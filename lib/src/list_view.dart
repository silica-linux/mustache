// La vista a elenco (⌘2, MU-20, mustache-spec 3), misurata su mu20-list-*: intestazione da y 52
// a 79 con la linea di 2 pt sotto (79–81), prima riga a y 85, righe da 20 a passo 20; colonne
// da x 10: Nome 364, Data di modifica 181, Dimensioni 97, Tipo 121, separatori 1 × 16 (y 58–73
// della finestra). Righe alternate: rettangoli di raggio 8 sulle righe dispari, da x 10 alla fine
// della tabella, anche dopo l'ultima riga. Triangolo a x 17–21, icona 16 a x 26, nome da x 47
// con la linea di base a 15 nella riga; rientro di 15 pt per livello.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'model.dart';

const double listRowHeight = 20;

/// L'intestazione: 27 pt di testo e 2 pt di linea.
const double listHeaderHeight = 27;
const double listHeaderLine = 2;

/// Dalla linea alla prima riga (la prima riga a y 85 della finestra).
const double listFirstRowGap = 4;
const double listInset = 10;
const double listIndent = 15;
const double listTriangleLeft = 17;
const double listIconLeft = 26;
const double listIconSide = 16;
const double listNameLeft = 47;

/// Linee di base: del testo nella riga e delle etichette nell'intestazione.
const double listRowBaseline = 15;
const double listHeaderBaseline = 18;

/// Dove comincia l'etichetta di una colonna: Nome a +45, le altre a +5 (inchiostro a +7).
const double listNameLabelLeft = 45;
const double listLabelLeft = 5;

/// Il testo delle celle: Data e Tipo a +7, Dimensioni a destra a 7 pt dal bordo.
const double listCellLeft = 7;
const double listCellRight = 7;

/// La larghezza minima di una colonna (Data, osservata).
const double listColumnMin = 75;

/// Raggi misurati su mu20-list-light e mu20-list-sel-light confrontando il profilo dell'angolo
/// con la copertura simulata dei pixel: righe alternate 8; selezione (riga sola e angoli esterni
/// di un blocco) 7,5. La specifica dice 10 per le capsule, ma l'arrotondamento occupa 4 righe.
const double listStripeRadius = 8;
const double listBlockRadius = 7.5;

/// Una colonna dell'elenco.
@immutable
class ListColumn {
  const ListColumn(
    this.key,
    this.label,
    this.width, {
    this.alignRight = false,
    this.descendingFirst = false,
  });
  final SortKey key;
  final String label;
  final double width;
  final bool alignRight;

  /// Il primo clic ordina dal più grande (Data e Dimensioni, R3.5).
  final bool descendingFirst;
}

const List<ListColumn> listColumns = [
  ListColumn(SortKey.name, 'Nome', 364),
  ListColumn(SortKey.modified, 'Data di modifica', 181, descendingFirst: true),
  ListColumn(
    SortKey.size,
    'Dimensioni',
    97,
    alignRight: true,
    descendingFirst: true,
  ),
  ListColumn(SortKey.kind, 'Tipo', 121),
];

/// La larghezza della tabella: il margine e le colonne.
double listTableWidth(List<double> widths) =>
    listInset + widths.fold(0.0, (a, b) => a + b);

/// I colori dell'elenco (base chiaro e scuro, mustache-spec 3.1; in chiaro misurati su
/// mu20-list-light).
@immutable
class ListColors {
  const ListColors({
    required this.background,
    required this.header,
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
  final Color stripe;

  /// La linea sotto l'intestazione: in scuro due righe di 1 pt diverse.
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

/// Un testo con la linea di base a `baseline` dalla cima del riquadro.
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

/// Tronca al centro con "…" perché il testo stia in `width` (R3.4).
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
  // Quanti caratteri tenere in tutto, metà davanti e metà dietro.
  while (lo <= hi) {
    final keep = (lo + hi) ~/ 2;
    final head = (keep + 1) ~/ 2;
    final tail = keep - head;
    final candidate =
        '${String.fromCharCodes(runes.take(head))}…'
        '${String.fromCharCodes(runes.skip(runes.length - tail))}';
    if (measure(candidate) <= width) {
      best = candidate;
      lo = keep + 1;
    } else {
      hi = keep - 1;
    }
  }
  return best;
}

/// L'intestazione: le etichette, i separatori 1 × 16, la freccia 7 × 4 della colonna
/// ordinata (8 pt dal suo bordo destro), la linea sotto. Clic per ordinare, trascinando un
/// separatore cambia la colonna alla sua sinistra.
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

  /// Trascinamento del separatore a destra della colonna `index`.
  final void Function(int index, double dx) onResize;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    // Le prese dei separatori stanno sopra le etichette: metà presa cade sulla colonna dopo.
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
          child: GestureDetector(
            key: ValueKey('intestazione ${column.key.name}'),
            behavior: HitTestBehavior.opaque,
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
                key: const ValueKey('freccia di ordinamento'),
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
      // La presa del separatore: 4 pt per parte.
      handles.add(
        Positioned(
          left: x - 4,
          top: 0,
          width: 8,
          height: listHeaderHeight,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              key: ValueKey('bordo ${column.key.name}'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (d) => onResize(i, d.delta.dx),
            ),
          ),
        ),
      );
    }
    return Container(
      key: const ValueKey('intestazione delle colonne'),
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

/// ∧ crescente, ∨ decrescente.
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

/// Il triangolo di una cartella: › chiusa, ⌄ aperta (5 × 8, cambia in un fotogramma).
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

/// Il fondo di una riga: la capsula alternata sulle righe dispari, o la selezione. Le righe
/// scelte contigue formano un blocco con gli angoli esterni arrotondati e una linea di 1 pt fra
/// una riga e l'altra (R3.8).
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

  /// Fin dove arriva la riga (la fine della tabella o della vista).
  final double width;
  final ListColors colors;
  final bool selected;
  final bool selectedAbove;
  final bool selectedBelow;

  /// Finestra attiva: selezione in accento, altrimenti grigia.
  final bool active;

  /// La cartella sotto un trascinamento: colorata come la selezione.
  final bool dropTarget;

  /// L'anello di 2 pt del clic destro su una riga non scelta (R3.9).
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
