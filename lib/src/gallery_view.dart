// The gallery (⌘4, MU-23, docs/spec/gallery.md for the behaviour; kit `Apps/Mustache/Gallery`): the
// large preview of the chosen item in a 1 pt outlined box (radius 8) 32 pt from the edges and
// below it, 40 pt lower, the strip of thumbnails (48 pt at a 64 pitch; the choice on a 56 × 56
// sunken rounded square). The strip scrolls to keep the choice visible (R6.1); the preview changes
// without a transition.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'icon_view.dart' show EntryIcon, hasThumbnail;
import 'model.dart';

const double galleryMargin = 32;
const double galleryThumb = 48;
const double galleryPitch = 64;
const double galleryStrip = 56;

/// Between the preview box and the strip, and below the strip.
const double galleryStripGap = 40;
const double galleryBottom = 32;

/// The large icon relative to the short side of the preview box (kit: 196 in a 360 box).
const double galleryIconRatio = 0.55;

/// The strip starts 8 pt inside the margin (kit: first thumbnail 40 from the edge).
const double galleryStripPad = galleryMargin + 8;

class GalleryView extends StatefulWidget {
  const GalleryView({
    super.key,
    required this.entries,
    required this.selected,
    required this.onTap,
    required this.onOpen,
    this.env,
    this.wrapItem,
  });

  /// Wraps every thumbnail (dragging, drop target).
  final Widget Function(Entry entry, Widget child)? wrapItem;

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
    final left = galleryStripPad - 8 + galleryPitch * _index;
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
        final colors = AmalfiTheme.of(context).colors;
        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  galleryMargin,
                  galleryMargin,
                  galleryMargin,
                  galleryStripGap,
                ),
                child: GestureDetector(
                  onDoubleTap: () => widget.onOpen(shown),
                  child: DecoratedBox(
                    key: const ValueKey('preview box'),
                    position: DecorationPosition.foreground,
                    decoration: ShapeDecoration(
                      shape: AmalfiSmoothBorder(
                        radius: 8,
                        side: BorderSide(
                          color: colors.lineSeparator,
                          strokeAlign: BorderSide.strokeAlignInside,
                        ),
                      ),
                    ),
                    child: _big(shown),
                  ),
                ),
              ),
            ),
            SizedBox(
              key: const ValueKey('thumbnail strip'),
              height: galleryStrip + galleryBottom,
              child: ListView.builder(
                controller: _strip,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                  galleryStripPad - (galleryPitch - galleryStrip) / 2,
                  0,
                  galleryMargin,
                  galleryBottom,
                ),
                itemCount: entries.length,
                itemExtent: galleryPitch,
                itemBuilder: (context, i) {
                  final entry = entries[i];
                  final chosen = i == _index;
                  final wrap = widget.wrapItem ?? (_, Widget child) => child;
                  return wrap(
                    entry,
                    Listener(
                      onPointerDown: (_) => widget.onTap(entry),
                      child: GestureDetector(
                        key: ValueKey('thumbnail ${entry.path}'),
                        onDoubleTap: () => widget.onOpen(entry),
                        child: Center(
                          child: Container(
                            width: galleryStrip,
                            height: galleryStrip,
                            alignment: Alignment.center,
                            decoration: ShapeDecoration(
                              color: chosen ? colors.surfaceSunken : null,
                              shape: AmalfiSmoothBorder(radius: 8),
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

  /// The large preview: the image fitted and centered in the box, or the large icon, 0.55 of the
  /// box (folders, files without a preview, R6.2).
  Widget _big(Entry entry) {
    if (hasThumbnail(entry.name)) {
      return Padding(
        padding: const EdgeInsets.all(1),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Image.file(
            File(entry.path),
            key: const ValueKey('large preview'),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => LayoutBuilder(
              builder: (context, box) => Center(
                child: EntryIcon(
                  entry: entry,
                  side: math.max(
                    16.0,
                    math.min(box.maxWidth, box.maxHeight) * galleryIconRatio,
                  ),
                  env: widget.env,
                ),
              ),
            ),
          ),
        ),
      );
    }
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
