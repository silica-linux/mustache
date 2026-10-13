// Le operazioni sui file della finestra (MU.4): rinomina, nuova cartella, duplica, Cestino,
// eliminazione, annulla e ripeti, con gli avvisi.

part of 'window.dart';

/// Il clic lento sul nome di un elemento già selezionato apre la rinomina dopo ~440 ms
/// (mustache-spec 8), se non segue un doppio clic.
const Duration slowClickRename = Duration(milliseconds: 440);

extension _Operations on _MustacheWindowState {
  /// La selezione nell'ordine della vista; nelle colonne può essere una cartella fuori dal
  /// contenuto mostrato (la cartella aperta).
  List<Entry> get _selection => [
    for (final e in _entries)
      if (_selected.contains(e.path)) e,
    for (final path in _selected)
      if (!_entries.any((e) => e.path == path)) ?entryAt(path),
  ];

  void _select(Iterable<String> paths) {
    _selected
      ..clear()
      ..addAll(paths);
    _anchor = _cursor = paths.isEmpty ? null : paths.last;
  }

  void _showAlert(Widget alert) => _update(() => _alert = alert);

  void _closeAlert() {
    _update(() => _alert = null);
    _focus.requestFocus();
  }

  /// Un errore: avviso con un solo OK.
  void _showError(String title, [String? message]) => _showAlert(
    SilicaAlert(
      opaque: true,
      icon: _appIcon,
      title: title,
      message: message,
      buttons: [
        AlertButton('OK', role: AlertRole.primary, onPressed: _closeAlert),
      ],
    ),
  );

  void _startRename(String path) {
    _slowClick?.cancel();
    _update(() {
      _select([path]);
      _renaming = path;
    });
  }

  void _endRename() {
    _update(() => _renaming = null);
    _focus.requestFocus();
  }

  /// Il nome scritto nel campo: controlli (R8.2, R8.3), conferma se cambia l'estensione
  /// (R8.4), poi la rinomina.
  void _commitRename(Entry entry, String name) {
    _endRename();
    if (name == entry.name) return;
    final dir = parentOf(entry.path) ?? '/';
    final problem = invalidName(dir, entry.name, name);
    if (problem != null) {
      _showError(problem);
      return;
    }
    if (extensionChanges(entry.name, name, isDirectory: entry.isDirectory)) {
      final (_, oldExt) = splitExtension(entry.name);
      final (newBase, newExt) = splitExtension(name);
      _showAlert(
        SilicaAlert(
          opaque: true,
          icon: _appIcon,
          title: newExt.isEmpty
              ? 'Vuoi togliere l\'estensione «$oldExt»?'
              : 'Vuoi usare l\'estensione «$newExt» invece di «$oldExt»?',
          message:
              'Cambiando l\'estensione il file potrebbe aprirsi con un\'altra app.',
          sideBySide: true,
          buttons: [
            AlertButton(
              'Mantieni $oldExt',
              role: AlertRole.cancel,
              onPressed: () {
                _closeAlert();
                _rename(entry, '$newBase$oldExt');
              },
            ),
            AlertButton(
              newExt.isEmpty ? 'Togli' : 'Usa $newExt',
              role: AlertRole.primary,
              onPressed: () {
                _closeAlert();
                _rename(entry, name);
              },
            ),
          ],
        ),
      );
      return;
    }
    _rename(entry, name);
  }

  void _rename(Entry entry, String name) {
    final result = renameEntry(entry.path, name);
    if (result.error != null) {
      _showError('Non si può rinominare «${entry.name}».', result.error);
      return;
    }
    _undo.push(RenameOp(entry.path, result.path!));
    _select([result.path!]);
    _load();
  }

  /// ⇧⌘N: "cartella senza nome", subito in rinomina; ⌘Z la elimina.
  void _newFolder() {
    final result = createFolder(_history.current);
    if (result.error != null) {
      _showError('Non si può creare la cartella.', result.error);
      return;
    }
    final path = result.path!;
    _undo.push(
      CreateOp([path], 'Nuova cartella', (p) {
        try {
          Directory(p).createSync();
          return (path: p, error: null);
        } on FileSystemException catch (e) {
          return (path: null, error: e.message);
        }
      }),
    );
    _load();
    _startRename(path);
  }

