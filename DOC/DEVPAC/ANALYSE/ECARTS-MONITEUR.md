# Rapport d'écarts : chapitre 4 « The Debugger » (Mon) du manuel Devpac 3 contre le MONITEUR de DEVPAC.PAS

Sources analysées
- Manuel : pages PDF OCR p151 à p202 (pages imprimées 135 à 186). Attention : le décalage réel est de +16 (imprimé 135 = p151), pas +8 comme indiqué dans BRIEF.md. Les numéros « p. » ci-dessous sont les numéros IMPRIMÉS du manuel. Extrait concaténé : `scratchpad/mon_man.txt`.
- Code : `parts/p12.pas` (498 lignes, MONITEUR), repris dans DEVPAC.PAS lignes 13990-14498 environ (RunMonitor l. 14402, MonExec l. 14328, DrawMonitor l. 14114, MonRunUntil l. 14246, MonStepOver l. 14274, MonTerm l. 14002). Émulateur CPU : p07 (Step, RunCpu l. 5060, RaiseExc l. 4216, Halt68 l. 4151). Désassembleur et table de symboles : p06 (Dis l. 3819, DbgFind l. 3639). Chargement PRG : p09b (LoadPRGImage l. 12798). Clavier : p01 (PollEvent l. 598), p08 (PollKeys l. 5390).
- Conventions : Gravité = bloquant (comportement faux ou impossible à utiliser tel que décrit), important, mineur. Taille = XS (< 20 lignes Pascal), S (20-80), M (80-250), L (> 250).
- Doutes OCR signalés au fil du texte (liste en fin de rapport, section 16).

---------------------------------------------------------------------

## 0. Résumé (15 lignes)

1. Le moniteur actuel (p12) est une console à ligne de commande (« T S G D M B F L X V H Q ? ») sur un écran fixe à 4 zones ; le Mon de Devpac 3 est un débogueur à touches simples (Alt-/Ctrl-lettre, exécution immédiate sans Return) avec 5 fenêtres configurables. Plus de 90 % des commandes du chapitre 4 n'existent pas.
2. Pire : les lettres de commande qui existent ont un sens DIFFÉRENT du manuel (G = Go ici, = Search dans Mon ; B = point d'arrêt ici, = Load Binary dans Mon ; S = step over ici, = Save Binary ; L = Load ici, = List labels ; Q = quit ici, = Query port ; T = trace ici, = Transfer to port ; H = aide ici, = History ; F = fill ici, = Font/inexistant ; X = reload ; ? = évaluation ici, = opérateur source).
3. Bug bloquant : « S » / F8 (step over) et toute exécution « jusqu'à une adresse » (MonRunUntil) ne s'arrêtent PAS à l'adresse cible (seulement testée tous les 20 000 instructions) : le JSR n'est pas enjambé, le programme part en roue libre.
4. Bug bloquant : après une exception (bus/adresse/illégale/division par zéro...) ou une instruction STOP, plus aucune commande d'exécution n'est acceptée (StopReason reste ≠ NONE) : impossible de corriger un registre, sauter l'instruction ou reprendre, alors que tout le § « Exception Analysis » (p. 185-186) suppose de pouvoir le faire. Après une exception, le PC affiché est aussi décalé (CurOpPC+2 ou milieu d'instruction).
5. Bug : un point d'arrêt situé sur l'instruction immédiatement suivante est ignoré par MonRunUntil (le premier Step est suivi d'un RunCpu qui ne teste pas le PC de départ).
6. Points d'arrêt : une seule sorte (adresse permanente, bascule on/off, 16 max). Manquent : simple « une fois » (effacé au déclenchement), stop-n, count, conditionnel (expression), permanent distingué, Ctrl-A, Ctrl-K, Ctrl-D (BDOS), Alt-B avec syntaxe `adresse,spécificateur`, marqueur `[ ]` dans le désassemblage.
7. Expressions : pas de priorité d'opérateurs, ni `<< >> ~ ^ ! = < > <> != <= >=`, ni `\` (décimal ; ici `#` = décimal, ce qui est l'ancienne syntaxe Mon 1 explicitement abandonnée par le manuel), ni indirection `{...}.b/.w/.l` (ici `[..]` long seulement), ni M0-M9, TEXT/DATA/BSS/END, SSP/USP/CCR. Et `=` est capté comme affectation de registre avant toute évaluation : impossible d'écrire une condition `d6&ffff=ffff`.
8. Fenêtres : aucune des notions de fenêtre courante (Tab, Alt-1..5), types (Registres/Désassemblage/Mémoire/Source), Zoom, Split, Widen, vues empilées (Shift-./Shift-,), verrouillage sur expression (Alt-L), Edit view (Alt-E : modification de la mémoire), Font, curseurs de défilement, Esc de rafraîchissement. Il n'existe AUCUNE commande qui modifie la mémoire sauf `F`.
9. Fenêtre registres : manque l'affichage ASCII des Dn, les 6 mots pointés par chaque An + ASCII, la ligne PC avec instruction désassemblée et valeurs d'adresses effectives (`; 00001FAE 0F01`), les registres mémoire M0-M9 (zoom).
10. Fonctions absentes en totalité : historique (H, 5 entrées, remplie par pas/points d'arrêt/exceptions), recherche (G/N : B/W/L/T/I), comparaison (C), copie (I), remplissage W, Query/Transfer port (Q/T), List labels (L), Load/Save binaire/ASCII (B/S/A), Use new executable (E), Preferences (Ctrl-P, MON.INF), Disassemble to printer/disk (P), Show other bases (Alt-O/0), Change drive (D), Run variantes (R : Go/Slowly/Instruction/Until + Watch Y/N), Trace Ctrl-T, Skip Ctrl-S.
11. Débogage symbolique : symboles chargés (tables DRI 8 caractères et extension 22 caractères), recherche linéaire exacte seulement ; pas d'option casse/préfixe `_` `@`/longueur de symbole, pas de `symbole(An)` (Relative offsets), pas de symbole sur la ligne de désassemblage. Aucun support des informations de ligne (OPT LINE / HCLN, que le moteur d'assemblage de DEVPAC.PAS n'émet d'ailleurs pas : DirOpt ne connaît que D, O, C, W, L) donc aucun débogage source.
12. Écran : le « dialogue Mon » (ESC to abort, édition de ligne Alt-x/Shift-flèches/Del) n'existe pas ; saisie par ligne `>` en bas. L'aide F-touches affichée (« F7:Trace F8:Over F9:Run F10:Screen ») n'est pas dans le manuel.
13. Choses qui concordent : registres + flags + mode U/S + masque (partiel), Ctrl-Z = pas, Ctrl-R = go, Ctrl-A (ici step over, DIFFÉRENT), V = écran du programme (touche = retour), la base hexadécimale par défaut et `$`, les registres sans ambiguïté `A5` / `0A5` / `$A5`, le chargement initial « Executable file to load », les traps/line-A traités comme une instruction (comportement par défaut du manuel, p. 168 et 172).
14. N/A ou partiellement N/A pour un émulateur HLE : exceptions de vecteurs « Mon active » (TOS HLE), Shift-Alt-Help, NOTRACE.PRG, AMON/résident, comptes FPU/MMU/68030, écran Control-O (multi-résolution), screen timer, Top of RAM. Section 14 dit lesquelles méritent quand même un équivalent.
15. Plan : 25 corrections ordonnées en section 17, architecture de l'écran à 5 fenêtres dans 640x480 (grille 80x48 cellules de 8x10) en section 18, avec les structures de données.

---------------------------------------------------------------------

## 1. Exceptions (manuel p. 136-137 ; § Exception Analysis p. 185-186)

Format : MON-Ex. Manuel / Code / Gravité / Taille.

### MON-E1  Après une exception, impossible de reprendre ou de corriger l'état
- Manuel (p. 185-186) : « Correcting a register value may be enough to resume execution, at least temporarily » (Address Error) ; « Bumping the PC past the offending instruction is unlikely to be much help » (Privilege) ; Ctrl-S (p. 168) « Skip Instruction ... when you know that this instruction is going to do something it shouldn't ». Mon intercepte l'exception et reste utilisable.
- Code : `Halt68` (p07 l.4151) pose `StopReason:=STOP_FAULT`. Ensuite `MonTraceN` (l.14229) et `MonRunUntil` (l.14246) font : `If (StopReason<>STOP_NONE) And (<>STOP_BREAK) And (<>STOP_TRACE) Then Begin ReportStop; Exit; End;` donc ils ne font que réafficher le message. Idem après STOP (`STOP_STOP`), `STOP_USER`. Seul `X` (recharger) sort de l'impasse. On peut modifier PC (`PC=...`) mais pas relancer.
- Gravité : bloquant (workflow de diagnostic du manuel impossible).
- Taille : XS/S. Dans ReportStop, après avoir imprimé le message, remettre `StopReason:=STOP_NONE` pour FAULT/STOP/USER (sauf STOP_EXIT où le programme est réellement terminé : garder un indicateur `ProgDead`). Pour STOP, avancer PC si nécessaire.

