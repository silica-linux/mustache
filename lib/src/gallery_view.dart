// The gallery (⌘4, MU-23, docs/spec/gallery.md): the large preview of the chosen item (32 pt from the
// edges, 1 pt outline, no shadow) and below it the strip of thumbnails (48 pt at a 59 pitch, 54
// tall; the choice in a 54 × 54 rounded square). The strip scrolls to keep the choice visible
// (R6.1); the preview changes without a transition.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'icon_view.dart' show EntryIcon, hasThumbnail;
import 'model.dart';

const double galleryMargin = 32;
const double galleryThumb = 48;
const double galleryPitch = 59;
const double galleryStrip = 54;
const Color galleryOutline = Color(0xFFF2F2F2);
const Color galleryOutlineDark = Color(0xFF313132);

/// The large icon relative to the short side of the preview (MU-23).
const double galleryIconRatio = 0.94;
const Color galleryChosen = Color(0xFFBDBDBD);

/// The choice in dark (MU-23).
const Color galleryChosenDark = Color(0xFF5C5C5D);

bool _dark(BuildContext context) =>
    MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark;

class GalleryView extends StatefulWidget {
  const GalleryView({
    super.key,
    required this.entries,
    required this.selected,
    required this.onTap,
    required this.onOpen,
    this.env,
  });

  final List<Entry> entries;

  /// The chosen item (null: the first).
  final String? selected;
  final ValueChanged<Entry> onTap;
  final ValueChanged<Entry> onOpen;
  final Map<String, String>? env;

  @override
  State<GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  final ScrollController _strip = ScrollController();

  @override
  void dispose() {
    _strip.dispose();
    super.dispose();
  }

  int get _index {
    final i = widget.entries.indexWhere((e) => e.path == widget.selected);
    return i < 0 ? 0 : i;
  }

  /// The strip scrolls just enough to keep the choice visible (R6.1).
  void _reveal(double width) {
    if (!_strip.hasClients) return;
    final left = 8 + galleryPitch * _index;
    final right = left + galleryPitch;
    final offset = _strip.offset;
    if (left < offset) {
      _strip.jumpTo(left);
    } else if (right > offset + width) {
      _strip.jumpTo(math.min(right - width, _strip.position.maxScrollExtent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    if (entries.isEmpty) return const SizedBox.expand();
    final shown = entries[_index];
    return LayoutBuilder(
      builder: (context, box) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _reveal(box.maxWidth),
        );
        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(galleryMargin),
                child: GestureDetector(
                  onDoubleTap: () => widget.onOpen(shown),
                  child: _big(shown),
                ),
              ),
            ),
            SizedBox(
              key: const ValueKey('thumbnail strip'),
              height: galleryStrip + 12,
              child: ListView.builder(
                controller: _strip,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: entries.length,
                itemExtent: galleryPitch,
                itemBuilder: (context, i) {
                  final entry = entries[i];
                  final chosen = i == _index;
                  return Listener(
                    onPointerDown: (_) => widget.onTap(entry),
                    child: GestureDetector(
                      key: ValueKey('thumbnail ${entry.path}'),
                      onDoubleTap: () => widget.onOpen(entry),
                      child: Center(
                        child: Container(
                          width: galleryStrip,
                          height: galleryStrip,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: chosen
                                ? (_dark(context)
                                      ? galleryChosenDark
                                      : galleryChosen)
                                : null,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: SizedBox(
                            width: galleryThumb,
                            height: galleryThumb,
                            child: EntryIcon(
                              entry: entry,
                              side: galleryThumb,
                              env: widget.env,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// The large preview: the image fitted and centered with the 1 pt outline, or the large icon, as
  /// big as the preview square (folders, files without a preview, R6.2).
  Widget _big(Entry entry) {
    if (hasThumbnail(entry.name)) {
      return Center(
        child: DecoratedBox(
          key: const ValueKey('large preview'),
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.all(
              color: _dark(context) ? galleryOutlineDark : galleryOutline,
            ),
          ),
          child: Image.file(
            File(entry.path),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => LayoutBuilder(
              builder: (context, box) => EntryIcon(
                entry: entry,
                side: math.max(16.0, math.min(box.maxWidth, box.maxHeight)),
                env: widget.env,
              ),
            ),
          ),
        ),
      );
    }
    // The icon takes ~0.94 of the preview square (MU-23: box 494 × 525, folder 427
    // wide, i.e. an icon of ~464; images fill it instead).
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.max(
          16.0,
          math.min(box.maxWidth, box.maxHeight) * galleryIconRatio,
        );
        return Center(
          key: const ValueKey('large preview'),
          child: EntryIcon(entry: entry, side: side, env: widget.env),
        );
      },
    );
  }
}
