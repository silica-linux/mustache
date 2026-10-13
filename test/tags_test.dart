import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/sidebar.dart';
import 'package:mustache/src/tags.dart';
import 'package:mustache/src/window.dart';
import 'package:mustache/src/xattr.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  test('nomi e colori', () {
    expect(tagName(TagColor.red), 'Rosso');
    expect(tagColor('Verde'), TagColor.green);
    expect(tagColor('Lavoro'), isNull);
    expect(menuTagColor(TagColor.red), const Color(0xFFFF6663));
    final ring = tagRing(menuTagColor(TagColor.red));
    expect(
      ring.computeLuminance(),
      lessThan(menuTagColor(TagColor.red).computeLuminance()),
    );
  });

  testWidgets('cerchio del menu assegna l\'etichetta; la barra la ritrova', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GlassRegistry.channel, (call) async => true);
    // Sotto la home: /tmp può non avere gli attributi user.
    final home = Directory(
      '${Platform.environment['HOME']}/.cache',
    ).createTempSync('mustache-etichette');
    addTearDown(() => home.deleteSync(recursive: true));
    final file = File('${home.path}/Doc/nota.txt')..createSync(recursive: true);
    if (!writeTags(file.path, [])) {
      markTestSkipped('niente attributi estesi su questo disco');
      return;
    }
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: '${home.path}/Doc',
          places: [Place('casa', home.path, PlaceKind.home)],
          trash: Place('Cestino', '${home.path}/Cestino', PlaceKind.trash),
          settings: Settings('${home.path}/s.json')..view = 'list',
        ),
      ),
    );
    final row = find.descendant(
      of: find.byType(ListView),
      matching: find.text('nota.txt'),
    );
    await tester.tapAt(tester.getCenter(row), buttons: kSecondaryMouseButton);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('etichetta Verde')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(readTags(file.path), ['Verde']);
    // Il pallino davanti al nome.
    expect(find.byType(TagDots), findsOneWidget);

    // La barra laterale: "Verde" mostra gli elementi con l'etichetta.
    await tester.tap(
      find.descendant(of: find.byType(Sidebar), matching: find.text('Verde')),
    );
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(row, findsOneWidget);
    // Il titolo è il nome dell'etichetta.
    expect(
      find.descendant(of: find.byType(Sidebar), matching: find.text('Verde')),
      findsOneWidget,
    );
    // Di nuovo il cerchio: toglie.
    await tester.tapAt(tester.getCenter(row), buttons: kSecondaryMouseButton);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('etichetta Verde')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(readTags(file.path), isEmpty);
  });
}
