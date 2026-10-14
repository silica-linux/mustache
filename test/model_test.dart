import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:mustache/src/l10n.dart';
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
  test('natural sort, case insensitive', () {
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

  test('by size folders come first, ties by name', () {
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

  test('sizes and dates in the list view formats', () {
    expect(formatSize(file('x', size: 12)), '12 bytes');
    expect(formatSize(file('x', size: 1)), '1 byte');
    expect(formatSize(file('x', size: 3400000)), '3 MB');
    // Like the rows of MU-20 (R3.2).
    expect(formatSize(file('x', size: 2967)), '3 KB');
    expect(formatSize(file('x', size: 461000)), '461 KB');
    expect(formatSize(file('x', size: 2150000000)), '2.15 GB');
    expect(formatSize(file('x', size: 0)), 'Zero bytes');
    expect(formatSize(file('x', dir: true)), '--');
    final now = DateTime(2026, 10, 13, 12);
    expect(formatDate(DateTime(2026, 10, 13, 10, 22), now), 'Today, 10:22');
    expect(formatDate(DateTime(2026, 10, 12, 18, 5), now), 'Yesterday, 18:05');
    expect(formatDate(DateTime(2024, 3, 3, 9, 14), now), 'Mar 3, 2024, 09:14');
  });

  test('in Italian: the measured formats (R3.1, R3.2)', () {
    useLocale(const Locale('it'));
    addTearDown(() => useLocale(const Locale('en')));
    expect(formatSize(file('x', size: 12)), '12 byte');
    expect(formatSize(file('x', size: 2150000000)), '2,15 GB');
    expect(formatSize(file('x', size: 0)), 'Zero byte');
    final now = DateTime(2026, 10, 13, 12);
    expect(formatDate(DateTime(2026, 10, 13, 10, 22), now), 'oggi, 10:22');
    expect(formatDate(DateTime(2026, 10, 12, 18, 5), now), 'ieri, 18:05');
    expect(formatDate(DateTime(2024, 3, 3, 9, 14), now), '3 mar 2024, 09:14');
    expect(kindLabel(file('a.png'), 'image/png'), 'Immagine PNG');
    expect(kindLabel(file('a.zip'), 'application/zip'), 'Archivio zip');
    expect(kindLabel(file('dati')), 'Documento');
  });

  test('the language: the first supported one, otherwise English', () {
    expect(resolveLocale(const [Locale('it', 'IT')]), const Locale('it'));
    expect(
      resolveLocale(const [Locale('de'), Locale('it')]),
      const Locale('it'),
    );
    expect(resolveLocale(const [Locale('de')]), const Locale('en'));
    expect(resolveLocale(const []), const Locale('en'));
  });

  test('extensions and kinds', () {
    expect(file('foto.JPG').extension, 'jpg');
    expect(file('.nascosto').extension, '');
    expect(file('senza').extension, '');
    // Short families (R3.3): the format for images and audio, the extension for archives.
    expect(kindLabel(file('a.pdf'), 'application/pdf'), 'PDF');
    expect(kindLabel(file('a.png'), 'image/png'), 'PNG image');
    expect(kindLabel(file('a.wav'), 'audio/x-wav'), 'WAV audio');
    expect(kindLabel(file('a.zip'), 'application/zip'), 'zip archive');
    expect(kindLabel(file('a.rs'), 'text/rust'), 'Text');
    expect(kindLabel(file('a.mov'), 'video/quicktime'), 'Video');
    expect(kindLabel(file('dati')), 'Document');
    expect(kindLabel(file('Gamma', dir: true)), 'Folder');
  });

  test('history: back, forward, and a new path clears forward', () {
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
  });

  test('places from the user folders, only those that exist', () {
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

  test('a folder that does not exist is an error, not an exception', () {
    final result = listDirectory('/non/esiste/davvero');
    expect(result.error, isNotNull);
    expect(result.entries, isEmpty);
  });

  test('a link has its own date and size (R3.2)', () {
    final dir = Directory.systemTemp.createTempSync('mustache-link');
    addTearDown(() => dir.deleteSync(recursive: true));
    final target = File('${dir.path}/appunti.txt')..writeAsStringSync('x' * 31);
    target.setLastModifiedSync(DateTime(2024, 10, 13, 12, 56));
    Link('${dir.path}/collegamento').createSync('appunti.txt');
    final link = listDirectory(
      dir.path,
    ).entries.firstWhere((e) => e.name == 'collegamento');
    expect(link.isLink, isTrue);
    // The target is 11 bytes long ("appunti.txt"); the date is now, not 2024.
    expect(link.size, 11);
    expect(link.modified.year, DateTime.now().year);
    expect(kindLabel(link, 'text/plain'), 'Link');
    expect(entryAt(link.path)?.size, 11);
  });

  test('history: the places before and after, and jumps', () {
    final h = History('/a')
      ..go('/b')
      ..go('/c')
      ..go('/d');
    expect(h.backList, ['/c', '/b', '/a']);
    expect(h.forwardList, isEmpty);
    expect(h.jump(-2), isTrue);
    expect(h.current, '/b');
    expect(h.forwardList, ['/c', '/d']);
    expect(h.jump(2), isTrue);
    expect(h.current, '/d');
    expect(h.jump(1), isFalse);
    expect(h.jump(-4), isFalse);
    expect(h.jump(0), isFalse);
  });
}
