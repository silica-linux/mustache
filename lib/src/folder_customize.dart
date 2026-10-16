// Customize Folder (FOLDER-CUSTOM, docs/spec/folder-customize.md): a popover anchored to the folder
// icon, with an arrow, that edits the folder in place: tags (the folder colour is its tag colour),
// a silica-icons symbol or an emoji. Every change is saved on the folder at once (tags in
// `user.xdg.tags`, symbol and emoji in `user.silica.folder`, see folder_style.dart) and every
// folder icon redraws; there is no OK. Esc, or a click outside, closes it and keeps the changes.
//
// Measured: the body 320 × 670 (radius 18), the 96 pt preview, the 13 pt name, the colour row (a
// 20 pt "remove all tags" button, 26 pt discs at a 34 pitch, a 28 pt "+"), the selected group
// (10 pt offset, newest in front, 2 pt divider, slide ~280 ms, ~470 ms back), the symbol grid
// (426 tall, 44 pt cells, 6 per row, 18 pt glyphs, 2 pt accent ring), the 147 × 24 buttons.
// Provisional: the open and close animation (silica_ui's fade), the light mode of the emoji
// picker, the emoji picker's own contents (folder_emoji data, emoji_data.dart) and the symbol
// categories (silica-icons has no category data yet).

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:silica_ui/silica_ui.dart';

import 'emoji_data.dart';
import 'folder_icons.dart';
import 'folder_style.dart';
import 'l10n.dart';
import 'model.dart' show displayName;
import 'tags.dart';
import 'xattr.dart' as xattr show writeTags;

/// The popover body, the emoji picker body and the colour row (measured).
const Size folderPopoverSize = Size(320, 670);
const Size emojiPopoverSize = Size(320, 444);
const double folderPreviewSide = 96;
const double folderDiscSide = 26;
const double folderDiscPitch = 34;
const double folderDiscFirst = 42;
const double folderRowCentre = 157;
const double folderPlusSide = 28;
const double folderGroupOffset = 10;
const double folderSymbolCell = 44;
const int folderSymbolColumns = 6;
const double folderButtonWidth = 147;
const double folderButtonHeight = 24;

/// The slide of the discs: when a tag is assigned or removed, and when all are removed.
const Duration folderSlide = Duration(milliseconds: 280);
const Duration folderSlideAll = Duration(milliseconds: 470);

/// The disc colours: the Amalfi palette of the tags (tags.dart).
Color folderDiscColor(TagColor c, {required bool dark}) =>
    tagPaletteColor(c, dark: dark);

/// The selection ring and the selected glyph: `Accent/Amalfi` (light; the dark one is read from
/// the theme where it is drawn).
const Color folderAccent = Color(0xFF0E77E6);

/// The seven categories of the symbol grid, in order.
enum SymbolCategoryId {
  people,
  nature,
  food,
  activities,
  travel,
  objects,
  symbols,
}

String symbolCategoryTitle(SymbolCategoryId id) => switch (id) {
  SymbolCategoryId.people => l10n.symbolPeople,
  SymbolCategoryId.nature => l10n.symbolNature,
  SymbolCategoryId.food => l10n.symbolFood,
  SymbolCategoryId.activities => l10n.symbolActivities,
  SymbolCategoryId.travel => l10n.symbolTravel,
  SymbolCategoryId.objects => l10n.symbolObjects,
  SymbolCategoryId.symbols => l10n.symbolSymbols,
};

