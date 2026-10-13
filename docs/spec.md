# Mustache · specifica

Cosa fa Mustache e come si comporta. Dove un comportamento o un valore aspetta una misura
del riferimento c'è il codice della richiesta (`MU-xx`); finché manca, il valore nel codice è
provvisorio e lo dice.

## Principi

- **Un gestore dei file per tutto il sistema.** Mustache è anche il browser dei dialoghi Apri e
  Salva delle altre app (tramite `xdg-desktop-portal`, `silica/crates/portal`) e risponde a
  `org.freedesktop.FileManager1` (le app chiedono "mostra questo file nella sua cartella").
- **Standard freedesktop**, non formati nostri: cartelle dell'utente (xdg-user-dirs), Cestino
  (Trash spec), tipi di file (shared-mime-info), app predefinite (`mimeapps.list`), anteprime
  (Thumbnail Managing Standard), etichette negli attributi estesi (`user.xdg.tags`).
- **Tutto è un comando.** Ogni azione ha un id `mustache.*`, un'etichetta e una scorciatoia;
  menu, barra degli strumenti, tastiera e (dal canale dei comandi delle app di Silica) CLI e MCP
  chiamano gli stessi comandi.
- **Mai perdere un file.** Le operazioni distruttive vanno nel Cestino; ogni operazione sui file
  si annulla con ⌘Z finché è possibile; una copia interrotta lascia la destinazione pulita.

## Finestra

- Barra laterale a sinistra, contenuto a destra, barra degli strumenti in alto unificata con la
  barra della finestra (Aperto: serve che Ossido disegni i pulsanti della finestra sopra la barra
  dell'app). Opzionali: barra del percorso, barra di stato, pannello di anteprima (MU-03,
  MU-04, MU-05).
- Schede: ⌘T apre una scheda nella cartella corrente; la barra delle schede compare con la
  seconda scheda (MU-01).
- Finestra nuova: ⌘N, nella cartella Inizio (impostazione); posizione a cascata (MU-01).

## Barra laterale

