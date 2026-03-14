{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Algol 58 vers assembleur 8086
}

(* ============================================================
  AL58C86.PAS - Compilateur Algol 58 vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
            ParseArgs : analyser argv (source.a58 [sortie.asm] [-v] [-d] [-w])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .a58 ou .alg (fichier source Algol 58)
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LEXEUR (TOKENS ALGOL 58) [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_INTEGER, TK_REAL, TK_IDENT,
              TK_KEYWORD, TK_OP, TK_PUNCT, TK_STRING, TK_LABEL
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanReal : constante reelle avec point decimal (3.14)
              Notation exposant : 10 1.5 (subscript dix) -> avertissement + trunc
            Commentaires : mot-cle comment jusqu au prochain point-virgule ;
            Mots-cles : begin end if then else for do step until while
              go to goto procedure value integer real Boolean array
              switch own true false
            Separateurs : := (affectation), ; (fin d instruction), , (virgule)
              [ ] (indices de tableau), ( ) (groupement, parametres)
            Operateurs : + - * / (div entier) ^ (puissance)
              = != < <= > >= (relationnel)
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
            Entiers decimaux : 0..65535 (unsigned) ou -32768..32767 (signe)
            Entiers signes : signe unaire + ou - devant un entier
            Reels : reconnus par le lexeur, traites comme entiers (trunc)
              Notation avec point : 3.14 -> 3 (trunc, avec avertissement)
              Notation exposant subscript 10 : 1.5 @ 3 -> 1500 (trunc)
            Booleens : true -> AX=1, false -> AX=0
            Chaines de caracteres (extensions) :
              Chaines entre guillemets "abc" -> DB dans DATA avec label
              Utilisees principalement pour les sorties (write)
            TExprKind : EK_NONE, EK_IMM, EK_AX, EK_MEM
            TExprVal : Kind, ImmVal, TypeIdx, Offset, SymIdx
            ExprMakeImm, ExprMakeNone, ExprMakeBool : constructeurs TExprVal
            LitEvalInt, LitEvalReal, LitEval : evaluer des tokens litteraux
            DataAdd, DataAddStr, DataAddWord : gestion segment DATA

  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
            Arithmetiques   : + - * / (division reelle -> IDIV)
              Division entiere : div ou (barre horizontale) -> IDIV, resultat DX ignore
              Puissance       : ^ ou ** -> CALL _A58RT_POW(AX=base, BX=exp)
            Relationnels    : = (egal) # ou != (different)
              < <= > >= (comparaison) -> CMP + Jcc
            Logiques        : and (et logique), or (ou logique), not (negation)
              Implication     : imp ou (fleche droite) -> NOT a OR b
              Equivalence     : eqv ou (double fleche) -> (a AND b) OR (NOT a AND NOT b)
            Affectation     : := (assignation)
            Unaires         : + - (signe), not (negation logique)
            Precedence (du plus fort au plus faible) :
              1. not, unaire +/-
              2. ^ (puissance)
              3. * / div
              4. + - (binaire)
              5. = # < <= > >=
              6. and
              7. or
              8. imp
              9. eqv
            EmitInstr, EmitLabel, EmitComment, EmitBlankLine, EmitRaw
            NewLabel : generateur de labels uniques _A58L_NNNNN
            ExprFlushToAX, ExprMakeAX : chargement expression dans AX
            BinOpPrec : table de precedence Algol 58 (9 niveaux)
            BinOpIsRight : ^ est droit-associatif
            EmitBinOp : pliage de constantes + code 8086
            ParsePrimary, ParseUnary, ParseExprPrec : parseur Pratt

  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
            TSymKind : SK_VAR, SK_ARRAY, SK_PROC, SK_LABEL, SK_SWITCH,
              SK_PARAM_VALUE, SK_PARAM_NAME
            TSymRec : Name, MangledName, Kind, TypeIdx, Offset,
              Scope, IsOwn (variable own persistante)
            SymAdd, SymFind, SymFindInScope, SymMangle
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            SymEnterScope / SymLeaveScope : gestion des blocs begin...end
            Variables own : persistantes entre appels de procedure
              Allouees dans DATA au lieu de la pile
            Etiquettes : labels numeriques ou symboliques pour go to

  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
            TTypeKind : TYK_INTEGER (16 bits signe), TYK_REAL (stub entier trunc),
              TYK_BOOLEAN (0 ou 1 dans AX), TYK_STRING (ptr chaine DATA),
              TYK_ARRAY (tableau), TYK_LABEL (etiquette), TYK_SWITCH (aiguillage),
              TYK_PROCEDURE (procedure)
            TypeTab, TypeInit : enregistrer les types primitifs
            TypeSizeof : integer=2, real=2 (tronque), Boolean=2, ptr=2
            Conversion implicite : integer <-> real (trunc/round selon contexte)
            Verification de type dans les affectations et les parametres
            Type des parametres par nom : evaluation retardee (thunk)

  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _A58L_NNNNN)
            Prefixes : _A58V_ (variable), _A58P_ (procedure), _A58K_ (chaine const),
              _A58RT_ (runtime), _A58L_ (label), _A58SW_ (switch),
              _A58OWN_ (variable own), _A58ARR_ (tableau)
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
            EmitProlog / EmitEpilog : PUSH BP / MOV BP,SP et MOV SP,BP / POP BP
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_ARRAY),
              IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddArray : variantes d ajout
            Variables globales (niveau programme) : entrees DK_WORD dans DATA
            Variables own : entrees DK_WORD dans DATA (persistantes)
            Chaines litterales : DB 'abc',0 dans DATA avec label _A58K_N
            Tableaux globaux : blocs DW dans DATA avec label _A58ARR_nom
            Tables de switch : DW label1, label2, ... dans DATA

  TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
            Variables globales : segment DATA, acces par label _A58V_nom
            Variables locales : pile BP, acces [BP-offset]
            Parametres par valeur (value) : copie sur pile
            Parametres par nom (name, par defaut) :
              Passage par thunk : adresse d un sous-programme qui evalue
              l expression a chaque acces -> CALL thunk -> AX=valeur
            Variables own : allouees dans DATA, persistent entre appels
              Initialisees une seule fois au premier appel
            Affectation := : ExprLoad + MOV destination, AX
            Affectation de tableau : calcul index + MOV [base+offset], AX
            Affectation multiple : a := b := expr (associatif droite)

  TODO 10 - EXPRESSIONS PRIMAIRES
            ParsePrimary : literal entier, literal reel, ident, appel proc
            Booleens : true -> MOV AX,1 / false -> XOR AX,AX
            Acces variable simple : MOV AX, [_A58V_nom] ou MOV AX, [BP-n]
            Acces tableau : nom[i] ou nom[i,j] -> calcul offset + load
            Acces parametre par nom : CALL thunk_nom -> AX=valeur
            Appel de fonction : nom(args) -> PUSH args + CALL _A58P_nom
            Groupement parenthese : (expr)
            Expression conditionnelle : if cond then expr1 else expr2
              -> evaluation condition, JZ vers expr2, sinon expr1

  TODO 11 - EXPRESSIONS BINAIRES
            ParseExprPrec(MinPrec) : boucle de precedence (Pratt)
            Arithmetique entiere : ADD/SUB pour +, - / IMUL pour *
            Division : IDIV -> AX=quotient (/) ou DX=reste (mod)
            Division entiere : div -> IDIV, resultat AX uniquement
            Puissance : ^ -> CALL _A58RT_POW(AX=base, BX=exp) -> AX
            Comparaison : CMP + Jcc pour =, #, <, <=, >, >=
              Resultat dans AX : 1 (vrai) ou 0 (faux)
            Logique and : court-circuit JZ vers false-branch
            Logique or : court-circuit JNZ vers true-branch
            Logique not : XOR AX,1
            Implication imp : NOT AX / OR AX,BX (equivalent a not a or b)
            Equivalence eqv : XOR AX,BX / XOR AX,1 (not xor)

  TODO 12 - ENTREES/SORTIES (READ / WRITE)
            Algol 58 ne standardise pas les E/S ; implementation pratique :
            Instruction write (extension) :
              write(expr)       -> conversion + INT 21h AH=40h BX=1 (STDOUT)
              write("chaine")   -> ecriture directe de la chaine DATA
              write(entier)     -> CALL _A58RT_NUMTOSTR + ecriture
              write(booleen)    -> ecriture "true" ou "false"
            Instruction writeln : write + CR+LF
            Instruction read (extension) :
              read(var)         -> INT 21h AH=0Ah (lecture ligne)
                                   CALL _A58RT_STRTONUM -> var := AX
            Instruction readln : read + consommer CR+LF
            Gestion de STDOUT (handle 1) et STDERR (handle 2)
            Formatage : ecriture d entiers signes, chaines, booleens

  TODO 13 - IF / THEN / ELSE (CONDITIONNELLES)
            ParseIfStmt : if cond then stmt [else stmt]
              Emission TEST AX,AX / JZ pour condition fausse
              Labels : _A58L_ELSE_N, _A58L_ENDIF_N
            Expression conditionnelle (inline) :
              if cond then expr1 else expr2 -> resultat dans AX
              Utilise dans les affectations : x := if b then 1 else 2
              Labels : _A58L_CEXF_N, _A58L_CEXE_N (cond expr false/end)
            Conditions imbriquees : if...then if...then...else
              Regle de rattachement : else lie au if le plus proche

  TODO 14 - BOUCLES FOR
            ParseForStmt : for v := init step incr until limit do stmt
              Variable de boucle : affectee a init au debut
              Increment : ajoute a chaque iteration (step positif ou negatif)
              Test de fin : comparaison avec limit (until)
              Labels : _A58L_FTEST_N, _A58L_FINCR_N, _A58L_FEND_N
            Variante while : for v := init while cond do stmt
              Boucle tant que cond est vraie (pas de step/until)
              Labels : _A58L_FWTEST_N, _A58L_FWEND_N
            Liste de clauses : for v := e1, e2 step s until u, e3 do stmt
              Plusieurs clauses separees par virgule, executees en sequence
              Chaque clause peut etre un element, step-until ou while
            Boucle vide : si init > limit avec step positif, ne pas executer

  TODO 15 - TABLEAUX (ARRAY)
            Declaration : array A[lo:hi] ou array A[lo1:hi1, lo2:hi2]
              Bornes entieres connues a la compilation
              Taille = (hi - lo + 1) * sizeof(element) par dimension
            Types de tableau : integer array, real array, Boolean array
            Acces element : A[i] -> calcul offset = (i - lo) * 2
              Multidimensionnel : A[i,j] -> (i-lo1)*dim2 + (j-lo2) * 2
              Emission : MOV BX, base / calcul SI offset / MOV AX,[BX+SI]
            Affectation element : A[i] := expr -> calcul offset + MOV [BX+SI],AX
            Verification de bornes : CMP index, lo / JB erreur
              CMP index, hi / JA erreur -> CALL _A58RT_CHKIDX
            Tableaux locaux : alloues sur la pile (SUB SP, taille)
            Tableaux globaux : alloues dans DATA avec label _A58ARR_nom
            Passage de tableau en parametre : adresse + descripteur de bornes

  TODO 16 - BLOCS BEGIN...END ET PORTEES
            ParseBlock : begin declarations ; instructions end
              Bloc comme unite d execution et de portee
              Declarations locales au bloc (variables, tableaux)
            Portee lexicale : variables visibles dans le bloc et sous-blocs
              SymEnterScope a begin, SymLeaveScope a end
            Blocs imbriques : begin ... begin ... end ... end
              Chaque bloc interne a sa propre portee
            Instructions composees : begin stmt1 ; stmt2 ; ... ; stmtN end
              Le point-virgule separe les instructions (pas terminateur)
            Bloc de programme principal : begin ... end (niveau 0)
            Allocation locale : SUB SP, taille_locales a l entree du bloc
              ADD SP, taille_locales a la sortie du bloc

  TODO 17 - PROCEDURES
            ParseProcDecl : procedure nom(params) ; corps
              ou procedure nom(params) ; value p1,p2 ; specs ; corps
            Parametres par valeur (value) : copie de la valeur sur la pile
              Declare par : value p1, p2 ; apres la liste de parametres
            Parametres par nom (par defaut) :
              Semantique de substitution textuelle (Jensen's device)
              Implementation par thunk : sous-programme qui evalue l expression
              CALL thunk_param -> AX = valeur courante du parametre
            Specifications de type : integer p1 ; real p2 ; apres value
            Procedures sans type de retour : pas de valeur dans AX
            Fonctions (procedure typee) : integer procedure f(x) ;
              Resultat retourne dans AX (derniere affectation a f)
              Convention : f := expr dans le corps assigne la valeur de retour
            Prologue : PUSH BP / MOV BP,SP / SUB SP, locals_size
            Epilogue : MOV SP,BP / POP BP / RET
            Procedures imbriquees : acces au cadre englobant via lien statique
              (pointeur vers BP du cadre parent passe comme parametre cache)
            Appel : PUSH args + CALL _A58P_nom / nettoyage pile apres retour

  TODO 18 - GO TO ET ETIQUETTES
            Etiquettes : labels numeriques (ex: 10:) ou symboliques (ex: boucle:)
              Declare implicitement a l apparition avec deux-points
              Stocke dans la table des symboles avec SK_LABEL
            Instruction go to : go to label ou goto label
              Emission : JMP _A58L_USR_label
              Verification : label doit exister dans la portee courante ou englobante
            Saut inter-bloc : go to vers un label dans un bloc englobant
              Necessite un ajustement de la pile (MOV SP, saved_sp)
              Avertissement si saut vers un bloc interne (interdit)
            Etiquettes non utilisees : avertissement a la compilation
            Etiquettes en avant (forward) : reference avant declaration
              Resolution en deux passes ou table de fixup

  TODO 19 - DECLARATIONS SWITCH
            ParseSwitchDecl : switch s := label1, label2, label3
              Declare un aiguillage (tableau de labels) dans la table des symboles
            Utilisation : go to s[i] -> saut a la i-eme etiquette
              Emission : MOV BX, i / DEC BX (base 1)
                SHL BX,1 / MOV AX, [_A58SW_s + BX]
                JMP AX (saut indirect via table)
            Table en DATA : _A58SW_s DW _A58L_USR_label1, _A58L_USR_label2, ...
            Verification de bornes : 1 <= i <= nombre_de_labels
              Si hors bornes : avertissement + saut a l instruction suivante
            Switch avec expressions : switch s := if b then l1 else l2, l3
              Expressions conditionnelles dans la liste de designateurs

  TODO 20 - EXPRESSIONS BOOLEENNES AVANCEES
            Operateurs booleens complets d Algol 58 :
              and (conjonction)  : AND logique -> TEST + JZ court-circuit
              or  (disjonction)  : OR logique  -> TEST + JNZ court-circuit
              not (negation)     : XOR AX, 1
              imp (implication)  : a imp b <=> not a or b
                Emission : NOT AX -> OR AX, BX (valeur de b)
              eqv (equivalence)  : a eqv b <=> (a and b) or (not a and not b)
                Emission : XOR AX, BX / XOR AX, 1 (not xor = equivalence)
            Evaluation court-circuit pour and et or
            Comparaisons chainees : pas supportees (a < b < c -> erreur syntaxe)
            Resultat booleen : toujours 0 (false) ou 1 (true) dans AX
            Utilisation dans les conditions : if, for while, expression cond

  TODO 21 - FONCTIONS MATHEMATIQUES INTRINSEQUES
            abs(x)   -> CALL _A58RT_ABS(AX=n) : valeur absolue -> AX
            sign(x)  -> CALL _A58RT_SIGN(AX=n) : -1, 0 ou 1 -> AX
            entier(x)-> trunc (identite en 16 bits entier, avertissement)
            sqrt(x)  -> CALL _A58RT_SQRT(AX=n) : racine carree entiere (Newton)
            sin(x)   -> CALL _A58RT_SIN : stub -> AX=0 + avertissement
            cos(x)   -> CALL _A58RT_COS : stub -> AX=1 + avertissement
            arctan(x)-> CALL _A58RT_ARCTAN : stub -> AX=0 + avertissement
            ln(x)    -> CALL _A58RT_LN : stub -> AX=0 + avertissement
            exp(x)   -> CALL _A58RT_EXP : stub -> AX=1 + avertissement
            max(a,b) -> CALL _A58RT_MAX(AX=a, BX=b) -> AX
            min(a,b) -> CALL _A58RT_MIN(AX=a, BX=b) -> AX
            mod(a,b) -> IDIV : reste dans DX -> MOV AX,DX
            Les fonctions transcendantes (sin, cos, ln, exp, arctan) sont
              des stubs car le 8086 n a pas de FPU ; avertissement emis

  TODO 22 - PARAMETRES PAR NOM ET THUNKS
            Semantique du passage par nom en Algol 58 :
              Le parametre est remplace textuellement par l argument
              A chaque acces, l expression argument est reevaluee
            Implementation par thunks :
              Pour chaque argument passe par nom, generer un sous-programme
              _A58TH_proc_param PROC NEAR : evalue l expression -> AX / RET
              Passer l adresse du thunk sur la pile au lieu de la valeur
            Acces au parametre par nom dans le corps :
              CALL WORD PTR [BP+offset_thunk] -> AX = valeur courante
            Jensen's device : for i := 1 step 1 until n do
              sum := sum + V[i]  (V passe par nom -> V[i] reevalue a chaque iteration)
            Thunks avec variables capturees :
              Le thunk accede au cadre de l appelant via lien statique
              MOV BP, [BP+lien_statique] avant evaluation dans le thunk
            Optimisation : si l argument est une simple variable,
              passage par reference au lieu de thunk (LEA au lieu de CALL)

  TODO 23 - GESTION DES ERREURS DE COMPILATION
            TErrorRec : Line, Col, Msg
            ErrTab[0..MAX_ERRORS-1], ErrCount
            FatalError(msg) : affiche erreur + arret immediat (Halt)
            WarnMsg(msg) : affiche avertissement + continue
            Erreurs lexicales : caractere invalide, chaine non fermee,
              nombre trop grand, commentaire non termine
            Erreurs syntaxiques : token inattendu, begin/end non apparie,
              point-virgule manquant, parenthese non fermee
            Erreurs semantiques : variable non declaree, type incompatible,
              tableau hors bornes (si constant), label duplique
            Mode de recuperation : sauter jusqu au prochain point-virgule
              ou mot-cle structurant (begin, end, for, if, procedure)
            Compteur d erreurs : arret si ErrCount >= MAX_ERRORS
            Statistiques finales : nombre d erreurs et avertissements

  TODO 24 - RUNTIME MINIMAL
            _A58RT_PRINT(BX=handle, SI=msg, CX=len) : INT 21h AH=40h
            _A58RT_PRINTLN : _A58RT_PRINT + CR+LF via _A58_CRLF DB 13,10,0
            _A58RT_STRLEN(SI=str) : compte octets jusqu a 0 -> AX
            _A58RT_NUMTOSTR(AX=n, DI=buf) : entier signe -> ASCII (itoa)
            _A58RT_STRTONUM(SI=str) : ASCII -> entier -> AX (atoi)
            _A58RT_ABS(AX=n) : valeur absolue -> AX (NEG si negatif)
            _A58RT_SIGN(AX=n) : signe -> AX = -1, 0 ou 1
            _A58RT_POW(AX=base, BX=exp) : puissance entiere -> AX
            _A58RT_SQRT(AX=n) : racine carree entiere (Newton-Raphson) -> AX
            _A58RT_MAX(AX=a, BX=b) : maximum -> AX
            _A58RT_MIN(AX=a, BX=b) : minimum -> AX
            _A58RT_CHKIDX(AX=index, BX=lo, CX=hi) : verification bornes tableau
              -> CALL _A58RT_PANIC si hors bornes
            _A58RT_PANIC(SI=msg) : affiche message + MOV AX,4C01h + INT 21h
            RuntimeEmitted : flag pour n emettre le runtime qu une seule fois
            Heap statique : _A58_HEAP DB 2048 DUP(0) + _A58_HEAPTOP DW 0
            Buffer de travail : _A58_STRBUF DB 256 DUP(0) pour conversions

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitClose : END _A58P_Main dans _TEXT ENDS / DATA ENDS
            Run : pipeline complet LexInit -> ParseBlock (programme) ->
              EmitRuntime -> _TEXT ENDS / EmitDataSeg / END _A58P_Main
            Fichiers SAMPLES\ALGOL58\ a creer :
              hello.a58   (write/writeln, variables, constantes, chaines)
              math.a58    (expressions, abs, sign, puissance, fonctions)
              control.a58 (if/then/else, for step until, for while)
              arrays.a58  (array, acces indexe, bornes, multidimensionnel)
              procs.a58   (procedure, value, parametres par nom, Jensen)
              switch.a58  (switch, go to, etiquettes, saut conditionnel)
              blocks.a58  (begin/end, portees imbriquees, variables own)
              bool.a58    (and, or, not, imp, eqv, expressions booleennes)
            Smoke tests : AL58C86.EXE -v SAMPLES\ALGOL58\*.a58

  ============================================================ *)

