// The in-place rename field (MU-32, docs/spec/rename.md): as wide as the text (grows and shrinks while
// typing), 21 tall with the 3 pt focus ring, 1 pt inner border, 13 pt text 4 pt from the edge. On
// opening the name without the extension is selected (R8.1); Return confirms, Esc cancels, losing
// focus (a click elsewhere) confirms.

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
          // Estimated: the content background in dark.
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

/// The part selected on opening: the name without the extension (everything for folders and names
/// without an extension).
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
      // A click elsewhere: confirms, like Return.
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
        key: const ValueKey('rename field'),
        width: width,
        height: renameHeight,
        decoration: BoxDecoration(
          color: colors.fill,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(3),
          boxShadow: [
            // The focus ring: 3 pt around the border.
            BoxShadow(color: colors.ring, spreadRadius: renameRing - 1),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: renameTextInset),
        alignment: Alignment.centerLeft,
        // Text editing shortcuts (delete, arrows, ⌘A): the window is not inside a WidgetsApp that
        // provides them.
        child: DefaultTextEditingShortcuts(
          child: EditableText(
            controller: _controller,
            focusNode: _focus,
            style: style,
            cursorColor: colors.text,
            backgroundCursorColor: colors.text,
            selectionColor: colors.selection,
            maxLines: 1,
            // On desktop the field would select everything on focus: here the name without the
            // extension stays selected (R8.1).
            selectAllOnFocus: false,
            // Return and Esc are handled by the surrounding Focus.
            onSubmitted: (_) => _commit(),
          ),
        ),
      ),
    );
  }
}
