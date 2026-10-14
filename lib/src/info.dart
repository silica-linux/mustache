// The Get Info window (⌘I, MU-60, docs/spec/info.md): 265 wide, as tall as its content; a header
// with the 44 pt icon, the name in semibold, the size and the date; sections with a chevron that
// open and close (the state applies to all Info windows, R11.1): General, Name & Extension,
// Comments, Open With, Preview, Sharing & Permissions. Labels right-aligned up to x 91, values from
// x 93, ~11 pt text.
//
// In Silica it lives inside the Mustache window (the embedder has no child windows).

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'icon_view.dart' show EntryIcon;
import 'model.dart';
import 'xattr.dart';

const double infoWidth = 265;
const double infoLabelRight = 91;
const double infoValueLeft = 93;

/// The sections, in order.
enum InfoSection { general, name, comments, openWith, preview, permissions }

String infoSectionTitle(InfoSection s) => switch (s) {
  InfoSection.general => l10n.infoGeneral,
  InfoSection.name => l10n.infoNameExtension,
  InfoSection.comments => l10n.infoComments,
  InfoSection.openWith => l10n.openWith,
  InfoSection.preview => l10n.infoPreview,
  InfoSection.permissions => l10n.infoPermissions,
};

/// What `stat` says about a file that `FileStat` does not have: creation, disk usage, owner and
/// group.
class StatDetails {
  const StatDetails({
    this.created,
    this.blocks = 0,
    this.owner = '',
    this.group = '',
    this.mode = 0,
  });

  final DateTime? created;
  final int blocks;
  final String owner;
  final String group;
  final int mode;

  int get onDisk => blocks * 512;

  /// From the output of `stat -c '%W %b %U %G %a'`.
  static StatDetails parse(String line) {
    final parts = line.trim().split(' ');
    if (parts.length < 5) return const StatDetails();
    final birth = int.tryParse(parts[0]) ?? 0;
    return StatDetails(
      created: birth > 0
          ? DateTime.fromMillisecondsSinceEpoch(birth * 1000)
          : null,
      blocks: int.tryParse(parts[1]) ?? 0,
      owner: parts[2],
      group: parts[3],
      mode: int.tryParse(parts[4], radix: 8) ?? 0,
    );
  }

  static StatDetails of(String path) {
    try {
      final r = Process.runSync('stat', ['-c', '%W %b %U %G %a', path]);
      return r.exitCode == 0 ? parse('${r.stdout}') : const StatDetails();
    } on ProcessException {
      return const StatDetails();
    }
  }
}

/// The privileges of a class (owner, group, others) as the menu shows them.
enum Privilege { readWrite, readOnly, writeOnly, none }

String privilegeLabel(Privilege p) => switch (p) {
  Privilege.readWrite => l10n.privilegeReadWrite,
  Privilege.readOnly => l10n.privilegeReadOnly,
  Privilege.writeOnly => l10n.privilegeWriteOnly,
  Privilege.none => l10n.privilegeNone,
};

/// The privileges of the class `shift` (6 owner, 3 group, 0 others) in the mode.
Privilege privilegeOf(int mode, int shift) {
  final r = mode >> (shift + 2) & 1 == 1;
  final w = mode >> (shift + 1) & 1 == 1;
  return r && w
      ? Privilege.readWrite
      : r
      ? Privilege.readOnly
      : w
      ? Privilege.writeOnly
      : Privilege.none;
}

/// The mode with the privileges of the class `shift` changed (execute stays as it is).
int withPrivilege(int mode, int shift, Privilege p) {
  final bits = switch (p) {
    Privilege.readWrite => 6,
    Privilege.readOnly => 4,
    Privilege.writeOnly => 2,
    Privilege.none => 0,
  };
  return (mode & ~(6 << shift)) | (bits << shift);
}

String _date(DateTime? t) => t == null ? '--' : longDate(t);

/// Window colors (MU-60); in dark: background `#272728`, white text,
/// secondary `#9e9e9e`, title `#a1a1a1`, lines `#3c3c3d`; the link in dark is *estimated*.
@immutable
class InfoColors {
  const InfoColors({
    required this.fill,
    required this.text,
    required this.secondary,
    required this.title,
    required this.line,
    required this.fieldBorder,
    required this.link,
  });

  final Color fill;
  final Color text;
  final Color secondary;
  final Color title;
  final Color line;
  final Color fieldBorder;
  final Color link;

