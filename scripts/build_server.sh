#!/usr/bin/env bash
# build_server.sh — Compile server_main.dart on a machine with only Dart SDK
# Usage: ./scripts/build_server.sh [output_path]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT="${1:-$PROJECT_DIR/server_main}"

cd "$PROJECT_DIR"

echo "==> Switching to server pubspec (no Flutter SDK required)..."
cp pubspec.yaml pubspec.yaml.bak
cp pubspec_server.yaml pubspec.yaml

echo "==> Running dart pub get..."
dart pub get

echo "==> Compiling server_main.dart -> $OUTPUT ..."
dart compile exe lib/server_main.dart -o "$OUTPUT"

echo "==> Restoring original pubspec.yaml..."
cp pubspec.yaml.bak pubspec.yaml
dart pub get --no-precompile 2>/dev/null || true

echo ""
echo "Build complete: $OUTPUT"
echo "Deploy with:"
echo "  scp $OUTPUT user@server:/opt/secretariat/server_main"
echo "  ssh user@server 'sudo chown secretariat:secretariat /opt/secretariat/server_main && sudo chmod 755 /opt/secretariat/server_main && sudo systemctl restart secretariat'"
