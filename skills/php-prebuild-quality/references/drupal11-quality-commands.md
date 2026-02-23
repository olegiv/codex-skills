# Drupal 11 PHP Quality Commands

## Scope Commands

Strict (default):

```bash
$CODEX_HOME/skills/php-prebuild-quality/scripts/run_prebuild_quality.sh
```

Changed files:

```bash
$CODEX_HOME/skills/php-prebuild-quality/scripts/run_prebuild_quality.sh --mode changed
```

Module:

```bash
$CODEX_HOME/skills/php-prebuild-quality/scripts/run_prebuild_quality.sh --module iru_datalayer
```

Theme:

```bash
$CODEX_HOME/skills/php-prebuild-quality/scripts/run_prebuild_quality.sh --theme iru_ip
```

Explicit paths:

```bash
$CODEX_HOME/skills/php-prebuild-quality/scripts/run_prebuild_quality.sh --paths modules/custom/iru_datalayer themes/custom/iru_ip
```

Disable IDE inspection:

```bash
$CODEX_HOME/skills/php-prebuild-quality/scripts/run_prebuild_quality.sh --ide-inspect off
```

Final validation (clean verdict mode):

```bash
$CODEX_HOME/skills/php-prebuild-quality/scripts/run_prebuild_quality.sh --module iru_briefing --final-validation on
```

Custom IDE profile and binary:

```bash
$CODEX_HOME/skills/php-prebuild-quality/scripts/run_prebuild_quality.sh --paths modules/custom/iru_briefing/iru_briefing.install --ide-profile $CODEX_HOME/skills/php-prebuild-quality/references/phpstorm-profile.xml --ide-bin /Applications/PhpStorm.app/Contents/bin/inspect.sh
```

Single file:

```bash
$CODEX_HOME/skills/php-prebuild-quality/scripts/run_prebuild_quality.sh --paths modules/custom/iru_datalayer/src/Form/SettingsForm.php
```

## Underlying Tools

- Lint: `php -l`
- PHPCS:
  `./vendor/bin/phpcs --standard=Drupal,DrupalPractice --extensions=php,module,inc,install,theme,profile,engine`
- PHPStan:
  `./vendor/bin/phpstan analyse -c phpstan.neon`
- PHPUnit:
  `./vendor/bin/phpunit -c core/phpunit.xml.dist`
- PhpStorm CLI inspection:
  `/Applications/PhpStorm.app/Contents/bin/inspect.sh <project> <profile.xml> <output_dir> -format json -d <scope_target>`

## Notes

- `--module` and `--theme` are mutually exclusive.
- `--paths` cannot be combined with `--module` or `--theme`.
- Missing tests for the selected scope are reported as skip, not failure.
- IDE inspection is fail-hard when enabled (missing binary/profile, blocked inspection run, or invalid/missing JSON report => fail).
- `--final-validation on` requires `--ide-inspect on`; otherwise runner fails fast.
- Runs with `--ide-inspect off` are triage only and must not be treated as clean final validation.
- Parser resolves `file://$PROJECT_DIR$/...` report paths and counts tracked PHP quality inspections only.

Skill quick validation:

```bash
$CODEX_HOME/skills/php-prebuild-quality/scripts/quick_validate.py
```

## Reconciliation Rule

If the user provides concrete findings, do not mark validation clean until each
reported line is explicitly reconciled (`fixed` or `intentional with rationale`)
in addition to passing scripted gates.

## Exception Severity Modes

- `CRITICAL_STOP`: install/update lifecycle and integrity-critical flows.
- `RECOVERABLE_CONTINUE`: best-effort runtime flows with safe fallback.

Decision checklist:
1. Is this `*.install`, `hook_install()`, `hook_update_N()`, `post_update_NAME()`, or an install/update helper?
2. Can failure break schema/config/data integrity?
3. Is this optional/best-effort behavior?
4. Is deterministic fallback available?

