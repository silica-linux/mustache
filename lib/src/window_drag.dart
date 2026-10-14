// Il trascinamento nella finestra (MU-40): chi si trascina, dove si rilascia, la cartella a
// molla.

part of 'window.dart';

extension _Drag on _MustacheWindowState {
  /// Gli elementi che partono trascinando `entry`: la selezione se ne fa parte, sennò lui.
  List<String> _dragPaths(Entry entry) => _selected.contains(entry.path)
      ? [for (final e in _selection) e.path]
      : [entry.path];

  /// Rende trascinabile un elemento della vista (soglia: 1 pt per il mouse, come nell'elenco).
  /// Uscendo dalla finestra il trascinamento passa a Ossido (`SilicaDrag`), con la stessa
  /// immagine: le altre app e il Dock ricevono i file.
  Widget _draggable(Entry entry, Widget child) => Draggable<DragPayload>(
    data: DragPayload(_dragPaths(entry), _history.current),
    dragAnchorStrategy: pointerDragAnchorStrategy,
    feedback: RepaintBoundary(
      key: _dragImageKey,
      child: DragImage(paths: _dragPaths(entry), env: widget.iconsEnv),
    ),
    onDragStarted: () {
      _slowClick?.cancel();
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

  /// File rilasciati da un'altra app (o tornati qui da fuori): sulla cartella sotto il
  /// puntatore, altrimenti in quella aperta; sposta o copia come dentro la finestra.
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

  /// Una cartella della vista come destinazione (e cartella a molla: entra dopo la sosta).
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

  /// Rilascio: sposta o copia (R9.1) nella destinazione.
  void _drop(DragPayload payload, String destination) {
    final copy = dropCopies(payload.paths, destination);
    _startTransfer(
      copy ? TransferKind.copy : TransferKind.move,
      payload.paths,
      destination,
    );
  }
}

/// Tiene un `Overlay` sopra la finestra (le immagini trascinate ci vivono) e ricostruisce la sua
/// voce quando la finestra cambia.
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
