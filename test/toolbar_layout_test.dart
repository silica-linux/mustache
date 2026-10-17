import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/toolbar_layout.dart';

// The thresholds of components.md › "Toolbar width states": leaves below / comes back at.
void main() {
  // (state, leaves below, comes back at, with the search open: leaves, comes back)
  const table = [
    (ToolbarStage.full, 667, 675, 871, 879),
    (ToolbarStage.viewPopUp, 571, 579, 775, 783),
    (ToolbarStage.tagsActionsOverflow, 541, 549, 745, 753),
    (ToolbarStage.shareOverflow, 497, 505, 701, 709),
    (ToolbarStage.groupOverflow, 433, 441, 637, 645),
    (ToolbarStage.viewOverflow, 369, 369, 573, 573),
  ];

  for (final open in [false, true]) {
    for (final (stage, leaves, back, openLeaves, openBack) in table) {
      // Below the last one only the minimum remains (Back/Forward in »): not modelled.
      if (stage == ToolbarStage.viewOverflow) continue;
      final l = open ? openLeaves : leaves;
      final b = open ? openBack : back;
      test('${stage.name} leaves below $l and returns at $b (open: $open)', () {
        ToolbarLayout at(double w, ToolbarLayout? from) =>
            resolveToolbarLayout(w, previous: from, searchOpen: open);
        // Coming from the wider side it stays down to its width, then leaves.
        var layout = at(1200, null);
        for (var w = 1200.0; w >= l; w--) {
          layout = at(w, layout);
        }
        expect(layout.stage.index <= stage.index, isTrue);
        final held = layout;
        layout = at(l - 1.0, layout);
        expect(layout.stage.index, greaterThan(stage.index));
        // Coming back: not before 8 pt later (the last state has none).
        if (b != l) {
          layout = at(b - 1.0, layout);
          expect(layout.stage.index, greaterThan(stage.index));
        }
        layout = at(b.toDouble(), layout);
        expect(layout.stage.index, lessThanOrEqualTo(stage.index));
        expect(held.stage.index, lessThanOrEqualTo(stage.index));
      });
    }
  }

  test('Wide starts at 856 without hysteresis', () {
    expect(resolveToolbarLayout(856).permanentSearch, isTrue);
    final below = resolveToolbarLayout(855);
    expect(below.permanentSearch, isFalse);
    expect(resolveToolbarLayout(856, previous: below).permanentSearch, isTrue);
  });

  test('what each state shows', () {
    ToolbarLayout at(double w) => resolveToolbarLayout(w);
    final full = at(700);
    expect(
      (full.viewSegments, full.group, full.capsule, full.overflow),
      (true, true, true, false),
    );
    final popUp = at(600);
    expect(
      (popUp.viewSegments, popUp.viewPopUp, popUp.capsule),
      (false, true, true),
    );
    final tags = at(545);
    expect((tags.shareAlone, tags.overflow, tags.capsule), (true, true, false));
    expect(at(500).shareInOverflow, isTrue);
    expect(at(500).group, isTrue);
    expect(at(436).groupInOverflow, isTrue);
    expect(at(440).viewPopUp, isTrue);
    expect(at(380).viewInOverflow, isTrue);
  });

  test('without Group the states shift and no state shows it', () {
    final layout = resolveToolbarLayout(700, hasGroup: false);
    expect(layout.group, isFalse);
    expect(layout.groupInOverflow, isFalse);
    expect(
      toolbarStageWidth(
        ToolbarStage.full,
        searchOpen: false,
        group: false,
        search: true,
      ),
      667 - 64,
    );
  });

  test('without search (it is in the preview section) there is no Wide', () {
    expect(resolveToolbarLayout(2000, search: false).stage, ToolbarStage.full);
  });

  test(
    'the permanent field grows from 160 to 320; focused it is at least 240',
    () {
      expect(permanentSearchWidth(856), 160);
      expect(permanentSearchWidth(900), 193);
      expect(permanentSearchWidth(2000), 320);
      expect(permanentSearchWidth(860, filled: true), 240);
      expect(permanentSearchWidth(2000, filled: true), 320);
    },
  );

  test('the open field narrows below a toolbar of 352', () {
    expect(openSearchWidth(500), 240);
    expect(openSearchWidth(300), 188);
    expect(openSearchWidth(284), 172);
  });
}
