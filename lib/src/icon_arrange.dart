// Free icon positions (sort "None", R4.7, R4.8, MU-21): each folder keeps where its icons were left;
// Clean Up moves the off-grid icons to the nearest free cell, Clean Up By lays them all out in an
// order, Snap to Grid makes every drop land on a free cell.
//
// Storage: one JSON file in `$XDG_STATE_HOME/mustache/icon-positions.json` (default
// `~/.local/state`), keyed by folder path, then by item name. It is the app's state, not the user's
// data: no hidden file is written into the folders (it works on read-only folders and does not
// change them), and an extended attribute would need write permission on the folder. A renamed or
// moved folder loses its arrangement and starts from the grid again.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'icon_view.dart';
import 'model.dart' show SortKey;

/// Delay and duration of the Clean Up movement (MU-21 M4): it starts ~350 ms after the release on
/// the menu item and lasts ~290 ms, decelerating.
const Duration cleanUpDelay = Duration(milliseconds: 350);
const Duration cleanUpDuration = Duration(milliseconds: 290);

/// The digits of Clean Up By (⌥⌘1…7): the reference's order is name, kind, last opened, added,
/// modified, size, tags; the orders Mustache does not have leave their digits unused.
const Map<SortKey, int> arrangeByDigit = {
  SortKey.name: 1,
  SortKey.kind: 2,
  SortKey.modified: 5,
  SortKey.size: 6,
};

/// The drag threshold of the icon view (MU-34): nothing up to 7 pt, sometimes at 8, always from 9.
const double iconDragThreshold = 8;

/// The fixed grid of free positions. With a sort order the grid stretches to fill the width
/// ([iconGrid]); with "None" the cells keep the minimum pitch, so resizing the window moves nothing.
class FreeGrid {
  const FreeGrid({
    required this.pitchX,
    required this.pitchY,
    required this.left,
    required this.top,
  });

  factory FreeGrid.of({
    double side = defaultIconSide,
    double text = defaultLabelSize,
  }) {
    // The stretched grid's geometry for a width where the minimum pitch fits exactly once: its
    // pitch is the minimum one. Provisional: the spacing of the free grid was not measured apart
    // from the stretched one (MU-21 table: 100 at text 10).
    final g = iconGrid(0, side: side, text: text);
    return FreeGrid(
      pitchX: minIconPitch(side: side, text: text),
      pitchY: g.pitchY,
      left: g.left,
      top: g.top,
    );
  }

  final double pitchX;
  final double pitchY;
  final double left;
  final double top;

  /// The position of a cell: the icon's center x and top y.
  Offset cell(int column, int row) =>
      Offset(left + pitchX * (column + 0.5), top + pitchY * row);

  /// The cell nearest to a position (never at negative indices).
  (int, int) cellOf(Offset p) => (
    math.max(0, ((p.dx - left) / pitchX - 0.5).round()),
    math.max(0, ((p.dy - top) / pitchY).round()),
  );

  /// The columns that fit in `width`, at least one.
  int columnsFor(double width) =>
      math.max(1, ((width - 2 * left) / pitchX).floor());

  bool onGrid(Offset p) {
    final (c, r) = cellOf(p);
    return (cell(c, r) - p).distance < 0.5;
  }
}

/// Lays out `names` on the grid, row by row, `columns` per row (Clean Up By, and the first
/// arrangement of a folder: the order it had with the sort).
Map<String, Offset> arrangeOnGrid(
  List<String> names,
  FreeGrid grid,
  int columns,
) => {
  for (var i = 0; i < names.length; i++)
    names[i]: grid.cell(i % columns, i ~/ columns),
};

/// The cells taken by `positions` (icons that are on a cell).
Set<(int, int)> _taken(Iterable<Offset> positions, FreeGrid grid) => {
  for (final p in positions)
    if (grid.onGrid(p)) grid.cellOf(p),
};

