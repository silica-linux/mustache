// The file operations of MU.4 (docs/spec/rename.md, operations.md): new folder, duplicate, rename, Trash
// (freedesktop Trash specification), put back, delete, and the undo stack.
//
// Never exceptions towards the UI: every operation returns the result or a message (a vanished
// file, a missing permission, a full disk are normal cases).

import 'dart:io';

import 'l10n.dart';
import 'model.dart';

/// The name of a new folder (⇧⌘N), in the user's language.
String get newFolderName => l10n.newFolderName;

/// The result of an operation: the path produced, or an error to show.
typedef OpResult = ({String? path, String? error});

OpResult _ok(String path) => (path: path, error: null);
OpResult _fail(String message) => (path: null, error: message);

/// Name and extension ("appunti", ".txt"); folders and names starting with a dot have no extension.
(String, String) splitExtension(String name, {bool isDirectory = false}) {
  if (isDirectory) return (name, '');
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return (name, '');
  return (name.substring(0, dot), name.substring(dot));
}

/// A free name in `dir`: `base` + `ext`, then `base 2` + `ext`, `base 3`…
String uniqueName(String dir, String base, [String ext = '']) {
  bool taken(String name) =>
      FileSystemEntity.typeSync('$dir/$name', followLinks: false) !=
      FileSystemEntityType.notFound;
  var name = '$base$ext';
  for (var n = 2; taken(name); n++) {
    name = '$base $n$ext';
  }
  return name;
}

/// The name of the copy (⌘D): "name copy.ext", then "name copy 2.ext"; folders "Alfa copy" (in
/// Italian "nome copia.ext").
String copyName(String dir, String name, {bool isDirectory = false}) {
  final (base, ext) = splitExtension(name, isDirectory: isDirectory);
  return uniqueName(dir, l10n.copySuffix(base), ext);
}

/// Make Link (⌃⌘A): a symbolic link to `path` next to it, named "name link.ext".
OpResult makeLink(String path) {
  final type = FileSystemEntity.typeSync(path, followLinks: false);
  if (type == FileSystemEntityType.notFound) return _fail(l10n.errorGone);
  final dir = parentOf(path) ?? '/';
  final (base, ext) = splitExtension(
    displayName(path),
    isDirectory: type == FileSystemEntityType.directory,
  );
  final target = '$dir/${uniqueName(dir, l10n.linkSuffix(base), ext)}';
  try {
    Link(target).createSync(path);
    return _ok(target);
  } on FileSystemException catch (e) {
    return _fail(_describe(e));
  }
}

/// Creates the new folder name (or "… 2") in `dir`.
OpResult createFolder(String dir) {
  final path = '$dir/${uniqueName(dir, newFolderName)}';
  try {
    Directory(path).createSync();
    return _ok(path);
  } on FileSystemException catch (e) {
    return _fail(_describe(e));
  }
}

/// Duplicates a file or a folder (recursively; links stay links).
OpResult duplicate(String path) {
  final type = FileSystemEntity.typeSync(path, followLinks: false);
  if (type == FileSystemEntityType.notFound) {
    return _fail(l10n.errorGone);
  }
  final dir = parentOf(path) ?? '/';
  final target =
      '$dir/${copyName(dir, displayName(path), isDirectory: type == FileSystemEntityType.directory)}';
  try {
    _copy(path, target);
    return _ok(target);
  } on FileSystemException catch (e) {
    // A half-made copy does not stay.
    _deleteQuietly(target);
    return _fail(_describe(e));
  }
}

void _copy(String from, String to) {
  switch (FileSystemEntity.typeSync(from, followLinks: false)) {
    case FileSystemEntityType.link:
      Link(to).createSync(Link(from).targetSync());
    case FileSystemEntityType.directory:
      Directory(to).createSync();
      for (final child in Directory(from).listSync(followLinks: false)) {
        _copy(child.path, '$to/${displayName(child.path)}');
      }
    default:
      File(from).copySync(to);
  }
}

