import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/dialog.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  test('argomenti del dialogo e URI', () {
    final d = DialogOptions.parse([
      '--dialog=save',
      '--title=Esporta',
      '--name=relazione.pdf',
      '--folder=/',
    ])!;
    expect(d.save, isTrue);
    expect(d.title, 'Esporta');
    expect(d.name, 'relazione.pdf');
    expect(d.folder, '/');
    expect(d.acceptLabel, 'Salva');
    expect(DialogOptions.parse(['/home']), isNull);
    expect(
      DialogOptions.parse([
        '--dialog=open',
        '--multiple',
        '--folder=/non/esiste',
      ])!.folder,
      isNull,
    );
    expect(fileUri('/home/io/a b.txt'), 'file:///home/io/a%20b.txt');
  });

  group('nella finestra', () {
    late Directory home;
    late List<List<String>> finished;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            GlassRegistry.channel,
            (call) async => true,
          );
      home = Directory.systemTemp.createTempSync('mustache-dialogo');
      File('${home.path}/nota.txt').writeAsStringSync('x');
      Directory('${home.path}/Cartella').createSync();
      finished = [];
    });

    tearDown(() => home.deleteSync(recursive: true));

    Future<void> pump(WidgetTester tester, DialogOptions dialog) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MustacheWindow(
            start: home.path,
            places: [Place('casa', home.path, PlaceKind.home)],
            trash: Place('Cestino', '${home.path}/Cestino', PlaceKind.trash),
            settings: Settings('${home.path}/.s.json')..view = 'list',
            dialog: dialog,
            onDialogFinish: finished.add,
          ),
        ),
      );
    }

    testWidgets('Apri: doppio clic su un file lo sceglie; Esc annulla', (
      tester,
    ) async {
      await pump(
        tester,
        const DialogOptions(save: false, title: 'Scegli un file'),
      );
      expect(find.text('Scegli un file'), findsOneWidget);
      await tester.tap(find.text('nota.txt'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('nota.txt'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(finished, [
        ['${home.path}/nota.txt'],
      ]);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(finished.last, isEmpty);
    });

    testWidgets('Salva: il nome nella cartella aperta; sostituire chiede', (
      tester,
    ) async {
      await pump(tester, const DialogOptions(save: true, name: 'nuovo.txt'));
      await tester.tap(find.byKey(const ValueKey('dialogo Salva')));
      await tester.pump();
      expect(finished, [
        ['${home.path}/nuovo.txt'],
      ]);
      await tester.enterText(
        find.byKey(const ValueKey('campo del nome del dialogo')),
        'nota.txt',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('dialogo Salva')));
      await tester.pump();
      expect(find.byType(SilicaAlert), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('avviso Sostituisci')));
      await tester.pump();
      expect(finished.last, ['${home.path}/nota.txt']);
    });

    testWidgets('cartelle: senza scelta vale quella aperta', (tester) async {
      await pump(tester, const DialogOptions(save: false, directory: true));
      await tester.tap(find.byKey(const ValueKey('dialogo Apri')));
      await tester.pump();
      expect(finished, [
        [home.path],
      ]);
    });
  });
}
