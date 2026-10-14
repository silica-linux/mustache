# Selection and keyboard

## Selection rectangle (MU-30, MU-33)

| Part | Light (on `#ffffff`) | Dark (on `#272728`) | AC |
| --- | --- | --- | --- |
| Fill | `#e6e6e6` (black ~10 %) | `#3c3c3d` (white ~10 %) | *as the selected icon background in AC, `#a6a6a6` / `#676768` (provisional)* |
| 1 pt border | `#aaaaaa` (black ~33 %) | `#6c6c6d` (white ~32 %) | — |
| Corners | square | square | |

- **R7.1** Dragging from the empty area of the icon view draws the rectangle. It selects, live,
  every item whose icon or label it intersects, and it stays inside the visible area.
- **R7.2** In the list, dragging from the empty part of a row selects **whole rows** live,
  **with no rectangle**.
- **R7.3** Clicking with modifiers:

  | Click | Effect |
  | --- | --- |
  | ⌘-click | adds or removes an item |
  | ⇧-click **in the list** | selects the contiguous range |
  | ⇧-click **in the icon view** | the same as ⌘-click: adds or removes one item, never a range |
  | Click on the empty area | deselects |
- **R7.6** In the icon view, ⇧ plus arrows select a **linear range in reading order** (not a
  rectangle), from the anchor to the cursor. With 6 columns, starting from item 1:

  | Keys | Selection |
  | --- | --- |
  | ⇧→ ⇧→ | 1–3 |
  | ⇧↓ (from 3, the cursor goes to the item below, 9) | **1–9** |
  | ⇧← | 1–8 |
  | ⇧↑ (the cursor goes to the item above, 2) | 1–2 |
  | ⇧↑ on the first row | nothing |
- **R7.4** When the pointer leaves the edge while selecting, scrolling starts at once (≤ 50 ms).
  Its speed is **proportional to the distance d** past the edge and **constant over time**:
  icons ≈ **38.5 pt/s per pt**, list ≈ **20 pt/s per pt**.

  | d (pt) | −5 | 1 | 5 | 20 | 60 | 120 |
  | --- | --- | --- | --- | --- | --- | --- |
  | Icons at 64 (pt/s) | 0 | 39 | 195 | 770 | 2308 | 4561 |
  | List (pt/s) | — | — | 98 | 401 | 1208 | — |

  An earlier single point (~300 pt/s at d = 10 in the list) was incomplete; the table is the
  six-point measurement.

## Keyboard (MU-31, MU-10, MU-61)

| Key | Effect |
| --- | --- |
| → ← ↑ ↓ (icons) | moves in the grid, **no wrap-around** at the edges |
| → from the last item of an incomplete row | the nearest item to the right in the row above (geometric) |
| → / ← (list) | opens / closes the selected folder |
| ⌘↓ | opens the selected folder in the same window, with an empty selection |
| ⌘↑ | the parent folder, with the folder just left selected |
| ⌘[ / ⌘] | back / forward, with an empty selection |
| Return | **rename** (it does not open) |
| Tab / ⇧Tab / ⌥Tab | next / previous / next in alphabetical order, with wrap-around |
| ⌃Tab / ⌃⇧Tab (keyboard navigation on) | cycles the window's controls, without the sidebar (R1.30) |
| Esc | cancels a rename |
| Letters | the first name with that prefix |
| Space | quick preview ([quick-look.md](quick-look.md)) |

- **R7.5** Type-to-select keeps extending the prefix while the gap between releasing one letter
  and pressing the next is ≤ 0.90 s. From 0.95 s it starts over. The threshold is **~930 ms**
  (±30).

## Drag thresholds (MU-34, MU-40)

| View | Threshold |
| --- | --- |
| List | **1 pt** |
| Columns | **1 pt** |
| Icons (64) | **~8–9 pt** (7 never, 8 sometimes, 9 always) |
| Sidebar | **5 pt** |
| Desktop (icons 96) | **4–5 pt** (3 never, 4 two times in three, 5 always) |

- **R7.7** On the desktop, with free positions, releasing at the starting point still moves the
  icon by the distance the pointer covered inside the threshold (1–3 pt).
