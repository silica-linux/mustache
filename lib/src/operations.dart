// Le operazioni sui file di MU.4 (mustache-spec 8, 9.3, 9.4): nuova cartella, duplica, rinomina,
// Cestino (specifica freedesktop Trash), ripristino, eliminazione, e la pila per annullare.
//
// Mai eccezioni verso l'interfaccia: ogni operazione restituisce il risultato o un messaggio
// (un file sparito, un permesso mancante, un disco pieno sono casi normali).

import 'dart:io';

import 'model.dart';

/// Il nome di una cartella nuova (⇧⌘N).
const String newFolderName = 'cartella senza nome';

/// Il risultato di un'operazione: il percorso prodotto, o un errore da mostrare.
typedef OpResult = ({String? path, String? error});

OpResult _ok(String path) => (path: path, error: null);
OpResult _fail(String message) => (path: null, error: message);

/// Nome e estensione ("appunti", ".txt"); le cartelle e i nomi che iniziano con il punto non
/// hanno estensione.
(String, String) splitExtension(String name, {bool isDirectory = false}) {
  if (isDirectory) return (name, '');
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return (name, '');
  return (name.substring(0, dot), name.substring(dot));
}

/// Un nome libero in `dir`: `base` + `ext`, poi `base 2` + `ext`, `base 3`…
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

/// Il nome della copia (⌘D): "nome copia.ext", poi "nome copia 2.ext"; cartelle "Alfa copia".
String copyName(String dir, String name, {bool isDirectory = false}) {
  final (base, ext) = splitExtension(name, isDirectory: isDirectory);
  return uniqueName(dir, '$base copia', ext);
}

/// Crea "cartella senza nome" (o "… 2") in `dir`.
OpResult createFolder(String dir) {
  final path = '$dir/${uniqueName(dir, newFolderName)}';
  try {
    Directory(path).createSync();
    return _ok(path);
  } on FileSystemException catch (e) {
    return _fail(_describe(e));
  }
}

/// Duplica un file o una cartella (ricorsivamente; i link restano link).
OpResult duplicate(String path) {
  final type = FileSystemEntity.typeSync(path, followLinks: false);
  if (type == FileSystemEntityType.notFound) {
    return _fail('L\'elemento non esiste più.');
  }
  final dir = parentOf(path) ?? '/';
  final target =
      '$dir/${copyName(dir, displayName(path), isDirectory: type == FileSystemEntityType.directory)}';
  try {
    _copy(path, target);
    return _ok(target);
  } on FileSystemException catch (e) {
    // Una copia a metà non resta.
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
    // Resta: meglio un file in più che un errore sopra un errore.
  }
}

/// Elimina subito, senza Cestino (⌥⌘⌫ dopo la conferma).
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

/// Perché un nome nuovo non va: vuoto, `.` o `..`, con `/` (su Linux non può stare in un nome),
/// o già usato nella stessa cartella. Null se va bene.
String? invalidName(String dir, String oldName, String newName) {
  if (newName.trim().isEmpty || newName == '.' || newName == '..') {
    return 'Il nome «$newName» non può essere utilizzato. Scegli un altro nome.';
  }
  if (newName.contains('/') || newName.contains('\u0000')) {
    return 'Il nome «$newName» non può essere utilizzato. '
        'Prova a usare un nome senza la barra «/».';
  }
  if (newName != oldName &&
      FileSystemEntity.typeSync('$dir/$newName', followLinks: false) !=
          FileSystemEntityType.notFound &&
      // Solo maiuscole e minuscole diverse sullo stesso file: si può.
      newName.toLowerCase() != oldName.toLowerCase()) {
    return 'Il nome «$newName» è già stato assegnato. Scegline un altro.';
  }
  return null;
}

/// L'estensione cambia rinominando un file (R8.4: si chiede conferma)?
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

/// Rinomina dentro la stessa cartella.
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
        return _fail('L\'elemento non esiste più.');
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

/// Il Cestino dell'utente (specifica freedesktop Trash): `files/` e `info/`.
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

  /// Il percorso è dentro il Cestino?
  bool contains(String path) => path == files || path.startsWith('$files/');

  /// Sposta nel Cestino; il risultato è il percorso dentro `files/`.
  OpResult put(String path, {DateTime? now}) {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      return _fail('L\'elemento non esiste più.');
    }
    try {
      Directory(files).createSync(recursive: true);
      Directory(info).createSync(recursive: true);
      // Un nome libero sia in files/ sia in info/ (la specifica: il file .trashinfo si crea
      // per primo, in modo esclusivo).
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

  /// La posizione d'origine di un elemento del Cestino (dal suo .trashinfo).
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
      // Senza info non si sa dove tornare.
    } on ArgumentError {
      // Percorso codificato male.
    }
    return null;
  }

  /// Rimette un elemento del Cestino dov'era (R9.10).
  OpResult restore(String trashed) {
    final origin = originOf(trashed);
    if (origin == null) {
      return _fail('Non si sa da dove viene «${displayName(trashed)}».');
    }
    if (FileSystemEntity.typeSync(origin, followLinks: false) !=
        FileSystemEntityType.notFound) {
      return _fail(
        'Nella cartella d\'origine c\'è già un elemento chiamato '
        '«${displayName(origin)}».',
      );
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

/// Sposta; fra dischi diversi (rename impossibile) copia e poi cancella.
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
    // EXDEV: un altro file system.
    if (e.osError?.errorCode != 18) rethrow;
    _copy(from, to);
    _deleteQuietly(from);
  }
}

String _describe(FileSystemException e) {
  final code = e.osError?.errorCode;
  return switch (code) {
    13 || 1 => 'Non hai i permessi per questa operazione.',
    28 => 'Il disco è pieno.',
    2 => 'L\'elemento non esiste più.',
    30 => 'Il disco è di sola lettura.',
    _ => e.osError?.message ?? e.message,
  };
}

/// Un'operazione che si può annullare e ripetere.
abstract class Undoable {
  const Undoable();

  /// L'etichetta del menu Modifica ("Annulla Rinomina").
  String get label;

  /// Annulla; un errore se non si può più.
  String? undo(Trash trash);

  /// Rifà; un errore se non si può più.
  String? redo(Trash trash);
}

class RenameOp extends Undoable {
  RenameOp(this.from, this.to);
  String from;
  String to;

  @override
  String get label => 'Rinomina';

  @override
  String? undo(Trash trash) => renameEntry(to, displayName(from)).error;

  @override
  String? redo(Trash trash) => renameEntry(from, displayName(to)).error;
}

/// Elementi creati (cartella nuova, duplicati): annullare li elimina (non nel Cestino).
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

/// Elementi spostati nel Cestino: annullare li rimette dov'erano.
class TrashOp extends Undoable {
  TrashOp(this.moves);

  /// (origine, percorso nel Cestino).
  final List<(String, String)> moves;

  @override
  String get label => 'Sposta';

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

/// La pila di annulla/ripeti della finestra.
class UndoStack {
  final List<Undoable> _done = [];
  final List<Undoable> _undone = [];

  void push(Undoable op) {
    _done.add(op);
    _undone.clear();
  }

  String? get undoLabel => _done.isEmpty ? null : 'Annulla ${_done.last.label}';
  String? get redoLabel =>
      _undone.isEmpty ? null : 'Ripeti ${_undone.last.label}';

  /// Annulla l'ultima operazione; null se riuscito o se non c'era niente.
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
