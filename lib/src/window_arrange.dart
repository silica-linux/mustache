// Free icon positions in the window (sort "None", R4.7, R4.8, mustache#4, mustache#5): loading
// and saving the folder's arrangement, dragging icons around, Clean Up, Clean Up By and Snap to
// Grid, arrows that move spatially.

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
    _cleanUpTimer?.cancel();
    _moveDuration = Duration.zero;
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

  void _toggleSnap() => _update(() {
    _arrangement.snap = !_arrangement.snap;
    if (_arrangement.snap && _arrangement.free) {
      _arrangement.icons
        ..clear()
        ..addAll(cleanUp(_arrangement.icons, _freeGrid));
    }
    _saveArrangement();
  });

  /// Clean Up (R4.8): after the measured delay the off-grid icons slide to the nearest free cell,
  /// decelerating; with `selection` only the selected ones.
  void _cleanUp({bool selection = false}) {
    if (!_arrangement.free) return;
    final only = selection
        ? {
            for (final e in _entries)
              if (_selected.contains(e.path)) e.name,
          }
        : null;
    _cleanUpTimer?.cancel();
    // The delay counts from the release on the item; the menu calls back after its blink.
    _cleanUpTimer = Timer(cleanUpDelay - MenuMetrics.fadeStart, () {
      if (!mounted) return;
      _update(() {
        _moveDuration = cleanUpDuration;
        final cleaned = cleanUp(_arrangement.icons, _freeGrid, only: only);
        _arrangement.icons
          ..clear()
          ..addAll(cleaned);
        _saveArrangement();
      });
      _cleanUpTimer = Timer(
        cleanUpDuration,
        () => _moveDuration = Duration.zero,
      );
    });
  }

  /// Clean Up By: every icon on the grid in the order of `key`, at once (the new arrangement
  /// appears in the next frame, MU-21); the folder stays in free positions.
  void _arrangeBy(SortKey key) {
    if (_view != ViewMode.icons) return;
    _update(() {
      _cleanUpTimer?.cancel();
      _moveDuration = Duration.zero;
      final grid = _freeGrid;
      _arrangement
        ..free = true
        ..icons.clear()
        ..icons.addAll(
          arrangeOnGrid(
            [for (final e in sortEntries(_entries, key, kindOf: _kind)) e.name],
            grid,
            grid.columnsFor(_contentWidth),
          ),
        );
      _saveArrangement();
    });
  }

  /// A drop of icons of this folder inside its own view: they move by the pointer's movement from
  /// the press, keeping their offsets; with Snap to Grid each lands on the nearest free cell.
  bool _acceptsMove(DragPayload payload) =>
      _arrangement.free &&
      payload.from == _history.current &&
      payload.paths.every((p) => parentOf(p) == _history.current);

  void _moveDropped(DragPayload payload, Offset dropAt) {
    final from = _pressAt;
    if (from == null || !_acceptsMove(payload)) return;
    final names = {
      for (final p in payload.paths) p.substring(p.lastIndexOf('/') + 1),
    };
    _update(() {
      _moveDuration = Duration.zero;
      final moved = moveIcons(
        _arrangement.icons,
        names,
        dropAt - from,
        _freeGrid,
        snap: _arrangement.snap,
      );
      _arrangement.icons
        ..clear()
        ..addAll(moved);
      _saveArrangement();
    });
  }

  /// The arrows with free positions: the nearest icon on that side (true if handled).
  bool _moveSpatially(Move move, {bool extend = false}) {
    final positions = _freePositions;
    if (_view != ViewMode.icons || positions == null) return false;
    if (positions.isEmpty) return true;
    final from = _cursor ?? _anchor;
    String? next;
    if (from == null || !positions.containsKey(from)) {
      // Nothing chosen: the first icon in reading order.
      final sorted = positions.entries.toList()
        ..sort((a, b) {
          final dy = a.value.dy.compareTo(b.value.dy);
          return dy != 0 ? dy : a.value.dx.compareTo(b.value.dx);
        });
      next = sorted.first.key;
    } else {
      next = spatialNeighbour(positions, from, switch (move) {
        Move.up => const Offset(0, -1),
        Move.down => const Offset(0, 1),
        Move.left => const Offset(-1, 0),
        Move.right => const Offset(1, 0),
      });
    }
    if (next == null) return true;
    final target = next;
    _update(() {
      _cursor = target;
      if (extend) {
        _selected.add(target);
      } else {
        _anchor = target;
        _selected
          ..clear()
          ..add(target);
      }
    });
    return true;
  }
}
