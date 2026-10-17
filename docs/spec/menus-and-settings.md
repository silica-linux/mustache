# Menus, commands, tags, Go to Folder, settings

## Context menus (MU-50, MU-62)

| Measure | Value |
| --- | --- |
| Item / separator / tags row | **24 / 11 / 49 pt** |
| Width (a file's menu) | 254 pt |
| Opening | top-left corner at the pointer (+1, −6) |
| Tag circles | **14** pt diameter, **24** pt pitch, the first 18 pt from the left edge |
| Circle, hovered | grows from **14 to 20** with a white **+**; the Tags… item becomes "Add Tag “Red”" |
| Circle, already assigned | a white **✓**; hovered, a **×** and "Remove Tag “Red”" |

Circle colors, the same in light and dark: red `#ff6663`, orange `#ffa356`, yellow `#ffd54c`,
green `#65d27b`, blue `#49a0ff`, purple `#d859e7`, gray `#a5a5a9`.

Menu layouts. Groups are separated by `|`; labels are Mustache's.

| Target | Structure |
| --- | --- |
| File | Open, Open With › \| Move to Trash \| Get Info, Rename, Compress “name”, Duplicate, Make Link, Quick Look, Copy \| Share… \| tag circles, Tags… \| Quick Actions › |
| — holding ⌥ | Always Open With; Show Inspector; Slideshow “name”; Copy “name” as Pathname |
| Folder | Open in New Tab, Paste Item \| Move to Trash \| (as a file) \| Share… \| tag circles, Customize Folder… \| Import from Device ›, Quick Actions › \| Folder Services |
| — holding ⌥ | Open in New Window; Paste Item Exactly |
| Image | as a file, plus Set Desktop Picture at the bottom |
| Several files | New Folder with Selection (N items) at the top; Rename…; Compress; with ⌥ a summary, Compress N, Slideshow N, Copy N as Pathnames |
| Empty area of the window | New Folder, Paste Item \| Get Info \| View ›, Use Groups, Sort By › (in icons also None and Snap to Grid), Show View Options \| Import from Device › \| Services › |
| Sidebar, folder | Open in New Tab, Show in Enclosing Folder \| Remove from Sidebar \| Get Info, Add to Dock |
| Sidebar, Trash | Open in New Tab \| Remove from Sidebar \| Get Info |
| Sidebar, tag | Open in New Tab \| Remove from Sidebar, Delete Tag “X”… \| Rename “X” \| No Color + 7 colors |

- **R10.1** Open With › lists the default app first, marked "(default)", then a separator, the
  other apps in alphabetical order, another separator, a link to the app store, and Other….
- **R10.2** Quick Actions › with no actions shows only Customize…. Services appears in the menus
  of the empty area and of the app, not in a file's menu.
- **R10.3** Clicking a tag circle assigns the tag (or removes it) and closes the menu.
- **R10.5** On a folder the last row of the tag group reads Customize Folder… in place of Tags…;
  it opens the Customize Folder popover on the folder's icon ([folder-customize.md](folder-customize.md)).

## App menus and commands (MU-51)

Items change while ⌥ is held (**R10.4**):

| Item | With ⌥ |
| --- | --- |
| Empty Trash… | empties without asking |
| Open | open and close the window |
| Open With | always open with |
| Close Window | close all |
| Get Info | show the inspector |
| Compress | names the item |
| Quick Look | slideshow |
| Move to Trash | delete immediately… |
| Copy | copy as pathname |
| Paste Item | move item here |
| Select All | deselect all |
| Go | a Library place appears |
| Minimize / Zoom / Move to | … all |

The View menu does not change with ⌥. With ⌥⇧ two more items appear: duplicate exactly and paste
item exactly.

- **R10.5** Some item names depend on the selection: New Folder with “name”, Copy “name”, and
  Quick Look “folder” when nothing is selected.

Commands and shortcuts (the command ids are Mustache's registry, see [product.md](product.md)):

| Menu | Command | Shortcut |
| --- | --- | --- |
| App | Settings… | ⌘, |
| App | Empty Trash… / without asking | ⇧⌘⌫ / ⌥⇧⌘⌫ |
| App | Hide / Hide Others | ⌘H / ⌥⌘H (shell) |
| File | New Window | ⌘N |
| File | New Folder | ⇧⌘N |
| File | New Folder with Selection | ⌃⌘N |
| File | New Smart Folder | — |
| File | New Tab | ⌘T |
| File | Open / and close the window | ⌘O / ⌥⌘O |
| File | Open in New Tab | ⌃⌘O |
| File | Open With › / Always Open With › | — |
| File | Close Window / Close All | ⌘W / ⌥⌘W |
| File | Get Info / Inspector / Summary | ⌘I / ⌥⌘I / ⌃⌘I |
| File | Rename | Return |
| File | Compress | — |
| File | Duplicate / exactly | ⌘D / ⌥⇧⌘D |
| File | Make Link | ⌃⌘A |
| File | Quick Look / Slideshow | ⌘Y (Space) / ⌥⌘Y |
| File | Share… | — |
| File | Show Original (of a link) | ⌘R |
| File | Add to Sidebar | ⌃⌘T |
| File | Add to Dock | ⌃⇧⌘T |
| File | Move to Trash / Delete Immediately… | ⌘⌫ / ⌥⌘⌫ |
| File | Restore (inside the Trash) | ⌘⌫ |
| File | Eject | ⌘E |
| File | tag circles, Tags… | — |
| File | Print | ⌘P |
| Edit | Undo / Redo | ⌘Z / ⇧⌘Z |
| Edit | Cut / Copy / Paste | ⌘X / ⌘C / ⌘V |
| Edit | Copy as Pathname | ⌥⌘C |
| Edit | Copy as Link | ⌃⌥⌘C |
| Edit | Move Item Here | ⌥⌘V |
| Edit | Paste Item Exactly | ⌥⇧⌘V |
| Edit | Select All / Deselect All | ⌘A / ⌥⌘A |
| Edit | Show Clipboard | — |
| Edit | Find / Find by Name… | ⌘F / ⌃⇧⌘F |
| Edit | Emoji and symbols | fn E (system) |
| View | as Icons / List / Columns / Gallery | ⌘1 / ⌘2 / ⌘3 / ⌘4 |
| View | Use Groups | ⌃⌘0 |
| View | Sort By › Name, Type, Last Opened, Added, Modified, Created, Size, Tags | ⌃⌥⌘1…7 (Created has none) |
| View | Clean Up / Clean Up Selection / Clean Up By › | ⌥⌘1…7 for Clean Up By |
| View | Show Tab Bar / Show All Tabs | ⇧⌘T / ⇧⌘\\ |
| View | Hide Sidebar | ⌃⌘S |
| View | Show Preview | ⇧⌘P |
| View | Hide Toolbar | ⌥⌘T |
| View | Show Path Bar | ⌥⌘P |
| View | Show Status Bar | ⌘' (Italian layout) |
| View | Customize Toolbar… | — |
| View | Show View Options | ⌘J |
| View | Full Screen | fn F (window) |
| Go | Back / Forward | ⌘[ / ⌘] |
| Go | Enclosing Folder / in a new window | ⌘↑ / ⌃⌘↑ |
| Go | Startup disk | ⇧⌘↑ |
| Go | Recents, Documents, Desktop, Downloads, Home, Computer, nearby sharing, Network, cloud drive, Shared, Applications, Utilities | ⇧⌘F, ⇧⌘O, ⇧⌘D, ⌥⌘L, ⇧⌘H, ⇧⌘C, ⇧⌘R, ⇧⌘K, ⇧⌘I, ⇧⌘S, ⇧⌘A, ⇧⌘U |
| Go | Library (with ⌥) | — |
| Go | Recent Folders › | — |
| Go | Go to Folder… | ⇧⌘G |
| Go | Connect to Server… | ⌘K |
| Window | Minimize / all | ⌘M / ⌥⌘M (window) |
| Window | Fill / Center / Move and resize › | fn⌃F / fn⌃C / fn⌃ arrows (window) |
| Window | Previous / Next Tab | ⌃⇧⇥ / ⌃⇥ |
| Window | Move Tab to New Window / Merge All Windows | — |
| Window | Cycle through windows | ⌘< (shell) |
| Window | Show Progress | — |
| Help | search field, manual, tips | ⌘? (shell) |

### The menus in the menu bar (silica-desktop#175)

The app publishes these menus to Silica's menu bar (silica-menu-v1, silica_ui `SilicaMenuBar`;
`lib/src/menus.dart`): the app menu, File, Edit, View, Go, Window and Help. Every state shows the
same items; the state decides which are enabled and a few labels, as measured:

- **Selection**: with nothing selected Open, Rename, Duplicate, Quick Look, Move to Trash, Copy and
  New Folder with Selection are disabled; with one item the names appear in the labels (New Folder
  with “name”, Copy “name”); Open With › is enabled for files and disabled for a folder.
- **Desktop focused**: the desktop process publishes its own menus (Ossido shows the frontmost
  client's). The four views, the bars, Customize Toolbar…, Clean Up and Clean Up By › are
  disabled; Use Groups becomes **Use Stacks** (⌃⌘0, `desktop.action` `stacks`); Sort By › stays
  enabled (None, Name, Type, Modified, Size); Close Window, Get Info, Quick Look and Go › Back and
  Forward are disabled.
- **Open and Save dialog**: the dialog's process publishes the same menus with New Window, New Tab,
  Get Info, the file operations, Gallery and the status bar and preview pane disabled; Close
  Window cancels the dialog.
- **Tabs**: one menu bar for the process, owned by the active tab; New Tab, Close Window (closes
  the tab, the last one the window) and Show Previous/Next Tab (with two tabs or more) run the tabs
  host's commands.
- **Text fields**: while a name or the search field has the keyboard, Edit acts on the field
  (Undo, Cut, Copy, Paste, Select All).
- The Option and Shift variants of an item (Close All, Duplicate Exactly, Copy as Pathname,
  Delete Immediately…, Open in New Tab, …) are not menu items: the bar has no alternates; the
  keyboard shortcuts that exist keep working.
- No Quit: Mustache keeps running without a window (DOCK-02).
- Shown disabled, not done yet: About, Settings…, New Folder with Selection, New
  Smart Folder, Compress, Make Link, Share…, Manage Shared Folder…, Show Original, Add to Sidebar,
  Eject, Print, Cut, Show Clipboard, Use Groups, Sort By › Last Opened, Date Added, Created and
  Tags, Show Tab Bar, Show All Tabs, Hide Toolbar, Customize Toolbar…, Show View Options, Show
  Preview Options, Recents, Nearby Sharing, Network, Cloud Drive, Shared, Applications, Utilities,
  Recent Folders ›, Go to Folder…, Connect to Server…, Move Tab to New Window, Merge All Windows
  and Show Progress Window. The tag colour row of File and the system Edit items (writing tools,
  autofill, dictation, emoji) are not drawn: they belong to the system.

## Tags popover and settings (MU-62)

| Measure | Value |
| --- | --- |
| Popover (Edit Tags button) | a 10 pt arrow (base ~30) toward the button; body **228 × 226**, radius **~18**, dark 1 px border |
| Content | a centered title, a 218 × 27 field, the favorite tags (rows **19**, dot + name), Show All… |
| Token | a **14** pt capsule in the tag's color (green: `#8adc98` light, `#31b54f` dark) |

| Color | Light | Dark |
| --- | --- | --- |
| Background (top → bottom) | `#f8f8f9` → `#f6f6f7` | `#474748` → `#505051` |
| Field | `#fefefe`, border `#e1e1e1` | `#1d1d1d` |

- **R10.6** Typing in the field:
  - The list filters with **inline completion**: the rest of the name is selected, the matching
    row turns the accent color, and the popover shrinks.
  - Return turns the text into a token.
  - A new name offers "Create tag “…”" and a row of colors (none + 7).
  - **Esc cancels** everything.
  - Return on an empty field confirms and closes.
- **R10.7** Settings › Tags:
  - Rows are 20 pt: a dot, the name and a checkbox, with + and − buttons.
  - There is a favorite tags row with 7 circles, and a switch that tints folders by their tag.
  - A row's menu offers Rename, Delete… and No Color + 7 colors.
  - Delete opens a 292 × 218 sheet with Cancel / Delete Tag buttons, 128 × 30.
- **R10.9** Rename “X” from a row's menu, or a tag created with +, edits the name **in place**.
  - The field replaces the name, **as wide as the text** (it grows as you type), with the
    rename focus ring ([rename.md](rename.md)).
  - The whole text is selected at the start.
  - Return confirms, and the name changes everywhere at once (R2.19).

## Go to Folder, ⇧⌘G, and Connect to Server, ⌘K (MU-52)

| Measure | Value |
| --- | --- |
| Go to Folder | a **460 × 183** card, horizontally centered on the window, its top 50 pt below the bar (y 102); fixed size; the window behind is **veiled** (white → `#cccccc`) |
| Field | 344 × 22, prefilled with the last path (or the current folder), all selected; a close × on the right |
| Suggestions | a "Go to:" header; rows **22** (443 wide, text from x +17) shown as breadcrumbs with ›; the first row in the accent color; long paths compress their first segments; 11 pt scroller |
| Connect to Server | an ordinary **window**, **486 × 234**, centered on the screen: a 448 × 26 combo box, a 446 × 72 favorites table with alternating rows, + / − / actions (90 × 26) / ?, Browse 68 × 26, Connect 78 × 26 (disabled while the field is empty) |

| Animation | Delay | End |
| --- | --- | --- |
| ⇧⌘G: the card | +85 ms | ~+207 |
| ⇧⌘G: the veil | +85 ms | ~+313 |
| Esc: card and veil go | +70 ms | ~+283 |

- **R10.8** Typing in Go to Folder:
  - It completes inline in gray after the cursor, case-insensitive.
  - The matching letters are bold in the suggestions.
  - **Tab** accepts the completion, adds "/" and lists the subfolders.
  - **Return** goes to the folder in the same window and closes the card.

## Settings (MU-97; inventory ST-APPSET-01…04)

| Measure | Value |
| --- | --- |
| Window | **377** wide (385 for Advanced). Height by pane: General 482, Tags 621, Sidebar 828, Advanced 392. Placed at (10, 389); it reopens on the last pane |
| Bar | 4 buttons (icon + label), 56 tall; the chosen one in a gray capsule with accent-colored text |

| Pane | Option | What it changes in Mustache |
| --- | --- | --- |
| General | which volumes show on the desktop: internal disks, external disks, optical and media devices, connected servers | the desktop's volume icons ([desktop.md](desktop.md)) |
| General | the folder new windows show (a places menu) | New Window's folder (R1.4) |
| General | sync Desktop and Documents with a cloud | not applicable |
| General | open folders in tabs instead of new windows | ⌘ + double click opens a tab (R1.14) |
| General | suggest file names | suggestions when naming (R8.9) |
| Tags | the tags shown in the sidebar (checkbox list, + / −) | the Tags section's rows |
| Tags | favorite tags (7 colors, draggable) | the context menu's circles |
| Tags | tint folders by their tags (switch) | folders colored with the tag |
| Sidebar | which places show: recents, shared, the user folders (applications, desktop, documents, downloads, movies, music, pictures), the locations (cloud drives, the user folder, the computer, internal and external disks, optical and media devices, nearby sharing, network computers, connected servers, Trash), recent tags | the sidebar's rows |
| Advanced | show all file name extensions | extensions always shown |
| Advanced | warn before changing an extension, before removing from the cloud drive, before emptying the Trash | confirmations (R8.4, R9.12) |
| Advanced | remove items from the Trash after 30 days | automatic Trash cleanup |
| Advanced | keep folders on top: in windows sorted by name, on the desktop | sorting (R3.5) |
| Advanced | when searching: search this computer, search the current folder, use the previous scope | the default search scope ([search.md](search.md)) |
