#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
BUILD_CONFIG="${BUILD_CONFIG:-debug}"
BINARY="${ROOT}/.build/${BUILD_CONFIG}/loadout"
TARGET="${INSTALL_DIR}/loadout"

echo "building loadout (${BUILD_CONFIG})..."
(cd "$ROOT" && swift build -c "${BUILD_CONFIG}")

mkdir -p "$INSTALL_DIR"
cp -f "$BINARY" "$TARGET"

if command -v codesign >/dev/null 2>&1; then
  codesign -s - --force --timestamp=none "$TARGET"
  echo "signed (ad-hoc) → ${TARGET}"
else
  echo "warning: codesign not found — keychain may keep prompting"
fi

echo "installed → ${TARGET}"

if ! echo ":${PATH}:" | grep -q ":${INSTALL_DIR}:"; then
  echo ""
  echo "add to PATH (e.g. in ~/.zshrc):"
  echo "  export PATH=\"\${HOME}/.local/bin:\${PATH}\""
fi

echo ""
echo "one-time keychain migration (if you used loadout before this version):"
echo "  loadout migrate-keychain"