void _deleteQuietly(String path) {
  try {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      Directory(path).deleteSync(recursive: true);
    } else if (type != FileSystemEntityType.notFound) {
      File(path).deleteSync();
    }
  } on FileSystemException {
    // It stays: better one extra file than an error on top of an error.
  }
}

/// Deletes right away, without the Trash (⌥⌘⌫ after confirmation).
OpResult deletePermanently(String path) {
  try {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return _ok(path);
    if (type == FileSystemEntityType.directory) {
      Directory(path).deleteSync(recursive: true);
    } else {
      File(path).deleteSync();
    }
    return _ok(path);
  } on FileSystemException catch (e) {
    return _fail(_describe(e));
  }
}

/// Why a new name is not valid: empty, `.` or `..`, with `/` (it cannot be in a name on Linux), or
/// already used in the same folder. Null if valid.
String? invalidName(String dir, String oldName, String newName) {
  if (newName.trim().isEmpty || newName == '.' || newName == '..') {
    return l10n.errorNameInvalid(newName);
  }
  if (newName.contains('/') || newName.contains('\u0000')) {
    return l10n.errorNameSlash(newName);
  }
  if (newName != oldName &&
      FileSystemEntity.typeSync('$dir/$newName', followLinks: false) !=
          FileSystemEntityType.notFound &&
      // Only a case change on the same file: allowed.
      newName.toLowerCase() != oldName.toLowerCase()) {
    return l10n.errorNameTaken(newName);
  }
  return null;
}

/// Does renaming a file change its extension (R8.4: confirmation is asked)?
bool extensionChanges(
  String oldName,
  String newName, {
  bool isDirectory = false,
}) {
  if (isDirectory) return false;
  final (_, a) = splitExtension(oldName);
  final (_, b) = splitExtension(newName);
  return a.isNotEmpty && a != b;
}

/// Renames within the same folder.
OpResult renameEntry(String path, String newName) {
  final dir = parentOf(path) ?? '/';
  final problem = invalidName(dir, displayName(path), newName);
  if (problem != null) return _fail(problem);
  final target = '$dir/$newName';
  if (target == path) return _ok(path);
  try {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    switch (type) {
      case FileSystemEntityType.notFound:
        return _fail(l10n.errorGone);
      case FileSystemEntityType.directory:
        Directory(path).renameSync(target);
      case FileSystemEntityType.link:
        Link(path).renameSync(target);
      default:
        File(path).renameSync(target);
    }
    return _ok(target);
  } on FileSystemException catch (e) {
    return _fail(_describe(e));
  }
}

/// The user's Trash (freedesktop Trash specification): `files/` and `info/`.
class Trash {
  Trash(this.root);

  /// `$XDG_DATA_HOME/Trash`.
  factory Trash.forUser(Map<String, String> env) {
    final home = env['HOME'] ?? '/';
    final data = env['XDG_DATA_HOME'];
    return Trash(
      '${data == null || data.isEmpty ? '$home/.local/share' : data}/Trash',
    );
  }

  final String root;
  String get files => '$root/files';
  String get info => '$root/info';

  /// Is the path inside the Trash?
  bool contains(String path) => path == files || path.startsWith('$files/');

  /// Deletes everything in the Trash for good (R9.12); the error of the first item that could
  /// not go, if any (the others are still deleted).
  String? empty() {
    String? error;
    for (final dir in [files, info]) {
      try {
        for (final item in Directory(dir).listSync(followLinks: false)) {
          error ??= deletePermanently(item.path).error;
        }
      } on FileSystemException {
        // No such folder: nothing to delete.
      }
    }
    return error;
  }

