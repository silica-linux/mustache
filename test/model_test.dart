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
    expect(formatSize(file('x', size: 3400000)), '3,4 MB');
    expect(formatSize(file('x', size: 2000000000)), '2 GB');
    expect(formatSize(file('x', dir: true)), '--');
    final now = DateTime(2026, 10, 13, 12);
    expect(formatDate(DateTime(2026, 10, 13, 10, 22), now), 'Oggi, 10:22');
    expect(formatDate(DateTime(2026, 10, 12, 18, 5), now), 'Ieri, 18:05');
    expect(formatDate(DateTime(2024, 3, 3, 9, 14), now), '3 mar 2024, 09:14');
  });

  test('estensioni e tipi', () {
    expect(file('foto.JPG').extension, 'jpg');
    expect(file('.nascosto').extension, '');
    expect(file('senza').extension, '');
    expect(kindLabel(file('a.pdf')), 'Documento PDF');
    expect(kindLabel(file('a.rs')), 'Documento RS');
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
}