/// The silica-icons symbols of each category (provisional; names missing from the installed
/// icons are skipped, and any symbol not listed here goes to Symbols).
const Map<SymbolCategoryId, String> _categorySymbols = {
  SymbolCategoryId.people:
      'accessibility contact-card fingerprint person-2 person-circle person-fill person-plus '
      'person smiley',
  SymbolCategoryId.nature:
      'bug cloud-bolt cloud-fog cloud-moon cloud-rain cloud-snow cloud-sun cloud-fill cloud '
      'leaf-fill leaf moon-stars moon snowflake sparkles sun-min sun sunrise sunset thermometer '
      'umbrella-fill umbrella wind',
  SymbolCategoryId.food: 'drop-fill drop',
  SymbolCategoryId.activities:
      'camera film gamecontroller headphones megaphone-fill megaphone mic-fill mic-slash mic '
      'music-list music-note paintbrush palette pause-circle pause play-circle play-pause play '
      'puzzle-fill puzzle record-circle record repeat-1 repeat shuffle skip-backward skip-forward '
      'speaker stopwatch timer video-fill video-slash video volume-0 volume-1 volume-2 '
      'volume-slash volume wand waveform photo-fill photo gallery',
  SymbolCategoryId.travel:
      'airplane compass globe house-door-fill house-door house-fill house location-fill location '
      'pin scope',
  SymbolCategoryId.objects:
      'alarm archive battery-0 battery-10 battery-50 battery-charging battery bell-badge bell-fill '
      'bell-slash bell book bookmark-fill bookmark books-vertical-fill books-vertical calendar '
      'clipboard clock cpu cube desktop display-2 display doc-fill doc-plus doc-text doc dock '
      'drive envelope-open envelope eraser eyedropper folder-fill folder-plus folder hourglass '
      'key keyboard-brightness-min keyboard-brightness keyboard laptop lightbulb-fill lightbulb '
      'lock-fill lock-open lock message-2 message-ellipsis message-fill message mouse paperclip '
      'paperplane-fill paperplane pencil phone-down phone-fill phone plug printer router scissors '
      'sd-card server smartphone smartwatch tablet tag terminal trash-fill trash tray tv '
      'usb-drive webcam window-split-3 window-split window-stack window wrench gear sliders '
      'compose captions',
};

typedef SymbolCategory = ({SymbolCategoryId id, List<String> names});

/// The symbol names silica-icons offers for folders (`symbols/regular`), sorted; empty if the
/// icons are not installed. Read once per symbols folder.
List<String> folderSymbolNames({Map<String, String>? env}) {
  final dir = folderSymbolsDir(env: env);
  if (dir == null) return const [];
  return _symbolNames[dir] ??= () {
    try {
      final names = [
        for (final f in Directory('$dir/regular').listSync())
          if (f is File && f.path.endsWith('.svg'))
            f.path.substring(f.path.lastIndexOf('/') + 1, f.path.length - 4),
      ]..sort();
      return [
        for (final n in names)
          if (validSymbol(n)) n,
      ];
    } on FileSystemException {
      return const <String>[];
    }
  }();
}

final Map<String, List<String>> _symbolNames = {};

/// The symbols in their seven categories; empty categories are left out.
List<SymbolCategory> folderSymbolCategories({Map<String, String>? env}) {
  final all = folderSymbolNames(env: env);
  final placed = <String>{};
  final result = <SymbolCategory>[];
  for (final id in SymbolCategoryId.values) {
    final listed = _categorySymbols[id]?.split(' ') ?? const <String>[];
    final names = id == SymbolCategoryId.symbols
        ? [
            for (final n in all)
              if (!placed.contains(n)) n,
          ]
        : [
            for (final n in listed)
              if (all.contains(n) && placed.add(n)) n,
          ];
    if (names.isNotEmpty) result.add((id: id, names: names));
  }
  return result;
}

/// `symbols/` of the silica-icons folder icon, or null.
String? folderSymbolsDir({Map<String, String>? env}) {
  final dyn = findSilicaIcon('folder-generic', env: env)?.dynamic;
  return dyn is FolderSymbol ? dyn.symbolsDir : null;
}

/// The folder icons on screen by path, so the popover can point at the one it edits.
final Map<String, BuildContext> folderIconAnchors = {};

/// Registers [child] as the icon of the folder at [path] (the last one built wins).
class FolderIconAnchor extends StatefulWidget {
  const FolderIconAnchor({super.key, required this.path, required this.child});

  final String path;
  final Widget child;

  @override
  State<FolderIconAnchor> createState() => _FolderIconAnchorState();
}

class _FolderIconAnchorState extends State<FolderIconAnchor> {
  @override
  void initState() {
    super.initState();
    folderIconAnchors[widget.path] = context;
  }

