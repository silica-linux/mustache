// Le app che aprono un file (MU-50, mustache-spec R10.1): le voci .desktop con `MimeType`
// (specifica freedesktop Desktop Entry), le scelte di `mimeapps.list` (specifica "Association
// between MIME types and applications": predefinite, aggiunte, tolte) e l'avvio con i codici di
// campo di `Exec`.

import 'dart:io';

import 'package:silica_ui/silica_ui.dart' show MimeDatabase, xdgDataDirs;

/// Un'app installata che dichiara i tipi che apre.
class DesktopApp {
  const DesktopApp({
    required this.id,
    required this.name,
    required this.exec,
    this.mimeTypes = const [],
    this.icon,
    this.terminal = false,
  });

  /// L'id della voce (`org.gnome.TextEditor.desktop`).
  final String id;
  final String name;
  final String exec;
  final List<String> mimeTypes;
  final String? icon;
  final bool terminal;
}

/// Una voce .desktop (testo); null se non è un'app avviabile o è nascosta.
DesktopApp? parseDesktopApp(String id, String text, {String locale = 'it'}) {
  final values = <String, String>{};
  var inEntry = false;
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('[')) {
      inEntry = line == '[Desktop Entry]';
      continue;
    }
    if (!inEntry || line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    values[line.substring(0, eq).trim()] = line.substring(eq + 1).trim();
  }
  if (values['Type'] != 'Application') return null;
  if (values['NoDisplay'] == 'true' || values['Hidden'] == 'true') return null;
  final exec = values['Exec'];
  final name = values['Name[$locale]'] ?? values['Name'];
  if (exec == null || exec.isEmpty || name == null) return null;
  return DesktopApp(
    id: id,
    name: name,
    exec: exec,
    mimeTypes: [
      for (final t in (values['MimeType'] ?? '').split(';'))
        if (t.trim().isNotEmpty) t.trim(),
    ],
    icon: values['Icon'],
    terminal: values['Terminal'] == 'true',
  );
}

/// Le scelte di `mimeapps.list`, unite nell'ordine di precedenza.
class MimeApps {
  final Map<String, List<String>> defaults = {};
  final Map<String, List<String>> added = {};
  final Map<String, Set<String>> removed = {};

  /// Aggiunge un file (i primi letti hanno precedenza).
  void addFile(String text) {
    String? section;
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.startsWith('[')) {
        section = line;
        continue;
      }
      final eq = line.indexOf('=');
      if (eq <= 0 || line.startsWith('#')) continue;
      final type = line.substring(0, eq).trim();
      final ids = [
        for (final id in line.substring(eq + 1).split(';'))
          if (id.trim().isNotEmpty) id.trim(),
      ];
      switch (section) {
        case '[Default Applications]':
          defaults.putIfAbsent(type, () => []).addAll(ids);
        case '[Added Associations]':
          added.putIfAbsent(type, () => []).addAll(ids);
        case '[Removed Associations]':
          removed.putIfAbsent(type, () => {}).addAll(ids);
      }
    }
  }
}

/// Le app e le associazioni del sistema e dell'utente.
class AppRegistry {
  AppRegistry(this.apps, this.mimeApps, this.mime);

  /// Dai file del sistema: applications/ nelle cartelle dei dati XDG (la prima vince), e i
  /// `mimeapps.list` di configurazione e dati (specifica, "File name and location").
  factory AppRegistry.load({Map<String, String>? env, MimeDatabase? mime}) {
    final e = env ?? Platform.environment;
    final apps = <String, DesktopApp>{};
    final dataDirs = xdgDataDirs(e);
    for (final dir in dataDirs) {
      final root = Directory('$dir/applications');
      if (!root.existsSync()) continue;
      try {
        for (final file in root.listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.desktop')) continue;
          final id = file.path
              .substring(root.path.length + 1)
              .replaceAll('/', '-');
          if (apps.containsKey(id)) continue;
          try {
            final app = parseDesktopApp(id, file.readAsStringSync());
            if (app != null) apps[id] = app;
          } on FileSystemException {
            continue;
          } on FormatException {
            continue;
          }
        }
      } on FileSystemException {
        continue;
      }
    }
    final mimeApps = MimeApps();
    final home = e['HOME'] ?? '/';
    final config = e['XDG_CONFIG_HOME'];
    final configHome = config == null || config.isEmpty
        ? '$home/.config'
        : config;
    final configDirs = (e['XDG_CONFIG_DIRS'] ?? '/etc/xdg').split(':');
    for (final path in [
      '$configHome/mimeapps.list',
      for (final d in configDirs)
        if (d.isNotEmpty) '$d/mimeapps.list',
      for (final d in dataDirs) '$d/applications/mimeapps.list',
    ]) {
      try {
        mimeApps.addFile(File(path).readAsStringSync());
      } on FileSystemException {
        continue;
      } on FormatException {
        continue;
      }
    }
    return AppRegistry(apps, mimeApps, mime ?? MimeDatabase.load(env: env));
  }

  final Map<String, DesktopApp> apps;
  final MimeApps mimeApps;
  final MimeDatabase mime;

  List<String> _typeChain(String type) => [type, ...mime.parentsOf(type)];

