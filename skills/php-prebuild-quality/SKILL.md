---
name: php-prebuild-quality
description: Run Drupal 11 pre-build quality gates with dual-source validation (lint, PHPCS, PHPStan, PhpStorm CLI inspections, PHPUnit) in strict, changed-file, module-scoped, theme-scoped, or explicit-path modes.
---

# PHP Prebuild Quality

Use this skill to execute non-mutating pre-build quality validation for Drupal 11 PHP code.

## Quick Start

Run from the Drupal repository root:

```bash
$CODEX_HOME/skills/php-prebuild-quality/scripts/run_prebuild_quality.sh
```

Module-scoped run:

```bash
$CODEX_HOME/skills/php-prebuild-quality/scripts/run_prebuild_quality.sh --module iru_datalayer
```

Theme-scoped run:

```bash
$CODEX_HOME/skills/php-prebuild-quality/scripts/run_prebuild_quality.sh --theme iru_ip
```

Changed-files run:

```bash
$CODEX_HOME/skills/php-prebuild-quality/scripts/run_prebuild_quality.sh --mode changed
```

Disable IDE inspection explicitly:

```bash
$CODEX_HOME/skills/php-prebuild-quality/scripts/run_prebuild_quality.sh --ide-inspect off
```

Final-validation run (required for clean verdicts):

```bash
$CODEX_HOME/skills/php-prebuild-quality/scripts/run_prebuild_quality.sh --module iru_datalayer --final-validation on
```

## Execution Order

Always run stages in this order:
1. PHP syntax lint (`php -l`)
2. PHPCS (`Drupal,DrupalPractice`)
3. PHPStan (`phpstan.neon`)
4. PhpStorm CLI inspection (`inspect.sh`, dedicated profile)
5. PHPUnit (`core/phpunit.xml.dist`)

## Scope Modes

Use these options:
- `--mode strict|changed` (default `strict`)
- `--module <machine_name>` (mutually exclusive with `--theme`)
- `--theme <machine_name>` (mutually exclusive with `--module`)
- `--paths <space-separated paths...>` (mutually exclusive with `--module`/`--theme`; accepts a single file)
- `--ide-inspect on|off` (default `on`)
- `--ide-profile <path>` (default `references/phpstorm-profile.xml`)
- `--ide-bin <path>` (default `/Applications/PhpStorm.app/Contents/bin/inspect.sh`)
- `--final-validation on|off` (default `off`)

Behavior:
- `strict`: lint `modules/custom` + `themes/custom`; PHPCS both; PHPStan on `modules/custom`; PHPUnit on all custom modules with tests.
- `changed`: run on changed custom PHP files in Git diff; PHPUnit on affected custom modules that contain tests.
- `--module`: run all gates on one module; PHPUnit only for that module tests if present.
- `--theme`: run all gates on one theme; PHPUnit only for that theme tests if present.
- `single file`: run with `--paths <file>`; lint/PHPCS/PHPStan target the file; PHPUnit runs related module/theme tests if present, otherwise skip.
- `--paths`: run all gates on provided paths; PHPUnit only for derived module/theme test directories when present.

## Hard Rules

- Do not edit repository files.
- Fail with non-zero exit code if any stage fails.
- Treat missing tests as skip, not failure.
- IDE inspection is fail-hard when enabled:
  - missing `inspect.sh` is failure
  - unavailable runner state (for example active IDE instance lock) is failure
  - missing/invalid inspection report is failure
  - report paths using `file://$PROJECT_DIR$/...` must be resolved and counted
  - parser counts tracked PHP quality families only (unhandled exception, missing
    throws, polymorphic call, redundant cast)
- Final-validation mode is fail-hard on source coverage:
  - `--final-validation on` requires `--ide-inspect on`
  - runs with `--ide-inspect off` are triage only, not clean verdicts
- Report stage-by-stage status summary at the end.

## Output Contract

Return output in this order:
1. Scope and resolved targets
2. Stage logs (`lint`, `phpcs`, `phpstan`, `phpstorm_inspect`, `phpunit`)
3. Final summary with pass/fail per stage
4. Exit code semantics (`0` pass, `1` failure)

