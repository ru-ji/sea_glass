import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'painter.dart';
import 'style.dart';
import 'theme.dart';

/// Shared state for one piece: loads the shader and owns its geometry controller.
mixin _GlassState<T extends StatefulWidget> on State<T> {
  final SeaGlassGeometryController cache = SeaGlassGeometryController();
  ui.FragmentProgram? program = SeaGlassShaderProgram.loaded;

  @override
  void initState() {
    super.initState();
    if (program == null) {
      SeaGlassShaderProgram.load().then((p) {
        if (mounted && p != null) setState(() => program = p);
      });
    }
  }

  @override
  void dispose() {
    cache.dispose();
    super.dispose();
  }
}

/// Draws the glass material behind [child]. It adds no padding and no
/// interaction. The material paints up to 48 logical pixels outside the layout
/// box (shadow and transmitted light), so try not to clip ancestors.
class SeaGlass extends StatefulWidget {
  const SeaGlass({
    super.key,
    this.style,
    this.palette,
    this.shape,
    this.componentStyle,
    this.clipChild = false,
    this.width,
    this.height,
    this.alignment,
    this.padding,
    this.child,
  });

  final SeaGlassStyle? style;
  final SeaGlassPalette? palette;
  final SeaGlassShape? shape;

  /// Fallback bundle for any of [style], [palette] and [shape] left null.
  final SeaGlassComponentStyle? componentStyle;

  /// Clip the child to the tumbled outline.
  final bool clipChild;
  final double? width, height;
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? padding;
  final Widget? child;

  @override
  State<SeaGlass> createState() => _SeaGlassState();

  /// Prepares the shader and the geometry for a piece of [size], so it draws
  /// completely on the first frame (useful before pushing a screen). Geometry
  /// depends only on size, shape, tumble and seed.
  static Future<void> precache(
    Size size, {
    SeaGlassStyle style = SeaGlassStyle.reference,
    SeaGlassShape shape = SeaGlassShape.rounded,
  }) async {
    await SeaGlassShaderProgram.load();
    final key = SeaGlassGeometryController.keyFor(size, shape, style.normalized());
    (await SeaGlassGeometryCache.obtain(key))?.dispose();
  }
}

class _SeaGlassState extends State<SeaGlass> with _GlassState {
  @override
  Widget build(BuildContext context) {
    final base = widget.componentStyle ?? SeaGlassTheme.of(context);
    final style = widget.style ?? base.style;
    final palette = widget.palette ?? base.palette;
    final shape = widget.shape ?? base.shape;
    Widget? content = widget.child;
    if (content != null && widget.padding != null) {
      content = Padding(padding: widget.padding!, child: content);
    }
    if (content != null && widget.alignment != null) {
      content = Align(alignment: widget.alignment!, child: content);
    }
    // The material and the clip always cover the whole box. Padding and
    // alignment only place the child inside it.
    if (content != null && widget.clipChild) {
      content = ClipPath(clipper: SeaGlassClipper(cache, style, shape), child: content);
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: CustomPaint(
        painter: SeaGlassPainter(
            style: style, palette: palette, shape: shape, controller: cache, program: program,
            devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0),
        child: content ?? const SizedBox.expand(),
      ),
    );
  }
}

/// Non-interactive glass container. Content uses the palette ink colour.
class SeaGlassSurface extends StatelessWidget {
  const SeaGlassSurface({
    super.key,
    this.style,
    this.palette,
    this.shape,
    this.componentStyle,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.padding,
    this.child,
  });

  final SeaGlassStyle? style;
  final SeaGlassPalette? palette;
  final SeaGlassShape? shape;
  final SeaGlassComponentStyle? componentStyle;
  final double? width, height;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry? padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final base = componentStyle ?? SeaGlassTheme.of(context);
    final ink = (palette ?? base.palette).ink;
    return SeaGlass(
      style: style,
      palette: palette,
      shape: shape,
      componentStyle: componentStyle,
      clipChild: true,
      width: width,
      height: height,
      alignment: alignment,
      padding: padding,
      child: child == null
          ? null
          : IconTheme.merge(
              data: IconThemeData(color: ink),
              child: DefaultTextStyle.merge(style: TextStyle(color: ink), child: child!)),
    );
  }
}

/// Glass button with button semantics, a 48 logical pixel minimum target,
/// a keyboard focus outline, a disabled state and a 2 px press offset.
class SeaGlassButton extends StatefulWidget {
  const SeaGlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.palette,
    this.shape,
    this.componentStyle,
    this.width,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  });

  /// Null disables the button.
  final VoidCallback? onPressed;
  final Widget child;
  final SeaGlassStyle? style;
  final SeaGlassPalette? palette;
  final SeaGlassShape? shape;
  final SeaGlassComponentStyle? componentStyle;
  final double? width, height;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<SeaGlassButton> createState() => _SeaGlassButtonState();
}

class _SeaGlassButtonState extends State<SeaGlassButton> with _GlassState {
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.componentStyle ?? SeaGlassTheme.of(context);
    final style = widget.style ?? base.style;
    final palette = widget.palette ?? base.palette;
    final shape = widget.shape ?? base.shape;

    final pressed = _pressed && _enabled;
    // Matches the original: content clipped to the outline, a 4 px centred
    // focus stroke clipped to a 2 px inner border, and the whole piece offset
    // 2 px while pressed. Disabled pieces draw at 45% opacity.
    final clipper = SeaGlassClipper(cache, style, shape);
    Widget content = ClipPath(
      clipper: clipper,
      child: IconTheme.merge(
        data: IconThemeData(color: palette.ink),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: palette.ink),
          child: Stack(alignment: Alignment.center, children: [
            Padding(
              padding: widget.padding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [Flexible(child: widget.child)],
              ),
            ),
            if (_focused)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _FocusPainter(cache, style, shape, palette.ink.withValues(alpha: .65)),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );

    Widget glass = CustomPaint(
      painter: SeaGlassPainter(
        style: style, palette: palette, shape: shape, controller: cache, program: program,
        devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0,
      ),
      child: Center(widthFactor: 1, heightFactor: 1, child: content),
    );

    glass = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: SizedBox(width: widget.width, height: widget.height, child: glass),
    );
    glass = Transform.translate(
      offset: Offset(0, pressed ? 2 : 0),
      child: Opacity(opacity: _enabled ? 1 : .45, child: glass),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        enabled: _enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          }),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: _enabled ? (_) => _setPressed(true) : null,
          onTapUp: _enabled ? (_) => _setPressed(false) : null,
          onTapCancel: _enabled ? () => _setPressed(false) : null,
          onTap: widget.onPressed,
          child: glass,
        ),
      ),
    );
  }
}

class _FocusPainter extends CustomPainter {
  _FocusPainter(this.cache, this.style, this.shape, this.color) : super(repaint: cache);
  final SeaGlassGeometryController cache;
  final SeaGlassStyle style;
  final SeaGlassShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      cache.pathFor(size, shape, style.normalized()),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_FocusPainter old) => color != old.color;
}
