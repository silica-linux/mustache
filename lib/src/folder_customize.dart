// The Customize Folder section of Get Info (folders only): a row of colour swatches (none, the
// seven colour names, a custom #rrggbb), a searchable grid of silica-icons symbols and Reset.
// Choices are saved on the folder at once (folder_style.dart) and every folder icon redraws.
//
// Provisional until the reference is measured (every value below is estimated, see
// docs/spec/info.md › Customize Folder): swatch 16 pt at a 22 pt pitch with a 2 pt selection ring
// 1.5 pt out; symbol cells 28 pt, 8 per row, 4 rows visible (scrolls), glyph 18 pt, selected cell
// with a 6 pt-radius tint of the link colour at 20%; fields 22 pt tall; Reset as a link-coloured
// text button.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:silica_ui/silica_ui.dart';

import 'folder_style.dart';
import 'info.dart' show InfoColors;
import 'l10n.dart';
import 'tags.dart';

/// Swatch side and pitch (provisional).
const double folderSwatchSide = 16;
const double folderSwatchPitch = 22;

/// Symbol grid cell, columns and visible rows (provisional).
const double folderSymbolCell = 28;
const int folderSymbolColumns = 8;
const int folderSymbolRows = 4;

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

/// `symbols/` of the silica-icons folder icon, or null.
String? folderSymbolsDir({Map<String, String>? env}) {
  final dyn = findSilicaIcon('folder-generic', env: env)?.dynamic;
  return dyn is FolderSymbol ? dyn.symbolsDir : null;
}

/// The colour a tint name or `#rrggbb` is drawn with in the swatches.
Color? swatchColor(
  String? tint, {
  Map<String, String>? env,
  bool dark = false,
}) {
  if (tint == null) return null;
  final dyn = findSilicaIcon('folder-generic', env: env)?.dynamic;
  if (dyn is FolderSymbol) {
    final c = dyn.tintFor(tint);
    if (c != null) return c;
  }
  for (final c in TagColor.values) {
    if (c.name == tint) return sidebarTagColor(c, dark: dark);
  }
  if (validTint(tint)) {
    return Color(int.parse('ff${tint.substring(1)}', radix: 16));
  }
  return null;
}

class FolderCustomizeSection extends StatefulWidget {
  const FolderCustomizeSection({
    super.key,
    required this.path,
    this.env,
    this.styles,
  });

  final String path;
  final Map<String, String>? env;

  /// The styles to read and save (the app's by default).
  final FolderStyles? styles;

  @override
  State<FolderCustomizeSection> createState() => _FolderCustomizeSectionState();
}

