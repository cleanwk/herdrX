#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
scripts/icon.sh
xcodegen generate
# A hostless bundle: no HerdrX startup, default Herdr session or user preferences.
if xcodebuild test -project HerdrX.xcodeproj -scheme SelectionTests -configuration Debug \
  -derivedDataPath build/release -destination 'platform=macOS' \
  -parallel-testing-enabled NO -resultBundlePath build/tests/selection.xcresult; then
  cat build/tests/pane-actions.json
  exit 0
else
  status=$?
  xcrun xcresulttool get test-results summary --path build/tests/selection.xcresult || true
  xcrun xcresulttool export diagnostics --path build/tests/selection.xcresult \
    --output-path build/tests/selection-diagnostics || true
  exit "$status"
fi
