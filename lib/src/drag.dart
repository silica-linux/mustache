// Dragging inside the window (MU-40, docs/spec/operations.md): the image in flight (16 pt icon and name
// in an accent pill for each item, alpha ~0.90, red count badge, green "+" when copying), the drop
// targets that highlight and the "spring-loaded" folder that opens after ~715 ms of hovering.
// Without modifiers it moves if the destination is on the same disk, otherwise copies; with ⌥ it
// copies (R9.1).

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'icon_view.dart' show EntryIcon;
import 'model.dart';

/// The colors of the drag image and the drop highlights, as Amalfi tokens (light): `Accent/Amalfi`,
/// `Palette/Terracotta` (the count), `Palette/Ulivo` (the copy "+") and `Accent/Amalfi` for the drop
/// line.
const Color dragAccent = Color(0xFF0E77E6);
const Color dragCountBadge = Color(0xFFF0562E);
const Color dragCopyBadge = Color(0xFF34A853);
const Color dropLine = Color(0xFF0E77E6);
const double dragAlpha = 0.90;

/// The dragged items left in place while the image travels: dimmed (provisional, as the desktop).
const double dragDim = 0.5;
const double dragPill = 16;

/// The pills of the image: one row per item, at this pitch, after the room for the badges.
const double dragRowPitch = dragPill + 4;
const double dragImagePad = 12;

/// The most items drawn in the image.
const int dragImageRows = 5;

/// The hover time on a folder before it opens (R9.1, spring-loaded folder).
const Duration springOpen = Duration(milliseconds: 715);

/// The spring-loaded folder blinks before it opens (MU-40): at ~340 ms the highlight goes off for
/// 80 ms, comes back for 107 ms, and goes off again until the folder opens.
const Duration springBlinkAt = Duration(milliseconds: 340);
const Duration springBlinkOff = Duration(milliseconds: 80);
const Duration springBlinkOn = Duration(milliseconds: 107);

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

