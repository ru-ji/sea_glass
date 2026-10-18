import 'package:flutter/material.dart';

/// Material recipe. Lengths are logical pixels. Out-of-range values are clamped.
@immutable
class SeaGlassStyle {
  const SeaGlassStyle({
    this.frost = 0.55,
    this.grain = 0.48,
    this.tumble = 0.025,
    this.thickness = 6,
    this.bulge = 0.65,
    this.elevation = 8,
    this.lightDegrees = 315,
    this.transmission = 0.58,
    this.seed = 42,
    this.shadowDegrees = 180,
  });

  /// Cloudiness, 0..1.
  final double frost;

  /// Microscopic abrasion, 0..1.
  final double grain;

  /// Contour variation as a fraction of the shorter side, 0..0.065.
  final double tumble;

  /// Optical thickness, 0..14.
  final double thickness;

  /// Curvature through the body, 0..1.
  final double bulge;

  /// Height of the fixed downward shadow, 0..18.
  final double elevation;

  /// Surface reflection azimuth in degrees. Zero is above; 90 is right.
  final double lightDegrees;

  /// Lower light exit and colored ground pool, 0..1.
  final double transmission;

  /// Stable piece identity. Keep it constant across rebuilds.
  final int seed;

  /// Direction the ground light falls, in degrees: 180 is down (the
  /// reference's fixed direction), 90 is right, 0 is up. The cast and contact
  /// shadows, the transmitted color pool and the body's luminous exit edge all
  /// follow it. Independent of [lightDegrees], which moves surface reflections.
  /// This is an extension: the original always casts downward.
  final double shadowDegrees;

  static const SeaGlassStyle reference = SeaGlassStyle();
  static const SeaGlassStyle tumbled = SeaGlassStyle(
    frost: .72, grain: .68, tumble: .055, thickness: 9,
    bulge: .80, elevation: 7, transmission: .48,
  );
  static const SeaGlassStyle quiet = SeaGlassStyle(
    frost: .38, grain: .23, tumble: .012, thickness: 3,
    bulge: .38, elevation: 4, transmission: .66,
  );

  SeaGlassStyle copyWith({
    double? frost, double? grain, double? tumble, double? thickness,
    double? bulge, double? elevation, double? lightDegrees,
    double? transmission, int? seed, double? shadowDegrees,
  }) =>
      SeaGlassStyle(
        frost: frost ?? this.frost,
        grain: grain ?? this.grain,
        tumble: tumble ?? this.tumble,
        thickness: thickness ?? this.thickness,
        bulge: bulge ?? this.bulge,
        elevation: elevation ?? this.elevation,
        lightDegrees: lightDegrees ?? this.lightDegrees,
        transmission: transmission ?? this.transmission,
        seed: seed ?? this.seed,
        shadowDegrees: shadowDegrees ?? this.shadowDegrees,
      );

  /// The same recipe with every field clamped to its documented range.
  SeaGlassStyle normalized() => SeaGlassStyle(
        frost: _finite(frost, .55).clamp(0.0, 1.0),
        grain: _finite(grain, .48).clamp(0.0, 1.0),
        tumble: _finite(tumble, .025).clamp(0.0, 0.065),
        thickness: _finite(thickness, 6).clamp(0.0, 14.0),
        bulge: _finite(bulge, .65).clamp(0.0, 1.0),
        elevation: _finite(elevation, 8).clamp(0.0, 18.0),
        lightDegrees: _finite(lightDegrees, 315),
        transmission: _finite(transmission, .58).clamp(0.0, 1.0),
        seed: seed,
        shadowDegrees: _finite(shadowDegrees, 180),
      );

  static double _finite(double v, double fallback) => v.isFinite ? v : fallback;

  @override
  bool operator ==(Object other) =>
      other is SeaGlassStyle &&
      frost == other.frost && grain == other.grain && tumble == other.tumble &&
      thickness == other.thickness && bulge == other.bulge &&
      elevation == other.elevation && lightDegrees == other.lightDegrees &&
      transmission == other.transmission && seed == other.seed &&
      shadowDegrees == other.shadowDegrees;

