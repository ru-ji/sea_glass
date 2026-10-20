import 'package:flutter/material.dart';
import 'package:sea_glass/sea_glass.dart';

/// Mix recipes, palettes and Material 3 colours, with live sliders.
class PlaygroundPage extends StatefulWidget {
  const PlaygroundPage({super.key});

  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

class _PlaygroundPageState extends State<PlaygroundPage> {
  static const palettes = {
    'Lagoon': SeaGlassPalette.lagoon,
    'Lilac': SeaGlassPalette.lilac,
    'Rose': SeaGlassPalette.rose,
    'Amber': SeaGlassPalette.amber,
    'Mint': SeaGlassPalette.mint,
  };
  String palette = 'Lagoon';
  bool materialYou = false;
  bool tintedShadow = false;
  double tumble = .025, frost = .55, light = 315, shadow = 180;

  @override
  Widget build(BuildContext context) {
    final glass = materialYou ? SeaGlassPalette.of(context) : palettes[palette]!;
    final style = SeaGlassStyle.reference.copyWith(tumble: tumble, frost: frost, lightDegrees: light, shadowDegrees: shadow, shadowTinted: tintedShadow);
    return Material(
      color: const Color(0xFFF7F4EF),
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.all(32), children: [
          SeaGlassTheme(
            style: style,
            palette: glass,
            child: Wrap(spacing: 24, runSpacing: 40, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SeaGlassButton(
                onPressed: () {},
                width: 220,
                height: 72,
                style: style.copyWith(seed: 33),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.edit_outlined), SizedBox(width: 12), Text('Compose'),
                ]),
              ),
              SeaGlassButton(
                onPressed: () {},
                shape: SeaGlassShape.capsule,
                style: style.copyWith(seed: 7),
                child: const Text('Capsule'),
              ),
              SeaGlassSurface(
                width: 80,
                height: 80,
                shape: SeaGlassShape.disc,
                style: style.copyWith(seed: 12),
                child: const Icon(Icons.add),
              ),
            ]),
          ),
          const SizedBox(height: 40),
          Wrap(spacing: 8, children: [
            for (final name in palettes.keys)
              ChoiceChip(
                label: Text(name),
                selected: !materialYou && palette == name,
                onSelected: (_) => setState(() {
                  palette = name;
                  materialYou = false;
                }),
              ),
          ]),
          SwitchListTile(
            title: const Text('Material 3 colors'),
            value: materialYou,
            onChanged: (v) => setState(() => materialYou = v),
          ),
          SwitchListTile(
            title: const Text('Tinted shadow'),
            value: tintedShadow,
            onChanged: (v) => setState(() => tintedShadow = v),
          ),
          _slider('Tumble', tumble, .065, (v) => tumble = v),
          _slider('Frost', frost, 1, (v) => frost = v),
          _slider('Light', light, 360, (v) => light = v),
          _slider('Shadow', shadow, 360, (v) => shadow = v),
        ]),
      ),
    );
  }

  Widget _slider(String label, double value, double max, ValueChanged<double> set) => Row(children: [
        SizedBox(width: 64, child: Text(label)),
        Expanded(child: Slider(value: value, max: max, onChanged: (v) => setState(() => set(v)))),
      ]);
}
