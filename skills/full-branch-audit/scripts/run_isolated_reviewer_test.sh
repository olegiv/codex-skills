#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/run_isolated_reviewer.sh"

test_root="$(mktemp -d "${TMPDIR:-/tmp}/full-branch-review-test.XXXXXXXXXX")"
cleanup() {
  case "$test_root" in
    "${TMPDIR:-/tmp}"/full-branch-review-test.*)
      rm -rf -- "$test_root"
      ;;
    *)
      echo "refusing to remove unexpected test directory: $test_root" >&2
      ;;
  esac
}
trap cleanup EXIT

source_home="$test_root/source-home"
repo="$test_root/repo"
fake_codex="$test_root/fake-codex"
prompt="$test_root/prompt.md"
report="$test_root/report.txt"
mkdir -p "$source_home/skills/should-not-leak" "$source_home/plugins" "$repo"
printf '{}\n' > "$source_home/auth.json"
printf 'must not leak\n' > "$source_home/AGENTS.md"
printf 'model = "must-not-leak"\n' > "$source_home/config.toml"
printf 'audit directly\n' > "$prompt"
git -C "$repo" init -q

cat > "$fake_codex" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'codex_home=%s\n' "$CODEX_HOME"
  printf 'child=%s\n' "${CODEX_FULL_BRANCH_AUDIT_CHILD:-}"
  [[ -L "$CODEX_HOME/auth.json" ]] && echo 'auth=symlink'
  [[ ! -e "$CODEX_HOME/AGENTS.md" ]] && echo 'agents=absent'
  [[ ! -e "$CODEX_HOME/config.toml" ]] && echo 'config=absent'
  [[ ! -e "$CODEX_HOME/skills" ]] && echo 'skills=absent'
  [[ ! -e "$CODEX_HOME/plugins" ]] && echo 'plugins=absent'
  printf 'args='
  printf '<%s>' "$@"
  printf '\nstdin='
  cat
} > "$TEST_REPORT"
FAKE
chmod 700 "$fake_codex"

TEST_REPORT="$report" CODEX_HOME="$source_home" CODEX_BIN="$fake_codex" \
  "$RUNNER" "$repo" "$prompt"

grep -Fx 'child=1' "$report" >/dev/null
grep -Fx 'auth=symlink' "$report" >/dev/null
grep -Fx 'agents=absent' "$report" >/dev/null
grep -Fx 'config=absent' "$report" >/dev/null
grep -Fx 'skills=absent' "$report" >/dev/null
grep -Fx 'plugins=absent' "$report" >/dev/null
grep -F -- '<--ignore-user-config>' "$report" >/dev/null
grep -F -- '<--ephemeral>' "$report" >/dev/null
grep -F -- '<--sandbox><read-only>' "$report" >/dev/null
grep -F -- 'Do not invoke full-branch-audit' "$report" >/dev/null
grep -F -- $'stdin=audit directly' "$report" >/dev/null

review_home="$(sed -n 's/^codex_home=//p' "$report")"
[[ -n $review_home && ! -e $review_home ]]

if CODEX_FULL_BRANCH_AUDIT_CHILD=1 TEST_REPORT="$report" \
    CODEX_HOME="$source_home" CODEX_BIN="$fake_codex" \
    "$RUNNER" "$repo" "$prompt" >/dev/null 2>&1; then
  echo "recursive launch unexpectedly succeeded" >&2
  exit 1
fi

echo "Isolated reviewer launcher tests passed"
