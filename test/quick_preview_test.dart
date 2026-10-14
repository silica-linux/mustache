import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/quick_preview.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';

void main() {
  test('panel sizes for images (spec 12)', () {
    expect(imagePanelSize(const Size(800, 600)), const Size(810, 643));
    expect(imagePanelSize(const Size(600, 900)), const Size(610, 943));
    // Small: minimum width.
    expect(imagePanelSize(const Size(320, 240)).width, quickPreviewMinWidth);
    // Large: fitted to the maximum height.
    final big = imagePanelSize(const Size(4000, 3000));
    expect(big.height, quickPreviewMaxHeight);
    expect(big.width, closeTo(1628, 2));
    // In a smaller window it shrinks proportionally.
    expect(
      fitPanel(const Size(800, 400), const Size(400, 400)),
      const Size(400, 200),
    );
    expect(isTextPreview('main.rs'), isTrue);
    expect(isTextPreview('foto.png'), isFalse);
  });

  testWidgets('Space opens and closes; Esc closes; the text shows', (
    tester,
  ) async {
    final home = Directory.systemTemp.createTempSync('mustache-anteprima');
    addTearDown(() => home.deleteSync(recursive: true));
    File('${home.path}/nota.txt').writeAsStringSync('riga di prova');
    Directory('${home.path}/Cartella').createSync();
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: home.path,
          places: [Place('casa', home.path, PlaceKind.home)],
          trash: Place('Trash', '${home.path}/Cestino', PlaceKind.trash),
          settings: Settings('${home.path}/s.json')..view = 'list',
        ),
      ),
    );
    final panel = find.byKey(const ValueKey('quick preview'));
    await tester.tap(find.text('nota.txt'));
    await tester.pump(const Duration(milliseconds: 310));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(panel, findsOneWidget);
    expect(find.text('riga di prova'), findsOneWidget);
    expect(tester.getSize(panel), quickPreviewText);
    // ↑: the folder, with the generic panel.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(tester.getSize(panel), quickPreviewGeneric);
    expect(
      // In the bar and beside the large icon.
      find.descendant(of: panel, matching: find.text('Cartella')),
      findsNWidgets(2),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(panel, findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(panel, findsNothing);
  });
}
