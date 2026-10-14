import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/desktop.dart';
import 'package:mustache/src/icon_view.dart' show EntryIcon;
import 'package:silica_ui/silica_ui.dart' show SilicaDrag;
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

    /// The tags the fake `user.xdg.tags` holds, by path.
    late Map<String, List<String>> tags;

    setUp(() {
      tags = {};
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
              readTags: (p) => tags[p] ?? const [],
              writeTags: (p, t) {
                tags[p] = t;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.state<DesktopViewState>(find.byType(DesktopView));
    }

    /// Lets the drag's start finish: reading the image back is real asynchronous work.
    Future<void> settleDragStart(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump();
      }
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

    Map<String, Object?> lastState() {
      final call = shell.lastWhere(
        (c) =>
            c.method == 'broadcast' &&
            (c.arguments as Map)['topic'] == 'desktop.state',
      );
      return jsonDecode((call.arguments as Map)['value'] as String)
          as Map<String, Object?>;
    }

    testWidgets('the state carries the colour tags every selected item has', (
      tester,
    ) async {
      tags['${folder.path}/one.txt'] = ['Red', 'Blue', 'Work'];
      tags['${folder.path}/two.txt'] = ['Rosso'];
      final state = await pump(tester);
      await tester.tapAt(state.positions['one.txt']! + const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 600));
      expect(lastState()['tags'], ['red', 'blue']);
      expect(lastState()['folder'], false);
      // A tag in another language keeps its colour; only the shared ones are reported.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tapAt(state.positions['two.txt']! + const Offset(0, 40));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump(const Duration(milliseconds: 600));
      expect(state.selected, {'one.txt', 'two.txt'});
      expect(lastState()['tags'], ['red']);
      await tester.tapAt(const Offset(200, 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(lastState()['tags'], isEmpty);
    });

    testWidgets('the tag actions add the colour, or remove it from all', (
      tester,
    ) async {
      final one = '${folder.path}/one.txt';
      final two = '${folder.path}/two.txt';
      tags[one] = ['Work', 'Rosso'];
      final state = await pump(tester);
      await tester.tapAt(state.positions['one.txt']! + const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 600));
      state.runAction('tag:blue');
      expect(tags[one], ['Work', 'Rosso', l10n.tagBlue]);
      expect(lastState()['tags'], ['red', 'blue']);
      // The colour all the items have is removed (in any language).
      state.runAction('tag:red');
      expect(tags[one], ['Work', l10n.tagBlue]);
      // With several items, one lacking it: it is added to all.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tapAt(state.positions['two.txt']! + const Offset(0, 40));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump(const Duration(milliseconds: 600));
      state.runAction('tag:blue');
      expect(tags[one], ['Work', l10n.tagBlue]);
      expect(tags[two], [l10n.tagBlue]);
      state.runAction('tag:blue');
      expect(tags[one], ['Work']);
      expect(tags[two], isEmpty);
      // An unknown colour does nothing.
      state.runAction('tag:pink');
      expect(tags[two], isEmpty);
    });

    testWidgets('Customize Folder… opens a window with Get Info on it', (
      tester,
    ) async {
      Directory('${folder.path}/Progetti').createSync();
      final state = await pump(tester);
      List<String> launches() => [
        for (final c in shell)
          if (c.method == 'launch') (c.arguments as Map)['command'] as String,
      ];
      // A file: nothing to customize.
      await tester.tapAt(state.positions['one.txt']! + const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 600));
      expect(lastState()['folder'], false);
      state.runAction('customize');
      expect(launches(), isEmpty);
      // One folder: the file manager starts with its Customize Folder section.
      await tester.tapAt(state.positions['Progetti']! + const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 600));
      expect(lastState()['folder'], true);
      state.runAction('customize');
      expect(launches(), hasLength(1));
      expect(
        launches().single,
        contains("'--customize=${folder.path}/Progetti'"),
      );
    });

    test('--customize=<folder> among the arguments', () {
      expect(customizeArgument(['--customize=/a/b c']), '/a/b c');
      expect(customizeArgument(['x', '--customize=']), isNull);
      expect(customizeArgument(['/a']), isNull);
    });

    testWidgets('arrow keys move the selection between icons', (tester) async {
      final state = await pump(tester);
      await tester.tapAt(state.positions['one.txt']! + const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(state.selected, {'two.txt'});
    });

    testWidgets('selecting never moves the icon or its name', (tester) async {
      final state = await pump(tester);
      final at = state.positions['one.txt']!;
      Finder inIcon(Finder f) => find.descendant(
        of: find.byKey(const ValueKey('desktop one.txt')),
        matching: f,
      );
      final icon = tester.getRect(inIcon(find.byType(EntryIcon)));
      final name = tester.getRect(find.text('one.txt'));
      expect(icon, Rect.fromLTWH(at.dx - 48, at.dy, 96, 96));
      await tester.tapAt(at + const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 600));
      expect(state.selected, {'one.txt'});
      expect(tester.getRect(inIcon(find.byType(EntryIcon))), icon);
      expect(tester.getRect(find.text('one.txt')), name);
      // The square: 108 × 108, 6 pt around the icon (MU-90).
      expect(
        tester.getRect(find.byKey(const ValueKey('desktop selection'))),
        Rect.fromLTWH(at.dx - 54, at.dy - 6, 108, 108),
      );
      // The capsule's top 104 pt below the icon's top, 17 pt tall.
      final capsule = tester.getRect(
        find
            .ancestor(
              of: find.text('one.txt'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(capsule.top, at.dy + 104);
      expect(capsule.height, 17);
    });

    testWidgets(
      'the rubber band selects by the icon or the name, not around them',
      (tester) async {
        final state = await pump(tester);
        final at = state.positions['one.txt']!;
        // On the name's line only.
        expect(state.keysIn(Rect.fromLTWH(at.dx - 4, at.dy + 110, 8, 4)), {
          'one.txt',
        });
        // Between the icon and the name, or beside the short name: nothing.
        expect(
          state.keysIn(Rect.fromLTWH(at.dx - 4, at.dy + 98, 8, 4)),
          isEmpty,
        );
        expect(
          state.keysIn(Rect.fromLTWH(at.dx + 44, at.dy + 110, 4, 4)),
          isEmpty,
        );
        // Drawn while dragging from empty desktop.
        final gesture = await tester.startGesture(at + const Offset(-200, 20));
        await gesture.moveTo(at + const Offset(0, 50));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('desktop rubber band')),
          findsOneWidget,
        );
        expect(state.selected, {'one.txt'});
        await gesture.up();
        await tester.pump();
        expect(find.byKey(const ValueKey('desktop rubber band')), findsNothing);
      },
    );

    testWidgets(
      'a drag: the image follows the pointer, the icons stay dimmed, the drop moves them',
      (tester) async {
        final state = await pump(tester);
        final one = state.positions['one.txt']!;
        final two = state.positions['two.txt']!;
        await tester.tapAt(one + const Offset(0, 40));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.tapAt(two + const Offset(0, 40));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump(const Duration(milliseconds: 600));
        expect(state.selected, {'one.txt', 'two.txt'});

        final drag = await tester.startGesture(one + const Offset(0, 40));
        await tester.pump(const Duration(milliseconds: 100));
        for (var i = 1; i <= 6; i++) {
          await drag.moveTo(
            one + const Offset(0, 40) + Offset(-30.0 * i, 10.0 * i),
          );
          await tester.pump();
        }
        // Outside Silica the image travels inside the desktop.
        await settleDragStart(tester);
        expect(state.dragged, {'one.txt', 'two.txt'});
        expect(state.positions['one.txt'], one);
        expect(
          find.byKey(const ValueKey('desktop drag image')),
          findsOneWidget,
        );
        final dimmed = tester.widget<Opacity>(
          find
              .descendant(
                of: find.byKey(const ValueKey('desktop two.txt')),
                matching: find.byType(Opacity),
              )
              .first,
        );
        expect(dimmed.opacity, desktopDragDim);
        await drag.up();
        await tester.pump();
        // Each icon where its image was: moved by the whole movement of the pointer.
        expect(state.dragged, isEmpty);
        expect(state.positions['one.txt'], one + const Offset(-180, 60));
        expect(state.positions['two.txt'], two + const Offset(-180, 60));
        expect(find.byKey(const ValueKey('desktop drag image')), findsNothing);
        expect(state.selected, {'one.txt', 'two.txt'});
      },
    );

    testWidgets('on a sorted desktop a dropped icon travels back to its cell', (
      tester,
    ) async {
      final state = await pump(tester);
      state.runAction('sort:name');
      await tester.pump();
      final one = state.positions['one.txt']!;
      final drag = await tester.startGesture(one + const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 600));
      for (var i = 1; i <= 4; i++) {
        await drag.moveTo(one + const Offset(0, 40) + Offset(-50.0 * i, 0));
        await tester.pump();
      }
      await settleDragStart(tester);
      await drag.up();
      await tester.pump();
      expect(state.positions['one.txt'], one);
      await tester.pump(const Duration(milliseconds: 100));
      final left = tester
          .getTopLeft(find.byKey(const ValueKey('desktop one.txt')))
          .dx;
      expect(left, lessThan(one.dx - desktopPitchX / 2 - 1));
      expect(left, greaterThan(one.dx - desktopPitchX / 2 - 200));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('desktop one.txt'))).dx,
        one.dx - desktopPitchX / 2,
      );
    });

    testWidgets('dropped back by Ossido, the icons keep where they were grabbed', (
      tester,
    ) async {
      final state = await pump(tester);
      final one = state.positions['one.txt']!;
      // Ossido takes the drag.
      final starts = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SilicaDrag.channel,
        (call) async {
          starts.add(call);
          return true;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SilicaDrag.channel,
          null,
        ),
      );
      final sounds = listenSounds(tester);
      final press = one + const Offset(10, 40);
      final drag = await tester.startGesture(press);
      await tester.pump(const Duration(milliseconds: 600));
      await drag.moveTo(press + const Offset(-20, 0));
      await tester.pump();
      await settleDragStart(tester);
      expect(starts.single.method, 'start');
      final args = starts.single.arguments as Map;
      expect(args['uris'], [Uri.file('${folder.path}/one.txt').toString()]);
      final icon = args['icon'] as Map;
      // The image is the icon as drawn, its grabbed point under the pointer.
      expect(icon['width'], desktopPitchX);
      expect(icon['x'], (press.dx - (one.dx - desktopPitchX / 2)).round());
      expect(icon['y'], (press.dy - (one.dy - desktopSelectionPad)).round());
      // The embedder cancels the gesture; Ossido drops the files back on the desktop.
      await drag.cancel();
      await tester.pump();
      expect(state.dragged, {'one.txt'});
      Future<void> fromOssido(String method, Object? args) =>
          tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            SilicaDrag.channel.name,
            SilicaDrag.channel.codec.encodeMethodCall(MethodCall(method, args)),
            (_) {},
          );
      await fromOssido('drop', {
        'x': press.dx - 300,
        'y': press.dy + 100,
        'uris': [Uri.file('${folder.path}/one.txt').toString()],
      });
      await fromOssido('finished', {'action': 'move'});
      await tester.pump();
      expect(state.dragged, isEmpty);
      expect(state.positions['one.txt'], one + const Offset(-300, 100));
      // Free desktop: the selection is back ~275 ms after the release, not at once.
      const square = ValueKey('desktop selection');
      expect(find.byKey(square), findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(square), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(square), findsOneWidget);
      // Repositioning icons on the desktop is silent.
      expect(sounds, isEmpty);
    });

    testWidgets('Duplicate plays the move and copy sound, once', (
      tester,
    ) async {
      final sounds = listenSounds(tester);
      final state = await pump(tester);
      await tester.tapAt(state.positions['one.txt']! + const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 600));
      state.runAction('duplicate');
      await tester.pump();
      expect(sounds, ['file-transfer']);
      state.runAction('duplicate');
      await tester.pump();
      expect(sounds, ['file-transfer', 'file-transfer']);
    });

    testWidgets('files moved onto the desktop sound once, when moved', (
      tester,
    ) async {
      final sounds = listenSounds(tester);
      final state = await pump(tester);
      final other = Directory.systemTemp.createTempSync('mustache_other');
      addTearDown(() => other.deleteSync(recursive: true));
      File('${other.path}/a.txt').writeAsStringSync('a');
      File('${other.path}/b.txt').writeAsStringSync('b');
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SilicaDrag.channel.name,
        SilicaDrag.channel.codec.encodeMethodCall(
          MethodCall('drop', {
            'x': 100.0,
            'y': 100.0,
            'uris': [
              Uri.file('${other.path}/a.txt').toString(),
              Uri.file('${other.path}/b.txt').toString(),
            ],
          }),
        ),
        (_) {},
      );
      await tester.pump();
      expect(sounds, ['file-transfer']);
      expect(state.positions.keys, containsAll(['a.txt', 'b.txt']));
    });

    testWidgets('the capsule turns grey when the desktop is not active', (
      tester,
    ) async {
      final state = await pump(tester);
      await tester.tapAt(state.positions['one.txt']! + const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 600));
      BoxDecoration capsule() =>
          tester
                  .widget<Container>(
                    find
                        .ancestor(
                          of: find.text('one.txt'),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(capsule().color, desktopCapsule);
      expect(capsule().borderRadius, BorderRadius.circular(8.5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(capsule().color, const Color(0xFFD0D0D0));
      // The square stays.
      expect(find.byKey(const ValueKey('desktop selection')), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(capsule().color, desktopCapsule);
    });

    test('measured values of the band, the badge and the square', () {
      expect(desktopBandFill.a, closeTo(0.15, 0.01));
      expect(desktopBandBorder.a, closeTo(0.57, 0.01));
      expect(desktopSelectionSide, 108);
      expect(desktopSelectionOutlineWidth, 2);
      expect(desktopBadgeFromPointer.dx, greaterThan(0));
      expect(desktopBadgeFromPointer.dy, greaterThan(0));
    });

    testWidgets('Move to Trash plays its sound', (tester) async {
      final sounds = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('silica/dbus', JSONMethodCodec()),
        (call) async {
          final args = call.arguments as Map;
          if (args['method'] == 'PlaySound')
            sounds.add((args['args'] as List).single);
          return const <Object?>[];
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('silica/dbus', JSONMethodCodec()),
          null,
        ),
      );
      final state = await pump(tester);
      await tester.tapAt(state.positions['one.txt']! + const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 600));
      state.runAction('trash');
      await tester.pump();
      expect(sounds, ['trash-move']);
      // Nothing selected, nothing moved: no sound.
      state.runAction('trash');
      await tester.pump();
      expect(sounds, ['trash-move']);
    });
  });
}

/// The interface sounds asked of silica-daemon (`PlaySound` on `silica/dbus`): a fake player.
List<String> listenSounds(WidgetTester tester) {
  const dbus = MethodChannel('silica/dbus', JSONMethodCodec());
  final sounds = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(dbus, (
    call,
  ) async {
    final args = call.arguments as Map;
    if (args['method'] == 'PlaySound') {
      sounds.add((args['args'] as List).single as String);
    }
    return const <Object?>[];
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      dbus,
      null,
    ),
  );
  return sounds;
}
