// La finestra di Mustache: barra laterale a sinistra (sidebar.dart) dalla cima al fondo, a destra
// la barra degli strumenti unificata con la finestra (toolbar.dart) e la vista dei contenuti.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'model.dart';
import 'settings.dart';
import 'apps.dart';
import 'column_view.dart';
import 'dialog.dart';
import 'drag.dart';
import 'gallery_view.dart';
import 'icon_view.dart';
import 'info.dart';
import 'list_view.dart';
import 'operations.dart';
import 'path_bar.dart';
import 'preview_pane.dart';
import 'quick_look.dart';
import 'status_bar.dart';
import 'rename_field.dart';
import 'transfer.dart';
import 'transfer_ui.dart';
import 'xattr.dart';
import 'sidebar.dart';
import 'tags.dart';
import 'toolbar.dart';

part 'window_columns.dart';
part 'window_context.dart';
part 'window_dialog.dart';
part 'window_drag.dart';
part 'window_list.dart';
part 'window_operations.dart';
part 'window_search.dart';
part 'window_tags.dart';
part 'window_transfers.dart';

const Color accent = Color(0xFF0075F2);
const Color textColor = Color(0xFF000000);
const Color secondaryText = Color(0xFF808182);
const Color contentFill = Color(0xFFFFFFFF);

/// I colori di fondo e del testo della finestra, chiaro e scuro (mustache.md MU-20, MU-03,
/// MU-04: contenuto `#272728`, barra degli strumenti e intestazione `#2f2f2f` in scuro).
@immutable
class WindowColors {
  const WindowColors({
    required this.content,
    required this.text,
    required this.secondary,
  });

  final Color content;
  final Color text;
  final Color secondary;

  static const WindowColors light = WindowColors(
    content: contentFill,
    text: textColor,
    secondary: secondaryText,
  );

  static const WindowColors dark = WindowColors(
    content: Color(0xFF272728),
    text: Color(0xFFDFDFE0),
    secondary: Color(0xFF9E9E9E),
  );

  static WindowColors of(BuildContext context) =>
      MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark
      ? dark
      : light;
}

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

/// Mostra o nasconde una parte della finestra.
enum WindowPart { statusBar, previewPane }

class TogglePartIntent extends Intent {
  const TogglePartIntent(this.part);
  final WindowPart part;
}

class NewWindowIntent extends Intent {
  const NewWindowIntent();
}

class SearchIntent extends Intent {
  const SearchIntent();
}

class InfoIntent extends Intent {
  const InfoIntent();
}

class QuickLookIntent extends Intent {
  const QuickLookIntent();
}

class CloseIntent extends Intent {
  const CloseIntent();
}

class TogglePathBarIntent extends Intent {
  const TogglePathBarIntent();
}

class SetViewIntent extends Intent {
  const SetViewIntent(this.view);
  final ViewMode view;
}

/// Le direzioni delle frecce: nell'elenco su e giù, nella griglia anche a destra e sinistra.
enum Move { up, down, left, right }

/// Una delle operazioni sui file (MU.4), con la sua scorciatoia.
enum FileCommand {
  rename,
  newFolder,
  duplicate,
  trash,
  delete,
  undo,
  redo,
  copy,
  paste,
  move,
}

class FileCommandIntent extends Intent {
  const FileCommandIntent(this.command);
  final FileCommand command;
}

class MoveSelectionIntent extends Intent {
  const MoveSelectionIntent(this.move, {this.extend = false});
  final Move move;

  /// Con ⇧: la selezione si allunga dall'àncora (R7.6).
  final bool extend;
}

