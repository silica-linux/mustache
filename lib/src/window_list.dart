// La vista a elenco nella finestra (MU-20, mustache-spec 3; geometria e colori in
// list_view.dart): intestazione che ordina e ridimensiona, righe con triangolo, icona e celle,
// cartelle aperte nel posto (rientro di 15 pt per livello), righe alternate fino in fondo anche
// a cartella vuota, selezione a blocchi. Le righe vuote dopo l'ultima sono fondo: un clic toglie
// la selezione, il clic destro apre il menu della cartella.

part of 'window.dart';

/// Una riga dell'elenco: l'elemento e il suo livello (0 per il contenuto della cartella).
typedef ListRowItem = ({Entry entry, int depth});

extension _ListView on _MustacheWindowState {
  /// Le righe in ordine: il contenuto con le cartelle aperte espanse (solo nell'elenco, non
  /// nei risultati della ricerca).
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

  /// L'ordine in cui si muovono le frecce e ⇧clic: nell'elenco anche le figlie aperte.
  List<Entry> get _ordered => _view == ViewMode.list && !_searching
      ? [for (final row in _listRows) row.entry]
      : _entries;

  List<Entry> _childrenOf(String path) => _childCache[path] ??= sortEntries(
    listDirectory(path, showHidden: _showHidden).entries,
    _sort,
    descending: _descending,
    kindOf: _kind,
  );

  /// Apre o chiude una cartella nel posto; con ⌥ tutto il sottoalbero (R3.7).
  void _toggleExpanded(Entry entry, {bool subtree = false}) {
    final open = !_expanded.contains(entry.path);
    _update(() {
      if (!subtree) {
        open ? _expanded.add(entry.path) : _expanded.remove(entry.path);
        return;
      }
      // Il sottoalbero, al più 2000 cartelle (una cartella enorme non blocca la finestra).
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

  /// → e ← nell'elenco: aprono e chiudono la cartella del cursore (R3.7).
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

  /// Clic su un'intestazione: una colonna nuova parte da crescente (Data e Dimensioni da
  /// decrescente), la stessa si inverte (R3.5).
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

  /// Trascinando un separatore cambia la colonna a sinistra; l'ultima assorbe la differenza
  /// finché può, poi la tabella si allarga (R3.6).
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

  Widget _listView() {
    if (_error != null) {
      return Center(
        child: Text(
          'Non si può aprire: $_error',
          style: text(13, color: secondaryText),
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
        // Le righe alternate continuano fino in fondo (R3.10).
        final fill =
            ((box.maxHeight - listHeaderHeight - listHeaderLine) /
                    listRowHeight)
                .ceil() +
            1;
        final count = math.max(rows.length, fill);
        final content = ColoredBox(
          color: colors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListHeader(
                widths: _listWidths,
                sort: _sort,
                descending: _descending,
                colors: colors,
                onSort: _sortList,
                onResize: _resizeColumn,
              ),
              Expanded(
                child: ListView.builder(
                  key: const ValueKey('elenco'),
                  padding: const EdgeInsets.only(top: listFirstRowGap),
                  itemExtent: listRowHeight,
                  itemCount: count,
                  itemBuilder: (context, index) => index < rows.length
                      ? _listRow(rows, index, colors, table, now)
                      : _emptyListRow(index, colors, table),
                ),
              ),
            ],
          ),
        );
        if (!scrolls) return content;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: width, height: box.maxHeight, child: content),
        );
      },
    );
  }

  /// Una riga dopo l'ultima: solo la striscia; un clic è un clic sul fondo.
  Widget _emptyListRow(int index, ListColors colors, double table) =>
      GestureDetector(
        key: ValueKey('riga vuota $index'),
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
    final active = _active;
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
    // I punti delle etichette in fondo alla colonna Nome (R3.4).
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
    return _draggable(
      entry,
      _folderTarget(
        entry,
        (context, dropActive) => Listener(
          // La riga si sceglie al rilascio, se non è partito un trascinamento (MU-25:
          // nessun cambiamento fino al rilascio). Solo il pulsante primario sceglie: il
          // clic destro su una riga non scelta lascia la selezione com'è e dà l'anello
          // (R3.9, MU-50); il triangolo non sceglie la riga.
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
                    // La presa del triangolo: 15 × 20 da x 11 (AX 15 × 22).
                    left: 11 + indent,
                    width: 15,
                    top: 0,
                    height: listRowHeight,
                    // Il triangolo apre al rilascio (MU-25), con ⌥ letto alla pressione; il
                    // doppio clic qui non apre la cartella.
                    child: Listener(
                      key: ValueKey('triangolo ${entry.path}'),
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
                            // › 5 × 8 a x 17–21, ⌄ 8 × 5 centrato nello stesso punto.
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
                      : baselineText(
                          middleEllipsis(entry.name, nameStyle, nameRoom),
                          nameStyle,
                          baseline: listRowBaseline,
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
