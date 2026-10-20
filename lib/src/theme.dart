import 'package:flutter/material.dart';

import 'style.dart';

/// Defaults that flow down the tree. A nested theme overrides only what it sets.
class SeaGlassTheme extends StatelessWidget {
  const SeaGlassTheme({super.key, this.style, this.palette, this.shape, required this.child});

  final SeaGlassStyle? style;
  final SeaGlassPalette? palette;
  final SeaGlassShape? shape;
  final Widget child;

  /// The defaults in scope, or the library defaults when there is no theme above.
  static SeaGlassComponentStyle of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SeaGlassScope>()?.data ??
      const SeaGlassComponentStyle();

  @override
  Widget build(BuildContext context) {
    final parent = of(context);
    return _SeaGlassScope(
      data: parent.copyWith(style: style, palette: palette, shape: shape),
      child: child,
    );
  }
}

class _SeaGlassScope extends InheritedWidget {
  const _SeaGlassScope({required this.data, required super.child});
  final SeaGlassComponentStyle data;

  @override
  bool updateShouldNotify(_SeaGlassScope old) => data != old.data;
}

/// Sets the glass palette from the current Material 3 [ColorScheme].
class SeaGlassMaterialTheme extends StatelessWidget {
  const SeaGlassMaterialTheme({
    super.key,
    this.role = SeaGlassColorRole.primary,
    required this.child,
  });

  final SeaGlassColorRole role;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SeaGlassTheme(palette: SeaGlassPalette.of(context, role), child: child);
}
