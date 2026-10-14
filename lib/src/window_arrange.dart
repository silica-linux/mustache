// Free icon positions in the window (sort "None", R4.7, mustache#4): loading and saving the
// folder's arrangement.

part of 'window.dart';

extension _Arrange on _MustacheWindowState {
  FreeGrid get _freeGrid => FreeGrid.of(side: _iconSide);

  /// The free positions shown by the icon view, by path; null when the folder is sorted (or the
  /// view shows search or tag results, which are always sorted).
  Map<String, Offset>? get _freePositions {
    if (!_arrangement.free || _searching || _tagView != null) return null;
    return {
      for (final e in _entries)
        if (_arrangement.icons[e.name] case final p?) e.path: p,
    };
  }

  /// Reads the arrangement of the open folder and gives a place to the items that have none yet
  /// (new files: the first free cells).
  void _loadArrangement() {
    _arrangement =
        widget.iconPositions?.of(_history.current) ?? FolderArrangement();
    if (_arrangement.free) _completeArrangement();
  }

  void _completeArrangement() {
    final names = [for (final e in _entries) e.name];
    final grid = _freeGrid;
    final placed = placeNew(
      names,
      _arrangement.icons,
      grid,
      grid.columnsFor(_contentWidth),
    );
    final changed =
        placed.length != _arrangement.icons.length ||
        placed.entries.any((e) => _arrangement.icons[e.key] != e.value);
    if (!changed) return;
    // Items that are gone are forgotten.
    _arrangement.icons
      ..clear()
      ..addAll(placed);
    _saveArrangement();
  }

  void _saveArrangement() =>
      widget.iconPositions?.put(_history.current, _arrangement);

  /// Sort "None": the icons keep the positions saved for the folder (R4.7); the first time, they
  /// start where the sorted grid had them.
  void _sortNone() => _update(() {
    _arrangement.free = true;
    if (_arrangement.icons.isEmpty) {
      final grid = _freeGrid;
      _arrangement.icons.addAll(
        arrangeOnGrid(
          [for (final e in _entries) e.name],
          grid,
          grid.columnsFor(_contentWidth),
        ),
      );
    }
    _completeArrangement();
    _saveArrangement();
  });

  /// A sort order: the grid stretches and reflows again; the free positions stay saved for when
  /// "None" comes back.
  void _sortBy(SortKey key) => _update(() {
    _sort = key;
    _descending = false;
    _entries = sortEntries(_entries, _sort, kindOf: _kind);
    if (_arrangement.free) {
      _arrangement.free = false;
      _saveArrangement();
    }
  });
}
