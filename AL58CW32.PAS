{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Algol 58 vers assembleur 80386, 32 bits, pour
    Windows 32 bits
}

(* ============================================================
  AL58CW32.PAS - Compilateur Algol 58 vers assembleur 80386
    pour Windows 32 bits
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32 (console)

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un listing .ASM lisible
    (la production du .ASM est optionnelle et jamais implicite).
  Supporte toutes les exemples SAMPLES\ALGOL58\*.a58

  Reference : DOC\ALGOL58_SPEC_LANG.txt
  Compilateur 16 bits de reference : AL58C86.PAS (DOC\TODO\AL58C86.txt)
  Modele PE/COFF 32 bits de reference : JOVCW32.PAS, BCPLCW32.PAS

  ETAT : TODO 01 (squelette et pipeline), TODO 02 (options), TODO 03
         (constantes, limites, nommage), TODO 04 (lexeur) et TODO 05
         (types), TODO 06 (symboles et portees) et TODO 07 (structure du
         programme et declarations) implementes, les autres TODOs sont
         a faire.

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - ARCHITECTURE ET PIPELINE DU COMPILATEUR [IMPLEMENTE]
            Definir le pipeline complet :
              source .a58 -> lexeur -> parseur -> table des symboles
              -> code genere (ASM 80386) -> .ASM (optionnel)
              -> encodeur binaire x86-32 -> .OBJ (COFF) ou .EXE (PE)
            Choix retenu : encodeur binaire interne (comme JOVCW32), le
              .ASM n'etant qu'un listing parallele, pas une etape requise
            Differences avec AL58C86 : registres 32 bits (EAX..EBP),
              modele FLAT, entier 32 bits, appels API Win32 au lieu de
              INT 21h, aucune limite de segment 64 Ko
            Decouper le source en sections commentees : constantes, types,
              options, lexeur, symboles, types Algol, parseur/generateur,
              runtime, ecrivains OBJ/EXE, programme principal
            Garder la compatibilite Turbo Pascal 7 / Free Pascal 3.2
              ({$MODE TP}, {$H-}, {$I-}), lignes de 80 colonnes maximum

  TODO 02 - OPTIONS DE LIGNE DE COMMANDE ET FICHIERS DE SORTIE [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm)
            Syntaxe : AL58CW32 source.a58 [-o sortie] [-obj] [-asm]
              [-v] [-d] [-w] [-h]
            Par defaut : produire source.exe (PE Windows 32 bits)
            -obj : produire uniquement source.obj (aucun .EXE)
            -asm : produire en plus source.asm (listing MASM 80386)
            -o nom : nom du fichier de sortie principal
            Extensions d'entree acceptees : .a58 et .alg
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Aide en ligne (-h), version et date, message d'usage si
              aucun argument

  TODO 03 - CONSTANTES, LIMITES ET CONVENTIONS DE NOMMAGE [IMPLEMENTE]
            Constantes PE/COFF : PE_MACHINE_I386 ($014C), PE_MAGIC_32
              ($010B), PE_IMG_BASE ($00400000), PE_SEC_ALIGN (4096),
              PE_FILE_ALIGN (512), PE_SUBSYS_CUI (3), indicateurs de
              sections (code, donnees initialisees, lecture/ecriture)
            Limites internes 32 bits (pas de reduction "Turbo Pascal 16
              bits") : symboles, labels, portees, tailles de pile
            Prefixes de nommage ASM : _A58V_ (variable), _A58P_
              (procedure), _A58K_ (chaine), _A58RT_ (runtime), _A58L_
              (label interne), _A58SW_ (switch), _A58OWN_ (own),
              _A58ARR_ (tableau), _A58TH_ (thunk)
            Utilitaires : ItoS, UpCaseStr, AsmIdent (nom ASM valide)

  TODO 04 - LEXEUR ALGOL 58 [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_INTEGER, TK_REAL, TK_IDENT,
              TK_KEYWORD, TK_OP, TK_PUNCT, TK_STRING
            Format libre, suivi de ligne et colonne pour les erreurs
            Insensible a la casse pour les mots-cles (Boolean, BEGIN...)
            Mots-cles : begin end if then else for do step until while
              go to goto procedure value integer real Boolean array
              switch own true false comment and or not imp eqv div mod
            Operateurs : + - * / ^ ** = # != < <= > >= :=
            Ponctuation : ; , : ( ) [ ]
            Commentaire "comment ... ;" ignore jusqu'au prochain point-
              virgule (y compris sur plusieurs lignes)
            Chaines entre guillemets "..." (extension pour write/writeln)
            Nombres : entiers, reels avec point (3.14), exposant (10)
            Mode debug -d : afficher chaque token

  TODO 05 - TYPES DE DONNEES ET CONVERSIONS (32 BITS) [IMPLEMENTE]
            integer : 32 bits signe (DWORD), au lieu des 16 bits d'AL58C86
            real : flottant 64 bits via x87 (FLD/FSTP QWORD), decision
              retenue : la cible 386 permet un vrai support (3.14 de
              hello.a58, test_literals)
            Boolean : 0 ou 1 (DWORD) ; true et false
            string : pointeur vers donnees .data (litteraux seulement)
            label, switch, procedure : types d'entites du programme
            Conversions implicites (TypeConversion) :
              integer -> real (FILD), real -> integer (FISTP, arrondi au
              plus pres), integer -> Boolean (<> 0), Boolean -> integer
              (rien), real -> Boolean interdit
            Un entier utilise comme condition (if x then ...) est vrai
              s'il est different de zero (test_primexpr.a58)
            Table des types et TypeSizeof (integer=4, real=8, Boolean=4)
            Mode de passage des parametres : value (PM_VALUE) ou par nom
              (PM_NAME, thunk)

  TODO 06 - TABLE DES SYMBOLES ET PORTEES [IMPLEMENTE]
            TSymKind : SK_VAR, SK_ARRAY, SK_PROC, SK_FUNC, SK_LABEL,
              SK_SWITCH, SK_PARAM_VALUE, SK_PARAM_NAME, SK_OWN
            SymAdd, SymFind, SymFindInScope, SymEnterScope, SymLeaveScope
            Une portee par bloc begin...end et par procedure (le parseur
              ouvre aussi une portee pour tout autre bloc au besoin)
            Masquage lexical : t declare dans deux blocs freres
              (blocks.a58 : t=100 puis t=200)
            Variable non declaree (x := 42 dans test_errors.a58) :
              avertissement, declaration implicite integer, compilation
              poursuivie
            Calcul des offsets locaux [EBP-n] et des parametres [EBP+n]
            Niveau d'imbrication statique pour les procedures imbriquees

  TODO 07 - STRUCTURE D'UN PROGRAMME ET DECLARATIONS MELANGEES [IMPLEMENTE]
            Un programme est un bloc begin ... end ou une suite
              d'instructions sans begin/end englobant (test_types.a58,
              test_symbols.a58, test_emitter.a58)
            Plusieurs blocs begin...end consecutifs au niveau supreme
              (test_thunks.a58) executes en sequence dans un meme main
            Declarations melangees aux instructions, apres des
              instructions (hello.a58 : array, procedure, integer en
              plein corps, comme dans blocks.a58 et arrays.a58)
            Declarations : integer, real, Boolean, own, array, procedure,
              switch, y compris "integer a, b, c ;" (liste d'identificateurs)
            Instruction vide et expression isolee ("42;", "3 + 4;",
              "true and false;") : evaluee puis ignoree

  TODO 08 - EXPRESSIONS ARITHMETIQUES ET PRECEDENCE [A FAIRE]
            Parseur a precedence (Pratt) a 9 niveaux, du plus fort :
              not et unaire +/- ; ^ et ** (droite) ; * / div mod ;
              + - ; relationnels ; and ; or ; imp ; eqv
            Entiers : ADD, SUB, IMUL, CDQ + IDIV, mod via EDX
            "/" : division entiere entre entiers (42 / 6), division
              reelle si un operande est real
            Puissance : appel de _A58RT_POW (entiers) ou x87 (reels)
            Pliage de constantes a la compilation
            Debordement et division par zero : message d'erreur runtime
            Expressions couvertes : test_binexpr, test_operators, math

  TODO 09 - RELATIONNELS, BOOLEENS ET EXPRESSIONS CONDITIONNELLES [A FAIRE]
            Comparaisons = # != < <= > >= : CMP + SETcc / Jcc, resultat
              0 ou 1 dans EAX
            and, or en court-circuit ; not ; imp (not a or b) ; eqv
              ((a and b) or (not a and not b))
            Expression conditionnelle : if c then e1 else e2 comme valeur
              (x := if b then 1 else 2), imbriquee (test_primexpr)
            Boolean procedure retournant "if ... then 1 else 0"
            Conditions utilisables dans if, for while, switch
            Refuser les comparaisons chainees (a < b < c) avec erreur
            Exemples : bool.a58, test_boolexpr.a58

  TODO 10 - VARIABLES, AFFECTATIONS ET VARIABLES OWN [A FAIRE]
            Variables globales : section .data, label _A58V_nom
            Variables locales de bloc/procedure : [EBP-n]
            Variables own : section .data, persistantes entre appels,
              initialisees a zero ; accessibles seulement dans leur bloc
              (blocks.a58, test_vars.a58, test_primexpr.a58)
            Affectation := avec conversion de type selon la cible
            Affectation multiple a := b := expr (associative a droite)
            Valeur negative et litteral signe ("b := -7")
            Initialisation des variables locales non specifiee en Algol
              58 : choisir et documenter (zero recommande)

  TODO 11 - TABLEAUX [A FAIRE]
            Declaration : [integer|real|Boolean] array nom[lo:hi] et
              multidimensionnelle nom[lo1:hi1, lo2:hi2] (matrice 3x3)
            Bornes constantes (declarations globales) et bornes
              calculees a l'execution (tableaux locaux dynamiques,
              allocation sur la pile ou sur le tas Win32)
            Acces : calcul (i - lo) * taille, multidimensionnel en
              row-major, expression comme indice (V[j + 1])
            Bornes non standard (W[5:9], R[0:2] real, flags[0:4] Boolean)
            Verification de bornes a l'execution : _A58RT_CHKIDX
            Tableau en parametre de procedure (adresse + bornes)
            Exemples : arrays.a58, test_arrays.a58, test_dataseg.a58

  TODO 12 - INSTRUCTIONS CONDITIONNELLES ET BOUCLES FOR [A FAIRE]
            if cond then stmt [else stmt], else lie au if le plus proche
            for v := e1 step e2 until e3 do stmt (pas positif ou negatif ;
              boucle vide si bornes inversees ; reevaluation des bornes
              a chaque iteration selon la semantique Algol)
            for v := e while cond do stmt
            for v := e do stmt (clause simple, test_forloop test 7)
            Liste de clauses separees par virgule, de types differents :
              for v := a, b step c until d, e while f do stmt
            Corps simple ou bloc begin...end
            Exemples : control.a58, test_forloop.a58, test_ifthenelse.a58

  TODO 13 - GO TO, ETIQUETTES ET SWITCH [A FAIRE]
            Etiquettes symboliques (fin:) et numeriques (100:), avec
              etiquette suivie d'une instruction (etiq6b: goto etiq6a)
            go to et goto (un ou deux mots), renvois avant et arriere
            Resolution par table de fixups (etiquette utilisee avant sa
              declaration)
            Saut hors d'un bloc : restaurer ESP/EBP du bloc cible
            Avertissement : etiquette non utilisee ; erreur : etiquette
              inconnue, dupliquee ou saut dans un bloc interne
            switch s := l1, l2, l3 ; avec go to s[i], indice expression
              (s3[1 + 1]), switch contenant des expressions conditionnelles
            Table de switch dans .data, saut indirect JMP [table+idx*4]
            Indice hors bornes (1..n) : avertissement/continuer sur
              l'instruction suivante
            Exemples : switch.a58, test_switch.a58, test_goto.a58

  TODO 14 - PROCEDURES ET FONCTIONS [A FAIRE]
            procedure nom(params) ; value ... ; specs ; corps
            Procedure sans parametre et appelee avec "()" (greet())
            Fonctions typees : integer / real / Boolean procedure, valeur
              retournee dans EAX (ou ST0 pour real) via "nom := expr"
            Specifications des parametres : value a, b ; integer a ;
              integer b ; (plusieurs lignes de specifications)
            Parametres par valeur : copie sur la pile
            Procedures imbriquees (outer/inner) avec lien statique et
              acces aux variables de l'englobante
            Variables globales modifiees par effet de bord (counter)
            Recursion, convention d'appel interne documentee (empilage
              droite a gauche, nettoyage par l'appelant, EBP sauvegarde)
            Exemples : procs.a58, test_procedures.a58

  TODO 15 - PARAMETRES PAR NOM ET THUNKS [A FAIRE]
            Par defaut un parametre est passe par nom (substitution
              textuelle reevaluee a chaque acces)
            Un thunk _A58TH_proc_param par argument : evalue l'expression
              dans le contexte de l'appelant (lien statique restaure) et
              retourne la valeur dans EAX
            Argument variable simple : optimisation par reference
            Argument constant : constante directe (showconst(123))
            Argument expression (b + 5, f * f + 1) : thunk complet
            Parametre par nom ecrit par la procedure : thunk d'ecriture
              (L-value) quand l'argument est une variable ou un tableau
            Melange value / name dans un meme appel (twoparam)
            Jensen's device : somme d'une expression indicee par i
            Exemples : test_thunks.a58, procs.a58

  TODO 16 - ENTREES/SORTIES : WRITE, WRITELN, READ, READLN [A FAIRE]
            write(a, b, ...) avec liste d'arguments heterogenes :
              chaines, entiers, reels, booleens, expressions
              (write("x=", x, " y=", y))
            writeln(...) : ajoute CR LF ; writeln() et writeln("") seuls
            write d'un booleen affiche "true" ou "false"
            Entiers signes positifs et negatifs (write(-7))
            Constantes immediates (writeln(123))
            read(var) / readln(var) : lire un entier au clavier et
              l'affecter, y compris element de tableau
            Sortie sur stdout par defaut, runtime en WriteFile Win32
            Exemples : hello.a58, test_readwrite.a58, test_literals.a58

  TODO 17 - FONCTIONS INTRINSEQUES [A FAIRE]
            abs, sign, entier, sqrt, max, min, mod(a, b) en fonction
            Avec x87 : sin, cos, arctan, ln, exp, sqrt reels corrects
              (au lieu des stubs 16 bits), puissance reelle
            Resultat integer ou real selon le type de l'argument
            Verification du nombre et du type d'arguments (erreur sinon)
            Un identificateur intrinseque peut etre redefini par une
              procedure utilisateur (la declaration utilisateur gagne)
              (exemple : integer procedure max(a, b) dans hello.a58)
            Exemples : test_intrinsics.a58, math.a58, test_runtime.a58

  TODO 18 - GENERATION DU CODE ASSEMBLEUR 80386 [A FAIRE]
            Representation du code : liste d'instructions internes avec
              labels et operandes (registres 32 bits, memoire, immediats)
            Emetteur ASM textuel (actif seulement avec -asm) :
              .386 / .MODEL FLAT, STDCALL / .DATA / .CODE / END
            EmitInstr, EmitLabel, EmitComment, EmitBlankLine, NewLabel
            Prologue/epilogue : PUSH EBP / MOV EBP,ESP / SUB ESP,n ...
              MOV ESP,EBP / POP EBP / RET n
            Sections : .text (code), .data (variables, own, tableaux,
              switch), .rdata (chaines litterales dedoublonnees)
            Imports Win32 declares via EXTERN/INCLUDELIB kernel32.lib
            Le listing doit pouvoir etre assemble par MASM/ASM.PAS sans
              modification (point d'entree _A58P_Main)

  TODO 19 - ENCODEUR BINAIRE x86-32 [A FAIRE]
            Encoder en octets le sous-ensemble 80386 genere : MOV, ADD,
              SUB, IMUL, IDIV, CDQ, NEG, NOT, AND, OR, XOR, CMP, TEST,
              SETcc, Jcc, JMP, CALL, RET, PUSH, POP, LEA, INC, DEC, SHL,
              SHR, instructions x87 utiles (FLD, FST, FADD, FILD, ...)
            Tampons de code et de donnees (MAX_BIN_CODE, MAX_BIN_DATA)
            Table de labels et table de fixups (rel8/rel32, adresses
              absolues de donnees, appels d'import)
            Choix du plus court Jcc/JMP (rel8 ou rel32) sans boucle
              infinie de relaxation
            Verification croisee avec le listing .ASM (-asm) et avec
              DISEXE.PAS / DISOBJ.PAS

  TODO 20 - ECRIVAIN PE (.EXE WINDOWS 32 BITS) [A FAIRE]
            En-tete MZ + stub DOS, signature PE, COFF File Header
              (machine 386), Optional Header (magic $010B, ImageBase
              $00400000, alignements 4096/512, subsystem console)
            Sections .text, .rdata, .data, .idata
            Table d'import : kernel32.dll (GetStdHandle, WriteFile,
              ReadFile, ExitProcess, HeapAlloc, GetProcessHeap) avec IAT
            Resolution des fixups en RVA, SizeOfImage/Headers/Code
            Fichier .EXE par defaut, executable sous Windows ou EMUW32
              (TESTS\EMUW32.PAS)

  TODO 21 - ECRIVAIN COFF (.OBJ, OPTION -obj) [A FAIRE]
            COFF File Header (machine 386), sections .text/.data/.rdata
              avec relocations (IMAGE_REL_I386_DIR32, REL32)
            Table des symboles : externes (_A58P_Main, imports Win32),
              statiques, auxiliaires ; table des chaines
            Un .OBJ lie par LINK.PAS (ou un linker externe) doit donner
              le meme comportement que l'.EXE direct
            Option -obj : ne pas produire de .EXE
            Option -obj -asm : produire .OBJ et .ASM

  TODO 22 - RUNTIME ALGOL 58 POUR WIN32 [A FAIRE]
            Routines internes, sans bibliotheque C :
              _A58RT_PRINT / _A58RT_PRINTLN (WriteFile sur stdout)
              _A58RT_NUMTOSTR / _A58RT_REALTOSTR (itoa, ftoa)
              _A58RT_STRTONUM (atoi, entree standard via ReadFile)
              _A58RT_ABS, SIGN, SQRT, POW, MAX, MIN
              _A58RT_CHKIDX (bornes tableau) et _A58RT_PANIC (message +
                ExitProcess(1))
              Division par zero et debordement
            Initialisation : GetStdHandle(STD_OUTPUT_HANDLE / INPUT)
            Sortie : ExitProcess(0) a la fin de _A58P_Main
            Emission du runtime seulement pour les routines utilisees
              (reduction de la taille des .EXE)

  TODO 23 - GESTION DES ERREURS ET AVERTISSEMENTS [A FAIRE]
            Erreurs lexicales : caractere invalide, chaine non fermee,
              commentaire non termine, nombre hors limites
            Erreurs syntaxiques : token inattendu, begin/end non apparie,
              parenthese ou crochet non ferme, point-virgule manquant
            Erreurs semantiques : type incompatible, appel avec mauvais
              nombre d'arguments, etiquette inconnue, doublon de
              declaration dans une meme portee
            Avertissements : variable non declaree (declaration implicite),
              etiquette non utilisee, indice de switch hors bornes
            Recuperation : synchronisation sur ; ou mot-cle (begin, end,
              for, if, procedure) pour reporter plusieurs erreurs
            Format "fichier(ligne,col) : erreur/avertissement : message"
            Compteurs finaux, code de retour EXIT_ERROR si erreurs,
              aucun fichier de sortie corrompu en cas d'erreur
            Exemple : test_errors.a58 (compilation poursuivie)

  TODO 24 - PROGRAMME PRINCIPAL, MODES VERBEUX ET DEBOGAGE [A FAIRE]
            Run : lexeur -> parseur/generateur -> encodeur -> ecrivain
              (PE ou COFF) -> .ASM optionnel -> statistiques
            Mode -v : phases, tailles .text/.data, nombre de symboles
            Mode -d : dump des tokens, de la table des symboles et du
              code interne
            Mode -w : activer/desactiver les avertissements
            Suppression de sortie partielle si erreur
            Verifier que l'absence de -asm ne cree jamais de .ASM, que
              -obj ne cree jamais de .EXE, et que sans option on obtient
              uniquement le .EXE

  TODO 25 - VALIDATION SUR TOUS LES EXEMPLES SAMPLES\ALGOL58\* [A FAIRE]
            Compiler les 31 fichiers : arrays, blocks, bool, control,
              hello, math, procs, switch, test_arrays, test_binexpr,
              test_blocks, test_boolexpr, test_dataseg, test_emitter,
              test_errors, test_final, test_forloop, test_goto,
              test_ifthenelse, test_intrinsics, test_literals,
              test_operators, test_primexpr, test_procedures,
              test_readwrite, test_runtime, test_switch, test_symbols,
              test_thunks, test_types, test_vars
            Creer les sorties attendues (.exp) puis un script
              TESTS\test_al58cw32.sh (modele : test_cscw32.sh,
              test_adacw32.sh) executant chaque .EXE via Wine ou EMUW32
              et comparant la sortie
            Tester les trois modes : .EXE (defaut), .OBJ (-obj) et
              .ASM (-asm), verifier que -asm est optionnel
            Cas speciaux : test_errors.a58 doit compiler en signalant
              les avertissements ; test_types, test_symbols et
              test_emitter (expressions isolees, sans begin) doivent
              produire un .EXE valide
            Mettre a jour README.md (ligne AL58CW32.PAS), ajouter
              DOC\TODO\AL58CW32.txt et BIN\AL58CW32.EXE
  ============================================================ *)

{ ============================================================
  AL58CW32 - Compilateur Algol 58 -> assembleur 80386 / Win32
  Compilation : fpc -Mtp AL58CW32.PAS
  ============================================================ }

Program AL58CW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$IFNDEF FPC}{$N+}{$ENDIF}
{$I-} { Desactiver les IO-check pour gerer nous-memes les erreurs }

{ ============================================================
  SECTION 1 - CONSTANTES (TODO 01, 03)
  ============================================================ }
Const
  AL58CW32_VERSION = '0.1';
  AL58CW32_DATE    = '2026';

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Differences avec AL58C86 (cible 8086, 16 bits, DOS) :
      - registres 32 bits (EAX, EBX, ECX, EDX, ESI, EDI, EBP, ESP)
      - modele FLAT : pas de segments, pas de limite de 64 Ko
      - integer sur 32 bits signes
      - sorties par API Win32 (kernel32) au lieu de INT 21h
      - sortie finale : .EXE (PE) ou .OBJ (COFF), .ASM optionnel }
  ABI_WORD_SIZE = 4;   { taille d un registre / d un integer en octets }
  ABI_REAL_SIZE = 8;   { real : flottant 64 bits (x87)                   }
  ABI_RET_REG   = 'EAX';
  ABI_FRAME_REG = 'EBP';
  ABI_STACK_REG = 'ESP';
  ABI_PARAM_BASE = 8;  { [EBP+8] = premier parametre (apres EBP, retour) }

  { ---- Format PE (.EXE Windows 32 bits) ---- }
  PE_DOS_MAGIC     = $5A4D;       { 'MZ'                               }
  PE_SIGNATURE     = $00004550;   { 'PE',0,0                           }
  PE_MACHINE_I386  = $014C;
  PE_OPT_SIZE      = 224;         { taille de l Optional Header 32 bits }
  PE_MAGIC_32      = $010B;
  PE_IMG_BASE      = $00400000;
  PE_SEC_ALIGN     = 4096;
  PE_FILE_ALIGN    = 512;
  PE_SUBSYS_CUI    = 3;           { sous-systeme console               }
  PE_FILE_EXE      = $0002;       { IMAGE_FILE_EXECUTABLE_IMAGE        }
  PE_FILE_32BIT    = $0100;       { IMAGE_FILE_32BIT_MACHINE           }
  PE_SCN_TEXT      = $60000020;   { code, execute, read                }
  PE_SCN_RDATA     = $40000040;   { donnees initialisees, read         }
  PE_SCN_DATA      = $C0000040;   { donnees initialisees, read, write  }

  { ---- Format COFF (.OBJ) ---- }
  COFF_SYM_EXTERNAL = 2;
  COFF_SYM_STATIC   = 3;
  COFF_REL_DIR32    = $0006;      { IMAGE_REL_I386_DIR32               }
  COFF_REL_REL32    = $0014;      { IMAGE_REL_I386_REL32               }

  { ---- Tampons du code binaire (TODO 19 a 21) ---- }
  MAX_BIN_CODE  = {$IFDEF FPC}262144{$ELSE}16384{$ENDIF};
  MAX_BIN_DATA  = {$IFDEF FPC}262144{$ELSE}16384{$ENDIF};
  MAX_BIN_LBL   = {$IFDEF FPC}8192{$ELSE}512{$ENDIF};
  MAX_BIN_FIX   = {$IFDEF FPC}16384{$ELSE}512{$ENDIF};

  { ---- Limites internes du compilateur (32 bits) ---- }
  MAX_SYM       = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_PROC      = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}2048{$ELSE}128{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}32{$ELSE}16{$ENDIF};
  MAX_DIM       = 8;      { dimensions maximales d un tableau          }
  MAX_SWITCH    = 256;    { designateurs maximaux d un switch          }
  MAX_LOOP_NEST = 32;     { imbrication maximale des boucles for       }
  MAX_ERRORS    = 30;     { arret apres ce nombre d erreurs            }
  MAX_STR       = 255;    { longueur maximale d une chaine litterale   }

  { ---- Prefixes de nommage ASM ---- }
  A58_VAR_PFX   = '_A58V_';     { variable scalaire                    }
  A58_PROC_PFX  = '_A58P_';     { procedure / fonction                 }
  A58_STR_PFX   = '_A58K_';     { constante chaine litterale           }
  A58_RT_PFX    = '_A58RT_';    { routine runtime                      }
  A58_LBL_PFX   = '_A58L_';     { label de saut interne                }
  A58_USR_PFX   = '_A58L_USR_'; { etiquette Algol (go to)              }
  A58_SW_PFX    = '_A58SW_';    { table switch                         }
  A58_OWN_PFX   = '_A58OWN_';   { variable own                         }
  A58_ARR_PFX   = '_A58ARR_';   { tableau                              }
  A58_THUNK_PFX = '_A58TH_';    { thunk de parametre par nom           }
  A58_MAIN_NAME = '_A58P_Main'; { point d entree du programme          }

