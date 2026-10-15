// The Mustache window: the sidebar on the left (sidebar.dart) from top to bottom, on the right the
// toolbar unified with the window (toolbar.dart) and the content view.

import 'external.dart';

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show kDoubleTapTimeout, kPrimaryButton;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'model.dart';
import 'settings.dart';
import 'apps.dart';
import 'column_view.dart';
import 'dialog.dart';
import 'folder_customize.dart';
import 'folder_icons.dart';
import 'folder_style.dart';
import 'folder_watch.dart';
import 'drag.dart';
import 'gallery_view.dart';
import 'icon_arrange.dart';
import 'icon_view.dart';
import 'info.dart';
import 'list_view.dart';
import 'operations.dart';
import 'path_bar.dart';
import 'preview_pane.dart';
import 'quick_preview.dart';
import 'status_bar.dart';
import 'rename_field.dart';
import 'sounds.dart';
import 'transfer.dart';
import 'transfer_ui.dart';
import 'xattr.dart';
import 'sidebar.dart';
import 'tags.dart';
import 'toolbar.dart';

part 'window_arrange.dart';
part 'window_columns.dart';
part 'window_context.dart';
part 'window_dialog.dart';
part 'window_drag.dart';
part 'window_list.dart';
part 'window_operations.dart';
part 'window_search.dart';
part 'window_tags.dart';
part 'window_transfers.dart';

/// The tab bar below the toolbar: a 28 pt rail with 4 pt above and below (the content moves down
/// by 36, MU-01).
const double tabBarHeight = 36;

/// The narrowest window that keeps the window buttons clear (516 pt, titlebar.md).
const double minimumWindowWidth = 516;

/// The shortest window (252 pt, mustache.md).
const double minimumWindowHeight = 252;

const Size minimumWindowSize = Size(minimumWindowWidth, minimumWindowHeight);

const Color accent = Color(0xFF0075F2);
const Color textColor = Color(0xFF000000);
const Color secondaryText = Color(0xFF808182);
const Color contentFill = Color(0xFFFFFFFF);

/// Background and text colors of the window, light and dark (mustache.md MU-20, MU-03, MU-04:
/// content `#272728`, toolbar and header `#2f2f2f` in dark).
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

/// Intents of the window shortcuts (`mustache.*` commands, docs/spec/product.md).
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

/// Shows or hides a part of the window.
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

class QuickPreviewIntent extends Intent {
  const QuickPreviewIntent();
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

/// Clean Up By an order (⌥⌘1…7, `mustache.view.arrange_by`).
class ArrangeByIntent extends Intent {
  const ArrangeByIntent(this.key);
  final SortKey key;
}

/// Arrow directions: up and down in the list, also left and right in the grid.
enum Move { up, down, left, right }

/// One of the file operations (MU.4), with its shortcut.
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

  /// With ⇧: the selection extends from the anchor (R7.6).
  final bool extend;
}

/// The .desktop entry of Mustache (to open more windows).
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
    this.iconPositions,
    this.active = true,
    this.iconsEnv,
    this.tabBar,
    this.onLocation,
    this.focused = true,
    this.dialog,
    this.onDialogFinish,
    this.customize,
  });

  /// A folder whose Customize Folder popover opens at start (`--customize=<path>`,
  /// sent by the desktop's context menu; `start` is the folder that holds it).
  final String? customize;

  /// The window is an Open or Save dialog for the portal (null: the normal window).
  final DialogOptions? dialog;

  /// How the dialog ends (tests); null: writes to stdout and exits.
  final void Function(List<String> paths)? onDialogFinish;

  /// This tab is the active one: becoming active it takes the keyboard back.
  final bool focused;

  /// The tab bar (from [TabsHost], null with a single tab): below the header, above the content.
  final Widget? tabBar;

  /// Where the window is (the title of its tab).
  final ValueChanged<String>? onLocation;

  final String start;
  final List<Place> places;
  final Place trash;

  /// The silica-icons directory (`SILICA_ICONS_DIR`): the sidebar symbols.
  final String? iconsDir;

  /// Fixed time (tests).
  final DateTime? now;

  /// Opens a file with the default app (tests: records the call).
  final void Function(String path)? open;

  /// Settings kept between launches (the sidebar width).
  final Settings? settings;

  /// The free icon positions of every folder (sort "None", R4.7); null: none are kept.
  final IconPositions? iconPositions;

  /// The window has the focus: the sidebar colors change when it does not.
  final bool active;

  /// The environment where silica-icons is looked up (tests); null: the process environment.
  final Map<String, String>? iconsEnv;

  @override
  State<MustacheWindow> createState() => _MustacheWindowState();
}

