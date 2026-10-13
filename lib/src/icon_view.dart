// La vista a icone (MU-21, mustache-spec 4): griglia che riempie la larghezza, etichette sotto
// le icone su al più due righe, selezione con il fondo dell'icona e la capsula del nome.
//
// Griglia (spec 4.1, R4.1, R4.6): il passo x è la larghezza disponibile divisa per le colonne
// che entrano con il passo minimo; il passo y e la cima della prima icona seguono il lato
// (59 / 78 / 116 / 154 / 192 per 16 / 32 / 64 / 96 / 128, prima icona a 21–28 pt dall'alto).
// Selezione (spec 4.2): fondo 72 × 72 di raggio ~6 attorno all'icona da 64 (4 pt per lato),
// capsula del nome alta 17 per riga, raggio ~5, 4 pt di margine, 2 pt sotto il fondo.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'model.dart';

/// Il lato predefinito delle icone e il corpo del testo (spec 4.1).
const double defaultIconSide = 64;
const double defaultLabelSize = 12;

/// Margine fra l'icona e il suo fondo selezionato, e raggio del fondo.
const double iconSelectionPad = 4;
const double iconSelectionRadius = 6;

/// La capsula del nome: alta 17 per riga, raggio 5, 4 pt di margine, 2 pt sotto il fondo.
const double labelLine = 17;
const double labelRadius = 5;
const double labelPad = 4;
const double labelGap = 2;

/// Le immagini in miniatura occupano ~89 % del lato dell'icona, angoli di ~3 pt (spec 4.4).
const double thumbnailRatio = 0.89;
const double thumbnailRadius = 3;

/// I colori della selezione (spec 4.2), chiaro e scuro.
@immutable
class IconViewColors {
  const IconViewColors({
    required this.iconSelection,
    required this.label,
    required this.labelSelected,
    required this.capsule,
    required this.capsuleInactive,
    required this.labelSelectedInactive,
  });

  final Color iconSelection;
  final Color label;
  final Color labelSelected;
  final Color capsule;
  final Color capsuleInactive;
  final Color labelSelectedInactive;

  static IconViewColors of({required bool dark}) => dark
      ? const IconViewColors(
          iconSelection: Color(0xFF3C3C3D),
          label: Color(0xFFFFFFFF),
          labelSelected: Color(0xFFFFFFFF),
          capsule: Color(0xFF0059D1),
          capsuleInactive: Color(0xFF464646),
          labelSelectedInactive: Color(0xFFFFFFFF),
        )
      : const IconViewColors(
          iconSelection: Color(0xFFE6E6E6),
          label: Color(0xFF000000),
          labelSelected: Color(0xFFFFFFFF),
          capsule: Color(0xFF0064E1),
          capsuleInactive: Color(0xFFDCDCDC),
          labelSelectedInactive: Color(0xFF000000),
        );
}

/// La geometria della griglia per una larghezza del contenuto.
@immutable
class IconGrid {
  const IconGrid({
    required this.side,
    required this.columns,
    required this.pitchX,
    required this.pitchY,
    required this.left,
    required this.top,
  });

  /// Lato dell'icona.
  final double side;
  final int columns;
  final double pitchX;
  final double pitchY;

  /// Bordo sinistro della prima cella e cima della prima icona.
  final double left;
  final double top;

  /// Il centro x della cella `column`.
  double centerX(int column) => left + pitchX * (column + 0.5);

  /// La cima dell'icona della riga `row`.
  double iconTop(int row) => top + pitchY * row;

  /// La cella sotto un punto (null fuori dalle celle occupate da `count` elementi).
  int? indexAt(Offset p, int count) {
    if (p.dx < left || p.dy < top - iconSelectionPad) return null;
    final column = ((p.dx - left) / pitchX).floor();
    final row = ((p.dy - top + iconSelectionPad) / pitchY).floor();
    if (column < 0 || column >= columns) return null;
    final index = row * columns + column;
    return index < count ? index : null;
  }
}

