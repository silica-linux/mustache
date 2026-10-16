// The status bar (⌘', MU-04, docs/spec/bars.md): 28 pt below the content, the text
// centered (item count and free space, or selected count of the total and free space, R1.21) and, in the icon view, the
// size slider (80 × 4 track, 18 × 14 knob, 17 pt from the right edge).

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';

const double statusBarHeight = 28;

/// The icon size for slider value 0–112 (docs/spec/bars.md): up to 56 it is 16 + 2 × value, then 5
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

/// The width of the icon size slider and its distance from the right edge.
const double statusSliderWidth = 96;
const double statusSliderRight = 16;

/// The status bar (kit `Apps/Mustache/Status Bar`): 28 tall, a 1 pt separator along the top, the
/// text centered in Label `Text/Secondary` (`Text/Tertiary` in an inactive window).
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
    final colors = AmalfiTheme.of(context).colors;
    return SizedBox(
      key: const ValueKey('status bar'),
      height: statusBarHeight,
      child: ColoredBox(
        color: colors.surfaceWindow,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 6,
              height: 16,
              child: Center(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AmalfiType.callout(
                    color: active ? colors.textSecondary : colors.textTertiary,
                  ),
                ),
              ),
            ),
            if (value != null)
              Positioned(
                right: statusSliderRight,
                top: 0,
                bottom: 0,
                width: statusSliderWidth,
                child: Center(
                  key: const ValueKey('icon slider'),
                  child: AmalfiSlider(
                    value: value,
                    min: 0,
                    max: 112,
                    onChanged: onSlider,
                    semanticLabel: l10n.iconSize,
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 1,
              child: ColoredBox(color: colors.lineSeparator),
            ),
          ],
        ),
      ),
    );
  }
}
