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

  TODO 01 - INFRASTRUCTURE ET OPTIONS
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
            ParseArgs : analyser argv (source.a68 [sortie.asm] [-v] [-d] [-w])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .a68 ou .algol
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LEXEUR (TOKENS ALGOL 68)
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

  TODO 03 - DENOTATIONS (LITTERAUX)
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

Begin
End.
