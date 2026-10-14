import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/icon_view.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  test('la griglia segue la tabella di spec 4.1', () {
    // 783 pt di contenuto: 6 colonne a 64 (passo ~126,8), prima icona a 24, passo y 116.
    final g64 = iconGrid(783);
    expect(g64.columns, 6);
    expect(g64.pitchX, closeTo(126.8, 0.1));
    expect(g64.pitchY, 116);
    expect(g64.top, 24);
    expect(g64.centerX(0), closeTo(74, 1.5));
    // Gli altri lati: passo y e cima della prima icona.
    for (final (side, pitchY, top) in [
      (16.0, 59.0, 21.0),
      (32.0, 78.0, 22.0),
      (96.0, 154.0, 26.0),
      (128.0, 192.0, 28.0),
    ]) {
      final g = iconGrid(783, side: side);
      expect(g.pitchY, pitchY, reason: 'lato $side');
      expect(g.top, top, reason: 'lato $side');
    }
    expect(iconGrid(783, side: 128).columns, 4);
    // Il testo: 10 → 8 colonne e passo y 110; 16 → 5 colonne e 122.
    expect(iconGrid(822, text: 10).columns, 8);
    expect(iconGrid(822, text: 10).pitchY, 110);
    expect(iconGrid(783, text: 16).columns, 5);
    expect(iconGrid(783, text: 16).pitchY, 122);
  });

  testWidgets('etichetta: al più due righe, la seconda troncata al centro', (
    tester,
  ) async {
    const style = TextStyle(fontSize: 12);
    expect(labelLines('breve.txt', 110, style), ['breve.txt']);
    final lines = labelLines(
      'un nome di file davvero molto lungo che non entra in due righe.pdf',
      110,
      style,
    );
    expect(lines, hasLength(2));
    expect(lines.last, contains('…'));
    expect(lines.last, endsWith('.pdf'));
    // Una parola sola più larga della riga va a capo dentro la parola (nei test ogni
    // carattere è largo quanto il corpo: 9 per riga).
    final word = labelLines('abcdefghijklmno', 110, style);
    expect(word, hasLength(2));
    expect(word.join(), 'abcdefghijklmno');
  });

  group('nella finestra', () {
    late Directory root;
    late Directory config;

    setUp(() {
      root = Directory.systemTemp.createTempSync('mustache-icone');
      config = Directory.systemTemp.createTempSync('mustache-config');
      for (final name in ['Alfa', 'Beta']) {
        Directory('${root.path}/$name').createSync();
      }
      // Abbastanza file per due righe.
      for (var i = 0; i < 12; i++) {
        final name = 'file$i.txt';
        File('${root.path}/$name').writeAsStringSync('x');
      }
    });

    tearDown(() {
      root.deleteSync(recursive: true);
      config.deleteSync(recursive: true);
    });

    Future<Settings> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = Settings('${config.path}/s.json');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MustacheWindow(
            start: root.path,
            places: [Place('casa', root.path, PlaceKind.home)],
            trash: Place('Cestino', '${root.path}/Cestino', PlaceKind.trash),
            settings: settings,
            // Nessuna icona di silica-icons: le celle restano vuote, la griglia no.
            iconsEnv: {'SILICA_ICONS_DIR': config.path},
          ),
        ),
      );
      return settings;
    }

    Finder label(String name) =>
        find.descendant(of: find.byType(IconView), matching: find.text(name));

    testWidgets('selezione, capsula del nome, frecce nella griglia', (
      tester,
    ) async {
      await pump(tester);
      // Ordine naturale, cartelle e file insieme.
      expect(label('Alfa'), findsOneWidget);
      await tester.tap(label('Alfa'));
      await tester.pump();
      DecoratedBox capsule(String name) => tester.widget<DecoratedBox>(
        find.byKey(ValueKey('nome ${root.path}/$name 0')),
      );
      expect(
        (capsule('Alfa').decoration as BoxDecoration).color,
        const Color(0xFF0064E1),
      );
      expect(
        tester.widget<Text>(label('Alfa')).style?.color,
        const Color(0xFFFFFFFF),
      );
      // → passa alla cella accanto, ↓ alla riga sotto (stessa colonna).
      final ordered = [
        for (final e in sortEntries(
          listDirectory(root.path, showHidden: false).entries,
          SortKey.name,
        ))
          e.name,
      ];
      final start = ordered.indexOf('Alfa');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        (capsule(ordered[start + 1]).decoration as BoxDecoration).color,
        const Color(0xFF0064E1),
      );
      final columns = iconGrid(
        tester.getSize(find.byType(IconView)).width,
      ).columns;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      final below = (start + 1 + columns).clamp(0, ordered.length - 1);
      expect(
        (capsule(ordered[below]).decoration as BoxDecoration).color,
        const Color(0xFF0064E1),
      );
      // Clic nel vuoto: nessuna selezione.
      await tester.tapAt(
        tester.getBottomRight(find.byType(IconView)) - const Offset(20, 20),
      );
      await tester.pump();
      expect(
        (capsule(ordered[below]).decoration as BoxDecoration).color,
        isNull,
      );
      // Lascia scadere l'attesa del doppio clic.
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('⌘2 passa all\'elenco, ⌘1 alle icone, e la scelta resta', (
      tester,
    ) async {
      final settings = await pump(tester);
      expect(find.byType(IconView), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(find.byType(IconView), findsNothing);
      expect(find.text('Alfa'), findsOneWidget);
      expect(settings.view, 'list');
      expect(Settings(settings.path).view, 'list');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(find.byType(IconView), findsOneWidget);
    });
  });

  test('miniature solo per le immagini', () {
    expect(hasThumbnail('foto.JPG'), isTrue);
    expect(hasThumbnail('nota.txt'), isFalse);
    expect(hasThumbnail('.png'), isFalse);
    expect(fileIconId('nota.txt'), 'file-text');
  });
}
