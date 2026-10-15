# Desktop icons (MU-90, MU-12)

The desktop is drawn by Mustache itself: `mustache --desktop` (silica-desktop#147) shows the desktop
folder on a full-screen surface of the bottom layer, above the wallpaper and below the windows.
Ossido keeps it running and makes Mustache the frontmost app when the desktop is clicked; its
context menu is drawn by the menu bar (the desktop is below the windows) and runs here
(`desktopmenu`, `desktop.state`, `desktop.action` on the shell channel). Not yet: Get Info, the
quick preview and the view options on the desktop (they need a window of the same process,
silica-desktop#146), Paste Item (silica-desktop#150), volumes (R15.4, R15.6).

The menu of the selected icons ends, as the window's, with the row of seven colour dots (the
window's measurements: 14 pt at a 24 pt pitch, 25 pt tall, *provisional*) and Customize Folder…
(Tags…, disabled, unless the selection is one folder). The shell draws them and sends back
`desktop.action` = `tag:<colour>` (all the selected items have the tag: it is removed, else added)
or `customize` (starts a file manager window with `--customize=<folder>`: the Customize Folder
popover on that folder). `desktop.state` carries `tags` (the colours all the selected items
have, checked in the row) and `folder` (the selection is one folder).

| Measure | Value |
| --- | --- |
| Measured state | Sort By None, stacks off, **96** pt icons, 12 pt text, labels below |
| First icon | at (2446, 40) on a 2560 pt primary display: its right edge **18 pt** from the screen edge, 40 pt from the top |
| Pitch | vertical **148**, horizontal **124** |
| Labels | **white, bold** (9 pt capital height, *≈ 12 pt provisional*), centered ~10 pt below the icon, with a soft dark shadow (~1 pt down, blur ~2–3 pt; darkest pixel `#535357` over `#7a7b80`); the same in light and dark |
| Selection | a rounded square **108 × 108** (6 pt around the icon), corner radius **~8 pt**, `#55565a` fill (black ~30 %) with a light **2 pt** outline `#888a8c` (white ~10 %); the same in light and dark. Drawn behind the icon: the icon never moves or scales, nor does its name |
| Selected name capsule | **17** tall, **5 pt** side padding, fully round ends (radius 8.5), its top **104 pt** below the icon's top (8 below the icon, ~3 below the square), `#0064e1` / `#0059d1`, white text |
| Inactive selection | a window is key: the square is unchanged, the capsule turns light grey `#d0d0d0` with dark text |
| Rubber band | square corners, white fill **~15 %**, **1 pt** white outline **~57 %**, drawn above the icons; selects live by intersection with the icon or the lines of its name; releasing removes it at once |

![Desktop grid](diagrams/desktop.svg)

| Animation | Delay | Duration |
| --- | --- | --- |
| Use Stacks (⌃⌘0): icons fly into their stacks | +55 ms | **~160 ms** |
| A stack opens in place | +145 ms | **~150 ms** |

- **R15.1** New icons fill the grid **top to bottom** (8 rows on a 1440 pt display), then
  **toward the left**. The icons sit under the windows.
- **R15.2** With stacks on, items group by type (documents, images, …). A type with a single
  item stays a single icon. A closed stack shows **2–3 overlapping, rotated thumbnails** and no
  count.
- **R15.3** Clicking a stack opens it in place:
  - the stack becomes an icon with a ⌄ chevron;
  - its items take the grid cells beside it, moving the others;
  - another click closes it.
- **R15.4** A newly mounted volume takes the **first free grid cell**, after the files already
  there. Volumes get no precedence: with three files in the first column, a never-seen volume
  lands in the fourth cell.
  - A volume seen before returns to its remembered position.
  - Which volumes appear is set in Settings › General.
- **R15.5** Return renames in place, as in the windows (R8.1).
- **R15.6** A volume's desktop icon is a 96 pt external-disk icon. Its label is styled like the
  files' (white, bold, with a shadow).
- **R15.7** A file dragged out of an open stack and dropped on free desktop **stays in the
  stack**.
  - The image returns to its cell in **~250 ms**, decelerating, like a rejected drop.
  - With stacks on, the desktop is always kept in order.
  - Turning stacks off puts the icons back in their previous positions.
- **R15.8** An open stack takes the cells below it and moves the other items.
- Drag threshold: **4–5 pt** (R7.7). The image in flight over the desktop (96 pt icon + pill)
  and dropping onto the desktop: R9.13 in [operations.md](operations.md).

Dragging desktop icons (MU-40, R9.13):

- The image is the dragged icons as they are drawn (icon and name in its capsule) at **~90 %**,
  keeping their arrangement and where the pointer grabbed them; with several items a **20 pt**
  red count badge sits **below and right** of the pointer (+9…+28 pt across, +11…+30 pt down).
  Ossido carries it (`silica/drag` › `start` with the grab point `x`, `y`), over windows, the Dock
  and other apps.
- The icons stay in place, *dimmed to ~50 % (provisional, DESKTOP-SEL)*, until the drag ends.
- Dropped on the desktop with free positions (no grid snapping), there is no snap and no fly:
  each icon appears where its image was; the image and its badge fade out in **~150–200 ms** and
  the selected look (square, capsule) is back **~250–300 ms** after the release. On an ordered desktop (a sort order, stacks) the icons travel back to their
  cells in **~250 ms**, decelerating (R15.7); so does an icon that would land off the screen.
- Not yet: a cancelled drag (Esc, a drop nowhere) loses its image at once; the reference slides
  it back to the origin (~260 ms) and fades it (~190 ms).

Sounds (FILE-SOUNDS, played by silica-daemon's `PlaySound`): three sounds only, each played once
when the operation is **complete**, never at the drop. `trash-move` when icons go to the Trash
(menu, ⌘⌫, script, or a drop on the Dock's Trash, which sounds from the Dock); `file-transfer`
(move, copy, duplicate) when files dropped from elsewhere are moved or copied onto the desktop
(across disks: after the last copy finished) and on Duplicate; `trash-empty` ~0.2 s after the
Trash icon turns empty (Dock). Dragging or repositioning icons on the desktop is silent.
