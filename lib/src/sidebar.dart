// The sidebar (MU-10, MU-11): attached to the window edges, from top to bottom, without a line
// towards the content. Rows at a 32 pt pitch; 24 pt between the center of a heading and the first
// row, 40 between the last row and the next heading. Selection: a radius 8 rectangle as tall as the
// row, 10 pt from the edge; text in semibold, the icon keeps its color. No background on hover. On
// hover the headings show a 10 × 6 chevron that collapses the section (~190 ms, ease out, from +70
// ms; expansion from +120 ms): the rows drop their text right away and slide up under the heading,
// which clips them.
//
// Width (MU-11): minimum 135 pt, the content does not go below 316; released between 191 and 209 it
// snaps back to 200; dragged closer than ~65 pt to the edge the sidebar hides.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'drag.dart';
import 'model.dart';
import 'tags.dart';

const double sidebarRow = 32;
const double sidebarTextLeft = 47;
const double sidebarIconLeft = 20;
const double sidebarIconSize = 18;
const double sidebarHeadingLeft = 17;
const double sidebarSelectionInset = 10;
const double sidebarSelectionRadius = 8;

/// The first row has its center 68 pt from the top of the window (below the buttons).
const double sidebarFirstRowCenter = 68;

/// Between the center of a heading and that of the first row (MU-10, windows.md).
const double sidebarHeadingToRow = 24;

/// Between the center of the last row and that of the next heading.
const double sidebarRowToHeading = 40;

/// The width of new windows (spec/sidebar.md: 192; 200 is only where it snaps).
const double sidebarDefaultWidth = 192;

/// Where the sidebar snaps when released between 191 and 209 (MU-11).
const double sidebarSnapWidth = 200;
const double sidebarMinWidth = 135;
const double contentMinWidth = 316;

/// Released in this range the sidebar goes back to the default width.
const double sidebarSnapFrom = 191;
const double sidebarSnapTo = 209;

/// Dragged with the pointer closer than this to the left edge, the sidebar hides.
const double sidebarHideBelow = 65;

/// The heading chevron: 10 × 6, 31 pt from the right edge of the sidebar.
const Size sidebarChevron = Size(10, 6);
const double sidebarChevronRight = 31;

/// Collapsing and expanding a section (MU-11): ~190 ms after a delay.
const Duration sectionCollapse = Duration(milliseconds: 255);
const Duration sectionExpand = Duration(milliseconds: 308);
const double sectionCollapseDelay = 70 / 255;
const double sectionExpandDelay = 120 / 308;

/// Hiding and showing the sidebar (⌃⌘S): ~240 / ~230 ms, S curve; showing starts ~40 ms after the
/// key.
const Duration sidebarHide = Duration(milliseconds: 240);
const Duration sidebarShow = Duration(milliseconds: 270);
const double sidebarShowDelay = 40 / 270;

/// Sidebar colors by theme and window state (docs/spec/sidebar.md; values chosen among the measurements, open-questions.md 2–3: the
/// background is a material and depends on what is behind it).
@immutable
class SidebarColors {
  const SidebarColors({
    required this.fill,
    required this.selection,
    required this.text,
    required this.selectedText,
    required this.heading,
    required this.accentIcon,
    required this.plainIcon,
    required this.plainIconSelected,
  });

  final Color fill;
  final Color selection;
  final Color text;
  final Color selectedText;
  final Color heading;
  final Color accentIcon;

  /// The gray icon at rest and under the selection (two different measurements, spec/sidebar.md).
  final Color plainIcon;
  final Color plainIconSelected;