## Dual-Source Validation Contract

Validation is clean only when both sources are clean:
1. Script gates (`lint`, `phpcs`, `phpstan`, `phpstorm_inspect`, `phpunit`)
2. User-provided concrete findings (line-level) are either fixed or explicitly reconciled.

If a user provides concrete findings:
- do not report “clean” until each item is mapped to:
  - file + line
  - source tool/inspection
  - resolution status (`fixed` or `intentional with rationale`)

## Exception Handling Policy Matrix

Use one of these two exception-handling modes when fixing quality findings.

- `CRITICAL_STOP`
  - Use for install/update lifecycle code (`*.install`, `hook_install()`,
    `hook_update_N()`, `post_update_NAME()`, install/update helpers).
  - Use when failure can break schema/config/data integrity or when no safe fallback exists.
  - Catch narrow lower-level exceptions and rethrow a domain exception.
    For Drupal install/update flows, prefer `\Drupal\Core\Utility\UpdateException`.
  - Never swallow exceptions; abort execution for the failing operation.
  - `@throws` must list all exception types that can escape the method.

- `RECOVERABLE_CONTINUE`
  - Use for non-critical, best-effort runtime operations where safe fallback exists.
  - Catch expected exceptions, log with Drupal logger/watchdog, include operation context.
  - Show messenger warning/error only in interactive web request context.
    Do not use messenger in non-interactive CLI/background execution.
  - Return deterministic fallback and continue execution.
  - Handled exceptions should not escape; do not add `@throws` for swallowed failures.

## Issue Fix Playbook

## User-Reported Findings Reconciliation

When user supplies a concrete warning list, reconcile line-by-line before final status:

1. Create a table/list mapping each reported item to:
   - exact file path and line
   - category (exception handling, PHPDoc, polymorphic call, cast, etc.)
   - fix action taken
   - re-validation result
2. If any item is not fixed:
   - keep overall status as not clean
   - explain why and what remains.
3. Never claim file-level clean status from a single gate when stronger
   user-provided/IDE findings remain unresolved.

When quality checks report `Unhandled exception`, `Missing @throws tag(s)`, or
`PHPDoc comment doesn't contain all necessary @throws tags`, apply these rules:

1. Classify the method with this checklist:
   - Is this install/update lifecycle code?
   - Would failure break schema/config/data integrity?
   - Is the operation optional or best-effort?
   - Is a safe deterministic fallback available?
2. If classified as `CRITICAL_STOP`:
   - Wrap lower-level failures and rethrow domain exception.
   - For install/update helpers, use `\Drupal\Core\Utility\UpdateException`.
   - Never continue after exception in lifecycle helpers/hooks.
   - Keep PHPDoc complete: every escaped exception type must be listed in `@throws`.
3. If classified as `RECOVERABLE_CONTINUE`:
   - Catch narrow exceptions where feasible (`InvalidPluginDefinitionException`,
     `PluginNotFoundException`, `EntityStorageException`), and use `\Throwable` only
     at integration boundaries where multiple runtime failures are possible.
   - Log with operation context, optionally show messenger alert in interactive web requests.
   - Return deterministic fallback value and continue execution.
   - Keep handled exceptions internal (no escaping `@throws` for swallowed failures).
4. Re-run single-file scope after changes:
   `run_prebuild_quality.sh --paths <file>` and verify all stages pass.

When quality checks report unhandled exceptions in runtime services/builders
(for example page data builders), use this focused policy:

1. Map severity by layer:
   - Runtime services/builders: `RECOVERABLE_CONTINUE`.
   - Install/update helpers/hooks: `CRITICAL_STOP`.
2. Check common Drupal throw sources at integration boundaries:
   - `EntityTypeManagerInterface::getStorage()` plugin exceptions.
   - Entity query execution exceptions.
   - `FileUrlGeneratorInterface::generateString()` stream wrapper exceptions.
   - `AliasManagerInterface::getAliasByPath()` invalid argument exceptions.
   - Typed-data field/property access (`get()`, `first()`) throwing
     `\InvalidArgumentException` / `\Drupal\Core\TypedData\Exception\MissingDataException`.
