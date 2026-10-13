// La finestra di Mustache: barra laterale a sinistra, a destra l'intestazione con la
// navigazione e la vista a elenco.
//
// Misure della barra laterale (MU-10 per quelle che mancano): larga 192 pt, dalla cima al fondo
// della finestra, righe a passo 32, testo a 47 pt dal bordo, icone fra 20 e 38 pt,
// intestazioni di sezione a 17 pt in semibold grigio; fondo chiaro `#e5e5e7`, contenuto
// bianco, nessuna linea fra i due. Intestazione e vista a elenco sono provvisorie (MU-02,
// MU-20): l'intestazione vera sarà la barra degli strumenti unificata con quella della
// finestra (docs/spec.md, "Aperto").

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:silica_ui/silica_ui.dart';

import 'model.dart';

const double sidebarWidth = 192;
const double sidebarRow = 32;
const double sidebarTextLeft = 47;
const double sidebarIconLeft = 20;
const double sidebarIconSize = 18;
const double sidebarHeadingLeft = 17;
const Color sidebarFill = Color(0xFFE5E5E7);
const Color sidebarHeading = Color(0xFF808182);
const Color accent = Color(0xFF0075F2);
const Color textColor = Color(0xFF000000);
const Color secondaryText = Color(0xFF808182);
const Color contentFill = Color(0xFFFFFFFF);

/// Provvisori (MU-20): righe da 24 pt, intestazione delle colonne da 28.
const double listRow = 24;
const double listHeader = 28;
const double headerHeight = 38;
const Color selectionFill = accent;
const Color selectionText = Color(0xFFFFFFFF);

TextStyle text(double size, {Color color = textColor, FontWeight? weight}) =>
    TextStyle(
      fontFamily: uiFontFamily,
      package: 'silica_ui',
      fontSize: size,
      fontWeight: weight,
      color: color,
    );

/// Intenti delle scorciatoie della finestra (comandi `mustache.*`, docs/spec.md).
class OpenIntent extends Intent {
  const OpenIntent();
}

class ParentIntent extends Intent {
  const ParentIntent();
}

class BackIntent extends Intent {
  const BackIntent();
}

class ForwardIntent extends Intent {
  const ForwardIntent();
}

class ToggleHiddenIntent extends Intent {
  const ToggleHiddenIntent();
}

class MoveSelectionIntent extends Intent {
  const MoveSelectionIntent(this.delta);
  final int delta;
}

class MustacheWindow extends StatefulWidget {
  const MustacheWindow({
    super.key,
    required this.start,
    required this.places,
    required this.trash,
    this.iconsDir,
    this.now,
    this.open,
  });

  final String start;
  final List<Place> places;
  final Place trash;

  /// La cartella di silica-icons (`SILICA_ICONS_DIR`): i simboli della barra laterale.
  final String? iconsDir;

  /// Ora fissa (test).
  final DateTime? now;

  /// Apre un file con l'app predefinita (test: registra la chiamata).
  final void Function(String path)? open;

  @override
  State<MustacheWindow> createState() => _MustacheWindowState();
}

