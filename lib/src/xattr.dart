// Extended file attributes (xattr) for tags and comments, with the keys of the freedesktop
// convention: `user.xdg.tags` (comma-separated tags) and `user.xdg.comment`. The libc calls
// (getxattr, setxattr, removexattr) go through FFI; a file system without support, a missing
// permission or a different libc give null or false, never an exception.

import 'dart:convert';
import 'dart:ffi';
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

class _Libc {
  _Libc._(this.get, this.set, this.remove);
  final _GetDart get;
  final _SetDart set;
  final _RemoveDart remove;

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
      );
    } on ArgumentError {
      // A libc without xattr: no tags on disk.
    }
    return _instance;
  }
}

/// The value of an attribute (UTF-8 text), or null if missing or unreadable.
String? readAttribute(String path, String name) {
  final libc = _Libc.instance;
  if (libc == null) return null;
  final p = path.toNativeUtf8();
  final n = name.toNativeUtf8();
  try {
    final size = libc.get(p, n, nullptr, 0);
    if (size <= 0 || size > 1 << 16) return null;
    final buffer = calloc<Uint8>(size);
    try {
      final read = libc.get(p, n, buffer, size);
      if (read < 0) return null;
      return utf8.decode(buffer.asTypedList(read), allowMalformed: true);
    } finally {
      calloc.free(buffer);
    }
  } finally {
    calloc
      ..free(p)
      ..free(n);
  }
}

/// Writes an attribute; an empty value removes it. False if the disk does not allow it.
bool writeAttribute(String path, String name, String value) {
  final libc = _Libc.instance;
  if (libc == null) return false;
  final p = path.toNativeUtf8();
  final n = name.toNativeUtf8();
  try {
    if (value.isEmpty) {
      final r = libc.remove(p, n);
      // Removing one that is not there is fine.
      return r == 0 || readAttribute(path, name) == null;
    }
    final bytes = Uint8List.fromList(utf8.encode(value));
    final buffer = calloc<Uint8>(bytes.length);
    try {
      buffer.asTypedList(bytes.length).setAll(0, bytes);
      return libc.set(p, n, buffer, bytes.length, 0) == 0;
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