- Sezioni: **Preferiti** (le cartelle dell'utente, poi quelle aggiunte trascinandole),
  **Posizioni** (cartella Inizio, dischi, volumi montati, rete, Cestino), **Etichette**.
- Attaccata ai bordi della finestra, dalla cima al fondo, senza linea verso il contenuto. Righe a
  passo 32 pt (prima riga con il centro a 68), testo a 47 pt, icone dei simboli di `silica-icons`
  nel colore d'accento (grigie per la cartella Inizio e il Cestino); intestazioni a 24 pt dalla
  prima riga e 40 dall'ultima della sezione prima (MU-10).
- Selezione: rettangolo di raggio 8 alto quanto la riga, da 10 pt dal bordo, testo in semibold;
  nessun fondo al passaggio. Colori per tema e per finestra attiva/inattiva (MU-10, MU-98).
- Intestazioni: chevron al passaggio, clic per comprimere ed espandere (~190 ms, MU-11).
- Larghezza: trascinando il bordo, fra 135 pt e quanto lascia 316 pt al contenuto; vicino a
  200 si aggancia a 200 (le finestre nuove partono da 192); contro il bordo sinistro la barra si nasconde. Le finestre nuove
  prendono l'ultima larghezza (`$XDG_CONFIG_HOME/mustache/settings.json`).
- Nascondi/mostra: `mustache.sidebar.toggle`, ⌃⌘S (~240 ms, curva a S).
- Da fare: trascinare per aggiungere, riordinare e togliere (MU-11), volumi ed espulsione
  (MU-12), etichette (MU-62).

## Viste

| Vista | Comando | Scorciatoia | Stato |
| --- | --- | --- | --- |
| A icone | `mustache.view.icons` | ⌘1 | griglia che riempie la larghezza, etichette su due righe troncate al centro, selezione con fondo e capsula, miniature delle immagini; la vista predefinita e l'ultima scelta restano nelle impostazioni (MU-21, MU-80) |
| A elenco | `mustache.view.list` | ⌘2 | scheletro: colonne Nome, Data di modifica, Dimensione, Tipo; ordinamento con clic sull'intestazione (MU-20) |
| A colonne | `mustache.view.columns` | ⌘3 | da fare (MU-22) |
| Galleria | `mustache.view.gallery` | ⌘4 | da fare (MU-23) |

- Ordinamento naturale (`file 2` prima di `file 10`), senza distinguere maiuscole e minuscole;
  a parità, per nome.
- Date: "Oggi, 10:22", "Ieri, 18:05", poi giorno, mese abbreviato, anno e ora (formato da
  verificare: MU-20).
- Dimensioni in unità decimali ("3,4 MB"), "--" per le cartelle.
- Cartelle con decine di migliaia di elementi: il contenuto compare subito e si completa mentre
  si legge (MU-24).

## Selezione e tastiera

| Azione | Comando | Scorciatoia |
| --- | --- | --- |
| Apri | `mustache.open` | ⌘↓, doppio clic |
| Cartella superiore | `mustache.go.parent` | ⌘↑ |
| Indietro / Avanti | `mustache.go.back` / `mustache.go.forward` | ⌘[ / ⌘] |
| Mostra o nascondi i file nascosti | `mustache.view.hidden` | ⌘⇧. |
| Seleziona tutto | `mustache.select.all` | ⌘A |
| Rinomina | `mustache.rename` | Invio |
| Vai alla cartella | `mustache.go.to` | ⌘⇧G |
| Informazioni | `mustache.info` | ⌘I |
| Anteprima rapida | `mustache.quicklook` | Spazio |
| Nuova cartella | `mustache.new.folder` | ⌘⇧N |
| Duplica | `mustache.duplicate` | ⌘D |
| Sposta nel Cestino | `mustache.trash` | ⌘⌫ |
| Annulla / Ripeti | `mustache.undo` / `mustache.redo` | ⌘Z / ⌘⇧Z |
| Cerca | `mustache.search` | ⌘F |
| Nuova finestra / scheda | `mustache.window.new` / `mustache.tab.new` | ⌘N / ⌘T |

La tabella completa nasce dall'inventario dei menu (MU-51). Selezione: clic, ⌘clic, ⇧clic,
rettangolo dal vuoto, frecce e ⇧frecce, digitazione per saltare a un nome (MU-30, MU-31).
Fatto oggi: clic, ⌘clic, ⇧clic, frecce.

## Operazioni sui file

- Copiare, spostare, collegare trascinando (modificatori come in MU-40), con le cartelle che si
  aprono al passaggio durante il trascinamento.
- Copie lunghe in background con avanzamento visibile e annullabile; conflitti con una domanda
  (tenere entrambi, sostituire, saltare) (MU-41).
- Nuova cartella, duplicato, archivio compresso, collegamento, Cestino e ripristino dal Cestino
  secondo la Trash spec (MU-42).
- Rinomina sul posto, con il nome selezionato senza l'estensione; rinomina di più file (MU-32).

## Altro

- **Informazioni** (⌘I) e ispettore che segue la selezione (MU-60).
- **Anteprima rapida** (Spazio): immagini, PDF, testi, audio e video, cartelle (MU-61).
- **Etichette** colorate e con nome, negli attributi estesi; righe nella barra laterale (MU-62).
- **Ricerca** nella cartella e in tutto il disco dell'utente, con criteri (MU-70).
- **Anteprime** delle immagini, dei PDF e dei video al posto delle icone (MU-80).
- **Scrivania**: le regole delle icone le applica il componente della shell (MU-90).
- **Dialoghi Apri e Salva** per le altre app, con lo stesso browser (MU-95).

## Aperto

- Barra degli strumenti unificata con la finestra: Ossido oggi disegna la barra del titolo
  (decorazioni lato server). Serve un modo per far disegnare a Ossido solo i pulsanti della
  finestra e lasciare la barra all'app (estensione di `silica-shell` o protocollo nuovo).
- Menu dell'app nella barra dei menu: arriva con `silica-menu-v1` (M7 di Silica).
- Comandi dell'app raggiungibili da CLI e MCP: serve il canale dei comandi delle app (da
  progettare in Silica).
- Trascinamento verso le altre app e la shell: `wl_data_device` c'è in Ossido, va verificato con
  l'embedder.
