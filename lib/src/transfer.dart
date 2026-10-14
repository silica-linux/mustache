// Background copies and moves (MU-41, MU-43, mustache-spec 9.2): in chunks, with progress in bytes,
// cancellation that leaves nothing in the destination (R9.6) and name conflicts asked to the user
// (Keep Both → "name 2.ext", Replace, Stop; R9.7). A move on the same disk is a rename; across
// disks it is a copy followed by deletion. The modification date stays the original's (R9.8).

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'model.dart';
import 'operations.dart';

enum TransferKind { copy, move }

enum TransferState { running, done, cancelled, failed }

/// What to do when an item with the same name is already in the destination.
enum ConflictChoice { keepBoth, replace, stop }

/// The result of an item: from where to where.
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

  /// Bytes per chunk read and written.
  final int chunk;

  TransferState state = TransferState.running;
  String? error;
  int totalBytes = 0;
  int doneBytes = 0;

  /// The current item (name) and the paths created in the destination, finished or not.
  String? currentName;
  final List<String> targets = [];

  /// The completed items.
  final List<TransferMove> completed = [];

  bool _cancelled = false;
  final DateTime started = DateTime.now();

  double get fraction =>
      totalBytes == 0 ? 0 : (doneBytes / totalBytes).clamp(0, 1);

  /// Is the path an item (or inside an item) still being copied?
  bool isPending(String path) =>
      state == TransferState.running &&
      targets.any((t) => path == t || path.startsWith('$t/')) &&
      !completed.any((c) => c.$2 == path);

  /// Cancel: stops at the next chunk and removes from the destination what it created.
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
        // Pasting into the same folder: the copy gets "name copia".
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
        // Nothing of the copy stays in the destination (R9.6); what was moved entirely stays moved.
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
      // A half-written chunk does not stay.
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
      // Another disk (EXDEV) or a permission: copy.
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
      // The same permissions (an executable stays executable).
      final mode = FileStat.statSync(from).mode & 0x1ff;
      Process.runSync('chmod', [mode.toRadixString(8), to]);
    } on ProcessException {
      // Without chmod the default permissions stay.
    }
  }

  void _keepTimes(String from, String to) {
    try {
      final modified = FileStat.statSync(from).modified;
      if (FileSystemEntity.isFileSync(to))
        File(to).setLastModifiedSync(modified);
    } on FileSystemException {
      // The date is not essential.
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
      // Unreadable: counts as zero, the error will come while copying.
    }
    return 0;
  }
}

/// Moved items: undo puts them back where they were.
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

/// The file clipboard of this process (⌘C): the copied paths.
class FileClipboard {
  FileClipboard._();
  static List<String> paths = const [];
}
