# Quick preview, Space (MU-61)

| Measure | Value |
| --- | --- |
| Panel | a floating window, **centered on the screen** |
| Top bar | **38 pt**, translucent (`#c6c7cb` over gray in light, `#6e6f73` in dark). On the left: close and full-screen circles (~14) and the name. On the right: Markup, Rotate, Share, and an "Open with <app>" capsule |
| Content frame | **5 pt** left, right and bottom; `#f8f8f9` / `#404041`; rounded corners |
| Maximum height | **1256** |
| Minimum width | ~370 |

| Content | Panel (pt) | Rule |
| --- | --- | --- |
| Image 800 × 600 / 600 × 900 | 810 × 643 / 610 × 943 | natural size + 10 × 43 |
| Image 320 × 240 | 370 × 283 | the minimum width |
| Image 4000 × 3000 | 1628 × 1256 | fitted to the maximum height |
| PDF A4 portrait / landscape | 989 × 1256 / 1724 × 1256 | the page fitted to the height |
| Text | 816 × 849 | |
| Video 160 × 120 | 373 × 223 | ×1.5; it plays automatically |
| Audio | 575 × 309 | a generic cover, duration, volume and a bar |
| Folder, code, zip, binary, no extension | **575 × 328** | a large icon on the left, the name in bold, "size, N items", "Last modified …" |

| Animation | Delay | Duration | Shape |
| --- | --- | --- | --- |
| Open: grows **from the item's icon** (scale + translation) | first frame at +119 ms, already ~60 % | 94 % at +213, 98 % at +266, still at ~+480 | exponential settling, no bounce |
| Close: back toward the icon | +22 ms | **~150 ms** | accelerating |
| ↑ ↓ with the panel open | — | one frame, size included | no fade |
| Index view, enter | +179 ms | ~210 ms | the item shrinks into its thumbnail, the others fade in |
| Index view, exit (click a thumbnail) | +100 ms | ~180 ms | the thumbnail grows |
| ⌥Space, full screen | +144 ms | ~60 ms | almost a cut |
| Full-screen controls hide | **2000 ms** after the last pointer movement | ~160 ms fade | — |

- **R12.1** With several items selected, two more controls appear:
  - a ‹ › capsule after the close button;
  - an index button on the right, a 2 × 2 grid 34 × 26.

  The last selected item is shown.
- **R12.2** The index view has the title "N items" and a 2-column grid on a translucent blurred
  background. The thumbnails scale with the panel:
  - in one case, 704 × 528 at a 776 × 576 pitch;
  - in a 1034 × 811 panel, 416 × 312 at 488 × 360.

  In both cases the pitch is the thumbnail **+ 72 in x and + 48 in y**. *A thumbnail is ~40 % of
  the panel's width (provisional: from one case).*
- **R12.3** Full screen has a **black** background. An image smaller than the screen stays at
  **natural size**. Moving the pointer shows a controls capsule:
  - ~192 × 63, `#141414`, its bottom 73 pt above the screen's bottom;
  - it holds Share | Exit Full Screen, Close.
- **R12.4** Space, Esc or × closes the panel.
  - From the index view, the first Esc returns to the item and the second closes.
  - From full screen, Esc returns to the windowed panel if that was open before. Of the two
    sessions, the dedicated test showed this.
