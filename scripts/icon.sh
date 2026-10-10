#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
tool="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
[[ -x "$tool" ]] || { echo 'Xcode 27 Icon Composer is required' >&2; exit 1; }
preview='Resources/Icon/Preview.png'
"$tool" App/AppIcon.icon --export-image --output-file "$preview" --platform macOS --rendition Default --width 1024 --height 1024 --scale 1
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT
mkdir "$temp/HerdIcon.iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$preview" --out "$temp/HerdIcon.iconset/icon_${size}x${size}.png" > /dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$preview" --out "$temp/HerdIcon.iconset/icon_${size}x${size}@2x.png" > /dev/null
done
iconutil -c icns "$temp/HerdIcon.iconset" -o Resources/Icon/HerdIcon.icns
