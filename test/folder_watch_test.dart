import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/folder_watch.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/operations.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';

void main() {
  late Directory root;
  late FolderWatcher saved;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mustache-refresh');
    File('${root.path}/uno.txt').writeAsStringSync('1');
    File('${root.path}/due.txt').writeAsStringSync('2');
    saved = folderWatcher;
    folderWatcher = FolderWatcher(
      watchDisk: true,
      debounce: const Duration(milliseconds: 40),
    );
  });

  tearDown(() {
    folderWatcher.dispose();
    folderWatcher = saved;
    root.deleteSync(recursive: true);
  });

  test(
    'one watch per folder, counted, and one debounced call per burst',
    () async {
      final watcher = FolderWatcher(
        watchDisk: true,
        debounce: const Duration(milliseconds: 40),
      );
      addTearDown(watcher.dispose);
      final seen = <List<String>>[];
      final stop = watcher.watch(root.path, seen.add);
      final again = watcher.watch(root.path, (_) {});
      expect(watcher.watched, {root.path});
      await Future<void>.delayed(const Duration(milliseconds: 100));
      File('${root.path}/tre.txt').writeAsStringSync('3');
      File('${root.path}/quattro.txt').writeAsStringSync('4');
      File('${root.path}/uno.txt').deleteSync();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(seen, hasLength(1));
      expect(
        seen.single,
        containsAll(['${root.path}/tre.txt', '${root.path}/uno.txt']),
      );
      stop();
      expect(watcher.watched, {root.path}, reason: 'still shown by the other');
      again();
      expect(watcher.watched, isEmpty);
    },
  );

  test(
    'a folder that does not exist yet is picked up when it appears',
    () async {
      final watcher = FolderWatcher(
        watchDisk: true,
        debounce: const Duration(milliseconds: 40),
      );
      addTearDown(watcher.dispose);
      final later = '${root.path}/Trash/files';
      var calls = 0;
      final stop = watcher.watch(later, (_) => calls++);
      addTearDown(stop);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      Directory(later).createSync(recursive: true);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(calls, greaterThan(0));
      final before = calls;
      File('$later/a.txt').writeAsStringSync('a');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(calls, greaterThan(before));
    },
  );

  Future<void> pump(WidgetTester tester, String folder, {String? trash}) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: folder,
          places: [Place('Prova', root.path, PlaceKind.home)],
          trash: Place(
            'Trash',
            trash ?? '${root.path}/Cestino',
            PlaceKind.trash,
          ),
          now: DateTime(2026, 10, 13, 12),
          open: (_) {},
          settings: Settings(
            '${Directory.systemTemp.createTempSync('mustache-impostazioni').path}/s.json',
          )..view = 'list',
        ),
      ),
    );
    // Let the watch start.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    // The debounce timer lives in the test's fake clock.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
  }

  testWidgets('an external delete, create and rename update the window', (
    tester,
  ) async {
    await pump(tester, root.path);
    expect(find.text('uno.txt'), findsOneWidget);

    File('${root.path}/uno.txt').deleteSync();
    await settle(tester);
    expect(find.text('uno.txt'), findsNothing);

    File('${root.path}/nuovo.txt').writeAsStringSync('n');
    await settle(tester);
    expect(find.text('nuovo.txt'), findsOneWidget);

    File('${root.path}/due.txt').renameSync('${root.path}/rinominato.txt');
    await settle(tester);
    expect(find.text('due.txt'), findsNothing);
    expect(find.text('rinominato.txt'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    expect(folderWatcher.watched, isEmpty);
  });

  testWidgets(
    'moving to the Trash updates the folder and an open Trash window',
    (tester) async {
      final trash = Trash('${root.path}/TrashRoot');
      Directory(trash.files).createSync(recursive: true);
      // Two windows: one on the folder, one on the Trash.
      await pump(tester, root.path, trash: trash.files);
      expect(find.text('uno.txt'), findsOneWidget);
      expect(folderWatcher.watched, contains(root.path));

      final result = trash.put('${root.path}/uno.txt');
      expect(result.error, isNull);
      await settle(tester);
      expect(find.text('uno.txt'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await pump(tester, trash.files, trash: trash.files);
      expect(find.text('uno.txt'), findsOneWidget);
      expect(find.text('due.txt'), findsNothing);
      trash.put('${root.path}/due.txt');
      await settle(tester);
      expect(find.text('due.txt'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
