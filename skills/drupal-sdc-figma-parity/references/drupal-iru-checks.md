# Drupal IRU Checks

## Allowed Change Scope

- `modules/custom/**`
- `themes/custom/**`
- project-specific scripts/docs

## Build and Runtime

1. Run `npm run build` only if frontend sources changed.
2. Run `./vendor/bin/drush cr` when required (Twig/YAML/services/rendering updates).
3. Avoid repeated rebuilds without changed inputs.

## Capture Hygiene

1. Neutralize overlays (cookie banners, popups) before capture.
2. Ensure target interaction state matches Figma node state.
3. Keep browser zoom at `100%`.
4. Use node-derived `W x H` for screenshot/crop.

## Comparison Notes

1. Validate both macro layout and micro glyph placement.
2. Call out exact differences with coordinates/dimensions when possible.
3. Iterate in small deltas, one visual issue group per pass.

