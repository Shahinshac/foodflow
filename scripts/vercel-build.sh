#!/bin/bash
set -e

echo "=== Setting up Flutter SDK for Vercel Web Deployment ==="

FLUTTER_DIR="$HOME/flutter"

if [ -d "$FLUTTER_DIR/bin" ]; then
    echo "Found cached Flutter SDK at $FLUTTER_DIR"
else
    echo "Cloning Flutter SDK (stable branch)..."
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

echo "=== Flutter Environment Info ==="
flutter --version

echo "=== Enabling Flutter Web ==="
flutter config --enable-web --no-analytics

echo "=== Fetching Packages ==="
flutter pub get

echo "=== Compiling Flutter Web Release ==="
flutter build web --release

echo "=== Verification of Build Output ==="
if [ -f "build/web/index.html" ]; then
    echo "SUCCESS: build/web/index.html generated successfully."
else
    echo "ERROR: build/web/index.html not found!"
    exit 1
fi
