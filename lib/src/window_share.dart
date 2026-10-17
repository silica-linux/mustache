// The Share button of the preview toolbar (silica-desktop#217): the system share service
// (silica_ui `SilicaShare`) lists where the selection can go and sends it there. The button is
// drawn only when the service has targets for the selection.

part of 'window.dart';

extension _Share on _MustacheWindowState {
  List<Uri> _shareUris() => [for (final e in _selection) Uri.file(e.path)];

  /// The Share piece for the current selection, or null (nothing selected, or no targets). The
  /// service is asked again when the selection changes.
  Widget? _shareButton() {
    final files = _shareUris();
    final key = files.join('\n');
    if (key != _shareFor) {
      _shareFor = key;
      _shareable = false;
      if (files.isNotEmpty) unawaited(_loadShareTargets(key, files));
    }
    if (!_shareable) return null;
    return AmalfiToolbarPiece(
      key: const ValueKey('share piece'),
      child: AmalfiToolbarButton(
        key: _shareKey,
        icon: AmalfiGlyph(AmalfiGlyphs.share),
        onPressed: _openShareMenu,
        semanticLabel: l10n.shareLabel,
      ),
    );
  }

  Future<void> _loadShareTargets(String key, List<Uri> files) async {
    final targets = await SilicaShare.targets(files);
    if (!mounted || key != _shareFor || targets.isEmpty) return;
    // ignore: invalid_use_of_protected_member
    setState(() => _shareable = true);
  }

  /// Opens the Share menu below the button with the selected items.
  Future<void> _openShareMenu() async {
    final box = _shareKey.currentContext?.findRenderObject();
    final files = _shareUris();
    final host = _bodyKey.currentContext;
    if (box is! RenderBox || !box.attached || files.isEmpty || host == null) {
      return;
    }
    await showSilicaShareMenu(
      context: host,
      position: box.localToGlobal(Offset(0, box.size.height + 4)),
      files: files,
      copyLabel: l10n.shareCopy,
    );
    if (mounted) _focus.requestFocus();
  }
}
