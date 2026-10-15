// Folder colour and symbol, kept on the folder itself so every app sees them:
//
// - colour tags in `user.xdg.tags` (the freedesktop convention, also read by other file
//   managers): a tag named like a colour (Red, Rosso…) tints the folder;
// - a symbol or an emoji in `user.silica.folder`, JSON such as `{"symbol":"music-note"}` or
//   `{"emoji":"🎵"}` (the emoji replaces the symbol); the symbol is a silica-icons symbol name.
//   An older custom tint (`{"tint":"#e8336d"}`, a `#rrggbb` or a colour name) is still read;
// - where the disk has no user attributes (some USB and network file systems), the same JSON in
//   the GIO metadata store, key `metadata::silica-folder`.
//
// The folder colour is its tag colour (FOLDER-CUSTOM): the colour of the last assigned colour tag,
// else an older custom tint, else none. Values are
// cached per folder; watching the displayed folders (inotify IN_ATTRIB arrives as a modify event
// without content change) drops the entries that changed and redraws the folder icons.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'external.dart';
import 'tags.dart';
import 'xattr.dart';
import 'xattr.dart' as xattr show readTags;

const String folderStyleAttribute = 'user.silica.folder';
const String folderStyleMetadata = 'metadata::silica-folder';

final RegExp _hexTint = RegExp(r'^#[0-9a-fA-F]{6}$');

/// An emoji is at most this many code points (flags and family sequences are long).
const int maxEmojiRunes = 12;

final RegExp _symbolName = RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$');

/// A valid stored tint: `#rrggbb` or the name of a colour (`red`…`gray`).
bool validTint(String? tint) =>
    tint != null &&
    (_hexTint.hasMatch(tint) || TagColor.values.any((c) => c.name == tint));

bool validSymbol(String? symbol) =>
    symbol != null && _symbolName.hasMatch(symbol);

/// A storable emoji: short, no control characters or spaces.
bool validEmoji(String? emoji) =>
    emoji != null &&
    emoji.isNotEmpty &&
    emoji.runes.length <= maxEmojiRunes &&
    !emoji.runes.any((r) => r <= 0x20 || (r >= 0x7f && r < 0xa0)) &&
    // A bare ASCII letter or digit is not an emoji (a keycap is: digit + U+FE0F + U+20E3).
    (emoji.runes.length > 1 || emoji.runes.first > 0x7f);

/// What the user chose for a folder (any part can be missing). A symbol and an emoji exclude
/// each other.
@immutable
class FolderStyle {
  const FolderStyle({this.tint, this.symbol, this.emoji});

  final String? tint;
  final String? symbol;
  final String? emoji;

  bool get isEmpty => tint == null && symbol == null && emoji == null;

  FolderStyle withTint(String? value) =>
      FolderStyle(tint: value, symbol: symbol, emoji: emoji);

  /// The symbol replaces an emoji.
  FolderStyle withSymbol(String? value) => FolderStyle(
    tint: tint,
    symbol: value,
    emoji: value == null ? emoji : null,
  );

  /// The emoji replaces a symbol.
  FolderStyle withEmoji(String? value) => FolderStyle(
    tint: tint,
    symbol: value == null ? symbol : null,
    emoji: value,
  );

  /// The stored JSON; unknown or malformed fields are dropped. Null: nothing usable.
  static FolderStyle? parse(String? json) {
    if (json == null || json.trim().isEmpty) return null;
    try {
      final value = jsonDecode(json);
      if (value is! Map) return null;
      final tint = value['tint'];
      final symbol = value['symbol'];
      final emoji = value['emoji'];
      final okEmoji = emoji is String && validEmoji(emoji);
      final style = FolderStyle(
        tint: tint is String && validTint(tint) ? tint.toLowerCase() : null,
        symbol: !okEmoji && symbol is String && validSymbol(symbol)
            ? symbol
            : null,
        emoji: okEmoji ? emoji : null,
      );
      return style.isEmpty ? null : style;
    } on FormatException {
      return null;
    }
  }

