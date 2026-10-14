// Quick preview (Space, MU-61, mustache-spec 12): a centered panel with a 38 pt top bar (×, name,
// the open-with-app capsule) and a 5 pt frame around the content. The size follows the content: an image at
// its natural size plus 10 × 43 (at least ~370 wide, at most 1256 tall), text 816 × 849, the rest
// (folders, code, archives, files without a preview) 575 × 328 with the large icon, the name and
// the details.
//
// In Silica the panel lives inside the window (the embedder has no child windows yet): it shrinks
// to fit.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'icon_view.dart' show EntryIcon, hasThumbnail;
import 'model.dart';

const double quickPreviewBar = 38;
const double quickPreviewFrame = 5;
const double quickPreviewMaxHeight = 1256;
const double quickPreviewMinWidth = 370;
const Size quickPreviewGeneric = Size(575, 328);
const Size quickPreviewText = Size(816, 849);

/// The extensions shown as text.
const Set<String> textExtensions = {
  'txt',
  'md',
  'log',
  'csv',
  'tsv',
  'json',
  'xml',
  'yaml',
  'yml',
  'toml',
  'ini',
  'conf',
  'rs',
  'dart',
  'py',
  'js',
  'ts',
  'c',
  'h',
  'cpp',
  'go',
  'java',
  'sh',
  'html',
  'css',
};

bool isTextPreview(String name) {
  final dot = name.lastIndexOf('.');
  return dot > 0 &&
      textExtensions.contains(name.substring(dot + 1).toLowerCase());
}

/// The panel size for an image of `natural` pt (spec 12).
Size imagePanelSize(Size natural) {
  var w = natural.width + 2 * quickPreviewFrame;
  var h = natural.height + quickPreviewBar + quickPreviewFrame;
  if (h > quickPreviewMaxHeight) {
    // Fitted to the maximum height, proportionally.
    final scale =
        (quickPreviewMaxHeight - quickPreviewBar - quickPreviewFrame) /
        natural.height;
    w = natural.width * scale + 2 * quickPreviewFrame;
    h = quickPreviewMaxHeight;
  }
  return Size(math.max(w, quickPreviewMinWidth), h);
}

/// Shrinks the panel to fit in `room` (the window), proportionally.
Size fitPanel(Size panel, Size room) {
  final scale = math.min(
    1.0,
    math.min(room.width / panel.width, room.height / panel.height),
  );
  return Size(panel.width * scale, panel.height * scale);
}

class QuickPreviewPanel extends StatefulWidget {
  const QuickPreviewPanel({
    super.key,
    required this.entry,
    required this.onClose,
    this.openWith,
    this.onOpenWith,
    this.position,
    this.env,
  });

  final Entry entry;
  final VoidCallback onClose;

  /// The name of the default app, for the open-with capsule.
  final String? openWith;
  final VoidCallback? onOpenWith;

  /// "N of M" when the selection has several items.
  final (int, int)? position;
  final Map<String, String>? env;

  @override
  State<QuickPreviewPanel> createState() => _QuickPreviewPanelState();
}

class _QuickPreviewPanelState extends State<QuickPreviewPanel> {
  Size? _imageSize;
  String? _text;
  String? _sized;

  void _load() {
    final entry = widget.entry;
    if (_sized == entry.path) return;
    _sized = entry.path;
    _imageSize = null;
    _text = null;
    if (hasThumbnail(entry.name)) {
      final image = FileImage(File(entry.path));
      image
          .resolve(ImageConfiguration.empty)
          .addListener(
            ImageStreamListener((info, _) {
              if (mounted && _sized == entry.path) {
                setState(
                  () => _imageSize = Size(
                    info.image.width.toDouble(),
                    info.image.height.toDouble(),
                  ),
                );
              }
            }, onError: (_, _) {}),
          );
    } else if (!entry.isDirectory && isTextPreview(entry.name)) {
      try {
        final file = File(entry.path).openSync();
        try {
          final bytes = file.readSync(64 * 1024);
          _text = String.fromCharCodes(bytes);
        } finally {
          file.closeSync();
        }
      } on FileSystemException {
        _text = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _load();
    final entry = widget.entry;
    final image = _imageSize;
    final kind = image != null
        ? 'image'
        : _text != null
        ? 'text'
        : 'generic';
    final natural = switch (kind) {
      'image' => imagePanelSize(image!),
      'text' => quickPreviewText,
      _ => quickPreviewGeneric,
    };
    return LayoutBuilder(
      builder: (context, room) {
        final size = fitPanel(
          natural,
          Size(room.maxWidth - 40, room.maxHeight - 40),
        );
        return Center(
          child: Container(
            key: const ValueKey('quick preview'),
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x33000000), width: 0.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 40,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _bar(entry),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      quickPreviewFrame,
                      0,
                      quickPreviewFrame,
                      quickPreviewFrame,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: switch (kind) {
                        'image' => ColoredBox(
                          color: const Color(0xFFFFFFFF),
                          child: Image.file(
                            File(entry.path),
                            fit: BoxFit.contain,
                          ),
                        ),
                        'text' => ColoredBox(
                          color: const Color(0xFFFFFFFF),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _text!,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: Color(0xFF1A1A1A),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ),
                        _ => _generic(entry),
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bar(Entry entry) {
    final position = widget.position;
    return SizedBox(
      height: quickPreviewBar,
      child: Row(
        children: [
          const SizedBox(width: 12),
          GestureDetector(
            key: const ValueKey('close quick preview'),
            onTap: widget.onClose,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Color(0xFFB0B0B5),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                '×',
                style: TextStyle(
                  fontFamily: uiFontFamily,
                  package: 'silica_ui',
                  fontSize: 11,
                  height: 1,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              position == null
                  ? entry.name
                  : l10n.positionOf(entry.name, position.$1, position.$2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: uiFontFamily,
                package: 'silica_ui',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3C3C3C),
              ),
            ),
          ),
          if (widget.openWith != null)
            GestureDetector(
              key: const ValueKey('open with from quick preview'),
              onTap: widget.onOpenWith,
              child: Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x14000000),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.openWithApp(widget.openWith!),
                  style: const TextStyle(
                    fontFamily: uiFontFamily,
                    package: 'silica_ui',
                    fontSize: 12,
                    color: Color(0xFF3C3C3C),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _generic(Entry entry) {
    var count = '';
    if (entry.isDirectory) {
      try {
        final n = Directory(entry.path).listSync().length;
        count = l10n.itemCount(n);
      } on FileSystemException {
        count = '';
      }
    }
    final when = longDate(entry.modified);
    return ColoredBox(
      color: const Color(0xFFFFFFFF),
      child: Row(
        children: [
          const SizedBox(width: 36),
          EntryIcon(entry: entry, side: 128, env: widget.env),
          const SizedBox(width: 28),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: uiFontFamily,
                    package: 'silica_ui',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (!entry.isDirectory) formatSize(entry),
                    if (count.isNotEmpty) count,
                  ].join(', '),
                  style: const TextStyle(
                    fontFamily: uiFontFamily,
                    package: 'silica_ui',
                    fontSize: 13,
                    color: Color(0xFF6E6E73),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.lastModified(when),
                  style: const TextStyle(
                    fontFamily: uiFontFamily,
                    package: 'silica_ui',
                    fontSize: 13,
                    color: Color(0xFF6E6E73),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }
}
