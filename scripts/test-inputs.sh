#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
xcrun swiftc -parse-as-library App/RenameInput.swift App/SearchInput.swift scripts/TextInputTests.swift -o build/tests/text-input-tests
build/tests/text-input-tests
