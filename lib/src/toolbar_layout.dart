// The width states of the content toolbar (docs/design/amalfi/components.md › "Toolbar width
// states", silica-desktop; kit `Apps/Mustache/Toolbar/Bar/*`): as the toolbar narrows it drops items
// in a fixed order, and takes them back 8 pt later than it dropped them (hysteresis). The layout
// is a pure function of the width, the previous state and the search state, so it is tested
// against the table.

/// The states, widest first. Each one holds what the previous one held, minus what moved into
/// the » menu or into a pop-up.
enum ToolbarStage {
  /// Views, Group, Share · Tags · Actions and the permanent search field.
  wide,

  /// The same with the search circle.
  full,

  /// The view group is a pop-up.
  viewPopUp,

  /// Tags and Actions went into », Share stays alone.
  tagsActionsOverflow,

  /// Share went into » too.
  shareOverflow,

  /// Group went into ».
  groupOverflow,

  /// The view pop-up went into »: title, » and search.
  viewOverflow,
}

/// What a width shows.
class ToolbarLayout {
  const ToolbarLayout._(this.stage, this.hasGroup);

  final ToolbarStage stage;

  /// Whether the Group item exists at all (Mustache has no grouping yet: it is left out).
  final bool hasGroup;

  /// The permanent search field instead of the circle.
  bool get permanentSearch => stage == ToolbarStage.wide;

  /// The view group as a segmented control (false: a pop-up, or in »).
  bool get viewSegments =>
      stage == ToolbarStage.wide || stage == ToolbarStage.full;

  bool get viewPopUp =>
      stage.index >= ToolbarStage.viewPopUp.index &&
      stage.index < ToolbarStage.viewOverflow.index;

  bool get group => hasGroup && stage.index < ToolbarStage.groupOverflow.index;

  /// The Share · Tags · Actions capsule.
  bool get capsule => stage.index <= ToolbarStage.viewPopUp.index;

  /// Share alone, beside ».
  bool get shareAlone => stage == ToolbarStage.tagsActionsOverflow;

  /// The » button.
  bool get overflow => stage.index >= ToolbarStage.tagsActionsOverflow.index;

  bool get viewInOverflow => stage == ToolbarStage.viewOverflow;
  bool get groupInOverflow =>
      hasGroup && stage.index >= ToolbarStage.groupOverflow.index;
  bool get shareInOverflow => stage.index >= ToolbarStage.shareOverflow.index;
  bool get tagsActionsInOverflow =>
      stage.index >= ToolbarStage.tagsActionsOverflow.index;

  @override
  bool operator ==(Object other) =>
      other is ToolbarLayout &&
      other.stage == stage &&
      other.hasGroup == hasGroup;

  @override
  int get hashCode => Object.hash(stage, hasGroup);
}

/// The widths of the items (pt) and the room around the title.
abstract final class ToolbarWidths {
  /// 16 + back/forward 73 + 12 + title 160 + 12 + 16.
  static const double base = 289;
  static const double views = 152;
  static const double popUp = 56;
  static const double group = 56;
  static const double capsule = 110;
  static const double single = 36;
  static const double gap = 8;
  static const double hysteresis = 8;

  /// The search field open (240) against the circle (36).
  static const double searchOpen = 240;
  static const double searchExtra = searchOpen - single;

  /// The permanent field's width at the start of the Wide state, and its largest.
  static const double fieldLeast = 160;
  static const double fieldMost = 320;

  /// A focused or filled field is at least this wide.
  static const double fieldFocused = 240;

  /// Wide begins here with every item.
  static const double wide = 856;
}

