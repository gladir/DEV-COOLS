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

  TODO 04 - OPERATEURS ET PRECEDENCE
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

  TODO 05 - TABLE DES SYMBOLES
            TSymKind : SK_VAR, SK_PARAM, SK_PROC, SK_LABEL,
              SK_SWITCH, SK_ARRAY, SK_OWN
            TSymRec : Name, MangledName, Kind, TypeIdx, Offset,
              Scope, IsOwn, IsValue, IsName
            SymAdd, SymFind, SymFindInScope, SymMangle
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            SymEnterScope / SymLeaveScope : gestion des blocs imbriques
              Algol 60 permet des declarations locales dans chaque bloc
            Algol 60 est a portee lexicale statique (static scoping)
            Recherche en remontant les portees englobantes

  TODO 06 - SYSTEME DE TYPES
            TTypeKind : TYK_INTEGER (16 bits signe), TYK_REAL (stub entier),
              TYK_BOOLEAN (16 bits, 0 ou 1), TYK_STRING (ptr chaine),
              TYK_LABEL (adresse de code), TYK_SWITCH (tableau de labels),
              TYK_PROCEDURE (pointeur de code), TYK_ARRAY (tableau)
            TypeTab, TypeInit : enregistrer les types primitifs
            TypeSizeof : INTEGER=2, REAL=2 (tronque), BOOLEAN=2, ptr=2
            Conversion implicite INTEGER -> REAL (avertissement)
            Pas de types utilisateur en Algol 60 (pas de RECORD, pas d ENUM)
            Verification de type a la compilation pour les operateurs

  TODO 07 - EMETTEUR DE CODE ASM
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

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_ARRAY),
              IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr : variantes d ajout
            Variables globales (declarations au niveau programme) :
              entrees DK_WORD dans DATA
            Chaines litterales : DB 'abc',0 dans DATA avec label _A60K_N
            Variables OWN : entrees dans DATA (persistent entre appels)
              avec label _A60O_NomProc_NomVar
            Tableaux globaux : reserve avec DW count DUP(0)

  TODO 09 - VARIABLES ET AFFECTATIONS
            Variables globales : segment DATA, acces par label _A60V_nom
            Variables locales : pile BP, acces [BP-offset]
            Parametres par valeur : copie sur pile (comme variable locale)
            Parametres par nom : passage de thunk (adresse de sous-routine)
            Affectation := : ParseExpr + MOV destination, AX
            Affectation multiple : a := b := c := expr
              Evaluer expr une fois, affecter de droite a gauche
            Affectation de tableau : arr[i] := expr -> calcul offset + MOV

  TODO 10 - EXPRESSIONS PRIMAIRES
            ParsePrimary : literal entier, literal reel, TRUE/FALSE,
              identificateur, appel de procedure/fonction
            Acces variable simple : MOV AX, [label] ou MOV AX, [BP-offset]
            Acces element de tableau : arr[i,j] -> calcul offset lineaire
            Appel de fonction : CALL _A60P_nom -> resultat dans AX
            Parentheses : ( expr ) -> evaluation de l expression
            Expression conditionnelle : IF b THEN e1 ELSE e2
              (traitee comme expression retournant une valeur dans AX)
            Acces switch : nom[expr] -> expression designationnelle (label)

  TODO 11 - EXPRESSIONS ARITHMETIQUES ET BOOLEENNES
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

  TODO 12 - ENTREES/SORTIES (INTRINSICS)
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

  TODO 13 - INSTRUCTIONS CONDITIONNELLES (IF/THEN/ELSE)
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

  TODO 14 - BOUCLE FOR (STEP/UNTIL/WHILE)
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

  TODO 15 - GOTO ET ETIQUETTES
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

  TODO 16 - BLOCS (BEGIN/END) ET INSTRUCTIONS COMPOSEES
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

  TODO 17 - TABLEAUX (ARRAY) A BORNES DYNAMIQUES
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

  TODO 18 - DECLARATIONS DE PROCEDURES
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

  TODO 19 - APPELS DE PROCEDURES ET PARAMETRES
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

  TODO 20 - APPEL PAR NOM (THUNKS / CALL BY NAME)
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

  TODO 21 - DECLARATIONS SWITCH (AIGUILLAGES)
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

  TODO 22 - VARIABLES OWN (STATIQUES)
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

  TODO 23 - EXPRESSIONS CONDITIONNELLES ET DESIGNATIONNELLES
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

  TODO 24 - RUNTIME MINIMAL
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

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
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
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY_BLK);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;
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

  { Label sequentiel }
  LabelSeq   : Integer;

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

{ ---- EmitHeader : emettre l en-tete MASM (stub TODO 07) ---- }
Procedure EmitHeader;
Begin
  EmitComment('Genere par AL60C86 v' + AL60_VERSION + ' - ' + Opts.SrcFile);
End;

{ ---- EmitDataSeg : emettre le segment _DATA (stub TODO 08) -- }
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
        EmitRaw(DataTab[I].LblName + ' DB ' + IntToStr_(DataTab[I].IntVal));
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

{ ---- Compilation ------------------------------------------- }
Procedure Run;
Begin
  GlobalInit;
  If Opts.Verbose Then ShowBanner;

  EmitOpen;
  EmitHeader;
  LexInit;

  { Premier token }
  ParserAdvance;

  { Boucle de lexing + evaluation litteraux (TODO 03 demo) }
  While CurToken.Kind <> TK_EOF Do
  Begin
    { TODO 04+ : ParseProgram }
    ParserAdvance;
  End;

  LexClose;
  EmitDataSeg;
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
