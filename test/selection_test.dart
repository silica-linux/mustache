import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/icon_view.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';

void main() {
  late Directory home;
  late Directory config;

  setUp(() {
    home = Directory.systemTemp.createTempSync('mustache-selezione');
    config = Directory.systemTemp.createTempSync('mustache-sel-config');
    for (var i = 1; i <= 15; i++) {
      File(
        '${home.path}/f${i.toString().padLeft(2, '0')}.txt',
      ).writeAsStringSync('x');
    }
  });

  tearDown(() {
    home.deleteSync(recursive: true);
    config.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: home.path,
          places: [Place('casa', home.path, PlaceKind.home)],
          trash: Place('Cestino', '${home.path}/Cestino', PlaceKind.trash),
          settings: Settings('${config.path}/s.json')..view = 'icons',
          iconsEnv: {'SILICA_ICONS_DIR': config.path},
        ),
      ),
    );
  }

  Set<String> selectedNames(WidgetTester tester) => {
    for (final e in tester.widget<IconView>(find.byType(IconView)).selected)
      e.split('/').last,
  };

  Finder label(String name) =>
      find.descendant(of: find.byType(IconView), matching: find.text(name));

  testWidgets('⇧ e frecce: intervallo lineare dall\'àncora (R7.6)', (
    tester,
  ) async {
    await pump(tester);
    final columns = iconGrid(
      tester.getSize(find.byType(IconView)).width,
    ).columns;
    await tester.tap(label('f01.txt'));
    await tester.pump(const Duration(milliseconds: 310));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(selectedNames(tester), {'f01.txt', 'f02.txt', 'f03.txt'});
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    // Da 3 all'elemento sotto: tutto l'intervallo lineare 1…3+colonne.
    expect(selectedNames(tester).length, 3 + columns);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    // Sulla prima riga ↑ non fa nulla: resta 1…3.
    expect(selectedNames(tester), {'f01.txt', 'f02.txt', 'f03.txt'});
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  });

  testWidgets('⇧clic nella vista a icone aggiunge o toglie (R7.3)', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(label('f01.txt'));
    await tester.pump(const Duration(milliseconds: 310));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(label('f04.txt'));
    await tester.pump(const Duration(milliseconds: 310));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(selectedNames(tester), {'f01.txt', 'f04.txt'});
  });

  testWidgets(
    'rettangolo dal vuoto: seleziona dal vivo e sparisce al rilascio',
    (tester) async {
      await pump(tester);
      final view = tester.getRect(find.byType(IconView));
      final start = view.bottomRight - const Offset(10, 10);
      final mouse = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await mouse.moveBy(const Offset(-5, -5));
      await tester.pump();
      await mouse.moveTo(tester.getCenter(label('f01.txt')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('rettangolo di selezione')),
        findsOneWidget,
      );
      expect(selectedNames(tester).length, 15);
      await mouse.up();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('rettangolo di selezione')),
        findsNothing,
      );
      expect(selectedNames(tester).length, 15);
    },
  );
}
