import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
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
  });

  group('storage', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('mustache-pos'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('positions survive a restart, per folder', () {
      final store = IconPositions('${dir.path}/state/p.json');
      store.put(
        '/x',
        FolderArrangement(free: true, icons: {'a': const Offset(10, 20)}),
      );
      final again = IconPositions('${dir.path}/state/p.json');
      expect(again.of('/x').free, isTrue);
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
        tester.getTopLeft(find.byType(IconView)) + const Offset(420, 230),
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
