// Copie e spostamenti in background (MU-41, MU-43, mustache-spec 9.2): a pezzi, con
// l'avanzamento in byte, l'annullamento che non lascia niente nella destinazione (R9.6) e i
// conflitti di nome chiesti a chi guarda (Mantieni entrambi → "nome 2.ext", Sostituisci,
// Interrompi; R9.7). Lo spostamento sullo stesso disco è un rename; fra dischi diversi è una copia
// seguita dalla cancellazione. La data di modifica resta quella dell'originale (R9.8).

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'model.dart';
import 'operations.dart';

enum TransferKind { copy, move }

enum TransferState { running, done, cancelled, failed }

/// Che fare quando nella destinazione c'è già un elemento con lo stesso nome.
enum ConflictChoice { keepBoth, replace, stop }

/// Il risultato di un elemento: da dove a dove.
typedef TransferMove = (String from, String to);

class Transfer extends ChangeNotifier {
  Transfer({
    required this.kind,
    required this.sources,
    required this.destination,
    this.chunk = 1 << 20,
  });

  final TransferKind kind;
  final List<String> sources;
  final String destination;

  /// Byte per pezzo letto e scritto.
  final int chunk;

  TransferState state = TransferState.running;
  String? error;
  int totalBytes = 0;
  int doneBytes = 0;

  /// L'elemento in corso (nome) e i percorsi creati nella destinazione, finiti o no.
  String? currentName;
  final List<String> targets = [];

  /// Gli elementi completati.
  final List<TransferMove> completed = [];

  bool _cancelled = false;
  final DateTime started = DateTime.now();

  double get fraction =>
      totalBytes == 0 ? 0 : (doneBytes / totalBytes).clamp(0, 1);

  /// Il percorso è un elemento (o dentro un elemento) ancora in copia?
  bool isPending(String path) =>
      state == TransferState.running &&
      targets.any((t) => path == t || path.startsWith('$t/')) &&
      !completed.any((c) => c.$2 == path);

  /// Annulla: si ferma al prossimo pezzo e toglie dalla destinazione quel che ha creato.
  void cancel() => _cancelled = true;

  Future<void> run({
    required Future<ConflictChoice> Function(String name) onConflict,
  }) async {
    try {
      totalBytes = sources.fold(0, (sum, s) => sum + _sizeOf(s));
      notifyListeners();
      for (final source in sources) {
        if (_cancelled) break;
        final name = displayName(source);
        var target = '$destination/$name';
        // Incollare nella stessa cartella: la copia prende "nome copia".
        if (target == source) {
          if (kind == TransferKind.move) continue;
          target =
              '$destination/${copyName(destination, name, isDirectory: FileSystemEntity.isDirectorySync(source))}';
        } else if (FileSystemEntity.typeSync(target, followLinks: false) !=
            FileSystemEntityType.notFound) {
          switch (await onConflict(name)) {
            case ConflictChoice.stop:
              _cancelled = true;
              continue;
            case ConflictChoice.replace:
              final error = deletePermanently(target).error;
              if (error != null) throw FileSystemException(error, target);
            case ConflictChoice.keepBoth:
              final (base, ext) = splitExtension(
                name,
                isDirectory: FileSystemEntity.isDirectorySync(source),
              );
              target = '$destination/${uniqueName(destination, base, ext)}';
          }
        }
        if (source == destination || destination.startsWith('$source/')) {
          throw FileSystemException(
            'Non si può mettere una cartella dentro se stessa.',
            source,
          );
        }
        currentName = displayName(target);
        targets.add(target);
        notifyListeners();
        if (kind == TransferKind.move && _rename(source, target)) {
          doneBytes += _sizeOf(target);
        } else {
          await _copy(source, target);
          if (_cancelled) break;
          if (kind == TransferKind.move) {
            final error = deletePermanently(source).error;
            if (error != null) throw FileSystemException(error, source);
          }
        }
        completed.add((source, target));
        notifyListeners();
      }
      if (_cancelled) {
        // Nella destinazione non resta nulla della copia (R9.6); quel che è stato spostato
        // per intero resta spostato.
        for (final target in targets) {
          if (kind == TransferKind.copy ||
              !completed.any((c) => c.$2 == target)) {
            deletePermanently(target);
          }
        }
        if (kind == TransferKind.copy) completed.clear();
        state = TransferState.cancelled;
      } else {
        state = TransferState.done;
      }
    } on FileSystemException catch (e) {
      // Il pezzo a metà non resta.
      final last = targets.lastOrNull;
      if (last != null && !completed.any((c) => c.$2 == last)) {
        deletePermanently(last);
      }
      error = e.osError?.message ?? e.message;
      state = TransferState.failed;
    }
    currentName = null;
    notifyListeners();
  }

