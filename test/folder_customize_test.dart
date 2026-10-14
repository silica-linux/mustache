import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/folder_customize.dart';
import 'package:mustache/src/folder_style.dart';
import 'package:mustache/src/info.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';
import 'package:mustache/src/xattr.dart';
import 'package:silica_ui/silica_ui.dart';

import 'folder_fixture.dart';
import 'folder_style_test.dart' show FakeDisk, FakeMetadata, homeTemp;

void main() {
  late Directory icons;
  late Map<String, String> env;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GlassRegistry.channel, (call) async => true);
    icons = folderIconsRoot();
    env = {'SILICA_ICONS_DIR': icons.path, 'HOME': '/nonexistent-home'};
  });

  tearDown(() => icons.deleteSync(recursive: true));

  Future<FolderStyles> pumpSection(
    WidgetTester tester, {
    FakeDisk? disk,
    bool fails = false,
  }) async {
    final d = disk ?? FakeDisk();
    final styles = FolderStyles(
      readAttribute: d.read,
      writeAttribute: fails ? (_, _, _) => AttributeWrite.failed : d.write,
      readTags: (path) => d.tags[path] ?? const [],
      metadata: FakeMetadata(),
    );
    addTearDown(styles.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: infoWidth,
            child: FolderCustomizeSection(
              path: '/home/a/Lavoro',
              env: env,
              styles: styles,
            ),
          ),
        ),
      ),
    );
    return styles;
  }

  testWidgets('swatches save the colour; a custom colour from the field', (
    tester,
  ) async {
    final styles = await pumpSection(tester);
    // None, the seven colours and the custom one.
    for (final name in [
      'none',
      'red',
      'orange',
      'yellow',
      'green',
      'blue',
      'purple',
      'gray',
      'custom',
    ]) {
      expect(find.byKey(ValueKey('folder tint $name')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('folder tint purple')));
    await tester.pump();
    expect(styles.stored('/home/a/Lavoro'), const FolderStyle(tint: 'purple'));
    expect(find.byKey(const ValueKey('folder tint field')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('folder tint custom')));
    await tester.pump();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('folder tint field')),
        matching: find.byType(EditableText),
      ),
      'E8336D',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(styles.stored('/home/a/Lavoro'), const FolderStyle(tint: '#e8336d'));

    await tester.tap(find.byKey(const ValueKey('folder tint none')));
    await tester.pump();
    expect(styles.stored('/home/a/Lavoro'), isNull);
  });

  testWidgets('the symbol grid: search, choose, none, Reset', (tester) async {
    final styles = await pumpSection(tester);
    // "No symbol" first, then every symbol of silica-icons.
    expect(find.byKey(const ValueKey('folder symbol none')), findsOneWidget);
    for (final name in fixtureSymbols) {
      expect(find.byKey(ValueKey('folder symbol $name')), findsOneWidget);
    }
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('folder symbol search')),
        matching: find.byType(EditableText),
      ),
      'music',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('folder symbol house')), findsNothing);
    expect(find.byKey(const ValueKey('folder symbol none')), findsNothing);
    expect(
      find.byKey(const ValueKey('folder symbol music-list')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('folder symbol music-note')));
    await tester.pump();
    expect(
      styles.stored('/home/a/Lavoro'),
      const FolderStyle(symbol: 'music-note'),
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('folder symbol search')),
        matching: find.byType(EditableText),
      ),
      'nothing like this',
    );
    await tester.pump();
    expect(find.text('No symbols'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('folder tint red')));
    await tester.pump();
    expect(
      styles.stored('/home/a/Lavoro'),
      const FolderStyle(tint: 'red', symbol: 'music-note'),
    );
    await tester.tap(find.byKey(const ValueKey('folder reset')));
    await tester.pump();
    expect(styles.stored('/home/a/Lavoro'), isNull);
  });

  testWidgets('a folder that cannot be changed says so', (tester) async {
    final styles = await pumpSection(tester, fails: true);
    expect(find.byKey(const ValueKey('folder style error')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('folder tint green')));
    await tester.pump();
    expect(find.byKey(const ValueKey('folder style error')), findsOneWidget);
    expect(styles.stored('/home/a/Lavoro'), isNull);
  });

  testWidgets('a change made elsewhere shows in the open section', (
    tester,
  ) async {
    final disk = FakeDisk();
    final styles = await pumpSection(tester, disk: disk);
    disk.write('/home/a/Lavoro', folderStyleAttribute, '{"tint":"#123456"}');
    styles.changed('/home/a/Lavoro');
    await tester.pump(const Duration(milliseconds: 200));
    // The custom swatch now shows the colour, chosen.
    final swatch = find.descendant(
      of: find.byKey(const ValueKey('folder tint custom')),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color == const Color(0xFF123456),
      ),
    );
    expect(swatch, findsOneWidget);
  });

  group('in the window', () {
    late Directory home;
    late Directory folder;

    Future<bool> pumpWindow(WidgetTester tester) async {
      home = homeTemp('mustache-folder-menu');
      folder = Directory('${home.path}/Doc/Progetti')
        ..createSync(recursive: true);
      File('${home.path}/Doc/nota.txt').writeAsStringSync('x');
      if (!writeTags(folder.path, [])) return false;
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MustacheWindow(
            start: '${home.path}/Doc',
            places: [Place('casa', home.path, PlaceKind.home)],
            trash: Place('Trash', '${home.path}/Cestino', PlaceKind.trash),
            settings: Settings('${home.path}/s.json')..view = 'list',
            iconsEnv: {...env, 'HOME': home.path},
          ),
        ),
      );
      return true;
    }

    Future<void> rightClickFolder(WidgetTester tester) async {
      final row = find.descendant(
        of: find.byType(ListView),
        matching: find.text('Progetti'),
      );
      await tester.tapAt(tester.getCenter(row), buttons: kSecondaryMouseButton);
      await tester.pump();
    }

    FolderIcon? drawnFolder(WidgetTester tester) {
      for (final icon in tester.widgetList<SilicaIcon>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(SilicaIcon),
        ),
      )) {
        if (icon.source case FolderSource(:final folder)) return folder;
      }
      return null;
    }

    testWidgets('the colour dots tag a folder and tint it', (tester) async {
      if (!await pumpWindow(tester)) {
        markTestSkipped('no extended attributes on this file system');
        return;
      }
      expect(drawnFolder(tester)?.tint, isNull);
      await rightClickFolder(tester);
      for (final c in [
        'red',
        'orange',
        'yellow',
        'green',
        'blue',
        'purple',
        'gray',
      ]) {
        expect(find.byKey(ValueKey('tag $c')), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('tag orange')));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(readTags(folder.path), ['Orange']);
      expect(folderStyles.look(folder.path).tint, 'orange');
      expect(drawnFolder(tester)?.tint, const Color(0xFFFF8A00));
      writeTags(folder.path, []);
      folderStyles.invalidate([folder.path]);
    });

    testWidgets('Customize Folder… opens Get Info on its section', (
      tester,
    ) async {
      if (!await pumpWindow(tester)) {
        markTestSkipped('no extended attributes on this file system');
        return;
      }
      await rightClickFolder(tester);
      await tester.tap(find.text('Customize Folder…'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(find.byKey(ValueKey('info ${folder.path}')), findsOneWidget);
      expect(find.byType(FolderCustomizeSection), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('folder symbol star')));
      await tester.pump();
      expect(
        readAttribute(folder.path, folderStyleAttribute),
        '{"symbol":"star"}',
      );
      expect(drawnFolder(tester)?.symbol, 'star');

      // Changed by another app: the watcher's notice redraws the icon.
      writeAttribute(folder.path, folderStyleAttribute, '{"symbol":"house"}');
      folderStyles.changed(folder.path);
      await tester.pump(const Duration(milliseconds: 200));
      expect(drawnFolder(tester)?.symbol, 'house');
      folderStyles.save(folder.path, const FolderStyle());
    });

    testWidgets('a file has Tags…, not Customize Folder…', (tester) async {
      if (!await pumpWindow(tester)) {
        markTestSkipped('no extended attributes on this file system');
        return;
      }
      await tester.tapAt(
        tester.getCenter(
          find.descendant(
            of: find.byType(ListView),
            matching: find.text('nota.txt'),
          ),
        ),
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();
      expect(find.text('Tags…'), findsOneWidget);
      expect(find.text('Customize Folder…'), findsNothing);
      await tester.tapAt(const Offset(5, 690));
      await tester.pump();
      await rightClickFolder(tester);
      expect(find.text('Customize Folder…'), findsOneWidget);
      expect(find.text('Tags…'), findsNothing);
    });
  });
}
