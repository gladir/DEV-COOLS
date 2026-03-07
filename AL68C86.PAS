{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Algol 68 vers assembleur 8086
}

(* ============================================================
  AL68C86.PAS - Compilateur Algol 68 -> Assembleur 8086 (MASM/TASM)
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
            ParseArgs : analyser argv (source.a68 [sortie.asm] [-v] [-d] [-w])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .a68 ou .algol
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LEXEUR (TOKENS ALGOL 68) [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_INT_DEN, TK_REAL_DEN, TK_BOOL_DEN,
              TK_CHAR_DEN, TK_STRING_DEN, TK_IDENT, TK_BOLD, TK_OP,
              TK_ASSIGN, TK_BUS, TK_COMMA, TK_SEMI, TK_OPEN, TK_CLOSE
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            Mots gras (bold words) en majuscules : BEGIN END IF THEN ELSE
              FI CASE IN OUT ESAC FOR FROM TO BY WHILE DO OD
              PROC OP PRIO MODE STRUCT UNION REF LOC HEAP
              INT REAL BOOL CHAR BITS BYTES COMPL STRING VOID
              PAR CO COMMENT PR PRAGMAT NIL SKIP TRUE FALSE
              AND OR NOT OF AT IS ISNT EMPTY
            Symboles speciaux : := (devient), =: (assignation inversee),
              +* (I pour COMPL), //: (sur), /:= (divab),
              +:= (plusab), -:= (minusab), *:= (timesab)
            Commentaires : CO ... CO, COMMENT ... COMMENT, # ... #
            Pragmats : PR ... PR, PRAGMAT ... PRAGMAT
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - DENOTATIONS (LITTERAUX) [IMPLEMENTE]
            Entiers (INT denotation) : 0..65535 (suite de chiffres)
              Bases : 2r1010, 4r123, 8r77, 16rFF (radix r digits)
            Reels (REAL denotation) : 3.14, 1.5e-3, .5e2
              Reconnus par le lexeur, traites comme entiers (trunc)
            Booleens : TRUE -> AX=1, FALSE -> AX=0
            Caracteres (CHAR denotation) : "a" (un seul caractere entre guillemets)
              Caracteres speciaux : """" (guillemet echappe par doublement)
            Chaines (STRING denotation) : "abc" -> pointeur vers donnees DATA
              Concatenation implicite de chaines adjacentes
            VOID : pas de valeur, denotation SKIP ou EMPTY
            NIL : reference nulle -> AX=0
            ExprMakeImm, ExprMakeNone, ExprMakeBool, ExprMakeVoid, ExprMakeNil
            LitEvalInt, LitEvalFloat, LitEval (dispatcher)
            DataAdd, DataAddStr, DataAddWord (segment DATA avec dedup)
            EmitDataSeg : emission _DATA SEGMENT avec donnees predefinies
            Indices de mode : TY_IDX_INT/REAL/BOOL/CHAR/BITS/STRING/VOID/REF

  TODO 04 - OPERATEURS ET PRIORITES
            Niveaux de priorite standard (1 a 9, 9 = plus fort) :
              Priorite 1 : OR (ou logique, court-circuit)
              Priorite 2 : AND (et logique, court-circuit)
              Priorite 3 : = /= < <= > >= (comparaison)
              Priorite 4 : - + (addition, soustraction binaire)
              Priorite 5 : * / OVER MOD (multiplication, division)
              Priorite 6 : ** (exponentiation -> appel _A68RT_POWER)
              Priorite 7 : NOT ABS ARG BIN CONJ IM LENG
                LEVEL ODD RE REPR ROUND SHORTEN SIGN (monadiques)
              Priorite 8 : ELEM SHL SHR UP DOWN LWB UPB
              Priorite 9 : +* I (partie imaginaire COMPL)
            Operateurs d affectation : +:= -:= *:= /:= (plusab, minusab, ...)
            ParseFormula(MinPrio) : analyseur de Pratt avec priorites

  TODO 05 - TABLE DES SYMBOLES ET PORTEES
            TSymKind : SK_IDENT (identite), SK_VAR (variable REF),
              SK_PROC (procedure), SK_OP (operateur), SK_MODE (type),
              SK_LABEL (etiquette), SK_PRIO (priorite d operateur)
            TSymRec : Name, MangledName, Kind, ModeIdx, Offset,
              ScopeLevel, IsParam, IsHeap, IsLoc
            SymAdd, SymFind, SymFindInScope, SymMangle
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            SymEnterScope / SymLeaveScope : gestion des portees
            Portees imbriquees : chaque clause ouvre une portee
              (BEGIN..END, IF..FI, DO..OD, parentheses, etc.)
            Regles de visibilite Algol 68 : identification
              d un identificateur dans la plus petite portee englobante

  TODO 06 - SYSTEME DE MODES (TYPES)
            TModeKind : MK_INT (16 bits signe), MK_REAL (stub entier),
              MK_BOOL (8 bits), MK_CHAR (8 bits), MK_BITS (16 bits),
              MK_BYTES (tableau octets), MK_COMPL (paire d entiers),
              MK_STRING (ptr chaine dynamique), MK_VOID,
              MK_STRUCT (structure), MK_UNION (mode uni),
              MK_REF (reference), MK_PROC (procedure),
              MK_ARRAY (tableau flexible), MK_ROW (rangee)
            ModeTab, ModeInit : enregistrer les modes primitifs et utilisateur
            Declaration MODE : MODE NEWMODE = definition;
              Equivalence structurelle des modes (pas nominale)
            ModeSizeof : INT=2, REAL=2, BOOL=1, CHAR=1, BITS=2,
              COMPL=4, REF=2, pointeurs=2
            LONG et SHORT prefixes : LONG INT, SHORT REAL, etc.
              (avertissement : non supportes, traites comme INT/REAL)
            Verification de compatibilite : mode source vs mode cible

  TODO 07 - COERCITIONS (COERCIONS)
            Les 6 coercitions Algol 68, appliquees automatiquement :
            Dereferencement (dereferencing) : REF M -> M
              MOV BX,AX / MOV AX,[BX] (suivre le pointeur)
            Deproceduration (deproceduring) : PROC M -> M
              CALL adresse_proc -> resultat dans AX
            Elargissement (widening) : INT -> REAL, REAL -> COMPL
              (en pratique : NOP ou extension de signe)
            Mise en rangee (rowing) : M -> [1:1] M (singleton array)
              Creer un tableau d un element sur la pile
            Unification (uniting) : M -> UNION(M, ...) 
              Encapsuler la valeur avec un discriminant de mode
            Vidage (voiding) : M -> VOID
              Ignorer le resultat (POP ou ne pas utiliser AX)
            Chaine de coercitions : appliquer dans l ordre canonique
              deref -> deproc -> widen -> row -> unite -> void
            Contexte de coercition : fort, ferme, faible, doux, meek

  TODO 08 - EMETTEUR DE CODE ASM
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _A68L_NNNNN)
            Prefixes : _A68V_ (variable), _A68P_ (procedure),
              _A68K_ (chaine const), _A68RT_ (runtime), _A68L_ (label),
              _A68M_ (mode/type info), _A68O_ (operateur utilisateur)
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
            EmitProlog / EmitEpilog : PUSH BP / MOV BP,SP et MOV SP,BP / POP BP
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS

  TODO 09 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_ARRAY/DK_STRUCT),
              IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddStruct : variantes d ajout
            Variables globales : entrees DK_WORD dans DATA avec label _A68V_nom
            Constantes : entrees DK_WORD ou DK_STR (immuables)
            Chaines litterales : DB 'abc',0 dans DATA avec label _A68K_N
            Descripteurs de tableaux : DW lwb, upb, taille_elem, offset_data
            Descripteurs de modes UNION : DW discriminant + donnees
            Pool de chaines pour STRING dynamique

  TODO 10 - DECLARATIONS D IDENTITE ET DE VARIABLE
            Declaration d identite : INT x = 42;
              Mode est fixe, valeur est constante ou expression
              Pas de REF implicite (x est une constante, pas une variable)
            Declaration de variable : REF INT x = LOC INT := 42;
              Forme abregee : INT x := 42 (cree un REF INT local)
              LOC : allocation locale sur la pile [BP-offset]
              HEAP : allocation dynamique sur le tas
                CALL _A68RT_ALLOC(CX=sizeof) -> AX=ptr
            Declarations multiples : INT a = 1, b = 2, c = 3;
            Declaration REF explicite : REF INT p = x;
              p est un alias vers la variable x (meme adresse)
            Initialisation obligatoire en Algol 68

  TODO 11 - EXPRESSIONS PRIMAIRES (UNITES PRIMAIRES)
            ParsePrimary : denotation, identificateur, appel de proc
            Clause fermee : (expr) ou BEGIN expr END
            Clause conditionnelle : IF/THEN/ELSE/FI ou (cond|val1|val2)
            Clause de cas : CASE/IN/OUT/ESAC ou (expr|val1,val2,...|defaut)
            Identificateur : recherche dans la table des symboles
            SKIP : valeur indefinie du mode requis -> 0
            NIL : reference nulle -> AX=0
            Appel de procedure : nom(args) -> PUSH args + CALL _A68P_nom
            Selection de champ : expr OF struct -> offset dans STRUCT
            Indexation de tableau : expr[indice] -> calcul offset element
            Tranche de tableau : expr[lo:up] -> nouveau descripteur

  TODO 12 - EXPRESSIONS BINAIRES ET FORMULES
            ParseFormula(MinPrio) : boucle de Pratt avec priorites 1 a 9
            Arithmetique entiere : ADD/SUB/IMUL/IDIV pour +, -, *, OVER
            MOD : IDIV -> resultat dans DX (reste)
            Comparaison : CMP + Jcc pour =, /=, <, <=, >, >=
            Comparaison STRING : CALL _A68RT_STRCMP -> drapeaux
            Logique AND : court-circuit JZ vers false-branch
            Logique OR : court-circuit JNZ vers true-branch
            NOT : XOR AX,1
            Concatenation + de STRING : CALL _A68RT_CONCAT -> AX=ptr
            Operateur +* (I) pour COMPL : combiner partie reelle et imaginaire
            Operateurs sur BITS : AND OR NOT (operations bit a bit)
              SHL SHR (decalage), ELEM (test de bit)
            Operateurs d affectation composes : +:= -:= *:= /:=
              Lire la variable, operer, reecrire

  TODO 13 - CLAUSES FERMEES ET CLAUSES SERIE
            Clause fermee (closed clause) :
              BEGIN serie END ou ( serie )
              Ouvre une nouvelle portee, la valeur est celle de la derniere unite
            Clause serie (serial clause) :
              suite d unites separees par ; (go-on symbol)
              La valeur de la clause serie est la valeur de la derniere unite
            Labels : label: (etiquette suivie de deux-points)
              GO TO label ou GOTO label -> JMP _A68L_label
            Clause VOID : clause serie dont la valeur est ignoree
            Emboitement de clauses : chaque clause ouvre sa portee
            Declaration locale dans une clause :
              BEGIN INT x := 5; x + 1 END -> resultat 6

  TODO 14 - CLAUSES CONDITIONNELLES (IF ET CASE)
            ParseIfClause : IF cond THEN unites ELIF cond THEN unites ELSE unites FI
              Forme abregee : (cond | val_vrai | val_faux)
              Emission TEST AX,AX / JZ pour condition fausse
              Labels : _A68L_ELIF_N, _A68L_ELSE_N, _A68L_FI_N
            ParseCaseClause : CASE expr IN unite1, unite2, ... OUT unites ESAC
              Forme abregee : (expr | val1, val2, ... | defaut)
              L expression doit etre de mode INT
              Emission : CMP AX,1 / JE label1, CMP AX,2 / JE label2, ...
              La clause OUT est executee si aucune valeur ne correspond
              Labels : _A68L_CASE_N, _A68L_COUT_N, _A68L_CESAC_N
            Clauses conditionnelles comme expressions :
              INT x = IF cond THEN 1 ELSE 2 FI
              Le mode des deux branches doit etre compatible

  TODO 15 - CLAUSES REPETITIVES (BOUCLES)
            ParseLoopClause :
              FOR id FROM debut TO fin BY pas WHILE cond DO unites OD
              Tous les mots-cles sauf DO/OD sont optionnels
            FOR id : variable de boucle locale, mode INT, non modifiable
              Si FOR absent, pas de variable de boucle
            FROM debut : valeur initiale (defaut 1)
            TO fin : borne superieure (si absent, boucle infinie)
              DOWNTO n : equivalent a BY -1 TO n
            BY pas : increment (defaut 1, negatif autorise)
            WHILE cond : condition testee a chaque iteration avant DO
              Permet des boucles while pures : WHILE cond DO ... OD
            DO unites OD : corps de la boucle
            Labels : _A68L_LFOR_N, _A68L_LTEST_N, _A68L_LBODY_N,
              _A68L_LINCR_N, _A68L_LEND_N
            Boucle infinie : DO ... OD (sans FOR/TO/WHILE)

  TODO 16 - STRUCTURES (STRUCT)
            Declaration : MODE POINT = STRUCT(INT x, INT y);
              Champs nommes avec leur mode
              Taille = somme des sizeof de chaque champ
            Acces aux champs : x OF point -> offset fixe depuis le debut
              ParseSelectionClause : ParsePrimary puis OF ident
              Emission : ADD AX, offset_champ
            Constructeur de structure : POINT(3, 7) -> allouer et remplir
              Empiler les valeurs dans l ordre des champs
            Affectation de structure : copie champ par champ ou REP MOVSW
            Structures imbriquees : MODE RECT = STRUCT(POINT tl, POINT br);
              Acces chaine : x OF tl OF rect -> offset cumule
            Comparaison de structures : pas d operateur = par defaut
              (l utilisateur peut definir un OP = avec STRUCT)

  TODO 17 - REFERENCES ET AFFECTATIONS
            REF MODE : reference (pointeur) vers un objet de mode MODE
              Tout variable est implicitement un REF
            Affectation := : expr_dest := expr_source
              La destination doit etre de mode REF M
              Dereferencer si necessaire, puis MOV [dest], source
            Affectation inversee =: : expr_source =: expr_dest
              Meme semantique, operandes inverses syntaxiquement
            LOC MODE : allocation locale sur la pile
              SUB SP, sizeof(MODE) -> adresse en [BP-offset]
            HEAP MODE : allocation dynamique sur le tas
              CALL _A68RT_ALLOC(CX=sizeof) -> AX=ptr
            REF REF MODE : double indirection (reference vers reference)
            NIL : reference nulle, compatible avec tout REF M
              Test IS NIL / ISNT NIL : CMP AX,0 / JE ou JNE
            Identite IS / ISNT : comparer deux references (adresses)
              IS -> CMP + JE, ISNT -> CMP + JNE

  TODO 18 - TABLEAUX ET TRANCHES (ROWS)
            Declaration : [1:10] INT a -> tableau de 10 entiers
              Bornes flexibles : lwb et upb arbitraires (pas seulement 0 ou 1)
            Descripteur de tableau : (lwb, upb, taille_elem, ptr_data)
              Stocke dans DATA ou sur la pile selon LOC/HEAP
            Acces par index : a[i] -> calcul offset (i - lwb) * elem_size
              Verification de bornes : CMP + JB/JA -> erreur si hors limites
            Tranche (trimming) : a[lo:up] -> nouveau descripteur
              Meme donnees, bornes modifiees
            Tranche avec pas : a[lo:up AT 1] -> reindexation a partir de 1
            LWB et UPB : bornes inferieure et superieure d un tableau
              LWB a -> AX = borne inf, UPB a -> AX = borne sup
            Tableaux multidimensionnels : [1:m, 1:n] INT matrice
              Descripteur etendu, calcul offset linearise
            STRING comme [1:n] CHAR : flexible, concatenable
            Affectation de tableau : copie element par element ou REP MOVSW
            Constructeur de rangee : (1, 2, 3) en contexte de rowing

  TODO 19 - PROCEDURES (PROC)
            Declaration : PROC nom = (params) MODE : corps;
              Forme abregee : PROC nom = (INT x) INT : x + 1;
            PROC VOID : procedure sans valeur de retour
            Parametres par valeur : copie sur la pile
            Parametres REF (par reference) : passage d adresse
            Convention d appel : cdecl 16 bits, arguments empiles gauche a droite
            Prologue : PUSH BP / MOV BP,SP / SUB SP, locals_size
            Epilogue : MOV SP,BP / POP BP / RET
            Valeur de retour : resultat de la derniere expression du corps -> AX
            Procedures comme valeurs de premier ordre :
              PROC(INT)INT f = ma_proc;
              Variables de type PROC -> pointeur de code
              Appel indirect : CALL [AX]
            Recursion : supportee naturellement via la pile
            Procedures locales (imbriquees) : acces au cadre englobant
              via lien statique (pointeur vers BP du parent)

  TODO 20 - DEFINITIONS D OPERATEURS (OP ET PRIO)
            OP + = (INT a, INT b) INT : ... ;
              Definition ou redefinition d un operateur dyadique
            OP - = (INT a) INT : ... ;
              Definition d un operateur monadique (un seul operande)
            PRIO MONOP = 7;
              Declaration de la priorite d un nouvel operateur (1 a 9)
            Operateurs standard predefinis : +, -, *, /, OVER, MOD,
              =, /=, <, <=, >, >=, AND, OR, NOT, ABS, etc.
            Surcharge d operateurs : meme symbole, modes differents
              Resolution par le mode des operandes
            Operateurs d affectation : OP +:= = (REF INT a, INT b) REF INT : ...
            Table des operateurs : OpTab[0..MAX_OP-1]
              TOpRec : Name, Prio, LeftMode, RightMode, ResultMode, ProcLabel
            Emission : meme code qu un appel PROC
              PUSH operandes + CALL _A68O_nom_modes

  TODO 21 - MODES UNIS (UNION) ET CLAUSE DE CONFORMITE
            Declaration : MODE NOMBRE = UNION(INT, REAL);
              Un mode uni peut contenir l une des alternatives
            Representation : discriminant (DW) + donnees (taille = max des alternatives)
            Unification (coercition) : INT -> UNION(INT, REAL)
              Stocker le discriminant du mode + la valeur
            Clause de conformite (conformity clause) :
              CASE expr IN
                (INT i) : utiliser i,
                (REAL r) : utiliser r
              OUT
                traitement par defaut
              ESAC
              Emission : CMP discriminant + JE pour chaque alternative
              Extraire la valeur et la lier a l identificateur local
            Test de mode : (expr | (INT) : ..., (REAL) : ... | ... )
            EMPTY : mode UNION vide (aucune alternative selectionnee)

  TODO 22 - TRANSPUT (ENTREES/SORTIES)
            Procedures standard de transput :
            print((args)) : ecriture sur stdout
              print(("Bonjour", newline))
              Accepte une liste heterogene : INT, REAL, BOOL, CHAR, STRING
              INT -> CALL _A68RT_PRINTINT(AX=valeur)
              CHAR -> INT 21h AH=02h DL=char
              STRING -> INT 21h AH=40h BX=1 CX=len SI=ptr
              newline -> ecriture CR+LF
            read((args)) : lecture depuis stdin
              read((x, y)) : lire des valeurs dans les variables
              INT -> CALL _A68RT_READINT -> AX
              CHAR -> INT 21h AH=01h -> AL
              STRING -> INT 21h AH=0Ah (lecture ligne)
            newline : constante PROC VOID (ecrire CR+LF)
            newpage : constante PROC VOID (ecrire FF)
            space : constante PROC VOID (ecrire espace)
            whole(n, width) : formater un entier avec largeur
            fixed(r, width, after) : formater un reel
            Fichiers : open, close, get, put (simplifie)

  TODO 23 - CLAUSES COLLATERALES ET PARALLELES
            Clause collaterale : (unite1, unite2, unite3)
              Les unites sont evaluees dans un ordre indefini
              En pratique, evaluation gauche a droite sur 8086
              Utilisee pour les constructeurs de rangees et structures
            Clause parallele : PAR(unite1, unite2, unite3)
              PAR BEGIN tache1, tache2 END
              Non supportee sur DOS 8086 mono-tache
              Emission : avertissement "PAR non supporte, evaluation sequentielle"
              Evaluer les unites sequentiellement avec avertissement
            Clause collaterale d elaboration :
              PAR(INT a := 1, INT b := 2) : declarations simultanees
              Meme traitement que collaterale simple

  TODO 24 - RUNTIME MINIMAL
            _A68RT_PRINT(BX=handle, SI=msg, CX=len) : INT 21h AH=40h
            _A68RT_PRINTLN : _A68RT_PRINT + CR+LF via _A68_CRLF DB 13,10,0
            _A68RT_STRLEN(SI=str) : compter octets jusqu a 0 -> AX
            _A68RT_PRINTINT(AX=n) : entier signe -> ASCII + ecriture stdout
            _A68RT_PRINTBOOL(AX=n) : ecrire TRUE ou FALSE
            _A68RT_READINT : lecture chaine + conversion -> AX (atoi)
            _A68RT_READCHAR : INT 21h AH=01h -> AL
            _A68RT_READLINE(DI=buf, CX=max) : lecture ligne stdin
            _A68RT_NUMTOSTR(AX=n, DI=buf) : entier signe -> ASCII (itoa)
            _A68RT_STRTONUM(SI=str) : ASCII -> entier -> AX (atoi)
            _A68RT_CONCAT(SI=src1, DI=src2) : concatenation STRING -> AX=ptr
            _A68RT_STRCMP(SI=str1, DI=str2) : comparaison -> drapeaux ZF/CF
            _A68RT_STRTRIM(SI=str, BX=lo, CX=up) : tranche -> AX=ptr
            _A68RT_ALLOC(CX=nb_octets) : allocation heap -> AX=ptr
            _A68RT_POWER(AX=base, BX=exp) : exponentiation entiere -> AX
            _A68RT_ABS(AX=n) : valeur absolue -> AX
            _A68RT_ODD(AX=n) : test parite -> AX=0|1
            _A68RT_SIGN(AX=n) : signe -> AX=-1|0|1
            _A68RT_CHKIDX(AX=idx, BX=lwb, CX=upb) : verification bornes
              -> erreur si hors bornes
            _A68RT_CHKNIL(AX=ptr) : verification reference nulle
              -> erreur si AX=0
            _A68RT_PANIC(SI=msg) : affiche message + MOV AX,4C01h + INT 21h
            RuntimeEmitted : flag pour n emettre le runtime qu une seule fois
            Heap statique : _A68_HEAP DB 4096 DUP(0) + _A68_HEAPTOP DW 0

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitClose : END _A68P_Main dans _TEXT ENDS / DATA ENDS
            Run : pipeline complet LexInit -> ParseProgram ->
              EmitRuntime -> _TEXT ENDS / EmitDataSeg / END _A68P_Main
            Fichiers SAMPLES\ALGOL68\ a creer :
              hello.a68    (print, STRING, newline, denotations)
              math.a68     (operateurs, INT, REAL, ABS, SIGN, ODD)
              control.a68  (IF/FI, CASE/ESAC, boucles FOR/DO/OD)
              arrays.a68   (tableaux, tranches, LWB, UPB, STRING)
              structs.a68  (STRUCT, selection OF, constructeurs)
              refs.a68     (REF, LOC, HEAP, :=, IS, ISNT, NIL)
              procs.a68    (PROC, recursion, procedures comme valeurs)
              ops.a68      (OP, PRIO, surcharge d operateurs)
              union.a68    (UNION, clause de conformite, CASE IN)
              coerce.a68   (coercitions, widening, rowing, voiding)
            Smoke tests : AL68C86.EXE -v SAMPLES\ALGOL68\*.a68

  ============================================================ *)

Program AL68C86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  AL68_VERSION = '1.0';
  AL68_DATE    = '2026-03-06';

  { Limites internes }
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_MODE      = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_OP        = {$IFDEF FPC}128{$ELSE}32{$ENDIF};
  STACK_SIZE    = 1024;

  { Prefixes de nommage ASM }
  A68_VAR_PFX  = '_A68V_';    { variable (identite REF)             }
  A68_PROC_PFX = '_A68P_';    { procedure                           }
  A68_STR_PFX  = '_A68K_';    { constante chaine litterale          }
  A68_RT_PFX   = '_A68RT_';   { routine runtime                     }
  A68_LBL_PFX  = '_A68L_';    { label de saut interne               }
  A68_MODE_PFX = '_A68M_';    { info de mode (type)                 }
  A68_OP_PFX   = '_A68O_';    { operateur utilisateur               }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Indices de mode primitifs dans ModeTab (TODO 03/06) }
  TY_IDX_INT     = 0;   { INT  : entier 16 bits signe           }
  TY_IDX_REAL    = 1;   { REAL : reel (stub -> entier tronque)  }
  TY_IDX_BOOL    = 2;   { BOOL : booleen 8 bits                 }
  TY_IDX_CHAR    = 3;   { CHAR : caractere 8 bits               }
  TY_IDX_BITS    = 4;   { BITS : mot binaire 16 bits            }
  TY_IDX_STRING  = 5;   { STRING : chaine dynamique (ptr)       }
  TY_IDX_VOID    = 6;   { VOID : pas de valeur                  }
  TY_IDX_REF     = 7;   { REF (reference / pointeur)            }
  TY_IDX_COMPL   = 8;   { COMPL : paire re+im                   }
  TY_IDX_BYTES   = 9;   { BYTES : tableau d octets              }
  TY_IDX_UNKNOWN = -1;  { mode inconnu                          }

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;   { fichier source (.a68 / .algol)       }
    OutFile   : TString;   { fichier assembleur de sortie (.asm)  }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Warnings  : Boolean;   { -w : activer les avertissements      }
  End;

  { ---- Tokens Algol 68 (TODO 02) ------------------------- }
  TTokenKind = (
    TK_EOF,        { fin de fichier                         }
    TK_INT_DEN,    { denotation entiere 42 16rFF            }
    TK_REAL_DEN,   { denotation reelle 3.14 1.5e-3          }
    TK_BOOL_DEN,   { TRUE ou FALSE                          }
    TK_CHAR_DEN,   { denotation caractere "a"               }
    TK_STRING_DEN, { denotation chaine "abc"                }
    TK_IDENT,      { identificateur                         }
    TK_BOLD,       { mot gras (bold) BEGIN END IF etc.      }
    TK_OP,         { operateur + - * / := etc.              }
    TK_SEMI,       { ; (go-on symbol)                       }
    TK_COMMA,      { , (collateral)                         }
    TK_OPEN,       { (                                      }
    TK_CLOSE,      { )                                      }
    TK_BUS,        { =: (assignation inversee)              }
    TK_SUB,        { [ (indice)                             }
    TK_BUS2,       { ] (fin indice)                         }
    TK_COLON       { : (tranche / label)                    }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;     { valeur textuelle brute          }
    IntVal   : LongInt;     { valeur entiere (TK_INT_DEN)     }
    Line     : Integer;     { ligne source (1-base)           }
    Col      : Integer;     { colonne source (1-base)         }
  End;

  { ---- Categories de symboles (TODO 05) ------------------ }
  TSymCat = (
    SC_IDENT,      { identite (INT x = 42)                }
    SC_VAR,        { variable (REF INT x := 42)           }
    SC_PROC,       { procedure                            }
    SC_OP,         { operateur utilisateur                }
    SC_MODE,       { declaration de mode                  }
    SC_LABEL,      { etiquette                            }
    SC_PARAM       { parametre formel                     }
  );

  TSymRec = Record
    Name        : TString;   { identificateur Algol 68         }
    MangledName : TString;   { _A68V_nom / _A68P_nom           }
    Cat         : TSymCat;
    ModeIdx     : Integer;   { indice dans ModeTab             }
    ScopeLevel  : Integer;
    Offset      : Integer;   { [BP-n] pour locaux              }
    IsParam     : Boolean;   { parametre de procedure          }
    IsHeap      : Boolean;   { alloue sur le tas (HEAP)        }
    IsConst     : Boolean;   { identite constante              }
    DeclLine    : Integer;
  End;

  { ---- Modes (types) Algol 68 (TODO 06) ------------------ }
  TModeKind = (
    MK_INT,        { entier 16 bits signe                  }
    MK_REAL,       { reel (stub -> entier tronque)         }
    MK_BOOL,       { booleen 8 bits                        }
    MK_CHAR,       { caractere 8 bits                      }
    MK_BITS,       { mot binaire 16 bits                   }
    MK_BYTES,      { tableau d octets                      }
    MK_COMPL,      { paire d entiers (re, im)              }
    MK_STRING,     { chaine dynamique (ptr)                }
    MK_VOID,       { pas de valeur                         }
    MK_STRUCT,     { structure                             }
    MK_UNION,      { mode uni                              }
    MK_REF,        { reference (pointeur)                  }
    MK_PROC,       { procedure                             }
    MK_ROW,        { rangee (tableau)                      }
    MK_UNKNOWN     { mode inconnu                          }
  );

  TModeRec = Record
    Name    : TString;
    Kind    : TModeKind;
    Size    : Integer;   { octets : INT=2, BOOL=1, ptr=2    }
    ElemIdx : Integer;   { REF/ROW/PROC : mode element      }
  End;

  { ---- Valeurs d expression (TODO 11) -------------------- }
  TExprKind = (
    EK_NONE,   { void / pas de valeur            }
    EK_IMM,    { immediate dans ImmVal           }
    EK_AX,     { valeur dans AX                  }
    EK_MEM     { adresse [BP+Offset] ou label    }
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    ModeIdx : Integer;
    Offset  : Integer;
    SymIdx  : Integer;   { indice dans SymTab (-1 = pas de lvalue) }
  End;

  { ---- Segment de donnees (TODO 08) ---------------------- }
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY_BLK, DK_STRUCT_BLK);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;
  End;

  { ---- Operateurs utilisateur (TODO 20) ------------------- }
  TOpRec = Record
    Name      : TString;   { symbole ou nom de l operateur    }
    Prio      : Integer;   { priorite 1..9                    }
    LeftMode  : Integer;   { mode operande gauche (-1=monadique) }
    RightMode : Integer;   { mode operande droite             }
    ResMode   : Integer;   { mode du resultat                 }
    ProcLabel : TString;   { label de la procedure ASM        }
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  { Options }
  Opts : TOptions;

  { Compteurs generaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;
  TotalSyms  : Integer;

  { Valeur fictive pour ignorer un retour TExprVal }
  GExprDummy : TExprVal;

  { Lexeur (TODO 02) }
  LexSrcF    : Text;
  LexLine    : String;
  LexLineNo  : Integer;
  LexColNo   : Integer;
  LexEOF     : Boolean;
  LexOpened  : Boolean;
  CurToken   : TToken;

  { Table des symboles (TODO 05) }
  SymTab     : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount   : Integer;
  ScopeStack : Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeTop   : Integer;
  CurScope   : Integer;

  { Table des modes (TODO 06) }
  ModeTab   : Array[0..MAX_MODE - 1] Of TModeRec;
  ModeCount : Integer;

  { Emetteur ASM (TODO 08) }
  OutF         : Text;
  OutFOpen     : Boolean;
  CurFrameSize : Integer;    { taille cadre local courant (words)   }
  CurProcDepth : Integer;    { 0 = global, >0 = dans une proc      }
  CurProcRetLbl: TString;    { label epilogue de la proc courante   }
  CurProcName  : TString;    { nom de la procedure courante         }
  LoopTop      : Integer;
  LoopBreakLbl : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContLbl  : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LabelGenSeq  : Integer;    { compteur unique pour LabelGen        }

  { Segment de donnees (TODO 09) }
  DataTab   : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount : Integer;

  { Table des operateurs (TODO 20) }
  OpTab     : Array[0..MAX_OP - 1] Of TOpRec;
  OpCount   : Integer;

  { Etat general }
  RuntimeEmitted : Boolean;

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }

{ TODO 02 - Lexeur }
Procedure LexInit;             Forward;
Procedure LexClose;            Forward;
Procedure LexNextToken;        Forward;
Procedure PrintToken(Const T : TToken); Forward;
Procedure LexNextLine;         Forward;
Procedure LexError(Const Msg : TString); Forward;
Function  IsBoldWord(Const S : TString) : Boolean; Forward;
Function  IsIdentStart(Ch : Char) : Boolean; Forward;
Function  IsIdentCont(Ch : Char) : Boolean; Forward;
Function  IsHexDigit(Ch : Char) : Boolean; Forward;
Function  HexVal(Ch : Char) : Integer; Forward;
Procedure LexScanIdent;        Forward;
Procedure LexScanNumber;       Forward;
Procedure LexScanString;       Forward;
Procedure LexSkipComment(Const Closer : TString); Forward;
Procedure LexSkipHashComment;  Forward;
Procedure LexSkipPragmat(Const Closer : TString); Forward;

{ TODO 03 - Denotations }
Procedure ExprMakeImm(AVal : LongInt; AModeIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ExprMakeNone(Var Res : TExprVal); Forward;
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal); Forward;
Procedure ExprMakeVoid(Var Res : TExprVal); Forward;
Procedure ExprMakeNil(Var Res : TExprVal); Forward;
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
Function  DataAddWord(Const Lbl : TString;
                      AIntVal : LongInt) : Integer; Forward;

{ TODO 04 - Operateurs }
Function  BinOpPrec(Const Op : TString) : Integer; Forward;
Procedure ParseFormula(MinPrio : Integer; Var Res : TExprVal); Forward;

{ TODO 05 - Symboles }
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymAdd(Const Name : TString; Cat : TSymCat;
                 ModeIdx, Offset : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
Function  SymNextOffset : Integer; Forward;
Procedure SymInit;       Forward;

{ TODO 06 - Modes }
Procedure ModeInit;      Forward;
Function  ModeSizeof(ModeIdx : Integer) : Integer; Forward;

{ TODO 07 - Coercitions }
Procedure ApplyCoercion(SrcMode, DstMode : Integer); Forward;

{ TODO 08 - Emetteur ASM }
Function  LabelGen : TString; Forward;
Procedure EmitRaw(Const S : TString); Forward;
Procedure EmitLabel(Const Lbl : TString); Forward;
Procedure EmitInstr(Const Mnem : TString); Forward;
Procedure EmitOpen;      Forward;
Procedure EmitClose;     Forward;
Procedure EmitHeader;    Forward;
Procedure EmitProlog;    Forward;
Procedure EmitEpilog;    Forward;
Procedure EmitDataSeg;   Forward;
Procedure EmitRuntime;   Forward;

{ TODO 09 - Donnees }
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                  AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : TString; Forward;

{ TODO 10 - Declarations }
Procedure ParseDeclStmt; Forward;

{ TODO 11 - Expressions primaires }
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Procedure ParseExpr(Var Res : TExprVal); Forward;

{ TODO 12 - Expressions binaires }
Procedure ExprFlushToAX(Const E : TExprVal); Forward;

{ TODO 13 - Clauses fermees }
Procedure ParseSerialClause(Var Res : TExprVal); Forward;

{ TODO 14 - Conditionnelles }
Procedure ParseIfClause(Var Res : TExprVal); Forward;
Procedure ParseCaseClause(Var Res : TExprVal); Forward;

{ TODO 15 - Boucles }
Procedure ParseLoopClause; Forward;

{ TODO 16 - Structures }
Procedure ParseStructDecl; Forward;

{ TODO 17 - References }
Procedure ParseAssignment; Forward;

{ TODO 18 - Tableaux }
Procedure ParseRowDecl; Forward;

{ TODO 19 - Procedures }
Procedure ParseProcDecl; Forward;

{ TODO 20 - Operateurs }
Procedure ParseOpDecl;   Forward;
Procedure ParsePrioDecl; Forward;

{ TODO 21 - Union }
Procedure ParseUnionDecl; Forward;
Procedure ParseConformityClause(Var Res : TExprVal); Forward;

{ TODO 22 - Transput }
Procedure ParsePrint; Forward;
Procedure ParseRead;  Forward;

{ TODO 23 - Collateral / Parallele }
Procedure ParseCollateral(Var Res : TExprVal); Forward;

{ TODO 24 - Runtime }
{ (EmitRuntime deja declare plus haut) }

{ TODO 25 - Generation finale }
Procedure Run; Forward;

{ General }
Procedure ParseStmt; Forward;
Procedure ParserAdvance; Forward;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- Messages d erreur et d avertissement ---------------- }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('AL68C86: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
    Assign(OutF, Opts.OutFile);
    {$I-} Erase(OutF); {$I+}
  End;
  Halt(EXIT_ERROR);
End;

Procedure CompileError(Const Msg : TString);
Begin
  Write('AL68C86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('error: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, compilation arretee');
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  Write('AL68C86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('warning: ', Msg);
  Inc(WarnCount);
End;

{ ---- Banniere ---------------------------------------------- }

Procedure ShowBanner;
Begin
  WriteLn('AL68C86 v', AL68_VERSION, ' (', AL68_DATE, ')');
  WriteLn('Compilateur Algol 68 -> assembleur 8086 (MASM .MODEL SMALL)');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('Usage: AL68C86 <source.a68> [sortie.asm] [-v] [-d] [-w]');
  WriteLn;
  WriteLn('  source.a68 : fichier Algol 68 source (.a68 ou .algol)');
  WriteLn('  sortie.asm : fichier assembleur de sortie (defaut: source.asm)');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn;
  Halt(EXIT_USAGE);
End;

Procedure ShowHelp;
Begin
  ShowBanner;
  WriteLn('AL68C86 - Cette commande permet de lancer le compilateur Algol 68');
  WriteLn('pour l''assembleur du microprocesseur 8086.');
  WriteLn;
  ShowUsage;
End;

{ ---- Utilitaires chaines ------------------------------------ }

Function StrLowerCase(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'A') And (R[I] <= 'Z') Then
      R[I] := Chr(Ord(R[I]) + 32);
  StrLowerCase := R;
End;

Function StrUpperCase(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'a') And (R[I] <= 'z') Then
      R[I] := Chr(Ord(R[I]) - 32);
  StrUpperCase := R;
End;

Function IntToStr(N : LongInt) : TString;
Var
  S : TString;
Begin
  Str(N, S);
  IntToStr := S;
End;

{ Extrait le nom de base d un chemin (sans extension) }
Function BaseName(Const Path : TString) : TString;
Var
  I, LastSep, LastDot : Integer;
  S : TString;
Begin
  LastSep := 0;
  LastDot := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If LastDot > LastSep Then
    S := Copy(Path, LastSep + 1, LastDot - LastSep - 1)
  Else
    S := Copy(Path, LastSep + 1, Length(Path));
  BaseName := S;
End;

{ Extrait l extension d un chemin en minuscules }
Function ExtractExt(Const Path : TString) : TString;
Var
  I, LastDot, LastSep : Integer;
Begin
  LastDot := 0;
  LastSep := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If (LastDot > 0) And (LastDot > LastSep) Then
    ExtractExt := StrLowerCase(Copy(Path, LastDot, Length(Path) - LastDot + 1))
  Else
    ExtractExt := '';
End;

{ Remplace l extension d un chemin }
Function ReplaceExt(Const Path, NewExt : TString) : TString;
Var
  I, LastDot, LastSep : Integer;
Begin
  LastDot := 0;
  LastSep := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If (LastDot > 0) And (LastDot > LastSep) Then
    ReplaceExt := Copy(Path, 1, LastDot - 1) + NewExt
  Else
    ReplaceExt := Path + NewExt;
End;

{ ---- Initialisation des options ----------------------------- }

Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
End;

{ ---- Analyse des arguments de la ligne de commande --------- }

Procedure ParseArgs;
Var
  I   : Integer;
  Arg : TString;
  Ext : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowUsage;

  For I := 1 To ParamCount Do
  Begin
    Arg := ParamStr(I);

    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Then
      ShowHelp
    Else If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('AL68C86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('AL68C86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('AL68C86: fichier source manquant');
    ShowUsage;
  End;

  { Verifier l extension .a68 ou .algol }
  Ext := ExtractExt(Opts.SrcFile);
  If (Ext <> '.a68') And (Ext <> '.algol') Then
    WarnMsg('extension attendue .a68 ou .algol, recue: ' + Ext);

  If Opts.OutFile = '' Then
    Opts.OutFile := ReplaceExt(Opts.SrcFile, '.asm');
End;

{ ---- Nettoyage -------------------------------------------- }

Procedure Cleanup;
Begin
  If LexOpened Then
    LexClose;
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ---- Initialisation generale des variables globales -------- }

Procedure GlobalInit;
Begin
  ErrorCount     := 0;
  WarnCount      := 0;
  TotalLines     := 0;
  TotalSyms      := 0;
  SymCount       := 0;
  ScopeTop       := 0;
  CurScope       := 0;
  ModeCount      := 0;
  DataCount      := 0;
  OpCount        := 0;
  OutFOpen       := False;
  LexOpened      := False;
  LexEOF         := False;
  CurProcDepth   := 0;
  CurProcRetLbl  := '';
  CurProcName    := '';
  LoopTop        := 0;
  RuntimeEmitted := False;
  CurFrameSize   := 0;
  LabelGenSeq    := 0;
  GExprDummy.Kind    := EK_NONE;
  GExprDummy.ImmVal  := 0;
  GExprDummy.ModeIdx := -1;
  GExprDummy.Offset  := 0;
  GExprDummy.SymIdx  := -1;
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
End;

{ ---- Statistiques ----------------------------------------- }

Procedure ShowStats;
Begin
  WriteLn('Compilation terminee : ', Opts.SrcFile, ' -> ', Opts.OutFile);
  WriteLn('  Lignes         : ', TotalLines);
  WriteLn('  Symboles       : ', TotalSyms);
  WriteLn('  Erreurs        : ', ErrorCount);
  WriteLn('  Avertissements : ', WarnCount);
End;

{ ============================================================
  TODO 02 - LEXEUR (TOKENS ALGOL 68) [IMPLEMENTE]
  ============================================================ }

{ ---- Erreur lexicale --------------------------------------- }

Procedure LexError(Const Msg : TString);
Begin
  Write('AL68C86:');
  If LexLineNo > 0 Then
    Write(Opts.SrcFile, ':', LexLineNo, ':', LexColNo, ': ');
  WriteLn('lex error: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, compilation arretee');
End;

{ ---- IsBoldWord : verifier si un mot en majuscules est
       un mot gras (bold word / indicant) Algol 68 ---------- }

Function IsBoldWord(Const S : TString) : Boolean;
Begin
  IsBoldWord :=
    { Clauses et structure }
    (S = 'BEGIN')   Or (S = 'END')     Or (S = 'IF')       Or
    (S = 'THEN')    Or (S = 'ELIF')    Or (S = 'ELSE')     Or
    (S = 'FI')      Or (S = 'CASE')    Or (S = 'IN')       Or
    (S = 'OUT')     Or (S = 'ESAC')    Or (S = 'FOR')      Or
    (S = 'FROM')    Or (S = 'TO')      Or (S = 'BY')       Or
    (S = 'WHILE')   Or (S = 'DO')      Or (S = 'OD')       Or
    (S = 'GOTO')    Or (S = 'GO')      Or
    { Declarations }
    (S = 'PROC')    Or (S = 'OP')      Or (S = 'PRIO')     Or
    (S = 'MODE')    Or (S = 'STRUCT')  Or (S = 'UNION')    Or
    (S = 'REF')     Or (S = 'LOC')     Or (S = 'HEAP')     Or
    { Modes primitifs }
    (S = 'INT')     Or (S = 'REAL')    Or (S = 'BOOL')     Or
    (S = 'CHAR')    Or (S = 'BITS')    Or (S = 'BYTES')    Or
    (S = 'COMPL')   Or (S = 'STRING')  Or (S = 'VOID')     Or
    (S = 'LONG')    Or (S = 'SHORT')   Or (S = 'SEMA')     Or
    { Booleens et constantes }
    (S = 'TRUE')    Or (S = 'FALSE')   Or (S = 'NIL')      Or
    (S = 'SKIP')    Or (S = 'EMPTY')   Or
    { Operateurs bold }
    (S = 'AND')     Or (S = 'OR')      Or (S = 'NOT')      Or
    (S = 'OF')      Or (S = 'AT')      Or (S = 'IS')       Or
    (S = 'ISNT')    Or (S = 'ABS')     Or (S = 'ARG')      Or
    (S = 'BIN')     Or (S = 'CONJ')    Or (S = 'ENTIER')   Or
    (S = 'IM')      Or (S = 'LENG')    Or (S = 'LEVEL')    Or
    (S = 'ODD')     Or (S = 'RE')      Or (S = 'REPR')     Or
    (S = 'ROUND')   Or (S = 'SHORTEN') Or (S = 'SIGN')     Or
    (S = 'ELEM')    Or (S = 'SHL')     Or (S = 'SHR')      Or
    (S = 'UP')      Or (S = 'DOWN')    Or (S = 'LWB')      Or
    (S = 'UPB')     Or (S = 'MOD')     Or (S = 'OVER')     Or
    { Parallele }
    (S = 'PAR')     Or
    { Commentaires et pragmats (traites au scan, mais reconnus) }
    (S = 'CO')      Or (S = 'COMMENT') Or
    (S = 'PR')      Or (S = 'PRAGMAT');
End;

{ ---- Fonctions auxiliaires de caracteres ------------------- }

Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or
                  (Ch = '_');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsIdentStart(Ch) Or
                 ((Ch >= '0') And (Ch <= '9'));
End;

Function IsHexDigit(Ch : Char) : Boolean;
Begin
  IsHexDigit := ((Ch >= '0') And (Ch <= '9')) Or
                ((Ch >= 'A') And (Ch <= 'F')) Or
                ((Ch >= 'a') And (Ch <= 'f'));
End;

Function HexVal(Ch : Char) : Integer;
Begin
  If (Ch >= '0') And (Ch <= '9') Then
    HexVal := Ord(Ch) - Ord('0')
  Else If (Ch >= 'A') And (Ch <= 'F') Then
    HexVal := Ord(Ch) - Ord('A') + 10
  Else
    HexVal := Ord(Ch) - Ord('a') + 10;
End;

{ ---- LexNextLine : lire la prochaine ligne source ---------- }

Procedure LexNextLine;
Begin
  If LexEOF Then Exit;
  If EOF(LexSrcF) Then
  Begin
    LexEOF  := True;
    LexLine := '';
    LexColNo := 1;
  End
  Else
  Begin
    ReadLn(LexSrcF, LexLine);
    Inc(LexLineNo);
    Inc(TotalLines);
    LexColNo := 1;
  End;
End;

{ ---- PrintToken : affichage debug d un token --------------- }

Procedure PrintToken(Const T : TToken);
Var
  KS : TString;
Begin
  If Not Opts.DebugMode Then Exit;
  Case T.Kind Of
    TK_EOF        : KS := 'EOF';
    TK_INT_DEN    : KS := 'INT_DEN';
    TK_REAL_DEN   : KS := 'REAL_DEN';
    TK_BOOL_DEN   : KS := 'BOOL_DEN';
    TK_CHAR_DEN   : KS := 'CHAR_DEN';
    TK_STRING_DEN : KS := 'STRING_DEN';
    TK_IDENT      : KS := 'IDENT';
    TK_BOLD       : KS := 'BOLD';
    TK_OP         : KS := 'OP';
    TK_SEMI       : KS := 'SEMI';
    TK_COMMA      : KS := 'COMMA';
    TK_OPEN       : KS := 'OPEN';
    TK_CLOSE      : KS := 'CLOSE';
    TK_BUS        : KS := 'BUS';
    TK_SUB        : KS := 'SUB';
    TK_BUS2       : KS := 'BUS2';
    TK_COLON      : KS := 'COLON';
  Else
    KS := '???';
  End;
  Write('  [', T.Line, ':', T.Col, '] ', KS);
  If T.Val <> '' Then
    Write(' "', T.Val, '"');
  If (T.Kind = TK_INT_DEN) Or (T.Kind = TK_REAL_DEN) Or
     (T.Kind = TK_BOOL_DEN) Then
    Write(' =', T.IntVal);
  WriteLn;
End;

{ ---- LexSkipComment : sauter un commentaire CO...CO
       ou COMMENT...COMMENT (le mot ouvrant est deja consomme,
       on cherche le mot fermant Closer en tant que mot entier
       pour eviter les faux positifs dans le texte). ---------- }

Procedure LexSkipComment(Const Closer : TString);
Var
  W    : TString;
  WU   : TString;
  Ch   : Char;
Begin
  While Not LexEOF Do
  Begin
    { Avancer a la prochaine ligne si necessaire }
    If LexColNo > Length(LexLine) Then
    Begin
      LexNextLine;
      Continue;
    End;
    Ch := LexLine[LexColNo];
    { Scanner un mot et verifier si c est le fermant }
    If IsIdentStart(Ch) Then
    Begin
      W := '';
      While (LexColNo <= Length(LexLine)) And
            IsIdentCont(LexLine[LexColNo]) Do
      Begin
        If Length(W) < MAX_STR Then
          W := W + LexLine[LexColNo];
        Inc(LexColNo);
      End;
      WU := StrUpperCase(W);
      If WU = Closer Then
        Exit; { commentaire ferme }
    End
    Else
      Inc(LexColNo);
  End;
  LexError('commentaire non ferme, attendu: ' + Closer);
End;

{ ---- LexSkipHashComment : sauter un commentaire # ... # --- }

Procedure LexSkipHashComment;
Begin
  Inc(LexColNo); { sauter le # ouvrant }
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      LexNextLine;
      Continue;
    End;
    If LexLine[LexColNo] = '#' Then
    Begin
      Inc(LexColNo);
      Exit;
    End;
    Inc(LexColNo);
  End;
  LexError('commentaire # non ferme');
End;

{ ---- LexSkipPragmat : sauter un pragmat PR...PR
       ou PRAGMAT...PRAGMAT (meme logique que commentaire) ---- }

Procedure LexSkipPragmat(Const Closer : TString);
Begin
  LexSkipComment(Closer);
End;

{ ---- LexScanIdent : scanner un identificateur ou mot gras.
       En Algol 68, les mots gras sont ecrits en MAJUSCULES
       (convention bold stropping). Si le mot est CO/COMMENT,
       on saute le commentaire. Si PR/PRAGMAT, on saute le pragmat. }

Procedure LexScanIdent;
Var
  S  : TString;
  SU : TString;
  SL : Integer;
  SC : Integer;
Begin
  SL := LexLineNo;
  SC := LexColNo;
  S  := '';
  While (LexColNo <= Length(LexLine)) And
        IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  SU := StrUpperCase(S);

  { Commentaires CO...CO et COMMENT...COMMENT }
  If SU = 'CO' Then
  Begin
    LexSkipComment('CO');
    LexNextToken; { relancer le scan pour le prochain vrai token }
    Exit;
  End;
  If SU = 'COMMENT' Then
  Begin
    LexSkipComment('COMMENT');
    LexNextToken;
    Exit;
  End;

  { Pragmats PR...PR et PRAGMAT...PRAGMAT }
  If SU = 'PR' Then
  Begin
    LexSkipPragmat('PR');
    LexNextToken;
    Exit;
  End;
  If SU = 'PRAGMAT' Then
  Begin
    LexSkipPragmat('PRAGMAT');
    LexNextToken;
    Exit;
  End;

  CurToken.Line := SL;
  CurToken.Col  := SC;

  { Verifier si c est un mot gras (bold word) }
  If IsBoldWord(SU) Then
  Begin
    CurToken.Kind   := TK_BOLD;
    CurToken.Val    := SU;
    CurToken.IntVal := 0;
    { Cas speciaux pour TRUE / FALSE -> TK_BOOL_DEN }
    If SU = 'TRUE' Then
    Begin
      CurToken.Kind   := TK_BOOL_DEN;
      CurToken.IntVal := 1;
    End
    Else If SU = 'FALSE' Then
    Begin
      CurToken.Kind   := TK_BOOL_DEN;
      CurToken.IntVal := 0;
    End;
  End
  Else
  Begin
    { Identificateur ordinaire (minuscules ou melange) }
    CurToken.Kind   := TK_IDENT;
    CurToken.Val    := S; { garder la casse originale }
    CurToken.IntVal := 0;
  End;
End;

{ ---- LexScanNumber : scanner une denotation entiere ou reelle.
       Algol 68 supporte les bases : 2r1010, 8r77, 16rFF.
       Flottants : 3.14, 1.5e-3, .5e2 (tronques en entier). }

Procedure LexScanNumber;
Var
  N       : LongInt;
  Base    : Integer;
  IsFloat : Boolean;
  NegExp  : Boolean;
  FracDiv : Real;
  FracVal : Real;
  ExpVal  : Integer;
  FltVal  : Real;
  SL, SC  : Integer;
  RadixN  : LongInt;
Begin
  SL      := LexLineNo;
  SC      := LexColNo;
  N       := 0;
  Base    := 10;
  IsFloat := False;
  NegExp  := False;
  FracVal := 0.0;
  FracDiv := 10.0;
  ExpVal  := 0;

  { Scanner la partie entiere decimale }
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
  Begin
    N := N * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
    Inc(LexColNo);
  End;

  { Verifier si c est une base : Nr... (ex: 16rFF) }
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'r') Or (LexLine[LexColNo] = 'R')) And
     (N >= 2) And (N <= 16) Then
  Begin
    Base := N;
    N := 0;
    Inc(LexColNo); { sauter le 'r' }
    { Scanner les digits dans la base }
    While (LexColNo <= Length(LexLine)) And
          IsHexDigit(LexLine[LexColNo]) Do
    Begin
      RadixN := HexVal(LexLine[LexColNo]);
      If RadixN >= Base Then
      Begin
        LexError('chiffre invalide pour base ' + IntToStr(Base));
        Break;
      End;
      N := N * Base + RadixN;
      Inc(LexColNo);
    End;
    CurToken.Line   := SL;
    CurToken.Col    := SC;
    CurToken.Kind   := TK_INT_DEN;
    CurToken.IntVal := N;
    Str(N, CurToken.Val);
    Exit;
  End;

  { Partie decimale .ddd (seulement en base 10) }
  If (LexColNo <= Length(LexLine)) And
     (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And
     (LexLine[LexColNo + 1] >= '0') And
     (LexLine[LexColNo + 1] <= '9') Then
  Begin
    IsFloat := True;
    Inc(LexColNo); { sauter le '.' }
    FracDiv := 10.0;
    FracVal := 0.0;
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] >= '0') And
          (LexLine[LexColNo] <= '9') Do
    Begin
      FracVal := FracVal +
        (Ord(LexLine[LexColNo]) - Ord('0')) / FracDiv;
      FracDiv := FracDiv * 10.0;
      Inc(LexColNo);
    End;
  End;

  { Exposant e/E [+-]ddd }
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'e') Or (LexLine[LexColNo] = 'E')) Then
  Begin
    IsFloat := True;
    Inc(LexColNo);
    NegExp := False;
    If (LexColNo <= Length(LexLine)) And
       (LexLine[LexColNo] = '-') Then
    Begin
      NegExp := True;
      Inc(LexColNo);
    End
    Else If (LexColNo <= Length(LexLine)) And
            (LexLine[LexColNo] = '+') Then
      Inc(LexColNo);
    ExpVal := 0;
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] >= '0') And
          (LexLine[LexColNo] <= '9') Do
    Begin
      ExpVal := ExpVal * 10 +
        (Ord(LexLine[LexColNo]) - Ord('0'));
      Inc(LexColNo);
    End;
  End;

  { Calculer la valeur finale }
  If IsFloat Then
  Begin
    FltVal := N + FracVal;
    While ExpVal > 0 Do
    Begin
      If NegExp Then FltVal := FltVal / 10.0
      Else           FltVal := FltVal * 10.0;
      Dec(ExpVal);
    End;
    If FltVal > 32767.0 Then N := 32767
    Else If FltVal < -32768.0 Then N := -32768
    Else N := Trunc(FltVal);
    CurToken.Kind := TK_REAL_DEN;
  End
  Else
    CurToken.Kind := TK_INT_DEN;

  CurToken.Line   := SL;
  CurToken.Col    := SC;
  CurToken.IntVal := N;
  Str(N, CurToken.Val);
End;

{ ---- LexScanString : scanner une denotation de chaine
       entre guillemets doubles. En Algol 68, le guillemet
       est echappe par doublement : "" -> un seul ".
       Si la chaine contient un seul caractere, c est une
       denotation de caractere (TK_CHAR_DEN). --------------- }

Procedure LexScanString;
Var
  S    : TString;
  SL   : Integer;
  SC   : Integer;
  Ch   : Char;
Begin
  SL := LexLineNo;
  SC := LexColNo;
  S  := '';
  Inc(LexColNo); { sauter le guillemet ouvrant }

  While (LexColNo <= Length(LexLine)) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '"' Then
    Begin
      { Verifier si c est un doublement "" -> un seul " }
      If (LexColNo < Length(LexLine)) And
         (LexLine[LexColNo + 1] = '"') Then
      Begin
        If Length(S) < MAX_STR Then
          S := S + '"';
        Inc(LexColNo, 2);
      End
      Else
      Begin
        Inc(LexColNo); { sauter le guillemet fermant }
        Break;
      End;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + Ch;
      Inc(LexColNo);
    End;
  End;

  CurToken.Line   := SL;
  CurToken.Col    := SC;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
  { Un seul caractere -> denotation de caractere }
  If Length(S) = 1 Then
  Begin
    CurToken.Kind   := TK_CHAR_DEN;
    CurToken.IntVal := Ord(S[1]);
  End
  Else
    CurToken.Kind := TK_STRING_DEN;
End;

{ ---- LexNextToken : scanner principal du lexeur Algol 68.
       Gere les espaces, commentaires, identifiants/mots gras,
       nombres, chaines, et tous les operateurs/symboles. ----- }

Procedure LexNextToken;
Var
  Ch       : Char;
  SL, SC   : Integer;
  Scanning : Boolean;
Begin
  CurToken.IntVal := 0;
  Scanning := True;

  While Scanning Do
  Begin
    { Avancer au-dela de la fin de ligne }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

    { Fin de fichier }
    If LexEOF Then
    Begin
      CurToken.Kind   := TK_EOF;
      CurToken.Val    := '';
      CurToken.IntVal := 0;
      CurToken.Line   := LexLineNo;
      CurToken.Col    := LexColNo;
      Exit;
    End;

    Ch := LexLine[LexColNo];
    SL := LexLineNo;
    SC := LexColNo;

    { Espaces et tabulations }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Then
    Begin
      Inc(LexColNo);
      Continue;
    End;

    { Commentaire # ... # }
    If Ch = '#' Then
    Begin
      LexSkipHashComment;
      Continue;
    End;

    { Identificateur ou mot gras }
    If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      Scanning := False;
    End

    { Nombre (entier ou reel) }
    Else If (Ch >= '0') And (Ch <= '9') Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    { Nombre commencant par . (ex: .5) }
    Else If (Ch = '.') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] >= '0') And
            (LexLine[LexColNo + 1] <= '9') Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    { Chaine entre guillemets }
    Else If Ch = '"' Then
    Begin
      LexScanString;
      Scanning := False;
    End

    { Point-virgule (go-on symbol) }
    Else If Ch = ';' Then
    Begin
      CurToken.Kind := TK_SEMI;
      CurToken.Val  := ';';
      CurToken.Line := SL;
      CurToken.Col  := SC;
      Inc(LexColNo);
      Scanning := False;
    End

    { Virgule (collateral) }
    Else If Ch = ',' Then
    Begin
      CurToken.Kind := TK_COMMA;
      CurToken.Val  := ',';
      CurToken.Line := SL;
      CurToken.Col  := SC;
      Inc(LexColNo);
      Scanning := False;
    End

    { Parenthese ouvrante }
    Else If Ch = '(' Then
    Begin
      CurToken.Kind := TK_OPEN;
      CurToken.Val  := '(';
      CurToken.Line := SL;
      CurToken.Col  := SC;
      Inc(LexColNo);
      Scanning := False;
    End

    { Parenthese fermante }
    Else If Ch = ')' Then
    Begin
      CurToken.Kind := TK_CLOSE;
      CurToken.Val  := ')';
      CurToken.Line := SL;
      CurToken.Col  := SC;
      Inc(LexColNo);
      Scanning := False;
    End

    { Crochet ouvrant (indice) }
    Else If Ch = '[' Then
    Begin
      CurToken.Kind := TK_SUB;
      CurToken.Val  := '[';
      CurToken.Line := SL;
      CurToken.Col  := SC;
      Inc(LexColNo);
      Scanning := False;
    End

    { Crochet fermant }
    Else If Ch = ']' Then
    Begin
      CurToken.Kind := TK_BUS2;
      CurToken.Val  := ']';
      CurToken.Line := SL;
      CurToken.Col  := SC;
      Inc(LexColNo);
      Scanning := False;
    End

    { Deux-points : ou := }
    Else If Ch = ':' Then
    Begin
      If (LexColNo < Length(LexLine)) And
         (LexLine[LexColNo + 1] = '=') Then
      Begin
        { := (becomes / assignation) }
        CurToken.Kind := TK_OP;
        CurToken.Val  := ':=';
        CurToken.Line := SL;
        CurToken.Col  := SC;
        Inc(LexColNo, 2);
      End
      Else
      Begin
        { : (tranche / label) }
        CurToken.Kind := TK_COLON;
        CurToken.Val  := ':';
        CurToken.Line := SL;
        CurToken.Col  := SC;
        Inc(LexColNo);
      End;
      Scanning := False;
    End

    { = ou =: }
    Else If Ch = '=' Then
    Begin
      If (LexColNo < Length(LexLine)) And
         (LexLine[LexColNo + 1] = ':') Then
      Begin
        { =: (assignation inversee / bus) }
        CurToken.Kind := TK_BUS;
        CurToken.Val  := '=:';
        CurToken.Line := SL;
        CurToken.Col  := SC;
        Inc(LexColNo, 2);
      End
      Else
      Begin
        { = (egalite) }
        CurToken.Kind := TK_OP;
        CurToken.Val  := '=';
        CurToken.Line := SL;
        CurToken.Col  := SC;
        Inc(LexColNo);
      End;
      Scanning := False;
    End

    { + ou +:= ou +* }
    Else If Ch = '+' Then
    Begin
      If (LexColNo < Length(LexLine)) And
         (LexLine[LexColNo + 1] = ':') And
         (LexColNo + 1 < Length(LexLine)) And
         (LexLine[LexColNo + 2] = '=') Then
      Begin
        { +:= (plusab) }
        CurToken.Kind := TK_OP;
        CurToken.Val  := '+:=';
        CurToken.Line := SL;
        CurToken.Col  := SC;
        Inc(LexColNo, 3);
      End
      Else If (LexColNo < Length(LexLine)) And
              (LexLine[LexColNo + 1] = '*') Then
      Begin
        { +* (I pour COMPL) }
        CurToken.Kind := TK_OP;
        CurToken.Val  := '+*';
        CurToken.Line := SL;
        CurToken.Col  := SC;
        Inc(LexColNo, 2);
      End
      Else
      Begin
        { + }
        CurToken.Kind := TK_OP;
        CurToken.Val  := '+';
        CurToken.Line := SL;
        CurToken.Col  := SC;
        Inc(LexColNo);
      End;
      Scanning := False;
    End

    { - ou -:= }
    Else If Ch = '-' Then
    Begin
      If (LexColNo < Length(LexLine)) And
         (LexLine[LexColNo + 1] = ':') And
         (LexColNo + 1 < Length(LexLine)) And
         (LexLine[LexColNo + 2] = '=') Then
      Begin
        { -:= (minusab) }
        CurToken.Kind := TK_OP;
        CurToken.Val  := '-:=';
        CurToken.Line := SL;
        CurToken.Col  := SC;
        Inc(LexColNo, 3);
      End
      Else
      Begin
        { - }
        CurToken.Kind := TK_OP;
        CurToken.Val  := '-';
        CurToken.Line := SL;
        CurToken.Col  := SC;
        Inc(LexColNo);
      End;
      Scanning := False;
    End

    { * ou *:= }
    Else If Ch = '*' Then
    Begin
      If (LexColNo < Length(LexLine)) And
         (LexLine[LexColNo + 1] = ':') And
         (LexColNo + 1 < Length(LexLine)) And
         (LexLine[LexColNo + 2] = '=') Then
      Begin
        { *:= (timesab) }
        CurToken.Kind := TK_OP;
        CurToken.Val  := '*:=';
        CurToken.Line := SL;
        CurToken.Col  := SC;
        Inc(LexColNo, 3);
      End
      Else If (LexColNo < Length(LexLine)) And
              (LexLine[LexColNo + 1] = '*') Then
      Begin
        { ** (exponentiation) }
        CurToken.Kind := TK_OP;
        CurToken.Val  := '**';
        CurToken.Line := SL;
        CurToken.Col  := SC;
        Inc(LexColNo, 2);
      End
      Else
      Begin
        { * }
        CurToken.Kind := TK_OP;
        CurToken.Val  := '*';
        CurToken.Line := SL;
        CurToken.Col  := SC;
        Inc(LexColNo);
      End;
      Scanning := False;
    End

    { / ou /:= ou /= }
    Else If Ch = '/' Then
    Begin
      If (LexColNo < Length(LexLine)) And
         (LexLine[LexColNo + 1] = ':') And
         (LexColNo + 1 < Length(LexLine)) And
         (LexLine[LexColNo + 2] = '=') Then
      Begin
        { /:= (divab) }
        CurToken.Kind := TK_OP;
        CurToken.Val  := '/:=';
        CurToken.Line := SL;
        CurToken.Col  := SC;
        Inc(LexColNo, 3);
      End
      Else If (LexColNo < Length(LexLine)) And
              (LexLine[LexColNo + 1] = '=') Then
      Begin
        { /= (non egal) }
        CurToken.Kind := TK_OP;
        CurToken.Val  := '/=';
        CurToken.Line := SL;
        CurToken.Col  := SC;
        Inc(LexColNo, 2);
      End
      Else
      Begin
        { / (division) }
        CurToken.Kind := TK_OP;
        CurToken.Val  := '/';
        CurToken.Line := SL;
        CurToken.Col  := SC;
        Inc(LexColNo);
      End;
      Scanning := False;
    End

    { < ou <= }
    Else If Ch = '<' Then
    Begin
      If (LexColNo < Length(LexLine)) And
         (LexLine[LexColNo + 1] = '=') Then
      Begin
        CurToken.Kind := TK_OP;
        CurToken.Val  := '<=';
        CurToken.Line := SL;
        CurToken.Col  := SC;
        Inc(LexColNo, 2);
      End
      Else
      Begin
        CurToken.Kind := TK_OP;
        CurToken.Val  := '<';
        CurToken.Line := SL;
        CurToken.Col  := SC;
        Inc(LexColNo);
      End;
      Scanning := False;
    End

    { > ou >= }
    Else If Ch = '>' Then
    Begin
      If (LexColNo < Length(LexLine)) And
         (LexLine[LexColNo + 1] = '=') Then
      Begin
        CurToken.Kind := TK_OP;
        CurToken.Val  := '>=';
        CurToken.Line := SL;
        CurToken.Col  := SC;
        Inc(LexColNo, 2);
      End
      Else
      Begin
        CurToken.Kind := TK_OP;
        CurToken.Val  := '>';
        CurToken.Line := SL;
        CurToken.Col  := SC;
        Inc(LexColNo);
      End;
      Scanning := False;
    End

    { ^ (exponentiation alternative) }
    Else If Ch = '^' Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '^';
      CurToken.Line := SL;
      CurToken.Col  := SC;
      Inc(LexColNo);
      Scanning := False;
    End

    { ~ (tilde, alias pour NOT dans certains contextes) }
    Else If Ch = '~' Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '~';
      CurToken.Line := SL;
      CurToken.Col  := SC;
      Inc(LexColNo);
      Scanning := False;
    End

    { | (barre verticale, separateur CASE abrege) }
    Else If Ch = '|' Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '|';
      CurToken.Line := SL;
      CurToken.Col  := SC;
      Inc(LexColNo);
      Scanning := False;
    End

    { @ (AT, reindexation de tranche) }
    Else If Ch = '@' Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '@';
      CurToken.Line := SL;
      CurToken.Col  := SC;
      Inc(LexColNo);
      Scanning := False;
    End

    { Caractere inconnu }
    Else
    Begin
      LexError('caractere inconnu: ' + Ch);
      Inc(LexColNo);
    End;
  End; { While Scanning }
End;

{ ---- LexInit : ouvrir le fichier source et initialiser ----- }

Procedure LexInit;
Begin
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir: ' + Opts.SrcFile);
  LexOpened  := True;
  LexLineNo  := 0;
  LexColNo   := 1;
  LexEOF     := False;
  LexLine    := '';
  { Lire la premiere ligne }
  LexNextLine;
End;

{ ---- LexClose : fermer le fichier source -------------------- }

Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ============================================================
  TODO 03 - DENOTATIONS (LITTERAUX) [IMPLEMENTE]
  ============================================================ }

{ ---- ExprMakeImm : construire une valeur immediate ---------- }

Procedure ExprMakeImm(AVal : LongInt; AModeIdx : Integer;
                      Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.ModeIdx := AModeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprMakeNone : valeur invalide (void/erreur) ----------- }

Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.ModeIdx := TY_IDX_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprMakeBool : valeur booleenne (0 ou 1) --------------- }

Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  If AVal <> 0 Then Res.ImmVal := 1 Else Res.ImmVal := 0;
  Res.ModeIdx := TY_IDX_BOOL;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprMakeVoid : valeur VOID (SKIP / EMPTY) -------------- }

Procedure ExprMakeVoid(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.ModeIdx := TY_IDX_VOID;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprMakeNil : reference nulle (NIL) -> AX=0 ------------ }

Procedure ExprMakeNil(Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := 0;
  Res.ModeIdx := TY_IDX_REF;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- LitEvalInt : denotation entiere -> valeur immediate ----- }
{ IntVal est deja calcule par LexScanNumber (base 10 ou Nr).    }

Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_INT, Res);
End;

{ ---- LitEvalFloat : denotation reelle -> entier tronque ------ }
{ 8086 n a pas de FPU ; les REAL sont tronques en INT.          }

Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_REAL, Res);
  WarnMsg('denotation reelle tronquee a ' + IntToStr(T.IntVal) +
          ' (pas de FPU sur 8086)');
End;

{ ---- DataAdd : ajouter une entree dans le segment DATA ------- }
{ Retourne l index dans DataTab ou -1 si plein.                  }

Function DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    CompileError('segment DATA plein (max=' + IntToStr(MAX_DATA) + ')');
    DataAdd := -1;
    Exit;
  End;
  DataTab[DataCount].LblName   := Lbl;
  DataTab[DataCount].Kind      := Kind;
  DataTab[DataCount].IntVal    := AIntVal;
  DataTab[DataCount].StrVal    := AStrVal;
  DataTab[DataCount].ElemCount := 0;
  DataAdd := DataCount;
  Inc(DataCount);
End;

{ ---- DataAddStr : creer un label _A68K_N et stocker la chaine }
{ Reutilise les doublons (meme contenu -> meme label).          }
{ Retourne le label genere.                                      }

Function DataAddStr(Const S : TString) : TString;
Var
  I   : Integer;
  Lbl : TString;
Begin
  { Recherche de doublon }
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_STR) And (DataTab[I].StrVal = S) Then
    Begin
      DataAddStr := DataTab[I].LblName;
      Exit;
    End;
  Inc(LabelGenSeq);
  Lbl := A68_STR_PFX + IntToStr(LabelGenSeq);
  DataAdd(Lbl, DK_STR, 0, S);
  DataAddStr := Lbl;
End;

{ ---- DataAddWord : ajouter un mot 16 bits dans le segment DATA }

Function DataAddWord(Const Lbl : TString;
                     AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

{ ---- EmitDataSeg : ecrire _DATA SEGMENT complet -------------- }
{ Emet les chaines predefinies et toutes les entrees DataTab.    }

Procedure EmitDataSeg;
Var
  I, J : Integer;
  NS   : TString;
  B    : Byte;
Begin
  If Not OutFOpen Then Exit;
  WriteLn(OutF);
  WriteLn(OutF, '_DATA   SEGMENT WORD PUBLIC ''DATA''');
  WriteLn(OutF, '        ASSUME  DS:_DATA');
  { Chaines predefinies pour print(TRUE/FALSE) }
  WriteLn(OutF, '_A68_TRUE_S:');
  WriteLn(OutF, '        DB      ''TRUE'',0');
  WriteLn(OutF, '_A68_FALSE_S:');
  WriteLn(OutF, '        DB      ''FALSE'',0');
  WriteLn(OutF, '_A68_NIL_S:');
  WriteLn(OutF, '        DB      ''NIL'',0');
  WriteLn(OutF, '_A68_CRLF:');
  WriteLn(OutF, '        DB      13,10,0');
  WriteLn(OutF, '_A68_STRBUF:');
  WriteLn(OutF, '        DB      128 DUP(0)');
  { Entrees DataTab }
  For I := 0 To DataCount - 1 Do
  Begin
    WriteLn(OutF, DataTab[I].LblName, ':');
    Case DataTab[I].Kind Of
      DK_WORD :
      Begin
        Str(DataTab[I].IntVal, NS);
        WriteLn(OutF, '        DW      ', NS);
      End;
      DK_BYTE :
      Begin
        Str(DataTab[I].IntVal And $FF, NS);
        WriteLn(OutF, '        DB      ', NS);
      End;
      DK_STR :
      Begin
        Write(OutF, '        DB      ');
        For J := 1 To Length(DataTab[I].StrVal) Do
        Begin
          B := Ord(DataTab[I].StrVal[J]);
          Str(B, NS);
          If J > 1 Then Write(OutF, ',');
          Write(OutF, NS);
        End;
        WriteLn(OutF, ',0');
      End;
      DK_ARRAY_BLK :
      Begin
        { Descripteur de tableau : lwb, upb, elem_size, offset_data }
        WriteLn(OutF, '        DW      0,0,0,0  ; stub array descriptor');
      End;
      DK_STRUCT_BLK :
      Begin
        { Bloc de structure : stub }
        WriteLn(OutF, '        DW      0  ; stub struct block');
      End;
    End;
  End;
  WriteLn(OutF, '_DATA   ENDS');
End;

{ ---- LitEval : dispatcher principal pour les denotations ----- }
{ Types de tokens Algol 68 acceptes :                             }
{   TK_INT_DEN    -> EK_IMM, ModeIdx = TY_IDX_INT                }
{   TK_REAL_DEN   -> EK_IMM, ModeIdx = TY_IDX_REAL (tronque)     }
{   TK_BOOL_DEN   -> EK_IMM, ModeIdx = TY_IDX_BOOL (0 ou 1)     }
{   TK_CHAR_DEN   -> EK_IMM, ModeIdx = TY_IDX_CHAR (Ord)         }
{   TK_STRING_DEN -> EK_MEM, ModeIdx = TY_IDX_STRING (DataAddStr) }
{   TK_BOLD SKIP/EMPTY -> EK_NONE, ModeIdx = TY_IDX_VOID         }
{   TK_BOLD NIL        -> EK_IMM(0), ModeIdx = TY_IDX_REF        }

Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Var
  I          : Integer;
  LitStrLbl  : TString;
  LitStrIdx  : Integer;
Begin
  ExprMakeNone(Res); { valeur par defaut }
  Case T.Kind Of
    TK_INT_DEN :
      LitEvalInt(T, Res);
    TK_REAL_DEN :
      LitEvalFloat(T, Res);
    TK_BOOL_DEN :
      ExprMakeBool(T.IntVal, Res);
    TK_CHAR_DEN :
      ExprMakeImm(T.IntVal, TY_IDX_CHAR, Res);
    TK_STRING_DEN :
    Begin
      { Stocker la chaine dans DataTab (avec dedup) }
      LitStrLbl := DataAddStr(T.Val);
      { Trouver l index dans DataTab par le label }
      LitStrIdx := -1;
      For I := 0 To DataCount - 1 Do
        If DataTab[I].LblName = LitStrLbl Then
        Begin
          LitStrIdx := I;
          Break;
        End;
      Res.Kind    := EK_MEM;
      Res.ImmVal  := 0;
      Res.ModeIdx := TY_IDX_STRING;
      Res.Offset  := LitStrIdx;
      Res.SymIdx  := -1;
    End;
    TK_BOLD :
    Begin
      If (T.Val = 'SKIP') Or (T.Val = 'EMPTY') Then
        ExprMakeVoid(Res)
      Else If T.Val = 'NIL' Then
        ExprMakeNil(Res)
      Else
        ExprMakeNone(Res);
    End;
  Else
    ExprMakeNone(Res);
  End;
End;

Function BinOpPrec(Const Op : TString) : Integer;
Begin
  { TODO 04 }
  BinOpPrec := 0;
End;

Procedure ParseFormula(MinPrio : Integer; Var Res : TExprVal);
Begin
  { TODO 04 }
  Res := GExprDummy;
End;

Function SymFind(Const Name : TString) : Integer;
Begin
  { TODO 05 }
  SymFind := -1;
End;

Function SymAdd(Const Name : TString; Cat : TSymCat;
                ModeIdx, Offset : Integer) : Integer;
Begin
  { TODO 05 }
  SymAdd := -1;
End;

Procedure SymEnterScope;
Begin
  { TODO 05 }
End;

Procedure SymLeaveScope;
Begin
  { TODO 05 }
End;

Function SymNextOffset : Integer;
Begin
  { TODO 05 }
  SymNextOffset := 0;
End;

Procedure SymInit;
Begin
  { TODO 05 }
End;

Procedure ModeInit;
Begin
  { TODO 06 }
End;

Function ModeSizeof(ModeIdx : Integer) : Integer;
Begin
  { TODO 06 }
  ModeSizeof := 2;
End;

Procedure ApplyCoercion(SrcMode, DstMode : Integer);
Begin
  { TODO 07 }
End;

Function LabelGen : TString;
Begin
  { TODO 08 }
  Inc(LabelGenSeq);
  LabelGen := A68_LBL_PFX + IntToStr(LabelGenSeq);
End;

Procedure EmitRaw(Const S : TString);
Begin
  { TODO 08 }
End;

Procedure EmitLabel(Const Lbl : TString);
Begin
  { TODO 08 }
End;

Procedure EmitInstr(Const Mnem : TString);
Begin
  { TODO 08 }
End;

Procedure EmitOpen;
Begin
  { TODO 08 }
End;

Procedure EmitClose;
Begin
  { TODO 08 }
End;

Procedure EmitHeader;
Begin
  { TODO 08 }
End;

Procedure EmitProlog;
Begin
  { TODO 08 }
End;

Procedure EmitEpilog;
Begin
  { TODO 08 }
End;

{ DataAdd, DataAddStr, EmitDataSeg : implementes dans TODO 03 ci-dessus }

Procedure EmitRuntime;
Begin
  { TODO 24 }
End;

Procedure ParseDeclStmt;
Begin
  { TODO 10 }
End;

Procedure ParsePrimary(Var Res : TExprVal);
Begin
  { TODO 11 }
  Res := GExprDummy;
End;

Procedure ParseExpr(Var Res : TExprVal);
Begin
  { TODO 11 }
  Res := GExprDummy;
End;

Procedure ExprFlushToAX(Const E : TExprVal);
Begin
  { TODO 12 }
End;

Procedure ParseSerialClause(Var Res : TExprVal);
Begin
  { TODO 13 }
  Res := GExprDummy;
End;

Procedure ParseIfClause(Var Res : TExprVal);
Begin
  { TODO 14 }
  Res := GExprDummy;
End;

Procedure ParseCaseClause(Var Res : TExprVal);
Begin
  { TODO 14 }
  Res := GExprDummy;
End;

Procedure ParseLoopClause;
Begin
  { TODO 15 }
End;

Procedure ParseStructDecl;
Begin
  { TODO 16 }
End;

Procedure ParseAssignment;
Begin
  { TODO 17 }
End;

Procedure ParseRowDecl;
Begin
  { TODO 18 }
End;

Procedure ParseProcDecl;
Begin
  { TODO 19 }
End;

Procedure ParseOpDecl;
Begin
  { TODO 20 }
End;

Procedure ParsePrioDecl;
Begin
  { TODO 20 }
End;

Procedure ParseUnionDecl;
Begin
  { TODO 21 }
End;

Procedure ParseConformityClause(Var Res : TExprVal);
Begin
  { TODO 21 }
  Res := GExprDummy;
End;

Procedure ParsePrint;
Begin
  { TODO 22 }
End;

Procedure ParseRead;
Begin
  { TODO 22 }
End;

Procedure ParseCollateral(Var Res : TExprVal);
Begin
  { TODO 23 }
  Res := GExprDummy;
End;

Procedure ParseStmt;
Begin
  { TODO 25 - stub : consommer un token pour eviter boucle infinie }
  If CurToken.Kind <> TK_EOF Then
    ParserAdvance;
End;

Procedure ParserAdvance;
Begin
  LexNextToken;
  If Opts.DebugMode Then
    PrintToken(CurToken);
End;

{ ============================================================
  TODO 25 - PROCEDURE RUN (STUB)
  ============================================================ }

Procedure Run;
Begin
  GlobalInit;
  If Opts.Verbose Then ShowBanner;

  ModeInit;
  SymInit;
  EmitOpen;
  EmitHeader;
  LexInit;

  ParserAdvance;

  While CurToken.Kind <> TK_EOF Do
    ParseStmt;

  LexClose;
  EmitRuntime;
  EmitClose;

  If Opts.Verbose Then ShowStats;

  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
  ParseArgs;
  Run;
End.
