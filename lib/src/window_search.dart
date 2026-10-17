// Search (⌘F, MU-70, docs/spec/search.md): the field in the toolbar, the scope bar below (search in
// this computer or the folder), the results in the list titled after the search. Without tokens
// it searches name and content (R13.2): the name right away, the content only of small text files. Esc
// clears the field but stays in search (R13.4); Back leaves.

part of 'window.dart';

/// How many items a search examines at most, and the largest file read for its content.
/// The scope bar below the toolbar while searching.
const double scopeBarHeight = 32;

const int searchScanLimit = 200000;
const int searchContentLimit = 256 * 1024;

/// After the last letter, how long to wait before searching (first results at ~600 ms).
const Duration searchDebounce = Duration(milliseconds: 250);

enum SearchScope { computer, folder }

extension _Search on _MustacheWindowState {
  void _startSearch() {
    _enterSearch();
    _searchFocus.requestFocus();
  }

  /// Esc in the field: it is cleared, but the window stays in search (R13.4).
  void _clearSearchField() {
    _searchQuery.clear();
    _searchToken++;
    _update(() => _entries = const []);
    _focus.requestFocus();
  }

  void _endSearch() {
    _searchToken++;
    _searchQuery.clear();
    _update(() => _searching = false);
    _load();
  }

  void _queryChanged() {
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDebounce, _runSearch);
  }

  String get _searchRoot => _searchScope == SearchScope.computer
      ? (widget.places
                .where((p) => p.kind == PlaceKind.home)
                .firstOrNull
                ?.path ??
            '/')
      : _searchFolder;

  Future<void> _runSearch() async {
    final query = _searchQuery.text.trim().toLowerCase();
    final token = ++_searchToken;
    if (query.isEmpty) {
      _update(() => _entries = const []);
      return;
    }
    final root = _searchRoot;
    final byName = <Entry>[];
    final byContent = <Entry>[];
    var seen = 0;
    void show() => _update(() => _entries = [...byName, ...byContent]);
    _update(() {
      _entries = const [];
      _selected.clear();
    });
    try {
      await for (final item in Directory(
        root,
      ).list(recursive: true, followLinks: false)) {
        if (token != _searchToken || !mounted) return;
        if (++seen > searchScanLimit) break;
        final relative = item.path.substring(root.length);
        if (relative.contains('/.')) continue;
        final name = displayName(item.path);
        if (name.toLowerCase().contains(query)) {
          final entry = entryAt(item.path);
          if (entry != null) {
            byName.add(entry);
            if (byName.length % 20 == 1) show();
          }
          continue;
        }
        // Content: only small text files, read whole.
        if (item is File && isTextPreview(name)) {
          try {
            if (item.lengthSync() > searchContentLimit) continue;
            final text = await item.readAsString();
            if (token != _searchToken) return;
            if (text.toLowerCase().contains(query)) {
              final entry = entryAt(item.path);
              if (entry != null) byContent.add(entry);
            }
          } on FileSystemException {
            continue;
          } on FormatException {
            continue;
          }
        }
      }
    } on FileSystemException {
      // An unreadable folder stops the pass: what was found stays.
    }
    if (token == _searchToken && mounted) show();
  }

  /// Search starts when the field takes the focus or ⌘F is pressed: the scope bar and the results
  /// replace the folder's view.
  void _enterSearch() {
    if (_searching) return;
    _update(() {
      _searching = true;
      _searchFolder = _history.current;
    });
  }

  /// The search field in the toolbar (kit `Piece/Search`, a 36 pt toolbar field); Esc clears it but stays in
  /// search (R13.4).
  Widget _searchField(double width) => Focus(
    key: const ValueKey('search field'),
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (focused) {
      if (focused) _enterSearch();
    },
    child: AmalfiSearchField(
      controller: _searchQuery,
      focusNode: _searchFocus,
      size: AmalfiFieldSize.toolbar,
      width: width,
      placeholder: l10n.searchPlaceholder,
      onChanged: (_) {
        _enterSearch();
        _queryChanged();
      },
      onCleared: _clearSearchField,
    ),
  );

  /// The scope bar (kit `Scope Bar`): 32 tall, a "search in" label and the two scopes, the chosen
  /// one on a sunken capsule, a 1 pt separator below. The Save button keeps the search (window_sheets.dart).
  Widget _scopeBar() {
    final colors = AmalfiTheme.of(context).colors;
    Widget capsule(String label, SearchScope scope) {
      final chosen = _searchScope == scope;
      return GestureDetector(
        key: ValueKey('scope $label'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _update(() => _searchScope = scope);
          _runSearch();
        },
        child: Center(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: chosen ? colors.surfaceSunken : null,
              shape: AmalfiSmoothBorder(radius: 12),
            ),
            child: SizedBox(
              height: 24,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: AmalfiType.callout(
                      color: chosen ? colors.textPrimary : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      key: const ValueKey('scope bar'),
      height: scopeBarHeight,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              spacing: 8,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    l10n.searchIn,
                    style: AmalfiType.callout(color: colors.textSecondary),
                  ),
                ),
                capsule(l10n.thisComputer, SearchScope.computer),
                capsule(
                  l10n.quoted(displayName(_searchFolder)),
                  SearchScope.folder,
                ),
              ],
            ),
          ),
          // The kit's Save button (`Buttons/Push/Secondary/Small`) at the end of the bar.
          Positioned(
            right: 8,
            top: 0,
            bottom: 1,
            child: Center(
              child: ListenableBuilder(
                listenable: _searchQuery,
                builder: (context, _) => AmalfiPushButton(
                  key: const ValueKey('save search button'),
                  label: l10n.saveSearchButton,
                  size: AmalfiControlSize.small,
                  onPressed: _searchQuery.text.trim().isEmpty
                      ? null
                      : _openSaveSearch,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 1,
            child: ColoredBox(color: colors.lineSeparator),
          ),
        ],
      ),
    );
  }
}
