# Mustache · reference specification

This folder describes how Mustache must look and behave, component by component. The values
come from **observing macOS 27** (27.0.1) from the outside, in a clean-room process. The
reference file manager was used, screenshotted and recorded, and the results were measured.
Nothing was read from the system's files.

The raw material stays private in `silica-linux/silica-reference`: screenshots, recordings and
measuring scripts. This public spec keeps only what was learned from them: numbers, colors,
timings and the behaviour, written in our own words. The interface labels quoted here are
Mustache's own (English source, `lib/l10n`), not the reference's.

## Identifiers

- **MU-xx** names a measurement request, for example MU-21 (icon view, text size and Clean Up).
  Code comments and issues cite these ids.
- **Rn.m** names a behaviour rule of component *n*, in the form "if … then …". The numbers are
  stable: issues and tests cite them.

## Conditions and units

- **Display.** The main display is 2560 × 1440 at **1× scale (1 pt = 1 px)**, 75 Hz, with a
  flat gray desktop `#7a7b80`.
- **Test setup.** The test window sits at (200, 150), 1000 × 700 pt, on a test folder. The same
  folder is recreated on Linux for the parity checks (`../parity.md`).
- **Sizes** are in **pt**. Coordinates are relative to the window unless said otherwise.
- **Colors** are in **sRGB hex**. Grays are as captured; saturated colors were converted from the
  display profile to sRGB.
- **Times** are in **ms** from the first event of the action (key down, click), accurate to one
  frame (±13.3 ms).
- **Curves** describe the shape of an animation. A constant (τ) is given where one was fitted.
- **Light / dark** are the two appearances. **RT** = Reduce Transparency and **AC** = Increase
  Contrast are the accessibility variants.
- **Provisional** marks a value that was estimated, not measured, and says what it was
  estimated from. Every other value is measured.

## Files

| File | Content |
| --- | --- |
| [window.md](window.md) | window shape, shadow, buttons, animations, drag zones and edges |
| [toolbar.md](toolbar.md) | toolbar geometry, control states, title, compression, the veil over scrolled content, customization |
| [tabs.md](tabs.md) | tab bar, All Tabs |
| [bars.md](bars.md) | path bar, status bar and icon-size slider |
| [preview-pane.md](preview-pane.md) | the preview pane |
| [sidebar.md](sidebar.md) | sidebar geometry, selection, sections, dragging, width, volumes, tags |
| [list-view.md](list-view.md) | list view |
| [icon-view.md](icon-view.md) | icon view, thumbnails, sorting and free positions |
| [column-view.md](column-view.md) | column view |
| [gallery.md](gallery.md) | gallery view |
| [selection-and-keyboard.md](selection-and-keyboard.md) | rubber band, keyboard, drag thresholds |
| [rename.md](rename.md) | renaming in place |
| [operations.md](operations.md) | dragging, copies and conflicts, new/duplicate/compress, Trash |
| [menus-and-settings.md](menus-and-settings.md) | context menus, app commands, tags popover, Go to Folder, settings |
| [info.md](info.md) | the Info window |
| [quick-look.md](quick-look.md) | quick preview |
| [search.md](search.md) | search |
| [dialogs.md](dialogs.md) | Open and Save dialogs |
| [desktop.md](desktop.md) | rules for the desktop icons (applied by the shell) |
| [appearance.md](appearance.md) | dark appearance and the accessibility variants |
| [open-questions.md](open-questions.md) | conflicts between measurements and what is still unmeasured |
| [product.md](product.md) | what Mustache is: principles, commands, views, operations (Mustache's own design) |

Diagrams in `diagrams/` are drawn by us from the numbers; they are not screenshots.
