# JVM.PAS - clone de la machine virtuelle Java

`JVM.PAS` (a la racine) est une JVM ecrite en Pascal (Free Pascal 3.2), dans un seul fichier,
sans fichier d'inclusion. Elle execute les `.class` produits par `JAVAC.PAS` (ou `javac`).

    fpc -Mdelphi -O2 JVM.PAS
    JVM [-cp chemin] [-text] [-vga] [-debug] Classe [arguments]

- Le mode graphique (AWT/Swing) utilise PtcGraph en 256 couleurs ; `-vga` bascule sur
  `InitializeGraphics` (16 couleurs), `-text` interdit le graphique.
- La bibliotheque Java (java.lang, java.util, java.io, java.util.stream, java.util.concurrent,
  java.math, java.time, java.text, java.util.regex, java.nio.file, java.awt, javax.swing)
  est ecrite en Java dans `RT/` ; elle est compilee par JAVAC.PAS puis embarquee en base 64
  dans `JVM.PAS` (section DONNEES). Les methodes natives sont codees en Pascal.
- `TOOLS/` : scripts qui regenerent la section DONNEES (`split.py` decoupe les sources,
  `gen.py` encode les `.class`, `mk.sh` enchaine le tout).

## Limites

- Free Pascal uniquement (Int64, chaines longues, tableaux dynamiques) ; Turbo Pascal 7 ne
  peut pas compiler le moteur.
- Pas de reflexion complete (Method/Field/Constructor), d'annotations a l'execution, de
  serialisation d'objets, ni de lecture des `.jar`.
- Interpreteur seul : environ 15 a 20 fois plus lent qu'une JVM a compilation a la volee.
- Police graphique 8x8 par defaut seulement ; AWT/Swing est une reimplementation minimale
  (pas de JTable, GridBagLayout, JTabbedPane, JSplitPane).
- Les unites PtcGraph/PtcCrt demandent un affichage meme pour les programmes console.
