// Il pannello di anteprima (⇧⌘P, MU-05, mustache-spec 1.6): a destra dei contenuti, largo 264,
// fondo `#ececec` senza linea di separazione; anteprima 244 × 320 a 10 pt di margine, nome in
// semibold, "Tipo - dimensione", e le Informazioni in righe da 23 pt con linee di 1 pt.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'icon_view.dart' show EntryIcon, hasThumbnail;
import 'info.dart' show StatDetails;
import 'model.dart';
import 'quick_look.dart' show isTextPreview;

const double previewPaneWidth = 264;
const Size previewBox = Size(244, 320);

TextStyle _text(
  double size, {
  FontWeight? weight,
  Color color = const Color(0xFF1A1A1A),
}) => TextStyle(
  fontFamily: uiFontFamily,
  package: 'silica_ui',
  fontSize: size,
  fontWeight: weight,
  color: color,
);

String _when(DateTime? t) {
  if (t == null) return '--';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year}, ${two(t.hour)}:${two(t.minute)}';
}

class PreviewPane extends StatelessWidget {
  const PreviewPane({
    super.key,
    required this.items,
    required this.kindOf,
    this.env,
  });

  /// La selezione (vuota: niente).
  final List<Entry> items;
  final String Function(Entry entry) kindOf;
  final Map<String, String>? env;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('pannello di anteprima'),
      width: previewPaneWidth,
      color: const Color(0xFFECECEC),
      child: items.isEmpty
          ? null
          : items.length > 1
          ? _many()
          : _one(items.single),
    );
  }

  Widget _many() {
    final total = items.fold<int>(
      0,
      (sum, e) => sum + (e.isDirectory ? 0 : e.size),
    );
    return Column(
      children: [
        const SizedBox(height: 10),
        SizedBox.fromSize(
          size: previewBox,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Un ventaglio di icone ruotate.
              for (var i = 0; i < items.length && i < 3; i++)
                Transform.rotate(
                  angle: (i - 1) * 0.12,
                  child: EntryIcon(entry: items[i], side: 128, env: env),
                ),
            ],
          ),
        ),
        Text(
          '${items.length} elementi',
          style: _text(15, weight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          '${items.length} documenti - ${formatSize(Entry(name: '', path: '', isDirectory: false, size: total, modified: DateTime(0)))}',
          style: _text(12, color: const Color(0xFF6E6E73)),
        ),
      ],
    );
  }

  /// `stat` per percorso e data: non a ogni disegno.
  static final Map<String, StatDetails> _stats = {};

  Widget _one(Entry entry) {
    final key = '${entry.path}\u0000${entry.modified.microsecondsSinceEpoch}';
    if (_stats.length > 500) _stats.clear();
    final stat = _stats[key] ??= StatDetails.of(entry.path);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox.fromSize(size: previewBox, child: _preview(entry)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _text(15, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.isDirectory
                      ? kindOf(entry)
                      : '${kindOf(entry)} - ${formatSize(entry)}',
                  style: _text(12, color: const Color(0xFF6E6E73)),
                ),
                const SizedBox(height: 14),
                Text('Informazioni', style: _text(13, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                _row('Creato', _when(stat.created)),
                _row('Modificato', _when(entry.modified)),
                if (!entry.isDirectory) _row('Dimensioni', formatSize(entry)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Container(
    height: 23,
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFFD5D5D5))),
    ),
    child: Row(
      children: [
        Text(label, style: _text(12, color: const Color(0xFF6E6E73))),
        const Spacer(),
        Text(value, style: _text(12)),
      ],
    ),
  );

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
