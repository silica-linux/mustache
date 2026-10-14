# Mustache

Il gestore dei file di [Silica](https://github.com/silica-linux/silica-desktop): cartelle e file in
viste a elenco, icone, colonne e galleria, barra laterale con i luoghi, anteprima rapida,
etichette, ricerca. Scritto in Flutter su [`silica_ui`](https://github.com/silica-linux/silica-ui).

Stato: scheletro (0.1.0). Barra laterale con i luoghi dell'utente e il Cestino, vista a elenco
con ordinamento, selezione, navigazione e scorciatoie. Il resto è nel [piano](docs/plan.md).

## Provarlo

Dentro Silica, con il repository principale accanto (`~/silica/silica`):

```
cd ~/silica/silica
cargo xtask install-app ~/silica/mustache   # bundle in release e voce .desktop
cargo xtask run --nested --shell             # Mustache è nel Dock, in Faro e nel launcher
```

`install-app` scrive `~/.local/share/applications/dev.frascella.Mustache.desktop` dal modello in
`linux/` (app id `dev.frascella.Mustache`, icona `mustache` di silica-icons, visibile solo in
Silica). Dopo una modifica al codice basta rifare il bundle:
`cargo xtask bundle ~/silica/mustache --release`.

Con `SILICA_ICONS_DIR` (lo imposta `cargo xtask run` se `silica-icons` è clonato accanto) la
barra laterale usa i simboli di [`silica-icons`](https://github.com/silica-linux/silica-icons).

Senza Silica l'app gira anche con `flutter test`; non c'è un target desktop di Flutter:
Mustache è pensato per l'embedder di Silica.

## Documenti

- [`docs/spec.md`](docs/spec.md): cosa fa Mustache e come si comporta.
- [`docs/parity.md`](docs/parity.md): parità misurata con il riferimento.
- [`docs/plan.md`](docs/plan.md): i task.
- [`AGENTS.md`](AGENTS.md): regole per chi lavora sul repository, persone e agenti.

## Licenza

MIT OR Apache-2.0 ([LICENSE-MIT](LICENSE-MIT), [LICENSE-APACHE](LICENSE-APACHE)).
