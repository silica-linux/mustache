# File operations

## Dragging (MU-40)

| Element | Light | Dark |
| --- | --- | --- |
| Dragged image (over a list) | for each item, **icon + name in a pill**, accent `#0064e1` with white text, arranged as in the list; the whole image at **alpha ~0.90** (see open-questions, item 19). Its shape over other views: table below | *`#0059d1` (provisional: the dark accent)* |
| Count badge | a **20 pt** circle ~`#fb3936`, white digit, at the top left of the group | ~`#f53230` |
| Copy badge "+" | an **18 pt** circle `#00c261`, left of the count | `#02c167` |
| Destination: a folder | the whole row in the accent color, as a selection | |
| Destination: the open folder | a **2 pt** `#b3d7ff` line along the content area's edge | — |
| Source rows | gray (as an inactive selection) | |

| Animation | Delay | Duration | Shape |
| --- | --- | --- | --- |
| Spring-loaded folder: blink | **~340 ms** after arriving | off 80, on 107, off | — |
| Spring-loaded folder: opens in the same window | **~715 ms** | — | — |
| Spring-loaded tab | ~1060 ms | — | — |
| Invalid drop: the image flies back | — | **~260 ms** (340 pt) | decelerating |
| then fades in place | — | **~190 ms** | — |
| Esc during the drag: back to the starting folder | — | ~100 ms | — |

- **R9.1** The operation depends on the modifiers and the destination:

  | Modifiers | Operation | Badge or pointer |
  | --- | --- | --- |
  | none, same volume | **move** | no badge |
  | none, another volume | **copy** | "+" alone |
  | ⌥ | copy | "+" next to the count |
  | ⌥⌘ | link | a curved arrow on the pointer |
  | ⌘ | move | — |
- **R9.2** Pressing or releasing a modifier during the spring-loaded wait restarts the count (one
  test opened at 1085 ms with ⌥ pressed halfway).
- **R9.3** A drop on the toolbar, or anywhere invalid, moves no file and the image flies back.

The image in flight (MU-40):

| Measure | Value |
| --- | --- |
| Over a list | a 16 pt icon + the name in a pill (**16 pt** tall) |
| Over an icon window (64) | the 64 pt icon (document body 50 × 62) |
| Over the desktop | a **96 pt** icon (body 67 × 89) with the name in a pill below, as a desktop icon |
| Alpha | **~0.90** for the whole image (pill `#366ae1` over white, `#295dd4` over gray `#7a7b80`; a white page reads 255 over white, 242 over gray) |
| Over the Dock | without the name pill, semi-transparent |

