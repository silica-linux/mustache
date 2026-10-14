# Open and Save dialogs (MU-95, MU-96)

Mustache is the browser inside the Open and Save dialogs of the other apps (through the Silica
portal).

## Save

| Measure | Value |
| --- | --- |
| Shape | a rounded card (radius ~18–20) **centered on the window**, horizontally and vertically; the window behind is veiled |
| Compact | **413 × 218**. Labels right-aligned (x +39…+136), controls from x +142: name 232 × 26 (selected), tags 232 × 27, format 232 × 26, where 200 × 26 plus a 26 × 26 expansion button ⌄; Cancel / Save 81 × 26 (Save in the accent color) |
| Expanded | **866 × 347** (it may overflow the window), centered. Sidebar **186**. A toolbar row: Back/Forward segments 24 × 24, view 69 × 26, Group 68 × 26, locations 232 × 26, a ∧ chevron, Search 199 × 27. A file area 100 tall at the initial size; New Folder 113 × 26 |
| Resizable | yes (e.g. to 1004 × 634); it stays centered |
| New folder | a **320 × 158** card: a 282 × 26 field with the default name, Cancel 71 × 26 / Create 55 × 26 |
| View menu | Show Sidebar; Icons / List / Columns (no gallery); Hide Extension |

| Color | Light | Dark |
| --- | --- | --- |
| Card background | `#ffffff` | `#272727` (top line `#3d3d3d`) |
| Outer border | `#a6a6a6` | `#010101` |
| Veil over the window | white → `#bababa` | `#262726` → `#1c1c1c` |

The veil was measured at `#cccccc` / `#1a1a1a` on a still image and at `#bababa` / `#1c1c1c` at
the end of the animation on video. Go to Folder uses `#cccccc`. The table uses the steady-state
video value. *The veil is about black at 27 % in light (provisional: 255 → 186).*

| Animation | Delay | Duration |
| --- | --- | --- |
| Compact: the veil | +145 ms | to ~+440 |
| The card fades in **moving down ~20 pt**, constant width (no scaling) | +212 ms | still at ~+480; *soft end (provisional)* |
| Closing (Cancel): fade, no movement | +46 ms after the release | gone at ~+270, veil at ~+310 |
| Compact → expanded: widens left and down, the sidebar enters from the left | ~190 ms after the click | settled ~420 ms |
| Compact → expanded, dark | **+213 ms** after the click on ⌄ | still at **+453–466** (~250 ms) |
| Expanded → compact, dark (∧) | **+105 ms** | still at **+358** (~250 ms) |

- **R14.1** A panel resized by the user reopens at that width. Compact or expanded is remembered
  too.
- **R14.2** Files that cannot be chosen are listed in **gray**.
- **R14.3** Searching in the Save panel shows a scope bar (a 224 × 32 group with This Computer
  and the folder) with a + button.
  - The results are **folders only**.
  - The locations menu becomes "Searching “This Computer”".
  - New Folder and Save are disabled.
- **R14.4** ⇧⌘G opens Go to Folder ([menus-and-settings.md](menus-and-settings.md)); Return
  takes the dialog to that folder.

## Open

- **R14.5** Open is a **separate window**, not a card: **880 × 448**, with no visible title.
  - It has a 186 pt sidebar, a toolbar row and a column view at a 245 pitch.
  - New Document and Show Options sit at the bottom left.
  - Cancel / Open sit on the right; Open is disabled while nothing is selected.
- **R14.6** What the Open dialog keeps and drops from the file manager:
  - It keeps the sidebar, the icon, list and column views, selection and arrows, the locations
    menu, ⇧⌘G and Group.
  - It drops the gallery, tabs, the path and status bars, and the full context menus.
