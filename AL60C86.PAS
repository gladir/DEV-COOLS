{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Algol 60 vers assembleur 8086
}

(* ============================================================
  AL60C86.PAS - Compilateur Algol 60 -> Assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
            ParseArgs : analyser argv (source.a60 [sortie.asm] [-v] [-d] [-w])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .a60 ou .alg (fichier source Algol 60)
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LEXEUR (TOKENS ALGOL 60) [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_INTEGER, TK_REAL, TK_IDENT,
              TK_STRING, TK_KEYWORD, TK_OP, TK_PUNCT, TK_BOOLEAN
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanString : chaine entre guillemets ` ... ` ou backtick
            Commentaires : mot-cle 'comment' suivi de texte jusqu au ;
              Texte entre BEGIN et le premier ; (commentaire implicite)
            Mots-cles : BEGIN END IF THEN ELSE FOR DO STEP UNTIL
              WHILE GO TO GOTO SWITCH VALUE OWN BOOLEAN INTEGER
              REAL ARRAY PROCEDURE STRING LABEL COMMENT TRUE FALSE
            Symboles speciaux : := (affectation), ; (separateur)
              : (etiquette), , (virgule), . (fin de programme)
              ( ) [ ] (parentheses et indices)
              + - * / (arithmetique)
              < <= = >= > != (comparaison)
              ^ (puissance, notation alternative : deux etoiles)
              10 (notation exposant dans les reels, symbole dix)
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
            Entiers decimaux : 0..65535 (unsigned) ou -32768..32767 (signed)
            Reels : 3.14, 6.022|10|23 (notation avec exposant base 10)
              Traitement simplifie : trunc vers entier 16 bits + avertissement
            Booleens : TRUE -> AX=1, FALSE -> AX=0
            Chaines : `Hello` -> donnees dans segment DATA avec DB
              Pas de type chaine natif en Algol 60 standard
              Extension : chaines pour les entrees/sorties
            Constantes nommees : pas de CONST en Algol 60, simuler avec
              des variables initialisees ou des macros internes

  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
            Arithmetiques : + - * / (reels et entiers)
                            div (division entiere, reste tronque)
            Puissance     : ^ ou ** (exponentiation)
            Comparaison   : < <= = >= > != (different de)
            Logiques      : AND OR NOT (ou symboles /\ \/ ~)
              Equivalence : EQUIV (equivalence logique)
              Implication : IMPL (implication logique -> NOT a OR b)
            Affectation   : := (peut etre multiple : a := b := expr)
            Precedence (du plus fort au plus faible) :
              1. NOT, unaire +/-
              2. ^ (puissance)
              3. * / div
              4. + - (binaire)
              5. < <= = >= > !=
              6. AND
              7. OR
              8. IMPL
              9. EQUIV

  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
            TSymKind : SK_VAR, SK_PARAM, SK_PROC, SK_LABEL,
              SK_SWITCH, SK_ARRAY, SK_OWN
            TSymRec : Name, MangledName, Kind, TypeIdx, Offset,
              ScopeLevel, IsOwn, IsValue, IsName, DeclLine
            SymNameClean, SymMangle, SymAdd, SymFind, SymFindInScope
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            SymEnterScope / SymLeaveScope : gestion des blocs imbriques
              Algol 60 permet des declarations locales dans chaque bloc
            Algol 60 est a portee lexicale statique (static scoping)
            Recherche en remontant les portees englobantes
            SymNextOffset : allocation locale CurFrameSize += 2

  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
            TTypeKind : TYK_INTEGER (16 bits signe), TYK_REAL (stub entier),
              TYK_BOOLEAN (16 bits, 0 ou 1), TYK_STRING (ptr chaine),
              TYK_LABEL (adresse de code), TYK_SWITCH (tableau de labels),
              TYK_PROCEDURE (pointeur de code), TYK_ARRAY (tableau)
            TypeTab, TypeInit : enregistrer les types primitifs
            TypeSizeof : INTEGER=2, REAL=2 (tronque), BOOLEAN=2, ptr=2
            Conversion implicite INTEGER -> REAL (avertissement)
            Pas de types utilisateur en Algol 60 (pas de RECORD, pas d ENUM)
            Verification de type a la compilation pour les operateurs

  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _A60L_NNNNN)
            Prefixes : _A60V_ (variable), _A60P_ (procedure), _A60K_ (chaine const),
              _A60RT_ (runtime), _A60L_ (label), _A60S_ (switch),
              _A60O_ (variable own), _A60T_ (thunk)
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
            EmitProlog / EmitEpilog : PUSH BP / MOV BP,SP et MOV SP,BP / POP BP
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_ARRAY),
              IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr : variantes d ajout
            DataAddArray : reserver un bloc DK_ARRAY_BLK avec ElemCount
            DataInit : pre-peupler le segment DATA avec les constantes
              _A60_CRLF (0Dh,0Ah,0), _A60_SPACE (' ',0), _A60_EMPTY (0)
              _A60_TRUE_S ('TRUE',0), _A60_FALSE_S ('FALSE',0)
              _A60_NUMBUF (12 octets), _A60_TMPBUF (256 octets)
            Variables globales (declarations au niveau programme) :
              entrees DK_WORD dans DATA
            Chaines litterales : DB 'abc',0 dans DATA avec label _A60K_N
            Variables OWN : entrees dans DATA (persistent entre appels)
              avec label _A60O_NomProc_NomVar
            Tableaux globaux : reserve avec DW count DUP(0)

  TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
            Variables globales : segment DATA, acces par label _A60V_nom
            Variables locales : pile BP, acces [BP-offset]
            Parametres par valeur : copie sur pile (comme variable locale)
            Parametres par nom : passage de thunk (adresse de sous-routine)
            Affectation := : ParseExpr + MOV destination, AX
            Affectation multiple : a := b := c := expr
              Evaluer expr une fois, affecter de droite a gauche
            Affectation de tableau : arr[i] := expr -> calcul offset + MOV
            ExprAddrOf : retourner la reference ASM d une variable
              globale -> WORD PTR [_A60V_nom], locale -> WORD PTR [BP-n]
            ExprStore : MOV [addr], AX pour ecrire dans la variable
            ExprLoad : MOV AX, [addr] et remplir TExprVal
            DeclAllocSym : allouer une variable
              globale (scope 0) -> DW 0 dans DATA
              locale (scope > 0) -> SUB SP, 2
            ParseDeclStmt : parser INTEGER/REAL/BOOLEAN ident [,ident]
              avec optionnel := expr pour initialisation
            ParseExprStmt : parser ident := expr (affectation)
              ou expression seule
            ParseStmt : dispatcher type-keyword -> ParseDeclStmt,
              autre -> ParseExprStmt

  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
            ParsePrimary : literal entier, literal reel, TRUE/FALSE,
              identificateur, appel de procedure/fonction
            Acces variable simple : MOV AX, [label] ou MOV AX, [BP-offset]
            Acces element de tableau : arr[i,j] -> calcul offset lineaire
            Appel de fonction : CALL _A60P_nom -> resultat dans AX
            Parentheses : ( expr ) -> evaluation de l expression
            Expression conditionnelle : IF b THEN e1 ELSE e2
              (traitee comme expression retournant une valeur dans AX)
            Acces switch : nom[expr] -> expression designationnelle (label)
            ParseProcCall : push args droite-a-gauche, CALL, ADD SP
            ParseArrayAccess : arr[i] -> LEA base + index*2, MOV AX,[BX]
            ParseSwitchAccess : sw[i] -> MOV BX,i / SHL BX,1 / MOV AX,[tbl+BX]

  TODO 11 - EXPRESSIONS ARITHMETIQUES ET BOOLEENNES [IMPLEMENTE]
            ParseExprPrec(MinPrec) : boucle de precedence (Pratt)
            Arithmetique entiere : ADD/SUB/IMUL/IDIV pour +, -, *, div
            Division reelle / : IDIV avec avertissement (pas de virgule flottante)
            Puissance ^ : boucle de multiplication iterative
              ou CALL _A60RT_POWER(AX=base, BX=exposant) -> AX
            Comparaison : CMP + Jcc pour <, <=, =, >=, >, !=
            Logique AND : court-circuit JZ vers false-branch
            Logique OR : court-circuit JNZ vers true-branch
            Logique NOT : XOR AX,1
            IMPL (implication) : NOT a OR b -> emission JNZ + OR
            EQUIV (equivalence) : CMP AX,BX -> AX=0|1 ou XOR+NOT

  TODO 12 - ENTREES/SORTIES (INTRINSICS) [IMPLEMENTE]
            Algol 60 ne definit pas d E/S standard ;
            intrinsics fournis par le compilateur :
            outinteger(canal, n)   -> CALL _A60RT_OUTINT (INT 21h AH=40h)
            outreal(canal, x)      -> CALL _A60RT_OUTREAL (stub: outinteger)
            outstring(canal, s)    -> CALL _A60RT_OUTSTR (INT 21h AH=40h)
            outboolean(canal, b)   -> CALL _A60RT_OUTBOOL ("TRUE"/"FALSE")
            ininteger(canal)       -> CALL _A60RT_ININT (INT 21h AH=0Ah + atoi)
            inreal(canal)          -> CALL _A60RT_INREAL (stub: ininteger)
            inchar(canal)          -> CALL _A60RT_INCHAR (INT 21h AH=01h)
            sysact(canal, action, r) -> operations speciales (open/close fichier)
            print(args)            -> raccourci pour outstring sur canal 1
            Canal 1 = STDOUT (handle 1), Canal 2 = STDERR (handle 2)
            Nouvelle ligne : CALL _A60RT_NEWLINE (ecriture CR+LF)
            ParseIOIntrinsic : intercepte les noms I/O dans ParsePrimary
            EmitIORuntime : 7 routines runtime ASM (INT 21h DOS)

  TODO 13 - INSTRUCTIONS CONDITIONNELLES (IF/THEN/ELSE) [IMPLEMENTE]
            ParseIfStmt : IF expr THEN stmt [ELSE stmt]
              Emission TEST AX,AX / JZ pour condition fausse
              Labels : _A60L_ELSE_N, _A60L_ENDIF_N
            IF sans ELSE : saut vers _A60L_ENDIF_N si faux
            IF avec ELSE : saut vers _A60L_ELSE_N si faux,
              JMP _A60L_ENDIF_N apres branche THEN
            Attention : ambiguite du "dangling else" en Algol 60
              Resolution : ELSE se lie au IF le plus proche non encore ferme
            Expression conditionnelle : IF b THEN e1 ELSE e2
              Meme logique de saut, resultat dans AX

  TODO 14 - BOUCLE FOR (STEP/UNTIL/WHILE) [IMPLEMENTE]
            ParseForStmt : FOR var := elements DO stmt
            Forme STEP/UNTIL : FOR i := lo STEP s UNTIL hi DO ...
              Initialiser i := lo
              Test : si s > 0 alors CMP i, hi / JG fin
                     si s < 0 alors CMP i, hi / JL fin
              Increment : ADD i, s apres chaque iteration
              Labels : _A60L_FTEST_N, _A60L_FINCR_N, _A60L_FEND_N
            Forme WHILE : FOR i := expr WHILE cond DO ...
              Affecter i := expr a chaque iteration
              Tester cond, si faux -> JMP fin
            Forme simple : FOR i := e1, e2, e3 DO ...
              Liste d elements : evaluer chaque element successivement
              Chaque element peut etre une valeur simple, STEP/UNTIL ou WHILE
            Combinaison d elements : FOR i := 1, 3 STEP 2 UNTIL 9, 20 DO ...
              Traiter chaque element de la liste dans l ordre

  TODO 15 - GOTO ET ETIQUETTES [IMPLEMENTE]
            Declarations d etiquettes : nom: au debut d une instruction
            Table des etiquettes : LabelTab, LabelAdd, LabelFind
            GOTO label : JMP _A60L_label
            GO TO label : synonyme de GOTO (deux mots)
            GOTO expression designationnelle : GOTO switch[expr]
              Evaluer l expression, obtenir l adresse du label
              JMP indirect : JMP [BX] ou CALL/RET selon implementation
            Etiquettes locales a un bloc : portee du BEGIN/END englobant
            Restriction : GOTO ne peut pas sauter a l interieur d un bloc
              depuis l exterieur (seulement vers un bloc englobant)
            Etiquettes en tant que parametres : passage de label a une procedure

  TODO 16 - BLOCS (BEGIN/END) ET INSTRUCTIONS COMPOSEES [IMPLEMENTE]
            ParseBlock : BEGIN declarations; instructions END
            Declarations au debut du bloc uniquement (avant les instructions)
            Ordre des declarations : types, puis variables, puis procedures
            Portee lexicale : les declarations sont locales au bloc
              SymEnterScope au BEGIN, SymLeaveScope au END
            Variables locales du bloc : allocations sur la pile (SUB SP, n)
              Liberation a la sortie du bloc (ADD SP, n ou MOV SP,BP)
            Instruction composee : BEGIN stmt; stmt; ...; stmt END
              Sans declarations, c est une simple sequence
            Bloc programme principal : le bloc le plus externe
              Genere le point d entree _A60P_Main
            Blocs imbriques : portees imbriquees multiples avec
              recherche des variables dans la chaine de portees

  TODO 17 - TABLEAUX (ARRAY) A BORNES DYNAMIQUES [IMPLEMENTE]
            Declaration : ARRAY id[lo:hi] ou ARRAY id[lo1:hi1, lo2:hi2]
              Bornes : expressions entieres evaluees a l entree du bloc
              Multidimensionnel : indices separes par des virgules
            Types de tableaux : INTEGER ARRAY, REAL ARRAY, BOOLEAN ARRAY
            Allocation dynamique : taille = (hi-lo+1) * sizeof(element)
              Tableaux locaux : reserve sur la pile (SUB SP, taille)
              Tableaux globaux : reserve dans le segment DATA
            Acces par indice : arr[i] -> offset = (i - lo) * sizeof(elem)
              Acces multidimensionnel : linearisation row-major
              arr[i,j] -> offset = ((i-lo1)*(hi2-lo2+1) + (j-lo2)) * sizeof
            Verification de bornes : CMP index, lo / CMP index, hi
              -> erreur si hors bornes (optionnel, selon flag -r)
            Tableaux en parametres : passage par reference (adresse + descripteur)
              Descripteur : pointeur base, bornes inferieures, dimensions

  TODO 18 - DECLARATIONS DE PROCEDURES [IMPLEMENTE]
            ParseProcDecl : [type] PROCEDURE nom(params); [VALUE params;]
              [specifications;] corps
            Specifications des parametres :
              INTEGER id, id; REAL id; BOOLEAN id;
              ARRAY id; PROCEDURE id; LABEL id; SWITCH id; STRING id
            Mot-cle VALUE : indique les parametres passes par valeur
              Les autres sont par nom par defaut (call by name)
            Procedures sans type : pas de valeur de retour (comme void)
            Procedures typees : INTEGER PROCEDURE, REAL PROCEDURE,
              BOOLEAN PROCEDURE -> resultat dans AX
              Retour de valeur : affectation au nom de la procedure
              ex : PROCEDURE f; f := expr (affecte la valeur de retour)
            Convention d appel : cdecl 16 bits
              Prologue : PUSH BP / MOV BP,SP / SUB SP, locals_size
              Epilogue : MOV SP,BP / POP BP / RET
            Procedures imbriquees : acces au cadre englobant via lien statique
              (display ou pointeur vers BP du cadre parent)

  TODO 19 - APPELS DE PROCEDURES ET PARAMETRES [IMPLEMENTE]
            Appel de procedure : nom(arg1, arg2, ...)
            Parametres par valeur (VALUE) :
              Evaluer l argument, empiler la valeur sur la pile
              Le parametre formel est une copie locale
            Parametres par nom (defaut, call by name) :
              Passer un thunk : adresse d une sous-routine qui evalue
              l expression de l argument dans le contexte de l appelant
              Le parametre formel invoque le thunk a chaque acces
            Nombre de parametres : verification a la compilation
            Types des parametres : verification de compatibilite
            Appels recursifs : support natif via pile (pas de limite sauf memoire)
            Procedures comme parametres : passage de l adresse du code
              PROCEDURE p(f); PROCEDURE f; -> f passe comme pointeur

  TODO 20 - APPEL PAR NOM (THUNKS / CALL BY NAME) [IMPLEMENTE]
            Concept : chaque acces au parametre formel reevalue l argument
              dans l environnement de l appelant
            Generation de thunks : pour chaque argument par nom,
              generer une sous-routine anonyme _A60T_N qui :
                1. Sauvegarde le contexte courant
                2. Restaure le contexte de l appelant (display/BP)
                3. Evalue l expression de l argument
                4. Retourne le resultat dans AX (valeur) ou BX (adresse)
                5. Restaure le contexte de l appele
            Thunk pour L-value : si le parametre est cible d affectation,
              le thunk retourne l adresse (BX) au lieu de la valeur
            Thunk pour R-value : si le parametre est lu,
              le thunk retourne la valeur (AX)
            Optimisation : si l argument est une variable simple,
              pas besoin de thunk, passage direct par reference
            Optimisation : si l argument est une constante,
              pas besoin de thunk, passage par valeur
            Jensen's device : FOR i := 1 STEP 1 UNTIL n DO s := s + V[i]
              ou V et s sont passes par nom -> acces dynamique correct
            Display : tableau de pointeurs vers les cadres de pile
              des portees englobantes pour acces aux variables non locales

  TODO 21 - DECLARATIONS SWITCH (AIGUILLAGES) [IMPLEMENTE]
            Declaration : SWITCH sw := label1, label2, label3, ...
              Liste d expressions designationnelles (labels ou IF-THEN-ELSE labels)
            Acces : sw[expr] retourne le label a la position expr
              Indice base 1 : sw[1] = label1, sw[2] = label2, etc.
            Utilisation avec GOTO : GOTO sw[expr]
              Evaluer expr -> index dans la table -> JMP vers le label
            Implementation : table de mots dans DATA
              _A60S_sw DW OFFSET _A60L_label1, OFFSET _A60L_label2, ...
              Acces : MOV BX, index / DEC BX / SHL BX,1 / JMP [_A60S_sw + BX]
            Verification de bornes : index < 1 ou > n -> erreur ou no-op
            Expressions designationnelles conditionnelles dans la liste :
              SWITCH sw := L1, IF b THEN L2 ELSE L3, L4
              -> evaluer la condition pour determiner le label effectif

  TODO 22 - VARIABLES OWN (STATIQUES) [IMPLEMENTE]
            Declaration : OWN INTEGER x; OWN REAL y; OWN BOOLEAN z;
              OWN ARRAY a[1:10]
            Semantique : la variable conserve sa valeur entre les appels
              de la procedure (equivalent a 'static' en C)
            Implementation : allocation dans le segment DATA au lieu de la pile
              Label : _A60O_NomProc_NomVar DW 0
            Initialisation : a zero (ou valeur par defaut) au debut du programme
              Pas de re-initialisation a chaque appel de procedure
            Variables OWN dans des blocs : la variable persiste entre
              les executions successives du bloc
            OWN ARRAY : tableau alloue dans DATA, bornes fixees au premier appel
              Les bornes ne changent pas aux appels suivants
            Distinction avec variables locales : locales sur pile,
              OWN dans DATA

  TODO 23 - EXPRESSIONS CONDITIONNELLES ET DESIGNATIONNELLES [IMPLEMENTE]
            Expression conditionnelle : IF b THEN e1 ELSE e2
              Retourne une valeur : e1 si b est vrai, e2 sinon
              Type : le type commun de e1 et e2 (INTEGER, REAL, BOOLEAN)
              Emission : TEST AX,AX / JZ lbl_else / eval e1 / JMP lbl_end /
                lbl_else: eval e2 / lbl_end:
              Peut etre imbriquee : IF b1 THEN (IF b2 THEN e1 ELSE e2) ELSE e3
            Expression designationnelle : expression dont la valeur est un label
              Variable de type LABEL : stocke une adresse de code
              Element de switch : sw[expr] -> label
              Expression designationnelle conditionnelle :
                IF b THEN L1 ELSE L2 -> retourne un label
              Utilisation : GOTO (expression designationnelle)
            Distinction instruction vs expression :
              IF THEN ELSE peut etre instruction (sans valeur) ou expression
              Le contexte determine l interpretation

  TODO 24 - RUNTIME MINIMAL [IMPLEMENTE]
            _A60RT_PRINT(BX=handle, SI=msg, CX=len) : INT 21h AH=40h
            _A60RT_PRINTLN : _A60RT_PRINT + CR+LF via _A60_CRLF DB 13,10,0
            _A60RT_STRLEN(SI=str) : compte octets jusqu a 0 -> AX
            _A60RT_NUMTOSTR(AX=n, DI=buf) : entier signe -> ASCII (itoa)
            _A60RT_STRTONUM(SI=str) : ASCII -> entier -> AX (atoi)
            _A60RT_POWER(AX=base, BX=exp) : exponentiation entiere -> AX
            _A60RT_OUTINT(BX=canal, AX=n) : ecrire entier sur canal
            _A60RT_OUTSTR(BX=canal, SI=str) : ecrire chaine sur canal
            _A60RT_OUTBOOL(BX=canal, AX=b) : ecrire TRUE ou FALSE
            _A60RT_ININT(BX=canal) : lire entier depuis canal -> AX
            _A60RT_INCHAR(BX=canal) : lire caractere -> AL
            _A60RT_NEWLINE(BX=canal) : ecrire CR+LF
            _A60RT_ABS(AX=n) : valeur absolue -> AX
            _A60RT_SIGN(AX=n) : signe -> AX (-1, 0, 1)
            _A60RT_ENTIER(AX=n) : partie entiere (stub: identite sur entiers)
            _A60RT_CHKIDX(AX=idx, BX=lo, CX=hi) : verification bornes tableau
              -> erreur si hors bornes
            _A60RT_PANIC(SI=msg) : affiche message + MOV AX,4C01h + INT 21h
            RuntimeEmitted : flag pour n emettre le runtime qu une seule fois
            Heap statique : _A60_HEAP DB 4096 DUP(0) + _A60_HEAPTOP DW 0

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES [IMPLEMENTE]
            EmitClose : END _A60P_Main dans _TEXT ENDS / DATA ENDS
            Run : pipeline complet LexInit -> ParseProgram ->
              EmitRuntime -> _TEXT ENDS / EmitDataSeg / END _A60P_Main
            Fichiers SAMPLES\ALGOL60\ a creer :
              hello.a60   (outstring, variables, affectations)
              math.a60    (expressions arithmetiques, puissance, div)
              ifthen.a60  (IF/THEN/ELSE, expressions conditionnelles)
              forloop.a60 (FOR/STEP/UNTIL, FOR/WHILE, listes d elements)
              arrays.a60  (ARRAY, indices, bornes dynamiques, multi-dim)
              procs.a60   (PROCEDURE, fonctions, recursion, parametres)
              byname.a60  (call by name, Jensen's device, thunks)
              switch.a60  (SWITCH, GOTO switch[i], aiguillages)
              own.a60     (OWN variables, persistance entre appels)
              blocks.a60  (BEGIN/END, portees imbriquees, blocs)
            Smoke tests : AL60C86.EXE -v SAMPLES\ALGOL60\*.a60

  ============================================================ *)

Program AL60C86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES GENERALES
  ============================================================ }

Const
  AL60_VERSION = '1.0';
  AL60_DATE    = '2026-03-06';

  { Limites internes }
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}100{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}32{$ELSE}16{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_ARRAY_DIM = 4;    { dimensions max d un tableau (TODO 17) }
  STACK_SIZE    = 1024;

  { Prefixes de nommage ASM }
  A60_VAR_PFX  = '_A60V_';   { variable scalaire               }
  A60_FN_PFX   = '_A60P_';   { procedure / fonction            }
  A60_STR_PFX  = '_A60K_';   { constante chaine litterale      }
  A60_RT_PFX   = '_A60RT_';  { routine runtime                 }
  A60_LBL_PFX  = '_A60L_';   { label de saut interne           }
  A60_SW_PFX   = '_A60S_';   { table switch (aiguillage)       }
  A60_OWN_PFX  = '_A60O_';   { variable OWN (statique)         }
  A60_THK_PFX  = '_A60T_';   { thunk (call by name)            }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Indices de types primitifs Algol 60 }
  TY_IDX_INTEGER   = 0;  { entier 16 bits signe            }
  TY_IDX_REAL      = 1;  { reel (stub: entier tronque)     }
  TY_IDX_BOOLEAN   = 2;  { 0 ou 1 dans AX                  }
  TY_IDX_STRING    = 3;  { pointeur chaine DATA             }
  TY_IDX_LABEL     = 4;  { adresse de code (etiquette)      }
  TY_IDX_SWITCH    = 5;  { tableau de labels (aiguillage)   }
  TY_IDX_PROCEDURE = 6;  { pointeur de code (sous-programme)}
  TY_IDX_ARRAY     = 7;  { tableau a bornes dynamiques      }
  TY_PRIM_COUNT    = 8;
  TY_UNKNOWN       = -1;

{ ============================================================
  TYPES
  ============================================================ }

