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
