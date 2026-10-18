import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'contour.dart';
import 'material_field.dart';
import 'random.dart';
import 'style.dart';

/// Transparent gutter the material may draw into outside its layout box.
const double kSeaGlassPadding = 48.0;

/// Loads the fragment program once. Resolves to null if shaders are unavailable
/// (unsupported backend, unit tests); painters then draw only the ground light.
class SeaGlassShaderProgram {
  SeaGlassShaderProgram._();

  static const String asset = 'packages/sea_glass/shaders/sea_glass.frag';
  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram?>? _loading;

  static ui.FragmentProgram? get loaded => _program;

  static Future<ui.FragmentProgram?> load() => _loading ??= () async {
        // The package-relative key applies inside this package's own tests.
        for (final key in const [asset, 'shaders/sea_glass.frag']) {
          try {
            return _program = await ui.FragmentProgram.fromAsset(key);
          } catch (_) {}
        }
        debugPrint('sea_glass: shader unavailable');
        return null;
      }();
}

@immutable
class GeometryKey {
  const GeometryKey(this.widthDp, this.heightDp, this.shape, this.tumble, this.seed, this.fieldScale);
  final double widthDp, heightDp, tumble, fieldScale;
  final SeaGlassShape shape;
  final int seed;

  bool sameSize(Size s) => widthDp == s.width && heightDp == s.height;

  @override
  bool operator ==(Object other) =>
      other is GeometryKey && other.widthDp == widthDp && other.heightDp == heightDp && other.shape == shape &&
      other.tumble == tumble && other.seed == seed && other.fieldScale == fieldScale;

  @override
  int get hashCode => Object.hash(widthDp, heightDp, shape, tumble, seed, fieldScale);
}

class LiveGeometry {
  LiveGeometry(this.key, this.path, this.a, this.b, this.width, this.height, this.gradientScaleA, this.gradientScaleB);
  final GeometryKey key;
  final Path path;
  final ui.Image a, b;
  final int width, height;
  final double gradientScaleA, gradientScaleB;

  /// A handle sharing the same GPU images; dispose each handle independently.
  LiveGeometry clone() => LiveGeometry(key, path, a.clone(), b.clone(), width, height, gradientScaleA, gradientScaleB);

  int get byteSize => width * height * 16 * 2;

  void dispose() {
    a.dispose();
    b.dispose();
  }
}

/// Shared LRU of immutable geometry (like the reference's
/// sharedLiveMaterialGeometryCache): up to 32 entries within a texture budget.
/// Matching pieces, revisited screens and precached sizes draw on first paint.
class SeaGlassGeometryCache {
  SeaGlassGeometryCache._();

  static const int maxEntries = 32;
  static const int maxBytes = 32 << 20;
  static final Map<GeometryKey, LiveGeometry> _entries = {};
  static final Map<GeometryKey, Future<LiveGeometry?>> _building = {};
  static int _bytes = 0;

  /// A new handle to a cached geometry, or null.
  static LiveGeometry? lookup(GeometryKey key) {
    final g = _entries.remove(key);
    if (g == null) return null;
    _entries[key] = g; // most recently used
    return g.clone();
  }

  /// Builds (once per key) and caches; resolves to a new handle.
  static Future<LiveGeometry?> obtain(GeometryKey key) async {
    final hit = lookup(key);
    if (hit != null) return hit;
    final g = await (_building[key] ??= SeaGlassGeometryController._build(key)
      ..whenComplete(() => _building.remove(key)));
    if (g == null) return null;
    if (!_entries.containsKey(key)) {
      _entries[key] = g;
      _bytes += g.byteSize;
      while (_entries.length > maxEntries || (_bytes > maxBytes && _entries.length > 1)) {
        final oldest = _entries.keys.first;
        final evicted = _entries.remove(oldest)!;
        _bytes -= evicted.byteSize;
        evicted.dispose();
      }
    }
    return lookup(key) ?? g.clone();
  }

  /// Releases every cached geometry. Live pieces keep their own handles.
  static void clear() {
    for (final g in _entries.values) {
      g.dispose();
    }
    _entries.clear();
    _bytes = 0;
  }
}

/// Owns one piece's geometry (port of LiveMaterialRenderer's update model):
/// the last complete geometry stays visible while edits are prepared off the
/// paint path; one build is active and only the newest request is kept pending.
class SeaGlassGeometryController extends ChangeNotifier {
  LiveGeometry? _displayed;
  GeometryKey? _active, _pending;
  bool _disposed = false;
  final Map<GeometryKey, Path> _paths = {};