3. For runtime service methods:
   - Catch narrow exceptions first, then `\Throwable` only at hard integration boundaries.
   - Log with watchdog/logger including operation key and context.
   - Return deterministic fallback payloads (`[]`, `''`, `'/'`) and continue.
   - Do not add messenger in service-layer utility classes.
   - Prefer local safe-access helpers for repeated typed-data reads to avoid
     scattered try/catch duplication.
4. Keep `@throws` aligned with behavior:
   - Do not advertise `@throws` for handled runtime recoverable exceptions.
   - Keep explicit `@throws` only for exceptions intentionally allowed to escape.

When quality checks report `Possible polymorphic call` / `Potentially polymorphic call`
or undefined-symbol style warnings on entity objects, apply these rules:

1. Add explicit runtime type narrowing before method calls on loaded entities.
2. Use strict `NULL` checks for loaded entities (`$entity === NULL`) before branching.
3. Add defensive `instanceof` guards and fail early with domain exception if type is unexpected.
4. Add precise PHPDoc type annotations for storages and loaded entities where practical.
5. Keep mutation calls (`set('theme', ...)`, `setRegion`, `save`, etc.) only in code paths where type is proven.

When quality checks report `Undefined method` / `Undefined symbols`, apply these rules:

1. Verify the target class API before fixing (core/entity class may not expose the method name reported in code).
2. Prefer methods guaranteed by the narrowed concrete class or interface on the current code path.
3. For Drupal entities without dedicated setters, use field API mutation:
   - Example: use `$block->set('theme', 'iru_ip')` instead of `$block->setTheme('iru_ip')`.
4. Combine method fixes with explicit type narrowing (`instanceof`) to avoid polymorphic-call regressions.
5. Re-run single-file scope after change:
   `run_prebuild_quality.sh --paths <file>`.

When analysis reports `Exception "<Type>" is never thrown in the corresponding "try" block`,
apply these rules:

1. Do not keep stale or speculative catch types in a union catch.
2. Split integration boundaries into separate `try` blocks:
   - one block for operations with known narrow exceptions,
   - one block for broader runtime/integration failures (optional `\Throwable`).
3. Catch only exceptions that are actually thrown by the statements in each `try`.
4. If analyzer cannot prove framework-level throws (common with Drupal query/runtime internals),
   prefer boundary `catch (\Throwable $e)` with recoverable logging and fallback.
5. Keep operation keys specific in logs (`*_storage`, `*_query`, `*_url`) to preserve diagnostics.

When analysis reports `Argument matches the parameter's default value`, apply these rules:

1. Omit explicit arguments that equal the callee default value.
2. Keep explicit argument only when it improves readability in ambiguous call sites.
3. Prefer concise form for fluent APIs and builders.
4. Validate behavior remains unchanged after simplification.
5. Example: replace `->accessCheck(TRUE)` with `->accessCheck()`.

When analysis reports `Type cast is redundant`, apply these rules:

1. Remove casts where expression type is already guaranteed (`string`, `int`, etc.).
2. Keep casts only at unclear boundaries (mixed input, external payloads, user data).
3. Prefer native type guarantees from interfaces/return types over defensive casting.
4. Typical cleanup: logging/context arrays often do not need `(string)` around
   already-string return values.
5. Common Drupal menu helper case: remove redundant `(string)` for
   `$entity->language()->getId()` and for normalized state keys already
   guaranteed as string (for example `$state['langcode']` in a typed
   state array).
6. Re-run single-file scope after change to confirm no behavior regressions.

## Resources

- Script: `scripts/run_prebuild_quality.sh`
- PhpStorm parser: `scripts/count_phpstorm_issues.php`
- Quick validator: `scripts/quick_validate.py`
- PhpStorm profile: `references/phpstorm-profile.xml`
- Reference: `references/drupal11-quality-commands.md`

Read `references/drupal11-quality-commands.md` when command details are needed.
