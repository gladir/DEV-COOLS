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

  ETAT : TODO 01 (squelette et pipeline), TODO 02 (options) et TODO 03
         (constantes, limites, nommage) implementes, les autres TODOs
         sont a faire.

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

  TODO 04 - LEXEUR ALGOL 58 [A FAIRE]
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

  TODO 05 - TYPES DE DONNEES ET CONVERSIONS (32 BITS) [A FAIRE]
            integer : 32 bits signe (DWORD), plus le 16 bits de AL58C86
            real : decision a trancher et documenter ; recommande :
              flottant 64 bits via x87 (FLD/FSTP QWORD), car la cible
              386 permet un vrai support (3.14 de hello.a58, test_literals)
            Boolean : 0 ou 1 (DWORD) ; true et false
            string : pointeur vers donnees .data (litteraux seulement)
            label, switch, procedure : types d'entites du programme
            Conversions implicites integer <-> real selon le contexte
            Un entier utilise comme condition (if x then ...) est vrai
              s'il est different de zero (test_primexpr.a58)
            Table des types et TypeSizeof (integer=4, real=8, Boolean=4)

  TODO 06 - TABLE DES SYMBOLES ET PORTEES [A FAIRE]
            TSymKind : SK_VAR, SK_ARRAY, SK_PROC, SK_FUNC, SK_LABEL,
              SK_SWITCH, SK_PARAM_VALUE, SK_PARAM_NAME, SK_OWN
            SymAdd, SymFind, SymFindInScope, SymEnterScope, SymLeaveScope
            Une portee par bloc begin...end, par procedure et par for
            Masquage lexical : t declare dans deux blocs freres
              (blocks.a58 : t=100 puis t=200)
            Variable non declaree (x := 42 dans test_errors.a58) :
              avertissement, declaration implicite integer, compilation
              poursuivie
            Calcul des offsets locaux [EBP-n] et des parametres [EBP+n]
            Niveau d'imbrication statique pour les procedures imbriquees

  TODO 07 - STRUCTURE D'UN PROGRAMME ET DECLARATIONS MELANGEES [A FAIRE]
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
Procedure PhaseLex;
Begin
  { A faire : TODO 04 }
End;

{ ============================================================
  SECTION 7 - TYPES ALGOL ET TABLE DES SYMBOLES (TODO 05, 06)
  ============================================================ }

{ ============================================================
  SECTION 8 - PARSEUR ET GENERATEUR DE CODE (TODO 07 a 17)
  ============================================================ }
Procedure PhaseParse;
Begin
  { A faire : TODO 07 a 17 }
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
