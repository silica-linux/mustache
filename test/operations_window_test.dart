import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/rename_field.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  late Directory home;
  late Directory dir;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GlassRegistry.channel, (call) async => true);
    home = Directory.systemTemp.createTempSync('mustache-casa');
    dir = Directory('${home.path}/Documenti')..createSync();
    File('${dir.path}/appunti.txt').writeAsStringSync('a');
    File('${dir.path}/bozza.txt').writeAsStringSync('b');
    File('${dir.path}/conto.txt').writeAsStringSync('c');
  });

  tearDown(() => home.deleteSync(recursive: true));

  String p(String name) => '${dir.path}/$name';

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: dir.path,
          places: [Place('casa', home.path, PlaceKind.home)],
          trash: Place(
            'Trash',
            '${home.path}/.local/share/Trash/files',
            PlaceKind.trash,
          ),
          settings: Settings('${home.path}/.config/s.json')..view = 'list',
        ),
      ),
    );
  }

  Future<void> select(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    // Past the double-click wait, without reaching the slow-click rename.
    await tester.pump(const Duration(milliseconds: 310));
  }

  Future<void> keys(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool meta = false,
    bool shift = false,
    bool alt = false,
  }) async {
    if (meta) await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(key);
    if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (meta) await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
  }

  testWidgets('Return renames: only the name selected, Return confirms, ⌘Z', (
    tester,
  ) async {
    await pump(tester);
    await select(tester, 'appunti.txt');
    await keys(tester, LogicalKeyboardKey.enter);
    await tester.pump();
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(
      field.controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 7),
    );
    await tester.enterText(find.byType(EditableText), 'promemoria.txt');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(File(p('promemoria.txt')).existsSync(), isTrue);
    expect(find.byType(RenameField), findsNothing);
    expect(find.text('promemoria.txt'), findsOneWidget);
    await keys(tester, LogicalKeyboardKey.keyZ, meta: true);
    expect(File(p('appunti.txt')).existsSync(), isTrue);
    await keys(tester, LogicalKeyboardKey.keyZ, meta: true, shift: true);
    expect(File(p('promemoria.txt')).existsSync(), isTrue);
  });

  testWidgets(
    'on Linux the focus does not select everything: the name without extension stays',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await pump(tester);
      await select(tester, 'appunti.txt');
      await keys(tester, LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(
        field.controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 7),
      );
      await keys(tester, LogicalKeyboardKey.escape);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('Esc cancels; a name already used opens the alert', (
    tester,
  ) async {
    await pump(tester);
    await select(tester, 'appunti.txt');
    await keys(tester, LogicalKeyboardKey.enter);
    await tester.enterText(find.byType(EditableText), 'altro.txt');
    await keys(tester, LogicalKeyboardKey.escape);
    expect(find.byType(RenameField), findsNothing);
    expect(File(p('appunti.txt')).existsSync(), isTrue);

    await keys(tester, LogicalKeyboardKey.enter);
    await tester.enterText(find.byType(EditableText), 'bozza.txt');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.byType(SilicaAlert), findsOneWidget);
    expect(find.textContaining('is already taken'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('alert OK')));
    await tester.pump();
    expect(find.byType(SilicaAlert), findsNothing);
    expect(File(p('appunti.txt')).readAsStringSync(), 'a');
    expect(File(p('bozza.txt')).readAsStringSync(), 'b');
  });

  testWidgets('changing the extension asks: Keep keeps the old one', (
    tester,
  ) async {
    await pump(tester);
    await select(tester, 'appunti.txt');
    await keys(tester, LogicalKeyboardKey.enter);
    await tester.enterText(find.byType(EditableText), 'note.md');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.byKey(const ValueKey('alert Use .md')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('alert Keep .txt')));
    await tester.pump();
    expect(File(p('note.txt')).existsSync(), isTrue);
  });

  testWidgets('⇧⌘N creates "cartella senza nome" in rename; ⌘Z removes it', (
    tester,
  ) async {
    await pump(tester);
    await keys(tester, LogicalKeyboardKey.keyN, meta: true, shift: true);
    await tester.pump();
    expect(Directory(p('new folder')).existsSync(), isTrue);
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.controller.text, 'new folder');
    // Everything selected (a folder has no extension).
    expect(field.controller.selection.extentOffset, 'new folder'.length);
    await keys(tester, LogicalKeyboardKey.escape);
    await keys(tester, LogicalKeyboardKey.keyZ, meta: true);
    expect(Directory(p('new folder')).existsSync(), isFalse);
  });

  testWidgets('⌘D duplicates and selects the copies', (tester) async {
    await pump(tester);
    await select(tester, 'bozza.txt');
    await keys(tester, LogicalKeyboardKey.keyD, meta: true);
    expect(File(p('bozza copy.txt')).readAsStringSync(), 'b');
    await keys(tester, LogicalKeyboardKey.keyD, meta: true);
    expect(File(p('bozza copy copy.txt')).existsSync(), isTrue);
    await keys(tester, LogicalKeyboardKey.keyZ, meta: true);
    expect(File(p('bozza copy copy.txt')).existsSync(), isFalse);
  });

  testWidgets(
    '⌘⌫ to the Trash, the selection moves to the next; ⌘Z puts it back',
    (tester) async {
      await pump(tester);
      await select(tester, 'bozza.txt');
      await keys(tester, LogicalKeyboardKey.backspace, meta: true);
      expect(File(p('bozza.txt')).existsSync(), isFalse);
      final trashed = File('${home.path}/.local/share/Trash/files/bozza.txt');
      expect(trashed.existsSync(), isTrue);
      // The next item (conto.txt) is selected: another ⌘⌫ moves it.
      await keys(tester, LogicalKeyboardKey.backspace, meta: true);
      expect(File(p('conto.txt')).existsSync(), isFalse);
      await keys(tester, LogicalKeyboardKey.keyZ, meta: true);
      await keys(tester, LogicalKeyboardKey.keyZ, meta: true);
      expect(File(p('bozza.txt')).readAsStringSync(), 'b');
      expect(File(p('conto.txt')).readAsStringSync(), 'c');
    },
  );

  testWidgets('⌥⌘⌫ asks for confirmation; Delete removes right away', (
    tester,
  ) async {
    await pump(tester);
    await select(tester, 'conto.txt');
    await keys(tester, LogicalKeyboardKey.backspace, meta: true, alt: true);
    expect(find.textContaining('Delete “conto.txt”'), findsOneWidget);
    await keys(tester, LogicalKeyboardKey.escape);
    expect(File(p('conto.txt')).existsSync(), isTrue);
    await keys(tester, LogicalKeyboardKey.backspace, meta: true, alt: true);
    await tester.tap(find.byKey(const ValueKey('alert Delete')));
    await tester.pump();
    expect(File(p('conto.txt')).existsSync(), isFalse);
    expect(
      Directory('${home.path}/.local/share/Trash/files').existsSync(),
      isFalse,
    );
  });

  testWidgets('slow click on the already selected name: rename after ~440 ms', (
    tester,
  ) async {
    await pump(tester);
    await select(tester, 'appunti.txt');
    await tester.tap(find.text('appunti.txt'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(RenameField), findsNothing);
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(RenameField), findsOneWidget);
  });
}