  /// Deletes for good what has been in the Trash longer than [age] (Settings › Advanced): the
  /// items whose `.trashinfo` says they were deleted before `now − age`; those with no readable
  /// date stay. Returns how many went.
  int purgeOlderThan(Duration age, {DateTime? now}) {
    final limit = (now ?? DateTime.now()).subtract(age);
    var removed = 0;
    try {
      for (final item in Directory(info).listSync(followLinks: false)) {
        if (item is! File || !item.path.endsWith('.trashinfo')) continue;
        final DateTime? deleted;
        try {
          deleted = _deletionDate(item.readAsStringSync());
        } on FileSystemException {
          continue;
        }
        if (deleted == null || !deleted.isBefore(limit)) continue;
        final name = displayName(
          item.path,
        ).replaceFirst(RegExp(r'\.trashinfo$'), '');
        final target = '$files/$name';
        if (FileSystemEntity.typeSync(target, followLinks: false) !=
                FileSystemEntityType.notFound &&
            deletePermanently(target).error != null) {
          continue;
        }
        deletePermanently(item.path);
        removed++;
      }
    } on FileSystemException {
      // No Trash: nothing to clean.
    }
    return removed;
  }

  static DateTime? _deletionDate(String text) {
    for (final line in text.split('\n')) {
      if (line.startsWith('DeletionDate=')) {
        return DateTime.tryParse(line.substring('DeletionDate='.length).trim());
      }
    }
    return null;
  }

  /// Moves to the Trash; the result is the path inside `files/`.
  OpResult put(String path, {DateTime? now}) {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      return _fail(l10n.errorGone);
    }
    try {
      Directory(files).createSync(recursive: true);
      Directory(info).createSync(recursive: true);
      // A name free both in files/ and info/ (the specification: the .trashinfo file is created
      // first, exclusively).
      final (base, ext) = splitExtension(
        displayName(path),
        isDirectory: type == FileSystemEntityType.directory,
      );
      late String name;
      late File infoFile;
      for (var n = 1; ; n++) {
        name = n == 1 ? '$base$ext' : '$base.$n$ext';
        infoFile = File('$info/$name.trashinfo');
        if (FileSystemEntity.typeSync('$files/$name', followLinks: false) !=
            FileSystemEntityType.notFound) {
          continue;
        }
        try {
          infoFile.createSync(exclusive: true);
          break;
        } on FileSystemException {
          continue;
        }
      }
      infoFile.writeAsStringSync(
        '[Trash Info]\nPath=${_encodePath(path)}\n'
        'DeletionDate=${_isoSeconds(now ?? DateTime.now())}\n',
      );
      final target = '$files/$name';
      try {
        _move(path, target, type);
      } on FileSystemException catch (e) {
        _deleteQuietly(infoFile.path);
        return _fail(_describe(e));
      }
      return _ok(target);
    } on FileSystemException catch (e) {
      return _fail(_describe(e));
    }
  }

  /// The original location of a Trash item (from its .trashinfo).
  String? originOf(String trashed) {
    try {
      final text = File(
        '$info/${displayName(trashed)}.trashinfo',
      ).readAsStringSync();
      for (final line in text.split('\n')) {
        if (line.startsWith('Path=')) {
          return Uri.decodeComponent(line.substring(5).trim());
        }
      }
    } on FileSystemException {
      // Without info it is unknown where to go back.
    } on ArgumentError {
      // Badly encoded path.
    }
    return null;
  }

  /// Puts a Trash item back where it was (R9.10).
  OpResult restore(String trashed) {
    final origin = originOf(trashed);
    if (origin == null) {
      return _fail(l10n.errorUnknownOrigin(displayName(trashed)));
    }
    if (FileSystemEntity.typeSync(origin, followLinks: false) !=
        FileSystemEntityType.notFound) {
      return _fail(l10n.errorOriginTaken(displayName(origin)));
    }
    try {
      Directory(parentOf(origin) ?? '/').createSync(recursive: true);
      _move(
        trashed,
        origin,
        FileSystemEntity.typeSync(trashed, followLinks: false),
      );
      _deleteQuietly('$info/${displayName(trashed)}.trashinfo');
      return _ok(origin);
    } on FileSystemException catch (e) {
      return _fail(_describe(e));
    }
  }

  static String _encodePath(String path) =>
      path.split('/').map(Uri.encodeComponent).join('/');

  static String _isoSeconds(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}'
        'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

