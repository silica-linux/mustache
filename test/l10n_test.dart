import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/l10n.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mustache-l10n');
    File('${root.path}/appunti.txt').writeAsStringSync('x' * 31);
    File(
      '${root.path}/grande.bin',
    ).writeAsBytesSync(List.filled(2150000, 0), flush: true);
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    useLocale(const Locale('en'));
  });

  Future<void> pump(WidgetTester tester, Locale locale) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppLocalizationsScope(
        locale: locale,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: MustacheWindow(
            start: root.path,
            places: [Place('Prova', root.path, PlaceKind.home)],
            trash: Place('Trash', '${root.path}/.Trash', PlaceKind.trash),
            now: DateTime.now(),
            settings: Settings(
              '${Directory.systemTemp.createTempSync('mustache-l10n-s').path}/s.json',
            )..view = 'list',
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('English: headers, places, dates and sizes', (tester) async {
    await pump(tester, const Locale('en', 'US'));
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Modified'), findsOneWidget);
    expect(find.text('Places'), findsOneWidget);
    expect(find.text('Trash'), findsOneWidget);
    expect(find.textContaining('Today, '), findsWidgets);
    expect(find.text('2 MB'), findsOneWidget);
    expect(find.text('31 bytes'), findsOneWidget);
  });

  testWidgets('Italian: the measured texts and formats', (tester) async {
    await pump(tester, const Locale('it', 'IT'));
    expect(find.text('Nome'), findsOneWidget);
    expect(find.text('Data di modifica'), findsOneWidget);
    expect(find.text('Posizioni'), findsOneWidget);
    expect(find.text('Cestino'), findsOneWidget);
    expect(find.textContaining('oggi, '), findsWidgets);
    expect(find.text('31 byte'), findsOneWidget);
    expect(find.text('Rosso'), findsOneWidget);
    expect(l10n.localeName, 'it');
  });

  testWidgets('an unknown language falls back to English', (tester) async {
    await pump(tester, const Locale('de', 'DE'));
    expect(find.text('Name'), findsOneWidget);
    expect(l10n.localeName, 'en');
  });
}
