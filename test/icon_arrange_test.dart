import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/icon_arrange.dart';
import 'package:mustache/src/icon_view.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  final grid = FreeGrid.of();

  group('free grid', () {
    test('fixed pitch: the minimum one, whatever the width', () {
      expect(grid.pitchX, minIconPitch());
      expect(grid.pitchY, iconGrid(783).pitchY);
      expect(grid.top, iconGrid(783).top);
      expect(
        grid.columnsFor(800),
        ((800 - 2 * grid.left) / grid.pitchX).floor(),
      );
      expect(grid.columnsFor(10), 1);
      expect(grid.onGrid(grid.cell(2, 3)), isTrue);
      expect(grid.onGrid(grid.cell(2, 3) + const Offset(3, 0)), isFalse);
      expect(grid.cellOf(grid.cell(4, 1) + const Offset(20, -20)), (4, 1));
    });

    test(
      'Clean Up: off-grid icons go to the nearest free cell, the others stay',
      () {
        final positions = {
          'a': grid.cell(0, 0),
          'b': grid.cell(1, 0),
          // Near cell (1, 0), which is taken: the nearest free one is (2, 0) or (1, 1).
          'c': grid.cell(1, 0) + const Offset(30, 10),
          // Near cell (3, 2), free.
          'd': grid.cell(3, 2) + const Offset(-12, 15),
        };
        final cleaned = cleanUp(positions, grid);
        expect(cleaned['a'], positions['a']);
        expect(cleaned['b'], positions['b']);
        expect(cleaned['d'], grid.cell(3, 2));
        expect(cleaned['c'], grid.cell(2, 0));
        // Only the selection.
        final some = cleanUp(positions, grid, only: {'d'});
        expect(some['c'], positions['c']);
        expect(some['d'], grid.cell(3, 2));
      },
    );

    test('Clean Up never puts two icons in one cell', () {
      final positions = {
        for (var i = 0; i < 6; i++) 'i$i': grid.cell(2, 2) + Offset(i * 3, 5),
      };
      final cleaned = cleanUp(positions, grid);
      expect(cleaned.values.toSet(), hasLength(6));
      expect(cleaned.values.every(grid.onGrid), isTrue);
    });

    test('new items take the first free cells', () {
      final placed = placeNew(
        ['a', 'b', 'c'],
        {'a': grid.cell(0, 0), 'gone': grid.cell(5, 5)},
        grid,
        3,
      );
      expect(placed.keys, unorderedEquals(['a', 'b', 'c']));
      expect(placed['b'], grid.cell(1, 0));
      expect(placed['c'], grid.cell(2, 0));
    });

    test('moving keeps the offsets; Snap to Grid lands on free cells', () {
      final positions = {
        'a': grid.cell(0, 0),
        'b': grid.cell(1, 0),
        'c': grid.cell(2, 0),
      };
      const delta = Offset(37, 140);
      final moved = moveIcons(positions, ['a', 'b'], delta, grid);
      expect(moved['a'], positions['a']! + delta);
      expect(moved['b']! - moved['a']!, positions['b']! - positions['a']!);
      expect(moved['c'], positions['c']);
      // With snap: each one on the cell nearest to where it fell.
      final snapped = moveIcons(
        positions,
        ['a'],
        const Offset(5, 120),
        grid,
        snap: true,
      );
      expect(snapped['a'], grid.cell(0, 1));
      // A taken cell is skipped.
      final taken = moveIcons(
        positions,
        ['a'],
        positions['c']! - positions['a']!,
        grid,
        snap: true,
      );
      expect(taken['a'], isNot(positions['c']));
      expect(grid.onGrid(taken['a']!), isTrue);
    });

    test('arrows move to the nearest icon on that side', () {
      final positions = {
        'a': grid.cell(0, 0),
        'b': grid.cell(3, 0) + const Offset(0, 20),
        'c': grid.cell(1, 2),
        'd': grid.cell(0, 1),
      };
      expect(spatialNeighbour(positions, 'a', const Offset(1, 0)), 'b');
      expect(spatialNeighbour(positions, 'a', const Offset(0, 1)), 'd');
      expect(spatialNeighbour(positions, 'a', const Offset(-1, 0)), isNull);
      expect(spatialNeighbour(positions, 'd', const Offset(0, 1)), 'c');
    });
  });

  group('storage', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('mustache-pos'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('positions survive a restart, per folder', () {
      final store = IconPositions('${dir.path}/state/p.json');
      store.put(
        '/x',
        FolderArrangement(
          free: true,
          snap: true,
          icons: {'a': const Offset(10, 20)},
        ),
      );
      final again = IconPositions('${dir.path}/state/p.json');
      expect(again.of('/x').free, isTrue);
      expect(again.of('/x').snap, isTrue);
      expect(again.of('/x').icons['a'], const Offset(10, 20));
      expect(again.of('/y').free, isFalse);
    });

    test('another process saving other folders is not overwritten', () {
      final one = IconPositions('${dir.path}/p.json');
      final two = IconPositions('${dir.path}/p.json');
      one.put('/a', FolderArrangement(free: true));
      two.put('/b', FolderArrangement(free: true));
      final read = IconPositions('${dir.path}/p.json');
      expect(read.of('/a').free, isTrue);
      expect(read.of('/b').free, isTrue);
    });

    test('a damaged file or odd values count as no arrangement', () {
      File(
        '${dir.path}/p.json',
      ).writeAsStringSync('{"/x": {"icons": {"a": [1, "b"]}}');
      expect(IconPositions('${dir.path}/p.json').of('/x').icons, isEmpty);
      File('${dir.path}/p.json').writeAsStringSync(
        '{"/x": {"free": 3, "icons": {"a": [1, 2], "b": [1]}}}',
      );
      final x = IconPositions('${dir.path}/p.json').of('/x');
      expect(x.free, isFalse);
      expect(x.icons.keys, ['a']);
    });

    test('the file is in the XDG state directory', () {
      expect(
        IconPositions.forUser({'HOME': '/h'}).path,
        '/h/.local/state/mustache/icon-positions.json',
      );
      expect(
        IconPositions.forUser({'HOME': '/h', 'XDG_STATE_HOME': '/s'}).path,
        '/s/mustache/icon-positions.json',
      );
    });
  });

  group('icon view', () {
    List<Entry> entries(int n) => [
      for (var i = 0; i < n; i++)
        Entry(
          path: '/f/item$i',
          name: 'item$i',
          isDirectory: true,
          size: 0,
          modified: DateTime(2026),
        ),
    ];

    Future<void> pump(
      WidgetTester tester,
      double width, {
      Map<String, Offset>? positions,
      int count = 12,
    }) async {
      tester.view.physicalSize = Size(width, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: IconView(
            entries: entries(count),
            selected: const {},
            onTap: (_) {},
            onOpen: (_) {},
            onBackground: () {},
            positions: positions,
            env: const {'SILICA_ICONS_DIR': '/nonexistent'},
          ),
        ),
      );
    }

    Offset cellOf(WidgetTester tester, String path) {
      final cell = tester.widget<AnimatedPositioned>(
        find.byKey(ValueKey('cell $path')),
      );
      return Offset(cell.left!, cell.top!);
    }

    testWidgets('sorted: the grid reflows with the width (mustache#4)', (
      tester,
    ) async {
      await pump(tester, 900);
      final wide = iconGrid(900).columns;
      expect(
        cellOf(tester, '/f/item${wide - 1}').dy,
        cellOf(tester, '/f/item0').dy,
      );
      await pump(tester, 400);
      final narrow = iconGrid(400).columns;
      expect(narrow, lessThan(wide));
      // The item that was on the first row goes down.
      expect(
        cellOf(tester, '/f/item${wide - 1}').dy,
        greaterThan(cellOf(tester, '/f/item0').dy),
      );
      expect(
        find.byKey(const ValueKey('icon view horizontal scroll')),
        findsNothing,
      );
    });

    testWidgets(
      'free positions: resizing moves nothing and the content scrolls sideways',
      (tester) async {
        final positions = arrangeOnGrid(
          [for (var i = 0; i < 12; i++) '/f/item$i'],
          grid,
          7,
        );
        await pump(tester, 900, positions: positions);
        final before = {
          for (var i = 0; i < 12; i++) i: cellOf(tester, '/f/item$i'),
        };
        await pump(tester, 400, positions: positions);
        for (var i = 0; i < 12; i++) {
          expect(cellOf(tester, '/f/item$i'), before[i]);
        }
        final scroll = find.byKey(
          const ValueKey('icon view horizontal scroll'),
        );
        expect(scroll, findsOneWidget);
        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(of: scroll, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        // Seven columns do not fit in 400 pt.
        expect(position.maxScrollExtent, greaterThan(0));
      },
    );
  });

  group('in the window', () {
    late Directory root;
    late Directory config;
    late IconPositions store;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            GlassRegistry.channel,
            (call) async => true,
          );
      root = Directory.systemTemp.createTempSync('mustache-free');
      config = Directory.systemTemp.createTempSync('mustache-free-config');
      for (final name in [
        'delta.txt',
        'alfa.txt',
        'charlie.txt',
        'bravo.txt',
      ]) {
        File('${root.path}/$name').writeAsStringSync('x');
      }
      store = IconPositions('${config.path}/positions.json');
    });

    tearDown(() {
      root.deleteSync(recursive: true);
      config.deleteSync(recursive: true);
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MustacheWindow(
            start: root.path,
            places: [Place('home', root.path, PlaceKind.home)],
            trash: Place('Trash', '${root.path}/.Trash', PlaceKind.trash),
            settings: Settings('${config.path}/s.json'),
            iconPositions: store,
            iconsEnv: {'SILICA_ICONS_DIR': config.path},
          ),
        ),
      );
    }

    Offset cellOf(WidgetTester tester, String name) {
      final cell = tester.widget<AnimatedPositioned>(
        find.byKey(ValueKey('cell ${root.path}/$name')),
      );
      return Offset(cell.left!, cell.top!);
    }

    Future<void> backgroundMenu(WidgetTester tester) async {
      await tester.tapAt(
        // The view starts under the glass toolbar (R1.9).
        tester.getTopLeft(find.byType(IconView)) +
            const Offset(420, 230 + toolbarHeight),
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();
    }

    testWidgets(
      'Sort By › None keeps the icons where they are, saved per folder',
      (tester) async {
        await pump(tester);
        final before = cellOf(tester, 'alfa.txt');
        await backgroundMenu(tester);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(
          location: tester.getCenter(find.text('Sort By')),
        );
        await mouse.moveBy(const Offset(2, 0));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();
        await mouse.moveTo(tester.getCenter(find.text('None')));
        await tester.pump();
        await tester.tap(find.text('None'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(store.of(root.path).free, isTrue);
        expect(store.of(root.path).icons.keys, hasLength(4));
        // On the free grid, in the same order: the first icon is still first.
        expect(cellOf(tester, 'alfa.txt').dy, before.dy);
        expect(IconPositions(store.path).of(root.path).free, isTrue);
      },
    );

    testWidgets(
      'a dragged icon stays where it is dropped; the threshold is ~8 pt',
      (tester) async {
        final g = FreeGrid.of();
        store.put(
          root.path,
          FolderArrangement(
            free: true,
            icons: arrangeOnGrid(
              ['alfa.txt', 'bravo.txt', 'charlie.txt', 'delta.txt'],
              g,
              4,
            ),
          ),
        );
        await pump(tester);
        final start = cellOf(tester, 'alfa.txt');
        final at = tester.getCenter(
          find.byKey(ValueKey('${root.path}/alfa.txt')),
        );
        // 6 pt: no drag.
        var gesture = await tester.startGesture(
          at,
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveBy(const Offset(6, 0));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 400));
        expect(cellOf(tester, 'alfa.txt'), start);
        // A real drag: 60 to the right and 250 down.
        gesture = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(6, 25));
          await tester.pump();
        }
        await gesture.up();
        await tester.pump();
        expect(cellOf(tester, 'alfa.txt'), start + const Offset(60, 250));
        expect(
          IconPositions(store.path).of(root.path).icons['alfa.txt'],
          g.cell(0, 0) + const Offset(60, 250),
        );
        await tester.pump(const Duration(milliseconds: 400));
      },
    );

    testWidgets(
      'Clean Up: after ~350 ms the icon slides to the nearest free cell',
      (tester) async {
        final g = FreeGrid.of();
        store.put(
          root.path,
          FolderArrangement(
            free: true,
            icons: {
              'alfa.txt': g.cell(0, 0),
              'bravo.txt': g.cell(1, 0),
              'charlie.txt': g.cell(2, 0),
              'delta.txt': g.cell(3, 1) + const Offset(17, -12),
            },
          ),
        );
        await pump(tester);
        final off = cellOf(tester, 'delta.txt');
        await backgroundMenu(tester);
        await tester.tap(find.text('Clean Up'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(cellOf(tester, 'delta.txt'), off);
        await tester.pump(const Duration(milliseconds: 60));
        final target = off - const Offset(17, -12);
        final animated = tester.widget<AnimatedPositioned>(
          find.byKey(ValueKey('cell ${root.path}/delta.txt')),
        );
        expect(animated.duration, cleanUpDuration);
        expect(Offset(animated.left!, animated.top!), target);
        // Half-way it is between the two; at the end on the cell.
        await tester.pump(const Duration(milliseconds: 100));
        final mid = tester.getTopLeft(
          find.byKey(ValueKey('cell ${root.path}/delta.txt')),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final end = tester.getTopLeft(
          find.byKey(ValueKey('cell ${root.path}/delta.txt')),
        );
        expect(mid, isNot(end));
        expect(store.of(root.path).icons['delta.txt'], g.cell(3, 1));
        expect(store.of(root.path).icons['alfa.txt'], g.cell(0, 0));
      },
    );

    testWidgets('⌥⌘1 lays out every icon by name at once', (tester) async {
      final g = FreeGrid.of();
      store.put(
        root.path,
        FolderArrangement(
          free: true,
          icons: {
            'delta.txt': g.cell(0, 0),
            'charlie.txt': g.cell(1, 0),
            'bravo.txt': g.cell(2, 2) + const Offset(5, 5),
            'alfa.txt': g.cell(4, 1),
          },
        ),
      );
      await pump(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      final icons = store.of(root.path).icons;
      final columns = g.columnsFor(tester.getSize(find.byType(IconView)).width);
      expect(
        icons,
        arrangeOnGrid(
          ['alfa.txt', 'bravo.txt', 'charlie.txt', 'delta.txt'],
          g,
          columns,
        ),
      );
      expect(store.of(root.path).free, isTrue);
      // No animation.
      expect(
        tester
            .widget<AnimatedPositioned>(
              find.byKey(ValueKey('cell ${root.path}/alfa.txt')),
            )
            .duration,
        Duration.zero,
      );
      expect(cellOf(tester, 'alfa.txt').dy, cellOf(tester, 'delta.txt').dy);
    });

    testWidgets('arrows move spatially among free icons', (tester) async {
      final g = FreeGrid.of();
      store.put(
        root.path,
        FolderArrangement(
          free: true,
          icons: {
            'alfa.txt': g.cell(0, 0),
            'bravo.txt': g.cell(0, 2),
            'charlie.txt': g.cell(3, 0),
            'delta.txt': g.cell(5, 3),
          },
        ),
      );
      await pump(tester);
      Color? capsule(String name) =>
          (tester
                      .widget<DecoratedBox>(
                        find.byKey(ValueKey('name ${root.path}/$name 0')),
                      )
                      .decoration
                  as BoxDecoration)
              .color;
      await tester.tap(find.byKey(ValueKey('${root.path}/alfa.txt')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(capsule('bravo.txt'), isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(capsule('charlie.txt'), isNotNull);
      expect(capsule('alfa.txt'), isNull);
    });

    testWidgets('a new file takes the first free cell', (tester) async {
      final g = FreeGrid.of();
      store.put(
        root.path,
        FolderArrangement(
          free: true,
          icons: {
            'alfa.txt': g.cell(0, 0),
            'bravo.txt': g.cell(2, 0),
            'charlie.txt': g.cell(3, 0),
          },
        ),
      );
      await pump(tester);
      expect(store.of(root.path).icons['delta.txt'], g.cell(1, 0));
    });
  });
}
