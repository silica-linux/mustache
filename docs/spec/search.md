# Search, ⌘F (MU-70)

| Measure | Value |
| --- | --- |
| Field | the Search capsule becomes a **242 × 38** field with a focus ring |
| Scope bar | **32 pt** under the toolbar: "Search in:" plus 22 pt capsules "This Computer" and the current folder (the chosen one on a gray background); on the right, Save and − |
| Criteria rows | the first 34 pt ("Kind is Any", − +); each + adds a row at a **32** pitch |
| Result columns | Name, Kind, Last Opened (descending); no parent-folder column; the path bar is hidden |
| Token | ~15 tall, in two parts: a small-caps label with a chevron (e.g. NAME ⌄) and the value on a lighter background; its menu offers file name or everything |
| Token label background | `#bbbbbb` light / `#8f8f8f` dark |
| Save sheet | **413 × 263**, centered on the window: name, tags, where with an expansion button, Add to Sidebar (on), Cancel / Save 81 × 26 |

| Animation | Delay | Duration |
| --- | --- | --- |
| The field appears | **~+170 ms** | one frame (no width animation); the ring fades in over ~200 ms |
| First results | **~+600 ms** after the first letter | — |
| Suggestions menu | ~+650 ms | — |
| Later updates | 80–400 ms after each letter | — |

- **R13.1** ⌘F compresses the toolbar as in R1.7: the view group and Group become menus. The
  title becomes "Searching “scope”". The initial scope comes from Settings › Advanced; the
  default is This Computer.
- **R13.2** Typing without a token searches names **and contents**. The suggestions offer
  "name contains “x”" and "content contains “x”", and choosing one makes a token.
- **R13.3** No results: an empty list with the alternating rows, **no text**.
- **R13.4** Esc in the field empties it and turns it back into a capsule, but the window **stays
  in search**, with the criteria visible. Back returns to the folder.