/// Moves; across disks (rename impossible) it copies and then deletes.
void _move(String from, String to, FileSystemEntityType type) {
  try {
    switch (type) {
      case FileSystemEntityType.directory:
        Directory(from).renameSync(to);
      case FileSystemEntityType.link:
        Link(from).renameSync(to);
      default:
        File(from).renameSync(to);
    }
  } on FileSystemException catch (e) {
    // EXDEV: another file system.
    if (e.osError?.errorCode != 18) rethrow;
    _copy(from, to);
    _deleteQuietly(from);
  }
}

String _describe(FileSystemException e) {
  final code = e.osError?.errorCode;
  return switch (code) {
    13 || 1 => l10n.errorPermission,
    28 => l10n.errorDiskFull,
    2 => l10n.errorGone,
    30 => l10n.errorReadOnly,
    _ => e.osError?.message ?? e.message,
  };
}

/// An operation that can be undone and redone.
abstract class Undoable {
  const Undoable();

  /// The label of the Edit menu ("Undo Rename").
  String get label;

  /// Undo; an error if no longer possible.
  String? undo(Trash trash);

  /// Redo; an error if no longer possible.
  String? redo(Trash trash);
}

class RenameOp extends Undoable {
  RenameOp(this.from, this.to);
  String from;
  String to;

  @override
  String get label => l10n.rename;

  @override
  String? undo(Trash trash) => renameEntry(to, displayName(from)).error;

  @override
  String? redo(Trash trash) => renameEntry(from, displayName(to)).error;
}

/// Created items (new folder, duplicates): undo deletes them (not to the Trash).
class CreateOp extends Undoable {
  CreateOp(this.paths, this.label, this._recreate);
  final List<String> paths;

  @override
  final String label;
  final OpResult Function(String path) _recreate;

  @override
  String? undo(Trash trash) {
    for (final path in paths) {
      final error = deletePermanently(path).error;
      if (error != null) return error;
    }
    return null;
  }

  @override
  String? redo(Trash trash) {
    for (final path in paths) {
      final error = _recreate(path).error;
      if (error != null) return error;
    }
    return null;
  }
}

/// Items moved to the Trash: undo puts them back where they were.
class TrashOp extends Undoable {
  TrashOp(this.moves);

  /// (source, path in the Trash).
  final List<(String, String)> moves;

  @override
  String get label => l10n.opMove;

  @override
  String? undo(Trash trash) {
    for (final (_, trashed) in moves) {
      final error = trash.restore(trashed).error;
      if (error != null) return error;
    }
    return null;
  }

  @override
  String? redo(Trash trash) {
    for (var i = 0; i < moves.length; i++) {
      final (origin, _) = moves[i];
      final result = trash.put(origin);
      if (result.error != null) return result.error;
      moves[i] = (origin, result.path!);
    }
    return null;
  }
}

/// The undo/redo stack of the window.
class UndoStack {
  final List<Undoable> _done = [];
  final List<Undoable> _undone = [];

  void push(Undoable op) {
    _done.add(op);
    _undone.clear();
  }

  String? get undoLabel =>
      _done.isEmpty ? null : l10n.undoAction(_done.last.label);
  String? get redoLabel =>
      _undone.isEmpty ? null : l10n.redoAction(_undone.last.label);

  /// Undoes the last operation; null if it succeeded or there was nothing.
  String? undo(Trash trash) {
    if (_done.isEmpty) return null;
    final op = _done.removeLast();
    final error = op.undo(trash);
    if (error == null) _undone.add(op);
    return error;
  }

  String? redo(Trash trash) {
    if (_undone.isEmpty) return null;
    final op = _undone.removeLast();
    final error = op.redo(trash);
    if (error == null) _done.add(op);
    return error;
  }
}
