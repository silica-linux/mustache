import 'dart:ui' show Color;
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/external.dart';
import 'package:mustache/src/folder_icons.dart';
import 'package:mustache/src/folder_style.dart';
import 'package:mustache/src/xattr.dart';

import 'folder_fixture.dart';

/// The GIO metadata store, in memory.
class FakeMetadata implements FolderMetadata {
  final Map<String, String> values = {};
  int reads = 0;

  @override
  String? read(String path) {
    reads++;
    return values[path];
  }

  @override
  bool write(String path, String? value) {
    value == null ? values.remove(path) : values[path] = value;
    return true;
  }
}

/// Extended attributes and tags, in memory; `supported: false` acts like a USB stick.
class FakeDisk {
  FakeDisk({this.supported = true});
  final bool supported;
  final Map<String, Map<String, String>> attributes = {};
  final Map<String, List<String>> tags = {};

  ({String? value, bool unsupported}) read(String path, String name) => (
    value: supported ? (attributes[path]?[name]) : null,
    unsupported: !supported,
  );

  AttributeWrite write(String path, String name, String value) {
    if (!supported) return AttributeWrite.unsupported;
    if (value.isEmpty) {
      attributes[path]?.remove(name);
    } else {
      (attributes[path] ??= {})[name] = value;
    }
    return AttributeWrite.done;
  }

  FolderStyles styles(FakeMetadata metadata) => FolderStyles(
    readAttribute: read,
    writeAttribute: write,
    readTags: (path) => tags[path] ?? const [],
    metadata: metadata,
  );
}

