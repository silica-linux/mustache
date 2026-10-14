import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/preview_pane.dart';
import 'package:mustache/src/status_bar.dart';

/// The window parts follow the system appearance (MU-04, MU-05).
Widget dark(Widget child) => MediaQuery(
  data: const MediaQueryData(platformBrightness: Brightness.dark),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: child),
  ),
);

void main() {
  testWidgets('dark status bar: background, line, active and inactive text', (
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
        find.byKey(const ValueKey('status bar')),
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

  testWidgets('dark preview pane: background, name and actions', (
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
      find.byKey(const ValueKey('preview pane')),
    );
    expect(pane.color, PaneColors.dark.fill);
    expect(
      tester.widget<Text>(find.text('Alfa')).style?.color,
      PaneColors.dark.name,
    );
    final bar = tester.widget<Container>(
      find.byKey(const ValueKey('pane actions')),
    );
    expect(bar.color, const Color(0xFF272728));
  });
}
