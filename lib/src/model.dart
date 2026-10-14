// Il modello di Mustache, senza interfaccia: il contenuto di una cartella, l'ordinamento, i
// formati di date e dimensioni, la cronologia della navigazione e i luoghi dell'utente.

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'link_stat.dart';

/// Un elemento di una cartella.
@immutable
class Entry {
  const Entry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modified,
    this.isLink = false,
  });

  final String name;
  final String path;
  final bool isDirectory;

  /// Byte; per le cartelle non conta.
  final int size;
  final DateTime modified;
  final bool isLink;

  bool get isHidden => name.startsWith('.');

  /// L'estensione senza punto, minuscola; vuota per le cartelle e i nomi senza punto.
  String get extension {
    if (isDirectory) return '';
    final dot = name.lastIndexOf('.');
    return dot <= 0 || dot == name.length - 1
        ? ''
        : name.substring(dot + 1).toLowerCase();
  }
}

/// Le colonne per cui si ordina.
enum SortKey { name, modified, size, kind }

/// Il contenuto di `path`, senza i file nascosti salvo `showHidden`. Una cartella che non si
/// legge (permessi, sparita) dà un errore, non un'eccezione.
({List<Entry> entries, String? error}) listDirectory(
  String path, {
  bool showHidden = false,
}) {
  final entries = <Entry>[];
  try {
    for (final item in Directory(path).listSync(followLinks: false)) {
      final name = item.uri.pathSegments.lastWhere(
        (s) => s.isNotEmpty,
        orElse: () => item.path,
      );
      if (!showHidden && name.startsWith('.')) continue;
      final link = item is Link;
      // Per i collegamenti la destinazione dice se è una cartella (si apre); data e dimensione
      // sono del collegamento (R3.2).
      final stat = link ? FileStat.statSync(item.path) : item.statSync();
      final own = link ? linkStat(item.path) : null;
      entries.add(
        Entry(
          name: Uri.decodeComponent(name),
          path: item.path,
          isDirectory: stat.type == FileSystemEntityType.directory,
          size: own?.size ?? (stat.size < 0 ? 0 : stat.size),
          modified: own?.modified ?? stat.modified,
          isLink: link,
        ),
      );
    }
  } on FileSystemException catch (error) {
    return (entries: entries, error: error.osError?.message ?? error.message);
  }
  return (entries: entries, error: null);
}

