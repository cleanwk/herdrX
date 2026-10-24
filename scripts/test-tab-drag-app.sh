#!/bin/bash
# Drags a tab in the built app against a real Herdr server. Needs scripts/build.sh
# and the herdr binary from scripts/test-coexistence.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
xcrun swiftc scripts/TabDragDriver.swift -o build/tests/tab-drag-driver
python3 scripts/tab-drag-app.py build/coexistence-tests/herdr build/release/Build/Products/Release/HerdrX.app build/tests/tab-drag-driver
