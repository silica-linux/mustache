// La vista a colonne nella finestra (MU-22): la radice, il contenuto delle colonne, la scelta
// con il clic e con le frecce (R5.3).

part of 'window.dart';

extension _Columns on _MustacheWindowState {
  /// La radice: la voce della barra laterale che contiene la cartella aperta (la più
  /// specifica), altrimenti `/` (R5.6).
  String get _columnRoot {
    var best = '/';
    for (final place in [...widget.places, widget.trash]) {
      final p = place.path;
      if ((_history.current == p || _history.current.startsWith('$p/')) &&
          p.length > best.length) {
        best = p;
      }
    }
    return best;
  }

  /// Il contenuto ordinato di una colonna, letto una volta per caricamento.
  List<Entry> _columnList(String dir) => _columnCache[dir] ??= sortEntries(
    listDirectory(dir, showHidden: _showHidden).entries,
    _sort,
    descending: _descending,
  );

  /// L'elemento scelto delle colonne: quello selezionato, o la cartella aperta.
  String get _leaf =>
      _selected.length == 1 ? _selected.first : _history.current;

  /// Clic su un elemento della colonna di `dir`: una cartella diventa quella aperta (la sua
  /// colonna compare a destra), un file resta scelto nella sua.
  void _selectInColumn(Entry entry, String dir) {
    final target = entry.isDirectory ? entry.path : dir;
    if (target != _history.current) _history.go(target);
    _select([entry.path]);
    _load();
  }

  void _moveInColumns(Move move) {
    final leaf = _leaf;
    final parent = parentOf(leaf) ?? '/';
    switch (move) {
      case Move.up || Move.down:
        final siblings = _columnList(
          leaf == _history.current ? parent : _history.current,
        );
        if (siblings.isEmpty) return;
        final i = siblings.indexWhere((e) => e.path == leaf);
        final next = i < 0
            ? (move == Move.down ? 0 : siblings.length - 1)
            : (i + (move == Move.down ? 1 : -1)).clamp(0, siblings.length - 1);
        final entry = siblings[next];
        _selectInColumn(entry, parentOf(entry.path) ?? '/');
      case Move.right:
        // Dentro la cartella scelta: la sua prima voce.
        final entry = entryAt(leaf);
        if (entry == null || !entry.isDirectory) return;
        final children = _columnList(leaf);
        if (children.isNotEmpty) _selectInColumn(children.first, leaf);
      case Move.left:
        // La cartella che contiene la scelta, nella colonna a sinistra.
        final dir = leaf == _history.current ? parent : _history.current;
        if (dir == _columnRoot || dir == '/') return;
        final entry = entryAt(dir);
        if (entry != null) _selectInColumn(entry, parentOf(dir) ?? '/');
    }
  }
}
