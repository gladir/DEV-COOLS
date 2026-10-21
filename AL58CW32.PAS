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

  ETAT : TODO 01 a 25 implementes (analyse complete du langage,
         generation du code, listing .ASM, encodeur x86-32, ecrivains
         PE et COFF, runtime integre, gestion des erreurs, pilotage,
         validation sur les 31 exemples SAMPLES\ALGOL58).

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

  TODO 14 - PROCEDURES ET FONCTIONS [IMPLEMENTE]
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
              droite a gauche, nettoyage par la procedure, EBP sauvegarde)
            Exemples : procs.a58, test_procedures.a58
            Realise : appel comme instruction (nom(args), nom() ou nom seul)
              et comme valeur (noeud EX_CALL) ; nombre d'arguments
              verifie, argument value converti vers le type du
              parametre, argument par nom controle (convertible), tableau
              passe par son nom (type des elements verifie), argument
              simple marque 'reference' (TODO 15), procedure sans valeur
              refusee dans une expression ; recursion (la procedure est
              visible dans son propre corps) ; les parametres sont
              conserves apres la fermeture du corps pour les appels
              ulterieurs ; un nom inconnu suivi de ( reste une fonction
              intrinseque (TODO 17)
            Convention d'appel retenue : arguments empiles de droite a
              gauche, puis le lien statique (procedure declaree dans une
              autre procedure), CALL ; la procedure nettoie la pile avec
              RET n (n = ParamBytes) ; resultat dans EAX (integer,
              Boolean) ou ST(0) (real)

  TODO 15 - PARAMETRES PAR NOM ET THUNKS [IMPLEMENTE]
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
            Realise : classement de chaque argument par nom (TArgClass) :
              constante (cellule .data, par reference), variable simple
              ou element a indices constants (reference directe),
              parametre par nom de l'appelant (paire reprise telle
              quelle), expression ou element a indices variables (thunk
              de lecture, reevalue a chaque acces : Jensen's device),
              variable ou element ecrit par la procedure et converti ou
              indice (thunk d'ecriture qui rend l'adresse) ; un thunk
              recoit le nom _A58TH_proc_param (unique) ; IsWritten marque
              les parametres affectes (affectation, variable de for) et
              se propage aux parametres transmis ; un argument non
              assignable pour un parametre modifie est une erreur
            Paire transmise : mot 0 = adresse du thunk (0 = reference
              directe), mot 1 = BP de l'appelant (ou adresse de la
              variable si mot 0 = 0) ; le thunk est appele avec EAX =
              contexte, fixe EBP, rend la valeur ou l'adresse dans EAX
              (ST(0) pour un real)
            Reste pour la generation de code (TODO 18) : emission des
              thunks au moment de l'appel, acces au parametre dans le
              corps (appel du thunk ou lecture par reference)

  TODO 16 - ENTREES/SORTIES : WRITE, WRITELN, READ, READLN [IMPLEMENTE]
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
            Realise : write / writeln / read / readln reconnus par leur nom
              (non reserves : une declaration du meme nom est prioritaire),
              parentheses facultatives, noeuds EX_WRITE et EX_READ ;
              write accepte chaine, integer, real, Boolean ; les entiers
              et booleens constants sont convertis en texte puis fusionnes
              avec les chaines voisines ; read demande des variables
              numeriques ou Boolean, elements de tableau ou parametres par
              nom (marques ecrits) ; stdout seulement (pas de syntaxe
              pour stderr dans le langage)
            Reste pour le runtime (TODO 22) : format des reels, lecture
              des Boolean (true / false), WriteFile et ReadFile

  TODO 17 - FONCTIONS INTRINSEQUES [IMPLEMENTE]
            abs, sign, entier, sqrt, max, min, mod(a, b) en fonction
            Avec x87 : sin, cos, arctan, ln, exp, sqrt reels corrects
              (au lieu des stubs 16 bits), puissance reelle
            Resultat integer ou real selon le type de l'argument
            Verification du nombre et du type d'arguments (erreur sinon)
            Un identificateur intrinseque peut etre redefini par une
              procedure utilisateur (la declaration utilisateur gagne)
              (exemple : integer procedure max(a, b) dans hello.a58)
            Exemples : test_intrinsics.a58, math.a58, test_runtime.a58
            Realise : table des intrinseques (abs, sign, entier, sqrt, sin,
              cos, arctan, ln, exp, max, min, mod, div), noeud EX_INTRIN ;
              entier = plancher (entier(-2.1) = -3, identite sur un
              integer) ; sqrt suit son argument (racine entiere pour un
              integer, x87 pour un real) ; max / min convertissent vers le
              type commun ; mod(a, b) et div(a, b) exigent des entiers ;
              repliement des appels a arguments constants (avec erreurs :
              sqrt negatif, ln <= 0, division par zero) ; un nom inconnu
              suivi de ( est maintenant une erreur, ainsi qu'une
              instruction commencant par un nom inconnu
            Reste pour la generation de code (TODO 18) et le runtime
              (TODO 22) : appels _A58RT_ABS, SIGN, SQRT, MAX, MIN,
              instructions x87 FSIN, FCOS, FPATAN, FYL2X, F2XM1...

  TODO 18 - GENERATION DU CODE ASSEMBLEUR 80386 [IMPLEMENTE]
            Representation du code : liste d'instructions internes avec
              labels et operandes (registres 32 bits, memoire, immediats)
              CodeTab (programme) et DeferTab (procedures et thunks,
              places apres le programme) ; noms internes (Intern)
            Emetteur ASM textuel (actif seulement avec -asm) :
              .386 / .MODEL FLAT / INCLUDELIB kernel32.lib / .DATA /
              .CODE / END _A58P_Main (syntaxe de ML.PAS)
            Emit, EmitLabel, EmitComment, EmitBlank, NewLabel
            Prologue/epilogue : PUSH EBP / MOV EBP,ESP / SUB ESP,n /
              locales mises a zero (REP STOSD) ... MOV ESP,EBP /
              POP EBP / RET n ; taille du cadre corrigee en fin de corps
            Sections : .CODE, .DATA (variables, own, tableaux et leurs
              descripteurs, tables de switch, constantes reelles, chaines
              litterales dedoublonnees avec 0 final)
            Imports Win32 declares via EXTERN/INCLUDELIB kernel32.lib
            Generation en une passe, au fil de l'analyse : expressions
              entieres (EAX) et reelles (x87, valeurs intermediaires sur
              la pile machine), comparaisons, and / or / imp en sauts,
              expressions conditionnelles, affectations (adresse de la
              cible puis valeur), if, for a plusieurs clauses (selecteur
              de clause), go to / switch (table + JMP indirect), appels
              avec lien statique, arguments value / par nom (paire,
              thunks), tableaux (descripteur, controle de bornes,
              bornes dynamiques sur le tas), E/S et intrinseques
            Contrat avec le runtime (TODO 22) : routines _A58RT_* appelees
              avec arguments en registres : WRITESTR (EAX, EDX), WRITEZ,
              WRITEINT, WRITEREAL (ST0), WRITEBOOL, NEWLINE, READINT,
              READREAL, READBOOL, READLN, POW, RPOW, EXP, FLOOR, RTOI,
              RSIGN, ISQRT, CHKIDX (conserve les registres), DIVZERO, ALLOC
            Verifie avec ML.PAS : les 31 exemples SAMPLES\ALGOL58 sont
              compiles, assembles, lies puis executes avec un runtime de
              test ; les sorties correspondent aux resultats attendus
            Contournements de ML.PAS (bogues observees) : PUSH OFFSET
              etiquette_en_avant mal dimensionne a la passe 1 (passer par
              un registre), TEST reg,imm mal encode, immediats 16 bits
              emis sur 32 bits (AND AX,imm)

  TODO 19 - ENCODEUR BINAIRE x86-32 [IMPLEMENTE]
            Encoder en octets le sous-ensemble 80386 genere : MOV, MOVZX,
              LEA, PUSH, POP, ADD/SUB/AND/OR/XOR/CMP (reg, memoire,
              immediat 8 ou 32 bits), TEST, IMUL, IDIV, DIV, CDQ, NEG,
              NOT, INC, DEC, SHL, SHR, SAR, SETcc, Jcc, JMP (direct et
              indirect), CALL (direct, registre, memoire), RET, REP
              STOSD, SAHF et les instructions x87 (FLD, FST, FSTP, FILD,
              FISTP, FADD..FDIVR en memoire et en ST(i), FADDP..FDIVP,
              FCOM, FCOMP, FXCH, FNSTSW, FNSTCW, FLDCW et les operations
              sans operande : FCHS FABS FTST FLD1 FLDZ FLDL2E FLDLN2
              F2XM1 FYL2X FPATAN FRNDINT FSCALE FSQRT FSIN FCOS)
            Operandes 8, 16 et 32 bits, ModRM / SIB / deplacement 8 ou 32
              bits (cas [EBP], [ESP], [sym], [sym + index*echelle])
            Tampons de code et de donnees (BinCode, BinData) ; table des
              etiquettes BinLbl (code, donnees, externe) ; relocations
              BinFix : BF_ABS32 (adresse d'un symbole : champ code ou
              donnees, la valeur en place est l'addendum) et BF_REL32
              (appel ou saut vers un symbole externe)
            Sauts courts ou longs choisis par relaxation : tous courts au
              depart, agrandis tant qu'un deplacement deborde (converge,
              les tailles ne font que croitre) ; cibles externes en rel32
            Donnees : DataTab -> octets (zeros, chaines avec 0 final,
              entiers, reels, tables d'adresses avec relocations)
            Imports : toute cible d'appel non definie est un import
              (BinImport), a resoudre par l'ecrivain PE ou COFF
            Mode -d : <sortie>.lst, un listing hexadecimal (decalage,
              octets, instruction)
            Verification : chaque instruction du listing est re-decodee
              avec objdump et comparee (mnemonique, longueur, operandes)
              sur les 31 exemples et sur une serie de 131 instructions
              couvrant toutes les formes (dont celles du futur runtime) ;
              aucun ecart

  TODO 20 - ECRIVAIN PE (.EXE WINDOWS 32 BITS) [IMPLEMENTE]
            En-tete MZ + souche DOS, signature PE, COFF File Header
              (machine 386, 3 sections, sans relocation), Optional Header
              (magic $010B, ImageBase $00400000, alignements 4096 / 512,
              sous-systeme console, piles et tas de 1 Mo reserves)
            Sections .text (code + une souche JMP [IAT] par import),
              .data (donnees), .idata (import de kernel32.dll : table
              des descripteurs, ILT, IAT, noms avec indice, nom de la DLL)
            Repertoires : importation (1) et IAT (12) ; point d'entree =
              _A58P_Main
            Relocations resolues a l'ecriture : adresses absolues
              (code -> donnees, donnees -> code pour les tables de
              switch) et appels aux imports (deplacement vers la souche)
            Un symbole non defini dont le nom commence par _A58 est une
              erreur (routine du runtime absente, TODO 22) ; tout autre
              nom est importe de kernel32.dll (GetStdHandle, WriteFile,
              ReadFile, ExitProcess, GetProcessHeap, HeapAlloc...)
            Fichier .EXE par defaut (option -o pour le nom)
            Verifie : objdump -x / -p lit l'en-tete et la table
              d'importation ; un programme assemble a la main (appels
              GetStdHandle, WriteFile, ExitProcess, saut par table de
              switch) s'execute correctement avec un code de retour 42 ;
              l'execution des 31 exemples attend le runtime (TODO 22)

  TODO 21 - ECRIVAIN COFF (.OBJ, OPTION -obj) [IMPLEMENTE]
            COFF File Header (machine 386, 2 sections, sans en-tete
              optionnel), sections .text (code, alignement 4) et .data
              (donnees) avec leurs relocations (IMAGE_REL_I386_DIR32 pour
              les adresses absolues, REL32 pour les appels externes)
            Table des symboles : .text et .data (statiques, avec entree
              auxiliaire : taille et nombre de relocations), _A58P_Main
              (externe, defini dans .text), puis un symbole externe non
              defini par import (routines _A58RT_* du runtime, fonctions
              Win32) ; table des chaines pour les noms de plus de 8
              caracteres
            Une adresse absolue vers une etiquette definie vise le symbole
              de section, le decalage de l'etiquette etant ajoute a la
              valeur en place (addendum COFF)
            Option -obj : un seul .OBJ, jamais de .EXE ; -obj -asm produit
              .OBJ et .ASM
            Verifie : les 31 exemples donnent un .OBJ lisible par objdump
              et llvm-objdump (sections, symboles, relocations) ; lies
              avec lld-link a un runtime de test et une bibliotheque
              d'import kernel32, hello, switch, procs et test_thunks
              s'executent avec la meme sortie que l'.EXE direct

  TODO 22 - RUNTIME ALGOL 58 POUR WIN32 [IMPLEMENTE]
            Runtime ecrit en assembleur 80386, integre au compilateur sous
              forme de texte (RtText, section 12), sans bibliotheque C :
              seules les fonctions de kernel32.dll sont importees
              (GetStdHandle, WriteFile, ReadFile, ExitProcess,
              GetProcessHeap, HeapAlloc)
            Mini-assembleur (RtAssembleLine) : convertit les lignes en
              instructions internes (registres, immediats decimaux ou
              hexadecimaux, [Sym+Base+Index*Echelle+Depl], BYTE/WORD/DWORD/
              QWORD PTR, OFFSET, ST(i)), reutilisees par le listing .ASM
              et l'encodeur ; JZ / JNZ sont des synonymes de JE / JNE
            Emission des seules routines utilisees : fermeture transitive
              des appels _A58RT_* (RtMark) a partir du code du programme ;
              les cellules de donnees _A58_* sont creees a la demande
            Le runtime est ajoute apres le code du programme (RtLink, au
              debut de la phase codegen) : le listing .ASM est donc
              autonome (assemblable seul avec ML.PAS) et le .OBJ ne
              depend plus que de kernel32
            Routines : WRITESTR (EAX adresse, EDX longueur), WRITEZ,
              WRITEINT, WRITEREAL (ST0), WRITEBOOL, NEWLINE, READINT,
              READREAL, READBOOL, READLN (avec GETC / UNGETC / SKIPWS),
              POW (entiers), RPOW (reels), EXP, EXP2, FLOOR, RTOI (arrondi,
              demi vers le haut), RSIGN, ISQRT, CHKIDX (conserve tous les
              registres), DIVZERO, ALLOC (tas du processus, memoire a zero)
            Messages d'erreur d'execution (code de sortie 1) : 'Erreur:
              indice hors bornes', 'Erreur: division par zero'
            Formats : entier en decimal, signe '-' ; reel en notation fixe,
              6 decimales au plus, zeros finaux supprimes (au moins un
              chiffre apres le point), partie entiere limitee a environ
              2 milliards ; Boolean true / false ; fin de ligne CR LF ;
              lecture : blancs ignores, signe, chiffres, point decimal ;
              Boolean lu : true si le premier mot commence par t ou T
            Verifie : les 31 exemples compilent directement en .EXE et
              donnent les memes sorties qu'avec le runtime de test assemble
              par ML.PAS ; les listings .ASM seuls (hello, math,
              test_readwrite) s'assemblent avec ML.PAS et s'executent ;
              objdump confirme l'encodage du runtime (0 ecart) ; des .OBJ
              lies avec lld-link a une bibliotheque d'import kernel32
              (math, procs, arrays, test_final) s'executent correctement ;
              lecture de l'entree standard testee (entier, reel, Boolean)

  TODO 23 - GESTION DES ERREURS ET AVERTISSEMENTS [IMPLEMENTE]
            Erreurs lexicales : caractere invalide, chaine non fermee,
              commentaire non termine, entier / reel / exposant hors
              limites ; signalees en une passe, puis le parseur tourne
              quand meme et ajoute les erreurs syntaxiques
            Erreurs syntaxiques : token inattendu (avec le token trouve),
              begin / end non apparie, parenthese ou crochet non ferme,
              point-virgule manquant, instruction ou expression attendue
            Erreurs semantiques : type incompatible, nombre d'arguments
              incorrect, procedure inconnue, etiquette non definie,
              declaration en double dans une portee, indice ou tableau
              invalide, division par zero constante
            Avertissements (affiches avec -w) : variable non declaree
              (declaration implicite), etiquette non utilisee, indice de
              switch hors bornes, real converti en integer, integer
              converti en Boolean, Boolean converti en integer
            Recuperation : ParserSync avance jusqu'a ; end begin for if
              ou procedure (non consommes) ; garantie de progression
              (un arret repete sur le meme mot-cle est franchi)
            Format : fichier(ligne,colonne) : erreur|avertissement :
              message ; erreur fatale : AL58CW32: erreur fatale: message
            Compteurs finaux (PhaseReport) : 'Compilation echouee : N
              erreur(s), M avertissement(s)' ou 'Compilation terminee :
              0 erreur, M avertissement(s)' ; arret apres 30 erreurs
            Code de retour EXIT_ERROR (1) si erreur ; les phases de
              generation ne tournent pas, donc aucun fichier de sortie
              n'est ecrit ; les fichiers deja crees sont supprimes si une
              erreur fatale survient (NoteOutput / RemoveOutputs)
            Verifie sur une batterie de 16 programmes fautifs (lexicaux,
              syntaxiques, semantiques) et sur test_errors.a58 (compile,
              avertissement de la variable x avec -w) ; les 31 exemples
              compilent toujours avec les memes sorties

  TODO 24 - PROGRAMME PRINCIPAL, MODES VERBEUX ET DEBOGAGE [IMPLEMENTE]
            Run : lexeur -> parseur/generateur -> (runtime) -> encodeur ->
              ecrivain (PE ou COFF) -> rapport ; .ASM optionnel ecrit
              avant l'encodage ; les phases de generation ne tournent
              pas s'il y a des erreurs
            Mode -v : banniere, fichiers de sortie, une ligne par phase,
              lignes et tokens, declarations et instructions analysees,
              instructions / donnees / noms internes, tailles .text et
              .data, relocations et imports, taille du fichier ecrit,
              bilan final
            Mode -d : tokens, types, table des symboles par portee,
              decisions du parseur, code interne (liste complete des
              instructions, runtime compris) et listing hexadecimal
              <sortie>.lst
            Mode -w / -w+ : activer les avertissements ; -w- : les
              desactiver (defaut : desactives)
            Suppression de sortie partielle si erreur (TODO 23)
            Verifie (matrice des fichiers produits pour hello.a58) :
              sans option -> h.exe seul ; -asm -> h.exe + h.asm ;
              -obj -> h.obj seul ; -obj -asm -> h.obj + h.asm ;
              -d -> h.exe + h.lst ; -v et -w- -> h.exe seul ;
              -o nom -> nom.exe (ou nom.obj / nom.asm)

  TODO 25 - VALIDATION SUR TOUS LES EXEMPLES SAMPLES\ALGOL58\* [IMPLEMENTE]
            Les 31 fichiers (arrays, blocks, bool, control, hello, math,
              procs, switch, test_arrays ... test_vars) sont compiles en
              .EXE, executes et compares aux sorties attendues
              TESTS\AL58CW32\exp\*.exp
            Script TESTS\test_al58cw32.sh (modele : test_adacw32.sh) :
              compile AL58CW32.PAS, puis pour chaque exemple
                - mode par defaut : .EXE seul (aucun .asm ni .obj)
                - -asm : .EXE + .ASM ; -obj : .OBJ seul ; -obj -asm :
                  .OBJ + .ASM
                - execution et comparaison de la sortie
                - .OBJ lisible par objdump ; encodage de chaque
                  instruction verifie par objdump (chkenc.py)
              puis des programmes fautifs (erreurs lexicale, syntaxique,
              semantique : message, code de retour 1, aucun .EXE),
              plusieurs erreurs en une compilation, avertissements avec
              et sans -w, options -h / sans argument / source introuvable
            Executeur des .EXE : Wine s'il est installe, sinon le
              chargeur PE minimal TESTS\AL58CW32\runpe.c (Linux x86-64,
              gcc ; stubs.asm / stubs.bin fournissent les fonctions
              kernel32 par appels systeme) ; sans executeur les
              comparaisons de sortie sont ignorees
            Cas speciaux verifies : test_errors.a58 compile en signalant
              l'avertissement avec -w ; test_types, test_symbols,
              test_emitter, test_operators, test_primexpr, test_vars et
              test_binexpr (expressions isolees, sans sortie) produisent
              un .EXE valide
            Resultat : 232 verifications reussies, 0 echec
            Livrables : README.md (ligne AL58CW32.PAS),
              DOC\TODO\AL58CW32.txt, BINLINUX\AL58CW32 ; WIN32\
              al58cw32.exe n'a pas pu etre genere ici (pas de
              compilateur croise Free Pascal vers Win32) : a produire
              avec fpc -Mtp AL58CW32.PAS sous Windows
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
  MAX_BIN_FIX   = {$IFDEF FPC}131072{$ELSE}512{$ENDIF};

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

  TDoubleBits = Record
    Case Boolean Of
      False : (D : Double);
      True  : (Lo, Hi : LongInt);
  End;

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
Var
  B : TDoubleBits;
Begin
  B.D := D;
  RealBad := (B.Hi And $7FF00000) = $7FF00000;
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
{ Fichiers de sortie crees pendant cette compilation : supprimes si une
  erreur fatale survient, pour ne laisser aucun fichier tronque. }
Var
  OutCreated  : Array[0..7] Of TString;
  OutCreatedN : Integer;

Procedure NoteOutput(Const Name : TString);
Begin
  If OutCreatedN <= 7 Then
  Begin
    OutCreated[OutCreatedN] := Name;
    Inc(OutCreatedN);
  End;
End;

Procedure RemoveOutputs;
Var
  I : Integer;
  F : File;
Begin
  For I := 0 To OutCreatedN - 1 Do
  Begin
    Assign(F, OutCreated[I]);
    Erase(F);
    If IOResult <> 0 Then ;
  End;
  OutCreatedN := 0;
End;

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('AL58CW32: erreur fatale: ', Msg);
  RemoveOutputs;
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('AL58CW32: avertissement: ', Msg);
  Inc(WarnCount);
End;

{ Erreur / avertissement localise dans le source :
  fichier(ligne,colonne) : erreur : message }
Procedure ErrorAt(Line, Col : Integer; Const Msg : TString);
Begin
  WriteLn(Opts.SrcFile, '(', Line, ',', Col, ') : erreur : ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs (' + ItoS(MAX_ERRORS) +
               '), compilation arretee');
End;

