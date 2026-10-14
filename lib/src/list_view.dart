// The list view (⌘2, MU-20, mustache-spec 3), measured on mu20-list-*: header from y 52 to 79 with
// the 2 pt line below (79–81), first row at y 85, 20 pt rows at a 20 pitch; columns from x 10: Name
// 364, Date Modified 181, Size 97, Kind 121, 1 × 16 separators (y 58–73 of the window). Alternating
// rows: rectangles with radius 8 on odd rows, from x 10 to the end of the table, also after the
// last row. Triangle at x 17–21, 16 pt icon at x 26, name from x 47 with the baseline at 15 in the
// row; 15 pt indent per level.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'model.dart';

const double listRowHeight = 20;

/// The header: 27 pt of text and 2 pt of line.
const double listHeaderHeight = 27;
const double listHeaderLine = 2;

/// From the line to the first row (the first row at y 85 of the window).
const double listFirstRowGap = 4;
const double listInset = 10;
const double listIndent = 15;
const double listTriangleLeft = 17;
const double listIconLeft = 26;
const double listIconSide = 16;
const double listNameLeft = 47;

/// Baselines: of the text in a row and of the labels in the header.
const double listRowBaseline = 15;
const double listHeaderBaseline = 18;

/// Where a column label starts: Name at +45, the others at +5 (ink at +7).
const double listNameLabelLeft = 45;
const double listLabelLeft = 5;

/// Cell text: Date and Kind at +7, Size right-aligned 7 pt from the edge.
const double listCellLeft = 7;
const double listCellRight = 7;

/// The minimum width of a column (Date, observed).
const double listColumnMin = 75;

/// Radii measured on mu20-list-light and mu20-list-sel-light by comparing the corner profile with
/// simulated pixel coverage: alternating rows 8; selection (single row and outer corners of a
/// block) 7.5. The specification says 10 for the capsules, but the rounding spans 4 rows.
const double listStripeRadius = 8;
const double listBlockRadius = 7.5;

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
  final bool alignRight;

  /// The first click sorts from the largest (Date and Size, R3.5).
  final bool descendingFirst;
}

const List<ListColumn> listColumns = [
  ListColumn(SortKey.name, 364),
  ListColumn(SortKey.modified, 181, descendingFirst: true),
  ListColumn(SortKey.size, 97, alignRight: true, descendingFirst: true),
  ListColumn(SortKey.kind, 121),
];

/// The table width: the margin and the columns.
double listTableWidth(List<double> widths) =>
    listInset + widths.fold(0.0, (a, b) => a + b);

/// List colors (light and dark base, mustache-spec 3.1; in light measured on mu20-list-light).
@immutable
class ListColors {
  const ListColors({
    required this.background,
    required this.header,
    required this.headerPressed,
    required this.stripe,
    required this.line,
    required this.lineDark,
    required this.separator,
    required this.labelSorted,
    required this.label,
    required this.chevron,
    required this.name,
    required this.secondary,
    required this.triangle,
    required this.selection,
    required this.selectionLine,
    required this.selectionName,
    required this.selectionSecondary,
    required this.inactiveSelection,
    required this.inactiveLine,
    required this.inactiveName,
    required this.inactiveSecondary,
  });

  final Color background;
  final Color header;

  /// The pressed header cell, from separator to separator (MU-25).
  final Color headerPressed;
  final Color stripe;

  /// The line below the header: in dark two different 1 pt rows.
  final Color line;
  final Color lineDark;
  final Color separator;
  final Color labelSorted;
  final Color label;
  final Color chevron;
  final Color name;
  final Color secondary;
  final Color triangle;
  final Color selection;
  final Color selectionLine;
  final Color selectionName;
  final Color selectionSecondary;
  final Color inactiveSelection;
  final Color inactiveLine;
  final Color inactiveName;
  final Color inactiveSecondary;