  @override
  void didUpdateWidget(FolderIconAnchor old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      if (folderIconAnchors[old.path] == context) {
        folderIconAnchors.remove(old.path);
      }
      folderIconAnchors[widget.path] = context;
    }
  }

  @override
  void dispose() {
    if (folderIconAnchors[widget.path] == context) {
      folderIconAnchors.remove(widget.path);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The colors of the popover: Amalfi tokens (neutral greys, no warm tones).
class _Palette {
  const _Palette(this.dark, this.tokens);
  final bool dark;
  final AmalfiColors tokens;

  Color get text => tokens.textPrimary;
  Color get secondary => tokens.textSecondary;
  Color get line => tokens.lineSeparator;
  Color get glyph => tokens.textSecondary;
  Color get plusFill => tokens.surfaceSunken;
  Color get button => tokens.surfaceControl;
  Color get removeOn => tokens.textSecondary;
  Color get removeOff => tokens.textTertiary;
  Color get divider => tokens.lineBorder;
  Color get accent => tokens.accentAmalfi;
}

TextStyle _text(Color color, {double size = 13, FontWeight? weight}) =>
    TextStyle(
      fontFamily: uiFontFamily,
      package: 'silica_ui',
      fontSize: size,
      height: 1,
      color: color,
      fontWeight: weight,
      fontFamilyFallback: emojiFonts,
    );

/// The Customize Folder popover and, on top of it, the emoji picker and the "+" menu. It fills
/// the area it is put in (the window's content) and points at the icon of the folder at [path].
class FolderCustomizeOverlay extends StatefulWidget {
  const FolderCustomizeOverlay({
    super.key,
    required this.path,
    required this.onClose,
    this.env,
    this.styles,
    this.writeTags,
    this.onTagsChanged,
    this.onEditTags,
    this.waitForAnchor = false,
    this.focusNode,
  });

  final String path;
  final Map<String, String>? env;

  /// The styles to read and save (the app's by default).
  final FolderStyles? styles;

  /// Writes the folder's tags (the extended attribute by default); false if it could not.
  final bool Function(String path, List<String> tags)? writeTags;

  /// The folder's tags changed.
  final ValueChanged<List<String>>? onTagsChanged;

  /// "Edit Tags…" of the "+" menu; null hides the item.
  final VoidCallback? onEditTags;

  /// The popover closed (Esc, a click outside).
  final VoidCallback onClose;

  /// The window is still loading the folder that holds the icon: wait for it (~1 s at most).
  final bool waitForAnchor;

  /// The node that holds the keyboard (Esc) while the popover is open; the host can focus it
  /// again after a menu closes. Null: the popover has its own.
  final FocusNode? focusNode;

  @override
  State<FolderCustomizeOverlay> createState() => _FolderCustomizeOverlayState();
}

class _FolderCustomizeOverlayState extends State<FolderCustomizeOverlay> {
  FolderStyles get _styles => widget.styles ?? folderStyles;
  bool Function(String, List<String>) get _write =>
      widget.writeTags ?? xattr.writeTags;

  late FolderStyle _style = _styles.stored(widget.path) ?? const FolderStyle();
  late List<String> _tags = _styles.readTags(widget.path);
  late final FocusNode _ownFocus = FocusNode(debugLabel: 'folder popover');
  FocusNode get _focus => widget.focusNode ?? _ownFocus;
  Rect? _anchor;
  Timer? _retry;
  int _attempts = 0;
  bool _failed = false;
  bool _emojiOpen = false;
  Rect _emojiAnchor = Rect.zero;
  Rect _mainRect = Rect.zero;
  Rect _emojiRect = Rect.zero;
  bool _menuOpen = false;
  Object? _hover;
  Object? _pressed;
  Duration _slide = folderSlide;
  Curve _curve = Curves.easeOut;
  final GlobalKey _plusKey = GlobalKey();
  final GlobalKey _emojiKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _styles.addListener(_reload);
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveAnchor());
  }

  @override
  void dispose() {
    _retry?.cancel();
    _ownFocus.dispose();
    _styles.removeListener(_reload);
    super.dispose();
  }

  /// Changed elsewhere (another window, the shell, another app): show what is on disk.
  void _reload() {
    if (!mounted) return;
    final style = _styles.stored(widget.path) ?? const FolderStyle();
    final tags = _styles.readTags(widget.path);
    if (style != _style || !_sameList(tags, _tags)) {
      setState(() {
        _style = style;
        _tags = tags;
      });
    }
  }

  static bool _sameList(List<String> a, List<String> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((e) => e);

  void _resolveAnchor() {
    if (!mounted) return;
    final own = context.findRenderObject();
    Rect? rect;
    final target = folderIconAnchors[widget.path];
    if (own is RenderBox && own.hasSize && target != null && target.mounted) {
      final box = target.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) {
        rect = box.localToGlobal(Offset.zero, ancestor: own) & box.size;
      }
    }
    if (rect == null && widget.waitForAnchor && _attempts++ < 20) {
      _retry = Timer(const Duration(milliseconds: 50), _resolveAnchor);
      return;
    }
    // No icon on screen (a folder of another window): point near the top left of the area.
    rect ??= const Rect.fromLTWH(120, 80, 64, 64);
    setState(() => _anchor = rect);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  /// [key]'s widget in this overlay's coordinates.
  Rect? _localRect(GlobalKey key) {
    final own = context.findRenderObject();
    final box = key.currentContext?.findRenderObject();
    if (own is! RenderBox || box is! RenderBox || !box.attached) return null;
    return box.localToGlobal(Offset.zero, ancestor: own) & box.size;
  }

  _Palette get _p =>
      _Palette(AmalfiTheme.of(context).isDark, AmalfiTheme.of(context).colors);

  // Tags ------------------------------------------------------------------------------------

  /// The colour tags in the order they were assigned (the last one is the folder's colour).
  List<TagColor> get _assigned {
    final result = <TagColor>[];
    for (final t in _tags) {
      final c = tagColor(t);
      if (c != null && !result.contains(c)) result.add(c);
    }
    return result;
  }

  void _setTags(List<String> next, {bool all = false}) {
    final ok = _write(widget.path, next);
    if (ok) {
      _tags = next;
      widget.onTagsChanged?.call(next);
    }
    _styles.invalidate([widget.path]);
    setState(() {
      _failed = !ok;
      _slide = all ? folderSlideAll : folderSlide;
      _curve = all ? Curves.easeOutBack : Curves.easeOut;
    });
  }

  void _toggle(TagColor c) {
    if (_assigned.contains(c)) {
      _setTags([
        for (final t in _tags)
          if (tagColor(t) != c) t,
      ]);
    } else {
      _setTags([..._tags, tagName(c)]);
    }
  }

  /// Back to blue: no tag at all, and no older custom tint.
  void _removeAll() {
    if (_style.tint != null) _save(_style.withTint(null));
    if (_tags.isNotEmpty) _setTags(const [], all: true);
  }

  bool get _canRemoveAll => _tags.isNotEmpty || _style.tint != null;

  // Style -----------------------------------------------------------------------------------

  void _save(FolderStyle style) {
    final ok = _styles.save(widget.path, style);
    setState(() {
      _failed = !ok;
      if (ok) _style = style;
    });
  }

  void _pickEmoji(String emoji) {
    useEmoji(emoji);
    setState(() => _emojiOpen = false);
    _save(_style.withEmoji(emoji));
  }

  // Menus -----------------------------------------------------------------------------------

  void _openPlusMenu() {
    final rect = _localRect(_plusKey);
    if (rect == null) return;
    final colourless = [
      for (final t in _tags)
        if (tagColor(t) == null) t,
    ];
    final host = context;
    setState(() => _menuOpen = true);
    final at = rect.bottomLeft + const Offset(0, 4);
    final box = context.findRenderObject();
    final global = box is RenderBox ? box.localToGlobal(at) : at;
    showAmalfiMenu(
      context: host,
      position: global,
      opaque: true,
      entries: [
        for (final t in colourless)
          AmalfiMenuAction(
            t,
            icon: const TagDot(color: null, side: 12),
            checked: true,
            onSelected: () => _setTags([
              for (final x in _tags)
                if (x != t) x,
            ]),
          ),
        if (colourless.isNotEmpty && widget.onEditTags != null)
          const AmalfiMenuDivider(),
        if (widget.onEditTags != null)
          AmalfiMenuAction(l10n.folderEditTags, onSelected: widget.onEditTags),
      ],
    ).whenComplete(() {
      if (mounted) setState(() => _menuOpen = false);
    });
  }

  void _openEmoji() {
    if (_emojiOpen) {
      setState(() => _emojiOpen = false);
      return;
    }
    final rect = _localRect(_emojiKey);
    if (rect == null) return;
    setState(() {
      _emojiOpen = true;
      _emojiAnchor = rect;
    });
  }

  void _escape() {
    if (_menuOpen) return;
    if (_emojiOpen) {
      setState(() => _emojiOpen = false);
    } else {
      widget.onClose();
    }
  }

  // Build -----------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final anchor = _anchor;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = Offset.zero & constraints.biggest;
        if (anchor == null || bounds.isEmpty) return const SizedBox.shrink();
        // A short window shrinks the symbol grid, not the rest.
        final height = math.max(
          330.0,
          math.min(folderPopoverSize.height, bounds.height - 16),
        );
        final place = placePopover(
          anchor: anchor,
          size: Size(folderPopoverSize.width, height),
          bounds: bounds,
          preferred: TipEdge.right,
        );
        _mainRect = place.rect;
        final emoji = _emojiOpen
            ? placePopover(
                anchor: _emojiAnchor,
                size: emojiPopoverSize,
                bounds: bounds,
                preferred: TipEdge.bottom,
              )
            : null;
        _emojiRect = emoji?.rect ?? Rect.zero;
        return CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): _escape},
          child: Focus(
            focusNode: _focus,
            autofocus: true,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Listener(
                    key: const ValueKey('folder popover outside'),
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (e) {
                      if (_menuOpen) return;
                      final at = e.localPosition;
                      if (_emojiOpen && !_emojiRect.contains(at)) {
                        setState(() => _emojiOpen = false);
                        if (_mainRect.contains(at)) return;
                      }
                      if (!_mainRect.contains(at) && !_emojiRect.contains(at)) {
                        widget.onClose();
                      }
                    },
                  ),
                ),
                Positioned.fromRect(
                  rect: place.rect,
                  child: PopoverPanel(
                    key: const ValueKey('folder popover'),
                    edge: place.edge,
                    tip: place.tip,
                    child: _body(),
                  ),
                ),
                if (emoji != null)
                  Positioned.fromRect(
                    key: const ValueKey('emoji host'),
                    rect: emoji.rect,
                    child: PopoverPanel(
                      key: const ValueKey('emoji popover'),
                      edge: emoji.edge,
                      tip: emoji.tip,
                      child: EmojiPicker(onPick: _pickEmoji),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _body() {
    final p = _p;
    return Column(
      children: [
        SizedBox(height: 202, child: _top(p)),
        _line(p),
        Expanded(child: _symbols(p)),
        _line(p),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            children: [
              _button(
                p,
                key: 'folder clear',
                enabled: _style.symbol != null || _style.emoji != null,
                onTap: () => _save(_style.withSymbol(null).withEmoji(null)),
                child: Text(l10n.folderClear, style: _text(p.text)),
              ),
              const SizedBox(width: 10),
              _button(
                p,
                key: 'folder emoji button',
                anchorKey: _emojiKey,
                onTap: _openEmoji,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _style.emoji != null
                        ? Text(_style.emoji!, style: _text(p.text, size: 14))
                        : _glyph('smiley', 14, p.text, fallback: '☺'),
                    const SizedBox(width: 6),
                    Text(l10n.folderEmoji, style: _text(p.text)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _line(_Palette p) => Container(height: 1, color: p.line);

  Widget _button(
    _Palette p, {
    required String key,
    required Widget child,
    required VoidCallback onTap,
    bool enabled = true,
    GlobalKey? anchorKey,
  }) => GestureDetector(
    key: ValueKey(key),
    behavior: HitTestBehavior.opaque,
    onTap: enabled ? onTap : null,
    child: Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Container(
        key: anchorKey,
        width: folderButtonWidth,
        height: folderButtonHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.button,
          borderRadius: BorderRadius.circular(6),
        ),
        child: child,
      ),
    ),
  );

  Widget _glyph(String name, double side, Color color, {String? fallback}) {
    final dir = folderSymbolsDir(env: widget.env);
    final file = dir == null ? null : File('$dir/regular/$name.svg');
    if (file == null || !file.existsSync()) {
      return SizedBox(
        width: side,
        height: side,
        child: Center(
          child: Text(fallback ?? '', style: _text(color, size: side)),
        ),
      );
    }
    return SvgPicture.file(
      file,
      width: side,
      height: side,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  // The top: preview, name, colour row, caption ------------------------------------------------

  Widget _top(_Palette p) {
    final assigned = _assigned;
    final group = assigned.reversed
        .toList(); // newest first = in front, on the left
    final x = <TagColor, double>{};
    for (var i = 0; i < group.length; i++) {
      x[group[i]] = folderDiscFirst + folderGroupOffset * i;
    }
    var cursor = folderDiscFirst;
    double? dividerX;
    if (group.isNotEmpty) {
      dividerX =
          folderDiscFirst +
          folderDiscSide +
          folderGroupOffset * (group.length - 1) +
          6;
      cursor = dividerX + 2 + 8;
    }
    for (final c in TagColor.values) {
      if (assigned.contains(c)) continue;
      x[c] = cursor;
      cursor += folderDiscPitch;
    }
    // After the last disc: its 26 pt and the 8 pt gap, which is `cursor` already.
    final caption = _failed
        ? l10n.folderStyleError
        : switch (_hover) {
            final TagColor c => tagName(c),
            'remove' => l10n.folderRemoveAllTags,
            _ => null,
          };
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 16,
          left: (folderPopoverSize.width - folderPreviewSide) / 2,
          width: folderPreviewSide,
          height: folderPreviewSide,
          child: _preview(),
        ),
        Positioned(
          top: 116,
          left: 12,
          right: 12,
          height: 16,
          child: Text(
            displayName(widget.path),
            key: const ValueKey('folder name'),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _text(p.text, weight: FontWeight.w600).copyWith(height: 1.2),
          ),
        ),
        Positioned(
          left: 12,
          top: folderRowCentre - 10,
          width: 20,
          height: 20,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hover = 'remove'),
            onExit: (_) => setState(() {
              if (_hover == 'remove') _hover = null;
            }),
            child: GestureDetector(
              key: const ValueKey('folder remove all tags'),
              behavior: HitTestBehavior.opaque,
              onTap: _canRemoveAll ? _removeAll : null,
              child: CustomPaint(
                painter: _RemoveTagsPainter(
                  _canRemoveAll ? p.removeOn : p.removeOff,
                ),
              ),
            ),
          ),
        ),
        if (dividerX != null)
          AnimatedPositioned(
            key: const ValueKey('folder tag divider'),
            duration: _slide,
            curve: _curve,
            left: dividerX,
            top: folderRowCentre - 27,
            width: 2,
            height: 54,
            child: ColoredBox(color: p.divider),
          ),
        // From the back: the discs outside the group, then the group from the oldest to the
        // newest, so the newest is in front.
        for (final c in TagColor.values)
          if (!assigned.contains(c)) _disc(c, x[c]!, assigned: false),
        for (final c in assigned) _disc(c, x[c]!, assigned: true),
        AnimatedPositioned(
          duration: _slide,
          curve: _curve,
          left: cursor,
          top: folderRowCentre - folderPlusSide / 2,
          width: folderPlusSide,
          height: folderPlusSide,
          child: GestureDetector(
            key: _plusKey,
            behavior: HitTestBehavior.opaque,
            onTap: _openPlusMenu,
            child: Semantics(
              button: true,
              label: l10n.folderAddTag,
              child: Container(
                key: const ValueKey('folder add tag'),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.plusFill,
                ),
                child: CustomPaint(painter: _PlusPainter(p.secondary, 10)),
              ),
            ),
          ),
        ),
        if (caption != null)
          Positioned(
            top: 178,
            left: 8,
            right: 8,
            height: 14,
            child: Text(
              caption,
              key: const ValueKey('folder caption'),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _text(
                _failed ? p.tokens.paletteTerracotta : p.secondary,
                size: 11,
              ).copyWith(height: 1.2),
            ),
          ),
      ],
    );
  }

  Widget _preview() => ListenableBuilder(
    listenable: _styles,
    builder: (context, _) {
      final folder = styledFolderIcon(
        widget.path,
        env: widget.env,
        styles: _styles,
      );
      if (folder == null) return const SizedBox.shrink();
      return FolderEmoji(
        key: const ValueKey('folder preview'),
        emoji: _styles.look(widget.path).emoji,
        side: folderPreviewSide,
        child: SilicaIcon(
          FolderSource(
            folderHasItems(widget.path) ? fullFolder(folder) : folder,
          ),
          side: folderPreviewSide,
          env: widget.env,
        ),
      );
    },
  );

  Widget _disc(TagColor c, double left, {required bool assigned}) {
    final p = _p;
    final hovered = _hover == c;
    final pressed = _pressed == c;
    var color = folderDiscColor(c, dark: p.dark);
    if (pressed) {
      final hsl = HSLColor.fromColor(color);
      color = hsl
          .withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0))
          .toColor();
    }
    final glyph = hovered ? (assigned ? '×' : '+') : (assigned ? '✓' : null);
    return AnimatedPositioned(
      key: ValueKey('folder disc ${c.name}'),
      duration: _slide,
      curve: _curve,
      left: left,
      top: folderRowCentre - folderDiscSide / 2,
      width: folderDiscSide,
      height: folderDiscSide,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = c),
        onExit: (_) => setState(() {
          if (_hover == c) _hover = null;
          if (_pressed == c) _pressed = null;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = c),
          onTapCancel: () => setState(() => _pressed = null),
          onTapUp: (_) => setState(() => _pressed = null),
          onTap: () => _toggle(c),
          child: Semantics(
            button: true,
            label: tagName(c),
            checked: assigned,
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              alignment: Alignment.center,
              child: glyph == null
                  ? null
                  : Text(
                      glyph,
                      style: _text(
                        const Color(0xFFFFFFFF),
                        size: 15,
                        weight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // The symbol grid -----------------------------------------------------------------------------

  Widget _symbols(_Palette p) {
    final dir = folderSymbolsDir(env: widget.env);
    final categories = folderSymbolCategories(env: widget.env);
    if (dir == null || categories.isEmpty) {
      return Center(
        child: Text(l10n.folderNoSymbols, style: _text(p.secondary)),
      );
    }
    return CustomScrollView(
      key: const ValueKey('folder symbols'),
      slivers: [
        for (final category in categories) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: SizedBox(
                height: 16,
                child: Text(
                  symbolCategoryTitle(category.id),
                  style: _text(p.text, weight: FontWeight.w700),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: folderSymbolColumns,
                mainAxisExtent: folderSymbolCell,
                crossAxisSpacing:
                    (folderPopoverSize.width -
                        40 -
                        folderSymbolCell * folderSymbolColumns) /
                    (folderSymbolColumns - 1),
              ),
              itemCount: category.names.length,
              itemBuilder: (context, i) =>
                  _symbolCell(p, dir, category.names[i]),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
      ],
    );
  }

  Widget _symbolCell(_Palette p, String dir, String name) {
    final selected = _style.symbol == name;
    return GestureDetector(
      key: ValueKey('folder symbol $name'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _save(_style.withSymbol(name)),
      child: Semantics(
        button: true,
        selected: selected,
        label: name.replaceAll('-', ' '),
        child: Container(
          width: folderSymbolCell,
          height: folderSymbolCell,
          alignment: Alignment.center,
          decoration: selected
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: p.accent, width: 2),
                )
              : null,
          child: SvgPicture.file(
            File('$dir/regular/$name.svg'),
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(
              selected ? p.accent : p.glyph,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}

/// A crossed tag: the "remove all tags" button.
class _RemoveTagsPainter extends CustomPainter {
  const _RemoveTagsPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    final tag = Path()
      ..moveTo(w * 0.12, h * 0.5)
      ..lineTo(w * 0.42, h * 0.2)
      ..lineTo(w * 0.86, h * 0.2)
      ..lineTo(w * 0.86, h * 0.8)
      ..lineTo(w * 0.42, h * 0.8)
      ..close();
    canvas
      ..drawPath(tag, paint)
      ..drawCircle(Offset(w * 0.5, h * 0.5), 1.2, paint)
      ..drawLine(Offset(w * 0.1, h * 0.95), Offset(w * 0.9, h * 0.05), paint);
  }

  @override
  bool shouldRepaint(_RemoveTagsPainter old) => old.color != color;
}

class _PlusPainter extends CustomPainter {
  const _PlusPainter(this.color, this.arm);
  final Color color;
  final double arm;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final c = size.center(Offset.zero);
    canvas
      ..drawLine(c - Offset(arm / 2, 0), c + Offset(arm / 2, 0), paint)
      ..drawLine(c - Offset(0, arm / 2), c + Offset(0, arm / 2), paint);
  }

  @override
  bool shouldRepaint(_PlusPainter old) => old.color != color;
}

/// The emoji picker (provisional, emoji_data.dart): a search field, the frequently used emoji and
/// the categories in a grid of 6 columns, a category bar at the bottom. [onPick] gets the emoji.
class EmojiPicker extends StatefulWidget {
  const EmojiPicker({super.key, required this.onPick});

  final ValueChanged<String> onPick;

  @override
  State<EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends State<EmojiPicker> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();
  late final List<GlobalKey> _sections = List.generate(
    emojiCategories.length + 1,
    (_) => GlobalKey(),
  );

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // The emoji picker is dark only in the reference (light is not measured): light follows the
  // popover's colours.
  _Palette get _p =>
      _Palette(AmalfiTheme.of(context).isDark, AmalfiTheme.of(context).colors);

  String _title(int i) => switch (i) {
    0 => l10n.emojiFrequent,
    1 => l10n.emojiSmileys,
    2 => l10n.emojiAnimals,
    3 => l10n.emojiFood,
    4 => l10n.emojiActivity,
    5 => l10n.emojiTravel,
    6 => l10n.emojiObjects,
    7 => l10n.emojiSymbols,
    _ => l10n.emojiFlags,
  };

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final searching = _query.text.trim().isNotEmpty;
    final found = searching ? searchEmoji(_query.text) : const <EmojiItem>[];
    final seen = <String>{};
    final unique = [
      for (final e in found)
        if (seen.add(e.emoji)) e.emoji,
    ];
    return SizedBox(
      width: emojiPopoverSize.width,
      height: emojiPopoverSize.height,
      child: Column(
        children: [
          Padding(padding: const EdgeInsets.all(10), child: _searchField(p)),
          Expanded(
            child: searching
                ? (unique.isEmpty
                      ? Center(
                          child: Text(
                            l10n.emojiNone,
                            style: _text(p.secondary),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [_grid(unique)],
                        ))
                : SingleChildScrollView(
                    key: const ValueKey('emoji grid'),
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i <= emojiCategories.length; i++)
                          Column(
                            key: _sections[i],
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 4,
                                ),
                                child: Text(
                                  _title(i),
                                  style: _text(
                                    p.secondary,
                                    size: 11,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _grid(
                                i == 0
                                    ? frequentEmoji
                                    : [
                                        for (final e
                                            in emojiCategories[i - 1].items)
                                          e.emoji,
                                      ],
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
          Container(height: 1, color: p.line),
          SizedBox(
            height: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i <= emojiCategories.length; i++)
                  GestureDetector(
                    key: ValueKey('emoji category $i'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _query.clear();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final ctx = _sections[i].currentContext;
                        if (ctx != null) {
                          Scrollable.ensureVisible(
                            ctx,
                            duration: Duration.zero,
                          );
                        }
                      });
                    },
                    child: SizedBox(
                      width: 30,
                      height: 36,
                      child: Center(
                        child: Text(
                          i == 0 ? '🕘' : emojiCategories[i - 1].icon,
                          style: _text(p.text, size: 16),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(List<String> emoji) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 6,
      mainAxisExtent: 44,
    ),
    itemCount: emoji.length,
    itemBuilder: (context, i) => GestureDetector(
      key: ValueKey('emoji ${emoji[i]}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onPick(emoji[i]),
      child: Center(child: Text(emoji[i], style: _text(_p.text, size: 32))),
    ),
  );

  Widget _searchField(_Palette p) => Container(
    key: const ValueKey('emoji search'),
    width: 300,
    height: 28,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      color: p.button,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Stack(
      alignment: Alignment.centerLeft,
      children: [
        ValueListenableBuilder(
          valueListenable: _query,
          builder: (context, value, _) => value.text.isEmpty
              ? Text(l10n.emojiSearch, style: _text(p.secondary))
              : const SizedBox.shrink(),
        ),
        DefaultTextEditingShortcuts(
          child: EditableText(
            controller: _query,
            focusNode: _focus,
            autofocus: true,
            style: _text(p.text),
            cursorColor: p.text,
            backgroundCursorColor: p.text,
            selectionColor: p.tokens.accentAmalfiSoft,
            maxLines: 1,
            onSubmitted: (_) {},
          ),
        ),
      ],
    ),
  );
}
