# Info window (MU-60)

| Measure | Value |
| --- | --- |
| Width | **265**; as tall as its content (913 for a text file with Preview open, 829 with everything open and Preview closed, 730 for a folder, 724 for a disk) |
| Position | (10, 40); each further Info window **+285 pt** to the right |
| Title | "“name” Info", with a proxy icon |
| Header | a 44 pt icon, the name in semibold and the size, "Modified: …"; a 257 × 33 tags field |
| Sections | a disclosure chevron (15 × 15 target at x 16), 20 pt pitch when closed, 1 pt lines between sections |
| Labels / values | labels right-aligned (x 23–91), values from x 93; *~11 pt (provisional)* |
| Permissions | a Name / Privilege table with 16 pt rows; + / − / actions, a lock on the right |

| Color | Light | Dark |
| --- | --- | --- |
| Background | `#ffffff` | `#272728` |
| Separators | `#e6e6e6` | `#3c3c3d` |

Sections, in order (Mustache's labels):

1. **General**: Type; Size, as "N bytes (X on disk)"; Where, on several lines; Created;
   Modified; and the Stationery pad and Locked checkboxes.
2. **More Info**: metadata. It shows a spinner while loading and "--" when there is nothing.
3. **Name and Extension**: a field and a Hide extension checkbox.
4. **Comments**.
5. **Open With**: not shown for folders.
6. **Preview**: open by default.
7. **Sharing and Permissions**.

For a disk, General lists the volume type, version, format, capacity, available and used space.

| Animation | Delay | Duration | Shape |
| --- | --- | --- | --- |
| Opening or closing a section: the sections below slide, the window changes height | **~180 ms** after the release | **~130 ms** (closing ~120) | 0.05 / 0.22 / 0.51 / 0.78 / 0.95 / 1 in 13–27 ms steps (S-shaped) |
| The inspector following the selection | the same frame as the selection, or the next (+67…+102 ms after the key) | no fade | — |

- **R11.1** Opening or closing a section applies **to every** Info window opened afterwards.
- **R11.2** A file renamed from outside updates the title within 2 s. The comment is saved when
  the field loses focus.
- **R11.3** ⌥⌘I opens the inspector, a **floating** window 265 × 821 at (10, 40) that follows
  the selection. With several items it shows:
  - a multiple-items title;
  - "N items" and a breakdown, for example "2 documents, 1 folder";
  - the sizes added up;
  - the dates as a range.
- **R11.4** Changing a privilege from its menu (Read and write / Read only / No access) on a
  user's file applies **at once, on disk**, without unlocking the lock.

## Customize Folder (provisional)

Folders have a colour and a symbol drawn on their icon, as the reference system does. Nothing of
this section is measured yet: every value below is *provisional* and changes when the
measurement lands.

Storage, on the folder itself so every app and the shell see it:

- a tag named like a colour in `user.xdg.tags` (Red, Orange, Yellow, Green, Blue, Purple, Gray,
  or the same names in another language Mustache knows) tints the folder;
- a custom tint and/or symbol in `user.silica.folder`, JSON: `{"tint":"#e8336d","symbol":"music-note"}`.
  The tint is `#rrggbb` or a colour name (`red` … `gray`); the symbol a silica-icons symbol name;
- on a disk without user attributes, the same JSON in the GIO metadata store
  (`metadata::silica-folder`).

The tint is the custom one, else the first colour tag's, else none. A custom symbol replaces a
special folder's own; one silica-icons does not have is ignored. Changes made elsewhere redraw
the icons of the folders on screen at once (attribute changes are watched, debounced ~120 ms).

Opened from the folder's context menu (Customize Folder…, after the colour circles, in place of
Tags…) or as a section of Get Info, after General:

| Element | Value |
| --- | --- |
| Section | *after General, folders only, closed by default (provisional)* |
| Colour row | *None, the seven colours, Custom; 16 pt swatches at a 22 pt pitch; the chosen one with a 2 pt ring in the text colour (provisional)* |
| Swatch colours | the tint colours of the silica-icons generic folder (`labels`) |
| Custom colour | *a 22 pt field taking `#rrggbb`, applied on Return (provisional)* |
| Symbol grid | *a search field (22 pt), then 28 pt cells, 8 per row, 4 rows visible and scrolling; 18 pt glyphs in the text colour; the chosen cell with a 6 pt-radius fill of the link colour at 20%; "no symbol" first (provisional)* |
| Reset | *a text button in the link colour, bottom right: removes the custom tint and symbol, not the tags (provisional)* |
| Error | *"This folder can't be customized." in red, bottom left, when saving fails (provisional)* |
