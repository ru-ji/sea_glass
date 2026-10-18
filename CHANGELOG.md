## 0.2.0
- `SeaGlassStyle.shadowDegrees` (default 180, down): direction of the cast and contact shadows, the
  transmitted color pool and the body's luminous exit edge. An extension of the original, which
  always casts downward; at 180 the output is unchanged and bit-identical to it.
- Example: Shadow slider in the Playground and a shadow-directions screenshot.

## 0.1.1
- Require Flutter 3.41 and request float32 geometry textures explicitly; the default target format
  could store 8-bit channels on Impeller.
- `SeaGlass` with `alignment` or `padding` now paints and clips the whole box, not just the child.
- While a piece is resized, the previous geometry is stretched instead of disappearing.
- A -> B -> A edits keep A displayed; failed geometry builds are no longer retried on every frame.
- Shared-cache handles are cloned before eviction can dispose them.
- One reusable fragment shader per piece, and the ground light is rasterized once per change instead
  of re-blurred every frame.
- Flat fallback when shaders or float textures are unavailable, instead of drawing nothing.
- Removed the unused `SeaGlassDecoration`; button semantics are no longer duplicated.
- Example: Quick settings and Pill pages, plus a screenshot test.

## 0.1.0
- Initial Flutter port: `SeaGlass`, `SeaGlassSurface`, `SeaGlassButton`, `SeaGlassTheme`, `SeaGlassMaterialTheme`, recipes (`reference`, `tumbled`, `quiet`) and five palettes.
