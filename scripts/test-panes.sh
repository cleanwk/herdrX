#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
xcrun swiftc -parse-as-library Core/Sources/HerdCore/JSON.swift Core/Sources/HerdCore/PaneLayoutGeometry.swift App/PaneGeometry.swift App/PaneShape.swift scripts/PaneGeometryTests.swift -o build/tests/pane-geometry-tests
case "$(uname -m)" in
  arm64) asset=herdr-macos-aarch64 ;;
  x86_64) asset=herdr-macos-x86_64 ;;
  *) exit 1 ;;
esac
mkdir -p build/pane-tests
curl --fail --location --silent --show-error "https://github.com/herdrdev/herdr/releases/download/v0.8.2/$asset" -o build/pane-tests/herdr-legacy
chmod +x build/pane-tests/herdr-legacy
# Reuse CI's current fixture binary; keep this script runnable on its own.
herdr_current=build/coexistence-tests/herdr
if [[ ! -x "$herdr_current" ]]; then
  herdr_current=build/pane-tests/herdr-current
  curl --fail --location --silent --show-error "https://github.com/herdrdev/herdr/releases/download/v0.9.3/$asset" -o "$herdr_current"
  chmod +x "$herdr_current"
fi
python3 scripts/layout-origin-fixture.py build/pane-tests/herdr-legacy "$herdr_current" build/tests/layout-origins.json
build/tests/pane-geometry-tests build/tests/layout-origins.json