/// A temporary folder under home (/tmp may be tmpfs without user attributes).
Directory homeTemp(String name) {
  final cache = Directory('${Platform.environment['HOME']}/.cache')
    ..createSync(recursive: true);
  final dir = cache.createTempSync(name);
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

void main() {
  test('the stored JSON: valid fields only', () {
    expect(
      FolderStyle.parse('{"tint":"#E8336D","symbol":"music-note"}'),
      const FolderStyle(tint: '#e8336d', symbol: 'music-note'),
    );
    expect(FolderStyle.parse('{"tint":"red"}'), const FolderStyle(tint: 'red'));
    expect(
      FolderStyle.parse('{"tint":"pink","symbol":"../x"}'),
      isNull,
      reason: 'neither part is usable',
    );
    expect(FolderStyle.parse('not json'), isNull);
    expect(FolderStyle.parse('[1]'), isNull);
    expect(FolderStyle.parse(''), isNull);
    expect(
      const FolderStyle(tint: '#e8336d', symbol: 'music-note').encode(),
      '{"tint":"#e8336d","symbol":"music-note"}',
    );
    expect(const FolderStyle(symbol: 'star').encode(), '{"symbol":"star"}');
  });

  test('user.silica.folder on a real folder, and the checked reads', () {
    final dir = homeTemp('mustache-folder-style');
    final folder = Directory('${dir.path}/Musica')..createSync();
    final probe = readAttributeChecked(folder.path, folderStyleAttribute);
    expect(probe.value, isNull);
    if (probe.unsupported ||
        !writeAttribute(folder.path, folderStyleAttribute, '{"tint":"red"}')) {
      markTestSkipped('the file system does not support user attributes');
      return;
    }
    final metadata = FakeMetadata();
    final styles = FolderStyles(metadata: metadata);
    expect(styles.stored(folder.path), const FolderStyle(tint: 'red'));
    const style = FolderStyle(tint: '#e8336d', symbol: 'music-note');
    expect(styles.save(folder.path, style), isTrue);
    expect(
      readAttribute(folder.path, folderStyleAttribute),
      '{"tint":"#e8336d","symbol":"music-note"}',
    );
    expect(styles.look(folder.path), (symbol: 'music-note', tint: '#e8336d'));
    // Reset removes the attribute; removing it twice is fine.
    expect(styles.save(folder.path, const FolderStyle()), isTrue);
    expect(styles.save(folder.path, const FolderStyle()), isTrue);
    expect(readAttribute(folder.path, folderStyleAttribute), isNull);
    expect(styles.stored(folder.path), isNull);
    // The disk supports attributes: the GIO store is never asked.
    expect(metadata.reads, 0);
    // A vanished folder: a failure, not an exception.
    expect(
      writeAttributeChecked('${dir.path}/gone', folderStyleAttribute, '{}'),
      AttributeWrite.failed,
    );
    expect(styles.save('${dir.path}/gone', style), isFalse);
  });

  test('a file system without user attributes is told from a missing one', () {
    // procfs has no user attributes (like some USB and network disks).
    if (!Directory('/proc/self').existsSync()) {
      markTestSkipped('no /proc');
      return;
    }
    expect(
      readAttributeChecked('/proc/self', folderStyleAttribute).unsupported,
      isTrue,
    );
  });

  test('a disk without attributes keeps the style in the GIO store', () {
    final metadata = FakeMetadata();
    final disk = FakeDisk(supported: false);
    final styles = disk.styles(metadata);
    expect(styles.stored('/media/usb/Foto'), isNull);
    expect(metadata.reads, 1);
    expect(
      styles.save('/media/usb/Foto', const FolderStyle(symbol: 'star')),
      isTrue,
    );
    expect(metadata.values['/media/usb/Foto'], '{"symbol":"star"}');
    expect(styles.look('/media/usb/Foto').symbol, 'star');
    expect(styles.save('/media/usb/Foto', const FolderStyle()), isTrue);
    expect(metadata.values, isEmpty);
    // A disk with attributes does not write to the GIO store.
    final supported = FakeDisk();
    final other = FakeMetadata();
    supported
        .styles(other)
        .save('/home/a/Foto', const FolderStyle(tint: 'blue'));
    expect(other.values, isEmpty);
    expect(
      supported.attributes['/home/a/Foto']?[folderStyleAttribute],
      '{"tint":"blue"}',
    );
  });

  test('gio info output and the real store under flutter test', () {
    expect(
      parseGioInfo(
        'uri: file:///media/usb/Foto\n'
        'attributes:\n'
        '  metadata::silica-folder: {"tint":"red"}\n',
      ),
      '{"tint":"red"}',
    );
    expect(parseGioInfo('attributes:\n'), isNull);
    // Tests start nothing: the real GIO store answers nothing and writes nothing.
    expect(startsNothing, isTrue);
    expect(runQuietly('gio', ['info', '/']), isNull);
    expect(const GioFolderMetadata().read('/'), isNull);
    expect(const GioFolderMetadata().write('/', '{}'), isFalse);
  });

  test('tint order: custom, then the first colour tag, then none', () {
    final disk = FakeDisk();
    final styles = disk.styles(FakeMetadata());
    const path = '/home/a/Lavoro';
    expect(styles.look(path), (symbol: null, tint: null));
    disk.tags[path] = ['Progetti', 'Verde', 'Red'];
    styles.invalidate([path]);
    expect(styles.look(path).tint, 'green', reason: 'the first colour tag');
    disk.tags[path] = ['Grigio'];
    styles.invalidate([path]);
    expect(styles.look(path).tint, 'gray', reason: 'a localized name');
    styles.save(path, const FolderStyle(symbol: 'star'));
    expect(styles.look(path), (symbol: 'star', tint: 'gray'));
    styles.save(path, const FolderStyle(tint: '#e8336d', symbol: 'star'));
    expect(styles.look(path), (symbol: 'star', tint: '#e8336d'));
  });

  test('the icon gets the symbol and the tint, full or empty', () {
    final root = folderIconsRoot();
    addTearDown(() => root.deleteSync(recursive: true));
    final home = Directory.systemTemp.createTempSync('folder-home');
    addTearDown(() => home.deleteSync(recursive: true));
    final env = {'SILICA_ICONS_DIR': root.path, 'HOME': home.path};
    final disk = FakeDisk();
    final styles = disk.styles(FakeMetadata());
    final plain = Directory('${home.path}/Plain')..createSync();
    expect(
      styledFolderIcon(plain.path, env: env, styles: styles)!.icon.id,
      'folder',
    );

    disk.tags[plain.path] = ['Blue'];
    styles.save(plain.path, const FolderStyle(symbol: 'star'));
    final folder = styledFolderIcon(plain.path, env: env, styles: styles)!;
    expect(folder.icon.id, 'folder-generic');
    expect(folder.symbol, 'star');
    expect(folder.tint, const Color(0xFF2F7CF6));
    final full = fullFolder(folder);
    expect(full.symbol, 'star');
    expect(full.tint, folder.tint);
    expect(full.icon.layers.single.path, endsWith('/icon-full.svg'));

    // A symbol silica-icons does not have keeps the special folder's own.
    final music = Directory('${home.path}/Music')..createSync();
    final env2 = {...env, 'XDG_CONFIG_HOME': '${home.path}/.config'};
    File('${home.path}/.config/user-dirs.dirs')
      ..createSync(recursive: true)
      ..writeAsStringSync('XDG_MUSIC_DIR="\$HOME/Music"\n');
    styles.save(music.path, const FolderStyle(symbol: 'no-such-symbol'));
    expect(
      styledFolderIcon(music.path, env: env2, styles: styles)!.symbol,
      'music-note',
    );
    styles.save(music.path, const FolderStyle(symbol: 'house', tint: 'red'));
    final custom = styledFolderIcon(music.path, env: env2, styles: styles)!;
    expect(custom.symbol, 'house');
    expect(custom.tint, const Color(0xFFF2382E));
  });

  test('invalidating redraws only for folders already shown', () {
    final styles = FakeDisk().styles(FakeMetadata());
    var redraws = 0;
    styles.addListener(() => redraws++);
    styles.invalidate(['/a']);
    expect(redraws, 0);
    styles.look('/a');
    styles.invalidate(['/a', '/b']);
    expect(redraws, 1);
  });

  test(
    'the watcher sees an attribute change and redraws once, debounced',
    () async {
      final dir = homeTemp('mustache-folder-watch');
      final folder = Directory('${dir.path}/Foto')..createSync();
      if (readAttributeChecked(folder.path, folderStyleAttribute).unsupported) {
        markTestSkipped('the file system does not support user attributes');
        return;
      }
      final styles = FolderStyles(
        metadata: FakeMetadata(),
        watchDisk: true,
        debounce: const Duration(milliseconds: 50),
      );
      addTearDown(styles.dispose);
      final stop = styles.watch(dir.path);
      final again = styles.watch(dir.path);
      expect(styles.watched, {dir.path});
      expect(styles.look(folder.path).tint, isNull);
      final redrawn = Completer<void>();
      var redraws = 0;
      styles.addListener(() {
        redraws++;
        if (!redrawn.isCompleted) redrawn.complete();
      });
      // Let the watch start, then change the attribute as another app would.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(writeTags(folder.path, ['Red']), isTrue);
      expect(
        writeAttribute(folder.path, folderStyleAttribute, '{"symbol":"star"}'),
        isTrue,
      );
      await redrawn.future.timeout(const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(redraws, 1);
      expect(styles.look(folder.path), (symbol: 'star', tint: 'red'));
      stop();
      expect(styles.watched, {dir.path}, reason: 'still shown by the other');
      again();
      stop();
      expect(styles.watched, isEmpty);
    },
  );

  test('under flutter test the app styles do not watch the disk', () {
    final styles = FolderStyles();
    addTearDown(styles.dispose);
    expect(styles.watchDisk, isFalse);
    final stop = styles.watch('/');
    expect(styles.watched, {'/'});
    stop();
    expect(styles.watched, isEmpty);
  });
}