class _MustacheWindowState extends State<MustacheWindow> {
  late final History _history = History(widget.start);
  final FocusNode _focus = FocusNode();
  List<Entry> _entries = const [];
  String? _error;
  bool _showHidden = false;
  SortKey _sort = SortKey.name;
  bool _descending = false;
  final Set<String> _selected = {};
  String? _anchor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _load() {
    // Il titolo della finestra è il nome della cartella (l'embedder di Silica lo passa a
    // Ossido; fuori da Silica la chiamata non fa niente).
    SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(label: displayName(_history.current)),
    );
    final result = listDirectory(_history.current, showHidden: _showHidden);
    setState(() {
      _entries = sortEntries(result.entries, _sort, descending: _descending);
      _error = result.error;
      _selected.removeWhere((path) => !_entries.any((e) => e.path == path));
    });
  }

  void _navigate(String path) {
    _history.go(path);
    _selected.clear();
    _anchor = null;
    _load();
  }

  void _openEntry(Entry entry) {
    if (entry.isDirectory) {
      _navigate(entry.path);
    } else {
      (widget.open ?? _xdgOpen)(entry.path);
    }
  }

  static void _xdgOpen(String path) {
    Process.start('xdg-open', [path], mode: ProcessStartMode.detached).ignore();
  }

  void _openSelection() {
    final selected = _entries.where((e) => _selected.contains(e.path));
    if (selected.length == 1) _openEntry(selected.first);
  }

  void _moveSelection(int delta) {
    if (_entries.isEmpty) return;
    final current = _entries.indexWhere((e) => e.path == _anchor);
    final next = current < 0
        ? (delta > 0 ? 0 : _entries.length - 1)
        : (current + delta).clamp(0, _entries.length - 1);
    setState(() {
      _anchor = _entries[next].path;
      _selected
        ..clear()
        ..add(_anchor!);
    });
  }

  void _tap(Entry entry) {
    final keys = HardwareKeyboard.instance;
    setState(() {
      if (keys.isMetaPressed || keys.isControlPressed) {
        _selected.contains(entry.path)
            ? _selected.remove(entry.path)
            : _selected.add(entry.path);
        _anchor = entry.path;
      } else if (keys.isShiftPressed && _anchor != null) {
        final a = _entries.indexWhere((e) => e.path == _anchor);
        final b = _entries.indexOf(entry);
        if (a >= 0) {
          _selected
            ..clear()
            ..addAll([
              for (var i = a < b ? a : b; i <= (a < b ? b : a); i++)
                _entries[i].path,
            ]);
        }
      } else {
        _selected
          ..clear()
          ..add(entry.path);
        _anchor = entry.path;
      }
    });
    _focus.requestFocus();
  }

  void _sortBy(SortKey key) {
    setState(() {
      _descending = _sort == key && !_descending;
      _sort = key;
      _entries = sortEntries(_entries, _sort, descending: _descending);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowDown, meta: true): OpenIntent(),
        SingleActivator(LogicalKeyboardKey.arrowUp, meta: true): ParentIntent(),
        SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true):
            BackIntent(),
        SingleActivator(LogicalKeyboardKey.bracketRight, meta: true):
            ForwardIntent(),
        SingleActivator(LogicalKeyboardKey.period, meta: true, shift: true):
            ToggleHiddenIntent(),
        SingleActivator(LogicalKeyboardKey.arrowDown): MoveSelectionIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): MoveSelectionIntent(-1),
      },
      child: Actions(
        actions: {
          OpenIntent: CallbackAction<OpenIntent>(
            onInvoke: (_) => _openSelection(),
          ),
          ParentIntent: CallbackAction<ParentIntent>(
            onInvoke: (_) {
              final parent = parentOf(_history.current);
              if (parent != null) _navigate(parent);
              return null;
            },
          ),
          BackIntent: CallbackAction<BackIntent>(
            onInvoke: (_) {
              if (_history.back()) _load();
              return null;
            },
          ),
          ForwardIntent: CallbackAction<ForwardIntent>(
            onInvoke: (_) {
              if (_history.forward()) _load();
              return null;
            },
          ),
          ToggleHiddenIntent: CallbackAction<ToggleHiddenIntent>(
            onInvoke: (_) {
              _showHidden = !_showHidden;
              _load();
              return null;
            },
          ),
          MoveSelectionIntent: CallbackAction<MoveSelectionIntent>(
            onInvoke: (intent) {
              _moveSelection(intent.delta);
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: sidebarWidth, child: _sidebar()),
              Expanded(
                child: ColoredBox(
                  color: contentFill,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(),
                      _columnsHeader(),
                      Expanded(child: _list()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sidebar() {
    Widget heading(String label) => SizedBox(
      height: sidebarRow,
      child: Padding(
        padding: const EdgeInsets.only(left: sidebarHeadingLeft, top: 14),
        child: Text(
          label,
          style: text(11.5, color: sidebarHeading, weight: FontWeight.w600),
        ),
      ),
    );
    Widget row(Place place) {
      final selected = place.path == _history.current;
      return GestureDetector(
        key: ValueKey('luogo ${place.path}'),
        onTap: () => _navigate(place.path),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: sidebarRow,
          child: Stack(
            children: [
              if (selected)
                // Selezione provvisoria (MU-10): rettangolo grigio arrotondato.
                Positioned.fill(
                  left: 10,
                  right: 10,
                  top: 2,
                  bottom: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x1A000000),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              Positioned(
                left: sidebarIconLeft,
                top: (sidebarRow - sidebarIconSize) / 2,
                width: sidebarIconSize,
                height: sidebarIconSize,
                child: _symbol(place.kind),
              ),
              Positioned(
                left: sidebarTextLeft,
                right: 8,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    place.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text(13.75),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: sidebarFill,
      child: ListView(
        padding: const EdgeInsets.only(top: 44),
        children: [
          heading('Preferiti'),
          for (final place in widget.places) row(place),
          const SizedBox(height: 8),
          heading('Posizioni'),
          row(widget.trash),
        ],
      ),
    );
  }

  /// Il simbolo di silica-icons per un luogo, nel colore d'accento; niente se le icone non
  /// ci sono.
  Widget _symbol(PlaceKind kind) {
    final dir = widget.iconsDir;
    if (dir == null) return const SizedBox.shrink();
    final name = switch (kind) {
      PlaceKind.home => 'house',
      PlaceKind.desktop => 'display',
      PlaceKind.documents => 'doc',
      PlaceKind.downloads => 'download',
      PlaceKind.pictures => 'photo',
      PlaceKind.music => 'music-note',
      PlaceKind.videos => 'film',
      PlaceKind.trash => 'trash',
    };
    final file = File('$dir/symbols/$name.svg');
    if (!file.existsSync()) return const SizedBox.shrink();
    final color = kind == PlaceKind.trash ? const Color(0xFF7C7C82) : accent;
    return SvgPicture.file(
      file,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  Widget _header() {
    Widget button(String label, bool enabled, VoidCallback onTap) =>
        GestureDetector(
          onTap: enabled ? onTap : null,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 28,
            child: Center(
              child: Text(
                label,
                style: text(
                  20,
                  color: enabled ? textColor : const Color(0xFFABABAB),
                ),
              ),
            ),
          ),
        );
    return SizedBox(
      height: headerHeight,
      child: Row(
        children: [
          const SizedBox(width: 8),
          button('‹', _history.canGoBack, () {
            if (_history.back()) _load();
          }),
          button('›', _history.canGoForward, () {
            if (_history.forward()) _load();
          }),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              displayName(_history.current),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text(
                15,
                color: const Color(0xFF4D4D4D),
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const List<(SortKey, String, int)> _columns = [
    (SortKey.name, 'Nome', 5),
    (SortKey.modified, 'Data di modifica', 3),
    (SortKey.size, 'Dimensione', 2),
    (SortKey.kind, 'Tipo', 2),
  ];

  Widget _columnsHeader() {
    return SizedBox(
      height: listHeader,
      child: Row(
        children: [
          for (final (key, label, flex) in _columns)
            Expanded(
              flex: flex,
              child: GestureDetector(
                onTap: () => _sortBy(key),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _sort == key
                          ? '$label ${_descending ? '↓' : '↑'}'
                          : label,
                      style: text(
                        11.5,
                        color: secondaryText,
                        weight: _sort == key ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _list() {
    if (_error != null) {
      return Center(
        child: Text(
          'Non si può aprire: $_error',
          style: text(13, color: secondaryText),
        ),
      );
    }
    if (_entries.isEmpty) {
      return Center(
        child: Text('Cartella vuota', style: text(13, color: secondaryText)),
      );
    }
    final now = widget.now ?? DateTime.now();
    return ListView.builder(
      itemCount: _entries.length,
      itemExtent: listRow,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final selected = _selected.contains(entry.path);
        final color = selected ? selectionText : textColor;
        final secondary = selected ? selectionText : secondaryText;
        final cells = [
          entry.isDirectory ? '${entry.name}/' : entry.name,
          formatDate(entry.modified, now),
          formatSize(entry),
          kindLabel(entry),
        ];
        return GestureDetector(
          key: ValueKey(entry.path),
          onTap: () => _tap(entry),
          onDoubleTap: () => _openEntry(entry),
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? selectionFill : null,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: [
                for (var i = 0; i < _columns.length; i++)
                  Expanded(
                    flex: _columns[i].$3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        cells[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text(13, color: i == 0 ? color : secondary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
