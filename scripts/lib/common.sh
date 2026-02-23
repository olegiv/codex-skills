#!/usr/bin/env bash
set -u
set -o pipefail

log() {
  printf '[%s] %s\n' "$1" "$2"
}

err() {
  log "ERROR" "$1" >&2
}

die() {
  err "$1"
  exit 1
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

strip_quotes() {
  local value
  value="$(trim "$1")"
  if [[ "$value" =~ ^\"(.*)\"$ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return
  fi
  if [[ "$value" =~ ^\'(.*)\'$ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return
  fi
  printf '%s' "$value"
}

normalize_bool() {
  local value
  value="$(strip_quotes "$1")"
  case "${value,,}" in
    true|1|yes|on)
      printf 'true'
      ;;
    false|0|no|off)
      printf 'false'
      ;;
    *)
      printf 'true'
      ;;
  esac
}

resolve_repo_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  printf '%s\n' "$script_dir"
}

parse_manifest() {
  local manifest="$1"
  [[ -f "$manifest" ]] || die "Manifest not found: $manifest"

  local current_name=""
  local current_path=""
  local current_enabled=""
  local current_owner=""
  local current_requires=""
  local current_post_validate=""

  flush_entry() {
    if [[ -z "$current_name" ]]; then
      return
    fi
    if [[ -z "$current_path" ]]; then
      current_path="skills/$current_name"
    fi
    if [[ -z "$current_enabled" ]]; then
      current_enabled="true"
    fi
    printf '%s|%s|%s|%s|%s|%s\n' \
      "$current_name" \
      "$current_path" \
      "$current_enabled" \
      "$current_owner" \
      "$current_requires" \
      "$current_post_validate"
  }

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    local line
    line="$(trim "$raw_line")"
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue

    if [[ "$line" =~ ^-[[:space:]]*name:[[:space:]]*(.+)$ ]]; then
      flush_entry
      current_name="$(strip_quotes "${BASH_REMATCH[1]}")"
      current_path=""
      current_enabled=""
      current_owner=""
      current_requires=""
      current_post_validate=""
      continue
    fi

    if [[ -z "$current_name" ]]; then
      continue
    fi

    if [[ "$line" =~ ^path:[[:space:]]*(.+)$ ]]; then
      current_path="$(strip_quotes "${BASH_REMATCH[1]}")"
      continue
    fi
    if [[ "$line" =~ ^enabled:[[:space:]]*(.+)$ ]]; then
      current_enabled="$(normalize_bool "${BASH_REMATCH[1]}")"
      continue
    fi
    if [[ "$line" =~ ^owner:[[:space:]]*(.+)$ ]]; then
      current_owner="$(strip_quotes "${BASH_REMATCH[1]}")"
      continue
    fi
    if [[ "$line" =~ ^requires:[[:space:]]*(.+)$ ]]; then
      current_requires="$(strip_quotes "${BASH_REMATCH[1]}")"
      continue
    fi
    if [[ "$line" =~ ^post_validate:[[:space:]]*(.*)$ ]]; then
      current_post_validate="$(strip_quotes "${BASH_REMATCH[1]}")"
      continue
    fi
  done < "$manifest"

  flush_entry
}