| Animation | Delay | Duration |
| --- | --- | --- |
| Shape change (e.g. 16 → 96 when leaving onto the desktop; the pill slides below and centers, cross-dissolve) | **~210–260 ms after the pointer stops** (while it moves, the old shape stays) | **~200–300 ms** |
| Drop on the desktop: the image goes, the icon appears in place (where the image's icon was) | next frame (~19 ms) | none |
| Top screen edge → Panorama | **~90 ms** after the image touches the menu bar | — |
| Dock app: blinks dark twice (dark ~100, normal ~80, dark ~90), then the app's windows view | **~830 ms** of hovering | — |
| Dock: gap for a new folder (the Dock widens by one cell: right edge +31, half of 63, and stays centered) | — | **~240 ms** |
| Dock: the added item grows from a point (label above) | after a short empty gap | — |
| Dock: dragged back out, the gap closes | — | ~300 ms |
| Dock: the Remove label above the icon | after ~500 ms outside the Dock | — |
| Dock: dropped outside, the icon fades in place (no puff) | — | **~250 ms**, fade |

- **R9.13** A file dropped on the desktop moves to the Desktop folder. Its icon appears where
  the image was, selected with an inactive selection, because the file manager keeps the key
  window.
- **R9.14** During a drag, reaching the top edge of the screen opens **Panorama**, and the item
  can be dropped on a space. Dropped on nothing, no file moves.
- **R9.15** Hovering a file over a Dock app does **not** highlight it at once.
  - After ~830 ms the app blinks dark twice and its windows view opens. If it has no windows,
    the view says so.
  - The app's label appears above it, as on a normal hover.
  - Dropping on the app was not tried.
- **R9.16** A file dropped on the Dock's Trash goes to the Trash, and the icon turns "full" on
  release. A volume ejects instead (R2.18).
- **R9.17** The Dock's right zone holds folders as stacks:
  - A folder dropped there becomes a stack, showing the folder's first document.
  - A file dropped on a stack goes into that folder (moved, on the same volume).
  - The stack's icon updates with the new item in front, with no bounce.
- **R9.18** A stack dragged out of the Dock and released after Remove appears leaves the Dock;
  the folder is untouched. Pressing and holding on the stack opens it instead, as a fan with an
  item that opens the folder in Mustache.

## Copies, progress, conflicts (MU-41, MU-43)

| Measure | Value |
| --- | --- |
| Progress in the destination | the item appears at once with a **dimmed** name and a **~14 pt pie** right of the Name column (a 1 pt gray outline that fills clockwise); the final size is already written |
| Progress window | **404 × 88**: a 34 pt icon, "Copying “X” to “Y”", a **309 × 20** accent bar, a 15 × 10 × right of the bar, and a line "done of total – time left" |
| Conflict | a **separate window** (not a sheet), **404 × 106**: a document icon with a warning triangle, the text, and three small **22 pt** buttons on the right: Keep Both 117, Stop 88, Replace 88 |

| Animation | Delay | Duration |
| --- | --- | --- |
| Copy done: normal text, the pie goes | — | one frame |
| × in the progress window: the window closes | +162 ms | to ~+297 (~135 ms) |
| ×: the row disappears from the destination | +189 ms | one frame |
| ⌘. with the progress window in front | — | within ~80 ms |

- **R9.4** A copy that lasts more than a few seconds opens the progress window **by itself**.
  Otherwise the window opens only from Window › Show Progress. *The threshold is ~2–3 s
  (provisional: a 3.6 s copy opened no window, a 20 GB copy opened one "after a few seconds").*
- **R9.5** Clicking the pie does **nothing**: it neither cancels nor shows a ×.
- **R9.6** A cancelled copy (× or ⌘.) leaves **nothing** in the destination.
- **R9.7** Keep Both names the new copy "name 2.ext" (a space and a number before the
  extension). Replace replaces.
- **R9.8** ⌘C / ⌘V copies. **⌥⌘V** moves, across volumes too, and keeps the modification
  date.

## New, duplicate, compress, link (MU-42)

| Operation | Result | Afterwards |
| --- | --- | --- |
| ⇧⌘N | a new folder with the default name, in its sorted place, **straight into rename** (whole name selected) | ⌘Z deletes it (not to the Trash) |
| ⌃⌘N with N > 1 items | "New Folder with Items" holding the selection, in rename; with 1 item the command names it | ⌘Z puts everything back |
| ⌘D | "name copy.ext", then "name copy 2.ext"; folders "Folder copy" | the selection moves to the duplicates; ⌘Z deletes them |
| Compress 1 item | "name.ext.zip", then "name 2.ext.zip" | |
| Compress N items | "Archive.zip", then "Archive 2.zip" | |
| ⌃⌘A (make link) | the item's name plus a link suffix, then numbered | the new link enters rename |

## Trash and deleting (MU-42, MU-12, MU-51)

| Animation | Duration | Shape |
| --- | --- | --- |
| ⌘⌫: the row disappears, the rows below rise by 20 pt | **~210 ms** | soft end |

- **R9.9** ⌘⌫ shows **no flight** toward the Dock. The selection moves to the next item, and ⌘Z
  puts the item back.
- **R9.10** Inside the Trash, ⌘⌫ means Restore: back to the original folder.
- **R9.11** ⌥⌘⌫ opens an alert, **292 × 250**, horizontally centered on the screen.
  - It has a 66 pt icon and a bold title.
  - Cancel and Delete sit **side by side**, 128 × 30, 6 pt apart. Delete is destructive.

| Button | Light | Dark |
| --- | --- | --- |
| Delete background | `#fcccca` | `#734545` |
| Delete text | `#ff383c` | `#f01d14` |
| Cancel background | `#e8e8e8` | `#525253` |

Trash window (list view):

| Measure | Light | Dark |
| --- | --- | --- |
| A "Trash" band under the toolbar | **38 pt** (y 52–90), content background, gray label 19 pt from the content's left edge | same |
| Empty button | **59 × 22**, 16 pt from the right edge; enabled when the Trash has items | same |
| Empty button, disabled (empty Trash) | gray text, background `#f0f0f0` | background `#404040` |
| Empty Trash | only the alternating rows, no text (as R3.10) | same |

Empty Trash alert:

| Measure | Light | Dark |
| --- | --- | --- |
| Alert | **292 × 268**, horizontally centered **on the screen**, a 66 pt full-Trash icon, a bold question title (250 × 50) and a one-line warning that it cannot be undone | same |
| Buttons | **stacked, full width**, 262 × 30, 4 pt apart; the primary on top | same |
| Empty Trash (primary, not red) | `#007aff`, white text | `#007aff` |
| Cancel | `#e8e8e8` | `#494949` |

| Animation | Delay | Duration |
| --- | --- | --- |
| Confirm: the alert goes, the Dock icon empties, the Trash list empties | same frame | — |
| A window showing the Trash **closes** | +894 ms | fade **~100 ms** |
| Sound | **~0.35 s** after the visible emptying (~0.2 s of it is capture latency) | **~280 ms**, peak **−19 dBFS** at system volume 88 |

- **R9.12** Emptying the Trash:
  - ⇧⌘⌫ asks with the alert above. It is not the destructive red of R9.11.
  - ⌥⇧⌘⌫ empties without asking.
  - On confirmation the Trash empties in one frame, a window showing it closes, and a short
    sound plays. Silica plays a sound of its own with a similar length and level.