  /// L'app predefinita per un tipo: `Default Applications` per il tipo e poi per i genitori;
  /// altrimenti la prima app aggiunta o installata che lo apre.
  DesktopApp? defaultFor(String type) {
    for (final t in _typeChain(type)) {
      for (final id in mimeApps.defaults[t] ?? const <String>[]) {
        final app = apps[id];
        if (app != null && !(mimeApps.removed[t]?.contains(id) ?? false))
          return app;
      }
    }
    return appsFor(type).firstOrNull;
  }

  /// Le app che aprono un tipo (o un suo genitore), senza le tolte; prima le aggiunte in
  /// `mimeapps.list`, poi le altre in ordine di nome.
  List<DesktopApp> appsFor(String type) {
    final out = <DesktopApp>[];
    final seen = <String>{};
    for (final t in _typeChain(type)) {
      final removed = mimeApps.removed[t] ?? const <String>{};
      for (final id in mimeApps.added[t] ?? const <String>[]) {
        final app = apps[id];
        if (app != null && !removed.contains(id) && seen.add(id)) out.add(app);
      }
      final declared = [
        for (final app in apps.values)
          if (app.mimeTypes.contains(t) && !removed.contains(app.id)) app,
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      for (final app in declared) {
        if (seen.add(app.id)) out.add(app);
      }
    }
    return out;
  }
}

/// La riga di comando di `Exec` per aprire `paths` (codici di campo: %f %F %u %U, %i %c %k;
/// %d %D %n %N %v %m deprecati e tolti; %% è %). Le virgolette della specifica si rispettano.
List<String> execArguments(
  DesktopApp app,
  List<String> paths, {
  String? desktopFile,
}) {
  final words = _splitExec(app.exec);
  final out = <String>[];
  var usedFiles = false;
  for (final word in words) {
    switch (word) {
      case '%f' || '%u':
        if (paths.isNotEmpty) out.add(paths.first);
        usedFiles = true;
      case '%F' || '%U':
        out.addAll(paths);
        usedFiles = true;
      case '%i':
        if (app.icon != null) out.addAll(['--icon', app.icon!]);
      case '%c':
        out.add(app.name);
      case '%k':
        if (desktopFile != null) out.add(desktopFile);
      case '%d' || '%D' || '%n' || '%N' || '%v' || '%m':
        break;
      default:
        out.add(
          word
              .replaceAll('%%', '\u0000')
              .replaceAllMapped(RegExp('%[a-zA-Z]'), (_) => '')
              .replaceAll('\u0000', '%'),
        );
    }
  }
  // Un'app senza codici di campo riceve comunque il file in fondo.
  if (!usedFiles) out.addAll(paths);
  return out.where((w) => w.isNotEmpty).toList();
}

List<String> _splitExec(String exec) {
  final out = <String>[];
  final current = StringBuffer();
  var quoted = false;
  var started = false;
  for (var i = 0; i < exec.length; i++) {
    final c = exec[i];
    if (quoted) {
      if (c == '\\' && i + 1 < exec.length) {
        current.write(exec[++i]);
      } else if (c == '"') {
        quoted = false;
      } else {
        current.write(c);
      }
    } else if (c == '"') {
      quoted = true;
      started = true;
    } else if (c == ' ' || c == '\t') {
      if (started || current.isNotEmpty) out.add(current.toString());
      current.clear();
      started = false;
    } else {
      current.write(c);
      started = true;
    }
  }
  if (started || current.isNotEmpty) out.add(current.toString());
  return out;
}

/// Avvia un'app su dei file, staccata da Mustache. Un errore (programma assente) è un messaggio.
Future<String?> launchApp(DesktopApp app, List<String> paths) async {
  final args = execArguments(app, paths);
  if (args.isEmpty) return 'La voce di «${app.name}» non ha un comando.';
  try {
    await Process.start(
      args.first,
      args.skip(1).toList(),
      mode: ProcessStartMode.detached,
    );
    return null;
  } on ProcessException catch (e) {
    return 'Non si può aprire «${app.name}»: ${e.message}';
  }
}

final Map<String, String?> _comments = {};

/// La descrizione di un tipo MIME nella lingua (`<comment xml:lang="it">` di
/// `mime/<tipo>.xml`), o quella senza lingua; null se il tipo non ha un file.
String? mimeComment(
  String type, {
  String locale = 'it',
  Map<String, String>? env,
}) {
  final key = '$locale $type';
  // In cache solo con l'ambiente del processo (i test ne passano altri).
  if (env == null && _comments.containsKey(key)) return _comments[key];
  String? found;
  for (final dir in xdgDataDirs(env ?? Platform.environment)) {
    final file = File('$dir/mime/$type.xml');
    if (!file.existsSync()) continue;
    try {
      final text = file.readAsStringSync();
      final localized = RegExp(
        '<comment xml:lang="$locale">([^<]*)</comment>',
      ).firstMatch(text);
      final plain = RegExp('<comment>([^<]*)</comment>').firstMatch(text);
      found = _unescape((localized ?? plain)?.group(1));
      if (found != null) break;
    } on FileSystemException {
      continue;
    }
  }
  if (env == null) _comments[key] = found;
  return found;
}

String? _unescape(String? s) => s
    ?.replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');
