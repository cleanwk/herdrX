#!/usr/bin/env python3
"""Emit metadata only after packaging and signature verification."""
import hashlib
import json
import pathlib
import plistlib
import sys
import subprocess

if __name__ == "__main__":
    archive = pathlib.Path(sys.argv[1])
    notarized = sys.argv[2] == "1"
    info = plistlib.loads(pathlib.Path("build/release/Build/Products/Release/Herd-X.app/Contents/Info.plist").read_bytes())
    architectures = subprocess.check_output(["lipo", "build/release/Build/Products/Release/Herd-X.app/Contents/MacOS/Herd-X", "-archs"], text=True).split()
    if set(architectures) != {"arm64", "x86_64"} or archive.name != f'Herd-X-{info["CFBundleShortVersionString"]}-universal.zip':
        raise ValueError("Archive or architecture mismatch")
    digest = hashlib.file_digest(archive.open("rb"), "sha256").hexdigest()
    metadata = dict(version=info["CFBundleShortVersionString"], build=info["CFBundleVersion"],
                    filename=archive.name, sha256=digest, architectures=sorted(architectures),
                    min_macos=info["LSMinimumSystemVersion"], notarized=notarized)
    (archive.parent / "release.json").write_text(json.dumps(metadata, indent=2) + "\n")
