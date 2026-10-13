// La finestra di Mustache: barra laterale a sinistra (sidebar.dart), a destra l'intestazione con
// la navigazione e la vista a elenco. Intestazione e vista a elenco sono provvisorie (MU-02,
// MU-20): l'intestazione vera sarà la barra degli strumenti unificata con quella della finestra
// (docs/spec.md, "Aperto").

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'model.dart';
import 'settings.dart';
import 'icon_view.dart';
import 'sidebar.dart';

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

class ToggleSidebarIntent extends Intent {
  const ToggleSidebarIntent();
}

class SetViewIntent extends Intent {
  const SetViewIntent(this.view);
  final ViewMode view;
}

/// Le direzioni delle frecce: nell'elenco su e giù, nella griglia anche a destra e sinistra.
enum Move { up, down, left, right }

class MoveSelectionIntent extends Intent {
  const MoveSelectionIntent(this.move);
  final Move move;
}

/// La vista dei contenuti (spec 3–6): a icone (⌘1) o a elenco (⌘2).
enum ViewMode { icons, list }

class MustacheWindow extends StatefulWidget {
  const MustacheWindow({
    super.key,
    required this.start,
    required this.places,
    required this.trash,
    this.iconsDir,
    this.now,
    this.open,
    this.settings,
    this.active = true,
    this.iconsEnv,
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

  /// Le impostazioni che restano fra un avvio e l'altro (la larghezza della barra laterale).
  final Settings? settings;

  /// La finestra ha il focus: i colori della barra laterale cambiano quando non ce l'ha.
  final bool active;

  /// L'ambiente in cui cercare silica-icons (test); null: quello del processo.
  final Map<String, String>? iconsEnv;

  @override
  State<MustacheWindow> createState() => _MustacheWindowState();
}

class _MustacheWindowState extends State<MustacheWindow>
    with SingleTickerProviderStateMixin {
  late final History _history = History(widget.start);

  /// La larghezza della barra laterale quando si vede; le finestre nuove prendono l'ultima.
  late double _sidebarWidth =
      widget.settings?.sidebarWidth ?? sidebarDefaultWidth;

  /// 1: barra visibile, 0: nascosta (⌃⌘S o trascinata contro il bordo).
  late final AnimationController _sidebarShown = AnimationController(
    vsync: this,
    duration: sidebarShow,
    reverseDuration: sidebarHide,
    value: 1,
  )..addListener(() => setState(() {}));
  bool _resizing = false;

  late ViewMode _view = ViewMode.values.firstWhere(
    (v) => v.name == widget.settings?.view,
    orElse: () => ViewMode.icons,
  );

  /// La larghezza dell'area dei contenuti all'ultimo disegno (per le frecce nella griglia).
  double _contentWidth = 800;
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
    _sidebarShown.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    if (_sidebarShown.status == AnimationStatus.reverse ||
        _sidebarShown.value == 0) {
      _sidebarShown.forward();
    } else {
      _sidebarShown.reverse();
    }
  }

  /// Quanto si vede la barra (0–1): curva a S; il mostrare parte con ~40 ms di ritardo.
  double get _sidebarProgress {
    final value = _sidebarShown.value;
    if (_sidebarShown.status == AnimationStatus.forward) {
      final t = ((value - sidebarShowDelay) / (1 - sidebarShowDelay)).clamp(
        0.0,
        1.0,
      );
      return Curves.easeInOut.transform(t);
    }
    return Curves.easeInOut.transform(value);
  }

  void _dragSidebar(double x, double windowWidth) {
    final width = dragWidth(x, windowWidth);
    setState(() {
      _resizing = true;
      if (width == 0) {
        _sidebarShown.value = 0;
      } else {
        _sidebarShown.value = 1;
        _sidebarWidth = width;
      }
    });
  }

  void _releaseSidebar() {
    setState(() {
      _resizing = false;
      _sidebarWidth = releaseWidth(_sidebarWidth);
    });
    widget.settings?.sidebarWidth = _sidebarWidth;
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

  void _moveSelection(Move move) {
    final columns = _view == ViewMode.icons
        ? iconGrid(_contentWidth).columns
        : 1;
    final delta = switch (move) {
      Move.up => -columns,
      Move.down => columns,
      Move.left => _view == ViewMode.icons ? -1 : 0,
      Move.right => _view == ViewMode.icons ? 1 : 0,
    };
    if (delta == 0) return;
    _moveBy(delta);
  }

  void _setView(ViewMode view) {
    setState(() => _view = view);
    widget.settings?.view = view.name;
  }

  void _moveBy(int delta) {
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
        SingleActivator(LogicalKeyboardKey.keyS, control: true, meta: true):
            ToggleSidebarIntent(),
        SingleActivator(LogicalKeyboardKey.arrowDown): MoveSelectionIntent(
          Move.down,
        ),
        SingleActivator(LogicalKeyboardKey.arrowUp): MoveSelectionIntent(
          Move.up,
        ),
        SingleActivator(LogicalKeyboardKey.arrowLeft): MoveSelectionIntent(
          Move.left,
        ),
        SingleActivator(LogicalKeyboardKey.arrowRight): MoveSelectionIntent(
          Move.right,
        ),
        SingleActivator(LogicalKeyboardKey.digit1, meta: true): SetViewIntent(
          ViewMode.icons,
        ),
        SingleActivator(LogicalKeyboardKey.digit2, meta: true): SetViewIntent(
          ViewMode.list,
        ),
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
          ToggleSidebarIntent: CallbackAction<ToggleSidebarIntent>(
            onInvoke: (_) {
              _toggleSidebar();
              return null;
            },
          ),
          SetViewIntent: CallbackAction<SetViewIntent>(
            onInvoke: (intent) {
              _setView(intent.view);
              return null;
            },
          ),
          MoveSelectionIntent: CallbackAction<MoveSelectionIntent>(
            onInvoke: (intent) {
              _moveSelection(intent.move);
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final windowWidth = constraints.maxWidth;
              // Nascondendosi la barra scorre a sinistra (resta larga uguale) e il contenuto
              // si allarga.
              final shown = _resizing ? _sidebarShown.value : _sidebarProgress;
              final visible = _sidebarWidth * shown;
              final dark =
                  MediaQuery.maybePlatformBrightnessOf(context) ==
                  Brightness.dark;
              return Stack(
                children: [
                  Positioned(
                    left: visible - _sidebarWidth,
                    top: 0,
                    bottom: 0,
                    width: _sidebarWidth,
                    child: Sidebar(
                      sections: [
                        SidebarSection('Preferiti', [
                          for (final place in widget.places)
                            if (place.kind != PlaceKind.home) place,
                        ]),
                        SidebarSection('Posizioni', [
                          for (final place in widget.places)
                            if (place.kind == PlaceKind.home) place,
                          widget.trash,
                        ]),
                      ],
                      current: _history.current,
                      onSelect: (place) => _navigate(place.path),
                      colors: SidebarColors.of(
                        dark: dark,
                        active: widget.active,
                      ),
                      iconsDir: widget.iconsDir,
                    ),
                  ),
                  Positioned(
                    left: visible,
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: ColoredBox(
                      color: contentFill,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(),
                          if (_view == ViewMode.list) _columnsHeader(),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, box) {
                                _contentWidth = box.maxWidth;
                                return _view == ViewMode.icons
                                    ? _icons()
                                    : _list();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Il bordo trascinabile, anche a barra nascosta (la si riapre tirandola).
                  Positioned(
                    left: visible - 3,
                    top: 0,
                    bottom: 0,
                    width: 6,
                    child: SidebarDivider(
                      key: const ValueKey('bordo della barra'),
                      onDrag: (x) => _dragSidebar(x, windowWidth),
                      onRelease: _releaseSidebar,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
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

  Widget _icons() {
    if (_error != null || _entries.isEmpty) return _list();
    return IconView(
      entries: _entries,
      selected: _selected,
      active: widget.active,
      env: widget.iconsEnv,
      onTap: _tap,
      onOpen: _openEntry,
      onBackground: () => setState(() {
        _selected.clear();
        _anchor = null;
      }),
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
