#!/usr/bin/env bash
# Regenerates data/lumide.json from the GitHub releases API.
#
# No release archive is ever downloaded: each GitHub asset carries a
# `digest: "sha256:<hex>"` field, so we read the hash straight from the API. A
# full run is a handful of HTTP requests, cheap enough for CI.
#
# The asset filename version does not always match the release tag (older assets
# embed a "_1" build suffix, e.g. tag 0.13.0 -> Lumide-Linux-0.13.0_1-...), so we
# record each asset's real `browser_download_url` rather than constructing it.
#
# Env knobs (all optional):
#   LUMIDE_DATA_DIR   where to write lumide.json   (default: $PWD/data)
#   GITHUB_TOKEN      sent as a bearer token to raise the API rate limit

set -euo pipefail

DATA_DIR="${LUMIDE_DATA_DIR:-$PWD/data}"
REPO="SoFluffyOS/lumide"
API="https://api.github.com/repos/$REPO/releases"

# (system, asset-arch) pairs we support. Add "aarch64-linux:arm64" once upstream
# publishes an arm64 Linux asset.
SYSTEMS=(
  "x86_64-linux:x86_64"
)

mkdir -p "$DATA_DIR"

log() { printf '[lumide-update] %s\n' "$*" >&2; }

gh_get() {
  local url="$1"
  local -a auth=()
  [[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
  curl -fsSL "${auth[@]}" -H "Accept: application/vnd.github+json" "$url"
}

out="$DATA_DIR/lumide.json"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

page=1
while :; do
  log "fetching releases page $page"
  resp="$(gh_get "$API?per_page=100&page=$page")"
  [[ "$(jq 'length' <<<"$resp")" -eq 0 ]] && break

  for spec in "${SYSTEMS[@]}"; do
    IFS=: read -r system arch <<<"$spec"
    # For each release, keep the asset matching Lumide-Linux-*-<arch>.tar.gz and
    # emit one record using the release tag as the version.
    jq -c \
      --arg system "$system" \
      --arg pat "^Lumide-Linux-.*-${arch}\\.tar\\.gz$" '
      .[]
      | .tag_name as $version
      | .assets[]
      | select(.name | test($pat))
      | select(.digest | startswith("sha256:"))
      | {
          version: $version,
          system: $system,
          url: .browser_download_url,
          sha256: (.digest | ltrimstr("sha256:")),
        }
    ' <<<"$resp" >>"$tmp"
  done

  page=$((page + 1))
done

jq -s 'unique_by([.version, .system]) | sort_by(.system, .version)' "$tmp" >"$out"
log "wrote $out ($(jq length "$out") entries)"
