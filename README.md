# sea_glass

Frosted, softly tumbled glass for Flutter — a port of the **Sea Glass** material concept
([mttmcknn/sea-glass](https://github.com/mttmcknn/sea-glass), Compose) for Material 3 apps.
Seeded organic outlines, microscopic frost, a curved coloured interior, a luminous lower edge
and soft transmitted light beneath each piece. Text and icons stay normal widgets.

```dart
SeaGlassButton(
  onPressed: compose,
  palette: SeaGlassPalette.lagoon,
  style: SeaGlassStyle.reference.copyWith(seed: 33),
  child: const Text('Compose'),
)
```

## Widgets
- `SeaGlassButton` – semantics, 48 px minimum target, focus outline, disabled state, 2 px press offset.
- `SeaGlassSurface` – non-interactive container (clips content to the outline, sets ink colour).
- `SeaGlass` – material behind any child; `clipChild` optional.
- `SeaGlassTheme` – inheritable defaults (`style`, `palette`, `shape`); nested themes override only what they set.
- `SeaGlassComponentStyle` – style + palette + shape bundle for design systems.

## Recipes and palettes
`SeaGlassStyle.reference / tumbled / quiet`, or `copyWith(frost, grain, tumble, thickness, bulge, elevation, lightDegrees, transmission, seed)`.
Palettes: `lagoon, lilac, rose, amber, mint`. Shapes: `rounded, capsule, disc`.
Keep each piece's `seed` stable; use different seeds for neighbours.

## Material 3 / dynamic colour
```dart
SeaGlassMaterialTheme(child: ...)                    // ambient ColorScheme, primary container
SeaGlassPalette.of(context, SeaGlassColorRole.tertiary)
SeaGlassPalette.fromColorScheme(dynamicScheme)       // e.g. from dynamic_color
```

## Fidelity to the original
- `shaders/sea_glass.frag` is a mechanical translation of `SeaGlassBodyShader.kt`. Only type names
  (`float2`→`vec2`, …), the entry point and texture sampling (`eval` → `texture`, plus a
  `geometrySize` uniform) differ. Every equation and constant is unchanged.
- The geometry pipeline is ported line by line: the seeded Mulberry32 stream, the tumbled B-spline
  contour, the Euclidean distance transform, tanh/arch profiles, cloud noise, height smoothing,
  gradient encoding and the 262,144-sample budget. Textures are uploaded as opaque RGBA float32
  with bilinear sampling.
- Ground light ports `RealtimeGround`: the same three layers, offsets, Gaussian sigmas, colors
  and transmission gradient, each blurred as a whole.
- Tests check the random stream and contour points against fixtures generated from the original
  web reference (`test/fixtures/web_reference.json`).
- Platform rasterization and blur can differ by subpixel amounts, as they already do between the
  original's Android and Skia targets.
- Geometry is built asynchronously (mask readback needs a frame), so on first paint only the
  ground light shows until the body arrives, typically one frame later. Later edits keep the last
  complete geometry visible, as in the original.
- If fragment shaders are unavailable, only the ground light is drawn.
- The material paints up to 48 px outside its layout box; avoid clipping ancestors.
- Not yet verified on a device or emulator.

Credit: material design and shader math by [mttmcknn/sea-glass](https://github.com/mttmcknn/sea-glass); see its license.
