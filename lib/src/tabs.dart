// Tabs (MU-01, docs/spec/tabs.md): ⌘T opens a tab in the folder of the active tab, ⌘W closes it, ⌃⇥
// and ⌃⇧⇥ move to the next and the previous. The bar appears with at least two tabs, below the
// toolbar and only above the content: a capsule rail 28 tall (border 1, radius 14), the active tab
// as a pill 24 tall inset by 2 pt, 1 × 16 separators between inactive tabs, "+" in a 30 pt circle;
// the × appears on the left on hover. Equal widths (the measured differences follow no rule), at
// least 120 pt.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'model.dart';

const double tabRailHeight = 28;
const double tabPillHeight = 24;
const double tabMinWidth = 120;
const double tabPlusSide = 30;

/// A tab: where it started and where it is now.
class TabInfo {
  TabInfo(this.id, this.location);
  final int id;
  String location;
}

class NewTabIntent extends Intent {
  const NewTabIntent();
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
            onInvoke: (_) {
              newTab();
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

/// Tab bar colors (MU-01), light and dark.
@immutable
class TabColors {
  const TabColors({
    required this.rail,
    required this.railBorder,
    required this.active,
    required this.hovered,
    required this.separator,
    required this.plus,
    required this.plusGlyph,
    required this.title,
    required this.titleInactive,
    required this.close,
  });

  final Color rail;
  final Color railBorder;
  final Color active;
  final Color hovered;
  final Color separator;
  final Color plus;
  final Color plusGlyph;
  final Color title;
  final Color titleInactive;
  final Color close;

  static const TabColors light = TabColors(
    rail: Color(0xFFE8E8E8),
    railBorder: Color(0xFFDCDCDC),
    active: Color(0xFFFEFDFE),
    hovered: Color(0xFFDCDCDC),
    separator: Color(0xFFCCCCCC),
    plus: Color(0xFFF8F8F8),
    plusGlyph: Color(0xFF282828),
    title: Color(0xFF4C4B4C),
    titleInactive: Color(0xFF828282),
    close: Color(0xFF7B7B7B),
  );

  static const TabColors dark = TabColors(
    rail: Color(0xFF404041),
    railBorder: Color(0xFF4F4F50),
    active: Color(0xFF464648),
    hovered: Color(0xFF4B4B4B),
    separator: Color(0xFF575758),
    plus: Color(0xFF474748),
    plusGlyph: Color(0xFFDADADA),
    title: Color(0xFFECECEC),
    titleInactive: Color(0xFF8B8B8C),
    close: Color(0xFF909091),
  );

  static TabColors of(BuildContext context) =>
      MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark
      ? dark
      : light;
}

class _TabBar extends StatefulWidget {
  const _TabBar({required this.host});
  final TabsHostState host;

  @override
  State<_TabBar> createState() => _TabBarState();
}

class _TabBarState extends State<_TabBar> {
  int? _hovered;

  TextStyle _title(TabColors colors, bool active) => TextStyle(
    fontFamily: uiFontFamily,
    package: 'silica_ui',
    fontSize: 11,
    color: active ? colors.title : colors.titleInactive,
  );

  @override
  Widget build(BuildContext context) {
    final host = widget.host;
    final tabs = host.tabs;
    final colors = TabColors.of(context);
    return SizedBox(
      key: const ValueKey('tab bar'),
      height: tabRailHeight + 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 7, 4),
        child: Row(
          children: [
            // Left of the first tab the bar moves the window (MU-08); between the last tab and "+"
            // it does not.
            const WindowDragArea(
              key: ValueKey('tab grip'),
              child: SizedBox(width: 8, height: tabRailHeight),
            ),
            Expanded(
              child: Container(
                height: tabRailHeight,
                decoration: BoxDecoration(
                  color: colors.rail,
                  borderRadius: BorderRadius.circular(tabRailHeight / 2),
                  border: Border.all(color: colors.railBorder),
                ),
                padding: const EdgeInsets.all(1),
                child: LayoutBuilder(
                  builder: (context, box) {
                    // Equal widths; below 120 pt the rail scrolls.
                    final width = box.maxWidth / tabs.length;
                    final each = width < tabMinWidth ? tabMinWidth : width;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < tabs.length; i++)
                            SizedBox(width: each, child: _tab(colors, i)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 3),
            GestureDetector(
              key: const ValueKey('new tab'),
              onTap: host.newTab,
              child: Container(
                width: tabPlusSide,
                height: tabPlusSide,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.plus,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '+',
                  style: TextStyle(
                    fontSize: 16,
                    color: colors.plusGlyph,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(TabColors colors, int i) {
    final host = widget.host;
    final active = i == host.active;
    final hovered = _hovered == i;
    final next = i + 1;
    // The separator disappears next to the active tab and the one under the pointer.
    final separator =
        !active &&
        next < host.tabs.length &&
        next != host.active &&
        !hovered &&
        _hovered != next;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = i),
      onExit: (_) => setState(() {
        if (_hovered == i) _hovered = null;
      }),
      child: GestureDetector(
        key: ValueKey('tab ${host.tabs[i].id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => host.select(i),
        child: Stack(
          children: [
            if (active || hovered)
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: active ? colors.active : colors.hovered,
                    borderRadius: BorderRadius.circular(tabPillHeight / 2),
                  ),
                ),
              ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Center(
                  child: Text(
                    displayName(host.tabs[i].location),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _title(colors, active),
                  ),
                ),
              ),
            ),
            // The × on the left on hover.
            if (hovered)
              Positioned(
                left: 4,
                top: (tabRailHeight - 2 - 18) / 2,
                width: 18,
                height: 18,
                child: GestureDetector(
                  key: ValueKey('close tab ${host.tabs[i].id}'),
                  onTap: () => host.closeTab(i),
                  child: Center(
                    child: Text(
                      '×',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.close,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            if (separator)
              Positioned(
                right: 0,
                top: (tabRailHeight - 2 - 16) / 2,
                width: 1,
                height: 16,
                child: ColoredBox(color: colors.separator),
              ),
          ],
        ),
      ),
    );
  }
}
