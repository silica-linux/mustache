// Le schede (MU-01, mustache-spec 1.3): ⌘T apre una scheda nella cartella della scheda attiva,
// ⌘W la chiude, ⌃⇥ e ⌃⇧⇥ passano alla successiva e alla precedente. La barra compare con almeno
// due schede, sotto la barra degli strumenti e solo sopra i contenuti: binario a capsula alto 28
// (bordo 1, raggio 14), scheda attiva a pillola alta 24 con 2 pt di rientro, separatori 1 × 16
// fra le inattive, "+" in un cerchio da 30; la × compare a sinistra al passaggio. Larghezze
// uguali (le differenze misurate non seguono una regola), almeno 120 pt.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'model.dart';

const double tabRailHeight = 28;
const double tabPillHeight = 24;
const double tabMinWidth = 120;
const double tabPlusSide = 30;

/// Una scheda: dove è partita e dove si trova ora.
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

/// Tiene le schede di una finestra: una vista per scheda, la barra quando ce n'è più d'una.
class TabsHost extends StatefulWidget {
  const TabsHost({super.key, required this.start, required this.build});

  final String start;

  /// La finestra di una scheda: riceve la barra delle schede (null con una sola scheda), la
  /// funzione per dire dove si trova e se è la scheda attiva (prende la tastiera).
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
      // L'ultima scheda chiude la finestra.
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
                key: ValueKey('scheda ${tab.id}'),
                // Solo la scheda attiva prende il focus della tastiera.
                child: TickerMode(
                  enabled: tab == tabs[active],
                  // Le schede dietro non prendono la tastiera.
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

class _TabBar extends StatefulWidget {
  const _TabBar({required this.host});
  final TabsHostState host;

  @override
  State<_TabBar> createState() => _TabBarState();
}

class _TabBarState extends State<_TabBar> {
  int? _hovered;

  TextStyle _title(bool active) => TextStyle(
    fontFamily: uiFontFamily,
    package: 'silica_ui',
    fontSize: 11,
    color: active ? const Color(0xFF4C4B4C) : const Color(0xFF828282),
  );

  @override
  Widget build(BuildContext context) {
    final host = widget.host;
    final tabs = host.tabs;
    return SizedBox(
      key: const ValueKey('barra delle schede'),
      height: tabRailHeight + 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 7, 4),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: tabRailHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.circular(tabRailHeight / 2),
                  border: Border.all(color: const Color(0xFFDCDCDC)),
                ),
                padding: const EdgeInsets.all(1),
                child: LayoutBuilder(
                  builder: (context, box) {
                    // Larghezze uguali; sotto 120 pt il binario scorre.
                    final width = box.maxWidth / tabs.length;
                    final each = width < tabMinWidth ? tabMinWidth : width;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < tabs.length; i++)
                            SizedBox(width: each, child: _tab(i)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 3),
            GestureDetector(
              key: const ValueKey('nuova scheda'),
              onTap: host.newTab,
              child: Container(
                width: tabPlusSide,
                height: tabPlusSide,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F8F8),
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '+',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF282828),
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

  Widget _tab(int i) {
    final host = widget.host;
    final active = i == host.active;
    final hovered = _hovered == i;
    final next = i + 1;
    // Il separatore sparisce accanto all'attiva e a quella sotto il puntatore.
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
        key: ValueKey('scheda ${host.tabs[i].id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => host.select(i),
        child: Stack(
          children: [
            if (active || hovered)
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFFEFDFE)
                        : const Color(0xFFDCDCDC),
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
                    style: _title(active),
                  ),
                ),
              ),
            ),
            // La × a sinistra al passaggio.
            if (hovered)
              Positioned(
                left: 4,
                top: (tabRailHeight - 2 - 18) / 2,
                width: 18,
                height: 18,
                child: GestureDetector(
                  key: ValueKey('chiudi la scheda ${host.tabs[i].id}'),
                  onTap: () => host.closeTab(i),
                  child: const Center(
                    child: Text(
                      '×',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7B7B7B),
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
                child: const ColoredBox(color: Color(0xFFCCCCCC)),
              ),
          ],
        ),
      ),
    );
  }
}