{ ============================================================
  SECTION 2 - TYPES (TODO 01, 04, 05, 06)
  ============================================================ }
Type
  TString = String[255];

  { Tokens du lexeur (TODO 04) }
  TTokenKind = (
    TK_EOF,
    TK_INTEGER,
    TK_REAL,
    TK_IDENT,
    TK_KEYWORD,
    TK_OP,
    TK_PUNCT,
    TK_STRING
  );

  TToken = Record
    Kind    : TTokenKind;
    Val     : TString;     { texte ; mot-cle et operateur normalises }
    IntVal  : LongInt;     { valeur d un TK_INTEGER                  }
    RealVal : Double;      { valeur d un TK_REAL (et TK_INTEGER)     }
    Line    : Integer;
    Col     : Integer;
  End;

  { Options de la ligne de commande (TODO 02) }
  TOptions = Record
    SrcFile   : TString;    { fichier source .a58 / .alg              }
    OutFile   : TString;    { sortie principale (.exe ou .obj)        }
    AsmFile   : TString;    { listing .asm (si EmitAsm)               }
    Verbose   : Boolean;    { -v : banniere + statistiques            }
    DebugMode : Boolean;    { -d : dump des tokens                    }
    Warnings  : Boolean;    { -w : activer les avertissements         }
    EmitExe   : Boolean;    { produire un .EXE PE (defaut)            }
    EmitObj   : Boolean;    { -obj : produire seulement un .OBJ       }
    EmitAsm   : Boolean;    { -asm : produire aussi un .ASM           }
  End;

  { Etapes du pipeline :
      source .a58 -> lexeur -> parseur / table des symboles
      -> generation du code interne (listing .ASM optionnel)
      -> encodeur binaire x86-32 -> ecrivain COFF (.OBJ) ou PE (.EXE) }
  TPhase = (
    PH_LEX,       { TODO 04 : lexeur                                  }
    PH_PARSE,     { TODO 06-17 : parseur et table des symboles        }
    PH_CODEGEN,   { TODO 18 : code interne + listing .ASM optionnel   }
    PH_ENCODE,    { TODO 19 : encodeur binaire x86-32                 }
    PH_WRITE,     { TODO 20-21 : ecrivain PE (.EXE) ou COFF (.OBJ)    }
    PH_REPORT     { TODO 23-24 : statistiques et code de retour       }
  );