## Fix Pattern: Critical Stop (Install/Update)

Use when execution must stop on failure.

1. Catch narrow lower-level exceptions where practical.
2. Wrap and rethrow as domain exception (`UpdateException` for install/update flows).
3. Keep full `@throws` coverage for escaped exceptions.

Example style:

```php
/**
 * @throws \Drupal\Core\Utility\UpdateException
 */
public static function doWork(): void {
  try {
    // integration call(s)
  }
  catch (\Throwable $e) {
    throw new \Drupal\Core\Utility\UpdateException(sprintf('Operation failed: %s', $e->getMessage()));
  }
}
```

## Fix Pattern: Recoverable Continue (Runtime Best-Effort)

Use when execution should continue with fallback behavior.

1. Catch expected exceptions.
2. Log with Drupal logger/watchdog including operation context.
3. Show messenger warning/error only in interactive web request context.
4. Return deterministic fallback and continue.
5. Do not leak handled exceptions (`@throws` not needed for swallowed failures).

Example style:

```php
public function fetchOptionalPayload(string $entityId): array {
  try {
    return $this->provider->fetch($entityId);
  }
  catch (\RuntimeException $e) {
    $this->logger->warning(
      'Optional payload fetch failed for {entity_id}: {message}',
      ['entity_id' => $entityId, 'message' => $e->getMessage(), 'exception' => $e]
    );
    if ($this->requestStack->getCurrentRequest() !== NULL && PHP_SAPI !== 'cli') {
      $this->messenger->addWarning('Using fallback data because optional payload fetch failed.');
    }
    return [];
  }
}
```

Do:
- Stop lifecycle operations on exception.
- Log recoverable exceptions with actionable context.
- Return deterministic fallbacks in continue mode.

Don't:
- Continue silently after an exception.
- Use messenger in non-interactive CLI/background contexts.
- Swallow integrity-critical install/update failures.

Validate after fix:

```bash
$CODEX_HOME/skills/php-prebuild-quality/scripts/run_prebuild_quality.sh --paths <file>
```

## Fix Pattern: Possible Polymorphic Call

Use this remediation pattern when static analysis warns that method calls may fail
depending on runtime class:

1. Narrow entity/storage types explicitly.
2. Guard loaded entities with `instanceof`.
3. Throw a domain exception if an unexpected class is returned.

Example style:

```php
/** @var \Drupal\Core\Entity\EntityStorageInterface<\Drupal\block\BlockInterface> $storage */
$storage = \Drupal::entityTypeManager()->getStorage('block');
$loaded = $storage->load($blockId);
if ($loaded !== NULL && !$loaded instanceof \Drupal\block\Entity\Block) {
  throw new UpdateException(sprintf('Unexpected block entity class for "%s".', $blockId));
}
$block = $loaded;
if ($block === NULL) {
  $block = \Drupal\block\Entity\Block::create([...]);
}
if (!$block instanceof \Drupal\block\Entity\Block) {
  throw new UpdateException(sprintf('Cannot configure block "%s": invalid entity instance.', $blockId));
}
```

## Fix Pattern: Undefined Method / Undefined Symbols

Use this remediation pattern when static analysis reports missing method on an entity/class:

1. Confirm method exists on the concrete target class (not assumed from naming).
2. Narrow type first (`instanceof`) before method calls.
3. If no dedicated setter exists, use Drupal entity field API (`set(<field>, <value>)`).

Example style:

```php
if (!$block instanceof \Drupal\block\Entity\Block) {
  throw new UpdateException('Invalid block entity instance.');
}
if ($block->getTheme() !== 'iru_ip') {
  $block->set('theme', 'iru_ip');
}
if ($block->getRegion() !== 'footer_top') {
  $block->setRegion('footer_top');
}
```

## Fix Pattern: Unhandled Exceptions in Runtime Services/Builders

Use this remediation pattern for runtime page/service builders (non-install lifecycle):

