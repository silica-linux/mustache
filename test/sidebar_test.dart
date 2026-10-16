import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/sidebar.dart';
import 'package:mustache/src/window.dart';

import 'kit.dart';

/// A text inside the sidebar (the icon view shows the same names).
Finder inSidebar(String text) =>
    find.descendant(of: find.byType(Sidebar), matching: find.text(text));

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mustache-barra');
    for (final name in ['Documenti', 'Download']) {
      Directory('${root.path}/$name').createSync();
    }
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<Settings> pump(WidgetTester tester, {Settings? settings}) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final used = settings ?? Settings('${root.path}/settings.json');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: root.path,
          places: [
            Place('casa', root.path, PlaceKind.home),
            Place('Documenti', '${root.path}/Documenti', PlaceKind.documents),
            Place('Download', '${root.path}/Download', PlaceKind.downloads),
          ],
          trash: Place('Trash', '${root.path}/Cestino', PlaceKind.trash),
          settings: used,
        ),
      ),
    );
    return used;
  }

  testWidgets('rows, headers and the selection follow the kit Sidebar master', (
    tester,
  ) async {
    await pump(tester);
    final kit = loadKit('Sidebar');
    final heading = tester.getRect(find.byKey(const ValueKey('header Pinned')));
    final documents = tester.getRect(
      find.byKey(ValueKey('place ${root.path}/Documenti')),
    );
    final downloads = tester.getRect(
      find.byKey(ValueKey('place ${root.path}/Download')),
    );
    final places = tester.getRect(find.byKey(const ValueKey('header Places')));
    // The first header 8 below the 52 pt bar; the rows 28 tall at a 32 pitch, 12 from the edges,
    // 216 wide; between the last row of a section and the next header 16 (28 + 4 + 8 + 4).
    expect(heading.top, kit.rect('Pinned').top);
    expect(documents.top, kit.rect('Desktop').top);
    expect(documents.left, kit.rect('Desktop').left);
    expect(documents.size, kit.rect('Desktop').size);
    expect(downloads.top - documents.top, sidebarRow);
    expect(
      places.top - downloads.bottom,
      kit.rect('Places').top - kit.rect('Videos').bottom,
    );
    // The row of the shown folder is selected: the soft accent capsule, the label in Body Emphasis.
    final home = tester.widget<Text>(inSidebar('casa'));
    expect(home.style?.fontWeight, FontWeight.w500);
  });

  testWidgets(
    'the sidebar section of the toolbar: window controls slot, toggle',
    (tester) async {
      await pump(tester);
      final kit = loadKit('Toolbar Sidebar');
      expect(
        tester.getRect(find.byKey(const ValueKey('sidebar bar'))),
        Rect.fromLTWH(0, 0, kit.size.width, kit.size.height),
      );
      final toggle = tester.getRect(
        find.byKey(const ValueKey('sidebar toggle')),
      );
      expect(toggle, kit.rect('Sidebar Toggle'));
    },
  );

  test('width: minimum 200, minimum content, snap to 240, hidden', () {
    expect(dragWidth(100, 1000), sidebarMinWidth);
    expect(dragWidth(900, 1000), 1000 - contentMinWidth);
    expect(dragWidth(300, 1000), 300);
    expect(dragWidth(60, 1000), 0);
    expect(releaseWidth(235), sidebarSnapWidth);
    expect(releaseWidth(249), sidebarSnapWidth);
    expect(releaseWidth(230), 230);
    expect(releaseWidth(252), 252);
  });

  testWidgets('dragging the edge changes the width and remembers it', (
    tester,
  ) async {
    final settings = await pump(tester);
    final divider = find.byKey(const ValueKey('sidebar edge'));
    final gesture = await tester.startGesture(tester.getCenter(divider));
    await gesture.moveBy(const Offset(60, 0));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(tester.getCenter(divider).dx, closeTo(sidebarDefaultWidth + 100, 1));
    expect(settings.sidebarWidth, closeTo(sidebarDefaultWidth + 100, 1));
    // A new window starts from the same width (the file on disk).
    expect(
      Settings(settings.path).sidebarWidth,
      closeTo(sidebarDefaultWidth + 100, 1),
    );

    // Released near the default width it snaps back to it.
    final again = await tester.startGesture(tester.getCenter(divider));
    await again.moveBy(const Offset(-50, 0));
    await again.moveBy(const Offset(-55, 0));
    await tester.pump();
    await again.up();
    await tester.pump();
    expect(tester.getCenter(divider).dx, closeTo(sidebarSnapWidth, 1));
  });

  testWidgets('⌃⌘S hides the sidebar in ~240 ms and shows it again', (
    tester,
  ) async {
    await pump(tester);
    Future<void> toggle() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    }

    final divider = find.byKey(const ValueKey('sidebar edge'));
    await toggle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final half = tester.getCenter(divider).dx;
    expect(half, inExclusiveRange(40, 160));
    await tester.pump(const Duration(milliseconds: 130));
    expect(tester.getCenter(divider).dx, 0);
    await toggle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    // Showing starts with a ~40 ms delay.
    expect(tester.getCenter(divider).dx, 0);
    await tester.pump(const Duration(milliseconds: 260));
    expect(tester.getCenter(divider).dx, sidebarDefaultWidth);
  });

  testWidgets('the header chevron collapses and reopens the section', (
    tester,
  ) async {
    await pump(tester);
    final header = find.byKey(const ValueKey('header Pinned'));
    final placesBefore = tester.getCenter(inSidebar('Places')).dy;
    // The chevron shows while the pointer is over the header (kit: the plain header).
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(header));
    await tester.pump();
    await tester.tap(header);
    await tester.pump();
    // The row text disappears right away; the movement starts after ~70 ms.
    expect(inSidebar('Documenti'), findsNothing);
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getCenter(inSidebar('Places')).dy, placesBefore);
    await tester.pump(const Duration(milliseconds: 260));
    expect(
      tester.getCenter(inSidebar('Places')).dy,
      closeTo(placesBefore - 2 * sidebarRow, 0.5),
    );
    // Reopened (its chevron stays while it is closed): back as it was.
    await tester.tap(header);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    expect(tester.getCenter(inSidebar('Places')).dy, placesBefore);
    expect(inSidebar('Documenti'), findsOneWidget);
  });

  test('damaged or unreadable settings count as defaults', () {
    final file = File('${root.path}/rotto.json')..writeAsStringSync('{non è');
    expect(Settings(file.path).sidebarWidth, isNull);
    file.writeAsStringSync('{"sidebarWidth": "largo"}');
    expect(Settings(file.path).sidebarWidth, isNull);
    // A folder in place of the file: it is written without errors, it lasts for the session.
    Directory('${root.path}/cartella.json').createSync();
    final settings = Settings('${root.path}/cartella.json')..sidebarWidth = 250;
    expect(settings.sidebarWidth, 250);
  });

  test('the sidebar symbols are in symbols/regular', () {
    expect(symbolFor(PlaceKind.downloads), 'arrow-down');
    expect(symbolFor(PlaceKind.home), 'house');
  });
}
