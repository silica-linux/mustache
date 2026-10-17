// Go to Folder (⇧⌘G, kit `Apps/Mustache/Go To Folder Sheet`): a 460 × 212 sheet with a path field
// (396 × 32) that completes inline in the tertiary colour, a close button, the header "Go to:"
// and up to four folder suggestions in rows of 28, the first selected in the accent colour.
// Return goes to the typed folder, or to the chosen suggestion; Tab accepts the completion; the
// arrows move through the suggestions; Esc and the close button close the sheet.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';

const Size goToFolderSize = Size(460, 212);

/// How many suggestions the sheet lists.
const int goToFolderRows = 4;

/// The path typed in the sheet as an absolute path: `~` is [home], a relative path starts at
/// [cwd].
String expandTyped(String typed, {required String home, required String cwd}) {
  var path = typed.trim();
  if (path == '~') return home;
  if (path.startsWith('~/')) {
    path = '$home${path.substring(1)}';
  } else if (!path.startsWith('/')) {
    path = cwd.endsWith('/') ? '$cwd$path' : '$cwd/$path';
  }
  return path;
}

/// The folders that complete [typed]: the folders of the typed directory whose name starts with
/// what follows the last `/` (case-insensitively; hidden ones only for a typed dot), sorted by
/// name, at most [limit]. A path that does not exist, or cannot be read, has none.
List<String> folderSuggestions(
  String typed, {
  required String home,
  required String cwd,
  int limit = goToFolderRows,
}) {
  if (typed.trim().isEmpty) return const [];
  final slash = typed.lastIndexOf('/');
  final dirPart = slash < 0 ? '' : typed.substring(0, slash + 1);
  final prefix = (slash < 0 ? typed : typed.substring(slash + 1)).toLowerCase();
  final dir = expandTyped(
    dirPart.isEmpty ? '.' : dirPart,
    home: home,
    cwd: cwd,
  );
  final names = <String>[];
  try {
    for (final e in Directory(dir).listSync(followLinks: false)) {
      final name = e.path.substring(e.path.lastIndexOf('/') + 1);
      if (name.startsWith('.') && !prefix.startsWith('.')) continue;
      if (!name.toLowerCase().startsWith(prefix)) continue;
      // A link to a folder counts as a folder.
      if (e is Directory ||
          (e is Link && FileSystemEntity.isDirectorySync(e.path))) {
        names.add(name);
      }
    }
  } on FileSystemException {
    return const [];
  }
  names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  final base = dir.endsWith('/') ? dir : '$dir/';
  return [for (final n in names.take(limit)) '$base$n'];
}

/// A folder as the sheet lists it: `silica › Documents › Projects` for a folder in [home] (named
/// after it), `/ › usr › share` elsewhere.
String breadcrumb(String path, String home) {
  final homeName = home.substring(home.lastIndexOf('/') + 1);
  if (path == home) return homeName;
  if (path.startsWith('$home/')) {
    return [
      homeName,
      ...path.substring(home.length + 1).split('/'),
    ].join(' › ');
  }
  if (path == '/') return '/';
  return ['/', ...path.substring(1).split('/')].join(' › ');
}

class GoToFolderSheet extends StatefulWidget {
  const GoToFolderSheet({
    super.key,
    required this.home,
    required this.cwd,
    required this.onGo,
    required this.onClose,
  });

  final String home;

  /// The folder shown: relative paths start here.
  final String cwd;

  /// The folder (or file) to go to.
  final ValueChanged<String> onGo;
  final VoidCallback onClose;

  @override
  State<GoToFolderSheet> createState() => _GoToFolderSheetState();
}

