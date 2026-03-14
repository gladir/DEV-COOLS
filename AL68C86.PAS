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

  TODO 04 - OPERATEURS ET PRIORITES [IMPLEMENTE]
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
            IsAssignOp, BinOpPrec, BinOpIsRight, ExprFlushToAX
            ParsePrimary, ParseUnary, ParseFormula(MinPrio), ParseExpr

  TODO 05 - TABLE DES SYMBOLES ET PORTEES [IMPLEMENTE]
            TSymKind : SK_IDENT (identite), SK_VAR (variable REF),
              SK_PROC (procedure), SK_OP (operateur), SK_MODE (type),
              SK_LABEL (etiquette), SK_PRIO (priorite d operateur)
            TSymRec : Name, MangledName, Kind, ModeIdx, Offset,
              ScopeLevel, IsParam, IsHeap, IsLoc
            SymNameClean, SymMangle, SymAdd, SymFind, SymFindInScope
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            SymEnterScope / SymLeaveScope : gestion des portees
            SymNextOffset : prochain offset [BP-n] pour locale
            SymInit : predeclare 61 symboles standard Algol 68
              I/O (print/read/newline/newpage/space/backspace)
              Transput (put/get/open/close/associate/create/establish)
              Operateurs (abs/odd/sign/entier/round/repr/leng/shorten/
                bin/elem/level/re/im/conj/arg)
              Math (sqrt/exp/ln/sin/cos/tan/arcsin/arccos/arctan)
              Chaines (whole/fixed/float/char in string/string in string)
              Constantes (max int/max real/small real/pi/blank/flip/flop)
              Fichiers (stand in/stand out/stand error/stand back)
              Divers (random/next random/stop)

  TODO 06 - SYSTEME DE MODES (TYPES) [IMPLEMENTE]
            TModeKind : MK_INT (16 bits signe), MK_REAL (stub entier),
              MK_BOOL (8 bits), MK_CHAR (8 bits), MK_BITS (16 bits),
              MK_BYTES (tableau octets), MK_COMPL (paire d entiers),
              MK_STRING (ptr chaine dynamique), MK_VOID,
              MK_STRUCT (structure), MK_UNION (mode uni),
              MK_REF (reference), MK_PROC (procedure),
              MK_ARRAY (tableau flexible), MK_ROW (rangee)
            ModeTab, ModeInit : 10 modes primitifs (INT/REAL/BOOL/CHAR/
              BITS/STRING/VOID/REF/COMPL/BYTES)
            ModeSizeof : INT=2, REAL=2, BOOL=1, CHAR=1, BITS=2,
              COMPL=4, REF=2, STRING=2(ptr), VOID=0, BYTES=2(ptr)
            ModeKindOf, ModeMangle (_A68N_/_A68B_/_A68C_/_A68S_/
              _A68U_/_A68R_/_A68T_/_A68W_/_A68X_)
            ModeIsNumeric (INT/REAL/BITS/COMPL/BOOL/CHAR)
            ModeIsPtr (STRING/ROW/REF/PROC/STRUCT/UNION/BYTES)
            ModeCanCoerce : meme->OK, UNKNOWN->OK, INT->REAL(widen),
              CHAR->INT, BOOL->INT, INT<->BITS(BIN), REF->elem(deref),
              CHAR->STRING(row), INT/REAL->COMPL, tout->VOID
            ModeCoerceResult : cmp/logic->BOOL, SHL/SHR->BITS/INT,
              +*I->COMPL, **->base, :=->cible, COMPL>REAL>INT promo
            ModeInfer (IMM->INT, else ModeIdx/UNKNOWN)
            ModeLookupName (case-insensitive)

  TODO 07 - COERCITIONS (COERCIONS) [IMPLEMENTE]
            Les 6 coercitions Algol 68, appliquees automatiquement :
            Dereferencement (dereferencing) : REF M -> M
              MOV BX,AX / MOV AX,[BX] (suivre le pointeur)
            Deproceduration (deproceduring) : PROC M -> M
              CALL AX -> resultat dans AX
            Elargissement (widening) : INT -> REAL (NOP stub),
              CHAR->INT (XOR AH,AH), BOOL->INT (AND AX,1),
              INT/REAL->COMPL (PUSH AX/PUSH 0), INT<->BITS (NOP),
              INT->CHAR (AND AX,0FFh)
            Mise en rangee (rowing) : M -> ROW M
              PUSH AX / MOV AX,SP (singleton array sur pile)
            Unification (uniting) : M -> UNION(M, ...)
              PUSH AX / PUSH disc / MOV AX,SP (discriminant+valeur)
            Vidage (voiding) : M -> VOID
              Ignorer le resultat (NOP, valeur AX non utilisee)
            CoerceChain : chaine dans l ordre canonique
              deref -> deproc -> widen -> row -> unite -> void
            ApplyCoercion : point d entree avec verification

  TODO 08 - EMETTEUR DE CODE ASM [IMPLEMENTE]
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitInstrA (un operande), EmitInstrAB (deux operandes)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _A68L_NNNNN)
            Prefixes : _A68V_ (variable), _A68P_ (procedure),
              _A68K_ (chaine const), _A68RT_ (runtime), _A68L_ (label),
              _A68M_ (mode/type info), _A68O_ (operateur utilisateur)
            EmitOpen : Assign/Rewrite avec {$I-}/{$I+} IOResult
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
              WORD PUBLIC CODE / ASSUME CS:_TEXT,DS:_DATA,SS:NOTHING
              _A68P_main: point d entree + init DS (MOV AX,_DATA/MOV DS,AX)
            EmitProlog / EmitEpilog : PUSH BP / MOV BP,SP et MOV SP,BP / POP BP
            EmitDataSeg : _DATA SEGMENT avec constantes predefinies
              (_A68_TRUE_S/_A68_FALSE_S/_A68_NIL_S/_A68_CRLF/_A68_STRBUF)
              et entrees DataTab (DK_WORD/DK_BYTE/DK_STR avec gestion
              caracteres de controle par valeurs numeriques et doublement
              apostrophes, DK_ARRAY_BLK/DK_STRUCT_BLK)
            EmitRuntime : stub pour TODO 24
            EmitClose : DOS exit MOV AX,4C00h/INT 21h + runtime +
              _TEXT ENDS + data + END _A68P_main

  TODO 09 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_ARRAY/DK_STRUCT),
              IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddStruct : variantes d ajout
            DataAddByte : un octet (CHAR, BOOL) dans le segment DATA
            DataAddArrayDesc : descripteur de tableau [lwb:upb]
              DW lwb, DW upb, DW taille_elem, DW offset_data
            DataAddUnionDesc : descripteur d union (UNION)
              DW discriminant, taille_max * DB 0
            DataAddGlobalVar : variable globale _A68V_nom (DW 0)
            DataFindStr : retrouver un label de chaine existante
            Variables globales : entrees DK_WORD dans DATA avec label _A68V_nom
            Constantes : entrees DK_WORD ou DK_STR (immuables)
            Chaines litterales : DB 'abc',0 dans DATA avec label _A68K_N
            Descripteurs de tableaux : DW lwb, upb, taille_elem, offset_data
            Descripteurs de modes UNION : DW discriminant + donnees
            Pool de chaines : _A68_STRPOOL DB STRPOOL_SIZE DUP(0)
              + _A68_STRPOOL_TOP DW 0 (prochain octet libre)

  TODO 10 - DECLARATIONS D IDENTITE ET DE VARIABLE [IMPLEMENTE]
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

  TODO 11 - EXPRESSIONS PRIMAIRES (UNITES PRIMAIRES) [IMPLEMENTE]
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

  TODO 12 - EXPRESSIONS BINAIRES ET FORMULES [IMPLEMENTE]
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

  TODO 13 - CLAUSES FERMEES ET CLAUSES SERIE [IMPLEMENTE]
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

  TODO 14 - CLAUSES CONDITIONNELLES (IF ET CASE) [IMPLEMENTE]
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

  TODO 15 - CLAUSES REPETITIVES (BOUCLES) [IMPLEMENTE]
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

  TODO 16 - STRUCTURES (STRUCT) [IMPLEMENTE]
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

  TODO 17 - REFERENCES ET AFFECTATIONS [IMPLEMENTE]
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

  TODO 18 - TABLEAUX ET TRANCHES (ROWS) [IMPLEMENTE]
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

  TODO 19 - PROCEDURES (PROC) [IMPLEMENTE]
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
  MAX_STRUCT_FIELDS = {$IFDEF FPC}128{$ELSE}32{$ENDIF};
  STACK_SIZE    = 1024;
  STRPOOL_SIZE  = 1024;  { taille du pool de chaines dynamiques }

  { Prefixes de nommage ASM }
  A68_VAR_PFX  = '_A68V_';    { variable (identite REF)             }
  A68_PROC_PFX = '_A68P_';    { procedure                           }
  A68_STR_PFX  = '_A68K_';    { constante chaine litterale          }
  A68_RT_PFX   = '_A68RT_';   { routine runtime                     }
  A68_LBL_PFX  = '_A68L_';    { label de saut interne               }
  A68_MODE_PFX = '_A68M_';    { info de mode (type)                 }
  A68_OP_PFX   = '_A68O_';    { operateur utilisateur               }
  A68_ARR_PFX  = '_A68A_';    { descripteur de tableau               }
  A68_UNI_PFX  = '_A68U_';    { descripteur d union                  }
  A68_STR_PFX2 = '_A68S_';    { structure (prefix pour struct data)   }

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
    ElemIdx : Integer;   { REF/ROW/PROC : mode element ;
                           STRUCT : index debut StructFieldTab }
    FieldCnt: Integer;   { nombre de champs (MK_STRUCT seulement) }
  End;

  { ---- Champs de structure (TODO 16) ----------------------- }
  TStructField = Record
    Name    : TString;   { nom du champ                       }
    ModeIdx : Integer;   { indice mode dans ModeTab           }
    Offset  : Integer;   { offset en octets depuis le debut   }
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
  PushedToken   : TToken;    { token remis par pushback (TODO 13) }
  HasPushedToken: Boolean;   { vrai si PushedToken est valide     }

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
  IfCount      : Integer;    { compteur pour labels IF abreges      }
  CaseCount    : Integer;    { compteur pour labels CASE abreges    }
  LoopCount    : Integer;    { compteur pour labels LOOP             }

  { Segment de donnees (TODO 09) }
  DataTab   : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount : Integer;

  { Table des operateurs (TODO 20) }
  OpTab     : Array[0..MAX_OP - 1] Of TOpRec;
  OpCount   : Integer;

  { Table des champs de structure (TODO 16) }
  StructFieldTab   : Array[0..MAX_STRUCT_FIELDS - 1] Of TStructField;
  StructFieldCount : Integer;
  StructCount      : Integer;   { nombre de modes STRUCT declares }
  RowCount         : Integer;   { nombre de modes ROW declares }
  ProcCount        : Integer;   { nombre de PROC declarees (TODO 19) }

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
Function  IsAssignOp(Const Op : TString) : Boolean; Forward;
Function  BinOpPrec(Const Op : TString) : Integer; Forward;
Function  BinOpIsRight(Const Op : TString) : Boolean; Forward;
Procedure ExprFlushToAX(Const E : TExprVal); Forward;
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Procedure ParseUnary(Var Res : TExprVal); Forward;
Procedure ParseFormula(MinPrio : Integer; Var Res : TExprVal); Forward;
Procedure ParseExpr(Var Res : TExprVal); Forward;

{ TODO 05 - Symboles }
Function  SymNameClean(Const Name : TString) : TString; Forward;
Function  SymMangle(Const Name : TString; Cat : TSymCat) : TString; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindInScope(Const Name : TString;
                         Level : Integer) : Integer; Forward;
Function  SymAdd(Const Name : TString; Cat : TSymCat;
                 ModeIdx, Offset : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
Function  SymNextOffset : Integer; Forward;
Procedure SymInit;       Forward;

{ TODO 06 - Modes }
Procedure ModeInit;      Forward;
Function  ModeSizeof(ModeIdx : Integer) : Integer; Forward;
Function  ModeKindOf(ModeIdx : Integer) : TModeKind; Forward;
Function  ModeMangle(ModeIdx : Integer) : TString; Forward;
Function  ModeIsNumeric(ModeIdx : Integer) : Boolean; Forward;
Function  ModeIsPtr(ModeIdx : Integer) : Boolean; Forward;
Function  ModeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean; Forward;
Function  ModeCoerceResult(LeftIdx, RightIdx : Integer;
                           Const Op : TString) : Integer; Forward;
Function  ModeInfer(Const E : TExprVal) : Integer; Forward;
Function  ModeLookupName(Const Name : TString) : Integer; Forward;
Function  ModeAddRow(ElemModeIdx : Integer) : Integer; Forward;

{ TODO 07 - Coercitions }
Procedure CoerceDeref(SrcMode : Integer); Forward;
Procedure CoerceDeproc(SrcMode : Integer); Forward;
Procedure CoerceWiden(SrcMode, DstMode : Integer); Forward;
Procedure CoerceRow(SrcMode : Integer); Forward;
Procedure CoerceUnite(SrcMode, DstMode : Integer); Forward;
Procedure CoerceVoid; Forward;
Procedure CoerceChain(SrcMode, DstMode : Integer); Forward;
Procedure ApplyCoercion(SrcMode, DstMode : Integer); Forward;

{ TODO 08 - Emetteur ASM }
Function  LabelGen : TString; Forward;
Procedure EmitRaw(Const S : TString); Forward;
Procedure EmitBlankLine; Forward;
Procedure EmitComment(Const S : TString); Forward;
Procedure EmitLabel(Const Lbl : TString); Forward;
Procedure EmitInstr(Const Mnem : TString); Forward;
Procedure EmitInstrA(Const Mnem, A1 : TString); Forward;
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString); Forward;
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
Function  DataAddByte(Const Lbl : TString;
                      AByteVal : Integer) : Integer; Forward;
Function  DataAddStruct(Const Lbl : TString;
                        ASize : Integer) : Integer; Forward;
Function  DataAddArrayDesc(Const Lbl : TString;
                           ALwb, AUpb, AElemSize : Integer;
                           Const ADataLbl : TString) : Integer; Forward;
Function  DataAddUnionDesc(Const Lbl : TString;
                           ADiscrim, AMaxSize : Integer) : Integer; Forward;
Function  DataAddGlobalVar(Const Name : TString;
                           ModeIdx : Integer) : Integer; Forward;
Function  DataFindStr(Const S : TString) : TString; Forward;

{ TODO 10 - Declarations }
Procedure ParseDeclStmt; Forward;

{ TODO 11 - Expressions primaires }
{ (ParsePrimary, ParseExpr deja declares dans TODO 04) }

{ TODO 12 - Expressions binaires }
{ (ExprFlushToAX deja declare dans TODO 04) }

{ TODO 13 - Clauses fermees }
Procedure ParseSerialClause(Var Res : TExprVal); Forward;

{ TODO 14 - Conditionnelles }
Procedure ParseIfClause(Var Res : TExprVal); Forward;
Procedure ParseCaseClause(Var Res : TExprVal); Forward;

{ TODO 15 - Boucles }
Procedure ParseLoopClause(Var Res : TExprVal); Forward;

{ TODO 16 - Structures }
Procedure ParseStructDecl; Forward;
Procedure ParseModeDecl; Forward;
Function  StructFieldLookup(ModeIdx : Integer;
                            Const FieldName : TString) : Integer; Forward;

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
  IfCount        := 0;
  CaseCount      := 0;
  LoopCount      := 0;
  StructFieldCount := 0;
  StructCount    := 0;
  RowCount       := 0;
  ProcCount      := 0;
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
  HasPushedToken   := False;
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
    (S = 'DOWNTO')  Or
    (S = 'GOTO')    Or (S = 'GO')      Or (S = 'OUSE')     Or
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

{ ============================================================
  TODO 09 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
  ============================================================ }

{ ---- DataAddByte : ajouter un octet dans le segment DATA ------- }
{ Utilise pour CHAR et BOOL.                                       }

Function DataAddByte(Const Lbl : TString;
                     AByteVal : Integer) : Integer;
Begin
  DataAddByte := DataAdd(Lbl, DK_BYTE, AByteVal And $FF, '');
End;

{ ---- DataAddStruct : ajouter un bloc STRUCT vide --------------- }
{ ASize = nombre de mots DW du bloc (ElemCount stocke la taille). }

Function DataAddStruct(Const Lbl : TString;
                       ASize : Integer) : Integer;
Var
  Idx : Integer;
Begin
  Idx := DataAdd(Lbl, DK_STRUCT_BLK, ASize, '');
  If (Idx >= 0) And (Idx < MAX_DATA) Then
    DataTab[Idx].ElemCount := ASize;
  DataAddStruct := Idx;
End;

{ ---- DataAddArrayDesc : descripteur de tableau [lwb:upb] ------- }
{ Genere un bloc de 4 mots DW : lwb, upb, taille_elem, ptr_data.  }
{ ADataLbl est le label du bloc de donnees du tableau.             }
{ Le descripteur est emis dans le segment DATA avec label Lbl.     }
{ Structure :                                                       }
{   Lbl DW lwb                                                     }
{       DW upb                                                     }
{       DW taille_elem (octets par element)                        }
{       DW OFFSET ADataLbl  (pointeur near vers les donnees)       }

Function DataAddArrayDesc(Const Lbl : TString;
                          ALwb, AUpb, AElemSize : Integer;
                          Const ADataLbl : TString) : Integer;
Var
  Idx : Integer;
Begin
  Idx := DataAdd(Lbl, DK_ARRAY_BLK, ALwb, ADataLbl);
  If (Idx >= 0) And (Idx < MAX_DATA) Then
  Begin
    { Champs reutilises pour le descripteur de tableau :              }
    { IntVal  = lwb (borne inferieure)                               }
    { StrVal  = label du bloc de donnees                             }
    { ElemCount encode upb et elem_size sur 16 bits :                }
    {   bits 8..15 = upb (borne superieure, max 255)                 }
    {   bits 0..7  = taille element en octets (max 255)              }
    DataTab[Idx].ElemCount := (AUpb And $FF) * 256 + (AElemSize And $FF);
  End;
  DataAddArrayDesc := Idx;
End;

{ ---- DataAddUnionDesc : descripteur d union -------------------- }
{ Genere un bloc contenant un discriminant (DW) suivi de           }
{ AMaxSize octets nuls pour la partie donnees de l union.          }

Function DataAddUnionDesc(Const Lbl : TString;
                          ADiscrim, AMaxSize : Integer) : Integer;
Var
  Idx : Integer;
Begin
  Idx := DataAdd(Lbl, DK_STRUCT_BLK, ADiscrim, '');
  If (Idx >= 0) And (Idx < MAX_DATA) Then
    DataTab[Idx].ElemCount := AMaxSize;
  DataAddUnionDesc := Idx;
End;

{ ---- DataAddGlobalVar : declarer une variable globale ---------- }
{ Cree une entree DK_WORD dans DataTab avec label _A68V_nom       }
{ et valeur initiale 0. Retourne l index dans DataTab.            }
{ Si la variable existe deja, retourne l index existant.          }

Function DataAddGlobalVar(Const Name : TString;
                          ModeIdx : Integer) : Integer;
Var
  I      : Integer;
  Lbl    : TString;
  MK     : TModeKind;
Begin
  Lbl := A68_VAR_PFX + SymNameClean(Name);
  { Verifier si deja declaree }
  For I := 0 To DataCount - 1 Do
    If DataTab[I].LblName = Lbl Then
    Begin
      DataAddGlobalVar := I;
      Exit;
    End;
  { Choisir la taille selon le mode }
  MK := ModeKindOf(ModeIdx);
  Case MK Of
    MK_BOOL, MK_CHAR :
      DataAddGlobalVar := DataAddByte(Lbl, 0);
    MK_COMPL :
    Begin
      { COMPL = 2 mots (re + im) }
      DataAddGlobalVar := DataAddStruct(Lbl, 2);
    End;
    Else
      { INT, REAL, BITS, STRING, REF, PROC, etc. = 1 mot DW }
      DataAddGlobalVar := DataAddWord(Lbl, 0);
  End;
End;

{ ---- DataFindStr : retrouver un label de chaine existante ------ }
{ Retourne le label si la chaine existe dans DataTab, '' sinon.    }

Function DataFindStr(Const S : TString) : TString;
Var
  I : Integer;
Begin
  DataFindStr := '';
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_STR) And (DataTab[I].StrVal = S) Then
    Begin
      DataFindStr := DataTab[I].LblName;
      Exit;
    End;
End;

{ ---- EmitDataSeg : ecrire _DATA SEGMENT complet -------------- }
{ Emet les chaines predefinies et toutes les entrees DataTab.    }
{ Gestion des caracteres de controle : les octets non imprimables }
{ (< 32 ou > 126) sont emis comme valeurs numeriques. Les        }
{ apostrophes sont doublees ('') pour MASM.                      }

Procedure EmitDataSeg;
Var
  I, J     : Integer;
  S, NS    : TString;
  B        : Byte;
  InStr    : Boolean;
  First    : Boolean;
