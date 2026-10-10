#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="${VERSION:-$(cat VERSION)}"
app='build/release/Build/Products/Release/HerdrX.app'
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
actual=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
[[ "$actual" == "$version" ]] || { echo 'Bundle version mismatch' >&2; exit 1; }
mkdir -p build/dist
archive="build/dist/HerdrX-${version}-universal.zip"
if [[ "${NOTARIZE:-0}" == 1 ]]; then
  : "${APPLE_ID:?}" "${APPLE_TEAM_ID:?}" "${APPLE_APP_PASSWORD:?}"
  codesign -dvv "$app" 2>&1 | grep -q 'Authority=Developer ID Application' || { echo 'Developer ID signing required' >&2; exit 1; }
  ditto -c -k --keepParent "$app" build/notarize.zip
  xcrun notarytool submit build/notarize.zip --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD" --wait --output-format json > build/notary-result.json
  python3 -c 'import json; assert json.load(open("build/notary-result.json"))["status"] == "Accepted"'
  xcrun stapler staple "$app"
  spctl --assess --type execute --verbose "$app"
fi
codesign --verify --deep --strict "$app"
architectures=$(lipo "$app/Contents/MacOS/HerdrX" -archs)
[[ "$architectures" == 'arm64 x86_64' || "$architectures" == 'x86_64 arm64' ]] || { echo 'Universal app required' >&2; exit 1; }
ditto -c -k --keepParent "$app" "$archive"
shasum -a 256 "$archive" > build/dist/SHA256SUMS
python3 scripts/release.py "$archive" "${NOTARIZE:-0}"
