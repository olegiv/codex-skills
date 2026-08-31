#!/usr/bin/env bash
set -euo pipefail

START='<!-- codex-skill:full-branch-audit:start -->'
END='<!-- codex-skill:full-branch-audit:end -->'

usage() {
  cat <<'USAGE'
Usage:
  check_agents_snippet.sh [codex-home]

Checks for the managed full-branch-audit block in AGENTS.md under the
selected Codex home. Defaults to $CODEX_HOME or ~/.codex.
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

codex_home="${1:-${CODEX_HOME:-$HOME/.codex}}"
agents_file="$codex_home/AGENTS.md"
if [[ ! -f "$agents_file" ]]; then
  echo "missing: $agents_file"
  exit 1
fi

start_count="$(grep -Fxc "$START" "$agents_file" || true)"
end_count="$(grep -Fxc "$END" "$agents_file" || true)"

if [[ $start_count == 1 && $end_count == 1 ]]; then
  echo "present: $agents_file"
  exit 0
fi
if [[ $start_count != "$end_count" ]]; then
  echo "invalid: managed block markers are unbalanced in $agents_file"
  exit 2
fi
if [[ $start_count != 0 ]]; then
  echo "invalid: expected at most one managed block in $agents_file"
  exit 2
fi

echo "missing: managed block not found in $agents_file"
exit 1