/// Confronto "naturale": i numeri nei nomi si confrontano per valore (`file 2` prima di
/// `file 10`), le lettere senza distinguere maiuscole e minuscole.
int naturalCompare(String a, String b) {
  final x = a.toLowerCase();
  final y = b.toLowerCase();
  var i = 0;
  var j = 0;
  while (i < x.length && j < y.length) {
    final ci = x.codeUnitAt(i);
    final cj = y.codeUnitAt(j);
    if (_isDigit(ci) && _isDigit(cj)) {
      final si = i;
      final sj = j;
      while (i < x.length && _isDigit(x.codeUnitAt(i))) {
        i++;
      }
      while (j < y.length && _isDigit(y.codeUnitAt(j))) {
        j++;
      }
      final ni = BigInt.parse(x.substring(si, i));
      final nj = BigInt.parse(y.substring(sj, j));
      final c = ni.compareTo(nj);
      if (c != 0) return c;
      continue;
    }
    if (ci != cj) return ci.compareTo(cj);
    i++;
    j++;
  }
  final rest = (x.length - i).compareTo(y.length - j);
  return rest != 0 ? rest : a.compareTo(b);
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

/// Gli elementi ordinati per `key`. A parità si ordina per nome; le cartelle stanno fra i
/// file (l'ordine misto è quello predefinito, da verificare: MU-20).
List<Entry> sortEntries(
  Iterable<Entry> entries,
  SortKey key, {
  bool descending = false,
  String Function(Entry)? kindOf,
}) {
  final kind = kindOf ?? kindLabel;
  int compare(Entry a, Entry b) {
    final byName = naturalCompare(a.name, b.name);
    final primary = switch (key) {
      SortKey.name => byName,
      SortKey.modified => a.modified.compareTo(b.modified),
      SortKey.size =>
        a.isDirectory != b.isDirectory
            ? (a.isDirectory ? -1 : 1)
            : a.size.compareTo(b.size),
      SortKey.kind => kind(a).compareTo(kind(b)),
    };
    return primary != 0 ? primary : byName;
  }

  final sorted = entries.toList()..sort(compare);
  return descending ? sorted.reversed.toList() : sorted;
}

const List<String> _units = ['KB', 'MB', 'GB', 'TB'];

/// Dimensione in unità decimali (1 KB = 1000 byte, R3.2): "N byte" sotto 1000, KB e MB interi,
/// GB e TB con due decimali e la virgola; "Zero byte" per un file vuoto, "--" per le cartelle.
String formatSize(Entry entry) {
  if (entry.isDirectory) return '--';
  final bytes = entry.size;
  if (bytes == 0) return 'Zero byte';
  if (bytes < 1000) return '$bytes byte';
  var value = bytes / 1000;
  var unit = 0;
  while (value.round() >= 1000 && unit < _units.length - 1) {
    value /= 1000;
    unit++;
  }
  final text = unit < 2
      ? value.round().toString()
      : value.toStringAsFixed(2).replaceAll('.', ',');
  return '$text ${_units[unit]}';
}

const List<String> _months = [
  'gen',
  'feb',
  'mar',
  'apr',
  'mag',
  'giu',
  'lug',
  'ago',
  'set',
  'ott',
  'nov',
  'dic',
];

/// "oggi, 10:22", "ieri, 18:05", altrimenti "3 ott 2026, 09:14" (R3.1: minuscolo, anno
/// sempre).
String formatDate(DateTime t, DateTime now) {
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  final day = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(day).inDays;
  if (days == 0) return 'oggi, $hh:$mm';
  if (days == 1) return 'ieri, $hh:$mm';
  return '${t.day} ${_months[t.month - 1]} ${t.year}, $hh:$mm';
}

const Map<String, String> _formats = {
  'png': 'PNG',
  'jpeg': 'JPEG',
  'gif': 'GIF',
  'webp': 'WebP',
  'svg+xml': 'SVG',
  'tiff': 'TIFF',
  'bmp': 'BMP',
  'heic': 'HEIC',
  'avif': 'AVIF',
  'x-tga': 'TGA',
  'wav': 'WAV',
  'x-wav': 'WAV',
  'vnd.wave': 'WAV',
  'aiff': 'AIFF',
  'x-aiff': 'AIFF',
  'mpeg': 'MP3',
  'flac': 'FLAC',
  'x-flac': 'FLAC',
  'ogg': 'Ogg',
  'x-vorbis+ogg': 'Ogg',
  'opus': 'Opus',
  'aac': 'AAC',
  'mp4': 'AAC',
};

const Set<String> _archives = {
  'application/zip',
  'application/gzip',
  'application/x-tar',
  'application/x-compressed-tar',
  'application/x-xz',
  'application/x-xz-compressed-tar',
  'application/x-bzip2',
  'application/x-bzip2-compressed-tar',
  'application/x-7z-compressed',
  'application/vnd.rar',
  'application/x-rar',
  'application/zstd',
  'application/x-zstd-compressed-tar',
};

/// La colonna Tipo: un nome breve per famiglia (R3.3), con parole nostre: cartella,
/// collegamento, testo, archivio, video, PDF, immagine e audio col formato, documento per il
/// resto. `mime` è il tipo del contenuto (della destinazione, per un collegamento).
String kindLabel(Entry entry, [String? mime]) {
  if (entry.isLink) return 'Collegamento';
  if (entry.isDirectory) return 'Cartella';
  final type = mime ?? 'application/octet-stream';
  final slash = type.indexOf('/');
  final top = slash < 0 ? type : type.substring(0, slash);
  final sub = slash < 0 ? '' : type.substring(slash + 1);
  if (type == 'application/pdf') return 'PDF';
  if (top == 'image') return 'Immagine ${_formats[sub] ?? sub.toUpperCase()}';
  if (top == 'audio') return 'Audio ${_formats[sub] ?? sub.toUpperCase()}';
  if (top == 'video') return 'Video';
  if (_archives.contains(type)) {
    final ext = entry.extension;
    return ext.isEmpty ? 'Archivio' : 'Archivio $ext';
  }
  if (type == 'application/json') return 'JSON';
  if (type == 'text/markdown') return 'Markdown';
  if (top == 'text') return 'Testo';
  return 'Documento';
}

/// La cronologia di una finestra: indietro e avanti come in un navigatore.
class History {
  History(String start) : _stack = [start];

  final List<String> _stack;
  int _index = 0;

  String get current => _stack[_index];
  bool get canGoBack => _index > 0;
  bool get canGoForward => _index < _stack.length - 1;

  /// Va in `path`: la cronologia in avanti si perde.
  void go(String path) {
    if (path == current) return;
    _stack
      ..removeRange(_index + 1, _stack.length)
      ..add(path);
    _index = _stack.length - 1;
  }

  bool back() {
    if (!canGoBack) return false;
    _index--;
    return true;
  }

  bool forward() {
    if (!canGoForward) return false;
    _index++;
    return true;
  }
}

/// La cartella che contiene `path`, o null alla radice.
String? parentOf(String path) {
  final trimmed = path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  if (trimmed == '/') return null;
  final slash = trimmed.lastIndexOf('/');
  if (slash < 0) return null;
  return slash == 0 ? '/' : trimmed.substring(0, slash);
}

/// Il nome da mostrare per una cartella: l'ultimo segmento, "/" per la radice.
String displayName(String path) {
  if (path == '/') return '/';
  final parts = path.split('/').where((s) => s.isNotEmpty);
  return parts.isEmpty ? path : parts.last;
}

/// Un luogo della barra laterale.
@immutable
class Place {
  const Place(this.label, this.path, this.kind);

  final String label;
  final String path;
  final PlaceKind kind;
}

enum PlaceKind {
  home,
  desktop,
  documents,
  downloads,
  pictures,
  music,
  videos,
  trash,

  /// Un'etichetta (percorso `tag:<nome>`): mostra gli elementi che la portano.
  tag,
}

/// Il prefisso dei percorsi delle etichette nella barra laterale.
const String tagPathPrefix = 'tag:';

/// Le cartelle dell'utente da `~/.config/user-dirs.dirs` (specifica xdg-user-dirs), con il
/// nome della cartella come etichetta; solo quelle che esistono.
List<Place> userPlaces({required String home, String? userDirs}) {
  final dirs = <String, String>{};
  for (final line in (userDirs ?? '').split('\n')) {
    final match = RegExp(r'^XDG_(\w+)_DIR="(.*)"$').firstMatch(line.trim());
    if (match == null) continue;
    dirs[match.group(1)!] = match.group(2)!.replaceFirst(r'$HOME', home);
  }
  final places = <Place>[Place(displayName(home), home, PlaceKind.home)];
  for (final (key, kind) in [
    ('DESKTOP', PlaceKind.desktop),
    ('DOCUMENTS', PlaceKind.documents),
    ('DOWNLOAD', PlaceKind.downloads),
    ('PICTURES', PlaceKind.pictures),
    ('MUSIC', PlaceKind.music),
    ('VIDEOS', PlaceKind.videos),
  ]) {
    final path = dirs[key];
    if (path == null || path == home || !Directory(path).existsSync()) continue;
    places.add(Place(displayName(path), path, kind));
  }
  return places;
}

/// Il Cestino dell'utente (specifica freedesktop Trash): `$XDG_DATA_HOME/Trash/files`.
Place trashPlace({required String home, String? dataHome}) {
  final base = (dataHome == null || dataHome.isEmpty)
      ? '$home/.local/share'
      : dataHome;
  return Place('Cestino', '$base/Trash/files', PlaceKind.trash);
}

/// L'elemento in `path` (null se non esiste): come una riga di `listDirectory`.
Entry? entryAt(String path) {
  try {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    final link = type == FileSystemEntityType.link;
    final stat = FileStat.statSync(path);
    final own = link ? linkStat(path) : null;
    return Entry(
      name: displayName(path),
      path: path,
      isDirectory: stat.type == FileSystemEntityType.directory,
      size: own?.size ?? (stat.size < 0 ? 0 : stat.size),
      modified: own?.modified ?? stat.modified,
      isLink: link,
    );
  } on FileSystemException {
    return null;
  }
}

/// La vista dei contenuti (spec 3–6): a icone (⌘1), a elenco (⌘2), a colonne (⌘3).
enum ViewMode { icons, list, columns, gallery }
