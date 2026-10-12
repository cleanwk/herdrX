#!/usr/bin/env python3
"""Publish a single signed Sparkle update with deltas from recent stable releases."""
import hashlib
import json
import pathlib
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

import appcast

REPO = "cleanwk/herdrX"
MAX_DELTAS = 3


def version_tuple(version):
    if not isinstance(version, str) or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError("Expected a stable release version")
    return tuple(map(int, version.split(".")))


def previous_releases(releases, version):
    current = version_tuple(version)
    eligible = []
    for release in releases:
        tag = release.get("tag_name", "")
        if release.get("draft") or release.get("prerelease") or not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", tag):
            continue
        if version_tuple(tag[1:]) < current:
            eligible.append(release)
    return sorted(eligible, key=lambda r: version_tuple(r["tag_name"][1:]), reverse=True)[:MAX_DELTAS]


def archive_info(archive):
    with zipfile.ZipFile(archive) as bundle:
        return plistlib.loads(bundle.read("HerdrX.app/Contents/Info.plist"))


def validate_history(release, directory, current_info):
    """Only exact published archives with matching bundle identity/key can be bases."""
    tag = release["tag_name"]
    version_tuple(tag.removeprefix("v"))
    filename = f"HerdrX-{tag[1:]}-universal.zip"
    for name in ("release.json", filename):
        assets = [asset for asset in release["assets"] if asset["name"] == name]
        if len(assets) != 1 or assets[0].get("browser_download_url") != f"https://github.com/{REPO}/releases/download/{tag}/{name}":
            raise ValueError("Missing or unexpected historical release asset")
        path = directory / name
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if assets[0].get("digest") != "sha256:" + digest or assets[0].get("size") != path.stat().st_size:
            raise ValueError("Historical asset digest or size mismatch")
    metadata = json.loads((directory / "release.json").read_text())
    archive = directory / filename
    if metadata.get("version") != tag[1:] or metadata.get("filename") != filename or metadata.get("sha256") != hashlib.sha256(archive.read_bytes()).hexdigest():
        raise ValueError("Historical metadata/archive mismatch")
    info = archive_info(archive)
    build = info.get("CFBundleVersion", "")
    if not re.fullmatch(r"[1-9][0-9]*", build) or int(build) >= int(current_info["CFBundleVersion"]) or metadata.get("build") != build:
        raise ValueError("Historical build must precede the new build")
    if info.get("CFBundleShortVersionString") != tag[1:] or set(metadata.get("architectures", [])) != {"arm64", "x86_64"}:
        raise ValueError("Historical bundle version or architecture mismatch")
    for key in ("CFBundleIdentifier", "SUPublicEDKey"):
        if not info.get(key) or info[key] != current_info[key]:
            raise ValueError(f"Historical {key} differs from the new app")
    return archive


def fetch_history(directory, current_info):
    """Unavailable or unverified history reduces delta coverage, never full updates."""
    try:
        response = subprocess.run(["gh", "api", f"repos/{REPO}/releases?per_page=100"],
                                  check=True, capture_output=True, timeout=60)
        releases = previous_releases(json.loads(response.stdout), current_info["CFBundleShortVersionString"])
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"::warning::Cannot read delta history; generating a full update only ({type(error).__name__})")
        return []
    archives, builds = [], set()
    for release in releases:
        tag = release["tag_name"]
        destination = directory / tag
        destination.mkdir()
        try:
            subprocess.run(["gh", "release", "download", tag, "--repo", REPO, "--dir", str(destination),
                            "--pattern", "release.json", "--pattern", f"HerdrX-{tag[1:]}-universal.zip"],
                           check=True, capture_output=True, timeout=180)
            archive = validate_history(release, destination, current_info)
            build = archive_info(archive)["CFBundleVersion"]
            if build in builds:
                raise ValueError("Duplicate historical build")
            builds.add(build)
            archives.append(archive)
            print(f"Delta base: {tag} (build {build})")
        except (OSError, ValueError, KeyError, zipfile.BadZipFile, subprocess.SubprocessError) as error:
            print(f"::warning::Skipping delta base {tag} ({type(error).__name__}); full update remains available")
    return archives


def generate(directory, app, tool, key_file, public_key, history):
    """Keep historical archives out of release assets; copy only verified outputs."""
    directory, app, tool = pathlib.Path(directory), pathlib.Path(app), pathlib.Path(tool)
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    metadata = json.loads((directory / "release.json").read_text())
    version = metadata["version"]
    version_tuple(version)
    if metadata["filename"] != f"HerdrX-{version}-universal.zip" or metadata["build"] != info["CFBundleVersion"]:
        raise ValueError("New release metadata does not match the bundle")
    if info.get("SUPublicEDKey") != public_key or info["CFBundleShortVersionString"] != version:
        raise ValueError("New release version or Sparkle key mismatch")
    if not re.fullmatch(r"[1-9][0-9]*", info["CFBundleVersion"]):
        raise ValueError("New release requires a positive build number")
    with tempfile.TemporaryDirectory(prefix="appcast-", dir=directory.parent) as temporary:
        staging = pathlib.Path(temporary)
        for name in (metadata["filename"], "release.json"):
            shutil.copy2(directory / name, staging / name)
        builds = set()
        for archive in history:
            builds.add(archive_info(archive)["CFBundleVersion"])
            shutil.copy2(archive, staging / archive.name)
        subprocess.run([str(tool), "--ed-key-file", str(key_file), "--download-url-prefix",
                        f"https://github.com/{REPO}/releases/download/v{version}/", "--versions", info["CFBundleVersion"],
                        "--maximum-versions", "1", "--maximum-deltas", str(MAX_DELTAS), str(staging)], check=True)
        metadata = appcast.verify(staging, app, str(tool.parent / "sign_update"), str(key_file), public_key, builds)
        # A failed generation/verification above must never leave a publishable feed.
        for name in ["appcast.xml", "release.json", "SHA256SUMS"] + [delta["filename"] for delta in metadata["deltas"]]:
            shutil.copy2(staging / name, directory / name)
    print(f"Verified full update and {len(metadata['deltas'])} delta(s)")
    return metadata


def main():
    directory, app, tool, key_file, public_key = sys.argv[1:]
    info = plistlib.loads((pathlib.Path(app) / "Contents/Info.plist").read_bytes())
    with tempfile.TemporaryDirectory(prefix="update-history-", dir=pathlib.Path(directory).parent) as temporary:
        history = fetch_history(pathlib.Path(temporary), info)
        generate(directory, app, tool, key_file, public_key, history)


if __name__ == "__main__":
    main()
