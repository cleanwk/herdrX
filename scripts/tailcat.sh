#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
if [[ ! -f build/herdrx-tailcat ]] || [[ -n "$(find Tools/Tailcat -type f -newer build/herdrx-tailcat -print -quit)" ]] || [[ "$(lipo -archs build/herdrx-tailcat)" != 'x86_64 arm64' && "$(lipo -archs build/herdrx-tailcat)" != 'arm64 x86_64' ]]; then
  (cd Tools/Tailcat && CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -trimpath -ldflags='-s -w' -o ../../build/tailcat-arm64 .)
  (cd Tools/Tailcat && CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -trimpath -ldflags='-s -w' -o ../../build/tailcat-amd64 .)
  lipo -create build/tailcat-arm64 build/tailcat-amd64 -output build/herdrx-tailcat
fi
if [[ -n "${TARGET_BUILD_DIR:-}" ]]; then
  mkdir -p "$TARGET_BUILD_DIR/$EXECUTABLE_FOLDER_PATH"
  cp build/herdrx-tailcat "$TARGET_BUILD_DIR/$EXECUTABLE_FOLDER_PATH/herdrx-tailcat"
  signing=(--force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}")
  if [[ "${ENABLE_HARDENED_RUNTIME:-NO}" == YES ]]; then signing+=(--options runtime); fi
  codesign "${signing[@]}" "$TARGET_BUILD_DIR/$EXECUTABLE_FOLDER_PATH/herdrx-tailcat"
fi
