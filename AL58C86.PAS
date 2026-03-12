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

  TODO 03 - LITTERAUX ET CONSTANTES
            Entiers decimaux : 0..65535 (unsigned) ou -32768..32767 (signe)
            Entiers signes : signe unaire + ou - devant un entier
            Reels : reconnus par le lexeur, traites comme entiers (trunc)
              Notation avec point : 3.14 -> 3 (trunc, avec avertissement)
              Notation exposant subscript 10 : 1.5 @ 3 -> 1500 (trunc)
            Booleens : true -> AX=1, false -> AX=0
            Chaines de caracteres (extensions) :
              Chaines entre guillemets "abc" -> DB dans DATA avec label
              Utilisees principalement pour les sorties (write)

  TODO 04 - OPERATEURS ET PRECEDENCE
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

  TODO 05 - TABLE DES SYMBOLES
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

  TODO 06 - SYSTEME DE TYPES
            TTypeKind : TYK_INTEGER (16 bits signe), TYK_REAL (stub entier trunc),
              TYK_BOOLEAN (0 ou 1 dans AX), TYK_STRING (ptr chaine DATA),
              TYK_ARRAY (tableau), TYK_LABEL (etiquette), TYK_SWITCH (aiguillage),
              TYK_PROCEDURE (procedure)
            TypeTab, TypeInit : enregistrer les types primitifs
            TypeSizeof : integer=2, real=2 (tronque), Boolean=2, ptr=2
            Conversion implicite : integer <-> real (trunc/round selon contexte)
            Verification de type dans les affectations et les parametres
            Type des parametres par nom : evaluation retardee (thunk)

  TODO 07 - EMETTEUR DE CODE ASM
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

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_ARRAY),
              IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddArray : variantes d ajout
            Variables globales (niveau programme) : entrees DK_WORD dans DATA
            Variables own : entrees DK_WORD dans DATA (persistantes)
            Chaines litterales : DB 'abc',0 dans DATA avec label _A58K_N
            Tableaux globaux : blocs DW dans DATA avec label _A58ARR_nom
            Tables de switch : DW label1, label2, ... dans DATA

  TODO 09 - VARIABLES ET AFFECTATIONS
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
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY_BLK);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;  { DK_ARRAY_BLK : nb elements }
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
  STUBS POUR LES TODOS SUIVANTS
  ============================================================ }

Procedure ParseBlock;
Begin
  { Stub : ne fait rien pour le moment }
End;

Procedure TypeInit;
Begin
  { Stub : sera implemente dans TODO 06 }
  TypeCount := 0;
End;

Procedure SymInit;
Begin
  { Stub : sera implemente dans TODO 05 }
  SymCount := 0;
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
End;

Procedure EmitDataSeg;
Begin
  { Stub : sera implemente dans TODO 08 }
  WriteLn(OutF);
  WriteLn(OutF, '_DATA   SEGMENT WORD PUBLIC ''DATA''');
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
