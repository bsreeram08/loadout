#!/usr/bin/env bash
# Shared code signing helpers.
#
# SIGN_IDENTITY:
#   "-" (default)     ad-hoc signing for local development
#   "Developer ID …"  hardened runtime + timestamp for notarization
#
# Optional:
#   ENTITLEMENTS_PATH — entitlements plist passed to codesign

sign_binary() {
  local target="$1"
  local identity="${SIGN_IDENTITY:--}"

  if ! command -v codesign >/dev/null 2>&1; then
    echo "warning: codesign not found — skip signing ${target}" >&2
    return 0
  fi

  local -a args=(-s "$identity" --force)

  if [[ "$identity" != "-" ]]; then
    args+=(--options runtime --timestamp)
    if [[ -n "${ENTITLEMENTS_PATH:-}" && -f "$ENTITLEMENTS_PATH" ]]; then
      args+=(--entitlements "$ENTITLEMENTS_PATH")
    fi
  else
    args+=(--timestamp=none)
  fi

  codesign "${args[@]}" "$target"
}

is_signed() {
  local target="$1"
  command -v codesign >/dev/null 2>&1 && codesign --verify --strict "$target" 2>/dev/null
}

signing_label() {
  local identity="${SIGN_IDENTITY:--}"
  if [[ "$identity" == "-" ]]; then
    echo "ad-hoc"
  else
    echo "$identity"
  fi
}