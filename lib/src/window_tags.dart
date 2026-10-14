// Tags in the window (MU-62): reading from extended attributes, assignment from the row of circles
// in the context menu (R10.3), the Tags section of the sidebar and the view of the items with a tag
// (R2.15).

part of 'window.dart';

/// How many items the search for a tag in home examines at most.
const int tagScanLimit = 50000;

extension _Tags on _MustacheWindowState {
  /// The tags of an item, read once per load.
  List<String> _tagsOf(Entry entry) =>
      _tagCache[entry.path] ??= readTags(entry.path);

  /// The color tags all the chosen items have.
  Set<TagColor> _sharedColors(List<Entry> items) {
    if (items.isEmpty) return const {};
    return {
      for (final c in TagColor.values)
        if (items.every((e) => _tagsOf(e).any((t) => tagColor(t) == c))) c,
    };
  }

  /// A click on a circle: if all items have it, it is removed, otherwise added.
  void _toggleTag(TagColor color, [List<Entry>? targets]) {
    final name = tagName(color);
    final items = targets ?? _selection;
    bool has(List<String> tags) => tags.any((t) => tagColor(t) == color);
    final remove = items.isNotEmpty && items.every((e) => has(_tagsOf(e)));
    var failed = false;
    for (final e in items) {
      final tags = [..._tagsOf(e)];
      if (remove) {
        tags.removeWhere((t) => tagColor(t) == color);
      } else if (!has(tags)) {
        tags.add(name);
      }
      if (writeTags(e.path, tags)) {
        _tagCache[e.path] = tags;
        // A colour tag tints a folder.
        if (e.isDirectory) folderStyles.invalidate([e.path]);
      } else {
        failed = true;
      }
    }
    _update(() {});
    if (failed) {
      _showError(l10n.tagError, l10n.tagErrorDetail);
    }
  }

  /// A tag typed in the preview pane field.
  void _addTag(Entry entry, String tag) {
    final tags = [..._tagsOf(entry)];
    if (tags.contains(tag)) return;
    tags.add(tag);
    if (writeTags(entry.path, tags)) {
      _update(() => _tagCache[entry.path] = tags);
      if (entry.isDirectory) folderStyles.invalidate([entry.path]);
    } else {
      _showError(l10n.tagError, l10n.tagErrorDetail);
    }
  }

  /// The actions at the bottom of the preview pane, depending on the choice (spec/preview-pane.md): Edit for
  /// images and PDFs (with the default app), More (the item menu) always.
  List<PaneAction> _paneActions() {
    final items = _selection;
    if (items.isEmpty) return const [];
    final one = items.length == 1 ? items.single : null;
    final editable =
        one != null &&
        !one.isDirectory &&
        (hasThumbnail(one.name) || one.extension == 'pdf');
    return [
      if (editable) PaneAction(l10n.paneEdit, 'pencil', (_) => _openEntry(one)),
      PaneAction(
        l10n.paneMore,
        'ellipsis-circle',
        (at) => _openContextMenu(items.first, at),
      ),
    ];
  }

  /// The row of circles of the context menu.
  MenuEntry _tagMenuRow(List<Entry> items) => MenuCustom(
    height: 25,
    width: 18 + 24.0 * TagColor.values.length + 12,
    builder: (context, close) => TagCircleRow(
      assigned: _sharedColors(items),
      onToggle: (c) {
        _toggleTag(c, items);
        close();
      },
    ),
  );

  /// The places of the Tags section.
  List<Place> get _tagPlaces => [
    for (final color in TagColor.values)
      Place(tagName(color), '$tagPathPrefix${tagName(color)}', PlaceKind.tag),
  ];

  /// Shows the items in home with the tag, as the search finds them.
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
        // No hidden folders (.cache, .local…): tags are not put there.
        final relative = item.path.substring(home.length);
        if (relative.contains('/.')) continue;
        if (!readTags(item.path).any((t) => sameTag(t, name))) continue;
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
      // An unreadable folder stops the search: what was found stays.
    }
  }
}