{ ============================================================
  AL58C86 - Compilateur Algol 58 -> assembleur 8086
  Version : 1.0  Date : 2026-03-06
  Compilation : ppc386 -O2 -Mtp AL58C86.PAS
  ============================================================ }

Program AL58C86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  AL58_VERSION = '1.0';
  AL58_DATE    = '2026-03-06';

  { Limites internes }
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}32{$ELSE}16{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  STACK_SIZE    = 1024;

  { Prefixes de nommage ASM }
  A58_VAR_PFX  = '_A58V_';    { variable scalaire                  }
  A58_PROC_PFX = '_A58P_';    { procedure / fonction               }
  A58_STR_PFX  = '_A58K_';    { constante chaine litterale         }
  A58_RT_PFX   = '_A58RT_';   { routine runtime                    }
  A58_LBL_PFX  = '_A58L_';    { label de saut interne              }
  A58_SW_PFX   = '_A58SW_';   { table switch                       }
  A58_OWN_PFX  = '_A58OWN_';  { variable own                       }
  A58_ARR_PFX  = '_A58ARR_';  { tableau                            }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Indices de types primitifs Algol 58 }
  TY_IDX_INTEGER   = 0;  { entier 16 bits signe   }
  TY_IDX_REAL      = 1;  { reel (stub entier)     }
  TY_IDX_BOOLEAN   = 2;  { 0 ou 1 dans AX         }
  TY_IDX_STRING    = 3;  { pointeur chaine DATA    }
  TY_IDX_LABEL     = 4;  { etiquette               }
  TY_IDX_SWITCH    = 5;  { aiguillage              }
  TY_IDX_PROCEDURE = 6;  { procedure               }
  TY_PRIM_COUNT    = 7;
  TY_UNKNOWN       = -1;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;   { fichier source (.a58 ou .alg)        }
    OutFile   : TString;   { fichier assembleur de sortie (.asm)  }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Warnings  : Boolean;   { -w : activer les avertissements      }
  End;

  { ---- Tokens Algol 58 (TODO 02) ------------------------- }
  TTokenKind = (
    TK_EOF,       { fin de fichier                          }
    TK_INTEGER,   { literal entier 42                       }
    TK_REAL,      { literal reel 3.14                       }
    TK_STRING,    { literal chaine "abc"                    }
    TK_IDENT,     { identificateur                          }
    TK_KEYWORD,   { mot-cle Algol 58                        }
    TK_OP,        { operateur + - * / ^ := = # < > <= >=   }
    TK_PUNCT,     { ponctuation ; , ( ) [ ]                 }
    TK_LABEL      { etiquette numerique ou symbolique       }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;     { valeur textuelle brute          }
    IntVal   : LongInt;     { valeur entiere (TK_INTEGER)     }
    RealVal  : Real;        { valeur reelle (TK_REAL)         }
    Line     : Integer;     { ligne source (1-base)           }
    Col      : Integer;     { colonne source (1-base)         }
  End;

  { ---- Categories de symboles (TODO 05) ------------------ }
  TSymKind = (
    SK_VAR,          { variable scalaire              }
    SK_ARRAY,        { tableau                        }
    SK_PROC,         { procedure / fonction           }
    SK_LABEL,        { etiquette                      }
    SK_SWITCH,       { aiguillage (switch)            }
    SK_PARAM_VALUE,  { parametre par valeur           }
    SK_PARAM_NAME    { parametre par nom (thunk)      }
  );

  TSymRec = Record
    Name        : TString;   { identifiant Algol 58            }
    MangledName : TString;   { _A58V_nom / _A58P_nom           }
    Kind        : TSymKind;
    TypeIdx     : Integer;   { indice dans TypeTab             }
    ScopeLevel  : Integer;
    Offset      : Integer;   { [BP-n] pour locaux              }
    IsOwn       : Boolean;   { variable own (persistante)      }
    DeclLine    : Integer;
  End;

  { ---- Types internes (TODO 06) -------------------------- }
  TTypeKind = (
    TYK_INTEGER,
    TYK_REAL,
    TYK_BOOLEAN,
    TYK_STRING,
    TYK_ARRAY,
    TYK_LABEL,
    TYK_SWITCH,
    TYK_PROCEDURE
  );

  TTypeRec = Record
    Name    : TString;
    Kind    : TTypeKind;
    Size    : Integer;   { octets : integer=2, ptr=2 }
  End;

  { ---- Segment de donnees (TODO 08) ---------------------- }
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY_BLK, DK_SWITCH_TAB);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;  { DK_ARRAY_BLK : nb elements }
  End;

  { ---- Valeurs d'expression (TODO 03) -------------------- }
  TExprKind = (
    EK_NONE,   { void / pas de valeur             }
    EK_IMM,    { immediate dans ImmVal             }
    EK_AX,     { valeur dans AX                    }
    EK_MEM,    { adresse [BP+Offset] ou [_A58V_x]  }
    EK_STACK   { valeur sauvee sur la pile (PUSH)  }
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
    SymIdx  : Integer;
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

  { Lexeur (TODO 02) }
  LexSrcF   : Text;
  LexLine   : String;
  LexLineNo : Integer;
  LexColNo  : Integer;
  LexEOF    : Boolean;
  LexOpened : Boolean;
  CurToken  : TToken;

  { Table des symboles (TODO 05) }
  SymTab     : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount   : Integer;
  ScopeStack : Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeTop   : Integer;
  CurScope   : Integer;
  LabelSeq   : Integer;

  { Table des types (TODO 06) }
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

  { Emetteur ASM (TODO 07) }
  OutF         : Text;
  OutFOpen     : Boolean;
  CurFrameSize : Integer;    { taille cadre local courant (words)   }
  CurFnDepth   : Integer;    { 0 = global, >0 = dans une procedure }
  CurFnRetLbl  : TString;    { label epilogue de la procedure       }
  CurFnName    : TString;    { nom de la procedure courante         }
  LoopTop      : Integer;

  { Segment de donnees (TODO 08) }
  DataTab   : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount : Integer;
  StrSeq    : Integer;  { compteur pour les labels de chaines _A58K_NNN }

  { Valeur fictive pour ignorer un retour TExprVal }
  GExprDummy : TExprVal;

  { Etat general }
  RuntimeEmitted : Boolean;

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
Procedure EmitOpen;     Forward;
Procedure EmitClose;    Forward;
Procedure EmitDataSeg;  Forward;
Procedure EmitRuntime;  Forward;
Procedure EmitHeader;   Forward;
{ TODO 02 - Lexeur }
Procedure LexInit;             Forward;
Procedure LexClose;            Forward;
Function  IsKeyword(Const S : TString) : Boolean; Forward;
Procedure PrintToken(Const T : TToken); Forward;
Procedure LexNextLine;         Forward;
Function  IsIdentStart(Ch : Char) : Boolean; Forward;
Function  IsIdentCont(Ch : Char) : Boolean;  Forward;
Procedure LexScanIdent;        Forward;
Procedure LexScanNumber;       Forward;
Procedure LexScanString;       Forward;
Procedure LexSkipComment;      Forward;
Procedure LexNextToken;        Forward;
Procedure ParserAdvance; Forward;
Procedure ParseBlock;   Forward;
Procedure TypeInit;     Forward;
Procedure SymInit;      Forward;
{ TODO 03 - Litteraux et constantes }
Function  DataAdd(Const ALbl : TString; AKind : TDataKind;
                  AInt : LongInt; Const AStr : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : TString; Forward;
Function  DataAddWord(Const ALbl : TString;
                      AInit : LongInt) : Integer; Forward;
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ExprMakeNone(Var Res : TExprVal); Forward;
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal); Forward;
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEvalReal(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
{ TODO 04 - Operateurs et precedence }
Procedure EmitRaw(Const S : TString); Forward;
Procedure EmitInstr(Const Mnem, Ops : TString); Forward;
Procedure EmitLabel(Const Lbl : TString); Forward;
Procedure EmitComment(Const Msg : TString); Forward;
Procedure EmitBlankLine; Forward;
Function  NewLabel : TString; Forward;
Procedure ExprFlushToAX(Var E : TExprVal); Forward;
Procedure ExprMakeAX(ATypeIdx : Integer; Var Res : TExprVal); Forward;
Function  BinOpPrec(Const Op : TString) : Integer; Forward;
Function  BinOpIsRight(Const Op : TString) : Boolean; Forward;
Procedure EmitBinOp(Const Op : TString;
                    Var L : TExprVal; Var R : TExprVal); Forward;
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Procedure ParseUnary(Var Res : TExprVal); Forward;
Procedure ParseExprPrec(MinPrec : Integer;
                        Var Res : TExprVal); Forward;
{ TODO 05 - Table des symboles }
Function  SymNameClean(Const Name : TString) : TString; Forward;
Function  SymMangle(Const Name : TString; Kind : TSymKind) : TString; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindInScope(Const Name : TString;
                         Level : Integer) : Integer; Forward;
Function  SymAdd(Const Name : TString; Kind : TSymKind;
                 TypeIdx, Offset : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
{ TODO 06 - Systeme de types }
Function  TypeAdd(Kind : TTypeKind; Const AName : TString;
                  Size : Integer) : Integer; Forward;
Function  TypeSizeof(TIdx : Integer) : Integer; Forward;
Function  TypeKindOf(TIdx : Integer) : TTypeKind; Forward;
Function  TypeIsNumeric(TIdx : Integer) : Boolean; Forward;
Function  TypeCheckAssign(DstIdx, SrcIdx : Integer) : Boolean; Forward;
{ TODO 07 - Emetteur de code ASM }
Procedure EmitProlog; Forward;
Procedure EmitEpilog; Forward;
{ TODO 08 - Segment de donnees et statiques }
Function  DataAddArray(Const ALbl : TString;
                       AElemCount : Integer) : Integer; Forward;
Procedure DataInit; Forward;
{ TODO 09 - Variables et affectations }
Procedure ParseVarDecl; Forward;
Procedure ParseOwnDecl; Forward;
Procedure ParseAssign(VarIdx : Integer); Forward;
Procedure ParseStmt; Forward;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- Messages d erreur et d avertissement ---------------- }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('AL58C86: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
    Assign(OutF, Opts.OutFile);
    Erase(OutF);
  End;
  Halt(EXIT_ERROR);
End;

Procedure CompileError(Const Msg : TString);
Begin
  Write('AL58C86:');
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
  Write('AL58C86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('warning: ', Msg);
  Inc(WarnCount);
End;

{ ---- Banniere ---------------------------------------------- }

Procedure ShowBanner;
Begin
  WriteLn('AL58C86 v', AL58_VERSION, ' (', AL58_DATE, ')');
  WriteLn('Compilateur Algol 58 -> assembleur 8086 (MASM .MODEL SMALL)');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('Usage: AL58C86 <source.a58> [sortie.asm] [-v] [-d] [-w]');
  WriteLn;
  WriteLn('  source.a58 : fichier Algol 58 source (.a58 ou .alg)');
  WriteLn('  sortie.asm : fichier assembleur de sortie (defaut: source.asm)');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn('  -h, --help : cette aide');
  WriteLn;
  Halt(EXIT_USAGE);
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

Function IntToStr_(N : LongInt) : TString;
Var
  S : TString;
Begin
  Str(N, S);
  IntToStr_ := S;
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
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowUsage;

  For I := 1 To ParamCount Do
  Begin
    Arg := ParamStr(I);

    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Then
      ShowUsage
    Else If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('AL58C86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('AL58C86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('AL58C86: fichier source manquant');
    ShowUsage;
  End;

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
  LabelSeq       := 0;
  TypeCount      := 0;
  DataCount      := 0;
  StrSeq         := 0;
  OutFOpen       := False;
  LexOpened      := False;
  LexEOF         := False;
  CurFnDepth     := 0;
  CurFnRetLbl    := '';
  CurFnName      := '';
  LoopTop        := 0;
  RuntimeEmitted := False;
  CurFrameSize   := 0;
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
End;

{ ---- ShowStats --------------------------------------------- }

Procedure ShowStats;
Begin
  WriteLn;
  WriteLn('Compilation terminee : ', Opts.SrcFile, ' -> ', Opts.OutFile);
  WriteLn('  Lignes         : ', TotalLines);
  WriteLn('  Symboles       : ', TotalSyms);
  WriteLn('  Erreurs        : ', ErrorCount);
  WriteLn('  Avertissements : ', WarnCount);
End;

{ ============================================================
  TODO 02 - LEXEUR (TOKENS ALGOL 58) [IMPLEMENTE]
  ============================================================ }

{ ---- IsKeyword : teste si S est un mot-cle Algol 58 -------- }
Function IsKeyword(Const S : TString) : Boolean;
Begin
  IsKeyword :=
    (S = 'begin')     Or (S = 'end')       Or (S = 'if')         Or
    (S = 'then')      Or (S = 'else')      Or (S = 'for')        Or
    (S = 'do')        Or (S = 'step')      Or (S = 'until')      Or
    (S = 'while')     Or (S = 'go')        Or (S = 'to')         Or
    (S = 'goto')      Or (S = 'procedure') Or (S = 'value')      Or
    (S = 'integer')   Or (S = 'real')      Or (S = 'Boolean')    Or
    (S = 'array')     Or (S = 'switch')    Or (S = 'own')        Or
    (S = 'true')      Or (S = 'false')     Or (S = 'comment')    Or
    (S = 'and')       Or (S = 'or')        Or (S = 'not')        Or
    (S = 'imp')       Or (S = 'eqv')       Or (S = 'div')        Or
    (S = 'mod')       Or (S = 'string')    Or (S = 'label')      Or
    (S = 'write')     Or (S = 'writeln')   Or (S = 'read')       Or
    (S = 'readln')    Or (S = 'abs')       Or (S = 'sign')       Or
    (S = 'sqrt')      Or (S = 'sin')       Or (S = 'cos')        Or
    (S = 'arctan')    Or (S = 'ln')        Or (S = 'exp')        Or
    (S = 'entier')    Or (S = 'max')       Or (S = 'min');
End;

{ ---- PrintToken : affichage debug d un token --------------- }
Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF     : Write('EOF');
    TK_INTEGER : Write('INT(', T.IntVal, ')');
    TK_REAL    : Write('REAL(', T.Val, ')');
    TK_STRING  : Write('STR("', T.Val, '")');
    TK_IDENT   : Write('IDENT(', T.Val, ')');
    TK_KEYWORD : Write('KW(', T.Val, ')');
    TK_OP      : Write('OP(', T.Val, ')');
    TK_PUNCT   : Write('PUNCT(', T.Val, ')');
    TK_LABEL   : Write('LABEL(', T.Val, ')');
  End;
  WriteLn;
End;

{ ---- LexNextLine : lire la prochaine ligne source ----------- }
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

{ ---- Fonctions de test sur les caracteres ------------------- }
Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or
                  (Ch = '_');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsIdentStart(Ch) Or ((Ch >= '0') And (Ch <= '9'));
End;

{ ---- LexScanIdent : scanner un identificateur ou mot-cle --- }
Procedure LexScanIdent;
Var
  S : TString;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) And IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
  If IsKeyword(S) Then
    CurToken.Kind := TK_KEYWORD
  Else
    CurToken.Kind := TK_IDENT;
End;

{ ---- LexScanNumber : scanner un litteral numerique ---------- }
{ Supporte : entiers decimaux, reels avec point (3.14)         }
{ Les reels sont tronques a un entier (avec avertissement)     }
Procedure LexScanNumber;
Var
  N       : LongInt;
  Ch      : Char;
  IsReal  : Boolean;
  FracDiv : Real;
  FracVal : Real;
  FltVal  : Real;
Begin
  N       := 0;
  IsReal  := False;
  FracVal := 0.0;
  FracDiv := 10.0;

  { Scanner la partie entiere }
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
  Begin
    Ch := LexLine[LexColNo];
    N := N * 10 + (Ord(Ch) - Ord('0'));
    Inc(LexColNo);
  End;

  { Partie decimale .ddd }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And
     (LexLine[LexColNo + 1] >= '0') And (LexLine[LexColNo + 1] <= '9') Then
  Begin
    IsReal := True;
    Inc(LexColNo); { sauter le point }
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

  { Si reel, tronquer a entier avec avertissement }
  If IsReal Then
  Begin
    FltVal := N + FracVal;
    If FltVal > 32767.0 Then N := 32767
    Else If FltVal < -32768.0 Then N := -32768
    Else N := Trunc(FltVal);
    CurToken.Kind    := TK_REAL;
    CurToken.IntVal  := N;
    CurToken.RealVal := N + FracVal;
    Str(CurToken.RealVal:0:6, CurToken.Val);
    WarnMsg('reel tronque a entier: ' + CurToken.Val + ' -> ' + IntToStr_(N));
  End
  Else
  Begin
    CurToken.Kind    := TK_INTEGER;
    CurToken.IntVal  := N;
    CurToken.RealVal := 0.0;
    Str(N, CurToken.Val);
  End;
End;

{ ---- LexScanString : scanner une chaine entre guillemets --- }
Procedure LexScanString;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo); { sauter guillemet ouvrant }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '"' Then
    Begin
      Inc(LexColNo);
      { Guillemet double "" = guillemet litteral }
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '"') Then
      Begin
        If Length(S) < MAX_STR Then S := S + '"';
        Inc(LexColNo);
      End
      Else
        Break; { fin de chaine }
    End
    Else
    Begin
      If Length(S) < MAX_STR Then S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexSkipComment : sauter commentaire Algol 58 ---------- }
{ Le mot-cle 'comment' a deja ete lu. On saute tout jusqu au   }
{ prochain point-virgule ;                                      }
Procedure LexSkipComment;
Begin
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      LexNextLine;
    End
    Else If LexLine[LexColNo] = ';' Then
    Begin
      Inc(LexColNo); { consommer le ; }
      Exit;
    End
    Else
      Inc(LexColNo);
  End;
End;

{ ---- LexNextToken : scanner principal ----------------------- }
Procedure LexNextToken;
Var
  Ch : Char;
  Scanning : Boolean;
Begin
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;

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
      Scanning := False;
      Break;
    End;

    CurToken.Line := LexLineNo;
    CurToken.Col  := LexColNo;
    Ch := LexLine[LexColNo];

    { Espaces blancs }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
    Begin
      Inc(LexColNo);
    End

    { Identificateur ou mot-cle }
    Else If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      { Traitement special du mot-cle 'comment' }
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'comment') Then
      Begin
        LexSkipComment;
        { continue la boucle pour scanner le prochain token }
      End
      { Traitement de 'go to' comme mot-cle compose }
      Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'go') Then
      Begin
        { Regarder si le prochain non-espace est 'to' }
        While (LexColNo <= Length(LexLine)) And
              ((LexLine[LexColNo] = ' ') Or (LexLine[LexColNo] = #9)) Do
          Inc(LexColNo);
        If (LexColNo + 1 <= Length(LexLine)) And
           (LexLine[LexColNo] = 't') And (LexLine[LexColNo + 1] = 'o') And
           ((LexColNo + 2 > Length(LexLine)) Or
            Not IsIdentCont(LexLine[LexColNo + 2])) Then
        Begin
          Inc(LexColNo); Inc(LexColNo); { consommer 'to' }
          CurToken.Val := 'goto';
        End;
        Scanning := False;
      End
      { Operateurs logiques : and, or, not, imp, eqv sont des mots-cles }
      { mais aussi des operateurs -> on les traite comme TK_KEYWORD }
      Else
        Scanning := False;
    End

    { Nombre }
    Else If (Ch >= '0') And (Ch <= '9') Then
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

    { Operateur := (affectation) }
    Else If (Ch = ':') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := ':=';
      Inc(LexColNo); Inc(LexColNo);
      Scanning := False;
    End

    { Label : nombre ou ident suivi de ':' (sans '=') }
    { Gere dans le parser ; ici ':' est ponctuation }
    Else If Ch = ':' Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := ':';
      Inc(LexColNo);
      Scanning := False;
    End

    { Operateur <= }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '<=';
      Inc(LexColNo); Inc(LexColNo);
      Scanning := False;
    End

    { Operateur >= }
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '>=';
      Inc(LexColNo); Inc(LexColNo);
      Scanning := False;
    End

    { Operateur != ou # (different) }
    Else If (Ch = '!') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '!=';
      Inc(LexColNo); Inc(LexColNo);
      Scanning := False;
    End
    Else If Ch = '#' Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '#';
      Inc(LexColNo);
      Scanning := False;
    End

    { Operateur ** (puissance alternative) }
    Else If (Ch = '*') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '^';  { normalise a ^ }
      Inc(LexColNo); Inc(LexColNo);
      Scanning := False;
    End

    { Operateurs simples : + - * / ^ = < > }
    Else If Ch In ['+', '-', '*', '/', '^', '=', '<', '>'] Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Scanning := False;
    End

    { Ponctuation : ; , ( ) [ ] }
    Else If Ch In [';', ',', '(', ')', '[', ']'] Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Scanning := False;
    End

    { Caractere inconnu : erreur + avancer }
    Else
    Begin
      CompileError('caractere inattendu: ' + Ch);
      Inc(LexColNo);
    End;
  End;

  PrintToken(CurToken);
End;

{ ---- LexInit : ouvrir le fichier source et initialiser ----- }
Procedure LexInit;
Begin
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
  LexOpened := True;
  LexLineNo := 0;
  LexColNo  := 1;
  LexEOF    := False;
  LexLine   := '';
  { Lire la premiere ligne }
  LexNextLine;
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

{ ---- ParserAdvance : lire le prochain token ----------------- }
Procedure ParserAdvance;
Begin
  LexNextToken;
End;

{ ============================================================
  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

{ ---- DataAdd : enregistrer une entree dans DataTab ---------- }
{ Retourne l index alloue ou -1 si table pleine.               }
Function DataAdd(Const ALbl : TString; AKind : TDataKind;
                 AInt : LongInt; Const AStr : TString) : Integer;
Var Idx : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    FatalError('Table de donnees statiques pleine (MAX_DATA)');
    DataAdd := -1;
    Exit;
  End;
  Idx := DataCount;
  DataTab[Idx].LblName   := ALbl;
  DataTab[Idx].Kind      := AKind;
  DataTab[Idx].IntVal    := AInt;
  DataTab[Idx].StrVal    := AStr;
  DataTab[Idx].ElemCount := 0;
  Inc(DataCount);
  DataAdd := Idx;
End;

{ ---- DataAddStr : creer une entree DK_STR et retourner le label }
{ Reutilise les doublons (meme contenu -> meme label).            }
{ Retourne le label ASM de la chaine dans DATA.                   }
Function DataAddStr(Const S : TString) : TString;
Var
  I   : Integer;
  Lbl : TString;
  NS  : TString;
Begin
  { Chercher un doublon existant }
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_STR) And (DataTab[I].StrVal = S) Then
    Begin
      DataAddStr := DataTab[I].LblName;
      Exit;
    End;
  { Nouvelle chaine }
  Inc(StrSeq);
  Str(StrSeq, NS);
  Lbl := A58_STR_PFX + NS;
  DataAdd(Lbl, DK_STR, 0, S);
  DataAddStr := Lbl;
End;

{ ---- DataAddWord : enregistrer un mot DW (variable globale) - }
Function DataAddWord(Const ALbl : TString;
                     AInit : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(ALbl, DK_WORD, AInit, '');
End;

{ ---- ExprMakeImm : construire une valeur immediate ---------- }
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprMakeNone : expression sans valeur (void/erreur) ---- }
Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprMakeBool : valeur booleenne (0 ou 1) --------------- }
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  If AVal <> 0 Then Res.ImmVal := 1 Else Res.ImmVal := 0;
  Res.TypeIdx := TY_IDX_BOOLEAN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- LitEvalInt : convertir un token TK_INTEGER en valeur --- }
{ IntVal est deja calcule par LexScanNumber.                    }
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_INTEGER, Res);
End;

{ ---- LitEvalReal : convertir TK_REAL -> entier (trunc) ----- }
{ Algol 58 cible 8086 : pas de FPU, les reels sont tronques.   }
Procedure LitEvalReal(Const T : TToken; Var Res : TExprVal);
Var
  IV : LongInt;
Begin
  IV := T.IntVal;  { deja tronque par LexScanNumber }
  ExprMakeImm(IV, TY_IDX_REAL, Res);
End;

{ ---- LitEval : dispatcher principal pour les litteraux ------ }
{ Tokens acceptes : TK_INTEGER, TK_REAL, TK_STRING, TK_KEYWORD }
{ (true/false).                                                 }
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeNone(Res);  { valeur par defaut }
  Case T.Kind Of
    TK_INTEGER : LitEvalInt(T, Res);
    TK_REAL    : LitEvalReal(T, Res);
    TK_STRING  :
    Begin
      { Stocker la chaine dans DATA ; DataAddStr retourne le label }
      DataAddStr(T.Val);
      Res.Kind    := EK_IMM;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STRING;
      Res.Offset  := DataCount - 1;  { index dans DataTab }
      Res.SymIdx  := -1;
    End;
    TK_KEYWORD :
    Begin
      If T.Val = 'true' Then
        ExprMakeBool(1, Res)
      Else If T.Val = 'false' Then
        ExprMakeBool(0, Res)
      Else
        ExprMakeNone(Res);
    End;
  Else
    ExprMakeNone(Res);
  End;
End;

{ ============================================================
  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
  ============================================================ }

{ ---- EmitRaw : ligne brute sans indentation ------------------ }
Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then WriteLn(OutF, S);
End;

{ ---- EmitInstr : instruction indentee (8 espaces + mnem + ops) }
Procedure EmitInstr(Const Mnem, Ops : TString);
Begin
  If Not OutFOpen Then Exit;
  If Ops <> '' Then WriteLn(OutF, '        ', Mnem, '    ', Ops)
  Else WriteLn(OutF, '        ', Mnem);
End;

{ ---- EmitLabel : etiquette suivie de ':' --------------------- }
Procedure EmitLabel(Const Lbl : TString);
Begin
  If OutFOpen Then WriteLn(OutF, Lbl, ':');
End;

{ ---- EmitComment : commentaire ASM (prefixe '; ') ------------ }
Procedure EmitComment(Const Msg : TString);
Begin
  If OutFOpen Then WriteLn(OutF, '; ', Msg);
End;

{ ---- EmitBlankLine : ligne vide ------------------------------ }
Procedure EmitBlankLine;
Begin
  If OutFOpen Then WriteLn(OutF);
End;

{ ---- NewLabel : generer un label unique _A58L_NNNNN ---------- }
Function NewLabel : TString;
Var NS : TString;
Begin
  Inc(LabelSeq);
  Str(LabelSeq, NS);
  NewLabel := A58_LBL_PFX + NS;
End;

{ ---- ExprMakeAX : construire une valeur deja dans AX --------- }
Procedure ExprMakeAX(ATypeIdx : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_AX;
  Res.ImmVal  := 0;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprFlushToAX : materialiser la valeur dans AX ---------- }
{ Si EK_IMM : MOV AX, val. Si EK_MEM : MOV AX, [adr].          }
{ Si EK_AX : rien a faire. Si EK_NONE : XOR AX,AX.             }
Procedure ExprFlushToAX(Var E : TExprVal);
Var S : TString;
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
      { Chaine litterale : Offset = index DataTab -> OFFSET label }
      If E.TypeIdx = TY_IDX_STRING Then
      Begin
        If (E.Offset >= 0) And (E.Offset < DataCount) Then
          EmitInstr('MOV', 'AX, OFFSET ' + DataTab[E.Offset].LblName)
        Else
          EmitInstr('XOR', 'AX, AX');
      End
      { Variable locale : [BP-n] }
      Else If E.Offset < 0 Then
      Begin
        Str(-E.Offset, S);
        EmitInstr('MOV', 'AX, [BP-' + S + ']');
      End
      { Variable parametre/frame : [BP+n] }
      Else
      Begin
        Str(E.Offset, S);
        EmitInstr('MOV', 'AX, [BP+' + S + ']');
      End;
      E.Kind := EK_AX;
    End;
    EK_AX : ;
    EK_STACK :
    Begin
      EmitInstr('POP', 'AX');
      E.Kind := EK_AX;
    End;
    EK_NONE :
    Begin
      EmitInstr('XOR', 'AX, AX');
      E.Kind := EK_AX;
    End;
  End;
End;

{ ---- BinOpPrec : table de precedence Algol 58 ----------------
  Retourne 0 si l operateur n est pas un operateur binaire.
  Niveaux (echelle inversee : plus le nombre est haut, plus la
  precedence est forte) :
    eqv         -> 1
    imp         -> 2
    or          -> 3
    and         -> 4
    = # != < <= > >=  -> 5  (relationnels)
    + - (binaire)     -> 6
    * / div mod       -> 7
    ^ **              -> 8  (puissance)                           }
Function BinOpPrec(Const Op : TString) : Integer;
Begin
  If      Op = 'eqv'                                     Then BinOpPrec := 1
  Else If Op = 'imp'                                     Then BinOpPrec := 2
  Else If Op = 'or'                                      Then BinOpPrec := 3
  Else If Op = 'and'                                     Then BinOpPrec := 4
  Else If (Op = '=') Or (Op = '#') Or (Op = '!=')
       Or (Op = '<') Or (Op = '<=')
       Or (Op = '>') Or (Op = '>=')                     Then BinOpPrec := 5
  Else If (Op = '+') Or (Op = '-')                       Then BinOpPrec := 6
  Else If (Op = '*') Or (Op = '/') Or (Op = 'div')
       Or (Op = 'mod')                                   Then BinOpPrec := 7
  Else If (Op = '^') Or (Op = '**')                      Then BinOpPrec := 8
  Else                                                        BinOpPrec := 0;
End;

{ ---- BinOpIsRight : ^ et ** sont droit-associatifs ----------- }
Function BinOpIsRight(Const Op : TString) : Boolean;
Begin
  BinOpIsRight := (Op = '^') Or (Op = '**');
End;

{ ---- EmitBinOp : generer le code 8086 d un operateur binaire --
  Pliage de constantes si L et R sont EK_IMM.
  Operateurs Algol 58 couverts :
    + - * / div mod ^ **  (arithmetiques)
    = # != < <= > >=      (relationnels)
    and or                (logiques avec court-circuit)
    imp eqv               (logiques derives)                     }
Procedure EmitBinOp(Const Op : TString;
                    Var L : TExprVal; Var R : TExprVal);
Var
  RS          : TString;
  LblE        : TString;
  Acc         : LongInt;
  Exp         : LongInt;
  SavedRInBX  : Boolean;
Begin
  { ---- Pliage de constantes -------------------------------- }
  If (L.Kind = EK_IMM) And (R.Kind = EK_IMM) Then
  Begin
    If      Op = '+'   Then L.ImmVal := L.ImmVal + R.ImmVal
    Else If Op = '-'   Then L.ImmVal := L.ImmVal - R.ImmVal
    Else If Op = '*'   Then L.ImmVal := L.ImmVal * R.ImmVal
    Else If (Op = '/') Or (Op = 'div') Then
    Begin
      If R.ImmVal = 0 Then Begin CompileError('division par zero'); End
      Else L.ImmVal := L.ImmVal Div R.ImmVal;
    End
    Else If Op = 'mod' Then
    Begin
      If R.ImmVal = 0 Then Begin CompileError('modulo par zero'); End
      Else L.ImmVal := L.ImmVal Mod R.ImmVal;
    End
    Else If (Op = '^') Or (Op = '**') Then
    Begin
      Acc := 1; Exp := R.ImmVal;
      If Exp < 0 Then L.ImmVal := 0
      Else Begin
        While Exp > 0 Do Begin Acc := Acc * L.ImmVal; Dec(Exp); End;
        L.ImmVal := Acc;
      End;
    End
    Else If Op = '='   Then Begin If L.ImmVal =  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If (Op = '#') Or (Op = '!=') Then
      Begin If L.ImmVal <> R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '<'   Then Begin If L.ImmVal <  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '<='  Then Begin If L.ImmVal <= R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '>'   Then Begin If L.ImmVal >  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '>='  Then Begin If L.ImmVal >= R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = 'and' Then
      Begin If (L.ImmVal<>0) And (R.ImmVal<>0) Then L.ImmVal:=1 Else L.ImmVal:=0; End
    Else If Op = 'or'  Then
      Begin If (L.ImmVal<>0) Or  (R.ImmVal<>0) Then L.ImmVal:=1 Else L.ImmVal:=0; End
    Else If Op = 'imp' Then
      Begin If (L.ImmVal<>0) And (R.ImmVal=0) Then L.ImmVal:=0 Else L.ImmVal:=1; End
    Else If Op = 'eqv' Then
      Begin If ((L.ImmVal<>0) = (R.ImmVal<>0)) Then L.ImmVal:=1 Else L.ImmVal:=0; End;
    L.TypeIdx := TY_IDX_INTEGER;
    Exit;
  End;

  { ---- Court-circuit and ----------------------------------- }
  If Op = 'and' Then
  Begin
    LblE := NewLabel;
    ExprFlushToAX(L);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('JZ', LblE);
    ExprFlushToAX(R);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('MOV', 'AX, 0');
    EmitInstr('JZ', LblE);
    EmitInstr('MOV', 'AX, 1');
    EmitLabel(LblE);
    L.Kind := EK_AX; L.TypeIdx := TY_IDX_BOOLEAN;
    Exit;
  End;

  { ---- Court-circuit or ------------------------------------ }
  If Op = 'or' Then
  Begin
    LblE := NewLabel;
    ExprFlushToAX(L);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('MOV', 'AX, 1');
    EmitInstr('JNZ', LblE);
    ExprFlushToAX(R);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('MOV', 'AX, 0');
    EmitInstr('JZ', LblE);
    EmitInstr('MOV', 'AX, 1');
    EmitLabel(LblE);
    L.Kind := EK_AX; L.TypeIdx := TY_IDX_BOOLEAN;
    Exit;
  End;

  { ---- imp : NOT a OR b ------------------------------------ }
  If Op = 'imp' Then
  Begin
    LblE := NewLabel;
    ExprFlushToAX(L);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('MOV', 'AX, 1');
    EmitInstr('JZ', LblE);       { L=0 -> imp est vrai }
    ExprFlushToAX(R);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('MOV', 'AX, 0');
    EmitInstr('JZ', LblE);       { L<>0 et R=0 -> imp est faux }
    EmitInstr('MOV', 'AX, 1');
    EmitLabel(LblE);
    L.Kind := EK_AX; L.TypeIdx := TY_IDX_BOOLEAN;
    Exit;
  End;

  { ---- eqv : (a AND b) OR (NOT a AND NOT b) ---------------- }
  If Op = 'eqv' Then
  Begin
    ExprFlushToAX(L);
    EmitInstr('PUSH', 'AX');
    ExprFlushToAX(R);
    EmitInstr('MOV', 'BX, AX');
    EmitInstr('POP', 'AX');
    { AX=L, BX=R : on veut (AX<>0)=(BX<>0) }
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('MOV', 'AX, 0');
    EmitInstr('SETNE', 'AL');     { AL = (L<>0) }
    EmitInstr('TEST', 'BX, BX');
    EmitInstr('MOV', 'BX, 0');
    EmitInstr('SETNE', 'BL');     { BL = (R<>0) }
    EmitInstr('CMP', 'AX, BX');
    EmitInstr('MOV', 'AX, 0');
    EmitInstr('SETE', 'AL');      { AX = (L<>0)=(R<>0) }
    L.Kind := EK_AX; L.TypeIdx := TY_IDX_BOOLEAN;
    Exit;
  End;

  { ---- Cas general : emission 8086 ------------------------- }
  { Si R est dans AX et L va modifier AX, sauver R dans BX }
  SavedRInBX := False;
  If (R.Kind = EK_AX) And (L.Kind <> EK_AX) Then
  Begin
    EmitInstr('MOV', 'BX, AX');
    SavedRInBX := True;
  End;
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
    Else If (Op = '/') Or (Op = 'div') Then
    Begin
      EmitInstr('MOV', 'BX, ' + RS);
      EmitInstr('CWD', '');
      EmitInstr('IDIV', 'BX');
    End
    Else If Op = 'mod' Then
    Begin
      EmitInstr('MOV', 'BX, ' + RS);
      EmitInstr('CWD', '');
      EmitInstr('IDIV', 'BX');
      EmitInstr('MOV', 'AX, DX');
    End
    Else If (Op = '^') Or (Op = '**') Then
    Begin
      EmitInstr('MOV', 'BX, ' + RS);
      EmitInstr('CALL', A58_RT_PFX + 'POW');
    End
    Else If Op = '='   Then Begin EmitInstr('CMP','AX, '+RS); EmitInstr('MOV','AX, 0'); EmitInstr('SETE','AL'); End
    Else If (Op = '#') Or (Op = '!=') Then
      Begin EmitInstr('CMP','AX, '+RS); EmitInstr('MOV','AX, 0'); EmitInstr('SETNE','AL'); End
    Else If Op = '<'   Then Begin EmitInstr('CMP','AX, '+RS); EmitInstr('MOV','AX, 0'); EmitInstr('SETL','AL'); End
    Else If Op = '<='  Then Begin EmitInstr('CMP','AX, '+RS); EmitInstr('MOV','AX, 0'); EmitInstr('SETLE','AL'); End
    Else If Op = '>'   Then Begin EmitInstr('CMP','AX, '+RS); EmitInstr('MOV','AX, 0'); EmitInstr('SETG','AL'); End
    Else If Op = '>='  Then Begin EmitInstr('CMP','AX, '+RS); EmitInstr('MOV','AX, 0'); EmitInstr('SETGE','AL'); End;
  End
  Else
  Begin
    { R non immediat : preparer AX = L et BX = R }
    If SavedRInBX Then
    Begin
      { BX contient deja R (sauve avant ExprFlushToAX(L)) }
    End
    Else If (R.Kind = EK_AX) And (L.Kind <> EK_AX) Then
    Begin
      { R est dans AX mais L a modifie AX : sauver R dans BX }
      EmitInstr('MOV', 'BX, AX');
      ExprFlushToAX(L);
    End
    Else
    Begin
      { Cas normal : sauvegarder L dans la pile, charger R dans BX }
      EmitInstr('PUSH', 'AX');
      ExprFlushToAX(R);
      EmitInstr('MOV', 'BX, AX');
      EmitInstr('POP', 'AX');
    End;
    If      Op = '+'   Then EmitInstr('ADD', 'AX, BX')
    Else If Op = '-'   Then EmitInstr('SUB', 'AX, BX')
    Else If Op = '*'   Then EmitInstr('IMUL', 'BX')
    Else If (Op = '/') Or (Op = 'div') Then
      Begin EmitInstr('CWD',''); EmitInstr('IDIV','BX'); End
    Else If Op = 'mod' Then
      Begin EmitInstr('CWD',''); EmitInstr('IDIV','BX'); EmitInstr('MOV','AX, DX'); End
    Else If (Op = '^') Or (Op = '**') Then
      EmitInstr('CALL', A58_RT_PFX + 'POW')
    Else
    Begin
      { Relationnels : CMP AX, BX + SETcc }
      EmitInstr('CMP', 'AX, BX');
      EmitInstr('MOV', 'AX, 0');
      If      Op = '='                Then EmitInstr('SETE', 'AL')
      Else If (Op = '#') Or (Op = '!=') Then EmitInstr('SETNE', 'AL')
      Else If Op = '<'                Then EmitInstr('SETL', 'AL')
      Else If Op = '<='               Then EmitInstr('SETLE', 'AL')
      Else If Op = '>'                Then EmitInstr('SETG', 'AL')
      Else If Op = '>='               Then EmitInstr('SETGE', 'AL');
    End;
  End;
  L.Kind := EK_AX;
End;

{ ---- ParsePrimary : atome du parseur Pratt ------------------- }
{ Gere : literaux entiers/reels, true/false, chaines, ( expr ).  }
{ Identificateurs : lookup dans la table des symboles (TODO 05). }
Procedure ParsePrimary(Var Res : TExprVal);
Var
  VarName : TString;
  VarIdx  : Integer;
Begin
  ExprMakeNone(Res);
  Case CurToken.Kind Of
    TK_INTEGER, TK_REAL, TK_STRING :
    Begin
      LitEval(CurToken, Res);
      ParserAdvance;
    End;
    TK_KEYWORD :
    Begin
      If (CurToken.Val = 'true') Or (CurToken.Val = 'false') Then
      Begin
        LitEval(CurToken, Res);
        ParserAdvance;
      End
      Else
      Begin
        CompileError('expression primaire inattendue: ' + CurToken.Val);
        ParserAdvance;
      End;
    End;
    TK_PUNCT :
    Begin
      If CurToken.Val = '(' Then
      Begin
        ParserAdvance;  { consommer ( }
        ParseExprPrec(1, Res);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance  { consommer ) }
        Else
          CompileError(') attendue');
      End
      Else
      Begin
        CompileError('expression primaire inattendue: ' + CurToken.Val);
        ParserAdvance;
      End;
    End;
    TK_IDENT :
    Begin
      { TODO 05 : lookup dans la table des symboles }
      VarName := CurToken.Val;
      VarIdx  := SymFind(VarName);
      If VarIdx < 0 Then
      Begin
        WarnMsg('identificateur non declare: ' + VarName);
        ExprMakeImm(0, TY_IDX_INTEGER, Res);
      End
      Else
      Begin
        Case SymTab[VarIdx].Kind Of
          SK_VAR :
          Begin
            If (SymTab[VarIdx].ScopeLevel = 0) Or
               SymTab[VarIdx].IsOwn Then
            Begin
              { Globale ou own : acces via label DATA }
              Res.Kind    := EK_MEM;
              Res.ImmVal  := 0;
              Res.TypeIdx := SymTab[VarIdx].TypeIdx;
              Res.Offset  := VarIdx;
              Res.SymIdx  := VarIdx;
              EmitInstr('MOV', 'AX, [' + SymTab[VarIdx].MangledName + ']');
              Res.Kind := EK_AX;
            End
            Else
            Begin
              { Locale : acces [BP-offset] }
              Res.Kind    := EK_MEM;
              Res.ImmVal  := 0;
              Res.TypeIdx := SymTab[VarIdx].TypeIdx;
              Res.Offset  := SymTab[VarIdx].Offset;
              Res.SymIdx  := VarIdx;
              EmitInstr('MOV', 'AX, [BP-' +
                        IntToStr_(SymTab[VarIdx].Offset) + ']');
              Res.Kind := EK_AX;
            End;
          End;
          SK_PARAM_VALUE :
          Begin
            Res.Kind    := EK_MEM;
            Res.ImmVal  := 0;
            Res.TypeIdx := SymTab[VarIdx].TypeIdx;
            Res.Offset  := SymTab[VarIdx].Offset;
            Res.SymIdx  := VarIdx;
            EmitInstr('MOV', 'AX, [BP+' +
                      IntToStr_(SymTab[VarIdx].Offset) + ']');
            Res.Kind := EK_AX;
          End;
          SK_LABEL :
          Begin
            Res.Kind    := EK_IMM;
            Res.ImmVal  := 0;
            Res.TypeIdx := TY_IDX_LABEL;
            Res.Offset  := 0;
            Res.SymIdx  := VarIdx;
          End;
        Else
          { Autres categories : stub pour l instant }
          ExprMakeImm(0, TY_IDX_INTEGER, Res);
        End;
      End;
      ParserAdvance;
    End;
  Else
    CompileError('expression attendue, token inattendu');
  End;
End;

{ ---- ParseUnary : gestion des operateurs unaires ------------- }
{ Unaires : not (negation logique), + (identite), - (negation). }
Procedure ParseUnary(Var Res : TExprVal);
Begin
  { not expr }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'not') Then
  Begin
    ParserAdvance;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
    Begin
      If Res.ImmVal <> 0 Then Res.ImmVal := 0 Else Res.ImmVal := 1;
    End
    Else
    Begin
      ExprFlushToAX(Res);
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('MOV', 'AX, 0');
      EmitInstr('SETE', 'AL');
      Res.Kind := EK_AX;
    End;
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  { + expr (identite) }
  Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '+') Then
  Begin
    ParserAdvance;
    ParseUnary(Res);
  End
  { - expr (negation) }
  Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '-') Then
  Begin
    ParserAdvance;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
      Res.ImmVal := -Res.ImmVal
    Else
    Begin
      ExprFlushToAX(Res);
      EmitInstr('NEG', 'AX');
      Res.Kind := EK_AX;
    End;
  End
  { Pas d unaire : primaire }
  Else
    ParsePrimary(Res);
