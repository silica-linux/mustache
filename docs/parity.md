# Measured parity

As in `silica/ROADMAP.md`: only measured metrics (screenshots of Mustache inside Ossido against
the reference, with the same content: the MU-00 test folder), never estimates. Every row cites
the request the reference comes from.

| Area | Metric | Value | Request | Measured on |
| --- | --- | --- | --- | --- |
| List | header labels (Name, Date): ink box | pixel-identical | MU-20 · mu20-list-light | 2026-10-14 |
| List | column separators (content x) | pixel-identical: 373, 554, 651, 772 | MU-20 | 2026-10-14 |
| Icons | folder at 64: box and center | 59 × 48 against 58 × 46, same vertical center (y 107.5) | MU-21 · mu21-sel3-light | 2026-10-14 |
| Icons | label wrapping: "barre / colorate.mov", "grande / 4000x3000.png", "configurazione.js / on", "molto lu…colonna" | identical | MU-21 · mu21-sel3-light | 2026-10-14 |
| Gallery | large icon of a folder (x, y) | 307–734 × 221–564 against 308–733 × 221–561 | MU-23 · mu23-gallery-folder-light | 2026-10-14 |
| Gallery | pane: 50 pt icon, name, Information, Created, Tags (ink boxes) | within 1–3 pt | MU-23 · mu23-gallery-folder-light | 2026-10-14 |
| List | sort arrow | same x, y +1 px at the top (64–67 against 63–67) | MU-20 | 2026-10-14 |
| List | line below the header, start and pitch of the alternating rows | pixel-identical (79–81; stripes 105–125, pitch 40) | MU-20 | 2026-10-14 |
| List | triangle, icon, name of the first row | same x; text y +1 px at the top | MU-20 | 2026-10-14 |
| List | end of the alternating rows | identical (content x 772) | MU-20 | 2026-10-14 |
| List | corner of the alternating rows (first x with coverage, rows 0–4) | 15,13,12,11,11 against 14,13,12,11,10 | MU-20 | 2026-10-14 |
| List | mean pixel difference, Date and Size columns, 30 rows | 3.88 levels out of 255 (link texts differ) | MU-20 | 2026-10-14 |

Conditions: the MU-00 test folder recreated on Linux with the same names, sizes and dates,
1000 × 700 window with a 200 sidebar, Ossido without a window (`--headless`), comparison with
the measuring script on the same window coordinates. Kinds and icons are our own.

Known difference: the reference has always-visible scroll bars (mouse connected), which take
17 pt from the content: 6 icon columns instead of our 7 at 1000 × 700.

To measure:

- Sidebar: positions of icons and text, selection, light and dark background (MU-10).
- Icon view: grid, labels, selection (MU-21).
