# Changelog

## Unreleased

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