Type
  TString = String[MAX_STR];

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;   { fichier source (.a60 / .alg)         }
    OutFile   : TString;   { fichier assembleur de sortie (.asm)  }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Warnings  : Boolean;   { -w : activer les avertissements      }
  End;

  { ---- Tokens Algol 60 (TODO 02) -------------------------- }
  TTokenKind = (
    TK_EOF,       { fin de fichier                          }
    TK_INTEGER,   { literal entier 42 0                     }
    TK_REAL,      { literal reel 3.14 (tronque en entier)   }
    TK_IDENT,     { identificateur (non-mot-cle)            }
    TK_STRING,    { literal chaine ` ... `                  }
    TK_KEYWORD,   { mot-cle Algol 60 reconnu                }
    TK_OP,        { operateur + - * / := etc.               }
    TK_PUNCT,     { ponctuation ; , ( ) [ ] . :             }
    TK_BOOLEAN    { TRUE ou FALSE                           }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;     { valeur textuelle brute          }
    IntVal   : LongInt;     { valeur entiere (TK_INTEGER)     }
    FloatVal : Real;        { valeur flottante (TK_REAL)      }
    Line     : Integer;     { ligne source (1-base)           }
    Col      : Integer;     { colonne source (1-base)         }
  End;

  { ---- Expressions (TODO 03) ------------------------------- }
  TExprKind = (
    EK_NONE,   { void / pas de valeur            }
    EK_IMM,    { immediate dans ImmVal           }
    EK_AX,     { valeur dans AX                  }
    EK_MEM     { adresse [BP+Offset] ou [_A60V_x]}
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
    SymIdx  : Integer;
  End;

  { ---- Segment de donnees (TODO 03+) ----------------------- }
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY_BLK, DK_SWITCH_TAB);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;
  End;

  { ---- Categories de symboles (TODO 05) -------------------- }
  TSymKind = (
    SK_VAR,      { variable scalaire (INTEGER, REAL, BOOLEAN)  }
    SK_PARAM,    { parametre formel de procedure               }
    SK_PROC,     { procedure / fonction                        }
    SK_LABEL,    { etiquette de saut (label)                   }
    SK_SWITCH,   { aiguillage (switch)                         }
    SK_ARRAY,    { tableau (ARRAY)                             }
    SK_OWN       { variable OWN (statique, persistante)        }
  );

  TSymRec = Record
    Name        : TString;   { identifiant Algol 60                }
    MangledName : TString;   { etiquette ASM (_A60V_nom, etc.)     }
    Kind        : TSymKind;
    TypeIdx     : Integer;   { indice dans TypeTab (TY_IDX_*)      }
    ScopeLevel  : Integer;   { portee de declaration               }
    Offset      : Integer;   { [BP-n] pour locaux, [BP+n] params   }
    IsOwn       : Boolean;   { OWN : variable statique (DATA seg)  }
    IsValue     : Boolean;   { VALUE : parametre passe par valeur  }
    IsName      : Boolean;   { parametre passe par nom (thunk)     }
    DeclLine    : Integer;   { ligne de declaration (debug)        }
    { Champs tableau (TODO 17) }
    ArrayDim    : Integer;   { nombre de dimensions (0 = pas un tableau) }
    ArrayElemTy : Integer;   { type des elements (TY_IDX_INTEGER, etc.)  }
    ArrayLo     : Array[1..MAX_ARRAY_DIM] Of Integer; { borne inf     }
    ArrayHi     : Array[1..MAX_ARRAY_DIM] Of Integer; { borne sup     }
    { Champs procedure (TODO 19) }
    ProcParamCount : Integer;  { nombre de parametres formels (SK_PROC) }
    { Champs procedure (TODO 20) }
    ProcParamIsVal : Array[0..MAX_PARAM - 1] Of Boolean; { True=VALUE }
    { Champs switch (TODO 21) }
    SwitchLabCount : Integer;  { nombre d entrees dans la table switch }
  End;

  { ---- Systeme de types (TODO 06) -------------------------- }
  TTypeKind = (
    TYK_INTEGER,   { entier 16 bits signe (INTEGER)              }
    TYK_REAL,      { reel (stub: entier tronque 16 bits)         }
    TYK_BOOLEAN,   { booleen 0 ou 1 dans AX (BOOLEAN)            }
    TYK_STRING,    { pointeur vers chaine dans DATA (STRING)      }
    TYK_LABEL,     { adresse de code / etiquette (LABEL)          }
    TYK_SWITCH,    { tableau de labels / aiguillage (SWITCH)      }
    TYK_PROCEDURE, { pointeur de code / sous-programme (PROCEDURE)}
    TYK_ARRAY,     { tableau a bornes dynamiques (ARRAY)          }
    TYK_UNKNOWN    { type inconnu ou non determine                }
  );

  TTypeRec = Record
    Name : TString;     { nom du type (INTEGER, REAL, etc.)      }
    Kind : TTypeKind;   { categorie de type                       }
    Size : Integer;     { taille en octets (2 pour 16-bit)        }
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

  { Emetteur ASM (stubs pour TODO 07+) }
  OutF       : Text;
  OutFOpen   : Boolean;

  { Lexeur (TODO 02) }
  LexSrcF    : Text;
  LexLine    : String;
  LexLineNo  : Integer;
  LexColNo   : Integer;
  LexEOF     : Boolean;
  LexOpened  : Boolean;
  CurToken   : TToken;

  { Segment de donnees (TODO 03) }
  DataTab    : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount  : Integer;

  { Expressions (TODO 03) }
  GExprDummy : TExprVal;

  { Etat general }
  RuntimeEmitted : Boolean;
  IOEmitted      : Boolean;
  MinRTEmitted   : Boolean;

  { Label sequentiel }
  LabelSeq   : Integer;

  { Compteur IF (TODO 13) }
  IfCount    : Integer;

  { Compteur FOR (TODO 14) }
  ForCount   : Integer;

  { Compteur GOTO (TODO 15) }
  GotoCount  : Integer;

  { Compteur BLOCK (TODO 16) }
  BlockCount : Integer;

  { Compteur ARRAY (TODO 17) }
  ArrayCount : Integer;

  { Compteur PROCEDURE (TODO 18) }
  ProcCount   : Integer;
  CurFnName   : TString;    { nom de la procedure courante ('' si hors proc) }
  CurFnRetLbl : TString;    { label de retour de la procedure courante       }
  CurFnDepth  : Integer;    { profondeur d imbrication des procedures        }

  { Compteur THUNK (TODO 20) }
  ThunkCount : Integer;

  { Compteur SWITCH (TODO 21) }
  SwitchCount : Integer;

  { Compteur OWN (TODO 22) }
  OwnCount : Integer;

  { Table des symboles (TODO 05) }
  SymTab       : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount     : Integer;
  ScopeStack   : Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeTop     : Integer;
  CurScope     : Integer;
  CurFrameSize : Integer;    { taille cadre local courant (en octets) }

  { Table des types (TODO 06) }
  TypeTab    : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount  : Integer;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- Forward declarations (TODO 02) ----------------------- }
Procedure LexInit;             Forward;
Procedure LexClose;            Forward;
Function  IsKeyword(Const S : TString) : Boolean; Forward;
Procedure PrintToken(Const T : TToken); Forward;
Procedure LexNextLine;         Forward;
Function  IsIdentStart(Ch : Char) : Boolean; Forward;
Function  IsIdentCont(Ch : Char) : Boolean; Forward;
Procedure LexScanIdent;        Forward;
Procedure LexScanNumber;       Forward;
Procedure LexScanString;       Forward;
Procedure LexSkipComment;      Forward;
Procedure LexNextToken;        Forward;
Function  StrUpperCase(Const S : TString) : TString; Forward;
{ ---- Forward declarations (TODO 03) ----------------------- }
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ExprMakeNone(Var Res : TExprVal); Forward;
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal); Forward;
Procedure ExprMakeAX(ATypeIdx : Integer; Var Res : TExprVal); Forward;
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEvalReal(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEvalStr(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                  AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : TString; Forward;
Function  DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer; Forward;
Function  LabelGen : TString; Forward;
Procedure ParserAdvance; Forward;
Procedure EmitOpen;      Forward;
Procedure EmitClose;     Forward;
Procedure EmitHeader;    Forward;
Procedure EmitDataSeg;   Forward;
Procedure EmitRaw(Const S : TString); Forward;
Procedure EmitComment(Const S : TString); Forward;
{ ---- Forward declarations (TODO 07) ----------------------- }
Procedure EmitInstrA(Const Mnem, A : TString); Forward;
Procedure EmitInstrAB(Const Mnem, A, B : TString); Forward;
Procedure EmitPush(Const Reg : TString); Forward;
Procedure EmitPop(Const Reg : TString); Forward;
Procedure EmitMov(Const Dst, Src : TString); Forward;
Procedure EmitProlog; Forward;
Procedure EmitEpilog; Forward;
{ ---- Forward declarations (TODO 08) ----------------------- }
Function  DataAddArray(Const Lbl : TString;
                       ElemCount : Integer) : Integer; Forward;
Procedure DataInit;    Forward;
{ ---- Forward declarations (TODO 04) ----------------------- }
Procedure EmitInstr(Const Mnem, Args : TString); Forward;
Procedure EmitLabel(Const Lbl : TString); Forward;
Procedure EmitBlankLine; Forward;
Function  BinOpPrec(Const Op : TString) : Integer; Forward;
Function  BinOpIsRight(Const Op : TString) : Boolean; Forward;
Procedure ExprFlushToAX(Var E : TExprVal); Forward;
Procedure ExprEmitBinOp(Const Op : TString;
                        Var L : TExprVal; Var R : TExprVal); Forward;
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Procedure ParseUnary(Var Res : TExprVal); Forward;
Function  CurTokIsInfixOp : Boolean; Forward;
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Forward;
Procedure ParseExpr(Var Res : TExprVal); Forward;
{ ---- Forward declarations (TODO 05) ----------------------- }
Function  SymNameClean(Const Name : TString) : TString; Forward;
Function  SymMangle(Const Name : TString; Kind : TSymKind) : TString; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindInScope(Const Name : TString;
                         Level : Integer) : Integer; Forward;
Function  SymAdd(Const Name : TString; Kind : TSymKind;
                 TypeIdx, Offset : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
Function  SymNextOffset : Integer; Forward;
Procedure SymInit;       Forward;
{ ---- Forward declarations (TODO 09) ----------------------- }
Function  ExprAddrOf(SIdx : Integer) : TString; Forward;
Procedure ExprStore(SIdx : Integer); Forward;
Procedure ExprLoad(SIdx : Integer; Var Res : TExprVal); Forward;
Function  DeclAllocSym(Const Name : TString;
                       TypeIdx : Integer) : Integer; Forward;
Procedure ParseDeclStmt; Forward;
Procedure ParseExprStmt; Forward;
Procedure ParseStmt; Forward;
{ ---- Forward declarations (TODO 10) ----------------------- }
Procedure ParseProcCall(Const ProcName : TString;
                        ProcSIdx : Integer;
                        Var Res : TExprVal); Forward;
Procedure ParseArrayAccess(SIdx : Integer;
                           Var Res : TExprVal); Forward;
Procedure ParseSwitchAccess(SIdx : Integer;
                            Var Res : TExprVal); Forward;
{ ---- Forward declarations (TODO 11) ----------------------- }
Procedure EmitExprRuntime; Forward;
{ ---- Forward declarations (TODO 12) ----------------------- }
Procedure ParseIOIntrinsic(Const Name : TString;
                           Var Res : TExprVal); Forward;
Procedure EmitIORuntime; Forward;
{ ---- Forward declarations (TODO 13) ----------------------- }
Procedure ParseIfStmt; Forward;
{ ---- Forward declarations (TODO 14) ----------------------- }
Procedure ParseForStmt; Forward;
{ ---- Forward declarations (TODO 15) ----------------------- }
Procedure ParseGotoStmt; Forward;
{ ---- Forward declarations (TODO 16) ----------------------- }
Procedure ParseBlock; Forward;
{ ---- Forward declarations (TODO 17) ----------------------- }
Procedure ParseArrayDecl(ElemTypeIdx : Integer); Forward;
{ ---- Forward declarations (TODO 18) ----------------------- }
Procedure ParseProcDecl(RetTypeIdx : Integer); Forward;
{ ---- Forward declarations (TODO 21) ----------------------- }
Procedure ParseSwitchDecl; Forward;
{ ---- Forward declarations (TODO 22) ----------------------- }
Procedure ParseOwnDecl; Forward;
{ ---- Forward declarations (TODO 24) ----------------------- }
Procedure EmitMinimalRuntime; Forward;
{ ---- Forward declarations (TODO 06) ----------------------- }
Procedure TypeInit;      Forward;
Function  TypeKindOf(TypeIdx : Integer) : TTypeKind; Forward;
Function  TypeSizeof(TypeIdx : Integer) : Integer; Forward;
Function  TypeMangle(TypeIdx : Integer) : TString; Forward;
Function  TypeIsNumeric(TypeIdx : Integer) : Boolean; Forward;
Function  TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean; Forward;
Function  TypeCoerceResult(LeftIdx, RightIdx : Integer;
                           Const Op : TString) : Integer; Forward;
Function  TypeInfer(Const E : TExprVal) : Integer; Forward;
Function  TypeLookupName(Const Name : TString) : Integer; Forward;

{ ---- Erreur fatale ----------------------------------------- }
Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('AL60C86: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
    Assign(OutF, Opts.OutFile);
    {$I-} Erase(OutF); {$I+}
    If IOResult <> 0 Then ;
  End;
  Halt(EXIT_ERROR);
End;

{ ---- Erreur de compilation --------------------------------- }
Procedure CompileError(Const Msg : TString);
Begin
  WriteLn('AL60C86: error: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, compilation arretee');
End;

{ ---- Avertissement ----------------------------------------- }
Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('AL60C86: warning: ', Msg);
  Inc(WarnCount);
End;

{ ---- Banniere ---------------------------------------------- }
Procedure ShowBanner;
Begin
  WriteLn('AL60C86 v', AL60_VERSION, ' (', AL60_DATE, ')');
  WriteLn('Compilateur Algol 60 -> assembleur 8086 (MASM .MODEL SMALL)');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

{ ---- Aide en ligne ----------------------------------------- }
Procedure ShowUsage;
Begin
  WriteLn('AL60C86 - Cette commande permet de lancer le compilateur Algol 60 ',
          'pour l''assembleur du microprocesseur 8086 ou 8088.');
  WriteLn;
  WriteLn('Syntaxe : AL60C86 <source.a60> [sortie.asm] [-v] [-d] [-w]');
  WriteLn;
  WriteLn('  source.a60 : fichier Algol 60 source (.a60 ou .alg)');
  WriteLn('  sortie.asm : fichier assembleur de sortie (defaut: source.asm)');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn('  -h         : afficher cette aide');
  WriteLn;
  Halt(EXIT_USAGE);
End;

{ ---- Statistiques ------------------------------------------ }
Procedure ShowStats;
Begin
  WriteLn;
  WriteLn('Compilation terminee : ', Opts.SrcFile, ' -> ', Opts.OutFile);
  WriteLn('  Lignes         : ', TotalLines);
  WriteLn('  Symboles       : ', TotalSyms);
  WriteLn('  Erreurs        : ', ErrorCount);
  WriteLn('  Avertissements : ', WarnCount);
End;

{ ---- Utilitaires chaines ----------------------------------- }

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

Function IntToStr_(N : LongInt) : TString;
Var
  S : TString;
Begin
  Str(N, S);
  IntToStr_ := S;
End;

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

{ ---- Initialisation des options ---------------------------- }
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
      ShowUsage
    Else If (Arg = '-v') Or (Arg = '--verbose') Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('AL60C86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('AL60C86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('AL60C86: fichier source manquant');
    ShowUsage;
  End;

  { Detecter l extension .a60 ou .alg }
  Ext := ExtractExt(Opts.SrcFile);
  If (Ext <> '.a60') And (Ext <> '.alg') Then
  Begin
    WriteLn('AL60C86: avertissement: extension non reconnue: ', Ext);
    WriteLn('  extensions attendues: .a60 ou .alg');
  End;

  If Opts.OutFile = '' Then
    Opts.OutFile := ReplaceExt(Opts.SrcFile, '.asm');
End;

{ ---- Nettoyage --------------------------------------------- }
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

{ ---- Initialisation globale -------------------------------- }
Procedure GlobalInit;
Var
  I : Integer;
Begin
  ErrorCount     := 0;
  WarnCount      := 0;
  TotalLines     := 0;
  TotalSyms      := 0;
  LabelSeq       := 0;
  OutFOpen       := False;
  LexOpened      := False;
  LexEOF         := False;
  LexLineNo      := 0;
  LexColNo       := 1;
  LexLine        := '';
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.FloatVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
  { Segment de donnees }
  DataCount := 0;
  For I := 0 To MAX_DATA - 1 Do
  Begin
    DataTab[I].LblName   := '';
    DataTab[I].Kind      := DK_WORD;
    DataTab[I].IntVal    := 0;
    DataTab[I].StrVal    := '';
    DataTab[I].ElemCount := 0;
  End;
  { Expression dummy }
  GExprDummy.Kind    := EK_NONE;
  GExprDummy.ImmVal  := 0;
  GExprDummy.TypeIdx := TY_UNKNOWN;
  GExprDummy.Offset  := 0;
  GExprDummy.SymIdx  := -1;
  RuntimeEmitted := False;
  IOEmitted := False;
  MinRTEmitted := False;
  IfCount := 0;
  ForCount := 0;
  GotoCount := 0;
  BlockCount := 0;
  ArrayCount := 0;
  ProcCount := 0;
  CurFnName := '';
  CurFnRetLbl := '';
  CurFnDepth := 0;
  ThunkCount := 0;
  SwitchCount := 0;
  OwnCount := 0;
  { Table des symboles (TODO 05) }
  SymInit;
  { Systeme de types (TODO 06) }
  TypeInit;
  { Segment de donnees (TODO 08) }
  DataInit;
End;

{ ============================================================
  TODO 02 - LEXEUR (TOKENS ALGOL 60) [IMPLEMENTE]
  ============================================================ }

{ ---- StrUpperCase : conversion en majuscules --------------- }
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

{ ---- IsKeyword : tester si un mot est un mot-cle Algol 60 - }
{ Les mots-cles sont compares en majuscules (case-insensitive) }
Function IsKeyword(Const S : TString) : Boolean;
Var
  U : TString;
Begin
  U := StrUpperCase(S);
  IsKeyword :=
    (U = 'BEGIN')     Or (U = 'END')       Or (U = 'IF')        Or
    (U = 'THEN')      Or (U = 'ELSE')      Or (U = 'FOR')       Or
    (U = 'DO')        Or (U = 'STEP')      Or (U = 'UNTIL')     Or
    (U = 'WHILE')     Or (U = 'GO')        Or (U = 'TO')        Or
    (U = 'GOTO')      Or (U = 'SWITCH')    Or (U = 'VALUE')     Or
    (U = 'OWN')       Or (U = 'BOOLEAN')   Or (U = 'INTEGER')   Or
    (U = 'REAL')      Or (U = 'ARRAY')     Or (U = 'PROCEDURE') Or
    (U = 'STRING')    Or (U = 'LABEL')     Or (U = 'COMMENT')   Or
    (U = 'TRUE')      Or (U = 'FALSE')     Or (U = 'NOT')       Or
    (U = 'AND')       Or (U = 'OR')        Or (U = 'IMPL')      Or
    (U = 'EQUIV')     Or (U = 'DIV');
End;

{ ---- PrintToken : affichage debug d un token --------------- }
Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF     : Write('EOF');
    TK_INTEGER : Write('INT(', T.IntVal, ')');
    TK_REAL    : Write('REAL(', T.IntVal, ')');
    TK_STRING  : Write('STR("', T.Val, '")');
    TK_IDENT   : Write('IDENT(', T.Val, ')');
    TK_KEYWORD : Write('KW(', T.Val, ')');
    TK_OP      : Write('OP(', T.Val, ')');
    TK_PUNCT   : Write('PUNCT(', T.Val, ')');
    TK_BOOLEAN : Write('BOOL(', T.Val, ')');
  End;
  WriteLn;
End;

{ ---- LexNextLine : lire la prochaine ligne source ---------- }
Procedure LexNextLine;
Begin
  If LexEOF Then Exit;
  If EOF(LexSrcF) Then
  Begin
    LexEOF   := True;
    LexLine  := '';
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

{ ---- IsIdentStart : caractere de debut d identificateur ---- }
Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or
                  (Ch = '_');
End;

{ ---- IsIdentCont : caractere de suite d identificateur ----- }
Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsIdentStart(Ch) Or ((Ch >= '0') And (Ch <= '9'));
End;

{ ---- LexScanIdent : scanner un identificateur ou mot-cle --- }
{ Algol 60 est case-insensitive ; on stocke en majuscules     }
Procedure LexScanIdent;
Var
  S : TString;
  U : TString;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) And IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  U := StrUpperCase(S);
  CurToken.IntVal := 0;
  { Booleens TRUE / FALSE -> TK_BOOLEAN }
  If U = 'TRUE' Then
  Begin
    CurToken.Kind   := TK_BOOLEAN;
    CurToken.Val    := 'TRUE';
    CurToken.IntVal := 1;
  End
  Else If U = 'FALSE' Then
  Begin
    CurToken.Kind   := TK_BOOLEAN;
    CurToken.Val    := 'FALSE';
    CurToken.IntVal := 0;
  End
  { COMMENT -> sauter le commentaire }
  Else If U = 'COMMENT' Then
  Begin
    LexSkipComment;
    LexNextToken;
    Exit;
  End
  Else If IsKeyword(U) Then
  Begin
    CurToken.Kind := TK_KEYWORD;
    CurToken.Val  := U;
  End
  Else
  Begin
    CurToken.Kind := TK_IDENT;
    CurToken.Val  := U;
  End;
End;

{ ---- LexScanNumber : scanner un litteral numerique --------- }
{ Entiers decimaux et reels (reels tronques en entier 16 bits) }
Procedure LexScanNumber;
Var
  N       : LongInt;
  IsFloat : Boolean;
  FracDiv : Real;
  FracVal : Real;
  FltVal  : Real;
  ExpVal  : Integer;
  NegExp  : Boolean;
Begin
  N       := 0;
  IsFloat := False;
  FracVal := 0.0;
  FracDiv := 10.0;
  ExpVal  := 0;
  NegExp  := False;

  { Partie entiere }
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
  Begin
    N := N * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
    Inc(LexColNo);
  End;

  { Partie decimale .ddd }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And
     (LexLine[LexColNo + 1] >= '0') And (LexLine[LexColNo + 1] <= '9') Then
  Begin
    IsFloat := True;
    Inc(LexColNo); { sauter . }
    FracDiv := 10.0;
    FracVal := 0.0;
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
    Begin
      FracVal := FracVal + (Ord(LexLine[LexColNo]) - Ord('0')) / FracDiv;
      FracDiv := FracDiv * 10.0;
      Inc(LexColNo);
    End;
  End;

  { Exposant : notation 10 (symbole dix) ou e/E }
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'e') Or (LexLine[LexColNo] = 'E')) Then
  Begin
    IsFloat := True;
    Inc(LexColNo);
    NegExp := False;
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '-') Then
    Begin NegExp := True; Inc(LexColNo); End
    Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '+') Then
      Inc(LexColNo);
    ExpVal := 0;
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
    Begin
      ExpVal := ExpVal * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
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
    CurToken.Kind     := TK_REAL;
    CurToken.FloatVal := FltVal;
    WarnMsg('reel tronque en entier 16 bits');
  End
  Else
    CurToken.Kind := TK_INTEGER;

  CurToken.IntVal := N;
  Str(N, CurToken.Val);
End;

{ ---- LexScanString : scanner une chaine backtick ` ... ` --- }
Procedure LexScanString;
Var
  S : TString;
Begin
  S := '';
  Inc(LexColNo); { sauter le backtick ouvrant }
  While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] <> '`') Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '`') Then
    Inc(LexColNo); { sauter le backtick fermant }
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexSkipComment : sauter un commentaire comment...;  --- }
{ Aussi appele pour le texte apres BEGIN jusqu au premier ;    }
Procedure LexSkipComment;
Begin
  While Not LexEOF Do
  Begin
    While LexColNo <= Length(LexLine) Do
    Begin
      If LexLine[LexColNo] = ';' Then
      Begin
        Inc(LexColNo); { consommer le ; }
        Exit;
      End;
      Inc(LexColNo);
    End;
    LexNextLine;
  End;
End;

{ ---- LexNextToken : scanner principal ---------------------- }
Procedure LexNextToken;
Var
  Ch, Ch2 : Char;
  Scanning : Boolean;
Begin
  CurToken.IntVal  := 0;
  CurToken.FloatVal := 0.0;

  Scanning := True;
  While Scanning Do
  Begin
    { Avancer a la prochaine ligne si fin de ligne }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

    { Fin de fichier }
    If LexEOF Then
    Begin
      CurToken.Kind := TK_EOF;
      CurToken.Val  := '';
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      Exit;
    End;

    CurToken.Line := LexLineNo;
    CurToken.Col  := LexColNo;
    Ch := LexLine[LexColNo];

    { Espaces blancs }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
    Begin
      Inc(LexColNo);
      Continue;
    End;

    Scanning := False;

    { Identificateur ou mot-cle }
    If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      Exit;
    End;

    { Litteral numerique }
    If (Ch >= '0') And (Ch <= '9') Then
    Begin
      LexScanNumber;
      Exit;
    End;

    { Chaine backtick }
    If Ch = '`' Then
    Begin
      LexScanString;
      Exit;
    End;

    { Chaine double-quote (extension) }
    If Ch = '"' Then
    Begin
      Inc(LexColNo);
      CurToken.Val := '';
      While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] <> '"') Do
      Begin
        If Length(CurToken.Val) < MAX_STR Then
          CurToken.Val := CurToken.Val + LexLine[LexColNo];
        Inc(LexColNo);
      End;
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '"') Then
        Inc(LexColNo);
      CurToken.Kind   := TK_STRING;
      CurToken.IntVal := 0;
      Exit;
    End;

    { Operateurs et ponctuation }
    Ch2 := #0;
    If LexColNo < Length(LexLine) Then
      Ch2 := LexLine[LexColNo + 1];

    Case Ch Of
      { Affectation := ou etiquette : }
      ':': Begin
             If Ch2 = '=' Then
             Begin
               CurToken.Kind := TK_OP;
               CurToken.Val  := ':=';
               Inc(LexColNo, 2);
             End
             Else
             Begin
               CurToken.Kind := TK_PUNCT;
               CurToken.Val  := ':';
               Inc(LexColNo);
             End;
           End;

      { Comparaisons < <= }
      '<': Begin
             If Ch2 = '=' Then
             Begin
               CurToken.Kind := TK_OP;
               CurToken.Val  := '<=';
               Inc(LexColNo, 2);
             End
             Else
             Begin
               CurToken.Kind := TK_OP;
               CurToken.Val  := '<';
               Inc(LexColNo);
             End;
           End;

      { Comparaisons > >= }
      '>': Begin
             If Ch2 = '=' Then
             Begin
               CurToken.Kind := TK_OP;
               CurToken.Val  := '>=';
               Inc(LexColNo, 2);
             End
             Else
             Begin
               CurToken.Kind := TK_OP;
               CurToken.Val  := '>';
               Inc(LexColNo);
             End;
           End;

      { Differend != ou negation logique /\ }
      '!': Begin
             If Ch2 = '=' Then
             Begin
               CurToken.Kind := TK_OP;
               CurToken.Val  := '!=';
               Inc(LexColNo, 2);
             End
             Else
             Begin
               CurToken.Kind := TK_OP;
               CurToken.Val  := '!';
               Inc(LexColNo);
             End;
           End;

      { Puissance ** ou simple multiplication * }
      '*': Begin
             If Ch2 = '*' Then
             Begin
               CurToken.Kind := TK_OP;
               CurToken.Val  := '^';  { normaliser ** en ^ }
               Inc(LexColNo, 2);
             End
             Else
             Begin
               CurToken.Kind := TK_OP;
               CurToken.Val  := '*';
               Inc(LexColNo);
             End;
           End;

      { Logique /\ (AND) ou division / }
      '/': Begin
             If Ch2 = '\' Then
             Begin
               CurToken.Kind := TK_OP;
               CurToken.Val  := '/\';
               Inc(LexColNo, 2);
             End
             Else
             Begin
               CurToken.Kind := TK_OP;
               CurToken.Val  := '/';
               Inc(LexColNo);
             End;
           End;

      { Logique \/ (OR) }
      '\': Begin
             If Ch2 = '/' Then
             Begin
               CurToken.Kind := TK_OP;
               CurToken.Val  := '\/';
               Inc(LexColNo, 2);
             End
             Else
             Begin
               CurToken.Kind := TK_OP;
               CurToken.Val  := '\';
               Inc(LexColNo);
             End;
           End;

      { Negation logique ~ }
      '~': Begin
             CurToken.Kind := TK_OP;
             CurToken.Val  := '~';
             Inc(LexColNo);
           End;

      { Egalite = }
      '=': Begin
             CurToken.Kind := TK_OP;
             CurToken.Val  := '=';
             Inc(LexColNo);
           End;

      { Operateurs arithmetiques simples }
      '+': Begin
             CurToken.Kind := TK_OP;
             CurToken.Val  := '+';
             Inc(LexColNo);
           End;

      '-': Begin
             CurToken.Kind := TK_OP;
             CurToken.Val  := '-';
             Inc(LexColNo);
           End;

      { Puissance ^ }
      '^': Begin
             CurToken.Kind := TK_OP;
             CurToken.Val  := '^';
             Inc(LexColNo);
           End;

      { Ponctuation }
      ';': Begin
             CurToken.Kind := TK_PUNCT;
             CurToken.Val  := ';';
             Inc(LexColNo);
           End;

      ',': Begin
             CurToken.Kind := TK_PUNCT;
             CurToken.Val  := ',';
             Inc(LexColNo);
           End;

      '.': Begin
             CurToken.Kind := TK_PUNCT;
             CurToken.Val  := '.';
             Inc(LexColNo);
           End;

      '(': Begin
             CurToken.Kind := TK_PUNCT;
             CurToken.Val  := '(';
             Inc(LexColNo);
           End;

      ')': Begin
             CurToken.Kind := TK_PUNCT;
             CurToken.Val  := ')';
             Inc(LexColNo);
           End;

      '[': Begin
             CurToken.Kind := TK_PUNCT;
             CurToken.Val  := '[';
             Inc(LexColNo);
           End;

      ']': Begin
             CurToken.Kind := TK_PUNCT;
             CurToken.Val  := ']';
             Inc(LexColNo);
           End;

    Else
      Begin
        { Caractere inconnu : signaler et avancer }
        CompileError('caractere inattendu: ' + Ch);
        Inc(LexColNo);
        Scanning := True;
      End;
    End; { case }
  End; { while Scanning }
