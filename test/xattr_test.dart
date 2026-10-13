import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/xattr.dart';

void main() {
  test('etichette e commenti negli attributi estesi', () {
    // /tmp può essere tmpfs (xattr user non sempre supportati): si prova nella home.
    final dir = Directory(
      '${Platform.environment['HOME']}/.cache',
    ).createTempSync('mustache-xattr');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/nota.txt')..writeAsStringSync('x');
    expect(readTags(file.path), isEmpty);
    if (!writeTags(file.path, ['Rosso', 'Lavoro'])) {
      markTestSkipped('il file system non supporta gli attributi user');
      return;
    }
    expect(readTags(file.path), ['Rosso', 'Lavoro']);
    expect(writeAttribute(file.path, commentAttribute, 'un commento'), isTrue);
    expect(readAttribute(file.path, commentAttribute), 'un commento');
    expect(writeTags(file.path, []), isTrue);
    expect(readTags(file.path), isEmpty);
    // Un file che non esiste: niente, senza eccezioni.
    expect(readTags('${dir.path}/sparito'), isEmpty);
    expect(writeTags('${dir.path}/sparito', ['Rosso']), isFalse);
  });
}
