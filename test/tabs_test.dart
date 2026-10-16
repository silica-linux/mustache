import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/tabs.dart';
import 'package:mustache/src/window.dart';

import 'kit.dart';

void main() {
  testWidgets('⌘T opens a tab; the bar appears with two; ⌃⇥ and ⌘W', (
    tester,
  ) async {
    final home = Directory.systemTemp.createTempSync('mustache-schede');
    addTearDown(() => home.deleteSync(recursive: true));
    Directory('${home.path}/Alfa').createSync();
    Directory('${home.path}/Beta').createSync();
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = Settings('${home.path}/.s.json')..view = 'list';
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: TabsHost(
          start: home.path,
          build: (tab, bar, onLocation, active) => MustacheWindow(
            start: tab.location,
            places: [Place('casa', home.path, PlaceKind.home)],
            trash: Place('Trash', '${home.path}/Cestino', PlaceKind.trash),
            settings: settings,
            tabBar: bar,
            onLocation: onLocation,
            focused: active,
          ),
        ),
      ),
    );
    await tester.pump();
    final bar = find.byKey(const ValueKey('tab bar'));
    expect(bar, findsNothing);

    Future<void> keys(
      LogicalKeyboardKey key, {
      bool meta = false,
      bool control = false,
      bool shift = false,
    }) async {
      if (meta) await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      if (control)
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(key);
      if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      if (meta) await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      await tester.pump();
    }

    await keys(LogicalKeyboardKey.keyT, meta: true);
    expect(bar, findsOneWidget);
    // Kit `Apps/Mustache/Tab Bar`: 36 tall, the first tab 8 from the left and 4 from the top,
    // 28 tall; the new-tab button 24 pt, 8 from the right and 6 from the top.
    final kit = loadKit('Tab Bar');
    final barRect = tester.getRect(bar);
    final first = tester
        .getRect(find.byKey(const ValueKey('tab 0')))
        .shift(-barRect.topLeft);
    expect(barRect.height, kit.size.height);
    expect(first.left, kit.rect('Tab 1').left);
    expect(first.top, kit.rect('Tab 1').top);
    expect(first.height, kit.rect('Tab 1').height);
    final plus = tester.getRect(find.byKey(const ValueKey('new tab')));
    expect(plus.size, kit.rect('New tab').size);
    expect(barRect.right - plus.right, 8);
    expect(plus.top - barRect.top, kit.rect('New tab').top);
    // The window shortcuts reach the new tab (⌘3: columns, ⌘2: list).
    await keys(LogicalKeyboardKey.digit3, meta: true);
    expect(settings.view, 'columns');
    await keys(LogicalKeyboardKey.digit2, meta: true);
    expect(settings.view, 'list');
    // In the second tab Alfa is entered: the first stays in home.
    await tester.tap(find.text('Alfa'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Alfa'));
    await tester.pump();
    await tester.pump();
    final host = tester.state<TabsHostState>(find.byType(TabsHost));
    expect(host.tabs.map((t) => displayName(t.location)), [
      displayName(home.path),
      'Alfa',
    ]);
    // ⌃⇥: the first tab, still in home.
    await keys(LogicalKeyboardKey.tab, control: true);
    expect(host.active, 0);
    expect(find.text('Beta'), findsOneWidget);
    // ⌘W closes the active tab: Alfa remains, the bar disappears.
    await keys(LogicalKeyboardKey.keyW, meta: true);
    expect(host.tabs.length, 1);
    expect(bar, findsNothing);
    // An empty folder shows no text (R3.10): the title says it.
    expect(tester.widget<Text>(titleText()).data, 'Alfa');
    await tester.pump(const Duration(milliseconds: 500));
  });
}
