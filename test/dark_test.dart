import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/preview_pane.dart';
import 'package:mustache/src/status_bar.dart';
import 'package:silica_ui/silica_ui.dart';

/// The window parts follow the system appearance, with the Amalfi tokens.
Widget dark(Widget child) => MediaQuery(
  data: const MediaQueryData(platformBrightness: Brightness.dark),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: child),
  ),
);

void main() {
  final tokens = AmalfiColors.dark;

  testWidgets('dark status bar: surface, separator, active and inactive text', (
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
      final bar = find.byKey(const ValueKey('status bar'));
      expect(
        tester
            .widget<ColoredBox>(
              find.descendant(of: bar, matching: find.byType(ColoredBox)).first,
            )
            .color,
        tokens.surfaceWindow,
      );
      expect(
        find
            .descendant(
              of: bar,
              matching: find.byWidgetPredicate(
                (w) => w is ColoredBox && w.color == tokens.lineSeparator,
              ),
            )
            .evaluate()
            .length,
        1,
      );
      expect(
        tester.widget<Text>(find.text('3 elementi')).style?.color,
        active ? tokens.textSecondary : tokens.textTertiary,
      );
    }
  });

  testWidgets('dark preview pane: surface, name and action', (tester) async {
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
            items: [entry],
            kindOf: (_) => 'Folder',
            now: DateTime(2026, 10, 14, 18),
            actions: [PaneAction('More', 'ellipsis-circle', (_) {})],
          ),
        ),
      ),
    );
    final pane = find.byKey(const ValueKey('preview pane'));
    expect(
      tester
          .widget<ColoredBox>(
            find.descendant(of: pane, matching: find.byType(ColoredBox)).first,
          )
          .color,
      tokens.surfaceSidebar,
    );
    expect(
      tester.widget<Text>(find.text('Alfa')).style?.color,
      tokens.textPrimary,
    );
    expect(find.byKey(const ValueKey('action More')), findsOneWidget);
  });
}
