#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/coexistence-tests
case "$(uname -m)" in
  arm64) asset=herdr-macos-aarch64 ;;
  x86_64) asset=herdr-macos-x86_64 ;;
  *) exit 1 ;;
esac
curl --fail --location --silent --show-error "https://github.com/herdrdev/herdr/releases/download/v0.9.3/$asset" -o build/coexistence-tests/herdr
chmod +x build/coexistence-tests/herdr
cat > build/coexistence-tests/module.modulemap <<MODULE
module PTY { header "${PWD}/Core/Sources/PTY/include/PTY.h" export * }
MODULE
xcrun clang -I Core/Sources/PTY/include -c Core/Sources/PTY/PTY.c -o build/coexistence-tests/PTY.o
xcrun swiftc -parse-as-library -I build/coexistence-tests Core/Sources/HerdCore/*.swift App/PTY.swift Tests/TerminalCoexistence.swift build/coexistence-tests/PTY.o -o build/coexistence-tests/check
python3 scripts/coexistence-fixture.py build/coexistence-tests/herdr build/coexistence-tests/check
