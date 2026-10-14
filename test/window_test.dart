import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/sidebar.dart';
import 'package:mustache/src/toolbar.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
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
          trash: Place('Cestino', '${root.path}/Cestino', PlaceKind.trash),
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

    // The sidebar: 192 wide, the row text at 47 pt.
    expect(tester.getTopLeft(find.text('Prova').first).dx, sidebarTextLeft);

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
      Color? title() =>
          tester.widget<Text>(find.byKey(const ValueKey('title'))).style?.color;
      expect(title(), ToolbarColors.light.title);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(title(), ToolbarColors.light.titleInactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(title(), ToolbarColors.light.title);
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
    final back = tester.getCenter(find.byKey(const ValueKey('back')));
    final hold = await tester.startGesture(back, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 320));
    await hold.up();
    await tester.pump();
    // The previous place, in the menu below the segment; the click opens it.
    final name = root.path.split('/').last;
    final item = find.descendant(
      of: find.byType(MenuPanel),
      matching: find.text(name),
    );
    expect(item, findsOneWidget);
    final panel = tester.getRect(find.byType(MenuPanel));
    expect(panel.top, closeTo(7 + 38 - 2, 1));
    await tester.tap(item);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.text('nota.txt'), findsOneWidget);
  });

  testWidgets('the unified toolbar: capsules, views, Back', (tester) async {
    await pump(tester);
    // Back/Forward 7 pt from the sidebar, 38 tall with 7 pt above; the title 12 pt after.
    final nav = tester.getRect(find.byKey(const ValueKey('back and forward')));
    expect(nav, const Rect.fromLTWH(199, 7, 75, 38));
    expect(tester.getTopLeft(find.byKey(const ValueKey('title'))).dx, 286);
    expect(tester.getSize(find.byKey(const ValueKey('view group'))).width, 162);
    expect(tester.getTopRight(find.byKey(const ValueKey('search'))).dx, 993);

    await tester.tap(find.text('Alfa'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.text('dentro.txt'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('back')));
    await tester.pump();
    expect(find.text('nota.txt'), findsOneWidget);

    // The view group: the grid removes the column header.
    await tester.tap(find.byKey(const ValueKey('view icons')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('column header')), findsNothing);

    // With the sidebar hidden the toolbar leaves room for the window buttons.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('back and forward'))).dx,
      windowButtonsEnd + 7,
    );
  });
}
