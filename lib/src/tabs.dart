// Tabs (MU-01, docs/spec/tabs.md): ⌘T opens a tab in the folder of the active tab, ⌘W closes it, ⌃⇥
// and ⌃⇧⇥ move to the next and the previous. The bar appears with at least two tabs, below the
// toolbar and only above the content: Amalfi tabs (the selected one raised) and a round "+" button;
// the × shows on the chosen tab and on hover. Equal widths (the measured differences follow no
// rule).

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'l10n.dart';
import 'model.dart';

/// The tab bar (kit `Apps/Mustache/Tab Bar`): 36 tall, tabs 28 tall 4 apart from x 8, the new tab
/// button 24.
const double tabBarOuterHeight = 36;

/// A tab: where it started and where it is now.
class TabInfo {
  TabInfo(this.id, this.location);
  final int id;
  String location;
}

class NewTabIntent extends Intent {
  /// A new tab, at [at] (the current folder by default).
  const NewTabIntent([this.at]);
  final String? at;
}

class CloseTabIntent extends Intent {
  const CloseTabIntent();
}

class NextTabIntent extends Intent {
  const NextTabIntent(this.step);
  final int step;
}

/// Holds the tabs of a window: one view per tab, the bar when there is more than one.
class TabsHost extends StatefulWidget {
  const TabsHost({super.key, required this.start, required this.build});

  final String start;

  /// The window of a tab: it receives the tab bar (null with a single tab), the function to report
  /// where it is, and whether it is the active tab (it takes the keyboard).
  final Widget Function(
    TabInfo tab,
    Widget? tabBar,
    ValueChanged<String> onLocation,
    bool active,
  )
  build;

  @override
  State<TabsHost> createState() => TabsHostState();
}

class TabsHostState extends State<TabsHost> {
  late final List<TabInfo> tabs = [TabInfo(0, widget.start)];
  int active = 0;
  int _next = 1;

  void newTab([String? at]) {
    setState(() {
      tabs.insert(active + 1, TabInfo(_next++, at ?? tabs[active].location));
      active++;
    });
  }

  void closeTab(int index) {
    if (tabs.length == 1) {
      // The last tab closes the window.
      SystemNavigator.pop().ignore();
      return;
    }
    setState(() {
      tabs.removeAt(index);
      if (index < active) active--;
      if (active >= tabs.length) active = tabs.length - 1;
    });
  }

  void select(int index) {
    setState(() => active = index.clamp(0, tabs.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final bar = tabs.length < 2 ? null : _TabBar(host: this);
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyT, meta: true): NewTabIntent(),
        SingleActivator(LogicalKeyboardKey.keyW, meta: true): CloseTabIntent(),
        SingleActivator(LogicalKeyboardKey.tab, control: true): NextTabIntent(
          1,
        ),
        SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true):
            NextTabIntent(-1),
      },
      child: Actions(
        actions: {
          NewTabIntent: CallbackAction<NewTabIntent>(
            onInvoke: (intent) {
              newTab(intent.at);
              return null;
            },
          ),
          CloseTabIntent: CallbackAction<CloseTabIntent>(
            onInvoke: (_) {
              closeTab(active);
              return null;
            },
          ),
          NextTabIntent: CallbackAction<NextTabIntent>(
            onInvoke: (intent) {
              select((active + intent.step) % tabs.length);
              return null;
            },
          ),
        },
        child: IndexedStack(
          index: active,
          children: [
            for (final tab in tabs)
              KeyedSubtree(
                key: ValueKey('tab ${tab.id}'),
                // Only the active tab takes the keyboard focus.
                child: TickerMode(
                  enabled: tab == tabs[active],
                  // Tabs behind do not take the keyboard.
                  child: ExcludeFocus(
                    excluding: tab != tabs[active],
                    child: widget.build(tab, tab == tabs[active] ? bar : null, (
                      location,
                    ) {
                      if (tab.location != location) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => tab.location = location);
                        });
                      }
                    }, tab == tabs[active]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.host});
  final TabsHostState host;

  @override
  Widget build(BuildContext context) {
    final tabs = host.tabs;
    return SizedBox(
      key: const ValueKey('tab bar'),
      height: tabBarOuterHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Row(
          spacing: 4,
          children: [
            // Equal widths (the measured differences follow no rule), at least 120 pt: below that
            // the tabs stay at the minimum and the rest is cut.
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey('tab ${tabs[i].id}'),
                  child: AmalfiTab(
                    label: displayName(tabs[i].location),
                    selected: i == host.active,
                    width: null,
                    closeLabel: l10n.menuCloseTab,
                    onSelect: () => host.select(i),
                    onClose: () => host.closeTab(i),
                  ),
                ),
              ),
            // Kit `Buttons/Icon/Round/Small`.
            KeyedSubtree(
              key: const ValueKey('new tab'),
              child: AmalfiIconButton(
                icon: const AmalfiGlyph(AmalfiGlyphs.plus),
                onPressed: host.newTab,
                semanticLabel: l10n.menuNewTab,
                shape: AmalfiIconButtonShape.round,
                size: AmalfiControlSize.small,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
