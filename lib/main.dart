// Mustache, the file manager of Silica.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'src/desktop.dart';
import 'src/dialog.dart';
import 'src/icon_arrange.dart';
import 'src/l10n.dart';
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
  // An Open or Save dialog for the portal (--dialog=open|save).
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
  final iconPositions = IconPositions.forUser(env);
  WidgetsFlutterBinding.ensureInitialized();
  // The desktop (silica-desktop#147): Ossido starts this mode on the bottom layer and keeps it
  // running; it has no window, so none of the window setup below.
  if (args.contains('--desktop')) {
    runApp(
      AppLocalizationsScope(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DesktopView(
            folder: desktopFolderOf(
              env,
              userDirs.existsSync() ? userDirs.readAsStringSync() : null,
            ),
            positions: iconPositions,
            choices: DesktopChoices.forUser(env),
            env: env,
          ),
        ),
      ),
    );
    return;
  }
  // The toolbar is unified with the window: Ossido draws only the window buttons.
  SilicaWindow.setFullSizeContent(toolbarHeight).ignore();
  if (dialog != null) {
    runApp(
      AppLocalizationsScope(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: MustacheWindow(
            start: start,
            places: places,
            trash: trash,
            iconsDir: env['SILICA_ICONS_DIR'],
            settings: settings,
            iconPositions: iconPositions,
            dialog: dialog,
          ),
        ),
      ),
    );
    return;
  }
  // The file manager keeps running with no window and has no Quit (DOCK-02, APP-LC); a
  // reopen (the Dock, the Launcher) opens a new window at the home folder.
  SilicaApp.quitEnabled = false;
  // The buttons never move as a window narrows: the window stops where they stay clear.
  SilicaWindow.setSizeLimits(min: minimumWindowSize).ignore();
  var opensAt = start;
  runApp(
    AppLocalizationsScope(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SilicaAppWindow(
          onClosed: () => opensAt = home,
          // One window per tab (⌘T).
          builder: (context) => TabsHost(
            start: opensAt,
            build: (tab, tabBar, onLocation, active) => MustacheWindow(
              start: tab.location,
              places: places,
              trash: trash,
              iconsDir: env['SILICA_ICONS_DIR'],
              settings: settings,
              iconPositions: iconPositions,
              tabBar: tabBar,
              onLocation: onLocation,
              focused: active,
            ),
          ),
        ),
      ),
    ),
  );
}