Begin
  If Not OutFOpen Then Exit;
  EmitBlankLine;
  EmitRaw('_DATA   SEGMENT WORD PUBLIC ''DATA''');
  EmitRaw('        ASSUME  DS:_DATA');
  { Constantes predefinies Algol 68 }
  EmitLabel('_A68_TRUE_S');
  EmitRaw('        DB      ''TRUE'',0');
  EmitLabel('_A68_FALSE_S');
  EmitRaw('        DB      ''FALSE'',0');
  EmitLabel('_A68_NIL_S');
  EmitRaw('        DB      ''NIL'',0');
  EmitLabel('_A68_CRLF');
  EmitRaw('        DB      13,10,0');
  EmitLabel('_A68_STRBUF');
  EmitRaw('        DB      256 DUP(0)');
  { Pool de chaines dynamiques pour STRING (TODO 09) }
  EmitLabel('_A68_STRPOOL');
  EmitRaw('        DB      ' + IntToStr(STRPOOL_SIZE) + ' DUP(0)');
  EmitLabel('_A68_STRPOOL_TOP');
  EmitRaw('        DW      0');
  { Buffer temporaire pour slice de tableau (TODO 18)
    Structure : DW lwb, upb, elem_size, data_ptr (4 mots = 8 octets) }
  EmitLabel('_A68_SLICEBUF');
  EmitRaw('        DW      0,0,0,0  ; slice desc [lwb,upb,esiz,data]');
  { Entrees dynamiques de DataTab }
  For I := 0 To DataCount - 1 Do
  Begin
    EmitLabel(DataTab[I].LblName);
    Case DataTab[I].Kind Of
      DK_WORD :
        EmitRaw('        DW      ' + IntToStr(DataTab[I].IntVal));
      DK_BYTE :
      Begin
        Str(DataTab[I].IntVal And $FF, NS);
        EmitRaw('        DB      ' + NS);
      End;
      DK_STR :
      Begin
        { Construire la ligne DB avec gestion des caracteres de controle }
        { et doublement des apostrophes pour MASM                       }
        S := '        DB      ';
        InStr := False;
        First := True;
        For J := 1 To Length(DataTab[I].StrVal) Do
        Begin
          B := Ord(DataTab[I].StrVal[J]);
          If (B >= 32) And (B <= 126) Then
          Begin
            { Caractere imprimable }
            If Not InStr Then
            Begin
              If Not First Then S := S + ',';
              S := S + '''';
              InStr := True;
            End;
            If DataTab[I].StrVal[J] = '''' Then
              S := S + ''''''
            Else
              S := S + DataTab[I].StrVal[J];
          End
          Else
          Begin
            { Caractere de controle : emettre comme valeur numerique }
            If InStr Then
            Begin
              S := S + '''';
              InStr := False;
            End;
            If Not First Then S := S + ',';
            Str(B, NS);
            S := S + NS;
          End;
          First := False;
        End;
        If InStr Then S := S + '''';
        If Length(DataTab[I].StrVal) = 0 Then
          S := S + '0'
        Else
          S := S + ',0';
        EmitRaw(S);
      End;
      DK_ARRAY_BLK :
      Begin
        { Descripteur de tableau : DW lwb, upb, taille_elem, OFFSET data }
        { Decodage : IntVal = lwb, ElemCount bits 8..15 = upb,           }
        {            ElemCount bits 0..7 = elem_size, StrVal = data lbl  }
        S := '        DW      ' + IntToStr(DataTab[I].IntVal);
        If DataTab[I].ElemCount > 0 Then
        Begin
          { upb = bits 8..15 }
          Str(DataTab[I].ElemCount Div 256, NS);
          S := S + ',' + NS;
          { elem_size = bits 0..7 }
          Str(DataTab[I].ElemCount And $FF, NS);
          S := S + ',' + NS;
        End
        Else
          S := S + ',0,2';
        If DataTab[I].StrVal <> '' Then
          S := S + ',OFFSET ' + DataTab[I].StrVal
        Else
          S := S + ',0';
        EmitRaw(S + '  ; array desc [lwb,upb,esiz,data]');
      End;
      DK_STRUCT_BLK :
      Begin
        { Bloc STRUCT/UNION : IntVal = valeur initiale (discriminant)    }
        { ElemCount = nombre total de mots DW a reserver dans le bloc   }
        If DataTab[I].ElemCount > 1 Then
        Begin
          { Premier mot = valeur initiale / discriminant }
          EmitRaw('        DW      ' + IntToStr(DataTab[I].IntVal) +
                  '  ; struct/union block');
          { Mots restants = (ElemCount - 1) remplis de zeros }
          Str(DataTab[I].ElemCount - 1, NS);
          EmitRaw('        DW      ' + NS + ' DUP(0)');
        End
        Else If DataTab[I].ElemCount = 1 Then
          EmitRaw('        DW      ' + IntToStr(DataTab[I].IntVal) +
                  '  ; struct block')
        Else
          EmitRaw('        DW      0  ; struct block');
      End;
    End;
  End;
  EmitRaw('_DATA   ENDS');
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

{ ============================================================
  TODO 04 - OPERATEURS ET PRIORITES [IMPLEMENTE]
  ============================================================ }

{ ---- IsAssignOp : detecter un operateur d affectation -------- }
{ Algol 68 : := (becomes), +:= (plusab), -:= (minusab),
  *:= (timesab), /:= (divab)                                    }

Function IsAssignOp(Const Op : TString) : Boolean;
Begin
  IsAssignOp :=
    (Op = ':=') Or (Op = '+:=') Or (Op = '-:=') Or
    (Op = '*:=') Or (Op = '/:=');
End;

{ ---- BinOpPrec : priorite d un operateur binaire ------------- }
{ Algol 68 standard : 9 niveaux (1=faible, 9=fort).
  On reserve 0 = pas d operateur.
    1 : OR  (logique, court-circuit)
    2 : AND (logique, court-circuit)
    3 : = /= < <= > >= (comparaison)
    4 : + - (addition, soustraction binaire)
    5 : * / OVER MOD %  (multiplication, division)
    6 : ** (exponentiation)
    7 : SHL SHR ELEM UP DOWN LWB UPB
    8 : +* I (formation de COMPL)                                }

Function BinOpPrec(Const Op : TString) : Integer;
Begin
  If (Op = 'OR') Then
    BinOpPrec := 1
  Else If (Op = 'AND') Then
    BinOpPrec := 2
  Else If (Op = '=') Or (Op = '/=') Or (Op = '<') Or
          (Op = '<=') Or (Op = '>') Or (Op = '>=') Then
    BinOpPrec := 3
  Else If (Op = '+') Or (Op = '-') Then
    BinOpPrec := 4
  Else If (Op = '*') Or (Op = '/') Or (Op = 'OVER') Or
          (Op = 'MOD') Or (Op = '%') Then
    BinOpPrec := 5
  Else If Op = '**' Then
    BinOpPrec := 6
  Else If (Op = 'SHL') Or (Op = 'SHR') Or (Op = 'ELEM') Or
          (Op = 'UP') Or (Op = 'DOWN') Or (Op = 'LWB') Or
          (Op = 'UPB') Then
    BinOpPrec := 7
  Else If (Op = '+*') Or (Op = 'I') Then
    BinOpPrec := 8
  Else
    BinOpPrec := 0;
End;

{ ---- BinOpIsRight : operateur droit-associatif --------------- }
{ Seul ** est droit-associatif en Algol 68.                      }

Function BinOpIsRight(Const Op : TString) : Boolean;
Begin
  BinOpIsRight := (Op = '**');
End;

{ ---- ExprFlushToAX : charger une TExprVal dans AX ----------- }
{ EK_IMM  -> MOV AX, imm                                        }
{ EK_MEM  -> MOV AX, [BP+Offset] ou LEA AX, [label]             }
{ EK_AX   -> rien (deja dans AX)                                 }
{ EK_NONE -> XOR AX, AX (0 par defaut)                          }

Procedure ExprFlushToAX(Const E : TExprVal);
Var
  S : TString;
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      Str(E.ImmVal, S);
      EmitInstr('MOV    AX, ' + S);
    End;
    EK_MEM :
    Begin
      If E.SymIdx >= 0 Then
      Begin
        If SymTab[E.SymIdx].ScopeLevel = 0 Then
        Begin
          { Global variable/ident : load from data segment }
          If (ModeKindOf(E.ModeIdx) = MK_BOOL) Or
             (ModeKindOf(E.ModeIdx) = MK_CHAR) Then
          Begin
            EmitInstr('XOR    AX, AX');
            EmitInstr('MOV    AL, [' + SymTab[E.SymIdx].MangledName + ']');
          End
          Else If ModeKindOf(E.ModeIdx) = MK_ROW Then
            EmitInstr('MOV    AX, OFFSET ' + SymTab[E.SymIdx].MangledName)
          Else
            EmitInstr('MOV    AX, [' + SymTab[E.SymIdx].MangledName + ']');
        End
        Else
        Begin
          { Variable locale : [BP+Offset] }
          Str(E.Offset, S);
          If ModeKindOf(E.ModeIdx) = MK_ROW Then
          Begin
            { ROW local : LEA pour obtenir l adresse du descripteur }
            If E.Offset >= 0 Then
              EmitInstr('LEA    AX, [BP+' + S + ']')
            Else
              EmitInstr('LEA    AX, [BP' + S + ']');
          End
          Else
          Begin
            If E.Offset >= 0 Then
              EmitInstr('MOV    AX, [BP+' + S + ']')
            Else
              EmitInstr('MOV    AX, [BP' + S + ']');
          End;
        End;
      End
      Else
      Begin
        { Donnee dans DATA segment via DataTab index }
        If (E.Offset >= 0) And (E.Offset < DataCount) Then
          EmitInstr('LEA    AX, ' + DataTab[E.Offset].LblName)
        Else
        Begin
          Str(E.Offset, S);
          EmitInstr('MOV    AX, ' + S);
        End;
      End;
    End;
    EK_AX :
      ; { deja dans AX }
    EK_NONE :
      EmitInstr('XOR    AX, AX');
  End;
End;

{ ---- ParsePrimary : expression primaire (atome) -------------- }
{ Gere : denotations (littéraux), identificateurs, parentheses,
  BEGIN...END, SKIP, EMPTY, NIL, TRUE, FALSE.                   }

Procedure ParsePrimary(Var Res : TExprVal);
Var
  Idx      : Integer;
  ProcName : TString;
  ArgRes   : TExprVal;
  ArgCount : Integer;
  ArgSStr  : TString;
  IdxRes   : TExprVal;
  UpRes    : TExprVal;
  LblElse  : TString;
  LblEnd   : TString;
  LblNext  : TString;
  CaseS    : TString;
  CaseIdx  : Integer;
  CaseRes  : TExprVal;
  { TODO 16 - Struct field selection }
  FieldIdent : TString;
  StructRes  : TExprVal;
  StructMIdx : Integer;
  FldIdx     : Integer;
  FldOfs     : Integer;
  FldMode    : Integer;
  SOfs       : TString;
  CtorMIdx   : Integer;
  CtorFldI   : Integer;
  CtorSize   : TString;
