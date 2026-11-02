# DEVPAC.PAS : état de conformité avec le manuel de Devpac 3

Les trois fichiers `ECARTS-*.md` de ce dossier sont les rapports d'écarts rédigés AVANT les corrections
(comparaison du manuel Devpac 3, OCR de `Devpac_v3_Manual.pdf`, avec le code). Ce fichier résume ce qui a
été corrigé ensuite et ce qui reste à faire. Les rapports d'écarts restent la liste de référence du reste à faire.

## Éditeur (menus, touches, fichiers, préférences)
Fait : touches Alt-lettre du manuel ; touches de bloc F1-F5, Shift-F4, Shift-F5 ; presse-papiers (Delete Block = Cut) ;
commandes Ctrl du manuel et WordStar ; ligne d'état avec les messages exacts et bip ; Find/Find Previous/Replace/
Replace All depuis le curseur ; menus Desk/File/Edit/Block/Search/Options/Tools/Program avec sous-menus et raccourcis ;
Check, Previous error, erreurs recalées pendant l'édition ; File : New/Load/Insert/Revert/Close/Save As/Save/Delete File/
Change Directory, dialogue de sortie ; préférences complètes ; signets ; `HISOFTED.INF` ; widgets (cases à cocher,
pop-up, Alt-lettre sur les boutons) ; table ASCII, Help, About ; double-clic, glissière, marge.
Reste à faire : plusieurs fenêtres (jusqu'à 7) et Arrange/Cycle ; menu Tools à 20 outils configurables ; Fonts ;
listes Add/Remove ; Output Symbols ; plusieurs fichiers en ligne de commande.
Limite technique : `ReadKey` (PtcCrt) ne donne pas l'état de Maj ; Shift-Alt-S, Shift-Alt-J, Shift-flèches et Shift-Ins
sont remplacés (F8 = Save, Alt-U = erreur suivante, Alt-F1..F8 / Ctrl-F1..F8 = signets, Alt-C = table ASCII).

## Assembleur GenST
Fait : plus de perte silencieuse (DC sans limite, 40000 lignes et relocations) ; avertissements de l'annexe B et codes
retour 0/5/10/20 ; options de ligne de commande GEN (-B -C -E -H -I -L -O -P -Q -S -T -V -W -Z, +OPT) ; /DEF: ;
ELSEIF, IIF, EQUR, CARGS, RADIX, INCDIR, RORG, MACHINE, EQUENV ; labels @nom, 1$, indentés avec ':' ; OFFSET ;
précédence des opérateurs du manuel ; branches arrière sans taille = mot ; macros (<...>, \#, \?, \<sym>, \\, 35 paramètres,
continuation &) ; OPT complet avec « invalid option » ; directives de listing appliquées ; OUTPUT .ext ; COMMENT HEAD= ;
sortie S-records ; 68020 (index à échelle, link.l, mul/div 32 bits) avec OPT P=68020 ; messages d'erreur de l'annexe B.
Reste à faire : formats GST, DRI et Lattice (refusés par « linker format restriction ») ; 68881/FPU/MMU ; LINE/HCLN
(débogage source) ; optimisations O2-O6, O8-O12 et leurs avertissements ; EXTB/RTD/BKPT/MOVEC ; modes 68020 mémoire
indirecte ; erreur « forward reference » pour EQU.
Changement de comportement : `-B -L -S -O` avec un seul tiret prennent le sens GEN ; les anciens sens restent avec `/B /L /S /O`.

## Moniteur Mon
Fait : réécriture en écran à fenêtres (registres, désassemblage, mémoire, source), commandes Alt-/Ctrl-/lettres du manuel,
dialogues Mon, expressions (7 niveaux de priorité), points d'arrêt (simple, stop, count, permanent, conditionnel),
historique, recherche, chargement/sauvegarde ; bugs corrigés (step over, reprise après exception, PC fautif) ;
le tutoriel du chapitre 1 du manuel se joue entièrement.
Reste à faire : débogage source (dépend de LINE/HCLN) ; gestionnaire d'exception installé par le programme ;
références croisées de la commande P ; Run Slowly ; Shift+flèches (limite PtcCrt, remplacé par PgUp/PgDn, < et >) ;
traduction allemande des nouveaux dialogues.
Hors périmètre de l'émulateur : AMON, ROM, NOTRACE, Follow traps, modes couleur, FPU, 68020+.
