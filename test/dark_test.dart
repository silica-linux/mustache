import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/preview_pane.dart';
import 'package:mustache/src/status_bar.dart';

/// I pezzi della finestra seguono l'aspetto del sistema (MU-04, MU-05).
Widget dark(Widget child) => MediaQuery(
  data: const MediaQueryData(platformBrightness: Brightness.dark),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: child),
  ),
);

void main() {
  testWidgets('barra di stato scura: fondo, linea, testo attivo e inattivo', (
    tester,
  ) async {
    for (final active in [true, false]) {
      await tester.pumpWidget(
        dark(
          SizedBox(
            width: 600,
            child: StatusBar(text: '3 elementi', active: active),
          ),
        ),
      );
      final box = tester.widget<Container>(
        find.byKey(const ValueKey('barra di stato')),
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFF2F2F2F));
      expect((decoration.border! as Border).top.color, const Color(0xFF000000));
      expect(
        tester.widget<Text>(find.text('3 elementi')).style?.color,
        active ? const Color(0xFFA1A1A1) : const Color(0xFF636363),
      );
    }
  });

  testWidgets('pannello di anteprima scuro: fondo, nome e azioni', (
    tester,
  ) async {
    final entry = Entry(
      name: 'Alfa',
      path: '/prova/Alfa',
      isDirectory: true,
      size: 0,
      modified: DateTime(2026, 10, 14, 16, 1),
    );
    await tester.pumpWidget(
      dark(
        SizedBox(
          height: 600,
          child: PreviewPane(
            width: 264,
            items: [entry],
            kindOf: (_) => 'Cartella',
            now: DateTime(2026, 10, 14, 18),
            actions: [PaneAction('Altro', 'ellipsis-circle', (_) {})],
          ),
        ),
      ),
    );
    final pane = tester.widget<Container>(
      find.byKey(const ValueKey('pannello di anteprima')),
    );
    expect(pane.color, PaneColors.dark.fill);
    expect(
      tester.widget<Text>(find.text('Alfa')).style?.color,
      PaneColors.dark.name,
    );
    final bar = tester.widget<Container>(
      find.byKey(const ValueKey('azioni del pannello')),
    );
    expect(bar.color, const Color(0xFF272728));
  });
}
