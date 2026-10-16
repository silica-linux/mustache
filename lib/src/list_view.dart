// The list view (⌘2, MU-20, docs/spec/list-view.md for the behaviour; kit `Apps/Mustache/List`,
// `List Header`, `List Row/*` for the look): a 28 pt header with a 1 pt separator below it, rows 28
// tall, odd rows striped on `Surface/Sidebar` across the whole width, the selection an accent
// capsule inset 8 from each side (radius 8). Columns from x 20 (the content padding): Name (icon
// at +0, name at +24), Date Modified, Size, Kind; the gaps between the texts are 12–16. Folders
// expand in place (16 pt indent per level) with a 12 pt chevron before the icon.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'model.dart';

const double listRowHeight = 28;

/// The header: 27 pt of labels and a 1 pt separator (kit `List Header`: 760 × 28, line at y 27).
const double listHeaderHeight = 27;
const double listHeaderLine = 1;

/// The first row follows the header directly.
const double listFirstRowGap = 0;

/// The content padding: the table starts here, the selection and stripes reach 8 from the edge.
const double listInset = 20;
const double listSelectionInset = 8;
const double listIndent = 16;

/// The expand chevron (12 pt) sits in the padding before the icon.
const double listChevronLeft = 4;
const double listChevronSide = 12;
const double listIconLeft = 20;
const double listIconSide = 16;
const double listNameLeft = 44;

/// Where the label of the Name column starts in the header, and of the others.
const double listNameLabelLeft = 24;
const double listLabelLeft = 0;

/// The room kept free right of the text of a column (the first one 16, the others 12).
const double listNameRight = 16;
const double listCellRight = 12;

/// The minimum width of a column.
const double listColumnMin = 75;

/// The radius of the selection capsule and of the block of selected rows (kit: 8).
const double listBlockRadius = 8;

/// A list column.
@immutable
class ListColumn {
  const ListColumn(
    this.key,
    this.width, {
    this.alignRight = false,
    this.descendingFirst = false,
  });
  final SortKey key;

  /// The header label, in the user's language.
  String get label => switch (key) {
    SortKey.name => l10n.columnName,
    SortKey.modified => l10n.columnModified,
    SortKey.size => l10n.columnSize,
    SortKey.kind => l10n.columnKind,
  };
  final double width;

  /// Unused by the kit (every cell is left aligned); kept for the sort order of a column.
  final bool alignRight;

  /// The first click sorts from the largest (Date and Size, R3.5).
  final bool descendingFirst;
}

/// The kit's columns: texts at 44 (Name, 280 wide), 340 (168), 520 (88) and 620 (128) of a 760
/// table that starts 20 in; each column runs to the start of the next.
const List<ListColumn> listColumns = [
  ListColumn(SortKey.name, 320),
  ListColumn(SortKey.modified, 180, descendingFirst: true),
  ListColumn(SortKey.size, 100, descendingFirst: true),
  ListColumn(SortKey.kind, 140),
];

/// The table width: the margin and the columns.
double listTableWidth(List<double> widths) =>
    listInset + widths.fold(0.0, (a, b) => a + b);

/// The colors of the list: Amalfi tokens (`Text/*`, `Surface/*`, `Line/Separator`,
/// `Accent/Amalfi`).
@immutable
class ListColors {
  const ListColors(this.tokens);

  final AmalfiColors tokens;

  Color get background => tokens.surfaceWindow;
  Color get stripe => tokens.surfaceSidebar;
  Color get line => tokens.lineSeparator;
  Color get label => tokens.textTertiary;
  Color get labelSorted => tokens.textPrimary;
  Color get name => tokens.textPrimary;
  Color get secondary => tokens.textSecondary;
  Color get triangle => tokens.textTertiary;
  Color get selection => tokens.accentAmalfi;
  Color get selectionName => tokens.textOnAccent;
  Color get selectionSecondary => tokens.textOnAccent;

