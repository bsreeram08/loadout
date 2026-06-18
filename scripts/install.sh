#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib/sign.sh
source "${ROOT}/scripts/lib/sign.sh"

INSTALL_DIR="${HOME}/.local/bin"
BUILD_CONFIG="${BUILD_CONFIG:-release}"
TARGET="${INSTALL_DIR}/loadout"

echo "building loadout (${BUILD_CONFIG})..."
(cd "$ROOT" && swift build -c "${BUILD_CONFIG}" --product loadout)

BIN_DIR="${ROOT}/.build/$(uname -m | sed 's/arm64/arm64/')-apple-macosx/${BUILD_CONFIG}"
BINARY="${BIN_DIR}/loadout"
if [[ ! -f "$BINARY" ]]; then
  BINARY="${ROOT}/.build/${BUILD_CONFIG}/loadout"
fi
if [[ ! -f "$BINARY" ]]; then
  echo "error: loadout binary not found after build" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"
cp -f "$BINARY" "$TARGET"

if is_signed "$TARGET"; then
  echo "already signed → ${TARGET}"
else
  sign_binary "$TARGET"
  echo "signed ($(signing_label)) → ${TARGET}"
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