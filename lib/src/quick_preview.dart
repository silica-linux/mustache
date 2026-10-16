// Quick preview (Space, MU-61, docs/spec/quick-look.md for the behaviour; kit `Apps/Mustache/Quick
// Preview`): a centered window panel with a 40 pt top bar (close, name, the open-with button) and a
// 1 pt separator below it. The size follows the content: an image at its natural size plus the bar
// (at least ~370 wide, at most 1256 tall), text 816 × 849, the rest (folders, code, archives,
// files without a preview) 576 × 328 with the large icon, the name and the details.
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

/// The top bar: 40 tall and its separator.
const double quickPreviewBar = 41;
const double quickPreviewFrame = 0;
const double quickPreviewMaxHeight = 1256;
const double quickPreviewMinWidth = 370;
const Size quickPreviewGeneric = Size(576, 328);
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

/// The panel size for an image of `natural` pt (spec/quick-look.md).
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

  /// The name of the default app, for the open-with button.
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
    final colors = AmalfiTheme.of(context).colors;
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
          child: SizedBox(
            key: const ValueKey('quick preview'),
            width: size.width,
            height: size.height,
            child: AmalfiWindow(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _bar(entry, colors),
                  Expanded(
                    child: switch (kind) {
                      'image' => Image.file(
                        File(entry.path),
                        fit: BoxFit.contain,
                      ),
                      'text' => SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _text!,
                          style: AmalfiType.mono(color: colors.textPrimary),
                        ),
                      ),
                      _ => _generic(entry, colors),
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The top bar (kit `Quick Preview`): 40 tall on the sidebar surface with a 1 pt separator
  /// below, the close control on the left and the name in Body Emphasis. The kit's minimise and
  /// zoom controls do nothing for a preview and are left out.
  Widget _bar(Entry entry, AmalfiColors colors) {
    final position = widget.position;
    return SizedBox(
      height: quickPreviewBar,
      child: ColoredBox(
        color: colors.surfaceSidebar,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 1,
              child: ColoredBox(color: colors.lineSeparator),
            ),
            Row(
              children: [
                const SizedBox(width: 12),
                GestureDetector(
                  key: const ValueKey('close quick preview'),
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: const AmalfiWindowDot(
                    kind: AmalfiWindowControlKind.close,
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
                    style: AmalfiType.bodyEmphasis(color: colors.textPrimary),
                  ),
                ),
                if (widget.openWith != null)
                  KeyedSubtree(
                    key: const ValueKey('open with from quick preview'),
                    child: AmalfiPushButton(
                      label: l10n.openWithApp(widget.openWith!),
                      size: AmalfiControlSize.small,
                      onPressed: widget.onOpenWith,
                    ),
                  ),
                const SizedBox(width: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _generic(Entry entry, AmalfiColors colors) {
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
    // Kit `Quick Preview`: the icon 160 pt at (40, 84) of the 576 × 328 panel (43 under the bar),
    // the title at x 232, y 120 (79 under the bar).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 40),
        Padding(
          padding: const EdgeInsets.only(top: 43),
          child: EntryIcon(entry: entry, side: 160, env: widget.env),
        ),
        const SizedBox(width: 32),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 79),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AmalfiType.title2(color: colors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (!entry.isDirectory) formatSize(entry),
                    if (count.isNotEmpty) count,
                  ].join(', '),
                  style: AmalfiType.callout(color: colors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.lastModified(when),
                  style: AmalfiType.callout(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
      ],
    );
  }
}
