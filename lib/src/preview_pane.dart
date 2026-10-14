// The preview pane (⇧⌘P, MU-05, docs/spec/preview-pane.md) and the gallery one (MU-23, docs/spec/gallery.md): right of
// the content, 264 wide (250 in the gallery), background `#ececec` without a separator line.
//
// At the top of the pane: the 244 × 320 preview with a 10 pt margin, then the name in semibold and
// "Kind - size". In the gallery (`compact`) the large preview is already on the left: at the top
// there is the 50 pt icon with the name and "Kind - size" beside it (MU-23).
//
// Then, the same in both (measured on MU-23, y from the top of the pane):
// Information in bold 13 (baseline 100), 23 pt rows with an 11 pt `#858787` label on the left and
// an 11 pt `#353537` value on the right, 1 pt `#d5d5d5` lines below (130, 153); Tags in bold
// (baseline 180) and the white add-a-tag field 33 tall from y 190; at the bottom the
// actions bar, white, 70 tall.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'icon_view.dart' show EntryIcon, hasThumbnail;
import 'info.dart' show StatDetails;
import 'model.dart';
import 'quick_preview.dart' show isTextPreview;

const double previewPaneWidth = 264;
const Size previewBox = Size(244, 320);
const double paneActionsHeight = 70;
const double paneRow = 23;
const double paneTagField = 33;
const double paneCompactIcon = 50;

const Color paneFill = Color(0xFFECECEC);
const Color paneLine = Color(0xFFD5D5D5);
const Color paneName = Color(0xFF474747);
const Color paneKind = Color(0xFFB8B8B9);
const Color paneLabel = Color(0xFF858787);
const Color paneValue = Color(0xFF353537);
const Color paneHeading = Color(0xFF1A1A1A);
const Color panePlaceholder = Color(0xFFB4B4B4);

/// Pane colors (MU-05), light and dark (dark texts from the lightest pixels of
/// MU-05).
@immutable
class PaneColors {
  const PaneColors({
    required this.fill,
    required this.line,
    required this.name,
    required this.kind,
    required this.label,
    required this.value,
    required this.heading,
    required this.placeholder,
    required this.actions,
    required this.actionText,
    required this.actionIcon,
    required this.field,
  });

  final Color fill;
  final Color line;
  final Color name;
  final Color kind;
  final Color label;
  final Color value;
  final Color heading;
  final Color placeholder;
  final Color actions;
  final Color actionText;
  final Color actionIcon;
  final Color field;

  static const PaneColors light = PaneColors(
    fill: paneFill,
    line: paneLine,
    name: paneName,
    kind: paneKind,
    label: paneLabel,
    value: paneValue,
    heading: paneHeading,
    placeholder: panePlaceholder,
    actions: Color(0xFFFFFFFF),
    actionText: Color(0xFF6E6E6E),
    actionIcon: Color(0xFF6E6E6E),
    field: Color(0xFFFFFFFF),
  );

  static const PaneColors dark = PaneColors(
    fill: Color(0xFF2A2A2B),
    line: Color(0xFF474748),
    name: Color(0xFFEAEAEA),
    kind: Color(0xFF5B5B5C),
    label: Color(0xFF7E7E80),
    value: Color(0xFFE9E9E9),
    heading: Color(0xFFEAEAEA),
    placeholder: Color(0xFF5C5C5D),
    actions: Color(0xFF272728),
    actionText: Color(0xFF939393),
    actionIcon: Color(0xFF9E9E9E),
    field: Color(0xFF272728),
  );

  static PaneColors of(BuildContext context) =>
      MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark
      ? dark
      : light;
}

TextStyle _text(double size, {FontWeight? weight, Color color = paneHeading}) =>
    TextStyle(
      fontFamily: uiFontFamily,
      package: 'silica_ui',
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1,
    );

/// A text with its baseline at `baseline` from the top of its box.
Widget _onBaseline(Widget text, double baseline) => Baseline(
  baseline: baseline,
  baselineType: TextBaseline.alphabetic,
  child: text,
);

/// An action of the bottom bar: a symbol with a label below; it receives the click point (to open a
/// menu there).
class PaneAction {
  const PaneAction(this.label, this.symbol, this.onPressed);
  final String label;
  final String symbol;
  final ValueChanged<Offset> onPressed;
}

class PreviewPane extends StatelessWidget {
  const PreviewPane({
    super.key,
    required this.items,
    required this.kindOf,
    this.env,
    this.width = previewPaneWidth,
    this.compact = false,
    this.now,
    this.tagsOf,
    this.onAddTag,
    this.actions = const [],
    this.iconsDir,
  });