  static GeometryKey keyFor(Size size, SeaGlassShape shape, SeaGlassStyle style) {
    final fieldScale = math.min(1.0, math.sqrt(262144.0 / (size.width * size.height)));
    return GeometryKey(size.width, size.height, shape, style.tumble, style.seed, fieldScale);
  }

  /// Outline for clipping and ground light: the displayed geometry's when it
  /// matches the size, otherwise the requested outline (computed synchronously).
  Path pathFor(Size size, SeaGlassShape shape, SeaGlassStyle style) {
    final d = _displayed;
    if (d != null && d.key.sameSize(size)) return d.path;
    final key = keyFor(size, shape, style);
    if (_paths.length > 4) _paths.clear();
    return _paths[key] ??= _outline(key);
  }

  static Path _outline(GeometryKey k) => contourToPath(
      contourSegments(buildContour(k.widthDp, k.heightDp, shape: k.shape, tumble: k.tumble, seed: k.seed)));

  LiveGeometry? displayedFor(Size size) {
    final d = _displayed;
    return d != null && d.key.sameSize(size) ? d : null;
  }

  void request(Size size, SeaGlassShape shape, SeaGlassStyle style) {
    if (size.width < 1 || size.height < 1) return;
    final key = keyFor(size, shape, style);
    if (_displayed?.key == key || _active == key) {
      _pending = null;
      return;
    }
    // Cached geometry applies synchronously, during this paint.
    final cached = SeaGlassGeometryCache.lookup(key);
    if (cached != null) {
      _displayed?.dispose();
      _displayed = cached;
      _pending = null;
      return;
    }
    if (_active != null) {
      _pending = key;
      return;
    }
    _start(key);
  }

  void _start(GeometryKey key) {
    _active = key;
    SeaGlassGeometryCache.obtain(key).then((g) {
      if (_disposed) {
        g?.dispose();
        return;
      }
      if (g != null) {
        _displayed?.dispose();
        _displayed = g;
      }
      _active = null;
      final next = _pending;
      _pending = null;
      if (next != null && next != _displayed?.key) _start(next);
      notifyListeners();
    });
  }

  static Future<LiveGeometry?> _build(GeometryKey k) async {
    try {
      final segments = contourSegments(
          buildContour(k.widthDp, k.heightDp, shape: k.shape, tumble: k.tumble, seed: k.seed));
      final width = math.max(1, (k.widthDp * k.fieldScale).ceil());
      final height = math.max(1, (k.heightDp * k.fieldScale).ceil());
      final columns = width + 2, rows = height + 2;
      final coverage = await rasterizeMask(segments, columns, rows, k.fieldScale);
      final textures = await compute(
        buildGeometryTextures,
        GeometryRequest(
          widthDp: k.widthDp, heightDp: k.heightDp, scale: k.fieldScale,
          seed: k.seed, width: width, height: height, coverage: coverage,
        ),
      );
      final a = await uploadFloatTexture(textures.a, width, height);
      final b = await uploadFloatTexture(textures.b, width, height);
      return LiveGeometry(k, contourToPath(segments), a, b, width, height,
          textures.gradientScaleA, textures.gradientScaleB);
    } catch (e, s) {
      debugPrint('sea_glass: geometry build failed: $e\n$s');
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _displayed?.dispose();
    _displayed = null;
    super.dispose();
  }
}

/// Paints the three ground-light layers and the glass body.
class SeaGlassPainter extends CustomPainter {
  SeaGlassPainter({
    required this.style,
    required this.palette,
    required this.shape,
    required this.controller,
    this.program,
  }) : super(repaint: controller);

  final SeaGlassStyle style;
  final SeaGlassPalette palette;
  final SeaGlassShape shape;
  final SeaGlassGeometryController controller;
  final ui.FragmentProgram? program;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 1 || size.height < 1) return;
    final s = style.normalized();
    controller.request(size, shape, s);
    final geometry = controller.displayedFor(size);
    // Like the reference, never show a partial piece: ground and body appear
    // together once this size's geometry exists. A displayed geometry keeps its
    // own seed and tumble while a newer one is prepared.
    if (geometry == null || program == null) return;
    paintGround(canvas, geometry.path, size, s, palette);
    _paintBody(canvas, size, s, geometry, program!);
  }

  void _paintBody(Canvas canvas, Size size, SeaGlassStyle s, LiveGeometry g, ui.FragmentProgram p) {
    final shader = p.fragmentShader();
    configureBodyShader(
      shader, g.a, g.b,
      widthDp: g.key.widthDp, heightDp: g.key.heightDp, fieldScale: g.key.fieldScale,
      gradientScaleA: g.gradientScaleA, gradientScaleB: g.gradientScaleB,
      textureWidth: g.width, textureHeight: g.height,
      style: s, seed: g.key.seed, body: palette.body, edge: palette.edge,
    );
    canvas.drawPath(g.path, Paint()
      ..isAntiAlias = true
      ..shader = shader);
  }

  @override
  bool shouldRepaint(SeaGlassPainter old) =>
      style != old.style || palette != old.palette || shape != old.shape ||
      program != old.program || controller != old.controller;
}

