// The window's toolbar, split into sections as the regions below it (kit `Apps/Mustache/Toolbar *`,
// components.md): the sidebar section (window controls, sidebar toggle), the content section
// (back and forward, title, view switcher, search) and, with the preview pane open, the preview
// section (search). Flat bars on the window surface, 52 tall; only the controls in them are glass.
// Ossido draws the window buttons on top of the 96 pt controls slot (silica-window-v1).

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'model.dart';
import 'toolbar_layout.dart';

/// The width of the slot the window buttons sit in (`AmalfiToolbarPieceMetrics.controlsWidth`).
const double windowControlsSlot = AmalfiToolbarPieceMetrics.controlsWidth;

/// The width of the search field in the preview section (the 260 pt column less its padding).
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

/// The content section: back and forward, the title and, right of it, the items the width
/// allows (kit `Apps/Mustache/Toolbar/Bar/*`, components.md › "Toolbar width states"): the view
/// group (segments, or a pop-up), Share · Tags · Actions (a capsule, or Share alone beside »,
/// or all in ») and the search (a circle that grows into the field, or the permanent field).
class MustacheToolbar extends StatefulWidget {
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
    required this.showMenu,
    this.galleryEnabled = true,
    this.searchField,
    this.searchOpen = false,
    this.onSearchOpen,
    this.shareEnabled = false,
    this.tagsEnabled = false,
    this.onShare,
    this.onTags,
    this.actions,
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

  /// The chosen view (null: none chosen, as in the search results, which are a list).
  final ViewMode? view;
  final ValueChanged<ViewMode> onView;

  /// Whether the gallery can be chosen (not in dialogs).
  final bool galleryEnabled;

  /// Shows a menu with its top-left corner at the global position (the window's, which gives
  /// the keyboard back when it closes).
  final void Function(Offset position, List<AmalfiMenuEntry> entries) showMenu;

  /// The search field of a given width; null: the search is in the preview section.
  final Widget Function(double width)? searchField;

  /// Whether the field is expanded (focused, holding text or opened by the circle).
  final bool searchOpen;

  /// The circle was pressed: the window opens the field and focuses it.
  final VoidCallback? onSearchOpen;

  /// Share can send the selection somewhere; Tags needs a selection (Actions works without).
  final bool shareEnabled;
  final bool tagsEnabled;

  /// Share and Tags open their popover below `anchor`.
  final ValueChanged<Rect>? onShare;
  final ValueChanged<Rect>? onTags;

  /// The Actions menu (the item menu of the selection, or the folder's).
  final List<AmalfiMenuEntry> Function()? actions;

  /// With the sidebar hidden: the toggle (after the slot of the window buttons) that shows it.
  final VoidCallback? sidebarToggleWhenHidden;

  /// Long press on Back / Forward: the history menu, from the bottom left corner of the segment.
  final ValueChanged<Offset>? onBackHistory;
  final ValueChanged<Offset>? onForwardHistory;

  /// The long press that opened the history menu ends: over the segment (`onButton`) the menu
  /// closes; elsewhere it is a click at `position`.
  final void Function(bool onButton, Offset position)? onHistoryRelease;

  @override
  State<MustacheToolbar> createState() => _MustacheToolbarState();
}

/// Mustache has no grouping of the items yet: the Group item is left out (it works or it is
/// not there); the states follow the table without it.
const bool toolbarHasGroup = false;

const List<(ViewMode, String)> _viewModes = [
  (ViewMode.icons, 'square-grid-2x2'),
  (ViewMode.list, 'list-bullet'),
  (ViewMode.columns, 'window-split-3'),
  (ViewMode.gallery, 'gallery'),
];

class _MustacheToolbarState extends State<MustacheToolbar> {
  ToolbarLayout? _layout;
  final GlobalKey _popUpKey = GlobalKey();
  final GlobalKey _capsuleKey = GlobalKey();
  final GlobalKey _shareKey = GlobalKey();
  final GlobalKey _overflowKey = GlobalKey();

  Rect _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return Rect.zero;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// The i-th of the three equal parts of the capsule.
  Rect _segment(int i) {
    final r = _rectOf(_capsuleKey);
    final w = r.width / 3;
    return Rect.fromLTWH(r.left + w * i, r.top, w, r.height);
  }

  String _viewLabel(ViewMode mode) => switch (mode) {
    ViewMode.icons => l10n.viewIcons,
    ViewMode.list => l10n.viewList,
    ViewMode.columns => l10n.viewColumns,
    ViewMode.gallery => l10n.viewGallery,
  };

