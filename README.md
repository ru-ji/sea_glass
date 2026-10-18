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
`test/kotlin_parity_test.dart` compares this package with the original implementation.
`tool/kotlin_reference/export.sh` compiles the original Kotlin geometry sources unchanged, renders
the original `SeaGlassBodyShader` through Skia (skiko 0.9.37.4, as shipped with Compose 1.10.3)
and exports reference data. The pinned commit is in `test/fixtures/kotlin/REVISION`. Results
over five cases (rounded, disc, capsule, portrait, and a large piece above the sample budget):

| Stage | Result |
| --- | --- |
| Random stream, contour points | identical (also vs the web reference) |
| Contour mask rasterization | identical bytes |
| Geometry textures (profiles, gradients, scales) | bit-identical floats |
| Body shader, Kotlin textures | pixel-identical RGBA |
| Body shader, full Dart pipeline | pixel-identical RGBA |
| Ground light (shadows, transmitted light) | max 3/255 per channel, mean below 1/255 |

The ground difference does not come from the recipe. With blur disabled, alpha is identical and
premultiplied color still differs by a few levels, because the two Skia builds round translucent
blending differently. The original also uses each platform's own blur.

`shaders/sea_glass.frag` is a mechanical translation of `SeaGlassBodyShader.kt`. Only type
names, the entry point and texture sampling (plus a `geometrySize` uniform) differ. Textures are
rounded to binary16 before upload, as the original uploads RGBA_F16.

### First frame
Flutter cannot read back a rasterized mask or create an image synchronously, so a piece's first
geometry is built asynchronously. A piece never shows partially: ground and body appear together.
To draw on the very first frame, as the original does, precache the size:

```dart
await SeaGlass.precache(const Size(270, 88), style: SeaGlassStyle.reference.copyWith(seed: 33));
```

Built geometry is kept in a shared LRU (32 entries, like the original), so revisited screens and
repeated pieces also draw immediately.

### Not yet verified
- Rendering on a device or emulator. Impeller (the default on iOS and Android) may round
  differently from the Skia software renderer used by `flutter test`.

- The material paints up to 48 px outside its layout box; avoid clipping ancestors.

Credit: material design and shader math by [mttmcknn/sea-glass](https://github.com/mttmcknn/sea-glass); see its license.
