# Customize Folder (FOLDER-CUSTOM, #91)

Measured on the reference system (private notes in `silica-reference`, `folder-custom.md`); numbers
only here, in our own words. A folder's colour, symbol and emoji are edited in a **popover**
anchored to the folder's icon, not in Get Info.

## Where it lives

- The folder context menu has **Customize Folder…** where files have Tags…. It opens a popover
  with an arrow on its left side pointing at the folder's icon (silica_ui `PopoverPanel`; the
  popover goes to the right of the icon and flips or slides to stay inside the window). Started
  with `--customize=<folder>` (the Desktop's menu), the window opens in the parent folder and the
  popover points at the folder when its icon is shown.
- Everything is **live**: each choice is saved on the folder at once and every icon redraws. There
  is no OK. **Esc**, or a click outside, closes the popover and **keeps** the changes. Esc first
  closes the emoji picker when it is open.
- *Provisional:* the open and close animation (silica_ui's 120 ms fade).

## Storage

- The folder **colour is its tag colour**. Picking a colour assigns that tag (`user.xdg.tags`,
  Red … Gray in the user's language, appended in the order assigned) and the folder icon is tinted.
  With several colour tags the **last assigned** wins (`folder_style.dart`: last colour tag, else
  an older custom tint, else none).
- A symbol or an emoji lives in `user.silica.folder` (JSON): `{"symbol":"music-note"}` or
  `{"emoji":"🎵"}`. Each replaces the other. An emoji is at most 12 code points, without spaces or
  control characters. An older `{"tint":…}` is still read and is removed by "remove all tags".
- On a disk without user attributes the JSON goes to the GIO metadata store
  (`metadata::silica-folder`). Changes made elsewhere redraw the icons on screen and the open
  popover (attribute changes are watched, debounced ~120 ms).

## Layout (body 320 × 670, radius 18)

| Element | Value |
| --- | --- |
| Preview | the folder icon at 96 pt, centred, canvas top at y 16 |
| Name | 13 pt semibold, centred, y 116, 16 tall; `#ececeb` dark |
| Colour row | centre y 157: "remove all tags" button 20 pt at x 12; 26 pt discs at a **34 pt pitch** from x 42; a 28 pt "+" after the last disc |
| Caption | 11 pt secondary grey, centred, y 178: the hovered disc's tag name, or "Remove all tags" |
| Separators | 1 px at y 202 and y 629 (`#6f6b69` dark, `#e6e4e3` light) |
| Symbol grid | y 203–629 (426 tall), scrolls; headings bold 13 pt, 16 tall at x 10; cells **44 × 44**, **6 per row** from x 20; glyphs ~18 pt in muted grey (`#c1bcb9` dark); **no search, no hover**; selected: a **2 pt accent ring** (`#0479fc`) and an accent glyph |
| Buttons | two **147 × 24** at y 638, x 8 and 165: **Clear** (disabled when there is no symbol or emoji) and **Emoji** (a smiley and the label; the chosen emoji replaces the smiley) |

In a window shorter than 686 pt the body shrinks and the symbol grid with it.

### Disc colours (the vivid system colours, not the dots' of lists and menus)

| Colour | Dark | Light |
| --- | --- | --- |
| Red | `#ff4747` | `#ff383c` |
| Orange | `#ff9e32` | `#ff8d28` |
| Yellow | `#ffe014` | `#f5c202` |
| Green | `#3bdb63` | `#27bf4d` |
| Blue | `#0c99ff` | `#0178f0` |
| Purple | `#e647fc` | `#b72bc8` |
| Grey | `#8e8e93` | `#8e8e93` |

## Behaviour

- **Hover** on a disc: a white **+** on it and the tag name in the caption.
- **Assigned** disc: a white **✓**; on hover a **×** (click removes the tag). It moves to a
  **group** at the start of the row: discs offset **10 pt**, **newest in front, on the left**,
  followed by a **2 pt divider** (6 pt before, 8 pt after, 54 pt tall). The other discs slide to
  their new places in **~280 ms** (ease-out); the row stays left-aligned.
- The folder and the preview change colour at once, with **no fade**.
- **Remove all tags**: removes every tag of the folder (and an older custom tint). The folder goes
  back to blue and the row slides back in **~470 ms**, with a small overshoot. Disabled (dim)
  without tags.
- **+** opens a menu: the folder's tags that have no colour (a ring glyph and the name, click
  removes), a separator and **Edit Tags…** (closes the popover, selects the folder and shows the
  preview pane, where tags are typed). Mustache keeps no list of other tags yet.
- **Symbol**: embossed on the folder front by silica_ui (a darker shade of the folder colour,
  about a third of the icon: 32 pt on the 96 pt preview). Choosing an emoji clears it.
- **Emoji** opens a second popover below (flipping above when it does not fit): body 320 × 444, a
  300 × 28 search field, a scrolling grid starting with the frequently used emoji (6 columns, 48 ×
  44 cells, 32 pt emoji) and a category bar at the bottom. Picking one closes the picker and draws
  it **in full colour** on the folder, about a third of the icon (30 pt on the preview), replacing
  any symbol. It is drawn on the folder icons of the views and on the preview; the sidebar, the path bar and the
  Desktop do not draw emoji yet (they get the tint and the symbol).
- **Clear** removes only the symbol or emoji; the tags stay.
- A write that fails (no permission, read-only disk) shows "This folder can't be customized." in
  the caption slot, in red.

## Symbol categories

Seven, in this order: People, Animals & Nature, Food & Drink, Activities, Travel & Places,
Objects, Symbols (the reference has 527 symbols; silica-icons has fewer, so a category with none
is left out). The assignment of each silica-icons symbol is ours (`_categorySymbols` in
`folder_customize.dart`); a symbol not listed goes to Symbols.

## Not measured (kept *provisional*)

- The popover's open and close animation.
- The light mode of the emoji picker (it follows the popover's colours) and of the symbol ring.
- The emoji picker's contents: Silica has no system emoji picker, so the set (`emoji_data.dart`,
  with search keywords and a frequently used list kept for the session) is a small stand-in.
- Custom colour tags from "Edit tags…" (the user's tag list is not edited here).

## Tag dots

Unchanged except for one measure: with two tags the dot behind sits **6 pt** to the right of the
front one in the icon view (5 pt in the list and the columns). The last assigned tag is in front,
on the left.
