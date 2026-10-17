import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/icon_view.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/folder_icons.dart';

import 'folder_fixture.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  test('a folder is full with one visible item; hidden files do not count', () {
    final dir = Directory.systemTemp.createTempSync('full-folder');
    addTearDown(() => dir.deleteSync(recursive: true));
    expect(folderHasItems(dir.path), isFalse);
    File('${dir.path}/.hidden').writeAsStringSync('');
    Directory('${dir.path}/.cache').createSync();
    expect(folderHasItems(dir.path), isFalse);
    File('${dir.path}/a.txt').writeAsStringSync('');
    expect(folderHasItems(dir.path), isTrue);
    // Gone or unreadable: empty, not an exception.
    expect(folderHasItems('${dir.path}/missing'), isFalse);
  });

  test('the answer follows the folder when its contents change', () {
    final dir = Directory.systemTemp.createTempSync('full-folder');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/a.txt')..writeAsStringSync('');
    expect(folderHasItems(dir.path), isTrue);
    file.deleteSync();
    // Make the modification time differ even on a coarse clock.
    final later = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 5;
    Process.runSync('touch', ['-d', '@$later', dir.path]);
    expect(folderHasItems(dir.path), isFalse);
  });

  test(
    'the full variant swaps the artwork and keeps id and dynamic content',
    () {
      final root = folderIconsRoot();
      addTearDown(() => root.deleteSync(recursive: true));
      final env = {'SILICA_ICONS_DIR': root.path};
      final plain = findSilicaIcon('folder-generic', env: env)!;
      final full = fullFolderVariant(plain);
      expect(full.id, 'folder-generic');
      expect(full.layers.single.path, endsWith('/icon-full.svg'));
      expect(full.layers.single.darkPath, isNull);
      expect(full.dynamic, isNotNull);
      expect(plain.layers.single.path, endsWith('/icon.svg'));
    },
  );

  test('an icon without a full variant stays as it is', () {
    final root = folderIconsRoot(withFull: false);
    addTearDown(() => root.deleteSync(recursive: true));
    final plain = findSilicaIcon(
      'folder-generic',
      env: {'SILICA_ICONS_DIR': root.path},
    );
    expect(plain, isNotNull);
    expect(identical(fullFolderVariant(plain!), plain), isTrue);
  });

  test('fullFolder keeps symbol and tint', () {
    final root = folderIconsRoot();
    addTearDown(() => root.deleteSync(recursive: true));
    final plain = findSilicaIcon(
      'folder-generic',
      env: {'SILICA_ICONS_DIR': root.path},
    )!;
    const tint = Color(0xFF2FB350);
    final full = fullFolder(FolderIcon(plain, symbol: 'house', tint: tint));
    expect(full.symbol, 'house');
    expect(full.tint, tint);
    expect(full.icon.layers.single.path, endsWith('/icon-full.svg'));
  });

  testWidgets('EntryIcon draws an empty folder plain and a full one full', (
    tester,
  ) async {
    final root = folderIconsRoot();
    final tree = Directory.systemTemp.createTempSync('full-entries');
    addTearDown(() {
      root.deleteSync(recursive: true);
      tree.deleteSync(recursive: true);
    });
    Directory('${tree.path}/empty').createSync();
    Directory('${tree.path}/full').createSync();
    File('${tree.path}/full/a.txt').writeAsStringSync('');
    Directory('${tree.path}/hidden').createSync();
    File('${tree.path}/hidden/.a').writeAsStringSync('');
    Entry folder(String name) => Entry(
      name: name,
      path: '${tree.path}/$name',
      isDirectory: true,
      size: 0,
      modified: DateTime(2026),
    );

    Future<String> artwork(String name) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: EntryIcon(
            entry: folder(name),
            side: 64,
            env: {'SILICA_ICONS_DIR': root.path},
          ),
        ),
      );
      final source = tester.widget<SilicaIcon>(find.byType(SilicaIcon)).source;
      return (source as FolderSource).folder.icon.layers.single.path;
    }

    expect(await artwork('empty'), endsWith('/icon.svg'));
    expect(await artwork('hidden'), endsWith('/icon.svg'));
    expect(await artwork('full'), endsWith('/icon-full.svg'));
  });
}
