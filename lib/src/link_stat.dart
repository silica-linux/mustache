// Data e dimensione di un collegamento simbolico, non della sua destinazione (la vista a elenco
// mostra quelle del collegamento, R3.2): `lstat` di libc via FFI. Su Linux x86_64 e aarch64
// `struct stat` ha la dimensione a +48 e `st_mtim` (secondi, nanosecondi) a +88. Fuori da
// queste architetture, o se la chiamata fallisce, null: si usa la destinazione.

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _LstatC = Int32 Function(Pointer<Utf8>, Pointer<Uint8>);
typedef _LstatDart = int Function(Pointer<Utf8>, Pointer<Uint8>);

const int _statSize = 256;
const int _sizeOffset = 48;
const int _mtimeOffset = 88;

_LstatDart? _lstat = _lookup();

_LstatDart? _lookup() {
  if (!Platform.isLinux) return null;
  final abi = Abi.current();
  if (abi != Abi.linuxX64 && abi != Abi.linuxArm64) return null;
  try {
    return DynamicLibrary.process().lookupFunction<_LstatC, _LstatDart>(
      'lstat',
    );
  } on ArgumentError {
    return null;
  }
}

/// La dimensione in byte e la data di modifica del collegamento stesso.
({int size, DateTime modified})? linkStat(String path) {
  final lstat = _lstat;
  if (lstat == null) return null;
  final p = path.toNativeUtf8();
  final buffer = calloc<Uint8>(_statSize);
  try {
    if (lstat(p, buffer) != 0) return null;
    final data = buffer.asTypedList(_statSize).buffer.asByteData();
    final size = data.getInt64(_sizeOffset, Endian.little);
    final seconds = data.getInt64(_mtimeOffset, Endian.little);
    final nanos = data.getInt64(_mtimeOffset + 8, Endian.little);
    return (
      size: size < 0 ? 0 : size,
      modified: DateTime.fromMicrosecondsSinceEpoch(
        seconds * 1000000 + nanos ~/ 1000,
      ),
    );
  } finally {
    calloc
      ..free(p)
      ..free(buffer);
  }
}