class _FolderCustomizeSectionState extends State<FolderCustomizeSection> {
  FolderStyles get _styles => widget.styles ?? folderStyles;
  late FolderStyle _style = _styles.stored(widget.path) ?? const FolderStyle();
  final TextEditingController _query = TextEditingController();
  final TextEditingController _hex = TextEditingController();
  final FocusNode _queryFocus = FocusNode();
  final FocusNode _hexFocus = FocusNode();
  bool _hexShown = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _styles.addListener(_reload);
    _query.addListener(() => setState(() {}));
    _hexShown = _style.tint?.startsWith('#') ?? false;
    _hex.text = _hexShown ? _style.tint! : '';
  }

  @override
  void didUpdateWidget(FolderCustomizeSection old) {
    super.didUpdateWidget(old);
    if (old.styles != widget.styles) {
      (old.styles ?? folderStyles).removeListener(_reload);
      _styles.addListener(_reload);
    }
    if (old.path != widget.path || old.styles != widget.styles) _reload();
  }

  @override
  void dispose() {
    _styles.removeListener(_reload);
    _query.dispose();
    _hex.dispose();
    _queryFocus.dispose();
    _hexFocus.dispose();
    super.dispose();
  }

  /// Changed elsewhere (another window, the shell, another app): show what is on disk.
  void _reload() {
    if (!mounted) return;
    final style = _styles.stored(widget.path) ?? const FolderStyle();
    if (style != _style) setState(() => _style = style);
  }

  void _apply(FolderStyle style) {
    final ok = _styles.save(widget.path, style);
    setState(() {
      _failed = !ok;
      if (ok) _style = style;
    });
  }

  InfoColors get _c => InfoColors.of(context);
  bool get _dark =>
      MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark;

  TextStyle _text({Color? color, double size = 11}) => TextStyle(
    fontFamily: uiFontFamily,
    package: 'silica_ui',
    fontSize: size,
    color: color ?? _c.text,
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.folderColor, style: _text(color: _c.secondary)),
        const SizedBox(height: 4),
        _swatches(),
        if (_hexShown) ...[
          const SizedBox(height: 6),
          _field(
            _hex,
            _hexFocus,
            key: 'folder tint field',
            placeholder: l10n.folderCustomColor,
            onSubmitted: (value) {
              var v = value.trim().toLowerCase();
              if (!v.startsWith('#')) v = '#$v';
              if (validTint(v) && v.length == 7) _apply(_style.withTint(v));
            },
          ),
        ],
        const SizedBox(height: 8),
        Text(l10n.folderSymbol, style: _text(color: _c.secondary)),
        const SizedBox(height: 4),
        _field(
          _query,
          _queryFocus,
          key: 'folder symbol search',
          placeholder: l10n.folderSymbolSearch,
          onSubmitted: (_) {},
        ),
        const SizedBox(height: 4),
        _symbols(),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _failed
                  ? Text(
                      l10n.folderStyleError,
                      key: const ValueKey('folder style error'),
                      style: _text(color: const Color(0xFFE0443E)),
                    )
                  : const SizedBox.shrink(),
            ),
            GestureDetector(
              key: const ValueKey('folder reset'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _hex.clear();
                setState(() => _hexShown = false);
                _apply(const FolderStyle());
              },
              child: Text(l10n.folderReset, style: _text(color: _c.link)),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _swatches() {
    final tint = _style.tint;
    final custom = tint != null && tint.startsWith('#');
    return Row(
      children: [
        _swatch(
          'none',
          selected: tint == null,
          child: CustomPaint(
            size: const Size.square(folderSwatchSide),
            painter: _NonePainter(_c.secondary),
          ),
          onTap: () {
            setState(() => _hexShown = false);
            _apply(_style.withTint(null));
          },
        ),
        for (final c in TagColor.values)
          _swatch(
            c.name,
            selected: tint == c.name,
            child: _disc(swatchColor(c.name, env: widget.env, dark: _dark)),
            onTap: () {
              setState(() => _hexShown = false);
              _apply(_style.withTint(c.name));
            },
          ),
        _swatch(
          'custom',
          selected: custom,
          child: custom
              ? _disc(swatchColor(tint, env: widget.env))
              : Container(
                  width: folderSwatchSide,
                  height: folderSwatchSide,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Color(0xFFFF3B30),
                        Color(0xFFFFCC00),
                        Color(0xFF34C759),
                        Color(0xFF007AFF),
                        Color(0xFFAF52DE),
                        Color(0xFFFF3B30),
                      ],
                    ),
                  ),
                ),
          onTap: () {
            setState(() => _hexShown = true);
            _hexFocus.requestFocus();
          },
        ),
      ],
    );
  }

  Widget _disc(Color? color) => Container(
    width: folderSwatchSide,
    height: folderSwatchSide,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      border: color == null ? null : Border.all(color: tagRing(color)),
    ),
  );

  Widget _swatch(
    String name, {
    required bool selected,
    required Widget child,
    required VoidCallback onTap,
  }) => GestureDetector(
    key: ValueKey('folder tint $name'),
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: SizedBox(
      width: folderSwatchPitch,
      height: folderSwatchPitch,
      child: Center(
        child: Container(
          width: folderSwatchSide + 7,
          height: folderSwatchSide + 7,
          alignment: Alignment.center,
          decoration: selected
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _c.text, width: 2),
                )
              : null,
          child: child,
        ),
      ),
    ),
  );

  Widget _symbols() {
    final dir = folderSymbolsDir(env: widget.env);
    final query = _query.text.trim().toLowerCase().replaceAll(' ', '-');
    final names = [
      for (final n in folderSymbolNames(env: widget.env))
        if (query.isEmpty || n.contains(query)) n,
    ];
    final cells = [if (query.isEmpty) null, ...names];
    const height = folderSymbolCell * folderSymbolRows;
    if (dir == null || names.isEmpty) {
      return SizedBox(
        height: folderSymbolCell,
        child: Center(
          child: Text(l10n.folderNoSymbols, style: _text(color: _c.secondary)),
        ),
      );
    }
    final rows = (cells.length / folderSymbolColumns).ceil();
    return SizedBox(
      height: math.min(height, rows * folderSymbolCell),
      child: GridView.builder(
        key: const ValueKey('folder symbols'),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: folderSymbolColumns,
          mainAxisExtent: folderSymbolCell,
        ),
        itemCount: cells.length,
        itemBuilder: (context, i) {
          final name = cells[i];
          final selected = _style.symbol == name;
          return GestureDetector(
            key: ValueKey('folder symbol ${name ?? 'none'}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _apply(_style.withSymbol(name)),
            child: Container(
              margin: const EdgeInsets.all(1),
              decoration: selected
                  ? BoxDecoration(
                      color: _c.link.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    )
                  : null,
              alignment: Alignment.center,
              child: name == null
                  ? CustomPaint(
                      size: const Size.square(18),
                      painter: _NonePainter(_c.secondary),
                    )
                  : SvgPicture.file(
                      File('$dir/regular/$name.svg'),
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(_c.text, BlendMode.srcIn),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    FocusNode focus, {
    required String key,
    required String placeholder,
    required ValueChanged<String> onSubmitted,
  }) => Container(
    key: ValueKey(key),
    height: 22,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      border: Border.all(color: _c.fieldBorder),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Stack(
      alignment: Alignment.centerLeft,
      children: [
        ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? Text(
                  placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(color: _c.secondary, size: 12),
                )
              : const SizedBox.shrink(),
        ),
        DefaultTextEditingShortcuts(
          child: EditableText(
            controller: controller,
            focusNode: focus,
            style: _text(size: 12),
            cursorColor: _c.text,
            backgroundCursorColor: _c.text,
            selectionColor: const Color(0xFFB3D7FF),
            maxLines: 1,
            onSubmitted: onSubmitted,
            onTapOutside: (_) => focus.unfocus(),
          ),
        ),
      ],
    ),
  );
}

/// "No colour" / "no symbol": a ring with a diagonal bar.
class _NonePainter extends CustomPainter {
  const _NonePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final r = size.shortestSide / 2 - 0.6;
    final c = size.center(Offset.zero);
    canvas
      ..drawCircle(c, r, paint)
      ..drawLine(
        c + Offset(-r, r) * math.sqrt1_2,
        c + Offset(r, -r) * math.sqrt1_2,
        paint,
      );
  }

  @override
  bool shouldRepaint(_NonePainter old) => old.color != color;
}
