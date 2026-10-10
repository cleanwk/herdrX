#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
xcrun swiftc -parse-as-library App/PaneGeometry.swift App/PaneShape.swift scripts/PaneGeometryTests.swift -o build/tests/pane-geometry-tests
build/tests/pane-geometry-tests
