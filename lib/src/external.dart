import 'dart:io';

/// True under `flutter test`: nothing may start programs on the machine running the tests
/// (opening a file there would launch the user's own apps).
bool get startsNothing => Platform.environment.containsKey('FLUTTER_TEST');

/// Starts [executable] detached, unless running under `flutter test`: there it only checks that
/// the program exists (a missing one still fails as it would for real), and starts nothing.
Future<void> startDetached(String executable, List<String> arguments) async {
  if (startsNothing) {
    if (!_found(executable)) {
      throw ProcessException(
        executable,
        arguments,
        'No such file or directory',
        2,
      );
    }
    return;
  }
  await Process.start(executable, arguments, mode: ProcessStartMode.detached);
}

/// The program is a file, by its path or in `PATH`.
bool _found(String executable) {
  if (executable.contains('/')) return File(executable).existsSync();
  final path = Platform.environment['PATH'] ?? '';
  return path
      .split(':')
      .where((dir) => dir.isNotEmpty)
      .any((dir) => File('$dir/$executable').existsSync());
}

/// Runs [executable] to the end and returns what it printed, unless running under
/// `flutter test`: there it starts nothing and returns null, as for a missing program or a
/// failure (callers then fall back to a fake or to nothing).
ProcessResult? runQuietly(String executable, List<String> arguments) {
  if (startsNothing) return null;
  try {
    return Process.runSync(executable, arguments);
  } on ProcessException {
    return null;
  }
}
