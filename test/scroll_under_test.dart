// The content scrolls under the glass toolbar (mustache#3, mustache-spec R1.9 / R4.9).

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/column_view.dart';
import 'package:mustache/src/icon_view.dart';
import 'package:mustache/src/list_view.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  late Directory root;
  late Directory config;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mustache-under');
    config = Directory.systemTemp.createTempSync('mustache-under-config');
    for (var i = 0; i < 80; i++) {
      File(
        '${root.path}/file${i.toString().padLeft(2, '0')}.txt',
      ).writeAsStringSync('x');
    }
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    config.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: root.path,
          places: [Place('home', root.path, PlaceKind.home)],
          trash: Place('Trash', '${root.path}/.Trash', PlaceKind.trash),
          settings: Settings('${config.path}/s.json'),
          iconsEnv: {'SILICA_ICONS_DIR': config.path},
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> view(WidgetTester tester, LogicalKeyboardKey digit) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(digit);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
  }

  final line = find.byKey(const ValueKey('toolbar line'));
  final veil = find.byKey(const ValueKey('toolbar veil'));

  Color lineColor(WidgetTester tester) => tester.widget<ColoredBox>(line).color;

  testWidgets('icons: the view fills the window from the top, the first '
      'row starts below the band, the line appears once scrolled', (
    tester,
  ) async {
    await pump(tester);
    expect(veil, findsOneWidget);
    // The view starts at the top of the window, under the toolbar.
    final top = tester.getTopLeft(find.byType(IconView)).dy;
    expect(top, 0);
    final first = tester.getTopLeft(
      find.byKey(ValueKey('cell ${root.path}/file00.txt')),
    );
    expect(first.dy, greaterThanOrEqualTo(toolbarHeight));
    expect(tester.getSize(veil).height, toolbarHeight);
    expect(line, findsNothing);

    await tester.drag(find.byType(IconView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(line, findsOneWidget);
    expect(lineColor(tester), ToolbarVeil.light.line);
    // The rows scrolled under the band are still painted (under the veil).
    final scrolled = tester.getTopLeft(
      find.byKey(ValueKey('cell ${root.path}/file00.txt')),
    );
    expect(scrolled.dy, lessThan(toolbarHeight));
  });

  testWidgets('list: the column header is in the veiled band, rows scroll '
      'under it, no second line', (tester) async {
    await pump(tester);
    await view(tester, LogicalKeyboardKey.digit2);
    final header = find.byKey(const ValueKey('column header'));
    expect(tester.getTopLeft(header).dy, toolbarHeight);
    // Transparent: the veil shows through.
    expect(tester.widget<Container>(header).color, const Color(0x00000000));
    final band = toolbarHeight + listHeaderHeight + listHeaderLine;
    expect(tester.getSize(veil).height, band);
    final firstRow = find.byKey(ValueKey('${root.path}/file00.txt'));
    expect(tester.getTopLeft(firstRow).dy, greaterThanOrEqualTo(band));

    // Rows start a file drag: scroll the list directly.
    tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey('list')),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .jumpTo(40);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(firstRow).dy, lessThan(band));
    // The header has its own line: the band's is transparent.
    expect(lineColor(tester).a, 0);
  });

  testWidgets('columns: each column starts below the band', (tester) async {
    await pump(tester);
    await view(tester, LogicalKeyboardKey.digit3);
    expect(find.byType(ColumnView), findsOneWidget);
    expect(tester.getTopLeft(find.byType(ColumnView)).dy, 0);
    final row = find.byKey(ValueKey('${root.path}/file00.txt'));
    expect(tester.getTopLeft(row).dy, greaterThanOrEqualTo(toolbarHeight));
  });

  testWidgets('dark: the dark veil and line', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pump(tester);
    await tester.drag(find.byType(IconView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(lineColor(tester), ToolbarVeil.dark.line);
  });
}
