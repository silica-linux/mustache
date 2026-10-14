// The Mustache settings kept between launches, in `$XDG_CONFIG_HOME/mustache/settings.json`. A
// missing or unreadable file, or odd values, count as the default settings: never an error.

import 'dart:convert';
import 'dart:io';

class Settings {
  Settings(this.path) {
    try {
      final data = jsonDecode(File(path).readAsStringSync());
      if (data is Map<String, Object?>) _data.addAll(data);
    } on Object {
      // Missing or damaged: start again from the defaults.
    }
  }

  /// The file in the user's configuration directory.
  factory Settings.forUser(Map<String, String> env) {
    final home = env['HOME'] ?? '/';
    final config = env['XDG_CONFIG_HOME'];
    final base = config == null || config.isEmpty ? '$home/.config' : config;
    return Settings('$base/mustache/settings.json');
  }

  final String path;
  final Map<String, Object?> _data = {};

  /// The sidebar width of new windows (MU-11: the last one set).
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

  /// The last chosen view (`icons`, `list`), for new windows.
  String? get view {
    final value = _data['view'];
    return value is String ? value : null;
  }

  set view(String? value) {
    _data['view'] = value;
    _save();
  }

  /// The path bar is visible (⌥⌘P), for new windows.
  bool? get pathBar {
    final value = _data['pathBar'];
    return value is bool ? value : null;
  }

  set pathBar(bool? value) {
    _data['pathBar'] = value;
    _save();
  }

  /// The open sections of the Get Info window (shared by all, R11.1).
  List<String>? get infoSections {
    final value = _data['infoSections'];
    return value is List
        ? [
            for (final v in value)
              if (v is String) v,
          ]
        : null;
  }

  set infoSections(List<String>? value) {
    _data['infoSections'] = value;
    _save();
  }

  bool? _bool(String key) {
    final v = _data[key];
    return v is bool ? v : null;
  }

  /// The status bar (⌘') and the preview pane (⇧⌘P) visible.
  bool? get statusBar => _bool('statusBar');
  set statusBar(bool? value) {
    _data['statusBar'] = value;
    _save();
  }

  bool? get previewPane => _bool('previewPane');
  set previewPane(bool? value) {
    _data['previewPane'] = value;
    _save();
  }

  /// The icon size of the icon view.
  double? get iconSide {
    final v = _data['iconSide'];
    return v is num && v >= 16 && v <= 512 ? v.toDouble() : null;
  }

  set iconSide(double? value) {
    _data['iconSide'] = value;
    _save();
  }

  void _save() {
    try {
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(_data));
    } on FileSystemException {
      // Without write permission the setting lasts only for this session.
    }
  }
}
