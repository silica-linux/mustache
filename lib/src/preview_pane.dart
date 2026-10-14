// Il pannello di anteprima (⇧⌘P, MU-05, mustache-spec 1.6) e quello della galleria (MU-23,
// spec 6): a destra dei contenuti, largo 264 (250 in galleria), fondo `#ececec` senza linea di
// separazione.
//
// In cima, nel pannello: l'anteprima 244 × 320 a 10 pt di margine, poi il nome in semibold e
// "Tipo - dimensione". In galleria (`compact`) l'anteprima grande è già a sinistra: in cima c'è
// l'icona di 50 con accanto nome e "Tipo - dimensione" (mu23-gallery-folder-light).
//
// Poi, uguali (misurati su mu23-gallery-folder-light, y dalla cima del pannello): Informazioni
// in grassetto 13 (linea di base 100), righe da 23 pt con etichetta 11 `#858787` a sinistra e
// valore 11 `#353537` a destra, linee di 1 pt `#d5d5d5` sotto (130, 153); Tag in grassetto (base
// 180) e il campo "Aggiungi un tag…" bianco alto 33 da y 190; in fondo la barra delle azioni,
// bianca, alta 70.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:silica_ui/silica_ui.dart';

import 'icon_view.dart' show EntryIcon, hasThumbnail;
import 'info.dart' show StatDetails;
import 'model.dart';
import 'quick_look.dart' show isTextPreview;

const double previewPaneWidth = 264;
const Size previewBox = Size(244, 320);
const double paneActionsHeight = 70;
const double paneRow = 23;
const double paneTagField = 33;
const double paneCompactIcon = 50;

const Color paneFill = Color(0xFFECECEC);
const Color paneLine = Color(0xFFD5D5D5);
const Color paneName = Color(0xFF474747);
const Color paneKind = Color(0xFFB8B8B9);
const Color paneLabel = Color(0xFF858787);
const Color paneValue = Color(0xFF353537);
const Color paneHeading = Color(0xFF1A1A1A);
const Color panePlaceholder = Color(0xFFB4B4B4);

TextStyle _text(double size, {FontWeight? weight, Color color = paneHeading}) =>
    TextStyle(
      fontFamily: uiFontFamily,
      package: 'silica_ui',
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1,
    );

/// Un testo con la linea di base a `baseline` dalla cima del suo riquadro.
Widget _onBaseline(Widget text, double baseline) => Baseline(
  baseline: baseline,
  baselineType: TextBaseline.alphabetic,
  child: text,
);

/// Un'azione della barra in fondo: un simbolo e un'etichetta sotto; riceve il punto del clic
/// (per aprire un menu lì).
class PaneAction {
  const PaneAction(this.label, this.symbol, this.onPressed);
  final String label;
  final String symbol;
  final ValueChanged<Offset> onPressed;
}

class PreviewPane extends StatelessWidget {
  const PreviewPane({
    super.key,
    required this.items,
    required this.kindOf,
    this.env,
    this.width = previewPaneWidth,
    this.compact = false,
    this.now,
    this.tagsOf,
    this.onAddTag,
    this.actions = const [],
    this.iconsDir,
  });

  /// Largo 264, 250 in galleria.
  final double width;

  /// In galleria: in cima l'icona di 50 con nome e tipo accanto, niente anteprima.
  final bool compact;

  /// La selezione (vuota: niente).
  final List<Entry> items;
  final String Function(Entry entry) kindOf;
  final Map<String, String>? env;

  /// Per "oggi" e "ieri" nelle date (i test fissano l'ora).
  final DateTime? now;

  /// Le etichette di un elemento e l'aggiunta di una dal campo.
  final List<String> Function(Entry entry)? tagsOf;
  final void Function(Entry entry, String tag)? onAddTag;

  /// I pulsanti della barra in fondo (vuota: niente barra).
  final List<PaneAction> actions;

  /// La cartella di silica-icons, per i simboli delle azioni.
  final String? iconsDir;