/// Clips children to the displayed tumbled outline.
class SeaGlassClipper extends CustomClipper<Path> {
  SeaGlassClipper(this.controller, this.style, this.shape) : super(reclip: controller);
  final SeaGlassGeometryController controller;
  final SeaGlassStyle style;
  final SeaGlassShape shape;

  @override
  Path getClip(Size size) => controller.pathFor(size, shape, style.normalized());

  @override
  bool shouldReclip(SeaGlassClipper old) => style != old.style || shape != old.shape;
}

/// composeMaskRasterizer: white source-over on transparent, antialiased,
/// path scaled by [scale] and offset by one pixel. Returns alpha bytes.
Future<Uint8List> rasterizeMask(List<ContourSegment> segments, int columns, int rows, double scale) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..translate(1, 1)
    ..drawPath(contourToPath(segments, scale), Paint()
      ..color = const Color(0xFFFFFFFF)
      ..isAntiAlias = true);
  final picture = recorder.endRecording();
  final image = await picture.toImage(columns, rows);
  picture.dispose();
  final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  image.dispose();
  final coverage = Uint8List(columns * rows);
  for (var i = 0; i < coverage.length; i++) {
    coverage[i] = rgba.getUint8(i * 4 + 3);
  }
  return coverage;
}

/// Opaque float RGBA keeps the encoded fields out of color conversion. Values
/// are first rounded to IEEE binary16, because the reference uploads RGBA_F16
/// on every platform; the GPU then samples exactly the same texel values.
Future<ui.Image> uploadFloatTexture(Float32List data, int width, int height) {
  final rounded = Float32List(data.length);
  for (var i = 0; i < data.length; i++) {
    rounded[i] = halfToFloat(float16Bits(data[i]));
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(rounded.buffer.asUint8List(),
      width, height, ui.PixelFormat.rgbaFloat32, done.complete);
  return done.future;
}

/// Binds the geometry textures and sets every uniform of sea_glass.frag in
/// declaration order, with the same values LiveMaterialRenderer uses.
void configureBodyShader(
  ui.FragmentShader shader,
  ui.Image geometryA,
  ui.Image geometryB, {
  required double widthDp,
  required double heightDp,
  required double fieldScale,
  required double gradientScaleA,
  required double gradientScaleB,
  required int textureWidth,
  required int textureHeight,
  required SeaGlassStyle style,
  required int seed,
  required Color body,
  required Color edge,
}) {
  final s = style;
  final theta = s.lightDegrees * math.pi / 180.0;
  final lx = math.sin(theta);
  final ly = -math.cos(theta);
  const lightZ = 0.52;
  final lightSide = math.sqrt(1.0 - lightZ * lightZ);
  final halfX = lx * lightSide, halfY = ly * lightSide, halfZ = lightZ + 1.0;
  final halfLength = math.sqrt(halfX * halfX + halfY * halfY + halfZ * halfZ);
  shader
    ..setImageSampler(0, geometryA, filterQuality: FilterQuality.low)
    ..setImageSampler(1, geometryB, filterQuality: FilterQuality.low);
  var i = 0;
  void f(double v) => shader.setFloat(i++, v);
  f(widthDp); f(heightDp); // materialSize
  f(fieldScale); // fieldScale
  f(1.0); // density: Flutter fragment coordinates are already logical pixels
  f(gradientScaleA); f(gradientScaleB); // gradientScales
  f(textureWidth.toDouble()); f(textureHeight.toDouble()); // geometrySize
  f(s.frost); f(s.grain); f(s.thickness); f(s.bulge); // recipeA
  f(s.lightDegrees); f(s.transmission); f(SeaGlassRandom(seed).nextDouble()); f(0); // recipeB
  final b = body.toARGB32(), e = edge.toARGB32();
  f(((b >> 16) & 255) / 255); f(((b >> 8) & 255) / 255); f((b & 255) / 255); // bodyColor
  f(((e >> 16) & 255) / 255); f(((e >> 8) & 255) / 255); f((e & 255) / 255); // edgeColor
  f(lx); f(ly); // lightDirection
  f(halfX / halfLength); f(halfY / halfLength); f(halfZ / halfLength); // halfway
}

final ByteData _bits = ByteData(4);

/// IEEE binary16, round-to-nearest-even (port of the reference float16Bits).
int float16Bits(double value) {
  _bits.setFloat32(0, value);
  final bits = _bits.getUint32(0);
  final sign = (bits >>> 16) & 0x8000;
  final exponent = (bits >>> 23) & 0xFF;
  final mantissa = bits & 0x7FFFFF;
  if (exponent == 0xFF) return sign | (mantissa == 0 ? 0x7C00 : 0x7E00);
  final halfExponent = exponent - 127 + 15;
  if (halfExponent >= 31) return sign | 0x7C00;
  if (halfExponent <= 0) {
    if (halfExponent < -10) return sign;
    final significant = mantissa | 0x800000;
    final shift = 14 - halfExponent;
    var rounded = significant >>> shift;
    final remainder = significant & ((1 << shift) - 1);
    final halfway = 1 << (shift - 1);
    if (remainder > halfway || (remainder == halfway && (rounded & 1) != 0)) rounded++;
    return sign | rounded;
  }
  final rounded = mantissa + 0xFFF + ((mantissa >>> 13) & 1);
  return sign | ((halfExponent << 10) + (rounded >>> 13));
}

double halfToFloat(int h) {
  final sign = (h & 0x8000) != 0 ? -1.0 : 1.0;
  final exponent = (h >>> 10) & 0x1F;
  final mantissa = h & 0x3FF;
  if (exponent == 0) return sign * mantissa * math.pow(2, -24);
  if (exponent == 31) return mantissa == 0 ? sign * double.infinity : double.nan;
  return sign * (1 + mantissa / 1024) * math.pow(2, exponent - 15);
}

/// Port of RealtimeGround: three layers in the original order, each drawn
/// into its own layer and blurred as a whole (Gaussian sigma, decal tiling).
void paintGround(Canvas canvas, Path path, Size size, SeaGlassStyle s, SeaGlassPalette palette) {
  final short = math.min(size.width, size.height);
  final t = s.transmission;
  final bounds = Rect.fromLTWH(-kSeaGlassPadding, -kSeaGlassPadding,
      size.width + kSeaGlassPadding * 2, size.height + kSeaGlassPadding * 2);
  // Compose converts these float alphas to 8-bit color with rounding.
  Color argb(double alpha, int rgb) => Color(((f32(alpha) * 255).round() << 24) | rgb);

  void layer(double offset, double sigma, Paint paint) {
    canvas.saveLayer(
      bounds,
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
    );
    canvas.translate(0, offset);
    canvas.drawPath(path, paint..isAntiAlias = true);
    canvas.restore();
  }

  layer(
    math.min(16.0, s.thickness * 0.40 + s.elevation * 0.72 + s.bulge * short * 0.03),
    math.min(6.0, 2.5 + s.elevation * 0.18 + s.frost * 0.7 + s.bulge * short * 0.018),
    Paint()..color = argb((0.18 + s.elevation * 0.001) * (1.0 - t * 0.82), 0x3F4342),
  );
  layer(
    math.min(8.0, s.thickness * 0.32 + 0.8),
    1.4 + s.elevation * 0.065,
    Paint()..color = argb(0.10 * (1.0 - t * 0.70), 0x3D413F),
  );
  if (t > 0.001) {
    final travel = 4.0 + s.elevation * 0.56 + short * 0.055;
    final body = palette.body.toARGB32();
    int tint(int channel) => (255.0 - (255 - channel) * 1.35).round().clamp(0, 255);
    final tintRgb = (tint((body >> 16) & 255) << 16) | (tint((body >> 8) & 255) << 8) | tint(body & 255);
    layer(
      math.min(22.0, s.thickness * 0.42 + travel),
      math.min(8.0, 2.8 + short * 0.033 + s.frost * 1.6),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [argb(0, tintRgb), argb(t * 0.06, tintRgb), argb(t * 0.48, tintRgb), argb(t * 0.94, tintRgb)],
          const [0.0, 0.45, 0.75, 1.0],
        ),
    );
  }
}