/// The free cell nearest to `p`, searched in rings around its own cell.
Offset nearestFreeCell(Offset p, FreeGrid grid, Set<(int, int)> taken) {
  final (c0, r0) = grid.cellOf(p);
  Offset? best;
  var bestDistance = double.infinity;
  int? foundAt;
  for (var ring = 0; ring < 10000; ring++) {
    // Cells are not square and `p` is not at a cell's center: once a free cell is found, one more
    // ring may hold a nearer one.
    if (foundAt != null && ring > foundAt + 1) break;
    for (var r = r0 - ring; r <= r0 + ring; r++) {
      for (var c = c0 - ring; c <= c0 + ring; c++) {
        if (c < 0 || r < 0) continue;
        if ((r - r0).abs() != ring && (c - c0).abs() != ring) continue;
        if (taken.contains((c, r))) continue;
        final d = (grid.cell(c, r) - p).distance;
        if (d < bestDistance) {
          bestDistance = d;
          best = grid.cell(c, r);
          foundAt ??= ring;
        }
      }
    }
  }
  return best ?? grid.cell(c0, r0);
}

/// Clean Up (R4.8): each icon of `only` (all when null) that is off the grid goes to the nearest
/// free cell; the others stay still. Icons are placed in reading order, so the first ones choose
/// first.
Map<String, Offset> cleanUp(
  Map<String, Offset> positions,
  FreeGrid grid, {
  Set<String>? only,
}) {
  final moving =
      [
        for (final MapEntry(:key, :value) in positions.entries)
          if ((only == null || only.contains(key)) && !grid.onGrid(value)) key,
      ]..sort(
        (a, b) => _readingOrder(
          positions[a] ?? Offset.zero,
          positions[b] ?? Offset.zero,
        ),
      );
  final staying = {
    for (final MapEntry(:key, :value) in positions.entries)
      if (!moving.contains(key)) key: value,
  };
  final taken = _taken(staying.values, grid);
  final result = {...positions};
  for (final name in moving) {
    final to = nearestFreeCell(positions[name] ?? Offset.zero, grid, taken);
    taken.add(grid.cellOf(to));
    result[name] = to;
  }
  return result;
}

int _readingOrder(Offset a, Offset b) {
  final dy = a.dy.compareTo(b.dy);
  return dy != 0 ? dy : a.dx.compareTo(b.dx);
}

/// Places the items without a position (new files) in the first free cells, row by row within
/// `columns`; the others keep theirs.
Map<String, Offset> placeNew(
  List<String> names,
  Map<String, Offset> positions,
  FreeGrid grid,
  int columns,
) {
  final result = {
    for (final name in names)
      if (positions[name] case final p?) name: p,
  };
  final taken = _taken(result.values, grid);
  var next = 0;
  for (final name in names) {
    if (result.containsKey(name)) continue;
    while (taken.contains((next % columns, next ~/ columns))) {
      next++;
    }
    final cell = (next % columns, next ~/ columns);
    taken.add(cell);
    result[name] = grid.cell(cell.$1, cell.$2);
  }
  return result;
}

/// Moves `names` by `delta` keeping their offsets (a drag of the selection); with `snap` each one
/// lands on the free cell nearest to where it was dropped (Snap to Grid). Positions stay inside the
/// content (never above or left of the first cell's margin).
Map<String, Offset> moveIcons(
  Map<String, Offset> positions,
  Iterable<String> names,
  Offset delta,
  FreeGrid grid, {
  bool snap = false,
}) {
  final moving = names.where(positions.containsKey).toList()
    ..sort((a, b) => _readingOrder(positions[a]!, positions[b]!));
  final result = {...positions};
  final taken = snap
      ? _taken([
          for (final MapEntry(:key, :value) in positions.entries)
            if (!moving.contains(key)) value,
        ], grid)
      : <(int, int)>{};
  for (final name in moving) {
    var to = positions[name]! + delta;
    to = Offset(
      math.max(grid.pitchX / 2, to.dx),
      math.max(grid.top / 2, to.dy),
    );
    if (snap) {
      to = nearestFreeCell(to, grid, taken);
      taken.add(grid.cellOf(to));
    }
    result[name] = to;
  }
  return result;
}

