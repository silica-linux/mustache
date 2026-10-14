// The list view in the window (MU-20, docs/spec/list-view.md; geometry and colors in list_view.dart): a
// header that sorts and resizes, rows with disclosure triangle, icon and cells, folders expanded in
// place (15 pt indent per level), alternating rows down to the bottom even for an empty folder,
// block selection. The empty rows after the last one are background: a click clears the selection,
// a right click opens the folder menu.

part of 'window.dart';

/// A list row: the item and its level (0 for the folder's own contents).
typedef ListRowItem = ({Entry entry, int depth});

extension _ListView on _MustacheWindowState {
  /// Rows in order: the contents with expanded folders opened (only in the list, not in search
  /// results).
  List<ListRowItem> get _listRows {
    final rows = <ListRowItem>[];
    void add(List<Entry> entries, int depth) {
      for (final entry in entries) {
        rows.add((entry: entry, depth: depth));
        if (entry.isDirectory && _expanded.contains(entry.path)) {
          add(_childrenOf(entry.path), depth + 1);
        }
      }
    }

    add(_entries, 0);
    return rows;
  }

  /// The order the arrows and ⇧-click move in: in the list, expanded children too.
  List<Entry> get _ordered => _view == ViewMode.list && !_searching
      ? [for (final row in _listRows) row.entry]
      : _entries;

  List<Entry> _childrenOf(String path) => _childCache[path] ??= sortEntries(
    listDirectory(path, showHidden: _showHidden).entries,
    _sort,
    descending: _descending,
    kindOf: _kind,
  );

  /// Expands or collapses a folder in place; with ⌥ the whole subtree (R3.7).
  void _toggleExpanded(Entry entry, {bool subtree = false}) {
    final open = !_expanded.contains(entry.path);
    _update(() {
      if (!subtree) {
        open ? _expanded.add(entry.path) : _expanded.remove(entry.path);
        return;
      }
      // The subtree, at most 2000 folders (a huge folder does not freeze the window).
      final stack = [entry.path];
      var budget = 2000;
      while (stack.isNotEmpty && budget-- > 0) {
        final path = stack.removeLast();
        if (open) {
          _expanded.add(path);
          for (final child in _childrenOf(path)) {
            if (child.isDirectory && !child.isLink) stack.add(child.path);
          }
        } else {
          _expanded.remove(path);
          for (final open in _expanded.toList()) {
            if (open.startsWith('$path/')) _expanded.remove(open);
          }
          break;
        }
      }
    });
  }

  /// → and ← in the list: expand and collapse the cursor's folder (R3.7).
  bool _expandAtCursor({required bool open}) {
    if (_view != ViewMode.list || _searching) return false;
    final path = _cursor ?? _anchor;
    final entry = path == null
        ? null
        : _listRows.where((r) => r.entry.path == path).firstOrNull?.entry;
    if (entry == null || !entry.isDirectory) return true;
    if (open != _expanded.contains(entry.path)) {
      final alt = HardwareKeyboard.instance.isAltPressed;
      _toggleExpanded(entry, subtree: alt);
    }
    return true;
  }

  /// Click on a header: a new column starts ascending (Date and Size descending), the same one is
  /// reversed (R3.5).
  void _sortList(SortKey key) {
    final column = listColumns.firstWhere((c) => c.key == key);
    _update(() {
      _descending = _sort == key ? !_descending : column.descendingFirst;
      _sort = key;
      _entries = sortEntries(
        _entries,
        _sort,
        descending: _descending,
        kindOf: _kind,
      );
      _childCache.clear();
    });
  }

  /// Dragging a separator changes the column on its left; the last one absorbs the difference while
  /// it can, then the table widens (R3.6).
  void _resizeColumn(int index, double dx) {
    _update(() {
      final last = _listWidths.length - 1;
      final before = _listWidths[index];
      final after = math.max(listColumnMin, before + dx);
      final change = after - before;
      _listWidths[index] = after;
      if (index != last) {
        _listWidths[last] = math.max(listColumnMin, _listWidths[last] - change);
      }
    });
  }

  ListColors get _listColors => ListColors.of(
    dark: MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark,
  );