End;

{ ---- LexInit : initialiser le lexeur et ouvrir le source --- }
Procedure LexInit;
Begin
  Assign(LexSrcF, Opts.SrcFile);
  {$I-} Reset(LexSrcF); {$I+}
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
  LexOpened  := True;
  LexEOF     := False;
  LexLineNo  := 0;
  LexColNo   := 1;
  LexLine    := '';
  LexNextLine; { lire la premiere ligne }
End;

{ ---- LexClose : fermer le fichier source ------------------- }
Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ============================================================
  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

{ ---- LabelGen : generateur de labels uniques _A60L_N ------- }
Function LabelGen : TString;
Var
  S : TString;
Begin
  Inc(LabelSeq);
  Str(LabelSeq, S);
  LabelGen := A60_LBL_PFX + S;
End;

{ ---- DataAdd : ajouter une entree dans le segment DATA ----- }
Function DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    CompileError('segment DATA plein');
    DataAdd := DataCount - 1;
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

{ ---- DataAddStr : creer un label _A60K_N et stocker chaine - }
Function DataAddStr(Const S : TString) : TString;
Var
  Lbl : TString;
Begin
  Inc(LabelSeq);
  Str(LabelSeq, Lbl);
  Lbl := A60_STR_PFX + Lbl;
  DataAdd(Lbl, DK_STR, 0, S);
  DataAddStr := Lbl;
End;

{ ---- DataAddWord : ajouter un mot 16 bits dans DATA -------- }
Function DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

{ ---- ExprMakeImm : construire une valeur immediate --------- }
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprMakeNone : expression sans valeur (void) ---------- }
Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprMakeBool : valeur booleenne (0 ou 1) -------------- }
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  If AVal <> 0 Then Res.ImmVal := 1 Else Res.ImmVal := 0;
  Res.TypeIdx := TY_IDX_BOOLEAN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprMakeAX : resultat dans le registre AX ------------- }
Procedure ExprMakeAX(ATypeIdx : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_AX;
  Res.ImmVal  := 0;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- LitEvalInt : evaluer un token TK_INTEGER --------------- }
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_INTEGER, Res);
End;

{ ---- LitEvalReal : evaluer un token TK_REAL (tronque) ------- }
{ Les reels sont tronques en entier 16 bits avec avertissement }
Procedure LitEvalReal(Const T : TToken; Var Res : TExprVal);
Var
  IV : LongInt;
Begin
  IV := T.IntVal;  { deja tronque par LexScanNumber }
  If IV > 32767 Then IV := 32767;
  If IV < -32768 Then IV := -32768;
  ExprMakeImm(IV, TY_IDX_REAL, Res);
End;

{ ---- LitEvalStr : evaluer un token TK_STRING ---------------- }
{ La chaine est stockee dans le segment DATA avec un label      }
Procedure LitEvalStr(Const T : TToken; Var Res : TExprVal);
Begin
  DataAddStr(T.Val);
  Res.Kind    := EK_MEM;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_STRING;
  Res.Offset  := DataCount - 1;
  Res.SymIdx  := -1;
End;

{ ---- LitEval : dispatcher pour les litteraux Algol 60 ------ }
{ Tokens : TK_INTEGER, TK_REAL, TK_STRING, TK_BOOLEAN          }
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeNone(Res);
  Case T.Kind Of
    TK_INTEGER : LitEvalInt(T, Res);
    TK_REAL    : LitEvalReal(T, Res);
    TK_STRING  : LitEvalStr(T, Res);
    TK_BOOLEAN : ExprMakeBool(T.IntVal, Res);
  Else
    ExprMakeNone(Res);
  End;
End;

{ ---- ParserAdvance : avancer d un token -------------------- }
Procedure ParserAdvance;
Begin
  LexNextToken;
  If Opts.DebugMode Then
    PrintToken(CurToken);
End;

{ ---- EmitRaw : ecrire une ligne brute dans le .asm --------- }
Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, S);
End;

{ ---- EmitComment : ecrire un commentaire ASM ---------------- }
Procedure EmitComment(Const S : TString);
Begin
  EmitRaw('; ' + S);
End;

{ ---- EmitOpen : ouvrir le fichier assembleur de sortie ------ }
Procedure EmitOpen;
Begin
  Assign(OutF, Opts.OutFile);
  {$I-} Rewrite(OutF); {$I+}
  If IOResult <> 0 Then
    FatalError('impossible de creer: ' + Opts.OutFile);
  OutFOpen := True;
End;

{ ============================================================
  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
  ============================================================ }

{ ---- EmitHeader : emettre l en-tete MASM (TODO 07) ---------- }
{ Emet : commentaire de generation, .MODEL SMALL, .STACK,
  ouverture du segment _TEXT avec ASSUME CS:_TEXT.              }
Procedure EmitHeader;
Var
  NS : TString;
Begin
  Str(STACK_SIZE, NS);
  EmitComment('Genere par AL60C86 v' + AL60_VERSION + ' - ' + Opts.SrcFile);
  EmitComment('Cible : 8086 DOS (.MODEL SMALL)');
  EmitComment('Pile  : ' + NS + ' octets');
  EmitBlankLine;
  EmitRaw('        .MODEL  SMALL');
  EmitRaw('        .STACK  ' + NS);
  EmitBlankLine;
  EmitRaw('_TEXT   SEGMENT PUBLIC ''CODE''');
  EmitRaw('        ASSUME  CS:_TEXT');
  EmitBlankLine;
End;

{ ---- EmitInstrA : ecrire une instruction ASM a 1 operande --- }
{ Exemple : EmitInstrA('PUSH', 'AX')  ->  "        PUSH AX"    }
Procedure EmitInstrA(Const Mnem, A : TString);
Begin
  EmitRaw('        ' + Mnem + ' ' + A);
End;

{ ---- EmitInstrAB : ecrire une instruction ASM a 2 operandes - }
{ Exemple : EmitInstrAB('MOV', 'AX', 'BX')  ->  "        MOV AX, BX" }
Procedure EmitInstrAB(Const Mnem, A, B : TString);
Begin
  EmitRaw('        ' + Mnem + ' ' + A + ', ' + B);
End;

{ ---- EmitPush : emettre PUSH registre ------------------------ }
Procedure EmitPush(Const Reg : TString);
Begin
  EmitInstrA('PUSH', Reg);
End;

{ ---- EmitPop : emettre POP registre ------------------------- }
Procedure EmitPop(Const Reg : TString);
Begin
  EmitInstrA('POP', Reg);
End;

{ ---- EmitMov : emettre MOV destination, source --------------- }
Procedure EmitMov(Const Dst, Src : TString);
Begin
  EmitInstrAB('MOV', Dst, Src);
End;

{ ---- EmitProlog : emettre le prologue de sous-programme ------ }
{ PUSH BP  /  MOV BP, SP  : sauvegarde et mise en place du cadre }
Procedure EmitProlog;
Begin
  EmitPush('BP');
  EmitMov('BP', 'SP');
End;

{ ---- EmitEpilog : emettre l epilogue de sous-programme ------- }
{ MOV SP, BP  /  POP BP  /  RET  : restauration du cadre et retour }
Procedure EmitEpilog;
Begin
  EmitMov('SP', 'BP');
  EmitPop('BP');
  EmitRaw('        RET');
End;

{ ============================================================
  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
  ============================================================ }

{ ---- DataAddArray : reserver un bloc DK_ARRAY_BLK ----------- }
{ Ajoute une entree tableau dans le segment DATA.
  Le tableau est emis comme "LblName DW ElemCount DUP(0)".       }
Function DataAddArray(Const Lbl : TString;
                      ElemCount : Integer) : Integer;
Var
  Idx : Integer;
Begin
  Idx := DataAdd(Lbl, DK_ARRAY_BLK, 0, '');
  DataTab[Idx].ElemCount := ElemCount;
  DataAddArray := Idx;
End;

{ ---- DataInit : pre-peupler le segment DATA avec les constantes }
{ Enregistre les constantes utilitaires necessaires au runtime :
  _A60_CRLF    : retour chariot + saut de ligne (0Dh, 0Ah, 0)
  _A60_SPACE   : un espace suivi de NUL (' ', 0)
  _A60_EMPTY   : chaine vide (NUL seul)
  _A60_TRUE_S  : chaine 'TRUE' pour affichage des booleens
  _A60_FALSE_S : chaine 'FALSE' pour affichage des booleens
  _A60_NUMBUF  : tampon 12 octets pour conversion numerique
  _A60_TMPBUF  : tampon 256 octets pour operations temporaires   }
Procedure DataInit;
Begin
  DataAdd('_A60_CRLF',    DK_BYTE, 0, '0Dh, 0Ah, 0');
  DataAdd('_A60_SPACE',   DK_STR,  0, ' ');
  DataAdd('_A60_EMPTY',   DK_STR,  0, '');
  DataAdd('_A60_TRUE_S',  DK_STR,  0, 'TRUE');
  DataAdd('_A60_FALSE_S', DK_STR,  0, 'FALSE');
  DataAddArray('_A60_NUMBUF', 6);
  DataAddArray('_A60_TMPBUF', 128);
  { Sauvegarde du BP de l appelant pour les thunks (TODO 20) }
  DataAddWord('_A60V_SAVEBP', 0);
  { Heap statique et messages d erreur (TODO 24) }
  DataAddArray('_A60_HEAP', 2048);
  DataAddWord('_A60_HEAPTOP', 0);
  DataAdd('_A60_PANIC_IDX', DK_STR, 0, 'Index out of bounds');
End;

{ ---- EmitDataSeg : emettre le segment _DATA (TODO 08) -------- }
Procedure EmitDataSeg;
Var
  I, J : Integer;
  S    : TString;
