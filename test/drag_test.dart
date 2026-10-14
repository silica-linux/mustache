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
  test('destinazioni valide e dischi diversi', () {
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

  group('nella finestra', () {
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
            trash: Place('Cestino', '${home.path}/Cestino', PlaceKind.trash),
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
      // L'immagine in volo: la pillola con il nome.
      expect(find.byType(DragImage), findsOneWidget);
      await mouse.up();
      await tester.pump();
    }

    testWidgets('su una cartella sposta; con ⌥ copia', (tester) async {
      await pump(tester);
      await drag(
        tester,
        tester.getCenter(find.text('nota.txt')),
        tester.getCenter(find.text('Dentro')),
      );
      await settle(tester);
      expect(File('${home.path}/Doc/Dentro/nota.txt').existsSync(), isTrue);
      expect(File('${home.path}/Doc/nota.txt').existsSync(), isFalse);

      // Di nuovo fuori, sulla casa nella barra laterale, con ⌥: copia.
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

    testWidgets('cartella a molla: la sosta la apre', (tester) async {
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
      // Ora la finestra mostra Dentro (vuota).
      // Una cartella vuota non scrive niente (R3.10): lo dice il titolo.
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('titolo'))).data,
        'Dentro',
      );
      await mouse.cancel();
      await tester.pump();
    });
  });
}
