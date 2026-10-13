// La barra laterale (MU-10, MU-11): attaccata ai bordi della finestra, dalla cima al fondo, senza
// linea verso il contenuto. Righe a passo 32 pt; fra il centro di un'intestazione e la prima riga
// 24 pt, fra l'ultima riga e l'intestazione dopo 40. Selezione: rettangolo di raggio 8 alto quanto
// la riga, da 10 pt dal bordo; testo in semibold, l'icona tiene il suo colore. Nessun fondo al
// passaggio del puntatore. Le intestazioni mostrano al passaggio un chevron 10 × 6 che comprime la
// sezione (~190 ms, uscita morbida, da +70 ms; espansione da +120 ms): le righe perdono subito il
// testo e scorrono in su sotto l'intestazione che le ritaglia.
//
// Larghezza (MU-11): minimo 135 pt, il contenuto non scende sotto 316; rilasciata fra 191 e 209
// torna a 200; trascinata a meno di ~65 pt dal bordo la barra si nasconde.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:silica_ui/silica_ui.dart';

import 'model.dart';

const double sidebarRow = 32;
const double sidebarTextLeft = 47;
const double sidebarIconLeft = 20;
const double sidebarIconSize = 18;
const double sidebarHeadingLeft = 17;
const double sidebarSelectionInset = 10;
const double sidebarSelectionRadius = 8;

/// La prima riga ha il centro a 68 pt dalla cima della finestra (sotto i pulsanti).
const double sidebarFirstRowCenter = 68;

/// Fra il centro di un'intestazione e quello della prima riga (MU-10, windows.md).
const double sidebarHeadingToRow = 24;

/// Fra il centro dell'ultima riga e quello dell'intestazione dopo.
const double sidebarRowToHeading = 40;

/// La larghezza delle finestre nuove (spec 2.1: 192; 200 è solo dove si aggancia).
const double sidebarDefaultWidth = 192;

/// Dove si aggancia la barra rilasciata fra 191 e 209 (MU-11).
const double sidebarSnapWidth = 200;
const double sidebarMinWidth = 135;
const double contentMinWidth = 316;

/// Rilasciata in questo intervallo la barra torna alla larghezza predefinita.
const double sidebarSnapFrom = 191;
const double sidebarSnapTo = 209;

/// Trascinata con il puntatore a meno di questa distanza dal bordo sinistro, la barra si nasconde.
const double sidebarHideBelow = 65;

/// Il chevron dell'intestazione: 10 × 6, a 31 pt dal bordo destro della barra.
const Size sidebarChevron = Size(10, 6);
const double sidebarChevronRight = 31;

/// Compressione ed espansione di una sezione (MU-11): ~190 ms dopo un ritardo.
const Duration sectionCollapse = Duration(milliseconds: 255);
const Duration sectionExpand = Duration(milliseconds: 308);
const double sectionCollapseDelay = 70 / 255;
const double sectionExpandDelay = 120 / 308;

/// Nascondere e mostrare la barra (⌃⌘S): ~240 / ~230 ms, curva a S; il mostrare parte ~40 ms
/// dopo il tasto.
const Duration sidebarHide = Duration(milliseconds: 240);
const Duration sidebarShow = Duration(milliseconds: 270);
const double sidebarShowDelay = 40 / 270;

/// I colori della barra per tema e stato della finestra (mustache-spec 2.1, 2.2: valori M3/M4
/// scelti fra le fonti; il fondo è un materiale e dipende da cosa c'è dietro).
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

  /// L'icona grigia a riposo e sotto la selezione (due misure diverse, spec 2.1).
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

/// Una sezione della barra: un titolo (vuoto: nessuna intestazione) e i suoi luoghi.
@immutable
class SidebarSection {
  const SidebarSection(this.title, this.places);
  final String title;
  final List<Place> places;
}

