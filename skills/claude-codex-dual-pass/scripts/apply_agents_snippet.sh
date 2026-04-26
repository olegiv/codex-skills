#!/usr/bin/env bash
set -euo pipefail

START='<!-- codex-skill:claude-codex-dual-pass:start -->'
END='<!-- codex-skill:claude-codex-dual-pass:end -->'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNIPPET_FILE="$SCRIPT_DIR/../references/agents-snippet.md"

usage() {
  cat <<'USAGE'
Usage:
  apply_agents_snippet.sh <project-root>

Creates or updates <project-root>/AGENTS.md with the managed
claude-codex-dual-pass block. Only the managed block is replaced.
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

project_root="${1:-}"
if [[ -z "$project_root" ]]; then
  usage >&2
  exit 2
fi

if [[ ! -d "$project_root" ]]; then
  echo "project root not found: $project_root" >&2
  exit 2
fi

if [[ ! -f "$SNIPPET_FILE" ]]; then
  echo "snippet not found: $SNIPPET_FILE" >&2
  exit 2
fi

agents_file="$project_root/AGENTS.md"
tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

if [[ ! -f "$agents_file" ]]; then
  {
    printf '# AGENTS.md\n\n'
    cat "$SNIPPET_FILE"
    printf '\n'
  } > "$agents_file"
  echo "created: $agents_file"
  exit 0
fi

start_count="$(grep -Fxc "$START" "$agents_file" || true)"
end_count="$(grep -Fxc "$END" "$agents_file" || true)"

if [[ "$start_count" != "$end_count" ]]; then
  echo "cannot update: managed block markers are unbalanced in $agents_file" >&2
  exit 2
fi

if [[ "$start_count" != "0" && "$start_count" != "1" ]]; then
  echo "cannot update: expected at most one managed block in $agents_file" >&2
  exit 2
fi

if [[ "$start_count" == "0" ]]; then
  cp "$agents_file" "$tmp_file"
  {
    printf '\n'
    cat "$SNIPPET_FILE"
    printf '\n'
  } >> "$tmp_file"
  mv "$tmp_file" "$agents_file"
  trap - EXIT
  echo "appended: $agents_file"
  exit 0
fi

awk -v start="$START" -v end="$END" -v snippet="$SNIPPET_FILE" '
  BEGIN {
    while ((getline line < snippet) > 0) {
      replacement = replacement line ORS
    }
    close(snippet)
    in_block = 0
  }
  $0 == start {
    printf "%s", replacement
    in_block = 1
    next
  }
  $0 == end && in_block {
    in_block = 0
    next
  }
  !in_block {
    print
  }
' "$agents_file" > "$tmp_file"

mv "$tmp_file" "$agents_file"
trap - EXIT
echo "updated: $agents_file"
