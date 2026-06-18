#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib/sign.sh
source "${ROOT}/scripts/lib/sign.sh"

BUILD_CONFIG="${BUILD_CONFIG:-release}"
VERSION="${LOADOUT_VERSION:-$(cat "${ROOT}/VERSION")}"
ARCH="$(uname -m)"
RELEASE_DIR="${ROOT}/dist/release"
STAGING="${ROOT}/dist/staging"

echo "packaging loadout ${VERSION} (${ARCH}, ${BUILD_CONFIG})..."

"${ROOT}/scripts/build-app.sh"

APP="${ROOT}/dist/Loadout.app"
CLI="$(resolve_swift_binary loadout "$ROOT" "$BUILD_CONFIG")"

rm -rf "$RELEASE_DIR" "$STAGING"
mkdir -p "$RELEASE_DIR" "$STAGING"

CLI_NAME="loadout-${VERSION}-macos-${ARCH}"
APP_NAME="Loadout-${VERSION}-macos-${ARCH}"

# CLI tarball: binary + install helper
CLI_STAGE="${STAGING}/${CLI_NAME}"
mkdir -p "${CLI_STAGE}/bin"
cp -f "$CLI" "${CLI_STAGE}/bin/loadout"
chmod +x "${CLI_STAGE}/bin/loadout"
cat > "${CLI_STAGE}/README.txt" <<EOF
Loadout CLI ${VERSION} (${ARCH})

Install:
  mkdir -p ~/.local/bin
  cp bin/loadout ~/.local/bin/loadout
  chmod +x ~/.local/bin/loadout

Ensure ~/.local/bin is on your PATH, then run:
  loadout --version
EOF

(
  cd "$STAGING"
  tar -czf "${RELEASE_DIR}/${CLI_NAME}.tar.gz" "$CLI_NAME"
)

# App zip
ditto -c -k --keepParent "$APP" "${RELEASE_DIR}/${APP_NAME}.zip"

# Optional notarization (Developer ID + Apple credentials required)
if [[ "${NOTARIZE:-}" == "1" ]]; then
  if [[ "${SIGN_IDENTITY:--}" == "-" ]]; then
    echo "error: NOTARIZE=1 requires SIGN_IDENTITY (Developer ID Application)" >&2
    exit 1
  fi
  "${ROOT}/scripts/notarize.sh" "${RELEASE_DIR}/${APP_NAME}.zip"
fi

echo ""
echo "release artifacts → ${RELEASE_DIR}/"
ls -lh "${RELEASE_DIR}"
echo ""
echo "signing: $(signing_label)"