import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/preview_pane.dart';

void main() {
  testWidgets('gallery pane: header, dates, tags, actions', (tester) async {
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
              kindOf: (_) => 'Folder',
              now: DateTime(2026, 10, 14, 18),
              tagsOf: (_) => const [],
              onAddTag: (_, tag) => added.add(tag),
              actions: [
                PaneAction('More', 'ellipsis-circle', (at) => more = at),
              ],
            ),
          ),
        ),
      ),
    );
    // Name beside the 50 pt icon, with the baseline at 39 (mu23-gallery-folder).
    expect(tester.getTopLeft(find.text('Alfa')).dx, 69);
    // "Today, 16:01" on the right edge, at 10 pt.
    final date = find.text('Today, 16:01');
    expect(date, findsOneWidget);
    expect(tester.getTopRight(date).dx, closeTo(240, 0.5));
    // The tags field: Return adds.
    await tester.tap(find.text('Add a tag…'));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'Lavoro');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(added, ['Lavoro']);
    // The actions bar at the bottom, 70 tall.
    final bar = tester.getRect(find.byKey(const ValueKey('pane actions')));
    expect(bar.height, paneActionsHeight);
    expect(bar.bottom, 600);
    await tester.tap(find.byKey(const ValueKey('action More')));
    expect(more, isNotNull);
  });
}