class _GoToFolderSheetState extends State<GoToFolderSheet> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  List<String> _suggestions = const [];
  int _selected = 0;

  /// An arrow moved the selection: Return takes it even if the typed path exists.
  bool _picked = false;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(_changed);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _expand(String typed) =>
      expandTyped(typed, home: widget.home, cwd: widget.cwd);

  void _changed() {
    final next = folderSuggestions(
      _text.text,
      home: widget.home,
      cwd: widget.cwd,
    );
    setState(() {
      _suggestions = next;
      _selected = 0;
      _picked = false;
      _notFound = false;
    });
  }

  /// What follows the typed text in the selected suggestion's name.
  String get _completion {
    if (_suggestions.isEmpty) return '';
    final typed = _text.text;
    final prefix = typed.substring(typed.lastIndexOf('/') + 1);
    final path = _suggestions[_selected];
    final name = path.substring(path.lastIndexOf('/') + 1);
    return name.length > prefix.length ? name.substring(prefix.length) : '';
  }

  void _accept() {
    if (_suggestions.isEmpty) return;
    final typed = _text.text;
    final slash = typed.lastIndexOf('/');
    final path = _suggestions[_selected];
    final name = path.substring(path.lastIndexOf('/') + 1);
    final text = '${typed.substring(0, slash + 1)}$name/';
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _submit() {
    final typed = _text.text.trim();
    if (typed.isEmpty) return;
    final exact = _expand(typed);
    final exists =
        FileSystemEntity.typeSync(exact) != FileSystemEntityType.notFound;
    if (exists && !_picked) {
      widget.onGo(exact);
    } else if (_suggestions.isNotEmpty) {
      widget.onGo(_suggestions[_selected]);
    } else {
      setState(() => _notFound = true);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && _suggestions.isNotEmpty) {
      setState(() {
        _selected = (_selected + 1) % _suggestions.length;
        _picked = true;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && _suggestions.isNotEmpty) {
      setState(() {
        _selected = (_selected - 1 + _suggestions.length) % _suggestions.length;
        _picked = true;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      _accept();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    final style = AmalfiType.body(color: colors.textPrimary);
    return SizedBox.fromSize(
      size: goToFolderSize,
      child: AmalfiAlertSurface(
        radius: AmalfiSheetMetrics.radius,
        child: Stack(
          children: [
            Positioned(
              left: 16,
              top: 16,
              width: 396,
              height: 32,
              child: DecoratedBox(
                key: const ValueKey('go to folder field'),
                decoration: ShapeDecoration(
                  color: colors.surfaceSunken,
                  shape: AmalfiSmoothBorder(radius: 10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Focus(
                    onKeyEvent: _onKey,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // The completion, after the typed text (invisible here, same style).
                        Row(
                          children: [
                            Text(
                              _text.text,
                              style: style.copyWith(
                                color: const Color(0x00000000),
                              ),
                            ),
                            Text(
                              _completion,
                              key: const ValueKey('go to folder completion'),
                              style: style.copyWith(color: colors.textTertiary),
                            ),
                          ],
                        ),
                        EditableText(
                          controller: _text,
                          focusNode: _focus,
                          autofocus: true,
                          style: style,
                          cursorColor: colors.textPrimary,
                          backgroundCursorColor: colors.textPrimary,
                          selectionColor: colors.accentAmalfiSoft,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 420,
              top: 18,
              child: AmalfiIconButton(
                key: const ValueKey('go to folder close'),
                icon: const AmalfiGlyph(AmalfiGlyphs.xmark),
                semanticLabel: l10n.closeSheet,
                size: AmalfiControlSize.regular,
                onPressed: widget.onClose,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 60,
              height: 1,
              child: ColoredBox(color: colors.lineSeparator),
            ),
            Positioned(
              left: 16,
              top: 68,
              child: Text(
                _notFound ? l10n.goToFolderNotFound : l10n.goToFolderHeader,
                style: AmalfiType.caption(
                  color: _notFound
                      ? colors.paletteTerracotta
                      : colors.textTertiary,
                ),
              ),
            ),
            for (var i = 0; i < _suggestions.length; i++)
              Positioned(
                left: 8,
                top: 88 + 28.0 * i,
                width: 444,
                height: 28,
                child: GestureDetector(
                  key: ValueKey('go to folder suggestion $i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onGo(_suggestions[i]),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: i == _selected ? colors.accentAmalfi : null,
                      shape: AmalfiSmoothBorder(radius: 8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          breadcrumb(_suggestions[i], widget.home),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AmalfiType.body(
                            color: i == _selected
                                ? const Color(0xFFFFFFFF)
                                : colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
