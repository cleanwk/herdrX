#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/pty-tests
cat > build/pty-tests/module.modulemap <<MODULE
module PTY { header "${PWD}/Core/Sources/PTY/include/PTY.h" export * }
MODULE
xcrun clang -I Core/Sources/PTY/include -c Core/Sources/PTY/PTY.c -o build/pty-tests/PTY.o
xcrun swiftc -I build/pty-tests App/PTY.swift Tests/PTYStress.swift build/pty-tests/PTY.o -o build/pty-tests/stress
build/pty-tests/stress
