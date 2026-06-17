#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="${ROOT}/Assets/AppIcon.iconset"
ICNS="${ROOT}/Assets/AppIcon.icns"

echo "rendering black & white icons..."
swift "${ROOT}/scripts/RenderIcons.swift"

echo "building AppIcon.icns..."
iconutil -c icns "$ICONSET" -o "$ICNS"

echo "icons ready:"
echo "  ${ICNS}"
echo "  ${ROOT}/Sources/LoadoutApp/Resources/MenuBarIcon.png"
echo "  ${ROOT}/Sources/LoadoutApp/Resources/MenuBarIcon@2x.png"