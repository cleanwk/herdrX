#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="${VERSION:-$(cat VERSION)}"
build="${BUILD_NUMBER:-1}"
identity="${SIGN_IDENTITY:--}"
runtime=YES
# Library validation needs a Developer ID team; local ad-hoc previews have none.
[[ "$identity" != '-' ]] || runtime=NO
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid version' >&2; exit 1; }
[[ "$build" =~ ^[0-9]+$ ]] || { echo 'Invalid build number' >&2; exit 1; }
scripts/icon.sh
xcodegen generate
swift test --package-path Core -c release
xcodebuild -project HerdrX.xcodeproj -scheme HerdrX -configuration Release \
  -derivedDataPath build/release -destination 'generic/platform=macOS' \
  MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$build" \
  CODE_SIGN_IDENTITY="$identity" CODE_SIGN_STYLE=Manual \
  ENABLE_HARDENED_RUNTIME="$runtime" \
  ONLY_ACTIVE_ARCH=NO 'ARCHS=arm64 x86_64'
app='build/release/Build/Products/Release/HerdrX.app'
codesign --verify --deep --strict "$app"
if [[ "$identity" != '-' ]]; then
  app_team=$(codesign -dv "$app" 2>&1 | sed -n 's/^TeamIdentifier=//p')
  framework_team=$(codesign -dv "$app/Contents/Frameworks/Sparkle.framework" 2>&1 | sed -n 's/^TeamIdentifier=//p')
  [[ -n "$app_team" && "$app_team" != 'not set' && "$app_team" == "$framework_team" ]] || { echo 'Embedded framework signing team must match the app' >&2; exit 1; }
fi
architectures=$(lipo "$app/Contents/MacOS/HerdrX" -archs)
[[ "$architectures" == 'arm64 x86_64' || "$architectures" == 'x86_64 arm64' ]] || { echo 'Universal app required' >&2; exit 1; }
echo "$app"
