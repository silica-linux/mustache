// Copy views (docs/spec/operations.md for the behaviour): the progress pie next to the name in the
// list, the progress window (an Amalfi panel with the app icon, a "Copying …" line, a progress bar
// with a cancel button and the "done of total" line) and the conflict window (an Amalfi alert with
// Stop, Keep Both and Replace).

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'model.dart';
import 'transfer.dart';

const Size progressWindowSize = Size(404, 96);
const double pieSide = 14;

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
    child: CustomPaint(
      painter: _PiePainter(
        fraction,
        AmalfiTheme.of(context).colors.textTertiary,
      ),
    ),
  );
}

class _PiePainter extends CustomPainter {
  const _PiePainter(this.fraction, this.color);
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    canvas
      ..drawArc(
        rect.deflate(1.5),
        -math.pi / 2,
        2 * math.pi * fraction.clamp(0, 1),
        true,
        Paint()..color = color,
      )
      ..drawOval(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  @override
  bool shouldRepaint(_PiePainter old) =>
      old.fraction != fraction || old.color != color;
}

String _bytes(int n) {
  if (n < 1000) return l10n.sizeBytes(n);
  if (n < 1000 * 1000) return '${decimal(n / 1000, 1)} KB';
  if (n < 1000 * 1000 * 1000) return '${decimal(n / 1e6, 1)} MB';
  return '${decimal(n / 1e9, 2)} GB';
}

/// The panel of the progress window: `Surface/Raised` with the alert radius, a rim and the level 3
/// shadow (`AmalfiAlertSurface`).
Widget _panel(Widget child) => AmalfiAlertSurface(radius: 16, child: child);

/// The progress window of a copy.
class ProgressWindow extends StatelessWidget {
  const ProgressWindow({super.key, required this.transfer, this.icon});

  final Transfer transfer;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    final verb = transfer.kind == TransferKind.copy
        ? l10n.copying
        : l10n.moving;
    final name = transfer.currentName ?? '';
    return SizedBox(
      key: const ValueKey('progress window'),
      width: progressWindowSize.width,
      height: progressWindowSize.height,
      child: _panel(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 40, height: 40, child: icon),
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
                      style: AmalfiType.body(color: colors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AmalfiProgressBar(
                            value: transfer.fraction.clamp(0, 1),
                            semanticLabel: verb,
                          ),
                        ),
                        const SizedBox(width: 8),
                        KeyedSubtree(
                          key: const ValueKey('cancel copy'),
                          child: AmalfiIconButton(
                            icon: AmalfiGlyph(AmalfiGlyphs.xmark),
                            onPressed: transfer.cancel,
                            semanticLabel: l10n.cancel,
                            size: AmalfiControlSize.small,
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
                      style: AmalfiType.callout(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The name conflict window: an alert with the three choices.
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
      ConflictChoice choice, {
      bool primary = false,
    }) => KeyedSubtree(
      key: ValueKey('conflict ${choice.name}'),
      child: AmalfiPushButton(
        label: label,
        variant: primary
            ? AmalfiPushButtonVariant.primary
            : AmalfiPushButtonVariant.secondary,
        onPressed: () => onChoice(choice),
      ),
    );
    return KeyedSubtree(
      key: const ValueKey('conflict window'),
      child: AmalfiAlert(
        icon: icon,
        title: moving ? l10n.conflictMove(name) : l10n.conflictCopy(name),
        // The default one on top when stacked: the list is read last to first.
        actions: [
          button(l10n.stop, ConflictChoice.stop),
          button(l10n.keepBoth, ConflictChoice.keepBoth),
          button(l10n.replace, ConflictChoice.replace, primary: true),
        ],
      ),
    );
  }
}
