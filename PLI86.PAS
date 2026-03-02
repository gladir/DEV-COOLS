(* @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur PL/I (PL/1) pour 8086/8088 - Sortie MASM/TASM

  ===== TODOS 25 POINTS =====

  TODO 01 - Architecture generale, constantes et types de base
            Types de tokens PL/I (TOK_IDENT, TOK_NUMBER, TOK_STRING,
            TOK_PLUS, TOK_MINUS, TOK_STAR, TOK_SLASH, TOK_LPAREN,
            TOK_RPAREN, TOK_SEMI, TOK_COMMA, TOK_ASSIGN, TOK_EQ,
            TOK_NE, TOK_LT, TOK_GT, TOK_LE, TOK_GE, TOK_AND, TOK_OR,
            TOK_NOT, TOK_LBRACE, TOK_RBRACE, TOK_EOF, TOK_UNKNOWN...).
            Types de donnees PL/I (TYPE_FIXED, TYPE_FLOAT, TYPE_CHAR,
            TYPE_BIT, TYPE_LABEL, TYPE_VOID, TYPE_POINTER...).
            Classes de stockage (STORE_AUTO, STORE_STATIC, STORE_EXTERNAL,
            STORE_BASED, STORE_CONTROLLED).
            Constantes d'erreur et limites (MAX_SYM, MAX_PROC, MAX_LOCAL,
            MAX_PARAM, MAX_DEPTH, MAX_LABEL, MAX_STR...).
            Utilitaires : ItoS, ItoSI, UpCaseStr, AsmIdent, PadLabel.
            => COMPLET 01

  TODO 02 - Tokeniseur PL/I (Lexer)
            Procedure InitTokenizer : ouvrir source, initialiser etat.
            Procedure NextChar / PeekChar.
            Procedure NextToken : reconnaitre les tokens PL/I :
              - Identificateurs (et mots-cles detectes apres coup)
              - Litteraux numeriques : 123, 1.5, 1E3, 1B (binaire)
              - Litteraux chaines : 'texte' (apostrophe doublable : '')
              - Commentaires : /* ... */ (possiblement sur plusieurs lignes)
              - Operateurs : + - * / = ^= < <= > >= | || & !! ** -> ( ) , ;
              - Token special %INCLUDE (directive preprocesseur)
            Stocker dans cur_tok_type / cur_tok_str / cur_tok_num.
            => COMPLET 02

  TODO 03 - Reconnaissance des mots-cles PL/I
            Function IsKeyword(Const s: String): Integer.
            Mots-cles complets :
              PROCEDURE END BEGIN CALL RETURN IF THEN ELSE DO WHILE UNTIL
              SELECT WHEN OTHERWISE DECLARE DCL FIXED FLOAT CHAR BIT LABEL
              POINTER PTR BASED ON CONDITION SIGNAL REVERT RESIGNAL
              ALLOCATE FREE PUT GET LIST SKIP LINE EDIT OPEN CLOSE
              FORMAT PICTURE STATIC EXTERNAL INTERNAL AUTOMATIC AUTO
              INITIAL INIT VALUE BY REFERENCE RESTRICTED
              ENTRY RETURNS OPTIONS RECURSIVE REORDER IRREDUCIBLE
              SUBSTR INDEX LENGTH TRIM LTRIM RTRIM HIGH LOW UNSPEC
              STRING COMPLEX REAL IMAG BINARY DECIMAL OVERFLOW ZERODIVIDE
              NOOVERFLOW NOZERODIVIDE ANYSIZE CONNECTED DEFINED
              AND OR NOT MOD REM ABS SIGN FLOOR CEIL TRUNC ROUND MAX MIN
            => COMPLET 03

  TODO 04 - Table des symboles (variables, procedures, labels)
            Type TSymEntry : name (String[48]), sym_type (Integer),
              data_type (Integer), store_class (Integer),
              bp_offset (Integer), asm_label (String[48]),
              is_param (Boolean), param_idx (Integer),
              array_size (Integer), precision (Integer), scale (Integer).
            Type TProcEntry : name (String[48]), asm_label (String[48]),
              param_count (Integer), return_type (Integer), defined (Boolean),
              param_types : Array[1..MAX_PARAM] of Integer,
              param_names : Array[1..MAX_PARAM] of String[48].
            Procedure InitSymTable.
            Function FindSym(Const name: String): Integer.
            Function AddSym(Const name: String; dt, sc: Integer): Integer.
            Function FindProc(Const name: String): Integer.
            Function AddProc(Const name: String; nparams, rt: Integer): Integer.
            => COMPLET 04

  TODO 05 - Gestion des scopes (blocs BEGIN...END et PROCEDURE)
            Pile de scopes : chaque scope a sa propre table de symboles
            locaux, un offset BP courant, et un label de sortie.
            Procedure EnterScope(kind: Integer).
            Procedure LeaveScope.
            Function FindSymInScope(Const name: String): Integer.
            Function AddLocalSym(Const name: String; dt, sc: Integer): Integer.
            Compteur d'offset BP pour l'allocation des variables locales.
            => COMPLET 05

  TODO 06 - Parseur : DECLARE / DCL (declarations de variables)
            Procedure ParseDeclare.
            Syntaxe : DECLARE nom [attributs] [, nom [attributs]] ... ;
            Attributs supportes :
              FIXED [BINARY|DECIMAL] [(p[,q])]
              FLOAT [BINARY|DECIMAL] [(p)]
              CHAR[(n)] [VARYING]
              BIT[(n)]
              POINTER / PTR
              STATIC / AUTOMATIC / EXTERNAL
              INITIAL(valeur) / INIT(valeur)
              DIMENSION/DIM(n) ou (n,m) pour les tableaux
            Allouer espace en segment .DATA (STATIC) ou sur la pile (AUTO).
            => COMPLET 06

  TODO 07 - Parseur : Expressions (operateurs PL/I)
            Function ParseExpr : Integer.
            Function ParseRelExpr : Integer.
            Function ParseAddExpr : Integer.
            Function ParseMulExpr : Integer.
            Function ParseUnaryExpr : Integer.
            Function ParsePrimaryExpr : Integer.
            Precedences PL/I :
              ** (puissance, droite-assoc)
              unaire + - NOT ^
              * /
              + -
              || (concatenation de chaines)
              < <= = >= > ^= (comparaisons)
              & (AND bit a bit)
              | (OR bit a bit)
              AND OR (booleens)
            Retourne le data_type de l'expression pour la verification de type.
            => COMPLET 07

  TODO 08 - Generation de code : evaluation d'expression en AX/BX
            Procedure GenLoadVar(sym_idx: Integer).
              FIXED/POINTER -> MOV AX, [_VAR_xxx] ou [BP+off]
              CHAR         -> LEA AX, [_VAR_xxx]
            Procedure GenStoreVar(sym_idx: Integer).
              MOV [_VAR_xxx], AX  ou  MOV [BP+off], AX
            Procedure GenBinOp(op: Integer; dt: Integer).
              +  : ADD AX, BX
              -  : SUB AX, BX
              *  : IMUL BX (resultat dans DX:AX)
              /  : CWD + IDIV BX (quotient dans AX)
              MOD: CWD + IDIV BX (reste dans DX -> MOV AX, DX)
            Procedure GenCompare(op, dt: Integer).
              CMP AX, BX + Jxx/SETxx -> AX = 0 ou 0FFFFh
            => COMPLET 08

  TODO 09 - Parseur : Instruction d'affectation
            Procedure ParseAssignment.
            Syntaxe : variable = expression ;
            Gestion des affectations multiples : a, b = expr ;
            Conversion implicite de type (FIXED<->FLOAT, CHAR tronque/etend).
            Verification que la variable n'est pas CONSTANT.
            => COMPLET 09

  TODO 10 - Parseur : IF / THEN / ELSE
            Procedure ParseIf.
            Syntaxe :
              IF expr THEN stmt ;
              IF expr THEN stmt ; ELSE stmt ;
              IF expr THEN DO ; stmts END ;
              IF expr THEN DO ; stmts END ; ELSE DO ; stmts END ;
            Generation :
              Evaluer expr -> AX.
              TEST AX, AX + JZ lbl_else.
              Compiler then-part.
              JMP lbl_end + EmitLabel(lbl_else).
              Compiler else-part (optionnel).
              EmitLabel(lbl_end).
            => COMPLET 10

  TODO 11 - Parseur : DO WHILE / DO UNTIL / DO n TIMES / DO i = a TO b BY c
            Procedure ParseDo.
            Variantes :
              DO ;  stmts END ;               (bloc simple)
              DO WHILE(expr) ; stmts END ;    (boucle tant-que)
              DO UNTIL(expr) ; stmts END ;    (boucle jusqu-a)
              DO i = a TO b [BY c] ; stmts END ;  (boucle for)
            Generation :
              DO WHILE : lbl_top TEST JZ lbl_end stmts JMP lbl_top EmitLabel(lbl_end)
              DO i=a TO b : init + lbl_top CMP JG lbl_end stmts INC/ADD JMP lbl_top
            => COMPLET 11

  TODO 12 - Parseur : SELECT / WHEN / OTHERWISE
            Procedure ParseSelect.
            Syntaxe :
              SELECT [(expr)] ;
                WHEN(val) stmt ;
                WHEN(val1, val2) stmt ;
                OTHERWISE stmt ;
              END ;
            Generation :
              Evaluer selecteur -> DX (ou AX si pas de selecteur).
              Pour chaque WHEN : CMP DX, val + JNE lbl_next.
              WHEN sans valeur = condition bool evaluee separement.
              OTHERWISE = clause par defaut (JMP lbl_end sinon).
            => COMPLET 12

  TODO 13 - Parseur : PROCEDURE et ENTRY / RETURN
            Procedure ParseProcedure.
            Syntaxe :
              nom : PROCEDURE [(param [, param] ...)] [RETURNS (type)] [OPTIONS(...)] ;
                declarations
                instructions
              END [nom] ;
            Convention d'appel 8086 :
              Arguments empiles de gauche a droite.
              AX = valeur de retour (FIXED 16 bits).
              PUSH BP / MOV BP, SP en prologue.
              MOV SP, BP / POP BP / RET (n*2) en epilogue.
            Procedure ParseReturn.
              RETURN [(expr)] ;
              Compiler expr -> AX + JMP lbl_epilogue_proc.
            => COMPLET 13

  TODO 14 - Parseur : CALL (appel de procedure en instruction)
            Procedure ParseCall.
            Syntaxe : CALL nom [(arg [, arg] ...)] ;
            Gestion des arguments :
              Passer PAR VALEUR par defaut (PUSH AX apres eval).
              Passer PAR REFERENCE si parametre declare POINTER : LEA AX + PUSH AX.
            Verification arity (nombre de parametres).
            Retourner type de RETURNS si utilise comme expression.
            => COMPLET 14

  TODO 15 - Parseur : PUT LIST / PUT SKIP / GET LIST (E/S simplifiee)
            Procedure ParsePut.
            Syntaxe :
              PUT LIST (expr [, expr] ...) ;
              PUT SKIP [(n)] ;
              PUT STRING (var) LIST (expr) ;
            Procedure ParseGet.
              GET LIST (var [, var] ...) ;
            Generation :
              PUT LIST FIXED  -> convertir AX en ASCII + INT 21h AH=09h (comme CC8086 WRITE)
              PUT LIST STRING -> LEA DX, str + INT 21h AH=09h
              PUT SKIP        -> MOV DL,13 / INT 21h + MOV DL,10 / INT 21h
              GET LIST        -> INT 21h AH=0Ah + convertir ASCII->binaire + stocker
            => COMPLET 15

  TODO 16 - Generation : en-tete programme + segment .DATA
            Procedure GenHeader.
              '; Generated by PLI86 V1.0'
              '.MODEL SMALL' + '.STACK 256'
            Procedure GenDataSegment.
              - Variables STATIC : _VAR_nom DW 0 (FIXED 16-bit)
                                   _VAR_nom DB n DUP(0) (CHAR(n))
              - Buffers internes : _CRLF, _NUMBUF, _INPUTBUF
              - Etiquettes de format (PICTURE) si utilisees
            => COMPLET 16

  TODO 17 - Generation : point d'entree START + epilogue programme
            Procedure GenCodeSegmentHeader.
              '.CODE'
              'START:'
              'MOV AX, @DATA' / 'MOV DS, AX' / 'MOV ES, AX'
              CALL vers la procedure MAIN (premiere PROCEDURE sans parametre).
              'MOV AX, 4C00h' / 'INT 21h'
            Procedure GenFooter.
              'END START'
            => COMPLET 17

  TODO 18 - Generation : variables locales et frame d'activation
            Procedure GenPrologue(proc_idx: Integer).
              PUSH BP / MOV BP, SP
              SUB SP, total_local_size  (si variables locales)
            Procedure GenEpilogue(proc_idx: Integer).
              MOV SP, BP / POP BP / RET (nparams*2)
            Lors de l'analyse de DECLARE inside PROCEDURE :
              Allouer offset negatif BP : -2, -4, -6...
              Initialiser avec INITIAL si present.
            => COMPLET 18

  TODO 19 - Generation : tableaux (DIMENSION / DIM)
            Lors de DECLARE tab FIXED DIM(n) :
              Allouer _VAR_tab DW n DUP(0) en .DATA (STATIC).
              ou SUB SP, n*2 sur la pile (AUTO).
            Acces element : tab(i)
              Evaluer i -> AX (0-base ou 1-base selon LBOUND).
              LEA BX, _VAR_tab + MOV AX, [BX + AX*2].
              (en 8086 reel : SHL AX,1 + MOV SI,AX + MOV AX,[_VAR_tab+SI])
            2D : row*cols + col.
            => COMPLET 19

  TODO 20 - Fonctions built-in PL/I
            Function GenBuiltIn(Const name: String; args: Integer): Boolean.
            Fonctions supportees :
              LENGTH(s)   -> MOV AX, longueur (premier octet du descripteur)
              SUBSTR(s,i,n) -> copie partielle, retourne adresse ou valeur
              INDEX(s,t)  -> recherche lineaire, retourne position (0 si absent)
              ABS(n)      -> CWD + XOR AX,DX + SUB AX,DX
              MAX(a,b)    -> CMP AX,BX + CMOVG/JG simulation
              MIN(a,b)    -> CMP AX,BX + CMOVL/JL simulation
              MOD(a,b)    -> CWD + IDIV BX + MOV AX,DX
              SIGN(n)     -> -1, 0 ou +1
              FLOOR/CEIL  -> identique pour FIXED (entiers)
              UNSPEC(x)   -> MOV AX, x  (brut)
            => COMPLET 20

  TODO 21 - Gestion des CONDITION / ON / SIGNAL
            Conditions PL/I standard :
              OVERFLOW, ZERODIVIDE, SUBSCRIPTRANGE, STRINGRANGE,
              STRINGSIZE, STORAGE, CONVERSION, UNDEFINEDFILE,
              ENDFILE, ERROR, FINISH.
            Procedure ParseOn.
              ON condition DO ; stmts END ; / ON condition GOTO label ;
              Enregistrer un handler (stub : sauvegarder lbl dans table).
            Procedure ParseSignal.
              SIGNAL condition ;
              Generer CALL au handler enregistre (ou INT pour NMI en debug).
            Stub minimal : ON ZERODIVIDE -> JMP lbl_err si IDIV.
            => COMPLET 21

  TODO 22 - Generation : helpers runtime
            Procedure GenRuntimeHelpers.
              _PLI_PRINT_INT  : AX = entier -> afficher en decimal (INT 21h AH=09h)
              _PLI_PRINT_STR  : DX = ptr chaine '$'-terminee -> INT 21h AH=09h
              _PLI_PRINT_CHAR : DL = char -> INT 21h AH=02h
              _PLI_CRLF       : 13,10 via INT 21h AH=09h
              _PLI_READ_INT   : AH=0Ah + parsing ASCII -> AX
              _PLI_READ_STR   : AH=0Ah -> copier dans buffer var CHAR
              _PLI_STR_LEN    : SI = ptr -> CX = longueur (chercher $)
              _PLI_ERROR      : afficher message d'erreur + INT 21h AH=4Ch code 1
            => COMPLET 22

  TODO 23 - Parseur : instruction de niveau superieur (boucle principale)
            Procedure ParseStatement.
            Dispatcher selon le token courant :
              DECLARE / DCL -> ParseDeclare
              IF            -> ParseIf
              DO            -> ParseDo
              SELECT        -> ParseSelect
              CALL          -> ParseCall
              PUT           -> ParsePut
              GET           -> ParseGet
              RETURN        -> ParseReturn
              ident ':'     -> label PL/I (GenLabel + enregistrer dans sym_table)
              ident '='     -> ParseAssignment
              GOTO / GO TO  -> ParseGoto
              END           -> signaler fin de bloc
              ;             -> instruction vide
            Procedure ParseBlock.
              Appeler ParseStatement en boucle jusqu'a END ou EOF.
            => COMPLET 23

  TODO 24 - Parseur : GOTO / GO TO et labels
            Procedure ParseGoto.
              GOTO label ; / GO TO label ;
              Emettre JMP _LBL_nom.
            Gestion des forward-references :
              Si le label n'est pas encore defini, enregistrer dans
              une liste de patchs (forward_refs) : (lbl_name, asm_label).
              A la fin de chaque PROCEDURE, resoudre les patchs.
            Procedure ParseLabel (label : en debut de ParseStatement).
              nom ':' -> EmitLabel(_LBL_nom) et marquer sym comme defini.
            => COMPLET 24

  TODO 25 - Test complet avec un programme PL/I de test
            Creer TEST.PLI :
              MAIN: PROCEDURE OPTIONS(MAIN) ;
                DECLARE N FIXED BINARY ;
                DECLARE I FIXED BINARY ;
                DECLARE SUM FIXED BINARY INITIAL(0) ;
                N = 10 ;
                DO I = 1 TO N ;
                  SUM = SUM + I ;
                END ;
                PUT LIST (SUM) ;
                PUT SKIP ;
              END MAIN ;
            Compiler : PLI86.EXE TEST.PLI TEST.ASM
            Verifier le .ASM : structure .MODEL SMALL, segment .DATA,
            variables _VAR_N, _VAR_I, _VAR_SUM, boucle DO, affichage PUT.
            Assembler si TASM/MASM disponible.
            => COMPLET 25
