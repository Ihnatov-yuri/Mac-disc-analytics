#!/usr/bin/env bash
# Build DiscStats (Release) and install it into /Applications.
# Usage: ./scripts/install.sh
set -euo pipefail

cd "$(dirname "$0")/.."
BUILD_DIR="build"
APP="$BUILD_DIR/Build/Products/Release/DiscStats.app"
DEST="/Applications/DiscStats.app"

xcodebuild -project DiscStats.xcodeproj \
           -scheme DiscStats \
           -configuration Release \
           -derivedDataPath "$BUILD_DIR" \
           build | tail -n 5

[ -d "$APP" ] || { echo "Build output not found: $APP" >&2; exit 1; }

# Quit a running copy so the bundle can be replaced.
osascript -e 'quit app "DiscStats"' 2>/dev/null || true

rm -rf "$DEST"
ditto "$APP" "$DEST"
echo "Installed $DEST"
open "$DEST"
