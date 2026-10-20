## 0.2.1

- Added `SeaGlassStyle.shadowColor`. It sets the cast and contact shadow colour, and its alpha
  scales their opacity, so `Colors.transparent` turns them off. Null keeps the default.
- Added `SeaGlassShape.squircle`, a squarer rounded rectangle (corner radius 28% of the short side).
- Updated the docs, screenshots and promo, and refactored the example code.

## 0.2.0

- Added `SeaGlassStyle.shadowDegrees` (default 180, straight down). It sets the direction of the
  cast and contact shadows and the transmitted colour pool.
- Added `SeaGlassStyle.shadowTinted` (default false). It tints the cast and contact shadows with
  the body pigment.
- Both are extensions to the original and only change the ground light. The glass body shader is
  untouched, so the default output stays the same. Each variant is tested against the Kotlin
  exporter, which applies the same change to the original ground code path.
- Example: a Shadow slider and a Tinted shadow switch in the Playground, plus a shadow screenshot.
- Example: promo clips (`button`, `screen`, `tumble`, `release`) rendered at phone resolution.
- Package: Apache 2.0 LICENSE and NOTICE, pub.dev topics and screenshots.

## 0.1.1

- Require Flutter 3.41 and ask for float32 geometry textures explicitly. The default target format
  could store 8-bit channels on Impeller.
- `SeaGlass` with `alignment` or `padding` now paints and clips the whole box, not just the child.
- A resized piece stretches its previous geometry instead of disappearing.
- A -> B -> A edits keep A on screen, and a failed geometry build is no longer retried every frame.
- Shared-cache handles are cloned before eviction can dispose them.
- Each piece reuses one fragment shader, and the ground light is rasterized once per change
  instead of being blurred again on every frame.
- If shaders or float textures are unavailable, the widget draws a flat fallback instead of
  nothing.
- Removed the unused `SeaGlassDecoration`. Button semantics are no longer duplicated.
- Example: Quick settings and Pill pages, plus a screenshot test.

## 0.1.0

- First Flutter port. Includes `SeaGlass`, `SeaGlassSurface`, `SeaGlassButton`, `SeaGlassTheme`,
  `SeaGlassMaterialTheme`, the `reference`, `tumbled` and `quiet` recipes, and five palettes.
