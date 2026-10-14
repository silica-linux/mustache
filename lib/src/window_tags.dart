// Le etichette nella finestra (MU-62): lettura dagli attributi estesi, assegnazione dalla fila dei
// cerchi del menu contestuale (R10.3), la sezione Tag della barra laterale e la vista degli
// elementi con un'etichetta (R2.15).

part of 'window.dart';

/// Quanti elementi esamina al più la ricerca di un'etichetta nella home.
const int tagScanLimit = 50000;

extension _Tags on _MustacheWindowState {
  /// Le etichette di un elemento, lette una volta per caricamento.
  List<String> _tagsOf(Entry entry) =>
      _tagCache[entry.path] ??= readTags(entry.path);

  /// Le etichette di colore che hanno tutti gli elementi scelti.
  Set<TagColor> get _sharedColors {
    final items = _selection;
    if (items.isEmpty) return const {};
    return {
      for (final c in TagColor.values)
        if (items.every((e) => _tagsOf(e).contains(tagName(c)))) c,
    };
  }

  /// Un clic su un cerchio: se tutti gli elementi l'hanno la toglie, sennò la aggiunge.
  void _toggleTag(TagColor color) {
    final name = tagName(color);
    final items = _selection;
    final remove =
        items.isNotEmpty && items.every((e) => _tagsOf(e).contains(name));
    var failed = false;
    for (final e in items) {
      final tags = [..._tagsOf(e)];
      if (remove) {
        tags.remove(name);
      } else if (!tags.contains(name)) {
        tags.add(name);
      }
      if (writeTags(e.path, tags)) {
        _tagCache[e.path] = tags;
      } else {
        failed = true;
      }
    }
    _update(() {});
    if (failed) {
      _showError(
        'Non si può assegnare l\'etichetta.',
        'Il disco non permette gli attributi estesi.',
      );
    }
  }

  /// La fila dei cerchi del menu contestuale.
  MenuEntry _tagMenuRow() => MenuCustom(
    height: 25,
    width: 18 + 24.0 * TagColor.values.length + 12,
    builder: (context, close) => TagCircleRow(
      assigned: _sharedColors,
      onToggle: (c) {
        _toggleTag(c);
        close();
      },
    ),
  );

  /// I luoghi della sezione Tag.
  List<Place> get _tagPlaces => [
    for (final name in defaultTags.keys)
      Place(name, '$tagPathPrefix$name', PlaceKind.tag),
  ];

  /// Mostra gli elementi della home con l'etichetta, man mano che la ricerca li trova.
  Future<void> _showTag(String name) async {
    final home =
        widget.places
            .where((p) => p.kind == PlaceKind.home)
            .firstOrNull
            ?.path ??
        _history.current;
    final search = ++_tagSearch;
    _update(() {
      _tagView = name;
      _entries = const [];
      _selected.clear();
      _error = null;
    });
    final found = <Entry>[];
    var seen = 0;
    try {
      await for (final item in Directory(
        home,
      ).list(recursive: true, followLinks: false)) {
        if (search != _tagSearch || !mounted) return;
        if (++seen > tagScanLimit) break;
        // Niente cartelle nascoste (.cache, .local…): lì le etichette non si mettono.
        final relative = item.path.substring(home.length);
        if (relative.contains('/.')) continue;
        if (!readTags(item.path).contains(name)) continue;
        final entry = entryAt(item.path);
        if (entry == null) continue;
        found.add(entry);
        _update(
          () => _entries = sortEntries(
            [...found],
            _sort,
            descending: _descending,
            kindOf: _kind,
          ),
        );
      }
    } on FileSystemException {
      // Una cartella illeggibile ferma la ricerca: resta quel che si è trovato.
    }
  }
}
