// Saved searches: a `.search` file (JSON) that holds what to look for and where. Mustache
// writes them in the folder the user chooses (`~/Saved Searches` by default), lists the ones
// added to the sidebar (settings.json, `savedSearches`) and runs one when it is opened.
//
//     {"version": 1, "query": "lemon", "scope": "folder", "folder": "/home/a/Documents"}
//
// `scope` is `computer` (the home folder and everything under it) or `folder`.

import 'dart:convert';
import 'dart:io';

const String savedSearchExtension = 'search';

class SavedSearch {
  const SavedSearch({
    required this.query,
    required this.everywhere,
    this.folder,
  });

  final String query;

  /// True: This Computer; false: [folder].
  final bool everywhere;
  final String? folder;

  Map<String, Object?> toJson() => {
    'version': 1,
    'query': query,
    'scope': everywhere ? 'computer' : 'folder',
    if (!everywhere && folder != null) 'folder': folder,
  };

  /// A saved search from its JSON; null when it is not one (odd values never throw).
  static SavedSearch? fromJson(Object? json) {
    if (json is! Map) return null;
    final query = json['query'];
    if (query is! String || query.trim().isEmpty) return null;
    final folder = json['folder'];
    final everywhere = json['scope'] != 'folder' || folder is! String;
    return SavedSearch(
      query: query,
      everywhere: everywhere,
      folder: folder is String ? folder : null,
    );
  }

  /// Reads the file at [path]; null if it is missing or damaged.
  static SavedSearch? read(String path) {
    try {
      return fromJson(jsonDecode(File(path).readAsStringSync()));
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }
}

/// A file name for [name] in [dir]: `name.search`, or `name 2.search`… when it exists. Slashes
/// in the name become `-`.
String uniqueSearchPath(String dir, String name) {
  var base = name.trim().replaceAll('/', '-');
  if (base.isEmpty) base = 'Search';
  var path = '$dir/$base.$savedSearchExtension';
  for (var n = 2; File(path).existsSync(); n++) {
    path = '$dir/$base $n.$savedSearchExtension';
  }
  return path;
}

/// Writes [search] as a new file in [dir] (created if needed) named after [name]; the path, or
/// null if it could not be written.
String? writeSavedSearch(String dir, String name, SavedSearch search) {
  try {
    Directory(dir).createSync(recursive: true);
    final path = uniqueSearchPath(dir, name);
    File(path).writeAsStringSync(jsonEncode(search.toJson()));
    return path;
  } on FileSystemException {
    return null;
  }
}

/// The default folder of saved searches.
String savedSearchesDir(String home) => '$home/Saved Searches';