  static SidebarColors of({required bool dark, required bool active}) =>
      switch ((dark, active)) {
        (false, true) => const SidebarColors(
          fill: Color(0xFFECECED),
          selection: Color(0xFFD7D7D7),
          text: Color(0xFF000000),
          selectedText: Color(0xFF000000),
          heading: Color(0xFF808182),
          accentIcon: Color(0xFF0070EB),
          plainIcon: Color(0xFF7C7C82),
          plainIconSelected: Color(0xFF6E6E74),
        ),
        (false, false) => const SidebarColors(
          fill: Color(0xFFF2F2F2),
          selection: Color(0xFFE7E7E7),
          text: Color(0xFF727272),
          selectedText: Color(0xFF676767),
          heading: Color(0xFFA6A6A6),
          accentIcon: Color(0xFF7F7F7F),
          plainIcon: Color(0xFF7F7F7F),
          plainIconSelected: Color(0xFF7F7F7F),
        ),
        (true, true) => const SidebarColors(
          fill: Color(0xFF2A2A2C),
          selection: Color(0xFF464647),
          text: Color(0xFFFFFFFF),
          selectedText: Color(0xFFFFFFFF),
          heading: Color(0xFF7C7D7E),
          accentIcon: Color(0xFF00ABFF),
          plainIcon: Color(0xFFB6B7BD),
          plainIconSelected: Color(0xFFC7C7CD),
        ),
        (true, false) => const SidebarColors(
          fill: Color(0xFF29292A),
          selection: Color(0xFF373738),
          text: Color(0xFF969696),
          selectedText: Color(0xFF9B9B9C),
          heading: Color(0xFF5C5C5D),
          accentIcon: Color(0xFF929293),
          plainIcon: Color(0xFF929293),
          plainIconSelected: Color(0xFF929293),
        ),
      };
}

/// A sidebar section: a title (empty: no heading) and its places.
@immutable
class SidebarSection {
  const SidebarSection(this.title, this.places);
  final String title;
  final List<Place> places;
}

/// The sidebar width after a drag: between the minimum and the maximum that leaves 316 pt to the
/// content; 0 (hidden) with the pointer too close to the edge.
double dragWidth(double pointerX, double windowWidth) {
  if (pointerX < sidebarHideBelow) return 0;
  final max = math.max(sidebarMinWidth, windowWidth - contentMinWidth);
  return pointerX.clamp(sidebarMinWidth, max);
}

/// The width on release: close to 200 it snaps to 200.
double releaseWidth(double width) =>
    width >= sidebarSnapFrom && width <= sidebarSnapTo
    ? sidebarSnapWidth
    : width;

/// The silica-icons symbol for a place.
String symbolFor(PlaceKind kind) => switch (kind) {
  PlaceKind.home => 'house-door',
  PlaceKind.desktop => 'desktop',
  PlaceKind.documents => 'doc',
  PlaceKind.downloads => 'arrow-down-circle',
  PlaceKind.pictures => 'photo-fill',
  PlaceKind.music => 'music-note',
  PlaceKind.videos => 'film',
  PlaceKind.trash => 'trash',
  PlaceKind.tag => '',
};

/// The home folder and the Trash have the gray icon, the other places the accent one.
bool accentIcon(PlaceKind kind) =>
    kind != PlaceKind.home && kind != PlaceKind.trash && kind != PlaceKind.tag;