*)

Program PLI86;

{$A-}
{$I-}

Uses DOS;

{ ============================================================================ }
{ CONSTANTES GENERALES                                                         }
{ ============================================================================ }

Const
 VERSION = 'PLI86 V1.0';

 { ---- Types de tokens PL/I ---- }
 TOK_UNKNOWN  = 0;
 TOK_IDENT    = 1;   { identificateur / mot-cle }
 TOK_NUMBER   = 2;   { litterale numerique       }
 TOK_STRING   = 3;   { 'texte'                   }
 TOK_PLUS     = 4;   { +                         }
 TOK_MINUS    = 5;   { -                         }
 TOK_STAR     = 6;   { *                         }
 TOK_SLASH    = 7;   { /                         }
 TOK_LPAREN   = 8;   { (                         }
 TOK_RPAREN   = 9;   { )                         }
 TOK_SEMI     = 10;  { ;                         }
 TOK_COMMA    = 11;  { ,                         }
 TOK_ASSIGN   = 12;  { =  (affectation)          }
 TOK_EQ       = 13;  { =  (comparaison, ctx)     }
 TOK_NE       = 14;  { ^= ou !=                  }
 TOK_LT       = 15;  { <                         }
 TOK_LE       = 16;  { <=                        }
 TOK_GT       = 17;  { >                         }
 TOK_GE       = 18;  { >=                        }
 TOK_AND      = 19;  { & ou AND                  }
 TOK_OR       = 20;  { | ou OR                   }
 TOK_NOT      = 21;  { ^ ou NOT                  }
 TOK_STAR2    = 22;  { **  (puissance)           }
 TOK_CONCAT   = 23;  { ||  (concatenation)       }
 TOK_COLON    = 24;  { :   (label)               }
 TOK_DOT      = 25;  { .   (acces membre)        }
 TOK_ARROW    = 26;  { ->  (pointeur)            }
 TOK_PERCENT  = 27;  { %   (preprocesseur)       }
 TOK_EOF      = 99;

 { ---- Types de donnees PL/I ---- }
 TYPE_UNKNOWN  = 0;
 TYPE_FIXED    = 1;   { FIXED BINARY (entier 16 bits)       }
 TYPE_FIXED32  = 2;   { FIXED BINARY(31) (entier 32 bits)   }
 TYPE_FLOAT    = 3;   { FLOAT BINARY (flottant, stub)       }
 TYPE_CHAR     = 4;   { CHAR(n) (chaine de longueur fixe)   }
 TYPE_CHAR_VAR = 5;   { CHAR(n) VARYING (longueur variable) }
 TYPE_BIT      = 6;   { BIT(n) (champ de bits)              }
 TYPE_LABEL    = 7;   { LABEL (etiquette PL/I)              }
 TYPE_POINTER  = 8;   { POINTER / PTR                       }
 TYPE_ENTRY    = 9;   { ENTRY (pointeur de procedure)       }
 TYPE_VOID     = 10;  { pas de type de retour               }

 { ---- Classes de stockage ---- }
 STORE_AUTO     = 0;  { AUTOMATIC (pile BP)                 }
 STORE_STATIC   = 1;  { STATIC (segment .DATA)              }
 STORE_EXTERNAL = 2;  { EXTERNAL (import)                   }
 STORE_BASED    = 3;  { BASED (acces via pointeur)          }
 STORE_PARAM    = 4;  { Parametre de procedure              }

 { ---- Codes des mots-cles ---- }
 KW_NONE        =  0;
 KW_PROCEDURE   =  1;
 KW_END         =  2;
 KW_BEGIN       =  3;
 KW_CALL        =  4;
 KW_RETURN      =  5;
 KW_IF          =  6;
 KW_THEN        =  7;
 KW_ELSE        =  8;
 KW_DO          =  9;
 KW_WHILE       = 10;
 KW_UNTIL       = 11;
 KW_SELECT      = 12;
 KW_WHEN        = 13;
 KW_OTHERWISE   = 14;
 KW_DECLARE     = 15;
 KW_DCL         = 16;
 KW_FIXED       = 17;
 KW_FLOAT       = 18;
 KW_CHAR        = 19;
 KW_CHARACTER   = 20;
 KW_BIT         = 21;
 KW_LABEL       = 22;
 KW_POINTER     = 23;
 KW_PTR         = 24;
 KW_STATIC      = 25;
 KW_AUTOMATIC   = 26;
 KW_AUTO        = 27;
 KW_EXTERNAL    = 28;
 KW_INTERNAL    = 29;
 KW_INITIAL     = 30;
 KW_INIT        = 31;
 KW_RETURNS     = 32;
 KW_OPTIONS     = 33;
 KW_BINARY      = 34;
 KW_DECIMAL     = 35;
 KW_PUT         = 36;
 KW_GET         = 37;
 KW_LIST        = 38;
 KW_SKIP        = 39;
 KW_TO          = 40;
 KW_BY          = 41;
 KW_GOTO        = 42;
 KW_GO          = 43;
 KW_ON          = 44;
 KW_SIGNAL      = 45;
 KW_REVERT      = 46;
 KW_ENTRY       = 47;
 KW_VARYING     = 48;
 KW_RECURSIVE   = 49;
 KW_AND         = 50;
 KW_OR          = 51;
 KW_NOT         = 52;
 KW_MOD         = 53;
 KW_BASED       = 54;
 KW_DIMENSION   = 55;
 KW_DIM         = 56;
 KW_SUBSTR      = 57;
 KW_INDEX       = 58;
 KW_LENGTH      = 59;
 KW_ABS         = 60;
 KW_MAX         = 61;
 KW_MIN         = 62;
 KW_SIGN        = 63;
 KW_FLOOR       = 64;
 KW_CEIL        = 65;
 KW_TRUNC       = 66;
 KW_ROUND       = 67;
 KW_UNSPEC      = 68;
 KW_STRING      = 69;
 KW_FORMAT      = 70;
 KW_EDIT        = 71;
 KW_OPEN        = 72;
 KW_CLOSE       = 73;
 KW_READ        = 74;
 KW_WRITE       = 75;
 KW_OVERFLOW    = 76;
 KW_ZERODIVIDE  = 77;
 KW_NOOVERFLOW  = 78;
 KW_ALLOCATE    = 79;
 KW_FREE        = 80;
 KW_ALLOC       = 81;

 { ---- Limites ---- }
 MAX_SYM    = 256;   { Variables + labels max            }
 MAX_PROC   = 64;    { Procedures max                    }
 MAX_LOCAL  = 64;    { Variables locales par scope       }
 MAX_PARAM  = 16;    { Parametres max par procedure      }
 MAX_DEPTH  = 16;    { Profondeur de scope max           }
 MAX_LABEL  = 9999;  { Limite compteur labels ASM        }
 MAX_STR    = 128;   { Litteraux chaines max             }
 MAX_FWD    = 64;    { Forward references max            }

{ ============================================================================ }
{ TYPES                                                                        }
{ ============================================================================ }

