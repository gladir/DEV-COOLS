# DEVPAC.PAS : état de conformité avec le manuel de Devpac 3

Les trois fichiers `ECARTS-*.md` de ce dossier sont les rapports d'écarts rédigés AVANT les corrections
(comparaison du manuel Devpac 3, OCR de `Devpac_v3_Manual.pdf`, avec le code). Ce fichier résume l'état actuel.
`FORMAT-LINE-HCLN.md` décrit le format des informations de ligne écrites par OPT LINE / OPT HCLN.

## Éditeur
Fait : 7 fenêtres GEM (un tampon par fenêtre, Alt-1..7, Cycle, Close, Arrange Overlap/Tile/Vertical, plusieurs fichiers
en ligne de commande, INCLUDE lus depuis les fenêtres ouvertes) ; menus Desk/File/Edit/Block/Search/Options/Tools/Program
avec sous-menus ; Alt-lettre, Ctrl/WordStar, blocs F1-F5 ; touches Maj/Ctrl/Alt lues directement (Shift-Alt-S, Shift-flèches,
Ctrl-chiffre...) ; menu Tools à 20 outils configurables, Run Other, Run with Shell, Environment, Resident ; Fonts (Ctrl-G) ;
listes Add/Remove (double-clic, glisser) ; dialogues d'assemblage Control/Listing/Options/Optimisations ; Output Symbols ;
Debugger options (MON.INF) ; préférences, signets, `HISOFTED.INF` ; double-clic/glisser par mot ; souris sans clic perdu.
Reste à faire : Shift-Shift pour interrompre un assemblage ; police TOS 8x8 pour la console émulée ; raccourcis Alt-pavé
des outils 15 à 20 ; réglages mémorisés sans effet (Low memory assembly, tampon, résident).
Réserve : sous un vrai Turbo Pascal 7, `TMemFileHook` (type procédural) et le tampon complet par fenêtre n'ont pas été testés.

## Assembleur GenST
Fait : voir le détail de la phase 1 (avertissements/codes retour, options GEN, directives, macros, OPT...) ; en plus :
LINE/HCLN/XDEBUG ; AsmOutputSymbols et fichiers `.GS` (format propre au projet, le manuel ne le spécifie pas) ; formats
DRI (L2) et Lattice (L7) avec XDEF/XREF/MODULE ; S-records ; 68010/20/30/40 complets (modes mémoire indirecte, bitfields,
CAS, PACK, MOVE16, CINV...) ; 68881/68882 complet ; MMU 68851/68030/68040 ; constantes et directives flottantes
(DC/DS/DCB.S/D/X/P, FEQU, FOPT) vérifiées contre GNU as ; optimisations O1 à O12 avec comptes rendus ; 15 messages de
l'annexe B qui n'avaient aucun chemin d'émission en ont un.
Format GST (L1, `OPT GST`, `+GST`, `-L1`, extension `.BIN`) : écrit d'après l'appendice B du manuel du linker QL
(format SROFF, fourni dans le dépôt de travail) : SOURCE, COMMENT, DEFINE, XDEF, XREF multi-termes, SECTION, ORG, OFFSET, END,
MODULE (plusieurs modules par fichier = bibliothèque). Validé : l'exemple B.2.5 du manuel est reproduit octet par octet,
un décodeur et un éditeur de liens écrits d'après la spécification relient deux modules et une bibliothèque en une image identique à l'assemblage
mono-fichier. Limites : seulement trois sections (TEXT, DATA, BSS) et pas de COMMON ; un seul import par expression, pas d'import
en octet ; symboles tronqués à 32 caractères ; les extensions « non officielles » de Devpac pour les bibliothèques et le sens exact
de XDEBUG pour GST ne sont pas documentés ; pas de bits signé/non signé dans la règle de troncature ; aucun test avec LinkST réel ni avec de vrais `.BIN` Devpac.
Coquille du manuel QL : l'exemple imprime `FB 02` devant « SECTION », la syntaxe documentée est `FB 04` ; c'est `FB 04` qui est écrit.
Reste à faire : FOPT ROUND/PREC sans effet ; conversion packed arrondie au-delà de 17 chiffres ; pas de test
sur hôte big-endian ; messages impossibles à déclencher : `assembly interrupted`, `repeated include file`, `invalid printer parameter`.
Les formats DRI et Lattice ont été validés avec un décodeur et un éditeur de liens écrits pour le projet, d'après les
spécifications publiques, sans linker réel.

## Moniteur Mon
Fait : écran à fenêtres, commandes et expressions du manuel, points d'arrêt de tous les types, historique, recherche ;
exceptions 68000 avec gestionnaires installés par le programme (cadres de pile, RTE, interception par Mon) ; références
croisées de P (labels Lxxxxxx) ; Run Slowly, Screen timer ; textes allemands ; désassembleur 68010/20/30/40/68881 ;
Ctrl-Haut/Bas et Alt-Haut/Bas ; débogage source (fenêtre Source avec infos LINE/HCLN, pas à pas par ligne, points d'arrêt
sur ligne, opérateurs # et ?, recherche, bascule source/désassemblage).
Reste à faire : désassembleur MMU (PMOVE, PTEST... affichés en dc.w) ; interruptions matérielles ; hook utilisateur sur
TRAP #1/#2/#13/#14 ; pas par ligne avec plusieurs instructions sur la même ligne (macros) ; message quand le source est
introuvable.
Hors périmètre de l'émulateur : AMON, ROM, NOTRACE, Follow traps pour les TRAP émulés, modes couleur, FPU et 68020+ à l'exécution.