Begin
  Case CurToken.Kind Of
    { ---- Denotations numeriques et booleennes ---- }
    TK_INT_DEN, TK_REAL_DEN, TK_BOOL_DEN, TK_CHAR_DEN, TK_STRING_DEN :
    Begin
      LitEval(CurToken, Res);
      ParserAdvance;
    End;

    { ---- Mots gras (bold) : TRUE FALSE SKIP EMPTY NIL BEGIN ---- }
    TK_BOLD :
    Begin
      If CurToken.Val = 'TRUE' Then
      Begin
        ExprMakeBool(1, Res);
        ParserAdvance;
      End
      Else If CurToken.Val = 'FALSE' Then
      Begin
        ExprMakeBool(0, Res);
        ParserAdvance;
      End
      Else If (CurToken.Val = 'SKIP') Or (CurToken.Val = 'EMPTY') Then
      Begin
        ExprMakeVoid(Res);
        ParserAdvance;
      End
      Else If CurToken.Val = 'NIL' Then
      Begin
        ExprMakeNil(Res);
        ParserAdvance;
      End
      Else If CurToken.Val = 'BEGIN' Then
      Begin
        { BEGIN ... END -> clause fermee avec portee }
        ParserAdvance;
        SymEnterScope;
        ParseSerialClause(Res);
        SymLeaveScope;
        If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'END') Then
          ParserAdvance
        Else
          CompileError('END attendu');
      End
      Else If CurToken.Val = 'IF' Then
      Begin
        ParseIfClause(Res);
      End
      Else If CurToken.Val = 'CASE' Then
      Begin
        ParseCaseClause(Res);
      End
      { TODO 15 - Boucles : FOR / WHILE / DO }
      Else If (CurToken.Val = 'FOR') Or (CurToken.Val = 'WHILE') Or
              (CurToken.Val = 'DO') Then
      Begin
        ParseLoopClause(Res);
      End
      { GOTO label ou GO TO label -> JMP _A68L_name }
      Else If CurToken.Val = 'GOTO' Then
      Begin
        ParserAdvance; { consomme GOTO }
        If CurToken.Kind = TK_IDENT Then
        Begin
          EmitInstr('JMP    ' + A68_LBL_PFX + CurToken.Val);
          ParserAdvance;
        End
        Else
          CompileError('identificateur attendu apres GOTO');
        ExprMakeVoid(Res);
      End
      Else If CurToken.Val = 'GO' Then
      Begin
        ParserAdvance; { consomme GO }
        If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'TO') Then
          ParserAdvance { consomme TO }
        Else
          CompileError('TO attendu apres GO');
        If CurToken.Kind = TK_IDENT Then
        Begin
          EmitInstr('JMP    ' + A68_LBL_PFX + CurToken.Val);
          ParserAdvance;
        End
        Else
          CompileError('identificateur attendu apres GO TO');
        ExprMakeVoid(Res);
      End
      Else
      Begin
        { Autre mot gras : stub pour TODO ulterieurs }
        ExprMakeNone(Res);
        ParserAdvance;
      End;
    End;

    { ---- Identificateur ---- }
    TK_IDENT :
    Begin
      Idx := SymFind(CurToken.Val);
      If Idx >= 0 Then
      Begin
        Res.Kind    := EK_MEM;
        Res.ImmVal  := 0;
        Res.ModeIdx := SymTab[Idx].ModeIdx;
        Res.Offset  := SymTab[Idx].Offset;
        Res.SymIdx  := Idx;
        ParserAdvance;
      End
      Else
      Begin
        { Verifier si c est un constructeur de struct : POINT(3, 7) }
        CtorMIdx := ModeLookupName(CurToken.Val);
        If (CtorMIdx >= 0) And (ModeTab[CtorMIdx].Kind = MK_STRUCT) Then
        Begin
          { Constructeur de structure }
          ParserAdvance; { consomme le nom du mode }
          If CurToken.Kind = TK_OPEN Then
          Begin
            ParserAdvance; { consomme ( }
            EmitComment('struct constructor ' + ModeTab[CtorMIdx].Name);
            { Allouer l espace sur la pile }
            If ModeTab[CtorMIdx].Size > 0 Then
            Begin
              Str(ModeTab[CtorMIdx].Size, CtorSize);
              EmitInstr('SUB    SP, ' + CtorSize);
            End;
            EmitInstr('MOV    BX, SP');
            { Remplir les champs dans l ordre }
            CtorFldI := 0;
            While (CurToken.Kind <> TK_CLOSE) And
                  (CurToken.Kind <> TK_EOF) Do
            Begin
              ParseExpr(ArgRes);
              ExprFlushToAX(ArgRes);
              If CtorFldI < ModeTab[CtorMIdx].FieldCnt Then
              Begin
                FldOfs := StructFieldTab[
                  ModeTab[CtorMIdx].ElemIdx + CtorFldI].Offset;
                Str(FldOfs, SOfs);
                If FldOfs = 0 Then
                  EmitInstr('MOV    [BX], AX')
                Else
                  EmitInstr('MOV    [BX+' + SOfs + '], AX');
              End;
              Inc(CtorFldI);
              If CurToken.Kind = TK_COMMA Then
                ParserAdvance;
            End;
            If CurToken.Kind = TK_CLOSE Then
              ParserAdvance;
            { AX = adresse de la structure allouee }
            EmitInstr('MOV    AX, BX');
            Res.Kind    := EK_AX;
            Res.ModeIdx := CtorMIdx;
            Res.SymIdx  := -1;
          End
          Else
          Begin
            { Nom de mode sans ( : traiter comme 0 }
            ExprMakeImm(0, CtorMIdx, Res);
          End;
        End
        Else
        Begin
          { Identifiant inconnu : sauvegarder le nom puis avancer }
          FieldIdent := CurToken.Val;
          ParserAdvance;
          { Verifier si c est un selecteur de champ : ident OF expr }
          If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'OF') Then
          Begin
            ParserAdvance; { consomme OF }
            ParsePrimary(StructRes);
            StructMIdx := StructRes.ModeIdx;
            If (StructMIdx >= 0) And (StructMIdx < ModeCount) And
               (ModeTab[StructMIdx].Kind = MK_STRUCT) Then
            Begin
              FldIdx := StructFieldLookup(StructMIdx, FieldIdent);
              If FldIdx >= 0 Then
              Begin
                FldOfs  := StructFieldTab[FldIdx].Offset;
                FldMode := StructFieldTab[FldIdx].ModeIdx;
                Str(FldOfs, SOfs);
                EmitComment('field ' + FieldIdent + ' OF ' +
                            ModeTab[StructMIdx].Name +
                            ', offset=' + SOfs);
                If (StructRes.Kind = EK_MEM) And
                   (StructRes.SymIdx >= 0) Then
                Begin
                  If SymTab[StructRes.SymIdx].ScopeLevel = 0 Then
                    EmitInstr('MOV    BX, OFFSET ' +
                              SymTab[StructRes.SymIdx].MangledName)
                  Else
                  Begin
                    Str(StructRes.Offset, SOfs);
                    If StructRes.Offset >= 0 Then
                      EmitInstr('LEA    BX, [BP+' + SOfs + ']')
                    Else
                      EmitInstr('LEA    BX, [BP' + SOfs + ']');
                  End;
                  If FldOfs > 0 Then
                  Begin
                    Str(FldOfs, SOfs);
                    EmitInstr('ADD    BX, ' + SOfs);
                  End;
                  If (ModeSizeof(FldMode) = 1) Then
                  Begin
                    EmitInstr('XOR    AX, AX');
                    EmitInstr('MOV    AL, [BX]');
                  End
                  Else
                    EmitInstr('MOV    AX, [BX]');
                End
                Else
                Begin
                  ExprFlushToAX(StructRes);
                  EmitInstr('MOV    BX, AX');
                  If FldOfs > 0 Then
                  Begin
                    Str(FldOfs, SOfs);
                    EmitInstr('ADD    BX, ' + SOfs);
                  End;
                  EmitInstr('MOV    AX, [BX]');
                End;
                Res.Kind    := EK_AX;
                Res.ModeIdx := FldMode;
                Res.SymIdx  := -1;
              End
              Else
              Begin
                CompileError('champ ' + FieldIdent +
                             ' inconnu dans ' +
                             ModeTab[StructMIdx].Name);
                Res.Kind   := EK_AX;
                Res.SymIdx := -1;
              End;
            End
            Else
            Begin
              ExprFlushToAX(StructRes);
              EmitComment('field selection (OF) - non-struct');
              Res.Kind   := EK_AX;
              Res.SymIdx := -1;
            End;
          End
          Else
          Begin
            WarnMsg('identificateur non declare: ' + FieldIdent);
            ExprMakeImm(0, TY_IDX_INT, Res);
          End;
        End;
      End;
      { Appel de procedure : nom(args) -> PUSH args + CALL }
      If (Idx >= 0) And (SymTab[Idx].Cat = SC_PROC) And
         (CurToken.Kind = TK_OPEN) Then
      Begin
        ProcName := SymTab[Idx].MangledName;
        ArgCount := 0;
        ParserAdvance; { consomme ( }
        While (CurToken.Kind <> TK_CLOSE) And
              (CurToken.Kind <> TK_EOF) Do
        Begin
          ParseExpr(ArgRes);
          ExprFlushToAX(ArgRes);
          EmitInstr('PUSH   AX');
          Inc(ArgCount);
          If CurToken.Kind = TK_COMMA Then
            ParserAdvance;
        End;
        If CurToken.Kind = TK_CLOSE Then
          ParserAdvance;
        EmitInstr('CALL   ' + ProcName);
        If ArgCount > 0 Then
        Begin
          Str(ArgCount * 2, ArgSStr);
          EmitInstr('ADD    SP, ' + ArgSStr);
        End;
        Res.Kind    := EK_AX;
        Res.ModeIdx := SymTab[Idx].ModeIdx;
        Res.SymIdx  := -1;
      End
      { Simple identifier (not a call) - check postfix OF, [, etc. }
      Else If Idx >= 0 Then
      Begin
        { Selection de champ : ident OF struct }
        If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'OF') Then
        Begin
          ParserAdvance; { consomme OF }
          { En Algol 68, la syntaxe est "champ OF struct_expr".
            L ident lu (Idx) est le NOM DU CHAMP.
            L expression apres OF est la variable struct. }
          FieldIdent := SymTab[Idx].Name;
          { Parser l expression struct apres OF }
          ParsePrimary(StructRes);
          StructMIdx := StructRes.ModeIdx;
          If (StructMIdx >= 0) And (StructMIdx < ModeCount) And
             (ModeTab[StructMIdx].Kind = MK_STRUCT) Then
          Begin
            FldIdx := StructFieldLookup(StructMIdx, FieldIdent);
            If FldIdx >= 0 Then
            Begin
              FldOfs  := StructFieldTab[FldIdx].Offset;
              FldMode := StructFieldTab[FldIdx].ModeIdx;
              Str(FldOfs, SOfs);
              EmitComment('field ' + FieldIdent + ' OF ' +
                          ModeTab[StructMIdx].Name +
                          ', offset=' + SOfs);
              { Calculer l adresse de la struct }
              If (StructRes.Kind = EK_MEM) And
                 (StructRes.SymIdx >= 0) Then
              Begin
                If SymTab[StructRes.SymIdx].ScopeLevel = 0 Then
                Begin
                  { Global struct : adresse via label }
                  EmitInstr('MOV    BX, OFFSET ' +
                            SymTab[StructRes.SymIdx].MangledName);
                End
                Else
                Begin
                  { Local struct : adresse via BP+offset }
                  Str(StructRes.Offset, SOfs);
                  If StructRes.Offset >= 0 Then
                    EmitInstr('LEA    BX, [BP+' + SOfs + ']')
                  Else
                    EmitInstr('LEA    BX, [BP' + SOfs + ']');
                End;
                { Ajouter l offset du champ }
                If FldOfs > 0 Then
                Begin
                  Str(FldOfs, SOfs);
                  EmitInstr('ADD    BX, ' + SOfs);
                End;
                { Charger la valeur du champ }
                If (ModeSizeof(FldMode) = 1) Then
                Begin
                  EmitInstr('XOR    AX, AX');
                  EmitInstr('MOV    AL, [BX]');
                End
                Else
                  EmitInstr('MOV    AX, [BX]');
              End
              Else
              Begin
                { Struct dans AX (adresse) }
                ExprFlushToAX(StructRes);
                EmitInstr('MOV    BX, AX');
                If FldOfs > 0 Then
                Begin
                  Str(FldOfs, SOfs);
                  EmitInstr('ADD    BX, ' + SOfs);
                End;
                EmitInstr('MOV    AX, [BX]');
              End;
              Res.Kind    := EK_AX;
              Res.ModeIdx := FldMode;
              Res.SymIdx  := -1;
            End
            Else
            Begin
              CompileError('champ ' + FieldIdent +
                           ' inconnu dans ' +
                           ModeTab[StructMIdx].Name);
              Res.Kind   := EK_AX;
              Res.SymIdx := -1;
            End;
          End
          Else
          Begin
            { Pas un struct : traiter comme avant (stub) }
            ExprFlushToAX(StructRes);
            EmitComment('field selection (OF) - non-struct');
            Res.Kind   := EK_AX;
            Res.SymIdx := -1;
          End;
        End
        { Indexation de tableau : expr[indice] }
        Else If CurToken.Kind = TK_SUB Then
        Begin
          ExprFlushToAX(Res);
          EmitInstr('PUSH   AX');
          ParserAdvance; { consomme [ }
          ParseExpr(IdxRes);
          { Detect slice lo:up }
          If CurToken.Kind = TK_COLON Then
          Begin
            { Tranche : expr[lo:up] }
            ExprFlushToAX(IdxRes);
            EmitInstr('PUSH   AX'); { lo }
            ParserAdvance; { consomme : }
            ParseExpr(UpRes);
            ExprFlushToAX(UpRes);
            EmitInstr('PUSH   AX'); { up }
            { Appel runtime slice ou STRTRIM selon contexte }
            If (Res.ModeIdx >= 0) And (Res.ModeIdx < ModeCount) And
               (ModeTab[Res.ModeIdx].Kind = MK_ROW) Then
            Begin
              EmitInstr('CALL   ' + A68_RT_PFX + 'SLICE');
              EmitInstr('ADD    SP, 6');
            End
            Else
            Begin
              EmitInstr('CALL   _A68RT_STRTRIM');
              EmitInstr('ADD    SP, 6');
            End;
          End
          Else
          Begin
            { Simple indexation }
            ExprFlushToAX(IdxRes);
            EmitComment('array index');
            { Verifier si c est un mode ROW -> descriptor-based }
            If (Res.ModeIdx >= 0) And (Res.ModeIdx < ModeCount) And
               (ModeTab[Res.ModeIdx].Kind = MK_ROW) Then
            Begin
              { AX = index, stack top = descriptor ptr }
              EmitInstr('POP    BX');        { BX = descriptor ptr }
              EmitInstr('PUSH   BX');        { garder pour bounds check }
              EmitInstr('CALL   ' + A68_RT_PFX + 'ROWCHK');
              EmitInstr('POP    BX');        { BX = descriptor ptr }
              EmitInstr('SUB    AX, [BX]');  { AX = index - lwb }
              EmitInstr('MOV    CX, [BX+4]'); { CX = elem_size }
              EmitInstr('MUL    CX');        { AX = offset }
              EmitInstr('ADD    AX, [BX+6]'); { AX = data_ptr + offset }
              EmitInstr('MOV    BX, AX');
              If (ModeTab[Res.ModeIdx].ElemIdx >= 0) And
                 (ModeTab[Res.ModeIdx].ElemIdx < ModeCount) And
                 (ModeTab[ModeTab[Res.ModeIdx].ElemIdx].Size = 1) Then
                EmitInstr('MOV    AL, [BX]')
              Else
                EmitInstr('MOV    AX, [BX]');
              { Mettre a jour le mode resultat au mode element }
              Res.ModeIdx := ModeTab[Res.ModeIdx].ElemIdx;
            End
            Else
            Begin
              { Indexation simple (STRING etc.) }
              EmitInstr('SHL    AX, 1');
              EmitInstr('POP    BX');
              EmitInstr('ADD    BX, AX');
              EmitInstr('MOV    AX, [BX]');
            End;
          End;
          If CurToken.Kind = TK_BUS2 Then
            ParserAdvance; { consomme ] }
          Res.Kind   := EK_AX;
          Res.SymIdx := -1;
        End;
      End;
    End;

    { ---- Parenthese ouvrante ( -> clause fermee ou forme abregee - }
    TK_OPEN :
    Begin
      ParserAdvance; { consomme ( }
      SymEnterScope;
      ParseSerialClause(Res);

      { Forme abregee : (expr | ...) }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '|') Then
      Begin
        ExprFlushToAX(Res);
        ParserAdvance; { consomme premier | }

        If Res.ModeIdx = TY_IDX_BOOL Then
        Begin
          { Forme abregee IF : (cond | then_val | else_val) }
          Inc(IfCount);
          LblElse := A68_LBL_PFX + 'ELSE_' + IntToStr(IfCount);
          LblEnd  := A68_LBL_PFX + 'FI_' + IntToStr(IfCount);

          EmitInstr('TEST   AX, AX');
          EmitInstr('JZ     ' + LblElse);

          { Branche THEN }
          ParseSerialClause(Res);
          ExprFlushToAX(Res);
          EmitInstr('JMP    ' + LblEnd);

          { Branche ELSE }
          EmitLabel(LblElse);
          If (CurToken.Kind = TK_OP) And (CurToken.Val = '|') Then
          Begin
            ParserAdvance; { consomme second | }
            ParseSerialClause(Res);
            ExprFlushToAX(Res);
          End
          Else
            EmitInstr('XOR    AX, AX'); { pas de ELSE -> 0 }

          EmitLabel(LblEnd);
          Res.Kind   := EK_AX;
          Res.SymIdx := -1;
        End
        Else
        Begin
          { Forme abregee CASE : (expr | v1, v2, ... | defaut) }
          Inc(CaseCount);
          LblEnd := A68_LBL_PFX + 'CESAC_' + IntToStr(CaseCount);
          EmitInstr('MOV    BX, AX'); { sauvegarde selecteur }

          CaseIdx := 1;
          ExprMakeNone(Res);
          While (CurToken.Kind <> TK_CLOSE) And
                (CurToken.Kind <> TK_EOF) Do
          Begin
            If (CurToken.Kind = TK_OP) And (CurToken.Val = '|') Then
              Break; { marqueur OUT/defaut }

            LblNext := A68_LBL_PFX + 'CASE_' + IntToStr(CaseCount)
                       + '_' + IntToStr(CaseIdx);
            Str(CaseIdx, CaseS);
            EmitInstr('CMP    BX, ' + CaseS);
            EmitInstr('JNE    ' + LblNext);

            ParseSerialClause(CaseRes);
            ExprFlushToAX(CaseRes);
            Res := CaseRes;
            EmitInstr('JMP    ' + LblEnd);

            EmitLabel(LblNext);
            Inc(CaseIdx);

            If CurToken.Kind = TK_COMMA Then
              ParserAdvance
            Else
              Break;
          End;

          { Defaut (equivalent OUT) }
          If (CurToken.Kind = TK_OP) And (CurToken.Val = '|') Then
          Begin
            ParserAdvance; { consomme | }
            ParseSerialClause(CaseRes);
            ExprFlushToAX(CaseRes);
            Res := CaseRes;
          End;

          EmitLabel(LblEnd);
          Res.Kind   := EK_AX;
          Res.SymIdx := -1;
        End;

        SymLeaveScope;
        If CurToken.Kind = TK_CLOSE Then
          ParserAdvance
        Else
          CompileError(') attendu');
      End
      Else
      Begin
        SymLeaveScope;
        If CurToken.Kind = TK_CLOSE Then
          ParserAdvance  { consomme ) }
        Else
          CompileError(') attendu');
      End;
    End;

  Else
    { Token inattendu }
    CompileError('expression attendue, token: ' + CurToken.Val);
    ExprMakeNone(Res);
    If CurToken.Kind <> TK_EOF Then
      ParserAdvance;
  End;
End;

{ ---- ParseUnary : operateurs unaires (monadiques) ------------ }
{ Algol 68 : NOT, ABS, -, +, ODD, SIGN, BIN, REPR, ROUND,
  ENTIER, SHORTEN, LENG, CONJ, RE, IM, ARG, LEVEL             }

Procedure ParseUnary(Var Res : TExprVal);
Var
  Op      : TString;
  LblSkip : TString;
  LblEnd  : TString;
Begin
  { ---- Operateur unaire symbole : - + ~ ---- }
  If (CurToken.Kind = TK_OP) And
     ((CurToken.Val = '-') Or (CurToken.Val = '+') Or
      (CurToken.Val = '~')) Then
  Begin
    Op := CurToken.Val;
    ParserAdvance;
    ParseUnary(Res); { recursion pour unaires enchaines }
    { Pliage de constantes }
    If Res.Kind = EK_IMM Then
    Begin
      If Op = '-' Then
        Res.ImmVal := -Res.ImmVal
      Else If Op = '~' Then
        Res.ImmVal := Not Res.ImmVal;
      { + : rien a faire }
    End
    Else
    Begin
      ExprFlushToAX(Res);
      If Op = '-' Then
        EmitInstr('NEG    AX')
      Else If Op = '~' Then
        EmitInstr('NOT    AX');
      { Op = '+' : rien a faire }
      Res.Kind := EK_AX;
    End;
    Exit;
  End;

  { ---- Operateurs unaires bold : NOT ABS ODD SIGN etc. ---- }
  If (CurToken.Kind = TK_BOLD) Then
  Begin
    Op := CurToken.Val;

    If Op = 'NOT' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      If Res.Kind = EK_IMM Then
      Begin
        If Res.ImmVal = 0 Then Res.ImmVal := 1
        Else Res.ImmVal := 0;
        Res.ModeIdx := TY_IDX_BOOL;
      End
      Else
      Begin
        ExprFlushToAX(Res);
        { NOT AX : 0->1, non-zero->0 }
        EmitInstr('CMP    AX, 0');
        LblSkip := LabelGen;
        LblEnd  := LabelGen;
        EmitInstr('JE     ' + LblSkip);
        EmitInstr('XOR    AX, AX');
        EmitInstr('JMP    ' + LblEnd);
        EmitLabel(LblSkip);
        EmitInstr('MOV    AX, 1');
        EmitLabel(LblEnd);
        Res.Kind := EK_AX;
        Res.ModeIdx := TY_IDX_BOOL;
      End;
      Exit;
    End;

    If Op = 'ABS' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      If Res.Kind = EK_IMM Then
      Begin
        If Res.ImmVal < 0 Then Res.ImmVal := -Res.ImmVal;
      End
      Else
      Begin
        ExprFlushToAX(Res);
        { ABS AX : si negatif, negate }
        EmitInstr('CMP    AX, 0');
        EmitInstr('JGE    $+4');
        EmitInstr('NEG    AX');
        Res.Kind := EK_AX;
      End;
      Exit;
    End;

    If Op = 'ODD' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      If Res.Kind = EK_IMM Then
      Begin
        Res.ImmVal := Res.ImmVal And 1;
        Res.ModeIdx := TY_IDX_BOOL;
      End
      Else
      Begin
        ExprFlushToAX(Res);
        EmitInstr('AND    AX, 1');
        Res.Kind := EK_AX;
        Res.ModeIdx := TY_IDX_BOOL;
      End;
      Exit;
    End;

    If Op = 'SIGN' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      If Res.Kind = EK_IMM Then
      Begin
        If Res.ImmVal > 0 Then Res.ImmVal := 1
        Else If Res.ImmVal < 0 Then Res.ImmVal := -1
        Else Res.ImmVal := 0;
      End
      Else
      Begin
        { Stub : resultat dans AX (-1, 0, 1) }
        ExprFlushToAX(Res);
        EmitInstr('CMP    AX, 0');
        EmitInstr('JG     ' + A68_LBL_PFX + 'SGN_P');
        EmitInstr('JL     ' + A68_LBL_PFX + 'SGN_N');
        EmitInstr('XOR    AX, AX');
        EmitInstr('JMP    ' + A68_LBL_PFX + 'SGN_E');
        EmitLabel(A68_LBL_PFX + 'SGN_P');
        EmitInstr('MOV    AX, 1');
        EmitInstr('JMP    ' + A68_LBL_PFX + 'SGN_E');
        EmitLabel(A68_LBL_PFX + 'SGN_N');
        EmitInstr('MOV    AX, -1');
        EmitLabel(A68_LBL_PFX + 'SGN_E');
        Res.Kind := EK_AX;
      End;
      Exit;
    End;

    If Op = 'ENTIER' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      { Sur 8086 sans FPU, ENTIER(x) = x (deja tronque) }
      Res.ModeIdx := TY_IDX_INT;
      Exit;
    End;

    If Op = 'ROUND' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      { Sur 8086 sans FPU, ROUND(x) = x (deja tronque) }
      Res.ModeIdx := TY_IDX_INT;
      Exit;
    End;

    If (Op = 'BIN') Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      Res.ModeIdx := TY_IDX_BITS;
      Exit;
    End;

    If (Op = 'REPR') Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      Res.ModeIdx := TY_IDX_CHAR;
      Exit;
    End;

    If (Op = 'LENG') Or (Op = 'SHORTEN') Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      { Sur 8086 16-bit, LENG et SHORTEN sont identite }
      Exit;
    End;

    If (Op = 'RE') Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      { RE z = partie reelle -> stub : AX inchange }
      Res.ModeIdx := TY_IDX_INT;
      Exit;
    End;

    If (Op = 'IM') Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      { IM z = partie imaginaire -> stub : AX=0 }
      ExprMakeImm(0, TY_IDX_INT, Res);
      Exit;
    End;

    If (Op = 'CONJ') Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      { CONJ z = conjugue complexe -> stub : AX inchange }
      Exit;
    End;

    If (Op = 'ARG') Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      { ARG z = argument complexe -> stub : 0 }
      ExprMakeImm(0, TY_IDX_REAL, Res);
      Exit;
    End;

    If (Op = 'LEVEL') Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      { LEVEL : scope level -> stub : 0 }
      ExprMakeImm(0, TY_IDX_INT, Res);
      Exit;
    End;

    If Op = 'LWB' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      ExprFlushToAX(Res);
      EmitComment('LWB (prefix)');
      EmitInstr('MOV    BX, AX');
      EmitInstr('MOV    AX, [BX]');
      Res.Kind    := EK_AX;
      Res.ModeIdx := TY_IDX_INT;
      Exit;
    End;

    If Op = 'UPB' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      ExprFlushToAX(Res);
      EmitComment('UPB (prefix)');
      EmitInstr('MOV    BX, AX');
      EmitInstr('MOV    AX, [BX+2]');
      Res.Kind    := EK_AX;
      Res.ModeIdx := TY_IDX_INT;
      Exit;
    End;
  End;

  { ---- Pas d operateur unaire -> expression primaire ---- }
  ParsePrimary(Res);
End;

{ ---- ParseFormula : parseur de Pratt pour formules Algol 68 -- }
{ MinPrio = priorite minimale a capturer (1 au premier appel).   }
{ Gere court-circuit AND/OR, constant folding, CMP+Jcc.         }

Procedure ParseFormula(MinPrio : Integer; Var Res : TExprVal);
Var
  Op       : TString;
  Prec     : Integer;
  NextPrio : Integer;
  Rhs      : TExprVal;
  LblSkip  : TString;
  LblEnd   : TString;
  LVal     : LongInt;
  RVal     : LongInt;
  FoldOK   : Boolean;
  IsStrCmp : Boolean; { comparaison sur STRING }
Begin
  ParseUnary(Res);

  { Boucle Pratt : tant qu on trouve un operateur de priorite >= MinPrio }
  While True Do
  Begin
    Op   := '';
    Prec := 0;

    { Detecter un operateur binaire dans TK_OP }
    If CurToken.Kind = TK_OP Then
    Begin
      Op   := CurToken.Val;
      Prec := BinOpPrec(Op);
    End
    { Detecter un operateur bold (OR AND OVER MOD SHL SHR etc.) }
    Else If CurToken.Kind = TK_BOLD Then
    Begin
      Op   := CurToken.Val;
      Prec := BinOpPrec(Op);
    End;

    { Si pas d operateur ou priorite trop faible -> sortir }
    If (Prec = 0) Or (Prec < MinPrio) Then Break;

    ParserAdvance; { consommer l operateur }

    { ---- Court-circuit AND (logique BOOL) / Bitwise AND (BITS) ---- }
    If (Op = 'AND') And (ModeKindOf(Res.ModeIdx) <> MK_BITS) Then
    Begin
      If Res.Kind = EK_IMM Then
      Begin
        If Res.ImmVal = 0 Then
        Begin
          { AND avec gauche fausse : court-circuiter }
          ParseFormula(Prec + 1, Rhs);
          ExprMakeBool(0, Res);
          Continue;
        End;
        { Gauche vraie : resultat = evaluation droite }
        ParseFormula(Prec + 1, Rhs);
        Res := Rhs;
        If Res.Kind = EK_IMM Then
        Begin
          If Res.ImmVal <> 0 Then Res.ImmVal := 1
          Else Res.ImmVal := 0;
          Res.ModeIdx := TY_IDX_BOOL;
        End;
        Continue;
      End;
      { Pas de constante : emission court-circuit }
      ExprFlushToAX(Res);
      LblSkip := LabelGen;
      EmitInstr('CMP    AX, 0');
      EmitInstr('JE     ' + LblSkip);
      ParseFormula(Prec + 1, Rhs);
      ExprFlushToAX(Rhs);
      EmitLabel(LblSkip);
      Res.Kind    := EK_AX;
      Res.ModeIdx := TY_IDX_BOOL;
      Continue;
    End;

    { ---- Court-circuit OR (logique BOOL) / Bitwise OR (BITS) ---- }
    If (Op = 'OR') And (ModeKindOf(Res.ModeIdx) <> MK_BITS) Then
    Begin
      If Res.Kind = EK_IMM Then
      Begin
        If Res.ImmVal <> 0 Then
        Begin
          { OR avec gauche vraie : court-circuiter }
          ParseFormula(Prec + 1, Rhs);
          ExprMakeBool(1, Res);
          Continue;
        End;
        { Gauche fausse : resultat = evaluation droite }
        ParseFormula(Prec + 1, Rhs);
        Res := Rhs;
        If Res.Kind = EK_IMM Then
        Begin
          If Res.ImmVal <> 0 Then Res.ImmVal := 1
          Else Res.ImmVal := 0;
          Res.ModeIdx := TY_IDX_BOOL;
        End;
        Continue;
      End;
      { Pas de constante : emission court-circuit }
      ExprFlushToAX(Res);
      LblSkip := LabelGen;
      EmitInstr('CMP    AX, 0');
      EmitInstr('JNE    ' + LblSkip);
      ParseFormula(Prec + 1, Rhs);
      ExprFlushToAX(Rhs);
      EmitLabel(LblSkip);
      Res.Kind    := EK_AX;
      Res.ModeIdx := TY_IDX_BOOL;
      Continue;
    End;

    { ---- Tous les autres operateurs binaires ---- }
    If BinOpIsRight(Op) Then NextPrio := Prec
    Else NextPrio := Prec + 1;

    { Sauver gauche sur la pile si non-constante }
    FoldOK := (Res.Kind = EK_IMM);
    LVal   := Res.ImmVal;
    If Not FoldOK Then
    Begin
      ExprFlushToAX(Res);
      EmitInstr('PUSH   AX');
    End;

    ParseFormula(NextPrio, Rhs);

    { Tentative de pliage de constantes }
    If FoldOK And (Rhs.Kind = EK_IMM) Then
    Begin
      RVal := Rhs.ImmVal;

      { Arithmetique }
      If Op = '+' Then
        Res.ImmVal := LVal + RVal
      Else If Op = '-' Then
        Res.ImmVal := LVal - RVal
      Else If (Op = '*') Then
        Res.ImmVal := LVal * RVal
      Else If (Op = '/') Or (Op = 'OVER') Then
      Begin
        If RVal = 0 Then
        Begin
          CompileError('division par zero');
          Res.ImmVal := 0;
        End
        Else
          Res.ImmVal := LVal Div RVal;
      End
      Else If (Op = 'MOD') Or (Op = '%') Then
      Begin
        If RVal = 0 Then
        Begin
          CompileError('modulo par zero');
          Res.ImmVal := 0;
        End
        Else
          Res.ImmVal := LVal Mod RVal;
      End
      Else If Op = '**' Then
      Begin
        { Exponentiation par iteration }
        If RVal < 0 Then
        Begin
          Res.ImmVal := 0; { resultat entier = 0 pour exp negative }
          WarnMsg('exposant negatif tronque a 0');
        End
        Else
        Begin
          Res.ImmVal := 1;
          While RVal > 0 Do
          Begin
            Res.ImmVal := Res.ImmVal * LVal;
            Dec(RVal);
          End;
        End;
      End
      { Comparaisons }
      Else If Op = '=' Then
      Begin
        If LVal = RVal Then Res.ImmVal := 1 Else Res.ImmVal := 0;
        Res.ModeIdx := TY_IDX_BOOL;
      End
      Else If Op = '/=' Then
      Begin
        If LVal <> RVal Then Res.ImmVal := 1 Else Res.ImmVal := 0;
        Res.ModeIdx := TY_IDX_BOOL;
      End
      Else If Op = '<' Then
      Begin
        If LVal < RVal Then Res.ImmVal := 1 Else Res.ImmVal := 0;
        Res.ModeIdx := TY_IDX_BOOL;
      End
      Else If Op = '<=' Then
      Begin
        If LVal <= RVal Then Res.ImmVal := 1 Else Res.ImmVal := 0;
        Res.ModeIdx := TY_IDX_BOOL;
      End
      Else If Op = '>' Then
      Begin
        If LVal > RVal Then Res.ImmVal := 1 Else Res.ImmVal := 0;
        Res.ModeIdx := TY_IDX_BOOL;
      End
      Else If Op = '>=' Then
      Begin
        If LVal >= RVal Then Res.ImmVal := 1 Else Res.ImmVal := 0;
        Res.ModeIdx := TY_IDX_BOOL;
      End
      { SHL / SHR }
      Else If Op = 'SHL' Then
        Res.ImmVal := LVal Shl RVal
      Else If Op = 'SHR' Then
        Res.ImmVal := LVal Shr RVal
      { +* (complexe) }
      Else If (Op = '+*') Or (Op = 'I') Then
      Begin
        Res.ImmVal := LVal;
        Res.ModeIdx := TY_IDX_COMPL;
        WarnMsg('COMPL non supporte sur 8086, partie IM ignoree');
      End
      { LWB / UPB : stub }
      Else If Op = 'LWB' Then
        Res.ImmVal := 1
      Else If Op = 'UPB' Then
        Res.ImmVal := LVal
      { AND / OR bitwise sur BITS (pliage de constantes) }
      Else If Op = 'AND' Then
        Res.ImmVal := LVal And RVal
      Else If Op = 'OR' Then
        Res.ImmVal := LVal Or RVal
      { ELEM : test de bit (resultat BOOL)
        RVal < 16 car BITS est un mot 16 bits sur 8086 }
      Else If Op = 'ELEM' Then
      Begin
        If (RVal >= 0) And (RVal < 16) Then
        Begin
          If ((LVal Shr RVal) And 1) = 1 Then Res.ImmVal := 1
          Else Res.ImmVal := 0;
        End
        Else
          Res.ImmVal := 0;
        Res.ModeIdx := TY_IDX_BOOL;
      End
      Else
      Begin
        FoldOK := False; { operateur inconnu : pas de pliage }
      End;

      If FoldOK Then Continue;
      { Si pliage echoue, on genere le code normalement }
      ExprFlushToAX(Res);
      EmitInstr('PUSH   AX');
    End;

    { ---- Generation de code pour operateurs binaires ---- }
    ExprFlushToAX(Rhs);
    EmitInstr('MOV    BX, AX');
    EmitInstr('POP    AX');

    { Arithmetique / Concatenation STRING }
    If Op = '+' Then
    Begin
      If ModeKindOf(Res.ModeIdx) = MK_STRING Then
      Begin
        { Concatenation de chaines : AX=ptr1, BX=ptr2 -> AX=resultat }
        EmitInstr('CALL   ' + A68_RT_PFX + 'CONCAT');
        Res.ModeIdx := TY_IDX_STRING;
      End
      Else
        EmitInstr('ADD    AX, BX');
    End
    Else If Op = '-' Then
      EmitInstr('SUB    AX, BX')
    Else If Op = '*' Then
      EmitInstr('IMUL   BX')
    Else If (Op = '/') Or (Op = 'OVER') Then
    Begin
      EmitInstr('CWD');
      EmitInstr('IDIV   BX');
    End
    Else If (Op = 'MOD') Or (Op = '%') Then
    Begin
      EmitInstr('CWD');
      EmitInstr('IDIV   BX');
      EmitInstr('MOV    AX, DX'); { reste dans DX }
    End
    Else If Op = '**' Then
    Begin
      { Appel runtime : AX=base, BX=exp -> AX=resultat }
      EmitInstr('CALL   ' + A68_RT_PFX + 'POWER');
    End
    { Comparaisons -> CMP + SETcc emulee (STRING : CALL _A68RT_STRCMP) }
    Else If (Op = '=') Or (Op = '/=') Or (Op = '<') Or
            (Op = '<=') Or (Op = '>') Or (Op = '>=') Then
    Begin
      IsStrCmp := (ModeKindOf(Res.ModeIdx) = MK_STRING);
      If IsStrCmp Then
        EmitInstr('CALL   ' + A68_RT_PFX + 'STRCMP')
      Else
        EmitInstr('CMP    AX, BX');
      LblSkip := LabelGen;
      LblEnd  := LabelGen;
      If Op = '=' Then
        EmitInstr('JE     ' + LblSkip)
      Else If Op = '/=' Then
        EmitInstr('JNE    ' + LblSkip)
      Else If Op = '<' Then
        EmitInstr('JL     ' + LblSkip)
      Else If Op = '<=' Then
        EmitInstr('JLE    ' + LblSkip)
      Else If Op = '>' Then
        EmitInstr('JG     ' + LblSkip)
      Else { >= }
        EmitInstr('JGE    ' + LblSkip);
      EmitInstr('XOR    AX, AX');
      EmitInstr('JMP    ' + LblEnd);
      EmitLabel(LblSkip);
      EmitInstr('MOV    AX, 1');
      EmitLabel(LblEnd);
      Res.ModeIdx := TY_IDX_BOOL;
    End
    { SHL / SHR }
    Else If Op = 'SHL' Then
    Begin
      EmitInstr('MOV    CL, BL');
      EmitInstr('SAL    AX, CL');
    End
    Else If Op = 'SHR' Then
    Begin
      EmitInstr('MOV    CL, BL');
      EmitInstr('SAR    AX, CL');
    End
    { +* I : formation COMPL -> stub }
    Else If (Op = '+*') Or (Op = 'I') Then
    Begin
      WarnMsg('COMPL non supporte sur 8086, partie IM ignoree');
    End
    { AND bitwise (BITS mode - logique court-circuit traite plus haut) }
    Else If Op = 'AND' Then
      EmitInstr('AND    AX, BX')
    { OR bitwise (BITS mode - logique court-circuit traite plus haut) }
    Else If Op = 'OR' Then
      EmitInstr('OR     AX, BX')
    { ELEM : test de bit BX dans AX -> BOOL }
    Else If Op = 'ELEM' Then
    Begin
      EmitInstr('MOV    CL, BL');
      EmitInstr('SHR    AX, CL');
      EmitInstr('AND    AX, 1');
      Res.ModeIdx := TY_IDX_BOOL;
    End
    { UP DOWN : stubs }
    Else If (Op = 'UP') Or (Op = 'DOWN') Then
    Begin
      WarnMsg(Op + ' : stub, traite comme NOP');
    End
    { LWB : borne inferieure du descripteur de tableau }
    Else If Op = 'LWB' Then
    Begin
      EmitComment('LWB');
      EmitInstr('MOV    BX, AX');
      EmitInstr('MOV    AX, [BX]');
      Res.ModeIdx := TY_IDX_INT;
    End
    { UPB : borne superieure du descripteur de tableau }
    Else If Op = 'UPB' Then
    Begin
      EmitComment('UPB');
      EmitInstr('MOV    BX, AX');
      EmitInstr('MOV    AX, [BX+2]');
      Res.ModeIdx := TY_IDX_INT;
    End;

    Res.Kind := EK_AX;
  End; { While }
End;

{ ---- ParseExpr : point d entree pour une expression ---------- }
{ Appelle ParseFormula avec priorite minimale 1.
  Gere egalement les operateurs d affectation :
  := (becomes), =: (reverse assign),
  +:= (plusab), -:= (minusab), *:= (timesab), /:= (divab).     }

Procedure ParseExpr(Var Res : TExprVal);
Var
  AssignOp : TString;
  Rhs      : TExprVal;
  SIdx     : Integer;
  S        : TString;
  { TODO 17 }
  DestIdx  : Integer;
  IsLblRef : TString;
Begin
  ParseFormula(1, Res);

  { TODO 17 - Affectation de base := }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
  Begin
    { L operande gauche doit etre une lvalue (variable) }
    If (Res.Kind <> EK_MEM) Or (Res.SymIdx < 0) Then
    Begin
      CompileError('operande gauche de := doit etre une variable');
      ParserAdvance;
      ParseFormula(1, Rhs);
      Exit;
    End;
    SIdx := Res.SymIdx;
    ParserAdvance; { consommer := }
    ParseFormula(1, Rhs);
    ExprFlushToAX(Rhs);
    EmitComment('assign := to ' + SymTab[SIdx].Name);
    { Stocker dans la variable }
    If SymTab[SIdx].ScopeLevel = 0 Then
    Begin
      If (ModeKindOf(SymTab[SIdx].ModeIdx) = MK_BOOL) Or
         (ModeKindOf(SymTab[SIdx].ModeIdx) = MK_CHAR) Then
        EmitInstr('MOV    [' + SymTab[SIdx].MangledName + '], AL')
      Else If (SymTab[SIdx].ModeIdx >= 0) And
              (SymTab[SIdx].ModeIdx < ModeCount) And
              (ModeTab[SymTab[SIdx].ModeIdx].Kind = MK_STRUCT) Then
      Begin
        { Struct assignment : copier via REP MOVSW }
        EmitInstr('MOV    SI, AX');
        EmitInstr('MOV    DI, OFFSET ' + SymTab[SIdx].MangledName);
        Str(ModeTab[SymTab[SIdx].ModeIdx].Size Div 2, S);
        EmitInstr('MOV    CX, ' + S);
        EmitInstr('CLD');
        EmitInstr('REP MOVSW');
      End
      Else
        EmitInstr('MOV    [' + SymTab[SIdx].MangledName + '], AX');
    End
    Else
    Begin
      Str(SymTab[SIdx].Offset, S);
      If (SymTab[SIdx].ModeIdx >= 0) And
         (SymTab[SIdx].ModeIdx < ModeCount) And
         (ModeTab[SymTab[SIdx].ModeIdx].Kind = MK_STRUCT) Then
      Begin
        { Struct local : copier via REP MOVSW }
        EmitInstr('MOV    SI, AX');
        If SymTab[SIdx].Offset >= 0 Then
          EmitInstr('LEA    DI, [BP+' + S + ']')
        Else
          EmitInstr('LEA    DI, [BP' + S + ']');
        Str(ModeTab[SymTab[SIdx].ModeIdx].Size Div 2, S);
        EmitInstr('MOV    CX, ' + S);
        EmitInstr('CLD');
        EmitInstr('REP MOVSW');
      End
      Else If SymTab[SIdx].Offset >= 0 Then
        EmitInstr('MOV    [BP+' + S + '], AX')
      Else
        EmitInstr('MOV    [BP' + S + '], AX');
    End;
    Res.Kind := EK_AX;
  End
  { TODO 17 - Affectation inversee =: }
  Else If CurToken.Kind = TK_BUS Then
  Begin
    { expr_source =: dest }
    ExprFlushToAX(Res);
    EmitInstr('PUSH   AX');
    ParserAdvance; { consommer =: }
    { Lire la destination }
    ParseFormula(1, Rhs);
    If (Rhs.Kind <> EK_MEM) Or (Rhs.SymIdx < 0) Then
    Begin
      CompileError('operande droite de =: doit etre une variable');
      Exit;
    End;
    DestIdx := Rhs.SymIdx;
    EmitInstr('POP    AX');
    EmitComment('reverse assign =: to ' + SymTab[DestIdx].Name);
    If SymTab[DestIdx].ScopeLevel = 0 Then
      EmitInstr('MOV    [' + SymTab[DestIdx].MangledName + '], AX')
    Else
    Begin
      Str(SymTab[DestIdx].Offset, S);
      If SymTab[DestIdx].Offset >= 0 Then
        EmitInstr('MOV    [BP+' + S + '], AX')
      Else
        EmitInstr('MOV    [BP' + S + '], AX');
    End;
    Res.Kind := EK_AX;
  End
  { TODO 17 - IS / ISNT identity test }
  Else If (CurToken.Kind = TK_BOLD) And
          ((CurToken.Val = 'IS') Or (CurToken.Val = 'ISNT')) Then
  Begin
    IsLblRef := CurToken.Val;
    ExprFlushToAX(Res);
    EmitInstr('PUSH   AX');
    ParserAdvance; { consommer IS ou ISNT }
    ParseFormula(1, Rhs);
    ExprFlushToAX(Rhs);
    EmitInstr('POP    BX');
    EmitInstr('CMP    BX, AX');
    Inc(LabelGenSeq);
    Str(LabelGenSeq, S);
    If IsLblRef = 'IS' Then
    Begin
      EmitComment('IS identity test');
      EmitInstr('MOV    AX, 0');
      EmitInstr('JNE    _A68L_IS_' + S);
      EmitInstr('MOV    AX, 1');
      EmitLabel('_A68L_IS_' + S);
    End
    Else
    Begin
      EmitComment('ISNT identity test');
      EmitInstr('MOV    AX, 0');
      EmitInstr('JE     _A68L_ISNT_' + S);
      EmitInstr('MOV    AX, 1');
      EmitLabel('_A68L_ISNT_' + S);
    End;
    Res.Kind    := EK_AX;
    Res.ModeIdx := TY_IDX_BOOL;
    Res.SymIdx  := -1;
  End
  { Operateurs d affectation composes : +:= -:= *:= /:= }
  Else If (CurToken.Kind = TK_OP) And IsAssignOp(CurToken.Val) And
     (CurToken.Val <> ':=') Then
  Begin
    AssignOp := CurToken.Val;
    { L operande gauche doit etre une lvalue (variable) }
    If (Res.Kind <> EK_MEM) Or (Res.SymIdx < 0) Then
    Begin
      CompileError('operande gauche de ' + AssignOp +
                   ' doit etre une variable');
      ParserAdvance;
      ParseFormula(1, Rhs);
      Exit;
    End;
    SIdx := Res.SymIdx;
    { Charger la valeur actuelle de la variable }
    ExprFlushToAX(Res);
    EmitInstr('PUSH   AX');
    ParserAdvance; { consommer l operateur compose }
    ParseFormula(1, Rhs);
    ExprFlushToAX(Rhs);
    EmitInstr('MOV    BX, AX');
    EmitInstr('POP    AX');
    { Appliquer l operation }
    If AssignOp = '+:=' Then
      EmitInstr('ADD    AX, BX')
    Else If AssignOp = '-:=' Then
      EmitInstr('SUB    AX, BX')
    Else If AssignOp = '*:=' Then
      EmitInstr('IMUL   BX')
    Else If AssignOp = '/:=' Then
    Begin
      EmitInstr('CWD');
      EmitInstr('IDIV   BX');
    End;
    { Stocker le resultat dans la variable }
    If SymTab[SIdx].ScopeLevel = 0 Then
    Begin
      If (ModeKindOf(SymTab[SIdx].ModeIdx) = MK_BOOL) Or
         (ModeKindOf(SymTab[SIdx].ModeIdx) = MK_CHAR) Then
        EmitInstr('MOV    [' + SymTab[SIdx].MangledName + '], AL')
      Else
        EmitInstr('MOV    [' + SymTab[SIdx].MangledName + '], AX');
    End
    Else
    Begin
      Str(SymTab[SIdx].Offset, S);
      If SymTab[SIdx].Offset >= 0 Then
        EmitInstr('MOV    [BP+' + S + '], AX')
      Else
        EmitInstr('MOV    [BP' + S + '], AX');
    End;
    Res.Kind := EK_AX;
  End;
End;

{ ============================================================
  TODO 05 - TABLE DES SYMBOLES ET PORTEES [IMPLEMENTE]
  ============================================================ }

{ ---- SymNameClean : nettoyer un nom pour MASM --------------- }
{ Remplace tout caractere non alphanumerique par underscore.    }

Function SymNameClean(Const Name : TString) : TString;
Var
  I   : Integer;
  Res : TString;
  Ch  : Char;
Begin
  Res := '';
  For I := 1 To Length(Name) Do
  Begin
    Ch := Name[I];
    If ((Ch >= 'A') And (Ch <= 'Z')) Or
       ((Ch >= 'a') And (Ch <= 'z')) Or
       ((Ch >= '0') And (Ch <= '9')) Or
       (Ch = '_') Then
      Res := Res + Ch
    Else
      Res := Res + '_';
  End;
  SymNameClean := Res;
End;

{ ---- SymMangle : construire l etiquette ASM d un symbole ---- }
{ SC_IDENT  : identite (INT x = 42)      -> _A68V_ + name      }
{ SC_VAR    : variable (REF INT x := 42) -> _A68V_ + name      }
{ SC_PROC   : procedure                  -> _A68P_ + name      }
{ SC_OP     : operateur utilisateur       -> _A68O_ + name      }
{ SC_MODE   : declaration de mode         -> _A68M_ + name      }
{ SC_LABEL  : etiquette                   -> _A68L_ + name      }
{ SC_PARAM  : parametre formel            -> _A68V_ + name      }

Function SymMangle(Const Name : TString; Cat : TSymCat) : TString;
Var
  Clean : TString;
  Pfx   : TString;
Begin
  Clean := SymNameClean(Name);
  Case Cat Of
    SC_IDENT  : Pfx := A68_VAR_PFX;
    SC_VAR    : Pfx := A68_VAR_PFX;
    SC_PROC   : Pfx := A68_PROC_PFX;
    SC_OP     : Pfx := A68_OP_PFX;
    SC_MODE   : Pfx := A68_MODE_PFX;
    SC_LABEL  : Pfx := A68_LBL_PFX;
    SC_PARAM  : Pfx := A68_VAR_PFX;
  Else
    Pfx := A68_VAR_PFX;
  End;
  SymMangle := Pfx + Clean;
End;

{ ---- SymFind : chercher un symbole (plus recent d abord) ---- }
{ Parcourt la table du plus recent au plus ancien pour respecter }
{ la regle Algol 68 de visibilite dans la plus petite portee    }
{ englobante.  Retourne l index (0-base) ou -1.                 }

Function SymFind(Const Name : TString) : Integer;
Var
  I : Integer;
Begin
  For I := SymCount - 1 DownTo 0 Do
    If SymTab[I].Name = Name Then
    Begin
      SymFind := I;
      Exit;
    End;
  SymFind := -1;
End;

{ ---- SymFindInScope : chercher un symbole dans une portee --- }
{ Retourne l index du symbole de nom Name dans la portee Level, }
{ ou -1 si pas trouve.                                          }

Function SymFindInScope(Const Name : TString;
                        Level : Integer) : Integer;
Var
  I : Integer;
Begin
  For I := SymCount - 1 DownTo 0 Do
    If (SymTab[I].Name = Name) And
       (SymTab[I].ScopeLevel = Level) Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
  SymFindInScope := -1;
End;

{ ---- SymAdd : ajouter un symbole dans la table --------------- }
{ Retourne l index du nouveau symbole (0-base) ou -1 si plein.  }

Function SymAdd(Const Name : TString; Cat : TSymCat;
                ModeIdx, Offset : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    CompileError('table des symboles pleine (max=' +
                 IntToStr(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;
  Idx := SymCount;
  SymTab[Idx].Name        := Name;
  SymTab[Idx].MangledName := SymMangle(Name, Cat);
  SymTab[Idx].Cat         := Cat;
  SymTab[Idx].ModeIdx     := ModeIdx;
  SymTab[Idx].ScopeLevel  := CurScope;
  SymTab[Idx].Offset      := Offset;
  SymTab[Idx].IsParam     := (Cat = SC_PARAM);
  SymTab[Idx].IsHeap      := False;
  SymTab[Idx].IsConst     := (Cat = SC_IDENT);
  SymTab[Idx].DeclLine    := LexLineNo;
  Inc(SymCount);
  Inc(TotalSyms);

  If Opts.DebugMode Then
    WriteLn('  SYM_ADD[', Idx, ']: ', Name,
            ' cat=', Ord(Cat),
            ' mode=', ModeIdx,
            ' scope=', CurScope,
            ' -> ', SymTab[Idx].MangledName);

  SymAdd := Idx;
End;

{ ---- SymEnterScope : ouvrir une nouvelle portee ------------- }
{ Sauvegarde SymCount sur la pile de portees pour pouvoir       }
{ retirer les symboles locaux lors du SymLeaveScope.            }

Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
  Begin
    CompileError('imbrication de portees trop profonde (max=' +
                 IntToStr(MAX_SCOPE) + ')');
    Exit;
  End;
  ScopeStack[ScopeTop] := SymCount;
  Inc(ScopeTop);
  Inc(CurScope);
  If Opts.DebugMode Then
    WriteLn('  SCOPE_ENTER level=', CurScope,
            ' syms=', SymCount);
End;

{ ---- SymLeaveScope : quitter la portee courante ------------- }
{ Retire tous les symboles ajoutes dans cette portee en         }
{ restaurant SymCount depuis la pile.                            }

Procedure SymLeaveScope;
Begin
  If ScopeTop <= 0 Then
  Begin
    CompileError('desequilibre de portees : LeaveScope sans EnterScope');
    Exit;
  End;
  Dec(ScopeTop);
  SymCount := ScopeStack[ScopeTop];
  Dec(CurScope);
  If Opts.DebugMode Then
    WriteLn('  SCOPE_LEAVE level=', CurScope,
            ' syms=', SymCount);
End;

{ ---- SymNextOffset : prochain offset disponible pour locale -- }
{ Calcule [BP - 2*N] pour la prochaine variable locale.          }

Function SymNextOffset : Integer;
Var
  I, MaxOfs : Integer;
Begin
  MaxOfs := 0;
  For I := 0 To SymCount - 1 Do
    If (SymTab[I].ScopeLevel >= 1) And
       (Not SymTab[I].IsParam) And
       (SymTab[I].Offset < MaxOfs) Then
      MaxOfs := SymTab[I].Offset;
  { Prochain offset = MaxOfs - 2 (taille mot 16 bits par defaut ;
    le dimensionnement specifique par mode sera dans TODO 06) }
  SymNextOffset := MaxOfs - 2;
End;

{ ---- SymInit : initialiser la table et predeclarer ---------- }
{ Symboles standard Algol 68 :                                   }
{   I/O : print, read, newline, newpage, space, backspace        }
{   Operateurs : abs, odd, sign, repr, entier, round, leng,     }
{     shorten, bin, elem, level, re, im, conj, arg               }
{   Chaines : char in string, string in string                   }
{   Transput : put, get, open, close, associate, create           }
{   Math : sqrt, exp, ln, sin, cos, tan, arcsin, arccos, arctan  }
{   Divers : random, next random, whole repr, fixed repr,        }
{     float repr                                                  }

Procedure SymInit;
Begin
  SymCount    := 0;
  ScopeTop    := 0;
  CurScope    := 0;
  TotalSyms   := 0;

  { === Procedures d entree/sortie standard (transput) === }
  SymAdd('print',             SC_PROC, TY_IDX_VOID, 0);
  SymAdd('printf',            SC_PROC, TY_IDX_VOID, 0);
  SymAdd('read',              SC_PROC, TY_IDX_VOID, 0);
  SymAdd('readf',             SC_PROC, TY_IDX_VOID, 0);
  SymAdd('newline',           SC_PROC, TY_IDX_VOID, 0);
  SymAdd('newpage',           SC_PROC, TY_IDX_VOID, 0);
  SymAdd('space',             SC_PROC, TY_IDX_VOID, 0);
  SymAdd('backspace',         SC_PROC, TY_IDX_VOID, 0);

  { === Procedures de transput fichier === }
  SymAdd('put',               SC_PROC, TY_IDX_VOID, 0);
  SymAdd('get',               SC_PROC, TY_IDX_VOID, 0);
  SymAdd('open',              SC_PROC, TY_IDX_INT, 0);
  SymAdd('close',             SC_PROC, TY_IDX_VOID, 0);
  SymAdd('associate',         SC_PROC, TY_IDX_VOID, 0);
  SymAdd('create',            SC_PROC, TY_IDX_VOID, 0);
  SymAdd('establish',         SC_PROC, TY_IDX_VOID, 0);

  { === Operateurs standard (modes entiers) === }
  SymAdd('abs',               SC_PROC, TY_IDX_INT, 0);
  SymAdd('odd',               SC_PROC, TY_IDX_BOOL, 0);
  SymAdd('sign',              SC_PROC, TY_IDX_INT, 0);
  SymAdd('entier',            SC_PROC, TY_IDX_INT, 0);
  SymAdd('round',             SC_PROC, TY_IDX_INT, 0);
  SymAdd('repr',              SC_PROC, TY_IDX_CHAR, 0);
  SymAdd('leng',              SC_PROC, TY_IDX_INT, 0);
  SymAdd('shorten',           SC_PROC, TY_IDX_INT, 0);
  SymAdd('bin',               SC_PROC, TY_IDX_BITS, 0);
  SymAdd('elem',              SC_PROC, TY_IDX_BOOL, 0);
  SymAdd('level',             SC_PROC, TY_IDX_INT, 0);
  SymAdd('re',                SC_PROC, TY_IDX_REAL, 0);
  SymAdd('im',                SC_PROC, TY_IDX_REAL, 0);
  SymAdd('conj',              SC_PROC, TY_IDX_COMPL, 0);
  SymAdd('arg',               SC_PROC, TY_IDX_REAL, 0);

  { === Fonctions mathematiques === }
  SymAdd('sqrt',              SC_PROC, TY_IDX_REAL, 0);
  SymAdd('exp',               SC_PROC, TY_IDX_REAL, 0);
  SymAdd('ln',                SC_PROC, TY_IDX_REAL, 0);
  SymAdd('sin',               SC_PROC, TY_IDX_REAL, 0);
  SymAdd('cos',               SC_PROC, TY_IDX_REAL, 0);
  SymAdd('tan',               SC_PROC, TY_IDX_REAL, 0);
  SymAdd('arcsin',            SC_PROC, TY_IDX_REAL, 0);
  SymAdd('arccos',            SC_PROC, TY_IDX_REAL, 0);
  SymAdd('arctan',            SC_PROC, TY_IDX_REAL, 0);

  { === Procedures de conversion chaine === }
  SymAdd('whole',             SC_PROC, TY_IDX_STRING, 0);
  SymAdd('fixed',             SC_PROC, TY_IDX_STRING, 0);
  SymAdd('float',             SC_PROC, TY_IDX_STRING, 0);
  SymAdd('char in string',    SC_PROC, TY_IDX_BOOL, 0);
  SymAdd('string in string',  SC_PROC, TY_IDX_BOOL, 0);

  { === Constantes predefinies === }
  SymAdd('max int',           SC_IDENT, TY_IDX_INT, 0);
  SymAdd('max real',          SC_IDENT, TY_IDX_REAL, 0);
  SymAdd('small real',        SC_IDENT, TY_IDX_REAL, 0);
  SymAdd('max abs char',      SC_IDENT, TY_IDX_INT, 0);
  SymAdd('null character',    SC_IDENT, TY_IDX_CHAR, 0);
  SymAdd('blank',             SC_IDENT, TY_IDX_CHAR, 0);
  SymAdd('flip',              SC_IDENT, TY_IDX_CHAR, 0);
  SymAdd('flop',              SC_IDENT, TY_IDX_CHAR, 0);
  SymAdd('error char',        SC_IDENT, TY_IDX_CHAR, 0);
  SymAdd('pi',                SC_IDENT, TY_IDX_REAL, 0);

  { === Fichiers standard === }
  SymAdd('stand in',          SC_IDENT, TY_IDX_REF, 0);
  SymAdd('stand out',         SC_IDENT, TY_IDX_REF, 0);
  SymAdd('stand error',       SC_IDENT, TY_IDX_REF, 0);
  SymAdd('stand back',        SC_IDENT, TY_IDX_REF, 0);

  { === Divers === }
  SymAdd('random',            SC_PROC, TY_IDX_REAL, 0);
  SymAdd('next random',       SC_PROC, TY_IDX_REAL, 0);
  SymAdd('stop',              SC_PROC, TY_IDX_VOID, 0);
End;

{ ============================================================
  TODO 06 - SYSTEME DE MODES (TYPES) [IMPLEMENTE]
  ============================================================ }

{ ---- ModeInit : initialiser la table des modes primitifs ----- }
{ Enregistre les 10 modes primitifs d Algol 68 dans ModeTab     }
{ aux indices TY_IDX_INT..TY_IDX_BYTES.                         }

Procedure ModeInit;

  Procedure AddMode(Const AName : TString; AKind : TModeKind;
                    ASize : Integer; AElem : Integer);
  Begin
    If ModeCount >= MAX_MODE Then Exit;
    ModeTab[ModeCount].Name     := AName;
    ModeTab[ModeCount].Kind     := AKind;
    ModeTab[ModeCount].Size     := ASize;
    ModeTab[ModeCount].ElemIdx  := AElem;
    ModeTab[ModeCount].FieldCnt := 0;
    Inc(ModeCount);
  End;

Begin
  ModeCount := 0;
  { idx 0 } AddMode('INT',    MK_INT,     2, -1);
  { idx 1 } AddMode('REAL',   MK_REAL,    2, -1);
  { idx 2 } AddMode('BOOL',   MK_BOOL,    1, -1);
  { idx 3 } AddMode('CHAR',   MK_CHAR,    1, -1);
  { idx 4 } AddMode('BITS',   MK_BITS,    2, -1);
  { idx 5 } AddMode('STRING', MK_STRING,  2, -1);
  { idx 6 } AddMode('VOID',   MK_VOID,    0, -1);
  { idx 7 } AddMode('REF',    MK_REF,     2, -1);
  { idx 8 } AddMode('COMPL',  MK_COMPL,   4, -1);
  { idx 9 } AddMode('BYTES',  MK_BYTES,   2, -1);
End;

{ ---- ModeKindOf : retourner le TModeKind d un mode ---------- }
{ Retourne MK_UNKNOWN si l indice est hors de la table.         }

Function ModeKindOf(ModeIdx : Integer) : TModeKind;
Begin
  If (ModeIdx >= 0) And (ModeIdx < ModeCount) Then
    ModeKindOf := ModeTab[ModeIdx].Kind
  Else
    ModeKindOf := MK_UNKNOWN;
End;

{ ---- ModeSizeof : taille en octets d un mode ----------------- }
{ INT=2, REAL=2 (stub entier), BOOL=1, CHAR=1, BITS=2,          }
{ STRING=2 (ptr), VOID=0, REF=2 (ptr), COMPL=4, BYTES=2 (ptr), }
{ STRUCT/UNION/ROW/PROC -> 2 (ptr generique), UNKNOWN -> 2.     }

Function ModeSizeof(ModeIdx : Integer) : Integer;
Begin
  If (ModeIdx >= 0) And (ModeIdx < ModeCount) Then
    ModeSizeof := ModeTab[ModeIdx].Size
  Else
    ModeSizeof := 2;
End;

{ ---- ModeMangle : prefixe ASM pour un mode ------------------- }
{ Retourne un prefixe MASM pour generer des etiquettes de type :  }
{   INT/REAL/BITS/COMPL -> _A68N_ (numerique)                    }
{   BOOL               -> _A68B_ (booleen)                       }
{   CHAR/BYTES          -> _A68C_ (caractere)                    }
{   STRING             -> _A68S_ (chaine)                        }
{   VOID               -> _A68U_ (void/unit)                     }
{   REF/ROW/PROC       -> _A68R_ (reference)                     }
{   STRUCT             -> _A68T_ (structure)                      }
{   UNION              -> _A68W_ (union)                          }
{   UNKNOWN            -> _A68X_ (inconnu)                        }

Function ModeMangle(ModeIdx : Integer) : TString;
Var
  K : TModeKind;
Begin
  K := ModeKindOf(ModeIdx);
  Case K Of
    MK_INT     : ModeMangle := '_A68N_';
    MK_REAL    : ModeMangle := '_A68N_';
    MK_BOOL    : ModeMangle := '_A68B_';
    MK_CHAR    : ModeMangle := '_A68C_';
    MK_BITS    : ModeMangle := '_A68N_';
    MK_BYTES   : ModeMangle := '_A68C_';
    MK_COMPL   : ModeMangle := '_A68N_';
    MK_STRING  : ModeMangle := '_A68S_';
    MK_VOID    : ModeMangle := '_A68U_';
    MK_STRUCT  : ModeMangle := '_A68T_';
    MK_UNION   : ModeMangle := '_A68W_';
    MK_REF     : ModeMangle := '_A68R_';
    MK_PROC    : ModeMangle := '_A68R_';
    MK_ROW     : ModeMangle := '_A68R_';
  Else
    ModeMangle := '_A68X_';
  End;
End;

{ ---- ModeIsNumeric : vrai si le mode est numerique ----------- }
{ INT, REAL, BITS, COMPL, BOOL (coerci en INT) sont numeriques.  }

Function ModeIsNumeric(ModeIdx : Integer) : Boolean;
Var
  K : TModeKind;
Begin
  K := ModeKindOf(ModeIdx);
  ModeIsNumeric :=
    (K = MK_INT) Or (K = MK_REAL) Or (K = MK_BITS) Or
    (K = MK_COMPL) Or (K = MK_BOOL) Or (K = MK_CHAR);
End;

{ ---- ModeIsPtr : vrai si le mode est un pointeur ------------- }
{ STRING, ROW, REF, PROC, STRUCT, UNION, BYTES sont des ptrs.   }

Function ModeIsPtr(ModeIdx : Integer) : Boolean;
Var
  K : TModeKind;
Begin
  K := ModeKindOf(ModeIdx);
  ModeIsPtr :=
    (K = MK_STRING) Or (K = MK_ROW) Or (K = MK_REF) Or
    (K = MK_PROC) Or (K = MK_STRUCT) Or (K = MK_UNION) Or
    (K = MK_BYTES);
End;

{ ---- ModeCanCoerce : compatibilite de coercition ------------- }
{ Algol 68 a des coercitions implicites :                         }
{   meme mode -> OK                                               }
{   UNKNOWN -> tout : OK                                          }
{   INT -> REAL : widening                                        }
{   CHAR -> INT : widening                                        }
{   BOOL -> INT : widening (ABS)                                  }
{   INT -> BITS : reinterpretation (BIN)                          }
{   BITS -> INT : reinterpretation                                }
{   REF M -> M : dereferencing                                    }
{   tout -> VOID : voiding                                        }

Function ModeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean;
Var
  SK, DK : TModeKind;
Begin
  { Meme mode : toujours OK }
  If SrcIdx = DstIdx Then
  Begin
    ModeCanCoerce := True;
    Exit;
  End;
  { UNKNOWN -> tout : OK }
  If (SrcIdx = TY_IDX_UNKNOWN) Or (DstIdx = TY_IDX_UNKNOWN) Then
  Begin
    ModeCanCoerce := True;
    Exit;
  End;
  SK := ModeKindOf(SrcIdx);
  DK := ModeKindOf(DstIdx);
  { Tout -> VOID : voiding }
  If DK = MK_VOID Then
  Begin
    ModeCanCoerce := True;
    Exit;
  End;
  { INT -> REAL : widening }
  If (SK = MK_INT) And (DK = MK_REAL) Then
  Begin
    ModeCanCoerce := True;
    Exit;
  End;
  { REAL -> INT : narrowing (avec ENTIER/ROUND) }
  If (SK = MK_REAL) And (DK = MK_INT) Then
  Begin
    ModeCanCoerce := True;
    Exit;
  End;
  { CHAR -> INT : widening }
  If (SK = MK_CHAR) And (DK = MK_INT) Then
  Begin
    ModeCanCoerce := True;
    Exit;
  End;
  { INT -> CHAR : narrowing }
  If (SK = MK_INT) And (DK = MK_CHAR) Then
  Begin
    ModeCanCoerce := True;
    Exit;
  End;
  { BOOL -> INT : widening (ABS bool) }
  If (SK = MK_BOOL) And (DK = MK_INT) Then
  Begin
    ModeCanCoerce := True;
    Exit;
  End;
  { INT <-> BITS : reinterpretation (BIN) }
  If ((SK = MK_INT) And (DK = MK_BITS)) Or
     ((SK = MK_BITS) And (DK = MK_INT)) Then
  Begin
    ModeCanCoerce := True;
    Exit;
  End;
  { REF -> element : dereferencing }
  If SK = MK_REF Then
  Begin
    ModeCanCoerce := True;
    Exit;
  End;
  { CHAR -> STRING : rowing }
  If (SK = MK_CHAR) And (DK = MK_STRING) Then
  Begin
    ModeCanCoerce := True;
    Exit;
  End;
  { INT -> COMPL : widening (re part) }
  If (SK = MK_INT) And (DK = MK_COMPL) Then
  Begin
    ModeCanCoerce := True;
    Exit;
  End;
  { REAL -> COMPL : widening (re part) }
  If (SK = MK_REAL) And (DK = MK_COMPL) Then
  Begin
    ModeCanCoerce := True;
    Exit;
  End;
  ModeCanCoerce := False;
End;

{ ---- ModeCoerceResult : type resultat d une operation binaire  }
{ Determine le mode du resultat selon l operateur et les modes    }
{ des operandes gauche et droit.                                  }

Function ModeCoerceResult(LeftIdx, RightIdx : Integer;
                          Const Op : TString) : Integer;
Var
  LK, RK : TModeKind;
Begin
  LK := ModeKindOf(LeftIdx);
  RK := ModeKindOf(RightIdx);

  { Operateurs de comparaison et logiques -> BOOL }
  If (Op = '=')   Or (Op = '/=') Or (Op = '~=') Or
     (Op = '<')   Or (Op = '<=') Or
     (Op = '>')   Or (Op = '>=') Or
     (Op = 'AND') Or (Op = 'OR') Or (Op = '&') Or
     (Op = 'ANDTH') Or (Op = 'OREL') Then
  Begin
    ModeCoerceResult := TY_IDX_BOOL;
    Exit;
  End;

  { Operateurs sur les bits -> BITS }
  If (Op = 'SHL') Or (Op = 'SHR') Or
     (Op = 'ELEM') Or (Op = 'UP') Or (Op = 'DOWN') Then
  Begin
    If (LK = MK_BITS) Or (RK = MK_BITS) Then
      ModeCoerceResult := TY_IDX_BITS
    Else
      ModeCoerceResult := TY_IDX_INT;
    Exit;
  End;

  { LWB / UPB -> INT (borne de tableau) }
  If (Op = 'LWB') Or (Op = 'UPB') Then
  Begin
    ModeCoerceResult := TY_IDX_INT;
    Exit;
  End;

  { Concatenation + sur STRING -> STRING }
  If Op = '+' Then
  Begin
    If (LK = MK_STRING) Or (RK = MK_STRING) Then
    Begin
      ModeCoerceResult := TY_IDX_STRING;
      Exit;
    End;
  End;

  { Operateurs complexes +* et I -> COMPL }
  If (Op = '+*') Or (Op = 'I') Then
  Begin
    ModeCoerceResult := TY_IDX_COMPL;
    Exit;
  End;

  { Exponentiation ** -> type de la base }
  If Op = '**' Then
  Begin
    ModeCoerceResult := LeftIdx;
    Exit;
  End;

  { Affectation := +: = -:= *:= /:= -> type de la cible (gauche) }
  If (Op = ':=')  Or (Op = '+:=') Or (Op = '-:=') Or
     (Op = '*:=') Or (Op = '/:=') Then
  Begin
    ModeCoerceResult := LeftIdx;
    Exit;
  End;

  { Promotion arithmetique : COMPL > REAL > INT }
  If (LK = MK_COMPL) Or (RK = MK_COMPL) Then
  Begin
    ModeCoerceResult := TY_IDX_COMPL;
    Exit;
  End;
  If (LK = MK_REAL) Or (RK = MK_REAL) Then
  Begin
    ModeCoerceResult := TY_IDX_REAL;
    Exit;
  End;
  If (LK = MK_CHAR) And (RK = MK_CHAR) Then
  Begin
    ModeCoerceResult := TY_IDX_INT;
    Exit;
  End;
  If (LK = MK_BOOL) And (RK = MK_BOOL) Then
  Begin
    ModeCoerceResult := TY_IDX_INT;
    Exit;
  End;

  { Default : type de gauche }
  ModeCoerceResult := LeftIdx;
End;

{ ---- ModeInfer : deduire le mode d une expression ----------- }
{ EK_IMM -> INT, sinon : ModeIdx de l expression ou UNKNOWN.    }

Function ModeInfer(Const E : TExprVal) : Integer;
Begin
  If E.Kind = EK_IMM Then
    ModeInfer := TY_IDX_INT
  Else If E.ModeIdx >= 0 Then
    ModeInfer := E.ModeIdx
  Else
    ModeInfer := TY_IDX_UNKNOWN;
End;

{ ---- ModeLookupName : chercher un mode par nom --------------- }
{ Recherche case-insensitive dans ModeTab. Retourne l indice     }
{ (0-base) ou -1 si non trouve.                                  }

Function ModeLookupName(Const Name : TString) : Integer;
Var
  I, J   : Integer;
  Upper  : TString;
  TabUp  : TString;
Begin
  Upper := Name;
  For I := 1 To Length(Upper) Do
    If (Upper[I] >= 'a') And (Upper[I] <= 'z') Then
      Upper[I] := Chr(Ord(Upper[I]) - 32);
  For I := 0 To ModeCount - 1 Do
  Begin
    TabUp := ModeTab[I].Name;
    { Convertir aussi le nom du ModeTab en majuscules pour les
      modes utilisateur (minuscules possibles depuis TODO 16) }
    For J := 1 To Length(TabUp) Do
      If (TabUp[J] >= 'a') And (TabUp[J] <= 'z') Then
        TabUp[J] := Chr(Ord(TabUp[J]) - 32);
    If TabUp = Upper Then
    Begin
      ModeLookupName := I;
      Exit;
    End;
  End;
  ModeLookupName := -1;
End;

{ ---- ModeAddRow : creer ou retrouver un mode ROW pour ElemModeIdx -- }
Function ModeAddRow(ElemModeIdx : Integer) : Integer;
Var
  I : Integer;
  RowName : TString;
Begin
  { Verifier si un mode ROW pour cet element existe deja }
  For I := 0 To ModeCount - 1 Do
    If (ModeTab[I].Kind = MK_ROW) And (ModeTab[I].ElemIdx = ElemModeIdx) Then
    Begin
      ModeAddRow := I;
      Exit;
    End;
  { Creer un nouveau mode ROW }
  If ModeCount >= MAX_MODE Then
  Begin
    CompileError('table des modes pleine');
    ModeAddRow := -1;
    Exit;
  End;
  If (ElemModeIdx >= 0) And (ElemModeIdx < ModeCount) Then
    RowName := '[]' + ModeTab[ElemModeIdx].Name
  Else
    RowName := '[]?';
  I := ModeCount;
  ModeTab[I].Name     := RowName;
  ModeTab[I].Kind     := MK_ROW;
  ModeTab[I].Size     := 2;  { taille du pointeur vers le descripteur }
  ModeTab[I].ElemIdx  := ElemModeIdx;
  ModeTab[I].FieldCnt := 0;
  Inc(ModeCount);
  Inc(RowCount);
  ModeAddRow := I;
End;

{ ============================================================
  TODO 07 - COERCITIONS (COERCIONS) [IMPLEMENTE]
  Les 6 coercitions Algol 68 appliquees automatiquement.
  Ordre canonique : deref -> deproc -> widen -> row -> unite -> void
  ============================================================ }

{ ---- CoerceDeref : dereferencement (dereferencing) ----------- }
{ REF M -> M : suivre le pointeur dans AX                        }
{   MOV BX, AX        ; adresse du REF dans BX                   }
{   MOV AX, [BX]      ; charger la valeur pointee               }

Procedure CoerceDeref(SrcMode : Integer);
Begin
  If ModeKindOf(SrcMode) <> MK_REF Then Exit;
  EmitInstr('MOV    BX, AX');
  EmitInstr('MOV    AX, [BX]');
End;

{ ---- CoerceDeproc : deproceduration (deproceduring) ---------- }
{ PROC M -> M : appeler la procedure, resultat dans AX           }
{   CALL adresse_proc  ; la valeur revient dans AX               }

Procedure CoerceDeproc(SrcMode : Integer);
Begin
  If ModeKindOf(SrcMode) <> MK_PROC Then Exit;
  { AX contient l adresse de la procedure }
  EmitInstr('CALL   AX');
End;

{ ---- CoerceWiden : elargissement (widening) ------------------ }
{ INT -> REAL   : en 16 bits stub, NOP (meme representation)     }
{ CHAR -> INT   : XOR AH,AH (etendre octet a mot)              }
{ BOOL -> INT   : AND AX,1 (normaliser 0/1)                     }
{ INT -> COMPL  : PUSH 0 / PUSH AX (re=AX, im=0)              }
{ REAL -> COMPL : PUSH 0 / PUSH AX (re=AX, im=0)              }
{ INT -> BITS   : NOP (meme taille, reinterpretation)            }
{ BITS -> INT   : NOP (meme taille, reinterpretation)            }

Procedure CoerceWiden(SrcMode, DstMode : Integer);
Var
  SK, DK : TModeKind;
Begin
  SK := ModeKindOf(SrcMode);
  DK := ModeKindOf(DstMode);
  { CHAR -> INT : etendre octet bas a mot }
  If (SK = MK_CHAR) And (DK = MK_INT) Then
  Begin
    EmitInstr('XOR    AH, AH');
    Exit;
  End;
  { BOOL -> INT : normaliser a 0 ou 1 }
  If (SK = MK_BOOL) And (DK = MK_INT) Then
  Begin
    EmitInstr('AND    AX, 1');
    Exit;
  End;
  { INT -> COMPL ou REAL -> COMPL : pousser (re=AX, im=0) }
  If ((SK = MK_INT) Or (SK = MK_REAL)) And (DK = MK_COMPL) Then
  Begin
    EmitInstr('PUSH   AX');
    EmitInstr('XOR    AX, AX');
    EmitInstr('PUSH   AX');
    WarnMsg('widening to COMPL : re=AX, im=0 on stack');
    Exit;
  End;
  { INT -> REAL : NOP en stub 16 bits (meme representation) }
  If (SK = MK_INT) And (DK = MK_REAL) Then
    Exit;
  { REAL -> INT : NOP en stub 16 bits (deja un entier tronque) }
  If (SK = MK_REAL) And (DK = MK_INT) Then
    Exit;
  { INT <-> BITS : NOP (reinterpretation, meme taille) }
  If ((SK = MK_INT) And (DK = MK_BITS)) Or
     ((SK = MK_BITS) And (DK = MK_INT)) Then
    Exit;
  { INT -> CHAR : tronquer a l octet bas }
  If (SK = MK_INT) And (DK = MK_CHAR) Then
  Begin
    EmitInstr('AND    AX, 0FFh');
    Exit;
  End;
End;

{ ---- CoerceRow : mise en rangee (rowing) --------------------- }
{ M -> ROW M : creer un singleton array sur la pile               }
{   PUSH AX         ; element unique                              }
{   MOV AX, SP      ; AX = adresse du tableau sur la pile        }

Procedure CoerceRow(SrcMode : Integer);
Begin
  EmitInstr('PUSH   AX');
  EmitInstr('MOV    AX, SP');
End;

{ ---- CoerceUnite : unification (uniting) --------------------- }
{ M -> UNION(M,...) : encapsuler avec discriminant de mode        }
{   PUSH AX         ; valeur                                      }
{   MOV AX, disc    ; discriminant = index du mode source        }
{   PUSH AX         ; discriminant sur la pile                    }
{   MOV AX, SP      ; AX = adresse du bloc UNION                }

Procedure CoerceUnite(SrcMode, DstMode : Integer);
Begin
  EmitInstr('PUSH   AX');
  EmitInstr('MOV    AX, ' + IntToStr(SrcMode));
  EmitInstr('PUSH   AX');
  EmitInstr('MOV    AX, SP');
End;

{ ---- CoerceVoid : vidage (voiding) --------------------------- }
{ M -> VOID : ignorer la valeur dans AX                           }
{   (ne rien emettre, la valeur dans AX est simplement ignoree)  }

Procedure CoerceVoid;
Begin
  { Rien a emettre : la valeur dans AX est ignoree }
End;

{ ---- CoerceChain : chaine de coercitions --------------------- }
{ Applique les coercitions dans l ordre canonique Algol 68 :      }
{   1. Dereferencement (REF M -> M)                               }
{   2. Deproceduration (PROC M -> M)                              }
{   3. Elargissement (INT->REAL, CHAR->INT, BOOL->INT, ->COMPL) }
{   4. Mise en rangee (M -> ROW M)                                }
{   5. Unification (M -> UNION)                                   }
{   6. Vidage (M -> VOID)                                         }

Procedure CoerceChain(SrcMode, DstMode : Integer);
Var
  CurMode : Integer;
  SK, DK  : TModeKind;
Begin
  If SrcMode = DstMode Then Exit;
  If (SrcMode = TY_IDX_UNKNOWN) Or (DstMode = TY_IDX_UNKNOWN) Then Exit;
  CurMode := SrcMode;
  SK := ModeKindOf(CurMode);
  DK := ModeKindOf(DstMode);

  { 1. Dereferencement : REF M -> M }
  If SK = MK_REF Then
  Begin
    CoerceDeref(CurMode);
    { Apres deref, on suppose le mode element (INT par defaut) }
    If ModeTab[CurMode].ElemIdx >= 0 Then
      CurMode := ModeTab[CurMode].ElemIdx
    Else
      CurMode := TY_IDX_INT;
    SK := ModeKindOf(CurMode);
    If CurMode = DstMode Then Exit;
  End;

  { 2. Deproceduration : PROC M -> M }
  If SK = MK_PROC Then
  Begin
    CoerceDeproc(CurMode);
    If ModeTab[CurMode].ElemIdx >= 0 Then
      CurMode := ModeTab[CurMode].ElemIdx
    Else
      CurMode := TY_IDX_INT;
    SK := ModeKindOf(CurMode);
    If CurMode = DstMode Then Exit;
  End;

  { 3. Elargissement (widening) }
  If ModeCanCoerce(CurMode, DstMode) And (DK <> MK_VOID) And
     (DK <> MK_ROW) And (DK <> MK_UNION) Then
  Begin
    CoerceWiden(CurMode, DstMode);
    Exit;
  End;

  { 4. Mise en rangee (rowing) : M -> ROW M }
  If DK = MK_ROW Then
  Begin
    CoerceRow(CurMode);
    Exit;
  End;

  { 5. Unification (uniting) : M -> UNION }
  If DK = MK_UNION Then
  Begin
    CoerceUnite(CurMode, DstMode);
    Exit;
  End;

  { 6. Vidage (voiding) : M -> VOID }
  If DK = MK_VOID Then
  Begin
    CoerceVoid;
  End;
End;

{ ---- ApplyCoercion : point d entree principal ---------------- }
{ Applique la coercition de SrcMode vers DstMode.                 }
{ Verifie d abord si la coercition est possible, puis delegue    }
{ a CoerceChain pour appliquer la chaine canonique.               }

Procedure ApplyCoercion(SrcMode, DstMode : Integer);
Begin
  { Meme mode : rien a faire }
  If SrcMode = DstMode Then Exit;
  { UNKNOWN : pas de coercition possible }
  If (SrcMode = TY_IDX_UNKNOWN) Or (DstMode = TY_IDX_UNKNOWN) Then Exit;
  { Verifier la compatibilite }
  If Not ModeCanCoerce(SrcMode, DstMode) Then
  Begin
    WarnMsg('coercition impossible de mode ' + IntToStr(SrcMode) +
            ' vers mode ' + IntToStr(DstMode));
    Exit;
  End;
  CoerceChain(SrcMode, DstMode);
End;

{ ============================================================
  TODO 08 - EMETTEUR DE CODE ASM [IMPLEMENTE]
  ============================================================ }

{ LabelGen : generer un label unique _A68L_NNNNN }
Function LabelGen : TString;
Var
  S : TString;
Begin
  Inc(LabelGenSeq);
  Str(LabelGenSeq, S);
  LabelGen := A68_LBL_PFX + S;
End;

{ EmitRaw : ecrire une ligne brute dans le fichier de sortie }
Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, S);
End;

{ EmitBlankLine : ligne vide }
Procedure EmitBlankLine;
Begin
  If OutFOpen Then
    WriteLn(OutF);
End;

{ EmitComment : commentaire ASM '; texte' }
Procedure EmitComment(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '; ', S);
End;

{ EmitLabel : label ASM suivi de ':' en colonne 0 }
Procedure EmitLabel(Const Lbl : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, Lbl, ':');
End;

{ EmitInstr : instruction sans operandes (8 espaces d'indentation) }
Procedure EmitInstr(Const Mnem : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '        ', Mnem);
End;

{ EmitInstrA : instruction + un operande }
Procedure EmitInstrA(Const Mnem, A1 : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '        ', Mnem, '   ', A1);
End;

{ EmitInstrAB : instruction + deux operandes separes par ', ' }
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '        ', Mnem, '   ', A1, ', ', A2);
End;

{ EmitOpen : ouvrir le fichier de sortie ASM }
Procedure EmitOpen;
Begin
  {$I-}
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('impossible de creer le fichier: ' + Opts.OutFile);
  OutFOpen := True;
End;

{ EmitHeader : en-tete du fichier ASM (.MODEL SMALL, segment de code, point d entree) }
Procedure EmitHeader;
Begin
  EmitComment('Genere par AL68C86 v' + AL68_VERSION + ' - ' + Opts.SrcFile);
  EmitBlankLine;
  EmitRaw('        .MODEL SMALL');
  EmitRaw('        .STACK ' + IntToStr(STACK_SIZE));
  EmitBlankLine;
  EmitRaw('_TEXT   SEGMENT WORD PUBLIC ''CODE''');
  EmitRaw('        ASSUME  CS:_TEXT, DS:_DATA, SS:NOTHING');
  EmitBlankLine;
  EmitComment('--- point d''entree ---');
  EmitLabel(A68_PROC_PFX + 'main');
  EmitInstrAB('MOV', 'AX', '_DATA');
  EmitInstrAB('MOV', 'DS', 'AX');
  EmitBlankLine;
End;

{ EmitProlog : preambule de procedure (cadre BP) }
Procedure EmitProlog;
Begin
  EmitInstr('PUSH   BP');
  EmitInstr('MOV    BP, SP');
  If CurFrameSize > 0 Then
    EmitInstr('SUB    SP, ' + IntToStr(CurFrameSize * 2));
End;

{ EmitEpilog : epilogue de procedure (restaurer SP/BP et retourner) }
Procedure EmitEpilog;
Begin
  If CurProcRetLbl <> '' Then
    EmitLabel(CurProcRetLbl);
  If CurFrameSize > 0 Then
    EmitInstr('MOV    SP, BP');
  EmitInstr('POP    BP');
  EmitInstr('RET');
End;

{ DataAdd, DataAddStr, EmitDataSeg : implementes dans TODO 03 ci-dessus }

Procedure EmitRuntime;
Begin
  If RuntimeEmitted Then Exit;
  RuntimeEmitted := True;
  { Runtime: bounds check pour tableaux (TODO 18) }
  EmitBlankLine;
  EmitComment('--- runtime: row bounds check ---');
  EmitLabel(A68_RT_PFX + 'ROWCHK');
  { Entree: AX=index, BX=ptr descripteur }
  { Sortie: AX=index si OK, sinon arret }
  EmitInstr('CMP    AX, [BX]');
  EmitInstr('JL     ' + A68_RT_PFX + 'ROWFAIL');
  EmitInstr('CMP    AX, [BX+2]');
  EmitInstr('JG     ' + A68_RT_PFX + 'ROWFAIL');
  EmitInstr('RET');
  EmitLabel(A68_RT_PFX + 'ROWFAIL');
  EmitInstr('MOV    AX, 4C01h');
  EmitInstr('INT    21h');

  { Runtime: slice (tranche) pour tableaux }
  EmitBlankLine;
  EmitComment('--- runtime: row slice ---');
  EmitLabel(A68_RT_PFX + 'SLICE');
  { Entree: pile [SP+2]=desc_ptr, [SP+4]=lo, [SP+6]=up }
  EmitInstr('PUSH   BP');
  EmitInstr('MOV    BP, SP');
  EmitInstr('MOV    BX, [BP+4]');
  EmitInstr('MOV    AX, [BP+6]');
  EmitInstr('MOV    DI, OFFSET _A68_SLICEBUF');
  EmitInstr('MOV    [DI], AX');
  EmitInstr('MOV    AX, [BP+8]');
  EmitInstr('MOV    [DI+2], AX');
  EmitInstr('MOV    AX, [BX+4]');
  EmitInstr('MOV    [DI+4], AX');
  EmitInstr('MOV    AX, [BX+6]');
  EmitInstr('MOV    [DI+6], AX');
  EmitInstr('MOV    AX, DI');
  EmitInstr('POP    BP');
  EmitInstr('RET');
End;

{ EmitClose : terminaison du programme DOS et fermeture du fichier ASM }
Procedure EmitClose;
Begin
  EmitBlankLine;
  EmitComment('--- sortie DOS ---');
  EmitInstr('MOV    AX, 4C00h');
  EmitInstr('INT    21h');
  EmitBlankLine;
  { Emettre le runtime (TODO 24) }
  EmitRuntime;
  EmitBlankLine;
  EmitRaw('_TEXT   ENDS');
  EmitBlankLine;
  { Emettre le segment de donnees }
  EmitDataSeg;
  EmitBlankLine;
  EmitRaw('        END ' + A68_PROC_PFX + 'main');
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ============================================================
  TODO 10 - DECLARATIONS D IDENTITE ET DE VARIABLE [IMPLEMENTE]
  ============================================================ }

Procedure ParseDeclStmt;
{ Syntaxe Algol 68 supportee :
    INT x = 42;               (identite / constante)
    INT x := 42;              (variable locale abregee)
    REF INT p = x;            (reference / alias)
    REF INT x = LOC INT := 42; (variable LOC explicite)
    HEAP INT x;               (allocation dynamique)
    INT a = 1, b = 2;         (declarations multiples)
  Le token courant est le premier mot de la declaration :
    un mode (INT/BOOL/CHAR/REAL/STRING/BITS/BYTES/COMPL/VOID)
    ou REF / LOC / HEAP.                                        }
Var
  MIdx      : Integer;   { indice du mode declare            }
  SIdx      : Integer;   { indice du symbole cree            }
  DIdx      : Integer;   { indice DataTab pour globales      }
  OfsVal    : Integer;   { offset [BP-n] pour variable locale }
  IsRef     : Boolean;   { REF explicite                     }
  IsLoc     : Boolean;   { LOC explicite dans initialiseur   }
  IsHeap    : Boolean;   { HEAP                              }
  IsVar     : Boolean;   { vrai si := (variable, pas identite) }
  Name      : TString;   { nom de l identificateur           }
  Res       : TExprVal;  { valeur de l initialiseur          }
  S         : TString;   { chaine temporaire                 }
  Done      : Boolean;   { fin de la liste de declarations   }
  InnerMode : Integer;   { mode apres LOC/HEAP               }
  IsStructMode : Boolean; { vrai si le mode est MK_STRUCT     }
  HasInit   : Boolean;   { vrai si un initialiseur est present }
  { TODO 18 - tableaux }
  IsRow     : Boolean;   { vrai si declaration de tableau     }
  RowLwb    : Integer;   { borne inferieure                  }
  RowUpb    : Integer;   { borne superieure                  }
  RowElemSz : Integer;   { taille element                    }
  RowMIdx   : Integer;   { mode ROW cree                     }
  DescLbl   : TString;   { label du descripteur              }
  DataLbl   : TString;   { label du bloc de donnees          }
  RowLwbRes : TExprVal;  { expression borne inferieure       }
  RowUpbRes : TExprVal;  { expression borne superieure       }
  RowNElem  : Integer;   { nombre d elements                 }
  RowI      : Integer;   { compteur init tableau             }
  ArgRes    : TExprVal;  { expression element init           }
Begin
  { --- 0. Detecter les bornes de tableau [lwb:upb] ---- }
  IsRow  := False;
  RowLwb := 1;
  RowUpb := 0;

  If CurToken.Kind = TK_SUB Then
  Begin
    { Syntaxe : [lwb:upb] MODE name }
    IsRow := True;
    ParserAdvance; { consomme [ }
    { Lire lwb }
    ParseExpr(RowLwbRes);
    If RowLwbRes.Kind = EK_IMM Then
      RowLwb := RowLwbRes.ImmVal
    Else
    Begin
      ExprFlushToAX(RowLwbRes);
      RowLwb := 1;
    End;
    If CurToken.Kind = TK_COLON Then
      ParserAdvance;  { consomme : }
    { Lire upb }
    ParseExpr(RowUpbRes);
    If RowUpbRes.Kind = EK_IMM Then
      RowUpb := RowUpbRes.ImmVal
    Else
    Begin
      ExprFlushToAX(RowUpbRes);
      RowUpb := RowLwb;
    End;
    If CurToken.Kind = TK_BUS2 Then
      ParserAdvance;  { consomme ] }
  End;

  { --- 1. Detecter REF / LOC / HEAP en tete ---- }
  IsRef  := False;
  IsLoc  := False;
  IsHeap := False;
  MIdx   := -1;

  If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'REF') Then
  Begin
    IsRef := True;
    ParserAdvance;  { consomme REF }
  End
  Else If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'LOC') Then
  Begin
    IsLoc := True;
    ParserAdvance;  { consomme LOC }
  End
  Else If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'HEAP') Then
  Begin
    IsHeap := True;
    ParserAdvance;  { consomme HEAP }
  End;

  { --- 2. Lire le mode (INT, BOOL, CHAR, ...) ---- }
  If CurToken.Kind = TK_BOLD Then
  Begin
    MIdx := ModeLookupName(CurToken.Val);
    If MIdx >= 0 Then
      ParserAdvance   { consomme le nom de mode }
    Else
    Begin
      CompileError('mode inconnu : ' + CurToken.Val);
      ParserAdvance;
      Exit;
    End;
  End
  Else If CurToken.Kind = TK_IDENT Then
  Begin
    { Mode utilisateur (TODO 16) ou alias - essayer de le trouver }
    MIdx := ModeLookupName(CurToken.Val);
    If MIdx >= 0 Then
      ParserAdvance
    Else
    Begin
      CompileError('mode attendu, obtenu : ' + CurToken.Val);
      ParserAdvance;
      Exit;
    End;
  End
  Else
  Begin
    CompileError('mode attendu dans declaration');
    Exit;
  End;

  { Si c est un tableau, creer un mode ROW pour le mode element }
  If IsRow And (MIdx >= 0) Then
  Begin
    RowElemSz := ModeSizeof(MIdx);
    RowMIdx := ModeAddRow(MIdx);
    RowNElem := RowUpb - RowLwb + 1;
    If RowNElem < 0 Then RowNElem := 0;
  End
  Else
  Begin
    RowElemSz := 2;
    RowMIdx := -1;
    RowNElem := 0;
  End;

  { Si REF explicite, le mode effectif est une reference a MIdx.
    Note : le mode de base est perdu ici (simplification TODO 10).
    Une implementation complete creerait un mode REF(base) dans ModeTab. }
  If IsRef Then
    MIdx := TY_IDX_REF;

  { --- 3. Boucle sur les declarations multiples (a = 1, b = 2) --- }
  Done := False;
  While Not Done Do
  Begin
    { --- 3a. Lire l identificateur ---- }
    If CurToken.Kind <> TK_IDENT Then
    Begin
      CompileError('identificateur attendu dans declaration');
      Exit;
    End;
    Name := CurToken.Val;
    ParserAdvance;  { consomme l identificateur }

    { --- 3b. Operateur = (identite) ou := (variable) ---- }
    IsVar := False;
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    Begin
      IsVar := True;
      ParserAdvance;  { consomme := }
    End
    Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
    Begin
      IsVar := False;
      ParserAdvance;  { consomme = }
    End
    Else
    Begin
      { Pas d initialiseur explicite pour HEAP/ROW decl }
      If IsHeap Or IsLoc Or IsRow Then
      Begin
        { HEAP INT x; ou LOC INT x; ou [1:n] INT x; sans initialiseur }
        IsVar := True;
      End
      Else
      Begin
        CompileError('= ou := attendu apres identificateur ' + Name);
        Exit;
      End;
    End;

    { --- 3c. Detecter LOC/HEAP dans le membre droit ---- }
    { Ex: REF INT x = LOC INT := 42; }
    If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'LOC') Then
    Begin
      IsLoc := True;
      IsVar := True;
      ParserAdvance;  { consomme LOC }
      { Optionnel : mode apres LOC - utilise pour la taille d allocation.
        Remplace MIdx par le mode de base (intentionnel pour REF INT = LOC INT) }
      If CurToken.Kind = TK_BOLD Then
      Begin
        InnerMode := ModeLookupName(CurToken.Val);
        If InnerMode >= 0 Then
        Begin
          MIdx := InnerMode;
          ParserAdvance;
        End;
      End;
      { Optionnel : := apres LOC INT }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
        ParserAdvance;
    End
    Else If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'HEAP') Then
    Begin
      IsHeap := True;
      IsVar  := True;
      ParserAdvance;  { consomme HEAP }
      If CurToken.Kind = TK_BOLD Then
      Begin
        InnerMode := ModeLookupName(CurToken.Val);
        If InnerMode >= 0 Then
        Begin
          MIdx := InnerMode;
          ParserAdvance;
        End;
      End;
      If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
        ParserAdvance;
    End;

    { --- 3d. Generer le code ---- }
    EmitComment('decl ' + Name + ' : mode=' + IntToStr(MIdx));

    { === Gestion des tableaux (TODO 18) === }
    If IsRow And (RowMIdx >= 0) Then
    Begin
      EmitComment('row decl [' + IntToStr(RowLwb) + ':' +
                  IntToStr(RowUpb) + '] ' + Name);
      If CurScope >= 1 Then
      Begin
        { Tableau local : descripteur + donnees sur la pile }
        { Allouer l espace pour les donnees (RowNElem * RowElemSz) }
        If RowNElem > 0 Then
        Begin
          Str(RowNElem * RowElemSz, S);
          EmitInstr('SUB    SP, ' + S);
          Inc(CurFrameSize, RowNElem * RowElemSz);
        End;
        { Allouer 8 octets pour le descripteur }
        EmitInstr('SUB    SP, 8');
        Inc(CurFrameSize, 8);
        OfsVal := SymNextOffset;
        { Remplir le descripteur sur la pile }
        If OfsVal >= 0 Then S := '+' + IntToStr(OfsVal)
        Else S := IntToStr(OfsVal);
        EmitInstr('MOV    WORD PTR [BP' + S + '], ' +
                  IntToStr(RowLwb));
        If OfsVal + 2 >= 0 Then S := '+' + IntToStr(OfsVal + 2)
        Else S := IntToStr(OfsVal + 2);
        EmitInstr('MOV    WORD PTR [BP' + S + '], ' +
                  IntToStr(RowUpb));
        If OfsVal + 4 >= 0 Then S := '+' + IntToStr(OfsVal + 4)
        Else S := IntToStr(OfsVal + 4);
        EmitInstr('MOV    WORD PTR [BP' + S + '], ' +
                  IntToStr(RowElemSz));
        { Pointeur vers les donnees = BP + OfsVal + 8 }
        If OfsVal + 8 >= 0 Then S := '+' + IntToStr(OfsVal + 8)
        Else S := IntToStr(OfsVal + 8);
        EmitInstr('LEA    AX, [BP' + S + ']');
        If OfsVal + 6 >= 0 Then S := '+' + IntToStr(OfsVal + 6)
        Else S := IntToStr(OfsVal + 6);
        EmitInstr('MOV    [BP' + S + '], AX');
        { Enregistrer le symbole avec le mode ROW }
        SIdx := SymAdd(Name, SC_VAR, RowMIdx, OfsVal);
        { AX = adresse du descripteur pour l initialiseur }
        If OfsVal >= 0 Then S := '+' + IntToStr(OfsVal)
        Else S := IntToStr(OfsVal);
        EmitInstr('LEA    AX, [BP' + S + ']');
      End
      Else
      Begin
        { Tableau global : descripteur + donnees dans DATA }
        DataLbl := A68_ARR_PFX + SymNameClean(Name) + '_D';
        DescLbl := A68_ARR_PFX + SymNameClean(Name);
        { Ajouter le bloc de donnees (RowNElem mots) }
        DIdx := DataAddStruct(DataLbl, RowNElem);
        { Ajouter le descripteur }
        DIdx := DataAddArrayDesc(DescLbl, RowLwb, RowUpb,
                                 RowElemSz, DataLbl);
        SIdx := SymAdd(Name, SC_VAR, RowMIdx, 0);
        { Forcer le MangledName vers le descripteur de tableau }
        If SIdx >= 0 Then
          SymTab[SIdx].MangledName := DescLbl;
        { AX = OFFSET descripteur }
        EmitInstr('MOV    AX, OFFSET ' + DescLbl);
      End;

      { Lire l initialiseur si present : (v1, v2, ...) }
      HasInit := False;
      If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
      Begin
        HasInit := True;
        ParserAdvance;  { consomme := }
      End
      Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
      Begin
        HasInit := True;
        ParserAdvance;  { consomme = }
      End;

      If (CurToken.Kind = TK_OPEN) Then
      Begin
        { Constructeur de rangee (v1, v2, ...) }
        EmitInstr('PUSH   AX');  { sauver adresse descripteur }
        ParserAdvance; { consomme ( }
        RowI := 0;
        While (CurToken.Kind <> TK_CLOSE) And
              (CurToken.Kind <> TK_EOF) Do
        Begin
          ParseExpr(ArgRes);
          ExprFlushToAX(ArgRes);
          { Stocker dans le bloc de donnees }
          If CurScope >= 1 Then
          Begin
            EmitInstr('POP    BX');
            EmitInstr('PUSH   BX');
            EmitInstr('MOV    BX, [BX+6]'); { data_ptr }
            Str(RowI * RowElemSz, S);
            If RowElemSz = 1 Then
              EmitInstr('MOV    BYTE PTR [BX+' + S + '], AL')
            Else
              EmitInstr('MOV    [BX+' + S + '], AX');
          End
          Else
          Begin
            Str(RowI * RowElemSz, S);
            If RowElemSz = 1 Then
              EmitInstr('MOV    BYTE PTR [' + DataLbl + '+' + S + '], AL')
            Else
              EmitInstr('MOV    [' + DataLbl + '+' + S + '], AX');
          End;
          Inc(RowI);
          If CurToken.Kind = TK_COMMA Then
            ParserAdvance;
        End;
        If CurToken.Kind = TK_CLOSE Then
          ParserAdvance;
        EmitInstr('POP    AX'); { restaurer adresse descripteur }
      End;
    End
    Else If IsHeap Then
    Begin
      { HEAP : allocation dynamique }
      { Charger la taille du mode dans CX puis appeler alloc }
      Str(ModeSizeof(MIdx), S);
      EmitInstr('MOV    CX, ' + S);
      EmitInstr('CALL   ' + A68_RT_PFX + 'ALLOC');
      { AX = pointeur vers la zone allouee }

      { Lire l initialiseur si present, sinon initialiser a 0 }
      If (CurToken.Kind <> TK_SEMI) And (CurToken.Kind <> TK_COMMA) And
         (CurToken.Kind <> TK_EOF) Then
      Begin
        EmitInstr('PUSH   AX');        { sauvegarder le pointeur }
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstr('MOV    BX, AX');    { BX = valeur init }
        EmitInstr('POP    AX');        { AX = pointeur }
        EmitInstr('MOV    [AX], BX');  { stocker valeur }
      End
      Else
      Begin
        { Pas d initialiseur : initialiser a 0 }
        EmitInstr('MOV    WORD PTR [AX], 0');
      End;

      { Enregistrer dans la table des symboles }
      If CurScope >= 1 Then
      Begin
        OfsVal := SymNextOffset;
        SIdx := SymAdd(Name, SC_VAR, MIdx, OfsVal);
        If SIdx >= 0 Then
          SymTab[SIdx].IsHeap := True;
        Str(OfsVal, S);
        EmitInstr('MOV    [BP' + S + '], AX');
      End
      Else
      Begin
        DIdx := DataAddGlobalVar(Name, TY_IDX_REF);
        SIdx := SymAdd(Name, SC_VAR, MIdx, 0);
        If SIdx >= 0 Then
        Begin
          SymTab[SIdx].IsHeap := True;
          EmitInstr('MOV    [' + SymTab[SIdx].MangledName + '], AX');
        End;
      End;
    End
    Else If IsVar Or IsLoc Then
    Begin
      { Variable locale ou avec LOC explicite }
      { Determiner si c est un struct }
      IsStructMode := (MIdx >= 0) And (MIdx < ModeCount) And
                      (ModeTab[MIdx].Kind = MK_STRUCT);
      HasInit := (CurToken.Kind <> TK_SEMI) And
                 (CurToken.Kind <> TK_COMMA) And
                 (CurToken.Kind <> TK_EOF);
      { Lire l initialiseur }
      If HasInit Then
      Begin
        ParseExpr(Res);
        ExprFlushToAX(Res);
      End
      Else
      Begin
        { Pas d initialiseur : valeur par defaut 0 }
        EmitInstr('XOR    AX, AX');
      End;

      If CurScope >= 1 Then
      Begin
        { Variable locale : allouer sur la pile }
        OfsVal := SymNextOffset;
        { Pour les structures, ajuster l offset selon la taille }
        If (MIdx >= 0) And (MIdx < ModeCount) And
           (ModeTab[MIdx].Kind = MK_STRUCT) And
           (ModeTab[MIdx].Size > 2) Then
          OfsVal := OfsVal - ModeTab[MIdx].Size + 2;
        SIdx := SymAdd(Name, SC_VAR, MIdx, OfsVal);
        EmitInstr('SUB    SP, ' + IntToStr(ModeSizeof(MIdx)));
        Str(OfsVal, S);
        If IsStructMode Then
        Begin
          If HasInit Then
          Begin
            { Struct : AX contient l adresse source, copier les donnees }
            EmitComment('struct copy ' + ModeTab[MIdx].Name +
                        ' size=' + IntToStr(ModeTab[MIdx].Size));
            EmitInstr('MOV    SI, AX');       { SI = source }
            If OfsVal >= 0 Then
              EmitInstr('LEA    DI, [BP+' + S + ']')
            Else
              EmitInstr('LEA    DI, [BP' + S + ']');
            Str(ModeTab[MIdx].Size Div 2, S);
            EmitInstr('MOV    CX, ' + S);   { nombre de mots }
            EmitInstr('CLD');
            EmitInstr('REP MOVSW');
          End
          Else
          Begin
            { Struct sans initialiseur : mettre a zero }
            EmitComment('struct zero ' + ModeTab[MIdx].Name);
            If OfsVal >= 0 Then
              EmitInstr('LEA    DI, [BP+' + S + ']')
            Else
              EmitInstr('LEA    DI, [BP' + S + ']');
            Str(ModeTab[MIdx].Size Div 2, S);
            EmitInstr('MOV    CX, ' + S);
            EmitInstr('XOR    AX, AX');
            EmitInstr('CLD');
            EmitInstr('REP STOSW');
          End;
        End
        Else If ModeSizeof(MIdx) = 1 Then
          EmitInstr('MOV    BYTE PTR [BP' + S + '], AL')
        Else
          EmitInstr('MOV    [BP' + S + '], AX');
        Inc(CurFrameSize, ModeSizeof(MIdx));
      End
      Else
      Begin
        { Variable globale : stocker dans DATA segment }
        If IsStructMode Then
        Begin
          DIdx := DataAddStruct(A68_VAR_PFX + Name,
                                ModeTab[MIdx].Size Div 2);
          SIdx := SymAdd(Name, SC_VAR, MIdx, 0);
          If (SIdx >= 0) And HasInit Then
          Begin
            EmitComment('global struct ' + Name +
                        ' init, size=' +
                        IntToStr(ModeTab[MIdx].Size));
            EmitInstr('MOV    SI, AX');
            EmitInstr('MOV    DI, OFFSET ' +
                      SymTab[SIdx].MangledName);
            Str(ModeTab[MIdx].Size Div 2, S);
            EmitInstr('MOV    CX, ' + S);
            EmitInstr('CLD');
            EmitInstr('REP MOVSW');
          End;
        End
        Else
        Begin
          DIdx := DataAddGlobalVar(Name, MIdx);
          SIdx := SymAdd(Name, SC_VAR, MIdx, 0);
          If SIdx >= 0 Then
            EmitInstr('MOV    [' + SymTab[SIdx].MangledName + '], AX');
        End;
      End;
    End
    Else
    Begin
      { Identite (constante) : INT x = 42 }
      { Lire l initialiseur }
      ParseExpr(Res);
      ExprFlushToAX(Res);

      If CurScope >= 1 Then
      Begin
        { Identite locale : allouer sur la pile (immutable) }
        OfsVal := SymNextOffset;
        SIdx := SymAdd(Name, SC_IDENT, MIdx, OfsVal);
        EmitInstr('SUB    SP, ' + IntToStr(ModeSizeof(MIdx)));
        Str(OfsVal, S);
        If ModeSizeof(MIdx) = 1 Then
          EmitInstr('MOV    BYTE PTR [BP' + S + '], AL')
        Else
          EmitInstr('MOV    [BP' + S + '], AX');
        Inc(CurFrameSize, ModeSizeof(MIdx));
      End
      Else
      Begin
        { Identite globale : stocker dans DATA segment }
        DIdx := DataAddGlobalVar(Name, MIdx);
        SIdx := SymAdd(Name, SC_IDENT, MIdx, 0);
        If SIdx >= 0 Then
          EmitInstr('MOV    [' + SymTab[SIdx].MangledName + '], AX');
      End;
    End;

    { --- 3e. Virgule -> declaration suivante, sinon fin ---- }
    If CurToken.Kind = TK_COMMA Then
    Begin
      ParserAdvance;  { consomme , }
      { Continuer la boucle }
    End
    Else
      Done := True;
  End; { While Not Done }

  { --- 4. Point-virgule de fin ---- }
  If CurToken.Kind = TK_SEMI Then
    ParserAdvance  { consomme ; }
  Else
    { En Algol 68, le ; est optionnel avant END }
    If Not ((CurToken.Kind = TK_BOLD) And
            ((CurToken.Val = 'END') Or (CurToken.Val = 'FI') Or
             (CurToken.Val = 'OD') Or (CurToken.Val = 'ESAC'))) Then
      WarnMsg('; attendu apres declaration');
End;

{ ParsePrimary, ParseExpr, ExprFlushToAX : implementes dans TODO 04 ci-dessus }

Procedure ParseSerialClause(Var Res : TExprVal);
Var
  WasDecl   : Boolean;
  SavedTok  : TToken;
  LblSym    : Integer;
Begin
  ExprMakeNone(Res);
  While (CurToken.Kind <> TK_EOF) Do
  Begin
    { Check for closing delimiters }
    If (CurToken.Kind = TK_BOLD) And
       ((CurToken.Val = 'END') Or (CurToken.Val = 'FI') Or
        (CurToken.Val = 'OD') Or (CurToken.Val = 'ESAC') Or
        (CurToken.Val = 'ELSE') Or (CurToken.Val = 'ELIF') Or
        (CurToken.Val = 'THEN') Or (CurToken.Val = 'IN') Or
        (CurToken.Val = 'OUT') Or (CurToken.Val = 'DO') Or
        (CurToken.Val = 'OUSE')) Then
      Break;
    If CurToken.Kind = TK_CLOSE Then
      Break;

    WasDecl := False;

    { Check for label definition : ident followed by : }
    If CurToken.Kind = TK_IDENT Then
    Begin
      SavedTok := CurToken;
      ParserAdvance;
      If CurToken.Kind = TK_COLON Then
      Begin
        { Label definition }
        ParserAdvance; { consomme : }
        EmitLabel(A68_LBL_PFX + SavedTok.Val);
        LblSym := SymAdd(SavedTok.Val, SC_LABEL, -1, 0);
        WasDecl := True;
        { Continue to next unit }
      End
      Else
      Begin
        { Not a label - push back current token and restore ident }
        PushedToken := CurToken;
        HasPushedToken := True;
        CurToken := SavedTok;
        ParseExpr(Res);
      End;
    End
    Else
    { Try declaration or expression }
    If (CurToken.Kind = TK_BOLD) And
       ((CurToken.Val = 'INT') Or (CurToken.Val = 'REAL') Or
        (CurToken.Val = 'BOOL') Or (CurToken.Val = 'CHAR') Or
        (CurToken.Val = 'STRING') Or (CurToken.Val = 'BITS') Or
        (CurToken.Val = 'BYTES') Or (CurToken.Val = 'COMPL') Or
        (CurToken.Val = 'VOID') Or
        (CurToken.Val = 'REF') Or (CurToken.Val = 'LOC') Or
        (CurToken.Val = 'HEAP')) Then
    Begin
      ParseDeclStmt;
      WasDecl := True;
    End
    Else If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'PROC') Then
    Begin
      ParserAdvance; { consomme PROC }
      ParseProcDecl;
      WasDecl := True;
    End
    Else If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'MODE') Then
    Begin
      ParseModeDecl;
      WasDecl := True;
    End
    Else
      ParseExpr(Res);

    { ParseDeclStmt already consumes its trailing semicolon }
    If Not WasDecl Then
    Begin
      If CurToken.Kind = TK_SEMI Then
        ParserAdvance
      Else
        Break;
    End;
  End;
