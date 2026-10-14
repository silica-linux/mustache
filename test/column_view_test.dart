import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/column_view.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/tags.dart';
import 'package:mustache/src/window.dart';

void main() {
  test('catena delle colonne dalla radice alla cartella aperta', () {
    expect(columnChain('/home/io', '/home/io/Documenti/Lettere'), [
      '/home/io',
      '/home/io/Documenti',
      '/home/io/Documenti/Lettere',
    ]);
    expect(columnChain('/home/io', '/home/io'), ['/home/io']);
    expect(columnChain('/', '/etc'), ['/', '/etc']);
    // Fuori dalla radice: la sola cartella.
    expect(columnChain('/home/io', '/tmp'), ['/tmp']);
    // Un prefisso che non è una cartella madre non conta.
    expect(columnChain('/home/io', '/home/ionico'), ['/home/ionico']);
  });

  group('nella finestra', () {
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
              'Cestino',
              '${home.path}/.local/share/Trash/files',
              PlaceKind.trash,
            ),
            settings: Settings('${home.path}/.config/s.json')..view = 'columns',
          ),
        ),
      );
    }

    Finder column(String dir) => find.byKey(ValueKey('colonna $dir'));

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
          : (boxes.first.decoration as BoxDecoration).color;
    }

    testWidgets('una cartella scelta apre la sua colonna; selezione attenuata a '
        'sinistra; frecce', (tester) async {
      await pump(tester);
      expect(column(home.path), findsOneWidget);
      final docs = '${home.path}/Documenti';
      await tester.tap(find.text('Documenti'));
      await tester.pump();
      expect(column(docs), findsOneWidget);
      expect(fillOf(tester, docs), const Color(0xFF0064E1));
      // La colonna è a 245 pt dalla prima.
      expect(
        tester.getTopLeft(column(docs)).dx -
            tester.getTopLeft(column(home.path)).dx,
        columnPitch,
      );
      // → entra: la prima voce della cartella (Lettere), e Documenti diventa grigio.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      final letters = '$docs/Lettere';
      expect(fillOf(tester, letters), const Color(0xFF0064E1));
      expect(fillOf(tester, docs), const Color(0xFFDCDCDC));
      expect(column(letters), findsOneWidget);
      // ↓ passa a nota.txt (stessa colonna): la colonna di Lettere sparisce.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(fillOf(tester, '$docs/nota.txt'), const Color(0xFF0064E1));
      expect(column(letters), findsNothing);
      // ← torna alla cartella a sinistra.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(fillOf(tester, docs), const Color(0xFF0064E1));
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('⌘3 passa alle colonne', (tester) async {
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

  testWidgets('nomi troncati al centro e punti delle etichette (mu22-root)', (
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
          tagsOf: (e) => e.name == 'etichettato.txt' ? ['Blu', 'Rosso'] : [],
        ),
      ),
    );
    final beta = tester.widget<Text>(find.textContaining('Beta con un'));
    expect(beta.data, contains('…'));
    expect(beta.data, endsWith('colonna'));
    expect(find.byType(TagDots), findsOneWidget);
  });

  testWidgets('la cartella aperta resta in vista in una colonna lunga', (
    tester,
  ) async {
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
