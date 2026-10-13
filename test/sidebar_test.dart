import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/sidebar.dart';
import 'package:mustache/src/window.dart';

/// Un testo dentro la barra laterale (la vista a icone mostra gli stessi nomi).
Finder inSidebar(String text) =>
    find.descendant(of: find.byType(Sidebar), matching: find.text(text));

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mustache-barra');
    for (final name in ['Documenti', 'Download']) {
      Directory('${root.path}/$name').createSync();
    }
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<Settings> pump(WidgetTester tester, {Settings? settings}) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final used = settings ?? Settings('${root.path}/settings.json');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: root.path,
          places: [
            Place('casa', root.path, PlaceKind.home),
            Place('Documenti', '${root.path}/Documenti', PlaceKind.documents),
            Place('Download', '${root.path}/Download', PlaceKind.downloads),
          ],
          trash: Place('Cestino', '${root.path}/Cestino', PlaceKind.trash),
          settings: used,
        ),
      ),
    );
    return used;
  }

  double centerY(WidgetTester tester, Finder finder) =>
      tester.getCenter(finder).dy;

  testWidgets('righe a passo 32, intestazioni a 24 e 40 dalle righe', (
    tester,
  ) async {
    await pump(tester);
    final heading = centerY(tester, inSidebar('Preferiti'));
    final documents = centerY(tester, inSidebar('Documenti'));
    final downloads = centerY(tester, inSidebar('Download'));
    final places = centerY(tester, inSidebar('Posizioni'));
    expect(documents - heading, closeTo(sidebarHeadingToRow, 0.5));
    expect(downloads - documents, sidebarRow);
    expect(places - downloads, closeTo(sidebarRowToHeading, 0.5));
    expect(documents, sidebarFirstRowCenter);
    // La riga della cartella mostrata è selezionata, con il testo in semibold.
    final selection = tester.getRect(
      find.byKey(const ValueKey('selezione della barra')),
    );
    expect(selection.left, sidebarSelectionInset);
    expect(selection.height, sidebarRow);
    final home = tester.widget<Text>(inSidebar('casa'));
    expect(home.style?.fontWeight, FontWeight.w600);
  });

  test('larghezza: minimo, contenuto minimo, aggancio a 200, nascosta', () {
    expect(dragWidth(100, 1000), sidebarMinWidth);
    expect(dragWidth(900, 1000), 1000 - contentMinWidth);
    expect(dragWidth(300, 1000), 300);
    expect(dragWidth(60, 1000), 0);
    expect(releaseWidth(195), sidebarSnapWidth);
    expect(releaseWidth(209), sidebarSnapWidth);
    expect(releaseWidth(190), 190);
    expect(releaseWidth(212), 212);
  });

  testWidgets('trascinare il bordo cambia la larghezza e la ricorda', (
    tester,
  ) async {
    final settings = await pump(tester);
    final divider = find.byKey(const ValueKey('bordo della barra'));
    final gesture = await tester.startGesture(tester.getCenter(divider));
    await gesture.moveBy(const Offset(60, 0));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(tester.getCenter(divider).dx, closeTo(sidebarDefaultWidth + 100, 1));
    expect(settings.sidebarWidth, closeTo(sidebarDefaultWidth + 100, 1));
    // Una finestra nuova parte dalla stessa larghezza (il file sul disco).
    expect(
      Settings(settings.path).sidebarWidth,
      closeTo(sidebarDefaultWidth + 100, 1),
    );

    // Rilasciata vicino a 200 si aggancia a 200.
    final again = await tester.startGesture(tester.getCenter(divider));
    await again.moveBy(const Offset(-50, 0));
    await again.moveBy(const Offset(-45, 0));
    await tester.pump();
    await again.up();
    await tester.pump();
    expect(tester.getCenter(divider).dx, closeTo(sidebarSnapWidth, 1));
  });

  testWidgets('⌃⌘S nasconde la barra in ~240 ms e la rimostra', (tester) async {
    await pump(tester);
    Future<void> toggle() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    }

    final divider = find.byKey(const ValueKey('bordo della barra'));
    await toggle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final half = tester.getCenter(divider).dx;
    expect(half, inExclusiveRange(40, 160));
    await tester.pump(const Duration(milliseconds: 130));
    expect(tester.getCenter(divider).dx, 0);
    await toggle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    // Il mostrare parte con ~40 ms di ritardo.
    expect(tester.getCenter(divider).dx, 0);
    await tester.pump(const Duration(milliseconds: 260));
    expect(tester.getCenter(divider).dx, sidebarDefaultWidth);
  });

  testWidgets('il chevron dell\'intestazione comprime e riapre la sezione', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('comprimi Preferiti')), findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(inSidebar('Preferiti')));
    await tester.pump();
    // Compare subito, senza ritardo.
    final chevron = find.byKey(const ValueKey('comprimi Preferiti'));
    expect(chevron, findsOneWidget);
    final placesBefore = centerY(tester, inSidebar('Posizioni'));
    await tester.tap(chevron);
    await tester.pump();
    // Il testo delle righe sparisce subito; il movimento parte dopo ~70 ms.
    expect(inSidebar('Documenti'), findsNothing);
    await tester.pump(const Duration(milliseconds: 60));
    expect(centerY(tester, inSidebar('Posizioni')), placesBefore);
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      centerY(tester, inSidebar('Posizioni')),
      closeTo(placesBefore - 2 * sidebarRow, 0.5),
    );
    // Riaperta: torna com'era.
    await tester.tap(find.byKey(const ValueKey('comprimi Preferiti')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    expect(centerY(tester, inSidebar('Posizioni')), placesBefore);
    expect(inSidebar('Documenti'), findsOneWidget);
  });

  test('impostazioni rovinate o illeggibili valgono come predefinite', () {
    final file = File('${root.path}/rotto.json')..writeAsStringSync('{non è');
    expect(Settings(file.path).sidebarWidth, isNull);
    file.writeAsStringSync('{"sidebarWidth": "largo"}');
    expect(Settings(file.path).sidebarWidth, isNull);
    // Una cartella al posto del file: si scrive senza errori, vale per la sessione.
    Directory('${root.path}/cartella.json').createSync();
    final settings = Settings('${root.path}/cartella.json')..sidebarWidth = 250;
    expect(settings.sidebarWidth, 250);
  });

  test('i simboli della barra stanno in symbols/regular', () {
    expect(symbolFor(PlaceKind.downloads), 'arrow-down-circle');
    expect(accentIcon(PlaceKind.documents), isTrue);
    expect(accentIcon(PlaceKind.trash), isFalse);
  });
}
