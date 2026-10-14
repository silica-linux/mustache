// The Open and Save dialogs (MU-95, mustache-spec 14) for the Silica portal (`silica-portal`,
// org.freedesktop.impl.portal.FileChooser): Mustache starts with `--dialog=open|save` and the other
// arguments, and writes the choice to stdout, one `file://` URI per line; cancelling exits with
// code 1 without writing anything.

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'l10n.dart';

/// What the dialog asks for.
@immutable
class DialogOptions {
  const DialogOptions({
    required this.save,
    this.title = '',
    this.accept,
    this.multiple = false,
    this.directory = false,
    this.name = '',
    this.folder,
  });

  /// Save (true) or Open.
  final bool save;
  final String title;

  /// The button label (null: Open / Save).
  final String? accept;
  final bool multiple;

  /// Folders are chosen (Open).
  final bool directory;

  /// The proposed name (Save).
  final String name;

  /// The starting folder.
  final String? folder;

  String get acceptLabel => accept ?? (save ? l10n.save : l10n.open);

  /// From the process arguments; null if it is not a dialog.
  static DialogOptions? parse(List<String> args) {
    String? value(String key) {
      for (final a in args) {
        if (a.startsWith('--$key=')) return a.substring(key.length + 3);
      }
      return null;
    }

    final kind = value('dialog');
    if (kind != 'open' && kind != 'save') return null;
    final folder = value('folder');
    return DialogOptions(
      save: kind == 'save',
      title: value('title') ?? '',
      accept: value('accept'),
      multiple: args.contains('--multiple'),
      directory: args.contains('--directory'),
      name: value('name') ?? '',
      folder: folder != null && Directory(folder).existsSync() ? folder : null,
    );
  }
}

/// The `file://` URI of a path (every segment encoded).
String fileUri(String path) => Uri.file(path).toString();

/// Writes the choice and exits: code 0 with the URIs, 1 if cancelled (no URI).
void finishDialog(
  List<String> paths, {
  void Function(int code)? exitFor,
  IOSink? out,
}) {
  final sink = out ?? stdout;
  for (final p in paths) {
    sink.writeln(fileUri(p));
  }
  (exitFor ?? exit)(paths.isEmpty ? 1 : 0);
}
