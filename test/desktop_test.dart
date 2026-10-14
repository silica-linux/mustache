import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/desktop.dart';
import 'package:mustache/src/icon_arrange.dart';
import 'package:mustache/src/l10n.dart';
import 'package:mustache/src/model.dart';

Entry _entry(String name, {bool dir = false}) => Entry(
  name: name,
  path: '/d/$name',
  isDirectory: dir,
  size: 0,
  modified: DateTime(2026),
);

void main() {
  const screen = Size(2560, 1440);
  const grid = DesktopGrid(screen);

  group('grid (MU-90, R15.1)', () {
    test('first icon 18 pt from the right edge and 40 from the top', () {
      final first = grid.cell(0, 0);
      expect(first.dx + desktopIconSide / 2, 2560 - 18);
      expect(first.dy, 40);
      expect(grid.cell(1, 0).dx, first.dx - 124);
      expect(grid.cell(0, 1).dy, 40 + 148);
    });

    test(
      '8 rows on a 1440 pt display, filled top to bottom then leftwards',
      () {
        expect(grid.rows, 8);
        expect(grid.nth(0), (0, 0));
        expect(grid.nth(7), (0, 7));
        expect(grid.nth(8), (1, 0));
      },
    );

    test('cells round trip, and the nearest free cell avoids taken ones', () {
      expect(grid.cellOf(grid.cell(3, 2) + const Offset(20, -30)), (3, 2));
      final taken = {(0, 0)};
      expect(grid.nearestFree(grid.cell(0, 0), taken), isNot(grid.cell(0, 0)));
      expect(grid.firstFree(taken), grid.cell(0, 1));
    });
  });

  group('layout', () {
    final icons = [
      for (final n in ['a', 'b', 'c']) DesktopIcon.item(_entry(n)),
    ];

    test('sorted: the icons fill the grid in order', () {
      final p = layoutDesktop(icons, grid, free: false);
      expect(p['a'], grid.cell(0, 0));
      expect(p['c'], grid.cell(0, 2));
    });

    test(
      'free: stored positions stay, new icons take the first free cells',
      () {
        final stored = {'b': grid.cell(0, 0), 'a': const Offset(1000, 500)};
        final p = layoutDesktop(icons, grid, free: true, stored: stored);
        expect(p['b'], grid.cell(0, 0));
        expect(p['a'], const Offset(1000, 500));
        expect(p['c'], grid.cell(0, 1));
      },
    );

    test(
      'Clean Up moves only the off-grid icons, to the nearest free cell',
      () {
        final p = cleanUpDesktop({
          'a': grid.cell(0, 0),
          'b': grid.cell(0, 0) + const Offset(-10, 20),
        }, grid);
        expect(p['a'], grid.cell(0, 0));
        expect(grid.onGrid(p['b']!), isTrue);
        expect(p['b'], isNot(grid.cell(0, 0)));
      },
    );

    test(
      'stacks group a kind with more than one item; an open stack spreads',
      () {
        final order = [_entry('x.png'), _entry('y.png'), _entry('notes.txt')];
        String kind(Entry e) => e.name.endsWith('.png') ? 'Image' : 'Text';
        final grouped = groupStacks(order, kind);
        expect(grouped.map((i) => i.key), ['stack:Image', 'notes.txt']);
        expect(grouped.first.members.length, 2);
        final open = layoutDesktop(
          grouped,
          grid,
          free: false,
          openStack: 'stack:Image',
        );
        expect(open['stack:Image'], grid.cell(0, 0));
        expect(open['x.png'], grid.cell(0, 1));
        expect(open['notes.txt'], grid.cell(0, 3));
      },
    );
  });

  test('actions from the shell carry a serial', () {
    expect(parseDesktopAction('sort:name 4'), 'sort:name');
    expect(parseDesktopAction('newFolder 12'), 'newFolder');
    expect(parseDesktopAction('broken'), isNull);
    expect(parseDesktopAction('x y'), isNull);
    expect(shellQuote("it's"), "'it'\\''s'");
  });

  test('the desktop folder from user-dirs, else ~/Desktop', () {
    expect(
      desktopFolderOf({'HOME': '/h'}, 'XDG_DESKTOP_DIR="\$HOME/Scrivania"\n'),
      '/h/Scrivania',
    );
    expect(desktopFolderOf({'HOME': '/h'}, null), '/h/Desktop');
  });

  group('the desktop view', () {
    late Directory home;
    late Directory folder;
    late List<MethodCall> shell;

    setUp(() {
      home = Directory.systemTemp.createTempSync('desktop');
      folder = Directory('${home.path}/Desktop')..createSync();
      for (final n in ['one.txt', 'two.txt']) {
        File('${folder.path}/$n').writeAsStringSync(n);
      }
      shell = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('silica/shell', JSONMethodCodec()),
            (call) async {
              shell.add(call);
              return true;
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('silica/shell', JSONMethodCodec()),
            null,
          );
      home.deleteSync(recursive: true);
    });

    Future<DesktopViewState> pump(WidgetTester tester) async {
      tester.view.physicalSize = screen;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        AppLocalizationsScope(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: DesktopView(
              folder: folder.path,
              positions: IconPositions('${home.path}/positions.json'),
              choices: DesktopChoices('${home.path}/desktop.json'),
              env: {'HOME': home.path},
              kindOf: (e) => 'Text',
              watch: false,
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.state<DesktopViewState>(find.byType(DesktopView));
    }

    testWidgets('icons start at the top right, a click selects', (
      tester,
    ) async {
      final state = await pump(tester);
      expect(state.positions.keys, containsAll(['one.txt', 'two.txt']));
      final first = state.positions['one.txt']!;
      expect(first, grid.cell(0, 0));
      await tester.tapAt(first + const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 600));
      expect(state.selected, {'one.txt'});
      expect(
        shell.any(
          (c) =>
              c.method == 'broadcast' &&
              (c.arguments as Map)['topic'] == 'desktop.state',
        ),
        isTrue,
      );
    });

    testWidgets('a right click asks the shell for the menu', (tester) async {
      final state = await pump(tester);
      final at = state.positions['two.txt']! + const Offset(0, 40);
      await tester.tapAt(at, buttons: kSecondaryButton);
      await tester.pump();
      final menu = shell.lastWhere(
        (c) =>
            c.method == 'broadcast' &&
            (c.arguments as Map)['topic'] == 'desktopmenu',
      );
      expect((menu.arguments as Map)['value'], endsWith(' items'));
      await tester.tapAt(const Offset(200, 600), buttons: kSecondaryButton);
      await tester.pump();
      expect((shell.last.arguments as Map)['value'], endsWith(' desktop'));
    });

    testWidgets('menu actions: new folder, sort, trash', (tester) async {
      final state = await pump(tester);
      state.runAction('newFolder');
      await tester.pump();
      expect(
        folder.listSync().map(
          (e) => e.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
        ),
        contains(l10n.newFolderName),
      );
      state.runAction('sort:name');
      await tester.pump();
      expect(state.positions['one.txt'], isNotNull);
      await tester.tapAt(state.positions['two.txt']! + const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 600));
      state.runAction('trash');
      await tester.pump();
      expect(File('${folder.path}/two.txt').existsSync(), isFalse);
      expect(
        File('${home.path}/.local/share/Trash/files/two.txt').existsSync(),
        isTrue,
      );
    });

    testWidgets('arrow keys move the selection between icons', (tester) async {
      final state = await pump(tester);
      await tester.tapAt(state.positions['one.txt']! + const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(state.selected, {'two.txt'});
    });
  });
}
