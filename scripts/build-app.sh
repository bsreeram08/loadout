#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib/sign.sh
source "${ROOT}/scripts/lib/sign.sh"

BUILD_CONFIG="${BUILD_CONFIG:-release}"
ENTITLEMENTS_PATH="${ENTITLEMENTS_PATH:-${ROOT}/Assets/Loadout.entitlements}"
DIST="${ROOT}/dist"
APP="${DIST}/Loadout.app"
IDENTIFIER="${LOADOUT_BUNDLE_ID:-dev.loadout.app}"
VERSION="${LOADOUT_VERSION:-$(cat "${ROOT}/VERSION" 2>/dev/null || echo 0.2.0.1)}"

if [[ ! -f "${ROOT}/Assets/AppIcon.icns" ]]; then
  echo "generating icons..."
  "${ROOT}/scripts/generate-icons.sh"
fi

echo "building loadout + LoadoutApp (${BUILD_CONFIG})..."
(cd "$ROOT" && swift build -c "${BUILD_CONFIG}" --product loadout --product LoadoutApp)

BIN_DIR="${ROOT}/.build/$(uname -m | sed 's/arm64/arm64/')-apple-macosx/${BUILD_CONFIG}"
if [[ ! -f "${BIN_DIR}/LoadoutApp" ]]; then
  BIN_DIR="${ROOT}/.build/${BUILD_CONFIG}"
fi

rm -rf "$APP"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"

cp "${BIN_DIR}/LoadoutApp" "${APP}/Contents/MacOS/LoadoutApp"
cp "${BIN_DIR}/loadout" "${APP}/Contents/MacOS/loadout"
cp "${BIN_DIR}/loadout" "${APP}/Contents/Resources/loadout"
cp "${ROOT}/Assets/AppIcon.icns" "${APP}/Contents/Resources/AppIcon.icns"
cp "${ROOT}/Sources/LoadoutApp/Resources/MenuBarIcon.png" "${APP}/Contents/Resources/"
cp "${ROOT}/Sources/LoadoutApp/Resources/MenuBarIcon@2x.png" "${APP}/Contents/Resources/"

cat > "${APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>LoadoutApp</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>${IDENTIFIER}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Loadout</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

sign_binary "${APP}/Contents/MacOS/loadout"
sign_binary "${APP}/Contents/MacOS/LoadoutApp"
sign_binary "$APP"
echo "signed ($(signing_label)) → ${APP}"

echo "built → ${APP}"
echo ""
echo "install:"
echo "  cp -R '${APP}' /Applications/"
echo "  open '/Applications/Loadout.app'"