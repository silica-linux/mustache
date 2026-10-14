// Context menus (MU-50, mustache-spec 10.1) and opening with apps (R10.1): Open, Open With (the
// default on top, then the others by name), Move to Trash, Rename, Duplicate; on the background New
// Folder, View and Sort By. Entries for features not done yet stay visible and disabled, for the
// structure.

part of 'window.dart';

/// The menu opens with its top-left corner at the pointer (+1, −6) (spec 10.1).
const Offset contextMenuOffset = Offset(1, -6);

extension _Context on _MustacheWindowState {
  AppRegistry get _registry =>
      _apps ??= AppRegistry.load(env: widget.iconsEnv, mime: systemMime);

  /// The MIME type of an item, computed once per path and date.
  String _typeOf(Entry entry) {
    if (entry.isDirectory) return 'inode/directory';
    final key = '${entry.path}\u0000${entry.modified.microsecondsSinceEpoch}';
    return _types[key] ??= systemMime.typeOf(entry.path);
  }

  /// The Kind column: the name of the type's family (R3.3).
  String _kind(Entry entry) => kindLabel(entry, _typeOf(entry));

  /// Opens files with an app (or the default one of the first), with an alert when it cannot.
  Future<void> _openWith(List<Entry> files, [DesktopApp? app]) async {
    if (files.isEmpty) return;
    final custom = widget.open;
    if (custom != null && app == null) {
      for (final f in files) {
        custom(f.path);
      }
      return;
    }
    final chosen = app ?? _registry.defaultFor(_typeOf(files.first));
    if (chosen == null) {
      // No app declares the type: the system decides the rest.
      for (final f in files) {
        _MustacheWindowState._xdgOpen(f.path);
      }
      return;
    }
    final error = await launchApp(chosen, [for (final f in files) f.path]);
    if (error != null && mounted) _showError(error);
  }

  void _openContextMenu(Entry? entry, Offset position) {
    _slowClick?.cancel();
    // In the list a right click on an unselected row does not change the selection: the row gets
    // the ring and the menu applies to it alone (R3.9).
    final ring =
        entry != null &&
        !_selected.contains(entry.path) &&
        _view == ViewMode.list;
    if (entry != null && !_selected.contains(entry.path) && !ring) {
      _update(() => _select([entry.path]));
    }
    final items = entry == null
        ? const <Entry>[]
        : ring
        ? [entry]
        : _selection;
    _contextRing = ring ? entry.path : null;
    _update(() {
      _menuAt = position + contextMenuOffset;
      _menuEntries = items.isEmpty ? _backgroundMenu() : _itemsMenu(items);
    });
  }

  /// Opens the Get Info windows (at most 5).
  void _openInfo(List<String> paths) => _update(() {
    for (final p in paths.take(5)) {
      if (!_infos.contains(p)) _infos.add(p);
    }
  });

  void _closeContextMenu() {
    _update(() {
      _menuAt = null;
      _menuEntries = const [];
      _contextRing = null;
    });
    _focus.requestFocus();
  }

  List<MenuEntry> _itemsMenu(List<Entry> items) {
    final inTrash = _trash.contains(_history.current);
    final files = [
      for (final e in items)
        if (!e.isDirectory) e,
    ];
    final single = items.length == 1 ? items.first : null;
    return [
      if (items.length > 1)
        MenuAction(
          'Nuova cartella con selezione (${items.length} elementi)',
          enabled: false,
        ),
      MenuAction(
        'Apri',
        onSelected: () {
          if (single != null && single.isDirectory) {
            _openEntry(single);
          } else {
            _openWith(files);
          }
        },
      ),
      if (files.length == items.length) _openWithMenu(files),
      const MenuDivider(),
      MenuAction(
        inTrash ? 'Ripristina' : 'Sposta nel Cestino',
        onSelected: () => _moveToTrash(items),
      ),
      const MenuDivider(),
      MenuAction(
        'Ottieni informazioni',
        onSelected: () => _openInfo([for (final e in items) e.path]),
      ),
      MenuAction(
        items.length > 1 ? 'Rinomina…' : 'Rinomina',
        enabled: single != null,
        onSelected: single == null ? null : () => _startRename(single.path),
      ),
      MenuAction('Duplica', onSelected: () => _duplicate(items)),
      MenuAction('Copia', onSelected: () => _copySelection(items)),
      const MenuDivider(),
      _tagMenuRow(items),
      const MenuAction('Tag…', enabled: false),
    ];
  }

  /// "Open With ›": the default on top with "(default)", then the others by name, then "Other…"
  /// (R10.1).
  MenuAction _openWithMenu(List<Entry> files) {
    final type = _typeOf(files.first);
    final preferred = _registry.defaultFor(type);
    final others = [
      for (final app in _registry.appsFor(type))
        if (app.id != preferred?.id) app,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return MenuAction(
      'Apri con',
      submenu: [
        if (preferred != null)
          MenuAction(
            '${preferred.name} (predefinita)',
            onSelected: () => _openWith(files, preferred),
          ),
        if (preferred != null && others.isNotEmpty) const MenuDivider(),
        for (final app in others)
          MenuAction(app.name, onSelected: () => _openWith(files, app)),
        const MenuDivider(),
        const MenuAction('Altro…', enabled: false),
      ],
    );
  }

  List<MenuEntry> _backgroundMenu() => [
    MenuAction('Nuova cartella', onSelected: _newFolder),
    MenuAction(
      FileClipboard.paths.length > 1
          ? 'Incolla ${FileClipboard.paths.length} elementi'
          : 'Incolla elemento',
      enabled: FileClipboard.paths.isNotEmpty,
      onSelected: () => _paste(move: false),
    ),
    const MenuDivider(),
    MenuAction(
      'Ottieni informazioni',
      onSelected: () => _openInfo([_history.current]),
    ),
    const MenuDivider(),
    MenuAction(
      'Vista',
      submenu: [
        MenuAction(
          'Come icone',
          checked: _view == ViewMode.icons,
          onSelected: () => _setView(ViewMode.icons),
        ),
        MenuAction(
          'Come elenco',
          checked: _view == ViewMode.list,
          onSelected: () => _setView(ViewMode.list),
        ),
        MenuAction(
          'Come colonne',
          checked: _view == ViewMode.columns,
          onSelected: () => _setView(ViewMode.columns),
        ),
        MenuAction(
          'Come galleria',
          checked: _view == ViewMode.gallery,
          onSelected: () => _setView(ViewMode.gallery),
        ),
      ],
    ),
    MenuAction(
      'Ordina per',
      submenu: [
        for (final (key, label) in const [
          (SortKey.name, 'Nome'),
          (SortKey.kind, 'Tipo'),
          (SortKey.modified, 'Data di modifica'),
          (SortKey.size, 'Dimensione'),
        ])
          MenuAction(
            label,
            checked: _sort == key,
            onSelected: () => _update(() {
              _sort = key;
              _descending = false;
              _entries = sortEntries(_entries, _sort, kindOf: _kind);
            }),
          ),
      ],
    ),
  ];
}