  static const ListColors light = ListColors(
    background: Color(0xFFFFFFFF),
    header: Color(0xFFFFFFFF),
    headerPressed: Color(0xFFF2F2F2),
    stripe: Color(0xFFF4F5F5),
    line: Color(0xFFE5E5E5),
    lineDark: Color(0xFFE5E5E5),
    separator: Color(0xFFE5E5E5),
    labelSorted: Color(0xFF4D4D4D),
    label: Color(0xFF808080),
    chevron: Color(0xFF6A6A6A),
    name: Color(0xFF252525),
    secondary: Color(0xFF808080),
    triangle: Color(0xFF808080),
    selection: Color(0xFF0064E1),
    selectionLine: Color(0xFF2673E4),
    selectionName: Color(0xFFFFFFFF),
    selectionSecondary: Color(0xFFBDCEF5),
    inactiveSelection: Color(0xFFDCDCDC),
    inactiveLine: Color(0xFFD1D1D1),
    inactiveName: Color(0xFF222222),
    inactiveSecondary: Color(0xFF6E6E6E),
  );

  static const ListColors dark = ListColors(
    background: Color(0xFF272728),
    header: Color(0xFF2F2F2F),
    headerPressed: Color(0xFF414141),
    stripe: Color(0xFF313132),
    line: Color(0xFF494949),
    lineDark: Color(0xFF363637),
    separator: Color(0xFF535353),
    labelSorted: Color(0xFFFFFFFF),
    label: Color(0xFFABABAB),
    chevron: Color(0xFFABABAB),
    name: Color(0xFFDFDFE0),
    secondary: Color(0xFFA2A2A2),
    triangle: Color(0xFFA2A2A2),
    selection: Color(0xFF0059D1),
    selectionLine: Color(0xFF2469D5),
    selectionName: Color(0xFFFFFFFF),
    selectionSecondary: Color(0xFFBBCBF0),
    inactiveSelection: Color(0xFF464646),
    inactiveLine: Color(0xFF424242),
    inactiveName: Color(0xFFE3E3E3),
    inactiveSecondary: Color(0xFFACACAC),
  );

  static ListColors of({required bool dark}) => dark ? ListColors.dark : light;
}

TextStyle listText(double size, Color color, {FontWeight? weight}) => TextStyle(
  fontFamily: uiFontFamily,
  package: 'silica_ui',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: 1,
);

/// A text with its baseline at `baseline` from the top of the box.
Widget baselineText(
  String text,
  TextStyle style, {
  required double baseline,
  TextAlign align = TextAlign.left,
}) => Baseline(
  baseline: baseline,
  baselineType: TextBaseline.alphabetic,
  child: SizedBox(
    width: double.infinity,
    child: Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
      textAlign: align,
      style: style,
    ),
  ),
);

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
    // No spaces around the "…" (mu22-root: "Beta con un…nella colonna").
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

/// The header: the labels, the 1 × 16 separators, the 7 × 4 arrow of the sorted column (8 pt from
/// its right edge), the line below. Click to sort; dragging a separator changes the column on its
/// left.
class ListHeader extends StatelessWidget {
  const ListHeader({
    super.key,
    required this.widths,
    required this.sort,
    required this.descending,
    required this.colors,
    required this.onSort,
    required this.onResize,
  });

  final List<double> widths;
  final SortKey sort;
  final bool descending;
  final ListColors colors;
  final ValueChanged<SortKey> onSort;

