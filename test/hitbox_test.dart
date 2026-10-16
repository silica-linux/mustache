// The click areas of the window: every control receives clicks over its whole area, up to the
// edges, and nothing goes through to what is behind or beside it.

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/status_bar.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  late Directory root;
  late List<String> calls;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mustache-zone');
    Directory('${root.path}/Alfa').createSync();
    for (var i = 0; i < 40; i++) {
      File('${root.path}/file $i.txt').writeAsStringSync('x');
    }
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SilicaWindow.channel, (call) async {
          calls.add(call.method);
          return null;
        });
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<Settings> pump(WidgetTester tester, {String view = 'list'}) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings =
        Settings(
            '${Directory.systemTemp.createTempSync('mustache-impostazioni').path}/s.json',
          )
          ..view = view
          ..statusBar = true
          ..pathBar = true;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: root.path,
          places: [Place('Prova', root.path, PlaceKind.home)],
          trash: Place('Trash', '${root.path}/.Cestino', PlaceKind.trash),
          settings: settings,
        ),
      ),
    );
    await tester.pump();
    return settings;
  }

  Color nameColor(WidgetTester tester, String name) => tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('list')),
          matching: find.text(name),
        ),
      )
      .style!
      .color!;

  testWidgets('toolbar segments: the whole segment, up to the edges', (
    tester,
  ) async {
    await pump(tester);
    for (final (key, mode) in [
      ('Icons', 'icons'),
      ('Gallery', 'gallery'),
      ('Columns', 'columns'),
      ('List', 'list'),
    ]) {
      // 1 pt from the left and right edges, at the top and at the bottom (the toolbar changes with
      // the view: the preview pane takes the search field, so the segments are measured again).
      for (final corner in [true, false]) {
        final rect = tester.getRect(find.bySemanticsLabel(key));
        final p = corner
            ? rect.topLeft + const Offset(1, 1)
            : rect.bottomRight - const Offset(1, 1);
        await tester.tapAt(p);
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          find.byKey(const ValueKey('column header')),
          mode == 'list' ? findsOneWidget : findsNothing,
          reason: '$key at $p',
        );
      }
    }
    // A click on a segment does not move the window.
    expect(calls, isNot(contains('startMove')));
    Future<void> drag(Offset from) async {
      final gesture = await tester.startGesture(
        from,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(30, 0));
      await gesture.up();
      await tester.pump();
    }

    // MU-08: not from the title; from the empty space beside it, from the top of the sidebar and
    // from the status bar, yes.
    final title = tester.getRect(find.byKey(const ValueKey('title')));
    await drag(Offset(title.right - 4, title.center.dy));
    expect(calls, isNot(contains('startMove')));
    await drag(Offset(title.right + 20, title.center.dy));
    expect(calls.where((c) => c == 'startMove'), hasLength(1));
    await drag(const Offset(100, 30));
    expect(calls.where((c) => c == 'startMove'), hasLength(2));
    final status = tester.getRect(find.byKey(const ValueKey('status bar')));
    await drag(status.center + const Offset(-200, 0));
    expect(calls.where((c) => c == 'startMove'), hasLength(3));
  });

  testWidgets('the status bar does not pass clicks to the list behind', (
    tester,
  ) async {
    await pump(tester);
    final bar = tester.getRect(find.byKey(const ValueKey('status bar')));
    final path = tester.getRect(find.byKey(const ValueKey('path bar')));
    // I choose a row, then click on the status bar and on the path bar (outside the segments): the
    // choice stays.
    await tester.tap(find.text('file 0.txt'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(nameColor(tester, 'file 0.txt'), AmalfiColors.light.textOnAccent);
    await tester.tapAt(Offset(bar.left + 40, bar.center.dy));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(Offset(path.right - 20, path.center.dy));
    await tester.pump(const Duration(milliseconds: 400));
    expect(nameColor(tester, 'file 0.txt'), AmalfiColors.light.textOnAccent);
    // The list ends above the path bar: the last visible row does not end up under it.
    final list = tester.getRect(find.byKey(const ValueKey('list')));
    expect(list.bottom, lessThanOrEqualTo(path.top));
    expect(path.bottom, lessThanOrEqualTo(bar.top));
  });

  testWidgets('icon slider: the whole slider bar', (tester) async {
    final settings = await pump(tester, view: 'icons');
    final slider = tester.getRect(find.byKey(const ValueKey('icon slider')));
    // The thumb's lens is part of the control: the ends of the track are a few points inside.
    await tester.tapAt(Offset(slider.right - 4, slider.center.dy));
    await tester.pump();
    expect(settings.iconSide, greaterThan(iconSideFor(100)));
    await tester.tapAt(Offset(slider.left + 4, slider.center.dy));
    await tester.pump();
    expect(settings.iconSide, lessThan(iconSideFor(12)));
  });

  testWidgets('sidebar edge: 3 pt per side, the list right after', (
    tester,
  ) async {
    await pump(tester);
    final header = tester.getRect(find.byKey(const ValueKey('column header')));
    final edge = header.left;
    // Dragging 2 pt from the edge, inside the content, widens the sidebar.
    await tester.dragFrom(
      Offset(edge + 2, 300),
      const Offset(40, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    final wider = tester.getRect(find.byKey(const ValueKey('column header')));
    expect(wider.left, greaterThan(edge + 30));
    // 4 pt from the edge it is already the list: the row of a file (a folder has its chevron
    // there).
    await tester.tapAt(Offset(wider.left + 4, wider.bottom + 42));
    await tester.pump(const Duration(milliseconds: 400));
    expect(nameColor(tester, 'file 0.txt'), AmalfiColors.light.textOnAccent);
    await tester.tapAt(Offset(wider.left + 60, wider.bottom + 14));
    await tester.pump(const Duration(milliseconds: 400));
    expect(nameColor(tester, 'Alfa'), AmalfiColors.light.textOnAccent);
  });

  testWidgets('header: the label up to the separator, then the grip', (
    tester,
  ) async {
    await pump(tester);
    final date = tester.getRect(find.byKey(const ValueKey('header modified')));
    // 5 pt from the end of the Date column it sorts by date (the grip is 5 pt, 3 left of the edge).
    await tester.tapAt(Offset(date.right - 5, date.center.dy));
    await tester.pump();
    expect(find.byKey(const ValueKey('sort arrow')), findsOneWidget);
    final arrow = tester.getRect(find.byKey(const ValueKey('sort arrow')));
    expect(arrow.size, const Size(12, 12));
    expect(arrow.right, lessThan(date.right - 4));
  });
}