  @override
  int get hashCode => Object.hash(frost, grain, tumble, thickness, bulge,
      elevation, lightDegrees, transmission, seed, shadowDegrees);
}

enum SeaGlassShape { rounded, capsule, disc }

/// Material 3 color roles usable as glass pigment.
enum SeaGlassColorRole {
  primary, secondary, tertiary, error, surface;

  Color container(ColorScheme s) => switch (this) {
        primary => s.primaryContainer,
        secondary => s.secondaryContainer,
        tertiary => s.tertiaryContainer,
        error => s.errorContainer,
        surface => s.surfaceContainerHighest,
      };

  Color onContainer(ColorScheme s) => switch (this) {
        primary => s.onPrimaryContainer,
        secondary => s.onSecondaryContainer,
        tertiary => s.onTertiaryContainer,
        error => s.onErrorContainer,
        surface => s.onSurface,
      };
}

/// Body pigment, transmitted edge light and a legible foreground.
/// [body] and [edge] alpha is ignored; translucency comes from the material model.
@immutable
class SeaGlassPalette {
  const SeaGlassPalette({required this.body, required this.edge, required this.ink});

  final Color body;
  final Color edge;
  final Color ink;

  static const SeaGlassPalette lagoon = SeaGlassPalette(
      body: Color(0xFFB5D0EB), edge: Color(0xFFD6E9FF), ink: Color(0xFF2F647C));
  static const SeaGlassPalette lilac = SeaGlassPalette(
      body: Color(0xFFE1CDE8), edge: Color(0xFFFBE8F7), ink: Color(0xFF71388B));
  static const SeaGlassPalette rose = SeaGlassPalette(
      body: Color(0xFFEECED6), edge: Color(0xFFFFF0F1), ink: Color(0xFF963F59));
  static const SeaGlassPalette amber = SeaGlassPalette(
      body: Color(0xFFF0D9BE), edge: Color(0xFFFFFCE0), ink: Color(0xFF865733));
  static const SeaGlassPalette mint = SeaGlassPalette(
      body: Color(0xFFC0DED0), edge: Color(0xFFE6FFF0), ink: Color(0xFF396C5A));

  /// Uses a Material 3 container color as pigment and its on-container color
  /// as foreground. The edge is the container blended 35% toward white.
  factory SeaGlassPalette.fromColorScheme(ColorScheme scheme,
      [SeaGlassColorRole role = SeaGlassColorRole.primary]) {
    final body = role.container(scheme);
    return SeaGlassPalette(
      body: body,
      edge: Color.lerp(body, Colors.white, .35)!,
      ink: role.onContainer(scheme),
    );
  }

  /// Reads the ambient Material theme (works with dynamic_color schemes too).
  factory SeaGlassPalette.of(BuildContext context,
          [SeaGlassColorRole role = SeaGlassColorRole.primary]) =>
      SeaGlassPalette.fromColorScheme(Theme.of(context).colorScheme, role);

  @override
  bool operator ==(Object other) =>
      other is SeaGlassPalette && body == other.body && edge == other.edge && ink == other.ink;

  @override
  int get hashCode => Object.hash(body, edge, ink);
}

/// A reusable design-system bundle of recipe, palette and shape.
@immutable
class SeaGlassComponentStyle {
  const SeaGlassComponentStyle({
    this.style = SeaGlassStyle.reference,
    this.palette = SeaGlassPalette.lagoon,
    this.shape = SeaGlassShape.rounded,
  });

  final SeaGlassStyle style;
  final SeaGlassPalette palette;
  final SeaGlassShape shape;

  SeaGlassComponentStyle copyWith({SeaGlassStyle? style, SeaGlassPalette? palette, SeaGlassShape? shape}) =>
      SeaGlassComponentStyle(
          style: style ?? this.style, palette: palette ?? this.palette, shape: shape ?? this.shape);

  @override
  bool operator ==(Object other) =>
      other is SeaGlassComponentStyle &&
      style == other.style && palette == other.palette && shape == other.shape;

  @override
  int get hashCode => Object.hash(style, palette, shape);
}
