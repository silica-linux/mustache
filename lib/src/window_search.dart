// La ricerca (⌘F, MU-70, mustache-spec 13): il campo nella barra, la barra dell'ambito sotto
// ("Cerca in:" Questo computer / la cartella), i risultati nell'elenco con il titolo "Ricerca in
// …". Senza gettoni si cerca nel nome e nel contenuto (R13.2): il nome subito, il contenuto solo
// dei file di testo piccoli. Esc svuota il campo ma resta in ricerca (R13.4); Indietro esce.

part of 'window.dart';

/// Quanti elementi esamina al più una ricerca, e il più grande file letto per il contenuto.
const int searchScanLimit = 200000;
const int searchContentLimit = 256 * 1024;

/// Dopo l'ultima lettera, quanto si aspetta prima di cercare (i primi risultati a ~600 ms).
const Duration searchDebounce = Duration(milliseconds: 250);

enum SearchScope { computer, folder }

extension _Search on _MustacheWindowState {
  void _startSearch() => _update(() {
    _searching = true;
    _searchFolder = _history.current;
    _searchFocus.requestFocus();
  });

  /// Esc nel campo: si svuota, ma la finestra resta in ricerca (R13.4).
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
        // Il contenuto: solo testo piccolo, letto per intero.
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
      // Una cartella illeggibile ferma il giro: resta quel che si è trovato.
    }
    if (token == _searchToken && mounted) show();
  }

  /// Il campo della ricerca nella barra: 242 × 38 con l'anello di focus (spec 13).
  Widget _searchField() => Container(
    key: const ValueKey('campo di ricerca'),
    width: 242,
    height: toolbarCapsuleHeight,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F2F7),
      borderRadius: BorderRadius.circular(toolbarCapsuleHeight / 2),
      border: Border.all(color: const Color(0xFF8FB4FB), width: 2),
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
          style: text(13),
          cursorColor: textColor,
          backgroundCursorColor: textColor,
          selectionColor: const Color(0xFFB3D7FF),
          maxLines: 1,
          onChanged: (_) => _queryChanged(),
        ),
      ),
    ),
  );

  /// La barra dell'ambito: 32 pt, "Cerca in:" e le due capsule alte 22.
  Widget _scopeBar() {
    Widget capsule(String label, SearchScope scope) {
      final chosen = _searchScope == scope;
      return GestureDetector(
        key: ValueKey('ambito $label'),
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
            color: chosen ? const Color(0x1F000000) : null,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(label, style: text(12)),
        ),
      );
    }

    return SizedBox(
      key: const ValueKey('barra dell\'ambito'),
      height: 32,
      child: Row(
        children: [
          const SizedBox(width: 14),
          Text('Cerca in:', style: text(12, color: secondaryText)),
          const SizedBox(width: 8),
          capsule('Questo computer', SearchScope.computer),
          capsule('«${displayName(_searchFolder)}»', SearchScope.folder),
        ],
      ),
    );
  }
}
