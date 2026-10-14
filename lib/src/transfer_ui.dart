// Copy views (mustache-spec 9.2): the progress pie next to the name in the list, the progress
// window (404 × 88: 34 pt icon, "Copio …", 309 × 20 accent bar, × on the right, "done of total"
// line) and the conflict window (404 × 106, three small buttons 22 tall: Keep Both 117, Stop 88,
// Replace 88).

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'model.dart';
import 'transfer.dart';

const Size progressWindowSize = Size(404, 88);
const Size conflictWindowSize = Size(404, 106);
const double pieSide = 14;
const Color transferAccent = Color(0xFF0064E1);

/// After how long the progress window opens by itself (R9.4, ~2–3 s, estimated).
const Duration progressWindowDelay = Duration(milliseconds: 2500);

/// The pie: a 1 pt gray outline that fills clockwise.
class ProgressPie extends StatelessWidget {
  const ProgressPie(this.fraction, {super.key});
  final double fraction;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: pieSide,
    height: pieSide,
    child: CustomPaint(painter: _PiePainter(fraction)),
  );
}

class _PiePainter extends CustomPainter {
  const _PiePainter(this.fraction);
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    canvas
      ..drawArc(
        rect.deflate(1.5),
        -math.pi / 2,
        2 * math.pi * fraction.clamp(0, 1),
        true,
        Paint()..color = const Color(0xFF8E8E93),
      )
      ..drawOval(
        rect,
        Paint()
          ..color = const Color(0xFF8E8E93)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  @override
  bool shouldRepaint(_PiePainter old) => old.fraction != fraction;
}

String _bytes(int n) {
  if (n < 1000) return l10n.sizeBytes(n);
  if (n < 1000 * 1000) return '${decimal(n / 1000, 1)} KB';
  if (n < 1000 * 1000 * 1000) return '${decimal(n / 1e6, 1)} MB';
  return '${decimal(n / 1e9, 2)} GB';
}

TextStyle _text(
  double size, {
  FontWeight? weight,
  Color color = const Color(0xFF1A1A1A),
}) => TextStyle(
  fontFamily: uiFontFamily,
  package: 'silica_ui',
  fontSize: size,
  fontWeight: weight,
  color: color,
);

BoxDecoration _panel() => BoxDecoration(
  color: const Color(0xFFFFFFFF),
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: const Color(0x40000000), width: 0.5),
  boxShadow: const [
    BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 10)),
  ],
);

/// The progress window of a copy.
class ProgressWindow extends StatelessWidget {
  const ProgressWindow({super.key, required this.transfer, this.icon});

  final Transfer transfer;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final verb = transfer.kind == TransferKind.copy
        ? l10n.copying
        : l10n.moving;
    final name = transfer.currentName ?? '';
    return Container(
      key: const ValueKey('progress window'),
      width: progressWindowSize.width,
      height: progressWindowSize.height,
      decoration: _panel(),
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 34, height: 34, child: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.transferLine(
                    verb,
                    name,
                    displayName(transfer.destination),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(13),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    SizedBox(
                      width: 309,
                      height: 20,
                      child: _Bar(transfer.fraction),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      key: const ValueKey('cancel copy'),
                      onTap: transfer.cancel,
                      child: SizedBox(
                        width: 15,
                        height: 15,
                        child: CustomPaint(painter: _CrossPainter()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.progressOf(
                    _bytes(transfer.doneBytes),
                    _bytes(transfer.totalBytes),
                  ),
                  style: _text(11, color: const Color(0xFF8E8E93)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(this.fraction);
  final double fraction;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      height: 6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(3),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: fraction.clamp(0, 1),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: transferAccent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2,
      Paint()..color = const Color(0xFFB0B0B5),
    );
    final p = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final c = size.center(Offset.zero);
    const d = 3.0;
    canvas
      ..drawLine(c + const Offset(-d, -d), c + const Offset(d, d), p)
      ..drawLine(c + const Offset(d, -d), c + const Offset(-d, d), p);
  }

  @override
  bool shouldRepaint(_CrossPainter old) => false;
}

/// The name conflict window.
class ConflictWindow extends StatelessWidget {
  const ConflictWindow({
    super.key,
    required this.name,
    required this.moving,
    required this.onChoice,
    this.icon,
  });

  final String name;
  final bool moving;
  final ValueChanged<ConflictChoice> onChoice;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    Widget button(
      String label,
      double width,
      ConflictChoice choice, {
      bool primary = false,
    }) => GestureDetector(
      key: ValueKey('conflict ${choice.name}'),
      onTap: () => onChoice(choice),
      child: Container(
        width: width,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? transferAccent : const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: _text(
            12,
            color: primary ? const Color(0xFFFFFFFF) : const Color(0xFF242424),
          ),
        ),
      ),
    );
    return Container(
      key: const ValueKey('conflict window'),
      width: conflictWindowSize.width,
      height: conflictWindowSize.height,
      decoration: _panel(),
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 34, height: 34, child: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  moving ? l10n.conflictMove(name) : l10n.conflictCopy(name),
                  maxLines: 3,
                  style: _text(12),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              button(l10n.keepBoth, 117, ConflictChoice.keepBoth),
              const SizedBox(width: 8),
              button(l10n.stop, 88, ConflictChoice.stop),
              const SizedBox(width: 8),
              button(l10n.replace, 88, ConflictChoice.replace, primary: true),
            ],
          ),
        ],
      ),
    );
  }
}
