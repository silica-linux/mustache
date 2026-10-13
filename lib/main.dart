// Mustache, il gestore dei file di Silica.

import 'dart:io';

import 'package:flutter/widgets.dart';

import 'src/dialog.dart';
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
  // Un dialogo Apri o Salva per il portale (--dialog=open|save).
  final dialog = DialogOptions.parse(args);
  final folders = [
    for (final a in args)
      if (!a.startsWith('--')) a,
  ];
  final start =
      dialog?.folder ??
      (folders.isNotEmpty && Directory(folders.first).existsSync()
          ? folders.first
          : home);
  final places = userPlaces(
    home: home,
    userDirs: userDirs.existsSync() ? userDirs.readAsStringSync() : null,
  );
  final trash = trashPlace(home: home, dataHome: env['XDG_DATA_HOME']);
  final settings = Settings.forUser(env);
  if (dialog != null) {
    runApp(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MustacheWindow(
          start: start,
          places: places,
          trash: trash,
          iconsDir: env['SILICA_ICONS_DIR'],
          settings: settings,
          dialog: dialog,
        ),
      ),
    );
    return;
  }
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
