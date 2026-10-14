import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/list_view.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mustache-elenco');
    Directory(
      '${root.path}/Annidata/Livello 2/Livello 3',
    ).createSync(recursive: true);
    File('${root.path}/Annidata/Livello 2/secondo.txt').writeAsStringSync('x');
    File(
      '${root.path}/Annidata/Livello 2/Livello 3/profondo.txt',
    ).writeAsStringSync('x');
    File('${root.path}/appunti.txt').writeAsStringSync('x' * 31);
    File('${root.path}/grande.bin').writeAsBytesSync(List.filled(3000, 0));
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: root.path,
          places: [Place('Prova', root.path, PlaceKind.home)],
          trash: Place('Cestino', '${root.path}/.Cestino', PlaceKind.trash),
          now: DateTime(2026, 10, 14, 12),
          settings: Settings(
            '${Directory.systemTemp.createTempSync('mustache-impostazioni').path}/s.json',
          )..view = 'list',
        ),
      ),
    );
  }

  Rect row(WidgetTester tester, String name) =>
      tester.getRect(find.byKey(ValueKey('${root.path}/$name')));

  testWidgets('measured geometry: header, 20 pt rows, columns', (tester) async {
    await pump(tester);
    final header = tester.getRect(find.byKey(const ValueKey('column header')));
    expect(header.top, 52);
    expect(header.height, listHeaderHeight + listHeaderLine);
    // The first row at y 85, then a 20 pitch.
    final first = row(tester, 'Annidata');
    expect(first.top, 85);
    expect(first.height, listRowHeight);
    expect(row(tester, 'appunti.txt').top, 105);
    // The name at x 47 from the edge of the content.
    final content = header.left;
    expect(tester.getTopLeft(find.text('Annidata')).dx - content, listNameLeft);
  });

  testWidgets(
    'the triangle expands without choosing; ⌥ expands the whole subtree',
    (tester) async {
      await pump(tester);
      final r = row(tester, 'Annidata');
      await tester.tapAt(Offset(r.left + 19, r.center.dy));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Livello 2'), findsOneWidget);
      expect(find.text('Livello 3'), findsNothing);
      // The row was not chosen: the name stays dark.
      final name = tester.widget<Text>(find.text('Annidata'));
      expect(name.style?.color, ListColors.light.name);
      // ⌥-click collapses; ⌥-click again expands everything.
      await tester.tapAt(Offset(r.left + 19, r.center.dy));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Livello 2'), findsNothing);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.tapAt(Offset(r.left + 19, r.center.dy));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Livello 3'), findsOneWidget);
      expect(find.text('profondo.txt'), findsOneWidget);
      // 15 pt indent per level.
      final x2 = tester.getTopLeft(find.text('Livello 2')).dx;
      final x3 = tester.getTopLeft(find.text('Livello 3')).dx;
      expect(x3 - x2, listIndent);
    },
  );

  testWidgets(
    'a click on the row chooses; on the empty rows it clears the choice',
    (tester) async {
      await pump(tester);
      final r = row(tester, 'appunti.txt');
      await tester.tapAt(r.center);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<Text>(find.text('appunti.txt')).style?.color,
        ListColors.light.selectionName,
      );
      await tester.tap(find.byKey(const ValueKey('empty row 10')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<Text>(find.text('appunti.txt')).style?.color,
        ListColors.light.name,
      );
    },
  );

  testWidgets('headers: Size starts from the largest, then reverses', (
    tester,
  ) async {
    await pump(tester);
    double y(String name) => tester.getTopLeft(find.text(name)).dy;
    await tester.tap(find.byKey(const ValueKey('header size')));
    await tester.pump();
    expect(y('grande.bin'), lessThan(y('appunti.txt')));
    await tester.tap(find.byKey(const ValueKey('header size')));
    await tester.pump();
    expect(y('grande.bin'), greaterThan(y('appunti.txt')));
    // Dragging the edge of Name widens the column.
    final before = tester.getTopLeft(find.textContaining('oggi, ').first).dx;
    await tester.drag(
      find.byKey(const ValueKey('edge name')),
      const Offset(40, 0),
    );
    await tester.pump();
    final after = tester.getTopLeft(find.textContaining('oggi, ').first).dx;
    expect(after - before, closeTo(40, 1));
  });

  testWidgets('presses (MU-25): the row and the triangle act on release', (
    tester,
  ) async {
    await pump(tester);
    Color? name() => tester.widget<Text>(find.text('appunti.txt')).style?.color;
    final press = await tester.startGesture(
      row(tester, 'appunti.txt').center,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(name(), ListColors.light.name);
    await press.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(name(), ListColors.light.selectionName);
    final triangle = find.byKey(ValueKey('triangle ${root.path}/Annidata'));
    final hold = await tester.startGesture(
      tester.getCenter(triangle),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(find.text('Livello 2'), findsNothing);
    await hold.up();
    await tester.pump();
    expect(find.text('Livello 2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('pressed header is filled; held long it does not sort', (
    tester,
  ) async {
    await pump(tester);
    double y(String name) => tester.getTopLeft(find.text(name)).dy;
    final before = y('grande.bin') < y('appunti.txt');
    final cell = find.byKey(const ValueKey('header size'));
    final hold = await tester.startGesture(tester.getCenter(cell));
    await tester.pump(const Duration(milliseconds: 150));
    final fill = tester.widget<ColoredBox>(
      find.descendant(of: cell, matching: find.byType(ColoredBox)).first,
    );
    expect(fill.color, ListColors.light.headerPressed);
    await tester.pump(const Duration(seconds: 1));
    await hold.up();
    await tester.pump();
    expect(y('grande.bin') < y('appunti.txt'), before);
    // The separator grip: 5 pt, 3 left of the line and 1 to the right.
    final grip = tester.getRect(find.byKey(const ValueKey('edge name')));
    expect(grip.width, 5);
    await tester.pump(const Duration(seconds: 5));
  });
}
