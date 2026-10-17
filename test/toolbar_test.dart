import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

// The adaptive toolbar (mustache#21, kit `Apps/Mustache/Toolbar`): what each width shows and that
// every control of it works.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mustache-toolbar');
    File('${root.path}/nota.txt').writeAsStringSync('testo');
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<void> pump(WidgetTester tester, {required double width}) async {
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: root.path,
          places: [Place('Prova', root.path, PlaceKind.home)],
          trash: Place('Trash', '${root.path}/Cestino', PlaceKind.trash),
          settings: Settings(
            '${Directory.systemTemp.createTempSync('mustache-s').path}/s.json',
          )..view = 'list',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  testWidgets('wide: permanent field, view group, capsule; no circle', (
    tester,
  ) async {
    await pump(tester, width: 1300);
    expect(key('permanent search'), findsOneWidget);
    expect(key('search button'), findsNothing);
    expect(key('view group'), findsOneWidget);
    expect(key('share tags actions'), findsOneWidget);
  });

  testWidgets('the circle grows into the field, Esc collapses it', (
    tester,
  ) async {
    await pump(tester, width: 1000);
    expect(key('search button'), findsOneWidget);
    await tester.tap(key('search button'));
    await tester.pump(const Duration(milliseconds: 20));
    // Mid-growth: wider than the circle, narrower than the field.
    final growing = tester.getSize(key('search field slot')).width;
    expect(growing, inInclusiveRange(36, 240));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(key('search field slot')).width, 240);
    expect(key('search button'), findsNothing);
    // The field has the focus at once: typing goes into it, and search starts.
    await tester.enterText(find.byType(EditableText).last, 'nota');
    await tester.pump(const Duration(milliseconds: 300));
    expect(key('scope bar'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(key('scope bar'), findsNothing);
    expect(key('search button'), findsOneWidget);
  });

  testWidgets('a click in the content collapses an empty field', (
    tester,
  ) async {
    await pump(tester, width: 1000);
    await tester.tap(key('search button'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(key('search field slot'), findsOneWidget);
    await tester.tapAt(const Offset(700, 400));
    await tester.pumpAndSettle();
    expect(key('search button'), findsOneWidget);
  });

  testWidgets('the view pop-up opens the view menu and chooses a view', (
    tester,
  ) async {
    // Narrow enough for the pop-up (below the Full state).
    await pump(tester, width: 800);
    expect(key('view group'), findsNothing);
    final popUp = find.bySemanticsLabel('View');
    expect(popUp, findsOneWidget);
    final gesture = await tester.startGesture(
      tester.getCenter(popUp),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AmalfiMenu), findsOneWidget);
    expect(find.text('List'), findsOneWidget);
    await tester.tap(find.text('List'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(key('column header'), findsOneWidget);
  });

  testWidgets('Actions opens the folder menu without a selection', (
    tester,
  ) async {
    await pump(tester, width: 1000);
    final capsule = tester.getRect(key('share tags actions'));
    await tester.tapAt(capsule.topLeft + Offset(capsule.width * 5 / 6, 18));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AmalfiMenu), findsOneWidget);
    expect(find.text('New Folder'), findsOneWidget);
  });

  testWidgets('Tags needs a selection, then opens its popover', (tester) async {
    await pump(tester, width: 1000);
    final capsule = tester.getRect(key('share tags actions'));
    final tags = capsule.topLeft + Offset(capsule.width / 2, 18);
    await tester.tapAt(tags);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Show All…'), findsNothing);
    await tester.tap(find.text('nota.txt'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(tags);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tags'), findsWidgets);
    final list = find.byType(AmalfiPopoverList);
    expect(
      find.descendant(of: list, matching: find.text('Red')),
      findsOneWidget,
    );
    expect(find.text('Show All…'), findsOneWidget);
    // Show All… keeps the popover open with every colour.
    await tester.tap(find.text('Show All…'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.descendant(of: list, matching: find.text('Gray')),
      findsOneWidget,
    );
    expect(find.text('Show All…'), findsNothing);
  });

  testWidgets('narrow: Tags and Actions go into the » menu', (tester) async {
    await pump(tester, width: 740);
    // 740 - 240 = 500: below the pop-up state, Share stays beside ».
    expect(key('share tags actions'), findsNothing);
    expect(find.bySemanticsLabel('More'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('More'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tags…'), findsOneWidget);
    expect(find.text('Actions'), findsOneWidget);
  });
}
