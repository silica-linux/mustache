// La barra di stato (⌘', MU-04, mustache-spec 1.5): 28 pt sotto i contenuti, il testo centrato
// ("N elementi, X disponibili", "K di N selezionati, X disponibili", R1.21) e, nella vista a
// icone, il cursore della dimensione (binario 80 × 4, manopola 18 × 14, 17 pt dal bordo destro).

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

const double statusBarHeight = 28;

/// Il lato dell'icona per il valore del cursore 0–112 (mustache-spec 1.5): fino a 56 è
/// 16 + 2 × valore, poi 5 pt per unità fino a 80, poi più in fretta fino a 512.
double iconSideFor(double value) {
  final v = value.clamp(0, 112).toDouble();
  if (v <= 56) return 16 + 2 * v;
  if (v <= 80) return 128 + 5 * (v - 56);
  // 80 → 244, 90 → 312, 100 → 392, 106 → 448, 112 → 512.
  const points = [
    (80.0, 244.0),
    (90.0, 312.0),
    (100.0, 392.0),
    (106.0, 448.0),
    (112.0, 512.0),
  ];
  for (var i = 1; i < points.length; i++) {
    final (x0, y0) = points[i - 1];
    final (x1, y1) = points[i];
    if (v <= x1) return y0 + (y1 - y0) * (v - x0) / (x1 - x0);
  }
  return 512;
}

/// Il valore del cursore per un lato (l'inversa di [iconSideFor]).
double sliderValueFor(double side) {
  var lo = 0.0;
  var hi = 112.0;
  for (var i = 0; i < 40; i++) {
    final mid = (lo + hi) / 2;
    if (iconSideFor(mid) < side) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return hi;
}

/// Lo spazio libero del disco che contiene `path`, in byte (da `df`); null se non si sa.
int? freeBytes(String path) {
  try {
    final r = Process.runSync('df', ['-B1', '--output=avail', path]);
    if (r.exitCode != 0) return null;
    final lines = '${r.stdout}'.trim().split('\n');
    return lines.length < 2 ? null : int.tryParse(lines.last.trim());
  } on ProcessException {
    return null;
  }
}

/// "12,34 GB": due decimali (come nella barra di stato).
String formatFree(int bytes) {
  String num(double v, int d) => v.toStringAsFixed(d).replaceAll('.', ',');
  if (bytes >= 1e12) return '${num(bytes / 1e12, 2)} TB';
  if (bytes >= 1e9) return '${num(bytes / 1e9, 2)} GB';
  if (bytes >= 1e6) return '${num(bytes / 1e6, 1)} MB';
  return '${num(bytes / 1e3, 0)} KB';
}

/// Il testo della barra (R1.21).
String statusText({
  required int count,
  required int selected,
  int? free,
  bool listing = true,
}) {
  final items = count == 1 ? '1 elemento' : '$count elementi';
  final head = selected == 0
      ? items
      : selected == 1 && count == 1
      ? '1 di 1 selezionato'
      : '$selected di $count selezionati';
  if (!listing || free == null) return head;
  return '$head, ${formatFree(free)} disponibili';
}

/// I colori della barra di stato (MU-04), chiaro e scuro.
@immutable
class StatusBarColors {
  const StatusBarColors({
    required this.fill,
    required this.line,
    required this.text,
    required this.textInactive,
    required this.track,
    required this.filled,
    required this.knob,
    required this.knobShadow,
  });

  final Color fill;
  final Color line;
  final Color text;
  final Color textInactive;
  final Color track;
  final Color filled;
  final Color knob;
  final Color? knobShadow;

  static const StatusBarColors light = StatusBarColors(
    fill: Color(0xFFFFFFFF),
    line: Color(0xFFD9D9D9),
    text: Color(0xFF858585),
    textInactive: Color(0xFFBDBDBD),
    track: Color(0xFFE5E5E5),
    filled: Color(0xFF0176F7),
    knob: Color(0xFFFFFFFF),
    knobShadow: Color(0x40000000),
  );

  /// Scuro: manopola `#dfdfdf` piena, senza ombra.
  static const StatusBarColors dark = StatusBarColors(
    fill: Color(0xFF2F2F2F),
    line: Color(0xFF000000),
    text: Color(0xFFA1A1A1),
    textInactive: Color(0xFF636363),
    track: Color(0xFF434343),
    filled: Color(0xFF0D7BFB),
    knob: Color(0xFFDFDFDF),
    knobShadow: null,
  );

  static StatusBarColors of(BuildContext context) =>
      MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark
      ? dark
      : light;
}

class StatusBar extends StatelessWidget {
  const StatusBar({
    super.key,
    required this.text,
    this.slider,
    this.onSlider,
    this.active = true,
  });

  final String text;

  /// Finestra attiva: in quella inattiva il testo è più tenue.
  final bool active;

  /// Il valore del cursore delle icone (null: nessun cursore).
  final double? slider;
  final ValueChanged<double>? onSlider;

  @override
  Widget build(BuildContext context) {
    final value = slider;
    final colors = StatusBarColors.of(context);
    return Container(
      key: const ValueKey('barra di stato'),
      height: statusBarHeight,
      decoration: BoxDecoration(
        color: colors.fill,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: uiFontFamily,
                package: 'silica_ui',
                fontSize: 11,
                color: active ? colors.text : colors.textInactive,
              ),
            ),
          ),
          if (value != null)
            Positioned(
              right: 17,
              top: 0,
              bottom: 0,
              width: 82,
              child: _Slider(value: value, onChanged: onSlider, colors: colors),
            ),
        ],
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({required this.value, required this.colors, this.onChanged});
  final double value;
  final StatusBarColors colors;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // Corsa di 62 pt sul binario di 80 (la manopola larga 18).
      const travel = 62.0;
      final x = 1 + travel * value / 112;
      void set(double local) =>
          onChanged?.call(((local - 1 - 9) / travel * 112).clamp(0, 112));
      return GestureDetector(
        key: const ValueKey('cursore delle icone'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => set(d.localPosition.dx),
        onHorizontalDragUpdate: (d) => set(d.localPosition.dx),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Positioned(
              left: 1,
              width: 80,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: colors.track,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Positioned(
              left: 1,
              width: x + 9,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: colors.filled,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Positioned(
              left: x,
              child: Container(
                width: 18,
                height: 14,
                decoration: BoxDecoration(
                  color: colors.knob,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: [
                    if (colors.knobShadow case final shadow?)
                      BoxShadow(
                        color: shadow,
                        blurRadius: 2,
                        offset: const Offset(0, 0.5),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