End;

{ ---- ParseExprPrec : boucle de montee de precedence (Pratt) -- }
{ Operateurs binaires detectes comme TK_OP ou TK_KEYWORD        }
{ (and, or, not, imp, eqv, div, mod).                           }
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op       : TString;
  Prec     : Integer;
  NextPrec : Integer;
  Right    : TExprVal;
Begin
  ParseUnary(Res);

  Repeat
    Op   := '';
    Prec := 0;

    { Detecter operateur binaire (TK_OP) }
    If CurToken.Kind = TK_OP Then
    Begin
      Op   := CurToken.Val;
      Prec := BinOpPrec(Op);
    End
    { Mots-cles operateurs : and, or, imp, eqv, div, mod }
    Else If CurToken.Kind = TK_KEYWORD Then
    Begin
      If (CurToken.Val = 'and') Or (CurToken.Val = 'or')
      Or (CurToken.Val = 'imp') Or (CurToken.Val = 'eqv')
      Or (CurToken.Val = 'div') Or (CurToken.Val = 'mod') Then
      Begin
        Op   := CurToken.Val;
        Prec := BinOpPrec(Op);
      End;
    End;

    { Pas d operateur binaire ou precedence trop basse }
    If (Op = '') Or (Prec < MinPrec) Then Break;

    ParserAdvance;  { consommer l operateur }

    { Niveau suivant : droit-assoc -> meme prec, sinon prec+1 }
    If BinOpIsRight(Op) Then NextPrec := Prec
    Else NextPrec := Prec + 1;

    { Sauvegarder le registre AX si le cote gauche y est deja }
    { pour eviter que le parsing du cote droit ne l ecrase.    }
    If Res.Kind = EK_AX Then
    Begin
      EmitInstr('PUSH', 'AX');
      Res.Kind := EK_STACK;
    End;

    ParseExprPrec(NextPrec, Right);
    EmitBinOp(Op, Res, Right);
  Until False;