  List<AmalfiMenuEntry> _viewEntries() => [
    for (final (mode, _) in _viewModes)
      AmalfiMenuAction(
        _viewLabel(mode),
        checked: widget.view == mode,
        enabled: mode != ViewMode.gallery || widget.galleryEnabled,
        onSelected: () => widget.onView(mode),
      ),
  ];

  List<AmalfiMenuEntry> _actions() => widget.actions?.call() ?? const [];

  /// The view pop-up: the menu puts the current item over the button.
  void _openViewMenu() {
    final r = _rectOf(_popUpKey);
    final index = _viewModes.indexWhereOrZero(widget.view);
    widget.showMenu(
      Offset(
        r.left - 4,
        r.top +
            (r.height - AmalfiMenuMetrics.itemHeight) / 2 -
            AmalfiMenuMetrics.padding -
            index * AmalfiMenuMetrics.itemHeight,
      ),
      _viewEntries(),
    );
  }

  void _openActions(Rect anchor) =>
      widget.showMenu(anchor.bottomLeft + const Offset(0, 4), _actions());

  void _openShare(Rect anchor) {
    if (widget.shareEnabled) widget.onShare?.call(anchor);
  }

  void _openTags(Rect anchor) {
    if (widget.tagsEnabled) widget.onTags?.call(anchor);
  }

  /// The » menu: what left the bar, in bar order; menu buttons as submenus.
  void _openOverflow(ToolbarLayout layout) {
    final anchor = _rectOf(_overflowKey);
    widget.showMenu(anchor.bottomLeft + const Offset(0, 4), [
      if (layout.viewInOverflow)
        AmalfiMenuAction(l10n.view, submenu: _viewEntries()),
      if (layout.shareInOverflow)
        AmalfiMenuAction(
          l10n.shareLabel,
          enabled: widget.shareEnabled && widget.onShare != null,
          onSelected: () => _openShare(anchor),
        ),
      if (layout.tagsActionsInOverflow) ...[
        AmalfiMenuAction(
          l10n.tagsMenu,
          enabled: widget.tagsEnabled && widget.onTags != null,
          onSelected: () => _openTags(anchor),
        ),
        AmalfiMenuAction(l10n.toolbarActions, submenu: _actions()),
      ],
    ]);
  }

  Widget _nav(BuildContext context) => Builder(
    builder: (context) => GestureDetector(
      key: const ValueKey('back and forward'),
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (d) {
        // The two segments: the press is in the left or the right one.
        final box = context.findRenderObject()! as RenderBox;
        final index = d.localPosition.dx < box.size.width / 2 ? 0 : 1;
        final callback = index == 0
            ? widget.onBackHistory
            : widget.onForwardHistory;
        callback?.call(
          box.localToGlobal(
            Offset(index * box.size.width / 2, box.size.height),
          ),
        );
      },
      onLongPressEnd: (d) {
        final box = context.findRenderObject()! as RenderBox;
        widget.onHistoryRelease?.call(
          box.size.contains(d.localPosition),
          d.globalPosition,
        );
      },
      child: AmalfiActionSegments(
        segments: [
          AmalfiSegment.icon(
            AmalfiGlyph(AmalfiGlyphs.chevronLeft),
            semanticLabel: l10n.menuBack,
            enabled: widget.canGoBack,
          ),
          AmalfiSegment.icon(
            AmalfiGlyph(AmalfiGlyphs.chevronRight),
            semanticLabel: l10n.menuForward,
            enabled: widget.canGoForward,
          ),
        ],
        onPressed: (i) => i == 0 ? widget.onBack() : widget.onForward(),
      ),
    ),
  );

  Widget _views() {
    final view = widget.view;
    return AmalfiSegmentedControl(
      key: const ValueKey('view group'),
      size: AmalfiControlSize.large,
      toolbar: true,
      selected: {
        for (var i = 0; i < _viewModes.length; i++)
          if (_viewModes[i].$1 == view) i,
      },
      onChanged: (s) {
        if (s.isNotEmpty) widget.onView(_viewModes[s.first].$1);
      },
      segments: [
        for (final (mode, symbol) in _viewModes)
          AmalfiSegment.icon(
            symbolGlyph(symbol, size: 20),
            semanticLabel: _viewLabel(mode),
            enabled: mode != ViewMode.gallery || widget.galleryEnabled,
          ),
      ],
    );
  }

  Widget _viewPopUp() {
    final symbol = _viewModes
        .firstWhere(
          (m) => m.$1 == (widget.view ?? ViewMode.list),
          orElse: () => _viewModes[1],
        )
        .$2;
    return ToolbarPopUp(
      key: _popUpKey,
      semanticLabel: l10n.view,
      glyph: symbolGlyph(symbol, size: 20),
      chevron: 'chevron-up-down',
      onOpen: _openViewMenu,
    );
  }