/// The item nearest to `from` in a direction (arrow keys with free positions): among the items on
/// that side, the one with the smallest distance, with the sideways offset weighing double.
String? spatialNeighbour(
  Map<String, Offset> positions,
  String from,
  Offset direction,
) {
  final origin = positions[from];
  if (origin == null) return null;
  String? best;
  var bestScore = double.infinity;
  for (final MapEntry(:key, :value) in positions.entries) {
    if (key == from) continue;
    final d = value - origin;
    final along = d.dx * direction.dx + d.dy * direction.dy;
    if (along <= 0.5) continue;
    final across = (d.dx * direction.dy - d.dy * direction.dx).abs();
    final score = along + 2 * across;
    if (score < bestScore) {
      bestScore = score;
      best = key;
    }
  }
  return best;
}

/// The arrangement of a folder: free ("None") or sorted, Snap to Grid, and the positions by name.
class FolderArrangement {
  FolderArrangement({
    this.free = false,
    this.snap = false,
    Map<String, Offset>? icons,
  }) : icons = icons ?? {};

  bool free;
  bool snap;
  final Map<String, Offset> icons;

  Map<String, Object?> toJson() => {
    'free': free,
    'snap': snap,
    'icons': {
      for (final MapEntry(:key, :value) in icons.entries)
        key: [value.dx, value.dy],
    },
  };

  static FolderArrangement fromJson(Object? data) {
    final map = data is Map ? data : const {};
    final icons = map['icons'] is Map ? map['icons'] as Map : const {};
    return FolderArrangement(
      free: map['free'] == true,
      snap: map['snap'] == true,
      icons: {
        for (final MapEntry(:key, :value) in icons.entries)
          if (key is String &&
              value is List &&
              value.length == 2 &&
              value[0] is num &&
              value[1] is num &&
              (value[0] as num).isFinite &&
              (value[1] as num).isFinite)
            key: Offset(
              (value[0] as num).toDouble(),
              (value[1] as num).toDouble(),
            ),
      },
    );
  }
}

/// The arrangements of all folders, in one file. A missing or damaged file counts as empty: never
/// an error.
class IconPositions {
  IconPositions(this.path) {
    _read();
  }

  void _read() {
    try {
      final data = jsonDecode(File(path).readAsStringSync());
      if (data is Map) {
        for (final MapEntry(:key, :value) in data.entries) {
          if (key is String) _folders[key] = FolderArrangement.fromJson(value);
        }
      }
    } on Object {
      // Missing or damaged: start from no arrangement.
    }
  }

  factory IconPositions.forUser(Map<String, String> env) {
    final home = env['HOME'] ?? '/';
    final state = env['XDG_STATE_HOME'];
    final base = state == null || state.isEmpty ? '$home/.local/state' : state;
    return IconPositions('$base/mustache/icon-positions.json');
  }

  final String path;
  final Map<String, FolderArrangement> _folders = {};

  /// The arrangement of `folder` (an empty one, sorted, if it has none).
  FolderArrangement of(String folder) =>
      _folders[folder] ?? FolderArrangement();

  /// Saves the arrangement of `folder`. The file is read again first: another Mustache process may
  /// have saved other folders in the meantime.
  void put(String folder, FolderArrangement arrangement) {
    _read();
    _folders[folder] = arrangement;
    save();
  }

  void save() {
    try {
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        jsonEncode({
          for (final MapEntry(:key, :value) in _folders.entries)
            key: value.toJson(),
        }),
      );
    } on FileSystemException {
      // Without write permission the arrangement lasts only for this session.
    }
  }
}