{ ============================================================
  SECTION 3 - VARIABLES GLOBALES (TODO 01, 02, 23)
  ============================================================ }
Var
  Opts       : TOptions;
  ErrorCount : Integer;   { erreurs de compilation signalees  }
  WarnCount  : Integer;   { avertissements signales           }

{ ============================================================
  SECTION 4 - UTILITAIRES (TODO 03)
  ============================================================ }
Function ItoS(V : LongInt) : TString;
Var
  S : TString;
Begin
  Str(V, S);
  ItoS := S;
End;

{ Nombre sur Width chiffres au moins, complete par des zeros }
Function ItoSZ(V : LongInt; Width : Integer) : TString;
Var
  S : TString;
Begin
  S := ItoS(V);
  While Length(S) < Width Do
    S := '0' + S;
  ItoSZ := S;
End;

Function UpCaseStr(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If R[I] In ['a'..'z'] Then
      R[I] := Chr(Ord(R[I]) - 32);
  UpCaseStr := R;
End;

{ Identificateur Algol -> fragment de nom ASM valide : lettres,
  chiffres et souligne conserves, tout autre caractere devient _.
  Algol 58 ne distingue pas majuscules et minuscules : la casse est
  normalisee en majuscules. }
Function AsmIdent(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := UpCaseStr(S);
  For I := 1 To Length(R) Do
    If Not (R[I] In ['A'..'Z', '0'..'9', '_']) Then
      R[I] := '_';
  AsmIdent := R;
End;

{ ---- Noms des symboles ASM : prefixe + identificateur ---- }
Function MangleVar(Const Name : TString) : TString;
Begin
  MangleVar := A58_VAR_PFX + AsmIdent(Name);
End;

Function MangleProc(Const Name : TString) : TString;
Begin
  MangleProc := A58_PROC_PFX + AsmIdent(Name);
End;

Function MangleOwn(Const Name : TString) : TString;
Begin
  MangleOwn := A58_OWN_PFX + AsmIdent(Name);
End;

Function MangleArr(Const Name : TString) : TString;
Begin
  MangleArr := A58_ARR_PFX + AsmIdent(Name);
End;

Function MangleSwitch(Const Name : TString) : TString;
Begin
  MangleSwitch := A58_SW_PFX + AsmIdent(Name);
End;

Function MangleRT(Const Name : TString) : TString;
Begin
  MangleRT := A58_RT_PFX + AsmIdent(Name);
End;

Function MangleUserLabel(Const Name : TString) : TString;
Begin
  MangleUserLabel := A58_USR_PFX + AsmIdent(Name);
End;

Function MangleThunk(Const Proc, Param : TString) : TString;
Begin
  MangleThunk := A58_THUNK_PFX + AsmIdent(Proc) + '_' + AsmIdent(Param);
End;

{ Labels internes et chaines : numerotation sur 5 chiffres }
Function MangleLabel(N : LongInt) : TString;
Begin
  MangleLabel := A58_LBL_PFX + ItoSZ(N, 5);
End;

Function MangleStr(N : LongInt) : TString;
Begin
  MangleStr := A58_STR_PFX + ItoS(N);
End;

Function PhaseName(P : TPhase) : String;
Begin
  Case P Of
    PH_LEX     : PhaseName := 'lexeur';
    PH_PARSE   : PhaseName := 'parseur';
    PH_CODEGEN : PhaseName := 'generation du code';
    PH_ENCODE  : PhaseName := 'encodeur x86-32';
    PH_WRITE   : PhaseName := 'ecrivain PE/COFF';
    PH_REPORT  : PhaseName := 'rapport';
  End;
End;

Function StrLower(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If R[I] In ['A'..'Z'] Then
      R[I] := Chr(Ord(R[I]) + 32);
  StrLower := R;
End;

{ Position du point de l extension (0 si aucune extension) }
Function ExtPos(Const Name : TString) : Integer;
Var
  I : Integer;
Begin
  ExtPos := 0;
  I := Length(Name);
  While I > 0 Do
  Begin
    If Name[I] = '.' Then
    Begin
      ExtPos := I;
      Exit;
    End;
    If Name[I] In ['\', '/', ':'] Then Exit;
    Dec(I);
  End;
End;

Function GetExt(Const Name : TString) : TString;
Var
  P : Integer;
Begin
  P := ExtPos(Name);
  If P = 0 Then
    GetExt := ''
  Else
    GetExt := StrLower(Copy(Name, P, 255));
End;

Function ReplaceExt(Const Name, Ext : TString) : TString;
Var
  P : Integer;
Begin
  P := ExtPos(Name);
  If P = 0 Then
    ReplaceExt := Name + Ext
  Else
    ReplaceExt := Copy(Name, 1, P - 1) + Ext;
End;

Function FileExists(Const Name : TString) : Boolean;
Var
  F : File;
Begin
  Assign(F, Name);
  Reset(F, 1);
  If IOResult = 0 Then
  Begin
    Close(F);
    FileExists := True;
  End
  Else
    FileExists := False;
End;

{ ============================================================
  SECTION 5 - OPTIONS DE LIGNE DE COMMANDE (TODO 02)
  ============================================================ }
Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('AL58CW32: FATAL: ', Msg);
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('AL58CW32: warning: ', Msg);
  Inc(WarnCount);
End;

{ Erreur / avertissement localise dans le source (TODO 23 etendra) }
Procedure ErrorAt(Line, Col : Integer; Const Msg : TString);
Begin
  WriteLn('AL58CW32: ', Opts.SrcFile, ':', Line, ':', Col,
          ': error: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, compilation arretee');
End;

Procedure WarnAt(Line, Col : Integer; Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('AL58CW32: ', Opts.SrcFile, ':', Line, ':', Col,
          ': warning: ', Msg);
  Inc(WarnCount);
End;

Procedure ShowBanner;
Begin
  WriteLn('AL58CW32 ', AL58CW32_VERSION, ' (', AL58CW32_DATE, ') - ',
          'Compilateur Algol 58 vers 80386 / Windows 32 bits');
End;

Procedure ShowUsage(Code : Integer);
Begin
  ShowBanner;
  WriteLn;
  WriteLn('Syntaxe: AL58CW32 <source.a58> [-o sortie] [-obj] [-asm]',
          ' [-v] [-d] [-w] [-h]');
  WriteLn;
  WriteLn('  source.a58 : fichier Algol 58 source (.a58 ou .alg)');
  WriteLn('  -o nom     : nom du fichier de sortie principal');
  WriteLn('  -obj       : produire seulement un .OBJ (COFF), pas de .EXE');
  WriteLn('  -asm       : produire aussi un listing .ASM (optionnel)');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn('  -h, --help : cette aide');
  WriteLn;
  WriteLn('Par defaut, produit source.exe (PE Windows 32 bits).');
  Halt(Code);
End;

Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.AsmFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
  Opts.EmitExe   := True;
  Opts.EmitObj   := False;
  Opts.EmitAsm   := False;
End;

Procedure ParseArgs;
Var
  I   : Integer;
  Arg : TString;
  Opt : TString;
  Ext : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowUsage(EXIT_USAGE);

  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    Opt := StrLower(Arg);

    If (Opt = '-h') Or (Opt = '--help') Or (Opt = '/?') Then
      ShowUsage(EXIT_OK)
    Else If Opt = '-v' Then
      Opts.Verbose := True
    Else If Opt = '-d' Then
      Opts.DebugMode := True
    Else If Opt = '-w' Then
      Opts.Warnings := True
    Else If Opt = '-obj' Then
      Opts.EmitObj := True
    Else If Opt = '-asm' Then
      Opts.EmitAsm := True
    Else If Opt = '-o' Then
    Begin
      Inc(I);
      If I > ParamCount Then
      Begin
        WriteLn('AL58CW32: -o demande un nom de fichier');
        ShowUsage(EXIT_USAGE);
      End;
      Opts.OutFile := ParamStr(I);
    End
    Else If (Arg <> '') And (Arg[1] = '-') Then
    Begin
      WriteLn('AL58CW32: option inconnue: ', Arg);
      ShowUsage(EXIT_USAGE);
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else
    Begin
      WriteLn('AL58CW32: argument inattendu: ', Arg);
      ShowUsage(EXIT_USAGE);
    End;
    Inc(I);
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('AL58CW32: fichier source manquant');
    ShowUsage(EXIT_USAGE);
  End;

  { Extension du source : .a58 ou .alg (.a58 ajoute si absente) }
  If ExtPos(Opts.SrcFile) = 0 Then
  Begin
    If FileExists(Opts.SrcFile + '.a58') Then
      Opts.SrcFile := Opts.SrcFile + '.a58'
    Else
      Opts.SrcFile := Opts.SrcFile + '.alg';
  End;
  Ext := GetExt(Opts.SrcFile);
  If (Ext <> '.a58') And (Ext <> '.alg') Then
    FatalError('extension non supportee (attendu .a58 ou .alg): ' +
               Opts.SrcFile);
  If Not FileExists(Opts.SrcFile) Then
    FatalError('fichier source introuvable: ' + Opts.SrcFile);

  { Sortie principale : .EXE par defaut, .OBJ seul avec -obj }
  If Opts.EmitObj Then
    Opts.EmitExe := False;
  If Opts.OutFile = '' Then
  Begin
    If Opts.EmitExe Then
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.exe')
    Else
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.obj');
  End
  Else If ExtPos(Opts.OutFile) = 0 Then
  Begin
    If Opts.EmitExe Then
      Opts.OutFile := Opts.OutFile + '.exe'
    Else
      Opts.OutFile := Opts.OutFile + '.obj';
  End;

  { Listing assembleur optionnel : meme nom de base que la sortie }
  Opts.AsmFile := ReplaceExt(Opts.OutFile, '.asm');

  If StrLower(Opts.OutFile) = StrLower(Opts.SrcFile) Then
    FatalError('la sortie ecraserait le source: ' + Opts.OutFile);
  If GetExt(Opts.OutFile) = '.asm' Then
    FatalError('-o ne peut pas designer un .asm; utiliser -asm');
End;

{ ============================================================
  SECTION 6 - LEXEUR (TODO 04)
  ============================================================ }
Const
  KEYWORD_COUNT = 29;
  KeywordTab : Array[1..KEYWORD_COUNT] Of String[9] = (
    'begin', 'end', 'if', 'then', 'else', 'for', 'do', 'step', 'until',
    'while', 'goto', 'procedure', 'value', 'integer', 'real', 'boolean',
    'array', 'switch', 'own', 'true', 'false', 'and', 'or', 'not', 'imp',
    'eqv', 'div', 'mod', 'comment'
  );
  LEX_BUFSIZE = 4096;
  LEX_EOF     = #0;   { sentinelle de fin de fichier }

Var
  LexF       : File;
  LexOpened  : Boolean;
  LexBuf     : Array[0..LEX_BUFSIZE - 1] Of Byte;
  LexBufLen  : Integer;
  LexBufPos  : Integer;
  LexHitEOF  : Boolean;
  LexCur     : Char;       { caractere courant                    }
  LexNxt     : Char;       { caractere suivant (lookahead de 1)   }
  LexLine    : Integer;    { ligne du caractere courant           }
  LexCol     : Integer;    { colonne du caractere courant         }
  LexPending : Boolean;    { un token est en attente (go to)      }
  LexPendTok : TToken;
  TokenCount : LongInt;    { tokens lus (statistiques)            }
  LexQuiet   : Boolean;    { vrai : ne pas rapporter les erreurs  }

{ Erreur lexicale ; la 2e passe (parseur) ne les repete pas }
Procedure LexError(Line, Col : Integer; Const Msg : TString);
Begin
  If Not LexQuiet Then ErrorAt(Line, Col, Msg);
End;

{ Lit un octet du fichier source ; #0 a la fin du fichier.
  Un octet 0 reel ou ^Z fait partie de la fin / est invalide. }
Function LexRawChar : Char;
Var
  B : Byte;
Begin
  LexRawChar := LEX_EOF;
  If LexHitEOF Then Exit;
  If LexBufPos >= LexBufLen Then
  Begin
    BlockRead(LexF, LexBuf, LEX_BUFSIZE, LexBufLen);
    LexBufPos := 0;
    If LexBufLen <= 0 Then
    Begin
      LexBufLen := 0;
      LexHitEOF := True;
      Exit;
    End;
  End;
  B := LexBuf[LexBufPos];
  Inc(LexBufPos);
  If B = 26 Then
    LexHitEOF := True          { ^Z : fin de fichier DOS }
  Else If B = 0 Then
    LexRawChar := #1           { NUL : caractere invalide }
  Else
    LexRawChar := Chr(B);
End;

Procedure LexNextChar;
Begin
  If LexCur = #10 Then
  Begin
    Inc(LexLine);
    LexCol := 1;
  End
  Else
    Inc(LexCol);
  LexCur := LexNxt;
  LexNxt := LexRawChar;
End;

Function LexPeekChar : Char;
Begin
  LexPeekChar := LexNxt;
End;

Procedure LexInit;
Begin
  Assign(LexF, Opts.SrcFile);
  Reset(LexF, 1);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le source: ' + Opts.SrcFile);
  LexOpened  := True;
  LexBufLen  := 0;
  LexBufPos  := 0;
  LexHitEOF  := False;
  LexPending := False;
  TokenCount := 0;
  LexLine    := 1;
  LexCol     := 0;
  LexCur     := LEX_EOF;
  LexNxt     := LexRawChar;
  LexNextChar;
End;

Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexF);
    LexOpened := False;
  End;
End;

Function IsLetter(C : Char) : Boolean;
Begin
  IsLetter := C In ['A'..'Z', 'a'..'z', '_'];
End;

Function IsDigit(C : Char) : Boolean;
Begin
  IsDigit := C In ['0'..'9'];
End;

Function IsKeyword(Const Low : TString) : Boolean;
Var
  I : Integer;
Begin
  IsKeyword := False;
  For I := 1 To KEYWORD_COUNT Do
    If KeywordTab[I] = Low Then
    Begin
      IsKeyword := True;
      Exit;
    End;
End;

Function TokenKindName(K : TTokenKind) : TString;
Begin
  Case K Of
    TK_EOF     : TokenKindName := 'EOF';
    TK_INTEGER : TokenKindName := 'INTEGER';
    TK_REAL    : TokenKindName := 'REAL';
    TK_IDENT   : TokenKindName := 'IDENT';
    TK_KEYWORD : TokenKindName := 'KEYWORD';
    TK_OP      : TokenKindName := 'OP';
    TK_PUNCT   : TokenKindName := 'PUNCT';
    TK_STRING  : TokenKindName := 'STRING';
  End;
End;

{ Identificateur ou mot-cle : lettre suivie de lettres/chiffres }
Procedure LexScanIdent(Var T : TToken);
Var
  Low : TString;
Begin
  T.Val := '';
  While IsLetter(LexCur) Or IsDigit(LexCur) Do
  Begin
    If Length(T.Val) < 255 Then
      T.Val := T.Val + LexCur;
    LexNextChar;
  End;
  Low := StrLower(T.Val);
  If IsKeyword(Low) Then
  Begin
    T.Kind := TK_KEYWORD;
    T.Val  := Low;
  End
  Else
    T.Kind := TK_IDENT;
End;

{ Nombre : entier (123), reel (3.14, .5), exposant (1.5E3, 2@-2) }
Procedure LexScanNumber(Var T : TToken);
Var
  IntOvf  : Boolean;
  IsReal  : Boolean;
  Mant    : Double;
  E10     : Integer;
  ExpV    : Integer;
  ExpNeg  : Boolean;
  Digit   : Integer;
  I, N    : Integer;
  P       : Double;
Begin
  T.Val := '';
  T.IntVal := 0;
  IntOvf := False;
  IsReal := False;
  Mant := 0;
  E10 := 0;

  { partie entiere }
  While IsDigit(LexCur) Do
  Begin
    Digit := Ord(LexCur) - Ord('0');
    If T.IntVal > (MaxLongInt - Digit) Div 10 Then
      IntOvf := True
    Else
      T.IntVal := T.IntVal * 10 + Digit;
    Mant := Mant * 10 + Digit;
    If Length(T.Val) < 255 Then T.Val := T.Val + LexCur;
    LexNextChar;
  End;

  { partie fractionnaire : le point doit etre suivi d un chiffre }
  If (LexCur = '.') And IsDigit(LexPeekChar) Then
  Begin
    IsReal := True;
    If Length(T.Val) < 255 Then T.Val := T.Val + '.';
    LexNextChar;
    While IsDigit(LexCur) Do
    Begin
      Mant := Mant * 10 + (Ord(LexCur) - Ord('0'));
      Dec(E10);
      If Length(T.Val) < 255 Then T.Val := T.Val + LexCur;
      LexNextChar;
    End;
  End;

  { exposant : E, e ou @ suivi de [+|-] chiffres }
  If (LexCur In ['E', 'e', '@']) And
     (IsDigit(LexPeekChar) Or (LexPeekChar In ['+', '-'])) Then
  Begin
    IsReal := True;
    If Length(T.Val) < 255 Then T.Val := T.Val + LexCur;
    LexNextChar;
    ExpNeg := False;
    If LexCur In ['+', '-'] Then
    Begin
      ExpNeg := (LexCur = '-');
      If Length(T.Val) < 255 Then T.Val := T.Val + LexCur;
      LexNextChar;
    End;
    If Not IsDigit(LexCur) Then
      LexError(LexLine, LexCol, 'exposant invalide: chiffre attendu')
    Else
    Begin
      ExpV := 0;
      While IsDigit(LexCur) Do
      Begin
        If ExpV < 10000 Then
          ExpV := ExpV * 10 + (Ord(LexCur) - Ord('0'));
        If Length(T.Val) < 255 Then T.Val := T.Val + LexCur;
        LexNextChar;
      End;
      If ExpNeg Then ExpV := -ExpV;
      E10 := E10 + ExpV;
    End;
  End;

  If IsReal Then
  Begin
    T.Kind := TK_REAL;
    If (E10 > 308) Or (E10 < -308) Then
    Begin
      LexError(T.Line, T.Col, 'exposant hors limites: ' + T.Val);
      T.RealVal := 0;
    End
    Else
    Begin
      P := 1;
      N := Abs(E10);
      For I := 1 To N Do
        P := P * 10;
      If E10 < 0 Then
        T.RealVal := Mant / P
      Else
        T.RealVal := Mant * P;
    End;
  End
  Else
  Begin
    T.Kind := TK_INTEGER;
    If IntOvf Then
    Begin
      LexError(T.Line, T.Col, 'entier hors limites: ' + T.Val);
      T.IntVal := MaxLongInt;
    End;
    T.RealVal := T.IntVal;
  End;
End;

{ Chaine entre guillemets, sur une seule ligne, sans echappement }
Procedure LexScanString(Var T : TToken);
Var
  TooLong : Boolean;
Begin
  TooLong := False;
  T.Kind := TK_STRING;
  T.Val  := '';
  LexNextChar;                           { guillemet ouvrant }
  While (LexCur <> '"') And (LexCur <> #10) And (LexCur <> LEX_EOF) Do
  Begin
    If Length(T.Val) < MAX_STR Then
      T.Val := T.Val + LexCur
    Else If Not TooLong Then
    Begin
      LexError(T.Line, T.Col, 'chaine trop longue (max ' +
              ItoS(MAX_STR) + ' caracteres)');
      TooLong := True;                   { une seule erreur par chaine }
    End;
    LexNextChar;
  End;
  If LexCur = '"' Then
    LexNextChar
  Else
    LexError(T.Line, T.Col, 'chaine non fermee');
End;

{ Commentaire : "comment" deja lu, ignore tout jusqu au ; inclus }
Procedure LexSkipComment(StartLine, StartCol : Integer);
Begin
  While (LexCur <> ';') And (LexCur <> LEX_EOF) Do
    LexNextChar;
  If LexCur = ';' Then
    LexNextChar
  Else
    LexError(StartLine, StartCol,
            'commentaire non termine (point-virgule attendu)');
End;

{ Un token brut, sans fusion de "go to" }
Procedure LexScanToken(Var T : TToken);
Var
  Done : Boolean;
  C    : Char;
Begin
  Done := False;
  Repeat
    While LexCur In [' ', #9, #10, #12, #13] Do
      LexNextChar;
    T.Line := LexLine;
    T.Col  := LexCol;
    T.Val  := '';
    T.IntVal := 0;
    T.RealVal := 0;
    C := LexCur;
    Done := True;
    If C = LEX_EOF Then
      T.Kind := TK_EOF
    Else If IsLetter(C) Then
    Begin
      LexScanIdent(T);
      If (T.Kind = TK_KEYWORD) And (T.Val = 'comment') Then
      Begin
        LexSkipComment(T.Line, T.Col);
        Done := False;
      End;
    End
    Else If IsDigit(C) Or ((C = '.') And IsDigit(LexPeekChar)) Then
      LexScanNumber(T)
    Else If C = '"' Then
      LexScanString(T)
    Else
    Begin
      T.Kind := TK_OP;
      T.Val  := C;
      Case C Of
        '+', '-', '/', '^', '=', '#':
          LexNextChar;
        '*':
          Begin
            LexNextChar;
            If LexCur = '*' Then
            Begin
              T.Val := '^';              { ** equivaut a ^ }
              LexNextChar;
            End;
          End;
        '<', '>':
          Begin
            LexNextChar;
            If LexCur = '=' Then
            Begin
              T.Val := T.Val + '=';
              LexNextChar;
            End;
          End;
        '!':
          Begin
            LexNextChar;
            If LexCur = '=' Then
            Begin
              T.Val := '#';              { != equivaut a # }
              LexNextChar;
            End
            Else
            Begin
              LexError(T.Line, T.Col, 'caractere invalide: !');
              Done := False;
            End;
          End;
        ':':
          Begin
            LexNextChar;
            If LexCur = '=' Then
            Begin
              T.Val := ':=';
              LexNextChar;
            End
            Else
              T.Kind := TK_PUNCT;
          End;
        ';', ',', '(', ')', '[', ']':
          Begin
            T.Kind := TK_PUNCT;
            LexNextChar;
          End;
      Else
        Begin
          If (C < ' ') Or (C > '~') Then
            LexError(T.Line, T.Col,
                    'caractere invalide: code ' + ItoS(Ord(C)))
          Else
            LexError(T.Line, T.Col, 'caractere invalide: ' + C);
          LexNextChar;
          Done := False;
        End;
      End;
    End;
  Until Done;
End;

{ Token suivant. "go" suivi de "to" devient le mot-cle unique goto. }
Procedure LexNextToken(Var T : TToken);
Var
  T2 : TToken;
Begin
  If LexPending Then
  Begin
    T := LexPendTok;
    LexPending := False;
  End
  Else
    LexScanToken(T);
  If (T.Kind = TK_IDENT) And (UpCaseStr(T.Val) = 'GO') Then
  Begin
    LexScanToken(T2);
    If (T2.Kind = TK_IDENT) And (UpCaseStr(T2.Val) = 'TO') Then
    Begin
      T.Kind := TK_KEYWORD;
      T.Val  := 'goto';
    End
    Else
    Begin
      LexPendTok := T2;
      LexPending := True;
    End;
  End;
  Inc(TokenCount);
End;

{ Mode debug -d : une ligne par token }
Procedure PrintToken(Const T : TToken);
Begin
  Write(T.Line:5, ':', T.Col:3, ' ', TokenKindName(T.Kind):8);
  Case T.Kind Of
    TK_INTEGER : WriteLn(' ', T.IntVal);
    TK_REAL    : WriteLn(' ', T.RealVal:0:6, '  (', T.Val, ')');
    TK_STRING  : WriteLn(' "', T.Val, '"');
    TK_EOF     : WriteLn;
  Else
    WriteLn(' ', T.Val);
  End;
End;

Procedure PhaseLex;
Var
  T : TToken;
Begin
  LexInit;
  Repeat
    LexNextToken(T);
    If Opts.DebugMode Then PrintToken(T);
  Until T.Kind = TK_EOF;
  If Opts.Verbose Then
  Begin
    If LexCol = 1 Then Dec(LexLine);   { dernier octet = fin de ligne }
    WriteLn('  ', Opts.SrcFile, ': ', LexLine, ' ligne(s), ',
            TokenCount - 1, ' token(s)');
  End;
  LexClose;
End;

{ ============================================================
  SECTION 7 - TYPES ALGOL ET TABLE DES SYMBOLES (TODO 05, 06)
  ============================================================ }
Const
  { Indices des types primitifs Algol 58 dans TypeTab }
  TY_UNKNOWN       = -1;   { type indetermine (apres une erreur)      }
  TY_IDX_INTEGER   = 0;    { entier 32 bits signe                      }
  TY_IDX_REAL      = 1;    { flottant 64 bits (x87)                    }
  TY_IDX_BOOLEAN   = 2;    { 0 ou 1 dans un DWORD                      }
  TY_IDX_STRING    = 3;    { pointeur vers une chaine litterale        }
  TY_IDX_LABEL     = 4;    { etiquette (adresse de code)               }
  TY_IDX_SWITCH    = 5;    { aiguillage (adresse de table)             }
  TY_IDX_PROCEDURE = 6;    { procedure sans valeur de retour           }
  TY_IDX_ARRAY     = 7;    { descripteur de tableau (pointeur)         }
  TY_PRIM_COUNT    = 8;

Type
  TTypeKind = (
    TYK_INTEGER,
    TYK_REAL,
    TYK_BOOLEAN,
    TYK_STRING,
    TYK_LABEL,
    TYK_SWITCH,
    TYK_PROCEDURE,
    TYK_ARRAY
  );

  TTypeRec = Record
    Kind : TTypeKind;
    Name : String[12];
    Size : Integer;          { taille en octets d une valeur }
  End;

  { Conversion implicite a generer pour passer d un type a un autre }
  TConv = (
    CV_NONE,           { meme representation : rien a generer          }
    CV_INT_TO_REAL,    { FILD : entier ou booleen -> real              }
    CV_REAL_TO_INT,    { FISTP : real -> integer, arrondi au plus pres }
    CV_INT_TO_BOOL,    { TEST / SETNE : integer -> Boolean (<> 0)      }
    CV_ERROR           { conversion interdite                          }
  );

  { Mode de passage d un parametre de procedure }
  TParamMode = (
    PM_VALUE,          { value : copie de la valeur sur la pile        }
    PM_NAME            { par defaut : thunk reevalue a chaque acces    }
  );

Var
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

Function TypeAdd(K : TTypeKind; Const Name : TString;
                 Size : Integer) : Integer;
Begin
  If TypeCount >= MAX_TYPE Then
    FatalError('table des types pleine');
  TypeTab[TypeCount].Kind := K;
  TypeTab[TypeCount].Name := Name;
  TypeTab[TypeCount].Size := Size;
  TypeAdd := TypeCount;
  Inc(TypeCount);
End;

{ Enregistre les types primitifs, dans l ordre des TY_IDX_* }
Procedure TypeInit;
Begin
  TypeCount := 0;
  TypeAdd(TYK_INTEGER,   'integer',   ABI_WORD_SIZE);
  TypeAdd(TYK_REAL,      'real',      ABI_REAL_SIZE);
  TypeAdd(TYK_BOOLEAN,   'Boolean',   ABI_WORD_SIZE);
  TypeAdd(TYK_STRING,    'string',    ABI_WORD_SIZE);
  TypeAdd(TYK_LABEL,     'label',     ABI_WORD_SIZE);
  TypeAdd(TYK_SWITCH,    'switch',    ABI_WORD_SIZE);
  TypeAdd(TYK_PROCEDURE, 'procedure', ABI_WORD_SIZE);
  TypeAdd(TYK_ARRAY,     'array',     ABI_WORD_SIZE);
End;

Function TypeValid(T : Integer) : Boolean;
Begin
  TypeValid := (T >= 0) And (T < TypeCount);
End;

Function TypeName(T : Integer) : TString;
Begin
  If TypeValid(T) Then
    TypeName := TypeTab[T].Name
  Else
    TypeName := '?';
End;

{ Taille en octets : integer=4, real=8, Boolean=4, pointeurs=4 }
Function TypeSizeof(T : Integer) : Integer;
Begin
  If TypeValid(T) Then
    TypeSizeof := TypeTab[T].Size
  Else
    TypeSizeof := ABI_WORD_SIZE;
End;

Function TypeIsReal(T : Integer) : Boolean;
Begin
  TypeIsReal := (T = TY_IDX_REAL);
End;

Function TypeIsNumeric(T : Integer) : Boolean;
Begin
  TypeIsNumeric := (T = TY_IDX_INTEGER) Or (T = TY_IDX_REAL);
End;

{ Types admis dans une expression arithmetique ou relationnelle :
  le Boolean est stocke comme 0 ou 1 et se comporte comme un entier. }
Function TypeIsArith(T : Integer) : Boolean;
Begin
  TypeIsArith := (T = TY_IDX_INTEGER) Or (T = TY_IDX_REAL) Or
                 (T = TY_IDX_BOOLEAN);
End;

{ Condition de if / while / expression conditionnelle : un entier
  est vrai s il est different de zero (test_primexpr.a58). }
Function TypeIsCondition(T : Integer) : Boolean;
Begin
  TypeIsCondition := (T = TY_IDX_BOOLEAN) Or (T = TY_IDX_INTEGER);
End;

{ Type d un mot-cle de declaration : integer, real, boolean }
Function TypeFromKeyword(Const Kw : TString) : Integer;
Begin
  If Kw = 'integer' Then
    TypeFromKeyword := TY_IDX_INTEGER
  Else If Kw = 'real' Then
    TypeFromKeyword := TY_IDX_REAL
  Else If Kw = 'boolean' Then
    TypeFromKeyword := TY_IDX_BOOLEAN
  Else
    TypeFromKeyword := TY_UNKNOWN;
End;

{ Type d un litteral : 42, 3.14, "abc", true, false }
Function TypeFromToken(Const T : TToken) : Integer;
Begin
  Case T.Kind Of
    TK_INTEGER : TypeFromToken := TY_IDX_INTEGER;
    TK_REAL    : TypeFromToken := TY_IDX_REAL;
    TK_STRING  : TypeFromToken := TY_IDX_STRING;
    TK_KEYWORD :
      If (T.Val = 'true') Or (T.Val = 'false') Then
        TypeFromToken := TY_IDX_BOOLEAN
      Else
        TypeFromToken := TY_UNKNOWN;
  Else
    TypeFromToken := TY_UNKNOWN;
  End;
End;

{ Conversion implicite de From vers To (affectation, parametre) :
    integer -> real     : CV_INT_TO_REAL
    real    -> integer  : CV_REAL_TO_INT (arrondi au plus pres)
    integer -> Boolean  : CV_INT_TO_BOOL (<> 0)
    Boolean -> integer  : CV_NONE (0 ou 1)
    Boolean -> real     : CV_INT_TO_REAL
    real    -> Boolean  : CV_ERROR
  Un type indetermine ne produit pas d erreur en cascade. }
Function TypeConversion(From, Dest : Integer) : TConv;
Begin
  TypeConversion := CV_ERROR;
  If (Not TypeValid(From)) Or (Not TypeValid(Dest)) Then
    TypeConversion := CV_NONE
  Else If From = Dest Then
    TypeConversion := CV_NONE
  Else If Dest = TY_IDX_INTEGER Then
  Begin
    If From = TY_IDX_REAL Then
      TypeConversion := CV_REAL_TO_INT
    Else If From = TY_IDX_BOOLEAN Then
      TypeConversion := CV_NONE;
  End
  Else If Dest = TY_IDX_REAL Then
  Begin
    If (From = TY_IDX_INTEGER) Or (From = TY_IDX_BOOLEAN) Then
      TypeConversion := CV_INT_TO_REAL;
  End
  Else If Dest = TY_IDX_BOOLEAN Then
  Begin
    If From = TY_IDX_INTEGER Then
      TypeConversion := CV_INT_TO_BOOL;
  End;
End;

Function TypeAssignable(From, Dest : Integer) : Boolean;
Begin
  TypeAssignable := (TypeConversion(From, Dest) <> CV_ERROR);
End;

{ Type resultat de A op B pour + - * : real des qu un operande est
  real, sinon integer. TY_UNKNOWN si un operande n est pas arithmetique. }
Function TypeArith(A, B : Integer) : Integer;
Begin
  If (Not TypeValid(A)) Or (Not TypeValid(B)) Then
    TypeArith := TY_UNKNOWN
  Else If (Not TypeIsArith(A)) Or (Not TypeIsArith(B)) Then
    TypeArith := TY_UNKNOWN
  Else If (A = TY_IDX_REAL) Or (B = TY_IDX_REAL) Then
    TypeArith := TY_IDX_REAL
  Else
    TypeArith := TY_IDX_INTEGER;
End;

{ Mode debug -d : liste des types enregistres }
Procedure TypeDump;
Var
  I : Integer;
Begin
  WriteLn('Types (', TypeCount, ') :');
  For I := 0 To TypeCount - 1 Do
    WriteLn('  ', I:2, '  ', Copy(TypeTab[I].Name + '          ', 1, 10),
            TypeTab[I].Size:3, ' octets');
End;

{ ============================================================
  TABLE DES SYMBOLES ET PORTEES (TODO 06)

  Allocation des variables :
    - niveau 0 (programme principal, y compris ses blocs imbriques) :
      donnees statiques dans .data, noms ASM uniques ; les procedures
      du niveau 0 y accedent directement, sans lien statique
    - variables d une procedure : locales [EBP-n]
    - parametres : [EBP+n], le premier en [EBP+8] ; les procedures
      declarees dans une autre procedure recoivent en plus un lien
      statique (BP de la procedure englobante) en [EBP+8], les
      parametres commencent alors en [EBP+12]
    - parametre par valeur : taille du type ; parametre par nom :
      8 octets (adresse du thunk + BP de l appelant)
  ============================================================ }
Const
  SYM_NAME_MAX    = 63;
  PARAM_NAME_SIZE = 8;
  MAX_IMPLICIT    = {$IFDEF FPC}256{$ELSE}16{$ENDIF};
  SYM_TOTAL       = MAX_SYM + MAX_IMPLICIT;

Type
  TName    = String[SYM_NAME_MAX];
  TMangled = String[127];

  TSymKind = (
    SK_VAR,           { variable scalaire                          }
    SK_OWN,           { variable scalaire own (persistante)        }
    SK_ARRAY,         { tableau                                    }
    SK_PROC,          { procedure sans valeur de retour            }
    SK_FUNC,          { procedure typee (fonction)                 }
    SK_LABEL,         { etiquette de go to                         }
    SK_SWITCH,        { aiguillage                                 }
    SK_PARAM_VALUE,   { parametre value                            }
    SK_PARAM_NAME     { parametre par nom (defaut)                 }
  );

  TStorage = (
    SC_NONE,          { pas de stockage de donnees                 }
    SC_GLOBAL,        { .data : label Mangled                      }
    SC_LOCAL,         { pile : [EBP + Offset], Offset < 0          }
    SC_PARAM          { pile : [EBP + Offset], Offset > 0          }
  );

  TSymRec = Record
    Name       : TName;       { identificateur tel qu ecrit          }
    Key        : TName;       { identificateur en majuscules         }
    Mangled    : TMangled;    { nom ASM (SC_GLOBAL, procedures)      }
    Kind       : TSymKind;
    TypeIdx    : Integer;     { type, ou type de retour / d element  }
    Storage    : TStorage;
    Offset     : LongInt;     { decalage par rapport a EBP           }
    ScopeId    : Integer;     { identifiant unique de la portee      }
    Level      : Integer;     { niveau d imbrication des procedures  }
    IsOwn      : Boolean;
    IsDefined  : Boolean;     { etiquette : definie ?                }
    IsUsed     : Boolean;     { etiquette : referencee ?             }
    Line       : Integer;
    Col        : Integer;
    ArrDims    : Integer;     { tableau : nombre de dimensions       }
    ArrLo      : Array[1..MAX_DIM] Of LongInt;
    ArrHi      : Array[1..MAX_DIM] Of LongInt;
    ArrDynamic : Boolean;     { tableau : bornes calculees a l exec. }
    ElemType   : Integer;     { tableau : type des elements          }
    ParamCount : Integer;     { procedure : nombre de parametres     }
    ParamSym   : Array[1..MAX_PARAM] Of Integer;
    ParamBytes : Integer;     { procedure : taille des parametres    }
    ParamIdx   : Integer;     { parametre : rang (1..n)              }
    SwitchCount: Integer;     { switch : nombre de designateurs      }
  End;

  TScopeRec = Record
    FirstSym   : Integer;     { premier symbole de la portee         }
    Id         : Integer;     { identifiant unique                   }
    IsProc     : Boolean;     { portee d une procedure ?             }
    ProcSym    : Integer;     { symbole de la procedure (ou -1)      }
    SavedLocal : LongInt;     { LocalOfs a l entree                  }
    SavedProc  : Integer;     { CurProcScope a l entree              }
    FrameSize  : LongInt;     { procedure : octets de locales max.   }
    RetOfs     : LongInt;     { fonction : cellule du resultat       }
  End;

  TUseRec = Record
    Base  : TMangled;
    Count : Integer;
  End;

Var
  SymTab       : Array[0..SYM_TOTAL - 1] Of TSymRec;
  SymCount     : Integer;     { symboles de la pile (0..SymCount-1)  }
  ImpCount     : Integer;     { symboles implicites (MAX_SYM..)      }
  ScopeTab     : Array[0..MAX_SCOPE - 1] Of TScopeRec;
  ScopeTop     : Integer;     { nombre de portees ouvertes           }
  ScopeSeq     : Integer;     { compteur d identifiants de portee    }
  CurLevel     : Integer;     { niveau de procedure courant (0=main) }
  CurProcScope : Integer;     { portee de la procedure courante      }
  LocalOfs     : LongInt;     { octets de locales alloues            }
  UseTab       : Array[0..SYM_TOTAL - 1] Of TUseRec;
  UseCount     : Integer;

{ Nom ASM unique : le premier usage garde Base, les suivants recoivent
  un suffixe __n (blocs freres declarant le meme identificateur). }
Function UniqueMangle(Const Base : TMangled) : TMangled;
Var
  I : Integer;
Begin
  For I := 0 To UseCount - 1 Do
    If UseTab[I].Base = Base Then
    Begin
      Inc(UseTab[I].Count);
      UniqueMangle := Base + '__' + ItoS(UseTab[I].Count);
      Exit;
    End;
  If UseCount >= SYM_TOTAL Then
    FatalError('table des noms ASM pleine');
  UseTab[UseCount].Base  := Base;
  UseTab[UseCount].Count := 1;
  Inc(UseCount);
  UniqueMangle := Base;
End;

Function SymKindName(K : TSymKind) : TString;
Begin
  Case K Of
    SK_VAR         : SymKindName := 'var';
    SK_OWN         : SymKindName := 'own';
    SK_ARRAY       : SymKindName := 'array';
    SK_PROC        : SymKindName := 'proc';
    SK_FUNC        : SymKindName := 'func';
    SK_LABEL       : SymKindName := 'label';
    SK_SWITCH      : SymKindName := 'switch';
    SK_PARAM_VALUE : SymKindName := 'param-value';
    SK_PARAM_NAME  : SymKindName := 'param-name';
  End;
End;

Function StorageName(S : TStorage) : TString;
Begin
  Case S Of
    SC_NONE   : StorageName := '-';
    SC_GLOBAL : StorageName := 'global';
    SC_LOCAL  : StorageName := 'local';
    SC_PARAM  : StorageName := 'param';
  End;
End;

Procedure SymInit;
Begin
  SymCount     := 0;
  ImpCount     := 0;
  ScopeTop     := 0;
  ScopeSeq     := 0;
  CurLevel     := 0;
  CurProcScope := -1;
  LocalOfs     := 0;
  UseCount     := 0;
End;

{ ---- Recherche ------------------------------------------------- }

Function SymMakeKey(Const Name : TString) : TName;
Begin
  SymMakeKey := Copy(UpCaseStr(Name), 1, SYM_NAME_MAX);
End;

{ Symbole visible le plus interne ; la pile masque les portees
  englobantes, puis les symboles implicites. -1 si introuvable. }
Function SymFind(Const Name : TString) : Integer;
Var
  I   : Integer;
  Key : TName;
Begin
  Key := SymMakeKey(Name);
  SymFind := -1;
  For I := SymCount - 1 Downto 0 Do
    If SymTab[I].Key = Key Then
    Begin
      SymFind := I;
      Exit;
    End;
  For I := MAX_SYM To MAX_SYM + ImpCount - 1 Do
    If SymTab[I].Key = Key Then
    Begin
      SymFind := I;
      Exit;
    End;
End;

{ Symbole declare dans la portee courante seulement. -1 si absent. }
Function SymFindInScope(Const Name : TString) : Integer;
Var
  I, First : Integer;
  Key      : TName;
Begin
  SymFindInScope := -1;
  If ScopeTop = 0 Then Exit;
  Key   := SymMakeKey(Name);
  First := ScopeTab[ScopeTop - 1].FirstSym;
  For I := SymCount - 1 Downto First Do
    If SymTab[I].Key = Key Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
End;

{ ---- Portees et allocation de la pile --------------------------- }

Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
    FatalError('blocs trop imbriques (max ' + ItoS(MAX_SCOPE) + ')');
  Inc(ScopeSeq);
  ScopeTab[ScopeTop].FirstSym   := SymCount;
  ScopeTab[ScopeTop].Id         := ScopeSeq;
  ScopeTab[ScopeTop].IsProc     := False;
  ScopeTab[ScopeTop].ProcSym    := -1;
  ScopeTab[ScopeTop].SavedLocal := LocalOfs;
  ScopeTab[ScopeTop].SavedProc  := CurProcScope;
  ScopeTab[ScopeTop].FrameSize  := 0;
  ScopeTab[ScopeTop].RetOfs     := 0;
  Inc(ScopeTop);
End;

{ Reserve Size octets (arrondis a 4) dans les locales de la procedure
  courante et retourne le decalage negatif par rapport a EBP. }
Function SymAllocLocal(Size : Integer) : LongInt;
Begin
  If CurProcScope < 0 Then
    FatalError('erreur interne: locale hors procedure');
  LocalOfs := LocalOfs + ((Size + 3) And (Not 3));
  If LocalOfs > ScopeTab[CurProcScope].FrameSize Then
    ScopeTab[CurProcScope].FrameSize := LocalOfs;
  SymAllocLocal := -LocalOfs;
End;

{ Ouvre la portee du corps d une procedure deja ajoutee a la table.
  Les parametres sont ensuite ajoutes par SymAdd. }
Procedure SymEnterProc(ProcIdx : Integer);
Begin
  SymEnterScope;
  ScopeTab[ScopeTop - 1].IsProc  := True;
  ScopeTab[ScopeTop - 1].ProcSym := ProcIdx;
  Inc(CurLevel);
  CurProcScope := ScopeTop - 1;
  LocalOfs := 0;
  If SymTab[ProcIdx].Kind = SK_FUNC Then
    ScopeTab[CurProcScope].RetOfs :=
      SymAllocLocal(TypeSizeof(SymTab[ProcIdx].TypeIdx));
End;

{ Procedure dont le corps est en cours de compilation (ou -1) }
Function SymCurProc : Integer;
Begin
  If CurProcScope < 0 Then
    SymCurProc := -1
  Else
    SymCurProc := ScopeTab[CurProcScope].ProcSym;
End;

{ Octets de locales du corps courant (pour SUB ESP, n au prologue) }
Function SymFrameSize : LongInt;
Begin
  If CurProcScope < 0 Then
    SymFrameSize := 0
  Else
    SymFrameSize := ScopeTab[CurProcScope].FrameSize;
End;

{ Decalage [EBP+n] de la cellule du resultat d une fonction }
Function SymResultOfs : LongInt;
Begin
  If CurProcScope < 0 Then
    SymResultOfs := 0
  Else
    SymResultOfs := ScopeTab[CurProcScope].RetOfs;
End;

{ ---- Ajout de symboles ------------------------------------------ }

Function SymAdd(Const Name : TString; K : TSymKind; TypeIdx : Integer;
                IsOwn : Boolean; Line, Col : Integer) : Integer;
Var
  I, P : Integer;
Begin
  If ScopeTop = 0 Then
    FatalError('erreur interne: aucune portee ouverte');
  If Length(Name) > SYM_NAME_MAX Then
    ErrorAt(Line, Col, 'identificateur trop long (max ' +
            ItoS(SYM_NAME_MAX) + '): ' + Name);

  I := SymFindInScope(Name);
  If I >= 0 Then
  Begin
    ErrorAt(Line, Col, 'declaration en double: ' + Name);
    SymAdd := I;
    Exit;
  End;
  If (ScopeTop = 1) And (K <> SK_LABEL) Then
    For I := MAX_SYM To MAX_SYM + ImpCount - 1 Do
      If SymTab[I].Key = SymMakeKey(Name) Then
      Begin
        ErrorAt(Line, Col, 'declaree apres un usage implicite: ' + Name);
        SymAdd := I;
        Exit;
      End;
  If SymCount >= MAX_SYM Then
    FatalError('table des symboles pleine (max ' + ItoS(MAX_SYM) + ')');

  I := SymCount;
  Inc(SymCount);
  FillChar(SymTab[I], SizeOf(TSymRec), 0);
  SymTab[I].Name      := Copy(Name, 1, SYM_NAME_MAX);
  SymTab[I].Key       := SymMakeKey(Name);
  SymTab[I].Kind      := K;
  SymTab[I].TypeIdx   := TypeIdx;
  SymTab[I].Storage   := SC_NONE;
  SymTab[I].ScopeId   := ScopeTab[ScopeTop - 1].Id;
  SymTab[I].Level     := CurLevel;
  SymTab[I].IsOwn     := IsOwn Or (K = SK_OWN);
  SymTab[I].Line      := Line;
  SymTab[I].Col       := Col;

  Case K Of
    SK_VAR, SK_OWN, SK_ARRAY:
      If (CurLevel = 0) Or SymTab[I].IsOwn Then
      Begin
        SymTab[I].Storage := SC_GLOBAL;
        If SymTab[I].IsOwn And (K <> SK_ARRAY) Then
          SymTab[I].Mangled := UniqueMangle(MangleOwn(Name))
        Else If K = SK_ARRAY Then
          SymTab[I].Mangled := UniqueMangle(MangleArr(Name))
        Else
          SymTab[I].Mangled := UniqueMangle(MangleVar(Name));
      End
      Else
      Begin
        SymTab[I].Storage := SC_LOCAL;
        If K = SK_ARRAY Then
          SymTab[I].Offset := SymAllocLocal(ABI_WORD_SIZE)
        Else
          SymTab[I].Offset := SymAllocLocal(TypeSizeof(TypeIdx));
      End;
    SK_PROC, SK_FUNC:
      SymTab[I].Mangled := UniqueMangle(MangleProc(Name));
    SK_LABEL:
      SymTab[I].Mangled := UniqueMangle(MangleUserLabel(Name));
    SK_SWITCH:
      SymTab[I].Mangled := UniqueMangle(MangleSwitch(Name));
    SK_PARAM_VALUE, SK_PARAM_NAME:
      Begin
        P := SymCurProc;
        If P < 0 Then
          FatalError('erreur interne: parametre hors procedure');
        If SymTab[P].ParamCount >= MAX_PARAM Then
          ErrorAt(Line, Col, 'trop de parametres (max ' +
                  ItoS(MAX_PARAM) + ')')
        Else
        Begin
          Inc(SymTab[P].ParamCount);
          SymTab[P].ParamSym[SymTab[P].ParamCount] := I;
          SymTab[I].ParamIdx := SymTab[P].ParamCount;
        End;
        SymTab[I].Storage := SC_PARAM;
      End;
  End;
  SymAdd := I;
End;

{ Variable utilisee sans declaration : avertissement, puis integer
  global implicite visible de partout (test_errors.a58, x := 42). }
Function SymImplicit(Const Name : TString; Line, Col : Integer) : Integer;
Var
  I : Integer;
Begin
  If ImpCount >= MAX_IMPLICIT Then
    FatalError('trop de variables implicites (max ' +
               ItoS(MAX_IMPLICIT) + ')');
  WarnAt(Line, Col, 'variable non declaree: ' + Name +
         ' (declaree integer)');
  I := MAX_SYM + ImpCount;
  Inc(ImpCount);
  FillChar(SymTab[I], SizeOf(TSymRec), 0);
  SymTab[I].Name    := Copy(Name, 1, SYM_NAME_MAX);
  SymTab[I].Key     := SymMakeKey(Name);
  SymTab[I].Kind    := SK_VAR;
  SymTab[I].TypeIdx := TY_IDX_INTEGER;
  SymTab[I].Storage := SC_GLOBAL;
  SymTab[I].ScopeId := 1;
  SymTab[I].Level   := 0;
  SymTab[I].Line    := Line;
  SymTab[I].Col     := Col;
  SymTab[I].Mangled := UniqueMangle(MangleVar(Name));
  SymImplicit := I;
End;

{ ---- Parametres de procedure ------------------------------------ }

Function SymFindParam(ProcIdx : Integer; Const Name : TString) : Integer;
Var
  K   : Integer;
  Key : TName;
Begin
  Key := SymMakeKey(Name);
  SymFindParam := -1;
  For K := 1 To SymTab[ProcIdx].ParamCount Do
    If SymTab[SymTab[ProcIdx].ParamSym[K]].Key = Key Then
    Begin
      SymFindParam := SymTab[ProcIdx].ParamSym[K];
      Exit;
    End;
End;

{ "value a, b ;" : passe le parametre par valeur }
Function SymMarkValue(ProcIdx : Integer; Const Name : TString) : Boolean;
Var
  S : Integer;
Begin
  S := SymFindParam(ProcIdx, Name);
  If S >= 0 Then
    SymTab[S].Kind := SK_PARAM_VALUE;
  SymMarkValue := (S >= 0);
End;

{ "integer a ;" : specification de type d un parametre }
Function SymSetParamType(ProcIdx : Integer; Const Name : TString;
                         T : Integer) : Boolean;
Var
  S : Integer;
Begin
  S := SymFindParam(ProcIdx, Name);
  If S >= 0 Then
    SymTab[S].TypeIdx := T;
  SymSetParamType := (S >= 0);
End;

Function SymParamSize(S : Integer) : Integer;
Begin
  If SymTab[S].TypeIdx = TY_IDX_ARRAY Then
    SymParamSize := ABI_WORD_SIZE          { adresse du descripteur }
  Else If SymTab[S].Kind = SK_PARAM_NAME Then
    SymParamSize := PARAM_NAME_SIZE        { thunk + BP appelant    }
  Else
    SymParamSize := (TypeSizeof(SymTab[S].TypeIdx) + 3) And (Not 3);
End;

{ A appeler apres les specifications : calcule les decalages [EBP+n]
  (le premier parametre en EBP+8, apres EBP et l adresse de retour,
  decale de 4 si un lien statique est recu) et ParamBytes. }
Procedure SymLayoutParams(ProcIdx : Integer);
Var
  K, S : Integer;
  Ofs  : LongInt;
Begin
  Ofs := ABI_PARAM_BASE;
  If SymTab[ProcIdx].Level >= 1 Then
    Ofs := Ofs + ABI_WORD_SIZE;           { lien statique }
  For K := 1 To SymTab[ProcIdx].ParamCount Do
  Begin
    S := SymTab[ProcIdx].ParamSym[K];
    SymTab[S].Offset := Ofs;
    Ofs := Ofs + SymParamSize(S);
  End;
  SymTab[ProcIdx].ParamBytes := Ofs - ABI_PARAM_BASE;
End;

{ ---- Etiquettes ------------------------------------------------- }

{ Reference "go to nom" : retrouve l etiquette visible, ou cree une
  etiquette pas encore definie dans la portee courante (renvoi avant). }
Function SymRefLabel(Const Name : TString; Line, Col : Integer) : Integer;
Var
  I   : Integer;
  Key : TName;
Begin
  Key := SymMakeKey(Name);
  For I := SymCount - 1 Downto 0 Do
    If (SymTab[I].Key = Key) And (SymTab[I].Kind = SK_LABEL) Then
    Begin
      SymTab[I].IsUsed := True;
      SymRefLabel := I;
      Exit;
    End;
  I := SymAdd(Name, SK_LABEL, TY_IDX_LABEL, False, Line, Col);
  SymTab[I].IsUsed := True;
  SymRefLabel := I;
End;

{ Definition "nom :" devant une instruction }
Function SymDefLabel(Const Name : TString; Line, Col : Integer) : Integer;
Var
  I : Integer;
Begin
  I := SymFindInScope(Name);
  If I >= 0 Then
  Begin
    If (SymTab[I].Kind = SK_LABEL) And (Not SymTab[I].IsDefined) Then
    Begin
      SymTab[I].IsDefined := True;     { fin d un renvoi avant }
      SymTab[I].Line := Line;
      SymTab[I].Col  := Col;
    End
    Else
      ErrorAt(Line, Col, 'etiquette dupliquee: ' + Name);
    SymDefLabel := I;
    Exit;
  End;
  I := SymAdd(Name, SK_LABEL, TY_IDX_LABEL, False, Line, Col);
  SymTab[I].IsDefined := True;
  SymDefLabel := I;
End;

{ ---- Impression et fermeture ------------------------------------ }

Procedure SymDumpScope(Scope : Integer);
Var
  I : Integer;
Begin
  WriteLn('Portee ', ScopeTab[Scope].Id, ' (niveau ', CurLevel,
          '), locales ', ScopeTab[Scope].FrameSize, ' octets :');
  For I := ScopeTab[Scope].FirstSym To SymCount - 1 Do
    WriteLn('  ', SymTab[I].Name, ' ', SymKindName(SymTab[I].Kind), ' ',
            TypeName(SymTab[I].TypeIdx), ' ', StorageName(SymTab[I].Storage),
            ' ', SymTab[I].Offset, ' ', SymTab[I].Mangled);
End;

{ Ferme la portee courante : verifie les etiquettes, libere les
  symboles et restaure l etat de la pile. }
Procedure SymLeaveScope;
Var
  I, S : Integer;
Begin
  If ScopeTop = 0 Then
    FatalError('erreur interne: fermeture sans portee ouverte');
  S := ScopeTop - 1;
  For I := ScopeTab[S].FirstSym To SymCount - 1 Do
    If SymTab[I].Kind = SK_LABEL Then
    Begin
      If Not SymTab[I].IsDefined Then
        ErrorAt(SymTab[I].Line, SymTab[I].Col,
                'etiquette non definie: ' + SymTab[I].Name)
      Else If Not SymTab[I].IsUsed Then
        WarnAt(SymTab[I].Line, SymTab[I].Col,
               'etiquette non utilisee: ' + SymTab[I].Name);
    End;
  If Opts.DebugMode Then SymDumpScope(S);
  SymCount := ScopeTab[S].FirstSym;
  LocalOfs := ScopeTab[S].SavedLocal;
  If ScopeTab[S].IsProc Then
    Dec(CurLevel);
  CurProcScope := ScopeTab[S].SavedProc;
  Dec(ScopeTop);
End;

{ ============================================================
  SECTION 8 - PARSEUR ET GENERATEUR DE CODE (TODO 07 a 17)
  ============================================================ }
Var
  CurToken   : TToken;       { token courant du parseur             }
  DeclCount  : LongInt;      { symboles declares (statistiques)     }
  BlockCount : LongInt;      { blocs begin...end analyses           }
  ProcCount  : LongInt;      { procedures declarees                 }

{ ---- Primitives du parseur -------------------------------------- }

Procedure ParserAdvance;
Begin
  LexNextToken(CurToken);
End;

Function TokText(Const T : TToken) : TString;
Begin
  Case T.Kind Of
    TK_EOF    : TokText := 'fin de fichier';
    TK_STRING : TokText := '"' + T.Val + '"';
    TK_INTEGER,
    TK_REAL   : TokText := T.Val;
  Else
    TokText := '''' + T.Val + '''';
  End;
End;

Procedure ParseError(Const Msg : TString);
Begin
  ErrorAt(CurToken.Line, CurToken.Col,
          Msg + ' (trouve: ' + TokText(CurToken) + ')');
End;

Function AtEOF : Boolean;
Begin
  AtEOF := (CurToken.Kind = TK_EOF);
End;

Function AtKw(Const S : TString) : Boolean;
Begin
  AtKw := (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = S);
End;

Function AtPunct(C : Char) : Boolean;
Begin
  AtPunct := (CurToken.Kind = TK_PUNCT) And (CurToken.Val = C);
End;

Function AtOp(Const S : TString) : Boolean;
Begin
  AtOp := (CurToken.Kind = TK_OP) And (CurToken.Val = S);
End;

Function AtTypeKw : Boolean;
Begin
  AtTypeKw := AtKw('integer') Or AtKw('real') Or AtKw('boolean');
End;

Function AtDeclKw : Boolean;
Begin
  AtDeclKw := AtTypeKw Or AtKw('own') Or AtKw('array') Or
              AtKw('procedure') Or AtKw('switch');
End;

Procedure ExpectPunct(C : Char);
Begin
  If AtPunct(C) Then
    ParserAdvance
  Else
    ParseError('''' + C + ''' attendu');
End;

{ Recuperation apres une erreur : avance jusqu au prochain ';' ou
  'end' (non consommes) pour reprendre l analyse (TODO 23). }
Procedure ParserSync;
Begin
  While Not (AtEOF Or AtPunct(';') Or AtKw('end')) Do
    ParserAdvance;
End;

Procedure ParseBlock; Forward;

{ Instruction simple (placeholder des TODO 08 a 13) : consomme les
  tokens jusqu au prochain ';' ou 'end' (non consommes). Un bloc
  begin...end imbrique est analyse a part pour que ses declarations
  et sa structure soient verifiees. L'expression isolee "42 ;" est
  donc lue puis ignoree. }
Procedure SkipStatement;
Begin
  While Not (AtEOF Or AtPunct(';') Or AtKw('end')) Do
    If AtKw('begin') Then
      ParseBlock
    Else
      ParserAdvance;
End;

{ ---- Declarations ----------------------------------------------- }

{ integer a, b, c   (declaration de variables, own ou non) }
Procedure ParseVarList(K : TSymKind; T : Integer; IsOwn : Boolean);
Var
  Done : Boolean;
Begin
  Repeat
    If CurToken.Kind <> TK_IDENT Then
    Begin
      ParseError('identificateur attendu dans la declaration');
      ParserSync;
      Exit;
    End;
    SymAdd(CurToken.Val, K, T, IsOwn, CurToken.Line, CurToken.Col);
    Inc(DeclCount);
    ParserAdvance;
    Done := Not AtPunct(',');
    If Not Done Then ParserAdvance;
  Until Done;
End;

{ Saute une expression de borne jusqu'a ':' ',' ']' ou ';' }
Procedure SkipBoundExpr;
Var
  Depth : Integer;
Begin
  Depth := 0;
  While Not AtEOF Do
  Begin
    If Depth = 0 Then
      If AtPunct(':') Or AtPunct(',') Or AtPunct(']') Or AtPunct(';')
         Or AtKw('end') Then
        Exit;
    If AtPunct('(') Or AtPunct('[') Then
      Inc(Depth)
    Else If (AtPunct(')') Or AtPunct(']')) And (Depth > 0) Then
      Dec(Depth);
    ParserAdvance;
  End;
End;

{ Borne de tableau : constante entiere signee, sinon expression a
  evaluer a l execution (Dyn = True, TODO 11). }
Procedure ParseBound(Var V : LongInt; Var Dyn : Boolean);
Var
  Neg : Boolean;
Begin
  Neg := False;
  V   := 0;
  If AtOp('-') Then
  Begin
    Neg := True;
    ParserAdvance;
  End
  Else If AtOp('+') Then
    ParserAdvance;
  If CurToken.Kind = TK_INTEGER Then
  Begin
    V := CurToken.IntVal;
    If Neg Then V := -V;
    ParserAdvance;
    If Not (AtPunct(':') Or AtPunct(',') Or AtPunct(']')) Then
    Begin
      Dyn := True;                { expression composee }
      SkipBoundExpr;
    End;
  End
  Else
  Begin
    Dyn := True;
    SkipBoundExpr;
  End;
End;

{ [integer|real|Boolean] array a, b [lo:hi, lo:hi], c [lo:hi]
  Un tableau sans type est de type real (regle d Algol 60). }
Procedure ParseArrayDecl(ElemType : Integer; IsOwn : Boolean);
Var
  Names : Array[1..16] Of Integer;
  NName : Integer;
  I, D  : Integer;
  Lo, Hi: LongInt;
  Dyn   : Boolean;
  Cur   : Integer;
Begin
  Repeat
    NName := 0;
    Repeat
      If CurToken.Kind <> TK_IDENT Then
      Begin
        ParseError('nom de tableau attendu');
        ParserSync;
        Exit;
      End;
      If NName < 16 Then
      Begin
        Inc(NName);
        Names[NName] := SymAdd(CurToken.Val, SK_ARRAY, ElemType, IsOwn,
                               CurToken.Line, CurToken.Col);
        SymTab[Names[NName]].ElemType := ElemType;
        Inc(DeclCount);
      End
      Else
        ParseError('trop de noms dans une declaration de tableau');
      ParserAdvance;
      If AtPunct(',') Then
        ParserAdvance
      Else
        Break;
    Until False;

    If Not AtPunct('[') Then
    Begin
      ParseError('''['' attendu apres le nom du tableau');
      ParserSync;
      Exit;
    End;
    ParserAdvance;
    D := 0;
    Repeat
      Dyn := False;
      ParseBound(Lo, Dyn);
      If AtPunct(':') Then
        ParserAdvance
      Else
        ParseError(''':'' attendu entre les bornes');
      ParseBound(Hi, Dyn);
      Inc(D);
      If D <= MAX_DIM Then
        For I := 1 To NName Do
        Begin
          Cur := Names[I];
          SymTab[Cur].ArrDims := D;
          SymTab[Cur].ArrLo[D] := Lo;
          SymTab[Cur].ArrHi[D] := Hi;
          If Dyn Then SymTab[Cur].ArrDynamic := True;
        End
      Else
        ParseError('trop de dimensions (max ' + ItoS(MAX_DIM) + ')');
      If (Not Dyn) And (Lo > Hi) Then
        ErrorAt(CurToken.Line, CurToken.Col,
                'bornes inversees: ' + ItoS(Lo) + ':' + ItoS(Hi));
      If AtPunct(',') Then
        ParserAdvance
      Else
        Break;
    Until False;
    ExpectPunct(']');
    If AtPunct(',') Then
      ParserAdvance
    Else
      Break;
  Until False;
End;

{ switch s := l1, l2, if b then l3 else l4
  Les designateurs sont comptes (virgules de premier niveau) ; leur
  traduction releve du TODO 13. }
Procedure ParseSwitchDecl;
Var
  S, Depth, N : Integer;
Begin
  If CurToken.Kind <> TK_IDENT Then
  Begin
    ParseError('nom de switch attendu');
    ParserSync;
    Exit;
  End;
  S := SymAdd(CurToken.Val, SK_SWITCH, TY_IDX_SWITCH, False,
              CurToken.Line, CurToken.Col);
  Inc(DeclCount);
  ParserAdvance;
  If AtOp(':=') Then
    ParserAdvance
  Else
    ParseError(''':='' attendu apres le nom du switch');
  N := 1;
  Depth := 0;
  If AtPunct(';') Or AtEOF Then
    ParseError('liste de designateurs attendue');
  While Not (AtEOF Or AtKw('end') Or (Depth = 0) And AtPunct(';')) Do
  Begin
    If AtPunct('(') Or AtPunct('[') Then
      Inc(Depth)
    Else If (AtPunct(')') Or AtPunct(']')) And (Depth > 0) Then
      Dec(Depth)
    Else If (Depth = 0) And AtPunct(',') Then
      Inc(N);
    ParserAdvance;
  End;
  SymTab[S].SwitchCount := N;
End;

{ Specification d'un parametre : integer a, b ;  Boolean array t ;
  Les types non listes (label, string) ne sont pas supportes. }
Procedure ParseParamSpec(P : Integer);
Var
  T, Elem, S : Integer;
Begin
  T := TY_UNKNOWN;
  Elem := TY_IDX_REAL;
  If AtTypeKw Then
  Begin
    T := TypeFromKeyword(CurToken.Val);
    Elem := T;
    ParserAdvance;
  End;
  If AtKw('array') Then
  Begin
    T := TY_IDX_ARRAY;
    ParserAdvance;
  End
  Else If AtKw('procedure') Then
  Begin
    T := TY_IDX_PROCEDURE;
    ParserAdvance;
  End
  Else If AtKw('switch') Then
  Begin
    T := TY_IDX_SWITCH;
    ParserAdvance;
  End;
  Repeat
    If CurToken.Kind <> TK_IDENT Then
    Begin
      ParseError('nom de parametre attendu dans la specification');
      ParserSync;
      Exit;
    End;
    S := SymFindParam(P, CurToken.Val);
    If S < 0 Then
      ErrorAt(CurToken.Line, CurToken.Col,
              'specification d''un nom qui n''est pas un parametre: ' +
              CurToken.Val)
    Else
    Begin
      SymTab[S].TypeIdx := T;
      SymTab[S].ElemType := Elem;
    End;
    ParserAdvance;
    If AtPunct(',') Then
      ParserAdvance
    Else
      Break;
  Until False;
  ExpectPunct(';');
End;

{ [type] procedure nom [(p1, p2)] ; [value p1, p2 ;] [specs] corps
  Le mot procedure est deja consomme. L entete et la table des
  symboles sont completes ; le corps reste a traduire (TODO 14). }
Procedure ParseProcDecl(RetType : Integer; HasType : Boolean);
Var
  P, K, S : Integer;
  Kind    : TSymKind;
Begin
  If CurToken.Kind <> TK_IDENT Then
  Begin
    ParseError('nom de procedure attendu');
    ParserSync;
    Exit;
  End;
  If HasType Then
    Kind := SK_FUNC
  Else
  Begin
    Kind := SK_PROC;
    RetType := TY_IDX_PROCEDURE;
  End;
  P := SymAdd(CurToken.Val, Kind, RetType, False,
              CurToken.Line, CurToken.Col);
  Inc(DeclCount);
  Inc(ProcCount);
  ParserAdvance;
  SymEnterProc(P);

  If AtPunct('(') Then
  Begin
    ParserAdvance;
    If Not AtPunct(')') Then
      Repeat
        If CurToken.Kind <> TK_IDENT Then
        Begin
          ParseError('nom de parametre attendu');
          Break;
        End;
        SymAdd(CurToken.Val, SK_PARAM_NAME, TY_UNKNOWN, False,
               CurToken.Line, CurToken.Col);
        ParserAdvance;
        If AtPunct(',') Then
          ParserAdvance
        Else
          Break;
      Until False;
    ExpectPunct(')');
  End;
  ExpectPunct(';');

  If AtKw('value') Then
  Begin
    ParserAdvance;
    Repeat
      If CurToken.Kind <> TK_IDENT Then
      Begin
        ParseError('nom de parametre attendu apres value');
        Break;
      End;
      If Not SymMarkValue(P, CurToken.Val) Then
        ErrorAt(CurToken.Line, CurToken.Col,
                'value: ce n''est pas un parametre: ' + CurToken.Val);
      ParserAdvance;
      If AtPunct(',') Then
        ParserAdvance
      Else
        Break;
    Until False;
    ExpectPunct(';');
  End;

  While AtTypeKw Or AtKw('array') Or AtKw('switch') Or
        AtKw('procedure') Do
    ParseParamSpec(P);

  { Parametre sans specification : integer par defaut }
  For K := 1 To SymTab[P].ParamCount Do
  Begin
    S := SymTab[P].ParamSym[K];
    If SymTab[S].TypeIdx = TY_UNKNOWN Then
    Begin
      WarnAt(SymTab[S].Line, SymTab[S].Col,
             'parametre sans specification: ' + SymTab[S].Name +
             ' (integer)');
      SymTab[S].TypeIdx := TY_IDX_INTEGER;
    End;
  End;
  SymLayoutParams(P);

  SkipStatement;                 { corps : TODO 14 }
  SymLeaveScope;
End;

{ Declaration commencant par own, un type, array, procedure ou
  switch. Le ';' final n'est pas consomme. }
Procedure ParseDeclaration;
Var
  IsOwn, HasType : Boolean;
  T              : Integer;
Begin
  IsOwn   := AtKw('own');
  HasType := False;
  T       := TY_UNKNOWN;
  If IsOwn Then ParserAdvance;
  If AtTypeKw Then
  Begin
    T := TypeFromKeyword(CurToken.Val);
    HasType := True;
    ParserAdvance;
  End;

  If AtKw('array') Then
  Begin
    ParserAdvance;
    If HasType Then
      ParseArrayDecl(T, IsOwn)
    Else
      ParseArrayDecl(TY_IDX_REAL, IsOwn);
  End
  Else If AtKw('procedure') Then
  Begin
    If IsOwn Then ParseError('own ne s''applique pas a une procedure');
    ParserAdvance;
    ParseProcDecl(T, HasType);
  End
  Else If AtKw('switch') Then
  Begin
    If IsOwn Or HasType Then
      ParseError('switch n''accepte ni own ni type');
    ParserAdvance;
    ParseSwitchDecl;
  End
  Else If HasType Then
  Begin
    If IsOwn Then
      ParseVarList(SK_OWN, T, True)
    Else
      ParseVarList(SK_VAR, T, False);
  End
  Else
  Begin
    ParseError('type attendu apres own');
    ParserSync;
  End;
End;

{ ---- Structure du programme ------------------------------------- }

{ Element d un bloc : declaration, bloc imbrique, instruction ou
  rien (instruction vide devant ';' ou 'end'). }
Procedure ParseItem;
Begin
  If AtEOF Or AtPunct(';') Or AtKw('end') Then
    Exit
  Else If AtKw('begin') Then
    ParseBlock
  Else If AtDeclKw Then
    ParseDeclaration
  Else
    SkipStatement;
End;

{ begin item ; item ; ... end   (portee propre) }
Procedure ParseBlock;
Begin
  Inc(BlockCount);
  ParserAdvance;                      { begin }
  SymEnterScope;
  Repeat
    ParseItem;
    If AtPunct(';') Then
      ParserAdvance
    Else If AtKw('end') Or AtEOF Then
      Break
    Else
    Begin
      ParseError(''';'' ou ''end'' attendu');
      ParserSync;
      If AtPunct(';') Then ParserAdvance;
    End;
  Until False;
  If AtKw('end') Then
    ParserAdvance
  Else
    ParseError('''end'' attendu (begin non ferme)');
  SymLeaveScope;
End;

{ Programme : suite d elements au niveau supreme. Des blocs begin...end
  peuvent se suivre sans ';' (test_thunks.a58) ; un programme peut
  aussi n etre qu une suite d instructions sans begin (test_types). }
Procedure ParseProgram;
Var
  WasBlock : Boolean;
Begin
  ParserAdvance;
  While Not AtEOF Do
  Begin
    WasBlock := AtKw('begin');
    If AtKw('end') Then
    Begin
      ParseError('''end'' sans ''begin'' correspondant');
      ParserAdvance;
      Continue;
    End;
    ParseItem;
    If AtPunct(';') Then
      ParserAdvance
    Else If Not (AtEOF Or WasBlock) Then
    Begin
      ParseError(''';'' attendu');
      ParserSync;
      If AtPunct(';') Then ParserAdvance;
    End;
  End;
End;

Procedure PhaseParse;
Begin
  DeclCount  := 0;
  BlockCount := 0;
  ProcCount  := 0;
  LexQuiet   := True;            { erreurs lexicales deja signalees }
  LexInit;
  SymEnterScope;                 { portee globale (identifiant 1) }
  ParseProgram;
  SymLeaveScope;
  LexClose;
  If Opts.Verbose Then
    WriteLn('  ', DeclCount, ' declaration(s), ', ProcCount,
            ' procedure(s), ', BlockCount, ' bloc(s)');
End;

{ ============================================================
  SECTION 9 - CODE INTERNE ET LISTING ASM OPTIONNEL (TODO 18)
  ============================================================ }
Procedure PhaseCodegen;
Begin
  { A faire : TODO 18 }
End;

{ ============================================================
  SECTION 10 - ENCODEUR BINAIRE x86-32 (TODO 19)
  ============================================================ }
Procedure PhaseEncode;
Begin
  { A faire : TODO 19 }
End;

{ ============================================================
  SECTION 11 - ECRIVAINS PE (.EXE) ET COFF (.OBJ) (TODO 20, 21)
  ============================================================ }
Procedure PhaseWrite;
Begin
  { A faire : TODO 20 et 21 }
End;

{ ============================================================
  SECTION 12 - RUNTIME ALGOL 58 POUR WIN32 (TODO 22)
  ============================================================ }

{ ============================================================
  SECTION 13 - ERREURS ET RAPPORT FINAL (TODO 23, 24)
  ============================================================ }
Procedure PhaseReport;
Begin
  { A faire : TODO 23 et 24 }
End;

{ ============================================================
  SECTION 14 - PIPELINE PRINCIPAL (TODO 01, 24)
  ============================================================ }
Procedure RunPhase(P : TPhase);
Begin
  If Opts.Verbose Then
    WriteLn('AL58CW32: ', PhaseName(P));
  Case P Of
    PH_LEX     : PhaseLex;
    PH_PARSE   : PhaseParse;
    PH_CODEGEN : PhaseCodegen;
    PH_ENCODE  : PhaseEncode;
    PH_WRITE   : PhaseWrite;
    PH_REPORT  : PhaseReport;
  End;
End;

Procedure Run;
Var
  P : TPhase;
Begin
  ErrorCount := 0;
  WarnCount  := 0;
  TypeInit;
  SymInit;
  LexQuiet := False;
  If Opts.DebugMode Then TypeDump;
  If Opts.Verbose Then
  Begin
    ShowBanner;
    WriteLn('  source : ', Opts.SrcFile);
    If Opts.EmitExe Then
      WriteLn('  .EXE   : ', Opts.OutFile);
    If Opts.EmitObj Then
      WriteLn('  .OBJ   : ', Opts.OutFile);
    If Opts.EmitAsm Then
      WriteLn('  .ASM   : ', Opts.AsmFile);
  End;
  For P := PH_LEX To PH_REPORT Do
    If (ErrorCount = 0) Or (P = PH_REPORT) Then
      RunPhase(P);
  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
BEGIN
  ParseArgs;
  Run;
END.