End;

{ ============================================================
  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
  ============================================================ }

{ ---- SymNameClean : assainir un identificateur pour ASM ------ }
{ Remplace les caracteres non alphanumeriques par '_'.           }
Function SymNameClean(Const Name : TString) : TString;
Var
  S : TString;
  I : Integer;
Begin
  S := Name;
  For I := 1 To Length(S) Do
    If Not ((S[I] >= 'A') And (S[I] <= 'Z'))
    And Not ((S[I] >= 'a') And (S[I] <= 'z'))
    And Not ((S[I] >= '0') And (S[I] <= '9'))
    And (S[I] <> '_') Then
      S[I] := '_';
  SymNameClean := S;
End;

{ ---- SymMangle : construire le label ASM d un symbole -------- }
{ Prefixe selon la categorie du symbole Algol 58.                }
Function SymMangle(Const Name : TString; Kind : TSymKind) : TString;
Var
  Clean : TString;
Begin
  Clean := SymNameClean(Name);
  Case Kind Of
    SK_VAR         : SymMangle := A58_VAR_PFX  + Clean;
    SK_ARRAY       : SymMangle := A58_ARR_PFX  + Clean;
    SK_PROC        : SymMangle := A58_PROC_PFX + Clean;
    SK_LABEL       : SymMangle := A58_LBL_PFX  + Clean;
    SK_SWITCH      : SymMangle := A58_SW_PFX   + Clean;
    SK_PARAM_VALUE : SymMangle := '';  { acces [BP+n], pas de label }
    SK_PARAM_NAME  : SymMangle := '';  { acces [BP+n], pas de label }
  Else
    SymMangle := A58_VAR_PFX + Clean;
  End;
