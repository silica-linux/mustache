import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/preview_pane.dart';

void main() {
  testWidgets('pannello della galleria: intestazione, date, tag, azioni', (
    tester,
  ) async {
    final entry = Entry(
      name: 'Alfa',
      path: '/prova/Alfa',
      isDirectory: true,
      size: 0,
      modified: DateTime(2026, 10, 14, 16, 1),
    );
    final added = <String>[];
    Offset? more;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: 600,
            child: PreviewPane(
              width: 250,
              compact: true,
              items: [entry],
              kindOf: (_) => 'Cartella',
              now: DateTime(2026, 10, 14, 18),
              tagsOf: (_) => const [],
              onAddTag: (_, tag) => added.add(tag),
              actions: [
                PaneAction('Altro', 'ellipsis-circle', (at) => more = at),
              ],
            ),
          ),
        ),
      ),
    );
    // Nome accanto all'icona di 50, con la linea di base a 39 (mu23-gallery-folder).
    expect(tester.getTopLeft(find.text('Alfa')).dx, 69);
    // "oggi, 16:01" sul bordo destro, a 10 pt.
    final date = find.text('oggi, 16:01');
    expect(date, findsOneWidget);
    expect(tester.getTopRight(date).dx, closeTo(240, 0.5));
    // Il campo dei tag: Invio aggiunge.
    await tester.tap(find.text('Aggiungi un tag…'));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'Lavoro');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(added, ['Lavoro']);
    // La barra delle azioni in fondo, alta 70.
    final bar = tester.getRect(
      find.byKey(const ValueKey('azioni del pannello')),
    );
    expect(bar.height, paneActionsHeight);
    expect(bar.bottom, 600);
    await tester.tap(find.byKey(const ValueKey('azione Altro')));
    expect(more, isNotNull);
  });
}
