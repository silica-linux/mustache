// The Share item of the toolbar (silica-desktop#217, mustache#21): the system share service
// (silica_ui `SilicaShare`) lists where the selection can go and sends it there. The item is
// enabled only when the service has targets for the selection.

part of 'window.dart';

extension _Share on _MustacheWindowState {
  List<Uri> _shareUris() => [for (final e in _selection) Uri.file(e.path)];

  /// Whether the Share item of the toolbar can send the current selection (nothing selected, or
  /// no targets: it is disabled). The service is asked again when the selection changes.
  bool _shareEnabled() {
    final files = _shareUris();
    final key = files.join('\n');
    if (key != _shareFor) {
      _shareFor = key;
      _shareable = false;
      if (files.isNotEmpty) unawaited(_loadShareTargets(key, files));
    }
    return _shareable;
  }

  Future<void> _loadShareTargets(String key, List<Uri> files) async {
    final targets = await SilicaShare.targets(files);
    if (!mounted || key != _shareFor || targets.isEmpty) return;
    // ignore: invalid_use_of_protected_member
    setState(() => _shareable = true);
  }

  /// Opens the Share menu below `anchor` (the button) with the selected items.
  Future<void> _openShareMenu(Rect anchor) async {
    final files = _shareUris();
    final host = _bodyKey.currentContext;
    if (files.isEmpty || host == null) return;
    await showSilicaShareMenu(
      context: host,
      position: anchor.bottomLeft + const Offset(0, 4),
      files: files,
      copyLabel: l10n.shareCopy,
    );
    if (mounted) _focus.requestFocus();
  }
}
