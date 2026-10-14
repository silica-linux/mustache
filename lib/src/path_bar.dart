// The path bar (⌥⌘P, MU-03, mustache-spec 1.4): below the content, 28 pt tall (2 px line and
// background), one segment per folder from the disk to the open one (or to the chosen item, R1.17):
// 16 pt icon, text 5 pt after it, 5 × 7 chevron. A click opens the folder (R1.18). When space runs
// out, all the middle segments shrink equally down to 29 pt, then the first, then the second to
// last; the last stays whole; cut text fades out (R1.20).

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'icon_view.dart' show EntryIcon;
import 'model.dart';

const double pathBarHeight = 28;
const double pathBarLeft = 13;
const double pathIcon = 16;
const double pathTextGap = 5;

/// The space of a segment besides its text: icon, gaps and chevron (pitch = text + ~36).
const double pathSegmentExtra = 36;

/// The narrowest a segment shrinks to: icon and chevron.
const double pathSegmentMin = 29;

@immutable
class PathBarColors {
  const PathBarColors(this.fill, this.lineDark, this.lineLight, this.text);
  final Color fill;
  final Color lineDark;
  final Color lineLight;
  final Color text;

  static PathBarColors of({required bool dark}) => dark
      ? const PathBarColors(
          Color(0xFF2F2F2F),
          Color(0xFF3F3F40),
          Color(0xFF434343),
          Color(0xFFA1A1A1),
        )
      : const PathBarColors(
          Color(0xFFFFFFFF),
          Color(0xFFDCDDDD),
          Color(0xFFE6E6E6),
          Color(0xFF7F7F7F),
        );
}

/// Segment widths in `available` pt (R1.20): all middle ones equal down to 29, then the first, then
/// the second to last; the last whole.
List<double> pathBarWidths(List<double> natural, double available) {
  final widths = [...natural];
  double total() => widths.fold(0.0, (a, b) => a + b);
  if (natural.length < 2 || total() <= available) return widths;
  final last = widths.length - 1;
  final middle = [for (var i = 1; i < last - 1; i++) i];

  // Shrinks the segments `idx` (at most down to the minimum) by as much as needed, the widest
  // first: the result is a common cap.
  void shrink(List<int> idx) {
    final excess = total() - available;
    // Half a point of tolerance: the search for the cap is approximate.
    if (excess <= 0.5 || idx.isEmpty) return;
    // The cap t such that sum(max(min, min(w, t))) removes `excess`.
    var lo = pathSegmentMin;
    var hi = idx.map((i) => widths[i]).fold(pathSegmentMin, math.max);
    double cut(double t) => idx
        .map(
          (i) => widths[i] - math.max(pathSegmentMin, math.min(widths[i], t)),
        )
        .fold(0.0, (a, b) => a + b);
    if (cut(lo) <= excess) {
      for (final i in idx) {
        widths[i] = math.min(widths[i], pathSegmentMin);
      }
      return;
    }
    for (var step = 0; step < 40; step++) {
      final mid = (lo + hi) / 2;
      if (cut(mid) > excess) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    for (final i in idx) {
      widths[i] = math.max(pathSegmentMin, math.min(widths[i], hi));
    }
  }

  shrink(middle);
  shrink([0]);
  if (last >= 2) shrink([last - 1]);
  return widths;
}

/// The folders from the disk to `path` included.
List<String> pathSegments(String path) {
  final out = <String>['/'];
  var current = '';
  for (final part in path.split('/').where((p) => p.isNotEmpty)) {
    current = '$current/$part';
    out.add(current);
  }
  return out;
}

class PathBar extends StatelessWidget {
  const PathBar({
    super.key,
    required this.path,
    required this.onOpen,
    this.env,
    this.diskName,
  });

  /// The last segment: the open folder or the chosen item.
  final String path;
  final ValueChanged<String> onOpen;
  final Map<String, String>? env;

  /// The name of the first segment (the root of the file system).
  final String? diskName;

  @override
  Widget build(BuildContext context) {
    final dark =
        MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark;
    final colors = PathBarColors.of(dark: dark);
    final style = TextStyle(
      fontFamily: uiFontFamily,
      package: 'silica_ui',
      fontSize: 13,
      color: colors.text,
    );
    final segments = pathSegments(path);
    String label(String p) => p == '/' ? diskName ?? l10n.disk : displayName(p);
    final natural = [
      for (var i = 0; i < segments.length; i++)
        _textWidth(label(segments[i]), style) +
            (i == segments.length - 1
                ? pathIcon + pathTextGap + 4
                : pathSegmentExtra),
    ];
    return SizedBox(
      key: const ValueKey('path bar'),
      height: pathBarHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.fill,
          border: Border(top: BorderSide(color: colors.lineDark)),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final widths = pathBarWidths(
              natural,
              box.maxWidth - pathBarLeft - 8,
            );
            return Padding(
              padding: const EdgeInsets.only(left: pathBarLeft, top: 1),
              child: Row(
                children: [
                  for (var i = 0; i < segments.length; i++)
                    SizedBox(
                      width: widths[i],
                      child: _segment(
                        segments[i],
                        label(segments[i]),
                        last: i == segments.length - 1,
                        truncated: widths[i] < natural[i] - 0.5,
                        style: style,
                        colors: colors,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _segment(
    String path,
    String label, {
    required bool last,
    required bool truncated,
    required TextStyle style,
    required PathBarColors colors,
  }) {
    final entry = entryAt(path);
    Widget text = Text(
      label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
      style: style,
    );
    if (truncated) {
      // Cut text fades out on the right, without "…".
      text = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
          stops: [0.6, 1],
        ).createShader(rect),
        child: text,
      );
    }
    return GestureDetector(
      key: ValueKey('segment $path'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onOpen(path),
      child: Row(
        children: [
          SizedBox(
            width: pathIcon,
            height: pathIcon,
            child: entry == null
                ? null
                : EntryIcon(entry: entry, side: pathIcon, env: env),
          ),
          const SizedBox(width: pathTextGap),
          Expanded(child: text),
          if (!last) ...[
            const SizedBox(width: 5),
            SizedBox(
              width: 5,
              height: 7,
              child: CustomPaint(painter: _Chevron(colors.text)),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  static double _textWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }
}

class _Chevron extends CustomPainter {
  const _Chevron(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0.75, 0.5)
        ..lineTo(size.width - 0.75, size.height / 2)
        ..lineTo(0.75, size.height - 0.5),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Chevron old) => old.color != color;
}
