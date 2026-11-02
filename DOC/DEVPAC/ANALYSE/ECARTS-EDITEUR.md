# Écarts ÉDITEUR / interface — manuel Devpac 3 (chap. 2 « Using the Editor » + début du chap. 3) vs DEVPAC.PAS

Sources lues : OCR p029 à p078 (pages imprimées 13 à 62 ; chap. 2 = p.13-54, boîtes de dialogue de l'assembleur = p.55-61), parts p10 (widgets/menus), p11 (éditeur/préférences), p13 (commandes/touches/souris), extraits p01 (codes touches) ; en complément le manuel DevpacST 2 (v2.txt) pour les touches WordStar, la cible réelle du clone étant « GenST 2.00 » (`VERSION_TEXT='2.00'`). Aucun fichier du dépôt modifié.
Numéros de lignes = ceux de /home/user/DEV-COOLS/DEVPAC.PAS (fonctions citées par nom). Pages = pages imprimées du manuel v3. Mention « OCR douteux » quand le texte est incertain.

---

## 1. Résumé (15 lignes)

1. L'éditeur actuel est mono-fenêtre / mono-tampon ; le manuel décrit jusqu'à 7 fenêtres (Alt-1..7, Arrange/Cycle/Close, signets par fenêtre, includes lus en mémoire depuis les autres fenêtres). C'est le plus gros écart structurel (taille XL).
2. Toutes les touches Alt-lettre du manuel (Alt-A, X, L, S, F, N, P, R, G, T, B, I, Q, J, Y, K, H, W, D...) sont absentes : seule Alt-M est gérée (`256+50` dans HandleKey), alors que la table `AltScan` existe déjà dans p01 sans être utilisée.
3. Les raccourcis Ctrl du clone (^A Assembler, ^F Chercher, ^S Sauver, ^C Copier, ^V Coller, ^W Aller à, ^U Couper, ^N Nouveau, ^Q Quitter...) entrent en conflit direct avec ceux du manuel (^A/^F = mot gauche/droite, ^V = fenêtre suivante, ^W = fermer, ^U = UnDelete ligne, ^G = polices, ^J = erreur précédente) et avec WordStar (^S/^D/^E/^X curseur, ^R/^C pages).
4. Les touches de bloc F1/F2/F3/F4/F5, Shift-F4, Shift-F5 n'existent pas : le clone utilise F5/F6 (début/fin de bloc), F1 = aide, F9 = Run, F10 = menu ; F2, F3, F4 ne font rien.
5. Sémantique du presse-papiers erronée : « Delete block »/Del/Backspace ne conservent pas le bloc supprimé ; « Save block » écrase le presse-papiers ; pas de « Copy block » (duplication F4) ; marqueurs de bloc effacés dès qu'on tape.
6. Barres de menus : le clone a 5 menus (Desk, File, Search, Options, Program) ; le manuel en a 8 (Desk, File, Edit, Block, Search, Options, Tools, Program) avec sous-menus. Absents : menus Edit, Block, Tools, sous-menus, raccourcis Alt affichés.
7. Opérations disque manquantes : Revert, Delete File, Close, Change Directory, proposition de créer un fichier inexistant, Insert File avec Alt-I (existe sous « Append... », sans raccourci), Print Block (Alt-W), plusieurs fichiers en ligne de commande (seul le 1er est chargé).
8. Recherche : pas de Find Previous, pas de Replace All « à partir du curseur » (le clone part de la ligne 1), pas d'abandon par Esc, pas de signets, pas de saisie de caractères de contrôle (^I, Shift-Ins).
9. Messages de la ligne d'état (« Top of file », « End of file », « What blocks! », « Invalid block! », bip) : aucun ; le clone utilise des boîtes d'alerte modales (« Not found » seulement).
10. Préférences : 6 réglages sur ~14 ; manquent Auto-save configuration, Hide mouse, Show matching parentheses, Stop at end of line, Save files on Quit/Run Other (Yes/No/Ask), Load/Save as/Reset, 4 formes de curseur ; plages (tab 2-16) non respectées (1-32) ; fichier DEVPAC.INF au lieu de HISOFTED.INF.
11. Menu Tools (20 outils, dialogue de configuration, Run Other/Run with Shell, %. %? %%, Environment/PATH, Make resident) : absent, hormis un « Run Other » simplifié dans le menu Program.
12. Menu Program : Assemble, Run, Debug, Mon, Run with GEM, Jump to error présents ; absents : Check (Alt-Y), Output Symbols, Run Directory, Previous error (Ctrl-J), Shift-Alt-J, erreurs recalées lors des modifications, message d'erreur dans la ligne d'état (le clone ouvre un écran texte puis une alerte).
13. Dialogues d'options de l'assembleur (Control/Listing/Options/Optimisations/Debugger) : un seul dialogue réduit à 7 champs ; les champs déjà supportés par le moteur (OptListName, OptTabSize, OptWarnings, symboles prédéfinis) ne sont pas exposés.
14. Widgets : pas de cases à cocher, pop-up, listes à boutons Add/Remove, raccourcis Alt-lettre sur boutons ; Esc annule le dialogue au lieu de vider le champ ; pas de curseur dans les champs ; pas de filtre numérique (Goto).
15. Absents aussi : Fonts (Ctrl-G), ASCII Table (Shift-Ins), Cycle/Arrange, Help détaillé (Alt-H), Install Application (sans objet), Resident Tools, Undo key.

---

## 2. Liste ordonnée des 20 corrections les plus utiles

| # | Correction | Réf. | Taille |
|---|-----------|------|--------|
| 1 | Brancher les raccourcis Alt-lettre (table `AltScan` existante) : Alt-A/Y/X/D/M/K/J, Alt-L/S/I/Q, Alt-F/N/P/R/G/T/B, Alt-H, Alt-W, Shift-Alt-S, Shift-Alt-J | G-KEY-1 | S-M |
| 2 | Touches de bloc du manuel : F1 début, F2 fin, F3 save block, F4 copy block, F5 paste, Shift-F4 remember, Shift-F5 delete ; déplacer l'aide sur Alt-H/Help | G-BLK-1 | S |
| 3 | Corriger le presse-papiers : Delete block = Cut (garde le texte), Save block n'écrase plus le presse-papiers, Copy block (duplication à la position du curseur), marqueurs conservés pendant l'édition | G-BLK-2..5 | S-M |
| 4 | Réaligner les commandes Ctrl sur le manuel/WordStar : ^Y, ^@ (fin de ligne), ^U/Undo (UnDelete ligne avec tampon), ^A/^F mot, ^S/^D/^E/^X, ^R/^C pages, ^W fermer, ^V cycle ; déplacer les commandes du clone sur Alt | G-KEY-2, G-DEL-1..3 | M |
| 5 | Ligne d'état avec messages exacts + bip : Top of file, End of file, Not found, What blocks!, Invalid block!, nb de remplacements, message d'erreur d'assemblage | G-MSG-1..2 | M |
| 6 | Find Previous (Alt-P), dialogue Find avec boutons Next/Previous/Cancel et pop-up Casing, Replace/Replace All à partir du curseur, Esc d'abandon avec décompte | G-SRCH-1..5 | M |
| 7 | Restructurer les menus : Edit (Cut/Copy/Paste, Goto Top/Bottom/line), Block, Search (Find..., Find Next/Previous, Replace, Replace All, Bookmarks), Tools, avec raccourcis Alt affichés et sous-menus | G-MENU-1..4 | M |
| 8 | Menu Program : Check (Alt-Y), Previous error (^J), Jump to Error (Alt-J) dans la ligne d'état, Shift-Alt-J, recalage des numéros d'erreur lors des insertions/suppressions, Run Directory | G-PRG-1..6 | M |
| 9 | Menu File : Revert, Delete File, Close, Change Directory, Insert File (Alt-I), invite « créer le fichier ? », confirmation de fermeture Save/Leave | G-FILE-1..8 | M |
| 10 | Préférences complètes (Auto-indent, Auto-save configuration, Hide mouse, Make backups, Show matching parentheses, Stop at end of line, Save files on Quit / Run Other, Tab 2-16, Buffer 4000-999000, 4 formes de curseur, Load / Save as / Reset) | G-PREF-1..8 | M |
| 11 | Signets (Set/Goto Bookmark 1-8, Ctrl-Shift-chiffre / Ctrl-chiffre) | G-SRCH-6 | S (1 fenêtre) |
| 12 | Fichier de configuration : nom HISOFTED.INF, recherche répertoire courant puis PATH, Auto-save, sauver aussi OptOutName/listing/run dir | G-CFG-1..4 | S-M |
| 13 | Multi-fenêtres (jusqu'à 7), Alt-1..7, Arrange Windows (Overlap/Tile/Vertical), Cycle Windows, Close, signets par fenêtre, includes lus en mémoire | G-WIN-1..6 | XL |
| 14 | Widgets de dialogue : cases à cocher, pop-up, listes (Add/Remove/double-clic/glisser), Alt-lettre sur boutons, Esc = vider le champ, curseur et Delete dans les champs, filtre numérique, Shift-Ins | G-DLG-1..7 | L |
| 15 | Menu Tools : 20 outils configurables, dialogue (Menu entry, Command line None/Prompt/As shown, Directory, Save files, Path, Pause, Report all errors, TOS/GEM, Make resident), Run Other (Alt-0), Run with Shell (Shift-Alt-0), %. %? %% | G-TOOL-1..6 | L |
| 16 | Dialogues d'assemblage : exposer ce que le moteur sait déjà faire (Listing None/Screen/Printer/Disk + List to + Tab size, No warnings, EQU symbols, INCLUDE dirs multiples, Ignore multiple includes) et prévoir les autres cases (Options/Optimisations) | G-ASM-1..6 | M-L |
| 17 | Dialogue de sortie « Save All / As Above / Leave All / Leave » + case Backups | G-FILE-9 | M |
| 18 | Souris : double-clic = mot, glisser par mot, clic marge = ligne, défilement auto, glisser le curseur de la barre, clic zone grise = page | G-MOUSE-1..5 | M |
| 19 | Table ASCII (Edit, Shift-Ins), Fonts (Ctrl-G), About avec mémoire libre, Help (Alt-H) avec la liste des touches | G-MISC-1..5 | M |
| 20 | Ligne de commande : jusqu'à 7 fichiers chargés dans 7 fenêtres (GTP) ; options Debugger (dialogue Mon : 11 réglages) | G-CLI-1, G-DBG-1 | S / M |

---

## 3. Écarts détaillés, par thème

Format : **ID — titre** — *Manuel (p.)* / *Code* / *Gravité* / *Taille*.
Classement dans chaque thème : du plus prioritaire au moins prioritaire. Gravité : bloquant (une procédure documentée est impossible ou produit un autre résultat), important, mineur.

### 3.1 Raccourcis clavier Alt / Ctrl / touches de fonction

**G-KEY-1 — Raccourcis Alt-lettre absents**
- Manuel (p.14, 22-31, 47-50) : « Using a menu shortcut, by pressing the Alternate key (Alt) in conjunction with another, such as Alt-F for Find ». Liste lisible dans le texte : Alt-T (Goto Top), Alt-B (Goto Bottom), Alt-G (Goto line), Alt-F (Find), Alt-N (Find Next), Alt-P (Find Previous), Alt-R (Replace), Alt-L (Load), Alt-S (Save As), Shift-Alt-S (Save), Alt-I (Insert File), Alt-Q (Quit), Alt-W (Print Block), Alt-H (Help), Alt-A (Assemble), Alt-Y (Check), Alt-X (Run), Alt-J (Jump to error), Shift-Alt-U/J (erreur suivante dans la fenêtre), Alt-0 (Run Other), Shift-Alt-0 (Run with Shell), Alt-1..7 (fenêtres), Alt-chiffre du pavé numérique (outils). Menu Program (OCR p.47) : Run Alt-X, Debug Alt-D (OCR « ap »/« 5X » douteux), Mon Alt-M, Run with GEM Alt-K, Previous error Ctrl-J, Jump to Error Alt-J. Dans les boîtes : Alt-première lettre du bouton (p.14).
- Code : HandleKey (l. 14925) ne traite que `256+50` (Alt-M → CmdMonitor). `AltScan` (p01, l.~126) est déclarée mais jamais utilisée. Les menus affichent `^X` à la place de `Alt-X` (MLabel, l. 7615).
- Gravité : **bloquant** (toute la mémoire musculaire du manuel est inutilisable). Taille : S-M (décoder `K=256+scan` avec `AltScan`, mapper vers les mêmes Cmd*/DoMenu ; scancodes Alt-chiffre 120-129).

**G-KEY-2 — Raccourcis Ctrl du clone en conflit avec le manuel**
- Manuel (p.14, 19-21, 26) : ^A/^F = mot à gauche/droite ; ^V = Cycle Windows ; ^W = fermer la fenêtre ; ^Y = supprimer ligne ; ^@ = supprimer jusqu'en fin de ligne ; ^U (ou touche Undo) = UnDelete ligne ; ^G = Fonts ; ^J = erreur précédente ; ^I = Tab ; Ctrl-gauche/droite = début/fin de ligne ; Shift-gauche/droite = mot ; Shift-haut/bas = page. En v2 (p.17-18 v2.txt) : ^S ^D ^E ^X = flèches WordStar, ^R/^C = page haut/bas.
- Code : CtrlCommand (l. 14900) affecte ^A Assembler, ^B Effacer bloc, ^C Copier, ^D Debug, ^F Chercher, ^G Suivant, ^J Jump to error (prochaine, pas précédente), ^K Run with GEM, ^L Load, ^N New, ^O Run Other, ^Q Quit, ^R Replace, ^S Save, ^U Cut, ^V Paste, ^W Goto, ^X Run, ^Y Delete line. ^E, ^H(=Bksp), ^I(=Tab) : rien ou standard. Ctrl-gauche/droite = mot (convention PC) et non début/fin de ligne ; Home/End = début/fin de ligne (équivalent PC acceptable). Pas de Shift-flèches (la lecture `ReadKey` ne les distingue pas).
- Gravité : **bloquant** pour qui suit le manuel/WordStar (^A, ^F, ^V, ^W, ^U font autre chose). Taille : M (réaffecter ; déplacer les commandes du clone sur Alt-lettre ; mettre à jour CmdHelp et les libellés de menus).

**G-KEY-3 — Touches de fonction**
- Manuel (p.23-26) : F1 Block Start, F2 Block End, F3 Save Block, F4 Copy Block, F5 Paste Block, Shift-F4 Remember Block, Shift-F5 Delete Block. Touches Help/Undo/Insert (Shift-Ins = table ASCII) ; Help = aide.
- Code : K_F1 → CmdHelp ; K_F5 → début de bloc ; K_F6 → fin de bloc ; K_F9 → Run ; K_F10 → menu Desk ; F2/F3/F4/F7/F8 non gérées ; Shift-F4/F5 non gérées ; Ins = bascule insertion/écrasement (non décrit dans le manuel) ; pas de touche Undo.
- Gravité : **bloquant** (voir G-BLK-1). Taille : S.

**G-KEY-4 — Touches de curseur diverses**
- Manuel (p.20-22) : Ctrl-gauche début de ligne / Ctrl-droite fin de ligne ; Shift-haut/bas = page ; clic sur les flèches des barres ; Alt-T / Alt-B ; Alt-B va au début de la DERNIÈRE ligne.
- Code : K_PGUP/K_PGDN OK (page = TXT_ROWS-1) ; K_CHOME/K_CEND fonctionnent mais Ctrl-End place le curseur en FIN de dernière ligne (K_CEND : `CurC:=Length+1`), pas au début ; pas d'équivalent menu « Goto Top / Goto Bottom ».
- Gravité : mineur. Taille : S.

**G-KEY-5 — Pavé numérique « Cursor mode »**
- Manuel (p.34) : pavé numérique utilisable comme curseur (7 début de ligne, 1 fin de ligne, 9/3 pages...), « défaut : Cursor pad mode ».
- Code : `PrefNumPad` est lu/écrit mais n'a aucun effet ; valeur par défaut 1 = « Numbers » (radio `Numbers|Cursor`) donc contraire au manuel.
- Gravité : mineur (le pavé PC a déjà ses touches curseur). Taille : S.

### 3.2 Curseur, saisie, tabulation

**G-CUR-1 — Messages « Top of file » / « End of file »** : voir G-MSG-1 (curseur haut/bas bloqué sans retour d'information).

**G-CUR-2 — « Stop at end of line »** (manuel p.35) : option absente. Code : flèche gauche au début de ligne passe à la fin de la ligne précédente et droite en fin de ligne passe à la suivante (K_LEFT/K_RIGHT) = équivalent de l'option désactivée, sans possibilité de bloquer. Gravité mineur, taille S.

**G-CUR-3 — Curseur au-delà de la fin de ligne** (manuel p.20) : on peut cliquer/placer le curseur après la fin de ligne et le texte tapé est ajouté à la fin réelle. Code : EdPosAt/EnsureVisible ramènent toujours CurC à `Length+1` (le curseur ne reste jamais « à droite » du texte) ; effet utilisateur équivalent, colonne affichée différente. Gravité mineur, taille S.

**G-CUR-4 — Backspace au-delà de la fin de ligne / Delete en fin de ligne** (manuel p.21) : « Delete … has no effect if the cursor is past the end of the current line ». Code (DoDelete, l. 13472) : en fin de ligne Delete joint la ligne suivante. (OCR clair mais formulation ambiguë : fin de ligne = « past the end » ? à valider.) Gravité mineur, taille S.

**G-CUR-5 — Tabulation** : manuel p.21 plage 2 à 16 (défaut 8). Code : octet #9 conservé, alignement multiple de PrefTab ✓ ; mais plage acceptée 1-32 (EditorPrefsDlg, LoadPrefs). Gravité mineur, taille S.

**G-CUR-6 — Limites de taille** : manuel : pas de limite hors mémoire (tampon 4000-999000 octets). Code : ligne limitée à 250 caractères (InsertChar, DoBackspace, DoDelete refusent silencieusement), MAXLN = 16000 lignes (alerte « Too many lines »). Gravité mineur (avertir au lieu d'échouer silencieusement), taille S.

**G-CUR-7 — Auto-indent, Show matching parentheses, Hide mouse** : auto-indent ✓ (NewLineAt copie les blancs de début de ligne). « Show matching parentheses » (p.35 : en tapant `)` le curseur saute à la `(` correspondante et revient) et « Hide mouse when typing » (p.34) absents. Gravité mineur, taille S chacun.

### 3.3 Blocs et presse-papiers

**G-BLK-1 — Marquage et commandes de bloc par touches** (voir G-KEY-3)
- Manuel (p.23-25) : F1/F2 marquent début/fin ; ordre libre ; menu Block : Block Start F1, Block End F2, Save Block F3, Copy Block F4, Delete Block Shift-F5, Remember Block Shift-F4, Paste Block F5, Print Block Alt-W.
- Code : menu « Search » mélange recherche et blocs (items 6-13 : Set block start F5, Set block end F6, Copy/Cut/Paste/Delete block, Select all). Pas de menu Block, pas de « Save block » dans le menu bloc (il est dans File), pas de « Copy block » (duplication), pas de « Print block ».
- Gravité : **bloquant**. Taille : S-M.

**G-BLK-2 — « Delete block » doit conserver le bloc dans le presse-papiers**
- Manuel (p.25-26) : « A deleted block is remembered, memory permitting, in the clipboard … equivalent to Cut on the Edit menu ».
- Code : le menu « Delete block » (^B) appelle DeleteBlock seul (l. 14843, M=3 I=11) ; Del et Backspace avec un bloc actif appellent aussi DeleteBlock sans copie (HandleKey) → perte de texte irrécupérable (et, après un Find, le texte trouvé étant marqué comme bloc, Del/Backspace supprime la chaîne trouvée). Seul « Cut block » (^U) copie d'abord.
- Gravité : **bloquant** (perte de données). Taille : S.

**G-BLK-3 — « Save Block » ne doit pas toucher au presse-papiers et doit signaler les erreurs**
- Manuel (p.24) : sans bloc → message « What blocks! » ; début après la fin → « Invalid block! » ; fichier existant écrasé sans backup.
- Code : SaveBlockFile (l. 13670) appelle CopyBlock, donc remplace le contenu du presse-papiers ; CmdSaveBlock sans bloc sort silencieusement (aucun message) ; l'ordre début/fin est normalisé par BlockOrder donc « Invalid block! » n'existe jamais.
- Gravité : important. Taille : S.

**G-BLK-4 — « Copy Block » (F4) = duplication du bloc à la position du curseur ; « Remember » (Shift-F4) = copie vers le tampon**
- Manuel (p.24-25) : Copy Block insère une copie à la position du curseur ; si on copie dans le bloc lui-même → « Invalid block! ». Remember Block = Copy du menu Edit.
- Code : « Copy block » = copie vers le presse-papiers (équivalent Remember/Copy), pas de duplication ; pas de test « Invalid block! ».
- Gravité : important. Taille : S.

**G-BLK-5 — Persistance des marqueurs de bloc**
- Manuel (p.26) : « Block markers remain during all editing commands, moving where necessary, and are only reset by the commands Delete block and Load. »
- Code : le bloc est effacé (ClearBlock) par toute frappe de caractère, Enter, Tab, Esc, clic souris, Paste ; les marqueurs ne se décalent pas quand des lignes sont insérées/supprimées (BlkSL..BlkEC fixes) → bloc faux après édition. New/Load l'effacent (OK).
- Gravité : important. Taille : M (recaler BlkSL/EL à chaque InsLineAt/DelLineAt/SetLine).

**G-BLK-6 — Sélection à la souris**
- Manuel (p.23) : glisser ; double-clic = mot ; double-clic + glisser = mot par mot ; clic dans la marge gauche = ligne par ligne ; défilement automatique en haut/bas.
- Code : MouseDown/MouseMove : glisser caractère par caractère ; pas de double-clic ni de marge ; pas de défilement auto spécifique (EnsureVisible suit le curseur mais la souris doit rester dans la zone). Voir G-MOUSE.
- Gravité : mineur. Taille : M.

**G-BLK-7 — Presse-papiers perdu lors d'un changement de taille de tampon ou après assemblage** (manuel p.25) : le code conserve le presse-papiers (ClipLn) ; écart sans conséquence (plus tolérant). Gravité mineur, taille S (ne rien faire).

**G-BLK-8 — Impression d'un bloc** (manuel p.25) : Alt-W, alerte de confirmation, tabulations → espaces, tout le fichier si aucun bloc. Code : absent. Gravité mineur (impression hôte à définir), taille M.

**G-BLK-9 — « Select all »** : fonction du clone absente du manuel (extra, à conserver ou documenter).

### 3.4 Suppression et « UnDelete »

**G-DEL-1 — Delete line (^Y) sans tampon d'annulation**
- Manuel (p.26) : la ligne supprimée est conservée dans un tampon interne ; ^U ou touche Undo la réinsère, autant de fois que voulu.
- Code : DeleteCurLine (l. 13497) supprime sans mémoriser ; ^U = « Cut block ». Gravité : important. Taille : S.

**G-DEL-2 — Delete to end of line (Ctrl-@)** (manuel p.26) : absent (aucun code K=0). Gravité : important. Taille : S.

**G-DEL-3 — UnDelete Line (^U / Undo)** : absent (voir G-DEL-1). Gravité : important. Taille : S. (touche Undo : sous DOS/PtcGraph `ReadKey` n'a pas de code Undo ; prévoir une touche de remplacement.)

### 3.5 Recherche, remplacement, signets, aller à

**G-SRCH-1 — Find Previous (Alt-P)** absent. Manuel p.27 : « Find Previous … starts just before the cursor ». Code : FindFrom ne cherche que vers l'avant ; pas de menu. Gravité : important. Taille : S.

**G-SRCH-2 — Dialogue Find**
- Manuel (p.27) : champs Find et Replace dans la même boîte ; pop-up « Casing » (test=Test / test<>Test) ; boutons Cancel / Previous / Next (Return = Next) ; la chaîne de remplacement peut rester vide.
- Code : DoFind (l. 13733) : champ « Texte » + radio Ignorer/Respecter + OK/Annuler ; DoReplace est un dialogue séparé (champ Find + Replace + Casse + Mode Un/Tous). Pas de bouton Previous.
- Gravité : mineur. Taille : M.

**G-SRCH-3 — Message « Not found » et curseur**
- Manuel (p.27) : « the message Not found will appear in the status area and the cursor will remain unmoved ».
- Code : alerte modale « Not found / Introuvable / Nicht gefunden » (DoFindNext, DoReplace) ; curseur inchangé ✓ ; pas de bip ; la chaîne trouvée est marquée comme bloc (effet de bord, voir G-BLK-2).
- Gravité : mineur. Taille : S.

**G-SRCH-4 — Replace (Alt-R)**
- Manuel (p.28) : remplace l'occurrence trouvée puis « the editor will then search for the next occurrence ».
- Code (mode « Un ») : cherche à partir du curseur (CurC, inclus), remplace, place le curseur après le remplacement ; ne recherche pas la suivante ; pas de raccourci sans dialogue (^R rouvre toujours le dialogue).
- Gravité : important. Taille : S.

**G-SRCH-5 — Replace All**
- Manuel (p.28) : « from the cursor position onwards » ; Esc abandonne et la ligne d'état indique le nombre de remplacements ; volontairement sans raccourci clavier.
- Code (mode « Tous ») : démarre à la ligne 1 colonne 1 (`FL:=1;FC:=1`) ; pas d'abandon par Esc ; décompte dans une alerte ; accessible au clavier (^R puis radio).
- Gravité : important (remplace aussi avant le curseur). Taille : S.

**G-SRCH-6 — Signets (bookmarks)**
- Manuel (p.28-29) : Search > Set Bookmark (1-8, Ctrl-Shift-chiffre) et Goto Bookmark (Ctrl-chiffre) ; le numéro de fenêtre s'affiche dans le menu ; perdus à la fermeture de la fenêtre. Items « Set 2 Alt-2 »... OCR douteux sur les raccourcis Alt-chiffre (le texte dit Ctrl).
- Code : absents (aucun sous-menu possible dans RunMenu).
- Gravité : important. Taille : S (mono-fenêtre) / M avec sous-menus.

**G-SRCH-7 — Caractères de contrôle dans les champs de recherche**
- Manuel (p.28) : Ctrl-I = Tab, autres caractères de contrôle sauf CR/LF ; Shift-Ins ouvre la table ASCII.
- Code : DlgRun n'accepte que les codes 32..255 ; Ctrl-I est un Tab de navigation de champ. Gravité : mineur. Taille : S (+ table ASCII M).

**G-SRCH-8 — Goto line (Alt-G)**
- Manuel (p.22) : dialogue n'acceptant que des chiffres ; message « End of file » si la ligne n'existe pas.
- Code : DoGotoLine via InputDlg, tous caractères acceptés (ToInt), GotoLine ramène silencieusement à la dernière ligne. Raccourci ^W (qui est « fermer fenêtre » dans le manuel).
- Gravité : mineur. Taille : S.

**G-SRCH-9 — Goto Top / Goto Bottom** (manuel p.22, Alt-T / Alt-B, items du menu Edit) : absents du menu (seulement Ctrl-Home/End). Gravité : mineur. Taille : S.

### 3.6 Menus (barres, éléments, comportement)

**G-MENU-1 — Structure des barres de menus**
- Manuel (p.17, 22, 23, 27, 29, 33, 38, 47) : Desk (About Devpac-3..., accessoires) ; File (New, Load, Insert File, Revert, Close, Save As..., Save, Delete File, Change Directory, Quit) ; Edit (Cut, Copy, Paste, ASCII Table..., Goto Top, Goto Bottom, Goto..., Arrange Windows >, Cycle Windows, Window >) ; Block (Block Start, Block End, Save Block, Copy Block, Delete Block, Remember Block, Paste Block, Print Block) ; Search (Find..., Find Next, Find Previous, Replace, Replace All, Set Bookmark >, Goto Bookmark >) ; Options (4 dialogues d'assemblage Control/Listing/Options/Optimisations, Debugger, Preferences..., Resident..., Fonts..., Environment..., Save preferences, Install Application côté Bureau) ; Tools (Tool 1..20 avec Alt+pavé, Run Other... Alt-0, Run with Shell Shift-Alt-0) ; Program (Assemble, Check, Output Symbols, Run, Debug, Mon, Directory >, Run with GEM, Previous error, Jump to Error). (L'OCR ne garantit ni l'ordre exact des menus ni la présence de tous les items dans Options.)
- Code : MTitle (l. ~7594) : Desk, File, Search, Options, Program. Desk : About, Help, Memory. File : New, Load, Save, Save as, Append, Save block, Quit. Search : Find, Find next, Replace, Goto line, Set/End block, Copy/Cut/Paste/Delete block, Select all. Options : Editor preferences, Assembler options, Debugger options (qui ouvre en fait RunOptionsDlg : GEM + accessoires), Save/Load preferences. Program : Assemble, Run, Debug, MonST, Run with GEM, Jump to error, Run Other.
- Gravité : important. Taille : M (ajouter Edit, Block, Tools ; réorganiser).

**G-MENU-2 — Sous-menus** (manuel p.17) : indicateur », ouverture après un court délai, ouverture à gauche si pas de place. Code : RunMenu/DrawDropDown ne gèrent pas les sous-menus. Gravité : important (nécessaire pour Arrange Windows, Window, Bookmarks, Directory). Taille : M.

**G-MENU-3 — Raccourcis affichés** : le clone affiche `^X`/`AltM`/`F5` ; le manuel affiche Alt (symbole « Alternate ») + lettre, Shift-F5, etc. Gravité : mineur. Taille : S (dépend de G-KEY-1).

**G-MENU-4 — Éléments désactivés / coches**
- Manuel (p.28, 49) : Goto Bookmark n'est actif qu'après Set ; coche à côté de Run with GEM.
- Code : MEnabled (l. ~14xx) grise Find next sans chaîne, Save/Copy/Cut/Delete block sans bloc, Paste sans tampon, Jump to error sans erreur ✓ ; coche sur Run with GEM ✓ (MChecked).
- Gravité : — (conforme). À étendre aux nouveaux items (Revert si fichier jamais sauvé : « Revert will do nothing »).

**G-MENU-5 — Désk accessoires** (manuel p.46) : la liste des accessoires dans Desk. Code : accessoires chargés à l'exécution de programmes (LoadAccessories) mais aucun menu d'accessoires dans l'éditeur ; le menu Desk contient « Help » et « Memory... » (extras). Gravité : mineur. Taille : M.

**G-MENU-6 — F10 / activation au clavier** : F10 ouvre le menu (non décrit dans le manuel), navigation ←→↑↓ et Entrée ✓ ; pas de sélection par lettre. Gravité : mineur.

### 3.7 Opérations disque

**G-FILE-1 — New** (manuel p.29) : ouvre une fenêtre vide (jusqu'à 7). Code CmdNew : vide le tampon actuel après confirmation « Discard the changes ? ». Raccourci ^N (Alt-N = Find Next dans le manuel). Gravité : important (lié G-WIN). Taille : S/XL.

**G-FILE-2 — Load (Alt-L)** (p.29-30) : nouvelle fenêtre (ou fenêtre inutilisée) ; si le fichier est trop grand → alerte « augmentez le tampon » ; si le fichier n'existe pas → boîte proposant de le CRÉER. Code CmdLoad : remplace le texte (avec confirmation) ; fichier absent → alerte « Cannot open file » sans proposition de création ; alerte « File too large for the text buffer » ✓ (équivalent). Masque `*.S`. Gravité : important. Taille : S-M.

**G-FILE-3 — Revert** (p.30) : recharge la dernière version sauvée, avec avertissement ; sans effet si jamais sauvé. Code : absent. Gravité : important. Taille : S.

**G-FILE-4 — Save As (Alt-S) / Save (Shift-Alt-S)** (p.30-31) : Save As via sélecteur ; Save réutilise le nom, sinon sélecteur ; backup `.BAK` si « Make backups » (renomme l'ancien, supprime l'ancien .BAK). Code : EdSaveFile ✓ (renommage en .BAK, suppression du .BAK préexistant) ; Save = ^S, Save as sans raccourci ; confirmation « File exists / Overwrite » ajoutée par le clone (le sélecteur GEM le fait de son côté dans le manuel). Gravité : mineur. Taille : S (raccourcis).

**G-FILE-5 — Insert File (Alt-I)** (p.31) : insère le fichier à la position du curseur. Code : « Append... » (CmdAppend → EdLoadFile(…, True)) insère les lignes APRÈS la ligne courante (`InsLineAt(CurL+I,…)`), pas à la colonne du curseur ; sans raccourci ; libellé différent. Gravité : mineur. Taille : S.

**G-FILE-6 — Delete File** (p.31) : sélecteur puis effacement. Code : absent. Gravité : mineur. Taille : S.

**G-FILE-7 — Close (Ctrl-W)** (p.31) : ferme la fenêtre ; avertit si modifiée (continuer / annuler / sauver). Code : absent ; le clic sur la case de fermeture appelle CmdQuit (quitte l'application, MouseDown l. 15014). Gravité : important. Taille : S (mono-fenêtre) / lié G-WIN.

**G-FILE-8 — Change Directory** (p.31, 42-43) : sélecteur de dossier, modifie le répertoire courant ; sert à Run (Run Directory « Current »), aux outils, et est mémorisé dans HISOFTED.INF. Code : absent ; FileSelect garde son propre répertoire. Gravité : important. Taille : M (répertoire courant global + sauvegarde dans l'INF).

**G-FILE-9 — Quit (Alt-Q)** (p.32) : si des textes sont modifiés, dialogue listant les fichiers modifiés avec boutons « Save All », « As Above », « Leave All », « Leave » par fichier, case Backups. Code (CmdQuit, l. 14777) : alerte Save/Quit/Cancel pour l'unique tampon ; préférence « Save files on Quit » (Yes/No/Ask, p.35) absente. Gravité : important (devient indispensable avec le multi-fenêtre). Taille : M.

**G-FILE-10 — Fichiers en ligne de commande** (p.30) : jusqu'à 7 fichiers chargés automatiquement (CLI ou GTP) ; fichier absent → proposition de le créer. Code : ParseCommandLine accepte 20 noms mais seul FileQueue[1] est chargé dans l'éditeur ; les suivants ne servent que pour /A /X /D (chargés l'un après l'autre en remplaçant le texte). Gravité : mineur. Taille : S-M.

**G-FILE-11 — Format du fichier** : sauvegarde en CR+LF (comme sur ST) ✓.

### 3.8 Plusieurs fenêtres

**G-WIN-1 — Support de 7 fenêtres** (p.19) : Alt-1..Alt-7, chaque fenêtre avec son tampon de la taille « Text Buffer » (mémoire allouée par fenêtre en usage). Code : un seul tampon (`Ed`, `EdN`, `EdFile`...). Gravité : **bloquant** (fonction centrale du chap. 2 et prérequis des signets, includes en mémoire, Close, Cycle, quit multiple). Taille : XL (refonte des variables globales de p11 en un enregistrement de fenêtre).

**G-WIN-2 — Arrange Windows (Overlap / Tile / Vertical), Ctrl = disposition permanente** (p.17, 19) : absent. Gravité : important. Taille : L.

**G-WIN-3 — Cycle Windows (Ctrl-V) et sous-menu Window** (p.19, 22) : absent (^V = Paste dans le clone). Gravité : important. Taille : M.

**G-WIN-4 — Fenêtre GEM** (p.18) : déplaçable par la barre de titre, redimensionnable (grow box), plein écran (full box), barres de défilement avec flèches et glissière. Code : une fenêtre plein écran fixe (DrawEditor/GemTitleBar) ; case de fermeture = quitter ; case « full » dessinée mais sans effet ; barre de défilement verticale : le clic sur la zone grise positionne directement TopL (au lieu de défiler d'une page) ; pas de glisser de la glissière. Gravité : mineur. Taille : M.

**G-WIN-5 — Includes lus depuis les autres fenêtres** (p.48) : assemblage en lisant les includes déjà chargés ; en cas d'erreur dans un include, passage automatique à la bonne fenêtre. Code : AssembleSource(MainFileName, Ed, EdN) lit les includes sur disque ; l'erreur dans un include affiche le nom de fichier dans l'alerte (JumpToError) sans ouvrir le fichier. Gravité : important. Taille : M (après G-WIN-1).

**G-WIN-6 — Titre de fenêtre** : nom du fichier ✓ ; fenêtre « New » sans titre (code : `AppTitle`). Gravité : mineur.

### 3.9 Ligne d'état et messages

**G-MSG-1 — Ligne d'état d'erreur + bip**
- Manuel (p.18, 20, 22, 24, 27) : la ligne d'état affiche Line/Col/mémoire libre et sert aux messages d'erreur, « usually accompanied by a ping noise » ; le message est effacé à la frappe suivante. Textes : **Top of file** (curseur haut en première ligne), **End of file** (curseur bas en dernière ligne ; Goto d'une ligne inexistante), **Not found**, **What blocks!** (Save block sans bloc — le brief écrit « What block! » ; l'OCR v3 ET v2 donnent « What blocks! », donc probablement exact), **Invalid block!** (début après fin lors d'un Save block ; copie d'un bloc dans lui-même), nombre de remplacements après Replace All interrompu.
- Code : aucun mécanisme de message dans la ligne d'état (InfoText = `Line: n Col: n Mem: n`, plus « modified » et « OVR ») ; aucun de ces textes sauf « Not found » (en alerte modale, 3 langues) ; Top/End of file ne produisent rien ; pas de bip.
- Gravité : important. Taille : M (variable `StatusMsg` effacée à la prochaine touche, dessinée dans DrawEditor ; bip via le haut-parleur hôte).

**G-MSG-2 — Message d'erreur d'assemblage dans la ligne d'état** (p.48, 53) : voir G-PRG-3.

**G-MSG-3 — Format de la ligne d'état** : manuel p.18 : « Line and Column offsets as well as the number of bytes of memory free », initialement 59980 pour 60000 octets (20 octets réservés). Code : `Mem:` = PrefBuf-EdMem-12 → 59988 au démarrage ; libellés `Line:`/`Col:`/`Mem:` non vérifiables (capture d'écran non lisible en OCR). Gravité : mineur. Taille : S.

**G-MSG-4 — Alertes** : les messages du clone (« Out of text memory », « Too many lines », « Block buffer is empty », « Set the block start first ») n'existent pas dans le manuel ; à conserver ou à remplacer par la ligne d'état.

### 3.10 Préférences (Options > Preferences...)

Manuel p.33-37 : dialogue avec Auto-indent lines, Auto-save configuration, Cursor mode numeric keypad, Hide mouse when typing, Make backups, Show matching parentheses, Stop at end of line, Save files on Quit [Yes/No/Ask], Save files on Run Other [Yes/No/Ask], Tab setting (2-16, défaut 8), Text Buffer (4000-999000, défaut 60000), Cursor (Flashing block / Flashing line / Still block / Still line), boutons Load..., Save as..., Reset, OK, Cancel. Cases à cocher (états par défaut non lisibles en OCR, sauf pavé numérique = Cursor).

**G-PREF-1 — Réglages manquants** : Auto-save configuration, Hide mouse, Show matching parentheses, Stop at end of line, Save files on Quit, Save files on Run Other. Code : EditorPrefsDlg (l. 13877) : Tab, Text buffer, Numeric pad (sans effet), Backups, Auto indent, Cursor (Flash|Still), « Load MonST » (option de Devpac 2, absente du v3 qui l'a déplacée dans Resident Tools). Gravité : important (6 réglages). Taille : M.

**G-PREF-2 — Forme du curseur** (p.36) : 4 formes. Code : 2 (clignote/fixe), forme déterminée par Ins (bloc) / écrasement (barre basse). Gravité : mineur. Taille : S.

**G-PREF-3 — Plages et valeurs par défaut** : Tab 2-16 (code 1-32) ; Buffer 4000-999000 (code 4000-1000000) ; défaut 60000 ✓ ; défaut 8 ✓ ; pavé numérique par défaut = Cursor (code : Numbers). Gravité : mineur. Taille : S.

**G-PREF-4 — Changement de taille du tampon** (p.36) : le texte en cours est perdu → confirmation s'il n'est pas sauvé ; le presse-papiers est perdu ; mémoire allouée par fenêtre ; « Help » affiche la mémoire libre (recommandé ≥ 100 Ko pour assembler). Code : valeur appliquée directement, texte conservé, pas de vérification que PrefBuf ≥ EdMem (MemFree peut devenir négatif ; InfoText l'écrête à 0). Gravité : mineur. Taille : S.

**G-PREF-5 — Boutons Load..., Save as..., Reset** (p.36-37) : charger/sauver un fichier de réglages nommé ; Reset = valeurs par défaut. Code : boutons Cancel / Save / OK ; « Save » écrit DEVPAC.INF ; menu « Load preferences » relit DEVPAC.INF (pas de choix de fichier) ; pas de Reset. Gravité : mineur. Taille : S-M.

**G-PREF-6 — « Save preferences » (Options)** (p.36) : sauve éditeur + assembleur + menu Tools + taille du tampon du programme sous HISOFTED.INF. Code : SavePrefs écrit 15 clés (voir 3.11) mais ni menu Tools, ni listing, ni nom de sortie (OptOutName), ni OptListName. Gravité : mineur. Taille : S.

**G-PREF-7 — Auto-save configuration** : absent (voir G-PREF-1).

**G-PREF-8 — Fonts** (Ctrl-G, p.44-45) : TOS Font / GEM Font (Normal / Small / Tiny en haute résolution ; Normal / Small en moyenne) ; Small double le nombre de lignes ; effet persistant après sortie. Code : police fixe 8x10 (LINE_H=10) sur 640x480 ; aucun dialogue. Gravité : mineur. Taille : M-L.

### 3.11 Fichier de configuration

**G-CFG-1 — Nom et emplacement** : manuel p.36-37 : HISOFTED.INF, cherché d'abord dans le répertoire courant (dossier du fichier double-cliqué) puis dans le PATH GEMDOS/AES ; rangé au même endroit à la sauvegarde, sinon dans le répertoire courant ; chargé au démarrage ; un fichier nommé autrement doit être chargé explicitement (v2 : GENST2.INF). Code : `DEVPAC.INF` dans le répertoire de travail uniquement (SavePrefs/LoadPrefs, l. 13817/13843), format texte `CLE=valeur` (TAB, BUFFER, NUMPAD, BACKUP, INDENT, CURSOR, LOADMON, TODISK, DEBUG, LISTING, OPTIMIZE, CASE, RUNGEM, ACC, INCPATH). Gravité : mineur (le format binaire d'origine n'a pas à être reproduit). Taille : S.

**G-CFG-2 — Contenu sauvegardé** : manuel p.36-37, 50, 54 : réglages éditeur, assembleur (tous les dialogues), menu Tools, Run with GEM, Run Directory, Resident, répertoire courant. Code : voir ci-dessus ; manquent OptOutName, OptListName, OptWarnings, OptTabSize, outils, répertoire de run, répertoire courant, dernier Run Other. Gravité : mineur. Taille : S.

**G-CFG-3 — Chargement automatique silencieux** ✓ (LoadPrefs ignore l'absence de fichier).

**G-CFG-4 — Pas de borne sur les valeurs lues** : TAB et BUFFER sont écrêtés, NUMPAD/BACKUP/INDENT/CURSOR non (valeurs hors 0-1 possibles). Gravité : mineur. Taille : S.

### 3.12 Menu Tools, Run Other, Run with Shell, Path, Environment

**G-TOOL-1 — Menu Tools** (p.37-38) : jusqu'à ~20 entrées (« Tool 1 »...), exécutées par clic ou Alt + touche du pavé numérique ; configuration par Ctrl + clic ou Ctrl-Alt + pavé ; enregistrée dans l'INF. L'INF livré pré-configure les outils Devpac. Code : absent. Gravité : important. Taille : L. (Nombre exact d'outils : l'OCR liste « Tool 1 … Tool 20 », en partie illisible.)

**G-TOOL-2 — Dialogue de configuration d'outil** (p.38-41) : Tool number, Menu entry, Command line [None | Prompt | As shown] + ligne de commande, Directory [Tool's | Top window | Current], Save files [No | Yes (défaut) | Ask...], Path + bouton FSel, Pause on return, Report all errors, Run as TOS / Run as GEM (boutons radio), Make resident. Gravité : important. Taille : L (dépend des widgets G-DLG).

**G-TOOL-3 — Run Other (Alt-0)** (p.41-42) : avertit si la source n'est pas sauvée (selon « Save files on Run Other »), sélecteur de fichier, invite de ligne de commande pour .TOS/.TTP, expansion `%.` (nom complet du fichier édité), `%?` (nom sans extension), `%%` (un %). Code : CmdRunOther (l. 14680) : dialogue Programme + Ligne de commande + bouton Choisir (^O dans le menu Program) ; pas d'expansion des méta-caractères ; pas de sauvegarde préalable. Gravité : important. Taille : S-M.

**G-TOOL-4 — Run with Shell (Shift-Alt-0)** (p.42) : exécute une ligne de commande via le vecteur `_shell_p` s'il existe, sinon recherche dans la variable d'environnement PATH (réglable dans Options > Environment). Code : absent. Gravité : mineur (le monde émulé n'a pas de shell). Taille : M.

**G-TOOL-5 — Chemins (Current directory, GEMDOS path, AES path)** (p.43-44) : trois chemins gérés par l'éditeur. Code : pas de notion de répertoire courant éditeur (voir G-FILE-8), pas de PATH émulé côté éditeur. Gravité : mineur. Taille : M.

**G-TOOL-6 — Environment...** (p.44) : fenêtre d'édition des variables d'environnement utilisées par les outils (PATH, CLINKWITH, LIBS...). Code : absent. Gravité : mineur. Taille : M.

### 3.13 Programme : Assemble, Check, Output Symbols, Run, Debug, Mon, Directory, erreurs

**G-PRG-1 — Check (Alt-Y)** (p.48, 61) : comme Assemble mais sans sortie ; légèrement plus rapide. Code : absent. Gravité : important. Taille : S (appel de AssembleSource avec sortie désactivée).

**G-PRG-2 — Output Symbols** (p.48, 61) : produit un fichier .GS (table de symboles pré-assemblée) à partir d'un include ; le contenu ne peut avoir que macros et constantes. Code : absent (OptSymbols existe dans p02 mais n'est pas utilisé comme sortie .GS ; pas de « Pre-assembled includes »). Gravité : mineur (optimisation). Taille : L.

**G-PRG-3 — Comportement après assemblage / erreurs**
- Manuel (p.48, 53-54) : après Assemble, en cas d'erreur « the editor will go to the first erroneous line and display the error message in the status bar » ; Alt-J = erreur suivante (change de fenêtre si besoin) ; Ctrl-J = précédente ; Shift-Alt-U (OCR douteux, probablement Shift-Alt-J) = prochaine erreur après le curseur dans la fenêtre courante ; Alt-T puis Shift-Alt-J = première erreur du fichier ; les insertions/suppressions sont prises en compte automatiquement ; mémorisation limitée ; « Shift - Shift » interrompt un assemblage ; message possiblement détecté plus loin que la ligne réelle ; erreurs multiples.
- Code : DoAssemble (l. 14564) affiche l'écran texte du compte rendu (ShowTextScreen(True)) puis JumpToError ouvre une ALERTE modale (message + ligne) ; JumpToError cycle 1..AsmErrors via ErrJump ; numéros de lignes figés (ErrLn[]) donc faux après modification ; pas d'erreur précédente ; pas de Shift-Alt-J ; pas d'interruption par Shift-Shift ; MAXERR = 100.
- Gravité : important. Taille : M.

**G-PRG-4 — Assemble : compte rendu** : manuel p.47-48 (pas de précision sur l'affichage des passes ; texte OCR). Code : l'écran texte « Press any key » après Assemble est un choix du clone. Gravité : mineur. Taille : S.

**G-PRG-5 — Run (Alt-X)** (p.49) : lance le programme assemblé en mémoire ; refusé si l'assemblage ne s'est pas terminé normalement ; permis avec des erreurs non fatales (ex. symboles non définis) « at your own risk ». Code : CmdRun exécute DoAssemble puis RunProgramGUI seulement si AssembleSource a renvoyé vrai (zéro erreur ET fichier produit) ; les symboles non définis étant des erreurs (p02 l.674), l'exécution est refusée. (À vérifier : dans GenST, « undefined symbol » est-il une erreur ou un avertissement ?) Gravité : mineur. Taille : S.

**G-PRG-6 — Run Directory** (p.50) : Program > Directory > Current / Top Window : répertoire passé aux programmes lancés. Code : absent. Gravité : mineur. Taille : S-M.

**G-PRG-7 — Debug / Mon** (p.50) : Debug lance Mon avec les infos de débogage ; Mon l'invoque instantanément ; retour à l'éditeur à la sortie. Code : CmdDebug force OptDebug=True et appelle RunMonitor ✓ ; CmdMonitor (Alt-M seulement via `256+50` ; menu « MonST|AltM ») ✓. Écran selon « Run with GEM » ✓. Gravité : — (conforme).

**G-PRG-8 — Run with GEM** (p.49) : coche = mode GEM, mémorisé dans les préférences. Code : ✓ (OptRunGem, coche, clé RUNGEM) ; raccourci ^K au lieu de Alt-K. En mode Amiga libellé « Run as CLI ».

**G-PRG-9 — Mise en garde « mouse in menu bar »** (p.49) : sans objet pour le clone.

### 3.14 Options de débogage (Mon) intégrées à l'éditeur

**G-DBG-1 — Dialogue « Debugger options »** (p.51-53) : Auto '@'/'_' prefix labels, Auto-load source, Display 'ZAn' in disassembly, Enable timed screen switching, Follow TRAPs, Ignore cartridge area, Ignore label case, Interpret relative offsets, Symbol significance (défaut 22), Source line numbers [None/Dec/Hex], Start at label. Code : l'item de menu « Debugger options... » ouvre RunOptionsDlg (GEM + Accessories), qui n'a aucun de ces réglages ; aucun de ces réglages n'existe dans p12 (recherche négative sur follow/ignore/significance/prefix). Gravité : important (item de menu trompeur) ; le contenu relève de l'analyse du moniteur. Taille : M. À court terme : renommer l'item « Run options... ».

**G-DBG-2 — Resident Tools** (p.54) : cases Assembler / Debugger (précharger en mémoire). Code : sans objet pour une application unique ; seule l'ancienne option « Load MonST » (PrefLoadMon, sans effet). Gravité : mineur.

### 3.15 Dialogues d'options de l'assembleur (Options > Control / Listing / Options / Optimisations)

Manuel p.55-60 (chap. 3 « From the Editor »). Code : un seul dialogue AsmOptionsDlg (l. 13912) : Output Memory/Disk, Debug info Yes/No, Listing Yes/No, Optimise Yes/No, Symbols Case/Any, Include dir (1 chemin), Output file.

**G-ASM-1 — Control** : Ignore multiple includes, Low memory assembly, No warnings, Debug symbols [None/Normal/Exports], Line debug [None/Standard/Compressed], Format [Atari executable / GST / DRI / Lattice / S-records / RAM...] + Buffer size, liste « EQU symbols » (`label=value`, 1 par défaut), liste « INCLUDE directories », liste « Pre-assembled includes », Output (nom). Code : Output Memory/Disk (≈ Format RAM vs exécutable), Debug Yes/No (≈ Debug symbols Normal/None), Include dir unique, Output file ✓. `OptWarnings` existe (OPT W) mais pas dans le dialogue ; la ligne de commande /DEF:n=v remplit PreDefs (10 max) sans passer par un écran. Gravité : important/mineur selon l'élément. Taille : M.

**G-ASM-2 — Listing** : popup None/Screen/Printer/Disk, List to, Tab size, First pass listing, List macro expansions, List conditionals only, List symbol table. Code : Listing Yes/No ; OptListName (« List to ») et OptTabSize existent dans p02/p05 mais sans dialogue ; les autres options (macro, conditionals, symbol table) : PrintSymbols est toujours appelé. Gravité : mineur. Taille : M.

**G-ASM-3 — Options (processeur et cases OPT)** : Processor (68000/68010/68020/68030/68040/68332), 68881/2, 68851, Default branch size (Word par défaut), Symbol significance (8-127, défaut 127), Case insensitive labels, AUTOPC, ALLOWZERO, BDW, CHKIMM, CHKBIT, CHKPC, NOEVEN, NOTYPE, USER, ODL, LOCALU. Code : seul « Symbols Case/Any » (OPT C). L'assembleur (GenST 68000) ne gère pas ces options ; dialogue inutile tant que le moteur ne les supporte pas. Gravité : mineur (hors périmètre GenST 2). Taille : L (moteur + dialogue).

**G-ASM-4 — Optimisations** : 10 lignes à trois états Y/W/N (ADDA/SUBA→LEA, ADD/SUB→ADDQ/SUBQ, branches arrière/avant, déplacements de base/indirects/externes, LEA→ADDQ/SUBQ, MOVEA.L→MOVEA.W, MOVE.L→MOVEQ, branches nulles→NOP). Code : un seul booléen « Optimise » (OPT O). Gravité : mineur. Taille : L.

**G-ASM-5 — Raccourci d'assemblage** : Alt-A (voir G-KEY-1) ; ^A dans le clone.

**G-ASM-6 — Messages** : « Program buffer full » / « Out of memory » (p.48) sans objet pour le clone (pas de tampon programme) ; documenter l'absence.

### 3.16 Dialogues, pop-up, widgets

**G-DLG-1 — Cases à cocher, pop-up, listes** (p.14-17) : boutons de sortie (bouton par défaut à bordure épaisse ✓), boutons radio, champs de texte (ligne pointillée, curseur « | »), cases à cocher (croix), pop-up (appui prolongé, relâcher dehors = annuler), listes à boutons Add/Remove (double-clic = éditer, glisser = réordonner). Code (DlgAdd, DlgRun, p10) : DK_LABEL/EDIT/RADIO/BUTTON/BOXED/ICON/HLINE seulement ; les Oui/Non sont rendus par des radios. Gravité : important (nécessaire aux dialogues des chap. 2 et 3). Taille : L.

**G-DLG-2 — Clavier dans les dialogues** : Return = bouton par défaut ✓ ; Alt-première lettre = bouton non par défaut (absent) ; Esc = VIDE le champ en cours (code : Esc ferme le dialogue = Cancel) ; Backspace/Delete/flèches pour corriger (code : Backspace efface le dernier caractère ; Delete vide TOUT le champ ; pas de ←/→ ni insertion en milieu de champ ; texte uniquement ajouté à la fin) ; Tab / ↑ ↓ entre champs ✓ (Shift-Tab ✓). Gravité : important. Taille : M.

**G-DLG-3 — Champs filtrés** (p.15) : Goto n'accepte que des chiffres. Code : InputDlg sans filtre. Gravité : mineur. Taille : S.

**G-DLG-4 — Shift-Ins dans les dialogues** : table ASCII (p.46). Absent. Gravité : mineur. Taille : M (voir G-MISC-1).

**G-DLG-5 — Alertes** : AlertBox ✓ (icônes !, ?, stop ; boutons jusqu'à 4 ; Esc = Cancel). Les touches de raccourci Alt-lettre manquent.

**G-DLG-6 — Sélecteur de fichiers** : le manuel utilise le sélecteur GEM natif (p.29, 31) avec lecteur, dossier, masque, nom ; le clone a un sélecteur maison (FileSelect, l. 7459) : liste, double-clic, « .. », saisie de la sélection, OK/Annuler ; pas de choix de lecteur ni de masque modifiable, pas de création de dossier. Gravité : mineur. Taille : M.

**G-DLG-7 — Message d'erreur de lecture** : « Cannot open file » ; pour le chargement d'un fichier absent le manuel propose la création (G-FILE-2).

### 3.17 Divers : About, ASCII Table, Help, Fonts, accessoires

**G-MISC-1 — ASCII Table...** (p.45-46) : pop-up à la position de la souris montrant tout le jeu de 256 caractères ; clic = insertion au curseur ; Shift-Insert au clavier (aussi dans les dialogues) ; caractères perturbants grisés. Code : absent. Gravité : mineur. Taille : M.

**G-MISC-2 — About Devpac-3...** (p.45) : version, mémoire libre et mémoire utilisée par programmes résidents et textes ouverts (liste des fichiers avec tailles), mémoire système/alternative libre ; Return/OK. Code : CmdAbout : titre du clone, auteur, URL, mode Atari ST/Amiga ; la mémoire est dans « Memory... » (CmdMemory : tampon texte, utilisé, libre, lignes, RAM émulée). Gravité : mineur. Taille : S.

**G-MISC-3 — Help (touche Help ou Alt-H)** (p.46) : boîte montrant les touches curseur et fonction ainsi que la mémoire système libre. Code : CmdHelp (F1 / Desk > Help) : alerte listant ^N ^L ^S... qui décrit les touches du clone, pas celles du manuel. Gravité : mineur. Taille : S (à refaire quand les touches seront alignées).

**G-MISC-4 — Fonts (Ctrl-G)** : voir G-PREF-8.

**G-MISC-5 — Accessoires de bureau** (p.46) : menu Desk liste les accessoires ; fenêtres d'accessoires au-dessus de l'éditeur ; le curseur ne clignote et les menus ne marchent que si une fenêtre éditeur est au premier plan. Code : sans objet côté éditeur (voir G-MENU-5). Gravité : mineur.

**G-MISC-6 — Install Application** (p.46-47) : configuration du Bureau ; sans objet pour le clone (association .S côté système hôte).

### 3.18 Souris

**G-MOUSE-1 — Placement du curseur et sélection** ✓ (clic, glisser).
**G-MOUSE-2 — Double-clic = mot, glisser par mot, clic dans la marge gauche = glisser par ligne** (p.23) : absents (MouseDown, l. 15014 : pas de test de double-clic dans l'éditeur ; seul FileSelect en a un). Gravité : mineur. Taille : M.
**G-MOUSE-3 — Barres de défilement** (p.18-20) : clic zone grise haute/basse = page ; flèches = ligne/caractère ; glissière déplaçable. Code : flèches ✓ ; zone grise verticale = saut proportionnel (au lieu d'une page) ; horizontale : demi-largeur ✓ ; pas de glisser de la glissière. Gravité : mineur. Taille : S-M.
**G-MOUSE-4 — Défilement automatique en glissant au-delà du bord** (p.23) : partiel. Gravité : mineur. Taille : S.
**G-MOUSE-5 — Masquage du pointeur à la frappe** (p.34) : absent (voir G-PREF-1). Gravité : mineur.

### 3.19 Ligne de commande et démarrage

**G-CLI-1** : manuel p.30 : jusqu'à 7 fichiers chargés en 7 fenêtres, proposition de création. Code : voir G-FILE-10. Options propres du clone (/A /X /D /M /B /L /S /O /OUT /INC /DEF /NODISK /FLx /NOGEM) non décrites par le manuel (Devpac 3 : options de GEN.TTP -B -C -D -E -H -I -L -M -O, p.62 ; hors périmètre éditeur).

---

## 4. Éléments conformes ou équivalents (pour mémoire)

- Ligne d'état Line/Col/mémoire libre en haut de fenêtre ; nom du fichier dans la barre de titre.
- Touche Tab = octet #9, alignement sur multiple de PrefTab, suppression qui referme la ligne.
- Backspace en début de ligne joint à la précédente ; Auto-indent par copie des blancs initiaux.
- Backups `.BAK` à la sauvegarde (renommage, suppression de l'ancien .BAK), activés par préférence.
- Sauvegarde/chargement CR+LF ; Save sans nom → sélecteur ; confirmation à la fermeture/au New (simplifiée).
- Run with GEM avec coche, mémorisé dans l'INF ; Debug force les symboles ; Mon accessible instantanément (Alt-M).
- Éléments de menu grisés selon le contexte (bloc, presse-papiers, chaîne de recherche, erreurs).
- Bouton par défaut à bordure épaisse, Return = défaut, Tab/↑/↓ entre champs, radios, alertes à icônes.
- Fonction de sélecteur de fichiers avec double-clic et dossiers.

## 5. Points d'OCR douteux

- Raccourci du menu Program « Debug » (OCR « ap »/« 5X ») : probablement Alt-D (v2 le confirme, p. v2.txt l.1378).
- « Shift-Alt-U » (p.53) dans la phrase « Shift-Alt-U command which finds the next error after the cursor » vs « Shift-Alt-J » deux lignes plus bas : une des deux est une erreur d'OCR ; très probablement Shift-Alt-J partout.
- « What blocks! » : le brief écrit « What block! » ; l'OCR v2 et v3 donnent tous deux « What blocks! » (v2 : « What blocks ! »).
- « Control-@ » (supprimer jusqu'en fin de ligne) : l'OCR v2 donne « trl-4 », v3 « Control-@ » ; retenu Ctrl-@ (code 0).
- Libellés des items du menu Edit (« Cut oS », « Paste F5 », « Goto Top 8T ») : raccourcis lisibles seulement en partie ; Cut/Copy/Paste sans raccourci Alt confirmé par le texte (ils renvoient aux commandes de bloc).
- Nombre d'outils du menu Tools (liste « Tool 1..Tool 20 » partiellement lisible) et raccourcis Alt+pavé : à vérifier sur la capture d'origine.
- États par défaut des cases du dialogue Preferences : non lisibles (seul le pavé numérique = Cursor, tab = 8, buffer = 60000 sont indiqués dans le texte).

## 6. Remarque sur le périmètre

Le clone se présente comme « GenST 2.00 / MonST » (VERSION_TEXT='2.00'). Plusieurs écarts du chapitre 3 (68020+, optimisations détaillées, formats GST/DRI/Lattice, HCLN, pré-assemblage .GS) relèvent de Devpac 3 et dépendent du moteur d'assemblage, pas seulement de l'interface ; ils sont classés « mineur » ici. Les écarts d'interface (touches, menus, blocs, messages, dialogues, multi-fenêtre) s'appliquent aux deux versions du manuel (v2 et v3 partagent la plupart des commandes d'édition : Alt-lettre, F1-F5, Ctrl-Y/U, Shift-F5).
