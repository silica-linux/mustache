import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';

void main() {
  testWidgets('⌘F cerca nel nome e nel contenuto; Esc svuota; ⌘[ esce', (
    tester,
  ) async {
    final home = Directory.systemTemp.createTempSync('mustache-ricerca');
    addTearDown(() => home.deleteSync(recursive: true));
    Directory('${home.path}/Doc/Profondo').createSync(recursive: true);
    File(
      '${home.path}/Doc/Profondo/bilancio annuale.txt',
    ).writeAsStringSync('x');
    File(
      '${home.path}/Doc/lettera.txt',
    ).writeAsStringSync('il bilancio è pronto');
    File('${home.path}/Doc/altro.txt').writeAsStringSync('niente');
    Directory('${home.path}/.nascosta').createSync();
    File('${home.path}/.nascosta/bilancio.txt').writeAsStringSync('x');
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: '${home.path}/Doc',
          places: [Place('casa', home.path, PlaceKind.home)],
          trash: Place('Cestino', '${home.path}/Cestino', PlaceKind.trash),
          settings: Settings('${home.path}/.s.json')..view = 'icons',
        ),
      ),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.byKey(const ValueKey('campo di ricerca')), findsOneWidget);
    expect(find.byKey(const ValueKey('barra dell\'ambito')), findsOneWidget);
    expect(find.text('Ricerca in «Questo computer»'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).last, 'bilancio');
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    // Per nome (in profondità) e per contenuto; non dentro le cartelle nascoste.
    expect(find.text('bilancio annuale.txt'), findsOneWidget);
    expect(find.text('lettera.txt'), findsOneWidget);
    expect(find.text('altro.txt'), findsNothing);
    expect(find.textContaining('.nascosta'), findsNothing);

    // Esc: il campo si svuota, la finestra resta in ricerca.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const ValueKey('barra dell\'ambito')), findsOneWidget);
    expect(find.text('lettera.txt'), findsNothing);

    // ⌘[: torna alla cartella.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.byKey(const ValueKey('barra dell\'ambito')), findsNothing);
    // Di nuovo la vista a icone (il nome può andare a capo).
    expect(find.textContaining('lettera'), findsWidgets);
  });
}