  /// The selection of a window that is not active or of rows being dragged (Assumption: not
  /// measured, the kit shows only the active selection).
  Color get inactiveSelection => tokens.lineBorder;
  Color get inactiveName => tokens.textPrimary;
  Color get inactiveSecondary => tokens.textSecondary;
  Color get headerPressed => tokens.lineSeparator;

  static ListColors of(BuildContext context) =>
      ListColors(AmalfiTheme.of(context).colors);
}

/// Truncates in the middle with "…" so the text fits in `width` (R3.4).
String middleEllipsis(String text, TextStyle style, double width) {
  if (width <= 0) return '';
  double measure(String s) => (TextPainter(
    text: TextSpan(text: s, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout()).width;
  if (measure(text) <= width) return text;
  final runes = text.runes.toList();
  var lo = 0;
  var hi = runes.length;
  var best = '…';
  // How many characters to keep in total, half in front and half behind.
  while (lo <= hi) {
    final keep = (lo + hi) ~/ 2;
    final head = (keep + 1) ~/ 2;
    final tail = keep - head;
    // No spaces around the "…" (MU-22: "Beta con un…nella colonna").
    final candidate =
        '${String.fromCharCodes(runes.take(head)).trimRight()}…'
        '${String.fromCharCodes(runes.skip(runes.length - tail)).trimLeft()}';
    if (measure(candidate) <= width) {
      best = candidate;
      lo = keep + 1;
    } else {
      hi = keep - 1;
    }
  }
  return best;
}

/// The header: the labels (Label, `Text/Tertiary`; the sorted column in `Text/Primary` with a 12 pt
/// chevron), the 1 pt separator below. Click to sort; dragging the edge between two columns changes
/// the column on its left.
class ListHeader extends StatelessWidget {
  const ListHeader({
    super.key,
    required this.widths,
    required this.sort,
    required this.descending,
    required this.colors,
    required this.onSort,
    required this.onResize,
    this.background,
  });

  /// Null: the window surface.
  final Color? background;
  final List<double> widths;
  final SortKey sort;
  final bool descending;
  final ListColors colors;
  final ValueChanged<SortKey> onSort;

  /// Dragging the edge to the right of column `index`.
  final void Function(int index, double dx) onResize;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    // The edge grips sit above the labels: half a grip falls on the next column.
    final handles = <Widget>[];
    var x = listInset;
    for (var i = 0; i < listColumns.length; i++) {
      final column = listColumns[i];
      final width = widths[i];
      final sorted = column.key == sort;
      final left = i == 0 ? listNameLabelLeft : listLabelLeft;
      children.add(
        Positioned(
          left: x,
          top: 0,
          width: width,
          height: listHeaderHeight,
          child: _HeaderCell(
            key: ValueKey('header ${column.key.name}'),
            pressedColor: colors.headerPressed,
            onTap: () => onSort(column.key),
            child: Padding(
              padding: EdgeInsets.only(left: left, top: 6, right: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      column.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: AmalfiType.label(
                        color: sorted ? colors.labelSorted : colors.label,
                      ),
                    ),
                  ),
                  if (sorted)
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: IgnorePointer(
                        child: AmalfiGlyph(
                          descending
                              ? AmalfiGlyphs.chevronDown
                              : AmalfiGlyphs.chevronUp,
                          key: const ValueKey('sort arrow'),
                          size: 12,
                          color: colors.labelSorted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      x += width;
      // The edge grip: 5 pt, 3 left of the boundary and 2 to the right.
      handles.add(
        Positioned(
          left: x - 3,
          top: 0,
          width: 5,
          height: listHeaderHeight,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              key: ValueKey('edge ${column.key.name}'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (d) => onResize(i, d.delta.dx),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      key: const ValueKey('column header'),
      height: listHeaderHeight + listHeaderLine,
      child: ColoredBox(
        color: background ?? colors.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: listHeaderHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [...children, ...handles],
              ),
            ),
            SizedBox(
              height: listHeaderLine,
              child: ColoredBox(color: colors.line),
            ),
          ],
        ),
      ),
    );
  }
}

/// A header cell: pressed it fills (no change on hover); a short click sorts on release, a long
/// press does not (MU-25).
class _HeaderCell extends StatefulWidget {
  const _HeaderCell({
    super.key,
    required this.pressedColor,
    required this.onTap,
    required this.child,
  });

  final Color pressedColor;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_HeaderCell> createState() => _HeaderCellState();
}

class _HeaderCellState extends State<_HeaderCell> {
  bool _pressed = false;

  void _set(bool pressed) {
    if (pressed != _pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => _set(true),
    onTapUp: (_) => _set(false),
    onTapCancel: () => _set(false),
    onTap: widget.onTap,
    // Held long: no reordering on release.
    onLongPress: () {},
    onLongPressStart: (_) => _set(true),
    onLongPressEnd: (_) => _set(false),
    child: ColoredBox(
      color: _pressed ? widget.pressedColor : const Color(0x00000000),
      child: widget.child,
    ),
  );
}

/// A folder's disclosure chevron: › closed, ⌄ open (changes in one frame).
class ListTriangle extends StatelessWidget {
  const ListTriangle({super.key, required this.open, required this.color});
  final bool open;
  final Color color;

  @override
  Widget build(BuildContext context) => AmalfiGlyph(
    open ? AmalfiGlyphs.chevronDown : AmalfiGlyphs.chevronRight,
    size: listChevronSide,
    color: color,
  );
}

/// The background of a row: the stripe on odd rows (across the whole width), or the selection (an
/// accent capsule inset 8 from each side). Contiguous selected rows form a block with rounded
/// outer corners and a 1 pt line between rows (R3.8).
class ListRowBackground extends StatelessWidget {
  const ListRowBackground({
    super.key,
    required this.index,
    required this.width,
    required this.colors,
    this.selected = false,
    this.selectedAbove = false,
    this.selectedBelow = false,
    this.active = true,
    this.dropTarget = false,
    this.ring = false,
  });

  final int index;

  /// How far the row reaches (the end of the table or of the view).
  final double width;
  final ListColors colors;
  final bool selected;
  final bool selectedAbove;
  final bool selectedBelow;

  /// Active window: selection in the accent color, otherwise gray.
  final bool active;

  /// The folder under a drag: colored like the selection.
  final bool dropTarget;

  /// The 2 pt ring of a right click on an unselected row (R3.9).
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final right = math.max(listInset, width);
    Widget shape(Decoration decoration) => Positioned(
      left: listSelectionInset,
      width: right - 2 * listSelectionInset,
      top: 0,
      bottom: 0,
      child: DecoratedBox(decoration: decoration),
    );
    final children = <Widget>[];
    if (index.isOdd && !selected) {
      children.add(Positioned.fill(child: ColoredBox(color: colors.stripe)));
    }
    if (selected || dropTarget) {
      final fill = active || dropTarget
          ? colors.selection
          : colors.inactiveSelection;
      final above = selected && selectedAbove;
      final below = selected && selectedBelow;
      children.add(
        shape(
          ShapeDecoration(
            color: fill,
            shape: AmalfiSmoothBorder.only(
              topLeft: above ? 0 : listBlockRadius,
              topRight: above ? 0 : listBlockRadius,
              bottomLeft: below ? 0 : listBlockRadius,
              bottomRight: below ? 0 : listBlockRadius,
            ),
          ),
        ),
      );
      if (below) {
        children.add(
          Positioned(
            left: listSelectionInset,
            width: right - 2 * listSelectionInset,
            bottom: 0,
            height: 1,
            child: ColoredBox(color: colors.tokens.accentAmalfiPressed),
          ),
        );
      }
    }
    if (ring && !selected) {
      children.add(
        shape(
          ShapeDecoration(
            shape: AmalfiSmoothBorder(
              radius: listBlockRadius,
              side: BorderSide(color: colors.selection, width: 2),
            ),
          ),
        ),
      );
    }
    return Stack(children: children);
  }
}
