import 'package:flutter/material.dart';
import 'package:sea_glass/sea_glass.dart';

/// A single large glass pill: glittering grain, a glowing lower edge and
/// colored light transmitted onto the ground beneath it.
class PillPage extends StatefulWidget {
  const PillPage({super.key});

  @override
  State<PillPage> createState() => _PillPageState();
}

const lagoonPill = SeaGlassPalette(body: Color(0xFF27A9BC), edge: Color(0xFF9EF2FA), ink: Color(0xFFE9FEFF));
const lilacPill = SeaGlassPalette(body: Color(0xFF9B7BC4), edge: Color(0xFFF1DDFF), ink: Color(0xFFFFF7FF));
const amberPill = SeaGlassPalette(body: Color(0xFFE0A253), edge: Color(0xFFFFF1C2), ink: Color(0xFF4A2A06));

const pillStyle = SeaGlassStyle(
  frost: .35, grain: .95, tumble: .004, thickness: 10, bulge: .75, elevation: 14, transmission: .9, seed: 3,
);

class _PillPageState extends State<PillPage> {
  static const palettes = {'Lagoon': lagoonPill, 'Lilac': lilacPill, 'Amber': amberPill};
  String palette = 'Lagoon';
  int taps = 0;

  @override
  Widget build(BuildContext context) {
    final glass = palettes[palette]!;
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final width = (constraints.maxWidth - 48).clamp(200.0, 560.0);
          return Column(children: [
            const Spacer(),
            SeaGlassButton(
              onPressed: () => setState(() => taps++),
              width: width,
              height: 96,
              shape: SeaGlassShape.capsule,
              palette: glass,
              style: pillStyle,
              child: Text(
                taps == 0 ? 'Sea Glass' : 'Tapped $taps×',
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w400, letterSpacing: .2),
              ),
            ),
            const Spacer(),
            Wrap(spacing: 8, children: [
              for (final name in palettes.keys)
                ChoiceChip(
                  label: Text(name),
                  selected: palette == name,
                  onSelected: (_) => setState(() => palette = name),
                ),
            ]),
            const SizedBox(height: 32),
          ]);
        }),
      ),
    );
  }
}
