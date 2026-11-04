#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
EXECUTABLE="HowMuch"
UNIVERSAL_DIR="$ROOT/.build/universal"
mkdir -p "$UNIVERSAL_DIR" "$ROOT/.build/home" "$ROOT/.build/tmp" "$ROOT/.build/clang-module-cache" "$ROOT/.build/swift-module-cache"

build_arch() {
    local triple="$1"
    local scratch="$2"
    echo "==> Building $EXECUTABLE for $triple" >&2
    HOME="$ROOT/.build/home" \
    TMPDIR="$ROOT/.build/tmp" \
    CLANG_MODULE_CACHE_PATH="$ROOT/.build/clang-module-cache" \
    SWIFT_MODULE_CACHE_PATH="$ROOT/.build/swift-module-cache" \
    swift build \
        -c release \
        --product "$EXECUTABLE" \
        --triple "$triple" \
        --disable-sandbox \
        --scratch-path "$scratch" >&2
    find "$scratch" -type f -name "$EXECUTABLE" -perm -111 -print -quit
}

ARM_BIN="$(build_arch arm64-apple-macosx13.0 "$ROOT/.build/universal-arm64")"
X64_BIN="$(build_arch x86_64-apple-macosx13.0 "$ROOT/.build/universal-x64")"
if [[ -z "$ARM_BIN" || -z "$X64_BIN" ]]; then
    echo "Universal build did not produce both executables." >&2
    exit 1
fi

lipo -create "$ARM_BIN" "$X64_BIN" -output "$UNIVERSAL_DIR/$EXECUTABLE"
lipo -info "$UNIVERSAL_DIR/$EXECUTABLE"

HOWMUCH_BIN="$UNIVERSAL_DIR/$EXECUTABLE" bash "$ROOT/Scripts/build_app.sh"