End;

{ ---- SymFind : rechercher un symbole par nom ------------------ }
{ Parcourt la table en ordre inverse (derniere declaration vue    }
{ en premier -> shadowing correct dans les portees imbriquees).   }
{ Retourne l index (0-base) ou -1 si non trouve.                 }
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

{ ---- SymFindInScope : recherche dans une portee specifique ---- }
{ Retourne l index du symbole Name dans la portee Level,          }
{ ou -1 si non trouve.                                            }
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
Function SymAdd(Const Name : TString; Kind : TSymKind;
                TypeIdx, Offset : Integer) : Integer;
Var
  Idx : Integer;
  MN  : TString;
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
  SymTab[Idx].Kind        := Kind;
  SymTab[Idx].TypeIdx     := TypeIdx;
  SymTab[Idx].ScopeLevel  := CurScope;
  SymTab[Idx].Offset      := Offset;
  SymTab[Idx].IsOwn       := False;
  SymTab[Idx].DeclLine    := CurToken.Line;
  MN := SymMangle(Name, Kind);
  SymTab[Idx].MangledName := MN;
  If Opts.DebugMode Then
    WriteLn('  SYM_ADD[', Idx, ']: ', Name,
            ' kind=', Ord(Kind),
            ' scope=', CurScope,
            ' -> ', MN);
  SymAdd := Idx;
  Inc(SymCount);
  Inc(TotalSyms);
