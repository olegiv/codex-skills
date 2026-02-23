---
name: drupal-sdc-figma-parity
description: Drupal SDC Figma-to-code pixel-parity workflow using direct Figma MCP tools, with screenshot-gated validation and node-specific capture dimensions.
---

# Drupal SDC Figma Parity

Use this skill for any request that asks to match a Figma node/frame in Drupal with pixel parity.

## Core Rules

1. Use direct Figma MCP tools only:
   - `get_design_context`
   - `get_screenshot`
   - `get_metadata` (only when context is too large)
   - `get_variable_defs` (when token/value confirmation is needed)
2. Do not use CLI wrapper flows like `/figma-to-sdc`.
3. Visual source of truth is browser-visible Figma output.
4. Screenshot gate is mandatory:
   - Post Figma screenshot first.
   - Implement.
   - Post Drupal screenshot.
   - Compare and list differences.
   - Wait for user validation before next cycle.

## Capture and Comparison Sizing (Locked)

1. Global default zoom is always `100%`.
2. Do not use hardcoded default viewport sizes.
3. Capture size is node-specific:
   - Read `W x H` from the target Figma node screenshot.
   - Capture Drupal at the same `W x H`.
4. If target element is part of a larger page:
   - Capture full page as needed.
   - Crop to the target region that matches node geometry.
5. User can explicitly override size rules; otherwise node size is authoritative.

## Required Flow

1. Parse `fileKey` and `nodeId` from the Figma URL.
2. Fetch design context for exact target node.
3. Fetch screenshot for exact target node/state.
4. Determine comparison `W x H` from the Figma screenshot dimensions.
5. Implement in allowed project scope only.
6. Build/cache refresh only when required by changed files.
7. Capture Drupal screenshot at matching `W x H`.
8. Compare and report mismatches by element.
9. Iterate until validated by user.

## Project Boundaries

Allowed mutation scope:
- `modules/custom/**`
- `themes/custom/**`
- project-specific scripts/docs

Forbidden:
- `core/**`
- `vendor/**`
- `node_modules/**`
- `.git/**`

## References

- `references/workflow.md`
- `references/validation-gates.md`
- `references/drupal-iru-checks.md`

## Example Prompt

```text
Use drupal-sdc-figma-parity skill.
Migrate this Figma node to Drupal with pixel parity:
https://figma.com/design/<fileKey>/<fileName>?node-id=<nodeId>

Rules:
- Use direct Figma MCP only (no figma-to-sdc CLI wrappers).
- Post Figma screenshot first.
- Implement in modules/custom/** and themes/custom/** only.
- Capture Drupal screenshot at the same node-derived W x H (100% zoom).
- Compare and list differences, then wait for my validation.
```
