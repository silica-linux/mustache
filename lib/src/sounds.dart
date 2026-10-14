// Interface sound effects (FILE-SOUNDS): played by silica-daemon (`dev.frascella.Silica.Sound1`
// › `PlaySound`) over the embedder's `silica/dbus` channel. The daemon owns the sounds, the
// player and the "Play user interface sound effects" setting; without it (outside Silica, in
// tests) nothing plays and nothing fails.

import 'package:flutter/services.dart';

/// The sounds Mustache asks for.
enum UiSound {
  /// Items moved to the Trash from a menu or the keyboard.
  trashMove('trash-move'),

  /// A copy or move finished (drag and drop, paste).
  fileTransfer('file-transfer');

  const UiSound(this.id);

  /// The name the daemon knows it by.
  final String id;
}

const MethodChannel _dbus = MethodChannel('silica/dbus', JSONMethodCodec());

/// Plays `sound`; never fails.
Future<void> playUiSound(UiSound sound) async {
  try {
    await _dbus.invokeMethod<Object?>('call', {
      'bus': 'session',
      'destination': 'dev.frascella.Silica',
      'path': '/dev/frascella/Silica/Sound1',
      'interface': 'dev.frascella.Silica.Sound1',
      'method': 'PlaySound',
      'signature': 's',
      'args': [sound.id],
    });
  } on PlatformException {
    // No daemon, or no such sound: silence.
  } on MissingPluginException {
    // Outside Silica.
  }
}
