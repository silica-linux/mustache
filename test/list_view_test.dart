import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/list_view.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

import 'kit.dart';

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
          trash: Place('Trash', '${root.path}/.Cestino', PlaceKind.trash),
          // The files are made now: their dates read "Today, …".
          now: DateTime.now(),
          settings: Settings(
            '${Directory.systemTemp.createTempSync('mustache-impostazioni').path}/s.json',
          )..view = 'list',
        ),
      ),
    );
  }

  Rect row(WidgetTester tester, String name) =>
      tester.getRect(find.byKey(ValueKey('${root.path}/$name')));

  testWidgets('geometry of the kit List master: header, 28 pt rows, columns', (
    tester,
  ) async {
    await pump(tester);
    final kit = loadKit('List');
    final header = tester.getRect(find.byKey(const ValueKey('column header')));
    expect(header.top, kit.rect('Header').top);
    expect(header.height, kit.rect('Header').height);
    // The first row follows the header, then a 28 pitch.
    final first = row(tester, 'Annidata');
    expect(first.top, kit.rect('Desktop').top);
    expect(first.height, kit.rect('Desktop').height);
    expect(row(tester, 'appunti.txt').top - first.top, 28);
    // Kit `List Row`: the name at x 44 and the cells at 340, 520 and 620, from the content edge.
    final content = header.left;
    final master = loadKit('List Row/Even');
    expect(
      tester.getTopLeft(find.text('Annidata')).dx - content,
      master.rect('Name').left,
    );
    final today = tester.getTopLeft(find.textContaining('Today, ').first).dx;
    expect(today - content, master.rect('Date').left);
    // The header labels sit over the columns: Name at 44, Date Modified at 340.
    final headers = loadKit('List Header');
    expect(
      tester.getTopLeft(find.text('Name')).dx - content,
      headers.rect('Name').left,
    );
    expect(
      tester.getTopLeft(find.text('Date Modified')).dx - content,
      headers.rect('Date').left,
    );
    // The stripe of an odd row runs across the whole width.
    final odd = tester.getRect(
      find
          .descendant(
            of: find.byKey(ValueKey('${root.path}/appunti.txt')),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(odd.width, first.width);
  });

  testWidgets(
    'the triangle expands without choosing; ⌥ expands the whole subtree',
    (tester) async {
      await pump(tester);
      final r = row(tester, 'Annidata');
      await tester.tapAt(Offset(r.left + 10, r.center.dy));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Livello 2'), findsOneWidget);
      expect(find.text('Livello 3'), findsNothing);
      // The row was not chosen: the name stays dark.
      final name = tester.widget<Text>(find.text('Annidata'));
      expect(name.style?.color, AmalfiColors.light.textPrimary);
      // ⌥-click collapses; ⌥-click again expands everything.
      await tester.tapAt(Offset(r.left + 10, r.center.dy));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Livello 2'), findsNothing);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.tapAt(Offset(r.left + 10, r.center.dy));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Livello 3'), findsOneWidget);
      expect(find.text('profondo.txt'), findsOneWidget);
      // 16 pt indent per level.
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
        AmalfiColors.light.textOnAccent,
      );
      await tester.tap(find.byKey(const ValueKey('empty row 10')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<Text>(find.text('appunti.txt')).style?.color,
        AmalfiColors.light.textPrimary,
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
    final before = tester.getTopLeft(find.textContaining('Today, ').first).dx;
    await tester.drag(
      find.byKey(const ValueKey('edge name')),
      const Offset(40, 0),
    );
    await tester.pump();
    final after = tester.getTopLeft(find.textContaining('Today, ').first).dx;
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
    expect(name(), AmalfiColors.light.textPrimary);
    await press.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(name(), AmalfiColors.light.textOnAccent);
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
    expect(fill.color, AmalfiColors.light.lineSeparator);
    await tester.pump(const Duration(seconds: 1));
    await hold.up();
    await tester.pump();
    expect(y('grande.bin') < y('appunti.txt'), before);
    // The edge grip: 5 pt, 3 left of the boundary and 2 to the right.
    final grip = tester.getRect(find.byKey(const ValueKey('edge name')));
    expect(grip.width, 5);
    await tester.pump(const Duration(seconds: 5));
  });
}
