#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_HOME="$ROOT/.build/home"
MODULE_CACHE="$ROOT/.build/clang-module-cache"
SWIFT_CACHE="$ROOT/.build/swift-module-cache"
TMP="$ROOT/.build/tmp"

mkdir -p "$BUILD_HOME" "$MODULE_CACHE" "$SWIFT_CACHE" "$TMP" "$ROOT/.build/cache" "$ROOT/.build/config" "$ROOT/.build/security"

HOME="$BUILD_HOME" \
TMPDIR="$TMP" \
CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" \
SWIFT_MODULE_CACHE_PATH="$SWIFT_CACHE" \
swift run \
    --disable-sandbox \
    --cache-path "$ROOT/.build/cache" \
    --config-path "$ROOT/.build/config" \
    --security-path "$ROOT/.build/security" \
    CoreChecks