End;

{ ---- SymEnterScope : entrer dans une nouvelle portee ---------- }
{ Sauvegarde SymCount pour restaurer a SymLeaveScope.            }
Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
  Begin
    CompileError('portees trop imbriquees (max=' +
                 IntToStr_(MAX_SCOPE) + ')');
    Exit;
  End;
  ScopeStack[ScopeTop] := SymCount;
  Inc(ScopeTop);
  Inc(CurScope);
  If Opts.DebugMode Then
    WriteLn('  SCOPE_ENTER: level=', CurScope);
End;

{ ---- SymLeaveScope : quitter la portee courante --------------- }
{ Les symboles locaux de cette portee sont retires de la table.  }
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
    WriteLn('  SCOPE_LEAVE: level=', CurScope);
End;

{ ---- SymInit : initialisation de la table des symboles -------- }
Procedure SymInit;
Begin
  SymCount := 0;
  ScopeTop := 0;
  CurScope := 0;
  TotalSyms := 0;
End;

{ ============================================================
  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
  ============================================================ }

{ ---- TypeAdd : ajouter un type dans TypeTab ------------------- }
{ Retourne l index du nouveau type (0-base) ou -1 si plein.      }
Function TypeAdd(Kind : TTypeKind; Const AName : TString;
                 Size : Integer) : Integer;
