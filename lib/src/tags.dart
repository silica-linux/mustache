// Tags (MU-62, docs/spec/sidebar.md, menus-and-settings.md, open-questions.md): the 7 colors with a name each, stored
// in the file attribute `user.xdg.tags`. Two palettes: saturated in the sidebar (13 pt filled
// circle, no outline), light in the menu (14 pt, 20 on hover with + / ✓ / ×) and in the list (10
// pt, with a 1 pt ring of the same darker hue; several tags overlap at a 5 pt pitch with a ring in
// the background color).

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';

enum TagColor { red, orange, yellow, green, blue, purple, gray }

/// The names of the default tags in every language Mustache has: tags are stored on the files by
/// name, so a tag written in another language keeps its color.
const Map<TagColor, List<String>> defaultTagNames = {
  TagColor.red: ['Red', 'Rosso'],
  TagColor.orange: ['Orange', 'Arancio'],
  TagColor.yellow: ['Yellow', 'Giallo'],
  TagColor.green: ['Green', 'Verde'],
  TagColor.blue: ['Blue', 'Blu'],
  TagColor.purple: ['Purple', 'Viola'],
  TagColor.gray: ['Gray', 'Grigio'],
};

/// The tag name of a color, in the user's language (written on new tags).
String tagName(TagColor color) => switch (color) {
  TagColor.red => l10n.tagRed,
  TagColor.orange => l10n.tagOrange,
  TagColor.yellow => l10n.tagYellow,
  TagColor.green => l10n.tagGreen,
  TagColor.blue => l10n.tagBlue,
  TagColor.purple => l10n.tagPurple,
  TagColor.gray => l10n.tagGray,
};

/// The color of a tag, from its name in any language (null: a tag without a color).
TagColor? tagColor(String name) {
  for (final MapEntry(key: color, value: names) in defaultTagNames.entries) {
    if (names.contains(name)) return color;
  }
  return null;
}

/// Is `name` the tag `wanted`, or the same default color tag in another language?
bool sameTag(String name, String wanted) =>
    name == wanted ||
    (tagColor(wanted) != null && tagColor(name) == tagColor(wanted));

/// The color of a tag in the Amalfi palette (kit `Apps/Mustache/Tag Row`: Red, Orange, Green, Blue
/// and Purple are `Palette/Terracotta`, `Palette/Limone`, `Palette/Ulivo`, `Accent/Amalfi` and
/// `Palette/Lavanda`).
Color tagPaletteColor(TagColor c, {required bool dark}) {
  final colors = AmalfiColors.of(dark ? Brightness.dark : Brightness.light);
  return switch (c) {
    TagColor.red => colors.paletteTerracotta,
    TagColor.orange => colors.paletteLimone,
    // Assumption: not measured (the kit has no Yellow or Gray tag): a lighter Limone and a neutral.
    TagColor.yellow => dark ? const Color(0xFFFFE680) : const Color(0xFFFFE14D),
    TagColor.green => colors.paletteUlivo,
    TagColor.blue => colors.accentAmalfi,
    TagColor.purple => colors.paletteLavanda,
    TagColor.gray => colors.textTertiary,
  };
}

/// The sidebar palette.
Color sidebarTagColor(TagColor c, {required bool dark}) =>
    tagPaletteColor(c, dark: dark);

/// The palette of the menus and the list.
Color menuTagColor(TagColor c, {bool dark = false}) =>
    tagPaletteColor(c, dark: dark);

/// The 1 pt ring: the same hue ~10% darker.
Color tagRing(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0)).toColor();
}

/// A dot: filled, with the darker ring if `ring`; without a color it is a gray ring.
class TagDot extends StatelessWidget {
  const TagDot({
    super.key,
    required this.color,
    required this.side,
    this.ring = true,
    this.outline,
  });

  /// null: tag without a color (gray ring `#6e6e74`).
  final Color? color;
  final double side;
  final bool ring;

  /// An outer ring in the background color (overlapping dots in the list).
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    final c = color;
    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c,
        border: c == null
            ? Border.all(color: const Color(0xFF6E6E74), width: 1.2)
            : ring
            ? Border.all(color: tagRing(c))
            : null,
        boxShadow: outline == null
            ? null
            : [BoxShadow(color: outline!, spreadRadius: 1)],
      ),
    );
  }
}

/// The offset of the dot behind in the list (and the columns) and under an icon (FOLDER-CUSTOM).
const double listTagPitch = 5;
const double iconTagPitch = 6;

/// The dots of an item in the list or under an icon: 10 pt, overlapping at a 5 pt pitch (6 pt under
/// an icon), the last assigned in front, on the left. Tags are stored in the order they were
/// assigned.
class TagDots extends StatelessWidget {
  const TagDots({
    super.key,
    required this.tags,
    this.background,
    this.pitch = listTagPitch,
  });

  final List<String> tags;
  final Color? background;
  final double pitch;

  @override
  Widget build(BuildContext context) {
    final colors = [
      for (final t in tags.reversed)
        if (tagColor(t) case final c?)
          menuTagColor(c, dark: AmalfiTheme.of(context).isDark),
    ];
    if (colors.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: 10 + pitch * (colors.length - 1),
      height: 10,
      child: Stack(
        children: [
          // From the back: the first assigned behind, the last assigned in front; those in front have a ring in the
          // background color, which separates them from the one behind.
          for (var i = colors.length - 1; i >= 0; i--)
            Positioned(
              left: pitch * i,
              child: TagDot(
                color: colors[i],
                side: 10,
                outline: i == colors.length - 1
                    ? null
                    : (background ?? const Color(0xFFFFFFFF)),
              ),
            ),
        ],
      ),
    );
  }
}

/// The row of circles of the context menu: 14 pt at a 24 pitch, the first 18 pt from the edge; on
/// hover a circle grows to 20 pt with + (or × if the tag is already there, ✓ at rest).
class TagCircleRow extends StatefulWidget {
  const TagCircleRow({
    super.key,
    required this.assigned,
    required this.onToggle,
  });

  /// The colors already assigned to all the chosen items.
  final Set<TagColor> assigned;
  final ValueChanged<TagColor> onToggle;

  @override
  State<TagCircleRow> createState() => _TagCircleRowState();
}

class _TagCircleRowState extends State<TagCircleRow> {
  TagColor? _hovered;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 18 - 3),
    child: Row(
      children: [
        for (final c in TagColor.values)
          MouseRegion(
            onEnter: (_) => setState(() => _hovered = c),
            onExit: (_) => setState(() {
              if (_hovered == c) _hovered = null;
            }),
            child: GestureDetector(
              key: ValueKey('tag ${c.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onToggle(c),
              child: SizedBox(
                width: 24,
                height: 25,
                child: Center(child: _circle(c)),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _circle(TagColor c) {
    final hovered = _hovered == c;
    final assigned = widget.assigned.contains(c);
    final side = hovered ? 20.0 : 14.0;
    final glyph = hovered
        ? (assigned ? '×' : '+')
        : assigned
        ? '✓'
        : null;
    return Stack(
      alignment: Alignment.center,
      children: [
        TagDot(
          color: menuTagColor(c, dark: AmalfiTheme.of(context).isDark),
          side: side,
        ),
        if (glyph != null)
          Text(
            glyph,
            style: TextStyle(
              fontSize: hovered ? 14 : 10,
              height: 1,
              color: const Color(0xFFFFFFFF),
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
