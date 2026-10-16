// The path bar (⌥⌘P, MU-03; kit `Apps/Mustache/Path Bar`): below the content, 28 pt tall with a 1 pt
// separator on top, one segment per folder from the disk to the open one (or to the chosen item,
// R1.17): 16 pt icon at x 12, the name 4 pt after it (Caption), a 12 pt chevron 11 pt after the
// name and 8 before the next icon. A click opens the folder (R1.18). When space runs out, all the
// middle segments shrink equally down to their minimum, then the first, then the second to last; the
// last stays whole; cut text fades out (R1.20, behaviour measured, sizes Amalfi).

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'icon_view.dart' show EntryIcon;
import 'model.dart';

const double pathBarHeight = 28;
const double pathBarLeft = 12;
const double pathIcon = 16;
const double pathTextGap = 4;

/// The space of a segment besides its text: icon and gap, 11 before the chevron, the 12 pt
/// chevron and 8 before the next icon.
const double pathChevronGap = 11;
const double pathChevron = 12;
const double pathSegmentEnd = 8;
const double pathSegmentExtra =
    pathIcon + pathTextGap + pathChevronGap + pathChevron + pathSegmentEnd;

/// The narrowest a segment shrinks to: its icon and chevron without the name.
const double pathSegmentMin = pathSegmentExtra;

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
    final colors = AmalfiTheme.of(context).colors;
    final style = AmalfiType.callout(color: colors.textPrimary);
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
      child: ColoredBox(
        color: colors.surfaceWindow,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 1,
              child: ColoredBox(color: colors.lineSeparator),
            ),
            LayoutBuilder(
              builder: (context, box) {
                final widths = pathBarWidths(
                  natural,
                  box.maxWidth - pathBarLeft - 8,
                );
                return Padding(
                  padding: const EdgeInsets.only(left: pathBarLeft, top: 1),
                  // Too many segments for the width are cut at the right edge, not an overflow.
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      maxWidth: double.infinity,
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
                    ),
                  ),
                );
              },
            ),
          ],
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
    required AmalfiColors colors,
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
      // Everything hangs from the top of the segment (kit: icon and name at y 6, chevron at y 8 of the
      // 28 pt bar, 1 under its separator).
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: SizedBox(
              width: pathIcon,
              height: pathIcon,
              child: entry == null
                  ? null
                  : EntryIcon(entry: entry, side: pathIcon, env: env),
            ),
          ),
          const SizedBox(width: pathTextGap),
          Expanded(
            child: Padding(padding: const EdgeInsets.only(top: 5), child: text),
          ),
          if (!last) ...[
            const SizedBox(width: pathChevronGap),
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: AmalfiGlyph(
                AmalfiGlyphs.chevronRight,
                size: pathChevron,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(width: pathSegmentEnd),
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
