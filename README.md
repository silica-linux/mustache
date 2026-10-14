<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/silica-logo-dark.svg">
    <img alt="Silica" src=".github/silica-logo-light.svg" width="200">
  </picture>
</p>

<h1 align="center">Mustache</h1>

<p align="center">
  <b>The file manager of Silica.</b><br>
  List, icon, column and gallery views, sidebar places, quick preview, tags and search, in Flutter.
</p>

<p align="center">
  <img alt="Flutter: app" src="https://img.shields.io/badge/Flutter-shell%20%26%20apps-02569B?style=flat-square&logo=flutter">
  <img alt="license: MIT / Apache-2.0" src="https://img.shields.io/badge/license-MIT%20%2F%20Apache--2.0-3a3a3a?style=flat-square">
  <img alt="status: early alpha" src="https://img.shields.io/badge/status-early%20alpha-d69e2e?style=flat-square">
</p>

Written in Flutter on [`silica_ui`](https://github.com/silica-linux/silica-ui), for the
[Silica desktop](https://github.com/silica-linux/silica-desktop).

## Try it

Inside Silica, with the desktop repository next to this one (`~/silica/silica`):

```sh
cd ~/silica/silica
cargo xtask install-app ~/silica/mustache   # release bundle and .desktop entry
cargo xtask run --nested --shell             # Mustache is in the Dock, Faro and the launcher
```

`install-app` writes `~/.local/share/applications/dev.frascella.Mustache.desktop` from the
template in `linux/` (app id `dev.frascella.Mustache`, icon `mustache` from silica-icons, shown
only in Silica). After a code change, rebuild the bundle:
`cargo xtask bundle ~/silica/mustache --release`.

With `SILICA_ICONS_DIR` (set by `cargo xtask run` when `silica-icons` is cloned alongside) the
sidebar uses the symbols of [`silica-icons`](https://github.com/silica-linux/silica-icons).
Outside Silica the app runs under `flutter test`; there is no Flutter desktop target, Mustache
is built for the Silica embedder.

## Documents

- [`docs/spec.md`](docs/spec.md): what Mustache does and how it behaves.
- [`docs/parity.md`](docs/parity.md): measured parity with the reference.
- [`docs/plan.md`](docs/plan.md): the tasks.
- [`AGENTS.md`](AGENTS.md): rules for people and agents working on the repository.

## License

MIT OR Apache-2.0 ([LICENSE-MIT](LICENSE-MIT), [LICENSE-APACHE](LICENSE-APACHE)).
