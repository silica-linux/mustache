// Mustache, il gestore dei file di Silica.

import 'dart:io';

import 'package:flutter/widgets.dart';

import 'src/model.dart';
import 'src/settings.dart';
import 'src/tabs.dart';
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
  final places = userPlaces(
    home: home,
    userDirs: userDirs.existsSync() ? userDirs.readAsStringSync() : null,
  );
  final trash = trashPlace(home: home, dataHome: env['XDG_DATA_HOME']);
  final settings = Settings.forUser(env);
  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      // Una finestra per scheda (⌘T).
      child: TabsHost(
        start: start,
        build: (tab, tabBar, onLocation, active) => MustacheWindow(
          start: tab.location,
          places: places,
          trash: trash,
          iconsDir: env['SILICA_ICONS_DIR'],
          settings: settings,
          tabBar: tabBar,
          onLocation: onLocation,
          focused: active,
        ),
      ),
    ),
  );
}
