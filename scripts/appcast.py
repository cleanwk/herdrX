#!/usr/bin/env python3
"""Verify generated Sparkle artifacts before enabling self-updates in metadata."""
import base64
import hashlib
import json
import pathlib
import plistlib
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


def main():
    # The private key is only a path passed to Sparkle's official verifier.
    directory, app, tool, key_file, public_key = sys.argv[1:]
    directory = pathlib.Path(directory)
    metadata_path = directory / "release.json"
    metadata = json.loads(metadata_path.read_text())
    info = plistlib.loads((pathlib.Path(app) / "Contents/Info.plist").read_bytes())
    archive, feed = directory / metadata["filename"], directory / "appcast.xml"
    signature = validate(feed.read_bytes(), metadata, info, archive, public_key)
    subprocess.run([tool, "--verify", "--ed-key-file", key_file, str(feed)], check=True)
    subprocess.run([tool, "--verify", "--ed-key-file", key_file, str(archive), signature], check=True)
    metadata["signed_updates"] = True
    metadata["appcast_sha256"] = hashlib.sha256(feed.read_bytes()).hexdigest()
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n")


if __name__ == "__main__":
    main()
