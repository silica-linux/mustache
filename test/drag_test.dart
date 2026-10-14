import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/drag.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

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

    testWidgets('outside the window the drag passes to Ossido', (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SilicaDrag.channel, (call) async {
            calls.add(call);
            return true;
          });
      await pump(tester);
      final mouse = await tester.startGesture(
        tester.getCenter(find.text('nota.txt')),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 20));
      await mouse.moveBy(const Offset(6, 0));
      await tester.pump();
      // Inside the window it stays a Flutter drag.
      await mouse.moveTo(const Offset(500, 300));
      await tester.pump();
      expect(calls, isEmpty);
      await mouse.moveTo(const Offset(1100, 300));
      await tester.pump();
      for (var i = 0; i < 10 && calls.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(calls.single.method, 'start');
      final args = calls.single.arguments as Map;
      expect(args['uris'], [Uri.file('${home.path}/Doc/nota.txt').toString()]);
      expect(args['icon'], isA<Map<Object?, Object?>>());
      // Leaving and coming back does not start it again.
      await mouse.moveTo(const Offset(1200, 300));
      await tester.pump();
      expect(calls, hasLength(1));
      await mouse.cancel();
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
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('title'))).data,
        'Dentro',
      );
      await mouse.cancel();
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