End;

Procedure ParseIfClause(Var Res : TExprVal);
Var
  LblElse, LblEnd : TString;
  CondRes : TExprVal;
  MyIf    : Integer;
Begin
  { IF deja vu ou consomme par l'appelant pour ELIF }
  ParserAdvance; { consomme IF ou ELIF }
  Inc(IfCount);
  MyIf := IfCount;

  { Parse condition }
  ParseExpr(CondRes);
  ExprFlushToAX(CondRes);

  LblElse := A68_LBL_PFX + 'ELSE_' + IntToStr(MyIf);
  LblEnd  := A68_LBL_PFX + 'FI_' + IntToStr(MyIf);

  EmitInstr('TEST   AX, AX');
  EmitInstr('JZ     ' + LblElse);

  { THEN clause }
  If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'THEN') Then
    ParserAdvance
  Else
    CompileError('THEN attendu');

  ParseSerialClause(Res);
  ExprFlushToAX(Res);

  EmitInstr('JMP    ' + LblEnd);

  { ELSE / ELIF / FI }
  EmitLabel(LblElse);

  If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'ELIF') Then
  Begin
    { ELIF -> recursive IF }
    ParseIfClause(Res);
    { ELIF chain ends with FI consumed by deepest call }
  End
  Else If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'ELSE') Then
  Begin
    ParserAdvance; { consomme ELSE }
    ParseSerialClause(Res);
    ExprFlushToAX(Res);
    If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'FI') Then
      ParserAdvance
    Else
      CompileError('FI attendu');
  End
  Else If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'FI') Then
  Begin
    { No ELSE branch }
    ExprMakeVoid(Res);
    ParserAdvance; { consomme FI }
  End
  Else
    CompileError('ELSE, ELIF ou FI attendu');

  EmitLabel(LblEnd);
  If Res.Kind <> EK_NONE Then
  Begin
    Res.Kind   := EK_AX;
    Res.SymIdx := -1;
  End;