1. Policy mapping:
   - Runtime builder/service => `RECOVERABLE_CONTINUE`.
   - Install/update lifecycle => `CRITICAL_STOP`.
2. Check common Drupal throw points:
   - `EntityTypeManagerInterface::getStorage()`
   - query execution
   - `FileUrlGeneratorInterface::generateString()`
   - `AliasManagerInterface::getAliasByPath()`
   - typed-data access (`get()`, `first()`, nested property reads)
3. Catch narrow exceptions first; use `\Throwable` only at integration boundaries.
4. Log with operation context and return deterministic fallback payload.
5. Do not use messenger in service-layer helper code.

Example style:

```php
try {
  $url = $this->fileUrlGenerator->generateString($file->getFileUri());
}
catch (\Drupal\Core\File\Exception\InvalidStreamWrapperException $e) {
  $this->logger->warning(
    'Recoverable exception in {operation}: {message}',
    ['operation' => 'build_image_url', 'message' => $e->getMessage(), 'exception' => $e]
  );
  $url = '';
}
```

Typed-data-safe helper style:

```php
private function getItemPropertyValueSafe(
  \Drupal\Core\Field\FieldItemInterface $item,
  string $property,
  string $operation,
  mixed $default = NULL,
): mixed {
  try {
    return $item->get($property)->getValue();
  }
  catch (\InvalidArgumentException | \Drupal\Core\TypedData\Exception\MissingDataException $e) {
    $this->logger->warning(
      'Recoverable exception in {operation}: {message}',
      ['operation' => $operation, 'message' => $e->getMessage(), 'exception' => $e]
    );
    return $default;
  }
}
```

## Fix Pattern: Exception Type Never Thrown in Try Block

Use this remediation when analyzer reports:
`Exception "<Type>" is never thrown in the corresponding "try" block`.

1. Remove stale catch types that are not thrown by the enclosed statements.
2. Split combined logic into distinct `try` boundaries (storage vs query vs URL generation).
3. Keep narrow catches only where provable.
4. For framework/runtime boundaries where static analysis is incomplete, use
   `catch (\Throwable $e)` with recoverable logging and fallback.

Example style:

```php
try {
  $storage = $this->entityTypeManager->getStorage('node');
}
catch (\Drupal\Component\Plugin\Exception\InvalidPluginDefinitionException | \Drupal\Component\Plugin\Exception\PluginNotFoundException $e) {
  // storage fallback
  return [];
}

try {
  $nids = $storage->getQuery()->condition('status', 1)->execute();
}
catch (\Throwable $e) {
  // query fallback
  return [];
}
```

## Fix Pattern: Argument Matches Parameter Default Value

Use this remediation when analyzer reports:
`Argument matches the parameter's default value`.

1. Remove redundant explicit argument when it equals the method default.
2. Keep explicit argument only if needed for clarity in non-obvious call sites.
3. Re-run file scope checks to confirm no behavior change.

Example style:

```php
// Before.
$query->accessCheck(TRUE);

// After (default is TRUE).
$query->accessCheck();
```

## Fix Pattern: Type Cast Is Redundant

Use this remediation when analyzer reports:
`Type cast is redundant`.

1. Remove casts when the source expression is already strongly typed.
2. Keep casts only where type is genuinely ambiguous.
3. Common Drupal case: remove redundant `(string)` in logging/context arrays.
4. Common Drupal install/update helper case: remove redundant `(string)` for
   `$link->language()->getId()` and for `$state['langcode']` when state is
   already normalized to string.

Example style:

```php
// Before.
['title' => (string) $link->getTitle()]

// After.
['title' => $link->getTitle()]
```

```php
// Before.
'langcode' => (string) $link->language()->getId();
$link->set('langcode', (string) $state['langcode']);

// After.
'langcode' => $link->language()->getId();
$link->set('langcode', $state['langcode']);
```
