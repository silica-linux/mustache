import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/operations.dart';
import 'package:mustache/src/transfer.dart';

void main() {
  late Directory root;
  late Directory src;
  late Directory dst;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mustache-copie');
    src = Directory('${root.path}/da')..createSync();
    dst = Directory('${root.path}/a')..createSync();
    File('${src.path}/grande.bin').writeAsBytesSync(List.filled(300000, 7));
    Directory('${src.path}/Cartella/dentro').createSync(recursive: true);
    File('${src.path}/Cartella/dentro/x.txt').writeAsStringSync('x');
    File(
      '${src.path}/Cartella/dentro/x.txt',
    ).setLastModifiedSync(DateTime(2020, 1, 2));
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<ConflictChoice> never(String _) async =>
      fail('nessun conflitto atteso');

  test('copy: bytes, structure, modification date', () async {
    final t = Transfer(
      kind: TransferKind.copy,
      sources: ['${src.path}/grande.bin', '${src.path}/Cartella'],
      destination: dst.path,
      chunk: 65536,
    );
    final seen = <int>[];
    t.addListener(() => seen.add(t.doneBytes));
    await t.run(onConflict: never);
    expect(t.state, TransferState.done);
    expect(t.totalBytes, 300001);
    expect(t.doneBytes, 300001);
    expect(seen.length, greaterThan(4));
    expect(File('${dst.path}/grande.bin').lengthSync(), 300000);
    final copied = File('${dst.path}/Cartella/dentro/x.txt');
    expect(copied.readAsStringSync(), 'x');
    expect(copied.lastModifiedSync(), DateTime(2020, 1, 2));
    expect(File('${src.path}/grande.bin').existsSync(), isTrue);
  });

  test('move on the same disk: rename, the original disappears', () async {
    final t = Transfer(
      kind: TransferKind.move,
      sources: ['${src.path}/Cartella'],
      destination: dst.path,
    );
    await t.run(onConflict: never);
    expect(Directory('${dst.path}/Cartella/dentro').existsSync(), isTrue);
    expect(Directory('${src.path}/Cartella').existsSync(), isFalse);
    // Undoing the move puts it back.
    expect(MoveOp(t.completed).undo(Trash('${root.path}/Cestino')), isNull);
    expect(Directory('${src.path}/Cartella/dentro').existsSync(), isTrue);
  });

  test('conflicts: keep both, replace, stop', () async {
    File('${dst.path}/grande.bin').writeAsStringSync('vecchio');
    var t = Transfer(
      kind: TransferKind.copy,
      sources: ['${src.path}/grande.bin'],
      destination: dst.path,
    );
    await t.run(onConflict: (_) async => ConflictChoice.keepBoth);
    expect(File('${dst.path}/grande 2.bin').lengthSync(), 300000);
    expect(File('${dst.path}/grande.bin').readAsStringSync(), 'vecchio');

    t = Transfer(
      kind: TransferKind.copy,
      sources: ['${src.path}/grande.bin'],
      destination: dst.path,
    );
    await t.run(onConflict: (_) async => ConflictChoice.replace);
    expect(File('${dst.path}/grande.bin').lengthSync(), 300000);

    t = Transfer(
      kind: TransferKind.copy,
      sources: ['${src.path}/grande.bin', '${src.path}/Cartella'],
      destination: dst.path,
    );
    await t.run(onConflict: (_) async => ConflictChoice.stop);
    expect(t.state, TransferState.cancelled);
    expect(Directory('${dst.path}/Cartella').existsSync(), isFalse);
  });

  test(
    'cancelling during the copy leaves nothing in the destination',
    () async {
      final t = Transfer(
        kind: TransferKind.copy,
        sources: ['${src.path}/Cartella', '${src.path}/grande.bin'],
        destination: dst.path,
        chunk: 4096,
      );
      t.addListener(() {
        if (t.doneBytes > 50000) t.cancel();
      });
      await t.run(onConflict: never);
      expect(t.state, TransferState.cancelled);
      expect(dst.listSync(), isEmpty);
    },
  );

  test(
    'pasting into the same folder makes "name copia"; into itself it does not',
    () async {
      var t = Transfer(
        kind: TransferKind.copy,
        sources: ['${src.path}/grande.bin'],
        destination: src.path,
      );
      await t.run(onConflict: never);
      expect(File('${src.path}/grande copia.bin').existsSync(), isTrue);

      t = Transfer(
        kind: TransferKind.copy,
        sources: ['${src.path}/Cartella'],
        destination: '${src.path}/Cartella/dentro',
      );
      await t.run(onConflict: never);
      expect(t.state, TransferState.failed);
      expect(t.error, contains('dentro se stessa'));
    },
  );
}
