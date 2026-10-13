// La visualizzazione rapida (Spazio, MU-61, mustache-spec 12): un pannello centrato con la
// barra superiore di 38 pt (×, nome, "Apri con <app>") e una cornice di 5 pt attorno al
// contenuto. Le dimensioni seguono il contenuto: un'immagine alla sua grandezza naturale più
// 10 × 43 (larga almeno ~370, alta al più 1256), il testo 816 × 849, il resto (cartelle, codice,
// archivi, file senza anteprima) 575 × 328 con l'icona grande, il nome e i dati.
//
// In Silica il pannello vive dentro la finestra (l'embedder non ha ancora finestre figlie): si
// riduce per starci.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'icon_view.dart' show EntryIcon, hasThumbnail;
import 'model.dart';

const double quickLookBar = 38;
const double quickLookFrame = 5;
const double quickLookMaxHeight = 1256;
const double quickLookMinWidth = 370;
const Size quickLookGeneric = Size(575, 328);
const Size quickLookText = Size(816, 849);

/// Le estensioni mostrate come testo.
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

/// La dimensione del pannello per un'immagine di `natural` pt (spec 12).
Size imagePanelSize(Size natural) {
  var w = natural.width + 2 * quickLookFrame;
  var h = natural.height + quickLookBar + quickLookFrame;
  if (h > quickLookMaxHeight) {
    // Adattata all'altezza massima, in proporzione.
    final scale =
        (quickLookMaxHeight - quickLookBar - quickLookFrame) / natural.height;
    w = natural.width * scale + 2 * quickLookFrame;
    h = quickLookMaxHeight;
  }
  return Size(math.max(w, quickLookMinWidth), h);
}

/// Riduce il pannello perché stia in `room` (la finestra), in proporzione.
Size fitPanel(Size panel, Size room) {
  final scale = math.min(
    1.0,
    math.min(room.width / panel.width, room.height / panel.height),
  );
  return Size(panel.width * scale, panel.height * scale);
}

class QuickLookPanel extends StatefulWidget {
  const QuickLookPanel({
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

  /// Il nome dell'app predefinita, per la capsula "Apri con …".
  final String? openWith;
  final VoidCallback? onOpenWith;

  /// "N di M" quando la selezione ha più elementi.
  final (int, int)? position;
  final Map<String, String>? env;

  @override
  State<QuickLookPanel> createState() => _QuickLookPanelState();
}

class _QuickLookPanelState extends State<QuickLookPanel> {
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
      'text' => quickLookText,
      _ => quickLookGeneric,
    };
    return LayoutBuilder(
      builder: (context, room) {
        final size = fitPanel(
          natural,
          Size(room.maxWidth - 40, room.maxHeight - 40),
        );
        return Center(
          child: Container(
            key: const ValueKey('visualizzazione rapida'),
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
                      quickLookFrame,
                      0,
                      quickLookFrame,
                      quickLookFrame,
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
      height: quickLookBar,
      child: Row(
        children: [
          const SizedBox(width: 12),
          GestureDetector(
            key: const ValueKey('chiudi la visualizzazione rapida'),
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
                  : '${entry.name}  (${position.$1} di ${position.$2})',
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
              key: const ValueKey('apri con dalla visualizzazione rapida'),
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
                  'Apri con ${widget.openWith}',
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
        count = n == 1 ? '1 elemento' : '$n elementi';
      } on FileSystemException {
        count = '';
      }
    }
    final date = entry.modified;
    String two(int v) => v.toString().padLeft(2, '0');
    final when =
        '${date.day} ${_months[date.month - 1]} ${date.year}, ${two(date.hour)}:${two(date.minute)}';
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
                  'Ultima modifica: $when',
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

const List<String> _months = [
  'gennaio',
  'febbraio',
  'marzo',
  'aprile',
  'maggio',
  'giugno',
  'luglio',
  'agosto',
  'settembre',
  'ottobre',
  'novembre',
  'dicembre',
];
