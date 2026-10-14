// Dragging from every view of the window, and the slow click that renames (R8): neither a drag
// nor a rubber band nor a double click nor a click on the icon opens the field.

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/drag.dart';
import 'package:mustache/src/icon_view.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/rename_field.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  late Directory home;
  late Directory config;
  late List<MethodCall> starts;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GlassRegistry.channel, (call) async => true);
    starts = [];
    // Outside Silica: Ossido does not take the drag, the image stays in the window.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SilicaDrag.channel, (call) async {
          starts.add(call);
          return false;
        });
    home = Directory.systemTemp.createTempSync('mustache-trascina-viste');
    config = Directory.systemTemp.createTempSync('mustache-trascina-config');
    Directory('${home.path}/Cartella').createSync();
    File('${home.path}/alfa.txt').writeAsStringSync('a');
    File('${home.path}/bravo.txt').writeAsStringSync('b');
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SilicaDrag.channel, null);
    home.deleteSync(recursive: true);
    config.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester, String view) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: home.path,
          places: [Place('casa', home.path, PlaceKind.home)],
          trash: Place('Trash', '${home.path}/.Cestino', PlaceKind.trash),
          settings: Settings('${config.path}/s.json')..view = view,
          iconsEnv: {'SILICA_ICONS_DIR': config.path},
        ),
      ),
    );
  }

  /// Lets real async work (the image's bytes, the copies) finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  Finder name(String name) => find.text(name).first;

  /// The icon of an item in the icon view (above its name).
  Offset iconOf(WidgetTester tester, String file) {
    final cell = tester.getRect(
      find.byKey(ValueKey('cell ${home.path}/$file')),
    );
    return Offset(cell.center.dx, cell.top + defaultIconSide / 2 + 4);
  }

  /// Presses at `from`, moves by `by` in steps and checks that a drag started.
  Future<TestGesture> startDrag(
    WidgetTester tester,
    Offset from, {
    Offset by = const Offset(20, 0),
  }) async {
    final mouse = await tester.startGesture(
      from,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 20));
    for (var i = 1; i <= 4; i++) {
      await mouse.moveTo(from + by * (i / 4));
      await tester.pump();
    }
    return mouse;
  }

  group('the drag starts in every view', () {
    for (final (view, from) in [
      ('icons', 'icon'),
      ('icons', 'name'),
      ('list', 'name'),
      ('columns', 'name'),
      ('gallery', 'thumbnail'),
    ]) {
      testWidgets('$view, from the $from', (tester) async {
        await pump(tester, view);
        final at = switch ((view, from)) {
          ('icons', 'icon') => iconOf(tester, 'alfa.txt'),
          ('gallery', _) => tester.getCenter(
            find.byKey(ValueKey('thumbnail ${home.path}/alfa.txt')),
          ),
          _ => tester.getCenter(name('alfa.txt')),
        };
        final mouse = await startDrag(tester, at);
        expect(find.byKey(const ValueKey('drag image')), findsOneWidget);
        await settle(tester);
        expect(starts, hasLength(1));
        final args = starts.single.arguments as Map;
        expect(args['uris'], [Uri.file('${home.path}/alfa.txt').toString()]);
        expect(args['icon'], isA<Map<Object?, Object?>>());
        if (view == 'icons') {
          // The icon stays in place, dimmed.
          final dimmed = tester.widget<Opacity>(
            find
                .descendant(
                  of: find.byKey(ValueKey('cell ${home.path}/alfa.txt')),
                  matching: find.byType(Opacity),
                )
                .first,
          );
          expect(dimmed.opacity, dragDim);
        }
        await mouse.up();
        await tester.pump();
        expect(find.byKey(const ValueKey('drag image')), findsNothing);
        // Released on itself: nothing moved, and no rename.
        await tester.pump(const Duration(seconds: 1));
        expect(File('${home.path}/alfa.txt').existsSync(), isTrue);
        expect(find.byType(RenameField), findsNothing);
      });
    }

    testWidgets('several items: one image with the count badge', (
      tester,
    ) async {
      await pump(tester, 'icons');
      await tester.tap(name('alfa.txt'));
      await tester.pump(const Duration(milliseconds: 310));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.tap(name('bravo.txt'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump(const Duration(milliseconds: 310));
      final mouse = await startDrag(tester, iconOf(tester, 'bravo.txt'));
      await settle(tester);
      final args = starts.single.arguments as Map;
      expect((args['uris'] as List).toSet(), {
        Uri.file('${home.path}/alfa.txt').toString(),
        Uri.file('${home.path}/bravo.txt').toString(),
      });
      await mouse.up();
      await tester.pump(const Duration(seconds: 1));
      Set<String> selected() => {
        for (final p in tester.widget<IconView>(find.byType(IconView)).selected)
          displayName(p),
      };
      expect(selected(), {'alfa.txt', 'bravo.txt'});
      // A click without a drag on one of them leaves it alone selected, on release.
      final click = await tester.startGesture(
        iconOf(tester, 'alfa.txt'),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(selected(), {'alfa.txt', 'bravo.txt'});
      await click.up();
      await tester.pump(const Duration(seconds: 1));
      expect(selected(), {'alfa.txt'});
    });
  });

  group('drop into a folder of the window', () {
    for (final view in ['icons', 'list', 'columns']) {
      testWidgets(view, (tester) async {
        await pump(tester, view);
        final mouse = await startDrag(
          tester,
          tester.getCenter(name('alfa.txt')),
        );
        await mouse.moveTo(tester.getCenter(name('Cartella')));
        await tester.pump();
        await mouse.up();
        await settle(tester);
        expect(File('${home.path}/Cartella/alfa.txt').existsSync(), isTrue);
        expect(File('${home.path}/alfa.txt').existsSync(), isFalse);
      });
    }

    testWidgets('the folder springs open after hovering', (tester) async {
      await pump(tester, 'icons');
      final mouse = await startDrag(tester, iconOf(tester, 'alfa.txt'));
      await mouse.moveTo(iconOf(tester, 'Cartella'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('title'))).data,
        displayName(home.path),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('title'))).data,
        'Cartella',
      );
      // Released there: the file goes into the folder now open.
      await mouse.moveBy(const Offset(0, 40));
      await tester.pump();
      await mouse.up();
      await settle(tester);
      expect(File('${home.path}/Cartella/alfa.txt').existsSync(), isTrue);
    });
  });

  group('rename on a slow click (R8)', () {
    Future<void> click(WidgetTester tester, Offset at) async {
      await tester.tapAt(at, kind: PointerDeviceKind.mouse);
      await tester.pump();
    }

    testWidgets('a slow second click on the name renames after ~440 ms', (
      tester,
    ) async {
      await pump(tester, 'icons');
      await click(tester, tester.getCenter(name('alfa.txt')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(RenameField), findsNothing);
      await click(tester, tester.getCenter(name('alfa.txt')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(RenameField), findsNothing);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(RenameField), findsOneWidget);
    });

    testWidgets('a click on the icon or a double click does not rename', (
      tester,
    ) async {
      await pump(tester, 'icons');
      await click(tester, tester.getCenter(name('alfa.txt')));
      await tester.pump(const Duration(milliseconds: 500));
      await click(tester, iconOf(tester, 'alfa.txt'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RenameField), findsNothing);
      // A double click on the name of the selected item (it opens the file instead).
      await click(tester, tester.getCenter(name('alfa.txt')));
      await tester.pump(const Duration(milliseconds: 100));
      await click(tester, tester.getCenter(name('alfa.txt')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RenameField), findsNothing);
    });

    testWidgets('a drag from the selected name does not rename', (
      tester,
    ) async {
      await pump(tester, 'icons');
      await click(tester, tester.getCenter(name('alfa.txt')));
      await tester.pump(const Duration(milliseconds: 500));
      final mouse = await startDrag(
        tester,
        tester.getCenter(name('alfa.txt')),
        by: const Offset(0, 120),
      );
      await mouse.up();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RenameField), findsNothing);
    });

    testWidgets('the rubber band never arms the rename', (tester) async {
      await pump(tester, 'icons');
      // The only selected item, its name clicked: then a rubber band from the background
      // that ends on it alone.
      await click(tester, tester.getCenter(name('alfa.txt')));
      await tester.pump(const Duration(milliseconds: 500));
      await click(tester, tester.getCenter(name('alfa.txt')));
      final view = tester.getRect(find.byType(IconView));
      final mouse = await tester.startGesture(
        view.bottomRight - const Offset(20, 20),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await mouse.moveTo(tester.getCenter(name('alfa.txt')));
      await tester.pump();
      expect(find.byKey(const ValueKey('rubber band')), findsOneWidget);
      await mouse.up();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RenameField), findsNothing);
      // A rubber band alone, starting near the selected item: no rename either.
      final band = await tester.startGesture(
        view.bottomRight - const Offset(20, 20),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await band.moveTo(iconOf(tester, 'alfa.txt'));
      await tester.pump();
      await band.up();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RenameField), findsNothing);
      // A press on a cell never starts a rubber band (its own drag).
      final drag = await startDrag(tester, iconOf(tester, 'alfa.txt'));
      expect(find.byKey(const ValueKey('rubber band')), findsNothing);
      await drag.up();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RenameField), findsNothing);
    });

    testWidgets('list: slow click on the name renames, on the row not', (
      tester,
    ) async {
      await pump(tester, 'list');
      await click(tester, tester.getCenter(name('alfa.txt')));
      await tester.pump(const Duration(milliseconds: 500));
      // On the row, away from the name.
      final row = tester.getRect(find.byKey(ValueKey('${home.path}/alfa.txt')));
      await click(tester, Offset(row.left + 260, row.center.dy));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RenameField), findsNothing);
      await click(tester, tester.getCenter(name('alfa.txt')));
      await tester.pump(const Duration(milliseconds: 460));
      expect(find.byType(RenameField), findsOneWidget);
    });
  });
}