  static const InfoColors light = InfoColors(
    fill: Color(0xFFFFFFFF),
    text: Color(0xFF1A1A1A),
    secondary: Color(0xFF6E6E73),
    title: Color(0xFF4D4D4D),
    line: Color(0xFFE6E6E6),
    fieldBorder: Color(0xFFD0D0D0),
    link: Color(0xFF0064E1),
  );

  static const InfoColors dark = InfoColors(
    fill: Color(0xFF272728),
    text: Color(0xFFFFFFFF),
    secondary: Color(0xFF9E9E9E),
    title: Color(0xFFA1A1A1),
    line: Color(0xFF3C3C3D),
    fieldBorder: Color(0xFF353535),
    link: Color(0xFF0A84FF),
  );

  static InfoColors of(BuildContext context) =>
      MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark
      ? dark
      : light;
}

class InfoPanel extends StatefulWidget {
  const InfoPanel({
    super.key,
    required this.entry,
    required this.kind,
    required this.open,
    required this.onToggle,
    required this.onClose,
    required this.onRename,
    this.openWith,
    this.env,
  });

  final Entry entry;

  /// The description of the type (as in the Kind column).
  final String kind;

  /// The open sections and the click on the chevron.
  final Set<InfoSection> open;
  final ValueChanged<InfoSection> onToggle;
  final VoidCallback onClose;

  /// The name typed in the Name field (Return renames right away, R8.8).
  final ValueChanged<String> onRename;

  /// The app that opens the file (null for folders).
  final String? openWith;
  final Map<String, String>? env;

  @override
  State<InfoPanel> createState() => _InfoPanelState();
}

