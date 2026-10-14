# AGENTS.md

Mustache is a Silica app: the rules of `silica/AGENTS.md` apply (clean-room, assets, never
crash, everything is a command, measured parity). On top of them, for this **public**
repository:

## Clean-room

- Observations of the reference system live in the private repository `silica-reference`
  (`RICHIESTE-mustache.md` for the requests, `mustache.md` for the measurements), never here.
  Here only the request codes (`MU-20`) and the measured metrics are cited.
- Specification, comments and interface texts are written in our own words. No Apple product
  names, no texts copied from the reference interface.
- Measured numbers (sizes, colors, timings) can be used in code, with the code of the request
  they come from.

## Work

- Start of a session: `docs/plan.md` (next task), then `docs/spec.md`.
- Before every commit: `dart format`, `flutter analyze --fatal-infos`, `flutter test`,
  `tool/check_assets.sh`. One task per commit (`MU.3: icon view`).
- Everything in the repository is in English (code, comments, tests, docs, commits); the
  interface texts are the exception until they move to the localization files.
- For visual work: screenshots inside Ossido (`ui.screenshot`), comparison with the reference
  in `silica-reference`, and the metric in `docs/parity.md` only if measured.
- Every user action is a `mustache.*` command (id, label, shortcut), listed in `docs/spec.md`.
- `silica_ui` is used from a tag (`ref` in `pubspec.yaml`); a widget that other apps need too
  goes into `silica-ui`, not here.
- Never crash: an unreadable file, a vanished folder, an odd name are normal cases, with a
  message, not an exception.