  bool _rename(String from, String to) {
    try {
      switch (FileSystemEntity.typeSync(from, followLinks: false)) {
        case FileSystemEntityType.directory:
          Directory(from).renameSync(to);
        case FileSystemEntityType.link:
          Link(from).renameSync(to);
        default:
          File(from).renameSync(to);
      }
      return true;
    } on FileSystemException {
      // Un altro disco (EXDEV) o un permesso: si copia.
      return false;
    }
  }

  Future<void> _copy(String from, String to) async {
    switch (FileSystemEntity.typeSync(from, followLinks: false)) {
      case FileSystemEntityType.link:
        Link(to).createSync(Link(from).targetSync());
      case FileSystemEntityType.directory:
        Directory(to).createSync();
        for (final child in Directory(from).listSync(followLinks: false)) {
          if (_cancelled) return;
          await _copy(child.path, '$to/${displayName(child.path)}');
        }
        _keepTimes(from, to);
      default:
        await _copyFile(from, to);
    }
  }

  Future<void> _copyFile(String from, String to) async {
    final input = await File(from).open();
    final output = await File(to).open(mode: FileMode.writeOnly);
    try {
      final buffer = Uint8List(chunk);
      while (!_cancelled) {
        final read = await input.readInto(buffer);
        if (read <= 0) break;
        await output.writeFrom(buffer, 0, read);
        doneBytes += read;
        notifyListeners();
      }
    } finally {
      await input.close();
      await output.close();
    }
    if (_cancelled) return;
    _keepTimes(from, to);
    try {
      // Gli stessi permessi (l'eseguibile resta eseguibile).
      final mode = FileStat.statSync(from).mode & 0x1ff;
      Process.runSync('chmod', [mode.toRadixString(8), to]);
    } on ProcessException {
      // Senza chmod restano i permessi predefiniti.
    }
  }

  void _keepTimes(String from, String to) {
    try {
      final modified = FileStat.statSync(from).modified;
      if (FileSystemEntity.isFileSync(to))
        File(to).setLastModifiedSync(modified);
    } on FileSystemException {
      // La data non è essenziale.
    }
  }

  static int _sizeOf(String path) {
    try {
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        var total = 0;
        for (final e in Directory(
          path,
        ).listSync(recursive: true, followLinks: false)) {
          if (e is File) total += e.lengthSync();
        }
        return total;
      }
      if (type == FileSystemEntityType.file) return File(path).lengthSync();
    } on FileSystemException {
      // Illeggibile: conta zero, l'errore arriverà copiando.
    }
    return 0;
  }
}

/// Elementi spostati: annullare li rimette dov'erano.
class MoveOp extends Undoable {
  MoveOp(this.moves);
  final List<TransferMove> moves;

  @override
  String get label => 'Sposta';

  @override
  String? undo(Trash trash) {
    for (final (from, to) in moves.reversed) {
      final error = _moveBack(to, from);
      if (error != null) return error;
    }
    return null;
  }

  static String? _moveBack(String from, String to) {
    if (FileSystemEntity.typeSync(to, followLinks: false) !=
        FileSystemEntityType.notFound) {
      return 'C\'è già un elemento chiamato «${displayName(to)}».';
    }
    try {
      switch (FileSystemEntity.typeSync(from, followLinks: false)) {
        case FileSystemEntityType.directory:
          Directory(from).renameSync(to);
        case FileSystemEntityType.link:
          Link(from).renameSync(to);
        case FileSystemEntityType.notFound:
          return 'L\'elemento non esiste più.';
        default:
          File(from).renameSync(to);
      }
      return null;
    } on FileSystemException catch (e) {
      return e.osError?.message ?? e.message;
    }
  }

  @override
  String? redo(Trash trash) {
    for (final (from, to) in moves) {
      final error = _moveBack(from, to);
      if (error != null) return error;
    }
    return null;
  }
}

/// Gli appunti dei file di questo processo (⌘C): i percorsi copiati.
class FileClipboard {
  FileClipboard._();
  static List<String> paths = const [];
}