End;

Procedure ParseCaseClause(Var Res : TExprVal);
Var
  SelRes     : TExprVal;
  CaseRes    : TExprVal;
  LblEnd     : TString;
  LblNext    : TString;
  CaseIdx    : Integer;
  CaseS      : TString;
  MyCase     : Integer;
Begin
  ParserAdvance; { consomme CASE }
  Inc(CaseCount);
  MyCase := CaseCount;

  { Parse selector expression }
  ParseExpr(SelRes);
  ExprFlushToAX(SelRes);
  EmitInstr('MOV    BX, AX');

  LblEnd := A68_LBL_PFX + 'CESAC_' + IntToStr(MyCase);

  { IN clause }
  If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'IN') Then
    ParserAdvance
  Else
    CompileError('IN attendu');

  CaseIdx := 1; { Algol 68 : CASE indices commencent a 1 }
  ExprMakeNone(Res);

  { Parse comma-separated case values, indexing from 1 }
  While (CurToken.Kind <> TK_EOF) Do
  Begin
    If (CurToken.Kind = TK_BOLD) And
       ((CurToken.Val = 'OUT') Or (CurToken.Val = 'ESAC') Or
        (CurToken.Val = 'OUSE')) Then
      Break;

    LblNext := A68_LBL_PFX + 'CASE_' + IntToStr(MyCase)
               + '_' + IntToStr(CaseIdx);

    Str(CaseIdx, CaseS);
    EmitInstr('CMP    BX, ' + CaseS);
    EmitInstr('JNE    ' + LblNext);

    ParseSerialClause(CaseRes);
    ExprFlushToAX(CaseRes);
    Res := CaseRes;
    EmitInstr('JMP    ' + LblEnd);

    EmitLabel(LblNext);
    Inc(CaseIdx);

    If CurToken.Kind = TK_COMMA Then
      ParserAdvance
    Else
      Break;
  End;

  { OUSE clause : CASE chain (like ELIF for IF) }
  If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'OUSE') Then
  Begin
    ParserAdvance; { consomme OUSE }
    Inc(CaseCount);
    { Parse new selector }
    ParseExpr(SelRes);
    ExprFlushToAX(SelRes);
    EmitInstr('MOV    BX, AX');

    If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'IN') Then
      ParserAdvance
    Else
      CompileError('IN attendu apres OUSE');

    CaseIdx := 1;
    While (CurToken.Kind <> TK_EOF) Do
    Begin
      If (CurToken.Kind = TK_BOLD) And
         ((CurToken.Val = 'OUT') Or (CurToken.Val = 'ESAC') Or
          (CurToken.Val = 'OUSE')) Then
        Break;

      LblNext := A68_LBL_PFX + 'CASE_' + IntToStr(CaseCount)
                 + '_' + IntToStr(CaseIdx);

      Str(CaseIdx, CaseS);
      EmitInstr('CMP    BX, ' + CaseS);
      EmitInstr('JNE    ' + LblNext);

      ParseSerialClause(CaseRes);
      ExprFlushToAX(CaseRes);
      Res := CaseRes;
      EmitInstr('JMP    ' + LblEnd);

      EmitLabel(LblNext);
      Inc(CaseIdx);

      If CurToken.Kind = TK_COMMA Then
        ParserAdvance
      Else
        Break;
    End;
  End;

  { OUT clause (default) }
  If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'OUT') Then
  Begin
    ParserAdvance; { consomme OUT }
    ParseSerialClause(CaseRes);
    ExprFlushToAX(CaseRes);
    Res := CaseRes;
  End;

  { ESAC }
  If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'ESAC') Then
    ParserAdvance
  Else
    CompileError('ESAC attendu');

  EmitLabel(LblEnd);
  If Res.Kind <> EK_NONE Then
  Begin
    Res.Kind   := EK_AX;
    Res.SymIdx := -1;
  End;
