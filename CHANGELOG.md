# Changelog

## Unreleased

- **Added (mustache#23):** the Open With submenu shows the 16 pt icon of each of Silica's own apps
  (`X-Silica-Icon` of its desktop entry, drawn by `AmalfiAppIcon`; other apps keep an empty slot so
  the labels line up), 192 wide, in Actions and the context menu; the File menu passes the icon id
  to the menu bar. Needs silica_ui with `AmalfiAppIcon` and `AmalfiMenuAction.submenuWidth`.

Amalfi (silica_ui 1.0.0 "Amalfi", milestone M6): the whole window is rebuilt on the Amalfi design
system from the kit page `App · Mustache` (silica_ui v1.0.0-alpha.5). Look and measures are the
kit's (sidebar 240, flat 52 pt toolbar split in sidebar, content and preview sections, 104 pt icon
tiles, 28 pt list and column rows, tab bar, path and status bars, scope bar, gallery, preview pane,
Get Info 264 wide, quick preview 576 × 328, alerts, menus, the progress and conflict windows, the
tag palette); behaviour and the measured animations are unchanged. The search field is always in
the toolbar (it starts the search when it takes the focus) and, with the preview pane open (always
in the columns and gallery views), moves over the pane. Column headings read "Date Modified" and
"Kind". Tests compare the window's parts with the frames of the kit's masters (`test/kit`). The
kit's Share button and More Info section, the scope bar's Save button and the quick preview's
minimise and zoom controls are not drawn: the app cannot do them yet.

Menus in Silica's menu bar (silica-desktop#175): the app menu, File, Edit, View, Go, Window and
Help, published with silica_ui 0.34's `SilicaMenuBar` as measured (docs/spec/menus-and-settings.md):
shortcuts, separators, checkmarks (view, sort, bars), labels that follow the selection and
enabled states by selection, tabs, dialog and desktop (the desktop process publishes its own menus,
with Use Stacks and Sort By). Items that run are wired to the existing actions; those whose feature
does not exist yet are shown disabled. New: Select All (⌘A) and Open (⌘O) for several items.

Get Info is a real window (#12): ⌘I, File › Get Info and the context menus open one child
window of the Mustache window per item (at most five), which can be dragged anywhere, stays above
its browser window and open while it is used, and is as tall as its content (265 pt wide). Ossido
draws its title bar and close button; the sections, Name and Comments work as before and a
section opened in one Info opens in all. Where Silica cannot open windows (the desktop, an older
Silica) the panels are drawn inside the window as before. Needs silica_ui 0.34.0 and the
embedder's `--multi-window`, now in the `.desktop` entry (silica-desktop#146).

Desktop: the context menu of the selected icons has the colour dots and Customize Folder… of the
window's menu. The desktop applies the tag (`desktop.action` `tag:<colour>`), reports the colours
the selection shares in `desktop.state`, and starts a window with the Customize
Folder popover on the folder (`--customize=<folder>`).

Customize Folder (FOLDER-CUSTOM, #91), reworked 1:1: the folder context menu's "Customize
Folder…" (in place of "Tags…") opens a popover anchored to the folder's icon, with an arrow, that
edits in place and applies every change at once; Esc or a click outside closes it and keeps the
changes. The folder colour is its tag colour: seven 26 pt discs (the vivid colours, dark and
light) assign the tag and tint the folder; the last assigned wins. Hover shows a white plus and the
tag name; an assigned disc shows a check (a cross on hover) and moves into a group on the left,
10 pt apart, newest in front, followed by a 2 pt divider, while the others slide over (~280 ms);
"remove all tags" returns the folder to blue (~470 ms). A "+" menu lists the folder's colourless
tags and Edit Tags…. Below, a scrolling grid of the silica-icons symbols in seven categories (44 pt
cells, six per row, a 2 pt accent ring on the chosen one) embosses the symbol on the folder; Clear
removes the symbol or emoji and keeps the tags; Emoji opens a simple (provisional) emoji picker
with search, frequently used and a category bar, and the emoji is drawn on the folder in full
colour (stored as `{"emoji":"🎵"}` in `user.silica.folder`). The Customize Folder section of Get
Info is gone. Tag dots: in the icon view the dot behind sits 6 pt right of the front one (5 pt in
the list), the last assigned tag in front. The popover's open and close animation and the light
mode of the emoji picker are not measured yet.

Folder colour and symbol: a folder is tinted by its last assigned colour tag (`user.xdg.tags`, the
convention other file managers share) and can carry a silica-icons symbol or an emoji; they live
on the folder in `user.silica.folder` (JSON), or in the GIO metadata store on disks without user
attributes. Every view, the Desktop, the path bar, Get Info and the previews draw it, on the empty
and the full folder alike, and redraw at once when another app changes it (the folders on screen
are watched for attribute changes).

Windows: dragging files works in every view (icons, list, columns, gallery). The items are
pressed through raw pointer events, so the rubber band, taps and double clicks no longer take the
drag away; past the view's threshold the dragged items dim in place and their image (the icons as
drawn, or the list pills, with a count badge) goes to Ossido at once, held where the pointer
grabbed it, so files reach other windows, the desktop, the Dock and other apps. Over the window
the folder under the pointer lights up, springs open after ~715 ms and takes the drop; ⌥ copies,
⌘ moves even across disks. Pressing an item of a larger selection keeps the selection for the
drag. Rename on a slow click: only a click released without moving on the name of the item that
was already the only one selected, not the second click of a double click; a drag, a rubber band
or a click on the icon never opens the field.

Full folders: a folder with at least one visible item (hidden files do not count) is drawn with
the `full` variant of the silica-icons folder, on the Desktop and in every view of the window;
the symbol and tint stay on top. The check is one directory listing per folder, cached until the
folder's modification time changes.

Localization: English is the source language and Italian the first translation (Flutter
gen-l10n, `lib/l10n`). The window follows the system languages passed by the embedder, falling
back to English; sizes, dates and types are formatted for the language. Default tag names are
recognized in both languages. The `.desktop` entry has English texts with Italian translations.

Desktop: the selection square and the name's capsule no longer move the icon; dragging icons
shows a translucent image of them (with a count badge) that keeps where the pointer grabbed them,
the icons staying dimmed in place, and an ordered desktop sends dropped icons back to their cells.
Sounds: moving to the Trash and finished copies and moves play the system's interface sounds
(silica-daemon's `PlaySound`).

## 0.1.0 · 2026-10-13

Skeleton: sidebar with the user's places (xdg-user-dirs) and the Trash, list view with natural
sorting, dates and sizes, selection with ⌘ and ⇧, back and forward, opening with the default
app (`xdg-open`), hidden files, shortcuts ⌘↑ ⌘↓ ⌘[ ⌘] ⌘⇧.
