# Piano

I task di Mustache, in ordine. Ogni task: un commit (`MU.3: vista a icone`), test, e per il lavoro
visivo uno screenshot dentro Ossido confrontato con il riferimento.

| Task | Contenuto | Riferimento | Stato |
| --- | --- | --- | --- |
| MU.1 | Scheletro: barra laterale (luoghi utente, Cestino), vista a elenco, ordinamento, selezione, navigazione, scorciatoie | MU-10, MU-20, MU-30, MU-31 | fatto (0.1.0) |
| MU.2 | Barra laterale misurata: selezione, passaggio, sezioni comprimibili, larghezza | MU-10, MU-11 | fatto (0.2.0); restano trascinare per aggiungere e riordinare (MU-11, con MU.7), volumi (MU-12), etichette (MU.9), focus della finestra e tema scuro dall'embedder |
| MU.3 | Vista a icone: griglia, etichette, dimensioni, anteprime delle immagini | MU-21, MU-80 | fatto (0.3.0): griglia a 64/12, etichette su due righe, selezione, miniature delle immagini, frecce, ⌘1/⌘2; restano rettangolo di selezione (MU.7), dimensione e spaziatura nelle opzioni della vista, posizioni libere e Allinea, anteprime di testo e PDF (MU.8) |
| MU.4 | Rinomina sul posto, nuova cartella, duplica, Cestino (Trash spec), annulla | MU-32, MU-42 | fatto (0.4.0): rinomina con Invio e clic lento, controlli e avvisi, ⇧⌘N, ⌘D, ⌘⌫ (Ripristina nel Cestino), ⌥⌘⌫ con conferma, ⌘Z/⇧⌘Z; restano ⌃⌘N, comprimi, alias, rinomina in blocco, animazione delle righe al Cestino (210 ms), avvisi vicino all'elemento (R8.5) |
| MU.5 | Tipi di file (shared-mime-info), app predefinite e "Apri con" (`mimeapps.list`) | MU-50 | fatto (0.5.0): tipo MIME e descrizione nella colonna Tipo, apertura con l'app predefinita (`mimeapps.list`, voci .desktop, `Exec`), menu contestuali di file, cartelle, più elementi e vuoto con "Apri con"; restano Altro…, ⌥ (Apri sempre con), cerchi delle etichette (MU.9), Copia/Incolla, menu in popup veri (serve l'embedder) |
| MU.6 | Vista a colonne e barra del percorso | MU-22, MU-03 | fatto (0.6.0): colonne dalla voce della barra laterale, selezione attenuata a sinistra, frecce, scorrimento orizzontale; barra del percorso (⌥⌘P) con restringimento R1.20 e clic sui segmenti; restano maniglia e larghezza delle colonne (R5.2), colonna di anteprima (con MU.8), rilascio sui segmenti (MU.7) |
| MU.7 | Trascinamento e copie in background con avanzamento e conflitti | MU-40, MU-41 | fatto (0.9.0): copie e spostamenti in background con torta, finestra di avanzamento, annullamento e conflitti, ⌘C/⌘V/⌥⌘V; trascinamento su cartelle, barra laterale e cartella aperta con cartella a molla; rettangolo di selezione con scorrimento al bordo, ⇧clic e ⇧frecce nella vista a icone. Restano: selezione a righe trascinando nell'elenco (R7.2), trascinamento fra finestre e app (serve il trascinamento Wayland nell'embedder), immagine in volo che cambia forma (16 → 64 → 96) |
| MU.8 | Anteprima rapida | MU-61 | fatto (0.10.0): pannello con barra da 38 pt e cornice di 5 pt, immagini alla grandezza naturale (+10 × 43, min 370, max 1256), testo, pannello generico con icona grande e dati; Spazio, ⌘Y, Esc, frecce, "Apri con". Restano PDF, audio e video, vista indice, schermo intero, animazione dall'icona; il pannello sta nella finestra finché l'embedder non ha finestre figlie |
| MU.9 | Informazioni, etichette | MU-60, MU-62 | fatto (0.12.0): etichette in `user.xdg.tags`, cerchi nel menu contestuale, pallini, sezione Tag con la vista degli elementi; finestra Informazioni (⌘I) larga 265 con Generali, Nome (Invio rinomina), Commenti (`user.xdg.comment`), Apri con, Anteprima, Permessi (chmod subito), sezioni ricordate. Restano popover "Tag…", etichette personalizzate, Impostazioni › Tag, ispettore ⌥⌘I, scelta dell'app predefinita |
| MU.10 | Ricerca | MU-70 | |
| MU.11 | Schede e finestre multiple, barra di stato, pannello di anteprima | MU-01, MU-04, MU-05 | |
| MU.12 | Vista galleria | MU-23 | |
| MU.13 | Dialoghi Apri e Salva per il portale di Silica | MU-95 | con `silica/crates/portal` |

Dipendenze da Silica (aperte in `docs/spec.md`): barra degli strumenti unificata, menu globale
(M7), canale dei comandi delle app, trascinamento fra app.
