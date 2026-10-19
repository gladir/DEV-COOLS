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

  ETAT : TODO 01 a 07 implementes (squelette en sections, pipeline en 7
         phases, options, constantes, limites et nommage, lexeur, modes,
         symboles et prelude, code interne et listing, parseur de
         clauses) ; TODO 08 a 25 a faire.

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

  TODO 05 - TABLE DES SYMBOLES, PORTEES ET PRELUDE STANDARD [IMPLEMENTE]
            Portees emboitees (clauses fermees, series, boucles,
              procedures) ; recherche du plus interne vers l'externe
            Espaces de noms : identites et variables, modes, operateurs
              (avec modes des operandes), priorites, labels
            Entree : nom, genre, mode, portee, niveau d'imbrication,
              classe de stockage (statique, local, parametre), decalage
              ou nom ASM
            Doublon dans une meme portee signale ; masquage dans une
              portee interne permis
            Prelude standard : pi, newline, space, print, read, whole,
              sqrt, sin, cos, tan, arctan, exp, ln, ABS, SIGN, ODD, LWB,
              UPB, BIN, SHL, SHR, ENTIER, ROUND, operateurs
              arithmetiques, de comparaison, booleens et de chaines avec
              leurs priorites (1 a 9)
            Resolution des operateurs surcharges par les modes des
              operandes (preparer TODO 11 et TODO 17)
            Mode debug -d : afficher chaque portee
            Verification : test_closed.a68, test_decl.a68
            Realise : section 8 ; TSymbol (nom, genre, mode, portee, chaine
              des symboles de la portee, stockage, decalage, nom ASM,
              position, utilise, intrinseque, generique) et TScope
              (parent, niveau de procedures, genre, cadre) ; genres
              SK_VAR, SK_IDENT, SK_PROC, SK_PARAM, SK_STD, SK_MODE, SK_OP,
              SK_PRIO et SK_LABEL en cinq espaces de noms (identificateurs,
              modes, operateurs, priorites, etiquettes) ; ScopeEnter et
              ScopeLeave ; SymDeclare (doublon signale, la premiere
              declaration reste en vigueur ; operateurs distingues par les
              modes de leurs operandes) ; SymAllocate (segment de donnees au
              niveau 0, sinon [EBP - Offset] dans le cadre de la procedure
              englobante) ; SymFindIdent, SymFindMode, SymFindLabel,
              SymFindPrio, SymFindOp (modes exacts, portee la plus interne
              d'abord, LWB et UPB generiques sur tout tableau) et
              SymOpExists ; PreludeInit : priorites standard (OR 2, AND 3,
              = et /= 4, comparaisons 5, + et - 6, * / OVER MOD 7, ** SHL
              SHR LWB UPB 8, +* 9, affectations composees 1), 127
              operateurs (combinaisons INT et REAL explicites, chaines,
              BOOL, BITS, affectations composees, monadiques) et les
              identificateurs standard ; SymDumpScope pour -d
            Verifie : harnais de 40 controles hors depot (prelude, priorites,
              INT + REAL, INT / INT donne REAL, BOOL + INT refuse, UPB
              generique, +:= sur REF INT, doublons, espaces de noms
              distincts, surcharge et doublon d'un operateur utilisateur,
              PRIO utilisateur, masquage et redefinition d'un operateur du
              prelude, retour apres sortie de portee, cadre local et
              decalages dans une procedure) : tous reussis

  TODO 06 - CODE INTERNE, LISTING .ASM ET SEGMENT DE DONNEES [IMPLEMENTE]
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
            Realise : section 9, reprise de celle d'AL60CW32 ; TReg, TOperand
              (registre, immediat, memoire [symbole + base + index*echelle +
              deplacement], etiquette, OFFSET, ST(i)), TOp (MOV, MOVZX, LEA,
              PUSH, POP, arithmetique, SETcc, Jcc, CALL, RET, REP STOSD,
              REP MOVSD pour copier les structures, instructions x87) et
              TInstr ; CodeTab / DeferTab, MoveToDeferred ; noms ASM uniques
              (Intern, table de hachage) ; OpReg, OpImm, OpMem, OpMemSym,
              OpMemIdx, OpLabel, OpOffset, OpST ; Emit, Emit0, Emit1,
              EmitLabel, EmitComment, EmitBlank, NewLabel ; WriteListing
              (.386, .MODEL FLAT, EXTERN des fonctions kernel32, .DATA,
              .CODE, END _A68P_Main) ; DataNew, DataAddZero, DataStr,
              DataInt, DataReal (cellules partagees), DataTable ; DataDump ;
              GenMainBegin (_A68P_Main, cadre memorise dans _A68_MAINBP) et
              GenMainEnd (ExitProcess(0)), appeles par le parseur en
              attendant le TODO 07 ; PhaseCodegen : statistiques (-v),
              code interne et donnees (-d), listing .ASM (-asm) ; les
              sections 9 a 11 sont reordonnees pour que le code interne
              precede le parseur ; descripteurs de modes : pas necessaires
              (l'etiquette d'une union est l'indice du mode)
            Verifie : un programme vide compile avec -asm, s'assemble avec
              ML et s'execute (code 0) ; un programme construit a la main
              avec chaine, entier, reel, table d'adresses, saut indexe,
              appel d'une procedure differee et x87 s'assemble avec ML et
              s'execute : il ecrit Salut A68 et rend le code 49

  TODO 07 - PARSEUR : PROGRAMME, CLAUSES SERIES ET FERMEES [IMPLEMENTE]
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
            Realise : section 10 ; arbre d'unites (TUnit : genre, mode,
              position, enfants A B C, element suivant, symbole, portee) ;
              genres UK_SERIAL, UK_CLOSED, UK_LABELDEF, UK_GOTO, UK_SKIP,
              UK_DECL et UK_OPAQUE ; jetons lus dans TokTab (TokAt,
              ParserAdvance, AtKw, AtPunct) ; ParseSerial (au niveau le plus
              externe seule la fin du fichier ferme la clause) ;
              ParseClosed (BEGIN ... END et parentheses, une portee par
              clause, fermeture manquante signalee avec la ligne et la
              colonne de l'ouverture) ; ParenIsClosed distingue une clause
              fermee de (c | a | b) et des listes a virgules ; etiquettes
              devant une unite ou une declaration (ParseLabelDef, doublon
              signale) ; GOTO (ParseGoto) resolu en fin d'analyse
              (ResolveGotos : etiquette visible depuis la portee du saut
              ou une portee englobante, sinon erreur) ; avertissement
              d'etiquette inutilisee avec -w ; unites vides et point-
              virgule final tolerees ; recuperation : message puis saut
              jusqu'au prochain point-virgule ou a une fermeture, avec
              progression garantie ; en attendant les TODOs 08 a 19, les
              declarations (AtDeclStart) et les autres unites sont
              enveloppees sans analyse (ParseOpaque : jetons equilibres
              jusqu'au point-virgule, le DO d'une clause repetitive
              ouvrant son corps) ; PhaseCodegen genere maintenant le code
              depuis l'arbre (GenUnit : etiquettes et JMP) ; -d affiche
              l'arbre, -v les statistiques
            Verifie : les 27 exemples sont analyses sans erreur (de 6 unites
              pour test_dataseg a 39 pour math) ; test_closed donne deux
              clauses fermees, deux etiquettes et un GOTO resolu ; erreurs :
              GOTO vers une etiquette inconnue, etiquette dupliquee, END ou
              parenthese manquants, fermeture isolee, point-virgule oublie,
              GOTO sans etiquette ; un programme avec GOTO et etiquettes
              imbriquees s'assemble avec ML et s'execute (code 0)

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
  MAX_SCOPETAB  = {$IFDEF FPC}2048{$ELSE}64{$ENDIF};   { portees creees  }
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
  A68_MAINBP    = '_A68_MAINBP'; { cadre du programme principal        }

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

  { Table des symboles et portees (TODO 05) }
  TSymKind = (
    SK_VAR,        { variable : identite d un REF m (INT y := 10)    }
    SK_IDENT,      { identite constante (INT x = 42)                 }
    SK_PROC,       { procedure : identite d un PROC                  }
    SK_PARAM,      { parametre formel                                }
    SK_STD,        { identificateur du prelude standard              }
    SK_MODE,       { nom de mode (MODE POINT = ...)                  }
    SK_OP,         { operateur (OP), mode = PROC des operandes       }
    SK_PRIO,       { priorite d un operateur (PRIO), Offset = 1 a 9  }
    SK_LABEL       { etiquette                                       }
  );

  TStorage = (
    SC_NONE,
    SC_STATIC,     { segment de donnees (niveau 0)                   }
    SC_LOCAL,      { cadre de procedure, [EBP - Offset]              }
    SC_PARAM       { parametre, [EBP + Offset]                       }
  );

  TScopeKind = (
    SCK_PRELUDE,   { prelude standard                                }
    SCK_PROGRAM,   { programme                                       }
    SCK_CLOSED,    { clause fermee ou serie                          }
    SCK_LOOP,      { clause repetitive (variable de controle)        }
    SCK_CHOICE,    { branche d un IF ou d un CASE                    }
    SCK_PROC,      { corps de procedure ou d operateur               }
    SCK_CONFORM    { alternative d une clause de conformite          }
  );

  TSymbol = Record
    Name      : TName;
    Kind      : TSymKind;
    Mode      : Integer;       { mode du symbole (MD_...)             }
    Scope     : Integer;
    Prev      : Integer;       { symbole precedent de la meme portee  }
    Storage   : TStorage;
    Offset    : LongInt;       { decalage dans le cadre ou priorite   }
    AsmName   : TString;       { nom ASM du symbole                   }
    Line      : Integer;
    Col       : Integer;
    Used      : Boolean;
    Intrinsic : Boolean;       { realise en ligne par le generateur   }
    Generic   : Boolean;       { operande : tout tableau (LWB, UPB)   }
  End;

  TScope = Record
    Parent     : Integer;      { -1 pour le prelude                   }
    Level      : Integer;      { profondeur de procedures             }
    Kind       : TScopeKind;
    LastSym    : Integer;      { dernier symbole declare, -1 si aucun }
    FrameBytes : LongInt;      { octets locaux (portee de procedure)  }
    FrameScope : Integer;      { portee de procedure du cadre, -1 si
                                 les objets sont statiques            }
  End;

  { Arbre d unites (TODO 07) : une unite est un noeud ; les enfants
    sont designes par A, B, C ; les elements d une liste (clause serie,
    arguments) sont chaines par Next. Les indices sont des LongInt car
    Integer vaut 16 bits en mode TP. }
  TUnitKind = (
    UK_SERIAL,     { clause serie : A = premier element de la liste   }
    UK_CLOSED,     { clause fermee : A = clause serie, Scope          }
    UK_LABELDEF,   { definition d une etiquette : Sym                 }
    UK_GOTO,       { saut : Name, Scope, Sym apres resolution         }
    UK_SKIP,       { SKIP                                              }
    UK_DECL,       { declaration pas encore analysee (TODO 08)        }
    UK_OPAQUE      { unite pas encore analysee (TODOs 10 a 19)        }
  );

  TUnit = Record
    Kind    : TUnitKind;
    Mode    : Integer;     { mode de l unite (TODO 09)              }
    Line    : Integer;
    Col     : Integer;
    A, B, C : LongInt;     { enfants (-1 : aucun) ; UK_DECL et
                             UK_OPAQUE : jetons A a B - 1           }
    Next    : LongInt;     { element suivant d une liste            }
    Sym     : Integer;     { symbole associe, -1 si aucun           }
    Scope   : Integer;     { portee de la clause ou du saut         }
    Name    : TName;
    IntVal  : LongInt;
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
Var
  SymTab     : Array[0..MAX_SYM - 1] Of TSymbol;
  SymCount   : Integer;
  ScopeTab   : Array[0..MAX_SCOPETAB - 1] Of TScope;
  ScopeCount : Integer;
  ScopeCur   : Integer;      { portee courante                        }
  ScopeDepth : Integer;      { imbrication courante                   }

Function SymKindName(K : TSymKind) : TString;
Begin
  Case K Of
    SK_VAR   : SymKindName := 'var';
    SK_IDENT : SymKindName := 'identite';
    SK_PROC  : SymKindName := 'proc';
    SK_PARAM : SymKindName := 'param';
    SK_STD   : SymKindName := 'standard';
    SK_MODE  : SymKindName := 'mode';
    SK_OP    : SymKindName := 'op';
    SK_PRIO  : SymKindName := 'prio';
    SK_LABEL : SymKindName := 'etiquette';
  End;
End;

{ ---- portees ---- }
Function ScopeEnter(K : TScopeKind) : Integer;
Var
  S : Integer;
Begin
  If ScopeCount >= MAX_SCOPETAB Then
    FatalError('trop de portees (max ' + ItoS(MAX_SCOPETAB) + ')');
  If ScopeDepth >= MAX_SCOPE Then
    FatalError('imbrication trop profonde (max ' + ItoS(MAX_SCOPE) +
               ' portees)');
  S := ScopeCount;
  Inc(ScopeCount);
  ScopeTab[S].Parent  := ScopeCur;
  ScopeTab[S].Kind    := K;
  ScopeTab[S].LastSym := -1;
  ScopeTab[S].FrameBytes := 0;
  If ScopeCur < 0 Then
  Begin
    ScopeTab[S].Level      := 0;
    ScopeTab[S].FrameScope := -1;
  End
  Else
  Begin
    ScopeTab[S].Level      := ScopeTab[ScopeCur].Level;
    ScopeTab[S].FrameScope := ScopeTab[ScopeCur].FrameScope;
  End;
  If K = SCK_PROC Then
  Begin
    Inc(ScopeTab[S].Level);
    ScopeTab[S].FrameScope := S;       { nouveau cadre }
  End;
  ScopeCur := S;
  Inc(ScopeDepth);
  ScopeEnter := S;
End;

Procedure SymDumpScope(S : Integer);
Var
  Chain : Array[0..255] Of Integer;
  N, I, J : Integer;
Begin
  N := 0;
  I := ScopeTab[S].LastSym;
  While (I >= 0) And (N < 256) Do
  Begin
    Chain[N] := I;
    Inc(N);
    I := SymTab[I].Prev;
  End;
  WriteLn('Portee ', S, ' (niveau ', ScopeTab[S].Level, ', locales ',
          ScopeTab[S].FrameBytes, ' octets) :');
  For J := N - 1 Downto 0 Do
  Begin
    I := Chain[J];
    Write('  ', SymTab[I].Name, ' ', SymKindName(SymTab[I].Kind), ' ',
          ModeName(SymTab[I].Mode));
    Case SymTab[I].Storage Of
      SC_STATIC : Write(' global ', SymTab[I].AsmName);
      SC_LOCAL  : Write(' local -', SymTab[I].Offset);
      SC_PARAM  : Write(' param +', SymTab[I].Offset);
    End;
    WriteLn;
  End;
End;

Procedure ScopeLeave;
Begin
  If (ScopeCur >= 0) And (ScopeTab[ScopeCur].Kind <> SCK_PRELUDE) Then
  Begin
    If Opts.DebugMode Then SymDumpScope(ScopeCur);
    ScopeCur := ScopeTab[ScopeCur].Parent;
    Dec(ScopeDepth);
  End;
End;

{ ---- declaration ---- }
Function SymNewRaw(Const Name : TName; K : TSymKind; M : Integer) : Integer;
Var
  I : Integer;
Begin
  If SymCount >= MAX_SYM Then
    FatalError('trop de symboles (max ' + ItoS(MAX_SYM) + ')');
  I := SymCount;
  Inc(SymCount);
  SymTab[I].Name      := Name;
  SymTab[I].Kind      := K;
  SymTab[I].Mode      := M;
  SymTab[I].Scope     := ScopeCur;
  SymTab[I].Prev      := ScopeTab[ScopeCur].LastSym;
  SymTab[I].Storage   := SC_NONE;
  SymTab[I].Offset    := 0;
  SymTab[I].AsmName       := '';
  SymTab[I].Line      := 0;
  SymTab[I].Col       := 0;
  SymTab[I].Used      := False;
  SymTab[I].Intrinsic := False;
  SymTab[I].Generic   := False;
  ScopeTab[ScopeCur].LastSym := I;
  SymNewRaw := I;
End;

{ Nombre d operandes d un operateur (parametres de son mode PROC) }
Function OpArity(S : Integer) : Integer;
Begin
  OpArity := ModeTab[ModeResolve(SymTab[S].Mode)].Count;
End;

Function OpOperand(S, I : Integer) : Integer;
Var
  M : Integer;
Begin
  M := ModeResolve(SymTab[S].Mode);
  OpOperand := ModePoolM[ModeTab[M].First + I];
End;

Function OpResult(S : Integer) : Integer;
Begin
  OpResult := ModeTab[ModeResolve(SymTab[S].Mode)].Sub;
End;

{ Espace de noms : identificateurs (variables, identites, procedures,
  parametres, standard), modes, operateurs, priorites, etiquettes }
Function SymSameSpace(A, B : TSymKind) : Boolean;
Begin
  If A In [SK_VAR, SK_IDENT, SK_PROC, SK_PARAM, SK_STD] Then
    SymSameSpace := B In [SK_VAR, SK_IDENT, SK_PROC, SK_PARAM, SK_STD]
  Else
    SymSameSpace := A = B;
End;

Function SymAllocName(Const Name : TName; K : TSymKind; I : Integer)
         : TString;
Begin
  Case K Of
    SK_PROC : SymAllocName := A68_PROC_PFX + AsmIdent(Name) + '_' +
                              ItoS(I);
    SK_OP   : SymAllocName := MangleOp(Name, I);
    SK_LABEL: SymAllocName := A68_USR_PFX + AsmIdent(Name) + '_' +
                              ItoS(I);
  Else
    SymAllocName := A68_VAR_PFX + AsmIdent(Name) + '_' + ItoS(I);
  End;
End;

{ Declare un symbole dans la portee courante. Un doublon (meme nom, meme
  espace de noms, memes operandes pour un operateur) dans la meme portee
  est une erreur : la premiere declaration reste en vigueur et son indice
  est retourne, ce qui evite des erreurs en cascade. }
Function SymDeclare(Const Name : TName; K : TSymKind; M : Integer;
                    Line, Col : Integer) : Integer;
Var
  I, J  : Integer;
  Dup   : Integer;
  Same  : Boolean;
Begin
  I := ScopeTab[ScopeCur].LastSym;
  Dup := -1;
  While I >= 0 Do
  Begin
    If (SymTab[I].Name = Name) And SymSameSpace(SymTab[I].Kind, K) Then
    Begin
      If K = SK_OP Then
      Begin
        Same := ModeTab[ModeResolve(SymTab[I].Mode)].Count =
                ModeTab[ModeResolve(M)].Count;
        J := 0;
        While Same And (J < ModeTab[ModeResolve(M)].Count) Do
        Begin
          Same := ModeSame(OpOperand(I, J),
                           ModePoolM[ModeTab[ModeResolve(M)].First + J]);
          Inc(J);
        End;
        If Same Then Dup := I;
      End
      Else
        Dup := I;
    End;
    I := SymTab[I].Prev;
  End;
  If (Dup >= 0) And (ScopeTab[ScopeCur].Kind <> SCK_PRELUDE) Then
  Begin
    ErrorAt(Line, Col, 'declaration en double: ' + Name);
    SymDeclare := Dup;
    Exit;
  End;
  I := SymNewRaw(Name, K, M);
  SymTab[I].Line := Line;
  SymTab[I].Col  := Col;
  SymTab[I].AsmName := SymAllocName(Name, K, I);
  SymDeclare := I;
End;

{ Reserve la place de l objet d une variable ou d une identite : dans le
  segment de donnees au niveau 0, sinon dans le cadre de la procedure
  englobante ([EBP - Offset]) }
Procedure SymAllocate(S : Integer; Size : LongInt);
Var
  F : Integer;
Begin
  F := ScopeTab[SymTab[S].Scope].FrameScope;
  If F < 0 Then
    SymTab[S].Storage := SC_STATIC
  Else
  Begin
    ScopeTab[F].FrameBytes := ScopeTab[F].FrameBytes + ((Size + 3) And -4);
    SymTab[S].Storage := SC_LOCAL;
    SymTab[S].Offset  := ScopeTab[F].FrameBytes;
  End;
End;

{ ---- recherche (de la portee courante vers le prelude) ---- }
Function SymLookupKinds(Const Name : TName; K : TSymKind) : Integer;
Var
  S, I : Integer;
Begin
  SymLookupKinds := -1;
  S := ScopeCur;
  While S >= 0 Do
  Begin
    I := ScopeTab[S].LastSym;
    While I >= 0 Do
    Begin
      If (SymTab[I].Name = Name) And SymSameSpace(SymTab[I].Kind, K) Then
      Begin
        SymLookupKinds := I;
        Exit;
      End;
      I := SymTab[I].Prev;
    End;
    S := ScopeTab[S].Parent;
  End;
End;

{ identificateur (variable, identite, procedure, parametre, standard) }
Function SymFindIdent(Const Name : TName) : Integer;
Begin
  SymFindIdent := SymLookupKinds(Name, SK_VAR);
End;

Function SymFindMode(Const Name : TName) : Integer;
Begin
  SymFindMode := SymLookupKinds(Name, SK_MODE);
End;

Function SymFindLabel(Const Name : TName) : Integer;
Begin
  SymFindLabel := SymLookupKinds(Name, SK_LABEL);
End;

{ priorite d un operateur dyadique ; 0 si aucune PRIO n est visible }
Function SymFindPrio(Const Name : TName) : Integer;
Var
  I : Integer;
Begin
  I := SymLookupKinds(Name, SK_PRIO);
  If I < 0 Then
    SymFindPrio := 0
  Else
    SymFindPrio := SymTab[I].Offset;
End;

{ Un operande de mode M convient-il a l operande attendu (sans
  coercition) ? }
Function OpOperandFits(S, I, M : Integer) : Boolean;
Var
  E : Integer;
Begin
  E := OpOperand(S, I);
  If SymTab[S].Generic Then
    OpOperandFits := (ModeKind(E) <> MK_ROW) Or
                     (ModeKind(M) = MK_ROW)
  Else
    OpOperandFits := ModeSame(E, M);
End;

{ Operateur de ce nom dont les operandes ont exactement ces modes (B
  ignore si Arity = 1). Le plus interne l emporte. -1 si aucun. }
Function SymFindOp(Const Name : TName; Arity : Integer; A, B : Integer)
         : Integer;
Var
  S, I : Integer;
  Ok   : Boolean;
Begin
  SymFindOp := -1;
  S := ScopeCur;
  While S >= 0 Do
  Begin
    I := ScopeTab[S].LastSym;
    While I >= 0 Do
    Begin
      If (SymTab[I].Kind = SK_OP) And (SymTab[I].Name = Name) And
         (OpArity(I) = Arity) Then
      Begin
        Ok := OpOperandFits(I, 0, A);
        If Ok And (Arity = 2) Then Ok := OpOperandFits(I, 1, B);
        If Ok Then
        Begin
          SymFindOp := I;
          Exit;
        End;
      End;
      I := SymTab[I].Prev;
    End;
    S := ScopeTab[S].Parent;
  End;
End;

{ Y a-t-il un operateur de ce nom et de cette arite ? (pour distinguer
  "operateur inconnu" de "modes d operandes incorrects") }
Function SymOpExists(Const Name : TName; Arity : Integer) : Boolean;
Var
  S, I : Integer;
Begin
  SymOpExists := False;
  S := ScopeCur;
  While S >= 0 Do
  Begin
    I := ScopeTab[S].LastSym;
    While I >= 0 Do
    Begin
      If (SymTab[I].Kind = SK_OP) And (SymTab[I].Name = Name) And
         (OpArity(I) = Arity) Then
        SymOpExists := True;
      I := SymTab[I].Prev;
    End;
    S := ScopeTab[S].Parent;
  End;
End;

{ ---- prelude standard ---- }
Procedure PreOp(Const Name : TName; A, B, R : Integer);
Var
  S : Integer;
Begin
  ModeTmpReset;
  ModeTmpAdd('', A, 0, 0);
  If B >= 0 Then ModeTmpAdd('', B, 0, 0);
  S := SymDeclare(Name, SK_OP, ModeProcTmp(R), 0, 0);
  SymTab[S].Intrinsic := True;
End;

Procedure PreOpGeneric(Const Name : TName; Arity, R : Integer);
Var
  S : Integer;
Begin
  ModeTmpReset;
  ModeTmpAdd('', ModeRow(MD_INT, 1, False), 0, 0);
  If Arity = 2 Then ModeTmpAdd('', ModeRow(MD_INT, 1, False), 0, 0);
  S := SymDeclare(Name, SK_OP, ModeProcTmp(R), 0, 0);
  SymTab[S].Intrinsic := True;
  SymTab[S].Generic   := True;
End;

Procedure PrePrio(Const Name : TName; P : Integer);
Var
  S : Integer;
Begin
  S := SymDeclare(Name, SK_PRIO, MD_VOID, 0, 0);
  SymTab[S].Offset := P;
End;

{ operateur arithmetique sur INT et REAL, avec les combinaisons mixtes }
Procedure PreArith(Const Name : TName; IntRes, RealRes : Integer);
Begin
  PreOp(Name, MD_INT, MD_INT, IntRes);
  PreOp(Name, MD_REAL, MD_REAL, RealRes);
  PreOp(Name, MD_INT, MD_REAL, RealRes);
  PreOp(Name, MD_REAL, MD_INT, RealRes);
End;

Procedure PreCompare(Const Name : TName);
Begin
  PreOp(Name, MD_INT, MD_INT, MD_BOOL);
  PreOp(Name, MD_REAL, MD_REAL, MD_BOOL);
  PreOp(Name, MD_INT, MD_REAL, MD_BOOL);
  PreOp(Name, MD_REAL, MD_INT, MD_BOOL);
  PreOp(Name, MD_CHAR, MD_CHAR, MD_BOOL);
  PreOp(Name, MD_STRING, MD_STRING, MD_BOOL);
End;

Procedure PreAssignOp(Const Name : TName);
Begin
  PreOp(Name, ModeRef(MD_INT), MD_INT, ModeRef(MD_INT));
  PreOp(Name, ModeRef(MD_REAL), MD_REAL, ModeRef(MD_REAL));
  PreOp(Name, ModeRef(MD_REAL), MD_INT, ModeRef(MD_REAL));
End;

Procedure PreStd(Const Name : TName; M : Integer);
Var
  S : Integer;
Begin
  S := SymDeclare(Name, SK_STD, M, 0, 0);
  SymTab[S].Intrinsic := True;
  SymTab[S].AsmName := A68_RT_PFX + AsmIdent(Name);
End;

Procedure PreProc1(Const Name : TName; A, R : Integer);
Begin
  ModeTmpReset;
  ModeTmpAdd('', A, 0, 0);
  PreStd(Name, ModeProcTmp(R));
End;

Procedure PreludeInit;
Begin
  SymCount   := 0;
  ScopeCount := 0;
  ScopeCur   := -1;
  ScopeDepth := 0;
  ScopeEnter(SCK_PRELUDE);

  { priorites standard (Revised Report) }
  PrePrio('OR', 2);
  PrePrio('AND', 3);
  PrePrio('=', 4);       PrePrio('/=', 4);
  PrePrio('<', 5);       PrePrio('<=', 5);
  PrePrio('>', 5);       PrePrio('>=', 5);
  PrePrio('+', 6);       PrePrio('-', 6);
  PrePrio('*', 7);       PrePrio('/', 7);
  PrePrio('OVER', 7);    PrePrio('%', 7);
  PrePrio('MOD', 7);     PrePrio('%*', 7);
  PrePrio('**', 8);      PrePrio('SHL', 8);
  PrePrio('SHR', 8);     PrePrio('LWB', 8);
  PrePrio('UPB', 8);
  PrePrio('+*', 9);
  PrePrio('+:=', 1);     PrePrio('-:=', 1);
  PrePrio('*:=', 1);     PrePrio('/:=', 1);
  PrePrio('%:=', 1);     PrePrio('%*:=', 1);

  { operateurs dyadiques arithmetiques }
  PreArith('+', MD_INT, MD_REAL);
  PreArith('-', MD_INT, MD_REAL);
  PreArith('*', MD_INT, MD_REAL);
  PreArith('/', MD_REAL, MD_REAL);
  PreArith('**', MD_INT, MD_REAL);
  PreOp('OVER', MD_INT, MD_INT, MD_INT);
  PreOp('%', MD_INT, MD_INT, MD_INT);
  PreOp('MOD', MD_INT, MD_INT, MD_INT);
  PreOp('%*', MD_INT, MD_INT, MD_INT);
  { comparaisons }
  PreCompare('<');  PreCompare('<=');
  PreCompare('>');  PreCompare('>=');
  PreCompare('=');  PreCompare('/=');
  PreOp('=', MD_BOOL, MD_BOOL, MD_BOOL);
  PreOp('/=', MD_BOOL, MD_BOOL, MD_BOOL);
  PreOp('=', MD_BITS, MD_BITS, MD_BOOL);
  PreOp('/=', MD_BITS, MD_BITS, MD_BOOL);
  { booleens et bits }
  PreOp('AND', MD_BOOL, MD_BOOL, MD_BOOL);
  PreOp('OR', MD_BOOL, MD_BOOL, MD_BOOL);
  PreOp('AND', MD_BITS, MD_BITS, MD_BITS);
  PreOp('OR', MD_BITS, MD_BITS, MD_BITS);
  PreOp('SHL', MD_BITS, MD_INT, MD_BITS);
  PreOp('SHR', MD_BITS, MD_INT, MD_BITS);
  PreOp('SHL', MD_INT, MD_INT, MD_INT);       { extension }
  PreOp('SHR', MD_INT, MD_INT, MD_INT);       { extension }
  { chaines }
  PreOp('+', MD_STRING, MD_STRING, MD_STRING);
  PreOp('+', MD_STRING, MD_CHAR, MD_STRING);
  PreOp('+', MD_CHAR, MD_STRING, MD_STRING);
  PreOp('+', MD_CHAR, MD_CHAR, MD_STRING);
  { affectations composees (et leurs formes en mots) }
  PreAssignOp('+:=');  PreAssignOp('-:=');
  PreAssignOp('*:=');  PreAssignOp('/:=');
  PreAssignOp('PLUSAB');   PreAssignOp('MINUSAB');
  PreAssignOp('TIMESAB');  PreAssignOp('DIVAB');
  PreOp('%:=', ModeRef(MD_INT), MD_INT, ModeRef(MD_INT));
  PreOp('%*:=', ModeRef(MD_INT), MD_INT, ModeRef(MD_INT));
  PreOp('OVERAB', ModeRef(MD_INT), MD_INT, ModeRef(MD_INT));
  PreOp('MODAB', ModeRef(MD_INT), MD_INT, ModeRef(MD_INT));
  PreOp('+:=', ModeRef(MD_STRING), MD_STRING, ModeRef(MD_STRING));
  PreOp('+:=', ModeRef(MD_STRING), MD_CHAR, ModeRef(MD_STRING));
  { operateurs monadiques }
  PreOp('-', MD_INT, -1, MD_INT);
  PreOp('-', MD_REAL, -1, MD_REAL);
  PreOp('+', MD_INT, -1, MD_INT);
  PreOp('+', MD_REAL, -1, MD_REAL);
  PreOp('ABS', MD_INT, -1, MD_INT);
  PreOp('ABS', MD_REAL, -1, MD_REAL);
  PreOp('ABS', MD_CHAR, -1, MD_INT);
  PreOp('ABS', MD_BOOL, -1, MD_INT);
  PreOp('SIGN', MD_INT, -1, MD_INT);
  PreOp('SIGN', MD_REAL, -1, MD_INT);
  PreOp('ODD', MD_INT, -1, MD_BOOL);
  PreOp('NOT', MD_BOOL, -1, MD_BOOL);
  PreOp('NOT', MD_BITS, -1, MD_BITS);
  PreOp('BIN', MD_INT, -1, MD_BITS);
  PreOp('ENTIER', MD_REAL, -1, MD_INT);
  PreOp('ROUND', MD_REAL, -1, MD_INT);
  PreOp('REPR', MD_INT, -1, MD_CHAR);
  PreOpGeneric('LWB', 1, MD_INT);
  PreOpGeneric('UPB', 1, MD_INT);
  PreOpGeneric('LWB', 2, MD_INT);
  PreOpGeneric('UPB', 2, MD_INT);

  { identificateurs standard }
  PreStd('pi', MD_REAL);
  PreStd('print', MD_VOID);       { forme speciale (TODO 19) }
  PreStd('read', MD_VOID);        { forme speciale (TODO 19) }
  PreStd('newline', MD_VOID);     { marqueur de print (TODO 19) }
  PreStd('space', MD_VOID);       { marqueur de print (TODO 19) }
  ModeTmpReset;
  ModeTmpAdd('', MD_INT, 0, 0);
  ModeTmpAdd('', MD_INT, 0, 0);
  PreStd('whole', ModeProcTmp(MD_STRING));
  PreProc1('sqrt', MD_REAL, MD_REAL);
  PreProc1('sin', MD_REAL, MD_REAL);
  PreProc1('cos', MD_REAL, MD_REAL);
  PreProc1('tan', MD_REAL, MD_REAL);
  PreProc1('arctan', MD_REAL, MD_REAL);
  PreProc1('exp', MD_REAL, MD_REAL);
  PreProc1('ln', MD_REAL, MD_REAL);
End;

{ ============================================================
  SECTION 9 - CODE INTERNE, LISTING ASM ET DONNEES (TODO 06)
  ============================================================ }

(* Le generateur produit une liste d'instructions 80386 structurees
  (CodeTab), consommee par le listing .ASM optionnel (WriteListing)
  puis par l'encodeur binaire (TODO 20). Les corps de procedures et
  d'operateurs sont ecrits dans une seconde liste (DeferTab) placee
  apres le programme principal.

  Conventions de generation :
    - INT, BOOL, CHAR, BITS, REF : EAX ; REAL : ST(0) ; les valeurs
      intermediaires sont rangees sur la pile machine (jamais en
      registre a travers un appel)
    - ECX, EDX, ESI, EDI : temporaires ; EBP : cadre ; ESP : pile
    - appels de procedure : voir TODO 16 ; routines du runtime :
      arguments dans les registres (TODO 22) *)
Const
  MAX_CODE      = {$IFDEF FPC}262144{$ELSE}2048{$ENDIF};
  MAX_NAMES     = {$IFDEF FPC}16384{$ELSE}512{$ENDIF};
  MAX_ASMSTR    = {$IFDEF FPC}4096{$ELSE}64{$ENDIF};
  MAX_DATAITEMS = {$IFDEF FPC}8192{$ELSE}256{$ENDIF};
  MAX_TABENT    = {$IFDEF FPC}8192{$ELSE}256{$ENDIF};
  NAME_HASH     = {$IFDEF FPC}32768{$ELSE}1024{$ENDIF};

Type
  TMangled = String[127];

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
    OP_CALL, OP_RET, OP_REP_STOSD, OP_REP_MOVSD,
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

  TDoubleBits = Record
    Case Boolean Of
      False : (D : Double);
      True  : (Lo, Hi : LongInt);
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
  For I := 1 To Length(S) Do
    H := ((H * 33) + Ord(S[I])) And $7FFFFFF;
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

{ Etiquette interne _A60L_NNNNN }
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
    OP_REP_MOVSD: OpName := 'REP MOVSD';
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
  WriteLn(F, '; ', FileName, ' - genere par AL68CW32 ',
          AL68CW32_VERSION, ' a partir de ', Opts.SrcFile);
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
  WriteLn(F, 'EXTERN HeapFree:PROC');
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
  WriteLn(F, 'END ', A68_MAIN_NAME);
  Close(F);
  If IOResult <> 0 Then
    FatalError('erreur d''ecriture de ' + FileName);
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
  N := Intern(A68_STR_PFX + ItoS(ConstSeq));
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
  N := Intern('_A68C_' + ItoS(ConstSeq));
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
  N := Intern('_A68C_' + ItoS(ConstSeq));
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

{ Mode debug -d : liste des cellules de donnees }
Procedure DataDump;
Var
  I : Integer;
  K : TString;
Begin
  WriteLn('Donnees (', DataCount, ') :');
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_ZERO  : K := 'zero';
      DK_STR   : K := 'chaine';
      DK_INT   : K := 'entier';
      DK_REAL  : K := 'reel';
      DK_TABLE : K := 'table';
    End;
    WriteLn('  ', NameTab[DataTab[I].Name], ' ', K, ' ',
            DataTab[I].Size, ' octets');
  End;
End;


{ ---- Programme principal ---- }
Procedure GenMainBegin;
Begin
  EmitComment('programme principal');
  EmitLabel(Intern(A68_MAIN_NAME));
  Emit1(OP_PUSH, OpReg(R_EBP));
  Emit(OP_MOV, OpReg(R_EBP), OpReg(R_ESP));
  DataAddZero(Intern(A68_MAINBP), 4);
  Emit(OP_MOV, OpMemSym(Intern(A68_MAINBP), 0, 4), OpReg(R_EBP));
End;

Procedure GenMainEnd;
Begin
  Emit1(OP_PUSH, OpImm(0));
  Emit1(OP_CALL, OpLabel(Intern('ExitProcess')));
End;

{ ============================================================
  SECTION 10 - ARBRE D UNITES ET PARSEUR (TODO 07, 08, 10)
  ============================================================ }
Var
  UnitTab    : Array[0..MAX_UNIT - 1] Of TUnit;
  UnitCount  : LongInt;
  UnitRoot   : LongInt;       { clause serie du programme              }
  TokPos     : LongInt;       { jeton courant dans TokTab              }
  GotoTab    : Array[0..MAX_LABEL - 1] Of LongInt;
  GotoCount  : Integer;
  ClauseCount: LongInt;       { clauses fermees analysees              }
  LabelCount : LongInt;       { etiquettes definies                    }
  OpaqueCount: LongInt;       { unites et declarations non analysees   }

Function UnitNew(K : TUnitKind; Line, Col : Integer) : LongInt;
Begin
  If UnitCount >= MAX_UNIT Then
    FatalError('programme trop long (arbre d''unites plein, max ' +
               ItoS(MAX_UNIT) + ')');
  UnitTab[UnitCount].Kind  := K;
  UnitTab[UnitCount].Mode  := MD_ERROR;
  UnitTab[UnitCount].Line  := Line;
  UnitTab[UnitCount].Col   := Col;
  UnitTab[UnitCount].A     := -1;
  UnitTab[UnitCount].B     := -1;
  UnitTab[UnitCount].C     := -1;
  UnitTab[UnitCount].Next  := -1;
  UnitTab[UnitCount].Sym   := -1;
  UnitTab[UnitCount].Scope := ScopeCur;
  UnitTab[UnitCount].Name  := '';
  UnitTab[UnitCount].IntVal := 0;
  UnitNew := UnitCount;
  Inc(UnitCount);
End;

{ ---- acces aux jetons ---- }
Function TokAt(K : LongInt) : TToken;
Begin
  If TokPos + K >= TokCount Then
    TokAt := TokTab[TokCount - 1]          { EOF }
  Else
    TokAt := TokTab[TokPos + K];
End;

Procedure ParserAdvance;
Begin
  If TokPos < TokCount - 1 Then Inc(TokPos);
End;

Function AtKw(Const W : TName) : Boolean;
Begin
  AtKw := (TokTab[TokPos].Kind = TK_KEYWORD) And (TokTab[TokPos].Val = W);
End;

Function AtPunct(Const W : TName) : Boolean;
Begin
  AtPunct := (TokTab[TokPos].Kind = TK_PUNCT) And (TokTab[TokPos].Val = W);
End;

Function AtEOF : Boolean;
Begin
  AtEOF := TokTab[TokPos].Kind = TK_EOF;
End;

Function TokDesc(Const T : TToken) : TString;
Begin
  Case T.Kind Of
    TK_EOF     : TokDesc := 'fin de fichier';
    TK_INT     : TokDesc := T.Val;
    TK_REAL    : TokDesc := T.Val;
    TK_BOOL    : TokDesc := T.Val;
    TK_CHAR    : TokDesc := '"' + T.Val + '"';
    TK_STRING  : TokDesc := 'chaine';
    TK_TAG     : TokDesc := 'identificateur ' + T.Val;
  Else
    TokDesc := '''' + T.Val + '''';
  End;
End;

Procedure ParseError(Const Msg : TString);
Begin
  ErrorAt(TokTab[TokPos].Line, TokTab[TokPos].Col,
          Msg + ' (trouve: ' + TokDesc(TokTab[TokPos]) + ')');
End;

{ +1 pour un jeton qui ouvre une construction, -1 pour un jeton qui la
  ferme, 0 sinon }
Function TokDepth(Const T : TToken) : Integer;
Begin
  TokDepth := 0;
  If T.Kind = TK_KEYWORD Then
  Begin
    If (T.Val = 'BEGIN') Or (T.Val = 'IF') Or (T.Val = 'CASE') Or
       (T.Val = 'DO') Then
      TokDepth := 1
    Else If (T.Val = 'END') Or (T.Val = 'FI') Or (T.Val = 'ESAC') Or
            (T.Val = 'OD') Then
      TokDepth := -1;
  End
  Else If T.Kind = TK_PUNCT Then
  Begin
    If (T.Val = '(') Or (T.Val = '[') Then
      TokDepth := 1
    Else If (T.Val = ')') Or (T.Val = ']') Then
      TokDepth := -1;
  End;
End;

{ Le jeton ferme-t-il une clause serie (a profondeur nulle) ? }
Function AtSerialEnd : Boolean;
Var
  T : TToken;
Begin
  T := TokTab[TokPos];
  AtSerialEnd := False;
  Case T.Kind Of
    TK_EOF : AtSerialEnd := True;
    TK_KEYWORD:
      AtSerialEnd := (T.Val = 'END') Or (T.Val = 'FI') Or
                     (T.Val = 'ESAC') Or (T.Val = 'OD') Or
                     (T.Val = 'ELSE') Or (T.Val = 'ELIF') Or
                     (T.Val = 'OUT') Or (T.Val = 'OUSE') Or
                     (T.Val = 'THEN') Or (T.Val = 'IN') Or
                     (T.Val = 'DO');
    TK_PUNCT:
      AtSerialEnd := (T.Val = ')') Or (T.Val = ']') Or (T.Val = '|') Or
                     (T.Val = '|:');
  End;
End;

{ Debut d une declaration (analysee au TODO 08) : mot de declarateur, ou
  nom de mode suivi d un identificateur }
Function AtDeclStart : Boolean;
Var
  T, N : TToken;
Begin
  T := TokTab[TokPos];
  N := TokAt(1);
  AtDeclStart := False;
  If T.Kind = TK_KEYWORD Then
    AtDeclStart := (T.Val = 'MODE') Or (T.Val = 'PRIO') Or
                   (T.Val = 'OP') Or (T.Val = 'PROC') Or
                   (T.Val = 'INT') Or (T.Val = 'REAL') Or
                   (T.Val = 'BOOL') Or (T.Val = 'CHAR') Or
                   (T.Val = 'STRING') Or (T.Val = 'BITS') Or
                   (T.Val = 'BYTES') Or (T.Val = 'COMPL') Or
                   (T.Val = 'REF') Or (T.Val = 'HEAP') Or
                   (T.Val = 'LOC') Or (T.Val = 'FLEX') Or
                   (T.Val = 'LONG') Or (T.Val = 'STRUCT') Or
                   (T.Val = 'UNION')
  Else If T.Kind = TK_PUNCT Then
    AtDeclStart := T.Val = '['
  Else If (T.Kind = TK_BOLD) Or (T.Kind = TK_TAG) Then
    AtDeclStart := N.Kind = TK_TAG;
End;

{ Jetons de la position courante jusqu au ; ou a la fermeture de la
  clause, sans les analyser : enveloppe provisoire des unites et
  declarations des TODOs suivants. Retourne le noeud. }
Function ParseOpaque(K : TUnitKind) : LongInt;
Var
  U, Start : LongInt;
  Depth    : Integer;
  Done     : Boolean;
  LoopHead : Boolean;
  OL, OC   : Integer;
Begin
  U := UnitNew(K, TokTab[TokPos].Line, TokTab[TokPos].Col);
  Start := TokPos;
  Depth := 0;
  OL := 0;
  OC := 0;
  Done := False;
  { une clause repetitive FOR ... DO ... OD : son DO ouvre le corps }
  LoopHead := AtKw('FOR') Or AtKw('WHILE') Or AtKw('FROM') Or
              AtKw('BY') Or AtKw('TO') Or AtKw('DOWNTO');
  While Not Done Do
  Begin
    If AtEOF Then
    Begin
      If Depth > 0 Then
        ErrorAt(OL, OC, 'construction non fermee (fin de fichier)');
      Done := True;
    End
    Else If (Depth = 0) And LoopHead And AtKw('DO') Then
    Begin
      OL := TokTab[TokPos].Line;
      OC := TokTab[TokPos].Col;
      LoopHead := False;
      Inc(Depth);
      ParserAdvance;
    End
    Else If (Depth = 0) And (AtPunct(';') Or AtSerialEnd) Then
      Done := True
    Else
    Begin
      If TokDepth(TokTab[TokPos]) > 0 Then
      Begin
        If Depth = 0 Then
        Begin
          OL := TokTab[TokPos].Line;
          OC := TokTab[TokPos].Col;
        End;
        Inc(Depth);
      End
      Else If (TokDepth(TokTab[TokPos]) < 0) And (Depth > 0) Then
        Dec(Depth);
      ParserAdvance;
    End;
  End;
  If TokPos = Start Then ParserAdvance;     { progression garantie }
  UnitTab[U].A := Start;
  UnitTab[U].B := TokPos;
  Inc(OpaqueCount);
  ParseOpaque := U;
End;

{ La parenthese ouvrante courante ouvre-t-elle une clause fermee simple
  (ni (c | a | b), ni liste d elements separes par des virgules) ? }
Function ParenIsClosed : Boolean;
Var
  K     : LongInt;
  Depth : Integer;
  T     : TToken;
  Plain : Boolean;
Begin
  Plain := True;
  Depth := 0;
  K := TokPos;
  While K < TokCount Do
  Begin
    T := TokTab[K];
    If T.Kind = TK_EOF Then
      K := TokCount
    Else
    Begin
      If TokDepth(T) > 0 Then
        Inc(Depth)
      Else If TokDepth(T) < 0 Then
        Dec(Depth)
      Else If (Depth = 1) And (T.Kind = TK_PUNCT) And
              ((T.Val = ',') Or (T.Val = '|') Or (T.Val = '|:')) Then
        Plain := False;
      If Depth <= 0 Then K := TokCount Else Inc(K);
    End;
  End;
  ParenIsClosed := Plain;
End;

{ Definit l etiquette courante dans la portee courante (erreur si elle
  y est deja definie) }
Function ParseLabelDef : LongInt;
Var
  U    : LongInt;
  I, S : Integer;
  Name : TName;
Begin
  Name := TokTab[TokPos].Val;
  U := UnitNew(UK_LABELDEF, TokTab[TokPos].Line, TokTab[TokPos].Col);
  UnitTab[U].Name := Name;
  S := -1;
  I := ScopeTab[ScopeCur].LastSym;
  While (I >= 0) And (S < 0) Do
  Begin
    If (SymTab[I].Kind = SK_LABEL) And (SymTab[I].Name = Name) Then S := I;
    I := SymTab[I].Prev;
  End;
  If S >= 0 Then
    ErrorAt(TokTab[TokPos].Line, TokTab[TokPos].Col,
            'etiquette dupliquee: ' + Name)
  Else
  Begin
    S := SymDeclare(Name, SK_LABEL, MD_VOID, TokTab[TokPos].Line,
                    TokTab[TokPos].Col);
    Inc(LabelCount);
  End;
  UnitTab[U].Sym := S;
  ParserAdvance;                       { l etiquette }
  ParserAdvance;                       { les deux-points }
  ParseLabelDef := U;
End;

{ GOTO etiquette : l etiquette peut etre definie plus loin ; la
  resolution se fait a la fin de l analyse (ResolveGotos) }
Function ParseGoto : LongInt;
Var
  U : LongInt;
Begin
  U := UnitNew(UK_GOTO, TokTab[TokPos].Line, TokTab[TokPos].Col);
  ParserAdvance;                       { GOTO }
  If TokTab[TokPos].Kind = TK_TAG Then
  Begin
    UnitTab[U].Name := TokTab[TokPos].Val;
    If GotoCount >= MAX_LABEL Then
      FatalError('trop de sauts GOTO (max ' + ItoS(MAX_LABEL) + ')');
    GotoTab[GotoCount] := U;
    Inc(GotoCount);
    ParserAdvance;
  End
  Else
    ParseError('etiquette attendue apres GOTO');
  ParseGoto := U;
End;

Function ParseSerial(Top : Boolean) : LongInt; Forward;

{ Clause fermee : BEGIN ... END ou ( ... ) ; ouvre une portee }
Function ParseClosed : LongInt;
Var
  U, Ser  : LongInt;
  L, C    : Integer;
  IsBegin : Boolean;
Begin
  L := TokTab[TokPos].Line;
  C := TokTab[TokPos].Col;
  IsBegin := AtKw('BEGIN');
  U := UnitNew(UK_CLOSED, L, C);
  ParserAdvance;                       { BEGIN ou ( }
  UnitTab[U].Scope := ScopeEnter(SCK_CLOSED);
  Ser := ParseSerial(False);
  UnitTab[U].A := Ser;
  If IsBegin Then
  Begin
    If AtKw('END') Then
      ParserAdvance
    Else
      ParseError('''END'' attendu (BEGIN ouvert ligne ' + ItoS(L) +
                 ', colonne ' + ItoS(C) + ')');
  End
  Else
  Begin
    If AtPunct(')') Then
      ParserAdvance
    Else
      ParseError(''')'' attendu (parenthese ouverte ligne ' + ItoS(L) +
                 ', colonne ' + ItoS(C) + ')');
  End;
  ScopeLeave;
  Inc(ClauseCount);
  ParseClosed := U;
End;

{ Une unite ; les unites autres que la clause fermee, GOTO et SKIP sont
  provisoirement enveloppees (TODOs 10 a 19) }
Function ParseUnit : LongInt;
Var
  U : LongInt;
Begin
  If AtKw('BEGIN') Or (AtPunct('(') And ParenIsClosed) Then
    ParseUnit := ParseClosed
  Else If AtKw('GOTO') Then
    ParseUnit := ParseGoto
  Else If AtKw('SKIP') Then
  Begin
    U := UnitNew(UK_SKIP, TokTab[TokPos].Line, TokTab[TokPos].Col);
    ParserAdvance;
    ParseUnit := U;
  End
  Else If AtDeclStart Then
    ParseUnit := ParseOpaque(UK_DECL)
  Else
    ParseUnit := ParseOpaque(UK_OPAQUE);
End;

{ Clause serie : unites, declarations et etiquettes separees par des
  points-virgules, jusqu a une fermeture. Au niveau le plus externe
  (Top), seule la fin du fichier ferme la clause ; un jeton de
  fermeture isole est une erreur. Retourne le premier element. }
Function ParseSerial(Top : Boolean) : LongInt;
Var
  First, Last, U : LongInt;
  Start          : LongInt;
  NeedSep        : Boolean;

  Procedure AddItem(N : LongInt);
  Begin
    If First < 0 Then First := N Else UnitTab[Last].Next := N;
    Last := N;
  End;

Begin
  First := -1;
  Last := -1;
  NeedSep := False;
  While Not AtEOF Do
  Begin
    Start := TokPos;
    If AtPunct(';') Then
    Begin
      ParserAdvance;                   { separateur (unite vide toleree) }
      NeedSep := False;
    End
    Else If AtSerialEnd Then
    Begin
      If Not Top Then
      Begin
        ParseSerial := First;
        Exit;
      End;
      ParseError('fermeture sans ouverture');
      ParserAdvance;
    End
    Else If NeedSep Then
    Begin
      { recuperation : signale puis saute jusqu au prochain ; ou a une
        fermeture }
      ParseError(''';'' ou fermeture attendu');
      AddItem(ParseOpaque(UK_OPAQUE));
      NeedSep := True;
    End
    Else If (TokTab[TokPos].Kind = TK_TAG) And
            (TokAt(1).Kind = TK_PUNCT) And (TokAt(1).Val = ':') Then
      AddItem(ParseLabelDef)
    Else
    Begin
      U := ParseUnit;
      AddItem(U);
      NeedSep := True;
    End;
    If TokPos = Start Then ParserAdvance;     { progression garantie }
  End;
  ParseSerial := First;
End;

{ Etiquettes : chaque GOTO designe une etiquette visible depuis sa
  portee (la sienne ou une portee englobante) }
Function SymFindLabelFrom(S : Integer; Const Name : TName) : Integer;
Var
  I : Integer;
Begin
  SymFindLabelFrom := -1;
  While S >= 0 Do
  Begin
    I := ScopeTab[S].LastSym;
    While I >= 0 Do
    Begin
      If (SymTab[I].Kind = SK_LABEL) And (SymTab[I].Name = Name) Then
      Begin
        SymFindLabelFrom := I;
        Exit;
      End;
      I := SymTab[I].Prev;
    End;
    S := ScopeTab[S].Parent;
  End;
End;

Procedure ResolveGotos;
Var
  K : Integer;
  U : LongInt;
  S : Integer;
Begin
  For K := 0 To GotoCount - 1 Do
  Begin
    U := GotoTab[K];
    S := SymFindLabelFrom(UnitTab[U].Scope, UnitTab[U].Name);
    If S < 0 Then
      ErrorAt(UnitTab[U].Line, UnitTab[U].Col,
              'etiquette non definie: ' + UnitTab[U].Name)
    Else
    Begin
      UnitTab[U].Sym := S;
      SymTab[S].Used := True;
    End;
  End;
End;

Procedure WarnUnusedLabels;
Var
  I : Integer;
Begin
  For I := 0 To SymCount - 1 Do
    If (SymTab[I].Kind = SK_LABEL) And Not SymTab[I].Used Then
      WarnAt(SymTab[I].Line, SymTab[I].Col,
             'etiquette non utilisee: ' + SymTab[I].Name);
End;

{ Mode debug -d : arbre d unites }
Function UnitKindName(K : TUnitKind) : TString;
Begin
  Case K Of
    UK_SERIAL   : UnitKindName := 'clause serie';
    UK_CLOSED   : UnitKindName := 'clause fermee';
    UK_LABELDEF : UnitKindName := 'etiquette';
    UK_GOTO     : UnitKindName := 'GOTO';
    UK_SKIP     : UnitKindName := 'SKIP';
    UK_DECL     : UnitKindName := 'declaration (non analysee)';
    UK_OPAQUE   : UnitKindName := 'unite (non analysee)';
  End;
End;

Procedure UnitDump(U : LongInt; Depth : Integer);
Var
  I : Integer;
  E : LongInt;
Begin
  While U >= 0 Do
  Begin
    For I := 1 To Depth Do Write('  ');
    Write(UnitKindName(UnitTab[U].Kind), ' ligne ', UnitTab[U].Line);
    Case UnitTab[U].Kind Of
      UK_LABELDEF, UK_GOTO : Write(' ', UnitTab[U].Name);
      UK_DECL, UK_OPAQUE   :
        Begin
          Write(' :');
          E := UnitTab[U].A;
          While (E < UnitTab[U].B) And (E < UnitTab[U].A + 8) Do
          Begin
            Write(' ', TokTab[E].Val);
            Inc(E);
          End;
          If E < UnitTab[U].B Then Write(' ...');
        End;
    End;
    WriteLn;
    If UnitTab[U].Kind = UK_CLOSED Then
      UnitDump(UnitTab[U].A, Depth + 1);
    U := UnitTab[U].Next;
  End;
End;

Procedure PhaseParse;
Begin
  UnitCount := 0;
  TokPos := 0;
  GotoCount := 0;
  ClauseCount := 0;
  LabelCount := 0;
  OpaqueCount := 0;
  ScopeEnter(SCK_PROGRAM);
  UnitRoot := UnitNew(UK_SERIAL, 1, 1);
  UnitTab[UnitRoot].A := ParseSerial(True);
  ResolveGotos;
  If Opts.Warnings Then WarnUnusedLabels;
  ScopeLeave;
  If Opts.Verbose Then
    WriteLn('  ', UnitCount, ' unite(s), ', ClauseCount,
            ' clause(s) fermee(s), ', LabelCount, ' etiquette(s), ',
            GotoCount, ' goto, ', OpaqueCount,
            ' unite(s) ou declaration(s) pas encore analysee(s)');
  If Opts.DebugMode Then
  Begin
    WriteLn('Arbre d''unites (', UnitCount, ' noeuds) :');
    UnitDump(UnitTab[UnitRoot].A, 1);
  End;
End;

{ ============================================================
  SECTION 11 - COERCITIONS, MODES ET GENERATION (TODO 09, 11 a 19)
  ============================================================ }
Procedure PhaseModes;
Begin
  { A faire : TODO 09 et 11 a 19 }
End;

{ ---- Generation du code a partir de l arbre ---- }
Procedure GenUnit(U : LongInt);
Begin
  While U >= 0 Do
  Begin
    Case UnitTab[U].Kind Of
      UK_SERIAL  : GenUnit(UnitTab[U].A);
      UK_CLOSED  : GenUnit(UnitTab[U].A);
      UK_LABELDEF:
        If UnitTab[U].Sym >= 0 Then
          EmitLabel(Intern(SymTab[UnitTab[U].Sym].AsmName));
      UK_GOTO    :
        If UnitTab[U].Sym >= 0 Then
          Emit1(OP_JMP, OpLabel(Intern(SymTab[UnitTab[U].Sym].AsmName)));
      UK_SKIP    : ;
      UK_DECL, UK_OPAQUE:
        EmitComment('(ligne ' + ItoS(UnitTab[U].Line) +
                    ' : pas encore generee)');
    End;
    U := UnitTab[U].Next;
  End;
End;

Procedure PhaseCodegen;
Begin
  GenMainBegin;
  GenUnit(UnitRoot);
  GenMainEnd;
  If Opts.Verbose Then
    WriteLn('  ', CodeCount + DeferCount, ' instruction(s), ',
            DataCount, ' donnee(s) statique(s), ', NameCount,
            ' nom(s) interne(s)');
  If Opts.DebugMode Then
  Begin
    DataDump;
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
  PreludeInit;
  CodeInit;
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
