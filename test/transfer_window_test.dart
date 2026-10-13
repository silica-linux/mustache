import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/transfer.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  late Directory home;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GlassRegistry.channel, (call) async => true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
    home = Directory.systemTemp.createTempSync('mustache-incolla');
    Directory('${home.path}/A').createSync();
    Directory('${home.path}/B').createSync();
    File('${home.path}/A/nota.txt').writeAsStringSync('ciao');
    FileClipboard.paths = const [];
  });

  tearDown(() => home.deleteSync(recursive: true));

  Future<void> pump(WidgetTester tester, String start) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: start,
          places: [Place('casa', home.path, PlaceKind.home)],
          trash: Place('Cestino', '${home.path}/Cestino', PlaceKind.trash),
          settings: Settings('${home.path}/s.json')..view = 'list',
        ),
      ),
    );
  }

  Future<void> keys(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool alt = false,
  }) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(key);
    if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  }

  /// Lascia finire l'I/O vero della copia.
  Future<void> settle(WidgetTester tester) async {
    // L'I/O vero finisce fuori dal tempo finto; i suoi seguiti girano a ogni pump.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('⌘C e ⌘V copiano; un conflitto chiede, Mantieni entrambi', (
    tester,
  ) async {
    await pump(tester, '${home.path}/A');
    await tester.tap(find.text('nota.txt'));
    await tester.pump(const Duration(milliseconds: 310));
    await keys(tester, LogicalKeyboardKey.keyC);
    expect(FileClipboard.paths, ['${home.path}/A/nota.txt']);
    // Nella stessa cartella: "nota copia.txt".
    await keys(tester, LogicalKeyboardKey.keyV);
    await settle(tester);
    expect(File('${home.path}/A/nota copia.txt').readAsStringSync(), 'ciao');
    // In B due volte: la seconda è un conflitto.
    await tester.tap(find.text('casa'));
    await tester.pump();
    await tester.tap(find.text('B/'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('B/'));
    await tester.pump();
    await keys(tester, LogicalKeyboardKey.keyV);
    await settle(tester);
    expect(File('${home.path}/B/nota.txt').existsSync(), isTrue);
    await keys(tester, LogicalKeyboardKey.keyV);
    await settle(tester);
    expect(
      find.byKey(const ValueKey('finestra del conflitto')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('conflitto Mantieni entrambi')));
    await settle(tester);
    expect(File('${home.path}/B/nota 2.txt').existsSync(), isTrue);
    expect(find.byKey(const ValueKey('finestra del conflitto')), findsNothing);
  });

  testWidgets('⌥⌘V sposta; ⌘Z lo rimette', (tester) async {
    FileClipboard.paths = ['${home.path}/A/nota.txt'];
    await pump(tester, '${home.path}/B');
    await keys(tester, LogicalKeyboardKey.keyV, alt: true);
    await settle(tester);
    expect(File('${home.path}/B/nota.txt').existsSync(), isTrue);
    expect(File('${home.path}/A/nota.txt').existsSync(), isFalse);
    await keys(tester, LogicalKeyboardKey.keyZ);
    await tester.pump();
    expect(File('${home.path}/A/nota.txt').existsSync(), isTrue);
  });
}
