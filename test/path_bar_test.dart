import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/path_bar.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';

void main() {
  test('segmenti dal disco alla cartella', () {
    expect(pathSegments('/home/io/Documenti'), [
      '/',
      '/home',
      '/home/io',
      '/home/io/Documenti',
    ]);
    expect(pathSegments('/'), ['/']);
  });

  test('restringimento: intermedi uguali, poi il primo, poi il penultimo', () {
    const natural = [107.0, 80.0, 120.0, 95.0, 77.0, 93.0];
    // Ci stanno: nessun cambiamento.
    expect(pathBarWidths(natural, 1000), natural);
    // Poco spazio: si stringono gli intermedi, a un tetto comune; primo e ultimo interi.
    final a = pathBarWidths(natural, 520);
    expect(a.first, 107);
    expect(a.last, 93);
    expect(a.fold(0.0, (x, y) => x + y), closeTo(520, 1));
    // I due più larghi scendono allo stesso tetto; quello già più stretto resta.
    expect(a[2], closeTo(a[3], 0.01));
    expect(a[1], 80);
    // Molto poco: intermedi al minimo, poi il primo.
    final b = pathBarWidths(natural, 300);
    for (final w in b.sublist(1, 4)) {
      expect(w, pathSegmentMin);
    }
    expect(b.first, lessThan(107));
    expect(b.last, 93);
    // Ancora meno: anche il penultimo, ma mai sotto 29.
    final c = pathBarWidths(natural, 200);
    expect(c.every((w) => w >= pathSegmentMin), isTrue);
    expect(c[4], lessThan(77));
    expect(c.last, 93);
  });

  testWidgets('⌥⌘P mostra la barra; un clic su un segmento apre la cartella', (
    tester,
  ) async {
    final home = Directory.systemTemp.createTempSync('mustache-percorso');
    addTearDown(() => home.deleteSync(recursive: true));
    Directory('${home.path}/Documenti/Lettere').createSync(recursive: true);
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings('${home.path}/s.json')..view = 'list';
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: '${home.path}/Documenti/Lettere',
          places: [Place('casa', home.path, PlaceKind.home)],
          trash: Place('Cestino', '${home.path}/Cestino', PlaceKind.trash),
          settings: settings,
        ),
      ),
    );
    expect(find.byKey(const ValueKey('barra del percorso')), findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    final bar = find.byKey(const ValueKey('barra del percorso'));
    expect(bar, findsOneWidget);
    expect(tester.getSize(bar).height, pathBarHeight);
    expect(settings.pathBar, isTrue);
    await tester.tap(find.byKey(ValueKey('segmento ${home.path}/Documenti')));
    await tester.pump();
    expect(find.text('Lettere'), findsOneWidget);
  });
}