/// La voce .desktop di Mustache (per aprire altre finestre).
const String mustacheDesktopId = 'dev.frascella.Mustache.desktop';

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
    this.tabBar,
    this.onLocation,
    this.focused = true,
    this.dialog,
    this.onDialogFinish,
  });

  /// La finestra è un dialogo Apri o Salva per il portale (null: la finestra normale).
  final DialogOptions? dialog;

  /// Come finisce il dialogo (test); null: scrive sullo stdout ed esce.
  final void Function(List<String> paths)? onDialogFinish;

  /// La scheda è quella attiva: diventandolo riprende la tastiera.
  final bool focused;

  /// La barra delle schede (dal [TabsHost], null con una sola scheda): sotto l'intestazione,
  /// sopra i contenuti.
  final Widget? tabBar;

  /// Dove si trova la finestra (il titolo della sua scheda).
  final ValueChanged<String>? onLocation;

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

  /// La finestra è quella attiva per Ossido: l'embedder lo dice con `flutter/lifecycle`
  /// (`resumed` attiva, `inactive` no; senza notizie, attiva).
  bool _windowActive = _isActive(WidgetsBinding.instance.lifecycleState);
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onStateChange: (state) {
      final active = _isActive(state);
      if (active != _windowActive) setState(() => _windowActive = active);
    },
  );

  static bool _isActive(AppLifecycleState? state) =>
      state == null || state == AppLifecycleState.resumed;

  /// Attiva per Ossido e, con le schede, la scheda in primo piano.
  bool get _active => widget.active && _windowActive;

  /// Il trascinamento fra app: l'immagine da dare a Ossido, se è già uscito, e i rilasci.
  final GlobalKey _dragImageKey = GlobalKey();
  bool _draggedOut = false;
  StreamSubscription<SilicaDragEvent>? _externalDrags;

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

  /// Il cursore delle frecce (l'àncora resta dove è iniziata la selezione con ⇧) e la
  /// selezione all'inizio del rettangolo.
  String? _cursor;
  Set<String>? _bandBase;

  late final Trash _trash = Trash(
    parentOf(widget.trash.path) ?? widget.trash.path,
  );
  final UndoStack _undo = UndoStack();

  /// L'elemento in rinomina, l'attesa del clic lento e l'avviso aperto.
  String? _renaming;
  Timer? _slowClick;
  Widget? _alert;

  /// Le app (lette alla prima apertura con un'app), i tipi MIME e il menu contestuale aperto.
  AppRegistry? _apps;
  final Map<String, String> _types = {};
  Offset? _menuAt;
  List<MenuEntry> _menuEntries = const [];

  /// Le copie in corso, quella con la finestra di avanzamento e il conflitto in attesa.
  final List<Transfer> _transfers = [];
  Transfer? _progress;
  ({String name, bool moving, Completer<ConflictChoice> done})? _conflict;

  /// Le etichette lette in questo caricamento; l'etichetta mostrata (vista dei risultati) e la
  /// ricerca in corso.
  final Map<String, List<String>> _tagCache = {};
  String? _tagView;
  int _tagSearch = 0;

  /// Le finestre Informazioni aperte (percorsi) e le loro sezioni aperte (per tutte).
  final List<String> _infos = [];
  late final Set<InfoSection> _infoOpen = {
    for (final name
        in widget.settings?.infoSections ??
            const ['general', 'name', 'preview'])
      ?InfoSection.values.where((s) => s.name == name).firstOrNull,
  };

  /// La ricerca: attiva, il campo, l'ambito, la cartella di partenza, l'attesa e il giro in
  /// corso.
  bool _searching = false;
  final TextEditingController _searchQuery = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  SearchScope _searchScope = SearchScope.computer;
  String _searchFolder = '/';
  Timer? _searchTimer;
  int _searchToken = 0;

  /// Barra di stato, pannello di anteprima, lato delle icone, spazio libero.
  // Nei dialoghi niente barre né pannello (R14.6).
  late bool _statusBar =
      widget.dialog == null && (widget.settings?.statusBar ?? false);
  late bool _previewPane =
      widget.dialog == null && (widget.settings?.previewPane ?? false);
  late double _iconSide = widget.settings?.iconSide ?? defaultIconSide;
  int? _free;

  /// Il nome del file del dialogo Salva.
  late final TextEditingController _saveName = TextEditingController(
    text: widget.dialog?.name ?? '',
  );
  final FocusNode _saveFocus = FocusNode();

  /// La visualizzazione rapida aperta (Spazio).
  bool _quickLook = false;

  /// La barra del percorso (⌥⌘P), ricordata per le finestre nuove.
  late bool _pathBar =
      widget.dialog == null && (widget.settings?.pathBar ?? false);

  /// Il contenuto delle colonne, letto una volta per caricamento.
  final Map<String, List<Entry>> _columnCache = {};

  // Nei dialoghi si parte a colonne, e la galleria non c'è (R14.5, R14.6).
  late ViewMode _view = widget.dialog != null
      ? ViewMode.columns
      : ViewMode.values.firstWhere(
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

  /// Le colonne dell'elenco, allargate trascinando i separatori (R3.6).
  final List<double> _listWidths = [for (final c in listColumns) c.width];

  /// Le cartelle aperte nel posto nell'elenco e il loro contenuto, letto una volta.
  final Set<String> _expanded = {};
  final Map<String, List<Entry>> _childCache = {};

  /// La riga del clic destro su un elemento non scelto: l'anello, la selezione resta (R3.9).
  String? _contextRing;

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _externalDrags = SilicaDrag.events.listen((event) {
      if (event is SilicaDrop && mounted) _externalDrop(event);
    });
    _load();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _externalDrags?.cancel();
    _focus.dispose();
    _sidebarShown.dispose();
    _slowClick?.cancel();
    _searchTimer?.cancel();
    _searchQuery.dispose();
    _searchFocus.dispose();
    _saveName.dispose();
    _saveFocus.dispose();
    super.dispose();
  }

  /// L'icona dell'app negli avvisi (66 pt), da silica-icons.
  Widget? get _appIcon {
    final icon = findSilicaIcon('mustache', env: widget.iconsEnv);
    return icon == null ? null : SilicaIcon(LayeredSource(icon), side: 66);
  }

  /// ⌘N: un'altra finestra, cioè un altro processo avviato dalla voce .desktop dell'app.
  Future<void> _newWindow() async {
    final app = _registry.apps[mustacheDesktopId];
    if (app == null) {
      _showError(
        'Non si può aprire una finestra nuova.',
        'La voce di Mustache non è installata (cargo xtask install-app).',
      );
      return;
    }
    final home =
        widget.places
            .where((p) => p.kind == PlaceKind.home)
            .firstOrNull
            ?.path ??
        _history.current;
    final error = await launchApp(app, [home]);
    if (error != null && mounted) _showError(error);
  }

  @override
  void didUpdateWidget(MustacheWindow old) {
    super.didUpdateWidget(old);
    if (widget.focused && !old.focused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  /// `setState` per le operazioni in `window_operations.dart` (un'estensione non può chiamarlo).
  void _update(VoidCallback change) => setState(change);

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
      ApplicationSwitcherDescription(
        label: widget.dialog?.title.isNotEmpty ?? false
            ? widget.dialog!.title
            : displayName(_history.current),
      ),
    );
    // In ricerca si rifà la ricerca.
    if (_searching) {
      _runSearch();
      return;
    }
    // Nella vista di un'etichetta si rifà la ricerca.
    final tag = _tagView;
    if (tag != null) {
      _tagCache.clear();
      _showTag(tag);
      return;
    }
    final result = listDirectory(_history.current, showHidden: _showHidden);
    if (_statusBar) _free = freeBytes(_history.current);
    widget.onLocation?.call(_history.current);
    setState(() {
      _columnCache.clear();
      _tagCache.clear();
      _childCache.clear();
      _entries = sortEntries(
        result.entries,
        _sort,
        descending: _descending,
        kindOf: _kind,
      );
      // Le cartelle aperte che non ci sono più si dimenticano.
      _expanded.removeWhere((path) => !Directory(path).existsSync());
      _error = result.error;
      // Nelle colonne la scelta può essere la cartella aperta, che non è nel suo contenuto.
      _selected.removeWhere(
        (path) =>
            !_ordered.any((e) => e.path == path) &&
            !(_view == ViewMode.columns && entryAt(path) != null),
      );
      _galleryChoice();
    });
  }

  void _navigate(String path) {
    _tagView = null;
    if (_searching) {
      _searching = false;
      _searchToken++;
      _searchQuery.clear();
    }
    _tagSearch++;
    _history.go(path);
    _selected.clear();
    _anchor = null;
    _load();
  }

  void _openEntry(Entry entry) {
    _slowClick?.cancel();
    if (entry.isDirectory) {
      _navigate(entry.path);
    } else if (widget.dialog case final d?) {
      // Nel dialogo Apri il doppio clic su un file lo sceglie.
      if (!d.save && !d.directory) _finish([entry.path]);
    } else {
      _openWith([entry]);
    }
  }

  static void _xdgOpen(String path) {
    Process.start('xdg-open', [path], mode: ProcessStartMode.detached).ignore();
  }

  void _openSelection() {
    final selected = _entries.where((e) => _selected.contains(e.path));
    if (selected.length == 1) _openEntry(selected.first);
  }

  void _moveSelection(Move move, {bool extend = false}) {
    if (_view == ViewMode.columns) {
      _moveInColumns(move);
      return;
    }
    final columns = _view == ViewMode.icons
        ? iconGrid(_contentWidth, side: _iconSide).columns
        : 1;
    // Nell'elenco → e ← aprono e chiudono la cartella (R3.7).
    if ((move == Move.left || move == Move.right) &&
        _expandAtCursor(open: move == Move.right)) {
      return;
    }
    final across = _view == ViewMode.icons || _view == ViewMode.gallery;
    final delta = switch (move) {
      // In galleria la striscia è una riga: su e giù non la muovono.
      Move.up => _view == ViewMode.gallery ? 0 : -columns,
      Move.down => _view == ViewMode.gallery ? 0 : columns,
      Move.left => across ? -1 : 0,
      Move.right => across ? 1 : 0,
    };
    if (delta == 0) return;
    _moveBy(delta, extend: extend);
  }

  void _setView(ViewMode view) {
    // Nei dialoghi niente galleria, e la scelta non cambia quella delle finestre.
    if (widget.dialog != null) {
      if (view != ViewMode.gallery) setState(() => _view = view);
      return;
    }
    setState(() {
      _view = view;
      _galleryChoice();
    });
    widget.settings?.view = view.name;
  }

  /// In galleria c'è sempre un elemento scelto, quello in grande (mu23): senza scelta, il primo.
  void _galleryChoice() {
    if (_view != ViewMode.gallery || _searching) return;
    final shown = _cursor ?? (_selected.isEmpty ? null : _selected.last);
    if (shown != null && _entries.any((e) => e.path == shown)) return;
    if (_entries.isEmpty) return;
    _selected
      ..clear()
      ..add(_entries.first.path);
    _anchor = _cursor = _entries.first.path;
  }

  /// Le frecce: il cursore si sposta di `delta` nell'ordine di lettura. Senza ⇧ seleziona
  /// solo il cursore; con ⇧ l'intervallo lineare dall'àncora al cursore (R7.6). Oltre la prima
  /// o l'ultima riga nella griglia non succede niente.
  void _moveBy(int delta, {bool extend = false}) {
    final order = _ordered;
    if (order.isEmpty) return;
    final current = order.indexWhere((e) => e.path == (_cursor ?? _anchor));
    int next;
    if (current < 0) {
      next = delta > 0 ? 0 : order.length - 1;
    } else {
      next = current + delta;
      if (next < 0 || next >= order.length) {
        // Nella griglia, su e giù oltre il bordo non si muovono; nell'elenco si ferma lì.
        if (delta.abs() > 1) return;
        next = next.clamp(0, order.length - 1);
      }
    }
    setState(() {
      _cursor = order[next].path;
      final anchor = order.indexWhere((e) => e.path == _anchor);
      if (extend && anchor >= 0) {
        final (a, b) = anchor < next ? (anchor, next) : (next, anchor);
        _selected
          ..clear()
          ..addAll([for (var i = a; i <= b; i++) order[i].path]);
      } else {
        _anchor = _cursor;
        _selected
          ..clear()
          ..add(_cursor!);
      }
    });
  }

  /// Il rettangolo di selezione: con ⌘ o ⇧ alterna sugli elementi di partenza, sennò li
  /// sostituisce.
  void _rubberBand(Set<String> paths, {required bool done}) {
    final keys = HardwareKeyboard.instance;
    final base = _bandBase ??= keys.isMetaPressed || keys.isShiftPressed
        ? {..._selected}
        : <String>{};
    setState(() {
      _selected
        ..clear()
        ..addAll({...base.difference(paths), ...paths.difference(base)});
      _anchor = _cursor = paths.isEmpty ? _anchor : paths.last;
    });
    if (done) _bandBase = null;
  }

  void _tap(Entry entry) {
    final keys = HardwareKeyboard.instance;
    final wasOnlySelected =
        _selected.length == 1 && _selected.contains(entry.path);
    final plain =
        !keys.isMetaPressed && !keys.isControlPressed && !keys.isShiftPressed;
    _clickForRename(entry, wasOnlySelected: plain && wasOnlySelected);
    setState(() {
      // Nella vista a icone ⇧clic aggiunge o toglie come ⌘clic (R7.3).
      if (keys.isMetaPressed ||
          keys.isControlPressed ||
          (keys.isShiftPressed && _view == ViewMode.icons)) {
        _selected.contains(entry.path)
            ? _selected.remove(entry.path)
            : _selected.add(entry.path);
        _anchor = _cursor = entry.path;
      } else if (keys.isShiftPressed && _anchor != null) {
        final order = _ordered;
        final a = order.indexWhere((e) => e.path == _anchor);
        final b = order.indexWhere((e) => e.path == entry.path);
        if (a >= 0) {
          _selected
            ..clear()
            ..addAll([
              for (var i = a < b ? a : b; i <= (a < b ? b : a); i++)
                order[i].path,
            ]);
        }
      } else {
        _selected
          ..clear()
          ..add(entry.path);
        _anchor = _cursor = entry.path;
      }
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) => _OverlayHost(child: _window(context));

  Widget _window(BuildContext context) {
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
        SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
            MoveSelectionIntent(Move.down, extend: true),
        SingleActivator(LogicalKeyboardKey.arrowUp): MoveSelectionIntent(
          Move.up,
        ),
        SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
            MoveSelectionIntent(Move.up, extend: true),
        SingleActivator(LogicalKeyboardKey.arrowLeft): MoveSelectionIntent(
          Move.left,
        ),
        SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
            MoveSelectionIntent(Move.left, extend: true),
        SingleActivator(LogicalKeyboardKey.arrowRight): MoveSelectionIntent(
          Move.right,
        ),
        SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
            MoveSelectionIntent(Move.right, extend: true),
        SingleActivator(LogicalKeyboardKey.enter): FileCommandIntent(
          FileCommand.rename,
        ),
        SingleActivator(LogicalKeyboardKey.keyN, meta: true, shift: true):
            FileCommandIntent(FileCommand.newFolder),
        SingleActivator(LogicalKeyboardKey.keyD, meta: true): FileCommandIntent(
          FileCommand.duplicate,
        ),
        SingleActivator(LogicalKeyboardKey.backspace, meta: true):
            FileCommandIntent(FileCommand.trash),
        SingleActivator(LogicalKeyboardKey.backspace, meta: true, alt: true):
            FileCommandIntent(FileCommand.delete),
        SingleActivator(LogicalKeyboardKey.keyZ, meta: true): FileCommandIntent(
          FileCommand.undo,
        ),
        SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            FileCommandIntent(FileCommand.redo),
        SingleActivator(LogicalKeyboardKey.keyC, meta: true): FileCommandIntent(
          FileCommand.copy,
        ),
        SingleActivator(LogicalKeyboardKey.keyV, meta: true): FileCommandIntent(
          FileCommand.paste,
        ),
        SingleActivator(LogicalKeyboardKey.keyV, meta: true, alt: true):
            FileCommandIntent(FileCommand.move),
        SingleActivator(LogicalKeyboardKey.digit1, meta: true): SetViewIntent(
          ViewMode.icons,
        ),
        SingleActivator(LogicalKeyboardKey.digit2, meta: true): SetViewIntent(
          ViewMode.list,
        ),
        SingleActivator(LogicalKeyboardKey.digit3, meta: true): SetViewIntent(
          ViewMode.columns,
        ),
        SingleActivator(LogicalKeyboardKey.digit4, meta: true): SetViewIntent(
          ViewMode.gallery,
        ),
        SingleActivator(LogicalKeyboardKey.keyP, meta: true, alt: true):
            TogglePathBarIntent(),
        SingleActivator(LogicalKeyboardKey.space): QuickLookIntent(),
        SingleActivator(LogicalKeyboardKey.keyI, meta: true): InfoIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, meta: true): SearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyN, meta: true): NewWindowIntent(),
        SingleActivator(LogicalKeyboardKey.quoteSingle, meta: true):
            TogglePartIntent(WindowPart.statusBar),
        SingleActivator(LogicalKeyboardKey.keyP, meta: true, shift: true):
            TogglePartIntent(WindowPart.previewPane),
        SingleActivator(LogicalKeyboardKey.keyY, meta: true): QuickLookIntent(),
        SingleActivator(LogicalKeyboardKey.escape): CloseIntent(),
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
              // Dalla ricerca, Indietro torna alla cartella (R13.4).
              if (_searching) {
                _endSearch();
              } else if (_history.back()) {
                _load();
              }
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
          FileCommandIntent: CallbackAction<FileCommandIntent>(
            onInvoke: (intent) {
              if (_alert != null || _renaming != null) return null;
              switch (intent.command) {
                case FileCommand.rename:
                  if (widget.dialog != null) {
                    _acceptDialog();
                    return null;
                  }
                  final only = _selection;
                  if (only.length == 1) _startRename(only.first.path);
                case FileCommand.newFolder:
                  _newFolder();
                case FileCommand.duplicate:
                  _duplicate();
                case FileCommand.trash:
                  _moveToTrash();
                case FileCommand.delete:
                  _confirmDelete();
                case FileCommand.undo:
                  _undoLast();
                case FileCommand.redo:
                  _redoLast();
                case FileCommand.copy:
                  _copySelection();
                case FileCommand.paste:
                  _paste(move: false);
                case FileCommand.move:
                  _paste(move: true);
              }
              return null;
            },
          ),
          TogglePartIntent: CallbackAction<TogglePartIntent>(
            onInvoke: (intent) {
              setState(() {
                switch (intent.part) {
                  case WindowPart.statusBar:
                    _statusBar = !_statusBar;
                    if (_statusBar) _free = freeBytes(_history.current);
                    widget.settings?.statusBar = _statusBar;
                  case WindowPart.previewPane:
                    _previewPane = !_previewPane;
                    widget.settings?.previewPane = _previewPane;
                }
              });
              return null;
            },
          ),
          NewWindowIntent: CallbackAction<NewWindowIntent>(
            onInvoke: (_) {
              _newWindow();
              return null;
            },
          ),
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (_) {
              _startSearch();
              return null;
            },
          ),
          InfoIntent: CallbackAction<InfoIntent>(
            onInvoke: (_) {
              // La selezione, o la cartella aperta se non c'è.
              final paths = _selected.isEmpty
                  ? [_history.current]
                  : [for (final e in _selection) e.path];
              setState(() {
                for (final p in paths.take(5)) {
                  if (!_infos.contains(p)) _infos.add(p);
                }
              });
              return null;
            },
          ),
          QuickLookIntent: CallbackAction<QuickLookIntent>(
            onInvoke: (_) {
              if (_renaming != null || _alert != null) return null;
              setState(() => _quickLook = !_quickLook && _selected.isNotEmpty);
              return null;
            },
          ),
          CloseIntent: CallbackAction<CloseIntent>(
            onInvoke: (_) {
              if (_quickLook) {
                setState(() => _quickLook = false);
              } else if (widget.dialog != null && _alert == null) {
                // Esc nel dialogo: annulla.
                _finish(const []);
              }
              return null;
            },
          ),
          TogglePathBarIntent: CallbackAction<TogglePathBarIntent>(
            onInvoke: (_) {
              setState(() => _pathBar = !_pathBar);
              widget.settings?.pathBar = _pathBar;
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
              _moveSelection(intent.move, extend: intent.extend);
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
                        SidebarSection('Tag', _tagPlaces),
                      ],
                      current: _tagView == null
                          ? _history.current
                          : '$tagPathPrefix$_tagView',
                      onSelect: (place) => place.kind == PlaceKind.tag
                          ? _showTag(place.label)
                          : _navigate(place.path),
                      onDrop: _drop,
                      colors: SidebarColors.of(dark: dark, active: _active),
                      iconsDir: widget.iconsDir,
                    ),
                  ),
                  Positioned(
                    left: visible,
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: ColoredBox(
                      color: WindowColors.of(context).content,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Sopra l'elenco la barra ha il fondo dell'intestazione (in scuro
                          // `#2f2f2f`, più chiaro del contenuto); altrove quello del contenuto.
                          _toolbar(visible),
                          if (widget.dialog?.save ?? false) _saveBar(),
                          ?widget.tabBar,
                          if (_searching) _scopeBar(),
                          Expanded(
                            // La cartella aperta come destinazione: linea di 2 pt lungo il bordo.
                            child: FolderDropTarget(
                              path: _history.current,
                              onDrop: _drop,
                              builder: (context, active) => Container(
                                foregroundDecoration: active
                                    ? BoxDecoration(
                                        border: Border.all(
                                          color: dropLine,
                                          width: 2,
                                        ),
                                      )
                                    : null,
                                child: LayoutBuilder(
                                  builder: (context, box) {
                                    _contentWidth = box.maxWidth;
                                    // I risultati della ricerca sono sempre un elenco.
                                    final view = _searching
                                        ? _listView()
                                        : switch (_view) {
                                            ViewMode.icons => _icons(),
                                            ViewMode.list => _listView(),
                                            ViewMode.columns => _columnsView(),
                                            ViewMode.gallery => _galleryView(),
                                          };
                                    // In galleria il pannello c'è sempre, largo 250 (spec 6).
                                    final pane =
                                        _previewPane ||
                                        _view == ViewMode.gallery;
                                    if (!pane) return view;
                                    // Il pannello di anteprima a destra (spec 1.6).
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(child: view),
                                        PreviewPane(
                                          width: _view == ViewMode.gallery
                                              ? 250
                                              : previewPaneWidth,
                                          compact: _view == ViewMode.gallery,
                                          items: _selection,
                                          kindOf: _kind,
                                          env: widget.iconsEnv,
                                          now: widget.now,
                                          tagsOf: _tagsOf,
                                          onAddTag: _addTag,
                                          actions: _paneActions(),
                                          iconsDir: widget.iconsDir,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          if (_pathBar)
                            PathBar(
                              // L'elemento scelto è l'ultimo segmento (R1.17).
                              path: _selected.length == 1
                                  ? _selected.first
                                  : _history.current,
                              env: widget.iconsEnv,
                              onOpen: (path) {
                                final entry = entryAt(path);
                                if (entry == null) return;
                                if (entry.isDirectory) {
                                  _navigate(path);
                                } else {
                                  _openEntry(entry);
                                }
                              },
                            ),
                          if (widget.dialog != null) _dialogButtons(),
                          // La barra di stato sotto la barra del percorso (spec 1.5).
                          // La barra di stato sposta la finestra (MU-08).
                          if (_statusBar)
                            WindowDragArea(
                              child: StatusBar(
                                active: _active,
                                text: statusText(
                                  count: _entries.length,
                                  selected: _selected.length,
                                  free: _free,
                                  listing: !_searching && _tagView == null,
                                ),
                                slider: _view == ViewMode.icons && !_searching
                                    ? sliderValueFor(_iconSide)
                                    : null,
                                onSlider: (value) {
                                  setState(
                                    () => _iconSide = iconSideFor(value),
                                  );
                                  widget.settings?.iconSide = _iconSide;
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // La cima della barra laterale, sotto i pulsanti della finestra, sposta la
                  // finestra come la barra degli strumenti.
                  Positioned(
                    left: 0,
                    top: 0,
                    width: visible,
                    height: toolbarHeight,
                    child: const WindowDragArea(child: SizedBox.expand()),
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
                  // Il menu contestuale: un clic fuori lo chiude.
                  if (_menuAt != null)
                    Positioned.fill(
                      child: MenuHost(
                        key: ValueKey(_menuAt),
                        entries: _menuEntries,
                        anchor: _menuAt!,
                        opaque: true,
                        onDismissed: _closeContextMenu,
                      ),
                    ),
                  // La visualizzazione rapida: l'ultimo elemento scelto; le frecce la cambiano.
                  if (_quickLook && _selection.isNotEmpty)
                    Positioned.fill(child: _quickLookPanel()),
                  // Le finestre Informazioni, una accanto all'altra a +285 pt.
                  for (var i = 0; i < _infos.length; i++)
                    if (entryAt(_infos[i]) case final entry?)
                      Positioned(
                        right: 12.0 + 285 * i,
                        top: 40,
                        bottom: 12,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: InfoPanel(
                            entry: entry,
                            kind: _kind(entry),
                            env: widget.iconsEnv,
                            open: _infoOpen,
                            openWith: entry.isDirectory
                                ? null
                                : _registry.defaultFor(_typeOf(entry))?.name,
                            onToggle: (section) {
                              setState(() {
                                _infoOpen.contains(section)
                                    ? _infoOpen.remove(section)
                                    : _infoOpen.add(section);
                              });
                              widget.settings?.infoSections = [
                                for (final s in _infoOpen) s.name,
                              ];
                            },
                            onClose: () =>
                                setState(() => _infos.remove(_infos[i])),
                            onRename: (name) {
                              final old = _infos[i];
                              final result = renameEntry(old, name);
                              if (result.error != null) {
                                _showError(
                                  'Non si può rinominare.',
                                  result.error,
                                );
                                return;
                              }
                              _undo.push(RenameOp(old, result.path!));
                              setState(() => _infos[i] = result.path!);
                              _load();
                            },
                          ),
                        ),
                      ),
                  // La finestra di avanzamento non blocca il resto.
                  if (_progress != null && _alert == null)
                    Align(
                      alignment: const Alignment(0, 0.85),
                      child: ProgressWindow(
                        transfer: _progress!,
                        icon: _appIcon,
                      ),
                    ),
                  // Il conflitto aspetta una scelta: copre la finestra.
                  if (_conflict != null)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {},
                        child: Align(
                          alignment: const Alignment(0, -0.5),
                          child: ConflictWindow(
                            name: _conflict!.name,
                            moving: _conflict!.moving,
                            icon: _appIcon,
                            onChoice: _chooseConflict,
                          ),
                        ),
                      ),
                    ),
                  // Un avviso copre la finestra: il resto non riceve clic finché è aperto.
                  if (_alert != null)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {},
                        child: Align(
                          alignment: const Alignment(0, -0.5),
                          child: _alert,
                        ),
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

  /// La barra degli strumenti (spec 1.2); `visible` è la parte visibile della barra laterale.
  /// Il menu della cronologia (pressione lunga su Indietro o Avanti, MU-07): voci da 24 con
  /// l'icona della cartella, il luogo più vicino in alto.
  void _historyMenu(Offset at, {required bool back}) {
    final places = back ? _history.backList : _history.forwardList;
    if (places.isEmpty) return;
    _update(() {
      _menuAt = at;
      _menuEntries = [
        for (var i = 0; i < places.length; i++)
          MenuAction(
            displayName(places[i]),
            icon: (_) =>
                switch (resolveFolderIcon(places[i], env: widget.iconsEnv)) {
                  final folder? => SilicaIcon(FolderSource(folder), side: 16),
                  null => const SizedBox(width: 16, height: 16),
                },
            onSelected: () {
              if (_history.jump(back ? -(i + 1) : i + 1)) _load();
            },
          ),
      ];
    });
  }

  Widget _toolbar(double visible) => MustacheToolbar(
    // Sopra l'elenco la barra ha il fondo dell'intestazione (in scuro `#2f2f2f`, più chiaro
    // del contenuto); altrove quello del contenuto.
    background: _searching || _view == ViewMode.list
        ? _listColors.header
        : WindowColors.of(context).content,
    onBackHistory: (at) => _historyMenu(at, back: true),
    onForwardHistory: (at) => _historyMenu(at, back: false),
    // A barra laterale nascosta la barra lascia il posto ai pulsanti della finestra.
    leading: visible < windowButtonsEnd ? windowButtonsEnd - visible + 7 : 7,
    title: widget.dialog != null && widget.dialog!.title.isNotEmpty
        ? widget.dialog!.title
        : _searching
        ? 'Ricerca in «${_searchScope == SearchScope.computer ? 'Questo computer' : displayName(_searchFolder)}»'
        : _tagView ?? displayName(_history.current),
    active: _active,
    canGoBack: _history.canGoBack || _searching,
    canGoForward: _history.canGoForward,
    onBack: () {
      // Dalla ricerca, Indietro torna alla cartella (R13.4).
      if (_searching) {
        _endSearch();
      } else if (_history.back()) {
        _load();
      }
    },
    onForward: () {
      if (_history.forward()) _load();
    },
    view: _searching ? null : _view,
    onView: _setView,
    onSearch: _startSearch,
    searchField: _searching ? _searchField() : null,
    iconsDir: widget.iconsDir,
  );

  Widget _renameField(Entry entry, {double maxWidth = 400}) => RenameField(
    key: ValueKey('rinomina ${entry.path}'),
    name: entry.name,
    isDirectory: entry.isDirectory,
    maxWidth: maxWidth,
    onCommit: (name) => _commitRename(entry, name),
    onCancel: _endRename,
  );

  Widget _quickLookPanel() {
    final items = _selection;
    final shown = items.firstWhere(
      (e) => e.path == _cursor,
      orElse: () => items.last,
    );
    final app = shown.isDirectory ? null : _registry.defaultFor(_typeOf(shown));
    return QuickLookPanel(
      entry: shown,
      env: widget.iconsEnv,
      position: items.length > 1
          ? (items.indexOf(shown) + 1, items.length)
          : null,
      openWith: app?.name,
      onOpenWith: () {
        setState(() => _quickLook = false);
        _openWith([shown], app);
      },
      onClose: () => setState(() => _quickLook = false),
    );
  }

  Widget _galleryView() => GalleryView(
    entries: _entries,
    selected: _cursor ?? (_selected.isEmpty ? null : _selected.last),
    onTap: _tap,
    onOpen: _openEntry,
    env: widget.iconsEnv,
  );

  Widget _columnsView() => ColumnView(
    root: _columnRoot,
    current: _history.current,
    leaf: _selected.length == 1 ? _selected.first : _history.current,
    list: _columnList,
    onSelect: _selectInColumn,
    onOpen: _openEntry,
    active: _active,
    env: widget.iconsEnv,
    tagsOf: _tagsOf,
  );

  Widget _icons() {
    if (_error != null) return _listView();
    return IconView(
      side: _iconSide,
      entries: _entries,
      selected: _selected,
      active: _active,
      env: widget.iconsEnv,
      onTap: _tap,
      onOpen: _openEntry,
      renaming: _renaming,
      renameBuilder: (entry, maxWidth) =>
          _renameField(entry, maxWidth: maxWidth),
      onContext: _openContextMenu,
      onRubberBand: _rubberBand,
      tagsOf: _tagsOf,
      wrapItem: (entry, child) => _draggable(
        entry,
        _folderTarget(
          entry,
          (context, active) => active
              ? Container(
                  foregroundDecoration: BoxDecoration(
                    color: const Color(0x400064E1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: child,
                )
              : child,
        ),
      ),
      onBackground: () => setState(() {
        _selected.clear();
        _anchor = null;
      }),
    );
  }
}
