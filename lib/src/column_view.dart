// La vista a colonne (MU-22, mustache-spec 5): una colonna per ogni cartella dalla radice (la
// voce della barra laterale da cui si parte, R5.6) fino a quella aperta; l'elemento scelto è
// evidenziato nella sua colonna (blu nella colonna attiva, grigio in quelle a sinistra, R5.1).
// Le colonne non si comprimono: la vista scorre in orizzontale e salta subito in fondo quando
// se ne apre una nuova (R5.4, R5.5).

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'icon_view.dart' show EntryIcon;
import 'list_view.dart' show middleEllipsis;
import 'model.dart';
import 'tags.dart' show TagDots;

/// Passo di una colonna (elenco 234 + fascia di separazione 11).
const double columnPitch = 245;
const double columnBand = 11;
const double columnRow = 24;
const double columnTop = 6;
const double columnIconLeft = 17;
const double columnIconSide = 16;
const double columnTextLeft = 39;
const double columnChevronLeft = 208;
const double columnSelectionLeft = 10;
const double columnSelectionWidth = 208;
const double columnSelectionRadius = 7;

@immutable
class ColumnColors {
  const ColumnColors({
    required this.fill,
    required this.band,
    required this.text,
    required this.active,
    required this.activeText,
    required this.path,
    required this.chevron,
  });

  final Color fill;
  final Color band;
  final Color text;
  final Color active;
  final Color activeText;

  /// La selezione nelle colonne a sinistra della attiva.
  final Color path;
  final Color chevron;

  static ColumnColors of({required bool dark}) => dark
      ? const ColumnColors(
          fill: Color(0xFF272728),
          band: Color(0xFF313132),
          text: Color(0xFFFFFFFF),
          active: Color(0xFF0059D1),
          activeText: Color(0xFFFFFFFF),
          path: Color(0xFF464646),
          chevron: Color(0xFF8E8E93),
        )
      : const ColumnColors(
          fill: Color(0xFFFFFFFF),
          band: Color(0xFFF3F3F3),
          text: Color(0xFF000000),
          active: Color(0xFF0064E1),
          activeText: Color(0xFFFFFFFF),
          path: Color(0xFFDCDCDC),
          chevron: Color(0xFF8E8E93),
        );
}

/// Le cartelle delle colonne: dalla radice a `current` compresa (solo se `current` è dentro
/// `root`; altrimenti la sola `current`).
List<String> columnChain(String root, String current) {
  if (current != root && !current.startsWith(root == '/' ? '/' : '$root/')) {
    return [current];
  }
  final chain = <String>[root];
  var rest = current.substring(root.length);
  if (rest.startsWith('/')) rest = rest.substring(1);
  var path = root;
  for (final part in rest.split('/').where((p) => p.isNotEmpty)) {
    path = path == '/' ? '/$part' : '$path/$part';
    chain.add(path);
  }
  return chain;
}

class ColumnView extends StatefulWidget {
  const ColumnView({
    super.key,
    required this.root,
    required this.current,
    required this.leaf,
    required this.list,
    required this.onSelect,
    required this.onOpen,
    this.active = true,
    this.env,
    this.tagsOf,
  });

  /// Le etichette di un elemento: i punti prima della freccia (mu22-root).
  final List<String> Function(Entry entry)? tagsOf;

  /// La radice (prima colonna) e la cartella aperta (ultima colonna).
  final String root;
  final String current;

  /// L'elemento scelto: un file nella colonna di `current`, o `current` stesso se è stata
  /// scelta una cartella (allora la sua colonna è l'ultima, senza selezione).
  final String? leaf;

  /// Il contenuto di una cartella, già ordinato (dalla finestra: file nascosti, ordinamento).
  final List<Entry> Function(String dir) list;

  /// Clic su un elemento della colonna di `dir`.
  final void Function(Entry entry, String dir) onSelect;
  final ValueChanged<Entry> onOpen;
  final bool active;
  final Map<String, String>? env;

  @override
  State<ColumnView> createState() => _ColumnViewState();
}