Procedure WarnAt(Line, Col : Integer; Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn(Opts.SrcFile, '(', Line, ',', Col, ') : avertissement : ', Msg);
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
  WriteLn('  -v         : mode verbeux (phases, tailles, statistiques)');
  WriteLn('  -d         : debug (tokens, symboles, code interne) et');
  WriteLn('               listing hexadecimal sortie.lst');
  WriteLn('  -w, -w-    : activer / desactiver les avertissements');
  WriteLn('  -h, --help : cette aide');
  WriteLn;
  WriteLn('Par defaut, produit seulement source.exe (PE Windows 32 bits).');
  WriteLn('Sans -asm aucun .asm n''est cree ; avec -obj aucun .exe n''est cree.');
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
    Else If (Opt = '-w') Or (Opt = '-w+') Then
      Opts.Warnings := True
    Else If Opt = '-w-' Then
      Opts.Warnings := False
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

{ Commentaire : "comment" deja lu, ignore tout jusqu au ; inclus.
  Tolerance : un ; entre parentheses sur la meme ligne ne termine pas
  le commentaire ("... (suivi de ;) ;" dans test_goto.a58). }
Procedure LexSkipComment(StartLine, StartCol : Integer);
Var
  Depth : Integer;
Begin
  Depth := 0;
  While ((LexCur <> ';') Or (Depth > 0)) And (LexCur <> LEX_EOF) Do
  Begin
    If LexCur = '(' Then
      Inc(Depth)
    Else If (LexCur = ')') And (Depth > 0) Then
      Dec(Depth)
    Else If LexCur = #10 Then
      Depth := 0;                    { la tolerance s arrete a la ligne }
    LexNextChar;
  End;
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

  { Mode de transmission d'un argument a un parametre (TODO 15).
    Un parametre par nom est transmis comme une paire de mots :
      mot 0 = adresse du thunk, ou 0 pour une reference directe
      mot 1 = BP de l'appelant (contexte du thunk), ou l'adresse
              de la variable quand le mot 0 vaut 0
    Le thunk est appele avec EAX = contexte ; il fixe EBP, evalue
    l'argument et retourne la valeur (thunk de lecture) ou l'adresse
    (thunk d'ecriture) dans EAX, ou ST(0) pour un real. }
  TArgClass = (
    AC_VALUE,          { parametre value : valeur convertie empilee    }
    AC_ARRAY,          { tableau : adresse du descripteur              }
    AC_CONST,          { constante : cellule en .data, par reference   }
    AC_REF,            { variable simple : adresse directe             }
    AC_FORWARD,        { parametre par nom de l'appelant : paire reprise }
    AC_THUNK,          { expression : thunk de lecture                 }
    AC_THUNK_RW        { variable indicee ou convertie ecrite par la
                         procedure : thunk qui rend l'adresse          }
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
  MAX_PARAM_SYMS  = {$IFDEF FPC}2048{$ELSE}64{$ENDIF};

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
    IsWritten  : Boolean;     { parametre par nom : affecte dans le corps }
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
    ArrDescOfs : LongInt;     { tableau local : decalage du descripteur }
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
  { SymTab : [0..MAX_SYM-1] pile des symboles visibles, puis les
    symboles implicites, puis (a partir de SYM_TOTAL) les copies des
    parametres des procedures dont le corps est ferme : un appel
    ulterieur en a besoin (nom, mode, type, decalage). }
  SymTab       : Array[0..SYM_TOTAL + MAX_PARAM_SYMS - 1] Of TSymRec;
  ParamSymCount: Integer;
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
  ParamSymCount := 0;
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
  I, S, Dest, P : Integer;
  CanHoist      : Boolean;
Begin
  If ScopeTop = 0 Then
    FatalError('erreur interne: fermeture sans portee ouverte');
  S := ScopeTop - 1;
  If Opts.DebugMode Then SymDumpScope(S);
  { Un renvoi avant vers une etiquette pas encore definie dans un
    bloc interne passe dans la portee englobante (meme procedure) ;
    sinon l'etiquette doit etre definie ici. }
  { parametres d'une procedure : copies conservees pour les appels }
  If ScopeTab[S].IsProc Then
  Begin
    P := ScopeTab[S].ProcSym;
    For I := 1 To SymTab[P].ParamCount Do
    Begin
      If ParamSymCount >= MAX_PARAM_SYMS Then
        FatalError('trop de parametres de procedures (max ' +
                   ItoS(MAX_PARAM_SYMS) + ')');
      SymTab[SYM_TOTAL + ParamSymCount] :=
        SymTab[SymTab[P].ParamSym[I]];
      SymTab[P].ParamSym[I] := SYM_TOTAL + ParamSymCount;
      Inc(ParamSymCount);
    End;
  End;
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
  CODE INTERNE ET LISTING ASM (TODO 18)

  Le generateur produit une liste d'instructions 80386 structurees
  (CodeTab), consommee par le listing .ASM optionnel (WriteListing)
  puis par l'encodeur binaire (TODO 19). Les procedures et les thunks
  sont ecrits dans une seconde liste (DeferTab) placee apres le
  programme principal.

  Conventions de generation :
    - integer, Boolean, pointeurs : EAX ; real : ST(0) ; les valeurs
      intermediaires sont rangees sur la pile machine (jamais en
      registre a travers un appel)
    - ECX, EDX, ESI, EDI : temporaires ; EBP : cadre ; ESP : pile
    - appels de procedure : voir ParseCall (TODO 14) ; routines du
      runtime : arguments dans les registres (TODO 22)
  ============================================================ }
Const
  MAX_CODE      = {$IFDEF FPC}262144{$ELSE}2048{$ENDIF};
  MAX_NAMES     = {$IFDEF FPC}16384{$ELSE}512{$ENDIF};
  MAX_ASMSTR    = {$IFDEF FPC}4096{$ELSE}64{$ENDIF};
  MAX_DATAITEMS = {$IFDEF FPC}8192{$ELSE}256{$ENDIF};
  MAX_TABENT    = {$IFDEF FPC}8192{$ELSE}256{$ENDIF};
  NAME_HASH     = {$IFDEF FPC}32768{$ELSE}1024{$ENDIF};

Type
  TReg = (
    R_NONE,
    R_EAX, R_ECX, R_EDX, R_EBX, R_ESP, R_EBP, R_ESI, R_EDI,   { 0..7 }
    R_AX, R_AL, R_CL, R_DL, R_BL                              { 16/8 bits }
  );

  TOperandKind = (
    OK_NONE,
    OK_REG,       { Reg                                                  }
    OK_IMM,       { Imm                                                  }
    OK_MEM,       { [Sym + Base + Index*Scale + Imm], Size octets        }
    OK_LABEL,     { cible de saut ou d'appel : Sym                       }
    OK_OFFSET,    { OFFSET Sym + Imm                                     }
    OK_ST         { ST(Imm)                                              }
  );

  TOperand = Record
    Kind  : TOperandKind;
    Reg   : TReg;
    Base  : TReg;
    Index : TReg;
    Scale : Byte;          { 1, 2, 4 ou 8 }
    Size  : Byte;          { memoire : 1, 2, 4, 8 octets (0 = non precise) }
    Imm   : LongInt;
    Sym   : Integer;       { indice dans NameTab, -1 si aucun }
  End;

  TOp = (
    OP_NOP,
    OP_LABEL,           { A.Sym = nom }
    OP_COMMENT,         { A.Imm = indice dans AsmStrs }
    OP_BLANK,
    OP_MOV, OP_MOVZX, OP_LEA, OP_PUSH, OP_POP,
    OP_ADD, OP_SUB, OP_IMUL, OP_IDIV, OP_CDQ, OP_NEG, OP_NOT,
    OP_AND, OP_OR, OP_XOR, OP_CMP, OP_TEST, OP_INC, OP_DEC,
    OP_SHR, OP_SAR,
    OP_SETE, OP_SETNE, OP_SETL, OP_SETLE, OP_SETG, OP_SETGE,
    OP_SETA, OP_SETAE, OP_SETB, OP_SETBE,
    OP_JMP, OP_JE, OP_JNE, OP_JL, OP_JLE, OP_JG, OP_JGE,
    OP_JA, OP_JAE, OP_JB, OP_JBE, OP_JS,
    OP_CALL, OP_RET, OP_REP_STOSD,
    OP_FLD, OP_FST, OP_FSTP, OP_FILD,
    OP_FADD, OP_FSUB, OP_FSUBR, OP_FMUL, OP_FDIV, OP_FDIVR,
    OP_FCHS, OP_FABS, OP_FSQRT, OP_FSIN, OP_FCOS, OP_FPATAN,
    OP_FYL2X, OP_FLDLN2, OP_FLD1, OP_FLDZ, OP_FXCH,
    OP_FCOM, OP_FCOMP, OP_FNSTSW, OP_SAHF,
    OP_DIV, OP_JNS, OP_SHL, OP_FTST, OP_FRNDINT, OP_F2XM1, OP_FSCALE,
    OP_FLDL2E, OP_FADDP, OP_FSUBP, OP_FMULP, OP_FDIVP, OP_FISTP,
    OP_FNSTCW, OP_FLDCW
  );

  TInstr = Record
    Op   : TOp;
    A, B : TOperand;
  End;

  TDataKind = (
    DK_ZERO,     { Size octets a zero }
    DK_STR,      { chaine : AsmStrs[Str], sans zero final }
    DK_INT,      { un DWORD : Lo }
    DK_REAL,     { un QWORD : Lo, Hi }
    DK_TABLE     { DWORD d'adresses : TabEnt[First .. First+Count-1] }
  );

  TDataItem = Record
    Name         : Integer;
    Kind         : TDataKind;
    Size         : LongInt;
    Lo, Hi       : LongInt;
    Str          : Integer;
    First, Count : Integer;
  End;


Var
  CodeTab    : Array[0..MAX_CODE - 1] Of TInstr;
  CodeCount  : LongInt;       { Integer = 16 bits en mode TP }
  DeferTab   : Array[0..MAX_CODE - 1] Of TInstr;
  DeferCount : LongInt;
  NameTab    : Array[0..MAX_NAMES - 1] Of TMangled;
  NameCount  : Integer;
  NameHash   : Array[0..NAME_HASH - 1] Of Integer;
  AsmStrs    : Array[0..MAX_ASMSTR - 1] Of TString;
  AsmStrCount: Integer;
  DataTab    : Array[0..MAX_DATAITEMS - 1] Of TDataItem;
  DataCount  : Integer;
  TabEnt     : Array[0..MAX_TABENT - 1] Of Integer;
  TabEntCount: Integer;
  LabelSeq   : LongInt;       { compteur des etiquettes internes     }
  ConstSeq   : LongInt;       { compteur des constantes en .data     }

{ Nom interne unique (table de hachage) : retourne son indice }
Function Intern(Const S : TMangled) : Integer;
Var
  H, I : LongInt;
Begin
  H := 5381;
  { BOGUE REEL CORRIGE (hachage djb2 : "Runtime error 215" a l'execution,
    chaines assez longues/nombreuses - ex. arrays.a58) : H*33 depasse
    l'intervalle signe 32 bits AVANT que le masque And $7FFFFFF ne le
    ramene dans les bornes - un debordement cyclique est le comportement
    VOULU de ce hachage (comme le hash non signe classique en C), donc on
    desactive explicitement la verification de depassement le temps de ce
    calcul au lieu de changer de type (le masque final garantit de toute
    facon un resultat positif et borne). }
  {$Q-}
  For I := 1 To Length(S) Do
    H := ((H * 33) + Ord(S[I])) And $7FFFFFF;
  {$Q+}
  H := H Mod NAME_HASH;
  While NameHash[H] >= 0 Do
  Begin
    If NameTab[NameHash[H]] = S Then
    Begin
      Intern := NameHash[H];
      Exit;
    End;
    H := (H + 1) Mod NAME_HASH;
  End;
  If NameCount >= MAX_NAMES Then
    FatalError('table des noms ASM pleine');
  NameTab[NameCount] := S;
  NameHash[H] := NameCount;
  Intern := NameCount;
  Inc(NameCount);
End;

Procedure CodeInit;
Var
  I : Integer;
Begin
  CodeCount   := 0;
  DeferCount  := 0;
  NameCount   := 0;
  AsmStrCount := 0;
  DataCount   := 0;
  TabEntCount := 0;
  LabelSeq    := 0;
  ConstSeq    := 0;
  For I := 0 To NAME_HASH - 1 Do
    NameHash[I] := -1;
End;

{ ---- Operandes ---- }

Function OpNone : TOperand;
Var
  O : TOperand;
Begin
  FillChar(O, SizeOf(O), 0);
  O.Sym := -1;
  OpNone := O;
End;

Function OpReg(R : TReg) : TOperand;
Var
  O : TOperand;
Begin
  O := OpNone;
  O.Kind := OK_REG;
  O.Reg  := R;
  OpReg := O;
End;

Function OpImm(V : LongInt) : TOperand;
Var
  O : TOperand;
Begin
  O := OpNone;
  O.Kind := OK_IMM;
  O.Imm  := V;
  OpImm := O;
End;

{ [Base + Disp] }
Function OpMem(Base : TReg; Disp : LongInt; Size : Byte) : TOperand;
Var
  O : TOperand;
Begin
  O := OpNone;
  O.Kind := OK_MEM;
  O.Base := Base;
  O.Imm  := Disp;
  O.Size := Size;
  OpMem := O;
End;

{ [Sym + Disp] : cellule en .data }
Function OpMemSym(Sym : Integer; Disp : LongInt; Size : Byte) : TOperand;
Var
  O : TOperand;
Begin
  O := OpNone;
  O.Kind := OK_MEM;
  O.Sym  := Sym;
  O.Imm  := Disp;
  O.Size := Size;
  OpMemSym := O;
End;

{ [Sym + Base + Index*Scale + Disp] }
Function OpMemIdx(Sym : Integer; Base, Index : TReg; Scale : Byte;
                  Disp : LongInt; Size : Byte) : TOperand;
Var
  O : TOperand;
Begin
  O := OpNone;
  O.Kind  := OK_MEM;
  O.Sym   := Sym;
  O.Base  := Base;
  O.Index := Index;
  O.Scale := Scale;
  O.Imm   := Disp;
  O.Size  := Size;
  OpMemIdx := O;
End;

Function OpLabel(Sym : Integer) : TOperand;
Var
  O : TOperand;
Begin
  O := OpNone;
  O.Kind := OK_LABEL;
  O.Sym  := Sym;
  OpLabel := O;
End;

Function OpOffset(Sym : Integer) : TOperand;
Var
  O : TOperand;
Begin
  O := OpNone;
  O.Kind := OK_OFFSET;
  O.Sym  := Sym;
  OpOffset := O;
End;

Function OpST(I : Integer) : TOperand;
Var
  O : TOperand;
Begin
  O := OpNone;
  O.Kind := OK_ST;
  O.Imm  := I;
  OpST := O;
End;

{ ---- Emission ---- }

Procedure Emit(Op : TOp; Const A, B : TOperand);
Begin
  If CodeCount >= MAX_CODE Then
    FatalError('programme trop long (code interne plein)');
  CodeTab[CodeCount].Op := Op;
  CodeTab[CodeCount].A  := A;
  CodeTab[CodeCount].B  := B;
  Inc(CodeCount);
End;

Procedure Emit0(Op : TOp);
Begin
  Emit(Op, OpNone, OpNone);
End;

Procedure Emit1(Op : TOp; Const A : TOperand);
Begin
  Emit(Op, A, OpNone);
End;

Procedure EmitLabel(Name : Integer);
Begin
  Emit(OP_LABEL, OpLabel(Name), OpNone);
End;

Function AsmStrAdd(Const S : TString) : Integer;
Begin
  If AsmStrCount >= MAX_ASMSTR Then
    FatalError('table des chaines ASM pleine');
  AsmStrs[AsmStrCount] := S;
  AsmStrAdd := AsmStrCount;
  Inc(AsmStrCount);
End;

Procedure EmitComment(Const S : TString);
Begin
  Emit(OP_COMMENT, OpImm(AsmStrAdd(S)), OpNone);
End;

Procedure EmitBlank;
Begin
  Emit0(OP_BLANK);
End;

{ Etiquette interne _A58L_NNNNN }
Function NewLabel : Integer;
Begin
  Inc(LabelSeq);
  NewLabel := Intern(MangleLabel(LabelSeq));
End;

{ Deplace CodeTab[Start .. CodeCount-1] a la fin de DeferTab : les
  procedures et les thunks sortent ainsi du flot du programme. }
Procedure MoveToDeferred(Start : LongInt);
Var
  I : LongInt;
Begin
  For I := Start To CodeCount - 1 Do
  Begin
    If DeferCount >= MAX_CODE Then
      FatalError('programme trop long (code differe plein)');
    DeferTab[DeferCount] := CodeTab[I];
    Inc(DeferCount);
  End;
  CodeCount := Start;
End;

{ ---- Donnees (.data) ---- }

Function DataNew(NameIdx : Integer; K : TDataKind) : Integer;
Begin
  If DataCount >= MAX_DATAITEMS Then
    FatalError('trop de donnees statiques');
  FillChar(DataTab[DataCount], SizeOf(TDataItem), 0);
  DataTab[DataCount].Name := NameIdx;
  DataTab[DataCount].Kind := K;
  DataTab[DataCount].Str  := -1;
  DataNew := DataCount;
  Inc(DataCount);
End;

{ Cellule de Size octets mise a zero }
Procedure DataAddZero(NameIdx : Integer; Size : LongInt);
Begin
  DataTab[DataNew(NameIdx, DK_ZERO)].Size := Size;
End;

{ Chaine litterale : retourne le nom du label ; deux chaines egales
  partagent la meme cellule. }
Function DataStr(Const S : TString) : Integer;
Var
  I, N : Integer;
Begin
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_STR) And
       (AsmStrs[DataTab[I].Str] = S) Then
    Begin
      DataStr := DataTab[I].Name;
      Exit;
    End;
  Inc(ConstSeq);
  N := Intern(A58_STR_PFX + ItoS(ConstSeq));
  I := DataNew(N, DK_STR);
  DataTab[I].Str  := AsmStrAdd(S);
  DataTab[I].Size := Length(S);
  DataStr := N;
End;

{ Constante entiere en memoire (argument par nom, par reference) }
Function DataInt(V : LongInt) : Integer;
Var
  I, N : Integer;
Begin
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_INT) And (DataTab[I].Lo = V) Then
    Begin
      DataInt := DataTab[I].Name;
      Exit;
    End;
  Inc(ConstSeq);
  N := Intern('_A58C_' + ItoS(ConstSeq));
  I := DataNew(N, DK_INT);
  DataTab[I].Lo   := V;
  DataTab[I].Size := 4;
  DataInt := N;
End;

{ Constante reelle (QWORD) }
Function DataReal(V : Double) : Integer;
Var
  I, N : Integer;
  B    : TDoubleBits;
Begin
  B.D := V;
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_REAL) And (DataTab[I].Lo = B.Lo) And
       (DataTab[I].Hi = B.Hi) Then
    Begin
      DataReal := DataTab[I].Name;
      Exit;
    End;
  Inc(ConstSeq);
  N := Intern('_A58C_' + ItoS(ConstSeq));
  I := DataNew(N, DK_REAL);
  DataTab[I].Lo   := B.Lo;
  DataTab[I].Hi   := B.Hi;
  DataTab[I].Size := 8;
  DataReal := N;
End;

{ Table d'adresses (switch) : Entries = indices de noms }
Procedure DataTable(NameIdx : Integer; Const Entries : Array Of Integer;
                    Count : Integer);
Var
  I, K : Integer;
Begin
  K := DataNew(NameIdx, DK_TABLE);
  DataTab[K].First := TabEntCount;
  DataTab[K].Count := Count;
  DataTab[K].Size  := 4 * Count;
  For I := 0 To Count - 1 Do
  Begin
    If TabEntCount >= MAX_TABENT Then
      FatalError('tables de switch trop grandes');
    TabEnt[TabEntCount] := Entries[I];
    Inc(TabEntCount);
  End;
End;

{ ---- Listing texte (MASM / ML.PAS) ---- }

Function RegName(R : TReg) : TString;
Begin
  Case R Of
    R_EAX : RegName := 'EAX';
    R_ECX : RegName := 'ECX';
    R_EDX : RegName := 'EDX';
    R_EBX : RegName := 'EBX';
    R_ESP : RegName := 'ESP';
    R_EBP : RegName := 'EBP';
    R_ESI : RegName := 'ESI';
    R_EDI : RegName := 'EDI';
    R_AL  : RegName := 'AL';
    R_CL  : RegName := 'CL';
    R_DL  : RegName := 'DL';
    R_BL  : RegName := 'BL';
    R_AX  : RegName := 'AX';
  Else
    RegName := '?';
  End;
End;

Function OpName(Op : TOp) : TString;
Begin
  Case Op Of
    OP_MOV: OpName := 'MOV';       OP_MOVZX: OpName := 'MOVZX';
    OP_LEA: OpName := 'LEA';       OP_PUSH: OpName := 'PUSH';
    OP_POP: OpName := 'POP';       OP_ADD: OpName := 'ADD';
    OP_SUB: OpName := 'SUB';       OP_IMUL: OpName := 'IMUL';
    OP_IDIV: OpName := 'IDIV';     OP_CDQ: OpName := 'CDQ';
    OP_NEG: OpName := 'NEG';       OP_NOT: OpName := 'NOT';
    OP_AND: OpName := 'AND';       OP_OR: OpName := 'OR';
    OP_XOR: OpName := 'XOR';       OP_CMP: OpName := 'CMP';
    OP_TEST: OpName := 'TEST';     OP_INC: OpName := 'INC';
    OP_DEC: OpName := 'DEC';       OP_SHR: OpName := 'SHR';
    OP_SAR: OpName := 'SAR';
    OP_SETE: OpName := 'SETE';     OP_SETNE: OpName := 'SETNE';
    OP_SETL: OpName := 'SETL';     OP_SETLE: OpName := 'SETLE';
    OP_SETG: OpName := 'SETG';     OP_SETGE: OpName := 'SETGE';
    OP_SETA: OpName := 'SETA';     OP_SETAE: OpName := 'SETAE';
    OP_SETB: OpName := 'SETB';     OP_SETBE: OpName := 'SETBE';
    OP_JMP: OpName := 'JMP';       OP_JE: OpName := 'JE';
    OP_JNE: OpName := 'JNE';       OP_JL: OpName := 'JL';
    OP_JLE: OpName := 'JLE';       OP_JG: OpName := 'JG';
    OP_JGE: OpName := 'JGE';       OP_JA: OpName := 'JA';
    OP_JAE: OpName := 'JAE';       OP_JB: OpName := 'JB';
    OP_JBE: OpName := 'JBE';       OP_JS: OpName := 'JS';
    OP_CALL: OpName := 'CALL';     OP_RET: OpName := 'RET';
    OP_REP_STOSD: OpName := 'REP STOSD';
    OP_FLD: OpName := 'FLD';       OP_FST: OpName := 'FST';
    OP_FSTP: OpName := 'FSTP';     OP_FILD: OpName := 'FILD';
    OP_FADD: OpName := 'FADD';     OP_FSUB: OpName := 'FSUB';
    OP_FSUBR: OpName := 'FSUBR';   OP_FMUL: OpName := 'FMUL';
    OP_FDIV: OpName := 'FDIV';     OP_FDIVR: OpName := 'FDIVR';
    OP_FCHS: OpName := 'FCHS';     OP_FABS: OpName := 'FABS';
    OP_FSQRT: OpName := 'FSQRT';   OP_FSIN: OpName := 'FSIN';
    OP_FCOS: OpName := 'FCOS';     OP_FPATAN: OpName := 'FPATAN';
    OP_FYL2X: OpName := 'FYL2X';   OP_FLDLN2: OpName := 'FLDLN2';
    OP_FLD1: OpName := 'FLD1';     OP_FLDZ: OpName := 'FLDZ';
    OP_FXCH: OpName := 'FXCH';     OP_FCOM: OpName := 'FCOM';
    OP_FCOMP: OpName := 'FCOMP';   OP_FNSTSW: OpName := 'FNSTSW';
    OP_SAHF: OpName := 'SAHF';
    OP_DIV: OpName := 'DIV';       OP_JNS: OpName := 'JNS';
    OP_SHL: OpName := 'SHL';       OP_FTST: OpName := 'FTST';
    OP_FRNDINT: OpName := 'FRNDINT';  OP_F2XM1: OpName := 'F2XM1';
    OP_FSCALE: OpName := 'FSCALE';    OP_FLDL2E: OpName := 'FLDL2E';
    OP_FADDP: OpName := 'FADDP';   OP_FSUBP: OpName := 'FSUBP';
    OP_FMULP: OpName := 'FMULP';   OP_FDIVP: OpName := 'FDIVP';
    OP_FISTP: OpName := 'FISTP';   OP_FNSTCW: OpName := 'FNSTCW';
    OP_FLDCW: OpName := 'FLDCW';
  Else
    OpName := '?';
  End;
End;

Function SizePtr(Size : Byte) : TString;
Begin
  Case Size Of
    1 : SizePtr := 'BYTE PTR ';
    2 : SizePtr := 'WORD PTR ';
    4 : SizePtr := 'DWORD PTR ';
    8 : SizePtr := 'QWORD PTR ';
  Else
    SizePtr := '';
  End;
End;

Function SignedStr(V : LongInt) : TString;
Begin
  If V >= 0 Then
    SignedStr := '+' + ItoS(V)
  Else
    SignedStr := ItoS(V);
End;

Function OperandText(Const O : TOperand; Op : TOp) : TString;
Var
  S : TString;
Begin
  S := '';
  Case O.Kind Of
    OK_REG    : S := RegName(O.Reg);
    OK_IMM    : S := ItoS(O.Imm);
    OK_LABEL  : S := NameTab[O.Sym];
    OK_ST     : S := 'ST(' + ItoS(O.Imm) + ')';
    OK_OFFSET :
      Begin
        S := 'OFFSET ' + NameTab[O.Sym];
        If O.Imm <> 0 Then S := S + SignedStr(O.Imm);
      End;
    OK_MEM    :
      Begin
        If Op <> OP_LEA Then S := SizePtr(O.Size);
        S := S + '[';
        If O.Sym >= 0 Then S := S + NameTab[O.Sym];
        If O.Base <> R_NONE Then
        Begin
          If O.Sym >= 0 Then S := S + '+';
          S := S + RegName(O.Base);
        End;
        If O.Index <> R_NONE Then
        Begin
          If (O.Sym >= 0) Or (O.Base <> R_NONE) Then S := S + '+';
          S := S + RegName(O.Index) + '*' + ItoS(O.Scale);
        End;
        If O.Imm <> 0 Then S := S + SignedStr(O.Imm);
        S := S + ']';
      End;
  End;
  OperandText := S;
End;

Function InstrText(Const I : TInstr) : TString;
Var
  S : TString;
Begin
  S := '        ' + OpName(I.Op);
  If I.A.Kind <> OK_NONE Then
  Begin
    While Length(S) < 16 Do S := S + ' ';
    If S[Length(S)] <> ' ' Then S := S + ' ';
    S := S + OperandText(I.A, I.Op);
    If I.B.Kind <> OK_NONE Then
      S := S + ', ' + OperandText(I.B, I.Op);
  End;
  InstrText := S;
End;

{ Texte d'une chaine en DB : 'abc', 13, 10 }
Function DbText(Const S : TString) : TString;
Var
  R      : TString;
  I      : Integer;
  InQ    : Boolean;
Begin
  R   := '';
  InQ := False;
  For I := 1 To Length(S) Do
  Begin
    If (S[I] >= ' ') And (S[I] <= '~') And (S[I] <> '''') Then
    Begin
      If Not InQ Then
      Begin
        If R <> '' Then R := R + ', ';
        R := R + '''';
        InQ := True;
      End;
      R := R + S[I];
    End
    Else
    Begin
      If InQ Then
      Begin
        R := R + '''';
        InQ := False;
      End;
      If R <> '' Then R := R + ', ';
      R := R + ItoS(Ord(S[I]));
    End;
  End;
  If InQ Then R := R + '''';
  If R = '' Then R := '0';
  DbText := R;
End;

Function HexDword(V : LongInt) : TString;
Const
  Digits : String[16] = '0123456789ABCDEF';
Var
  R : TString;
  I : Integer;
  W : LongInt;
Begin
  R := '';
  W := V;
  For I := 1 To 8 Do
  Begin
    R := Digits[(W And 15) + 1] + R;
    W := (W Shr 4) And $0FFFFFFF;
  End;
  HexDword := '0' + R + 'h';
End;

Procedure WriteInstrList(Var F : Text; Const Tab : Array Of TInstr;
                         Count : LongInt);
Var
  I : LongInt;
Begin
  For I := 0 To Count - 1 Do
    Case Tab[I].Op Of
      OP_NOP     : ;
      OP_LABEL   : WriteLn(F, NameTab[Tab[I].A.Sym], ':');
      OP_COMMENT : WriteLn(F, '        ; ', AsmStrs[Tab[I].A.Imm]);
      OP_BLANK   : WriteLn(F);
    Else
      WriteLn(F, InstrText(Tab[I]));
    End;
End;

{ Ecrit le listing .ASM (ML.PAS / MASM 32 bits) }
Procedure WriteListing(Const FileName : TString);
Var
  F    : Text;
  I, J : Integer;
  Name : TString;
Begin
  Assign(F, FileName);
  Rewrite(F);
  If IOResult <> 0 Then
    FatalError('impossible de creer ' + FileName);
  NoteOutput(FileName);
  WriteLn(F, '; ', FileName, ' - genere par AL58CW32 ',
          AL58CW32_VERSION, ' a partir de ', Opts.SrcFile);
  WriteLn(F);
  WriteLn(F, '.386');
  WriteLn(F, '.MODEL FLAT');
  WriteLn(F);
  WriteLn(F, 'INCLUDELIB kernel32.lib');
  WriteLn(F, 'EXTERN GetStdHandle:PROC');
  WriteLn(F, 'EXTERN WriteFile:PROC');
  WriteLn(F, 'EXTERN ReadFile:PROC');
  WriteLn(F, 'EXTERN ExitProcess:PROC');
  WriteLn(F, 'EXTERN GetProcessHeap:PROC');
  WriteLn(F, 'EXTERN HeapAlloc:PROC');
  WriteLn(F);
  WriteLn(F, '.DATA');
  For I := 0 To DataCount - 1 Do
  Begin
    Name := NameTab[DataTab[I].Name];
    While Length(Name) < 16 Do Name := Name + ' ';
    Case DataTab[I].Kind Of
      DK_ZERO  :
        WriteLn(F, Name, ' DD ', (DataTab[I].Size + 3) Div 4, ' DUP(0)');
      DK_STR   :
        WriteLn(F, Name, ' DB ', DbText(AsmStrs[DataTab[I].Str]), ', 0');
      DK_INT   :
        WriteLn(F, Name, ' DD ', DataTab[I].Lo);
      DK_REAL  :
        WriteLn(F, Name, ' DD ', HexDword(DataTab[I].Lo), ', ',
                HexDword(DataTab[I].Hi));
      DK_TABLE :
        Begin
          Write(F, Name, ' DD ');
          For J := 0 To DataTab[I].Count - 1 Do
          Begin
            If J > 0 Then Write(F, ', ');
            Write(F, NameTab[TabEnt[DataTab[I].First + J]]);
          End;
          WriteLn(F);
        End;
    End;
  End;
  WriteLn(F);
  WriteLn(F, '.CODE');
  WriteInstrList(F, CodeTab, CodeCount);
  WriteLn(F);
  WriteInstrList(F, DeferTab, DeferCount);
  WriteLn(F);
  WriteLn(F, 'END ', A58_MAIN_NAME);
  Close(F);
  If IOResult <> 0 Then
    FatalError('erreur d''ecriture de ' + FileName);
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
  CallCount  : LongInt;      { appels de procedure ou fonction      }
  ThunkCount : LongInt;      { thunks d'arguments par nom           }
  IOCount    : LongInt;      { instructions write / read            }
  IntrinCount: LongInt;      { appels d'intrinseques non repliees   }
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

{ write, writeln, read, readln : entrees/sorties (TODO 16) }
Function IsIOName(Const Name : TString) : Boolean;
Var
  K : TString;
Begin
  K := UpCaseStr(Name);
  IsIOName := (K = 'WRITE') Or (K = 'WRITELN') Or (K = 'READ') Or
              (K = 'READLN');
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
Var
  SyncLine, SyncCol : Integer;   { position du dernier arret sur un mot-cle }

Function AtSyncKw : Boolean;
Begin
  AtSyncKw := AtKw('begin') Or AtKw('for') Or AtKw('if') Or
              AtKw('procedure');
End;

Procedure ParserSync;
Begin
  { garantie de progression : un arret repete sur le meme mot-cle est
    franchi }
  If AtSyncKw And (CurToken.Line = SyncLine) And
     (CurToken.Col = SyncCol) Then
    ParserAdvance;
  While Not (AtEOF Or AtPunct(';') Or AtKw('end') Or AtSyncKw) Do
    ParserAdvance;
  SyncLine := CurToken.Line;
  SyncCol  := CurToken.Col;
End;

Procedure ParseItem; Forward;
Procedure ParseStatement; Forward;
Procedure ParseIO(Const Tok : TToken); Forward;
Procedure GenDeclareData(S : Integer); Forward;
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

  TIntrinsic = (
    IN_ABS, IN_SIGN, IN_ENTIER, IN_SQRT, IN_SIN, IN_COS, IN_ARCTAN,
    IN_LN, IN_EXP, IN_MAX, IN_MIN, IN_MOD, IN_DIV, IN_NONE
  );

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
    EX_INTRIN,      { fonction intrinseque (IntVal = TIntrinsic)  }
    EX_INDEX,       { Sym[L...] : element de tableau (IntVal = nb d indices) }
    EX_LIST,        { liste d indices : L = expression, R = suivant }
    EX_LABEL,       { designateur : etiquette (Sym)               }
    EX_SWITCHREF,   { designateur : Sym[L] (element de switch)    }
    EX_CALL,        { appel de Sym ; L = liste des arguments      }
    EX_WRITE,       { write / writeln : L = arguments, Flag = CR LF }
    EX_READ         { read / readln : L = variables, Flag = fin de ligne }
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
Function ExprCoerceCtx(N, Dest : Integer; Var Conv : TConv;
                       Line, Col : Integer; Const Ctx : TString)
         : Boolean;
Begin
  ExprCoerceCtx := False;
  Conv := TypeConversion(ExprTab[N].Typ, Dest);
  If Conv = CV_ERROR Then
  Begin
    ErrorAt(Line, Col, Ctx + ' incompatible: ' +
            TypeName(ExprTab[N].Typ) + ' vers ' + TypeName(Dest));
    Exit;
  End;
  If Conv = CV_REAL_TO_INT Then
    WarnAt(Line, Col, 'real converti en integer: arrondi au plus proche')
  Else If Conv = CV_INT_TO_BOOL Then
    WarnAt(Line, Col, 'integer converti en Boolean (<> 0)')
  Else If (ExprTab[N].Typ = TY_IDX_BOOLEAN) And (Dest = TY_IDX_INTEGER) Then
    WarnAt(Line, Col, 'Boolean converti en integer (0 ou 1)');
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
  ExprCoerceCtx := True;
End;

{ Affectation : voir ExprCoerceCtx }
Function ExprCoerce(N, Dest : Integer; Var Conv : TConv;
                    Line, Col : Integer) : Boolean;
Begin
  ExprCoerce := ExprCoerceCtx(N, Dest, Conv, Line, Col, 'affectation');
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

Function ArgClassName(C : TArgClass) : TString;
Begin
  Case C Of
    AC_VALUE    : ArgClassName := 'value';
    AC_ARRAY    : ArgClassName := 'array/ref';
    AC_CONST    : ArgClassName := 'name/const';
    AC_REF      : ArgClassName := 'name/ref';
    AC_FORWARD  : ArgClassName := 'name/forward';
    AC_THUNK    : ArgClassName := 'name/thunk';
    AC_THUNK_RW : ArgClassName := 'name/thunk-rw';
  End;
End;

{ Sous-script constants : tous les indices du tableau sont des entiers
  constants (l'adresse de l'element ne change donc jamais). }
Function IndexIsFixed(E : Integer) : Boolean;
Var
  I : Integer;
Begin
  IndexIsFixed := False;
  If ExprTab[E].Flag Then Exit;             { controle de bornes requis }
  I := ExprTab[E].L;
  While I >= 0 Do
  Begin
    If ExprTab[ExprTab[I].L].Kind <> EX_INT Then Exit;
    I := ExprTab[I].R;
  End;
  IndexIsFixed := True;
End;

{ Argument d'appel pour le parametre P. Un parametre tableau recoit le
  nom d'un tableau ; un parametre value, une expression convertie vers
  son type ; un parametre par nom, une expression (thunk au TODO 15)
  dont le type doit etre convertible vers celui du parametre. Item.Flag
  indique un argument qui est une variable ou un element de tableau du
  bon type : il pourra etre passe par reference au lieu d'un thunk. }
Function ParseCallArg(P : Integer; Const ProcName : TString;
                      Var Item : Integer) : Boolean;
Var
  Tok       : TToken;
  E, S      : Integer;
  Conv      : TConv;
  Line, Col : Integer;
  Cls       : TArgClass;
  IsLv      : Boolean;
Begin
  ParseCallArg := False;
  Item := -1;
  Line := CurToken.Line;
  Col  := CurToken.Col;
  Conv := CV_NONE;
  If SymTab[P].TypeIdx = TY_IDX_ARRAY Then
  Begin
    Tok := CurToken;
    If Tok.Kind <> TK_IDENT Then
    Begin
      ParseError('nom de tableau attendu pour le parametre ' +
                 SymTab[P].Name);
      Exit;
    End;
    ParserAdvance;
    S := SymFind(Tok.Val);
    If (S < 0) Or (Not SymIsArrayLike(S)) Then
    Begin
      ErrorAt(Tok.Line, Tok.Col, 'tableau attendu pour le parametre ' +
              SymTab[P].Name + ': ' + Tok.Val);
      Exit;
    End;
    If SymTab[S].ElemType <> SymTab[P].ElemType Then
    Begin
      ErrorAt(Tok.Line, Tok.Col, 'tableau ' + Tok.Val + ' de ' +
              TypeName(SymTab[S].ElemType) + ' au lieu de ' +
              TypeName(SymTab[P].ElemType));
      Exit;
    End;
    E := ExprNew(EX_VAR, TY_IDX_ARRAY, Tok.Line, Tok.Col);
    ExprTab[E].Sym := S;
  End
  Else If SymTab[P].TypeIdx In [TY_IDX_PROCEDURE, TY_IDX_SWITCH,
                                TY_IDX_LABEL] Then
  Begin
    ErrorAt(Line, Col, 'parametre ' + SymTab[P].Name + ' de ' +
            ProcName + ': procedure, switch ou etiquette en parametre ' +
            'non supporte');
    Exit;
  End
  Else
  Begin
    E := ParseExprPrec(1);
    If E < 0 Then Exit;
    If Not ExprCoerceCtx(E, SymTab[P].TypeIdx, Conv, Line, Col,
                         'argument') Then Exit;
  End;
  { mode de transmission de l'argument }
  If SymTab[P].TypeIdx = TY_IDX_ARRAY Then
    Cls := AC_ARRAY
  Else If SymTab[P].Kind = SK_PARAM_VALUE Then
    Cls := AC_VALUE
  Else
  Begin
    IsLv := ExprTab[E].Kind In [EX_VAR, EX_INDEX];
    If SymTab[P].IsWritten Then
    Begin
      If Not IsLv Then
      Begin
        ErrorAt(Line, Col, 'argument non assignable: ' + ProcName +
                ' modifie le parametre ' + SymTab[P].Name);
        Exit;
      End;
      If Conv <> CV_NONE Then
      Begin
        ErrorAt(Line, Col, 'argument de type ' +
                TypeName(ExprTab[E].Typ) + ': ' + ProcName +
                ' modifie le parametre ' + SymTab[P].Name + ' (' +
                TypeName(SymTab[P].TypeIdx) + '), meme type exige');
        Exit;
      End;
      { l'ecriture traverse l'appelant : son parametre par nom aussi }
      If (ExprTab[E].Kind = EX_VAR) And
         (SymTab[ExprTab[E].Sym].Kind = SK_PARAM_NAME) Then
        SymTab[ExprTab[E].Sym].IsWritten := True;
    End;
    If ExprTab[E].Kind In [EX_INT, EX_REAL, EX_BOOL] Then
      Cls := AC_CONST
    Else If (ExprTab[E].Kind = EX_VAR) And (Conv = CV_NONE) Then
    Begin
      If SymTab[ExprTab[E].Sym].Kind = SK_PARAM_NAME Then
        Cls := AC_FORWARD
      Else
        Cls := AC_REF;
    End
    Else If (ExprTab[E].Kind = EX_INDEX) And (Conv = CV_NONE) And
            IndexIsFixed(E) Then
      Cls := AC_REF
    Else If IsLv And SymTab[P].IsWritten Then
      Cls := AC_THUNK_RW
    Else
      Cls := AC_THUNK;
  End;

  Item := ExprNew(EX_LIST, ExprTab[E].Typ, Line, Col);
  ExprTab[Item].L      := E;
  ExprTab[Item].Conv   := Conv;
  ExprTab[Item].IntVal := Ord(Cls);
  ExprTab[Item].Flag   := (Cls = AC_REF);
  If Cls In [AC_THUNK, AC_THUNK_RW] Then
  Begin
    { le thunk est emis par le generateur au moment de l'appel : il
      evalue (ou localise) l'argument dans le contexte de l'appelant }
    ExprTab[Item].StrIdx :=
      ExprAddStr(UniqueMangle(MangleThunk(ProcName, SymTab[P].Name)));
    Inc(ThunkCount);
  End;
  ParseCallArg := True;
End;

{ nom(arg, arg...) ou nom (sans parentheses) : appel de la procedure
  ou fonction S. Tok = le nom, deja consomme. Le nombre d'arguments
  est verifie. Valeur : le type de retour d'une fonction, ou le type
  procedure (aucune valeur). Convention d'appel :
    - arguments empiles de droite a gauche, puis le lien statique
      pour une procedure declaree dans une autre procedure
    - CALL, la procedure nettoie la pile (RET n, n = ParamBytes)
    - resultat dans EAX (integer, Boolean) ou ST(0) (real) }
Function ParseCall(Const Tok : TToken; S : Integer) : Integer;
Var
  Head, Tail, Item, Expected, N, Node : Integer;
  Bad                                  : Boolean;
Begin
  ParseCall := -1;
  Expected := SymTab[S].ParamCount;
  Head := -1;
  Tail := -1;
  N    := 0;
  Bad  := False;
  If AtPunct('(') Then
  Begin
    ParserAdvance;
    If Not AtPunct(')') Then
      Repeat
        Inc(N);
        If N <= Expected Then
        Begin
          If ParseCallArg(SymTab[S].ParamSym[N], SymTab[S].Name,
                          Item) Then
          Begin
            If Head < 0 Then Head := Item Else ExprTab[Tail].R := Item;
            Tail := Item;
          End
          Else
            Bad := True;
        End
        Else
        Begin
          If N = Expected + 1 Then
            ErrorAt(CurToken.Line, CurToken.Col, 'trop d''arguments ' +
                    'pour ' + SymTab[S].Name + ' (' + ItoS(Expected) +
                    ' attendu(s))');
          Bad := True;
          If ParseExprPrec(1) < 0 Then ;
        End;
        If AtPunct(',') Then
          ParserAdvance
        Else
          Break;
      Until False;
    ExpectPunct(')');
  End;
  If (N < Expected) Then
  Begin
    ErrorAt(Tok.Line, Tok.Col, 'appel de ' + Tok.Val + ': ' + ItoS(N) +
            ' argument(s) au lieu de ' + ItoS(Expected));
    Bad := True;
  End;
  If Bad Then Exit;
  Inc(CallCount);
  If SymTab[S].Kind = SK_FUNC Then
    Node := ExprNew(EX_CALL, SymTab[S].TypeIdx, Tok.Line, Tok.Col)
  Else
    Node := ExprNew(EX_CALL, TY_IDX_PROCEDURE, Tok.Line, Tok.Col);
  ExprTab[Node].Sym    := S;
  ExprTab[Node].L      := Head;
  ExprTab[Node].IntVal := N;
  ParseCall := Node;
End;

{ ---- Fonctions intrinseques (TODO 17) ----------------------------- }

Function IntrinsicName(I : TIntrinsic) : TString;
Begin
  Case I Of
    IN_ABS    : IntrinsicName := 'abs';
    IN_SIGN   : IntrinsicName := 'sign';
    IN_ENTIER : IntrinsicName := 'entier';
    IN_SQRT   : IntrinsicName := 'sqrt';
    IN_SIN    : IntrinsicName := 'sin';
    IN_COS    : IntrinsicName := 'cos';
    IN_ARCTAN : IntrinsicName := 'arctan';
    IN_LN     : IntrinsicName := 'ln';
    IN_EXP    : IntrinsicName := 'exp';
    IN_MAX    : IntrinsicName := 'max';
    IN_MIN    : IntrinsicName := 'min';
    IN_MOD    : IntrinsicName := 'mod';
    IN_DIV    : IntrinsicName := 'div';
  Else
    IntrinsicName := '?';
  End;
End;

{ Intrinseque designe par un nom (IN_NONE si ce n'en est pas un) ;
  une procedure du programme de meme nom reste prioritaire. }
Function FindIntrinsic(Const Name : TString) : TIntrinsic;
Var
  I : TIntrinsic;
  K : TString;
Begin
  K := StrLower(Name);
  FindIntrinsic := IN_NONE;
  For I := IN_ABS To IN_DIV Do
    If IntrinsicName(I) = K Then
    Begin
      FindIntrinsic := I;
      Exit;
    End;
End;

Function IntrinsicArgc(I : TIntrinsic) : Integer;
Begin
  If I In [IN_MAX, IN_MIN, IN_MOD, IN_DIV] Then
    IntrinsicArgc := 2
  Else
    IntrinsicArgc := 1;
End;

{ Racine carree entiere (plancher) }
Function IntSqrt(V : LongInt) : LongInt;
Var
  R : TWide;
Begin
  R := Trunc(Sqrt(V));
  While R * R > V Do Dec(R);
  While (R + 1) * (R + 1) <= V Do Inc(R);
  IntSqrt := R;
End;

{ nom(arg) ou nom(a, b) : fonction intrinseque I, Tok = le nom.
  Resultat : abs, max, min suivent le type des arguments ; sign et
  entier donnent un integer ; sqrt suit son argument (racine entiere
  pour un integer) ; sin, cos, arctan, ln, exp donnent un real (x87) ;
  mod et div (forme fonction) exigent des entiers. Les appels dont tous
  les arguments sont constants sont calcules a la compilation. }
Function ParseIntrinsic(Const Tok : TToken; I : TIntrinsic) : Integer;
Var
  Args           : Array[1..2] Of Integer;
  Argc, Expected : Integer;
  K, Res, Target : Integer;
  E, Node, Item  : Integer;
  Head, Tail     : Integer;
  Conv           : TConv;
  Bad, AllConst  : Boolean;
  IsRealArg      : Boolean;
  D1, D2, RV     : Double;
  IV, I1, I2     : LongInt;
  Err            : TString;
Begin
  ParseIntrinsic := -1;
  Expected := IntrinsicArgc(I);
  Argc := 0;
  Bad  := False;
  Args[1] := -1;
  Args[2] := -1;
  If Not AtPunct('(') Then
  Begin
    ParseError('''('' attendu apres ' + Tok.Val);
    Exit;
  End;
  ParserAdvance;
  If Not AtPunct(')') Then
    Repeat
      E := ParseExprPrec(1);
      Inc(Argc);
      If Argc <= 2 Then Args[Argc] := E;
      If E < 0 Then Bad := True;
      If AtPunct(',') Then
        ParserAdvance
      Else
        Break;
    Until False;
  ExpectPunct(')');
  If Argc <> Expected Then
  Begin
    ErrorAt(Tok.Line, Tok.Col, Tok.Val + ': ' + ItoS(Expected) +
            ' argument(s) attendu(s), ' + ItoS(Argc) + ' trouve(s)');
    Exit;
  End;
  If Bad Then Exit;
  For K := 1 To Expected Do
    If Not TypeIsArith(ExprTab[Args[K]].Typ) Then
    Begin
      ErrorAt(Tok.Line, Tok.Col, Tok.Val + ': argument numerique ' +
              'attendu (type: ' + TypeName(ExprTab[Args[K]].Typ) + ')');
      Exit;
    End;

  { type du resultat }
  IsRealArg := ExprTab[Args[1]].Typ = TY_IDX_REAL;
  Case I Of
    IN_ABS    : Res := TypeArith(ExprTab[Args[1]].Typ, ExprTab[Args[1]].Typ);
    IN_SIGN,
    IN_ENTIER : Res := TY_IDX_INTEGER;
    IN_SQRT   : If IsRealArg Then Res := TY_IDX_REAL
                Else Res := TY_IDX_INTEGER;
    IN_SIN, IN_COS, IN_ARCTAN, IN_LN, IN_EXP : Res := TY_IDX_REAL;
    IN_MAX, IN_MIN : Res := TypeArith(ExprTab[Args[1]].Typ,
                                      ExprTab[Args[2]].Typ);
  Else
    Res := TY_IDX_INTEGER;
  End;
  If I In [IN_MOD, IN_DIV] Then
    If (ExprTab[Args[1]].Typ = TY_IDX_REAL) Or
       (ExprTab[Args[2]].Typ = TY_IDX_REAL) Then
    Begin
      ErrorAt(Tok.Line, Tok.Col, Tok.Val + ' demande des operandes ' +
              'entiers');
      Exit;
    End;

  { repliement : tous les arguments sont des constantes }
  AllConst := True;
  For K := 1 To Expected Do
    If Not ExprIsNumConst(Args[K]) Then AllConst := False;
  If AllConst Then
  Begin
    Err := '';
    IV  := 0;
    RV  := 0;
    D1  := ExprNumReal(Args[1]);
    I1  := ExprTab[Args[1]].IntVal;
    D2  := 0;
    I2  := 0;
    If Expected = 2 Then
    Begin
      D2 := ExprNumReal(Args[2]);
      I2 := ExprTab[Args[2]].IntVal;
    End;
    Case I Of
      IN_ABS:
        If Res = TY_IDX_REAL Then RV := Abs(D1) Else IV := Abs(I1);
      IN_SIGN:
        If D1 > 0 Then IV := 1 Else If D1 < 0 Then IV := -1 Else IV := 0;
      IN_ENTIER:
        If ExprTab[Args[1]].Kind = EX_REAL Then
        Begin
          If Abs(D1) >= 2147483647.0 Then
            Err := 'entier: valeur hors de l''intervalle integer'
          Else
          Begin
            RV := Int(D1);
            If D1 < RV Then RV := RV - 1;
            IV := Trunc(RV);
          End;
        End
        Else
          IV := I1;
      IN_SQRT:
        If D1 < 0 Then
          Err := 'sqrt: argument negatif'
        Else If Res = TY_IDX_REAL Then
          RV := Sqrt(D1)
        Else
          IV := IntSqrt(I1);
      IN_SIN:    RV := Sin(D1);
      IN_COS:    RV := Cos(D1);
      IN_ARCTAN: RV := ArcTan(D1);
      IN_LN:
        If D1 <= 0 Then Err := 'ln: argument non positif'
        Else RV := Ln(D1);
      IN_EXP:
        If D1 > 700 Then Err := 'exp: debordement'
        Else RV := Exp(D1);
      IN_MAX:
        If Res = TY_IDX_REAL Then
        Begin
          If D1 >= D2 Then RV := D1 Else RV := D2;
        End
        Else If I1 >= I2 Then IV := I1 Else IV := I2;
      IN_MIN:
        If Res = TY_IDX_REAL Then
        Begin
          If D1 <= D2 Then RV := D1 Else RV := D2;
        End
        Else If I1 <= I2 Then IV := I1 Else IV := I2;
      IN_MOD: FoldIntBin('mod', I1, I2, IV, Err);
      IN_DIV: FoldIntBin('div', I1, I2, IV, Err);
    End;
    If (Err = '') And (Res = TY_IDX_REAL) And RealBad(RV) Then
      Err := Tok.Val + ': debordement reel';
    If Err <> '' Then
    Begin
      ErrorAt(Tok.Line, Tok.Col, Err);
      Exit;
    End;
    Node := Args[1];
    ExprTab[Node].Line := Tok.Line;
    ExprTab[Node].Col  := Tok.Col;
    If Res = TY_IDX_REAL Then
    Begin
      ExprTab[Node].Kind    := EX_REAL;
      ExprTab[Node].Typ     := TY_IDX_REAL;
      ExprTab[Node].RealVal := RV;
    End
    Else
    Begin
      ExprTab[Node].Kind   := EX_INT;
      ExprTab[Node].Typ    := TY_IDX_INTEGER;
      ExprTab[Node].IntVal := IV;
    End;
    Inc(FoldCount);
    ParseIntrinsic := Node;
    Exit;
  End;

  { entier d'un integer : identite }
  If (I = IN_ENTIER) And (ExprTab[Args[1]].Typ = TY_IDX_INTEGER) Then
  Begin
    ParseIntrinsic := Args[1];
    Exit;
  End;

  { noeud d'appel du runtime ; chaque argument est converti vers le
    type de calcul (real pour les fonctions transcendantes et le
    resultat de max / min) }
  Head := -1;
  Tail := -1;
  For K := 1 To Expected Do
  Begin
    If I In [IN_SIN, IN_COS, IN_ARCTAN, IN_LN, IN_EXP] Then
      Target := TY_IDX_REAL
    Else If I In [IN_MAX, IN_MIN] Then
      Target := Res
    Else If ExprTab[Args[K]].Typ = TY_IDX_REAL Then
      Target := TY_IDX_REAL
    Else
      Target := TY_IDX_INTEGER;
    Conv := TypeConversion(ExprTab[Args[K]].Typ, Target);
    Item := ExprNew(EX_LIST, Target, Tok.Line, Tok.Col);
    ExprTab[Item].L    := Args[K];
    ExprTab[Item].Conv := Conv;
    If Head < 0 Then Head := Item Else ExprTab[Tail].R := Item;
    Tail := Item;
  End;
  Node := ExprNew(EX_INTRIN, Res, Tok.Line, Tok.Col);
  ExprTab[Node].IntVal := Ord(I);
  ExprTab[Node].L      := Head;
  Inc(IntrinCount);
  ParseIntrinsic := Node;
End;

Function ParsePrimary : Integer;
Var
  N, S : Integer;
  Tok  : TToken;
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
        { mod(a, b) et div(a, b) : forme fonction }
        ParserAdvance;
        If AtPunct('(') Then
        Begin
          If Tok.Val = 'mod' Then
            ParsePrimary := ParseIntrinsic(Tok, IN_MOD)
          Else
            ParsePrimary := ParseIntrinsic(Tok, IN_DIV);
        End
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
        S := SymFind(Tok.Val);
        { procedure ou fonction declaree : appel (le nom de la
          fonction en cours suivi de := est une cible, pas un appel) }
        If (S >= 0) And (SymTab[S].Kind In [SK_PROC, SK_FUNC]) And
           Not ((S = SymCurProc) And AtOp(':=')) Then
        Begin
          ParsePrimary := ParseCall(Tok, S);
          Exit;
        End;
        If AtPunct('(') Then
        Begin
          If S >= 0 Then
            ErrorAt(Tok.Line, Tok.Col, 'ce n''est pas une procedure: ' +
                    Tok.Val)
          Else If FindIntrinsic(Tok.Val) <> IN_NONE Then
            ParsePrimary := ParseIntrinsic(Tok, FindIntrinsic(Tok.Val))
          Else
            ErrorAt(Tok.Line, Tok.Col, 'procedure ou fonction ' +
                    'inconnue: ' + Tok.Val);
          Exit;
        End;
        If S < 0 Then
        Begin
          S := SymImplicit(Tok.Val, Tok.Line, Tok.Col);
          GenDeclareData(S);
        End;
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
  Pad  : TString;
  I, K : Integer;
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
    EX_INTRIN : WriteLn('intrinsic ',
                        IntrinsicName(TIntrinsic(ExprTab[N].IntVal)),
                        ' : ', TypeName(ExprTab[N].Typ));
    EX_INDEX  : Begin
                  Write('index ', SymTab[ExprTab[N].Sym].Name, '[',
                        ExprTab[N].IntVal, '] : ',
                        TypeName(ExprTab[N].Typ));
                  If ExprTab[N].Flag Then
                    WriteLn(' (controle de bornes)')
                  Else
                    WriteLn;
                End;
    EX_WRITE  : Begin
                  Write('write');
                  If ExprTab[N].Flag Then Write('ln');
                  WriteLn(' (', ExprTab[N].IntVal, ' argument(s))');
                End;
    EX_READ   : Begin
                  Write('read');
                  If ExprTab[N].Flag Then Write('ln');
                  WriteLn(' (', ExprTab[N].IntVal, ' variable(s))');
                End;
    EX_LIST   : WriteLn('list');
    EX_LABEL  : WriteLn('label ', SymTab[ExprTab[N].Sym].Name);
    EX_SWITCHREF : WriteLn('switch ', SymTab[ExprTab[N].Sym].Name, '[]');
    EX_CALL   : WriteLn('call ', SymTab[ExprTab[N].Sym].Name, '(',
                        ExprTab[N].IntVal, ') : ',
                        TypeName(ExprTab[N].Typ));
  End;
  If ExprTab[N].Kind = EX_CALL Then
  Begin
    I := ExprTab[N].L;
    K := 0;
    While I >= 0 Do
    Begin
      Inc(K);
      Write(Pad, '  arg ', K, ' ');
      Write(ArgClassName(TArgClass(ExprTab[I].IntVal)));
      If TArgClass(ExprTab[I].IntVal) In [AC_THUNK, AC_THUNK_RW] Then
        Write(' ', ExprStrTab[ExprTab[I].StrIdx]);
      WriteLn(' ', ConvName(ExprTab[I].Conv));
      ExprDump(ExprTab[I].L, Depth + 2);
      I := ExprTab[I].R;
    End;
    Exit;
  End;
  If ExprTab[N].Kind In [EX_WRITE, EX_READ, EX_INTRIN] Then
  Begin
    I := ExprTab[N].L;
    While I >= 0 Do
    Begin
      ExprDump(ExprTab[I].L, Depth + 1);
      I := ExprTab[I].R;
    End;
    Exit;
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

{ ---- Generation du code : operandes et variables (TODO 18) ------- }

Procedure CallRT(Const Name : TString);
Begin
  Emit1(OP_CALL, OpLabel(Intern(A58_RT_PFX + Name)));
End;

Procedure LoadImm(R : TReg; V : LongInt);
Begin
  If V = 0 Then
    Emit(OP_XOR, OpReg(R), OpReg(R))
  Else
    Emit(OP_MOV, OpReg(R), OpImm(V));
End;

{ ST(0) -> pile machine (SUB ESP,8 ; FSTP QWORD [ESP]) }
Procedure SpillReal;
Begin
  Emit(OP_SUB, OpReg(R_ESP), OpImm(8));
  Emit1(OP_FSTP, OpMem(R_ESP, 0, 8));
End;

Function IsRealT(T : Integer) : Boolean;
Begin
  IsRealT := (T = TY_IDX_REAL);
End;

Function ValSize(T : Integer) : Byte;
Begin
  If T = TY_IDX_REAL Then ValSize := 8 Else ValSize := 4;
End;

{ Registre contenant le cadre de la procedure de niveau Level : EBP
  pour le niveau courant, sinon ECX apres remontee des liens
  statiques ([cadre+8]). }
Function GenFrameReg(Level : Integer) : TReg;
Var
  K : Integer;
Begin
  K := CurLevel - Level;
  If K <= 0 Then
  Begin
    GenFrameReg := R_EBP;
    Exit;
  End;
  Emit(OP_MOV, OpReg(R_ECX), OpMem(R_EBP, ABI_PARAM_BASE, 4));
  Dec(K);
  While K > 0 Do
  Begin
    Emit(OP_MOV, OpReg(R_ECX), OpMem(R_ECX, ABI_PARAM_BASE, 4));
    Dec(K);
  End;
  GenFrameReg := R_ECX;
End;

{ Cellule d'une variable scalaire (globale, locale ou parametre par
  valeur) ; resultat d'une fonction pour SK_FUNC. }
Function SymCell(S : Integer; Extra : LongInt; Size : Byte) : TOperand;
Var
  F : TReg;
Begin
  If SymTab[S].Kind = SK_FUNC Then
  Begin
    SymCell := OpMem(R_EBP, SymResultOfs + Extra, Size);
    Exit;
  End;
  If SymTab[S].Storage = SC_GLOBAL Then
    SymCell := OpMemSym(Intern(SymTab[S].Mangled), Extra, Size)
  Else
  Begin
    F := GenFrameReg(SymTab[S].Level);
    SymCell := OpMem(F, SymTab[S].Offset + Extra, Size);
  End;
End;

Function DescName(S : Integer) : Integer;
Begin
  DescName := Intern('_A58DSC_' + Copy(SymTab[S].Mangled,
                     Length(A58_ARR_PFX) + 1, 120));
End;

{ ESI := adresse du descripteur du tableau S : declare (global ou
  local) ou parametre tableau (pointeur recu). Descripteur (DWORD) :
  [0] base, [1] nombre de dimensions, puis par dimension lo, hi,
  pas (en elements). }
Procedure GenDescToESI(S : Integer);
Var
  F : TReg;
Begin
  If SymTab[S].Kind = SK_ARRAY Then
  Begin
    If SymTab[S].Storage = SC_GLOBAL Then
      Emit(OP_MOV, OpReg(R_ESI), OpOffset(DescName(S)))
    Else
    Begin
      F := GenFrameReg(SymTab[S].Level);
      Emit(OP_LEA, OpReg(R_ESI), OpMem(F, SymTab[S].ArrDescOfs, 0));
    End;
  End
  Else
  Begin
    F := GenFrameReg(SymTab[S].Level);
    Emit(OP_MOV, OpReg(R_ESI), OpMem(F, SymTab[S].Offset, 4));
  End;
End;

{ Acces a un parametre par nom : EAX := valeur (WantAddr = False) ou
  adresse de l'argument (WantAddr = True). Paire [mot0, mot1] : mot0 =
  thunk (0 = reference directe), mot1 = contexte ou adresse. Un
  thunk est appele avec EAX = contexte, ECX = 0 (valeur) ou 1 (adresse),
  et rend la valeur en EAX / ST(0) ou l'adresse en EAX. }
Procedure GenByName(S : Integer; WantAddr : Boolean);
Var
  F            : TReg;
  Off          : LongInt;
  Lref, Ldone  : Integer;
Begin
  F   := GenFrameReg(SymTab[S].Level);
  Off := SymTab[S].Offset;
  Lref  := NewLabel;
  Ldone := NewLabel;
  Emit(OP_MOV, OpReg(R_EDX), OpMem(F, Off, 4));
  Emit(OP_MOV, OpReg(R_EAX), OpMem(F, Off + 4, 4));
  Emit(OP_TEST, OpReg(R_EDX), OpReg(R_EDX));
  If WantAddr Then
    Emit1(OP_JE, OpLabel(Ldone))
  Else
    Emit1(OP_JE, OpLabel(Lref));
  If WantAddr Then
    Emit(OP_MOV, OpReg(R_ECX), OpImm(1))
  Else
    Emit(OP_XOR, OpReg(R_ECX), OpReg(R_ECX));
  Emit1(OP_CALL, OpReg(R_EDX));
  If Not WantAddr Then
  Begin
    Emit1(OP_JMP, OpLabel(Ldone));
    EmitLabel(Lref);
    Emit(OP_MOV, OpReg(R_EDX), OpReg(R_EAX));
    If IsRealT(SymTab[S].TypeIdx) Then
      Emit1(OP_FLD, OpMem(R_EDX, 0, 8))
    Else
      Emit(OP_MOV, OpReg(R_EAX), OpMem(R_EDX, 0, 4));
  End;
  EmitLabel(Ldone);
End;

{ Valeur d'une variable scalaire -> EAX ou ST(0) }
Procedure GenLoadVar(S : Integer);
Var
  T : Integer;
Begin
  T := SymTab[S].TypeIdx;
  If SymTab[S].Kind = SK_PARAM_NAME Then
    GenByName(S, False)
  Else If IsRealT(T) Then
    Emit1(OP_FLD, SymCell(S, 0, 8))
  Else
    Emit(OP_MOV, OpReg(R_EAX), SymCell(S, 0, 4));
End;

{ Adresse d'une variable scalaire -> EAX }
Procedure GenAddrVar(S : Integer);
Var
  O : TOperand;
Begin
  If SymTab[S].Kind = SK_PARAM_NAME Then
  Begin
    GenByName(S, True);
    Exit;
  End;
  O := SymCell(S, 0, 0);
  If O.Sym >= 0 Then
    Emit(OP_MOV, OpReg(R_EAX), OpOffset(O.Sym))
  Else
    Emit(OP_LEA, OpReg(R_EAX), O);
End;

{ Pas (en elements) de la dimension K d'un tableau a bornes connues }
Function KnownStride(S, K : Integer) : LongInt;
Var
  J       : Integer;
  Stride  : LongInt;
Begin
  Stride := 1;
  For J := K + 1 To SymTab[S].ArrDims Do
    Stride := Stride * (SymTab[S].ArrHi[J] - SymTab[S].ArrLo[J] + 1);
  KnownStride := Stride;
End;

Procedure GenExpr(N : Integer); Forward;
Procedure GenExprAs(N, T : Integer); Forward;
Procedure GenAssign(N : Integer; NeedValue : Boolean); Forward;

{ Adresse d'un element de tableau -> EAX. Chaque indice est controle
  par _A58RT_CHKIDX (sauf constante verifiee a la compilation) ;
  indice lineaire = somme (i_k - lo_k) * pas_k. }
Procedure GenIndexAddr(N : Integer);
Var
  S, K, Dims, Item, E : Integer;
  Known, Chk          : Boolean;
  Off                 : LongInt;
Begin
  S    := ExprTab[N].Sym;
  Dims := ExprTab[N].IntVal;
  Known := (SymTab[S].Kind = SK_ARRAY) And (Not SymTab[S].ArrDynamic) And
           (SymTab[S].ArrDims = Dims);
  Item := ExprTab[N].L;
  K := 0;
  While Item >= 0 Do
  Begin
    Inc(K);
    E := ExprTab[Item].L;
    If K > 1 Then Emit1(OP_PUSH, OpReg(R_EAX));        { cumul partiel }
    GenExprAs(E, TY_IDX_INTEGER);
    Off := 8 + 12 * (K - 1);                           { lo ; hi = +4 }
    Chk := (Not Known) Or (ExprTab[E].Kind <> EX_INT);
    GenDescToESI(S);
    If Chk Then
    Begin
      If Known Then
      Begin
        Emit(OP_MOV, OpReg(R_ECX), OpImm(SymTab[S].ArrLo[K]));
        Emit(OP_MOV, OpReg(R_EDX), OpImm(SymTab[S].ArrHi[K]));
      End
      Else
      Begin
        Emit(OP_MOV, OpReg(R_ECX), OpMem(R_ESI, Off, 4));
        Emit(OP_MOV, OpReg(R_EDX), OpMem(R_ESI, Off + 4, 4));
      End;
      CallRT('CHKIDX');
    End;
    If Known Then
    Begin
      If SymTab[S].ArrLo[K] <> 0 Then
        Emit(OP_SUB, OpReg(R_EAX), OpImm(SymTab[S].ArrLo[K]));
      If KnownStride(S, K) <> 1 Then
      Begin
        Emit(OP_MOV, OpReg(R_ECX), OpImm(KnownStride(S, K)));
        Emit(OP_IMUL, OpReg(R_EAX), OpReg(R_ECX));
      End;
    End
    Else
    Begin
      Emit(OP_SUB, OpReg(R_EAX), OpMem(R_ESI, Off, 4));
      Emit(OP_MOV, OpReg(R_ECX), OpMem(R_ESI, Off + 8, 4));
      Emit(OP_IMUL, OpReg(R_EAX), OpReg(R_ECX));
    End;
    If K > 1 Then
    Begin
      Emit1(OP_POP, OpReg(R_ECX));
      Emit(OP_ADD, OpReg(R_EAX), OpReg(R_ECX));
    End;
    Item := ExprTab[Item].R;
  End;
  GenDescToESI(S);
  Emit(OP_MOV, OpReg(R_ECX), OpMem(R_ESI, 0, 4));
  Emit(OP_LEA, OpReg(R_EAX),
       OpMemIdx(-1, R_ECX, R_EAX, ValSize(ExprTab[N].Typ), 0, 0));
End;

{ Adresse d'une variable ou d'un element -> EAX }
Procedure GenAddrNode(E : Integer);
Begin
  If ExprTab[E].Kind = EX_INDEX Then
    GenIndexAddr(E)
  Else
    GenAddrVar(ExprTab[E].Sym);
End;

{ Conversion de la valeur courante de From vers Dest }
Procedure GenConvert(From, Dest : Integer);
Begin
  If From = Dest Then Exit;
  If (Dest = TY_IDX_REAL) And
     ((From = TY_IDX_INTEGER) Or (From = TY_IDX_BOOLEAN)) Then
  Begin
    Emit1(OP_PUSH, OpReg(R_EAX));
    Emit1(OP_FILD, OpMem(R_ESP, 0, 4));
    Emit(OP_ADD, OpReg(R_ESP), OpImm(4));
  End
  Else If (Dest = TY_IDX_INTEGER) And (From = TY_IDX_REAL) Then
    CallRT('RTOI')
  Else If (Dest = TY_IDX_BOOLEAN) And (From = TY_IDX_INTEGER) Then
  Begin
    Emit(OP_TEST, OpReg(R_EAX), OpReg(R_EAX));
    Emit1(OP_SETNE, OpReg(R_AL));
    Emit(OP_MOVZX, OpReg(R_EAX), OpReg(R_AL));
  End;
End;

Procedure GenExprAs(N, T : Integer);
Begin
  GenExpr(N);
  GenConvert(ExprTab[N].Typ, T);
End;

{ ---- Comparaisons et sauts conditionnels ---- }

Function InvRel(Const Op : TString) : TString;
Begin
  If Op = '=' Then InvRel := '#'
  Else If Op = '#' Then InvRel := '='
  Else If Op = '<' Then InvRel := '>='
  Else If Op = '<=' Then InvRel := '>'
  Else If Op = '>' Then InvRel := '<='
  Else InvRel := '<';
End;

{ Saut selon Op ; entiers : drapeaux signes ; reels : apres
  FCOMP [ESP] (droite en ST0, gauche en memoire) et SAHF, la
  relation est inversee et lue avec les drapeaux non signes. }
Function JccFor(Const Op : TString; IsReal : Boolean) : TOp;
Begin
  If Op = '=' Then JccFor := OP_JE
  Else If Op = '#' Then JccFor := OP_JNE
  Else If IsReal Then
  Begin
    If Op = '<' Then JccFor := OP_JA
    Else If Op = '<=' Then JccFor := OP_JAE
    Else If Op = '>' Then JccFor := OP_JB
    Else JccFor := OP_JBE;
  End
  Else
  Begin
    If Op = '<' Then JccFor := OP_JL
    Else If Op = '<=' Then JccFor := OP_JLE
    Else If Op = '>' Then JccFor := OP_JG
    Else JccFor := OP_JGE;
  End;
End;

Function SetFor(Const Op : TString; IsReal : Boolean) : TOp;
Begin
  If Op = '=' Then SetFor := OP_SETE
  Else If Op = '#' Then SetFor := OP_SETNE
  Else If IsReal Then
  Begin
    If Op = '<' Then SetFor := OP_SETA
    Else If Op = '<=' Then SetFor := OP_SETAE
    Else If Op = '>' Then SetFor := OP_SETB
    Else SetFor := OP_SETBE;
  End
  Else
  Begin
    If Op = '<' Then SetFor := OP_SETL
    Else If Op = '<=' Then SetFor := OP_SETLE
    Else If Op = '>' Then SetFor := OP_SETG
    Else SetFor := OP_SETGE;
  End;
End;

{ Evalue les deux operandes d'une relation et positionne les drapeaux.
  Retourne True si la comparaison est reelle (mapping non signe). }
Function GenCompareFlags(N : Integer) : Boolean;
Var
  L, R, Dom : Integer;
Begin
  L := ExprTab[N].L;
  R := ExprTab[N].R;
  Dom := TypeArith(ExprTab[L].Typ, ExprTab[R].Typ);
  If Dom = TY_IDX_REAL Then
  Begin
    GenExprAs(L, TY_IDX_REAL);
    SpillReal;
    GenExprAs(R, TY_IDX_REAL);
    Emit1(OP_FCOMP, OpMem(R_ESP, 0, 8));
    Emit1(OP_FNSTSW, OpReg(R_AX));
    Emit(OP_ADD, OpReg(R_ESP), OpImm(8));
    Emit0(OP_SAHF);
    GenCompareFlags := True;
  End
  Else
  Begin
    GenExprAs(L, TY_IDX_INTEGER);
    If ExprTab[R].Kind = EX_INT Then
      Emit(OP_CMP, OpReg(R_EAX), OpImm(ExprTab[R].IntVal))
    Else
    Begin
      Emit1(OP_PUSH, OpReg(R_EAX));
      GenExprAs(R, TY_IDX_INTEGER);
      Emit(OP_MOV, OpReg(R_ECX), OpReg(R_EAX));
      Emit1(OP_POP, OpReg(R_EAX));
      Emit(OP_CMP, OpReg(R_EAX), OpReg(R_ECX));
    End;
    GenCompareFlags := False;
  End;
End;

{ Saute vers Lbl si la condition N est vraie (OnTrue) ou fausse }
Procedure GenJump(N, Lbl : Integer; OnTrue : Boolean);
Var
  Skip   : Integer;
  Op     : TString;
  IsReal : Boolean;
Begin
  If ExprTab[N].Kind In [EX_BOOL, EX_INT] Then
  Begin
    If (ExprTab[N].IntVal <> 0) = OnTrue Then
      Emit1(OP_JMP, OpLabel(Lbl));
    Exit;
  End;
  If (ExprTab[N].Kind = EX_UNARY) And (ExprTab[N].Op = 'not') Then
  Begin
    GenJump(ExprTab[N].L, Lbl, Not OnTrue);
    Exit;
  End;
  If ExprTab[N].Kind = EX_BINARY Then
  Begin
    Op := ExprTab[N].Op;
    If OpIsRel(Op) Then
    Begin
      IsReal := GenCompareFlags(N);
      If Not OnTrue Then Op := InvRel(Op);
      Emit1(JccFor(Op, IsReal), OpLabel(Lbl));
      Exit;
    End;
    If (Op = 'and') Or (Op = 'or') Or (Op = 'imp') Then
    Begin
      If Op = 'imp' Then
      Begin
        { a imp b = (non a) ou b }
        If OnTrue Then
        Begin
          GenJump(ExprTab[N].L, Lbl, False);
          GenJump(ExprTab[N].R, Lbl, True);
        End
        Else
        Begin
          Skip := NewLabel;
          GenJump(ExprTab[N].L, Skip, False);
          GenJump(ExprTab[N].R, Lbl, False);
          EmitLabel(Skip);
        End;
        Exit;
      End;
      If (Op = 'and') = (Not OnTrue) Then
      Begin
        { and / faux  ou  or / vrai : l'un des deux suffit }
        GenJump(ExprTab[N].L, Lbl, OnTrue);
        GenJump(ExprTab[N].R, Lbl, OnTrue);
      End
      Else
      Begin
        Skip := NewLabel;
        GenJump(ExprTab[N].L, Skip, Not OnTrue);
        GenJump(ExprTab[N].R, Lbl, OnTrue);
        EmitLabel(Skip);
      End;
      Exit;
    End;
  End;
  GenExpr(N);
  Emit(OP_TEST, OpReg(R_EAX), OpReg(R_EAX));
  If OnTrue Then
    Emit1(OP_JNE, OpLabel(Lbl))
  Else
    Emit1(OP_JE, OpLabel(Lbl));
End;

{ ---- Generation du code : expressions ---------------------------- }

{ Operation arithmetique entiere : EAX := EAX op ECX }
Procedure GenIntOp(Const Op : TString; RightIsConst : Boolean);
Var
  Ok : Integer;
Begin
  If Op = '+' Then
    Emit(OP_ADD, OpReg(R_EAX), OpReg(R_ECX))
  Else If Op = '-' Then
    Emit(OP_SUB, OpReg(R_EAX), OpReg(R_ECX))
  Else If Op = '*' Then
    Emit(OP_IMUL, OpReg(R_EAX), OpReg(R_ECX))
  Else If Op = '^' Then
  Begin
    Emit(OP_MOV, OpReg(R_EDX), OpReg(R_ECX));
    CallRT('POW');
  End
  Else
  Begin
    { / div mod : division par zero controlee si le diviseur varie }
    If Not RightIsConst Then
    Begin
      Ok := NewLabel;
      Emit(OP_TEST, OpReg(R_ECX), OpReg(R_ECX));
      Emit1(OP_JNE, OpLabel(Ok));
      CallRT('DIVZERO');
      EmitLabel(Ok);
    End;
    Emit0(OP_CDQ);
    Emit1(OP_IDIV, OpReg(R_ECX));
    If Op = 'mod' Then Emit(OP_MOV, OpReg(R_EAX), OpReg(R_EDX));
  End;
End;

Procedure GenBinary(N : Integer);
Var
  Op        : TString;
  L, R, T   : Integer;
  IsReal    : Boolean;
  Lf, Le    : Integer;
Begin
  Op := ExprTab[N].Op;
  L  := ExprTab[N].L;
  R  := ExprTab[N].R;
  T  := ExprTab[N].Typ;

  If OpIsRel(Op) Then
  Begin
    IsReal := GenCompareFlags(N);
    Emit1(SetFor(Op, IsReal), OpReg(R_AL));
    Emit(OP_MOVZX, OpReg(R_EAX), OpReg(R_AL));
    Exit;
  End;

  If OpIsLogic(Op) Then
  Begin
    If Op = 'eqv' Then
    Begin
      GenExprAs(L, TY_IDX_BOOLEAN);
      Emit1(OP_PUSH, OpReg(R_EAX));
      GenExprAs(R, TY_IDX_BOOLEAN);
      Emit1(OP_POP, OpReg(R_ECX));
      Emit(OP_CMP, OpReg(R_ECX), OpReg(R_EAX));
      Emit1(OP_SETE, OpReg(R_AL));
      Emit(OP_MOVZX, OpReg(R_EAX), OpReg(R_AL));
    End
    Else
    Begin
      Lf := NewLabel;
      Le := NewLabel;
      GenJump(N, Lf, False);
      Emit(OP_MOV, OpReg(R_EAX), OpImm(1));
      Emit1(OP_JMP, OpLabel(Le));
      EmitLabel(Lf);
      Emit(OP_XOR, OpReg(R_EAX), OpReg(R_EAX));
      EmitLabel(Le);
    End;
    Exit;
  End;

  If T = TY_IDX_REAL Then
  Begin
    GenExprAs(L, TY_IDX_REAL);
    SpillReal;
    GenExprAs(R, TY_IDX_REAL);
    If Op = '^' Then
    Begin
      Emit1(OP_FLD, OpMem(R_ESP, 0, 8));       { ST0 = base, ST1 = exposant }
      CallRT('RPOW');
    End
    Else If Op = '+' Then
      Emit1(OP_FADD, OpMem(R_ESP, 0, 8))
    Else If Op = '*' Then
      Emit1(OP_FMUL, OpMem(R_ESP, 0, 8))
    Else If Op = '-' Then
      Emit1(OP_FSUBR, OpMem(R_ESP, 0, 8))
    Else
      Emit1(OP_FDIVR, OpMem(R_ESP, 0, 8));     { / }
    Emit(OP_ADD, OpReg(R_ESP), OpImm(8));
    Exit;
  End;

  { entiers }
  GenExprAs(L, TY_IDX_INTEGER);
  If (ExprTab[R].Kind = EX_INT) And (Op <> '^') And (Op <> '*') And
     (Op <> '/') And (Op <> 'div') And (Op <> 'mod') Then
  Begin
    If Op = '+' Then
      Emit(OP_ADD, OpReg(R_EAX), OpImm(ExprTab[R].IntVal))
    Else
      Emit(OP_SUB, OpReg(R_EAX), OpImm(ExprTab[R].IntVal));
    Exit;
  End;
  If ExprTab[R].Kind = EX_INT Then
  Begin
    Emit(OP_MOV, OpReg(R_ECX), OpImm(ExprTab[R].IntVal));
    GenIntOp(Op, True);
    Exit;
  End;
  Emit1(OP_PUSH, OpReg(R_EAX));
  GenExprAs(R, TY_IDX_INTEGER);
  Emit(OP_MOV, OpReg(R_ECX), OpReg(R_EAX));
  Emit1(OP_POP, OpReg(R_EAX));
  GenIntOp(Op, False);
End;

Procedure GenIntrinsic(N : Integer);
Var
  I          : TIntrinsic;
  A1, A2     : Integer;
  T, Lk, Ld  : Integer;
Begin
  I  := TIntrinsic(ExprTab[N].IntVal);
  A1 := ExprTab[N].L;
  A2 := -1;
  If ExprTab[A1].R >= 0 Then A2 := ExprTab[A1].R;
  T  := ExprTab[N].Typ;
  Case I Of
    IN_ABS:
      Begin
        GenExprAs(ExprTab[A1].L, ExprTab[A1].Typ);
        If T = TY_IDX_REAL Then
          Emit0(OP_FABS)
        Else
        Begin
          Emit0(OP_CDQ);
          Emit(OP_XOR, OpReg(R_EAX), OpReg(R_EDX));
          Emit(OP_SUB, OpReg(R_EAX), OpReg(R_EDX));
        End;
      End;
    IN_SIGN:
      Begin
        GenExprAs(ExprTab[A1].L, ExprTab[A1].Typ);
        If ExprTab[A1].Typ = TY_IDX_REAL Then
          CallRT('RSIGN')
        Else
        Begin
          Emit(OP_MOV, OpReg(R_ECX), OpReg(R_EAX));
          Emit0(OP_CDQ);
          Emit1(OP_NEG, OpReg(R_ECX));
          Emit(OP_SHR, OpReg(R_ECX), OpImm(31));
          Emit(OP_MOV, OpReg(R_EAX), OpReg(R_EDX));
          Emit(OP_OR, OpReg(R_EAX), OpReg(R_ECX));
        End;
      End;
    IN_ENTIER:
      Begin
        GenExprAs(ExprTab[A1].L, TY_IDX_REAL);
        CallRT('FLOOR');
      End;
    IN_SQRT:
      Begin
        GenExprAs(ExprTab[A1].L, ExprTab[A1].Typ);
        If T = TY_IDX_REAL Then Emit0(OP_FSQRT) Else CallRT('ISQRT');
      End;
    IN_SIN, IN_COS, IN_ARCTAN, IN_LN, IN_EXP:
      Begin
        GenExprAs(ExprTab[A1].L, TY_IDX_REAL);
        Case I Of
          IN_SIN    : Emit0(OP_FSIN);
          IN_COS    : Emit0(OP_FCOS);
          IN_ARCTAN :
            Begin
              Emit0(OP_FLD1);
              Emit0(OP_FPATAN);
            End;
          IN_LN     :
            Begin
              Emit0(OP_FLDLN2);
              Emit1(OP_FXCH, OpST(1));
              Emit0(OP_FYL2X);
            End;
          IN_EXP    : CallRT('EXP');
        End;
      End;
    IN_MAX, IN_MIN:
      Begin
        Lk := NewLabel;
        Ld := NewLabel;
        If T = TY_IDX_REAL Then
        Begin
          GenExprAs(ExprTab[A1].L, TY_IDX_REAL);
          SpillReal;
          GenExprAs(ExprTab[A2].L, TY_IDX_REAL);
          Emit1(OP_FLD, OpMem(R_ESP, 0, 8));    { ST0 = gauche, ST1 = droite }
          Emit(OP_ADD, OpReg(R_ESP), OpImm(8));
          Emit1(OP_FCOM, OpST(1));
          Emit1(OP_FNSTSW, OpReg(R_AX));
          Emit0(OP_SAHF);
          { max : garder la gauche si gauche >= droite ; min : si <= }
          If I = IN_MAX Then
            Emit1(OP_JAE, OpLabel(Lk))
          Else
            Emit1(OP_JBE, OpLabel(Lk));
          Emit1(OP_FSTP, OpST(0));              { garder la droite }
          Emit1(OP_JMP, OpLabel(Ld));
          EmitLabel(Lk);
          Emit1(OP_FSTP, OpST(1));              { garder la gauche }
          EmitLabel(Ld);
        End
        Else
        Begin
          GenExprAs(ExprTab[A1].L, TY_IDX_INTEGER);
          Emit1(OP_PUSH, OpReg(R_EAX));
          GenExprAs(ExprTab[A2].L, TY_IDX_INTEGER);
          Emit(OP_MOV, OpReg(R_ECX), OpReg(R_EAX));
          Emit1(OP_POP, OpReg(R_EAX));
          Emit(OP_CMP, OpReg(R_EAX), OpReg(R_ECX));
          If I = IN_MAX Then
            Emit1(OP_JGE, OpLabel(Lk))
          Else
            Emit1(OP_JLE, OpLabel(Lk));
          Emit(OP_MOV, OpReg(R_EAX), OpReg(R_ECX));
          EmitLabel(Lk);
        End;
      End;
    IN_MOD, IN_DIV:
      Begin
        GenExprAs(ExprTab[A1].L, TY_IDX_INTEGER);
        Emit1(OP_PUSH, OpReg(R_EAX));
        GenExprAs(ExprTab[A2].L, TY_IDX_INTEGER);
        Emit(OP_MOV, OpReg(R_ECX), OpReg(R_EAX));
        Emit1(OP_POP, OpReg(R_EAX));
        If I = IN_MOD Then GenIntOp('mod', False) Else GenIntOp('div', False);
      End;
  End;
End;

{ Thunk d'un argument par nom (emis a l'ecart, dans DeferTab) : appele
  avec EAX = contexte (BP de l'appelant) et ECX = 0 pour la valeur
  (convertie vers le type du parametre) ou 1 pour l'adresse (thunk
  d'ecriture seulement). }
Procedure GenThunk(Item, Param : Integer; Cls : TArgClass);
Var
  Start, Lth, Laddr, E : Integer;
Begin
  Start := CodeCount;
  Lth   := Intern(ExprStrTab[ExprTab[Item].StrIdx]);
  E     := ExprTab[Item].L;
  EmitLabel(Lth);
  Emit1(OP_PUSH, OpReg(R_EBP));
  Emit(OP_MOV, OpReg(R_EBP), OpReg(R_EAX));
  Laddr := -1;
  If Cls = AC_THUNK_RW Then
  Begin
    Laddr := NewLabel;
    Emit(OP_TEST, OpReg(R_ECX), OpReg(R_ECX));
    Emit1(OP_JNE, OpLabel(Laddr));
  End;
  GenExprAs(E, SymTab[Param].TypeIdx);
  Emit1(OP_POP, OpReg(R_EBP));
  Emit0(OP_RET);
  If Cls = AC_THUNK_RW Then
  Begin
    EmitLabel(Laddr);
    GenAddrNode(E);
    Emit1(OP_POP, OpReg(R_EBP));
    Emit0(OP_RET);
  End;
  MoveToDeferred(Start);
End;

{ Appel : arguments de droite a gauche, lien statique, CALL ; la
  procedure nettoie la pile (RET n). Resultat : EAX ou ST(0). }
Procedure GenCall(N : Integer);
Var
  S, K, Item, PS, E, Delta : Integer;
  Items                    : Array[1..MAX_PARAM] Of Integer;
  Cls                      : TArgClass;
  F                        : TReg;
Begin
  S := ExprTab[N].Sym;
  Item := ExprTab[N].L;
  K := 0;
  While Item >= 0 Do
  Begin
    Inc(K);
    Items[K] := Item;
    Item := ExprTab[Item].R;
  End;
  While K >= 1 Do
  Begin
    Item := Items[K];
    PS   := SymTab[S].ParamSym[K];
    E    := ExprTab[Item].L;
    Cls  := TArgClass(ExprTab[Item].IntVal);
    Case Cls Of
      AC_VALUE:
        Begin
          GenExprAs(E, SymTab[PS].TypeIdx);
          If IsRealT(SymTab[PS].TypeIdx) Then
            SpillReal
          Else
            Emit1(OP_PUSH, OpReg(R_EAX));
        End;
      AC_ARRAY:
        Begin
          GenDescToESI(ExprTab[E].Sym);
          Emit1(OP_PUSH, OpReg(R_ESI));
        End;
      AC_CONST:
        Begin
          If IsRealT(SymTab[PS].TypeIdx) Then
            Emit(OP_MOV, OpReg(R_EDX),
                 OpOffset(DataReal(ExprTab[E].RealVal)))
          Else
            Emit(OP_MOV, OpReg(R_EDX),
                 OpOffset(DataInt(ExprTab[E].IntVal)));
          Emit1(OP_PUSH, OpReg(R_EDX));
          Emit1(OP_PUSH, OpImm(0));
        End;
      AC_REF:
        Begin
          GenAddrNode(E);
          Emit1(OP_PUSH, OpReg(R_EAX));
          Emit1(OP_PUSH, OpImm(0));
        End;
      AC_FORWARD:
        Begin
          F := GenFrameReg(SymTab[ExprTab[E].Sym].Level);
          Emit1(OP_PUSH, OpMem(F, SymTab[ExprTab[E].Sym].Offset + 4, 4));
          Emit1(OP_PUSH, OpMem(F, SymTab[ExprTab[E].Sym].Offset, 4));
        End;
      AC_THUNK, AC_THUNK_RW:
        Begin
          GenThunk(Item, PS, Cls);
          Emit1(OP_PUSH, OpReg(R_EBP));
          { passer par un registre : ML.PAS ne dimensionne pas bien
            PUSH OFFSET etiquette_en_avant a la passe 1 }
          Emit(OP_MOV, OpReg(R_EDX), OpOffset(Intern(
               ExprStrTab[ExprTab[Item].StrIdx])));
          Emit1(OP_PUSH, OpReg(R_EDX));
        End;
    End;
    Dec(K);
  End;
  { lien statique : cadre de la procedure qui contient la declaration }
  If SymTab[S].Level >= 1 Then
  Begin
    Delta := CurLevel - SymTab[S].Level;
    Emit(OP_MOV, OpReg(R_EAX), OpReg(R_EBP));
    While Delta > 0 Do
    Begin
      Emit(OP_MOV, OpReg(R_EAX), OpMem(R_EAX, ABI_PARAM_BASE, 4));
      Dec(Delta);
    End;
    Emit1(OP_PUSH, OpReg(R_EAX));
  End;
  Emit1(OP_CALL, OpLabel(Intern(SymTab[S].Mangled)));
End;

{ Valeur de N -> EAX ou ST(0) }
Procedure GenExpr(N : Integer);
Var
  T, Lelse, Lend : Integer;
Begin
  T := ExprTab[N].Typ;
  Case ExprTab[N].Kind Of
    EX_INT, EX_BOOL:
      LoadImm(R_EAX, ExprTab[N].IntVal);
    EX_REAL:
      Begin
        If ExprTab[N].RealVal = 0 Then
          Emit0(OP_FLDZ)
        Else If ExprTab[N].RealVal = 1 Then
          Emit0(OP_FLD1)
        Else
          Emit1(OP_FLD, OpMemSym(DataReal(ExprTab[N].RealVal), 0, 8));
      End;
    EX_STR:
      Emit(OP_MOV, OpReg(R_EAX),
           OpOffset(DataStr(ExprStrTab[ExprTab[N].StrIdx])));
    EX_VAR:
      GenLoadVar(ExprTab[N].Sym);
    EX_INDEX:
      Begin
        GenIndexAddr(N);
        If IsRealT(T) Then
          Emit1(OP_FLD, OpMem(R_EAX, 0, 8))
        Else
          Emit(OP_MOV, OpReg(R_EAX), OpMem(R_EAX, 0, 4));
      End;
    EX_UNARY:
      Begin
        If ExprTab[N].Op = 'not' Then
        Begin
          GenExpr(ExprTab[N].L);
          Emit(OP_TEST, OpReg(R_EAX), OpReg(R_EAX));
          Emit1(OP_SETE, OpReg(R_AL));
          Emit(OP_MOVZX, OpReg(R_EAX), OpReg(R_AL));
        End
        Else
        Begin
          GenExprAs(ExprTab[N].L, T);
          If ExprTab[N].Op = '-' Then
          Begin
            If IsRealT(T) Then
              Emit0(OP_FCHS)
            Else
              Emit1(OP_NEG, OpReg(R_EAX));
          End;
        End;
      End;
    EX_BINARY:
      GenBinary(N);
    EX_COND:
      Begin
        Lelse := NewLabel;
        Lend  := NewLabel;
        GenJump(ExprTab[N].L, Lelse, False);
        GenExprAs(ExprTab[N].R, T);
        Emit1(OP_JMP, OpLabel(Lend));
        EmitLabel(Lelse);
        GenExprAs(ExprTab[N].E, T);
        EmitLabel(Lend);
      End;
    EX_ASSIGN:
      GenAssign(N, True);
    EX_CALL:
      GenCall(N);
    EX_INTRIN:
      GenIntrinsic(N);
  End;
End;

{ ---- Generation du code : instructions --------------------------- }

{ nom := valeur  (NeedValue : la valeur reste dans EAX / ST(0), pour
  les affectations multiples ; sinon un real est depile) }
Procedure GenAssign(N : Integer; NeedValue : Boolean);
Var
  Tgt, Val, TT, Sym : Integer;
  Simple            : Boolean;
  Cell              : TOperand;
Begin
  Tgt := ExprTab[N].L;
  Val := ExprTab[N].R;
  TT  := ExprTab[Tgt].Typ;
  Simple := (ExprTab[Tgt].Kind = EX_VAR) And
            (SymTab[ExprTab[Tgt].Sym].Kind <> SK_PARAM_NAME);
  If Simple Then
  Begin
    Sym := ExprTab[Tgt].Sym;
    GenExprAs(Val, TT);
    Cell := SymCell(Sym, 0, ValSize(TT));
    If IsRealT(TT) Then
    Begin
      If NeedValue Then Emit1(OP_FST, Cell) Else Emit1(OP_FSTP, Cell);
    End
    Else
      Emit(OP_MOV, Cell, OpReg(R_EAX));
  End
  Else
  Begin
    { adresse de la cible d'abord (indices), puis la valeur }
    GenAddrNode(Tgt);
    Emit1(OP_PUSH, OpReg(R_EAX));
    GenExprAs(Val, TT);
    Emit1(OP_POP, OpReg(R_ECX));
    If IsRealT(TT) Then
    Begin
      If NeedValue Then
        Emit1(OP_FST, OpMem(R_ECX, 0, 8))
      Else
        Emit1(OP_FSTP, OpMem(R_ECX, 0, 8));
    End
    Else
      Emit(OP_MOV, OpMem(R_ECX, 0, 4), OpReg(R_EAX));
  End;
End;

{ Vrai si l'evaluation de N a un effet (appel, affectation, E/S) }
Function ExprHasEffect(N : Integer) : Boolean;
Begin
  ExprHasEffect := False;
  If N < 0 Then Exit;
  If ExprTab[N].Kind In [EX_ASSIGN, EX_CALL, EX_WRITE, EX_READ] Then
  Begin
    ExprHasEffect := True;
    Exit;
  End;
  If ExprHasEffect(ExprTab[N].L) Or ExprHasEffect(ExprTab[N].R) Or
     ExprHasEffect(ExprTab[N].E) Then
    ExprHasEffect := True;
End;

Procedure GenWrite(N : Integer);
Var
  Item, E, T, Len : Integer;
Begin
  Item := ExprTab[N].L;
  While Item >= 0 Do
  Begin
    E := ExprTab[Item].L;
    T := ExprTab[E].Typ;
    If ExprTab[E].Kind = EX_STR Then
    Begin
      Len := Length(ExprStrTab[ExprTab[E].StrIdx]);
      If Len > 0 Then
      Begin
        Emit(OP_MOV, OpReg(R_EAX),
             OpOffset(DataStr(ExprStrTab[ExprTab[E].StrIdx])));
        Emit(OP_MOV, OpReg(R_EDX), OpImm(Len));
        CallRT('WRITESTR');
      End;
    End
    Else If T = TY_IDX_STRING Then
    Begin
      GenExpr(E);
      CallRT('WRITEZ');
    End
    Else If IsRealT(T) Then
    Begin
      GenExpr(E);
      CallRT('WRITEREAL');
    End
    Else If T = TY_IDX_BOOLEAN Then
    Begin
      GenExpr(E);
      CallRT('WRITEBOOL');
    End
    Else
    Begin
      GenExpr(E);
      CallRT('WRITEINT');
    End;
    Item := ExprTab[Item].R;
  End;
  If ExprTab[N].Flag Then CallRT('NEWLINE');
End;

Procedure GenRead(N : Integer);
Var
  Item, E, T : Integer;
  Simple     : Boolean;
  RdName     : TString;
  Cell       : TOperand;
Begin
  Item := ExprTab[N].L;
  While Item >= 0 Do
  Begin
    E := ExprTab[Item].L;
    T := ExprTab[E].Typ;
    If IsRealT(T) Then
      RdName := 'READREAL'
    Else If T = TY_IDX_BOOLEAN Then
      RdName := 'READBOOL'
    Else
      RdName := 'READINT';
    Simple := (ExprTab[E].Kind = EX_VAR) And
              (SymTab[ExprTab[E].Sym].Kind <> SK_PARAM_NAME);
    If Simple Then
    Begin
      CallRT(RdName);
      Cell := SymCell(ExprTab[E].Sym, 0, ValSize(T));
      If IsRealT(T) Then
        Emit1(OP_FSTP, Cell)
      Else
        Emit(OP_MOV, Cell, OpReg(R_EAX));
    End
    Else
    Begin
      GenAddrNode(E);
      Emit1(OP_PUSH, OpReg(R_EAX));
      CallRT(RdName);
      Emit1(OP_POP, OpReg(R_ECX));
      If IsRealT(T) Then
        Emit1(OP_FSTP, OpMem(R_ECX, 0, 8))
      Else
        Emit(OP_MOV, OpMem(R_ECX, 0, 4), OpReg(R_EAX));
    End;
    Item := ExprTab[Item].R;
  End;
  If ExprTab[N].Flag Then CallRT('READLN');
End;

{ Instruction expression (affectation, appel, E/S ou expression a
  effet) : la valeur eventuelle est jetee. }
Procedure GenStmtExpr(N : Integer);
Begin
  If N < 0 Then Exit;
  Case ExprTab[N].Kind Of
    EX_ASSIGN: GenAssign(N, False);
    EX_WRITE:  GenWrite(N);
    EX_READ:   GenRead(N);
    EX_CALL:
      Begin
        GenCall(N);
        If IsRealT(ExprTab[N].Typ) Then Emit1(OP_FSTP, OpST(0));
      End;
  Else
    If ExprHasEffect(N) Then
    Begin
      GenExpr(N);
      If IsRealT(ExprTab[N].Typ) Then Emit1(OP_FSTP, OpST(0));
    End;
  End;
End;

{ Saut vers un designateur (go to) }
Procedure GenDesignator(D : Integer);
Var
  S, Cnt, Lskip, Lelse : Integer;
Begin
  Case ExprTab[D].Kind Of
    EX_LABEL:
      Emit1(OP_JMP, OpLabel(Intern(SymTab[ExprTab[D].Sym].Mangled)));
    EX_SWITCHREF:
      Begin
        S   := ExprTab[D].Sym;
        Cnt := SymTab[S].SwitchCount;
        Lskip := NewLabel;
        GenExprAs(ExprTab[D].L, TY_IDX_INTEGER);
        Emit(OP_CMP, OpReg(R_EAX), OpImm(1));
        Emit1(OP_JL, OpLabel(Lskip));
        Emit(OP_CMP, OpReg(R_EAX), OpImm(Cnt));
        Emit1(OP_JG, OpLabel(Lskip));
        Emit1(OP_JMP, OpMemIdx(Intern(SymTab[S].Mangled), R_NONE, R_EAX,
                               4, -4, 4));
        EmitLabel(Lskip);
      End;
    EX_COND:
      Begin
        Lelse := NewLabel;
        GenJump(ExprTab[D].L, Lelse, False);
        GenDesignator(ExprTab[D].R);
        EmitLabel(Lelse);
        GenDesignator(ExprTab[D].E);
      End;
  End;
End;

{ Declaration d'un switch : table des adresses dans .data ; un
  designateur qui n'est pas une simple etiquette recoit un petit bloc
  de code (saute par un JMP) qui calcule la destination. }
Procedure GenSwitchDecl(S : Integer; Const Ds : Array Of Integer;
                        Count : Integer);
Var
  Entries : Array[0..MAX_SWITCH - 1] Of Integer;
  Stubs   : Array[0..MAX_SWITCH - 1] Of Integer;
  I, Lskip : Integer;
  AnyStub  : Boolean;
Begin
  AnyStub := False;
  For I := 0 To Count - 1 Do
    If ExprTab[Ds[I]].Kind = EX_LABEL Then
    Begin
      Entries[I] := Intern(SymTab[ExprTab[Ds[I]].Sym].Mangled);
      Stubs[I] := -1;
    End
    Else
    Begin
      Stubs[I] := NewLabel;
      Entries[I] := Stubs[I];
      AnyStub := True;
    End;
  If AnyStub Then
  Begin
    Lskip := NewLabel;
    Emit1(OP_JMP, OpLabel(Lskip));
    For I := 0 To Count - 1 Do
      If Stubs[I] >= 0 Then
      Begin
        EmitLabel(Stubs[I]);
        GenDesignator(Ds[I]);
      End;
    EmitLabel(Lskip);
  End;
  DataTable(Intern(SymTab[S].Mangled), Entries, Count);
End;

{ Declaration d'un tableau : remplit le descripteur a l'execution et,
  pour des bornes variables, alloue les donnees sur le tas. }
Procedure GenArrayDecl(S : Integer; Const NLo, NHi : Array Of Integer);
Var
  K, Dims, Es : Integer;
  Local       : Boolean;
  Base        : LongInt;

  Function Cell(Off : LongInt) : TOperand;
  Begin
    If Local Then
      Cell := OpMem(R_EBP, SymTab[S].ArrDescOfs + Off, 4)
    Else
      Cell := OpMemSym(DescName(S), Off, 4);
  End;

Begin
  Dims  := SymTab[S].ArrDims;
  Es    := TypeSizeof(SymTab[S].ElemType);
  Local := SymTab[S].Storage = SC_LOCAL;
  Emit(OP_MOV, Cell(4), OpImm(Dims));
  If Not SymTab[S].ArrDynamic Then
  Begin
    For K := 1 To Dims Do
    Begin
      Base := 8 + 12 * (K - 1);
      Emit(OP_MOV, Cell(Base), OpImm(SymTab[S].ArrLo[K]));
      Emit(OP_MOV, Cell(Base + 4), OpImm(SymTab[S].ArrHi[K]));
      Emit(OP_MOV, Cell(Base + 8), OpImm(KnownStride(S, K)));
    End;
    If Local Then
    Begin
      Emit(OP_LEA, OpReg(R_EAX),
           OpMem(R_EBP, SymTab[S].ArrDataOfs, 0));
      Emit(OP_MOV, Cell(0), OpReg(R_EAX));
    End
    Else
      Emit(OP_MOV, Cell(0), OpOffset(Intern(SymTab[S].Mangled)));
    Exit;
  End;
  { bornes a l'execution }
  For K := 1 To Dims Do
  Begin
    Base := 8 + 12 * (K - 1);
    If NLo[K - 1] >= 0 Then
      GenExprAs(NLo[K - 1], TY_IDX_INTEGER)
    Else
      LoadImm(R_EAX, SymTab[S].ArrLo[K]);
    Emit(OP_MOV, Cell(Base), OpReg(R_EAX));
    If NHi[K - 1] >= 0 Then
      GenExprAs(NHi[K - 1], TY_IDX_INTEGER)
    Else
      LoadImm(R_EAX, SymTab[S].ArrHi[K]);
    Emit(OP_MOV, Cell(Base + 4), OpReg(R_EAX));
  End;
  Emit(OP_MOV, OpReg(R_EAX), OpImm(1));
  For K := Dims Downto 1 Do
  Begin
    Base := 8 + 12 * (K - 1);
    Emit(OP_MOV, Cell(Base + 8), OpReg(R_EAX));         { pas }
    Emit(OP_MOV, OpReg(R_ECX), Cell(Base + 4));
    Emit(OP_SUB, OpReg(R_ECX), Cell(Base));
    Emit1(OP_INC, OpReg(R_ECX));
    Emit(OP_IMUL, OpReg(R_EAX), OpReg(R_ECX));          { elements }
  End;
  Emit(OP_MOV, OpReg(R_ECX), OpImm(Es));
  Emit(OP_IMUL, OpReg(R_EAX), OpReg(R_ECX));
  CallRT('ALLOC');
  Emit(OP_MOV, Cell(0), OpReg(R_EAX));
End;

{ Declare les donnees statiques d'un symbole (variable globale ou
  own, tableau a bornes constantes et descripteur) }
Procedure GenDeclareData(S : Integer);
Begin
  Case SymTab[S].Kind Of
    SK_VAR, SK_OWN:
      If SymTab[S].Storage = SC_GLOBAL Then
        DataAddZero(Intern(SymTab[S].Mangled),
                    TypeSizeof(SymTab[S].TypeIdx));
    SK_ARRAY:
      Begin
        If SymTab[S].Storage = SC_GLOBAL Then
        Begin
          If (Not SymTab[S].ArrDynamic) And (SymTab[S].ArrBytes > 0) Then
            DataAddZero(Intern(SymTab[S].Mangled), SymTab[S].ArrBytes);
          DataAddZero(DescName(S), 4 * (2 + 3 * SymTab[S].ArrDims));
        End;
      End;
  End;
End;

{ ---- Procedures : prologue et epilogue ---- }

Type
  TProcGen = Record
    Start     : LongInt;     { debut dans CodeTab }
    PatchSub  : LongInt;     { SUB ESP, taille }
    PatchMov  : LongInt;     { MOV ECX, taille / 4 }
  End;

Procedure GenProcBegin(Var PG : TProcGen; S : Integer);
Begin
  PG.Start := CodeCount;
  EmitBlank;
  EmitComment('procedure ' + SymTab[S].Name);
  EmitLabel(Intern(SymTab[S].Mangled));
  Emit1(OP_PUSH, OpReg(R_EBP));
  Emit(OP_MOV, OpReg(R_EBP), OpReg(R_ESP));
  PG.PatchSub := CodeCount;
  Emit(OP_SUB, OpReg(R_ESP), OpImm(0));
  { les locales sont mises a zero }
  Emit(OP_MOV, OpReg(R_EDI), OpReg(R_ESP));
  Emit(OP_XOR, OpReg(R_EAX), OpReg(R_EAX));
  PG.PatchMov := CodeCount;
  Emit(OP_MOV, OpReg(R_ECX), OpImm(0));
  Emit0(OP_REP_STOSD);
End;

{ A appeler avant SymLeaveScope : la taille du cadre est connue }
Procedure GenProcEnd(Var PG : TProcGen; S : Integer);
Var
  Frame : LongInt;
  I     : LongInt;
Begin
  Frame := SymFrameSize;
  If Frame = 0 Then
  Begin
    For I := PG.PatchSub To PG.PatchMov + 1 Do
      CodeTab[I].Op := OP_NOP;
  End
  Else
  Begin
    CodeTab[PG.PatchSub].B := OpImm(Frame);
    CodeTab[PG.PatchMov].B := OpImm(Frame Div 4);
  End;
  If SymTab[S].Kind = SK_FUNC Then
  Begin
    If IsRealT(SymTab[S].TypeIdx) Then
      Emit1(OP_FLD, OpMem(R_EBP, SymResultOfs, 8))
    Else
      Emit(OP_MOV, OpReg(R_EAX), OpMem(R_EBP, SymResultOfs, 4));
  End;
  Emit(OP_MOV, OpReg(R_ESP), OpReg(R_EBP));
  Emit1(OP_POP, OpReg(R_EBP));
  If SymTab[S].ParamBytes > 0 Then
    Emit1(OP_RET, OpImm(SymTab[S].ParamBytes))
  Else
    Emit0(OP_RET);
  MoveToDeferred(PG.Start);
End;

Procedure GenMainBegin;
Begin
  EmitComment('programme principal');
  EmitLabel(Intern(A58_MAIN_NAME));
  Emit1(OP_PUSH, OpReg(R_EBP));
  Emit(OP_MOV, OpReg(R_EBP), OpReg(R_ESP));
End;

Procedure GenMainEnd;
Begin
  Emit1(OP_PUSH, OpImm(0));
  Emit1(OP_CALL, OpLabel(Intern('ExitProcess')));
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
  If N >= 0 Then GenStmtExpr(N);
  If Not AtStmtEnd Then
  Begin
    If N >= 0 Then ParseError('operateur ou '';'' attendu');
    ParserSync;
  End;
End;

Procedure ParseBlock; Forward;

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
  { affectation d'un parametre par nom : les arguments doivent
    pouvoir etre ecrits (TODO 15) }
  If (ExprTab[Tgt].Kind = EX_VAR) And
     (SymTab[ExprTab[Tgt].Sym].Kind = SK_PARAM_NAME) Then
    SymTab[ExprTab[Tgt].Sym].IsWritten := True;
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
  Tok       : TToken;
  Tgt, N, S : Integer;
Begin
  Tok := CurToken;
  ParserAdvance;
  If AtPunct(':') Then
  Begin
    ParseLabelDef(Tok.Val, Tok.Line, Tok.Col);
    Exit;
  End;
  S := SymFind(Tok.Val);
  If (S < 0) And IsIOName(Tok.Val) And (Not AtOp(':=')) Then
  Begin
    ParseIO(Tok);
    Exit;
  End;
  If (S >= 0) And (SymTab[S].Kind In [SK_PROC, SK_FUNC]) And
     (Not AtOp(':=')) And (Not AtPunct('[')) Then
  Begin
    { appel de procedure comme instruction }
    ParserUnget(Tok);
    ExprReset;
    N := ParsePrimary;
    If N < 0 Then
      ParserSync
    Else
    Begin
      If Opts.DebugMode Then
      Begin
        WriteLn('Appel ligne ', ExprTab[N].Line, ' :');
        ExprDump(N, 1);
      End;
      GenStmtExpr(N);
      If Not AtStmtEnd Then
      Begin
        ParseError('operateur ou '';'' attendu apres l''appel');
        ParserSync;
      End;
    End;
    Exit;
  End;
  If Not (AtOp(':=') Or AtPunct('[')) Then
  Begin
    If AtPunct('(') Then
      ErrorAt(Tok.Line, Tok.Col, 'procedure inconnue: ' + Tok.Val)
    Else
      ErrorAt(Tok.Line, Tok.Col, 'instruction incorrecte apres ' +
              Tok.Val + ' (affectation, appel ou etiquette attendu)');
    ParserSync;
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
    GenStmtExpr(N);
    If Not AtStmtEnd Then
    Begin
      ParseError('operateur ou '';'' attendu');
      ParserSync;
    End;
  End;
End;

{ ---- Instructions de controle : if et for (TODO 12, 18) ---------- }

{ if condition then instruction [else instruction]
  Le else se rattache au if le plus proche (appel recursif). Code :
    saut vers Lelse si la condition est fausse ; then ; [JMP Lend ;
    Lelse : else ; Lend :]. }
Procedure ParseIf;
Var
  C         : Integer;
  Line      : Integer;
  Lelse, Lend : Integer;
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
  Lelse := NewLabel;
  If C >= 0 Then GenJump(C, Lelse, False);
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
    Lend := NewLabel;
    Emit1(OP_JMP, OpLabel(Lend));
    EmitLabel(Lelse);
    ParserAdvance;
    ParseStatement;
    EmitLabel(Lend);
  End
  Else
    EmitLabel(Lelse);
End;

Const
  MAX_FOR_CLAUSES = 16;

Type
  { Contexte d'une instruction for pendant l'analyse de sa liste.
    Disposition du code : les clauses d'abord (chacune saute vers le
    corps), puis le corps, puis le retour a la clause active, puis la
    sortie. }
  TForCtx = Record
    Valid     : Boolean;               { variable de boucle utilisable }
    Sym       : Integer;               { variable de boucle           }
    VT        : Integer;               { son type                     }
    Line, Col : Integer;
    LBody     : Integer;               { etiquette du corps           }
    LExit     : Integer;               { etiquette de sortie          }
    LEnd      : Integer;               { fin de la clause en cours    }
    Count     : Integer;               { clauses analysees            }
    Next      : Array[1..MAX_FOR_CLAUSES] Of Integer;
    HasSel    : Boolean;               { selecteur de clause alloue   }
    SelName   : Integer;               { selecteur global (niveau 0)  }
    SelOfs    : LongInt;               { ou local [EBP+SelOfs]        }
  End;

{ Cellule du selecteur de clause active (allouee a la demande) }
Function ForSelCell(Var C : TForCtx) : TOperand;
Begin
  If Not C.HasSel Then
  Begin
    C.HasSel := True;
    If CurLevel > 0 Then
    Begin
      C.SelName := -1;
      C.SelOfs  := SymAllocLocal(4);
    End
    Else
    Begin
      Inc(ConstSeq);
      C.SelName := Intern('_A58FSEL_' + ItoS(ConstSeq));
      DataAddZero(C.SelName, 4);
    End;
  End;
  If C.SelName >= 0 Then
    ForSelCell := OpMemSym(C.SelName, 0, 4)
  Else
    ForSelCell := OpMem(R_EBP, C.SelOfs, 4);
End;

{ variable de boucle := valeur }
Procedure ForAssign(Var C : TForCtx; Val : Integer);
Var
  A : Integer;
Begin
  A := ExprNew(EX_ASSIGN, C.VT, C.Line, C.Col);
  ExprTab[A].L := ExprMakeVar(C.Sym, C.Line, C.Col);
  ExprTab[A].R := Val;
  GenAssign(A, False);
End;

{ Compare la variable de boucle a Limit (Op = '>' ou '<') et saute
  vers Target quand la comparaison est vraie }
Procedure ForCompareJump(Var C : TForCtx; Const Op : TString;
                         Limit, Target : Integer);
Var
  Cmp : Integer;
Begin
  Cmp := ExprNew(EX_BINARY, TY_IDX_BOOLEAN, C.Line, C.Col);
  ExprTab[Cmp].Op := Op;
  ExprTab[Cmp].L  := ExprMakeVar(C.Sym, C.Line, C.Col);
  ExprTab[Cmp].R  := Limit;
  GenJump(Cmp, Target, True);
End;

{ Un element de liste de for : valeur, step-until ou while. }
Procedure ParseForClause(Var C : TForCtx);
Var
  E1, E2, E3, Cd : Integer;
  Conv           : TConv;
  Line, Col      : Integer;
  Empty, Multi   : Boolean;
  Lnext, Ltest   : Integer;
  Lneg, Lcont    : Integer;
  Plus, A, Z, Sg : Integer;
  Kind           : Integer;      { 1 valeur, 2 step-until, 3 while }
  Good           : Boolean;
Begin
  ExprReset;
  Inc(C.Count);
  Line := CurToken.Line;
  Col  := CurToken.Col;
  E1 := ParseExpr;
  If E1 >= 0 Then
    If Not ExprCoerce(E1, C.VT, Conv, Line, Col) Then E1 := -1;
  E2 := -1;
  E3 := -1;
  Cd := -1;
  Kind := 1;
  Good := E1 >= 0;

  If AtKw('step') Then
  Begin
    Kind := 2;
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
    Good := Good And (E2 >= 0) And (E3 >= 0);
    If Good Then
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
    Kind := 3;
    ParserAdvance;
    Cd := ParseCondition;
    Good := Good And (Cd >= 0);
    If Good And Opts.DebugMode Then
    Begin
      WriteLn('  clause while :');
      WriteLn('    init :');  ExprDump(E1, 3);
      WriteLn('    while :'); ExprDump(Cd, 3);
    End;
    If (Cd >= 0) And (ExprTab[Cd].Kind = EX_BOOL) And
       (ExprTab[Cd].IntVal = 0) Then
      WarnAt(Line, Col, 'condition toujours fausse: ' +
             'boucle jamais executee');
  End
  Else If Good And Opts.DebugMode Then
  Begin
    WriteLn('  clause valeur :');
    ExprDump(E1, 2);
  End;

  { fin de la clause : cible des sauts "clause epuisee" }
  C.LEnd := NewLabel;
  If C.Count <= MAX_FOR_CLAUSES Then C.Next[C.Count] := C.LEnd
  Else ErrorAt(Line, Col, 'trop de clauses dans le for');
  If (Not Good) Or (Not C.Valid) Or (C.Count > MAX_FOR_CLAUSES) Then
    Exit;
  Multi := (C.Count > 1) Or AtPunct(',');

  Case Kind Of
    1:
      Begin
        ForAssign(C, E1);
        If Multi Then
          Emit(OP_MOV, ForSelCell(C), OpImm(C.Count));
        Emit1(OP_JMP, OpLabel(C.LBody));
      End;
    2:
      Begin
        Lnext := NewLabel;
        Ltest := NewLabel;
        C.Next[C.Count] := Lnext;
        ForAssign(C, E1);
        Emit1(OP_JMP, OpLabel(Ltest));
        EmitLabel(Lnext);
        { variable := variable + pas }
        Plus := ExprNew(EX_BINARY, TypeArith(C.VT, ExprTab[E2].Typ),
                        C.Line, C.Col);
        ExprTab[Plus].Op := '+';
        ExprTab[Plus].L  := ExprMakeVar(C.Sym, C.Line, C.Col);
        ExprTab[Plus].R  := E2;
        A := ExprNew(EX_ASSIGN, C.VT, C.Line, C.Col);
        ExprTab[A].L := ExprMakeVar(C.Sym, C.Line, C.Col);
        ExprTab[A].R := Plus;
        GenAssign(A, False);
        EmitLabel(Ltest);
        { clause epuisee quand la variable depasse la limite dans le
          sens du pas }
        If ExprIsConst(E2) Then
        Begin
          If ExprConstReal(E2) > 0 Then
            ForCompareJump(C, '>', E3, C.LEnd)
          Else
            ForCompareJump(C, '<', E3, C.LEnd);
        End
        Else
        Begin
          Lneg  := NewLabel;
          Lcont := NewLabel;
          Z  := ExprMakeInt(0, C.Line, C.Col);
          Sg := ExprNew(EX_BINARY, TY_IDX_BOOLEAN, C.Line, C.Col);
          ExprTab[Sg].Op := '>=';
          ExprTab[Sg].L  := E2;
          ExprTab[Sg].R  := Z;
          GenJump(Sg, Lneg, False);
          ForCompareJump(C, '>', E3, C.LEnd);
          Emit1(OP_JMP, OpLabel(Lcont));
          EmitLabel(Lneg);
          ForCompareJump(C, '<', E3, C.LEnd);
          EmitLabel(Lcont);
        End;
        If Multi Then
          Emit(OP_MOV, ForSelCell(C), OpImm(C.Count));
        Emit1(OP_JMP, OpLabel(C.LBody));
      End;
    3:
      Begin
        Lnext := NewLabel;
        C.Next[C.Count] := Lnext;
        EmitLabel(Lnext);
        ForAssign(C, E1);
        GenJump(Cd, C.LEnd, False);
        If Multi Then
          Emit(OP_MOV, ForSelCell(C), OpImm(C.Count));
        Emit1(OP_JMP, OpLabel(C.LBody));
      End;
  End;
End;

{ for v := e1, e2 step e3 until e4, e5 while c do instruction
  Chaque element de la liste est une valeur, un step-until ou un
  while ; ils sont executes dans l'ordre (le corps est partage). }
Procedure ParseFor;
Var
  Tgt       : Integer;
  Line, Col : Integer;
  Ctx       : TForCtx;
  K         : Integer;
Begin
  Inc(ForCount);
  FillChar(Ctx, SizeOf(Ctx), 0);
  Ctx.Sym := -1;
  Ctx.VT  := TY_UNKNOWN;
  Line := CurToken.Line;
  ParserAdvance;                          { for }
  ExprReset;
  Col := CurToken.Col;
  Tgt := ParsePrimary;
  If Tgt >= 0 Then
  Begin
    If ExprTab[Tgt].Kind <> EX_VAR Then
    Begin
      ErrorAt(Line, Col, 'variable de boucle simple attendue');
    End
    Else
    Begin
      Ctx.Sym := ExprTab[Tgt].Sym;
      Ctx.VT  := ExprTab[Tgt].Typ;
      If Not TypeIsNumeric(Ctx.VT) Then
      Begin
        ErrorAt(Line, Col, 'variable de boucle numerique attendue ' +
                '(type: ' + TypeName(Ctx.VT) + ')');
        Ctx.VT := TY_UNKNOWN;
      End
      Else
      Begin
        Ctx.Valid := True;
        If SymTab[Ctx.Sym].Kind = SK_PARAM_NAME Then
          SymTab[Ctx.Sym].IsWritten := True;      { variable de boucle }
        If Opts.DebugMode Then
          WriteLn('For ligne ', Line, ' : variable ',
                  SymTab[Ctx.Sym].Name, ' (', TypeName(Ctx.VT), ')');
      End;
    End;
  End;
  Ctx.Line := Line;
  Ctx.Col  := Col;
  If AtOp(':=') Then
    ParserAdvance
  Else
  Begin
    ParseError(''':='' attendu apres la variable de boucle');
    ParserSync;
    Exit;
  End;
  Ctx.LBody := NewLabel;
  Ctx.LExit := NewLabel;

  If LoopDepth >= MAX_LOOP_NEST Then
    ErrorAt(Line, Col, 'boucles trop imbriquees (max ' +
            ItoS(MAX_LOOP_NEST) + ')');
  Inc(LoopDepth);
  Repeat
    ParseForClause(Ctx);
    EmitLabel(Ctx.LEnd);                  { fin de la clause }
    If AtPunct(',') Then
      ParserAdvance
    Else
      Break;
  Until False;
  { toutes les clauses epuisees : sortie ; sinon le corps }
  Emit1(OP_JMP, OpLabel(Ctx.LExit));
  EmitLabel(Ctx.LBody);
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
  { retour a la clause active }
  If Ctx.Valid Then
  Begin
    If Ctx.Count <= 1 Then
      Emit1(OP_JMP, OpLabel(Ctx.Next[1]))
    Else
    Begin
      Emit(OP_MOV, OpReg(R_EAX), ForSelCell(Ctx));
      For K := 1 To Ctx.Count - 1 Do
      Begin
        Emit(OP_CMP, OpReg(R_EAX), OpImm(K));
        Emit1(OP_JE, OpLabel(Ctx.Next[K]));
      End;
      Emit1(OP_JMP, OpLabel(Ctx.Next[Ctx.Count]));
    End;
  End;
  EmitLabel(Ctx.LExit);
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
  GenDesignator(D);
  If Not AtStmtEnd Then
  Begin
    ParseError('operateur ou '';'' attendu apres go to');
    ParserSync;
  End;
End;

{ etiquette : instruction   (Name = nom ou nombre, ':' est le token
  courant). L'instruction suivante peut etre vide ou un bloc. }
Procedure ParseLabelDef(Const Name : TString; Line, Col : Integer);
Var
  S : Integer;
Begin
  S := SymDefLabel(Name, Line, Col);
  EmitLabel(Intern(SymTab[S].Mangled));
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

{ ---- Entrees/sorties : write, writeln, read, readln (TODO 16) ----- }

{ write(a, b, ...) / writeln(...) / read(v, ...) / readln(...)
  Tok = le nom, deja consomme ; ce ne sont pas des mots reserves : une
  declaration du programme du meme nom reste prioritaire.
  write : chaine, integer, real ou Boolean (true / false). Les entiers
    et booleens constants sont convertis en texte a la compilation et
    fusionnes avec les chaines voisines ("x=", 5 devient "x=5").
  read : variables numeriques ou Boolean, elements de tableau ou
    parametres par nom (marques ecrits).
  writeln ajoute CR LF ; readln consomme le reste de la ligne.
  Le format des reels est fixe par le runtime (TODO 22). }
Procedure ParseIO(Const Tok : TToken);
Var
  Key                 : TString;
  IsWrite, NL         : Boolean;
  Head, Tail, Item, E : Integer;
  N, Node             : Integer;
  Line, Col           : Integer;
  Txt                 : TString;
Begin
  Inc(IOCount);
  Key     := UpCaseStr(Tok.Val);
  IsWrite := (Key = 'WRITE') Or (Key = 'WRITELN');
  NL      := (Key = 'WRITELN') Or (Key = 'READLN');
  Head := -1;
  Tail := -1;
  N    := 0;
  ExprReset;
  If AtPunct('(') Then
  Begin
    ParserAdvance;
    If Not AtPunct(')') Then
      Repeat
        Line := CurToken.Line;
        Col  := CurToken.Col;
        E := ParseExprPrec(1);
        If E < 0 Then
        Begin
          ParserSync;
          Exit;
        End;
        If IsWrite Then
        Begin
          If Not ((ExprTab[E].Typ = TY_IDX_STRING) Or
                  TypeIsArith(ExprTab[E].Typ)) Then
          Begin
            ErrorAt(Line, Col, Tok.Val + ': type non imprimable (' +
                    TypeName(ExprTab[E].Typ) + ')');
            ParserSync;
            Exit;
          End;
          { constante entiere ou booleenne -> texte }
          If ExprTab[E].Kind In [EX_INT, EX_BOOL] Then
          Begin
            If ExprTab[E].Kind = EX_BOOL Then
              If ExprTab[E].IntVal <> 0 Then Txt := 'true'
              Else Txt := 'false'
            Else
              Txt := ItoS(ExprTab[E].IntVal);
            ExprTab[E].Kind   := EX_STR;
            ExprTab[E].Typ    := TY_IDX_STRING;
            ExprTab[E].StrIdx := ExprAddStr(Txt);
          End;
        End
        Else
        Begin
          If Not (ExprTab[E].Kind In [EX_VAR, EX_INDEX]) Then
          Begin
            ErrorAt(Line, Col, Tok.Val + ': variable attendue');
            ParserSync;
            Exit;
          End;
          If Not (TypeIsArith(ExprTab[E].Typ)) Then
          Begin
            ErrorAt(Line, Col, Tok.Val + ': type non lisible (' +
                    TypeName(ExprTab[E].Typ) + ')');
            ParserSync;
            Exit;
          End;
          If (ExprTab[E].Kind = EX_VAR) And
             (SymTab[ExprTab[E].Sym].Kind = SK_PARAM_NAME) Then
            SymTab[ExprTab[E].Sym].IsWritten := True;
        End;
        { fusion de deux chaines consecutives }
        If IsWrite And (Tail >= 0) And (ExprTab[E].Kind = EX_STR) And
           (ExprTab[ExprTab[Tail].L].Kind = EX_STR) And
           (Length(ExprStrTab[ExprTab[ExprTab[Tail].L].StrIdx]) +
            Length(ExprStrTab[ExprTab[E].StrIdx]) <= MAX_STR) Then
          ExprStrTab[ExprTab[ExprTab[Tail].L].StrIdx] :=
            ExprStrTab[ExprTab[ExprTab[Tail].L].StrIdx] +
            ExprStrTab[ExprTab[E].StrIdx]
        Else
        Begin
          Item := ExprNew(EX_LIST, ExprTab[E].Typ, Line, Col);
          ExprTab[Item].L := E;
          If Head < 0 Then Head := Item Else ExprTab[Tail].R := Item;
          Tail := Item;
          Inc(N);
        End;
        If AtPunct(',') Then
          ParserAdvance
        Else
          Break;
      Until False;
    ExpectPunct(')');
  End;
  If IsWrite Then
    Node := ExprNew(EX_WRITE, TY_IDX_PROCEDURE, Tok.Line, Tok.Col)
  Else
    Node := ExprNew(EX_READ, TY_IDX_PROCEDURE, Tok.Line, Tok.Col);
  ExprTab[Node].L      := Head;
  ExprTab[Node].IntVal := N;
  ExprTab[Node].Flag   := NL;
  If Opts.DebugMode Then
  Begin
    WriteLn('E/S ligne ', Tok.Line, ' :');
    ExprDump(Node, 1);
  End;
  GenStmtExpr(Node);
  If Not AtStmtEnd Then
  Begin
    ParseError('operateur ou '';'' attendu apres ' + Tok.Val);
    ParserSync;
  End;
End;

{ ---- Declarations ----------------------------------------------- }

{ integer a, b, c   (declaration de variables, own ou non) }
Procedure ParseVarList(K : TSymKind; T : Integer; IsOwn : Boolean);
Var
  Done : Boolean;
  S    : Integer;
Begin
  Repeat
    If CurToken.Kind <> TK_IDENT Then
    Begin
      ParseError('identificateur attendu dans la declaration');
      ParserSync;
      Exit;
    End;
    S := SymAdd(CurToken.Val, K, T, IsOwn, CurToken.Line, CurToken.Col);
    GenDeclareData(S);
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
      If SymTab[Cur].ArrDims > 0 Then
      Begin
        If SymTab[Cur].Storage = SC_LOCAL Then
          SymTab[Cur].ArrDescOfs :=
            SymAllocLocal(4 * (2 + 3 * SymTab[Cur].ArrDims));
        GenDeclareData(Cur);
        GenArrayDecl(Cur, NLo, NHi);
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
  Ds      : Array[0..MAX_SWITCH - 1] Of Integer;
  Failed  : Boolean;
Begin
  Failed := False;
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
      Failed := True;
      ParserSync;
      Break;
    End;
    If N > MAX_SWITCH Then
    Begin
      ErrorAt(CurToken.Line, CurToken.Col, 'switch trop long (max ' +
              ItoS(MAX_SWITCH) + ')');
      Failed := True;
      ParserSync;
      Break;
    End;
    Ds[N - 1] := D;
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
  If Not Failed Then GenSwitchDecl(S, Ds, N);
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
  PG      : TProcGen;
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

  GenProcBegin(PG, P);
  ParseStatement;                { corps de la procedure }
  GenProcEnd(PG, P);
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
  Begin
    ParseError('instruction attendue');
    ParserSync;
  End;
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
  CallCount  := 0;
  ThunkCount := 0;
  IOCount    := 0;
  IntrinCount := 0;
  LabelCount := 0;
  ForCount   := 0;
  LoopDepth  := 0;
  ParkValid  := False;
  SyncLine   := 0;
  SyncCol    := 0;
  LexQuiet   := True;            { erreurs lexicales deja signalees }
  LexInit;
  CodeInit;
  SymEnterScope;                 { portee globale (identifiant 1) }
  GenMainBegin;
  ParseProgram;
  GenMainEnd;
  SymLeaveScope;
  LexClose;
  If Opts.Verbose Then
    WriteLn('  ', DeclCount, ' declaration(s), ', ProcCount,
            ' procedure(s), ', BlockCount, ' bloc(s), ', AssignCount,
            ' affectation(s), ', IfCount, ' if, ', ForCount, ' for, ',
            GotoCount, ' goto, ', LabelCount, ' etiquette(s), ',
            CallCount, ' appel(s), ', ThunkCount, ' thunk(s), ',
            IOCount, ' e/s, ', IntrinCount, ' intrinseque(s), ',
            FoldCount, ' constante(s) repliee(s)');
End;

{ ============================================================
  SECTION 9 - CODE INTERNE ET LISTING ASM OPTIONNEL (TODO 18)
  ============================================================ }
Procedure PhaseCodegen;
Begin
  If Opts.Verbose Then
    WriteLn('  ', CodeCount + DeferCount, ' instruction(s), ',
            DataCount, ' donnee(s) statique(s), ', NameCount,
            ' nom(s) interne(s)');
  If Opts.DebugMode Then
  Begin
    WriteLn('Code interne (', CodeCount + DeferCount, ' entrees) :');
    WriteInstrList(Output, CodeTab, CodeCount);
    WriteInstrList(Output, DeferTab, DeferCount);
  End;
  If Opts.EmitAsm Then
  Begin
    WriteListing(Opts.AsmFile);
    If Opts.Verbose Then WriteLn('  listing : ', Opts.AsmFile);
  End;
End;

{ ============================================================
  SECTION 10 - ENCODEUR BINAIRE x86-32 (TODO 19)
  ============================================================ }
Type
  TBinFixKind = (
    BF_REL32,      { deplacement relatif (cible externe) }
    BF_ABS32       { adresse absolue de Sym (+ valeur en place) }
  );

  TBinFix = Record
    Sect : Byte;           { 0 = code, 1 = donnees : ou se trouve le champ }
    Off  : LongInt;
    Kind : TBinFixKind;
    Sym  : Integer;        { nom (NameTab) de la cible }
  End;

  TBinLabel = Record
    Sect : Byte;           { 0 = non defini (externe), 1 = code, 2 = donnees }
    Off  : LongInt;
  End;

  { Resultat du codage d'une instruction }
  TEnc = Record
    Len     : Integer;
    B       : Array[0..15] Of Byte;
    NFix    : Integer;
    FixPos  : Array[1..2] Of Integer;
    FixSym  : Array[1..2] Of Integer;
    RelPos  : Integer;     { position du deplacement relatif (-1 : aucun) }
    RelSize : Integer;     { 1 ou 4 octets }
    RelSym  : Integer;     { etiquette cible }
  End;

Var
  BinCode     : Array[0..MAX_BIN_CODE - 1] Of Byte;
  BinCodeLen  : LongInt;
  BinData     : Array[0..MAX_BIN_DATA - 1] Of Byte;
  BinDataLen  : LongInt;
  BinLbl      : Array[0..MAX_NAMES - 1] Of TBinLabel;
  BinFix      : Array[0..MAX_BIN_FIX - 1] Of TBinFix;
  BinFixCount : LongInt;
  BinImport   : Array[0..255] Of Integer;     { noms importes (externes) }
  BinImportCount : Integer;
  InstrOff    : Array[0..2 * MAX_CODE] Of LongInt;
  InstrNear   : Array[0..2 * MAX_CODE - 1] Of Boolean;
  Enc         : TEnc;

Function InstrAt(I : LongInt) : TInstr;
Begin
  If I < CodeCount Then
    InstrAt := CodeTab[I]
  Else
    InstrAt := DeferTab[I - CodeCount];
End;

{ ---- Primitives de codage ---- }

Procedure PutB(V : LongInt);
Begin
  Enc.B[Enc.Len] := V And $FF;
  Inc(Enc.Len);
End;

Procedure PutD(V : LongInt);
Begin
  PutB(V);
  PutB(V Shr 8);
  PutB(V Shr 16);
  PutB(V Shr 24);
End;

Procedure PutW(V : LongInt);
Begin
  PutB(V);
  PutB(V Shr 8);
End;

{ Champ de 32 bits qui sera corrige par l'ecrivain (adresse de Sym) }
Procedure PutAbs(Sym : Integer; Addend : LongInt);
Begin
  Inc(Enc.NFix);
  Enc.FixPos[Enc.NFix] := Enc.Len;
  Enc.FixSym[Enc.NFix] := Sym;
  PutD(Addend);
End;

Function RegCode(R : TReg) : Integer;
Begin
  If R >= R_EAX Then
  Begin
    If R <= R_EDI Then
      RegCode := Ord(R) - Ord(R_EAX)
    Else If R = R_AX Then
      RegCode := 0
    Else
      RegCode := Ord(R) - Ord(R_AL);
  End
  Else
    RegCode := 0;
End;

Function RegSize(R : TReg) : Integer;
Begin
  If (R >= R_EAX) And (R <= R_EDI) Then
    RegSize := 4
  Else If R = R_AX Then
    RegSize := 2
  Else
    RegSize := 1;
End;

Function Fits8(V : LongInt) : Boolean;
Begin
  Fits8 := (V >= -128) And (V <= 127);
End;

Function ScaleBits(S : Byte) : Integer;
Begin
  Case S Of
    2 : ScaleBits := 1;
    4 : ScaleBits := 2;
    8 : ScaleBits := 3;
  Else
    ScaleBits := 0;
  End;
End;

{ ModRM (+ SIB + deplacement) pour un operande memoire }
Procedure EncMem(RegField : Integer; Const M : TOperand);
Var
  HasBase, HasIdx, HasSym : Boolean;
  Md, Bc                  : Integer;
Begin
  HasBase := M.Base <> R_NONE;
  HasIdx  := M.Index <> R_NONE;
  HasSym  := M.Sym >= 0;
  If (Not HasBase) And (Not HasIdx) Then
  Begin
    PutB((RegField Shl 3) Or 5);
    If HasSym Then PutAbs(M.Sym, M.Imm) Else PutD(M.Imm);
    Exit;
  End;
  { choix du mode de deplacement }
  If HasSym Then
    Md := 2
  Else If (M.Imm = 0) And HasBase And (M.Base <> R_EBP) Then
    Md := 0
  Else If Fits8(M.Imm) Then
    Md := 1
  Else
    Md := 2;
  If Not HasBase Then
  Begin
    { [sym + index*scale + disp32] }
    PutB((RegField Shl 3) Or 4);
    PutB((ScaleBits(M.Scale) Shl 6) Or (RegCode(M.Index) Shl 3) Or 5);
    If HasSym Then PutAbs(M.Sym, M.Imm) Else PutD(M.Imm);
    Exit;
  End;
  Bc := RegCode(M.Base);
  If HasIdx Then
  Begin
    PutB((Md Shl 6) Or (RegField Shl 3) Or 4);
    PutB((ScaleBits(M.Scale) Shl 6) Or (RegCode(M.Index) Shl 3) Or Bc);
  End
  Else If M.Base = R_ESP Then
  Begin
    PutB((Md Shl 6) Or (RegField Shl 3) Or 4);
    PutB($24);
  End
  Else
    PutB((Md Shl 6) Or (RegField Shl 3) Or Bc);
  If Md = 1 Then
    PutB(M.Imm)
  Else If Md = 2 Then
  Begin
    If HasSym Then PutAbs(M.Sym, M.Imm) Else PutD(M.Imm);
  End;
End;

{ ModRM pour un operande registre ou memoire (champ r/m) }
Procedure EncRM(RegField : Integer; Const O : TOperand);
Begin
  If O.Kind = OK_REG Then
    PutB($C0 Or (RegField Shl 3) Or RegCode(O.Reg))
  Else If O.Kind = OK_MEM Then
    EncMem(RegField, O)
  Else
    FatalError('encodeur: operande r/m invalide');
End;

{ Taille de l'operation : registre en priorite, sinon la memoire }
Function OpSize(Const A, B : TOperand) : Integer;
Begin
  If A.Kind = OK_REG Then
    OpSize := RegSize(A.Reg)
  Else If B.Kind = OK_REG Then
    OpSize := RegSize(B.Reg)
  Else If (A.Kind = OK_MEM) And (A.Size > 0) Then
    OpSize := A.Size
  Else If (B.Kind = OK_MEM) And (B.Size > 0) Then
    OpSize := B.Size
  Else
    OpSize := 4;
End;

Function CcOf(Op : TOp) : Integer;
Begin
  Case Op Of
    OP_SETE,  OP_JE  : CcOf := 4;
    OP_SETNE, OP_JNE : CcOf := 5;
    OP_SETL,  OP_JL  : CcOf := 12;
    OP_SETLE, OP_JLE : CcOf := 14;
    OP_SETG,  OP_JG  : CcOf := 15;
    OP_SETGE, OP_JGE : CcOf := 13;
    OP_SETA,  OP_JA  : CcOf := 7;
    OP_SETAE, OP_JAE : CcOf := 3;
    OP_SETB,  OP_JB  : CcOf := 2;
    OP_SETBE, OP_JBE : CcOf := 6;
    OP_JS            : CcOf := 8;
    OP_JNS           : CcOf := 9;
  Else
    CcOf := 0;
  End;
End;

Function AluNum(Op : TOp) : Integer;
Begin
  Case Op Of
    OP_ADD : AluNum := 0;
    OP_OR  : AluNum := 1;
    OP_AND : AluNum := 4;
    OP_SUB : AluNum := 5;
    OP_XOR : AluNum := 6;
    OP_CMP : AluNum := 7;
  Else
    AluNum := 0;
  End;
End;

Procedure EncBad(Const I : TInstr);
Begin
  FatalError('encodeur: forme d''instruction non supportee: ' +
             InstrText(I));
End;

{ ADD OR AND SUB XOR CMP }
Procedure EncAlu(Const I : TInstr);
Var
  N, Sz : Integer;
Begin
  N  := AluNum(I.Op);
  Sz := OpSize(I.A, I.B);
  If Sz = 2 Then PutB($66);
  If I.B.Kind = OK_IMM Then
  Begin
    If Sz = 1 Then
    Begin
      PutB($80);
      EncRM(N, I.A);
      PutB(I.B.Imm);
    End
    Else If Fits8(I.B.Imm) Then
    Begin
      PutB($83);
      EncRM(N, I.A);
      PutB(I.B.Imm);
    End
    Else
    Begin
      PutB($81);
      EncRM(N, I.A);
      If Sz = 2 Then PutW(I.B.Imm) Else PutD(I.B.Imm);
    End;
  End
  Else If (I.A.Kind = OK_REG) And (I.B.Kind In [OK_REG, OK_MEM]) Then
  Begin
    { reg, r/m : opcode base + 2 (8 bits) ou + 3 }
    If Sz = 1 Then PutB(N * 8 + 2) Else PutB(N * 8 + 3);
    EncRM(RegCode(I.A.Reg), I.B);
  End
  Else If (I.A.Kind = OK_MEM) And (I.B.Kind = OK_REG) Then
  Begin
    If Sz = 1 Then PutB(N * 8) Else PutB(N * 8 + 1);
    EncMem(RegCode(I.B.Reg), I.A);
  End
  Else
    EncBad(I);
End;

Procedure EncMov(Const I : TInstr);
Var
  Sz : Integer;
Begin
  Sz := OpSize(I.A, I.B);
  If Sz = 2 Then PutB($66);
  If (I.A.Kind = OK_REG) And (I.B.Kind = OK_IMM) Then
  Begin
    If Sz = 1 Then
    Begin
      PutB($B0 + RegCode(I.A.Reg));
      PutB(I.B.Imm);
    End
    Else
    Begin
      PutB($B8 + RegCode(I.A.Reg));
      If Sz = 2 Then PutW(I.B.Imm) Else PutD(I.B.Imm);
    End;
  End
  Else If (I.A.Kind = OK_REG) And (I.B.Kind = OK_OFFSET) Then
  Begin
    PutB($B8 + RegCode(I.A.Reg));
    PutAbs(I.B.Sym, I.B.Imm);
  End
  Else If (I.A.Kind = OK_REG) And (I.B.Kind = OK_REG) Then
  Begin
    If Sz = 1 Then PutB($88) Else PutB($89);
    PutB($C0 Or (RegCode(I.B.Reg) Shl 3) Or RegCode(I.A.Reg));
  End
  Else If (I.A.Kind = OK_REG) And (I.B.Kind = OK_MEM) Then
  Begin
    If Sz = 1 Then PutB($8A) Else PutB($8B);
    EncMem(RegCode(I.A.Reg), I.B);
  End
  Else If (I.A.Kind = OK_MEM) And (I.B.Kind = OK_REG) Then
  Begin
    If Sz = 1 Then PutB($88) Else PutB($89);
    EncMem(RegCode(I.B.Reg), I.A);
  End
  Else If (I.A.Kind = OK_MEM) And (I.B.Kind = OK_IMM) Then
  Begin
    If Sz = 1 Then
    Begin
      PutB($C6);
      EncMem(0, I.A);
      PutB(I.B.Imm);
    End
    Else
    Begin
      PutB($C7);
      EncMem(0, I.A);
      If Sz = 2 Then PutW(I.B.Imm) Else PutD(I.B.Imm);
    End;
  End
  Else If (I.A.Kind = OK_MEM) And (I.B.Kind = OK_OFFSET) Then
  Begin
    PutB($C7);
    EncMem(0, I.A);
    PutAbs(I.B.Sym, I.B.Imm);
  End
  Else
    EncBad(I);
End;

{ Instructions a un seul operande r/m : IDIV DIV NEG NOT (F7 /n),
  INC DEC (FF /n ou 40+r / 48+r) }
Procedure EncUnary(Const I : TInstr; Digit : Integer);
Begin
  PutB($F7);
  EncRM(Digit, I.A);
End;

Procedure EncIncDec(Const I : TInstr; Digit : Integer);
Begin
  If (I.A.Kind = OK_REG) And (RegSize(I.A.Reg) = 4) Then
    PutB($40 + Digit * 8 + RegCode(I.A.Reg))
  Else
  Begin
    PutB($FF);
    EncRM(Digit, I.A);
  End;
End;

Procedure EncShift(Const I : TInstr; Digit : Integer);
Begin
  If I.B.Kind <> OK_IMM Then EncBad(I);
  If I.B.Imm = 1 Then
  Begin
    PutB($D1);
    EncRM(Digit, I.A);
  End
  Else
  Begin
    PutB($C1);
    EncRM(Digit, I.A);
    PutB(I.B.Imm);
  End;
End;

{ Instructions x87 a operande memoire ou ST(i) }
Procedure EncFpu(Const I : TInstr);
Var
  Sz, Digit, Op32, Op64, StOp : Integer;
  HasSt                      : Boolean;
Begin
  { Digit : champ /n ; Op32 / Op64 : opcodes memoire ; StOp : second
    octet (forme ST) = base + i }
  Digit := 0; Op32 := 0; Op64 := 0; StOp := -1;
  HasSt := (I.A.Kind = OK_ST);
  Case I.Op Of
    OP_FLD   :
      Begin
        If HasSt Then Begin PutB($D9); PutB($C0 + I.A.Imm); Exit; End;
        Digit := 0; Op32 := $D9; Op64 := $DD;
      End;
    OP_FST   :
      Begin
        If HasSt Then Begin PutB($DD); PutB($D0 + I.A.Imm); Exit; End;
        Digit := 2; Op32 := $D9; Op64 := $DD;
      End;
    OP_FSTP  :
      Begin
        If HasSt Then Begin PutB($DD); PutB($D8 + I.A.Imm); Exit; End;
        Digit := 3; Op32 := $D9; Op64 := $DD;
      End;
    OP_FILD  :
      Begin
        Sz := I.A.Size;
        If Sz = 2 Then PutB($DF) Else If Sz = 8 Then PutB($DF)
        Else PutB($DB);
        If Sz = 8 Then EncMem(5, I.A) Else EncMem(0, I.A);
        Exit;
      End;
    OP_FISTP :
      Begin
        Sz := I.A.Size;
        If Sz = 2 Then PutB($DF) Else If Sz = 8 Then PutB($DF)
        Else PutB($DB);
        If Sz = 8 Then EncMem(7, I.A) Else EncMem(3, I.A);
        Exit;
      End;
    OP_FADD, OP_FMUL, OP_FSUB, OP_FSUBR, OP_FDIV, OP_FDIVR,
    OP_FCOM, OP_FCOMP:
      Begin
        Case I.Op Of
          OP_FADD  : Digit := 0;
          OP_FMUL  : Digit := 1;
          OP_FCOM  : Digit := 2;
          OP_FCOMP : Digit := 3;
          OP_FSUB  : Digit := 4;
          OP_FSUBR : Digit := 5;
          OP_FDIV  : Digit := 6;
          OP_FDIVR : Digit := 7;
        End;
        If HasSt Then
        Begin
          If I.Op = OP_FCOM Then
          Begin
            PutB($D8); PutB($D0 + I.A.Imm); Exit;
          End;
          If I.Op = OP_FCOMP Then
          Begin
            PutB($D8); PutB($D8 + I.A.Imm); Exit;
          End;
          { forme ST(i), ST(0) : DC + base }
          PutB($DC);
          Case I.Op Of
            OP_FADD  : PutB($C0 + I.A.Imm);
            OP_FMUL  : PutB($C8 + I.A.Imm);
            OP_FSUBR : PutB($E0 + I.A.Imm);
            OP_FSUB  : PutB($E8 + I.A.Imm);
            OP_FDIVR : PutB($F0 + I.A.Imm);
            OP_FDIV  : PutB($F8 + I.A.Imm);
          End;
          Exit;
        End;
        Op32 := $D8; Op64 := $DC;
      End;
    OP_FNSTCW: Begin PutB($D9); EncMem(7, I.A); Exit; End;
    OP_FLDCW : Begin PutB($D9); EncMem(5, I.A); Exit; End;
    OP_FXCH  : Begin PutB($D9); PutB($C8 + I.A.Imm); Exit; End;
    OP_FADDP : Begin PutB($DE); PutB($C0 + I.A.Imm); Exit; End;
    OP_FMULP : Begin PutB($DE); PutB($C8 + I.A.Imm); Exit; End;
    OP_FSUBP : Begin PutB($DE); PutB($E8 + I.A.Imm); Exit; End;
    OP_FDIVP : Begin PutB($DE); PutB($F8 + I.A.Imm); Exit; End;
    OP_FNSTSW: Begin PutB($DF); PutB($E0); Exit; End;
  End;
  If I.A.Kind <> OK_MEM Then EncBad(I);
  If I.A.Size = 4 Then
  Begin
    PutB(Op32);
    EncMem(Digit, I.A);
  End
  Else If I.A.Size = 8 Then
  Begin
    PutB(Op64);
    EncMem(Digit, I.A);
  End
  Else
    EncBad(I);
  StOp := StOp + 0;
End;

Procedure EncodeInstr(Const I : TInstr; Near : Boolean);
Var
  Sz, Cc : Integer;
Begin
  Enc.Len := 0;
  Enc.NFix := 0;
  Enc.RelPos := -1;
  Enc.RelSize := 0;
  Enc.RelSym := -1;
  Case I.Op Of
    OP_NOP, OP_LABEL, OP_COMMENT, OP_BLANK: ;
    OP_MOV : EncMov(I);
    OP_MOVZX:
      Begin
        If (I.B.Kind = OK_REG) And (RegSize(I.B.Reg) = 1) Or
           ((I.B.Kind = OK_MEM) And (I.B.Size = 1)) Then
        Begin
          PutB($0F); PutB($B6);
        End
        Else
        Begin
          PutB($0F); PutB($B7);
        End;
        EncRM(RegCode(I.A.Reg), I.B);
      End;
    OP_LEA :
      Begin
        PutB($8D);
        EncMem(RegCode(I.A.Reg), I.B);
      End;
    OP_PUSH:
      Case I.A.Kind Of
        OK_REG    : PutB($50 + RegCode(I.A.Reg));
        OK_IMM    :
          If Fits8(I.A.Imm) Then
          Begin
            PutB($6A); PutB(I.A.Imm);
          End
          Else
          Begin
            PutB($68); PutD(I.A.Imm);
          End;
        OK_OFFSET : Begin PutB($68); PutAbs(I.A.Sym, I.A.Imm); End;
        OK_MEM    : Begin PutB($FF); EncMem(6, I.A); End;
      Else
        EncBad(I);
      End;
    OP_POP :
      If I.A.Kind = OK_REG Then
        PutB($58 + RegCode(I.A.Reg))
      Else
      Begin
        PutB($8F);
        EncRM(0, I.A);
      End;
    OP_ADD, OP_SUB, OP_AND, OP_OR, OP_XOR, OP_CMP: EncAlu(I);
    OP_IMUL:
      If I.B.Kind = OK_IMM Then
      Begin
        If Fits8(I.B.Imm) Then
        Begin
          PutB($6B); PutB($C0 Or (RegCode(I.A.Reg) Shl 3) Or
                          RegCode(I.A.Reg)); PutB(I.B.Imm);
        End
        Else
        Begin
          PutB($69); PutB($C0 Or (RegCode(I.A.Reg) Shl 3) Or
                          RegCode(I.A.Reg)); PutD(I.B.Imm);
        End;
      End
      Else
      Begin
        PutB($0F); PutB($AF);
        EncRM(RegCode(I.A.Reg), I.B);
      End;
    OP_IDIV: EncUnary(I, 7);
    OP_DIV : EncUnary(I, 6);
    OP_NEG : EncUnary(I, 3);
    OP_NOT : EncUnary(I, 2);
    OP_CDQ : PutB($99);
    OP_INC : EncIncDec(I, 0);
    OP_DEC : EncIncDec(I, 1);
    OP_TEST:
      Begin
        Sz := OpSize(I.A, I.B);
        If I.B.Kind = OK_IMM Then
        Begin
          If Sz = 1 Then PutB($F6) Else PutB($F7);
          EncRM(0, I.A);
          If Sz = 1 Then PutB(I.B.Imm) Else PutD(I.B.Imm);
        End
        Else
        Begin
          If Sz = 1 Then PutB($84) Else PutB($85);
          EncRM(RegCode(I.B.Reg), I.A);
        End;
      End;
    OP_SHL : EncShift(I, 4);
    OP_SHR : EncShift(I, 5);
    OP_SAR : EncShift(I, 7);
    OP_SETE, OP_SETNE, OP_SETL, OP_SETLE, OP_SETG, OP_SETGE, OP_SETA,
    OP_SETAE, OP_SETB, OP_SETBE:
      Begin
        PutB($0F); PutB($90 + CcOf(I.Op));
        EncRM(0, I.A);
      End;
    OP_JMP, OP_JE, OP_JNE, OP_JL, OP_JLE, OP_JG, OP_JGE, OP_JA, OP_JAE,
    OP_JB, OP_JBE, OP_JS, OP_JNS:
      Begin
        If I.A.Kind = OK_LABEL Then
        Begin
          Enc.RelSym := I.A.Sym;
          If I.Op = OP_JMP Then
          Begin
            If Near Then
            Begin
              PutB($E9); Enc.RelPos := Enc.Len; Enc.RelSize := 4; PutD(0);
            End
            Else
            Begin
              PutB($EB); Enc.RelPos := Enc.Len; Enc.RelSize := 1; PutB(0);
            End;
          End
          Else
          Begin
            Cc := CcOf(I.Op);
            If Near Then
            Begin
              PutB($0F); PutB($80 + Cc);
              Enc.RelPos := Enc.Len; Enc.RelSize := 4; PutD(0);
            End
            Else
            Begin
              PutB($70 + Cc);
              Enc.RelPos := Enc.Len; Enc.RelSize := 1; PutB(0);
            End;
          End;
        End
        Else If I.Op = OP_JMP Then
        Begin
          PutB($FF);
          EncRM(4, I.A);
        End
        Else
          EncBad(I);
      End;
    OP_CALL:
      If I.A.Kind = OK_LABEL Then
      Begin
        PutB($E8);
        Enc.RelSym := I.A.Sym;
        Enc.RelPos := Enc.Len;
        Enc.RelSize := 4;
        PutD(0);
      End
      Else
      Begin
        PutB($FF);
        EncRM(2, I.A);
      End;
    OP_RET :
      If I.A.Kind = OK_IMM Then
      Begin
        PutB($C2); PutW(I.A.Imm);
      End
      Else
        PutB($C3);
    OP_REP_STOSD: Begin PutB($F3); PutB($AB); End;
    OP_FLD, OP_FST, OP_FSTP, OP_FILD, OP_FISTP, OP_FADD, OP_FSUB,
    OP_FSUBR, OP_FMUL, OP_FDIV, OP_FDIVR, OP_FCOM, OP_FCOMP, OP_FNSTCW,
    OP_FLDCW, OP_FXCH, OP_FADDP, OP_FSUBP, OP_FMULP, OP_FDIVP,
    OP_FNSTSW: EncFpu(I);
    OP_FCHS   : Begin PutB($D9); PutB($E0); End;
    OP_FABS   : Begin PutB($D9); PutB($E1); End;
    OP_FTST   : Begin PutB($D9); PutB($E4); End;
    OP_FLD1   : Begin PutB($D9); PutB($E8); End;
    OP_FLDL2E : Begin PutB($D9); PutB($EA); End;
    OP_FLDLN2 : Begin PutB($D9); PutB($ED); End;
    OP_FLDZ   : Begin PutB($D9); PutB($EE); End;
    OP_F2XM1  : Begin PutB($D9); PutB($F0); End;
    OP_FYL2X  : Begin PutB($D9); PutB($F1); End;
    OP_FPATAN : Begin PutB($D9); PutB($F3); End;
    OP_FRNDINT: Begin PutB($D9); PutB($FC); End;
    OP_FSCALE : Begin PutB($D9); PutB($FD); End;
    OP_FSQRT  : Begin PutB($D9); PutB($FA); End;
    OP_FSIN   : Begin PutB($D9); PutB($FE); End;
    OP_FCOS   : Begin PutB($D9); PutB($FF); End;
    OP_SAHF   : PutB($9E);
  Else
    EncBad(I);
  End;
End;

{ ---- Donnees ---- }

Procedure DataByte(V : LongInt);
Begin
  If BinDataLen >= MAX_BIN_DATA Then
    FatalError('segment de donnees trop grand');
  BinData[BinDataLen] := V And $FF;
  Inc(BinDataLen);
End;

Procedure DataDword(V : LongInt);
Begin
  DataByte(V);
  DataByte(V Shr 8);
  DataByte(V Shr 16);
  DataByte(V Shr 24);
End;

Procedure AddFix(Sect : Byte; Off : LongInt; Kind : TBinFixKind;
                 Sym : Integer);
Begin
  If BinFixCount >= MAX_BIN_FIX Then
    FatalError('trop de relocations (max ' + ItoS(MAX_BIN_FIX) + ')');
  BinFix[BinFixCount].Sect := Sect;
  BinFix[BinFixCount].Off  := Off;
  BinFix[BinFixCount].Kind := Kind;
  BinFix[BinFixCount].Sym  := Sym;
  Inc(BinFixCount);
End;

Procedure EncodeData;
Var
  I, J, N : Integer;
  S       : TString;
Begin
  For I := 0 To DataCount - 1 Do
  Begin
    While (BinDataLen And 3) <> 0 Do DataByte(0);
    BinLbl[DataTab[I].Name].Sect := 2;
    BinLbl[DataTab[I].Name].Off  := BinDataLen;
    Case DataTab[I].Kind Of
      DK_ZERO :
        For J := 1 To (DataTab[I].Size + 3) Div 4 Do DataDword(0);
      DK_STR  :
        Begin
          S := AsmStrs[DataTab[I].Str];
          For J := 1 To Length(S) Do DataByte(Ord(S[J]));
          DataByte(0);
        End;
      DK_INT  : DataDword(DataTab[I].Lo);
      DK_REAL :
        Begin
          DataDword(DataTab[I].Lo);
          DataDword(DataTab[I].Hi);
        End;
      DK_TABLE:
        For J := 0 To DataTab[I].Count - 1 Do
        Begin
          N := TabEnt[DataTab[I].First + J];
          AddFix(1, BinDataLen, BF_ABS32, N);
          DataDword(0);
        End;
    End;
  End;
  While (BinDataLen And 3) <> 0 Do DataByte(0);
End;

{ ---- Code : mise en page et emission ---- }

Function IsRelJump(Const I : TInstr) : Boolean;
Begin
  IsRelJump := (I.Op In [OP_JMP, OP_JE, OP_JNE, OP_JL, OP_JLE, OP_JG,
                         OP_JGE, OP_JA, OP_JAE, OP_JB, OP_JBE, OP_JS,
                         OP_JNS]) And (I.A.Kind = OK_LABEL);
End;

Procedure AddImport(Sym : Integer);
Var
  K : Integer;
Begin
  For K := 0 To BinImportCount - 1 Do
    If BinImport[K] = Sym Then Exit;
  If BinImportCount > 255 Then FatalError('trop d''imports');
  BinImport[BinImportCount] := Sym;
  Inc(BinImportCount);
End;

Procedure EncodeCode;
Var
  N, I, K       : LongInt;
  Off           : LongInt;
  Changed       : Boolean;
  Ins           : TInstr;
  Disp, Target  : LongInt;
  Sym           : Integer;
Begin
  N := CodeCount + DeferCount;
  For I := 0 To N - 1 Do InstrNear[I] := False;
  { sauts courts d'abord ; agrandis tant qu'un deplacement deborde }
  Repeat
    Changed := False;
    Off := 0;
    For I := 0 To N - 1 Do
    Begin
      InstrOff[I] := Off;
      Ins := InstrAt(I);
      If Ins.Op = OP_LABEL Then
      Begin
        BinLbl[Ins.A.Sym].Sect := 1;
        BinLbl[Ins.A.Sym].Off  := Off;
      End
      Else
      Begin
        EncodeInstr(Ins, InstrNear[I]);
        Off := Off + Enc.Len;
      End;
    End;
    InstrOff[N] := Off;
    For I := 0 To N - 1 Do
    Begin
      Ins := InstrAt(I);
      If IsRelJump(Ins) And (Not InstrNear[I]) Then
      Begin
        Sym := Ins.A.Sym;
        If BinLbl[Sym].Sect <> 1 Then
        Begin
          InstrNear[I] := True;            { cible externe : rel32 }
          Changed := True;
        End
        Else
        Begin
          Disp := BinLbl[Sym].Off - (InstrOff[I] + 2);
          If Not Fits8(Disp) Then
          Begin
            InstrNear[I] := True;
            Changed := True;
          End;
        End;
      End;
    End;
  Until Not Changed;

  { emission }
  BinCodeLen := 0;
  For I := 0 To N - 1 Do
  Begin
    Ins := InstrAt(I);
    EncodeInstr(Ins, InstrNear[I]);
    If BinCodeLen + Enc.Len > MAX_BIN_CODE Then
      FatalError('code binaire trop grand');
    For K := 0 To Enc.Len - 1 Do
      BinCode[BinCodeLen + K] := Enc.B[K];
    For K := 1 To Enc.NFix Do
      AddFix(0, BinCodeLen + Enc.FixPos[K], BF_ABS32, Enc.FixSym[K]);
    If Enc.RelPos >= 0 Then
    Begin
      Sym := Enc.RelSym;
      If BinLbl[Sym].Sect = 1 Then
      Begin
        Target := BinLbl[Sym].Off;
        Disp := Target - (BinCodeLen + Enc.Len);
        For K := 0 To Enc.RelSize - 1 Do
          BinCode[BinCodeLen + Enc.RelPos + K] := (Disp Shr (8 * K)) And $FF;
      End
      Else If BinLbl[Sym].Sect = 0 Then
      Begin
        If Enc.RelSize <> 4 Then
          FatalError('encodeur: saut court vers une cible externe');
        AddFix(0, BinCodeLen + Enc.RelPos, BF_REL32, Sym);
        AddImport(Sym);
      End
      Else
        FatalError('encodeur: saut vers une donnee: ' + NameTab[Sym]);
    End;
    BinCodeLen := BinCodeLen + Enc.Len;
  End;
End;

{ Verifie que chaque symbole reference par une adresse absolue est
  defini (code ou donnees) }
Procedure CheckFixups;
Var
  I : LongInt;
Begin
  For I := 0 To BinFixCount - 1 Do
    If (BinFix[I].Kind = BF_ABS32) And (BinLbl[BinFix[I].Sym].Sect = 0) Then
      FatalError('symbole non defini: ' + NameTab[BinFix[I].Sym]);
End;

Procedure EncodeProgram;
Var
  I : LongInt;
Begin
  For I := 0 To NameCount - 1 Do
  Begin
    BinLbl[I].Sect := 0;
    BinLbl[I].Off  := 0;
  End;
  BinDataLen := 0;
  BinFixCount := 0;
  BinImportCount := 0;
  EncodeData;
  EncodeCode;
  CheckFixups;
End;

Function Hex8(V : LongInt) : TString;
Var
  R : TString;
  I : Integer;
Begin
  R := '';
  For I := 1 To 8 Do
  Begin
    R := Copy('0123456789ABCDEF', (V And 15) + 1, 1) + R;
    V := (V Shr 4) And $0FFFFFFF;
  End;
  Hex8 := R;
End;

{ Listing hexadecimal du code (mode -d) : decalage, octets, texte }
Procedure WriteBinListing(Const FileName : TString);
Var
  F        : Text;
  I, K     : LongInt;
  Ins      : TInstr;
  S        : TString;
Begin
  Assign(F, FileName);
  Rewrite(F);
  If IOResult <> 0 Then Exit;
  NoteOutput(FileName);
  For I := 0 To CodeCount + DeferCount - 1 Do
  Begin
    Ins := InstrAt(I);
    Case Ins.Op Of
      OP_LABEL   : WriteLn(F, '        ', NameTab[Ins.A.Sym], ':');
      OP_COMMENT, OP_BLANK, OP_NOP : ;
    Else
      Begin
        { octets definitifs (deplacements resolus, adresses a zero) }
        S := '';
        For K := InstrOff[I] To InstrOff[I + 1] - 1 Do
          S := S + Copy('0123456789ABCDEF', (BinCode[K] Shr 4) + 1, 1) +
               Copy('0123456789ABCDEF', (BinCode[K] And 15) + 1, 1) + ' ';
        While Length(S) < 30 Do S := S + ' ';
        WriteLn(F, Hex8(InstrOff[I]), '  ', S, InstrText(Ins));
      End;
    End;
  End;
  Close(F);
End;

Procedure PhaseEncode;
Begin
  EncodeProgram;
  If Opts.Verbose Then
    WriteLn('  .text : ', BinCodeLen, ' octets, .data : ', BinDataLen,
            ' octets, ', BinFixCount, ' relocation(s), ', BinImportCount,
            ' import(s)');
  If Opts.DebugMode Then
    WriteBinListing(ReplaceExt(Opts.OutFile, '.lst'));
End;

{ ============================================================
  SECTION 11 - ECRIVAINS PE (.EXE) ET COFF (.OBJ) (TODO 20, 21)
  ============================================================ }
{ ---- Ecrivain PE : executable Windows 32 bits console (TODO 20) ----
  Disposition (alignement fichier 512, alignement memoire 4096) :
    en-tetes (MZ, PE, COFF, optionnel, 3 sections) a 0x000
    .text   RVA 0x1000 : code + une souche JMP [IAT] par import
    .data   : donnees (variables, constantes, tables)
    .idata  : table d'importation de kernel32.dll (ILT, IAT, noms)
  Pas de table de relocation : l'image est chargee a PE_IMG_BASE. }
Const
  PE_MAX_FILE = {$IFDEF FPC}1500000{$ELSE}20000{$ENDIF};
  PE_HDR_SIZE = $200;

Var
  PeOut : Array[0..PE_MAX_FILE - 1] Of Byte;

Function AlignUp(V, A : LongInt) : LongInt;
Begin
  AlignUp := ((V + A - 1) Div A) * A;
End;

Procedure PeB(Pos : LongInt; V : LongInt);
Begin
  If (Pos < 0) Or (Pos >= PE_MAX_FILE) Then
    FatalError('executable trop grand');
  PeOut[Pos] := V And $FF;
End;

Procedure PeW(Pos : LongInt; V : LongInt);
Begin
  PeB(Pos, V);
  PeB(Pos + 1, V Shr 8);
End;

Procedure PeD(Pos : LongInt; V : TWide);
Begin
  PeB(Pos, V And $FF);
  PeB(Pos + 1, (V Shr 8) And $FF);
  PeB(Pos + 2, (V Shr 16) And $FF);
  PeB(Pos + 3, (V Shr 24) And $FF);
End;

Function PeGetD(Pos : LongInt) : LongInt;
Begin
  PeGetD := PeOut[Pos] Or (PeOut[Pos + 1] Shl 8) Or
            (PeOut[Pos + 2] Shl 16) Or (PeOut[Pos + 3] Shl 24);
End;

Procedure PeStr(Pos : LongInt; Const S : TString);
Var
  I : Integer;
Begin
  For I := 1 To Length(S) Do PeB(Pos + I - 1, Ord(S[I]));
End;

{ En-tete de section : nom, taille virtuelle, RVA, taille et position
  dans le fichier, caracteristiques }
Procedure PeSection(Pos : LongInt; Const Name : TString; VSize, RVA,
                    RawSize, RawPtr : LongInt; Flags : TWide);
Begin
  PeStr(Pos, Name);
  PeD(Pos + 8, VSize);
  PeD(Pos + 12, RVA);
  PeD(Pos + 16, RawSize);
  PeD(Pos + 20, RawPtr);
  PeD(Pos + 36, Flags);
End;

Procedure WritePE(Const FileName : TString);
Var
  ImpName    : Array[0..255] Of TString;
  I, K       : LongInt;
  Nm         : TString;
  TextLen, StubOff, DataLen, IdataLen : LongInt;
  DescOff, IltOff, IatOff, HintOff, DllOff, P : LongInt;
  HintPos    : Array[0..255] Of LongInt;
  TextRVA, DataRVA, IdataRVA, ImageSize : LongInt;
  TextRaw, DataRaw, IdataRaw, FileSize  : LongInt;
  TextRawSz, DataRawSz, IdataRawSz      : LongInt;
  Entry      : LongInt;
  Where      : LongInt;
  Target     : TWide;
  F          : File;
  Written    : LongInt;
  MainSym    : Integer;
Begin
  { imports : toute cible non definie qui n'est pas du runtime }
  For I := 0 To BinImportCount - 1 Do
  Begin
    Nm := NameTab[BinImport[I]];
    If Copy(Nm, 1, 4) = '_A58' Then
      FatalError('symbole non defini: ' + Nm +
                 ' (routine du runtime absente)');
    ImpName[I] := Nm;
  End;
  MainSym := Intern(A58_MAIN_NAME);
  If BinLbl[MainSym].Sect <> 1 Then
    FatalError('point d''entree ' + A58_MAIN_NAME + ' introuvable');
  Entry := BinLbl[MainSym].Off;

  { tailles des sections }
  StubOff := AlignUp(BinCodeLen, 4);
  TextLen := StubOff + 8 * BinImportCount;
  If TextLen = 0 Then TextLen := 4;
  DataLen := BinDataLen;
  If DataLen = 0 Then DataLen := 4;
  K := BinImportCount;
  DescOff := 0;
  IltOff  := 40;
  IatOff  := IltOff + 4 * (K + 1);
  HintOff := IatOff + 4 * (K + 1);
  P := HintOff;
  For I := 0 To K - 1 Do
  Begin
    HintPos[I] := P;
    P := P + AlignUp(2 + Length(ImpName[I]) + 1, 2);
  End;
  DllOff := P;
  IdataLen := DllOff + Length('kernel32.dll') + 1;

  TextRVA   := $1000;
  DataRVA   := TextRVA + AlignUp(TextLen, PE_SEC_ALIGN);
  IdataRVA  := DataRVA + AlignUp(DataLen, PE_SEC_ALIGN);
  ImageSize := IdataRVA + AlignUp(IdataLen, PE_SEC_ALIGN);
  TextRaw   := PE_HDR_SIZE;
  TextRawSz := AlignUp(TextLen, PE_FILE_ALIGN);
  DataRaw   := TextRaw + TextRawSz;
  DataRawSz := AlignUp(DataLen, PE_FILE_ALIGN);
  IdataRaw  := DataRaw + DataRawSz;
  IdataRawSz := AlignUp(IdataLen, PE_FILE_ALIGN);
  FileSize  := IdataRaw + IdataRawSz;
  If FileSize > PE_MAX_FILE Then FatalError('executable trop grand');
  FillChar(PeOut, FileSize, 0);

  { contenu des sections }
  For I := 0 To BinCodeLen - 1 Do PeOut[TextRaw + I] := BinCode[I];
  For I := 0 To BinDataLen - 1 Do PeOut[DataRaw + I] := BinData[I];
  { souches : JMP DWORD PTR [IAT + 4*i] }
  For I := 0 To K - 1 Do
  Begin
    P := TextRaw + StubOff + 8 * I;
    PeB(P, $FF);
    PeB(P + 1, $25);
    PeD(P + 2, TWide(PE_IMG_BASE) + IdataRVA + IatOff + 4 * I);
    PeB(P + 6, $CC);
    PeB(P + 7, $CC);
  End;

  { relocations : adresses absolues et appels vers les imports }
  For I := 0 To BinFixCount - 1 Do
  Begin
    If BinFix[I].Sect = 0 Then
      Where := TextRaw + BinFix[I].Off
    Else
      Where := DataRaw + BinFix[I].Off;
    If BinFix[I].Kind = BF_ABS32 Then
    Begin
      Case BinLbl[BinFix[I].Sym].Sect Of
        1 : Target := TWide(PE_IMG_BASE) + TextRVA +
                      BinLbl[BinFix[I].Sym].Off;
        2 : Target := TWide(PE_IMG_BASE) + DataRVA +
                      BinLbl[BinFix[I].Sym].Off;
      Else
        FatalError('symbole non defini: ' + NameTab[BinFix[I].Sym]);
      End;
      PeD(Where, Target + PeGetD(Where));
    End
    Else
    Begin
      { appel d'un import : deplacement vers sa souche }
      K := -1;
      For P := 0 To BinImportCount - 1 Do
        If BinImport[P] = BinFix[I].Sym Then K := P;
      If K < 0 Then FatalError('import inconnu');
      Target := TextRVA + StubOff + 8 * K;
      PeD(Where, Target - (TextRVA + BinFix[I].Off + 4));
    End;
  End;

  { table d'importation (kernel32.dll) }
  K := BinImportCount;
  P := IdataRaw;
  If K > 0 Then
  Begin
    PeD(P + DescOff,      IdataRVA + IltOff);        { OriginalFirstThunk }
    PeD(P + DescOff + 12, IdataRVA + DllOff);        { Name }
    PeD(P + DescOff + 16, IdataRVA + IatOff);        { FirstThunk }
    For I := 0 To K - 1 Do
    Begin
      PeD(P + IltOff + 4 * I, IdataRVA + HintPos[I]);
      PeD(P + IatOff + 4 * I, IdataRVA + HintPos[I]);
      PeW(P + HintPos[I], 0);
      PeStr(P + HintPos[I] + 2, ImpName[I]);
    End;
    PeStr(P + DllOff, 'kernel32.dll');
  End;

  { en-tete DOS + souche }
  PeW(0, $5A4D);
  PeW(2, $0090);
  PeW(4, 3);
  PeW(8, 4);
  PeW(12, $FFFF);
  PeW(16, $00B8);
  PeW(24, $0040);
  PeD($3C, $80);
  PeStr($40, #$0E#$1F#$BA#$0E#$00#$B4#$09#$CD#$21#$B8#$01#$4C#$CD#$21);
  PeStr($4E, 'This program cannot be run in DOS mode.'#13#13#10'$');
  { signature PE et en-tete COFF }
  PeD($80, PE_SIGNATURE);
  PeW($84, PE_MACHINE_I386);
  PeW($86, 3);                                      { sections }
  PeW($94, PE_OPT_SIZE);
  PeW($96, PE_FILE_EXE Or PE_FILE_32BIT Or $0001 Or $0004 Or $0008);
  { en-tete optionnel }
  PeW($98, PE_MAGIC_32);
  PeB($9A, 1);
  PeD($9C, AlignUp(TextLen, PE_FILE_ALIGN));         { SizeOfCode }
  PeD($A0, DataRawSz + IdataRawSz);                  { SizeOfInitializedData }
  PeD($A8, TextRVA + Entry);                         { AddressOfEntryPoint }
  PeD($AC, TextRVA);
  PeD($B0, DataRVA);
  PeD($B4, PE_IMG_BASE);
  PeD($B8, PE_SEC_ALIGN);
  PeD($BC, PE_FILE_ALIGN);
  PeW($C0, 4);                                       { version du systeme }
  PeW($C8, 4);                                       { sous-systeme }
  PeD($D0, ImageSize);
  PeD($D4, PE_HDR_SIZE);
  PeW($DC, PE_SUBSYS_CUI);
  PeD($E0, $100000);                                 { pile reservee }
  PeD($E4, $1000);
  PeD($E8, $100000);                                 { tas reserve }
  PeD($EC, $1000);
  PeD($F4, 16);                                      { repertoires }
  PeD($F8 + 8, IdataRVA + DescOff);                  { import }
  PeD($F8 + 12, 40);
  PeD($F8 + 12 * 8, IdataRVA + IatOff);              { IAT }
  PeD($F8 + 12 * 8 + 4, 4 * (BinImportCount + 1));
  { table des sections }
  PeSection($178,       '.text',  TextLen,  TextRVA,  TextRawSz,  TextRaw,
            PE_SCN_TEXT);
  PeSection($178 + 40,  '.data',  DataLen,  DataRVA,  DataRawSz,  DataRaw,
            PE_SCN_DATA);
  PeSection($178 + 80,  '.idata', IdataLen, IdataRVA, IdataRawSz, IdataRaw,
            PE_SCN_DATA);

  Assign(F, FileName);
  Rewrite(F, 1);
  If IOResult <> 0 Then FatalError('impossible de creer ' + FileName);
  NoteOutput(FileName);
  BlockWrite(F, PeOut, FileSize, Written);
  Close(F);
  If Written <> FileSize Then
    FatalError('erreur d''ecriture de ' + FileName);
  If Opts.Verbose Then
    WriteLn('  executable : ', FileName, ' (', FileSize, ' octets)');
End;

{ ---- Ecrivain COFF : fichier objet i386 (TODO 21) ----
  Disposition : en-tete (20) + 2 en-tetes de section (.text, .data) +
  donnees .text + relocations .text + donnees .data + relocations .data +
  table des symboles (18 octets par entree) + table des chaines.
  Symboles : 0/1 = .text + aux, 2/3 = .data + aux, 4 = _A58P_Main
  (externe, defini dans .text), 5.. = externes non definis (imports et
  routines du runtime).
  Une adresse absolue vers une etiquette definie vise le symbole de
  section ; le decalage de l'etiquette est ajoute a la valeur en place
  (addendum COFF). Un appel externe a 0 en place (REL32). }
Procedure CoffSym(Pos : LongInt; Const Name : TString; StrBase : LongInt;
                  Var StrLen : LongInt; Value : LongInt; Sect, Typ : LongInt;
                  Cls, NAux : LongInt);
Var
  I : LongInt;
Begin
  If Length(Name) <= 8 Then
    PeStr(Pos, Name)
  Else
  Begin
    PeD(Pos + 4, StrLen);
    For I := 1 To Length(Name) Do PeB(StrBase + StrLen + I - 1, Ord(Name[I]));
    PeB(StrBase + StrLen + Length(Name), 0);
    StrLen := StrLen + Length(Name) + 1;
  End;
  PeD(Pos + 8, Value);
  PeW(Pos + 12, Sect);
  PeW(Pos + 14, Typ);
  PeB(Pos + 16, Cls);
  PeB(Pos + 17, NAux);
End;

Procedure WriteCOFF(Const FileName : TString);
Var
  I, K, P, Idx, Where : LongInt;
  NTextRel, NDataRel  : LongInt;
  TextRaw, TextRelOff, DataRaw, DataRelOff, SymOff, StrOff, StrLen : LongInt;
  NSym, FileSize, Written, Sect : LongInt;
  MainSym : Integer;
  F : File;
  RelOut : LongInt;
Begin
  MainSym := Intern(A58_MAIN_NAME);
  If BinLbl[MainSym].Sect <> 1 Then
    FatalError('point d''entree ' + A58_MAIN_NAME + ' introuvable');
  NTextRel := 0;
  NDataRel := 0;
  For I := 0 To BinFixCount - 1 Do
    If BinFix[I].Sect = 0 Then Inc(NTextRel) Else Inc(NDataRel);
  If (NTextRel > 65535) Or (NDataRel > 65535) Then
    FatalError('trop de relocations pour une section COFF');

  NSym := 5 + BinImportCount;
  TextRaw    := 20 + 2 * 40;
  TextRelOff := TextRaw + AlignUp(BinCodeLen, 4);
  DataRaw    := TextRelOff + 10 * NTextRel;
  DataRelOff := DataRaw + AlignUp(BinDataLen, 4);
  SymOff     := DataRelOff + 10 * NDataRel;
  StrOff     := SymOff + 18 * NSym;
  FileSize   := StrOff + 4 + Length(A58_MAIN_NAME) + 1;
  For I := 0 To BinImportCount - 1 Do
    FileSize := FileSize + Length(NameTab[BinImport[I]]) + 1;
  If FileSize > PE_MAX_FILE Then FatalError('fichier objet trop grand');
  FillChar(PeOut, FileSize, 0);

  { en-tete de fichier }
  PeW(0, PE_MACHINE_I386);
  PeW(2, 2);
  PeD(8, SymOff);
  PeD(12, NSym);

  { sections }
  PeStr(20, '.text');
  PeD(20 + 16, BinCodeLen);
  If BinCodeLen > 0 Then PeD(20 + 20, TextRaw);
  If NTextRel > 0 Then PeD(20 + 24, TextRelOff);
  PeW(20 + 32, NTextRel);
  PeD(20 + 36, PE_SCN_TEXT Or $00300000);          { alignement 4 }
  PeStr(60, '.data');
  PeD(60 + 16, BinDataLen);
  If BinDataLen > 0 Then PeD(60 + 20, DataRaw);
  If NDataRel > 0 Then PeD(60 + 24, DataRelOff);
  PeW(60 + 32, NDataRel);
  PeD(60 + 36, PE_SCN_DATA Or $00300000);

  For I := 0 To BinCodeLen - 1 Do PeOut[TextRaw + I] := BinCode[I];
  For I := 0 To BinDataLen - 1 Do PeOut[DataRaw + I] := BinData[I];

  { relocations : .text d'abord, puis .data }
  P := TextRelOff;
  For Sect := 0 To 1 Do
  Begin
    If Sect = 1 Then P := DataRelOff;
    For I := 0 To BinFixCount - 1 Do
      If BinFix[I].Sect = Sect Then
      Begin
        If Sect = 0 Then
          Where := TextRaw + BinFix[I].Off
        Else
          Where := DataRaw + BinFix[I].Off;
        PeD(P, BinFix[I].Off);
        If BinFix[I].Kind = BF_ABS32 Then
        Begin
          Case BinLbl[BinFix[I].Sym].Sect Of
            1 : Idx := 0;
            2 : Idx := 2;
          Else
            FatalError('symbole non defini: ' + NameTab[BinFix[I].Sym]);
          End;
          PeD(Where, PeGetD(Where) + BinLbl[BinFix[I].Sym].Off);
          PeD(P + 4, Idx);
          PeW(P + 8, COFF_REL_DIR32);
        End
        Else
        Begin
          K := -1;
          For RelOut := 0 To BinImportCount - 1 Do
            If BinImport[RelOut] = BinFix[I].Sym Then K := RelOut;
          If K < 0 Then FatalError('import inconnu');
          PeD(P + 4, 5 + K);
          PeW(P + 8, COFF_REL_REL32);
        End;
        P := P + 10;
      End;
  End;

  { table des symboles }
  StrLen := 4;
  CoffSym(SymOff, '.text', StrOff, StrLen, 0, 1, 0, COFF_SYM_STATIC, 1);
  PeD(SymOff + 18, BinCodeLen);
  PeW(SymOff + 22, NTextRel);
  CoffSym(SymOff + 36, '.data', StrOff, StrLen, 0, 2, 0, COFF_SYM_STATIC, 1);
  PeD(SymOff + 54, BinDataLen);
  PeW(SymOff + 58, NDataRel);
  CoffSym(SymOff + 72, A58_MAIN_NAME, StrOff, StrLen, BinLbl[MainSym].Off,
          1, $20, COFF_SYM_EXTERNAL, 0);
  For I := 0 To BinImportCount - 1 Do
    CoffSym(SymOff + 90 + 18 * I, NameTab[BinImport[I]], StrOff, StrLen, 0,
            0, $20, COFF_SYM_EXTERNAL, 0);
  PeD(StrOff, StrLen);
  FileSize := StrOff + StrLen;

  Assign(F, FileName);
  Rewrite(F, 1);
  If IOResult <> 0 Then FatalError('impossible de creer ' + FileName);
  NoteOutput(FileName);
  BlockWrite(F, PeOut, FileSize, Written);
  Close(F);
  If Written <> FileSize Then
    FatalError('erreur d''ecriture de ' + FileName);
  If Opts.Verbose Then
    WriteLn('  objet : ', FileName, ' (', FileSize, ' octets, ', NSym,
            ' symbole(s), ', BinFixCount, ' relocation(s))');
End;

Procedure PhaseWrite;
Begin
  If Opts.EmitExe Then WritePE(Opts.OutFile);
  If Opts.EmitObj Then WriteCOFF(Opts.OutFile);
End;

{ ============================================================
  SECTION 12 - RUNTIME ALGOL 58 POUR WIN32 (TODO 22)
  ============================================================
  Le runtime est ecrit en assembleur 80386 (syntaxe du listing) et
  integre au compilateur sous forme de texte (RtText). Seules les
  routines atteignables depuis le programme compile (appels _A58RT_*,
  fermeture transitive) sont assemblees par un mini-assembleur qui les
  convertit en instructions internes, ajoutees apres le code du
  programme : elles figurent donc dans le listing .ASM, qui devient
  autonome, puis sont encodees comme le reste (.EXE et .OBJ
  independants de toute bibliotheque, hormis kernel32.dll).

  Format de RtText : '@NOM' ouvre une routine, ';texte' est un
  commentaire, 'NOM:' une etiquette, sinon une instruction.
  Les cellules de donnees _A58_* (RtData) sont creees a la demande.

  Contrat : arguments en registres, resultat en EAX ou ST(0). Un
  reel est affiche en notation fixe, 6 decimales au plus, zeros
  finaux supprimes (au moins un chiffre apres le point), partie
  entiere limitee a environ 2 milliards ; un Boolean s'affiche true
  ou false ; fin de ligne = CR LF. }
Type
  TRtLine = String[70];

Const
  RT_LINES = 534;
  RT_MAX_ROUT = 40;
  RtText : Array[0..RT_LINES - 1] Of TRtLine = (
  '@_A58RT_GETOUT',
  '_A58RT_GETOUT:',
  'CMP DWORD PTR [_A58_HOUT], 0',
  'JNE _A58R_go1',
  'PUSH -11',
  'CALL GetStdHandle',
  'MOV DWORD PTR [_A58_HOUT], EAX',
  '_A58R_go1:',
  'RET',
  '@_A58RT_WRITESTR',
  ';EAX = adresse, EDX = longueur',
  '_A58RT_WRITESTR:',
  'PUSH EBP',
  'MOV EBP, ESP',
  'SUB ESP, 4',
  'PUSH EAX',
  'PUSH EDX',
  'CALL _A58RT_GETOUT',
  'POP EDX',
  'POP ECX',
  'PUSH 0',
  'LEA EAX, [EBP-4]',
  'PUSH EAX',
  'PUSH EDX',
  'PUSH ECX',
  'PUSH DWORD PTR [_A58_HOUT]',
  'CALL WriteFile',
  'MOV ESP, EBP',
  'POP EBP',
  'RET',
  '@_A58RT_WRITEZ',
  '_A58RT_WRITEZ:',
  'MOV EDX, EAX',
  '_A58R_wz1:',
  'CMP BYTE PTR [EDX], 0',
  'JE _A58R_wz2',
  'INC EDX',
  'JMP _A58R_wz1',
  '_A58R_wz2:',
  'SUB EDX, EAX',
  'JMP _A58RT_WRITESTR',
  '@_A58RT_NEWLINE',
  '_A58RT_NEWLINE:',
  'MOV EAX, OFFSET _A58_NL',
  'MOV EDX, 2',
  'JMP _A58RT_WRITESTR',
  '@_A58RT_WRITEBOOL',
  '_A58RT_WRITEBOOL:',
  'TEST EAX, EAX',
  'JZ _A58R_wb1',
  'MOV EAX, OFFSET _A58_TRUE',
  'MOV EDX, 4',
  'JMP _A58RT_WRITESTR',
  '_A58R_wb1:',
  'MOV EAX, OFFSET _A58_FALSE',
  'MOV EDX, 5',
  'JMP _A58RT_WRITESTR',
  '@_A58RT_WRITEINT',
  '_A58RT_WRITEINT:',
  'PUSH EBP',
  'MOV EBP, ESP',
  'SUB ESP, 16',
  'PUSH EBX',
  'PUSH ESI',
  'LEA ESI, [EBP-1]',
  'MOV EBX, EAX',
  'MOV ECX, 10',
  'TEST EAX, EAX',
  'JNS _A58R_wi1',
  'NEG EAX',
  '_A58R_wi1:',
  'XOR EDX, EDX',
  'DIV ECX',
  'ADD DL, 48',
  'MOV BYTE PTR [ESI], DL',
  'DEC ESI',
  'TEST EAX, EAX',
  'JNZ _A58R_wi1',
  'TEST EBX, EBX',
  'JNS _A58R_wi2',
  'MOV BYTE PTR [ESI], 45',
  'DEC ESI',
  '_A58R_wi2:',
  'INC ESI',
  'MOV EDX, EBP',
  'SUB EDX, ESI',
  'MOV EAX, ESI',
  'CALL _A58RT_WRITESTR',
  'POP ESI',
  'POP EBX',
  'MOV ESP, EBP',
  'POP EBP',
  'RET',
  '@_A58RT_WRITEREAL',
  ';ST(0) -> texte decimal (6 decimales au plus, zeros finaux retires)',
  '_A58RT_WRITEREAL:',
  'PUSH EBP',
  'MOV EBP, ESP',
  'SUB ESP, 96',
  'PUSH EBX',
  'PUSH ESI',
  'PUSH EDI',
  'FTST',
  'FNSTSW AX',
  'SAHF',
  'SETB BL',
  'MOVZX EBX, BL',
  'FABS',
  'FMUL QWORD PTR [_A58_C1E6]',
  'FRNDINT',
  'FLD ST(0)',
  'FDIV QWORD PTR [_A58_C1E6]',
  'CALL _A58RT_FLOOR',
  'MOV DWORD PTR [EBP-4], EAX',
  'FILD DWORD PTR [EBP-4]',
  'FMUL QWORD PTR [_A58_C1E6]',
  'FSUBP ST(1), ST',
  'FISTP DWORD PTR [EBP-8]',
  'LEA EDI, [EBP-96]',
  'TEST EBX, EBX',
  'JZ _A58R_wr1',
  'MOV BYTE PTR [EDI], 45',
  'INC EDI',
  '_A58R_wr1:',
  'MOV EAX, DWORD PTR [EBP-4]',
  'LEA ESI, [EBP-47]',
  'MOV ECX, 10',
  '_A58R_wr2:',
  'XOR EDX, EDX',
  'DIV ECX',
  'ADD DL, 48',
  'MOV BYTE PTR [ESI], DL',
  'DEC ESI',
  'TEST EAX, EAX',
  'JNZ _A58R_wr2',
  'INC ESI',
  'LEA EDX, [EBP-46]',
  '_A58R_wr3:',
  'CMP ESI, EDX',
  'JAE _A58R_wr4',
  'MOV AL, BYTE PTR [ESI]',
  'MOV BYTE PTR [EDI], AL',
  'INC ESI',
  'INC EDI',
  'JMP _A58R_wr3',
  '_A58R_wr4:',
  'MOV BYTE PTR [EDI], 46',
  'INC EDI',
  'MOV EAX, DWORD PTR [EBP-8]',
  'LEA ESI, [EBP-39]',
  'MOV ECX, 6',
  '_A58R_wr5:',
  'XOR EDX, EDX',
  'PUSH ECX',
  'MOV ECX, 10',
  'DIV ECX',
  'POP ECX',
  'ADD DL, 48',
  'MOV BYTE PTR [ESI], DL',
  'DEC ESI',
  'DEC ECX',
  'JNZ _A58R_wr5',
  'MOV ECX, 6',
  '_A58R_wr6:',
  'CMP ECX, 1',
  'JLE _A58R_wr7',
  'CMP BYTE PTR [EBP+ECX-45], 48',
  'JNE _A58R_wr7',
  'DEC ECX',
  'JMP _A58R_wr6',
  '_A58R_wr7:',
  'LEA ESI, [EBP-44]',
  '_A58R_wr8:',
  'MOV AL, BYTE PTR [ESI]',
  'MOV BYTE PTR [EDI], AL',
  'INC ESI',
  'INC EDI',
  'DEC ECX',
  'JNZ _A58R_wr8',
  'LEA EAX, [EBP-96]',
  'MOV EDX, EDI',
  'SUB EDX, EAX',
  'CALL _A58RT_WRITESTR',
  'POP EDI',
  'POP ESI',
  'POP EBX',
  'MOV ESP, EBP',
  'POP EBP',
  'RET',
  '@_A58RT_GETC',
  ';---- lecture ----',
  '_A58RT_GETC:',
  'MOV EAX, DWORD PTR [_A58_PEEKC]',
  'CMP EAX, -2',
  'JE _A58R_gc1',
  'MOV DWORD PTR [_A58_PEEKC], -2',
  'RET',
  '_A58R_gc1:',
  'PUSH EBP',
  'MOV EBP, ESP',
  'SUB ESP, 8',
  'CMP DWORD PTR [_A58_HIN], 0',
  'JNE _A58R_gc2',
  'PUSH -10',
  'CALL GetStdHandle',
  'MOV DWORD PTR [_A58_HIN], EAX',
  '_A58R_gc2:',
  'PUSH 0',
  'LEA EAX, [EBP-4]',
  'PUSH EAX',
  'PUSH 1',
  'LEA EAX, [EBP-8]',
  'PUSH EAX',
  'PUSH DWORD PTR [_A58_HIN]',
  'CALL ReadFile',
  'TEST EAX, EAX',
  'JZ _A58R_gc3',
  'CMP DWORD PTR [EBP-4], 0',
  'JE _A58R_gc3',
  'MOVZX EAX, BYTE PTR [EBP-8]',
  'JMP _A58R_gc4',
  '_A58R_gc3:',
  'MOV EAX, -1',
  '_A58R_gc4:',
  'MOV ESP, EBP',
  'POP EBP',
  'RET',
  '@_A58RT_UNGETC',
  '_A58RT_UNGETC:',
  'MOV DWORD PTR [_A58_PEEKC], EAX',
  'RET',
  '@_A58RT_SKIPWS',
  ';saute les blancs ; retourne le premier caractere utile dans EAX',
  '_A58RT_SKIPWS:',
  'CALL _A58RT_GETC',
  'CMP EAX, 32',
  'JE _A58RT_SKIPWS',
  'CMP EAX, 9',
  'JE _A58RT_SKIPWS',
  'CMP EAX, 13',
  'JE _A58RT_SKIPWS',
  'CMP EAX, 10',
  'JE _A58RT_SKIPWS',
  'RET',
  '@_A58RT_READINT',
  '_A58RT_READINT:',
  'PUSH EBX',
  'PUSH ESI',
  'XOR ESI, ESI',
  'XOR EBX, EBX',
  'CALL _A58RT_SKIPWS',
  'CMP EAX, 45',
  'JNE _A58R_ri1',
  'MOV EBX, 1',
  'CALL _A58RT_GETC',
  'JMP _A58R_ri2',
  '_A58R_ri1:',
  'CMP EAX, 43',
  'JNE _A58R_ri2',
  'CALL _A58RT_GETC',
  '_A58R_ri2:',
  'MOV ECX, EAX',
  'SUB ECX, 48',
  'CMP ECX, 9',
  'JBE _A58R_ri3',
  'CALL _A58RT_UNGETC',
  'JMP _A58R_ri4',
  '_A58R_ri3:',
  'LEA ESI, [ESI+ESI*4]',
  'ADD ESI, ESI',
  'ADD ESI, ECX',
  'CALL _A58RT_GETC',
  'JMP _A58R_ri2',
  '_A58R_ri4:',
  'MOV EAX, ESI',
  'TEST EBX, EBX',
  'JZ _A58R_ri5',
  'NEG EAX',
  '_A58R_ri5:',
  'POP ESI',
  'POP EBX',
  'RET',
  '@_A58RT_READREAL',
  '_A58RT_READREAL:',
  'PUSH EBX',
  'PUSH ESI',
  'PUSH EDI',
  'XOR EBX, EBX',
  'XOR EDI, EDI',
  'FLDZ',
  'CALL _A58RT_SKIPWS',
  'CMP EAX, 45',
  'JNE _A58R_rr1',
  'MOV EBX, 1',
  'CALL _A58RT_GETC',
  'JMP _A58R_rr2',
  '_A58R_rr1:',
  'CMP EAX, 43',
  'JNE _A58R_rr2',
  'CALL _A58RT_GETC',
  '_A58R_rr2:',
  'CMP EAX, 46',
  'JNE _A58R_rr3',
  'MOV ESI, 1',
  'CALL _A58RT_GETC',
  'JMP _A58R_rr2',
  '_A58R_rr3:',
  'MOV ECX, EAX',
  'SUB ECX, 48',
  'CMP ECX, 9',
  'JA _A58R_rr6',
  'FILD DWORD PTR [_A58_TEN]',
  'FMULP ST(1), ST',
  'MOV DWORD PTR [_A58_TMP], ECX',
  'FILD DWORD PTR [_A58_TMP]',
  'FADDP ST(1), ST',
  'TEST ESI, ESI',
  'JZ _A58R_rr4',
  'INC EDI',
  '_A58R_rr4:',
  'CALL _A58RT_GETC',
  'JMP _A58R_rr2',
  '_A58R_rr6:',
  'CALL _A58RT_UNGETC',
  '_A58R_rr7:',
  'TEST EDI, EDI',
  'JZ _A58R_rr8',
  'FILD DWORD PTR [_A58_TEN]',
  'FDIVP ST(1), ST',
  'DEC EDI',
  'JMP _A58R_rr7',
  '_A58R_rr8:',
  'TEST EBX, EBX',
  'JZ _A58R_rr9',
  'FCHS',
  '_A58R_rr9:',
  'POP EDI',
  'POP ESI',
  'POP EBX',
  'RET',
  '@_A58RT_READBOOL',
  '_A58RT_READBOOL:',
  'CALL _A58RT_SKIPWS',
  'MOV ECX, EAX',
  'OR ECX, 32',
  'XOR EDX, EDX',
  'CMP ECX, 116',
  'JNE _A58R_rb1',
  'MOV EDX, 1',
  '_A58R_rb1:',
  'PUSH EDX',
  '_A58R_rb2:',
  'CALL _A58RT_GETC',
  'CMP EAX, 97',
  'JB _A58R_rb3',
  'CMP EAX, 122',
  'JBE _A58R_rb2',
  '_A58R_rb3:',
  'CMP EAX, 65',
  'JB _A58R_rb4',
  'CMP EAX, 90',
  'JBE _A58R_rb2',
  '_A58R_rb4:',
  'CALL _A58RT_UNGETC',
  'POP EAX',
  'RET',
  '@_A58RT_READLN',
  '_A58RT_READLN:',
  'CALL _A58RT_GETC',
  'CMP EAX, 10',
  'JE _A58R_rl1',
  'CMP EAX, -1',
  'JNE _A58RT_READLN',
  '_A58R_rl1:',
  'RET',
  '@_A58RT_POW',
  ';---- arithmetique ----',
  ';EAX = base, EDX = exposant -> EAX',
  '_A58RT_POW:',
  'PUSH EBX',
  'MOV ECX, EDX',
  'MOV EBX, EAX',
  'MOV EAX, 1',
  'TEST ECX, ECX',
  'JS _A58R_pw5',
  '_A58R_pw1:',
  'TEST ECX, ECX',
  'JZ _A58R_pw9',
  'MOV EDX, ECX',
  'AND EDX, 1',
  'JZ _A58R_pw2',
  'IMUL EAX, EBX',
  '_A58R_pw2:',
  'IMUL EBX, EBX',
  'SHR ECX, 1',
  'JMP _A58R_pw1',
  '_A58R_pw5:',
  'CMP EBX, 1',
  'JE _A58R_pw9',
  'CMP EBX, -1',
  'JNE _A58R_pw6',
  'MOV EDX, ECX',
  'AND EDX, 1',
  'JZ _A58R_pw9',
  'MOV EAX, -1',
  'JMP _A58R_pw9',
  '_A58R_pw6:',
  'XOR EAX, EAX',
  '_A58R_pw9:',
  'POP EBX',
  'RET',
  '@_A58RT_EXP2',
  ';ST(0) = t -> 2^t',
  '_A58RT_EXP2:',
  'FLD ST(0)',
  'FRNDINT',
  'FSUB ST(1), ST',
  'FXCH ST(1)',
  'F2XM1',
  'FLD1',
  'FADDP ST(1), ST',
  'FSCALE',
  'FSTP ST(1)',
  'RET',
  '@_A58RT_EXP',
  ';ST(0) = x -> e^x',
  '_A58RT_EXP:',
  'FLDL2E',
  'FMULP ST(1), ST',
  'JMP _A58RT_EXP2',
  '@_A58RT_RPOW',
  ';ST(0) = base, ST(1) = exposant -> ST(0) = base ^ exposant',
  '_A58RT_RPOW:',
  'FTST',
  'FNSTSW AX',
  'SAHF',
  'JA _A58R_rp2',
  'JB _A58R_rp1',
  'FSTP ST(0)',
  'FSTP ST(0)',
  'FLDZ',
  'RET',
  '_A58R_rp1:',
  'FABS',
  'FLD ST(1)',
  'FISTP DWORD PTR [_A58_TMP]',
  'FYL2X',
  'CALL _A58RT_EXP2',
  'MOV EAX, DWORD PTR [_A58_TMP]',
  'AND EAX, 1',
  'JZ _A58R_rp3',
  'FCHS',
  '_A58R_rp3:',
  'RET',
  '_A58R_rp2:',
  'FYL2X',
  'JMP _A58RT_EXP2',
  '@_A58RT_FLOOR',
  ';ST(0) -> EAX = plancher',
  '_A58RT_FLOOR:',
  'SUB ESP, 8',
  'FNSTCW WORD PTR [ESP]',
  'MOVZX EAX, WORD PTR [ESP]',
  'AND EAX, 0F3FFh',
  'OR EAX, 0400h',
  'MOV WORD PTR [ESP+2], AX',
  'FLDCW WORD PTR [ESP+2]',
  'FISTP DWORD PTR [ESP+4]',
  'FLDCW WORD PTR [ESP]',
  'MOV EAX, DWORD PTR [ESP+4]',
  'ADD ESP, 8',
  'RET',
  '@_A58RT_RTOI',
  ';ST(0) -> EAX = arrondi au plus proche, demi vers le haut',
  '_A58RT_RTOI:',
  'FADD QWORD PTR [_A58_HALF]',
  'JMP _A58RT_FLOOR',
  '@_A58RT_RSIGN',
  ';ST(0) -> EAX = -1, 0 ou 1',
  '_A58RT_RSIGN:',
  'FTST',
  'FNSTSW AX',
  'SAHF',
  'FSTP ST(0)',
  'JA _A58R_rs1',
  'JB _A58R_rs2',
  'XOR EAX, EAX',
  'RET',
  '_A58R_rs1:',
  'MOV EAX, 1',
  'RET',
  '_A58R_rs2:',
  'MOV EAX, -1',
  'RET',
  '@_A58RT_ISQRT',
  ';EAX -> EAX = racine carree entiere',
  '_A58RT_ISQRT:',
  'PUSH EAX',
  'FILD DWORD PTR [ESP]',
  'ADD ESP, 4',
  'FSQRT',
  'JMP _A58RT_FLOOR',
  '@_A58RT_CHKIDX',
  ';EAX = indice, ECX = bas, EDX = haut : conserve tous les registres',
  '_A58RT_CHKIDX:',
  'CMP EAX, ECX',
  'JL _A58R_ci1',
  'CMP EAX, EDX',
  'JG _A58R_ci1',
  'RET',
  '_A58R_ci1:',
  'MOV EAX, OFFSET _A58_M_IDX',
  'MOV EDX, 28',
  'CALL _A58RT_WRITESTR',
  'PUSH 1',
  'CALL ExitProcess',
  '@_A58RT_DIVZERO',
  '_A58RT_DIVZERO:',
  'MOV EAX, OFFSET _A58_M_DIV',
  'MOV EDX, 27',
  'CALL _A58RT_WRITESTR',
  'PUSH 1',
  'CALL ExitProcess',
  '@_A58RT_ALLOC',
  ';EAX = octets -> EAX = adresse (memoire mise a zero)',
  '_A58RT_ALLOC:',
  'PUSH EAX',
  'CALL GetProcessHeap',
  'POP ECX',
  'PUSH ECX',
  'PUSH 8',
  'PUSH EAX',
  'CALL HeapAlloc',
  'RET'
  );

Var
  RtStart   : Array[0..RT_MAX_ROUT] Of Integer;   { 1re ligne de chaque routine }
  RtName    : Array[0..RT_MAX_ROUT - 1] Of TString;
  RtUsed    : Array[0..RT_MAX_ROUT - 1] Of Boolean;
  RtCount   : Integer;
  RtLine    : TString;                             { ligne en cours d'assemblage }
  RtPos     : Integer;
  RtDataMade: Array[0..31] Of Integer;
  RtDataN   : Integer;

Function RtFind(Const Name : TString) : Integer;
Var
  I : Integer;
Begin
  RtFind := -1;
  For I := 0 To RtCount - 1 Do
    If RtName[I] = Name Then RtFind := I;
End;

Function RtIdChar(C : Char) : Boolean;
Begin
  RtIdChar := ((C >= 'A') And (C <= 'Z')) Or ((C >= 'a') And (C <= 'z')) Or
              ((C >= '0') And (C <= '9')) Or (C = '_');
End;

{ Marque une routine et, transitivement, celles qu'elle appelle }
Procedure RtMark(Const Name : TString);
Var
  R, L, P, E : Integer;
  S, Id      : TString;
Begin
  R := RtFind(Name);
  If R < 0 Then
    FatalError('erreur interne: routine du runtime inconnue: ' + Name);
  If RtUsed[R] Then Exit;
  RtUsed[R] := True;
  For L := RtStart[R] To RtStart[R + 1] - 1 Do
  Begin
    S := RtText[L];
    If (S <> '') And (S[1] <> ';') And (S[1] <> '@') Then
    Begin
      P := Pos(A58_RT_PFX, S);
      While P > 0 Do
      Begin
        E := P;
        While (E <= Length(S)) And RtIdChar(S[E]) Do Inc(E);
        Id := Copy(S, P, E - P);
        RtMark(Id);
        S := Copy(S, E, Length(S));
        P := Pos(A58_RT_PFX, S);
      End;
    End;
  End;
End;

{ ---- cellules de donnees du runtime, creees a la demande ---- }
Procedure RtDataInt(Sym : Integer; V : LongInt);
Var
  K : Integer;
Begin
  K := DataNew(Sym, DK_INT);
  DataTab[K].Lo   := V;
  DataTab[K].Size := 4;
End;

Procedure RtDataStr(Sym : Integer; Const S : TString);
Var
  K : Integer;
Begin
  K := DataNew(Sym, DK_STR);
  DataTab[K].Str  := AsmStrAdd(S);
  DataTab[K].Size := Length(S);
End;

Procedure RtDataReal(Sym : Integer; Lo, Hi : LongInt);
Var
  K : Integer;
Begin
  K := DataNew(Sym, DK_REAL);
  DataTab[K].Lo   := Lo;
  DataTab[K].Hi   := Hi;
  DataTab[K].Size := 8;
End;

Procedure RtData(Sym : Integer);
Var
  I : Integer;
  N : TString;
Begin
  For I := 0 To RtDataN - 1 Do
    If RtDataMade[I] = Sym Then Exit;
  If RtDataN > 31 Then FatalError('erreur interne: trop de donnees runtime');
  RtDataMade[RtDataN] := Sym;
  Inc(RtDataN);
  N := NameTab[Sym];
  If (N = '_A58_HOUT') Or (N = '_A58_HIN') Or (N = '_A58_TMP') Then
    DataAddZero(Sym, 4)
  Else If N = '_A58_PEEKC' Then RtDataInt(Sym, -2)
  Else If N = '_A58_TEN'   Then RtDataInt(Sym, 10)
  Else If N = '_A58_NL'    Then RtDataStr(Sym, #13#10)
  Else If N = '_A58_TRUE'  Then RtDataStr(Sym, 'true')
  Else If N = '_A58_FALSE' Then RtDataStr(Sym, 'false')
  Else If N = '_A58_M_IDX' Then
    RtDataStr(Sym, 'Erreur: indice hors bornes'#13#10)
  Else If N = '_A58_M_DIV' Then
    RtDataStr(Sym, 'Erreur: division par zero'#13#10)
  Else If N = '_A58_C1E6'  Then RtDataReal(Sym, 0, $412E8480)
  Else If N = '_A58_HALF'  Then RtDataReal(Sym, 0, $3FE00000)
  Else
    FatalError('erreur interne: donnee runtime inconnue: ' + N);
End;

{ ---- mini-assembleur ---- }
Procedure RtSkip;
Begin
  While (RtPos <= Length(RtLine)) And (RtLine[RtPos] = ' ') Do Inc(RtPos);
End;

Function RtAtEnd : Boolean;
Begin
  RtSkip;
  RtAtEnd := RtPos > Length(RtLine);
End;

Function RtIdent : TString;
Var
  S : TString;
Begin
  S := '';
  While (RtPos <= Length(RtLine)) And RtIdChar(RtLine[RtPos]) Do
  Begin
    S := S + RtLine[RtPos];
    Inc(RtPos);
  End;
  RtIdent := S;
End;

{ nombre decimal ou hexadecimal (suffixe h), sans signe }
Function RtNumber : LongInt;
Var
  S    : TString;
  I, D : Integer;
  V    : LongInt;
  Hex  : Boolean;
Begin
  S := RtIdent;
  Hex := (S <> '') And ((S[Length(S)] = 'h') Or (S[Length(S)] = 'H'));
  If Hex Then Delete(S, Length(S), 1);
  V := 0;
  For I := 1 To Length(S) Do
  Begin
    If (S[I] >= '0') And (S[I] <= '9') Then
      D := Ord(S[I]) - 48
    Else
      D := Ord(UpCase(S[I])) - 55;
    If Hex Then V := V * 16 + D Else V := V * 10 + D;
  End;
  RtNumber := V;
End;

Function RtReg(Const S : TString) : TReg;
Begin
  RtReg := R_NONE;
  If S = 'EAX' Then RtReg := R_EAX
  Else If S = 'ECX' Then RtReg := R_ECX
  Else If S = 'EDX' Then RtReg := R_EDX
  Else If S = 'EBX' Then RtReg := R_EBX
  Else If S = 'ESP' Then RtReg := R_ESP
  Else If S = 'EBP' Then RtReg := R_EBP
  Else If S = 'ESI' Then RtReg := R_ESI
  Else If S = 'EDI' Then RtReg := R_EDI
  Else If S = 'AX' Then RtReg := R_AX
  Else If S = 'AL' Then RtReg := R_AL
  Else If S = 'CL' Then RtReg := R_CL
  Else If S = 'DL' Then RtReg := R_DL
  Else If S = 'BL' Then RtReg := R_BL;
End;

Function RtSym(Const Name : TString) : Integer;
Var
  K : Integer;
Begin
  K := Intern(Name);
  If Copy(Name, 1, 5) = '_A58_' Then RtData(K);
  RtSym := K;
End;

{ [Sym + Base + Index*Echelle + Depl] }
Function RtMemory(Size : Byte) : TOperand;
Var
  O    : TOperand;
  Sign : LongInt;
  Id   : TString;
  R    : TReg;
  N    : LongInt;
Begin
  O := OpNone;
  O.Kind := OK_MEM;
  O.Size := Size;
  Inc(RtPos);                                   { [ }
  Sign := 1;
  While (RtPos <= Length(RtLine)) And (RtLine[RtPos] <> ']') Do
  Begin
    RtSkip;
    If RtLine[RtPos] = '+' Then
    Begin
      Sign := 1;
      Inc(RtPos);
    End
    Else If RtLine[RtPos] = '-' Then
    Begin
      Sign := -1;
      Inc(RtPos);
    End
    Else If (RtLine[RtPos] >= '0') And (RtLine[RtPos] <= '9') Then
    Begin
      O.Imm := O.Imm + Sign * RtNumber;
      Sign := 1;
    End
    Else
    Begin
      Id := RtIdent;
      If Id = '' Then FatalError('erreur interne: runtime: ' + RtLine);
      R := RtReg(Id);
      If R <> R_NONE Then
      Begin
        If (RtPos <= Length(RtLine)) And (RtLine[RtPos] = '*') Then
        Begin
          Inc(RtPos);
          N := RtNumber;
          O.Index := R;
          O.Scale := N;
        End
        Else If O.Base = R_NONE Then
          O.Base := R
        Else
        Begin
          O.Index := R;
          O.Scale := 1;
        End;
      End
      Else
        O.Sym := RtSym(Id);
      Sign := 1;
    End;
    RtSkip;
  End;
  Inc(RtPos);                                   { ] }
  RtMemory := O;
End;

Function RtOperand : TOperand;
Var
  Id, Id2 : TString;
  R       : TReg;
  Size    : Byte;
  Neg     : Boolean;
  V       : LongInt;
Begin
  RtSkip;
  Size := 0;
  If RtLine[RtPos] = '[' Then
  Begin
    RtOperand := RtMemory(0);
    Exit;
  End;
  If (RtLine[RtPos] = '-') Or ((RtLine[RtPos] >= '0') And
                               (RtLine[RtPos] <= '9')) Then
  Begin
    Neg := RtLine[RtPos] = '-';
    If Neg Then Inc(RtPos);
    V := RtNumber;
    If Neg Then V := -V;
    RtOperand := OpImm(V);
    Exit;
  End;
  Id := RtIdent;
  If (Id = 'BYTE') Or (Id = 'WORD') Or (Id = 'DWORD') Or (Id = 'QWORD') Then
  Begin
    If Id = 'BYTE' Then Size := 1
    Else If Id = 'WORD' Then Size := 2
    Else If Id = 'DWORD' Then Size := 4
    Else Size := 8;
    RtSkip;
    Id2 := RtIdent;                             { PTR }
    RtSkip;
    RtOperand := RtMemory(Size);
    Exit;
  End;
  If Id = 'OFFSET' Then
  Begin
    RtSkip;
    RtOperand := OpOffset(RtSym(RtIdent));
    Exit;
  End;
  If Id = 'ST' Then
  Begin
    V := 0;
    If (RtPos <= Length(RtLine)) And (RtLine[RtPos] = '(') Then
    Begin
      Inc(RtPos);
      V := RtNumber;
      Inc(RtPos);
    End;
    RtOperand := OpST(V);
    Exit;
  End;
  R := RtReg(Id);
  If R <> R_NONE Then
    RtOperand := OpReg(R)
  Else
    RtOperand := OpLabel(Intern(Id));
End;

Procedure RtAssembleLine(Const S : TString);
Var
  Mn   : TString;
  Op   : TOp;
  Found: Boolean;
  A, B : TOperand;
Begin
  RtLine := S;
  RtPos  := 1;
  If S[1] = ';' Then
  Begin
    EmitComment(Copy(S, 2, Length(S)));
    Exit;
  End;
  If S[Length(S)] = ':' Then
  Begin
    EmitLabel(Intern(Copy(S, 1, Length(S) - 1)));
    Exit;
  End;
  Mn := RtIdent;
  If Mn = 'JZ' Then Mn := 'JE';
  If Mn = 'JNZ' Then Mn := 'JNE';
  Found := False;
  Op := OP_MOV;
  While (Not Found) And (Op <= OP_FLDCW) Do
  Begin
    If OpName(Op) = Mn Then Found := True Else Op := Succ(Op);
  End;
  If Not Found Then FatalError('erreur interne: runtime: ' + S);
  A := OpNone;
  B := OpNone;
  If Not RtAtEnd Then
  Begin
    A := RtOperand;
    RtSkip;
    If (RtPos <= Length(RtLine)) And (RtLine[RtPos] = ',') Then
    Begin
      Inc(RtPos);
      B := RtOperand;
    End;
  End;
  Emit(Op, A, B);
End;

{ Ajoute au programme les routines du runtime qu'il utilise }
Procedure RtLink;
Var
  I, L, R, Start : LongInt;
  Any            : Boolean;
  S              : TString;
Begin
  RtCount := 0;
  RtDataN := 0;
  For L := 0 To RT_LINES - 1 Do
    If RtText[L][1] = '@' Then
    Begin
      If RtCount >= RT_MAX_ROUT Then
        FatalError('erreur interne: trop de routines runtime');
      RtStart[RtCount] := L;
      RtName[RtCount]  := Copy(RtText[L], 2, 255);
      RtUsed[RtCount]  := False;
      Inc(RtCount);
    End;
  RtStart[RtCount] := RT_LINES;
  { routines appelees par le programme }
  For I := 0 To CodeCount + DeferCount - 1 Do
    If (InstrAt(I).A.Kind = OK_LABEL) And
       (InstrAt(I).Op In [OP_CALL, OP_JMP]) Then
    Begin
      S := NameTab[InstrAt(I).A.Sym];
      If Copy(S, 1, Length(A58_RT_PFX)) = A58_RT_PFX Then RtMark(S);
    End;
  Any := False;
  For R := 0 To RtCount - 1 Do
    If RtUsed[R] Then Any := True;
  If Not Any Then Exit;
  Start := CodeCount;
  EmitBlank;
  EmitComment('---- runtime AL58CW32 (routines utilisees) ----');
  For R := 0 To RtCount - 1 Do
    If RtUsed[R] Then
    Begin
      EmitBlank;
      For L := RtStart[R] + 1 To RtStart[R + 1] - 1 Do
        RtAssembleLine(RtText[L]);
    End;
  MoveToDeferred(Start);
End;

{ ============================================================
  SECTION 13 - ERREURS ET RAPPORT FINAL (TODO 23, 24)
  ============================================================ }
Procedure PhaseReport;
Begin
  If ErrorCount > 0 Then
    WriteLn('Compilation echouee : ', ErrorCount, ' erreur(s), ',
            WarnCount, ' avertissement(s)')
  Else If (WarnCount > 0) Or Opts.Verbose Then
    WriteLn('Compilation terminee : 0 erreur, ', WarnCount,
            ' avertissement(s)');
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
    PH_CODEGEN :
      Begin
        RtLink;
        PhaseCodegen;
      End;
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
  OutCreatedN := 0;
  {$IFDEF FPC}
  Set8087CW($133F);            { x87 : toutes les exceptions masquees }
  {$IFDEF CPUX86_64}
  SetMXCSR($1F80);             { SSE : toutes les exceptions masquees }
  {$ENDIF}
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
  { le parseur tourne meme apres des erreurs lexicales (les erreurs
    syntaxiques sont signalees en plus) ; les phases suivantes ne
    tournent que sans erreur }
  For P := PH_LEX To PH_REPORT Do
    If (ErrorCount = 0) Or (P = PH_PARSE) Or (P = PH_REPORT) Then
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