/// La griglia per `width` pt di contenuto (spec 4.1, R4.1, R4.6).
IconGrid iconGrid(
  double width, {
  double side = defaultIconSide,
  double text = defaultLabelSize,
}) {
  // Passo minimo: la larghezza dell'etichetta o l'icona con il suo margine.
  final minPitch = math.max(side + 36, 50 + text * 5);
  // ~11 pt di margine per lato (6 colonne da 126,8 in 783 pt).
  const margin = 11.0;
  final available = math.max(0.0, width - 2 * margin);
  final columns = math.max(1, (available / minPitch).floor());
  // Passo y: 116 a 64/12, 38 pt ogni 32 di lato; il testo più piccolo o più grande lo
  // accorcia o allunga (110 a 10, 120 a 14, 122 a 16).
  final textDelta = text <= 12 ? (text - 12) * 3 : math.min(6, (text - 12) * 2);
  return IconGrid(
    side: side,
    columns: columns,
    pitchX: available / columns,
    pitchY: side * 1.1875 + 40 + textDelta,
    left: margin,
    top: 20 + side / 16,
  );
}

/// Le righe dell'etichetta: al più due; la prima va a capo anche dentro una parola, la seconda
/// se non entra si tronca al centro (R4.5).
List<String> labelLines(String name, double maxWidth, TextStyle style) {
  double widthOf(String s) {
    final painter = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }

  if (widthOf(name) <= maxWidth) return [name];
  // La prima riga: quanti caratteri entrano, preferendo spezzare dopo uno spazio.
  var cut = 1;
  while (cut < name.length && widthOf(name.substring(0, cut + 1)) <= maxWidth) {
    cut++;
  }
  final space = name.lastIndexOf(' ', cut);
  if (space > 0 && space >= cut ~/ 2) cut = space + 1;
  final first = name.substring(0, cut).trimRight();
  var rest = name.substring(cut).trimLeft();
  if (rest.isEmpty) return [first];
  if (widthOf(rest) > maxWidth) {
    // Troncamento al centro: si tolgono caratteri attorno al centro finché entra.
    var keep = rest.length - 1;
    String middle(int n) {
      final head = (n + 1) ~/ 2;
      final tail = n - head;
      return '${rest.substring(0, head)}…${rest.substring(rest.length - tail)}';
    }

    while (keep > 1 && widthOf(middle(keep)) > maxWidth) {
      keep--;
    }
    rest = middle(keep);
  }
  return [first, rest];
}

class IconView extends StatelessWidget {
  const IconView({
    super.key,
    required this.entries,
    required this.selected,
    required this.onTap,
    required this.onOpen,
    required this.onBackground,
    this.active = true,
    this.side = defaultIconSide,
    this.text = defaultLabelSize,
    this.env,
    this.controller,
  });

  final List<Entry> entries;
  final Set<String> selected;
  final ValueChanged<Entry> onTap;
  final ValueChanged<Entry> onOpen;

  /// Clic nel vuoto: toglie la selezione.
  final VoidCallback onBackground;
  final bool active;
  final double side;
  final double text;

