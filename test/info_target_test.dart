// Get Info and Customize Folder… act on the selected item(s), never on the window's folder
// (docs/spec/info.md, menus-and-settings.md): every entry point, in every view.
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/folder_customize.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  late Directory home;
  late Directory doc;
  late Directory sub;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GlassRegistry.channel, (call) async => true);
    // A Silica that cannot open windows: the Info panels are drawn in the window
    // (info_window_test.dart covers the windows).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SilicaWindow.channel, (call) async => null);
    home = Directory.systemTemp.createTempSync('mustache-info-target');
    doc = Directory('${home.path}/Doc')..createSync();
    sub = Directory('${doc.path}/Progetti')..createSync();
    Directory('${doc.path}/Altra').createSync();
    File('${doc.path}/nota.txt').writeAsStringSync('x');
  });

  tearDown(() => home.deleteSync(recursive: true));

  Future<void> pump(
    WidgetTester tester, {
    String view = 'list',
    String? start,
    String? customize,
  }) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: start ?? doc.path,
          places: [Place('casa', home.path, PlaceKind.home)],
          trash: Place('Trash', '${home.path}/Cestino', PlaceKind.trash),
          settings: Settings('${home.path}/s.json')..view = view,
          iconsEnv: {'HOME': home.path},
          customize: customize,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Finder item(String name) => find.text(name).first;

  Future<void> click(
    WidgetTester tester,
    String name, {
    bool shift = false,
  }) async {
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(tester.getCenter(item(name)));
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> rightClick(WidgetTester tester, String name) async {
    await tester.tapAt(
      tester.getCenter(item(name)),
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();
  }

  Future<void> cmdI(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder info(String path) => find.byKey(ValueKey('info $path'));
  Finder anyInfo() => find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('info /'),
  );

  for (final view in ['list', 'icons', 'columns']) {
    group('$view view', () {
      testWidgets('⌘I shows the selected folder, not the window folder', (
        tester,
      ) async {
        await pump(tester, view: view);
        await click(tester, 'Progetti');
        await cmdI(tester);
        expect(info(sub.path), findsOneWidget);
        expect(info(doc.path), findsNothing);
        expect(anyInfo(), findsOneWidget);
      });

      testWidgets('⌘I shows the selected file', (tester) async {
        await pump(tester, view: view);
        await click(tester, 'nota.txt');
        await cmdI(tester);
        expect(info('${doc.path}/nota.txt'), findsOneWidget);
        expect(anyInfo(), findsOneWidget);
      });

      testWidgets('⌘I with several selected: one Info per item', (
        tester,
      ) async {
        await pump(tester, view: view);
        if (view == 'columns') return; // one choice at a time in columns
        await click(tester, 'Progetti');
        await click(tester, 'nota.txt', shift: true);
        await cmdI(tester);
        expect(info(sub.path), findsOneWidget);
        expect(info('${doc.path}/nota.txt'), findsOneWidget);
        expect(info(doc.path), findsNothing);
      });

      testWidgets('context menu Show Info on an unselected item', (
        tester,
      ) async {
        await pump(tester, view: view);
        await rightClick(tester, 'Progetti');
        await tester.tap(find.text('Show Info'));
        await settle(tester);
        expect(info(sub.path), findsOneWidget);
        expect(anyInfo(), findsOneWidget);
      });

      testWidgets('context menu Show Info on another selected item', (
        tester,
      ) async {
        await pump(tester, view: view);
        await click(tester, 'nota.txt');
        await rightClick(tester, 'Progetti');
        await tester.tap(find.text('Show Info'));
        await settle(tester);
        expect(info(sub.path), findsOneWidget);
        expect(info('${doc.path}/nota.txt'), findsNothing);
        expect(info(doc.path), findsNothing);
      });

      testWidgets('Customize Folder… edits the folder, not its parent', (
        tester,
      ) async {
        await pump(tester, view: view);
        await rightClick(tester, 'Progetti');
        await tester.tap(find.text('Customize Folder…'));
        await settle(tester);
        // A popover on that folder, not a Get Info window.
        expect(anyInfo(), findsNothing);
        final overlay = tester.widget<FolderCustomizeOverlay>(
          find.byType(FolderCustomizeOverlay),
        );
        expect(overlay.path, sub.path);
        expect(find.byKey(const ValueKey('folder popover')), findsOneWidget);
      });
    });
  }

  testWidgets('the window background menu: Show Info is the window folder', (
    tester,
  ) async {
    await pump(tester);
    await tester.tapAt(const Offset(700, 700), buttons: kSecondaryMouseButton);
    await tester.pump();
    await tester.tap(find.text('Show Info'));
    await settle(tester);
    expect(info(doc.path), findsOneWidget);
  });

  testWidgets('⌘I with nothing selected shows the window folder', (
    tester,
  ) async {
    await pump(tester);
    await cmdI(tester);
    expect(info(doc.path), findsOneWidget);
    expect(anyInfo(), findsOneWidget);
  });

  testWidgets(
    '--customize=<folder>: the window opens in the parent, the popover '
    'on the folder itself',
    (tester) async {
      await pump(tester, customize: sub.path);
      await tester.pump(const Duration(milliseconds: 100));
      expect(anyInfo(), findsNothing);
      expect(
        tester
            .widget<FolderCustomizeOverlay>(find.byType(FolderCustomizeOverlay))
            .path,
        sub.path,
      );
      expect(find.byKey(const ValueKey('folder popover')), findsOneWidget);
    },
  );
}
