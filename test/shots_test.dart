// Renders the window to PNG files for a visual check against the kit (not run with the suite: the
// files go to the folder in MUSTACHE_SHOTS).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/model.dart';
import 'package:mustache/src/settings.dart';
import 'package:mustache/src/window.dart';

void main() {
  final out = Platform.environment['MUSTACHE_SHOTS'];
  if (out == null) return;

  for (final dark in [false, true]) {
    for (final view in ['icons', 'list', 'columns', 'gallery']) {
      testWidgets('$view ${dark ? 'dark' : 'light'}', (tester) async {
        final root = Directory.systemTemp.createTempSync('mu-shot');
        addTearDown(() => root.deleteSync(recursive: true));
        for (final n in [
          'Desktop',
          'Documents',
          'Downloads',
          'Music',
          'Pictures',
          'Projects',
          'Public',
          'Templates',
          'Videos',
        ]) {
          Directory('${root.path}/$n').createSync();
        }
        File('${root.path}/Documents/notes.txt').writeAsStringSync('hello');
        Directory('${root.path}/Documents/Recipes').createSync();
        tester.view.physicalSize = const Size(1000, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: MustacheWindow(
                start: view == 'columns' ? '${root.path}/Documents' : root.path,
                places: [
                  Place('Desktop', '${root.path}/Desktop', PlaceKind.desktop),
                  Place(
                    'Documents',
                    '${root.path}/Documents',
                    PlaceKind.documents,
                  ),
                  Place(
                    'Downloads',
                    '${root.path}/Downloads',
                    PlaceKind.downloads,
                  ),
                  Place(
                    'Pictures',
                    '${root.path}/Pictures',
                    PlaceKind.pictures,
                  ),
                  Place('Music', '${root.path}/Music', PlaceKind.music),
                  Place('Videos', '${root.path}/Videos', PlaceKind.videos),
                  Place('silica', root.path, PlaceKind.home),
                ],
                trash: Place('Trash', '${root.path}/.Trash', PlaceKind.trash),
                now: DateTime.now(),
                iconsEnv: Platform.environment,
                settings: Settings('${root.path}/.s.json')
                  ..view = view
                  ..statusBar = true
                  ..pathBar = true,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$out/$view-${dark ? 'dark' : 'light'}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      });
    }
  }
}
