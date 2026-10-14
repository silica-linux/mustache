# Parità misurata

Come in `silica/ROADMAP.md`: solo metriche misurate (screenshot di Mustache dentro Ossido contro
il riferimento, con lo stesso contenuto: la cartella di prova di MU-00), mai stime. Ogni riga
cita la richiesta da cui viene il riferimento.

| Area | Metrica | Valore | Richiesta | Misurato il |
| --- | --- | --- | --- | --- |
| Elenco | etichette dell'intestazione (Nome, Data): riquadro dell'inchiostro | uguale al pixel | MU-20 · mu20-list-light | 2026-10-14 |
| Elenco | separatori delle colonne (x del contenuto) | uguali al pixel: 373, 554, 651, 772 | MU-20 | 2026-10-14 |
| Icone | cartella a 64: riquadro e centro | 59 × 48 contro 58 × 46, stesso centro verticale (y 107,5) | MU-21 · mu21-sel3-light | 2026-10-14 |
| Icone | a capo delle etichette: "barre / colorate.mov", "grande / 4000x3000.png", "configurazione.js / on", "molto lu…colonna" | uguale | MU-21 · mu21-sel3-light | 2026-10-14 |
| Elenco | freccia d'ordinamento | x uguale, y +1 px in cima (64–67 contro 63–67) | MU-20 | 2026-10-14 |
| Elenco | linea sotto l'intestazione, inizio e passo delle righe alternate | uguali al pixel (79–81; strisce 105–125, passo 40) | MU-20 | 2026-10-14 |
| Elenco | triangolo, icona, nome della prima riga | x uguali; y del testo +1 px in cima | MU-20 | 2026-10-14 |
| Elenco | fine delle righe alternate | uguale (x 772 del contenuto) | MU-20 | 2026-10-14 |
| Elenco | angolo delle righe alternate (prima x con copertura, righe 0–4) | 15,13,12,11,11 contro 14,13,12,11,10 | MU-20 | 2026-10-14 |
| Elenco | differenza media dei pixel, colonne Data e Dimensioni, 30 righe | 3,88 livelli su 255 (testi dei collegamenti diversi) | MU-20 | 2026-10-14 |

Condizioni: cartella di prova di MU-00 ricreata su Linux con gli stessi nomi, dimensioni e date,
finestra 1000 × 700 con barra laterale 200, Ossido senza finestra (`--headless`), confronto con
lo script di misura sulle stesse coordinate della finestra. Il tipo e le icone sono nostri.

Differenza nota: il riferimento ha le barre di scorrimento sempre visibili (mouse collegato),
che tolgono 17 pt al contenuto: 6 colonne di icone invece delle nostre 7 a 1000 × 700.

Da misurare:

- Barra laterale: posizioni di icone e testo, selezione, fondo chiaro e scuro (MU-10).
- Vista a icone: griglia, etichette, selezione (MU-21).
