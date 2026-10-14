// Extended file attributes (xattr) for tags and comments, with the keys of the freedesktop
// convention: `user.xdg.tags` (comma-separated tags) and `user.xdg.comment`; folders also keep
// their custom tint and symbol in `user.silica.folder` (folder_style.dart). The libc calls
// (getxattr, setxattr, removexattr) go through FFI; a file system without support, a missing
// permission or a different libc give null or false, never an exception.

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

const String tagsAttribute = 'user.xdg.tags';
const String commentAttribute = 'user.xdg.comment';

typedef _GetC =
    IntPtr Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Uint8>, IntPtr);
typedef _GetDart =
    int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Uint8>, int);
typedef _SetC =
    Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Uint8>, IntPtr, Int32);
typedef _SetDart =
    int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Uint8>, int, int);
typedef _RemoveC = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _RemoveDart = int Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _ErrnoC = Pointer<Int32> Function();
typedef _ErrnoDart = Pointer<Int32> Function();

/// `ENOTSUP` (= `EOPNOTSUPP`) on Linux: the file system has no user attributes.
const int _notSupported = 95;

class _Libc {
  _Libc._(this.get, this.set, this.remove, this.errno);
  final _GetDart get;
  final _SetDart set;
  final _RemoveDart remove;

  /// The calling thread's `errno` (glibc and musl both export `__errno_location`).
  final _ErrnoDart? errno;

  bool get lastUnsupported {
    final e = errno;
    return e != null && e().value == _notSupported;
  }

  static _Libc? _instance;
  static bool _tried = false;

  static _Libc? get instance {
    if (_tried) return _instance;
    _tried = true;
    try {
      final lib = DynamicLibrary.process();
      _instance = _Libc._(
        lib.lookupFunction<_GetC, _GetDart>('getxattr'),
        lib.lookupFunction<_SetC, _SetDart>('setxattr'),
        lib.lookupFunction<_RemoveC, _RemoveDart>('removexattr'),
        lib.providesSymbol('__errno_location')
            ? lib.lookupFunction<_ErrnoC, _ErrnoDart>('__errno_location')
            : null,
      );
    } on ArgumentError {
      // A libc without xattr: no tags on disk.
    }
    return _instance;
  }
}

/// The value of an attribute (UTF-8 text), or null if missing or unreadable.
String? readAttribute(String path, String name) =>
    readAttributeChecked(path, name).value;

/// The value of an attribute and whether the file system lacks user attributes altogether
/// (`unsupported`: some USB and network disks), which a missing attribute is not.
({String? value, bool unsupported}) readAttributeChecked(
  String path,
  String name,
) {
  final libc = _Libc.instance;
  if (libc == null) return (value: null, unsupported: true);
  final p = path.toNativeUtf8();
  final n = name.toNativeUtf8();
  try {
    final size = libc.get(p, n, nullptr, 0);
    if (size < 0) return (value: null, unsupported: libc.lastUnsupported);
    if (size == 0 || size > 1 << 16) return (value: null, unsupported: false);
    final buffer = calloc<Uint8>(size);
    try {
      final read = libc.get(p, n, buffer, size);
      if (read < 0) return (value: null, unsupported: libc.lastUnsupported);
      return (
        value: utf8.decode(buffer.asTypedList(read), allowMalformed: true),
        unsupported: false,
      );
    } finally {
      calloc.free(buffer);
    }
  } finally {
    calloc
      ..free(p)
      ..free(n);
  }
}

/// The result of writing an attribute.
enum AttributeWrite {
  done,

  /// The file system has no user attributes: the caller can use another store.
  unsupported,

  /// Anything else (no permission, a vanished file).
  failed,
}

/// Writes an attribute; an empty value removes it. False if the disk does not allow it.
bool writeAttribute(String path, String name, String value) =>
    writeAttributeChecked(path, name, value) == AttributeWrite.done;

/// [writeAttribute], telling a file system without user attributes from other failures.
AttributeWrite writeAttributeChecked(String path, String name, String value) {
  final libc = _Libc.instance;
  if (libc == null) return AttributeWrite.unsupported;
  final p = path.toNativeUtf8();
  final n = name.toNativeUtf8();
  AttributeWrite result(int r) => r == 0
      ? AttributeWrite.done
      : libc.lastUnsupported
      ? AttributeWrite.unsupported
      : AttributeWrite.failed;
  try {
    if (value.isEmpty) {
      final r = libc.remove(p, n);
      if (r == 0) return AttributeWrite.done;
      final outcome = result(r);
      // Removing one that is not there is fine.
      final check = readAttributeChecked(path, name);
      return outcome == AttributeWrite.failed &&
              check.value == null &&
              !check.unsupported &&
              File(path).statSync().type != FileSystemEntityType.notFound
          ? AttributeWrite.done
          : outcome;
    }
    final bytes = Uint8List.fromList(utf8.encode(value));
    final buffer = calloc<Uint8>(bytes.length);
    try {
      buffer.asTypedList(bytes.length).setAll(0, bytes);
      return result(libc.set(p, n, buffer, bytes.length, 0));
    } finally {
      calloc.free(buffer);
    }
  } finally {
    calloc
      ..free(p)
      ..free(n);
  }
}

/// The tags of a file (in order, without duplicates).
List<String> readTags(String path) {
  final value = readAttribute(path, tagsAttribute);
  if (value == null) return const [];
  final out = <String>[];
  for (final tag in value.split(',')) {
    final t = tag.trim();
    if (t.isNotEmpty && !out.contains(t)) out.add(t);
  }
  return out;
}

bool writeTags(String path, List<String> tags) =>
    writeAttribute(path, tagsAttribute, tags.join(','));
