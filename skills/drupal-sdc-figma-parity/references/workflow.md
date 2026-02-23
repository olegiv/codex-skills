# Workflow

## 1) Acquire Figma Truth

1. Parse:
   - `fileKey`
   - `nodeId`
2. Fetch:
   - `get_design_context(fileKey, nodeId)`
   - `get_screenshot(fileKey, nodeId)`
3. Optional:
   - `get_metadata(fileKey, nodeId)` for large/truncated structures.
   - `get_variable_defs(fileKey, nodeId)` for exact token verification.

## 2) Lock Comparison Size

1. Read target `W x H` from Figma screenshot.
2. Set capture viewport/crop to same `W x H`.
3. Enforce zoom `100%`.
4. Never assume global fixed size like `1440x300` unless that is the actual node size.

## 3) Implement

1. Reuse existing theme/component structure.
2. Apply node geometry and spacing from Figma output.
3. Keep changes in allowed project scope.

## 4) Validate (Per Iteration)

1. Post Figma screenshot in chat (target state).
2. Post Drupal screenshot in chat (same `W x H`).
3. Enumerate differences by element:
   - Position
   - Size
   - Spacing
   - Typography
   - Colors
   - Icon glyph/placement
4. Wait for user validation before next iteration.

