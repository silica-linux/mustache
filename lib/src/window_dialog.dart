// La finestra in modalità dialogo (Apri e Salva per il portale, mustache-spec 14): in alto per
// Salva il campo del nome, in basso Annulla e il pulsante d'accettazione (in accento,
// disattivato senza una scelta valida). Doppio clic su un file e Invio accettano; Esc annulla.

part of 'window.dart';

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
  Widget _saveBar() => SizedBox(
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
            style: text(13),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 232,
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFC8C8C8)),
            borderRadius: BorderRadius.circular(5),
          ),
          child: DefaultTextEditingShortcuts(
            child: EditableText(
              key: const ValueKey('campo del nome del dialogo'),
              controller: _saveName,
              focusNode: _saveFocus,
              style: text(13),
              cursorColor: textColor,
              backgroundCursorColor: textColor,
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
                  ? (onTap == null
                        ? const Color(0x660064E1)
                        : const Color(0xFF0064E1))
                  : const Color(0xFFE8E8E8),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: text(
                13,
                color: primary
                    ? const Color(0xFFFFFFFF)
                    : const Color(0xFF242424),
              ),
            ),
          ),
        );
    return Container(
      key: const ValueKey('pulsanti del dialogo'),
      height: 52,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE6E6E6))),
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
