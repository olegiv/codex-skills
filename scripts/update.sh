#!/usr/bin/env bash
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

REPO_ROOT="$(resolve_repo_root)"
SKILLS_SPEC="all"
MODE="link"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

usage() {
  cat <<'USAGE'
Usage:
  update.sh [--repo-root <path>] [--skills <comma-list|all>] [--mode link|copy] [--codex-home <path>]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      [[ $# -ge 2 ]] || die "Missing value for --repo-root"
      REPO_ROOT="$2"
      shift 2
      ;;
    --skills)
      [[ $# -ge 2 ]] || die "Missing value for --skills"
      SKILLS_SPEC="$2"
      shift 2
      ;;
    --mode)
      [[ $# -ge 2 ]] || die "Missing value for --mode"
      MODE="$2"
      shift 2
      ;;
    --codex-home)
      [[ $# -ge 2 ]] || die "Missing value for --codex-home"
      CODEX_HOME="$2"
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

if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  head_sha="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
  log "INFO" "Repository HEAD: $head_sha"
  if [[ -n "$(git -C "$REPO_ROOT" status --short --untracked-files=no)" ]]; then
    log "WARN" "Repository has local modifications; continuing with sync only"
  fi
fi

"$SCRIPT_DIR/install.sh" \
  --repo-root "$REPO_ROOT" \
  --skills "$SKILLS_SPEC" \
  --mode "$MODE" \
  --codex-home "$CODEX_HOME"

"$SCRIPT_DIR/validate.sh"

log "INFO" "Update complete. Restart Codex or open a new session to refresh skills."
