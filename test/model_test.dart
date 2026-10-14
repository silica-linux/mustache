import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';

Entry file(String name, {int size = 0, DateTime? at, bool dir = false}) =>
    Entry(
      name: name,
      path: '/prova/$name',
      isDirectory: dir,
      size: size,
      modified: at ?? DateTime(2026, 10, 13, 10),
    );

void main() {
  test('ordinamento naturale, senza distinguere le maiuscole', () {
    final names = [
      for (final e in sortEntries([
        file('file 10'),
        file('File 2'),
        file('alfa'),
        file('file 1'),
      ], SortKey.name))
        e.name,
    ];
    expect(names, ['alfa', 'file 1', 'File 2', 'file 10']);
    expect(
      sortEntries(
        [file('a'), file('b')],
        SortKey.name,
        descending: true,
      ).first.name,
      'b',
    );
  });

  test('per dimensione le cartelle vengono prima, a parità per nome', () {
    final sorted = sortEntries([
      file('grande', size: 5000),
      file('cartella', dir: true),
      file('piccolo', size: 10),
      file('anche piccolo', size: 10),
    ], SortKey.size);
    expect(
      [for (final e in sorted) e.name],
      ['cartella', 'anche piccolo', 'piccolo', 'grande'],
    );
  });

  test('dimensioni e date nei formati della vista a elenco', () {
    expect(formatSize(file('x', size: 12)), '12 byte');
    expect(formatSize(file('x', size: 3400000)), '3 MB');
    // Come le righe di mu20-list-rows (R3.2).
    expect(formatSize(file('x', size: 2967)), '3 KB');
    expect(formatSize(file('x', size: 461000)), '461 KB');
    expect(formatSize(file('x', size: 2150000000)), '2,15 GB');
    expect(formatSize(file('x', size: 0)), 'Zero byte');
    expect(formatSize(file('x', dir: true)), '--');
    final now = DateTime(2026, 10, 13, 12);
    expect(formatDate(DateTime(2026, 10, 13, 10, 22), now), 'oggi, 10:22');
    expect(formatDate(DateTime(2026, 10, 12, 18, 5), now), 'ieri, 18:05');
    expect(formatDate(DateTime(2024, 3, 3, 9, 14), now), '3 mar 2024, 09:14');
  });

  test('estensioni e tipi', () {
    expect(file('foto.JPG').extension, 'jpg');
    expect(file('.nascosto').extension, '');
    expect(file('senza').extension, '');
    // Famiglie brevi (R3.3): il formato per immagini e audio, l'estensione per gli archivi.
    expect(kindLabel(file('a.pdf'), 'application/pdf'), 'PDF');
    expect(kindLabel(file('a.png'), 'image/png'), 'Immagine PNG');
    expect(kindLabel(file('a.wav'), 'audio/x-wav'), 'Audio WAV');
    expect(kindLabel(file('a.zip'), 'application/zip'), 'Archivio zip');
    expect(kindLabel(file('a.rs'), 'text/rust'), 'Testo');
    expect(kindLabel(file('a.mov'), 'video/quicktime'), 'Video');
    expect(kindLabel(file('dati')), 'Documento');
    expect(kindLabel(file('Gamma', dir: true)), 'Cartella');
  });

  test(
    'cronologia: indietro, avanti, e una nuova strada cancella l\'avanti',
    () {
      final history = History('/a')
        ..go('/a/b')
        ..go('/a/b/c');
      expect(history.back(), isTrue);
      expect(history.current, '/a/b');
      expect(history.canGoForward, isTrue);
      history.go('/x');
      expect(history.canGoForward, isFalse);
      expect(history.back(), isTrue);
      expect(history.current, '/a/b');
      expect(parentOf('/a/b/'), '/a');
      expect(parentOf('/a'), '/');
      expect(parentOf('/'), isNull);
    },
  );

  test('luoghi dalle cartelle dell\'utente, solo quelle che esistono', () {
    final home = Directory.systemTemp.createTempSync('mustache-home').path;
    Directory('$home/Scrivania').createSync();
    Directory('$home/Scaricati').createSync();
    final places = userPlaces(
      home: home,
      userDirs:
          '# commento\n'
          'XDG_DESKTOP_DIR="\$HOME/Scrivania"\n'
          'XDG_DOWNLOAD_DIR="\$HOME/Scaricati"\n'
          'XDG_MUSIC_DIR="\$HOME/Musica"\n'
          'XDG_PUBLICSHARE_DIR="\$HOME"\n',
    );
    expect(
      [for (final p in places) p.label],
      [home.split('/').last, 'Scrivania', 'Scaricati'],
    );
    expect(trashPlace(home: home).path, '$home/.local/share/Trash/files');
    expect(trashPlace(home: home, dataHome: '/d').path, '/d/Trash/files');
  });

  test('una cartella che non esiste è un errore, non un\'eccezione', () {
    final result = listDirectory('/non/esiste/davvero');
    expect(result.error, isNotNull);
    expect(result.entries, isEmpty);
  });

  test('un collegamento ha la sua data e la sua dimensione (R3.2)', () {
    final dir = Directory.systemTemp.createTempSync('mustache-link');
    addTearDown(() => dir.deleteSync(recursive: true));
    final target = File('${dir.path}/appunti.txt')..writeAsStringSync('x' * 31);
    target.setLastModifiedSync(DateTime(2024, 10, 13, 12, 56));
    Link('${dir.path}/collegamento').createSync('appunti.txt');
    final link = listDirectory(
      dir.path,
    ).entries.firstWhere((e) => e.name == 'collegamento');
    expect(link.isLink, isTrue);
    // La destinazione è lunga 11 byte ("appunti.txt"); la data è di adesso, non del 2024.
    expect(link.size, 11);
    expect(link.modified.year, DateTime.now().year);
    expect(kindLabel(link, 'text/plain'), 'Collegamento');
    expect(entryAt(link.path)?.size, 11);
  });
}