  /// Dragging the separator to the right of column `index`.
  final void Function(int index, double dx) onResize;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    // The separator grips sit above the labels: half a grip falls on the next column.
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
              padding: EdgeInsets.only(left: left, right: sorted ? 20 : 4),
              child: baselineText(
                column.label,
                listText(
                  11,
                  sorted ? colors.labelSorted : colors.label,
                  weight: sorted ? FontWeight.w600 : null,
                ),
                baseline: listHeaderBaseline,
              ),
            ),
          ),
        ),
      );
      if (sorted) {
        children.add(
          Positioned(
            left: x + width - 14,
            top: 12,
            width: 7,
            height: 4,
            child: IgnorePointer(
              child: CustomPaint(
                key: const ValueKey('sort arrow'),
                painter: _ChevronPainter(colors.chevron, up: !descending),
              ),
            ),
          ),
        );
      }
      x += width;
      children.add(
        Positioned(
          left: x - 1,
          top: 6,
          width: 1,
          height: 16,
          child: ColoredBox(color: colors.separator),
        ),
      );
      // The separator grip: 5 pt, 3 left of the line and 1 to the right (MU-25).
      handles.add(
        Positioned(
          left: x - 4,
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
    return Container(
      key: const ValueKey('column header'),
      height: listHeaderHeight + listHeaderLine,
      color: colors.header,
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
          SizedBox(height: 1, child: ColoredBox(color: colors.line)),
          SizedBox(height: 1, child: ColoredBox(color: colors.lineDark)),
        ],
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

/// ∧ ascending, ∨ descending.
class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.color, {required this.up});
  final Color color;
  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final top = up ? 0.5 : size.height - 0.5;
    final bottom = up ? size.height - 0.5 : 0.5;
    canvas.drawPath(
      Path()
        ..moveTo(0.5, bottom)
        ..lineTo(size.width / 2, top)
        ..lineTo(size.width - 0.5, bottom),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.color != color || old.up != up;
}

/// A folder's disclosure triangle: › closed, ⌄ open (5 × 8, changes in one frame).
class ListTriangle extends StatelessWidget {
  const ListTriangle({super.key, required this.open, required this.color});
  final bool open;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: open ? 8 : 5,
    height: open ? 5 : 8,
    child: CustomPaint(painter: _TrianglePainter(color, open: open)),
  );
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter(this.color, {required this.open});
  final Color color;
  final bool open;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = open
        ? (Path()
            ..moveTo(0.75, 0.75)
            ..lineTo(size.width / 2, size.height - 0.75)
            ..lineTo(size.width - 0.75, 0.75))
        : (Path()
            ..moveTo(0.75, 0.75)
            ..lineTo(size.width - 0.75, size.height / 2)
            ..lineTo(0.75, size.height - 0.75));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) =>
      old.color != color || old.open != open;
}

/// The background of a row: the alternating capsule on odd rows, or the selection. Contiguous
/// selected rows form a block with rounded outer corners and a 1 pt line between rows (R3.8).
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
    Widget shape(BoxDecoration decoration) => Positioned(
      left: listInset,
      width: right - listInset,
      top: 0,
      bottom: 0,
      child: DecoratedBox(decoration: decoration),
    );
    final children = <Widget>[];
    if (selected || dropTarget) {
      final fill = active || dropTarget
          ? colors.selection
          : colors.inactiveSelection;
      final above = selected && selectedAbove;
      final below = selected && selectedBelow;
      final alone = !above && !below;
      const r = Radius.circular(listBlockRadius);
      children.add(
        shape(
          BoxDecoration(
            color: fill,
            borderRadius: alone
                ? BorderRadius.circular(listBlockRadius)
                : BorderRadius.only(
                    topLeft: above ? Radius.zero : r,
                    topRight: above ? Radius.zero : r,
                    bottomLeft: below ? Radius.zero : r,
                    bottomRight: below ? Radius.zero : r,
                  ),
          ),
        ),
      );
      if (below) {
        children.add(
          Positioned(
            left: listInset,
            width: right - listInset,
            bottom: 0,
            height: 1,
            child: ColoredBox(
              color: active ? colors.selectionLine : colors.inactiveLine,
            ),
          ),
        );
      }
    } else if (index.isOdd) {
      children.add(
        shape(
          BoxDecoration(
            color: colors.stripe,
            borderRadius: BorderRadius.circular(listStripeRadius),
          ),
        ),
      );
    }
    if (ring && !selected) {
      children.add(
        shape(
          BoxDecoration(
            border: Border.all(color: colors.selection, width: 2),
            borderRadius: BorderRadius.circular(listBlockRadius),
          ),
        ),
      );
    }
    return Stack(children: children);
  }
}
