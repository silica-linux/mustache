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
  test('names and colors', () {
    expect(tagName(TagColor.red), 'Red');
    expect(tagColor('Green'), TagColor.green);
    expect(tagColor('Lavoro'), isNull);
    expect(menuTagColor(TagColor.red), const Color(0xFFFF6663));
    final ring = tagRing(menuTagColor(TagColor.red));
    expect(
      ring.computeLuminance(),
      lessThan(menuTagColor(TagColor.red).computeLuminance()),
    );
  });

  testWidgets('the menu circle assigns the tag; the sidebar finds it again', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GlassRegistry.channel, (call) async => true);
    // Under home: /tmp may not support user attributes.
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
          trash: Place('Trash', '${home.path}/Cestino', PlaceKind.trash),
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
    await tester.tap(find.byKey(const ValueKey('tag green')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(readTags(file.path), ['Green']);
    // The dot before the name.
    expect(find.byType(TagDots), findsOneWidget);

    // The sidebar: "Green" shows the items with the tag.
    await tester.tap(
      find.descendant(of: find.byType(Sidebar), matching: find.text('Green')),
    );
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(row, findsOneWidget);
    // The title is the tag name.
    expect(
      find.descendant(of: find.byType(Sidebar), matching: find.text('Green')),
      findsOneWidget,
    );
    // The circle again: removes.
    await tester.tapAt(tester.getCenter(row), buttons: kSecondaryMouseButton);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tag green')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(readTags(file.path), isEmpty);
  });
}
