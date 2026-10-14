// A small silica-icons tree for folder tests: the generic folder (with colour names and the
// special folders' symbols), the plain folder and a few symbols, in a temporary directory.

import 'dart:io';

const String _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
    '<rect x="100" y="100" width="824" height="824" fill="#2f8cff"/></svg>';

const String _symbol =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<circle cx="12" cy="12" r="8" fill="#000"/></svg>';

const String _generic = '''
{
  "format": 1, "id": "folder-generic", "name": "Folder Generic", "kind": "file",
  "layers": [ { "role": "artwork", "file": "icon.svg" } ],
  "variants": {
    "dark": { "artwork": "icon-dark.svg" },
    "full": { "artwork": "icon-full.svg" },
    "full-dark": { "artwork": "icon-full-dark.svg" }
  },
  "dynamic": {
    "type": "folder-symbol",
    "symbol": {
      "box": [353.9, 424.36, 316.19, 316.19],
      "sizes": [ { "min_size": 16, "weight": "regular", "scale": 1 } ]
    },
    "effect": {
      "light": { "color": "#1a64c8", "opacity": 0.78 },
      "dark": { "color": "#0b3f94", "opacity": 0.8 }
    },
    "tint": {
      "light": { "luminance": [0.35, 0.85], "shade": 0.72, "glow": 0.5 },
      "labels": {
        "red": "#f2382e", "orange": "#ff8a00", "yellow": "#f5c400", "green": "#2fb350",
        "blue": "#2f7cf6", "purple": "#a052e0", "gray": "#8e8e93"
      }
    },
    "folders": { "MUSIC": "music-note", "DOCUMENTS": "doc-text" },
    "fallback": "folder"
  }
}
''';

const String _plain = '''
{
  "format": 1, "id": "folder", "name": "Folder", "kind": "file",
  "layers": [ { "role": "artwork", "file": "icon.svg" } ],
  "variants": { "full": { "artwork": "icon-full.svg" } },
  "dynamic": null
}
''';

/// The symbols of the fixture.
const List<String> fixtureSymbols = [
  'doc-text',
  'house',
  'music-list',
  'music-note',
  'star',
];

/// Creates the tree; the caller deletes it.
Directory folderIconsRoot() {
  final root = Directory.systemTemp.createTempSync('silica-icons-');
  for (final (id, manifest) in [
    ('folder-generic', _generic),
    ('folder', _plain),
  ]) {
    final dir = Directory('${root.path}/files/$id')
      ..createSync(recursive: true);
    File('${dir.path}/icon.json').writeAsStringSync(manifest);
    for (final name in ['icon', 'icon-dark', 'icon-full', 'icon-full-dark']) {
      File('${dir.path}/$name.svg').writeAsStringSync(_svg);
    }
  }
  final symbols = Directory('${root.path}/symbols/regular')
    ..createSync(recursive: true);
  for (final name in fixtureSymbols) {
    File('${symbols.path}/$name.svg').writeAsStringSync(_symbol);
  }
  return root;
}
