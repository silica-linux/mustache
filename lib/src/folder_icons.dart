// Full folders: a folder with at least one visible item is drawn with the `full` variant of
// its silica-icons icon (a sheet between the back and front panels). The folder's symbol and
// tint stay dynamic on top. The variant is picked here with the public silica_ui types, so it
// works before silica_ui itself offers a `full` flag.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'folder_style.dart';

/// Per folder: its modification time when it was listed, and whether it has a visible item.
/// A folder's modification time changes when an item is added, removed or renamed, so one
/// `stat` per query tells whether the cached answer still holds; the listing runs again only
/// then, and it is not recursive.
final Map<String, (DateTime, bool)> _hasItems = {};

/// The folder at [path] contains at least one item. Hidden files (names starting with a dot)
/// do not count. A folder that cannot be read is empty.
bool folderHasItems(String path) {
  try {
    final directory = Directory(path);
    final changed = directory.statSync().modified;
    final cached = _hasItems[path];
    if (cached != null && cached.$1 == changed) return cached.$2;
    var found = false;
    for (final item in directory.listSync(followLinks: false)) {
      final slash = item.path.lastIndexOf('/');
      if (!item.path.substring(slash + 1).startsWith('.')) {
        found = true;
        break;
      }
    }
    if (_hasItems.length > 2000) _hasItems.clear();
    _hasItems[path] = (changed, found);
    return found;
  } on FileSystemException {
    return false;
  }
}

/// The `full` variants already read, per manifest folder (null: the icon has none).
final Map<String, LayeredIcon?> _fullIcons = {};

final RegExp _svgName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}\.svg$');

/// [icon] with the artwork of its `full` and `full-dark` variants (`variants` of its
/// `icon.json`); [icon] itself if it has none. Id, kind and dynamic content are kept.
LayeredIcon fullFolderVariant(LayeredIcon icon) {
  if (icon.layers.length != 1) return icon;
  final path = icon.layers.first.path;
  final slash = path.lastIndexOf('/');
  if (slash < 0) return icon;
  final dir = path.substring(0, slash);
  final key = '$dir\u0000${icon.id}';
  if (_fullIcons.containsKey(key)) return _fullIcons[key] ?? icon;
  LayeredIcon? full;
  try {
    final json = jsonDecode(File('$dir/icon.json').readAsStringSync());
    final variants = json is Map ? json['variants'] : null;
    String? artwork(String name) {
      final variant = variants is Map ? variants[name] : null;
      final file = variant is Map ? variant['artwork'] : null;
      if (file is! String || !_svgName.hasMatch(file)) return null;
      return File('$dir/$file').existsSync() ? '$dir/$file' : null;
    }

    final light = artwork('full');
    if (light != null) {
      full = LayeredIcon(
        id: icon.id,
        kind: icon.kind,
        layers: [
          IconLayer(
            light,
            darkPath: artwork('full-dark'),
            shadow: icon.layers.first.shadow,
          ),
        ],
        dynamic: icon.dynamic,
      );
    }
  } on FileSystemException {
    full = null;
  } on FormatException {
    full = null;
  }
  _fullIcons[key] = full;
  return full ?? icon;
}

/// [folder] drawn full: same symbol and tint, the `full` artwork.
FolderIcon fullFolder(FolderIcon folder) => FolderIcon(
  fullFolderVariant(folder.icon),
  symbol: folder.symbol,
  tint: folder.tint,
);

/// The icon of the folder at [path] with its colour and symbol (folder_style.dart): a custom
/// symbol replaces the special folder's; one silica-icons does not have keeps the special one.
/// An emoji is not part of it: [FolderEmoji] draws it on top.
FolderIcon? styledFolderIcon(
  String path, {
  Map<String, String>? env,
  FolderStyles? styles,
}) {
  final look = (styles ?? folderStyles).look(path);
  // An emoji replaces every symbol, the special folder's too (an unknown key has none).
  final folder = resolveFolderIcon(
    path,
    symbol: look.symbol,
    key: look.emoji == null ? null : '-',
    tint: look.tint,
    env: env,
  );
  if (look.symbol != null && folder != null && folder.symbol == null) {
    return resolveFolderIcon(path, tint: look.tint, env: env);
  }
  return folder;
}

/// Where the emoji sits on the folder canvas, and its size: the centre of the symbol box of the
/// generic folder (x 0.5, y 0.569) and a third of the icon (FOLDER-CUSTOM: ~30 pt on 96 pt).
const Offset folderEmojiCentre = Offset(0.5, 0.569);
const double folderEmojiRatio = 0.31;

/// [child] (a folder icon of [side]) with the folder's [emoji] on its front, in full colour; no
/// emoji: [child] as it is.
class FolderEmoji extends StatelessWidget {
  const FolderEmoji({
    super.key,
    required this.emoji,
    required this.side,
    required this.child,
  });

  final String? emoji;
  final double side;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final emoji = this.emoji;
    if (emoji == null) return child;
    final box = side * folderEmojiRatio;
    return Stack(
      children: [
        child,
        Positioned(
          left: side * folderEmojiCentre.dx - box / 2,
          top: side * folderEmojiCentre.dy - box / 2,
          width: box,
          height: box,
          child: IgnorePointer(
            child: FittedBox(
              child: Text(
                emoji,
                key: const ValueKey('folder emoji'),
                style: const TextStyle(
                  fontSize: 100,
                  height: 1,
                  fontFamilyFallback: emojiFonts,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The colour emoji fonts, tried in order after the platform's own fallback.
const List<String> emojiFonts = ['Noto Color Emoji', 'Apple Color Emoji'];
