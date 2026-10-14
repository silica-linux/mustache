// La finestra in modalità dialogo (Apri e Salva per il portale, mustache-spec 14): in alto per
// Salva il campo del nome, in basso Annulla e il pulsante d'accettazione (in accento,
// disattivato senza una scelta valida). Doppio clic su un file e Invio accettano; Esc annulla.

part of 'window.dart';

/// I colori del dialogo; in scuro da mu95-open-dark e mu95-save-compact-dark (pulsante
/// `#373737` con il testo `#e0e0e0`, il primario disattivato `#2f2f30` / `#626263`, campo
/// `#191919` con il bordo `#313131`, linea `#3c3c3d`).
@immutable
class DialogColors {
  const DialogColors({
    required this.label,
    required this.field,
    required this.fieldBorder,
    required this.button,
    required this.buttonText,
    required this.primary,
    required this.primaryDisabled,
    required this.primaryDisabledText,
    required this.line,
  });

  final Color label;
  final Color? field;
  final Color fieldBorder;
  final Color button;
  final Color buttonText;
  final Color primary;
  final Color primaryDisabled;
  final Color primaryDisabledText;
  final Color line;

  static const DialogColors light = DialogColors(
    label: textColor,
    field: null,
    fieldBorder: Color(0xFFC8C8C8),
    button: Color(0xFFE8E8E8),
    buttonText: Color(0xFF242424),
    primary: Color(0xFF0064E1),
    primaryDisabled: Color(0x660064E1),
    primaryDisabledText: Color(0xFFFFFFFF),
    line: Color(0xFFE6E6E6),
  );

  static const DialogColors dark = DialogColors(
    label: Color(0xFF9E9E9E),
    field: Color(0xFF191919),
    fieldBorder: Color(0xFF313131),
    button: Color(0xFF373737),
    buttonText: Color(0xFFE0E0E0),
    primary: Color(0xFF007AFF),
    primaryDisabled: Color(0xFF2F2F30),
    primaryDisabledText: Color(0xFF626263),
    line: Color(0xFF3C3C3D),
  );

  static DialogColors of(BuildContext context) =>
      MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark
      ? dark
      : light;
}

extension _Dialog on _MustacheWindowState {
  DialogOptions get _dialogOptions => widget.dialog!;

  /// Gli elementi che il dialogo restituirebbe adesso.
  List<String> get _dialogChoice {
    final d = _dialogOptions;
    if (d.save) {
      final name = _saveName.text.trim();
      if (name.isEmpty || name.contains('/')) return const [];
      return ['${_history.current}/$name'];
    }
    final chosen = [
      for (final e in _selection)
        if (d.directory == e.isDirectory) e.path,
    ];
    // Per le cartelle, senza scelta vale quella aperta.
    if (chosen.isEmpty && d.directory) return [_history.current];
    return d.multiple ? chosen : chosen.take(1).toList();
  }

  void _finish(List<String> paths) =>
      (widget.onDialogFinish ?? finishDialog)(paths);

  void _acceptDialog() {
    final paths = _dialogChoice;
    if (paths.isEmpty) return;
    if (_dialogOptions.save && entryAt(paths.single) != null) {
      // Un file con lo stesso nome: si chiede prima di sostituirlo.
      _update(
        () => _alert = SilicaAlert(
          opaque: true,
          icon: _appIcon,
          title: 'Vuoi sostituire «${displayName(paths.single)}»?',
          message: 'Esiste già un elemento con questo nome in questa cartella.',
          sideBySide: true,
          buttons: [
            AlertButton(
              'Annulla',
              role: AlertRole.cancel,
              onPressed: _closeAlert,
            ),
            AlertButton(
              'Sostituisci',
              role: AlertRole.destructive,
              onPressed: () {
                _closeAlert();
                _finish(paths);
              },
            ),
          ],
        ),
      );
      return;
    }
    _finish(paths);
  }

  /// La riga del nome per Salva.
  Widget _saveBar() => _saveBarWith(DialogColors.of(context));

  Widget _saveBarWith(DialogColors colors) => SizedBox(
    key: const ValueKey('riga del nome'),
    height: 44,
    child: Row(
      children: [
        const SizedBox(width: 16),
        SizedBox(
          width: 110,
          child: Text(
            'Salva con nome:',
            textAlign: TextAlign.right,
            style: text(13, color: colors.label),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 232,
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: colors.field,
            border: Border.all(color: colors.fieldBorder),
            borderRadius: BorderRadius.circular(5),
          ),
          child: DefaultTextEditingShortcuts(
            child: EditableText(
              key: const ValueKey('campo del nome del dialogo'),
              controller: _saveName,
              focusNode: _saveFocus,
              style: text(13, color: WindowColors.of(context).text),
              cursorColor: WindowColors.of(context).text,
              backgroundCursorColor: WindowColors.of(context).text,
              selectionColor: const Color(0xFFB3D7FF),
              selectAllOnFocus: false,
              maxLines: 1,
              onChanged: (_) => _update(() {}),
              onSubmitted: (_) => _acceptDialog(),
            ),
          ),
        ),
      ],
    ),
  );

  /// In basso: Annulla e il pulsante d'accettazione (81 × 26).
  Widget _dialogButtons() {
    final enabled = _dialogChoice.isNotEmpty;
    final colors = DialogColors.of(context);
    Widget button(String label, {required bool primary, VoidCallback? onTap}) =>
        GestureDetector(
          key: ValueKey('dialogo $label'),
          onTap: onTap,
          child: Container(
            width: 81,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary
                  ? (onTap == null ? colors.primaryDisabled : colors.primary)
                  : colors.button,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: text(
                13,
                color: !primary
                    ? colors.buttonText
                    : onTap == null
                    ? colors.primaryDisabledText
                    : const Color(0xFFFFFFFF),
              ),
            ),
          ),
        );
    return Container(
      key: const ValueKey('pulsanti del dialogo'),
      height: 52,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          button('Annulla', primary: false, onTap: () => _finish(const [])),
          const SizedBox(width: 12),
          button(
            _dialogOptions.acceptLabel,
            primary: true,
            onTap: enabled ? _acceptDialog : null,
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
