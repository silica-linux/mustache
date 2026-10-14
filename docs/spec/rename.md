# Renaming (MU-32, MU-60)

| Measure | Light | Dark |
| --- | --- | --- |
| Field | a separate overlay as wide as the text; it grows and shrinks as you type (63 pt for an 11-character name, 96 for a long one). **21** tall including the ring; 13 pt text, 4 pt from the edge | |
| 3 pt focus ring | `#8fb4fb` / `#8cb2fb` | `#296692` |
| 1 pt inner border | `#649efa` | `#3586c5` |
| Background | `#ffffff` | *`#272728` (provisional: the dark content background)* |
| Selected text | `#b3d7ff` | `#40638b` |

| Trigger | Delay |
| --- | --- |
| Slow click on the name (item already selected, or a second click ≥ 0.7 s after the first) → field | **~440 ms** (438, 440, 439) |

- **R8.1** Return on a file with an extension selects **only the name, without the extension**.
  On a folder or a file without one, the whole name is selected. The same applies on the
  desktop (MU-90).
- **R8.2** A `/` in the name is accepted; on disk it is stored as `:`. A `:` is refused with an
  alert that has a full-width OK, and the field closes with the old name.
- **R8.3** A name that already exists is refused with an alert and OK.
- **R8.4** Changing the extension asks first. The alert has two side-by-side buttons, 128 × 30
  and 6 pt apart: Use .new and Keep .old.
- **R8.5** These alerts have a common layout:
  - They are **292** wide and 192–250 tall depending on the text.
  - They are **not centered** on the window: they open to the right, near the item.
  - They have a 66 pt icon at the top left, a bold title and a 250 pt text column, and buttons
    30 pt tall.
- **R8.6** Rename… with several items selected opens a sheet attached to the window, with
  three modes: Replace Text, Add Text and Format.

  | Mode | Size | Content |
  | --- | --- | --- |
  | Replace Text | 489 × 132 | Find, Replace With, an example, and Cancel / Rename (82 × 26) |
  | Format | 542 × 161 | name format, position, custom text, numbering and an example |
- **R8.7** After a rename, Edit shows "Undo Rename ⌘Z".
  - ⌘Z restores the old name **in one frame, +12 ms after the key**, with no animation.
  - The item **stays selected**.
  - Edit then offers "Redo Rename ⇧⌘Z".
- **R8.8** Changing the name in the Info window's field and pressing Return renames at once.
- **R8.9** Suggested file names, when the setting is on, appear **only** for a new name (New
  Folder with Selection), never when renaming an existing item.
  - The suggestions box appears **in one frame, ~2.1 s** after the field (the field at +1297 ms,
    the box at +3443 ms from the command).
  - Esc closes both the field and the box.
  - ⌘Z undoes the whole New Folder with Selection.

Suggestions box:

| Measure | Value |
| --- | --- |
| Size / position | **175 × 83 pt**, just under the field (field x + 11, 3 pt below) |
| Header | a gray "Suggestions" label with a report button on the right, 25 pt row |
| Rows | one suggestion each, **24 pt**, 13 pt text |
| Background | translucent light with a **colored glow** behind the rows (orange on the left, light blue on the right); dark: dark gray with the same glow |
