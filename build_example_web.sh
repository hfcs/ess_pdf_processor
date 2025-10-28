#!/usr/bin/env bash
# Wrapper to build the example Flutter web app from the repository root.
# This allows running a single command from the top-level to build the nested
# Flutter example.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)
EXAMPLE_DIR="$ROOT_DIR/web_app"

if [ ! -d "$EXAMPLE_DIR" ]; then
  echo "Error: web_app directory not found: $EXAMPLE_DIR" >&2
  exit 1
fi

echo "Building Flutter web example in $EXAMPLE_DIR"
cd "$EXAMPLE_DIR"
flutter build web --release

echo "Build finished. Output in $EXAMPLE_DIR/build/web (or build/web)"