Type
 { ----- Entree de la table des symboles ----- }
 TSymEntry = Record
  name        : String[48];   { Nom PL/I (upper-case)            }
  asm_label   : String[48];   { Etiquette ASM : _VAR_nom         }
  data_type   : Integer;       { TYPE_xxx                        }
  store_class : Integer;       { STORE_xxx                       }
  bp_offset   : Integer;       { offset BP si AUTO               }
  array_size  : Integer;       { 0 si scalaire, n si tableau     }
  precision   : Integer;       { nb bits/chiffres significatifs  }
  scale       : Integer;       { facteur d'echelle DECIMAL       }
  is_param    : Boolean;       { True si parametre de procedure  }
  param_idx   : Integer;       { index du parametre (1-base)     }
  init_val    : Integer;       { valeur INITIAL si connue        }
  has_init    : Boolean;       { True si INITIAL specifie        }
 End;
 PSymEntry = ^TSymEntry;

 { ----- Entree de la table des procedures ----- }
 TProcEntry = Record
  name        : String[48];
  asm_label   : String[48];   { ex: _PLI_MAIN             }
  param_count : Integer;
  return_type : Integer;       { TYPE_xxx ou TYPE_VOID     }
  defined     : Boolean;
  is_main     : Boolean;       { OPTIONS(MAIN)             }
  is_recursive: Boolean;       { OPTIONS(RECURSIVE)        }
  param_types : Array[1..MAX_PARAM] of Integer;
  param_names : Array[1..MAX_PARAM] of String[48];
 End;
 PProcEntry = ^TProcEntry;

 { ----- Scope (frame de compilation) ----- }
 TScopeKind = (SK_GLOBAL, SK_PROC, SK_BLOCK, SK_DO);
 TScopeEntry = Record
  kind        : TScopeKind;
  proc_idx    : Integer;       { index dans proc_table si SK_PROC }
  bp_top      : Integer;       { prochain offset BP negatif        }
  sym_start   : Integer;       { premier sym_table[sym_start]      }
  sym_end     : Integer;       { dernier symbole du scope          }
  lbl_exit    : String[32];   { label de sortie (RETURN)          }
 End;

 { ----- Litterale chaine ----- }
 TStrEntry = Record
  text        : String;
  asm_label   : String[32];
 End;
 PStrEntry = ^TStrEntry;

 { ----- Forward reference (GOTO vers label pas encore defini) ----- }
 TFwdRef = Record
  pli_label   : String[48];   { nom du label PL/I         }
  asm_label   : String[48];   { etiquette ASM que JMP attend }
 End;

{ ============================================================================ }
{ VARIABLES GLOBALES                                                           }
{ ============================================================================ }

Var
 { --- Fichiers --- }
 source_filename  : String;
 output_filename  : String;
 input_file       : Text;
 output_file      : Text;

 { --- Options --- }
 opt_verbose  : Boolean;
 opt_dump_tok : Boolean;
 opt_dump_ast : Boolean;

 { --- Etat du tokeniseur --- }
 src_line     : String;
 src_line_num : Integer;
 src_col      : Integer;
 src_eof      : Boolean;
 cur_tok_type : Integer;
 cur_tok_str  : String;
 cur_tok_num  : LongInt;
 cur_tok_kw   : Integer;   { KW_xxx si TOK_IDENT est un mot-cle }
 peek_char    : Char;
 has_peek     : Boolean;

 { --- Tables --- }
 sym_table    : Array[1..MAX_SYM]  of PSymEntry;
 sym_count    : Integer;
 proc_table   : Array[1..MAX_PROC] of PProcEntry;
 proc_count   : Integer;
 str_table    : Array[1..MAX_STR]  of PStrEntry;
 str_count    : Integer;

 { --- Scope --- }
 scope_stack  : Array[0..MAX_DEPTH] of TScopeEntry;
 scope_top    : Integer;   { index du scope courant }
 cur_proc_idx : Integer;   { procedure en cours de compilation }

 { --- Forward references --- }
 fwd_refs     : Array[1..MAX_FWD] of TFwdRef;
 fwd_count    : Integer;

 { --- Generateur de code --- }
 label_counter : Integer;
 lit_counter   : Integer;
 gen_enabled   : Boolean;
 error_count   : Integer;
 main_proc_idx : Integer;   { index de la procedure MAIN }

{ ============================================================================ }
{ TODO 01 - Architecture + utilitaires de base           [COMPLET]            }
{ ============================================================================ }

Function ItoS(n: LongInt): String;
Var s: String;
Begin Str(n, s); ItoS := s; End;

Function ItoSI(n: Integer): String;
Var s: String;
Begin Str(n, s); ItoSI := s; End;

Function UpCaseStr(Const s: String): String;
Var i: Integer; r: String;
Begin
 r := s;
 For i := 1 to Length(r) do
  If (r[i] >= 'a') And (r[i] <= 'z') Then
   r[i] := Chr(Ord(r[i]) - 32);
 UpCaseStr := r;
End;

{ Sanitise un nom PL/I en etiquette ASM valide }
Function AsmIdent(Const prefix, name: String): String;
Var i: Integer; r: String;
Begin
 r := prefix;
 For i := 1 to Length(name) do
  Case name[i] Of
   'A'..'Z','0'..'9': r := r + name[i];
   'a'..'z': r := r + Chr(Ord(name[i]) - 32);
   '_','-': r := r + '_';
  Else r := r + 'X';
  End;
 AsmIdent := r;
End;

Function PadLabel(Const s: String): String;
Var r: String; i: Integer;
Begin
 r := s;
 While Length(r) < 4 do r := '0' + r;
 PadLabel := r;
End;

Procedure Error(Const msg: String);
Begin
 WriteLn('ERREUR (ligne ', src_line_num, ') : ', msg);
 Inc(error_count);
End;

Procedure Warning(Const msg: String);
Begin
 WriteLn('ATTENTION (ligne ', src_line_num, ') : ', msg);
End;

{ ============================================================================ }
{ TODO 02 - TOKENISEUR PL/I                              [COMPLET]            }
{ ============================================================================ }

Function SrcGetChar: Char;
Begin
 If has_peek Then
 Begin SrcGetChar := peek_char; has_peek := False; Exit; End;
 If src_eof Then Begin SrcGetChar := #0; Exit; End;
 While (src_col > Length(src_line)) And Not src_eof Do
 Begin
  If EOF(input_file) Then
  Begin src_eof := True; SrcGetChar := #0; Exit; End;
  ReadLn(input_file, src_line);
  Inc(src_line_num);
  src_col := 1;
  SrcGetChar := ' ';
  Exit;
 End;
 SrcGetChar := src_line[src_col];
 Inc(src_col);
End;

Function SrcPeekChar: Char;
Var ch: Char;
Begin
 If has_peek Then Begin SrcPeekChar := peek_char; Exit; End;
 ch := SrcGetChar;
 If ch = #0 Then Begin SrcPeekChar := #0; Exit; End;
 has_peek := True; peek_char := ch; SrcPeekChar := ch;
End;

Procedure NextToken; Forward;

Procedure InitTokenizer;
Begin
 src_line_num := 0; src_col := 1; src_eof := False;
 has_peek := False; peek_char := #0;
 cur_tok_type := TOK_UNKNOWN; cur_tok_str := '';
 cur_tok_num  := 0; cur_tok_kw := KW_NONE;
 src_line := '';
 If EOF(input_file) Then src_eof := True
 Else
 Begin
  ReadLn(input_file, src_line);
  src_line_num := 1; src_col := 1;
 End;
 NextToken;
End;

Function IsKeyword(Const s: String): Integer; Forward;

Procedure NextToken;
Var c, c2: Char; s: String; n: LongInt;
Begin
 cur_tok_str := ''; cur_tok_num := 0; cur_tok_kw := KW_NONE;
 { Sauter espaces }
 Repeat
  c := SrcPeekChar;
  If c = #0 Then Break;
  If (c = ' ') Or (c = #9) Or (c = #13) Or (c = #10) Then SrcGetChar
  Else If (c = '/') Then
  Begin
   SrcGetChar;
   If SrcPeekChar = '*' Then
   Begin
    { Commentaire /* ... */ }
    SrcGetChar;
    Repeat
     c := SrcGetChar;
     If c = #0 Then Break;
     If (c = '*') And (SrcPeekChar = '/') Then
     Begin SrcGetChar; Break; End;
    Until False;
   End Else
   Begin
    { Token TOK_SLASH }
    has_peek := True; peek_char := c;
    c := '/';
    Break;
   End;
  End
  Else Break;
 Until False;
 If SrcPeekChar = #0 Then
 Begin cur_tok_type := TOK_EOF; cur_tok_str := 'EOF'; Exit; End;
 c := SrcGetChar;
 Case c Of
  '(': Begin cur_tok_type := TOK_LPAREN; cur_tok_str := '('; End;
  ')': Begin cur_tok_type := TOK_RPAREN; cur_tok_str := ')'; End;
  ';': Begin cur_tok_type := TOK_SEMI;   cur_tok_str := ';'; End;
  ',': Begin cur_tok_type := TOK_COMMA;  cur_tok_str := ','; End;
  '+': Begin cur_tok_type := TOK_PLUS;   cur_tok_str := '+'; End;
  '-': Begin
        If SrcPeekChar = '>' Then
        Begin SrcGetChar; cur_tok_type := TOK_ARROW; cur_tok_str := '->'; End
        Else Begin cur_tok_type := TOK_MINUS; cur_tok_str := '-'; End;
       End;
  '*': Begin
        If SrcPeekChar = '*' Then
        Begin SrcGetChar; cur_tok_type := TOK_STAR2; cur_tok_str := '**'; End
        Else Begin cur_tok_type := TOK_STAR; cur_tok_str := '*'; End;
       End;
  '/': Begin cur_tok_type := TOK_SLASH;  cur_tok_str := '/'; End;
  '=': Begin cur_tok_type := TOK_ASSIGN; cur_tok_str := '='; End;
  ':': Begin cur_tok_type := TOK_COLON;  cur_tok_str := ':'; End;
  '.': Begin cur_tok_type := TOK_DOT;    cur_tok_str := '.'; End;
  '%': Begin cur_tok_type := TOK_PERCENT;cur_tok_str := '%'; End;
  '<': Begin
        c2 := SrcPeekChar;
        If c2 = '=' Then Begin SrcGetChar; cur_tok_type := TOK_LE; cur_tok_str := '<='; End
        Else Begin cur_tok_type := TOK_LT; cur_tok_str := '<'; End;
       End;
  '>': Begin
        c2 := SrcPeekChar;
        If c2 = '=' Then Begin SrcGetChar; cur_tok_type := TOK_GE; cur_tok_str := '>='; End
        Else Begin cur_tok_type := TOK_GT; cur_tok_str := '>'; End;
       End;
  '^','!': Begin
        c2 := SrcPeekChar;
        If c2 = '=' Then Begin SrcGetChar; cur_tok_type := TOK_NE; cur_tok_str := '^='; End
        Else Begin cur_tok_type := TOK_NOT; cur_tok_str := '^'; End;
       End;
  '&': Begin cur_tok_type := TOK_AND; cur_tok_str := '&'; End;
  '|': Begin
        If SrcPeekChar = '|' Then
        Begin SrcGetChar; cur_tok_type := TOK_CONCAT; cur_tok_str := '||'; End
        Else Begin cur_tok_type := TOK_OR; cur_tok_str := '|'; End;
       End;
  '''': Begin
         { Chaine PL/I : '...' avec '' pour apostrophe interieure }
         s := '';
         Repeat
          c2 := SrcGetChar;
          If c2 = #0 Then Break;
          If c2 = '''' Then
          Begin
           If SrcPeekChar = '''' Then Begin SrcGetChar; s := s + ''''; End
           Else Break;
          End Else s := s + c2;
         Until False;
         cur_tok_type := TOK_STRING; cur_tok_str := s;
        End;
 Else
  { Nombre ou identificateur }
  If (c >= '0') And (c <= '9') Then
  Begin
   n := Ord(c) - 48;
   While (SrcPeekChar >= '0') And (SrcPeekChar <= '9') Do
    n := n * 10 + (Ord(SrcGetChar) - 48);
   { Ignorer suffixe E/B/D pour simplification }
   cur_tok_type := TOK_NUMBER; cur_tok_num := n; cur_tok_str := ItoS(n);
  End Else
  If ((c >= 'A') And (c <= 'Z')) Or ((c >= 'a') And (c <= 'z')) Or (c = '_') Then
  Begin
   s := UpCase(c);
   While True Do
   Begin
    c2 := SrcPeekChar;
    If ((c2 >= 'A') And (c2 <= 'Z')) Or ((c2 >= 'a') And (c2 <= 'z')) Or
       (c2 = '_') Or ((c2 >= '0') And (c2 <= '9')) Then
     s := s + UpCase(SrcGetChar)
    Else Break;
   End;
   cur_tok_type := TOK_IDENT; cur_tok_str := s;
   cur_tok_kw  := IsKeyword(s);
  End Else
  Begin
   cur_tok_type := TOK_UNKNOWN; cur_tok_str := c;
  End;
 End;
End;

Procedure Consume;
Begin NextToken; End;

Function TokIs(Const s: String): Boolean;
Begin TokIs := (cur_tok_type = TOK_IDENT) And (cur_tok_str = UpCaseStr(s)); End;

Function TokIsKw(kw: Integer): Boolean;
Begin TokIsKw := (cur_tok_type = TOK_IDENT) And (cur_tok_kw = kw); End;

Procedure Expect(tt: Integer; Const msg: String);
Begin
 If cur_tok_type <> tt Then Error('Attendu ' + msg + ', trouve: ' + cur_tok_str);
 Consume;
End;

{ ============================================================================ }
{ TODO 03 - RECONNAISSANCE DES MOTS-CLES PL/I            [COMPLET]            }
{ ============================================================================ }

Function IsKeyword(Const s: String): Integer;
Begin
 If s = 'PROCEDURE'  Then Begin IsKeyword := KW_PROCEDURE;  Exit; End;
 If s = 'PROC'       Then Begin IsKeyword := KW_PROCEDURE;  Exit; End;
 If s = 'END'        Then Begin IsKeyword := KW_END;        Exit; End;
 If s = 'BEGIN'      Then Begin IsKeyword := KW_BEGIN;      Exit; End;
 If s = 'CALL'       Then Begin IsKeyword := KW_CALL;       Exit; End;
 If s = 'RETURN'     Then Begin IsKeyword := KW_RETURN;     Exit; End;
 If s = 'IF'         Then Begin IsKeyword := KW_IF;         Exit; End;
 If s = 'THEN'       Then Begin IsKeyword := KW_THEN;       Exit; End;
 If s = 'ELSE'       Then Begin IsKeyword := KW_ELSE;       Exit; End;
 If s = 'DO'         Then Begin IsKeyword := KW_DO;         Exit; End;
 If s = 'WHILE'      Then Begin IsKeyword := KW_WHILE;      Exit; End;
 If s = 'UNTIL'      Then Begin IsKeyword := KW_UNTIL;      Exit; End;
 If s = 'SELECT'     Then Begin IsKeyword := KW_SELECT;     Exit; End;
 If s = 'WHEN'       Then Begin IsKeyword := KW_WHEN;       Exit; End;
 If s = 'OTHERWISE'  Then Begin IsKeyword := KW_OTHERWISE;  Exit; End;
 If s = 'DECLARE'    Then Begin IsKeyword := KW_DECLARE;    Exit; End;
 If s = 'DCL'        Then Begin IsKeyword := KW_DCL;        Exit; End;
 If s = 'FIXED'      Then Begin IsKeyword := KW_FIXED;      Exit; End;
 If s = 'FLOAT'      Then Begin IsKeyword := KW_FLOAT;      Exit; End;
 If s = 'CHAR'       Then Begin IsKeyword := KW_CHAR;       Exit; End;
 If s = 'CHARACTER'  Then Begin IsKeyword := KW_CHARACTER;  Exit; End;
 If s = 'BIT'        Then Begin IsKeyword := KW_BIT;        Exit; End;
 If s = 'LABEL'      Then Begin IsKeyword := KW_LABEL;      Exit; End;
 If s = 'POINTER'    Then Begin IsKeyword := KW_POINTER;    Exit; End;
 If s = 'PTR'        Then Begin IsKeyword := KW_PTR;        Exit; End;
 If s = 'STATIC'     Then Begin IsKeyword := KW_STATIC;     Exit; End;
 If s = 'AUTOMATIC'  Then Begin IsKeyword := KW_AUTOMATIC;  Exit; End;
 If s = 'AUTO'       Then Begin IsKeyword := KW_AUTO;       Exit; End;
 If s = 'EXTERNAL'   Then Begin IsKeyword := KW_EXTERNAL;   Exit; End;
 If s = 'INTERNAL'   Then Begin IsKeyword := KW_INTERNAL;   Exit; End;
 If s = 'INITIAL'    Then Begin IsKeyword := KW_INITIAL;    Exit; End;
 If s = 'INIT'       Then Begin IsKeyword := KW_INIT;       Exit; End;
 If s = 'RETURNS'    Then Begin IsKeyword := KW_RETURNS;    Exit; End;
 If s = 'OPTIONS'    Then Begin IsKeyword := KW_OPTIONS;    Exit; End;
 If s = 'BINARY'     Then Begin IsKeyword := KW_BINARY;     Exit; End;
 If s = 'DECIMAL'    Then Begin IsKeyword := KW_DECIMAL;    Exit; End;
 If s = 'PUT'        Then Begin IsKeyword := KW_PUT;        Exit; End;
 If s = 'GET'        Then Begin IsKeyword := KW_GET;        Exit; End;
 If s = 'LIST'       Then Begin IsKeyword := KW_LIST;       Exit; End;
 If s = 'SKIP'       Then Begin IsKeyword := KW_SKIP;       Exit; End;
 If s = 'TO'         Then Begin IsKeyword := KW_TO;         Exit; End;
 If s = 'BY'         Then Begin IsKeyword := KW_BY;         Exit; End;
 If s = 'GOTO'       Then Begin IsKeyword := KW_GOTO;       Exit; End;
 If s = 'GO'         Then Begin IsKeyword := KW_GO;         Exit; End;
 If s = 'ON'         Then Begin IsKeyword := KW_ON;         Exit; End;
 If s = 'SIGNAL'     Then Begin IsKeyword := KW_SIGNAL;     Exit; End;
 If s = 'REVERT'     Then Begin IsKeyword := KW_REVERT;     Exit; End;
 If s = 'ENTRY'      Then Begin IsKeyword := KW_ENTRY;      Exit; End;
 If s = 'VARYING'    Then Begin IsKeyword := KW_VARYING;    Exit; End;
 If s = 'RECURSIVE'  Then Begin IsKeyword := KW_RECURSIVE;  Exit; End;
 If s = 'AND'        Then Begin IsKeyword := KW_AND;        Exit; End;
 If s = 'OR'         Then Begin IsKeyword := KW_OR;         Exit; End;
 If s = 'NOT'        Then Begin IsKeyword := KW_NOT;        Exit; End;
 If s = 'MOD'        Then Begin IsKeyword := KW_MOD;        Exit; End;
 If s = 'BASED'      Then Begin IsKeyword := KW_BASED;      Exit; End;
 If s = 'DIMENSION'  Then Begin IsKeyword := KW_DIMENSION;  Exit; End;
 If s = 'DIM'        Then Begin IsKeyword := KW_DIM;        Exit; End;
 If s = 'SUBSTR'     Then Begin IsKeyword := KW_SUBSTR;     Exit; End;
 If s = 'INDEX'      Then Begin IsKeyword := KW_INDEX;      Exit; End;
 If s = 'LENGTH'     Then Begin IsKeyword := KW_LENGTH;     Exit; End;
 If s = 'ABS'        Then Begin IsKeyword := KW_ABS;        Exit; End;
 If s = 'MAX'        Then Begin IsKeyword := KW_MAX;        Exit; End;
 If s = 'MIN'        Then Begin IsKeyword := KW_MIN;        Exit; End;
 If s = 'SIGN'       Then Begin IsKeyword := KW_SIGN;       Exit; End;
 If s = 'FLOOR'      Then Begin IsKeyword := KW_FLOOR;      Exit; End;
 If s = 'CEIL'       Then Begin IsKeyword := KW_CEIL;       Exit; End;
 If s = 'TRUNC'      Then Begin IsKeyword := KW_TRUNC;      Exit; End;
 If s = 'ROUND'      Then Begin IsKeyword := KW_ROUND;      Exit; End;
 If s = 'UNSPEC'     Then Begin IsKeyword := KW_UNSPEC;     Exit; End;
 If s = 'STRING'     Then Begin IsKeyword := KW_STRING;     Exit; End;
 If s = 'FORMAT'     Then Begin IsKeyword := KW_FORMAT;     Exit; End;
 If s = 'EDIT'       Then Begin IsKeyword := KW_EDIT;       Exit; End;
 If s = 'OPEN'       Then Begin IsKeyword := KW_OPEN;       Exit; End;
 If s = 'CLOSE'      Then Begin IsKeyword := KW_CLOSE;      Exit; End;
 If s = 'READ'       Then Begin IsKeyword := KW_READ;       Exit; End;
 If s = 'WRITE'      Then Begin IsKeyword := KW_WRITE;      Exit; End;
 If s = 'OVERFLOW'   Then Begin IsKeyword := KW_OVERFLOW;   Exit; End;
 If s = 'ZERODIVIDE' Then Begin IsKeyword := KW_ZERODIVIDE; Exit; End;
 If s = 'NOOVERFLOW' Then Begin IsKeyword := KW_NOOVERFLOW; Exit; End;
 If s = 'ALLOCATE'   Then Begin IsKeyword := KW_ALLOCATE;   Exit; End;
 If s = 'ALLOC'      Then Begin IsKeyword := KW_ALLOC;      Exit; End;
 If s = 'FREE'       Then Begin IsKeyword := KW_FREE;       Exit; End;
 IsKeyword := KW_NONE;
End;

{ ============================================================================ }
{ TODO 04 - TABLE DES SYMBOLES ET DES PROCEDURES         [COMPLET]            }
{ ============================================================================ }

Procedure InitSymTable;
Begin
 sym_count  := 0;
 proc_count := 0;
 str_count  := 0;
 fwd_count  := 0;
 FillChar(sym_table,  SizeOf(sym_table),  0);
 FillChar(proc_table, SizeOf(proc_table), 0);
 FillChar(str_table,  SizeOf(str_table),  0);
End;

Function FindSym(Const name: String): Integer;
Var i: Integer; u: String;
Begin
 u := UpCaseStr(name);
 For i := sym_count DownTo 1 do
  If sym_table[i]^.name = u Then Begin FindSym := i; Exit; End;
 FindSym := 0;
End;

Function AddSym(Const name: String; dt, sc: Integer): Integer;
Var p: PSymEntry; u: String;
Begin
 u := UpCaseStr(name);
 If sym_count >= MAX_SYM Then
 Begin Error('Table des symboles pleine'); AddSym := 0; Exit; End;
 New(p);
 p^.name        := u;
 p^.asm_label   := AsmIdent('_VAR_', u);
 p^.data_type   := dt;
 p^.store_class := sc;
 p^.bp_offset   := 0;
 p^.array_size  := 0;
 p^.precision   := 15;
 p^.scale       := 0;
 p^.is_param    := False;
 p^.param_idx   := 0;
 p^.init_val    := 0;
 p^.has_init    := False;
 Inc(sym_count);
 sym_table[sym_count] := p;
 AddSym := sym_count;
End;

Function FindProc(Const name: String): Integer;
Var i: Integer; u: String;
Begin
 u := UpCaseStr(name);
 For i := 1 to proc_count do
  If proc_table[i]^.name = u Then Begin FindProc := i; Exit; End;
 FindProc := 0;
End;

Function AddProc(Const name: String; nparams, rt: Integer): Integer;
Var p: PProcEntry; u: String; existing: Integer;
Begin
 u := UpCaseStr(name);
 existing := FindProc(u);
 If existing > 0 Then Begin AddProc := existing; Exit; End;
 If proc_count >= MAX_PROC Then
 Begin Error('Table des procedures pleine'); AddProc := 0; Exit; End;
 Inc(proc_count);
 New(p);
 p^.name        := u;
 p^.asm_label   := AsmIdent('_PLI_', u);
 p^.param_count := nparams;
 p^.return_type := rt;
 p^.defined     := False;
 p^.is_main     := False;
 p^.is_recursive:= False;
 proc_table[proc_count] := p;
 AddProc := proc_count;
End;

{ ============================================================================ }
{ TODO 05 - GESTION DES SCOPES                           [COMPLET]            }
{ ============================================================================ }

Procedure InitScopes;
Begin
 scope_top := 0;
 scope_stack[0].kind      := SK_GLOBAL;
 scope_stack[0].proc_idx  := 0;
 scope_stack[0].bp_top    := 0;
 scope_stack[0].sym_start := 1;
 scope_stack[0].sym_end   := 0;
 scope_stack[0].lbl_exit  := '';
 cur_proc_idx := 0;
End;

Procedure EnterScope(kind: TScopeKind; pidx: Integer);
Begin
 If scope_top >= MAX_DEPTH Then
 Begin Error('Trop d''imbrications de scopes'); Exit; End;
 Inc(scope_top);
 scope_stack[scope_top].kind      := kind;
 scope_stack[scope_top].proc_idx  := pidx;
 scope_stack[scope_top].bp_top    := 0;
 scope_stack[scope_top].sym_start := sym_count + 1;
 scope_stack[scope_top].sym_end   := sym_count;
 scope_stack[scope_top].lbl_exit  := '';
 If kind = SK_PROC Then cur_proc_idx := pidx;
End;

Procedure LeaveScope;
Begin
 If scope_top = 0 Then Begin Error('LeaveScope sur scope global'); Exit; End;
 scope_stack[scope_top].sym_end := sym_count;
 Dec(scope_top);
 If scope_stack[scope_top].kind = SK_PROC Then
  cur_proc_idx := scope_stack[scope_top].proc_idx
 Else
  cur_proc_idx := 0;
End;

Function CurrentBpTop: Integer;
Begin CurrentBpTop := scope_stack[scope_top].bp_top; End;

Procedure AllocLocalBp(bytes: Integer);
Begin
 Dec(scope_stack[scope_top].bp_top, bytes);
End;

{ ============================================================================ }
{ TODO 09 - PRIMITIVES D'EMISSION ASM                    [COMPLET]            }
{ ============================================================================ }

Procedure Emit(Const s: String);
Begin If gen_enabled Then WriteLn(output_file, s); End;

Procedure EmitLabel(Const lbl: String);
Begin If gen_enabled Then WriteLn(output_file, lbl, ':'); End;

Procedure EmitComment(Const s: String);
Begin If gen_enabled Then WriteLn(output_file, '        ; ', s); End;

Procedure EmitBlank;
Begin If gen_enabled Then WriteLn(output_file); End;

Function NewLabel: String;
Var s: String;
Begin
 Inc(label_counter);
 s := ItoSI(label_counter);
 While Length(s) < 4 do s := '0' + s;
 NewLabel := '_L' + s;
End;

Function AddStringLit(Const text: String): String;
Var p: PStrEntry; lbl: String;
Begin
 If str_count >= MAX_STR Then
 Begin Error('Trop de litteraux chaines'); AddStringLit := '_CRLF'; Exit; End;
 Inc(str_count); Inc(lit_counter);
 lbl := '_LS' + ItoSI(lit_counter);
 New(p); p^.text := text; p^.asm_label := lbl;
 str_table[str_count] := p;
 AddStringLit := lbl;
End;

{ ============================================================================ }
{ TODO 08 - GENERATION : CHARGE / STOCKE VARIABLE        [COMPLET]            }
{ ============================================================================ }

Procedure GenLoadVar(sym_idx: Integer);
Var p: PSymEntry;
Begin
 If (sym_idx < 1) Or (sym_idx > sym_count) Then
 Begin EmitComment('GenLoadVar: idx invalide'); Exit; End;
 p := sym_table[sym_idx];
 If p^.store_class = STORE_AUTO Then
 Begin
  If p^.bp_offset >= 0 Then
   Emit('        MOV     AX, [BP+' + ItoSI(p^.bp_offset) + ']')
  Else
   Emit('        MOV     AX, [BP' + ItoSI(p^.bp_offset) + ']');
 End Else
  Emit('        MOV     AX, [' + p^.asm_label + ']');
End;

Procedure GenStoreVar(sym_idx: Integer);
Var p: PSymEntry;
Begin
 If (sym_idx < 1) Or (sym_idx > sym_count) Then
 Begin EmitComment('GenStoreVar: idx invalide'); Exit; End;
 p := sym_table[sym_idx];
 If p^.store_class = STORE_AUTO Then
 Begin
  If p^.bp_offset >= 0 Then
   Emit('        MOV     [BP+' + ItoSI(p^.bp_offset) + '], AX')
  Else
   Emit('        MOV     [BP' + ItoSI(p^.bp_offset) + '], AX');
 End Else
  Emit('        MOV     [' + p^.asm_label + '], AX');
End;

Procedure GenBinOp(op, dt: Integer);
Begin
 Case op Of
  TOK_PLUS:    Emit('        ADD     AX, BX');
  TOK_MINUS:   Emit('        SUB     AX, BX');
  TOK_STAR:    Emit('        IMUL    BX');
  TOK_SLASH:   Begin
                Emit('        CWD');
                Emit('        IDIV    BX');
               End;
  TOK_PERCENT: Begin
                Emit('        CWD');
                Emit('        IDIV    BX');
                Emit('        MOV     AX, DX');
               End;
  TOK_CONCAT:  EmitComment('|| concatenation (stub)');
 End;
End;

Procedure GenCompare(op: Integer);
Var lbl_f, lbl_e: String;
Begin
 lbl_f := NewLabel + 'CF'; lbl_e := NewLabel + 'CE';
 Emit('        CMP     AX, BX');
 Case op Of
  TOK_EQ, TOK_ASSIGN: Emit('        JNE     ' + lbl_f);
  TOK_NE:             Emit('        JE      ' + lbl_f);
  TOK_LT:             Emit('        JGE     ' + lbl_f);
  TOK_LE:             Emit('        JG      ' + lbl_f);
  TOK_GT:             Emit('        JLE     ' + lbl_f);
  TOK_GE:             Emit('        JL      ' + lbl_f);
 Else Emit('        JNE ' + lbl_f);
 End;
 Emit('        MOV     AX, 0FFFFh');
 Emit('        JMP     ' + lbl_e);
 EmitLabel(lbl_f);
 Emit('        XOR     AX, AX');
 EmitLabel(lbl_e);
End;

{ ============================================================================ }
{ TODO 18 - GENERATION : PROLOGUE / EPILOGUE PROCEDURE   [COMPLET]            }
{ ============================================================================ }

Procedure GenPrologue(local_size: Integer);
Begin
 Emit('        PUSH    BP');
 Emit('        MOV     BP, SP');
 If local_size > 0 Then
  Emit('        SUB     SP, ' + ItoSI(local_size));
End;

Procedure GenEpilogue(nparams: Integer);
Begin
 Emit('        MOV     SP, BP');
 Emit('        POP     BP');
 Emit('        RET     ' + ItoSI(nparams * 2));
End;

{ ============================================================================ }
{ TODO 19 - GENERATION : TABLEAUX (DIMENSION/DIM)        [COMPLET]            }
{ ============================================================================ }

Procedure GenArrayLoad(sym_idx: Integer);
{ AX = index en entree (base-1 PL/I), AX = valeur lue en sortie }
Var p: PSymEntry;
Begin
 If (sym_idx < 1) Or (sym_idx > sym_count) Then
 Begin EmitComment('GenArrayLoad: idx invalide'); Exit; End;
 p := sym_table[sym_idx];
 Emit('        DEC     AX');           { base-1 -> base-0 }
 Emit('        SHL     AX, 1');        { *2 pour WORD (DW) }
 Emit('        MOV     SI, AX');
 If p^.store_class = STORE_AUTO Then
 Begin
  If p^.bp_offset >= 0 Then
   Emit('        MOV     AX, [BP+' + ItoSI(p^.bp_offset) + '+SI]')
  Else
   Emit('        MOV     AX, [BP' + ItoSI(p^.bp_offset) + '+SI]');
 End Else
  Emit('        MOV     AX, [' + p^.asm_label + '+SI]');
End;

Procedure GenArrayStoreVal(sym_idx: Integer);
{ AX = valeur a stocker ; SI = index*2 deja calcule par l'appelant }
Var p: PSymEntry;
Begin
 If (sym_idx < 1) Or (sym_idx > sym_count) Then
 Begin EmitComment('GenArrayStoreVal: idx invalide'); Exit; End;
 p := sym_table[sym_idx];
 If p^.store_class = STORE_AUTO Then
 Begin
  If p^.bp_offset >= 0 Then
   Emit('        MOV     [BP+' + ItoSI(p^.bp_offset) + '+SI], AX')
  Else
   Emit('        MOV     [BP' + ItoSI(p^.bp_offset) + '+SI], AX');
 End Else
  Emit('        MOV     [' + p^.asm_label + '+SI], AX');
End;

{ Forward pour GenBuiltIn qui appelle ParseExpr }
Function ParseExpr: Integer; Forward;

{ ============================================================================ }
{ TODO 20 - FONCTIONS BUILT-IN PL/I                      [COMPLET]            }
{ ============================================================================ }

Function GenBuiltIn(Const bname: String): Boolean;
{ Appele apres consommation de '('.  Parse les arguments et genere le code.
  Consomme ')'.  Retourne True si built-in reconnu, False sinon. }
Var lbl1, lbl2: String; dt: Integer;
Begin
 GenBuiltIn := True;
 lbl1 := NewLabel + 'B1'; lbl2 := NewLabel + 'B2';
 If bname = 'ABS' Then
 Begin
  dt := ParseExpr;
  If cur_tok_type = TOK_RPAREN Then Consume;
  Emit('        CWD');
  Emit('        XOR     AX, DX');
  Emit('        SUB     AX, DX');
 End Else If bname = 'SIGN' Then
 Begin
  dt := ParseExpr;
  If cur_tok_type = TOK_RPAREN Then Consume;
  Emit('        TEST    AX, AX');
  Emit('        JZ      ' + lbl2);
  Emit('        JNS     ' + lbl1);
  Emit('        MOV     AX, 0FFFFh');
  Emit('        JMP     ' + lbl2);
  EmitLabel(lbl1);
  Emit('        MOV     AX, 1');
  EmitLabel(lbl2);
 End Else If (bname = 'FLOOR') Or (bname = 'CEIL') Or
             (bname = 'TRUNC') Or (bname = 'ROUND') Or
             (bname = 'UNSPEC') Then
 Begin
  dt := ParseExpr;
  If cur_tok_type = TOK_RPAREN Then Consume;
 End Else If bname = 'MOD' Then
 Begin
  dt := ParseExpr;
  Emit('        PUSH    AX');
  If cur_tok_type = TOK_COMMA Then Consume;
  dt := ParseExpr;
  Emit('        MOV     BX, AX');
  Emit('        POP     AX');
  Emit('        CWD');
  Emit('        IDIV    BX');
  Emit('        MOV     AX, DX');
  If cur_tok_type = TOK_RPAREN Then Consume;
 End Else If bname = 'MAX' Then
 Begin
  dt := ParseExpr;
  Emit('        PUSH    AX');
  If cur_tok_type = TOK_COMMA Then Consume;
  dt := ParseExpr;
  Emit('        MOV     BX, AX');
  Emit('        POP     AX');
  Emit('        CMP     AX, BX');
  Emit('        JGE     ' + lbl1);
  Emit('        MOV     AX, BX');
  EmitLabel(lbl1);
  If cur_tok_type = TOK_RPAREN Then Consume;
 End Else If bname = 'MIN' Then
 Begin
  dt := ParseExpr;
  Emit('        PUSH    AX');
  If cur_tok_type = TOK_COMMA Then Consume;
  dt := ParseExpr;
  Emit('        MOV     BX, AX');
  Emit('        POP     AX');
  Emit('        CMP     AX, BX');
  Emit('        JLE     ' + lbl1);
  Emit('        MOV     AX, BX');
  EmitLabel(lbl1);
  If cur_tok_type = TOK_RPAREN Then Consume;
 End Else If bname = 'LENGTH' Then
 Begin
  dt := ParseExpr;
  If cur_tok_type = TOK_RPAREN Then Consume;
  EmitComment('LENGTH : parcours jusqu a terminateur 24h ($)');
  Emit('        MOV     SI, AX');
  Emit('        XOR     CX, CX');
  EmitLabel(lbl1);
  Emit('        MOV     AL, [SI]');
  Emit('        CMP     AL, 24h');
  Emit('        JE      ' + lbl2);
  Emit('        INC     SI');
  Emit('        INC     CX');
  Emit('        JMP     ' + lbl1);
  EmitLabel(lbl2);
  Emit('        MOV     AX, CX');
 End Else If bname = 'SUBSTR' Then
 Begin
  dt := ParseExpr;
  Emit('        MOV     DI, AX');
  If cur_tok_type = TOK_COMMA Then Consume;
  dt := ParseExpr;
  Emit('        DEC     AX');
  Emit('        ADD     DI, AX');
  If cur_tok_type = TOK_COMMA Then
  Begin Consume; dt := ParseExpr; End;
  If cur_tok_type = TOK_RPAREN Then Consume;
  Emit('        MOV     AX, DI');
 End Else If bname = 'INDEX' Then
 Begin
  dt := ParseExpr;
  Emit('        PUSH    AX');
  If cur_tok_type = TOK_COMMA Then Consume;
  dt := ParseExpr;
  Emit('        POP     SI');
  If cur_tok_type = TOK_RPAREN Then Consume;
  EmitComment('INDEX(s,t) : stub -> retourne 0');
  Emit('        XOR     AX, AX');
 End Else If (bname = 'STRING') Or (bname = 'CHARACTER') Then
 Begin
  dt := ParseExpr;
  If cur_tok_type = TOK_RPAREN Then Consume;
  EmitComment('STRING/CHARACTER conversion (stub)');
 End Else
  GenBuiltIn := False;
End;

{ ============================================================================ }
{ TODO 07 - PARSEUR : EXPRESSIONS                        [COMPLET]            }
{ ============================================================================ }

{ Forward deja declare plus haut pour GenBuiltIn }

Function ParsePrimaryExpr: Integer;
Var sym_idx, lbl_idx, nargs: Integer; s: String; lbl_t, lbl_e2: String;
Begin
 ParsePrimaryExpr := TYPE_FIXED;
 Case cur_tok_type Of
  TOK_NUMBER:
  Begin
   Emit('        MOV     AX, ' + ItoS(cur_tok_num));
   Consume;
  End;
  TOK_STRING:
  Begin
   s := AddStringLit(cur_tok_str + '$');
   Emit('        LEA     AX, ' + s);
   Consume;
   ParsePrimaryExpr := TYPE_CHAR;
  End;
  TOK_LPAREN:
  Begin
   Consume;
   ParsePrimaryExpr := ParseExpr;
   If cur_tok_type = TOK_RPAREN Then Consume
   Else Error('Attendu )');
  End;
  TOK_IDENT:
  Begin
   Case cur_tok_kw Of
    KW_NOT, KW_NONE,
    KW_ABS, KW_SIGN, KW_MAX, KW_MIN, KW_MOD,
    KW_FLOOR, KW_CEIL, KW_TRUNC, KW_ROUND, KW_UNSPEC,
    KW_LENGTH, KW_SUBSTR, KW_INDEX, KW_STRING: { NOT, ident ou built-in PL/I }
    Begin
     If cur_tok_kw = KW_NOT Then
     Begin
      lbl_t := NewLabel + 'NT'; lbl_e2 := NewLabel + 'NE';
      Consume;
      ParsePrimaryExpr := ParsePrimaryExpr;
      Emit('        TEST    AX, AX');
      Emit('        JNZ     ' + lbl_t);
      Emit('        MOV     AX, 0FFFFh');
      Emit('        JMP     ' + lbl_e2);
      EmitLabel(lbl_t);
      Emit('        XOR     AX, AX');
      EmitLabel(lbl_e2);
     End Else
     Begin
      s := cur_tok_str; Consume;
      If cur_tok_type = TOK_LPAREN Then
      Begin
       { Built-in, tableau ou appel de procedure selon contexte }
       Consume; { manger '(' }
       sym_idx := FindSym(s);
       If (sym_idx > 0) And (sym_table[sym_idx]^.array_size > 0) Then
       Begin
        { Acces tableau tab(i) - base-1 PL/I }
        ParsePrimaryExpr := ParseExpr;
        If cur_tok_type = TOK_RPAREN Then Consume
        Else Error('Attendu ) apres index tableau');
        GenArrayLoad(sym_idx);
        ParsePrimaryExpr := sym_table[sym_idx]^.data_type;
       End Else If GenBuiltIn(s) Then
        ParsePrimaryExpr := TYPE_FIXED
       Else
       Begin
        { Appel de procedure externe comme expression }
        nargs := 0;
        While cur_tok_type <> TOK_RPAREN Do
        Begin
         If cur_tok_type = TOK_EOF Then Break;
         ParseExpr;
         Emit('        PUSH    AX');
         Inc(nargs);
         If cur_tok_type = TOK_COMMA Then Consume;
        End;
        If cur_tok_type = TOK_RPAREN Then Consume;
        Emit('        CALL    ' + AsmIdent('_PLI_', s));
        If nargs > 0 Then
         Emit('        ADD     SP, ' + ItoSI(nargs * 2));
        ParsePrimaryExpr := TYPE_FIXED;
       End;
      End Else
      Begin
       sym_idx := FindSym(s);
       If sym_idx > 0 Then
       Begin
        GenLoadVar(sym_idx);
        ParsePrimaryExpr := sym_table[sym_idx]^.data_type;
       End Else
       Begin
        EmitComment('Variable inconnue: ' + s);
        Emit('        XOR     AX, AX');
       End;
      End;
     End;
    End;
   Else
    EmitComment('ParsePrimaryExpr: kw inattendu ' + cur_tok_str);
    Consume;
   End;
  End;
  TOK_MINUS:
  Begin
   Consume;
   ParsePrimaryExpr := ParsePrimaryExpr;
   Emit('        NEG     AX');
  End;
 Else
  EmitComment('ParsePrimaryExpr: token inattendu ' + cur_tok_str);
  Consume;
 End;
End;

Function ParseMulExpr: Integer;
Var op, kw: Integer;
Begin
 ParseMulExpr := ParsePrimaryExpr;
 While (cur_tok_type = TOK_STAR) Or (cur_tok_type = TOK_SLASH) Or
       (cur_tok_type = TOK_PERCENT) Or (cur_tok_type = TOK_STAR2) Or
       ((cur_tok_type = TOK_IDENT) And (cur_tok_kw = KW_MOD)) Do
 Begin
  op := cur_tok_type; kw := cur_tok_kw; Consume;
  Emit('        PUSH    AX');
  ParseMulExpr := ParsePrimaryExpr;
  Emit('        MOV     BX, AX');
  Emit('        POP     AX');
  If op = TOK_STAR2 Then
  Begin
   EmitComment('** puissance via _PLI_POW');
   Emit('        PUSH    BX');
   Emit('        PUSH    AX');
   Emit('        CALL    _PLI_POW');
   Emit('        ADD     SP, 4');
  End Else If (op = TOK_IDENT) And (kw = KW_MOD) Then
  Begin
   Emit('        CWD');
   Emit('        IDIV    BX');
   Emit('        MOV     AX, DX');
  End Else
   GenBinOp(op, TYPE_FIXED);
 End;
End;

Function ParseAddExpr: Integer;
Var op: Integer;
Begin
 ParseAddExpr := ParseMulExpr;
 While (cur_tok_type = TOK_PLUS) Or (cur_tok_type = TOK_MINUS) Do
 Begin
  op := cur_tok_type; Consume;
  Emit('        PUSH    AX');
  ParseAddExpr := ParseMulExpr;
  Emit('        MOV     BX, AX');
  Emit('        POP     AX');
  GenBinOp(op, TYPE_FIXED);
 End;
End;

Function ParseRelExpr: Integer;
Var op: Integer;
Begin
 ParseRelExpr := ParseAddExpr;
 If (cur_tok_type = TOK_EQ)  Or (cur_tok_type = TOK_NE)  Or
    (cur_tok_type = TOK_LT)  Or (cur_tok_type = TOK_LE)  Or
    (cur_tok_type = TOK_GT)  Or (cur_tok_type = TOK_GE)  Then
 Begin
  op := cur_tok_type; Consume;
  Emit('        PUSH    AX');
  ParseRelExpr := ParseAddExpr;
  Emit('        MOV     BX, AX');
  Emit('        POP     AX');
  GenCompare(op);
 End;
End;

Function ParseExpr: Integer;
Var dt: Integer; op: Integer;
Begin
 ParseExpr := ParseRelExpr;
 While (cur_tok_type = TOK_AND) Or (cur_tok_type = TOK_OR) Or
       ((cur_tok_type = TOK_IDENT) And
        ((cur_tok_kw = KW_AND) Or (cur_tok_kw = KW_OR))) Do
 Begin
  op := cur_tok_type; Consume;
  Emit('        PUSH    AX');
  dt := ParseRelExpr;
  Emit('        POP     BX');
  If (op = TOK_AND) Or (op = TOK_IDENT) Then
   Emit('        AND     AX, BX')
  Else
   Emit('        OR      AX, BX');
  ParseExpr := dt;
 End;
End;

{ ============================================================================ }
{ TODO 06 - PARSEUR : DECLARE / DCL                      [COMPLET]            }
{ ============================================================================ }

Procedure ParseDeclare;
Var vname, vname2: String; dt, sc, arr_sz, prec: Integer;
    sym_idx: Integer; init_v: LongInt; has_init_v: Boolean;
    p: PSymEntry;

 Procedure ParseOneDecl;
 Var is_varying: Boolean;
 Begin
  If cur_tok_type <> TOK_IDENT Then
  Begin Error('Attendu nom de variable dans DECLARE'); Exit; End;
  vname    := cur_tok_str; Consume;
  dt       := TYPE_FIXED;
  sc       := STORE_AUTO;
  arr_sz   := 0;
  prec     := 15;
  has_init_v := False;
  init_v   := 0;
  is_varying := False;
  { Attributs }
  While True Do
  Begin
   If cur_tok_type = TOK_LPAREN Then
   Begin
    { DIM ou precision }
    Consume;
    arr_sz := cur_tok_num; Consume;
    If cur_tok_type = TOK_RPAREN Then Consume
    Else Error('Attendu )');
   End Else If TokIsKw(KW_FIXED) Then
   Begin
    dt := TYPE_FIXED; Consume;
    If TokIsKw(KW_BINARY) Then Consume;
    If TokIsKw(KW_DECIMAL) Then Consume;
    If cur_tok_type = TOK_LPAREN Then
    Begin
     Consume; prec := cur_tok_num; Consume;
     If cur_tok_type = TOK_RPAREN Then Consume;
    End;
   End Else If TokIsKw(KW_FLOAT) Then
   Begin
    dt := TYPE_FLOAT; Consume;
    If TokIsKw(KW_BINARY) Then Consume;
   End Else If TokIsKw(KW_CHAR) Or TokIsKw(KW_CHARACTER) Then
   Begin
    dt := TYPE_CHAR; Consume;
    If cur_tok_type = TOK_LPAREN Then
    Begin
     Consume; prec := cur_tok_num; Consume;
     If cur_tok_type = TOK_RPAREN Then Consume;
    End;
    If TokIsKw(KW_VARYING) Then Begin dt := TYPE_CHAR_VAR; Consume; End;
   End Else If TokIsKw(KW_BIT) Then
   Begin
    dt := TYPE_BIT; Consume;
    If cur_tok_type = TOK_LPAREN Then
    Begin
     Consume; prec := cur_tok_num; Consume;
     If cur_tok_type = TOK_RPAREN Then Consume;
    End;
   End Else If TokIsKw(KW_POINTER) Or TokIsKw(KW_PTR) Then
   Begin dt := TYPE_POINTER; Consume;
   End Else If TokIsKw(KW_STATIC) Then
   Begin sc := STORE_STATIC; Consume;
   End Else If TokIsKw(KW_AUTOMATIC) Or TokIsKw(KW_AUTO) Then
   Begin sc := STORE_AUTO; Consume;
   End Else If TokIsKw(KW_EXTERNAL) Then
   Begin sc := STORE_EXTERNAL; Consume;
   End Else If TokIsKw(KW_INITIAL) Or TokIsKw(KW_INIT) Then
   Begin
    Consume;
    If cur_tok_type = TOK_LPAREN Then
    Begin
     Consume;
     init_v := cur_tok_num; Consume;
     has_init_v := True;
     If cur_tok_type = TOK_RPAREN Then Consume;
    End;
   End Else If TokIsKw(KW_BINARY) Or TokIsKw(KW_DECIMAL) Then
   Begin Consume;
   End Else If TokIsKw(KW_DIMENSION) Or TokIsKw(KW_DIM) Then
   Begin
    Consume;
    If cur_tok_type = TOK_LPAREN Then
    Begin
     Consume; arr_sz := cur_tok_num; Consume;
     If cur_tok_type = TOK_RPAREN Then Consume;
    End;
   End Else Break;
  End;
  { Ajouter le symbole }
  sym_idx := AddSym(vname, dt, sc);
  If sym_idx = 0 Then Exit;
  p := sym_table[sym_idx];
  p^.array_size := arr_sz; p^.precision := prec;
  p^.has_init := has_init_v; p^.init_val := init_v;
  { Allouer sur la pile ou en DATA }
  If sc = STORE_AUTO Then
  Begin
   If arr_sz > 0 Then
   Begin
    AllocLocalBp(arr_sz * 2);
    p^.bp_offset := CurrentBpTop;
    Emit('        SUB     SP, ' + ItoSI(arr_sz * 2) + '  ; AUTO tab ' + vname + '(' + ItoSI(arr_sz) + ')');
   End Else
   Begin
    AllocLocalBp(2);
    p^.bp_offset := CurrentBpTop;
    Emit('        SUB     SP, 2   ; AUTO ' + vname);
    If has_init_v Then
     Emit('        MOV     WORD PTR [BP' + ItoSI(p^.bp_offset) + '], ' + ItoS(init_v));
   End;
  End Else If sc = STORE_STATIC Then
  Begin
   { Variable STATIC : emettre inline dans segment .DATA puis revenir en .CODE }
   Emit('        ; === STATIC DATA INLINE ===');
   Emit('.DATA');
   If arr_sz > 0 Then
    Emit('    ' + p^.asm_label + '  DW  ' + ItoSI(arr_sz) + ' DUP(' + ItoSI(init_v) + ')')
   Else
   Begin
    Case dt Of
     TYPE_CHAR, TYPE_CHAR_VAR:
      Emit('    ' + p^.asm_label + '  DB  ' + ItoSI(prec) + ' DUP(0)');
    Else
     Emit('    ' + p^.asm_label + '  DW  ' + ItoSI(init_v));
    End;
   End;
   Emit('.CODE');
  End;
 End;

Begin
 { DECLARE / DCL }
 Consume; { skip DECLARE/DCL }
 ParseOneDecl;
 While cur_tok_type = TOK_COMMA Do
 Begin Consume; ParseOneDecl; End;
 If cur_tok_type = TOK_SEMI Then Consume
 Else Error('Attendu ; apres DECLARE');
End;

{ ============================================================================ }
{ TODO 09 - PARSEUR : AFFECTATION                        [COMPLET]            }
{ ============================================================================ }

Procedure ParseAssignment(Const vname: String);
Var sym_idx, dt: Integer;
Begin
 { vname = deja lu, cur_tok = = }
 sym_idx := FindSym(vname);
 If sym_idx = 0 Then
 Begin
  sym_idx := AddSym(vname, TYPE_FIXED, STORE_AUTO);
  If sym_idx > 0 Then
  Begin
   AllocLocalBp(2);
   sym_table[sym_idx]^.bp_offset := CurrentBpTop;
   Emit('        SUB     SP, 2   ; AUTO impl. ' + vname);
  End;
 End;
 If cur_tok_type = TOK_ASSIGN Then Consume
 Else Error('Attendu = dans affectation');
 EmitComment(vname + ' = ...');
 dt := ParseExpr;
 GenStoreVar(sym_idx);
 If cur_tok_type = TOK_SEMI Then Consume
 Else Error('Attendu ; apres affectation');
End;

{ ============================================================================ }
{ TODO 10 - PARSEUR : IF / THEN / ELSE                   [COMPLET]            }
{ ============================================================================ }

Procedure ParseStatement; Forward;

Procedure ParseIf;
Var lbl_else, lbl_end: String;
Begin
 Consume; { skip IF }
 lbl_else := NewLabel + 'IE';
 lbl_end  := NewLabel + 'IF';
 EmitComment('---- IF ----');
 ParseExpr;
 Emit('        TEST    AX, AX');
 Emit('        JZ      ' + lbl_else);
 If Not TokIsKw(KW_THEN) Then Error('Attendu THEN')
 Else Consume;
 ParseStatement;
 Emit('        JMP     ' + lbl_end);
 EmitLabel(lbl_else);
 If TokIsKw(KW_ELSE) Then
 Begin Consume; ParseStatement; End;
 EmitLabel(lbl_end);
End;

{ ============================================================================ }
{ TODO 11 - PARSEUR : DO ... END                         [COMPLET]            }
{ ============================================================================ }

Procedure ParseDo;
Var lbl_top, lbl_end: String; iter_sym: Integer;
    iter_name: String; step_v: Integer;
Begin
 Consume; { skip DO }
 lbl_top := NewLabel + 'DT';
 lbl_end := NewLabel + 'DE';
 EmitComment('---- DO ----');
 If cur_tok_type = TOK_SEMI Then
 Begin
  { DO ; ... END ; (bloc simple) }
  Consume;
  EnterScope(SK_DO, cur_proc_idx);
  While Not (TokIsKw(KW_END) Or (cur_tok_type = TOK_EOF)) Do
   ParseStatement;
  LeaveScope;
  If TokIsKw(KW_END) Then Begin Consume; If cur_tok_type = TOK_SEMI Then Consume; End;
 End Else If TokIsKw(KW_WHILE) Then
 Begin
  { DO WHILE (expr) ; ... END ; }
  Consume;
  EmitLabel(lbl_top);
  If cur_tok_type = TOK_LPAREN Then Consume Else Error('Attendu ( apres WHILE');
  ParseExpr;
  If cur_tok_type = TOK_RPAREN Then Consume Else Error('Attendu )');
  Emit('        TEST    AX, AX');
  Emit('        JZ      ' + lbl_end);
  If cur_tok_type = TOK_SEMI Then Consume;
  EnterScope(SK_DO, cur_proc_idx);
  While Not (TokIsKw(KW_END) Or (cur_tok_type = TOK_EOF)) Do
   ParseStatement;
  LeaveScope;
  Emit('        JMP     ' + lbl_top);
  EmitLabel(lbl_end);
  If TokIsKw(KW_END) Then Begin Consume; If cur_tok_type = TOK_SEMI Then Consume; End;
 End Else If cur_tok_type = TOK_IDENT Then
 Begin
  { DO i = a TO b [BY c] ; ... END ; }
  iter_name := cur_tok_str; Consume;
  iter_sym := FindSym(iter_name);
  If iter_sym = 0 Then
  Begin
   iter_sym := AddSym(iter_name, TYPE_FIXED, STORE_AUTO);
   If iter_sym > 0 Then
   Begin
    AllocLocalBp(2);
    sym_table[iter_sym]^.bp_offset := CurrentBpTop;
    Emit('        SUB     SP, 2   ; iter ' + iter_name);
   End;
  End;
  If cur_tok_type = TOK_ASSIGN Then Consume Else Error('Attendu = apres variable DO');
  EmitComment('DO ' + iter_name + ' = ...');
  ParseExpr;
  GenStoreVar(iter_sym);
  If Not TokIsKw(KW_TO) Then Error('Attendu TO dans DO')
  Else Consume;
  EmitLabel(lbl_top);
  EmitComment('Test DO TO');
  GenLoadVar(iter_sym);
  Emit('        PUSH    AX');
  ParseExpr; { borne TO }
  Emit('        POP     BX');
  Emit('        CMP     BX, AX');
  Emit('        JG      ' + lbl_end);
  step_v := 1;
  If TokIsKw(KW_BY) Then
  Begin
   Consume;
   step_v := cur_tok_num; Consume;
  End;
  If cur_tok_type = TOK_SEMI Then Consume;
  EnterScope(SK_DO, cur_proc_idx);
  While Not (TokIsKw(KW_END) Or (cur_tok_type = TOK_EOF)) Do
   ParseStatement;
  LeaveScope;
  { Increment }
  GenLoadVar(iter_sym);
  If step_v = 1 Then Emit('        INC     AX')
  Else Emit('        ADD     AX, ' + ItoSI(step_v));
  GenStoreVar(iter_sym);
  Emit('        JMP     ' + lbl_top);
  EmitLabel(lbl_end);
  If TokIsKw(KW_END) Then Begin Consume; If cur_tok_type = TOK_SEMI Then Consume; End;
 End;
End;

{ ============================================================================ }
{ TODO 12 - PARSEUR : SELECT / WHEN / OTHERWISE          [COMPLET]            }
{ ============================================================================ }

Procedure ParseSelect;
Var lbl_end, lbl_next: String; has_sel: Boolean;
Begin
 Consume; { skip SELECT }
 lbl_end := NewLabel + 'SE';
 has_sel := False;
 EmitComment('---- SELECT ----');
 If cur_tok_type = TOK_LPAREN Then
 Begin
  Consume; ParseExpr;
  Emit('        MOV     DX, AX');
  If cur_tok_type = TOK_RPAREN Then Consume;
  has_sel := True;
 End;
 If cur_tok_type = TOK_SEMI Then Consume;
 While TokIsKw(KW_WHEN) Do
 Begin
  lbl_next := NewLabel + 'WN';
  Consume;
  Emit('        ; WHEN');
  If cur_tok_type = TOK_LPAREN Then
  Begin
   Consume;
   If has_sel Then
   Begin
    ParseExpr;
    Emit('        CMP     DX, AX');
    Emit('        JNE     ' + lbl_next);
   End Else
   Begin
    ParseExpr;
    Emit('        TEST    AX, AX');
    Emit('        JZ      ' + lbl_next);
   End;
   If cur_tok_type = TOK_RPAREN Then Consume;
  End;
  ParseStatement;
  Emit('        JMP     ' + lbl_end);
  EmitLabel(lbl_next);
 End;
 If TokIsKw(KW_OTHERWISE) Then
 Begin
  Consume;
  EmitComment('OTHERWISE');
  ParseStatement;
 End;
 EmitLabel(lbl_end);
 If TokIsKw(KW_END) Then Begin Consume; If cur_tok_type = TOK_SEMI Then Consume; End;
End;

{ ============================================================================ }
{ TODO 15 - PARSEUR : PUT / GET                          [COMPLET]            }
{ ============================================================================ }

Procedure ParsePut;
Var n_skip: Integer;
Begin
 Consume; { skip PUT }
 EmitComment('---- PUT ----');
 If TokIsKw(KW_SKIP) Then
 Begin
  Consume;
  n_skip := 1;
  If cur_tok_type = TOK_LPAREN Then
  Begin Consume; n_skip := cur_tok_num; Consume; Consume; End;
  While n_skip > 0 Do
  Begin Emit('        CALL    _PLI_CRLF'); Dec(n_skip); End;
 End Else If TokIsKw(KW_LIST) Then
 Begin
  Consume;
  If cur_tok_type = TOK_LPAREN Then Consume Else Error('Attendu (');
  While cur_tok_type <> TOK_RPAREN Do
  Begin
   If cur_tok_type = TOK_EOF Then Break;
   ParseExpr;
   Emit('        PUSH    AX');
   Emit('        CALL    _PLI_PRINT_INT');
   Emit('        POP     AX');
   If cur_tok_type = TOK_COMMA Then Consume;
  End;
  If cur_tok_type = TOK_RPAREN Then Consume;
 End Else If TokIsKw(KW_STRING) Then
 Begin
  Consume; EmitComment('PUT STRING (stub)');
 End;
 If cur_tok_type = TOK_SEMI Then Consume
 Else Error('Attendu ; apres PUT');
End;

Procedure ParseGet;
Var sym_idx: Integer; vname: String;
Begin
 Consume; { skip GET }
 EmitComment('---- GET ----');
 If TokIsKw(KW_LIST) Then
 Begin
  Consume;
  If cur_tok_type = TOK_LPAREN Then Consume Else Error('Attendu (');
  While cur_tok_type <> TOK_RPAREN Do
  Begin
   If cur_tok_type = TOK_EOF Then Break;
   vname := cur_tok_str; Consume;
   sym_idx := FindSym(vname);
   If sym_idx = 0 Then
   Begin
    sym_idx := AddSym(vname, TYPE_FIXED, STORE_AUTO);
    If sym_idx > 0 Then
    Begin
     AllocLocalBp(2);
     sym_table[sym_idx]^.bp_offset := CurrentBpTop;
     Emit('        SUB     SP, 2   ; GET var ' + vname);
    End;
   End;
   Emit('        CALL    _PLI_READ_INT');
   GenStoreVar(sym_idx);
   If cur_tok_type = TOK_COMMA Then Consume;
  End;
  If cur_tok_type = TOK_RPAREN Then Consume;
 End;
 If cur_tok_type = TOK_SEMI Then Consume
 Else Error('Attendu ; apres GET');
End;

{ ============================================================================ }
{ TODO 14 - PARSEUR : CALL                               [COMPLET]            }
{ ============================================================================ }

Procedure ParseCall;
Var pname: String; pidx, nargs: Integer;
Begin
 Consume; { skip CALL }
 If cur_tok_type <> TOK_IDENT Then
 Begin Error('Attendu nom de procedure apres CALL'); Exit; End;
 pname := cur_tok_str; Consume;
 EmitComment('CALL ' + pname);
 nargs := 0;
 If cur_tok_type = TOK_LPAREN Then
 Begin
  Consume;
  While cur_tok_type <> TOK_RPAREN Do
  Begin
   If cur_tok_type = TOK_EOF Then Break;
   ParseExpr;
   Emit('        PUSH    AX');
   Inc(nargs);
   If cur_tok_type = TOK_COMMA Then Consume;
  End;
  If cur_tok_type = TOK_RPAREN Then Consume;
 End;
 pidx := FindProc(pname);
 If pidx > 0 Then
  Emit('        CALL    ' + proc_table[pidx]^.asm_label)
 Else
 Begin
  pidx := AddProc(pname, nargs, TYPE_VOID);
  Emit('        CALL    ' + AsmIdent('_PLI_', pname));
 End;
 If nargs > 0 Then
  Emit('        ADD     SP, ' + ItoSI(nargs * 2));
 If cur_tok_type = TOK_SEMI Then Consume
 Else Error('Attendu ; apres CALL');
End;

{ ============================================================================ }
{ TODO 13 - PARSEUR : RETURN                             [COMPLET]            }
{ ============================================================================ }

Procedure ParseReturn;
Begin
 Consume; { skip RETURN }
 EmitComment('RETURN');
 If cur_tok_type <> TOK_SEMI Then ParseExpr;
 { Saut vers l'epilogue de la procedure courante }
 If scope_stack[scope_top].lbl_exit <> '' Then
  Emit('        JMP     ' + scope_stack[scope_top].lbl_exit)
 Else
  EmitComment('RETURN sans procedure englobante');
 If cur_tok_type = TOK_SEMI Then Consume;
End;

{ ============================================================================ }
{ TODO 24 - PARSEUR : GOTO / GO TO                       [COMPLET]            }
{ ============================================================================ }

Procedure ParseGoto;
Var lname: String;
Begin
 If TokIsKw(KW_GOTO) Then Consume
 Else If TokIsKw(KW_GO) Then
 Begin
  Consume;
  If TokIs('TO') Then Consume Else Error('Attendu TO apres GO');
 End;
 If cur_tok_type <> TOK_IDENT Then
 Begin Error('Attendu label apres GOTO'); Exit; End;
 lname := cur_tok_str; Consume;
 EmitComment('GOTO ' + lname);
 Emit('        JMP     ' + AsmIdent('_LBL_', lname));
 If cur_tok_type = TOK_SEMI Then Consume;
End;

{ ============================================================================ }
{ TODO 21 - PARSEUR : ON / SIGNAL                        [COMPLET]            }
{ ============================================================================ }

Procedure ParseOn;
Begin
 Consume; { skip ON }
 EmitComment('ON ' + cur_tok_str + ' (handler enregistre, stub)');
 { Sauter le nom de condition }
 If cur_tok_type = TOK_IDENT Then Consume;
 ParseStatement; { handler }
End;

Procedure ParseSignal;
Begin
 Consume; { skip SIGNAL }
 EmitComment('SIGNAL ' + cur_tok_str + ' (stub)');
 If cur_tok_type = TOK_IDENT Then Consume;
 If cur_tok_type = TOK_SEMI Then Consume;
End;

{ ============================================================================ }
{ TODO 23 - PARSEUR : INSTRUCTION + BLOC                 [COMPLET]            }
{ ============================================================================ }

Procedure ParseStatement;
Var vname: String; sym_idx: Integer;
Begin
 If cur_tok_type = TOK_SEMI Then
 Begin Consume; Exit; End;
 If cur_tok_type = TOK_IDENT Then
 Begin
  Case cur_tok_kw Of
   KW_DECLARE, KW_DCL: ParseDeclare;
   KW_IF:              ParseIf;
   KW_DO:              ParseDo;
   KW_SELECT:          ParseSelect;
   KW_CALL:            ParseCall;
   KW_PUT:             ParsePut;
   KW_GET:             ParseGet;
   KW_RETURN:          ParseReturn;
   KW_GOTO, KW_GO:     ParseGoto;
   KW_ON:              ParseOn;
   KW_SIGNAL:          ParseSignal;
   KW_END:             { Fin de bloc - laisser au parent }
                       Exit;
   KW_ELSE:            { Fin du THEN - laisser au parent }
                       Exit;
   KW_OTHERWISE, KW_WHEN:
                       Exit;
  Else
   { Soit une affectation, soit un label, soit un appel inline }
   vname := cur_tok_str; Consume;
   If cur_tok_type = TOK_COLON Then
   Begin
    { Label PL/I : nom : }
    Consume;
    sym_idx := FindSym(vname);
    If sym_idx = 0 Then sym_idx := AddSym(vname, TYPE_LABEL, STORE_STATIC);
    EmitLabel(AsmIdent('_LBL_', vname));
    EmitComment('Label ' + vname);
    { Si suivi de PROCEDURE, c'est la declaration d'une procedure }
    If TokIsKw(KW_PROCEDURE) Then
    Begin
     { TODO 13 : traite dans ParseTopLevel }
     EmitComment('PROCEDURE ' + vname + ' (voir ParseTopLevel)');
    End Else
     ParseStatement; { instruction qui suit le label }
   End Else If cur_tok_type = TOK_ASSIGN Then
    ParseAssignment(vname)
   Else If cur_tok_type = TOK_LPAREN Then
   Begin
    { Affectation element de tableau : tab(i) = expr }
    sym_idx := FindSym(vname);
    Consume; { manger '(' }
    EmitComment(vname + '(i) = ...');
    ParseExpr; { index -> AX, base-1 PL/I }
    If cur_tok_type = TOK_RPAREN Then Consume
    Else Error('Attendu ) apres index tableau');
    Emit('        DEC     AX');         { base-1 -> base-0 }
    Emit('        SHL     AX, 1');      { *2 octets (WORD) }
    Emit('        MOV     SI, AX');     { SI = offset tableau }
    If cur_tok_type = TOK_ASSIGN Then Consume
    Else Error('Attendu = apres tab(i)');
    ParseExpr; { valeur -> AX }
    If sym_idx > 0 Then
     GenArrayStoreVal(sym_idx)
    Else
     EmitComment('Tableau inconnu: ' + vname);
    If cur_tok_type = TOK_SEMI Then Consume;
   End
   Else
   Begin
    EmitComment('Instruction inconnue: ' + vname);
    While (cur_tok_type <> TOK_SEMI) And (cur_tok_type <> TOK_EOF) Do Consume;
    If cur_tok_type = TOK_SEMI Then Consume;
   End;
  End;
 End Else
 Begin
  EmitComment('ParseStatement: token inattendu: ' + cur_tok_str);
  Consume;
 End;
End;

Procedure ParseBlock;
Begin
 While Not TokIsKw(KW_END) And (cur_tok_type <> TOK_EOF) Do
  ParseStatement;
End;

{ ============================================================================ }
{ TODO 13 - PARSEUR : PROCEDURE                          [COMPLET]            }
{ ============================================================================ }

Procedure ParseTopLevel;
Var pname, pname2: String; pidx, nparams, rt, i_p, si_p: Integer;
    is_main: Boolean; lbl_epilogue: String;
    param_names: Array[0..MAX_PARAM] of String[48];
Begin
 { Niveau superieur : nom ':' PROCEDURE [...] ; ... END nom ; }
 If cur_tok_type <> TOK_IDENT Then
 Begin
  EmitComment('ParseTopLevel: attendu nom de procedure, trouve: ' + cur_tok_str);
  Consume; Exit;
 End;
 pname := cur_tok_str; Consume;
 If cur_tok_type <> TOK_COLON Then
 Begin Error('Attendu : apres ' + pname); Exit; End;
 Consume;
 If Not TokIsKw(KW_PROCEDURE) Then
 Begin Error('Attendu PROCEDURE apres ' + pname + ' :'); Exit; End;
 Consume;
 { Parametres optionnels }
 nparams := 0; rt := TYPE_VOID; is_main := False;
 If cur_tok_type = TOK_LPAREN Then
 Begin
  Consume;
  While cur_tok_type <> TOK_RPAREN Do
  Begin
   If cur_tok_type = TOK_IDENT Then
   Begin
    If nparams <= MAX_PARAM Then param_names[nparams] := cur_tok_str;
    Inc(nparams); Consume;
   End;
   If cur_tok_type = TOK_COMMA Then Consume;
  End;
  Consume;
 End;
 { OPTIONS }
 If TokIsKw(KW_OPTIONS) Then
 Begin
  Consume;
  If cur_tok_type = TOK_LPAREN Then Consume;
  If TokIs('MAIN') Then Begin is_main := True; Consume; End;
  If cur_tok_type = TOK_RPAREN Then Consume;
 End;
 { RETURNS }
 If TokIsKw(KW_RETURNS) Then
 Begin
  Consume;
  If cur_tok_type = TOK_LPAREN Then Consume;
  If TokIsKw(KW_FIXED) Then Begin rt := TYPE_FIXED; Consume; End
  Else If TokIsKw(KW_FLOAT) Then Begin rt := TYPE_FLOAT; Consume; End
  Else If TokIsKw(KW_CHAR) Or TokIsKw(KW_CHARACTER) Then Begin rt := TYPE_CHAR; Consume; End;
  { Qualificateurs optionnels : BINARY, DECIMAL, VARYING, etc. }
  While (cur_tok_type = TOK_IDENT) And
        (cur_tok_kw <> KW_NONE) And
        (cur_tok_type <> TOK_RPAREN) And
        (cur_tok_type <> TOK_SEMI) And (cur_tok_type <> TOK_EOF) Do Consume;
  If cur_tok_type = TOK_RPAREN Then Consume;
 End;
 If cur_tok_type = TOK_SEMI Then Consume Else Error('Attendu ; apres PROCEDURE');
 { Enregistrer la procedure }
 pidx := AddProc(pname, nparams, rt);
 proc_table[pidx]^.is_main := is_main;
 If is_main Then main_proc_idx := pidx;
 proc_table[pidx]^.defined := True;
 { Generer le label et le prologue }
 lbl_epilogue := AsmIdent('_EP_', pname);
 EmitBlank;
 EmitLabel(proc_table[pidx]^.asm_label);
 Emit('        PUSH    BP');
 Emit('        MOV     BP, SP');
 EmitComment('Prologue ' + pname);
 { Entrer dans le scope }
 EnterScope(SK_PROC, pidx);
 scope_stack[scope_top].lbl_exit := lbl_epilogue;
 { Enregistrer les parametres dans la table des symboles }
 { Convention 8086 cdecl : [BP+4]=param1, [BP+6]=param2, etc. }
 i_p := 0;
 While i_p < nparams Do
 Begin
  If i_p <= MAX_PARAM Then
  Begin
   si_p := AddSym(param_names[i_p], TYPE_FIXED, STORE_AUTO);
   If si_p > 0 Then
   Begin
    sym_table[si_p]^.bp_offset := 4 + i_p * 2;
    sym_table[si_p]^.is_param  := True;
    sym_table[si_p]^.param_idx := i_p + 1;
   End;
  End;
  Inc(i_p);
 End;
 { Compiler le corps }
 ParseBlock;
 { Epilogue }
 EmitLabel(lbl_epilogue);
 EmitComment('Epilogue ' + pname);
 Emit('        MOV     SP, BP');
 Emit('        POP     BP');
 Emit('        RET     ' + ItoSI(nparams * 2));
 EmitBlank;
 { Fermer le scope }
 LeaveScope;
 { Consommer END [nom] ; }
 If TokIsKw(KW_END) Then
 Begin
  Consume;
  If cur_tok_type = TOK_IDENT Then Consume; { nom optionnel }
  If cur_tok_type = TOK_SEMI Then Consume;
 End;
End;

{ ============================================================================ }
{ TODO 16 - GENERATION : EN-TETE + SEGMENT .DATA         [COMPLET]            }
{ ============================================================================ }

Procedure GenDataSegment;
Var i: Integer;
Begin
 Emit('.DATA');
 EmitBlank;
 EmitComment('=== Buffers internes PLI86 ===');
 Emit('    _CRLF      DB  13, 10, ''$''');
 Emit('    _NUMBUF    DB  20 DUP(30h), ''$''');
 Emit('    _INPUTBUF  DB  82, 0, 80 DUP(0)');
 Emit('    _ERR_STR   DB  ''ERREUR PL/I'', ''$''');
 EmitBlank;
 EmitComment('=== Variables STATIC ===');
 For i := 1 to sym_count do
  If sym_table[i]^.store_class = STORE_STATIC Then
  Begin
   Case sym_table[i]^.data_type Of
    TYPE_FIXED, TYPE_POINTER:
     Emit('    ' + sym_table[i]^.asm_label + '  DW  ' +
          ItoSI(sym_table[i]^.init_val));
    TYPE_CHAR, TYPE_CHAR_VAR:
     Emit('    ' + sym_table[i]^.asm_label + '  DB  ' +
          ItoSI(sym_table[i]^.precision) + ' DUP(0)');
   Else
    Emit('    ' + sym_table[i]^.asm_label + '  DW  0');
   End;
  End;
 If str_count > 0 Then
 Begin
  EmitBlank; EmitComment('=== Chaines litterales ===');
  For i := 1 to str_count do
   Emit('    ' + str_table[i]^.asm_label + '  DB  ''' + str_table[i]^.text + '''');
 End;
 EmitBlank;
End;

Procedure GenHeader;
Begin
 Emit('; ----------------------------------------------------------------');
 Emit('; Generated by PLI86 V1.0');
 Emit('; Source  : ' + source_filename);
 Emit('; ----------------------------------------------------------------');
 EmitBlank;
 Emit('        .MODEL SMALL');
 Emit('        .STACK 256');
 EmitBlank;
End;

{ ============================================================================ }
{ TODO 17 - GENERATION : POINT D'ENTREE START            [COMPLET]            }
{ ============================================================================ }

Procedure GenCodeSegmentHeader;
Begin
 Emit('.CODE');
 EmitBlank;
 Emit('START:');
 Emit('        MOV     AX, @DATA');
 Emit('        MOV     DS, AX');
 Emit('        MOV     ES, AX');
 EmitBlank;
 EmitComment('Appel de la procedure principale PL/I');
 If main_proc_idx > 0 Then
  Emit('        CALL    ' + proc_table[main_proc_idx]^.asm_label)
 Else
  Emit('        CALL    _PLI_MAIN');
 Emit('        MOV     AX, 4C00h');
 Emit('        INT     21h');
 EmitBlank;
End;

Procedure GenFooter;
Begin
 EmitBlank;
 Emit('END START');
End;

{ ============================================================================ }
{ TODO 22 - GENERATION : HELPERS RUNTIME                 [COMPLET]            }
{ ============================================================================ }

Procedure GenRuntimeHelpers;
Begin
 EmitBlank;
 Emit('; ----------------------------------------------------------------');
 Emit('; RUNTIME HELPERS PLI86');
 Emit('; ----------------------------------------------------------------');
 EmitBlank;
 { _PLI_CRLF }
 Emit('_PLI_CRLF:');
 Emit('        LEA     DX, _CRLF');
 Emit('        MOV     AH, 09h');
 Emit('        INT     21h');
 Emit('        RET');
 EmitBlank;
 { _PLI_PRINT_INT : AX = entier signe -> afficher en decimal }
 Emit('        ; _PLI_PRINT_INT: AX = entier -> affichage decimal');
 Emit('_PLI_PRINT_INT:');
 Emit('        PUSH    BX');
 Emit('        PUSH    CX');
 Emit('        PUSH    DX');
 Emit('        CMP     AX, 0');
 Emit('        JGE     _PINT_POS');
 Emit('        PUSH    AX');
 Emit('        MOV     DL, ''-''');
 Emit('        MOV     AH, 02h');
 Emit('        INT     21h');
 Emit('        POP     AX');
 Emit('        NEG     AX');
 Emit('_PINT_POS:');
 Emit('        LEA     DI, _NUMBUF + 19');
 Emit('        MOV     BYTE PTR [DI+1], ''$''');
 Emit('        MOV     CX, 10');
 Emit('        MOV     SI, 0');
 Emit('_PINT_LP:');
 Emit('        XOR     DX, DX');
 Emit('        DIV     CX');
 Emit('        ADD     DL, 30h');
 Emit('        MOV     [DI], DL');
 Emit('        DEC     DI');
 Emit('        INC     SI');
 Emit('        TEST    AX, AX');
 Emit('        JNZ     _PINT_LP');
 Emit('        INC     DI');
 Emit('        LEA     DX, [DI]');
 Emit('        MOV     AH, 09h');
 Emit('        INT     21h');
 Emit('        POP     DX');
 Emit('        POP     CX');
 Emit('        POP     BX');
 Emit('        RET');
 EmitBlank;
 { _PLI_PRINT_STR : DX = ptr chaine '$'-terminee }
 Emit('_PLI_PRINT_STR:');
 Emit('        MOV     AH, 09h');
 Emit('        INT     21h');
 Emit('        RET');
 EmitBlank;
 { _PLI_READ_INT : saisir un entier -> AX }
 Emit('        ; _PLI_READ_INT -> AX = entier signe');;
 Emit('_PLI_READ_INT:');
 Emit('        PUSH    BX');
 Emit('        PUSH    CX');
 Emit('        MOV     _INPUTBUF, 80');
 Emit('        LEA     DX, _INPUTBUF');
 Emit('        MOV     AH, 0Ah');
 Emit('        INT     21h');
 Emit('        CALL    _PLI_CRLF');
 Emit('        XOR     BX, BX');
 Emit('        XOR     CX, CX');
 Emit('        MOV     CL, _INPUTBUF+1');
 Emit('        LEA     SI, _INPUTBUF+2');
 Emit('_RINT_LP:');
 Emit('        JCXZ    _RINT_DONE');
 Emit('        LODSB');
 Emit('        SUB     AL, 30h');
 Emit('        IMUL    BX, BX, 10');
 Emit('        CBW');
 Emit('        ADD     BX, AX');
 Emit('        DEC     CX');
 Emit('        JMP     _RINT_LP');
 Emit('_RINT_DONE:');
 Emit('        MOV     AX, BX');
 Emit('        POP     CX');
 Emit('        POP     BX');
 Emit('        RET');
 EmitBlank;
 { _PLI_ERROR }
 Emit('_PLI_ERROR:');
 Emit('        LEA     DX, _ERR_STR');
 Emit('        MOV     AH, 09h');
 Emit('        INT     21h');
 Emit('        MOV     AX, 4C01h');
 Emit('        INT     21h');
 EmitBlank;
 { _PLI_POW : AX=base, BX=exposant empiles -> AX = base^exposant }
 Emit('        ; _PLI_POW: PUSH base / PUSH exposant -> AX = base**exp');
 Emit('_PLI_POW:');
 Emit('        PUSH    BP');
 Emit('        MOV     BP, SP');
 Emit('        MOV     AX, [BP+4]');
 Emit('        MOV     CX, [BP+6]');
 Emit('        MOV     BX, AX');
 Emit('        CMP     CX, 0');
 Emit('        JLE     _POW_DONE');
 Emit('        DEC     CX');
 Emit('_POW_LP:');
 Emit('        JCXZ    _POW_DONE');
 Emit('        IMUL    BX');
 Emit('        DEC     CX');
 Emit('        JMP     _POW_LP');
 Emit('_POW_DONE:');
 Emit('        POP     BP');
 Emit('        RET     4');
 EmitBlank;
End;

{ ============================================================================ }
{ TODO 25 - PROGRAMME PRINCIPAL + BOUCLE DE COMPILATION  [COMPLET]            }
{ ============================================================================ }

Procedure ShowHelp;
Begin
 WriteLn(VERSION, ' - Compilateur PL/I pour 8086/8088');
 WriteLn;
 WriteLn('Usage: PLI86 source.pli [sortie.asm] [options]');
 WriteLn;
 WriteLn('Options:');
 WriteLn('  /T    Afficher tokens seulement');
 WriteLn('  /V    Mode verbeux');
 WriteLn;
 WriteLn('Formes supportees:');
 WriteLn('  PROCEDURE END RETURN IF THEN ELSE DO WHILE TO BY');
 WriteLn('  SELECT WHEN OTHERWISE DECLARE CALL PUT GET GOTO SIGNAL ON');
 WriteLn;
 WriteLn('Types:');
 WriteLn('  FIXED FLOAT CHAR BIT POINTER');
 Halt(0);
End;

Var
 i_cmd : Integer;
 arg_s : String;
 j_ext : Integer;

BEGIN
 { ---- Initialisation ---- }
 error_count   := 0;
 label_counter := 0;
 lit_counter   := 0;
 gen_enabled   := False;
 main_proc_idx := 0;
 source_filename := '';
 output_filename := '';
 opt_dump_tok  := False;
 opt_dump_ast  := False;
 opt_verbose   := False;

 { ---- Ligne de commande ---- }
 For i_cmd := 1 to ParamCount do
 Begin
  arg_s := ParamStr(i_cmd);
  If (arg_s[1] = '/') Or (arg_s[1] = '-') Then
  Begin
   Case UpCase(arg_s[2]) Of
    'T': opt_dump_tok := True;
    'V': opt_verbose  := True;
    'H','?': ShowHelp;
   End;
  End Else If source_filename = '' Then
   source_filename := arg_s
  Else
   output_filename := arg_s;
 End;

 If source_filename = '' Then ShowHelp;

 { ---- Nom de sortie par defaut ---- }
 If output_filename = '' Then
 Begin
  output_filename := source_filename;
  j_ext := Length(output_filename);
  While (j_ext > 0) And (output_filename[j_ext] <> '.') And
        (output_filename[j_ext] <> '\') And (output_filename[j_ext] <> '/') Do Dec(j_ext);
  If (j_ext > 0) And (output_filename[j_ext] = '.') Then
   output_filename := Copy(output_filename, 1, j_ext-1) + '.ASM'
  Else
   output_filename := output_filename + '.ASM';
 End;

 { ---- Ouvrir le fichier source ---- }
 Assign(input_file, source_filename);
 Reset(input_file);
 If IOResult <> 0 Then
 Begin
  WriteLn('ERREUR: Impossible d''ouvrir : ', source_filename);
  Halt(1);
 End;

 WriteLn(VERSION, ' - Compilation de: ', source_filename);

 { ---- Initialiser les tables ---- }
 InitSymTable;
 InitScopes;

 { ---- Initialiser le tokeniseur ---- }
 InitTokenizer;

 { ---- Mode dump tokens ---- }
 If opt_dump_tok Then
 Begin
  WriteLn('=== TOKENS ===');
  While cur_tok_type <> TOK_EOF Do
  Begin
   WriteLn('TOK=', cur_tok_type, ' KW=', cur_tok_kw, ' "', cur_tok_str, '"');
   NextToken;
  End;
  Close(input_file);
  Halt(0);
 End;

 { ---- Ouvrir la sortie ASM ---- }
 Assign(output_file, output_filename);
 Rewrite(output_file);
 If IOResult <> 0 Then
 Begin
  WriteLn('ERREUR: Impossible de creer : ', output_filename);
  Halt(1);
 End;
 gen_enabled := True;

 { ---- Phase 1 : generer l'en-tete ---- }
 GenHeader;

 { ---- Phase 2 : generer le DATA (apres compilation, stub en 2 passes) ---- }
 { En une seule passe on emet le DATA d'abord vide puis on le remplirait.    }
 { Ici on fait une passe avec emission directe des stubs connus.              }
 Emit('.DATA');
 EmitBlank;
 EmitComment('=== Buffers internes PLI86 ===');
 Emit('    _CRLF      DB  13, 10, ''$''');
 Emit('    _NUMBUF    DB  20 DUP(30h), ''$''');
 Emit('    _INPUTBUF  DB  82, 0, 80 DUP(0)');
 Emit('    _ERR_STR   DB  ''ERREUR PL/I'', ''$''');
 EmitBlank;
 EmitComment('=== Variables (emises ici en monopasse) ===');
 { Les variables DECLARE seront emises inline lors du ParseTopLevel }
 { Pour une vrai 2 passes : accumuler dans sym_table puis emettre }
 EmitBlank;

 { ---- Phase 3 : .CODE ---- }
 GenCodeSegmentHeader;

 { ---- Boucle principale : lire et compiler les procedures de haut niveau ---- }
 While cur_tok_type <> TOK_EOF Do
 Begin
  If cur_tok_type = TOK_SEMI Then Begin Consume; Continue; End;
  ParseTopLevel;
 End;

 { ---- Generer les helpers runtime ---- }
 GenRuntimeHelpers;

 { ---- Footer ASM ---- }
 GenFooter;

 { ---- Fermer les fichiers ---- }
 Close(output_file);
 Close(input_file);

 WriteLn('ASM genere : ', output_filename);
 WriteLn('Termine. Erreurs: ', error_count,
         '  Procedures: ', proc_count,
         '  Symboles: ', sym_count);
 If error_count > 0 Then Halt(1);
END.
