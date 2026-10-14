// Dragging inside the window (MU-40): what is dragged, where it is dropped, the spring-loaded
// folder.

part of 'window.dart';

extension _Drag on _MustacheWindowState {
  /// The items that leave when dragging `entry`: the selection if it belongs to it, otherwise the
  /// entry alone.
  List<String> _dragPaths(Entry entry) => _selected.contains(entry.path)
      ? [for (final e in _selection) e.path]
      : [entry.path];

  /// Makes an item of the view draggable (threshold: 1 pt for the mouse, as in the list).
  /// Leaving the window, the drag passes to Ossido (`SilicaDrag`) with the same image: other apps
  /// and the Dock receive the files.
  Widget _draggable(Entry entry, Widget child) => Draggable<DragPayload>(
    data: DragPayload(_dragPaths(entry), _history.current),
    dragAnchorStrategy: pointerDragAnchorStrategy,
    feedback: RepaintBoundary(
      key: _dragImageKey,
      child: DragImage(paths: _dragPaths(entry), env: widget.iconsEnv),
    ),
    onDragStarted: () {
      _slowClick?.cancel();
      _rowDragged = true;
      _draggedOut = false;
    },
    onDragUpdate: (details) => _maybeDragOut(entry, details.globalPosition),
    child: child,
  );

  void _maybeDragOut(Entry entry, Offset position) {
    if (_draggedOut) return;
    final size = MediaQuery.sizeOf(context);
    if ((Offset.zero & size).contains(position)) return;
    _draggedOut = true;
    final paths = _dragPaths(entry);
    final boundary = _dragImageKey.currentContext?.findRenderObject();
    final image = boundary is RenderRepaintBoundary
        ? boundary.toImageSync()
        : null;
    SilicaDrag.start(paths, icon: image).whenComplete(() => image?.dispose());
  }

  /// Files dropped by another app (or coming back here from outside): onto the folder under the
  /// pointer, otherwise into the open one; move or copy as inside the window.
  void _externalDrop(SilicaDrop drop) {
    final paths = drop.paths;
    if (paths.isEmpty || !widget.focused) return;
    final destination =
        folderAt(drop.position, View.of(context).viewId) ?? _history.current;
    final from = File(paths.first).parent.path;
    final payload = DragPayload(paths, from);
    if (!canDrop(payload, destination)) return;
    if (paths.every((p) => File(p).parent.path == destination)) return;
    _drop(payload, destination);
  }

  /// A folder of the view as a drop target (and spring-loaded folder: it opens after hovering).
  Widget _folderTarget(
    Entry entry,
    Widget Function(BuildContext context, bool active) builder,
  ) => entry.isDirectory
      ? FolderDropTarget(
          path: entry.path,
          onDrop: _drop,
          onSpring: () {
            if (mounted) _navigate(entry.path);
          },
          builder: builder,
        )
      : builder(context, false);

  /// Drop: move or copy (R9.1) into the destination.
  void _drop(DragPayload payload, String destination) {
    final copy = dropCopies(payload.paths, destination);
    _startTransfer(
      copy ? TransferKind.copy : TransferKind.move,
      payload.paths,
      destination,
    );
  }
}

/// Keeps an `Overlay` above the window (dragged images live there) and rebuilds its entry when the
/// window changes.
class _OverlayHost extends StatefulWidget {
  const _OverlayHost({required this.child});
  final Widget child;

  @override
  State<_OverlayHost> createState() => _OverlayHostState();
}

class _OverlayHostState extends State<_OverlayHost> {
  late final OverlayEntry _entry = OverlayEntry(builder: (_) => widget.child);

  @override
  void didUpdateWidget(_OverlayHost old) {
    super.didUpdateWidget(old);
    _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry
      ..remove()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}
