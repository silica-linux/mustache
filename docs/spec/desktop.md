# Desktop icons (MU-90, MU-12)

The desktop is drawn by Mustache itself: `mustache --desktop` (silica-desktop#147) shows the desktop
folder on a full-screen surface of the bottom layer, above the wallpaper and below the windows.
Ossido keeps it running and makes Mustache the frontmost app when the desktop is clicked; its
context menu is drawn by the menu bar (the desktop is below the windows) and runs here
(`desktopmenu`, `desktop.state`, `desktop.action` on the shell channel). Not yet: Get Info, the
quick preview and the view options on the desktop (they need a window of the same process,
silica-desktop#146), Paste Item (silica-desktop#150), volumes (R15.4, R15.6).

| Measure | Value |
| --- | --- |
| Measured state | Sort By None, stacks off, **96** pt icons, 12 pt text, labels below |
| First icon | at (2446, 40) on a 2560 pt primary display: its right edge **18 pt** from the screen edge, 40 pt from the top |
| Pitch | vertical **148**, horizontal **124** |
| Labels | **white, bold** (9 pt capital height, *≈ 12 pt provisional*), centered ~10 pt below the icon, with a soft dark shadow (~1 pt down, blur ~2–3 pt; darkest pixel `#535357` over `#7a7b80`); the same in light and dark |
| Selection | a rounded square **108 × 107** (6 pt around; 108 × 108 in the close-up capture) `#545559` (black ~30 %) with a light **2 pt** outline `#88898c` (white ~10 %, outside the fill); the same in light and dark. Drawn behind the icon: it never moves the icon or its name |
| Selected name capsule | **17** tall, its top **104 pt** below the icon's top (8 below the icon), `#0064e1` / `#0059d1`, white text |
| Selection radius | *~10 pt outside (provisional: read from one close-up capture; DESKTOP-SEL)* |
| Capsule side padding, radius | *~5 pt, ~5 pt (provisional: read from one close-up capture; DESKTOP-SEL)* |
| Rubber band | *white ~10 % fill, white ~50 % 1 pt outline (provisional: not measured on the desktop; DESKTOP-SEL)*; selects by intersection with the icon or the lines of its name |

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
  red count badge sits by the pointer (*placed as in the windows, provisional on the desktop*).
  Ossido carries it (`silica/drag` › `start` with the grab point `x`, `y`), over windows, the Dock
  and other apps.
- The icons stay in place, *dimmed to ~50 % (provisional, DESKTOP-SEL)*, until the drag ends.
- Dropped on the desktop with free positions, each icon appears where its image was, in the next
  frame, selected. On an ordered desktop (a sort order, stacks) the icons travel back to their
  cells in **~250 ms**, decelerating (R15.7); so does an icon that would land off the screen.
- Not yet: a cancelled drag (Esc, a drop nowhere) loses its image at once; the reference slides
  it back to the origin (~260 ms) and fades it (~190 ms).

Sounds (FILE-SOUNDS, played by silica-daemon's `PlaySound`): `trash-move` when icons go to the
Trash from the menu or ⌘⌫, `file-transfer` when files dropped from elsewhere are moved or copied
onto the desktop. A drop on the Dock's Trash sounds from the Dock (`trash-drag`).