  /// ⌘D: le copie accanto agli originali; la selezione passa alle copie.
  void _duplicate() {
    final sources = _selection;
    if (sources.isEmpty) return;
    final made = <String, String>{};
    String? error;
    for (final entry in sources) {
      final result = duplicate(entry.path);
      if (result.error != null) {
        error = result.error;
        break;
      }
      made[result.path!] = entry.path;
    }
    if (made.isNotEmpty) {
      _undo.push(
        CreateOp(
          made.keys.toList(),
          made.length == 1
              ? 'Duplicazione'
              : 'Duplicazione di ${made.length} elementi',
          (copy) {
            // Ripetere: di nuovo la copia, con lo stesso nome.
            final source = made[copy];
            if (source == null) return (path: null, error: 'Copia sconosciuta');
            final again = duplicate(source);
            if (again.error != null || again.path == copy) return again;
            return renameEntry(again.path!, displayName(copy));
          },
        ),
      );
      _select(made.keys);
    }
    _load();
    if (error != null) _showError('Non si può duplicare.', error);
  }

  /// ⌘⌫: nel Cestino (la selezione passa all'elemento dopo); dentro il Cestino, Ripristina.
  void _moveToTrash() {
    final items = _selection;
    if (items.isEmpty) return;
    if (_trash.contains(_history.current)) {
      _restore(items);
      return;
    }
    final last = _entries.indexWhere((e) => e.path == items.last.path);
    final moves = <(String, String)>[];
    String? error;
    for (final entry in items) {
      final result = _trash.put(entry.path);
      if (result.error != null) {
        error = result.error;
        break;
      }
      moves.add((entry.path, result.path!));
    }
    if (moves.isNotEmpty) _undo.push(TrashOp(moves));
    // L'elemento dopo l'ultimo tolto, se c'è, altrimenti quello prima.
    final gone = {for (final (from, _) in moves) from};
    final rest = [
      for (final e in _entries)
        if (!gone.contains(e.path)) e.path,
    ];
    final next = _entries
        .skip(last + 1)
        .where((e) => !gone.contains(e.path))
        .firstOrNull
        ?.path;
    final pick = next ?? rest.lastOrNull;
    _select([?pick]);
    _load();
    if (error != null) _showError('Non si può spostare nel Cestino.', error);
  }

  void _restore(List<Entry> items) {
    String? error;
    for (final entry in items) {
      final result = _trash.restore(entry.path);
      if (result.error != null) {
        error = result.error;
        break;
      }
    }
    _select(const []);
    _load();
    if (error != null) _showError('Non si può ripristinare.', error);
  }

  /// ⌥⌘⌫: conferma, poi elimina subito (non si annulla).
  void _confirmDelete() {
    final items = _selection;
    if (items.isEmpty) return;
    _showAlert(
      SilicaAlert(
        opaque: true,
        icon: _appIcon,
        title: items.length == 1
            ? 'Confermi di voler eliminare «${items.first.name}»?'
            : 'Confermi di voler eliminare ${items.length} elementi?',
        message: items.length == 1
            ? 'Questo elemento verrà eliminato immediatamente. '
                  'L\'operazione è irreversibile.'
            : 'Questi elementi verranno eliminati immediatamente. '
                  'L\'operazione è irreversibile.',
        sideBySide: true,
        buttons: [
          AlertButton(
            'Annulla',
            role: AlertRole.cancel,
            onPressed: _closeAlert,
          ),
          AlertButton(
            'Elimina',
            role: AlertRole.destructive,
            onPressed: () {
              _closeAlert();
              String? error;
              for (final entry in items) {
                error ??= deletePermanently(entry.path).error;
              }
              _select(const []);
              _load();
              if (error != null) _showError('Non si può eliminare.', error);
            },
          ),
        ],
      ),
    );
  }

  void _undoLast() {
    final error = _undo.undo(_trash);
    _load();
    if (error != null) _showError('Non si può annullare.', error);
  }

  void _redoLast() {
    final error = _undo.redo(_trash);
    _load();
    if (error != null) _showError('Non si può ripetere.', error);
  }

  /// Un clic su un elemento: se era già l'unico selezionato, la rinomina dopo ~440 ms (a meno
  /// che arrivi un doppio clic, che apre).
  void _clickForRename(Entry entry, {required bool wasOnlySelected}) {
    _slowClick?.cancel();
    if (!wasOnlySelected) return;
    _slowClick = Timer(slowClickRename, () {
      if (mounted && _selected.length == 1 && _selected.contains(entry.path)) {
        _startRename(entry.path);
      }
    });
  }
}
