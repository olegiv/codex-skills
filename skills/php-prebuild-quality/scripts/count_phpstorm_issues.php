<?php

declare(strict_types=1);

if ($argc < 4) {
  fwrite(STDERR, "Usage: count_phpstorm_issues.php <report_dir> <root> <target...>\n");
  exit(2);
}

$reportDir = $argv[1];
$root = normalize_path($argv[2], NULL);
$targets = [];
for ($i = 3; $i < $argc; $i++) {
  $normalized = normalize_path($argv[$i], $root);
  if ($normalized !== '') {
    $targets[] = $normalized;
  }
}
if ($targets === []) {
  $targets[] = $root;
}

if (!is_dir($reportDir)) {
  fwrite(STDERR, sprintf("Report dir does not exist: %s\n", $reportDir));
  exit(2);
}

$issues = [];
$seen = [];

$iterator = new RecursiveIteratorIterator(
  new RecursiveDirectoryIterator($reportDir, FilesystemIterator::SKIP_DOTS)
);

foreach ($iterator as $item) {
  if (!$item->isFile() || strtolower((string) $item->getExtension()) !== 'json') {
    continue;
  }

  $raw = @file_get_contents($item->getPathname());
  if (!is_string($raw) || trim($raw) === '') {
    continue;
  }

  $decoded = json_decode($raw, TRUE);
  if (!is_array($decoded)) {
    continue;
  }

  walk_node($decoded, $targets, $root, $issues, $seen);
}

echo 'COUNT=' . count($issues) . PHP_EOL;
foreach (array_slice($issues, 0, 20) as $issue) {
  $lineSuffix = $issue['line'] !== '' ? ':' . $issue['line'] : '';
  echo sprintf('ISSUE %s%s - %s', $issue['file'], $lineSuffix, $issue['message']) . PHP_EOL;
}

function walk_node(mixed $node, array $targets, string $root, array &$issues, array &$seen): void {
  if (!is_array($node)) {
    return;
  }

  $candidatePath = '';
  foreach (['file', 'path', 'url'] as $key) {
    if (isset($node[$key]) && is_string($node[$key])) {
      $candidatePath = normalize_path($node[$key], $root);
      if ($candidatePath !== '') {
        break;
      }
    }
  }

  $description = '';
  if (isset($node['description']) && is_string($node['description'])) {
    $description = trim($node['description']);
  }
  elseif (isset($node['problem']) && is_string($node['problem'])) {
    $description = trim($node['problem']);
  }
  elseif (isset($node['problem_class']) && is_array($node['problem_class']) && isset($node['problem_class']['name']) && is_string($node['problem_class']['name'])) {
    $description = trim($node['problem_class']['name']);
  }

  $line = '';
  if (isset($node['line']) && (is_int($node['line']) || is_string($node['line']))) {
    $line = trim((string) $node['line']);
  }

  $inspection_id = extract_inspection_id($node);
  $is_tracked = is_tracked_inspection($inspection_id, $description);

  $isIssueLike = $candidatePath !== ''
    && $is_tracked
    && ($description !== '' || $line !== '' || array_key_exists('severity', $node) || array_key_exists('inspection', $node) || array_key_exists('problem_class', $node));

  if ($isIssueLike && path_matches_targets($candidatePath, $targets)) {
    $message = $description !== '' ? $description : 'Inspection issue';
    $key = $candidatePath . '|' . $line . '|' . $message;
    if (!isset($seen[$key])) {
      $issues[] = [
        'file' => $candidatePath,
        'line' => $line,
        'message' => $message,
      ];
      $seen[$key] = TRUE;
    }
  }

  foreach ($node as $child) {
    walk_node($child, $targets, $root, $issues, $seen);
  }
}

function normalize_path(string $path, ?string $root): string {
  $path = trim($path);
  if ($path === '') {
    return '';
  }

  $path = preg_replace('#^file://#', '', $path) ?? $path;
  $path = rawurldecode($path);
  $path = str_replace('\\', '/', $path);

  if ($root !== NULL) {
    $normalized_root = rtrim(str_replace('\\', '/', $root), '/');
    if ($path === '$PROJECT_DIR$') {
      $path = $normalized_root;
    }
    elseif (str_starts_with($path, '$PROJECT_DIR$/')) {
      $path = $normalized_root . substr($path, strlen('$PROJECT_DIR$'));
    }
  }

  if ($root !== NULL && !str_starts_with($path, '/')) {
    $path = rtrim($root, '/') . '/' . ltrim($path, '/');
  }

  $resolved = realpath($path);
  if ($resolved !== FALSE) {
    $path = str_replace('\\', '/', $resolved);
  }

  return rtrim($path, '/');
}

function path_matches_targets(string $path, array $targets): bool {
  foreach ($targets as $target) {
    if ($path === $target || str_starts_with($path, $target . '/')) {
      return TRUE;
    }
  }
  return FALSE;
}

function extract_inspection_id(array $node): string {
  if (isset($node['problem_class']) && is_array($node['problem_class']) && isset($node['problem_class']['id']) && is_string($node['problem_class']['id'])) {
    return trim($node['problem_class']['id']);
  }

  if (isset($node['inspection']) && is_string($node['inspection'])) {
    return trim($node['inspection']);
  }

  if (isset($node['inspectionTool']) && is_string($node['inspectionTool'])) {
    return trim($node['inspectionTool']);
  }

  return '';
}

function is_tracked_inspection(string $inspectionId, string $description): bool {
  static $tracked_ids = [
    'PhpUnhandledExceptionInspection',
    'PhpDocMissingThrowsInspection',
    'PhpPossiblePolymorphicInvocationInspection',
    'PhpRedundantCastingInspection',
    // PhpStorm emits this ID for "Type cast is redundant".
    'PhpCastIsUnnecessaryInspection',
  ];

  if ($inspectionId !== '' && in_array($inspectionId, $tracked_ids, TRUE)) {
    return TRUE;
  }

  $message = strtolower($description);
  if ($message === '') {
    return FALSE;
  }

  return str_contains($message, 'unhandled exception')
    || str_contains($message, '@throws')
    || str_contains($message, 'polymorphic call')
    || str_contains($message, 'type cast is redundant')
    || str_contains($message, 'type cast is unnecessary');
}
