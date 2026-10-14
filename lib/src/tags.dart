// Tags (MU-62, mustache-spec 2.8, 10.1, "Questions › Tags"): the 7 colors with a name each, stored
// in the file attribute `user.xdg.tags`. Two palettes: saturated in the sidebar (13 pt filled
// circle, no outline), light in the menu (14 pt, 20 on hover with + / ✓ / ×) and in the list (10
// pt, with a 1 pt ring of the same darker hue; several tags overlap at a 5 pt pitch with a ring in
// the background color).

import 'package:flutter/widgets.dart';

enum TagColor { red, orange, yellow, green, blue, purple, gray }

/// The default tags: name and color.
const Map<String, TagColor> defaultTags = {
  'Rosso': TagColor.red,
  'Arancio': TagColor.orange,
  'Giallo': TagColor.yellow,
  'Verde': TagColor.green,
  'Blu': TagColor.blue,
  'Viola': TagColor.purple,
  'Grigio': TagColor.gray,
};

/// The tag name of a color.
String tagName(TagColor color) =>
    defaultTags.entries.firstWhere((e) => e.value == color).key;

/// The color of a tag (null: a tag without a color).
TagColor? tagColor(String name) => defaultTags[name];

/// The sidebar palette (sRGB, red/orange/yellow measured; the others estimated).
Color sidebarTagColor(TagColor c, {required bool dark}) => switch (c) {
  TagColor.red => dark ? const Color(0xFFFF5E5F) : const Color(0xFFFB001A),
  TagColor.orange => dark ? const Color(0xFFFFBF0C) : const Color(0xFFF87B00),
  TagColor.yellow => dark ? const Color(0xFFFFF600) : const Color(0xFFF2B400),
  TagColor.green => const Color(0xFF28C840),
  TagColor.blue => const Color(0xFF0A84FF),
  TagColor.purple => const Color(0xFFBF5AF2),
  TagColor.gray => const Color(0xFF8E8E93),
};

/// The palette of the menu and the list (sRGB, mustache-spec 10.1).
Color menuTagColor(TagColor c) => switch (c) {
  TagColor.red => const Color(0xFFFF6663),
  TagColor.orange => const Color(0xFFFFA356),
  TagColor.yellow => const Color(0xFFFFD54C),
  TagColor.green => const Color(0xFF65D27B),
  TagColor.blue => const Color(0xFF49A0FF),
  TagColor.purple => const Color(0xFFD859E7),
  TagColor.gray => const Color(0xFFA5A5A9),
};

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

/// The dots of an item in the list or under an icon: 10 pt, overlapping at a 5 pt pitch, the first
/// in front.
class TagDots extends StatelessWidget {
  const TagDots({super.key, required this.tags, this.background});

  final List<String> tags;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final colors = [
      for (final t in tags)
        if (tagColor(t) case final c?) menuTagColor(c),
    ];
    if (colors.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: 10 + 5.0 * (colors.length - 1),
      height: 10,
      child: Stack(
        children: [
          // From the back: the last behind, the first in front; those in front have a ring in the
          // background color, which separates them from the one behind.
          for (var i = colors.length - 1; i >= 0; i--)
            Positioned(
              left: 5.0 * i,
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
              key: ValueKey('tag ${tagName(c)}'),
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
        TagDot(color: menuTagColor(c), side: side),
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
