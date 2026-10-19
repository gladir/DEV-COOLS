{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Algol 68 vers assembleur 80386, 32 bits, pour
    Windows 32 bits
}

(* ============================================================
  AL68CW32.PAS - Compilateur Algol 68 vers assembleur 80386
    pour Windows 32 bits
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32 (console)

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un listing .ASM lisible
    (la production du .ASM est optionnelle et jamais implicite).
  Supporte toutes les exemples SAMPLES\ALGOL68\*.a68

  Reference : DOC\ALGOL68_SPEC_LANG.txt
  Compilateur 16 bits de reference : AL68C86.PAS (DOC\TODO\AL68C86.txt)
  Compilateurs 32 bits de meme famille : AL58CW32.PAS et AL60CW32.PAS
    (encodeur x86-32, ecrivains PE et COFF, runtime Win32 integre avec
    mini-assembleur, gestion des erreurs, chargeur PE de test et script
    de test a reprendre ou a adapter : DOC\TODO\AL60CW32.txt,
    TESTS\test_al60cw32.sh, TESTS\AL60CW32\)
  Modele PE/COFF 32 bits de reference : JOVCW32.PAS, BCPLCW32.PAS

  ETAT : feuille de route seulement, aucun code ecrit pour le moment.

  PARTICULARITES D'ALGOL 68 A PRENDRE EN COMPTE (vues dans les exemples)
    - Langage fortement type par les modes : le type d'une unite depend
      de son contexte (coercitions : dereferencement, deprocedurage,
      elargissement, enrobage en tableau, union, vidage). Le parseur
      construit donc un arbre d'unites typees ; le code n'est genere
      qu'apres la resolution des modes et des coercitions.
    - Mots reserves en majuscules (BEGIN END IF THEN ELIF ELSE FI CASE IN
      OUSE OUT ESAC FOR FROM BY TO DOWNTO WHILE DO OD MODE STRUCT UNION
      PROC OP PRIO REF HEAP LOC INT REAL BOOL CHAR STRING BITS VOID PAR
      GOTO SKIP NIL EMPTY OF IS ISNT AND OR NOT OVER MOD ABS SIGN ODD
      SHL SHR BIN LWB UPB TRUE FALSE) ; identificateurs en minuscules.
    - Commentaires CO ... CO (aussi COMMENT ... COMMENT et # ... #).
    - Un programme est une clause serie : les exemples peuvent etre
      encadres par BEGIN ... END ou ecrits sans encadrement (arrays,
      structs, test_array, test_loop, test_ref...), avec des
      declarations MODE au niveau le plus externe.
    - Entrees/sorties par print((liste)) : la liste est une clause
      collaterale de valeurs de modes differents (INT, BOOL, CHAR,
      STRING, newline, space), print(chaine) accepte une seule valeur.
    - Extensions tolerees par les exemples : DOWNTO, SHL et SHR sur
      INT, /:= sur INT (division entiere), PAR execute sequentiellement
      (avertissement), declarations apres des instructions.
    - Pas de ramasse-miettes : HEAP alloue sur le tas Win32 sans
      liberation ; LOC (par defaut) vit dans le cadre de la clause.

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - ARCHITECTURE ET PIPELINE DU COMPILATEUR [A FAIRE]
            Definir le pipeline complet :
              source .a68 -> lexeur -> parseur (arbre d'unites)
              -> resolution des modes et coercitions -> generation
              (ASM 80386) -> .ASM (optionnel) -> encodeur binaire x86-32
              -> .OBJ (COFF) ou .EXE (PE) -> rapport
            Choix retenu : encodeur binaire interne (comme JOVCW32,
              AL58CW32 et AL60CW32), le .ASM n'etant qu'un listing
              parallele, pas une etape requise
            Difference avec AL60CW32 : la generation en une seule passe
              ne suffit pas, le mode d'une unite n'etant connu qu'avec
              son contexte ; l'arbre est donc complet avant la generation
            Differences avec AL68C86 : registres 32 bits (EAX..EBP),
              modele FLAT, INT sur 32 bits, vrai type REAL (x87), appels
              API Win32 au lieu de INT 21h, aucune limite de segment
            Decouper le source en sections commentees : constantes, types
              Pascal, options, lexeur, modes, symboles et portees,
              arbre d'unites, parseur, coercitions, generateur, code
              interne, encodeur, ecrivains OBJ/EXE, runtime, erreurs,
              programme principal
            Garder la compatibilite Turbo Pascal 7 / Free Pascal 3.2
              ({$MODE TP}, {$H-}, {$I-}), lignes de 80 colonnes maximum
            Attention : Integer vaut 16 bits en mode TP, utiliser LongInt
              pour les indices de tables et les tailles
            Attention : ne jamais ecrire de fermeture de commentaire
              Pascal dans un commentaire (parenthese-etoile, accolade)

  TODO 02 - OPTIONS, CONSTANTES, LIMITES ET NOMMAGE [A FAIRE]
            TOptions (SrcFile, OutFile, AsmFile, Verbose, DebugMode,
              Warnings, EmitExe, EmitObj, EmitAsm)
            Syntaxe : AL68CW32 source.a68 [-o sortie] [-obj] [-asm]
              [-v] [-d] [-w] [-w-] [-h]
            Par defaut : produire source.exe (PE Windows 32 bits)
            -obj : produire uniquement source.obj (aucun .EXE)
            -asm : produire aussi source.asm ; jamais cree sans -asm
            -o nom : nom de la sortie principale ; extension .exe ou
              .obj ajoutee si absente ; .asm de meme nom de base
            Source .a68 (ou .alg) ; extension ajoutee si absente
            Refus : sortie identique au source, -o vers un .asm, option
              inconnue (code 2), source introuvable (code 1)
            Codes de retour : 0 succes, 1 erreur, 2 usage
            Constantes PE/COFF : PE_DOS_MAGIC, PE_SIGNATURE,
              PE_MACHINE_I386 ($014C), PE_IMG_BASE ($00400000),
              PE_SEC_ALIGN (4096), PE_FILE_ALIGN (512), sous-systeme
              console, indicateurs de sections ; COFF_SYM_EXTERNAL,
              COFF_SYM_STATIC, IMAGE_REL_I386_DIR32 et REL32
            Limites internes 32 bits : symboles, modes, portees, unites,
              parametres, champs, dimensions, tailles de code et de
              donnees, relocations, profondeur d'imbrication
            Prefixes de nommage ASM : _A68V_ (variable ou identite),
              _A68P_ (procedure), _A68O_ (operateur), _A68K_ (chaine),
              _A68M_ (descripteur de mode), _A68L_ (label), _A68RT_
              (runtime), _A68T_ (thunk ou temporaire)
            Utilitaires : ItoS, StrLower, AsmIdent (nom ASM valide),
              extension et nom de fichier, FileExists

  TODO 03 - LEXEUR ALGOL 68 [A FAIRE]
            TTokenKind : TK_EOF, TK_INT, TK_REAL, TK_STRING, TK_CHAR,
              TK_TAG (identificateur en minuscules), TK_BOLD (mot en
              majuscules), TK_OP (symbole d'operateur), TK_PUNCT
            Format libre, suivi de ligne et colonne pour les erreurs
            Mots en majuscules = mots reserves ou noms de modes et
              d'operateurs ; table des mots reserves du TODO 01
            Commentaires : CO ... CO et COMMENT ... COMMENT (plusieurs
              lignes), # ... # ; commentaire non termine detecte
            Denotations : entiers (42), reels (3.14, 1.5e3, 1e-2),
              booleens TRUE et FALSE, caractere "A" (un seul caractere),
              chaine "texte" avec "" pour inclure un guillemet ; chaine
              ou caractere non ferme detecte, depassement INT detecte
            Symboles : := =: + - * / ** = /= < <= > >= et les formes
              composees +:= -:= *:= /:= %:= ; | et |: (formes abregees),
              : ; , ( ) [ ] et le separateur de lignes
            Les formes ELIF, OUSE, DOWNTO et les symboles abreges sont
              reconnus comme des tokens uniques
            Mode debug -d : afficher chaque token
            Verification : hello.a68 (denotations), test_formula.a68
              (tous les operateurs)

  TODO 04 - MODES (TYPES) ET LEUR REPRESENTATION [A FAIRE]
            Modes de base : INT (32 bits), REAL (64 bits, x87), BOOL,
              CHAR, BITS (32 bits), VOID
            Modes construits : REF m (pointeur 4 octets), [] m (tableau
              avec descripteur), STRUCT(champs), UNION(modes), PROC
              (parametres) m, STRING (tableau flexible de CHAR)
            Table des modes avec partage structurel : deux modes
              equivalents ont le meme indice (equivalence structurelle,
              MODE POINT = STRUCT(INT x, INT y) et alias MODE myint = INT)
            Declaration MODE : alias et modes recursifs a deux passes
              (la declaration doit pouvoir referencer son propre nom
              via un REF ou un tableau)
            Representation : INT, BOOL, BITS, CHAR scalaires sur un DWORD,
              REAL sur un QWORD, REF et PROC sur un DWORD (PROC = paire
              entree + lien statique), STRUCT = champs consecutifs alignes
              sur 4, tableau et STRING = descripteur (pointeur, bornes,
              pas), UNION = etiquette de mode + valeur la plus large
            Tailles et alignements calcules une fois par mode
            Mode debug -d : liste des modes
            Verification : test_decl.a68, test_struct.a68, test_union.a68

  TODO 05 - TABLE DES SYMBOLES, PORTEES ET PRELUDE STANDARD [A FAIRE]
            Portees emboitees (clauses fermees, series, boucles,
              procedures) ; recherche du plus interne vers l'externe
            Espaces de noms : identites et variables, modes, operateurs
              (avec modes des operandes), priorites, labels
            Entree : nom, genre, mode, portee, niveau d'imbrication,
              classe de stockage (statique, local, parametre), decalage
              ou nom ASM
            Doublon dans une meme portee signale ; masquage dans une
              portee interne permis
            Prelude standard : pi, newline, space, print, whole, ABS,
              SIGN, ODD, LWB, UPB, BIN, SHL, SHR, ENTIER, ROUND, operateurs
              arithmetiques, de comparaison, booleens et de chaines avec
              leurs priorites (1 a 9), constantes max int et max real
            Resolution des operateurs surcharges par les modes des
              operandes (preparer TODO 11 et TODO 17)
            Mode debug -d : afficher chaque portee
            Verification : test_closed.a68, test_decl.a68

  TODO 06 - CODE INTERNE, LISTING .ASM ET SEGMENT DE DONNEES [A FAIRE]
            TInstr (operation, deux operandes, commentaire) ; operandes :
              registre, immediat, memoire [base + index*echelle + depl],
              etiquette, symbole, registre ST(i)
            Emission : Emit, EmitLabel, EmitComment, EmitBlank,
              NewLabel ; code differe (corps de procedures emis a part,
              puis rattache apres le programme principal)
            Listing .ASM : en-tete .386 / .MODEL FLAT, EXTERN des
              fonctions Win32, .DATA, .CODE, END <entree>
            Segment de donnees : variables statiques du niveau externe,
              chaines des denotations (avec zero final et descripteur),
              reels, descripteurs de modes et tables, cellules du runtime
              creees a la demande
            Entree du programme : _A68P_Main, tampon de pile et
              ExitProcess a la fin
            Verification : test_dataseg.a68, test_closed.a68

  TODO 07 - PARSEUR : PROGRAMME, CLAUSES SERIES ET FERMEES [A FAIRE]
            Un programme est une clause serie, avec ou sans BEGIN ... END
              ou parentheses autour (arrays, structs, test_loop...)
            Clause serie : suite d'unites, declarations et labels
              separes par ; ou EXIT ; la derniere unite donne la valeur
            Clause fermee : BEGIN ... END et ( ... ), avec declarations
              locales (INT tmp := 5; tmp * 2) et valeur de la clause
            Labels : loop: et done: devant une unite ; GOTO etiquette et
              etiquette seule comme saut ; label non defini signale
            Declarations melangees aux unites, SKIP et unite vide
            Recuperation apres erreur : synchronisation sur ; ou sur un
              mot de fermeture (END OD FI ESAC) avec progression garantie
            Verification : test_closed.a68, test_primary.a68

  TODO 08 - DECLARATIONS : IDENTITE, VARIABLE, MODE ET PRIO [A FAIRE]
            Declaration d'identite : INT x = 42 ; BOOL flag = TRUE ;
              CHAR c = "A" ; STRING msg = "Hello" ; listes
              INT a = 1, b = 2, c2 = 3 ; identite constante (pas
              d'affectation possible)
            Declaration de variable : INT y := 10 ; REF INT p := NIL ;
              [1:5] INT a := (10, 20, 30, 40, 50) ; [1:3] INT b ;
              HEAP INT h ; LOC par defaut ; variable = identite d'un
              REF generateur
            Variable sans initialiseur : valeur indefinie initialisee a
              zero pour eviter les surprises
            Declaration MODE (TODO 04), PRIO (TODO 17), PROC (TODO 16) et
              OP (TODO 17) reconnues ici
            Initialiseur converti vers le mode declare par coercition
              (TODO 09)
            Verification : test_decl.a68, test_dataseg.a68, hello.a68

  TODO 09 - COERCITIONS [A FAIRE]
            Forces de contexte : forte, ferme, meek, faible, douce
            Coercitions : dereferencement (REF INT vers INT, plusieurs
              niveaux), deprocedurage (PROC INT vers INT), elargissement
              (INT vers REAL), enrobage (valeur vers tableau d'un
              element), union (valeur vers UNION), vidage (valeur
              ignoree, voiding)
            Application selon le contexte : operande de formule (ferme),
              source d'affectation (forte), condition (meek, BOOL),
              argument de procedure (fort), selecteur de CASE (meek)
            Une valeur utilisee comme instruction est videe : a + 5 ;
              ou un appel de PROC INT sans utiliser le resultat
            Erreur si aucune suite de coercitions ne convient ; mode
              equilibre des branches de IF et de CASE (balancing)
            Constantes : repliement INT vers REAL au moment de la
              compilation
            Verification : coerce.a68, test_primary.a68

  TODO 10 - UNITES PRIMAIRES [A FAIRE]
            Identificateurs (variables, identites, parametres) avec
              chargement par adresse ou par valeur
            Denotations : INT, REAL, BOOL, CHAR et STRING
            Appel de procedure f(a, b) et constructeur de structure
              POINT(3, 7) distingues par le mode du nom
            Selection x OF p (priorite la plus haute) en lecture et en
              ecriture ; selection sur une structure referencee
            Indexation a[i] et tranche a[1:5] (details au TODO 15)
            Clause fermee ou conditionnelle utilisee comme primaire
            Cast : mode suivi d'une clause fermee si les exemples en ont
            Adresse d'un champ ou d'un element pour les affectations
            Verification : test_primary.a68, structs.a68, refs.a68

  TODO 11 - FORMULES ET OPERATEURS STANDARD [A FAIRE]
            Priorites : monadiques (ABS SIGN ODD NOT BIN LWB UPB) au plus
              haut ; ** SHL SHR (8) ; * / OVER MOD (7) ; + - (6) ;
              < <= > >= (5) ; = /= (4) ; AND (3) ; OR (2)
            Arithmetique INT et REAL : + - * / OVER MOD **, avec
              elargissement INT vers REAL ; / sur deux INT donne un REAL
            Comparaisons sur INT, REAL, CHAR, BOOL ; AND OR NOT ; BITS
              avec SHL SHR AND OR, BIN et ABS
            Chaines : concatenation + et comparaisons < <= = /= >= >
              (routines du runtime)
            Monadiques : ABS, SIGN, ODD, NOT, - et + unaires
            Repliement des constantes (2 ** 8, ABS -5) avec detection du
              debordement et de la division par zero constante
            Division par zero a l'execution : controle avant IDIV
            Mode de resultat de chaque operateur, erreur si les modes
              des operandes ne conviennent pas
            Verification : test_formula.a68, math.a68, ops.a68

  TODO 12 - CLAUSES CONDITIONNELLES ET REPETITIVES [A FAIRE]
            IF ... THEN ... ELIF ... ELSE ... FI avec valeur (INT a :=
              IF TRUE THEN 42 ELSE 0 FI) et sans ELSE (valeur vide)
            CASE ... IN u1, u2, u3 OUT autre ESAC avec selecteur INT,
              OUSE enchaine, choix hors liste vers OUT ou SKIP
            Formes abregees : (cond | alors | sinon) et
              (indice | u1, u2 | defaut)
            Mode du resultat : equilibrage des branches (INT et INT,
              INT et REAL vers REAL, VOID si l'une est VOID)
            Boucles : FOR i FROM a BY b TO c WHILE cond DO ... OD ; FROM
              par defaut 1, BY par defaut 1, TO ou DOWNTO, BY negatif,
              WHILE seul, boucle infinie sans TO ; variable de controle
              INT locale a la boucle, bornes evaluees une fois
            Boucles imbriquees, labels et GOTO de sortie
            Verification : control.a68, test_cond.a68, test_loop.a68

  TODO 13 - STRUCTURES (STRUCT) [A FAIRE]
            MODE POINT = STRUCT(INT x, INT y) ; champs de modes
              differents, alias de mode, structures emboitees
            Disposition des champs (decalage de chaque champ, taille
              totale alignee)
            Constructeur POINT(3, 7) et initialisation d'une variable
            Selection x OF p en lecture et en ecriture : x OF p := 5
            Affectation d'une structure entiere (copie des octets)
            Passage et retour de structures par les procedures
            Verification : structs.a68, test_struct.a68

  TODO 14 - REFERENCES ET AFFECTATIONS [A FAIRE]
            Mode REF m : adresse ; variable locale = identite d'un
              REF m ; generateurs LOC (cadre de la clause) et HEAP
              (tas Win32, appel du runtime)
            Affectation := avec dereferencement automatique du membre de
              droite ; affectation inversee =: ; affectations composees
              +:= -:= *:= /:= (division entiere sur INT) %:=
            Identite IS et ISNT sur des references ; NIL ; test
              p IS NIL ; dereferencement d'un NIL detecte a l'execution
            REF REF m : niveaux multiples de dereferencement
            Valeur d'une affectation : la reference du membre de gauche
            Verification : refs.a68, test_ref.a68, coerce.a68

  TODO 15 - TABLEAUX, TRANCHES ET CHAINES [A FAIRE]
            Declaration [l:u] mode, [1:5] INT a := (10, 20, 30, 40, 50) ;
              dimensions multiples, bornes dynamiques (expressions
              evaluees a l'entree de la clause), tableau sans initialiseur
            Descripteur : pointeur, borne inferieure, borne superieure,
              pas ; reserve sur le tas (ou dans le cadre) et liberee a la
              sortie de la clause pour LOC
            Acces a[i] avec controle des bornes (runtime CHKIDX),
              tranche a[l:u] (nouveau descripteur sans copie), LWB et UPB
            Affichage de rangee (10, 20, 30) comme initialiseur
            STRING = tableau flexible de CHAR : denotation, concatenation
              +, tranche hello[1:5], comparaison, passage a print
            Verification : arrays.a68, test_array.a68, test_runtime.a68

  TODO 16 - PROCEDURES (PROC) [A FAIRE]
            Declaration PROC double = (INT x) INT : x + x ; parametres
              multiples, resultat VOID, corps = unite quelconque
            Appels : f(a, b), imbriques (double(add(3, 4))), recursion
              (factorial, fib) ; appel sans parametres noop()
            Convention d'appel : arguments empiles de droite a gauche,
              puis le lien statique, l'appelee nettoie la pile (RET n),
              resultat dans EAX (REAL dans ST(0), structures par adresse
              de retour)
            Procedures imbriquees (acces aux variables des niveaux
              englobants par chaine de liens statiques)
            Procedures comme valeurs : variable PROC, paire (entree,
              lien), appel indirect, deprocedurage (TODO 09)
            Cadre de pile : prologue, variables locales initialisees a
              zero, epilogue
            Verification : procs.a68, test_proc.a68

  TODO 17 - DEFINITIONS D'OPERATEURS : OP ET PRIO [A FAIRE]
            OP ADDX = (INT a, INT b) INT : a + b + 1 ; operateur
              dyadique utilisateur et monadique (OP DBL = (INT x) INT)
            PRIO MYMUL = 5 : priorite de 1 a 9 declaree avant ou apres
              l'operateur ; priorite par defaut pour un dyadique sans
              PRIO (a signaler)
            Surcharge : plusieurs definitions d'un meme symbole selon les
              modes des operandes ; resolution dans la table du TODO 05
            Operateurs composes dans une formule : (10 ADDX 5) MYMUL 2
            Un operateur est une procedure appelee avec les memes
              conventions (TODO 16), nom ASM _A68O_
            Verification : ops.a68, test_op.a68

  TODO 18 - MODES UNIS (UNION) ET CLAUSE DE CONFORMITE [A FAIRE]
            MODE NOMBRE = UNION(INT, REAL) ; alternatives distinctes ;
              union a une alternative (UNION(INT)) ; union de trois modes
            Representation : etiquette de mode puis valeur ; coercition
              d'union d'une valeur INT, BOOL ou CHAR
            EMPTY : union sans valeur
            Clause de conformite :
              CASE x IN (INT i) : unite, (REAL r) : unite OUT unite ESAC
              avec liaison du nom i a la valeur extraite
            Corps composes (BEGIN ... END) dans une alternative, OUT
              facultatif, selection selon l'etiquette
            Mode du resultat equilibre comme au TODO 12
            Verification : union.a68, test_union.a68

  TODO 19 - TRANSPUT, CLAUSES COLLATERALES ET PARALLELES [A FAIRE]
            print((a, b, c)) : liste collaterale de valeurs de modes
              differents ; chaque element appelle la routine du runtime
              selon son mode : INT, REAL, BOOL, CHAR, STRING, newline,
              space ; print(chaine) a un seul element sans parentheses
              internes ; print((newline)) ; valeurs calculees
              (x + y, nom + ver)
            whole(n, largeur) : INT vers STRING (largeur 0 = minimale),
              nombres negatifs
            Lecture minimale read((x)) pour INT, REAL, CHAR, STRING si
              utile (a documenter, entree standard)
            Clause collaterale (u1, u2, u3) : evaluation de gauche a
              droite, utilisee aussi pour les initialiseurs de rangees
            PAR (u1, u2) et PAR BEGIN ... END : execution sequentielle
              avec avertissement (pas de vrais processus)
            Formats d'affichage a documenter : entier decimal, reel en
              notation fixe, BOOL TRUE / FALSE ou true / false (a
              trancher d'apres les exemples), fin de ligne CR LF
            Verification : transput.a68, hello.a68, test_transput.a68,
              test_collateral.a68

  TODO 20 - ENCODEUR BINAIRE x86-32 [A FAIRE]
            Reprendre et adapter l'encodeur d'AL60CW32 : chaque
              instruction du code interne en octets (MOV, MOVZX, LEA,
              PUSH, POP, ADD, SUB, IMUL, IDIV, CDQ, NEG, NOT, AND, OR,
              XOR, CMP, TEST, INC, DEC, SHL, SHR, SAR, SETcc, Jcc, JMP,
              CALL, RET, REP MOVSD, REP STOSD et les instructions x87)
            Operandes 8, 16 et 32 bits, ModRM / SIB / deplacement 8 ou 32
              bits (cas [EBP], [ESP], [sym], [sym + index*echelle])
            Tampons de code et de donnees ; table des etiquettes (code,
              donnees, externe) ; relocations ABS32 et REL32
            Sauts courts ou longs choisis par relaxation
            Donnees : zeros, chaines avec 0 final, entiers, reels,
              descripteurs et tables d'adresses avec relocations ;
              imports = cibles d'appel non definies
            Mode -d : <sortie>.lst, listing hexadecimal
            Verification : decoder chaque instruction avec objdump
              (TESTS\AL60CW32\chkenc.py) sur tous les exemples

  TODO 21 - ECRIVAINS PE (.EXE) ET COFF (.OBJ) [A FAIRE]
            PE : en-tete MZ + souche DOS, signature PE, COFF File Header
              (machine 386, 3 sections), Optional Header (magic $010B,
              ImageBase $00400000, alignements 4096 / 512, console),
              sections .text, .data et .idata (import de kernel32.dll :
              descripteurs, ILT, IAT, noms avec indice), relocations
              resolues a l'ecriture, point d'entree _A68P_Main
            COFF (option -obj) : sections .text et .data avec
              relocations DIR32 et REL32, table des symboles (sections
              avec entree auxiliaire, point d'entree externe, externes
              non definis), table des chaines
            Un symbole du runtime non defini est une erreur ; tout autre
              nom est importe de kernel32.dll
            Option -obj : ne jamais produire de .EXE ; -obj -asm :
              .OBJ et .ASM ; sans -obj : .EXE seulement
            Verification : objdump -x / -p / -h -t -r ; un .OBJ lie avec
              lld-link doit donner le meme comportement que l'.EXE direct
              (TESTS\AL60CW32\runpe.c comme executeur de test)

  TODO 22 - RUNTIME ALGOL 68 POUR WIN32 [A FAIRE]
            Runtime ecrit en assembleur 80386, integre au compilateur
              sous forme de texte et assemble par un mini-assembleur,
              sans bibliotheque C ; seules les fonctions de kernel32.dll
              sont importees (GetStdHandle, WriteFile, ReadFile,
              ExitProcess, GetProcessHeap, HeapAlloc, HeapFree)
            Emission des seules routines utilisees (fermeture
              transitive des appels _A68RT_) ; le runtime figure dans le
              listing .ASM qui devient autonome
            Routines : WRITESTR, WRITEINT, WRITEREAL, WRITEBOOL,
              WRITECHAR, NEWLINE, SPACE, WHOLE, STRCAT, STRCMP,
              STRSLICE, POW, CHKIDX, DIVZERO, NILREF, ALLOC (tas, memoire
              mise a zero), FREE, READINT, READREAL, READCHAR
            Messages d'erreur d'execution (indice hors bornes, division
              par zero, reference NIL) et code de sortie 1
            Formats documentes : entier decimal, reel en notation fixe
              (6 decimales au plus, zeros finaux supprimes), BOOL,
              fin de ligne CR LF
            Verification : exemples executes (chargeur PE de test),
              programmes fautifs a l'execution

  TODO 23 - GESTION DES ERREURS ET AVERTISSEMENTS [A FAIRE]
            Erreurs lexicales : caractere invalide, chaine ou
              commentaire non ferme, entier hors limites
            Erreurs syntaxiques : unite inattendue, END FI OD ESAC
              manquant ou mal apparie, parenthese ou crochet non ferme,
              point-virgule manquant
            Erreurs de modes : coercition impossible, operateur sans
              definition pour les modes des operandes, nombre ou modes
              d'arguments incorrects, identificateur non declare,
              doublon dans une meme portee, selection sur un mode qui
              n'est pas une structure, indice sur un non-tableau,
              clause de conformite incorrecte, division par zero
              constante
            Avertissements : PAR execute sequentiellement, PRIO absente,
              etiquette inutilisee, conversions implicites, variable non
              initialisee
            Format "fichier(ligne,col) : erreur/avertissement : message"
            Recuperation pour reporter plusieurs erreurs
            Compteurs finaux, code de retour 1 si erreurs, aucun fichier
              de sortie corrompu ou partiel (les fichiers crees sont
              supprimes sur erreur fatale)
            Exemples : programmes fautifs du script de test

  TODO 24 - PROGRAMME PRINCIPAL, MODES VERBEUX ET DEBOGAGE [A FAIRE]
            Run : lexeur -> parseur -> modes et coercitions ->
              generation -> runtime -> encodeur -> ecrivain (PE ou
              COFF) -> .ASM optionnel -> rapport
            Mode -v : phases, tailles .text et .data, relocations,
              imports, fichiers produits
            Mode -d : tokens, modes, table des symboles, arbre d'unites,
              code interne et listing hexadecimal
            Mode -w / -w+ : activer les avertissements ; -w- : les
              desactiver
            Verifier que l'absence de -asm ne cree jamais de .ASM, que
              -obj ne cree jamais de .EXE, et que sans option on obtient
              uniquement le .EXE

  TODO 25 - VALIDATION SUR TOUS LES EXEMPLES SAMPLES\ALGOL68\* [A FAIRE]
            Compiler les 27 fichiers : arrays, coerce, control, hello,
              math, ops, procs, refs, structs, test_array, test_closed,
              test_collateral, test_cond, test_dataseg, test_decl,
              test_formula, test_loop, test_op, test_primary, test_proc,
              test_ref, test_runtime, test_struct, test_transput,
              test_union, transput, union
            Creer les sorties attendues (.exp) puis un script
              TESTS\test_al68cw32.sh (modele : test_al60cw32.sh)
              executant chaque .EXE via Wine ou le chargeur PE minimal
              et comparant la sortie, a completer par des resultats
              calcules a la main pour ne pas dependre uniquement du
              compilateur
            Tester les trois modes : .EXE (defaut), .OBJ (-obj) et
              .ASM (-asm), verifier que -asm est optionnel
            Controler l'encodage avec objdump, lier les .OBJ avec
              lld-link, et verifier les erreurs avec des programmes
              fautifs (message, code de retour, aucun fichier)
            Cas speciaux : test_dataseg, test_decl, test_closed,
              test_formula, test_cond, test_op, test_primary, test_proc,
              test_struct et test_union sont des expressions et
              declarations isolees (peu ou pas de sortie) qui doivent
              produire un .EXE valide
            Mettre a jour README.md (ligne AL68CW32.PAS), ajouter
              DOC\TODO\AL68CW32.txt et BINLINUX\AL68CW32 (WIN32\
              al68cw32.exe a produire sous Windows)
  ============================================================ *)
