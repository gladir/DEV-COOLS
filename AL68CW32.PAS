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

  ETAT : TODO 01 a 04 implementes (squelette en sections, pipeline en 7
         phases, options, constantes, limites et nommage, lexeur, modes) ;
         TODO 05 a 25 a faire.

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

  TODO 01 - ARCHITECTURE ET PIPELINE DU COMPILATEUR [IMPLEMENTE]
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
            Realise : directives {$MODE TP}, {$H-}, {$I-} ; 16 sections
              numerotees (constantes, types, variables, utilitaires,
              options, lexeur, modes, symboles et portees, arbre
              d'unites et parseur, coercitions, generateur et code
              interne, encodeur, ecrivains, runtime, erreurs et
              rapport, pipeline) ; type TPhase a sept phases (PH_LEX,
              PH_PARSE, PH_MODES, PH_CODEGEN, PH_ENCODE, PH_WRITE,
              PH_REPORT) ; Run execute les phases dans l'ordre (les
              phases vides seront remplies par les TODOs suivants) ;
              code de retour EXIT_OK ou EXIT_ERROR selon le nombre
              d'erreurs
            Verifie : compilation avec fpc -Mtp sans erreur (une seule note),
              execution : sept lignes de phases puis code
              de retour 0 ; lignes de 80 colonnes au plus

  TODO 02 - OPTIONS, CONSTANTES, LIMITES ET NOMMAGE [IMPLEMENTE]
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
            Realise : TOptions et InitOptions ; ParseArgs (options -o,
              -obj, -asm, -v, -d, -w, -w+, -w-, -h, --help et /?, une seule
              source, .a68 ajoute (ou .alg) si l'extension manque) ;
              ShowUsage et ShowBanner ; FatalError, ErrorAt, WarnAt et
              WarnMsg ; NoteOutput et RemoveOutputs (fichiers crees
              supprimes sur erreur fatale) ; constantes PE, COFF et ABI,
              tampons binaires et limites internes (symboles, modes,
              unites, portees, champs, alternatives d'union...) ;
              prefixes _A68V_, _A68P_, _A68O_, _A68K_, _A68M_, _A68L_,
              _A68RT_ et _A68T_ avec MangleVar, MangleProc, MangleOp,
              MangleMode, MangleRT, MangleUserLabel, MangleTemp,
              MangleLabel et MangleStr ; ItoS, ItoSZ, UpCaseStr, StrLower,
              AsmIdent, ExtPos, GetExt, ReplaceExt, FileExists ;
              Run n'affiche banniere et phases qu'avec -v ; le lexeur,
              le parseur et le rapport tournent toujours, les autres
              phases seulement sans erreur
            Verifie : sans argument -> usage et code 2 ; -h -> code 0 ;
              source introuvable, extension inconnue, option inconnue,
              -o vers un .asm ou vers le source -> refus ; fichiers
              nommes par defaut (.exe, .obj, .asm) pour -o, -obj, -asm

  TODO 03 - LEXEUR ALGOL 68 [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_INT, TK_REAL, TK_BOOL, TK_CHAR,
              TK_STRING, TK_TAG (identificateur contenant une
              minuscule), TK_KEYWORD (mot reserve de la syntaxe), TK_BOLD
              (autre mot en majuscules : nom de mode ou d'operateur),
              TK_OP (symbole d'operateur), TK_PUNCT
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
            Realise : source charge en memoire (LexLoad, LexAt avec
              regard en avant de plusieurs caracteres) ; PhaseLex range
              tous les tokens dans TokTab (EOF inclus), ce qui permet au
              parseur de regarder en avant ; denotations de chaines dans
              LitTab ; mots reserves dans KeywordTab ; &, ~, :=: et :/=:
              donnent AND, NOT, IS et ISNT ; GO suivi de TO devient GOTO ;
              nombres en base (16rFF, 2r1010) avec controle de la base et
              des chiffres ; un seul caractere "A" donne TK_CHAR, ""
              donne une chaine vide ; erreurs : caractere invalide,
              chaine non fermee ou trop longue, commentaire non termine
              (mot ou dieze attendu), entier, exposant ou reel hors
              limites, base invalide, identificateur trop long
            Verifie : les 27 exemples sont lus sans erreur (de 18 tokens
              pour test_dataseg a 353 pour control) ; tous les symboles
              composes (+:= -:= *:= /:= %:= %*:= =: := :=: :/=: +* ** /=
              <= >= |: et les autres), les trois formes de commentaires
              et les pragmats, les denotations (3.14, .5e2, 1.5e-3, 2e5,
              16rFF), GO TO et les erreurs ci-dessus donnent le resultat
              attendu avec -d

  TODO 04 - MODES (TYPES) ET LEUR REPRESENTATION [IMPLEMENTE]
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
            Realise : section 7 ; TMode (genre, element, dimensions,
              FLEX, liste dans un pool, taille) ; modes de base aux
              indices fixes MD_ERROR, MD_VOID, MD_INT, MD_REAL, MD_BOOL,
              MD_CHAR, MD_BITS, MD_NIL et MD_STRING (FLEX [] CHAR) ;
              constructeurs ModeRef et ModeRow (modes partages),
              ModeStructTmp, ModeUnionTmp et ModeProcTmp (liste en cours
              ModeTmpAdd) ; union : alternatives aplaties, sans doublon et
              triees, VOID refuse ; structure : doublon de champ signale ;
              ModeFwd et ModeDefine pour les modes recursifs ; ModeSame :
              equivalence structurelle, recursion comprise (paires deja
              rencontrees supposees equivalentes) ; ModeDeref, ModeDeref1,
              ModeFindField, ModeUnionHas ; ModeSize : INT, BOOL, CHAR,
              BITS, REF 4 octets, REAL 8, PROC 8 (entree et lien statique),
              tableau 4 + 12 par dimension (STRING 16), STRUCT somme des
              champs, UNION 4 + alternative la plus large, recursion sans
              REF detectee (ModeBadRec) ; ModeFieldOffset, ModeElemSize (1
              octet pour un CHAR) ; ModeName et ModeDump (-d)
            Verifie : harnais de 25 controles hors depot (tailles,
              partage, noms, STRING different de [] CHAR, structures de
              noms differents, NODE et NODE2 recursifs equivalents,
              recursion sans REF, unions dans un ordre quelconque,
              aplatissement, UNION a une alternative, VOID refuse,
              procedures) : tous reussis ; les modes des exemples
              (POINT, VEC3, NOMBRE, POLYVAL, WRAPPED) seront crees par le
              parseur aux TODOs 08, 13 et 18

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

Program AL68CW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-} { Desactiver les IO-check pour gerer nous-memes les erreurs }

{$IFDEF FPC}
Uses Math;
{$ENDIF}

{ ============================================================
  SECTION 1 - CONSTANTES, LIMITES ET NOMMAGE (TODO 01, 02)
  ============================================================ }
Const
  AL68CW32_VERSION = '0.1';
  AL68CW32_DATE    = '2026';

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Differences avec AL68C86 (cible 8086, 16 bits, DOS) :
      - registres 32 bits (EAX, EBX, ECX, EDX, ESI, EDI, EBP, ESP)
      - modele FLAT : pas de segments, pas de limite de 64 Ko
      - INT sur 32 bits signes, REAL sur 64 bits (x87)
      - sorties par API Win32 (kernel32) au lieu de INT 21h
      - sortie finale : .EXE (PE) ou .OBJ (COFF), .ASM optionnel }
  ABI_WORD_SIZE = 4;   { taille d un registre / d un INT en octets }
  ABI_REAL_SIZE = 8;   { REAL : flottant 64 bits (x87)             }
  ABI_RET_REG   = 'EAX';
  ABI_FRAME_REG = 'EBP';
  ABI_STACK_REG = 'ESP';
  ABI_PARAM_BASE = 8;  { [EBP+8] = dernier parametre empile : apres
                         EBP et l adresse de retour ; le lien statique
                         se trouve a cet endroit (TODO 16) }

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

  { ---- Tampons du code binaire (TODO 20, 21) ---- }
  MAX_BIN_CODE  = {$IFDEF FPC}262144{$ELSE}16384{$ENDIF};
  MAX_BIN_DATA  = {$IFDEF FPC}262144{$ELSE}16384{$ENDIF};
  MAX_BIN_LBL   = {$IFDEF FPC}8192{$ELSE}512{$ENDIF};
  MAX_BIN_FIX   = {$IFDEF FPC}131072{$ELSE}512{$ENDIF};

  { ---- Limites internes du compilateur (32 bits) ---- }
  MAX_SYM       = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};  { identificateurs }
  MAX_MODE      = {$IFDEF FPC}1024{$ELSE}64{$ENDIF};   { modes (TODO 04)  }
  MAX_MODEPOOL  = {$IFDEF FPC}8192{$ELSE}256{$ENDIF};  { champs, alternatives}
  MAX_UNIT      = {$IFDEF FPC}32768{$ELSE}512{$ENDIF}; { noeuds de l arbre}
  MAX_LABEL     = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}16{$ENDIF};     { portees emboitees}
  MAX_PROC      = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_FIELD     = {$IFDEF FPC}64{$ELSE}16{$ENDIF};     { champs de STRUCT }
  MAX_ALT       = {$IFDEF FPC}32{$ELSE}8{$ENDIF};      { modes d un UNION }
  MAX_DATA      = {$IFDEF FPC}2048{$ELSE}128{$ENDIF};
  MAX_ARRAY_DIM = 8;      { dimensions maximales d un tableau          }
  MAX_LOOP_NEST = 32;     { imbrication maximale des boucles           }
  MAX_ERRORS    = 30;     { arret apres ce nombre d erreurs            }
  MAX_STR       = 255;    { longueur maximale d une chaine litterale   }
  MAX_NAME      = 63;     { longueur maximale d un identificateur      }
  MAX_SRC       = {$IFDEF FPC}1048576{$ELSE}32000{$ENDIF}; { taille source }
  MAX_TOKEN     = {$IFDEF FPC}65536{$ELSE}2048{$ENDIF};    { tokens         }
  MAX_STRLIT    = {$IFDEF FPC}4096{$ELSE}128{$ENDIF};      { denotations    }

  { ---- Prefixes de nommage ASM ---- }
  A68_VAR_PFX   = '_A68V_';     { variable ou identite                 }
  A68_PROC_PFX  = '_A68P_';     { procedure                            }
  A68_OP_PFX    = '_A68O_';     { operateur defini par OP              }
  A68_STR_PFX   = '_A68K_';     { constante chaine litterale           }
  A68_MODE_PFX  = '_A68M_';     { descripteur de mode                  }
  A68_LBL_PFX   = '_A68L_';     { label de saut interne                }
  A68_USR_PFX   = '_A68L_USR_'; { etiquette Algol (goto)               }
  A68_RT_PFX    = '_A68RT_';    { routine runtime                      }
  A68_TEMP_PFX  = '_A68T_';     { temporaire ou thunk                  }
  A68_MAIN_NAME = '_A68P_Main'; { point d entree du programme          }

{ ============================================================
  SECTION 2 - TYPES (TODO 01, 02, 03, 04, 05)
  ============================================================ }
Type
  TString = String[255];

  TName = String[MAX_NAME];

  { Tokens du lexeur (TODO 03) : les mots en majuscules sont soit des
    mots reserves de la syntaxe (TK_KEYWORD), soit d autres mots en
    majuscules (TK_BOLD : noms de modes et d operateurs, resolus par la
    table des symboles) ; un identificateur contient une minuscule }
  TTokenKind = (
    TK_EOF,
    TK_INT,        { denotation entiere (IntVal)                      }
    TK_REAL,       { denotation reelle (RealVal)                      }
    TK_BOOL,       { TRUE ou FALSE (IntVal = 1 ou 0)                  }
    TK_CHAR,       { denotation d un caractere (IntVal = code)        }
    TK_STRING,     { denotation de chaine (IntVal = indice LitTab)    }
    TK_TAG,        { identificateur                                   }
    TK_KEYWORD,    { mot reserve de la syntaxe                        }
    TK_BOLD,       { autre mot en majuscules                          }
    TK_OP,         { symbole d operateur ou d affectation             }
    TK_PUNCT       { ; , ( ) [ ] : | et |:                            }
  );

  TToken = Record
    Kind    : TTokenKind;
    Val     : TName;       { texte ; symboles normalises            }
    IntVal  : LongInt;     { TK_INT, TK_BOOL, TK_CHAR, TK_STRING    }
    RealVal : Double;      { TK_REAL (et TK_INT)                    }
    Line    : Integer;
    Col     : Integer;
  End;

  { Modes (TODO 04) }
  TModeKind = (
    MK_ERROR,      { mode inconnu (apres une erreur)                 }
    MK_VOID,
    MK_INT,
    MK_REAL,
    MK_BOOL,
    MK_CHAR,
    MK_BITS,
    MK_NIL,        { mode de NIL : se coerce vers tout REF           }
    MK_REF,        { Sub = mode reference                            }
    MK_ROW,        { Sub = element, Dims dimensions, Flex            }
    MK_STRUCT,     { Count champs dans le pool a partir de First     }
    MK_UNION,      { Count alternatives triees, dans le pool         }
    MK_PROC,       { Sub = resultat, Count parametres dans le pool   }
    MK_FWD         { mode nomme en cours de definition (recursion)   }
  );

  TMode = Record
    Kind  : TModeKind;
    Sub   : Integer;
    Dims  : Integer;
    Flex  : Boolean;
    First : Integer;
    Count : Integer;
    Size  : LongInt;       { -1 : pas calcule, -2 : en cours         }
    Name  : TName;         { nom d un MK_FWD                         }
  End;

  { Options de la ligne de commande (TODO 02) }
  TOptions = Record
    SrcFile   : TString;    { fichier source .a68 / .alg              }
    OutFile   : TString;    { sortie principale (.exe ou .obj)        }
    AsmFile   : TString;    { listing .asm (si EmitAsm)               }
    Verbose   : Boolean;    { -v : banniere + statistiques            }
    DebugMode : Boolean;    { -d : dump des tokens, modes, code       }
    Warnings  : Boolean;    { -w : activer les avertissements         }
    EmitExe   : Boolean;    { produire un .EXE PE (defaut)            }
    EmitObj   : Boolean;    { -obj : produire seulement un .OBJ       }
    EmitAsm   : Boolean;    { -asm : produire aussi un .ASM           }
  End;

  { Etapes du pipeline :
      source .a68 -> lexeur -> parseur (arbre d unites)
      -> resolution des modes et coercitions
      -> generation du code interne (listing .ASM optionnel)
      -> encodeur binaire x86-32 -> ecrivain COFF (.OBJ) ou PE (.EXE) }
  TPhase = (
    PH_LEX,       { TODO 03 : lexeur                                  }
    PH_PARSE,     { TODO 05-08, 10 : symboles, arbre d unites         }
    PH_MODES,     { TODO 04, 09, 11-19 : modes et coercitions         }
    PH_CODEGEN,   { TODO 06, 11-19 : code interne + listing .ASM      }
    PH_ENCODE,    { TODO 20 : encodeur binaire x86-32                 }
    PH_WRITE,     { TODO 21 : ecrivain PE (.EXE) ou COFF (.OBJ)       }
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
  SECTION 4 - UTILITAIRES (TODO 02)
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
  La casse est normalisee en majuscules (les identificateurs et les
  mots reserves sont distingues par leur graphie dans le source, mais
  deux noms ne different jamais que par la casse dans le listing). }
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
  MangleVar := A68_VAR_PFX + AsmIdent(Name);
End;

Function MangleProc(Const Name : TString) : TString;
Begin
  MangleProc := A68_PROC_PFX + AsmIdent(Name);
End;

Function MangleOp(Const Name : TString; N : LongInt) : TString;
Begin
  MangleOp := A68_OP_PFX + AsmIdent(Name) + '_' + ItoS(N);
End;

Function MangleMode(N : LongInt) : TString;
Begin
  MangleMode := A68_MODE_PFX + ItoS(N);
End;

Function MangleRT(Const Name : TString) : TString;
Begin
  MangleRT := A68_RT_PFX + AsmIdent(Name);
End;

Function MangleUserLabel(Const Name : TString) : TString;
Begin
  MangleUserLabel := A68_USR_PFX + AsmIdent(Name);
End;

Function MangleTemp(N : LongInt) : TString;
Begin
  MangleTemp := A68_TEMP_PFX + ItoS(N);
End;

{ Labels internes et chaines : numerotation }
Function MangleLabel(N : LongInt) : TString;
Begin
  MangleLabel := A68_LBL_PFX + ItoSZ(N, 5);
End;

Function MangleStr(N : LongInt) : TString;
Begin
  MangleStr := A68_STR_PFX + ItoS(N);
End;

Function PhaseName(P : TPhase) : String;
Begin
  Case P Of
    PH_LEX     : PhaseName := 'lexeur';
    PH_PARSE   : PhaseName := 'parseur';
    PH_MODES   : PhaseName := 'modes et coercitions';
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
  WriteLn('AL68CW32: erreur fatale: ', Msg);
  RemoveOutputs;
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('AL68CW32: avertissement: ', Msg);
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
  WriteLn('AL68CW32 ', AL68CW32_VERSION, ' (', AL68CW32_DATE, ') - ',
          'Compilateur Algol 68 vers 80386 / Windows 32 bits');
End;

Procedure ShowUsage(Code : Integer);
Begin
  ShowBanner;
  WriteLn;
  WriteLn('Syntaxe: AL68CW32 <source.a68> [-o sortie] [-obj] [-asm]',
          ' [-v] [-d] [-w] [-w-] [-h]');
  WriteLn;
  WriteLn('  source.a68 : fichier Algol 68 source (.a68 ou .alg)');
  WriteLn('  -o nom     : nom du fichier de sortie principal');
  WriteLn('  -obj       : produire seulement un .OBJ (COFF), pas de .EXE');
  WriteLn('  -asm       : produire aussi un listing .ASM (optionnel)');
  WriteLn('  -v         : mode verbeux (phases, tailles, statistiques)');
  WriteLn('  -d         : debug (tokens, modes, symboles, code interne)');
  WriteLn('  -w, -w-    : activer / desactiver les avertissements');
  WriteLn('  -h, --help : cette aide');
  WriteLn;
  WriteLn('Par defaut, produit seulement source.exe (PE Windows 32 bits).');
  WriteLn('Sans -asm aucun .asm n''est cree ; avec -obj aucun .exe.');
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
        WriteLn('AL68CW32: -o demande un nom de fichier');
        ShowUsage(EXIT_USAGE);
      End;
      Opts.OutFile := ParamStr(I);
    End
    Else If (Arg <> '') And (Arg[1] = '-') Then
    Begin
      WriteLn('AL68CW32: option inconnue: ', Arg);
      ShowUsage(EXIT_USAGE);
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else
    Begin
      WriteLn('AL68CW32: argument inattendu: ', Arg);
      ShowUsage(EXIT_USAGE);
    End;
    Inc(I);
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('AL68CW32: fichier source manquant');
    ShowUsage(EXIT_USAGE);
  End;

  { Extension du source : .a68 ou .alg (.a68 ajoute si absente) }
  If ExtPos(Opts.SrcFile) = 0 Then
  Begin
    If FileExists(Opts.SrcFile + '.a68') Then
      Opts.SrcFile := Opts.SrcFile + '.a68'
    Else
      Opts.SrcFile := Opts.SrcFile + '.alg';
  End;
  Ext := GetExt(Opts.SrcFile);
  If (Ext <> '.a68') And (Ext <> '.alg') Then
    FatalError('extension non supportee (attendu .a68 ou .alg): ' +
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
  SECTION 6 - LEXEUR (TODO 03)
  ============================================================ }
Const
  KEYWORD_COUNT = 50;
  KeywordTab : Array[1..KEYWORD_COUNT] Of String[7] = (
    'BEGIN', 'END', 'IF', 'THEN', 'ELIF', 'ELSE', 'FI', 'CASE', 'IN',
    'OUSE', 'OUT', 'ESAC', 'FOR', 'FROM', 'BY', 'TO', 'DOWNTO', 'WHILE',
    'DO', 'OD', 'MODE', 'STRUCT', 'UNION', 'PROC', 'OP', 'PRIO', 'REF',
    'HEAP', 'LOC', 'INT', 'REAL', 'BOOL', 'CHAR', 'STRING', 'BITS',
    'BYTES', 'COMPL', 'VOID', 'FLEX', 'PAR', 'GOTO', 'SKIP', 'NIL',
    'EMPTY', 'OF', 'IS', 'ISNT', 'AT', 'EXIT', 'LONG'
  );

Var
  SrcBuf     : Array[0..MAX_SRC] Of Char;  { source en memoire }
  SrcLen     : LongInt;
  LexPos     : LongInt;    { indice du caractere courant          }
  LexLine    : Integer;    { ligne du caractere courant           }
  LexCol     : Integer;    { colonne du caractere courant         }
  TokTab     : Array[0..MAX_TOKEN - 1] Of TToken;
  TokCount   : LongInt;    { tokens ranges dans TokTab (EOF inclus)}
  LitTab     : Array[0..MAX_STRLIT - 1] Of TString;
  LitCount   : LongInt;    { denotations de chaines               }

{ Charge le fichier source en memoire }
Procedure LexLoad;
Var
  F : File;
  N : LongInt;
Begin
  Assign(F, Opts.SrcFile);
  Reset(F, 1);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le source: ' + Opts.SrcFile);
  BlockRead(F, SrcBuf, MAX_SRC, N);
  If (IOResult <> 0) Or (N < 0) Then N := 0;
  If N >= MAX_SRC Then
  Begin
    Close(F);
    FatalError('source trop volumineux (max ' + ItoS(MAX_SRC) +
               ' octets)');
  End;
  Close(F);
  SrcLen := N;
  SrcBuf[SrcLen] := #0;
  LexPos  := 0;
  LexLine := 1;
  LexCol  := 1;
End;

{ Caractere a LexPos + K ; #0 a la fin (un NUL reel est invalide) }
Function LexAt(K : LongInt) : Char;
Begin
  If LexPos + K >= SrcLen Then
    LexAt := #0
  Else If SrcBuf[LexPos + K] = #0 Then
    LexAt := #1
  Else
    LexAt := SrcBuf[LexPos + K];
End;

Function LexCur : Char;
Begin
  LexCur := LexAt(0);
End;

Procedure LexNextChar;
Begin
  If LexPos >= SrcLen Then Exit;
  If SrcBuf[LexPos] = #10 Then
  Begin
    Inc(LexLine);
    LexCol := 1;
  End
  Else
    Inc(LexCol);
  Inc(LexPos);
End;

Function LexAtEnd : Boolean;
Begin
  LexAtEnd := LexPos >= SrcLen;
End;

Function IsLetter(C : Char) : Boolean;
Begin
  IsLetter := C In ['A'..'Z', 'a'..'z'];
End;

Function IsDigit(C : Char) : Boolean;
Begin
  IsDigit := C In ['0'..'9'];
End;

Function IsWordChar(C : Char) : Boolean;
Begin
  IsWordChar := C In ['A'..'Z', 'a'..'z', '0'..'9', '_'];
End;

Function IsKeyword(Const W : TName) : Boolean;
Var
  I : Integer;
Begin
  IsKeyword := False;
  For I := 1 To KEYWORD_COUNT Do
    If KeywordTab[I] = W Then
    Begin
      IsKeyword := True;
      Exit;
    End;
End;

Function TokenKindName(K : TTokenKind) : TString;
Begin
  Case K Of
    TK_EOF     : TokenKindName := 'EOF';
    TK_INT     : TokenKindName := 'INT';
    TK_REAL    : TokenKindName := 'REAL';
    TK_BOOL    : TokenKindName := 'BOOL';
    TK_CHAR    : TokenKindName := 'CHAR';
    TK_STRING  : TokenKindName := 'STRING';
    TK_TAG     : TokenKindName := 'TAG';
    TK_KEYWORD : TokenKindName := 'KEYWORD';
    TK_BOLD    : TokenKindName := 'BOLD';
    TK_OP      : TokenKindName := 'OP';
    TK_PUNCT   : TokenKindName := 'PUNCT';
  End;
End;

{ Mot : lettres, chiffres et soulignes. Un mot sans minuscule est un
  mot en majuscules (mot reserve ou nom de mode / d operateur). }
Procedure LexScanWord(Var T : TToken);
Var
  HasLower : Boolean;
  TooLong  : Boolean;
Begin
  T.Val := '';
  HasLower := False;
  TooLong  := False;
  While IsWordChar(LexCur) Do
  Begin
    If LexCur In ['a'..'z'] Then HasLower := True;
    If Length(T.Val) < MAX_NAME Then
      T.Val := T.Val + LexCur
    Else If Not TooLong Then
    Begin
      ErrorAt(T.Line, T.Col, 'identificateur trop long (max ' +
              ItoS(MAX_NAME) + ' caracteres)');
      TooLong := True;
    End;
    LexNextChar;
  End;
  If HasLower Then
    T.Kind := TK_TAG
  Else If (T.Val = 'TRUE') Or (T.Val = 'FALSE') Then
  Begin
    T.Kind := TK_BOOL;
    If T.Val = 'TRUE' Then T.IntVal := 1 Else T.IntVal := 0;
  End
  Else If IsKeyword(T.Val) Then
    T.Kind := TK_KEYWORD
  Else
    T.Kind := TK_BOLD;
End;

{ Valeur d un chiffre en base 16 ; -1 si ce n est pas un chiffre }
Function DigitValue(C : Char) : Integer;
Begin
  If C In ['0'..'9'] Then
    DigitValue := Ord(C) - Ord('0')
  Else If C In ['a'..'f'] Then
    DigitValue := Ord(C) - Ord('a') + 10
  Else If C In ['A'..'F'] Then
    DigitValue := Ord(C) - Ord('A') + 10
  Else
    DigitValue := -1;
End;

{ Nombre : entier (123), entier en base (16rFF), reel (3.14, .5,
  1.5e-3, 2e5) }
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
  Base    : LongInt;
  BaseOK  : Boolean;
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
    If Length(T.Val) < MAX_NAME Then T.Val := T.Val + LexCur;
    LexNextChar;
  End;

  { entier en base : <base>r<chiffres> }
  If (LexCur = 'r') And (DigitValue(LexAt(1)) >= 0) And Not IsReal And
     (T.Val <> '') And (Length(T.Val) <= 2) Then
  Begin
    Base := T.IntVal;
    BaseOK := (Base >= 2) And (Base <= 16);
    If Not BaseOK Then
      ErrorAt(T.Line, T.Col, 'base invalide: ' + T.Val + 'r');
    If Length(T.Val) < MAX_NAME Then T.Val := T.Val + 'r';
    LexNextChar;
    T.IntVal := 0;
    IntOvf := False;
    While DigitValue(LexCur) >= 0 Do
    Begin
      Digit := DigitValue(LexCur);
      If BaseOK And (Digit >= Base) Then
      Begin
        ErrorAt(LexLine, LexCol, 'chiffre invalide en base ' +
                ItoS(Base) + ': ' + LexCur);
        BaseOK := False;
      End;
      If T.IntVal > (MaxLongInt - Digit) Div Base Then
        IntOvf := True
      Else
        T.IntVal := T.IntVal * Base + Digit;
      If Length(T.Val) < MAX_NAME Then T.Val := T.Val + LexCur;
      LexNextChar;
    End;
    T.Kind := TK_INT;
    If IntOvf Then
    Begin
      ErrorAt(T.Line, T.Col, 'entier hors limites: ' + T.Val);
      T.IntVal := MaxLongInt;
    End;
    T.RealVal := T.IntVal;
    Exit;
  End;

  { partie fractionnaire : le point doit etre suivi d un chiffre }
  If (LexCur = '.') And IsDigit(LexAt(1)) Then
  Begin
    IsReal := True;
    If Length(T.Val) < MAX_NAME Then T.Val := T.Val + '.';
    LexNextChar;
    While IsDigit(LexCur) Do
    Begin
      Mant := Mant * 10 + (Ord(LexCur) - Ord('0'));
      Dec(E10);
      If Length(T.Val) < MAX_NAME Then T.Val := T.Val + LexCur;
      LexNextChar;
    End;
  End;

  { exposant : e ou E suivi de [+|-] chiffres }
  If (LexCur In ['E', 'e']) And
     (IsDigit(LexAt(1)) Or
      ((LexAt(1) In ['+', '-']) And IsDigit(LexAt(2)))) Then
  Begin
    IsReal := True;
    If Length(T.Val) < MAX_NAME Then T.Val := T.Val + LexCur;
    LexNextChar;
    ExpNeg := False;
    If LexCur In ['+', '-'] Then
    Begin
      ExpNeg := (LexCur = '-');
      If Length(T.Val) < MAX_NAME Then T.Val := T.Val + LexCur;
      LexNextChar;
    End;
    ExpV := 0;
    While IsDigit(LexCur) Do
    Begin
      If ExpV < 10000 Then
        ExpV := ExpV * 10 + (Ord(LexCur) - Ord('0'));
      If Length(T.Val) < MAX_NAME Then T.Val := T.Val + LexCur;
      LexNextChar;
    End;
    If ExpNeg Then ExpV := -ExpV;
    E10 := E10 + ExpV;
  End;

  If IsReal Then
  Begin
    T.Kind := TK_REAL;
    If (E10 > 308) Or (E10 < -308) Then
    Begin
      ErrorAt(T.Line, T.Col, 'exposant hors limites: ' + T.Val);
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
        ErrorAt(T.Line, T.Col, 'reel hors limites: ' + T.Val);
        T.RealVal := 0;
      End;
    End;
  End
  Else
  Begin
    T.Kind := TK_INT;
    If IntOvf Then
    Begin
      ErrorAt(T.Line, T.Col, 'entier hors limites: ' + T.Val);
      T.IntVal := MaxLongInt;
    End;
    T.RealVal := T.IntVal;
  End;
End;

{ "texte" : un guillemet double s ecrit "" ; sur une seule ligne.
  Un seul caractere donne une denotation CHAR, sinon STRING. }
Procedure LexScanString(Var T : TToken);
Var
  S       : TString;
  TooLong : Boolean;
  Closed  : Boolean;
Begin
  S := '';
  TooLong := False;
  Closed  := False;
  LexNextChar;                           { guillemet ouvrant }
  While (LexCur <> #10) And Not LexAtEnd And Not Closed Do
  Begin
    If LexCur = '"' Then
    Begin
      If LexAt(1) = '"' Then
      Begin
        S := S + '"';
        LexNextChar;
        LexNextChar;
      End
      Else
        Closed := True;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + LexCur
      Else If Not TooLong Then
      Begin
        ErrorAt(T.Line, T.Col, 'chaine trop longue (max ' +
                ItoS(MAX_STR) + ' caracteres)');
        TooLong := True;                 { une seule erreur par chaine }
      End;
      LexNextChar;
    End;
  End;
  If Closed Then
    LexNextChar
  Else
    ErrorAt(T.Line, T.Col, 'chaine non fermee');
  If Length(S) = 1 Then
  Begin
    T.Kind   := TK_CHAR;
    T.IntVal := Ord(S[1]);
    T.Val    := S;
  End
  Else
  Begin
    T.Kind := TK_STRING;
    If LitCount >= MAX_STRLIT Then
      FatalError('trop de denotations de chaines (max ' +
                 ItoS(MAX_STRLIT) + ')');
    LitTab[LitCount] := S;
    T.IntVal := LitCount;
    Inc(LitCount);
    T.Val := Copy(S, 1, MAX_NAME);
  End;
End;

{ Commentaire entre dieses : # ... # (le # ouvrant est deja lu) }
Procedure LexSkipHash(StartLine, StartCol : Integer);
Begin
  While (LexCur <> '#') And Not LexAtEnd Do
    LexNextChar;
  If LexCur = '#' Then
    LexNextChar
  Else
    ErrorAt(StartLine, StartCol, 'commentaire non termine (# attendu)');
End;

{ Commentaire ou pragmat introduit par un mot en majuscules (CO,
  COMMENT, PR, PRAGMAT) : ignore jusqu au meme mot, isole, qui le ferme }
Procedure LexSkipWord(Const W : TName; StartLine, StartCol : Integer);
Var
  Cand   : TName;
  Closed : Boolean;
Begin
  Closed := False;
  While Not Closed And Not LexAtEnd Do
  Begin
    If IsLetter(LexCur) Then
    Begin
      Cand := '';
      While IsWordChar(LexCur) Do
      Begin
        If Length(Cand) < MAX_NAME Then Cand := Cand + LexCur;
        LexNextChar;
      End;
      If Cand = W Then Closed := True;
    End
    Else
      LexNextChar;
  End;
  If Not Closed Then
    ErrorAt(StartLine, StartCol, 'commentaire non termine (' + W +
            ' attendu)');
End;

Function CommentWord(Const W : TName) : Boolean;
Begin
  CommentWord := (W = 'CO') Or (W = 'COMMENT') Or (W = 'PR') Or
                 (W = 'PRAGMAT');
End;

{ Un token brut ; les commentaires et pragmats sont ignores }
Procedure LexScanToken(Var T : TToken);
Var
  Done : Boolean;
  C    : Char;
Begin
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
    If LexAtEnd Then
      T.Kind := TK_EOF
    Else If IsLetter(C) Then
    Begin
      LexScanWord(T);
      If (T.Kind = TK_BOLD) And CommentWord(T.Val) Then
      Begin
        LexSkipWord(T.Val, T.Line, T.Col);
        Done := False;
      End;
    End
    Else If IsDigit(C) Or ((C = '.') And IsDigit(LexAt(1))) Then
      LexScanNumber(T)
    Else If C = '"' Then
      LexScanString(T)
    Else If C = '#' Then
    Begin
      LexNextChar;
      LexSkipHash(T.Line, T.Col);
      Done := False;
    End
    Else
    Begin
      T.Kind := TK_OP;
      T.Val  := C;
      Case C Of
        '+', '-':
          Begin
            LexNextChar;
            If (LexCur = ':') And (LexAt(1) = '=') Then
            Begin
              T.Val := T.Val + ':=';           { +:= et -:= }
              LexNextChar;
              LexNextChar;
            End
            Else If (C = '+') And (LexCur = '*') Then
            Begin
              T.Val := '+*';
              LexNextChar;
            End;
          End;
        '*':
          Begin
            LexNextChar;
            If (LexCur = ':') And (LexAt(1) = '=') Then
            Begin
              T.Val := '*:=';
              LexNextChar;
              LexNextChar;
            End
            Else If LexCur = '*' Then
            Begin
              T.Val := '**';
              LexNextChar;
            End;
          End;
        '/':
          Begin
            LexNextChar;
            If (LexCur = ':') And (LexAt(1) = '=') Then
            Begin
              T.Val := '/:=';
              LexNextChar;
              LexNextChar;
            End
            Else If LexCur = '=' Then
            Begin
              T.Val := '/=';
              LexNextChar;
            End;
          End;
        '%':
          Begin
            LexNextChar;
            If (LexCur = ':') And (LexAt(1) = '=') Then
            Begin
              T.Val := '%:=';
              LexNextChar;
              LexNextChar;
            End
            Else If (LexCur = '*') And (LexAt(1) = ':') And
                    (LexAt(2) = '=') Then
            Begin
              T.Val := '%*:=';
              LexNextChar;
              LexNextChar;
              LexNextChar;
            End
            Else If LexCur = '*' Then
            Begin
              T.Val := '%*';
              LexNextChar;
            End;
          End;
        '=':
          Begin
            LexNextChar;
            If LexCur = ':' Then
            Begin
              T.Val := '=:';                   { affectation inversee }
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
        '&':
          Begin
            T.Kind := TK_BOLD;                 { & equivaut a AND }
            T.Val  := 'AND';
            LexNextChar;
          End;
        '~':
          Begin
            T.Kind := TK_BOLD;                 { ~ equivaut a NOT }
            T.Val  := 'NOT';
            LexNextChar;
          End;
        ':':
          Begin
            LexNextChar;
            If LexCur = '=' Then
            Begin
              LexNextChar;
              If LexCur = ':' Then
              Begin
                T.Kind := TK_KEYWORD;          { :=: equivaut a IS }
                T.Val  := 'IS';
                LexNextChar;
              End
              Else
                T.Val := ':=';
            End
            Else If (LexCur = '/') And (LexAt(1) = '=') And
                    (LexAt(2) = ':') Then
            Begin
              T.Kind := TK_KEYWORD;            { :/=: equivaut a ISNT }
              T.Val  := 'ISNT';
              LexNextChar;
              LexNextChar;
              LexNextChar;
            End
            Else
              T.Kind := TK_PUNCT;
          End;
        '|':
          Begin
            T.Kind := TK_PUNCT;
            LexNextChar;
            If LexCur = ':' Then
            Begin
              T.Val := '|:';
              LexNextChar;
            End;
          End;
        ';', ',', '(', ')', '[', ']':
          Begin
            T.Kind := TK_PUNCT;
            LexNextChar;
          End;
      Else
        Begin
          If (C < ' ') Or (C > '~') Then
            ErrorAt(T.Line, T.Col,
                    'caractere invalide: code ' + ItoS(Ord(C)))
          Else
            ErrorAt(T.Line, T.Col, 'caractere invalide: ' + C);
          LexNextChar;
          Done := False;
        End;
      End;
    End;
  Until Done;
End;

{ Mode debug -d : une ligne par token }
Procedure PrintToken(Const T : TToken);
Begin
  Write(T.Line:5, ':', T.Col:3, ' ', TokenKindName(T.Kind):8);
  Case T.Kind Of
    TK_INT, TK_BOOL : WriteLn(' ', T.IntVal);
    TK_REAL         : WriteLn(' ', T.RealVal:0:6, '  (', T.Val, ')');
    TK_CHAR         : WriteLn(' "', T.Val, '"');
    TK_STRING       : WriteLn(' "', LitTab[T.IntVal], '"');
    TK_EOF          : WriteLn;
  Else
    WriteLn(' ', T.Val);
  End;
End;

{ Range le token dans TokTab ; GO suivi de TO devient GOTO }
Procedure LexStore(Var T : TToken);
Begin
  If (T.Kind = TK_KEYWORD) And (T.Val = 'TO') And (TokCount > 0) And
     (TokTab[TokCount - 1].Kind = TK_BOLD) And
     (TokTab[TokCount - 1].Val = 'GO') Then
  Begin
    TokTab[TokCount - 1].Kind := TK_KEYWORD;
    TokTab[TokCount - 1].Val  := 'GOTO';
    Exit;
  End;
  If TokCount >= MAX_TOKEN Then
    FatalError('trop de tokens (max ' + ItoS(MAX_TOKEN) + ')');
  TokTab[TokCount] := T;
  Inc(TokCount);
End;

Procedure PhaseLex;
Var
  T : TToken;
Begin
  LexLoad;
  TokCount := 0;
  LitCount := 0;
  Repeat
    LexScanToken(T);
    If Opts.DebugMode Then PrintToken(T);
    LexStore(T);
  Until T.Kind = TK_EOF;
  If Opts.Verbose Then
  Begin
    If (LexCol = 1) And (LexLine > 1) Then Dec(LexLine);
    WriteLn('  ', Opts.SrcFile, ': ', LexLine, ' ligne(s), ',
            TokCount - 1, ' token(s)');
  End;
End;

{ ============================================================
  SECTION 7 - MODES (TODO 04)
  ============================================================ }
Const
  { indices fixes des modes de base }
  MD_ERROR  = 0;
  MD_VOID   = 1;
  MD_INT    = 2;
  MD_REAL   = 3;
  MD_BOOL   = 4;
  MD_CHAR   = 5;
  MD_BITS   = 6;
  MD_NIL    = 7;
  MD_STRING = 8;     { FLEX [] CHAR }

  { dimensions d un descripteur de tableau : pointeur + (borne
    inferieure, borne superieure, pas) par dimension }
  ROW_DESC_BASE = 4;
  ROW_DESC_DIM  = 12;

Var
  ModeTab   : Array[0..MAX_MODE - 1] Of TMode;
  ModeCount : Integer;
  ModePoolM : Array[0..MAX_MODEPOOL - 1] Of Integer;
  ModePoolN : Array[0..MAX_MODEPOOL - 1] Of TName;
  ModePoolCount : Integer;
  { liste en cours de construction (champs, parametres, alternatives) }
  ModeTmpN  : Integer;
  ModeTmpM  : Array[0..MAX_FIELD - 1] Of Integer;
  ModeTmpS  : Array[0..MAX_FIELD - 1] Of TName;
  ModeBadRec: Boolean;   { une taille a rencontre un mode recursif }

Function ModeNewRaw(K : TModeKind) : Integer;
Begin
  If ModeCount >= MAX_MODE Then
    FatalError('trop de modes (max ' + ItoS(MAX_MODE) + ')');
  ModeTab[ModeCount].Kind  := K;
  ModeTab[ModeCount].Sub   := 0;
  ModeTab[ModeCount].Dims  := 0;
  ModeTab[ModeCount].Flex  := False;
  ModeTab[ModeCount].First := 0;
  ModeTab[ModeCount].Count := 0;
  ModeTab[ModeCount].Size  := -1;
  ModeTab[ModeCount].Name  := '';
  ModeNewRaw := ModeCount;
  Inc(ModeCount);
End;

{ Suit les modes nommes en cours de definition jusqu au mode reel }
Function ModeResolve(M : Integer) : Integer;
Var
  N : Integer;
Begin
  N := 0;
  While (M >= 0) And (M < ModeCount) And (ModeTab[M].Kind = MK_FWD) And
        (ModeTab[M].Sub <> 0) And (N < 64) Do
  Begin
    M := ModeTab[M].Sub;
    Inc(N);
  End;
  ModeResolve := M;
End;

Function ModeKind(M : Integer) : TModeKind;
Begin
  ModeKind := ModeTab[ModeResolve(M)].Kind;
End;

Procedure ModeInit;
Var
  I : Integer;
Begin
  ModeCount := 0;
  ModePoolCount := 0;
  ModeTmpN := 0;
  ModeBadRec := False;
  For I := 0 To 7 Do
    ModeNewRaw(TModeKind(I));        { MK_ERROR a MK_NIL, dans l ordre }
  I := ModeNewRaw(MK_ROW);           { MD_STRING }
  ModeTab[I].Sub  := MD_CHAR;
  ModeTab[I].Dims := 1;
  ModeTab[I].Flex := True;
End;

Function ModeRef(M : Integer) : Integer;
Var
  I : Integer;
Begin
  For I := 0 To ModeCount - 1 Do
    If (ModeTab[I].Kind = MK_REF) And (ModeTab[I].Sub = M) Then
    Begin
      ModeRef := I;
      Exit;
    End;
  I := ModeNewRaw(MK_REF);
  ModeTab[I].Sub := M;
  ModeRef := I;
End;

Function ModeRow(M, Dims : Integer; Flex : Boolean) : Integer;
Var
  I : Integer;
Begin
  For I := 0 To ModeCount - 1 Do
    If (ModeTab[I].Kind = MK_ROW) And (ModeTab[I].Sub = M) And
       (ModeTab[I].Dims = Dims) And (ModeTab[I].Flex = Flex) Then
    Begin
      ModeRow := I;
      Exit;
    End;
  I := ModeNewRaw(MK_ROW);
  ModeTab[I].Sub  := M;
  ModeTab[I].Dims := Dims;
  ModeTab[I].Flex := Flex;
  ModeRow := I;
End;

{ Mode nomme dont la definition suit (MODE NODE = STRUCT(... REF NODE)) }
Function ModeFwd(Const Name : TName) : Integer;
Var
  I : Integer;
Begin
  I := ModeNewRaw(MK_FWD);
  ModeTab[I].Name := Name;
  ModeFwd := I;
End;

Procedure ModeDefine(Fwd, Target : Integer);
Begin
  If (Fwd > 0) And (ModeTab[Fwd].Kind = MK_FWD) And
     (ModeResolve(Target) <> Fwd) Then
    ModeTab[Fwd].Sub := Target;
End;

{ ---- construction des modes a liste ---- }
Procedure ModeTmpReset;
Begin
  ModeTmpN := 0;
End;

Procedure ModeTmpAdd(Const Name : TName; M, Line, Col : Integer);
Begin
  If ModeTmpN >= MAX_FIELD Then
  Begin
    ErrorAt(Line, Col, 'trop d''elements dans un mode (max ' +
            ItoS(MAX_FIELD) + ')');
    Exit;
  End;
  ModeTmpM[ModeTmpN] := M;
  ModeTmpS[ModeTmpN] := Name;
  Inc(ModeTmpN);
End;

Procedure ModePoolAdd(Const Name : TName; M : Integer);
Begin
  If ModePoolCount >= MAX_MODEPOOL Then
    FatalError('trop de champs de modes (max ' + ItoS(MAX_MODEPOOL) +
               ')');
  ModePoolM[ModePoolCount] := M;
  ModePoolN[ModePoolCount] := Name;
  Inc(ModePoolCount);
End;

{ Les listes de ModeTab[I] et de la liste en cours sont-elles les
  memes, element par element (indices et noms) ? }
Function ModeSameList(I : Integer; UseNames : Boolean) : Boolean;
Var
  K : Integer;
Begin
  ModeSameList := False;
  If ModeTab[I].Count <> ModeTmpN Then Exit;
  For K := 0 To ModeTmpN - 1 Do
  Begin
    If ModePoolM[ModeTab[I].First + K] <> ModeTmpM[K] Then Exit;
    If UseNames And
       (ModePoolN[ModeTab[I].First + K] <> ModeTmpS[K]) Then Exit;
  End;
  ModeSameList := True;
End;

Procedure ModeFillFromTmp(I : Integer);
Var
  K : Integer;
Begin
  ModeTab[I].First := ModePoolCount;
  ModeTab[I].Count := ModeTmpN;
  For K := 0 To ModeTmpN - 1 Do
    ModePoolAdd(ModeTmpS[K], ModeTmpM[K]);
End;

{ STRUCT(champs de la liste en cours) ; noms de champs distincts }
Function ModeStructTmp(Line, Col : Integer) : Integer;
Var
  I, J, K : Integer;
Begin
  For J := 0 To ModeTmpN - 1 Do
    For K := 0 To J - 1 Do
      If ModeTmpS[J] = ModeTmpS[K] Then
        ErrorAt(Line, Col, 'champ en double: ' + ModeTmpS[J]);
  For I := 0 To ModeCount - 1 Do
    If (ModeTab[I].Kind = MK_STRUCT) And ModeSameList(I, True) Then
    Begin
      ModeStructTmp := I;
      ModeTmpN := 0;
      Exit;
    End;
  I := ModeNewRaw(MK_STRUCT);
  ModeFillFromTmp(I);
  ModeTmpN := 0;
  ModeStructTmp := I;
End;

{ PROC(parametres de la liste en cours) Result }
Function ModeProcTmp(Result : Integer) : Integer;
Var
  I : Integer;
Begin
  For I := 0 To ModeCount - 1 Do
    If (ModeTab[I].Kind = MK_PROC) And (ModeTab[I].Sub = Result) And
       ModeSameList(I, False) Then
    Begin
      ModeProcTmp := I;
      ModeTmpN := 0;
      Exit;
    End;
  I := ModeNewRaw(MK_PROC);
  ModeTab[I].Sub := Result;
  ModeFillFromTmp(I);
  ModeTmpN := 0;
  ModeProcTmp := I;
End;

Function ModeSame(A, B : Integer) : Boolean; Forward;

{ UNION(alternatives) : unions imbriquees aplaties, doublons retires,
  alternatives triees par indice (l ordre n a pas d importance) }
Function ModeUnionTmp(Line, Col : Integer) : Integer;
Var
  Alts  : Array[0..MAX_ALT - 1] Of Integer;
  N     : Integer;
  I, J, K, T, M, R : Integer;
  Dup   : Boolean;

  Procedure AddAlt(X : Integer);
  Var
    D : Integer;
  Begin
    Dup := False;
    For D := 0 To N - 1 Do
      If ModeSame(Alts[D], X) Then Dup := True;
    If Not Dup Then
    Begin
      If N >= MAX_ALT Then
        ErrorAt(Line, Col, 'trop d''alternatives dans une UNION (max ' +
                ItoS(MAX_ALT) + ')')
      Else
      Begin
        Alts[N] := X;
        Inc(N);
      End;
    End;
  End;

Begin
  N := 0;
  For I := 0 To ModeTmpN - 1 Do
  Begin
    M := ModeResolve(ModeTmpM[I]);
    If ModeTab[M].Kind = MK_VOID Then
      ErrorAt(Line, Col, 'VOID ne peut pas etre une alternative d''UNION')
    Else If ModeTab[M].Kind = MK_UNION Then
    Begin
      For K := 0 To ModeTab[M].Count - 1 Do
        AddAlt(ModePoolM[ModeTab[M].First + K]);
    End
    Else
      AddAlt(M);
  End;
  For J := 1 To N - 1 Do                 { tri par insertion }
  Begin
    T := Alts[J];
    K := J - 1;
    While (K >= 0) And (Alts[K] > T) Do
    Begin
      Alts[K + 1] := Alts[K];
      Dec(K);
    End;
    Alts[K + 1] := T;
  End;
  ModeTmpN := 0;
  For I := 0 To N - 1 Do
    ModeTmpAdd('', Alts[I], Line, Col);
  R := -1;
  For I := 0 To ModeCount - 1 Do
    If (R < 0) And (ModeTab[I].Kind = MK_UNION) And
       ModeSameList(I, False) Then
      R := I;
  If R < 0 Then
  Begin
    R := ModeNewRaw(MK_UNION);
    ModeFillFromTmp(R);
  End;
  ModeTmpN := 0;
  ModeUnionTmp := R;
End;

{ ---- equivalence structurelle (recursion comprise) ---- }
Var
  EqA, EqB : Array[0..31] Of Integer;
  EqN      : Integer;

Function ModeSame(A, B : Integer) : Boolean;
Var
  K     : Integer;
  Same  : Boolean;
Begin
  A := ModeResolve(A);
  B := ModeResolve(B);
  If A = B Then
  Begin
    ModeSame := True;
    Exit;
  End;
  ModeSame := False;
  If ModeTab[A].Kind <> ModeTab[B].Kind Then Exit;
  { paire deja en cours de comparaison : supposee equivalente }
  For K := 0 To EqN - 1 Do
    If (EqA[K] = A) And (EqB[K] = B) Then
    Begin
      ModeSame := True;
      Exit;
    End;
  If EqN >= 32 Then Exit;
  EqA[EqN] := A;
  EqB[EqN] := B;
  Inc(EqN);
  Same := False;
  Case ModeTab[A].Kind Of
    MK_REF:
      Same := ModeSame(ModeTab[A].Sub, ModeTab[B].Sub);
    MK_ROW:
      Same := (ModeTab[A].Dims = ModeTab[B].Dims) And
              (ModeTab[A].Flex = ModeTab[B].Flex) And
              ModeSame(ModeTab[A].Sub, ModeTab[B].Sub);
    MK_PROC, MK_STRUCT, MK_UNION:
      Begin
        Same := (ModeTab[A].Count = ModeTab[B].Count);
        If Same And (ModeTab[A].Kind = MK_PROC) Then
          Same := ModeSame(ModeTab[A].Sub, ModeTab[B].Sub);
        K := 0;
        While Same And (K < ModeTab[A].Count) Do
        Begin
          If ModeTab[A].Kind = MK_STRUCT Then
            Same := ModePoolN[ModeTab[A].First + K] =
                    ModePoolN[ModeTab[B].First + K];
          If Same Then
            Same := ModeSame(ModePoolM[ModeTab[A].First + K],
                             ModePoolM[ModeTab[B].First + K]);
          Inc(K);
        End;
      End;
  End;
  Dec(EqN);
  ModeSame := Same;
End;

{ ---- predicats et acces ---- }
Function ModeIsRef(M : Integer) : Boolean;
Begin
  ModeIsRef := ModeKind(M) = MK_REF;
End;

{ mode apres retrait d un niveau de REF (le mode lui-meme sinon) }
Function ModeDeref1(M : Integer) : Integer;
Begin
  M := ModeResolve(M);
  If ModeTab[M].Kind = MK_REF Then
    ModeDeref1 := ModeResolve(ModeTab[M].Sub)
  Else
    ModeDeref1 := M;
End;

{ mode apres retrait de tous les REF }
Function ModeDeref(M : Integer) : Integer;
Begin
  M := ModeResolve(M);
  While ModeTab[M].Kind = MK_REF Do
    M := ModeResolve(ModeTab[M].Sub);
  ModeDeref := M;
End;

Function ModeIsNumeric(M : Integer) : Boolean;
Begin
  M := ModeResolve(M);
  ModeIsNumeric := ModeTab[M].Kind In [MK_INT, MK_REAL];
End;

Function ModeIsString(M : Integer) : Boolean;
Begin
  ModeIsString := ModeSame(M, MD_STRING);
End;

Function ModeFieldCount(M : Integer) : Integer;
Begin
  ModeFieldCount := ModeTab[ModeResolve(M)].Count;
End;

Function ModeFieldName(M, I : Integer) : TName;
Begin
  M := ModeResolve(M);
  ModeFieldName := ModePoolN[ModeTab[M].First + I];
End;

Function ModeFieldMode(M, I : Integer) : Integer;
Begin
  M := ModeResolve(M);
  ModeFieldMode := ModePoolM[ModeTab[M].First + I];
End;

{ indice du champ de ce nom dans une structure ; -1 si absent }
Function ModeFindField(M : Integer; Const Name : TName) : Integer;
Var
  I : Integer;
Begin
  ModeFindField := -1;
  M := ModeResolve(M);
  If ModeTab[M].Kind <> MK_STRUCT Then Exit;
  For I := 0 To ModeTab[M].Count - 1 Do
    If ModePoolN[ModeTab[M].First + I] = Name Then
      ModeFindField := I;
End;

{ le mode M est-il une alternative de l union U ? }
Function ModeUnionHas(U, M : Integer) : Boolean;
Var
  I : Integer;
Begin
  ModeUnionHas := False;
  U := ModeResolve(U);
  If ModeTab[U].Kind <> MK_UNION Then Exit;
  For I := 0 To ModeTab[U].Count - 1 Do
    If ModeSame(ModePoolM[ModeTab[U].First + I], M) Then
      ModeUnionHas := True;
End;

{ ---- representation en memoire ---- }
Function ModeSize(M : Integer) : LongInt;
Var
  K     : Integer;
  Total : LongInt;
  Max   : LongInt;
  S     : LongInt;
Begin
  M := ModeResolve(M);
  If ModeTab[M].Size = -2 Then
  Begin
    ModeBadRec := True;              { recursion sans REF }
    ModeSize := 0;
    Exit;
  End;
  If ModeTab[M].Size >= 0 Then
  Begin
    ModeSize := ModeTab[M].Size;
    Exit;
  End;
  ModeTab[M].Size := -2;
  Total := 0;
  Case ModeTab[M].Kind Of
    MK_ERROR, MK_FWD : Total := 4;
    MK_VOID          : Total := 0;
    MK_INT, MK_BOOL, MK_CHAR, MK_BITS, MK_NIL, MK_REF : Total := 4;
    MK_REAL          : Total := 8;
    MK_PROC          : Total := 8;       { entree + lien statique }
    MK_ROW           : Total := ROW_DESC_BASE +
                                ROW_DESC_DIM * ModeTab[M].Dims;
    MK_STRUCT:
      For K := 0 To ModeTab[M].Count - 1 Do
        Total := Total + ModeSize(ModePoolM[ModeTab[M].First + K]);
    MK_UNION:
      Begin
        Max := 0;
        For K := 0 To ModeTab[M].Count - 1 Do
        Begin
          S := ModeSize(ModePoolM[ModeTab[M].First + K]);
          If S > Max Then Max := S;
        End;
        Total := 4 + Max;                { etiquette + valeur }
      End;
  End;
  ModeTab[M].Size := Total;
  ModeSize := Total;
End;

{ decalage d un champ dans une structure }
Function ModeFieldOffset(M, I : Integer) : LongInt;
Var
  K   : Integer;
  Off : LongInt;
Begin
  M := ModeResolve(M);
  Off := 0;
  For K := 0 To I - 1 Do
    Off := Off + ModeSize(ModePoolM[ModeTab[M].First + K]);
  ModeFieldOffset := Off;
End;

{ taille d un element de tableau : 1 octet pour un CHAR }
Function ModeElemSize(Row : Integer) : LongInt;
Var
  E : Integer;
Begin
  E := ModeResolve(ModeTab[ModeResolve(Row)].Sub);
  If ModeTab[E].Kind = MK_CHAR Then
    ModeElemSize := 1
  Else
    ModeElemSize := ModeSize(E);
End;

{ ---- noms des modes (messages d erreur et mode -d) ---- }
Function ModeName(M : Integer) : TString;
Var
  S : TString;
  K : Integer;
Begin
  If (M < 0) Or (M >= ModeCount) Then
  Begin
    ModeName := '?';
    Exit;
  End;
  S := '';
  Case ModeTab[M].Kind Of
    MK_ERROR : S := '<erreur>';
    MK_VOID  : S := 'VOID';
    MK_INT   : S := 'INT';
    MK_REAL  : S := 'REAL';
    MK_BOOL  : S := 'BOOL';
    MK_CHAR  : S := 'CHAR';
    MK_BITS  : S := 'BITS';
    MK_NIL   : S := 'NIL';
    MK_FWD   : S := ModeTab[M].Name;
    MK_REF   : S := 'REF ' + ModeName(ModeTab[M].Sub);
    MK_ROW:
      Begin
        If M = MD_STRING Then
          S := 'STRING'
        Else
        Begin
          If ModeTab[M].Flex Then S := 'FLEX ';
          S := S + '[';
          For K := 2 To ModeTab[M].Dims Do
            S := S + ',';
          S := S + ']' + ModeName(ModeTab[M].Sub);
        End;
      End;
    MK_STRUCT:
      Begin
        S := 'STRUCT(';
        For K := 0 To ModeTab[M].Count - 1 Do
        Begin
          If K > 0 Then S := S + ', ';
          S := S + ModeName(ModePoolM[ModeTab[M].First + K]) + ' ' +
               ModePoolN[ModeTab[M].First + K];
        End;
        S := S + ')';
      End;
    MK_UNION:
      Begin
        S := 'UNION(';
        For K := 0 To ModeTab[M].Count - 1 Do
        Begin
          If K > 0 Then S := S + ', ';
          S := S + ModeName(ModePoolM[ModeTab[M].First + K]);
        End;
        S := S + ')';
      End;
    MK_PROC:
      Begin
        S := 'PROC';
        If ModeTab[M].Count > 0 Then
        Begin
          S := S + '(';
          For K := 0 To ModeTab[M].Count - 1 Do
          Begin
            If K > 0 Then S := S + ', ';
            S := S + ModeName(ModePoolM[ModeTab[M].First + K]);
          End;
          S := S + ')';
        End;
        S := S + ' ' + ModeName(ModeTab[M].Sub);
      End;
  End;
  ModeName := S;
End;

{ Mode debug -d : liste des modes }
Procedure ModeDump;
Var
  I : Integer;
Begin
  WriteLn('Modes (', ModeCount, ') :');
  For I := 0 To ModeCount - 1 Do
  Begin
    Write(I:4, '  ', ModeName(I));
    If ModeTab[I].Kind <> MK_FWD Then
      Write('  ', ModeSize(I), ' octets');
    WriteLn;
  End;
End;

{ ============================================================
  SECTION 8 - TABLE DES SYMBOLES ET PORTEES (TODO 05)
  ============================================================ }

{ ============================================================
  SECTION 9 - ARBRE D UNITES ET PARSEUR (TODO 07, 08, 10)
  ============================================================ }
Procedure PhaseParse;
Begin
  { A faire : TODO 07, 08 et 10 }
End;

{ ============================================================
  SECTION 10 - COERCITIONS ET RESOLUTION DES MODES (TODO 09)
  ============================================================ }
Procedure PhaseModes;
Begin
  { A faire : TODO 09 et 11 a 19 }
End;

{ ============================================================
  SECTION 11 - GENERATEUR, CODE INTERNE ET LISTING ASM (TODO 06)
  ============================================================ }
Procedure PhaseCodegen;
Begin
  { A faire : TODO 06 et 11 a 19 }
End;

{ ============================================================
  SECTION 12 - ENCODEUR BINAIRE x86-32 (TODO 20)
  ============================================================ }
Procedure PhaseEncode;
Begin
  { A faire : TODO 20 }
End;

{ ============================================================
  SECTION 13 - ECRIVAINS PE (.EXE) ET COFF (.OBJ) (TODO 21)
  ============================================================ }
Procedure PhaseWrite;
Begin
  { A faire : TODO 21 }
End;

{ ============================================================
  SECTION 14 - RUNTIME ALGOL 68 POUR WIN32 (TODO 22)
  ============================================================ }

{ ============================================================
  SECTION 15 - ERREURS ET RAPPORT FINAL (TODO 23, 24)
  ============================================================ }
Procedure PhaseReport;
Begin
  { A faire : TODO 23 et 24 }
End;

{ ============================================================
  SECTION 16 - PIPELINE PRINCIPAL (TODO 01, 24)
  ============================================================ }
Procedure RunPhase(P : TPhase);
Begin
  If Opts.Verbose Then
    WriteLn('AL68CW32: ', PhaseName(P));
  Case P Of
    PH_LEX     : PhaseLex;
    PH_PARSE   : PhaseParse;
    PH_MODES   : PhaseModes;
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
  OutCreatedN := 0;
  ModeInit;
  If Opts.DebugMode Then ModeDump;
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
  { les phases suivant le parseur ne tournent que sans erreur : aucun
    fichier de sortie n'est ecrit sinon }
  For P := PH_LEX To PH_REPORT Do
    If (ErrorCount = 0) Or (P = PH_LEX) Or (P = PH_PARSE) Or
       (P = PH_REPORT) Then
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
