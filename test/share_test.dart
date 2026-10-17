// The Share button of the preview toolbar (silica-desktop#217).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';

void main() {
  late Directory home;
  late List<MethodCall> calls;

  setUp(() {
    home = Directory.systemTemp.createTempSync('mustache-share');
    File('${home.path}/a.txt').writeAsStringSync('a');
    calls = [];
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('silica/dbus', JSONMethodCodec()),
          null,
        );
    home.deleteSync(recursive: true);
  });

  /// The window with the preview pane, and a fake share service (null: none).
  Future<void> pump(WidgetTester tester, {required bool service}) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('silica/dbus', JSONMethodCodec()),
          (call) async {
            calls.add(call);
            if (!service) throw MissingPluginException();
            final args = call.arguments as Map;
            return args['method'] == 'Targets'
                ? [
                    jsonEncode([
                      {'id': 'copy', 'name': 'Copy', 'icon': ''},
                      {'id': 'dev.frascella.Mail', 'name': 'Mail', 'icon': ''},
                    ]),
                  ]
                : [true];
          },
        );
    final settings = Settings('${home.path}/.s.json')
      ..view = 'icons'
      ..previewPane = true;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: home.path,
          places: [Place('home', home.path, PlaceKind.home)],
          trash: Place('Trash', '${home.path}/Trash', PlaceKind.trash),
          settings: settings,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The Share segment of the Share · Tags · Actions capsule: the first third of it.
  Offset shareSegment(WidgetTester tester) {
    final capsule = tester.getRect(
      find.byKey(const ValueKey('share tags actions')),
    );
    return capsule.topLeft + Offset(capsule.width / 6, capsule.height / 2);
  }

  testWidgets('Share is enabled for a selection and shares it', (tester) async {
    await pump(tester, service: true);
    // Nothing selected: Share does nothing.
    await tester.tapAt(shareSegment(tester));
    await tester.pumpAndSettle();
    expect(find.text('Mail'), findsNothing);
    await tester.tap(find.byKey(ValueKey('${home.path}/a.txt')));
    await tester.pumpAndSettle();
    await tester.tapAt(shareSegment(tester));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    expect(find.text('Mail'), findsOneWidget);
    await tester.tap(find.text('Mail'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    final share = calls
        .map((c) => c.arguments as Map)
        .lastWhere((a) => a['method'] == 'Share');
    expect(share['args'], [
      'dev.frascella.Mail',
      ['file://${home.path}/a.txt'],
    ]);
  });

  testWidgets('without the share service Share stays disabled', (tester) async {
    await pump(tester, service: false);
    await tester.tap(find.byKey(ValueKey('${home.path}/a.txt')));
    await tester.pumpAndSettle();
    expect(calls, isNotEmpty);
    await tester.tapAt(shareSegment(tester));
    await tester.pumpAndSettle();
    expect(find.text('Mail'), findsNothing);
    expect(find.text('Copy'), findsNothing);
  });
}