  @override
  Widget build(BuildContext context) {
    final content = items.isEmpty
        ? const SizedBox.expand()
        : items.length > 1
        ? _many()
        : _one(items.single);
    return Container(
      key: const ValueKey('pannello di anteprima'),
      width: width,
      color: paneFill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: content),
          if (items.isNotEmpty && actions.isNotEmpty) _actionsBar(),
        ],
      ),
    );
  }

  Widget _many() {
    final total = items.fold<int>(
      0,
      (sum, e) => sum + (e.isDirectory ? 0 : e.size),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact)
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox.fromSize(
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
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(10, compact ? 18 : 0, 10, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${items.length} elementi',
                style: _text(15, weight: FontWeight.w600, color: paneName),
              ),
              const SizedBox(height: 6),
              Text(
                '${items.length} documenti - ${formatSize(Entry(name: '', path: '', isDirectory: false, size: total, modified: DateTime(0)))}',
                style: _text(12, color: paneKind),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// `stat` per percorso e data: non a ogni disegno.
  static final Map<String, StatDetails> _stats = {};

  String _when(DateTime? t) =>
      t == null ? '--' : formatDate(t, now ?? DateTime.now());

  Widget _one(Entry entry) {
    final key = '${entry.path}\u0000${entry.modified.microsecondsSinceEpoch}';
    if (_stats.length > 500) _stats.clear();
    final stat = _stats[key] ??= StatDetails.of(entry.path);
    final kind = entry.isDirectory
        ? kindOf(entry)
        : '${kindOf(entry)} - ${formatSize(entry)}';
    final name = Text(
      entry.name,
      maxLines: compact ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: _text(15, weight: FontWeight.w600, color: paneName),
    );
    final subtitle = Text(
      kind,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _text(12, color: paneKind),
    );
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact)
            // Icona 50 a (8, 18); nome con la base a 39 e tipo con la base a 58, da x 69.
            SizedBox(
              height: 76,
              child: Stack(
                children: [
                  Positioned(
                    left: 8,
                    top: 18,
                    width: paneCompactIcon,
                    height: paneCompactIcon,
                    child: EntryIcon(
                      entry: entry,
                      side: paneCompactIcon,
                      env: env,
                    ),
                  ),
                  Positioned(
                    left: 69,
                    right: 10,
                    top: 0,
                    child: _onBaseline(name, 39),
                  ),
                  Positioned(
                    left: 69,
                    right: 10,
                    top: 0,
                    child: _onBaseline(subtitle, 58),
                  ),
                ],
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.all(10),
              child: SizedBox.fromSize(
                size: previewBox,
                child: _preview(entry),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [name, const SizedBox(height: 6), subtitle],
              ),
            ),
            const SizedBox(height: 4),
          ],
          // Informazioni: la base a 100 in galleria (24 sotto la cima di questa sezione).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 31,
                  child: _onBaseline(
                    Text(
                      'Informazioni',
                      style: _text(13, weight: FontWeight.w700),
                    ),
                    24,
                  ),
                ),
                _row('Creato', _when(stat.created)),
                _row(
                  'Modificato',
                  _when(entry.modified),
                  last: !hasThumbnail(entry.name),
                ),
                if (hasThumbnail(entry.name))
                  _row('Dimensioni', formatSize(entry), last: true),
                if (tagsOf != null) ...[
                  SizedBox(
                    height: 37,
                    child: _onBaseline(
                      Text('Tag', style: _text(13, weight: FontWeight.w700)),
                      27,
                    ),
                  ),
                  _TagField(
                    key: ValueKey('campo dei tag ${entry.path}'),
                    tags: tagsOf!(entry),
                    onAdd: (tag) => onAddTag?.call(entry, tag),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Una riga da 23: etichetta a sinistra, valore a destra, base a 15; una linea di 1 pt la
  /// separa dalla riga dopo (sotto l'ultima niente, mu23-gallery-folder).
  Widget _row(String label, String value, {bool last = false}) => Container(
    height: paneRow,
    decoration: BoxDecoration(
      border: last ? null : const Border(bottom: BorderSide(color: paneLine)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _onBaseline(Text(label, style: _text(11, color: paneLabel)), 15),
        const SizedBox(width: 8),
        Expanded(
          child: _onBaseline(
            // Larga quanto la riga: il valore sta sul bordo destro.
            SizedBox(
              width: double.infinity,
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _text(11, weight: FontWeight.w600, color: paneValue),
              ),
            ),
            15,
          ),
        ),
      ],
    ),
  );

  Widget _actionsBar() => Container(
    key: const ValueKey('azioni del pannello'),
    height: paneActionsHeight,
    color: const Color(0xFFFFFFFF),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final action in actions)
          GestureDetector(
            key: ValueKey('azione ${action.label}'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => action.onPressed(d.globalPosition),
            child: SizedBox(
              width: 74,
              height: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _symbol(action.symbol),
                  const SizedBox(height: 6),
                  Text(
                    action.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: _text(11, color: const Color(0xFF6E6E6E)),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _symbol(String name) {
    final dir = iconsDir;
    final file = dir == null ? null : File('$dir/symbols/regular/$name.svg');
    if (file == null || !file.existsSync()) {
      return const SizedBox(width: 18, height: 18);
    }
    return SvgPicture.file(
      file,
      width: 18,
      height: 18,
      colorFilter: const ColorFilter.mode(Color(0xFF6E6E6E), BlendMode.srcIn),
    );
  }

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

/// Il campo dei tag: bianco, alto 33; mostra le etichette dell'elemento, Invio ne aggiunge una.
class _TagField extends StatefulWidget {
  const _TagField({super.key, required this.tags, required this.onAdd});
  final List<String> tags;
  final ValueChanged<String> onAdd;

  @override
  State<_TagField> createState() => _TagFieldState();
}

class _TagFieldState extends State<_TagField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final tag = value.trim();
    if (tag.isEmpty) return;
    widget.onAdd(tag);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.tags.join(', ');
    final placeholder = existing.isEmpty ? 'Aggiungi un tag…' : existing;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focus.requestFocus,
      child: Container(
        height: paneTagField,
        color: const Color(0xFFFFFFFF),
        // Il testo in alto a sinistra (mu23-gallery-folder: base a ~12 dalla cima del campo).
        padding: const EdgeInsets.fromLTRB(4, 3, 4, 0),
        alignment: Alignment.topLeft,
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            if (_controller.text.isEmpty)
              IgnorePointer(
                child: Text(
                  placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(
                    12,
                    color: existing.isEmpty ? panePlaceholder : paneValue,
                  ),
                ),
              ),
            DefaultTextEditingShortcuts(
              child: EditableText(
                controller: _controller,
                focusNode: _focus,
                style: _text(12, color: paneValue),
                cursorColor: paneValue,
                backgroundCursorColor: paneValue,
                selectionColor: const Color(0xFFB3D7FF),
                maxLines: 1,
                onSubmitted: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
