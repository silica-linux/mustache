// La barra degli strumenti unificata con la finestra (MU-02, mustache-spec 1.2): alta 52 dalla
// cima, a destra della barra laterale, senza fondo; Ossido mette sopra i pulsanti della finestra
// (silica-window-v1). Capsula Indietro/Avanti (75), titolo da 12 pt dopo, gruppo delle viste
// (162) e Cerca (cerchio di 38) a destra, 7–8 pt fra le capsule. Il vuoto sposta la finestra.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:silica_ui/silica_ui.dart';

import 'model.dart';

/// Larghezza minima del titolo (spec 1.2).
const double toolbarTitleMin = 160;

/// I pulsanti della finestra finiscono a x 79 (centri 26/49/72, diametro 14): a barra laterale
/// nascosta la barra degli strumenti parte da qui.
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

  /// Il fondo della barra; in scuro, con il puntatore nella barra, `#2e3030` (MU-07).
  final Color? background;

  /// Pressione lunga su Indietro / Avanti: il menu della cronologia, con l'angolo in alto a
  /// sinistra sul bordo sinistro del segmento, 2 pt sopra il fondo della capsula (MU-07).
  final ValueChanged<Offset>? onBackHistory;
  final ValueChanged<Offset>? onForwardHistory;

  /// Lo spazio a sinistra prima della prima capsula.
  final double leading;
  final String title;

  /// Finestra attiva: titolo scuro.
  final bool active;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;

  /// La vista scelta (null: nessun gruppo delle viste, come nella ricerca).
  final ViewMode? view;
  final ValueChanged<ViewMode> onView;
  final VoidCallback onSearch;

  /// Il campo della ricerca al posto del cerchio di Cerca.
  final Widget? searchField;
  final String? iconsDir;

  @override
  State<MustacheToolbar> createState() => _MustacheToolbarState();
}

class _MustacheToolbarState extends State<MustacheToolbar> {
  bool _hovered = false;

  /// L'angolo del menu della cronologia sotto il segmento `index` (0 Indietro, 1 Avanti).
  void _history(int index) {
    final callback = index == 0
        ? widget.onBackHistory
        : widget.onForwardHistory;
    final box = context.findRenderObject();
    if (callback == null || box is! RenderBox) return;
    // Capsula da y 7, alta 38; segmenti da 36 dopo il contorno di 1 pt e il separatore.
    final x = widget.leading + 1 + index * 37;
    callback(box.localToGlobal(Offset(x, 7 + toolbarCapsuleHeight - 2)));
  }

  /// Il simbolo di silica-icons in un riquadro di `side` (i simboli disegnano in 24 il segno di
  /// 16–20: il riquadro è scelto perché il segno abbia le misure della barra).
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

  /// L'icona nel colore del segmento.
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
      key: const ValueKey('barra degli strumenti'),
      height: toolbarHeight,
      child: LayoutBuilder(
        builder: (context, box) {
          // Al restringersi escono prima le viste, poi Indietro/Avanti (spec 1.2, R1.7).
          final room = box.maxWidth - widget.leading;
          final views =
              widget.view != null && room >= 75 + 12 + 160 + 162 + 8 + 38;
          final navigation = room >= 75 + 12 + toolbarTitleMin + 38 + 14;
          return Row(
            children: [
              SizedBox(width: widget.leading),
              if (navigation) ...[
                ToolbarCapsule(
                  key: const ValueKey('indietro e avanti'),
                  separators: true,
                  children: [
                    ToolbarSegment(
                      key: const ValueKey('indietro'),
                      width: 36,
                      enabled: widget.canGoBack,
                      onTap: widget.onBack,
                      onLongPress: widget.onBackHistory == null
                          ? null
                          : () => _history(0),
                      icon: _icon('chevron-left', 24, '‹'),
                    ),
                    ToolbarSegment(
                      key: const ValueKey('avanti'),
                      width: 36,
                      enabled: widget.canGoForward,
                      onTap: widget.onForward,
                      onLongPress: widget.onForwardHistory == null
                          ? null
                          : () => _history(1),
                      icon: _icon('chevron-right', 24, '›'),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
              // Il titolo non sposta la finestra; il vuoto accanto sì (MU-08).
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) {},
                    child: Text(
                      widget.title,
                      key: const ValueKey('titolo'),
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
                  key: const ValueKey('gruppo delle viste'),
                  children: [
                    for (final (mode, symbol, side, fallback) in const [
                      // Griglia 15, elenco 17 × 12, colonne 20 × 15, galleria 19 × 15.
                      (ViewMode.icons, 'square-grid-2x2', 20.0, '▦'),
                      (ViewMode.list, 'list-bullet', 24.0, '≡'),
                      (ViewMode.columns, 'window-split-3', 24.0, '▥'),
                      (ViewMode.gallery, 'gallery', 24.0, '▭'),
                    ])
                      ToolbarSegment(
                        key: ValueKey('vista ${mode.name}'),
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
                    key: const ValueKey('cerca'),
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
