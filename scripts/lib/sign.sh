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

# Resolve a Swift PM executable across arch-specific .build layouts.
resolve_swift_binary() {
  local product="$1"
  local root="$2"
  local config="${3:-release}"

  local arch
  arch="$(uname -m)"
  local -a candidates=(
    "${root}/.build/${arch}-apple-macosx/${config}/${product}"
    "${root}/.build/${config}/${product}"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  while IFS= read -r candidate; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done < <(find "${root}/.build" -path "*/${config}/${product}" -type f 2>/dev/null | sort)

  echo "error: ${product} binary not found after build (config=${config})" >&2
  return 1
}