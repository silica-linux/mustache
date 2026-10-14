import 'dart:io';

/// True under `flutter test`: nothing may start programs on the machine running the tests
/// (opening a file there would launch the user's own apps).
bool get startsNothing => Platform.environment.containsKey('FLUTTER_TEST');

/// Starts [executable] detached, unless running under `flutter test`.
Future<void> startDetached(String executable, List<String> arguments) async {
  if (startsNothing) return;
  await Process.start(executable, arguments, mode: ProcessStartMode.detached);
}
