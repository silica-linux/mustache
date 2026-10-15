// One shared watch per displayed folder. Every window, the desktop and the column and list
// expansions that show a folder subscribe here; the folder is watched once while anyone shows
// it, and every subscriber is told (debounced) when something in it changes, whatever made the
// change: this window, another one, the desktop, another app or the terminal. A move to the
// Trash is a rename, a delete or a create in the folder; the Trash folder itself is watched like
// any other.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'external.dart';

/// Called with the paths that changed in a watched folder.
typedef FolderChanged = void Function(List<String> paths);

class _Watch {
  StreamSubscription<FileSystemEvent>? sub;
  final Map<int, FolderChanged> listeners = {};
  final Set<String> pending = {};
  Timer? flush;
}

class FolderWatcher {
  FolderWatcher({
    this.debounce = const Duration(milliseconds: 120),
    bool? watchDisk,
  }) : watchDisk = watchDisk ?? !startsNothing;

  /// How long changes are gathered before subscribers are told (the first change starts the wait,
  /// so a steady stream of events still reloads every [debounce]).
  final Duration debounce;

  /// Watch the disk for real (off under `flutter test`, where tests deliver [notify] by hand
  /// unless they ask for it).
  final bool watchDisk;

  final Map<String, _Watch> _watches = {};
  int _next = 0;

  /// Watches [dir] while shown; the returned function stops this subscription. The watch on the
  /// disk is shared and counted.
  VoidCallback watch(String dir, FolderChanged onChange) {
    final w = _watches.putIfAbsent(dir, () {
      final created = _Watch();
      if (watchDisk) _start(dir, created);
      return created;
    });
    final id = _next++;
    w.listeners[id] = onChange;
    var done = false;
    return () {
      if (done) return;
      done = true;
      final current = _watches[dir];
      if (current == null) return;
      current.listeners.remove(id);
      if (current.listeners.isEmpty) {
        _watches.remove(dir);
        current.sub?.cancel();
        current.flush?.cancel();
      }
    };
  }

  /// Starts the disk watch of [dir]. A folder that does not exist yet (the Trash before the first
  /// item is trashed) is watched through its nearest existing ancestor until it appears.
  void _start(String dir, _Watch w) {
    var target = dir;
    while (!Directory(target).existsSync()) {
      final slash = target.lastIndexOf('/');
      if (slash <= 0) {
        target = '/';
        break;
      }
      target = target.substring(0, slash);
    }
    try {
      w.sub = Directory(target).watch().listen((event) {
        if (target != dir && Directory(dir).existsSync()) {
          w.sub?.cancel();
          _start(dir, w);
          notify(dir, dir);
        } else if (target == dir) {
          notify(dir, event.path);
        }
      }, onError: (Object _) {});
    } on FileSystemException {
      w.sub = null;
    }
  }

  /// A change at [path] in the watched [dir], debounced. The watcher calls this for each disk
  /// event; tests call it by hand.
  void notify(String dir, String path) {
    final w = _watches[dir];
    if (w == null) return;
    w.pending.add(path);
    w.flush ??= Timer(debounce, () {
      w.flush = null;
      final paths = [...w.pending];
      w.pending.clear();
      for (final f in w.listeners.values.toList()) {
        f(paths);
      }
    });
  }

  /// The folders watched now.
  @visibleForTesting
  Set<String> get watched => _watches.keys.toSet();

  void dispose() {
    for (final w in _watches.values) {
      w.sub?.cancel();
      w.flush?.cancel();
    }
    _watches.clear();
  }
}

/// The folder watches of the whole app.
FolderWatcher folderWatcher = FolderWatcher();
