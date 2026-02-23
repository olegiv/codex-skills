#!/usr/bin/env bash
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

REPO_ROOT="$(resolve_repo_root)"
DEST="$REPO_ROOT/public-staging/skills"
CHECK_ONLY="false"
FAIL_ON_HIT="false"
RULES_FILE="$SCRIPT_DIR/sanitize/rules.txt"

SOURCES=()

usage() {
  cat <<'USAGE'
Usage:
  sanitize_public.sh [--source <path>] [--dest <path>] [--check-only] [--fail-on-hit]

Examples:
  sanitize_public.sh --source "$HOME/.codex/skills" --source "<repo-root>/dev/AI/codex"
  sanitize_public.sh --check-only --dest public-staging/skills
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      [[ $# -ge 2 ]] || die "Missing value for --source"
      SOURCES+=("$2")
      shift 2
      ;;
    --dest)
      [[ $# -ge 2 ]] || die "Missing value for --dest"
      DEST="$2"
      shift 2
      ;;
    --check-only)
      CHECK_ONLY="true"
      shift
      ;;
    --fail-on-hit)
      FAIL_ON_HIT="true"
      shift
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

[[ -f "$RULES_FILE" ]] || die "Rules file not found: $RULES_FILE"
command -v perl >/dev/null 2>&1 || die "perl is required"

if (( ${#SOURCES[@]} == 0 )); then
  SOURCES+=("$HOME/.codex/skills")
  if [[ -d "$REPO_ROOT/../codex" ]]; then
    SOURCES+=("$REPO_ROOT/../codex")
  fi
fi

find_skill_dirs() {
  local source="$1"

  if [[ ! -d "$source" ]]; then
    return
  fi

  if [[ -f "$source/SKILL.md" ]]; then
    printf '%s\n' "$source"
  fi

  if [[ -d "$source/skills" ]]; then
    find "$source/skills" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/SKILL.md' ';' -print
  fi

  find "$source" -mindepth 1 -maxdepth 1 -type d -not -name '.*' -exec test -f '{}/SKILL.md' ';' -print
}

apply_rules_to_file() {
  local file="$1"
  local rule
  while IFS= read -r rule || [[ -n "$rule" ]]; do
    [[ -z "$rule" ]] && continue
    [[ "$rule" =~ ^# ]] && continue
    perl -0777 -i -pe "$rule" "$file"
  done < "$RULES_FILE"
}

sanitize_tree() {
  local target="$1"
  local file
  while IFS= read -r -d '' file; do
    if grep -Iq . "$file"; then
      apply_rules_to_file "$file"
    fi
  done < <(find "$target" -type f -print0)
}

if [[ "$CHECK_ONLY" == "true" ]]; then
  if [[ ! -e "$DEST" ]]; then
    die "Check-only mode requires existing --dest path: $DEST"
  fi
  "$SCRIPT_DIR/scan_public_risks.sh" --path "$DEST"
  exit 0
fi

rm -rf "$DEST"
mkdir -p "$DEST"
MIRROR_DIR="$(cd "$(dirname "$DEST")" && pwd)/mirrors"
mkdir -p "$MIRROR_DIR"

copied=0
for source in "${SOURCES[@]}"; do
  if [[ ! -d "$source" ]]; then
    log "WARN" "Skipping missing source: $source"
    continue
  fi

  while IFS= read -r skill_dir; do
    [[ -z "$skill_dir" ]] && continue
    skill_name="$(basename "$skill_dir")"
    target_dir="$DEST/$skill_name"
    rm -rf "$target_dir"
    cp -R "$skill_dir" "$target_dir"
    copied=$((copied + 1))
  done < <(find_skill_dirs "$source" | sort -u)

  if [[ -f "$source/README.md" ]]; then
    mirror_name="$(basename "$source")-README.md"
    cp "$source/README.md" "$MIRROR_DIR/$mirror_name"
  fi
done

sanitize_tree "$DEST"
sanitize_tree "$MIRROR_DIR"

log "INFO" "Sanitized skills copied: $copied"
log "INFO" "Staging destination: $DEST"

if [[ "$FAIL_ON_HIT" == "true" ]]; then
  "$SCRIPT_DIR/scan_public_risks.sh" --path "$DEST"
fi