class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    required this.sections,
    required this.current,
    required this.onSelect,
    required this.colors,
    this.iconsDir,
    this.onDrop,
  });

  /// Dropping dragged items on a place (R2.8): the row turns accent colored.
  final void Function(DragPayload payload, String destination)? onDrop;

  final List<SidebarSection> sections;

  /// The folder shown: its row is selected.
  final String current;
  final ValueChanged<Place> onSelect;
  final SidebarColors colors;
  final String? iconsDir;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> with TickerProviderStateMixin {
  final Map<String, AnimationController> _sections = {};
  String? _hovered;

  AnimationController _controller(String title) => _sections.putIfAbsent(
    title,
    () => AnimationController(
      vsync: this,
      duration: sectionExpand,
      reverseDuration: sectionCollapse,
      value: 1,
    )..addListener(() => setState(() {})),
  );

  @override
  void dispose() {
    for (final controller in _sections.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggle(String title) {
    final controller = _controller(title);
    if (controller.status == AnimationStatus.reverse || controller.value == 0) {
      controller.forward();
    } else {
      controller.reverse();
    }
  }

  bool _collapsing(String title) {
    final controller = _sections[title];
    return controller != null &&
        (controller.status == AnimationStatus.reverse || controller.value == 0);
  }

  /// How much of the section shows (0–1), with the measured delay before the movement.
  double _openness(String title) {
    final controller = _sections[title];
    if (controller == null) return 1;
    final collapsing = _collapsing(title);
    final delay = collapsing ? sectionCollapseDelay : sectionExpandDelay;
    // The time elapsed since the start, as a fraction of the duration.
    final elapsed = collapsing ? 1 - controller.value : controller.value;
    final moved = Curves.easeOut.transform(
      ((elapsed - delay) / (1 - delay)).clamp(0.0, 1.0),
    );
    return collapsing ? 1 - moved : moved;
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final children = <Widget>[];
    var first = true;
    for (final section in widget.sections) {
      if (section.places.isEmpty) continue;
      final title = section.title;
      if (title.isNotEmpty) {
        // The heading takes 32 pt with the text centered 24 from the top: 40 from the center of the
        // last row before, 24 from the center of the first row after.
        children.add(
          first
              ? SizedBox(
                  height: sidebarFirstRowCenter - sidebarHeadingToRow - 24,
                )
              : const SizedBox.shrink(),
        );
        children.add(_heading(title, colors));
      } else if (first) {
        children.add(
          const SizedBox(height: sidebarFirstRowCenter - sidebarRow / 2),
        );
      }
      first = false;
      final openness = title.isEmpty ? 1.0 : _openness(title);
      final textVisible = title.isEmpty || !_collapsing(title);
      children.add(
        ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: openness,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final place in section.places)
                  _row(place, colors, showText: textVisible),
              ],
            ),
          ),
        ),
      );
    }
    return ColoredBox(
      color: colors.fill,
      child: ListView(padding: EdgeInsets.zero, children: children),
    );
  }

  Widget _heading(String title, SidebarColors colors) {
    final hovered = _hovered == title;
    final collapsed = _collapsing(title);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = title),
      onExit: (_) => setState(() {
        if (_hovered == title) _hovered = null;
      }),
      child: SizedBox(
        key: ValueKey('header $title'),
        height: sidebarRow,
        child: Stack(
          children: [
            Positioned(
              left: sidebarHeadingLeft,
              right: sidebarChevronRight + sidebarChevron.width,
              top: 24 - 8,
              height: 16,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(11.5, colors.heading, weight: FontWeight.w600),
                ),
              ),
            ),
            // The chevron appears on hover, without delay or fade (MU-11).
            if (hovered)
              Positioned(
                right: sidebarChevronRight - 4,
                top: 24 - 10,
                width: sidebarChevron.width + 8,
                height: 20,
                child: GestureDetector(
                  key: ValueKey('collapse $title'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _toggle(title),
                  child: Center(
                    child: SizedBox(
                      width: collapsed
                          ? sidebarChevron.height
                          : sidebarChevron.width,
                      height: collapsed
                          ? sidebarChevron.width
                          : sidebarChevron.height,
                      child: CustomPaint(
                        painter: _ChevronPainter(
                          colors.heading,
                          down: !collapsed,
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

  Widget _row(Place place, SidebarColors colors, {required bool showText}) {
    final onDrop = widget.onDrop;
    if (onDrop == null || place.kind == PlaceKind.tag) {
      return _rowContent(place, colors, showText: showText, drop: false);
    }
    return FolderDropTarget(
      path: place.path,
      onDrop: onDrop,
      builder: (context, active) =>
          _rowContent(place, colors, showText: showText, drop: active),
    );
  }

  Widget _rowContent(
    Place place,
    SidebarColors colors, {
    required bool showText,
    required bool drop,
  }) {
    final selected = place.path == widget.current;
    return GestureDetector(
      key: ValueKey('place ${place.path}'),
      onTap: () => widget.onSelect(place),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: sidebarRow,
        child: Stack(
          children: [
            if (selected || drop)
              Positioned.fill(
                left: sidebarSelectionInset,
                right: sidebarSelectionInset,
                child: DecoratedBox(
                  key: ValueKey(drop ? 'sidebar drop' : 'sidebar selection'),
                  decoration: BoxDecoration(
                    color: drop ? dragAccent : colors.selection,
                    borderRadius: BorderRadius.circular(sidebarSelectionRadius),
                  ),
                ),
              ),
            Positioned(
              left: sidebarIconLeft,
              top: (sidebarRow - sidebarIconSize) / 2,
              width: sidebarIconSize,
              height: sidebarIconSize,
              child: place.kind == PlaceKind.tag
                  // Tags: a 13 pt filled circle, without an outline.
                  ? Center(
                      child: TagDot(
                        color: switch (tagColor(place.label)) {
                          final c? => sidebarTagColor(
                            c,
                            dark: colors.fill.computeLuminance() < 0.3,
                          ),
                          null => null,
                        },
                        side: 13,
                        ring: false,
                      ),
                    )
                  : _symbol(
                      place.kind,
                      accentIcon(place.kind)
                          ? colors.accentIcon
                          : selected
                          ? colors.plainIconSelected
                          : colors.plainIcon,
                    ),
            ),
            if (showText)
              Positioned(
                left: sidebarTextLeft,
                right: sidebarSelectionInset + 4,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    // The Trash is named in the user's language; the other places by their
                    // folder or tag name.
                    place.kind == PlaceKind.trash ? l10n.trash : place.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _text(
                      13.75,
                      drop
                          ? const Color(0xFFFFFFFF)
                          : selected
                          ? colors.selectedText
                          : colors.text,
                      weight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The silica-icons symbol (`symbols/regular`); nothing if the icons are not there.
  Widget _symbol(PlaceKind kind, Color color) {
    final dir = widget.iconsDir;
    if (dir == null) return const SizedBox.shrink();
    final file = File('$dir/symbols/regular/${symbolFor(kind)}.svg');
    if (!file.existsSync()) return const SizedBox.shrink();
    return SvgPicture.file(
      file,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

TextStyle _text(double size, Color color, {FontWeight? weight}) => TextStyle(
  fontFamily: uiFontFamily,
  package: 'silica_ui',
  fontSize: size,
  fontWeight: weight,
  color: color,
);

/// ∨ (section open) or › (collapsed): changes right away, without rotation (MU-11).
class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.color, {required this.down});
  final Color color;
  final bool down;

  @override
  void paint(Canvas canvas, Size size) {
    final path = down
        ? (Path()
            ..moveTo(0.75, 0.75)
            ..lineTo(size.width / 2, size.height - 0.75)
            ..lineTo(size.width - 0.75, 0.75))
        : (Path()
            ..moveTo(0.75, 0.75)
            ..lineTo(size.width - 0.75, size.height / 2)
            ..lineTo(0.75, size.height - 0.75));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) =>
      old.color != color || old.down != down;
}

/// The right edge of the sidebar: dragging it changes the width (double arrow, also at the
/// minimum).
class SidebarDivider extends StatelessWidget {
  const SidebarDivider({
    super.key,
    required this.onDrag,
    required this.onRelease,
  });

  /// The pointer x in the window.
  final ValueChanged<double> onDrag;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.resizeLeftRight,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) => onDrag(d.globalPosition.dx),
      onHorizontalDragEnd: (_) => onRelease(),
      onHorizontalDragCancel: onRelease,
    ),
  );
}