End;

{ ============================================================
  TODO 15 - CLAUSES REPETITIVES (BOUCLES)
  ============================================================
  FOR id FROM debut TO fin BY pas WHILE cond DO unites OD
  Tous les mots-cles sauf DO/OD sont optionnels.
  FOR id : variable de boucle locale, mode INT, non modifiable.
  FROM debut : valeur initiale (defaut 1).
  TO fin : borne superieure (si absent, boucle infinie).
  DOWNTO n : equivalent a BY -1 TO n.
  BY pas : increment (defaut 1, negatif autorise).
  WHILE cond : condition testee a chaque iteration avant DO.
  DO unites OD : corps de la boucle.
  Boucle infinie : DO ... OD (sans FOR/TO/WHILE).
  Labels : _A68L_LTEST_N, _A68L_LINCR_N, _A68L_LEND_N       }

Procedure ParseLoopClause(Var Res : TExprVal);
Var
  HasFor, HasTo, HasWhile, IsDown : Boolean;
  LoopVarName : TString;
  LoopVarOfs, LimOfs : Integer;
  LoopVarSym  : Integer;
  InitRes, LimRes, StepRes, CondRes, BodyRes : TExprVal;
  LblTest, LblIncr, LblEnd : TString;
  MyLoop      : Integer;
  S, S2       : TString;
  StepVal     : LongInt;
  OldFrameSize: Integer;
  AllocCount  : Integer;
