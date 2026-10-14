# Path bar and status bar

## Path bar, ⌥⌘P (MU-03)

| Measure | Value |
| --- | --- |
| Position | under the content area (not under the sidebar), **above the status bar**. The window does not grow: the scroll area loses 28 pt |
| Height | **28 pt** including its top line (2 px line + 26 pt background) |
| Material | translucent: the content under it shows blurred |
| First segment | icon at x 13 of the content area |
| Icons | 16 pt (disk 12 × 13, folders 14 × 13) |
| Text | 5 pt after the icon; capital height 9 pt (as the list's names at 13 pt) |
| Separator | a › chevron **5 × 7**, 5–6 pt from the text and 6–7 pt from the next icon (pitch = text + ~36) |
| Compressed segment | **29 pt** (icon + chevron) |

| Color | Light | Dark |
| --- | --- | --- |
| Background (over empty content) | `#ffffff` | `#2f2f2f` |
| Top line (2 px) | `#dcdddd` + `#e6e6e6` | `#3f3f40` + `#434343` |
| Text and chevrons | `#7f7f7f` | `#a1a1a1` |
| Increase Contrast text | *`#393939` / `#c4c4c4` (provisional: as the list's secondary columns)* | |
| Inactive window | unchanged | unchanged |

- **R1.17** With a selection, the selected item is the **last segment**.
- **R1.18** A **single** click on a segment shows that folder in the window; the segments after
  it disappear. Hovering a segment draws no background.
- **R1.19** A file dropped on a segment is **moved** there. Segments do not spring open, even
  after 2.5 s.
- **R1.20** When space runs out, the segments shrink in three steps. The cut text **fades out**
  on the right, with no ellipsis.
  1. The middle segments shrink, **all by the same amount**, down to 29 pt.
  2. Then the first segment shrinks.
  3. Then the second to last.

  The last segment always stays whole.

  Example with 8 segments:

  | Window width | Segment widths |
  | --- | --- |
  | 1000 | first 107, middle 65–129 (whole), second to last 77, last 93 |
  | 800 | middle 63 |
  | 700 | middle 43 |
  | 600 | first 77, middle 29 |
  | 508 | first 29, second to last 33 |

## Status bar, ⌘' on the Italian layout (MU-04)

| Measure | Value |
| --- | --- |
| Effect | the window **grows by 28 pt** (700 → 728); the content area keeps its size |
| Height | **28** (1 pt separator + 27), under the content area only; translucent |
| Text | centered on the content area; capital/digit height 8 pt (*~11 pt, provisional*) |
| Icon-size slider (icon view only) | an 82 × 16 control 17 pt from the right edge: an **80 × 4** capsule track and an **18 × 14** knob; travel 62 pt (0.554 pt per unit) |

| Color | Light | Dark |
| --- | --- | --- |
| Background | `#ffffff` | `#2f2f2f` |
| Top separator | `#d9d9d9` | `#000000` |
| Text, active / inactive | `#808080`–`#898989` / `#bdbdbd` | `#a1a1a1` / `#636363` |
| Track | `#e5e5e5` | `#434343` |
| Filled part (left) | `#0176f7` | `#0d7bfb` |
| Knob | `#ffffff` with a shadow | `#dfdfdf` solid |

Slider value → icon side (pt):

| Value | 0 | 8 | 24 | 56 | 64 | 72 | 80 | 90 | 100 | 106 | 112 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Side | 16 | 32 | 64 | 128 | 164 | 204 | 244 | 312 | 392 | 448 | 512 |

Up to 56 the side is 16 + 2 × value. From there to 80 it grows 5 pt per unit, then 6.8 to
10.7 pt per unit.

- **R1.21** The status text depends on the selection and the view. Hidden items are not
  counted.

  | Situation | Text (Mustache's labels) |
  | --- | --- |
  | No selection | item count and the free space, for example "12 items, 41.2 GB available" (the free space has 2 decimals, sometimes 1) |
  | With a selection | "3 of 12 selected, 41.2 GB available"; singular "1 of 1 selected" |
  | Tag or search view | only the item count |
- **R1.22** In the column view, the counts are for the active column. In the gallery, the bar
  narrows to end beside the side pane.
