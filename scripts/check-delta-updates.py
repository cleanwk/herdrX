#!/usr/bin/env python3
"""macOS integration fixture using the built app and Sparkle's shipping tools."""
import hashlib
import json
import os
import pathlib
import plistlib
import shutil
import stat
import subprocess
import tempfile
import time

import appcast
import updates


def run(*args, **kwargs):
    return subprocess.run([str(arg) for arg in args], check=True, **kwargs)


def tree(root):
    result = {}
    for path in root.rglob("*"):
        mode = stat.S_IMODE(path.lstat().st_mode)
        if path.is_symlink():
            value = ("link", mode, os.readlink(path))
        elif path.is_file():
            value = ("file", mode, hashlib.sha256(path.read_bytes()).hexdigest())
        else:
            value = ("directory", mode)
        result[str(path.relative_to(root))] = value
    return result


def main():
    source = pathlib.Path("build/release/Build/Products/Release/HerdrX.app")
    tool = next(pathlib.Path("build/release/SourcePackages/artifacts").glob("**/bin/generate_appcast"))
    with tempfile.TemporaryDirectory(prefix="delta-tests-", dir="build") as temporary:
        root = pathlib.Path(temporary)
        key, public = root / "private-key", root / "public-key"
        # Ephemeral fixture keys never touch the user's or runner's Keychain.
        generator = root / "keys.swift"
        generator.write_text('''import Foundation
import CryptoKit
let key = Curve25519.Signing.PrivateKey()
try key.rawRepresentation.base64EncodedString().write(toFile: CommandLine.arguments[1], atomically: true, encoding: .utf8)
try key.publicKey.rawRepresentation.base64EncodedString().write(toFile: CommandLine.arguments[2], atomically: true, encoding: .utf8)
''')
        run("swift", generator, key, public)
        key.chmod(0o600)
        public_key = public.read_text()
        base = int(time.time())
        bundles, archives = [], []
        for index in range(4):
            version, build = f"99.0.{index}", str(base + index)
            directory = root / version
            directory.mkdir()
            bundle = directory / "HerdrX.app"
            run("ditto", source, bundle)
            plist = bundle / "Contents/Info.plist"
            info = plistlib.loads(plist.read_bytes())
            info.update(CFBundleShortVersionString=version, CFBundleVersion=build, SUPublicEDKey=public_key)
            plist.write_bytes(plistlib.dumps(info))
            (bundle / "Contents/Resources/delta-fixture.txt").write_text(f"Fixture revision {index}\n")
            run("codesign", "--force", "--deep", "--sign", "-", bundle, capture_output=True)
            archive = directory / f"HerdrX-{version}-universal.zip"
            run("ditto", "-c", "-k", "--keepParent", bundle, archive)
            bundles.append(bundle)
            archives.append(archive)

        bundle, archive = bundles[-1], archives[-1]
        info = plistlib.loads((bundle / "Contents/Info.plist").read_bytes())
        metadata = dict(version=info["CFBundleShortVersionString"], build=info["CFBundleVersion"],
                        filename=archive.name, min_macos=info["LSMinimumSystemVersion"], notarized=False,
                        architectures=["arm64", "x86_64"], sha256=hashlib.sha256(archive.read_bytes()).hexdigest())

        def generate(name, history):
            directory = root / name
            directory.mkdir()
            shutil.copy2(archive, directory / archive.name)
            (directory / "release.json").write_text(json.dumps(metadata))
            return directory, updates.generate(directory, bundle, tool, key, public_key, history)

        full, full_metadata = generate("full-only", [])
        assert full_metadata["deltas"] == [], "First release must work without history"
        output, result = generate("with-deltas", archives[:-1])
        assert len(result["deltas"]) == 3, "Expected coverage of all three base builds"
        expected_files = {archive.name, "appcast.xml", "release.json", "SHA256SUMS"}
        expected_files.update(delta["filename"] for delta in result["deltas"])
        assert {path.name for path in output.iterdir()} == expected_files, "Historical assets leaked into release"
        target_tree = tree(bundle)
        sizes = []
        for delta in result["deltas"]:
            index = int(delta["from_build"]) - base
            patched = root / f"patched-{index}.app"
            path = output / delta["filename"]
            assert path.stat().st_size < archive.stat().st_size, "Delta must save bandwidth"
            run(tool.parent / "BinaryDelta", "apply", bundles[index], patched, path)
            assert tree(patched) == target_tree, "Reconstructed bundle differs in contents, modes or symlinks"
            run("codesign", "--verify", "--deep", "--strict", patched)
            sizes.append(dict(from_build=delta["from_build"], bytes=path.stat().st_size))

        # A modified installed app must not accept a patch for an exact published base.
        wrong_base = root / "wrong-base.app"
        run("ditto", bundles[0], wrong_base)
        (wrong_base / "Contents/Resources/delta-fixture.txt").write_text("locally modified app\n")
        delta = next(d for d in result["deltas"] if d["from_build"] == str(base))
        failure = subprocess.run([str(tool.parent / "BinaryDelta"), "apply", str(wrong_base),
                                  str(root / "must-not-install.app"), str(output / delta["filename"])], capture_output=True)
        assert failure.returncode != 0, "Wrong base must be rejected (Sparkle falls back to full)"

        # Keep the same length so this tests cryptographic verification, not just size checks.
        path = output / delta["filename"]
        original = path.read_bytes()
        path.write_bytes(bytes([original[0] ^ 1]) + original[1:])
        try:
            appcast.verify(output, bundle, str(tool.parent / "sign_update"), str(key), public_key)
        except subprocess.CalledProcessError:
            pass
        else:
            raise AssertionError("Tampered delta passed signature verification")
        path.write_bytes(original)

        evidence = dict(full_bytes=archive.stat().st_size, deltas=sizes, verified_bases=3,
                        exact_bundle_reconstruction=True, signatures_verified=True,
                        wrong_base_rejected=True, tampered_delta_rejected=True, full_only_feed_verified=True)
        destination = pathlib.Path("build/tests/delta-updates.json")
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(evidence, indent=2) + "\n")
        print(json.dumps(evidence, indent=2))


if __name__ == "__main__":
    main()
