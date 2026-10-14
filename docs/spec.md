# Mustache · specification

What Mustache does and how it behaves. Where a behavior or a value waits for a measurement of
the reference there is the request code (`MU-xx`); until it arrives, the value in code is
provisional and says so.

## Principles

- **One file manager for the whole system.** Mustache is also the browser of the Open and Save
  dialogs of the other apps (through `xdg-desktop-portal`, `silica/crates/portal`) and answers
  `org.freedesktop.FileManager1` (apps ask "show this file in its folder").
- **freedesktop standards**, not formats of our own: user folders (xdg-user-dirs), Trash (Trash
  spec), file types (shared-mime-info), default apps (`mimeapps.list`), thumbnails (Thumbnail
  Managing Standard), tags in extended attributes (`user.xdg.tags`).
- **Everything is a command.** Every action has a `mustache.*` id, a label and a shortcut;
  menus, toolbar, keyboard and (from the Silica app command channel) CLI and MCP call the same
  commands.
- **Never lose a file.** Destructive operations go to the Trash; every file operation can be
  undone with ⌘Z while possible; an interrupted copy leaves the destination clean.

The interface texts are in Italian for now (quoted below as they appear); they move to the
localization files with English as the source language.

## Window

- Sidebar on the left from top to bottom, content on the right, toolbar unified with the window
  (52 pt, `silica-window-v1`: Ossido draws only the window buttons above the sidebar): Back/
  Forward capsule, title, view group (⌘1–⌘4), Search. Dragging the empty space of the toolbar or
  the top of the sidebar moves the window (MU-02, MU-08). To do: Group, Share, Tags, Action, the
  » menu and the veil under the bar (MU-99). Optional: path bar, status bar, preview pane (MU-03,
  MU-04, MU-05).
- Tabs: ⌘T opens a tab in the current folder; the tab bar appears with the second tab (MU-01).
- New window: ⌘N, in the Home folder (setting); cascading position (MU-01).

## Sidebar

- Sections: **Favorites** (the user folders, then those added by dragging), **Locations** (Home
  folder, disks, mounted volumes, network, Trash), **Tags**.
- Attached to the window edges, from top to bottom, without a line towards the content. Rows at
  a 32 pt pitch (first row centered at 68), text at 47 pt, symbol icons from `silica-icons` in
  the accent color (gray for the Home folder and the Trash); headings 24 pt from the first row
  and 40 from the last row of the previous section (MU-10).
- Selection: a radius 8 rectangle as tall as the row, 10 pt from the edge, text in semibold; no
  background on hover. Colors per theme and per active/inactive window (MU-10, MU-98).
- Headings: chevron on hover, click to collapse and expand (~190 ms, MU-11).
- Width: dragging the edge, between 135 pt and as much as leaves 316 pt to the content; near 200
  it snaps to 200 (new windows start at 192); against the left edge the sidebar hides. New
  windows take the last width (`$XDG_CONFIG_HOME/mustache/settings.json`).
- Hide/show: `mustache.sidebar.toggle`, ⌃⌘S (~240 ms, S curve).
- To do: dragging to add, reorder and remove (MU-11), volumes and eject (MU-12), tags (MU-62).

## Views

| View | Command | Shortcut | Status |
| --- | --- | --- | --- |
| Icons | `mustache.view.icons` | ⌘1 | a grid that fills the width, labels on two lines truncated in the middle, selection with background and capsule, image thumbnails; the default view and the last chosen one stay in the settings (MU-21, MU-80) |
| List | `mustache.view.list` | ⌘2 | measured geometry and colors: 28 pt header with separators and arrow, 20 pt rows, columns Name 364, Date 181, Size 97, Kind 121 (widened by dragging the separator), alternating rows down to the bottom, block selection, right-click ring; folders expanded in place with the triangle (⌥ the whole subtree, → and ←), 15 pt indent; Date and Size sort from the largest; names and kinds truncated in the middle; pressed header, row and triangle act on release (MU-20, MU-25). To do: expand animation, reordering columns by dragging the header, scroll bar |
| Columns | `mustache.view.columns` | ⌘3 | one column per folder from the sidebar entry, dimmed selection on the left, → and ←, horizontal scrolling (MU-22) |
| Gallery | `mustache.view.gallery` | ⌘4 | large preview (icons at 0.94 of the box), thumbnail strip, always a chosen item, pane with 50 pt icon, name and kind, Information, tags field and actions (Edit, More) (MU-23). To do: Rotate, Show More, folder sizes |

