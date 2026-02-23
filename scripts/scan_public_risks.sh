#!/usr/bin/env bash
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

TARGET_PATH="skills"

usage() {
  cat <<'USAGE'
Usage:
  scan_public_risks.sh [--path <path>]

Returns non-zero if disallowed patterns are found.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      [[ $# -ge 2 ]] || die "Missing value for --path"
      TARGET_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

SEARCH_TOOL=""
FILTER_TOOL=""
if command -v rg >/dev/null 2>&1; then
  SEARCH_TOOL="rg"
  FILTER_TOOL="rg"
elif command -v grep >/dev/null 2>&1; then
  SEARCH_TOOL="grep"
  FILTER_TOOL="grep"
  log "WARN" "ripgrep not found; using grep fallback"
else
  die "Neither ripgrep (rg) nor grep is available"
fi

if [[ ! -e "$TARGET_PATH" ]]; then
  die "Path not found: $TARGET_PATH"
fi

ALLOW_RE='(<your-token>|<your-secret>|\$[A-Z0-9_]*(TOKEN|KEY|SECRET|PASSWORD)|FIGMA_OAUTH_TOKEN|example\.local|example\.com)'
FOUND=0

scan_block() {
  local label="$1"
  local pattern="$2"
  local hits

  if [[ "$SEARCH_TOOL" == "rg" ]]; then
    hits="$(rg -n --no-heading -I -e "$pattern" "$TARGET_PATH" || true)"
  else
    hits="$(grep -RInE --binary-files=without-match "$pattern" "$TARGET_PATH" || true)"
  fi
  if [[ -z "$hits" ]]; then
    return
  fi

  if [[ "$FILTER_TOOL" == "rg" ]]; then
    hits="$(printf '%s\n' "$hits" | rg -v "$ALLOW_RE" || true)"
  else
    hits="$(printf '%s\n' "$hits" | grep -Ev "$ALLOW_RE" || true)"
  fi
  if [[ -z "$hits" ]]; then
    return
  fi

  FOUND=1
  log "ERROR" "${label} hits detected"
  printf '%s\n' "$hits"
}

scan_block "Absolute local paths" '/(Users|private/var)/'
scan_block "Internal identifiers" '(iruorg(\.local|4)|olegiv)'
scan_block "Private key headers" 'BEGIN (RSA|OPENSSH|EC) PRIVATE KEY'
scan_block "Bearer literals" '[Aa]uthorization[[:space:]]*:[[:space:]]*[Bb]earer[[:space:]]+[A-Za-z0-9._+/=-]{16,}'
scan_block "Probable secret literals" "(api[_-]?key|token|secret|password)[[:space:]]*[:=][[:space:]]*['\\\"][A-Za-z0-9._+/=-]{16,}['\\\"]"

if (( FOUND == 1 )); then
  exit 1
fi

log "INFO" "No public-risk pattern hits in $TARGET_PATH"
