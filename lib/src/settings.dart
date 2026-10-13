// Le impostazioni di Mustache che restano fra un avvio e l'altro, in
// `$XDG_CONFIG_HOME/mustache/settings.json`. Un file che manca, non si legge o ha valori strani
// vale come impostazioni predefinite: mai un errore.

import 'dart:convert';
import 'dart:io';

class Settings {
  Settings(this.path) {
    try {
      final data = jsonDecode(File(path).readAsStringSync());
      if (data is Map<String, Object?>) _data.addAll(data);
    } on Object {
      // Manca o è rovinato: si riparte dalle predefinite.
    }
  }

  /// Il file nella cartella di configurazione dell'utente.
  factory Settings.forUser(Map<String, String> env) {
    final home = env['HOME'] ?? '/';
    final config = env['XDG_CONFIG_HOME'];
    final base = config == null || config.isEmpty ? '$home/.config' : config;
    return Settings('$base/mustache/settings.json');
  }

  final String path;
  final Map<String, Object?> _data = {};

  /// La larghezza della barra laterale delle finestre nuove (MU-11: l'ultima impostata).
  double? get sidebarWidth {
    final value = _data['sidebarWidth'];
    return value is num && value.isFinite && value > 0
        ? value.toDouble()
        : null;
  }

  set sidebarWidth(double? value) {
    _data['sidebarWidth'] = value;
    _save();
  }

  /// L'ultima vista scelta (`icons`, `list`), per le finestre nuove.
  String? get view {
    final value = _data['view'];
    return value is String ? value : null;
  }

  set view(String? value) {
    _data['view'] = value;
    _save();
  }

  /// La barra del percorso è visibile (⌥⌘P), per le finestre nuove.
  bool? get pathBar {
    final value = _data['pathBar'];
    return value is bool ? value : null;
  }

  set pathBar(bool? value) {
    _data['pathBar'] = value;
    _save();
  }

  void _save() {
    try {
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(_data));
    } on FileSystemException {
      // Senza permessi di scrittura l'impostazione vale solo per questa sessione.
    }
  }
}
