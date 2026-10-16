// Helpers for the tests that compare the app with the masters of the Silica "Amalfi" UI kit
// (`Apps/Mustache/*`): the masters' layer frames are copied (slimmed) into `test/kit/`, named with
// `__` for `/` (`List Row__Even__Light.json`), and read here. Frames are in whole points.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

/// A scene as the app draws it: the appearance of the platform, left to right text, the content at
/// the top left.
Widget kitScene(Widget child, {bool dark = false}) => MediaQuery(
  data: MediaQueryData(
    platformBrightness: dark ? Brightness.dark : Brightness.light,
  ),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: child),
  ),
);

/// A layer of a master.
class KitLayer {
  KitLayer(this.json);
  final Map<String, dynamic> json;

  String get name => json['name'] as String;
  String? get text => json['text'] as String?;

  Rect get frame {
    final f = json['frame'] as Map<String, dynamic>;
    return Rect.fromLTWH(
      (f['x'] as num).toDouble(),
      (f['y'] as num).toDouble(),
      (f['w'] as num).toDouble(),
      (f['h'] as num).toDouble(),
    );
  }

  Size get size => frame.size;

  List<KitLayer> get children => [
    for (final c in (json['children'] as List? ?? const []))
      KitLayer(c as Map<String, dynamic>),
  ];

  /// The first descendant called `name` (a path `a/b` descends one level at a time).
  KitLayer layer(String name) {
    var layer = this;
    for (final part in name.split('/')) {
      layer = layer.children.firstWhere(
        (c) => c.name == part,
        orElse: () => throw StateError('no layer $part in ${layer.name}'),
      );
    }
    return layer;
  }

  /// The frames of every direct child called `name`, in the master's order (separators repeat).
  List<Rect> rects(String name) => [
    for (final c in children)
      if (c.name == name) c.frame,
  ];

  /// The frame of the layer called `name`, relative to this one.
  Rect rect(String name) => layer(name).frame;

  /// The token of the first fill (`Light/Surface/Window`), or null.
  String? get fillToken {
    final fills = (json['style']?['fills'] as List?) ?? const [];
    return fills.isEmpty ? null : fills.first['swatch'] as String?;
  }

  /// The radius of the first corner.
  double? get radius {
    final radii = (json['style']?['corners']?['radii'] as List?) ?? const [];
    return radii.isEmpty ? null : (radii.first as num).toDouble();
  }
}

/// A master of `Apps/Mustache`, e.g. `KitMaster.load('List Row/Even')` (Light) or
/// `KitMaster.load('Icons', dark: true)`.
KitLayer loadKit(String master, {bool dark = false}) {
  final name =
      '${master.replaceAll('/', '__')}__${dark ? 'Dark' : 'Light'}.json';
  final file = File('test/kit/$name');
  return KitLayer(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
}

/// The Amalfi colors of an appearance.
AmalfiColors kitColors({bool dark = false}) =>
    dark ? AmalfiColors.dark : AmalfiColors.light;

/// The text of the toolbar title.
Finder titleText() => find.descendant(
  of: find.byKey(const ValueKey('title')),
  matching: find.byType(Text),
);
