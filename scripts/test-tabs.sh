#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
xcrun swiftc -parse-as-library App/ThemeColors.swift App/Tabs.swift scripts/TabScrollTests.swift -o build/tests/tab-scroll-tests
build/tests/tab-scroll-tests
# TEMP probe
xcrun swiftc -parse-as-library App/Tabs.swift scripts/TabDragProbe.swift -o build/tests/tab-drag-probe
build/tests/tab-drag-probe
exit 1
