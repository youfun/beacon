#!/bin/bash

set -e

echo "========================================"
echo " Beacon Agent Dashboard — Build Script"
echo "========================================"

# Configuration
MIX_ENV=${MIX_ENV:-prod}
TARGET=${1:-linux}
echo "Build environment: $MIX_ENV"
echo "Target OS: $TARGET"

if [[ ! -f mix.exs ]]; then
  echo "❌ mix.exs not found — run this script from the watcher/ directory"
  exit 1
fi

export MIX_ENV=$MIX_ENV
export BURRITO_TARGET=$TARGET

echo ""
echo "📦 Fetching dependencies..."
mix deps.get --only prod

echo ""
echo "🔨 Compiling..."
mix compile

echo ""
echo "📦 Building single-file binary for $TARGET..."
mix release beacon --overwrite

echo ""
case $TARGET in
  windows)
    OUT="burrito_out/beacon_windows.exe"
    if [[ -f "$OUT" ]]; then
      echo "✅ Build successful!"
      echo "Binary: $OUT"
      echo ""
      echo "Usage on Windows:"
      echo "  .\\beacon_windows.exe"
      echo "  .\\beacon_windows.exe --port 8080 --dir C:\\Users\\you\\.claude"
    else
      echo "❌ Binary not found at $OUT"
      exit 1
    fi
    ;;
  macos_arm|macos_intel)
    OUT="burrito_out/beacon_macos"
    if [[ -f "$OUT" ]]; then
      echo "✅ Build successful!"
      echo "Binary: $OUT"
      echo ""
      echo "Usage:"
      echo "  chmod +x ./beacon_macos"
      echo "  ./beacon_macos"
      echo "  ./beacon_macos --port 8080 --dir ~/.claude"
    else
      echo "❌ Binary not found at $OUT"
      exit 1
    fi
    ;;
  *)
    OUT="burrito_out/beacon_linux"
    if [[ -f "$OUT" ]]; then
      echo "✅ Build successful!"
      echo "Binary: $OUT"
      echo ""
      echo "Usage:"
      echo "  chmod +x ./beacon_linux"
      echo "  ./beacon_linux"
      echo "  ./beacon_linux --port 8080 --dir ~/.claude"
    else
      echo "❌ Binary not found at $OUT"
      exit 1
    fi
    ;;
esac

echo ""
echo "The binary includes the Erlang VM — no Elixir/Erlang needed on target machine."
