import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/operations.dart';

void main() {
  late Directory root;
  late Trash trash;

  setUp(() {
    root = Directory.systemTemp.createTempSync('mustache-op');
    trash = Trash('${root.path}/.local/share/Trash');
  });

  tearDown(() => root.deleteSync(recursive: true));

  String p(String name) => '${root.path}/$name';

  test('nomi: estensione, cartella nuova, copie', () {
    expect(splitExtension('appunti.txt'), ('appunti', '.txt'));
    expect(splitExtension('.bashrc'), ('.bashrc', ''));
    expect(splitExtension('archivio.tar.gz'), ('archivio.tar', '.gz'));
    expect(splitExtension('Alfa.d', isDirectory: true), ('Alfa.d', ''));

    expect(createFolder(root.path).path, p('cartella senza nome'));
    expect(createFolder(root.path).path, p('cartella senza nome 2'));

    File(p('nota.txt')).writeAsStringSync('ciao');
    expect(duplicate(p('nota.txt')).path, p('nota copia.txt'));
    expect(duplicate(p('nota.txt')).path, p('nota copia 2.txt'));
    expect(File(p('nota copia 2.txt')).readAsStringSync(), 'ciao');

    Directory(p('Alfa/dentro')).createSync(recursive: true);
    File(p('Alfa/dentro/x.txt')).writeAsStringSync('x');
    Link(p('Alfa/collegamento')).createSync('dentro/x.txt');
    expect(duplicate(p('Alfa')).path, p('Alfa copia'));
    expect(File(p('Alfa copia/dentro/x.txt')).readAsStringSync(), 'x');
    expect(Link(p('Alfa copia/collegamento')).targetSync(), 'dentro/x.txt');

    expect(duplicate(p('sparito')).error, isNotNull);
  });

  test('rinomina: controlli, estensione, maiuscole', () {
    File(p('appunti.txt')).writeAsStringSync('a');
    File(p('altro.txt')).writeAsStringSync('b');
    expect(renameEntry(p('appunti.txt'), 'altro.txt').error, contains('già'));
    expect(renameEntry(p('appunti.txt'), 'a/b').error, contains('/'));
    expect(renameEntry(p('appunti.txt'), '  ').error, isNotNull);
    expect(renameEntry(p('appunti.txt'), '..').error, isNotNull);
    expect(extensionChanges('appunti.txt', 'appunti.md'), isTrue);
    expect(extensionChanges('appunti.txt', 'note.txt'), isFalse);
    expect(extensionChanges('LEGGIMI', 'LEGGIMI.md'), isFalse);
    expect(renameEntry(p('appunti.txt'), 'Appunti.txt').path, p('Appunti.txt'));
    expect(File(p('Appunti.txt')).existsSync(), isTrue);
  });

  test('Cestino: .trashinfo, nomi uguali, ripristino', () {
    Directory(p('Documenti')).createSync();
    File(p('Documenti/conto spese.txt')).writeAsStringSync('1');
    final first = trash.put(
      p('Documenti/conto spese.txt'),
      now: DateTime(2026, 10, 13, 9, 5, 7),
    );
    expect(first.path, '${trash.files}/conto spese.txt');
    final info = File(
      '${trash.info}/conto spese.txt.trashinfo',
    ).readAsStringSync();
    expect(info, startsWith('[Trash Info]\n'));
    expect(info, contains('/Documenti/conto%20spese.txt'));
    expect(info, contains('DeletionDate=2026-10-13T09:05:07'));
    expect(trash.originOf(first.path!), p('Documenti/conto spese.txt'));

    // Un secondo file con lo stesso nome non sovrascrive il primo.
    File(p('Documenti/conto spese.txt')).writeAsStringSync('2');
    final second = trash.put(p('Documenti/conto spese.txt'));
    expect(second.path, '${trash.files}/conto spese.2.txt');

    expect(trash.restore(first.path!).path, p('Documenti/conto spese.txt'));
    expect(File(p('Documenti/conto spese.txt')).readAsStringSync(), '1');
    expect(
      File('${trash.info}/conto spese.txt.trashinfo').existsSync(),
      isFalse,
    );
    // L'origine è di nuovo occupata: il secondo non si ripristina sopra il primo.
    expect(trash.restore(second.path!).error, contains('già'));
    expect(trash.contains(second.path!), isTrue);
    expect(trash.contains(p('Documenti')), isFalse);
  });

  test('annulla e ripeti: rinomina, cartella nuova, Cestino', () {
    final undo = UndoStack();
    File(p('a.txt')).writeAsStringSync('a');
    final renamed = renameEntry(p('a.txt'), 'b.txt');
    undo.push(RenameOp(p('a.txt'), renamed.path!));
    expect(undo.undoLabel, 'Annulla Rinomina');
    expect(undo.undo(trash), isNull);
    expect(File(p('a.txt')).existsSync(), isTrue);
    expect(undo.redoLabel, 'Ripeti Rinomina');
    expect(undo.redo(trash), isNull);
    expect(File(p('b.txt')).existsSync(), isTrue);

    final folder = createFolder(root.path).path!;
    undo.push(
      CreateOp([folder], 'Nuova cartella', (path) {
        Directory(path).createSync();
        return (path: path, error: null);
      }),
    );
    expect(undo.undo(trash), isNull);
    expect(Directory(folder).existsSync(), isFalse);
    expect(undo.redo(trash), isNull);
    expect(Directory(folder).existsSync(), isTrue);

    final moved = trash.put(p('b.txt')).path!;
    undo.push(TrashOp([(p('b.txt'), moved)]));
    expect(undo.undo(trash), isNull);
    expect(File(p('b.txt')).existsSync(), isTrue);
    expect(undo.redo(trash), isNull);
    expect(File(p('b.txt')).existsSync(), isFalse);

    // Un'operazione nuova cancella i ripeti.
    undo.undo(trash);
    undo.push(RenameOp(p('x'), p('y')));
    expect(undo.redoLabel, isNull);
  });

  test('eliminazione definitiva e casi mancanti', () {
    Directory(p('Pieno/dentro')).createSync(recursive: true);
    expect(deletePermanently(p('Pieno')).error, isNull);
    expect(Directory(p('Pieno')).existsSync(), isFalse);
    expect(deletePermanently(p('mai esistito')).error, isNull);
    expect(trash.put(p('mai esistito')).error, isNotNull);
    expect(trash.restore('${trash.files}/senza info').error, isNotNull);
  });
}
