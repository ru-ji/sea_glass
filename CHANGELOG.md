## 0.2.0
- `SeaGlassStyle.shadowDegrees` (default 180, down) sets the direction of the cast and contact
  shadows and the transmitted color pool.
- `SeaGlassStyle.shadowTinted` (default false) tints the cast and contact shadows with the body
  pigment.
- Both are extensions of the original and affect only the ground light; the glass body shader is
  the original's. With the defaults the output is unchanged. Each variant is tested against the
  Kotlin exporter, which applies the same extension to the original ground code path.
- Example: Shadow slider and Tinted shadow switch in the Playground, and a shadow screenshot.

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