class _ColumnViewState extends State<ColumnView> {
  final ScrollController _scroll = ScrollController();
  int _columns = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark =
        MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark;
    final colors = ColumnColors.of(dark: dark);
    final chain = columnChain(widget.root, widget.current);
    final leaf = widget.leaf;
    // La colonna attiva è quella dell'elemento scelto: quella del file, o quella che contiene
    // la cartella scelta (la penultima).
    final leafIsCurrent = leaf == widget.current;
    final activeColumn = leafIsCurrent ? chain.length - 2 : chain.length - 1;
    if (chain.length != _columns) {
      // Una colonna nuova: la vista salta in fondo, senza animazione (R5.4).
      _columns = chain.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
    return ColoredBox(
      color: colors.fill,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < chain.length; i++)
              _column(
                chain[i],
                // Nella colonna i è evidenziata la cartella dopo nella catena, o l'elemento.
                highlighted: i + 1 < chain.length
                    ? chain[i + 1]
                    : (leafIsCurrent ? null : leaf),
                active: i == activeColumn && widget.active,
                colors: colors,
              ),
          ],
        ),
      ),
    );
  }

  Widget _column(
    String dir, {
    required String? highlighted,
    required bool active,
    required ColumnColors colors,
  }) {
    final entries = widget.list(dir);
    return SizedBox(
      key: ValueKey('colonna $dir'),
      width: columnPitch,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _RevealList(
              key: ValueKey('elenco $dir'),
              reveal: entries.indexWhere((e) => e.path == highlighted),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final lit = entry.path == highlighted;
                final fill = !lit
                    ? null
                    : (active ? colors.active : colors.path);
                final textColor = lit && active
                    ? colors.activeText
                    : colors.text;
                final tags = widget.tagsOf?.call(entry) ?? const <String>[];
                final tagsWidth = tags.isEmpty
                    ? 0.0
                    : 10 + 5.0 * (tags.length - 1);
                return Listener(
                  onPointerDown: (_) => widget.onSelect(entry, dir),
                  child: GestureDetector(
                    key: ValueKey(entry.path),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    onDoubleTap: () => widget.onOpen(entry),
                    child: Stack(
                      children: [
                        if (fill != null)
                          Positioned(
                            left: columnSelectionLeft,
                            width: columnSelectionWidth,
                            top: 0,
                            bottom: 0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: fill,
                                borderRadius: BorderRadius.circular(
                                  columnSelectionRadius,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          left: columnIconLeft,
                          top: (columnRow - columnIconSide) / 2,
                          width: columnIconSide,
                          height: columnIconSide,
                          child: EntryIcon(
                            entry: entry,
                            side: columnIconSide,
                            env: widget.env,
                          ),
                        ),
                        // Il nome troncato al centro (mu22-root: "Beta con un…nella
                        // colonna"); i punti delle etichette prima della freccia.
                        Positioned(
                          left: columnTextLeft,
                          right:
                              columnPitch -
                              columnBand -
                              columnChevronLeft +
                              4 +
                              (tags.isEmpty ? 0 : tagsWidth + 6),
                          top: 0,
                          bottom: 0,
                          child: LayoutBuilder(
                            builder: (context, box) {
                              final style = TextStyle(
                                fontFamily: uiFontFamily,
                                package: 'silica_ui',
                                fontSize: 13,
                                color: textColor,
                              );
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  middleEllipsis(
                                    entry.name,
                                    style,
                                    box.maxWidth,
                                  ),
                                  maxLines: 1,
                                  softWrap: false,
                                  style: style,
                                ),
                              );
                            },
                          ),
                        ),
                        if (tags.isNotEmpty)
                          Positioned(
                            left: columnChevronLeft - 10 - tagsWidth,
                            top: (columnRow - 10) / 2,
                            child: TagDots(
                              tags: tags,
                              background: fill ?? colors.fill,
                            ),
                          ),
                        if (entry.isDirectory)
                          Positioned(
                            left: columnChevronLeft,
                            top: (columnRow - 7) / 2,
                            width: 4,
                            height: 7,
                            child: CustomPaint(
                              painter: _Chevron(
                                lit && active
                                    ? colors.activeText
                                    : colors.chevron,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // La fascia di separazione sul lato destro.
          SizedBox(
            width: columnBand,
            child: ColoredBox(color: colors.band),
          ),
        ],
      ),
    );
  }
}

/// L'elenco di una colonna: quando compare, la voce evidenziata è portata in vista (una
/// colonna lunga non nasconde la cartella aperta a destra).
class _RevealList extends StatefulWidget {
  const _RevealList({
    super.key,
    required this.reveal,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int reveal;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<_RevealList> createState() => _RevealListState();
}

class _RevealListState extends State<_RevealList> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || widget.reveal < 0) return;
      final position = _scroll.position;
      final bottom = columnTop + columnRow * (widget.reveal + 1);
      if (bottom > position.viewportDimension) {
        _scroll.jumpTo(
          (bottom - position.viewportDimension).clamp(
            0.0,
            position.maxScrollExtent,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: _scroll,
    padding: const EdgeInsets.only(top: columnTop),
    itemCount: widget.itemCount,
    itemExtent: columnRow,
    itemBuilder: widget.itemBuilder,
  );
}

class _Chevron extends CustomPainter {
  const _Chevron(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0.5, 0.5)
        ..lineTo(size.width - 0.5, size.height / 2)
        ..lineTo(0.5, size.height - 0.5),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_Chevron old) => old.color != color;
}