  /// The column header in the veiled band of the glass toolbar (R1.9: the veil continues under
  /// it); it follows the rows when the table scrolls sideways.
  Widget _listHeaderBand() => LayoutBuilder(
    builder: (context, box) {
      final width = math.max(
        listTableWidth(_listWidths) + listInset,
        box.maxWidth,
      );
      return ClipRect(
        child: ListenableBuilder(
          listenable: _listScrollX,
          builder: (context, child) => Transform.translate(
            offset: Offset(
              _listScrollX.hasClients ? -_listScrollX.offset : 0,
              0,
            ),
            child: child,
          ),
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: width,
            maxWidth: width,
            child: ListHeader(
              widths: _listWidths,
              sort: _sort,
              descending: _descending,
              colors: _listColors,
              background: const Color(0x00000000),
              onSort: _sortList,
              onResize: _resizeColumn,
            ),
          ),
        ),
      );
    },
  );

  Widget _listView() {
    if (_error != null) {
      return Padding(
        padding: EdgeInsets.only(top: _topInset),
        child: Center(
          child: Text(
            l10n.cantOpenFolder('$_error'),
            style: text(13, color: secondaryText),
          ),
        ),
      );
    }
    final colors = _listColors;
    final rows = _searching
        ? [for (final e in _entries) (entry: e, depth: 0)]
        : _listRows;
    final now = widget.now ?? DateTime.now();
    return LayoutBuilder(
      builder: (context, box) {
        final table = listTableWidth(_listWidths);
        final scrolls = table + listInset > box.maxWidth;
        final width = scrolls ? table + listInset : box.maxWidth;
        // Alternating rows continue down to the bottom (R3.10).
        // The header is in the toolbar band, inside `_topInset`.
        final fill = ((box.maxHeight - _topInset) / listRowHeight).ceil() + 1;
        final count = math.max(rows.length, fill);
        final content = ColoredBox(
          color: colors.background,
          child: ListView.builder(
            key: const ValueKey('list'),
            padding: EdgeInsets.only(top: _topInset + listFirstRowGap),
            itemExtent: listRowHeight,
            itemCount: count,
            itemBuilder: (context, index) => index < rows.length
                ? _listRow(rows, index, colors, table, now)
                : _emptyListRow(index, colors, table),
          ),
        );
        if (!scrolls) return content;
        return SingleChildScrollView(
          controller: _listScrollX,
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: width, height: box.maxHeight, child: content),
        );
      },
    );
  }

  /// A row after the last one: only the stripe; a click is a click on the background.
  Widget _emptyListRow(int index, ListColors colors, double table) =>
      GestureDetector(
        key: ValueKey('empty row $index'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _update(() {
          _selected.clear();
          _anchor = _cursor = null;
        }),
        onSecondaryTapDown: (d) => _openContextMenu(null, d.globalPosition),
        child: ListRowBackground(index: index, width: table, colors: colors),
      );

  Widget _listRow(
    List<ListRowItem> rows,
    int index,
    ListColors colors,
    double table,
    DateTime now,
  ) {
    final (:entry, :depth) = rows[index];
    bool chosen(int i) =>
        i >= 0 && i < rows.length && _selected.contains(rows[i].entry.path);
    final selected = chosen(index);
    // The rows being dragged turn gray (inactive selection, MU-40).
    final active = _active && _drag == null;
    final pending = _pendingTransfer(entry.path);
    final nameColor = selected
        ? (active ? colors.selectionName : colors.inactiveName)
        : pending != null
        ? colors.secondary
        : colors.name;
    final secondary = selected
        ? (active ? colors.selectionSecondary : colors.inactiveSecondary)
        : colors.secondary;
    final indent = listIndent * depth;
    final nameEnd = listInset + _listWidths[0];
    final tags = _tagsOf(entry);
    // The tag dots at the end of the Name column (R3.4).
    final tagsWidth = tags.isEmpty ? 0.0 : 10 + 5.0 * (tags.length - 1) + 8;
    final nameStyle = listText(13, nameColor);
    final nameRoom =
        nameEnd -
        (listNameLeft + indent) -
        tagsWidth -
        (pending != null ? 20 : 4);
    final cells = <Widget>[];
    var x = nameEnd;
    for (var i = 1; i < listColumns.length; i++) {
      final column = listColumns[i];
      final w = _listWidths[i];
      final value = switch (column.key) {
        SortKey.modified => formatDate(entry.modified, now),
        SortKey.size => formatSize(entry),
        SortKey.kind => _kind(entry),
        SortKey.name => '',
      };
      final style = listText(13, secondary);
      final room = w - listCellLeft - listCellRight;
      cells.add(
        Positioned(
          left: x + listCellLeft,
          width: math.max(0, room),
          top: 0,
          height: listRowHeight,
          child: baselineText(
            column.key == SortKey.kind
                ? middleEllipsis(value, style, room)
                : value,
            style,
            baseline: listRowBaseline,
            align: column.alignRight ? TextAlign.right : TextAlign.left,
          ),
        ),
      );
      x += w;
    }
    final ring = _contextRing == entry.path;
    return _itemPress(
      entry,
      threshold: 1,
      anchor: Offset(listIconLeft + indent, (listRowHeight - listIconSide) / 2),
      _folderTarget(
        entry,
        (context, dropActive) => Listener(
          // The row is chosen on release, if no drag started (MU-25: no change until release). Only
          // the primary button chooses: a right click on an unselected row leaves the selection as
          // it is and gives the ring (R3.9, MU-50); the triangle does not choose the row.
          onPointerDown: (e) {
            _rowDragged = false;
            final onTriangle =
                entry.isDirectory &&
                e.localPosition.dx >= 11 + indent &&
                e.localPosition.dx < listIconLeft + indent;
            _rowDown = e.buttons & kPrimaryButton == 0 || onTriangle
                ? null
                : entry.path;
          },
          onPointerUp: (e) {
            final down = _rowDown;
            _rowDown = null;
            if (down == entry.path && !_rowDragged) _tap(entry);
          },
          onPointerCancel: (_) => _rowDown = null,
          child: GestureDetector(
            key: ValueKey(entry.path),
            onTap: () {},
            onDoubleTap: () => _openEntry(entry),
            onSecondaryTapDown: (d) =>
                _openContextMenu(entry, d.globalPosition),
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ListRowBackground(
                    index: index,
                    width: table,
                    colors: colors,
                    selected: selected,
                    selectedAbove: chosen(index - 1),
                    selectedBelow: chosen(index + 1),
                    active: active,
                    dropTarget: dropActive,
                    ring: ring,
                  ),
                ),
                if (entry.isDirectory && !_searching)
                  Positioned(
                    // The triangle hit area: 15 × 20 from x 11 (AX 15 × 22).
                    left: 11 + indent,
                    width: 15,
                    top: 0,
                    height: listRowHeight,
                    // The triangle opens on release (MU-25), with ⌥ read at press time; a double
                    // click here does not open the folder.
                    child: Listener(
                      key: ValueKey('triangle ${entry.path}'),
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (e) {
                        _triangleDown = e.buttons == kPrimaryButton
                            ? (
                                entry.path,
                                HardwareKeyboard.instance.isAltPressed,
                              )
                            : null;
                      },
                      onPointerUp: (e) {
                        final down = _triangleDown;
                        _triangleDown = null;
                        if (down == null || down.$1 != entry.path) return;
                        _toggleExpanded(entry, subtree: down.$2);
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {},
                        onDoubleTap: () {},
                        child: Stack(
                          children: [
                            // › 5 × 8 at x 17–21, ⌄ 8 × 5 centered on the same point.
                            Positioned(
                              left: _expanded.contains(entry.path)
                                  ? listTriangleLeft - 11 - 1.5
                                  : listTriangleLeft - 11,
                              top: _expanded.contains(entry.path) ? 7.5 : 6,
                              child: ListTriangle(
                                open: _expanded.contains(entry.path),
                                color: selected && active
                                    ? colors.selectionName
                                    : colors.triangle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: listIconLeft + indent,
                  top: (listRowHeight - listIconSide) / 2,
                  width: listIconSide,
                  height: listIconSide,
                  child: EntryIcon(
                    entry: entry,
                    side: listIconSide,
                    env: widget.iconsEnv,
                  ),
                ),
                Positioned(
                  left: listNameLeft + indent,
                  width: math.max(0, nameRoom),
                  top: 0,
                  height: listRowHeight,
                  child: entry.path == _renaming
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: _renameField(entry, maxWidth: nameRoom),
                        )
                      : Baseline(
                          baseline: listRowBaseline,
                          baselineType: TextBaseline.alphabetic,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            heightFactor: 1,
                            // A press on the name itself may be a slow click (R8).
                            child: Listener(
                              onPointerDown: (_) => _namePress(entry),
                              child: Text(
                                middleEllipsis(entry.name, nameStyle, nameRoom),
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.clip,
                                style: nameStyle,
                              ),
                            ),
                          ),
                        ),
                ),
                if (pending != null)
                  Positioned(
                    left: listNameLeft + indent + nameRoom + 4,
                    top: (listRowHeight - pieSide) / 2,
                    child: ProgressPie(pending.fraction),
                  ),
                if (tags.isNotEmpty)
                  Positioned(
                    left: nameEnd - 7 - (tagsWidth - 8),
                    top: 5,
                    child: TagDots(
                      tags: tags,
                      background: selected
                          ? (active
                                ? colors.selection
                                : colors.inactiveSelection)
                          : index.isOdd
                          ? colors.stripe
                          : colors.background,
                    ),
                  ),
                ...cells,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
