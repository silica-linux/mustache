import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/apps.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  late Directory root;
  late Map<String, String> env;

  void app(String id, String text) {
    final file = File('${root.path}/data/applications/$id')
      ..createSync(recursive: true);
    file.writeAsStringSync(text);
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('mustache-app');
    env = {
      'HOME': root.path,
      'XDG_DATA_HOME': '${root.path}/data',
      'XDG_DATA_DIRS': '${root.path}/sys',
      'XDG_CONFIG_HOME': '${root.path}/config',
      'XDG_CONFIG_DIRS': '${root.path}/etc',
    };
    app('editor.desktop', '''
[Desktop Entry]
Type=Application
Name=Editor
Name[it]=Editor di testo
Exec=editor --new-window %U
MimeType=text/plain;
''');
    app('visore.desktop', '''
[Desktop Entry]
Type=Application
Name=Visore
Exec="/opt/il visore/bin" %f
MimeType=text/plain;image/png;
''');
    app('nascosta.desktop', '''
[Desktop Entry]
Type=Application
Name=Nascosta
Exec=nascosta
NoDisplay=true
MimeType=text/plain;
''');
    app('sub/codice.desktop', '''
[Desktop Entry]
Type=Application
Name=Codice
Exec=codice
MimeType=text/x-csrc;
''');
    File('${root.path}/config/mimeapps.list')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
[Default Applications]
image/png=visore.desktop;
[Removed Associations]
text/plain=editor.desktop;
''');
  });

  tearDown(() => root.deleteSync(recursive: true));

  final mime = MimeDatabase.fromText(
    globs2: '50:text/plain:*.txt\n50:text/x-csrc:*.c\n',
    subclasses: 'text/x-csrc text/plain\n',
  );

  test('voci .desktop: nome tradotto, nascoste, id con le sottocartelle', () {
    final registry = AppRegistry.load(env: env, mime: mime);
    expect(registry.apps['editor.desktop']?.name, 'Editor di testo');
    expect(registry.apps.containsKey('nascosta.desktop'), isFalse);
    expect(registry.apps['sub-codice.desktop']?.name, 'Codice');
  });

  test('predefinita, tolte, genitori e ordine di "Apri con"', () {
    final registry = AppRegistry.load(env: env, mime: mime);
    expect(registry.defaultFor('image/png')?.id, 'visore.desktop');
    // L'editor è tolto per text/plain: resta il visore.
    expect(
      [for (final a in registry.appsFor('text/plain')) a.id],
      ['visore.desktop'],
    );
    // Per il sorgente C: prima chi lo dichiara, poi chi apre il genitore text/plain.
    expect(
      [for (final a in registry.appsFor('text/x-csrc')) a.id],
      ['sub-codice.desktop', 'visore.desktop'],
    );
    expect(registry.defaultFor('application/x-ignoto'), isNull);
  });

  test('Exec: codici di campo, virgolette, file in fondo', () {
    final registry = AppRegistry.load(env: env, mime: mime);
    expect(
      execArguments(registry.apps['editor.desktop']!, ['/a b.txt', '/c.txt']),
      ['editor', '--new-window', '/a b.txt', '/c.txt'],
    );
    expect(
      execArguments(registry.apps['visore.desktop']!, ['/x.png', '/y.png']),
      ['/opt/il visore/bin', '/x.png'],
    );
    expect(execArguments(registry.apps['sub-codice.desktop']!, ['/m.c']), [
      'codice',
      '/m.c',
    ]);
    expect(
      execArguments(
        const DesktopApp(id: 'p', name: 'P', exec: 'p --sconto=50%% %d'),
        [],
      ),
      ['p', '--sconto=50%'],
    );
  });

  test(
    'un programma che non esiste è un messaggio, non un\'eccezione',
    () async {
      final error = await launchApp(
        const DesktopApp(id: 'x', name: 'Fantasma', exec: '/non/esiste %f'),
        ['/tmp/a'],
      );
      expect(error, contains('Fantasma'));
    },
  );
}
