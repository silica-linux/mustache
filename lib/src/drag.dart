// Il trascinamento dentro la finestra (MU-40, mustache-spec 9.1): l'immagine in volo (icona 16 e
// nome in una pillola d'accento per ogni elemento, alfa ~0,90, badge rosso del numero, "+" verde
// quando copia), le destinazioni che si evidenziano e la cartella "a molla" che si apre dopo
// ~715 ms di sosta. Senza modificatori sposta se la destinazione è sullo stesso disco, altrimenti
// copia; con ⌥ copia (R9.1).

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'icon_view.dart' show EntryIcon;
import 'model.dart';

const Color dragAccent = Color(0xFF0064E1);
const Color dragCountBadge = Color(0xFFFB3936);
const Color dragCopyBadge = Color(0xFF00C261);
const Color dropLine = Color(0xFFB3D7FF);
const double dragAlpha = 0.90;
const double dragPill = 16;

/// La sosta su una cartella prima che si apra (R9.1, cartella a molla).
const Duration springOpen = Duration(milliseconds: 715);

/// Quel che si trascina: gli elementi e la cartella da cui vengono.
@immutable
class DragPayload {
  const DragPayload(this.paths, this.from);
  final List<String> paths;
  final String from;
}

/// Il punto di montaggio di un percorso: il mount più lungo che lo contiene.
String mountOf(String path, List<MountPoint> mounts) {
  var best = '/';
  for (final m in mounts) {
    final p = m.path;
    if ((path == p || path.startsWith(p == '/' ? '/' : '$p/')) &&
        p.length > best.length) {
      best = p;
    }
  }
  return best;
}

List<MountPoint>? _mounts;

/// I mount del sistema, letti una volta.
List<MountPoint> get systemMounts {
  if (_mounts != null) return _mounts!;
  try {
    return _mounts = parseMountinfo(
      File('/proc/self/mountinfo').readAsStringSync(),
    );
  } on FileSystemException {
    return _mounts = const [];
  }
}

/// Copia (non sposta) se c'è ⌥ o se origine e destinazione sono su dischi diversi.
bool dropCopies(
  List<String> paths,
  String destination, {
  bool? alt,
  List<MountPoint>? mounts,
}) {
  final option = alt ?? HardwareKeyboard.instance.isAltPressed;
  if (option) return true;
  final m = mounts ?? systemMounts;
  final target = mountOf(destination, m);
  return paths.any((p) => mountOf(p, m) != target);
}

/// La destinazione accetta questi elementi? Non su se stessi né dentro se stessi, né nella
/// cartella da cui vengono (lì non cambierebbe niente).
bool canDrop(DragPayload payload, String destination) =>
    destination != payload.from &&
    !payload.paths.any(
      (p) => destination == p || destination.startsWith('$p/'),
    );

/// L'immagine in volo: una pillola per elemento (al più 5), il badge del numero e il "+".
class DragImage extends StatelessWidget {
  const DragImage({super.key, required this.paths, this.env});

  final List<String> paths;
  final Map<String, String>? env;

  @override
  Widget build(BuildContext context) {
    final copy = HardwareKeyboard.instance.isAltPressed;
    final shown = paths.take(5).toList();
    return Opacity(
      opacity: dragAlpha,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final path in shown) _row(path)],
          ),
          if (paths.length > 1 || copy)
            Positioned(
              left: -12,
              top: -12,
              child: Row(
                children: [
                  if (copy) _badge('+', dragCopyBadge, 18),
                  if (paths.length > 1)
                    _badge('${paths.length}', dragCountBadge, 20),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String path) {
    final entry = entryAt(path);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: entry == null
                ? null
                : EntryIcon(entry: entry, side: 16, env: env),
          ),
          const SizedBox(width: 4),
          Container(
            height: dragPill,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dragAccent,
              borderRadius: BorderRadius.circular(dragPill / 2),
            ),
            child: Text(
              displayName(path),
              style: const TextStyle(
                fontFamily: uiFontFamily,
                package: 'silica_ui',
                fontSize: 12,
                color: Color(0xFFFFFFFF),
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color, double side) => Container(
    width: side,
    height: side,
    margin: const EdgeInsets.only(right: 2),
    alignment: Alignment.center,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: uiFontFamily,
        package: 'silica_ui',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFFFFFFFF),
        decoration: TextDecoration.none,
      ),
    ),
  );
}

/// Una destinazione per gli elementi trascinati: `builder` riceve se è sotto il puntatore con
/// un carico accettabile; dopo una sosta di `springOpen` chiama `onSpring` (cartella a molla).
class FolderDropTarget extends StatefulWidget {
  const FolderDropTarget({
    super.key,
    required this.path,
    required this.onDrop,
    required this.builder,
    this.onSpring,
  });

  final String path;
  final void Function(DragPayload payload, String destination) onDrop;
  final Widget Function(BuildContext context, bool active) builder;
  final VoidCallback? onSpring;

  @override
  State<FolderDropTarget> createState() => _FolderDropTargetState();
}

class _FolderDropTargetState extends State<FolderDropTarget> {
  Timer? _spring;

  @override
  void dispose() {
    _spring?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DragTarget<DragPayload>(
    onWillAcceptWithDetails: (details) {
      final ok = canDrop(details.data, widget.path);
      if (ok && widget.onSpring != null) {
        _spring?.cancel();
        _spring = Timer(springOpen, () => widget.onSpring?.call());
      }
      return ok;
    },
    onLeave: (_) => _spring?.cancel(),
    onAcceptWithDetails: (details) {
      _spring?.cancel();
      widget.onDrop(details.data, widget.path);
    },
    builder: (context, candidates, rejected) =>
        widget.builder(context, candidates.isNotEmpty),
  );
}