### MON-E2  PC faux après une exception
- Manuel : Mon affiche l'état du processeur au moment de l'exception (le PC empilé dans le cadre d'exception : pour Illegal/Privilege/Line A/F, l'instruction fautive elle-même).
- Code : `Step` avance PC en lisant opcode et opérandes ; `RaiseExc(4)` est précédé de `PC:=CurOpPC+2` (p07 l.644, l.760, l.995), et `Halt68` ne remet jamais PC à `CurOpPC`. Pour Bus/Address error, le PC reste « milieu d'instruction ». Le message contient bien `CurOpPC` mais le panneau Registres affichera un PC différent (ou une instruction suivante).
- Gravité : important (le désassemblage « PC » affiche la mauvaise ligne ; les conseils Illegal instruction « PC très bas, saut à l'adresse 0 » supposent un PC fidèle).
- Taille : XS. Dans `Halt68` ou à l'appel de RaiseExc : `PC:=CurOpPC` pour les vecteurs 2, 3, 4, 8, 10, 11 ; vecteurs 5, 6, 7 : PC de l'instruction suivante (comme le matériel, et afficher ce fait).

### MON-E3  Vecteurs « Mon active : trapped »
- Manuel (tableau p. 136-137) : Mon redirige les vecteurs 2-8, 11-14, 16-24, 32, 35-44, 47+ (« trapped »), 4 = « breakpoint », 9 = single-step, 10 = « VDI support », 33/34/45/46 = appels GEMDOS/AES-VDI/XBIOS/BIOS, 25-31 et 64-255 non interceptés. (Note : sur le tableau OCR, trap #13 = XBIOS et trap #14 = BIOS sont probablement inversés par rapport à TOS réel, où #13 = BIOS et #14 = XBIOS ; erreur du manuel ou de l'OCR, à ne pas recopier.)
- Code : `RaiseExc` (p07 l.171) lit le vecteur en mémoire `Rd32(Vec*4)` : si le programme a installé un gestionnaire (≠ 0 et, pour les vecteurs ≥ 32, ≥ $400), le gestionnaire s'exécute sans que le moniteur n'intervienne ; sinon `Halt68`. Les TRAP #1, #2, #13, #14 et la ligne A sont gérés HLE dans `DoTrap`/`DoLineA`.
- Gravité : mineur (comportement raisonnable pour un TOS HLE). Option utile : un indicateur « piéger tous les vecteurs de 2 à 8 même si le programme a un gestionnaire » (équivalent de Ctrl-E « Re-install Exceptions »), voir MON-X4.
- Taille : S.

### MON-E4  Messages d'exception
- Manuel : types listés p. 185-186 : Bus Error, Address Error, Illegal Instruction, Privilege Violation, Divide by Zero, Floating Point Exceptions. Le tableau p. 136-137 nomme aussi CHK, TRAPV, line 1010/1111, format error, spurious interrupt, TRAP #n, FPCP, MMU.
- Code : `RaiseExc` nomme 2, 3, 4, 5, 6, 7, 8, 11 ; le reste devient « Exception #n ». Bus error donne `BusAddr` et `PC` ; Address error ne donne que `CurOpPC` (l'adresse impaire `BusAddr` est pourtant renseignée dans MemRd/MemWr). Pas de distinction lecture/écriture, ni du mode (user/super).
- Gravité : mineur.
- Taille : XS : ajouter noms pour 9 (Trace), 10 (Line A), 12-14, 24, 32-47 (« TRAP #n »), et l'adresse impaire pour Address error ; afficher « (instruction à $xxxxxx) » conforme à E2.

### MON-E5  Bit Trace (T) du SR ignoré
- Manuel : Mon utilise l'exception Trace (vecteur 9) pour le pas à pas ; les programmes qui positionnent T avec leur propre débogueur ne sont pas décrits. Pas de comportement manuel précis.
- Code : `SetSR` conserve `$A71F` (T inclus) mais `Step` n'en tient pas compte.
- Gravité : mineur ; n'a d'impact que pour du code qui s'auto-trace.
- Taille : S (émettre RaiseExc(9) après chaque instruction si T). Non requis par le manuel.

### MON-E6  Pile de l'exception (68000)
- Manuel (p. 185) : « look at the relevant stack to try and find a return address ». Le débogueur affiche la pile via une fenêtre mémoire verrouillée sur SP (voir MON-W9).
- Code : en cas de Halt68, aucun cadre n'est empilé : la pile contient l'état avant l'instruction. C'est suffisant pour l'analyse « PC dans une zone inexistante ». Rien à faire sauf si l'on met le PC dans une fenêtre mémoire.
- Gravité : mineur. Taille : néant.

### MON-E7  Exceptions 68020+/FPU/MMU
- Manuel : lignes FPCP/MMU du tableau, section « Floating Point Exceptions » p. 186, registres FP/CRP/SRP en expressions.
- Code : CPU strictement 68000 (p07). N/A. À exclure du périmètre ; documenter.

---------------------------------------------------------------------

## 2. Disposition de l'écran (Front Panel) (p. 138-139, 140, 143)

### MON-F1  Front panel à fenêtres numérotées
- Manuel (p. 138-139) : « a number of windows through which you can view the 680x0 registers, a disassembly, source code or memory » ; jusqu'à 5 fenêtres ; fenêtre 1 = registres/mémoire/source/désassemblage ; 2 et 4 = mémoire/désassemblage/source ; 3 et 5 = mémoire seulement ; chaque fenêtre est une pile de vues ; titre de la fenêtre courante en inverse (p. 140) ; plusieurs tailles (split/widen).
- Code : `DrawMonitor` (l.14114) dessine 4 zones fixes : « 1 Registers » (10 rangées), « 2 Disassembled PC » (gauche, 16 rangées), « 3 Memory » (droite, 16 rangées), « 4 Command » (journal de 17 lignes + invite `>`), plus une barre d'aide en bas. Pas de fenêtre 5. La numérotation « 4 Command » n'a pas de sens dans le manuel (la fenêtre 4 est une vue disassembly/memoire/source).
- Gravité : important (c'est l'écran de référence de tout le chapitre).
- Taille : L (voir section 18).

### MON-F2  Titres de fenêtres
- Manuel : « Mon's Windows », titres dans la barre (nom du fichier source pour les fenêtres source, p. 153 ; numéro de vue `2a`, `2b`... p. 157) ; fenêtre courante en inverse (p. 140) ; le titre de la vue 1 du registre porte aussi le mode.
- Code : titres figés `1 Registers`, `2 Disassembled PC`, `3 Memory`, `4 Command   <ProgName>` ; aucune notion de fenêtre courante (toutes les barres sont en inverse via MonBar : fond INK, texte WText).
- Gravité : mineur. Taille : XS dès que MON-F1 existe.

### MON-F3  Ligne de commande et ligne d'état
- Manuel : il n'y a PAS de ligne de commande permanente : les commandes sont des touches simples (p. 142) et les saisies passent par des dialogues (voir section 4). Les messages d'état (« Breakpoint », « Program Terminated ») apparaissent « in the lower window » (p. 143, 161). L'écran ne comporte pas de ligne d'aide.
- Code : journal défilant `MLog` (300 lignes, 17 visibles) avec écho `> commande` ; invite permanente `>` ; ligne d'aide F7/F8/F9/F10 en bas. L'« echo » des messages est utile et peut être conservé dans une fenêtre message/zone de statut (voir 18).
- Gravité : important (modèle d'interaction différent). Taille : M (liée à MON-C1).

### MON-F4  Registres et lignes pointées
- Manuel (p. 150, 152) : Dn en hex + ASCII de leurs 4 octets ; An en hex + dump hexa de la mémoire pointée (alignée mot ou octet, `**` si illisible) + ASCII ; SR en hex et en drapeaux, avec U/S ; PC + désassemblage de l'instruction courante, avec adresses effectives en hex et mémoire pointée de taille adaptée (ex. `tst.l $12A(a3) ;00001FAE 0F01`, `move.w $12A(a3),-(sp) ;00001FAE 0F01 > 0002AC08 FFFF`, MOVEM = quad-mot, pré-décrément pris en compte) ; ensuite registres FP, SSP, et registres mémoire de Mon (zoom).
- Code (l.14123-14143) : Dn : `D0:00000000 xxxx xxxx xxxx xxxx` où les 4 mots sont lus À L'ADRESSE contenue dans Dn (pas l'ASCII du registre) : écart de nature. An : adresse + 4 mots pointés, pas d'ASCII ; une seule ligne `SR:xxxx XNZVC 0n Mode: User/Super` (plutôt complet) ; PC : `PC:xxxxxxxx Instr:<compteur>`, sans désassemblage de l'instruction ni EA. `ClrErr` après la lecture pour supprimer les bus errors du dump (bien).
- Gravité : important. Taille : M (calcul d'EA : réutiliser `Dis`/`DEA` p06 pour produire la liste des EA ; la mise en forme `; srcEA data > dstEA data` demande une variante du désassembleur qui expose les EA).

### MON-F5  Instruction courante dans la fenêtre registres
- Cf. F4. Code : l'instruction n'est visible que dans la zone 2 (qui est calée sur MonDisAddr). Gravité : important. Taille : M.

### MON-F6  Taille de police et résolutions
- Manuel (p. 155, 160) : polices 8 et 16 pixels (8 et 6 en basse résolution), Alt-F, Control-O change de résolution.
- Code : police BGI 8x8 fixe, `MROW = 10`. L'hôte est en 640x480 (SCR_W/SCR_H, p01 l.94-95) ; l'écran ST émulé fait 640x400 (EMU_Y0 = 40). Gravité : mineur. Taille : S (deux tailles de cellules 8x10 et 8x16 via deux jeux de hauteurs ; pas de colour ST).

---------------------------------------------------------------------

## 3. Débogage symbolique (p. 140-141, 146, 151-152, 173-175)

### MON-S1  Chargement des symboles
- Manuel : symboles lus dans la section symboles standard du fichier exécutable (DRI, 8 caractères) et dans l'extension HiSoft (22 caractères) ; 22 caractères significatifs, réglable à 8 (Preferences) ; insensible à la casse par défaut (Ignore case), option `_`/`@` automatique (Auto prefix) ; « Start at label » (p. 174).
- Code : `LoadPRGImage` (p09b l.12798) lit la table (14 octets/symbole, extension type `$0048` + 14 caractères = 22) ; `DbgAdd` tronque à 24 caractères, table limitée à `MAXDBG = 3000` (au-delà, les symboles sont silencieusement ignorés). Hunk (AmigaOS) : symboles via `HAddr`/`DbgAdd` (autre chemin). `DbgByName` est TOUJOURS insensible à la casse. Pas d'options de casse/préfixe/longueur.
- Gravité : mineur (le fonctionnement par défaut est celui du manuel). Taille : S pour les options (3 booléens + longueur). Pour MAXDBG : prévenir au chargement si dépassement (XS) ou passer à une table dynamique (S).
- Test à faire à l'exécution : un programme avec > 3000 symboles (ex. gros module C) ; vérifié par lecture seulement.

### MON-S2  Recherche de symboles par adresse
- Manuel : le désassemblage affiche « the hex address, followed by any symbol, then the disassembly » (p. 151) ; `Relative offsets` (p. 174) : pour `xxx(An)` la valeur courante de An est ajoutée à l'offset puis recherchée dans la table (`symbole(An)`).
- Code : `DbgFind` (p06 l.3639) : parcours linéaire, correspondance EXACTE d'adresse uniquement (pas de `symbole+offset`), appelé pour absolu/PC-relatif/branchements (`SymOrHex`) mais jamais avec la valeur de An (aucune option Relative offsets). La colonne « symbole » est absente de `DrawMonitor` : la variable `Lbl` contient en fait le désassemblage et non un label. Les noms de labels de début de ligne ne s'affichent donc pas.
- Gravité : important (c'est ce qui rend le désassemblage lisible). Taille : S (afficher `DbgFind(A)` en tête de ligne ; Relative offsets : `Dis` doit pouvoir lire Rg[] ; indexation par tri + dichotomie pour la vitesse, 3000 × 16 lignes à chaque frappe = 48 000 comparaisons de chaînes par rafraîchissement, acceptable).

### MON-S3  Informations de ligne (débogage source)
- Manuel (p. 141, 146-147, 153) : lignes LINE / HCLN attachées au programme (Devpac 3, HiSoft BASIC 2, Lattice C 5.5) ; fenêtre source ; opérateurs `#` (n° de ligne → adresse) et `?` (adresse → n° de ligne) ; Set Breakpoint / Run Until / Lock Window au niveau source ; pas à pas ligne par ligne ; source chargé automatiquement (Auto load source file).
- Code : rien. Dans l'assembleur, `DirOpt` (p04 l.2765) ne traite que `D`, `O`, `C`, `W`, `L` ; `OPT XDEBUG`, `OPT LINE`, `OPT HCLN` (manuel Gen p. 119) ne sont ni reconnus ni émis ; `WritePRG` (p05) n'écrit que la table de symboles DRI.
- Gravité : important pour la fidélité Devpac 3, mais dépend de l'assembleur : nécessite d'émettre le bloc LINE ou HCLN (format non décrit dans les pages lues du manuel, p. 119 ne donne que la taille : 8 octets/ligne pour LINE, ~2 pour HCLN → format à retrouver ailleurs ou à définir). À traiter en dernier.
- Taille : L (assembleur) + M (moniteur : fenêtre source, # et ?).

### MON-S4  Commandes symboliques
- E « Executable file to use » (p. 167) : charge seulement symboles et lignes d'un exécutable (désactivé pour les accessoires), avec adresse de segment texte facultative. Code : absent. Gravité : mineur (utile seulement pour accessoires/overlays). Taille : S.
- L « List Labels » (p. 176) : liste paginée de tous les symboles (touche = page suivante, Esc annule). Code : `L` = Load. Gravité : important (confusion de commande + fonction manquante). Taille : S.

---------------------------------------------------------------------

## 4. Dialogues Mon et saisie des commandes (p. 141-142)

### MON-C1  Commandes à touche unique, Alt/Ctrl
- Manuel (p. 142) : « Mon is controlled by single-key commands » ; « Alt- key is the window key » ; « Control key ... connected with execution » ; majuscules et minuscules équivalentes ; « Commands take effect immediately - there is no need to press Return and invalid commands are simply ignored » ; les commandes potentiellement destructrices exigent Ctrl.
- Code : `RunMonitor` (l.14402) : boucle `PollEvent`, caractères imprimables (32..255) ajoutés à `MonCmd` (70 car. max), Return exécute `MonExec`. Touches directes : F1 (aide), F7 et Ctrl-Z (26) = pas, F8 et Ctrl-A (1) = step over, F9 et Ctrl-R (18) = go, F10 = écran programme, Ctrl-Q (17) = quitter, Haut = rappel de la dernière ligne, Backspace, Esc vide la ligne. Les touches Alt (codes `256+scan`, cf. `AltScan` p01 l.138) ne sont pas décodées dans le moniteur ; le code Ctrl-C (3) est ignoré dans la boucle moniteur (et n'a donc pas la sémantique « terminate process » du manuel). Les chiffres/lettres tapés alimentent la ligne de commande plutôt que de déclencher une action.
- Gravité : important. Taille : M (table de dispatch clavier ; voir MON-Q1 dans 18).

### MON-C2  Collisions de lettres avec les commandes du manuel (même sans Alt/Ctrl)
Le manuel utilise des lettres seules (sans modificateur) pour : A (Load ASCII), B (Load Binary), C (Compare), D (Change drive), E (Use new executable), G (Search), H (History), I (Intelligent copy), L (List labels), M (Modify address), N (Find next), P (Disassemble to printer/disk), Q (Query port), R (Run various), S (Save Binary), T (Transfer to port), U (Run Until), V (View screen), W (Fill), 0 (Show other bases), `.` `,` (vue suivante/précédente), Help (aide + points d'arrêt).
Code : G = go, B = bascule point d'arrêt, S = step over, T = trace, L = load, X = reload, Q = quit, H = aide, ? = évaluer, F = fill, D = désassembler à une adresse, M = mémoire à une adresse (D et M sont équivalents à Alt-A/M du manuel, ce qui est cohérent pour M seulement ; D devrait être « Change Drive & Directory »).
- Gravité : important (l'ensemble du chapitre ne peut être suivi sans respecter ces affectations).
- Taille : M ; renommer les commandes (G, B, S, T, L, Q, H, F, X, ?), supprimer ou déplacer l'ancienne syntaxe en commandes « étendues » (voir MON-C3).

### MON-C3  Conserver la ligne de commande ?
- Proposition (hors manuel) : on peut conserver une ligne de commande « étendue » (touche `:` ou Ctrl-X) pour les habitués (hex/`?`/affectations), avec les anciennes commandes, afin de ne pas perdre `BL/BC` ou `F` ; non exigé par le manuel. Gravité : mineur.

### MON-C4  Dialogues Mon
- Manuel (p. 141) : dialogue = boîte avec « ESC to abort » au-dessus du coin supérieur gauche, une invite, une ligne éditable avec curseur ; touches : flèches gauche/droite ; Shift-flèches début/fin de ligne ; Backspace ; Del ; Alt-x efface la ligne (OCR « Alt-x » : probablement Alt-X) ; Esc abandonne ; Return valide ; si l'expression est invalide « the screen will flash and the Return key will be ignored » (correction sur place) ; dialogues d'erreur « Return » (se ferment sur Return ou Esc).
- Code : aucun dialogue Mon. L'invite initiale « Executable file to load » appelle `InputDlg` (p10 l.343), widget hôte standard (boutons souris) et non un dialogue Mon ; les erreurs vont dans le journal, sans flash ni correction in situ (la ligne `>` est vidée à Return, donc une expression erronée oblige à retaper).
- Gravité : important. Taille : S (une procédure `MonPrompt(Titre: String; Var S: String; Maxlen): Boolean` qui boucle sur `PollEvent`, dessine une boîte, gère l'historique de la dernière saisie par prompt, et accepte un validateur d'expression ; un `MonAlert(Msg)` pour les erreurs).

### MON-C5  Historique de la ligne de commande
- Manuel : aucun rappel de ligne n'est décrit. Code : touche Haut rappelle UNE ligne (`MonCmdHist`). Gravité : néant (extension). L'historique « History » du manuel est une autre chose (voir section 10).

---------------------------------------------------------------------

## 5. Commandes et touches : couverture exhaustive (tableau p. 180-181 + corps du chapitre)

Légende : OK = comportement conforme ; ≠ = existe mais autre sens ; NON = absent. Le champ « Taille » correspond à l'ajout dans l'architecture de la section 18.

### 5.1 Fenêtres (Alt-, Tab, Shift-, ., ,)
| Touche (manuel, page) | Fonction | Code actuel | Gravité | Taille |
|---|---|---|---|---|
| Tab, Alt-1..5 (p. 140) | choisir fenêtre courante | NON | important | S |
| Alt-A ou M (p. 154) | Set Address (expression) | `M expr` / `D expr` (adresse de la zone, pas de fenêtre courante) ≠ | important | S |
| Alt-E (p. 154) | Edit View : édition hex/ASCII de la mémoire (Tab bascule, Esc quitte) ; sur registres = Alt-R ; source = tabulation 4/8 | NON (aucune commande ne modifie la mémoire, hors `F`) | bloquant pour modifier des données | M |
| Alt-F (p. 155) | taille de police (affiche aussi les registres flottants) | NON | mineur | S |
| Alt-G (p. 155) | Goto source line | NON (pas de source) | mineur | S |
| Alt-L (p. 155) | Lock to expression (adresse de départ recalculée après chaque exception ; verrouillage possible sur M2, {m2} ...) ; chaîne vide = déverrouiller | NON | important | M |
| Alt-P (p. 156) | Print window (imprimante ou fichier ; Esc abandonne) | NON (une imprimante hôte existe : `PrnPut` p09d écrit `PRINTER.OUT`) | mineur | S |
| Alt-S (p. 156) | Split window (vertical, sans effet sur la fenêtre 1) | NON | mineur | S |
| Alt-T (p. 156) | changer le type (fenêtres 1, 2, 4) | NON | important | S |
| Alt-W (p. 156) | Widen window (sans effet sur la fenêtre 1) | NON | mineur | S |
| Alt-Z (p. 157) | Zoom (Esc ou Alt-Z pour revenir) ; registres zoomés = registres supplémentaires + M0-M9 | NON | important | S |
| Ctrl-flèche haut/bas (p. 155, 180 ; OCR : « Control-< and Control-— ») | réduire/agrandir la hauteur de la fenêtre registres | NON | mineur | XS |
| Shift-. / Shift-, (p. 157-158) | Open View / Close View (empile une vue ; numérotation 2a, 2b ... ; Close View décharge le source) | NON | important | M |
| `.` / `,` (p. 158) | vue suivante / précédente (circulaire) | NON | important | S |
| Esc (p. 158) | met à jour toutes les fenêtres et recalcule les verrouillages | partiel : Esc vide la ligne de commande ≠ | important | XS |
| Flèches, Shift-flèches (p. 153) | défilement mémoire (octet/ligne, Shift = page), désassemblage (instruction/mot, Shift = page), source (ligne, Shift = page) | NON ; Haut rappelle la dernière commande ≠ | important | S |

### 5.2 Hors fenêtre (Alt-)
| Touche | Fonction | Code actuel | Gravité | Taille |
|---|---|---|---|---|
| Alt-B (p. 159, 163) | Set Breakpoint avec syntaxe `adr`, `adr,n`, `adr,=`, `adr,*`, `adr,?expr`, `adr,-` | `B [adr]` bascule ≠ | important | M |
| Alt-O ou 0 (p. 159, 177) | Show Other Bases : hex + décimal + symbole éventuel | `? expr` donne `$hex #déc %mot` : proche mais sans symbole, et décimal de mot tronqué (affiche `%` + valeur 16 bits, notation sans rapport avec le manuel) ≠ | mineur | XS |
| Alt-R (p. 159-160) | Register Set : `a3=a2+4`, `m3=m2`, registres de contrôle, FPn, CRP/SRP ; sert aussi à fixer l'adresse d'une fenêtre zoomée | `Dn=v An=v PC=v SR=v SP=v` à la ligne de commande ; pas de Mn, USP, SSP, CCR | important | S |

### 5.3 Contrôle et exécution (Ctrl-, lettres)
| Touche | Fonction | Code actuel | Gravité | Taille |
|---|---|---|---|---|
| Ctrl-R (p. 168) | Return to program / Run : exécution pleine vitesse avec les registres affichés | OK (Ctrl-R et F9 → `MonRunUntil(-1)`) | néant | - |
| Ctrl-Z, Ctrl-Y, Ctrl-W (p. 168) | Single-step (Y clavier allemand, W clavier français) ; Trap/Line-A/Line-F comptés comme une instruction | Ctrl-Z OK (aussi F7 et `T`) ; Ctrl-Y (25) et Ctrl-W (23) NON | mineur | XS |
| Ctrl-T (p. 168) | Trace Instruction : suit BSR/JSR/Trap/Line-A comme une seule instruction, réentre au retour (même ROM) | ≠ : le code appelle ça `S`/F8/Ctrl-A (step over) qui est cassé (E1/R1) | important | S |
| Ctrl-S (p. 168) | Skip : PC += longueur de l'instruction | NON (`PC=` impose de calculer l'adresse soi-même) | important | XS |
| R (p. 169-170) | Run (G) Go, (S) Slowly (historique), (I) Instruction (avec compte), (U) Until (expression évaluée à chaque instruction), puis « Watch Y/N ? » | `R` : accepté mais sans effet ; `T n` exécute n pas sans historique | important | M |
| U (p. 164) | Run Until : adresse + spécificateur de point d'arrêt, puis exécution | NON (le code l'obtient en interne via MonRunUntil mais cassé) | important | S |
| Ctrl-A (p. 164) | Breakpoint After : pose un point d'arrêt simple sur l'instruction suivante et reprend à PC (pour boucles DBF) | F8/Ctrl-A = « step over » ≠ (même idée mais pour JSR seulement ; la gestion DBcc est correcte dans l'esprit) | important | S |
| Ctrl-B (p. 164) | Simple breakpoint à l'adresse de départ de la fenêtre courante (désassemblage), bascule | NON (`B` fait la bascule mais sans fenêtre courante) | mineur | XS |
| Ctrl-K (p. 164) | Kill breakpoints | `BC` ≠ | mineur | XS |
| Ctrl-D (p. 164) | BDOS breakpoint (numéro GEMDOS, vide = effacer) | NON | important | S |
| Ctrl-X (p. 180 uniquement) | « Stop Executing » listé au tableau, sans description dans le corps | NON ; manuel peu clair (OCR ?) | mineur | XS |
| Ctrl-C (p. 161, 165) | Terminer le processus courant (programme ; puis Mon si plus de programme) | NON : Ctrl-C est ignoré dans la boucle moniteur (K=3) ; `Q`/Ctrl-Q quitte le moniteur directement, même si un programme tourne | important | S |
| Ctrl-E (p. 177) | Réinstaller les vecteurs d'exception | NON | mineur (cf. E3) | XS |
| Ctrl-L (p. 166) | Load program : fichier + ligne de commande ; impossible si un programme est déjà chargé | `L fichier` (pas de ligne de commande : `LoadProgram(Name,'',...)`), recharge sans condition | important | S |
| Ctrl-O (p. 160) | Other screen mode (résolutions couleur) | N/A (mono 640x400 émulé) | mineur | - |
| Ctrl-P (p. 172) | Preferences | NON | important | M |
| Help (p. 164) | Texte + adresses des segments + tous les points d'arrêt (Alt-commandes disponibles) | `H`/F1 = liste de commandes sans segments ni points d'arrêt (`BL` liste les points d'arrêt) ≠ | important | S |
| Shift-Alt-Help (p. 161) | interrompre le programme (trace exception au PC) | partiel : Ctrl-C (#3 reçu par `PollKeys` p08 l.5390) positionne `UserBreak` et `MonRunUntil` le teste. Le texte d'aide du code parle de « ESC/^C » mais Esc n'interrompt pas | mineur | XS |

### 5.4 Commandes lettre seule (sans modificateur)
| Touche | Fonction manuel | Code actuel | Gravité | Taille |
|---|---|---|---|---|
| A (p. 167) | Load ASCII file (fenêtre 2 ou 4, vue empilée si déjà source) | NON | mineur (sans source débogage) | M |
| B (p. 166) | Load Binary file : `fichier[,adresse]` ; M8/M9 = début/fin | NON (B = point d'arrêt ≠) | important | S |
| C (p. 178) | Compare memory (fenêtres 2/3 et 4/5 au premier écart ; N pour continuer) | NON | mineur | S |
| D (p. 177) | Change drive & directory | NON ; D = désassembler ≠ | mineur | S (SetCurDir hôte) |
| E (p. 167) | Executable file to use (symboles/lignes seuls) | NON | mineur | S |
| G (p. 170-171) | Search memory : B/W/L/T/I, alignement `,w`/`,l`, casse | NON (G = go ≠) | important | M |
| H (p. 165) | Show History buffer | NON (H = aide ≠) | important | M |
| I (p. 175) | Intelligent copy `deb,fin,dest` (recouvrement géré) | NON | mineur | XS |
| L (p. 176) | List labels | NON (L = load ≠) | important | S |
| M (p. 177) | Modify address (équivalent Alt-A) | OK pour la zone mémoire (≠ car pas de fenêtre courante) | mineur | XS |
| N (p. 171) | Find next | NON | important (suit G) | S |
| P (p. 176-177) | Disassemble to printer/disk, labels auto `Lxxxxxx`, zones de données | NON | mineur | M |
| Q (p. 178) | Query port (octet, ou `,W`/`,L`) | NON ; Q = quitter ≠ ; sur cet émulateur la lecture de la zone matérielle ne déclenche pas d'erreur de bus (Rd8 : `A<$FF0000` seulement) donc Q peut être une simple lecture | mineur | XS |
| S (p. 167) | Save binary `fichier,début,fin(inclus)` | NON ; S = step over ≠ | important | S |
| T (p. 178) | Transfer to port `adr,donnée[,taille]` | NON ; T = trace ≠ | mineur | XS |
| U (p. 164) | Run Until (adresse + type) | NON | important | S |
| V (p. 160) | View other screen ; une touche pour revenir | OK (`V`, F10 : `ViewProgramScreen` attend une touche clavier ; clic souris ignoré) | néant | - |
| W (p. 176) | Fill memory with : `début,fin(incl.),octet` | `F adr,len,val` ≠ (voir ci-dessous) | mineur | XS |
| 0 (p. 159) | Show other bases | `?` ≠ | mineur | XS |

### MON-X1  Aide interne contradictoire pour F
`MonHelp` affiche `F addr len b` (séparés par des espaces) alors que `MonExec` découpe avec `SplitTop(Arg,Prt,3)`, donc sur les virgules ; une saisie « F 1000 10 0 » donne N=1, usage affiché. Gravité : mineur, Taille : XS. (Par ailleurs, `len` ici est une longueur, alors que le manuel utilise une adresse de fin inclusive, p. 176.)

### MON-X2  Commande `R` inerte
`Else If Cmd='R' Then Begin End` (l.14450). Elle est acceptée et ne fait rien (silencieusement). Gravité : mineur ; Taille : XS (message ou implémentation du R du manuel).

### MON-X3  « X » recharge et perd tout
`X` recharge le programme (EmuReset efface les points d'arrêt : `NBps:=0` p09b l.240) ; aucune commande équivalente dans le manuel (un reload se fait par Ctrl-C puis Ctrl-L). Gravité : mineur. Les points d'arrêt posés devraient survivre à un rechargement (le manuel ne le dit pas, mais le flux « Terminate the program, re-load it, then set a stop breakpoint » p. 183 suppose qu'on les repose ; une conservation optionnelle est un plus).

### MON-X4  Terminer/quitter
Voir section 12.

---------------------------------------------------------------------

## 6. Expressions numériques (p. 145-148, 159, 182-183)

### MON-N1  Priorités et opérateurs
- Manuel (p. 146) : 7 niveaux de priorité : (1) moins/plus unaires et opérateurs source `#` `?` ; (2) `~` ; (3) `<<` `>>` ; (4) `&` `!` (OU) `^` (XOR) ; (5) `*` `/` ; (6) `+` `-` ; (7) comparaisons `= < > <> != <= >=` (résultat vrai/faux, utilisé par les points d'arrêt conditionnels et Run Until). `*` = multiplication seulement. Pas de notion de relatif/absolu.
- Code : `MonExpr` (l.14056) boucle sur `+ - * / & |` en GAUCHE-À-DROITE sans priorité (`2+3*4` = 20 au lieu de 14) ; `|` = OU (manuel : `!`) ; pas de `~`, `^`, `<<`, `>>`, aucun opérateur de comparaison ; `+` unaire non géré (erreur).
- Gravité : important (les conditions du manuel p. 169, 182-183 sont inutilisables : `d6&ffff=ffff`, `PC=E08B1A`, `{pc}.w=4e75`, `sp=a7`, `(a3>(3A400-\100+M1))`, `{main_ptr}&1`).
- Taille : M (réécriture en descente récursive à 7 niveaux ; ~120 lignes).

### MON-N2  Bases numériques
- Manuel (p. 145-146) : hexadécimal par défaut ; `$` explicite ; décimal avec `\` (« not # as in Mon version 1 ») ; zéro initial pour lever l'ambiguïté avec un nom de registre (`0A5`) ; `\` pour les numéros de ligne décimaux (p. 173).
- Code : hexadécimal par défaut ; `$` ; `#` = décimal (syntaxe Mon 1 que le manuel déconseille car `#` est maintenant l'opérateur de ligne source) ; `%` binaire (non dans le manuel, mais inoffensif) ; `'abc'` constantes caractères (non dans le manuel). `\` : NON.
- Gravité : important (`#` change de sens) ; Taille : XS pour `\`, S pour le déplacement de `#` vers l'opérateur source quand les infos de ligne existeront. Compatibilité : accepter `#` décimal comme ancien alias tant qu'il n'y a pas de source.

### MON-N3  Registres dans les expressions
- Manuel (p. 146) : noms de registres insensibles à la casse (clash avec hexa `A5` : utiliser `0A5` ou `$A5`) ; A7 = pile utilisateur ; SR, SSP, SFC, DFC, CACR, CAAR, VBR, MSP, ISP, MMUSR, TT0, TT1, TC, FPCR, FPSR, FPIAR (selon CPU) ; CRP/SRP non utilisables (64 bits) ; symboles réservés TEXT, DATA, BSS, END (END = octet suivant le BSS), SP (pile utilisateur ou superviseur selon SR).
- Code : D0-D7, A0-A7, SP (= A7 = `Rg[15]`, pas de distinction user/super car `SingleStack:=True` p09b), PC, SR. Le clash hex est bien traité comme dans le manuel (registre d'abord, `$A5`/`0A5` sinon). Absents : USP, SSP, CCR (RegOf les connaît mais MonTerm filtre `R<16`), TEXT/DATA/BSS/END, M0-M9 (voir N5), registres de contrôle (N/A 68000).
- Gravité : important pour TEXT/DATA/BSS/END et M0-M9 ; mineur pour le reste. Taille : S.

### MON-N4  Indirection
- Manuel (p. 147-148) : `{expr}` suivi de `.b`, `.w` ou `.l` (défaut long) ; imbriquable ; adresse impaire pour mot/long ou mémoire illisible : expression invalide (p. 147-148). Exemples : `{data_start+10}.w`, `{Sp}`, `{4+a6}`, `{pc}.w=4e75`, `{m2}`.
- Code : `[expr]` uniquement, long, sans suffixe de taille ; la mémoire illisible ne rend PAS l'expression invalide (`ClrErr` masque l'erreur et renvoie 0). Accès impair non rejeté (`Rd32` octet par octet).
- Gravité : important. Taille : S.

### MON-N5  Registres mémoire M0-M9
- Manuel (p. 148) : M0 = EA de destination de l'instruction courante ; M1-M5 = adresse de départ des fenêtres 1-5 (affecter M3 change la fenêtre 3, si non verrouillée) ; M6-M7 libres ; M8/M9 = début/fin du dernier fichier binaire chargé (B). Visibles en zoomant la fenêtre registres. M1 sans signification si la fenêtre 1 est un registre.
- Code : NON.
- Gravité : important (liés à presque tout : verrouillages, Save Binary `nom,M8,M9`, conseil p. 184 `{m5}`).
- Taille : M (stockage `Mem10: Array[0..9] of LongInt` + liens aux vues).

### MON-N6  Opérateurs source `#` et `?`
- Voir S3. Code : NON. Gravité : sans objet tant qu'il n'y a pas d'infos de ligne.

### MON-N7  Affectation `=` capturée par la ligne de commande
- Manuel : `=` est un opérateur de comparaison dans les expressions (p. 146) ; l'affectation est un dialogue spécial (Alt-R) dont le format est `registre=expression` (p. 159).
- Code : `MonExec` (l.14328) cherche `=` dans toute la ligne avant d'évaluer la commande (`P:=Pos('=',S)`) ; toute commande contenant `=` (par exemple `G` ou `B` avec condition, un futur `U ... d6&ffff=ffff`) est traitée comme affectation puis « Bad assignment ». Aussi `Dn=v` ne marche que si le premier jeton est un registre : un cas comme `? a0=a1` est détourné.
- Gravité : important (empêche d'utiliser les comparaisons). Taille : XS (n'interpréter comme affectation que dans le dialogue Alt-R, ou si l'argument avant `=` est un nom de registre ET que la commande est vide).

### MON-N8  Divers
- `MonTerm` : `Rg[R]` renvoie bien 32 bits pour An/Dn mais le suffixe de taille (`d0.w`) n'existe pas dans le manuel (non requis). La division par zéro est détectée (MErr). Dépassement 32 bits non signalé. Mineur.
- `MonTerm` essaie d'abord l'hexadécimal puis les symboles : un symbole comme `DEAD`, `FACE`, `ADD`, `BAD` sera lu comme nombre hexadécimal. Le manuel ne précise pas la priorité ; solution typique : les noms commençant par une lettre qui sont aussi des chiffres hexa valides sont interprétés comme symbole SI ce symbole existe. Mineur, XS.

---------------------------------------------------------------------

## 7. Types de fenêtres (p. 149-153)

### MON-W1  Fenêtre registres (voir F4) 
Gravité : important. Taille : M.

### MON-W2  Fenêtre désassemblage (p. 151-152)
- Manuel : adresse hexa à gauche, puis symbole éventuel, puis désassemblage ; `»` (OCR) pour le PC ; points d'arrêt entre crochets : stop = nombre d'exécutions restantes, conditionnel = `?` + début de l'expression, count = `=` + compteur, permanent = `*` ; format : norme Motorola, tout en minuscules sauf labels en majuscules, nombres en hexadécimal majuscule, zéros de tête supprimés, `$` omis sous 10, nombres signés quand pertinent ; seule entorse : listes MOVEM abrégées (`d0-3/a0-2`) ; constantes flottantes en hexa ; nombres TRAP en décimal (« except TRAP numbers »).
- Code : `Hex6(A)` (6 chiffres seulement) ; marqueur `*` (PC) ou `B` (point d'arrêt) dans la colonne 7 de l'adresse ; PC en ligne inversée ; texte de `Dis` en MAJUSCULES (`MOVE.L`, `D0`) et « MOVEM D0-D3/A0-A2 » non abrégé (`RegListText` p06 l.306 écrit `D0-D3`, abréviation inexistante) ; symboles sur les références absolues et branchements oui, mais pas de symbole de label à gauche ; pas de `[ ]`. Les nombres `ImmText` suppriment bien `$` sous 10. 
- Gravité : mineur à important (lisibilité) ; Taille : S.
- Remarque : pas de défilement ni de verrouillage (la fenêtre est refixée à `PC` après chaque trace/exécution par `MonDisAddr:=PC`) ; la fenêtre ne conserve pas son adresse pendant un `T` (le manuel dit « Window 2 is locked to the PC by default », p. 140, c'est donc cohérent).
- Limite du désassembleur : 68000 uniquement.

### MON-W3  Fenêtre mémoire (p. 152)
- Manuel : adresse hexa, mots hexa, ASCII ; `**` pour mémoire illisible ; nombre d'octets calculé sur la largeur (16 octets max par ligne) ; défilement par flèches (octet/ligne), Shift (page).
- Code : 8 octets par ligne fixe, regroupés par mots, ASCII ; octets illisibles affichés `00` (ClrErr + Rd8=0) au lieu de `**` ; pas de défilement (changer d'adresse avec `M addr`).
- Gravité : important (pas de `**`, pas de défilement). Taille : S.

### MON-W4  Fenêtre source (p. 153)
- Manuel : fichier ASCII avec nom du fichier en titre, tabulation 8 ou 4 (Alt-E), numéros de ligne absents/décimaux/hexa (Preferences), curseurs, Alt-G, recherche texte par G.
- Code : NON. Gravité : important (le débogueur d'origine est « source level »), dépend de S3. Taille : M.

### MON-W5  Fenêtre « texte » ?
Le manuel ne définit que quatre types (Register, Disassembly, Memory, Source). Il n'y a pas de type « Texte » distinct ; les affichages History/List labels/Help sont des fenêtres « larges » modales (p. 165, 176, 164). Rien à faire.

### MON-W6  Piles de vues, numérotation et verrouillages
Voir 5.1 (Alt-L, Shift-., Shift-,, `.`, `,`). Code : NON. Taille : M.

### MON-W7  Changement de type
Les fenêtres 3 et 5 sont mémoire seulement ; 2 et 4 mémoire/désassemblage/source ; 1 registres + les trois autres. Code : NON. Taille : XS avec le modèle de données de la section 18 (masque de types autorisés).

---------------------------------------------------------------------

## 8. Commutation d'écran (p. 160-161)

- V (view other screen) : le manuel retire Mon pour montrer l'écran du programme ; « pressing any key will return the Mon screen ». Code : OK (`ViewProgramScreen` : `EmuVisible`, `BlitScreen(True)`, attend une touche). Les clics souris sont ignorés (comme demandé). Gravité : néant.
- Screen timer (bascule vers l'écran du programme après 20 ms) : N/A ; chaque affichage hôte ne touche pas à l'écran émulé (le moniteur dessine sur l'écran hôte et l'écran ST est un bitmap en mémoire émulée) donc Mon peut afficher en permanence ou réafficher l'écran programme à la demande. Intéressant : la zone d'écran du programme est en mémoire (`ScrBase`, 32 000 octets) et peut donc être visualisée dans une fenêtre mémoire.
- Pendant l'exécution (Run, Go) : le code montre l'écran du programme (`EmuVisible:=True` dans `MonRunUntil`) et revient à Mon à l'arrêt. Manuel : « If N is selected then execution will occur while showing your program's display » (p. 169) ; le mode « Watch Y » affiche Mon après chaque instruction. Mode Watch : NON.
- Ctrl-O (autre mode d'écran) : N/A.
- Pendant un accès disque le programme est affiché (p. 161) : N/A.
- Gravité globale : mineur sauf Watch (voir R, section 9). Taille : XS.

---------------------------------------------------------------------

## 9. Exécution : Run, Step, Trace, Over, Until, Skip (p. 143-144, 168-170, 182-183)

### MON-R1  Step over et Run Until ne s'arrêtent pas à la cible (BUG)
- Manuel : Ctrl-T trace en considérant un BSR/JSR/Trap comme une seule instruction ; U « Run Until » pose un point d'arrêt à l'adresse et reprend ; Ctrl-A pose un point d'arrêt après l'instruction courante et reprend ; conseil p. 182 : Until `{Sp}` « sets a breakpoint at the return address ».
- Code : `MonStepOver` (l.14274) pour JSR/BSR/DBcc/TRAP appelle `MonRunUntil(PC+Len)`. Celle-ci (l.14246) exécute un premier `Step` puis boucle `RunCpu(20000)` en ne testant `PC=Target` qu'ENTRE deux paquets de 20 000 instructions. Aucune insertion de point d'arrêt temporaire. Donc l'arrêt n'a lieu que par chance (si PC coïncide avec la cible à la frontière), sinon à la fin du programme, à un point d'arrêt utilisateur ou à Ctrl-C.
- Gravité : bloquant (F8/S/Ctrl-A, qui est la commande de débogage la plus utilisée, ne marche pas pour les JSR/BSR ; DBcc non plus). Non exécuté pendant l'analyse : conclusion tirée de la lecture du code (`RunCpu` ne connaît pas `Target`) ; à confirmer par un test simple (JSR + RTS, F8).
- Taille : XS/S. Ajouter à `RunCpu` un paramètre/une variable globale `TempBp: LongInt` (ou une table de points d'arrêt temporaires) testée au même endroit que `IsBreakpoint`.

### MON-R2  Point d'arrêt à l'instruction suivante ignoré
- Code : dans `MonRunUntil`, le `Step` initial est suivi de `RunCpu` qui exécute directement l'instruction au nouveau PC avant de tester les points d'arrêt (RunCpu les teste APRÈS chaque Step) ; un point d'arrêt (ou la cible) posé exactement à `PC+Len` ne s'arrête donc pas. Même cause que R1 pour MonRunUntil lui-même (`Target` testée avant RunCpu, mais seulement une fois par paquet). Gravité : important. Taille : XS (tester `IsBreakpoint(PC)`/cible après le Step initial).

### MON-R3  Pas à pas
- Manuel : Ctrl-Z/Y/W, un pas ; message « Breakpoint » au chargement car Mon pose un point d'arrêt à la première instruction (p. 144) ; trap/line A = une instruction par défaut ; option « Follow traps » (p. 172) pour y entrer.
- Code : `MonTraceN(1)` : OK, trap et ligne A exécutés HLE comme une seule instruction. `Follow traps` : NON, et impossible dans l'architecture HLE : le code GEMDOS/BIOS/XBIOS/AES/VDI n'est pas du code 68000 (traité par `DoTrap`/`GemDispatch`), sauf pour du code « stub » ; ne pas implémenter, documenter. Après le chargement le code n'affiche pas « Breakpoint » mais « Loaded ... PC=$xxxx » (message distinct) : mineur.
- Gravité : néant à mineur.

### MON-R4  Run (R) : Go / Slowly / Instruction / Until + Watch
- Manuel (p. 169-170) : Go = Ctrl-R ; Slowly = réduit, avec historique complet ; Instruction = nombre d'instructions ; Until = expression évaluée après chaque instruction (arrêt si non nulle) ; question « Watch Y/N ? » (Y : Mon affiché après chaque instruction, interruption par les deux touches Shift ; N : écran du programme visible, interruption Shift-Alt-Help). Un clignotement de quelques pixels en haut à gauche montre que ça tourne.
- Code : `T n` fait n pas sans historique, sans Watch ni affichage intermédiaire ; pas de Run Until expression ; le pas n'est pas interruptible (boucle `For` sans test d'interruption : un `T 10000000` gèle l'hôte). 
- Gravité : important. Taille : M (boucle avec évaluation d'expression compilée une fois ; mode Watch = redessin tous les N pas ; interruption par Ctrl-C/Esc via `PollKeys`).

### MON-R5  Interruption d'un programme (p. 161)
- Manuel : Shift-Alt-Help interrompt avec trace exception au PC courant.
- Code : `PollInput` → `PollKeys` positionne `UserBreak` sur Ctrl-C (octet 3) ; `MonRunUntil` s'arrête en `STOP_USER` avec le message « Interrupted by user ». Équivalent suffisant. L'aide dit « (ESC/^C interrompt) » mais seul ^C fonctionne : corriger le texte ou accepter Esc (mais Esc est aussi une touche programme, cf. KQPush ; ne pas la voler). Gravité : mineur. Taille : XS.
- Note : après interruption dans du code de ROM (cf. manuel), le conseil `Run Until sp=a7` suppose du code ROM ; N/A ici car TOS est HLE.

### MON-R6  Programme terminé
- Manuel (p. 143, 165) : message « Program Terminated » dans la fenêtre du bas ; on peut charger un autre programme ; Ctrl-C ensuite quitte Mon. 
- Code : `STOP_EXIT` : message « Program terminated, exit code n » ; commandes d'exécution refusées ensuite (ReportStop à chaque fois), `L`/`X` pour recharger. OK en substance. Mineur : le manuel dit que si on a utilisé Debug depuis l'éditeur, Mon se termine automatiquement avec le programme (p. 165) ; ici non (on reste dans le moniteur) – acceptable mais à signaler.

### MON-R7  Message d'arrêt au chargement
Voir R3. Plus : « Start at label » (Preferences) permet d'arrêter à un autre point (ex. `main`) — NON.

---------------------------------------------------------------------

## 10. Points d'arrêt (p. 162-164, 183)

### MON-B1  Types
- Manuel : jusqu'à HUIT points d'arrêt simultanés, cinq types : simple `[1]` (effacé à l'exécution), stop `[n]` (arrête après n exécutions ; un simple est un stop de compte 1), count `[=]` (compteur incrémenté, jamais d'arrêt ; profilage), permanent `[*]` (jamais effacé, arrêt à chaque fois), conditionnel `[?]` (expression évaluée à chaque passage, arrêt si ≠ 0).
- Code : un tableau `Bps: Array[1..MAXBP] of LongInt` (MAXBP = 16, p07), uniquement adresse ; tous sont permanents : le point d'arrêt reste après le déclenchement ; `B addr` bascule (pose/retire) ; `BC` efface tout ; `BL` liste avec symbole. Pas de compte, ni de condition, ni de compteur.
- Gravité : important (conseil « Bug Hunting » p. 183 : count breakpoint puis stop breakpoint, conditionnel `{main_ptr}&1` : tous deux inutilisables).
- Taille : M (`TBp = Record Addr; Kind; N,Cnt: LongInt; Expr: String[63]; End;` ; test dans RunCpu : hit → selon Kind, évaluer, décrémenter, effacer).

### MON-B2  Syntaxe Alt-B
- Manuel : `<adr>` simple ; `<adr>,<expr>` stop (expr = nombre de fois, évaluée avant l'exécution) ; `<adr>,=` count (départ 0) ; `<adr>,*` permanent ; `<adr>,?<expr>` conditionnel ; `<adr>,-` efface. Pas posable sur adresse impaire, illisible ou en ROM.
- Code : `B [expr]` bascule ; aucune vérification de parité ni de lisibilité (`ToggleBp`, l.14285). Une adresse impaire n'arrêtera jamais l'exécution (le PC est toujours pair) et une adresse non lisible non plus.
- Gravité : important ; Taille : S (parseur de spécificateur + contrôles).

### MON-B3  Autres commandes de point d'arrêt
Ctrl-B (simple sur la fenêtre courante, bascule), Ctrl-K (tout effacer), Ctrl-A (après l'instruction), Ctrl-D (BDOS : numéro GEMDOS, vide = effacer), U (Run Until adresse + type), Help (affiche segments TEXT/DATA/BSS adresses/longueurs + points d'arrêt). Code : NON pour tous (équivalents partiels : `BC`, `BL`). Gravité : important (Ctrl-D en particulier, très utile sur un TOS simulé : on peut facilement tester le numéro de fonction dans `DoTrap`).
Taille : S au total (Ctrl-D : table `BdosBp` et test dans le gestionnaire de `TRAP #1`).

### MON-B4  Historique des points d'arrêt
« Every time a breakpoint is reached, regardless of whether the program is interrupted or resumed, the program state is remembered in the History buffer » (p. 163) : NON (voir H).

### MON-B5  Marqueurs dans le désassemblage
`[ ]` avec n/=/ ?expr / * : le code met un `B` dans la colonne 7. Mineur (S).

---------------------------------------------------------------------

## 11. Historique (History) (p. 164-165)

- Manuel : tampon de 5 entrées (la plus ancienne est supprimée) rempli par chaque pas, chaque point d'arrêt atteint, chaque exception et par les Run ; H ouvre une grande fenêtre avec tous les registres du 68000 (D0-D7, A0-A7, SR, PC) et le désassemblage de la prochaine instruction ; les `[ ]` y montrent les valeurs courantes ; seuls les registres 68000 y sont conservés.
- Code : NON. `InstrCount` seulement. Gravité : important (avec Run Slowly c'est l'outil d'analyse a posteriori). Taille : M (`THist = Record D,A: Array[0..7] of LongInt; PC,SR: LongInt; End; Hist: Array[0..HMAX-1] of THist; HHead,HN`). Le tampon de 5 est d'origine ; on peut en prévoir 64+ pour l'émulateur sans coût, en gardant le défilement.

---------------------------------------------------------------------

## 12. Quitter, chargement, sauvegarde (p. 165-167, 142-143)

### MON-Q1  Quitter
- Manuel : Ctrl-C = terminate (programme d'abord ; puis Mon s'il n'y a plus de programme) ; avec Debug depuis l'éditeur, Mon se termine aussi ; avertissement sur l'arrêt prématuré de programmes GEM (p. 166).
- Code : `Q` / `QUIT` / Ctrl-Q quittent Mon immédiatement ; le programme reste simplement abandonné (RunMonitor restitue l'éditeur ; `MonActive:=False`). Cela correspond à « Debug: Mon quitte avec le programme ». Gravité : mineur. Mais le message « Program Terminated + Ctrl-C retire Mon » n'est pas reproduit. Taille : XS.

### MON-Q2  Chargement du programme à déboguer
- Manuel (p. 142-143, 166) : lancement `mon prog ligne-de-commande` ; si aucun programme, invite « Executable file to load » (Return/Esc pour renoncer) ; invite d'une ligne de commande ; si échec, message d'erreur (le message est « Invalid program load format » pour un fichier non exécutable) et Ctrl-L pour réessayer ; Mon charge symboles et infos de ligne du premier fichier source, puis place un point d'arrêt à la première instruction (message « Breakpoint ») ; depuis l'éditeur le programme est chargé automatiquement (ou pris en mémoire s'il y est assemblé).
- Code : OK pour l'invite initiale (via InputDlg), le chargement automatique depuis l'éditeur (`CmdDebug` → `RunMonitor(OutPathFinal,False)`), le chargement des symboles (p09b) ; manquent : l'invite de ligne de commande (`LoadProgram(Name,'',...)` passe toujours `''`), « Invalid program load format » (le code affiche « Cannot load »). Mode `X`.
- Gravité : important pour la ligne de commande (programmes qui lisent leurs paramètres) ; Taille : XS.

### MON-Q3  Load Binary (B), Save Binary (S), Load ASCII (A), E
- Voir 5.4. Noter que M8/M9 ne se mettent à jour qu'après B : dépend de N5. Taille totale : M. Le code a déjà `ReadAll` (p09b) et des primitives de fichier.

---------------------------------------------------------------------

## 13. Recherche, copie, comparaison, fill, ports, désassemblage fichier, divers (p. 170-178)

### MON-M1  Recherche G / N
- Manuel (p. 170-171) : G demande `B/W/L/T/I` ; B/W/L = liste de nombres séparés par virgules (tolérant sur l'alignement, imposable par `,W`/`,L` terminal) ; T = texte (+ question de casse Y/N) ; I = fragment de mnémonique (ex. `$14(A` trouve `MOVE.L D2,$14(A0)`), casse Y/N ; sur une fenêtre source, T automatique et ligne affichée ; N cherche l'occurrence suivante, trouve toujours au moins une occurrence (le tampon de Mon) pour B/W/L/T ; Esc testé tous les 64 Ko (tous les 2 octets pour I) ; départ juste après l'adresse de début de la fenêtre courante (hors registres) ; zone de recherche : 0 → fin RAM système, puis ROM et cartouche, puis TT RAM, puis retour à 0 ; option NOCARTRIDGE / Ignore cartridge area.
- Code : NON. Gravité : important. Taille : M (la zone RAM émulée est 1 Mo ; chercher dans `[0, MemSize)`, `Dis` pour le mode I qui existe déjà ; ROM/cartouche N/A).

### MON-M2  Copie intelligente I, Compare C, Fill W, Query Q, Transfer T
- Voir 5.4. `I` : `début,fin,dest` avec chevauchement : XS. `C` : S. `W` : XS (la commande `F` actuelle est la même avec un autre format : à aligner). `Q`/`T` : XS (dans l'émulateur la lecture $FF0000+ renvoie 0 sans erreur de bus – cf. `Rd8` p06 l.62 – donc le garde-fou du manuel est sans objet, mais ces commandes sont nécessaires pour écrire/lire `Wr8`).
- Gravité : mineur.

### MON-M3  Disassemble to printer/disk (P)
- Manuel (p. 176-177) : 1re ligne `début,fin` ; 2e ligne zone du tampon de références croisées (vide = pas d'étiquettes automatiques) `tampon_début,tampon_fin` ; zones de données `début,fin[,B|W|L]` (désassemblées en DC) jusqu'à une ligne vide ; nom de fichier (vide = imprimante) ; étiquettes automatiques `Lxxxxxx` ; imprimante : 8 chiffres hexa, jusqu'à 10 mots de données, 12 car. de symbole, puis désassemblage ; disque : directement relisible par Gen (symbole, tab, instruction, tab entre opérande et code) ; Esc ou erreur disque interrompt. « XREF » mentionné pour le cas sans symboles.
- Code : NON. Gravité : mineur mais précieux (c'est la seule sortie du désassembleur en fichier). Taille : M ; réutiliser `Dis` et l'écriture `PRINTER.OUT` (p09d).

### MON-M4  Preferences (Ctrl-P) et sauvegarde (MON.INF)
- Manuel (p. 172-175) : Screen timer (Y/N), Follow traps (Y/N), Relative offsets (Y), Ignore case (Y), Ignore cartridge area, Source line numbers (N/D/H), Auto load source (Y), Auto `_`/`@` prefix (Y), Start at label (texte), Symbol length (22, minimum 8), Display ZAn in disassembly (N), Top of ST RAM (par défaut phys_top), Top of TT RAM, Save preferences (Y/N) → fichier **MON.INF** (OCR « MON.IMF ») dans le répertoire courant ; la disposition des fenêtres (split/widen) est aussi sauvegardée via Save Preferences (p. 156).
- Code : NON. `DEVPAC.INF` (p11 l.710) conserve les préférences de l'éditeur, pas du moniteur.
- Gravité : important pour sauvegarder la disposition ; Taille : M (réutiliser le format `CLE=VALEUR` de p11, ajouter les clés `MON_*`). Les options matérielles (Follow traps, screen timer, cartouche, TT RAM, ZAn) sont N/A et peuvent être omises.

### MON-M5  D (Change drive & directory)
Voir 5.4. Taille S (reprendre le chemin courant de l'hôte).

### MON-M6  Ctrl-E (réinstallation des vecteurs) et TT RAM
N/A / voir E3.

---------------------------------------------------------------------

## 14. Auto-résident (AMON) et sujets liés à la ROM (p. 179-180, 184-185)

- AMON.PRG (dormant dans AUTO, appelé à toute exception, Shift-Alt-Help pour interrompre, impossible de charger des programmes ou des labels, variables de base page à 0, Control-C laisse Mon résident ; avertissement sur Run Other dans Gen ; les deux Shift à l'installation pour entrer dans Mon et poser des BDOS breakpoints ; Ctrl-R annule l'installation) : N/A. Il n'y a ni dossier AUTO ni exécutable AMON dans cet émulateur. Seul pertinent : « enter Mon on any exception » : on peut offrir « Run with Mon armed » (ex. option « Trap exceptions dans Mon » de l'éditeur : au lieu de simple message à la fin du programme, ouvrir le moniteur sur l'état fautif). C'est faisable par `RunMonitor` sur une session déjà chargée (alors que `RunProgramGUI` actuel libère simplement). Gravité : mineur, Taille : S.
- Desk accessories (p. 184-185) : la méthode « chercher le nom .ACC en mémoire, `{Sp+2}`, BDOS bp $3D / $4B » dépend de Ctrl-D et de la fenêtre mémoire verrouillable sur expression ; `LoadAccessories` (p09b) charge les .ACC au démarrage du GEM émulé. Le moniteur actuel ne les voit pas. Gravité : mineur. Prérequis : B3 (Ctrl-D), N4 (indirection), W (fenêtres).
- NOTRACE.PRG, Shift-Alt-Help dans la ROM, « trace bit left in stack frames » (p. 173) : N/A (pas de ROM).

---------------------------------------------------------------------

## 15. Conseils (Hints & Tips) et Exception Analysis (p. 182-186) : ce qui est inutilisable aujourd'hui

| Conseil du manuel | Dépendance manquante | Statut actuel |
|---|---|---|
| Interrupted in ROM : `Run Until sp=a7` (Follow traps) | R, expression `=`, Follow traps | N/A (ROM) |
| `Until {Sp}` (retour de sous-routine) | U, indirection `{}` | impossible (E1/R1, N4) |
| `Run Until {pc}.w=4e75` + `(sp>xxx)` | R(U), `.w`, comparaisons, `&` booléen | impossible |
| `Run Until {4+a6}` | idem | impossible |
| Pré-calculer l'expression avec Alt-O | Alt-O | `?` approximatif |
| Conditionnel `{main_ptr}&1` | B conditionnel | impossible |
| Count breakpoint puis Help puis stop breakpoint | B count/stop + Help avec compteurs | impossible |
| Bus/Address error : regarder la pile | fenêtre mémoire verrouillée sur SP | possible avec `M SP`, mais sans défilement |
| Illegal instruction : PC très bas (< $30) : regarder l'adresse 0 | PC correct (E2) + fenêtre de désassemblage | PC faux (E2) |
| Address error : corriger un registre et reprendre | reprise (E1) | impossible |
| Privilege violation : sauter n'aide pas | Ctrl-S | N/A mais Ctrl-S manquant |
| Divide by zero | message | OK (« Divide by zero at $... ») |
Les conseils de la section « Desk Accessories » sont décrits en 14.

---------------------------------------------------------------------

## 16. Autres écarts relevés et doutes OCR

- Zones de l'OCR douteuses : (a) p. 137 : colonne « Mon active » du tableau, 45 = XBIOS / 46 = BIOS (inversion probable) ; (b) p. 141 : « Alt-x delete the entire line » (x en minuscule) ; (c) p. 155 : « Control-< and Control-— » (flèches gauche/droite ou haut/bas ? le tableau p. 180 dit « Reduce » / « Increase » Register Window Height) ; (d) p. 154 « keys 1-9, A-F » (probablement 0-9) ; (e) p. 175 « MON.IMF » = MON.INF ; (f) p. 164 « Run Unitil » ; (g) p. 181 le tableau liste « Control-E Re-install breakpoints » alors que le corps (p. 177) dit « Re-install Exceptions » ; (h) p. 180 « Control-X Stop Executing » sans description dans le corps ; (i) p. 176 « ,1 » = « ,L » ; (j) p. 153 sous-chapitre « Cursor Keys » : les flèches sont lisibles comme texte mais les glyphes sont perdus.
- Le manuel V3 numérote ses pages imprimées différemment des fichiers `pNNN.txt` (+16, pas +8 comme noté dans BRIEF.md pour ce chapitre).
- Écart « Mon » vs « MonST » : le moniteur de DEVPAC.PAS porte aussi le nom MonAm (variante Amiga, hunk). Le manuel ne parle que de Mon pour ST/TT ; les adaptations Amiga ne sont pas couvertes ici.

---------------------------------------------------------------------

## 17. Les 25 corrections les plus utiles, dans l'ordre recommandé

Ordre = (utilité réelle) puis (coût). Les numéros renvoient aux entrées ci-dessus.

1. R1 : faire en sorte que MonRunUntil/step over s'arrêtent à la cible (point d'arrêt temporaire testé dans RunCpu). XS. BLOQUANT.
2. E1 : reprendre après une exception ou un STOP (effacer `StopReason` après affichage, marquer l'état « mort » seulement pour STOP_EXIT). XS. BLOQUANT.
3. E2 : remettre PC au début de l'instruction fautive (Bus, Address, Illegal, Privilege, Line A/F) et ajouter l'adresse impaire au message d'Address error (E4). XS.
4. R2 : tester les points d'arrêt/cible juste après le Step initial de MonRunUntil. XS.
5. N7 : n'interpréter `=` comme affectation que pour `registre=expr` ; libère les comparaisons. XS.
6. N1/N2/N4 : réécrire l'évaluateur (priorité à 7 niveaux, `~ ^ ! << >>` et comparaisons, `\` décimal, `{expr}.b/.w/.l`, signalement d'erreur sur mémoire illisible). M.
7. C1/C2 : passer à des commandes à touche unique, avec la table du manuel (Alt-, Ctrl-, lettres) ; garder l'ancienne ligne en mode étendu (`:`). M.
8. C4 : dialogues Mon (invite, édition de ligne, flash à l'erreur, `MonAlert`). S.
9. F1/W7 : modèle de 5 fenêtres typées avec fenêtre courante (Tab, Alt-1..5), titre inversé, types autorisés par fenêtre. L (cf. 18).
10. W3/5.1 : défilement au curseur (flèches, PgUp/PgDn) pour mémoire et désassemblage ; `**` pour mémoire illisible. S.
11. Alt-E : édition de la mémoire (hex/ASCII), indispensable pour modifier des données. M.
12. B1/B2/B3 : points d'arrêt simple, stop, count, permanent, conditionnel, Alt-B syntaxe complète, Ctrl-B/K/A/D, U, Help avec les segments. M.
13. W2/S2 : désassemblage conforme (minuscules, colonne symbole, marqueurs `[ ]`, Relative offsets, MOVEM abrégé). S.
14. F4/F5/W1 : fenêtre registres complète (ASCII des Dn, mémoire pointée par An avec ASCII, ligne PC avec instruction et adresses effectives). M.
15. R4 : commande R (Go/Slowly/Instruction/Until + Watch), Ctrl-T trace, Ctrl-S skip, Ctrl-Y/Ctrl-W. M.
16. Historique (H) de 5 à 64 entrées, alimenté par pas, points d'arrêt, exceptions et Run. M.
17. N5 : registres mémoire M0-M9 (+ liens fenêtres et fichiers binaires). M.
18. Alt-L : verrouillage sur expression, Esc = mise à jour, vues empilées (Shift-., Shift-,, `.`, `,`). M.
19. M1 : recherche G/N (B/W/L/T/I). M.
20. Q2/Q3 : ligne de commande du programme à Ctrl-L, B/S (binaire), E (symboles), M8/M9. S/M.
21. S4/M2 : L (List labels), W (Fill), I (Copy), C (Compare), Q/T (ports), D (disque). S au total.
22. Alt-Z (zoom), Alt-S/Alt-W (split/widen), Alt-T (type), Alt-F (police), Ctrl-flèches (hauteur registres). S/M.
23. M4 : Ctrl-P préférences (relative offsets, ignore case, préfixe `_`/`@`, longueur de symbole, numéros de ligne, démarrage sur un label) + sauvegarde `MON.INF` ou clés dans `DEVPAC.INF`, y compris la disposition des fenêtres. M.
24. M3 : Disassemble to printer/disk (P) avec étiquettes automatiques et zones de données. M.
25. S3 : informations de ligne (OPT LINE/HCLN dans l'assembleur) + fenêtre source + opérateurs `#` `?` + A (Load ASCII) + Alt-G + pas à pas par ligne. L.

---------------------------------------------------------------------

## 18. Proposition d'architecture pour l'écran à fenêtres (640x480)

### 18.1 Contraintes du code existant
- Surface hôte : `SCR_W=640`, `SCR_H=480` (p01 l.94-95) ; texte BGI 8x8 (`PText`/`WText` → `OutTextXY`), cellule actuelle 8x10 (`MROW=10`) : grille de 80 colonnes x 48 rangées (480/10).
- Le moniteur redessine TOUT l'écran à chaque événement (`DrawMonitor` : Box plein écran + redessin) ; avec `HideMouse`/`ShowMouse` autour. Avec 5 fenêtres c'est encore acceptable (80x48 caractères au plus) mais mieux vaut des drapeaux « sale » par fenêtre.
- L'écran ST émulé est un bitmap en mémoire émulée (`ScrBase`) ; il est rendu sur l'écran hôte par `BlitScreen(True)` seulement quand `EmuVisible` est vrai. Le moniteur a donc son propre écran « gratuit » : aucune commutation matérielle à émuler.
- Clavier hôte (`PollEvent` p01 l.598) : `ReadKey` ; touches étendues = `256+scan` ; les combinaisons Alt-lettre arrivent comme `256+AltScan[l]` (table `AltScan` p01 l.138, non utilisée aujourd'hui) ; Ctrl-lettre = codes 1..26 ; Shift+flèche n'est PAS distingué de la flèche seule (pas d'information d'état Shift).

### 18.2 Grille proposée (cellule 8x10, 80x48)
```
rangée  0        : titre fenêtre 1 (« 1 Registers »)           [W1, 11 rangées : titre + D0-D7/A0-A7 (8) + SR + PC/instr]
rangées 1-8      : D0-D7 | A0-A7 (+ mémoire pointée)
rangée  9        : SR  (hex, flags, U/S)
rangée 10        : PC + instruction + EA
rangée 11        : titres W2 (cols 0-39) | W3 (cols 40-79)
rangées 12-28    : W2 désassemblage | W3 mémoire                 (17 lignes)
rangée 29        : titres W4 | W5
rangées 30-45    : W4 désassemblage/mémoire/source | W5 mémoire  (16 lignes)
rangée 46        : zone message (journal d'une ligne) : « Breakpoint », « Program terminated » ...
rangée 47        : ligne d'état : touches utiles (F7 F8 F9 ...), adresses, nom du programme
```
- Les dialogues Mon (invite + champ) se dessinent par-dessus, centrés, avec « ESC to abort » juste au-dessus du coin supérieur gauche comme dans le manuel.
- Le journal `MLog` de 300 lignes existant peut devenir une vue « messages » de la zone de la rangée 46 (ou une fenêtre zoomable Alt-Z), afin de ne pas perdre l'écho.
- Tailles : « split » (Alt-S) déplace la frontière entre W2/W4 et entre W3/W5 selon des paliers (0 = masquée, 1/4, 1/2, 3/4, 1 de la hauteur disponible) ; « widen » (Alt-W) déplace la frontière colonne entre les deux colonnes de fenêtres (3 paliers). Cela suffit pour « may hide or uncover another window » (p. 156). Fenêtre 1 inchangée par ces deux commandes, comme dans le manuel.
- Zoom (Alt-Z) : une seule fenêtre occupe rangées 0-45 ; le registre zoomé ajoute les lignes SSP/USP et M0-M9. 

### 18.3 Structures de données (Pascal, TP7/FPC)
```pascal
Const
 MAXVIEW = 8;               { vues empilées par fenêtre }
 NWIN    = 5;
 VK_REG=0; VK_DIS=1; VK_MEM=2; VK_SRC=3;

Type
 TView = Record
  Kind    : Byte;           { VK_* }
  Addr    : LongInt;        { adresse de départ (ou n° de ligne pour VK_SRC) }
  Lock    : String[63];     { expression de verrouillage, '' = libre }
  Locked  : Boolean;
  Small   : Boolean;        { police réduite (Alt-F) }
  HexLn   : Byte;           { numérotation source : 0 aucun, 1 déc, 2 hexa }
  Tab4    : Boolean;        { tabulation 4 (Alt-E sur source) }
  Src     : Integer;        { index dans SrcTab pour VK_SRC, -1 sinon }
  CurOff  : LongInt;        { curseur d'édition (Alt-E) }
  EditAsc : Boolean;        { édition ASCII (Tab) }
 End;

 TWin = Record
  Allowed : Set Of 0..3;    { types permis : W1 [REG,MEM,SRC,DIS], W2/W4 [MEM,DIS,SRC], W3/W5 [MEM] }
  Views   : Array[1..MAXVIEW] Of TView;
  NViews  : Integer;
  Top     : Integer;        { vue visible }
  X,Y,W,H : Integer;        { rectangle en cellules, recalculé par Layout }
  Vis     : Boolean;        { masquée par un split/widen d'une autre fenêtre }
  Dirty   : Boolean;
 End;

 TMonUI = Record
  Win     : Array[1..NWIN] Of TWin;
  Cur     : Integer;        { fenêtre courante 1..5 }
  Zoom    : Boolean;
  RegRows : Integer;        { hauteur fenêtre registres, réglée par Ctrl-flèches }
  SplitL,SplitR : Integer;  { paliers des frontières verticales W2/W4 et W3/W5 }
  Widen   : Integer;        { palier de la frontière colonne }
  Mem     : Array[0..9] Of LongInt;  { M0-M9 : M1..M5 = Win[n].Views[Top].Addr, M8/M9 binaire chargé }
 End;
```
Point d'arrêt (remplace `Bps: Array of LongInt` de p07) :
```pascal
Const BK_SIMPLE=1; BK_STOP=2; BK_COUNT=3; BK_PERM=4; BK_COND=5;
Type TBp = Record
  Addr : LongInt; Kind : Byte;
  N    : LongInt;           { stop : exécutions restantes ; count : compteur }
  Expr : String[63];        { conditionnel }
 End;
Var Bp  : Array[1..MAXBP] Of TBp;  { MAXBP 8 selon le manuel, plus si désiré }
    NBp : Integer;
    TempBp : LongInt;       { point d'arrêt temporaire (Ctrl-T, U, step over), -1 = aucun }
    BdosBp : Integer;       { numéro GEMDOS surveillé, -1 = aucun }
```
`RunCpu` : avant chaque instruction (hors la première), `If PC=TempBp Then arrêt` ; `For I` sur `Bp` ; sinon selon `Kind`. Pour de bonnes performances garder un tableau `Boolean` indexé par `PC Shr 1` (1 Mo / 2 = 512 Kbits) ou un `Set` d'adresses pour tester en O(1) avant de parcourir la table.

Historique :
```pascal
Type THist = Record D,A: Array[0..7] Of LongInt; PC,SR: LongInt; End;
Var Hist: Array[0..HMAX-1] Of THist; HHead,HCnt: Integer;  { anneau ; HMAX=5 au manuel, 64 conseillé }
```
Source :
```pascal
Type TSrc = Record Name: String; Lines: PLineArr; NLines: Integer; Map: PLongArr;  { ligne → adresse, nil = pas d'infos } End;
Var SrcTab: Array[0..3] Of TSrc;
```
(`PLineArr`/`LoadLines` existent déjà dans p04 pour l'éditeur et peuvent être réutilisés.)

Table de commandes :
```pascal
Type TCmd = Record Key: Word; Name: String[16]; Proc: Procedure; Zoomed: Boolean; End;
```
Remplir `Key` avec `256+AltScan[ord(c)-65]` pour Alt-lettre, `1..26` pour Ctrl-lettre, `Ord(c)` pour lettre seule (majuscules/minuscules fusionnées), `K_F*` pour des alias. Une boucle linéaire `For I:=1 To NCmd` suffit.

### 18.4 Boucle d'événements
1. `PollEvent` → code touche.
2. Si un dialogue est actif : lui donner l'événement.
3. Sinon : chercher dans `CmdTab`. Pour Shift-./Shift-, utiliser `>` et `<` (Shift-flèches inexistants dans l'API de touches : prévoir PgUp/PgDn = page, Ctrl-flèches `K_CLEFT/K_CRIGHT` = début/fin de ligne dans les dialogues, et Tab pour la fenêtre).
4. Exécution : les commandes de reprise (Ctrl-R, Ctrl-Z, R...) sont des fonctions `Exec*` qui retournent un code d'arrêt ; `MonRefresh` ajoute une entrée d'historique, recalcule tous les verrouillages (`Eval(Lock)`) et marque les fenêtres « sales ».
5. Rendu : `For W:=1 To NWIN Do If Win[W].Vis And Win[W].Dirty Then DrawWin(W)` ; `DrawWin` choisit `DrawRegs`, `DrawDis`, `DrawMem` ou `DrawSrc` selon `Views[Top].Kind`, avec le rectangle `X,Y,W,H` ; routines de bas niveau `CellText(col,row,S,Inverse)` qui font `PText/WText + Box` pour une cellule 8x10.
6. Fenêtre « Messages » (ligne 46) alimentée par `MonPrint`.

### 18.5 Ordre d'implémentation conseillé (compatible avec les 25 corrections)
a) Corrections moteur (1-5, 12 partiel) sans toucher l'UI.
b) Évaluateur d'expressions (6) car presque tout en dépend.
c) Modèle `TMonUI` + `DrawWin` + `CmdTab` avec les quatre types de fenêtre, défilement et édition mémoire (7-11).
d) Dialogues, points d'arrêt complets, registres et désassemblage conformes (8, 12-14).
e) Run/Slow/Watch, historique, M0-M9, verrouillage, vues empilées, recherche (15-19).
f) Fichiers (B/S/E/A), commandes diverses, Préférences, impression (20-24).
g) Débogage source (25) : OPT LINE/HCLN dans l'assembleur, puis fenêtre source.

### 18.6 Contrôle des risques
- Garder `RunMonitor(Prog, Prompt)` comme point d'entrée : appelé depuis `CmdDebug`, `CmdMonitor` (Alt-M, p13 l.494) et le démarrage (p13 l.816). Les commandes d'application (menus) n'ont pas à changer.
- `MonActive`/`EmuVisible` (p08) pilotent `BlitScreen` ; ne pas y toucher : seules les fonctions `MonYield` et `ViewProgramScreen` changent EmuVisible.
- Tester sur un exemple minimal (JSR/RTS, DBF, TRAP #1 Pterm, ILLEGAL, accès impair) pour valider R1/E1/E2 avant de bâtir l'UI.