Begin
  Inc(LoopCount);
  MyLoop := LoopCount;

  LblTest := A68_LBL_PFX + 'LTEST_' + IntToStr(MyLoop);
  LblIncr := A68_LBL_PFX + 'LINCR_' + IntToStr(MyLoop);
  LblEnd  := A68_LBL_PFX + 'LEND_'  + IntToStr(MyLoop);

  { Empiler le contexte de boucle pour les boucles imbriquees }
  If LoopTop < MAX_LOOP_NEST Then
  Begin
    LoopBreakLbl[LoopTop] := LblEnd;
    LoopContLbl[LoopTop]  := LblIncr;
    Inc(LoopTop);
  End;

  HasFor   := False;
  HasTo    := False;
  HasWhile := False;
  IsDown   := False;
  LoopVarName := '';
  LoopVarSym  := -1;
  LoopVarOfs  := 0;
  LimOfs      := 0;
  StepVal     := 1;
  AllocCount  := 0;
  OldFrameSize := CurFrameSize;

  SymEnterScope;

  { ---- FOR identificateur ---- }
  If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'FOR') Then
  Begin
    HasFor := True;
    ParserAdvance; { consomme FOR }
    If CurToken.Kind = TK_IDENT Then
    Begin
      LoopVarName := CurToken.Val;
      ParserAdvance; { consomme l identificateur }
    End
    Else
      CompileError('identificateur attendu apres FOR');
  End;

  { ---- FROM init (defaut 1) ---- }
  If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'FROM') Then
  Begin
    ParserAdvance; { consomme FROM }
    ParseExpr(InitRes);
  End
  Else
    ExprMakeImm(1, TY_IDX_INT, InitRes);

  { ---- Allouer et stocker la variable de boucle ---- }
  If HasFor Then
  Begin
    ExprFlushToAX(InitRes);
    LoopVarOfs := SymNextOffset;
    LoopVarSym := SymAdd(LoopVarName, SC_IDENT, TY_IDX_INT, LoopVarOfs);
    SymTab[LoopVarSym].IsConst := True;
    EmitInstr('SUB    SP, 2');
    Str(LoopVarOfs, S);
    EmitInstr('MOV    WORD PTR [BP' + S + '], AX');
    Inc(CurFrameSize, 2);
    Inc(AllocCount);
  End;

  { ---- TO limite ou DOWNTO limite ---- }
  If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'TO') Then
  Begin
    HasTo := True;
    ParserAdvance; { consomme TO }
    ParseExpr(LimRes);
    ExprFlushToAX(LimRes);
    LimOfs := SymNextOffset;
    SymAdd('_lim' + IntToStr(MyLoop), SC_VAR, TY_IDX_INT, LimOfs);
    EmitInstr('SUB    SP, 2');
    Str(LimOfs, S);
    EmitInstr('MOV    WORD PTR [BP' + S + '], AX');
    Inc(CurFrameSize, 2);
    Inc(AllocCount);
  End
  Else If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'DOWNTO') Then
  Begin
    HasTo  := True;
    IsDown := True;
    StepVal := -1;
    ParserAdvance; { consomme DOWNTO }
    ParseExpr(LimRes);
    ExprFlushToAX(LimRes);
    LimOfs := SymNextOffset;
    SymAdd('_lim' + IntToStr(MyLoop), SC_VAR, TY_IDX_INT, LimOfs);
    EmitInstr('SUB    SP, 2');
    Str(LimOfs, S);
    EmitInstr('MOV    WORD PTR [BP' + S + '], AX');
    Inc(CurFrameSize, 2);
    Inc(AllocCount);
  End;

  { ---- BY pas (defaut 1, ou -1 si DOWNTO) ---- }
  If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'BY') Then
  Begin
    ParserAdvance; { consomme BY }
    ParseExpr(StepRes);
    If StepRes.Kind = EK_IMM Then
      StepVal := StepRes.ImmVal;
  End;

  { ---- Emettre le label de test ---- }
  EmitLabel(LblTest);

  { ---- Comparaison TO ---- }
  If HasTo And HasFor Then
  Begin
    Str(LoopVarOfs, S);
    EmitInstr('MOV    AX, WORD PTR [BP' + S + ']');
    Str(LimOfs, S2);
    EmitInstr('CMP    AX, WORD PTR [BP' + S2 + ']');
    If IsDown Or (StepVal < 0) Then
      EmitInstr('JL     ' + LblEnd)
    Else
      EmitInstr('JG     ' + LblEnd);
  End;

  { ---- WHILE condition ---- }
  If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'WHILE') Then
  Begin
    HasWhile := True;
    ParserAdvance; { consomme WHILE }
    ParseExpr(CondRes);
    ExprFlushToAX(CondRes);
    EmitInstr('TEST   AX, AX');
    EmitInstr('JZ     ' + LblEnd);
  End;

  { ---- DO ... OD ---- }
  If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'DO') Then
    ParserAdvance { consomme DO }
  Else
    CompileError('DO attendu');

  { Corps de la boucle }
  ParseSerialClause(BodyRes);

  If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'OD') Then
    ParserAdvance { consomme OD }
  Else
    CompileError('OD attendu');

  { ---- Increment ---- }
  EmitLabel(LblIncr);
  If HasFor Then
  Begin
    Str(LoopVarOfs, S);
    EmitInstr('MOV    AX, WORD PTR [BP' + S + ']');
    Str(StepVal, S2);
    EmitInstr('ADD    AX, ' + S2);
    EmitInstr('MOV    WORD PTR [BP' + S + '], AX');
  End;
  EmitInstr('JMP    ' + LblTest);

  { ---- Fin de boucle ---- }
  EmitLabel(LblEnd);

  { Desallouer les variables locales de la boucle }
  If AllocCount > 0 Then
  Begin
    Str(AllocCount * 2, S);
    EmitInstr('ADD    SP, ' + S);
  End;

  { Depiler le contexte de boucle }
  If LoopTop > 0 Then
    Dec(LoopTop);

  CurFrameSize := OldFrameSize;
  SymLeaveScope;

  ExprMakeVoid(Res);