  Widget _capsule() => KeyedSubtree(
    key: _capsuleKey,
    child: AmalfiActionSegments(
      key: const ValueKey('share tags actions'),
      segments: [
        AmalfiSegment.icon(
          AmalfiGlyph(AmalfiGlyphs.share),
          semanticLabel: l10n.shareLabel,
          enabled: widget.shareEnabled && widget.onShare != null,
        ),
        AmalfiSegment.icon(
          symbolGlyph('tag', size: 20),
          semanticLabel: l10n.toolbarTags,
          enabled: widget.tagsEnabled && widget.onTags != null,
        ),
        AmalfiSegment.icon(
          symbolGlyph('ellipsis', size: 20),
          semanticLabel: l10n.toolbarActions,
          enabled: widget.actions != null,
        ),
      ],
      onPressed: (i) => switch (i) {
        0 => _openShare(_segment(0)),
        1 => _openTags(_segment(1)),
        _ => _openActions(_segment(2)),
      },
    ),
  );

  Widget _shareAlone() => AmalfiToolbarButton(
    key: _shareKey,
    icon: AmalfiGlyph(AmalfiGlyphs.share),
    onPressed: widget.shareEnabled && widget.onShare != null
        ? () => _openShare(_rectOf(_shareKey))
        : null,
    semanticLabel: l10n.shareLabel,
  );

  Widget _overflow(ToolbarLayout layout) => AmalfiToolbarButton(
    key: _overflowKey,
    icon: const _DoubleChevron(),
    onPressed: () => _openOverflow(layout),
    semanticLabel: l10n.toolbarMore,
  );

  @override
  Widget build(BuildContext context) => WindowDragArea(
    child: LayoutBuilder(
      builder: (context, box) {
        // The toolbar's own width: right of the window buttons when the sidebar is hidden.
        final hidden = widget.sidebarToggleWhenHidden != null;
        final width =
            box.maxWidth - (hidden ? windowControlsSlot - 12 + 44 : 0);
        final search = widget.searchField != null;
        final layout = _layout = resolveToolbarLayout(
          width,
          previous: _layout,
          searchOpen: widget.searchOpen,
          hasGroup: toolbarHasGroup,
          search: search,
        );
        final field = layout.permanentSearch
            ? permanentSearchWidth(
                width,
                hasGroup: toolbarHasGroup,
                filled: widget.searchOpen,
              )
            : openSearchWidth(width);
        // A focused field in the Wide state that does not leave room collapses the views.
        final popUp =
            layout.viewPopUp ||
            (layout.permanentSearch &&
                widget.searchOpen &&
                field >
                    permanentSearchWidth(width, hasGroup: toolbarHasGroup) &&
                width <
                    toolbarStageWidth(
                      ToolbarStage.full,
                      searchOpen: true,
                      group: toolbarHasGroup,
                      search: true,
                    ));
        return AmalfiToolbar.section(
          key: const ValueKey('toolbar'),
          active: widget.active,
          children: [
            if (widget.sidebarToggleWhenHidden case final toggle?) ...[
              const SizedBox(width: windowControlsSlot - 12),
              sidebarToggle(toggle),
            ],
            AmalfiToolbarPiece(child: _nav(context)),
            // The title and the empty space beside it move the window (silica-ui#96).
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: AmalfiTitlePiece(
                      key: const ValueKey('title'),
                      title: widget.title,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            if (layout.viewSegments && !popUp)
              AmalfiToolbarPiece(child: _views()),
            if (popUp) AmalfiToolbarPiece(child: _viewPopUp()),
            if (layout.capsule)
              AmalfiToolbarPiece(child: _capsule())
            else if (layout.shareAlone)
              AmalfiToolbarPiece(child: _shareAlone()),
            if (layout.overflow) AmalfiToolbarPiece(child: _overflow(layout)),
            if (widget.searchField case final build?)
              AmalfiToolbarPiece(
                child: layout.permanentSearch
                    ? KeyedSubtree(
                        key: const ValueKey('permanent search'),
                        child: build(field),
                      )
                    : ToolbarSearchSlot(
                        open: widget.searchOpen,
                        width: field,
                        onOpen: widget.onSearchOpen ?? () {},
                        semanticLabel: l10n.searchPlaceholder,
                        field: build,
                      ),
              ),
            // The kit's trailing 16 (the section gives 12 and the piece 4).
            const SizedBox(width: 4),
          ],
        );
      },
    ),
  );
}

extension on List<(ViewMode, String)> {
  int indexWhereOrZero(ViewMode? mode) {
    final i = indexWhere((m) => m.$1 == mode);
    return i < 0 ? 0 : i;
  }
}

/// » : two chevrons side by side (kit `Piece/Overflow`).
class _DoubleChevron extends StatelessWidget {
  const _DoubleChevron();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 20,
    height: 20,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(left: -3, child: symbolGlyph('chevron-right', size: 20)),
        Positioned(left: 3, child: symbolGlyph('chevron-right', size: 20)),
      ],
    ),
  );
}

