// Le etichette (MU-62, mustache-spec 2.8, 10.1, "Domande › Etichette"): i 7 colori con un nome
// ciascuno, salvate nell'attributo `user.xdg.tags` del file. Due tavolozze: satura nella barra
// laterale (cerchio pieno di 13 pt, senza contorno), chiara nel menu (14 pt, 20 al passaggio con
// + / ✓ / ×) e nell'elenco (10 pt, con un anello di 1 pt della stessa tinta più scura; più
// etichette si sovrappongono a passo 5 con un anello del colore del fondo).

import 'package:flutter/widgets.dart';

enum TagColor { red, orange, yellow, green, blue, purple, gray }

/// Le etichette predefinite: nome e colore.
const Map<String, TagColor> defaultTags = {
  'Rosso': TagColor.red,
  'Arancio': TagColor.orange,
  'Giallo': TagColor.yellow,
  'Verde': TagColor.green,
  'Blu': TagColor.blue,
  'Viola': TagColor.purple,
  'Grigio': TagColor.gray,
};

/// Il nome dell'etichetta di un colore.
String tagName(TagColor color) =>
    defaultTags.entries.firstWhere((e) => e.value == color).key;

/// Il colore di un'etichetta (null: un'etichetta senza colore).
TagColor? tagColor(String name) => defaultTags[name];

/// La tavolozza della barra laterale (sRGB, rosso/arancio/giallo misurati; gli altri stimati).
Color sidebarTagColor(TagColor c, {required bool dark}) => switch (c) {
  TagColor.red => dark ? const Color(0xFFFF5E5F) : const Color(0xFFFB001A),
  TagColor.orange => dark ? const Color(0xFFFFBF0C) : const Color(0xFFF87B00),
  TagColor.yellow => dark ? const Color(0xFFFFF600) : const Color(0xFFF2B400),
  TagColor.green => const Color(0xFF28C840),
  TagColor.blue => const Color(0xFF0A84FF),
  TagColor.purple => const Color(0xFFBF5AF2),
  TagColor.gray => const Color(0xFF8E8E93),
};

/// La tavolozza del menu e dell'elenco (sRGB, mustache-spec 10.1).
Color menuTagColor(TagColor c) => switch (c) {
  TagColor.red => const Color(0xFFFF6663),
  TagColor.orange => const Color(0xFFFFA356),
  TagColor.yellow => const Color(0xFFFFD54C),
  TagColor.green => const Color(0xFF65D27B),
  TagColor.blue => const Color(0xFF49A0FF),
  TagColor.purple => const Color(0xFFD859E7),
  TagColor.gray => const Color(0xFFA5A5A9),
};

/// L'anello di 1 pt: la stessa tinta ~10 % più scura.
Color tagRing(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0)).toColor();
}

/// Un pallino: pieno, con l'anello più scuro se `ring`; senza colore è un anello grigio.
class TagDot extends StatelessWidget {
  const TagDot({
    super.key,
    required this.color,
    required this.side,
    this.ring = true,
    this.outline,
  });

  /// null: etichetta senza colore (anello grigio `#6e6e74`).
  final Color? color;
  final double side;
  final bool ring;

  /// Un anello esterno nel colore del fondo (pallini sovrapposti nell'elenco).
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

/// I pallini di un elemento nell'elenco o sotto un'icona: 10 pt, sovrapposti a passo 5, il
/// primo davanti.
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
          // Dal fondo: l'ultimo dietro, il primo davanti; quelli davanti hanno l'anello del
          // colore del fondo, che li stacca da quello dietro.
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

/// La fila dei cerchi del menu contestuale: 14 pt a passo 24, il primo a 18 pt dal bordo; al
/// passaggio un cerchio cresce a 20 pt con + (o × se l'etichetta c'è già, ✓ a riposo).
class TagCircleRow extends StatefulWidget {
  const TagCircleRow({
    super.key,
    required this.assigned,
    required this.onToggle,
  });

  /// I colori già assegnati a tutti gli elementi scelti.
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
              key: ValueKey('etichetta ${tagName(c)}'),
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
