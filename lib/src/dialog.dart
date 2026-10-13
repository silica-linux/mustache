// I dialoghi Apri e Salva (MU-95, mustache-spec 14) per il portale di Silica
// (`silica-portal`, org.freedesktop.impl.portal.FileChooser): Mustache parte con
// `--dialog=open|save` e gli altri argomenti, e scrive la scelta sullo stdout, un URI
// `file://` per riga; annullare esce con codice 1 senza scrivere niente.

import 'dart:io';

import 'package:flutter/foundation.dart';

/// Che cosa chiede il dialogo.
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

  /// Salva (true) o Apri.
  final bool save;
  final String title;

  /// L'etichetta del pulsante (null: Apri / Salva).
  final String? accept;
  final bool multiple;

  /// Si scelgono cartelle (Apri).
  final bool directory;

  /// Il nome proposto (Salva).
  final String name;

  /// La cartella di partenza.
  final String? folder;

  String get acceptLabel => accept ?? (save ? 'Salva' : 'Apri');

  /// Dagli argomenti del processo; null se non è un dialogo.
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

/// L'URI `file://` di un percorso (ogni segmento codificato).
String fileUri(String path) => Uri.file(path).toString();

/// Scrive la scelta e chiude: codice 0 con gli URI, 1 se annullato (nessun URI).
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
