// Folder colour and symbol, kept on the folder itself so every app sees them:
//
// - colour tags in `user.xdg.tags` (the freedesktop convention, also read by other file
//   managers): a tag named like a colour (Red, Rosso…) tints the folder;
// - a custom tint and/or symbol in `user.silica.folder`, JSON such as
//   `{"tint":"#e8336d","symbol":"music-note"}`; the tint is `#rrggbb` or a colour name (`red`),
//   the symbol a silica-icons symbol name;
// - where the disk has no user attributes (some USB and network file systems), the same JSON in
//   the GIO metadata store, key `metadata::silica-folder`.
//
// The tint is the custom one, else the colour of the first colour tag, else none. Values are
// cached per folder; watching the displayed folders (inotify IN_ATTRIB arrives as a modify event
// without content change) drops the entries that changed and redraws the folder icons.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'external.dart';
import 'tags.dart';
import 'xattr.dart';
import 'xattr.dart' as xattr show readTags;

const String folderStyleAttribute = 'user.silica.folder';
const String folderStyleMetadata = 'metadata::silica-folder';

final RegExp _hexTint = RegExp(r'^#[0-9a-fA-F]{6}$');
final RegExp _symbolName = RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$');

/// A valid stored tint: `#rrggbb` or the name of a colour (`red`…`gray`).
bool validTint(String? tint) =>
    tint != null &&
    (_hexTint.hasMatch(tint) || TagColor.values.any((c) => c.name == tint));

bool validSymbol(String? symbol) =>
    symbol != null && _symbolName.hasMatch(symbol);

/// What the user chose for a folder (either part can be missing).
@immutable
class FolderStyle {
  const FolderStyle({this.tint, this.symbol});

  final String? tint;
  final String? symbol;

  bool get isEmpty => tint == null && symbol == null;

  FolderStyle withTint(String? value) =>
      FolderStyle(tint: value, symbol: symbol);
  FolderStyle withSymbol(String? value) =>
      FolderStyle(tint: tint, symbol: value);

  /// The stored JSON; unknown or malformed fields are dropped. Null: nothing usable.
  static FolderStyle? parse(String? json) {
    if (json == null || json.trim().isEmpty) return null;
    try {
      final value = jsonDecode(json);
      if (value is! Map) return null;
      final tint = value['tint'];
      final symbol = value['symbol'];
      final style = FolderStyle(
        tint: tint is String && validTint(tint) ? tint.toLowerCase() : null,
        symbol: symbol is String && validSymbol(symbol) ? symbol : null,
      );
      return style.isEmpty ? null : style;
    } on FormatException {
      return null;
    }
  }

  String encode() => jsonEncode({'tint': ?tint, 'symbol': ?symbol});

  @override
  bool operator ==(Object other) =>
      other is FolderStyle && other.tint == tint && other.symbol == symbol;

  @override
  int get hashCode => Object.hash(tint, symbol);
}

/// The store used where a disk has no user attributes.
abstract interface class FolderMetadata {
  String? read(String path);

  /// Writes [value]; null removes it. False if it could not.
  bool write(String path, String? value);
}

/// The GIO metadata store, through `gio info` and `gio set` (never under `flutter test`).
class GioFolderMetadata implements FolderMetadata {
  const GioFolderMetadata();

  @override
  String? read(String path) {
    final r = runQuietly('gio', ['info', '-a', folderStyleMetadata, path]);
    if (r == null || r.exitCode != 0) return null;
    return parseGioInfo('${r.stdout}');
  }

  @override
  bool write(String path, String? value) {
    final r = value == null
        ? runQuietly('gio', ['set', '-t', 'unset', path, folderStyleMetadata])
        : runQuietly('gio', ['set', path, folderStyleMetadata, value]);
    return r != null && r.exitCode == 0;
  }
}

/// The value of `metadata::silica-folder` in the output of `gio info -a`.
String? parseGioInfo(String output) {
  const prefix = '$folderStyleMetadata: ';
  for (final line in const LineSplitter().convert(output)) {
    final t = line.trim();
    if (t.startsWith(prefix)) return t.substring(prefix.length);
  }
  return null;
}

/// What a folder icon shows: the symbol and the tint (`#rrggbb` or a colour name).
typedef FolderLook = ({String? symbol, String? tint});

/// Folder styles: read, cached and saved.
class FolderStyles extends ChangeNotifier {
  FolderStyles({
    this.readAttribute = readAttributeChecked,
    this.writeAttribute = writeAttributeChecked,
    this.readTags = _readTags,
    this.metadata = const GioFolderMetadata(),
    this.debounce = const Duration(milliseconds: 120),
  });

  final ({String? value, bool unsupported}) Function(String path, String name)
  readAttribute;
  final AttributeWrite Function(String path, String name, String value)
  writeAttribute;
  final List<String> Function(String path) readTags;
  final FolderMetadata metadata;
  final Duration debounce;

  static List<String> _readTags(String path) => xattr.readTags(path);

  final Map<String, FolderStyle?> _stored = {};
  final Map<String, FolderLook> _looks = {};

  /// The custom style of the folder at [path] (the attribute, or the GIO store where the disk
  /// has no attributes).
  FolderStyle? stored(String path) {
    if (_stored.containsKey(path)) return _stored[path];
    final read = readAttribute(path, folderStyleAttribute);
    final style = FolderStyle.parse(
      read.unsupported ? metadata.read(path) : read.value,
    );
    if (_stored.length > 4000) _stored.clear();
    return _stored[path] = style;
  }

  /// Symbol and tint of the folder: the custom tint, else the first colour tag's.
  FolderLook look(String path) {
    final hit = _looks[path];
    if (hit != null) return hit;
    final style = stored(path);
    var tint = style?.tint;
    if (tint == null) {
      for (final tag in readTags(path)) {
        if (tagColor(tag) case final color?) {
          tint = color.name;
          break;
        }
      }
    }
    if (_looks.length > 4000) _looks.clear();
    return _looks[path] = (symbol: style?.symbol, tint: tint);
  }

  /// Saves [style] on the folder (an empty style removes it). False if it could not.
  bool save(String path, FolderStyle style) {
    final value = style.isEmpty ? '' : style.encode();
    final done = switch (writeAttribute(path, folderStyleAttribute, value)) {
      AttributeWrite.done => true,
      AttributeWrite.unsupported => metadata.write(
        path,
        style.isEmpty ? null : value,
      ),
      AttributeWrite.failed => false,
    };
    invalidate([path]);
    return done;
  }

  /// Forgets what is cached for [paths] and redraws if any was shown.
  void invalidate(Iterable<String> paths) {
    var changed = false;
    for (final p in paths) {
      final known = _stored.containsKey(p) || _looks.containsKey(p);
      _stored.remove(p);
      _looks.remove(p);
      changed |= known;
    }
    if (changed) notifyListeners();
  }

  final Set<String> _pending = {};
  Timer? _flush;

  void _changed(String path) {
    _pending.add(path);
    _flush ??= Timer(debounce, () {
      _flush = null;
      final paths = [..._pending];
      _pending.clear();
      invalidate(paths);
    });
  }

  /// A change at [path] seen by the folder watcher (folder_watch.dart), or by a test: debounced.
  void changed(String path) => _changed(path);

  @override
  void dispose() {
    _flush?.cancel();
    super.dispose();
  }
}

/// The styles of the whole app.
FolderStyles folderStyles = FolderStyles();
