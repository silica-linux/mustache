import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/drag.dart';
import 'package:mustache/src/list_view.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

import 'kit.dart';

void main() {
  test('valid destinations and different disks', () {
    const payload = DragPayload(['/c/a.txt', '/c/Cartella'], '/c');
    expect(canDrop(payload, '/c/Altra'), isTrue);
    expect(canDrop(payload, '/c'), isFalse);
    expect(canDrop(payload, '/c/Cartella'), isFalse);
    expect(canDrop(payload, '/c/Cartella/dentro'), isFalse);
    const mounts = [
      MountPoint('/', 'ext4', '/dev/nvme0n1p2'),
      MountPoint('/media/chiave', 'vfat', '/dev/sdb1'),
    ];
    expect(
      dropCopies(['/home/a'], '/home/b', alt: false, mounts: mounts),
      isFalse,
    );
    expect(
      dropCopies(['/home/a'], '/media/chiave', alt: false, mounts: mounts),
      isTrue,
    );
    expect(
      dropCopies(['/home/a'], '/home/b', alt: true, mounts: mounts),
      isTrue,
    );
    expect(mountOf('/media/chiaveX/f', mounts), '/');
    // ⌘ moves even to another disk; ⌥ still copies.
    expect(
      dropCopies(
        ['/home/a'],
        '/media/chiave',
        alt: false,
        meta: true,
        mounts: mounts,
      ),
      isFalse,
    );
    expect(
      dropCopies(['/home/a'], '/home/b', alt: true, meta: true, mounts: mounts),
      isTrue,
    );
  });

  group('in the window', () {
    late Directory home;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            GlassRegistry.channel,
            (call) async => true,
          );
      home = Directory.systemTemp.createTempSync('mustache-trascina');
      Directory('${home.path}/Doc/Dentro').createSync(recursive: true);
      File('${home.path}/Doc/nota.txt').writeAsStringSync('ciao');
    });

    tearDown(() => home.deleteSync(recursive: true));

    Future<void> pump(WidgetTester tester) async {
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
          ),
        ),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 10));
      }
    }

    Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
      final mouse = await tester.startGesture(
        from,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 20));
      await mouse.moveBy(const Offset(6, 0));
      await tester.pump();
      await mouse.moveTo(to);
      await tester.pump();
      // The image in flight: the pill with the name.
      expect(find.byType(DragImage), findsOneWidget);
      await mouse.up();
      await tester.pump();
    }

    testWidgets('onto a folder it moves; with ⌥ it copies', (tester) async {
      await pump(tester);
      await drag(
        tester,
        tester.getCenter(find.text('nota.txt')),
        tester.getCenter(find.text('Dentro')),
      );
      await settle(tester);
      expect(File('${home.path}/Doc/Dentro/nota.txt').existsSync(), isTrue);
      expect(File('${home.path}/Doc/nota.txt').existsSync(), isFalse);

      // Out again, onto home in the sidebar, with ⌥: copy.
      await tester.tap(find.text('Dentro'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Dentro'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await drag(
        tester,
        tester.getCenter(find.text('nota.txt')),
        tester.getCenter(find.text('casa')),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await settle(tester);
      expect(File('${home.path}/nota.txt').existsSync(), isTrue);
      expect(File('${home.path}/Doc/Dentro/nota.txt').existsSync(), isTrue);
    });

    testWidgets('the drag is handed to Ossido at once, held where grabbed', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SilicaDrag.channel, (call) async {
            calls.add(call);
            return false;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SilicaDrag.channel, null),
      );
      await pump(tester);
      final name = tester.getCenter(find.text('nota.txt'));
      final mouse = await tester.startGesture(
        name,
        kind: PointerDeviceKind.mouse,
      );
      await mouse.moveBy(const Offset(6, 0));
      await tester.pump();
      for (var i = 0; i < 10 && calls.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      // Still inside the window, the files already belong to Ossido's drag.
      expect(calls.single.method, 'start');
      final args = calls.single.arguments as Map;
      expect(args['uris'], [Uri.file('${home.path}/Doc/nota.txt').toString()]);
      final icon = args['icon'] as Map;
      // The grab point is inside the image, on the pill (not its corner).
      expect(icon['x'], allOf(greaterThan(0), lessThan(icon['width'])));
      expect(icon['y'], allOf(greaterThan(0), lessThan(icon['height'])));
      // Not taken (outside Silica): the image travels in the window, the row grays.
      expect(find.byKey(const ValueKey('drag image')), findsOneWidget);
      await mouse.up();
      await tester.pump();
      expect(find.byKey(const ValueKey('drag image')), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('taken by Ossido: its events light the folder and drop there', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SilicaDrag.channel, (call) async => true);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SilicaDrag.channel, null),
      );
      Future<void> embedder(String method, Map<String, Object?> args) =>
          tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            SilicaDrag.channel.name,
            const JSONMethodCodec().encodeMethodCall(MethodCall(method, args)),
            (_) {},
          );
      await pump(tester);
      final mouse = await tester.startGesture(
        tester.getCenter(find.text('nota.txt')),
        kind: PointerDeviceKind.mouse,
      );
      await mouse.moveBy(const Offset(6, 0));
      await tester.pump();
      await settle(tester);
      // Ossido draws the image now; the embedder cancels Flutter's press.
      expect(find.byKey(const ValueKey('drag image')), findsNothing);
      await mouse.cancel();
      await tester.pump();
      final folder = tester.getCenter(find.text('Dentro'));
      await embedder('enter', {'x': folder.dx, 'y': folder.dy});
      await tester.pump();
      final lit = tester.widget<ListRowBackground>(
        find.descendant(
          of: find.ancestor(
            of: find.text('Dentro'),
            matching: find.byKey(ValueKey('${home.path}/Doc/Dentro')),
          ),
          matching: find.byType(ListRowBackground),
        ),
      );
      expect(lit.dropTarget, isTrue);
      await embedder('drop', {
        'x': folder.dx,
        'y': folder.dy,
        'uris': [Uri.file('${home.path}/Doc/nota.txt').toString()],
      });
      await embedder('finished', {'action': 'move'});
      await settle(tester);
      expect(File('${home.path}/Doc/Dentro/nota.txt').existsSync(), isTrue);
      expect(File('${home.path}/Doc/nota.txt').existsSync(), isFalse);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
      'a drop from another app goes into the folder under the pointer',
      (tester) async {
        final outside = Directory.systemTemp.createTempSync('mustache-fuori');
        addTearDown(() => outside.deleteSync(recursive: true));
        File('${outside.path}/arrivato.txt').writeAsStringSync('da fuori');
        await pump(tester);
        Future<void> drop(Offset at, List<String> paths) =>
            tester.binding.defaultBinaryMessenger.handlePlatformMessage(
              SilicaDrag.channel.name,
              const JSONMethodCodec().encodeMethodCall(
                MethodCall('drop', {
                  'x': at.dx,
                  'y': at.dy,
                  'uris': [for (final p in paths) Uri.file(p).toString()],
                }),
              ),
              (_) {},
            );
        await drop(tester.getCenter(find.text('Dentro')), [
          '${outside.path}/arrivato.txt',
        ]);
        await settle(tester);
        expect(
          File('${home.path}/Doc/Dentro/arrivato.txt').existsSync(),
          isTrue,
        );
        // On the background: into the open folder.
        File('${outside.path}/secondo.txt').writeAsStringSync('ancora');
        await drop(const Offset(600, 600), ['${outside.path}/secondo.txt']);
        await settle(tester);
        expect(File('${home.path}/Doc/secondo.txt').existsSync(), isTrue);
      },
    );

    testWidgets('spring-loaded folder: hovering opens it', (tester) async {
      await pump(tester);
      final mouse = await tester.startGesture(
        tester.getCenter(find.text('nota.txt')),
        kind: PointerDeviceKind.mouse,
      );
      await mouse.moveBy(const Offset(6, 0));
      await tester.pump();
      await mouse.moveTo(tester.getCenter(find.text('Dentro')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      // Now the window shows Dentro (empty).
      // An empty folder shows no text (R3.10): the title says it.
      expect(tester.widget<Text>(titleText()).data, 'Dentro');
      await mouse.cancel();
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