class _MustacheWindowState extends State<MustacheWindow>
    with SingleTickerProviderStateMixin {
  late final History _history = History(widget.start);

  /// The window is the active one for Ossido: the embedder says so with `flutter/lifecycle`
  /// (`resumed` active, `inactive` not; without news, active).
  bool _windowActive = _isActive(WidgetsBinding.instance.lifecycleState);
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onStateChange: (state) {
      final active = _isActive(state);
      if (active != _windowActive) setState(() => _windowActive = active);
    },
  );

  static bool _isActive(AppLifecycleState? state) =>
      state == null || state == AppLifecycleState.resumed;

  /// Active for Ossido and, with tabs, the tab in front.
  bool get _active => widget.active && _windowActive;

  /// Dragging (window_drag.dart): the press on an item, the drag that left from here (and the
  /// last one, whose drop may come back after it ended), the folder under a drag and its spring,
  /// the pills' picture and the items as drawn (icon view, gallery).
  _ItemPress? _press;
  _WindowDrag? _drag;
  _WindowDrag? _lastDrag;
  final ValueNotifier<String?> _dropHover = ValueNotifier(null);
  Timer? _spring;
  final GlobalKey _dragImageKey = GlobalKey();
  final Map<String, GlobalKey> _faces = {};

  /// The slow click (R8): a press on a name (path, it was the only one selected) and the item
  /// clicked last, until the double-click time passes.
  (String, bool)? _nameDown;
  String? _recentClick;
  Timer? _recentClickTimer;

  /// The item of a larger selection pressed without modifiers: the only one selected on release
  /// if no drag started.
  String? _collapseTo;

  /// The pressed row (selected on release, MU-25) and whether a drag started from it; the pressed
  /// disclosure triangle with ⌥ read at press time.
  String? _rowDown;
  bool _rowDragged = false;
  (String, bool)? _triangleDown;
  StreamSubscription<SilicaDragEvent>? _externalDrags;

  /// The sidebar width when visible; new windows take the last one.
  late double _sidebarWidth =
      widget.settings?.sidebarWidth ?? sidebarDefaultWidth;

  /// 1: sidebar visible, 0: hidden (⌃⌘S or dragged against the edge).
  late final AnimationController _sidebarShown = AnimationController(
    vsync: this,
    duration: sidebarShow,
    reverseDuration: sidebarHide,
    value: 1,
  )..addListener(() => setState(() {}));
  bool _resizing = false;

  /// The arrow cursor (the anchor stays where the ⇧ selection started) and the selection at the
  /// start of the rubber band.
  String? _cursor;
  Set<String>? _bandBase;

  late final Trash _trash = Trash(
    parentOf(widget.trash.path) ?? widget.trash.path,
  );
  final UndoStack _undo = UndoStack();

  /// The item being renamed, the slow-click wait and the open alert.
  String? _renaming;
  Timer? _slowClick;
  Widget? _alert;

  /// The apps (read the first time an app is opened), the MIME types and the open context menu.
  AppRegistry? _apps;
  final Map<String, String> _types = {};
  Offset? _menuAt;
  List<MenuEntry> _menuEntries = const [];

  /// Copies in progress, the one with the progress window and the pending conflict.
  final List<Transfer> _transfers = [];
  Transfer? _progress;
  ({String name, bool moving, Completer<ConflictChoice> done})? _conflict;

  /// Tags read in this load; the tag shown (results view) and the search in progress.
  final Map<String, List<String>> _tagCache = {};
  String? _tagView;
  int _tagSearch = 0;

  /// The folder whose Customize Folder popover is open (folder_customize.dart), if any.
  String? _customizing;
  final FocusNode _customizeFocus = FocusNode(debugLabel: 'customize folder');

  /// The open Get Info windows (paths) and their open sections (shared by all).
  final List<String> _infos = [];
  late final Set<InfoSection> _infoOpen = {
    for (final name
        in widget.settings?.infoSections ??
            const ['general', 'name', 'preview'])
      ?InfoSection.values.where((s) => s.name == name).firstOrNull,
  };

  /// Search: active, the field, the scope, the starting folder, the debounce and the running pass.
  bool _searching = false;
  final TextEditingController _searchQuery = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  SearchScope _searchScope = SearchScope.computer;
  String _searchFolder = '/';
  Timer? _searchTimer;
  int _searchToken = 0;

  /// Status bar, preview pane, icon size, free space.
  // No bars or pane in dialogs (R14.6).
  late bool _statusBar =
      widget.dialog == null && (widget.settings?.statusBar ?? false);
  late bool _previewPane =
      widget.dialog == null && (widget.settings?.previewPane ?? false);
  late double _iconSide = widget.settings?.iconSide ?? defaultIconSide;
  int? _free;

  /// The file name of the Save dialog.
  late final TextEditingController _saveName = TextEditingController(
    text: widget.dialog?.name ?? '',
  );
  final FocusNode _saveFocus = FocusNode();

  /// Quick preview open (Space).
  bool _quickPreview = false;

  /// The arrangement of the open folder in the icon view (free or sorted, Snap to Grid, positions),
  /// how long icons take to move (Clean Up), the pending Clean Up and where the last press on an
  /// icon was (a drop moves the icons by the pointer's movement from there).
  FolderArrangement _arrangement = FolderArrangement();
  Duration _moveDuration = Duration.zero;
  Timer? _cleanUpTimer;
  Offset? _pressAt;

  /// The path bar (⌥⌘P), remembered for new windows.
  late bool _pathBar =
      widget.dialog == null && (widget.settings?.pathBar ?? false);

  /// The column contents, read once per load.
  final Map<String, List<Entry>> _columnCache = {};

  /// Watches of the folders on screen (folder_watch.dart): whatever changes one (an item created,
  /// deleted, renamed or moved in, by any app, or its colour or symbol) reloads the window.
  final Map<String, VoidCallback> _styleWatches = {};

  void _watchStyles(String dir) =>
      _styleWatches[dir] ??= folderWatcher.watch(dir, (paths) {
        folderStyles.invalidate(paths);
        if (mounted) _load();
      });

  /// Stops the watches of the folders no longer on screen.
  void _unwatchStyles({String? keep}) {
    for (final dir in _styleWatches.keys.toList()) {
      if (dir != keep) _styleWatches.remove(dir)?.call();
    }
  }

  // Dialogs start in columns, and there is no gallery (R14.5, R14.6).
  late ViewMode _view = widget.dialog != null
      ? ViewMode.columns
      : ViewMode.values.firstWhere(
          (v) => v.name == widget.settings?.view,
          orElse: () => ViewMode.icons,
        );

  /// The width of the content area at the last paint (for the arrows in the grid).
  double _contentWidth = 800;

  /// The height of the veiled band over the content (toolbar and the bars below it, R1.9): the
  /// views start below it and scroll under it.
  double _topInset = toolbarHeight;

  /// The sideways scroll of a list wider than the window (the header in the band follows it).
  final ScrollController _listScrollX = ScrollController();
  final FocusNode _focus = FocusNode();
  List<Entry> _entries = const [];
  String? _error;
  bool _showHidden = false;
  SortKey _sort = SortKey.name;
  bool _descending = false;
  final Set<String> _selected = {};
  String? _anchor;

  /// The list columns, widened by dragging the separators (R3.6).
  final List<double> _listWidths = [for (final c in listColumns) c.width];

  /// Folders expanded in place in the list and their contents, read once.
  final Set<String> _expanded = {};
  final Map<String, List<Entry>> _childCache = {};

  /// The row of a right click on an unselected item: the ring, the selection stays (R3.9).
  String? _contextRing;

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _externalDrags = SilicaDrag.events.listen(_dragEvent);
    if (widget.customize case final path?) _customizing = path;
    _load();
  }

  @override
  void dispose() {
    _unwatchStyles();
    _lifecycle.dispose();
    _externalDrags?.cancel();
    _focus.dispose();
    _customizeFocus.dispose();
    _listScrollX.dispose();
    _sidebarShown.dispose();
    _slowClick?.cancel();
    _recentClickTimer?.cancel();
    _spring?.cancel();
    _dropHover.dispose();
    _drag?.faces?.dispose();
    _drag?.picture?.dispose();
    _cleanUpTimer?.cancel();
    _searchTimer?.cancel();
    _searchQuery.dispose();
    _searchFocus.dispose();
    _saveName.dispose();
    _saveFocus.dispose();
    super.dispose();
  }

  /// The app icon in alerts (66 pt), from silica-icons.
  Widget? get _appIcon {
    final icon = findSilicaIcon('mustache', env: widget.iconsEnv);
    return icon == null ? null : SilicaIcon(LayeredSource(icon), side: 66);
  }

  /// ⌘N: another window, i.e. another process started from the app's .desktop entry.
  Future<void> _newWindow() async {
    final app = _registry.apps[mustacheDesktopId];
    if (app == null) {
      _showError(l10n.cantOpenWindow, l10n.entryNotInstalled);
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

  /// `setState` for the operations in `window_operations.dart` (an extension cannot call it).
  void _update(VoidCallback change) => setState(change);

  void _toggleSidebar() {
    if (_sidebarShown.status == AnimationStatus.reverse ||
        _sidebarShown.value == 0) {
      _sidebarShown.forward();
    } else {
      _sidebarShown.reverse();
    }
  }

  /// How much of the sidebar shows (0–1): S curve; showing starts with a ~40 ms delay.
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
    // The window title is the folder name (the Silica embedder passes it to Ossido; outside Silica
    // the call does nothing).
    SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(
        label: widget.dialog?.title.isNotEmpty ?? false
            ? widget.dialog!.title
            : displayName(_history.current),
      ),
    );
    // While searching, the search is run again.
    if (_searching) {
      _runSearch();
      return;
    }
    // In a tag view, the search is run again.
    final tag = _tagView;
    if (tag != null) {
      _tagCache.clear();
      _showTag(tag);
      return;
    }
    _unwatchStyles(keep: _history.current);
    _watchStyles(_history.current);
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
      // Expanded folders that no longer exist are forgotten.
      _expanded.removeWhere((path) => !Directory(path).existsSync());
      _error = result.error;
      // In columns the selection can be the open folder, which is not in its own contents.
      _selected.removeWhere(
        (path) =>
            !_ordered.any((e) => e.path == path) &&
            !(_view == ViewMode.columns && entryAt(path) != null),
      );
      _loadArrangement();
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
    _faces.clear();
    _load();
  }

  void _openEntry(Entry entry) {
    _slowClick?.cancel();
    if (entry.isDirectory) {
      _navigate(entry.path);
    } else if (widget.dialog case final d?) {
      // In the Open dialog a double click on a file chooses it.
      if (!d.save && !d.directory) _finish([entry.path]);
    } else {
      _openWith([entry]);
    }
  }

  static void _xdgOpen(String path) {
    startDetached('xdg-open', [path]).ignore();
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
    if (_moveSpatially(move, extend: extend)) return;
    final columns = _view == ViewMode.icons
        ? iconGrid(_contentWidth, side: _iconSide).columns
        : 1;
    // In the list → and ← expand and collapse the folder (R3.7).
    if ((move == Move.left || move == Move.right) &&
        _expandAtCursor(open: move == Move.right)) {
      return;
    }
    final across = _view == ViewMode.icons || _view == ViewMode.gallery;
    final delta = switch (move) {
      // In the gallery the strip is a single row: up and down do not move it.
      Move.up => _view == ViewMode.gallery ? 0 : -columns,
      Move.down => _view == ViewMode.gallery ? 0 : columns,
      Move.left => across ? -1 : 0,
      Move.right => across ? 1 : 0,
    };
    if (delta == 0) return;
    _moveBy(delta, extend: extend);
  }

  void _setView(ViewMode view) {
    // No gallery in dialogs, and their choice does not change the windows' one.
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

  /// In the gallery there is always a chosen item, the large one (mu23): without a selection, the
  /// first.
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

  /// Arrows: the cursor moves by `delta` in reading order. Without ⇧ only the cursor is selected;
  /// with ⇧ the linear range from the anchor to the cursor (R7.6). Past the first or last row in
  /// the grid nothing happens.
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
        // In the grid, up and down past the edge do not move; in the list it stops there.
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

  /// The rubber band: with ⌘ or ⇧ it toggles the starting items, otherwise it replaces them.
  void _rubberBand(Set<String> paths, {required bool done}) {
    // A rubber band never renames (R8).
    _slowClick?.cancel();
    _recentClick = null;
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
    setState(() {
      // In the icon view ⇧-click adds or removes like ⌘-click (R7.3).
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
      } else if (_selected.length > 1 && _selected.contains(entry.path)) {
        // A press on an item of a larger selection keeps it (it may be dragged): released
        // without a drag, only the item stays selected.
        _collapseTo = entry.path;
        _anchor = _cursor = entry.path;
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
  Widget build(BuildContext context) => _OverlayHost(
    // Every press, move and release, after the items' own (window_drag.dart).
    child: Listener(
      onPointerDown: _windowDown,
      onPointerMove: _windowMove,
      onPointerUp: _windowUp,
      onPointerCancel: _windowCancel,
      child: DropHover(
        notifier: _dropHover,
        child: Stack(
          children: [
            Positioned.fill(child: _window(context)),
            ?_dragLayer(),
          ],
        ),
      ),
    ),
  );

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
        SingleActivator(LogicalKeyboardKey.space): QuickPreviewIntent(),
        SingleActivator(LogicalKeyboardKey.keyI, meta: true): InfoIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, meta: true): SearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyN, meta: true): NewWindowIntent(),
        SingleActivator(LogicalKeyboardKey.quoteSingle, meta: true):
            TogglePartIntent(WindowPart.statusBar),
        SingleActivator(LogicalKeyboardKey.keyP, meta: true, shift: true):
            TogglePartIntent(WindowPart.previewPane),
        SingleActivator(LogicalKeyboardKey.keyY, meta: true):
            QuickPreviewIntent(),
        SingleActivator(LogicalKeyboardKey.escape): CloseIntent(),
        // Clean Up By (arrangeByDigit).
        SingleActivator(LogicalKeyboardKey.digit1, meta: true, alt: true):
            ArrangeByIntent(SortKey.name),
        SingleActivator(LogicalKeyboardKey.digit2, meta: true, alt: true):
            ArrangeByIntent(SortKey.kind),
        SingleActivator(LogicalKeyboardKey.digit5, meta: true, alt: true):
            ArrangeByIntent(SortKey.modified),
        SingleActivator(LogicalKeyboardKey.digit6, meta: true, alt: true):
            ArrangeByIntent(SortKey.size),
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
              // From search, Back returns to the folder (R13.4).
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
              // The selection, or the open folder if there is none.
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
          QuickPreviewIntent: CallbackAction<QuickPreviewIntent>(
            onInvoke: (_) {
              if (_renaming != null || _alert != null) return null;
              setState(
                () => _quickPreview = !_quickPreview && _selected.isNotEmpty,
              );
              return null;
            },
          ),
          CloseIntent: CallbackAction<CloseIntent>(
            onInvoke: (_) {
              if (_quickPreview) {
                setState(() => _quickPreview = false);
              } else if (widget.dialog != null && _alert == null) {
                // Esc in the dialog: cancel.
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
          ArrangeByIntent: CallbackAction<ArrangeByIntent>(
            onInvoke: (intent) {
              _arrangeBy(intent.key);
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
              // While hiding, the sidebar slides left (keeping its width) and the content widens.
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
                        SidebarSection(l10n.sidebarPinned, [
                          for (final place in widget.places)
                            if (place.kind != PlaceKind.home) place,
                        ]),
                        SidebarSection(l10n.sidebarPlaces, [
                          for (final place in widget.places)
                            if (place.kind == PlaceKind.home) place,
                          widget.trash,
                        ]),
                        SidebarSection(l10n.sidebarTags, _tagPlaces),
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
                          Expanded(
                            // The content scrolls under the glass toolbar (R1.9, mustache#3).
                            child: _underToolbar(
                              visible,
                              // The open folder as a drop target: a 2 pt line along the edge of
                              // the content, below the band.
                              (band) => FolderDropTarget(
                                path: _history.current,
                                onDrop: _drop,
                                builder: (context, active) => Stack(
                                  children: [
                                    Positioned.fill(child: _views()),
                                    if (active)
                                      Positioned(
                                        left: 0,
                                        top: band,
                                        right: 0,
                                        bottom: 0,
                                        child: IgnorePointer(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: dropLine,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_pathBar)
                            PathBar(
                              // The chosen item is the last segment (R1.17).
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
                          // The status bar below the path bar (spec/bars.md).
                          // The status bar moves the window (MU-08).
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
                  // The draggable edge, also with the sidebar hidden (pulling it reopens the
                  // sidebar).
                  Positioned(
                    left: visible - 3,
                    top: 0,
                    bottom: 0,
                    width: 6,
                    child: SidebarDivider(
                      key: const ValueKey('sidebar edge'),
                      onDrag: (x) => _dragSidebar(x, windowWidth),
                      onRelease: _releaseSidebar,
                    ),
                  ),
                  // The Customize Folder popover, under the context menu.
                  // (The Positioned widgets have keys so that one appearing does not shift the
                  // menu onto the other's element and restart it.)
                  if (_customizing case final path?)
                    Positioned.fill(
                      key: const ValueKey('customize host'),
                      child: FolderCustomizeOverlay(
                        key: ValueKey('customize $path'),
                        path: path,
                        env: widget.iconsEnv,
                        waitForAnchor: widget.customize == path,
                        focusNode: _customizeFocus,
                        writeTags: writeTags,
                        onTagsChanged: (tags) =>
                            _update(() => _tagCache[path] = tags),
                        onEditTags: () => _editTags(path),
                        onClose: () {
                          _update(() => _customizing = null);
                          _focus.requestFocus();
                        },
                      ),
                    ),
                  // The context menu: a click outside closes it.
                  if (_menuAt != null)
                    Positioned.fill(
                      key: const ValueKey('context menu host'),
                      child: MenuHost(
                        key: ValueKey(_menuAt),
                        entries: _menuEntries,
                        anchor: _menuAt!,
                        opaque: true,
                        onDismissed: _closeContextMenu,
                      ),
                    ),
                  // Quick preview: the last chosen item; the arrows change it.
                  if (_quickPreview && _selection.isNotEmpty)
                    Positioned.fill(child: _quickPreviewPanel()),
                  // The Get Info windows, side by side at +285 pt.
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
                                _showError(l10n.cantRename, result.error);
                                return;
                              }
                              _undo.push(RenameOp(old, result.path!));
                              setState(() => _infos[i] = result.path!);
                              _load();
                            },
                          ),
                        ),
                      ),
                  // The progress window does not block the rest.
                  if (_progress != null && _alert == null)
                    Align(
                      alignment: const Alignment(0, 0.85),
                      child: ProgressWindow(
                        transfer: _progress!,
                        icon: _appIcon,
                      ),
                    ),
                  // The conflict waits for a choice: it covers the window.
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
                  // An alert covers the window: the rest gets no clicks while it is open.
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

  /// The history menu (long press on Back or Forward, MU-07): 24 pt items with the folder icon, the
  /// nearest place on top.
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
                switch (styledFolderIcon(places[i], env: widget.iconsEnv)) {
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

  /// The glass toolbar over the content (R1.9, R4.9): the toolbar, then the bars below it (Save
  /// name row, tabs, search scope, list column header) in one veiled band; `content` gets the
  /// band's height and fills the whole area, scrolling under it.
  Widget _underToolbar(double visible, Widget Function(double band) content) {
    final list = _error == null && (_searching || _view == ViewMode.list);
    final bars = <(Widget, double)>[
      if (widget.dialog?.save ?? false) (_saveBar(), saveBarHeight),
      if (widget.tabBar case final tabBar?) (tabBar, tabBarHeight),
      if (_searching) (_scopeBar(), scopeBarHeight),
      if (list) (_listHeaderBand(), listHeaderHeight + listHeaderLine),
    ];
    final header = bars.fold(0.0, (sum, bar) => sum + bar.$2);
    _topInset = toolbarHeight + header;
    return ScrollUnderToolbar(
      toolbar: _toolbar(visible),
      header: bars.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (bar, height) in bars)
                  SizedBox(height: height, child: bar),
              ],
            ),
      headerHeight: header,
      active: _active,
      // At rest the bar shows the content colour, without a band (silica-ui#87). Under the list
      // header the band keeps the plain veil, as measured (`#2f2f2f` in dark, MU-98).
      background: list ? null : WindowColors.of(context).content,
      // The list header has its own line below it, always there (MU-20): no second one.
      showLine: !list,
      // The column view's lists and a wide list scroll vertically below depth 0.
      scrollPredicate: anyVerticalScrollUnderPredicate,
      body: (context, padding) => content(padding.top),
    );
  }

  /// The view of the folder (or of the search results), with the preview pane on the right.
  Widget _views() => LayoutBuilder(
    builder: (context, box) {
      _contentWidth = box.maxWidth;
      // Search results are always a list.
      final view = _searching
          ? _listView()
          : switch (_view) {
              ViewMode.icons => _icons(),
              ViewMode.list => _listView(),
              ViewMode.columns => _columnsView(),
              ViewMode.gallery => _galleryView(),
            };
      // In the gallery the pane is always there, 250 wide (spec/gallery.md).
      final pane = _previewPane || _view == ViewMode.gallery;
      if (!pane) return view;
      // The preview pane on the right (spec/preview-pane.md), below the band.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: view),
          Padding(
            padding: EdgeInsets.only(top: _topInset),
            child: PreviewPane(
              width: _view == ViewMode.gallery ? 250 : previewPaneWidth,
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
          ),
        ],
      );
    },
  );

  /// The toolbar (spec/toolbar.md); `visible` is the visible part of the sidebar. No background: the
  /// veil of the band is under it (R1.9).
  Widget _toolbar(double visible) => MustacheToolbar(
    onBackHistory: (at) => _historyMenu(at, back: true),
    onForwardHistory: (at) => _historyMenu(at, back: false),
    // With the sidebar hidden the toolbar leaves room for the window buttons.
    leading: visible < windowButtonsEnd ? windowButtonsEnd - visible + 7 : 7,
    title: widget.dialog != null && widget.dialog!.title.isNotEmpty
        ? widget.dialog!.title
        : _searching
        ? l10n.searchTitle(
            _searchScope == SearchScope.computer
                ? l10n.thisComputer
                : displayName(_searchFolder),
          )
        : _tagView ?? displayName(_history.current),
    active: _active,
    canGoBack: _history.canGoBack || _searching,
    canGoForward: _history.canGoForward,
    onBack: () {
      // From search, Back returns to the folder (R13.4).
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
    key: ValueKey('rename ${entry.path}'),
    name: entry.name,
    isDirectory: entry.isDirectory,
    maxWidth: maxWidth,
    onCommit: (name) => _commitRename(entry, name),
    onCancel: _endRename,
  );

  Widget _quickPreviewPanel() {
    final items = _selection;
    final shown = items.firstWhere(
      (e) => e.path == _cursor,
      orElse: () => items.last,
    );
    final app = shown.isDirectory ? null : _registry.defaultFor(_typeOf(shown));
    return QuickPreviewPanel(
      entry: shown,
      env: widget.iconsEnv,
      position: items.length > 1
          ? (items.indexOf(shown) + 1, items.length)
          : null,
      openWith: app?.name,
      onOpenWith: () {
        setState(() => _quickPreview = false);
        _openWith([shown], app);
      },
      onClose: () => setState(() => _quickPreview = false),
    );
  }

  // The gallery does not scroll vertically: it starts below the band.
  Widget _galleryView() => Padding(
    padding: EdgeInsets.only(top: _topInset),
    child: GalleryView(
      entries: _entries,
      selected: _cursor ?? (_selected.isEmpty ? null : _selected.last),
      onTap: _tap,
      onOpen: _openEntry,
      env: widget.iconsEnv,
      wrapItem: (entry, child) => _itemPress(
        entry,
        _litFolder(entry, child),
        threshold: iconDragThreshold,
        faces: true,
      ),
    ),
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
    topInset: _topInset,
    wrapItem: (entry, child) => GestureDetector(
      behavior: HitTestBehavior.translucent,
      // The menu applies to the item under the pointer: it becomes the chosen one first.
      onSecondaryTapDown: (d) {
        if (!_selected.contains(entry.path)) {
          _selectInColumn(entry, parentOf(entry.path) ?? '/');
        }
        _openContextMenu(entry, d.globalPosition);
      },
      child: _itemPress(
        entry,
        _litFolder(entry, child, radius: columnSelectionRadius),
        threshold: 1,
        anchor: const Offset(columnIconLeft, (columnRow - columnIconSide) / 2),
      ),
    ),
  );

  Widget _icons() {
    if (_error != null) return _listView();
    final positions = _freePositions;
    final view = IconView(
      topInset: _topInset,
      side: _iconSide,
      positions: positions,
      moveDuration: _moveDuration,
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
      onNamePress: _namePress,
      wrapItem: (entry, child) => _itemPress(
        entry,
        _litFolder(entry, child),
        threshold: iconDragThreshold,
        faces: true,
      ),
      onBackground: () => setState(() {
        _selected.clear();
        _anchor = null;
      }),
    );
    return view;
  }
}
