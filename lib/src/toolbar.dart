// The window's toolbar, split into sections as the regions below it (kit `Apps/Mustache/Toolbar *`,
// components.md): the sidebar section (window controls, sidebar toggle), the content section
// (back and forward, title, view switcher, search) and, with the preview pane open, the preview
// section (search). Flat bars on the window surface, 52 tall; only the controls in them are glass.
// Ossido draws the window buttons on top of the 96 pt controls slot (silica-window-v1).

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'model.dart';

/// The width of the slot the window buttons sit in (`AmalfiToolbarPieceMetrics.controlsWidth`).
const double windowControlsSlot = AmalfiToolbarPieceMetrics.controlsWidth;

/// The narrowest room (after the window controls) in which the view switcher still fits next to
/// back/forward and a title: the switcher goes first when the window narrows.
const double toolbarViewsMinRoom = 12 + 72 + 160 + 144 + 8;

/// The width of the search field in the content section (a large field, kit `Piece/Search`) and
/// in the preview section (the 260 pt column less its padding, no Share button beside it).
const double toolbarSearchWidth = 200;
const double previewSearchWidth = 232;

/// The glyph of an Icon Kit symbol installed with silica-icons (`symbols/regular`); empty when
/// it is not installed.
Widget symbolGlyph(String name, {double? size, Color? color}) =>
    AmalfiSymbol(name, size: size, color: color);

/// The sidebar section of the toolbar, a blur strip with the sidebar's edge over the full-height
/// sidebar: the slot of the window buttons, then the sidebar toggle.
class MustacheSidebarBar extends StatelessWidget {
  const MustacheSidebarBar({
    super.key,
    required this.active,
    required this.onToggle,
  });

  final bool active;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => WindowDragArea(
    child: AmalfiToolbar.sidebarSection(
      key: const ValueKey('sidebar bar'),
      surface: AmalfiToolbarSurface.blur,
      edge: true,
      active: active,
      children: [
        const SizedBox(width: windowControlsSlot),
        const AmalfiSpacerPiece(),
        sidebarToggle(onToggle),
      ],
    ),
  );
}

/// The sidebar toggle piece (kit `Piece/Sidebar Toggle`).
Widget sidebarToggle(VoidCallback onToggle) => AmalfiToolbarPiece(
  key: const ValueKey('sidebar toggle'),
  child: AmalfiToolbarButton(
    icon: AmalfiGlyph(AmalfiGlyphs.sidebar),
    onPressed: onToggle,
    semanticLabel: l10n.toggleSidebar,
  ),
);

/// The content section: back and forward, the title, the view switcher and (without the preview
/// section) the search field.
class MustacheToolbar extends StatelessWidget {
  const MustacheToolbar({
    super.key,
    required this.title,
    required this.active,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.view,
    required this.onView,
    this.search,
    this.sidebarToggleWhenHidden,
    this.onBackHistory,
    this.onForwardHistory,
    this.onHistoryRelease,
  });

  final String title;

  /// Active window: dark title.
  final bool active;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;

  /// The chosen view (null: no view switcher, as in search).
  final ViewMode? view;
  final ValueChanged<ViewMode> onView;

  /// The search field (a piece); null: it is in the preview section.
  final Widget? search;

  /// With the sidebar hidden: the toggle (after the slot of the window buttons) that shows it.
  final VoidCallback? sidebarToggleWhenHidden;

  /// Long press on Back / Forward: the history menu, from the bottom left corner of the segment.
  final ValueChanged<Offset>? onBackHistory;
  final ValueChanged<Offset>? onForwardHistory;

  /// The long press that opened the history menu ends: over the segment (`onButton`) the menu
  /// closes; elsewhere it is a click at `position`.
  final void Function(bool onButton, Offset position)? onHistoryRelease;

  Widget _nav(BuildContext context) => Builder(
    builder: (context) => GestureDetector(
      key: const ValueKey('back and forward'),
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (d) {
        // The two 32 pt segments: the press is in the left or the right one.
        final box = context.findRenderObject()! as RenderBox;
        final index = d.localPosition.dx < box.size.width / 2 ? 0 : 1;
        final callback = index == 0 ? onBackHistory : onForwardHistory;
        callback?.call(
          box.localToGlobal(Offset(index * 32.0, box.size.height)),
        );
      },
      onLongPressEnd: (d) {
        final box = context.findRenderObject()! as RenderBox;
        onHistoryRelease?.call(
          box.size.contains(d.localPosition),
          d.globalPosition,
        );
      },
      child: AmalfiActionSegments(
        segments: [
          AmalfiSegment.icon(
            AmalfiGlyph(AmalfiGlyphs.chevronLeft),
            semanticLabel: l10n.menuBack,
            enabled: canGoBack,
          ),
          AmalfiSegment.icon(
            AmalfiGlyph(AmalfiGlyphs.chevronRight),
            semanticLabel: l10n.menuForward,
            enabled: canGoForward,
          ),
        ],
        onPressed: (i) => i == 0 ? onBack() : onForward(),
      ),
    ),
  );

  Widget _views() {
    const modes = [
      (ViewMode.icons, 'square-grid-2x2'),
      (ViewMode.list, 'list-bullet'),
      (ViewMode.columns, 'window-split-3'),
      (ViewMode.gallery, 'gallery'),
    ];
    String label(ViewMode mode) => switch (mode) {
      ViewMode.icons => l10n.viewIcons,
      ViewMode.list => l10n.viewList,
      ViewMode.columns => l10n.viewColumns,
      ViewMode.gallery => l10n.viewGallery,
    };
    return AmalfiSegmentedControl(
      key: const ValueKey('view group'),
      size: AmalfiControlSize.large,
      selected: {
        for (var i = 0; i < modes.length; i++)
          if (modes[i].$1 == view) i,
      },
      onChanged: (s) {
        if (s.isNotEmpty) onView(modes[s.first].$1);
      },
      segments: [
        for (final (mode, symbol) in modes)
          AmalfiSegment.icon(
            symbolGlyph(symbol, size: 16),
            semanticLabel: label(mode),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => WindowDragArea(
    child: LayoutBuilder(
      builder: (context, box) {
        final room = box.maxWidth - 12 - 8;
        final views = view != null && room >= toolbarViewsMinRoom;
        return AmalfiToolbar.section(
          key: const ValueKey('toolbar'),
          active: active,
          children: [
            if (sidebarToggleWhenHidden case final toggle?) ...[
              const SizedBox(width: windowControlsSlot - 12),
              sidebarToggle(toggle),
            ],
            AmalfiToolbarPiece(child: _nav(context)),
            // The title does not move the window; the empty space beside it does (MU-08).
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: GestureDetector(
                      key: const ValueKey('title'),
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) {},
                      child: AmalfiTitlePiece(title: title),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            if (views) AmalfiToolbarPiece(child: _views()),
            ?search,
          ],
        );
      },
    ),
  );
}

/// The preview section (kit `Toolbar Preview`): the search field over the preview pane.
class MustachePreviewBar extends StatelessWidget {
  const MustachePreviewBar({
    super.key,
    required this.active,
    required this.search,
  });

  final bool active;
  final Widget search;

  @override
  Widget build(BuildContext context) => WindowDragArea(
    child: AmalfiToolbar.section(
      key: const ValueKey('preview bar'),
      active: active,
      surface: AmalfiToolbarSurface.sidebar,
      children: [search],
    ),
  );
}
