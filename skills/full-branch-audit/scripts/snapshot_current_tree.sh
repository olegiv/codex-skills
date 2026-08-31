#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

usage() {
  cat <<'USAGE'
Usage:
  snapshot_current_tree.sh [repository]

Prints stable identifiers for HEAD, tracked changes, Git status, and
untracked file content without modifying the repository.
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

hash_stdin() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    echo "SHA-256 utility not found" >&2
    return 127
  fi
}

repo="$(git -C "${1:-.}" rev-parse --show-toplevel)"
head_sha="$(git -C "$repo" rev-parse HEAD)"
status_sha="$(git -C "$repo" status --porcelain=v1 -z --untracked-files=all | hash_stdin)"
diff_sha="$(git -C "$repo" diff --binary HEAD -- | hash_stdin)"

untracked_sha="$({
  while IFS= read -r -d '' path; do
    full_path="$repo/$path"
    printf '%s\0' "$path"
    if [[ -L $full_path ]]; then
      printf 'symlink\0%s\0' "$(readlink "$full_path")"
    elif [[ -f $full_path ]]; then
      printf 'file\0%s\0' "$(hash_stdin < "$full_path")"
    else
      printf 'other\0'
    fi
  done < <(git -C "$repo" ls-files --others --exclude-standard -z)
} | hash_stdin)"

printf 'repository=%s\n' "$repo"
printf 'head=%s\n' "$head_sha"
printf 'status_sha256=%s\n' "$status_sha"
printf 'tracked_diff_sha256=%s\n' "$diff_sha"
printf 'untracked_sha256=%s\n' "$untracked_sha"