  /// 264 wide, 250 in the gallery.
  final double width;

  /// In the gallery: at the top the 50 pt icon with name and kind beside it, no preview.
  final bool compact;

  /// The selection (empty: nothing).
  final List<Entry> items;
  final String Function(Entry entry) kindOf;
  final Map<String, String>? env;

  /// For "today" and "yesterday" in dates (tests fix the time).
  final DateTime? now;

  /// The tags of an item and adding one from the field.
  final List<String> Function(Entry entry)? tagsOf;
  final void Function(Entry entry, String tag)? onAddTag;

  /// The buttons of the bottom bar (empty: no bar).
  final List<PaneAction> actions;

  /// The silica-icons directory, for the action symbols.
  final String? iconsDir;

  @override
  Widget build(BuildContext context) {
    final c = PaneColors.of(context);
    final content = items.isEmpty
        ? const SizedBox.expand()
        : items.length > 1
        ? _many(c)
        : _one(c, items.single);
    return Container(
      key: const ValueKey('preview pane'),
      width: width,
      color: c.fill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: content),
          if (items.isNotEmpty && actions.isNotEmpty) _actionsBar(c),
        ],
      ),
    );
  }

  Widget _many(PaneColors c) {
    final total = items.fold<int>(
      0,
      (sum, e) => sum + (e.isDirectory ? 0 : e.size),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact)
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox.fromSize(
              size: previewBox,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // A fan of rotated icons.
                  for (var i = 0; i < items.length && i < 3; i++)
                    Transform.rotate(
                      angle: (i - 1) * 0.12,
                      child: EntryIcon(entry: items[i], side: 128, env: env),
                    ),
                ],
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(10, compact ? 18 : 0, 10, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.itemCount(items.length),
                style: _text(15, weight: FontWeight.w600, color: c.name),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.documentsSize(
                  items.length,
                  formatSize(
                    Entry(
                      name: '',
                      path: '',
                      isDirectory: false,
                      size: total,
                      modified: DateTime(0),
                    ),
                  ),
                ),
                style: _text(12, color: c.kind),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// `stat` per path and date: not on every paint.
  static final Map<String, StatDetails> _stats = {};

  String _when(DateTime? t) =>
      t == null ? '--' : formatDate(t, now ?? DateTime.now());

  Widget _one(PaneColors c, Entry entry) {
    final key = '${entry.path}\u0000${entry.modified.microsecondsSinceEpoch}';
    if (_stats.length > 500) _stats.clear();
    final stat = _stats[key] ??= StatDetails.of(entry.path);
    final kind = entry.isDirectory
        ? kindOf(entry)
        : '${kindOf(entry)} - ${formatSize(entry)}';
    final name = Text(
      entry.name,
      maxLines: compact ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: _text(15, weight: FontWeight.w600, color: c.name),
    );
    final subtitle = Text(
      kind,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _text(12, color: c.kind),
    );
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact)
            // 50 pt icon at (8, 18); name with baseline at 39 and kind with baseline at 58, from x
            // 69.
            SizedBox(
              height: 76,
              child: Stack(
                children: [
                  Positioned(
                    left: 8,
                    top: 18,
                    width: paneCompactIcon,
                    height: paneCompactIcon,
                    child: EntryIcon(
                      entry: entry,
                      side: paneCompactIcon,
                      env: env,
                    ),
                  ),
                  Positioned(
                    left: 69,
                    right: 10,
                    top: 0,
                    child: _onBaseline(name, 39),
                  ),
                  Positioned(
                    left: 69,
                    right: 10,
                    top: 0,
                    child: _onBaseline(subtitle, 58),
                  ),
                ],
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.all(10),
              child: SizedBox.fromSize(
                size: previewBox,
                child: _preview(entry),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [name, const SizedBox(height: 6), subtitle],
              ),
            ),
            const SizedBox(height: 4),
          ],
          // Information: baseline at 100 in the gallery (24 below the top of this section).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 31,
                  child: _onBaseline(
                    Text(
                      l10n.information,
                      style: _text(
                        13,
                        weight: FontWeight.w700,
                        color: c.heading,
                      ),
                    ),
                    24,
                  ),
                ),
                _row(c, l10n.created, _when(stat.created)),
                _row(
                  c,
                  l10n.modified,
                  _when(entry.modified),
                  last: !hasThumbnail(entry.name),
                ),
                if (hasThumbnail(entry.name))
                  _row(c, l10n.size, formatSize(entry), last: true),
                if (tagsOf != null) ...[
                  SizedBox(
                    height: 37,
                    child: _onBaseline(
                      Text(
                        l10n.tags,
                        style: _text(
                          13,
                          weight: FontWeight.w700,
                          color: c.heading,
                        ),
                      ),
                      27,
                    ),
                  ),
                  _TagField(
                    key: ValueKey('tags field ${entry.path}'),
                    tags: tagsOf!(entry),
                    onAdd: (tag) => onAddTag?.call(entry, tag),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A 23 pt row: label on the left, value on the right, baseline at 15; a 1 pt line separates it
  /// from the next row (none below the last, MU-23).
  Widget _row(PaneColors c, String label, String value, {bool last = false}) =>
      Container(
        height: paneRow,
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: c.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _onBaseline(Text(label, style: _text(11, color: c.label)), 15),
            const SizedBox(width: 8),
            Expanded(
              child: _onBaseline(
                // As wide as the row: the value sits on the right edge.
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _text(11, weight: FontWeight.w600, color: c.value),
                  ),
                ),
                15,
              ),
            ),
          ],
        ),
      );

  Widget _actionsBar(PaneColors c) => Container(
    key: const ValueKey('pane actions'),
    height: paneActionsHeight,
    color: c.actions,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final action in actions)
          GestureDetector(
            key: ValueKey('action ${action.label}'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => action.onPressed(d.globalPosition),
            child: SizedBox(
              width: 74,
              height: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _symbol(c, action.symbol),
                  const SizedBox(height: 6),
                  Text(
                    action.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: _text(11, color: c.actionText),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _symbol(PaneColors c, String name) {
    final dir = iconsDir;
    final file = dir == null ? null : File('$dir/symbols/regular/$name.svg');
    if (file == null || !file.existsSync()) {
      return const SizedBox(width: 18, height: 18);
    }
    return SvgPicture.file(
      file,
      width: 18,
      height: 18,
      colorFilter: ColorFilter.mode(c.actionIcon, BlendMode.srcIn),
    );
  }

  Widget _preview(Entry entry) {
    if (hasThumbnail(entry.name)) {
      return Image.file(
        File(entry.path),
        fit: BoxFit.contain,
        cacheWidth: 488,
        errorBuilder: (_, _, _) => Center(
          child: EntryIcon(entry: entry, side: 128, env: env),
        ),
      );
    }
    if (!entry.isDirectory && isTextPreview(entry.name)) {
      var text = '';
      try {
        final f = File(entry.path).openSync();
        try {
          text = String.fromCharCodes(f.readSync(8192));
        } finally {
          f.closeSync();
        }
      } on FileSystemException {
        text = '';
      }
      return Container(
        color: const Color(0xFFFFFFFF),
        padding: const EdgeInsets.all(10),
        child: Text(
          text,
          overflow: TextOverflow.fade,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: Color(0xFF1A1A1A),
          ),
        ),
      );
    }
    return Center(
      child: EntryIcon(entry: entry, side: 128, env: env),
    );
  }
}

/// The tags field: white, 33 tall; shows the item's tags, Return adds one.
class _TagField extends StatefulWidget {
  const _TagField({super.key, required this.tags, required this.onAdd});
  final List<String> tags;
  final ValueChanged<String> onAdd;

  @override
  State<_TagField> createState() => _TagFieldState();
}

class _TagFieldState extends State<_TagField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final tag = value.trim();
    if (tag.isEmpty) return;
    widget.onAdd(tag);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.tags.join(', ');
    final placeholder = existing.isEmpty ? l10n.addTag : existing;
    final c = PaneColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focus.requestFocus,
      child: Container(
        height: paneTagField,
        color: c.field,
        // Text at the top left (MU-23: baseline ~12 from the top of the field).
        padding: const EdgeInsets.fromLTRB(4, 3, 4, 0),
        alignment: Alignment.topLeft,
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            if (_controller.text.isEmpty)
              IgnorePointer(
                child: Text(
                  placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(
                    12,
                    color: existing.isEmpty ? c.placeholder : c.value,
                  ),
                ),
              ),
            DefaultTextEditingShortcuts(
              child: EditableText(
                controller: _controller,
                focusNode: _focus,
                style: _text(12, color: c.value),
                cursorColor: c.value,
                backgroundCursorColor: c.value,
                selectionColor: const Color(0xFFB3D7FF),
                maxLines: 1,
                onSubmitted: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
