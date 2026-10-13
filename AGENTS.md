# AGENTS.md

Mustache è un'app di Silica: valgono le regole di `silica/AGENTS.md` (clean-room, asset, mai
crashare, tutto è un comando, parità misurata). In più, per questo repository **pubblico**:

## Clean-room

- Le osservazioni del sistema di riferimento stanno nel repository privato
  `silica-reference` (`RICHIESTE-mustache.md` per le richieste, `mustache.md` per le misure),
  mai qui. Qui si citano solo i codici delle richieste (`MU-20`) e le metriche misurate.
- Specifica, commenti e testi dell'interfaccia sono scritti con parole nostre. Niente nomi di
  prodotti Apple, niente testi copiati dall'interfaccia di riferimento.
- I numeri misurati (dimensioni, colori, tempi) si possono usare nel codice, con il codice della
  richiesta da cui vengono.

## Lavoro

- Inizio sessione: `docs/plan.md` (prossimo task), poi `docs/spec.md`.
- Prima di ogni commit: `dart format`, `flutter analyze --fatal-infos`, `flutter test`,
  `tool/check_assets.sh`. Un task per commit (`MU.3: vista a icone`).
- Per il lavoro visivo: screenshot dentro Ossido (`ui.screenshot`), confronto con il
  riferimento in `silica-reference`, e la metrica in `docs/parity.md` solo se misurata.
- Ogni azione dell'utente è un comando `mustache.*` (id, etichetta, scorciatoia), elencato in
  `docs/spec.md`.
- `silica_ui` si usa da un tag (`ref` in `pubspec.yaml`); un widget che serve anche ad altre app
  va in `silica-ui`, non qui.
- Mai crashare: un file che non si legge, una cartella sparita, un nome strano sono casi
  normali, con un messaggio, non un'eccezione.
