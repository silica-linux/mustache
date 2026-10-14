// Copy, paste and move in the window (MU-41, MU-43): ⌘C puts the paths on the clipboard, ⌘V copies
// them into the open folder, ⌥⌘V moves them (R9.8). The copy runs in the background; the progress
// window appears if it lasts more than ~2.5 s (R9.4); a conflict opens its window and waits for a
// choice.

part of 'window.dart';

extension _Transfers on _MustacheWindowState {
  void _copySelection([List<Entry>? items]) {
    final paths = [for (final e in items ?? _selection) e.path];
    if (paths.isEmpty) return;
    FileClipboard.paths = paths;
    // Also as text, for other apps (one path per line).
    Clipboard.setData(ClipboardData(text: paths.join('\n'))).ignore();
  }

  void _paste({required bool move}) {
    final sources = [
      for (final p in FileClipboard.paths)
        if (FileSystemEntity.typeSync(p, followLinks: false) !=
            FileSystemEntityType.notFound)
          p,
    ];
    if (sources.isEmpty) return;
    _startTransfer(
      move ? TransferKind.move : TransferKind.copy,
      sources,
      _history.current,
    );
    // Once moved, the clipboard no longer applies.
    if (move) FileClipboard.paths = const [];
  }

  /// Starts a copy or a move to `destination`.
  Future<void> _startTransfer(
    TransferKind kind,
    List<String> sources,
    String destination,
  ) async {
    final transfer = Transfer(
      kind: kind,
      sources: sources,
      destination: destination,
    );
    _update(() => _transfers.add(transfer));
    var lastPaint = DateTime(0);
    var listed = 0;
    transfer.addListener(() {
      if (!mounted) return;
      // A new item in the destination appears right away; progress repaints at most every 50 ms.
      final now = DateTime.now();
      if (transfer.targets.length != listed) {
        listed = transfer.targets.length;
        if (destination == _history.current) _load();
      } else if (now.difference(lastPaint) > const Duration(milliseconds: 50)) {
        lastPaint = now;
        _update(() {});
      }
    });
    final slow = Timer(progressWindowDelay, () {
      if (mounted && transfer.state == TransferState.running) {
        _update(() => _progress = transfer);
      }
    });
    await transfer.run(
      onConflict: (name) {
        final done = Completer<ConflictChoice>();
        _update(
          () => _conflict = (
            name: name,
            moving: kind == TransferKind.move,
            done: done,
          ),
        );
        return done.future;
      },
    );
    slow.cancel();
    if (!mounted) return;
    _update(() {
      _transfers.remove(transfer);
      if (_progress == transfer) _progress = null;
    });
    if (transfer.completed.isNotEmpty) {
      if (kind == TransferKind.move) {
        _undo.push(MoveOp([...transfer.completed]));
      } else {
        final copies = [for (final (_, to) in transfer.completed) to];
        _undo.push(
          CreateOp(
            copies,
            l10n.copy,
            (path) => (path: null, error: l10n.copyCantRedo),
          ),
        );
      }
      if (destination == _history.current) {
        _select([for (final (_, to) in transfer.completed) to]);
      }
    }
    _load();
    if (transfer.state == TransferState.failed) {
      _showError(
        kind == TransferKind.copy ? l10n.cantCopy : l10n.cantMove,
        transfer.error,
      );
    }
  }

  void _chooseConflict(ConflictChoice choice) {
    final conflict = _conflict;
    if (conflict == null) return;
    _update(() => _conflict = null);
    conflict.done.complete(choice);
  }

  /// The path is an item still being copied (dimmed name, pie).
  Transfer? _pendingTransfer(String path) {
    for (final t in _transfers) {
      if (t.isPending(path)) return t;
    }
    return null;
  }
}
