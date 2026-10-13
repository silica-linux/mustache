// Gli attributi estesi dei file (xattr) per le etichette e i commenti, con le chiavi della
// convenzione freedesktop: `user.xdg.tags` (etichette separate da virgole) e
// `user.xdg.comment`. Le chiamate a libc (getxattr, setxattr, removexattr) passano da FFI; un
// file system che non li supporta, un permesso mancante o una libc diversa danno null o false,
// mai un'eccezione.

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
      // Una libc senza xattr: niente etichette su disco.
    }
    return _instance;
  }
}

/// Il valore di un attributo (testo UTF-8), o null se manca o non si legge.
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

/// Scrive un attributo; un valore vuoto lo toglie. Falso se il disco non lo permette.
bool writeAttribute(String path, String name, String value) {
  final libc = _Libc.instance;
  if (libc == null) return false;
  final p = path.toNativeUtf8();
  final n = name.toNativeUtf8();
  try {
    if (value.isEmpty) {
      final r = libc.remove(p, n);
      // Toglierne uno che non c'è va bene.
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

/// Le etichette di un file (in ordine, senza doppioni).
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
