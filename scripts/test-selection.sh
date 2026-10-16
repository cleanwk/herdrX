#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
scripts/icon.sh
xcodegen generate
# Use the shipping optimization level for native latency measurements.
# Hostless bundles: the Desk/PTY fixture runs in a separate test process so its
# windows, async metadata tasks and Ghostty controller do not leak into selection.
if xcodebuild test -project HerdrX.xcodeproj -scheme SelectionTests -configuration Release \
  -derivedDataPath build/release -destination 'platform=macOS' \
  -parallel-testing-enabled NO -only-testing:SelectionTests/PaneActionInteractionTests \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 60 \
  -maximum-test-execution-time-allowance 120 -resultBundlePath build/tests/pane-actions.xcresult && \
  xcodebuild test-without-building -project HerdrX.xcodeproj -scheme SelectionTests -configuration Release \
  -derivedDataPath build/release -destination 'platform=macOS' \
  -skip-testing:SelectionTests/PaneActionInteractionTests \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 60 \
  -maximum-test-execution-time-allowance 120 \
  -parallel-testing-enabled NO -resultBundlePath build/tests/selection.xcresult; then
  cat build/tests/pane-actions.json
  exit 0
else
  status=$?
  for result in pane-actions selection; do
    [[ -d "build/tests/$result.xcresult" ]] || continue
    xcrun xcresulttool get test-results summary --path "build/tests/$result.xcresult" || true
    xcrun xcresulttool export diagnostics --path "build/tests/$result.xcresult" \
      --output-path "build/tests/$result-diagnostics" || true
  done
  exit "$status"
fi
