import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';

void main() {
  testWidgets('⌘F searches name and content; Esc clears; ⌘[ leaves', (
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
    expect(find.byKey(const ValueKey('search field')), findsOneWidget);
    expect(find.byKey(const ValueKey('scope bar')), findsOneWidget);
    expect(find.text('Ricerca in «Questo computer»'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).last, 'bilancio');
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    // By name (in depth) and by content; not inside hidden folders.
    expect(find.text('bilancio annuale.txt'), findsOneWidget);
    expect(find.text('lettera.txt'), findsOneWidget);
    expect(find.text('altro.txt'), findsNothing);
    expect(find.textContaining('.nascosta'), findsNothing);

    // Esc: the field is cleared, the window stays in search.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const ValueKey('scope bar')), findsOneWidget);
    expect(find.text('lettera.txt'), findsNothing);

    // ⌘[: back to the folder.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.byKey(const ValueKey('scope bar')), findsNothing);
    // The icon view again (the name may wrap).
    expect(find.textContaining('lettera'), findsWidgets);
  });
}
