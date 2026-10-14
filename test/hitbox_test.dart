// Le zone di clic della finestra: ogni controllo riceve i clic su tutta la sua area, fino ai
// bordi, e niente passa a quello che c'è dietro o accanto.

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/list_view.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/status_bar.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  late Directory root;
  late List<String> calls;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mustache-zone');
    Directory('${root.path}/Alfa').createSync();
    for (var i = 0; i < 40; i++) {
      File('${root.path}/file $i.txt').writeAsStringSync('x');
    }
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SilicaWindow.channel, (call) async {
          calls.add(call.method);
          return null;
        });
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<Settings> pump(WidgetTester tester, {String view = 'list'}) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings =
        Settings(
            '${Directory.systemTemp.createTempSync('mustache-impostazioni').path}/s.json',
          )
          ..view = view
          ..statusBar = true
          ..pathBar = true;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: root.path,
          places: [Place('Prova', root.path, PlaceKind.home)],
          trash: Place('Cestino', '${root.path}/.Cestino', PlaceKind.trash),
          settings: settings,
        ),
      ),
    );
    await tester.pump();
    return settings;
  }

  Color nameColor(WidgetTester tester, String name) => tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('elenco')),
          matching: find.text(name),
        ),
      )
      .style!
      .color!;

  testWidgets('segmenti della barra: tutto il segmento, fino ai bordi', (
    tester,
  ) async {
    await pump(tester);
    for (final (key, mode) in [
      ('vista icons', 'icons'),
      ('vista gallery', 'gallery'),
      ('vista columns', 'columns'),
      ('vista list', 'list'),
    ]) {
      final rect = tester.getRect(find.byKey(ValueKey(key)));
      // A 1 pt dal bordo sinistro e dal destro, in alto e in basso.
      for (final p in [
        rect.topLeft + const Offset(1, 1),
        rect.bottomRight - const Offset(1, 1),
      ]) {
        await tester.tapAt(p);
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          find.byKey(const ValueKey('intestazione delle colonne')),
          mode == 'list' ? findsOneWidget : findsNothing,
          reason: '$key a $p',
        );
      }
    }
    // Il vuoto della barra sposta la finestra; il clic su un segmento no.
    expect(calls, isNot(contains('startMove')));
    final title = tester.getRect(find.byKey(const ValueKey('titolo')));
    final gesture = await tester.startGesture(
      Offset(title.right - 4, title.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(30, 0));
    await gesture.up();
    await tester.pump();
    expect(calls, contains('startMove'));
  });

  testWidgets('la barra di stato non passa i clic all\'elenco dietro', (
    tester,
  ) async {
    await pump(tester);
    final bar = tester.getRect(find.byKey(const ValueKey('barra di stato')));
    final path = tester.getRect(
      find.byKey(const ValueKey('barra del percorso')),
    );
    // Scelgo una riga, poi clic sulla barra di stato e su quella del percorso (fuori dai
    // segmenti): la scelta resta.
    await tester.tap(find.text('file 0.txt'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(nameColor(tester, 'file 0.txt'), ListColors.light.selectionName);
    await tester.tapAt(Offset(bar.left + 40, bar.center.dy));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(Offset(path.right - 20, path.center.dy));
    await tester.pump(const Duration(milliseconds: 400));
    expect(nameColor(tester, 'file 0.txt'), ListColors.light.selectionName);
    // L'elenco finisce sopra la barra del percorso: l'ultima riga visibile non ci finisce sotto.
    final list = tester.getRect(find.byKey(const ValueKey('elenco')));
    expect(list.bottom, lessThanOrEqualTo(path.top));
    expect(path.bottom, lessThanOrEqualTo(bar.top));
  });

  testWidgets('cursore delle icone: tutta la barra del cursore', (
    tester,
  ) async {
    final settings = await pump(tester, view: 'icons');
    final slider = tester.getRect(
      find.byKey(const ValueKey('cursore delle icone')),
    );
    await tester.tapAt(Offset(slider.right - 2, slider.center.dy));
    await tester.pump();
    expect(settings.iconSide, iconSideFor(112));
    await tester.tapAt(Offset(slider.left + 2, slider.top + 2));
    await tester.pump();
    expect(settings.iconSide, lessThan(20));
  });

  testWidgets(
    'bordo della barra laterale: 3 pt per parte, l\'elenco subito dopo',
    (tester) async {
      await pump(tester);
      final header = tester.getRect(
        find.byKey(const ValueKey('intestazione delle colonne')),
      );
      final edge = header.left;
      // Trascinando a 2 pt dal bordo, dentro il contenuto, la barra si allarga.
      await tester.dragFrom(
        Offset(edge + 2, 300),
        const Offset(40, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      final wider = tester.getRect(
        find.byKey(const ValueKey('intestazione delle colonne')),
      );
      expect(wider.left, greaterThan(edge + 30));
      // A 4 pt dal bordo è già l'elenco: la riga di Alfa (il triangolo parte da x 11).
      await tester.tapAt(Offset(wider.left + 4, wider.bottom + 14));
      await tester.pump(const Duration(milliseconds: 400));
      expect(nameColor(tester, 'Alfa'), ListColors.light.selectionName);
      await tester.tapAt(Offset(wider.left + 60, wider.bottom + 34));
      await tester.pump(const Duration(milliseconds: 400));
      expect(nameColor(tester, 'file 0.txt'), ListColors.light.selectionName);
    },
  );

  testWidgets('intestazione: l\'etichetta fino al separatore, poi la presa', (
    tester,
  ) async {
    await pump(tester);
    final date = tester.getRect(
      find.byKey(const ValueKey('intestazione modified')),
    );
    // A 5 pt dalla fine della colonna Data ordina per data (la presa è di 4 pt).
    await tester.tapAt(Offset(date.right - 5, date.center.dy));
    await tester.pump();
    expect(
      tester.widget<CustomPaint>(
        find.byKey(const ValueKey('freccia di ordinamento')),
      ),
      isNotNull,
    );
    final arrow = tester.getRect(
      find.byKey(const ValueKey('freccia di ordinamento')),
    );
    expect(arrow.right, closeTo(date.right - 7, 0.5));
  });
}
