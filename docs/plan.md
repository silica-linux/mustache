# Piano

I task di Mustache, in ordine. Ogni task: un commit (`MU.3: vista a icone`), test, e per il lavoro
visivo uno screenshot dentro Ossido confrontato con il riferimento.

| Task | Contenuto | Riferimento | Stato |
| --- | --- | --- | --- |
| MU.1 | Scheletro: barra laterale (luoghi utente, Cestino), vista a elenco, ordinamento, selezione, navigazione, scorciatoie | MU-10, MU-20, MU-30, MU-31 | fatto (0.1.0) |
| MU.2 | Barra laterale misurata: selezione, passaggio, sezioni comprimibili, larghezza | MU-10, MU-11 | fatto (0.2.0); restano trascinare per aggiungere e riordinare (MU-11, con MU.7), volumi (MU-12), etichette (MU.9), focus della finestra e tema scuro dall'embedder |
| MU.3 | Vista a icone: griglia, etichette, dimensioni, anteprime delle immagini | MU-21, MU-80 | fatto (0.3.0): griglia a 64/12, etichette su due righe, selezione, miniature delle immagini, frecce, ⌘1/⌘2; restano rettangolo di selezione (MU.7), dimensione e spaziatura nelle opzioni della vista, posizioni libere e Allinea, anteprime di testo e PDF (MU.8) |
| MU.4 | Rinomina sul posto, nuova cartella, duplica, Cestino (Trash spec), annulla | MU-32, MU-42 | |
| MU.5 | Tipi di file (shared-mime-info), app predefinite e "Apri con" (`mimeapps.list`) | MU-50 | |
| MU.6 | Vista a colonne e barra del percorso | MU-22, MU-03 | |
| MU.7 | Trascinamento e copie in background con avanzamento e conflitti | MU-40, MU-41 | |
| MU.8 | Anteprima rapida | MU-61 | |
| MU.9 | Informazioni, etichette | MU-60, MU-62 | |
| MU.10 | Ricerca | MU-70 | |
| MU.11 | Schede e finestre multiple, barra di stato, pannello di anteprima | MU-01, MU-04, MU-05 | |
| MU.12 | Vista galleria | MU-23 | |
| MU.13 | Dialoghi Apri e Salva per il portale di Silica | MU-95 | con `silica/crates/portal` |

Dipendenze da Silica (aperte in `docs/spec.md`): barra degli strumenti unificata, menu globale
(M7), canale dei comandi delle app, trascinamento fra app.