End;

{ ============================================================
  TODO 16 - STRUCTURES (STRUCT) [IMPLEMENTE]
  ============================================================ }

{ ---- StructFieldLookup : chercher un champ dans un mode struct - }
{ Retourne l indice dans StructFieldTab, ou -1 si non trouve.      }

Function StructFieldLookup(ModeIdx : Integer;
                           Const FieldName : TString) : Integer;
Var
  I, First, Count : Integer;
  Upper, TabUp    : TString;
Begin
  StructFieldLookup := -1;
  If (ModeIdx < 0) Or (ModeIdx >= ModeCount) Then Exit;
  If ModeTab[ModeIdx].Kind <> MK_STRUCT Then Exit;
  First := ModeTab[ModeIdx].ElemIdx;
  Count := ModeTab[ModeIdx].FieldCnt;
  Upper := FieldName;
  For I := 1 To Length(Upper) Do
    If (Upper[I] >= 'A') And (Upper[I] <= 'Z') Then
      Upper[I] := Chr(Ord(Upper[I]) + 32);
  For I := First To First + Count - 1 Do
  Begin
    If I >= StructFieldCount Then Exit;
    TabUp := StructFieldTab[I].Name;
    { Comparaison insensible a la casse }
    If TabUp = Upper Then
    Begin
      StructFieldLookup := I;
      Exit;
    End;
  End;
End;

{ ---- ParseStructDecl : parser STRUCT(champs) et creer le mode -- }
{ Syntaxe : STRUCT ( MODE champ , MODE champ , ... )               }
{ Appele apres que STRUCT ait ete consomme.                        }
{ Retourne l indice du nouveau mode dans ModeTab (via StructDecl). }

Procedure ParseStructDecl;
Begin
  { La vraie logique est dans ParseModeDecl }
End;

{ ---- ParseModeDecl : parser MODE nom = STRUCT(...) ------------- }
{ Syntaxe :                                                         }
{   MODE POINT = STRUCT ( INT x , INT y ) ;                         }
{   MODE ALIAS = INT ;                                              }
{ Le token courant est MODE quand on entre ici.                     }

Procedure ParseModeDecl;
Var
  ModeName   : TString;
  NewMIdx    : Integer;
  FieldStart : Integer;
  FieldCnt   : Integer;
  TotalSize  : Integer;
  FldModeName: TString;
  FldMIdx    : Integer;
  FldName    : TString;
  FldOfs     : Integer;
  AliasMIdx  : Integer;
Begin
  ParserAdvance;  { consomme MODE }

  { Lire le nom du mode }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('identificateur attendu apres MODE');
    Exit;
  End;
  ModeName := CurToken.Val;
  ParserAdvance;

  { Attendre = }
  If Not ((CurToken.Kind = TK_OP) And (CurToken.Val = '=')) Then
  Begin
    CompileError('= attendu apres MODE ' + ModeName);
    Exit;
  End;
  ParserAdvance;  { consomme = }

  { STRUCT(...) ou alias de mode }
  If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'STRUCT') Then
  Begin
    ParserAdvance;  { consomme STRUCT }

    { Attendre ( }
    If CurToken.Kind <> TK_OPEN Then
    Begin
      CompileError('( attendu apres STRUCT');
      Exit;
    End;
    ParserAdvance;  { consomme ( }

    FieldStart := StructFieldCount;
    FieldCnt   := 0;
    TotalSize  := 0;

    { Parser la liste de champs : MODE nom , MODE nom , ... }
    While (CurToken.Kind <> TK_CLOSE) And
          (CurToken.Kind <> TK_EOF) Do
    Begin
      { Lire le mode du champ }
      FldMIdx := -1;
      If CurToken.Kind = TK_BOLD Then
      Begin
        FldMIdx := ModeLookupName(CurToken.Val);
        If FldMIdx < 0 Then
        Begin
          CompileError('mode inconnu dans STRUCT : ' + CurToken.Val);
          Exit;
        End;
        ParserAdvance;
      End
      Else If CurToken.Kind = TK_IDENT Then
      Begin
        FldMIdx := ModeLookupName(CurToken.Val);
        If FldMIdx < 0 Then
        Begin
          CompileError('mode inconnu dans STRUCT : ' + CurToken.Val);
          Exit;
        End;
        ParserAdvance;
      End
      Else
      Begin
        CompileError('mode attendu dans STRUCT, obtenu : ' + CurToken.Val);
        Exit;
      End;

      { Lire le nom du champ }
      If CurToken.Kind <> TK_IDENT Then
      Begin
        CompileError('nom de champ attendu dans STRUCT');
        Exit;
      End;
      FldName := CurToken.Val;
      ParserAdvance;

      { Ajouter le champ dans StructFieldTab }
      If StructFieldCount >= MAX_STRUCT_FIELDS Then
      Begin
        CompileError('trop de champs de structure (max=' +
                     IntToStr(MAX_STRUCT_FIELDS) + ')');
        Exit;
      End;
      { Stocker le nom en minuscules pour la comparaison }
      FldOfs := TotalSize;
      StructFieldTab[StructFieldCount].Name    := FldName;
      StructFieldTab[StructFieldCount].ModeIdx := FldMIdx;
      StructFieldTab[StructFieldCount].Offset  := FldOfs;
      Inc(StructFieldCount);
      Inc(FieldCnt);
      TotalSize := TotalSize + ModeSizeof(FldMIdx);

      { Virgule entre les champs }
      If CurToken.Kind = TK_COMMA Then
        ParserAdvance
      Else If CurToken.Kind <> TK_CLOSE Then
      Begin
        CompileError(', ou ) attendu dans STRUCT');
        Exit;
      End;
    End;

    { Consommer ) }
    If CurToken.Kind = TK_CLOSE Then
      ParserAdvance;

    { Creer le mode dans ModeTab }
    If ModeCount >= MAX_MODE Then
    Begin
      CompileError('table des modes pleine (max=' +
                   IntToStr(MAX_MODE) + ')');
      Exit;
    End;
    { Arrondir la taille au mot superieur (pair) pour REP MOVSW }
    If (TotalSize > 0) And ((TotalSize Mod 2) <> 0) Then
      Inc(TotalSize);
    NewMIdx := ModeCount;
    ModeTab[NewMIdx].Name     := ModeName;
    ModeTab[NewMIdx].Kind     := MK_STRUCT;
    ModeTab[NewMIdx].Size     := TotalSize;
    ModeTab[NewMIdx].ElemIdx  := FieldStart;
    ModeTab[NewMIdx].FieldCnt := FieldCnt;
    Inc(ModeCount);
    Inc(StructCount);

    EmitComment('MODE ' + ModeName + ' = STRUCT, size=' +
                IntToStr(TotalSize) + ', fields=' +
                IntToStr(FieldCnt));

    If Opts.DebugMode Then
      WriteLn('  MODE_ADD[', NewMIdx, ']: ', ModeName,
              ' STRUCT size=', TotalSize, ' fields=', FieldCnt);
  End
  Else
  Begin
    { Alias de mode : MODE ALIAS = ExistingMode }
    AliasMIdx := -1;
    If CurToken.Kind = TK_BOLD Then
    Begin
      AliasMIdx := ModeLookupName(CurToken.Val);
      ParserAdvance;
    End
    Else If CurToken.Kind = TK_IDENT Then
    Begin
      AliasMIdx := ModeLookupName(CurToken.Val);
      ParserAdvance;
    End;
    If AliasMIdx < 0 Then
    Begin
      CompileError('mode ou STRUCT attendu apres = dans MODE');
      Exit;
    End;
    { Creer un alias dans ModeTab }
    If ModeCount >= MAX_MODE Then
    Begin
      CompileError('table des modes pleine');
      Exit;
    End;
    NewMIdx := ModeCount;
    ModeTab[NewMIdx].Name     := ModeName;
    ModeTab[NewMIdx].Kind     := ModeTab[AliasMIdx].Kind;
    ModeTab[NewMIdx].Size     := ModeTab[AliasMIdx].Size;
    ModeTab[NewMIdx].ElemIdx  := ModeTab[AliasMIdx].ElemIdx;
    ModeTab[NewMIdx].FieldCnt := ModeTab[AliasMIdx].FieldCnt;
    Inc(ModeCount);
    EmitComment('MODE ' + ModeName + ' = alias for ' +
                ModeTab[AliasMIdx].Name);
  End;

  { Optionnel : consommer le ; final }
  If CurToken.Kind = TK_SEMI Then
    ParserAdvance;
End;

{ ============================================================
  TODO 17 - REFERENCES ET AFFECTATIONS [IMPLEMENTE]
  ============================================================ }

Procedure ParseAssignment;
{ L affectation standalone est geree dans ParseExpr.
  Cette procedure est pour les cas speciaux ou on veut
  forcer un contexte d affectation. }
Var
  Res : TExprVal;
Begin
  ParseExpr(Res);
End;

Procedure ParseRowDecl;
{ Appele pour MODE name = [] TYPE dans ParseModeDecl.
  Cree un mode ROW pour le type element indique. }
Var
  ElemMode : Integer;
  RowMode  : Integer;
Begin
  { Attend [ deja consomme dans ParseModeDecl ou appel direct }
  { Consommer ] si present }
  If CurToken.Kind = TK_SUB Then
    ParserAdvance;  { consomme [ }
  If CurToken.Kind = TK_BUS2 Then
    ParserAdvance;  { consomme ] }
  { Lire le mode element }
  If CurToken.Kind = TK_BOLD Then
  Begin
    ElemMode := ModeLookupName(CurToken.Val);
    If ElemMode >= 0 Then
      ParserAdvance
    Else
    Begin
      CompileError('mode element attendu dans ROW');
      Exit;
    End;
  End
  Else
  Begin
    CompileError('mode element attendu dans ROW');
    Exit;
  End;
  RowMode := ModeAddRow(ElemMode);
  { Le mode ROW est maintenant enregistre dans ModeTab }
  If RowMode < 0 Then
    CompileError('impossible de creer le mode ROW');
End;

Procedure ParseProcDecl;
{ Syntaxe Algol 68 :
    PROC nom = (MODE p1, MODE p2, ...) RETMODE : corps ;
    PROC nom = () VOID : corps ;
  Le mot PROC est deja consomme par l appelant.
  Convention d appel : arguments pousses gauche-a-droite.
    arg1 -> [BP+4+2*(nparams-1)]
    arg2 -> [BP+4+2*(nparams-2)]
    ...
    argN -> [BP+4]
  Valeur de retour dans AX. }
Var
  ProcNameStr     : TString;
  RetModeIdx      : Integer;
  ParamCnt        : Integer;
  ParamNames      : Array[0..MAX_PARAM - 1] Of TString;
  ParamModes      : Array[0..MAX_PARAM - 1] Of Integer;
  ParamIsRef      : Array[0..MAX_PARAM - 1] Of Boolean;
  SavedFrameSize  : Integer;
  SavedProcRetLbl : TString;
  SavedProcName   : TString;
  SavedProcDepth  : Integer;
  SkipLbl         : TString;
  RetLbl          : TString;
  BodyRes         : TExprVal;
  I, SIdx, PIdx   : Integer;
  S               : TString;
  ProcMName       : TString;
  PModeIdx        : Integer;
  MyProc          : Integer;
Begin
  { --- 1. Lire le nom de la procedure --- }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('identificateur attendu apres PROC');
    Exit;
  End;
  ProcNameStr := CurToken.Val;
  ParserAdvance; { consomme le nom }

  { --- 2. Attend = --- }
  If (CurToken.Kind <> TK_OP) Or (CurToken.Val <> '=') Then
  Begin
    CompileError('"=" attendu dans declaration PROC');
    Exit;
  End;
  ParserAdvance; { consomme = }

  { --- 3. Parser la liste de parametres (MODE nom, ...) --- }
  ParamCnt := 0;
  If CurToken.Kind = TK_OPEN Then
  Begin
    ParserAdvance; { consomme ( }
    While (CurToken.Kind <> TK_CLOSE) And
          (CurToken.Kind <> TK_EOF) Do
    Begin
      If ParamCnt >= MAX_PARAM Then
      Begin
        CompileError('trop de parametres (max=' +
                     IntToStr(MAX_PARAM) + ')');
        Break;
      End;
      { Mode optionnel REF }
      ParamIsRef[ParamCnt] := False;
      If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'REF') Then
      Begin
        ParamIsRef[ParamCnt] := True;
        ParserAdvance;
      End;
      { Lire le mode du parametre }
      PModeIdx := -1;
      If CurToken.Kind = TK_BOLD Then
      Begin
        PModeIdx := ModeLookupName(CurToken.Val);
        If PModeIdx < 0 Then
        Begin
          CompileError('mode inconnu: ' + CurToken.Val);
          PModeIdx := TY_IDX_INT;
        End;
        ParserAdvance;
      End
      Else If CurToken.Kind = TK_IDENT Then
      Begin
        PModeIdx := ModeLookupName(CurToken.Val);
        If PModeIdx < 0 Then
          PModeIdx := TY_IDX_INT;
        ParserAdvance;
      End
      Else
      Begin
        CompileError('mode attendu dans parametres de PROC');
        Break;
      End;
      ParamModes[ParamCnt] := PModeIdx;
      { Lire le nom du parametre }
      If CurToken.Kind = TK_IDENT Then
      Begin
        ParamNames[ParamCnt] := CurToken.Val;
        ParserAdvance;
      End
      Else
      Begin
        CompileError('identificateur attendu pour parametre');
        Break;
      End;
      Inc(ParamCnt);
      { Virgule -> parametre suivant }
      If CurToken.Kind = TK_COMMA Then
        ParserAdvance;
    End;
    If CurToken.Kind = TK_CLOSE Then
      ParserAdvance; { consomme ) }
  End;

  { --- 4. Lire le mode de retour --- }
  RetModeIdx := TY_IDX_VOID;
  If CurToken.Kind = TK_BOLD Then
  Begin
    RetModeIdx := ModeLookupName(CurToken.Val);
    If RetModeIdx < 0 Then
      RetModeIdx := TY_IDX_VOID;
    ParserAdvance;
  End
  Else If CurToken.Kind = TK_IDENT Then
  Begin
    RetModeIdx := ModeLookupName(CurToken.Val);
    If RetModeIdx < 0 Then
      RetModeIdx := TY_IDX_INT;
    ParserAdvance;
  End;

  { --- 5. Attend : avant le corps --- }
  If CurToken.Kind = TK_COLON Then
    ParserAdvance
  Else
    CompileError('":" attendu avant le corps de PROC');

  { --- 6. Enregistrer le symbole PROC (avant le corps pour recursion) --- }
  Inc(ProcCount);
  MyProc := ProcCount;
  SIdx := SymAdd(ProcNameStr, SC_PROC, RetModeIdx, 0);
  If SIdx < 0 Then Exit;
  ProcMName := SymTab[SIdx].MangledName;

  { --- 7. Emettre le saut par-dessus le corps --- }
  SkipLbl := A68_LBL_PFX + 'PSKIP_' + IntToStr(MyProc);
  EmitInstr('JMP    ' + SkipLbl);

  { --- 8. Emettre le label et le prologue --- }
  EmitBlankLine;
  EmitComment('PROC ' + ProcNameStr);
  EmitLabel(ProcMName);

  { Sauvegarder l etat du contexte englobant }
  SavedFrameSize  := CurFrameSize;
  SavedProcRetLbl := CurProcRetLbl;
  SavedProcName   := CurProcName;
  SavedProcDepth  := CurProcDepth;

  CurFrameSize := 0;
  CurProcName  := ProcNameStr;
  Inc(CurProcDepth);
  RetLbl := A68_LBL_PFX + 'PRET_' + IntToStr(MyProc);
  CurProcRetLbl := RetLbl;

  { Prologue }
  EmitInstr('PUSH   BP');
  EmitInstr('MOV    BP, SP');

  { --- 9. Entrer dans la portee et enregistrer les parametres --- }
  SymEnterScope;
  { Parametres : pousses gauche-a-droite par l appelant.
    Premier param (idx 0) se retrouve a [BP + 4 + 2*(n-1)],
    dernier param (idx n-1) a [BP + 4]. }
  For I := 0 To ParamCnt - 1 Do
  Begin
    PIdx := SymAdd(ParamNames[I], SC_PARAM, ParamModes[I],
                   4 + 2 * (ParamCnt - 1 - I));
  End;

  { --- 10. Parser le corps --- }
  { Le corps peut etre une expression simple ou un bloc BEGIN...END }
  ParseExpr(BodyRes);
  ExprFlushToAX(BodyRes);

  { --- 11. Epilogue --- }
  EmitLabel(RetLbl);
  EmitInstr('MOV    SP, BP');
  EmitInstr('POP    BP');
  EmitInstr('RET');

  { --- 12. Quitter la portee --- }
  SymLeaveScope;

  { Restaurer l etat du contexte englobant }
  CurFrameSize  := SavedFrameSize;
  CurProcRetLbl := SavedProcRetLbl;
  CurProcName   := SavedProcName;
  CurProcDepth  := SavedProcDepth;

  { --- 13. Label de saut (apres le corps) --- }
  EmitLabel(SkipLbl);

  { Consommer le point-virgule optionnel }
  If CurToken.Kind = TK_SEMI Then
    ParserAdvance;
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
Var
  IsDeclKw : Boolean;
  StmtRes  : TExprVal;
Begin
  { Detecter si le token courant debute une declaration }
  IsDeclKw := False;
  If CurToken.Kind = TK_BOLD Then
  Begin
    { Mots-cles de mode ou prefixes de declaration }
    If (CurToken.Val = 'INT') Or (CurToken.Val = 'REAL') Or
       (CurToken.Val = 'BOOL') Or (CurToken.Val = 'CHAR') Or
       (CurToken.Val = 'STRING') Or (CurToken.Val = 'BITS') Or
       (CurToken.Val = 'BYTES') Or (CurToken.Val = 'COMPL') Or
       (CurToken.Val = 'VOID') Or
       (CurToken.Val = 'REF') Or (CurToken.Val = 'LOC') Or
       (CurToken.Val = 'HEAP') Then
      IsDeclKw := True;
  End
  Else If CurToken.Kind = TK_IDENT Then
  Begin
    { Verifier si c est un mode utilisateur (struct) }
    If ModeLookupName(CurToken.Val) >= 0 Then
      IsDeclKw := True;
  End
  Else If CurToken.Kind = TK_SUB Then
  Begin
    { [lwb:upb] MODE name -> declaration de tableau (TODO 18) }
    IsDeclKw := True;
  End;

  If IsDeclKw Then
    ParseDeclStmt
  Else If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'MODE') Then
    ParseModeDecl
  Else If (CurToken.Kind = TK_BOLD) And (CurToken.Val = 'PROC') Then
  Begin
    ParserAdvance; { consomme PROC }
    ParseProcDecl;
  End
  Else If CurToken.Kind = TK_SEMI Then
    ParserAdvance   { point-virgule seul = go-on vide }
  Else If CurToken.Kind <> TK_EOF Then
  Begin
    { Expression-statement }
    ParseExpr(StmtRes);
  End;
End;

Procedure ParserAdvance;
Begin
  If HasPushedToken Then
  Begin
    CurToken := PushedToken;
    HasPushedToken := False;
  End
  Else
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
