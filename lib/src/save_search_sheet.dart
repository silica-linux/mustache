// The Save Search sheet (kit `Apps/Mustache/Save Search Sheet`, 413 × 263): a title and a
// message, the name (232 × 28), the tags, the folder pop-up, "Add to Sidebar", Cancel and Save.
// Labels are right-aligned to x 136, the controls start at x 142. The kit's round button that
// expands the folder list is not drawn: the pop-up lists the folders it can save to.

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';

const Size saveSearchSize = Size(413, 263);

/// What the sheet hands back.
typedef SaveSearchResult = ({
  String name,
  List<String> tags,
  String folder,
  bool addToSidebar,
});

class SaveSearchSheet extends StatefulWidget {
  const SaveSearchSheet({
    super.key,
    required this.initialName,
    required this.folders,
    required this.onSave,
    required this.onCancel,
  });

  final String initialName;

  /// The folders the search can be kept in: label and path, the first is the default.
  final List<(String, String)> folders;
  final ValueChanged<SaveSearchResult> onSave;
  final VoidCallback onCancel;

  @override
  State<SaveSearchSheet> createState() => _SaveSearchSheetState();
}

class _SaveSearchSheetState extends State<SaveSearchSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  final TextEditingController _tags = TextEditingController();
  late String _folder = widget.folders.first.$2;
  bool _sidebar = true;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _tags.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty;

  void _save() {
    if (!_valid) return;
    widget.onSave((
      name: _name.text.trim(),
      tags: [
        for (final t in _tags.text.split(','))
          if (t.trim().isNotEmpty) t.trim(),
      ],
      folder: _folder,
      addToSidebar: _sidebar,
    ));
  }

  Widget _label(String text, double top) {
    final colors = AmalfiTheme.of(context).colors;
    return Positioned(
      left: 24,
      top: top,
      width: 112,
      height: 18,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: AmalfiType.body(color: colors.textPrimary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    return SizedBox.fromSize(
      size: saveSearchSize,
      child: AmalfiAlertSurface(
        radius: AmalfiSheetMetrics.radius,
        child: Stack(
          children: [
            Positioned(
              left: 24,
              top: 20,
              height: 22,
              child: Text(
                l10n.saveSearchTitle,
                style: AmalfiType.headline(color: colors.textPrimary),
              ),
            ),
            Positioned(
              left: 24,
              top: 44,
              height: 16,
              child: Text(
                l10n.saveSearchMessage,
                style: AmalfiType.caption(color: colors.textSecondary),
              ),
            ),
            _label(l10n.saveSearchName, 81),
            _label(l10n.saveSearchTags, 117),
            _label(l10n.saveSearchWhere, 153),
            Positioned(
              left: 142,
              top: 76,
              child: AmalfiTextField(
                key: const ValueKey('save search name'),
                controller: _name,
                width: 232,
                autofocus: true,
                semanticLabel: l10n.saveSearchName,
                onSubmitted: (_) => _save(),
              ),
            ),
            Positioned(
              left: 142,
              top: 112,
              child: AmalfiTextField(
                key: const ValueKey('save search tags'),
                controller: _tags,
                width: 232,
                placeholder: l10n.saveSearchAddTags,
                semanticLabel: l10n.saveSearchTags,
                onSubmitted: (_) => _save(),
              ),
            ),
            Positioned(
              left: 142,
              top: 148,
              child: AmalfiPopUpButton<String>(
                key: const ValueKey('save search where'),
                width: 232,
                semanticLabel: l10n.saveSearchWhere,
                items: [
                  for (final (label, path) in widget.folders)
                    AmalfiPopUpItem(value: path, label: label),
                ],
                value: _folder,
                onChanged: (path) => setState(() => _folder = path),
              ),
            ),
            Positioned(
              left: 142,
              top: 190,
              child: AmalfiCheckbox(
                key: const ValueKey('save search sidebar'),
                value: _sidebar,
                label: l10n.saveSearchAddToSidebar,
                onChanged: (v) => setState(() => _sidebar = v),
              ),
            ),
            Positioned(
              left: 219,
              top: 219,
              width: 72,
              child: AmalfiPushButton(
                key: const ValueKey('save search cancel'),
                label: l10n.cancel,
                onPressed: widget.onCancel,
              ),
            ),
            Positioned(
              left: 308,
              top: 219,
              width: 72,
              child: AmalfiPushButton(
                key: const ValueKey('save search save'),
                label: l10n.save,
                variant: AmalfiPushButtonVariant.primary,
                onPressed: _valid ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
