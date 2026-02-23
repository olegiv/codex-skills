#!/usr/bin/env bash
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="strict"
MODULE=""
THEME=""
PATHS=()
IDE_INSPECT="on"
IDE_BIN="/Applications/PhpStorm.app/Contents/bin/inspect.sh"
IDE_PROFILE="$SCRIPT_DIR/../references/phpstorm-profile.xml"
FINAL_VALIDATION="off"

usage() {
  cat <<'USAGE'
Usage:
  run_prebuild_quality.sh [--mode strict|changed] [--module <name> | --theme <name>] [--paths <path...>] [--ide-inspect on|off] [--ide-profile <path>] [--ide-bin <path>] [--final-validation on|off]

Options:
  --mode         strict|changed (default: strict)
  --module       Custom module machine name under modules/custom
  --theme        Custom theme machine name under themes/custom
  --paths        Explicit files/directories (space-separated list)
  --ide-inspect  on|off (default: on)
  --ide-profile  PhpStorm inspection profile XML path
  --ide-bin      PhpStorm inspect.sh path
  --final-validation  on|off (default: off). When on, --ide-inspect must be on.
  -h, --help     Show this help
USAGE
}

log() {
  printf '[%s] %s\n' "$1" "$2"
}

error() {
  log "ERROR" "$1" >&2
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

append_unique() {
  local arr_name="$1"
  local value="$2"
  local existing
  eval "local current=(\"\${${arr_name}[@]}\")"
  for existing in "${current[@]}"; do
    if [[ "$existing" == "$value" ]]; then
      return 0
    fi
  done
  eval "${arr_name}+=(\"\$value\")"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      [[ $# -ge 2 ]] || { error "Missing value for --mode"; usage; exit 1; }
      MODE="$2"
      shift 2
      ;;
    --module)
      [[ $# -ge 2 ]] || { error "Missing value for --module"; usage; exit 1; }
      MODULE="$2"
      shift 2
      ;;
    --theme)
      [[ $# -ge 2 ]] || { error "Missing value for --theme"; usage; exit 1; }
      THEME="$2"
      shift 2
      ;;
    --paths)
      shift
      while [[ $# -gt 0 && "$1" != --* ]]; do
        PATHS+=("$1")
        shift
      done
      ;;
    --ide-inspect)
      [[ $# -ge 2 ]] || { error "Missing value for --ide-inspect"; usage; exit 1; }
      IDE_INSPECT="$2"
      shift 2
      ;;
    --ide-profile)
      [[ $# -ge 2 ]] || { error "Missing value for --ide-profile"; usage; exit 1; }
      IDE_PROFILE="$2"
      shift 2
      ;;
    --ide-bin)
      [[ $# -ge 2 ]] || { error "Missing value for --ide-bin"; usage; exit 1; }
      IDE_BIN="$2"
      shift 2
      ;;
    --final-validation)
      [[ $# -ge 2 ]] || { error "Missing value for --final-validation"; usage; exit 1; }
      FINAL_VALIDATION="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ "$MODE" != "strict" && "$MODE" != "changed" ]]; then
  error "Invalid --mode '$MODE'. Use strict or changed."
  exit 1
fi

if [[ "$IDE_INSPECT" != "on" && "$IDE_INSPECT" != "off" ]]; then
  error "Invalid --ide-inspect '$IDE_INSPECT'. Use on or off."
  exit 1
fi

if [[ "$FINAL_VALIDATION" != "on" && "$FINAL_VALIDATION" != "off" ]]; then
  error "Invalid --final-validation '$FINAL_VALIDATION'. Use on or off."
  exit 1
fi

if [[ "$FINAL_VALIDATION" == "on" && "$IDE_INSPECT" != "on" ]]; then
  error "Final validation requires --ide-inspect on."
  exit 1
fi

if [[ -n "$MODULE" && -n "$THEME" ]]; then
  error "--module and --theme are mutually exclusive."
  exit 1
fi

if (( ${#PATHS[@]} > 0 )) && [[ -n "$MODULE" || -n "$THEME" ]]; then
  error "--paths cannot be combined with --module or --theme."
  exit 1
fi

ROOT="${DRUPAL_ROOT:-$(pwd)}"
if [[ ! -f "$ROOT/composer.json" || ! -d "$ROOT/modules/custom" || ! -d "$ROOT/themes/custom" ]]; then
  error "Run from Drupal repository root or set DRUPAL_ROOT correctly."
  exit 1
fi

to_abs() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s\n' "$ROOT/$path"
  fi
}

IDE_PROFILE="$(to_abs "$IDE_PROFILE")"
IDE_BIN="$(to_abs "$IDE_BIN")"

PHP_BIN="$(command -v php || true)"
PHPCS_BIN="$ROOT/vendor/bin/phpcs"
PHPSTAN_BIN="$ROOT/vendor/bin/phpstan"
PHPUNIT_BIN="$ROOT/vendor/bin/phpunit"
PHPSTAN_CONFIG="$ROOT/phpstan.neon"
PHPUNIT_CONFIG="$ROOT/core/phpunit.xml.dist"
PHPSTORM_JSON_COUNTER="$SCRIPT_DIR/count_phpstorm_issues.php"

[[ -n "$PHP_BIN" ]] || { error "PHP binary not found in PATH."; exit 1; }
[[ -x "$PHPCS_BIN" ]] || { error "Missing executable $PHPCS_BIN"; exit 1; }
[[ -x "$PHPSTAN_BIN" ]] || { error "Missing executable $PHPSTAN_BIN"; exit 1; }
[[ -x "$PHPUNIT_BIN" ]] || { error "Missing executable $PHPUNIT_BIN"; exit 1; }
[[ -f "$PHPSTAN_CONFIG" ]] || { error "Missing PHPStan config $PHPSTAN_CONFIG"; exit 1; }
[[ -f "$PHPUNIT_CONFIG" ]] || { error "Missing PHPUnit config $PHPUNIT_CONFIG"; exit 1; }
[[ -f "$PHPSTORM_JSON_COUNTER" ]] || { error "Missing PhpStorm report parser $PHPSTORM_JSON_COUNTER"; exit 1; }
command_exists git || { error "git is required."; exit 1; }

if [[ "$IDE_INSPECT" == "on" ]]; then
  [[ -x "$IDE_BIN" ]] || { error "Missing executable PhpStorm inspector: $IDE_BIN"; exit 1; }
  [[ -f "$IDE_PROFILE" ]] || { error "Missing PhpStorm inspection profile: $IDE_PROFILE"; exit 1; }
fi

TARGET_ITEMS=()
SCOPE_LABEL=""

if (( ${#PATHS[@]} > 0 )); then
  for p in "${PATHS[@]}"; do
    abs="$(to_abs "$p")"
    if [[ ! -e "$abs" ]]; then
      error "Path not found: $p"
      exit 1
    fi
    append_unique TARGET_ITEMS "$abs"
  done
  SCOPE_LABEL="paths"
elif [[ -n "$MODULE" ]]; then
  module_path="$ROOT/modules/custom/$MODULE"
  [[ -d "$module_path" ]] || { error "Module not found: $module_path"; exit 1; }
  append_unique TARGET_ITEMS "$module_path"
  SCOPE_LABEL="module:$MODULE"
elif [[ -n "$THEME" ]]; then
  theme_path="$ROOT/themes/custom/$THEME"
  [[ -d "$theme_path" ]] || { error "Theme not found: $theme_path"; exit 1; }
  append_unique TARGET_ITEMS "$theme_path"
  SCOPE_LABEL="theme:$THEME"
elif [[ "$MODE" == "strict" ]]; then
  append_unique TARGET_ITEMS "$ROOT/modules/custom"
  append_unique TARGET_ITEMS "$ROOT/themes/custom"
  SCOPE_LABEL="strict"
else
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    if [[ "$rel" =~ \.(php|module|inc|install|theme|profile|engine)$ ]]; then
      append_unique TARGET_ITEMS "$ROOT/$rel"
    fi
  done < <(git -C "$ROOT" diff --name-only --diff-filter=ACMRTUXB -- modules/custom themes/custom)

  if (( ${#TARGET_ITEMS[@]} == 0 )); then
    log "INFO" "No changed custom PHP files found. Nothing to check."
    exit 0
  fi
  SCOPE_LABEL="changed"
fi

log "INFO" "Scope: $SCOPE_LABEL"
log "INFO" "Validation mode: $([[ "$FINAL_VALIDATION" == "on" ]] && printf 'final' || printf 'triage')"
for t in "${TARGET_ITEMS[@]}"; do
  log "INFO" "Target: ${t#$ROOT/}"
done

collect_php_files() {
  local item
  for item in "$@"; do
    if [[ -d "$item" ]]; then
      find "$item" -type f \
        \( -name '*.php' -o -name '*.module' -o -name '*.inc' -o -name '*.install' -o -name '*.theme' -o -name '*.profile' -o -name '*.engine' \)
    elif [[ -f "$item" && "$item" =~ \.(php|module|inc|install|theme|profile|engine)$ ]]; then
      printf '%s\n' "$item"
    fi
  done | sort -u
}

get_phpstan_targets() {
  if [[ -z "$MODULE" && -z "$THEME" && ${#PATHS[@]} -eq 0 && "$MODE" == "strict" ]]; then
    printf '%s\n' "$ROOT/modules/custom"
    return
  fi
  collect_php_files "$@"
}

collect_ide_scope_targets() {
  local item
  for item in "$@"; do
    if [[ -f "$item" ]]; then
      dirname "$item"
    elif [[ -d "$item" ]]; then
      printf '%s\n' "$item"
    fi
  done | sort -u
}

get_ide_filter_targets_for_scope() {
  local scope_target="$1"
  shift
  local item
  for item in "$@"; do
    if [[ -f "$item" ]]; then
      if [[ "$(dirname "$item")" == "$scope_target" ]]; then
        printf '%s\n' "$item"
      fi
    elif [[ -d "$item" ]]; then
      if [[ "$item" == "$scope_target" ]]; then
        printf '%s\n' "$item"
      fi
    fi
  done
}

OVERALL_FAILED=0
STAGE_SUMMARY=()

stage_result() {
  local stage="$1"
  local status="$2"
  STAGE_SUMMARY+=("$stage:$status")
  if [[ "$status" != "pass" && "$status" != "skip" ]]; then
    OVERALL_FAILED=1
  fi
}

# Stage 1: lint
log "INFO" "Stage: lint"
lint_files=()
while IFS= read -r f; do
  [[ -n "$f" ]] && lint_files+=("$f")
done < <(collect_php_files "${TARGET_ITEMS[@]}")

if (( ${#lint_files[@]} == 0 )); then
  log "WARN" "No PHP files found for lint stage."
  stage_result "lint" "skip"
else
  lint_failed=0
  for f in "${lint_files[@]}"; do
    if ! "$PHP_BIN" -l "$f" >/dev/null; then
      lint_failed=1
      error "Lint failed: ${f#$ROOT/}"
    fi
  done
  if (( lint_failed == 0 )); then
    stage_result "lint" "pass"
  else
    stage_result "lint" "fail"
  fi
fi

# Stage 2: phpcs
log "INFO" "Stage: phpcs"
if (( ${#TARGET_ITEMS[@]} == 0 )); then
  log "WARN" "No targets for PHPCS."
  stage_result "phpcs" "skip"
else
  if "$PHPCS_BIN" \
      --standard=Drupal,DrupalPractice \
      --extensions=php,module,inc,install,theme,profile,engine \
      "${TARGET_ITEMS[@]}"; then
    stage_result "phpcs" "pass"
  else
    stage_result "phpcs" "fail"
  fi
fi

# Stage 3: phpstan
log "INFO" "Stage: phpstan"
phpstan_targets=()
while IFS= read -r t; do
  [[ -n "$t" ]] && phpstan_targets+=("$t")
done < <(get_phpstan_targets "${TARGET_ITEMS[@]}")

if (( ${#phpstan_targets[@]} == 0 )); then
  log "WARN" "No targets for PHPStan."
  stage_result "phpstan" "skip"
else
  if "$PHPSTAN_BIN" analyse -c "$PHPSTAN_CONFIG" "${phpstan_targets[@]}"; then
    stage_result "phpstan" "pass"
  else
    stage_result "phpstan" "fail"
  fi
fi

# Stage 4: phpstorm_inspect
log "INFO" "Stage: phpstorm_inspect"
if [[ "$IDE_INSPECT" != "on" ]]; then
  log "INFO" "PhpStorm inspection disabled by --ide-inspect off."
  stage_result "phpstorm_inspect" "skip"
else
  ide_scope_targets=()
  while IFS= read -r s; do
    [[ -n "$s" ]] && ide_scope_targets+=("$s")
  done < <(collect_ide_scope_targets "${TARGET_ITEMS[@]}")

  if (( ${#ide_scope_targets[@]} == 0 )); then
    log "WARN" "No targets resolved for PhpStorm inspection."
    stage_result "phpstorm_inspect" "skip"
  else
    ide_failed=0
    for scope_target in "${ide_scope_targets[@]}"; do
      report_dir="$(mktemp -d "${TMPDIR:-/tmp}/phpstorm-inspect.XXXXXX")"
      inspect_log="$report_dir/inspect.log"

      "$IDE_BIN" "$ROOT" "$IDE_PROFILE" "$report_dir" -format json -d "$scope_target" >"$inspect_log" 2>&1
      inspect_exit=$?

      if grep -qiE 'Only one instance of .* can be run at a time\.' "$inspect_log"; then
        error "PhpStorm inspection blocked by running IDE instance for target ${scope_target#$ROOT/}."
        sed -n '1,20p' "$inspect_log" >&2
        ide_failed=1
        rm -rf "$report_dir"
        continue
      fi

      if (( inspect_exit != 0 )); then
        error "PhpStorm inspection command failed for target ${scope_target#$ROOT/}."
        sed -n '1,40p' "$inspect_log" >&2
        ide_failed=1
        rm -rf "$report_dir"
        continue
      fi

      json_count="$(find "$report_dir" -type f -name '*.json' | wc -l | tr -d ' ')"
      if [[ "$json_count" == "0" ]]; then
        error "PhpStorm inspection produced no JSON reports for target ${scope_target#$ROOT/}."
        sed -n '1,40p' "$inspect_log" >&2
        ide_failed=1
        rm -rf "$report_dir"
        continue
      fi

      filter_targets=()
      while IFS= read -r ft; do
        [[ -n "$ft" ]] && filter_targets+=("$ft")
      done < <(get_ide_filter_targets_for_scope "$scope_target" "${TARGET_ITEMS[@]}")
      if (( ${#filter_targets[@]} == 0 )); then
        filter_targets+=("$scope_target")
      fi

      parser_output="$($PHP_BIN "$PHPSTORM_JSON_COUNTER" "$report_dir" "$ROOT" "${filter_targets[@]}" 2>&1)"
      parser_exit=$?
      if (( parser_exit != 0 )); then
        error "PhpStorm report parsing failed for target ${scope_target#$ROOT/}."
        printf '%s\n' "$parser_output" >&2
        ide_failed=1
        rm -rf "$report_dir"
        continue
      fi

      issue_count_line="$(printf '%s\n' "$parser_output" | sed -n '1p')"
      issue_count="${issue_count_line#COUNT=}"
      if [[ ! "$issue_count" =~ ^[0-9]+$ ]]; then
        error "Invalid PhpStorm parser output for target ${scope_target#$ROOT/}."
        printf '%s\n' "$parser_output" >&2
        ide_failed=1
        rm -rf "$report_dir"
        continue
      fi

      if (( issue_count > 0 )); then
        error "PhpStorm inspection found $issue_count issue(s) for target ${scope_target#$ROOT/}."
        printf '%s\n' "$parser_output" | sed -n '2,16p' >&2
        ide_failed=1
      else
        log "INFO" "PhpStorm inspection passed for target ${scope_target#$ROOT/}."
      fi

      rm -rf "$report_dir"
    done

    if (( ide_failed == 0 )); then
      stage_result "phpstorm_inspect" "pass"
    else
      stage_result "phpstorm_inspect" "fail"
    fi
  fi
fi

# Stage 5: phpunit
log "INFO" "Stage: phpunit"
test_dirs=()

if [[ -n "$MODULE" ]]; then
  td="$ROOT/modules/custom/$MODULE/tests"
  [[ -d "$td" ]] && append_unique test_dirs "$td"
elif [[ -n "$THEME" ]]; then
  td="$ROOT/themes/custom/$THEME/tests"
  [[ -d "$td" ]] && append_unique test_dirs "$td"
elif (( ${#PATHS[@]} > 0 )) || [[ "$MODE" == "changed" ]]; then
  derived_files=()
  while IFS= read -r f; do
    [[ -n "$f" ]] && derived_files+=("$f")
  done < <(collect_php_files "${TARGET_ITEMS[@]}")

  touched_modules=()
  touched_themes=()
  for file in "${derived_files[@]}"; do
    rel="${file#$ROOT/}"
    case "$rel" in
      modules/custom/*)
        name="${rel#modules/custom/}"
        name="${name%%/*}"
        append_unique touched_modules "$name"
        ;;
      themes/custom/*)
        name="${rel#themes/custom/}"
        name="${name%%/*}"
        append_unique touched_themes "$name"
        ;;
    esac
  done

  for m in "${touched_modules[@]}"; do
    td="$ROOT/modules/custom/$m/tests"
    [[ -d "$td" ]] && append_unique test_dirs "$td"
  done
  for th in "${touched_themes[@]}"; do
    td="$ROOT/themes/custom/$th/tests"
    [[ -d "$td" ]] && append_unique test_dirs "$td"
  done
else
  while IFS= read -r td; do
    [[ -n "$td" ]] && append_unique test_dirs "$td"
  done < <(find "$ROOT/modules/custom" -mindepth 2 -maxdepth 2 -type d -name tests | sort)
fi

if (( ${#test_dirs[@]} == 0 )); then
  log "INFO" "No tests directories found for current scope. PHPUnit skipped."
  stage_result "phpunit" "skip"
else
  phpunit_failed=0
  for td in "${test_dirs[@]}"; do
    log "INFO" "PHPUnit target: ${td#$ROOT/}"
    if ! "$PHPUNIT_BIN" -c "$PHPUNIT_CONFIG" "$td"; then
      phpunit_failed=1
    fi
  done

  if (( phpunit_failed == 0 )); then
    stage_result "phpunit" "pass"
  else
    stage_result "phpunit" "fail"
  fi
fi

printf '\nSummary:\n'
for item in "${STAGE_SUMMARY[@]}"; do
  printf '  - %s\n' "$item"
done

if (( OVERALL_FAILED == 0 )); then
  log "INFO" "All enabled stages passed."
  exit 0
fi

error "One or more stages failed."
exit 1
