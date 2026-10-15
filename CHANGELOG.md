# Changelog

## Unreleased

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