- Natural sort (`file 2` before `file 10`), case insensitive; ties by name.
- Dates: "oggi, 10:22", "ieri, 18:05", then day, abbreviated month, year and time (R3.1).
- Sizes in decimal units: "N byte", KB and MB as integers, GB with two decimals ("2,15 GB"),
  "Zero byte", "--" for folders (R3.2). For a link, its own date and size.
- Kind: a short name per family, in our own words: folder, link, text, Markdown, JSON, PDF,
  image and audio with the format, archive with the extension, video, document (R3.3).
- Folders with tens of thousands of items: the content appears right away and completes while
  it is read (MU-24).

## Selection and keyboard

| Action | Command | Shortcut |
| --- | --- | --- |
| Open | `mustache.open` | ⌘↓, double click |
| Enclosing folder | `mustache.go.parent` | ⌘↑ |
| Back / Forward | `mustache.go.back` / `mustache.go.forward` | ⌘[ / ⌘] (long press on the buttons: history menu) |
| Show or hide hidden files | `mustache.view.hidden` | ⌘⇧. |
| Select all | `mustache.select.all` | ⌘A |
| Rename | `mustache.rename` | Return |
| Go to folder | `mustache.go.to` | ⌘⇧G |
| Get Info | `mustache.info` | ⌘I |
| Quick Look | `mustache.quicklook` | Space |
| New folder | `mustache.new.folder` | ⌘⇧N |
| Duplicate | `mustache.duplicate` | ⌘D |
| Move to Trash (inside the Trash: Put Back) | `mustache.trash` | ⌘⌫ |
| Delete immediately, with confirmation | `mustache.delete` | ⌥⌘⌫ |
| Undo / Redo | `mustache.undo` / `mustache.redo` | ⌘Z / ⌘⇧Z |
| Search | `mustache.search` | ⌘F |
| New window / tab | `mustache.window.new` / `mustache.tab.new` | ⌘N / ⌘T |

The complete table comes from the menu inventory (MU-51). Selection: click, ⌘-click, ⇧-click,
rubber band from the background, arrows and ⇧-arrows, typing to jump to a name (MU-30, MU-31).
Done today: click, ⌘-click, ⇧-click, arrows, rubber band.

## File operations

- Copying, moving, linking by dragging (modifiers as in MU-40), with folders that open while
  hovering during the drag; dragging to and from other apps and the Dock (`SilicaDrag`).
- Long copies in the background with visible, cancellable progress; conflicts with a question
  (keep both, replace, skip) (MU-41).
- New folder, duplicate, compressed archive, link, Trash and putting back from the Trash
  according to the Trash spec (MU-42).
- In-place rename, with the name selected without the extension; renaming several files (MU-32).

## More

- **Get Info** (⌘I) and an inspector that follows the selection (MU-60).
- **Quick Look** (Space): images, PDFs, texts, audio and video, folders (MU-61).
- **Tags** with color and name, in extended attributes; rows in the sidebar (MU-62).
- **Search** in the folder and in the whole user disk, with criteria (MU-70).
- **Thumbnails** of images, PDFs and videos in place of the icons (MU-80).
- **Desktop**: the icon rules are applied by the shell component (MU-90).
- **Open and Save dialogs** for the other apps, with the same browser (MU-95).

## Open

- The app menu in the menu bar: it comes with `silica-menu-v1` (Silica M7).
- App commands reachable from CLI and MCP: the app command channel is needed (to be designed in
  Silica).
