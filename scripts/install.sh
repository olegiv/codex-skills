#!/usr/bin/env bash
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

REPO_ROOT="$(resolve_repo_root)"
SKILLS_SPEC="all"
MODE="link"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

usage() {
  cat <<'USAGE'
Usage:
  install.sh [--repo-root <path>] [--skills <comma-list|all>] [--mode link|copy] [--codex-home <path>]
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

if [[ "$MODE" != "link" && "$MODE" != "copy" ]]; then
  die "Invalid --mode '$MODE' (expected link|copy)"
fi

MANIFEST="$REPO_ROOT/skills/manifest.yml"
[[ -f "$MANIFEST" ]] || die "Manifest not found: $MANIFEST"

mkdir -p "$CODEX_HOME/skills"

names=()
paths=()
enabled_flags=()

while IFS='|' read -r name path enabled owner requires post_validate; do
  [[ -z "$name" ]] && continue
  names+=("$name")
  paths+=("$path")
  enabled_flags+=("$enabled")
done < <(parse_manifest "$MANIFEST")

(( ${#names[@]} > 0 )) || die "No skill entries found in manifest"

find_skill_index() {
  local wanted="$1"
  local i
  for ((i = 0; i < ${#names[@]}; i++)); do
    if [[ "${names[$i]}" == "$wanted" ]]; then
      printf '%s\n' "$i"
      return 0
    fi
  done
  return 1
}

install_one() {
  local idx="$1"
  local name="${names[$idx]}"
  local path="${paths[$idx]}"
  local enabled="${enabled_flags[$idx]}"
  local src="$REPO_ROOT/$path"
  local dst="$CODEX_HOME/skills/$name"

  if [[ "$enabled" != "true" ]]; then
    log "INFO" "Skipping disabled skill: $name"
    return 0
  fi

  [[ -d "$src" ]] || die "Skill path missing for $name: $src"
  [[ -f "$src/SKILL.md" ]] || die "SKILL.md missing for $name: $src/SKILL.md"

  if [[ "$MODE" == "link" ]]; then
    ln -sfn "$src" "$dst"
    log "INFO" "Linked $name -> $dst"
    return 0
  fi

  if command -v rsync >/dev/null 2>&1; then
    mkdir -p "$dst"
    rsync -a --delete "$src/" "$dst/"
  else
    rm -rf "$dst"
    mkdir -p "$dst"
    cp -R "$src/"* "$dst/"
  fi
  log "INFO" "Copied $name -> $dst"
}

if [[ "$SKILLS_SPEC" == "all" ]]; then
  for ((i = 0; i < ${#names[@]}; i++)); do
    install_one "$i"
  done
  exit 0
fi

IFS=',' read -r -a requested <<< "$SKILLS_SPEC"
for raw_name in "${requested[@]}"; do
  wanted="$(trim "$raw_name")"
  [[ -n "$wanted" ]] || continue

  idx="$(find_skill_index "$wanted" || true)"
  [[ -n "$idx" ]] || die "Requested skill not found in manifest: $wanted"
  install_one "$idx"
done
