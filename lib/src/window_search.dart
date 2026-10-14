// Search (⌘F, MU-70, mustache-spec 13): the field in the toolbar, the scope bar below ("Cerca in:"
// This computer / the folder), the results in the list titled "Ricerca in …". Without tokens it
// searches name and content (R13.2): the name right away, the content only of small text files. Esc
// clears the field but stays in search (R13.4); Back leaves.

part of 'window.dart';

/// How many items a search examines at most, and the largest file read for its content.
const int searchScanLimit = 200000;
const int searchContentLimit = 256 * 1024;

/// After the last letter, how long to wait before searching (first results at ~600 ms).
const Duration searchDebounce = Duration(milliseconds: 250);

enum SearchScope { computer, folder }

extension _Search on _MustacheWindowState {
  void _startSearch() => _update(() {
    _searching = true;
    _searchFolder = _history.current;
    _searchFocus.requestFocus();
  });

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

  bool get _dark =>
      MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark;

  /// The search field in the toolbar: 242 × 38 with the focus ring (spec 13); in dark background
  /// `#4b4b4b` and ring `#3a6996` (mu70-empty-dark).
  Widget _searchField() => Container(
    key: const ValueKey('search field'),
    width: 242,
    height: toolbarCapsuleHeight,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: _dark ? const Color(0xFF4B4B4B) : const Color(0xFFF2F2F7),
      borderRadius: BorderRadius.circular(toolbarCapsuleHeight / 2),
      border: Border.all(
        color: _dark ? const Color(0xFF3A6996) : const Color(0xFF8FB4FB),
        width: 2,
      ),
    ),
    alignment: Alignment.centerLeft,
    child: Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _clearSearchField();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: DefaultTextEditingShortcuts(
        child: EditableText(
          controller: _searchQuery,
          focusNode: _searchFocus,
          style: text(13, color: WindowColors.of(context).text),
          cursorColor: WindowColors.of(context).text,
          backgroundCursorColor: WindowColors.of(context).text,
          selectionColor: const Color(0xFFB3D7FF),
          maxLines: 1,
          onChanged: (_) => _queryChanged(),
        ),
      ),
    ),
  );

  /// The scope bar: 32 pt, "Cerca in:" and the two 22 pt capsules; the chosen one on a gray
  /// background with dark text, the other in gray (mu70-empty: light `#222222` / `#808080`, dark
  /// `#e3e3e3` / `#a1a1a1` on `#494949`; the bar `#2f2f2f`).
  Widget _scopeBar() {
    final dark = _dark;
    final minor = dark ? const Color(0xFFA1A1A1) : secondaryText;
    Widget capsule(String label, SearchScope scope) {
      final chosen = _searchScope == scope;
      return GestureDetector(
        key: ValueKey('scope $label'),
        onTap: () {
          _update(() => _searchScope = scope);
          _runSearch();
        },
        child: Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          margin: const EdgeInsets.only(right: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: chosen
                ? (dark ? const Color(0xFF494949) : const Color(0xFFDFDFDF))
                : null,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            style: text(
              12,
              color: !chosen
                  ? minor
                  : dark
                  ? const Color(0xFFE3E3E3)
                  : const Color(0xFF222222),
            ),
          ),
        ),
      );
    }

    return Container(
      key: const ValueKey('scope bar'),
      height: 32,
      color: _listColors.header,
      child: Row(
        children: [
          const SizedBox(width: 14),
          Text(l10n.searchIn, style: text(12, color: minor)),
          const SizedBox(width: 8),
          capsule(l10n.thisComputer, SearchScope.computer),
          capsule(l10n.quoted(displayName(_searchFolder)), SearchScope.folder),
        ],
      ),
    );
  }
}