class _InfoPanelState extends State<InfoPanel> {
  late StatDetails _stat = StatDetails.of(widget.entry.path);
  late final TextEditingController _name = TextEditingController(
    text: widget.entry.name,
  );
  late final TextEditingController _comment = TextEditingController(
    text: readAttribute(widget.entry.path, commentAttribute) ?? '',
  );
  final FocusNode _commentFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // The comment is saved when leaving the field (R11.2).
    _commentFocus.addListener(() {
      if (!_commentFocus.hasFocus) {
        writeAttribute(
          widget.entry.path,
          commentAttribute,
          _comment.text.trim(),
        );
      }
    });
  }

  @override
  void didUpdateWidget(InfoPanel old) {
    super.didUpdateWidget(old);
    if (old.entry.path != widget.entry.path) {
      _stat = StatDetails.of(widget.entry.path);
      _name.text = widget.entry.name;
      _comment.text = readAttribute(widget.entry.path, commentAttribute) ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _comment.dispose();
    _commentFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  InfoColors get _c => InfoColors.of(context);

  TextStyle _text({double size = 11, FontWeight? weight, Color? color}) =>
      TextStyle(
        fontFamily: uiFontFamily,
        package: 'silica_ui',
        fontSize: size,
        fontWeight: weight,
        color: color ?? _c.text,
      );

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Container(
      key: ValueKey('info ${entry.path}'),
      width: infoWidth,
      decoration: BoxDecoration(
        color: _c.fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x40000000), width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _titleBar(entry),
              _header(entry),
              for (final section in InfoSection.values)
                if (section != InfoSection.openWith || !entry.isDirectory)
                  _section(section),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleBar(Entry entry) => SizedBox(
    height: 28,
    child: Row(
      children: [
        const SizedBox(width: 10),
        GestureDetector(
          key: const ValueKey('close info'),
          onTap: widget.onClose,
          child: Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFFFF5F57),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child: Text(
            l10n.infoTitle(entry.name),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _text(size: 12, weight: FontWeight.w600, color: _c.title),
          ),
        ),
        const SizedBox(width: 22),
      ],
    ),
  );

  Widget _header(Entry entry) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
    child: Row(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: EntryIcon(entry: entry, side: 44, env: widget.env),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _text(size: 13, weight: FontWeight.w600),
                    ),
                  ),
                  if (!entry.isDirectory)
                    Text(formatSize(entry), style: _text(color: _c.secondary)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                l10n.modifiedOn(_date(entry.modified)),
                style: _text(color: _c.secondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _section(InfoSection section) {
    final open = widget.open.contains(section);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 1, color: _c.line),
        GestureDetector(
          key: ValueKey('section ${section.name}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onToggle(section),
          child: SizedBox(
            height: 20,
            child: Row(
              children: [
                const SizedBox(width: 16),
                SizedBox(
                  width: 15,
                  child: Text(
                    open ? '⌄' : '›',
                    style: _text(size: 12, color: _c.secondary),
                  ),
                ),
                Expanded(
                  child: Text(
                    infoSectionTitle(section),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _text(weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _content(section),
          ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1.5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: infoLabelRight,
          child: Text(
            '$label:',
            textAlign: TextAlign.right,
            style: _text(color: _c.secondary),
          ),
        ),
        const SizedBox(width: infoValueLeft - infoLabelRight),
        Expanded(child: Text(value, style: _text())),
        const SizedBox(width: 10),
      ],
    ),
  );

  Widget _content(InfoSection section) {
    final entry = widget.entry;
    switch (section) {
      case InfoSection.general:
        return Column(
          children: [
            _row(l10n.kind, widget.kind),
            if (!entry.isDirectory)
              _row(
                l10n.size,
                l10n.sizeOnDisk(
                  entry.size,
                  formatSize(
                    Entry(
                      name: '',
                      path: '',
                      isDirectory: false,
                      size: _stat.onDisk,
                      modified: entry.modified,
                    ),
                  ),
                ),
              ),
            _row(l10n.location, parentOf(entry.path) ?? '/'),
            _row(l10n.created, _date(_stat.created)),
            _row(l10n.modified, _date(entry.modified)),
          ],
        );
      case InfoSection.name:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _field(
            _name,
            _nameFocus,
            key: 'name field',
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) widget.onRename(value.trim());
            },
          ),
        );
      case InfoSection.comments:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _field(
            _comment,
            _commentFocus,
            key: 'comment field',
            lines: 3,
            onSubmitted: (_) => _commentFocus.unfocus(),
          ),
        );
      case InfoSection.openWith:
        return _row(l10n.app, widget.openWith ?? l10n.none);
      case InfoSection.preview:
        return Center(
          child: SizedBox(
            width: 128,
            height: 128,
            child: EntryIcon(entry: entry, side: 128, env: widget.env),
          ),
        );
      case InfoSection.permissions:
        return Column(
          children: [
            for (final (label, shift) in [
              (l10n.ownerMe(_stat.owner.isEmpty ? '?' : _stat.owner), 6),
              (_stat.group.isEmpty ? l10n.groupFallback : _stat.group, 3),
              (l10n.everyone, 0),
            ])
              _permission(label, shift),
          ],
        );
    }
  }

  Widget _permission(String who, int shift) {
    final current = privilegeOf(_stat.mode, shift);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      child: Row(
        children: [
          Expanded(child: Text(who, style: _text())),
          // A click moves to the next privilege, applied on disk right away (R11.4).
          GestureDetector(
            key: ValueKey('privilege $shift'),
            onTap: () {
              const order = [
                Privilege.readWrite,
                Privilege.readOnly,
                Privilege.none,
              ];
              final next = order[(order.indexOf(current) + 1) % order.length];
              final mode = withPrivilege(_stat.mode, shift, next);
              try {
                final r = Process.runSync('chmod', [
                  mode.toRadixString(8),
                  widget.entry.path,
                ]);
                if (r.exitCode == 0) {
                  setState(() => _stat = StatDetails.of(widget.entry.path));
                }
              } on ProcessException {
                // Without chmod it stays as it was.
              }
            },
            child: Text(privilegeLabel(current), style: _text(color: _c.link)),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    FocusNode focus, {
    required String key,
    int lines = 1,
    required ValueChanged<String> onSubmitted,
  }) => Container(
    key: ValueKey(key),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: BoxDecoration(
      border: Border.all(color: _c.fieldBorder),
      borderRadius: BorderRadius.circular(5),
    ),
    child: DefaultTextEditingShortcuts(
      child: EditableText(
        controller: controller,
        focusNode: focus,
        style: _text(size: 12),
        cursorColor: _c.text,
        backgroundCursorColor: _c.text,
        selectionColor: const Color(0xFFB3D7FF),
        selectAllOnFocus: false,
        maxLines: lines,
        minLines: lines,
        onSubmitted: onSubmitted,
        onTapOutside: (_) => focus.unfocus(),
      ),
    ),
  );
}
