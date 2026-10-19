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

  ETAT : feuille de route seulement, aucun code ecrit pour le moment.

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - ARCHITECTURE ET PIPELINE DU COMPILATEUR [A FAIRE]
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

  TODO 02 - OPTIONS DE LIGNE DE COMMANDE ET FICHIERS DE SORTIE [A FAIRE]
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

  TODO 03 - CONSTANTES, LIMITES ET CONVENTIONS DE NOMMAGE [A FAIRE]
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
