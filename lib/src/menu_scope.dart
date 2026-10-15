// One menu bar for the process (silica_ui allows one `SilicaMenuBar` per app): [MenuScope] sits at
// the root and publishes the menus of whoever owns them now. A window process publishes the menus
// of its active tab; the desktop process (`--desktop`) its own; the Open/Save dialog its own. They
// are different Wayland clients, so Ossido shows the frontmost one's menus and they never meet.
// Without an owner (the last tab closing) the root shows the menus with nothing enabled.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'menus.dart';

/// Holds the menus last published and who published them.
class MenuHub extends ChangeNotifier {
  Object? _owner;
  String _signature = '';
  List<PlatformMenuItem> _menus = const [];
  bool _disposed = false;

  /// The menus now, empty without an owner.
  List<PlatformMenuItem> get menus => _menus;

  /// `owner` publishes its menus. Listeners hear of it only when what the bar shows changed (or
  /// the owner did): the actions read the owner's state when they run.
  void publish(Object owner, List<PlatformMenuItem> menus) {
    final signature = menuSignature(menus);
    final changed = !identical(owner, _owner) || signature != _signature;
    _owner = owner;
    _signature = signature;
    _menus = menus;
    if (changed) notifyListeners();
  }

  /// `owner` is gone: if it still owns the menus the bar goes back to the empty ones.
  void release(Object owner) {
    scheduleMicrotask(() {
      if (_disposed || !identical(_owner, owner)) return;
      _owner = null;
      _signature = '';
      _menus = const [];
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _HubScope extends InheritedWidget {
  const _HubScope({required this.hub, required super.child});
  final MenuHub hub;

  @override
  bool updateShouldNotify(_HubScope old) => hub != old.hub;
}

/// The hub of the nearest [MenuScope] (null in tests that build a window alone).
MenuHub? menuHubOf(BuildContext context) =>
    context.getInheritedWidgetOfExactType<_HubScope>()?.hub;

/// The process' menu bar: shows what the hub holds.
class MenuScope extends StatefulWidget {
  const MenuScope({super.key, required this.child, this.hub});

  final Widget child;

  /// An outside hub (tests); otherwise the scope makes its own.
  final MenuHub? hub;

  @override
  State<MenuScope> createState() => _MenuScopeState();
}

class _MenuScopeState extends State<MenuScope> {
  late final MenuHub _hub = widget.hub ?? MenuHub();

  @override
  void initState() {
    super.initState();
    _hub.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hub.removeListener(_changed);
    if (widget.hub == null) _hub.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _HubScope(
    hub: _hub,
    // The child is the same widget on every build: only the bar is rebuilt when the menus change.
    child: SilicaMenuBar(
      menus: _hub.menus.isEmpty ? buildMenus(const MenuSpec()) : _hub.menus,
      child: widget.child,
    ),
  );
}
