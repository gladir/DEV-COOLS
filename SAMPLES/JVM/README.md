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

## Fonctionnalites

- Reflexion complete (`Class`, `Method`, `Field`, `Constructor`, `Parameter`, `RecordComponent`,
  `Modifier`, `Array`, types generiques via l'attribut `Signature`), annotations a l'execution
  et `java.lang.reflect.Proxy`.
- Serialisation d'objets au format du JDK (`ObjectOutputStream`/`ObjectInputStream`,
  `Serializable`, `Externalizable`, `serialVersionUID`, lambdas serialisables).
- Lecture des archives `.jar`/`.zip` (inflate en Pascal, `-cp x.jar`, `-cp lib/*`,
  `-jar app.jar`), `java.util.zip`/`java.util.jar`, `ClassLoader`/`URLClassLoader`.
- Swing : `JList` (modeles `ListModel`/`ListSelectionModel`, rendus de cellules),
  `JScrollPane`/`JViewport`/`JScrollBar` (en-tetes, defilement, `Scrollable`), `JTable`
  (`TableModel`, `DefaultTableModel`, `TableColumnModel`, `JTableHeader` avec
  redimensionnement et deplacement de colonnes, rendus et editeurs de cellules, tri et
  filtrage par `TableRowSorter`/`RowFilter`), `JTabbedPane` (4 positions, plusieurs rangees),
  `JSplitPane` (divise glissante, `resizeWeight`, `oneTouchExpandable`) et `GridBagLayout`
  (algorithme du JDK, y compris l'alignement sur la ligne de base, resultats identiques),
  `JTabbedPane` avec `SCROLL_TAB_LAYOUT` (boutons de defilement des onglets) et `JTree`
  (`javax.swing.tree` : `DefaultMutableTreeNode`, `DefaultTreeModel`, `TreePath`,
  `DefaultTreeSelectionModel` et ses trois modes, rendus et editeur de noeuds, evenements
  d'expansion/de selection/de modele, `TreeWillExpandListener`, fleches, recherche par
  frappe, `Scrollable`). `java.beans.PropertyChangeSupport`
  est present et les proprietes des composants notifient leurs ecouteurs.

## Tests

`TESTS/` contient des programmes dont la sortie est comparee a celle d'un vrai JDK 21
(`Refl*`, `Serial*`, `Io1`, `Zip1`, `Loader1`, `Table1` : modeles, selection, tri, filtres et
edition de JTable, `GridBag1` et `GridBagBaseline1` : positions calculees par GridBagLayout,
`Tabs1`, `Tree1` : JTree, noeuds, modeles, selection et evenements) et des demonstrations
graphiques (`SwingDemo1` a `SwingDemo4`).

## Limites

- Free Pascal uniquement (Int64, chaines longues, tableaux dynamiques) ; Turbo Pascal 7 ne
  peut pas compiler le moteur.
- Interpreteur seul : environ 15 a 20 fois plus lent qu'une JVM a compilation a la volee.
- Police graphique 8x8 par defaut seulement ; AWT/Swing est une reimplementation compacte
  avec un seul aspect visuel (inspire de Metal/Ocean).
- La souris ne transmet pas l'etat des touches Maj/Ctrl : les selections multiples se font
  par glisser, au clavier (fleches, Ctrl+A) ou par programme.
- Pas de composants de texte riches (`JEditorPane`, `JTextPane`), de `JSpinner`, de
  glisser-deposer ni de changement d'aspect (`UIManager.setLookAndFeel` est sans effet).
- Les unites PtcGraph/PtcCrt demandent un affichage meme pour les programmes console.
