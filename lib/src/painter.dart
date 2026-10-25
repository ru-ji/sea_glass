import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'contour.dart';
import 'material_field.dart';
import 'random.dart';
import 'style.dart';

/// Unit vector for a ground-light angle in degrees, where 180 points down.
/// Values close to an axis snap to it, so 180 gives exactly (0, 1).
Offset shadowVector(double degrees) {
  final theta = degrees * math.pi / 180.0;
  double snap(double v) => v.abs() < 1e-9 ? 0.0 : (v - v.sign).abs() < 1e-9 ? v.sign : v;
  return Offset(snap(math.sin(theta)), snap(-math.cos(theta)));
}

/// Transparent space the material can paint into outside its layout box.
const double kSeaGlassPadding = 48.0;

/// Loads the fragment program once. Returns null when shaders are not available
/// (unsupported backend, unit tests). Painters then draw only the ground light.
class SeaGlassShaderProgram {
  SeaGlassShaderProgram._();

  static const String asset = 'packages/sea_glass/shaders/sea_glass.frag';
  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram?>? _loading;

  static bool _failed = false;

  static ui.FragmentProgram? get loaded => _program;

  /// True when loading has finished and there is no usable program.
  static bool get failed => _failed;

  static Future<ui.FragmentProgram?> load() => _loading ??= () async {
        // The short key is needed when running this package's own tests.
        for (final key in const [asset, 'shaders/sea_glass.frag']) {
          try {
            return _program = await ui.FragmentProgram.fromAsset(key);
          } catch (_) {}
        }
        debugPrint('sea_glass: shader unavailable, drawing a flat fallback');
        _failed = true;
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

  /// Another handle to the same GPU images. Dispose each handle on its own.
  LiveGeometry clone() => LiveGeometry(key, path, a.clone(), b.clone(), width, height, gradientScaleA, gradientScaleB);

  int get byteSize => width * height * 16 * 2;

  void dispose() {
    a.dispose();
    b.dispose();
  }
}

/// Shared LRU of read-only geometry, like the original's
/// sharedLiveMaterialGeometryCache. It holds up to 32 entries within a texture
/// budget, so repeats, revisited screens and precached sizes draw on first paint.
class SeaGlassGeometryCache {
  SeaGlassGeometryCache._();

  static const int maxEntries = 32;
  static const int maxBytes = 32 << 20;
  static final Map<GeometryKey, LiveGeometry> _entries = {};
  static final Map<GeometryKey, Future<LiveGeometry?>> _building = {};
  static int _bytes = 0;

  /// A fresh handle to cached geometry, or null.
  static LiveGeometry? lookup(GeometryKey key) {
    final g = _entries.remove(key);
    if (g == null) return null;
    _entries[key] = g; // most recently used
    return g.clone();
  }

  /// Builds the geometry once per key, caches it and returns a new handle.
  static Future<LiveGeometry?> obtain(GeometryKey key) async {
    final hit = lookup(key);
    if (hit != null) return hit;
    final g = await (_building[key] ??= SeaGlassGeometryController._build(key)
      ..whenComplete(() => _building.remove(key)));
    if (g == null) return null;
    // Each caller gets its own handle before eviction can dispose the cached one.
    final handle = g.clone();
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
    return handle;
  }

  /// Frees every cached geometry. Pieces that are still alive keep their handles.
  static void clear() {
    for (final g in _entries.values) {
      g.dispose();
    }
    _entries.clear();
    _bytes = 0;
  }
}

/// Owns one piece's geometry. This follows LiveMaterialRenderer's update model:
/// the last complete geometry stays on screen while the next one is built away
/// from the paint path. Only one build runs at a time, and only the newest
/// request waits behind it. The controller also owns the piece's shader and its
/// rasterized ground light.
class SeaGlassGeometryController extends ChangeNotifier {
  LiveGeometry? _displayed;
  GeometryKey? _active, _pending, _latest;
  final Set<GeometryKey> _failed = {};
  bool _disposed = false;
  final Map<GeometryKey, Path> _paths = {};
  ui.FragmentProgram? _shaderProgram;
  ui.FragmentShader? _shader;
  _GroundImage? _ground;

  static GeometryKey keyFor(Size size, SeaGlassShape shape, SeaGlassStyle style) {
    final fieldScale = math.min(1.0, math.sqrt(262144.0 / (size.width * size.height)));
    return GeometryKey(size.width, size.height, shape, style.tumble, style.seed, fieldScale);
  }