  /// L'ambiente per trovare silica-icons (test).
  final Map<String, String>? env;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final dark =
        MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark;
    final colors = IconViewColors.of(dark: dark);
    return LayoutBuilder(
      builder: (context, constraints) {
        final grid = iconGrid(constraints.maxWidth, side: side, text: text);
        final rows = (entries.length / grid.columns).ceil();
        final height = rows == 0 ? 0.0 : grid.iconTop(rows - 1) + grid.pitchY;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onBackground,
          child: SingleChildScrollView(
            controller: controller,
            child: SizedBox(
              height: math.max(height, constraints.maxHeight),
              child: Stack(
                children: [
                  for (var i = 0; i < entries.length; i++)
                    _cell(context, grid, i, colors),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cell(
    BuildContext context,
    IconGrid grid,
    int index,
    IconViewColors c,
  ) {
    final entry = entries[index];
    final column = index % grid.columns;
    final row = index ~/ grid.columns;
    final isSelected = selected.contains(entry.path);
    final cx = grid.centerX(column);
    final iconTop = grid.iconTop(row);
    final style = TextStyle(
      fontFamily: uiFontFamily,
      package: 'silica_ui',
      fontSize: text,
      color: isSelected
          ? (active ? c.labelSelected : c.labelSelectedInactive)
          : c.label,
    );
    final lines = labelLines(entry.name, grid.pitchX - 2 * labelPad - 6, style);
    final labelTop = iconTop + side + iconSelectionPad + labelGap;
    final bg = side + 2 * iconSelectionPad;
    return Positioned(
      left: cx - grid.pitchX / 2,
      top: iconTop - iconSelectionPad,
      width: grid.pitchX,
      height: bg + labelGap + labelLine * lines.length,
      // La selezione alla pressione, subito (non dopo l'attesa del doppio clic).
      child: Listener(
        onPointerDown: (_) => onTap(entry),
        child: GestureDetector(
          key: ValueKey(entry.path),
          behavior: HitTestBehavior.translucent,
          // Il vuoto attorno non tocca: il clic sulla cella non è un clic nel vuoto.
          onTap: () {},
          onDoubleTap: () => onOpen(entry),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: (grid.pitchX - bg) / 2,
                top: 0,
                width: bg,
                height: bg,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isSelected ? c.iconSelection : null,
                    borderRadius: BorderRadius.circular(iconSelectionRadius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(iconSelectionPad),
                    child: EntryIcon(entry: entry, side: side, env: env),
                  ),
                ),
              ),
              for (var i = 0; i < lines.length; i++)
                Positioned(
                  left: 0,
                  right: 0,
                  top: labelTop - (iconTop - iconSelectionPad) + i * labelLine,
                  height: labelLine,
                  child: Center(
                    child: DecoratedBox(
                      key: ValueKey('nome ${entry.path} $i'),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (active ? c.capsule : c.capsuleInactive)
                            : null,
                        borderRadius: BorderRadius.circular(labelRadius),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: labelPad,
                        ),
                        child: Text(lines[i], maxLines: 1, style: style),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le estensioni di cui si mostra la miniatura.
const Set<String> thumbnailExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp'};

bool hasThumbnail(String name) {
  final dot = name.lastIndexOf('.');
  return dot > 0 &&
      thumbnailExtensions.contains(name.substring(dot + 1).toLowerCase());
}

/// L'icona di un elemento: cartella (con il simbolo delle cartelle speciali), miniatura delle
/// immagini, o l'icona del tipo di file di silica-icons.
class EntryIcon extends StatelessWidget {
  const EntryIcon({
    super.key,
    required this.entry,
    required this.side,
    this.env,
  });

  final Entry entry;
  final double side;
  final Map<String, String>? env;

  @override
  Widget build(BuildContext context) {
    if (entry.isDirectory) {
      final folder = resolveFolderIcon(entry.path, env: env);
      if (folder != null) {
        return SilicaIcon(FolderSource(folder), side: side);
      }
      return SizedBox(width: side, height: side);
    }
    if (hasThumbnail(entry.name)) return _Thumbnail(entry.path, side);
    final icon = fileIconFor(entry.name, env: env);
    if (icon == null) return SizedBox(width: side, height: side);
    return SilicaIcon(LayeredSource(icon), side: side);
  }
}

/// La miniatura di un'immagine: ~89 % del lato, angoli di 3 pt, ombra morbida in basso; se
/// l'immagine non si legge, l'icona del tipo.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail(this.path, this.side);
  final String path;
  final double side;

  @override
  Widget build(BuildContext context) {
    final box = side * thumbnailRatio;
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return Center(
      child: ConstrainedBox(
        // Larga: l'immagine tiene le sue proporzioni dentro il riquadro, e ombra e angoli
        // seguono l'immagine, non il riquadro.
        constraints: BoxConstraints.loose(Size(box, box)),
        child: Image.file(
          File(path),
          cacheWidth: (box * ratio).round(),
          frameBuilder: (context, child, frame, _) => frame == null
              ? const SizedBox.shrink()
              : Center(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 7,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(thumbnailRadius),
                      child: child,
                    ),
                  ),
                ),
          errorBuilder: (context, error, stack) {
            final icon = fileIconFor(path.split('/').last);
            return icon == null
                ? const SizedBox.shrink()
                : SilicaIcon(LayeredSource(icon), side: side);
          },
        ),
      ),
    );
  }
}
