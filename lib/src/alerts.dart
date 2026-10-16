// The alerts of the app (kit `Alerts/*`): an Amalfi alert with the app icon, a title, a message and
// push buttons; the default button last, a destructive one in terracotta. The buttons are the
// `AlertButton`s of silica_ui (label, role, action).

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

/// An alert over the window: the buttons in the order they were given (the default one last).
class MustacheAlert extends StatelessWidget {
  const MustacheAlert({
    super.key,
    required this.title,
    required this.buttons,
    this.message,
    this.icon,
    this.sideBySide = false,
    this.opaque = true,
  });

  final String title;
  final String? message;
  final Widget? icon;
  final List<AlertButton> buttons;

  /// Kept for callers: the Amalfi alert puts up to two buttons side by side and stacks more.
  final bool sideBySide;
  final bool opaque;

  @override
  Widget build(BuildContext context) => AmalfiAlert(
    icon: icon,
    title: title,
    message: message,
    critical: buttons.any((b) => b.role == AlertRole.destructive),
    actions: [
      for (final button in buttons)
        KeyedSubtree(
          key: ValueKey('alert ${button.label}'),
          child: AmalfiPushButton(
            label: button.label,
            onPressed: button.onPressed,
            variant: switch (button.role) {
              AlertRole.primary => AmalfiPushButtonVariant.primary,
              AlertRole.destructive => AmalfiPushButtonVariant.destructive,
              AlertRole.normal ||
              AlertRole.cancel => AmalfiPushButtonVariant.secondary,
            },
          ),
        ),
    ],
  );
}
