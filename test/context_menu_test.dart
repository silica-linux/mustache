import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  late Directory home;
  late Directory dir;
  late Map<String, String> env;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GlassRegistry.channel, (call) async => true);
    home = Directory.systemTemp.createTempSync('mustache-menu');
    dir = Directory('${home.path}/Documenti')..createSync();
    File('${dir.path}/nota.txt').writeAsStringSync('ciao');
    Directory('${dir.path}/Alfa').createSync();
    env = {
      'HOME': home.path,
      'XDG_DATA_HOME': '${home.path}/.local/share',
      'XDG_DATA_DIRS': '${home.path}/sys',
      'XDG_CONFIG_HOME': '${home.path}/.config',
      'XDG_CONFIG_DIRS': '${home.path}/etc',
    };
    for (final (id, name) in [('scrivi', 'Scrivi'), ('appunti', 'Appunti')]) {
      File('${home.path}/.local/share/applications/$id.desktop')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '[Desktop Entry]\nType=Application\nName=$name\nExec=$id %f\n'
          'MimeType=text/plain;\n',
        );
    }
    File('${home.path}/.config/mimeapps.list')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '[Default Applications]\ntext/plain=scrivi.desktop;\n',
      );
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
          start: dir.path,
          places: [Place('casa', home.path, PlaceKind.home)],
          trash: Place(
            'Cestino',
            '${home.path}/.local/share/Trash/files',
            PlaceKind.trash,
          ),
          settings: Settings('${home.path}/.config/s.json')..view = 'list',
          iconsEnv: env,
        ),
      ),
    );
  }

  Future<void> rightClick(WidgetTester tester, Offset at) async {
    await tester.tapAt(at, buttons: kSecondaryMouseButton);
    await tester.pump();
  }

  testWidgets('file: Apri con mostra la predefinita in cima, poi le altre', (
    tester,
  ) async {
    await pump(tester);
    final at = tester.getCenter(find.text('nota.txt'));
    await rightClick(tester, at);
    expect(find.text('Apri'), findsOneWidget);
    expect(find.text('Sposta nel Cestino'), findsOneWidget);
    // Il menu si apre con l'angolo sul puntatore (+1, −6).
    final panel = tester.getRect(find.byType(MenuPanel));
    expect(panel.topLeft, at + const Offset(1, -6));
    // Il sottomenu "Apri con".
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: at);
    await mouse.moveTo(tester.getCenter(find.text('Apri con')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('Scrivi (predefinita)'), findsOneWidget);
    expect(find.text('Appunti'), findsOneWidget);
    final defaultTop = tester.getTopLeft(find.text('Scrivi (predefinita)')).dy;
    expect(tester.getTopLeft(find.text('Appunti')).dy, greaterThan(defaultTop));
  });

  testWidgets('Sposta nel Cestino dal menu, che poi si chiude', (tester) async {
    await pump(tester);
    await rightClick(tester, tester.getCenter(find.text('nota.txt')));
    await tester.tap(find.text('Sposta nel Cestino'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(File('${dir.path}/nota.txt').existsSync(), isFalse);
    expect(find.byType(MenuPanel), findsNothing);
  });

  testWidgets(
    'la colonna Tipo è la famiglia del tipo di shared-mime-info (R3.3)',
    (tester) async {
      File('${home.path}/sys/mime/text/plain.xml')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '<mime-type type="text/plain"><comment>Plain text</comment>'
          '<comment xml:lang="it">Testo semplice</comment></mime-type>',
        );
      File(
        '${home.path}/sys/mime/globs2',
      ).writeAsStringSync('50:text/plain:*.txt\n');
      await pump(tester);
      // Il tipo viene da shared-mime-info, il nome è quello breve della famiglia.
      expect(find.text('Testo'), findsWidgets);
      expect(find.text('Testo semplice'), findsNothing);
    },
  );
}
