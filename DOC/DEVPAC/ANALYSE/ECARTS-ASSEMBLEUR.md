# Ecarts ASSEMBLEUR : manuel Devpac 3 (chapitre 3 « The Assembler » + annexe B) contre DEVPAC.PAS

Sources lues : OCR `/tmp/claude-0/doc/txt2/p063..p150.txt` (chapitre 3 complet, pages imprimees 55 a 134) et `p229..p237.txt` (annexe B, pages 213 a 221 : l'OCR est TERMINE et lisible).
Code lu en entier : `parts/p02.pas` (expressions), `p03.pas` (operandes, encodage), `p04.pas` (lignes, macros, directives), `p05.pas` (passes, listing, PRG/Hunk), plus `p13.pas` (ligne de commande, batch) et `p11.pas` (dialogue d'options).
Banc de test (rien dans le depot n'a ete modifie) : `scratchpad/gapasm/` (copie du binaire `DEVPAC`, `t.sh`, `tt.sh`, `cmpgas.py`). Les verifications de comportement ont ete faites avec `DEVPAC /B fichier.s` (LANGUAGE=EN). Un controle croise de 160 instructions 68000 contre `m68k-linux-gnu-as` n'a montre aucun ecart d'encodage (seuls des artefacts de relocation de gas).
Numerotation des pages : celles de l'imprime (p.NN). Dans ce chapitre : fichier `pNNN.txt` = page imprimee + 16 (et non +8).

Legende. Gravite : **B** bloquant (donnees ou code faux en silence, ou syntaxe tres courante refusee), **I** important, **m** mineur. Taille de la correction : XS (moins de 20 lignes Pascal), S (moins de 80), M (moins de 250), L (moins de 800), XL (plus de 800).

---------------------------------------------------------------------

## 0. Resume (15 lignes)

1. L'assembleur du clone est un « GenST » 68000 pur, un seul format de sortie (PRG Atari ; BIN brut si ORG) ; Devpac 3 est un assembleur 68000-68040/68881/68851 a 5 formats de sortie.
2. Trois pertes de donnees silencieuses ont ete reproduites : `DC` tronque a 40 operandes (60 donnes, 40 emis), fichiers sources tronques a 16000 lignes, relocations tronquees a 16000 (PRG corrompu), sans aucun message.
3. Aucun avertissement n'existe : `Warn3` est defini mais jamais appele ; donc 0 des 20 avertissements de l'annexe B, et le code retour 5 est impossible.
4. Code retour : le batch rend 0/1/2/3 ; le manuel specifie 0/5/10/20/100+. Les options GEN (`-B -C -D -E -H -I -L -M -O -P -Q -S -T -V -X -W -Z +opt`) ne sont pas reconnues et, pire, `/B /D /L /M /O /S /X` ont un autre sens (ex. `/B` = batch, pas « pas de fichier binaire »).
5. `/DEF:n=v` est analyse mais jamais appliquee (`ApplyPreDefs` jamais appelee) : le `-E` du manuel ne fonctionne pas.
6. Syntaxe courante absente : `ELSEIF`, `IIF`, `EQUR`, `OFFSET` (ignore et FAUX : emet des octets), `CARGS`, `RADIX`, `RORG`, `INCDIR`, `MODULE`, `EQUENV`, `MACHINE`, `LISTCHAR`, `FEQU`, `FOPT`, `DC.S/D/X`, `__LK`, `__G2`, `__RS`, `\#`, `\?n`, `\<sym>`, `\A..\Z`, `&` de continuation.
7. Labels : `nom:` indente refuse, `@nom` refuse (pris pour de l'octal), `1$` refuse, labels de plus de 63 caracteres introuvables (le manuel : 127 significatifs).
8. Expressions : la precedence des operateurs ne suit pas le manuel (`1+2<<3` donne 24 au lieu de 17 ; `6&3+1` donne 4 au lieu de 3 ; `1|2^3` donne 1 au lieu de 0) ; pas de flottants ; types relatifs/absolus controles de facon incomplete.
9. Macros : seulement `\1..\9`, `\0`, `\@` et `NARG` ; les parametres entre `< >` contenant espace ou virgule sont casses ; pas de listing en mode NOMEX par defaut.
10. Branches : un `Bcc`/`BRA`/`BSR` sans taille vers l'arriere devient court d'office (le manuel : mot par defaut) ; `BSR.S`/`BRA.S` vers l'instruction suivante donnent un NOP sans erreur ; pas d'erreur « odd address ».
11. `OPT` : seules D, O/O1/O2, C, W sont reconnues ; tout le reste (NOCASE, MEX, P=, AUTOPC, CHKIMM, GST...) est accepte en silence et ignore, sans message « invalid option ». `OPT O+` ne fait que des branches courtes (pas O2..O12).
12. Jeu d'instructions : 68000 complet et correct ; rien de 68010+ (MOVEC, RTD, EXTB, BKPT, TRAPcc, DIVS.L, LINK.L...), ni modes 68020 (`([bd,An],Xn,od)`), ni 68881/68851. Pire : echelle d'index `(a0,d1.w*4)`, `link.l`, `divs.l`, `muls.l` sont acceptes et assembles FAUX en silence.
13. Listing : `LIST/NOLIST/PLEN/LLEN/TTL/SUBTTL/SPC/PAGE/FORMAT` ignores ; pas d'en-tete de page, pas de listing ecran/imprimante, expansions de macros toujours listees, table des symboles toujours imprimee.
14. Sortie : `OUTPUT .ext` cree un fichier nomme `.ext` ; `OUTPUT` l'emporte sur `-O`/dialogue (c'est l'inverse dans le manuel) ; `COMMENT HEAD=` (flags TT/Falcon) ignore ; pas de HCLN/LINE ; pas de GST/DRI/SREC/Lattice (`OPT GST` etc. donnent un .PRG sans message).
15. Interface : un seul dialogue « Assembler options » (7 champs) au lieu de Control / Listing / Options / Optimisations ; pas de commande Check ni Output Symbols (.GS) ; les messages d'erreur n'ont pas le libelle de l'annexe B (voir section 15).

---------------------------------------------------------------------

## 1. Ligne de commande, dialogues, codes retour

**[A1] Options de ligne de commande GEN.TTP absentes ou de sens different** — Gravite I · Taille M
- Manuel (p.62-64) : `-B` pas de binaire, `-C` casse insensible, `-D` debug, `-E sym=expr,...` labels, `-H` en-tetes pre-assembles, `-I<chemin>`, `-L`/`-L2`/`-L6`/`-L7` formats, `-M` memoire basse, `-O<fichier>`, `-P<listing>`, `-Q` pause, `-S` table des symboles, `-T<n>` tabulation, `-V<options>`, `-X` debug etendu, `-W<fichier>` fichier d'options, `-Z` listing passe 1, et `+OPTION` (noms longs d'OPT). Exemple : `gen test -oc:\test.prg -p`.
- Actuel (`p13.pas` ParseCommandLine/IsOption) : jeu different `/A /X /D /M /B /L /S /O /OUT: /INC: /DEF: /NODISK /NOGEM /FLx: /ATARIST /AMIGA`, prefixe `/` ou `-`. Collisions : `-B` = batch sans graphisme, `-D` = assembler puis deboguer, `-X` = assembler puis executer, `-M` = lancer Mon, `-L` = produire un .LST, `-S` = symboles de debug, `-O` = optimiser les branches. Testes : `-ofoo.prg`, `+DEBUG`, `-p`, `-q` ne sont pas des options : ils sont pris pour des noms de fichiers (« Cannot open -ofoo.prg », code retour 2). Pas de `-W`, pas de mode « sans binaire » sauf `/NODISK` (qui assemble vers un fichier temporaire).
- Correction : ajouter, sans casser les options actuelles, un second analyseur « mode GEN » (options collees a leur valeur, `+NOM`) ; `-O`/`-L`/`-S` etc. a retablir au sens du manuel dans ce mode.

**[A2] `-E` / `/DEF:` jamais appliquee** — Gravite I · Taille XS
- Manuel (p.64 et p.80) : `-E sym=expr,sym2` definit des symboles absolus (valeur 1 si `=expr` omis) ; liste « 'EQU' symbols » du dialogue Control (p.57).
- Actuel : `/DEF:FOO=3` est stocke dans `PreDefs` mais `ApplyPreDefs` (p13.pas) n'est appelee nulle part. Test : `dc.b FOO` avec `/DEF:FOO=3` donne « Undefined symbol: FOO ». Le dialogue n'a pas de liste EQU. De plus `DefSym(...,Kind=1)` (SET) serait utilise : le manuel parle d'un symbole absolu (a corriger en EQU, kind 0, sinon `IFD`/redefinition se comportent mal).
- Correction : appeler `ApplyPreDefs` au debut de chaque `RunPass` (apres `FreeSyms` de AssembleSource, avant la passe) ; accepter `a=expr,b=expr` avec evaluation.

**[A3] Codes retour** — Gravite I · Taille S
- Manuel (p.65) : 0 OK, 5 avertissement(s), 10 erreur(s), 20 erreur fatale, 100+ echec d'initialisation.
- Actuel (`BatchRun`) : 0 si ok, 1 si erreurs d'assemblage, 2 si fichier introuvable/pas de source, 3 si le programme execute echoue ; les erreurs fatales n'existent pas (include introuvable : l'assemblage continue) ; jamais 5 (pas d'avertissements, voir [W1]).
- Correction : mapper 0/5/10/20 dans BatchRun (en gardant 1/2/3 derriere une option si des scripts existants en dependent).

**[A4] Dialogues d'options reduits a un seul** — Gravite I · Taille L
- Manuel (p.55-60) : les 4 premieres entrees du menu Options : **Control** (Ignore multiple includes, Low memory, No warnings, popup Debug symbols None/Normal/Exports = NODEBUG/DEBUG/XDEBUG, popup Line debug Standard/Compressed, popup Format Atari/GST/DRI/Lattice/S-records/RAM + Buffer size, liste « 'EQU' symbols », Output to, liste « 'INCLUDE' directories », liste Pre-assembled includes), **Listing** (First pass listing, List macro expansions, List conditionals only, List symbol table, popup None/Screen/Printer/Disk, List to, Tab size), **Options** (68851, 68881/2, Add automatic PC-relative, Allow narrow zero operands, Base displacement default word, Case insensitive labels, Check absolutes for missing #, Check memory bitfield offsets, Ensure PC-relative code, No even indirection checking, No expression type checking, No supervisor instructions, Outer displacement default long, Underscore for local labels, popup Processor 68000..68040/68332, Symbol significance 8-127, popup Default branch size Short/Word/Long), **Optimisations** (11 lignes Y/W/N : ADDA/SUBA->LEA, ADD/SUB->ADDQ/SUBQ, branches arriere, deplacements de base, branches avant, deplacements indirects, LEA->ADDQ/SUBQ, MOVEA.L->MOVEA.W, MOVE.L->MOVEQ, branches nulles->NOP, deplacements externes).
- Actuel (`p11.pas` AsmOptionsDlg, menu Options > « Assembler options... ») : une seule boite : Output Memoire/Disque, Debug oui/non, Listing oui/non, Optimise oui/non, Symboles Casse/Libre, Include dir (un seul repertoire), Output file, boutons Cancel/Save/OK. Pas de listes (EQU, INCLUDE multiples, pre-assembles), pas de popups Format/Processor/Line debug/Branch size, pas d'option « No warnings », « Ignore multiple includes », pas de dialogue Listing ni Optimisations. Le menu Program n'a ni **Check** (Alt-Y) ni **Output Symbols** (p.48, 61, 77), ni Run Directory, ni « Previous error » (Ctrl-J).
- Correction : ajouter les variables d'options correspondantes d'abord (voir [O1]) puis les dialogues. Tout champ de dialogue sans effet reel est a eviter : commencer par Control/Listing/Optimisations une fois les options implementees.

**[A5] Memoire et mode « tampon »** — Gravite m · Taille XS
- Manuel (p.57, 64) : « Buffer size... », « Low memory assembly », message « program buffer full ». Sans objet pour le clone (assemblage vers fichier temporaire `DEVPAC.TMP`, 512 Ko par section). Rien a faire, sauf accepter les cases en no-op pour compatibilite des fichiers de preferences.

**[A6] Fichier d'options `-W`, pause `-Q`, tabulation `-T`** — Gravite m · Taille S (voir A1).

---------------------------------------------------------------------

## 2. Types de fichiers binaires et noms de sortie

**[B1] Un seul format de sortie** — Gravite I (ST pur : seul ATARI est indispensable) · Taille L par format
- Manuel (p.65-66, 117-131) : ATARI (PRG, L0), GST (`.BIN`, L1), DRI (`.O`, L2), SREC (`.MX`, L6), LATTICE (`.O`, L7), formats selectionnes par dialogue, `-L`, ou `OPT nom` avant tout code ; `__LK` donne le type.
- Actuel : PRG Atari (en-tete `$601A`, relocation, table de symboles DRI), et `.BIN` brut quand `ORG` est utilise. Test : `OPT GST`, `OPT DRI`, `OPT SREC`, `OPT LATTICE` sont acceptes SANS message et produisent un `.PRG` ; `OPT ATARI` idem. `__LK` n'existe pas.
- Estimation : SREC (M : S0/S1-S3/S9-S7, 28 octets par ligne, `SECTION nom,offset`, ORG obligatoire, avertissement « no ORG specified »), GST (L : hunks QL, XDEF/XREF/MODULE, imports dans les expressions), DRI (L : table de symboles/relocs CP/M-68k), Lattice (L : HUNK_UNIT/EXT, symboles base-relatifs `_sym(a4)`). Priorite basse pour un usage « programmes TOS directs » ; mais a minima : faire echouer proprement (« linker format restriction ») plutot que d'ignorer `OPT GST/DRI/SREC/LATTICE`.

**[B2] `ORG` en mode ATARI** — Gravite m · Taille S
- Manuel (p.121) : « The binary file produced has the standard GEMDOS header at the front, but no relocation information » ; plusieurs `ORG` permis « but no padding of the file is done ».
- Actuel : `ORG` n'est accepte qu'en premiere instruction (sinon « ORG must be the first statement ») ; fichier de sortie = `.BIN` brut SANS en-tete GEMDOS (test : `org $1000 / nop` donne `4e71`) ; un `ORG` plus loin remplit de zeros (`ReserveBytes`). L'interpretation « no padding » est ambigue dans l'OCR : a confirmer avec Devpac reel. `RORG` absent (voir [D12]).

**[B3] Nom du fichier de sortie** — Gravite I · Taille XS
- Manuel (p.66, 97) : priorite : nom explicite (dialogue/`-O`) > absence d'`OUTPUT` -> source + `.PRG/.BIN/.O/.MX` > `OUTPUT .ext` (extension seule) > `OUTPUT nom`. Extensions Atari .PRG .TOS .TTP .ACC .APP .GTP.
- Actuel (AssembleSource) : `OUTPUT` ecrase TOUJOURS le nom explicite (`If OutFileName<>'' Then OptOutName:=OutFileName`). Teste : `output zzz.prg` avec `/OUT:qq.prg` cree `zzz.prg`. `output .tos` cree un fichier nomme litteralement `.tos`.
- Correction : appliquer les 4 regles du manuel.

**[B4] En-tete PRG : drapeaux `COMMENT HEAD=`** — Gravite I (TT/Falcon) · Taille S
- Manuel (p.119-120) : `COMMENT HEAD=expression` fixe le « program load longword » (bit 0 fast load, bit 1 alt RAM load, bit 2 alt RAM malloc, bits 28-31 taille TPA).
- Actuel : `COMMENT` est dans la liste des directives ignorees (Directive, p04.pas). Test : `comment HEAD=7` laisse les octets 22-25 de l'en-tete a 0.
- Correction : evaluer l'expression apres `HEAD=` et ecrire le long a l'offset 22 de l'en-tete dans `WritePRG`.

**[B5] Informations de debug** — Gravite m · Taille M
- Manuel (p.118-119) : `OPT DEBUG` = symboles relatifs, 8 caracteres ; `OPT XDEBUG` = format etendu HiSoft (22 caracteres) ; `OPT LINE` = section de debug LINE (8 octets/ligne) ; `OPT HCLN` = lignes compressees (2 octets/ligne).
- Actuel : `OptDebug` unique (D/DEBUG seulement ; `XDEBUG`, `LINE`, `HCLN` ignores). `WritePRG` ecrit toujours le format etendu (flag `$48` + 14 octets) pour les noms de plus de 8 caracteres meme avec DEBUG. Les symboles absolus (EQU) ne sont pas ecrits (conforme). Mon n'a pas de support source LINE/HCLN (pas de `grep` positif sur HCLN dans le depot).

**[B6] Mode Amiga** — hors manuel (extension du clone ; `WriteHunk`). Non evalue.

---------------------------------------------------------------------

## 3. Format des lignes, champs, labels

**[C1] Label indente suivi de `:`** — Gravite B · Taille S
- Manuel (p.68) : « The label should normally start at column 1, but if a label is required to start at another position then it should be followed immediately by a colon (:) ». Exemple p.69 : `indented: link a6,#-10`.
- Actuel (SplitLine) : seule la colonne 1 introduit un label. Test : `  indented: nop` -> « Unknown opcode: INDENTED: », `label2: ; c2` indente de meme.
- Correction : dans SplitLine, si le premier jeton se termine par `:` (et n'est pas un mnemonique), c'est un label meme indente.

**[C2] Label commencant par `@`** — Gravite I · Taille XS
- Manuel (p.68) : `@` est permis en premier caractere sauf s'il est suivi d'un chiffre 0-7 (octal). Exemple legal `@test`.
- Actuel : l'evaluateur traite `@` comme prefixe octal inconditionnel (ExprPrimary) : `bra @test` -> « Bad expression ». (Le label `@test` est accepte a la definition, mais jamais referencable.)
- Correction : si `@` n'est pas suivi de 0-7, lire un identifiant ; ajouter `@` a IsIdStart/IsIdChar selon les regles.

**[C3] Labels locaux `nnn$`** — Gravite I · Taille S
- Manuel (p.68, 79) : « Sequences of digits terminated by a $ are also local labels ».
- Actuel : `1$ bne.s 1$` -> « Bad expression » (ExprPrimary lit `1` comme nombre). Les formes `nom$` et `.nom` fonctionnent (testees).
- Correction : en tete d'ExprPrimary, reperer chiffres + `$` ; et dans SplitLine/DefLabel accepter un label « chiffres$ ».

**[C4] Longueur significative des symboles** — Gravite B · Taille XS a S
- Manuel (p.59, 68, 86) : 127 caracteres significatifs par defaut (minimum 8, options `Cx`, `Cx+`, `Cx-`).
- Actuel : `TSym.Name : String[63]` et `AddSym` tronque a 63, mais `FindSym` compare le nom COMPLET : un label de plus de 63 caracteres est defini puis introuvable. Test : label de 71 caracteres puis `bra` dessus -> « Undefined symbol ». `LastGlobal` est aussi `String[63]`.
- Correction : passer `Name` a `String[127]` (ou chaine dynamique), faire la troncature a N caracteres significatifs aussi dans FindSym (et dans LocalName).

**[C5] Options de casse et de longueur de symbole** — Gravite I · Taille S
- Manuel (p.86-87) : `CASE`, `NOCASE`, `Cx`, `Cx+`, `Cx-`, `C+`/`C-` ; bascule possible n'importe ou ; en mode insensible, les noms exportes sont mis en majuscules.
- Actuel (DirOpt) : seulement `C+`/`C-` (nom `C` ou `C+`). Test : `opt nocase` suivi de `Test`/`test` ne signale aucun doublon (ignore). `OptCase` est reinitialise a chaque passe (OK). Note : mnemoniques/registres/directives sont bien insensibles a la casse (teste).
- Correction : voir [O1] (table d'options).

**[C6] Variantes de nom de macro et symboles reserves** — Gravite m · Taille S
- Manuel (p.68) : un label ne doit pas porter un nom de registre ni SR/CCR/USP... ; trois symboles reserves `__LK`, `__RS`, `__G2` ; `.` initial permis dans un nom de macro.
- Actuel : `d0 nop` accepte sans erreur (teste) ; `.dot macro` est accepte (teste). Local `.x` sans label global precedent accepte (le manuel : « you must have at least one real label before the first local one » -> erreur `local not allowed`).

**[C7] Champ commentaire** — Gravite m · Taille -
- Manuel (p.69, 96) : tout espace blanc apres les operandes demarre le commentaire ; `dc.b 1,2,3 ,4` ne genere que 3 octets.
- Actuel : l'espace avant une virgule est tolere (`move.l d0 , d1` ok ; `dc.b 1,2,3 ,4` genere 4 octets). Plus permissif que Devpac, sans danger, mais une source qui s'appuie sur « , 4 est un commentaire » (rare) differe.

**[C8] Lignes trop longues / trop nombreuses** — Gravite B · Taille XS
- Manuel : pas de limite documentee.
- Actuel (LoadLines, p04.pas) : lignes tronquees a 250 caracteres sans message ; `MAXLN = 16000` lignes par fichier (source principale ET chaque include) : lignes suivantes IGNOREES sans erreur. Test : fichier de 16100 `nop` -> « CODE 32000 », « No errors ». A transformer au minimum en erreur « source too large », ideal : tableau dynamique.

**[C9] Alignement** — voir [E6] (alignement des instructions : conforme).

---------------------------------------------------------------------

## 4. Expressions

**[D1] Priorite des operateurs** — Gravite I · Taille S
- Manuel (p.70) : par ordre decroissant : moins/plus unaire ; `~` ; `<<` `>>` ; `&` `|` `^` (meme niveau) ; `*` `/` ; `+` `-` ; comparaisons (`=` `<` `>` `<>` `<=` `>=`) ; gauche-droite a egalite.
- Actuel (ExprLevel, p02.pas) : niveaux 0 comparaisons, 1 `|`, 2 `^`, 3 `&`, 4 decalages, 5 `+ -`, 6 `* / %`. Resultats testes : `1+2<<3` = 24 (manuel : 17) ; `6&3+1` = 4 (manuel : 3) ; `5&3*2` = 4 (manuel : 2) ; `1|2^3` = 1 (manuel : 0) ; `2|4*2` = 10 (manuel : 12). `1+2*3`, `-3<<1`, `~0>>28`, `10-2-1` corrects.
- Correction : reordonner les niveaux selon le manuel (decalages > logiques > multiplicatifs > additifs > comparaisons) ; `%` modulo n'est pas dans le manuel (extension du clone, gardee, pas de conflit sauf avec le prefixe binaire).

**[D2] Constantes caractere** — Gravite m · Taille XS
- Manuel (p.71) : 1 a 4 caracteres, justifiees a droite complete par des zeros ; `'it''s'` ; guillemets simples ou doubles ; (l'OCR donne `$6974277C` pour `'it's'` : c'est `$69742773`, erreur d'OCR evidente).
- Actuel : valeurs correctes (`'abcd'`=61626364, `'ab'`=6162, `"Q"`=51, `'it''s'`=69742773). Pas d'erreur au-dela de 4 caracteres : `'abcde'` donne 62636465 sans message. Chaine non fermee `dc.b 'abc` -> « Value out of range » (le manuel : « missing quote »).

**[D3] Nombres** — Gravite m · Taille S
- Manuel (p.71) : decimal, `$` hexa, `@` octal, `%` binaire ; `RADIX` 2/4/8/10/16 (p.97).
- Actuel : tous testes OK (`$12f`, `@17`, `%101`) ; en plus `0x..` (extension). `RADIX` n'existe pas (voir [D13]).

**[D4] Nombres flottants et directives FP** — Gravite m (ST) · Taille L
- Manuel (p.72, 106-107) : constantes decimales `2.0`, `1E6`, hexa `$..`/`:..`, `FEQU.x`, `FOPT`, `DC.S/D/X/P`, arithmetique interne (seul le `-` unaire).
- Actuel : aucun. `dc.s 1.0` -> « Bad expression » ; `fequ.x` -> « Bad size suffix » (le suffixe `.X/.D/.P` est rejete par ProcessLine) ; `fopt` -> « Unknown opcode ».

**[D5] Table des types de combinaisons (relatif/absolu)** — Gravite I · Taille S
- Manuel (p.73) : decalages, logiques, `*`, `/` : seulement A op A ; `+` : A+A, A+R, R+A ; `-` : A-A, R-A (=R), R-R (=A), pas A-R ; comparaisons : A op A, R op R (=A).
- Actuel : respecte pour `+ - * /` (test : `l1+l2`, `1-l1`, `-l1`, `l1*2` -> « Illegal relocation »). NON respecte pour les decalages, `& | ^ ~` et les comparaisons : acceptes avec un operande relatif, la relocation est perdue en silence (`dc.l l1>>1` -> 0, `dc.l l1&1`). Pas d'option `NOTYPE`/`TYPE`.
- Correction : lever l'erreur de type dans ces niveaux sauf `NOTYPE`.

**[D6] Symboles relatifs dans une valeur 8/16 bits** — Gravite I · Taille S
- Manuel (annexe B, p.219-221) : « relocation not allowed », « relative not allowed », « relative cannot be relocated » (avertissement).
- Actuel : `move.w #label,d0`, `dc.w label`, `dc.b label` emettent la valeur non relocalisee, sans erreur (test `move.w #l,d0` -> `303c0000`). PRG ne peut pas relocaliser un mot : Devpac signale une erreur.
- Correction : dans PutImm/DirDC/EncEA, si `S>=0` et taille < 4 (et pas PC-relatif) -> Err « relocation not allowed ».

**[D7] Symboles reserves `__LK`, `__G2`, `__RS`, `NARG` et IFD dessus** — Gravite I · Taille S
- Manuel (p.98, 104, 114, 127) : `__G2` (version + bits 8-15 = processeur + bits 16-23 = 0 sur Atari), `__LK` (0 Atari, 1 GST, 2 DRI, 6 SREC, 7 Lattice), `__RS` (compteur RS), `NARG` ; `IFD`/`IFND` marchent sur les symboles reserves.
- Actuel : seul `NARG` est reconnu (ExprPrimary). Test : `dc.l __LK` / `__G2` / `__RS` -> « Undefined symbol ». `ifd NARG` est faux (le symbole n'est pas dans la table).
- Correction : XS-S : retourner CurRS (RSCount), 0 pour `__LK` (Atari), une constante pour `__G2` (≥ 43 en bits 0-7, processeur en 8-15).

**[D8] Fonctions/operateurs hors manuel** — aucun a ajouter (le manuel ne definit ni fonction ni operateur additionnel). `$` seul et `*` donnent le PC (le manuel ne documente que `*`).

**[D9] Division par zero, 32 bits, comparaisons** — conformes (testes : `10/0` -> erreur ; comparaisons -1/0 ; `=`/`==`/`<>`/`!=`/`!` ok).

---------------------------------------------------------------------

## 5. Modes d'adressage et jeu d'instructions

**[E1] Modes 68020+** — Gravite I (hors usage ST pur) · Taille XL
- Manuel (p.74-77) : registre d'index avec echelle `Xn.size*scale` (1,2,4,8), `(bd,An,Xn)`, `([bd,An],Xn,od)`, `([bd,An,Xn],od)`, memes formes en PC, suppression `ZAn`/`ZPC`, `.W/.L` sur bd/od, options `BDW BDL ODW ODL`, `(d3.l)`, `(d16,An)`.
- Actuel : seulement les 8 modes 68000 + la syntaxe `(d,An)`, `(d,An,Xn)`, `(d,PC)`, `(d,PC,Xn)`. DANGER (code faux en silence, teste) : `move.w (a0,d1.w*4),d0` -> `3030 1000` (echelle ignoree : ParseIndexReg coupe au `*`) ; `(a0,d1.l*3)` accepte sans « invalid index scale » ; `move.l ([4,a0],d1),d0` et `(d3.l)` -> erreur (correct).
- Correction minimale (S) : refuser toute echelle ≠ 1 quand le processeur selectionne est 68000/68010 (« invalid 68020 addressing mode »). Complete : XL.

**[E2] Registres speciaux et alias** — Gravite m · Taille S
- Manuel (p.77-78) : `SP`, `CCR`, `SR`, `USP`, `R0..R15`, registres de controle 68010+ (VBR, SFC, DFC, CACR, CAAR, MSP, ISP, MMU...), `FP0-FP7`, `FPCR/FPSR/FPIAR`.
- Actuel (RegOf) : D0-D7, A0-A7, SP, SR, CCR, USP, PC seulement. `r0`, `vbr`, `fp0` -> « Undefined symbol ».

**[E3] Extensions de mnemoniques documentees** — Gravite I · Taille S
- Manuel (p.81-82) : (a) `HS`/`LO` pour Bcc/DBcc/Scc : OK (teste). (b) `DBRA` : OK. (c) `ILLEGAL` = `$4AFC` : OK. (d) `Bcc.B/.S/.W`, `.L` : sur 68000 `Bcc.L` -> `Bcc.W` AVEC avertissement ; sur 68020+ vrai long. Actuel : `bra.l` -> mot, sans avertissement ni long 68020. (e) `BRA.S` vers l'instruction suivante interdit (erreur « short branch cannot be 0 bytes ») sauf `OPT O7+` (NOP + avertissement) ; `BSR.S` vers la suivante : erreur « illegal BSR.S ». Actuel (GBranch) : toujours un NOP, aucune erreur (`bsr.s l / l: nop` -> `4e71`). (f) `LINK` : avertissement si deplacement positif ou impair : aucun. (g) `MOVE from CCR` : instruction 68010, convertie en `MOVE SR` avec avertissement en mode 68000. Actuel : `move ccr,d0` -> `42C0` (opcode 68010 qui plante un vrai 68000) sans avertissement. (h) `MOVEQ` : avertissement si la donnee est 128-255 : aucun (accepte -128..255).
- Correction : un jeu de petits ajouts dans GBranch/GMisc/GMove ; (e) et (g) sont les plus utiles.

**[E4] Branche vers adresse impaire** — Gravite I · Taille S
- Manuel (p.81) : « the assembler will produce an error if it finds an odd destination in a BSR or BRA operand » (annexe : « odd address »).
- Actuel : aucune verification. Test : `dc.b 1 / l: / nop / beq l` -> `67fb` (cible impaire) sans erreur.

**[E5] Taille de branche par defaut (BRW/BRB/BRS/BRL, O1)** — Gravite I · Taille XS
- Manuel (p.102) : par defaut `BRW` : un `BRA` sans taille est un mot, « unless optimisation type 1 is selected when it may be promoted to BRA.S ».
- Actuel (GBranch) : `If OptOptimize Or (Disp<0) Then Decs:=1` : tout branchement arriere sans taille devient court MEME sans optimisation (test : `l: nop / bra l / bne l / bsr l` -> `60fc 66fa 61f8`). Resultat : tailles/adresses differentes de Devpac, et listings non comparables ; avec `OPT O+` aussi les avants.
- Correction : retirer `Or (Disp<0)` ; implementer `BRB/BRS/BRW/BRL` (les noms `OPT` sont aujourd'hui ignores) et l'option O1 separement de O+.

**[E6] Alignement (mot) et instructions** — conforme.
- Manuel (p.80) : toutes les instructions sauf `DC.B/DS.B` alignees sur mot ; un label seul sur sa ligne n'est pas aligne. Actuel : teste (label `odd2:` seul garde l'adresse impaire ; `dc.w`/instruction alignes, `dc.b` non). Pour un label SUR la meme ligne qu'une instruction, le clone aligne avant de definir le label : coherent avec l'exemple du manuel.

**[E7] Tailles d'instruction non validees** — Gravite m · Taille S
- Manuel (annexe B) : « invalid size », « invalid opcode size for data/address register ».
- Actuel : `nop.l`, `rts.b`, `moveq.w`, `swap.b`, `lea.w`, `jmp.b`, `move.b d0,ccr` sont acceptes. Seules les lettres hors B/W/L/S sont rejetees (« Bad size suffix »). `link.l a6,#-100`, `divs.l`, `muls.l` sont assembles comme leur forme mot (silencieusement faux sur 68020).
- Correction : table taille autorisee par mnemonique.

**[E8] 68010/68020/68030/68040/CPU32, 68881/2, 68851/MMU** — Gravite I (hors ST) · Taille XL
- Manuel (p.81, 85, 96-97) : « The complete 68000-68040 instruction set is supported (depending on the processor selected) together with the 68881/68882 and 68851 co-processors ». `MACHINE`, `OPT P=`, dialogue Processor.
- Actuel : `OPT P=68020` est accepte en silence mais sans effet ; `machine mc68020` -> « Unknown opcode ». Absents (testes : « Unknown opcode ») : `EXTB RTD BKPT TRAPcc MOVEC MOVES CMP2 CHK2 CAS PACK UNPK` + champs de bits + `CPUSH PFLUSH` + tout FPU. `tst.l a0` (autorise des le 68020) refuse.
- Estimation : 68010 (RTD, BKPT, MOVEC, MOVES, MOVE CCR) = M ; 68020/30 integer + modes = L ; 68040 = M ; FPU = L ; MMU = L.

**[E9] Controles « source checking »** — Gravite m · Taille S chacun
- Manuel (p.90-91) : `CHKIMM` (erreur « # probably missing » : `and.b $df,d1`), `CHKPC`, `AUTOPC` (`move.l test,a3` -> `test(pc),a3`), `EVEN`/`NOEVEN` (indirection impaire), `CHKBIT`/`WARNBIT` (numero de bit 0-7 pour octet), `ALLOWZERO`.
- Actuel : aucun n'est implemente (`opt autopc`, `opt chkimm` acceptes en silence). Tests : `and.b $df,d1` -> `c239 000000df` sans erreur ; `btst #9,(a0)` et `btst #40,d0` acceptes (pas de « Bit number should be 0-7 for byte »).

**[E10] Optimisations O1-O12 + OW** — Gravite I · Taille M
- Manuel (p.88-89, 105) : O1 branches arriere courtes, O2 `d(An)`->`(An)` si 0, O3 absolu -> court, O4 `MOVE.L #x,Dn`->`MOVEQ`, O5 `ADD/SUB #`->quick, O6 avertissement branches avant, O7 BRA.S 0 -> NOP, O8/O9 deplacements 68020, O10 `ADD #x,An`->`LEA`, O11 `LEA`->`ADDQ`, O12 `MOVE.L #x,An`->`MOVE.W` ; `O+`/`O-`, `OW+/-`, `OWn+/-` ; en fin d'assemblage, nombre d'optimisations et octets gagnes.
- Actuel : `OptOptimize` (un seul booleen) ne gouverne que les branches AVANT (jamais O2-O12). Test : avec `opt o+`, `move.l #5,d0` reste `203c00000005`, `add.l #1,d0` reste ADDI, `move.l 0(a0),d1` reste `2228 0000`, `lea 4(a0),a0` inchange. `O1/O2` sont aliases de `O+` dans DirOpt. Pas de compte rendu final.
- Correction : implementer au moins O2, O3, O4, O5 (les plus utilises) avec la contrainte « decision stable entre passes ».

---------------------------------------------------------------------

## 6. Directives de controle d'assemblage

**[F1] `INCLUDE` / `INCBIN` / `INCDIR`** — Gravite I · Taille S
- Manuel (p.83-85) : nom au format TOS (`c:\devpac\includes\header.i`), repertoires de la liste `-I`/dialogue + `INCDIR` (separes par `,` ou `;`, terminer par `\`), unite du fichier principal par defaut ; erreur de lecture = erreur fatale ; `INCONCE` ; fichiers `.GS` pre-assembles ; `INCBIN` : donnees forcees sur une frontiere paire.
- Actuel (FindInclude, Directive) : (1) `\` dans le chemin et casse des noms NON traduits : `include "inc\a.i"` -> « Cannot open file », `include "INC/A.I"` aussi, alors que `HostPath` (p09a.pas, deja ecrit pour GEMDOS) sait faire les deux : a reutiliser. (2) Un seul repertoire d'inclusion (`OptIncPath`), pas de liste. (3) `INCDIR` -> « Unknown opcode ». (4) `INCONCE`/« Ignore multiple includes » absent (teste : deux `include` du meme fichier = « Symbol already defined » deux fois). (5) `INCBIN` n'aligne pas (test `dc.b 1 / incbin "b.bin"` -> `01 616263`, attendu `01 00 616263`). (6) Include introuvable : erreur NON fatale, l'assemblage continue. (7) `.GS` : non pris en charge.
- Correction : (1) XS (appeler HostPath) ; (2)+(3) S ; (4) S ; (5) XS ; (7) voir [F4].

**[F2] `END`** — conforme (teste : plus rien n'est lu apres).

**[F3] `OPT` : syntaxe et options** — voir section 7.

**[F4] Fichiers pre-assembles `.GS`, `OPT GENSYM`, commande « Output Symbols »** — Gravite m · Taille M
- Manuel (p.84, 88, 77) : table de symboles/macros serialisee, rechargee a la place de l'include, option `-H`/liste « Pre-assembled includes ». Absent (aucun code `.GS`). Utile surtout pour accelerer les gros include (GEMDOS.I, AES...).

---------------------------------------------------------------------

## 7. OPT : etat de chaque option (p.85-94, tableau p.92-94)

Reconnues par DirOpt : `D+/D-`, `C+/C-`, `W+/W-`, `O`, `O1`, `O2` (avec `+`/`-`), `L` (ignore). Tout le reste est ignore SANS erreur : le manuel exige « invalid option ».

**[O1] Table d'options manquante** — Gravite I · Taille M (table d'options + variables + 1 booleen par option)

| Option du manuel (defaut) | Etat dans le clone |
|---|---|
| `P=type[/copro]` (68000) | ignore (aucune generation 020+) |
| `BDW`, `BDL` (BDL), `ODW` (ODW), `ODL` | ignore (sans objet sans modes 68020) |
| `OLD`, `BRW` (defaut), `BRB`, `BRS`, `BRL` | ignore ; defaut non conforme ([E5]) |
| `CASE` (defaut), `NOCASE`, `Cx`, `Cx+`, `Cx-` | seul `C+/C-` ; NOCASE/Cx ignores |
| `MEX`, `NOMEX` (NOMEX), `SYMTAB`, `NOSYMTAB`, `LIST1`, `NOLIST1`, `TRACEIF`, `NOTRACEIF` | ignores ; le listing montre toujours les expansions et la table des symboles |
| `ATARI`, `GST`, `DRI`, `SREC`, `LATTICE` | ignores (PRG produit quand meme) |
| `GENSYM` | ignore |
| `O1+..O12+`, `O+`, `O-`, `OW+/-`, `OWn+/-` | seul O/O1/O2 -> branches ([E10]) |
| `ALLOWZERO`, `CHKBIT`, `NOCHKBIT`, `WARNBIT`, `CHKIMM`, `CHKPC`, `EVEN`, `NOEVEN` | ignores ([E9]) |
| `AUTOPC`, `NOAUTOPC`, `INCONCE`, `NOINCONCE`, `LOCALU`, `LOCALDOT`, `NOTYPE`, `TYPE`, `NOWARN`, `WARN`, `USER`, `SUPER` | ignores (`W-`/`W+` seuls, mais inoperants car aucun avertissement n'est emis) |
| `DEBUG`, `NODEBUG`, `XDEBUG`, `LINE`, `NOLINE`, `HCLN`, `NOHCLN`, `D+`, `X+` | `D+/D-` seul ([B5]) |
| formes anciennes `A+ E+ I+ L7 M+ P+ S+ T+ U+ X+ Z+` | ignorees |

Tests : `opt l-,o1+,o2+,ow-,w-,x+` accepte ; `opt foo` accepte sans erreur ; `opt localu` sans effet (`_l` n'est pas local) ; `opt p=68030` accepte.
- Correction : (1) remplacer l'analyse par une table nom -> action ; (2) erreur « invalid option » pour les inconnues ; (3) options sans effet reel au moins enregistrees (et un avertissement « directive ignored » tant qu'elles ne sont pas implementees).

---------------------------------------------------------------------

## 8. Directives de donnees, alignement, divers (p.95-98)

**[H1] `DC` : limite silencieuse de 40 operandes** — Gravite B · Taille XS
- Manuel (p.95) : « No more than 128 bytes can be generated with a single DC directive ».
- Actuel (DirDC) : `Parts : Array[0..39]`, `SplitTop(...,40)` ignore le reste. Test : `dc.b` avec 60 valeurs -> « CODE 40 », aucune erreur : 20 octets perdus. Plus grave que la limite de Devpac, car le manuel promet jusqu'a 128 octets (et le test de 400 operandes donne aussi 40).
- Correction : boucle d'analyse incrementale sans tableau borne, ou au minimum erreur « line malformed »/« data too large » quand il y a plus de 40 operandes.

**[H2] `DCB`** — Gravite m · Taille XS
- Manuel (p.96) : `DCB.x nombre[,valeur]` (valeur 0 si omise). Actuel : l'omission donne « Operand expected » (`dcb.b 2` refuse). Nombre negatif non signale.

**[H3] `DS` negatif** — Gravite m · Taille XS : manuel « DCB or DS count must not be negative » ; actuel : ramene silencieusement a 0.

**[H4] `FAIL`** — Gravite m · Taille XS : manuel : erreur « user error » ; actuel : `FAIL: <args>` (utile mais libelle different).

**[H5] `EVEN`, `CNOP`** — conformes (testes).

**[H6] `MACHINE`, `RADIX`, `OUTPUT`, `INCDIR`, `RORG`** — Gravite I · Taille S chacun
- Manuel (p.97) : `MACHINE MC68000..MC68040, MC68332, CPU32` ; `RADIX 2/4/8/10/16` (en base 16 les nombres doivent commencer par un chiffre) ; `OUTPUT` ([B3]).
- Actuel : `MACHINE`, `RADIX`, `INCDIR`, `RORG` -> « Unknown opcode ». Test `radix 16 / dc.b 0ff` -> erreurs en cascade.

**[H7] `DC.S/.D/.X` et `DS/.DCB` flottants** — voir [D4].

---------------------------------------------------------------------

## 9. REPT / ENDR (p.99)

**[R1] Conformite** — OK pour le cas courant (teste : `rept 3 / nop / endr`, expression `512/4`, `rept` dans une macro). Ecarts mineurs :
- Manuel : « It is not possible to nest repeat loops » (annexe : « cannot nest repeat loops ») et « cannot nest MACRO definitions or define in REPTs ». Actuel : REPT imbriques ACCEPTES (test : 2x2 `nop` = 4) ; pas d'erreur pour une macro definie dans un REPT. Plus permissif : pas de risque.
- `\@` dans un REPT hors macro : « Bad expression » (le manuel ne le promet pas).

---------------------------------------------------------------------

## 10. Directives de listing (p.99-101) et format du listing

**[L1] Directives de listing ignorees** — Gravite I · Taille M
- Manuel : `LIST`/`NOLIST`, compteur `LIST +`/`LIST -`, `PLEN` (12-255, defaut 60), `LLEN` (38-255, defaut 132), `TTL`, `SUBTTL`, `SPC n`, `PAGE`, `LISTCHAR`, `FORMAT 0+/1-/2+`, en-tete de page (titre, date JJ/MM/AA ou MM/JJ/AA, heure, page ; ligne titre ; ligne sous-titre ; ligne blanche), saut de page FF entre pages.
- Actuel : `LIST NOLIST PAGE TTL SUBTTL LLEN PLEN SPC FORMAT IDNT NOPAGE NOFORMAT ECHO MASK2` sont dans la liste « reconnues et ignorees » (Directive, p04.pas) ; `LISTCHAR` -> « Unknown opcode ». Tests : `nolist` n'arrete pas le listing ; `list` seul (sans `/L`) ne cree aucun fichier ; pas d'en-tete de page ; pas d'argument controle (`invalid FORMAT parameter` etc.).
- Format actuel (ListLine) : `numero(5) adresse(6 hex) octets(max 6, 12 hex) source`, tabulations brutes (pas de « Tab size »), toujours suivi de « Symbol table » (nom, valeur hexa, TEXT/DATA/BSS/ABS), non limite a `-S`/`SYMTAB` (manuel p.87), sans macros ni constantes de listing de registre ; EQU/SET n'affichent pas leur valeur ; au-dela de 6 octets (DC.B long) pas de lignes de suite.
- Macros : par defaut (NOMEX) le manuel liste « just the macro call and not the code produced by it ». Actuel : les lignes de l'expansion sont TOUJOURS listees (teste : `m` puis 2 `nop` avec le meme numero de ligne).
- Peripheriques : le manuel permet Ecran/Imprimante/Disque et un fichier ou un peripherique (`-P prn:`/`aux:`) ; le clone ne sait ecrire que `<source>.LST` (ou `OptListName` qui n'est reglable nulle part : aucune option ni dialogue).
- Correction : (a) compteur LIST/NOLIST honore, MEX/NOMEX, symtab sur option : S ; (b) PLEN/LLEN/TTL/SUBTTL/SPC/PAGE/FORMAT + en-tete : M ; (c) listing ecran/imprimante/`-P` : S ; (d) `LIST1`/`TRACEIF`/« List conditionals only » : S.

---------------------------------------------------------------------

## 11. Directives de labels (p.101-107)

**[K1] `EQU`, `=`, `SET`, `RS`, `RSRESET`, `RSSET`, `REG`** — OK pour l'essentiel (testes). Ecarts :
- Manuel (p.101-102) : `EQU` n'accepte pas de reference avant ; annexe : « forward reference ». Actuel : `x equ y+1` suivi de `y equ 3` est ACCEPTE (resolu grace aux passes repetees ; plus permissif).
- `REG` : « may be used in expressions, with a warning » (misuse of register list) ; actuel : `dc.w a` avec `a reg d0-d3` -> « Undefined symbol ».
- Un label sur `IF`/`ENDC`/`EQU` local non controle.

**[K2] `EQUR`** — Gravite I · Taille S
- Manuel (p.118) : `label EQUR register` : nom utilisateur pour D/A, doit etre defini avant usage.
- Actuel : traite comme `EQU` et echoue : `a equr d3` -> « Undefined symbol: d3 ». Correction : table de synonymes de registres consultee par RegOf/ParseOp (et SP/aliases).

**[K3] `OFFSET`** — Gravite B · Taille M
- Manuel (p.104) : section absolue : labels absolus, seulement `DS` autorise, `OFFSET expression` fixe le PC initial, retour par `SECTION`.
- Actuel : `OFFSET` fait partie des directives IGNOREES : les labels deviennent des labels du TEXT et les `DS` generent des octets. Test : `offset 4 / x ds.w 1 / y ds.l 1 / text / dc.w x,y` -> `x=0, y=2` et 6 octets de zeros dans le programme (attendu : `x=4, y=6`, aucun octet).
- Correction : mode « OFFSET » (un 4e type de section, valeur absolue, pas d'emission, `SECTION` en sortie). Tant que ce n'est pas fait, `OFFSET` devrait au moins donner une erreur plutot que de produire du code faux.

**[K4] `CARGS`** — Gravite I · Taille S
- Manuel (p.105-106) : `CARGS [#offset,]lab1.size[,lab2.size...]` ; offset 4 et taille 2 par defaut ; `.B` equivaut a `.W`.
- Actuel : « Unknown opcode: CARGS » (+ erreurs en cascade sur les labels). Correction : analyse de la liste et DefSym absolu.

**[K5] `EQUENV`, `RSEVEN`, `__RS`** — Gravite m
- `EQUENV var` (p.117) : absent (« Unknown opcode »), S. `RSEVEN` : N'EXISTE PAS dans le manuel Devpac 3 (recherche negative dans txt2 et v2.txt) donc pas un ecart (le clone ne le connait pas non plus). `__RS` : voir [D7].

**[K6] `FEQU`, `FOPT`** — voir [D4].

---------------------------------------------------------------------

## 12. Assemblage conditionnel (p.108-110)

**[Q1] `ELSEIF`** — Gravite B · Taille XS
- Manuel (p.110) : « ELSEIF / ELSE : toggles conditional assembly... ELSE can be used instead of ELSEIF although ELSEIF is the traditional Devpac name ».
- Actuel (CondDirective) : seul `ELSE` est reconnu (+ `ENDIF`, `IFDEF`, `IFNDEF`, `IF` en extra). Test : `ifeq 0 / nop / elseif / nop / endc` -> « Unknown opcode: ELSEIF » puis « ENDC without IF ». Les sources Devpac historiques utilisent presque toutes `ELSEIF`.
- Correction : `If (Op='ELSE') Or (Op='ELSEIF')`.

**[Q2] `IIF`** — Gravite I · Taille S
- Manuel (p.109) : `IIF expression instruction` (une ligne, sans `ENDC`) ; un label peut preceder le `IIF` ; label defini avec le PC si l'expression est 0 ; la partie instruction n'a pas de champ label.
- Actuel : « Unknown opcode: IIF ». Correction : dans ProcessLine, traiter `IIF` : evaluer, puis reinjecter le reste de la ligne comme une ligne source (en conservant le label).

**[Q3] Autres** — IFEQ/NE/GT/GE/LT/LE, IFC/IFNC (casse sensible), IFD/IFND, `ELSE`, `ENDC`, `Missing ENDC` : conformes (testes). Differences mineures : limite d'imbrication 64 (`MAXCOND`) au lieu de 65535 (message « Conditionals nested too deeply ») ; IFC accepte aussi les guillemets doubles et les chaines non quotees ; `IFD` sur symbole reserve faux ([D7]) ; erreur de syntaxe dans l'expression d'un IFxx : valeur 0 (le manuel : « invalid IF expression, ignored » ; l'IF est alors... ignore) ; « fatally bad conditional » inexistant.

---------------------------------------------------------------------

## 13. Macros (p.110-117)

Fonctionne (teste) : `MACRO`/`ENDM`, `\1..\9`, `\0` (suffixe de l'appel), `\@` (compteur unique), `MEXIT`, `NARG`, recursion (exemple 3), appels `inc.l a0`, `gemdos 2,4`, `rtseq`, macros commencant par un point, `IFC '\1',''`. Le nom de la macro est insensible a la casse (extension).

**[M1] `< >` autour d'un parametre** — Gravite B · Taille S
- Manuel (p.111, 116, 131) : un parametre contenant espaces ou virgules s'ecrit `<...>` ; `>>` pour un `>` litteral.
- Actuel : SplitLine coupe l'argument au premier espace non protege par quotes ou parentheses, et SplitTop coupe aux virgules sans considerer `< >`. Tests : `n <a b>,7` -> `\2` vide (« Operand expected ») ; `n <a,b>,7` -> parametres `<a` / `b>` ; `n <1 + 1>` -> « Bad expression ». Seul `<'chaine avec espaces'>` marche (grace aux apostrophes). L'exemple 5 du manuel (`showname <'real Ale Search Program v'>`) marche pour la partie `< >` mais pas pour `\<version>` (voir M3).
- Correction : SplitLine et SplitTop doivent suivre la profondeur de `< >` en position de parametre de macro uniquement (`<` est aussi un operateur de comparaison : traiter seulement quand `<` ouvre un argument).

**[M2] Jusqu'a 36 parametres, `\A..\Z`, `\a..\z`** — Gravite I · Taille S
- Manuel (p.111) : « up to 36 parameters... \ followed by an alpha-numeric (1-9, A-Z, a-z) » ; `\0` = taille de l'appel, **W si aucune**.
- Actuel : 9 parametres (`Args` 0..9, `CallMacro` en lit 9) ; `\A` -> « Bad expression » (non substitue) ; la liste de noms `MACRO a,b` (extension du clone, `\nom`) existe mais pas les lettres. Test : appel `l1 1,2,..,9,10` avec `\A` -> erreur ; 11 parametres : les extras sont perdus en silence. `\0` sans suffixe est la chaine VIDE (le manuel : W) ; l'effet est invisible pour `addq.\0` (taille par defaut = mot) mais `dc.b "\0"` donne "" au lieu de "W".
- Correction : etendre `Args` a 36 (index 1-9 puis A-Z -> 10-35), `\0` = 'W' par defaut.

**[M3] Parametres speciaux `\#`, `\?n`, `\<sym>`, `\<$sym>`, `\\`** — Gravite I · Taille S
- Manuel (p.111-112, 128, 131) : `\#` synonyme de NARG ; `\?1` longueur du texte du parametre 1 (chaines de Pascal) ; `\<symbole>` -> chiffres decimaux de la valeur (symbole defini et absolu), `\<$symbole>` hexadecimal ; `\\` = backslash litteral.
- Actuel (SubstMacro) : uniquement `\0..\9`, `\@` et `\nom` (noms de parametres). Tests : `dc.b \#` / `\?1` -> « Bad expression » ; `dc.b "\<version>"` emet litteralement `\<version>` ; `\\` reste `\\`.
- Correction : SubstMacro : ajouter ces 5 cas (S).

**[M4] Appel de macro sur plusieurs lignes (`&`)** — Gravite I · Taille S
- Manuel (p.112, 117) : appel termine par une virgule, ligne suivante commencant par `&` puis blancs puis la suite des parametres.
- Actuel : « Unknown opcode: & » (test avec l'exemple 7 du manuel). Correction : dans NextLine/ProcessLine, recoller les lignes quand la ligne se termine par `,` et la suivante commence par `&`.

**[M5] Format de `\@`** — Gravite m · Taille XS : manuel `_nnn` (trois chiffres, jusqu'a 5) ; actuel `_1`, `_2`... (pas de zero de remplissage). Visible dans les listings/tables de symboles ; peut collisionner avec des labels `_1` utilisateur.

**[M6] Definition de macro** — Gravite m : manuel : macros non imbriquables (« cannot nest MACRO definitions »), `MACRO.W/.L` aligne le PC (p.110) ; actuel : l'imbrication est comptee en profondeur (pas d'erreur), le suffixe de `MACRO` n'est pas pris en compte ; `MEXIT` hors macro n'est pas signale (« spurious ENDM or MEXIT » : actuel silencieux ; ENDM hors macro -> « Unexpected ENDM » OK) ; macros limitees a 256, parametres a 100 caracteres, lignes expansees a 255.

---------------------------------------------------------------------

## 14. Directives de sortie et sections (p.117-131)

**[S1] `SECTION`, `TEXT`, `CODE`, `DATA`, `BSS`** — OK en Atari (teste, y compris BSS puis TEXT avec reference). Ecarts : nom de section inconnu (`section foo`) -> TEXT en silence (manuel : « invalid section name, TEXT assumed » ou erreur « invalid section specified ») ; `ds` seulement dans BSS (message « Cannot generate code in BSS » : correct mais libelle different).

**[S2] `MODULE`, `XDEF`, `XREF`, `XREF.L`, `COMMENT`, `CSECT`, `IDNT`, `RORG`** — Gravite m pour l'ST direct · Taille depend des formats ([B1])
- Actuel : `XDEF`/`XREF`/`PUBLIC`/`GLOBAL`/`EXPORT`/`IMPORT`/`COMMENT`/`IDNT` ignores sans message (donc `XREF` laisse des « Undefined symbol ») ; `MODULE`, `CSECT`, `RORG` -> « Unknown opcode ». En PRG pur (Atari), le manuel decrit seulement SECTION/ORG/COMMENT HEAD/OPT debug (p.118-121) : donc seuls `COMMENT HEAD`, `RORG` ([B4], S) sont requis.

**[S3] Imports dans les expressions** (p.123, 126, 131) — liés aux formats linkables ; sans objet tant que B1 n'est pas fait.

---------------------------------------------------------------------

## 15. Table recapitulative des directives (p.132-134) : etat

Legende : OK = conforme (teste), ~ = partiel, - = absent (« Unknown opcode »), IGN = reconnu et ignore en silence.

| Directive | Etat | Directive | Etat |
|---|---|---|---|
| CNOP | OK | MACRO / ENDM | ~ (M1-M6) |
| DC.B/W/L | ~ (H1, reloc D6) | MEXIT | OK (hors macro silencieux) |
| DC.S/D/X | - | NARG | OK |
| DCB | ~ (valeur obligatoire) | `\#`, `\?`, `\<>`, `\\` | - |
| DS | OK (negatif silencieux) | BSS / CODE / DATA / TEXT | OK |
| END | OK | COMMENT | IGN (HEAD= perdu) |
| EVEN | OK | CSECT | - |
| FAIL | ~ (libelle) | IDNT | IGN |
| INCBIN | ~ (alignement) | MODULE | - |
| INCDIR | - | ORG | ~ (B2) |
| INCLUDE | ~ (F1) | RORG | - |
| OPT | ~ (section 7) | SECTION | ~ (S1) |
| RADIX | - | XDEF / XREF (/.L) | IGN |
| MACHINE | - | OUTPUT | ~ (B3) |
| REPT / ENDR | OK | `__G2`, `__LK`, `__RS` | - |
| FORMAT, LIST, NOLIST, PLEN, LLEN, TTL, SUBTTL, SPC, PAGE | IGN | LISTCHAR | - |
| CARGS | - | EQUENV | - |
| EQU / `=` | OK | EQUR | - (echoue) |
| OFFSET | IGN (genere du code faux) | REG | ~ (usage en expression) |
| RS / RSRESET / RSSET | OK | SET | OK |
| FEQU, FOPT | - | ELSEIF | - |
| ELSE, ENDC, IFC, IFD, IFEQ/NE/GT/GE/LT/LE, IFNC, IFND | OK | IIF | - |

Directives presentes dans le clone mais absentes du manuel Devpac 3 : `IF`, `IFDEF`, `IFNDEF`, `ENDIF`, `NOPAGE`, `NOFORMAT`, `ECHO`, `MASK2`, `PUBLIC`, `GLOBAL`, `EXPORT`, `IMPORT` (tous ignores ou alias), `0x` hexa, `%` modulo, parametres nommes de macro, mode Amiga.

---------------------------------------------------------------------

## 16. Avertissements : infrastructure absente

**[W1] Aucun avertissement n'est jamais emis** — Gravite I · Taille M
- Manuel (p.56 « No warnings », p.103 NOWARN/WARN, annexe B p.219-221) : 20 avertissements ; code retour 5 ; `OW`.
- Actuel : `Warn3` (p02.pas) existe, avec le compteur `AsmWarns`, mais n'est appele nulle part (recherche dans p02-p05, p13). Tous les cas de la section 5 passent sans message. `OPT W-` modifie un drapeau sans consequence. Le compte rendu final affiche « N warning(s) » mais N vaut toujours 0.
- Correction : brancher `Warn3` sur les cas suivants (par ordre d'utilite) : `-L converted to .W` (bra.l sur 68000), `invalid LINK displacement`, `sign extended operand`/`MOVEQ substituted`, `68010 instruction, converted to MOVE SR`, `directive ignored` (pour toute directive/option reconnue mais ignoree : cela signalerait OFFSET, XDEF... au lieu de les avaler), `size should be .W`, `short branch converted to NOP`, `no ORG specified`, et les avertissements d'optimisation une fois O1-O12 faits. Ajouter le code retour 5.

---------------------------------------------------------------------

## 17. Annexe B : messages d'erreur et d'avertissement (p.213-221)

L'OCR de l'annexe est complet. Les libelles du clone sont trilingues (T3) et, sauf quelques-uns, differents de ceux du manuel. Le clone n'emet qu'**une erreur par ligne** (`LastErrLine`), uniquement en passe 2, au format `Error in line N: <message>` (ou `Error in <fichier> (N): ...`), puis la ligne source ; le manuel (p.53) : message suivi de la ligne et du fichier. Pas de message « INTERNAL ».

**Messages du clone qui ont un equivalent (libelle different)**

| Clone | Annexe B |
|---|---|
| Unknown opcode: X | instruction not recognised |
| Undefined symbol: X | undefined symbol |
| Symbol already defined: X | symbol defined twice |
| Phasing error: X | phasing error (meme sens) |
| Division by zero | division by zero |
| Missing ENDC | missing ENDC |
| ENDC without IF | spurious ENDC |
| Unexpected ENDR / ENDM | spurious ENDR / spurious ENDM or MEXIT |
| Unexpected end of file in MACRO/REPT | source expired prematurely |
| FAIL: texte | user error |
| Cannot open file: X / Cannot read file: X | file not found / include file read error (en plus : fatale dans Devpac) |
| Cannot generate code in BSS | BSS or OFFSET section cannot contain data |
| Bad register list | invalid register list |
| Bad size suffix / Illegal size | invalid size / invalid opcode size for data/address register |
| Label expected | symbol expected (ou « misuse of label ») |
| Missing ) | missing close bracket |
| Illegal addressing mode | addressing mode not allowed / not recognised / address register expected / data register expected / immediate data expected / register expected |
| Operand expected | register expected / comma expected / expression mismatch |
| Bad expression / Bad binary number | expression mismatch / invalid number |
| Illegal relocation | illegal type combination / relative not allowed / absolute not allowed / relocation not allowed |
| Value out of range | data too large / number too large |
| Too many operands | garbage following instruction |
| Program too large | program buffer full |
| ORG must be the first statement / ORG goes backwards | ORG/RORG not allowed |
| Macro name missing / Macro already defined | symbol expected / symbol defined twice (pas de libelle propre dans l'annexe) |

**Messages du clone sans libelle equivalent dans l'annexe** : « Branch out of range » (probablement « data too large » dans Devpac, a verifier sur l'original), « Offset out of range », « ELSE without IF », « Includes nested too deeply », « Conditionals nested too deeply », « Too many macros », « Cannot write output file ».

**Messages de l'annexe B SANS equivalent dans le clone (ou cas non detecte)** — a la fois libelle et detection
- Syntaxe/usage courant (a faire en priorite) : `# probably missing` (CHKIMM), `odd address`, `illegal BSR.S`, `short branch cannot be 0 bytes`, `forward reference`, `absolute expression MUST evaluate`, `relocation not allowed` / `relative not allowed` / `absolute not allowed` (D5/D6), `invalid option`, `invalid radix`, `invalid section name, TEXT assumed`, `invalid section specified`, `invalid section type`, `missing quote` (actuel : « Value out of range »), `DCB or DS count must not be negative`, `cannot nest repeat loops`, `cannot nest MACRO definitions or define in REPTs`, `repeated include file`, `local not allowed`, `misuse of label`, `invalid numeric expansion`, `invalid FORMAT parameter`, `invalid printer parameter`, `line malformed`, `Bit number should be 0-7 for byte`, `error in command line symbol`, `fatally bad conditional`, `out of memory`, `assembly interrupted`, `error during listing output`, `error during writing binary file` (le clone dit « Cannot write output file »), `cannot create binary file`, `executable code only`, `option must be at start`.
- Edition de liens/formats : `cannot export symbol`, `cannot import symbol`, `imported label not allowed`, `XREFs not allowed within brackets`, `linker format restriction`, `duplicate MODULE name`, `invalid pre-assembled file`.
- Processeurs/copro : `wrong processor`, `privileged instruction` (OPT USER), `-W or .L expected as index size`, `invalid 68020 addressing mode`, `invalid index scale`, `invalid bitfield specification`, `colon (:) expected`, `invalid MOVEP addressing mode` (le clone dit « Illegal addressing mode »), `only (An) allowed for this instruction`, `only FPIAR allowed`, `invalid MMU function code`, `MMU register expected`, `maths co-processor required`, `floating-point register expected`, `bad floating point expression`, `invalid floating point expression`, `floating point constant not allowed / too large`, `hex floating point number too large`, `invalid k-factor`, `not yet implemented`, `additional symbol on pass 2`.
- Avertissements (20 messages, section 16) : `-L converted to .W`, `68010 instruction, converted to MOVE SR`, `ADD/SUB converted to LEA`, `base displacement shortened`, `Bit number should be 0-7 for byte`, `branch could be short`, `branch made short`, `directive ignored`, `invalid LINK displacement`, `LEA converted to ADDQ/SUBQ`, `misuse of register list`, `MOVEQ substituted`, `no ORG specified`, `offset removed`, `outer displacement shortened`, `quick form used`, `relative cannot be relocated`, `short branch converted to NOP`, `short word addressing used`, `sign extended operand`, `size should be .W`. Aucun n'existe.

Estimation : adopter les libelles de l'annexe B comme textes anglais (en gardant fr/de) pour les cas deja detectes : S (une passe de renommage + table) ; ajouter les detections de la liste « syntaxe courante » ci-dessus : M.

---------------------------------------------------------------------

## 18. Autres defauts reproduits (limites silencieuses) — hors manuel mais critiques

| # | Defaut | Test | Gravite · Taille |
|---|---|---|---|
| X1 | 16000 relocations maximum (`MAXRELOC`), les suivantes SONT PERDUES sans message : PRG corrompu | `rept 20000 / move.l #l,d0 / endr` -> table de reloc : 16000 entrees | B · XS (tableau dynamique ou erreur) |
| X2 | 16000 lignes par fichier (`MAXLN`) | 16100 `nop` -> 16000 assembles, « No errors » | B · XS |
| X3 | `MAXDEC = 32000` decisions de branches (`DecIdx` clampe) : au-dela, tailles fausses/erreur de phase | lecture du code (GBranch) | m · XS |
| X4 | Table des symboles du listing limitee a 2000 | lecture (PrintSymbols `Arr[1..2000]`) | m · XS |
| X5 | Erreurs : 1 par ligne, 100 memorisees, seulement en passe 2 (le manuel : erreurs de syntaxe de la passe 1 signalees et arret a la fin de la passe 1) | tests | m · S |
| X6 | `move.l 4(a0)+,d0` accepte (le `4` est ignore) ; `btst #1,#2` ; `(a0,d1` -> « Missing ) » | tests | m · S |
| X7 | Plusieurs fichiers sources en ligne de commande : le code retour est celui du dernier echec (1 ou 2 s'ecrasent), pas le pire | lecture de BatchRun | m · XS |

---------------------------------------------------------------------

## 19. Ce qui est conforme (inutile de refaire)

Jeu d'instructions 68000 integral et codage verifie contre gas (160 instructions, toutes formes d'EA, MOVEM/MOVEP/MOVEQ/BCD/decalages/bits/Scc/DBcc/TRAP/STOP/LINK...) ; `HS`/`LO` ; `DBRA` ; `ILLEGAL` ; registres insensibles a la casse, `SP`, `CCR/SR/USP` ; modes 68000 y compris `d(An,Xn.s)` sans deplacement, `(d,PC,Xn)` ; `(label).w` ; alignement des instructions ; `EVEN`/`CNOP` ; chaines `'it''s'`, `"` et `'` ; hexa/octal/binaire ; moins unaire, `~`, comparaisons -1/0 ; compte `*`/`$` ; labels locaux `.nom` et `nom$` rattaches au dernier label global ; `EQU`/`=`/`SET`/`REG`/`RS*` ; IFxx/IFC/IFD/ELSE/ENDC ; REPT ; macros (cas simples, recursion, `\@`, `NARG`, `MEXIT`) ; sections TEXT/DATA/BSS avec references croisees et relocation PRG (en-tete `601A`, table de relocation compressee, table de symboles DRI) ; `END` ; `ORG` initial.

---------------------------------------------------------------------

## 20. Les 25 corrections les plus utiles (ordre conseille : utilite pour un developpeur ST / taille)

1. **[H1] DC > 40 operandes perdus** : supprimer la limite ou signaler une erreur (XS, bloquant).
2. **[X1][X2][C8] Limites silencieuses** (relocations, lignes, longueur de ligne) -> erreur explicite ou tableaux dynamiques (XS-S).
3. **[Q1] `ELSEIF`** (XS).
4. **[E5] Taille par defaut des branches arriere** : retirer `Or (Disp<0)` (XS) puis `OPT O1`/`BRB BRS BRW BRL` (S).
5. **[C4] Labels > 63 caracteres** introuvables ; passer a 127 et ajouter `Cx` (XS-S).
6. **[C1][C2][C3] Syntaxe de labels** : `nom:` indente, `@nom`, `1$` (S).
7. **[D1] Priorite des operateurs** selon p.70 (S).
8. **[Q2] `IIF`** (S).
9. **[K3] `OFFSET`** (M) — au minimum l'interdire par une erreur.
10. **[M1][M4] Macros : `< >` et lignes de continuation `&`** (S+S).
11. **[M2][M3][M5] Macros : 36 parametres, `\#`, `\?n`, `\<sym>`, `\<$sym>`, `\\`, `\0`=W, `\@`=`_nnn`** (S).
12. **[W1] Brancher `Warn3`** (au moins -L->.W, LINK, MOVEQ, MOVE CCR, directive ignored) + code retour 5 (M) ; **[A3]** codes 0/5/10/20 (S).
13. **[E3][E4] Verifications de branches** : `odd address`, `illegal BSR.S`, `short branch cannot be 0 bytes` / O7, `MOVE from CCR`->SR (S).
14. **[K2][K4] `EQUR` et `CARGS`** (S+S) ; **[H6] `RADIX`, `INCDIR`, `RORG`, `MACHINE`, `EQUENV`** (S chacun).
15. **[O1] OPT par table** (+ erreur `invalid option`, NOCASE/Cx/LOCALU/MEX/INCONCE/USER...) (M).
16. **[A2] Appliquer `/DEF:`** (XS) et le generaliser en `-E` (S).
17. **[F1] INCLUDE/INCBIN** : appeler `HostPath` (`\`, casse), alignement INCBIN, liste de repertoires + INCDIR + INCONCE (S).
18. **[B3] Regles du nom de sortie** (`OUTPUT .ext`, priorite de l'option explicite) (XS) ; **[B4] `COMMENT HEAD=`** (S).
19. **[D5][D6] Types de relocation** : `relocation not allowed` pour 8/16 bits, erreurs sur decalages/logiques/comparaisons relatifs (S).
20. **[L1] Directives de listing** : `LIST/NOLIST` compteur, `MEX/NOMEX`, symtab sur option, `TTL/SUBTTL/PLEN/LLEN/SPC/PAGE/FORMAT/LISTCHAR`, en-tete de page, `-P`/Ecran/Imprimante (M).
21. **[A1] Mode ligne de commande GEN** (`-B -E -H -I -L.. -O -P -S -T -W -Z +OPT`) (M).
22. **[E10] Optimisations O2-O5** (puis O6-O12) + `OPT O+`/`OW` + compte rendu final (M).
23. **[E9] AUTOPC, CHKIMM, CHKPC, EVEN/NOEVEN, CHKBIT** (S chacun).
24. **[A4] Dialogues Control / Listing / Options / Optimisations**, commandes Check et Output Symbols (L) — apres la mise en place des options reelles.
25. **[E1][E8][B1][D4] Gros chantiers** (a planifier a part) : refus propre des modes/instructions 68020+ (S) ; 68010 (M) ; modes 68020+68030 (L-XL) ; 68881 + FEQU/FOPT/DC.S/D/X (L) ; SREC (M), GST/DRI/Lattice (L chacun) ; `.GS` pre-assemble (M) ; LINE/HCLN (M).

---------------------------------------------------------------------

## 21. Reproduire les tests

Dossier : `/tmp/claude-0/-home-user-DEV-COOLS/8fb337bb-c043-5e64-98fb-f7994ba3a0a4/scratchpad/gapasm/`
- `t.sh fichier.s [opts]` : assemble avec `DEVPAC /B` et montre log + octets du segment TEXT/DATA.
- `tt.sh 'source avec \n' [opts]` : idem sur une source en ligne.
- `cmpgas.py liste.txt` : compare l'encodage 68000 ligne par ligne a `m68k-linux-gnu-as`.
- `e1.s e2.s` (expressions), `m1.s m2.s m3.s ex3.s ex6.s ex7.s` (macros, exemples du manuel), `l1.s` (listing), `i1.s i2.s` (instructions 020+).
Le binaire teste est la copie `gapasm/DEVPAC` du build du 2 novembre (DEVPAC.PAS de 15300 lignes).
