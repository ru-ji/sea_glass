import 'package:flutter/material.dart';
import 'package:sea_glass/sea_glass.dart';

/// A Quick Settings panel in the Android 16 style, built from sea glass tiles.
class QuickSettingsPage extends StatefulWidget {
  const QuickSettingsPage({super.key});

  @override
  State<QuickSettingsPage> createState() => _QuickSettingsPageState();
}

/// Frosted, almost white glass for tiles that are off.
const frosted = SeaGlassPalette(body: Color(0xFFE4EEF0), edge: Color(0xFFFFFFFF), ink: Color(0xFF2B3B3F));

/// Deep teal glass for tiles that are on.
const teal = SeaGlassPalette(body: Color(0xFF1E6F7C), edge: Color(0xFF7FDCE6), ink: Color(0xFFFFFFFF));

/// Tight contours, soft frost and a strong glow along the lower edge.
const qsStyle = SeaGlassStyle(
  frost: .6, grain: .5, tumble: .006, thickness: 5, bulge: .42, elevation: 9, transmission: .62,
);

class _QuickSettingsPageState extends State<QuickSettingsPage> {
  final active = <String>{'wifi', 'location'};
  double brightness = .5;

  void toggle(String id) => setState(() => active.contains(id) ? active.remove(id) : active.add(id));

  Widget tile(String id, IconData icon, {String? label, String? subtitle, int flex = 1, int seed = 0}) {
    return Expanded(
      flex: flex,
      child: QsTile(
        icon: icon,
        label: label,
        subtitle: subtitle,
        active: active.contains(id),
        seed: seed,
        onPressed: () => toggle(id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: 12, height: 12);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.2),
          radius: 1.1,
          colors: [Color(0xFFCFE6E8), Color(0xFFB7D6DB)],
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const _StatusHeader(),
            const SizedBox(height: 28),
            GlassSlider(value: brightness, onChanged: (v) => setState(() => brightness = v)),
            const SizedBox(height: 28),
            Row(children: [
              tile('wifi', Icons.wifi, label: 'Wi-Fi', subtitle: 'The_Matrix2.4G', flex: 2, seed: 1),
              gap,
              tile('data', Icons.mobiledata_off, label: 'Mobile data', flex: 2, seed: 2),
            ]),
            gap,
            Row(children: [
              tile('bluetooth', Icons.bluetooth_disabled, label: 'Bluetooth', flex: 2, seed: 3),
              gap,
              tile('torch', Icons.flashlight_on_outlined, seed: 4),
              gap,
              tile('location', Icons.location_on, seed: 5),
            ]),
            gap,
            Row(children: [
              tile('modes', Icons.bed_outlined, label: 'Modes', flex: 2, seed: 6),
              gap,
              tile('record', Icons.radio_button_checked, label: 'Screen record', subtitle: 'Start', flex: 2, seed: 7),
            ]),
            gap,
            Row(children: [
              tile('airplane', Icons.flight, seed: 8),
              gap,
              tile('qr', Icons.qr_code_scanner, seed: 9),
              gap,
              tile('share', Icons.sync_alt, label: 'Quick Share', flex: 2, seed: 10),
            ]),
            const SizedBox(height: 20),
            const _PagerRow(),
            const SizedBox(height: 120),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              SeaGlassButton(
                onPressed: () {},
                width: 52,
                height: 52,
                padding: EdgeInsets.zero,
                shape: SeaGlassShape.disc,
                palette: frosted,
                style: qsStyle.copyWith(seed: 20),
                semanticLabel: 'Settings',
                child: const Icon(Icons.settings, size: 22),
              ),
              const SizedBox(width: 14),
              SeaGlassButton(
                onPressed: () {},
                width: 52,
                height: 52,
                padding: EdgeInsets.zero,
                shape: SeaGlassShape.disc,
                palette: teal,
                style: qsStyle.copyWith(seed: 21),
                semanticLabel: 'Power',
                child: const Icon(Icons.power_settings_new, size: 24),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// One Quick Settings tile: a capsule with an icon and an optional label.
class QsTile extends StatelessWidget {
  const QsTile({
    super.key,
    required this.icon,
    required this.active,
    required this.onPressed,
    this.label,
    this.subtitle,
    this.seed = 0,
  });

  final IconData icon;
  final String? label;
  final String? subtitle;
  final bool active;
  final int seed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = active ? teal : frosted;
    final iconBadge = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? Colors.transparent : Colors.white.withValues(alpha: .45),
      ),
      child: Icon(icon, size: 24),
    );
    return SeaGlassButton(
      onPressed: onPressed,
      height: 76,
      padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 12),
      shape: SeaGlassShape.capsule,
      palette: palette,
      style: qsStyle.copyWith(seed: seed),
      semanticLabel: label,
      child: label == null
          ? Icon(icon, size: 24)
          : Row(children: [
              iconBadge,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label!, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    if (subtitle != null)
                      Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: palette.ink.withValues(alpha: .8))),
                  ],
                ),
              ),
            ]),
    );
  }
}

