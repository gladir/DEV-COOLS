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

  ETAT : TODO 01 a 13 implementes (squelette, options, constantes,
         lexeur, types, symboles, structure du programme, expressions,
         booleens, affectations, tableaux, if et for, go to et switch) ;
         TODO 14 a 25 a faire.

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

  TODO 08 - EXPRESSIONS ARITHMETIQUES ET PRECEDENCE [IMPLEMENTE]
            Parseur a precedence (Pratt) a 9 niveaux, du plus fort :
              not et unaire +/- ; ^ et ** (droite) ; * / div mod ;
              + - ; relationnels ; and ; or ; imp ; eqv
            Entiers : ADD, SUB, IMUL, CDQ + IDIV, mod via EDX
            "/" : division entiere entre entiers (42 / 6), division
              reelle si un operande est real
            Puissance : appel de _A58RT_POW (entiers) ou x87 (reels)
            Pliage de constantes a la compilation
            Debordement et division par zero : erreur de compilation
              sur constantes (implemente) ; message runtime pour les
              valeurs variables (TODO 22)
            Expressions couvertes : test_binexpr, test_operators, math
            Realise : arbre d'expressions (ExprTab, ExprDump en mode -d),
              ParseExprPrec / ParseUnary / ParsePrimary, typage et
              repliement des constantes entieres (32 bits, debordement
              detecte) et reelles ; unaire plus prioritaire que ^ (donc
              -2 ^ 2 = 4, selon DOC\ALGOL58_SPEC_LANG.txt) ; exposant
              entier negatif : resultat entier tronque (avertissement)
            Reste pour la generation de code : TODO 18 (parcours de
              l'arbre : ADD, SUB, IMUL, CDQ/IDIV, appel de POW, x87)

  TODO 09 - RELATIONNELS, BOOLEENS ET EXPRESSIONS CONDITIONNELLES [IMPLEMENTE]
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
            Realise : relationnels et operateurs logiques types Boolean
              (entier accepte comme condition), repliement des
              constantes (relationnels, and, or, not, imp, eqv) et du
              court-circuit quand le cote gauche est constant ;
              noeud EX_COND (if c then e1 else e2), repli si la
              condition est constante ; ParseCondition (pour if, while,
              switch) ; comparaison chainee refusee (a < b < c)
            Reste pour la generation de code (TODO 18) : TEST / Jcc,
              SETcc, court-circuit de and / or sur valeurs variables

  TODO 10 - VARIABLES, AFFECTATIONS ET VARIABLES OWN [IMPLEMENTE]
            Variables globales : section .data, label _A58V_nom
            Variables locales de bloc/procedure : [EBP-n]
            Variables own : section .data, persistantes entre appels,
              initialisees a zero ; accessibles seulement dans leur bloc
              (blocks.a58, test_vars.a58, test_primexpr.a58)
            Affectation := avec conversion de type selon la cible
            Affectation multiple a := b := expr (associative a droite)
            Valeur negative et litteral signe ("b := -7")
            Initialisation des variables locales non specifiee en Algol
              58 : choix retenu, zero (les variables statiques sont a
              zero dans .data ; les locales de procedure seront mises a
              zero au prologue par le generateur, TODO 18)
            Realise : cible = variable, own, parametre (valeur ou nom),
              ou nom de la fonction dont le corps est en cours (valeur de
              retour) ; noeud EX_ASSIGN avec conversion (ExprCoerce) :
              constantes converties a la compilation, real -> integer
              arrondi au plus proche (demi vers le haut, avec
              avertissement), real -> Boolean interdit ; affectations
              multiples a droite ; variable non declaree : avertissement
              et declaration implicite ; appels, indices et fonctions
              intrinseques (mod(a, b), max...) : noeuds opaques types
              integer en attendant les TODO 11, 14 et 17

  TODO 11 - TABLEAUX [IMPLEMENTE]
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
            Realise : declaration (bornes constantes ou expressions entieres
              evaluees a l'execution, octets calcules, donnees statiques
              au niveau 0 ou dans le cadre d'une procedure), noeud
              EX_INDEX (indices convertis en integer, nombre d'indices
              verifie, constantes controlees contre les bornes connues,
              Flag = controle _A58RT_CHKIDX necessaire), element de
              tableau comme cible d'affectation, chaine a := V[i] := 7
            Reste pour la generation de code : calcul d'adresse et
              descripteur (TODO 18), allocation sur le tas des tableaux
              dynamiques (TODO 22), passage en parametre (TODO 14, 15)

  TODO 12 - INSTRUCTIONS CONDITIONNELLES ET BOUCLES FOR [IMPLEMENTE]
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
            Realise : ParseStatement (bloc, if, for, affectation,
              expression, instruction vide), ParseIf (else lie au if le
              plus proche, then et else = instructions quelconques),
              ParseFor avec liste de clauses (valeur, step-until, while),
              variable de boucle simple numerique, init converti vers
              son type, avertissements (pas nul, boucle jamais executee),
              imbrication limitee a MAX_LOOP_NEST ; le corps des
              procedures est maintenant analyse comme une instruction
            Reste pour la generation de code (TODO 18) : sauts
              conditionnels, mise en place des clauses (init, pas, test
              de fin reevalues a chaque tour, corps partage)

  TODO 13 - GO TO, ETIQUETTES ET SWITCH [IMPLEMENTE]
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
            Realise : ParseDesignator (etiquette, nombre, switch[i],
              designateur entre parentheses ou conditionnel), ParseGoto
              (go to et goto), definition d'etiquette symbolique ou
              numerique devant une instruction (y compris vide ou bloc),
              renvois avant : une etiquette encore inconnue a la sortie
              d'un bloc est reportee dans la portee englobante (meme
              procedure), sinon erreur ; go to vers une autre procedure
              refuse ; switch dont chaque designateur est analyse
              (indice constant hors bornes : avertissement)
            Saut hors d'un bloc : aucun reglage de pile n'est requis, les
              blocs d'une procedure partagent son cadre (ESP/EBP fixes)
            Reste pour la generation de code (TODO 18) : JMP, table de
              switch dans .data, JMP indirect, petits blocs pour les
              designateurs conditionnels

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

{$IFDEF FPC}
Uses Math;
{$ENDIF}

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

{ Vrai si un reel est infini ou invalide (debordement) }
Function RealBad(D : Double) : Boolean;
Begin
  {$IFDEF FPC}
  RealBad := IsNaN(D) Or IsInfinite(D);
  {$ELSE}
  RealBad := False;
  {$ENDIF}
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
      If RealBad(T.RealVal) Then
      Begin
        LexError(T.Line, T.Col, 'reel hors limites: ' + T.Val);
        T.RealVal := 0;
      End;
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
    ArrBytes   : LongInt;     { tableau : octets de donnees (bornes cst) }
    ArrDataOfs : LongInt;     { tableau local : decalage des donnees  }
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
  I, S, Dest : Integer;
  CanHoist   : Boolean;
Begin
  If ScopeTop = 0 Then
    FatalError('erreur interne: fermeture sans portee ouverte');
  S := ScopeTop - 1;
  If Opts.DebugMode Then SymDumpScope(S);
  { Un renvoi avant vers une etiquette pas encore definie dans un
    bloc interne passe dans la portee englobante (meme procedure) ;
    sinon l'etiquette doit etre definie ici. }
  CanHoist := (Not ScopeTab[S].IsProc) And (ScopeTop >= 2);
  Dest := ScopeTab[S].FirstSym;
  For I := ScopeTab[S].FirstSym To SymCount - 1 Do
  Begin
    If SymTab[I].Kind = SK_LABEL Then
    Begin
      If Not SymTab[I].IsDefined Then
      Begin
        If CanHoist Then
        Begin
          SymTab[Dest] := SymTab[I];
          SymTab[Dest].ScopeId := ScopeTab[S - 1].Id;
          Inc(Dest);
        End
        Else
          ErrorAt(SymTab[I].Line, SymTab[I].Col,
                  'etiquette non definie: ' + SymTab[I].Name +
                  ' (ou definie dans un bloc interne)');
      End
      Else If Not SymTab[I].IsUsed Then
        WarnAt(SymTab[I].Line, SymTab[I].Col,
               'etiquette non utilisee: ' + SymTab[I].Name);
    End;
  End;
  SymCount := Dest;
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
  AssignCount: LongInt;      { affectations analysees               }
  IfCount    : LongInt;      { instructions if                      }
  GotoCount  : LongInt;      { instructions go to                   }
  LabelCount : LongInt;      { etiquettes definies                  }
  ForCount   : LongInt;      { instructions for                     }
  LoopDepth  : Integer;      { imbrication courante des for         }
  ParkValid  : Boolean;      { un token est range (ParserUnget)     }
  ParkTok    : TToken;

{ ---- Primitives du parseur -------------------------------------- }

Procedure ParserAdvance;
Begin
  If ParkValid Then
  Begin
    CurToken  := ParkTok;
    ParkValid := False;
  End
  Else
    LexNextToken(CurToken);
End;

{ Rend Saved (le token precedent) courant ; le token courant est
  range et reviendra au prochain ParserAdvance. Permet de regarder un
  token apres un identificateur avant de decider du type d'instruction. }
Procedure ParserUnget(Const Saved : TToken);
Begin
  ParkTok   := CurToken;
  ParkValid := True;
  CurToken  := Saved;
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

{ Fin d'une instruction simple : ';' end, else ou fin de fichier }
Function AtStmtEnd : Boolean;
Begin
  AtStmtEnd := AtEOF Or AtPunct(';') Or AtKw('end') Or AtKw('else');
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

Procedure ParseItem; Forward;
Procedure ParseStatement; Forward;
Procedure ParseLabelDef(Const Name : TString; Line, Col : Integer);
  Forward;

{ ---- Expressions (TODO 08) --------------------------------------
  Les expressions sont analysees en arbre (pool ExprTab) : le
  generateur de code (TODO 18) parcourra cet arbre. Chaque noeud
  porte son type ; les operations sur constantes sont repliees a la
  compilation. Priorites, du plus fort au plus faible :
    9 not, unaire +/- (droite)    8 ^ ** (droite)
    7 * / div mod                 6 + -
    5 = # < <= > >=               4 and      3 or    2 imp    1 eqv
  Les regles de type et le repliement des relationnels et des
  operateurs logiques sont completes au TODO 09. ----------------- }
Const
  MAX_EXPR     = {$IFDEF FPC}16384{$ELSE}512{$ENDIF};
  MAX_EXPR_STR = {$IFDEF FPC}256{$ELSE}16{$ENDIF};
  PREC_UNARY   = 9;
  MAX_ARRAY_ELEMS = 134217728;    { 2^27 elements }
  MAX_ARRAY_BYTES = 1073741824;   { 1 Go }
  PREC_POWER   = 8;

Type
  {$IFDEF FPC}
  TWide = Int64;
  {$ELSE}
  TWide = Comp;
  {$ENDIF}

  TExprKind = (
    EX_INT,         { constante entiere                     }
    EX_REAL,        { constante reelle                      }
    EX_BOOL,        { true / false (IntVal = 1 ou 0)        }
    EX_STR,         { chaine litterale (StrIdx)             }
    EX_VAR,         { variable scalaire (Sym)               }
    EX_UNARY,       { Op appliquee a L                      }
    EX_BINARY,      { L Op R                                }
    EX_COND,        { if L then R else E                    }
    EX_ASSIGN,      { L := R (L : variable) ; valeur = celle de L }
    EX_OPAQUE,      { appel non encore traduit (StrIdx = nom)  }
    EX_INDEX,       { Sym[L...] : element de tableau (IntVal = nb d indices) }
    EX_LIST,        { liste d indices : L = expression, R = suivant }
    EX_LABEL,       { designateur : etiquette (Sym)               }
    EX_SWITCHREF    { designateur : Sym[L] (element de switch)    }
  );

  TExprNode = Record
    Kind    : TExprKind;
    Op      : String[4];
    Typ     : Integer;      { TY_IDX_* ou TY_UNKNOWN            }
    IntVal  : LongInt;
    RealVal : Double;
    StrIdx  : Integer;
    Conv    : TConv;        { EX_ASSIGN : conversion de R vers L }
    Flag    : Boolean;      { EX_INDEX : controle de bornes a l execution }
    Sym     : Integer;
    L, R, E : Integer;      { fils, -1 si absent (E : sinon)    }
    Line    : Integer;
    Col     : Integer;
  End;

Var
  ExprTab      : Array[0..MAX_EXPR - 1] Of TExprNode;
  ExprCount    : Integer;
  ExprStrTab   : Array[0..MAX_EXPR_STR - 1] Of TString;
  ExprStrCount : Integer;
  FoldCount    : LongInt;     { operations repliees (statistiques) }

{ Vide le pool : appele avant chaque expression }
Procedure ExprReset;
Begin
  ExprCount    := 0;
  ExprStrCount := 0;
End;

Function ExprNew(K : TExprKind; Typ : Integer; Line, Col : Integer)
         : Integer;
Begin
  If ExprCount >= MAX_EXPR Then
    FatalError('expression trop complexe (max ' + ItoS(MAX_EXPR) +
               ' noeuds)');
  FillChar(ExprTab[ExprCount], SizeOf(TExprNode), 0);
  ExprTab[ExprCount].Kind := K;
  ExprTab[ExprCount].Typ  := Typ;
  ExprTab[ExprCount].L    := -1;
  ExprTab[ExprCount].R    := -1;
  ExprTab[ExprCount].E    := -1;
  ExprTab[ExprCount].Sym  := -1;
  ExprTab[ExprCount].Line := Line;
  ExprTab[ExprCount].Col  := Col;
  ExprNew := ExprCount;
  Inc(ExprCount);
End;

Function ExprMakeInt(V : LongInt; Line, Col : Integer) : Integer;
Var
  N : Integer;
Begin
  N := ExprNew(EX_INT, TY_IDX_INTEGER, Line, Col);
  ExprTab[N].IntVal := V;
  ExprMakeInt := N;
End;

Function ExprMakeReal(V : Double; Line, Col : Integer) : Integer;
Var
  N : Integer;
Begin
  N := ExprNew(EX_REAL, TY_IDX_REAL, Line, Col);
  ExprTab[N].RealVal := V;
  ExprMakeReal := N;
End;

Function ExprMakeBool(V : Boolean; Line, Col : Integer) : Integer;
Var
  N : Integer;
Begin
  N := ExprNew(EX_BOOL, TY_IDX_BOOLEAN, Line, Col);
  If V Then ExprTab[N].IntVal := 1;
  ExprMakeBool := N;
End;

{ Range S dans la table des chaines de l'expression ; retourne l'indice }
Function ExprAddStr(Const S : TString) : Integer;
Begin
  If ExprStrCount >= MAX_EXPR_STR Then
    FatalError('trop de chaines dans une expression');
  ExprStrTab[ExprStrCount] := S;
  ExprAddStr := ExprStrCount;
  Inc(ExprStrCount);
End;

Function ExprMakeStr(Const S : TString; Line, Col : Integer) : Integer;
Var
  N : Integer;
Begin
  N := ExprNew(EX_STR, TY_IDX_STRING, Line, Col);
  ExprTab[N].StrIdx := ExprAddStr(S);
  ExprMakeStr := N;
End;

Function ExprMakeVar(Sym : Integer; Line, Col : Integer) : Integer;
Var
  N : Integer;
Begin
  N := ExprNew(EX_VAR, SymTab[Sym].TypeIdx, Line, Col);
  ExprTab[N].Sym := Sym;
  ExprMakeVar := N;
End;

Function ExprIsConst(N : Integer) : Boolean;
Begin
  ExprIsConst := (N >= 0) And
                 (ExprTab[N].Kind In [EX_INT, EX_REAL]);
End;

Function ExprConstReal(N : Integer) : Double;
Begin
  If ExprTab[N].Kind = EX_INT Then
    ExprConstReal := ExprTab[N].IntVal
  Else
    ExprConstReal := ExprTab[N].RealVal;
End;

{ Constante booleenne ou entiere utilisable comme condition }
Function ExprIsCondConst(N : Integer) : Boolean;
Begin
  ExprIsCondConst := (N >= 0) And
                     (ExprTab[N].Kind In [EX_INT, EX_BOOL]);
End;

Function ExprTruth(N : Integer) : Boolean;
Begin
  ExprTruth := (ExprTab[N].IntVal <> 0);
End;

{ Constante numerique ou booleenne (comparable) }
Function ExprIsNumConst(N : Integer) : Boolean;
Begin
  ExprIsNumConst := (N >= 0) And
                    (ExprTab[N].Kind In [EX_INT, EX_REAL, EX_BOOL]);
End;

Function ExprNumReal(N : Integer) : Double;
Begin
  If ExprTab[N].Kind = EX_REAL Then
    ExprNumReal := ExprTab[N].RealVal
  Else
    ExprNumReal := ExprTab[N].IntVal;
End;

{ Transforme le noeud N en constante booleenne (repliement) }
Procedure ExprSetBool(N : Integer; V : Boolean);
Begin
  ExprTab[N].Kind := EX_BOOL;
  ExprTab[N].Typ  := TY_IDX_BOOLEAN;
  ExprTab[N].L    := -1;
  ExprTab[N].R    := -1;
  If V Then ExprTab[N].IntVal := 1 Else ExprTab[N].IntVal := 0;
  Inc(FoldCount);
End;

{ ---- Classification des operateurs ------------------------------ }

Function OpText(Const T : TToken) : TString;
Begin
  If T.Kind In [TK_OP, TK_KEYWORD] Then
    OpText := T.Val
  Else
    OpText := '';
End;

Function OpIsRel(Const Op : TString) : Boolean;
Begin
  OpIsRel := (Op = '=') Or (Op = '#') Or (Op = '<') Or (Op = '<=') Or
             (Op = '>') Or (Op = '>=');
End;

Function OpIsLogic(Const Op : TString) : Boolean;
Begin
  OpIsLogic := (Op = 'and') Or (Op = 'or') Or (Op = 'imp') Or
               (Op = 'eqv');
End;

{ Priorite d'un operateur binaire (0 si le token n'en est pas un) }
Function BinOpPrec(Const T : TToken) : Integer;
Var
  Op : TString;
Begin
  BinOpPrec := 0;
  Op := OpText(T);
  If T.Kind = TK_OP Then
  Begin
    If (Op = '+') Or (Op = '-') Then
      BinOpPrec := 6
    Else If (Op = '*') Or (Op = '/') Then
      BinOpPrec := 7
    Else If Op = '^' Then
      BinOpPrec := PREC_POWER
    Else If OpIsRel(Op) Then
      BinOpPrec := 5;
  End
  Else If T.Kind = TK_KEYWORD Then
  Begin
    If (Op = 'div') Or (Op = 'mod') Then
      BinOpPrec := 7
    Else If Op = 'and' Then
      BinOpPrec := 4
    Else If Op = 'or' Then
      BinOpPrec := 3
    Else If Op = 'imp' Then
      BinOpPrec := 2
    Else If Op = 'eqv' Then
      BinOpPrec := 1;
  End;
End;

{ Seul ^ est associatif a droite }
Function BinOpIsRight(Const T : TToken) : Boolean;
Begin
  BinOpIsRight := (T.Kind = TK_OP) And (T.Val = '^');
End;

{ ---- Repliement de constantes ----------------------------------- }

Function FoldRange(W : TWide) : Boolean;
Begin
  FoldRange := (W <= MaxLongInt) And (W >= -TWide(MaxLongInt) - 1);
End;

{ Op entier sur constantes ; Err <> '' en cas d'erreur }
Procedure FoldIntBin(Const Op : TString; A, B : LongInt;
                     Var R : LongInt; Var Err : TString);
Var
  W, Base : TWide;
  E       : LongInt;
Begin
  Err := '';
  R := 0;
  W := 0;
  If Op = '+' Then
    W := TWide(A) + TWide(B)
  Else If Op = '-' Then
    W := TWide(A) - TWide(B)
  Else If Op = '*' Then
    W := TWide(A) * TWide(B)
  Else If (Op = '/') Or (Op = 'div') Or (Op = 'mod') Then
  Begin
    If B = 0 Then
    Begin
      Err := 'division par zero';
      Exit;
    End;
    If (Op = 'mod') Then
      W := TWide(A) Mod TWide(B)
    Else
      W := TWide(A) Div TWide(B);
  End
  Else If Op = '^' Then
  Begin
    If B < 0 Then
    Begin
      { exposant negatif : resultat entier tronque }
      If A = 0 Then
      Begin
        Err := 'division par zero (0 ^ exposant negatif)';
        Exit;
      End;
      If A = 1 Then
        W := 1
      Else If A = -1 Then
      Begin
        If Odd(B) Then W := -1 Else W := 1;
      End
      Else
        W := 0;
    End
    Else
    Begin
      W := 1;
      Base := A;
      E := B;
      While E > 0 Do
      Begin
        If Odd(E) Then
        Begin
          W := W * Base;
          If Not FoldRange(W) Then Break;
        End;
        E := E Div 2;
        If E > 0 Then
        Begin
          Base := Base * Base;
          If (Base > MaxLongInt) Or (Base < -TWide(MaxLongInt) - 1) Then
          Begin
            W := TWide(MaxLongInt) + 1;     { debordement certain }
            Break;
          End;
        End;
      End;
    End;
  End;
  If Not FoldRange(W) Then
  Begin
    Err := 'debordement entier 32 bits dans une constante';
    Exit;
  End;
  R := W;
End;

{ Operation reelle sur constantes ; Err <> '' en cas d'erreur }
Procedure FoldRealBin(Const Op : TString; A, B : Double;
                      Var R : Double; Var Err : TString);
Var
  I, N : LongInt;
Begin
  Err := '';
  R := 0;
  If Op = '+' Then
    R := A + B
  Else If Op = '-' Then
    R := A - B
  Else If Op = '*' Then
    R := A * B
  Else If Op = '/' Then
  Begin
    If B = 0 Then
    Begin
      Err := 'division par zero';
      Exit;
    End;
    R := A / B;
  End
  Else If Op = '^' Then
  Begin
    If (Frac(B) = 0) And (Abs(B) <= 1024) Then
    Begin
      N := Trunc(Abs(B));
      R := 1;
      For I := 1 To N Do
      Begin
        R := R * A;
        If RealBad(R) Then Break;
      End;
      If (B < 0) And (Not RealBad(R)) Then
      Begin
        If R = 0 Then
          Err := 'division par zero (0 ^ exposant negatif)'
        Else
          R := 1 / R;
      End;
    End
    Else If A > 0 Then
      R := Exp(B * Ln(A))
    Else If (A = 0) And (B > 0) Then
      R := 0
    Else
      Err := 'puissance reelle invalide (base <= 0, exposant non entier)';
  End;
  If (Err = '') And RealBad(R) Then
    Err := 'debordement reel dans une constante';
End;

{ ---- Construction des noeuds ------------------------------------ }

Procedure OpTypeError(Const Op : TString; A, B : Integer; Line, Col : Integer);
Begin
  If B = TY_UNKNOWN Then
    ErrorAt(Line, Col, 'operande incompatible avec ''' + Op + ''': ' +
            TypeName(A))
  Else
    ErrorAt(Line, Col, 'operandes incompatibles avec ''' + Op + ''': ' +
            TypeName(A) + ', ' + TypeName(B));
End;

Function ExprMakeUnary(Const Op : TString; A : Integer;
                       Line, Col : Integer) : Integer;
Var
  N, T : Integer;
Begin
  ExprMakeUnary := -1;
  If A < 0 Then Exit;
  If Op = 'not' Then
  Begin
    If Not TypeIsCondition(ExprTab[A].Typ) Then
    Begin
      OpTypeError(Op, ExprTab[A].Typ, TY_UNKNOWN, Line, Col);
      Exit;
    End;
    T := TY_IDX_BOOLEAN;
    If ExprIsCondConst(A) Then
    Begin
      ExprSetBool(A, Not ExprTruth(A));
      ExprMakeUnary := A;
      Exit;
    End;
  End
  Else
  Begin
    T := TypeArith(ExprTab[A].Typ, ExprTab[A].Typ);
    If T = TY_UNKNOWN Then
    Begin
      OpTypeError(Op, ExprTab[A].Typ, TY_UNKNOWN, Line, Col);
      Exit;
    End;
    { +x : identite sur un nombre ; -x sur constante : replie }
    If ExprIsConst(A) Then
    Begin
      If Op = '-' Then
      Begin
        If ExprTab[A].Kind = EX_INT Then
          ExprTab[A].IntVal := -ExprTab[A].IntVal
        Else
          ExprTab[A].RealVal := -ExprTab[A].RealVal;
        Inc(FoldCount);
      End;
      ExprMakeUnary := A;
      Exit;
    End;
    If (Op = '+') And (ExprTab[A].Typ = T) Then
    Begin
      ExprMakeUnary := A;
      Exit;
    End;
  End;
  N := ExprNew(EX_UNARY, T, Line, Col);
  ExprTab[N].Op := Op;
  ExprTab[N].L  := A;
  ExprMakeUnary := N;
End;

Function ExprMakeBinary(Const Op : TString; L, R : Integer;
                        Line, Col : Integer) : Integer;
Var
  N, T, TL, TR : Integer;
  IV           : LongInt;
  RV           : Double;
  Err          : TString;
  IsDiv        : Boolean;
  D1, D2       : Double;
  Cmp          : Integer;
  Res          : Boolean;
Begin
  ExprMakeBinary := -1;
  If (L < 0) Or (R < 0) Then Exit;
  TL := ExprTab[L].Typ;
  TR := ExprTab[R].Typ;
  IsDiv := (Op = '/') Or (Op = 'div') Or (Op = 'mod');

  { type du resultat }
  If OpIsRel(Op) Then
  Begin
    If (TypeArith(TL, TR) = TY_UNKNOWN) Then
    Begin
      OpTypeError(Op, TL, TR, Line, Col);
      Exit;
    End;
    T := TY_IDX_BOOLEAN;
  End
  Else If OpIsLogic(Op) Then
  Begin
    If Not (TypeIsCondition(TL) And TypeIsCondition(TR)) Then
    Begin
      OpTypeError(Op, TL, TR, Line, Col);
      Exit;
    End;
    T := TY_IDX_BOOLEAN;
  End
  Else
  Begin
    T := TypeArith(TL, TR);
    If T = TY_UNKNOWN Then
    Begin
      OpTypeError(Op, TL, TR, Line, Col);
      Exit;
    End;
    { div et mod n'acceptent que des entiers }
    If ((Op = 'div') Or (Op = 'mod')) And (T = TY_IDX_REAL) Then
    Begin
      ErrorAt(Line, Col, '''' + Op + ''' demande des operandes entiers');
      Exit;
    End;
  End;

  { division par une constante nulle }
  If IsDiv And ExprIsConst(R) And (ExprConstReal(R) = 0) Then
  Begin
    ErrorAt(Line, Col, 'division par zero');
    Exit;
  End;
  If (Op = '^') And (T = TY_IDX_INTEGER) And ExprIsConst(R) And
     (ExprTab[R].IntVal < 0) Then
    WarnAt(Line, Col, 'exposant negatif: resultat entier tronque');

  { repliement des relationnels sur deux constantes }
  If OpIsRel(Op) And ExprIsNumConst(L) And ExprIsNumConst(R) Then
  Begin
    If (ExprTab[L].Kind = EX_REAL) Or (ExprTab[R].Kind = EX_REAL) Then
    Begin
      D1 := ExprNumReal(L);
      D2 := ExprNumReal(R);
      Cmp := 0;
      If D1 < D2 Then Cmp := -1 Else If D1 > D2 Then Cmp := 1;
    End
    Else
    Begin
      Cmp := 0;
      If ExprTab[L].IntVal < ExprTab[R].IntVal Then
        Cmp := -1
      Else If ExprTab[L].IntVal > ExprTab[R].IntVal Then
        Cmp := 1;
    End;
    If Op = '=' Then
      Res := (Cmp = 0)
    Else If Op = '#' Then
      Res := (Cmp <> 0)
    Else If Op = '<' Then
      Res := (Cmp < 0)
    Else If Op = '<=' Then
      Res := (Cmp <= 0)
    Else If Op = '>' Then
      Res := (Cmp > 0)
    Else
      Res := (Cmp >= 0);
    ExprSetBool(L, Res);
    ExprMakeBinary := L;
    Exit;
  End;

  { repliement des operateurs logiques (constantes, court-circuit) }
  If OpIsLogic(Op) And ExprIsCondConst(L) Then
  Begin
    If ExprIsCondConst(R) Then
    Begin
      If Op = 'and' Then
        Res := ExprTruth(L) And ExprTruth(R)
      Else If Op = 'or' Then
        Res := ExprTruth(L) Or ExprTruth(R)
      Else If Op = 'imp' Then
        Res := (Not ExprTruth(L)) Or ExprTruth(R)
      Else
        Res := (ExprTruth(L) = ExprTruth(R));
      ExprSetBool(L, Res);
      ExprMakeBinary := L;
      Exit;
    End;
    { gauche constante : la droite n'est pas toujours evaluee }
    If ((Op = 'and') And (Not ExprTruth(L))) Or
       ((Op = 'or') And ExprTruth(L)) Or
       ((Op = 'imp') And (Not ExprTruth(L))) Then
    Begin
      ExprSetBool(L, Op <> 'and');
      ExprMakeBinary := L;
      Exit;
    End;
    If ((Op = 'and') Or (Op = 'or') Or (Op = 'imp')) And
       (ExprTab[R].Typ = TY_IDX_BOOLEAN) Then
    Begin
      Inc(FoldCount);                 { true and x, false or x, true imp x }
      ExprMakeBinary := R;
      Exit;
    End;
  End;

  { repliement des operations arithmetiques sur deux constantes }
  If (Not OpIsRel(Op)) And (Not OpIsLogic(Op)) And
     ExprIsConst(L) And ExprIsConst(R) Then
  Begin
    Err := '';
    If T = TY_IDX_INTEGER Then
    Begin
      FoldIntBin(Op, ExprTab[L].IntVal, ExprTab[R].IntVal, IV, Err);
      If Err = '' Then
      Begin
        ExprTab[L].IntVal := IV;
        ExprTab[L].Line := Line;
        ExprTab[L].Col  := Col;
      End;
    End
    Else
    Begin
      FoldRealBin(Op, ExprConstReal(L), ExprConstReal(R), RV, Err);
      If Err = '' Then
      Begin
        ExprTab[L].Kind := EX_REAL;
        ExprTab[L].Typ  := TY_IDX_REAL;
        ExprTab[L].RealVal := RV;
        ExprTab[L].Line := Line;
        ExprTab[L].Col  := Col;
      End;
    End;
    If Err <> '' Then
    Begin
      ErrorAt(Line, Col, Err);
      Exit;
    End;
    Inc(FoldCount);
    ExprMakeBinary := L;
    Exit;
  End;

  N := ExprNew(EX_BINARY, T, Line, Col);
  ExprTab[N].Op := Op;
  ExprTab[N].L  := L;
  ExprTab[N].R  := R;
  ExprMakeBinary := N;
End;

Function ConvName(C : TConv) : TString;
Begin
  Case C Of
    CV_NONE        : ConvName := 'none';
    CV_INT_TO_REAL : ConvName := 'int->real';
    CV_REAL_TO_INT : ConvName := 'real->int';
    CV_INT_TO_BOOL : ConvName := 'int->bool';
    CV_ERROR       : ConvName := 'error';
  End;
End;

{ Arrondi au plus proche, demi vers le haut : entier(x + 0.5) }
Function RoundHalfUp(X : Double) : LongInt;
Var
  Y : Double;
  I : LongInt;
Begin
  Y := X + 0.5;
  I := Trunc(Y);
  If (Y < 0) And (Frac(Y) <> 0) Then Dec(I);
  RoundHalfUp := I;
End;

{ Convertit la valeur du noeud N vers le type Dest (affectation) :
  verifie la compatibilite et plie la conversion des constantes ;
  Conv indique la conversion a generer pour une valeur non constante.
  Retourne False apres avoir signale une erreur. }
Function ExprCoerce(N, Dest : Integer; Var Conv : TConv;
                    Line, Col : Integer) : Boolean;
Begin
  ExprCoerce := False;
  Conv := TypeConversion(ExprTab[N].Typ, Dest);
  If Conv = CV_ERROR Then
  Begin
    ErrorAt(Line, Col, 'affectation incompatible: ' +
            TypeName(ExprTab[N].Typ) + ' vers ' + TypeName(Dest));
    Exit;
  End;
  If Conv = CV_REAL_TO_INT Then
    WarnAt(Line, Col, 'real affecte a un integer: arrondi au plus proche');
  Case ExprTab[N].Kind Of
    EX_INT:
      If Dest = TY_IDX_REAL Then
      Begin
        ExprTab[N].RealVal := ExprTab[N].IntVal;
        ExprTab[N].Kind := EX_REAL;
        ExprTab[N].Typ  := TY_IDX_REAL;
        Conv := CV_NONE;
      End
      Else If Dest = TY_IDX_BOOLEAN Then
      Begin
        If ExprTab[N].IntVal <> 0 Then ExprTab[N].IntVal := 1;
        ExprTab[N].Kind := EX_BOOL;
        ExprTab[N].Typ  := TY_IDX_BOOLEAN;
        Conv := CV_NONE;
      End;
    EX_REAL:
      If Dest = TY_IDX_INTEGER Then
      Begin
        If Abs(ExprTab[N].RealVal) >= 2147483647.0 Then
        Begin
          ErrorAt(Line, Col, 'constante reelle hors de l''intervalle ' +
                  'integer');
          Exit;
        End;
        ExprTab[N].IntVal := RoundHalfUp(ExprTab[N].RealVal);
        ExprTab[N].Kind := EX_INT;
        ExprTab[N].Typ  := TY_IDX_INTEGER;
        Conv := CV_NONE;
      End;
    EX_BOOL:
      If Dest = TY_IDX_INTEGER Then
      Begin
        ExprTab[N].Kind := EX_INT;
        ExprTab[N].Typ  := TY_IDX_INTEGER;
      End
      Else If Dest = TY_IDX_REAL Then
      Begin
        ExprTab[N].RealVal := ExprTab[N].IntVal;
        ExprTab[N].Kind := EX_REAL;
        ExprTab[N].Typ  := TY_IDX_REAL;
        Conv := CV_NONE;
      End;
  End;
  ExprCoerce := True;
End;

{ if C then T else E : valeur de T ou de E. Les branches ont un type
  commun : Boolean si les deux le sont, chaine si les deux le sont,
  sinon le type arithmetique (real si l'une l'est). Une condition
  constante choisit directement la branche. }
Function ExprMakeCond(C, T, E : Integer; Line, Col : Integer) : Integer;
Var
  N, Res, Sel : Integer;
Begin
  ExprMakeCond := -1;
  If (C < 0) Or (T < 0) Or (E < 0) Then Exit;
  If (ExprTab[T].Typ = TY_IDX_BOOLEAN) And
     (ExprTab[E].Typ = TY_IDX_BOOLEAN) Then
    Res := TY_IDX_BOOLEAN
  Else If (ExprTab[T].Typ = TY_IDX_STRING) And
          (ExprTab[E].Typ = TY_IDX_STRING) Then
    Res := TY_IDX_STRING
  Else
  Begin
    Res := TypeArith(ExprTab[T].Typ, ExprTab[E].Typ);
    If Res = TY_UNKNOWN Then
    Begin
      ErrorAt(Line, Col, 'branches then/else de types incompatibles: ' +
              TypeName(ExprTab[T].Typ) + ', ' + TypeName(ExprTab[E].Typ));
      Exit;
    End;
  End;

  If ExprIsCondConst(C) Then
  Begin
    If ExprTruth(C) Then Sel := T Else Sel := E;
    If ExprTab[Sel].Typ = Res Then
    Begin
      Inc(FoldCount);
      ExprMakeCond := Sel;
      Exit;
    End;
    If (Res = TY_IDX_REAL) And (ExprTab[Sel].Kind In [EX_INT, EX_BOOL]) Then
    Begin
      ExprTab[Sel].RealVal := ExprTab[Sel].IntVal;
      ExprTab[Sel].Kind := EX_REAL;
      ExprTab[Sel].Typ  := TY_IDX_REAL;
      Inc(FoldCount);
      ExprMakeCond := Sel;
      Exit;
    End;
    If (Res = TY_IDX_INTEGER) And (ExprTab[Sel].Kind = EX_BOOL) Then
    Begin
      ExprTab[Sel].Kind := EX_INT;
      ExprTab[Sel].Typ  := TY_IDX_INTEGER;
      Inc(FoldCount);
      ExprMakeCond := Sel;
      Exit;
    End;
  End;

  N := ExprNew(EX_COND, Res, Line, Col);
  ExprTab[N].L := C;
  ExprTab[N].R := T;
  ExprTab[N].E := E;
  ExprMakeCond := N;
End;

{ ---- Analyse (parseur a precedence) ----------------------------- }

Function ParseExprPrec(MinPrec : Integer) : Integer; Forward;

{ Condition de if / while / expression conditionnelle : Boolean ou
  entier (vrai si different de zero). -1 si erreur. }
Function ParseCondition : Integer;
Var
  N         : Integer;
  Line, Col : Integer;
Begin
  Line := CurToken.Line;
  Col  := CurToken.Col;
  N := ParseExprPrec(1);
  If (N >= 0) And (Not TypeIsCondition(ExprTab[N].Typ)) Then
  Begin
    ErrorAt(Line, Col, 'condition booleenne attendue (type: ' +
            TypeName(ExprTab[N].Typ) + ')');
    N := -1;
  End;
  ParseCondition := N;
End;

{ if condition then expr else expr   (le mot if est le token courant) }
Function ParseCondExpr : Integer;
Var
  C, T, E   : Integer;
  Line, Col : Integer;
Begin
  Line := CurToken.Line;
  Col  := CurToken.Col;
  ParserAdvance;                          { if }
  C := ParseCondition;
  If AtKw('then') Then
    ParserAdvance
  Else
    ParseError('''then'' attendu');
  T := ParseExprPrec(1);
  If AtKw('else') Then
    ParserAdvance
  Else
  Begin
    ParseError('''else'' attendu dans une expression conditionnelle');
    ParseCondExpr := -1;
    Exit;
  End;
  E := ParseExprPrec(1);
  ParseCondExpr := ExprMakeCond(C, T, E, Line, Col);
End;

{ Tableau (declare comme tel, ou parametre de type array) ? }
Function SymIsArrayLike(S : Integer) : Boolean;
Begin
  SymIsArrayLike := (SymTab[S].Kind = SK_ARRAY) Or
    ((SymTab[S].Kind In [SK_PARAM_VALUE, SK_PARAM_NAME]) And
     (SymTab[S].TypeIdx = TY_IDX_ARRAY));
End;

{ nom[i] ou nom[i, j] : le token courant est le '[' qui suit le nom.
  Chaque indice est converti en integer ; les constantes sont
  verifiees contre les bornes connues. Flag = True quand le generateur
  doit controler les bornes a l'execution (_A58RT_CHKIDX). }
Function ParseIndexed(Const Tok : TToken; S : Integer) : Integer;
Var
  Head, Tail, Item, E, N, Dims, Node : Integer;
  Bad, NeedCheck                     : Boolean;
  Conv                               : TConv;
  Line, Col                          : Integer;
Begin
  Dims := SymTab[S].ArrDims;
  Head := -1;
  Tail := -1;
  N    := 0;
  Bad  := False;
  NeedCheck := (Dims = 0) Or SymTab[S].ArrDynamic;
  ParserAdvance;                            { [ }
  Repeat
    Line := CurToken.Line;
    Col  := CurToken.Col;
    E := ParseExprPrec(1);
    If E >= 0 Then
      If Not ExprCoerce(E, TY_IDX_INTEGER, Conv, Line, Col) Then E := -1;
    Inc(N);
    If E < 0 Then
      Bad := True
    Else
    Begin
      Item := ExprNew(EX_LIST, TY_IDX_INTEGER, Line, Col);
      ExprTab[Item].L    := E;
      ExprTab[Item].Conv := Conv;
      If Head < 0 Then Head := Item Else ExprTab[Tail].R := Item;
      Tail := Item;
      If ExprTab[E].Kind = EX_INT Then
      Begin
        If (Dims > 0) And (N <= Dims) And (Not SymTab[S].ArrDynamic) Then
        Begin
          If (ExprTab[E].IntVal < SymTab[S].ArrLo[N]) Or
             (ExprTab[E].IntVal > SymTab[S].ArrHi[N]) Then
          Begin
            ErrorAt(Line, Col, 'indice hors bornes: ' +
                    ItoS(ExprTab[E].IntVal) + ' (' + Tok.Val + '[' +
                    ItoS(SymTab[S].ArrLo[N]) + ':' +
                    ItoS(SymTab[S].ArrHi[N]) + '])');
            Bad := True;
          End;
        End;
      End
      Else
        NeedCheck := True;
    End;
    If AtPunct(',') Then
      ParserAdvance
    Else
      Break;
  Until False;
  If AtPunct(']') Then
    ParserAdvance
  Else
    ParseError(''']'' attendu');
  If (Dims > 0) And (N <> Dims) Then
  Begin
    ErrorAt(Tok.Line, Tok.Col, 'tableau ' + Tok.Val + ': ' + ItoS(N) +
            ' indice(s) au lieu de ' + ItoS(Dims));
    Bad := True;
  End;
  ParseIndexed := -1;
  If Bad Then Exit;
  Node := ExprNew(EX_INDEX, SymTab[S].ElemType, Tok.Line, Tok.Col);
  ExprTab[Node].Sym    := S;
  ExprTab[Node].L      := Head;
  ExprTab[Node].IntVal := N;
  ExprTab[Node].Flag   := NeedCheck;
  ParseIndexed := Node;
End;

{ Appel : saute le groupe ( ... ) courant et le remplace par un noeud
  opaque de type T (TODO 14, 17). }
Function ParseOpaque(Const Tok : TToken; T : Integer) : Integer;
Var
  N, Depth : Integer;
Begin
  Depth := 0;
  Repeat
    If AtPunct('(') Or AtPunct('[') Then
      Inc(Depth)
    Else If AtPunct(')') Or AtPunct(']') Then
      Dec(Depth);
    ParserAdvance;
  Until (Depth <= 0) Or AtEOF Or AtPunct(';');
  N := ExprNew(EX_OPAQUE, T, Tok.Line, Tok.Col);
  ExprTab[N].StrIdx := ExprAddStr(Tok.Val);
  ParseOpaque := N;
End;

Function ParsePrimary : Integer;
Var
  N, S, T : Integer;
  Tok     : TToken;
Begin
  ParsePrimary := -1;
  Tok := CurToken;
  Case Tok.Kind Of
    TK_INTEGER:
      Begin
        ParsePrimary := ExprMakeInt(Tok.IntVal, Tok.Line, Tok.Col);
        ParserAdvance;
      End;
    TK_REAL:
      Begin
        ParsePrimary := ExprMakeReal(Tok.RealVal, Tok.Line, Tok.Col);
        ParserAdvance;
      End;
    TK_STRING:
      Begin
        ParsePrimary := ExprMakeStr(Tok.Val, Tok.Line, Tok.Col);
        ParserAdvance;
      End;
    TK_KEYWORD:
      If (Tok.Val = 'true') Or (Tok.Val = 'false') Then
      Begin
        ParsePrimary := ExprMakeBool(Tok.Val = 'true', Tok.Line, Tok.Col);
        ParserAdvance;
      End
      Else If Tok.Val = 'if' Then
        ParsePrimary := ParseCondExpr
      Else If (Tok.Val = 'mod') Or (Tok.Val = 'div') Then
      Begin
        { mod(a, b) : forme fonction (TODO 17) }
        ParserAdvance;
        If AtPunct('(') Then
          ParsePrimary := ParseOpaque(Tok, TY_IDX_INTEGER)
        Else
          ErrorAt(Tok.Line, Tok.Col, 'expression attendue (trouve: ''' +
                  Tok.Val + ''')');
      End
      Else
        ParseError('expression attendue');
    TK_PUNCT:
      If Tok.Val = '(' Then
      Begin
        ParserAdvance;
        N := ParseExprPrec(1);
        If AtPunct(')') Then
          ParserAdvance
        Else
          ParseError(''')'' attendu');
        ParsePrimary := N;
      End
      Else
        ParseError('expression attendue');
    TK_IDENT:
      Begin
        ParserAdvance;
        If AtPunct('[') Then
        Begin
          S := SymFind(Tok.Val);
          If S < 0 Then
            ErrorAt(Tok.Line, Tok.Col, 'tableau non declare: ' + Tok.Val)
          Else If Not SymIsArrayLike(S) Then
            ErrorAt(Tok.Line, Tok.Col, 'ce n''est pas un tableau: ' +
                    Tok.Val)
          Else
            ParsePrimary := ParseIndexed(Tok, S);
          Exit;
        End;
        If AtPunct('(') Then
        Begin
          { appel : saute les arguments ; la traduction releve des
            TODO 14 (procedures) et 17 (fonctions intrinseques) }
          S := SymFind(Tok.Val);
          T := TY_IDX_INTEGER;
          If S >= 0 Then
            If SymTab[S].Kind = SK_FUNC Then
              T := SymTab[S].TypeIdx;
          ParsePrimary := ParseOpaque(Tok, T);
          Exit;
        End;
        S := SymFind(Tok.Val);
        If S < 0 Then
          S := SymImplicit(Tok.Val, Tok.Line, Tok.Col);
        If SymIsArrayLike(S) Then
          ErrorAt(Tok.Line, Tok.Col, 'indice attendu pour le tableau ' +
                  Tok.Val)
        Else If SymTab[S].Kind In [SK_VAR, SK_OWN, SK_PARAM_VALUE,
                              SK_PARAM_NAME] Then
          ParsePrimary := ExprMakeVar(S, Tok.Line, Tok.Col)
        Else If (SymTab[S].Kind = SK_FUNC) And (S = SymCurProc) And
                AtOp(':=') Then
          ParsePrimary := ExprMakeVar(S, Tok.Line, Tok.Col)
        Else
          ErrorAt(Tok.Line, Tok.Col,
                  'variable attendue: ' + Tok.Val + ' (' +
                  SymKindName(SymTab[S].Kind) + ')');
      End;
  Else
    ParseError('expression attendue');
  End;
End;

{ Operandes : not, + et - unaires (priorite maximale, droite) }
Function ParseUnary : Integer;
Var
  Op        : TString;
  Line, Col : Integer;
  A         : Integer;
Begin
  If AtOp('+') Or AtOp('-') Or AtKw('not') Then
  Begin
    Op   := CurToken.Val;
    Line := CurToken.Line;
    Col  := CurToken.Col;
    ParserAdvance;
    A := ParseUnary;
    ParseUnary := ExprMakeUnary(Op, A, Line, Col);
  End
  Else
    ParseUnary := ParsePrimary;
End;

{ Boucle de precedence : n'accepte que les operateurs de priorite
  >= MinPrec ; ^ est associatif a droite, les autres a gauche. }
Function ParseExprPrec(MinPrec : Integer) : Integer;
Var
  Left, Right, Prec : Integer;
  Op                : TString;
  Line, Col         : Integer;
  RightAssoc        : Boolean;
  LastRel           : Boolean;
Begin
  Left := ParseUnary;
  LastRel := False;
  Repeat
    Prec := BinOpPrec(CurToken);
    If (Prec = 0) Or (Prec < MinPrec) Then Break;
    Op   := CurToken.Val;
    Line := CurToken.Line;
    Col  := CurToken.Col;
    RightAssoc := BinOpIsRight(CurToken);
    ParserAdvance;
    If RightAssoc Then
      Right := ParseExprPrec(Prec)
    Else
      Right := ParseExprPrec(Prec + 1);
    If OpIsRel(Op) And LastRel Then
    Begin
      { a < b < c : interdit, utiliser (a < b) and (b < c) }
      ErrorAt(Line, Col, 'comparaison chainee non supportee: ' +
              'utiliser and entre les comparaisons');
      Left := -1;
      LastRel := False;
    End
    Else
    Begin
      Left := ExprMakeBinary(Op, Left, Right, Line, Col);
      LastRel := OpIsRel(Op) And (Left >= 0);
    End;
  Until False;
  ParseExprPrec := Left;
End;

Function ParseExpr : Integer;
Begin
  ParseExpr := ParseExprPrec(1);
End;

{ Mode debug -d : arbre d'une expression }
Procedure ExprDump(N, Depth : Integer);
Var
  Pad : TString;
  I   : Integer;
Begin
  If N < 0 Then Exit;
  Pad := '';
  While Length(Pad) < 2 * Depth + 2 Do
    Pad := Pad + ' ';
  Write(Pad);
  Case ExprTab[N].Kind Of
    EX_INT    : WriteLn('int ', ExprTab[N].IntVal);
    EX_REAL   : WriteLn('real ', ExprTab[N].RealVal:0:6);
    EX_BOOL   : If ExprTab[N].IntVal <> 0 Then
                  WriteLn('bool true')
                Else
                  WriteLn('bool false');
    EX_STR    : WriteLn('str "', ExprStrTab[ExprTab[N].StrIdx], '"');
    EX_VAR    : WriteLn('var ', SymTab[ExprTab[N].Sym].Name, ' : ',
                        TypeName(ExprTab[N].Typ));
    EX_UNARY  : WriteLn('unary ', ExprTab[N].Op, ' : ',
                        TypeName(ExprTab[N].Typ));
    EX_BINARY : WriteLn('binary ', ExprTab[N].Op, ' : ',
                        TypeName(ExprTab[N].Typ));
    EX_COND   : WriteLn('cond : ', TypeName(ExprTab[N].Typ));
    EX_ASSIGN : WriteLn('assign := ', ConvName(ExprTab[N].Conv), ' : ',
                        TypeName(ExprTab[N].Typ));
    EX_OPAQUE : WriteLn('opaque ', ExprStrTab[ExprTab[N].StrIdx], ' : ',
                        TypeName(ExprTab[N].Typ));
    EX_INDEX  : Begin
                  Write('index ', SymTab[ExprTab[N].Sym].Name, '[',
                        ExprTab[N].IntVal, '] : ',
                        TypeName(ExprTab[N].Typ));
                  If ExprTab[N].Flag Then
                    WriteLn(' (controle de bornes)')
                  Else
                    WriteLn;
                End;
    EX_LIST   : WriteLn('list');
    EX_LABEL  : WriteLn('label ', SymTab[ExprTab[N].Sym].Name);
    EX_SWITCHREF : WriteLn('switch ', SymTab[ExprTab[N].Sym].Name, '[]');
  End;
  If ExprTab[N].Kind = EX_INDEX Then
  Begin
    I := ExprTab[N].L;
    While I >= 0 Do
    Begin
      ExprDump(ExprTab[I].L, Depth + 1);
      I := ExprTab[I].R;
    End;
    Exit;
  End;
  If ExprTab[N].Kind = EX_COND Then
  Begin
    WriteLn(Pad, ' if:');
    ExprDump(ExprTab[N].L, Depth + 2);
    WriteLn(Pad, ' then:');
    ExprDump(ExprTab[N].R, Depth + 2);
    WriteLn(Pad, ' else:');
    ExprDump(ExprTab[N].E, Depth + 2);
    Exit;
  End;
  ExprDump(ExprTab[N].L, Depth + 1);
  ExprDump(ExprTab[N].R, Depth + 1);
End;

{ Debut d'une instruction expression : 42 ; 3 + 4 ; (2 + 3) * 4 ;
  "hello" ; true and false ; -5 ; not true ;  Elle est evaluee puis
  ignoree. Les instructions commencant par un identificateur
  (affectation, appel, etiquette) relevent des TODO 09 a 13. }
Function AtExprStart : Boolean;
Begin
  AtExprStart := (CurToken.Kind In [TK_INTEGER, TK_REAL, TK_STRING]) Or
                 AtKw('true') Or AtKw('false') Or AtKw('not') Or
                 AtOp('+') Or AtOp('-') Or AtPunct('(');
End;

Procedure ParseExprStatement;
Var
  N : Integer;
Begin
  ExprReset;
  N := ParseExpr;
  If N < 0 Then
    ParserSync
  Else If Opts.DebugMode Then
  Begin
    WriteLn('Expression ligne ', ExprTab[N].Line, ' :');
    ExprDump(N, 0);
  End;
  If Not AtStmtEnd Then
  Begin
    If N >= 0 Then ParseError('operateur ou '';'' attendu');
    ParserSync;
  End;
End;

Procedure ParseBlock; Forward;

{ Instruction simple (placeholder des TODO 08 a 13) : consomme les
  tokens jusqu au prochain ';' ou 'end' (non consommes). Un bloc
  begin...end imbrique est analyse a part pour que ses declarations
  et sa structure soient verifiees. L'expression isolee "42 ;" est
  donc lue puis ignoree. }
Procedure SkipStatement;
Var
  Depth : Integer;
Begin
  Depth := 0;
  While Not (AtEOF Or ((Depth = 0) And AtStmtEnd) Or AtPunct(';')) Do
    If AtKw('begin') Then
      ParseBlock
    Else
    Begin
      If AtPunct('(') Or AtPunct('[') Then
        Inc(Depth)
      Else If (AtPunct(')') Or AtPunct(']')) And (Depth > 0) Then
        Dec(Depth);
      ParserAdvance;
    End;
End;

{ ---- Affectations (TODO 10, 11) ---------------------------------- }

{ Cible deja analysee (variable ou element de tableau) suivie de ':='
  (token courant). Affectations multiples a := b := expr : le membre
  droit est analyse comme une expression ; si un ':=' suit et que
  c'est une cible, l'affectation continue (associative a droite).
  Chaque affectation vaut la valeur convertie vers sa cible. }
Function ParseAssignTail(Tgt : Integer) : Integer;
Var
  Val, N    : Integer;
  Conv      : TConv;
  Line, Col : Integer;
Begin
  ParseAssignTail := -1;
  Line := CurToken.Line;
  Col  := CurToken.Col;
  ParserAdvance;                          { :=  }
  Val := ParseExpr;
  If (Val >= 0) And AtOp(':=') And
     (ExprTab[Val].Kind In [EX_VAR, EX_INDEX]) Then
    Val := ParseAssignTail(Val);
  If (Tgt < 0) Or (Val < 0) Then Exit;
  If Not ExprCoerce(Val, ExprTab[Tgt].Typ, Conv, Line, Col) Then Exit;
  N := ExprNew(EX_ASSIGN, ExprTab[Tgt].Typ, Line, Col);
  ExprTab[N].Op   := ':=';
  ExprTab[N].L    := Tgt;
  ExprTab[N].R    := Val;
  ExprTab[N].Conv := Conv;
  Inc(AssignCount);
  ParseAssignTail := N;
End;

{ Instruction commencant par un identificateur : affectation si le
  token suivant est ':=' (variable) ou '[' (element de tableau, la
  cible est alors analysee avec ses indices). Etiquettes (TODO 13),
  appels de procedure (TODO 14) et write/read (TODO 16) restent
  sautes pour le moment. }
Procedure ParseIdentStatement;
Var
  Tok : TToken;
  Tgt, N : Integer;
Begin
  Tok := CurToken;
  ParserAdvance;
  If AtPunct(':') Then
  Begin
    ParseLabelDef(Tok.Val, Tok.Line, Tok.Col);
    Exit;
  End;
  If Not (AtOp(':=') Or AtPunct('[')) Then
  Begin
    ParserUnget(Tok);
    SkipStatement;
    Exit;
  End;
  ParserUnget(Tok);                       { nom de nouveau courant }
  ExprReset;
  Tgt := ParseExpr;
  N := -1;
  If Tgt >= 0 Then
    If AtOp(':=') And (ExprTab[Tgt].Kind In [EX_VAR, EX_INDEX]) Then
      N := ParseAssignTail(Tgt)
    Else
      ParseError(''':='' attendu apres ' + Tok.Val);
  If N < 0 Then
    ParserSync
  Else
  Begin
    If Opts.DebugMode Then
    Begin
      WriteLn('Affectation ligne ', ExprTab[N].Line, ' :');
      ExprDump(N, 0);
    End;
    If Not AtStmtEnd Then
    Begin
      ParseError('operateur ou '';'' attendu');
      ParserSync;
    End;
  End;
End;

{ ---- Instructions de controle : if et for (TODO 12) -------------- }

{ if condition then instruction [else instruction]
  Le else se rattache au if le plus proche (appel recursif). Le code
  de la condition et des branches est genere au TODO 18 : saut
  conditionnel vers l'etiquette else / fin. }
Procedure ParseIf;
Var
  C         : Integer;
  Line      : Integer;
Begin
  Inc(IfCount);
  Line := CurToken.Line;
  ParserAdvance;                          { if }
  ExprReset;
  C := ParseCondition;
  If Opts.DebugMode And (C >= 0) Then
  Begin
    WriteLn('If ligne ', Line, ' : condition');
    ExprDump(C, 1);
  End;
  If AtKw('then') Then
    ParserAdvance
  Else
  Begin
    ParseError('''then'' attendu apres la condition');
    ParserSync;
    Exit;
  End;
  ParseStatement;
  If AtKw('else') Then
  Begin
    If Opts.DebugMode Then WriteLn('Else (if ligne ', Line, ')');
    ParserAdvance;
    ParseStatement;
  End;
End;

{ Un element de liste de for : valeur, step-until ou while.
  VT = type de la variable de boucle. }
Procedure ParseForClause(VT : Integer);
Var
  E1, E2, E3, C : Integer;
  Conv          : TConv;
  Line, Col     : Integer;
  Empty         : Boolean;
Begin
  ExprReset;
  Line := CurToken.Line;
  Col  := CurToken.Col;
  E1 := ParseExpr;
  If E1 >= 0 Then
    If Not ExprCoerce(E1, VT, Conv, Line, Col) Then E1 := -1;

  If AtKw('step') Then
  Begin
    ParserAdvance;
    Line := CurToken.Line;
    Col  := CurToken.Col;
    E2 := ParseExpr;
    If (E2 >= 0) And (Not TypeIsArith(ExprTab[E2].Typ)) Then
    Begin
      ErrorAt(Line, Col, 'pas numerique attendu (type: ' +
              TypeName(ExprTab[E2].Typ) + ')');
      E2 := -1;
    End;
    If AtKw('until') Then
      ParserAdvance
    Else
      ParseError('''until'' attendu apres step');
    Line := CurToken.Line;
    Col  := CurToken.Col;
    E3 := ParseExpr;
    If (E3 >= 0) And (Not TypeIsArith(ExprTab[E3].Typ)) Then
    Begin
      ErrorAt(Line, Col, 'limite numerique attendue (type: ' +
              TypeName(ExprTab[E3].Typ) + ')');
      E3 := -1;
    End;
    If (E1 >= 0) And (E2 >= 0) And (E3 >= 0) Then
    Begin
      If Opts.DebugMode Then
      Begin
        WriteLn('  clause step-until :');
        WriteLn('    init :');  ExprDump(E1, 3);
        WriteLn('    step :');  ExprDump(E2, 3);
        WriteLn('    until :'); ExprDump(E3, 3);
      End;
      If ExprIsConst(E2) And (ExprConstReal(E2) = 0) Then
        WarnAt(Line, Col, 'pas nul: boucle infinie');
      If ExprIsConst(E1) And ExprIsConst(E2) And ExprIsConst(E3) And
         (ExprConstReal(E2) <> 0) Then
      Begin
        If ExprConstReal(E2) > 0 Then
          Empty := ExprConstReal(E1) > ExprConstReal(E3)
        Else
          Empty := ExprConstReal(E1) < ExprConstReal(E3);
        If Empty Then
          WarnAt(Line, Col, 'boucle jamais executee (bornes inversees)');
      End;
    End;
  End
  Else If AtKw('while') Then
  Begin
    ParserAdvance;
    C := ParseCondition;
    If (E1 >= 0) And (C >= 0) And Opts.DebugMode Then
    Begin
      WriteLn('  clause while :');
      WriteLn('    init :');  ExprDump(E1, 3);
      WriteLn('    while :'); ExprDump(C, 3);
    End;
    If (C >= 0) And (ExprTab[C].Kind = EX_BOOL) And
       (ExprTab[C].IntVal = 0) Then
      WarnAt(Line, Col, 'condition toujours fausse: ' +
             'boucle jamais executee');
  End
  Else If (E1 >= 0) And Opts.DebugMode Then
  Begin
    WriteLn('  clause valeur :');
    ExprDump(E1, 2);
  End;
End;

{ for v := e1, e2 step e3 until e4, e5 while c do instruction
  Chaque element de la liste est une valeur, un step-until ou un
  while ; ils sont executes dans l'ordre (le corps est partage). }
Procedure ParseFor;
Var
  Tgt, VT   : Integer;
  Line, Col : Integer;
  Sym       : Integer;
Begin
  Inc(ForCount);
  Line := CurToken.Line;
  ParserAdvance;                          { for }
  ExprReset;
  Col := CurToken.Col;
  Tgt := ParsePrimary;
  VT  := TY_UNKNOWN;
  If Tgt >= 0 Then
  Begin
    If ExprTab[Tgt].Kind <> EX_VAR Then
    Begin
      ErrorAt(Line, Col, 'variable de boucle simple attendue');
      Tgt := -1;
    End
    Else
    Begin
      Sym := ExprTab[Tgt].Sym;
      VT  := ExprTab[Tgt].Typ;
      If Not TypeIsNumeric(VT) Then
      Begin
        ErrorAt(Line, Col, 'variable de boucle numerique attendue ' +
                '(type: ' + TypeName(VT) + ')');
        Tgt := -1;
      End
      Else If Opts.DebugMode Then
        WriteLn('For ligne ', Line, ' : variable ', SymTab[Sym].Name,
                ' (', TypeName(VT), ')');
    End;
  End;
  If AtOp(':=') Then
    ParserAdvance
  Else
  Begin
    ParseError(''':='' attendu apres la variable de boucle');
    ParserSync;
    Exit;
  End;
  If Tgt < 0 Then VT := TY_UNKNOWN;

  If LoopDepth >= MAX_LOOP_NEST Then
    ErrorAt(Line, Col, 'boucles trop imbriquees (max ' +
            ItoS(MAX_LOOP_NEST) + ')');
  Inc(LoopDepth);
  Repeat
    ParseForClause(VT);
    If AtPunct(',') Then
      ParserAdvance
    Else
      Break;
  Until False;
  If AtKw('do') Then
    ParserAdvance
  Else
  Begin
    ParseError('''do'' attendu apres la liste du for');
    Dec(LoopDepth);
    ParserSync;
    Exit;
  End;
  ParseStatement;
  Dec(LoopDepth);
End;

{ ---- go to, etiquettes et designateurs (TODO 13) ----------------- }

{ Designateur : etiquette, element de switch, ou expression
  conditionnelle de designateurs :
    fin   100   menu[i + 1]   (d)   if c then fin else menu[2]
  Retourne un noeud EX_LABEL, EX_SWITCHREF ou EX_COND (type label),
  -1 en cas d'erreur. Un nom inconnu devient une etiquette en renvoi
  avant, resolue plus tard par SymDefLabel. }
Function ParseDesignator : Integer;
Var
  Tok       : TToken;
  C, T, E   : Integer;
  S, Idx, N : Integer;
  Conv      : TConv;
  Line, Col : Integer;
  Bad       : Boolean;
Begin
  ParseDesignator := -1;
  Line := CurToken.Line;
  Col  := CurToken.Col;

  If AtKw('if') Then
  Begin
    ParserAdvance;
    C := ParseCondition;
    If AtKw('then') Then
      ParserAdvance
    Else
    Begin
      ParseError('''then'' attendu');
      Exit;
    End;
    T := ParseDesignator;
    If AtKw('else') Then
      ParserAdvance
    Else
    Begin
      ParseError('''else'' attendu dans un designateur conditionnel');
      Exit;
    End;
    E := ParseDesignator;
    If (C < 0) Or (T < 0) Or (E < 0) Then Exit;
    N := ExprNew(EX_COND, TY_IDX_LABEL, Line, Col);
    ExprTab[N].L := C;
    ExprTab[N].R := T;
    ExprTab[N].E := E;
    ParseDesignator := N;
  End
  Else If AtPunct('(') Then
  Begin
    ParserAdvance;
    N := ParseDesignator;
    ExpectPunct(')');
    ParseDesignator := N;
  End
  Else If CurToken.Kind = TK_INTEGER Then
  Begin
    S := SymRefLabel(ItoS(CurToken.IntVal), Line, Col);
    ParserAdvance;
    N := ExprNew(EX_LABEL, TY_IDX_LABEL, Line, Col);
    ExprTab[N].Sym := S;
    ParseDesignator := N;
  End
  Else If CurToken.Kind = TK_IDENT Then
  Begin
    Tok := CurToken;
    ParserAdvance;
    If AtPunct('[') Then
    Begin
      Bad := False;
      S := SymFind(Tok.Val);
      If (S < 0) Or (SymTab[S].Kind <> SK_SWITCH) Then
      Begin
        ErrorAt(Tok.Line, Tok.Col, 'switch attendu: ' + Tok.Val);
        Bad := True;
      End;
      ParserAdvance;                              { [ }
      Line := CurToken.Line;
      Col  := CurToken.Col;
      Idx := ParseExprPrec(1);
      If Idx >= 0 Then
        If Not ExprCoerce(Idx, TY_IDX_INTEGER, Conv, Line, Col) Then
          Idx := -1;
      ExpectPunct(']');
      If Bad Or (Idx < 0) Then Exit;
      If ExprTab[Idx].Kind = EX_INT Then
        If (SymTab[S].SwitchCount > 0) And
           ((ExprTab[Idx].IntVal < 1) Or
            (ExprTab[Idx].IntVal > SymTab[S].SwitchCount)) Then
          WarnAt(Line, Col, 'indice de switch hors bornes (1..' +
                 ItoS(SymTab[S].SwitchCount) + '): aucun saut');
      N := ExprNew(EX_SWITCHREF, TY_IDX_LABEL, Tok.Line, Tok.Col);
      ExprTab[N].Sym := S;
      ExprTab[N].L   := Idx;
      ParseDesignator := N;
    End
    Else
    Begin
      S := SymFind(Tok.Val);
      If (S >= 0) And (SymTab[S].Kind = SK_SWITCH) Then
      Begin
        ErrorAt(Tok.Line, Tok.Col, 'indice attendu pour le switch ' +
                Tok.Val);
        Exit;
      End;
      S := SymRefLabel(Tok.Val, Tok.Line, Tok.Col);
      If SymTab[S].Level <> CurLevel Then
      Begin
        ErrorAt(Tok.Line, Tok.Col, 'go to vers une etiquette d''une ' +
                'autre procedure: non supporte (' + Tok.Val + ')');
        Exit;
      End;
      N := ExprNew(EX_LABEL, TY_IDX_LABEL, Tok.Line, Tok.Col);
      ExprTab[N].Sym := S;
      ParseDesignator := N;
    End;
  End
  Else
    ParseError('designateur attendu (etiquette ou switch[i])');
End;

{ go to designateur   (le mot go to est le token courant) }
Procedure ParseGoto;
Var
  D, Line : Integer;
Begin
  Inc(GotoCount);
  Line := CurToken.Line;
  ParserAdvance;                          { go to }
  ExprReset;
  D := ParseDesignator;
  If D < 0 Then
  Begin
    ParserSync;
    Exit;
  End;
  If Opts.DebugMode Then
  Begin
    WriteLn('Goto ligne ', Line, ' :');
    ExprDump(D, 1);
  End;
  If Not AtStmtEnd Then
  Begin
    ParseError('operateur ou '';'' attendu apres go to');
    ParserSync;
  End;
End;

{ etiquette : instruction   (Name = nom ou nombre, ':' est le token
  courant). L'instruction suivante peut etre vide ou un bloc. }
Procedure ParseLabelDef(Const Name : TString; Line, Col : Integer);
Begin
  SymDefLabel(Name, Line, Col);
  Inc(LabelCount);
  If Opts.DebugMode Then
    WriteLn('Etiquette ', Name, ' ligne ', Line);
  ParserAdvance;                          { : }
  ParseStatement;
End;

{ Instruction commencant par un entier : etiquette numerique
  (100: instruction) ou expression isolee }
Procedure ParseNumericStart;
Var
  Tok : TToken;
Begin
  Tok := CurToken;
  ParserAdvance;
  If AtPunct(':') Then
    ParseLabelDef(ItoS(Tok.IntVal), Tok.Line, Tok.Col)
  Else
  Begin
    ParserUnget(Tok);
    ParseExprStatement;
  End;
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

{ Borne de tableau : expression entiere. Une constante est retenue
  telle quelle ; sinon (Dyn = True) Node est l'arbre de la borne,
  evalue a l'execution par le generateur (TODO 18). }
Procedure ParseBound(Var V : LongInt; Var Dyn : Boolean;
                     Var Node : Integer);
Var
  N, Line, Col : Integer;
  Conv         : TConv;
Begin
  V    := 0;
  Node := -1;
  Line := CurToken.Line;
  Col  := CurToken.Col;
  N := ParseExprPrec(1);
  If N < 0 Then
  Begin
    Dyn := True;
    Exit;
  End;
  If Not ExprCoerce(N, TY_IDX_INTEGER, Conv, Line, Col) Then
  Begin
    Dyn := True;
    Exit;
  End;
  If ExprTab[N].Kind = EX_INT Then
    V := ExprTab[N].IntVal
  Else
  Begin
    Dyn  := True;
    Node := N;
  End;
End;

{ Octets d'un tableau a bornes constantes (0 et erreur si trop grand) }
Function ArrayBytes(S : Integer; Line, Col : Integer) : LongInt;
Var
  D        : Integer;
  Count, W : TWide;
Begin
  ArrayBytes := 0;
  Count := 1;
  For D := 1 To SymTab[S].ArrDims Do
  Begin
    Count := Count * (TWide(SymTab[S].ArrHi[D]) -
                      TWide(SymTab[S].ArrLo[D]) + 1);
    If Count > MAX_ARRAY_ELEMS Then
    Begin
      ErrorAt(Line, Col, 'tableau trop grand: ' + SymTab[S].Name);
      Exit;
    End;
  End;
  W := Count * TypeSizeof(SymTab[S].ElemType);
  If W > MAX_ARRAY_BYTES Then
  Begin
    ErrorAt(Line, Col, 'tableau trop grand: ' + SymTab[S].Name);
    Exit;
  End;
  ArrayBytes := W;
End;

{ [integer|real|Boolean] array a, b [lo:hi, lo:hi], c [lo:hi]
  Un tableau sans type est de type real (regle d Algol 60).
  Bornes constantes : donnees statiques (.data au niveau 0, cadre de
  la procedure sinon). Bornes variables : allocation sur le tas a
  l'execution. }
Procedure ParseArrayDecl(ElemType : Integer; IsOwn : Boolean);
Var
  Names      : Array[1..16] Of Integer;
  NLo, NHi   : Array[1..MAX_DIM] Of Integer;
  NName      : Integer;
  I, D       : Integer;
  Lo, Hi     : LongInt;
  DynD       : Boolean;
  Cur        : Integer;
  Line, Col  : Integer;
Begin
  Repeat
    ExprReset;
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
      Line := CurToken.Line;
      Col  := CurToken.Col;
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
    For I := 1 To MAX_DIM Do
    Begin
      NLo[I] := -1;
      NHi[I] := -1;
    End;
    Repeat
      DynD := False;
      Inc(D);
      Lo := 0;
      Hi := 0;
      If D <= MAX_DIM Then
        ParseBound(Lo, DynD, NLo[D])
      Else
        ParseBound(Lo, DynD, I);
      If AtPunct(':') Then
        ParserAdvance
      Else
        ParseError(''':'' attendu entre les bornes');
      If D <= MAX_DIM Then
        ParseBound(Hi, DynD, NHi[D])
      Else
        ParseBound(Hi, DynD, I);
      If D <= MAX_DIM Then
        For I := 1 To NName Do
        Begin
          Cur := Names[I];
          SymTab[Cur].ArrDims := D;
          SymTab[Cur].ArrLo[D] := Lo;
          SymTab[Cur].ArrHi[D] := Hi;
          If DynD Then SymTab[Cur].ArrDynamic := True;
        End
      Else
        ParseError('trop de dimensions (max ' + ItoS(MAX_DIM) + ')');
      If (Not DynD) And (Lo > Hi) Then
        ErrorAt(CurToken.Line, CurToken.Col,
                'bornes inversees: ' + ItoS(Lo) + ':' + ItoS(Hi));
      If AtPunct(',') Then
        ParserAdvance
      Else
        Break;
    Until False;
    ExpectPunct(']');

    { stockage des tableaux a bornes constantes }
    For I := 1 To NName Do
    Begin
      Cur := Names[I];
      If (Not SymTab[Cur].ArrDynamic) And (SymTab[Cur].ArrDims > 0) Then
      Begin
        SymTab[Cur].ArrBytes := ArrayBytes(Cur, Line, Col);
        If (CurLevel > 0) And (Not IsOwn) Then
          SymTab[Cur].ArrDataOfs := SymAllocLocal(SymTab[Cur].ArrBytes);
      End;
      If Opts.DebugMode Then
      Begin
        Write('Tableau ', SymTab[Cur].Name, ' ', TypeName(ElemType),
              ' [', SymTab[Cur].ArrDims, ' dim.]');
        If SymTab[Cur].ArrDynamic Then
          WriteLn(' bornes a l''execution')
        Else
          WriteLn(' ', SymTab[Cur].ArrBytes, ' octets');
      End;
    End;
    If Opts.DebugMode Then
      For D := 1 To MAX_DIM Do
      Begin
        If NLo[D] >= 0 Then
        Begin
          WriteLn('  borne inf. dim ', D, ' :');
          ExprDump(NLo[D], 1);
        End;
        If NHi[D] >= 0 Then
        Begin
          WriteLn('  borne sup. dim ', D, ' :');
          ExprDump(NHi[D], 1);
        End;
      End;
    If AtPunct(',') Then
      ParserAdvance
    Else
      Break;
  Until False;
End;

{ switch s := l1, l2, if b then l3 else l4
  Chaque designateur est analyse (ParseDesignator) ; les etiquettes
  encore inconnues sont des renvois avant. Le generateur (TODO 18)
  emet la table des adresses et, pour un designateur conditionnel,
  un petit bloc de code qui calcule la destination. }
Procedure ParseSwitchDecl;
Var
  S, N, D : Integer;
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
  If AtPunct(';') Or AtEOF Then
  Begin
    ParseError('liste de designateurs attendue');
    Exit;
  End;
  ExprReset;
  N := 0;
  Repeat
    D := ParseDesignator;
    Inc(N);
    If D < 0 Then
    Begin
      ParserSync;
      Break;
    End;
    If Opts.DebugMode Then
    Begin
      WriteLn('Switch ', SymTab[S].Name, ' designateur ', N, ' :');
      ExprDump(D, 1);
    End;
    If AtPunct(',') Then
      ParserAdvance
    Else
      Break;
  Until False;
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

  ParseStatement;                { corps de la procedure }
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

{ Instruction : bloc, if, for, affectation, expression isolee ; rien
  devant ';' 'end' ou 'else' (instruction vide). Les autres formes
  (go to, etiquettes, appels, write...) sont sautees jusqu'aux
  TODO 13, 14 et 16. }
Procedure ParseStatement;
Begin
  If AtStmtEnd Then
    Exit
  Else If AtKw('begin') Then
    ParseBlock
  Else If AtKw('if') Then
    ParseIf
  Else If AtKw('for') Then
    ParseFor
  Else If AtKw('goto') Then
    ParseGoto
  Else If CurToken.Kind = TK_INTEGER Then
    ParseNumericStart
  Else If AtExprStart Then
    ParseExprStatement
  Else If CurToken.Kind = TK_IDENT Then
    ParseIdentStatement
  Else
    SkipStatement;
End;

{ Element d un bloc : declaration ou instruction. }
Procedure ParseItem;
Begin
  If AtDeclKw Then
    ParseDeclaration
  Else
    ParseStatement;
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
  AssignCount := 0;
  IfCount    := 0;
  GotoCount  := 0;
  LabelCount := 0;
  ForCount   := 0;
  LoopDepth  := 0;
  ParkValid  := False;
  LexQuiet   := True;            { erreurs lexicales deja signalees }
  LexInit;
  SymEnterScope;                 { portee globale (identifiant 1) }
  ParseProgram;
  SymLeaveScope;
  LexClose;
  If Opts.Verbose Then
    WriteLn('  ', DeclCount, ' declaration(s), ', ProcCount,
            ' procedure(s), ', BlockCount, ' bloc(s), ', AssignCount,
            ' affectation(s), ', IfCount, ' if, ', ForCount, ' for, ',
            GotoCount, ' goto, ', LabelCount, ' etiquette(s), ',
            FoldCount, ' constante(s) repliee(s)');
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
  {$IFDEF FPC}
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
                    exOverflow, exUnderflow, exPrecision]);
  {$ENDIF}
  FoldCount := 0;
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