  String encode() =>
      jsonEncode({'tint': ?tint, 'symbol': ?symbol, 'emoji': ?emoji});

  @override
  bool operator ==(Object other) =>
      other is FolderStyle &&
      other.tint == tint &&
      other.symbol == symbol &&
      other.emoji == emoji;

  @override
  int get hashCode => Object.hash(tint, symbol, emoji);
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

/// What a folder icon shows: the symbol or the emoji and the tint (`#rrggbb` or a colour name).
typedef FolderLook = ({String? symbol, String? tint, String? emoji});

/// Folder styles: read, cached, saved, and watched.
class FolderStyles extends ChangeNotifier {
  FolderStyles({
    this.readAttribute = readAttributeChecked,
    this.writeAttribute = writeAttributeChecked,
    this.readTags = _readTags,
    this.metadata = const GioFolderMetadata(),
    this.debounce = const Duration(milliseconds: 120),
    bool? watchDisk,
  }) : watchDisk = watchDisk ?? !startsNothing;

  final ({String? value, bool unsupported}) Function(String path, String name)
  readAttribute;
  final AttributeWrite Function(String path, String name, String value)
  writeAttribute;
  final List<String> Function(String path) readTags;
  final FolderMetadata metadata;
  final Duration debounce;

  /// Watch the disk for real (off under `flutter test`, where tests deliver [changed] by hand
  /// unless they ask for it).
  final bool watchDisk;

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

  /// Symbol or emoji and tint of the folder: the tint is the colour of the last assigned colour
  /// tag (tags are stored in the order they were assigned), else an older custom tint.
  FolderLook look(String path) {
    final hit = _looks[path];
    if (hit != null) return hit;
    final style = stored(path);
    String? tint;
    for (final tag in readTags(path)) {
      if (tagColor(tag) case final color?) tint = color.name;
    }
    tint ??= style?.tint;
    if (_looks.length > 4000) _looks.clear();
    return _looks[path] = (
      symbol: style?.symbol,
      tint: tint,
      emoji: style?.emoji,
    );
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

  final Map<String, (StreamSubscription<FileSystemEvent>?, int)> _watches = {};
  final Set<String> _pending = {};
  Timer? _flush;

  /// Watches the folder [dir] (its own attributes and those of its items) while shown; the
  /// returned function stops it. Watches are shared and counted.
  VoidCallback watch(String dir) {
    final current = _watches[dir];
    if (current != null) {
      _watches[dir] = (current.$1, current.$2 + 1);
    } else {
      StreamSubscription<FileSystemEvent>? sub;
      if (watchDisk) {
        try {
          sub = Directory(dir).watch().listen(
            (event) => _changed(event.path),
            onError: (Object _) {},
          );
        } on FileSystemException {
          sub = null;
        }
      }
      _watches[dir] = (sub, 1);
    }
    var done = false;
    return () {
      if (done) return;
      done = true;
      final w = _watches[dir];
      if (w == null) return;
      if (w.$2 > 1) {
        _watches[dir] = (w.$1, w.$2 - 1);
      } else {
        _watches.remove(dir);
        w.$1?.cancel();
      }
    };
  }

  /// The folders watched now (for tests).
  @visibleForTesting
  Set<String> get watched => _watches.keys.toSet();

  void _changed(String path) {
    _pending.add(path);
    _flush ??= Timer(debounce, () {
      _flush = null;
      final paths = [..._pending];
      _pending.clear();
      invalidate(paths);
    });
  }

  /// A change at [path] seen by another watcher (the desktop has its own), or by a test:
  /// debounced like the watcher's.
  void changed(String path) => _changed(path);

  @override
  void dispose() {
    for (final (sub, _) in _watches.values) {
      sub?.cancel();
    }
    _watches.clear();
    _flush?.cancel();
    super.dispose();
  }
}

/// The styles of the whole app.
FolderStyles folderStyles = FolderStyles();
