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

class MustacheToolbar extends StatelessWidget {
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
  });

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

  /// Il simbolo di silica-icons in un riquadro di `side` (i simboli disegnano in 24 il segno di
  /// 16–20: il riquadro è scelto perché il segno abbia le misure della barra).
  Widget _symbol(String name, double side, String fallback) => SizedBox(
    width: side,
    height: side,
    child: Builder(
      builder: (context) {
        final color = DefaultTextStyle.of(context).style.color;
        final dir = iconsDir;
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
  Widget build(BuildContext context) => WindowDragArea(
    child: SizedBox(
      key: const ValueKey('barra degli strumenti'),
      height: toolbarHeight,
      child: LayoutBuilder(
        builder: (context, box) {
          // Al restringersi escono prima le viste, poi Indietro/Avanti (spec 1.2, R1.7).
          final room = box.maxWidth - leading;
          final views = view != null && room >= 75 + 12 + 160 + 162 + 8 + 38;
          final navigation = room >= 75 + 12 + toolbarTitleMin + 38 + 14;
          return Row(
            children: [
              SizedBox(width: leading),
              if (navigation) ...[
                ToolbarCapsule(
                  key: const ValueKey('indietro e avanti'),
                  separators: true,
                  children: [
                    ToolbarSegment(
                      key: const ValueKey('indietro'),
                      width: 36,
                      enabled: canGoBack,
                      onTap: onBack,
                      icon: _icon('chevron-left', 24, '‹'),
                    ),
                    ToolbarSegment(
                      key: const ValueKey('avanti'),
                      width: 36,
                      enabled: canGoForward,
                      onTap: onForward,
                      icon: _icon('chevron-right', 24, '›'),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  key: const ValueKey('titolo'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: uiFontFamily,
                    package: 'silica_ui',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? ToolbarColors.title
                        : ToolbarColors.titleInactive,
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
                        chosen: mode == view,
                        onTap: () => onView(mode),
                        icon: _icon(symbol, side, fallback),
                      ),
                  ],
                ),
              const SizedBox(width: 8),
              searchField ??
                  ToolbarCapsule(
                    key: const ValueKey('cerca'),
                    children: [
                      ToolbarSegment(
                        width: toolbarCapsuleHeight - 2,
                        onTap: onSearch,
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
