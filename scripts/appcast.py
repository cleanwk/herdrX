#!/usr/bin/env python3
"""Verify generated Sparkle artifacts before enabling self-updates in metadata."""
import base64
import hashlib
import json
import pathlib
import plistlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"


def validate(feed, metadata, info, archive, public_key):
    if len(base64.b64decode(public_key, validate=True)) != 32 or info.get("SUPublicEDKey") != public_key:
        raise ValueError("Bundle and configured Sparkle public keys must match")
    if not info.get("SURequireSignedFeed") or not info.get("SUVerifyUpdateBeforeExtraction"):
        raise ValueError("Signed feed and pre-extraction verification are required")
    items = ET.fromstring(feed).findall("./channel/item")
    if len(items) != 1:
        raise ValueError("Expected exactly one versioned update")
    item = items[0]
    if item.findtext(SPARKLE + "version") != info["CFBundleVersion"] or item.findtext(SPARKLE + "shortVersionString") != metadata["version"]:
        raise ValueError("Appcast version mismatch")
    if item.findtext(SPARKLE + "minimumSystemVersion") != metadata["min_macos"]:
        raise ValueError("Appcast minimum macOS mismatch")
    enclosure = item.find("enclosure")
    expected = f'https://github.com/cleanwk/herdrX/releases/download/v{metadata["version"]}/{metadata["filename"]}'
    if enclosure is None or enclosure.get("url") != expected or int(enclosure.get("length", "0")) != archive.stat().st_size:
        raise ValueError("Unexpected update URL or length")
    if hashlib.sha256(archive.read_bytes()).hexdigest() != metadata["sha256"]:
        raise ValueError("Archive digest changed after packaging")
    signature = enclosure.get(SPARKLE + "edSignature", "")
    if len(base64.b64decode(signature, validate=True)) != 64:
        raise ValueError("Missing archive Ed25519 signature")
    return signature


def deltas(feed, directory, version, build, allowed_builds=None):
    """Validate every delta before using its filename or trusting its signature."""
    result, sources = [], set()
    for enclosure in ET.fromstring(feed).findall(f"./channel/item/{SPARKLE}deltas/enclosure"):
        source = enclosure.get(SPARKLE + "deltaFrom", "")
        if not re.fullmatch(r"[1-9][0-9]*", source) or int(source) >= int(build) or source in sources:
            raise ValueError("Invalid or duplicate delta source build")
        if allowed_builds is not None and source not in allowed_builds:
            raise ValueError("Delta source was not a verified historical release")
        filename = f"HerdrX{build}-{source}.delta"
        expected = f"https://github.com/cleanwk/herdrX/releases/download/v{version}/{filename}"
        if enclosure.get("url") != expected:
            raise ValueError("Unexpected delta URL or filename")
        path = directory / filename
        if path.is_symlink() or not path.is_file() or int(enclosure.get("length", "0")) != path.stat().st_size or path.stat().st_size == 0:
            raise ValueError("Missing delta or incorrect length")
        signature = enclosure.get(SPARKLE + "edSignature", "")
        if len(base64.b64decode(signature, validate=True)) != 64:
            raise ValueError("Missing delta Ed25519 signature")
        sources.add(source)
        result.append((path, signature, source))
    return sorted(result, key=lambda value: int(value[2]), reverse=True)


def verify(directory, app, tool, key_file, public_key, allowed_builds=None):
    # The private key is only a path passed to Sparkle's official verifier.
    directory = pathlib.Path(directory)
    metadata_path = directory / "release.json"
    metadata = json.loads(metadata_path.read_text())
    info = plistlib.loads((pathlib.Path(app) / "Contents/Info.plist").read_bytes())
    archive, feed = directory / metadata["filename"], directory / "appcast.xml"
    signature = validate(feed.read_bytes(), metadata, info, archive, public_key)
    patches = deltas(feed.read_bytes(), directory, metadata["version"], info["CFBundleVersion"], allowed_builds)
    subprocess.run([tool, "--verify", "--ed-key-file", key_file, str(feed)], check=True)
    for payload, payload_signature in [(archive, signature)] + [(path, sig) for path, sig, _ in patches]:
        subprocess.run([tool, "--verify", "--ed-key-file", key_file, str(payload), payload_signature], check=True)
    metadata["signed_updates"] = True
    metadata["appcast_sha256"] = hashlib.sha256(feed.read_bytes()).hexdigest()
    metadata["deltas"] = [dict(filename=path.name, from_build=source, size=path.stat().st_size,
                               sha256=hashlib.sha256(path.read_bytes()).hexdigest()) for path, _, source in patches]
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n")
    checksums = [(archive.name, metadata["sha256"]), (feed.name, metadata["appcast_sha256"])]
    checksums.extend((delta["filename"], delta["sha256"]) for delta in metadata["deltas"])
    (directory / "SHA256SUMS").write_text("".join(f"{digest}  {name}\n" for name, digest in checksums))
    return metadata


if __name__ == "__main__":
    verify(*sys.argv[1:])
