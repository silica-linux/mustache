// The column view in the window (MU-22): the root, the column contents, choosing with a click and
// with the arrows (R5.3).

part of 'window.dart';

extension _Columns on _MustacheWindowState {
  /// The root: the sidebar entry that contains the open folder (the most specific one), otherwise
  /// `/` (R5.6).
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

  /// The sorted contents of a column, read once per load.
  List<Entry> _columnList(String dir) => _columnCache[dir] ??= sortEntries(
    listDirectory(dir, showHidden: _showHidden).entries,
    _sort,
    descending: _descending,
    kindOf: _kind,
  );

  /// The chosen item of the columns: the selected one, or the open folder.
  String get _leaf =>
      _selected.length == 1 ? _selected.first : _history.current;

  /// Click on an item in the column of `dir`: a folder becomes the open one (its column appears on
  /// the right), a file stays chosen in its own.
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
        // Into the chosen folder: its first entry.
        final entry = entryAt(leaf);
        if (entry == null || !entry.isDirectory) return;
        final children = _columnList(leaf);
        if (children.isNotEmpty) _selectInColumn(children.first, leaf);
      case Move.left:
        // The folder containing the choice, in the column on the left.
        final dir = leaf == _history.current ? parent : _history.current;
        if (dir == _columnRoot || dir == '/') return;
        final entry = entryAt(dir);
        if (entry != null) _selectInColumn(entry, parentOf(dir) ?? '/');
    }
  }
}