Begin
  If TypeCount >= MAX_TYPE Then
  Begin
    CompileError('table des types pleine (max=' +
                 IntToStr_(MAX_TYPE) + ')');
    TypeAdd := -1;
    Exit;
  End;
  TypeTab[TypeCount].Kind := Kind;
  TypeTab[TypeCount].Name := AName;
  TypeTab[TypeCount].Size := Size;
  If Opts.DebugMode Then
    WriteLn('  TYPE_ADD[', TypeCount, ']: ', AName,
            ' kind=', Ord(Kind), ' size=', Size);
  TypeAdd := TypeCount;
  Inc(TypeCount);
End;

{ ---- TypeSizeof : taille en octets d un type par son index ---- }
{ Retourne 2 (mot 16 bits) par defaut si l index est invalide.    }
Function TypeSizeof(TIdx : Integer) : Integer;
Begin
  If (TIdx >= 0) And (TIdx < TypeCount) Then
    TypeSizeof := TypeTab[TIdx].Size
  Else
    TypeSizeof := 2;
End;

{ ---- TypeKindOf : retourner le TTypeKind d un indice ---------- }
{ Si l indice est invalide, retourne TYK_INTEGER par defaut.      }
Function TypeKindOf(TIdx : Integer) : TTypeKind;
Begin
  If (TIdx >= 0) And (TIdx < TypeCount) Then
    TypeKindOf := TypeTab[TIdx].Kind
  Else
    TypeKindOf := TYK_INTEGER;
End;

{ ---- TypeIsNumeric : le type est-il numerique ? --------------- }
{ integer, real et boolean sont considerees comme numeriques.      }
Function TypeIsNumeric(TIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TIdx);
  TypeIsNumeric := (K = TYK_INTEGER) Or (K = TYK_REAL)
                Or (K = TYK_BOOLEAN);
End;

{ ---- TypeCheckAssign : compatibilite d affectation ------------ }
{ Retourne True si SrcIdx est assignable a DstIdx.                }
{ Regles Algol 58 :                                               }
{   - meme type -> OK                                             }
{   - integer <-> real -> OK (conversion implicite trunc/extend)  }
{   - boolean -> integer -> OK (0/1)                              }
{   - integer -> boolean -> OK (0=false, sinon true)              }
{   - real -> boolean -> OK (trunc puis 0/1)                      }
{   - string -> string -> OK                                      }
{   - label -> label -> OK                                        }
{   - procedure -> procedure -> OK                                }
{   - tout autre -> avertissement mais accepte                    }
Function TypeCheckAssign(DstIdx, SrcIdx : Integer) : Boolean;
Var
  DK, SK : TTypeKind;
Begin
  TypeCheckAssign := True;
  { Types identiques : toujours OK }
  If DstIdx = SrcIdx Then Exit;
  { Types inconnus : accepter silencieusement }
  If (DstIdx = TY_UNKNOWN) Or (SrcIdx = TY_UNKNOWN) Then Exit;
  DK := TypeKindOf(DstIdx);
  SK := TypeKindOf(SrcIdx);
  { Numeriques entre eux : toujours OK (conversion implicite) }
  If TypeIsNumeric(DstIdx) And TypeIsNumeric(SrcIdx) Then Exit;
  { Meme categorie de type : OK }
  If DK = SK Then Exit;
  { Sinon : avertissement de conversion }
  WarnMsg('conversion implicite de ' + TypeTab[SrcIdx].Name +
          ' vers ' + TypeTab[DstIdx].Name);
End;

{ ---- TypeInit : enregistrer les types primitifs Algol 58 ------ }
{ Place les 7 types de base aux indices reserves TY_IDX_*.        }
Procedure TypeInit;
Var
  I : Integer;
Begin
  TypeCount := 0;
  For I := 0 To MAX_TYPE - 1 Do
  Begin
    TypeTab[I].Name := '';
    TypeTab[I].Kind := TYK_INTEGER;
    TypeTab[I].Size := 0;
  End;
  { TY_IDX_INTEGER = 0 : entier 16 bits signe }
  TypeTab[TY_IDX_INTEGER].Name := 'integer';
  TypeTab[TY_IDX_INTEGER].Kind := TYK_INTEGER;
  TypeTab[TY_IDX_INTEGER].Size := 2;
  { TY_IDX_REAL = 1 : reel (stub entier tronque) }
  TypeTab[TY_IDX_REAL].Name := 'real';
  TypeTab[TY_IDX_REAL].Kind := TYK_REAL;
  TypeTab[TY_IDX_REAL].Size := 2;
  { TY_IDX_BOOLEAN = 2 : 0 ou 1 dans AX }
  TypeTab[TY_IDX_BOOLEAN].Name := 'Boolean';
  TypeTab[TY_IDX_BOOLEAN].Kind := TYK_BOOLEAN;
  TypeTab[TY_IDX_BOOLEAN].Size := 2;
  { TY_IDX_STRING = 3 : pointeur chaine DATA }
  TypeTab[TY_IDX_STRING].Name := 'string';
  TypeTab[TY_IDX_STRING].Kind := TYK_STRING;
  TypeTab[TY_IDX_STRING].Size := 2;
  { TY_IDX_LABEL = 4 : etiquette }
  TypeTab[TY_IDX_LABEL].Name := 'label';
  TypeTab[TY_IDX_LABEL].Kind := TYK_LABEL;
  TypeTab[TY_IDX_LABEL].Size := 2;
  { TY_IDX_SWITCH = 5 : aiguillage }
  TypeTab[TY_IDX_SWITCH].Name := 'switch';
  TypeTab[TY_IDX_SWITCH].Kind := TYK_SWITCH;
  TypeTab[TY_IDX_SWITCH].Size := 2;
  { TY_IDX_PROCEDURE = 6 : procedure }
  TypeTab[TY_IDX_PROCEDURE].Name := 'procedure';
  TypeTab[TY_IDX_PROCEDURE].Kind := TYK_PROCEDURE;
  TypeTab[TY_IDX_PROCEDURE].Size := 2;
  TypeCount := TY_PRIM_COUNT;
  If Opts.DebugMode Then
    WriteLn('  TypeInit : ', TypeCount, ' types primitifs');
End;

{ ============================================================
  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
  ============================================================ }

{ ---- EmitProlog : prologue de procedure ---------------------- }
{ PUSH BP / MOV BP,SP / SUB SP,CurFrameSize*2 (si > 0)         }
Procedure EmitProlog;
Var NS : TString;
Begin
  EmitInstr('PUSH', 'BP');
  EmitInstr('MOV', 'BP, SP');
  If CurFrameSize > 0 Then
  Begin
    Str(CurFrameSize * 2, NS);
    EmitInstr('SUB', 'SP, ' + NS);
  End;
End;

{ ---- EmitEpilog : epilogue de procedure ---------------------- }
{ MOV SP,BP / POP BP / RET                                      }
Procedure EmitEpilog;
Begin
  EmitInstr('MOV', 'SP, BP');
  EmitInstr('POP', 'BP');
  EmitInstr('RET', '');
End;

{ ============================================================
  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
  ============================================================ }

