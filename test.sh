#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$ROOT_DIR/build"
xcrun swiftc -O -module-cache-path "$ROOT_DIR/build/module-cache" \
  "$ROOT_DIR/general/pomodoro/Sources/Core.swift" \
  "$ROOT_DIR/general/pomodoro/Tests/main.swift" \
  -o "$ROOT_DIR/build/pomodoro-tests"
"$ROOT_DIR/build/pomodoro-tests"
