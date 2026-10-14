// Context menus (MU-50, docs/spec/menus-and-settings.md) and opening with apps (R10.1): Open, Open With (the
// default on top, then the others by name), Move to Trash, Rename, Duplicate; on the background New
// Folder, View and Sort By. Entries for features not done yet stay visible and disabled, for the
// structure.

part of 'window.dart';

/// The menu opens with its top-left corner at the pointer (+1, −6) (spec/menus-and-settings.md).
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
        MenuAction(l10n.newFolderWithSelection(items.length), enabled: false),
      MenuAction(
        l10n.open,
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
        inTrash ? l10n.restore : l10n.moveToTrash,
        onSelected: () => _moveToTrash(items),
      ),
      const MenuDivider(),
      MenuAction(
        l10n.showInfo,
        onSelected: () => _openInfo([for (final e in items) e.path]),
      ),
      MenuAction(
        items.length > 1 ? l10n.renameMany : l10n.rename,
        enabled: single != null,
        onSelected: single == null ? null : () => _startRename(single.path),
      ),
      MenuAction(l10n.duplicate, onSelected: () => _duplicate(items)),
      MenuAction(l10n.copy, onSelected: () => _copySelection(items)),
      const MenuDivider(),
      _tagMenuRow(items),
      if (single != null && single.isDirectory)
        MenuAction(
          l10n.customizeFolder,
          onSelected: () => _customizeFolder(single.path),
        )
      else
        MenuAction(l10n.tagsMenu, enabled: false),
    ];
  }

  /// Customize Folder…: Get Info with its Customize Folder section open.
  void _customizeFolder(String path) {
    _update(() => _infoOpen.add(InfoSection.customize));
    widget.settings?.infoSections = [for (final s in _infoOpen) s.name];
    _openInfo([path]);
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
      l10n.openWith,
      submenu: [
        if (preferred != null)
          MenuAction(
            l10n.defaultApp(preferred.name),
            onSelected: () => _openWith(files, preferred),
          ),
        if (preferred != null && others.isNotEmpty) const MenuDivider(),
        for (final app in others)
          MenuAction(app.name, onSelected: () => _openWith(files, app)),
        const MenuDivider(),
        MenuAction(l10n.otherApp, enabled: false),
      ],
    );
  }

  List<MenuEntry> _backgroundMenu() => [
    MenuAction(l10n.newFolder, onSelected: _newFolder),
    MenuAction(
      l10n.pasteItems(FileClipboard.paths.length),
      enabled: FileClipboard.paths.isNotEmpty,
      onSelected: () => _paste(move: false),
    ),
    const MenuDivider(),
    MenuAction(l10n.showInfo, onSelected: () => _openInfo([_history.current])),
    const MenuDivider(),
    MenuAction(
      l10n.view,
      submenu: [
        MenuAction(
          l10n.viewIcons,
          checked: _view == ViewMode.icons,
          onSelected: () => _setView(ViewMode.icons),
        ),
        MenuAction(
          l10n.viewList,
          checked: _view == ViewMode.list,
          onSelected: () => _setView(ViewMode.list),
        ),
        MenuAction(
          l10n.viewColumns,
          checked: _view == ViewMode.columns,
          onSelected: () => _setView(ViewMode.columns),
        ),
        MenuAction(
          l10n.viewGallery,
          checked: _view == ViewMode.gallery,
          onSelected: () => _setView(ViewMode.gallery),
        ),
      ],
    ),
    MenuAction(
      l10n.sortBy,
      submenu: [
        // In the icon view also "None" (free positions) and Snap to Grid.
        if (_view == ViewMode.icons) ...[
          MenuAction(
            l10n.sortNone,
            checked: _arrangement.free,
            onSelected: _sortNone,
          ),
          MenuAction(
            l10n.snapToGrid,
            checked: _arrangement.snap,
            onSelected: _toggleSnap,
          ),
          const MenuDivider(),
        ],
        for (final (key, label) in _sortChoices)
          MenuAction(
            label,
            checked:
                _sort == key && !(_view == ViewMode.icons && _arrangement.free),
            onSelected: () => _sortBy(key),
          ),
      ],
    ),
    // Clean Up works on free positions; Clean Up By also turns a sorted folder into a free one.
    if (_view == ViewMode.icons) ...[
      const MenuDivider(),
      MenuAction(
        l10n.cleanUp,
        enabled: _arrangement.free,
        onSelected: _cleanUp,
      ),
      MenuAction(
        l10n.cleanUpSelection,
        enabled: _arrangement.free && _selected.isNotEmpty,
        onSelected: () => _cleanUp(selection: true),
      ),
      MenuAction(
        l10n.cleanUpBy,
        submenu: [
          for (final (key, label) in _sortChoices)
            MenuAction(
              label,
              shortcut: '⌥⌘${arrangeByDigit[key]}',
              onSelected: () => _arrangeBy(key),
            ),
        ],
      ),
    ],
  ];

  List<(SortKey, String)> get _sortChoices => [
    (SortKey.name, l10n.sortName),
    (SortKey.kind, l10n.sortKind),
    (SortKey.modified, l10n.sortModified),
    (SortKey.size, l10n.sortSize),
  ];
}
