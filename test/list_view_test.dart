import 'dart:io';

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

  testWidgets('geometria misurata: intestazione, righe da 20, colonne', (
    tester,
  ) async {
    await pump(tester);
    final header = tester.getRect(
      find.byKey(const ValueKey('intestazione delle colonne')),
    );
    expect(header.top, 52);
    expect(header.height, listHeaderHeight + listHeaderLine);
    // La prima riga a y 85, poi passo 20.
    final first = row(tester, 'Annidata');
    expect(first.top, 85);
    expect(first.height, listRowHeight);
    expect(row(tester, 'appunti.txt').top, 105);
    // Il nome a x 47 dal bordo del contenuto.
    final content = header.left;
    expect(tester.getTopLeft(find.text('Annidata')).dx - content, listNameLeft);
  });

  testWidgets(
    'il triangolo apre senza scegliere; ⌥ apre tutto il sottoalbero',
    (tester) async {
      await pump(tester);
      final r = row(tester, 'Annidata');
      await tester.tapAt(Offset(r.left + 19, r.center.dy));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Livello 2'), findsOneWidget);
      expect(find.text('Livello 3'), findsNothing);
      // La riga non è stata scelta: il nome resta scuro.
      final name = tester.widget<Text>(find.text('Annidata'));
      expect(name.style?.color, ListColors.light.name);
      // ⌥clic chiude; ⌥clic di nuovo apre tutto.
      await tester.tapAt(Offset(r.left + 19, r.center.dy));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Livello 2'), findsNothing);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.tapAt(Offset(r.left + 19, r.center.dy));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Livello 3'), findsOneWidget);
      expect(find.text('profondo.txt'), findsOneWidget);
      // Rientro di 15 pt per livello.
      final x2 = tester.getTopLeft(find.text('Livello 2')).dx;
      final x3 = tester.getTopLeft(find.text('Livello 3')).dx;
      expect(x3 - x2, listIndent);
    },
  );

  testWidgets('clic sulla riga sceglie; sulle righe vuote toglie la scelta', (
    tester,
  ) async {
    await pump(tester);
    final r = row(tester, 'appunti.txt');
    await tester.tapAt(r.center);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<Text>(find.text('appunti.txt')).style?.color,
      ListColors.light.selectionName,
    );
    await tester.tap(find.byKey(const ValueKey('riga vuota 10')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<Text>(find.text('appunti.txt')).style?.color,
      ListColors.light.name,
    );
  });

  testWidgets('intestazioni: Dimensioni parte dal più grande, poi si inverte', (
    tester,
  ) async {
    await pump(tester);
    double y(String name) => tester.getTopLeft(find.text(name)).dy;
    await tester.tap(find.byKey(const ValueKey('intestazione size')));
    await tester.pump();
    expect(y('grande.bin'), lessThan(y('appunti.txt')));
    await tester.tap(find.byKey(const ValueKey('intestazione size')));
    await tester.pump();
    expect(y('grande.bin'), greaterThan(y('appunti.txt')));
    // Trascinando il bordo di Nome la colonna si allarga.
    final before = tester.getTopLeft(find.textContaining('oggi, ').first).dx;
    await tester.drag(
      find.byKey(const ValueKey('bordo name')),
      const Offset(40, 0),
    );
    await tester.pump();
    final after = tester.getTopLeft(find.textContaining('oggi, ').first).dx;
    expect(after - before, closeTo(40, 1));
  });
}