/// Copies (does not move) with ⌥ or when source and destination are on different disks; ⌘ moves
/// even across disks (R9.1).
bool dropCopies(
  List<String> paths,
  String destination, {
  bool? alt,
  bool? meta,
  List<MountPoint>? mounts,
}) {
  final option = alt ?? HardwareKeyboard.instance.isAltPressed;
  if (option) return true;
  final command = meta ?? HardwareKeyboard.instance.isMetaPressed;
  if (command) return false;
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
    final shown = paths.take(dragImageRows).toList();
    return Opacity(
      opacity: dragAlpha,
      child: Stack(
        children: [
          // Room for the badges inside the image: Ossido gets it as a picture.
          Padding(
            padding: const EdgeInsets.only(
              left: dragImagePad,
              top: dragImagePad,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final path in shown) _row(path)],
            ),
          ),
          if (paths.length > 1 || copy)
            Positioned(
              left: 0,
              top: 0,
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

/// The mark of a destination folder in the render tree: the window finds the folder under the
/// pointer with [folderAt] (its own drags and Ossido's) and drops there with [onDrop].
@immutable
class FolderDropMeta {
  const FolderDropMeta(this.path, {this.onDrop, this.onSpring});
  final String path;
  final void Function(DragPayload payload, String destination)? onDrop;

  /// The spring-loaded opening, for the folders that have it.
  final VoidCallback? onSpring;
}

/// The innermost destination folder under `position` (view coordinates).
FolderDropMeta? folderAt(Offset position, int viewId) {
  final result = HitTestResult();
  WidgetsBinding.instance.hitTestInView(result, position, viewId);
  for (final entry in result.path) {
    final target = entry.target;
    if (target is RenderMetaData && target.metaData is FolderDropMeta) {
      return target.metaData as FolderDropMeta;
    }
  }
  return null;
}

/// The folder a drag is over, for the window below it: its [FolderDropTarget] lights up.
class DropHover extends InheritedNotifier<ValueNotifier<String?>> {
  const DropHover({
    super.key,
    required ValueNotifier<String?> super.notifier,
    required super.child,
  });

  static String? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DropHover>()?.notifier?.value;
}

/// Whether the highlight of the folder under a drag is off in the blink of the spring-loading.
class DropBlink extends InheritedNotifier<ValueNotifier<bool>> {
  const DropBlink({
    super.key,
    required ValueNotifier<bool> super.notifier,
    required super.child,
  });

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DropBlink>()
          ?.notifier
          ?.value ??
      false;
}

/// A drop target for dragged items: `builder` receives whether a drag is over it (the window
/// decides, [DropHover]); the window opens it after hovering for `springOpen` when it has
/// `onSpring` (spring-loaded folder).
class FolderDropTarget extends StatelessWidget {
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
  Widget build(BuildContext context) => MetaData(
    metaData: FolderDropMeta(path, onDrop: onDrop, onSpring: onSpring),
    behavior: HitTestBehavior.translucent,
    child: Builder(
      builder: (context) => builder(
        context,
        DropHover.of(context) == path && !DropBlink.of(context),
      ),
    ),
  );
}

/// The count badge: 20 pt red circle with white digits (MU-40).
const double dragBadgeSide = 20;

/// The largest drag image, per side (the embedder's limit).
const double dragImageMax = 1024;

/// One image of `pieces` (each at its origin, same coordinates as `grab`) at ~90 % (MU-40), with
/// the count badge of `count` items at `grab + badgeFromPointer` when there are several; and the
/// point of it that stays under the pointer: `grab`, so the items move with the pointer from where
/// they were taken. Null when there is nothing to draw.
(ui.Image?, Offset) composeDragImage(
  List<(Offset, ui.Image)> pieces,
  Offset grab,
  int count, {
  Offset badgeFromPointer = const Offset(-2, -2),
}) {
  final badge = count > 1
      ? Rect.fromCircle(
          center: grab + badgeFromPointer,
          radius: dragBadgeSide / 2,
        )
      : null;
  var bounds = badge;
  for (final (origin, image) in pieces) {
    final rect = origin & Size(image.width.toDouble(), image.height.toDouble());
    bounds = bounds?.expandToInclude(rect) ?? rect;
  }
  if (bounds == null) return (null, Offset.zero);
  // Within the largest image, around the press.
  bounds = bounds.intersect(
    Rect.fromCenter(center: grab, width: dragImageMax, height: dragImageMax),
  );
  bounds = Rect.fromLTRB(
    bounds.left.floorToDouble(),
    bounds.top.floorToDouble(),
    bounds.right.ceilToDouble(),
    bounds.bottom.ceilToDouble(),
  );
  if (bounds.isEmpty) return (null, Offset.zero);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..translate(-bounds.left, -bounds.top);
  final translucent = Paint()
    ..color = const Color(0xFFFFFFFF).withValues(alpha: dragAlpha);
  for (final (origin, image) in pieces) {
    canvas.drawImage(image, origin, translucent);
  }
  if (badge != null) {
    canvas.drawCircle(
      badge.center,
      dragBadgeSide / 2,
      Paint()..color = dragCountBadge,
    );
    final digits = TextPainter(
      text: TextSpan(
        text: '$count',
        style: const TextStyle(
          fontFamily: uiFontFamily,
          package: 'silica_ui',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFFFFFFFF),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    digits.paint(
      canvas,
      badge.center - Offset(digits.width / 2, digits.height / 2),
    );
    digits.dispose();
  }
  final picture = recorder.endRecording();
  final image = picture.toImageSync(
    bounds.width.toInt(),
    bounds.height.toInt(),
  );
  picture.dispose();
  return (image, grab - bounds.topLeft);
}

/// Hands the files to Ossido's drag (the embedder's `silica/drag` › `start`) with `image` on the
/// pointer and its point `hotspot` under it, so the image stays where the pointer grabbed the
/// items. True if Ossido took it.
Future<bool> startFileDrag(
  List<String> paths,
  ui.Image? image,
  Offset hotspot,
) async {
  final args = <String, Object?>{
    'uris': [for (final p in paths) Uri.file(p).toString()],
  };
  if (image != null) {
    // rawRgba: premultiplied, as Wayland wants.
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes != null) {
      args['icon'] = {
        'width': image.width,
        'height': image.height,
        'rgba': base64Encode(bytes.buffer.asUint8List()),
        'x': hotspot.dx.round().clamp(0, math.max(0, image.width - 1)),
        'y': hotspot.dy.round().clamp(0, math.max(0, image.height - 1)),
      };
    }
  }
  try {
    return await SilicaDrag.channel.invokeMethod<bool>('start', args) ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}