  /// Outline used for clipping and the ground light. If the displayed geometry
  /// matches the size, use its path; otherwise compute the requested one now.
  Path pathFor(Size size, SeaGlassShape shape, SeaGlassStyle style) {
    final d = _displayed;
    if (d != null) {
      if (d.key.sameSize(size)) return d.path;
      // Match the painter, which stretches the last geometry while the next one builds.
      return d.path.transform(Matrix4.diagonal3Values(
          size.width / d.key.widthDp, size.height / d.key.heightDp, 1).storage);
    }
    final key = keyFor(size, shape, style);
    if (_paths.length > 4) _paths.clear();
    return _paths[key] ??= _outline(key);
  }

  static Path _outline(GeometryKey k) => contourToPath(
      contourSegments(buildContour(k.widthDp, k.heightDp, shape: k.shape, tumble: k.tumble, seed: k.seed)));

  /// The last complete geometry, at whatever size it was built.
  LiveGeometry? get displayed => _displayed;

  LiveGeometry? displayedFor(Size size) {
    final d = _displayed;
    return d != null && d.key.sameSize(size) ? d : null;
  }

  /// True if this geometry could not be built, for example without float textures.
  bool failedFor(Size size, SeaGlassShape shape, SeaGlassStyle style) =>
      _failed.contains(keyFor(size, shape, style));

  void request(Size size, SeaGlassShape shape, SeaGlassStyle style) {
    if (size.width < 1 || size.height < 1) return;
    final key = keyFor(size, shape, style);
    _latest = key;
    if (_displayed?.key == key || _active == key) {
      _pending = null;
      return;
    }
    // Do not retry a failed key on every repaint.
    if (_failed.contains(key)) return;
    // Cached geometry can be used right away, during this paint.
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
      _active = null;
      if (g == null) {
        _failed.add(key);
      } else if (g.key == _latest || _displayed?.key != _latest) {
        _displayed?.dispose();
        _displayed = g;
      } else {
        // A -> B (building) -> A keeps A, because the latest request is already shown.
        g.dispose();
      }
      final next = _pending;
      _pending = null;
      if (next != null && next != _displayed?.key && !_failed.contains(next)) _start(next);
      notifyListeners();
    });
  }

  /// One shader per piece. Only the uniforms change between frames.
  ui.FragmentShader shaderFor(ui.FragmentProgram program) {
    if (_shaderProgram != program) {
      _shader?.dispose();
      _shader = program.fragmentShader();
      _shaderProgram = program;
    }
    return _shader!;
  }

  /// The three blurred ground layers. They are rasterized once per change, like
  /// RealtimeGround's recorded layers, instead of being blurred on every frame.
  ui.Image groundFor(Path path, Size size, SeaGlassStyle s, SeaGlassPalette palette, double pixelRatio) {
    final key = _GroundKey(path, size, s.thickness, s.bulge, s.frost, s.elevation, s.transmission,
        palette.body.toARGB32() & 0xFFFFFF, pixelRatio, s.shadowDegrees, s.shadowTinted, s.shadowColor);
    final cached = _ground;
    if (cached != null && cached.key == key) return cached.image;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(pixelRatio)
      ..translate(kSeaGlassPadding, kSeaGlassPadding);
    paintGround(canvas, path, size, s, palette);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      ((size.width + kSeaGlassPadding * 2) * pixelRatio).ceil(),
      ((size.height + kSeaGlassPadding * 2) * pixelRatio).ceil(),
    );
    picture.dispose();
    cached?.image.dispose();
    _ground = _GroundImage(key, image);
    return image;
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
        buildUploadableGeometryTextures,
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
    _shader?.dispose();
    _ground?.image.dispose();
    super.dispose();
  }
}

@immutable
class _GroundKey {
  const _GroundKey(this.path, this.size, this.thickness, this.bulge, this.frost, this.elevation,
      this.transmission, this.body, this.pixelRatio, this.shadowDegrees, this.shadowTinted, this.shadowColor);
  final Path path;
  final Size size;
  final double thickness, bulge, frost, elevation, transmission, pixelRatio, shadowDegrees;
  final int body;
  final bool shadowTinted;
  final Color? shadowColor;

