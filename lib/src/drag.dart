// Dragging inside the window (MU-40, docs/spec/operations.md): the image in flight (16 pt icon and name
// in an accent pill for each item, alpha ~0.90, red count badge, green "+" when copying), the drop
// targets that highlight and the "spring-loaded" folder that opens after ~715 ms of hovering.
// Without modifiers it moves if the destination is on the same disk, otherwise copies; with ⌥ it
// copies (R9.1).

import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
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

/// The hover time on a folder before it opens (R9.1, spring-loaded folder).
const Duration springOpen = Duration(milliseconds: 715);

/// What is being dragged: the items and the folder they come from.
@immutable
class DragPayload {
  const DragPayload(this.paths, this.from);
  final List<String> paths;
  final String from;
}

/// The mount point of a path: the longest mount that contains it.
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

/// The system mounts, read once.
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

/// Copies (does not move) with ⌥ or when source and destination are on different disks.
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

/// Does the destination accept these items? Not onto themselves nor inside themselves, nor into the
/// folder they come from (nothing would change there).
bool canDrop(DragPayload payload, String destination) =>
    destination != payload.from &&
    !payload.paths.any(
      (p) => destination == p || destination.startsWith('$p/'),
    );

/// The image in flight: one pill per item (at most 5), the count badge and the "+".
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

/// The mark of a destination folder in the render tree: a drop from another app (which does not go
/// through `DragTarget`) finds it with [folderAt].
@immutable
class FolderDropMeta {
  const FolderDropMeta(this.path);
  final String path;
}

/// The innermost destination folder under `position` (view coordinates).
String? folderAt(Offset position, int viewId) {
  final result = HitTestResult();
  WidgetsBinding.instance.hitTestInView(result, position, viewId);
  for (final entry in result.path) {
    final target = entry.target;
    if (target is RenderMetaData && target.metaData is FolderDropMeta) {
      return (target.metaData as FolderDropMeta).path;
    }
  }
  return null;
}

/// A drop target for dragged items: `builder` receives whether it is under the pointer with an
/// acceptable payload; after hovering for `springOpen` it calls `onSpring` (spring-loaded folder).
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
    builder: (context, candidates, rejected) => MetaData(
      metaData: FolderDropMeta(widget.path),
      behavior: HitTestBehavior.translucent,
      child: widget.builder(context, candidates.isNotEmpty),
    ),
  );
}

/// A `Draggable` that starts only after the pointer has moved more than `threshold` pt (the icon
/// view, MU-34); the drag still starts from the press point, so a drop moves the item by the whole
/// movement of the pointer (R7.7).
class ThresholdDraggable<T extends Object> extends Draggable<T> {
  const ThresholdDraggable({
    super.key,
    required super.child,
    required super.feedback,
    required this.threshold,
    super.data,
    super.dragAnchorStrategy,
    super.onDragStarted,
    super.onDragUpdate,
  });

  final double threshold;

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) => _ThresholdDragRecognizer(threshold)..onStart = onStart;
}

class _ThresholdDragRecognizer extends MultiDragGestureRecognizer {
  _ThresholdDragRecognizer(this.threshold) : super(debugOwner: null);

  final double threshold;

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) =>
      _ThresholdPointerState(
        event.position,
        event.kind,
        gestureSettings,
        threshold,
      );

  @override
  String get debugDescription => 'threshold drag';
}

class _ThresholdPointerState extends MultiDragPointerState {
  _ThresholdPointerState(
    super.initialPosition,
    super.kind,
    super.gestureSettings,
    this.threshold,
  );

  final double threshold;

  @override
  void checkForResolutionAfterMove() {
    if ((pendingDelta ?? Offset.zero).distance > threshold) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
  }
}