/// The brightness slider: teal glass fill, a thin handle and a frosted track.
class GlassSlider extends StatelessWidget {
  const GlassSlider({super.key, required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const height = 56.0, handle = 4.0, spacing = 6.0, minFill = 56.0;
      final width = constraints.maxWidth;
      // Whole logical pixels keep the number of distinct geometries low.
      final fill = (minFill + (width - minFill * 2 - handle - spacing * 2) * value).roundToDouble();
      void update(Offset local) => onChanged(((local.dx - minFill) / (width - minFill * 2)).clamp(0.0, 1.0));
      return Semantics(
        slider: true,
        label: 'Brightness',
        value: '${(value * 100).round()}%',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) => update(d.localPosition),
          onTapDown: (d) => update(d.localPosition),
          child: SizedBox(
            height: height,
            child: Row(children: [
              SeaGlass(
                width: fill,
                height: height,
                shape: SeaGlassShape.capsule,
                palette: teal,
                style: qsStyle.copyWith(seed: 30),
              ),
              const SizedBox(width: spacing),
              Container(
                width: handle,
                height: height + 8,
                decoration: BoxDecoration(color: teal.body, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: spacing),
              Expanded(
                child: SeaGlass(
                  height: height,
                  shape: SeaGlassShape.capsule,
                  palette: frosted,
                  style: qsStyle.copyWith(seed: 31),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: Icon(Icons.brightness_auto_outlined, color: frosted.ink),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader();

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1B2426);
    return DefaultTextStyle.merge(
      style: const TextStyle(color: ink, fontSize: 16),
      child: const Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('10:10', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w500, height: 1)),
          Spacer(),
          Text('JIO 4G - Jio'),
        ]),
        SizedBox(height: 22),
        Row(children: [
          Text('Sat, Oct 10'),
          Spacer(),
          Icon(Icons.signal_cellular_alt, size: 18, color: ink),
          SizedBox(width: 6),
          Icon(Icons.wifi, size: 18, color: ink),
          SizedBox(width: 6),
          _Battery(),
          SizedBox(width: 6),
          Text('Until 7:00 PM'),
        ]),
      ]),
    );
  }
}

class _Battery extends StatelessWidget {
  const _Battery();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(color: const Color(0xFF1B2426), borderRadius: BorderRadius.circular(5)),
        child: const Text('82', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

class _PagerRow extends StatelessWidget {
  const _PagerRow();

  @override
  Widget build(BuildContext context) {
    Widget dot(double width, double alpha) => Container(
          width: width,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF2B3B3F).withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(3),
          ),
        );
    return Row(children: [
      const Spacer(),
      dot(14, .7),
      dot(6, .35),
      dot(6, .35),
      const Spacer(),
      const Icon(Icons.dashboard_customize_outlined, size: 22, color: Color(0xFF2B3B3F)),
    ]);
  }
}
