// The column view (MU-22, docs/spec/column-view.md for the behaviour; kit `Apps/Mustache/Columns`,
// `Column Row/*`): one column for each folder from the root (the sidebar entry it starts from, R5.1)
// down to the open one; the chosen item is highlighted in its column (accent in the active column,
// a soft separator tone in those on the left). Columns are 240 wide with a 1 pt separator between
// them; rows 28 tall from 8 below the top. Columns do not shrink: the view scrolls horizontally and
// jumps to the end right away when a new one opens (R5.4, R5.5).

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'icon_view.dart' show EntryIcon;
import 'list_view.dart' show middleEllipsis;
import 'model.dart';
import 'tags.dart' show TagDots;

/// A column: 240 wide, rows 28 tall from 8 below the top, the selection inset 8 (radius 8), the icon
/// at 16, the name at 40, the 12 pt chevron at 208.
const double columnPitch = 240;
const double columnRow = 28;
const double columnTop = 8;
const double columnIconLeft = 16;
const double columnIconSide = 16;
const double columnTextLeft = 40;
const double columnChevronLeft = 208;
const double columnChevronSide = 12;
const double columnSelectionLeft = 8;
const double columnSelectionWidth = 224;
const double columnSelectionRadius = 8;

/// The folders of the columns: from the root to `current` included (only if `current` is inside
/// `root`; otherwise `current` alone).
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
    this.wrapItem,
  });

  /// Wraps every row (dragging, drop target).
  final Widget Function(Entry entry, Widget child)? wrapItem;

  /// The tags of an item: the dots before the arrow (MU-22).
  final List<String> Function(Entry entry)? tagsOf;

  /// The root (first column) and the open folder (last column).
  final String root;
  final String current;

  /// The chosen item: a file in the column of `current`, or `current` itself if a folder was chosen
  /// (then its column is the last one, without a selection).
  final String? leaf;

  /// The contents of a folder, already sorted (by the window: hidden files, sort order).
  final List<Entry> Function(String dir) list;

  /// Click on an item of the column of `dir`.
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
    final colors = AmalfiTheme.of(context).colors;
    final chain = columnChain(widget.root, widget.current);
    final leaf = widget.leaf;
    // The active column is the one of the chosen item: the file's, or the one containing the chosen
    // folder (the second to last).
    final leafIsCurrent = leaf == widget.current;
    final activeColumn = leafIsCurrent ? chain.length - 2 : chain.length - 1;
    if (chain.length != _columns) {
      // A new column: the view jumps to the end, without animation (R5.4).
      _columns = chain.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
    return ColoredBox(
      color: colors.surfaceWindow,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < chain.length; i++)
              _column(
                chain[i],
                separator: i > 0,
                // In column i the next folder in the chain, or the item, is highlighted.
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
    required bool separator,
    required String? highlighted,
    required bool active,
    required AmalfiColors colors,
  }) {
    final entries = widget.list(dir);
    return SizedBox(
      key: ValueKey('column $dir'),
      width: columnPitch,
      child: Stack(
        children: [
          Positioned.fill(
            child: _RevealList(
              key: ValueKey('list $dir'),
              reveal: entries.indexWhere((e) => e.path == highlighted),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final lit = entry.path == highlighted;
                final fill = !lit
                    ? null
                    : (active ? colors.accentAmalfi : colors.lineSeparator);
                final textColor = lit && active
                    ? colors.textOnAccent
                    : colors.textPrimary;
                final tags = widget.tagsOf?.call(entry) ?? const <String>[];
                final tagsWidth = tags.isEmpty
                    ? 0.0
                    : 10 + 5.0 * (tags.length - 1);
                final wrap = widget.wrapItem ?? (_, Widget child) => child;
                return wrap(
                  entry,
                  Listener(
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
                                decoration: ShapeDecoration(
                                  color: fill,
                                  shape: AmalfiSmoothBorder(
                                    radius: columnSelectionRadius,
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
                          // The name truncated in the middle (MU-22: "Beta con un…nella
                          // colonna"); the tag dots before the arrow.
                          Positioned(
                            left: columnTextLeft,
                            right:
                                columnPitch -
                                columnChevronLeft +
                                4 +
                                (tags.isEmpty ? 0 : tagsWidth + 6),
                            top: 0,
                            bottom: 0,
                            child: LayoutBuilder(
                              builder: (context, box) {
                                final style = AmalfiType.body(color: textColor);
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
                                background: fill ?? colors.surfaceWindow,
                              ),
                            ),
                          if (entry.isDirectory)
                            Positioned(
                              left: columnChevronLeft,
                              top: (columnRow - columnChevronSide) / 2,
                              child: AmalfiGlyph(
                                AmalfiGlyphs.chevronRight,
                                size: columnChevronSide,
                                color: lit && active
                                    ? colors.textOnAccent
                                    : colors.textTertiary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // The 1 pt separator along the left edge (kit: over the first pixel of the column).
          if (separator)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 1,
              child: ColoredBox(color: colors.lineSeparator),
            ),
        ],
      ),
    );
  }
}

/// The list of a column: when it appears, the highlighted entry is scrolled into view (a long
/// column does not hide the folder open on the right).
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
