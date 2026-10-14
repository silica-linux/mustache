import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/gallery_view.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';

void main() {
  testWidgets('⌘4: galleria con la striscia e il pannello; → avanza', (
    tester,
  ) async {
    final home = Directory.systemTemp.createTempSync('mustache-galleria');
    addTearDown(() => home.deleteSync(recursive: true));
    for (var i = 1; i <= 4; i++) {
      File('${home.path}/f$i.txt').writeAsStringSync('$i');
    }
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings('${home.path}/.s.json')..view = 'list';
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: home.path,
          places: [Place('casa', home.path, PlaceKind.home)],
          trash: Place('Cestino', '${home.path}/Cestino', PlaceKind.trash),
          settings: settings,
        ),
      ),
    );
    await tester.tap(find.text('f1.txt'));
    await tester.pump(const Duration(milliseconds: 310));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.byType(GalleryView), findsOneWidget);
    expect(settings.view, 'gallery');
    expect(
      tester.getSize(find.byKey(const ValueKey('pannello di anteprima'))).width,
      250,
    );
    GalleryView gallery() =>
        tester.widget<GalleryView>(find.byType(GalleryView));
    expect(gallery().selected, '${home.path}/f1.txt');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(gallery().selected, '${home.path}/f2.txt');
    // Clic su una miniatura.
    await tester.tap(find.byKey(ValueKey('miniatura ${home.path}/f4.txt')));
    await tester.pump(const Duration(milliseconds: 310));
    expect(gallery().selected, '${home.path}/f4.txt');
    final thumbs = tester.getRect(
      find.byKey(const ValueKey('striscia delle miniature')),
    );
    expect(thumbs.height, galleryStrip + 12);
  });

  testWidgets(
    'senza scelta la galleria sceglie il primo; l\'icona riempie l\'anteprima',
    (tester) async {
      final home = Directory.systemTemp.createTempSync('mustache-galleria');
      addTearDown(() => home.deleteSync(recursive: true));
      Directory('${home.path}/Alfa').createSync();
      File('${home.path}/b.txt').writeAsStringSync('b');
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = Settings('${home.path}/.s.json')..view = 'gallery';
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MustacheWindow(
            start: home.path,
            places: [Place('casa', home.path, PlaceKind.home)],
            trash: Place('Cestino', '${home.path}/Cestino', PlaceKind.trash),
            settings: settings,
          ),
        ),
      );
      await tester.pump();
      // Il pannello descrive la cartella scelta (mu23-gallery-folder).
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pannello di anteprima')),
          matching: find.text('Alfa'),
        ),
        findsOneWidget,
      );
      // L'icona grande è quanto il lato corto dell'anteprima (non 256 fissi).
      final big = tester.getSize(
        find.byKey(const ValueKey('anteprima grande')),
      );
      expect(big.shortestSide, greaterThan(400));
    },
  );
}
