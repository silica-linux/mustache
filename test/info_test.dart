import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/info.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';

void main() {
  test('stat, privilegi', () {
    final s = StatDetails.parse('1760000000 8 io staff 640');
    expect(s.created, DateTime.fromMillisecondsSinceEpoch(1760000000000));
    expect(s.onDisk, 4096);
    expect(s.owner, 'io');
    expect(s.mode, 0x1a0);
    expect(StatDetails.parse('0 0 a b 644').created, isNull);
    expect(privilegeOf(0x1a0, 6), Privilege.readWrite);
    expect(privilegeOf(0x1a0, 3), Privilege.readOnly);
    expect(privilegeOf(0x1a0, 0), Privilege.none);
    expect(withPrivilege(0x1ed, 0, Privilege.none).toRadixString(8), '751');
    expect(
      withPrivilege(0x1a4, 3, Privilege.readWrite).toRadixString(8),
      '664',
    );
  });

  testWidgets('⌘I apre Informazioni; le sezioni si ricordano; Nome rinomina', (
    tester,
  ) async {
    final home = Directory.systemTemp.createTempSync('mustache-info');
    addTearDown(() => home.deleteSync(recursive: true));
    final file = File('${home.path}/nota.txt')..writeAsStringSync('ciao');
    Process.runSync('chmod', ['644', file.path]);
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
          trash: Place('Cestino', '${home.path}/Cestino', PlaceKind.trash),
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
    final panel = find.byKey(ValueKey('informazioni ${file.path}'));
    expect(panel, findsOneWidget);
    expect(tester.getSize(panel).width, infoWidth);
    expect(find.text('Info su nota.txt'), findsOneWidget);
    expect(
      find.text('4 byte (4,1 KB su disco)').evaluate().length +
          find.textContaining('su disco)').evaluate().length,
      greaterThan(0),
    );
    // Commenti chiusa: si apre e lo stato resta per le prossime.
    await tester.tap(find.byKey(const ValueKey('sezione Commenti')));
    await tester.pump();
    expect(find.byKey(const ValueKey('campo del commento')), findsOneWidget);
    expect(settings.infoSections, contains('comments'));
    // Permessi: il gruppo passa da Sola lettura a Nessun accesso, subito su disco.
    await tester.tap(
      find.byKey(const ValueKey('sezione Condivisione e permessi')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('privilegio 3')));
    await tester.pump();
    final mode = Process.runSync('stat', [
      '-c',
      '%a',
      file.path,
    ]).stdout.toString().trim();
    expect(mode, '604');
    // Nome: Invio rinomina.
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('campo del nome')),
        matching: find.byType(EditableText),
      ),
      'promemoria.txt',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(File('${home.path}/promemoria.txt').existsSync(), isTrue);
    await tester.tap(find.byKey(const ValueKey('chiudi le informazioni')));
    await tester.pump();
    expect(find.byType(InfoPanel), findsNothing);
  });
}
