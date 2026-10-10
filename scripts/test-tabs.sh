#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
xcrun swiftc -parse-as-library App/Tabs.swift scripts/TabScrollTests.swift -o build/tests/tab-scroll-tests
build/tests/tab-scroll-tests