/// La larghezza della barra dopo un trascinamento: fra il minimo e il massimo che lascia 316 pt
/// al contenuto; 0 (nascosta) con il puntatore troppo vicino al bordo.
double dragWidth(double pointerX, double windowWidth) {
  if (pointerX < sidebarHideBelow) return 0;
  final max = math.max(sidebarMinWidth, windowWidth - contentMinWidth);
  return pointerX.clamp(sidebarMinWidth, max);
}

/// La larghezza al rilascio: vicino a 200 si aggancia a 200.
double releaseWidth(double width) =>
    width >= sidebarSnapFrom && width <= sidebarSnapTo
    ? sidebarSnapWidth
    : width;

/// Il simbolo di silica-icons per un luogo.
String symbolFor(PlaceKind kind) => switch (kind) {
  PlaceKind.home => 'house-door',
  PlaceKind.desktop => 'desktop',
  PlaceKind.documents => 'doc',
  PlaceKind.downloads => 'arrow-down-circle',
  PlaceKind.pictures => 'photo-fill',
  PlaceKind.music => 'music-note',
  PlaceKind.videos => 'film',
  PlaceKind.trash => 'trash',
};

/// La cartella home e il Cestino hanno l'icona grigia, gli altri luoghi quella d'accento.
bool accentIcon(PlaceKind kind) =>
    kind != PlaceKind.home && kind != PlaceKind.trash;

class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    required this.sections,
    required this.current,
    required this.onSelect,
    required this.colors,
    this.iconsDir,
  });

  final List<SidebarSection> sections;

  /// La cartella mostrata: la sua riga è selezionata.
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

  /// Quanto della sezione si vede (0–1), con il ritardo misurato prima del movimento.
  double _openness(String title) {
    final controller = _sections[title];
    if (controller == null) return 1;
    final collapsing = _collapsing(title);
    final delay = collapsing ? sectionCollapseDelay : sectionExpandDelay;
    // Il tempo trascorso dall'inizio, in frazione della durata.
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
        // L'intestazione occupa 32 pt con il testo centrato a 24 dalla cima: 40 dal centro
        // dell'ultima riga di prima, 24 dal centro della prima riga dopo.
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
        key: ValueKey('intestazione $title'),
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
            // Il chevron compare al passaggio, senza ritardo né dissolvenza (MU-11).
            if (hovered)
              Positioned(
                right: sidebarChevronRight - 4,
                top: 24 - 10,
                width: sidebarChevron.width + 8,
                height: 20,
                child: GestureDetector(
                  key: ValueKey('comprimi $title'),
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
    final selected = place.path == widget.current;
    return GestureDetector(
      key: ValueKey('luogo ${place.path}'),
      onTap: () => widget.onSelect(place),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: sidebarRow,
        child: Stack(
          children: [
            if (selected)
              Positioned.fill(
                left: sidebarSelectionInset,
                right: sidebarSelectionInset,
                child: DecoratedBox(
                  key: const ValueKey('selezione della barra'),
                  decoration: BoxDecoration(
                    color: colors.selection,
                    borderRadius: BorderRadius.circular(sidebarSelectionRadius),
                  ),
                ),
              ),
            Positioned(
              left: sidebarIconLeft,
              top: (sidebarRow - sidebarIconSize) / 2,
              width: sidebarIconSize,
              height: sidebarIconSize,
              child: _symbol(
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
                    place.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _text(
                      13.75,
                      selected ? colors.selectedText : colors.text,
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

  /// Il simbolo di silica-icons (`symbols/regular`); niente se le icone non ci sono.
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

/// ∨ (sezione aperta) o › (compressa): cambia subito, senza rotazione (MU-11).
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

/// Il bordo destro della barra: trascinandolo cambia la larghezza (freccia doppia, anche al
/// minimo).
class SidebarDivider extends StatelessWidget {
  const SidebarDivider({
    super.key,
    required this.onDrag,
    required this.onRelease,
  });

  /// La x del puntatore nella finestra.
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
