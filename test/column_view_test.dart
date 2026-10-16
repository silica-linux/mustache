import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';
import 'package:mustache/src/column_view.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/tags.dart';
import 'package:mustache/src/window.dart';

void main() {
  test('chain of columns from the root to the open folder', () {
    expect(columnChain('/home/io', '/home/io/Documenti/Lettere'), [
      '/home/io',
      '/home/io/Documenti',
      '/home/io/Documenti/Lettere',
    ]);
    expect(columnChain('/home/io', '/home/io'), ['/home/io']);
    expect(columnChain('/', '/etc'), ['/', '/etc']);
    // Outside the root: the folder alone.
    expect(columnChain('/home/io', '/tmp'), ['/tmp']);
    // A prefix that is not a parent folder does not count.
    expect(columnChain('/home/io', '/home/ionico'), ['/home/ionico']);
  });

  group('in the window', () {
    late Directory home;

    setUp(() {
      home = Directory.systemTemp.createTempSync('mustache-colonne');
      Directory('${home.path}/Documenti/Lettere').createSync(recursive: true);
      File('${home.path}/Documenti/Lettere/cara.txt').writeAsStringSync('x');
      File('${home.path}/Documenti/nota.txt').writeAsStringSync('x');
      File('${home.path}/primo.txt').writeAsStringSync('x');
    });

    tearDown(() => home.deleteSync(recursive: true));

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MustacheWindow(
            start: home.path,
            places: [Place('casa', home.path, PlaceKind.home)],
            trash: Place(
              'Trash',
              '${home.path}/.local/share/Trash/files',
              PlaceKind.trash,
            ),
            settings: Settings('${home.path}/.config/s.json')..view = 'columns',
          ),
        ),
      );
    }

    Finder column(String dir) => find.byKey(ValueKey('column $dir'));

    Color? fillOf(WidgetTester tester, String path) {
      final boxes = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byKey(ValueKey(path)),
              matching: find.byType(DecoratedBox),
            ),
          )
          .toList();
      return boxes.isEmpty
          ? null
          : (boxes.first.decoration as ShapeDecoration).color;
    }

    testWidgets('a chosen folder opens its column; dimmed selection on the '
        'left; arrows', (tester) async {
      await pump(tester);
      expect(column(home.path), findsOneWidget);
      final docs = '${home.path}/Documenti';
      await tester.tap(find.text('Documenti'));
      await tester.pump();
      expect(column(docs), findsOneWidget);
      expect(fillOf(tester, docs), AmalfiColors.light.accentAmalfi);
      // The column is 240 pt from the first one (kit `Columns`).
      expect(
        tester.getTopLeft(column(docs)).dx -
            tester.getTopLeft(column(home.path)).dx,
        columnPitch,
      );
      // → enters: the first entry of the folder (Lettere), and Documenti turns gray.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      final letters = '$docs/Lettere';
      expect(fillOf(tester, letters), AmalfiColors.light.accentAmalfi);
      expect(fillOf(tester, docs), AmalfiColors.light.lineSeparator);
      expect(column(letters), findsOneWidget);
      // ↓ moves to nota.txt (same column): the column of Lettere disappears.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(fillOf(tester, '$docs/nota.txt'), AmalfiColors.light.accentAmalfi);
      expect(column(letters), findsNothing);
      // ← goes back to the folder on the left.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(fillOf(tester, docs), AmalfiColors.light.accentAmalfi);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('⌘3 switches to columns', (tester) async {
      await pump(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(find.byType(ColumnView), findsNothing);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(find.byType(ColumnView), findsOneWidget);
    });
  });

  testWidgets('names truncated in the middle and tag dots (MU-22)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Entry entry(String name, {bool dir = false}) => Entry(
      name: name,
      path: '/prova/$name',
      isDirectory: dir,
      size: 1,
      modified: DateTime(2026),
    );
    final entries = [
      entry(
        'Beta con un nome molto lungo che non entra nella colonna',
        dir: true,
      ),
      entry('etichettato.txt'),
    ];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ColumnView(
          root: '/prova',
          current: '/prova',
          leaf: '/prova',
          list: (_) => entries,
          onSelect: (_, _) {},
          onOpen: (_) {},
          tagsOf: (e) => e.name == 'etichettato.txt' ? ['Blue', 'Red'] : [],
        ),
      ),
    );
    final beta = tester.widget<Text>(find.textContaining('Beta con un'));
    expect(beta.data, contains('…'));
    expect(beta.data, endsWith('colonna'));
    expect(find.byType(TagDots), findsOneWidget);
  });

  testWidgets('the open folder stays in view in a long column', (tester) async {
    tester.view.physicalSize = const Size(1000, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Entry entry(String path, {bool dir = false}) => Entry(
      name: path.split('/').last,
      path: path,
      isDirectory: dir,
      size: 1,
      modified: DateTime(2026),
    );
    final parent = [
      for (var i = 0; i < 60; i++) entry('/r/file $i'),
      entry('/r/zeta', dir: true),
    ];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ColumnView(
          root: '/r',
          current: '/r/zeta',
          leaf: '/r/zeta',
          list: (dir) => dir == '/r' ? parent : [entry('/r/zeta/dentro')],
          onSelect: (_, _) {},
          onOpen: (_) {},
        ),
      ),
    );
    await tester.pump();
    final zeta = find.byKey(const ValueKey('/r/zeta'));
    expect(zeta, findsOneWidget);
    expect(tester.getRect(zeta).bottom, lessThanOrEqualTo(400));
  });
}
