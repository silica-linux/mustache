// Copia, incolla e sposta nella finestra (MU-41, MU-43): ⌘C mette i percorsi negli appunti,
// ⌘V li copia nella cartella aperta, ⌥⌘V li sposta (R9.8). La copia gira in background; la
// finestra di avanzamento compare se dura più di ~2,5 s (R9.4); un conflitto apre la sua
// finestra e aspetta la scelta.

part of 'window.dart';

extension _Transfers on _MustacheWindowState {
  void _copySelection() {
    final paths = [for (final e in _selection) e.path];
    if (paths.isEmpty) return;
    FileClipboard.paths = paths;
    // Anche come testo, per le altre app (un percorso per riga).
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
    // Spostati, gli appunti non valgono più.
    if (move) FileClipboard.paths = const [];
  }

  /// Avvia una copia o uno spostamento verso `destination`.
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
      // Un elemento nuovo nella destinazione compare subito; l'avanzamento ridisegna al più
      // ogni 50 ms.
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
            'Copia',
            (path) => (path: null, error: 'La copia non si può ripetere.'),
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
        kind == TransferKind.copy
            ? 'Non si può completare la copia.'
            : 'Non si può completare lo spostamento.',
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

  /// Il percorso è un elemento ancora in copia (nome attenuato, torta).
  Transfer? _pendingTransfer(String path) {
    for (final t in _transfers) {
      if (t.isPending(path)) return t;
    }
    return null;
  }
}