{ ---- DataAddArray : ajouter un bloc de tableau dans DataTab --- }
{ Cree une entree DK_ARRAY_BLK avec AElemCount elements DW.      }
{ Retourne l index dans DataTab ou -1 si plein.                   }
Function DataAddArray(Const ALbl : TString;
                      AElemCount : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    FatalError('Table de donnees statiques pleine (MAX_DATA)');
    DataAddArray := -1;
    Exit;
  End;
  Idx := DataCount;
  DataTab[Idx].LblName   := ALbl;
  DataTab[Idx].Kind      := DK_ARRAY_BLK;
  DataTab[Idx].IntVal    := 0;
  DataTab[Idx].StrVal    := '';
  DataTab[Idx].ElemCount := AElemCount;
  Inc(DataCount);
  DataAddArray := Idx;
End;

{ ---- DataInit : pre-initialiser le segment DATA -------------- }
{ Ajoute les entrees statiques necessaires au runtime minimal :   }
{   _A58_STRBUF : buffer de conversion chaines (64 octets)       }
{   _A58_HEAP   : tas statique (1024 mots DW)                    }
{   _A58_HEAPTOP : pointeur courant du tas                       }
Procedure DataInit;
Begin
  DataCount := 0;
  StrSeq    := 0;
  { Buffer de conversion chaine pour numtostr / print }
  DataAddArray('_A58_STRBUF', 32);
  { Tas statique (heap bump allocator) }
  DataAddArray('_A58_HEAP', 1024);
  { Pointeur sommet du tas }
  DataAddWord('_A58_HEAPTOP', 0);
End;

{ ============================================================
  TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
  ============================================================ }

{ ---- ParseVarDecl : declaration de variable ------------------- }
{ Syntaxe : integer ident [, ident]* ;                            }
{           real ident [, ident]* ;                                }
{           Boolean ident [, ident]* ;                             }
{ Les variables globales (CurScope=0) sont allouees dans DATA.    }
{ Les variables locales sont allouees sur la pile [BP-offset].    }
Procedure ParseVarDecl;
Var
  TyIdx   : Integer;
  VName   : TString;
  Idx     : Integer;
Begin
  { Determiner le type }
  If CurToken.Val = 'integer' Then TyIdx := TY_IDX_INTEGER
  Else If CurToken.Val = 'real' Then TyIdx := TY_IDX_REAL
  Else If CurToken.Val = 'Boolean' Then TyIdx := TY_IDX_BOOLEAN
  Else
  Begin
    CompileError('type attendu (integer, real, Boolean)');
    Exit;
  End;
  ParserAdvance;  { consommer le mot-cle de type }

  { Si le token suivant est 'array' ou 'procedure' on quitte }
  If (CurToken.Kind = TK_KEYWORD) And
     ((CurToken.Val = 'array') Or (CurToken.Val = 'procedure')) Then
    Exit;

  { Boucle : ident [, ident]* }
  Repeat
    If CurToken.Kind <> TK_IDENT Then
    Begin
      CompileError('identificateur attendu dans la declaration de variable');
      Exit;
    End;
    VName := CurToken.Val;
    ParserAdvance;  { consommer l ident }

    If CurFnDepth = 0 Then
    Begin
      { Globale (programme principal) : allouer dans DATA }
      Idx := SymAdd(VName, SK_VAR, TyIdx, 0);
      If Idx >= 0 Then
      Begin
        SymTab[Idx].ScopeLevel := 0;  { forcer niveau global }
        DataAddWord(SymTab[Idx].MangledName, 0);
      End;
    End
    Else
    Begin
      { Locale (dans une procedure) : allouer sur la pile }
      Inc(CurFrameSize);
      Idx := SymAdd(VName, SK_VAR, TyIdx, CurFrameSize * 2);
    End;

    { Virgule -> autre variable du meme type }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance  { consommer , }
    Else
      Break;
  Until False;

  { Consommer le ; separateur s il est present }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

{ ---- ParseOwnDecl : declaration de variable own --------------- }
{ Syntaxe : own integer ident [, ident]* ;                        }
{ Les variables own sont allouees dans DATA (persistantes).       }
Procedure ParseOwnDecl;
Var
  TyIdx   : Integer;
  VName   : TString;
  Idx     : Integer;
Begin
  { Deja positionne sur 'own', consommer }
  ParserAdvance;

  { Type obligatoire }
  If CurToken.Kind <> TK_KEYWORD Then
  Begin
    CompileError('type attendu apres own');
    Exit;
  End;
  If CurToken.Val = 'integer' Then TyIdx := TY_IDX_INTEGER
  Else If CurToken.Val = 'real' Then TyIdx := TY_IDX_REAL
  Else If CurToken.Val = 'Boolean' Then TyIdx := TY_IDX_BOOLEAN
  Else
  Begin
    CompileError('type attendu apres own (integer, real, Boolean)');
    Exit;
  End;
  ParserAdvance;  { consommer le type }

  { Boucle : ident [, ident]* }
  Repeat
    If CurToken.Kind <> TK_IDENT Then
    Begin
      CompileError('identificateur attendu dans own');
      Exit;
    End;
    VName := CurToken.Val;
    ParserAdvance;

    { Own : toujours dans DATA }
    Idx := SymAdd(VName, SK_VAR, TyIdx, 0);
    If Idx >= 0 Then
    Begin
      SymTab[Idx].IsOwn := True;
      { Utiliser le prefixe OWN pour le label }
      SymTab[Idx].MangledName := A58_OWN_PFX + SymNameClean(VName);
      DataAddWord(SymTab[Idx].MangledName, 0);
    End;

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance
    Else
      Break;
  Until False;

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

{ ---- ParseAssign : affectation ident := expr ----------------- }
{ VarIdx est l index du symbole cible dans SymTab.               }
{ Genere le code pour calculer l expression a droite puis la     }
{ stocker dans la destination (globale, locale, own ou param).   }
Procedure ParseAssign(VarIdx : Integer);
Var
  E  : TExprVal;
  NS : TString;
Begin
  { Consommer := }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    ParserAdvance
  Else
  Begin
    CompileError(':= attendu dans l''affectation');
    Exit;
  End;

  { Evaluer l expression a droite }
  ParseExprPrec(1, E);
  ExprFlushToAX(E);

  { Stocker AX dans la destination }
  Case SymTab[VarIdx].Kind Of
    SK_VAR :
    Begin
      If (SymTab[VarIdx].ScopeLevel = 0) Or SymTab[VarIdx].IsOwn Then
      Begin
        { Globale ou own : acces DATA }
        EmitInstr('MOV', '[' + SymTab[VarIdx].MangledName + '], AX');
      End
      Else
      Begin
        { Locale : acces pile [BP-n] }
        Str(SymTab[VarIdx].Offset, NS);
        EmitInstr('MOV', '[BP-' + NS + '], AX');
      End;
    End;
    SK_PARAM_VALUE :
    Begin
      { Parametre par valeur : [BP+offset] }
      Str(SymTab[VarIdx].Offset, NS);
      EmitInstr('MOV', '[BP+' + NS + '], AX');
    End;
  Else
    CompileError('destination d''affectation invalide: ' + SymTab[VarIdx].Name);
  End;
End;

{ ---- ParseStmt : dispatcher d instruction --------------------- }
{ Reconnait les declarations de variables et les affectations.    }
Procedure ParseStmt;
Var
  VarName : TString;
  VarIdx  : Integer;
Begin
  If CurToken.Kind = TK_EOF Then Exit;

  { Declaration de variable: integer/real/Boolean ident }
  If (CurToken.Kind = TK_KEYWORD) And
     ((CurToken.Val = 'integer') Or (CurToken.Val = 'real') Or
      (CurToken.Val = 'Boolean')) Then
  Begin
    ParseVarDecl;
    Exit;
  End;

  { Declaration own: own integer/real/Boolean ident }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'own') Then
  Begin
    ParseOwnDecl;
    Exit;
  End;

  { Commentaire : 'comment' ... ';' }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'comment') Then
  Begin
    While (CurToken.Kind <> TK_PUNCT) Or (CurToken.Val <> ';') Do
    Begin
      If CurToken.Kind = TK_EOF Then Exit;
      ParserAdvance;
    End;
    ParserAdvance;  { consommer ; }
    Exit;
  End;

  { Affectation ou expression : ident := expr }
  If CurToken.Kind = TK_IDENT Then
  Begin
    VarName := CurToken.Val;
    VarIdx  := SymFind(VarName);
    ParserAdvance;  { consommer l ident }

    { Affectation }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    Begin
      If VarIdx < 0 Then
      Begin
        { Variable implicite : declarer comme integer globale }
        VarIdx := SymAdd(VarName, SK_VAR, TY_IDX_INTEGER, 0);
        If VarIdx >= 0 Then
          DataAddWord(SymTab[VarIdx].MangledName, 0);
        WarnMsg('variable implicite: ' + VarName);
      End;
      ParseAssign(VarIdx);
    End;
    { Consommer ; s il suit }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
    Exit;
  End;

  { Mots-cles non reconnus : sauter }
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    { begin...end : bloc imbrique }
    If CurToken.Val = 'begin' Then
    Begin
      ParseBlock;
      Exit;
    End;

    { Autres mots-cles non encore implementes : on skip }
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
    Exit;
  End;

  { Autre : avancer }
  ParserAdvance;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

{ ============================================================
  STUBS POUR LES TODOS SUIVANTS
  ============================================================ }

Procedure ParseBlock;
Var
  SavedFrame : Integer;
Begin
  If CurToken.Kind = TK_EOF Then Exit;

  { Bloc begin...end }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'begin') Then
  Begin
    ParserAdvance;  { consommer begin }
    SymEnterScope;
    SavedFrame := CurFrameSize;

    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'end')) Do
    Begin
      ParseStmt;
    End;

    { Restaurer la taille du frame si des locales ont ete ajoutees }
    CurFrameSize := SavedFrame;
    SymLeaveScope;

    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'end') Then
      ParserAdvance  { consommer end }
    Else
      CompileError('end attendu');
  End
  Else
  Begin
    { Pas un bloc begin...end : traiter comme instruction simple }
    ParseStmt;
  End;
End;

Procedure EmitOpen;
Begin
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  If IOResult <> 0 Then
    FatalError('impossible de creer le fichier de sortie: ' + Opts.OutFile);
  OutFOpen := True;
End;

Procedure EmitClose;
Begin
  If OutFOpen Then
  Begin
    EmitComment('--- sortie DOS ---');
    EmitInstr('MOV', 'AX, 4C00h');
    EmitInstr('INT', '21h');
    WriteLn(OutF, '_A58P_Main ENDP');
    WriteLn(OutF);
    WriteLn(OutF, '_TEXT   ENDS');
    WriteLn(OutF);
    WriteLn(OutF, '        END     _A58P_Main');
    Close(OutF);
    OutFOpen := False;
  End;
End;

Procedure EmitHeader;
Begin
  WriteLn(OutF, '; =========================================================');
  WriteLn(OutF, '; Genere par AL58C86 v', AL58_VERSION);
  WriteLn(OutF, '; Source : ', Opts.SrcFile);
  WriteLn(OutF, '; =========================================================');
  WriteLn(OutF);
  WriteLn(OutF, '        .8086');
  WriteLn(OutF, '        .MODEL SMALL');
  WriteLn(OutF, '        .STACK ', STACK_SIZE);
  WriteLn(OutF);
  WriteLn(OutF, '_TEXT   SEGMENT WORD PUBLIC ''CODE''');
  WriteLn(OutF, '        ASSUME CS:_TEXT, DS:_DATA, SS:STACK');
  WriteLn(OutF);
  WriteLn(OutF, '_A58P_Main PROC');
  WriteLn(OutF, '        MOV     AX, _DATA');
  WriteLn(OutF, '        MOV     DS, AX');
  WriteLn(OutF);
End;

Procedure EmitDataSeg;
Var
  I  : Integer;
  J  : Integer;
  B  : Byte;
  NS : String[8];
Begin
  If Not OutFOpen Then Exit;
  WriteLn(OutF);
  WriteLn(OutF, '_DATA   SEGMENT WORD PUBLIC ''DATA''');
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_WORD :
      Begin
        Str(DataTab[I].IntVal, NS);
        WriteLn(OutF, DataTab[I].LblName, '        DW      ', NS);
      End;
      DK_BYTE :
      Begin
        Str(DataTab[I].IntVal And $FF, NS);
        WriteLn(OutF, DataTab[I].LblName, '        DB      ', NS);
      End;
      DK_STR :
      Begin
        Write(OutF, DataTab[I].LblName, '        DB      ');
        For J := 1 To Length(DataTab[I].StrVal) Do
        Begin
          B := Ord(DataTab[I].StrVal[J]);
          Str(B, NS);
          If J > 1 Then Write(OutF, ',');
          Write(OutF, NS);
        End;
        WriteLn(OutF, ',0');  { terminateur ASCIIZ }
      End;
      DK_ARRAY_BLK :
      Begin
        Str(DataTab[I].ElemCount, NS);
        WriteLn(OutF, DataTab[I].LblName, '        DW      ', NS, ' DUP(0)');
      End;
      DK_SWITCH_TAB :
      Begin
        { StrVal contient les labels separes par ',' -> DW OFFSET l1, OFFSET l2 }
        Write(OutF, DataTab[I].LblName, '        DW      ');
        If DataTab[I].StrVal <> '' Then
          WriteLn(OutF, DataTab[I].StrVal)
        Else
          WriteLn(OutF, '0');
      End;
    End;
  End;
  WriteLn(OutF, '_DATA   ENDS');
  WriteLn(OutF);
End;

Procedure EmitRuntime;
Begin
  { Stub : sera implemente dans TODO 24 }
End;

{ ============================================================
  RUN - Pipeline principal de compilation
  ============================================================ }

Procedure Run;
Begin
  GlobalInit;
  If Opts.Verbose Then ShowBanner;

  TypeInit;
  SymInit;
  DataInit;
  EmitOpen;
  EmitHeader;
  LexInit;

  ParserAdvance;

  While CurToken.Kind <> TK_EOF Do
  Begin
    ParseBlock;
    If CurToken.Kind <> TK_EOF Then
      ParserAdvance;
  End;

  LexClose;
  EmitRuntime;
  EmitDataSeg;
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
