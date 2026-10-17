// The screens of the app against the masters of the Silica "Amalfi" UI kit (`Apps/Mustache/*`,
// artboards of the kit page `App · Mustache`): the frames of the window's parts, in whole points,
// are those of the master's layers (copied into test/kit).

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/info.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/path_bar.dart';
import 'package:mustache/src/quick_preview.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/status_bar.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

import 'kit.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mustache-kit');
    for (final name in [
      'Desktop',
      'Documents',
      'Downloads',
      'Music',
      'Pictures',
      'Projects',
      'Public',
      'Templates',
      'Videos',
    ]) {
      Directory('${root.path}/$name').createSync();
    }
    Directory('${root.path}/Documents/Recipes').createSync();
    File('${root.path}/Documents/Toast.txt').writeAsStringSync('x');
  });

  tearDown(() => root.deleteSync(recursive: true));

  /// The window at the size of the kit's artboards (1000 × 640).
  Future<void> pump(
    WidgetTester tester, {
    required String view,
    bool bars = false,
    bool dark = false,
    String? start,
  }) async {
    tester.view.physicalSize = const Size(1000, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.platformBrightnessTestValue = dark
        ? Brightness.dark
        : Brightness.light;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: start ?? root.path,
          places: [Place('silica', root.path, PlaceKind.home)],
          trash: Place('Trash', '${root.path}/.Trash', PlaceKind.trash),
          now: DateTime.now(),
          settings: Settings('${root.path}/.s.json')
            ..view = view
            ..statusBar = bars
            ..pathBar = bars,
          iconsEnv: {'SILICA_ICONS_DIR': root.path},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('Icons', () {
    testWidgets('tiles and the selected tile (Tile, Tile Selected)', (
      tester,
    ) async {
      await pump(tester, view: 'icons');
      final kit = loadKit('Icons');
      final tile = loadKit('Tile Selected');
      for (final name in ['Desktop', 'Documents', 'Public', 'Videos']) {
        final cell = tester.getRect(
          find.byKey(ValueKey('cell ${root.path}/$name')),
        );
        final layer = kit.rect(name);
        expect(cell.left, layer.left, reason: name);
        expect(cell.top, layer.top, reason: name);
        expect(cell.width, layer.width, reason: name);
      }
      // Select Documents: the sunken background and the accent capsule of `Tile Selected`.
      await tester.tap(find.text('Documents'));
      await tester.pump(const Duration(milliseconds: 400));
      final cell = tester.getRect(
        find.byKey(ValueKey('cell ${root.path}/Documents')),
      );
      final bg = tester
          .getRect(
            find.byKey(ValueKey('icon background ${root.path}/Documents')),
          )
          .shift(-cell.topLeft);
      expect(bg, tile.rect('Selection'));
      final capsule = tester
          .getRect(find.byKey(ValueKey('name ${root.path}/Documents 0')))
          .shift(-cell.topLeft);
      expect(capsule, tile.rect('Label capsule'));
      final label = tester.getRect(find.text('Documents')).shift(-cell.topLeft);
      expect(label.top, tile.rect('Label').top);
      expect(label.height, tile.rect('Label').height);
    });

    testWidgets('the toolbar of the Icons master, light and dark', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await pump(tester, view: 'icons', dark: dark);
        final colors = kitColors(dark: dark);
        final bar = tester.getRect(find.byKey(const ValueKey('toolbar')));
        expect(bar, Rect.fromLTWH(240, 0, 760, 52));
        final sidebarBar = tester.getRect(
          find.byKey(const ValueKey('sidebar bar')),
        );
        expect(sidebarBar, const Rect.fromLTWH(0, 0, 240, 52));
        // The surfaces: window on the content, the sidebar surface at 80 % (blur strip) in the
        // sidebar section.
        expect(
          tester
              .widget<ColoredBox>(
                find
                    .descendant(
                      of: find.byKey(const ValueKey('sidebar bar')),
                      matching: find.byType(ColoredBox),
                    )
                    .first,
              )
              .color,
          colors.surfaceSidebar.withValues(alpha: 0.8),
        );
      }
    });
  });

  group('List', () {
    testWidgets('selected row: the capsule 8 in from each side (List Row)', (
      tester,
    ) async {
      await pump(tester, view: 'list');
      await tester.tap(find.text('Documents'));
      await tester.pump(const Duration(milliseconds: 400));
      final row = tester.getRect(
        find.byKey(ValueKey('${root.path}/Documents')),
      );
      final master = loadKit('List Row/Selected');
      expect(row.width, master.size.width);
      expect(row.height, master.size.height);
      final selection = tester
          .getRect(
            find
                .descendant(
                  of: find.byKey(ValueKey('${root.path}/Documents')),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          )
          .shift(-row.topLeft);
      expect(selection, master.rect('Selection'));
    });
  });

  group('Columns', () {
    testWidgets('rows of Columns: 240 columns, rows 28 from y 60', (
      tester,
    ) async {
      await pump(tester, view: 'columns', start: '${root.path}/Documents');
      final kit = loadKit('Columns');
      final desktop = tester.getRect(
        find.byKey(ValueKey('${root.path}/Desktop')),
      );
      final documents = tester.getRect(
        find.byKey(ValueKey('${root.path}/Documents')),
      );
      expect(desktop.left, kit.rect('Desktop').left);
      expect(desktop.width, kit.rect('Desktop').width);
      expect(desktop.height, kit.rect('Desktop').height);
      // The first row of a column: 60 (8 under the toolbar); the next is 28 below.
      expect(desktop.top, kit.rect('Desktop').top);
      expect(documents.top - desktop.top, 28);
      expect(documents.top, kit.rect('Documents').top);
      // The next column: 240 to the right, its first row at the same height.
      final recipes = tester.getRect(
        find.byKey(ValueKey('${root.path}/Documents/Recipes')),
      );
      expect(recipes.left, kit.rect('Recipes').left);
      expect(recipes.top, kit.rect('Recipes').top);
      // The preview section: the toolbar and the pane on the right, 260 wide from x 740.
      expect(
        tester.getRect(find.byKey(const ValueKey('preview bar'))),
        Rect.fromLTWH(
          kit.rect('Preview toolbar').left,
          0,
          kit.rect('Preview toolbar').width,
          52,
        ),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('toolbar'))).right,
        kit.rect('Preview toolbar').left,
      );
    });
  });

  group('Gallery', () {
    testWidgets('preview box, thumbnails and pane (Gallery)', (tester) async {
      File('${root.path}/Documents/Toast.txt').deleteSync();
      await pump(tester, view: 'gallery');
      final kit = loadKit('Gallery');
      final box = tester.getRect(find.byKey(const ValueKey('preview box')));
      expect(box, kit.rect('Preview box'));
      final strip = tester.getRect(
        find.byKey(const ValueKey('thumbnail strip')),
      );
      final first = tester.getRect(
        find.byKey(ValueKey('thumbnail ${root.path}/Desktop')),
      );
      // The thumbnail cells are 64 apart; the first one's 48 pt picture is at x 280, y 488.
      expect(first.left + 8, kit.rect('Thumb 1').left);
      expect(
        tester
                .getRect(
                  find.byKey(ValueKey('thumbnail ${root.path}/Documents')),
                )
                .left -
            first.left,
        kit.rect('Thumb 2').left - kit.rect('Thumb 1').left,
      );
      expect(first.center.dy - 24, kit.rect('Thumb 1').top);
      expect(strip.top, kit.rect('Selected thumb').top);
      // The pane: 260 wide on the right.
      final pane = tester.getRect(find.byKey(const ValueKey('preview pane')));
      expect(pane.left, kit.rect('Preview pane').left);
      expect(pane.top, kit.rect('Preview pane').top);
      expect(pane.width, kit.rect('Preview pane').width);
    });
  });

  group('Search', () {
    testWidgets('scope bar and toolbar of the Search master', (tester) async {
      await pump(tester, view: 'list');
      final kit = loadKit('Search');
      final scope = loadKit('Scope Bar');
      // The circle grows into the field; with it open the view group is a pop-up.
      await tester.tap(find.byKey(const ValueKey('search button')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AmalfiSearchField), findsOneWidget);
      await tester.enterText(find.byType(EditableText).last, 'doc');
      await tester.pump(const Duration(milliseconds: 400));
      final bar = tester.getRect(find.byKey(const ValueKey('scope bar')));
      expect(bar.top, kit.rect('Scope bar').top);
      expect(bar.height, kit.rect('Scope bar').height);
      Rect inBar(Finder f) => tester.getRect(f).shift(-bar.topLeft);
      final label = inBar(find.text('Search in:'));
      expect(label.left, scope.rect('Label').left);
      expect(label.top, scope.rect('Label').top);
      final capsule = inBar(
        find.descendant(
          of: find.byKey(const ValueKey('scope This Computer')),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(capsule.top, scope.rect('Capsule selected').top);
      expect(capsule.height, scope.rect('Capsule selected').height);
      expect(capsule.left, closeTo(scope.rect('Capsule selected').left, 2));
      // The header follows the scope bar; the search toolbar has the view pop-up, not the group.
      final header = tester.getRect(
        find.byKey(const ValueKey('column header')),
      );
      expect(header.top, kit.rect('Header').top);
      expect(find.byKey(const ValueKey('view group')), findsNothing);
    });
  });

  group('bars', () {
    testWidgets('status bar and path bar (Status Bar, Path Bar)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final status = loadKit('Status Bar');
      await tester.pumpWidget(
        kitScene(
          SizedBox(
            width: status.size.width,
            child: const StatusBar(text: '9 items, 41.2 GB available'),
          ),
        ),
      );
      final bar = tester.getRect(find.byKey(const ValueKey('status bar')));
      expect(bar.size, status.size);
      final label = tester
          .getRect(find.text('9 items, 41.2 GB available'))
          .shift(-bar.topLeft);
      expect(label.top, status.rect('Label').top);
      expect(label.height, status.rect('Label').height);
      expect(label.center.dx, status.rect('Label').center.dx);

      final path = loadKit('Path Bar');
      await tester.pumpWidget(
        kitScene(
          SizedBox(
            width: path.size.width,
            child: PathBar(
              path: '${root.path}/Documents/Recipes',
              onOpen: (_) {},
              env: {'SILICA_ICONS_DIR': root.path},
            ),
          ),
        ),
      );
      final pathBar = tester.getRect(find.byKey(const ValueKey('path bar')));
      expect(pathBar.size, path.size);
      // The first segment: the 20 pt icon at (12, 4), the name 4 after it, the chevron 9 after the name
      // and 6 before the next icon.
      Rect inBar(Finder f) => tester.getRect(f).shift(-pathBar.topLeft);
      final first = find.byKey(const ValueKey('segment /'));
      final name = inBar(
        find.descendant(of: first, matching: find.byType(Text)),
      );
      expect(name.left, path.rect('silica').left);
      expect(name.top, path.rect('silica').top);
      final chevron = inBar(
        find.descendant(of: first, matching: find.byType(AmalfiGlyph)),
      );
      expect(chevron.left - name.right, closeTo(9, 0.01));
      expect(chevron.top, path.rect('Chevron').top);
      expect(chevron.size, path.rect('Chevron').size);
      final second = inBar(
        find.byKey(
          ValueKey(
            'segment ${root.path.substring(0, root.path.indexOf('/', 1))}',
          ),
        ),
      );
      expect(second.left - chevron.right, closeTo(6, 0.01));
    });
  });

  group('panels', () {
    testWidgets('Get Info window (Info): frames of the master', (tester) async {
      final kit = loadKit('Info');
      final entry = Entry(
        name: 'Recipes',
        path: '${root.path}/Documents/Recipes',
        isDirectory: true,
        size: 0,
        modified: DateTime(2026, 10, 14, 10, 22),
      );
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        kitScene(
          InfoPanel(
            entry: entry,
            kind: 'Folder',
            open: const {InfoSection.general},
            onToggle: (_) {},
            onClose: () {},
            onRename: (_) {},
            tags: const [],
            onAddTag: (_) {},
          ),
        ),
      );
      final panel = tester.getRect(find.byKey(ValueKey('info ${entry.path}')));
      expect(panel.width, kit.size.width);
      Rect inPanel(Finder f) => tester.getRect(f).shift(-panel.topLeft);
      expect(inPanel(find.text('Recipes').first).left, kit.rect('Name').left);
      expect(inPanel(find.text('Recipes').first).top, kit.rect('Name').top);
      expect(inPanel(find.text('0 items').first).top, kit.rect('Size').top);
      expect(
        inPanel(find.textContaining('Modified:')).top,
        kit.rect('Modified').top,
      );
      final tags = inPanel(find.byType(AmalfiSearchField).first);
      expect(tags.top, kit.rect('Tags').top);
      expect(tags.height, kit.rect('Tags').height);
      final general = inPanel(find.text('General'));
      expect(general.left, kit.rect('General').left);
      expect(general.top, kit.rect('General').top);
      expect(inPanel(find.text('Type')).top, kit.rect('Type').top);
      expect(inPanel(find.text('Folder')).left, kit.rect('Type value').left);
      expect(
        inPanel(find.text('Modified').last).top,
        kit.rect('Modified').top == 108 ? 290 : 0,
      );
    });

    testWidgets('quick preview panel (Quick Preview)', (tester) async {
      final kit = loadKit('Quick Preview');
      final entry = Entry(
        name: 'Recipes',
        path: '${root.path}/Documents/Recipes',
        isDirectory: true,
        size: 0,
        modified: DateTime(2026, 10, 14, 10, 22),
      );
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        kitScene(
          SizedBox(
            width: 800,
            height: 600,
            child: QuickPreviewPanel(entry: entry, onClose: () {}),
          ),
        ),
      );
      final panel = tester.getRect(find.byKey(const ValueKey('quick preview')));
      expect(panel.size, kit.size);
      Rect inPanel(Finder f) => tester.getRect(f).shift(-panel.topLeft);
      expect(inPanel(find.text('Recipes').last).left, kit.rect('Title').left);
      expect(inPanel(find.text('Recipes').last).top, kit.rect('Title').top);
      expect(
        inPanel(find.textContaining('Last modified')).top,
        kit.rect('Modified').top,
      );
      final bar = inPanel(find.byKey(const ValueKey('close quick preview')));
      expect(bar.top, lessThan(quickPreviewBar));
    });
  });

  testWidgets('the smallest window lays out without overflow, in every view', (
    tester,
  ) async {
    for (final view in ['icons', 'list', 'columns', 'gallery']) {
      await pump(tester, view: view, bars: true);
      tester.view.physicalSize = minimumWindowSize;
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: view);
      expect(find.byKey(const ValueKey('toolbar')), findsOneWidget);
    }
  });

  test('the kit master files are in place', () {
    expect(loadKit('Icons').size, const Size(1000, 640));
    expect(loadKit('Info').size, const Size(264, 604));
    expect(
      PointerDeviceKind.mouse,
      isNotNull,
      reason: 'keeps the gestures import used',
    );
    expect(LogicalKeyboardKey.escape, isNotNull);
  });
}
