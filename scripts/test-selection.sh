#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
scripts/icon.sh
xcodegen generate
# A hostless bundle: no HerdrX startup, default Herdr session or user preferences.
xcodebuild test -project HerdrX.xcodeproj -scheme SelectionTests -configuration Debug \
  -derivedDataPath build/release -destination 'platform=macOS' \
  -parallel-testing-enabled NO -resultBundlePath build/tests/selection.xcresult
