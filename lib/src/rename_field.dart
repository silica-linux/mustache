// Il campo della rinomina sul posto (MU-32, mustache-spec 8): largo quanto il testo (cresce e si
// stringe scrivendo), alto 21 con l'anello di focus di 3 pt, bordo interno di 1 pt, testo 13 a
// 4 pt dal bordo. All'apertura è selezionato il nome senza estensione (R8.1); Invio conferma,
// Esc annulla, perdere il focus (un clic altrove) conferma.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'operations.dart';

const double renameHeight = 21;
const double renameRing = 3;
const double renameTextInset = 4;
const double renameTextSize = 13;

@immutable
class RenameColors {
  const RenameColors({
    required this.ring,
    required this.border,
    required this.fill,
    required this.text,
    required this.selection,
  });

  final Color ring;
  final Color border;
  final Color fill;
  final Color text;
  final Color selection;

  static RenameColors of({required bool dark}) => dark
      ? const RenameColors(
          ring: Color(0xFF296692),
          border: Color(0xFF3586C5),
          // Stimato: il fondo del contenuto in scuro.
          fill: Color(0xFF272728),
          text: Color(0xFFFFFFFF),
          selection: Color(0xFF40638B),
        )
      : const RenameColors(
          ring: Color(0xFF8FB4FB),
          border: Color(0xFF649EFA),
          fill: Color(0xFFFFFFFF),
          text: Color(0xFF000000),
          selection: Color(0xFFB3D7FF),
        );
}

/// La parte selezionata all'apertura: il nome senza estensione (tutto per cartelle e nomi senza
/// estensione).
TextSelection initialRenameSelection(String name, {bool isDirectory = false}) {
  final (base, _) = splitExtension(name, isDirectory: isDirectory);
  return TextSelection(baseOffset: 0, extentOffset: base.length);
}

class RenameField extends StatefulWidget {
  const RenameField({
    super.key,
    required this.name,
    required this.onCommit,
    required this.onCancel,
    this.isDirectory = false,
    this.maxWidth = 400,
  });

  final String name;
  final bool isDirectory;
  final ValueChanged<String> onCommit;
  final VoidCallback onCancel;
  final double maxWidth;

  @override
  State<RenameField> createState() => _RenameFieldState();
}

class _RenameFieldState extends State<RenameField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.name)
        ..selection = initialRenameSelection(
          widget.name,
          isDirectory: widget.isDirectory,
        );
  final FocusNode _focus = FocusNode();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _focus.addListener(() {
      // Un clic altrove: conferma, come Invio.
      if (!_focus.hasFocus) _commit();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    if (_done) return;
    _done = true;
    widget.onCommit(_controller.text);
  }

  void _cancel() {
    if (_done) return;
    _done = true;
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final dark =
        MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark;
    final colors = RenameColors.of(dark: dark);
    final style = TextStyle(
      fontFamily: uiFontFamily,
      package: 'silica_ui',
      fontSize: renameTextSize,
      color: colors.text,
    );
    final painter = TextPainter(
      text: TextSpan(text: _controller.text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final textWidth = painter.width;
    painter.dispose();
    final width = (textWidth + 2 * (renameTextInset + renameRing) + 2).clamp(
      30.0,
      widget.maxWidth,
    );
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          _cancel();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          _commit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        key: const ValueKey('campo di rinomina'),
        width: width,
        height: renameHeight,
        decoration: BoxDecoration(
          color: colors.fill,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(3),
          boxShadow: [
            // L'anello di focus: 3 pt attorno al bordo.
            BoxShadow(color: colors.ring, spreadRadius: renameRing - 1),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: renameTextInset),
        alignment: Alignment.centerLeft,
        // Le scorciatoie di modifica del testo (cancella, frecce, ⌘A): la finestra non è dentro
        // un WidgetsApp che le dà.
        child: DefaultTextEditingShortcuts(
          child: EditableText(
            controller: _controller,
            focusNode: _focus,
            style: style,
            cursorColor: colors.text,
            backgroundCursorColor: colors.text,
            selectionColor: colors.selection,
            maxLines: 1,
            // Su desktop il campo selezionerebbe tutto al focus: qui resta il nome senza
            // estensione (R8.1).
            selectAllOnFocus: false,
            // Invio e Esc li gestisce il Focus attorno.
            onSubmitted: (_) => _commit(),
          ),
        ),
      ),
    );
  }
}
