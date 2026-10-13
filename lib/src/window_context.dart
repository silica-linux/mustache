// I menu contestuali (MU-50, mustache-spec 10.1) e l'apertura con le app (R10.1): Apri, Apri con
// (la predefinita in cima, poi le altre in ordine di nome), Sposta nel Cestino, Rinomina,
// Duplica; nel vuoto Nuova cartella, Vista e Ordina per. Le voci di funzioni non ancora fatte
// restano visibili e disattivate, per la struttura.

part of 'window.dart';

/// Il menu si apre con l'angolo in alto a sinistra sul puntatore (+1, −6) (spec 10.1).
const Offset contextMenuOffset = Offset(1, -6);

extension _Context on _MustacheWindowState {
  AppRegistry get _registry =>
      _apps ??= AppRegistry.load(env: widget.iconsEnv, mime: systemMime);

  /// Il tipo MIME di un elemento, calcolato una volta per percorso e data.
  String _typeOf(Entry entry) {
    if (entry.isDirectory) return 'inode/directory';
    final key = '${entry.path}\u0000${entry.modified.microsecondsSinceEpoch}';
    return _types[key] ??= systemMime.typeOf(entry.path);
  }

  /// La colonna Tipo: la descrizione di shared-mime-info, o quella per estensione.
  String _kind(Entry entry) {
    if (entry.isDirectory) return 'Cartella';
    return mimeComment(_typeOf(entry), env: widget.iconsEnv) ??
        kindLabel(entry);
  }

  /// Apre dei file con un'app (o la predefinita del primo), con un avviso se non si può.
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
      // Nessuna app dichiara il tipo: il resto lo decide il sistema.
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
    if (entry != null && !_selected.contains(entry.path)) {
      _update(() => _select([entry.path]));
    }
    final items = entry == null ? const <Entry>[] : _selection;
    _update(() {
      _menuAt = position + contextMenuOffset;
      _menuEntries = items.isEmpty ? _backgroundMenu() : _itemsMenu(items);
    });
  }

  void _closeContextMenu() {
    _update(() {
      _menuAt = null;
      _menuEntries = const [];
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
        onSelected: _moveToTrash,
      ),
      const MenuDivider(),
      const MenuAction('Ottieni informazioni', enabled: false),
      MenuAction(
        items.length > 1 ? 'Rinomina…' : 'Rinomina',
        enabled: single != null,
        onSelected: single == null ? null : () => _startRename(single.path),
      ),
      MenuAction('Duplica', onSelected: _duplicate),
      const MenuAction('Copia', enabled: false),
    ];
  }

  /// "Apri con ›": la predefinita in cima con "(predefinita)", poi le altre in ordine di nome,
  /// poi "Altro…" (R10.1).
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
    const MenuDivider(),
    const MenuAction('Ottieni informazioni', enabled: false),
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
              _entries = sortEntries(_entries, _sort);
            }),
          ),
      ],
    ),
  ];
}
