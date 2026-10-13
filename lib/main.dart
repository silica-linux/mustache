// Mustache, il gestore dei file di Silica.

import 'dart:io';

import 'package:flutter/widgets.dart';

import 'src/model.dart';
import 'src/window.dart';

void main(List<String> args) {
  final env = Platform.environment;
  final home = env['HOME'] ?? '/';
  final userDirs = File(
    '${env['XDG_CONFIG_HOME'] ?? '$home/.config'}/user-dirs.dirs',
  );
  final start = args.isNotEmpty && Directory(args.first).existsSync()
      ? args.first
      : home;
  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MustacheWindow(
        start: start,
        places: userPlaces(
          home: home,
          userDirs: userDirs.existsSync() ? userDirs.readAsStringSync() : null,
        ),
        trash: trashPlace(home: home, dataHome: env['XDG_DATA_HOME']),
        iconsDir: env['SILICA_ICONS_DIR'],
      ),
    ),
  );
}
