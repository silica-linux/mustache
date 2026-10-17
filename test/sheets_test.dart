import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/go_to_folder.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/saved_search.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';

void main() {
  late Directory home;

  setUp(() {
    home = Directory.systemTemp.createTempSync('mustache-sheets');
    for (final d in [
      'Documents/Projects',
      'Documents/Promo',
      'Documents/Notes',
      'Pictures/Product shots',
      '.hidden',
    ]) {
      Directory('${home.path}/$d').createSync(recursive: true);
    }
    File('${home.path}/Documents/Programs.txt').writeAsStringSync('x');
  });
  tearDown(() => home.deleteSync(recursive: true));

  group('go to folder', () {
    test('typed paths: ~ is home, relative starts at the folder', () {
      expect(expandTyped('~', home: '/h', cwd: '/c'), '/h');
      expect(expandTyped('~/Docs', home: '/h', cwd: '/c'), '/h/Docs');
      expect(expandTyped('/usr', home: '/h', cwd: '/c'), '/usr');
      expect(expandTyped('src', home: '/h', cwd: '/c'), '/c/src');
    });

    test('suggestions: folders by prefix, sorted, no files, no hidden', () {
      List<String> names(String typed) => [
        for (final p in folderSuggestions(
          typed,
          home: home.path,
          cwd: home.path,
        ))
          p.substring(home.path.length),
      ];
      expect(names('~/Documents/Pro'), [
        '/Documents/Projects',
        '/Documents/Promo',
      ]);
      expect(names('~/Documents/pro'), [
        '/Documents/Projects',
        '/Documents/Promo',
      ]);
      expect(names('~/Documents/'), [
        '/Documents/Notes',
        '/Documents/Projects',
        '/Documents/Promo',
      ]);
      expect(names('~/'), ['/Documents', '/Pictures']);
      expect(names('~/.'), ['/.hidden']);
      expect(names('Pictures/Pro'), ['/Pictures/Product shots']);
      expect(names('~/Nothing/x'), isEmpty);
      expect(names(''), isEmpty);
    });

    test('at most four suggestions', () {
      for (var i = 0; i < 6; i++) {
        Directory('${home.path}/Documents/Pa$i').createSync();
      }
      expect(
        folderSuggestions('~/Documents/Pa', home: home.path, cwd: '/').length,
        4,
      );
    });

    test('breadcrumbs', () {
      expect(
        breadcrumb('/h/silica/Documents/Projects', '/h/silica'),
        'silica › Documents › Projects',
      );
      expect(breadcrumb('/h/silica', '/h/silica'), 'silica');
      expect(breadcrumb('/usr/share', '/h/silica'), '/ › usr › share');
    });
  });

  group('saved searches', () {
    test('json round trip and odd values', () {
      const folder = SavedSearch(
        query: 'lemon',
        everywhere: false,
        folder: '/h/Documents',
      );
      final back = SavedSearch.fromJson(folder.toJson())!;
      expect(back.query, 'lemon');
      expect(back.everywhere, isFalse);
      expect(back.folder, '/h/Documents');
      expect(SavedSearch.fromJson(null), isNull);
      expect(SavedSearch.fromJson({'query': 3}), isNull);
      expect(SavedSearch.fromJson({'query': ' '}), isNull);
      // A folder scope without a folder is This Computer.
      expect(
        SavedSearch.fromJson({'query': 'a', 'scope': 'folder'})!.everywhere,
        isTrue,
      );
    });

    test('files get unique names; a damaged file reads as null', () {
      const s = SavedSearch(query: 'a', everywhere: true);
      final dir = '${home.path}/Saved Searches';
      final a = writeSavedSearch(dir, 'Lemons/all', s)!;
      final b = writeSavedSearch(dir, 'Lemons/all', s)!;
      expect(a, '$dir/Lemons-all.search');
      expect(b, '$dir/Lemons-all 2.search');
      expect(SavedSearch.read(a)!.query, 'a');
      File(a).writeAsStringSync('{broken');
      expect(SavedSearch.read(a), isNull);
      expect(SavedSearch.read('$dir/missing.search'), isNull);
    });
  });

  Future<Settings> pumpWindow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings('${home.path}/.s.json')..view = 'icons';
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: home.path,
          places: [Place('silica', home.path, PlaceKind.home)],
          trash: Place('Trash', '${home.path}/Trash', PlaceKind.trash),
          settings: settings,
        ),
      ),
    );
    await tester.pump();
    return settings;
  }

  Future<void> shortcut(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
  }) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('⇧⌘G: the sheet, completion, Return goes there', (tester) async {
    await pumpWindow(tester);
    await shortcut(tester, LogicalKeyboardKey.keyG, shift: true);
    final sheet = find.byKey(const ValueKey('go to folder'));
    expect(sheet, findsOneWidget);
    // Kit: 460 × 212, 102 below the window's top, centred.
    final rect = tester.getRect(sheet);
    expect(rect.size, const Size(460, 212));
    expect(rect.top, 102);
    expect(rect.left, (1000 - 460) / 2);
    expect(
      tester.getSize(find.byKey(const ValueKey('go to folder field'))),
      const Size(396, 32),
    );
    await tester.enterText(find.byType(EditableText).last, '~/Documents/Pro');
    await tester.pump();
    expect(find.text('jects'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('go to folder suggestion 0'))),
      const Size(444, 28),
    );
    final name = home.path.split('/').last;
    expect(find.text('$name › Documents › Projects'), findsOneWidget);
    expect(find.text('$name › Documents › Promo'), findsOneWidget);
    // Down: the second one, Return goes to it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.text('mo'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.byKey(const ValueKey('go to folder')), findsNothing);
    expect(find.text('Promo'), findsWidgets);
  });

  testWidgets('Go to Folder: Esc closes, a missing folder says so', (
    tester,
  ) async {
    await pumpWindow(tester);
    await shortcut(tester, LogicalKeyboardKey.keyG, shift: true);
    await tester.enterText(find.byType(EditableText).last, '~/Nowhere');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Folder not found'), findsOneWidget);
    expect(find.byKey(const ValueKey('go to folder')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const ValueKey('go to folder')), findsNothing);
  });

  testWidgets('Save Search: sheet, file, sidebar row, and opening it again', (
    tester,
  ) async {
    File('${home.path}/Documents/lemon pie.txt').writeAsStringSync('x');
    final settings = await pumpWindow(tester);
    await shortcut(tester, LogicalKeyboardKey.keyF);
    await tester.enterText(find.byType(EditableText).last, 'lemon');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('save search button')));
    await tester.pump(const Duration(milliseconds: 400));
    final sheet = find.byKey(const ValueKey('save search'));
    expect(sheet, findsOneWidget);
    final rect = tester.getRect(sheet);
    expect(rect.size, const Size(413, 263));
    // Centred in the window (kit: 292, 188 in 1000 × 640).
    expect(rect.left, closeTo(293.5, 1));
    expect(rect.top, closeTo(188.5, 1));
    expect(find.text('Save this search'), findsOneWidget);
    expect(find.text('Search for lemon'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save search save')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('save search')), findsNothing);
    final file = File('${home.path}/Saved Searches/Search for lemon.search');
    expect(file.existsSync(), isTrue);
    expect(SavedSearch.read(file.path)!.query, 'lemon');
    expect(settings.savedSearches, [file.path]);
    // The sidebar has a row for it, selected while its search is on screen.
    expect(find.text('Saved Searches'), findsWidgets);
    expect(find.text('Search for lemon'), findsOneWidget);
    // Leave the search, then open the saved one from the sidebar.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.byKey(const ValueKey('scope bar')), findsNothing);
    await tester.tap(find.byKey(ValueKey('place search:${file.path}')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('scope bar')), findsOneWidget);
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(find.textContaining('lemon pie'), findsWidgets);
  });

  testWidgets(
    'Save Search: without text the button is disabled; Cancel keeps nothing',
    (tester) async {
      await pumpWindow(tester);
      await shortcut(tester, LogicalKeyboardKey.keyF);
      await tester.tap(find.byKey(const ValueKey('save search button')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('save search')), findsNothing);
      await tester.enterText(find.byType(EditableText).last, 'x');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('save search button')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('save search cancel')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('save search')), findsNothing);
      expect(Directory('${home.path}/Saved Searches').existsSync(), isFalse);
    },
  );
}
