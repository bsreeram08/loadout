#!/usr/bin/env bash
set -euo pipefail

# Notarize and staple a Loadout.app zip produced by package-release.sh.
#
# Required environment:
#   APPLE_ID              Apple ID email
#   APPLE_TEAM_ID         Team ID (e.g. TH2VPAUX6Y)
#   NOTARY_PASSWORD       App-specific password or App Store Connect API key secret
#
# Optional (API key auth instead of app-specific password):
#   NOTARY_KEY_PATH       Path to AuthKey_*.p8
#   NOTARY_KEY_ID         App Store Connect API key ID
#   APPLE_ISSUER_ID       App Store Connect issuer UUID

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <Loadout-*.zip>" >&2
  exit 1
fi

ZIP="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
if [[ ! -f "$ZIP" ]]; then
  echo "error: zip not found: $ZIP" >&2
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ditto -x -k "$ZIP" "$WORK"
APP="$(find "$WORK" -maxdepth 2 -name 'Loadout.app' -print -quit)"
if [[ -z "$APP" ]]; then
  echo "error: Loadout.app not found inside $ZIP" >&2
  exit 1
fi

NOTARY_ARGS=(--wait)
if [[ -n "${NOTARY_KEY_PATH:-}" && -n "${NOTARY_KEY_ID:-}" && -n "${APPLE_ISSUER_ID:-}" ]]; then
  NOTARY_ARGS+=(--key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "${APPLE_ISSUER_ID}")
elif [[ -n "${APPLE_ID:-}" && -n "${NOTARY_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  NOTARY_ARGS+=(--apple-id "$APPLE_ID" --password "$NOTARY_PASSWORD" --team-id "$APPLE_TEAM_ID")
else
  echo "error: set APPLE_ID + NOTARY_PASSWORD + APPLE_TEAM_ID, or NOTARY_KEY_PATH + NOTARY_KEY_ID" >&2
  exit 1
fi

echo "submitting ${ZIP} for notarization..."
xcrun notarytool submit "$ZIP" "${NOTARY_ARGS[@]}"

echo "stapling ticket to app bundle..."
xcrun stapler staple "$APP"

echo "repacking notarized zip..."
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "notarized → $ZIP"