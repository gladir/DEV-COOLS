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

  CONTRAINTE : AL68CW32.PAS n'a aucune dependance externe : aucune clause
    Uses (pas meme Math ni SysUtils), aucune inclusion de fichier par une
    directive d'inclusion ; tout le code est dans ce seul fichier. La
    directive de compilation I- ne fait qu'arreter la verification des
    erreurs d'entree/sortie.

  ETAT : TODO 01 a 24 implementes (squelette en sections, pipeline en 7
         phases, options, constantes, limites et nommage, lexeur, modes,
         symboles et prelude, code interne et listing, parseur de
         clauses, declarations, coercitions, primaires, formules,
         conditionnelles et boucles, structures,
         affectations, tableaux, procedures, operateurs, unions,
         transput, encodeur x86-32, ecrivains PE et COFF, runtime,
         erreurs et avertissements, programme principal et modes -v et -d)
         ; TODO 25 a faire.

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
            Aucune dependance externe : ni Uses, ni inclusion de fichier
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

  TODO 08 - DECLARATIONS : IDENTITE, VARIABLE, MODE ET PRIO [IMPLEMENTE]
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
            Realise : ParseDeclarer (INT, REAL, BOOL, CHAR, STRING, BITS,
              VOID, REF, STRUCT avec noms de champs groupes, UNION, PROC,
              [l:u, ...] avec bornes, [] et [,] sans bornes, FLEX, noms de
              modes) ; ParseObjectDecl (LOC ou HEAP, listes separees par
              des virgules, = pour une identite, := ou rien pour une
              variable de mode REF m) ; ParseModeDecl (alias direct pour
              un mode simple, mode nomme pour STRUCT et UNION, ce qui
              permet les modes recursifs ; recursion sans REF signalee) ;
              ParsePrioDecl (priorite de 1 a 9) ; denotations en noeuds
              UK_INTDEN, UK_REALDEN, UK_BOOLDEN, UK_CHARDEN, UK_STRDEN ;
              les autres initialiseurs et bornes sont enveloppes
              provisoirement (ParseOpaqueUntil) ; DenotationFits
              (INT vers REAL ou BITS, CHAR vers STRING, denotation vers
              l'une des alternatives d'une UNION) ; DeclareStorage (cellule
              du segment de donnees ou place dans le cadre) ; PROC et OP
              restent enveloppes (TODOs 16 et 17) ; GenDecl et
              GenStoreDenotation : INT, BOOL, CHAR, BITS par MOV, REAL par
              x87, STRING par descripteur (adresse, 1, longueur, 1), UNION
              par etiquette de mode puis valeur
            Verifie : les 27 exemples sont analyses sans erreur ; les
              modes POINT, VEC3, rect, myint, NOMBRE, WRAPPED et POLYVAL
              sont crees avec les bonnes tailles ; test_decl s'assemble
              avec ML et x, y et c2 valent 42, 10 et 3 a l'execution ;
              erreurs : doublon, mode inconnu, mode recursif sans REF,
              initialisation incompatible, priorite hors limites, champ
              en double, VOID dans une union, identite de tableau avec
              bornes, nom attendu ; STRUCT(INT a, b, REAL c), UNION(INT,
              REAL) := 3, [1:3, 1:4] REAL, FLEX [] CHAR et PROC (INT) INT
              sont acceptes

  TODO 09 - COERCITIONS [IMPLEMENTE]
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
            Realise : section 11 ; noeud UK_COERCE (unite enveloppee, genre
              CO_DEREF, CO_DEPROC, CO_WIDEN, CO_ROW, CO_UNITE ou CO_VOID,
              mode obtenu) ; TStrength (douce, faible, meek, ferme, forte) ;
              CoerceFit (union, elargissement, enrobage d'un element,
              NIL vers REF) ; CoerceUnit : suite de deprocedurages et
              dereferencements puis coercition finale, repliement des
              denotations (7 vers REAL, caractere vers chaine), SKIP, GOTO,
              EMPTY et NIL qui prennent le mode demande, clause fermee dont
              le dernier element prend le mode demande, unite de mode
              inconnu laissee telle quelle, erreur coercition impossible ;
              l'etiquette d'une union est l'indice de l'alternative (B) ;
              CoerceName (force faible : un nom reste un REF) ;
              ModeBalance (equilibrage de deux branches) ; PhaseModes :
              ModesSerial (unites non finales videes, derniere coercee ;
              la parse ne verifie plus les initialiseurs) et ModesDecl
              (initialiseur coerce vers le mode de l'objet) ; NIL, EMPTY
              et SKIP reconnus comme initialiseurs ; GenInit genere
              denotation, NIL, EMPTY et union ; -d affiche l'arbre apres
              coercitions
            Verifie : harnais de 33 controles hors depot (REF REF INT vers
              INT, 7 vers REAL, INT vers REAL refuse en contexte ferme,
              REF INT vers REAL, INT et REAL vers UNION, BOOL vers UNION
              refuse, UNION(INT) vers UNION(INT, REAL), caractere vers
              STRING, enrobage, PROC INT vers INT, vidage, NIL, SKIP, force
              faible et douce, equilibrage, clause serie et clause fermee) :
              tous reussis ; les 27 exemples passent sans erreur ; test_union
              s'assemble avec ML et les unions contiennent l'etiquette de
              mode puis la valeur (par exemple 2 puis 42 pour un INT)

  TODO 10 - UNITES PRIMAIRES [IMPLEMENTE]
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
            Realise : section 10 ; ParsePrimary (denotation, identificateur,
              clause fermee, champ OF operande, constructeur de structure
              ou conversion, suivis d'indexations et d'appels) qui rend -1
              sans rien consommer devant ce qui n'est pas encore analyse ;
              ParseUnitX : une unite est une primaire seule, sinon elle est
              enveloppee (formules, conditionnelles, boucles : TODOs 11 a
              19) ; ParseSelection (operande coerce en nom, champ et decalage
              trouves, mode REF champ si l'operande est un nom) ;
              ParseSlice (nombre d'indices verifie, indices coerces en INT,
              tranches l:u, mode element ou tableau, REF si nom) ;
              ParseCall (procedure deduite du mode, nombre d'arguments
              verifie, arguments coerces vers les modes des parametres) ;
              ParseConstruct (POINT(3, 7), valeurs coercees vers les
              champs, INT(x) conversion) ; identificateur non declare
              signale ; les noms de PROC sont declares des maintenant, de
              mode inconnu ; deflexion (un tableau de meme element convient
              a un STRING) ; la section des coercitions precede le
              parseur ; generation : GenValue (mot dans EAX, reel dans
              ST(0), adresse dans EAX pour les objets en memoire),
              StoreValue (MOV, FSTP ou REP MOVSD), identificateurs,
              pi, selection, constructeur (cellule temporaire), coercitions
              (dereferencement, elargissement par FILD, vidage, union),
              GenInit pour tous les initialiseurs ; indexation, appels et
              conversions : TODOs 15, 16 et 19
            Verifie : les 27 exemples sont analyses sans erreur et
              assembles par ML ; programme d'essai execute (valeurs lues
              dans les cellules par le code de sortie) : x OF p = 3,
              y OF p = 7, variable copiee, identite, REAL := 2.5 (5 une fois
              doublee), REAL := 7 (14), REAL := entier (10), pi (6),
              union (etiquette 2 puis 5), structure copiee (7), NIL (0),
              STRING copiee (longueur 2), x OF POINT(40, 2) = 40 ; erreurs :
              identificateur inconnu, champ inconnu, constructeur ou appel
              avec un mauvais nombre de valeurs, selection ou indexation
              d'un mode qui ne convient pas, nombre d'indices, coercition
              impossible dans INT(r)

  TODO 11 - FORMULES ET OPERATEURS STANDARD [IMPLEMENTE]
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
            Realise : section 10 ; ParseFormula (operateurs a priorites,
              associatifs a gauche, priorites lues dans la table des
              symboles : OR 2 a ** 8, monadiques au-dessus) et ParseOperand
              (operateurs monadiques puis primaire) ; operateurs
              reconnus seulement s'ils existent dans le prelude ou chez
              l'utilisateur, sinon l'unite reste enveloppee (OP du TODO
              17, affectations du TODO 14) ; CoercePossible et
              SymFindOpFirm : l'operateur est identifie d'apres les modes
              des operandes apres coercitions fermes (le plus interne et le
              plus recent d'abord) ; MakeDyadic et MakeMonadic (operandes
              coerces vers les modes de l'operateur, erreur operateur
              impossible pour les modes X et Y) ; FoldBinary et FoldUnary :
              repliement entier (Int64, debordement signale), reel,
              booleen, comparaisons, ABS, SIGN, ODD, NOT, ENTIER, ROUND,
              division par zero constante signalee une seule fois ; une
              clause fermee suivie d'un operateur est une primaire ;
              GenDyadic et GenMonadic : entiers (ADD, SUB, IMUL, IDIV
              avec controle du diviseur puis appel de DIVZERO, MOD toujours
              positif ou nul), reels sur la pile x87 (FADDP, FSUBP, FMULP,
              FDIVP, comparaison par FCOMP, FNSTSW, SAHF et SETcc), / sur
              deux INT donne un REAL, comparaisons, AND, OR, NOT, SHL, SHR,
              ABS, SIGN, ODD, chaines par STRCAT et STRCMP (adresses des
              descripteurs dans ESI et EDI) ; les routines _A68RT_ (POW,
              RPOW, FLOOR, RTOI, RSIGN, DIVZERO, STRCAT, STRCMP) seront
              fournies par le TODO 22
            Verifie : les 27 exemples sont analyses sans erreur ; programme
              d'essai de 28 formules assemble par ML et execute (valeurs lues
              par le code de sortie) : + - * OVER MOD (reste positif, -7 MOD
              3 = 2), OVER tronque (-7 OVER 2 = -3), ** avec un POW de
              substitution, ABS, SIGN, - unaire, comparaisons, AND avec
              priorite, NOT (clause fermee), ODD, reels (1.5 + 15 = 16.5, 15 /
              5 = 3, 2 * 16.5 - 1 = 32), SHL, SHR, priorites (15 + 4 * 2 = 23,
              (15 + 4) * 2 = 38, 2 + 3 * 4 = 14 replie) ; erreurs : division
              par zero constante ou variable constante, BOOL + INT, REF
              STRING * INT, debordement de constante

  TODO 12 - CLAUSES CONDITIONNELLES ET REPETITIVES [IMPLEMENTE]
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
            Realise : section 10 ; ParseIfTail et ParseIf (IF, ELIF, ELSE,
              FI, chaque partie dans sa portee, la condition et la partie
              alors partageant la leur) ; ParseCaseTail et ParseCase (IN,
              alternatives separees par des virgules, OUT, OUSE chaine,
              ESAC ; une clause de conformite (INT i) : est laissee au
              TODO 18) ; ParseBrief (formes ( c | a | b ) et ( s | u1, u2
              | d ), |: pour la suite ; IF ou CASE d'apres le mode du
              selecteur ou les virgules) ; ParseLoop (FOR, FROM, BY, TO,
              DOWNTO, WHILE, DO, OD dans n'importe quel ordre pour FROM, BY
              et TO, variable de controle INT locale, bornes evaluees dans
              la portee exterieure) ; mode d'une clause : equilibre des
              branches (VOID sans ELSE) ; CoerceUnit propage le mode demande
              aux branches et aux alternatives, la condition devient BOOL, le
              selecteur et les bornes INT, IF sans ELSE comme valeur est une
              erreur ; GenIf, GenCase (comparaisons successives), GenLoop
              (bornes et pas dans des cellules, test du signe du pas a la
              compilation ou a l'execution, WHILE apres le test de borne) ;
              GenSerialValue (valeur de la derniere unite) ; les mots de
              boucle terminent une expression ; un nom de mode n'est plus
              confondu avec un operateur monadique
            Verifie : les 27 exemples sont analyses sans erreur ; 13 valeurs
              de IF, ELIF, CASE, OUSE, formes abregees avec |: et IF dans
              une formule sont correctes a l'execution (42, 99, 20, 20, 99,
              42, 20, 99, 30, 7, 9, 6, 2 et 1.0 * 2 = 2 pour des branches
              INT et REAL) ; 11 boucles : 1 a 10 (55), TO 5 (15), BY 2 (25),
              DOWNTO (55), WHILE seul (5 tours), FOR avec WHILE (21), deux
              boucles imbriquees (9), BY -1 (15), aucune iteration (0), BY
              variable negative (25), boucle sans borne quittee par GOTO ;
              erreurs : IF sans ELSE comme valeur, THEN, FI, OD manquants,
              condition non booleenne, borne reelle, selecteur booleen

  TODO 13 - STRUCTURES (STRUCT) [IMPLEMENTE]
            MODE POINT = STRUCT(INT x, INT y) ; champs de modes
              differents, alias de mode, structures emboitees
            Disposition des champs (decalage de chaque champ, taille
              totale alignee)
            Constructeur POINT(3, 7) et initialisation d'une variable
            Selection x OF p en lecture et en ecriture : x OF p := 5
            Affectation d'une structure entiere (copie des octets)
            Passage et retour de structures par les procedures
            Verification : structs.a68, test_struct.a68
            Realise : l'essentiel vient des TODOs 04, 08, 09 et 10 et est
              verifie ici : modes STRUCT a champs groupes (INT a, b),
              equivalence structurelle (deux structures de meme forme sont
              le meme mode), decalages calcules par ModeFieldOffset (REAL
              sur 8 octets, STRING sur 16, UNION sur 4 + la plus large,
              structure emboitee en ligne), constructeur POINT(3, 7) dont
              chaque valeur est coercee vers son champ (INT vers REAL, un
              identificateur, une structure, une chaine, une union),
              constructeurs imbriques, selection a plusieurs niveaux
              (x OF tl OF r) et sur un constructeur (x OF POINT(40, 2)),
              selection qui rend un nom (REF champ) quand l'operande en est
              un, ce qui prepare x OF p := 5 du TODO 14, copie d'une
              structure entiere par REP MOVSD pour une initialisation ou un
              champ, mode recursif par REF (NODE avec NIL), message STRUCT
              sans champ ; l'affectation de structures et x OF p := v
              viennent avec le TODO 14, le passage et le retour par
              procedure avec le TODO 16
            Verifie : structs.a68 en entier (3, 7, 10, 20, 30, 99, l'aire
              40 * 25 = 1000 soit 232 modulo 256, 100) ; programme d'essai
              de 25 valeurs : rectangle de deux points (1, 40, 30), copie
              d'un champ structure (30), identite (6), structure mixte
              INT REAL STRING BOOL CHAR (7, 5 pour 2.5 double, longueur 2,
              1, 90), liste chainee (9, NIL), structure contenant une
              union (etiquette 2 puis 4), copie d'un rectangle (1, 40) ;
              erreurs : champ inconnu, selection sur un INT, constructeur
              avec un mauvais nombre ou un mauvais mode de valeur, STRUCT
              vide, mode inconnu dans un champ, mode redeclare ; les
              programmes d'essai sont conserves dans TESTS\AL68CW32\work

  TODO 14 - REFERENCES ET AFFECTATIONS [IMPLEMENTE]
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
            Realise : section 10 ; MakeAssign (membre gauche en force douce :
              un nom REF m, valeur coercee vers m en contexte fort, valeur
              de l'affectation = le nom ; erreur si le membre gauche n'est
              pas un nom, par exemple une identite) ; := et =: reconnus par
              ParseUnitX, le membre droit etant lui-meme une unite (a := b
              := c) ; MakeIdRel et UK_IDREL (IS, ISNT : deux noms REF de
              meme mode ou NIL, operandes en force faible, comparaison des
              adresses) ; affectations composees +:= -:= *:= /:= %:= %*:=
              et PLUSAB MINUSAB TIMESAB DIVAB OVERAB MODAB traitees comme
              operateurs du prelude (GenCompound : entiers en place, reels
              par x87, / et % entiers avec controle du diviseur, STRING par
              STRCAT) ; NIL comme primaire ; variables HEAP : la cellule
              contient l'adresse de l'objet, allocation par _A68RT_ALLOC,
              initialisation et lecture a travers le pointeur ; controle de
              la reference nulle (_A68RT_NILREF) avant tout
              dereferencement d'une reference lue en memoire et avant une
              selection ; GenAssign (nom, valeur, rangement par MOV, FSTP
              ou REP MOVSD) ; les corps de boucle et de conditionnelle sont
              maintenant vraiment generes
            Verifie : programme d'essai execute (cellules lues par le code
              de sortie) : x := 42, 99 =: z, a IS b faux et a ISNT b vrai
              pour deux variables de meme valeur, p IS NIL vrai, p := a puis
              p IS a vrai et lecture a travers p (5 puis 77 apres
              b := 77), HEAP INT initialise (31 puis 32) ou non (0),
              +:= -:= *:= /:= %:= (15, 13, 39, 19, 4), %*:= (2), reels (7,
              12, 3), n := m (100), w := q := 7, y1 OF pt := 9, copie d'une
              structure (9), HEAP de structure (3), somme d'une boucle FOR
              (55), IF avec affectations (1), WHILE (7) ; la lecture d'une
              reference NIL appelle NILREF ; erreurs : affectation a une
              constante, IS sur des modes differents ou sur un INT,
              coercition impossible a droite, -:= sur un STRING avec un
              CHAR ; refs.a68 est analyse entierement ; les boucles du
              TODO 12 s'executent sans remplacer leurs corps
            Reste : fait au TODO 22

  TODO 15 - TABLEAUX, TRANCHES ET CHAINES [IMPLEMENTE]
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
            Realise : descripteur de 4 mots pour une dimension (adresse,
              borne inf., borne sup., pas en octets) et 3 mots par
              dimension supplementaire ; tableau statique (bornes
              constantes, stockage reserve en donnees) ou dynamique (bornes
              evaluees a l'entree, stockage par _A68RT_ALLOC) ; CHAR sur
              un octet (MOVZX, ecriture d'octet), structures realignees ;
              UK_DISPLAY (affichage) coerce vers un tableau ou une
              structure, avec controle du nombre d'elements ; a[i] et
              a[i, j] avec controle _A68RT_CHKIDX ; tranche a[l:u] en
              nouveau descripteur sans copie ; LWB et UPB (forme
              dyadique n UPB a) ; copie de tableau par blocs (REP MOVSD) avec
              controle des dimensions (_A68RT_BOUNDS) ; identite
              [] INT t = (...) ; STRING = rangee flexible de CHAR (16
              octets), STRING e vide de bornes 1 et 0, h[2:4], h[5]
            Verifie : programme d'essai execute (ar.a68) : a[1], a[3],
              a[5] (10, 30, 50), LWB et UPB (1, 5), tableau sans valeur
              initiale (0), b[2] := 7, somme FOR de tab[i] (30), tableau
              dynamique [1:n] (9, 4), matrice m[2, 3] (55) et 2 UPB m (3),
              bornes [0:4], copie c := a puis a[1] := 99 (c reste a 10),
              identite [] INT (3, 7), tranches a[2:4] et a[2:4][2] (20,
              30), STRING sub = h[2:4] (3, premier caractere 101), h[5]
              (111), STRING vide (1, 0) ; erreur : affichage de 2 elements
              pour un tableau de 3 ; les 27 exemples restent analyses ;
              les essais des TODOs 8 a 14 donnent les memes valeurs
            Limites : l'affectation d'une STRING partage les caracteres
              (pas de copie) ; le stockage dynamique n'est pas libere
              (pas de FREE) ; tranches et affichages a plusieurs
              dimensions pas encore supportes ; les temporaires sont
              statiques (revu au TODO 16)
            Reste : (CHKIDX, BOUNDS, ALLOC : TODO 22) ; REP MOVSB, MOV
              d'octet, ADD memoire,registre au codeur du TODO 20

  TODO 16 - PROCEDURES (PROC) [IMPLEMENTE]
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
            Realise : texte de routine (UK_ROUTINE) ( parametres ) mode :
              unite, aussi sous la forme mode : unite sans parametres ;
              portee de procedure (SCK_PROC) contenant les parametres
              (SK_PARAM, [EBP + decalage]) ; PROC nom = routine (UK_PROCDECL,
              SK_PROC declare avant le corps pour la recursion) ; corps
              coerce vers le mode du resultat ; appel f(a, b) et f()
              (UK_CALL), arguments coerces vers les modes des parametres ;
              pile a l'entree : [EBP+8] lien statique, [EBP+12] adresse du
              resultat s'il est en memoire (structure, tableau, PROC), puis
              les parametres, le premier a l'adresse la plus basse ;
              appelee nettoie la pile (RET n) ; resultat dans EAX, ST(0) ou
              recopie a l'adresse fournie ; corps ecrits a part (DeferTab) ;
              prologue qui reserve le cadre (locales et temporaires, taille
              connue a la fin du corps) et le met a zero ; acces aux objets
              des cadres englobants par la chaine des liens statiques
              (cadre voulu dans EBX) ; les objets du niveau 0 restent
              statiques ; temporaires du generateur dans le cadre
              ([EBP - n]) des qu'on est dans une procedure, donc surs pour
              la recursion ; valeur de mode PROC = paire (entree, lien) de
              8 octets : identificateur de procedure, routine anonyme,
              variable ou parametre PROC, appel indirect CALL [paire] ;
              deprocedurage d'un PROC sans parametre (CO_DEPROC)
            Verifie : programmes d'essai executes (pt.a68, pt2.a68, cellules
              lues par le code de sortie) : double, add, sub3 (42, 42, 50),
              fact(5) = 120, fib(10) = 55, boucle FOR dans une procedure
              (55), REAL en parametre et resultat (4.5 et 2.5), STRUCT en
              parametre et resultat (swap, addp, mkchain recursif a
              resultat structure), REF INT en parametre (inc), procedures
              imbriquees sur trois niveaux avec acces aux variables
              englobantes (27 et 111), PROC (INT) INT en identite, en
              variable puis reaffectee (13, 24, 21), PROC en parametre
              avec procedure declaree ou routine anonyme (7 et 82), tableau
              en parametre (10), tableau local de taille dynamique (25),
              STRING en parametre et resultat, recursion avec boucle et
              temporaires (tri(3) = 14), PROC INT sans parametre appelee
              avec et sans parentheses (5, 5), BOOL et CHAR (1 et 65),
              variable globale lue et modifiee depuis une procedure (7 et
              9) ; erreurs : nombre d'arguments, mode d'argument, parametre
              en double, procedure en double, ':' manquant, routine
              attendue apres '=' ; les 27 exemples restent analyses ; les
              essais des TODOs 8 a 15 donnent les memes valeurs
            Limites : une routine qui renvoie une procedure liee a son
              propre cadre n'est pas sure (le cadre disparait) ; pas de
              GOTO hors d'une procedure ; pas de procedures mutuellement
              recursives (declaration avant usage) ; tableaux passes par
              descripteur (les elements ne sont pas recopies)
            Reste : le codeur du TODO 20 doit prendre en charge CALL
              indirect par memoire, RET n, MOV ESP,EBP et SUB ESP

  TODO 17 - DEFINITIONS D'OPERATEURS : OP ET PRIO [IMPLEMENTE]
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
            Realise : OP nom = texte de routine (ParseOpDecl, meme
              analyse que PROC avec ParseRoutine, symbole SK_OP declare
              avant le corps), nom bold ou symbole, un ou deux operandes
              (sinon erreur), plusieurs definitions separees par des
              virgules ; surcharge selon les modes des operandes
              (DBL pour INT et pour REAL, + pour des STRUCT) et
              redefinition d'un operateur du prelude dans une portee
              interne ; identification par coercitions fermes comme pour
              les operateurs du prelude ; PRIO avant ou apres l'OP ;
              dyadique sans PRIO : priorite 1 par defaut, signalee avec
              -w a la fin de l'analyse ; formule d'un operateur
              utilisateur (GenOpCall) : appel direct de la routine, mots
              de la pile et lien statique comme pour les procedures
              (GenCallDirect), operateurs declares dans une procedure
              inclus ; nom ASM _A68O_ nom _ indice
            Verifie : test_op.a68 execute (31, 14, 12, -42, 2, 32, 42) ;
              ot.a68 : priorites (1 ADDX 2 MYMUL 3 = 8, avec parentheses
              12, 2 LATE 3 ADDX 1 = 25), surcharge INT et REAL (42 et
              2,5), + de deux STRUCT (11 et 22), 3 + 4 intact (7),
              monadique sur STRUCT (25), appel de PROC dans un OP (26), OP
              dans une procedure avec acces a son parametre (22),
              associativite a gauche (3 MAX2 9 MAX2 5 = 9), OP recursif
              (120), OP rendant BOOL ; erreurs : trois operandes, OP en
              double, routine attendue, operande de mauvais mode (monadique
              et dyadique), nom d'operateur '=' ; les 27 exemples restent
              analyses ; les essais des TODOs 8 a 16 donnent les memes
              valeurs
            Limites : pas de forme OP (modes) mode nom = ... ; un operateur
              inconnu entre deux operandes reste une unite non analysee
              sans erreur (jusqu'au TODO 23)

  TODO 18 - MODES UNIS (UNION) ET CLAUSE DE CONFORMITE [IMPLEMENTE]
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
            Realise : les modes UNION, la coercition d'une valeur vers une
              union (etiquette = indice du mode de l'alternative, 0 pour
              EMPTY) et EMPTY existaient depuis les TODOs 4 et 9 ; ajout de
              la coercition d'une union vers une union plus large (meme
              etiquettes, recopie de l'objet) ; clause de conformite
              CASE x IN (mode nom) : unite, ... OUT serie ESAC
              (ParseConformity, UK_CONFORM et UK_CONFALT) : une portee
              SCK_CONFORM par alternative ou le nom est lie (identite) a la
              valeur extraite, nom facultatif ((INT) : unite), selecteur
              deference jusqu'a l'union (variable ou valeur), corps
              quelconques (BEGIN ... END, affectation, SKIP), OUT
              facultatif ; mode du resultat equilibre comme pour CASE ;
              controles : le selecteur est une UNION, chaque mode est une
              alternative de l'union, unites coercees vers le mode demande ;
              GenConform : comparaison de l'etiquette puis liaison du nom
              (LoadThrough et StoreValue du mode de l'alternative,
              structures comprises) ; fonctionne dans les procedures
            Verifie : test_union.a68 (52, 99, 1) ; un.a68 : INT, REAL, BOOL
              et CHAR dans des unions (14, 3,5, 30, 81), union vide qui
              prend la branche OUT (99), union avec STRUCT (56), copie d'une
              union (42), union vers union plus large (107), union en
              parametre (11 et 50), union locale dans une procedure (12),
              alternatives sans nom ; erreurs : mode qui n'est pas une
              alternative, selecteur qui n'est pas une union, branche de
              mode incorrect ; les 27 exemples restent analyses ; les
              essais des TODOs 8 a 17 donnent les memes valeurs
            Limites : pas de OUSE ni de forme abregee ( x | (INT i) : ... )
              pour la conformite ; les alternatives sont comparees par
              leur mode exact (pas de REF dans une alternative)

  TODO 19 - TRANSPUT, CLAUSES COLLATERALES ET PARALLELES [IMPLEMENTE]
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
            Realise : print((a, b, ...)) et print(a) (ParsePrintCall,
              UK_PRINT) : chaque element est coerce en force ferme vers
              INT, REAL, BOOL, CHAR, BITS ou STRING (erreur pour les autres
              modes) et newline / space sont des marqueurs ; GenPrint
              appelle une routine du runtime par element : WRITEINT (EAX),
              WRITEREAL (ST(0)), WRITEBOOL, WRITECHAR, WRITESTR (EAX =
              descripteur), NEWLINE, SPACE ; read((x, y)) et read(x) :
              noms de mode INT, REAL, CHAR ou STRING, READINT, READREAL,
              READCHAR, READSTR puis rangement a l'adresse du nom ;
              whole(n, largeur) : WHOLE (EAX = n, ECX = largeur, rend le
              descripteur d'une chaine nouvelle, largeur 0 = minimale,
              remplissage a gauche par des espaces) ; procedures standard
              sqrt, sin, cos, tan, arctan, ln, exp generees en ligne en
              x87 ; clause collaterale (u1, u2) en contexte vide :
              unites elaborees de gauche a droite ; PAR ( ... ) et PAR
              BEGIN ... END : clause fermee ou collaterale elaboree
              sequentiellement, avec avertissement (-w)
            Formats retenus (a realiser au TODO 22) : entier en decimal
              sans remplissage, signe - ; REAL en notation fixe, 6
              decimales au plus, zeros finaux supprimes mais une decimale
              au moins (4.5, 100.0, 0.666667) ; BOOL TRUE / FALSE ; CHAR
              et STRING tels quels ; fin de ligne CR LF ; read ignore les
              blancs avant un nombre, lit un caractere pour CHAR et le
              reste de la ligne pour STRING (256 caracteres au plus)
            Verifie : un runtime d'essai en assembleur (TESTS/AL68CW32/work,
              stubs.py, rt_code.inc), assemble avec ML et execute avec le
              chargeur PE, affiche pour hello.a68, transput.a68,
              test_transput.a68 et test_collateral.a68 les textes attendus
              (Hello, World!, TRUE, whole(-7,0) = -7, Algol 68, PAR: x=1
              y=2...) ; pr2.a68 : reels (3.14159, -0.5, 100.0, 0.666667),
              sqrt(16.0) = 4.0, arctan(1.0) * 4.0 = 3.141593, exp, ln, tan,
              whole avec largeur (42 sur 6, -5 sur 3, 123456 sur 2),
              (n := 1, x := 9.5), read de -42, 3.25, X et hello world ;
              erreurs : print d'une structure, read d'une valeur, PAR sans
              clause, element manquant ; les 27 exemples sont analyses
              sans aucune unite non analysee ; les essais des TODOs 8 a 18
              donnent les memes valeurs
            Limites : print n'affiche ni tableaux ni structures ni unions ;
              pas de formats (printf style), pas de fichiers ; read((x,
              newline)) ignore newline ; PAR n'a pas de parallelisme ;
              WRITEREAL est limite a 9.2E12 (voir TODO 22)

  TODO 20 - ENCODEUR BINAIRE x86-32 [IMPLEMENTE]
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
            Realise : section 12, reprise de l'encodeur d'AL60CW32 :
              EncodeInstr (ModRM, SIB, deplacement 8 ou 32 bits, cas
              [EBP], [ESP], [sym], [sym + index * echelle]), registres de
              8, 16 et 32 bits, MOV (dont MOV d'octet et MOV memoire,
              OFFSET), MOVZX, LEA, PUSH, POP, ALU (ADD OR AND SUB XOR CMP,
              forme memoire,registre comprise), IMUL, IDIV, DIV, CDQ, NEG,
              NOT, INC, DEC, TEST, SHL SHR SAR (par constante ou par CL),
              SETcc, Jcc et JMP, CALL et JMP indirects par memoire, RET et
              RET n, REP STOSD, REP MOVSD et REP MOVSB (nouveaux), x87
              (formes memoire de 4 et 8 octets, FILD et FISTP de 2, 4 et
              8 octets, formes ST(i), ST(0) et ST(0), ST(i) -- nouvelle --
              et instructions sans operande) ; EncodeData (zeros,
              chaines avec 0 final, entiers, reels, tables d'adresses avec
              relocations ABS32) ; EncodeCode : sauts courts d'abord puis
              agrandis tant qu'un deplacement deborde (relaxation),
              etiquettes code et donnees, relocations REL32 vers les
              cibles non definies, qui sont les imports (kernel32 et, tant
              que le runtime n'est pas emis, les routines _A68RT_) ;
              CheckFixups ; PhaseEncode affiche en -v la taille de .text et
              de .data, les relocations et les imports et ecrit en -d le
              listing hexadecimal <sortie>.lst ; BinCode, BinData, BinFix,
              BinLbl et BinImport sont destines aux ecrivains du TODO 21
            Verifie : TESTS/AL68CW32/chkenc.py decode avec objdump chaque
              instruction du listing hexadecimal (octets, mnemonique,
              operandes, cible des sauts et appels vers des etiquettes
              locales) ; 91 programmes (les 27 exemples et les programmes
              d'essai des TODOs 8 a 19) donnent 0 ecart ;
              TESTS/AL68CW32/chkall.sh refait la verification des 27
              exemples
            Reste : faits aux TODOs 21 et 22 (les instructions du runtime
              sont passees par chkenc avec les exemples)

  TODO 21 - ECRIVAINS PE (.EXE) ET COFF (.OBJ) [IMPLEMENTE]
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
            Realise : section 13, reprise des ecrivains d'AL60CW32 :
              WritePE (en-tete MZ avec souche DOS, signature PE, en-tete
              COFF, en-tete optionnel PE32 de 224 octets, base 0x00400000,
              alignements 4096 et 512, sous-systeme console, pile et tas
              de 1 Mo reserves, 3 sections .text, .data, .idata ; une
              souche JMP [IAT] par import ajoutee au code ; table
              d'importation de kernel32.dll avec ILT, IAT et noms avec
              indice ; relocations ABS32 et REL32 resolues a l'ecriture,
              point d'entree _A68P_Main, pas de table de relocation) ;
              WriteCOFF (en-tete, sections .text et .data avec leurs
              relocations DIR32 et REL32, table des symboles : sections
              avec entree auxiliaire, _A68P_Main externe defini, externes
              non definis, table des chaines) ; PhaseWrite : .EXE seul par
              defaut, .OBJ seul avec -obj, .ASM en plus avec -asm ; un
              symbole _A68... non defini est une erreur fatale pour l'.EXE
              ("routine du runtime absente", elle disparaitra avec le
              runtime du TODO 22), mais reste un externe du .OBJ ; sur
              erreur fatale les fichiers deja crees sont supprimes
            Corrige au passage : une unite qui commence par une
              parenthese et continue par un operateur ( (a + 1) /= 2 ) n'est
              plus prise pour une clause fermee
            Verifie : objdump -p / -h / -t / -r sur l'.EXE et le .OBJ
              (en-tetes, import de kernel32.dll, sections, symboles,
              relocations DIR32 et DISP32) ; TESTS/AL68CW32/chkpe.sh :
              work/exec.a68, un programme sans runtime dont les WHILE ne
              se terminent que si les resultats sont corrects (fact, fib,
              STRUCT, OP, REAL, UNION, FOR), s'execute avec le code 0 sous
              le chargeur PE, aussi bien en .EXE direct qu'en .OBJ lie avec
              lld-link (bibliotheque d'import kernel32 construite avec
              llvm-dlltool) ; avec un resultat faux le programme boucle
              (arrete par timeout) ; les 27 exemples donnent un .OBJ
              valide (chkall.sh, qui utilise maintenant -obj)
            Reste : les routines _A68RT_ : faites au TODO 22

  TODO 22 - RUNTIME ALGOL 68 POUR WIN32 [IMPLEMENTE]
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
            Realise : section 14 : RtText, 30 routines en assembleur
              (lignes de 70 caracteres au plus) ; mini-assembleur
              (RtAssembleLine : mnemoniques de OpName, operandes
              registre, immediat, OFFSET, ST(i), [base + index * echelle
              + depl], BYTE / WORD / DWORD / QWORD PTR, REP + instruction)
              qui produit des instructions internes ; RtLink, appele par
              PhaseCodegen apres le programme : marque les routines
              appelees (CALL ou JMP vers _A68RT_...) puis, de proche en
              proche, celles qu'elles appellent, et n'ajoute que celles-la
              dans DeferTab avec leurs cellules de donnees _A68D_...
              (RtData, creees a la demande) ; le listing .ASM est donc
              autonome et l'encodeur, les ecrivains PE et COFF traitent le
              runtime comme le reste ; seules GetStdHandle, WriteFile,
              ReadFile, ExitProcess, GetProcessHeap et HeapAlloc sont
              importees ; routines : PUT, FAIL, DIVZERO, NILREF, BOUNDS,
              CHKIDX, ALLOC (HeapAlloc avec HEAP_ZERO_MEMORY), NEWLINE,
              SPACE, WRITECHAR, WRITESTR, WRITEBOOL, DIGITS, WRITEINT,
              WRITEREAL, WHOLE, GETC, SKIPWS, READCHAR, READINT, READREAL,
              READSTR, STRCAT, STRCMP, POW, EXP2, RPOW, FLOOR, RTOI, RSIGN
              (le contrat registre par registre est dans le commentaire de
              la section) ; les erreurs d'execution (indice hors bornes,
              tableaux de dimensions differentes, reference NIL, division
              par zero, memoire insuffisante) ecrivent un message sur
              l'erreur standard et terminent par le code de sortie 1 ;
              pas de FREE : le tas n'est jamais libere
            Formats : entier en decimal sans remplissage, signe - ; reel en
              notation fixe, 6 decimales au plus, zeros finaux supprimes
              mais une decimale au moins (4.5, 100.0, 0.000001), valeur
              absolue inferieure a 9.2E12 ; BOOL TRUE / FALSE ; CHAR et
              STRING tels quels ; fin de ligne CR LF ; read ignore les
              blancs avant un nombre, lit un caractere pour CHAR et la
              ligne (256 caracteres au plus) pour STRING
            Corrige au passage : une clause fermee dont la valeur est une
              denotation ( (-1) ) ne produisait aucun code quand elle servait
              de valeur
            Verifie : les 26 exemples terminant (test_closed boucle par
              construction avec GOTO done) donnent des .EXE qui s'executent
              sous le chargeur PE de test avec les sorties attendues (les
              textes de procs.a68, math.a68, ops.a68, union.a68,
              control.a68... sont ceux que les exemples decrivent) ; le
              listing .ASM autonome assemble avec ML donne la meme sortie
              que l'.EXE direct pour les 26 ; TESTS/AL68CW32/chkrt.sh :
              work/rt1.a68 (reels, **, ENTIER, ROUND, SIGN, comparaisons
              de chaines, whole avec largeur), work/pr2.a68 (lecture de
              -42, 3.25, X et d'une ligne) et les quatre erreurs
              d'execution (message, pas de sortie apres l'erreur, code 1) ;
              chkall.sh (encodage) inclut maintenant le runtime
            Reste : les messages d'erreur du compilateur (TODO 23), le
              programme principal et les options (TODO 24), la validation
              complete (TODO 25)

  TODO 23 - GESTION DES ERREURS ET AVERTISSEMENTS [IMPLEMENTE]
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
            Realise : la plupart des diagnostics existaient deja (lexeur,
              parseur, modes) ; ajouts : toute unite que l'analyse ne
              reconnait pas est maintenant une erreur au jeton ou elle
              s'arrete ( INT x := 1 INT y := 2, 1 FOO 2, x(2),
              print((1 +)) ) au lieu d'etre ignoree en silence ; erreur
              lexicale "exposant incomplet" (1.5e) ; une seule erreur
              par position (plus de cascade "END attendu" puis
              "fermeture sans ouverture" au meme endroit) ; avertissements
              (option -w) : variable scalaire sans initialiseur lue avant
              sa premiere affectation dans l'ordre du texte (affectation,
              +:= et autres, read, argument d'un parametre REF), conversion
              implicite de INT en REAL, en plus de l'etiquette inutilisee,
              de la PRIO absente et de PAR ; PhaseReport : "Compilation
              echouee : n erreur(s), m avertissement(s)" ou, avec des
              avertissements ou -v, "Compilation terminee : 0 erreur, m
              avertissement(s)" ; apres une erreur seules les phases
              d'analyse tournent : aucun .EXE, .OBJ ni .ASM n'est ecrit, et
              les fichiers deja crees sont supprimes sur erreur fatale ou
              apres 30 erreurs
            Verifie : TESTS/AL68CW32/chkerr.sh : 44 programmes fautifs
              (errors.txt : erreurs lexicales, syntaxiques et de modes,
              avertissements) dont le premier diagnostic a la nature, la
              position et le message attendus, code de retour 1 (0 pour les
              avertissements), aucun fichier de sortie apres une erreur,
              rapport final ; fuzz.py : 3 400 mutations des exemples (jeton
              supprime, double, echange ou parasite) sans arret anormal ni
              boucle ; les 27 exemples ne produisent aucune erreur
            Limites : pas de recuperation fine apres une erreur de
              declaration (les erreurs en cascade sont possibles) ; la
              detection des variables non initialisees suit l'ordre du
              texte, pas le flot d'execution

  TODO 24 - PROGRAMME PRINCIPAL, MODES VERBEUX ET DEBOGAGE [IMPLEMENTE]
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
            Realise : la ligne de commande (ParseArgs : source .a68 ou
              .alg, extension ajoutee si absente, -o, -obj, -asm, -v, -d,
              -w, -w+, -w-, -h, codes 0 / 1 / 2) et le pipeline (Run,
              RunPhase) existaient depuis les TODOs 1 et 2 ; ce TODO les
              verifie et les complete : -v affiche la banniere, chaque
              phase, les nombres de lignes et de jetons, d'unites,
              d'instructions et de donnees, les routines du runtime
              emises, la taille de .text et de .data, les relocations, les
              imports de kernel32.dll, les fichiers produits et le rapport
              (la mention d'unites non analysees ne reste que s'il y en a) ;
              -d affiche les modes, les jetons (avec un titre), les portees
              de la table des symboles (avec un titre), l'arbre d'unites
              avant et apres les coercitions, les donnees, le code interne
              (runtime compris) et ecrit <sortie>.lst : listing
              hexadecimal du code puis carte des donnees (decalage, nom)
            Verifie : TESTS/AL68CW32/chkopt.sh : 17 combinaisons de
              fichiers produits (defaut : .exe seul ; -asm ; -obj : jamais
              de .exe ; -obj -asm ; -o avec et sans extension ; -d ; source
              sans extension ou en .alg ; -v), -o vers le source ou vers un
              .asm refuses, option inconnue (code 2), source introuvable
              (code 1), sans argument (code 2), -h (code 0), -w, -w+ et -w-
              et aucun fichier apres une erreur ; chkenc.py accepte
              toujours les .lst (carte des donnees en commentaire)

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

  TDoubleBits = Record
    Case Boolean Of
      False : (D : Double);
      True  : (Lo, Hi : LongInt);
  End;

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
    NoInit    : Boolean;       { variable scalaire sans initialiseur   }
    Warned    : Boolean;       { avertissement deja emis               }
    AsgLine   : Integer;       { premiere affectation (0 : aucune)     }
    AsgCol    : Integer;
    Heap      : Boolean;       { variable HEAP : la cellule contient
                                 l adresse de l objet                 }
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
    UK_NIL,        { NIL : mode MD_NIL                                 }
    UK_EMPTY,      { EMPTY : union vide                                }
    UK_COERCE,     { coercition : A = unite, IntVal = genre (CO_...)   }
    UK_IDENT,      { identificateur : Sym, Mode du symbole            }
    UK_SELECT,     { champ OF operande : A, IntVal = champ, C = decalage }
    UK_SLICE,      { A = operande, B = indices, IntVal = nombre, C =
                     nombre de tranches                                }
    UK_TRIM,       { tranche l:u : A = l, B = u (-1 si absent)         }
    UK_CALL,       { A = procedure, B = arguments, IntVal = nombre     }
    UK_CONSTRUCT,  { constructeur de structure : A = valeurs           }
    UK_CAST,       { conversion mode(unite) : A = unite                }
    UK_FORMULA,    { formule : Name, Sym = operateur, A, B (-1 si
                     monadique), IntVal = 1 ou 2                       }
    UK_DISPLAY,    { ( u1, u2, ... ) : A = elements, IntVal = nombre ;
                     mode donne par la coercition                      }
    UK_ASSIGN,     { affectation : A = nom, B = valeur, Mode = REF m   }
    UK_IDREL,      { a IS b, a ISNT b : Name, A, B, Mode BOOL          }
    UK_IF,         { A = condition, B = alors, C = sinon (serie, ou un
                     autre UK_IF pour ELIF), Scope                     }
    UK_CASE,       { A = selecteur, B = alternatives (IntVal), C = OUT
                     (serie, ou un autre UK_CASE pour OUSE)            }
    UK_PRINT,      { print((...)) ou read((...)) : Name, A = elements,
                     IntVal = nombre, Mode VOID                         }
    UK_CONFORM,    { CASE x IN (mode nom) : u ... : A = selecteur, B =
                     alternatives UK_CONFALT, IntVal = nombre, C = OUT,
                     Scope                                              }
    UK_CONFALT,    { alternative : Mode, Sym = nom lie (ou -1), A = unite,
                     IntVal = etiquette de l alternative dans l union   }
    UK_LOOP,       { A = FROM, B = BY, C = TO, D = WHILE, E = corps,
                     Sym = variable de controle, IntVal bit 0 = DOWNTO,
                     bit 1 = WHILE                                     }
    UK_INTDEN,     { denotation entiere : IntVal                       }
    UK_REALDEN,    { denotation reelle : RealVal                       }
    UK_BOOLDEN,    { TRUE ou FALSE : IntVal                            }
    UK_CHARDEN,    { denotation de caractere : IntVal = code           }
    UK_STRDEN,     { denotation de chaine : IntVal = indice LitTab     }
    UK_VARDECL,    { variable : Sym, Mode = mode de l objet, A =
                     initialiseur, B = bornes, C = dimensions          }
    UK_IDDECL,     { identite : Sym, Mode, A = initialiseur            }
    UK_MODEDECL,   { MODE : Sym                                        }
    UK_PRIODECL,   { PRIO : Sym, IntVal = priorite                     }
    UK_ROUTINE,    { texte de routine : A = corps, Scope, Sym = procedure
                     (si nommee), IntVal = octets retires par RET, C =
                     etiquette, D = 1 une fois le corps genere         }
    UK_PROCDECL,   { PROC nom = routine : Sym, A = UK_ROUTINE          }
    UK_DECL,       { declaration pas encore analysee (TODO 17)         }
    UK_OPAQUE      { unite pas encore analysee (TODOs 10 a 19)        }
  );

  TUnit = Record
    Kind    : TUnitKind;
    Mode    : Integer;     { mode de l unite (TODO 09)              }
    Line    : Integer;
    Col     : Integer;
    A, B, C : LongInt;     { enfants (-1 : aucun) ; UK_DECL et
                             UK_OPAQUE : jetons A a B - 1           }
    D, E    : LongInt;     { enfants supplementaires (UK_LOOP)      }
    Next    : LongInt;     { element suivant d une liste            }
    Sym     : Integer;     { symbole associe, -1 si aucun           }
    Scope   : Integer;     { portee de la clause ou du saut         }
    Name    : TName;
    IntVal  : LongInt;
    RealVal : Double;
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
  LastErrLine, LastErrCol : Integer;   { derniere erreur signalee    }
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

{ Vrai si un reel est infini ou invalide (exposant tout a 1) }
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
  { une seule erreur par position : evite les cascades }
  If (ErrorCount > 0) And (Line = LastErrLine) And (Col = LastErrCol) Then
    Exit;
  LastErrLine := Line;
  LastErrCol := Col;
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
  End
  Else If LexCur In ['E', 'e'] Then
  Begin
    { exposant sans chiffres : 1.5e }
    ErrorAt(LexLine, LexCol, 'exposant incomplet apres ' + T.Val);
    LexNextChar;
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
  If Opts.DebugMode Then WriteLn('Jetons (ligne : colonne, genre, texte) :');
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
  PreludeModes : Integer; { modes crees avant le programme (prelude)  }

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
Function ModeFieldOffset(M, I : Integer) : LongInt; Forward;

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
    MK_INT, MK_BOOL, MK_BITS, MK_NIL, MK_REF : Total := 4;
    MK_CHAR          : Total := 1;
    MK_REAL          : Total := 8;
    MK_PROC          : Total := 8;       { entree + lien statique }
    MK_ROW           : Total := ROW_DESC_BASE +
                                ROW_DESC_DIM * ModeTab[M].Dims;
    MK_STRUCT:
      Begin
        For K := 0 To ModeTab[M].Count - 1 Do
          Total := ModeFieldOffset(M, K) +
                   ModeSize(ModePoolM[ModeTab[M].First + K]);
        Total := (Total + 3) And -4;
      End;
    MK_UNION:
      Begin
        Max := 0;
        For K := 0 To ModeTab[M].Count - 1 Do
        Begin
          S := ModeSize(ModePoolM[ModeTab[M].First + K]);
          If S > Max Then Max := S;
        End;
        Total := (4 + Max + 3) And -4;   { etiquette + valeur }
      End;
  End;
  ModeTab[M].Size := Total;
  ModeSize := Total;
End;

{ alignement d un champ : 1 pour un CHAR, 4 sinon }
Function ModeAlign(M : Integer) : LongInt;
Begin
  If ModeKind(M) = MK_CHAR Then ModeAlign := 1 Else ModeAlign := 4;
End;

{ decalage d un champ dans une structure }
Function ModeFieldOffset(M, I : Integer) : LongInt;
Var
  K   : Integer;
  Off : LongInt;
  F   : Integer;
Begin
  M := ModeResolve(M);
  Off := 0;
  For K := 0 To I Do
  Begin
    F := ModePoolM[ModeTab[M].First + K];
    Off := (Off + ModeAlign(F) - 1) And -ModeAlign(F);
    If K < I Then Off := Off + ModeSize(F);
  End;
  ModeFieldOffset := Off;
End;

{ taille d un element de tableau }
Function ModeElemSize(Row : Integer) : LongInt;
Begin
  ModeElemSize := ModeSize(ModeTab[ModeResolve(Row)].Sub);
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
Procedure ModeDump(From : Integer);
Var
  I : Integer;
Begin
  WriteLn('Modes (', ModeCount - From, ') :');
  For I := From To ModeCount - 1 Do
  Begin
    Write(I:4, '  ', ModeName(I));
    If ModeTab[I].Kind = MK_FWD Then
    Begin
      If ModeTab[I].Sub <> 0 Then
        Write(' = ', ModeName(ModeTab[I].Sub));
    End
    Else
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
  SymTab[I].Heap      := False;
  SymTab[I].NoInit    := False;
  SymTab[I].Warned    := False;
  SymTab[I].AsgLine   := 0;
  SymTab[I].AsgCol    := 0;
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
Function SymOpExistsK(Const Name : TName; Arity : Integer;
                      UserOnly : Boolean) : Boolean;
Var
  S, I : Integer;
Begin
  SymOpExistsK := False;
  S := ScopeCur;
  While S >= 0 Do
  Begin
    I := ScopeTab[S].LastSym;
    While I >= 0 Do
    Begin
      If (SymTab[I].Kind = SK_OP) And (SymTab[I].Name = Name) And
         (OpArity(I) = Arity) And
         (Not UserOnly Or Not SymTab[I].Intrinsic) Then
        SymOpExistsK := True;
      I := SymTab[I].Prev;
    End;
    S := ScopeTab[S].Parent;
  End;
End;

Function SymOpExists(Const Name : TName; Arity : Integer) : Boolean;
Begin
  SymOpExists := SymOpExistsK(Name, Arity, False);
End;

{ La priorite de Name est-elle declaree (PRIO) dans la portee S ou une
  portee englobante ? }
Function PrioVisibleFrom(S : Integer; Const Name : TName) : Boolean;
Var
  I : Integer;
Begin
  PrioVisibleFrom := False;
  While S >= 0 Do
  Begin
    I := ScopeTab[S].LastSym;
    While I >= 0 Do
    Begin
      If (SymTab[I].Kind = SK_PRIO) And (SymTab[I].Name = Name) Then
        PrioVisibleFrom := True;
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
    OP_CALL, OP_RET, OP_REP_STOSD, OP_REP_MOVSD, OP_REP_MOVSB,
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
    OP_REP_MOVSB: OpName := 'REP MOVSB';
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
  DeclCount  : LongInt;       { declarations analysees                 }

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
  UnitTab[UnitCount].D     := -1;
  UnitTab[UnitCount].E     := -1;
  UnitTab[UnitCount].Next  := -1;
  UnitTab[UnitCount].Sym   := -1;
  UnitTab[UnitCount].Scope := ScopeCur;
  UnitTab[UnitCount].Name  := '';
  UnitTab[UnitCount].IntVal := 0;
  UnitTab[UnitCount].RealVal := 0;
  UnitNew := UnitCount;
  Inc(UnitCount);
End;

{ ---- Coercitions (TODO 09) ----
  Un noeud UK_COERCE enveloppe une unite : A = unite, IntVal = genre de
  coercition (CO_...), Mode = mode obtenu. Forces de contexte, de la
  plus faible a la plus forte :
    douce  : deprocedurage
    faible : deprocedurage et dereferencement qui laisse un nom (REF)
    meek   : deprocedurage et dereferencement
    ferme  : meek puis union (operandes de formules)
    forte  : ferme puis elargissement, enrobage en tableau et vidage }
Const
  CO_DEREF  = 1;      { REF m vers m                                  }
  CO_DEPROC = 2;      { PROC m (sans parametre) vers m : appel        }
  CO_WIDEN  = 3;      { INT vers REAL                                 }
  CO_ROW    = 4;      { m vers [] m (un element)                      }
  CO_UNITE  = 5;      { m vers UNION(... m ...) : B = etiquette       }
  CO_VOID   = 6;      { toute valeur vers VOID                        }

  FIT_NONE  = 0;
  FIT_UNITE = 1;
  FIT_WIDEN = 2;
  FIT_ROW   = 3;
  FIT_NIL   = 4;
  FIT_DEFLEX = 5;

Type
  TStrength = (STR_SOFT, STR_WEAK, STR_MEEK, STR_FIRM, STR_STRONG);

Var
  CoerceCount : LongInt;      { coercitions inserees (statistiques)   }

Function ModeIsProc0(M : Integer) : Boolean;
Begin
  M := ModeResolve(M);
  ModeIsProc0 := (ModeTab[M].Kind = MK_PROC) And (ModeTab[M].Count = 0);
End;

{ Alternative de l union U equivalente au mode M ; -1 si aucune }
Function ModeUnionAlt(U, M : Integer) : Integer;
Var
  I : Integer;
Begin
  ModeUnionAlt := -1;
  U := ModeResolve(U);
  If ModeTab[U].Kind <> MK_UNION Then Exit;
  For I := 0 To ModeTab[U].Count - 1 Do
    If ModeSame(ModePoolM[ModeTab[U].First + I], M) Then
      ModeUnionAlt := ModeResolve(ModePoolM[ModeTab[U].First + I]);
End;

{ Union M contenue dans l union Want (chaque alternative de M en est
  une de Want) }
Function ModeUnionSubset(M, Want : Integer) : Boolean;
Var
  I : Integer;
Begin
  M := ModeResolve(M);
  ModeUnionSubset := False;
  If ModeTab[M].Kind <> MK_UNION Then Exit;
  For I := 0 To ModeTab[M].Count - 1 Do
    If ModeUnionAlt(Want, ModePoolM[ModeTab[M].First + I]) < 0 Then Exit;
  ModeUnionSubset := True;
End;

{ Coercion finale (sans dereferencement ni deprocedurage) qui fait du
  mode M le mode Want, selon la force du contexte }
Function CoerceFit(M, Want : Integer; Str : TStrength) : Integer;
Var
  W, E : Integer;
Begin
  CoerceFit := FIT_NONE;
  M := ModeResolve(M);
  W := ModeResolve(Want);
  If (ModeTab[M].Kind = MK_NIL) And (ModeTab[W].Kind = MK_REF) Then
  Begin
    CoerceFit := FIT_NIL;
    Exit;
  End;
  If (Str >= STR_FIRM) And (ModeTab[W].Kind = MK_UNION) Then
  Begin
    If (ModeUnionAlt(W, M) >= 0) Or ModeUnionSubset(M, W) Then
    Begin
      CoerceFit := FIT_UNITE;
      Exit;
    End;
  End;
  { un tableau de meme element et meme dimension, flexible ou non,
    convient (deflexion) }
  If (ModeTab[M].Kind = MK_ROW) And (ModeTab[W].Kind = MK_ROW) And
     (ModeTab[M].Dims = ModeTab[W].Dims) And
     ModeSame(ModeTab[M].Sub, ModeTab[W].Sub) Then
  Begin
    CoerceFit := FIT_DEFLEX;
    Exit;
  End;
  If Str = STR_STRONG Then
  Begin
    If (ModeTab[M].Kind = MK_INT) And (ModeTab[W].Kind = MK_REAL) Then
    Begin
      CoerceFit := FIT_WIDEN;
      Exit;
    End;
    If (ModeTab[W].Kind = MK_ROW) And (ModeTab[W].Dims = 1) Then
    Begin
      E := ModeResolve(ModeTab[W].Sub);
      If ModeSame(M, E) Then CoerceFit := FIT_ROW;
    End;
  End;
End;

{ Le nom de variable U (identificateur) est affecte a la position
  (Line, Col) : premiere affectation connue }
Procedure MarkAssigned(U : LongInt; Line, Col : Integer);
Var
  S : Integer;
Begin
  If (U < 0) Or (UnitTab[U].Kind <> UK_IDENT) Then Exit;
  S := UnitTab[U].Sym;
  If (S < 0) Or (SymTab[S].Kind <> SK_VAR) Then Exit;
  If (SymTab[S].AsgLine = 0) Or (Line < SymTab[S].AsgLine) Or
     ((Line = SymTab[S].AsgLine) And (Col < SymTab[S].AsgCol)) Then
  Begin
    SymTab[S].AsgLine := Line;
    SymTab[S].AsgCol := Col;
  End;
End;

{ Lecture d'une variable scalaire sans initialiseur avant sa premiere
  affectation (dans l'ordre du texte) }
Procedure WarnUninit(U : LongInt);
Var
  S : Integer;
Begin
  If UnitTab[U].Kind <> UK_IDENT Then Exit;
  S := UnitTab[U].Sym;
  If (S < 0) Or (SymTab[S].Kind <> SK_VAR) Or Not SymTab[S].NoInit Or
     SymTab[S].Warned Then Exit;
  If (SymTab[S].AsgLine = 0) Or (UnitTab[U].Line < SymTab[S].AsgLine) Or
     ((UnitTab[U].Line = SymTab[S].AsgLine) And
      (UnitTab[U].Col < SymTab[S].AsgCol)) Then
  Begin
    SymTab[S].Warned := True;
    WarnAt(UnitTab[U].Line, UnitTab[U].Col, 'variable ' + SymTab[S].Name +
           ' lue avant toute affectation');
  End;
End;

Function CoerceWrap(U : LongInt; Kind : Integer; NewMode : Integer)
         : LongInt;
Var
  N : LongInt;
Begin
  If (Kind = CO_DEREF) And Opts.Warnings Then WarnUninit(U);
  If Kind = CO_WIDEN Then
    WarnAt(UnitTab[U].Line, UnitTab[U].Col,
           'conversion implicite de INT en REAL');
  N := UnitNew(UK_COERCE, UnitTab[U].Line, UnitTab[U].Col);
  UnitTab[N].A := U;
  UnitTab[N].IntVal := Kind;
  UnitTab[N].Mode := NewMode;
  Inc(CoerceCount);
  CoerceWrap := N;
End;

Function ModesSerial(First : LongInt; Want : Integer) : LongInt; Forward;
Function SerialMode(First : LongInt) : Integer; Forward;

{ Coerce l unite U vers le mode Want dans un contexte de force Str ;
  retourne l unite (eventuellement enveloppee). Une unite de mode
  inconnu (pas encore analysee) est laissee telle quelle. }
Function CoerceUnit(U : LongInt; Want : Integer; Str : TStrength)
         : LongInt;
Var
  M, W, Fit, Tag, Steps : Integer;
  UM                    : Integer;
  Cur, A, Prev, Nxt     : LongInt;
  Lit                   : TString;
  Done                  : Boolean;
Begin
  CoerceUnit := U;
  If (U < 0) Or (Want = MD_ERROR) Then Exit;
  W := ModeResolve(Want);
  Cur := U;
  { unites qui prennent le mode demande }
  Case UnitTab[U].Kind Of
    UK_SKIP, UK_GOTO:
      Begin
        UnitTab[U].Mode := Want;
        Exit;
      End;
    UK_EMPTY:
      Begin
        If ModeTab[W].Kind <> MK_UNION Then
          ErrorAt(UnitTab[U].Line, UnitTab[U].Col,
                  'EMPTY demande une UNION, pas ' + ModeName(Want));
        UnitTab[U].Mode := Want;
        Exit;
      End;
    UK_CLOSED:
      Begin
        UnitTab[U].A := ModesSerial(UnitTab[U].A, Want);
        UnitTab[U].Mode := Want;
        Exit;
      End;
    UK_IF:
      Begin
        UnitTab[U].A := ModesSerial(UnitTab[U].A, MD_BOOL);
        UnitTab[U].B := ModesSerial(UnitTab[U].B, Want);
        If UnitTab[U].C >= 0 Then
        Begin
          If UnitTab[UnitTab[U].C].Kind In [UK_IF, UK_CASE] Then
            UnitTab[U].C := CoerceUnit(UnitTab[U].C, Want, Str)
          Else
            UnitTab[U].C := ModesSerial(UnitTab[U].C, Want);
        End
        Else If W <> MD_VOID Then
          ErrorAt(UnitTab[U].Line, UnitTab[U].Col,
                  'IF sans ELSE utilise comme valeur de mode ' +
                  ModeName(Want));
        UnitTab[U].Mode := Want;
        Exit;
      End;
    UK_CASE:
      Begin
        UnitTab[U].A := ModesSerial(UnitTab[U].A, MD_INT);
        { alternatives : chaque unite est coercee vers le mode demande }
        Prev := -1;
        A := UnitTab[U].B;
        While A >= 0 Do
        Begin
          Nxt := UnitTab[A].Next;
          Cur := CoerceUnit(A, Want, STR_STRONG);
          UnitTab[Cur].Next := Nxt;
          If Prev < 0 Then UnitTab[U].B := Cur Else UnitTab[Prev].Next := Cur;
          Prev := Cur;
          A := Nxt;
        End;
        If UnitTab[U].C >= 0 Then
        Begin
          If UnitTab[UnitTab[U].C].Kind In [UK_IF, UK_CASE] Then
            UnitTab[U].C := CoerceUnit(UnitTab[U].C, Want, Str)
          Else
            UnitTab[U].C := ModesSerial(UnitTab[U].C, Want);
        End;
        UnitTab[U].Mode := Want;
        Exit;
      End;
    UK_CONFORM:
      Begin
        { selecteur : une union (apres dereferencement) ; chaque
          alternative doit en etre une ; les unites prennent le mode
          demande }
        UM := ModeDeref(SerialMode(UnitTab[U].A));
        If UM = MD_ERROR Then
          UM := MD_ERROR
        Else If ModeKind(UM) <> MK_UNION Then
        Begin
          ErrorAt(UnitTab[U].Line, UnitTab[U].Col,
                  'le selecteur d''une clause de conformite doit etre ' +
                  'une UNION, pas ' + ModeName(UM));
          UM := MD_ERROR;
        End
        Else
          UnitTab[U].A := ModesSerial(UnitTab[U].A, UM);
        A := UnitTab[U].B;
        While A >= 0 Do
        Begin
          If UM <> MD_ERROR Then
          Begin
            Tag := ModeUnionAlt(UM, UnitTab[A].Mode);
            If Tag < 0 Then
              ErrorAt(UnitTab[A].Line, UnitTab[A].Col,
                      ModeName(UnitTab[A].Mode) + ' n''est pas une ' +
                      'alternative de ' + ModeName(UM))
            Else
              UnitTab[A].IntVal := Tag;
          End;
          UnitTab[A].A := CoerceUnit(UnitTab[A].A, Want, STR_STRONG);
          A := UnitTab[A].Next;
        End;
        If UnitTab[U].C >= 0 Then
          UnitTab[U].C := ModesSerial(UnitTab[U].C, Want);
        UnitTab[U].Mode := Want;
        Exit;
      End;
    UK_DISPLAY:
      Begin
        If W = MD_VOID Then
        Begin
          { clause collaterale : unites elaborees de gauche a droite }
          Prev := -1;
          A := UnitTab[U].A;
          While A >= 0 Do
          Begin
            Nxt := UnitTab[A].Next;
            Cur := CoerceUnit(A, MD_VOID, STR_STRONG);
            UnitTab[Cur].Next := Nxt;
            If Prev < 0 Then UnitTab[U].A := Cur
            Else UnitTab[Prev].Next := Cur;
            Prev := Cur;
            A := Nxt;
          End;
        End
        Else If ModeTab[W].Kind = MK_ROW Then
        Begin
          If ModeTab[W].Dims <> 1 Then
            ErrorAt(UnitTab[U].Line, UnitTab[U].Col,
                    'affichage de tableau a plusieurs dimensions pas ' +
                    'encore supporte')
          Else
          Begin
            Prev := -1;
            A := UnitTab[U].A;
            While A >= 0 Do
            Begin
              Nxt := UnitTab[A].Next;
              Cur := CoerceUnit(A, ModeTab[W].Sub, STR_STRONG);
              UnitTab[Cur].Next := Nxt;
              If Prev < 0 Then UnitTab[U].A := Cur
              Else UnitTab[Prev].Next := Cur;
              Prev := Cur;
              A := Nxt;
            End;
          End;
        End
        Else If ModeTab[W].Kind = MK_STRUCT Then
        Begin
          If ModeTab[W].Count <> UnitTab[U].IntVal Then
            ErrorAt(UnitTab[U].Line, UnitTab[U].Col,
                    'affichage de ' + ModeName(Want) + ' avec ' +
                    ItoS(UnitTab[U].IntVal) + ' valeur(s) au lieu de ' +
                    ItoS(ModeTab[W].Count))
          Else
          Begin
            Prev := -1;
            A := UnitTab[U].A;
            Tag := 0;
            While A >= 0 Do
            Begin
              Nxt := UnitTab[A].Next;
              Cur := CoerceUnit(A, ModeFieldMode(W, Tag), STR_STRONG);
              UnitTab[Cur].Next := Nxt;
              If Prev < 0 Then UnitTab[U].A := Cur
              Else UnitTab[Prev].Next := Cur;
              Prev := Cur;
              A := Nxt;
              Inc(Tag);
            End;
          End;
        End
        Else
          ErrorAt(UnitTab[U].Line, UnitTab[U].Col,
                  'un affichage ne peut devenir ' + ModeName(Want));
        UnitTab[U].Mode := Want;
        Exit;
      End;
    UK_LOOP:
      Begin
        { bornes entieres, condition booleenne, corps vide }
        If UnitTab[U].A >= 0 Then
          UnitTab[U].A := CoerceUnit(UnitTab[U].A, MD_INT, STR_MEEK);
        If UnitTab[U].B >= 0 Then
          UnitTab[U].B := CoerceUnit(UnitTab[U].B, MD_INT, STR_MEEK);
        If UnitTab[U].C >= 0 Then
          UnitTab[U].C := CoerceUnit(UnitTab[U].C, MD_INT, STR_MEEK);
        If UnitTab[U].D >= 0 Then
          UnitTab[U].D := ModesSerial(UnitTab[U].D, MD_BOOL);
        UnitTab[U].E := ModesSerial(UnitTab[U].E, MD_VOID);
        UnitTab[U].Mode := MD_VOID;
      End;
  End;
  M := UnitTab[U].Mode;
  If M = MD_ERROR Then Exit;               { mode pas encore connu }
  M := ModeResolve(M);
  Done := False;
  Steps := 0;
  While Not Done Do
  Begin
    Inc(Steps);
    If Steps > 16 Then
    Begin
      ErrorAt(UnitTab[U].Line, UnitTab[U].Col, 'coercition trop longue');
      Done := True;
    End
    Else If W = MD_VOID Then
    Begin
      { vidage : un PROC sans parametre est d abord appele }
      If ModeIsProc0(M) And (Str = STR_STRONG) Then
      Begin
        M := ModeResolve(ModeTab[M].Sub);
        Cur := CoerceWrap(Cur, CO_DEPROC, M);
      End
      Else
      Begin
        If (Str = STR_STRONG) And (M <> MD_VOID) Then
          Cur := CoerceWrap(Cur, CO_VOID, MD_VOID);
        Done := True;
      End;
    End
    Else If ModeSame(M, W) Then
      Done := True
    Else
    Begin
      Fit := CoerceFit(M, W, Str);
      If Fit <> FIT_NONE Then
      Begin
        Case Fit Of
          FIT_NIL, FIT_DEFLEX:
            UnitTab[Cur].Mode := Want;
          FIT_UNITE:
            Begin
              If ModeTab[M].Kind = MK_UNION Then
                Tag := 0
              Else
                Tag := ModeUnionAlt(W, M);
              Cur := CoerceWrap(Cur, CO_UNITE, Want);
              UnitTab[Cur].B := Tag;
            End;
          FIT_WIDEN:
            If UnitTab[Cur].Kind = UK_INTDEN Then
            Begin
              { repliement : la denotation devient reelle }
              UnitTab[Cur].Kind := UK_REALDEN;
              UnitTab[Cur].RealVal := UnitTab[Cur].IntVal;
              UnitTab[Cur].Mode := MD_REAL;
            End
            Else
              Cur := CoerceWrap(Cur, CO_WIDEN, MD_REAL);
          FIT_ROW:
            If (UnitTab[Cur].Kind = UK_CHARDEN) And ModeIsString(W) Then
            Begin
              { repliement : un caractere devient une chaine }
              Lit := Chr(UnitTab[Cur].IntVal);
              If LitCount >= MAX_STRLIT Then
                FatalError('trop de denotations de chaines (max ' +
                           ItoS(MAX_STRLIT) + ')');
              LitTab[LitCount] := Lit;
              UnitTab[Cur].Kind := UK_STRDEN;
              UnitTab[Cur].IntVal := LitCount;
              UnitTab[Cur].Mode := MD_STRING;
              Inc(LitCount);
            End
            Else
              Cur := CoerceWrap(Cur, CO_ROW, Want);
        End;
        Done := True;
      End
      Else If (ModeTab[M].Kind = MK_REF) And (Str >= STR_WEAK) And
              ((Str >= STR_MEEK) Or
               (ModeKind(ModeTab[M].Sub) = MK_REF)) Then
      Begin
        M := ModeResolve(ModeTab[M].Sub);
        Cur := CoerceWrap(Cur, CO_DEREF, M);
      End
      Else If ModeIsProc0(M) Then
      Begin
        M := ModeResolve(ModeTab[M].Sub);
        Cur := CoerceWrap(Cur, CO_DEPROC, M);
      End
      Else
      Begin
        ErrorAt(UnitTab[U].Line, UnitTab[U].Col,
                'coercition impossible: ' + ModeName(UnitTab[U].Mode) +
                ' vers ' + ModeName(Want));
        UnitTab[Cur].Mode := Want;
        Done := True;
      End;
    End;
  End;
  CoerceUnit := Cur;
End;

{ Mode commun de deux branches (IF, CASE) : equilibrage }
Function ModeBalance(A, B : Integer) : Integer;
Var
  RA, RB : Integer;
Begin
  ModeBalance := MD_ERROR;
  RA := ModeDeref(A);
  RB := ModeDeref(B);
  If ModeSame(A, B) Then
    ModeBalance := ModeResolve(A)
  Else If (RA = MD_VOID) Or (RB = MD_VOID) Then
    ModeBalance := MD_VOID
  Else If ModeSame(RA, RB) Then
    ModeBalance := RA
  Else If ((RA = MD_INT) And (RB = MD_REAL)) Or
          ((RA = MD_REAL) And (RB = MD_INT)) Then
    ModeBalance := MD_REAL;
End;

{ Dereferencement jusqu a un nom (REF m avec m non REF) et deprocedurage :
  force faible, pour une selection x OF p ou un indice a[i] }
Function CoerceName(U : LongInt) : LongInt;
Var
  M : Integer;
  Cur : LongInt;
  Steps : Integer;
Begin
  Cur := U;
  If (U < 0) Or (UnitTab[U].Mode = MD_ERROR) Then
  Begin
    CoerceName := U;
    Exit;
  End;
  M := ModeResolve(UnitTab[U].Mode);
  Steps := 0;
  While Steps < 16 Do
  Begin
    Inc(Steps);
    If (ModeTab[M].Kind = MK_REF) And
       (ModeKind(ModeTab[M].Sub) = MK_REF) Then
    Begin
      M := ModeResolve(ModeTab[M].Sub);
      Cur := CoerceWrap(Cur, CO_DEREF, M);
    End
    Else If ModeIsProc0(M) Then
    Begin
      M := ModeResolve(ModeTab[M].Sub);
      Cur := CoerceWrap(Cur, CO_DEPROC, M);
    End
    Else
      Steps := 99;
  End;
  CoerceName := Cur;
End;

{ Deprocedurage seul (force douce) : membre gauche d'une affectation }
Function CoerceSoft(U : LongInt) : LongInt;
Var
  M     : Integer;
  Cur   : LongInt;
  Steps : Integer;
Begin
  Cur := U;
  If (U < 0) Or (UnitTab[U].Mode = MD_ERROR) Then
  Begin
    CoerceSoft := U;
    Exit;
  End;
  M := ModeResolve(UnitTab[U].Mode);
  Steps := 0;
  While (Steps < 16) And ModeIsProc0(M) Do
  Begin
    Inc(Steps);
    M := ModeResolve(ModeTab[M].Sub);
    Cur := CoerceWrap(Cur, CO_DEPROC, M);
  End;
  CoerceSoft := Cur;
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

Function AtOpSym(Const W : TName) : Boolean;
Begin
  AtOpSym := (TokTab[TokPos].Kind = TK_OP) And (TokTab[TokPos].Val = W);
End;

{ Un mode recursif sans REF a une taille infinie }
Procedure DeclareModeCheck(M : Integer; Const Name : TName;
                           Line, Col : Integer);
Begin
  ModeBadRec := False;
  ModeSize(M);
  If ModeBadRec Then
    ErrorAt(Line, Col, 'mode recursif sans REF: ' + Name);
  ModeBadRec := False;
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
  Else If T.Kind = TK_BOLD Then
    AtDeclStart := (N.Kind = TK_TAG) And Not SymOpExists(T.Val, 1)
  Else If T.Kind = TK_TAG Then
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

{ ---- Declarations (TODO 08) ---- }

{ Une unite ordinaire est enveloppee jusqu a une virgule, deux-points
  ou fermeture de profondeur nulle selon Stops (1 : virgule, 2 : deux-
  points) ; utilisee pour les initialiseurs et les bornes }
Function ParseOpaqueUntil(K : TUnitKind; Stops : Integer) : LongInt;
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
    Else If (Depth = 0) And (AtPunct(';') Or AtSerialEnd Or
            (((Stops And 1) <> 0) And AtPunct(',')) Or
            (((Stops And 2) <> 0) And AtPunct(':')) Or
            (((Stops And 4) <> 0) And (AtKw('BY') Or AtKw('TO') Or
             AtKw('DOWNTO') Or AtKw('WHILE')))) Then
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
  If TokPos = Start Then
  Begin
    ParseError('expression attendue');
    ParserAdvance;                          { progression garantie }
  End;
  UnitTab[U].A := Start;
  UnitTab[U].B := TokPos;
  Inc(OpaqueCount);
  ParseOpaqueUntil := U;
End;

{ Le jeton courant (hors signe) est-il une denotation ? }
Function AtDenotation : Boolean;
Begin
  AtDenotation := TokTab[TokPos].Kind In
                  [TK_INT, TK_REAL, TK_BOOL, TK_CHAR, TK_STRING];
End;

{ Le jeton suivant les K jetons courants termine-t-il une expression
  simple : virgule, point-virgule, deux-points ou fermeture ? }
Function TokEndsExpr(K : LongInt) : Boolean;
Var
  T : TToken;
Begin
  T := TokAt(K);
  TokEndsExpr := (T.Kind = TK_EOF) Or
                 ((T.Kind = TK_PUNCT) And ((T.Val = ',') Or
                  (T.Val = ';') Or (T.Val = ':') Or (T.Val = ')') Or
                  (T.Val = ']') Or (T.Val = '|') Or (T.Val = '|:'))) Or
                 ((T.Kind = TK_KEYWORD) And ((T.Val = 'END') Or
                  (T.Val = 'FI') Or (T.Val = 'ESAC') Or (T.Val = 'OD') Or
                  (T.Val = 'ELSE') Or (T.Val = 'ELIF') Or
                  (T.Val = 'OUT') Or (T.Val = 'OUSE') Or
                  (T.Val = 'THEN') Or (T.Val = 'IN') Or (T.Val = 'DO') Or
                  (T.Val = 'BY') Or (T.Val = 'TO') Or (T.Val = 'DOWNTO') Or
                  (T.Val = 'WHILE') Or (T.Val = 'FROM')));
End;

{ Denotation seule (eventuellement precedee de - ou +) : retourne son
  noeud ; -1 si l expression est plus complexe }
Function ParseDenotation : LongInt;
Var
  U     : LongInt;
  T     : TToken;
  Neg   : Boolean;
  Skip  : LongInt;
Begin
  ParseDenotation := -1;
  Neg := False;
  Skip := 0;
  T := TokTab[TokPos];
  If (T.Kind = TK_OP) And ((T.Val = '-') Or (T.Val = '+')) And
     (TokAt(1).Kind In [TK_INT, TK_REAL]) Then
  Begin
    Neg := T.Val = '-';
    Skip := 1;
    T := TokAt(1);
  End;
  If (T.Kind = TK_KEYWORD) And ((T.Val = 'NIL') Or (T.Val = 'EMPTY') Or
     (T.Val = 'SKIP')) And (Skip = 0) And TokEndsExpr(1) Then
  Begin
    If T.Val = 'NIL' Then
    Begin
      U := UnitNew(UK_NIL, T.Line, T.Col);
      UnitTab[U].Mode := MD_NIL;
    End
    Else If T.Val = 'EMPTY' Then
      U := UnitNew(UK_EMPTY, T.Line, T.Col)
    Else
      U := UnitNew(UK_SKIP, T.Line, T.Col);
    ParserAdvance;
    ParseDenotation := U;
    Exit;
  End;
  If Not (T.Kind In [TK_INT, TK_REAL, TK_BOOL, TK_CHAR, TK_STRING]) Then
    Exit;
  If Not TokEndsExpr(Skip + 1) Then Exit;
  Case T.Kind Of
    TK_INT   : U := UnitNew(UK_INTDEN, T.Line, T.Col);
    TK_REAL  : U := UnitNew(UK_REALDEN, T.Line, T.Col);
    TK_BOOL  : U := UnitNew(UK_BOOLDEN, T.Line, T.Col);
    TK_CHAR  : U := UnitNew(UK_CHARDEN, T.Line, T.Col);
  Else
    U := UnitNew(UK_STRDEN, T.Line, T.Col);
  End;
  UnitTab[U].IntVal := T.IntVal;
  UnitTab[U].RealVal := T.RealVal;
  If Neg Then
  Begin
    UnitTab[U].IntVal := -T.IntVal;
    UnitTab[U].RealVal := -T.RealVal;
  End;
  Case T.Kind Of
    TK_INT  : UnitTab[U].Mode := MD_INT;
    TK_REAL : UnitTab[U].Mode := MD_REAL;
    TK_BOOL : UnitTab[U].Mode := MD_BOOL;
    TK_CHAR : UnitTab[U].Mode := MD_CHAR;
  Else
    UnitTab[U].Mode := MD_STRING;
  End;
  If Skip = 1 Then ParserAdvance;
  ParserAdvance;
  ParseDenotation := U;
End;

Function ParseUnitX(Stops : Integer) : LongInt; Forward;

{ Initialiseur ou borne : unite simple, sinon enveloppe provisoire }
Function ParseInitUnit(Stops : Integer) : LongInt;
Begin
  ParseInitUnit := ParseUnitX(Stops);
End;

{ Le jeton courant commence-t-il un declarateur ? }
Function AtDeclarerStart : Boolean;
Var
  T : TToken;
Begin
  T := TokTab[TokPos];
  AtDeclarerStart := False;
  Case T.Kind Of
    TK_KEYWORD:
      AtDeclarerStart := (T.Val = 'INT') Or (T.Val = 'REAL') Or
                         (T.Val = 'BOOL') Or (T.Val = 'CHAR') Or
                         (T.Val = 'STRING') Or (T.Val = 'BITS') Or
                         (T.Val = 'VOID') Or (T.Val = 'REF') Or
                         (T.Val = 'STRUCT') Or (T.Val = 'UNION') Or
                         (T.Val = 'PROC') Or (T.Val = 'FLEX');
    TK_PUNCT : AtDeclarerStart := T.Val = '[';
    TK_BOLD, TK_TAG : AtDeclarerStart := SymFindMode(T.Val) >= 0;
  End;
End;

{ Declarateur : retourne le mode M. Pour un tableau de plus haut niveau
  declare avec des bornes, Bounds = liste des bornes (inferieure puis
  superieure pour chaque dimension, chainees par Next), Dims = nombre de
  dimensions. Retourne False apres une erreur (M = MD_ERROR). }
Function ParseDeclarer(Var M : Integer; Var Bounds : LongInt;
                       Var Dims : Integer; Nested : Boolean) : Boolean;
Var
  Elem, I, K, N, Dm  : Integer;
  B, Lo, Hi, LastB   : LongInt;
  InnerBounds        : LongInt;
  InnerDims          : Integer;
  Flex, Ok           : Boolean;
  L, C               : Integer;
  Name               : TName;
  FM                 : Array[0..MAX_FIELD - 1] Of Integer;
  FN                 : Array[0..MAX_FIELD - 1] Of TName;
  Res                : Integer;
  Sym                : Integer;
  Group              : Integer;
Begin
  M := MD_ERROR;
  Bounds := -1;
  Dims := 0;
  ParseDeclarer := False;
  L := TokTab[TokPos].Line;
  C := TokTab[TokPos].Col;
  Flex := False;
  If AtKw('FLEX') Then
  Begin
    Flex := True;
    ParserAdvance;
    If Not AtPunct('[') Then
    Begin
      ParseError('''['' attendu apres FLEX');
      Exit;
    End;
  End;
  Case TokTab[TokPos].Kind Of
    TK_KEYWORD:
      Begin
        If AtKw('INT') Then M := MD_INT
        Else If AtKw('REAL') Then M := MD_REAL
        Else If AtKw('BOOL') Then M := MD_BOOL
        Else If AtKw('CHAR') Then M := MD_CHAR
        Else If AtKw('STRING') Then M := MD_STRING
        Else If AtKw('BITS') Then M := MD_BITS
        Else If AtKw('VOID') Then M := MD_VOID;
        If M <> MD_ERROR Then
        Begin
          ParserAdvance;
          ParseDeclarer := True;
          Exit;
        End;
        If AtKw('REF') Then
        Begin
          ParserAdvance;
          Ok := ParseDeclarer(Elem, InnerBounds, InnerDims, True);
          If InnerDims > 0 Then
            ErrorAt(L, C, 'bornes interdites apres REF');
          M := ModeRef(Elem);
          ParseDeclarer := Ok;
          Exit;
        End;
        If AtKw('STRUCT') Then
        Begin
          ParserAdvance;
          If Not AtPunct('(') Then
          Begin
            ParseError('''('' attendu apres STRUCT');
            Exit;
          End;
          ParserAdvance;
          N := 0;
          Ok := True;
          If AtPunct(')') Then
          Begin
            ErrorAt(L, C, 'STRUCT sans champ');
            ParserAdvance;
            M := MD_ERROR;
            Exit;
          End;
          Repeat
            Ok := ParseDeclarer(Elem, InnerBounds, InnerDims, True) And Ok;
            If InnerDims > 0 Then
              ErrorAt(L, C, 'bornes interdites dans un champ');
            { un ou plusieurs noms de champs pour ce declarateur }
            Repeat
              If TokTab[TokPos].Kind <> TK_TAG Then
              Begin
                ParseError('nom de champ attendu');
                Ok := False;
              End
              Else
              Begin
                If N < MAX_FIELD Then
                Begin
                  FM[N] := Elem;
                  FN[N] := TokTab[TokPos].Val;
                  Inc(N);
                End
                Else
                  ErrorAt(L, C, 'trop de champs (max ' +
                          ItoS(MAX_FIELD) + ')');
                ParserAdvance;
              End;
              Group := 0;
              If AtPunct(',') And (TokAt(1).Kind = TK_TAG) And
                 (SymFindMode(TokAt(1).Val) < 0) Then
              Begin
                ParserAdvance;
                Group := 1;
              End;
            Until (Group = 0) Or AtEOF;
            Group := 0;
            If AtPunct(',') Then
            Begin
              ParserAdvance;
              Group := 1;
            End;
          Until (Group = 0) Or AtEOF Or (Not Ok);
          If AtPunct(')') Then
            ParserAdvance
          Else
          Begin
            ParseError(''')'' attendu pour fermer STRUCT');
            Ok := False;
          End;
          ModeTmpReset;
          For I := 0 To N - 1 Do
            ModeTmpAdd(FN[I], FM[I], L, C);
          M := ModeStructTmp(L, C);
          ParseDeclarer := Ok;
          Exit;
        End;
        If AtKw('UNION') Then
        Begin
          ParserAdvance;
          If Not AtPunct('(') Then
          Begin
            ParseError('''('' attendu apres UNION');
            Exit;
          End;
          ParserAdvance;
          N := 0;
          Ok := True;
          Repeat
            Ok := ParseDeclarer(Elem, InnerBounds, InnerDims, True) And Ok;
            If N < MAX_FIELD Then
            Begin
              FM[N] := Elem;
              Inc(N);
            End;
            Group := 0;
            If AtPunct(',') Then
            Begin
              ParserAdvance;
              Group := 1;
            End;
          Until (Group = 0) Or AtEOF;
          If AtPunct(')') Then
            ParserAdvance
          Else
          Begin
            ParseError(''')'' attendu pour fermer UNION');
            Ok := False;
          End;
          ModeTmpReset;
          For I := 0 To N - 1 Do
            ModeTmpAdd('', FM[I], L, C);
          M := ModeUnionTmp(L, C);
          ParseDeclarer := Ok;
          Exit;
        End;
        If AtKw('PROC') Then
        Begin
          ParserAdvance;
          N := 0;
          Ok := True;
          If AtPunct('(') Then
          Begin
            ParserAdvance;
            Repeat
              Ok := ParseDeclarer(Elem, InnerBounds, InnerDims, True) And Ok;
              If N < MAX_FIELD Then
              Begin
                FM[N] := Elem;
                Inc(N);
              End;
              Group := 0;
              If AtPunct(',') Then
              Begin
                ParserAdvance;
                Group := 1;
              End;
            Until (Group = 0) Or AtEOF;
            If AtPunct(')') Then
              ParserAdvance
            Else
            Begin
              ParseError(''')'' attendu pour fermer la liste de modes');
              Ok := False;
            End;
          End;
          Ok := ParseDeclarer(Res, InnerBounds, InnerDims, True) And Ok;
          ModeTmpReset;
          For I := 0 To N - 1 Do
            ModeTmpAdd('', FM[I], L, C);
          M := ModeProcTmp(Res);
          ParseDeclarer := Ok;
          Exit;
        End;
        ParseError('declarateur attendu');
        Exit;
      End;
    TK_PUNCT:
      If AtPunct('[') Then
      Begin
        ParserAdvance;
        Dm := 1;
        LastB := -1;
        If AtPunct(']') Or AtPunct(',') Then
        Begin
          { tableau sans bornes : [] ou [,] }
          While AtPunct(',') Do
          Begin
            Inc(Dm);
            ParserAdvance;
          End;
        End
        Else
        Begin
          Dm := 0;
          Repeat
            Inc(Dm);
            Lo := ParseInitUnit(2);
            If AtPunct(':') Then
              ParserAdvance
            Else
              ParseError(''':'' attendu entre les bornes');
            Hi := ParseInitUnit(1);
            If Bounds < 0 Then Bounds := Lo Else UnitTab[LastB].Next := Lo;
            UnitTab[Lo].Next := Hi;
            LastB := Hi;
            K := 0;
            If AtPunct(',') Then
            Begin
              ParserAdvance;
              K := 1;
            End;
          Until (K = 0) Or AtEOF;
        End;
        If AtPunct(']') Then
          ParserAdvance
        Else
        Begin
          ParseError(''']'' attendu');
          Exit;
        End;
        Ok := ParseDeclarer(Elem, InnerBounds, InnerDims, True);
        If InnerDims > 0 Then
          ErrorAt(L, C, 'bornes interieures non supportees');
        If Nested And (Bounds >= 0) Then
        Begin
          ErrorAt(L, C, 'bornes interdites ici');
          Bounds := -1;
        End;
        Dims := Dm;
        If Bounds < 0 Then Dims := 0;
        M := ModeRow(Elem, Dm, Flex);
        ParseDeclarer := Ok;
        Exit;
      End
      Else
      Begin
        ParseError('declarateur attendu');
        Exit;
      End;
    TK_BOLD, TK_TAG:
      Begin
        Name := TokTab[TokPos].Val;
        Sym := SymFindMode(Name);
        If Sym < 0 Then
        Begin
          ErrorAt(L, C, 'mode inconnu: ' + Name);
          ParserAdvance;
          Exit;
        End;
        M := SymTab[Sym].Mode;
        ParserAdvance;
        ParseDeclarer := True;
        Exit;
      End;
  Else
    ParseError('declarateur attendu');
  End;
End;

{ Reserve la place d un objet : cellule du segment de donnees au niveau
  0, sinon place dans le cadre }
Procedure DeclareStorage(S : Integer; M : Integer; Line, Col : Integer);
Var
  Size : LongInt;
Begin
  ModeBadRec := False;
  Size := ModeSize(M);
  If ModeBadRec Then
  Begin
    ErrorAt(Line, Col, 'mode recursif sans REF: ' + ModeName(M));
    ModeBadRec := False;
  End;
  If Size < 4 Then Size := 4;
  SymAllocate(S, Size);
  If SymTab[S].Storage = SC_STATIC Then
    DataAddZero(Intern(SymTab[S].AsmName), Size);
End;

{ MODE nom = declarateur, nom = declarateur, ... }
Function ParseModeDecl : LongInt;
Var
  First, Last, U : LongInt;
  Name           : TName;
  Fwd, S, M, Dm  : Integer;
  Bnd            : LongInt;
  L, C           : Integer;
  More           : Boolean;
Begin
  First := -1;
  Last := -1;
  ParserAdvance;                       { MODE }
  Repeat
    More := False;
    L := TokTab[TokPos].Line;
    C := TokTab[TokPos].Col;
    If Not (TokTab[TokPos].Kind In [TK_BOLD, TK_TAG]) Then
    Begin
      ParseError('nom de mode attendu');
      ParseOpaqueUntil(UK_OPAQUE, 0);
    End
    Else
    Begin
      Name := TokTab[TokPos].Val;
      U := UnitNew(UK_MODEDECL, L, C);
      UnitTab[U].Name := Name;
      Fwd := ModeFwd(Name);
      S := SymDeclare(Name, SK_MODE, Fwd, L, C);
      ParserAdvance;
      If AtOpSym('=') Then
        ParserAdvance
      Else
        ParseError('''='' attendu apres le nom de mode');
      ParseDeclarer(M, Bnd, Dm, False);
      If Dm > 0 Then ErrorAt(L, C, 'bornes interdites dans MODE');
      ModeDefine(Fwd, M);
      { un alias direct reste l alias ; seules les structures et les
        unions gardent leur nom (modes recursifs) }
      If Not (ModeKind(M) In [MK_STRUCT, MK_UNION]) Then
        SymTab[S].Mode := M;
      DeclareModeCheck(Fwd, Name, L, C);
      UnitTab[U].Sym := S;
      UnitTab[U].Mode := SymTab[S].Mode;
      If First < 0 Then First := U Else UnitTab[Last].Next := U;
      Last := U;
      Inc(DeclCount);
      If AtPunct(',') Then
      Begin
        ParserAdvance;
        More := True;
      End;
    End;
  Until (Not More) Or AtEOF;
  ParseModeDecl := First;
End;

{ PRIO nom = priorite, nom = priorite, ... (de 1 a 9) }
Function ParsePrioDecl : LongInt;
Var
  First, Last, U : LongInt;
  Name           : TName;
  S, P           : Integer;
  L, C           : Integer;
  More           : Boolean;
Begin
  First := -1;
  Last := -1;
  ParserAdvance;                       { PRIO }
  Repeat
    More := False;
    L := TokTab[TokPos].Line;
    C := TokTab[TokPos].Col;
    If Not (TokTab[TokPos].Kind In [TK_BOLD, TK_OP]) Then
    Begin
      ParseError('nom d''operateur attendu');
      ParseOpaqueUntil(UK_OPAQUE, 0);
    End
    Else
    Begin
      Name := TokTab[TokPos].Val;
      ParserAdvance;
      If AtOpSym('=') Then
        ParserAdvance
      Else
        ParseError('''='' attendu apres le nom de l''operateur');
      P := 0;
      If TokTab[TokPos].Kind = TK_INT Then
      Begin
        P := TokTab[TokPos].IntVal;
        ParserAdvance;
      End
      Else
        ParseError('priorite (entier de 1 a 9) attendue');
      If (P < 1) Or (P > 9) Then
      Begin
        If P <> 0 Then
          ErrorAt(L, C, 'priorite hors de 1 a 9: ' + ItoS(P));
        P := 5;
      End;
      U := UnitNew(UK_PRIODECL, L, C);
      UnitTab[U].Name := Name;
      S := SymDeclare(Name, SK_PRIO, MD_VOID, L, C);
      SymTab[S].Offset := P;
      UnitTab[U].Sym := S;
      UnitTab[U].IntVal := P;
      If First < 0 Then First := U Else UnitTab[Last].Next := U;
      Last := U;
      Inc(DeclCount);
      If AtPunct(',') Then
      Begin
        ParserAdvance;
        More := True;
      End;
    End;
  Until (Not More) Or AtEOF;
  ParsePrioDecl := First;
End;

{ LOC ou HEAP, declarateur, nom, = ou := et initialiseur, repetes
  avec des virgules : declarations d identite (=) et de variable (:=
  ou sans initialiseur) }
Function ParseObjectDecl : LongInt;
Var
  First, Last, U, Init : LongInt;
  Bounds               : LongInt;
  M                    : Integer;
  Dims                 : Integer;
  Name                 : TName;
  S, L, C              : Integer;
  Heap, More, IsVar    : Boolean;
  Ok                   : Boolean;
Begin
  First := -1;
  Last := -1;
  Heap := False;
  If AtKw('HEAP') Then
  Begin
    Heap := True;
    ParserAdvance;
  End
  Else If AtKw('LOC') Then
    ParserAdvance;
  Ok := ParseDeclarer(M, Bounds, Dims, False);
  If Not Ok Then
  Begin
    ParseOpaqueUntil(UK_OPAQUE, 0);
    ParseObjectDecl := -1;
    Exit;
  End;
  Repeat
    More := False;
    L := TokTab[TokPos].Line;
    C := TokTab[TokPos].Col;
    If TokTab[TokPos].Kind <> TK_TAG Then
    Begin
      ParseError('identificateur attendu dans la declaration');
      ParseOpaqueUntil(UK_OPAQUE, 0);
    End
    Else
    Begin
      Name := TokTab[TokPos].Val;
      ParserAdvance;
      Init := -1;
      IsVar := True;
      If AtOpSym('=') Then
      Begin
        IsVar := False;
        ParserAdvance;
        Init := ParseInitUnit(1);
      End
      Else If AtOpSym(':=') Then
      Begin
        ParserAdvance;
        Init := ParseInitUnit(1);
      End;
      If IsVar Then
      Begin
        U := UnitNew(UK_VARDECL, L, C);
        S := SymDeclare(Name, SK_VAR, ModeRef(M), L, C);
      End
      Else
      Begin
        U := UnitNew(UK_IDDECL, L, C);
        S := SymDeclare(Name, SK_IDENT, M, L, C);
      End;
      UnitTab[U].Name := Name;
      UnitTab[U].Sym := S;
      UnitTab[U].Mode := M;
      UnitTab[U].A := Init;
      UnitTab[U].B := Bounds;
      UnitTab[U].C := Dims;
      If Heap Then UnitTab[U].IntVal := 1;
      If IsVar And (Init < 0) And (Dims = 0) And Not Heap And
         (ModeKind(M) In [MK_INT, MK_REAL, MK_BOOL, MK_CHAR]) Then
        SymTab[S].NoInit := True;
      If Heap And IsVar Then
      Begin
        { variable HEAP : la cellule contient l adresse de l objet }
        SymTab[S].Heap := True;
        DeclareStorage(S, ModeRef(M), L, C);
      End
      Else
        DeclareStorage(S, M, L, C);
      If First < 0 Then First := U Else UnitTab[Last].Next := U;
      Last := U;
      Inc(DeclCount);
      If AtPunct(',') Then
      Begin
        ParserAdvance;
        More := True;
      End;
    End;
  Until (Not More) Or AtEOF;
  ParseObjectDecl := First;
End;

Function ParseProcDecl : LongInt; Forward;
Function ParseOpDecl : LongInt; Forward;

{ Declaration : MODE, PRIO, PROC nom = routine, OP nom = routine, objet
  (identite ou variable) }
Function ParseDeclaration : LongInt;
Begin
  If AtKw('MODE') Then
    ParseDeclaration := ParseModeDecl
  Else If AtKw('PRIO') Then
    ParseDeclaration := ParsePrioDecl
  Else If AtKw('PROC') And (TokAt(1).Kind = TK_TAG) And
          (TokAt(2).Kind = TK_OP) Then
    ParseDeclaration := ParseProcDecl
  Else If AtKw('OP') Then
    ParseDeclaration := ParseOpDecl
  Else
    ParseDeclaration := ParseObjectDecl;
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

{ ---- Unites primaires (TODO 10) ---- }

{ Mode naturel d une unite : celui de son dernier element pour une
  clause fermee, le mode memorise sinon }
Function NatMode(U : LongInt) : Integer;
Var
  P, Last : LongInt;
Begin
  NatMode := MD_ERROR;
  If U < 0 Then Exit;
  If UnitTab[U].Kind = UK_CLOSED Then
  Begin
    Last := -1;
    P := UnitTab[U].A;
    While P >= 0 Do
    Begin
      If Not (UnitTab[P].Kind In [UK_LABELDEF, UK_VARDECL, UK_IDDECL,
                                  UK_MODEDECL, UK_PRIODECL,
                                  UK_PROCDECL, UK_DECL]) Then
        Last := P;
      P := UnitTab[P].Next;
    End;
    If Last >= 0 Then NatMode := NatMode(Last);
  End
  Else
    NatMode := UnitTab[U].Mode;
End;

{ Indice du jeton qui suit la construction ouverte au jeton courant
  (BEGIN, parenthese ou crochet) ; TokCount - 1 si elle n est pas fermee }
Function TokAfterClose : LongInt;
Var
  K     : LongInt;
  Depth : Integer;
Begin
  Depth := 0;
  K := TokPos;
  While K < TokCount - 1 Do
  Begin
    If TokDepth(TokTab[K]) > 0 Then
      Inc(Depth)
    Else If TokDepth(TokTab[K]) < 0 Then
      Dec(Depth);
    Inc(K);
    If Depth <= 0 Then
    Begin
      TokAfterClose := K;
      Exit;
    End;
  End;
  TokAfterClose := TokCount - 1;
End;

{ Le jeton d indice K (absolu) termine-t-il une expression ? }
Function TokEndsExprAbs(K : LongInt) : Boolean;
Begin
  TokEndsExprAbs := TokEndsExpr(K - TokPos);
End;

{ Denotation d un seul jeton (sans signe) }
Function DenotationNode : LongInt;
Var
  U : LongInt;
  T : TToken;
Begin
  T := TokTab[TokPos];
  Case T.Kind Of
    TK_INT  : U := UnitNew(UK_INTDEN, T.Line, T.Col);
    TK_REAL : U := UnitNew(UK_REALDEN, T.Line, T.Col);
    TK_BOOL : U := UnitNew(UK_BOOLDEN, T.Line, T.Col);
    TK_CHAR : U := UnitNew(UK_CHARDEN, T.Line, T.Col);
  Else
    U := UnitNew(UK_STRDEN, T.Line, T.Col);
  End;
  UnitTab[U].IntVal := T.IntVal;
  UnitTab[U].RealVal := T.RealVal;
  Case T.Kind Of
    TK_INT  : UnitTab[U].Mode := MD_INT;
    TK_REAL : UnitTab[U].Mode := MD_REAL;
    TK_BOOL : UnitTab[U].Mode := MD_BOOL;
    TK_CHAR : UnitTab[U].Mode := MD_CHAR;
  Else
    UnitTab[U].Mode := MD_STRING;
  End;
  ParserAdvance;
  DenotationNode := U;
End;

Function ParsePrimary : LongInt; Forward;
Function ClauseFollowOk(K : LongInt) : Boolean; Forward;

{ ---- Textes de routine et procedures (TODO 16) ---- }

{ Le jeton d'indice K commence-t-il un declarateur ? }
Function DeclarerStartsAt(K : LongInt) : Boolean;
Var
  Save : LongInt;
Begin
  Save := TokPos;
  TokPos := K;
  DeclarerStartsAt := AtDeclarerStart;
  TokPos := Save;
End;

{ La parenthese courante ouvre-t-elle les parametres d'un texte de
  routine ( (INT x) INT : ... ) ? Un declarateur ou ) suit la
  parenthese et un declarateur suit la parenthese fermante. }
Function ParenIsRoutine : Boolean;
Var
  After : LongInt;
Begin
  ParenIsRoutine := False;
  If Not AtPunct('(') Then Exit;
  If Not ((TokAt(1).Kind = TK_PUNCT) And (TokAt(1).Val = ')')) And
     Not DeclarerStartsAt(TokPos + 1) Then Exit;
  After := TokAfterClose;
  If After >= TokCount - 1 Then Exit;
  ParenIsRoutine := DeclarerStartsAt(After);
End;

{ Texte de routine sans parametres : mode de base suivi de deux-points }
Function AtBareRoutine : Boolean;
Begin
  AtBareRoutine := (TokTab[TokPos].Kind = TK_KEYWORD) And
                   ((TokTab[TokPos].Val = 'INT') Or
                    (TokTab[TokPos].Val = 'REAL') Or
                    (TokTab[TokPos].Val = 'BOOL') Or
                    (TokTab[TokPos].Val = 'CHAR') Or
                    (TokTab[TokPos].Val = 'STRING') Or
                    (TokTab[TokPos].Val = 'BITS') Or
                    (TokTab[TokPos].Val = 'VOID')) And
                   (TokAt(1).Kind = TK_PUNCT) And (TokAt(1).Val = ':');
End;

Function AtRoutineStart : Boolean;
Begin
  AtRoutineStart := ParenIsRoutine Or AtBareRoutine;
End;

{ Texte de routine : ( parametres ) mode : unite. Une portee de
  procedure contient les parametres (SK_PARAM, [EBP + decalage]) ; si
  PName n'est pas vide, la procedure est declaree sous ce nom avant son
  corps (appels recursifs). Disposition de la pile a l'entree : [EBP+8]
  lien statique, puis [EBP+12] l'adresse du resultat s'il est
  structure, puis les parametres (le premier a l'adresse la plus
  basse). }
Function ParseRoutine(Const PName : TName; NL, NC : Integer;
                      K : TSymKind) : LongInt;
Var
  U, Body, Bnd  : LongInt;
  L, C          : Integer;
  N, I, Dm      : Integer;
  Elem, Res, M  : Integer;
  Sc, S         : Integer;
  Off, Sz       : LongInt;
  Ok, Grp, More : Boolean;
  Agg           : Boolean;
  PM            : Array[0..MAX_FIELD - 1] Of Integer;
  PN            : Array[0..MAX_FIELD - 1] Of TName;
  PL, PC        : Array[0..MAX_FIELD - 1] Of Integer;
Begin
  L := TokTab[TokPos].Line;
  C := TokTab[TokPos].Col;
  U := UnitNew(UK_ROUTINE, L, C);
  UnitTab[U].Sym := -1;
  UnitTab[U].C := -1;
  UnitTab[U].D := 0;
  UnitTab[U].Mode := MD_ERROR;
  N := 0;
  Ok := True;
  If AtPunct('(') Then
  Begin
    ParserAdvance;
    If AtPunct(')') Then
      ParserAdvance
    Else
    Begin
      Repeat
        More := False;
        Ok := ParseDeclarer(Elem, Bnd, Dm, True) And Ok;
        If Dm > 0 Then
          ErrorAt(L, C, 'bornes interdites dans un parametre formel');
        Repeat
          Grp := False;
          If TokTab[TokPos].Kind <> TK_TAG Then
          Begin
            ParseError('nom de parametre attendu');
            Ok := False;
          End
          Else
          Begin
            If N < MAX_FIELD Then
            Begin
              PM[N] := Elem;
              PN[N] := TokTab[TokPos].Val;
              PL[N] := TokTab[TokPos].Line;
              PC[N] := TokTab[TokPos].Col;
              Inc(N);
            End
            Else
              ErrorAt(L, C, 'trop de parametres (max ' +
                      ItoS(MAX_FIELD) + ')');
            ParserAdvance;
            If AtPunct(',') And (TokAt(1).Kind = TK_TAG) And
               (SymFindMode(TokAt(1).Val) < 0) Then
            Begin
              ParserAdvance;
              Grp := True;
            End;
          End;
        Until (Not Grp) Or AtEOF;
        If Ok And AtPunct(',') Then
        Begin
          ParserAdvance;
          More := True;
        End;
      Until (Not More) Or AtEOF;
      If AtPunct(')') Then
        ParserAdvance
      Else
      Begin
        ParseError(''')'' attendu pour fermer les parametres');
        Ok := False;
      End;
    End;
  End;
  Res := MD_ERROR;
  If Ok Then Ok := ParseDeclarer(Res, Bnd, Dm, True);
  If Ok Then
  Begin
    If AtPunct(':') Then
      ParserAdvance
    Else
    Begin
      ParseError(''':'' attendu apres le mode du resultat');
      Ok := False;
    End;
  End;
  If Not Ok Then
  Begin
    { texte de routine incorrect : le reste est saute }
    If (PName <> '') And (K = SK_PROC) Then
      SymDeclare(PName, SK_PROC, MD_ERROR, NL, NC);
    Body := ParseOpaqueUntil(UK_OPAQUE, 1);
    UnitTab[U].A := Body;
    ParseRoutine := U;
    Exit;
  End;
  ModeTmpReset;
  For I := 0 To N - 1 Do
    ModeTmpAdd('', PM[I], L, C);
  M := ModeProcTmp(Res);
  UnitTab[U].Mode := M;
  Sc := ScopeEnter(SCK_PROC);
  UnitTab[U].Scope := Sc;
  Agg := ModeKind(Res) In [MK_STRUCT, MK_ROW, MK_UNION, MK_PROC];
  Off := 12;
  If Agg Then Off := 16;
  For I := 0 To N - 1 Do
  Begin
    S := SymDeclare(PN[I], SK_PARAM, PM[I], PL[I], PC[I]);
    SymTab[S].Storage := SC_PARAM;
    SymTab[S].Offset := Off;
    SymTab[S].Used := True;
    Sz := ModeSize(PM[I]);
    If Sz < 4 Then Sz := 4;
    Off := Off + ((Sz + 3) And -4);
  End;
  UnitTab[U].IntVal := Off - 8;            { octets retires par RET }
  If PName <> '' Then
  Begin
    ScopeCur := ScopeTab[Sc].Parent;
    S := SymDeclare(PName, K, M, NL, NC);
    ScopeCur := Sc;
    SymTab[S].Used := True;
    UnitTab[U].Sym := S;
  End;
  Body := ParseUnitX(1);
  Body := CoerceUnit(Body, Res, STR_STRONG);
  UnitTab[U].A := Body;
  ScopeLeave;
  ParseRoutine := U;
End;

{ PROC nom = texte de routine, nom = ... }
Function ParseProcDecl : LongInt;
Var
  First, Last, U, R : LongInt;
  Name              : TName;
  L, C              : Integer;
  More              : Boolean;
Begin
  First := -1;
  Last := -1;
  ParserAdvance;                       { PROC }
  Repeat
    More := False;
    L := TokTab[TokPos].Line;
    C := TokTab[TokPos].Col;
    Name := TokTab[TokPos].Val;
    ParserAdvance;                     { nom }
    If AtOpSym('=') Then
      ParserAdvance
    Else
      ParseError('''='' attendu apres le nom de la procedure');
    If AtRoutineStart Then
    Begin
      R := ParseRoutine(Name, L, C, SK_PROC);
      U := UnitNew(UK_PROCDECL, L, C);
      UnitTab[U].Name := Name;
      UnitTab[U].A := R;
      UnitTab[U].Sym := UnitTab[R].Sym;
      UnitTab[U].Mode := UnitTab[R].Mode;
      If First < 0 Then First := U Else UnitTab[Last].Next := U;
      Last := U;
      Inc(DeclCount);
    End
    Else
    Begin
      ParseError('texte de routine attendu apres ''=''');
      SymDeclare(Name, SK_PROC, MD_ERROR, L, C);
      R := ParseOpaqueUntil(UK_OPAQUE, 1);
      If First < 0 Then First := R Else UnitTab[Last].Next := R;
      Last := R;
    End;
    If AtPunct(',') And (TokAt(1).Kind = TK_TAG) And
       (TokAt(2).Kind = TK_OP) Then
    Begin
      ParserAdvance;
      More := True;
    End;
  Until (Not More) Or AtEOF;
  ParseProcDecl := First;
End;

{ Operateurs definis par l'utilisateur dont la priorite sera verifiee }
Const
  MAX_USEROP = 256;
Var
  UserOpTab   : Array[0..MAX_USEROP - 1] Of Integer;
  UserOpCount : Integer;

{ OP nom = texte de routine, nom = ... : operateur monadique (un
  operande) ou dyadique (deux) ; la routine est appelee avec la
  convention des procedures }
Function ParseOpDecl : LongInt;
Var
  First, Last, U, R : LongInt;
  Name              : TName;
  L, C              : Integer;
  More              : Boolean;
  T                 : TToken;
Begin
  First := -1;
  Last := -1;
  ParserAdvance;                       { OP }
  Repeat
    More := False;
    L := TokTab[TokPos].Line;
    C := TokTab[TokPos].Col;
    T := TokTab[TokPos];
    If Not (T.Kind In [TK_BOLD, TK_OP]) Or (T.Val = '=') Then
    Begin
      ParseError('nom d''operateur attendu');
      R := ParseOpaqueUntil(UK_OPAQUE, 1);
      If First < 0 Then First := R Else UnitTab[Last].Next := R;
      Last := R;
    End
    Else
    Begin
      Name := T.Val;
      ParserAdvance;                   { nom }
      If AtOpSym('=') Then
        ParserAdvance
      Else
        ParseError('''='' attendu apres le nom de l''operateur');
      If AtRoutineStart Then
      Begin
        R := ParseRoutine(Name, L, C, SK_OP);
        U := UnitNew(UK_PROCDECL, L, C);
        UnitTab[U].Name := Name;
        UnitTab[U].A := R;
        UnitTab[U].Sym := UnitTab[R].Sym;
        UnitTab[U].Mode := UnitTab[R].Mode;
        If (UnitTab[R].Sym >= 0) Then
        Begin
          If (ModeTab[ModeResolve(UnitTab[R].Mode)].Count < 1) Or
             (ModeTab[ModeResolve(UnitTab[R].Mode)].Count > 2) Then
            ErrorAt(L, C, 'un operateur a un ou deux operandes, pas ' +
                    ItoS(ModeTab[ModeResolve(UnitTab[R].Mode)].Count))
          Else If (ModeTab[ModeResolve(UnitTab[R].Mode)].Count = 2) And
                  (UserOpCount < MAX_USEROP) Then
          Begin
            UserOpTab[UserOpCount] := UnitTab[R].Sym;
            Inc(UserOpCount);
          End;
        End;
        If First < 0 Then First := U Else UnitTab[Last].Next := U;
        Last := U;
        Inc(DeclCount);
      End
      Else
      Begin
        ParseError('texte de routine attendu apres ''=''');
        R := ParseOpaqueUntil(UK_OPAQUE, 1);
        If First < 0 Then First := R Else UnitTab[Last].Next := R;
        Last := R;
      End;
      If AtPunct(',') And (TokAt(1).Kind In [TK_BOLD, TK_OP]) And
         (TokAt(2).Kind = TK_OP) And (TokAt(2).Val = '=') Then
      Begin
        ParserAdvance;
        More := True;
      End;
    End;
  Until (Not More) Or AtEOF;
  ParseOpDecl := First;
End;

{ Liste d unites separees par des virgules jusqu a la parenthese
  fermante (consommee) ; retourne la tete de liste, Count = nombre }
Function ParseArgList(Var Count : Integer) : LongInt;
Var
  First, Last, A : LongInt;
  More           : Boolean;
Begin
  First := -1;
  Last := -1;
  Count := 0;
  ParserAdvance;                             { ( }
  If AtPunct(')') Then
  Begin
    ParserAdvance;                           { liste vide : f() }
    ParseArgList := -1;
    Exit;
  End;
  Repeat
    More := False;
    A := ParseUnitX(1);
    UnitTab[A].Next := -1;
    If First < 0 Then First := A Else UnitTab[Last].Next := A;
    Last := A;
    Inc(Count);
    If AtPunct(',') Then
    Begin
      ParserAdvance;
      More := True;
    End;
  Until (Not More) Or AtEOF;
  If AtPunct(')') Then
    ParserAdvance
  Else
    ParseError(''')'' attendu pour fermer la liste d''arguments');
  ParseArgList := First;
End;

{ Selection : champ OF operande }
Function ParseSelection : LongInt;
Var
  U, Op      : LongInt;
  Name       : TName;
  L, C       : Integer;
  M, St, Idx : Integer;
Begin
  L := TokTab[TokPos].Line;
  C := TokTab[TokPos].Col;
  Name := TokTab[TokPos].Val;
  ParserAdvance;                             { le champ }
  ParserAdvance;                             { OF }
  U := UnitNew(UK_SELECT, L, C);
  UnitTab[U].Name := Name;
  Op := ParsePrimary;
  If Op < 0 Then
  Begin
    ParseError('operande attendu apres OF');
    ParseSelection := U;
    Exit;
  End;
  Op := CoerceName(Op);
  UnitTab[U].A := Op;
  M := NatMode(Op);
  If M = MD_ERROR Then
  Begin
    ParseSelection := U;
    Exit;
  End;
  St := ModeDeref(M);
  If ModeKind(St) <> MK_STRUCT Then
  Begin
    ErrorAt(L, C, 'selection sur un mode qui n''est pas une structure: ' +
            ModeName(M));
    ParseSelection := U;
    Exit;
  End;
  Idx := ModeFindField(St, Name);
  If Idx < 0 Then
  Begin
    ErrorAt(L, C, 'champ inconnu: ' + Name + ' dans ' + ModeName(St));
    ParseSelection := U;
    Exit;
  End;
  UnitTab[U].IntVal := Idx;
  UnitTab[U].C := ModeFieldOffset(St, Idx);
  If ModeKind(M) = MK_REF Then
    UnitTab[U].Mode := ModeRef(ModeFieldMode(St, Idx))
  Else
    UnitTab[U].Mode := ModeFieldMode(St, Idx);
  ParseSelection := U;
End;

{ Indexation et tranche : operande [ indices ] }
Function ParseSlice(Op : LongInt) : LongInt;
Var
  U, First, Last, It, Lo, Hi : LongInt;
  M, Row, Elem               : Integer;
  Count, Trims               : Integer;
  L, C                       : Integer;
  More                       : Boolean;
Begin
  L := TokTab[TokPos].Line;
  C := TokTab[TokPos].Col;
  Op := CoerceName(Op);
  U := UnitNew(UK_SLICE, L, C);
  UnitTab[U].A := Op;
  M := NatMode(Op);
  Row := ModeDeref(M);
  ParserAdvance;                             { [ }
  First := -1;
  Last := -1;
  Count := 0;
  Trims := 0;
  Repeat
    More := False;
    Lo := -1;
    Hi := -1;
    If Not AtPunct(':') Then
    Begin
      Lo := ParseUnitX(3);
      Lo := CoerceUnit(Lo, MD_INT, STR_MEEK);
    End;
    If AtPunct(':') Then
    Begin
      ParserAdvance;
      If Not (AtPunct(',') Or AtPunct(']')) Then
      Begin
        Hi := ParseUnitX(1);
        Hi := CoerceUnit(Hi, MD_INT, STR_MEEK);
      End;
      It := UnitNew(UK_TRIM, L, C);
      UnitTab[It].A := Lo;
      UnitTab[It].B := Hi;
      Inc(Trims);
    End
    Else
      It := Lo;
    UnitTab[It].Next := -1;
    If First < 0 Then First := It Else UnitTab[Last].Next := It;
    Last := It;
    Inc(Count);
    If AtPunct(',') Then
    Begin
      ParserAdvance;
      More := True;
    End;
  Until (Not More) Or AtEOF;
  If AtPunct(']') Then
    ParserAdvance
  Else
    ParseError(''']'' attendu');
  UnitTab[U].B := First;
  UnitTab[U].IntVal := Count;
  UnitTab[U].C := Trims;
  If M = MD_ERROR Then
  Begin
    ParseSlice := U;
    Exit;
  End;
  If ModeKind(Row) <> MK_ROW Then
  Begin
    ErrorAt(L, C, 'indice sur un mode qui n''est pas un tableau: ' +
            ModeName(M));
    ParseSlice := U;
    Exit;
  End;
  If ModeTab[Row].Dims <> Count Then
  Begin
    ErrorAt(L, C, 'tableau de ' + ItoS(ModeTab[Row].Dims) +
            ' dimension(s) indice avec ' + ItoS(Count) + ' indice(s)');
    ParseSlice := U;
    Exit;
  End;
  Elem := ModeTab[Row].Sub;
  If Trims > 0 Then
    Elem := ModeRow(Elem, Trims, False);
  If ModeKind(M) = MK_REF Then
    UnitTab[U].Mode := ModeRef(Elem)
  Else
    UnitTab[U].Mode := Elem;
  ParseSlice := U;
End;

{ Appel de procedure : callee ( arguments ) ; le nombre d arguments et
  leurs modes sont verifies, chaque argument est coerce vers le mode du
  parametre (contexte fort) }
Function ParseCall(Callee : LongInt) : LongInt;
Var
  U, A, Args : LongInt;
  Prev, Cur  : LongInt;
  M, Proc, I : Integer;
  Count      : Integer;
  L, C       : Integer;
Begin
  L := TokTab[TokPos].Line;
  C := TokTab[TokPos].Col;
  Callee := CoerceUnit(Callee, ModeDeref(NatMode(Callee)), STR_MEEK);
  M := NatMode(Callee);
  Proc := ModeDeref(M);
  U := UnitNew(UK_CALL, L, C);
  UnitTab[U].A := Callee;
  Args := ParseArgList(Count);
  UnitTab[U].B := Args;
  UnitTab[U].IntVal := Count;
  If ModeKind(Proc) <> MK_PROC Then
  Begin
    ErrorAt(L, C, 'appel d''une valeur qui n''est pas une procedure: ' +
            ModeName(M));
    ParseCall := U;
    Exit;
  End;
  UnitTab[U].Mode := ModeTab[Proc].Sub;
  If ModeTab[Proc].Count <> Count Then
  Begin
    ErrorAt(L, C, 'appel avec ' + ItoS(Count) + ' argument(s) au lieu de ' +
            ItoS(ModeTab[Proc].Count));
    ParseCall := U;
    Exit;
  End;
  { coercition de chaque argument vers le mode du parametre }
  Prev := -1;
  A := Args;
  I := 0;
  While A >= 0 Do
  Begin
    Cur := A;
    A := UnitTab[Cur].Next;
    If ModeKind(ModePoolM[ModeTab[Proc].First + I]) = MK_REF Then
      MarkAssigned(Cur, UnitTab[Cur].Line, UnitTab[Cur].Col);
    Cur := CoerceUnit(Cur, ModePoolM[ModeTab[Proc].First + I], STR_STRONG);
    UnitTab[Cur].Next := A;
    If Prev < 0 Then UnitTab[U].B := Cur Else UnitTab[Prev].Next := Cur;
    Prev := Cur;
    Inc(I);
  End;
  ParseCall := U;
End;

{ ---- Transput, clauses paralleles (TODO 19) ---- }

Function ParseDisplay : LongInt; Forward;

{ Marqueur de print : newline ou space }
Function IsPrintMarker(U : LongInt) : Boolean;
Begin
  IsPrintMarker := (UnitTab[U].Kind = UK_IDENT) And
                   (UnitTab[U].Mode = MD_VOID) And
                   ((UnitTab[U].Name = 'newline') Or
                    (UnitTab[U].Name = 'space'));
End;

{ print(( a, b, ... )), print(a), read(( x, y )), read(x) : les
  elements sont des valeurs (print) de mode INT, REAL, BOOL, CHAR, BITS
  ou STRING, ou des noms (read) de mode INT, REAL, CHAR ou STRING ;
  newline et space sont admis dans les deux }
Function ParsePrintCall : LongInt;
Var
  U, Args, A, Cur, Prev, Nxt : LongInt;
  After                      : LongInt;
  Count, Save                : Integer;
  SaveTok                    : LongInt;
  IsRead, ListForm           : Boolean;
  M, Want                    : Integer;
Begin
  U := UnitNew(UK_PRINT, TokTab[TokPos].Line, TokTab[TokPos].Col);
  UnitTab[U].Name := TokTab[TokPos].Val;
  UnitTab[U].Mode := MD_VOID;
  IsRead := UnitTab[U].Name = 'read';
  ParserAdvance;                             { print ou read }
  ListForm := False;
  If (TokAt(1).Kind = TK_PUNCT) And (TokAt(1).Val = '(') Then
  Begin
    SaveTok := TokPos;
    TokPos := TokPos + 1;
    After := TokAfterClose;
    TokPos := SaveTok;
    ListForm := (TokTab[After].Kind = TK_PUNCT) And
                (TokTab[After].Val = ')');
  End;
  ParserAdvance;                             { ( }
  Count := 0;
  If ListForm Then
    Args := ParseArgList(Count)
  Else
  Begin
    Args := ParseUnitX(1);
    UnitTab[Args].Next := -1;
    Count := 1;
  End;
  If AtPunct(')') Then
    ParserAdvance
  Else
    ParseError(''')'' attendu apres les elements de ' + UnitTab[U].Name);
  { chaque element : valeur (print) ou nom (read) du bon mode }
  Prev := -1;
  A := Args;
  UnitTab[U].A := Args;
  While A >= 0 Do
  Begin
    Nxt := UnitTab[A].Next;
    Cur := A;
    M := NatMode(A);
    If (M <> MD_ERROR) And Not IsPrintMarker(A) Then
    Begin
      If IsRead Then
      Begin
        Cur := CoerceName(A);
        MarkAssigned(Cur, UnitTab[A].Line, UnitTab[A].Col);
        M := NatMode(Cur);
        If (ModeKind(M) <> MK_REF) Or
           Not (ModeKind(ModeDeref(M)) In [MK_INT, MK_REAL, MK_CHAR]) And
           Not ModeIsString(ModeDeref(M)) Then
          ErrorAt(UnitTab[A].Line, UnitTab[A].Col,
                  'read demande un nom de mode INT, REAL, CHAR ou ' +
                  'STRING, pas ' + ModeName(M));
      End
      Else
      Begin
        Want := ModeDeref(M);
        While ModeIsProc0(Want) Do
          Want := ModeDeref(ModeTab[ModeResolve(Want)].Sub);
        Cur := CoerceUnit(A, Want, STR_MEEK);
        If Not (ModeKind(Want) In [MK_INT, MK_REAL, MK_BOOL, MK_CHAR,
                                   MK_BITS]) And Not ModeIsString(Want) Then
          ErrorAt(UnitTab[A].Line, UnitTab[A].Col,
                  'print ne sait pas afficher une valeur de mode ' +
                  ModeName(Want));
      End;
    End;
    UnitTab[Cur].Next := Nxt;
    If Prev < 0 Then UnitTab[U].A := Cur Else UnitTab[Prev].Next := Cur;
    Prev := Cur;
    A := Nxt;
  End;
  UnitTab[U].IntVal := Count;
  ParsePrintCall := U;
End;

{ PAR ( ... ) ou PAR BEGIN ... END : pas de processus, les unites sont
  elaborees l'une apres l'autre (avertissement) }
Function ParsePar : LongInt;
Var
  U : LongInt;
  L, C : Integer;
Begin
  L := TokTab[TokPos].Line;
  C := TokTab[TokPos].Col;
  WarnAt(L, C, 'PAR : unites elaborees sequentiellement, sans processus ' +
         'paralleles');
  ParserAdvance;                             { PAR }
  If AtKw('BEGIN') Or (AtPunct('(') And ParenIsClosed) Then
    U := ParseClosed
  Else If AtPunct('(') Then
    U := ParseDisplay
  Else
  Begin
    ParseError('clause collaterale attendue apres PAR');
    U := -1;
  End;
  ParsePar := U;
End;

{ Mode suivi d une parenthese : constructeur de structure POINT(3, 7)
  ou conversion (cast) d une unite vers un mode }
Function ParseConstruct : LongInt;
Var
  U, A, Args : LongInt;
  M, I       : Integer;
  Count      : Integer;
  Bnd        : LongInt;
  Dm         : Integer;
  L, C       : Integer;
  Prev, Cur  : LongInt;
Begin
  L := TokTab[TokPos].Line;
  C := TokTab[TokPos].Col;
  If Not ParseDeclarer(M, Bnd, Dm, True) Then
  Begin
    ParseConstruct := -1;
    Exit;
  End;
  If ModeKind(M) = MK_STRUCT Then
  Begin
    U := UnitNew(UK_CONSTRUCT, L, C);
    UnitTab[U].Mode := M;
    Args := ParseArgList(Count);
    UnitTab[U].A := Args;
    UnitTab[U].IntVal := Count;
    If ModeFieldCount(M) <> Count Then
    Begin
      ErrorAt(L, C, 'constructeur de ' + ModeName(M) + ' avec ' +
              ItoS(Count) + ' valeur(s) au lieu de ' +
              ItoS(ModeFieldCount(M)));
      ParseConstruct := U;
      Exit;
    End;
    { coercition de chaque valeur vers le mode du champ }
    Prev := -1;
    A := Args;
    I := 0;
    While A >= 0 Do
    Begin
      Cur := A;
      A := UnitTab[Cur].Next;
      Cur := CoerceUnit(Cur, ModeFieldMode(M, I), STR_STRONG);
      UnitTab[Cur].Next := A;
      If Prev < 0 Then UnitTab[U].A := Cur Else UnitTab[Prev].Next := Cur;
      Prev := Cur;
      Inc(I);
    End;
    ParseConstruct := U;
    Exit;
  End;
  { conversion : un seul element }
  U := UnitNew(UK_CAST, L, C);
  UnitTab[U].Mode := M;
  ParserAdvance;                             { ( }
  A := ParseUnitX(1);
  UnitTab[U].A := CoerceUnit(A, M, STR_STRONG);
  If AtPunct(')') Then
    ParserAdvance
  Else
    ParseError(''')'' attendu apres la conversion');
  ParseConstruct := U;
End;

{ ---- Clauses conditionnelles et repetitives (TODO 12) ---- }

{ Derniere unite (hors declaration et etiquette) d'une chaine }
Function LastValueUnit(First : LongInt) : LongInt;
Var
  P : LongInt;
Begin
  LastValueUnit := -1;
  P := First;
  While P >= 0 Do
  Begin
    If Not (UnitTab[P].Kind In [UK_LABELDEF, UK_VARDECL, UK_IDDECL,
                                UK_MODEDECL, UK_PRIODECL,
                                UK_PROCDECL, UK_DECL]) Then
      LastValueUnit := P;
    P := UnitTab[P].Next;
  End;
End;

{ Mode naturel d'une clause serie : celui de sa derniere unite }
Function SerialMode(First : LongInt) : Integer;
Var
  L : LongInt;
Begin
  L := LastValueUnit(First);
  If L < 0 Then
    SerialMode := MD_VOID
  Else
    SerialMode := NatMode(L);
End;

{ Mode equilibre de deux modes naturels, inconnu si l un l'est }
Function BalanceKnown(A, B : Integer) : Integer;
Begin
  If (A = MD_ERROR) Or (B = MD_ERROR) Then
    BalanceKnown := MD_ERROR
  Else
    BalanceKnown := ModeBalance(A, B);
End;

{ La parenthese courante ouvre-t-elle une forme abregee ( c | a | b ) ? }
Function ParenIsBrief : Boolean;
Var
  K     : LongInt;
  Depth : Integer;
  T     : TToken;
  Bar   : Boolean;
Begin
  Bar := False;
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
              ((T.Val = '|') Or (T.Val = '|:')) Then
        Bar := True;
      If Depth <= 0 Then K := TokCount Else Inc(K);
    End;
  End;
  ParenIsBrief := Bar;
End;

{ Le CASE courant (jeton CASE ou OUSE) est-il une clause de conformite
  ((INT i) : unite) ? Les clauses de conformite sont analysees au TODO 18 }
Function CaseIsConformity : Boolean;
Var
  Save, After : LongInt;
  Res         : Boolean;
  Depth       : Integer;
  K           : LongInt;
Begin
  Res := False;
  K := TokPos;
  Depth := 0;
  { cherche le IN de cette clause (a profondeur nulle) }
  While (K < TokCount - 1) And Not Res Do
  Begin
    Inc(K);
    If TokDepth(TokTab[K]) > 0 Then Inc(Depth)
    Else If TokDepth(TokTab[K]) < 0 Then Dec(Depth);
    If (Depth = 0) And (TokTab[K].Kind = TK_KEYWORD) And
       (TokTab[K].Val = 'IN') Then
    Begin
      If (TokTab[K + 1].Kind = TK_PUNCT) And (TokTab[K + 1].Val = '(') Then
      Begin
        Save := TokPos;
        TokPos := K + 1;
        After := TokAfterClose;
        TokPos := Save;
        Res := (TokTab[After].Kind = TK_PUNCT) And
               (TokTab[After].Val = ':');
      End;
      K := TokCount;
    End;
  End;
  CaseIsConformity := Res;
End;

Function ParseCaseTail(U : LongInt; Brief : Boolean) : LongInt; Forward;

{ Reste d'une clause IF apres le IF (ou ELIF) deja consomme : condition,
  THEN, partie alors, puis ELIF, ELSE ou FI ; la forme abregee utilise
  | et |: }
Function ParseIfTail(Brief : Boolean) : LongInt;
Var
  U, Inner : LongInt;
  M1, M2   : Integer;
  Last     : LongInt;
Begin
  U := UnitNew(UK_IF, TokTab[TokPos].Line, TokTab[TokPos].Col);
  UnitTab[U].Scope := ScopeEnter(SCK_CHOICE);
  UnitTab[U].A := ParseSerial(False);
  If Brief Then
  Begin
    If AtPunct('|') Then
      ParserAdvance
    Else
      ParseError('''|'' attendu apres la condition');
  End
  Else
  Begin
    If AtKw('THEN') Then
      ParserAdvance
    Else
      ParseError('THEN attendu apres la condition');
  End;
  UnitTab[U].B := ParseSerial(False);
  ScopeLeave;
  UnitTab[U].C := -1;
  If (Not Brief) And AtKw('ELIF') Then
  Begin
    ParserAdvance;
    Inner := ParseIfTail(False);
    UnitTab[U].C := Inner;
  End
  Else If Brief And AtPunct('|:') Then
  Begin
    ParserAdvance;
    Inner := ParseIfTail(True);
    UnitTab[U].C := Inner;
  End
  Else If (Not Brief) And AtKw('ELSE') Then
  Begin
    ParserAdvance;
    ScopeEnter(SCK_CHOICE);
    UnitTab[U].C := ParseSerial(False);
    ScopeLeave;
  End
  Else If Brief And AtPunct('|') Then
  Begin
    ParserAdvance;
    ScopeEnter(SCK_CHOICE);
    UnitTab[U].C := ParseSerial(False);
    ScopeLeave;
  End;
  { mode naturel : equilibre des deux branches ; VOID sans ELSE }
  M1 := SerialMode(UnitTab[U].B);
  If UnitTab[U].C < 0 Then
    M2 := MD_VOID
  Else If UnitTab[UnitTab[U].C].Kind = UK_IF Then
    M2 := UnitTab[UnitTab[U].C].Mode
  Else
    M2 := SerialMode(UnitTab[U].C);
  UnitTab[U].Mode := BalanceKnown(M1, M2);
  Last := U;
  ParseIfTail := Last;
End;

Function ParseIf : LongInt;
Var
  U : LongInt;
Begin
  ParserAdvance;                             { IF }
  U := ParseIfTail(False);
  If AtKw('FI') Then
    ParserAdvance
  Else
    ParseError('FI attendu');
  Inc(ClauseCount);
  ParseIf := U;
End;

{ CASE selecteur IN unites separees par des virgules OUT serie ESAC ;
  forme abregee ( selecteur | unites | defaut ) }
Function ParseCaseTail(U : LongInt; Brief : Boolean) : LongInt;
Var
  First, Last, A, Inner : LongInt;
  Count                 : Integer;
  M, MB                 : Integer;
  More                  : Boolean;
Begin
  UnitTab[U].Scope := ScopeEnter(SCK_CHOICE);
  UnitTab[U].A := ParseSerial(False);
  If Brief Then
  Begin
    If AtPunct('|') Then
      ParserAdvance
    Else
      ParseError('''|'' attendu apres le selecteur');
  End
  Else
  Begin
    If AtKw('IN') Then
      ParserAdvance
    Else
      ParseError('IN attendu apres le selecteur');
  End;
  First := -1;
  Last := -1;
  Count := 0;
  Repeat
    More := False;
    A := ParseUnitX(1);
    UnitTab[A].Next := -1;
    If First < 0 Then First := A Else UnitTab[Last].Next := A;
    Last := A;
    Inc(Count);
    If AtPunct(',') Then
    Begin
      ParserAdvance;
      More := True;
    End;
  Until (Not More) Or AtEOF;
  UnitTab[U].B := First;
  UnitTab[U].IntVal := Count;
  ScopeLeave;
  UnitTab[U].C := -1;
  If (Not Brief) And AtKw('OUSE') Then
  Begin
    ParserAdvance;
    Inner := UnitNew(UK_CASE, TokTab[TokPos].Line, TokTab[TokPos].Col);
    UnitTab[U].C := ParseCaseTail(Inner, False);
  End
  Else If Brief And AtPunct('|:') Then
  Begin
    ParserAdvance;
    Inner := UnitNew(UK_CASE, TokTab[TokPos].Line, TokTab[TokPos].Col);
    UnitTab[U].C := ParseCaseTail(Inner, True);
  End
  Else If (Not Brief) And AtKw('OUT') Then
  Begin
    ParserAdvance;
    ScopeEnter(SCK_CHOICE);
    UnitTab[U].C := ParseSerial(False);
    ScopeLeave;
  End
  Else If Brief And AtPunct('|') Then
  Begin
    ParserAdvance;
    ScopeEnter(SCK_CHOICE);
    UnitTab[U].C := ParseSerial(False);
    ScopeLeave;
  End;
  { mode naturel : equilibre des alternatives et de la partie OUT ;
    VOID s'il n'y a pas de partie OUT }
  M := NatMode(First);
  A := First;
  While A >= 0 Do
  Begin
    M := BalanceKnown(M, NatMode(A));
    A := UnitTab[A].Next;
  End;
  If UnitTab[U].C < 0 Then
    MB := MD_VOID
  Else If UnitTab[UnitTab[U].C].Kind = UK_CASE Then
    MB := UnitTab[UnitTab[U].C].Mode
  Else
    MB := SerialMode(UnitTab[U].C);
  UnitTab[U].Mode := BalanceKnown(M, MB);
  ParseCaseTail := U;
End;

{ Clause de conformite : CASE selecteur IN (mode nom) : unite, ... OUT
  serie ESAC. Chaque alternative a sa portee (SCK_CONFORM) ou le nom est
  lie a la valeur extraite de l'union. }
Function ParseConformity : LongInt;
Var
  U, Alt, First, Last : LongInt;
  Bnd, Body           : LongInt;
  M, Dm, MB, S        : Integer;
  Name                : TName;
  L, C, Count         : Integer;
  More                : Boolean;
Begin
  U := UnitNew(UK_CONFORM, TokTab[TokPos].Line, TokTab[TokPos].Col);
  ParserAdvance;                             { CASE }
  UnitTab[U].Scope := ScopeEnter(SCK_CHOICE);
  UnitTab[U].A := ParseSerial(False);
  If AtKw('IN') Then
    ParserAdvance
  Else
    ParseError('IN attendu apres le selecteur');
  First := -1;
  Last := -1;
  Count := 0;
  M := MD_ERROR;
  Repeat
    More := False;
    L := TokTab[TokPos].Line;
    C := TokTab[TokPos].Col;
    If AtPunct('(') Then
      ParserAdvance
    Else
      ParseError('''('' attendu : alternative de la clause de conformite');
    ParseDeclarer(M, Bnd, Dm, True);
    Alt := UnitNew(UK_CONFALT, L, C);
    UnitTab[Alt].Mode := M;
    UnitTab[Alt].Sym := -1;
    UnitTab[Alt].IntVal := 0;
    UnitTab[Alt].Scope := ScopeEnter(SCK_CONFORM);
    If TokTab[TokPos].Kind = TK_TAG Then
    Begin
      Name := TokTab[TokPos].Val;
      S := SymDeclare(Name, SK_IDENT, M, TokTab[TokPos].Line,
                      TokTab[TokPos].Col);
      DeclareStorage(S, M, TokTab[TokPos].Line, TokTab[TokPos].Col);
      SymTab[S].Used := True;
      UnitTab[Alt].Sym := S;
      ParserAdvance;
    End;
    If AtPunct(')') Then
      ParserAdvance
    Else
      ParseError(''')'' attendu apres le mode de l''alternative');
    If AtPunct(':') Then
      ParserAdvance
    Else
      ParseError(''':'' attendu apres l''alternative');
    Body := ParseUnitX(1);
    UnitTab[Alt].A := Body;
    ScopeLeave;
    UnitTab[Alt].Next := -1;
    If First < 0 Then First := Alt Else UnitTab[Last].Next := Alt;
    Last := Alt;
    Inc(Count);
    If AtPunct(',') Then
    Begin
      ParserAdvance;
      More := True;
    End;
  Until (Not More) Or AtEOF;
  UnitTab[U].B := First;
  UnitTab[U].IntVal := Count;
  UnitTab[U].C := -1;
  If AtKw('OUT') Then
  Begin
    ParserAdvance;
    ScopeEnter(SCK_CHOICE);
    UnitTab[U].C := ParseSerial(False);
    ScopeLeave;
  End;
  ScopeLeave;
  { mode naturel : equilibre des alternatives et de la partie OUT }
  M := NatMode(UnitTab[First].A);
  Alt := UnitTab[First].Next;
  While Alt >= 0 Do
  Begin
    M := BalanceKnown(M, NatMode(UnitTab[Alt].A));
    Alt := UnitTab[Alt].Next;
  End;
  If UnitTab[U].C < 0 Then
    MB := MD_VOID
  Else
    MB := SerialMode(UnitTab[U].C);
  UnitTab[U].Mode := BalanceKnown(M, MB);
  If AtKw('ESAC') Then
    ParserAdvance
  Else
    ParseError('ESAC attendu');
  Inc(ClauseCount);
  ParseConformity := U;
End;

Function ParseCase : LongInt;
Var
  U : LongInt;
Begin
  If CaseIsConformity Then
  Begin
    ParseCase := ParseConformity;
    Exit;
  End;
  U := UnitNew(UK_CASE, TokTab[TokPos].Line, TokTab[TokPos].Col);
  ParserAdvance;                             { CASE }
  ParseCaseTail(U, False);
  If AtKw('ESAC') Then
    ParserAdvance
  Else
    ParseError('ESAC attendu');
  Inc(ClauseCount);
  ParseCase := U;
End;

{ ( condition | alors | sinon ) ou ( selecteur | unites | defaut ) : un
  identificateur seul en tete dont le mode est INT designe un CASE, un
  mode BOOL un IF ; sinon, une virgule dans la suite designe un CASE }
Function ParseBrief : LongInt;
Var
  K      : LongInt;
  Depth  : Integer;
  Commas : Boolean;
  IsCase : Boolean;
  U      : LongInt;
  S      : Integer;
Begin
  Commas := False;
  K := TokPos;
  Depth := 0;
  While K < TokCount - 1 Do
  Begin
    If TokDepth(TokTab[K]) > 0 Then Inc(Depth)
    Else If TokDepth(TokTab[K]) < 0 Then Dec(Depth);
    If (Depth = 1) And (TokTab[K].Kind = TK_PUNCT) And
       (TokTab[K].Val = ',') Then
      Commas := True;
    Inc(K);
    If Depth <= 0 Then K := TokCount;
  End;
  IsCase := Commas;
  If (TokAt(1).Kind = TK_TAG) And (TokAt(2).Kind = TK_PUNCT) And
     (TokAt(2).Val = '|') Then
  Begin
    S := SymFindIdent(TokAt(1).Val);
    If (S >= 0) And (SymTab[S].Mode <> MD_ERROR) Then
      IsCase := ModeKind(ModeDeref(SymTab[S].Mode)) = MK_INT;
  End;
  ParserAdvance;                             { ( }
  If IsCase Then
  Begin
    U := UnitNew(UK_CASE, TokTab[TokPos].Line, TokTab[TokPos].Col);
    ParseCaseTail(U, True);
  End
  Else
    U := ParseIfTail(True);
  If AtPunct(')') Then
    ParserAdvance
  Else
    ParseError(''')'' attendu pour fermer la forme abregee');
  Inc(ClauseCount);
  ParseBrief := U;
End;

{ Indice du jeton qui suit la clause repetitive courante : apres le
  OD qui ferme son DO ; TokCount - 1 si elle n est pas fermee }
Function TokAfterLoop : LongInt;
Var
  K     : LongInt;
  Depth : Integer;
  InBody: Boolean;
Begin
  K := TokPos;
  Depth := 0;
  InBody := False;
  While K < TokCount - 1 Do
  Begin
    If (Not InBody) And (Depth = 0) And (TokTab[K].Kind = TK_KEYWORD) And
       (TokTab[K].Val = 'DO') Then
    Begin
      InBody := True;
      Depth := 1;
    End
    Else If TokDepth(TokTab[K]) > 0 Then
      Inc(Depth)
    Else If TokDepth(TokTab[K]) < 0 Then
    Begin
      Dec(Depth);
      If InBody And (Depth = 0) Then
      Begin
        TokAfterLoop := K + 1;
        Exit;
      End;
    End;
    Inc(K);
  End;
  TokAfterLoop := TokCount - 1;
End;

{ FOR i FROM a BY b TO c WHILE condition DO corps OD ; toutes les
  parties sont facultatives sauf DO ... OD }
Function ParseLoop : LongInt;
Var
  U     : LongInt;
  Name  : TName;
  L, C  : Integer;
  S     : Integer;
Begin
  L := TokTab[TokPos].Line;
  C := TokTab[TokPos].Col;
  U := UnitNew(UK_LOOP, L, C);
  UnitTab[U].Mode := MD_VOID;
  Name := '';
  If AtKw('FOR') Then
  Begin
    ParserAdvance;
    If TokTab[TokPos].Kind = TK_TAG Then
    Begin
      Name := TokTab[TokPos].Val;
      ParserAdvance;
    End
    Else
      ParseError('nom de variable de controle attendu apres FOR');
  End;
  { bornes evaluees dans la portee exterieure ; FROM, BY et TO (ou
    DOWNTO) sont acceptes dans un ordre quelconque }
  While AtKw('FROM') Or AtKw('BY') Or AtKw('TO') Or AtKw('DOWNTO') Do
  Begin
    If AtKw('FROM') Then
    Begin
      ParserAdvance;
      UnitTab[U].A := ParseUnitX(4);
    End
    Else If AtKw('BY') Then
    Begin
      ParserAdvance;
      UnitTab[U].B := ParseUnitX(4);
    End
    Else
    Begin
      If AtKw('DOWNTO') Then UnitTab[U].IntVal := 1;
      ParserAdvance;
      UnitTab[U].C := ParseUnitX(4);
    End;
  End;
  UnitTab[U].Scope := ScopeEnter(SCK_LOOP);
  If Name <> '' Then
  Begin
    S := SymDeclare(Name, SK_IDENT, MD_INT, L, C);
    DeclareStorage(S, MD_INT, L, C);
    SymTab[S].Used := True;
    UnitTab[U].Sym := S;
    UnitTab[U].Name := Name;
  End;
  UnitTab[U].D := -1;
  If AtKw('WHILE') Then
  Begin
    ParserAdvance;
    UnitTab[U].D := ParseSerial(False);
    UnitTab[U].IntVal := UnitTab[U].IntVal Or 2;
  End;
  If AtKw('DO') Then
    ParserAdvance
  Else
    ParseError('DO attendu');
  UnitTab[U].E := ParseSerial(False);
  If AtKw('OD') Then
    ParserAdvance
  Else
    ParseError('OD attendu (clause repetitive ouverte ligne ' + ItoS(L) +
               ', colonne ' + ItoS(C) + ')');
  ScopeLeave;
  Inc(ClauseCount);
  ParseLoop := U;
End;

{ La parenthese courante ouvre-t-elle un affichage ( u1, u2, ... ) ? }
Function ParenIsDisplay : Boolean;
Begin
  ParenIsDisplay := Not ParenIsClosed And Not ParenIsBrief;
End;

{ Affichage : elements separes par des virgules ; son mode est donne
  par le contexte (tableau ou structure), voir CoerceUnit }
Function ParseDisplay : LongInt;
Var
  U, First, Last, A : LongInt;
  Count             : Integer;
  More              : Boolean;
Begin
  U := UnitNew(UK_DISPLAY, TokTab[TokPos].Line, TokTab[TokPos].Col);
  ParserAdvance;                             { ( }
  First := -1;
  Last := -1;
  Count := 0;
  Repeat
    More := False;
    A := ParseUnitX(1);
    UnitTab[A].Next := -1;
    If First < 0 Then First := A Else UnitTab[Last].Next := A;
    Last := A;
    Inc(Count);
    If AtPunct(',') Then
    Begin
      ParserAdvance;
      More := True;
    End;
  Until (Not More) Or AtEOF;
  If AtPunct(')') Then
    ParserAdvance
  Else
    ParseError(''')'' attendu pour fermer l''affichage');
  UnitTab[U].A := First;
  UnitTab[U].IntVal := Count;
  ParseDisplay := U;
End;

{ Unite primaire : denotation, identificateur, clause fermee, selection,
  tranche, appel, constructeur. Retourne -1 (sans rien consommer) si ce
  n est pas une primaire connue a ce stade (formules, conditionnelles,
  boucles... : TODOs 11 a 19). }
Function ParsePrimary : LongInt;
Var
  U       : LongInt;
  T       : TToken;
  S, M    : Integer;
  Going   : Boolean;
Begin
  ParsePrimary := -1;
  T := TokTab[TokPos];
  Case T.Kind Of
    TK_INT, TK_REAL, TK_BOOL, TK_CHAR, TK_STRING:
      U := DenotationNode;
    TK_KEYWORD:
      Begin
        If AtKw('NIL') Then
        Begin
          U := UnitNew(UK_NIL, T.Line, T.Col);
          UnitTab[U].Mode := MD_NIL;
          ParserAdvance;
        End
        Else If AtKw('BEGIN') And ClauseFollowOk(TokAfterClose) Then
          U := ParseClosed
        Else If (AtKw('IF') Or AtKw('CASE')) And
                ClauseFollowOk(TokAfterClose) Then
        Begin
          If AtKw('IF') Then U := ParseIf Else U := ParseCase;
          If U < 0 Then Exit;
        End
        Else If (AtKw('FOR') Or AtKw('FROM') Or AtKw('WHILE') Or
                 AtKw('TO') Or AtKw('DOWNTO') Or AtKw('BY') Or
                 AtKw('DO')) And ClauseFollowOk(TokAfterLoop) Then
          U := ParseLoop
        Else If (AtKw('INT') Or AtKw('REAL') Or AtKw('BOOL') Or
                 AtKw('CHAR') Or AtKw('STRING') Or AtKw('BITS')) And
                (TokAt(1).Kind = TK_PUNCT) And (TokAt(1).Val = '(') Then
          U := ParseConstruct
        Else If AtBareRoutine Then
          U := ParseRoutine('', 0, 0, SK_PROC)
        Else If AtKw('PAR') Then
          U := ParsePar
        Else
          Exit;
      End;
    TK_PUNCT:
      Begin
        If AtPunct('(') And ParenIsRoutine Then
          U := ParseRoutine('', 0, 0, SK_PROC)
        Else If AtPunct('(') And ParenIsClosed And
           ClauseFollowOk(TokAfterClose) Then
          U := ParseClosed
        Else If AtPunct('(') And ParenIsBrief And
                ClauseFollowOk(TokAfterClose) Then
          U := ParseBrief
        Else If AtPunct('(') And ParenIsDisplay And
                ClauseFollowOk(TokAfterClose) Then
          U := ParseDisplay
        Else
          Exit;
      End;
    TK_TAG, TK_BOLD:
      Begin
        If (T.Kind = TK_TAG) And (TokAt(1).Kind = TK_KEYWORD) And
           (TokAt(1).Val = 'OF') Then
          U := ParseSelection
        Else
        Begin
          S := SymFindIdent(T.Val);
          If S >= 0 Then
          Begin
            If (SymTab[S].Kind = SK_STD) And (SymTab[S].Mode = MD_VOID) And
               (T.Val <> 'newline') And (T.Val <> 'space') Then
            Begin
              If ((T.Val = 'print') Or (T.Val = 'read')) And
                 (TokAt(1).Kind = TK_PUNCT) And (TokAt(1).Val = '(') Then
                U := ParsePrintCall
              Else
                Exit;
            End
            Else
            Begin
              U := UnitNew(UK_IDENT, T.Line, T.Col);
              UnitTab[U].Sym := S;
              UnitTab[U].Name := T.Val;
              UnitTab[U].Mode := SymTab[S].Mode;
              SymTab[S].Used := True;
              ParserAdvance;
            End
          End
          Else If (SymFindMode(T.Val) >= 0) And (TokAt(1).Kind = TK_PUNCT) And
                  (TokAt(1).Val = '(') Then
            U := ParseConstruct
          Else If T.Kind = TK_TAG Then
          Begin
            ErrorAt(T.Line, T.Col, 'identificateur non declare: ' + T.Val);
            U := UnitNew(UK_IDENT, T.Line, T.Col);
            UnitTab[U].Name := T.Val;
            ParserAdvance;
          End
          Else
            Exit;
        End;
      End;
  Else
    Exit;
  End;
  { suffixes : tranches et appels }
  Going := True;
  While Going And (U >= 0) Do
  Begin
    M := NatMode(U);
    If AtPunct('[') And (M <> MD_ERROR) Then
      U := ParseSlice(U)
    Else If AtPunct('(') And (M <> MD_ERROR) And
            (ModeKind(ModeDeref(M)) = MK_PROC) Then
      U := ParseCall(U)
    Else If AtPunct('[') And (UnitTab[U].Kind = UK_IDENT) Then
      Going := False                       { mode inconnu : enveloppe }
    Else
      Going := False;
  End;
  ParsePrimary := U;
End;

{ ---- Formules (TODO 11) ---- }

{ Les coercitions de force Str menent-elles du mode M au mode Want ?
  (meme suite que CoerceUnit, sans modifier l arbre) }
Function CoercePossible(M, Want : Integer; Str : TStrength) : Boolean;
Var
  W, Steps : Integer;
  Done     : Boolean;
Begin
  CoercePossible := False;
  If (M = MD_ERROR) Or (Want = MD_ERROR) Then Exit;
  M := ModeResolve(M);
  W := ModeResolve(Want);
  Done := False;
  Steps := 0;
  While Not Done And (Steps < 16) Do
  Begin
    Inc(Steps);
    If ModeSame(M, W) Or (CoerceFit(M, W, Str) <> FIT_NONE) Then
    Begin
      CoercePossible := True;
      Done := True;
    End
    Else If (ModeTab[M].Kind = MK_REF) And (Str >= STR_MEEK) Then
      M := ModeResolve(ModeTab[M].Sub)
    Else If ModeIsProc0(M) Then
      M := ModeResolve(ModeTab[M].Sub)
    Else
      Done := True;
  End;
End;

{ Un operande de mode M convient-il a l operande I de l operateur S
  apres des coercitions de force ferme ? }
Function OpOperandFirm(S, I, M : Integer) : Boolean;
Begin
  If SymTab[S].Generic Then
  Begin
    If (OpArity(S) = 2) And (I = 0) Then
      OpOperandFirm := CoercePossible(M, MD_INT, STR_FIRM)
    Else
      OpOperandFirm := ModeKind(ModeDeref(M)) = MK_ROW;
  End
  Else
    OpOperandFirm := CoercePossible(M, OpOperand(S, I), STR_FIRM);
End;

{ Operateur de ce nom dont les operandes acceptent ces modes apres
  coercitions fermes ; la portee la plus interne et la declaration la
  plus recente l emportent. -1 si aucun. }
Function SymFindOpFirm(Const Name : TName; Arity : Integer; A, B : Integer)
         : Integer;
Var
  S, I : Integer;
  Ok   : Boolean;
Begin
  SymFindOpFirm := -1;
  S := ScopeCur;
  While S >= 0 Do
  Begin
    I := ScopeTab[S].LastSym;
    While I >= 0 Do
    Begin
      If (SymTab[I].Kind = SK_OP) And (SymTab[I].Name = Name) And
         (OpArity(I) = Arity) Then
      Begin
        Ok := OpOperandFirm(I, 0, A);
        If Ok And (Arity = 2) Then Ok := OpOperandFirm(I, 1, B);
        If Ok Then
        Begin
          SymFindOpFirm := I;
          Exit;
        End;
      End;
      I := SymTab[I].Prev;
    End;
    S := ScopeTab[S].Parent;
  End;
End;

{ ---- repliement des constantes ---- }
Var
  FoldFailed : Boolean;      { une erreur a deja ete signalee }

Function IsNumDen(U : LongInt) : Boolean;
Begin
  IsNumDen := UnitTab[U].Kind In [UK_INTDEN, UK_REALDEN];
End;

Function NumReal(U : LongInt) : Double;
Begin
  If UnitTab[U].Kind = UK_INTDEN Then
    NumReal := UnitTab[U].IntVal
  Else
    NumReal := UnitTab[U].RealVal;
End;

Procedure SetIntDen(U : LongInt; V : Int64; Line, Col : Integer);
Begin
  If (V > 2147483647) Or (V < -2147483647) Then
  Begin
    ErrorAt(Line, Col, 'debordement entier dans une constante');
    V := 0;
  End;
  UnitTab[U].Kind := UK_INTDEN;
  UnitTab[U].IntVal := V;
  UnitTab[U].Mode := MD_INT;
End;

Procedure SetRealDen(U : LongInt; V : Double; Line, Col : Integer);
Begin
  If RealBad(V) Then
  Begin
    ErrorAt(Line, Col, 'debordement reel dans une constante');
    V := 0;
  End;
  UnitTab[U].Kind := UK_REALDEN;
  UnitTab[U].RealVal := V;
  UnitTab[U].Mode := MD_REAL;
End;

Procedure SetBoolDen(U : LongInt; V : Boolean);
Begin
  UnitTab[U].Kind := UK_BOOLDEN;
  If V Then UnitTab[U].IntVal := 1 Else UnitTab[U].IntVal := 0;
  UnitTab[U].Mode := MD_BOOL;
End;

{ Replie la formule dyadique de deux denotations dans le noeud L ;
  retourne False si elle ne peut pas l etre }
Function FoldBinary(Const Op : TName; L, R : LongInt; ResMode : Integer;
                    Line, Col : Integer) : Boolean;
Var
  A, B, P : Int64;
  X, Y    : Double;
  I       : Integer;
  Cmp     : Integer;
Begin
  FoldBinary := False;
  If Not (IsNumDen(L) And IsNumDen(R)) And
     Not ((UnitTab[L].Kind = UK_BOOLDEN) And
          (UnitTab[R].Kind = UK_BOOLDEN)) Then Exit;
  If (UnitTab[L].Kind = UK_BOOLDEN) Then
  Begin
    A := UnitTab[L].IntVal;
    B := UnitTab[R].IntVal;
    If Op = 'AND' Then SetBoolDen(L, (A <> 0) And (B <> 0))
    Else If Op = 'OR' Then SetBoolDen(L, (A <> 0) Or (B <> 0))
    Else If Op = '=' Then SetBoolDen(L, A = B)
    Else If Op = '/=' Then SetBoolDen(L, A <> B)
    Else Exit;
    FoldBinary := True;
    Exit;
  End;
  X := NumReal(L);
  Y := NumReal(R);
  { comparaisons }
  If ResMode = MD_BOOL Then
  Begin
    If X < Y Then Cmp := -1 Else If X > Y Then Cmp := 1 Else Cmp := 0;
    If Op = '<' Then SetBoolDen(L, Cmp < 0)
    Else If Op = '<=' Then SetBoolDen(L, Cmp <= 0)
    Else If Op = '>' Then SetBoolDen(L, Cmp > 0)
    Else If Op = '>=' Then SetBoolDen(L, Cmp >= 0)
    Else If Op = '=' Then SetBoolDen(L, Cmp = 0)
    Else If Op = '/=' Then SetBoolDen(L, Cmp <> 0)
    Else Exit;
    FoldBinary := True;
    Exit;
  End;
  If ResMode = MD_REAL Then
  Begin
    If Op = '+' Then SetRealDen(L, X + Y, Line, Col)
    Else If Op = '-' Then SetRealDen(L, X - Y, Line, Col)
    Else If Op = '*' Then SetRealDen(L, X * Y, Line, Col)
    Else If Op = '/' Then
    Begin
      If Y = 0 Then
      Begin
        ErrorAt(Line, Col, 'division par zero');
        FoldFailed := True;
        Exit;
      End;
      SetRealDen(L, X / Y, Line, Col);
    End
    Else If Op = '**' Then
    Begin
      If (UnitTab[R].Kind = UK_INTDEN) And (UnitTab[R].IntVal >= 0) And
         (UnitTab[R].IntVal <= 64) Then
      Begin
        X := 1;
        For I := 1 To UnitTab[R].IntVal Do
          X := X * NumReal(L);
        SetRealDen(L, X, Line, Col);
      End
      Else If NumReal(L) > 0 Then
        SetRealDen(L, Exp(Y * Ln(NumReal(L))), Line, Col)
      Else
        Exit;
    End
    Else Exit;
    FoldBinary := True;
    Exit;
  End;
  { resultat entier }
  If (UnitTab[L].Kind <> UK_INTDEN) Or (UnitTab[R].Kind <> UK_INTDEN) Then
    Exit;
  A := UnitTab[L].IntVal;
  B := UnitTab[R].IntVal;
  If Op = '+' Then SetIntDen(L, A + B, Line, Col)
  Else If Op = '-' Then SetIntDen(L, A - B, Line, Col)
  Else If Op = '*' Then SetIntDen(L, A * B, Line, Col)
  Else If (Op = 'OVER') Or (Op = '%') Or (Op = 'MOD') Or (Op = '%*') Then
  Begin
    If B = 0 Then
    Begin
      ErrorAt(Line, Col, 'division par zero');
      FoldFailed := True;
      Exit;
    End;
    If (Op = 'OVER') Or (Op = '%') Then
      SetIntDen(L, A Div B, Line, Col)
    Else
    Begin
      P := A Mod B;
      If P < 0 Then
      Begin
        If B < 0 Then P := P - B Else P := P + B;
      End;
      SetIntDen(L, P, Line, Col);
    End;
  End
  Else If Op = '**' Then
  Begin
    If (B < 0) Or (B > 31) Then Exit;
    P := 1;
    For I := 1 To B Do
    Begin
      P := P * A;
      If (P > 2147483647) Or (P < -2147483647) Then
      Begin
        ErrorAt(Line, Col, 'debordement entier dans une constante');
        P := 0;
      End;
    End;
    SetIntDen(L, P, Line, Col);
  End
  Else If (Op = 'SHL') And (B >= 0) And (B < 31) Then
    SetIntDen(L, A * (Int64(1) Shl B), Line, Col)
  Else If (Op = 'SHR') And (B >= 0) And (B < 31) Then
    SetIntDen(L, A Div (Int64(1) Shl B), Line, Col)
  Else
    Exit;
  FoldBinary := True;
End;

Function FoldUnary(Const Op : TName; A : LongInt; ResMode : Integer;
                   Line, Col : Integer) : Boolean;
Var
  V : Int64;
  X : Double;
Begin
  FoldUnary := False;
  If UnitTab[A].Kind = UK_BOOLDEN Then
  Begin
    If Op = 'NOT' Then SetBoolDen(A, UnitTab[A].IntVal = 0)
    Else Exit;
    FoldUnary := True;
    Exit;
  End;
  If UnitTab[A].Kind = UK_INTDEN Then
  Begin
    V := UnitTab[A].IntVal;
    If Op = '-' Then SetIntDen(A, -V, Line, Col)
    Else If Op = '+' Then
      V := V
    Else If Op = 'ABS' Then SetIntDen(A, Abs(V), Line, Col)
    Else If Op = 'SIGN' Then
    Begin
      If V > 0 Then V := 1 Else If V < 0 Then V := -1 Else V := 0;
      SetIntDen(A, V, Line, Col);
    End
    Else If Op = 'ODD' Then SetBoolDen(A, (V And 1) <> 0)
    Else Exit;
    FoldUnary := True;
    Exit;
  End;
  If UnitTab[A].Kind = UK_REALDEN Then
  Begin
    X := UnitTab[A].RealVal;
    If Op = '-' Then SetRealDen(A, -X, Line, Col)
    Else If Op = '+' Then
      X := X
    Else If Op = 'ABS' Then SetRealDen(A, Abs(X), Line, Col)
    Else If Op = 'SIGN' Then
    Begin
      If X > 0 Then V := 1 Else If X < 0 Then V := -1 Else V := 0;
      SetIntDen(A, V, Line, Col);
    End
    Else If Op = 'ENTIER' Then
    Begin
      If Abs(X) >= 2147483647.0 Then Exit;
      V := Trunc(X);
      If V > X Then Dec(V);
      SetIntDen(A, V, Line, Col);
    End
    Else If Op = 'ROUND' Then
    Begin
      If Abs(X) >= 2147483646.0 Then Exit;
      V := Trunc(X + 0.5);
      If V > X + 0.5 Then Dec(V);
      SetIntDen(A, V, Line, Col);
    End
    Else Exit;
    FoldUnary := True;
  End;
End;

{ Formule dyadique : operateur identifie d apres les modes des deux
  operandes, operandes coerces vers les modes de l operateur }
Function MakeDyadic(Const Op : TName; L, R : LongInt; Line, Col : Integer)
         : LongInt;
Var
  U         : LongInt;
  ML, MR, S : Integer;
Begin
  ML := NatMode(L);
  MR := NatMode(R);
  If ((Length(Op) >= 2) And (Copy(Op, Length(Op) - 1, 2) = ':=')) Or
     (Op = 'PLUSAB') Or (Op = 'MINUSAB') Or (Op = 'TIMESAB') Or
     (Op = 'DIVAB') Or (Op = 'OVERAB') Or (Op = 'MODAB') Then
    MarkAssigned(L, Line, Col);
  U := UnitNew(UK_FORMULA, Line, Col);
  UnitTab[U].Name := Op;
  UnitTab[U].A := L;
  UnitTab[U].B := R;
  UnitTab[U].IntVal := 2;
  MakeDyadic := U;
  If (ML = MD_ERROR) Or (MR = MD_ERROR) Then Exit;     { mode inconnu }
  S := SymFindOpFirm(Op, 2, ML, MR);
  If S < 0 Then
  Begin
    ErrorAt(Line, Col, 'operateur ' + Op + ' impossible pour les modes ' +
            ModeName(ML) + ' et ' + ModeName(MR));
    Exit;
  End;
  UnitTab[U].Sym := S;
  UnitTab[U].Mode := OpResult(S);
  If SymTab[S].Generic Then
  Begin
    UnitTab[U].A := CoerceUnit(L, MD_INT, STR_FIRM);
    UnitTab[U].B := CoerceName(R);
    Exit;
  End;
  L := CoerceUnit(L, OpOperand(S, 0), STR_FIRM);
  R := CoerceUnit(R, OpOperand(S, 1), STR_FIRM);
  UnitTab[U].A := L;
  UnitTab[U].B := R;
  FoldFailed := False;
  If SymTab[S].Intrinsic And
     FoldBinary(Op, L, R, ModeResolve(OpResult(S)), Line, Col) Then
  Begin
    MakeDyadic := L;                       { la formule devient constante }
    UnitTab[L].Line := Line;
    UnitTab[L].Col := Col;
  End
  Else If SymTab[S].Intrinsic And (Not FoldFailed) And
          ((Op = 'OVER') Or (Op = '%') Or (Op = 'MOD') Or (Op = '%*') Or
           (Op = '/')) And (UnitTab[R].Kind = UK_INTDEN) And
          (UnitTab[R].IntVal = 0) Then
    ErrorAt(Line, Col, 'division par zero');
End;

Function MakeMonadic(Const Op : TName; A : LongInt; Line, Col : Integer)
         : LongInt;
Var
  U         : LongInt;
  MA, S     : Integer;
Begin
  MA := NatMode(A);
  U := UnitNew(UK_FORMULA, Line, Col);
  UnitTab[U].Name := Op;
  UnitTab[U].A := A;
  UnitTab[U].IntVal := 1;
  MakeMonadic := U;
  If MA = MD_ERROR Then Exit;
  S := SymFindOpFirm(Op, 1, MA, 0);
  If S < 0 Then
  Begin
    ErrorAt(Line, Col, 'operateur monadique ' + Op +
            ' impossible pour le mode ' + ModeName(MA));
    Exit;
  End;
  UnitTab[U].Sym := S;
  UnitTab[U].Mode := OpResult(S);
  If SymTab[S].Generic Then
  Begin
    UnitTab[U].A := CoerceName(A);
    Exit;
  End;
  A := CoerceUnit(A, OpOperand(S, 0), STR_FIRM);
  UnitTab[U].A := A;
  If SymTab[S].Intrinsic And
     FoldUnary(Op, A, ModeResolve(OpResult(S)), Line, Col) Then
  Begin
    MakeMonadic := A;
    UnitTab[A].Line := Line;
    UnitTab[A].Col := Col;
  End;
End;

{ Le jeton courant est-il un operateur dyadique connu ? Retourne son
  nom et sa priorite (0 sinon) }
Function AtDyadic(Var Name : TName) : Integer;
Var
  T : TToken;
  P : Integer;
Begin
  AtDyadic := 0;
  T := TokTab[TokPos];
  If (T.Kind <> TK_OP) And (T.Kind <> TK_BOLD) Then Exit;
  Name := T.Val;
  If (Name = ':=') Or (Name = '=:') Then Exit;
  P := SymFindPrio(Name);
  { operateur utilisateur sans PRIO : priorite 1 (signalee avec -w) }
  If (P = 0) And (T.Kind = TK_BOLD) And SymOpExistsK(Name, 2, True) Then
    P := 1;
  If (P > 0) And SymOpExists(Name, 2) Then AtDyadic := P;
End;

Function AtMonadic(Var Name : TName) : Boolean;
Var
  T : TToken;
Begin
  AtMonadic := False;
  T := TokTab[TokPos];
  If (T.Kind <> TK_OP) And (T.Kind <> TK_BOLD) Then Exit;
  If (T.Kind = TK_BOLD) And (SymFindMode(T.Val) >= 0) Then Exit;
  Name := T.Val;
  AtMonadic := SymOpExists(Name, 1);
End;

{ ---- References et affectations (TODO 14) ---- }

{ Identite entre deux noms : a IS b, a ISNT b, p IS NIL }
Function MakeIdRel(Const Op : TName; L, R : LongInt; Line, Col : Integer)
         : LongInt;
Var
  U      : LongInt;
  ML, MR : Integer;
Begin
  L := CoerceName(L);
  R := CoerceName(R);
  ML := NatMode(L);
  MR := NatMode(R);
  U := UnitNew(UK_IDREL, Line, Col);
  UnitTab[U].Name := Op;
  UnitTab[U].A := L;
  UnitTab[U].B := R;
  UnitTab[U].Mode := MD_BOOL;
  MakeIdRel := U;
  If (ML = MD_ERROR) Or (MR = MD_ERROR) Then Exit;
  If Not (ModeKind(ML) In [MK_REF, MK_NIL]) Or
     Not (ModeKind(MR) In [MK_REF, MK_NIL]) Then
  Begin
    ErrorAt(Line, Col, Op + ' demande deux noms (REF) ou NIL, pas ' +
            ModeName(ML) + ' et ' + ModeName(MR));
    Exit;
  End;
  If (ModeKind(ML) = MK_REF) And (ModeKind(MR) = MK_REF) And
     Not ModeSame(ML, MR) Then
    ErrorAt(Line, Col, Op + ' entre des modes differents: ' +
            ModeName(ML) + ' et ' + ModeName(MR));
End;

{ Affectation Dest := Src (ou Src =: Dest) : le membre de gauche doit
  etre un nom (REF m) apres deprocedurage et dereferencement faibles, le
  membre de droite est coerce vers m (contexte fort) ; la valeur de
  l'affectation est le nom du membre de gauche }
Function MakeAssign(Dest, Src : LongInt; Line, Col : Integer) : LongInt;
Var
  U : LongInt;
  M : Integer;
Begin
  Dest := CoerceSoft(Dest);
  MarkAssigned(Dest, Line, Col);
  M := NatMode(Dest);
  U := UnitNew(UK_ASSIGN, Line, Col);
  UnitTab[U].A := Dest;
  UnitTab[U].B := Src;
  UnitTab[U].Mode := M;
  MakeAssign := U;
  If M = MD_ERROR Then Exit;
  If ModeKind(M) <> MK_REF Then
  Begin
    ErrorAt(Line, Col, 'le membre gauche d''une affectation doit etre ' +
            'un nom (REF), pas ' + ModeName(M));
    Exit;
  End;
  UnitTab[U].B := CoerceUnit(Src, ModeTab[ModeResolve(M)].Sub,
                             STR_STRONG);
End;

Function ParseFormula(MinPrio : Integer) : LongInt; Forward;

{ Operande : operateurs monadiques (prioritaires) puis primaire }
Function ParseOperand : LongInt;
Var
  Name : TName;
  L, C : Integer;
  A    : LongInt;
Begin
  If AtMonadic(Name) Then
  Begin
    L := TokTab[TokPos].Line;
    C := TokTab[TokPos].Col;
    ParserAdvance;
    A := ParseOperand;
    If A < 0 Then
    Begin
      ParseOperand := -1;
      Exit;
    End;
    ParseOperand := MakeMonadic(Name, A, L, C);
  End
  Else
    ParseOperand := ParsePrimary;
End;

{ Formule : operandes separes par des operateurs dyadiques, selon leurs
  priorites (association a gauche) ; -1 si l unite n est pas une
  formule connue }
Function ParseFormula(MinPrio : Integer) : LongInt;
Var
  Left, Right : LongInt;
  Name        : TName;
  P           : Integer;
  L, C        : Integer;
Begin
  Left := ParseOperand;
  If Left < 0 Then
  Begin
    ParseFormula := -1;
    Exit;
  End;
  P := AtDyadic(Name);
  If AtKw('IS') Or AtKw('ISNT') Then
  Begin
    Name := TokTab[TokPos].Val;
    P := 4;
  End;
  While (P > 0) And (P >= MinPrio) Do
  Begin
    L := TokTab[TokPos].Line;
    C := TokTab[TokPos].Col;
    ParserAdvance;
    Right := ParseFormula(P + 1);
    If Right < 0 Then
    Begin
      ParseFormula := -1;
      Exit;
    End;
    If (Name = 'IS') Or (Name = 'ISNT') Then
      Left := MakeIdRel(Name, Left, Right, L, C)
    Else
      Left := MakeDyadic(Name, Left, Right, L, C);
    P := AtDyadic(Name);
    If AtKw('IS') Or AtKw('ISNT') Then
    Begin
      Name := TokTab[TokPos].Val;
      P := 4;
    End;
  End;
  ParseFormula := Left;
End;

{ Unite jusqu a une virgule / un deux-points / une fermeture : primaire
  si elle forme toute l unite, enveloppe provisoire sinon (formules,
  conditionnelles, boucles...). Stops comme ParseOpaqueUntil. }
{ Apres une clause fermee, la primaire est complete si l expression se
  termine ou si un operateur dyadique connu suit }
Function ClauseFollowOk(K : LongInt) : Boolean;
Var
  Save : LongInt;
  Name : TName;
Begin
  ClauseFollowOk := True;
  If TokEndsExprAbs(K) Then Exit;
  Save := TokPos;
  TokPos := K;
  ClauseFollowOk := AtDyadic(Name) > 0;
  TokPos := Save;
End;

Function ParseUnitX(Stops : Integer) : LongInt;
Var
  ErrStart     : Integer;
  U, SaveUnits : LongInt;
  SavePos, R   : LongInt;
  SaveGotos    : Integer;
  Rev          : Boolean;
  OL, OC       : Integer;
Begin
  U := ParseDenotation;
  If U >= 0 Then
  Begin
    ParseUnitX := U;
    Exit;
  End;
  SavePos := TokPos;
  SaveUnits := UnitCount;
  SaveGotos := GotoCount;
  ErrStart := ErrorCount;
  U := ParseFormula(0);
  If (U >= 0) And (AtOpSym(':=') Or AtOpSym('=:')) Then
  Begin
    Rev := AtOpSym('=:');
    OL := TokTab[TokPos].Line;
    OC := TokTab[TokPos].Col;
    ParserAdvance;
    R := ParseUnitX(Stops);
    If UnitTab[R].Kind <> UK_OPAQUE Then
    Begin
      If Rev Then
        U := MakeAssign(R, U, OL, OC)
      Else
        U := MakeAssign(U, R, OL, OC);
    End
    Else
      U := -1;                         { valeur pas encore analysee }
  End;
  If (U >= 0) And TokEndsExpr(0) Then
  Begin
    ParseUnitX := U;
    Exit;
  End;
  { pas une primaire seule : l'unite n'est pas reconnue ; erreur au jeton
    ou l'analyse s'est arretee (sauf si une erreur plus precise a deja ete
    signalee), puis on reprend au debut pour sauter les jetons }
  If ErrorCount = ErrStart Then
    ParseError('expression incorrecte ou incomplete');
  TokPos := SavePos;
  UnitCount := SaveUnits;
  GotoCount := SaveGotos;
  ParseUnitX := ParseOpaqueUntil(UK_OPAQUE, Stops);
End;

{ Une unite ; les unites autres que la clause fermee, GOTO et SKIP sont
  provisoirement enveloppees (TODOs 10 a 19) }
Function ParseUnit : LongInt;
Var
  U : LongInt;
Begin
  If AtKw('BEGIN') Or
     (AtPunct('(') And ParenIsClosed And Not ParenIsRoutine And
      TokEndsExprAbs(TokAfterClose)) Then
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
    ParseUnit := ParseDeclaration
  Else
    ParseUnit := ParseUnitX(0);
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
    If N < 0 Then Exit;
    If First < 0 Then First := N Else UnitTab[Last].Next := N;
    Last := N;
    While UnitTab[Last].Next >= 0 Do Last := UnitTab[Last].Next;
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
    UK_NIL      : UnitKindName := 'NIL';
    UK_EMPTY    : UnitKindName := 'EMPTY';
    UK_COERCE   : UnitKindName := 'coercition';
    UK_IDENT    : UnitKindName := 'identificateur';
    UK_SELECT   : UnitKindName := 'selection';
    UK_SLICE    : UnitKindName := 'indexation';
    UK_TRIM     : UnitKindName := 'tranche';
    UK_CALL     : UnitKindName := 'appel';
    UK_CONSTRUCT: UnitKindName := 'constructeur';
    UK_CAST     : UnitKindName := 'conversion';
    UK_FORMULA  : UnitKindName := 'formule';
    UK_DISPLAY  : UnitKindName := 'affichage';
    UK_ASSIGN   : UnitKindName := 'affectation';
    UK_IDREL    : UnitKindName := 'identite';
    UK_IF       : UnitKindName := 'IF';
    UK_CASE     : UnitKindName := 'CASE';
    UK_PRINT    : UnitKindName := 'transput';
    UK_CONFORM  : UnitKindName := 'clause de conformite';
    UK_CONFALT  : UnitKindName := 'alternative';
    UK_LOOP     : UnitKindName := 'boucle';
    UK_INTDEN   : UnitKindName := 'denotation INT';
    UK_REALDEN  : UnitKindName := 'denotation REAL';
    UK_BOOLDEN  : UnitKindName := 'denotation BOOL';
    UK_CHARDEN  : UnitKindName := 'denotation CHAR';
    UK_STRDEN   : UnitKindName := 'denotation STRING';
    UK_VARDECL  : UnitKindName := 'variable';
    UK_IDDECL   : UnitKindName := 'identite';
    UK_MODEDECL : UnitKindName := 'MODE';
    UK_PRIODECL : UnitKindName := 'PRIO';
    UK_ROUTINE  : UnitKindName := 'texte de routine';
    UK_PROCDECL : UnitKindName := 'procedure';
    UK_DECL     : UnitKindName := 'declaration (non analysee)';
    UK_OPAQUE   : UnitKindName := 'unite (non analysee)';
  End;
End;

Function CoerceName_(K : LongInt) : TString;
Begin
  Case K Of
    1 : CoerceName_ := 'dereferencement';
    2 : CoerceName_ := 'deprocedurage';
    3 : CoerceName_ := 'elargissement';
    4 : CoerceName_ := 'enrobage';
    5 : CoerceName_ := 'union';
    6 : CoerceName_ := 'vidage';
  Else
    CoerceName_ := '?';
  End;
End;

Procedure UnitDump(U : LongInt; Depth : Integer); Forward;

Procedure UnitDumpOne(U : LongInt; Depth : Integer);
Var
  I : Integer;
  E : LongInt;
Begin
  For I := 1 To Depth Do Write('  ');
  Write(UnitKindName(UnitTab[U].Kind), ' ligne ', UnitTab[U].Line);
  Case UnitTab[U].Kind Of
    UK_LABELDEF, UK_GOTO : Write(' ', UnitTab[U].Name);
    UK_INTDEN, UK_BOOLDEN, UK_CHARDEN : Write(' ', UnitTab[U].IntVal);
    UK_REALDEN : Write(' ', UnitTab[U].RealVal:0:6);
    UK_STRDEN  : Write(' "', LitTab[UnitTab[U].IntVal], '"');
    UK_COERCE  : Write(' ', CoerceName_(UnitTab[U].IntVal), ' -> ',
                       ModeName(UnitTab[U].Mode));
    UK_IDENT   : Write(' ', UnitTab[U].Name, ' : ',
                       ModeName(UnitTab[U].Mode));
    UK_SELECT  : Write(' ', UnitTab[U].Name, ' OF (decalage ',
                       UnitTab[U].C, ') : ', ModeName(UnitTab[U].Mode));
    UK_SLICE   : Write(' ', UnitTab[U].IntVal, ' indice(s), ',
                       UnitTab[U].C, ' tranche(s) : ',
                       ModeName(UnitTab[U].Mode));
    UK_LOOP    : Write(' ', UnitTab[U].Name);
    UK_CONFALT : Write(' ', ModeName(UnitTab[U].Mode));
    UK_PRINT   : Write(' ', UnitTab[U].Name, ' ', UnitTab[U].IntVal,
                       ' element(s)');
    UK_IDREL   : Write(' ', UnitTab[U].Name);
    UK_DISPLAY : Write(' ', UnitTab[U].IntVal, ' element(s) : ',
                       ModeName(UnitTab[U].Mode));
    UK_ASSIGN  : Write(' : ', ModeName(UnitTab[U].Mode));
    UK_FORMULA : Write(' ', UnitTab[U].Name, ' : ',
                       ModeName(UnitTab[U].Mode));
    UK_CALL    : Write(' ', UnitTab[U].IntVal, ' argument(s) : ',
                       ModeName(UnitTab[U].Mode));
    UK_CONSTRUCT, UK_CAST : Write(' : ', ModeName(UnitTab[U].Mode));
    UK_VARDECL, UK_IDDECL :
      Begin
        Write(' ', UnitTab[U].Name, ' : ', ModeName(UnitTab[U].Mode));
        If UnitTab[U].C > 0 Then
          Write(' (', UnitTab[U].C, ' dimension(s))');
        If UnitTab[U].IntVal = 1 Then Write(' HEAP');
      End;
    UK_MODEDECL :
      Begin
        Write(' ', UnitTab[U].Name, ' = ');
        If ModeTab[UnitTab[U].Mode].Kind = MK_FWD Then
          Write(ModeName(ModeTab[UnitTab[U].Mode].Sub))
        Else
          Write(ModeName(UnitTab[U].Mode));
      End;
    UK_PRIODECL : Write(' ', UnitTab[U].Name, ' = ', UnitTab[U].IntVal);
    UK_ROUTINE  : Write(' : ', ModeName(UnitTab[U].Mode));
    UK_PROCDECL : Write(' ', UnitTab[U].Name, ' : ',
                        ModeName(UnitTab[U].Mode));
    UK_DECL, UK_OPAQUE :
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
  If (UnitTab[U].Kind In [UK_VARDECL, UK_IDDECL]) And
     (UnitTab[U].A >= 0) Then
  Begin
    WriteLn;
    UnitDumpOne(UnitTab[U].A, Depth + 1);
  End
  Else
    WriteLn;
  If UnitTab[U].Kind = UK_CLOSED Then
    UnitDump(UnitTab[U].A, Depth + 1)
  Else If UnitTab[U].Kind In [UK_COERCE, UK_SELECT, UK_CAST] Then
    UnitDumpOne(UnitTab[U].A, Depth + 1)
  Else If UnitTab[U].Kind In [UK_IF, UK_CASE] Then
  Begin
    UnitDump(UnitTab[U].A, Depth + 1);
    UnitDump(UnitTab[U].B, Depth + 1);
    If UnitTab[U].C >= 0 Then UnitDump(UnitTab[U].C, Depth + 1);
  End
  Else If UnitTab[U].Kind = UK_CONFORM Then
  Begin
    UnitDump(UnitTab[U].A, Depth + 1);
    UnitDump(UnitTab[U].B, Depth + 1);
    If UnitTab[U].C >= 0 Then UnitDump(UnitTab[U].C, Depth + 1);
  End
  Else If UnitTab[U].Kind = UK_CONFALT Then
    UnitDumpOne(UnitTab[U].A, Depth + 1)
  Else If UnitTab[U].Kind = UK_LOOP Then
  Begin
    If UnitTab[U].A >= 0 Then UnitDumpOne(UnitTab[U].A, Depth + 1);
    If UnitTab[U].B >= 0 Then UnitDumpOne(UnitTab[U].B, Depth + 1);
    If UnitTab[U].C >= 0 Then UnitDumpOne(UnitTab[U].C, Depth + 1);
    If UnitTab[U].D >= 0 Then UnitDump(UnitTab[U].D, Depth + 1);
    UnitDump(UnitTab[U].E, Depth + 1);
  End
  Else If UnitTab[U].Kind In [UK_FORMULA, UK_ASSIGN, UK_IDREL] Then
  Begin
    UnitDumpOne(UnitTab[U].A, Depth + 1);
    If UnitTab[U].B >= 0 Then UnitDumpOne(UnitTab[U].B, Depth + 1);
  End
  Else If UnitTab[U].Kind In [UK_SLICE, UK_CALL] Then
  Begin
    UnitDumpOne(UnitTab[U].A, Depth + 1);
    UnitDump(UnitTab[U].B, Depth + 1);
  End
  Else If UnitTab[U].Kind In [UK_CONSTRUCT, UK_DISPLAY, UK_PRINT] Then
    UnitDump(UnitTab[U].A, Depth + 1)
  Else If UnitTab[U].Kind In [UK_ROUTINE, UK_PROCDECL] Then
  Begin
    If UnitTab[U].A >= 0 Then UnitDumpOne(UnitTab[U].A, Depth + 1);
  End
  Else If UnitTab[U].Kind = UK_TRIM Then
  Begin
    If UnitTab[U].A >= 0 Then UnitDumpOne(UnitTab[U].A, Depth + 1);
    If UnitTab[U].B >= 0 Then UnitDumpOne(UnitTab[U].B, Depth + 1);
  End;
End;

Procedure UnitDump(U : LongInt; Depth : Integer);
Begin
  While U >= 0 Do
  Begin
    UnitDumpOne(U, Depth);
    U := UnitTab[U].Next;
  End;
End;

Procedure PhaseParse;
Var
  K : Integer;
Begin
  UserOpCount := 0;
  UnitCount := 0;
  TokPos := 0;
  GotoCount := 0;
  ClauseCount := 0;
  LabelCount := 0;
  OpaqueCount := 0;
  DeclCount := 0;
  If Opts.DebugMode Then
    WriteLn('Table des symboles (portees refermees, de la plus interne ',
            'a la plus externe) :');
  ScopeEnter(SCK_PROGRAM);
  UnitRoot := UnitNew(UK_SERIAL, 1, 1);
  UnitTab[UnitRoot].A := ParseSerial(True);
  ResolveGotos;
  If Opts.Warnings Then
  Begin
    WarnUnusedLabels;
    For K := 0 To UserOpCount - 1 Do
      If Not PrioVisibleFrom(SymTab[UserOpTab[K]].Scope,
                             SymTab[UserOpTab[K]].Name) Then
        WarnAt(SymTab[UserOpTab[K]].Line, SymTab[UserOpTab[K]].Col,
               'operateur ' + SymTab[UserOpTab[K]].Name +
               ' sans PRIO : priorite 1 par defaut');
  End;
  ScopeLeave;
  If Opts.Verbose Then
  Begin
    Write('  ', UnitCount, ' unite(s), ', ClauseCount,
          ' clause(s) fermee(s), ', LabelCount, ' etiquette(s), ',
          GotoCount, ' goto, ', DeclCount, ' declaration(s)');
    If OpaqueCount > 0 Then
      Write(', ', OpaqueCount, ' unite(s) non analysee(s)');
    WriteLn;
  End;
  If Opts.DebugMode Then
  Begin
    WriteLn('Arbre d''unites (', UnitCount, ' noeuds) :');
    UnitDump(UnitTab[UnitRoot].A, 1);
    ModeDump(PreludeModes);
  End;
End;

{ ============================================================
  SECTION 11 - COERCITIONS, MODES ET GENERATION (TODO 09, 11 a 19)
  ============================================================ }
{ ---- Passe de resolution des modes ---- }

{ Est-ce une unite (par opposition a une declaration ou une etiquette) ? }
Function IsValueUnit(U : LongInt) : Boolean;
Begin
  IsValueUnit := Not (UnitTab[U].Kind In [UK_LABELDEF, UK_VARDECL,
                      UK_IDDECL, UK_MODEDECL, UK_PRIODECL,
                      UK_PROCDECL, UK_DECL]);
End;

{ Remplace dans une chaine l element Old par New (meme suivant) }
Procedure ReplaceItem(Var First : LongInt; Old, New : LongInt);
Var
  P : LongInt;
Begin
  If Old = New Then Exit;
  UnitTab[New].Next := UnitTab[Old].Next;
  If First = Old Then
    First := New
  Else
  Begin
    P := First;
    While (P >= 0) And (UnitTab[P].Next <> Old) Do P := UnitTab[P].Next;
    If P >= 0 Then UnitTab[P].Next := New;
  End;
End;

Procedure ModesDecl(U : LongInt);
Var
  Init, New, P, Prev, Nxt : LongInt;
Begin
  { bornes d'un tableau : entieres }
  Prev := -1;
  P := UnitTab[U].B;
  While P >= 0 Do
  Begin
    Nxt := UnitTab[P].Next;
    New := CoerceUnit(P, MD_INT, STR_MEEK);
    UnitTab[New].Next := Nxt;
    If Prev < 0 Then UnitTab[U].B := New Else UnitTab[Prev].Next := New;
    Prev := New;
    P := Nxt;
  End;
  Init := UnitTab[U].A;
  If Init >= 0 Then
  Begin
    New := CoerceUnit(Init, UnitTab[U].Mode, STR_STRONG);
    UnitTab[U].A := New;
    { affichage de tableau a bornes constantes : nombre d'elements }
    If (UnitTab[New].Kind = UK_DISPLAY) And (UnitTab[U].C = 1) And
       (UnitTab[UnitTab[U].B].Kind = UK_INTDEN) And
       (UnitTab[UnitTab[UnitTab[U].B].Next].Kind = UK_INTDEN) Then
    Begin
      P := UnitTab[UnitTab[UnitTab[U].B].Next].IntVal -
           UnitTab[UnitTab[U].B].IntVal + 1;
      If P <> UnitTab[New].IntVal Then
        ErrorAt(UnitTab[New].Line, UnitTab[New].Col,
                'affichage de ' + ItoS(UnitTab[New].IntVal) +
                ' element(s) pour un tableau de ' + ItoS(P));
    End;
  End;
End;

{ Clause serie : les unites autres que la derniere sont videes ; la
  derniere prend le mode Want }
Function ModesSerial(First : LongInt; Want : Integer) : LongInt;
Var
  P, Last, New : LongInt;
  Head         : LongInt;
Begin
  Head := First;
  Last := -1;
  P := First;
  While P >= 0 Do
  Begin
    If IsValueUnit(P) Then Last := P;
    P := UnitTab[P].Next;
  End;
  P := First;
  While P >= 0 Do
  Begin
    If UnitTab[P].Kind In [UK_VARDECL, UK_IDDECL] Then
      ModesDecl(P)
    Else If IsValueUnit(P) Then
    Begin
      If P = Last Then
        New := CoerceUnit(P, Want, STR_STRONG)
      Else
        New := CoerceUnit(P, MD_VOID, STR_STRONG);
      If New <> P Then
      Begin
        ReplaceItem(Head, P, New);
        P := New;
      End;
    End;
    P := UnitTab[P].Next;
  End;
  ModesSerial := Head;
End;

Procedure PhaseModes;
Begin
  CoerceCount := 0;
  UnitTab[UnitRoot].A := ModesSerial(UnitTab[UnitRoot].A, MD_VOID);
  If Opts.Verbose Then
    WriteLn('  ', CoerceCount, ' coercition(s) inseree(s)');
  If Opts.DebugMode Then
  Begin
    WriteLn('Arbre d''unites apres coercitions :');
    UnitDump(UnitTab[UnitRoot].A, 1);
  End;
End;

Procedure GenUnit(U : LongInt); Forward;
Procedure GenOne(U : LongInt); Forward;
Procedure GenNilCheck; Forward;
Function MayBeNil(U : LongInt) : Boolean; Forward;

Var
  GenFrame : Integer;     { portee de la procedure en cours, -1 : main  }
  GenLevel : Integer;     { niveau de procedure du code en cours      }

{ Operande memoire de l objet d un symbole (segment de donnees ou
  cadre) a Disp octets de son debut. Un objet d un cadre englobant est
  atteint par la chaine des liens statiques ([cadre + 8]) : le code
  qui la parcourt laisse le cadre voulu dans EBX. }
Function SymCell(S : Integer; Disp : LongInt; Size : Byte) : TOperand;
Var
  Base : TReg;
  Lv   : Integer;
  K    : Integer;
Begin
  If SymTab[S].Storage = SC_STATIC Then
  Begin
    SymCell := OpMemSym(Intern(SymTab[S].AsmName), Disp, Size);
    Exit;
  End;
  Base := R_EBP;
  Lv := ScopeTab[SymTab[S].Scope].Level;
  If Lv < GenLevel Then
  Begin
    Emit(OP_MOV, OpReg(R_EBX), OpMem(R_EBP, 8, 4));
    For K := 2 To GenLevel - Lv Do
      Emit(OP_MOV, OpReg(R_EBX), OpMem(R_EBX, 8, 4));
    Base := R_EBX;
  End;
  If SymTab[S].Storage = SC_PARAM Then
    SymCell := OpMem(Base, Disp + SymTab[S].Offset, Size)
  Else
    SymCell := OpMem(Base, Disp - SymTab[S].Offset, Size);
End;

{ Cellule temporaire : dans le segment de donnees (T >= 0, indice du
  nom) ou, dans une procedure, dans le cadre (T < 0 : [EBP + T]) }
Var
  TempSeq : LongInt;

Function NewTemp(Size : LongInt) : Integer;
Var
  N : Integer;
Begin
  If Size < 4 Then Size := 4;
  If GenFrame >= 0 Then
  Begin
    ScopeTab[GenFrame].FrameBytes :=
      ScopeTab[GenFrame].FrameBytes + ((Size + 3) And -4);
    If ScopeTab[GenFrame].FrameBytes > 30000 Then
      FatalError('cadre de procedure trop grand (max 30000 octets)');
    NewTemp := -ScopeTab[GenFrame].FrameBytes;
    Exit;
  End;
  Inc(TempSeq);
  N := Intern(MangleTemp(TempSeq));
  DataAddZero(N, Size);
  NewTemp := N;
End;

Function TMem(T : Integer; Disp : LongInt; Size : Byte) : TOperand;
Begin
  If T < 0 Then
    TMem := OpMem(R_EBP, T + Disp, Size)
  Else
    TMem := OpMemSym(T, Disp, Size);
End;

{ R = adresse du temporaire T }
Procedure TAddr(R : TReg; T : Integer);
Begin
  If T < 0 Then
    Emit(OP_LEA, OpReg(R), OpMem(R_EBP, T, 4))
  Else
    Emit(OP_MOV, OpReg(R), OpOffset(T));
End;

{ Destination d un rangement : un symbole (Sym >= 0) ou un temporaire
  anonyme (Lbl) }
Function DestOp(Sym, Lbl : Integer; Disp : LongInt; Size : Byte)
         : TOperand;
Begin
  If Sym >= 0 Then
    DestOp := SymCell(Sym, Disp, Size)
  Else
    DestOp := TMem(Lbl, Disp, Size);
End;

{ EDI = adresse de la destination }
Procedure DestAddrEDI(Sym, Lbl : Integer; Disp : LongInt);
Begin
  If (Sym >= 0) And (SymTab[Sym].Storage <> SC_STATIC) Then
    Emit(OP_LEA, OpReg(R_EDI), SymCell(Sym, Disp, 4))
  Else If (Sym < 0) And (Lbl < 0) Then
    Emit(OP_LEA, OpReg(R_EDI), OpMem(R_EBP, Lbl + Disp, 4))
  Else
  Begin
    If Sym >= 0 Then Lbl := Intern(SymTab[Sym].AsmName);
    Emit(OP_MOV, OpReg(R_EDI), OpOffset(Lbl));
    If Disp <> 0 Then
      Emit(OP_ADD, OpReg(R_EDI), OpImm(Disp));
  End;
End;

{ Classe de representation d un mode : 0 vide, 1 mot de 4 octets dans
  EAX, 2 reel dans ST(0), 3 objet en memoire (adresse dans EAX), 4
  procedure }
Function ValClass(M : Integer) : Integer;
Begin
  Case ModeKind(M) Of
    MK_VOID                          : ValClass := 0;
    MK_REAL                          : ValClass := 2;
    MK_STRUCT, MK_ROW, MK_UNION      : ValClass := 3;
    MK_PROC                          : ValClass := 4;
  Else
    ValClass := 1;
  End;
End;

{ Range une denotation dans la destination, comme valeur de mode M
  (INT, REAL, BOOL, CHAR, BITS, STRING) }
Procedure GenStoreDenotation(Sym, Lbl : Integer; Disp : LongInt;
                             M : Integer; Init : LongInt);
Var
  Txt : TString;
  L   : Integer;
Begin
  Case UnitTab[Init].Kind Of
    UK_INTDEN:
      If M = MD_REAL Then
      Begin
        Emit1(OP_FLD, OpMemSym(DataReal(UnitTab[Init].IntVal), 0, 8));
        Emit1(OP_FSTP, DestOp(Sym, Lbl, Disp, 8));
      End
      Else
        Emit(OP_MOV, DestOp(Sym, Lbl, Disp, 4),
             OpImm(UnitTab[Init].IntVal));
    UK_REALDEN:
      Begin
        Emit1(OP_FLD, OpMemSym(DataReal(UnitTab[Init].RealVal), 0, 8));
        Emit1(OP_FSTP, DestOp(Sym, Lbl, Disp, 8));
      End;
    UK_BOOLDEN, UK_CHARDEN, UK_STRDEN:
      If M = MD_STRING Then
      Begin
        If UnitTab[Init].Kind = UK_STRDEN Then
          Txt := LitTab[UnitTab[Init].IntVal]
        Else
          Txt := Chr(UnitTab[Init].IntVal);
        L := DataStr(Txt);
        Emit(OP_MOV, OpReg(R_EAX), OpOffset(L));
        Emit(OP_MOV, DestOp(Sym, Lbl, Disp, 4), OpReg(R_EAX));
        Emit(OP_MOV, DestOp(Sym, Lbl, Disp + 4, 4), OpImm(1));
        Emit(OP_MOV, DestOp(Sym, Lbl, Disp + 8, 4), OpImm(Length(Txt)));
        Emit(OP_MOV, DestOp(Sym, Lbl, Disp + 12, 4), OpImm(1));
      End
      Else If M = MD_CHAR Then
        Emit(OP_MOV, DestOp(Sym, Lbl, Disp, 1),
             OpImm(UnitTab[Init].IntVal))
      Else
        Emit(OP_MOV, DestOp(Sym, Lbl, Disp, 4),
             OpImm(UnitTab[Init].IntVal));
  End;
End;

{ Range la valeur calculee (EAX, ST(0) ou adresse dans EAX) de mode M
  dans la destination }
Procedure StoreValue(Sym, Lbl : Integer; Disp : LongInt; M : Integer);
Begin
  If (Sym >= 0) And SymTab[Sym].Heap Then
  Begin
    { objet HEAP : la cellule du symbole contient son adresse }
    Case ValClass(M) Of
      1 :
        Begin
          Emit(OP_MOV, OpReg(R_EDX), SymCell(Sym, 0, 4));
          If ModeKind(M) = MK_CHAR Then
            Emit(OP_MOV, OpMem(R_EDX, Disp, 1), OpReg(R_AL))
          Else
            Emit(OP_MOV, OpMem(R_EDX, Disp, 4), OpReg(R_EAX));
        End;
      2 :
        Begin
          Emit(OP_MOV, OpReg(R_EDX), SymCell(Sym, 0, 4));
          Emit1(OP_FSTP, OpMem(R_EDX, Disp, 8));
        End;
      3, 4 :
        Begin
          Emit(OP_MOV, OpReg(R_ESI), OpReg(R_EAX));
          Emit(OP_MOV, OpReg(R_EDI), SymCell(Sym, 0, 4));
          If Disp <> 0 Then
            Emit(OP_ADD, OpReg(R_EDI), OpImm(Disp));
          Emit(OP_MOV, OpReg(R_ECX), OpImm(ModeSize(M) Div 4));
          Emit0(OP_REP_MOVSD);
        End;
    End;
    Exit;
  End;
  Case ValClass(M) Of
    1 : If ModeKind(M) = MK_CHAR Then
          Emit(OP_MOV, DestOp(Sym, Lbl, Disp, 1), OpReg(R_AL))
        Else
          Emit(OP_MOV, DestOp(Sym, Lbl, Disp, 4), OpReg(R_EAX));
    2 : Emit1(OP_FSTP, DestOp(Sym, Lbl, Disp, 8));
    3, 4 :
      Begin
        Emit(OP_MOV, OpReg(R_ESI), OpReg(R_EAX));
        DestAddrEDI(Sym, Lbl, Disp);
        Emit(OP_MOV, OpReg(R_ECX), OpImm(ModeSize(M) Div 4));
        Emit0(OP_REP_MOVSD);
      End;
  End;
End;

{ Charge dans EAX l adresse de l objet d un symbole }
Procedure LoadSymAddress(S : Integer);
Begin
  If SymTab[S].Heap Then
    Emit(OP_MOV, OpReg(R_EAX), SymCell(S, 0, 4))
  Else If SymTab[S].Storage = SC_STATIC Then
    Emit(OP_MOV, OpReg(R_EAX), OpOffset(Intern(SymTab[S].AsmName)))
  Else
    Emit(OP_LEA, OpReg(R_EAX), SymCell(S, 0, 4));
End;

{ Charge la valeur d un objet dont EAX contient l adresse }
Procedure LoadThrough(M : Integer);
Begin
  Case ValClass(M) Of
    1 : If ModeKind(M) = MK_CHAR Then
          Emit(OP_MOVZX, OpReg(R_EAX), OpMem(R_EAX, 0, 1))
        Else
          Emit(OP_MOV, OpReg(R_EAX), OpMem(R_EAX, 0, 4));
    2 : Emit1(OP_FLD, OpMem(R_EAX, 0, 8));
  End;
End;

Procedure GenValue(U : LongInt); Forward;

Procedure GenSelect(U : LongInt);
Var
  M : Integer;
Begin
  GenValue(UnitTab[U].A);
  If MayBeNil(UnitTab[U].A) Then GenNilCheck;
  If UnitTab[U].C <> 0 Then
    Emit(OP_ADD, OpReg(R_EAX), OpImm(UnitTab[U].C));
  M := UnitTab[U].Mode;
  If ModeKind(M) <> MK_REF Then
    LoadThrough(M);               { selection dans une valeur }
End;

Procedure GenConstruct(U : LongInt);
Var
  T, I : Integer;
  A    : LongInt;
  M    : Integer;
Begin
  M := UnitTab[U].Mode;
  T := NewTemp(ModeSize(M));
  A := UnitTab[U].A;
  I := 0;
  While A >= 0 Do
  Begin
    GenValue(A);
    StoreValue(-1, T, ModeFieldOffset(M, I), ModeFieldMode(M, I));
    A := UnitTab[A].Next;
    Inc(I);
  End;
  TAddr(R_EAX, T);
End;

{ ---- Procedures et appels (TODO 16) ----
  Convention d'appel : arguments empiles de droite a gauche (le premier
  a l'adresse la plus basse), puis l'adresse du resultat si celui-ci
  est un objet en memoire (structure, tableau, procedure), puis le lien
  statique ; l'appelee nettoie la pile (RET n). Resultat : INT, BOOL,
  CHAR, REF dans EAX, REAL dans ST(0), objet en memoire recopie a
  l'adresse fournie (EAX = cette adresse). Une valeur de mode PROC est
  une paire (entree, lien statique) de 8 octets. }

{ Le mode M est-il rendu par adresse ? }
Function ResultInMemory(M : Integer) : Boolean;
Begin
  ResultInMemory := ValClass(M) In [3, 4];
End;

{ ECX = cadre du niveau Lv (0 : programme principal), obtenu depuis le
  cadre courant par la chaine des liens statiques }
Procedure LoadFrameECX(Lv : Integer);
Var
  K : Integer;
Begin
  If GenLevel <= Lv Then
    Emit(OP_MOV, OpReg(R_ECX), OpReg(R_EBP))
  Else
  Begin
    Emit(OP_MOV, OpReg(R_ECX), OpMem(R_EBP, 8, 4));
    For K := 2 To GenLevel - Lv Do
      Emit(OP_MOV, OpReg(R_ECX), OpMem(R_ECX, 8, 4));
  End;
End;

{ Niveau de la portee ou la procedure du symbole S est declaree }
Function ProcDeclLevel(S : Integer) : Integer;
Begin
  ProcDeclLevel := ScopeTab[SymTab[S].Scope].Level;
End;

{ L'unite designe-t-elle directement une procedure declaree (PROC nom =) ? }
Function DirectProc(U : LongInt) : Boolean;
Begin
  DirectProc := (UnitTab[U].Kind = UK_IDENT) And (UnitTab[U].Sym >= 0) And
                (SymTab[UnitTab[U].Sym].Kind = SK_PROC);
End;

{ Empile la valeur d'un argument (deja coercee vers le mode du
  parametre) }
Procedure GenPushArg(A : LongInt);
Var
  M  : Integer;
  Sz : LongInt;
Begin
  M := ModeResolve(UnitTab[A].Mode);
  GenValue(A);
  Case ValClass(M) Of
    1 : Emit1(OP_PUSH, OpReg(R_EAX));
    2 :
      Begin
        Emit(OP_SUB, OpReg(R_ESP), OpImm(8));
        Emit1(OP_FSTP, OpMem(R_ESP, 0, 8));
      End;
    3, 4 :
      Begin
        Sz := (ModeSize(M) + 3) And -4;
        Emit(OP_SUB, OpReg(R_ESP), OpImm(Sz));
        Emit(OP_MOV, OpReg(R_ESI), OpReg(R_EAX));
        Emit(OP_MOV, OpReg(R_EDI), OpReg(R_ESP));
        Emit(OP_MOV, OpReg(R_ECX), OpImm(Sz Div 4));
        Emit0(OP_REP_MOVSD);
      End;
  End;
End;

{ Fin d'un appel direct de la procedure ou de l'operateur S, arguments
  deja empiles : adresse du resultat, lien statique, CALL }
Procedure GenCallDirect(S : Integer; Res : Integer);
Var
  RT : Integer;
Begin
  If ResultInMemory(Res) Then
  Begin
    RT := NewTemp(ModeSize(Res));
    TAddr(R_EAX, RT);
    Emit1(OP_PUSH, OpReg(R_EAX));
  End;
  LoadFrameECX(ProcDeclLevel(S));
  Emit1(OP_PUSH, OpReg(R_ECX));
  Emit1(OP_CALL, OpLabel(Intern(SymTab[S].AsmName)));
End;

{ Formule dont l'operateur est defini par l'utilisateur : appel }
Procedure GenOpCall(U : LongInt);
Var
  S : Integer;
Begin
  S := UnitTab[U].Sym;
  If UnitTab[U].IntVal = 2 Then GenPushArg(UnitTab[U].B);
  GenPushArg(UnitTab[U].A);
  GenCallDirect(S, ModeResolve(OpResult(S)));
End;

{ ---- Transput et procedures standard (TODO 19) ----
  Routines du runtime (TODO 22), arguments dans les registres, EAX, ECX,
  EDX, ESI, EDI detruits : WRITEINT (EAX), WRITEREAL (ST(0), depile),
  WRITEBOOL (EAX), WRITECHAR (EAX), WRITESTR (EAX = descripteur),
  NEWLINE, SPACE ; READINT (EAX), READREAL (ST(0)), READCHAR (EAX),
  READSTR (EAX = descripteur d'une nouvelle chaine) ; WHOLE (EAX = n,
  ECX = largeur, EAX = descripteur d'une nouvelle chaine). }

Procedure CallRT(Const Name : TName);
Begin
  Emit1(OP_CALL, OpLabel(Intern(MangleRT(Name))));
End;

{ Un element de print }
Procedure GenPrintItem(A : LongInt);
Var
  M : Integer;
Begin
  M := ModeResolve(UnitTab[A].Mode);
  If IsPrintMarker(A) Then
  Begin
    If UnitTab[A].Name = 'newline' Then CallRT('NEWLINE') Else CallRT('SPACE');
    Exit;
  End;
  If UnitTab[A].Mode = MD_ERROR Then
  Begin
    EmitComment('element de print pas encore genere');
    Exit;
  End;
  GenValue(A);
  Case ModeKind(M) Of
    MK_INT, MK_BITS : CallRT('WRITEINT');
    MK_REAL         : CallRT('WRITEREAL');
    MK_BOOL         : CallRT('WRITEBOOL');
    MK_CHAR         : CallRT('WRITECHAR');
  Else
    If ModeIsString(M) Then CallRT('WRITESTR');
  End;
End;

{ Un nom de read : lecture puis rangement a l'adresse du nom }
Procedure GenReadItem(A : LongInt);
Var
  M : Integer;
Begin
  If IsPrintMarker(A) Then Exit;
  If UnitTab[A].Mode = MD_ERROR Then
  Begin
    EmitComment('element de read pas encore genere');
    Exit;
  End;
  M := ModeResolve(ModeTab[ModeResolve(UnitTab[A].Mode)].Sub);
  GenValue(A);
  If MayBeNil(A) Then GenNilCheck;
  Emit1(OP_PUSH, OpReg(R_EAX));
  Case ModeKind(M) Of
    MK_INT :
      Begin
        CallRT('READINT');
        Emit1(OP_POP, OpReg(R_EDX));
        Emit(OP_MOV, OpMem(R_EDX, 0, 4), OpReg(R_EAX));
      End;
    MK_REAL :
      Begin
        CallRT('READREAL');
        Emit1(OP_POP, OpReg(R_EDX));
        Emit1(OP_FSTP, OpMem(R_EDX, 0, 8));
      End;
    MK_CHAR :
      Begin
        CallRT('READCHAR');
        Emit1(OP_POP, OpReg(R_EDX));
        Emit(OP_MOV, OpMem(R_EDX, 0, 1), OpReg(R_AL));
      End;
  Else
    Begin
      CallRT('READSTR');
      Emit1(OP_POP, OpReg(R_EDI));
      Emit(OP_MOV, OpReg(R_ESI), OpReg(R_EAX));
      Emit(OP_MOV, OpReg(R_ECX), OpImm(4));
      Emit0(OP_REP_MOVSD);
    End;
  End;
End;

Procedure GenPrint(U : LongInt);
Var
  A : LongInt;
Begin
  A := UnitTab[U].A;
  While A >= 0 Do
  Begin
    If UnitTab[U].Name = 'read' Then GenReadItem(A) Else GenPrintItem(A);
    A := UnitTab[A].Next;
  End;
End;

{ Le callee est-il une procedure standard du prelude (whole, sqrt...) ? }
Function StdCallee(U : LongInt) : Boolean;
Begin
  StdCallee := (UnitTab[U].Kind = UK_IDENT) And (UnitTab[U].Sym >= 0) And
               (SymTab[UnitTab[U].Sym].Kind = SK_STD) And
               (ModeKind(SymTab[UnitTab[U].Sym].Mode) = MK_PROC);
End;

{ Appel d'une procedure standard : whole par le runtime, les fonctions
  mathematiques en ligne (x87) }
Procedure GenStdCall(Const Name : TName; Args : LongInt);
Begin
  If Name = 'whole' Then
  Begin
    GenValue(UnitTab[Args].Next);
    Emit1(OP_PUSH, OpReg(R_EAX));
    GenValue(Args);
    Emit1(OP_POP, OpReg(R_ECX));
    CallRT('WHOLE');
    Exit;
  End;
  GenValue(Args);                            { argument REAL dans ST(0) }
  If Name = 'sqrt' Then
    Emit0(OP_FSQRT)
  Else If Name = 'sin' Then
    Emit0(OP_FSIN)
  Else If Name = 'cos' Then
    Emit0(OP_FCOS)
  Else If Name = 'tan' Then
  Begin
    Emit1(OP_FLD, OpST(0));
    Emit0(OP_FSIN);
    Emit1(OP_FXCH, OpST(1));
    Emit0(OP_FCOS);
    Emit(OP_FDIVP, OpST(1), OpST(0));
  End
  Else If Name = 'arctan' Then
  Begin
    Emit0(OP_FLD1);
    Emit0(OP_FPATAN);
  End
  Else If Name = 'ln' Then
  Begin
    Emit0(OP_FLDLN2);
    Emit1(OP_FXCH, OpST(1));
    Emit0(OP_FYL2X);
  End
  Else If Name = 'exp' Then
  Begin
    { 2 ** (x log2 e) = 2 ** frac * 2 ** n }
    Emit0(OP_FLDL2E);
    Emit(OP_FMULP, OpST(1), OpST(0));
    Emit1(OP_FLD, OpST(0));
    Emit0(OP_FRNDINT);
    Emit1(OP_FXCH, OpST(1));
    Emit(OP_FSUB, OpST(0), OpST(1));
    Emit0(OP_F2XM1);
    Emit0(OP_FLD1);
    Emit(OP_FADDP, OpST(1), OpST(0));
    Emit0(OP_FSCALE);
    Emit1(OP_FSTP, OpST(1));
  End
  Else
    EmitComment('procedure standard ' + Name + ' pas encore generee');
End;

{ Appel de la procedure Callee (mode PROC) avec les arguments Args }
Procedure GenCallCore(Callee, Args : LongInt; PM : Integer);
Var
  Arr   : Array[0..MAX_FIELD - 1] Of LongInt;
  N, K  : Integer;
  A     : LongInt;
  Res   : Integer;
  RT    : Integer;
  Agg   : Boolean;
Begin
  If StdCallee(Callee) Then
  Begin
    GenStdCall(SymTab[UnitTab[Callee].Sym].Name, Args);
    Exit;
  End;
  PM := ModeResolve(PM);
  Res := ModeResolve(ModeTab[PM].Sub);
  N := 0;
  A := Args;
  While (A >= 0) And (N < MAX_FIELD) Do
  Begin
    Arr[N] := A;
    Inc(N);
    A := UnitTab[A].Next;
  End;
  For K := N - 1 Downto 0 Do
    GenPushArg(Arr[K]);
  If DirectProc(Callee) Then
    GenCallDirect(UnitTab[Callee].Sym, Res)
  Else
  Begin
    Agg := ResultInMemory(Res);
    RT := 0;
    If Agg Then RT := NewTemp(ModeSize(Res));
    GenValue(Callee);                      { EAX = adresse de la paire }
    Emit(OP_MOV, OpReg(R_ESI), OpReg(R_EAX));
    If Agg Then
    Begin
      TAddr(R_ECX, RT);
      Emit1(OP_PUSH, OpReg(R_ECX));
    End;
    Emit1(OP_PUSH, OpMem(R_ESI, 4, 4));
    Emit1(OP_CALL, OpMem(R_ESI, 0, 4));
  End;
End;

Procedure GenCall(U : LongInt);
Begin
  GenCallCore(UnitTab[U].A, UnitTab[U].B, NatMode(UnitTab[U].A));
End;

{ Valeur d'une procedure declaree : paire (entree, lien) dans un
  temporaire ; EAX = adresse de la paire }
Procedure GenProcValue(S : Integer);
Var
  T : Integer;
Begin
  T := NewTemp(8);
  Emit(OP_MOV, TMem(T, 0, 4), OpOffset(Intern(SymTab[S].AsmName)));
  LoadFrameECX(ProcDeclLevel(S));
  Emit(OP_MOV, TMem(T, 4, 4), OpReg(R_ECX));
  TAddr(R_EAX, T);
End;

{ Corps d'une routine, ecrit a part (DeferTab) : prologue, variables
  locales mises a zero, corps, recopie d'un resultat en memoire,
  epilogue }
Procedure GenRoutineBody(R : LongInt);
Var
  Start, Fix         : LongInt;
  SaveFrame, SaveLvl : Integer;
  PM, Res            : Integer;
  Lbl                : Integer;
  N                  : LongInt;
  I                  : Integer;
Begin
  If UnitTab[R].D <> 0 Then Exit;
  UnitTab[R].D := 1;
  If UnitTab[R].A < 0 Then Exit;
  If UnitTab[R].Sym >= 0 Then
    Lbl := Intern(SymTab[UnitTab[R].Sym].AsmName)
  Else
  Begin
    Lbl := NewLabel;
  End;
  UnitTab[R].C := Lbl;
  PM := ModeResolve(UnitTab[R].Mode);
  Res := ModeResolve(ModeTab[PM].Sub);
  SaveFrame := GenFrame;
  SaveLvl := GenLevel;
  GenFrame := UnitTab[R].Scope;
  GenLevel := ScopeTab[GenFrame].Level;
  Start := CodeCount;
  EmitBlank;
  If UnitTab[R].Sym >= 0 Then
    EmitComment('procedure ' + SymTab[UnitTab[R].Sym].Name + ' : ' +
                ModeName(PM))
  Else
    EmitComment('routine ligne ' + ItoS(UnitTab[R].Line) + ' : ' +
                ModeName(PM));
  EmitLabel(Lbl);
  Emit1(OP_PUSH, OpReg(R_EBP));
  Emit(OP_MOV, OpReg(R_EBP), OpReg(R_ESP));
  Fix := CodeCount;
  Emit(OP_SUB, OpReg(R_ESP), OpImm(0));
  Emit(OP_MOV, OpReg(R_EDI), OpReg(R_ESP));
  Emit(OP_XOR, OpReg(R_EAX), OpReg(R_EAX));
  Emit(OP_MOV, OpReg(R_ECX), OpImm(0));
  Emit0(OP_REP_STOSD);
  GenValue(UnitTab[R].A);
  If ResultInMemory(Res) Then
  Begin
    Emit(OP_MOV, OpReg(R_ESI), OpReg(R_EAX));
    Emit(OP_MOV, OpReg(R_EDI), OpMem(R_EBP, 12, 4));
    Emit(OP_MOV, OpReg(R_ECX), OpImm(ModeSize(Res) Div 4));
    Emit0(OP_REP_MOVSD);
    Emit(OP_MOV, OpReg(R_EAX), OpMem(R_EBP, 12, 4));
  End;
  Emit(OP_MOV, OpReg(R_ESP), OpReg(R_EBP));
  Emit1(OP_POP, OpReg(R_EBP));
  Emit1(OP_RET, OpImm(UnitTab[R].IntVal));
  { taille definitive du cadre : locales et temporaires }
  N := (ScopeTab[GenFrame].FrameBytes + 3) And -4;
  If N = 0 Then
  Begin
    For I := 0 To 4 Do CodeTab[Fix + I].Op := OP_NOP;
  End
  Else
  Begin
    CodeTab[Fix].B.Imm := N;
    CodeTab[Fix + 3].B.Imm := N Div 4;
  End;
  MoveToDeferred(Start);
  GenFrame := SaveFrame;
  GenLevel := SaveLvl;
End;

{ Texte de routine utilise comme valeur : paire (entree, cadre courant) }
Procedure GenRoutineValue(R : LongInt);
Var
  T : Integer;
Begin
  GenRoutineBody(R);
  If UnitTab[R].C < 0 Then
  Begin
    Emit(OP_MOV, OpReg(R_EAX), OpImm(0));
    Exit;
  End;
  T := NewTemp(8);
  Emit(OP_MOV, TMem(T, 0, 4), OpOffset(UnitTab[R].C));
  Emit(OP_MOV, TMem(T, 4, 4), OpReg(R_EBP));
  TAddr(R_EAX, T);
End;

Procedure GenCoerce(U : LongInt);
Var
  C  : LongInt;
  T, CT : Integer;
  CM : Integer;
Begin
  C := UnitTab[U].A;
  CM := UnitTab[C].Mode;
  Case UnitTab[U].IntVal Of
    CO_DEREF:
      Begin
        GenValue(C);
        If MayBeNil(C) Then GenNilCheck;
        LoadThrough(UnitTab[U].Mode);
      End;
    CO_WIDEN:
      Begin
        GenValue(C);
        Emit1(OP_PUSH, OpReg(R_EAX));
        Emit1(OP_FILD, OpMem(R_ESP, 0, 4));
        Emit(OP_ADD, OpReg(R_ESP), OpImm(4));
      End;
    CO_VOID:
      Begin
        GenValue(C);
        If ValClass(CM) = 2 Then Emit1(OP_FSTP, OpST(0));
      End;
    CO_ROW:
      Begin
        { valeur vers tableau d'un element }
        T := NewTemp(ModeSize(CM));
        GenValue(C);
        StoreValue(-1, T, 0, CM);
        Emit(OP_MOV, OpReg(R_EAX), OpImm(0));
        TAddr(R_EAX, T);
        CT := NewTemp(16);
        Emit(OP_MOV, TMem(CT, 0, 4), OpReg(R_EAX));
        Emit(OP_MOV, TMem(CT, 4, 4), OpImm(1));
        Emit(OP_MOV, TMem(CT, 8, 4), OpImm(1));
        Emit(OP_MOV, TMem(CT, 12, 4), OpImm(ModeSize(CM)));
        TAddr(R_EAX, CT);
      End;
    CO_DEPROC:
      GenCallCore(C, -1, CM);
    CO_UNITE:
      If ModeKind(CM) = MK_UNION Then
      Begin
        { union vers une union plus large : meme etiquettes }
        T := NewTemp(ModeSize(UnitTab[U].Mode));
        GenValue(C);
        StoreValue(-1, T, 0, CM);
        TAddr(R_EAX, T);
      End
      Else
      Begin
        T := NewTemp(ModeSize(UnitTab[U].Mode));
        Emit(OP_MOV, TMem(T, 0, 4), OpImm(UnitTab[U].B));
        GenValue(C);
        StoreValue(-1, T, 4, CM);
        TAddr(R_EAX, T);
      End;
  Else
    Begin
      GenValue(C);
      EmitComment('coercition ligne ' + ItoS(UnitTab[U].Line) +
                  ' pas encore generee');
    End;
  End;
End;

{ ---- Formules (TODO 11) ---- }

Procedure GenCompound(U : LongInt); Forward;
Function IsCompoundOp(Const Op : TName) : Boolean; Forward;

{ Charge l unite U comme reel dans ST(0) (un INT est converti) }
Procedure GenAsReal(U : LongInt);
Begin
  GenValue(U);
  If ValClass(UnitTab[U].Mode) <> 2 Then
  Begin
    Emit1(OP_PUSH, OpReg(R_EAX));
    Emit1(OP_FILD, OpMem(R_ESP, 0, 4));
    Emit(OP_ADD, OpReg(R_ESP), OpImm(4));
  End;
End;

{ EAX = caractere : construit dans des cellules temporaires la chaine
  d un caractere ; EAX = adresse de son descripteur }
Procedure GenCharToString;
Var
  Ch, D : Integer;
Begin
  Ch := NewTemp(4);
  D := NewTemp(16);
  Emit(OP_MOV, TMem(Ch, 0, 4), OpReg(R_EAX));
  TAddr(R_EAX, Ch);
  Emit(OP_MOV, TMem(D, 0, 4), OpReg(R_EAX));
  Emit(OP_MOV, TMem(D, 4, 4), OpImm(1));
  Emit(OP_MOV, TMem(D, 8, 4), OpImm(1));
  Emit(OP_MOV, TMem(D, 12, 4), OpImm(1));
  TAddr(R_EAX, D);
End;

{ Operande destine a une routine de chaines : adresse du descripteur }
Procedure GenAsString(U : LongInt);
Begin
  GenValue(U);
  If ModeKind(UnitTab[U].Mode) = MK_CHAR Then GenCharToString;
End;

Function SetOpFor(Const Op : TName; Real : Boolean) : TOp;
Begin
  SetOpFor := OP_SETE;
  If Real Then
  Begin
    { comparaison L ? R avec R dans ST(0) et L dans ST(1) : FCOMP donne
      les indicateurs de R par rapport a L }
    If Op = '<' Then SetOpFor := OP_SETA
    Else If Op = '<=' Then SetOpFor := OP_SETAE
    Else If Op = '>' Then SetOpFor := OP_SETB
    Else If Op = '>=' Then SetOpFor := OP_SETBE
    Else If Op = '=' Then SetOpFor := OP_SETE
    Else SetOpFor := OP_SETNE;
  End
  Else
  Begin
    If Op = '<' Then SetOpFor := OP_SETL
    Else If Op = '<=' Then SetOpFor := OP_SETLE
    Else If Op = '>' Then SetOpFor := OP_SETG
    Else If Op = '>=' Then SetOpFor := OP_SETGE
    Else If Op = '=' Then SetOpFor := OP_SETE
    Else SetOpFor := OP_SETNE;
  End;
End;

Procedure GenDivZeroCheck;
Var
  Ok : Integer;
Begin
  Ok := NewLabel;
  Emit(OP_TEST, OpReg(R_ECX), OpReg(R_ECX));
  Emit1(OP_JNE, OpLabel(Ok));
  Emit1(OP_CALL, OpLabel(Intern(MangleRT('DIVZERO'))));
  EmitLabel(Ok);
End;

Procedure GenDyadic(U : LongInt);
Var
  Op      : TName;
  L, R    : LongInt;
  ML, MR  : Integer;
  KL, KR  : TModeKind;
  Res     : Integer;
  IsStr   : Boolean;
  Skip, AddL : Integer;
Begin
  Op := UnitTab[U].Name;
  If IsCompoundOp(Op) Then
  Begin
    GenCompound(U);
    Exit;
  End;
  L := UnitTab[U].A;
  R := UnitTab[U].B;
  If SymTab[UnitTab[U].Sym].Generic Then
  Begin
    { n LWB a, n UPB a : dimension n du tableau }
    GenValue(R);
    Emit1(OP_PUSH, OpReg(R_EAX));
    GenValue(L);
    Emit1(OP_POP, OpReg(R_EDX));
    Emit1(OP_DEC, OpReg(R_EAX));
    Emit(OP_MOV, OpReg(R_ECX), OpImm(12));
    Emit(OP_IMUL, OpReg(R_EAX), OpReg(R_ECX));
    If Op = 'LWB' Then
      Emit(OP_MOV, OpReg(R_EAX), OpMemIdx(-1, R_EDX, R_EAX, 1, 4, 4))
    Else
      Emit(OP_MOV, OpReg(R_EAX), OpMemIdx(-1, R_EDX, R_EAX, 1, 8, 4));
    Exit;
  End;
  ML := ModeResolve(OpOperand(UnitTab[U].Sym, 0));
  MR := ModeResolve(OpOperand(UnitTab[U].Sym, 1));
  KL := ModeTab[ML].Kind;
  KR := ModeTab[MR].Kind;
  Res := ModeResolve(OpResult(UnitTab[U].Sym));
  IsStr := ModeIsString(ML) Or ModeIsString(MR) Or ModeIsString(Res);
  { chaines : routines du runtime, operandes par adresse de descripteur }
  If IsStr Then
  Begin
    GenAsString(L);
    Emit1(OP_PUSH, OpReg(R_EAX));
    GenAsString(R);
    Emit(OP_MOV, OpReg(R_EDI), OpReg(R_EAX));
    Emit1(OP_POP, OpReg(R_ESI));
    If Op = '+' Then
      Emit1(OP_CALL, OpLabel(Intern(MangleRT('STRCAT'))))
    Else
    Begin
      Emit1(OP_CALL, OpLabel(Intern(MangleRT('STRCMP'))));
      Emit(OP_CMP, OpReg(R_EAX), OpImm(0));
      Emit1(SetOpFor(Op, False), OpReg(R_AL));
      Emit(OP_MOVZX, OpReg(R_EAX), OpReg(R_AL));
    End;
    Exit;
  End;
  { operations sur des reels }
  If (KL = MK_REAL) Or (KR = MK_REAL) Or (Res = MD_REAL) Then
  Begin
    If Op = '**' Then
    Begin
      { RPOW : ST(0) = base, ST(1) = exposant }
      GenAsReal(R);
      GenAsReal(L);
      Emit1(OP_CALL, OpLabel(Intern(MangleRT('RPOW'))));
      Exit;
    End;
    GenAsReal(L);
    GenAsReal(R);
    If Op = '+' Then
      Emit(OP_FADDP, OpST(1), OpST(0))
    Else If Op = '-' Then
      Emit(OP_FSUBP, OpST(1), OpST(0))
    Else If Op = '*' Then
      Emit(OP_FMULP, OpST(1), OpST(0))
    Else If Op = '/' Then
      Emit(OP_FDIVP, OpST(1), OpST(0))
    Else
    Begin
      Emit1(OP_FCOMP, OpST(1));
      Emit1(OP_FNSTSW, OpReg(R_AX));
      Emit1(OP_FSTP, OpST(0));
      Emit0(OP_SAHF);
      Emit1(SetOpFor(Op, True), OpReg(R_AL));
      Emit(OP_MOVZX, OpReg(R_EAX), OpReg(R_AL));
    End;
    Exit;
  End;
  { operations sur des entiers, caracteres, booleens, bits }
  GenValue(L);
  Emit1(OP_PUSH, OpReg(R_EAX));
  GenValue(R);
  Emit(OP_MOV, OpReg(R_ECX), OpReg(R_EAX));
  Emit1(OP_POP, OpReg(R_EAX));
  If Op = '+' Then
    Emit(OP_ADD, OpReg(R_EAX), OpReg(R_ECX))
  Else If Op = '-' Then
    Emit(OP_SUB, OpReg(R_EAX), OpReg(R_ECX))
  Else If Op = '*' Then
    Emit(OP_IMUL, OpReg(R_EAX), OpReg(R_ECX))
  Else If (Op = 'OVER') Or (Op = '%') Then
  Begin
    GenDivZeroCheck;
    Emit0(OP_CDQ);
    Emit1(OP_IDIV, OpReg(R_ECX));
  End
  Else If (Op = 'MOD') Or (Op = '%*') Then
  Begin
    { reste toujours positif ou nul : si le reste est negatif, on lui
      ajoute la valeur absolue du diviseur }
    GenDivZeroCheck;
    Emit0(OP_CDQ);
    Emit1(OP_IDIV, OpReg(R_ECX));
    Emit(OP_MOV, OpReg(R_EAX), OpReg(R_EDX));
    Skip := NewLabel;
    AddL := NewLabel;
    Emit(OP_TEST, OpReg(R_EAX), OpReg(R_EAX));
    Emit1(OP_JNS, OpLabel(Skip));
    Emit(OP_MOV, OpReg(R_EDX), OpReg(R_ECX));
    Emit(OP_TEST, OpReg(R_EDX), OpReg(R_EDX));
    Emit1(OP_JNS, OpLabel(AddL));
    Emit1(OP_NEG, OpReg(R_EDX));
    EmitLabel(AddL);
    Emit(OP_ADD, OpReg(R_EAX), OpReg(R_EDX));
    EmitLabel(Skip);
  End
  Else If Op = '**' Then
  Begin
    Emit(OP_MOV, OpReg(R_EDX), OpReg(R_ECX));
    Emit1(OP_CALL, OpLabel(Intern(MangleRT('POW'))));
  End
  Else If Op = 'AND' Then
    Emit(OP_AND, OpReg(R_EAX), OpReg(R_ECX))
  Else If Op = 'OR' Then
    Emit(OP_OR, OpReg(R_EAX), OpReg(R_ECX))
  Else If Op = 'SHL' Then
    Emit(OP_SHL, OpReg(R_EAX), OpReg(R_CL))
  Else If Op = 'SHR' Then
    Emit(OP_SHR, OpReg(R_EAX), OpReg(R_CL))
  Else
  Begin
    Emit(OP_CMP, OpReg(R_EAX), OpReg(R_ECX));
    Emit1(SetOpFor(Op, False), OpReg(R_AL));
    Emit(OP_MOVZX, OpReg(R_EAX), OpReg(R_AL));
  End;
End;

Procedure GenMonadic(U : LongInt);
Var
  Op  : TName;
  A   : LongInt;
  MA  : Integer;
  Res : Integer;
Begin
  Op := UnitTab[U].Name;
  A := UnitTab[U].A;
  MA := ModeResolve(OpOperand(UnitTab[U].Sym, 0));
  Res := ModeResolve(OpResult(UnitTab[U].Sym));
  If SymTab[UnitTab[U].Sym].Generic Then
  Begin
    { LWB et UPB d'un tableau : champs du descripteur }
    GenValue(A);
    If MayBeNil(A) Then GenNilCheck;
    If Op = 'LWB' Then
      Emit(OP_MOV, OpReg(R_EAX), OpMem(R_EAX, 4, 4))
    Else
      Emit(OP_MOV, OpReg(R_EAX), OpMem(R_EAX, 8, 4));
    Exit;
  End;
  GenValue(A);
  If ModeTab[MA].Kind = MK_REAL Then
  Begin
    If Op = '-' Then
      Emit0(OP_FCHS)
    Else If Op = 'ABS' Then
      Emit0(OP_FABS)
    Else If Op = 'ENTIER' Then
      Emit1(OP_CALL, OpLabel(Intern(MangleRT('FLOOR'))))
    Else If Op = 'ROUND' Then
      Emit1(OP_CALL, OpLabel(Intern(MangleRT('RTOI'))))
    Else If Op = 'SIGN' Then
      Emit1(OP_CALL, OpLabel(Intern(MangleRT('RSIGN'))));
    Exit;
  End;
  If Op = '-' Then
    Emit1(OP_NEG, OpReg(R_EAX))
  Else If Op = 'ABS' Then
  Begin
    If ModeTab[MA].Kind = MK_INT Then
    Begin
      Emit0(OP_CDQ);
      Emit(OP_XOR, OpReg(R_EAX), OpReg(R_EDX));
      Emit(OP_SUB, OpReg(R_EAX), OpReg(R_EDX));
    End;
  End
  Else If Op = 'SIGN' Then
  Begin
    Emit(OP_CMP, OpReg(R_EAX), OpImm(0));
    Emit1(OP_SETG, OpReg(R_CL));
    Emit1(OP_SETL, OpReg(R_AL));
    Emit(OP_MOVZX, OpReg(R_EAX), OpReg(R_AL));
    Emit(OP_MOVZX, OpReg(R_ECX), OpReg(R_CL));
    Emit(OP_SUB, OpReg(R_ECX), OpReg(R_EAX));
    Emit(OP_MOV, OpReg(R_EAX), OpReg(R_ECX));
  End
  Else If Op = 'ODD' Then
    Emit(OP_AND, OpReg(R_EAX), OpImm(1))
  Else If Op = 'NOT' Then
  Begin
    If ModeTab[MA].Kind = MK_BITS Then
      Emit1(OP_NOT, OpReg(R_EAX))
    Else
      Emit(OP_XOR, OpReg(R_EAX), OpImm(1));
  End;
  { +, BIN, REPR : aucun code }
  If Res = MD_VOID Then ;
End;

{ Une clause serie : les unites sont generees dans l ordre, la derniere
  laisse sa valeur (EAX, ST(0) ou adresse dans EAX) }
Procedure GenSerialValue(First : LongInt);
Var
  P, Last : LongInt;
Begin
  Last := LastValueUnit(First);
  P := First;
  While P >= 0 Do
  Begin
    If P = Last Then GenValue(P) Else GenOne(P);
    P := UnitTab[P].Next;
  End;
End;

Procedure GenIf(U : LongInt);
Var
  LElse, LEnd : Integer;
Begin
  LElse := NewLabel;
  LEnd := NewLabel;
  GenSerialValue(UnitTab[U].A);
  Emit(OP_TEST, OpReg(R_EAX), OpReg(R_EAX));
  If UnitTab[U].C < 0 Then
    Emit1(OP_JE, OpLabel(LEnd))
  Else
    Emit1(OP_JE, OpLabel(LElse));
  GenSerialValue(UnitTab[U].B);
  If UnitTab[U].C >= 0 Then
  Begin
    Emit1(OP_JMP, OpLabel(LEnd));
    EmitLabel(LElse);
    If UnitTab[UnitTab[U].C].Kind In [UK_IF, UK_CASE] Then
      GenValue(UnitTab[U].C)
    Else
      GenSerialValue(UnitTab[U].C);
  End;
  EmitLabel(LEnd);
End;

Procedure GenCase(U : LongInt);
Var
  Labels      : Array[1..128] Of Integer;
  K, N        : Integer;
  LOut, LEnd  : Integer;
  A           : LongInt;
Begin
  N := UnitTab[U].IntVal;
  If N > 128 Then
  Begin
    FatalError('CASE avec plus de 128 alternatives');
    Exit;
  End;
  For K := 1 To N Do
    Labels[K] := NewLabel;
  LOut := NewLabel;
  LEnd := NewLabel;
  GenSerialValue(UnitTab[U].A);
  For K := 1 To N Do
  Begin
    Emit(OP_CMP, OpReg(R_EAX), OpImm(K));
    Emit1(OP_JE, OpLabel(Labels[K]));
  End;
  Emit1(OP_JMP, OpLabel(LOut));
  A := UnitTab[U].B;
  K := 1;
  While A >= 0 Do
  Begin
    EmitLabel(Labels[K]);
    GenValue(A);
    Emit1(OP_JMP, OpLabel(LEnd));
    A := UnitTab[A].Next;
    Inc(K);
  End;
  EmitLabel(LOut);
  If UnitTab[U].C >= 0 Then
  Begin
    If UnitTab[UnitTab[U].C].Kind In [UK_IF, UK_CASE] Then
      GenValue(UnitTab[U].C)
    Else
      GenSerialValue(UnitTab[U].C);
  End;
  EmitLabel(LEnd);
End;

{ FOR i FROM a BY b TO c WHILE cond DO corps OD : les bornes et le pas
  sont evalues une fois, dans des cellules temporaires }
Procedure GenLoop(U : LongInt);
Var
  Ctr, Lim, Stp         : Integer;
  LTop, LBody, LExit, LNeg : Integer;
  S                     : Integer;
  HaveLim               : Boolean;
  CtrOp                 : TOperand;
  Down                  : Boolean;
  StepKnown, StepNeg    : Boolean;
  B                     : LongInt;
Begin
  S := UnitTab[U].Sym;
  Down := (UnitTab[U].IntVal And 1) <> 0;
  B := UnitTab[U].B;
  Lim := 0;
  HaveLim := False;
  Stp := NewTemp(4);
  If S >= 0 Then
    CtrOp := SymCell(S, 0, 4)
  Else
  Begin
    Ctr := NewTemp(4);
    CtrOp := TMem(Ctr, 0, 4);
  End;
  If UnitTab[U].A >= 0 Then
    GenValue(UnitTab[U].A)
  Else
    Emit(OP_MOV, OpReg(R_EAX), OpImm(1));
  Emit(OP_MOV, CtrOp, OpReg(R_EAX));
  If UnitTab[U].C >= 0 Then
  Begin
    Lim := NewTemp(4);
    HaveLim := True;
    GenValue(UnitTab[U].C);
    Emit(OP_MOV, TMem(Lim, 0, 4), OpReg(R_EAX));
  End;
  If B >= 0 Then
    GenValue(B)
  Else
    Emit(OP_MOV, OpReg(R_EAX), OpImm(1));
  If Down Then Emit1(OP_NEG, OpReg(R_EAX));
  Emit(OP_MOV, TMem(Stp, 0, 4), OpReg(R_EAX));
  { signe du pas connu a la compilation s il est constant }
  StepKnown := (B < 0) Or (UnitTab[B].Kind = UK_INTDEN);
  StepNeg := Down;
  If (B >= 0) And (UnitTab[B].Kind = UK_INTDEN) Then
    StepNeg := (UnitTab[B].IntVal < 0) <> Down;
  LTop := NewLabel;
  LBody := NewLabel;
  LExit := NewLabel;
  LNeg := NewLabel;
  EmitLabel(LTop);
  If HaveLim Then
  Begin
    Emit(OP_MOV, OpReg(R_EAX), CtrOp);
    If StepKnown Then
    Begin
      Emit(OP_CMP, OpReg(R_EAX), TMem(Lim, 0, 4));
      If StepNeg Then Emit1(OP_JL, OpLabel(LExit))
      Else Emit1(OP_JG, OpLabel(LExit));
    End
    Else
    Begin
      Emit(OP_CMP, TMem(Stp, 0, 4), OpImm(0));
      Emit1(OP_JL, OpLabel(LNeg));
      Emit(OP_CMP, OpReg(R_EAX), TMem(Lim, 0, 4));
      Emit1(OP_JG, OpLabel(LExit));
      Emit1(OP_JMP, OpLabel(LBody));
      EmitLabel(LNeg);
      Emit(OP_CMP, OpReg(R_EAX), TMem(Lim, 0, 4));
      Emit1(OP_JL, OpLabel(LExit));
      EmitLabel(LBody);
    End;
  End;
  If UnitTab[U].D >= 0 Then
  Begin
    GenSerialValue(UnitTab[U].D);
    Emit(OP_TEST, OpReg(R_EAX), OpReg(R_EAX));
    Emit1(OP_JE, OpLabel(LExit));
  End;
  GenUnit(UnitTab[U].E);
  Emit(OP_MOV, OpReg(R_EAX), TMem(Stp, 0, 4));
  Emit(OP_ADD, CtrOp, OpReg(R_EAX));
  Emit1(OP_JMP, OpLabel(LTop));
  EmitLabel(LExit);
End;

{ Clause de conformite : l'etiquette de l'union choisit l'alternative ;
  le nom de l'alternative est lie a la valeur (apres l'etiquette) }
Procedure GenConform(U : LongInt);
Var
  T            : Integer;
  LOut, LEnd   : Integer;
  Alt          : LongInt;
  Lbls         : Array[1..128] Of Integer;
  K, N         : Integer;
  S            : Integer;
Begin
  N := UnitTab[U].IntVal;
  If N > 128 Then
  Begin
    FatalError('clause de conformite avec plus de 128 alternatives');
    Exit;
  End;
  T := NewTemp(4);
  For K := 1 To N Do
    Lbls[K] := NewLabel;
  LOut := NewLabel;
  LEnd := NewLabel;
  GenSerialValue(UnitTab[U].A);
  Emit(OP_MOV, TMem(T, 0, 4), OpReg(R_EAX));
  Alt := UnitTab[U].B;
  K := 1;
  While Alt >= 0 Do
  Begin
    Emit(OP_MOV, OpReg(R_EAX), TMem(T, 0, 4));
    Emit(OP_CMP, OpMem(R_EAX, 0, 4), OpImm(UnitTab[Alt].IntVal));
    Emit1(OP_JE, OpLabel(Lbls[K]));
    Alt := UnitTab[Alt].Next;
    Inc(K);
  End;
  Emit1(OP_JMP, OpLabel(LOut));
  Alt := UnitTab[U].B;
  K := 1;
  While Alt >= 0 Do
  Begin
    EmitLabel(Lbls[K]);
    S := UnitTab[Alt].Sym;
    If S >= 0 Then
    Begin
      Emit(OP_MOV, OpReg(R_EAX), TMem(T, 0, 4));
      Emit(OP_ADD, OpReg(R_EAX), OpImm(4));
      LoadThrough(ModeResolve(UnitTab[Alt].Mode));
      StoreValue(S, -1, 0, ModeResolve(UnitTab[Alt].Mode));
    End;
    GenValue(UnitTab[Alt].A);
    Emit1(OP_JMP, OpLabel(LEnd));
    Alt := UnitTab[Alt].Next;
    Inc(K);
  End;
  EmitLabel(LOut);
  If UnitTab[U].C >= 0 Then
    GenSerialValue(UnitTab[U].C);
  EmitLabel(LEnd);
End;

{ ---- Tableaux, tranches et chaines (TODO 15) ----
  Descripteur d'un tableau a D dimensions : adresse des elements, puis
  pour chaque dimension borne inferieure, borne superieure et pas en
  octets (4 + 12 * D octets). Un STRING est un tableau flexible de
  CHAR d'une dimension (16 octets). Le nom d'un tableau (REF) et sa
  valeur ont la meme representation : l'adresse de son descripteur. }

{ Copie les elements du tableau decrit par ESI dans celui que decrit EDI
  (memes dimensions, memes bornes) ; detruit EAX, ECX, EDX, ESI, EDI }
Procedure GenRowCopy(RowMode : Integer);
Var
  K, D, Ok : Integer;
  ES       : LongInt;
Begin
  D := ModeTab[ModeResolve(RowMode)].Dims;
  ES := ModeElemSize(RowMode);
  { les deux tableaux doivent avoir les memes dimensions }
  For K := 0 To D - 1 Do
  Begin
    Ok := NewLabel;
    Emit(OP_MOV, OpReg(R_EAX), OpMem(R_ESI, 8 + 12 * K, 4));
    Emit(OP_SUB, OpReg(R_EAX), OpMem(R_ESI, 4 + 12 * K, 4));
    Emit(OP_MOV, OpReg(R_ECX), OpMem(R_EDI, 8 + 12 * K, 4));
    Emit(OP_SUB, OpReg(R_ECX), OpMem(R_EDI, 4 + 12 * K, 4));
    Emit(OP_CMP, OpReg(R_EAX), OpReg(R_ECX));
    Emit1(OP_JE, OpLabel(Ok));
    Emit1(OP_CALL, OpLabel(Intern(MangleRT('BOUNDS'))));
    EmitLabel(Ok);
  End;
  Emit(OP_MOV, OpReg(R_EAX), OpImm(1));
  For K := 0 To D - 1 Do
  Begin
    Emit(OP_MOV, OpReg(R_ECX), OpMem(R_ESI, 8 + 12 * K, 4));
    Emit(OP_SUB, OpReg(R_ECX), OpMem(R_ESI, 4 + 12 * K, 4));
    Emit1(OP_INC, OpReg(R_ECX));
    Emit(OP_IMUL, OpReg(R_EAX), OpReg(R_ECX));
  End;
  Emit(OP_MOV, OpReg(R_ECX), OpImm(ES));
  Emit(OP_IMUL, OpReg(R_EAX), OpReg(R_ECX));
  Emit(OP_MOV, OpReg(R_ECX), OpReg(R_EAX));
  Emit(OP_MOV, OpReg(R_EDX), OpMem(R_EDI, 0, 4));
  Emit(OP_MOV, OpReg(R_ESI), OpMem(R_ESI, 0, 4));
  Emit(OP_MOV, OpReg(R_EDI), OpReg(R_EDX));
  If ES Mod 4 = 0 Then
  Begin
    Emit(OP_SHR, OpReg(R_ECX), OpImm(2));
    Emit0(OP_REP_MOVSD);
  End
  Else
    Emit0(OP_REP_MOVSB);
End;

{ Le mode M est-il un tableau dont l'affectation copie les elements
  (tableau non flexible) ? }
Function IsFixedRow(M : Integer) : Boolean;
Begin
  M := ModeResolve(M);
  IsFixedRow := (ModeTab[M].Kind = MK_ROW) And Not ModeTab[M].Flex;
End;

{ Verifie l'indice EAX contre les bornes de la dimension K du
  descripteur dont l'adresse est dans EDX (registres conserves) }
Procedure GenIndexCheck(K : Integer);
Begin
  Emit(OP_MOV, OpReg(R_ECX), OpMem(R_EDX, 4 + 12 * K, 4));
  Emit1(OP_PUSH, OpReg(R_EDX));
  Emit(OP_MOV, OpReg(R_EDX), OpMem(R_EDX, 8 + 12 * K, 4));
  Emit1(OP_CALL, OpLabel(Intern(MangleRT('CHKIDX'))));
  Emit1(OP_POP, OpReg(R_EDX));
End;

{ a[i, j] : adresse de l'element, puis valeur si le tableau n'est pas
  un nom ; a[l:u] : descripteur d'une tranche (nouveau descripteur, sans
  copie des elements, de bornes 1 : u - l + 1) }
Procedure GenSlice(U : LongInt);
Var
  Op, It  : LongInt;
  Row     : Integer;
  K, D    : Integer;
  T       : Integer;
  Skip    : Integer;
  Tr      : LongInt;
Begin
  Op := UnitTab[U].A;
  Row := ModeDeref(NatMode(Op));
  D := ModeTab[Row].Dims;
  GenValue(Op);
  If MayBeNil(Op) Then GenNilCheck;
  If UnitTab[U].C = 0 Then
  Begin
    Emit1(OP_PUSH, OpReg(R_EAX));              { descripteur }
    Emit1(OP_PUSH, OpImm(0));                  { decalage cumule }
    It := UnitTab[U].B;
    K := 0;
    While It >= 0 Do
    Begin
      GenValue(It);
      Emit(OP_MOV, OpReg(R_EDX), OpMem(R_ESP, 4, 4));
      GenIndexCheck(K);
      Emit(OP_SUB, OpReg(R_EAX), OpMem(R_EDX, 4 + 12 * K, 4));
      Emit(OP_IMUL, OpReg(R_EAX), OpMem(R_EDX, 12 + 12 * K, 4));
      Emit(OP_ADD, OpMem(R_ESP, 0, 4), OpReg(R_EAX));
      It := UnitTab[It].Next;
      Inc(K);
    End;
    Emit1(OP_POP, OpReg(R_EAX));
    Emit1(OP_POP, OpReg(R_EDX));
    Emit(OP_ADD, OpReg(R_EAX), OpMem(R_EDX, 0, 4));
    If ModeKind(UnitTab[U].Mode) <> MK_REF Then
      LoadThrough(UnitTab[U].Mode);
    Exit;
  End;
  { tranche d'un tableau a une dimension }
  Tr := UnitTab[U].B;
  If (D <> 1) Or (UnitTab[U].IntVal <> 1) Then
  Begin
    EmitComment('tranche multidimensionnelle : pas encore generee');
    Exit;
  End;
  T := NewTemp(16);
  Skip := NewLabel;
  Emit1(OP_PUSH, OpReg(R_EAX));                { [ESP+8] descripteur }
  If UnitTab[Tr].A >= 0 Then
    GenValue(UnitTab[Tr].A)
  Else
  Begin
    Emit(OP_MOV, OpReg(R_EDX), OpMem(R_ESP, 0, 4));
    Emit(OP_MOV, OpReg(R_EAX), OpMem(R_EDX, 4, 4));
  End;
  Emit1(OP_PUSH, OpReg(R_EAX));                { [ESP+4] borne basse }
  If UnitTab[Tr].B >= 0 Then
    GenValue(UnitTab[Tr].B)
  Else
  Begin
    Emit(OP_MOV, OpReg(R_EDX), OpMem(R_ESP, 4, 4));
    Emit(OP_MOV, OpReg(R_EAX), OpMem(R_EDX, 8, 4));
  End;
  Emit1(OP_PUSH, OpReg(R_EAX));                { [ESP] borne haute }
  { bornes verifiees sauf pour une tranche vide }
  Emit(OP_MOV, OpReg(R_EAX), OpMem(R_ESP, 4, 4));
  Emit(OP_CMP, OpReg(R_EAX), OpMem(R_ESP, 0, 4));
  Emit1(OP_JG, OpLabel(Skip));
  Emit(OP_MOV, OpReg(R_EDX), OpMem(R_ESP, 8, 4));
  GenIndexCheck(0);
  Emit(OP_MOV, OpReg(R_EAX), OpMem(R_ESP, 0, 4));
  GenIndexCheck(0);
  EmitLabel(Skip);
  Emit(OP_MOV, OpReg(R_EDX), OpMem(R_ESP, 8, 4));
  Emit(OP_MOV, OpReg(R_EAX), OpMem(R_ESP, 4, 4));
  Emit(OP_SUB, OpReg(R_EAX), OpMem(R_EDX, 4, 4));
  Emit(OP_IMUL, OpReg(R_EAX), OpMem(R_EDX, 12, 4));
  Emit(OP_ADD, OpReg(R_EAX), OpMem(R_EDX, 0, 4));
  Emit(OP_MOV, TMem(T, 0, 4), OpReg(R_EAX));
  Emit(OP_MOV, TMem(T, 4, 4), OpImm(1));
  Emit(OP_MOV, OpReg(R_EAX), OpMem(R_ESP, 0, 4));
  Emit(OP_SUB, OpReg(R_EAX), OpMem(R_ESP, 4, 4));
  Emit1(OP_INC, OpReg(R_EAX));
  Emit(OP_MOV, TMem(T, 8, 4), OpReg(R_EAX));
  Emit(OP_MOV, OpReg(R_EAX), OpMem(R_EDX, 12, 4));
  Emit(OP_MOV, TMem(T, 12, 4), OpReg(R_EAX));
  Emit(OP_ADD, OpReg(R_ESP), OpImm(12));
  TAddr(R_EAX, T);
End;

{ ( u1, u2, ... ) : tableau d'une dimension ou structure selon le mode
  obtenu par coercition ; les valeurs sont rangees dans des cellules
  temporaires ; le resultat est l'adresse du descripteur ou de la
  structure }
Procedure GenDisplay(U : LongInt);
Var
  M, Elem   : Integer;
  E, D, I   : Integer;
  A         : LongInt;
  ES        : LongInt;
Begin
  M := ModeResolve(UnitTab[U].Mode);
  If M = MD_VOID Then
  Begin
    { clause collaterale en contexte vide }
    A := UnitTab[U].A;
    While A >= 0 Do
    Begin
      GenValue(A);
      A := UnitTab[A].Next;
    End;
    Exit;
  End;
  If ModeTab[M].Kind = MK_STRUCT Then
  Begin
    D := NewTemp(ModeSize(M));
    A := UnitTab[U].A;
    I := 0;
    While A >= 0 Do
    Begin
      GenValue(A);
      StoreValue(-1, D, ModeFieldOffset(M, I), ModeFieldMode(M, I));
      A := UnitTab[A].Next;
      Inc(I);
    End;
    TAddr(R_EAX, D);
    Exit;
  End;
  If ModeTab[M].Kind <> MK_ROW Then
  Begin
    EmitComment('affichage sans mode (ligne ' + ItoS(UnitTab[U].Line) +
                ')');
    Exit;
  End;
  Elem := ModeResolve(ModeTab[M].Sub);
  ES := ModeSize(Elem);
  E := NewTemp(UnitTab[U].IntVal * ES);
  D := NewTemp(16);
  A := UnitTab[U].A;
  I := 0;
  While A >= 0 Do
  Begin
    GenValue(A);
    StoreValue(-1, E, I * ES, Elem);
    A := UnitTab[A].Next;
    Inc(I);
  End;
  TAddr(R_EAX, E);
  Emit(OP_MOV, TMem(D, 0, 4), OpReg(R_EAX));
  Emit(OP_MOV, TMem(D, 4, 4), OpImm(1));
  Emit(OP_MOV, TMem(D, 8, 4), OpImm(UnitTab[U].IntVal));
  Emit(OP_MOV, TMem(D, 12, 4), OpImm(ES));
  TAddr(R_EAX, D);
End;

{ Declaration d'un tableau : descripteur de l'objet du symbole S, avec
  reservation des elements (cellule statique si toutes les bornes sont
  constantes, sinon memoire du tas) ; initialisation par un affichage
  ou un autre tableau }
Procedure GenRowDecl(U : LongInt);
Var
  S, Init, It    : LongInt;
  M, E, K, D     : Integer;
  ES, Tot, Count : LongInt;
  ConstB         : Boolean;
  Lbl, LblOk     : Integer;
  LoA, HiA, Cnt, StrideA : Array[0..MAX_ARRAY_DIM - 1] Of LongInt;
Begin
  S := UnitTab[U].Sym;
  M := ModeResolve(UnitTab[U].Mode);
  Init := UnitTab[U].A;
  E := ModeResolve(ModeTab[M].Sub);
  ES := ModeSize(E);
  D := ModeTab[M].Dims;
  If UnitTab[U].C = 0 Then
  Begin
    { sans bornes : identite ou variable prenant le descripteur de la
      valeur (affichage, tranche, autre tableau) }
    If Init >= 0 Then
    Begin
      GenValue(Init);
      StoreValue(S, -1, 0, M);
    End
    Else If ModeTab[M].Flex Then
      Emit(OP_MOV, SymCell(S, 4, 4), OpImm(1));
    Exit;
  End;
  { bornes constantes ? }
  ConstB := SymTab[S].Storage = SC_STATIC;
  It := UnitTab[U].B;
  While It >= 0 Do
  Begin
    If (UnitTab[It].Kind <> UK_INTDEN) Or
       (UnitTab[UnitTab[It].Next].Kind <> UK_INTDEN) Then
      ConstB := False;
    It := UnitTab[UnitTab[It].Next].Next;
  End;
  If ConstB Then
  Begin
    It := UnitTab[U].B;
    K := 0;
    While (It >= 0) And (K < MAX_ARRAY_DIM) Do
    Begin
      LoA[K] := UnitTab[It].IntVal;
      HiA[K] := UnitTab[UnitTab[It].Next].IntVal;
      Cnt[K] := HiA[K] - LoA[K] + 1;
      If Cnt[K] < 0 Then Cnt[K] := 0;
      It := UnitTab[UnitTab[It].Next].Next;
      Inc(K);
    End;
    StrideA[D - 1] := ES;
    For K := D - 2 Downto 0 Do
      StrideA[K] := StrideA[K + 1] * Cnt[K + 1];
    Tot := StrideA[0] * Cnt[0];
    Lbl := Intern(SymTab[S].AsmName + '_E');
    DataAddZero(Lbl, Tot);
    Emit(OP_MOV, SymCell(S, 0, 4), OpOffset(Lbl));
    For K := 0 To D - 1 Do
    Begin
      Emit(OP_MOV, SymCell(S, 4 + 12 * K, 4), OpImm(LoA[K]));
      Emit(OP_MOV, SymCell(S, 8 + 12 * K, 4), OpImm(HiA[K]));
      Emit(OP_MOV, SymCell(S, 12 + 12 * K, 4), OpImm(StrideA[K]));
    End;
  End
  Else
  Begin
    { bornes calculees a l'execution }
    It := UnitTab[U].B;
    K := 0;
    While It >= 0 Do
    Begin
      GenValue(It);
      Emit(OP_MOV, SymCell(S, 4 + 12 * K, 4), OpReg(R_EAX));
      GenValue(UnitTab[It].Next);
      Emit(OP_MOV, SymCell(S, 8 + 12 * K, 4), OpReg(R_EAX));
      It := UnitTab[UnitTab[It].Next].Next;
      Inc(K);
    End;
    Emit(OP_MOV, SymCell(S, 12 + 12 * (D - 1), 4), OpImm(ES));
    For K := D - 2 Downto 0 Do
    Begin
      Emit(OP_MOV, OpReg(R_EAX), SymCell(S, 8 + 12 * (K + 1), 4));
      Emit(OP_SUB, OpReg(R_EAX), SymCell(S, 4 + 12 * (K + 1), 4));
      Emit1(OP_INC, OpReg(R_EAX));
      Emit(OP_IMUL, OpReg(R_EAX), SymCell(S, 12 + 12 * (K + 1), 4));
      Emit(OP_MOV, SymCell(S, 12 + 12 * K, 4), OpReg(R_EAX));
    End;
    Emit(OP_MOV, OpReg(R_EAX), SymCell(S, 8, 4));
    Emit(OP_SUB, OpReg(R_EAX), SymCell(S, 4, 4));
    Emit1(OP_INC, OpReg(R_EAX));
    Emit(OP_IMUL, OpReg(R_EAX), SymCell(S, 12, 4));
    LblOk := NewLabel;
    Emit(OP_TEST, OpReg(R_EAX), OpReg(R_EAX));
    Emit1(OP_JNS, OpLabel(LblOk));
    Emit(OP_XOR, OpReg(R_EAX), OpReg(R_EAX));
    EmitLabel(LblOk);
    Emit1(OP_CALL, OpLabel(Intern(MangleRT('ALLOC'))));
    Emit(OP_MOV, SymCell(S, 0, 4), OpReg(R_EAX));
  End;
  { initialisation : copie des elements }
  If Init >= 0 Then
  Begin
    GenValue(Init);
    Emit(OP_MOV, OpReg(R_ESI), OpReg(R_EAX));
    If SymTab[S].Storage = SC_STATIC Then
      Emit(OP_MOV, OpReg(R_EDI), OpOffset(Intern(SymTab[S].AsmName)))
    Else
      Emit(OP_LEA, OpReg(R_EDI), SymCell(S, 0, 4));
    GenRowCopy(M);
  End;
End;

{ ---- References et affectations (TODO 14) ---- }

{ Verifie que EAX n'est pas la reference nulle (appelle NILREF) }
Procedure GenNilCheck;
Var
  Ok : Integer;
Begin
  Ok := NewLabel;
  Emit(OP_TEST, OpReg(R_EAX), OpReg(R_EAX));
  Emit1(OP_JNE, OpLabel(Ok));
  Emit1(OP_CALL, OpLabel(Intern(MangleRT('NILREF'))));
  EmitLabel(Ok);
End;

{ L'unite rend-elle une reference lue en memoire (qui peut etre NIL) ? }
Function MayBeNil(U : LongInt) : Boolean;
Begin
  MayBeNil := UnitTab[U].Kind In [UK_COERCE, UK_NIL, UK_CALL, UK_CAST,
                                  UK_FORMULA];
End;

{ Affectation : adresse du nom, valeur, rangement ; le resultat est le
  nom (adresse dans EAX) }
Procedure GenAssign(U : LongInt);
Var
  Ref, Src : LongInt;
  M        : Integer;
Begin
  Ref := UnitTab[U].A;
  Src := UnitTab[U].B;
  M := ModeResolve(ModeTab[ModeResolve(UnitTab[U].Mode)].Sub);
  GenValue(Ref);
  If MayBeNil(Ref) Then GenNilCheck;
  Emit1(OP_PUSH, OpReg(R_EAX));
  GenValue(Src);
  Case ValClass(M) Of
    1 :
      Begin
        Emit1(OP_POP, OpReg(R_EDX));
        If ModeKind(M) = MK_CHAR Then
          Emit(OP_MOV, OpMem(R_EDX, 0, 1), OpReg(R_AL))
        Else
          Emit(OP_MOV, OpMem(R_EDX, 0, 4), OpReg(R_EAX));
        Emit(OP_MOV, OpReg(R_EAX), OpReg(R_EDX));
      End;
    2 :
      Begin
        Emit1(OP_POP, OpReg(R_EDX));
        Emit1(OP_FSTP, OpMem(R_EDX, 0, 8));
        Emit(OP_MOV, OpReg(R_EAX), OpReg(R_EDX));
      End;
    3, 4 :
      Begin
        Emit1(OP_POP, OpReg(R_EDI));
        Emit1(OP_PUSH, OpReg(R_EDI));
        Emit(OP_MOV, OpReg(R_ESI), OpReg(R_EAX));
        If IsFixedRow(M) Then
          GenRowCopy(M)                { copie des elements }
        Else
        Begin
          Emit(OP_MOV, OpReg(R_ECX), OpImm(ModeSize(M) Div 4));
          Emit0(OP_REP_MOVSD);
        End;
        Emit1(OP_POP, OpReg(R_EAX));
      End;
  Else
    Begin
      Emit1(OP_POP, OpReg(R_EDX));
      EmitComment('affectation de mode ' + ModeName(M) +
                  ' pas encore generee');
    End;
  End;
End;

{ IS et ISNT : comparaison des adresses }
Procedure GenIdRel(U : LongInt);
Begin
  GenValue(UnitTab[U].A);
  Emit1(OP_PUSH, OpReg(R_EAX));
  GenValue(UnitTab[U].B);
  Emit(OP_MOV, OpReg(R_ECX), OpReg(R_EAX));
  Emit1(OP_POP, OpReg(R_EAX));
  Emit(OP_CMP, OpReg(R_EAX), OpReg(R_ECX));
  If UnitTab[U].Name = 'IS' Then
    Emit1(OP_SETE, OpReg(R_AL))
  Else
    Emit1(OP_SETNE, OpReg(R_AL));
  Emit(OP_MOVZX, OpReg(R_EAX), OpReg(R_AL));
End;

Function IsCompoundOp(Const Op : TName) : Boolean;
Begin
  IsCompoundOp := (Op = '+:=') Or (Op = '-:=') Or (Op = '*:=') Or
                  (Op = '/:=') Or (Op = '%:=') Or (Op = '%*:=') Or
                  (Op = 'PLUSAB') Or (Op = 'MINUSAB') Or
                  (Op = 'TIMESAB') Or (Op = 'DIVAB') Or
                  (Op = 'OVERAB') Or (Op = 'MODAB');
End;

{ Affectation composee : cible op= valeur ; le resultat est le nom de la
  cible (adresse dans EAX) }
Procedure GenCompound(U : LongInt);
Var
  Op     : TName;
  Target : Integer;
  Skip, AddL : Integer;
Begin
  Op := UnitTab[U].Name;
  Target := ModeResolve(ModeTab[ModeResolve(
            OpOperand(UnitTab[U].Sym, 0))].Sub);
  GenValue(UnitTab[U].A);
  If MayBeNil(UnitTab[U].A) Then GenNilCheck;
  Emit1(OP_PUSH, OpReg(R_EAX));
  If ModeIsString(Target) Then
  Begin
    { cible + chaine : nouvelle chaine, descripteur recopie dans la cible }
    GenAsString(UnitTab[U].B);
    Emit(OP_MOV, OpReg(R_EDI), OpReg(R_EAX));
    Emit(OP_MOV, OpReg(R_ESI), OpMem(R_ESP, 0, 4));
    Emit1(OP_CALL, OpLabel(Intern(MangleRT('STRCAT'))));
    Emit(OP_MOV, OpReg(R_ESI), OpReg(R_EAX));
    Emit1(OP_POP, OpReg(R_EDI));
    Emit1(OP_PUSH, OpReg(R_EDI));
    Emit(OP_MOV, OpReg(R_ECX), OpImm(4));
    Emit0(OP_REP_MOVSD);
    Emit1(OP_POP, OpReg(R_EAX));
    Exit;
  End;
  If Target = MD_REAL Then
  Begin
    GenAsReal(UnitTab[U].B);
    Emit1(OP_POP, OpReg(R_ESI));
    Emit1(OP_FLD, OpMem(R_ESI, 0, 8));
    Emit1(OP_FXCH, OpST(1));
    If (Op = '+:=') Or (Op = 'PLUSAB') Then
      Emit(OP_FADDP, OpST(1), OpST(0))
    Else If (Op = '-:=') Or (Op = 'MINUSAB') Then
      Emit(OP_FSUBP, OpST(1), OpST(0))
    Else If (Op = '*:=') Or (Op = 'TIMESAB') Then
      Emit(OP_FMULP, OpST(1), OpST(0))
    Else
      Emit(OP_FDIVP, OpST(1), OpST(0));
    Emit1(OP_FSTP, OpMem(R_ESI, 0, 8));
    Emit(OP_MOV, OpReg(R_EAX), OpReg(R_ESI));
    Exit;
  End;
  { cible entiere }
  GenValue(UnitTab[U].B);
  Emit1(OP_POP, OpReg(R_ESI));
  If (Op = '+:=') Or (Op = 'PLUSAB') Then
    Emit(OP_ADD, OpMem(R_ESI, 0, 4), OpReg(R_EAX))
  Else If (Op = '-:=') Or (Op = 'MINUSAB') Then
    Emit(OP_SUB, OpMem(R_ESI, 0, 4), OpReg(R_EAX))
  Else If (Op = '*:=') Or (Op = 'TIMESAB') Then
  Begin
    Emit(OP_MOV, OpReg(R_ECX), OpMem(R_ESI, 0, 4));
    Emit(OP_IMUL, OpReg(R_ECX), OpReg(R_EAX));
    Emit(OP_MOV, OpMem(R_ESI, 0, 4), OpReg(R_ECX));
  End
  Else
  Begin
    { division entiere (le reste pour %*:= et MODAB, toujours >= 0) }
    Emit(OP_MOV, OpReg(R_ECX), OpReg(R_EAX));
    GenDivZeroCheck;
    Emit(OP_MOV, OpReg(R_EAX), OpMem(R_ESI, 0, 4));
    Emit0(OP_CDQ);
    Emit1(OP_IDIV, OpReg(R_ECX));
    If (Op = '%*:=') Or (Op = 'MODAB') Then
    Begin
      Emit(OP_MOV, OpReg(R_EAX), OpReg(R_EDX));
      Skip := NewLabel;
      AddL := NewLabel;
      Emit(OP_TEST, OpReg(R_EAX), OpReg(R_EAX));
      Emit1(OP_JNS, OpLabel(Skip));
      Emit(OP_MOV, OpReg(R_EDX), OpReg(R_ECX));
      Emit(OP_TEST, OpReg(R_EDX), OpReg(R_EDX));
      Emit1(OP_JNS, OpLabel(AddL));
      Emit1(OP_NEG, OpReg(R_EDX));
      EmitLabel(AddL);
      Emit(OP_ADD, OpReg(R_EAX), OpReg(R_EDX));
      EmitLabel(Skip);
    End;
    Emit(OP_MOV, OpMem(R_ESI, 0, 4), OpReg(R_EAX));
  End;
  Emit(OP_MOV, OpReg(R_EAX), OpReg(R_ESI));
End;

{ Valeur d une unite : mot dans EAX, reel dans ST(0), ou adresse dans
  EAX pour les objets en memoire ; une variable (mode REF m) a pour
  valeur son adresse }
Procedure GenValue(U : LongInt);
Var
  S, T : Integer;
Begin
  Case UnitTab[U].Kind Of
    UK_INTDEN, UK_BOOLDEN, UK_CHARDEN:
      Emit(OP_MOV, OpReg(R_EAX), OpImm(UnitTab[U].IntVal));
    UK_REALDEN:
      Emit1(OP_FLD, OpMemSym(DataReal(UnitTab[U].RealVal), 0, 8));
    UK_STRDEN:
      Begin
        T := NewTemp(ModeSize(MD_STRING));
        GenStoreDenotation(-1, T, 0, MD_STRING, U);
        TAddr(R_EAX, T);
      End;
    UK_NIL, UK_EMPTY:
      Emit(OP_MOV, OpReg(R_EAX), OpImm(0));
    UK_SKIP: ;
    UK_GOTO, UK_LABELDEF:
      GenOne(U);
    UK_IDENT:
      Begin
        S := UnitTab[U].Sym;
        If S < 0 Then Exit;
        If SymTab[S].Kind = SK_VAR Then
          LoadSymAddress(S)
        Else If (SymTab[S].Kind = SK_STD) And (SymTab[S].Name = 'pi') Then
          Emit1(OP_FLD, OpMemSym(DataReal(3.14159265358979323846), 0, 8))
        Else If SymTab[S].Kind = SK_IDENT Then
        Begin
          Case ValClass(SymTab[S].Mode) Of
            1 : If ModeKind(SymTab[S].Mode) = MK_CHAR Then
                  Emit(OP_MOVZX, OpReg(R_EAX), SymCell(S, 0, 1))
                Else
                  Emit(OP_MOV, OpReg(R_EAX), SymCell(S, 0, 4));
            2 : Emit1(OP_FLD, SymCell(S, 0, 8));
            3, 4 : LoadSymAddress(S);
          End;
        End
        Else If SymTab[S].Kind = SK_PARAM Then
        Begin
          Case ValClass(SymTab[S].Mode) Of
            1 : If ModeKind(SymTab[S].Mode) = MK_CHAR Then
                  Emit(OP_MOVZX, OpReg(R_EAX), SymCell(S, 0, 1))
                Else
                  Emit(OP_MOV, OpReg(R_EAX), SymCell(S, 0, 4));
            2 : Emit1(OP_FLD, SymCell(S, 0, 8));
            3, 4 : LoadSymAddress(S);
          End;
        End
        Else If SymTab[S].Kind = SK_PROC Then
          GenProcValue(S)
        Else If (SymTab[S].Kind = SK_STD) And
                (SymTab[S].Name = 'newline') Then
          CallRT('NEWLINE')
        Else If (SymTab[S].Kind = SK_STD) And
                (SymTab[S].Name = 'space') Then
          CallRT('SPACE')
        Else
          EmitComment(SymTab[S].Name + ' : pas encore genere');
      End;
    UK_COERCE    : GenCoerce(U);
    UK_FORMULA:
      If UnitTab[U].Sym < 0 Then
        EmitComment('(formule ligne ' + ItoS(UnitTab[U].Line) +
                    ' : operateur inconnu)')
      Else If Not SymTab[UnitTab[U].Sym].Intrinsic Then
        GenOpCall(U)
      Else If UnitTab[U].IntVal = 2 Then
        GenDyadic(U)
      Else
        GenMonadic(U);
    UK_SELECT    : GenSelect(U);
    UK_SLICE     : GenSlice(U);
    UK_DISPLAY   : GenDisplay(U);
    UK_ASSIGN    : GenAssign(U);
    UK_CALL      : GenCall(U);
    UK_PRINT     : GenPrint(U);
    UK_ROUTINE   : GenRoutineValue(U);
    UK_IDREL     : GenIdRel(U);
    UK_IF        : GenIf(U);
    UK_CASE      : GenCase(U);
    UK_CONFORM   : GenConform(U);
    UK_LOOP      : GenLoop(U);
    UK_CONSTRUCT : GenConstruct(U);
    UK_CLOSED:
      GenSerialValue(UnitTab[U].A);
  Else
    EmitComment('(ligne ' + ItoS(UnitTab[U].Line) +
                ' : pas encore generee)');
  End;
End;

{ Initialise l objet du symbole S (a Disp octets de son debut, de mode
  ObjMode) avec l unite Init, deja coercee vers ce mode : denotations,
  NIL, EMPTY et union d'une denotation directement, le reste par la
  valeur calculee }
Procedure GenInit(S : Integer; Disp : LongInt; Init : LongInt;
                  Const Name : TName; ObjMode : Integer);
Begin
  If SymTab[S].Heap Then
  Begin
    If UnitTab[Init].Kind <> UK_OPAQUE Then
    Begin
      GenValue(Init);
      StoreValue(S, -1, Disp, ObjMode);
    End
    Else
      EmitComment(Name + ' : initialiseur ligne ' +
                  ItoS(UnitTab[Init].Line) + ' pas encore genere');
    Exit;
  End;
  Case UnitTab[Init].Kind Of
    UK_INTDEN, UK_REALDEN, UK_BOOLDEN, UK_CHARDEN, UK_STRDEN:
      GenStoreDenotation(S, -1, Disp, ModeResolve(UnitTab[Init].Mode),
                         Init);
    UK_NIL, UK_EMPTY:
      Emit(OP_MOV, SymCell(S, Disp, 4), OpImm(0));
    UK_SKIP: ;
    UK_OPAQUE:
      EmitComment(Name + ' : initialiseur ligne ' +
                  ItoS(UnitTab[Init].Line) + ' pas encore genere');
    UK_COERCE:
      If (UnitTab[Init].IntVal = CO_UNITE) And
         (ModeKind(UnitTab[UnitTab[Init].A].Mode) <> MK_UNION) And
         (UnitTab[UnitTab[Init].A].Kind In [UK_INTDEN, UK_REALDEN,
          UK_BOOLDEN, UK_CHARDEN, UK_STRDEN]) Then
      Begin
        Emit(OP_MOV, SymCell(S, Disp, 4), OpImm(UnitTab[Init].B));
        GenInit(S, Disp + 4, UnitTab[Init].A, Name, ObjMode);
      End
      Else
      Begin
        GenValue(Init);
        StoreValue(S, -1, Disp, ObjMode);
      End;
  Else
    Begin
      GenValue(Init);
      StoreValue(S, -1, Disp, ObjMode);
    End;
  End;
End;

{ Declaration d identite ou de variable }
Procedure GenDecl(U : LongInt);
Begin
  If SymTab[UnitTab[U].Sym].Heap Then
  Begin
    { generateur HEAP : memoire du tas, adresse rangee dans la cellule }
    Emit(OP_MOV, OpReg(R_EAX), OpImm(ModeSize(UnitTab[U].Mode)));
    Emit1(OP_CALL, OpLabel(Intern(MangleRT('ALLOC'))));
    Emit(OP_MOV, SymCell(UnitTab[U].Sym, 0, 4), OpReg(R_EAX));
  End;
  If ModeKind(UnitTab[U].Mode) = MK_ROW Then
  Begin
    GenRowDecl(U);
    Exit;
  End;
  If UnitTab[U].A >= 0 Then
    GenInit(UnitTab[U].Sym, 0, UnitTab[U].A, UnitTab[U].Name,
            UnitTab[U].Mode);
End;

{ ---- Generation du code a partir de l arbre ---- }

Procedure GenOne(U : LongInt);
Begin
  Case UnitTab[U].Kind Of
    UK_SERIAL  : GenUnit(UnitTab[U].A);
    UK_CLOSED  : GenUnit(UnitTab[U].A);
    UK_COERCE, UK_IDENT, UK_SELECT, UK_SLICE, UK_CALL, UK_CONSTRUCT,
    UK_CAST, UK_FORMULA, UK_IF, UK_CASE, UK_CONFORM, UK_LOOP, UK_ASSIGN,
    UK_IDREL, UK_DISPLAY, UK_ROUTINE, UK_PRINT : GenValue(U);
    UK_PROCDECL : GenRoutineBody(UnitTab[U].A);
    UK_LABELDEF:
      If UnitTab[U].Sym >= 0 Then
        EmitLabel(Intern(SymTab[UnitTab[U].Sym].AsmName));
    UK_GOTO    :
      If UnitTab[U].Sym >= 0 Then
        Emit1(OP_JMP, OpLabel(Intern(SymTab[UnitTab[U].Sym].AsmName)));
    UK_SKIP, UK_NIL, UK_EMPTY, UK_MODEDECL, UK_PRIODECL, UK_TRIM : ;
    UK_VARDECL, UK_IDDECL : GenDecl(U);
    UK_INTDEN, UK_REALDEN, UK_BOOLDEN, UK_CHARDEN, UK_STRDEN : ;
    UK_DECL, UK_OPAQUE:
      EmitComment('(ligne ' + ItoS(UnitTab[U].Line) +
                  ' : pas encore generee)');
  End;
End;

Procedure GenUnit(U : LongInt);
Begin
  While U >= 0 Do
  Begin
    GenOne(U);
    U := UnitTab[U].Next;
  End;
End;

Procedure RtLink; Forward;

Procedure PhaseCodegen;
Begin
  GenFrame := -1;
  GenLevel := 0;
  GenMainBegin;
  GenUnit(UnitRoot);
  GenMainEnd;
  RtLink;
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
  If (I.B.Kind = OK_REG) And (I.B.Reg = R_CL) Then
  Begin
    PutB($D3);
    EncRM(Digit, I.A);
    Exit;
  End;
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
          If (I.B.Kind = OK_ST) And (I.A.Imm = 0) Then
          Begin
            { forme ST(0), ST(i) : D8 + base }
            PutB($D8);
            Case I.Op Of
              OP_FADD  : PutB($C0 + I.B.Imm);
              OP_FMUL  : PutB($C8 + I.B.Imm);
              OP_FSUB  : PutB($E0 + I.B.Imm);
              OP_FSUBR : PutB($E8 + I.B.Imm);
              OP_FDIV  : PutB($F0 + I.B.Imm);
              OP_FDIVR : PutB($F8 + I.B.Imm);
            End;
            Exit;
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
    OP_REP_MOVSD: Begin PutB($F3); PutB($A5); End;
    OP_REP_MOVSB: Begin PutB($F3); PutB($A4); End;
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
  { carte des donnees : decalage dans .data, taille, nom }
  WriteLn(F);
  WriteLn(F, '; .data (', BinDataLen, ' octets)');
  For I := 0 To DataCount - 1 Do
    WriteLn(F, '; ', Hex8(BinLbl[DataTab[I].Name].Off), '  ',
            NameTab[DataTab[I].Name]);
  Close(F);
End;

Procedure PhaseEncode;
Var
  K : Integer;
Begin
  EncodeProgram;
  If Opts.Verbose Then
    WriteLn('  .text : ', BinCodeLen, ' octets, .data : ', BinDataLen,
            ' octets, ', BinFixCount, ' relocation(s), ', BinImportCount,
            ' import(s)');
  If Opts.Verbose And (BinImportCount > 0) Then
  Begin
    Write('  imports (kernel32.dll) :');
    For K := 0 To BinImportCount - 1 Do
      Write(' ', NameTab[BinImport[K]]);
    WriteLn;
  End;
  If Opts.DebugMode Then
    WriteBinListing(ReplaceExt(Opts.OutFile, '.lst'));
End;


{ ============================================================
  SECTION 13 - ECRIVAINS PE (.EXE) ET COFF (.OBJ) (TODO 21)
  ============================================================ }
Type
  {$IFDEF FPC}
  TWide = Int64;
  {$ELSE}
  TWide = Comp;
  {$ENDIF}

{ ---- Ecrivain PE : executable Windows 32 bits console (TODO 21) ----
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
    If Copy(Nm, 1, 4) = '_A68' Then
      FatalError('symbole non defini: ' + Nm +
                 ' (routine du runtime absente)');
    ImpName[I] := Nm;
  End;
  MainSym := Intern(A68_MAIN_NAME);
  If BinLbl[MainSym].Sect <> 1 Then
    FatalError('point d''entree ' + A68_MAIN_NAME + ' introuvable');
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
  Symboles : 0/1 = .text + aux, 2/3 = .data + aux, 4 = _A68P_Main
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
  MainSym := Intern(A68_MAIN_NAME);
  If BinLbl[MainSym].Sect <> 1 Then
    FatalError('point d''entree ' + A68_MAIN_NAME + ' introuvable');
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
  FileSize   := StrOff + 4 + Length(A68_MAIN_NAME) + 1;
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
  CoffSym(SymOff + 72, A68_MAIN_NAME, StrOff, StrLen, BinLbl[MainSym].Off,
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
  SECTION 14 - RUNTIME ALGOL 68 POUR WIN32 (TODO 22)
  ============================================================ }
{ Le runtime est ecrit en assembleur 80386 (syntaxe du listing) et
  integre au compilateur sous forme de texte (RtText). Seules les
  routines atteignables depuis le programme compile (appels _A68RT_*,
  fermeture transitive) sont assemblees par un mini-assembleur qui les
  convertit en instructions internes, ajoutees apres le code du
  programme : elles figurent donc dans le listing .ASM, qui devient
  autonome, puis sont encodees comme le reste (.EXE et .OBJ
  independants de toute bibliotheque, hormis kernel32.dll).

  Format de RtText : '@NOM' ouvre une routine, ';texte' est un
  commentaire, 'NOM:' une etiquette, sinon une instruction. Les
  cellules de donnees _A68D_* sont creees a la demande (RtData).

  Contrat (registres detruits : EAX, ECX, EDX, ESI, EDI ; EBX et EBP
  conserves) :
    WRITEINT, WRITEBOOL, WRITECHAR EAX ; WRITEREAL ST(0) (depile) ;
    WRITESTR EAX = descripteur ; NEWLINE ; SPACE ; WHOLE EAX = n,
    ECX = largeur -> EAX = descripteur ; READINT, READCHAR -> EAX ;
    READREAL -> ST(0) ; READSTR -> EAX = descripteur ; STRCAT ESI,
    EDI = descripteurs -> EAX = descripteur ; STRCMP ESI, EDI -> EAX
    (< 0, 0, > 0) ; POW EAX ** EDX ; RPOW ST(0) ** ST(1) -> ST(0) ;
    FLOOR et RTOI ST(0) -> EAX ; RSIGN ST(0) -> EAX ; CHKIDX EAX =
    indice, ECX = borne basse, EDX = borne haute (registres conserves) ;
    BOUNDS ; NILREF ; DIVZERO ; ALLOC EAX = octets -> EAX = bloc mis a
    zero (HeapAlloc). Les routines d'erreur ecrivent un message sur
    l'erreur standard et terminent par le code de sortie 1.
  Formats : entier en decimal sans remplissage ; reel en notation fixe,
  6 decimales au plus, zeros finaux supprimes mais une decimale au
  moins, valeur absolue inferieure a 9.2E12 ; BOOL TRUE ou FALSE ; fin
  de ligne CR LF ; read ignore les blancs avant un nombre, lit un
  caractere pour CHAR et la ligne (256 caracteres au plus) pour
  STRING. }
Type
  TRtLine = String[70];

Const
  RT_LINES = 631;
  RT_MAX_ROUT = 40;
  RtText : Array[0..RT_LINES - 1] Of TRtLine = (
  '@_A68RT_PUT',
  '; ESI = octets, ECX = longueur : ecrit sur la sortie standard',
  '_A68RT_PUT:',
  'TEST ECX, ECX',
  'JLE _A68R_pt1',
  'PUSH ESI',
  'PUSH ECX',
  'PUSH -11',
  'CALL GetStdHandle',
  'POP ECX',
  'POP ESI',
  'PUSH 0',
  'PUSH OFFSET _A68D_WR',
  'PUSH ECX',
  'PUSH ESI',
  'PUSH EAX',
  'CALL WriteFile',
  '_A68R_pt1:',
  'RET',
  '@_A68RT_FAIL',
  '; EAX = message termine par zero : erreur standard, code de sortie 1',
  '_A68RT_FAIL:',
  'PUSH EAX',
  'XOR ECX, ECX',
  '_A68R_fl1:',
  'MOVZX EDX, BYTE PTR [EAX+ECX]',
  'TEST EDX, EDX',
  'JE _A68R_fl2',
  'INC ECX',
  'JMP _A68R_fl1',
  '_A68R_fl2:',
  'PUSH ECX',
  'PUSH -12',
  'CALL GetStdHandle',
  'POP ECX',
  'POP EDX',
  'PUSH 0',
  'PUSH OFFSET _A68D_WR',
  'PUSH ECX',
  'PUSH EDX',
  'PUSH EAX',
  'CALL WriteFile',
  'PUSH 1',
  'CALL ExitProcess',
  '@_A68RT_DIVZERO',
  '_A68RT_DIVZERO:',
  'MOV EAX, OFFSET _A68D_M_DIV',
  'JMP _A68RT_FAIL',
  '@_A68RT_NILREF',
  '_A68RT_NILREF:',
  'MOV EAX, OFFSET _A68D_M_NIL',
  'JMP _A68RT_FAIL',
  '@_A68RT_BOUNDS',
  '_A68RT_BOUNDS:',
  'MOV EAX, OFFSET _A68D_M_BND',
  'JMP _A68RT_FAIL',
  '@_A68RT_CHKIDX',
  '; EAX = indice, ECX = borne basse, EDX = borne haute (conserves)',
  '_A68RT_CHKIDX:',
  'CMP EAX, ECX',
  'JL _A68R_ck1',
  'CMP EAX, EDX',
  'JG _A68R_ck1',
  'RET',
  '_A68R_ck1:',
  'MOV EAX, OFFSET _A68D_M_IDX',
  'JMP _A68RT_FAIL',
  '@_A68RT_ALLOC',
  '; EAX = octets -> EAX = bloc mis a zero (tas du processus)',
  '_A68RT_ALLOC:',
  'PUSH EAX',
  'CALL GetProcessHeap',
  'POP ECX',
  'PUSH ECX',
  'PUSH 8',
  'PUSH EAX',
  'CALL HeapAlloc',
  'TEST EAX, EAX',
  'JNE _A68R_al1',
  'MOV EAX, OFFSET _A68D_M_MEM',
  'JMP _A68RT_FAIL',
  '_A68R_al1:',
  'RET',
  '@_A68RT_NEWLINE',
  '_A68RT_NEWLINE:',
  'MOV ESI, OFFSET _A68D_CR',
  'MOV ECX, 2',
  'JMP _A68RT_PUT',
  '@_A68RT_SPACE',
  '_A68RT_SPACE:',
  'MOV ESI, OFFSET _A68D_SP',
  'MOV ECX, 1',
  'JMP _A68RT_PUT',
  '@_A68RT_WRITECHAR',
  '; EAX = code du caractere',
  '_A68RT_WRITECHAR:',
  'MOV BYTE PTR [_A68D_BUF], AL',
  'MOV ESI, OFFSET _A68D_BUF',
  'MOV ECX, 1',
  'JMP _A68RT_PUT',
  '@_A68RT_WRITESTR',
  '; EAX = adresse du descripteur de chaine',
  '_A68RT_WRITESTR:',
  'MOV ECX, DWORD PTR [EAX+8]',
  'SUB ECX, DWORD PTR [EAX+4]',
  'INC ECX',
  'MOV ESI, DWORD PTR [EAX]',
  'JMP _A68RT_PUT',
  '@_A68RT_WRITEBOOL',
  '_A68RT_WRITEBOOL:',
  'TEST EAX, EAX',
  'JE _A68R_wb1',
  'MOV ESI, OFFSET _A68D_TRUE',
  'MOV ECX, 4',
  'JMP _A68RT_PUT',
  '_A68R_wb1:',
  'MOV ESI, OFFSET _A68D_FALSE',
  'MOV ECX, 5',
  'JMP _A68RT_PUT',
  '@_A68RT_DIGITS',
  '; EAX = entier : chiffres decimaux dans [EDI, ESI) de _A68D_BUF',
  '_A68RT_DIGITS:',
  'MOV EDI, OFFSET _A68D_BUF',
  'ADD EDI, 60',
  'MOV ESI, EDI',
  'MOV ECX, EAX',
  'TEST EAX, EAX',
  'JNS _A68R_dg1',
  'NEG EAX',
  '_A68R_dg1:',
  'XOR EDX, EDX',
  'DIV DWORD PTR [_A68D_TEN]',
  'PUSH EAX',
  'MOV EAX, EDX',
  'ADD EAX, 48',
  'DEC EDI',
  'MOV BYTE PTR [EDI], AL',
  'POP EAX',
  'TEST EAX, EAX',
  'JNE _A68R_dg1',
  'TEST ECX, ECX',
  'JNS _A68R_dg2',
  'DEC EDI',
  'MOV BYTE PTR [EDI], 45',
  '_A68R_dg2:',
  'RET',
  '@_A68RT_WRITEINT',
  '; EAX = entier',
  '_A68RT_WRITEINT:',
  'CALL _A68RT_DIGITS',
  'MOV ECX, ESI',
  'SUB ECX, EDI',
  'MOV ESI, EDI',
  'JMP _A68RT_PUT',
  '@_A68RT_WRITEREAL',
  '; ST(0) = reel (depile) : notation fixe, 6 decimales au plus',
  '_A68RT_WRITEREAL:',
  'FSTP QWORD PTR [_A68D_Q]',
  'MOV EAX, DWORD PTR [_A68D_Q+4]',
  'MOV DWORD PTR [_A68D_SG], EAX',
  'AND EAX, 2147483647',
  'MOV DWORD PTR [_A68D_Q+4], EAX',
  'FLD QWORD PTR [_A68D_Q]',
  'FMUL QWORD PTR [_A68D_MILR]',
  'FISTP QWORD PTR [_A68D_Q]',
  'MOV EDI, OFFSET _A68D_BUF',
  'ADD EDI, 60',
  'MOV DWORD PTR [_A68D_ACC], EDI',
  'XOR ECX, ECX',
  '_A68R_wr1:',
  'MOV EAX, DWORD PTR [_A68D_Q+4]',
  'XOR EDX, EDX',
  'DIV DWORD PTR [_A68D_TEN]',
  'MOV DWORD PTR [_A68D_Q+4], EAX',
  'MOV EAX, DWORD PTR [_A68D_Q]',
  'DIV DWORD PTR [_A68D_TEN]',
  'MOV DWORD PTR [_A68D_Q], EAX',
  'ADD EDX, 48',
  'MOV EAX, EDX',
  'DEC EDI',
  'MOV BYTE PTR [EDI], AL',
  'INC ECX',
  'MOV EAX, DWORD PTR [_A68D_Q]',
  'OR EAX, DWORD PTR [_A68D_Q+4]',
  'JNE _A68R_wr1',
  'CMP ECX, 7',
  'JL _A68R_wr1',
  '; chiffres entiers : ECX - 6, a decaler d''une place pour la virgule',
  'MOV EDX, ECX',
  'SUB EDX, 6',
  'MOV ESI, EDI',
  'DEC EDI',
  'PUSH EDI',
  'MOV ECX, EDX',
  'REP MOVSB',
  'MOV BYTE PTR [EDI], 46',
  'POP ESI',
  'MOV EAX, DWORD PTR [_A68D_ACC]',
  '; zeros finaux : au moins une decimale',
  '_A68R_wr2:',
  'MOV EDX, EAX',
  'DEC EDX',
  'MOV ECX, EDI',
  'INC ECX',
  'CMP EDX, ECX',
  'JLE _A68R_wr3',
  'MOVZX ECX, BYTE PTR [EDX]',
  'CMP ECX, 48',
  'JNE _A68R_wr3',
  'MOV EAX, EDX',
  'JMP _A68R_wr2',
  '_A68R_wr3:',
  'MOV ECX, DWORD PTR [_A68D_SG]',
  'TEST ECX, ECX',
  'JNS _A68R_wr4',
  'DEC ESI',
  'MOV BYTE PTR [ESI], 45',
  '_A68R_wr4:',
  'MOV ECX, EAX',
  'SUB ECX, ESI',
  'JMP _A68RT_PUT',
  '@_A68RT_WHOLE',
  '; EAX = n, ECX = largeur -> EAX = descripteur d''une chaine nouvelle',
  '_A68RT_WHOLE:',
  'PUSH ECX',
  'CALL _A68RT_DIGITS',
  'POP EDX',
  'MOV ECX, ESI',
  'SUB ECX, EDI',
  'CMP EDX, ECX',
  'JGE _A68R_wh1',
  'MOV EDX, ECX',
  '_A68R_wh1:',
  'PUSH EDI',
  'PUSH ECX',
  'PUSH EDX',
  'MOV EAX, EDX',
  'ADD EAX, 16',
  'CALL _A68RT_ALLOC',
  'POP EDX',
  'POP ECX',
  'POP ESI',
  'MOV DWORD PTR [EAX+4], 1',
  'MOV DWORD PTR [EAX+8], EDX',
  'MOV DWORD PTR [EAX+12], 1',
  'MOV EDI, EAX',
  'ADD EDI, 16',
  'MOV DWORD PTR [EAX], EDI',
  'PUSH EAX',
  'MOV EAX, EDX',
  'SUB EAX, ECX',
  '_A68R_wh2:',
  'TEST EAX, EAX',
  'JLE _A68R_wh3',
  'MOV BYTE PTR [EDI], 32',
  'INC EDI',
  'DEC EAX',
  'JMP _A68R_wh2',
  '_A68R_wh3:',
  'REP MOVSB',
  'POP EAX',
  'RET',
  '@_A68RT_GETC',
  '; EAX = caractere suivant de l''entree standard, -1 en fin de fichier',
  '_A68RT_GETC:',
  'MOV EAX, DWORD PTR [_A68D_PEEK]',
  'CMP EAX, -2',
  'JE _A68R_gc1',
  'MOV DWORD PTR [_A68D_PEEK], -2',
  'RET',
  '_A68R_gc1:',
  'PUSH -10',
  'CALL GetStdHandle',
  'PUSH 0',
  'PUSH OFFSET _A68D_WR',
  'PUSH 1',
  'PUSH OFFSET _A68D_IN',
  'PUSH EAX',
  'CALL ReadFile',
  'MOV EAX, DWORD PTR [_A68D_WR]',
  'TEST EAX, EAX',
  'JE _A68R_gc2',
  'MOVZX EAX, BYTE PTR [_A68D_IN]',
  'RET',
  '_A68R_gc2:',
  'MOV EAX, -1',
  'RET',
  '@_A68RT_SKIPWS',
  '_A68RT_SKIPWS:',
  'CALL _A68RT_GETC',
  'CMP EAX, 32',
  'JE _A68RT_SKIPWS',
  'CMP EAX, 9',
  'JE _A68RT_SKIPWS',
  'CMP EAX, 10',
  'JE _A68RT_SKIPWS',
  'CMP EAX, 13',
  'JE _A68RT_SKIPWS',
  'RET',
  '@_A68RT_READCHAR',
  '_A68RT_READCHAR:',
  'CALL _A68RT_GETC',
  'CMP EAX, -1',
  'JNE _A68R_rc1',
  'XOR EAX, EAX',
  '_A68R_rc1:',
  'RET',
  '@_A68RT_READINT',
  '_A68RT_READINT:',
  'CALL _A68RT_SKIPWS',
  'MOV DWORD PTR [_A68D_SG], 0',
  'MOV DWORD PTR [_A68D_ACC], 0',
  'CMP EAX, 45',
  'JNE _A68R_ri1',
  'MOV DWORD PTR [_A68D_SG], 1',
  'CALL _A68RT_GETC',
  '_A68R_ri1:',
  'SUB EAX, 48',
  'CMP EAX, 9',
  'JA _A68R_ri2',
  'PUSH EAX',
  'MOV EAX, DWORD PTR [_A68D_ACC]',
  'IMUL EAX, DWORD PTR [_A68D_TEN]',
  'POP ECX',
  'ADD EAX, ECX',
  'MOV DWORD PTR [_A68D_ACC], EAX',
  'CALL _A68RT_GETC',
  'JMP _A68R_ri1',
  '_A68R_ri2:',
  'ADD EAX, 48',
  'MOV DWORD PTR [_A68D_PEEK], EAX',
  'MOV EAX, DWORD PTR [_A68D_ACC]',
  'MOV ECX, DWORD PTR [_A68D_SG]',
  'TEST ECX, ECX',
  'JE _A68R_ri3',
  'NEG EAX',
  '_A68R_ri3:',
  'RET',
  '@_A68RT_READREAL',
  '_A68RT_READREAL:',
  'CALL _A68RT_SKIPWS',
  'MOV DWORD PTR [_A68D_SG], 0',
  'MOV DWORD PTR [_A68D_CNT], 0',
  'MOV DWORD PTR [_A68D_DOT], 0',
  'CMP EAX, 45',
  'JNE _A68R_rr1',
  'MOV DWORD PTR [_A68D_SG], 1',
  'CALL _A68RT_GETC',
  '_A68R_rr1:',
  'FLDZ',
  '_A68R_rr2:',
  'CMP EAX, 46',
  'JNE _A68R_rr3',
  'MOV ECX, DWORD PTR [_A68D_DOT]',
  'TEST ECX, ECX',
  'JNE _A68R_rr5',
  'MOV DWORD PTR [_A68D_DOT], 1',
  'CALL _A68RT_GETC',
  'JMP _A68R_rr2',
  '_A68R_rr3:',
  'SUB EAX, 48',
  'CMP EAX, 9',
  'JA _A68R_rr4',
  'PUSH EAX',
  'FMUL QWORD PTR [_A68D_TEN8]',
  'FILD DWORD PTR [ESP]',
  'FADDP ST(1), ST(0)',
  'POP EAX',
  'MOV ECX, DWORD PTR [_A68D_DOT]',
  'ADD DWORD PTR [_A68D_CNT], ECX',
  'CALL _A68RT_GETC',
  'JMP _A68R_rr2',
  '_A68R_rr4:',
  'ADD EAX, 48',
  '_A68R_rr5:',
  'MOV DWORD PTR [_A68D_PEEK], EAX',
  '_A68R_rr6:',
  'MOV ECX, DWORD PTR [_A68D_CNT]',
  'TEST ECX, ECX',
  'JE _A68R_rr7',
  'FDIV QWORD PTR [_A68D_TEN8]',
  'DEC ECX',
  'MOV DWORD PTR [_A68D_CNT], ECX',
  'JMP _A68R_rr6',
  '_A68R_rr7:',
  'MOV EAX, DWORD PTR [_A68D_SG]',
  'TEST EAX, EAX',
  'JE _A68R_rr8',
  'FCHS',
  '_A68R_rr8:',
  'RET',
  '@_A68RT_READSTR',
  '; lit une ligne (256 caracteres au plus) -> EAX = descripteur',
  '_A68RT_READSTR:',
  'MOV EAX, 272',
  'CALL _A68RT_ALLOC',
  'MOV DWORD PTR [_A68D_BLK], EAX',
  'MOV EDX, EAX',
  'ADD EAX, 16',
  'MOV DWORD PTR [EDX], EAX',
  'MOV DWORD PTR [EDX+4], 1',
  'MOV DWORD PTR [EDX+12], 1',
  'MOV DWORD PTR [_A68D_ACC], 0',
  '_A68R_rs1:',
  'CALL _A68RT_GETC',
  'CMP EAX, 10',
  'JE _A68R_rs2',
  'CMP EAX, -1',
  'JE _A68R_rs2',
  'CMP EAX, 13',
  'JE _A68R_rs1',
  'MOV ECX, DWORD PTR [_A68D_ACC]',
  'CMP ECX, 256',
  'JGE _A68R_rs1',
  'MOV EDX, DWORD PTR [_A68D_BLK]',
  'MOV EDX, DWORD PTR [EDX]',
  'ADD EDX, ECX',
  'MOV BYTE PTR [EDX], AL',
  'INC ECX',
  'MOV DWORD PTR [_A68D_ACC], ECX',
  'JMP _A68R_rs1',
  '_A68R_rs2:',
  'MOV EDX, DWORD PTR [_A68D_BLK]',
  'MOV EAX, DWORD PTR [_A68D_ACC]',
  'MOV DWORD PTR [EDX+8], EAX',
  'MOV EAX, EDX',
  'RET',
  '@_A68RT_STRCAT',
  '; ESI et EDI = descripteurs -> EAX = descripteur de ESI + EDI',
  '_A68RT_STRCAT:',
  'PUSH ESI',
  'PUSH EDI',
  'MOV EAX, DWORD PTR [ESI+8]',
  'SUB EAX, DWORD PTR [ESI+4]',
  'INC EAX',
  'TEST EAX, EAX',
  'JGE _A68R_sc1',
  'XOR EAX, EAX',
  '_A68R_sc1:',
  'MOV DWORD PTR [_A68D_ACC], EAX',
  'MOV EAX, DWORD PTR [EDI+8]',
  'SUB EAX, DWORD PTR [EDI+4]',
  'INC EAX',
  'TEST EAX, EAX',
  'JGE _A68R_sc2',
  'XOR EAX, EAX',
  '_A68R_sc2:',
  'MOV DWORD PTR [_A68D_CNT], EAX',
  'ADD EAX, DWORD PTR [_A68D_ACC]',
  'ADD EAX, 16',
  'CALL _A68RT_ALLOC',
  'POP EDI',
  'POP ESI',
  'MOV EDX, EAX',
  'MOV DWORD PTR [EDX+4], 1',
  'MOV ECX, DWORD PTR [_A68D_ACC]',
  'ADD ECX, DWORD PTR [_A68D_CNT]',
  'MOV DWORD PTR [EDX+8], ECX',
  'MOV DWORD PTR [EDX+12], 1',
  'MOV EAX, EDX',
  'ADD EAX, 16',
  'MOV DWORD PTR [EDX], EAX',
  'PUSH EDI',
  'MOV EDI, EAX',
  'MOV ECX, DWORD PTR [_A68D_ACC]',
  'MOV ESI, DWORD PTR [ESI]',
  'REP MOVSB',
  'POP ESI',
  'MOV ECX, DWORD PTR [_A68D_CNT]',
  'MOV ESI, DWORD PTR [ESI]',
  'REP MOVSB',
  'MOV EAX, EDX',
  'RET',
  '@_A68RT_STRCMP',
  '; ESI et EDI = descripteurs -> EAX < 0, 0 ou > 0',
  '_A68RT_STRCMP:',
  'MOV EAX, DWORD PTR [ESI+8]',
  'SUB EAX, DWORD PTR [ESI+4]',
  'INC EAX',
  'TEST EAX, EAX',
  'JGE _A68R_sm1',
  'XOR EAX, EAX',
  '_A68R_sm1:',
  'MOV EDX, DWORD PTR [EDI+8]',
  'SUB EDX, DWORD PTR [EDI+4]',
  'INC EDX',
  'TEST EDX, EDX',
  'JGE _A68R_sm2',
  'XOR EDX, EDX',
  '_A68R_sm2:',
  'PUSH EAX',
  'PUSH EDX',
  'MOV ECX, EAX',
  'CMP EDX, ECX',
  'JGE _A68R_sm3',
  'MOV ECX, EDX',
  '_A68R_sm3:',
  'MOV ESI, DWORD PTR [ESI]',
  'MOV EDI, DWORD PTR [EDI]',
  '_A68R_sm4:',
  'TEST ECX, ECX',
  'JE _A68R_sm6',
  'MOVZX EAX, BYTE PTR [ESI]',
  'MOVZX EDX, BYTE PTR [EDI]',
  'CMP EAX, EDX',
  'JNE _A68R_sm5',
  'INC ESI',
  'INC EDI',
  'DEC ECX',
  'JMP _A68R_sm4',
  '_A68R_sm5:',
  'SUB EAX, EDX',
  'ADD ESP, 8',
  'RET',
  '_A68R_sm6:',
  'POP EDX',
  'POP EAX',
  'SUB EAX, EDX',
  'RET',
  '@_A68RT_POW',
  '; EAX ** EDX, entiers',
  '_A68RT_POW:',
  'TEST EDX, EDX',
  'JS _A68R_pw4',
  'MOV ECX, EAX',
  'MOV EAX, 1',
  '_A68R_pw1:',
  'TEST EDX, EDX',
  'JE _A68R_pw3',
  'SHR EDX, 1',
  'JAE _A68R_pw2',
  'IMUL EAX, ECX',
  '_A68R_pw2:',
  'IMUL ECX, ECX',
  'JMP _A68R_pw1',
  '_A68R_pw3:',
  'RET',
  '_A68R_pw4:',
  'CMP EAX, 1',
  'JE _A68R_pw5',
  'CMP EAX, -1',
  'JE _A68R_pw6',
  'XOR EAX, EAX',
  'RET',
  '_A68R_pw5:',
  'MOV EAX, 1',
  'RET',
  '_A68R_pw6:',
  'SHR EDX, 1',
  'JAE _A68R_pw5',
  'RET',
  '@_A68RT_EXP2',
  '; ST(0) = v -> ST(0) = 2 ** v',
  '_A68RT_EXP2:',
  'FLD ST(0)',
  'FRNDINT',
  'FXCH ST(1)',
  'FSUB ST(0), ST(1)',
  'F2XM1',
  'FLD1',
  'FADDP ST(1), ST(0)',
  'FSCALE',
  'FSTP ST(1)',
  'RET',
  '@_A68RT_RPOW',
  '; ST(0) = base, ST(1) = exposant -> ST(0) = base ** exposant',
  '_A68RT_RPOW:',
  'FTST',
  'FNSTSW AX',
  'SAHF',
  'JA _A68R_rp1',
  'JB _A68R_rp2',
  'FSTP ST(0)',
  'FSTP ST(0)',
  'FLDZ',
  'RET',
  '_A68R_rp1:',
  'FYL2X',
  'JMP _A68RT_EXP2',
  '_A68R_rp2:',
  'FABS',
  'FXCH ST(1)',
  'FLD ST(0)',
  'FISTP DWORD PTR [_A68D_ACC]',
  'FXCH ST(1)',
  'FYL2X',
  'CALL _A68RT_EXP2',
  'MOV EAX, DWORD PTR [_A68D_ACC]',
  'SHR EAX, 1',
  'JAE _A68R_rp3',
  'FCHS',
  '_A68R_rp3:',
  'RET',
  '@_A68RT_FLOOR',
  '; ST(0) -> EAX = partie entiere par defaut (depile)',
  '_A68RT_FLOOR:',
  'SUB ESP, 12',
  'FNSTCW WORD PTR [ESP]',
  'MOVZX EAX, WORD PTR [ESP]',
  'AND EAX, 62463',
  'OR EAX, 1024',
  'MOV DWORD PTR [ESP+4], EAX',
  'FLDCW WORD PTR [ESP+4]',
  'FISTP DWORD PTR [ESP+8]',
  'FLDCW WORD PTR [ESP]',
  'MOV EAX, DWORD PTR [ESP+8]',
  'ADD ESP, 12',
  'RET',
  '@_A68RT_RTOI',
  '; ST(0) -> EAX = entier le plus proche (demi vers le haut)',
  '_A68RT_RTOI:',
  'FLD QWORD PTR [_A68D_HALF]',
  'FADDP ST(1), ST(0)',
  'JMP _A68RT_FLOOR',
  '@_A68RT_RSIGN',
  '; ST(0) -> EAX = -1, 0 ou 1 (depile)',
  '_A68RT_RSIGN:',
  'FTST',
  'FNSTSW AX',
  'SAHF',
  'FSTP ST(0)',
  'JA _A68R_sg1',
  'JB _A68R_sg2',
  'XOR EAX, EAX',
  'RET',
  '_A68R_sg1:',
  'MOV EAX, 1',
  'RET',
  '_A68R_sg2:',
  'MOV EAX, -1',
  'RET'
  );

Var
  RtStart   : Array[0..RT_MAX_ROUT] Of Integer;   { 1re ligne de routine }
  RtName    : Array[0..RT_MAX_ROUT - 1] Of TString;
  RtUsed    : Array[0..RT_MAX_ROUT - 1] Of Boolean;
  RtCount   : Integer;
  RtLine    : TString;                             { ligne assemblee }
  RtPos     : Integer;
  RtDataMade: Array[0..63] Of Integer;
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
      P := Pos(A68_RT_PFX, S);
      While P > 0 Do
      Begin
        E := P;
        While (E <= Length(S)) And RtIdChar(S[E]) Do Inc(E);
        Id := Copy(S, P, E - P);
        RtMark(Id);
        S := Copy(S, E, Length(S));
        P := Pos(A68_RT_PFX, S);
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
  If RtDataN > 63 Then FatalError('erreur interne: trop de donnees runtime');
  RtDataMade[RtDataN] := Sym;
  Inc(RtDataN);
  N := NameTab[Sym];
  If N = '_A68D_BUF' Then DataAddZero(Sym, 64)
  Else If N = '_A68D_Q' Then DataAddZero(Sym, 8)
  Else If (N = '_A68D_WR') Or (N = '_A68D_IN') Or (N = '_A68D_SG') Or
          (N = '_A68D_ACC') Or (N = '_A68D_CNT') Or (N = '_A68D_DOT') Or
          (N = '_A68D_BLK') Then DataAddZero(Sym, 4)
  Else If N = '_A68D_PEEK' Then RtDataInt(Sym, -2)
  Else If N = '_A68D_TEN'  Then RtDataInt(Sym, 10)
  Else If N = '_A68D_CR'   Then RtDataStr(Sym, #13#10)
  Else If N = '_A68D_SP'   Then RtDataStr(Sym, ' ')
  Else If N = '_A68D_TRUE' Then RtDataStr(Sym, 'TRUE')
  Else If N = '_A68D_FALSE' Then RtDataStr(Sym, 'FALSE')
  Else If N = '_A68D_M_IDX' Then
    RtDataStr(Sym, 'Erreur: indice hors bornes'#13#10)
  Else If N = '_A68D_M_BND' Then
    RtDataStr(Sym, 'Erreur: tableaux de dimensions differentes'#13#10)
  Else If N = '_A68D_M_NIL' Then
    RtDataStr(Sym, 'Erreur: reference NIL'#13#10)
  Else If N = '_A68D_M_DIV' Then
    RtDataStr(Sym, 'Erreur: division par zero'#13#10)
  Else If N = '_A68D_M_MEM' Then
    RtDataStr(Sym, 'Erreur: memoire insuffisante'#13#10)
  Else If N = '_A68D_MILR' Then RtDataReal(Sym, 0, $412E8480)
  Else If N = '_A68D_TEN8' Then RtDataReal(Sym, 0, $40240000)
  Else If N = '_A68D_HALF' Then RtDataReal(Sym, 0, $3FE00000)
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
  If Copy(Name, 1, 6) = '_A68D_' Then RtData(K);
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
  If Mn = 'REP' Then
  Begin
    RtSkip;
    Mn := 'REP ' + RtIdent;
  End;
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
  For I := 0 To CodeCount - 1 Do
    If (CodeTab[I].A.Kind = OK_LABEL) And
       (CodeTab[I].Op In [OP_CALL, OP_JMP]) Then
    Begin
      S := NameTab[CodeTab[I].A.Sym];
      If Copy(S, 1, Length(A68_RT_PFX)) = A68_RT_PFX Then RtMark(S);
    End;
  For I := 0 To DeferCount - 1 Do
    If (DeferTab[I].A.Kind = OK_LABEL) And
       (DeferTab[I].Op In [OP_CALL, OP_JMP]) Then
    Begin
      S := NameTab[DeferTab[I].A.Sym];
      If Copy(S, 1, Length(A68_RT_PFX)) = A68_RT_PFX Then RtMark(S);
    End;
  Any := False;
  For R := 0 To RtCount - 1 Do
    If RtUsed[R] Then Any := True;
  If Not Any Then
  Begin
    If Opts.Verbose Then WriteLn('  runtime : aucune routine');
    Exit;
  End;
  If Opts.Verbose Then
  Begin
    Write('  runtime :');
    For R := 0 To RtCount - 1 Do
      If RtUsed[R] Then
        Write(' ', Copy(RtName[R], Length(A68_RT_PFX) + 1, 40));
    WriteLn;
  End;
  Start := CodeCount;
  EmitBlank;
  EmitComment('---- runtime AL68CW32 (routines utilisees) ----');
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
  SECTION 15 - ERREURS ET RAPPORT FINAL (TODO 23, 24)
  ============================================================ }
Procedure PhaseReport;
Begin
  If ErrorCount > 0 Then
    WriteLn('Compilation echouee : ', ErrorCount, ' erreur(s), ',
            WarnCount, ' avertissement(s)')
  Else If (WarnCount > 0) Or Opts.Verbose Then
  Begin
    If Opts.Verbose Then
    Begin
      Write('  fichier(s) produit(s) : ', Opts.OutFile);
      If Opts.EmitAsm Then Write(', ', Opts.AsmFile);
      If Opts.DebugMode Then Write(', ', ReplaceExt(Opts.OutFile, '.lst'));
      WriteLn;
    End;
    WriteLn('Compilation terminee : 0 erreur, ', WarnCount,
            ' avertissement(s)');
  End;
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
  If Opts.DebugMode Then ModeDump(0);
  PreludeInit;
  PreludeModes := ModeCount;
  CodeInit;
  TempSeq := 0;
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
