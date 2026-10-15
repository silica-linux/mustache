import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/info.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    SilicaWindows.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SilicaWindow.channel, (call) async {
          calls.add(call);
          // The test view stands for the Info window's view.
          return call.method == 'openWindow' ? 0 : null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SilicaWindow.channel, null);
    SilicaWindows.reset();
  });

  testWidgets('⌘I opens Get Info as a child window, not inside the window', (
    tester,
  ) async {
    final home = Directory.systemTemp.createTempSync('mustache-info-window');
    addTearDown(() => home.deleteSync(recursive: true));
    final file = File('${home.path}/nota.txt')..writeAsStringSync('ciao');
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings('${home.path}/.s.json')..view = 'list';
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: home.path,
          places: [Place('casa', home.path, PlaceKind.home)],
          trash: Place('Trash', '${home.path}/Cestino', PlaceKind.trash),
          settings: settings,
        ),
      ),
    );
    await tester.tap(find.text('nota.txt'));
    await tester.pump(const Duration(milliseconds: 310));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    await tester.pump();

    final open = calls.where((c) => c.method == 'openWindow').single;
    final args = open.arguments as Map;
    expect(args['title'], 'nota.txt Info');
    expect(args['width'], infoWidth);
    expect(args['minWidth'], infoWidth);
    expect(args['maxWidth'], infoWidth);
    expect(args['kind'], 'utility');
    expect(args['parent'], 0);
    // The panel is the window's content, not drawn in the browser window.
    expect(find.byKey(ValueKey('info ${file.path}')), findsNothing);
    expect(SilicaWindows.open.value, hasLength(1));

    // ⌘I again on the same item: no second window.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(calls.where((c) => c.method == 'openWindow'), hasLength(1));

    // The window's content: the panel without its own frame and close button.
    final window = SilicaWindows.open.value.single;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: window.builder),
      ),
    );
    expect(find.byKey(ValueKey('info ${file.path}')), findsOneWidget);
    expect(find.byKey(const ValueKey('close info')), findsNothing);
    // The window follows its content's height.
    await tester.pump();
    final size = calls.lastWhere((c) => c.method == 'setSize');
    expect((size.arguments as Map)['width'], infoWidth);

    // Its close button: the window closes.
    await SilicaWindows.handle('closeRequested', {'viewId': 0});
    expect(calls.last.method, 'closeWindow');
  });
}
