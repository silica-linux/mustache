// The toolbar unified with the window (MU-02, docs/spec/toolbar.md): 52 tall from the top, right of
// the sidebar, without a background; Ossido puts the window buttons on top (silica-window-v1).
// Back/Forward capsule (75), title 12 pt after it, view group (162) and Search (38 pt circle) on
// the right, 7–8 pt between capsules. The empty space moves the window.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:silica_ui/silica_ui.dart';

import 'model.dart';

/// Minimum width of the title (spec/toolbar.md).
const double toolbarTitleMin = 160;

/// The window buttons end at x 79 (centers 26/49/72, diameter 14): with the sidebar hidden the
/// toolbar starts here.
const double windowButtonsEnd = 80;

class MustacheToolbar extends StatefulWidget {
  const MustacheToolbar({
    super.key,
    required this.leading,
    required this.title,
    required this.active,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.view,
    required this.onView,
    required this.onSearch,
    this.searchField,
    this.iconsDir,
    this.background,
    this.onBackHistory,
    this.onForwardHistory,
  });

  /// The bar background; in dark, with the pointer in the bar, `#2e3030` (MU-07).
  final Color? background;

  /// Long press on Back / Forward: the history menu, with its top-left corner on the left edge of
  /// the segment, 2 pt above the bottom of the capsule (MU-07).
  final ValueChanged<Offset>? onBackHistory;
  final ValueChanged<Offset>? onForwardHistory;

  /// The space on the left before the first capsule.
  final double leading;
  final String title;

  /// Active window: dark title.
  final bool active;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;

  /// The chosen view (null: no view group, as in search).
  final ViewMode? view;
  final ValueChanged<ViewMode> onView;
  final VoidCallback onSearch;

  /// The search field in place of the Search circle.
  final Widget? searchField;
  final String? iconsDir;

  @override
  State<MustacheToolbar> createState() => _MustacheToolbarState();
}

class _MustacheToolbarState extends State<MustacheToolbar> {
  bool _hovered = false;

  /// Opens the history menu below segment `index` (0 Back, 1 Forward), at the segment's corner.
  void _history(int index, Rect rect) {
    final callback = index == 0
        ? widget.onBackHistory
        : widget.onForwardHistory;
    callback?.call(rect.bottomLeft);
  }

  /// The silica-icons symbol in a `side` box (symbols draw the 16–20 glyph within 24: the box is
  /// chosen so the glyph has the toolbar measurements).
  Widget _symbol(String name, double side, String fallback) => SizedBox(
    width: side,
    height: side,
    child: Builder(
      builder: (context) {
        final color = DefaultTextStyle.of(context).style.color;
        final dir = widget.iconsDir;
        final file = dir == null
            ? null
            : File('$dir/symbols/regular/$name.svg');
        if (file != null && file.existsSync()) {
          return SvgPicture.file(
            file,
            fit: BoxFit.contain,
            colorFilter: color == null
                ? null
                : ColorFilter.mode(color, BlendMode.srcIn),
          );
        }
        return Center(
          child: Text(
            fallback,
            style: TextStyle(
              fontFamily: uiFontFamily,
              package: 'silica_ui',
              fontSize: side * 0.6,
              height: 1,
              color: color,
            ),
          ),
        );
      },
    ),
  );

  /// The icon in the segment color.
  Widget Function(Color) _icon(String name, double side, String fallback) =>
      (color) => DefaultTextStyle(
        style: TextStyle(color: color),
        child: _symbol(name, side, fallback),
      );

  @override
  Widget build(BuildContext context) {
    final dark =
        MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: ToolbarScope(
        active: widget.active,
        hovered: _hovered,
        child: ColoredBox(
          color: dark && _hovered && widget.active
              ? const Color(0xFF2E3030)
              : widget.background ?? const Color(0x00000000),
          child: _bar(),
        ),
      ),
    );
  }

  Widget _bar() => WindowDragArea(
    child: SizedBox(
      key: const ValueKey('toolbar'),
      height: toolbarHeight,
      child: LayoutBuilder(
        builder: (context, box) {
          // When shrinking the views go first, then Back/Forward (spec/toolbar.md, R1.7).
          final room = box.maxWidth - widget.leading;
          final views =
              widget.view != null && room >= 75 + 12 + 160 + 162 + 8 + 38;
          final navigation = room >= 75 + 12 + toolbarTitleMin + 38 + 14;
          return Row(
            children: [
              SizedBox(width: widget.leading),
              if (navigation) ...[
                ToolbarCapsule(
                  key: const ValueKey('back and forward'),
                  separators: true,
                  children: [
                    ToolbarSegment(
                      key: const ValueKey('back'),
                      width: 36,
                      enabled: widget.canGoBack,
                      onTap: widget.onBack,
                      onLongPressMenu: widget.onBackHistory == null
                          ? null
                          : (rect) => _history(0, rect),
                      icon: _icon('chevron-left', 24, '‹'),
                    ),
                    ToolbarSegment(
                      key: const ValueKey('forward'),
                      width: 36,
                      enabled: widget.canGoForward,
                      onTap: widget.onForward,
                      onLongPressMenu: widget.onForwardHistory == null
                          ? null
                          : (rect) => _history(1, rect),
                      icon: _icon('chevron-right', 24, '›'),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
              // The title does not move the window; the empty space beside it does (MU-08).
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) {},
                    child: Text(
                      widget.title,
                      key: const ValueKey('title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: uiFontFamily,
                        package: 'silica_ui',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: widget.active
                            ? ToolbarColors.of(context).title
                            : ToolbarColors.of(context).titleInactive,
                      ),
                    ),
                  ),
                ),
              ),
              if (views)
                ToolbarCapsule(
                  key: const ValueKey('view group'),
                  children: [
                    for (final (mode, symbol, side, fallback) in const [
                      // Grid 15, list 17 × 12, columns 20 × 15, gallery 19 × 15.
                      (ViewMode.icons, 'square-grid-2x2', 20.0, '▦'),
                      (ViewMode.list, 'list-bullet', 24.0, '≡'),
                      (ViewMode.columns, 'window-split-3', 24.0, '▥'),
                      (ViewMode.gallery, 'gallery', 24.0, '▭'),
                    ])
                      ToolbarSegment(
                        key: ValueKey('view ${mode.name}'),
                        width: 40,
                        chosen: mode == widget.view,
                        onTap: () => widget.onView(mode),
                        icon: _icon(symbol, side, fallback),
                      ),
                  ],
                ),
              const SizedBox(width: 8),
              widget.searchField ??
                  ToolbarCapsule(
                    key: const ValueKey('search'),
                    children: [
                      ToolbarSegment(
                        width: toolbarCapsuleHeight - 2,
                        onTap: widget.onSearch,
                        icon: _icon('search', 24, '⌕'),
                      ),
                    ],
                  ),
              const SizedBox(width: 7),
            ],
          );
        },
      ),
    ),
  );
}