  @override
  bool operator ==(Object other) =>
      other is _GroundKey && identical(other.path, path) && other.size == size &&
      other.thickness == thickness && other.bulge == bulge && other.frost == frost &&
      other.elevation == elevation && other.transmission == transmission &&
      other.body == body && other.pixelRatio == pixelRatio && other.shadowDegrees == shadowDegrees &&
      other.shadowTinted == shadowTinted && other.shadowColor == shadowColor;

  @override
  int get hashCode => Object.hash(identityHashCode(path), size, thickness, bulge, frost, elevation,
      transmission, body, pixelRatio, shadowDegrees, shadowTinted, shadowColor);
}

class _GroundImage {
  _GroundImage(this.key, this.image);
  final _GroundKey key;
  final ui.Image image;
}

/// Paints the glass body and the three ground-light layers.
class SeaGlassPainter extends CustomPainter {
  SeaGlassPainter({
    required this.style,
    required this.palette,
    required this.shape,
    required this.controller,
    this.program,
    this.devicePixelRatio = 1.0,
  }) : super(repaint: controller);

  final SeaGlassStyle style;
  final SeaGlassPalette palette;
  final SeaGlassShape shape;
  final SeaGlassGeometryController controller;
  final ui.FragmentProgram? program;

  /// Pixel ratio used for the cached ground-light image.
  final double devicePixelRatio;

  /// The ground light is blurred by at least 1.4 logical pixels, so more than
  /// 1.5 image pixels per logical pixel only costs memory.
  double get _groundRatio => math.min(devicePixelRatio, 1.5);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 1 || size.height < 1) return;
    final s = style.normalized();
    final p = program;
    if (p == null || controller.failedFor(size, shape, s)) {
      // Without a shader or float textures, draw a flat body instead of nothing.
      // While the shader is still loading, draw nothing.
      if (SeaGlassShaderProgram.failed || p != null) _paintFlat(canvas, size, s);
      return;
    }
    controller.request(size, shape, s);
    final exact = controller.displayedFor(size);
    final geometry = exact ?? controller.displayed;
    // Never show half a piece: ground and body appear together. While a new
    // size is being built, the previous geometry is stretched to fit, so
    // animated sizes do not blink. It keeps its own seed and tumble.
    if (geometry == null) return;
    final own = Size(geometry.key.widthDp, geometry.key.heightDp);
    canvas.save();
    if (exact == null) canvas.scale(size.width / own.width, size.height / own.height);
    _drawGround(canvas, controller.groundFor(geometry.path, own, s, palette, _groundRatio), own);
    _paintBody(canvas, s, geometry, p);
    canvas.restore();
  }

  void _drawGround(Canvas canvas, ui.Image image, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(-kSeaGlassPadding, -kSeaGlassPadding,
          image.width / _groundRatio, image.height / _groundRatio),
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  void _paintBody(Canvas canvas, SeaGlassStyle s, LiveGeometry g, ui.FragmentProgram p) {
    final shader = controller.shaderFor(p);
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

  void _paintFlat(Canvas canvas, Size size, SeaGlassStyle s) {
    final path = controller.pathFor(size, shape, s);
    _drawGround(canvas, controller.groundFor(path, size, s, palette, _groundRatio), size);
    canvas.drawPath(path, Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height),
          [Color.lerp(palette.body, const Color(0xFFFFFFFF), .25)!, palette.body, palette.edge],
          const [0.0, 0.7, 1.0]));
  }

  @override
  bool shouldRepaint(SeaGlassPainter old) =>
      style != old.style || palette != old.palette || shape != old.shape ||
      program != old.program || controller != old.controller ||
      devicePixelRatio != old.devicePixelRatio;
}

/// Clips children to the tumbled outline that is currently displayed.
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

/// Port of composeMaskRasterizer. Draws the path scaled by [scale] and offset
/// by one pixel, antialiased, in white source-over on transparent. Returns the
/// alpha channel.
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
  final bytes = rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes);
  final coverage = Uint8List(columns * rows);
  for (var i = 0; i < coverage.length; i++) {
    coverage[i] = bytes[i * 4 + 3];
  }
  return coverage;
}

/// Opaque float RGBA keeps the encoded fields away from colour conversion.
/// [data] must already be rounded with [roundToHalf].
Future<ui.Image> uploadFloatTexture(Float32List data, int width, int height) {
  final done = Completer<ui.Image>();
  // Ask for a float texture explicitly. With the default (dontCare), a backend
  // may store 8-bit channels and quantize the encoded gradients.
  ui.decodeImageFromPixels(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), width, height,
      ui.PixelFormat.rgbaFloat32,
      done.complete, targetFormat: ui.TargetPixelFormat.rgbaFloat32);
  return done.future;
}

