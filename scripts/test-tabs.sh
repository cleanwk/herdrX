#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
xcrun swiftc -parse-as-library App/ThemeColors.swift App/Tabs.swift scripts/TabScrollTests.swift -o build/tests/tab-scroll-tests
build/tests/tab-scroll-tests
# TEMP probe
xcrun swiftc -parse-as-library App/Tabs.swift scripts/TabDragProbe2.swift -o build/tests/tab-drag-probe2
for v in baseline hover consume safearea movableoff; do VARIANT=$v build/tests/tab-drag-probe2; done
xcrun swiftc -parse-as-library -D BGDISABLED App/Tabs.swift scripts/TabDragProbe2.swift -o build/tests/tab-drag-probe2b
VARIANT=bgdisabled build/tests/tab-drag-probe2b