List<double> _items(ToolbarStage stage, {required bool group}) =>
    switch (stage) {
      ToolbarStage.wide => [
        ToolbarWidths.views,
        if (group) ToolbarWidths.group,
        ToolbarWidths.capsule,
        ToolbarWidths.fieldLeast,
      ],
      ToolbarStage.full => [
        ToolbarWidths.views,
        if (group) ToolbarWidths.group,
        ToolbarWidths.capsule,
      ],
      ToolbarStage.viewPopUp => [
        ToolbarWidths.popUp,
        if (group) ToolbarWidths.group,
        ToolbarWidths.capsule,
      ],
      ToolbarStage.tagsActionsOverflow => [
        ToolbarWidths.popUp,
        if (group) ToolbarWidths.group,
        ToolbarWidths.single,
        ToolbarWidths.single,
      ],
      ToolbarStage.shareOverflow => [
        ToolbarWidths.popUp,
        if (group) ToolbarWidths.group,
        ToolbarWidths.single,
      ],
      ToolbarStage.groupOverflow => [ToolbarWidths.popUp, ToolbarWidths.single],
      ToolbarStage.viewOverflow => [ToolbarWidths.single],
    };

/// The width at which `stage` fits (it leaves below it, and comes back at this plus
/// [ToolbarWidths.hysteresis]). The search item is the circle, or the field when [searchOpen].
double toolbarStageWidth(
  ToolbarStage stage, {
  required bool searchOpen,
  required bool group,
  required bool search,
}) {
  if (stage == ToolbarStage.wide) {
    // 856 with Group; the field takes the place of the circle. A focused or filled field is at
    // least 240 wide: it needs the room of the open field (871), or the view group collapses.
    final wide =
        ToolbarWidths.wide -
        (group ? 0 : ToolbarWidths.group + ToolbarWidths.gap);
    if (!searchOpen) return wide;
    final full = toolbarStageWidth(
      ToolbarStage.full,
      searchOpen: true,
      group: group,
      search: true,
    );
    return full > wide ? full : wide;
  }
  final items = _items(stage, group: group);
  var width = ToolbarWidths.base;
  var count = items.length;
  for (final w in items) {
    width += w;
  }
  if (search) {
    count += 1;
    width += searchOpen ? ToolbarWidths.searchOpen : ToolbarWidths.single;
  }
  return width + ToolbarWidths.gap * (count - 1);
}

/// The layout for a toolbar `width` wide (right of the sidebar), coming from `previous` (null:
/// the first time). Without [search] (it is in the preview section) there is no Wide state.
ToolbarLayout resolveToolbarLayout(
  double width, {
  ToolbarLayout? previous,
  bool searchOpen = false,
  bool hasGroup = true,
  bool search = true,
}) {
  double need(ToolbarStage s) => toolbarStageWidth(
    s,
    searchOpen: searchOpen,
    group: hasGroup,
    search: search,
  );
  final first = search ? ToolbarStage.wide : ToolbarStage.full;
  var stage = previous?.stage ?? first;
  if (stage.index < first.index) stage = first;
  // The widest state keeps its place unless the width is at least that of the state.
  if (previous == null) {
    stage = first;
  }
  const last = ToolbarStage.viewOverflow;
  while (stage.index < last.index && width < need(stage)) {
    stage = ToolbarStage.values[stage.index + 1];
  }
  while (stage.index > first.index) {
    final wider = ToolbarStage.values[stage.index - 1];
    final back =
        need(wider) +
        (wider == ToolbarStage.wide ? 0 : ToolbarWidths.hysteresis);
    if (width < back) break;
    stage = wider;
  }
  return ToolbarLayout._(stage, hasGroup);
}

/// The width of the permanent field at toolbar width `width`: 160 at the start of Wide, growing
/// by 3/4 of the extra width up to 320. Focused or holding text it is at least 240.
double permanentSearchWidth(
  double width, {
  bool hasGroup = true,
  bool filled = false,
}) {
  final start = toolbarStageWidth(
    ToolbarStage.wide,
    searchOpen: false,
    group: hasGroup,
    search: true,
  );
  final w = (ToolbarWidths.fieldLeast + 0.75 * (width - start)).clamp(
    ToolbarWidths.fieldLeast,
    ToolbarWidths.fieldMost,
  );
  return filled && w < ToolbarWidths.fieldFocused
      ? ToolbarWidths.fieldFocused
      : w;
}

/// The width of the open (expanded) field: 240; below a toolbar of 352 it narrows with it
/// (width − 112, 172 at the least).
double openSearchWidth(double width) {
  if (width >= 352) return ToolbarWidths.searchOpen;
  return (width - 112).clamp(172, ToolbarWidths.searchOpen);
}
