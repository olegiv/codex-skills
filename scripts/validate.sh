#!/usr/bin/env bash
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

REPO_ROOT="$(resolve_repo_root)"
MANIFEST="$REPO_ROOT/skills/manifest.yml"

usage() {
  cat <<'USAGE'
Usage:
  validate.sh

Validates manifest, SKILL.md presence, relative references, and optional
post_validate commands.
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

[[ -f "$MANIFEST" ]] || die "Manifest not found: $MANIFEST"

entry_count=0
fail_count=0

check_links() {
  local skill_dir="$1"
  local skill_md="$2"
  local ref

  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue

    ref="${ref%%\)*}"
    ref="$(trim "$ref")"

    if [[ "$ref" =~ ^(https?://|mailto:|#) ]]; then
      continue
    fi

    if [[ "$ref" =~ ^/ ]]; then
      err "Absolute link in $skill_md: $ref"
      fail_count=$((fail_count + 1))
      continue
    fi

    local cleaned="$ref"
    cleaned="${cleaned%%#*}"
    cleaned="${cleaned%%\?*}"
    cleaned="${cleaned%% *}"

    [[ -z "$cleaned" ]] && continue

    if [[ ! -e "$skill_dir/$cleaned" ]]; then
      err "Broken relative link in $skill_md: $ref"
      fail_count=$((fail_count + 1))
    fi
  done < <(perl -ne 'while(/\]\(([^)]+)\)/g){print "$1\n"}' "$skill_md")
}

while IFS='|' read -r name path enabled _owner _requires post_validate; do
  [[ -z "$name" ]] && continue
  entry_count=$((entry_count + 1))

  if [[ "$enabled" != "true" ]]; then
    log "INFO" "Skipping disabled skill: $name"
    continue
  fi

  skill_dir="$REPO_ROOT/$path"
  skill_md="$skill_dir/SKILL.md"

  if [[ ! -d "$skill_dir" ]]; then
    err "Skill path not found for $name: $skill_dir"
    fail_count=$((fail_count + 1))
    continue
  fi

  if [[ ! -f "$skill_md" ]]; then
    err "Missing SKILL.md for $name: $skill_md"
    fail_count=$((fail_count + 1))
    continue
  fi

  check_links "$skill_dir" "$skill_md"

  if [[ -n "$post_validate" ]]; then
    log "INFO" "Running post_validate for $name"
    (
      cd "$skill_dir"
      bash -lc "$post_validate"
    ) || {
      err "post_validate failed for $name"
      fail_count=$((fail_count + 1))
    }
  fi
done < <(parse_manifest "$MANIFEST")

if (( entry_count == 0 )); then
  err "No manifest skill entries found in $MANIFEST"
  exit 1
fi

if (( fail_count > 0 )); then
  err "Validation failed with $fail_count issue(s)"
  exit 1
fi

log "INFO" "Validation passed"
