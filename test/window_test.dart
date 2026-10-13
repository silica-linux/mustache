import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/sidebar.dart';
import 'package:mustache/src/window.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mustache');
    Directory('${root.path}/Alfa').createSync();
    File('${root.path}/Alfa/dentro.txt').writeAsStringSync('ciao');
    File('${root.path}/nota.txt').writeAsStringSync('testo');
    File('${root.path}/.nascosto').writeAsStringSync('x');
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<List<String>> pump(WidgetTester tester) async {
    final opened = <String>[];
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: root.path,
          places: [Place('Prova', root.path, PlaceKind.home)],
          trash: Place('Cestino', '${root.path}/Cestino', PlaceKind.trash),
          now: DateTime(2026, 10, 13, 12),
          open: opened.add,
        ),
      ),
    );
    return opened;
  }

  testWidgets('elenca la cartella, apre le cartelle e torna indietro', (
    tester,
  ) async {
    final opened = await pump(tester);
    expect(find.text('Alfa/'), findsOneWidget);
    expect(find.text('nota.txt'), findsOneWidget);
    expect(find.text('.nascosto'), findsNothing);

    // La barra laterale: larga 192, il testo delle righe a 47 pt.
    expect(tester.getTopLeft(find.text('Prova').first).dx, sidebarTextLeft);

    await tester.tap(find.text('Alfa/'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Alfa/'));
    await tester.pumpAndSettle();
    expect(find.text('dentro.txt'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(find.text('nota.txt'), findsOneWidget);

    // Un file si apre con l'app predefinita.
    await tester.tap(find.text('nota.txt'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('nota.txt'));
    await tester.pumpAndSettle();
    expect(opened, ['${root.path}/nota.txt']);
  });

  testWidgets('frecce, ⌘↓ per aprire, ⌘⇧. per i file nascosti', (tester) async {
    await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(find.text('dentro.txt'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.period);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(find.text('.nascosto'), findsOneWidget);
  });

  testWidgets('clic sull\'intestazione inverte l\'ordinamento', (tester) async {
    await pump(tester);
    double y(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(y('Alfa/'), lessThan(y('nota.txt')));
    await tester.tap(find.text('Nome ↑'));
    await tester.pump();
    expect(y('Alfa/'), greaterThan(y('nota.txt')));
  });
}
