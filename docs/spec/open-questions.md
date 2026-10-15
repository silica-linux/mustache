# Conflicts and open cases

## Conflicts between measurements

When two sessions measured different values, this table records the choice and why. The item
numbers are cited elsewhere in the spec.

| # | Value | Measurements | Chosen | Why |
| --- | --- | --- | --- | --- |
| 1 | Default sidebar width | 192 in most sessions; 200 once (a window created after a restart) | 192 | more recordings; 200 is also the snap point |
| 2 | Active sidebar background | `#e5e5e7` / `#303133`; `#e2e3e5` / `#2f2f31`; `#ececed` / `#2a2a2c`; `#ededed` / `#29292a` | the last two | a material that depends on what is behind; those come from the same recording as the variants |
| 3 | Sidebar selection | `#d4d5d5` / `#474748`; `#d7d7d7` / `#464647` | the second | same recording as the variants; the difference follows the background |
| 4 | Sidebar blue icon | `#0075f2` / `#009eff` at rest; `#006ee9` / `#00acff` and `#0070eb` / `#00abff` selected | `#0070eb` / `#00abff` | rest and selected are almost equal; this one has the variants |
| 5 | Sidebar gray icon | `#7c7c82` / `#b6b7bd`; `#6e6e74` / `#c7c7cd` | the first at rest, the second under the selection | measured in different states |
| 6 | List secondary columns | `#808080` / `#9e9e9e`; `#7b7b7b` / `#a2a2a2` | the second | same recording as the variants; antialiasing |
| 7 | Secondary text on the selection | `#bad0f7` / `#b8cdf2`; `#bdcef5` / `#bbcbf0` | the second | the same |
| 8 | Icon side past slider value 56 | an early linear guess; a later non-linear table | the table ([bars.md](bars.md)) | the early session had not measured the middle values |
| 9 | Icon x pitch at 64 | 126.8 (6 columns); 114 or 128 | R4.1 | it depends on the available width |
| 10 | Autoscroll speed | ~30 pt/s per pt from one point; 20 pt/s per pt (list) from six | the six-point measurement | the single point was incomplete |
| 11 | Save sheet veil | `#cccccc` / `#1a1a1a`; `#bababa` / `#1c1c1c` | the second | measured on video at steady state |
| 12 | Esc from full-screen quick preview | "closes everything"; "back to the windowed panel" | the second | a dedicated test |
| 13 | Index view thumbnails | 704 × 528 at 776 × 576; 416 × 312 at 488 × 360 | both | they depend on the panel size (R12.2) |
| 14 | Toolbar capsules (plain variant) | `#f7f7f7`–`#fcfcfc`, dark `#454546`–`#484849`; `#f6f6f6`→`#fdfdfd`, `#4c4c4c`→`#535454` | the second | same recording as the variants |
| 15 | Inactive sidebar text, dark | `#949495`; `#969696` | the second | 2 levels apart |
| 16 | Position of a new window after several closes | first "unclear", then rules R1.1–R1.2 | R1.1–R1.2 | the later session explains it and agrees with the first |
| 17 | Veil under the toolbar, light | one session: ~83 % white with a gradient over the last 7 pt and no line; the dedicated test: a **uniform** veil, white ~51 % + saturation ×1.24, a 1 pt line once scrolled | the dedicated test (R1.9) | it used solid-color images and measured profiles. In the first session the colored bar was thin between white thumbnails, and the wide blur (σ ~35) mixed in the surrounding white: hence the lighter veil and the false gradient |
| 18 | Toolbar in an inactive window | one session: a distinct dark background (`#2f2f30`) and a 1 pt line always (`#e5e5e5` / `#363636`) when inactive, no line when active; the dedicated test: the **same** veil active and inactive, the line only once scrolled | both, by state | the first looked at the bar with nothing under it, the second with content scrolled. When inactive keep the first's background and line; with content under the bar use the formula in both states. Still to check: whether the inactive line is there with the content at the top |
| 19 | Dragged image pill color | the accent `#0064e1` (assumed opaque); composites `#366ae1` on white and `#295dd4` on gray → a solid ≈ `#205ade` at alpha 0.90 (display profile) | the accent `#0064e1` at alpha 0.90 | the first is converted to sRGB; the second gives the alpha |
| 20 | Secondary button in alerts, dark | `#525253`; `#494949`; `#808080` | each its own | different alerts and recordings; light agrees (`#e8e8e8`). *A single dark gray `#4d4d4e` (provisional: the average) is fine for Mustache* |

## Not measured

What remains cannot be done on the reference machine. No case blocks Mustache. Each comes with
the estimate to use.

| Request | Missing | Estimate |
| --- | --- | --- |
| MU-12 | a real USB stick; the progress of a slow eject | *a volume row behaves like a disk image's (R2.11): it appears in one frame. During a slow eject the row shows no indicator and disappears in one frame when done (R2.12). A busy volume gets the R2.13 alert* |
| MU-40 | dropping a file on a Dock app | *the app opens the file; the file manager shows no animation (the image vanishes in one frame, as R9.13). If the app does not accept the type, the image flies back like an invalid drop (~260 ms, R9.3)* |
| MU-02 | the title with title-bar icons always on | *the 16 pt folder icon always visible at x 285 with the title shifted 20 pt right, i.e. the end state of the hover in [toolbar.md](toolbar.md), with no animation* |
| MU-50 | Services in a file's menu, with services installed | *a Services › submenu at the bottom of the file menu, after Quick Actions ›, its items grouped by category as in the app menu* |

## Sidebar symbols

Mustache's sidebar uses `silica-icons` symbols: `clock`, `square-grid-2x2`, `display`, `doc`,
`download`, `photo`, `music-note`, `film`, `house`, `network`, `trash`, `eject`, `folder`,
`drive`, `cloud`, `tag`, `person-2`, `share-nearby`. They are our own designs. Where the
reference uses a different metaphor (applications, desktop, downloads in a circle, solid
pictures), Silica keeps its own symbol on purpose.

## Tag dots (MU-62)

| Where | Shape | Diameter | Outline |
| --- | --- | --- | --- |
| Sidebar | a **solid circle**, one color | **~12.5–13 pt** | **none**: only antialiasing |
| Context menu | a solid circle with a **1 pt ring of the same color, darker and more saturated** | **14 pt** (20 on hover, with a white + / ✓ / ×) | tone on tone, the same in light and dark |
| List | as the menu | **10 pt** | with several tags, also a 1 pt ring **in the background color** in front of the dot behind (5 pt pitch; 6 pt under an icon; the last assigned in front, on the left) |
| Tag without a color (sidebar) | a gray **ring** `#6e6e74` | — | — |

There are two palettes. The sidebar's dots are **saturated** (red `#fb001a`, orange `#f87b00`,
yellow `#f2b400`). The menu's and list's are **light** (red `#ff6663`, orange `#ffa356`, yellow
`#ffd54c`, …: the table in [menus-and-settings.md](menus-and-settings.md)).

Dots are drawn in code:
- **Sidebar:** a 13 pt solid circle with no outline.
- **Menu and list:** a solid circle (14 / 10 pt) with an inner 1 pt ring of the same tint, about
  10 % darker. In the list, overlapping dots get a 1 pt ring in the background color.
- **Tag with no color:** a ring.

No glyphs are needed beyond + ✓ × (`plus`, `checkmark`, `xmark` in `silica-icons`).