/// Binds the geometry textures and sets every sea_glass.frag uniform in
/// declaration order, using the same values as LiveMaterialRenderer.
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

/// Port of RealtimeGround. Draws the three layers in the original order, each
/// in its own layer, then blurs the whole layer (Gaussian sigma, decal tiling).
void paintGround(Canvas canvas, Path path, Size size, SeaGlassStyle s, SeaGlassPalette palette) {
  final short = math.min(size.width, size.height);
  final t = s.transmission;
  final bounds = Rect.fromLTWH(-kSeaGlassPadding, -kSeaGlassPadding,
      size.width + kSeaGlassPadding * 2, size.height + kSeaGlassPadding * 2);
  // Compose rounds these float alphas to 8-bit colour.
  Color argb(double alpha, int rgb) => Color(((f32(alpha) * 255).round() << 24) | rgb);
  final body = palette.body.toARGB32();
  // Extension: tinted shadows use the pigment at 40% brightness.
  // Extension: an explicit shadow colour replaces both, and its alpha scales the opacity.
  final custom = s.shadowColor;
  final shadowAlpha = custom == null ? 1.0 : custom.a;
  int shadowRgb(int neutral) {
    if (custom != null) return custom.toARGB32() & 0xFFFFFF;
    if (!s.shadowTinted) return neutral;
    int dim(int channel) => (channel * 0.4).round().clamp(0, 255);
    return (dim((body >> 16) & 255) << 16) | (dim((body >> 8) & 255) << 8) | dim(body & 255);
  }

  final direction = shadowVector(s.shadowDegrees);

  void layer(double offset, double sigma, Paint paint) {
    canvas.saveLayer(
      bounds,
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
    );
    canvas.translate(direction.dx * offset, direction.dy * offset);
    canvas.drawPath(path, paint..isAntiAlias = true);
    canvas.restore();
  }

  layer(
    math.min(16.0, s.thickness * 0.40 + s.elevation * 0.72 + s.bulge * short * 0.03),
    math.min(6.0, 2.5 + s.elevation * 0.18 + s.frost * 0.7 + s.bulge * short * 0.018),
    Paint()..color = argb((0.18 + s.elevation * 0.001) * (1.0 - t * 0.82) * shadowAlpha, shadowRgb(0x3F4342)),
  );
  layer(
    math.min(8.0, s.thickness * 0.32 + 0.8),
    1.4 + s.elevation * 0.065,
    Paint()..color = argb(0.10 * (1.0 - t * 0.70) * shadowAlpha, shadowRgb(0x3D413F)),
  );
  if (t > 0.001) {
    final travel = 4.0 + s.elevation * 0.56 + short * 0.055;
    int tint(int channel) => (255.0 - (255 - channel) * 1.35).round().clamp(0, 255);
    final tintRgb = (tint((body >> 16) & 255) << 16) | (tint((body >> 8) & 255) << 8) | tint(body & 255);
    layer(
      math.min(22.0, s.thickness * 0.42 + travel),
      math.min(8.0, 2.8 + short * 0.033 + s.frost * 1.6),
      Paint()
        // The opacity ramp follows the ground-light direction across the body.
        // At 180 degrees it runs from the top (0) to the bottom (height).
        ..shader = ui.Gradient.linear(
          _spanPoint(direction, 0),
          _spanPoint(direction, 1),
          [argb(0, tintRgb), argb(t * 0.06, tintRgb), argb(t * 0.48, tintRgb), argb(t * 0.94, tintRgb)],
          const [0.0, 0.45, 0.75, 1.0],
          TileMode.clamp,
          // Unit-box coordinates scaled to the body, matching the shader's travel.
          Matrix4.diagonal3Values(size.width, size.height, 1).storage,
        ),
    );
  }
}

/// The point in the unit box where the projection onto [direction] is at
/// fraction [t] of its range. On the centre line this runs from (0.5, 0) to
/// (0.5, 1) at 180 degrees, so a diagonal direction goes corner to corner.
Offset _spanPoint(Offset direction, double t) {
  final extent = direction.dx.abs() + direction.dy.abs();
  return const Offset(0.5, 0.5) + direction * ((t - 0.5) * extent);
}
