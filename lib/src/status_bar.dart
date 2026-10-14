// The status bar (⌘', MU-04, mustache-spec 1.5): 28 pt below the content, the text
// centered (item count and free space, or selected count of the total and free space, R1.21) and, in the icon view, the
// size slider (80 × 4 track, 18 × 14 knob, 17 pt from the right edge).

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';

const double statusBarHeight = 28;

/// The icon size for slider value 0–112 (mustache-spec 1.5): up to 56 it is 16 + 2 × value, then 5
/// pt per unit up to 80, then faster up to 512.
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

/// The slider value for a size (the inverse of [iconSideFor]).
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

/// The free space of the disk containing `path`, in bytes (from `df`); null if unknown.
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

/// "12.34 GB" ("12,34 GB" in Italian): two decimals (as in the status bar).
String formatFree(int bytes) {
  if (bytes >= 1e12) return '${decimal(bytes / 1e12, 2)} TB';
  if (bytes >= 1e9) return '${decimal(bytes / 1e9, 2)} GB';
  if (bytes >= 1e6) return '${decimal(bytes / 1e6, 1)} MB';
  return '${decimal(bytes / 1e3, 0)} KB';
}

/// The bar text (R1.21).
String statusText({
  required int count,
  required int selected,
  int? free,
  bool listing = true,
}) {
  final head = selected == 0
      ? l10n.itemCount(count)
      : l10n.selectedCount(selected, count);
  if (!listing || free == null) return head;
  return l10n.available(head, formatFree(free));
}

/// Status bar colors (MU-04), light and dark.
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

  /// Dark: a solid `#dfdfdf` knob, without shadow.
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

  /// Active window: in an inactive one the text is fainter.
  final bool active;

  /// The value of the icon slider (null: no slider).
  final double? slider;
  final ValueChanged<double>? onSlider;

  @override
  Widget build(BuildContext context) {
    final value = slider;
    final colors = StatusBarColors.of(context);
    return Container(
      key: const ValueKey('status bar'),
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
      // 62 pt of travel on the 80 track (the knob is 18 wide).
      const travel = 62.0;
      final x = 1 + travel * value / 112;
      void set(double local) =>
          onChanged?.call(((local - 1 - 9) / travel * 112).clamp(0, 112));
      return GestureDetector(
        key: const ValueKey('icon slider'),
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
