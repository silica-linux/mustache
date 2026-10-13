import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/tabs.dart';
import 'package:mustache/src/window.dart';

void main() {
  testWidgets('⌘T apre una scheda; la barra compare con due; ⌃⇥ e ⌘W', (
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
            trash: Place('Cestino', '${home.path}/Cestino', PlaceKind.trash),
            settings: settings,
            tabBar: bar,
            onLocation: onLocation,
            focused: active,
          ),
        ),
      ),
    );
    await tester.pump();
    final bar = find.byKey(const ValueKey('barra delle schede'));
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
    // Le scorciatoie della finestra arrivano alla scheda nuova (⌘3: colonne, ⌘2: elenco).
    await keys(LogicalKeyboardKey.digit3, meta: true);
    expect(settings.view, 'columns');
    await keys(LogicalKeyboardKey.digit2, meta: true);
    expect(settings.view, 'list');
    // Nella seconda scheda si entra in Alfa: la prima resta nella home.
    await tester.tap(find.text('Alfa/'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Alfa/'));
    await tester.pump();
    await tester.pump();
    final host = tester.state<TabsHostState>(find.byType(TabsHost));
    expect(host.tabs.map((t) => displayName(t.location)), [
      displayName(home.path),
      'Alfa',
    ]);
    // ⌃⇥: la prima scheda, ancora nella home.
    await keys(LogicalKeyboardKey.tab, control: true);
    expect(host.active, 0);
    expect(find.text('Beta/'), findsOneWidget);
    // ⌘W chiude la scheda attiva: resta Alfa, la barra sparisce.
    await keys(LogicalKeyboardKey.keyW, meta: true);
    expect(host.tabs.length, 1);
    expect(bar, findsNothing);
    expect(find.text('Cartella vuota'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
  });
}
