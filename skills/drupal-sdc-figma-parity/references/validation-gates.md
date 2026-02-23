# Validation Gates

## Mandatory Sequence

1. `Gate A`: Figma screenshot posted (exact target node/state).
2. `Gate B`: Drupal screenshot posted (same `W x H`, zoom `100%`).
3. `Gate C`: Mismatch list posted, grouped by element.
4. `Gate D`: User validation received before further iteration.

## Sizing Gate

1. Capture size must be derived from Figma screenshot dimensions.
2. Hardcoded default viewport sizes are disallowed.
3. If element is within larger page, crop to node-matching region.

## Diff Gate

1. Automated diff can be used as supporting evidence.
2. Automated pass alone is not sufficient.
3. Final acceptance requires side-by-side visual screenshots and user sign-off.

## Common Failure Blocks

1. Container matches but glyph does not.
2. Correct `W x H` but wrong internal alignment.
3. Captures polluted by overlays/banners.
4. Wrong interaction state during capture.