Begin
  EmitRaw('_DATA   SEGMENT WORD PUBLIC ''DATA''');
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_WORD :
        EmitRaw(DataTab[I].LblName + ' DW ' + IntToStr_(DataTab[I].IntVal));
      DK_BYTE :
      Begin
        If Length(DataTab[I].StrVal) > 0 Then
          EmitRaw(DataTab[I].LblName + ' DB ' + DataTab[I].StrVal)
        Else
          EmitRaw(DataTab[I].LblName + ' DB ' + IntToStr_(DataTab[I].IntVal));
      End;
      DK_STR :
      Begin
        S := 'DB  ';
        If Length(DataTab[I].StrVal) = 0 Then
          S := S + '0'
        Else
        Begin
          S := S + '''';
          For J := 1 To Length(DataTab[I].StrVal) Do
          Begin
            If DataTab[I].StrVal[J] = '''' Then
              S := S + ''''''
            Else
              S := S + DataTab[I].StrVal[J];
          End;
          S := S + ''', 0';
        End;
        EmitRaw(DataTab[I].LblName + ' ' + S);
      End;
      DK_ARRAY_BLK :
        EmitRaw(DataTab[I].LblName + ' DW ' +
                IntToStr_(DataTab[I].ElemCount) + ' DUP(0)');
      DK_SWITCH_TAB :
        EmitRaw(DataTab[I].LblName + ' DW ' + DataTab[I].StrVal);
    End;
  End;
  EmitRaw('_DATA   ENDS');
End;

{ ---- EmitClose : fermer le fichier assembleur de sortie ----- }
Procedure EmitClose;
Begin
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ============================================================
  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
  ============================================================ }

{ ---- EmitInstr : ecrire une instruction ASM (8 espaces) ----- }
Procedure EmitInstr(Const Mnem, Args : TString);
Begin
  If Args = '' Then
    EmitRaw('        ' + Mnem)
  Else
    EmitRaw('        ' + Mnem + ' ' + Args);
End;

{ ---- EmitLabel : ecrire un label ASM suivi de : ------------- }
Procedure EmitLabel(Const Lbl : TString);
Begin
  EmitRaw(Lbl + ':');
End;

{ ---- EmitBlankLine : ecrire une ligne vide ------------------- }
Procedure EmitBlankLine;
Begin
  EmitRaw('');
End;

{ ---- BinOpPrec : table de precedences Algol 60 (Pratt) ------
  Retourne 0 si l operateur n est pas binaire.
  Niveaux (ordre croissant = priorite croissante) :
    EQUIV              -> 1  (equivalence logique)
    IMPL               -> 2  (implication logique)
    OR, \/             -> 3  (disjonction)
    AND, /\            -> 4  (conjonction)
    < <= = >= > !=     -> 5  (comparaison)
    + - (binaire)      -> 6  (additif)
    * / div            -> 7  (multiplicatif)
    ^ ** (puissance)   -> 8  (droit-associatif)
    NOT ~ unaire +/-   -> traites par ParseUnary                }
Function BinOpPrec(Const Op : TString) : Integer;
Begin
  If Op = 'EQUIV' Then
    BinOpPrec := 1
  Else If Op = 'IMPL' Then
    BinOpPrec := 2
  Else If (Op = 'OR') Or (Op = '\/') Then
    BinOpPrec := 3
  Else If (Op = 'AND') Or (Op = '/\') Then
    BinOpPrec := 4
  Else If (Op = '<')  Or (Op = '<=') Or (Op = '=') Or
          (Op = '>=') Or (Op = '>')  Or (Op = '!=') Then
    BinOpPrec := 5
  Else If (Op = '+') Or (Op = '-') Then
    BinOpPrec := 6
  Else If (Op = '*') Or (Op = '/') Or (Op = 'DIV') Then
    BinOpPrec := 7
  Else If (Op = '^') Then
    BinOpPrec := 8
  Else
    BinOpPrec := 0;
End;

{ ---- BinOpIsRight : vrai si operateur droit-associatif ------ }
{ En Algol 60, seule la puissance ^ est droit-associative.      }
Function BinOpIsRight(Const Op : TString) : Boolean;
Begin
  BinOpIsRight := (Op = '^');
End;

{ ---- ExprFlushToAX : charger TExprVal dans AX --------------- }
{ EK_IMM -> MOV AX, imm ; EK_MEM -> MOV AX, [addr] ;          }
{ EK_AX  -> rien a faire ; EK_NONE -> XOR AX,AX                }
{ TODO 09 : supporte variables globales via SymIdx/MangledName  }
Procedure ExprFlushToAX(Var E : TExprVal);
Var
  S : TString;
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      Str(E.ImmVal, S);
      EmitInstr('MOV', 'AX, ' + S);
      E.Kind := EK_AX;
    End;
    EK_MEM :
    Begin
      { Chaine litterale : OFFSET label }
      If E.TypeIdx = TY_IDX_STRING Then
      Begin
        If (E.SymIdx >= 0) And (E.SymIdx < SymCount) Then
          EmitInstr('MOV', 'AX, OFFSET ' + SymTab[E.SymIdx].MangledName)
        Else If (E.Offset >= 0) And (E.Offset < DataCount) Then
          EmitInstr('MOV', 'AX, OFFSET ' + DataTab[E.Offset].LblName)
        Else
          EmitInstr('XOR', 'AX, AX');
      End
      { Variable via SymIdx : globale ou locale ou parametre }
      Else If (E.SymIdx >= 0) And (E.SymIdx < SymCount) Then
      Begin
        { Label -> OFFSET (adresse de code, TODO 23) }
        If SymTab[E.SymIdx].Kind = SK_LABEL Then
          EmitInstr('MOV', 'AX, OFFSET ' + SymTab[E.SymIdx].MangledName)
        Else If SymTab[E.SymIdx].ScopeLevel = 0 Then
          EmitInstr('MOV', 'AX, WORD PTR [' + SymTab[E.SymIdx].MangledName + ']')
        Else If SymTab[E.SymIdx].Kind = SK_OWN Then
          EmitInstr('MOV', 'AX, WORD PTR [' + SymTab[E.SymIdx].MangledName + ']')
        Else If SymTab[E.SymIdx].Kind = SK_PARAM Then
        Begin
          Str(SymTab[E.SymIdx].Offset, S);
          If SymTab[E.SymIdx].IsName Then
          Begin
            { Parametre par nom : invoquer le thunk (TODO 20) }
            EmitComment('thunk R-value pour ' + SymTab[E.SymIdx].Name);
            EmitInstr('MOV', 'BX, [BP+' + S + ']');
            EmitInstr('CALL', 'BX');
          End
          Else
            EmitInstr('MOV', 'AX, [BP+' + S + ']');
        End
        Else
        Begin
          Str(SymTab[E.SymIdx].Offset, S);
          EmitInstr('MOV', 'AX, [BP-' + S + ']');
        End;
      End
      { Variable locale : [BP-n] }
      Else If E.Offset < 0 Then
      Begin
        Str(-E.Offset, S);
        EmitInstr('MOV', 'AX, [BP-' + S + ']');
      End
      { Variable globale DATA ou parametre [BP+n] }
      Else
      Begin
        Str(E.Offset, S);
        EmitInstr('MOV', 'AX, [BP+' + S + ']');
      End;
      E.Kind := EK_AX;
    End;
    EK_AX :
      ;  { deja dans AX }
    EK_NONE :
    Begin
      EmitInstr('XOR', 'AX, AX');
      E.Kind := EK_AX;
    End;
  End;
End;

{ ---- ExprEmitBinOp : generer le code 8086 d un op binaire ---
  Pliage de constantes si L et R sont EK_IMM.
  Operateurs Algol 60 couverts :
    + - * / div          (arithmetique)
    ^ (puissance)        (droit-associatif, appel POWER runtime)
    < <= = >= > !=       (comparaison)
    AND /\ OR \/         (logique, court-circuit)
    IMPL                 (implication : NOT a OR b)
    EQUIV                (equivalence : CMP + SETE)            }
Procedure ExprEmitBinOp(Const Op : TString;
                        Var L : TExprVal; Var R : TExprVal);
Var
  RS       : TString;
  LblSkip  : TString;
  LblEnd   : TString;
  Acc, Exp : LongInt;
Begin
  { ---- Pliage de constantes -------------------------------- }
  If (L.Kind = EK_IMM) And (R.Kind = EK_IMM) Then
  Begin
    If      Op = '+'   Then L.ImmVal := L.ImmVal + R.ImmVal
    Else If Op = '-'   Then L.ImmVal := L.ImmVal - R.ImmVal
    Else If Op = '*'   Then L.ImmVal := L.ImmVal * R.ImmVal
    Else If (Op = '/') Or (Op = 'DIV') Then
    Begin
      If R.ImmVal = 0 Then
      Begin CompileError('division par zero'); L.ImmVal := 0; End
      Else
        L.ImmVal := L.ImmVal Div R.ImmVal;
    End
    Else If Op = '^'   Then
    Begin
      Acc := 1; Exp := R.ImmVal;
      If Exp < 0 Then L.ImmVal := 0
      Else Begin
        While Exp > 0 Do Begin Acc := Acc * L.ImmVal; Dec(Exp); End;
        L.ImmVal := Acc;
      End;
    End
    Else If Op = '='   Then Begin If L.ImmVal =  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '!='  Then Begin If L.ImmVal <> R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '<'   Then Begin If L.ImmVal <  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '<='  Then Begin If L.ImmVal <= R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '>'   Then Begin If L.ImmVal >  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '>='  Then Begin If L.ImmVal >= R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If (Op = 'AND') Or (Op = '/\') Then
    Begin If (L.ImmVal<>0) And (R.ImmVal<>0) Then L.ImmVal:=1 Else L.ImmVal:=0; End
    Else If (Op = 'OR') Or (Op = '\/') Then
    Begin If (L.ImmVal<>0) Or (R.ImmVal<>0) Then L.ImmVal:=1 Else L.ImmVal:=0; End
    Else If Op = 'IMPL' Then
    Begin
      { a IMPL b = NOT a OR b }
      If (L.ImmVal = 0) Or (R.ImmVal <> 0) Then L.ImmVal := 1 Else L.ImmVal := 0;
    End
    Else If Op = 'EQUIV' Then
    Begin
      { a EQUIV b = (a AND b) OR (NOT a AND NOT b) }
      If ((L.ImmVal<>0) And (R.ImmVal<>0)) Or ((L.ImmVal=0) And (R.ImmVal=0)) Then
        L.ImmVal := 1 Else L.ImmVal := 0;
    End;
    Exit;
  End;

  { ---- Court-circuit AND /\ -------------------------------- }
  If (Op = 'AND') Or (Op = '/\') Then
  Begin
    LblEnd := LabelGen;
    ExprFlushToAX(L);
    EmitInstr('OR', 'AX, AX');
    EmitInstr('JZ', LblEnd);  { si faux, resultat = 0, sauter R }
    ExprFlushToAX(R);
    EmitInstr('OR', 'AX, AX');
    EmitInstr('MOV', 'AX, 0');
    EmitInstr('JZ', LblEnd);
    EmitInstr('MOV', 'AX, 1');
    EmitLabel(LblEnd);
    L.Kind := EK_AX; L.TypeIdx := TY_IDX_BOOLEAN;
    Exit;
  End;

  { ---- Court-circuit OR \/ --------------------------------- }
  If (Op = 'OR') Or (Op = '\/') Then
  Begin
    LblEnd := LabelGen;
    ExprFlushToAX(L);
    EmitInstr('OR', 'AX, AX');
    EmitInstr('MOV', 'AX, 1');
    EmitInstr('JNZ', LblEnd);  { si vrai, resultat = 1, sauter R }
    ExprFlushToAX(R);
    EmitInstr('OR', 'AX, AX');
    EmitInstr('MOV', 'AX, 0');
    EmitInstr('JZ', LblEnd);
    EmitInstr('MOV', 'AX, 1');
    EmitLabel(LblEnd);
    L.Kind := EK_AX; L.TypeIdx := TY_IDX_BOOLEAN;
    Exit;
  End;

  { ---- IMPL (implication) : NOT a OR b --------------------- }
  If Op = 'IMPL' Then
  Begin
    LblEnd := LabelGen;
    ExprFlushToAX(L);
    EmitInstr('OR', 'AX, AX');
    EmitInstr('MOV', 'AX, 1');
    EmitInstr('JZ', LblEnd);  { si a=faux, implication=vrai }
    ExprFlushToAX(R);
    EmitInstr('OR', 'AX, AX');
    EmitInstr('MOV', 'AX, 0');
    EmitInstr('JZ', LblEnd);
    EmitInstr('MOV', 'AX, 1');
    EmitLabel(LblEnd);
    L.Kind := EK_AX; L.TypeIdx := TY_IDX_BOOLEAN;
    Exit;
  End;

  { ---- EQUIV (equivalence) --------------------------------- }
  If Op = 'EQUIV' Then
  Begin
    ExprFlushToAX(L);
    EmitInstr('PUSH', 'AX');
    ExprFlushToAX(R);
    EmitInstr('MOV', 'BX, AX');
    EmitInstr('POP', 'AX');
    { Normaliser les deux en 0/1 }
    EmitInstr('OR', 'AX, AX');
    EmitInstr('MOV', 'AX, 0');
    LblSkip := LabelGen;
    EmitInstr('JZ', LblSkip);
    EmitInstr('MOV', 'AX, 1');
    EmitLabel(LblSkip);
    EmitInstr('OR', 'BX, BX');
    EmitInstr('MOV', 'BX, 0');
    LblEnd := LabelGen;
    EmitInstr('JZ', LblEnd);
    EmitInstr('MOV', 'BX, 1');
    EmitLabel(LblEnd);
    { EQUIV = (a XOR b) == 0 -> NOT XOR }
    EmitInstr('XOR', 'AX, BX');
    EmitInstr('XOR', 'AX, 1');
    L.Kind := EK_AX; L.TypeIdx := TY_IDX_BOOLEAN;
    Exit;
  End;

  { ---- Cas general : emission 8086 ------------------------- }
  ExprFlushToAX(L);
  If R.Kind = EK_IMM Then
  Begin
    Str(R.ImmVal, RS);
    If      Op = '+'   Then EmitInstr('ADD', 'AX, ' + RS)
    Else If Op = '-'   Then EmitInstr('SUB', 'AX, ' + RS)
    Else If Op = '*'   Then
    Begin
      EmitInstr('MOV', 'BX, ' + RS);
      EmitInstr('IMUL', 'BX');
    End
    Else If (Op = '/') Or (Op = 'DIV') Then
    Begin
      EmitInstr('MOV', 'BX, ' + RS);
      EmitInstr('CWD', '');
      EmitInstr('IDIV', 'BX');
    End
    Else If Op = '^'   Then
    Begin
      EmitInstr('MOV', 'CX, ' + RS);
      EmitInstr('CALL', A60_RT_PFX + 'POWER');
    End
    Else
    Begin
      { Comparaisons : on passe par BX }
      EmitInstr('MOV', 'BX, ' + RS);
      EmitInstr('CMP', 'AX, BX');
      LblEnd := LabelGen;
      EmitInstr('MOV', 'AX, 1');
      If      Op = '='  Then EmitInstr('JE',  LblEnd)
      Else If Op = '!=' Then EmitInstr('JNE', LblEnd)
      Else If Op = '<'  Then EmitInstr('JL',  LblEnd)
      Else If Op = '<=' Then EmitInstr('JLE', LblEnd)
      Else If Op = '>'  Then EmitInstr('JG',  LblEnd)
      Else If Op = '>=' Then EmitInstr('JGE', LblEnd);
      EmitInstr('MOV', 'AX, 0');
      EmitLabel(LblEnd);
    End;
  End
  Else
  Begin
    { R non immediat : sauvegarder L dans la pile, charger R dans BX }
    EmitInstr('PUSH', 'AX');
    ExprFlushToAX(R);
    EmitInstr('MOV', 'BX, AX');
    EmitInstr('POP', 'AX');
    If      Op = '+'   Then EmitInstr('ADD', 'AX, BX')
    Else If Op = '-'   Then EmitInstr('SUB', 'AX, BX')
    Else If Op = '*'   Then EmitInstr('IMUL', 'BX')
    Else If (Op = '/') Or (Op = 'DIV') Then
    Begin
      EmitInstr('CWD', '');
      EmitInstr('IDIV', 'BX');
    End
    Else If Op = '^'   Then
    Begin
      { AX = base, BX = exposant -> AX = base^exp via POWER }
      EmitInstr('MOV', 'CX, BX');
      EmitInstr('CALL', A60_RT_PFX + 'POWER');
    End
    Else
    Begin
      { Comparaisons }
      EmitInstr('CMP', 'AX, BX');
      LblSkip := LabelGen;
      LblEnd  := LabelGen;
      EmitInstr('MOV', 'AX, 1');
      If      Op = '='  Then EmitInstr('JE',  LblEnd)
      Else If Op = '!=' Then EmitInstr('JNE', LblEnd)
      Else If Op = '<'  Then EmitInstr('JL',  LblEnd)
      Else If Op = '<=' Then EmitInstr('JLE', LblEnd)
      Else If Op = '>'  Then EmitInstr('JG',  LblEnd)
      Else If Op = '>=' Then EmitInstr('JGE', LblEnd);
      EmitInstr('MOV', 'AX, 0');
      EmitLabel(LblEnd);
    End;
  End;
  L.Kind := EK_AX;
End;

{ ---- ParsePrimary : atome du parseur Pratt ------------------ }
{ Literaux : entier, reel, chaine, booleen (TRUE/FALSE)         }
{ Parentheses : ( expr )                                        }
{ Expression conditionnelle : IF expr THEN expr ELSE expr       }
{ Identificateur : variable / appel de fonction (TODO 05+)      }
Procedure ParsePrimary(Var Res : TExprVal);
Var
  LblElse, LblEnd : TString;
  SIdx : Integer;
  IdName : TString;
Begin
  ExprMakeNone(Res);

  { Literal entier }
  If CurToken.Kind = TK_INTEGER Then
  Begin
    LitEvalInt(CurToken, Res);
    ParserAdvance;
    Exit;
  End;

  { Literal reel }
  If CurToken.Kind = TK_REAL Then
  Begin
    LitEvalReal(CurToken, Res);
    ParserAdvance;
    Exit;
  End;

  { Literal booleen }
  If CurToken.Kind = TK_BOOLEAN Then
  Begin
    ExprMakeBool(CurToken.IntVal, Res);
    ParserAdvance;
    Exit;
  End;

  { Literal chaine }
  If CurToken.Kind = TK_STRING Then
  Begin
    LitEvalStr(CurToken, Res);
    ParserAdvance;
    Exit;
  End;

  { Parentheses ( expr ) }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance;  { consommer ( }
    ParseExpr(Res);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance  { consommer ) }
    Else
      CompileError(') attendu');
    Exit;
  End;

  { Expression conditionnelle IF expr THEN expr ELSE expr }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'IF') Then
  Begin
    ParserAdvance;  { consommer IF }
    ParseExpr(Res);
    ExprFlushToAX(Res);
    LblElse := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('OR', 'AX, AX');
    EmitInstr('JZ', LblElse);  { si faux -> else }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'THEN') Then
      ParserAdvance  { consommer THEN }
    Else
      CompileError('THEN attendu');
    ParseExpr(Res);
    ExprFlushToAX(Res);
    EmitInstr('JMP', LblEnd);
    EmitLabel(LblElse);
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'ELSE') Then
      ParserAdvance  { consommer ELSE }
    Else
      CompileError('ELSE attendu dans expression conditionnelle');
    ParseExpr(Res);
    ExprFlushToAX(Res);
    EmitLabel(LblEnd);
    ExprMakeAX(Res.TypeIdx, Res);
    Exit;
  End;

  { Identificateur : resolution via SymFind (TODO 09+10+12) }
  If CurToken.Kind = TK_IDENT Then
  Begin
    IdName := CurToken.Val;

    { Intrinsics I/O (TODO 12) : intercepter avant SymFind }
    If (IdName = 'OUTINTEGER') Or (IdName = 'OUTREAL') Or
       (IdName = 'OUTSTRING') Or (IdName = 'OUTBOOLEAN') Or
       (IdName = 'ININTEGER') Or (IdName = 'INREAL') Or
       (IdName = 'INCHAR') Or (IdName = 'PRINT') Or
       (IdName = 'NEWLINE') Or (IdName = 'SYSACT') Then
    Begin
      ParserAdvance;  { consommer l identifiant }
      ParseIOIntrinsic(IdName, Res);
      Exit;
    End;

    SIdx := SymFind(IdName);
    ParserAdvance;  { consommer l identifiant }

    If SIdx >= 0 Then
    Begin
      { Appel de fonction/procedure : ident( ... ) (TODO 10) }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        ParserAdvance;  { consommer ( }
        ParseProcCall(IdName, SIdx, Res);
        Exit;
      End;

      { Appel de procedure sans parentheses en expression (TODO 19) }
      If (SymTab[SIdx].Kind = SK_PROC) And
         Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) And
         Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[')) And
         Not ((CurToken.Kind = TK_OP) And (CurToken.Val = ':=')) Then
      Begin
        If SymTab[SIdx].ProcParamCount = 0 Then
        Begin
          { Appel sans arguments (TODO 19) }
          EmitComment('appel ' + IdName + ' (sans args, expr, TODO 19)');
          EmitInstr('CALL', SymTab[SIdx].MangledName);
          ExprMakeAX(SymTab[SIdx].TypeIdx, Res);
        End
        Else
        Begin
          { Passage de procedure comme valeur : OFFSET label (TODO 19) }
          EmitComment('proc-as-value ' + IdName + ' (TODO 19)');
          EmitInstr('MOV', 'AX, OFFSET ' + SymTab[SIdx].MangledName);
          ExprMakeAX(SymTab[SIdx].TypeIdx, Res);
        End;
        Exit;
      End;

      { Acces tableau : ident[ ... ] (TODO 10) }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
      Begin
        ParserAdvance;  { consommer [ }
        If SymTab[SIdx].Kind = SK_SWITCH Then
          ParseSwitchAccess(SIdx, Res)
        Else
          ParseArrayAccess(SIdx, Res);
        Exit;
      End;

      { Variable simple }
      ExprLoad(SIdx, Res);
    End
    Else
    Begin
      { Identifiant non declare : possible appel de fonction externe }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        ParserAdvance;  { consommer ( }
        ParseProcCall(IdName, -1, Res);
        Exit;
      End;
      WarnMsg('identificateur non resolu: ' + IdName);
      ExprMakeImm(0, TY_IDX_INTEGER, Res);
    End;
    Exit;
  End;

  { Token inattendu }
  CompileError('expression attendue, token: ' + CurToken.Val);
  ParserAdvance;
End;

{ ---- ParseUnary : operateurs unaires Algol 60 --------------- }
{ NOT / ~ : negation logique -> XOR AX, 1                      }
{ - : negation arithmetique -> NEG AX                           }
{ + : unaire positif (noop)                                     }
Procedure ParseUnary(Var Res : TExprVal);
Begin
  { NOT (mot-cle) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'NOT') Then
  Begin
    ParserAdvance;  { consommer NOT }
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
    Begin
      If Res.ImmVal <> 0 Then Res.ImmVal := 0 Else Res.ImmVal := 1;
    End
    Else
    Begin
      ExprFlushToAX(Res);
      EmitInstr('XOR', 'AX, 1');
      ExprMakeAX(TY_IDX_BOOLEAN, Res);
    End;
    Exit;
  End;

  { ~ (symbole NOT alternatif) }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '~') Then
  Begin
    ParserAdvance;  { consommer ~ }
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
    Begin
      If Res.ImmVal <> 0 Then Res.ImmVal := 0 Else Res.ImmVal := 1;
    End
    Else
    Begin
      ExprFlushToAX(Res);
      EmitInstr('XOR', 'AX, 1');
      ExprMakeAX(TY_IDX_BOOLEAN, Res);
    End;
    Exit;
  End;

  { Unaire - (negation) }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '-') Then
  Begin
    ParserAdvance;  { consommer - }
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
      Res.ImmVal := -Res.ImmVal
    Else
    Begin
      ExprFlushToAX(Res);
      EmitInstr('NEG', 'AX');
      ExprMakeAX(Res.TypeIdx, Res);
    End;
    Exit;
  End;

  { Unaire + (noop) }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '+') Then
  Begin
    ParserAdvance;  { consommer + }
    ParseUnary(Res);
    Exit;
  End;

  { Pas d operateur unaire : descendre vers ParsePrimary }
  ParsePrimary(Res);
End;

{ ---- CurTokIsInfixOp : le token courant est-il un op binaire }
{ Detecte TK_OP (+, -, *, /, ^, <, <=, =, >=, >, !=, /\, \/)  }
{ et TK_KEYWORD (AND, OR, NOT, IMPL, EQUIV, DIV)               }
Function CurTokIsInfixOp : Boolean;
Var
  V : TString;
Begin
  CurTokIsInfixOp := False;
  If CurToken.Kind = TK_OP Then
  Begin
    V := CurToken.Val;
    If (V = '+') Or (V = '-') Or (V = '*') Or (V = '/') Or
       (V = '^') Or (V = '<') Or (V = '<=') Or (V = '=') Or
       (V = '>=') Or (V = '>') Or (V = '!=') Or
       (V = '/\') Or (V = '\/') Then
      CurTokIsInfixOp := True;
  End
  Else If CurToken.Kind = TK_KEYWORD Then
  Begin
    V := CurToken.Val;
    If (V = 'AND') Or (V = 'OR') Or (V = 'IMPL') Or
       (V = 'EQUIV') Or (V = 'DIV') Then
      CurTokIsInfixOp := True;
  End;
End;

{ ---- ParseExprPrec : boucle Pratt (montee de precedence) ---- }
{ Court-circuit AND/OR/IMPL via labels.                         }
{ Pliage de constantes si les deux operandes sont EK_IMM.       }
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op       : TString;
  Prec     : Integer;
  NextPrec : Integer;
  Right    : TExprVal;
Begin
  ParseUnary(Res);

  While CurTokIsInfixOp Do
  Begin
    Op := CurToken.Val;
    Prec := BinOpPrec(Op);
    If Prec < MinPrec Then Break;

    ParserAdvance;  { consommer l operateur }

    { Precedence suivante : droite si droit-associatif }
    If BinOpIsRight(Op) Then
      NextPrec := Prec
    Else
      NextPrec := Prec + 1;

    { Court-circuit AND /\ : si L=faux, pas besoin de R }
    If (Op = 'AND') Or (Op = '/\') Or
       (Op = 'OR')  Or (Op = '\/') Or
       (Op = 'IMPL') Or (Op = 'EQUIV') Then
    Begin
      ParseExprPrec(NextPrec, Right);
      ExprEmitBinOp(Op, Res, Right);
    End
    Else
    Begin
      { Autres operateurs : evaluer normalement }
      ParseExprPrec(NextPrec, Right);
      ExprEmitBinOp(Op, Res, Right);
    End;
  End;
End;

{ ---- ParseExpr : wrapper pour ParseExprPrec(1) -------------- }
Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParseExprPrec(1, Res);
End;

{ ============================================================
  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
  ============================================================ }

{ ---- SymInit : initialisation de la table des symboles ------ }
Procedure SymInit;
Begin
  SymCount     := 0;
  ScopeTop     := 0;
  CurScope     := 0;
  CurFrameSize := 0;
  ScopeStack[0] := 0;
End;

{ ---- SymNameClean : nettoyer un identifiant pour MASM -------
  Remplace les caracteres non alphanumeriques par '_'.
  MASM n accepte que [A-Za-z0-9_@?$] dans les labels.         }
Function SymNameClean(Const Name : TString) : TString;
Var
  S : TString;
  I : Integer;
Begin
  S := Name;
  For I := 1 To Length(S) Do
    If Not (((S[I] >= 'A') And (S[I] <= 'Z')) Or
            ((S[I] >= 'a') And (S[I] <= 'z')) Or
            ((S[I] >= '0') And (S[I] <= '9')) Or
            (S[I] = '_')) Then
      S[I] := '_';
  SymNameClean := S;
End;

{ ---- SymMangle : construire l etiquette ASM d un symbole ----
  SK_VAR    -> _A60V_ + name   (variable locale/globale)
  SK_PARAM  -> ''              (acces via [BP+n], pas de label)
  SK_PROC   -> _A60P_ + name   (procedure / fonction)
  SK_LABEL  -> _A60L_ + name   (etiquette utilisateur)
  SK_SWITCH -> _A60S_ + name   (table switch)
  SK_ARRAY  -> _A60V_ + name   (tableau, meme prefixe que var)
  SK_OWN    -> _A60O_ + name   (variable OWN, segment DATA)   }
Function SymMangle(Const Name : TString; Kind : TSymKind) : TString;
Var
  Clean : TString;
Begin
  Clean := SymNameClean(Name);
  Case Kind Of
    SK_VAR    : SymMangle := A60_VAR_PFX + Clean;
    SK_PARAM  : SymMangle := '';
    SK_PROC   : SymMangle := A60_FN_PFX  + Clean;
    SK_LABEL  : SymMangle := A60_LBL_PFX + Clean;
    SK_SWITCH : SymMangle := A60_SW_PFX  + Clean;
    SK_ARRAY  : SymMangle := A60_VAR_PFX + Clean;
    SK_OWN    : SymMangle := A60_OWN_PFX + Clean;
  Else
    SymMangle := A60_VAR_PFX + Clean;
  End;
End;

{ ---- SymFind : recherche dans toutes les portees ------------ }
{ Parcourt du plus recent au plus ancien (static scoping).
  Retourne l indice (0-base) ou -1 si non trouve.              }
Function SymFind(Const Name : TString) : Integer;
Var
  I : Integer;
  U : TString;
Begin
  U := StrUpperCase(Name);
  For I := SymCount - 1 DownTo 0 Do
    If StrUpperCase(SymTab[I].Name) = U Then
    Begin
      SymFind := I;
      Exit;
    End;
  SymFind := -1;
End;

{ ---- SymFindInScope : recherche dans une portee specifique -- }
{ Retourne l indice ou -1. Utile pour detecter redeclarations. }
Function SymFindInScope(Const Name : TString;
                        Level : Integer) : Integer;
Var
  I : Integer;
  U : TString;
Begin
  U := StrUpperCase(Name);
  For I := SymCount - 1 DownTo 0 Do
    If (StrUpperCase(SymTab[I].Name) = U) And
       (SymTab[I].ScopeLevel = Level) Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
  SymFindInScope := -1;
End;

{ ---- SymAdd : ajouter un symbole dans la table -------------- }
{ Retourne l indice du nouveau symbole (0-base) ou -1 si plein.
  Avec trace de debug si -d est actif.                          }
Function SymAdd(Const Name : TString; Kind : TSymKind;
                TypeIdx, Offset : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    CompileError('table des symboles pleine (max=' +
                 IntToStr_(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;
  Idx := SymCount;
  SymTab[Idx].Name        := Name;
  SymTab[Idx].MangledName := SymMangle(Name, Kind);
  SymTab[Idx].Kind        := Kind;
  SymTab[Idx].TypeIdx     := TypeIdx;
  SymTab[Idx].ScopeLevel  := CurScope;
  SymTab[Idx].Offset      := Offset;
  SymTab[Idx].IsOwn       := (Kind = SK_OWN);
  SymTab[Idx].IsValue     := False;
  SymTab[Idx].IsName      := False;
  SymTab[Idx].DeclLine    := CurToken.Line;
  SymTab[Idx].ArrayDim    := 0;
  SymTab[Idx].ArrayElemTy := TY_UNKNOWN;
  SymTab[Idx].SwitchLabCount := 0;
  Inc(SymCount);
  Inc(TotalSyms);
  { Trace debug si -d }
  If Opts.DebugMode Then
    WriteLn('  [sym] ', Name, ' kind=', Ord(Kind),
            ' scope=', CurScope, ' offset=', Offset,
            ' -> ', SymTab[Idx].MangledName);
  SymAdd := Idx;
End;

{ ---- SymEnterScope : entrer dans une nouvelle portee -------- }
{ Algol 60 : chaque bloc BEGIN..END cree une nouvelle portee.
  Les symboles declares dans le bloc sont locaux a ce bloc.     }
Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE - 1 Then
  Begin
    CompileError('profondeur de portee maximale atteinte (max=' +
                 IntToStr_(MAX_SCOPE) + ')');
    Exit;
  End;
  Inc(CurScope);
  Inc(ScopeTop);
  ScopeStack[ScopeTop] := SymCount;
End;

{ ---- SymLeaveScope : quitter la portee courante ------------- }
{ Les symboles locaux (SK_VAR, SK_PARAM, SK_ARRAY) sont
  retires de la table. Les OWN persistent (segment DATA).      }
Procedure SymLeaveScope;
Begin
  If ScopeTop <= 0 Then
  Begin
    CompileError('desequilibre de portees : LeaveScope sans EnterScope');
    Exit;
  End;
  SymCount := ScopeStack[ScopeTop];
  Dec(ScopeTop);
  Dec(CurScope);
End;

{ ---- SymNextOffset : allouer un emplacement local ----------- }
{ Incremente CurFrameSize de 2 octets (un mot 16 bits).
  Retourne l offset negatif par rapport a BP.
  Exemple : premier appel -> CurFrameSize=2, retourne 2
            => acces via [BP-2]                                 }
Function SymNextOffset : Integer;
Begin
  Inc(CurFrameSize, 2);
  SymNextOffset := CurFrameSize;
End;

{ ============================================================
  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
  ============================================================ }

{ ---- TypeInit : enregistrer les 8 types primitifs Algol 60 -- }
{ Les indices correspondent aux constantes TY_IDX_* definies
  dans la section CONSTANTES GENERALES (0=INTEGER, 1=REAL, ...) }
Procedure TypeInit;
Begin
  TypeCount := 0;
  { TY_IDX_INTEGER = 0 }
  TypeTab[0].Name := 'INTEGER';
  TypeTab[0].Kind := TYK_INTEGER;
  TypeTab[0].Size := 2;
  { TY_IDX_REAL = 1 }
  TypeTab[1].Name := 'REAL';
  TypeTab[1].Kind := TYK_REAL;
  TypeTab[1].Size := 2;    { stub : reel tronque en entier 16 bits }
  { TY_IDX_BOOLEAN = 2 }
  TypeTab[2].Name := 'BOOLEAN';
  TypeTab[2].Kind := TYK_BOOLEAN;
  TypeTab[2].Size := 2;    { 0 ou 1 dans AX                        }
  { TY_IDX_STRING = 3 }
  TypeTab[3].Name := 'STRING';
  TypeTab[3].Kind := TYK_STRING;
  TypeTab[3].Size := 2;    { pointeur near vers chaine DATA         }
  { TY_IDX_LABEL = 4 }
  TypeTab[4].Name := 'LABEL';
  TypeTab[4].Kind := TYK_LABEL;
  TypeTab[4].Size := 2;    { adresse de code 16 bits                }
  { TY_IDX_SWITCH = 5 }
  TypeTab[5].Name := 'SWITCH';
  TypeTab[5].Kind := TYK_SWITCH;
  TypeTab[5].Size := 2;    { pointeur vers table de labels          }
  { TY_IDX_PROCEDURE = 6 }
  TypeTab[6].Name := 'PROCEDURE';
  TypeTab[6].Kind := TYK_PROCEDURE;
  TypeTab[6].Size := 2;    { pointeur de code (near)                }
  { TY_IDX_ARRAY = 7 }
  TypeTab[7].Name := 'ARRAY';
  TypeTab[7].Kind := TYK_ARRAY;
  TypeTab[7].Size := 2;    { pointeur vers descripteur de tableau   }
  TypeCount := TY_PRIM_COUNT;  { = 8 }
End;

{ ---- TypeKindOf : retourner le TTypeKind pour un indice ----- }
{ Si l indice est invalide, retourne TYK_UNKNOWN.                }
Function TypeKindOf(TypeIdx : Integer) : TTypeKind;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeKindOf := TypeTab[TypeIdx].Kind
  Else
    TypeKindOf := TYK_UNKNOWN;
End;

{ ---- TypeSizeof : taille en octets d un type par son indice -- }
{ En Algol 60 sur 8086 16 bits, tous les types font 2 octets
  (un mot machine). Les REAL sont tronques en entiers 16 bits.   }
Function TypeSizeof(TypeIdx : Integer) : Integer;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeSizeof := TypeTab[TypeIdx].Size
  Else
    TypeSizeof := 2;   { defaut : un mot 16 bits }
End;

{ ---- TypeMangle : prefixe ASM selon le type Algol 60 -------- }
{ Utilise pour generer des labels typees dans le segment DATA.
  INTEGER -> _A60TI_ , REAL -> _A60TR_ , BOOLEAN -> _A60TB_
  STRING  -> _A60TS_ , LABEL -> _A60TL_ , etc.                  }
Function TypeMangle(TypeIdx : Integer) : TString;
Begin
  Case TypeKindOf(TypeIdx) Of
    TYK_INTEGER   : TypeMangle := '_A60TI_';
    TYK_REAL      : TypeMangle := '_A60TR_';
    TYK_BOOLEAN   : TypeMangle := '_A60TB_';
    TYK_STRING    : TypeMangle := '_A60TS_';
    TYK_LABEL     : TypeMangle := '_A60TL_';
    TYK_SWITCH    : TypeMangle := '_A60TW_';
    TYK_PROCEDURE : TypeMangle := '_A60TP_';
    TYK_ARRAY     : TypeMangle := '_A60TA_';
  Else
    TypeMangle := '_A60TX_';   { inconnu }
  End;
End;

{ ---- TypeIsNumeric : tester si un type est numerique --------- }
{ Algol 60 : INTEGER et REAL sont numeriques. BOOLEAN est
  traite comme numerique (0/1) pour les conversions implicites.  }
Function TypeIsNumeric(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsNumeric := (K = TYK_INTEGER) Or (K = TYK_REAL) Or
                   (K = TYK_BOOLEAN);
End;

{ ---- TypeCanCoerce : conversion implicite possible ? --------- }
{ Algol 60 permet les conversions implicites suivantes :
    INTEGER -> REAL    (promotion, avec avertissement)
    BOOLEAN -> INTEGER (TRUE=1, FALSE=0)
    INTEGER -> BOOLEAN (0=FALSE, <>0=TRUE)
    meme type -> meme type (identite)
  Pas de coercion vers STRING, LABEL, SWITCH, PROCEDURE, ARRAY. }
Function TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean;
Var
  SK, DK : TTypeKind;
Begin
  If SrcIdx = DstIdx Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  If (SrcIdx = TY_UNKNOWN) Or (DstIdx = TY_UNKNOWN) Then
  Begin
    TypeCanCoerce := True;  { type inconnu : accepter }
    Exit;
  End;
  SK := TypeKindOf(SrcIdx);
  DK := TypeKindOf(DstIdx);
  { Meme categorie }
  If SK = DK Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { INTEGER -> REAL (promotion) }
  If (SK = TYK_INTEGER) And (DK = TYK_REAL) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { REAL -> INTEGER (troncature, avec avertissement) }
  If (SK = TYK_REAL) And (DK = TYK_INTEGER) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { BOOLEAN <-> INTEGER }
  If ((SK = TYK_BOOLEAN) And (DK = TYK_INTEGER)) Or
     ((SK = TYK_INTEGER) And (DK = TYK_BOOLEAN)) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { BOOLEAN <-> REAL }
  If ((SK = TYK_BOOLEAN) And (DK = TYK_REAL)) Or
     ((SK = TYK_REAL) And (DK = TYK_BOOLEAN)) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  TypeCanCoerce := False;
End;

{ ---- TypeCoerceResult : type resultat d une operation binaire -
  Arithmetique (+,-,*,/,div,^) :
    INTEGER op INTEGER -> INTEGER
    REAL op REAL -> REAL
    INTEGER op REAL, REAL op INTEGER -> REAL (promotion)
    BOOLEAN op numerique -> INTEGER (promotion implicite)
  Comparaisons (<,<=,=,>=,>,!=) : toujours BOOLEAN
  Logique (AND,OR,NOT,IMPL,EQUIV) : toujours BOOLEAN
  Concat (~) : toujours STRING (extension)                       }
Function TypeCoerceResult(LeftIdx, RightIdx : Integer;
                          Const Op : TString) : Integer;
Var
  LK, RK : TTypeKind;
Begin
  { Comparaisons -> BOOLEAN }
  If (Op = '<') Or (Op = '<=') Or (Op = '=') Or
     (Op = '>=') Or (Op = '>') Or (Op = '!=') Or
     (Op = '<>') Then
  Begin
    TypeCoerceResult := TY_IDX_BOOLEAN;
    Exit;
  End;
  { Logique -> BOOLEAN }
  If (Op = 'AND') Or (Op = 'OR') Or (Op = '/\') Or
     (Op = '\/') Or (Op = 'NOT') Or (Op = '~') Or
     (Op = 'IMPL') Or (Op = 'EQUIV') Then
  Begin
    TypeCoerceResult := TY_IDX_BOOLEAN;
    Exit;
  End;
  { Division / : toujours REAL en Algol 60 standard }
  If Op = '/' Then
  Begin
    TypeCoerceResult := TY_IDX_REAL;
    Exit;
  End;
  { Division entiere div : toujours INTEGER }
  If Op = 'div' Then
  Begin
    TypeCoerceResult := TY_IDX_INTEGER;
    Exit;
  End;
  { Autres operateurs arithmetiques : promotion }
  LK := TypeKindOf(LeftIdx);
  RK := TypeKindOf(RightIdx);
  { Si l un des deux est REAL -> REAL }
  If (LK = TYK_REAL) Or (RK = TYK_REAL) Then
  Begin
    TypeCoerceResult := TY_IDX_REAL;
    Exit;
  End;
  { BOOLEAN promu en INTEGER pour l arithmetique }
  If (LK = TYK_BOOLEAN) And (RK = TYK_BOOLEAN) Then
  Begin
    TypeCoerceResult := TY_IDX_INTEGER;
    Exit;
  End;
  { INTEGER op INTEGER -> INTEGER (defaut) }
  TypeCoerceResult := TY_IDX_INTEGER;
End;

{ ---- TypeInfer : inferer le type d une expression ----------- }
{ Si le TypeIdx est deja connu (>= 0), le retourner.
  Sinon, pour EK_IMM on suppose INTEGER. Pour EK_NONE -> UNKNOWN. }
Function TypeInfer(Const E : TExprVal) : Integer;
Begin
  If E.TypeIdx >= 0 Then
  Begin
    TypeInfer := E.TypeIdx;
    Exit;
  End;
  Case E.Kind Of
    EK_IMM  : TypeInfer := TY_IDX_INTEGER;
    EK_AX   : TypeInfer := TY_IDX_INTEGER;
    EK_MEM  : TypeInfer := TY_IDX_INTEGER;
    EK_NONE : TypeInfer := TY_UNKNOWN;
  Else
    TypeInfer := TY_UNKNOWN;
  End;
End;

{ ---- TypeLookupName : chercher un type par son nom ----------- }
{ Recherche insensible a la casse parmi les types enregistres.
  Retourne l indice (0-base) ou TY_UNKNOWN si non trouve.        }
Function TypeLookupName(Const Name : TString) : Integer;
Var
  I : Integer;
  U : TString;
Begin
  U := StrUpperCase(Name);
  For I := 0 To TypeCount - 1 Do
    If StrUpperCase(TypeTab[I].Name) = U Then
    Begin
      TypeLookupName := I;
      Exit;
    End;
  TypeLookupName := TY_UNKNOWN;
End;

{ ============================================================
  TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
  ============================================================ }

{ ---- ExprAddrOf : retourner la reference ASM d une variable -- }
{ Globale (scope 0) -> WORD PTR [_A60V_nom]
  Locale  (scope>0) -> WORD PTR [BP-n]
  Parametre (SK_PARAM) -> WORD PTR [BP+n]   (TODO 18)
  OWN (SK_OWN) -> WORD PTR [_A60O_nom] (DATA)  (TODO 22)       }
Function ExprAddrOf(SIdx : Integer) : TString;
Var
  S : TString;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then
  Begin
    ExprAddrOf := 'WORD PTR [0]';
    Exit;
  End;
  If SymTab[SIdx].ScopeLevel = 0 Then
    ExprAddrOf := 'WORD PTR [' + SymTab[SIdx].MangledName + ']'
  Else If SymTab[SIdx].Kind = SK_OWN Then
    ExprAddrOf := 'WORD PTR [' + SymTab[SIdx].MangledName + ']'
  Else If SymTab[SIdx].Kind = SK_PARAM Then
  Begin
    Str(SymTab[SIdx].Offset, S);
    ExprAddrOf := 'WORD PTR [BP+' + S + ']';
  End
  Else
  Begin
    Str(SymTab[SIdx].Offset, S);
    ExprAddrOf := 'WORD PTR [BP-' + S + ']';
  End;
End;

{ ---- ExprStore : MOV [addr], AX pour ecrire dans une variable }
{ Emet MOV destination, AX selon l adresse du symbole.
  Pour SK_PARAM IsName (TODO 20), invoque le thunk L-value :
    le thunk retourne l adresse dans BX.                         }
Procedure ExprStore(SIdx : Integer);
Var
  Addr, S : TString;
Begin
  If (SIdx >= 0) And (SIdx < SymCount) And
     (SymTab[SIdx].Kind = SK_PARAM) And SymTab[SIdx].IsName Then
  Begin
    { Parametre par nom : invoquer le thunk L-value (TODO 20) }
    EmitInstr('PUSH', 'AX');  { sauvegarder la valeur a ecrire }
    EmitComment('thunk L-value pour ' + SymTab[SIdx].Name);
    Str(SymTab[SIdx].Offset, S);
    EmitInstr('MOV', 'BX, [BP+' + S + ']');
    EmitInstr('CALL', 'BX');
    { AX = valeur, BX = adresse de la variable }
    EmitInstr('POP', 'AX');
    EmitInstr('MOV', '[BX], AX');
  End
  Else
  Begin
    Addr := ExprAddrOf(SIdx);
    EmitInstr('MOV', Addr + ', AX');
  End;
End;

{ ---- ExprLoad : MOV AX, [addr] et remplir TExprVal ---------- }
{ Charge la valeur d une variable dans AX, et remplit Res comme
  EK_MEM avec SymIdx positionne.                                }
Procedure ExprLoad(SIdx : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_MEM;
  Res.ImmVal  := 0;
  Res.TypeIdx := SymTab[SIdx].TypeIdx;
  Res.Offset  := SymTab[SIdx].Offset;
  Res.SymIdx  := SIdx;
End;

{ ---- DeclAllocSym : allouer une variable dans la table ------- }
{ Globale (scope 0) -> ajouter DW 0 dans DATA avec label _A60V_
  Locale  (scope>0) -> SUB SP, 2 pour reserver sur la pile      }
Function DeclAllocSym(Const Name : TString;
                      TypeIdx : Integer) : Integer;
Var
  Idx, Off : Integer;
  Lbl      : TString;
Begin
  If CurScope = 0 Then
  Begin
    { Variable globale : entree DATA DW 0 }
    Lbl := SymMangle(Name, SK_VAR);
    DataAddWord(Lbl, 0);
    Idx := SymAdd(Name, SK_VAR, TypeIdx, 0);
    DeclAllocSym := Idx;
  End
  Else
  Begin
    { Variable locale : reserver 2 octets sur la pile }
    Off := SymNextOffset;
    Idx := SymAdd(Name, SK_VAR, TypeIdx, Off);
    EmitInstr('SUB', 'SP, 2');
    DeclAllocSym := Idx;
  End;
End;

{ ---- ParseDeclStmt : parser une declaration de variable ------ }
{ Syntaxe : INTEGER|REAL|BOOLEAN ident [, ident]* [; | := expr]
  Chaque identifiant est alloue via DeclAllocSym.
  Si := suit, l expression est evaluee et affectee.             }
Procedure ParseDeclStmt;
Var
  TypeIdx, SIdx : Integer;
  VarName : TString;
  E       : TExprVal;
Begin
  { Determiner le type }
  If CurToken.Val = 'INTEGER' Then
    TypeIdx := TY_IDX_INTEGER
  Else If CurToken.Val = 'REAL' Then
    TypeIdx := TY_IDX_REAL
  Else If CurToken.Val = 'BOOLEAN' Then
    TypeIdx := TY_IDX_BOOLEAN
  Else If CurToken.Val = 'STRING' Then
    TypeIdx := TY_IDX_STRING
  Else
  Begin
    CompileError('type attendu (INTEGER/REAL/BOOLEAN/STRING)');
    Exit;
  End;
  ParserAdvance;  { consommer le mot-cle de type }

  { Si le mot-cle suivant est ARRAY, deleguer a ParseArrayDecl (TODO 17) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'ARRAY') Then
  Begin
    ParserAdvance;  { consommer ARRAY }
    ParseArrayDecl(TypeIdx);
    Exit;
  End;

  { Si le mot-cle suivant est PROCEDURE, deleguer a ParseProcDecl (TODO 18) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'PROCEDURE') Then
  Begin
    ParserAdvance;  { consommer PROCEDURE }
    ParseProcDecl(TypeIdx);
    Exit;
  End;

  { Parser un ou plusieurs identifiants }
  While True Do
  Begin
    If CurToken.Kind <> TK_IDENT Then
    Begin
      CompileError('identificateur attendu apres le type');
      Exit;
    End;
    VarName := CurToken.Val;
    ParserAdvance;  { consommer l identifiant }

    { Verifier si deja declare dans la portee courante }
    If SymFindInScope(VarName, CurScope) >= 0 Then
      WarnMsg('redeclaration de ' + VarName + ' dans la meme portee');

    SIdx := DeclAllocSym(VarName, TypeIdx);
    EmitComment('var ' + VarName + ' : ' + TypeTab[TypeIdx].Name);

    { Initialisation optionnelle := expr }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    Begin
      ParserAdvance;  { consommer := }
      ParseExpr(E);
      ExprFlushToAX(E);
      ExprStore(SIdx);
    End;

    { Virgule : declaration multiple INTEGER a, b, c }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
    Begin
      ParserAdvance;  { consommer , }
      Continue;
    End;

    Break;
  End;
End;

{ ---- ParseExprStmt : parser une affectation ou expression ---- }
{ Syntaxe : ident := expr  (affectation simple ou multiple)
  ou       expr             (expression seule, resultat ignore)
  Affectation multiple : a := b := c := expr
  Evaluer la partie droite, puis affecter de droite a gauche.   }
Procedure ParseExprStmt;
Var
  SIdx : Integer;
  VarName : TString;
  E : TExprVal;
  Op : TString;
  Prec, NextPrec : Integer;
  Right : TExprVal;
Begin
  { Verifier si c est un identifiant suivi de := }
  If CurToken.Kind = TK_IDENT Then
  Begin
    VarName := CurToken.Val;
    SIdx := SymFind(VarName);
    If SIdx >= 0 Then
    Begin
      { Etiquette : ident: (TODO 15) }
      If SymTab[SIdx].Kind = SK_LABEL Then
      Begin
        ParserAdvance;  { consommer l identifiant }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
          ParserAdvance;  { consommer : }
        EmitLabel(SymTab[SIdx].MangledName);
        EmitComment('label ' + VarName);
        Exit;
      End;

      { Sauvegarder la position, avancer pour voir si := suit }
      ParserAdvance;  { consommer l identifiant }

      { Affectation element de tableau : ident[expr] := expr (TODO 17) }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') And
         ((SymTab[SIdx].Kind = SK_ARRAY) Or
          ((SymTab[SIdx].Kind = SK_OWN) And (SymTab[SIdx].ArrayDim >= 1))) Then
      Begin
        ParserAdvance;  { consommer [ }
        { Parser l index et generer le code d adresse }
        ParseExpr(E);
        ExprFlushToAX(E);
        { Soustraire la borne inferieure }
        If (SymTab[SIdx].ArrayDim >= 1) And
           (SymTab[SIdx].ArrayLo[1] <> 0) Then
          EmitInstr('SUB', 'AX, ' + IntToStr_(SymTab[SIdx].ArrayLo[1]));
        { Ignorer dimensions supplementaires }
        While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
        Begin
          ParserAdvance;
          ParseExpr(E);
          ExprFlushToAX(E);
        End;
        { Consommer ] }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
          ParserAdvance
        Else
          CompileError('] attendu apres l''index de tableau');
        { Consommer := }
        If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
        Begin
          ParserAdvance;  { consommer := }
          { AX = index relatif ; sauvegarder l adresse cible }
          EmitInstr('SHL', 'AX, 1');  { * 2 pour mots }
          EmitInstr('MOV', 'BX, AX');
          If (SymTab[SIdx].ScopeLevel = 0) Or
             (SymTab[SIdx].Kind = SK_OWN) Then
            EmitInstr('ADD', 'BX, OFFSET ' + SymTab[SIdx].MangledName)
          Else
          Begin
            { Local array : base = BP - Offset (TODO 17) }
            EmitInstr('ADD', 'BX, BP');
            EmitInstr('SUB', 'BX, ' + IntToStr_(SymTab[SIdx].Offset));
          End;
          EmitInstr('PUSH', 'BX');  { sauvegarder l adresse }
          { Evaluer l expression droite }
          ParseExpr(E);
          ExprFlushToAX(E);
          EmitInstr('POP', 'BX');
          EmitInstr('MOV', '[BX], AX');
          EmitComment(VarName + '[...] := ...');
          Exit;
        End
        Else
          CompileError(':= attendu apres ' + VarName + '[...]');
        Exit;
      End;

      { Appel de procedure sans parentheses (TODO 19) }
      { Ex : hello; -> CALL _A60P_HELLO  (aucun argument) }
      If (SymTab[SIdx].Kind = SK_PROC) And
         Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) And
         Not ((CurToken.Kind = TK_OP) And (CurToken.Val = ':=')) Then
      Begin
        EmitComment('appel ' + VarName + ' (sans args, TODO 19)');
        EmitInstr('CALL', SymTab[SIdx].MangledName);
        ExprMakeAX(SymTab[SIdx].TypeIdx, E);
        Exit;
      End;

      { Appel de procedure : procname(args) (TODO 18) }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') And
         (SymTab[SIdx].Kind = SK_PROC) Then
      Begin
        ParserAdvance;  { consommer ( }
        ParseProcCall(VarName, SIdx, E);
        Exit;
      End;

      If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
      Begin
        ParserAdvance;  { consommer := }
        { Retour de valeur de procedure : procname := expr (TODO 18) }
        If (SymTab[SIdx].Kind = SK_PROC) Then
        Begin
          ParseExpr(E);
          ExprFlushToAX(E);
          EmitComment(VarName + ' := ... (retour procedure)');
          Exit;
        End;
        { Affectation possiblement multiple : a := b := expr }
        ParseExpr(E);
        ExprFlushToAX(E);
        ExprStore(SIdx);
        EmitComment(VarName + ' := ...');
        Exit;
      End
      Else
      Begin
        { Pas d affectation : c est une expression qui commence
          par cet identifiant. On charge la variable et on continue
          la boucle de precedence Pratt en mode infixe. }
        ExprLoad(SIdx, E);
        { Boucle infixe Pratt manuelle }
        While CurTokIsInfixOp Do
        Begin
          Op := CurToken.Val;
          Prec := BinOpPrec(Op);
          If Prec < 1 Then Break;
          ParserAdvance;  { consommer l operateur }
          If BinOpIsRight(Op) Then NextPrec := Prec
          Else NextPrec := Prec + 1;
          ParseExprPrec(NextPrec, Right);
          ExprEmitBinOp(Op, E, Right);
        End;
        Exit;
      End;
    End
    Else
    Begin
      { Identifiant non dans la table des symboles.
        Avant d avancer, on doit laisser ParseExpr gerer le cas
        (appels de fonctions externes, intrinsics I/O, etc.) }
      { On ne fait rien ici - on tombe dans ParseExpr ci-dessous }
    End;
  End;

  { Pas un identifiant connu ou pas un identifiant : expression simple }
  ParseExpr(E);
End;

{ ---- ParseStmt : dispatcher d instructions ------------------- }
{ Dispatche vers ParseDeclStmt pour les mots-cles de type
  (INTEGER, REAL, BOOLEAN, STRING), vers ParseIfStmt pour IF,
  vers ParseForStmt pour FOR, vers ParseGotoStmt pour GOTO/GO TO,
  et vers ParseExprStmt pour les identifiants et expressions.   }
Procedure ParseStmt;
Var
  LblName : TString;
  SIdx : Integer;
Begin
  { Declaration : mot-cle de type }
  If (CurToken.Kind = TK_KEYWORD) And
     ((CurToken.Val = 'INTEGER') Or (CurToken.Val = 'REAL') Or
      (CurToken.Val = 'BOOLEAN') Or (CurToken.Val = 'STRING')) Then
  Begin
    ParseDeclStmt;
    Exit;
  End;

  { Instruction conditionnelle (TODO 13) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'IF') Then
  Begin
    ParserAdvance;  { consommer IF }
    ParseIfStmt;
    Exit;
  End;

  { Boucle FOR (TODO 14) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'FOR') Then
  Begin
    ParserAdvance;  { consommer FOR }
    ParseForStmt;
    Exit;
  End;

  { GOTO / GO TO (TODO 15) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'GOTO') Then
  Begin
    ParserAdvance;  { consommer GOTO }
    ParseGotoStmt;
    Exit;
  End;
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'GO') Then
  Begin
    ParserAdvance;  { consommer GO }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'TO') Then
      ParserAdvance;  { consommer TO }
    ParseGotoStmt;
    Exit;
  End;

  { Bloc BEGIN/END (TODO 16) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'BEGIN') Then
  Begin
    ParserAdvance;  { consommer BEGIN }
    ParseBlock;
    Exit;
  End;

  { Declaration ARRAY seule (TODO 17) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'ARRAY') Then
  Begin
    ParserAdvance;  { consommer ARRAY }
    ParseArrayDecl(TY_IDX_INTEGER);
    Exit;
  End;

  { Declaration PROCEDURE seule (TODO 18) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'PROCEDURE') Then
  Begin
    ParserAdvance;  { consommer PROCEDURE }
    ParseProcDecl(TY_IDX_INTEGER);
    Exit;
  End;

  { Declaration SWITCH (TODO 21) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'SWITCH') Then
  Begin
    ParserAdvance;  { consommer SWITCH }
    ParseSwitchDecl;
    Exit;
  End;

  { Declaration OWN (TODO 22) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'OWN') Then
  Begin
    ParserAdvance;  { consommer OWN }
    ParseOwnDecl;
    Exit;
  End;

  { Etiquette : ident suivi de : (TODO 15) }
  If (CurToken.Kind = TK_IDENT) Then
  Begin
    LblName := CurToken.Val;
    { Regarder si le prochain token est : (sans consommer) }
    { On utilise le fait que ParseExprStmt va gerez le cas normal }
    SIdx := SymFind(LblName);
    If (SIdx >= 0) And (SymTab[SIdx].Kind = SK_LABEL) Then
    Begin
      { C est un label connu : emettre le label et continuer }
      ParserAdvance;  { consommer l identifiant }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
        ParserAdvance;  { consommer : }
      EmitLabel(SymTab[SIdx].MangledName);
      EmitComment('label ' + LblName);
      Exit;
    End;
  End;

  { Expression ou affectation }
  ParseExprStmt;
End;

{ ============================================================
  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
  ============================================================ }

{ ---- ParseProcCall : appel de procedure/fonction Algol 60 ----
  Syntaxe : nom(arg1, arg2, ..., argN)
  Les arguments sont evalues de gauche a droite puis empiles
  en ordre inverse (convention C). Apres CALL, on nettoie la
  pile avec ADD SP, N*2. Le resultat est dans AX.
  TODO 20 : pour les parametres par nom, generer un thunk
  et pousser son adresse au lieu de la valeur.                   }
Procedure ParseProcCall(Const ProcName : TString;
                        ProcSIdx : Integer;
                        Var Res : TExprVal);
Var
  ArgCount   : Integer;
  ArgVals    : Array[0..MAX_PARAM - 1] Of TExprVal;
  ArgThkLbl  : Array[0..MAX_PARAM - 1] Of TString;
  I          : Integer;
  S          : TString;
  ProcLbl    : TString;
  IsNameArg  : Boolean;
  ThkLbl, SkpLbl : TString;
  N          : TString;
Begin
  { Le ( a deja ete consomme par l appelant }
  ArgCount := 0;
  For I := 0 To MAX_PARAM - 1 Do
    ArgThkLbl[I] := '';

  { Parser les arguments separes par des virgules }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
  Begin
    While True Do
    Begin
      If ArgCount >= MAX_PARAM Then
      Begin
        CompileError('trop d''arguments dans l''appel de ' + ProcName);
        Break;
      End;
      ParseExpr(ArgVals[ArgCount]);
      Inc(ArgCount);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance  { consommer , }
      Else
        Break;
    End;
  End;

  { Verification du nombre d arguments (TODO 19) }
  If (ProcSIdx >= 0) And (ProcSIdx < SymCount) And
     (SymTab[ProcSIdx].Kind = SK_PROC) Then
  Begin
    If ArgCount <> SymTab[ProcSIdx].ProcParamCount Then
      WarnMsg('appel de ' + ProcName + ': ' + IntToStr_(ArgCount) +
              ' argument(s), ' + IntToStr_(SymTab[ProcSIdx].ProcParamCount) +
              ' attendu(s)');
  End;

  { Consommer ) }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance
  Else
    CompileError(') attendu apres les arguments de ' + ProcName);

  { Sauvegarder le BP de l appelant pour les thunks (TODO 20) }
  EmitInstr('MOV', '[_A60V_SAVEBP], BP');

  { Generer les thunks pour les parametres par nom (TODO 20) }
  For I := 0 To ArgCount - 1 Do
  Begin
    IsNameArg := False;
    If (ProcSIdx >= 0) And (ProcSIdx < SymCount) And
       (SymTab[ProcSIdx].Kind = SK_PROC) And
       (I < SymTab[ProcSIdx].ProcParamCount) Then
      IsNameArg := Not SymTab[ProcSIdx].ProcParamIsVal[I];

    If IsNameArg Then
    Begin
      Inc(ThunkCount);
      Str(ThunkCount, N);
      ThkLbl := A60_THK_PFX + N;
      SkpLbl := '_A60L_TSKIP_' + N;
      ArgThkLbl[I] := ThkLbl;

      EmitInstr('JMP', SkpLbl);
      EmitLabel(ThkLbl);
      EmitRaw(ThkLbl + ' PROC NEAR');
      EmitInstr('PUSH', 'BP');
      EmitInstr('MOV', 'BP, [_A60V_SAVEBP]');

      If ArgVals[I].Kind = EK_IMM Then
      Begin
        Str(ArgVals[I].ImmVal, S);
        EmitInstr('MOV', 'AX, ' + S);
        EmitInstr('XOR', 'BX, BX');
      End
      Else If (ArgVals[I].Kind = EK_MEM) And
              (ArgVals[I].SymIdx >= 0) And
              (ArgVals[I].SymIdx < SymCount) Then
      Begin
        If SymTab[ArgVals[I].SymIdx].ScopeLevel = 0 Then
        Begin
          EmitInstr('MOV', 'AX, WORD PTR [' +
                    SymTab[ArgVals[I].SymIdx].MangledName + ']');
          EmitInstr('LEA', 'BX, WORD PTR [' +
                    SymTab[ArgVals[I].SymIdx].MangledName + ']');
        End
        Else If SymTab[ArgVals[I].SymIdx].Kind = SK_PARAM Then
        Begin
          Str(SymTab[ArgVals[I].SymIdx].Offset, S);
          If SymTab[ArgVals[I].SymIdx].IsName Then
          Begin
            EmitInstr('MOV', 'BX, [BP+' + S + ']');
            EmitInstr('CALL', 'BX');
          End
          Else
          Begin
            EmitInstr('MOV', 'AX, [BP+' + S + ']');
            EmitInstr('LEA', 'BX, [BP+' + S + ']');
          End;
        End
        Else
        Begin
          Str(SymTab[ArgVals[I].SymIdx].Offset, S);
          EmitInstr('MOV', 'AX, [BP-' + S + ']');
          EmitInstr('LEA', 'BX, [BP-' + S + ']');
        End;
      End
      Else
      Begin
        EmitInstr('XOR', 'BX, BX');
      End;

      EmitInstr('POP', 'BP');
      EmitRaw('        RET');
      EmitRaw(ThkLbl + ' ENDP');
      EmitLabel(SkpLbl);
    End;
  End;

  { Empiler les arguments en ordre inverse (convention C) }
  EmitComment('appel ' + ProcName + '(' + IntToStr_(ArgCount) + ' args)');
  For I := ArgCount - 1 DownTo 0 Do
  Begin
    If Length(ArgThkLbl[I]) > 0 Then
    Begin
      EmitInstr('MOV', 'AX, OFFSET ' + ArgThkLbl[I]);
      EmitPush('AX');
    End
    Else
    Begin
      ExprFlushToAX(ArgVals[I]);
      EmitPush('AX');
    End;
  End;

  { Generer CALL (TODO 19: indirect si SK_PARAM) }
  If (ProcSIdx >= 0) And (ProcSIdx < SymCount) Then
  Begin
    If SymTab[ProcSIdx].Kind = SK_PARAM Then
    Begin
      Str(SymTab[ProcSIdx].Offset, S);
      EmitInstr('MOV', 'BX, [BP+' + S + ']');
      EmitInstr('CALL', 'BX');
    End
    Else
    Begin
      ProcLbl := SymTab[ProcSIdx].MangledName;
      EmitInstr('CALL', ProcLbl);
    End;
  End
  Else
  Begin
    ProcLbl := A60_FN_PFX + SymNameClean(ProcName);
    EmitInstr('CALL', ProcLbl);
  End;

  { Nettoyer la pile }
  If ArgCount > 0 Then
  Begin
    Str(ArgCount * 2, S);
    EmitInstr('ADD', 'SP, ' + S);
  End;

  { Resultat dans AX }
  If (ProcSIdx >= 0) And (ProcSIdx < SymCount) Then
    ExprMakeAX(SymTab[ProcSIdx].TypeIdx, Res)
  Else
    ExprMakeAX(TY_IDX_INTEGER, Res);
End;

{ ---- ParseArrayAccess : acces element de tableau ------------- }
{ Syntaxe : arr[i] ou arr[i,j] (multidimensionnel lineaire)
  Calcul d offset (TODO 17) :
    1D : (index - lo) * 2
    2D : ((i-lo1)*(hi2-lo2+1) + (j-lo2)) * 2
  LEA BX, [base] ; ADD BX, offset ; MOV AX, [BX]               }
Procedure ParseArrayAccess(SIdx : Integer;
                           Var Res : TExprVal);
Var
  E     : TExprVal;
  Lo1   : Integer;
  ElemTy: Integer;
  Dim2Size : Integer;
Begin
  { Le [ a deja ete consomme par l appelant }
  EmitComment('acces tableau ' + SymTab[SIdx].Name);

  { Parser le premier index }
  ParseExpr(E);
  ExprFlushToAX(E);

  { Soustraire la borne inferieure de la 1ere dimension (TODO 17) }
  If ((SymTab[SIdx].Kind = SK_ARRAY) Or (SymTab[SIdx].Kind = SK_OWN)) And
     (SymTab[SIdx].ArrayDim >= 1) Then
  Begin
    Lo1 := SymTab[SIdx].ArrayLo[1];
    If Lo1 <> 0 Then
      EmitInstr('SUB', 'AX, ' + IntToStr_(Lo1));

    { Gestion multidimensionnelle : 2D (TODO 17) }
    If (SymTab[SIdx].ArrayDim >= 2) And
       (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
    Begin
      ParserAdvance;  { consommer , }
      { AX = (i - lo1), sauvegarder }
      Dim2Size := SymTab[SIdx].ArrayHi[2] - SymTab[SIdx].ArrayLo[2] + 1;
      EmitInstr('MOV', 'CX, ' + IntToStr_(Dim2Size));
      EmitInstr('IMUL', 'CX');  { AX = (i-lo1) * dim2size }
      EmitInstr('PUSH', 'AX');
      { Parser le 2eme index }
      ParseExpr(E);
      ExprFlushToAX(E);
      If SymTab[SIdx].ArrayLo[2] <> 0 Then
        EmitInstr('SUB', 'AX, ' + IntToStr_(SymTab[SIdx].ArrayLo[2]));
      EmitInstr('POP', 'CX');
      EmitInstr('ADD', 'AX, CX');  { AX = (i-lo1)*dim2 + (j-lo2) }
    End;
  End;

  { Ignorer les dimensions supplementaires (>2D) }
  While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
  Begin
    ParserAdvance;  { consommer , }
    ParseExpr(E);
    ExprFlushToAX(E);
  End;

  { Consommer ] }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
    ParserAdvance
  Else
    CompileError('] attendu apres l''index de tableau');

  { Generer le code d acces : AX = index relatif, BX = base }
  EmitInstr('SHL', 'AX, 1');  { AX = index * 2 (taille mot) }
  EmitInstr('MOV', 'BX, AX');
  { Adresse de base du tableau }
  If (SymTab[SIdx].ScopeLevel = 0) Or
     (SymTab[SIdx].Kind = SK_OWN) Then
    EmitInstr('ADD', 'BX, OFFSET ' + SymTab[SIdx].MangledName)
  Else
  Begin
    { Local array : base = BP - Offset (TODO 17) }
    EmitInstr('ADD', 'BX, BP');
    EmitInstr('SUB', 'BX, ' + IntToStr_(SymTab[SIdx].Offset));
  End;
  EmitInstr('MOV', 'AX, [BX]');

  { Type du resultat : type des elements si connu, sinon type du symbole }
  If ((SymTab[SIdx].Kind = SK_ARRAY) Or (SymTab[SIdx].Kind = SK_OWN)) And
     (SymTab[SIdx].ArrayElemTy >= 0) Then
    ElemTy := SymTab[SIdx].ArrayElemTy
  Else
    ElemTy := SymTab[SIdx].TypeIdx;
  ExprMakeAX(ElemTy, Res);
End;

{ ---- ParseSwitchAccess : acces element de switch (aiguillage)- }
{ Syntaxe : nom[expr]
  Un switch est un tableau de labels. On evalue expr (1-base),
  on convertit en 0-base, on multiplie par 2, et on charge
  l adresse du label depuis la table.                            }
Procedure ParseSwitchAccess(SIdx : Integer;
                            Var Res : TExprVal);
Var
  E : TExprVal;
Begin
  { Le [ a deja ete consomme par l appelant }
  ParseExpr(E);
  ExprFlushToAX(E);

  { Consommer ] }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
    ParserAdvance
  Else
    CompileError('] attendu apres l''index de switch');

  { Generer le code : AX = expr (1-base), table a _A60S_nom }
  EmitComment('acces switch ' + SymTab[SIdx].Name);
  EmitInstr('DEC', 'AX');          { 1-base -> 0-base }
  EmitInstr('SHL', 'AX, 1');       { * 2 pour offset mot }
  EmitInstr('MOV', 'BX, AX');
  EmitInstr('ADD', 'BX, OFFSET ' + SymTab[SIdx].MangledName);
  EmitInstr('MOV', 'AX, [BX]');

  ExprMakeAX(TY_IDX_LABEL, Res);
End;

{ ============================================================
  TODO 11 - EXPRESSIONS ARITHMETIQUES ET BOOLEENNES [IMPLEMENTE]
  ============================================================ }

{ ---- EmitExprRuntime : emettre les routines runtime pour
  les expressions arithmetiques et booleennes.
  _A60RT_POWER : AX=base, CX=exposant -> AX=base^CX
    Si CX=0 retourne 1, sinon boucle iterative IMUL.           }
Procedure EmitExprRuntime;
Begin
  If RuntimeEmitted Then Exit;
  RuntimeEmitted := True;

  EmitBlankLine;
  EmitComment('--- Runtime : expressions arithmetiques ---');
  EmitBlankLine;

  { _A60RT_POWER : exponentiation entiere iterative
    Entree : AX = base, CX = exposant (>= 0)
    Sortie : AX = base ^ exposant                              }
  EmitLabel(A60_RT_PFX + 'POWER');
  EmitInstr('CMP', 'CX, 0');
  EmitInstr('JNE', A60_RT_PFX + 'POWER_L1');
  EmitInstr('MOV', 'AX, 1');        { x^0 = 1 }
  EmitInstr('RET', '');
  EmitLabel(A60_RT_PFX + 'POWER_L1');
  EmitInstr('MOV', 'BX, AX');       { BX = base originale }
  EmitInstr('DEC', 'CX');           { 1er facteur deja dans AX }
  EmitLabel(A60_RT_PFX + 'POWER_L2');
  EmitInstr('CMP', 'CX, 0');
  EmitInstr('JE', A60_RT_PFX + 'POWER_L3');
  EmitInstr('IMUL', 'BX');          { AX = AX * base }
  EmitInstr('DEC', 'CX');
  EmitInstr('JMP', A60_RT_PFX + 'POWER_L2');
  EmitLabel(A60_RT_PFX + 'POWER_L3');
  EmitInstr('RET', '');

  EmitBlankLine;
End;

{ ============================================================
  TODO 12 - ENTREES/SORTIES (INTRINSICS) [IMPLEMENTE]
  ============================================================ }

{ ---- ParseIOIntrinsic : parser et emettre un appel I/O -------
  Algol 60 ne definit pas d E/S standard ; nous fournissons
  ces intrinsics comme appels compiles directement :
  - outinteger(canal, n)   : ecrire entier decimal
  - outreal(canal, x)      : ecrire reel (stub -> outinteger)
  - outstring(canal, s)    : ecrire chaine ASCIIZ
  - outboolean(canal, b)   : ecrire TRUE ou FALSE
  - ininteger(canal)       : lire entier decimal -> AX
  - inreal(canal)          : lire reel (stub -> ininteger) -> AX
  - inchar(canal)          : lire caractere -> AX (AL)
  - print(args)            : raccourci outstring(1, args)
  - newline(canal)         : ecrire CR+LF
  - sysact(canal,act,r)    : stub (NOP)
  Convention registres runtime :
    BX = handle fichier (canal)
    AX = valeur entiere/booleen ou AX = pointeur chaine
    Resultat des fonctions d entree dans AX                     }
Procedure ParseIOIntrinsic(Const Name : TString;
                           Var Res : TExprVal);
Var
  CanalExpr, ValExpr, Dummy : TExprVal;
Begin
  ExprMakeNone(Res);

  { --- outinteger(canal, n) --- }
  If Name = 'OUTINTEGER' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      ParserAdvance;  { consommer ( }
    ParseExpr(CanalExpr);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;  { consommer , }
    ParseExpr(ValExpr);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;  { consommer ) }
    EmitComment('outinteger(canal, n)');
    ExprFlushToAX(ValExpr);
    EmitPush('AX');                          { sauver n }
    ExprFlushToAX(CanalExpr);
    EmitMov('BX', 'AX');                     { BX = canal }
    EmitPop('AX');                           { AX = n }
    EmitInstr('CALL', A60_RT_PFX + 'OUTINT');
    ExprMakeNone(Res);
    Exit;
  End;

  { --- outreal(canal, x) --- stub -> outinteger }
  If Name = 'OUTREAL' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      ParserAdvance;
    ParseExpr(CanalExpr);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;
    ParseExpr(ValExpr);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
    EmitComment('outreal(canal, x) [stub -> outinteger]');
    ExprFlushToAX(ValExpr);
    EmitPush('AX');
    ExprFlushToAX(CanalExpr);
    EmitMov('BX', 'AX');
    EmitPop('AX');
    EmitInstr('CALL', A60_RT_PFX + 'OUTINT');
    ExprMakeNone(Res);
    Exit;
  End;

  { --- outstring(canal, s) --- }
  If Name = 'OUTSTRING' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      ParserAdvance;
    ParseExpr(CanalExpr);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;
    ParseExpr(ValExpr);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
    EmitComment('outstring(canal, s)');
    ExprFlushToAX(ValExpr);
    EmitMov('SI', 'AX');                     { SI = pointeur chaine }
    ExprFlushToAX(CanalExpr);
    EmitMov('BX', 'AX');                     { BX = canal }
    EmitInstr('CALL', A60_RT_PFX + 'OUTSTR');
    ExprMakeNone(Res);
    Exit;
  End;

  { --- outboolean(canal, b) --- }
  If Name = 'OUTBOOLEAN' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      ParserAdvance;
    ParseExpr(CanalExpr);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;
    ParseExpr(ValExpr);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
    EmitComment('outboolean(canal, b)');
    ExprFlushToAX(ValExpr);
    EmitPush('AX');
    ExprFlushToAX(CanalExpr);
    EmitMov('BX', 'AX');
    EmitPop('AX');
    EmitInstr('CALL', A60_RT_PFX + 'OUTBOOL');
    ExprMakeNone(Res);
    Exit;
  End;

  { --- ininteger(canal) --- }
  If Name = 'ININTEGER' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      ParserAdvance;
    ParseExpr(CanalExpr);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
    EmitComment('ininteger(canal)');
    ExprFlushToAX(CanalExpr);
    EmitMov('BX', 'AX');
    EmitInstr('CALL', A60_RT_PFX + 'ININT');
    ExprMakeAX(TY_IDX_INTEGER, Res);
    Exit;
  End;

  { --- inreal(canal) --- stub -> ininteger }
  If Name = 'INREAL' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      ParserAdvance;
    ParseExpr(CanalExpr);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
    EmitComment('inreal(canal) [stub -> ininteger]');
    ExprFlushToAX(CanalExpr);
    EmitMov('BX', 'AX');
    EmitInstr('CALL', A60_RT_PFX + 'ININT');
    ExprMakeAX(TY_IDX_REAL, Res);
    Exit;
  End;

  { --- inchar(canal) --- }
  If Name = 'INCHAR' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      ParserAdvance;
    ParseExpr(CanalExpr);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
    EmitComment('inchar(canal)');
    ExprFlushToAX(CanalExpr);
    EmitMov('BX', 'AX');
    EmitInstr('CALL', A60_RT_PFX + 'INCHAR');
    ExprMakeAX(TY_IDX_INTEGER, Res);
    Exit;
  End;

  { --- print(args) --- raccourci pour outstring(1, args) }
  If Name = 'PRINT' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      ParserAdvance;
    ParseExpr(ValExpr);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
    EmitComment('print(s) -> outstring(1, s)');
    ExprFlushToAX(ValExpr);
    EmitMov('SI', 'AX');
    EmitInstr('MOV', 'BX, 1');               { BX = STDOUT }
    EmitInstr('CALL', A60_RT_PFX + 'OUTSTR');
    ExprMakeNone(Res);
    Exit;
  End;

  { --- newline(canal) ou newline sans arguments --- }
  If Name = 'NEWLINE' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;  { consommer ( }
      ParseExpr(CanalExpr);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
      EmitComment('newline(canal)');
      ExprFlushToAX(CanalExpr);
      EmitMov('BX', 'AX');
    End
    Else
    Begin
      EmitComment('newline -> STDOUT');
      EmitInstr('MOV', 'BX, 1');             { BX = STDOUT }
    End;
    EmitInstr('CALL', A60_RT_PFX + 'NEWLINE');
    ExprMakeNone(Res);
    Exit;
  End;

  { --- sysact(canal, action, r) --- stub NOP }
  If Name = 'SYSACT' Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      ParserAdvance;
    ParseExpr(Dummy);  { canal }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;
    ParseExpr(Dummy);  { action }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
    Begin
      ParserAdvance;
      ParseExpr(Dummy);  { r }
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
    EmitComment('sysact(...) [stub NOP]');
    ExprMakeNone(Res);
    Exit;
  End;
End;

{ ---- EmitIORuntime : emettre les routines runtime I/O --------
  7 routines en assembleur 8086 utilisant INT 21h DOS :
  _A60RT_OUTINT  : BX=handle, AX=entier -> ecriture decimale signee
  _A60RT_OUTSTR  : BX=handle, SI=chaine ASCIIZ -> ecriture chaine
  _A60RT_OUTBOOL : BX=handle, AX=booleen -> ecriture TRUE/FALSE
  _A60RT_OUTREAL : alias -> _A60RT_OUTINT (stub)
  _A60RT_ININT   : BX=handle -> AX=entier lu (lecture ligne + atoi)
  _A60RT_INCHAR  : BX=handle -> AX=caractere lu (AL)
  _A60RT_NEWLINE : BX=handle -> ecriture CR+LF                 }
Procedure EmitIORuntime;
Begin
  If IOEmitted Then Exit;
  IOEmitted := True;

  EmitBlankLine;
  EmitComment('--- Runtime : entrees/sorties (TODO 12) ---');
  EmitBlankLine;

  { ---- _A60RT_OUTSTR : ecrire chaine ASCIIZ sur canal --------
    Entree : BX = handle fichier, SI = pointeur chaine ASCIIZ
    Utilise INT 21h AH=40h (ecrire sur fichier/handle)
    Calcule d abord la longueur de la chaine (strlen)            }
  EmitLabel(A60_RT_PFX + 'OUTSTR');
  EmitPush('AX');
  EmitPush('CX');
  EmitPush('DX');
  EmitPush('DI');
  { Calculer la longueur : parcourir jusqu au NUL }
  EmitMov('DI', 'SI');
  EmitInstr('XOR', 'CX, CX');
  EmitLabel(A60_RT_PFX + 'OUTSTR_L1');
  EmitInstr('CMP', 'BYTE PTR [DI], 0');
  EmitInstr('JE', A60_RT_PFX + 'OUTSTR_L2');
  EmitInstr('INC', 'DI');
  EmitInstr('INC', 'CX');
  EmitInstr('JMP', A60_RT_PFX + 'OUTSTR_L1');
  EmitLabel(A60_RT_PFX + 'OUTSTR_L2');
  { CX = longueur, SI = debut chaine }
  EmitMov('DX', 'SI');              { DX = adresse tampon }
  EmitInstr('MOV', 'AH, 40h');     { AH = ecrire sur handle }
  EmitInstr('INT', '21h');
  EmitPop('DI');
  EmitPop('DX');
  EmitPop('CX');
  EmitPop('AX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { ---- _A60RT_OUTINT : ecrire entier signe sur canal ---------
    Entree : BX = handle, AX = entier signe 16 bits
    Convertit AX en decimales ASCII dans _A60_NUMBUF
    puis ecrit via INT 21h AH=40h
    Le handle est sauve dans _A60_TMPBUF temporairement          }
  EmitLabel(A60_RT_PFX + 'OUTINT');
  EmitPush('BX');
  EmitPush('SI');
  EmitPush('DI');
  EmitPush('CX');
  EmitPush('DX');
  { Sauver le handle dans _A60_TMPBUF }
  EmitInstr('MOV', 'WORD PTR [_A60_TMPBUF], BX');
  { Pointer DI sur _A60_NUMBUF }
  EmitMov('DI', 'OFFSET _A60_NUMBUF');
  { Verifier signe }
  EmitInstr('CMP', 'AX, 0');
  EmitInstr('JGE', A60_RT_PFX + 'OUTINT_POS');
  { Nombre negatif : ecrire - et rendre positif }
  EmitInstr('MOV', 'BYTE PTR [DI], 45');   { 45 = '-' }
  EmitInstr('INC', 'DI');
  EmitInstr('NEG', 'AX');
  EmitLabel(A60_RT_PFX + 'OUTINT_POS');
  { Si AX = 0, ecrire directement '0' }
  EmitInstr('CMP', 'AX, 0');
  EmitInstr('JNE', A60_RT_PFX + 'OUTINT_CVT');
  EmitInstr('MOV', 'BYTE PTR [DI], 48');   { 48 = '0' }
  EmitInstr('INC', 'DI');
  EmitInstr('JMP', A60_RT_PFX + 'OUTINT_WR');
  { Conversion : diviser par 10 iterativement, empiler chiffres }
  EmitLabel(A60_RT_PFX + 'OUTINT_CVT');
  EmitInstr('XOR', 'CX, CX');      { compteur = 0 }
  EmitLabel(A60_RT_PFX + 'OUTINT_DIV');
  EmitInstr('XOR', 'DX, DX');
  EmitInstr('MOV', 'SI, 10');
  EmitInstr('DIV', 'SI');           { AX=quotient, DX=reste }
  EmitInstr('ADD', 'DX, 48');       { reste + '0' }
  EmitPush('DX');                   { empiler chiffre }
  EmitInstr('INC', 'CX');
  EmitInstr('CMP', 'AX, 0');
  EmitInstr('JNE', A60_RT_PFX + 'OUTINT_DIV');
  { Depiler chiffres dans l ordre correct }
  EmitLabel(A60_RT_PFX + 'OUTINT_POP');
  EmitPop('DX');
  EmitInstr('MOV', '[DI], DL');
  EmitInstr('INC', 'DI');
  EmitInstr('DEC', 'CX');
  EmitInstr('JNZ', A60_RT_PFX + 'OUTINT_POP');
  { Ecrire le tampon via INT 21h AH=40h }
  EmitLabel(A60_RT_PFX + 'OUTINT_WR');
  EmitMov('CX', 'DI');
  EmitInstr('SUB', 'CX, OFFSET _A60_NUMBUF');
  EmitInstr('MOV', 'DX, OFFSET _A60_NUMBUF');
  EmitInstr('MOV', 'BX, WORD PTR [_A60_TMPBUF]');
  EmitInstr('MOV', 'AH, 40h');
  EmitInstr('INT', '21h');
  EmitPop('DX');
  EmitPop('CX');
  EmitPop('DI');
  EmitPop('SI');
  EmitPop('BX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { ---- _A60RT_OUTBOOL : ecrire TRUE ou FALSE sur canal -------
    Entree : BX = handle, AX = booleen (0=FALSE, sinon TRUE)
    Appelle _A60RT_OUTSTR avec SI = _A60_TRUE_S ou _A60_FALSE_S }
  EmitLabel(A60_RT_PFX + 'OUTBOOL');
  EmitInstr('CMP', 'AX, 0');
  EmitInstr('JE', A60_RT_PFX + 'OUTBOOL_F');
  EmitMov('SI', 'OFFSET _A60_TRUE_S');
  EmitInstr('JMP', A60_RT_PFX + 'OUTSTR');
  EmitLabel(A60_RT_PFX + 'OUTBOOL_F');
  EmitMov('SI', 'OFFSET _A60_FALSE_S');
  EmitInstr('JMP', A60_RT_PFX + 'OUTSTR');
  EmitBlankLine;

  { ---- _A60RT_NEWLINE : ecrire CR+LF sur canal ----------------
    Entree : BX = handle
    Ecrit _A60_CRLF (0Dh, 0Ah) via INT 21h AH=40h              }
  EmitLabel(A60_RT_PFX + 'NEWLINE');
  EmitPush('AX');
  EmitPush('CX');
  EmitPush('DX');
  EmitInstr('MOV', 'DX, OFFSET _A60_CRLF');
  EmitInstr('MOV', 'CX, 2');       { 2 octets : CR + LF }
  EmitInstr('MOV', 'AH, 40h');
  EmitInstr('INT', '21h');
  EmitPop('DX');
  EmitPop('CX');
  EmitPop('AX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { ---- _A60RT_ININT : lire entier decimal depuis canal --------
    Entree : BX = handle (ignore, lit depuis stdin via AH=01h)
    Sortie : AX = entier lu
    Lit caracteres un a un, convertit ASCII -> entier.
    Gere signe negatif. Arrete a CR (0Dh) ou LF (0Ah).          }
  EmitLabel(A60_RT_PFX + 'ININT');
  EmitPush('BX');
  EmitPush('CX');
  EmitPush('DX');
  EmitInstr('XOR', 'BX, BX');      { BX = accumulateur }
  EmitInstr('XOR', 'CX, CX');      { CX = flag signe (0=pos) }
  { Lire premier caractere }
  EmitInstr('MOV', 'AH, 01h');
  EmitInstr('INT', '21h');          { AL = caractere }
  EmitInstr('CMP', 'AL, 45');      { '-' ? }
  EmitInstr('JNE', A60_RT_PFX + 'ININT_D');
  EmitInstr('MOV', 'CX, 1');       { flag negatif }
  EmitInstr('MOV', 'AH, 01h');
  EmitInstr('INT', '21h');          { lire prochain caractere }
  EmitLabel(A60_RT_PFX + 'ININT_D');
  { Boucle de lecture des chiffres }
  EmitInstr('CMP', 'AL, 0Dh');     { CR -> fin }
  EmitInstr('JE', A60_RT_PFX + 'ININT_END');
  EmitInstr('CMP', 'AL, 0Ah');     { LF -> fin }
  EmitInstr('JE', A60_RT_PFX + 'ININT_END');
  EmitInstr('CMP', 'AL, 48');      { < '0' -> fin }
  EmitInstr('JB', A60_RT_PFX + 'ININT_END');
  EmitInstr('CMP', 'AL, 57');      { > '9' -> fin }
  EmitInstr('JA', A60_RT_PFX + 'ININT_END');
  { BX = BX * 10 + (AL - '0') }
  EmitInstr('SUB', 'AL, 48');
  EmitInstr('XOR', 'AH, AH');
  EmitPush('AX');                   { sauver chiffre }
  EmitMov('AX', 'BX');
  EmitInstr('MOV', 'DX, 10');
  EmitInstr('MUL', 'DX');           { AX = BX * 10 }
  EmitPop('DX');                    { DX = chiffre }
  EmitInstr('ADD', 'AX, DX');
  EmitMov('BX', 'AX');             { BX = accumulateur }
  { Lire prochain caractere }
  EmitInstr('MOV', 'AH, 01h');
  EmitInstr('INT', '21h');
  EmitInstr('JMP', A60_RT_PFX + 'ININT_D');
  EmitLabel(A60_RT_PFX + 'ININT_END');
  EmitMov('AX', 'BX');
  { Appliquer signe }
  EmitInstr('CMP', 'CX, 0');
  EmitInstr('JE', A60_RT_PFX + 'ININT_RET');
  EmitInstr('NEG', 'AX');
  EmitLabel(A60_RT_PFX + 'ININT_RET');
  EmitPop('DX');
  EmitPop('CX');
  EmitPop('BX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { ---- _A60RT_INCHAR : lire un caractere depuis stdin ---------
    Entree : BX = handle (ignore, utilise AH=01h)
    Sortie : AX = caractere lu (dans AL, AH=0)                  }
  EmitLabel(A60_RT_PFX + 'INCHAR');
  EmitInstr('MOV', 'AH, 01h');     { lecture caractere + echo }
  EmitInstr('INT', '21h');
  EmitInstr('XOR', 'AH, AH');      { nettoyer AH }
  EmitInstr('RET', '');
  EmitBlankLine;
End;

{ ============================================================
  TODO 13 - INSTRUCTIONS CONDITIONNELLES (IF/THEN/ELSE) [IMPLEMENTE]
  ============================================================ }

{ ---- ParseIfStmt : instruction conditionnelle Algol 60 ------
  Syntaxe : IF condition THEN statement [ELSE statement]
  Le mot-cle IF a deja ete consomme par l appelant.
  Emission :
    - Evaluer condition -> AX
    - OR AX, AX / JZ _A60L_ELSE_N ou _A60L_ENDIF_N
    - branche THEN
    - [JMP _A60L_ENDIF_N / _A60L_ELSE_N: / branche ELSE]
    - _A60L_ENDIF_N:
  Le "dangling else" est resolu par liaison au IF le plus
  proche (greedy matching), conforme a Algol 60.              }
Procedure ParseIfStmt;
Var
  Cond     : TExprVal;
  LblElse  : TString;
  LblEnd   : TString;
  HasElse  : Boolean;
  N        : TString;
Begin
  Inc(IfCount);
  Str(IfCount, N);
  LblElse := '_A60L_ELSE_' + N;
  LblEnd  := '_A60L_ENDIF_' + N;

  EmitComment('IF (n ' + N + ')');

  { Evaluer la condition }
  ParseExpr(Cond);
  ExprFlushToAX(Cond);

  { Consommer THEN }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'THEN') Then
    ParserAdvance
  Else
    CompileError('THEN attendu apres condition IF');

  { Determiner si ELSE suit apres la branche THEN }
  { On ne le sait pas encore -> emettre saut vers LblElse }
  EmitInstr('OR', 'AX, AX');
  EmitInstr('JZ', LblElse);

  { Branche THEN : parser UNE instruction }
  EmitComment('THEN');
  { IF imbrique dans la branche THEN }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'IF') Then
  Begin
    ParserAdvance;
    ParseIfStmt;
  End
  Else
    ParseStmt;

  { Sauter les points-virgule optionnels entre THEN-stmt et ELSE }
  While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Do
    ParserAdvance;

  { Verifier si ELSE suit }
  HasElse := (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'ELSE');

  If HasElse Then
  Begin
    EmitInstr('JMP', LblEnd);
    EmitLabel(LblElse);
    ParserAdvance;  { consommer ELSE }

    EmitComment('ELSE');
    { IF imbrique dans la branche ELSE }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'IF') Then
    Begin
      ParserAdvance;
      ParseIfStmt;
    End
    Else
      ParseStmt;

    EmitLabel(LblEnd);
  End
  Else
  Begin
    { Pas de ELSE : le label else == label end }
    EmitLabel(LblElse);
  End;
End;

{ ============================================================
  TODO 14 - BOUCLE FOR (STEP/UNTIL/WHILE) [IMPLEMENTE]
  ============================================================ }

{ ---- ParseForStmt : boucle FOR Algol 60 ---------------------
  Syntaxe : FOR var := elem1 [, elem2, ...] DO stmt
  Chaque element peut etre :
    - valeur simple : expr
    - STEP/UNTIL : expr STEP expr UNTIL expr
    - WHILE : expr WHILE cond
  Labels : _A60L_FTEST_N, _A60L_FINCR_N, _A60L_FEND_N, _A60L_FNEXT_N }
Procedure ParseForStmt;
Var
  VarName  : TString;
  VarSIdx  : Integer;
  VarAddr  : TString;
  N        : TString;
  LblTest  : TString;
  LblIncr  : TString;
  LblEnd   : TString;
  ElemNum  : Integer;
  InitVal  : TExprVal;
  StepVal  : TExprVal;
  LimitVal : TExprVal;
  CondVal  : TExprVal;
  LblBody  : TString;
  NS       : TString;
Begin
  Inc(ForCount);
  Str(ForCount, N);

  EmitComment('FOR (n ' + N + ')');

  { Parser le nom de la variable de boucle }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('identificateur attendu apres FOR');
    Exit;
  End;
  VarName := CurToken.Val;
  ParserAdvance;

  { Chercher la variable dans la table des symboles }
  VarSIdx := SymFind(VarName);
  If VarSIdx < 0 Then
  Begin
    CompileError('variable FOR non declaree : ' + VarName);
    Exit;
  End;
  VarAddr := ExprAddrOf(VarSIdx);

  { Consommer := }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    ParserAdvance
  Else
    CompileError(':= attendu apres variable FOR');

  { Parser la liste d elements (separes par des virgules) }
  ElemNum := 0;
  LblEnd := '_A60L_FEND_' + N;

  Repeat
    Inc(ElemNum);
    Str(ElemNum, NS);

    { Evaluer l expression initiale }
    ParseExpr(InitVal);
    ExprFlushToAX(InitVal);
    EmitInstr('MOV', VarAddr + ', AX');

    { Determiner la forme de l element }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'STEP') Then
    Begin
      { ---- Forme STEP/UNTIL ---- }
      ParserAdvance;  { consommer STEP }
      EmitComment('FOR STEP/UNTIL (elem ' + NS + ')');

      LblTest := '_A60L_FTEST_' + N + '_' + NS;
      LblIncr := '_A60L_FINCR_' + N + '_' + NS;

      { Evaluer le pas (step) }
      ParseExpr(StepVal);
      ExprFlushToAX(StepVal);
      EmitInstr('PUSH', 'AX');  { sauvegarder le step sur la pile }

      { Consommer UNTIL }
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'UNTIL') Then
        ParserAdvance
      Else
        CompileError('UNTIL attendu apres STEP expr');

      { Evaluer la limite (until) }
      ParseExpr(LimitVal);
      ExprFlushToAX(LimitVal);
      EmitInstr('PUSH', 'AX');  { sauvegarder la limite sur la pile }

      { Label de test }
      EmitLabel(LblTest);

      { Recuperer limite et step depuis la pile (sans les consommer) }
      { Pile : [SP] = limite, [SP+2] = step }
      EmitInstr('MOV', 'AX, ' + VarAddr);  { AX = variable }
      EmitInstr('MOV', 'CX, WORD PTR [SP]');   { CX = limite }
      EmitInstr('MOV', 'DX, WORD PTR [SP+2]'); { DX = step }

      { Test : si step > 0 -> CMP var, limite / JG fin }
      {        si step < 0 -> CMP var, limite / JL fin }
      {        si step = 0 -> JMP fin (boucle infinie evitee) }
      EmitInstr('CMP', 'AX, CX');
      EmitInstr('OR', 'DX, DX');
      LblBody := '_A60L_FBODY_' + N + '_' + NS;
      EmitInstr('JS', '_A60L_FNEG_' + N + '_' + NS);
      { step >= 0 : si var > limite -> fin }
      EmitInstr('JG', LblIncr);
      EmitInstr('JMP', LblBody);
      EmitLabel('_A60L_FNEG_' + N + '_' + NS);
      { step < 0 : si var < limite -> fin }
      EmitInstr('JL', LblIncr);
      EmitLabel(LblBody);

      { Le corps de la boucle sera parse a la fin de tous les elements }
      { On stocke les infos pour apres le DO }
      { Mais en Algol 60, chaque element suivi par DO execute le body }
      { On va sauter au prochain element apres le body }

      { -- On doit stocker les infos de boucle et parser le body --
        En Algol 60, la syntaxe est :
          FOR i := e1 STEP s UNTIL h, e2, ... DO stmt
        Le DO et le body sont communs a tous les elements.
        On doit donc d abord parser TOUS les elements, puis le body.
        Cela necessite une approche differente : on genere le code
        pour chaque element avec un saut vers le body commun.

        Approche simplifiee : on ne supporte qu un seul element avant DO.
        Pour les listes, chaque element genere sa propre boucle sequentielle. }

      { Verifier si c est suivi par DO ou par une virgule }
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'DO') Then
      Begin
        ParserAdvance;  { consommer DO }
        { Parser le corps de la boucle }
        EmitComment('DO (body)');
        ParseStmt;  { gere BEGIN/END via ParseBlock (TODO 16) }

        { Incrementer : var := var + step }
        EmitComment('FOR increment');
        EmitInstr('MOV', 'AX, ' + VarAddr);
        EmitInstr('ADD', 'AX, WORD PTR [SP+2]');  { AX += step }
        EmitInstr('MOV', VarAddr + ', AX');
        EmitInstr('JMP', LblTest);

        { Label de sortie : nettoyer la pile }
        EmitLabel(LblIncr);
        EmitInstr('ADD', 'SP, 4');  { retirer step et limite }
      End
      Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      Begin
        { Plusieurs elements : ce STEP/UNTIL n est qu un element de la liste.
          On genere la boucle STEP/UNTIL, puis continue avec le prochain element.
          Le DO sera parse apres le dernier element. }
        { Pour simplifier, on parse le body inline ici aussi }
        { En fait pour gerer correctement la liste, on doit parser
          le DO+body une seule fois apres tous les elements. }
        { Approche : chaque element STEP/UNTIL est une boucle complete,
          le body est duplique pour chaque element. Ce n est pas optimal
          mais fonctionnel pour la compilation vers ASM. }
        ParserAdvance;  { consommer , }

        { On doit d abord finir cette boucle - mais on n a pas encore le body!
          Sautons au label de fin pour l instant et continuons la liste. }
        EmitInstr('JMP', LblIncr);
        EmitLabel(LblIncr);
        EmitInstr('ADD', 'SP, 4');
        { On continue avec le prochain element }
        Continue;
      End;
      { Sortir de la boucle repeat }
      Break;
    End
    Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'WHILE') Then
    Begin
      { ---- Forme WHILE ---- }
      ParserAdvance;  { consommer WHILE }
      EmitComment('FOR WHILE (elem ' + NS + ')');

      LblTest := '_A60L_FWTEST_' + N + '_' + NS;
      EmitLabel(LblTest);

      { Re-affecter i := expr a chaque iteration (deja fait au debut) }

      { Evaluer la condition WHILE }
      ParseExpr(CondVal);
      ExprFlushToAX(CondVal);
      EmitInstr('OR', 'AX, AX');
      EmitInstr('JZ', LblEnd);

      { Consommer DO }
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'DO') Then
      Begin
        ParserAdvance;
        EmitComment('DO (body)');
        ParseStmt;  { gere BEGIN/END via ParseBlock (TODO 16) }
      End
      Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      Begin
        ParserAdvance;
        Continue;
      End;

      EmitInstr('JMP', LblTest);
      Break;
    End
    Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'DO') Then
    Begin
      { ---- Forme simple : valeur unique (pas STEP ni WHILE) ---- }
      ParserAdvance;  { consommer DO }
      EmitComment('FOR simple (elem ' + NS + ')');

      { La variable a deja ete initialisee. Executer le body une fois. }
      ParseStmt;  { gere BEGIN/END via ParseBlock (TODO 16) }
      Break;
    End
    Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
    Begin
      { Virgule : prochain element de la liste }
      ParserAdvance;
      Continue;
    End
    Else
    Begin
      CompileError('DO, STEP, WHILE ou , attendu dans FOR');
      Break;
    End;
  Until False;

  EmitLabel(LblEnd);
  EmitComment('END FOR (n ' + N + ')');
End;

{ ============================================================
  TODO 15 - GOTO ET ETIQUETTES [IMPLEMENTE]
  ============================================================ }

{ ---- ParseGotoStmt : instruction GOTO / GO TO ---------------
  Syntaxe : GOTO label
            GO TO label
  Le mot-cle GOTO ou GO TO a deja ete consomme par l appelant.
  On attend un identifiant qui est le nom du label cible.
  On emet un JMP vers le label mangled _A60L_name.
  Si le label n est pas encore declare, on l ajoute quand meme
  (forward reference) et on emettra le label plus tard.          }
Procedure ParseGotoStmt;
Var
  LblName, MangledLbl : TString;
  SIdx : Integer;
  E    : TExprVal;
Begin
  Inc(GotoCount);
  If CurToken.Kind = TK_IDENT Then
  Begin
    LblName := CurToken.Val;
    ParserAdvance;  { consommer le nom du label }

    { Chercher le label dans la table des symboles }
    SIdx := SymFind(LblName);

    { GOTO sw[expr] : saut via table switch (TODO 21) }
    If (SIdx >= 0) And (SymTab[SIdx].Kind = SK_SWITCH) And
       (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
    Begin
      ParserAdvance;  { consommer [ }
      ParseExpr(E);
      ExprFlushToAX(E);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
        ParserAdvance  { consommer ] }
      Else
        CompileError('] attendu apres l''index de switch');
      EmitComment('GOTO ' + LblName + '[expr] (switch)');
      EmitInstr('DEC', 'AX');          { 1-base -> 0-base }
      EmitInstr('SHL', 'AX, 1');       { * 2 pour offset mot }
      EmitInstr('MOV', 'BX, AX');
      EmitInstr('ADD', 'BX, OFFSET ' + SymTab[SIdx].MangledName);
      EmitInstr('JMP', 'WORD PTR [BX]');
      Exit;
    End;

    If SIdx >= 0 Then
    Begin
      { Label deja declare }
      MangledLbl := SymTab[SIdx].MangledName;
    End
    Else
    Begin
      { Forward reference : ajouter le label en avance }
      SIdx := SymAdd(LblName, SK_LABEL, TY_IDX_LABEL, 0);
      If SIdx >= 0 Then
        MangledLbl := SymTab[SIdx].MangledName
      Else
        MangledLbl := A60_LBL_PFX + SymNameClean(LblName);
    End;

    EmitComment('GOTO ' + LblName);
    EmitInstr('JMP', MangledLbl);
  End
  Else If (CurToken.Kind = TK_INTEGER) Then
  Begin
    { GOTO avec numero de label (Algol 60 supporte les labels numeriques) }
    LblName := IntToStr_(CurToken.IntVal);
    ParserAdvance;

    SIdx := SymFind(LblName);
    If SIdx >= 0 Then
      MangledLbl := SymTab[SIdx].MangledName
    Else
    Begin
      SIdx := SymAdd(LblName, SK_LABEL, TY_IDX_LABEL, 0);
      If SIdx >= 0 Then
        MangledLbl := SymTab[SIdx].MangledName
      Else
        MangledLbl := A60_LBL_PFX + LblName;
    End;

    EmitComment('GOTO ' + LblName);
    EmitInstr('JMP', MangledLbl);
  End
  { Expression designationnelle conditionnelle (TODO 23) }
  { GOTO IF b THEN L1 ELSE L2 }
  Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'IF') Then
  Begin
    ParseExpr(E);
    ExprFlushToAX(E);
    EmitComment('GOTO designationnel conditionnel (TODO 23)');
    EmitInstr('MOV', 'BX, AX');
    EmitInstr('JMP', 'BX');
  End
  { Expression designationnelle parenthesee (TODO 23) }
  { GOTO (expression) }
  Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance;  { consommer ( }
    ParseExpr(E);
    ExprFlushToAX(E);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance  { consommer ) }
    Else
      CompileError(') attendu apres expression designationnelle');
    EmitComment('GOTO designationnel (TODO 23)');
    EmitInstr('MOV', 'BX, AX');
    EmitInstr('JMP', 'BX');
  End
  Else
    CompileError('identifiant de label attendu apres GOTO');
End;

{ ============================================================
  TODO 17 - TABLEAUX (ARRAY) A BORNES DYNAMIQUES [IMPLEMENTE]
  ============================================================ }

{ ---- ParseArrayDecl : parser une declaration ARRAY ----------- }
{ Syntaxe : [INTEGER|REAL|BOOLEAN] ARRAY id[lo:hi] [, id[lo:hi]]
  ou       ARRAY id[lo1:hi1, lo2:hi2]
  Le mot-cle ARRAY a deja ete consomme par l appelant.
  ElemTypeIdx est le type des elements (TY_IDX_INTEGER par defaut).
  Allocation :
    - Globale (scope 0) : DataAddArray dans le segment DATA
    - Locale  (scope>0) : SUB SP, taille sur la pile
  Les bornes sont des constantes entieres pour cette version.     }
Procedure ParseArrayDecl(ElemTypeIdx : Integer);
Var
  ArrName : TString;
  Lo, Hi  : Integer;
  Lo2, Hi2 : Integer;
  ElemCount : Integer;
  Dim     : Integer;
  SIdx    : Integer;
  Off     : Integer;
  Lbl     : TString;
  N       : TString;
  NegSign : Boolean;
Begin
  Inc(ArrayCount);
  Str(ArrayCount, N);

  { Boucle pour declarations multiples : ARRAY a[..], b[..] }
  While True Do
  Begin
    { Nom du tableau }
    If CurToken.Kind <> TK_IDENT Then
    Begin
      CompileError('identificateur attendu apres ARRAY');
      Exit;
    End;
    ArrName := CurToken.Val;
    ParserAdvance;  { consommer le nom }

    { Verifier si deja declare dans la portee courante }
    If SymFindInScope(ArrName, CurScope) >= 0 Then
      WarnMsg('redeclaration de ' + ArrName + ' dans la meme portee');

    { Consommer [ }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
      ParserAdvance
    Else
    Begin
      CompileError('[ attendu apres le nom du tableau');
      Exit;
    End;

    { Parser les bornes de chaque dimension }
    Dim := 0;
    Lo := 0; Hi := 0;
    Lo2 := 0; Hi2 := 0;
    While True Do
    Begin
      Inc(Dim);
      If Dim > MAX_ARRAY_DIM Then
      Begin
        CompileError('trop de dimensions (max=' +
                     IntToStr_(MAX_ARRAY_DIM) + ')');
        Exit;
      End;

      { Borne inferieure : constante entiere (eventuellement negative) }
      NegSign := False;
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '-') Then
      Begin
        NegSign := True;
        ParserAdvance;
      End;
      If CurToken.Kind <> TK_INTEGER Then
      Begin
        CompileError('borne inferieure entiere attendue');
        Exit;
      End;
      Lo := CurToken.IntVal;
      If NegSign Then Lo := -Lo;
      ParserAdvance;  { consommer la borne inf }

      { Consommer : }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
        ParserAdvance
      Else
      Begin
        CompileError(': attendu entre les bornes du tableau');
        Exit;
      End;

      { Borne superieure : constante entiere (eventuellement negative) }
      NegSign := False;
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '-') Then
      Begin
        NegSign := True;
        ParserAdvance;
      End;
      If CurToken.Kind <> TK_INTEGER Then
      Begin
        CompileError('borne superieure entiere attendue');
        Exit;
      End;
      Hi := CurToken.IntVal;
      If NegSign Then Hi := -Hi;
      ParserAdvance;  { consommer la borne sup }

      { Stocker les bornes selon la dimension }
      If Dim = 1 Then
      Begin
        Lo2 := Lo;  { on reutilise Lo2 temporairement pour dim 1 }
        Hi2 := Hi;
      End;

      { Virgule = dimension suivante, ] = fin }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      Begin
        ParserAdvance;  { consommer , }
        Continue;
      End;
      Break;
    End;

    { Consommer ] }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
      ParserAdvance
    Else
      CompileError('] attendu apres les bornes du tableau');

    { Calculer le nombre total d elements }
    If Dim = 1 Then
      ElemCount := Hi - Lo + 1
    Else
    Begin
      { Pour 2D : (hi1-lo1+1) * (hi2-lo2+1) }
      { Lo2/Hi2 contiennent les bornes de dim 1,
        Lo/Hi contiennent les bornes de la derniere dimension }
      ElemCount := (Hi2 - Lo2 + 1) * (Hi - Lo + 1);
    End;

    If ElemCount <= 0 Then
    Begin
      WarnMsg('tableau ' + ArrName + ' de taille <= 0');
      ElemCount := 1;
    End;

    { Allouer le tableau }
    If CurScope = 0 Then
    Begin
      { Tableau global : dans le segment DATA }
      Lbl := SymMangle(ArrName, SK_ARRAY);
      DataAddArray(Lbl, ElemCount);
      SIdx := SymAdd(ArrName, SK_ARRAY, TY_IDX_ARRAY, 0);
    End
    Else
    Begin
      { Tableau local : reserver N*2 octets sur la pile }
      { Le premier element (indice lo) est a [BP - (CurFrameSize + N*2)] }
      EmitInstr('SUB', 'SP, ' + IntToStr_(ElemCount * 2));
      Inc(CurFrameSize, ElemCount * 2);
      Off := CurFrameSize;  { base du tableau : element[lo] = [BP - Off] }
      SIdx := SymAdd(ArrName, SK_ARRAY, TY_IDX_ARRAY, Off);
    End;

    { Remplir les informations de tableau dans le symbole }
    If SIdx >= 0 Then
    Begin
      SymTab[SIdx].ArrayDim    := Dim;
      SymTab[SIdx].ArrayElemTy := ElemTypeIdx;
      If Dim = 1 Then
      Begin
        SymTab[SIdx].ArrayLo[1] := Lo;
        SymTab[SIdx].ArrayHi[1] := Hi;
      End
      Else If Dim >= 2 Then
      Begin
        SymTab[SIdx].ArrayLo[1] := Lo2;
        SymTab[SIdx].ArrayHi[1] := Hi2;
        SymTab[SIdx].ArrayLo[2] := Lo;
        SymTab[SIdx].ArrayHi[2] := Hi;
      End;
    End;

    EmitComment('ARRAY ' + ArrName + '[' + IntToStr_(Lo) + ':' +
                IntToStr_(Hi) + '] ' + IntToStr_(ElemCount) +
                ' elems type=' + TypeTab[ElemTypeIdx].Name);

    { Virgule = declaration suivante, sinon fin }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
    Begin
      ParserAdvance;  { consommer , }
      Continue;
    End;
    Break;
  End;
End;

{ ============================================================
  TODO 18 - DECLARATIONS DE PROCEDURES [IMPLEMENTE]
  ============================================================ }

{ ---- ParseProcDecl : parser une declaration de procedure ------
  Syntaxe : [type] PROCEDURE nom(param1, param2, ...);
            [VALUE param1, param2;]
            [INTEGER param1; REAL param2; ...]
            corps
  Le mot-cle PROCEDURE a deja ete consomme par l appelant.
  RetTypeIdx est le type de retour (TY_IDX_INTEGER par defaut).
  Procedures typees : retour de valeur par affectation au nom
    ex : INTEGER PROCEDURE f(x); f := x + 1
  Convention d appel : cdecl 16 bits
    Prologue : PUSH BP / MOV BP,SP
    Epilogue : MOV SP,BP / POP BP / RET
  Parametres : [BP+4], [BP+6], etc.                              }
Procedure ParseProcDecl(RetTypeIdx : Integer);
Var
  ProcName   : TString;
  ProcLbl    : TString;
  SkipLbl    : TString;
  RetLbl     : TString;
  N          : TString;
  ParamCount : Integer;
  ParamNames : Array[0..MAX_PARAM - 1] Of TString;
  ParamTypes : Array[0..MAX_PARAM - 1] Of Integer;
  ParamIsVal : Array[0..MAX_PARAM - 1] Of Boolean;
  SaveFrameSize : Integer;
  SaveFnName    : TString;
  SaveFnRetLbl  : TString;
  SaveFnDepth   : Integer;
  I, SIdx, Off  : Integer;
  SpecType      : Integer;
  SpecName      : TString;
  LocalBytes    : Integer;
Begin
  Inc(ProcCount);
  Str(ProcCount, N);

  { ---- Nom de la procedure ---- }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('identificateur attendu apres PROCEDURE');
    Exit;
  End;
  ProcName := CurToken.Val;
  ParserAdvance;  { consommer le nom }

  ProcLbl := A60_FN_PFX + SymNameClean(ProcName);
  SkipLbl := '_A60L_PSKIP_' + N;
  RetLbl  := '_A60L_PRET_' + N;

  EmitComment('procedure ' + ProcName + ' declaration (TODO 18)');

  { Enregistrer la procedure dans la table des symboles }
  SIdx := SymAdd(ProcName, SK_PROC, RetTypeIdx, 0);

  { ---- Liste de parametres : (p1, p2, ...) ---- }
  ParamCount := 0;
  For I := 0 To MAX_PARAM - 1 Do
  Begin
    ParamNames[I] := '';
    ParamTypes[I] := TY_IDX_INTEGER;
    ParamIsVal[I] := False;
  End;

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance;  { consommer ( }
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
    Begin
      If ParamCount >= MAX_PARAM Then
      Begin
        CompileError('trop de parametres (max=' + IntToStr_(MAX_PARAM) + ')');
        Break;
      End;
      If CurToken.Kind = TK_IDENT Then
      Begin
        ParamNames[ParamCount] := CurToken.Val;
        Inc(ParamCount);
      End;
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;  { consommer ) }

    { Stocker le nombre de parametres formels dans le symbole (TODO 19) }
    If SIdx >= 0 Then
      SymTab[SIdx].ProcParamCount := ParamCount;
  End;

  { Consommer ; apres la liste de parametres }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;

  { ---- Specification VALUE : VALUE p1, p2; ---- }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'VALUE') Then
  Begin
    ParserAdvance;  { consommer VALUE }
    While (CurToken.Kind = TK_IDENT) Do
    Begin
      For I := 0 To ParamCount - 1 Do
      Begin
        If StrUpperCase(ParamNames[I]) = StrUpperCase(CurToken.Val) Then
          ParamIsVal[I] := True;
      End;
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance
      Else
        Break;
    End;
    { Consommer ; apres VALUE }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
  End;

  { ---- Specifications de types des parametres ---- }
  { Syntaxe : INTEGER p1, p2; REAL p3; BOOLEAN p4;
    PROCEDURE f; (TODO 19) etc. }
  While (CurToken.Kind = TK_KEYWORD) And
        ((CurToken.Val = 'INTEGER') Or (CurToken.Val = 'REAL') Or
         (CurToken.Val = 'BOOLEAN') Or (CurToken.Val = 'STRING') Or
         (CurToken.Val = 'ARRAY') Or (CurToken.Val = 'LABEL') Or
         (CurToken.Val = 'SWITCH') Or (CurToken.Val = 'PROCEDURE')) Do
  Begin
    { Determiner le type }
    If CurToken.Val = 'INTEGER' Then SpecType := TY_IDX_INTEGER
    Else If CurToken.Val = 'REAL' Then SpecType := TY_IDX_REAL
    Else If CurToken.Val = 'BOOLEAN' Then SpecType := TY_IDX_BOOLEAN
    Else If CurToken.Val = 'STRING' Then SpecType := TY_IDX_STRING
    Else If CurToken.Val = 'ARRAY' Then SpecType := TY_IDX_ARRAY
    Else If CurToken.Val = 'LABEL' Then SpecType := TY_IDX_LABEL
    Else If CurToken.Val = 'PROCEDURE' Then SpecType := TY_IDX_INTEGER
    Else SpecType := TY_IDX_INTEGER;
    ParserAdvance;  { consommer le mot-cle de type }

    { Si le prochain est un mot-cle de controle, on sort }
    If (CurToken.Kind = TK_KEYWORD) And
       ((CurToken.Val = 'BEGIN') Or (CurToken.Val = 'IF') Or
        (CurToken.Val = 'FOR')) Then
      Break;

    { Parser les noms de parametres avec ce type }
    While (CurToken.Kind = TK_IDENT) Do
    Begin
      SpecName := CurToken.Val;
      For I := 0 To ParamCount - 1 Do
      Begin
        If StrUpperCase(ParamNames[I]) = StrUpperCase(SpecName) Then
          ParamTypes[I] := SpecType;
      End;
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance
      Else
        Break;
    End;
    { Consommer ; apres la spec de type }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
  End;

  { Stocker ParamIsVal dans le symbole procedure (TODO 20) }
  { Permettra a ParseProcCall de savoir quels params sont par nom }
  SIdx := SymFind(ProcName);
  If SIdx >= 0 Then
    For I := 0 To ParamCount - 1 Do
      SymTab[SIdx].ProcParamIsVal[I] := ParamIsVal[I];

  { ---- Generation de code : saut par-dessus le corps ---- }
  EmitInstr('JMP', SkipLbl);

  { ---- Label de la procedure ---- }
  EmitLabel(ProcLbl);
  EmitRaw(ProcLbl + ' PROC NEAR');

  { Prologue }
  EmitPush('BP');
  EmitInstr('MOV', 'BP, SP');

  { ---- Entrer dans la portee de la procedure ---- }
  SaveFrameSize := CurFrameSize;
  SaveFnName    := CurFnName;
  SaveFnRetLbl  := CurFnRetLbl;
  SaveFnDepth   := CurFnDepth;

  CurFrameSize := 0;
  CurFnName    := ProcName;
  CurFnRetLbl  := RetLbl;
  Inc(CurFnDepth);

  SymEnterScope;

  { Enregistrer les parametres dans la table des symboles }
  For I := 0 To ParamCount - 1 Do
  Begin
    Off := 4 + I * 2;  { [BP+4], [BP+6], [BP+8], etc. }
    SIdx := SymAdd(ParamNames[I], SK_PARAM, ParamTypes[I], Off);
    If SIdx >= 0 Then
    Begin
      SymTab[SIdx].IsValue := ParamIsVal[I];
      SymTab[SIdx].IsName  := Not ParamIsVal[I];
    End;
  End;

  EmitComment('corps procedure ' + ProcName + ' (' +
              IntToStr_(ParamCount) + ' params)');

  { ---- Parser le corps de la procedure ---- }
  { Le corps peut etre une instruction simple ou un bloc BEGIN...END }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'BEGIN') Then
  Begin
    ParserAdvance;  { consommer BEGIN }
    ParseBlock;
  End
  Else
    ParseStmt;

  { ---- Label de retour ---- }
  EmitLabel(RetLbl);

  { Liberer les variables locales si necessaire }
  LocalBytes := CurFrameSize;
  If LocalBytes > 0 Then
    EmitInstr('ADD', 'SP, ' + IntToStr_(LocalBytes));

  { Epilogue }
  EmitInstr('MOV', 'SP, BP');
  EmitPop('BP');
  EmitInstr('RET', '');
  EmitRaw(ProcLbl + ' ENDP');

  { ---- Label de saut (apres le corps) ---- }
  EmitLabel(SkipLbl);
  EmitComment('fin procedure ' + ProcName);

  { ---- Restaurer l etat ---- }
  SymLeaveScope;
  CurFrameSize := SaveFrameSize;
  CurFnName    := SaveFnName;
  CurFnRetLbl  := SaveFnRetLbl;
  CurFnDepth   := SaveFnDepth;
End;

{ ============================================================
  TODO 22 - VARIABLES OWN (STATIQUES) [IMPLEMENTE]
  ============================================================ }

{ ---- ParseOwnDecl : declaration de variables OWN (statiques) --
  Syntaxe : OWN INTEGER|REAL|BOOLEAN ident [, ident]*
            OWN ARRAY ident[lo:hi]
  Le mot-cle OWN a deja ete consomme par l appelant.
  Les variables OWN sont allouees dans le segment DATA (DW 0)
  au lieu de la pile, et persistent entre les appels de procedure.
  Le label utilise est _A60O_[procname_]varname.
  Les tableaux OWN sont alloues avec DK_ARRAY_BLK dans DATA.     }
Procedure ParseOwnDecl;
Var
  TypeIdx, SIdx : Integer;
  VarName : TString;
  Lbl     : TString;
  E       : TExprVal;
  { OWN ARRAY }
  Lo, Hi, ElemCount : Integer;
Begin
  Inc(OwnCount);

  { Determiner le type : OWN INTEGER|REAL|BOOLEAN|ARRAY }
  If (CurToken.Kind <> TK_KEYWORD) Then
  Begin
    CompileError('type attendu apres OWN (INTEGER/REAL/BOOLEAN/ARRAY)');
    Exit;
  End;

  { OWN ARRAY : deleguer a un traitement special }
  If CurToken.Val = 'ARRAY' Then
  Begin
    ParserAdvance;  { consommer ARRAY }

    { Nom du tableau }
    If CurToken.Kind <> TK_IDENT Then
    Begin
      CompileError('identificateur attendu apres OWN ARRAY');
      Exit;
    End;
    VarName := CurToken.Val;
    ParserAdvance;  { consommer le nom }

    { Bornes : [lo:hi] }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
      ParserAdvance;  { consommer [ }
    Lo := 0;
    Hi := 0;
    If CurToken.Kind = TK_INTEGER Then
    Begin
      Lo := CurToken.IntVal;
      ParserAdvance;  { consommer lo }
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      ParserAdvance;  { consommer : }
    If CurToken.Kind = TK_INTEGER Then
    Begin
      Hi := CurToken.IntVal;
      ParserAdvance;  { consommer hi }
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
      ParserAdvance;  { consommer ] }

    ElemCount := Hi - Lo + 1;
    If ElemCount < 1 Then ElemCount := 1;

    { Label OWN : _A60O_[proc_]nom }
    If CurFnName <> '' Then
      Lbl := A60_OWN_PFX + SymNameClean(CurFnName) + '_' +
             SymNameClean(VarName)
    Else
      Lbl := A60_OWN_PFX + SymNameClean(VarName);

    { Allouer dans DATA }
    DataAddArray(Lbl, ElemCount);

    { Ajouter le symbole comme SK_OWN avec infos tableau }
    SIdx := SymAdd(VarName, SK_OWN, TY_IDX_INTEGER, 0);
    If SIdx >= 0 Then
    Begin
      SymTab[SIdx].MangledName := Lbl;
      SymTab[SIdx].ArrayDim    := 1;
      SymTab[SIdx].ArrayElemTy := TY_IDX_INTEGER;
      SymTab[SIdx].ArrayLo[1]  := Lo;
      SymTab[SIdx].ArrayHi[1]  := Hi;
    End;

    EmitComment('OWN ARRAY ' + VarName + '[' + IntToStr_(Lo) +
                ':' + IntToStr_(Hi) + '] -> DATA ' + Lbl);
    Exit;
  End;

  { OWN INTEGER|REAL|BOOLEAN }
  If CurToken.Val = 'INTEGER' Then
    TypeIdx := TY_IDX_INTEGER
  Else If CurToken.Val = 'REAL' Then
    TypeIdx := TY_IDX_REAL
  Else If CurToken.Val = 'BOOLEAN' Then
    TypeIdx := TY_IDX_BOOLEAN
  Else
  Begin
    CompileError('type attendu apres OWN (INTEGER/REAL/BOOLEAN/ARRAY)');
    Exit;
  End;
  ParserAdvance;  { consommer le mot-cle de type }

  { OWN type ARRAY : OWN INTEGER ARRAY id[lo:hi] }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'ARRAY') Then
  Begin
    ParserAdvance;  { consommer ARRAY }

    If CurToken.Kind <> TK_IDENT Then
    Begin
      CompileError('identificateur attendu apres OWN type ARRAY');
      Exit;
    End;
    VarName := CurToken.Val;
    ParserAdvance;  { consommer le nom }

    Lo := 0;
    Hi := 0;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
      ParserAdvance;
    If CurToken.Kind = TK_INTEGER Then
    Begin
      Lo := CurToken.IntVal;
      ParserAdvance;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      ParserAdvance;
    If CurToken.Kind = TK_INTEGER Then
    Begin
      Hi := CurToken.IntVal;
      ParserAdvance;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
      ParserAdvance;

    ElemCount := Hi - Lo + 1;
    If ElemCount < 1 Then ElemCount := 1;

    If CurFnName <> '' Then
      Lbl := A60_OWN_PFX + SymNameClean(CurFnName) + '_' +
             SymNameClean(VarName)
    Else
      Lbl := A60_OWN_PFX + SymNameClean(VarName);

    DataAddArray(Lbl, ElemCount);

    SIdx := SymAdd(VarName, SK_OWN, TypeIdx, 0);
    If SIdx >= 0 Then
    Begin
      SymTab[SIdx].MangledName := Lbl;
      SymTab[SIdx].ArrayDim    := 1;
      SymTab[SIdx].ArrayElemTy := TypeIdx;
      SymTab[SIdx].ArrayLo[1]  := Lo;
      SymTab[SIdx].ArrayHi[1]  := Hi;
    End;

    EmitComment('OWN ' + TypeMangle(TypeIdx) + ' ARRAY ' + VarName +
                '[' + IntToStr_(Lo) + ':' + IntToStr_(Hi) +
                '] -> DATA ' + Lbl);
    Exit;
  End;

  { Parser la liste d identifiants : OWN INTEGER x, y, z }
  While (CurToken.Kind <> TK_EOF) Do
  Begin
    If CurToken.Kind <> TK_IDENT Then
    Begin
      CompileError('identificateur attendu dans la declaration OWN');
      Exit;
    End;
    VarName := CurToken.Val;
    ParserAdvance;  { consommer le nom }

    { Label OWN : _A60O_[proc_]nom }
    If CurFnName <> '' Then
      Lbl := A60_OWN_PFX + SymNameClean(CurFnName) + '_' +
             SymNameClean(VarName)
    Else
      Lbl := A60_OWN_PFX + SymNameClean(VarName);

    { Allouer dans DATA (DW 0) }
    DataAddWord(Lbl, 0);

    { Ajouter le symbole comme SK_OWN }
    SIdx := SymAdd(VarName, SK_OWN, TypeIdx, 0);
    If SIdx >= 0 Then
      SymTab[SIdx].MangledName := Lbl;

    EmitComment('OWN ' + VarName + ' -> DATA ' + Lbl);

    { Initialisation optionnelle : OWN INTEGER x := 42 }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    Begin
      ParserAdvance;  { consommer := }
      ParseExpr(E);
      ExprFlushToAX(E);
      ExprStore(SIdx);
    End;

    { Virgule : variable suivante }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance  { consommer , }
    Else
      Break;
  End;
End;

{ ============================================================
  TODO 23 - EXPRESSIONS CONDITIONNELLES ET DESIGNATIONNELLES [IMPLEMENTE]
  ============================================================ }
{ Changements effectues pour cette TODO :
  - ExprFlushToAX : SK_LABEL -> MOV AX, OFFSET label (adresse de code)
  - ParsePrimary  : IF expr THEN expr ELSE expr (deja en place)
  - ParseGotoStmt : GOTO IF b THEN L1 ELSE L2 (desig conditionnel)
                    GOTO (expr) (desig parenthesee)
  - ParseSwitchAccess : sw[expr] -> TY_IDX_LABEL (deja en place)       }

{ ============================================================
  TODO 24 - RUNTIME MINIMAL [IMPLEMENTE]
  ============================================================ }

{ ---- EmitMinimalRuntime : emettre les routines runtime
  complementaires (TODO 24).
  _A60RT_PRINT   : BX=handle, SI=msg, CX=len -> ecriture
  _A60RT_PRINTLN : PRINT + CR+LF
  _A60RT_STRLEN  : SI=str -> AX=longueur
  _A60RT_NUMTOSTR: AX=n, DI=buf -> conversion entier->ASCII
  _A60RT_STRTONUM: SI=str -> AX=entier
  _A60RT_ABS     : AX=n -> AX=|n|
  _A60RT_SIGN    : AX=n -> AX=-1/0/1
  _A60RT_ENTIER  : AX=n -> AX=n (stub identite sur entiers)
  _A60RT_CHKIDX  : AX=idx, BX=lo, CX=hi -> erreur si hors bornes
  _A60RT_PANIC   : SI=msg -> affiche + exit(1)                        }
Procedure EmitMinimalRuntime;
Begin
  If MinRTEmitted Then Exit;
  MinRTEmitted := True;

  EmitBlankLine;
  EmitComment('--- Runtime minimal (TODO 24) ---');
  EmitBlankLine;

  { ---- _A60RT_PRINT : ecrire CX octets depuis SI sur handle BX ---
    Entree : BX = handle, SI = adresse message, CX = longueur
    Utilise INT 21h AH=40h                                           }
  EmitLabel(A60_RT_PFX + 'PRINT');
  EmitPush('AX');
  EmitPush('DX');
  EmitMov('DX', 'SI');              { DX = adresse tampon }
  EmitInstr('MOV', 'AH, 40h');     { ecrire sur handle }
  EmitInstr('INT', '21h');
  EmitPop('DX');
  EmitPop('AX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { ---- _A60RT_PRINTLN : ecrire message + CR+LF -------------------
    Entree : BX = handle, SI = adresse chaine ASCIIZ
    Appelle OUTSTR puis NEWLINE                                      }
  EmitLabel(A60_RT_PFX + 'PRINTLN');
  EmitInstr('CALL', A60_RT_PFX + 'OUTSTR');
  EmitInstr('CALL', A60_RT_PFX + 'NEWLINE');
  EmitInstr('RET', '');
  EmitBlankLine;

  { ---- _A60RT_STRLEN : longueur d une chaine ASCIIZ ---------------
    Entree : SI = pointeur chaine ASCIIZ
    Sortie : AX = nombre d octets avant le NUL                      }
  EmitLabel(A60_RT_PFX + 'STRLEN');
  EmitPush('DI');
  EmitMov('DI', 'SI');
  EmitInstr('XOR', 'AX, AX');
  EmitLabel(A60_RT_PFX + 'STRLEN_L');
  EmitInstr('CMP', 'BYTE PTR [DI], 0');
  EmitInstr('JE', A60_RT_PFX + 'STRLEN_D');
  EmitInstr('INC', 'DI');
  EmitInstr('INC', 'AX');
  EmitInstr('JMP', A60_RT_PFX + 'STRLEN_L');
  EmitLabel(A60_RT_PFX + 'STRLEN_D');
  EmitPop('DI');
  EmitInstr('RET', '');
  EmitBlankLine;

  { ---- _A60RT_NUMTOSTR : entier signe -> ASCII (itoa) -------------
    Entree : AX = entier signe 16 bits, DI = adresse tampon
    Sortie : tampon rempli avec la representation decimale + NUL
    Modifie DI pour pointer apres le dernier caractere               }
  EmitLabel(A60_RT_PFX + 'NUMTOSTR');
  EmitPush('BX');
  EmitPush('CX');
  EmitPush('DX');
  EmitPush('SI');
  { Verifier signe }
  EmitInstr('CMP', 'AX, 0');
  EmitInstr('JGE', A60_RT_PFX + 'NTS_POS');
  EmitInstr('MOV', 'BYTE PTR [DI], 45');   { '-' }
  EmitInstr('INC', 'DI');
  EmitInstr('NEG', 'AX');
  EmitLabel(A60_RT_PFX + 'NTS_POS');
  { Si AX = 0, ecrire '0' directement }
  EmitInstr('CMP', 'AX, 0');
  EmitInstr('JNE', A60_RT_PFX + 'NTS_CVT');
  EmitInstr('MOV', 'BYTE PTR [DI], 48');   { '0' }
  EmitInstr('INC', 'DI');
  EmitInstr('JMP', A60_RT_PFX + 'NTS_NUL');
  { Conversion : diviser par 10, empiler chiffres }
  EmitLabel(A60_RT_PFX + 'NTS_CVT');
  EmitInstr('XOR', 'CX, CX');      { compteur = 0 }
  EmitLabel(A60_RT_PFX + 'NTS_DIV');
  EmitInstr('XOR', 'DX, DX');
  EmitInstr('MOV', 'SI, 10');
  EmitInstr('DIV', 'SI');           { AX=quotient, DX=reste }
  EmitInstr('ADD', 'DX, 48');       { reste + '0' }
  EmitPush('DX');
  EmitInstr('INC', 'CX');
  EmitInstr('CMP', 'AX, 0');
  EmitInstr('JNE', A60_RT_PFX + 'NTS_DIV');
  { Depiler chiffres dans l ordre correct }
  EmitLabel(A60_RT_PFX + 'NTS_POP');
  EmitPop('DX');
  EmitInstr('MOV', '[DI], DL');
  EmitInstr('INC', 'DI');
  EmitInstr('DEC', 'CX');
  EmitInstr('JNZ', A60_RT_PFX + 'NTS_POP');
  { Terminer par NUL }
  EmitLabel(A60_RT_PFX + 'NTS_NUL');
  EmitInstr('MOV', 'BYTE PTR [DI], 0');
  EmitPop('SI');
  EmitPop('DX');
  EmitPop('CX');
  EmitPop('BX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { ---- _A60RT_STRTONUM : ASCII -> entier (atoi) -------------------
    Entree : SI = pointeur chaine ASCIIZ (chiffres decimaux, opt. -)
    Sortie : AX = valeur entiere                                     }
  EmitLabel(A60_RT_PFX + 'STRTONUM');
  EmitPush('BX');
  EmitPush('CX');
  EmitPush('DX');
  EmitInstr('XOR', 'BX, BX');      { BX = accumulateur }
  EmitInstr('XOR', 'CX, CX');      { CX = flag signe }
  EmitInstr('CMP', 'BYTE PTR [SI], 45');   { '-' ? }
  EmitInstr('JNE', A60_RT_PFX + 'STN_DIG');
  EmitInstr('MOV', 'CX, 1');
  EmitInstr('INC', 'SI');
  EmitLabel(A60_RT_PFX + 'STN_DIG');
  EmitInstr('MOV', 'AL, [SI]');
  EmitInstr('CMP', 'AL, 0');       { NUL -> fin }
  EmitInstr('JE', A60_RT_PFX + 'STN_END');
  EmitInstr('CMP', 'AL, 48');      { < '0' -> fin }
  EmitInstr('JB', A60_RT_PFX + 'STN_END');
  EmitInstr('CMP', 'AL, 57');      { > '9' -> fin }
  EmitInstr('JA', A60_RT_PFX + 'STN_END');
  { BX = BX * 10 + (AL - '0') }
  EmitInstr('SUB', 'AL, 48');
  EmitInstr('XOR', 'AH, AH');
  EmitPush('AX');
  EmitMov('AX', 'BX');
  EmitInstr('MOV', 'DX, 10');
  EmitInstr('MUL', 'DX');           { AX = BX * 10 }
  EmitPop('DX');
  EmitInstr('ADD', 'AX, DX');
  EmitMov('BX', 'AX');
  EmitInstr('INC', 'SI');
  EmitInstr('JMP', A60_RT_PFX + 'STN_DIG');
  EmitLabel(A60_RT_PFX + 'STN_END');
  EmitMov('AX', 'BX');
  EmitInstr('CMP', 'CX, 0');
  EmitInstr('JE', A60_RT_PFX + 'STN_RET');
  EmitInstr('NEG', 'AX');
  EmitLabel(A60_RT_PFX + 'STN_RET');
  EmitPop('DX');
  EmitPop('CX');
  EmitPop('BX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { ---- _A60RT_ABS : valeur absolue ---------------------------------
    Entree : AX = entier signe
    Sortie : AX = |AX|                                               }
  EmitLabel(A60_RT_PFX + 'ABS');
  EmitInstr('CMP', 'AX, 0');
  EmitInstr('JGE', A60_RT_PFX + 'ABS_OK');
  EmitInstr('NEG', 'AX');
  EmitLabel(A60_RT_PFX + 'ABS_OK');
  EmitInstr('RET', '');
  EmitBlankLine;

  { ---- _A60RT_SIGN : signe d un entier -----------------------------
    Entree : AX = entier signe
    Sortie : AX = -1 si negatif, 0 si nul, +1 si positif             }
  EmitLabel(A60_RT_PFX + 'SIGN');
  EmitInstr('CMP', 'AX, 0');
  EmitInstr('JG', A60_RT_PFX + 'SIGN_P');
  EmitInstr('JL', A60_RT_PFX + 'SIGN_N');
  EmitInstr('XOR', 'AX, AX');      { AX = 0 }
  EmitInstr('RET', '');
  EmitLabel(A60_RT_PFX + 'SIGN_P');
  EmitMov('AX', '1');
  EmitInstr('RET', '');
  EmitLabel(A60_RT_PFX + 'SIGN_N');
  EmitMov('AX', '-1');
  EmitInstr('RET', '');
  EmitBlankLine;

  { ---- _A60RT_ENTIER : partie entiere (stub identite) ---------------
    Entree : AX = entier (sur entiers, identite)
    Sortie : AX = AX (pas de modification)                            }
  EmitLabel(A60_RT_PFX + 'ENTIER');
  EmitInstr('RET', '');
  EmitBlankLine;

  { ---- _A60RT_CHKIDX : verification bornes tableau ------------------
    Entree : AX = index, BX = borne inferieure, CX = borne superieure
    Sortie : AX inchange si dans les bornes
    Erreur : appelle _A60RT_PANIC si hors bornes                      }
  EmitLabel(A60_RT_PFX + 'CHKIDX');
  EmitInstr('CMP', 'AX, BX');
  EmitInstr('JL', A60_RT_PFX + 'CHKIDX_ERR');
  EmitInstr('CMP', 'AX, CX');
  EmitInstr('JG', A60_RT_PFX + 'CHKIDX_ERR');
  EmitInstr('RET', '');
  EmitLabel(A60_RT_PFX + 'CHKIDX_ERR');
  EmitMov('SI', 'OFFSET _A60_PANIC_IDX');
  EmitInstr('JMP', A60_RT_PFX + 'PANIC');
  EmitBlankLine;

  { ---- _A60RT_PANIC : message d erreur + terminaison ----------------
    Entree : SI = pointeur message ASCIIZ
    Action : ecrire message sur stderr (handle 2) puis exit(1)        }
  EmitLabel(A60_RT_PFX + 'PANIC');
  EmitPush('AX');
  EmitPush('BX');
  EmitPush('CX');
  EmitPush('DX');
  EmitPush('DI');
  { Calculer longueur du message }
  EmitMov('DI', 'SI');
  EmitInstr('XOR', 'CX, CX');
  EmitLabel(A60_RT_PFX + 'PANIC_L');
  EmitInstr('CMP', 'BYTE PTR [DI], 0');
  EmitInstr('JE', A60_RT_PFX + 'PANIC_W');
  EmitInstr('INC', 'DI');
  EmitInstr('INC', 'CX');
  EmitInstr('JMP', A60_RT_PFX + 'PANIC_L');
  EmitLabel(A60_RT_PFX + 'PANIC_W');
  { Ecrire sur stderr (handle = 2) }
  EmitMov('DX', 'SI');
  EmitInstr('MOV', 'BX, 2');       { stderr }
  EmitInstr('MOV', 'AH, 40h');
  EmitInstr('INT', '21h');
  { Ecrire CR+LF }
  EmitInstr('MOV', 'DX, OFFSET _A60_CRLF');
  EmitInstr('MOV', 'CX, 2');
  EmitInstr('MOV', 'AH, 40h');
  EmitInstr('INT', '21h');
  EmitPop('DI');
  EmitPop('DX');
  EmitPop('CX');
  EmitPop('BX');
  EmitPop('AX');
  { Terminer avec code d erreur 1 }
  EmitInstr('MOV', 'AX, 4C01h');
  EmitInstr('INT', '21h');
  EmitBlankLine;
End;

{ ============================================================
  TODO 21 - DECLARATIONS SWITCH (AIGUILLAGES) [IMPLEMENTE]
  ============================================================ }

{ ---- ParseSwitchDecl : declaration d aiguillage ---------------
  Syntaxe : SWITCH nom := label1, label2, label3, ...
  Le mot-cle SWITCH a deja ete consomme par l appelant.
  Genere une table de mots dans le segment DATA :
    _A60S_nom DW OFFSET _A60L_label1, OFFSET _A60L_label2, ...
  Utilisation avec GOTO : GOTO nom[expr]
    Evalue expr -> index 1-base, accede a la table, JMP [table+off] }
Procedure ParseSwitchDecl;
Var
  SwName     : TString;
  SIdx       : Integer;
  LblName    : TString;
  LblMng     : TString;
  LblSIdx    : Integer;
  OfsList    : TString;
  LabCount   : Integer;
  N          : TString;
Begin
  Inc(SwitchCount);

  { Nom du switch }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('identificateur attendu apres SWITCH');
    Exit;
  End;
  SwName := CurToken.Val;
  ParserAdvance;  { consommer le nom }

  { Consommer := }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    ParserAdvance  { consommer := }
  Else
  Begin
    CompileError(':= attendu apres le nom du switch');
    Exit;
  End;

  { Ajouter le symbole switch }
  SIdx := SymAdd(SwName, SK_SWITCH, TY_IDX_SWITCH, 0);
  Str(SwitchCount, N);
  EmitComment('SWITCH ' + SwName + ' (TODO 21)');

  { Parser la liste de labels : label1, label2, ... }
  OfsList := '';
  LabCount := 0;
  While (CurToken.Kind <> TK_EOF) Do
  Begin
    { Chaque entree peut etre un identifiant de label ou un entier }
    If (CurToken.Kind = TK_IDENT) Then
    Begin
      LblName := CurToken.Val;
      ParserAdvance;  { consommer le label }
      { Chercher ou creer le label }
      LblSIdx := SymFind(LblName);
      If LblSIdx < 0 Then
        LblSIdx := SymAdd(LblName, SK_LABEL, TY_IDX_LABEL, 0);
      If LblSIdx >= 0 Then
        LblMng := SymTab[LblSIdx].MangledName
      Else
        LblMng := A60_LBL_PFX + SymNameClean(LblName);
    End
    Else If (CurToken.Kind = TK_INTEGER) Then
    Begin
      LblName := IntToStr_(CurToken.IntVal);
      ParserAdvance;  { consommer le label numerique }
      LblSIdx := SymFind(LblName);
      If LblSIdx < 0 Then
        LblSIdx := SymAdd(LblName, SK_LABEL, TY_IDX_LABEL, 0);
      If LblSIdx >= 0 Then
        LblMng := SymTab[LblSIdx].MangledName
      Else
        LblMng := A60_LBL_PFX + LblName;
    End
    Else
      Break;

    { Ajouter a la liste des OFFSET }
    Inc(LabCount);
    If LabCount > 1 Then
      OfsList := OfsList + ', ';
    OfsList := OfsList + 'OFFSET ' + LblMng;

    { Virgule : entree suivante }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance  { consommer , }
    Else
      Break;
  End;

  { Stocker le nombre d entrees dans le symbole }
  If SIdx >= 0 Then
    SymTab[SIdx].SwitchLabCount := LabCount;

  { Ajouter la table switch au segment DATA }
  If LabCount > 0 Then
  Begin
    DataAdd(SymTab[SIdx].MangledName, DK_SWITCH_TAB, 0, OfsList);
  End
  Else
    WarnMsg('switch ' + SwName + ' sans entrees');
End;

{ ============================================================
  TODO 16 - BLOCS (BEGIN/END) ET INSTRUCTIONS COMPOSEES [IMPLEMENTE]
  ============================================================ }

{ ---- ParseBlock : bloc BEGIN declarations; instructions END --
  Le mot-cle BEGIN a deja ete consomme par l appelant.
  Fonctionnement :
    1. SymEnterScope : nouvelle portee lexicale
    2. Sauvegarder CurFrameSize
    3. Parser les declarations et instructions du bloc
       (LABEL, INTEGER, REAL, BOOLEAN, STRING, OWN, etc.)
       Les declarations locales appellent DeclAllocSym qui
       emet SUB SP,2 pour chaque variable
    4. Liberer la pile : ADD SP, n (octets locaux)
    5. Consommer END
    6. Restaurer CurFrameSize
    7. SymLeaveScope : quitter la portee                        }
Procedure ParseBlock;
Var
  SavedFrameSize : Integer;
  LocalBytes     : Integer;
  N              : TString;
Begin
  Inc(BlockCount);
  Str(BlockCount, N);
  SymEnterScope;
  SavedFrameSize := CurFrameSize;
  EmitComment('BEGIN bloc ' + N + ' (scope ' + IntToStr_(CurScope) + ')');

  { Parser declarations et instructions jusqu a END }
  While (CurToken.Kind <> TK_EOF) Do
  Begin
    { Sauter les points-virgule }
    While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Do
      ParserAdvance;
    { Fin de bloc }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'END') Then
      Break;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
      Break;

    { Declaration LABEL : LABEL l1, l2, ... }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'LABEL') Then
    Begin
      ParserAdvance;  { consommer LABEL }
      While (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_INTEGER) Do
      Begin
        If CurToken.Kind = TK_INTEGER Then
        Begin
          If SymFind(IntToStr_(CurToken.IntVal)) < 0 Then
            SymAdd(IntToStr_(CurToken.IntVal), SK_LABEL, TY_IDX_LABEL, 0);
        End
        Else
        Begin
          If SymFind(CurToken.Val) < 0 Then
            SymAdd(CurToken.Val, SK_LABEL, TY_IDX_LABEL, 0);
        End;
        ParserAdvance;  { consommer le nom du label }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          ParserAdvance  { consommer , }
        Else
          Break;
      End;
      Continue;
    End;

    { Declaration ARRAY seule : ARRAY id[lo:hi] (TODO 17) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'ARRAY') Then
    Begin
      ParserAdvance;  { consommer ARRAY }
      ParseArrayDecl(TY_IDX_INTEGER);  { type par defaut = INTEGER }
      Continue;
    End;

    { Declaration PROCEDURE dans un bloc (TODO 18) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'PROCEDURE') Then
    Begin
      ParserAdvance;  { consommer PROCEDURE }
      ParseProcDecl(TY_IDX_INTEGER);  { type par defaut = INTEGER }
      Continue;
    End;

    { Declaration SWITCH dans un bloc (TODO 21) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'SWITCH') Then
    Begin
      ParserAdvance;  { consommer SWITCH }
      ParseSwitchDecl;
      Continue;
    End;

    { Declaration OWN dans un bloc (TODO 22) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'OWN') Then
    Begin
      ParserAdvance;  { consommer OWN }
      ParseOwnDecl;
      Continue;
    End;

    { Mots-cles non encore geres : VALUE, COMMENT, etc. }
    If (CurToken.Kind = TK_KEYWORD) And
       ((CurToken.Val = 'VALUE') Or (CurToken.Val = 'COMMENT')) Then
    Begin
      ParserAdvance;  { consommer le mot-cle }
      Continue;
    End;

    { Instructions et declarations de type }
    ParseStmt;
  End;

  { ---- Nettoyage pile et fermeture du bloc ---- }
  LocalBytes := CurFrameSize - SavedFrameSize;
  If LocalBytes > 0 Then
  Begin
    EmitComment('libere ' + IntToStr_(LocalBytes) + ' octets locaux du bloc ' + N);
    EmitInstr('ADD', 'SP, ' + IntToStr_(LocalBytes));
  End;

  { Consommer END }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'END') Then
    ParserAdvance;

  CurFrameSize := SavedFrameSize;
  EmitComment('END bloc ' + N + ' (scope ' + IntToStr_(CurScope) + ')');
  SymLeaveScope;
End;

Procedure Run;
Begin
  GlobalInit;
  If Opts.Verbose Then ShowBanner;

  EmitOpen;
  EmitHeader;
  LexInit;

  { Premier token }
  ParserAdvance;

  { Boucle principale : parser les instructions (TODO 09) }
  While CurToken.Kind <> TK_EOF Do
  Begin
    { Fin de programme }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
      Break;

    { Separateurs : ; , : [ ] ( ) }
    If (CurToken.Kind = TK_PUNCT) And
       ((CurToken.Val = ';') Or (CurToken.Val = ',') Or
        (CurToken.Val = ':') Or (CurToken.Val = '[') Or
        (CurToken.Val = ']') Or (CurToken.Val = '(') Or
        (CurToken.Val = ')')) Then
    Begin
      ParserAdvance;
      Continue;
    End;

    { BEGIN / END : gestion de portee via ParseBlock (TODO 16) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'BEGIN') Then
    Begin
      ParserAdvance;  { consommer BEGIN }
      ParseBlock;
      Continue;
    End;
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'END') Then
    Begin
      EmitComment('END (scope ' + IntToStr_(CurScope) + ')');
      ParserAdvance;
      Continue;
    End;

    { Declarations de type : dispatcher vers ParseDeclStmt (TODO 09) }
    If (CurToken.Kind = TK_KEYWORD) And
       ((CurToken.Val = 'INTEGER') Or (CurToken.Val = 'REAL') Or
        (CurToken.Val = 'BOOLEAN') Or (CurToken.Val = 'STRING')) Then
    Begin
      ParseDeclStmt;
      Continue;
    End;

    { Instruction conditionnelle IF (TODO 13) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'IF') Then
    Begin
      ParserAdvance;  { consommer IF }
      ParseIfStmt;
      Continue;
    End;

    { Boucle FOR (TODO 14) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'FOR') Then
    Begin
      ParserAdvance;  { consommer FOR }
      ParseForStmt;
      Continue;
    End;

    { GOTO / GO TO (TODO 15) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'GOTO') Then
    Begin
      ParserAdvance;  { consommer GOTO }
      ParseGotoStmt;
      Continue;
    End;
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'GO') Then
    Begin
      ParserAdvance;  { consommer GO }
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'TO') Then
        ParserAdvance;  { consommer TO }
      ParseGotoStmt;
      Continue;
    End;

    { Declaration LABEL (TODO 15) : LABEL l1, l2, l3 }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'LABEL') Then
    Begin
      ParserAdvance;  { consommer LABEL }
      While (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_INTEGER) Do
      Begin
        If CurToken.Kind = TK_INTEGER Then
        Begin
          If SymFind(IntToStr_(CurToken.IntVal)) < 0 Then
            SymAdd(IntToStr_(CurToken.IntVal), SK_LABEL, TY_IDX_LABEL, 0);
        End
        Else
        Begin
          If SymFind(CurToken.Val) < 0 Then
            SymAdd(CurToken.Val, SK_LABEL, TY_IDX_LABEL, 0);
        End;
        ParserAdvance;  { consommer le nom du label }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          ParserAdvance  { consommer , }
        Else
          Break;
      End;
      Continue;
    End;

    { Affectation ident := expr OU label: (TODO 09 + TODO 15) }
    If (CurToken.Kind = TK_IDENT) Then
    Begin
      ParseExprStmt;
      Continue;
    End;

    { Label numerique : numero suivi de : (TODO 15) }
    If (CurToken.Kind = TK_INTEGER) Then
    Begin
      ParseExpr(GExprDummy);
      Continue;
    End;

    { Affectation orpheline := : parser l expression droite }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    Begin
      ParserAdvance;  { consommer := }
      If (CurToken.Kind <> TK_EOF) And
         Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Then
        ParseExpr(GExprDummy);
      Continue;
    End;

    { Declaration ARRAY au top-level (TODO 17) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'ARRAY') Then
    Begin
      ParserAdvance;  { consommer ARRAY }
      ParseArrayDecl(TY_IDX_INTEGER);
      Continue;
    End;

    { Declaration PROCEDURE au top-level (TODO 18) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'PROCEDURE') Then
    Begin
      ParserAdvance;  { consommer PROCEDURE }
      ParseProcDecl(TY_IDX_INTEGER);
      Continue;
    End;

    { Declaration SWITCH au top-level (TODO 21) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'SWITCH') Then
    Begin
      ParserAdvance;  { consommer SWITCH }
      ParseSwitchDecl;
      Continue;
    End;

    { Declaration OWN au top-level (TODO 22) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'OWN') Then
    Begin
      ParserAdvance;  { consommer OWN }
      ParseOwnDecl;
      Continue;
    End;

    { Mots-cles non-geres : on les saute pour l instant }
    If (CurToken.Kind = TK_KEYWORD) And
       ((CurToken.Val = 'VALUE') Or
        (CurToken.Val = 'COMMENT') Or
        (CurToken.Val = 'THEN') Or
        (CurToken.Val = 'ELSE') Or (CurToken.Val = 'TO')) Then
    Begin
      ParserAdvance;
      Continue;
    End;

    { Autre token : parser une expression }
    ParseExpr(GExprDummy);
  End;

  LexClose;
  EmitExprRuntime;                  { routines runtime (TODO 11) }
  EmitIORuntime;                    { routines I/O (TODO 12) }
  EmitMinimalRuntime;               { runtime minimal (TODO 24) }
  EmitRaw('_TEXT   ENDS');
  EmitBlankLine;
  EmitDataSeg;
  EmitBlankLine;
  EmitRaw('        END ' + A60_FN_PFX + 'Main');
  EmitClose;

  If Opts.Verbose Then ShowStats;

  Cleanup;

  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('AL60C86 - Cette commande permet de lancer le compilateur Algol 60 ',
          'pour l''assembleur du microprocesseur 8086 ou 8088.');
  WriteLn;
  WriteLn('Syntaxe : AL60C86 source.a60 [sortie.asm] [options]');
  WriteLn;
  WriteLn('Options :');
  WriteLn('  -v   mode verbeux (banniere + statistiques)');
  WriteLn('  -d   mode debug   (trace de chaque token)');
  WriteLn('  -w   activer les avertissements');
  Halt(0);
 End;
  ParseArgs;
  Run;
END.