/// A toolbar pop-up (kit `View Pop-up`, `Group`): a 56 × 36 glass capsule with a glyph and a
/// small chevron; the menu opens as the pointer goes down.
class ToolbarPopUp extends StatefulWidget {
  const ToolbarPopUp({
    super.key,
    required this.glyph,
    required this.chevron,
    required this.onOpen,
    required this.semanticLabel,
  });

  /// The width of the pop-up (kit `View Pop-up`).
  static const double width = 56;

  final Widget glyph;

  /// The symbol of the chevron (`chevron-up-down`, `chevron-down`).
  final String chevron;
  final VoidCallback onOpen;
  final String semanticLabel;

  @override
  State<ToolbarPopUp> createState() => _ToolbarPopUpState();
}

class _ToolbarPopUpState extends State<ToolbarPopUp> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    const height = AmalfiToolbarButtonMetrics.side;
    final radius = AmalfiRadii.capsule(height);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      onTap: widget.onOpen,
      child: ExcludeSemantics(
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) {
              setState(() => _pressed = true);
              widget.onOpen();
            },
            onPointerUp: (_) => setState(() => _pressed = false),
            onPointerCancel: (_) => setState(() => _pressed = false),
            child: SizedBox(
              width: ToolbarPopUp.width,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AmalfiGlass(
                      material: AmalfiMaterials.regular,
                      radius: radius,
                      kind: AmalfiGlassKind.control,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  if (_hovered || _pressed)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: AmalfiShapeDecoration(
                          color: _pressed
                              ? colors.lineBorder
                              : colors.lineSeparator,
                          shape: AmalfiSmoothBorder(radius: radius),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 10,
                    top: (height - 20) / 2,
                    child: IconTheme(
                      data: IconThemeData(color: colors.textPrimary, size: 20),
                      child: widget.glyph,
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: (height - 12) / 2,
                    child: symbolGlyph(
                      widget.chevron,
                      size: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The search item: the 36 pt circle, which on a press grows into the field (36 → 240 in
/// ~160 ms, ease-out) and back (240 → 36 in ~190 ms) when [open] ends.
class ToolbarSearchSlot extends StatefulWidget {
  const ToolbarSearchSlot({
    super.key,
    required this.open,
    required this.width,
    required this.onOpen,
    required this.semanticLabel,
    required this.field,
  });

  final bool open;

  /// The field's width when open.
  final double width;
  final VoidCallback onOpen;
  final String semanticLabel;
  final Widget Function(double width) field;

  @override
  State<ToolbarSearchSlot> createState() => _ToolbarSearchSlotState();
}

class _ToolbarSearchSlotState extends State<ToolbarSearchSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(
    vsync: this,
    value: widget.open ? 1 : 0,
    duration: const Duration(milliseconds: 160),
    reverseDuration: const Duration(milliseconds: 190),
  )..addListener(() => setState(() {}));

  @override
  void didUpdateWidget(ToolbarSearchSlot old) {
    super.didUpdateWidget(old);
    if (widget.open == old.open) return;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _grow.value = widget.open ? 1 : 0;
    } else if (widget.open) {
      _grow.forward();
    } else {
      _grow.reverse();
    }
  }

  @override
  void dispose() {
    _grow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_grow.value == 0 && !widget.open) {
      return AmalfiToolbarButton(
        key: const ValueKey('search button'),
        icon: symbolGlyph('search', size: 20),
        onPressed: widget.onOpen,
        semanticLabel: widget.semanticLabel,
      );
    }
    const closed = AmalfiToolbarButtonMetrics.side;
    // Most of the distance in the first frame: ease-out.
    final t = AmalfiCurves.easeOut.transform(_grow.value.clamp(0, 1));
    final width = closed + (widget.width - closed) * t;
    // The field is laid out at its full width and revealed as the slot grows.
    return SizedBox(
      key: const ValueKey('search field slot'),
      width: width,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerRight,
          minWidth: widget.width,
          maxWidth: widget.width,
          child: widget.field(widget.width),
        ),
      ),
    );
  }
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
