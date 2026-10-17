// The sheets of the window: Go to Folder (⇧⌘G) and Save Search, and the saved searches (a
// `.search` file, a row in the sidebar). A sheet hangs under the toolbar over a veil; Esc, a
// click on the veil and the sheet's own buttons close it.

part of 'window.dart';

extension _Sheets on _MustacheWindowState {
  String get _home =>
      widget.places.where((p) => p.kind == PlaceKind.home).firstOrNull?.path ??
      Platform.environment['HOME'] ??
      '/';

  void _closeSheet() {
    if (_sheet == null) return;
    _update(() => _sheet = null);
    _focus.requestFocus();
  }

  // Go to Folder ------------------------------------------------------------------------------

  /// Go › Go to Folder… (⇧⌘G, kit `Go To Folder Sheet`: 102 pt below the window's top).
  void _openGoToFolder() {
    if (_modalOpen) return;
    _update(() {
      _sheetCentered = false;
      _sheet = GoToFolderSheet(
        key: const ValueKey('go to folder'),
        home: _home,
        cwd: _history.current,
        onGo: _goToPath,
        onClose: _closeSheet,
      );
    });
  }

  /// Goes to a typed or chosen path: a folder opens, a file's folder opens with it selected.
  void _goToPath(String path) {
    _closeSheet();
    if (FileSystemEntity.isDirectorySync(path)) {
      _navigate(path);
    } else if (File(path).existsSync()) {
      _navigate(parentOf(path) ?? '/');
      _update(() => _select([path]));
    }
  }

  // Saved searches ------------------------------------------------------------------------------

  /// The saved searches added to the sidebar that still exist.
  List<Place> get _savedPlaces => [
    for (final path in widget.settings?.savedSearches ?? const <String>[])
      if (File(path).existsSync())
        Place(
          displayName(path).replaceFirst(RegExp(r'\.search$'), ''),
          '$searchPathPrefix$path',
          PlaceKind.search,
        ),
  ];

  /// A saved search is on screen and unchanged: its sidebar row is selected.
  bool get _savedViewShown =>
      _savedView != null && _searching && _searchQuery.text == _savedQuery;

  /// Runs the search of the `.search` file at [path] (sidebar row, double click).
  void _openSavedSearch(String path) {
    final search = SavedSearch.read(path);
    if (search == null) {
      _showError(l10n.savedSearchDamaged(displayName(path)));
      return;
    }
    _tagView = null;
    _searchTimer?.cancel();
    _update(() {
      _searching = true;
      _searchScope = search.everywhere || search.folder == null
          ? SearchScope.computer
          : SearchScope.folder;
      if (search.folder != null) _searchFolder = search.folder!;
      _searchQuery.text = search.query;
      _savedView = path;
      _savedQuery = search.query;
    });
    _runSearch();
  }

  String _defaultSearchName() {
    final query = _searchQuery.text.trim();
    return _searchScope == SearchScope.folder
        ? l10n.savedSearchNameInFolder(displayName(_searchFolder), query)
        : l10n.savedSearchNameEverywhere(query);
  }

  /// The folders the Save Search pop-up offers: Saved Searches (the default), the Desktop, the
  /// Documents and the home folder.
  List<(String, String)> _saveFolders() {
    final home = _home;
    String? place(PlaceKind kind) =>
        widget.places.where((p) => p.kind == kind).firstOrNull?.path;
    return [
      (l10n.savedSearchesFolder, savedSearchesDir(home)),
      for (final kind in [PlaceKind.desktop, PlaceKind.documents])
        if (place(kind) case final path? when Directory(path).existsSync())
          (displayName(path), path),
      (displayName(home), home),
    ];
  }

  /// The Save button of the scope bar (kit `Save Search Sheet`: 413 × 263, centred).
  void _openSaveSearch() {
    if (_modalOpen || _searchQuery.text.trim().isEmpty) return;
    _update(() {
      _sheetCentered = true;
      _sheet = SaveSearchSheet(
        key: const ValueKey('save search'),
        initialName: _defaultSearchName(),
        folders: _saveFolders(),
        onSave: _saveSearch,
        onCancel: _closeSheet,
      );
    });
  }

  void _saveSearch(SaveSearchResult result) {
    final search = SavedSearch(
      query: _searchQuery.text.trim(),
      everywhere: _searchScope == SearchScope.computer,
      folder: _searchScope == SearchScope.folder ? _searchFolder : null,
    );
    final path = writeSavedSearch(result.folder, result.name, search);
    _closeSheet();
    if (path == null) {
      _showError(l10n.saveSearchError);
      return;
    }
    if (result.tags.isNotEmpty) writeTags(path, result.tags);
    final settings = widget.settings;
    if (result.addToSidebar && settings != null) {
      settings.savedSearches = [...settings.savedSearches, path];
    }
    _update(() {
      _savedView = path;
      _savedQuery = _searchQuery.text;
    });
  }
}
