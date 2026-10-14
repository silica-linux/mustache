# Dark appearance and accessibility variants (MU-98)

The per-variant values sit in each component's table: toolbar capsules
([toolbar.md](toolbar.md)), sidebar ([sidebar.md](sidebar.md)), list
([list-view.md](list-view.md)), icon selection ([icon-view.md](icon-view.md)). The variants
were turned on from the system's accessibility display settings. The rules:

- **R16.1** Reduce Transparency in light changes little: the sidebar is lighter and flatter
  (`#f7f7f7`) and the capsules are flat white. Everything else stays.
- **R16.2** Reduce Transparency in dark makes everything darker and flatter:
  - sidebar `#141414`, content `#1e1e1e`, alternating rows `#292929`;
  - nearly black capsules (`#141414` → `#1d1d1d`) with a `#3d3d3d` border.
- **R16.3** Increase Contrast changes these colors and adds **no new border** at 1×:

  | Element | Light | Dark |
  | --- | --- | --- |
  | Selection (more saturated) | `#0040dd` | `#1874da` |
  | Secondary text | `#393939` (much darker) | `#c4c4c4` (much lighter) |
  | Names | pure black | pure white |
  | Line under the list header | `#595959` | — |
  | Selected icon background | `#a6a6a6` | `#676768` |
  | Sidebar selection | `#a1a1a1` | `#646465` |
  | Sidebar blue icons | `#003ac2` (darker) | — |
- **R16.4** The inactive selection (`#dcdcdc` / `#464646`) does not change with either variant.
- The "show button shapes" accessibility option exists; it was not tried.

Not measured in the variants, to be derived from the nearest case if needed: path and status
bars, tabs, the preview pane, the gallery, Info, quick preview, popovers, dialogs and menus. In
an inactive window, only the sidebar and the list are measured.

Dark: the veil under the toolbar (R1.9) and the expanding Save panel are measured. Still
light-only: the image in flight while dragging (dark pill *`#0059d1`, provisional*), and the
file name suggestions box, which in dark is described but has no measured colors.
