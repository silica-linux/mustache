import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/toolbar.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

import 'kit.dart';

void main() {
  test('the minimum window keeps the window buttons clear', () {
    expect(minimumWindowSize, const Size(556, 252));
  });

  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mustache');
    Directory('${root.path}/Alfa').createSync();
    File('${root.path}/Alfa/dentro.txt').writeAsStringSync('ciao');
    File('${root.path}/nota.txt').writeAsStringSync('testo');
    File('${root.path}/.nascosto').writeAsStringSync('x');
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<List<String>> pump(WidgetTester tester) async {
    final opened = <String>[];
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: root.path,
          places: [Place('Prova', root.path, PlaceKind.home)],
          trash: Place('Trash', '${root.path}/Cestino', PlaceKind.trash),
          now: DateTime(2026, 10, 13, 12),
          open: opened.add,
          // The list view (the default is icons).
          settings: Settings(
            '${Directory.systemTemp.createTempSync('mustache-impostazioni').path}/s.json',
          )..view = 'list',
        ),
      ),
    );
    return opened;
  }

  testWidgets('lists the folder, opens folders and goes back', (tester) async {
    final opened = await pump(tester);
    expect(find.text('Alfa'), findsOneWidget);
    expect(find.text('nota.txt'), findsOneWidget);
    expect(find.text('.nascosto'), findsNothing);

    // The sidebar: 240 wide, the row label 36 pt from the row (12 from the edge).
    expect(tester.getTopLeft(find.text('Prova').first).dx, 12 + 36);

    await tester.tap(find.text('Alfa'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Alfa'));
    await tester.pumpAndSettle();
    expect(find.text('dentro.txt'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(find.text('nota.txt'), findsOneWidget);

    // A file opens with the default app.
    await tester.tap(find.text('nota.txt'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('nota.txt'));
    await tester.pumpAndSettle();
    expect(opened, ['${root.path}/nota.txt']);
  });

  testWidgets('arrows, ⌘↓ to open, ⌘⇧. for hidden files', (tester) async {
    await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(find.text('dentro.txt'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.period);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(find.text('.nascosto'), findsOneWidget);
  });

  testWidgets('a click on the header reverses the sort', (tester) async {
    await pump(tester);
    double y(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(y('Alfa'), lessThan(y('nota.txt')));
    await tester.tap(find.byKey(const ValueKey('header name')));
    await tester.pump();
    expect(y('Alfa'), greaterThan(y('nota.txt')));
  });

  testWidgets(
    'the window inactive for Ossido (flutter/lifecycle) dims the title',
    (tester) async {
      await pump(tester);
      final colors = AmalfiColors.light;
      Color? title() => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('title')),
              matching: find.byType(Text),
            ),
          )
          .style
          ?.color;
      expect(title(), colors.textPrimary);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(title(), colors.textTertiary);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(title(), colors.textPrimary);
    },
  );

  testWidgets('long press on Back: the history menu', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Alfa'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.text('dentro.txt'), findsOneWidget);
    final nav = tester.getRect(find.byKey(const ValueKey('back and forward')));
    final hold = await tester.startGesture(
      Offset(nav.left + 16, nav.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 600));
    // The previous place, in the menu below the segment (its bottom left corner).
    final name = root.path.split('/').last;
    final item = find.descendant(
      of: find.byType(AmalfiMenu),
      matching: find.text(name),
    );
    expect(item, findsOneWidget);
    final panel = tester.getRect(find.byType(AmalfiMenu));
    expect(panel.left, nav.left);
    expect(panel.top, nav.bottom);
    // Releasing over the item chooses it.
    await hold.moveTo(tester.getCenter(item));
    await hold.up();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.byType(AmalfiMenu), findsNothing);
    expect(find.text('nota.txt'), findsOneWidget);
  });

  testWidgets(
    'releasing on Back with the history menu open closes it (MU-07)',
    (tester) async {
      await pump(tester);
      await tester.tap(find.text('Alfa'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(find.text('dentro.txt'), findsOneWidget);
      final nav = tester.getRect(
        find.byKey(const ValueKey('back and forward')),
      );
      final hold = await tester.startGesture(
        Offset(nav.left + 16, nav.center.dy),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(AmalfiMenu), findsOneWidget);
      await hold.up();
      await tester.pump(const Duration(milliseconds: 300));
      // Closed, and the window did not navigate.
      expect(find.byType(AmalfiMenu), findsNothing);
      expect(find.text('dentro.txt'), findsOneWidget);
      expect(find.text('nota.txt'), findsNothing);
    },
  );

  testWidgets('the toolbar: pieces at the frames of the kit Toolbar Icons', (
    tester,
  ) async {
    await pump(tester);
    final kit = loadKit('Toolbar Icons');
    // The content section starts at x 240, 52 tall; the controls are inside their pieces (4 pt).
    final bar = tester.getRect(find.byKey(const ValueKey('toolbar')));
    expect(bar, Rect.fromLTWH(240, 0, 760, 52));
    Rect inBar(Finder f) => tester.getRect(f).shift(-bar.topLeft);
    final nav = inBar(find.byKey(const ValueKey('back and forward')));
    final navPiece = kit.rect('Nav');
    expect(nav.left, navPiece.left + 4);
    expect(nav.size, const Size(64, 32));
    expect(nav.top, 10);
    final views = inBar(find.byKey(const ValueKey('view group')));
    final viewsPiece = kit.rect('Segmented 4');
    expect(views.left, viewsPiece.left + 4);
    expect(views.width, viewsPiece.width - 8);
    expect(views.height, 32);
    final search = inBar(find.byKey(const ValueKey('search field')));
    final searchPiece = kit.rect('Search');
    expect(search.left, searchPiece.left + 4);
    expect(search.right, searchPiece.right - 4);
    expect(
      inBar(find.byKey(const ValueKey('title'))).left,
      kit.rect('Title').left,
    );

    await tester.tap(find.text('Alfa'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.text('dentro.txt'), findsOneWidget);
    await tester.tapAt(
      tester
              .getRect(find.byKey(const ValueKey('back and forward')))
              .centerLeft +
          const Offset(16, 0),
    );
    await tester.pump();
    expect(find.text('nota.txt'), findsOneWidget);

    // The view group: the grid removes the column header.
    await tester.tap(find.bySemanticsLabel('Icons'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('column header')), findsNothing);

    // With the sidebar hidden the toolbar leaves room for the window buttons.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    // The content section starts with the slot of the window buttons (96, 12 of it the section's
    // padding) and the toggle (40), then the 4 pt of the nav piece.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('back and forward'))).dx,
      12 + (windowControlsSlot - 12) + 40 + 4,
    );
  });
}
