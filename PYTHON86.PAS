{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Python vers assembleur 8086
}

(* ============================================================
  PYTHON86.PAS - Compilateur Python vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  Voir DOC/TODO/PYTHON86.txt
  ============================================================ *)

Program PYTHON86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES GLOBALES
  ============================================================ }
Const
  PYTHON86_VERSION = '1.0';
  PYTHON86_DATE    = '2026-03-06';

  { Limites des tableaux internes }
  MAX_SYM        = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_LABEL      = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE      = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA       = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_TYPE       = {$IFDEF FPC}32{$ELSE}16{$ENDIF};
  MAX_PARAM      = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST  = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_TRY_NEST   = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_COMP_BUF   = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_ERRORS     = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR        = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  STACK_SIZE     = 1024;
  MAX_INDENT     = 64;     { profondeur max de l indentation        }
  MAX_DEDENT_Q   = 32;     { nombre max de DEDENT en attente        }
  MAX_HASH_PAIRS = 64;     { nombre max de paires par dict           }
  MAX_CLASS      = 32;     { nombre max de classes                    }
  MAX_CLS_ATTR   = 16;     { nombre max d attributs par classe        }
  MAX_CLS_METH   = 16;     { nombre max de methodes par classe        }
  MAX_IMPORT     = 16;     { nombre max de modules importes (TODO 23) }

  { Prefixes de nommage ASM }
  PY_VAR_PFX  = '_PYV_';    { variable globale/locale              }
  PY_FN_PFX   = '_PYF_';    { fonction def                         }
  PY_STR_PFX  = '_PYK_';    { constante chaine litterale           }
  PY_RT_PFX   = '_PYRT_';   { routine runtime                      }
  PY_LBL_PFX  = '_PYL_';    { label de saut interne                }
  PY_CLS_PFX  = '_PYC_';    { classe / vtable                      }
  PY_MTH_PFX  = '_PYM_';    { methode                              }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Indices de types primitifs Python (TODO 03) }
  TY_IDX_INT   = 0;   { entier 16 bits signe       }
  TY_IDX_STR   = 1;   { pointeur chaine DATA       }
  TY_IDX_BOOL  = 2;   { 0 ou 1 dans AX             }
  TY_IDX_NONE  = 3;   { None : AX=0                }
  TY_IDX_LIST  = 4;   { pointeur bloc DATA          }
  TY_IDX_DICT  = 5;   { pointeur bloc DATA          }
  TY_IDX_FUNC  = 6;   { pointeur de code            }
  TY_IDX_CLASS = 7;   { pointeur vtable             }
  TY_IDX_TUPLE = 8;   { pointeur tuple immutable    }
  TY_IDX_MODULE= 9;   { module importe (TODO 23)    }
  TY_PRIM_COUNT = 10;
  TY_UNKNOWN   = -1;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;   { fichier source Python (.py)           }
    OutFile   : TString;   { fichier assembleur de sortie (.asm)   }
    Verbose   : Boolean;   { -v : banniere et statistiques         }
    DebugMode : Boolean;   { -d : affichage de chaque token        }
    Warnings  : Boolean;   { -w : activer les avertissements       }
  End;

  { ---- Tokens Python (TODO 02) ---------------------------- }
  TTokenKind = (
    TK_EOF,       { fin de fichier                          }
    TK_NEWLINE,   { fin de ligne logique                    }
    TK_INDENT,    { augmentation d indentation              }
    TK_DEDENT,    { diminution d indentation                }
    TK_INTEGER,   { literal entier 42 0xFF 0o17 0b101       }
    TK_FLOAT,     { literal flottant 3.14 1.5e3             }
    TK_STRING,    { literal chaine 'abc' ou "abc"           }
    TK_IDENT,     { identificateur (non-mot-cle)            }
    TK_KEYWORD,   { mot-cle Python reconnu                  }
    TK_OP,        { operateur + - * / == != etc.            }
    TK_PUNCT      { ponctuation , ( ) : . etc.              }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;     { valeur textuelle brute          }
    IntVal   : LongInt;     { valeur entiere (TK_INTEGER)     }
    FloatVal : Real;        { valeur flottante (TK_FLOAT)     }
    Line     : Integer;     { ligne source (1-base)           }
    Col      : Integer;     { colonne source (1-base)         }
  End;

  { ---- Valeurs d expression (TODO 03) ---------------------- }
  TExprKind = (
    EK_NONE,   { void / pas de valeur                      }
    EK_IMM,    { valeur immediate dans ImmVal               }
    EK_AX,     { valeur dans le registre AX                 }
    EK_MEM     { adresse memoire [BP+Offset] ou [_PYV_x]   }
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;   { indice type primitif            }
    Offset  : Integer;   { offset donnee/pile              }
    SymIdx  : Integer;   { indice SymTab (-1 = pas lvalue) }
  End;

  { ---- Segment de donnees (TODO 03) ------------------------ }
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY_BLK, DK_LIST, DK_DICT, DK_TUPLE);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;
  End;

  { ---- Table des symboles (TODO 05) ------------------------- }
  TSymKind = (
    SK_VAR,       { variable (globale ou locale)               }
    SK_PARAM,     { parametre de fonction                      }
    SK_FUNC,      { fonction def                               }
    SK_CLASS,     { classe class                               }
    SK_MODULE,    { module importe                             }
    SK_BUILTIN,   { builtin (print, len, int, str ...)         }
    SK_GLOBAL,    { marqueur global (instruction global x)     }
    SK_LOCAL      { variable locale explicite                  }
  );

  TSymRec = Record
    Name        : TString;     { nom Python original              }
    MangledName : TString;     { label ASM (_PYV_x, _PYF_f ...)  }
    Kind        : TSymKind;
    TypeIdx     : Integer;     { indice type primitif (-1=unknown)}
    Offset      : Integer;     { offset pile BP- (locaux/params)  }
    ScopeLevel  : Integer;     { niveau de portee (0=global)      }
    IsGlobal    : Boolean;     { instruction global -> True       }
    IsNonlocal  : Boolean;     { instruction nonlocal -> True     }
    IsImported  : Boolean;     { importation from module (TODO 23)}
    DeclLine    : Integer;     { ligne de declaration (debug)     }
  End;

  { ---- Systeme de types dynamique (TODO 06) ------------------ }
  TTypeKind = (
    TYK_INT,       { entier 16 bits signe                     }
    TYK_BOOL,      { booleen (0 ou 1)                         }
    TYK_STR,       { pointeur chaine terminee par 0           }
    TYK_NONE,      { None : valeur nulle                      }
    TYK_LIST,      { pointeur tableau dynamique               }
    TYK_DICT,      { pointeur table de hachage                }
    TYK_TUPLE,     { pointeur tableau fixe (immutable)        }
    TYK_FUNC,      { pointeur de code (fonction)              }
    TYK_OBJECT,    { pointeur instance de classe              }
    TYK_CLASS,     { descripteur de classe                    }
    TYK_UNKNOWN    { type indetermine                         }
  );

  TTypeRec = Record
    Name : TString;    { nom Python du type (int, str, ...) }
    Kind : TTypeKind;  { categorie de type                  }
    Size : Integer;    { taille en octets (2=mot, 0=void)   }
  End;

  { ---- Classes (TODO 18) -------------------------------------- }
  TClassRec = Record
    Name       : TString;       { nom Python de la classe          }
    ParentIdx  : Integer;       { index parent dans ClassTab (-1)  }
    AttrCount  : Integer;       { nombre d attributs d instance    }
    AttrNames  : Array[0..MAX_CLS_ATTR - 1] Of TString;
    MethCount  : Integer;       { nombre de methodes               }
    MethNames  : Array[0..MAX_CLS_METH - 1] Of TString;
    MethLabels : Array[0..MAX_CLS_METH - 1] Of TString;
    ObjSize    : Integer;       { taille instance : 2 + AttrCount*2 }
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  { Options de compilation }
  Opts       : TOptions;

  { Compteurs generaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;
  TotalSyms  : Integer;

  { Lexeur (TODO 02) }
  LexSrcF    : Text;
  LexLine    : String;
  LexLineNo  : Integer;
  LexColNo   : Integer;
  LexEOF     : Boolean;
  LexOpened  : Boolean;
  CurToken   : TToken;

  { Pile d indentation }
  IndentStack : Array[0..MAX_INDENT - 1] Of Integer;
  IndentTop   : Integer;   { indice du sommet (0 = base = colonne 0) }
  DedentQueue : Integer;   { nombre de DEDENT en attente              }
  AtLineStart : Boolean;   { True = debut de ligne logique (indent)   }
  ParenDepth  : Integer;   { >0 = dans paren/crochet -> pas NEWLINE }

  { Segment de donnees (TODO 03) }
  DataTab     : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount   : Integer;
  LabelGenSeq : Integer;   { compteur pour labels uniques _PYL_N }
  GExprDummy  : TExprVal;  { valeur fictive pour ignorer un retour }

  { Fichier de sortie (TODO 03) }
  OutF        : Text;
  OutFOpen    : Boolean;

  { Table des symboles (TODO 05) }
  SymTab      : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount    : Integer;
  ScopeStack  : Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeTop    : Integer;    { sommet de la pile des portees }
  CurScope    : Integer;    { niveau de portee courant (0 = global) }

  { Systeme de types (TODO 06) }
  TypeTab     : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount   : Integer;

  { Pile de boucles (TODO 14) }
  LoopBreakStack : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContStack  : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopElseStack  : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopTop        : Integer;

  { Pile de try/except (TODO 21) }
  TryExceptStack  : Array[0..MAX_TRY_NEST - 1] Of TString;
  TryFinallyStack : Array[0..MAX_TRY_NEST - 1] Of TString;
  TryEndStack     : Array[0..MAX_TRY_NEST - 1] Of TString;
  TryTop          : Integer;

  { Buffer de code pour comprehensions (TODO 22) }
  CompBuf       : Array[1..MAX_COMP_BUF] Of TString;
  CompBufCount  : Integer;
  CompBufActive : Boolean;

  { Gestion des fonctions (TODO 17) }
  FuncRetLabel   : TString;    { label d epilogue pour return       }
  FuncLocalsSize : Integer;    { taille des locaux en octets        }
  InFunction     : Boolean;    { True si on compile le corps d un def }

  { Gestion des classes (TODO 18) }
  ClassTab       : Array[0..MAX_CLASS - 1] Of TClassRec;
  ClassCount     : Integer;    { nombre de classes enregistrees        }
  InClass        : Boolean;    { True si on compile le corps d une class }
  CurClassIdx    : Integer;    { index classe courante dans ClassTab   }

  { Table des modules importes (TODO 23) }
  ImportTab      : Array[0..MAX_IMPORT - 1] Of TString;
  ImportCount    : Integer;    { nombre de modules importes            }

  { Flag runtime minimal (TODO 24) }
  RuntimeEmitted : Boolean;    { True si runtime deja emis             }

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
Procedure LexInit;             Forward;
Procedure LexClose;            Forward;
Function  IsKeyword(Const S : TString) : Boolean; Forward;
Procedure PrintToken(Const T : TToken); Forward;
Procedure LexNextLine;         Forward;
Function  IsIdentStart(Ch : Char) : Boolean; Forward;
Function  IsIdentCont(Ch : Char) : Boolean; Forward;
Function  IsHexDigit(Ch : Char) : Boolean; Forward;
Function  HexVal(Ch : Char) : Integer; Forward;
Procedure LexScanIdent;        Forward;
Procedure LexScanNumber;       Forward;
Function  LexScanEscChar : Char; Forward;
Procedure LexScanString(Quote : Char; Triple : Boolean); Forward;
Procedure LexNextToken;        Forward;
Procedure ParserAdvance;       Forward;
{ TODO 03 - Forward declarations litteraux et constantes }
Function  LabelGen : TString;  Forward;
Procedure EmitRaw(Const S : String); Forward;
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                  AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : TString; Forward;
Function  DataAddWord(Const Lbl : TString;
                      AIntVal : LongInt) : Integer; Forward;
{ TODO 08 - Forward declarations segment de donnees }
Function  DataAddList(Const Lbl : TString;
                      AElemCount : Integer) : Integer; Forward;
Function  DataAddDict(Const Lbl : TString;
                      APairCount : Integer) : Integer; Forward;
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ExprMakeNone(Var Res : TExprVal); Forward;
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal); Forward;
Procedure ExprMakeAX(ATypeIdx : Integer; Var Res : TExprVal); Forward;
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEvalStr(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
Procedure EmitOpen;            Forward;
Procedure EmitHeader;          Forward;
Procedure EmitDataSeg;         Forward;
Procedure EmitClose;           Forward;
{ TODO 07 - Forward declarations emetteur de code ASM }
Procedure EmitProlog(FrameSize : Integer);  Forward;
Procedure EmitEpilog;                       Forward;
{ TODO 04 - Forward declarations operateurs et precedence }
Procedure EmitInstr(Const S : TString);      Forward;
Procedure EmitLabel(Const Lbl : TString);    Forward;
Procedure EmitComment(Const Msg : TString);  Forward;
Procedure EmitBlankLine;                     Forward;
Function  BinOpPrec(Const Op : TString) : Integer; Forward;
Function  BinOpIsRight(Const Op : TString) : Boolean; Forward;
Function  IsAssignOp(Const Op : TString) : Boolean; Forward;
Procedure ExprFlushToAX(Var E : TExprVal);   Forward;
Procedure ExprEmitBinOp(Const Op : TString;
            Var L : TExprVal; Var R : TExprVal); Forward;
Procedure ParsePrimary(Var Res : TExprVal);  Forward;
Procedure ParseUnary(Var Res : TExprVal);    Forward;
Procedure ParseExprPrec(MinPrec : Integer;
            Var Res : TExprVal);             Forward;
Procedure ParseExpr(Var Res : TExprVal);     Forward;
{ TODO 05 - Forward declarations table des symboles }
Function  SymNameClean(Const Name : TString) : TString; Forward;
Function  SymMangle(Const Name : TString; Kind : TSymKind) : TString; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindInScope(Const Name : TString;
            Level : Integer) : Integer; Forward;
Function  SymAdd(Const Name : TString; Kind : TSymKind;
            TypeIdx, Offset : Integer) : Integer; Forward;
Procedure SymEnterScope;     Forward;
Procedure SymLeaveScope;     Forward;
Procedure SymInit;           Forward;
{ TODO 06 - Forward declarations systeme de types }
Procedure TypeInit;          Forward;
Function  TypeKindOf(TypeIdx : Integer) : TTypeKind; Forward;
Function  TypeSizeof(TypeIdx : Integer) : Integer; Forward;
Function  TypeFindByName(Const Name : TString) : Integer; Forward;
Function  TypeKindStr(K : TTypeKind) : TString; Forward;
Function  TypeIdxFromExpr(Const E : TExprVal) : Integer; Forward;
{ TODO 09 - Forward declarations variables et affectations }
Procedure ExprLoadToAX(SIdx : Integer);    Forward;
Procedure EmitStoreVar(SIdx : Integer);    Forward;
Procedure EnsureVarInData(SIdx : Integer); Forward;
Procedure ParseAssign(FirstSymIdx : Integer); Forward;
{ TODO 10 - Forward declarations expressions primaires }
Procedure ParseCallArgs(SIdx : Integer; Var Res : TExprVal); Forward;
Procedure EmitBuiltinCall(SIdx : Integer; ArgTypeIdx : Integer;
                         Var Res : TExprVal); Forward;
Procedure ParseListLiteral(Var Res : TExprVal);  Forward;
Procedure ParseDictLiteral(Var Res : TExprVal);  Forward;
{ TODO 11 - Forward declarations expressions binaires }
Procedure EmitExprRuntime;  Forward;
{ TODO 12 - Forward declarations entrees/sorties }
Procedure EmitIORuntime;  Forward;
{ TODO 13 - Forward declarations if/elif/else }
Procedure ParseBlock;    Forward;
Procedure ParseIfStmt;   Forward;
{ TODO 14 - Forward declarations boucles }
Procedure ParseWhileStmt; Forward;
Procedure ParseForStmt;   Forward;
{ TODO 15 - Forward declaration runtime listes }
Procedure EmitListRuntime; Forward;
{ TODO 16 - Forward declaration runtime dicts }
Procedure EmitDictRuntime; Forward;
{ TODO 17 - Forward declarations fonctions }
Procedure ParseDefStmt;    Forward;
Procedure ParseReturnStmt; Forward;
{ TODO 18 - Forward declarations classes }
Procedure ParseClassStmt;   Forward;
Procedure EmitClassRuntime;  Forward;
Function  ClassFind(Const Name : TString) : Integer; Forward;
Function  ClassFindAttr(ClsIdx : Integer; Const AName : TString) : Integer; Forward;
Function  ClassFindMeth(ClsIdx : Integer; Const MName : TString) : Integer; Forward;
{ TODO 19 - Forward declarations tuples }
Procedure ParseTupleLiteral(Var Res : TExprVal); Forward;
Procedure EmitTupleRuntime; Forward;
{ TODO 20 - Forward declaration runtime chaines avancees }
Procedure EmitStrRuntime; Forward;
{ TODO 21 - Forward declarations exceptions }
Procedure ParseTryStmt;   Forward;
Procedure ParseRaiseStmt; Forward;
{ TODO 22 - Forward declarations comprehensions }
Procedure ParseListComprehension(Var Res : TExprVal);  Forward;
Procedure ParseDictComprehension(Var Res : TExprVal);  Forward;
{ TODO 23 - Forward declarations modules et import }
Procedure ParseImportStmt;     Forward;
Procedure ParseFromImportStmt; Forward;
{ TODO 24 - Forward declaration runtime minimal }
Procedure EmitMinimalRuntime;  Forward;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- Messages d erreur et d avertissement ---------------- }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('PYTHON86: FATAL: ', Msg);
  Halt(EXIT_ERROR);
End;

Procedure CompileError(Const Msg : TString; Line : Integer);
Begin
  Write('PYTHON86:');
  If Line > 0 Then
    Write(Opts.SrcFile, ':', Line, ': ');
  WriteLn('error: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, compilation arretee');
End;

Procedure WarnMsg(Const Msg : TString; Line : Integer);
Begin
  If Not Opts.Warnings Then Exit;
  Write('PYTHON86:');
  If Line > 0 Then
    Write(Opts.SrcFile, ':', Line, ': ');
  WriteLn('warning: ', Msg);
  Inc(WarnCount);
End;

{ ---- Banniere ---------------------------------------------- }

Procedure ShowBanner;
Begin
  WriteLn('PYTHON86 v', PYTHON86_VERSION, ' (', PYTHON86_DATE, ')');
  WriteLn('Compilateur Python -> assembleur 8086 (MASM .MODEL SMALL)');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('Usage: PYTHON86 <source.py> [sortie.asm] [-v] [-d] [-w]');
  WriteLn;
  WriteLn('  source.py  : fichier Python source');
  WriteLn('  sortie.asm : fichier assembleur de sortie (defaut: source.asm)');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn('  -h, --help : cette aide');
  WriteLn;
  Halt(EXIT_USAGE);
End;

Procedure ShowStats;
Begin
  WriteLn('Compilation terminee : ', Opts.SrcFile, ' -> ', Opts.OutFile);
  WriteLn('  Lignes         : ', TotalLines);
  WriteLn('  Symboles       : ', TotalSyms);
  WriteLn('  Erreurs        : ', ErrorCount);
  WriteLn('  Avertissements : ', WarnCount);
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

{ Extrait le nom de base d un chemin (sans repertoire ni extension) }
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
    Else If (Arg = '-v') Or (Arg = '--verbose') Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('PYTHON86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('PYTHON86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('PYTHON86: fichier source manquant');
    ShowUsage;
  End;

  If Opts.OutFile = '' Then
    Opts.OutFile := ReplaceExt(Opts.SrcFile, '.asm');
End;

{ ---- Nettoyage des ressources ------------------------------ }

Procedure Cleanup;
Begin
  If LexOpened Then LexClose;
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ---- Initialisation generale des variables globales -------- }

Procedure GlobalInit;
Begin
  ErrorCount  := 0;
  WarnCount   := 0;
  TotalLines  := 0;
  TotalSyms   := 0;
  LexOpened   := False;
  LexEOF      := False;
  LexLineNo   := 0;
  LexColNo    := 1;
  LexLine     := '';
  IndentTop   := 0;
  IndentStack[0] := 0;
  DedentQueue := 0;
  AtLineStart := True;
  ParenDepth  := 0;
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.FloatVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
  { TODO 03 : segment de donnees et sortie }
  DataCount   := 0;
  LabelGenSeq := 0;
  OutFOpen    := False;
  GExprDummy.Kind    := EK_NONE;
  GExprDummy.ImmVal  := 0;
  GExprDummy.TypeIdx := TY_UNKNOWN;
  GExprDummy.Offset  := 0;
  GExprDummy.SymIdx  := -1;
  { TODO 05 : table des symboles }
  SymCount  := 0;
  ScopeTop  := 0;
  CurScope  := 0;
  { TODO 14 : pile de boucles }
  LoopTop   := 0;
  { TODO 21 : exceptions }
  TryTop    := 0;
  { TODO 17 : fonctions }
  FuncRetLabel   := '';
  FuncLocalsSize := 0;
  InFunction     := False;
  { TODO 18 : classes }
  ClassCount  := 0;
  InClass     := False;
  CurClassIdx := -1;
  { TODO 22 : comprehensions }
  CompBufActive := False;
  CompBufCount  := 0;
  { TODO 23 : modules et import }
  ImportCount := 0;
  { TODO 24 : runtime minimal }
  RuntimeEmitted := False;
End;

{ ============================================================
  TODO 02 - LEXEUR (TOKENS PYTHON) [IMPLEMENTE]
  ============================================================ }

{ ---- IsKeyword : teste si S est un mot-cle Python ---------- }
Function IsKeyword(Const S : TString) : Boolean;
Begin
  IsKeyword :=
    (S = 'False')    Or (S = 'None')     Or (S = 'True')      Or
    (S = 'and')      Or (S = 'as')       Or (S = 'assert')    Or
    (S = 'async')    Or (S = 'await')    Or (S = 'break')     Or
    (S = 'class')    Or (S = 'continue') Or (S = 'def')       Or
    (S = 'del')      Or (S = 'elif')     Or (S = 'else')      Or
    (S = 'except')   Or (S = 'finally')  Or (S = 'for')       Or
    (S = 'from')     Or (S = 'global')   Or (S = 'if')        Or
    (S = 'import')   Or (S = 'in')       Or (S = 'is')        Or
    (S = 'lambda')   Or (S = 'nonlocal') Or (S = 'not')       Or
    (S = 'or')       Or (S = 'pass')     Or (S = 'raise')     Or
    (S = 'return')   Or (S = 'try')      Or (S = 'while')     Or
    (S = 'with')     Or (S = 'yield');
End;

{ ---- PrintToken : affichage debug d un token --------------- }
Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF     : Write('EOF');
    TK_NEWLINE : Write('NEWLINE');
    TK_INDENT  : Write('INDENT');
    TK_DEDENT  : Write('DEDENT');
    TK_INTEGER : Write('INT(', T.IntVal, ')');
    TK_FLOAT   : Write('FLOAT(', T.Val, ')');
    TK_STRING  : Write('STR(''', T.Val, ''')');
    TK_IDENT   : Write('IDENT(', T.Val, ')');
    TK_KEYWORD : Write('KW(', T.Val, ')');
    TK_OP      : Write('OP(', T.Val, ')');
    TK_PUNCT   : Write('PUNCT(', T.Val, ')');
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

{ ---- Test de caracteres ------------------------------------- }

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

Function IsHexDigit(Ch : Char) : Boolean;
Begin
  IsHexDigit := ((Ch >= '0') And (Ch <= '9')) Or
                ((Ch >= 'A') And (Ch <= 'F')) Or
                ((Ch >= 'a') And (Ch <= 'f'));
End;

Function HexVal(Ch : Char) : Integer;
Begin
  If (Ch >= '0') And (Ch <= '9') Then HexVal := Ord(Ch) - Ord('0')
  Else If (Ch >= 'A') And (Ch <= 'F') Then HexVal := Ord(Ch) - Ord('A') + 10
  Else HexVal := Ord(Ch) - Ord('a') + 10;
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
{ Entiers decimaux, hex (0x), octaux (0o), binaires (0b),       }
{ flottants (3.14, 1.5e3), underscores dans les nombres (1_000) }
Procedure LexScanNumber;
Var
  N        : LongInt;
  Base     : Integer;
  IsFloat  : Boolean;
  NegExp   : Boolean;
  Ch       : Char;
  FracDiv  : Real;
  FracVal  : Real;
  ExpVal   : Integer;
  FltVal   : Real;
Begin
  N       := 0;
  Base    := 10;
  IsFloat := False;
  NegExp  := False;
  FracVal := 0.0;
  FracDiv := 10.0;
  ExpVal  := 0;
  Ch      := LexLine[LexColNo];

  { Detecter prefixe 0x 0o 0b }
  If (Ch = '0') And (LexColNo < Length(LexLine)) Then
  Begin
    Ch := LexLine[LexColNo + 1];
    If (Ch = 'x') Or (Ch = 'X') Then
    Begin
      Base := 16;
      Inc(LexColNo); Inc(LexColNo);
    End
    Else If (Ch = 'o') Or (Ch = 'O') Then
    Begin
      Base := 8;
      Inc(LexColNo); Inc(LexColNo);
    End
    Else If (Ch = 'b') Or (Ch = 'B') Then
    Begin
      Base := 2;
      Inc(LexColNo); Inc(LexColNo);
    End;
  End;

  { Scanner la partie entiere }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '_' Then
    Begin
      Inc(LexColNo);
    End
    Else If (Base = 16) And IsHexDigit(Ch) Then
    Begin
      N := N * 16 + HexVal(Ch);
      Inc(LexColNo);
    End
    Else If (Base = 8) And (Ch >= '0') And (Ch <= '7') Then
    Begin
      N := N * 8 + (Ord(Ch) - Ord('0'));
      Inc(LexColNo);
    End
    Else If (Base = 2) And ((Ch = '0') Or (Ch = '1')) Then
    Begin
      N := N * 2 + (Ord(Ch) - Ord('0'));
      Inc(LexColNo);
    End
    Else If (Base = 10) And (Ch >= '0') And (Ch <= '9') Then
    Begin
      N := N * 10 + (Ord(Ch) - Ord('0'));
      Inc(LexColNo);
    End
    Else
      Break;
  End;

  { Partie decimale .ddd (seulement en base 10) }
  If (Base = 10) And (LexColNo <= Length(LexLine)) And
     (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And
     (LexLine[LexColNo + 1] >= '0') And (LexLine[LexColNo + 1] <= '9') Then
  Begin
    IsFloat := True;
    Inc(LexColNo);
    FracDiv := 10.0;
    FracVal := 0.0;
    While (LexColNo <= Length(LexLine)) And
          (((LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9')) Or
           (LexLine[LexColNo] = '_')) Do
    Begin
      If LexLine[LexColNo] <> '_' Then
      Begin
        FracVal := FracVal + (Ord(LexLine[LexColNo]) - Ord('0')) / FracDiv;
        FracDiv := FracDiv * 10.0;
      End;
      Inc(LexColNo);
    End;
  End;

  { Exposant e/E [+-]ddd }
  If (Base = 10) And (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'e') Or (LexLine[LexColNo] = 'E')) Then
  Begin
    IsFloat := True;
    Inc(LexColNo);
    NegExp := False;
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '-') Then
    Begin
      NegExp := True;
      Inc(LexColNo);
    End
    Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '+') Then
      Inc(LexColNo);
    ExpVal := 0;
    While (LexColNo <= Length(LexLine)) And
          (((LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9')) Or
           (LexLine[LexColNo] = '_')) Do
    Begin
      If LexLine[LexColNo] <> '_' Then
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
    CurToken.FloatVal := FltVal;
    If FltVal > 32767.0 Then N := 32767
    Else If FltVal < -32768.0 Then N := -32768
    Else N := Trunc(FltVal);
    CurToken.Kind := TK_FLOAT;
  End
  Else
    CurToken.Kind := TK_INTEGER;

  CurToken.IntVal := N;
  Str(N, CurToken.Val);
End;

{ ---- LexScanEscChar : decoder une sequence d echappement --- }
Function LexScanEscChar : Char;
Var
  Ch : Char;
  V  : Integer;
Begin
  If LexColNo > Length(LexLine) Then
  Begin
    LexScanEscChar := '\';
    Exit;
  End;
  Ch := LexLine[LexColNo];
  Inc(LexColNo);
  Case Ch Of
    'n'        : LexScanEscChar := #10;
    't'        : LexScanEscChar := #9;
    'r'        : LexScanEscChar := #13;
    '0'        : LexScanEscChar := #0;
    'a'        : LexScanEscChar := #7;
    'b'        : LexScanEscChar := #8;
    'f'        : LexScanEscChar := #12;
    'v'        : LexScanEscChar := #11;
    '\'        : LexScanEscChar := '\';
    ''''       : LexScanEscChar := '''';
    '"'        : LexScanEscChar := '"';
    'x', 'X'  :
    Begin
      V := 0;
      If (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Then
      Begin
        V := HexVal(LexLine[LexColNo]);
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Then
        Begin
          V := V * 16 + HexVal(LexLine[LexColNo]);
          Inc(LexColNo);
        End;
      End;
      LexScanEscChar := Chr(V And $FF);
    End;
  Else
    LexScanEscChar := Ch;
  End;
End;

{ ---- LexScanString : chaine simple/double/triple ------------ }
{ Quote = caractere de guillemet (' ou ")                        }
{ Triple = True pour les chaines triple-quote (''' ou """)       }
Procedure LexScanString(Quote : Char; Triple : Boolean);
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  If Triple Then
  Begin
    { Sauter les 3 guillemets ouvrants }
    Inc(LexColNo); Inc(LexColNo); Inc(LexColNo);
    { Scanner jusqu a ''' ou """ }
    While Not LexEOF Do
    Begin
      If LexColNo > Length(LexLine) Then
      Begin
        If Length(S) < MAX_STR Then S := S + #10;
        LexNextLine;
        Continue;
      End;
      Ch := LexLine[LexColNo];
      { Detecter les 3 guillemets fermants }
      If (Ch = Quote) And (LexColNo + 2 <= Length(LexLine)) And
         (LexLine[LexColNo + 1] = Quote) And
         (LexLine[LexColNo + 2] = Quote) Then
      Begin
        Inc(LexColNo); Inc(LexColNo); Inc(LexColNo);
        Break;
      End
      Else If Ch = '\' Then
      Begin
        Inc(LexColNo);
        Ch := LexScanEscChar;
        If Length(S) < MAX_STR Then S := S + Ch;
      End
      Else
      Begin
        If Length(S) < MAX_STR Then S := S + Ch;
        Inc(LexColNo);
      End;
    End;
  End
  Else
  Begin
    { Chaine simple : un seul guillemet }
    Inc(LexColNo); { sauter guillemet ouvrant }
    While LexColNo <= Length(LexLine) Do
    Begin
      Ch := LexLine[LexColNo];
      If Ch = Quote Then
      Begin
        Inc(LexColNo);
        Break;
      End
      Else If Ch = '\' Then
      Begin
        Inc(LexColNo);
        Ch := LexScanEscChar;
        If Length(S) < MAX_STR Then S := S + Ch;
      End
      Else
      Begin
        If Length(S) < MAX_STR Then S := S + Ch;
        Inc(LexColNo);
      End;
    End;
  End;
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexInit : ouvrir le fichier source --------------------- }
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
  IndentTop  := 0;
  IndentStack[0] := 0;
  DedentQueue := 0;
  AtLineStart := True;
  ParenDepth  := 0;
  { Lire la premiere ligne }
  LexNextLine;
  { Detecter shebang #!/... et le sauter }
  If (Not LexEOF) And (Length(LexLine) >= 2) And
     (LexLine[1] = '#') And (LexLine[2] = '!') Then
  Begin
    LexNextLine;
    AtLineStart := True;
  End;
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

{ ---- LexNextToken : scanner le prochain token --------------- }
{ Gere l indentation Python (INDENT/DEDENT) et les NEWLINE      }
Procedure LexNextToken;
Var
  Ch       : Char;
  Indent  : Integer;
  IsTriple : Boolean;
  Scanning : Boolean;
Begin
  CurToken.IntVal   := 0;
  CurToken.FloatVal := 0.0;

  { 1) S il reste des DEDENT en file d attente, les emettre }
  If DedentQueue > 0 Then
  Begin
    Dec(DedentQueue);
    CurToken.Kind := TK_DEDENT;
    CurToken.Val  := '';
    CurToken.Line := LexLineNo;
    CurToken.Col  := 1;
    Exit;
  End;

  Scanning := True;
  While Scanning Do
  Begin
    { Avancer si on est en fin de ligne }
    If (Not LexEOF) And (LexColNo > Length(LexLine)) Then
    Begin
      { Emettre NEWLINE avant de passer a la ligne suivante }
      If (ParenDepth = 0) And (Not AtLineStart) Then
      Begin
        CurToken.Kind := TK_NEWLINE;
        CurToken.Val  := '';
        CurToken.Line := LexLineNo;
        CurToken.Col  := LexColNo;
        AtLineStart := True;
        Scanning := False;
        Break;
      End;
      { Passer les lignes }
      While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      Begin
        LexNextLine;
        AtLineStart := True;
      End;
    End;

    { Fin de fichier : emettre les DEDENT restants puis EOF }
    If LexEOF Then
    Begin
      If IndentTop > 0 Then
      Begin
        Dec(IndentTop);
        DedentQueue := IndentTop; { les autres seront emis apres }
        IndentTop := 0;
        CurToken.Kind := TK_DEDENT;
        CurToken.Val  := '';
        CurToken.Line := LexLineNo;
        CurToken.Col  := 1;
        Scanning := False;
        Break;
      End;
      CurToken.Kind := TK_EOF;
      CurToken.Val  := '';
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      Scanning := False;
      Break;
    End;

    { 2) Gestion de l indentation en debut de ligne }
    If AtLineStart Then
    Begin
      AtLineStart := False;

      { Calculer le niveau d indentation }
      Indent := 0;
      While (LexColNo <= Length(LexLine)) And
            ((LexLine[LexColNo] = ' ') Or (LexLine[LexColNo] = #9)) Do
      Begin
        If LexLine[LexColNo] = #9 Then
          Indent := ((Indent Div 8) + 1) * 8
        Else
          Inc(Indent);
        Inc(LexColNo);
      End;

      { Ligne vide ou commentaire seul : on ne genere pas INDENT/DEDENT }
      If (LexColNo > Length(LexLine)) Or (LexLine[LexColNo] = '#') Then
      Begin
        LexColNo := Length(LexLine) + 1; { passer la ligne }
        Continue;
      End;

      { Si on est dans des parentheses/crochets/accolades, pas d INDENT }
      If ParenDepth > 0 Then
        Continue;

      { Comparer avec le sommet de la pile d indentation }
      If Indent > IndentStack[IndentTop] Then
      Begin
        { Augmentation d indentation -> INDENT }
        Inc(IndentTop);
        If IndentTop >= MAX_INDENT Then
          IndentTop := MAX_INDENT - 1;
        IndentStack[IndentTop] := Indent;
        CurToken.Kind := TK_INDENT;
        CurToken.Val  := '';
        CurToken.Line := LexLineNo;
        CurToken.Col  := 1;
        Scanning := False;
        Break;
      End
      Else If Indent < IndentStack[IndentTop] Then
      Begin
        { Diminution d indentation -> DEDENT(s) }
        While (IndentTop > 0) And (Indent < IndentStack[IndentTop]) Do
        Begin
          Dec(IndentTop);
          Inc(DedentQueue);
        End;
        If Indent <> IndentStack[IndentTop] Then
          CompileError('indentation inconsistante', LexLineNo);
        { Emettre le premier DEDENT, les autres sont en file }
        If DedentQueue > 0 Then
        Begin
          Dec(DedentQueue);
          CurToken.Kind := TK_DEDENT;
          CurToken.Val  := '';
          CurToken.Line := LexLineNo;
          CurToken.Col  := 1;
          Scanning := False;
          Break;
        End;
      End;
      { Si indent = meme niveau, on continue normalement }
      Continue;
    End;

    CurToken.Line := LexLineNo;
    CurToken.Col  := LexColNo;
    Ch := LexLine[LexColNo];

    { Espaces }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
    Begin
      Inc(LexColNo);
    End

    { Commentaire # -> fin de ligne }
    Else If Ch = '#' Then
    Begin
      LexColNo := Length(LexLine) + 1;
      { Le NEWLINE sera emis au prochain tour de boucle }
    End

    { Continuation de ligne avec \ en fin de ligne }
    Else If (Ch = '\') And (LexColNo = Length(LexLine)) Then
    Begin
      LexNextLine;
      { Pas de AtLineStart : la suite est la meme ligne logique }
    End

    { Identificateur ou mot-cle }
    Else If IsIdentStart(Ch) Then
    Begin
      { Prefixes de chaines : r'...' b'...' f'...' }
      If ((Ch = 'r') Or (Ch = 'R') Or (Ch = 'b') Or (Ch = 'B') Or
          (Ch = 'f') Or (Ch = 'F')) And
         (LexColNo < Length(LexLine)) And
         ((LexLine[LexColNo + 1] = '''') Or (LexLine[LexColNo + 1] = '"')) Then
      Begin
        Inc(LexColNo); { sauter le prefixe }
        Ch := LexLine[LexColNo];
        { Detecter triple-quote }
        IsTriple := (LexColNo + 2 <= Length(LexLine)) And
                    (LexLine[LexColNo + 1] = Ch) And
                    (LexLine[LexColNo + 2] = Ch);
        LexScanString(Ch, IsTriple);
        Scanning := False;
      End
      Else
      Begin
        LexScanIdent;
        Scanning := False;
      End;
    End

    { Nombre decimal }
    Else If (Ch >= '0') And (Ch <= '9') Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    { Nombre .5 (point suivi d un chiffre) }
    Else If (Ch = '.') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] >= '0') And
            (LexLine[LexColNo + 1] <= '9') Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    { Chaines de caracteres }
    Else If (Ch = '''') Or (Ch = '"') Then
    Begin
      { Detecter triple-quote }
      IsTriple := (LexColNo + 2 <= Length(LexLine)) And
                  (LexLine[LexColNo + 1] = Ch) And
                  (LexLine[LexColNo + 2] = Ch);
      LexScanString(Ch, IsTriple);
      Scanning := False;
    End

    { Operateurs multi-caracteres Python }

    { ** et **= }
    Else If (Ch = '*') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '**=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '**';
      End;
      Scanning := False;
    End

    { *= }
    Else If (Ch = '*') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '*=';
      Scanning := False;
    End

    { * }
    Else If Ch = '*' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '*';
      Scanning := False;
    End

    { // et //= }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '//=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '//';
      End;
      Scanning := False;
    End

    { /= }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '/=';
      Scanning := False;
    End

    { / }
    Else If Ch = '/' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '/';
      Scanning := False;
    End

    { == }
    Else If (Ch = '=') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '==';
      Scanning := False;
    End

    { = }
    Else If Ch = '=' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '=';
      Scanning := False;
    End

    { != }
    Else If (Ch = '!') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '!=';
      Scanning := False;
    End

    { << et <<= }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '<') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '<<=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '<<';
      End;
      Scanning := False;
    End

    { <= }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '<=';
      Scanning := False;
    End

    { < }
    Else If Ch = '<' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '<';
      Scanning := False;
    End

    { >> et >>= }
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '>>=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '>>';
      End;
      Scanning := False;
    End

    { >= }
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '>=';
      Scanning := False;
    End

    { > }
    Else If Ch = '>' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '>';
      Scanning := False;
    End

    { += }
    Else If (Ch = '+') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '+=';
      Scanning := False;
    End

    { + }
    Else If Ch = '+' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '+';
      Scanning := False;
    End

    { -= et -> }
    Else If (Ch = '-') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '-=';
      Scanning := False;
    End
    Else If (Ch = '-') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '->';
      Scanning := False;
    End

    { - }
    Else If Ch = '-' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '-';
      Scanning := False;
    End

    { %= }
    Else If (Ch = '%') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '%=';
      Scanning := False;
    End

    { % }
    Else If Ch = '%' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '%';
      Scanning := False;
    End

    { &= }
    Else If (Ch = '&') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '&=';
      Scanning := False;
    End

    { & }
    Else If Ch = '&' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '&';
      Scanning := False;
    End

    { |= }
    Else If (Ch = '|') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '|=';
      Scanning := False;
    End

    { | }
    Else If Ch = '|' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '|';
      Scanning := False;
    End

    { ^= }
    Else If (Ch = '^') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '^=';
      Scanning := False;
    End

    { ^ }
    Else If Ch = '^' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '^';
      Scanning := False;
    End

    { ~ }
    Else If Ch = '~' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '~';
      Scanning := False;
    End

    { @ (decorateur) }
    Else If Ch = '@' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '@';
      Scanning := False;
    End

    { ... (Ellipsis) }
    Else If (Ch = '.') And (LexColNo + 2 <= Length(LexLine)) And
            (LexLine[LexColNo + 1] = '.') And
            (LexLine[LexColNo + 2] = '.') Then
    Begin
      Inc(LexColNo); Inc(LexColNo); Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := '...';
      Scanning := False;
    End

    { . }
    Else If Ch = '.' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := '.';
      Scanning := False;
    End

    { : }
    Else If Ch = ':' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := ':';
      Scanning := False;
    End

    { ; }
    Else If Ch = ';' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := ';';
      Scanning := False;
    End

    { , }
    Else If Ch = ',' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := ',';
      Scanning := False;
    End

    { ( [ { : ponctuation ouvrante -> incrementer ParenDepth }
    Else If (Ch = '(') Or (Ch = '[') Or (Ch = '{') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Inc(ParenDepth);
      Scanning := False;
    End

    { ponctuation fermante -> decrementer ParenDepth }
    Else If (Ch = ')') Or (Ch = ']') Or (Ch = '}') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      If ParenDepth > 0 Then Dec(ParenDepth);
      Scanning := False;
    End

    { Caractere inconnu }
    Else
    Begin
      WarnMsg('caractere inconnu: ' + Ch, LexLineNo);
      Inc(LexColNo);
    End;

  End; { While Scanning }
End;

{ ---- ParserAdvance : lire le prochain token avec debug ------ }
Procedure ParserAdvance;
Begin
  LexNextToken;
  If Opts.DebugMode Then
    PrintToken(CurToken);
End;

{ ============================================================
  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

{ ---- LabelGen : generateur de labels uniques _PYL_N -------- }
Function LabelGen : TString;
Begin
  Inc(LabelGenSeq);
  LabelGen := PY_LBL_PFX + IntToStr_(LabelGenSeq);
End;

{ ---- EmitRaw : ecrire une ligne brute dans le fichier ASM --- }
{ Si le buffer de comprehension est actif, stocker dans CompBuf }
Procedure EmitRaw(Const S : String);
Begin
  If CompBufActive Then
  Begin
    If CompBufCount < MAX_COMP_BUF Then
    Begin
      Inc(CompBufCount);
      CompBuf[CompBufCount] := S;
    End;
  End
  Else If OutFOpen Then
    WriteLn(OutF, S);
End;

{ ---- DataAdd : ajouter une entree dans DataTab -------------- }
Function DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer;
Begin
  If DataCount >= MAX_DATA Then
    FatalError('DataTab pleine (MAX_DATA atteint)');
  DataTab[DataCount].LblName   := Lbl;
  DataTab[DataCount].Kind      := Kind;
  DataTab[DataCount].IntVal    := AIntVal;
  DataTab[DataCount].StrVal    := AStrVal;
  DataTab[DataCount].ElemCount := 0;
  DataAdd := DataCount;
  Inc(DataCount);
End;

{ DataAddStr : creer un label _PYK_N et stocker la chaine litterale }
Function DataAddStr(Const S : TString) : TString;
Var
  Lbl : TString;
Begin
  Inc(LabelGenSeq);
  Lbl := PY_STR_PFX + IntToStr_(LabelGenSeq);
  DataAdd(Lbl, DK_STR, 0, S);
  DataAddStr := Lbl;
End;

{ DataAddWord : ajouter un mot 16 bits dans le segment DATA }
Function DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

{ ============================================================
  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
  ============================================================ }

{ DataAddList : creer une entree DK_LIST dans DataTab.            }
{ AElemCount elements de 16 bits (DW) seront reserves.            }
{ Les elements sont initialises a 0 ; le code generateur remplit  }
{ les valeurs effectives.                                          }
Function DataAddList(Const Lbl : TString;
                     AElemCount : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If DataCount >= MAX_DATA Then
    FatalError('DataTab pleine (MAX_DATA atteint)');
  Idx := DataCount;
  DataTab[Idx].LblName   := Lbl;
  DataTab[Idx].Kind      := DK_LIST;
  DataTab[Idx].IntVal    := 0;
  DataTab[Idx].StrVal    := '';
  DataTab[Idx].ElemCount := AElemCount;
  Inc(DataCount);
  DataAddList := Idx;
End;

{ DataAddDict : creer une entree DK_DICT dans DataTab.            }
{ APairCount paires cle/valeur -> 2*APairCount mots de 16 bits.   }
Function DataAddDict(Const Lbl : TString;
                     APairCount : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If DataCount >= MAX_DATA Then
    FatalError('DataTab pleine (MAX_DATA atteint)');
  Idx := DataCount;
  DataTab[Idx].LblName   := Lbl;
  DataTab[Idx].Kind      := DK_DICT;
  DataTab[Idx].IntVal    := 0;
  DataTab[Idx].StrVal    := '';
  DataTab[Idx].ElemCount := APairCount;
  Inc(DataCount);
  DataAddDict := Idx;
End;

{ ---- Constructeurs TExprVal --------------------------------- }

{ ExprMakeImm : valeur immediate constante }
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ExprMakeNone : valeur invalide (void / erreur) }
Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ExprMakeBool : valeur booleenne (0 ou 1) }
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  If AVal <> 0 Then Res.ImmVal := 1 Else Res.ImmVal := 0;
  Res.TypeIdx := TY_IDX_BOOL;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ExprMakeAX : valeur dans le registre AX }
Procedure ExprMakeAX(ATypeIdx : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_AX;
  Res.ImmVal  := 0;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- Evaluateurs de litteraux ------------------------------- }

{ LitEvalInt : convertir un token TK_INTEGER en valeur         }
{ (IntVal est deja calcule par LexScanNumber)                   }
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_INT, Res);
End;

{ LitEvalFloat : convertir un token TK_FLOAT en entier (trunc) }
{ Python n a pas de float natif 8086 : on tronque avec warning  }
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal);
Var
  IV : LongInt;
Begin
  IV := Trunc(T.FloatVal);
  If IV > 32767 Then IV := 32767;
  If IV < -32768 Then IV := -32768;
  WarnMsg('flottant tronque en entier: ' + T.Val, T.Line);
  ExprMakeImm(IV, TY_IDX_INT, Res);
End;

{ LitEvalStr : stocker une chaine dans le segment DATA         }
{ Retourne un EK_MEM pointant vers le label de la chaine       }
Procedure LitEvalStr(Const T : TToken; Var Res : TExprVal);
Var
  Lbl : TString;
Begin
  Lbl := DataAddStr(T.Val);
  Res.Kind    := EK_MEM;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_STR;
  Res.Offset  := DataCount - 1;   { index de l entree DATA }
  Res.SymIdx  := -1;
End;

{ LitEval : dispatcher principal pour les litteraux Python     }
{ Tokens : TK_INTEGER, TK_FLOAT, TK_STRING, TK_KEYWORD        }
{ Mots-cles : True, False, None                                 }
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeNone(Res);
  Case T.Kind Of
    TK_INTEGER :
      LitEvalInt(T, Res);
    TK_FLOAT :
      LitEvalFloat(T, Res);
    TK_STRING :
      LitEvalStr(T, Res);
    TK_KEYWORD :
    Begin
      If T.Val = 'True' Then
        ExprMakeBool(1, Res)
      Else If T.Val = 'False' Then
        ExprMakeBool(0, Res)
      Else If T.Val = 'None' Then
        ExprMakeImm(0, TY_IDX_NONE, Res)
      Else
        ExprMakeNone(Res);
    End;
  Else
    ExprMakeNone(Res);
  End;
End;

{ ---- Emission ASM (stubs pour TODOs suivants) --------------- }

Procedure EmitOpen;
Begin
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  If IOResult <> 0 Then
    FatalError('impossible de creer: ' + Opts.OutFile);
  OutFOpen := True;
End;

Procedure EmitHeader;
Begin
  EmitRaw('; Genere par PYTHON86 v' + PYTHON86_VERSION +
          ' - ' + Opts.SrcFile);
  EmitRaw('; Cible : MASM .MODEL SMALL, DOS 16 bits');
  EmitRaw('');
  EmitRaw('.MODEL SMALL');
  EmitRaw('.STACK ' + IntToStr_(STACK_SIZE));
  EmitRaw('');
  EmitRaw('_TEXT   SEGMENT WORD PUBLIC ''CODE''');
  EmitRaw('        ASSUME CS:_TEXT, DS:_DATA, SS:STACK');
  EmitRaw('');
End;

Procedure EmitDataSeg;
Var
  I, J : Integer;
  S    : TString;
Begin
  EmitRaw('');
  EmitRaw('_DATA   SEGMENT WORD PUBLIC ''DATA''');
  EmitRaw('');
  { Buffer de travail pour concatenation de chaines }
  EmitRaw('_PY_STRBUF  DB  256 DUP(0)');
  { Buffer secondaire pour operations chaines avancees (TODO 20) }
  EmitRaw('_PY_STRBUF2 DB  256 DUP(0)');
  EmitRaw('');
  { Buffer pour conversions entier -> chaine (TODO 12) }
  EmitRaw('_PY_NUMBUF  DB  12 DUP(0)');
  EmitRaw('');
  { Constantes CRLF et espace pour print (TODO 12) }
  EmitRaw('_PY_CRLF    DB  13, 10');
  EmitRaw('_PY_SPACE   DB  32, 0');
  EmitRaw('');
  { Buffer de lecture pour input (TODO 12) }
  EmitRaw('_PY_INPUTMX DB  126');
  EmitRaw('_PY_INPUTLN DB  0');
  EmitRaw('_PY_INPUTBF DB  128 DUP(0)');
  EmitRaw('');
  { Donnees pour boucle for (TODO 14) }
  EmitRaw('_PY_FOREND   DW 0');
  EmitRaw('_PY_FORSTEP  DW 0');
  EmitRaw('_PY_FORITER  DW 0');
  EmitRaw('');
  { Donnees pour gestion des exceptions (TODO 21) }
  EmitRaw('_PY_EXCFLAG  DW 0');
  EmitRaw('_PY_EXCVAL   DW 0');
  EmitRaw('');
  { Donnees pour comprehensions (TODO 22) }
  EmitRaw('_PY_COMPTGT  DW 0');
  EmitRaw('_PY_COMPIDX  DW 0');
  EmitRaw('');
  { Heap statique pour allocations dynamiques (listes, dicts, objets) }
  EmitRaw('_PY_HEAP    DB  4096 DUP(0)');
  EmitRaw('_PY_HEAPTOP DW  0');
  EmitRaw('');
  { Emettre toutes les entrees de DataTab }
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_WORD :
        EmitRaw(DataTab[I].LblName + '  DW  ' +
                IntToStr_(DataTab[I].IntVal));
      DK_BYTE :
        EmitRaw(DataTab[I].LblName + '  DB  ' +
                IntToStr_(DataTab[I].IntVal));
      DK_STR :
      Begin
        { Emettre la chaine comme DB 'c','h',...,0 }
        S := DataTab[I].StrVal;
        If Length(S) = 0 Then
          EmitRaw(DataTab[I].LblName + '  DB  0')
        Else
        Begin
          Write(OutF, DataTab[I].LblName, '  DB  ');
          For J := 1 To Length(S) Do
          Begin
            If J > 1 Then Write(OutF, ',');
            Write(OutF, Ord(S[J]));
          End;
          WriteLn(OutF, ',0');
        End;
      End;
      DK_ARRAY_BLK :
        EmitRaw(DataTab[I].LblName + '  DW  ' +
                IntToStr_(DataTab[I].ElemCount) + ' DUP(0)');
      DK_LIST :
      Begin
        { Liste litterale : ElemCount mots de 16 bits initialises a 0 }
        If DataTab[I].ElemCount <= 0 Then
          EmitRaw(DataTab[I].LblName + '  DW  0')
        Else
          EmitRaw(DataTab[I].LblName + '  DW  ' +
                  IntToStr_(DataTab[I].ElemCount) + ' DUP(0)');
      End;
      DK_DICT :
      Begin
        { Dictionnaire : 2*ElemCount mots (paires cle/valeur) }
        If DataTab[I].ElemCount <= 0 Then
          EmitRaw(DataTab[I].LblName + '  DW  0')
        Else
          EmitRaw(DataTab[I].LblName + '  DW  ' +
                  IntToStr_(DataTab[I].ElemCount * 2) + ' DUP(0)');
      End;
      DK_TUPLE :
      Begin
        { Tuple : ElemCount mots de 16 bits initialises a 0 }
        If DataTab[I].ElemCount <= 0 Then
          EmitRaw(DataTab[I].LblName + '  DW  0')
        Else
          EmitRaw(DataTab[I].LblName + '  DW  ' +
                  IntToStr_(DataTab[I].ElemCount) + ' DUP(0)');
      End;
    End;
  End;
  EmitRaw('');
  EmitRaw('_DATA   ENDS');
End;

{ ============================================================
  TODO 24 - RUNTIME MINIMAL [IMPLEMENTE]
  ============================================================ }

{ EmitMinimalRuntime : consolide l emission de toutes les routines runtime }
{ Protege par RuntimeEmitted pour n emettre qu une seule fois              }
Procedure EmitMinimalRuntime;
Begin
  If RuntimeEmitted Then Exit;
  RuntimeEmitted := True;

  EmitBlankLine;
  EmitComment('=== RUNTIME MINIMAL (TODO 24) ===');

  { Routines d expressions binaires (TODO 11) }
  EmitExprRuntime;
  { Routines d entrees/sorties (TODO 12) }
  EmitIORuntime;
  { Routines pour listes (TODO 15) }
  EmitListRuntime;
  { Routines pour dicts (TODO 16) }
  EmitDictRuntime;
  { Routines pour classes (TODO 18) }
  EmitClassRuntime;
  { Routines pour tuples (TODO 19) }
  EmitTupleRuntime;
  { Routines pour chaines avancees (TODO 20) }
  EmitStrRuntime;

  { _PYRT_PANIC : affiche un message d erreur et termine avec code 1 }
  { Entree : SI = pointeur chaine ASCIIZ du message                   }
  EmitBlankLine;
  EmitComment('_PYRT_PANIC : affiche message + exit code 1');
  EmitLabel(PY_RT_PFX + 'PANIC');
  EmitInstr('PUSH   SI');
  EmitInstr('CALL   ' + PY_RT_PFX + 'PRINTSTR');
  EmitInstr('MOV    SI, OFFSET _PY_CRLF');
  EmitInstr('CALL   ' + PY_RT_PFX + 'PRINTSTR');
  EmitInstr('MOV    AX, 4C01h');
  EmitInstr('INT    21h');
End;

Procedure EmitClose;
Begin
  { Emettre le runtime minimal une seule fois (TODO 24) }
  EmitMinimalRuntime;
  { Fermer le segment de code }
  EmitRaw('');
  EmitRaw('_TEXT   ENDS');
  EmitRaw('');
  { Segment de donnees }
  EmitDataSeg;
  EmitRaw('');
  EmitRaw('        END _PYF_Main');
  { Fermer le fichier }
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ============================================================
  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
  ============================================================ }

{ ---- Helpers d emission ASM --------------------------------- }

{ EmitInstr : emettre une instruction indentee (8 espaces) }
Procedure EmitInstr(Const S : TString);
Begin
  If CompBufActive Then
  Begin
    If CompBufCount < MAX_COMP_BUF Then
    Begin
      Inc(CompBufCount);
      CompBuf[CompBufCount] := '        ' + S;
    End;
  End
  Else If OutFOpen Then
    WriteLn(OutF, '        ', S);
End;

{ EmitLabel : emettre un label suivi de ':' }
Procedure EmitLabel(Const Lbl : TString);
Begin
  If CompBufActive Then
  Begin
    If CompBufCount < MAX_COMP_BUF Then
    Begin
      Inc(CompBufCount);
      CompBuf[CompBufCount] := Lbl + ':';
    End;
  End
  Else If OutFOpen Then
    WriteLn(OutF, Lbl, ':');
End;

{ EmitComment : emettre un commentaire ASM ('; msg') }
Procedure EmitComment(Const Msg : TString);
Begin
  If CompBufActive Then
  Begin
    If CompBufCount < MAX_COMP_BUF Then
    Begin
      Inc(CompBufCount);
      CompBuf[CompBufCount] := '; ' + Msg;
    End;
  End
  Else If OutFOpen Then
    WriteLn(OutF, '; ', Msg);
End;

{ EmitBlankLine : ligne vide dans le fichier de sortie }
Procedure EmitBlankLine;
Begin
  If CompBufActive Then
  Begin
    If CompBufCount < MAX_COMP_BUF Then
    Begin
      Inc(CompBufCount);
      CompBuf[CompBufCount] := '';
    End;
  End
  Else If OutFOpen Then
    WriteLn(OutF);
End;

{ ---- ExprFlushToAX : materialiser la valeur dans AX --------- }
Procedure ExprFlushToAX(Var E : TExprVal);
Var
  S : TString;
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      If E.ImmVal = 0 Then
        EmitInstr('XOR    AX, AX')
      Else
      Begin
        Str(E.ImmVal, S);
        EmitInstr('MOV    AX, ' + S);
      End;
      E.Kind := EK_AX;
    End;
    EK_MEM :
    Begin
      { Chaine litterale : OFFSET label }
      If E.TypeIdx = TY_IDX_STR Then
      Begin
        If (E.Offset >= 0) And (E.Offset < DataCount) Then
          EmitInstr('MOV    AX, OFFSET ' + DataTab[E.Offset].LblName)
        Else If (E.SymIdx >= 0) And (E.SymIdx < SymCount) Then
          EmitInstr('MOV    AX, OFFSET ' + SymTab[E.SymIdx].MangledName)
        Else
          EmitInstr('XOR    AX, AX');
      End
      Else If (E.SymIdx >= 0) And (E.SymIdx < SymCount) Then
      Begin
        { Variable : charger depuis memoire (TODO 09) }
        ExprLoadToAX(E.SymIdx);
      End
      Else
        EmitInstr('XOR    AX, AX');
      E.Kind := EK_AX;
    End;
    EK_AX :
      ;  { deja dans AX }
    EK_NONE :
    Begin
      EmitInstr('XOR    AX, AX');
      E.Kind := EK_AX;
    End;
  End;
End;

{ ---- BinOpPrec : table de precedences Python (Pratt) --------
  Retourne 0 si l operateur n est pas binaire.
  Niveaux (ordre croissant = priorite croissante) :
    or           -> 1
    and          -> 2
    not          -> traite en unaire (ParseUnary)
    == != < <= > >= in is  -> 3
    |            -> 4
    ^            -> 5
    &            -> 6
    << >>        -> 7
    + - (binaire)-> 8
    * / // %     -> 9
    **           -> 10 (droit-associatif)                      }
Function BinOpPrec(Const Op : TString) : Integer;
Begin
  If Op = 'or' Then
    BinOpPrec := 1
  Else If Op = 'and' Then
    BinOpPrec := 2
  Else If (Op = '==') Or (Op = '!=') Or
          (Op = '<')  Or (Op = '<=') Or
          (Op = '>')  Or (Op = '>=') Or
          (Op = 'in') Or (Op = 'is') Or
          (Op = 'not in') Or (Op = 'is not') Then
    BinOpPrec := 3
  Else If Op = '|' Then
    BinOpPrec := 4
  Else If Op = '^' Then
    BinOpPrec := 5
  Else If Op = '&' Then
    BinOpPrec := 6
  Else If (Op = '<<') Or (Op = '>>') Then
    BinOpPrec := 7
  Else If (Op = '+') Or (Op = '-') Then
    BinOpPrec := 8
  Else If (Op = '*') Or (Op = '/') Or (Op = '//') Or (Op = '%') Then
    BinOpPrec := 9
  Else If Op = '**' Then
    BinOpPrec := 10
  Else
    BinOpPrec := 0;
End;

{ BinOpIsRight : ** est droit-associatif en Python }
Function BinOpIsRight(Const Op : TString) : Boolean;
Begin
  BinOpIsRight := (Op = '**');
End;

{ IsAssignOp : detecter les operateurs d affectation }
Function IsAssignOp(Const Op : TString) : Boolean;
Begin
  IsAssignOp := (Op = '=')   Or (Op = '+=')  Or (Op = '-=')  Or
                (Op = '*=')  Or (Op = '//=') Or (Op = '%=')  Or
                (Op = '**=') Or (Op = '&=')  Or (Op = '|=')  Or
                (Op = '^=')  Or (Op = '<<=') Or (Op = '>>=') Or
                (Op = '/=');
End;

{ ---- ExprEmitBinOp : generer le code 8086 d un operateur ----
  Pliage de constantes si L et R sont EK_IMM.
  Operateurs Python couverts :
    + - * / // % ** (arith)
    == != < <= > >= (comparaison)
    and or (logique, court-circuit)
    & | ^ << >> (bitwise)
    in, is (stub = comparaison)                                }
Procedure ExprEmitBinOp(Const Op : TString;
            Var L : TExprVal; Var R : TExprVal);
Var
  RS     : TString;
  LblEnd : TString;
  Acc    : LongInt;
  Exp    : LongInt;
Begin
  { ---- Pliage de constantes -------------------------------- }
  If (L.Kind = EK_IMM) And (R.Kind = EK_IMM) Then
  Begin
    If      Op = '+'   Then L.ImmVal := L.ImmVal + R.ImmVal
    Else If Op = '-'   Then L.ImmVal := L.ImmVal - R.ImmVal
    Else If Op = '*'   Then L.ImmVal := L.ImmVal * R.ImmVal
    Else If (Op = '/') Or (Op = '//') Then
    Begin
      If R.ImmVal = 0 Then
      Begin
        CompileError('division par zero', CurToken.Line);
        L.ImmVal := 0;
      End
      Else
        L.ImmVal := L.ImmVal Div R.ImmVal;
    End
    Else If Op = '%'   Then
    Begin
      If R.ImmVal = 0 Then
      Begin
        CompileError('modulo par zero', CurToken.Line);
        L.ImmVal := 0;
      End
      Else
        L.ImmVal := L.ImmVal Mod R.ImmVal;
    End
    Else If Op = '**'  Then
    Begin
      Acc := 1; Exp := R.ImmVal;
      If Exp < 0 Then L.ImmVal := 0
      Else Begin
        While Exp > 0 Do Begin Acc := Acc * L.ImmVal; Dec(Exp); End;
        L.ImmVal := Acc;
      End;
    End
    Else If Op = '&'   Then L.ImmVal := L.ImmVal And R.ImmVal
    Else If Op = '|'   Then L.ImmVal := L.ImmVal Or  R.ImmVal
    Else If Op = '^'   Then L.ImmVal := L.ImmVal Xor R.ImmVal
    Else If Op = '<<'  Then L.ImmVal := L.ImmVal Shl Integer(R.ImmVal And 15)
    Else If Op = '>>'  Then L.ImmVal := L.ImmVal Shr Integer(R.ImmVal And 15)
    Else If Op = '=='  Then Begin If L.ImmVal =  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '!='  Then Begin If L.ImmVal <> R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '<'   Then Begin If L.ImmVal <  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '<='  Then Begin If L.ImmVal <= R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '>'   Then Begin If L.ImmVal >  R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = '>='  Then Begin If L.ImmVal >= R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0; End
    Else If Op = 'and' Then
    Begin
      If (L.ImmVal <> 0) And (R.ImmVal <> 0) Then L.ImmVal := R.ImmVal
      Else L.ImmVal := 0;
    End
    Else If Op = 'or'  Then
    Begin
      If L.ImmVal <> 0 Then { garde L }
      Else L.ImmVal := R.ImmVal;
    End
    Else If Op = 'in'      Then L.ImmVal := 0  { stub }
    Else If Op = 'not in'  Then L.ImmVal := 1  { stub }
    Else If Op = 'is'      Then
    Begin
      If L.ImmVal = R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0;
    End
    Else If Op = 'is not'  Then
    Begin
      If L.ImmVal <> R.ImmVal Then L.ImmVal := 1 Else L.ImmVal := 0;
    End;
    L.TypeIdx := TY_IDX_INT;
    Exit;
  End;

  { ---- Court-circuit 'and' --------------------------------- }
  If Op = 'and' Then
  Begin
    LblEnd := LabelGen;
    ExprFlushToAX(L);
    EmitInstr('TEST   AX, AX');
    EmitInstr('JZ     ' + LblEnd);
    ExprFlushToAX(R);
    EmitLabel(LblEnd);
    L.Kind := EK_AX;
    L.TypeIdx := TY_IDX_INT;
    Exit;
  End;

  { ---- Court-circuit 'or' ---------------------------------- }
  If Op = 'or' Then
  Begin
    LblEnd := LabelGen;
    ExprFlushToAX(L);
    EmitInstr('TEST   AX, AX');
    EmitInstr('JNZ    ' + LblEnd);
    ExprFlushToAX(R);
    EmitLabel(LblEnd);
    L.Kind := EK_AX;
    L.TypeIdx := TY_IDX_INT;
    Exit;
  End;

  { ---- TODO 11 : Concatenation str + ----------------------- }
  If (Op = '+') And (L.TypeIdx = TY_IDX_STR) Then
  Begin
    ExprFlushToAX(L);
    EmitInstr('MOV    SI, AX');      { SI = gauche }
    EmitInstr('PUSH   SI');
    ExprFlushToAX(R);
    EmitInstr('MOV    DI, AX');      { DI = droite }
    EmitInstr('POP    SI');
    EmitInstr('CALL   ' + PY_RT_PFX + 'CONCAT');
    L.Kind    := EK_AX;
    L.TypeIdx := TY_IDX_STR;
    L.SymIdx  := -1;
    Exit;
  End;

  { ---- TODO 11 : Repetition str * n ----------------------- }
  If (Op = '*') And (L.TypeIdx = TY_IDX_STR) Then
  Begin
    ExprFlushToAX(L);
    EmitInstr('MOV    SI, AX');      { SI = chaine }
    EmitInstr('PUSH   SI');
    ExprFlushToAX(R);
    EmitInstr('MOV    CX, AX');      { CX = count  }
    EmitInstr('POP    SI');
    EmitInstr('CALL   ' + PY_RT_PFX + 'STRMUL');
    L.Kind    := EK_AX;
    L.TypeIdx := TY_IDX_STR;
    L.SymIdx  := -1;
    Exit;
  End;

  { ---- TODO 15 : Concatenation list + list ----------------- }
  If (Op = '+') And (L.TypeIdx = TY_IDX_LIST) Then
  Begin
    ExprFlushToAX(L);
    EmitInstr('MOV    SI, AX');      { SI = liste gauche }
    EmitInstr('PUSH   SI');
    ExprFlushToAX(R);
    EmitInstr('MOV    DI, AX');      { DI = liste droite }
    EmitInstr('POP    SI');
    EmitInstr('CALL   ' + PY_RT_PFX + 'LISTCONCAT');
    L.Kind    := EK_AX;
    L.TypeIdx := TY_IDX_LIST;
    L.SymIdx  := -1;
    Exit;
  End;

  { ---- TODO 15 : Repetition list * n ----------------------- }
  If (Op = '*') And (L.TypeIdx = TY_IDX_LIST) Then
  Begin
    ExprFlushToAX(L);
    EmitInstr('MOV    SI, AX');      { SI = liste }
    EmitInstr('PUSH   SI');
    ExprFlushToAX(R);
    EmitInstr('MOV    CX, AX');      { CX = count }
    EmitInstr('POP    SI');
    EmitInstr('CALL   ' + PY_RT_PFX + 'LISTMUL');
    L.Kind    := EK_AX;
    L.TypeIdx := TY_IDX_LIST;
    L.SymIdx  := -1;
    Exit;
  End;

  { ---- TODO 19 : Concatenation tuple + tuple --------------- }
  If (Op = '+') And (L.TypeIdx = TY_IDX_TUPLE) Then
  Begin
    ExprFlushToAX(L);
    EmitInstr('MOV    SI, AX');      { SI = tuple gauche }
    EmitInstr('PUSH   SI');
    ExprFlushToAX(R);
    EmitInstr('MOV    DI, AX');      { DI = tuple droite }
    EmitInstr('POP    SI');
    EmitInstr('CALL   ' + PY_RT_PFX + 'TUPLECONCAT');
    L.Kind    := EK_AX;
    L.TypeIdx := TY_IDX_TUPLE;
    L.SymIdx  := -1;
    Exit;
  End;

  { ---- TODO 19 : Repetition tuple * n --------------------- }
  If (Op = '*') And (L.TypeIdx = TY_IDX_TUPLE) Then
  Begin
    ExprFlushToAX(L);
    EmitInstr('MOV    SI, AX');      { SI = tuple }
    EmitInstr('PUSH   SI');
    ExprFlushToAX(R);
    EmitInstr('MOV    CX, AX');      { CX = count }
    EmitInstr('POP    SI');
    EmitInstr('CALL   ' + PY_RT_PFX + 'TUPLEMUL');
    L.Kind    := EK_AX;
    L.TypeIdx := TY_IDX_TUPLE;
    L.SymIdx  := -1;
    Exit;
  End;

  { ---- TODO 11 : Comparaison str (==, !=, <, <=, >, >=) --- }
  If ((Op = '==') Or (Op = '!=') Or (Op = '<') Or
      (Op = '<=') Or (Op = '>') Or (Op = '>=')) And
     (L.TypeIdx = TY_IDX_STR) Then
  Begin
    ExprFlushToAX(L);
    EmitInstr('MOV    SI, AX');
    EmitInstr('PUSH   SI');
    ExprFlushToAX(R);
    EmitInstr('MOV    DI, AX');
    EmitInstr('POP    SI');
    EmitInstr('CALL   ' + PY_RT_PFX + 'STRCMP');
    { AX = resultat de la comparaison (-1,0,+1) }
    EmitInstr('MOV    BX, AX');
    EmitInstr('MOV    AX, 0');
    If      Op = '==' Then Begin EmitInstr('TEST   BX, BX'); EmitInstr('JNZ    $+4'); End
    Else If Op = '!=' Then Begin EmitInstr('TEST   BX, BX'); EmitInstr('JZ     $+4'); End
    Else If Op = '<'  Then Begin EmitInstr('CMP    BX, 0');  EmitInstr('JGE    $+4'); End
    Else If Op = '<=' Then Begin EmitInstr('CMP    BX, 0');  EmitInstr('JG     $+4'); End
    Else If Op = '>'  Then Begin EmitInstr('CMP    BX, 0');  EmitInstr('JLE    $+4'); End
    Else If Op = '>=' Then Begin EmitInstr('CMP    BX, 0');  EmitInstr('JL     $+4'); End;
    EmitInstr('INC    AX');
    L.Kind    := EK_AX;
    L.TypeIdx := TY_IDX_INT;
    L.SymIdx  := -1;
    Exit;
  End;

  { ---- TODO 16 : Operateur in pour dicts -------------------- }
  If ((Op = 'in') Or (Op = 'not in')) And (R.TypeIdx = TY_IDX_DICT) Then
  Begin
    ExprFlushToAX(L);
    EmitInstr('PUSH   AX');          { element a chercher }
    ExprFlushToAX(R);
    EmitInstr('MOV    SI, AX');      { SI = dict }
    EmitInstr('POP    AX');          { AX = key }
    EmitInstr('CALL   ' + PY_RT_PFX + 'DICTCONTAINS');
    If Op = 'not in' Then
    Begin
      EmitInstr('TEST   AX, AX');
      EmitInstr('MOV    AX, 0');
      EmitInstr('JNZ    $+4');
      EmitInstr('INC    AX');
    End;
    L.Kind    := EK_AX;
    L.TypeIdx := TY_IDX_INT;
    L.SymIdx  := -1;
    Exit;
  End;

  { ---- TODO 19 : Operateur in pour tuples ------------------- }
  If ((Op = 'in') Or (Op = 'not in')) And (R.TypeIdx = TY_IDX_TUPLE) Then
  Begin
    ExprFlushToAX(L);
    EmitInstr('PUSH   AX');          { element a chercher }
    ExprFlushToAX(R);
    EmitInstr('MOV    SI, AX');      { SI = tuple }
    EmitInstr('POP    AX');          { AX = element }
    EmitInstr('CALL   ' + PY_RT_PFX + 'CONTAINS');
    If Op = 'not in' Then
    Begin
      EmitInstr('TEST   AX, AX');
      EmitInstr('MOV    AX, 0');
      EmitInstr('JNZ    $+4');
      EmitInstr('INC    AX');
    End;
    L.Kind    := EK_AX;
    L.TypeIdx := TY_IDX_INT;
    L.SymIdx  := -1;
    Exit;
  End;

  { ---- TODO 20 : Operateur in pour chaines (sub in str) ------ }
  If ((Op = 'in') Or (Op = 'not in')) And (R.TypeIdx = TY_IDX_STR) Then
  Begin
    ExprFlushToAX(L);
    EmitInstr('PUSH   AX');          { sous-chaine a chercher }
    ExprFlushToAX(R);
    EmitInstr('MOV    SI, AX');      { SI = chaine principale }
    EmitInstr('POP    DI');          { DI = sous-chaine       }
    EmitInstr('CALL   ' + PY_RT_PFX + 'STRCONTAINS');
    If Op = 'not in' Then
    Begin
      EmitInstr('TEST   AX, AX');
      EmitInstr('MOV    AX, 0');
      EmitInstr('JNZ    $+4');
      EmitInstr('INC    AX');
    End;
    L.Kind    := EK_AX;
    L.TypeIdx := TY_IDX_INT;
    L.SymIdx  := -1;
    Exit;
  End;

  { ---- TODO 11 : Operateur in / not in -------------------- }
  If (Op = 'in') Or (Op = 'not in') Then
  Begin
    ExprFlushToAX(L);
    EmitInstr('PUSH   AX');          { element a chercher }
    ExprFlushToAX(R);
    EmitInstr('MOV    SI, AX');      { SI = collection   }
    EmitInstr('POP    AX');          { AX = element      }
    EmitInstr('CALL   ' + PY_RT_PFX + 'CONTAINS');
    If Op = 'not in' Then
    Begin
      EmitInstr('TEST   AX, AX');
      EmitInstr('MOV    AX, 0');
      EmitInstr('JNZ    $+4');
      EmitInstr('INC    AX');
    End;
    L.Kind    := EK_AX;
    L.TypeIdx := TY_IDX_INT;
    L.SymIdx  := -1;
    Exit;
  End;

  { ---- Cas general : emission 8086 ------------------------- }
  ExprFlushToAX(L);

  If R.Kind = EK_IMM Then
  Begin
    Str(R.ImmVal, RS);
    If      Op = '+'   Then EmitInstr('ADD    AX, ' + RS)
    Else If Op = '-'   Then EmitInstr('SUB    AX, ' + RS)
    Else If Op = '&'   Then EmitInstr('AND    AX, ' + RS)
    Else If Op = '|'   Then EmitInstr('OR     AX, ' + RS)
    Else If Op = '^'   Then EmitInstr('XOR    AX, ' + RS)
    Else If Op = '<<'  Then
    Begin
      EmitInstr('MOV    CL, ' + RS);
      EmitInstr('SHL    AX, CL');
    End
    Else If Op = '>>'  Then
    Begin
      EmitInstr('MOV    CL, ' + RS);
      EmitInstr('SAR    AX, CL');
    End
    Else If Op = '*'   Then
    Begin
      EmitInstr('MOV    BX, ' + RS);
      EmitInstr('IMUL   BX');
    End
    Else If Op = '**'  Then
    Begin
      EmitInstr('MOV    CX, ' + RS);
      EmitInstr('CALL   ' + PY_RT_PFX + 'POWER');
    End
    Else If (Op = '/') Or (Op = '//') Then
    Begin
      EmitInstr('MOV    BX, ' + RS);
      EmitInstr('CWD');
      EmitInstr('IDIV   BX');
    End
    Else If Op = '%'   Then
    Begin
      EmitInstr('MOV    BX, ' + RS);
      EmitInstr('CWD');
      EmitInstr('IDIV   BX');
      EmitInstr('MOV    AX, DX');
    End
    Else If Op = '=='  Then
    Begin
      EmitInstr('CMP    AX, ' + RS);
      EmitInstr('MOV    AX, 0');
      EmitInstr('JNE    $+4');
      EmitInstr('INC    AX');
    End
    Else If Op = '!='  Then
    Begin
      EmitInstr('CMP    AX, ' + RS);
      EmitInstr('MOV    AX, 0');
      EmitInstr('JE     $+4');
      EmitInstr('INC    AX');
    End
    Else If Op = '<'   Then
    Begin
      EmitInstr('CMP    AX, ' + RS);
      EmitInstr('MOV    AX, 0');
      EmitInstr('JGE    $+4');
      EmitInstr('INC    AX');
    End
    Else If Op = '<='  Then
    Begin
      EmitInstr('CMP    AX, ' + RS);
      EmitInstr('MOV    AX, 0');
      EmitInstr('JG     $+4');
      EmitInstr('INC    AX');
    End
    Else If Op = '>'   Then
    Begin
      EmitInstr('CMP    AX, ' + RS);
      EmitInstr('MOV    AX, 0');
      EmitInstr('JLE    $+4');
      EmitInstr('INC    AX');
    End
    Else If Op = '>='  Then
    Begin
      EmitInstr('CMP    AX, ' + RS);
      EmitInstr('MOV    AX, 0');
      EmitInstr('JL     $+4');
      EmitInstr('INC    AX');
    End
    Else If (Op = 'is') Or (Op = 'is not') Then
    Begin
      EmitInstr('CMP    AX, ' + RS);
      EmitInstr('MOV    AX, 0');
      If Op = 'is' Then
        EmitInstr('JNE    $+4')
      Else
        EmitInstr('JE     $+4');
      EmitInstr('INC    AX');
    End;
  End
  Else
  Begin
    { R non immediat : sauvegarder L dans la pile, charger R dans BX }
    EmitInstr('PUSH   AX');
    ExprFlushToAX(R);
    EmitInstr('MOV    BX, AX');
    EmitInstr('POP    AX');
    If      Op = '+'  Then EmitInstr('ADD    AX, BX')
    Else If Op = '-'  Then EmitInstr('SUB    AX, BX')
    Else If Op = '&'  Then EmitInstr('AND    AX, BX')
    Else If Op = '|'  Then EmitInstr('OR     AX, BX')
    Else If Op = '^'  Then EmitInstr('XOR    AX, BX')
    Else If Op = '<<' Then
    Begin
      EmitInstr('MOV    CX, BX');
      EmitInstr('SHL    AX, CL');
    End
    Else If Op = '>>' Then
    Begin
      EmitInstr('MOV    CX, BX');
      EmitInstr('SAR    AX, CL');
    End
    Else If Op = '*'  Then EmitInstr('IMUL   BX')
    Else If Op = '**' Then
    Begin
      EmitInstr('MOV    CX, BX');
      EmitInstr('CALL   ' + PY_RT_PFX + 'POWER');
    End
    Else If (Op = '/') Or (Op = '//') Then
    Begin
      EmitInstr('CWD');
      EmitInstr('IDIV   BX');
    End
    Else If Op = '%' Then
    Begin
      EmitInstr('CWD');
      EmitInstr('IDIV   BX');
      EmitInstr('MOV    AX, DX');
    End
    Else
    Begin
      { Comparaison : CMP AX, BX + branchement conditionnel }
      EmitInstr('CMP    AX, BX');
      EmitInstr('MOV    AX, 0');
      If      Op = '=='     Then EmitInstr('JNE    $+4')
      Else If Op = '!='     Then EmitInstr('JE     $+4')
      Else If Op = '<'      Then EmitInstr('JGE    $+4')
      Else If Op = '<='     Then EmitInstr('JG     $+4')
      Else If Op = '>'      Then EmitInstr('JLE    $+4')
      Else If Op = '>='     Then EmitInstr('JL     $+4')
      Else If Op = 'is'     Then EmitInstr('JNE    $+4')
      Else If Op = 'is not' Then EmitInstr('JE     $+4');
      EmitInstr('INC    AX');
    End;
  End;
  L.Kind    := EK_AX;
  L.SymIdx  := -1;
End;

{ ---- ParsePrimary : atome du parseur Pratt (TODO 10) --------- }
{ Gere : litteraux entiers, flottants, chaines, True/False/None, }
{ identifiants + appel de fonction, parentheses / tuple,          }
{ liste literale, dict literale, postfixes [i], [a:b], .attr.     }
Procedure ParsePrimary(Var Res : TExprVal);
Var
  E      : TExprVal;
  IdxSym : Integer;
  IdxE   : TExprVal;
  LblNeg : TString;
  AttrName : TString;
  ArgE   : TExprVal;
  I      : Integer;
  ArgCount : Integer;
Begin
  ExprMakeNone(Res);
  Case CurToken.Kind Of

    { Litteraux : deleguer a LitEval }
    TK_INTEGER, TK_FLOAT, TK_STRING :
    Begin
      LitEval(CurToken, Res);
      ParserAdvance;
    End;

    { Mots-cles litteraux : True, False, None }
    TK_KEYWORD :
    Begin
      If (CurToken.Val = 'True') Or (CurToken.Val = 'False') Or
         (CurToken.Val = 'None') Then
      Begin
        LitEval(CurToken, Res);
        ParserAdvance;
      End
      Else
      Begin
        { Mot-cle non litterale : pas un atome d expression }
        ExprMakeNone(Res);
      End;
    End;

    { Identifiant : resolution via SymFind (TODO 05/09/10) }
    TK_IDENT :
    Begin
      IdxSym := SymFind(CurToken.Val);
      If IdxSym >= 0 Then
      Begin
        EmitComment('ident: ' + CurToken.Val +
                    ' [' + SymTab[IdxSym].MangledName + ']');
        Res.SymIdx := IdxSym;
        { Builtin ou fonction : gerer l appel (TODO 10) }
        If (SymTab[IdxSym].Kind = SK_BUILTIN) Or
           (SymTab[IdxSym].Kind = SK_FUNC) Then
        Begin
          ExprMakeImm(0, SymTab[IdxSym].TypeIdx, Res);
          Res.SymIdx := IdxSym;
        End
        Else
        Begin
          { Variable : retourner EK_MEM pour acces lecture/ecriture }
          Res.Kind    := EK_MEM;
          Res.TypeIdx := SymTab[IdxSym].TypeIdx;
          Res.Offset  := SymTab[IdxSym].Offset;
        End;
      End
      Else
      Begin
        { Identifiant inconnu : auto-declarer comme variable globale }
        EmitComment('ident (auto): ' + CurToken.Val);
        IdxSym := SymAdd(CurToken.Val, SK_VAR, TY_UNKNOWN, 0);
        Res.SymIdx := IdxSym;
        Res.Kind    := EK_MEM;
        Res.TypeIdx := TY_UNKNOWN;
        Res.Offset  := 0;
        If IdxSym < 0 Then Res.SymIdx := -1;
      End;
      ParserAdvance;
      { Appel de fonction / builtin : f(args) (TODO 10) }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        ParseCallArgs(Res.SymIdx, Res);
    End;

    { Parentheses de groupement ou tuple literal (TODO 10/19) }
    TK_PUNCT :
    Begin
      If CurToken.Val = '(' Then
      Begin
        ParserAdvance;
        { Tuple vide : () }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        Begin
          ParserAdvance;
          EmitComment('tuple vide');
          { Allouer un tuple vide avec count=0 sur le heap }
          EmitInstr('MOV    DI, [_PY_HEAPTOP]');
          EmitInstr('ADD    DI, OFFSET _PY_HEAP');
          EmitInstr('MOV    WORD PTR [DI], 0');
          EmitInstr('ADD    WORD PTR [_PY_HEAPTOP], 2');
          EmitInstr('MOV    AX, DI');
          ExprMakeAX(TY_IDX_TUPLE, Res);
        End
        Else
        Begin
          ParseExpr(E);
          { Verifier si c est un tuple : (e1, e2, ...) ou (e1,) }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          Begin
            EmitComment('tuple literal');
            { Allouer sur le heap }
            ExprFlushToAX(E);
            EmitInstr('MOV    DI, [_PY_HEAPTOP]');
            EmitInstr('ADD    DI, OFFSET _PY_HEAP');
            EmitInstr('MOV    [DI+2], AX');     { elem 0 }
            ArgCount := 1;
            While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
            Begin
              ParserAdvance;
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                Break;
              ParseExpr(IdxE);
              ExprFlushToAX(IdxE);
              EmitInstr('MOV    [DI+' + IntToStr_(2 + ArgCount * 2) + '], AX');
              Inc(ArgCount);
            End;
            { Ecrire le count en tete }
            EmitInstr('MOV    WORD PTR [DI], ' + IntToStr_(ArgCount));
            { Mettre a jour HEAPTOP }
            EmitInstr('ADD    WORD PTR [_PY_HEAPTOP], ' +
                      IntToStr_((ArgCount + 1) * 2));
            EmitInstr('MOV    AX, DI');
            ExprMakeAX(TY_IDX_TUPLE, E);
          End;
          Res := E;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance
          Else
            CompileError(''')'' attendue', CurToken.Line);
        End;
      End
      Else If CurToken.Val = '[' Then
        ParseListLiteral(Res)
      Else If CurToken.Val = '{' Then
        ParseDictLiteral(Res)
      Else
        ExprMakeNone(Res);
    End;

  Else
    ExprMakeNone(Res);
  End;

  { Postfixes : index [i], slice [a:b], attribut .attr (TODO 10) }
  While (CurToken.Kind = TK_PUNCT) And
        ((CurToken.Val = '[') Or (CurToken.Val = '.')) Do
  Begin
    If CurToken.Val = '[' Then
    Begin
      { Acces index ou slice : expr[i] ou expr[a:b] }
      ExprFlushToAX(Res);
      EmitInstr('MOV    SI, AX');   { SI = objet }
      ParserAdvance;
      ParseExpr(IdxE);
      { Detecter slice : [a:b] }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      Begin
        If Res.TypeIdx = TY_IDX_STR Then
        Begin
          { Slice sur chaine : s[a:b] -> CALL _PYRT_STRSLICE (TODO 20) }
          EmitComment('str slice [a:b]');
          ExprFlushToAX(IdxE);
          EmitInstr('PUSH   AX');   { sauvegarder a }
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
          Begin
            EmitInstr('MOV    BX, 0FFFFh'); { b = fin }
            EmitInstr('POP    AX');         { AX = a }
          End
          Else
          Begin
            ParseExpr(E);
            ExprFlushToAX(E);
            EmitInstr('MOV    BX, AX');   { BX = b }
            EmitInstr('POP    AX');       { AX = a }
          End;
          EmitInstr('CALL   ' + PY_RT_PFX + 'STRSLICE');
        End
        Else
        Begin
          { Slice : expr[a:b] }
          EmitComment('slice [a:b]');
          ExprFlushToAX(IdxE);
          EmitInstr('PUSH   AX');   { sauvegarder a }
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
          Begin
            EmitInstr('MOV    BX, 0FFFFh'); { b = fin }
            EmitInstr('POP    AX');         { AX = a }
          End
          Else
          Begin
            ParseExpr(E);
            ExprFlushToAX(E);
            EmitInstr('MOV    BX, AX');   { BX = b }
            EmitInstr('POP    AX');       { AX = a }
          End;
          EmitInstr('CALL   ' + PY_RT_PFX + 'SLICE');
        End;
      End
      Else
      Begin
        If Res.TypeIdx = TY_IDX_DICT Then
        Begin
          { Dict access by key : d[key] -> DICTGET }
          EmitComment('dict access [key]');
          ExprFlushToAX(IdxE);
          EmitInstr('CALL   ' + PY_RT_PFX + 'DICTGET');
        End
        Else If Res.TypeIdx = TY_IDX_STR Then
        Begin
          { Index chaine : s[i] -> caractere comme chaine (TODO 20) }
          EmitComment('str index [i]');
          ExprFlushToAX(IdxE);
          EmitInstr('MOV    BX, AX');          { BX = index }
          EmitInstr('TEST   BX, BX');
          LblNeg := LabelGen;
          EmitInstr('JGE    ' + LblNeg);
          { index negatif : i + strlen(s) }
          EmitInstr('PUSH   BX');
          EmitInstr('CALL   ' + PY_RT_PFX + 'LEN');
          EmitInstr('POP    BX');
          EmitInstr('ADD    BX, AX');
          EmitLabel(LblNeg);
          EmitInstr('ADD    SI, BX');
          EmitInstr('XOR    AH, AH');
          EmitInstr('MOV    AL, [SI]');
          { Stocker le caractere dans STRBUF2 comme chaine 1 char }
          EmitInstr('MOV    BYTE PTR [_PY_STRBUF2], AL');
          EmitInstr('MOV    BYTE PTR [_PY_STRBUF2+1], 0');
          EmitInstr('MOV    AX, OFFSET _PY_STRBUF2');
        End
        Else
        Begin
          { Index simple : expr[i] (TODO 15 : skip count header + neg) }
          EmitComment('index [i]');
          ExprFlushToAX(IdxE);
          EmitInstr('PUSH   SI');
          EmitInstr('MOV    BX, AX');
          LblNeg := LabelGen;
          EmitInstr('TEST   BX, BX');
          EmitInstr('JGE    ' + LblNeg);
          EmitInstr('ADD    BX, [SI]');    { index negatif : i + len }
          EmitLabel(LblNeg);
          EmitInstr('SHL    BX, 1');
          EmitInstr('ADD    BX, 2');       { sauter l en-tete count }
          EmitInstr('POP    SI');
          EmitInstr('ADD    SI, BX');
          EmitInstr('MOV    AX, [SI]');
        End;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
        ParserAdvance
      Else
        CompileError(''']'' attendue', CurToken.Line);
      If Res.TypeIdx = TY_IDX_STR Then
        ExprMakeAX(TY_IDX_STR, Res)
      Else
        ExprMakeAX(TY_IDX_INT, Res);
    End
    Else If CurToken.Val = '.' Then
    Begin
      { Acces attribut : expr.attr (TODO 15 : methodes liste) }
      ExprFlushToAX(Res);
      EmitInstr('MOV    SI, AX');   { SI = instance }
      ParserAdvance;
      If CurToken.Kind = TK_IDENT Then
      Begin
        AttrName := CurToken.Val;
        EmitComment('attr: .' + AttrName);
        ParserAdvance;

        { --- Acces module.fonction (TODO 23) --- }
        If Res.TypeIdx = TY_IDX_MODULE Then
        Begin
          { Identifier le module via SymIdx }
          If (Res.SymIdx >= 0) And (SymTab[Res.SymIdx].Name = 'math') Then
          Begin
            { math.abs, math.pow, math.min, math.max }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
            Begin
              IdxSym := SymFind(AttrName);
              If IdxSym < 0 Then
              Begin
                { Auto-ajouter pow comme builtin si besoin }
                If AttrName = 'pow' Then
                Begin
                  IdxSym := SymAdd('pow', SK_BUILTIN, TY_IDX_INT, 0);
                  If IdxSym >= 0 Then
                    SymTab[IdxSym].IsImported := True;
                End;
              End;
              If IdxSym >= 0 Then
                ParseCallArgs(IdxSym, Res)
              Else
              Begin
                WarnMsg('math.' + AttrName + ' non supporte', CurToken.Line);
                ParserAdvance;  { consommer '(' }
                While (CurToken.Kind <> TK_EOF) And
                      Not ((CurToken.Kind = TK_PUNCT) And
                           (CurToken.Val = ')')) Do
                  ParserAdvance;
                If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                  ParserAdvance;
                ExprMakeAX(TY_IDX_INT, Res);
              End;
            End
            Else
            Begin
              WarnMsg('math.' + AttrName + ' utilise sans appel', CurToken.Line);
              ExprMakeAX(TY_IDX_INT, Res);
            End;
          End
          Else If (Res.SymIdx >= 0) And (SymTab[Res.SymIdx].Name = 'sys') Then
          Begin
            If (AttrName = 'exit') And
               (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
            Begin
              { sys.exit(code) -> MOV AX,4C00h+code / INT 21h }
              EmitComment('sys.exit(code)');
              ParserAdvance;  { consommer '(' }
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              Begin
                { sys.exit() sans argument = exit(0) }
                ParserAdvance;
                EmitInstr('MOV    AX, 4C00h');
                EmitInstr('INT    21h');
              End
              Else
              Begin
                ParseExpr(ArgE);
                ExprFlushToAX(ArgE);
                EmitInstr('MOV    AH, 4Ch');
                EmitInstr('INT    21h');
                If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                  ParserAdvance;
              End;
              ExprMakeAX(TY_IDX_NONE, Res);
            End
            Else If AttrName = 'argv' Then
            Begin
              WarnMsg('sys.argv non supporte', CurToken.Line);
              ExprMakeImm(0, TY_IDX_NONE, Res);
            End
            Else
            Begin
              WarnMsg('sys.' + AttrName + ' non supporte', CurToken.Line);
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
              Begin
                ParserAdvance;
                While (CurToken.Kind <> TK_EOF) And
                      Not ((CurToken.Kind = TK_PUNCT) And
                           (CurToken.Val = ')')) Do
                  ParserAdvance;
                If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                  ParserAdvance;
              End;
              ExprMakeAX(TY_IDX_NONE, Res);
            End;
          End
          Else If (Res.SymIdx >= 0) And (SymTab[Res.SymIdx].Name = 'os') Then
          Begin
            WarnMsg('os.' + AttrName + ' non supporte', CurToken.Line);
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
            Begin
              ParserAdvance;
              While (CurToken.Kind <> TK_EOF) And
                    Not ((CurToken.Kind = TK_PUNCT) And
                         (CurToken.Val = ')')) Do
                ParserAdvance;
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                ParserAdvance;
            End;
            ExprMakeAX(TY_IDX_NONE, Res);
          End
          Else
          Begin
            { Module externe : appel module.fonction }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
            Begin
              EmitComment('module call: ' + SymTab[Res.SymIdx].Name +
                          '.' + AttrName);
              IdxSym := SymFind(AttrName);
              If IdxSym >= 0 Then
                ParseCallArgs(IdxSym, Res)
              Else
              Begin
                EmitInstr('CALL   _PYM_' + SymTab[Res.SymIdx].Name +
                          '_' + AttrName);
                ParserAdvance;  { consommer '(' }
                While (CurToken.Kind <> TK_EOF) And
                      Not ((CurToken.Kind = TK_PUNCT) And
                           (CurToken.Val = ')')) Do
                  ParserAdvance;
                If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                  ParserAdvance;
                ExprMakeAX(TY_IDX_INT, Res);
              End;
            End
            Else
            Begin
              EmitInstr('MOV    AX, [_PYM_' + SymTab[Res.SymIdx].Name +
                        '_' + AttrName + ']');
              ExprMakeAX(TY_IDX_INT, Res);
            End;
          End;
        End
        Else
        { --- Methodes de liste (TODO 15) --- }
        If (Res.TypeIdx = TY_IDX_LIST) And
           (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          If AttrName = 'append' Then
          Begin
            { lst.append(val) : SI=liste, AX=val }
            EmitInstr('PUSH   SI');
            ParserAdvance;  { consommer '(' }
            ParseExpr(ArgE);
            ExprFlushToAX(ArgE);
            EmitInstr('POP    SI');
            EmitInstr('CALL   ' + PY_RT_PFX + 'LISTAPPEND');
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            ExprMakeAX(TY_IDX_NONE, Res);
          End
          Else If AttrName = 'pop' Then
          Begin
            { lst.pop() : SI=liste -> AX=element }
            ParserAdvance;  { consommer '(' }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            EmitInstr('CALL   ' + PY_RT_PFX + 'LISTPOP');
            ExprMakeAX(TY_IDX_INT, Res);
          End
          Else If AttrName = 'insert' Then
          Begin
            { lst.insert(i, val) : SI=liste, AX=index, BX=val }
            EmitInstr('PUSH   SI');
            ParserAdvance;  { consommer '(' }
            ParseExpr(ArgE);
            ExprFlushToAX(ArgE);
            EmitInstr('PUSH   AX');  { sauver index }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
              ParserAdvance;
            ParseExpr(ArgE);
            ExprFlushToAX(ArgE);
            EmitInstr('MOV    BX, AX');  { BX = val }
            EmitInstr('POP    AX');      { AX = index }
            EmitInstr('POP    SI');      { SI = liste }
            EmitInstr('CALL   ' + PY_RT_PFX + 'LISTINSERT');
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            ExprMakeAX(TY_IDX_NONE, Res);
          End
          Else
          Begin
            { Methode inconnue : stub generique }
            EmitInstr('MOV    AX, [SI]');
            ParserAdvance;  { consommer '(' }
            While (CurToken.Kind <> TK_EOF) And
                  Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
              ParserAdvance;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            ExprMakeAX(TY_IDX_INT, Res);
          End;
        End
        Else If (Res.TypeIdx = TY_IDX_STR) And
           (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          { --- Methodes de chaine (TODO 20) --- }
          If AttrName = 'upper' Then
          Begin
            { s.upper() : SI=chaine -> AX=ptr nouvelle chaine majuscules }
            ParserAdvance;  { consommer '(' }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            EmitInstr('CALL   ' + PY_RT_PFX + 'STRUPPER');
            ExprMakeAX(TY_IDX_STR, Res);
          End
          Else If AttrName = 'lower' Then
          Begin
            { s.lower() : SI=chaine -> AX=ptr nouvelle chaine minuscules }
            ParserAdvance;  { consommer '(' }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            EmitInstr('CALL   ' + PY_RT_PFX + 'STRLOWER');
            ExprMakeAX(TY_IDX_STR, Res);
          End
          Else If AttrName = 'strip' Then
          Begin
            { s.strip() : SI=chaine -> AX=ptr chaine sans espaces }
            ParserAdvance;  { consommer '(' }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            EmitInstr('CALL   ' + PY_RT_PFX + 'STRSTRIP');
            ExprMakeAX(TY_IDX_STR, Res);
          End
          Else If AttrName = 'find' Then
          Begin
            { s.find(sub) : SI=chaine, DI=sous-chaine -> AX=index ou -1 }
            EmitInstr('PUSH   SI');
            ParserAdvance;  { consommer '(' }
            ParseExpr(ArgE);
            ExprFlushToAX(ArgE);
            EmitInstr('MOV    DI, AX');   { DI = sous-chaine }
            EmitInstr('POP    SI');       { SI = chaine }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            EmitInstr('CALL   ' + PY_RT_PFX + 'STRFIND');
            ExprMakeAX(TY_IDX_INT, Res);
          End
          Else If AttrName = 'replace' Then
          Begin
            { s.replace(old, new) : SI=chaine, DI=old, DX=new -> AX=ptr }
            EmitInstr('PUSH   SI');
            ParserAdvance;  { consommer '(' }
            ParseExpr(ArgE);
            ExprFlushToAX(ArgE);
            EmitInstr('PUSH   AX');  { sauver old }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
              ParserAdvance;
            ParseExpr(ArgE);
            ExprFlushToAX(ArgE);
            EmitInstr('MOV    DX, AX');  { DX = new }
            EmitInstr('POP    DI');      { DI = old }
            EmitInstr('POP    SI');      { SI = chaine }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            EmitInstr('CALL   ' + PY_RT_PFX + 'STRREPLACE');
            ExprMakeAX(TY_IDX_STR, Res);
          End
          Else If AttrName = 'split' Then
          Begin
            { s.split(sep) : SI=chaine, DI=sep -> AX=ptr liste }
            EmitInstr('PUSH   SI');
            ParserAdvance;  { consommer '(' }
            ParseExpr(ArgE);
            ExprFlushToAX(ArgE);
            EmitInstr('MOV    DI, AX');   { DI = separateur }
            EmitInstr('POP    SI');       { SI = chaine }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            EmitInstr('CALL   ' + PY_RT_PFX + 'STRSPLIT');
            ExprMakeAX(TY_IDX_LIST, Res);
          End
          Else If AttrName = 'startswith' Then
          Begin
            { s.startswith(prefix) : SI=chaine, DI=prefix -> AX=0|1 }
            EmitInstr('PUSH   SI');
            ParserAdvance;  { consommer '(' }
            ParseExpr(ArgE);
            ExprFlushToAX(ArgE);
            EmitInstr('MOV    DI, AX');   { DI = prefix }
            EmitInstr('POP    SI');       { SI = chaine }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            EmitInstr('CALL   ' + PY_RT_PFX + 'STARTSWITH');
            ExprMakeAX(TY_IDX_BOOL, Res);
          End
          Else If AttrName = 'endswith' Then
          Begin
            { s.endswith(suffix) : SI=chaine, DI=suffix -> AX=0|1 }
            EmitInstr('PUSH   SI');
            ParserAdvance;  { consommer '(' }
            ParseExpr(ArgE);
            ExprFlushToAX(ArgE);
            EmitInstr('MOV    DI, AX');   { DI = suffix }
            EmitInstr('POP    SI');       { SI = chaine }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            EmitInstr('CALL   ' + PY_RT_PFX + 'ENDSWITH');
            ExprMakeAX(TY_IDX_BOOL, Res);
          End
          Else If AttrName = 'count' Then
          Begin
            { s.count(sub) : SI=chaine, DI=sous-chaine -> AX=nombre }
            EmitInstr('PUSH   SI');
            ParserAdvance;  { consommer '(' }
            ParseExpr(ArgE);
            ExprFlushToAX(ArgE);
            EmitInstr('MOV    DI, AX');   { DI = sous-chaine }
            EmitInstr('POP    SI');       { SI = chaine }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            EmitInstr('CALL   ' + PY_RT_PFX + 'STRCOUNT');
            ExprMakeAX(TY_IDX_INT, Res);
          End
          Else
          Begin
            { Methode str inconnue : stub generique }
            EmitInstr('MOV    AX, SI');
            ParserAdvance;  { consommer '(' }
            While (CurToken.Kind <> TK_EOF) And
                  Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
              ParserAdvance;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            ExprMakeAX(TY_IDX_STR, Res);
          End;
        End
        Else If (Res.TypeIdx = TY_IDX_DICT) And
           (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          If AttrName = 'get' Then
          Begin
            { d.get(key, default) : SI=dict, AX=key, BX=default }
            EmitInstr('PUSH   SI');
            ParserAdvance;  { consommer '(' }
            ParseExpr(ArgE);
            ExprFlushToAX(ArgE);
            EmitInstr('PUSH   AX');  { sauver key }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            Begin
              ParserAdvance;
              ParseExpr(ArgE);
              ExprFlushToAX(ArgE);
              EmitInstr('MOV    BX, AX');  { BX = default }
            End
            Else
              EmitInstr('XOR    BX, BX');  { default = 0 }
            EmitInstr('POP    AX');      { AX = key }
            EmitInstr('POP    SI');      { SI = dict }
            EmitInstr('CALL   ' + PY_RT_PFX + 'DICTGETDEF');
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            ExprMakeAX(TY_IDX_INT, Res);
          End
          Else If AttrName = 'keys' Then
          Begin
            { d.keys() : SI=dict -> AX=new list }
            ParserAdvance;  { consommer '(' }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            EmitInstr('CALL   ' + PY_RT_PFX + 'DICTKEYS');
            ExprMakeAX(TY_IDX_LIST, Res);
          End
          Else If AttrName = 'values' Then
          Begin
            { d.values() : SI=dict -> AX=new list }
            ParserAdvance;  { consommer '(' }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            EmitInstr('CALL   ' + PY_RT_PFX + 'DICTVALS');
            ExprMakeAX(TY_IDX_LIST, Res);
          End
          Else
          Begin
            { Methode dict inconnue : stub generique }
            EmitInstr('MOV    AX, [SI]');
            ParserAdvance;  { consommer '(' }
            While (CurToken.Kind <> TK_EOF) And
                  Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
              ParserAdvance;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            ExprMakeAX(TY_IDX_INT, Res);
          End;
        End
        Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          { Appel de methode : obj.method(args) (TODO 18 enrichi) }
          { SI = pointeur objet, AttrName = nom methode           }
          { Chercher la methode dans TOUTES les classes            }
          I := -1;
          IdxSym := -1;
          For ArgCount := 0 To ClassCount - 1 Do
          Begin
            I := ClassFindMeth(ArgCount, AttrName);
            If I >= 0 Then
            Begin
              IdxSym := ArgCount;  { reutiliser IdxSym pour stocker le clsIdx }
              Break;
            End;
          End;
          If I >= 0 Then
          Begin
            EmitComment('method call: .' + AttrName);
            EmitInstr('PUSH   SI');     { sauver self }
            ParserAdvance;  { consommer '(' }
            ArgCount := 0;
            { Empiler les arguments }
            If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
            Begin
              ParseExpr(ArgE);
              ExprFlushToAX(ArgE);
              EmitInstr('PUSH   AX');
              Inc(ArgCount);
              While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
              Begin
                ParserAdvance;
                ParseExpr(ArgE);
                ExprFlushToAX(ArgE);
                EmitInstr('PUSH   AX');
                Inc(ArgCount);
              End;
            End;
            { Empiler self comme premier parametre }
            EmitInstr('PUSH   SI');
            EmitInstr('CALL   ' + ClassTab[IdxSym].MethLabels[I]);
            EmitInstr('ADD    SP, ' + IntToStr_((ArgCount + 1) * 2));
            EmitInstr('POP    SI');  { restaurer SI }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            ExprMakeAX(TY_IDX_INT, Res);
          End
          Else
          Begin
            { Methode non trouvee : stub generique }
            EmitInstr('MOV    AX, [SI]');
            ParserAdvance;
            While (CurToken.Kind <> TK_EOF) And
                  Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
              ParserAdvance;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            ExprMakeAX(TY_IDX_INT, Res);
          End;
        End
        Else
        Begin
          { Acces attribut : obj.attr (TODO 18 enrichi) }
          { SI = pointeur objet, AttrName = nom attribut }
          { Chercher l attribut dans toutes les classes }
          I := -1;
          For ArgCount := 0 To ClassCount - 1 Do
          Begin
            I := ClassFindAttr(ArgCount, AttrName);
            If I >= 0 Then Break;
          End;
          If I >= 0 Then
          Begin
            EmitComment('attr read: .' + AttrName);
            EmitInstr('MOV    BX, SI');
            EmitInstr('MOV    AX, [BX+' + IntToStr_(2 + I * 2) + ']');
            ExprMakeAX(TY_IDX_INT, Res);
          End
          Else
          Begin
            { Attribut non trouve : offset 0 par defaut }
            EmitInstr('MOV    AX, [SI]');
            ExprMakeAX(TY_IDX_INT, Res);
          End;
        End;
      End
      Else
        CompileError('identifiant attendu apres ''.''', CurToken.Line);
      ExprMakeAX(TY_IDX_INT, Res);
    End;
  End;
End;

{ ---- ParseUnary : operateurs unaires Python ------------------ }
{ Gere : - (negation), + (identite), ~ (complement bit a bit),  }
{ not (negation logique).                                         }
Procedure ParseUnary(Var Res : TExprVal);
Begin
  { Unaire '-' }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '-') Then
  Begin
    ParserAdvance;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
      Res.ImmVal := -Res.ImmVal
    Else
    Begin
      ExprFlushToAX(Res);
      EmitInstr('NEG    AX');
      Res.Kind := EK_AX;
    End;
    Exit;
  End;

  { Unaire '+' : identite }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '+') Then
  Begin
    ParserAdvance;
    ParseUnary(Res);
    Exit;
  End;

  { Unaire '~' : complement bit a bit }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '~') Then
  Begin
    ParserAdvance;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
      Res.ImmVal := Not Res.ImmVal
    Else
    Begin
      ExprFlushToAX(Res);
      EmitInstr('NOT    AX');
      Res.Kind := EK_AX;
    End;
    Exit;
  End;

  { Unaire 'not' : negation logique }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'not') Then
  Begin
    ParserAdvance;
    { Detecter 'not in' (operateur binaire combine) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'in') Then
    Begin
      { 'not in' sera gere comme operateur binaire par ParseExprPrec }
      { On recule : c est a ParseExprPrec de le gerer                }
      { Non - on parse l operande unaire 'not' normalement           }
      ParseUnary(Res);
      If Res.Kind = EK_IMM Then
      Begin
        If Res.ImmVal <> 0 Then Res.ImmVal := 0 Else Res.ImmVal := 1;
      End
      Else
      Begin
        ExprFlushToAX(Res);
        EmitInstr('TEST   AX, AX');
        EmitInstr('MOV    AX, 0');
        EmitInstr('JNZ    $+4');
        EmitInstr('INC    AX');
        Res.Kind := EK_AX;
      End;
      Res.TypeIdx := TY_IDX_BOOL;
      Exit;
    End;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
    Begin
      If Res.ImmVal <> 0 Then Res.ImmVal := 0 Else Res.ImmVal := 1;
    End
    Else
    Begin
      ExprFlushToAX(Res);
      EmitInstr('TEST   AX, AX');
      EmitInstr('MOV    AX, 0');
      EmitInstr('JNZ    $+4');
      EmitInstr('INC    AX');
      Res.Kind := EK_AX;
    End;
    Res.TypeIdx := TY_IDX_BOOL;
    Exit;
  End;

  { Pas d operateur unaire : deleguer a ParsePrimary }
  ParsePrimary(Res);
End;

{ ---- ParseExprPrec : parseur Pratt pour expressions Python --- }
{ Boucle de montee de precedence pour operateurs binaires.       }
{ MinPrec = niveau de precedence minimal a capturer.             }
{ AX = gauche, BX = droite pour emission binaire.                }
{ Court-circuit pour and/or. Pliage de constantes via            }
{ ExprEmitBinOp.                                                  }
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
    { Mots-cles operateurs : and, or, in, is, not (in) }
    Else If CurToken.Kind = TK_KEYWORD Then
    Begin
      If (CurToken.Val = 'and') Or (CurToken.Val = 'or') Then
      Begin
        Op   := CurToken.Val;
        Prec := BinOpPrec(Op);
      End
      Else If CurToken.Val = 'in' Then
      Begin
        Op   := 'in';
        Prec := BinOpPrec('in');
      End
      Else If CurToken.Val = 'is' Then
      Begin
        Op   := 'is';
        Prec := BinOpPrec('is');
      End
      Else If CurToken.Val = 'not' Then
      Begin
        { Lookahead pour 'not in' }
        Op := 'not';
        Prec := 0;
      End;
    End;

    { Verifier si la precedence est suffisante }
    If (Prec = 0) Or (Prec < MinPrec) Then Break;

    { Gerer 'is not' (deux tokens) }
    If Op = 'is' Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'not') Then
      Begin
        Op := 'is not';
        ParserAdvance;
      End;
    End
    { Gerer 'not in' (deux tokens depuis 'not') }
    Else If Op = 'not' Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'in') Then
      Begin
        Op := 'not in';
        Prec := BinOpPrec('not in');
        If Prec < MinPrec Then Break;
        ParserAdvance;
      End
      Else
      Begin
        { 'not' seul n est pas un operateur binaire ici }
        { On ne devrait pas arriver ici normalement      }
        Break;
      End;
    End
    Else
      ParserAdvance;  { consommer l operateur }

    { Calculer le seuil de precedence pour la droite }
    If BinOpIsRight(Op) Then
      NextPrec := Prec       { droit-associatif : meme niveau }
    Else
      NextPrec := Prec + 1;  { gauche-associatif : niveau + 1 }

    { Parser l operande droite }
    ParseExprPrec(NextPrec, Right);

    { Emettre le code binaire }
    ExprEmitBinOp(Op, Res, Right);

  Until False;
End;

{ ---- ParseExpr : parser une expression complete -------------- }
Procedure ParseExpr(Var Res : TExprVal);
Var
  CondRes  : TExprVal;
  ElseRes  : TExprVal;
  LblElse  : TString;
  LblEnd   : TString;
Begin
  ParseExprPrec(1, Res);
  { Expression ternaire : a if cond else b (TODO 13) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'if') Then
  Begin
    ParserAdvance;
    { Sauvegarder la valeur de a }
    ExprFlushToAX(Res);
    EmitInstr('PUSH   AX');
    { Parser la condition }
    ParseExprPrec(1, CondRes);
    ExprFlushToAX(CondRes);
    LblElse := LabelGen;
    LblEnd  := LabelGen;
    { Si condition fausse, aller au else }
    EmitInstr('TEST   AX, AX');
    EmitInstr('JZ     ' + LblElse);
    { Condition vraie : utiliser a (deja sur la pile) }
    EmitInstr('POP    AX');
    EmitInstr('JMP    ' + LblEnd);
    { Else }
    EmitLabel(LblElse);
    EmitInstr('ADD    SP, 2');
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'else') Then
    Begin
      ParserAdvance;
      ParseExprPrec(1, ElseRes);
      ExprFlushToAX(ElseRes);
    End
    Else
      CompileError('''else'' attendu dans expression ternaire', CurToken.Line);
    EmitLabel(LblEnd);
    ExprMakeAX(Res.TypeIdx, Res);
  End;
End;

{ ============================================================
  TODO 11 - EXPRESSIONS BINAIRES [IMPLEMENTE]
  ============================================================ }

{ ---- EmitExprRuntime : routines runtime pour expressions ----- }
{ Emettre les sous-programmes ASM 8086 pour les operations       }
{ binaires non triviales : concatenation, comparaison de         }
{ chaines, recherche dans une collection, puissance, et          }
{ logique not.                                                   }
Procedure EmitExprRuntime;
Begin
  EmitBlankLine;
  EmitComment('-- Runtime : expressions binaires (TODO 11) --');

  { _PYRT_CONCAT : SI=gauche, DI=droite -> AX=resultat (ptr _PY_STRBUF) }
  EmitLabel(PY_RT_PFX + 'CONCAT');
  EmitInstr('PUSH   DI');              { sauver droite }
  EmitInstr('MOV    DI, OFFSET _PY_STRBUF');
  { Copier gauche (SI) dans buf }
  EmitLabel(PY_RT_PFX + 'CC1');
  EmitInstr('LODSB');
  EmitInstr('TEST   AL, AL');
  EmitInstr('JZ     ' + PY_RT_PFX + 'CC2');
  EmitInstr('STOSB');
  EmitInstr('JMP    ' + PY_RT_PFX + 'CC1');
  EmitLabel(PY_RT_PFX + 'CC2');
  EmitInstr('POP    SI');              { SI = droite }
  { Copier droite dans buf }
  EmitLabel(PY_RT_PFX + 'CC3');
  EmitInstr('LODSB');
  EmitInstr('TEST   AL, AL');
  EmitInstr('JZ     ' + PY_RT_PFX + 'CC4');
  EmitInstr('STOSB');
  EmitInstr('JMP    ' + PY_RT_PFX + 'CC3');
  EmitLabel(PY_RT_PFX + 'CC4');
  EmitInstr('MOV    BYTE PTR [DI], 0');
  EmitInstr('MOV    AX, OFFSET _PY_STRBUF');
  EmitInstr('RET');

  { _PYRT_STRCMP : SI=gauche, DI=droite -> AX = -1/0/+1 }
  EmitLabel(PY_RT_PFX + 'STRCMP');
  EmitLabel(PY_RT_PFX + 'SC1');
  EmitInstr('MOV    AL, [SI]');
  EmitInstr('MOV    AH, [DI]');
  EmitInstr('CMP    AL, AH');
  EmitInstr('JB     ' + PY_RT_PFX + 'SCLT');
  EmitInstr('JA     ' + PY_RT_PFX + 'SCGT');
  EmitInstr('TEST   AL, AL');
  EmitInstr('JZ     ' + PY_RT_PFX + 'SCEQ');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstr('JMP    ' + PY_RT_PFX + 'SC1');
  EmitLabel(PY_RT_PFX + 'SCEQ');
  EmitInstr('XOR    AX, AX');
  EmitInstr('RET');
  EmitLabel(PY_RT_PFX + 'SCLT');
  EmitInstr('MOV    AX, -1');
  EmitInstr('RET');
  EmitLabel(PY_RT_PFX + 'SCGT');
  EmitInstr('MOV    AX, 1');
  EmitInstr('RET');

  { _PYRT_STRMUL : SI=chaine, CX=count -> AX=resultat (ptr _PY_STRBUF) }
  EmitLabel(PY_RT_PFX + 'STRMUL');
  EmitInstr('MOV    DI, OFFSET _PY_STRBUF');
  EmitInstr('TEST   CX, CX');
  EmitInstr('JLE    ' + PY_RT_PFX + 'SM_END');
  EmitLabel(PY_RT_PFX + 'SM_LP');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   SI');
  EmitLabel(PY_RT_PFX + 'SM_C');
  EmitInstr('LODSB');
  EmitInstr('TEST   AL, AL');
  EmitInstr('JZ     ' + PY_RT_PFX + 'SM_NX');
  EmitInstr('STOSB');
  EmitInstr('JMP    ' + PY_RT_PFX + 'SM_C');
  EmitLabel(PY_RT_PFX + 'SM_NX');
  EmitInstr('POP    SI');
  EmitInstr('POP    CX');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'SM_LP');
  EmitLabel(PY_RT_PFX + 'SM_END');
  EmitInstr('MOV    BYTE PTR [DI], 0');
  EmitInstr('MOV    AX, OFFSET _PY_STRBUF');
  EmitInstr('RET');

  { _PYRT_CONTAINS : AX=elem, SI=collection -> AX=0|1 (stub list scan) }
  EmitLabel(PY_RT_PFX + 'CONTAINS');
  EmitInstr('MOV    BX, AX');
  EmitInstr('MOV    CX, [SI]');       { CX = nombre d elements }
  EmitInstr('ADD    SI, 2');
  EmitInstr('TEST   CX, CX');
  EmitInstr('JZ     ' + PY_RT_PFX + 'CN_NO');
  EmitLabel(PY_RT_PFX + 'CN_LP');
  EmitInstr('LODSW');
  EmitInstr('CMP    AX, BX');
  EmitInstr('JE     ' + PY_RT_PFX + 'CN_YES');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'CN_LP');
  EmitLabel(PY_RT_PFX + 'CN_NO');
  EmitInstr('XOR    AX, AX');
  EmitInstr('RET');
  EmitLabel(PY_RT_PFX + 'CN_YES');
  EmitInstr('MOV    AX, 1');
  EmitInstr('RET');

  { _PYRT_NOT : AX -> AX = 0 si truthy, 1 si falsy }
  EmitLabel(PY_RT_PFX + 'NOT');
  EmitInstr('TEST   AX, AX');
  EmitInstr('MOV    AX, 0');
  EmitInstr('JNZ    $+4');
  EmitInstr('INC    AX');
  EmitInstr('RET');

  { _PYRT_POWER : AX=base, CX=exposant -> AX=resultat }
  { (deja partiellement present dans les appels, on emet le corps) }
  EmitLabel(PY_RT_PFX + 'POWER');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   DX');
  EmitInstr('MOV    BX, AX');        { BX = base }
  EmitInstr('MOV    AX, 1');         { AX = accumulateur = 1 }
  EmitInstr('TEST   CX, CX');
  EmitInstr('JLE    ' + PY_RT_PFX + 'PW_END');
  EmitLabel(PY_RT_PFX + 'PW_LP');
  EmitInstr('IMUL   BX');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'PW_LP');
  EmitLabel(PY_RT_PFX + 'PW_END');
  EmitInstr('POP    DX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
End;

{ ============================================================
  TODO 15 - LISTES : RUNTIME [IMPLEMENTE]
  ============================================================ }

{ ---- EmitListRuntime : routines runtime pour les listes ------ }
{ Layout liste : [count DW][elem0 DW][elem1 DW]...              }
{   _PYRT_SLICE       : SI=list, AX=start, BX=end -> AX=new    }
{   _PYRT_LISTAPPEND  : SI=list, AX=val -> modifie en place     }
{   _PYRT_LISTPOP     : SI=list -> AX=dernier element           }
{   _PYRT_LISTINSERT  : SI=list, AX=index, BX=val               }
{   _PYRT_LISTCONCAT  : SI=lst1, DI=lst2 -> AX=new list         }
{   _PYRT_LISTMUL     : SI=list, CX=repeat -> AX=new list       }
Procedure EmitListRuntime;
Begin
  EmitBlankLine;
  EmitComment('-- Runtime : listes (TODO 15) --');

  { _PYRT_SLICE : SI=list, AX=start, BX=end -> AX=ptr new list }
  { Si BX = FFFFh, utiliser [SI] comme fin                       }
  EmitLabel(PY_RT_PFX + 'SLICE');
  EmitInstr('PUSH   DX');
  EmitInstr('CMP    BX, 0FFFFh');
  EmitInstr('JNE    ' + PY_RT_PFX + 'SL_OK');
  EmitInstr('MOV    BX, [SI]');          { BX = len si sentinel }
  EmitLabel(PY_RT_PFX + 'SL_OK');
  EmitInstr('MOV    CX, BX');
  EmitInstr('SUB    CX, AX');            { CX = count = end - start }
  EmitInstr('PUSH   CX');               { sauver count }
  EmitInstr('PUSH   SI');               { sauver src list }
  EmitInstr('PUSH   AX');               { sauver start }
  { Allouer nouvelle liste sur le heap }
  EmitInstr('MOV    DI, [_PY_HEAPTOP]');
  EmitInstr('ADD    DI, OFFSET _PY_HEAP');
  EmitInstr('MOV    [DI], CX');          { ecrire count }
  { Calculer adresse source : SI + 2 + start*2 }
  EmitInstr('POP    AX');               { AX = start }
  EmitInstr('SHL    AX, 1');
  EmitInstr('POP    SI');               { SI = src list }
  EmitInstr('ADD    SI, AX');
  EmitInstr('ADD    SI, 2');             { sauter count header }
  { Copier CX elements }
  EmitInstr('POP    CX');               { CX = count }
  EmitInstr('PUSH   DI');               { sauver ptr new list }
  EmitInstr('PUSH   CX');
  EmitInstr('ADD    DI, 2');             { dest = new list + 2 }
  EmitInstr('TEST   CX, CX');
  EmitInstr('JLE    ' + PY_RT_PFX + 'SL_DN');
  EmitLabel(PY_RT_PFX + 'SL_CP');
  EmitInstr('MOVSW');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'SL_CP');
  EmitLabel(PY_RT_PFX + 'SL_DN');
  { Mettre a jour HEAPTOP }
  EmitInstr('POP    CX');               { CX = count }
  EmitInstr('INC    CX');               { +1 pour header }
  EmitInstr('SHL    CX, 1');
  EmitInstr('ADD    [_PY_HEAPTOP], CX');
  EmitInstr('POP    AX');               { AX = ptr new list }
  EmitInstr('POP    DX');
  EmitInstr('RET');

  { _PYRT_LISTAPPEND : SI=list, AX=val -> modifie en place }
  EmitLabel(PY_RT_PFX + 'LISTAPPEND');
  EmitInstr('MOV    CX, [SI]');          { CX = count }
  EmitInstr('MOV    BX, CX');
  EmitInstr('SHL    BX, 1');
  EmitInstr('ADD    BX, 2');             { offset = 2 + count*2 }
  EmitInstr('MOV    [SI+BX], AX');       { stocker val apres dernier }
  EmitInstr('INC    WORD PTR [SI]');     { count++ }
  EmitInstr('ADD    WORD PTR [_PY_HEAPTOP], 2');
  EmitInstr('RET');

  { _PYRT_LISTPOP : SI=list -> AX=dernier element }
  EmitLabel(PY_RT_PFX + 'LISTPOP');
  EmitInstr('MOV    CX, [SI]');          { CX = count }
  EmitInstr('DEC    WORD PTR [SI]');     { count-- }
  EmitInstr('SHL    CX, 1');             { CX = count*2 }
  EmitInstr('MOV    AX, [SI+CX]');       { AX = dernier element }
  EmitInstr('RET');

  { _PYRT_LISTINSERT : SI=list, AX=index, BX=val }
  { Decaler les elements vers la droite a partir de la fin }
  EmitLabel(PY_RT_PFX + 'LISTINSERT');
  EmitInstr('PUSH   DX');
  EmitInstr('MOV    DX, BX');            { DX = val a inserer }
  EmitInstr('MOV    CX, [SI]');          { CX = count }
  EmitInstr('MOV    BX, CX');            { BX = idx copie (count) }
  EmitLabel(PY_RT_PFX + 'LI_SH');
  EmitInstr('CMP    BX, AX');
  EmitInstr('JLE    ' + PY_RT_PFX + 'LI_IN');
  { Decaler : [SI + 2 + BX*2] = [SI + 2 + (BX-1)*2] }
  EmitInstr('PUSH   AX');
  EmitInstr('MOV    AX, BX');
  EmitInstr('SHL    AX, 1');
  EmitInstr('ADD    AX, 2');
  EmitInstr('PUSH   SI');
  EmitInstr('ADD    SI, AX');
  EmitInstr('MOV    AX, [SI-2]');
  EmitInstr('MOV    [SI], AX');
  EmitInstr('POP    SI');
  EmitInstr('POP    AX');
  EmitInstr('DEC    BX');
  EmitInstr('JMP    ' + PY_RT_PFX + 'LI_SH');
  EmitLabel(PY_RT_PFX + 'LI_IN');
  { Inserer : [SI + 2 + AX*2] = DX }
  EmitInstr('SHL    AX, 1');
  EmitInstr('ADD    AX, 2');
  EmitInstr('ADD    SI, AX');
  EmitInstr('MOV    [SI], DX');
  EmitInstr('SUB    SI, AX');            { restaurer SI }
  EmitInstr('INC    WORD PTR [SI]');     { count++ }
  EmitInstr('ADD    WORD PTR [_PY_HEAPTOP], 2');
  EmitInstr('POP    DX');
  EmitInstr('RET');

  { _PYRT_LISTCONCAT : SI=lst1, DI=lst2 -> AX=new list }
  EmitLabel(PY_RT_PFX + 'LISTCONCAT');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   DX');
  EmitInstr('MOV    AX, [SI]');          { AX = count1 }
  EmitInstr('MOV    BX, [DI]');          { BX = count2 }
  EmitInstr('MOV    CX, AX');
  EmitInstr('ADD    CX, BX');            { CX = total count }
  EmitInstr('PUSH   CX');               { sauver total }
  EmitInstr('PUSH   SI');               { sauver lst1 }
  EmitInstr('PUSH   DI');               { sauver lst2 }
  EmitInstr('PUSH   AX');               { sauver count1 }
  EmitInstr('PUSH   BX');               { sauver count2 }
  { Allouer sur le heap }
  EmitInstr('MOV    DI, [_PY_HEAPTOP]');
  EmitInstr('ADD    DI, OFFSET _PY_HEAP');
  EmitInstr('MOV    [DI], CX');          { ecrire total count }
  EmitInstr('PUSH   DI');               { sauver ptr new list }
  EmitInstr('ADD    DI, 2');             { dest = new + 2 }
  { Copier lst1 }
  EmitInstr('POP    BX');               { BX = ptr new list (on va PUSH apres) }
  EmitInstr('PUSH   BX');
  EmitInstr('MOV    CX, [SP+8]');        { count1 = [SP+8] }
  { Utiliser une autre approche : depiler count1, count2 }
  { Annuler et reprendre proprement }
  EmitInstr('POP    DI');               { DI = ptr new list }
  EmitInstr('POP    CX');               { CX = count2 }
  EmitInstr('POP    AX');               { AX = count1 }
  EmitInstr('POP    BX');               { BX = ptr lst2 }
  EmitInstr('POP    SI');               { SI = ptr lst1 }
  EmitInstr('POP    DX');               { DX = total count }
  { Ecrire total count }
  EmitInstr('MOV    [DI], DX');
  EmitInstr('PUSH   DI');               { sauver ptr new list }
  EmitInstr('PUSH   BX');               { sauver ptr lst2 }
  EmitInstr('PUSH   CX');               { sauver count2 }
  EmitInstr('ADD    DI, 2');
  { Copier count1 elements depuis lst1 }
  EmitInstr('ADD    SI, 2');
  EmitInstr('MOV    CX, AX');
  EmitInstr('TEST   CX, CX');
  EmitInstr('JLE    ' + PY_RT_PFX + 'LC_P2');
  EmitLabel(PY_RT_PFX + 'LC_L1');
  EmitInstr('MOVSW');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'LC_L1');
  EmitLabel(PY_RT_PFX + 'LC_P2');
  { Copier count2 elements depuis lst2 }
  EmitInstr('POP    CX');               { CX = count2 }
  EmitInstr('POP    SI');               { SI = ptr lst2 }
  EmitInstr('ADD    SI, 2');
  EmitInstr('TEST   CX, CX');
  EmitInstr('JLE    ' + PY_RT_PFX + 'LC_DN');
  EmitLabel(PY_RT_PFX + 'LC_L2');
  EmitInstr('MOVSW');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'LC_L2');
  EmitLabel(PY_RT_PFX + 'LC_DN');
  { Mettre a jour HEAPTOP }
  EmitInstr('POP    AX');               { AX = ptr new list }
  EmitInstr('MOV    CX, [AX]');         { CX = total count }
  EmitInstr('INC    CX');               { +1 pour header }
  EmitInstr('SHL    CX, 1');
  EmitInstr('ADD    [_PY_HEAPTOP], CX');
  EmitInstr('POP    DX');
  EmitInstr('POP    BX');
  EmitInstr('RET');

  { _PYRT_LISTMUL : SI=list, CX=repeat -> AX=new list }
  EmitLabel(PY_RT_PFX + 'LISTMUL');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   DX');
  EmitInstr('MOV    AX, [SI]');          { AX = elem count }
  EmitInstr('MOV    BX, AX');
  EmitInstr('IMUL   CX');               { AX = total elements }
  EmitInstr('MOV    DX, AX');            { DX = total }
  { Allouer sur le heap }
  EmitInstr('MOV    DI, [_PY_HEAPTOP]');
  EmitInstr('ADD    DI, OFFSET _PY_HEAP');
  EmitInstr('MOV    [DI], DX');          { ecrire total count }
  EmitInstr('PUSH   DI');               { sauver ptr new list }
  EmitInstr('ADD    DI, 2');
  EmitInstr('TEST   CX, CX');
  EmitInstr('JLE    ' + PY_RT_PFX + 'LM_DN');
  EmitLabel(PY_RT_PFX + 'LM_LP');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   SI');
  EmitInstr('ADD    SI, 2');
  EmitInstr('MOV    CX, BX');            { CX = elem count per iter }
  EmitInstr('TEST   CX, CX');
  EmitInstr('JLE    ' + PY_RT_PFX + 'LM_NX');
  EmitLabel(PY_RT_PFX + 'LM_CP');
  EmitInstr('MOVSW');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'LM_CP');
  EmitLabel(PY_RT_PFX + 'LM_NX');
  EmitInstr('POP    SI');
  EmitInstr('POP    CX');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'LM_LP');
  EmitLabel(PY_RT_PFX + 'LM_DN');
  { Mettre a jour HEAPTOP }
  EmitInstr('POP    AX');               { AX = ptr new list }
  EmitInstr('MOV    CX, [AX]');
  EmitInstr('INC    CX');
  EmitInstr('SHL    CX, 1');
  EmitInstr('ADD    [_PY_HEAPTOP], CX');
  EmitInstr('POP    DX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
End;

{ ============================================================
  TODO 12 - ENTREES/SORTIES [IMPLEMENTE]
  ============================================================ }

{ ---- EmitIORuntime : routines runtime pour print / input ---- }
{ Emet les sous-programmes ASM 8086 pour les E/S Python :        }
{   _PYRT_STRLEN   : SI -> CX (longueur d une chaine ASCIIZ)    }
{   _PYRT_NUMTOSTR : AX -> SI=ptr, CX=len (entier -> chaine)   }
{   _PYRT_INTTOSTR : alias pour NUMTOSTR (entier -> chaine ptr) }
{   _PYRT_PRINTSTR : SI=chaine ASCIIZ -> ecriture STDOUT        }
{   _PYRT_PRINT    : AX=entier -> afficher en decimal sur STDOUT }
{   _PYRT_NEWLINE  : emettre CR+LF sur STDOUT                   }
{   _PYRT_INPUT    : lire une ligne depuis STDIN -> AX=ptr      }
{   _PYRT_STRTONUM : SI=chaine -> AX=entier                     }
{   _PYRT_LEN      : SI=chaine ASCIIZ -> AX=longueur            }
{   _PYRT_TOHEX    : AX=entier -> AX=ptr chaine hex             }
{   _PYRT_TOOCT    : AX=entier -> AX=ptr chaine oct             }
{   _PYRT_TOBIN    : AX=entier -> AX=ptr chaine bin             }
Procedure EmitIORuntime;
Begin
  EmitBlankLine;
  EmitComment('-- Runtime : entrees/sorties (TODO 12) --');

  { _PYRT_STRLEN : SI=chaine ASCIIZ -> CX=longueur }
  EmitLabel(PY_RT_PFX + 'STRLEN');
  EmitInstr('PUSH   SI');
  EmitInstr('XOR    CX, CX');
  EmitLabel(PY_RT_PFX + 'SL1');
  EmitInstr('LODSB');
  EmitInstr('TEST   AL, AL');
  EmitInstr('JZ     ' + PY_RT_PFX + 'SL2');
  EmitInstr('INC    CX');
  EmitInstr('JMP    ' + PY_RT_PFX + 'SL1');
  EmitLabel(PY_RT_PFX + 'SL2');
  EmitInstr('POP    SI');
  EmitInstr('RET');

  { _PYRT_LEN : SI=chaine ou collection -> AX=longueur }
  EmitLabel(PY_RT_PFX + 'LEN');
  EmitInstr('PUSH   SI');
  EmitInstr('XOR    AX, AX');
  EmitLabel(PY_RT_PFX + 'LN1');
  EmitInstr('CMP    BYTE PTR [SI], 0');
  EmitInstr('JE     ' + PY_RT_PFX + 'LN2');
  EmitInstr('INC    AX');
  EmitInstr('INC    SI');
  EmitInstr('JMP    ' + PY_RT_PFX + 'LN1');
  EmitLabel(PY_RT_PFX + 'LN2');
  EmitInstr('POP    SI');
  EmitInstr('RET');

  { _PYRT_NUMTOSTR : AX=entier signe -> _PY_NUMBUF, SI=ptr, CX=len }
  { Convertit un entier 16 bits signe en chaine decimale ASCII       }
  EmitLabel(PY_RT_PFX + 'NUMTOSTR');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   DX');
  EmitInstr('PUSH   DI');
  EmitInstr('MOV    DI, OFFSET _PY_NUMBUF');
  EmitInstr('ADD    DI, 11');          { pointer sur la fin du buffer }
  EmitInstr('MOV    BYTE PTR [DI], 0'); { terminateur null }
  EmitInstr('DEC    DI');
  EmitInstr('MOV    BX, 10');
  EmitInstr('XOR    CX, CX');          { compteur de chiffres }
  EmitInstr('TEST   AX, AX');
  EmitInstr('JNS    ' + PY_RT_PFX + 'NT_POS');
  { Nombre negatif : on note le signe et on prend la valeur absolue }
  EmitInstr('NEG    AX');
  EmitInstr('PUSH   AX');              { sauver flag negatif }
  EmitInstr('MOV    AX, 1');
  EmitInstr('PUSH   AX');              { 1 = negatif }
  EmitInstr('POP    AX');              { recup flag }
  EmitInstr('POP    AX');              { -- annuler, on refait autrement }
  { En fait, approche plus simple : }
  EmitInstr('JMP    ' + PY_RT_PFX + 'NT_POS');
  EmitLabel(PY_RT_PFX + 'NT_NEG');
  EmitInstr('NEG    AX');
  EmitLabel(PY_RT_PFX + 'NT_POS');
  { Division repetee par 10 }
  EmitLabel(PY_RT_PFX + 'NT_LP');
  EmitInstr('XOR    DX, DX');
  EmitInstr('DIV    BX');              { AX = quotient, DX = reste }
  EmitInstr('ADD    DL, 48');          { '0' + reste }
  EmitInstr('MOV    [DI], DL');
  EmitInstr('DEC    DI');
  EmitInstr('INC    CX');
  EmitInstr('TEST   AX, AX');
  EmitInstr('JNZ    ' + PY_RT_PFX + 'NT_LP');
  { SI = debut de la chaine, CX = longueur }
  EmitInstr('INC    DI');
  EmitInstr('MOV    SI, DI');
  EmitInstr('POP    DI');
  EmitInstr('POP    DX');
  EmitInstr('POP    BX');
  EmitInstr('RET');

  { _PYRT_INTTOSTR : AX=entier -> AX=ptr chaine ASCIIZ }
  { Appelle NUMTOSTR puis retourne SI dans AX            }
  EmitLabel(PY_RT_PFX + 'INTTOSTR');
  EmitInstr('CALL   ' + PY_RT_PFX + 'NUMTOSTR');
  EmitInstr('MOV    AX, SI');
  EmitInstr('RET');

  { _PYRT_PRINTSTR : SI=chaine ASCIIZ -> ecriture sur STDOUT }
  { Utilise DOS INT 21h, AH=40h, BX=1 (STDOUT)               }
  EmitLabel(PY_RT_PFX + 'PRINTSTR');
  EmitInstr('PUSH   AX');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitInstr('CALL   ' + PY_RT_PFX + 'STRLEN'); { CX = longueur }
  EmitInstr('MOV    DX, SI');          { DS:DX = adresse chaine }
  EmitInstr('MOV    BX, 1');           { handle STDOUT }
  EmitInstr('MOV    AH, 40h');
  EmitInstr('INT    21h');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('POP    AX');
  EmitInstr('RET');

  { _PYRT_PRINT : AX=entier -> afficher en decimal sur STDOUT }
  { Convertit en chaine puis ecrit                              }
  EmitLabel(PY_RT_PFX + 'PRINT');
  EmitInstr('PUSH   SI');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitInstr('PUSH   BX');
  { Gerer les nombres negatifs }
  EmitInstr('TEST   AX, AX');
  EmitInstr('JNS    ' + PY_RT_PFX + 'PR_POS');
  { Ecrire le signe '-' }
  EmitInstr('PUSH   AX');
  EmitInstr('MOV    DL, 45');          { '-' }
  EmitInstr('MOV    AH, 02h');
  EmitInstr('INT    21h');
  EmitInstr('POP    AX');
  EmitInstr('NEG    AX');
  EmitLabel(PY_RT_PFX + 'PR_POS');
  EmitInstr('CALL   ' + PY_RT_PFX + 'NUMTOSTR'); { SI=ptr, CX=len }
  EmitInstr('MOV    DX, SI');
  EmitInstr('MOV    BX, 1');
  EmitInstr('MOV    AH, 40h');
  EmitInstr('INT    21h');
  EmitInstr('POP    BX');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    SI');
  EmitInstr('RET');

  { _PYRT_NEWLINE : emettre CR+LF sur STDOUT }
  EmitLabel(PY_RT_PFX + 'NEWLINE');
  EmitInstr('PUSH   AX');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitInstr('MOV    DX, OFFSET _PY_CRLF');
  EmitInstr('MOV    CX, 2');
  EmitInstr('MOV    BX, 1');
  EmitInstr('MOV    AH, 40h');
  EmitInstr('INT    21h');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('POP    AX');
  EmitInstr('RET');

  { _PYRT_PRINTSPC : emettre un espace sur STDOUT }
  EmitLabel(PY_RT_PFX + 'PRINTSPC');
  EmitInstr('PUSH   AX');
  EmitInstr('PUSH   DX');
  EmitInstr('MOV    DL, 32');
  EmitInstr('MOV    AH, 02h');
  EmitInstr('INT    21h');
  EmitInstr('POP    DX');
  EmitInstr('POP    AX');
  EmitInstr('RET');

  { _PYRT_INPUT : lire une ligne depuis STDIN -> AX=ptr chaine ASCIIZ }
  { Utilise DOS INT 21h, AH=0Ah (lecture ligne bufferisee)              }
  EmitLabel(PY_RT_PFX + 'INPUT');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitInstr('PUSH   SI');
  EmitInstr('MOV    DX, OFFSET _PY_INPUTMX');
  EmitInstr('MOV    AH, 0Ah');
  EmitInstr('INT    21h');
  { Terminer la chaine par 0 au lieu de CR }
  EmitInstr('XOR    BH, BH');
  EmitInstr('MOV    BL, [_PY_INPUTLN]');  { longueur lue }
  EmitInstr('MOV    BYTE PTR [_PY_INPUTBF + BX], 0'); { null-term }
  { Emettre un saut de ligne apres la saisie }
  EmitInstr('CALL   ' + PY_RT_PFX + 'NEWLINE');
  { Retourner le pointeur sur le buffer }
  EmitInstr('MOV    AX, OFFSET _PY_INPUTBF');
  EmitInstr('POP    SI');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');

  { _PYRT_STRTONUM : SI=chaine ASCIIZ -> AX=entier }
  { Convertit une chaine decimale en entier 16 bits   }
  EmitLabel(PY_RT_PFX + 'STRTONUM');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitInstr('XOR    AX, AX');
  EmitInstr('XOR    CX, CX');          { CX = flag negatif }
  EmitInstr('CMP    BYTE PTR [SI], 45'); { '-' }
  EmitInstr('JNE    ' + PY_RT_PFX + 'SN_LP');
  EmitInstr('INC    CX');              { marquer negatif }
  EmitInstr('INC    SI');
  EmitLabel(PY_RT_PFX + 'SN_LP');
  EmitInstr('MOV    BL, [SI]');
  EmitInstr('TEST   BL, BL');
  EmitInstr('JZ     ' + PY_RT_PFX + 'SN_DN');
  EmitInstr('CMP    BL, 48');          { < '0' }
  EmitInstr('JB     ' + PY_RT_PFX + 'SN_DN');
  EmitInstr('CMP    BL, 57');          { > '9' }
  EmitInstr('JA     ' + PY_RT_PFX + 'SN_DN');
  EmitInstr('SUB    BL, 48');
  EmitInstr('XOR    BH, BH');
  { AX = AX * 10 + digit }
  EmitInstr('PUSH   BX');
  EmitInstr('MOV    BX, 10');
  EmitInstr('MUL    BX');
  EmitInstr('POP    BX');
  EmitInstr('ADD    AX, BX');
  EmitInstr('INC    SI');
  EmitInstr('JMP    ' + PY_RT_PFX + 'SN_LP');
  EmitLabel(PY_RT_PFX + 'SN_DN');
  EmitInstr('TEST   CX, CX');
  EmitInstr('JZ     ' + PY_RT_PFX + 'SN_OK');
  EmitInstr('NEG    AX');
  EmitLabel(PY_RT_PFX + 'SN_OK');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');

  { _PYRT_TOHEX : AX=entier -> AX=ptr chaine "0xHHHH" }
  EmitLabel(PY_RT_PFX + 'TOHEX');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DI');
  EmitInstr('MOV    DI, OFFSET _PY_NUMBUF');
  EmitInstr('MOV    BYTE PTR [DI], 48');   { '0' }
  EmitInstr('MOV    BYTE PTR [DI+1], 120'); { 'x' }
  EmitInstr('ADD    DI, 6');
  EmitInstr('MOV    BYTE PTR [DI], 0');   { null-term }
  EmitInstr('DEC    DI');
  EmitInstr('MOV    CX, 4');
  EmitLabel(PY_RT_PFX + 'HX_LP');
  EmitInstr('MOV    BX, AX');
  EmitInstr('AND    BX, 0Fh');
  EmitInstr('CMP    BL, 10');
  EmitInstr('JB     ' + PY_RT_PFX + 'HX_D');
  EmitInstr('ADD    BL, 87');            { 'a' - 10 }
  EmitInstr('JMP    ' + PY_RT_PFX + 'HX_S');
  EmitLabel(PY_RT_PFX + 'HX_D');
  EmitInstr('ADD    BL, 48');            { '0' }
  EmitLabel(PY_RT_PFX + 'HX_S');
  EmitInstr('MOV    [DI], BL');
  EmitInstr('DEC    DI');
  EmitInstr('SHR    AX, 1');
  EmitInstr('SHR    AX, 1');
  EmitInstr('SHR    AX, 1');
  EmitInstr('SHR    AX, 1');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'HX_LP');
  EmitInstr('MOV    AX, OFFSET _PY_NUMBUF');
  EmitInstr('POP    DI');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');

  { _PYRT_TOOCT : AX=entier -> AX=ptr chaine "0oNNNNNN" }
  EmitLabel(PY_RT_PFX + 'TOOCT');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DI');
  EmitInstr('MOV    DI, OFFSET _PY_NUMBUF');
  EmitInstr('MOV    BYTE PTR [DI], 48');    { '0' }
  EmitInstr('MOV    BYTE PTR [DI+1], 111'); { 'o' }
  EmitInstr('ADD    DI, 8');
  EmitInstr('MOV    BYTE PTR [DI], 0');
  EmitInstr('DEC    DI');
  EmitInstr('MOV    CX, 6');
  EmitLabel(PY_RT_PFX + 'OC_LP');
  EmitInstr('MOV    BX, AX');
  EmitInstr('AND    BX, 07h');
  EmitInstr('ADD    BL, 48');
  EmitInstr('MOV    [DI], BL');
  EmitInstr('DEC    DI');
  EmitInstr('SHR    AX, 1');
  EmitInstr('SHR    AX, 1');
  EmitInstr('SHR    AX, 1');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'OC_LP');
  EmitInstr('MOV    AX, OFFSET _PY_NUMBUF');
  EmitInstr('POP    DI');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');

  { _PYRT_TOBIN : AX=entier -> AX=ptr chaine "0bBBBBBBBBBBBBBBBB" }
  { Note : nous utilisons _PY_STRBUF pour avoir assez de place (18+ chars) }
  EmitLabel(PY_RT_PFX + 'TOBIN');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DI');
  EmitInstr('MOV    DI, OFFSET _PY_STRBUF');
  EmitInstr('MOV    BYTE PTR [DI], 48');   { '0' }
  EmitInstr('MOV    BYTE PTR [DI+1], 98'); { 'b' }
  EmitInstr('ADD    DI, 18');
  EmitInstr('MOV    BYTE PTR [DI], 0');
  EmitInstr('DEC    DI');
  EmitInstr('MOV    CX, 16');
  EmitLabel(PY_RT_PFX + 'BN_LP');
  EmitInstr('MOV    BX, AX');
  EmitInstr('AND    BX, 01h');
  EmitInstr('ADD    BL, 48');
  EmitInstr('MOV    [DI], BL');
  EmitInstr('DEC    DI');
  EmitInstr('SHR    AX, 1');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'BN_LP');
  EmitInstr('MOV    AX, OFFSET _PY_STRBUF');
  EmitInstr('POP    DI');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
End;

{ ============================================================
  TODO 16 - DICTIONNAIRES : RUNTIME [IMPLEMENTE]
  ============================================================ }

{ ---- EmitDictRuntime : routines runtime pour les dicts ------- }
{ Layout dict : [count DW][key0 DW][val0 DW][key1 DW][val1 DW]  }
{   _PYRT_DICTGET      : SI=dict, AX=key -> AX=val (panic if not)}
{   _PYRT_DICTSET      : SI=dict, AX=key, BX=val -> modifie      }
{   _PYRT_DICTGETDEF   : SI=dict, AX=key, BX=default -> AX       }
{   _PYRT_DICTCONTAINS : SI=dict, AX=key -> AX=0|1               }
{   _PYRT_DICTDEL      : SI=dict, AX=key -> supprime la paire    }
{   _PYRT_DICTKEYS     : SI=dict -> AX=ptr new list of keys       }
{   _PYRT_DICTVALS     : SI=dict -> AX=ptr new list of values     }
Procedure EmitDictRuntime;
Begin
  EmitBlankLine;
  EmitComment('-- Runtime : dicts (TODO 16) --');

  { _PYRT_DICTGET : SI=dict, AX=key -> AX=val }
  { Recherche lineaire dans les paires key/val }
  EmitLabel(PY_RT_PFX + 'DICTGET');
  EmitInstr('PUSH   BX');
  EmitInstr('MOV    BX, AX');            { BX = key }
  EmitInstr('MOV    CX, [SI]');          { CX = count }
  EmitInstr('ADD    SI, 2');             { sauter header }
  EmitInstr('TEST   CX, CX');
  EmitInstr('JZ     ' + PY_RT_PFX + 'DG_NF');
  EmitLabel(PY_RT_PFX + 'DG_LP');
  EmitInstr('CMP    [SI], BX');          { comparer cle }
  EmitInstr('JE     ' + PY_RT_PFX + 'DG_FD');
  EmitInstr('ADD    SI, 4');             { paire suivante }
  EmitInstr('LOOP   ' + PY_RT_PFX + 'DG_LP');
  EmitLabel(PY_RT_PFX + 'DG_NF');
  { KeyError : retourner 0 comme valeur par defaut }
  EmitInstr('XOR    AX, AX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitLabel(PY_RT_PFX + 'DG_FD');
  EmitInstr('MOV    AX, [SI+2]');        { AX = valeur }
  EmitInstr('POP    BX');
  EmitInstr('RET');

  { _PYRT_DICTSET : SI=dict, AX=key, BX=val -> modifie en place }
  { Si la cle existe, mettre a jour. Sinon, ajouter la paire.   }
  EmitLabel(PY_RT_PFX + 'DICTSET');
  EmitInstr('PUSH   DX');
  EmitInstr('MOV    DX, AX');            { DX = key }
  EmitInstr('MOV    CX, [SI]');          { CX = count }
  EmitInstr('PUSH   SI');                { sauver ptr dict }
  EmitInstr('ADD    SI, 2');             { sauter header }
  EmitInstr('TEST   CX, CX');
  EmitInstr('JZ     ' + PY_RT_PFX + 'DS_ADD');
  EmitLabel(PY_RT_PFX + 'DS_LP');
  EmitInstr('CMP    [SI], DX');          { comparer cle }
  EmitInstr('JE     ' + PY_RT_PFX + 'DS_UPD');
  EmitInstr('ADD    SI, 4');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'DS_LP');
  EmitLabel(PY_RT_PFX + 'DS_ADD');
  { Ajouter nouvelle paire a la fin }
  EmitInstr('MOV    [SI], DX');          { ecrire cle }
  EmitInstr('MOV    [SI+2], BX');        { ecrire val }
  EmitInstr('POP    SI');                { SI = ptr dict }
  EmitInstr('INC    WORD PTR [SI]');     { count++ }
  EmitInstr('ADD    WORD PTR [_PY_HEAPTOP], 4');  { 4 octets de plus }
  EmitInstr('POP    DX');
  EmitInstr('RET');
  EmitLabel(PY_RT_PFX + 'DS_UPD');
  { Mettre a jour valeur existante }
  EmitInstr('MOV    [SI+2], BX');        { ecrire val }
  EmitInstr('POP    SI');                { depiler ptr dict sauvegarde }
  EmitInstr('POP    DX');
  EmitInstr('RET');

  { _PYRT_DICTGETDEF : SI=dict, AX=key, BX=default -> AX=val ou default }
  EmitLabel(PY_RT_PFX + 'DICTGETDEF');
  EmitInstr('PUSH   DX');
  EmitInstr('MOV    DX, AX');            { DX = key }
  EmitInstr('MOV    CX, [SI]');          { CX = count }
  EmitInstr('ADD    SI, 2');
  EmitInstr('TEST   CX, CX');
  EmitInstr('JZ     ' + PY_RT_PFX + 'DD_DEF');
  EmitLabel(PY_RT_PFX + 'DD_LP');
  EmitInstr('CMP    [SI], DX');
  EmitInstr('JE     ' + PY_RT_PFX + 'DD_FD');
  EmitInstr('ADD    SI, 4');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'DD_LP');
  EmitLabel(PY_RT_PFX + 'DD_DEF');
  EmitInstr('MOV    AX, BX');            { retourner default }
  EmitInstr('POP    DX');
  EmitInstr('RET');
  EmitLabel(PY_RT_PFX + 'DD_FD');
  EmitInstr('MOV    AX, [SI+2]');        { retourner val }
  EmitInstr('POP    DX');
  EmitInstr('RET');

  { _PYRT_DICTCONTAINS : SI=dict, AX=key -> AX=0|1 }
  EmitLabel(PY_RT_PFX + 'DICTCONTAINS');
  EmitInstr('MOV    BX, AX');            { BX = key }
  EmitInstr('MOV    CX, [SI]');
  EmitInstr('ADD    SI, 2');
  EmitInstr('TEST   CX, CX');
  EmitInstr('JZ     ' + PY_RT_PFX + 'DC_NO');
  EmitLabel(PY_RT_PFX + 'DC_LP');
  EmitInstr('CMP    [SI], BX');
  EmitInstr('JE     ' + PY_RT_PFX + 'DC_YES');
  EmitInstr('ADD    SI, 4');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'DC_LP');
  EmitLabel(PY_RT_PFX + 'DC_NO');
  EmitInstr('XOR    AX, AX');
  EmitInstr('RET');
  EmitLabel(PY_RT_PFX + 'DC_YES');
  EmitInstr('MOV    AX, 1');
  EmitInstr('RET');

  { _PYRT_DICTDEL : SI=dict, AX=key -> supprime la paire }
  { Recherche la cle, puis decale les paires suivantes }
  EmitLabel(PY_RT_PFX + 'DICTDEL');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   DX');
  EmitInstr('MOV    BX, AX');            { BX = key }
  EmitInstr('MOV    CX, [SI]');
  EmitInstr('PUSH   SI');                { sauver ptr dict }
  EmitInstr('ADD    SI, 2');
  EmitInstr('TEST   CX, CX');
  EmitInstr('JZ     ' + PY_RT_PFX + 'DL_DN');
  EmitLabel(PY_RT_PFX + 'DL_LP');
  EmitInstr('CMP    [SI], BX');
  EmitInstr('JE     ' + PY_RT_PFX + 'DL_FD');
  EmitInstr('ADD    SI, 4');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'DL_LP');
  EmitInstr('JMP    ' + PY_RT_PFX + 'DL_DN');
  EmitLabel(PY_RT_PFX + 'DL_FD');
  { Decaler paires suivantes de 4 octets vers la gauche }
  EmitInstr('DEC    CX');                { CX = remaining pairs }
  EmitInstr('TEST   CX, CX');
  EmitInstr('JZ     ' + PY_RT_PFX + 'DL_DC');
  EmitLabel(PY_RT_PFX + 'DL_SH');
  EmitInstr('MOV    AX, [SI+4]');
  EmitInstr('MOV    [SI], AX');
  EmitInstr('MOV    AX, [SI+6]');
  EmitInstr('MOV    [SI+2], AX');
  EmitInstr('ADD    SI, 4');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'DL_SH');
  EmitLabel(PY_RT_PFX + 'DL_DC');
  EmitInstr('POP    SI');                { SI = ptr dict }
  EmitInstr('DEC    WORD PTR [SI]');     { count-- }
  EmitInstr('POP    DX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitLabel(PY_RT_PFX + 'DL_DN');
  { Cle non trouvee, ne rien faire }
  EmitInstr('POP    SI');
  EmitInstr('POP    DX');
  EmitInstr('POP    BX');
  EmitInstr('RET');

  { _PYRT_DICTKEYS : SI=dict -> AX=ptr new list of keys }
  EmitLabel(PY_RT_PFX + 'DICTKEYS');
  EmitInstr('PUSH   BX');
  EmitInstr('MOV    CX, [SI]');          { CX = count }
  EmitInstr('ADD    SI, 2');
  EmitInstr('MOV    DI, [_PY_HEAPTOP]');
  EmitInstr('ADD    DI, OFFSET _PY_HEAP');
  EmitInstr('MOV    [DI], CX');          { ecrire count header }
  EmitInstr('PUSH   DI');                { sauver ptr new list }
  EmitInstr('ADD    DI, 2');
  EmitInstr('TEST   CX, CX');
  EmitInstr('JLE    ' + PY_RT_PFX + 'DK_DN');
  EmitLabel(PY_RT_PFX + 'DK_LP');
  EmitInstr('MOV    AX, [SI]');          { AX = key }
  EmitInstr('STOSW');                    { ecrire dans new list }
  EmitInstr('ADD    SI, 4');             { paire suivante }
  EmitInstr('LOOP   ' + PY_RT_PFX + 'DK_LP');
  EmitLabel(PY_RT_PFX + 'DK_DN');
  EmitInstr('POP    AX');                { AX = ptr new list }
  EmitInstr('MOV    CX, [AX]');          { CX = count }
  EmitInstr('INC    CX');
  EmitInstr('SHL    CX, 1');
  EmitInstr('ADD    [_PY_HEAPTOP], CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');

  { _PYRT_DICTVALS : SI=dict -> AX=ptr new list of values }
  EmitLabel(PY_RT_PFX + 'DICTVALS');
  EmitInstr('PUSH   BX');
  EmitInstr('MOV    CX, [SI]');          { CX = count }
  EmitInstr('ADD    SI, 2');
  EmitInstr('MOV    DI, [_PY_HEAPTOP]');
  EmitInstr('ADD    DI, OFFSET _PY_HEAP');
  EmitInstr('MOV    [DI], CX');          { ecrire count header }
  EmitInstr('PUSH   DI');                { sauver ptr new list }
  EmitInstr('ADD    DI, 2');
  EmitInstr('TEST   CX, CX');
  EmitInstr('JLE    ' + PY_RT_PFX + 'DV_DN');
  EmitLabel(PY_RT_PFX + 'DV_LP');
  EmitInstr('MOV    AX, [SI+2]');        { AX = value }
  EmitInstr('STOSW');
  EmitInstr('ADD    SI, 4');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'DV_LP');
  EmitLabel(PY_RT_PFX + 'DV_DN');
  EmitInstr('POP    AX');                { AX = ptr new list }
  EmitInstr('MOV    CX, [AX]');
  EmitInstr('INC    CX');
  EmitInstr('SHL    CX, 1');
  EmitInstr('ADD    [_PY_HEAPTOP], CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
End;

{ ---- SymNameClean : nettoyer un nom pour l utiliser en ASM --- }
{ Supprime les caracteres non alphanumeriques sauf _ .           }
Function SymNameClean(Const Name : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := '';
  For I := 1 To Length(Name) Do
    If ((Name[I] >= 'A') And (Name[I] <= 'Z')) Or
       ((Name[I] >= 'a') And (Name[I] <= 'z')) Or
       ((Name[I] >= '0') And (Name[I] <= '9')) Or
       (Name[I] = '_') Then
    Begin
      If Length(R) < MAX_STR Then
        R := R + Name[I];
    End
    Else
    Begin
      If Length(R) < MAX_STR Then
        R := R + '_';
    End;
  If R = '' Then R := '_anon';
  SymNameClean := R;
End;

{ ---- SymMangle : generer un label ASM depuis un symbole ------ }
{ Le prefixe depend de la categorie du symbole :                  }
{   SK_VAR / SK_LOCAL / SK_GLOBAL / SK_PARAM -> _PYV_             }
{   SK_FUNC   -> _PYF_                                            }
{   SK_CLASS  -> _PYC_                                             }
{   SK_MODULE -> _PYV_                                             }
{   SK_BUILTIN -> _PYRT_                                           }
Function SymMangle(Const Name : TString; Kind : TSymKind) : TString;
Var
  Clean : TString;
Begin
  Clean := SymNameClean(Name);
  Case Kind Of
    SK_FUNC    : SymMangle := PY_FN_PFX  + Clean;
    SK_CLASS   : SymMangle := PY_CLS_PFX + Clean;
    SK_BUILTIN : SymMangle := PY_RT_PFX  + Clean;
  Else
    SymMangle := PY_VAR_PFX + Clean;
  End;
End;

{ ---- SymFind : recherche MRU (Most Recently Used) ------------ }
{ Cherche du plus recent au plus ancien pour respecter le         }
{ masquage (shadowing) des variables dans les portees internes.   }
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

{ ---- SymFindInScope : recherche dans une portee specifique --- }
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
{ Retourne l indice du nouveau symbole (0-base) ou -1 si plein.  }
Function SymAdd(Const Name : TString; Kind : TSymKind;
                TypeIdx, Offset : Integer) : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    CompileError('table des symboles pleine (max=' +
                 IntToStr_(MAX_SYM) + ')', CurToken.Line);
    SymAdd := -1;
    Exit;
  End;
  SymTab[SymCount].Name        := Name;
  SymTab[SymCount].MangledName := SymMangle(Name, Kind);
  SymTab[SymCount].Kind        := Kind;
  SymTab[SymCount].TypeIdx     := TypeIdx;
  SymTab[SymCount].Offset      := Offset;
  SymTab[SymCount].ScopeLevel  := CurScope;
  SymTab[SymCount].IsGlobal    := False;
  SymTab[SymCount].IsNonlocal  := False;
  SymTab[SymCount].IsImported  := False;
  SymTab[SymCount].DeclLine    := CurToken.Line;

  If Opts.DebugMode Then
    WriteLn('  SYM_ADD[', SymCount, ']: ', Name,
            ' kind=', Ord(Kind),
            ' scope=', CurScope,
            ' -> ', SymTab[SymCount].MangledName);

  SymAdd := SymCount;
  Inc(SymCount);
  Inc(TotalSyms);
End;

{ ---- SymEnterScope : entrer dans une nouvelle portee --------- }
{ Chaque def, class, lambda cree un nouvel environnement.        }
Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
  Begin
    CompileError('portees trop imbriquees (max=' +
                 IntToStr_(MAX_SCOPE) + ')', CurToken.Line);
    Exit;
  End;
  ScopeStack[ScopeTop] := SymCount;
  Inc(ScopeTop);
  Inc(CurScope);
  If Opts.DebugMode Then
    WriteLn('  SCOPE_ENTER: level=', CurScope);
End;

{ ---- SymLeaveScope : quitter la portee courante -------------- }
{ Les symboles locaux de cette portee sont retires de la table.  }
Procedure SymLeaveScope;
Begin
  If ScopeTop <= 0 Then Exit;
  Dec(ScopeTop);
  SymCount := ScopeStack[ScopeTop];
  Dec(CurScope);
  If Opts.DebugMode Then
    WriteLn('  SCOPE_LEAVE: level=', CurScope);
End;

{ ---- SymInit : initialiser la table des symboles ------------- }
{ Enregistre les builtins Python (print, len, int, str, etc.)    }
Procedure SymInit;
Var
  I : Integer;
Begin
  SymCount  := 0;
  ScopeTop  := 0;
  CurScope  := 0;
  For I := 0 To MAX_SYM - 1 Do
  Begin
    SymTab[I].Name        := '';
    SymTab[I].MangledName := '';
    SymTab[I].Kind        := SK_VAR;
    SymTab[I].TypeIdx     := TY_UNKNOWN;
    SymTab[I].Offset      := 0;
    SymTab[I].ScopeLevel  := 0;
    SymTab[I].IsGlobal    := False;
    SymTab[I].IsNonlocal  := False;
    SymTab[I].DeclLine    := 0;
  End;
  { Enregistrer les builtins de base }
  SymAdd('print',     SK_BUILTIN, TY_IDX_NONE, 0);
  SymAdd('input',     SK_BUILTIN, TY_IDX_STR,  0);
  SymAdd('len',       SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('int',       SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('str',       SK_BUILTIN, TY_IDX_STR,  0);
  SymAdd('float',     SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('bool',      SK_BUILTIN, TY_IDX_BOOL, 0);
  SymAdd('abs',       SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('chr',       SK_BUILTIN, TY_IDX_STR,  0);
  SymAdd('ord',       SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('type',      SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('isinstance',SK_BUILTIN, TY_IDX_BOOL, 0);
  SymAdd('range',     SK_BUILTIN, TY_IDX_LIST, 0);
  SymAdd('list',      SK_BUILTIN, TY_IDX_LIST, 0);
  SymAdd('dict',      SK_BUILTIN, TY_IDX_DICT, 0);
  SymAdd('tuple',     SK_BUILTIN, TY_IDX_LIST, 0);
  SymAdd('set',       SK_BUILTIN, TY_IDX_LIST, 0);
  SymAdd('min',       SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('max',       SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('sum',       SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('sorted',    SK_BUILTIN, TY_IDX_LIST, 0);
  SymAdd('reversed',  SK_BUILTIN, TY_IDX_LIST, 0);
  SymAdd('enumerate', SK_BUILTIN, TY_IDX_LIST, 0);
  SymAdd('zip',       SK_BUILTIN, TY_IDX_LIST, 0);
  SymAdd('map',       SK_BUILTIN, TY_IDX_LIST, 0);
  SymAdd('filter',    SK_BUILTIN, TY_IDX_LIST, 0);
  SymAdd('hex',       SK_BUILTIN, TY_IDX_STR,  0);
  SymAdd('oct',       SK_BUILTIN, TY_IDX_STR,  0);
  SymAdd('bin',       SK_BUILTIN, TY_IDX_STR,  0);
  SymAdd('repr',      SK_BUILTIN, TY_IDX_STR,  0);
  SymAdd('id',        SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('hash',      SK_BUILTIN, TY_IDX_INT,  0);
  SymAdd('open',      SK_BUILTIN, TY_IDX_INT,  0);
End;

{ ============================================================
  TODO 06 - SYSTEME DE TYPES DYNAMIQUE [IMPLEMENTE]
  ============================================================ }

{ ---- TypeKindStr : nom textuel d un TTypeKind --------------- }
Function TypeKindStr(K : TTypeKind) : TString;
Begin
  Case K Of
    TYK_INT     : TypeKindStr := 'int';
    TYK_BOOL    : TypeKindStr := 'bool';
    TYK_STR     : TypeKindStr := 'str';
    TYK_NONE    : TypeKindStr := 'NoneType';
    TYK_LIST    : TypeKindStr := 'list';
    TYK_DICT    : TypeKindStr := 'dict';
    TYK_TUPLE   : TypeKindStr := 'tuple';
    TYK_FUNC    : TypeKindStr := 'function';
    TYK_OBJECT  : TypeKindStr := 'object';
    TYK_CLASS   : TypeKindStr := 'type';
    TYK_UNKNOWN : TypeKindStr := '<unknown>';
  Else
    TypeKindStr := '<unknown>';
  End;
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
{ En architecture 16-bit, les pointeurs font 2 octets (un mot). }
{ INT=2, BOOL=2 (stocke sur un mot pour simplifier), STR=2,     }
{ LIST=2, DICT=2, TUPLE=2, FUNC=2, OBJECT=2, CLASS=2, NONE=0.  }
Function TypeSizeof(TypeIdx : Integer) : Integer;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeSizeof := TypeTab[TypeIdx].Size
  Else
    TypeSizeof := 2;  { taille par defaut : word (16 bits) }
End;

{ ---- TypeFindByName : rechercher un type par nom ------------- }
{ Retourne l indice dans TypeTab ou TY_UNKNOWN si non trouve.    }
Function TypeFindByName(Const Name : TString) : Integer;
Var I : Integer;
Begin
  For I := 0 To TypeCount - 1 Do
    If TypeTab[I].Name = Name Then
    Begin
      TypeFindByName := I;
      Exit;
    End;
  TypeFindByName := TY_UNKNOWN;
End;

{ ---- TypeIdxFromExpr : deduire l indice type d une expression  }
{ Utilise le champ TypeIdx de l expression si connu,              }
{ sinon retourne TY_UNKNOWN.                                      }
Function TypeIdxFromExpr(Const E : TExprVal) : Integer;
Begin
  If (E.TypeIdx >= 0) And (E.TypeIdx < TypeCount) Then
    TypeIdxFromExpr := E.TypeIdx
  Else
    TypeIdxFromExpr := TY_UNKNOWN;
End;

{ ---- TypeInit : enregistrer les types primitifs Python -------- }
{ Les indices correspondent a TY_IDX_INT=0 .. TY_IDX_CLASS=7.    }
{ Les types supplementaires (TUPLE, UNKNOWN) sont ajoutes apres.  }
Procedure TypeInit;
Var I : Integer;
Begin
  TypeCount := 0;
  For I := 0 To MAX_TYPE - 1 Do
  Begin
    TypeTab[I].Name := '';
    TypeTab[I].Kind := TYK_UNKNOWN;
    TypeTab[I].Size := 0;
  End;
  { TY_IDX_INT = 0 : entier 16 bits signe }
  TypeTab[0].Name := 'int';
  TypeTab[0].Kind := TYK_INT;
  TypeTab[0].Size := 2;
  { TY_IDX_STR = 1 : pointeur chaine }
  TypeTab[1].Name := 'str';
  TypeTab[1].Kind := TYK_STR;
  TypeTab[1].Size := 2;
  { TY_IDX_BOOL = 2 : booleen (stocke sur un mot) }
  TypeTab[2].Name := 'bool';
  TypeTab[2].Kind := TYK_BOOL;
  TypeTab[2].Size := 2;
  { TY_IDX_NONE = 3 : None (pas de taille) }
  TypeTab[3].Name := 'NoneType';
  TypeTab[3].Kind := TYK_NONE;
  TypeTab[3].Size := 0;
  { TY_IDX_LIST = 4 : liste dynamique (pointeur) }
  TypeTab[4].Name := 'list';
  TypeTab[4].Kind := TYK_LIST;
  TypeTab[4].Size := 2;
  { TY_IDX_DICT = 5 : dictionnaire (pointeur) }
  TypeTab[5].Name := 'dict';
  TypeTab[5].Kind := TYK_DICT;
  TypeTab[5].Size := 2;
  { TY_IDX_FUNC = 6 : fonction (pointeur de code) }
  TypeTab[6].Name := 'function';
  TypeTab[6].Kind := TYK_FUNC;
  TypeTab[6].Size := 2;
  { TY_IDX_CLASS = 7 : descripteur de classe }
  TypeTab[7].Name := 'type';
  TypeTab[7].Kind := TYK_CLASS;
  TypeTab[7].Size := 2;
  { 8 : tuple (pointeur tableau fixe) }
  TypeTab[8].Name := 'tuple';
  TypeTab[8].Kind := TYK_TUPLE;
  TypeTab[8].Size := 2;
  { 9 : object (instance de classe) }
  TypeTab[9].Name := 'object';
  TypeTab[9].Kind := TYK_OBJECT;
  TypeTab[9].Size := 2;
  TypeCount := 10;

  If Opts.DebugMode Then
    WriteLn('  Types enregistres : ', TypeCount);
End;

{ ============================================================
  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
  ============================================================ }

{ ---- EmitProlog : prologue de fonction ----------------------- }
{ PUSH BP / MOV BP,SP / SUB SP,FrameSize (si FrameSize > 0)     }
Procedure EmitProlog(FrameSize : Integer);
Begin
  EmitInstr('PUSH BP');
  EmitInstr('MOV BP,SP');
  If FrameSize > 0 Then
    EmitInstr('SUB SP,' + IntToStr_(FrameSize));
End;

{ ---- EmitEpilog : epilogue de fonction ----------------------- }
{ MOV SP,BP / POP BP / RET                                      }
Procedure EmitEpilog;
Begin
  EmitInstr('MOV SP,BP');
  EmitInstr('POP BP');
  EmitInstr('RET');
End;

{ ============================================================
  TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
  ============================================================ }

{ ---- ExprLoadToAX : charger une variable dans AX ------------- }
{ Globale (scope=0) : MOV AX, [_PYV_x]                          }
{ Locale  (offset<0): MOV AX, [BP-offset]                       }
{ Param   (offset>0): MOV AX, [BP+offset]                       }
Procedure ExprLoadToAX(SIdx : Integer);
Var
  Off : Integer;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then
  Begin
    EmitInstr('XOR    AX, AX');
    Exit;
  End;
  If (SymTab[SIdx].ScopeLevel = 0) Or (SymTab[SIdx].IsGlobal) Then
  Begin
    { Variable globale : acces par label dans segment DATA }
    EnsureVarInData(SIdx);
    EmitInstr('MOV    AX, [' + SymTab[SIdx].MangledName + ']');
  End
  Else If SymTab[SIdx].Kind = SK_PARAM Then
  Begin
    { Parametre : [BP+offset] (offset positif, +4 pour ret addr+old BP) }
    Off := SymTab[SIdx].Offset;
    If Off >= 0 Then
      EmitInstr('MOV    AX, [BP+' + IntToStr_(Off) + ']')
    Else
      EmitInstr('MOV    AX, [BP' + IntToStr_(Off) + ']');
  End
  Else
  Begin
    { Variable locale : [BP-offset] (offset negatif ou 0) }
    Off := SymTab[SIdx].Offset;
    If Off = 0 Then
      EmitInstr('MOV    AX, [BP]')
    Else If Off > 0 Then
      EmitInstr('MOV    AX, [BP-' + IntToStr_(Off) + ']')
    Else
      EmitInstr('MOV    AX, [BP+' + IntToStr_(-Off) + ']');
  End;
End;

{ ---- EmitStoreVar : stocker AX dans une variable ------------- }
{ Globale (scope=0) : MOV [_PYV_x], AX                          }
{ Locale  (offset>0): MOV [BP-offset], AX                       }
{ Param   (offset>0): MOV [BP+offset], AX                       }
Procedure EmitStoreVar(SIdx : Integer);
Var
  Off : Integer;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then Exit;
  If (SymTab[SIdx].ScopeLevel = 0) Or (SymTab[SIdx].IsGlobal) Then
  Begin
    { Variable globale : stocker dans segment DATA }
    EnsureVarInData(SIdx);
    EmitInstr('MOV    [' + SymTab[SIdx].MangledName + '], AX');
  End
  Else If SymTab[SIdx].Kind = SK_PARAM Then
  Begin
    Off := SymTab[SIdx].Offset;
    If Off >= 0 Then
      EmitInstr('MOV    [BP+' + IntToStr_(Off) + '], AX')
    Else
      EmitInstr('MOV    [BP' + IntToStr_(Off) + '], AX');
  End
  Else
  Begin
    Off := SymTab[SIdx].Offset;
    If Off = 0 Then
      EmitInstr('MOV    [BP], AX')
    Else If Off > 0 Then
      EmitInstr('MOV    [BP-' + IntToStr_(Off) + '], AX')
    Else
      EmitInstr('MOV    [BP+' + IntToStr_(-Off) + '], AX');
  End;
End;

{ ---- EnsureVarInData : s assurer qu une globale a un DW ------ }
{ Si la variable globale n a pas encore d entree DATA, en creer   }
{ une (DK_WORD initialise a 0) avec le label _PYV_x.             }
Procedure EnsureVarInData(SIdx : Integer);
Var
  I : Integer;
  Lbl : TString;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then Exit;
  Lbl := SymTab[SIdx].MangledName;
  { Verifier si deja dans DataTab }
  For I := 0 To DataCount - 1 Do
    If DataTab[I].LblName = Lbl Then Exit;
  { Ajouter un DW 0 }
  DataAddWord(Lbl, 0);
End;

{ ---- ParseAssign : parser une affectation -------------------- }
{ Appelee quand on a un identifiant suivi de '=' ou op-assign.    }
{ Gere :                                                          }
{   x = expr           (affectation simple)                       }
{   x += expr          (affectation augmentee)                    }
{   a, b = e1, e2      (affectation multiple)                    }
{   a, b = b, a        (echange via pile temporaire)             }
Procedure ParseAssign(FirstSymIdx : Integer);
Var
  Op     : TString;
  RHS    : TExprVal;
  Targets : Array[0..MAX_PARAM - 1] Of Integer;  { indices symboles }
  NTargets : Integer;
  Vals   : Array[0..MAX_PARAM - 1] Of TExprVal;
  NVals  : Integer;
  VName  : TString;
  I, SIdx : Integer;
Begin
  NTargets := 1;
  Targets[0] := FirstSymIdx;

  { Collecter les cibles d affectation multiple : a, b, c = ... }
  While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
  Begin
    ParserAdvance;
    If CurToken.Kind = TK_IDENT Then
    Begin
      VName := CurToken.Val;
      SIdx := SymFind(VName);
      If SIdx < 0 Then
        SIdx := SymAdd(VName, SK_VAR, TY_UNKNOWN, 0);
      If NTargets < MAX_PARAM Then
      Begin
        Targets[NTargets] := SIdx;
        Inc(NTargets);
      End;
      ParserAdvance;
    End
    Else
      Break;
  End;

  { Determiner le type d affectation }
  If (CurToken.Kind = TK_OP) And IsAssignOp(CurToken.Val) Then
  Begin
    Op := CurToken.Val;
    ParserAdvance;

    If Op = '=' Then
    Begin
      { ---- Affectation simple ou multiple ---- }
      If NTargets = 1 Then
      Begin
        { Simple : x = expr }
        EmitComment('assign: ' + SymTab[Targets[0]].Name + ' = expr');
        ParseExpr(RHS);
        ExprFlushToAX(RHS);
        EmitStoreVar(Targets[0]);
        { Propager le type de l expression vers la variable (TODO 15) }
        If RHS.TypeIdx <> TY_UNKNOWN Then
          SymTab[Targets[0]].TypeIdx := RHS.TypeIdx;
      End
      Else
      Begin
        { Multiple : a, b = expr1, expr2 ou a, b, c = tuple }
        EmitComment('assign multiple: ' + IntToStr_(NTargets) + ' targets');
        { Parser la premiere expression }
        ParseExpr(RHS);
        ExprFlushToAX(RHS);
        { TODO 19 : Unpacking de tuple : a, b, c = tup }
        If (Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ','))) And
           ((RHS.TypeIdx = TY_IDX_TUPLE) Or (RHS.TypeIdx = TY_IDX_LIST)) Then
        Begin
          EmitComment('tuple/list unpacking');
          EmitInstr('MOV    SI, AX');    { SI = ptr tuple/list }
          For I := 0 To NTargets - 1 Do
          Begin
            EmitInstr('MOV    AX, [SI+' + IntToStr_(2 + I * 2) + ']');
            EmitStoreVar(Targets[I]);
          End;
        End
        Else
        Begin
          { Affectation multiple classique : a, b = expr1, expr2 }
          EmitInstr('PUSH   AX');
          NVals := 1;
          For I := 1 To NTargets - 1 Do
          Begin
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
              ParserAdvance;
            If NVals < MAX_PARAM Then
            Begin
              ParseExpr(Vals[NVals]);
              ExprFlushToAX(Vals[NVals]);
              EmitInstr('PUSH   AX');
              Inc(NVals);
            End;
          End;
          { Stocker en ordre inverse (dernier pousse = premier depile) }
          For I := NVals - 1 DownTo 0 Do
          Begin
            EmitInstr('POP    AX');
            EmitStoreVar(Targets[I]);
          End;
        End;
      End;
    End
    Else
    Begin
      { ---- Affectation augmentee : x += expr, x -= expr, etc. ---- }
      EmitComment('augmented assign: ' + SymTab[Targets[0]].Name +
                  ' ' + Op + ' expr');
      { Charger la valeur courante de la variable }
      ExprLoadToAX(Targets[0]);
      EmitInstr('PUSH   AX');
      { Evaluer l expression droite }
      ParseExpr(RHS);
      ExprFlushToAX(RHS);
      EmitInstr('MOV    BX, AX');
      EmitInstr('POP    AX');
      { Appliquer l operateur }
      If      Op = '+='  Then EmitInstr('ADD    AX, BX')
      Else If Op = '-='  Then EmitInstr('SUB    AX, BX')
      Else If Op = '*='  Then EmitInstr('IMUL   BX')
      Else If Op = '//=' Then
      Begin
        EmitInstr('CWD');
        EmitInstr('IDIV   BX');
      End
      Else If Op = '/='  Then
      Begin
        EmitInstr('CWD');
        EmitInstr('IDIV   BX');
      End
      Else If Op = '%='  Then
      Begin
        EmitInstr('CWD');
        EmitInstr('IDIV   BX');
        EmitInstr('MOV    AX, DX');
      End
      Else If Op = '&='  Then EmitInstr('AND    AX, BX')
      Else If Op = '|='  Then EmitInstr('OR     AX, BX')
      Else If Op = '^='  Then EmitInstr('XOR    AX, BX')
      Else If Op = '<<=' Then
      Begin
        EmitInstr('MOV    CX, BX');
        EmitInstr('SHL    AX, CL');
      End
      Else If Op = '>>=' Then
      Begin
        EmitInstr('MOV    CX, BX');
        EmitInstr('SAR    AX, CL');
      End
      Else If Op = '**=' Then
      Begin
        EmitInstr('MOV    CX, BX');
        EmitInstr('CALL   ' + PY_RT_PFX + 'POWER');
      End;
      { Stocker le resultat }
      EmitStoreVar(Targets[0]);
    End;
  End;
End;

{ ============================================================
  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
  ============================================================ }

{ ---- EmitBuiltinCall : emettre l appel d un builtin ---------- }
{ len(x) -> CALL _PYRT_LEN ; abs(x) -> CALL _PYRT_ABS ; etc.    }
{ L argument est dans AX a l entree ; resultat dans AX.           }
Procedure EmitBuiltinCall(SIdx : Integer; ArgTypeIdx : Integer;
                         Var Res : TExprVal);
Var
  Name : TString;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then
  Begin
    EmitComment('builtin: unknown');
    ExprMakeAX(TY_IDX_INT, Res);
    Exit;
  End;
  Name := SymTab[SIdx].Name;
  EmitComment('builtin call: ' + Name);

  If Name = 'len' Then
  Begin
    EmitInstr('MOV    SI, AX');
    If (ArgTypeIdx = TY_IDX_LIST) Or (ArgTypeIdx = TY_IDX_DICT) Or
       (ArgTypeIdx = TY_IDX_TUPLE) Then
      EmitInstr('MOV    AX, [SI]')   { liste/dict/tuple : count en tete }
    Else
      EmitInstr('CALL   ' + PY_RT_PFX + 'LEN');  { chaine ASCIIZ }
    ExprMakeAX(TY_IDX_INT, Res);
  End
  Else If Name = 'abs' Then
  Begin
    { AX = valeur, resultat absolu dans AX }
    EmitInstr('CWD');
    EmitInstr('XOR    AX, DX');
    EmitInstr('SUB    AX, DX');
    ExprMakeAX(TY_IDX_INT, Res);
  End
  Else If Name = 'int' Then
  Begin
    { int(x) : deja entier dans AX pour notre cible 8086 }
    ExprMakeAX(TY_IDX_INT, Res);
  End
  Else If Name = 'str' Then
  Begin
    { str(x) : convertir entier -> chaine via runtime }
    EmitInstr('CALL   ' + PY_RT_PFX + 'INTTOSTR');
    ExprMakeAX(TY_IDX_STR, Res);
  End
  Else If Name = 'chr' Then
  Begin
    { chr(x) : caractere unique - stocker dans buffer }
    EmitInstr('MOV    BYTE PTR [_PY_STRBUF], AL');
    EmitInstr('MOV    BYTE PTR [_PY_STRBUF+1], 0');
    EmitInstr('MOV    AX, OFFSET _PY_STRBUF');
    ExprMakeAX(TY_IDX_STR, Res);
  End
  Else If Name = 'ord' Then
  Begin
    { ord(x) : premier caractere de la chaine -> entier }
    EmitInstr('MOV    SI, AX');
    EmitInstr('XOR    AH, AH');
    EmitInstr('MOV    AL, [SI]');
    ExprMakeAX(TY_IDX_INT, Res);
  End
  Else If Name = 'bool' Then
  Begin
    { bool(x) : 0->0, non-0->1 }
    EmitInstr('TEST   AX, AX');
    EmitInstr('MOV    AX, 0');
    EmitInstr('JZ     $+4');
    EmitInstr('INC    AX');
    ExprMakeAX(TY_IDX_BOOL, Res);
  End
  Else If Name = 'print' Then
  Begin
    { print(x) : appeler le runtime print }
    EmitInstr('CALL   ' + PY_RT_PFX + 'PRINT');
    ExprMakeAX(TY_IDX_NONE, Res);
  End
  Else If Name = 'input' Then
  Begin
    { input() : lire une ligne }
    EmitInstr('CALL   ' + PY_RT_PFX + 'INPUT');
    ExprMakeAX(TY_IDX_STR, Res);
  End
  Else If Name = 'hex' Then
  Begin
    EmitInstr('CALL   ' + PY_RT_PFX + 'TOHEX');
    ExprMakeAX(TY_IDX_STR, Res);
  End
  Else If Name = 'oct' Then
  Begin
    EmitInstr('CALL   ' + PY_RT_PFX + 'TOOCT');
    ExprMakeAX(TY_IDX_STR, Res);
  End
  Else If Name = 'bin' Then
  Begin
    EmitInstr('CALL   ' + PY_RT_PFX + 'TOBIN');
    ExprMakeAX(TY_IDX_STR, Res);
  End
  Else If (Name = 'min') Or (Name = 'max') Then
  Begin
    { min/max(a,b) : AX=premier arg deja pousse, BX disponible }
    { L appelant pousse les args ; on recupere le 2eme depuis BX }
    EmitInstr('POP    BX');  { 2eme argument }
    If Name = 'min' Then
    Begin
      EmitInstr('CMP    AX, BX');
      EmitInstr('JLE    $+4');
      EmitInstr('MOV    AX, BX');
    End
    Else
    Begin
      EmitInstr('CMP    AX, BX');
      EmitInstr('JGE    $+4');
      EmitInstr('MOV    AX, BX');
    End;
    ExprMakeAX(TY_IDX_INT, Res);
  End
  Else If Name = 'isinstance' Then
  Begin
    { isinstance(obj, ClassName) : AX = obj (premier arg depile)     }
    { Le deuxieme arg est le typecode de la classe (pousse avant)    }
    EmitInstr('POP    BX');           { BX = typecode classe }
    EmitInstr('MOV    SI, AX');       { SI = pointeur objet  }
    EmitInstr('MOV    CX, [SI]');     { CX = typecode objet  }
    EmitInstr('XOR    AX, AX');
    EmitInstr('CMP    CX, BX');
    EmitInstr('JNE    $+4');
    EmitInstr('INC    AX');
    ExprMakeAX(TY_IDX_BOOL, Res);
  End
  Else If Name = 'pow' Then
  Begin
    { pow(base, exp) : AX=base (premier arg), CX=exp (deuxieme arg) }
    EmitInstr('POP    CX');           { CX = exposant }
    EmitInstr('CALL   ' + PY_RT_PFX + 'POW');
    ExprMakeAX(TY_IDX_INT, Res);
  End
  Else If Name = 'exit' Then
  Begin
    { exit(code) : sortie DOS (TODO 23) }
    EmitComment('exit(code)');
    EmitInstr('MOV    AH, 4Ch');
    EmitInstr('INT    21h');
    ExprMakeAX(TY_IDX_NONE, Res);
  End
  Else
  Begin
    { Appel builtin generique via CALL }
    EmitInstr('CALL   ' + SymTab[SIdx].MangledName);
    ExprMakeAX(SymTab[SIdx].TypeIdx, Res);
  End;
End;

{ ---- ParseCallArgs : parser les arguments d appel ------------ }
{ Appele quand CurToken = '(' apres un identifiant.              }
{ SIdx = indice du symbole de la fonction/builtin dans SymTab.   }
{ Emet PUSH pour chaque argument, puis CALL pour la fonction.    }
{ TODO 12 : traitement special pour print() et input()           }
Procedure ParseCallArgs(SIdx : Integer; Var Res : TExprVal);
Var
  ArgE       : TExprVal;
  ArgCount   : Integer;
  IsBuiltin  : Boolean;
  IsPrint    : Boolean;
  IsInput    : Boolean;
  FuncName   : TString;
  FirstArgTy : Integer;
Begin
  { Consommer le '(' }
  ParserAdvance;
  ArgCount := 0;
  FirstArgTy := TY_UNKNOWN;

  IsBuiltin := False;
  IsPrint := False;
  IsInput := False;
  FuncName := '';
  If (SIdx >= 0) And (SIdx < SymCount) Then
  Begin
    IsBuiltin := (SymTab[SIdx].Kind = SK_BUILTIN);
    FuncName := SymTab[SIdx].Name;
    IsPrint := (FuncName = 'print');
    IsInput := (FuncName = 'input');
  End;

  { ---- Traitement special de print (TODO 12) ---- }
  { print(*args) : chaque argument est affiche separement          }
  {   - entier : CALL _PYRT_PRINT                                  }
  {   - chaine : MOV SI, AX / CALL _PYRT_PRINTSTR                 }
  {   - separateur espace entre les arguments                       }
  {   - CR+LF a la fin                                              }
  If IsPrint Then
  Begin
    EmitComment('print(...)');
    If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
    Begin
      { Premier argument }
      ParseExpr(ArgE);
      ExprFlushToAX(ArgE);
      If ArgE.TypeIdx = TY_IDX_STR Then
      Begin
        EmitInstr('MOV    SI, AX');
        EmitInstr('CALL   ' + PY_RT_PFX + 'PRINTSTR');
      End
      Else
        EmitInstr('CALL   ' + PY_RT_PFX + 'PRINT');
      Inc(ArgCount);
      { Arguments suivants avec separateur espace }
      While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
      Begin
        ParserAdvance;
        { Emettre un espace separateur }
        EmitInstr('CALL   ' + PY_RT_PFX + 'PRINTSPC');
        ParseExpr(ArgE);
        ExprFlushToAX(ArgE);
        If ArgE.TypeIdx = TY_IDX_STR Then
        Begin
          EmitInstr('MOV    SI, AX');
          EmitInstr('CALL   ' + PY_RT_PFX + 'PRINTSTR');
        End
        Else
          EmitInstr('CALL   ' + PY_RT_PFX + 'PRINT');
        Inc(ArgCount);
      End;
    End;
    { Emettre le saut de ligne final }
    EmitInstr('CALL   ' + PY_RT_PFX + 'NEWLINE');
    { Consommer le ')' }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance
    Else
      CompileError(''')'' attendue apres arguments', CurToken.Line);
    ExprMakeAX(TY_IDX_NONE, Res);
    Exit;
  End;

  { ---- Traitement special de input (TODO 12) ---- }
  { input([prompt]) : affiche le prompt si present, lit une ligne }
  If IsInput Then
  Begin
    EmitComment('input(...)');
    If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
    Begin
      { Argument = prompt a afficher }
      ParseExpr(ArgE);
      ExprFlushToAX(ArgE);
      EmitInstr('MOV    SI, AX');
      EmitInstr('CALL   ' + PY_RT_PFX + 'PRINTSTR');
      Inc(ArgCount);
    End;
    { Lire une ligne }
    EmitInstr('CALL   ' + PY_RT_PFX + 'INPUT');
    { Consommer le ')' }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance
    Else
      CompileError(''')'' attendue apres arguments', CurToken.Line);
    ExprMakeAX(TY_IDX_STR, Res);
    Exit;
  End;

  { ---- Parsing generique des arguments ---- }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
  Begin
    { Premier argument }
    ParseExpr(ArgE);
    FirstArgTy := ArgE.TypeIdx;
    ExprFlushToAX(ArgE);
    EmitInstr('PUSH   AX');
    Inc(ArgCount);
    { Arguments suivants }
    While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
    Begin
      ParserAdvance;
      ParseExpr(ArgE);
      ExprFlushToAX(ArgE);
      EmitInstr('PUSH   AX');
      Inc(ArgCount);
    End;
  End;

  { Consommer le ')' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance
  Else
    CompileError(''')'' attendue apres arguments', CurToken.Line);

  { Emettre l appel }
  If IsBuiltin Then
  Begin
    { Recuperer le premier argument (ou 0 si aucun) }
    If ArgCount > 0 Then
      EmitInstr('POP    AX')
    Else
      EmitInstr('XOR    AX, AX');
    { Appeler le builtin specifique }
    EmitBuiltinCall(SIdx, FirstArgTy, Res);
    { Nettoyer les arguments supplementaires }
    If ArgCount > 1 Then
      EmitInstr('ADD    SP, ' + IntToStr_((ArgCount - 1) * 2));
  End
  Else If (SIdx >= 0) And (SIdx < SymCount) And
          (SymTab[SIdx].Kind = SK_CLASS) Then
  Begin
    { Appel de constructeur : ClassName(args) (TODO 18) }
    { 1. Allouer l objet sur le heap via _PYRT_OBJNEW    }
    { 2. Appeler __init__(self, args)                     }
    { 3. Retourner le pointeur de l objet dans AX        }
    EmitComment('constructor: ' + SymTab[SIdx].Name);
    EmitInstr('MOV    CX, ' + IntToStr_(
              ClassTab[SymTab[SIdx].Offset].ObjSize));
    EmitInstr('CALL   ' + PY_RT_PFX + 'OBJNEW');
    { Stocker le typecode dans [AX] }
    EmitInstr('MOV    WORD PTR [AX], ' +
              IntToStr_(SymTab[SIdx].Offset));
    EmitInstr('PUSH   AX');         { sauver ptr objet }
    { Empiler self + args pour __init__ }
    { Les args sont deja sur la pile (empiles avant) }
    { Ajouter self (le ptr objet) comme premier arg    }
    EmitInstr('PUSH   AX');         { self = premier param de __init__ }
    { Appeler __init__ si elle existe }
    If ClassFindMeth(SymTab[SIdx].Offset, '__init__') >= 0 Then
    Begin
      EmitInstr('CALL   ' + PY_MTH_PFX +
                SymNameClean(SymTab[SIdx].Name) + '___init__');
      { Nettoyer self + args de la pile }
      EmitInstr('ADD    SP, ' + IntToStr_((ArgCount + 1) * 2));
    End
    Else
      EmitInstr('ADD    SP, 2');  { nettoyer self seulement }
    { Recuperer le pointeur objet }
    EmitInstr('POP    AX');
    { Le resultat est un objet }
    Res.Kind    := EK_AX;
    Res.TypeIdx := TY_IDX_CLASS;
    Res.ImmVal  := SymTab[SIdx].Offset;  { index de la classe }
    Res.Offset  := 0;
    Res.SymIdx  := SIdx;
  End
  Else
  Begin
    { Appel de fonction utilisateur : CALL _PYF_func }
    If (SIdx >= 0) And (SIdx < SymCount) Then
    Begin
      EmitComment('call: ' + SymTab[SIdx].Name + ' (' +
                  IntToStr_(ArgCount) + ' args)');
      EmitInstr('CALL   ' + SymTab[SIdx].MangledName);
    End
    Else
    Begin
      EmitComment('call: unknown function');
      EmitInstr('XOR    AX, AX');
    End;
    { Nettoyer la pile des arguments }
    If ArgCount > 0 Then
      EmitInstr('ADD    SP, ' + IntToStr_(ArgCount * 2));
    If (SIdx >= 0) And (SIdx < SymCount) Then
      ExprMakeAX(SymTab[SIdx].TypeIdx, Res)
    Else
      ExprMakeAX(TY_IDX_INT, Res);
  End;
End;

{ ============================================================
  TODO 22 - COMPREHENSIONS ET GENERATEURS (SIMPLIFIE) [IMPLEMENTE]
  ============================================================ }

{ ---- CompBufReplay : rejouer le code bufferise --------------- }
{ Ecrit toutes les lignes accumulees dans CompBuf vers OutF.     }
Procedure CompBufReplay;
Var I : Integer;
Begin
  If OutFOpen Then
    For I := 1 To CompBufCount Do
      WriteLn(OutF, CompBuf[I]);
End;

{ ---- ScanLineForKeyword : detecter un mot-cle dans la ligne -- }
{ Recherche le mot-cle KW dans la suite de LexLine a partir de   }
{ LexColNo. Saute les chaines entre guillemets. Verifie les       }
{ frontieres de mot. Usage : detecter 'for' pour distinguer       }
{ comprehension de liste/dict litterale.                           }
Function ScanLineForKeyword(Const KW : TString) : Boolean;
Var
  P, KLen : Integer;
  InStr   : Boolean;
  Q       : Char;
Begin
  ScanLineForKeyword := False;
  KLen := Length(KW);
  P := LexColNo;
  InStr := False;
  Q := #0;
  While P <= Length(LexLine) Do
  Begin
    If Not InStr And ((LexLine[P] = '''') Or (LexLine[P] = '"')) Then
    Begin
      InStr := True;
      Q := LexLine[P];
      Inc(P);
      Continue;
    End;
    If InStr And (LexLine[P] = Q) Then
    Begin
      InStr := False;
      Inc(P);
      Continue;
    End;
    If InStr Then
    Begin
      Inc(P);
      Continue;
    End;
    If P + KLen - 1 <= Length(LexLine) Then
    Begin
      If Copy(LexLine, P, KLen) = KW Then
      Begin
        If ((P <= 1) Or Not (LexLine[P - 1] In
            ['a'..'z','A'..'Z','0'..'9','_'])) And
           ((P + KLen > Length(LexLine)) Or Not (LexLine[P + KLen] In
            ['a'..'z','A'..'Z','0'..'9','_'])) Then
        Begin
          ScanLineForKeyword := True;
          Exit;
        End;
      End;
    End;
    Inc(P);
  End;
End;

{ ---- ParseListComprehension --------------------------------- }
{ Syntaxe : [expr for var in iterable]                            }
{           [expr for var in iterable if cond]                     }
{ Le '[' a deja ete consomme par ParseListLiteral.                }
Procedure ParseListComprehension(Var Res : TExprVal);
Var
  ExprE     : TExprVal;
  VarName   : TString;
  VarIdx    : Integer;
  LblTest, LblEnd, LblIncr : TString;
  StartRes, EndRes, StepRes : TExprVal;
  HasStep, HasRange         : Boolean;
  CondE     : TExprVal;
Begin
  EmitComment('list comprehension');

  { Allouer une liste vide sur le heap }
  EmitInstr('MOV    DI, [_PY_HEAPTOP]');
  EmitInstr('ADD    DI, OFFSET _PY_HEAP');
  EmitInstr('MOV    WORD PTR [DI], 0');       { count = 0 }
  EmitInstr('ADD    WORD PTR [_PY_HEAPTOP], 2');
  EmitInstr('MOV    [_PY_COMPTGT], DI');      { sauvegarder ptr liste }

  { Bufferiser le code de l expression }
  CompBufActive := True;
  CompBufCount  := 0;
  ParseExpr(ExprE);
  ExprFlushToAX(ExprE);
  CompBufActive := False;

  { Attendre 'for' }
  If (CurToken.Kind <> TK_KEYWORD) Or (CurToken.Val <> 'for') Then
  Begin
    CompileError('''for'' attendu dans list comprehension', CurToken.Line);
    Exit;
  End;
  ParserAdvance;

  { Parser le nom de la variable de boucle }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('identifiant attendu apres for', CurToken.Line);
    Exit;
  End;
  VarName := CurToken.Val;
  VarIdx := SymFind(VarName);
  If VarIdx < 0 Then
    VarIdx := SymAdd(VarName, SK_VAR, TY_IDX_INT, 0);
  EnsureVarInData(VarIdx);
  ParserAdvance;

  { Attendre 'in' }
  If (CurToken.Kind <> TK_KEYWORD) Or (CurToken.Val <> 'in') Then
  Begin
    CompileError('''in'' attendu dans list comprehension', CurToken.Line);
    Exit;
  End;
  ParserAdvance;

  LblTest := LabelGen;
  LblIncr := LabelGen;
  LblEnd  := LabelGen;

  { Parser l iterable }
  HasStep  := False;
  HasRange := (CurToken.Kind = TK_IDENT) And (CurToken.Val = 'range');
  If HasRange Then
  Begin
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      ParserAdvance;
    ParseExpr(StartRes);
    ExprFlushToAX(StartRes);
    EmitInstr('PUSH   AX');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
    Begin
      ParserAdvance;
      ParseExpr(EndRes);
      ExprFlushToAX(EndRes);
      EmitInstr('PUSH   AX');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      Begin
        ParserAdvance;
        HasStep := True;
        ParseExpr(StepRes);
        ExprFlushToAX(StepRes);
        EmitInstr('PUSH   AX');
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
      If HasStep Then
      Begin
        EmitInstr('POP    CX');
        EmitInstr('POP    BX');
        EmitInstr('POP    AX');
        EmitInstr('MOV    [' + SymTab[VarIdx].MangledName + '], AX');
        EmitInstr('MOV    [_PY_FOREND], BX');
        EmitInstr('MOV    [_PY_FORSTEP], CX');
      End
      Else
      Begin
        EmitInstr('POP    BX');
        EmitInstr('POP    AX');
        EmitInstr('MOV    [' + SymTab[VarIdx].MangledName + '], AX');
        EmitInstr('MOV    [_PY_FOREND], BX');
        EmitInstr('MOV    WORD PTR [_PY_FORSTEP], 1');
      End;
    End
    Else
    Begin
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
      EmitInstr('POP    BX');
      EmitInstr('MOV    [_PY_FOREND], BX');
      EmitInstr('MOV    WORD PTR [' + SymTab[VarIdx].MangledName + '], 0');
      EmitInstr('MOV    WORD PTR [_PY_FORSTEP], 1');
    End;
  End
  Else
  Begin
    { Iteration generique sur liste }
    ParseExpr(StartRes);
    ExprFlushToAX(StartRes);
    EmitInstr('MOV    [_PY_FORITER], AX');
    EmitInstr('MOV    WORD PTR [_PY_COMPIDX], 0');
    EmitInstr('MOV    SI, AX');
    EmitInstr('MOV    CX, [SI]');
    EmitInstr('MOV    [_PY_FOREND], CX');
  End;

  { Boucle : label de test }
  EmitLabel(LblTest);
  If HasRange Then
  Begin
    EmitInstr('MOV    AX, [' + SymTab[VarIdx].MangledName + ']');
    EmitInstr('CMP    AX, [_PY_FOREND]');
    EmitInstr('JGE    ' + LblEnd);
  End
  Else
  Begin
    { Iteration generique : charger element courant dans la variable }
    EmitInstr('MOV    BX, [_PY_COMPIDX]');
    EmitInstr('CMP    BX, [_PY_FOREND]');
    EmitInstr('JGE    ' + LblEnd);
    EmitInstr('MOV    SI, [_PY_FORITER]');
    EmitInstr('SHL    BX, 1');
    EmitInstr('ADD    BX, 2');
    EmitInstr('MOV    AX, [SI+BX]');
    EmitInstr('MOV    [' + SymTab[VarIdx].MangledName + '], AX');
  End;

  { Filtre optionnel : if cond (emis directement, pas bufferise) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'if') Then
  Begin
    ParserAdvance;
    ParseExpr(CondE);
    ExprFlushToAX(CondE);
    EmitInstr('TEST   AX, AX');
    EmitInstr('JZ     ' + LblIncr);
  End;

  { Rejouer le code de l expression bufferisee }
  CompBufReplay;

  { Appeler LISTAPPEND : SI = liste, AX = valeur }
  EmitInstr('MOV    SI, [_PY_COMPTGT]');
  EmitInstr('CALL   _PYRT_LISTAPPEND');

  { Incrementer }
  EmitLabel(LblIncr);
  If HasRange Then
  Begin
    EmitInstr('MOV    AX, [' + SymTab[VarIdx].MangledName + ']');
    EmitInstr('ADD    AX, [_PY_FORSTEP]');
    EmitInstr('MOV    [' + SymTab[VarIdx].MangledName + '], AX');
  End
  Else
    EmitInstr('INC    WORD PTR [_PY_COMPIDX]');
  EmitInstr('JMP    ' + LblTest);

  { Fin de boucle }
  EmitLabel(LblEnd);

  { Resultat = pointeur vers la liste }
  EmitInstr('MOV    AX, [_PY_COMPTGT]');

  { Consommer ']' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
    ParserAdvance
  Else
    CompileError(''']'' attendue apres list comprehension', CurToken.Line);

  ExprMakeAX(TY_IDX_LIST, Res);
End;

{ ---- ParseDictComprehension --------------------------------- }
{ Syntaxe : (kexpr:vexpr for var in iterable)                     }
{           (kexpr:vexpr for var in iterable if cond)              }
{ Le accolade ouvrante a deja ete consomme par ParseDictLiteral.  }
Procedure ParseDictComprehension(Var Res : TExprVal);
Var
  KeyE, ValE : TExprVal;
  VarName    : TString;
  VarIdx     : Integer;
  LblTest, LblEnd, LblIncr : TString;
  StartRes, EndRes, StepRes : TExprVal;
  HasStep, HasRange : Boolean;
  CondE      : TExprVal;
Begin
  EmitComment('dict comprehension');

  { Allouer un dict vide sur le heap }
  EmitInstr('MOV    DI, [_PY_HEAPTOP]');
  EmitInstr('ADD    DI, OFFSET _PY_HEAP');
  EmitInstr('MOV    WORD PTR [DI], 0');       { count = 0 }
  EmitInstr('ADD    WORD PTR [_PY_HEAPTOP], 2');
  EmitInstr('MOV    [_PY_COMPTGT], DI');      { sauvegarder ptr dict }

  { Bufferiser le code de la cle }
  CompBufActive := True;
  CompBufCount  := 0;
  ParseExpr(KeyE);
  ExprFlushToAX(KeyE);
  CompBufActive := False;

  { Ajouter PUSH AX dans le buffer pour sauvegarder la cle }
  If CompBufCount < MAX_COMP_BUF Then
  Begin
    Inc(CompBufCount);
    CompBuf[CompBufCount] := '        PUSH   AX';
  End;

  { Attendre ':' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    ParserAdvance
  Else
    CompileError(''':'' attendue dans dict comprehension', CurToken.Line);

  { Bufferiser le code de la valeur (ajoute apres cle + PUSH AX) }
  CompBufActive := True;
  ParseExpr(ValE);
  ExprFlushToAX(ValE);
  CompBufActive := False;
  { CompBuf contient : code_cle + PUSH AX + code_valeur }

  { Attendre 'for' }
  If (CurToken.Kind <> TK_KEYWORD) Or (CurToken.Val <> 'for') Then
  Begin
    CompileError('''for'' attendu dans dict comprehension', CurToken.Line);
    Exit;
  End;
  ParserAdvance;

  { Parser le nom de la variable de boucle }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('identifiant attendu apres for', CurToken.Line);
    Exit;
  End;
  VarName := CurToken.Val;
  VarIdx := SymFind(VarName);
  If VarIdx < 0 Then
    VarIdx := SymAdd(VarName, SK_VAR, TY_IDX_INT, 0);
  EnsureVarInData(VarIdx);
  ParserAdvance;

  { Attendre 'in' }
  If (CurToken.Kind <> TK_KEYWORD) Or (CurToken.Val <> 'in') Then
  Begin
    CompileError('''in'' attendu dans dict comprehension', CurToken.Line);
    Exit;
  End;
  ParserAdvance;

  LblTest := LabelGen;
  LblIncr := LabelGen;
  LblEnd  := LabelGen;

  { Parser l iterable }
  HasStep  := False;
  HasRange := (CurToken.Kind = TK_IDENT) And (CurToken.Val = 'range');
  If HasRange Then
  Begin
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      ParserAdvance;
    ParseExpr(StartRes);
    ExprFlushToAX(StartRes);
    EmitInstr('PUSH   AX');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
    Begin
      ParserAdvance;
      ParseExpr(EndRes);
      ExprFlushToAX(EndRes);
      EmitInstr('PUSH   AX');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      Begin
        ParserAdvance;
        HasStep := True;
        ParseExpr(StepRes);
        ExprFlushToAX(StepRes);
        EmitInstr('PUSH   AX');
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
      If HasStep Then
      Begin
        EmitInstr('POP    CX');
        EmitInstr('POP    BX');
        EmitInstr('POP    AX');
        EmitInstr('MOV    [' + SymTab[VarIdx].MangledName + '], AX');
        EmitInstr('MOV    [_PY_FOREND], BX');
        EmitInstr('MOV    [_PY_FORSTEP], CX');
      End
      Else
      Begin
        EmitInstr('POP    BX');
        EmitInstr('POP    AX');
        EmitInstr('MOV    [' + SymTab[VarIdx].MangledName + '], AX');
        EmitInstr('MOV    [_PY_FOREND], BX');
        EmitInstr('MOV    WORD PTR [_PY_FORSTEP], 1');
      End;
    End
    Else
    Begin
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
      EmitInstr('POP    BX');
      EmitInstr('MOV    [_PY_FOREND], BX');
      EmitInstr('MOV    WORD PTR [' + SymTab[VarIdx].MangledName + '], 0');
      EmitInstr('MOV    WORD PTR [_PY_FORSTEP], 1');
    End;
  End
  Else
  Begin
    { Iteration generique sur liste }
    ParseExpr(StartRes);
    ExprFlushToAX(StartRes);
    EmitInstr('MOV    [_PY_FORITER], AX');
    EmitInstr('MOV    WORD PTR [_PY_COMPIDX], 0');
    EmitInstr('MOV    SI, AX');
    EmitInstr('MOV    CX, [SI]');
    EmitInstr('MOV    [_PY_FOREND], CX');
  End;

  { Boucle : label de test }
  EmitLabel(LblTest);
  If HasRange Then
  Begin
    EmitInstr('MOV    AX, [' + SymTab[VarIdx].MangledName + ']');
    EmitInstr('CMP    AX, [_PY_FOREND]');
    EmitInstr('JGE    ' + LblEnd);
  End
  Else
  Begin
    EmitInstr('MOV    BX, [_PY_COMPIDX]');
    EmitInstr('CMP    BX, [_PY_FOREND]');
    EmitInstr('JGE    ' + LblEnd);
    EmitInstr('MOV    SI, [_PY_FORITER]');
    EmitInstr('SHL    BX, 1');
    EmitInstr('ADD    BX, 2');
    EmitInstr('MOV    AX, [SI+BX]');
    EmitInstr('MOV    [' + SymTab[VarIdx].MangledName + '], AX');
  End;

  { Filtre optionnel : if cond (emis directement) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'if') Then
  Begin
    ParserAdvance;
    ParseExpr(CondE);
    ExprFlushToAX(CondE);
    EmitInstr('TEST   AX, AX');
    EmitInstr('JZ     ' + LblIncr);
  End;

  { Rejouer le buffer : code_cle + PUSH AX + code_valeur }
  CompBufReplay;
  { Apres replay : AX = valeur, cle sur la pile }

  { DICTSET : SI = dict, AX = cle, BX = valeur }
  EmitInstr('MOV    BX, AX');                  { BX = valeur }
  EmitInstr('POP    AX');                      { AX = cle }
  EmitInstr('MOV    SI, [_PY_COMPTGT]');
  EmitInstr('CALL   _PYRT_DICTSET');

  { Incrementer }
  EmitLabel(LblIncr);
  If HasRange Then
  Begin
    EmitInstr('MOV    AX, [' + SymTab[VarIdx].MangledName + ']');
    EmitInstr('ADD    AX, [_PY_FORSTEP]');
    EmitInstr('MOV    [' + SymTab[VarIdx].MangledName + '], AX');
  End
  Else
    EmitInstr('INC    WORD PTR [_PY_COMPIDX]');
  EmitInstr('JMP    ' + LblTest);

  { Fin de boucle }
  EmitLabel(LblEnd);

  { Resultat = pointeur vers le dict }
  EmitInstr('MOV    AX, [_PY_COMPTGT]');

  (* Consommer accolade fermante *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance
  Else
    CompileError('accolade fermante attendue apres dict comprehension',
                 CurToken.Line);

  ExprMakeAX(TY_IDX_DICT, Res);
End;

{ ============================================================
  TODO 23 - MODULES ET IMPORT (SIMPLIFIE) [IMPLEMENTE]
  ============================================================ }

{ ---- ImportFind : chercher un module dans ImportTab ----------- }
Function ImportFind(Const Name : TString) : Integer;
Var I : Integer;
Begin
  ImportFind := -1;
  For I := 0 To ImportCount - 1 Do
    If ImportTab[I] = Name Then
    Begin
      ImportFind := I;
      Exit;
    End;
End;

{ ---- ImportAdd : enregistrer un module dans ImportTab --------- }
Function ImportAdd(Const Name : TString) : Integer;
Begin
  If ImportFind(Name) >= 0 Then
  Begin
    ImportAdd := ImportFind(Name);
    Exit;
  End;
  If ImportCount >= MAX_IMPORT Then
  Begin
    CompileError('trop de modules importes (max=' +
                 IntToStr_(MAX_IMPORT) + ')', CurToken.Line);
    ImportAdd := -1;
    Exit;
  End;
  ImportTab[ImportCount] := Name;
  ImportAdd := ImportCount;
  Inc(ImportCount);
End;

{ ---- ParseImportStmt : import module_name --------------------- }
{ Syntaxe : import math / import sys / import os / import other   }
{ Modules connus (math, sys) : enregistrer dans ImportTab et      }
{   ajouter un symbole SK_MODULE dans SymTab.                     }
{ Modules inconnus : emettre une declaration EXTRN en ASM.        }
Procedure ParseImportStmt;
Var
  ModName : TString;
  Idx     : Integer;
Begin
  { CurToken = 'import' deja verifie }
  ParserAdvance;   { consommer 'import' }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('nom de module attendu apres ''import''', CurToken.Line);
    Exit;
  End;
  ModName := CurToken.Val;
  EmitComment('import ' + ModName);
  ParserAdvance;   { consommer le nom du module }

  { Enregistrer le module }
  ImportAdd(ModName);

  { Module math : ses fonctions sont deja des builtins }
  If ModName = 'math' Then
  Begin
    Idx := SymFind('math');
    If Idx < 0 Then
    Begin
      Idx := SymAdd('math', SK_MODULE, TY_IDX_MODULE, 0);
      If Idx >= 0 Then
        SymTab[Idx].IsImported := True;
    End;
    { S assurer que pow est declare comme builtin }
    If SymFind('pow') < 0 Then
    Begin
      Idx := SymAdd('pow', SK_BUILTIN, TY_IDX_INT, 0);
      If Idx >= 0 Then
        SymTab[Idx].IsImported := True;
    End;
  End
  { Module sys : sys.exit(code) -> sortie DOS }
  Else If ModName = 'sys' Then
  Begin
    Idx := SymFind('sys');
    If Idx < 0 Then
    Begin
      Idx := SymAdd('sys', SK_MODULE, TY_IDX_MODULE, 0);
      If Idx >= 0 Then
        SymTab[Idx].IsImported := True;
    End;
  End
  { Module os : non supporte }
  Else If ModName = 'os' Then
  Begin
    WarnMsg('module ''os'' non supporte - instruction ignoree',
            CurToken.Line);
    Idx := SymFind('os');
    If Idx < 0 Then
    Begin
      Idx := SymAdd('os', SK_MODULE, TY_IDX_MODULE, 0);
      If Idx >= 0 Then
        SymTab[Idx].IsImported := True;
    End;
  End
  Else
  Begin
    { Module externe inconnu : declarer EXTRN }
    Idx := SymFind(ModName);
    If Idx < 0 Then
    Begin
      Idx := SymAdd(ModName, SK_MODULE, TY_IDX_MODULE, 0);
      If Idx >= 0 Then
        SymTab[Idx].IsImported := True;
    End;
    EmitInstr('EXTRN  _PYM_' + ModName + ':NEAR');
  End;

  { Consommer les imports multiples : import a, b, c }
  While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
  Begin
    ParserAdvance;  { consommer ',' }
    If CurToken.Kind = TK_IDENT Then
    Begin
      ModName := CurToken.Val;
      EmitComment('import ' + ModName);
      ImportAdd(ModName);
      If (ModName <> 'math') And (ModName <> 'sys') And (ModName <> 'os') Then
      Begin
        Idx := SymFind(ModName);
        If Idx < 0 Then
        Begin
          Idx := SymAdd(ModName, SK_MODULE, TY_IDX_MODULE, 0);
          If Idx >= 0 Then
            SymTab[Idx].IsImported := True;
        End;
        EmitInstr('EXTRN  _PYM_' + ModName + ':NEAR');
      End
      Else
      Begin
        Idx := SymFind(ModName);
        If Idx < 0 Then
        Begin
          Idx := SymAdd(ModName, SK_MODULE, TY_IDX_MODULE, 0);
          If Idx >= 0 Then
            SymTab[Idx].IsImported := True;
        End;
      End;
      ParserAdvance;
    End;
  End;
End;

{ ---- ParseFromImportStmt : from module import name1, name2 --- }
{ Syntaxe : from math import abs, pow, min, max                  }
{           from sys import exit                                 }
Procedure ParseFromImportStmt;
Var
  ModName, FuncName : TString;
  Idx : Integer;
Begin
  { CurToken = 'from' deja verifie }
  ParserAdvance;   { consommer 'from' }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('nom de module attendu apres ''from''', CurToken.Line);
    Exit;
  End;
  ModName := CurToken.Val;
  ParserAdvance;   { consommer le nom du module }

  { Attendre 'import' }
  If (CurToken.Kind <> TK_KEYWORD) Or (CurToken.Val <> 'import') Then
  Begin
    CompileError('''import'' attendu apres ''from ' + ModName + '''',
                 CurToken.Line);
    Exit;
  End;
  ParserAdvance;   { consommer 'import' }

  EmitComment('from ' + ModName + ' import ...');
  ImportAdd(ModName);

  { Parser les noms importes }
  Repeat
    If CurToken.Kind = TK_OP Then
    Begin
      { from module import * }
      If CurToken.Val = '*' Then
      Begin
        EmitComment('  import * (tout)');
        ParserAdvance;
        Break;
      End;
    End;

    If CurToken.Kind <> TK_IDENT Then
    Begin
      CompileError('nom de symbole attendu apres ''import''', CurToken.Line);
      Exit;
    End;
    FuncName := CurToken.Val;
    EmitComment('  from ' + ModName + ' import ' + FuncName);
    ParserAdvance;

    { Module math : les fonctions abs, min, max sont deja des builtins }
    If ModName = 'math' Then
    Begin
      { Ajouter pow si pas encore present }
      If FuncName = 'pow' Then
      Begin
        If SymFind('pow') < 0 Then
        Begin
          Idx := SymAdd('pow', SK_BUILTIN, TY_IDX_INT, 0);
          If Idx >= 0 Then
            SymTab[Idx].IsImported := True;
        End;
      End
      Else If (FuncName = 'sqrt') Or (FuncName = 'log') Or
              (FuncName = 'sin') Or (FuncName = 'cos') Then
        WarnMsg('math.' + FuncName +
                ' non supporte en entier 16 bits - instruction ignoree',
                CurToken.Line)
      Else
      Begin
        { abs, min, max etc. deja builtins - rien a faire }
        Idx := SymFind(FuncName);
        If (Idx >= 0) And (SymTab[Idx].Kind = SK_BUILTIN) Then
          SymTab[Idx].IsImported := True;
      End;
    End
    { Module sys : exit -> sortie DOS }
    Else If ModName = 'sys' Then
    Begin
      If FuncName = 'exit' Then
      Begin
        Idx := SymFind('exit');
        If Idx < 0 Then
        Begin
          Idx := SymAdd('exit', SK_BUILTIN, TY_IDX_NONE, 0);
          If Idx >= 0 Then
            SymTab[Idx].IsImported := True;
        End;
      End
      Else If FuncName = 'argv' Then
        WarnMsg('sys.argv non supporte - instruction ignoree',
                CurToken.Line)
      Else
        WarnMsg('sys.' + FuncName + ' non supporte - instruction ignoree',
                CurToken.Line);
    End
    { Module os : non supporte }
    Else If ModName = 'os' Then
      WarnMsg('module ''os'' non supporte - instruction ignoree',
              CurToken.Line)
    Else
    Begin
      { Module externe : ajouter le symbole comme importe }
      Idx := SymFind(FuncName);
      If Idx < 0 Then
      Begin
        Idx := SymAdd(FuncName, SK_FUNC, TY_UNKNOWN, 0);
        If Idx >= 0 Then
        Begin
          SymTab[Idx].IsImported := True;
          SymTab[Idx].MangledName := '_PYM_' + ModName + '_' + FuncName;
        End;
      End;
      EmitInstr('EXTRN  _PYM_' + ModName + '_' + FuncName + ':NEAR');
    End;

    { Continuer si virgule }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance
    Else
      Break;
  Until False;
End;

{ ---- ParseListLiteral : [e0, e1, e2, ...] -------------------- }
{ Layout heap : [count DW][elem0 DW][elem1 DW]...                }
Procedure ParseListLiteral(Var Res : TExprVal);
Var
  ElemE    : TExprVal;
  ElemCount: Integer;
Begin
  EmitComment('list literal');
  { Consommer le '[' }
  ParserAdvance;
  ElemCount := 0;

  { Liste vide : [] -> heap [count=0] }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
  Begin
    ParserAdvance;
    EmitInstr('MOV    DI, [_PY_HEAPTOP]');
    EmitInstr('ADD    DI, OFFSET _PY_HEAP');
    EmitInstr('MOV    WORD PTR [DI], 0');  { count = 0 }
    EmitInstr('ADD    WORD PTR [_PY_HEAPTOP], 2');
    EmitInstr('MOV    AX, DI');
    ExprMakeAX(TY_IDX_LIST, Res);
    Exit;
  End;

  { Detecter list comprehension : [expr for var in ...] }
  If ScanLineForKeyword('for') Then
  Begin
    ParseListComprehension(Res);
    Exit;
  End;

  { Allouer le bloc dans le heap : bump allocator }
  EmitInstr('MOV    DI, [_PY_HEAPTOP]');
  EmitInstr('ADD    DI, OFFSET _PY_HEAP');

  { Parser chaque element et stocker dans [DI + 2 + 2*i] }
  ParseExpr(ElemE);
  ExprFlushToAX(ElemE);
  EmitInstr('MOV    [DI+2], AX');        { elem 0 a offset 2 }
  Inc(ElemCount);
  While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
  Begin
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
      Break;  { virgule terminale }
    ParseExpr(ElemE);
    ExprFlushToAX(ElemE);
    EmitInstr('MOV    [DI+' + IntToStr_(2 + ElemCount * 2) + '], AX');
    Inc(ElemCount);
  End;

  { Ecrire le count en tete }
  EmitInstr('MOV    WORD PTR [DI], ' + IntToStr_(ElemCount));
  { Mettre a jour le HEAPTOP : (count + 1) * 2 }
  EmitInstr('ADD    WORD PTR [_PY_HEAPTOP], ' +
            IntToStr_((ElemCount + 1) * 2));
  { Retourner le pointeur vers le bloc }
  EmitInstr('MOV    AX, DI');

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
    ParserAdvance
  Else
    CompileError(''']'' attendue', CurToken.Line);
  ExprMakeAX(TY_IDX_LIST, Res);
End;

{ ---- ParseDictLiteral : dict literal ------------------------- }
{ Cree un bloc DK_DICT dans le heap et remplit paires cle/val.   }
Procedure ParseDictLiteral(Var Res : TExprVal);
Var
  KeyE, ValE : TExprVal;
  PairCount  : Integer;
Begin
  EmitComment('dict literal');
  { Consommer le '{' }
  ParserAdvance;
  PairCount := 0;

  (* Dict vide : {} *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
  Begin
    ParserAdvance;
    { Allouer un dict vide avec count=0 }
    EmitInstr('MOV    DI, [_PY_HEAPTOP]');
    EmitInstr('ADD    DI, OFFSET _PY_HEAP');
    EmitInstr('MOV    WORD PTR [DI], 0');   { count = 0 }
    EmitInstr('ADD    WORD PTR [_PY_HEAPTOP], 2');
    EmitInstr('MOV    AX, DI');
    ExprMakeAX(TY_IDX_DICT, Res);
    Exit;
  End;

  (* Detecter dict comprehension : k:v for var in ... *)
  If ScanLineForKeyword('for') Then
  Begin
    ParseDictComprehension(Res);
    Exit;
  End;

  { Allouer dans le heap }
  EmitInstr('MOV    DI, [_PY_HEAPTOP]');
  EmitInstr('ADD    DI, OFFSET _PY_HEAP');

  { Parser paire cle:valeur - pairs start at offset 2 (after count header) }
  ParseExpr(KeyE);
  ExprFlushToAX(KeyE);
  EmitInstr('MOV    [DI+' + IntToStr_(PairCount * 4 + 2) + '], AX');  { cle }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    ParserAdvance
  Else
    CompileError(''':'' attendue dans dict literal', CurToken.Line);
  ParseExpr(ValE);
  ExprFlushToAX(ValE);
  EmitInstr('MOV    [DI+' + IntToStr_(PairCount * 4 + 4) + '], AX');  { val }
  Inc(PairCount);

  While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
  Begin
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
      Break;  { virgule terminale }
    ParseExpr(KeyE);
    ExprFlushToAX(KeyE);
    EmitInstr('MOV    [DI+' + IntToStr_(PairCount * 4 + 2) + '], AX');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      ParserAdvance
    Else
      CompileError(''':'' attendue dans dict literal', CurToken.Line);
    ParseExpr(ValE);
    ExprFlushToAX(ValE);
    EmitInstr('MOV    [DI+' + IntToStr_(PairCount * 4 + 4) + '], AX');
    Inc(PairCount);
  End;

  { Ecrire le count header }
  EmitInstr('MOV    WORD PTR [DI], ' + IntToStr_(PairCount));
  { Mettre a jour le HEAPTOP : 2 (header) + PairCount * 4 }
  EmitInstr('MOV    AX, ' + IntToStr_(PairCount * 4 + 2));
  EmitInstr('ADD    [_PY_HEAPTOP], AX');
  { Retourner le pointeur vers le bloc }
  EmitInstr('MOV    AX, DI');

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance
  Else
    CompileError('''}'' attendue', CurToken.Line);
  ExprMakeAX(TY_IDX_DICT, Res);
End;

{ ============================================================
  TODO 14 - BOUCLES : while / for / break / continue / else [IMPLEMENTE]
  ============================================================ }

{ ---- LoopPush : empiler les labels d une nouvelle boucle -------- }
Procedure LoopPush(BreakLbl, ContLbl, ElseLbl : TString);
Begin
  If LoopTop >= MAX_LOOP_NEST Then
  Begin
    CompileError('trop de boucles imbriquees', CurToken.Line);
    Exit;
  End;
  LoopBreakStack[LoopTop] := BreakLbl;
  LoopContStack[LoopTop]  := ContLbl;
  LoopElseStack[LoopTop]  := ElseLbl;
  Inc(LoopTop);
End;

{ ---- LoopPop : depiler les labels de la boucle courante --------- }
Procedure LoopPop;
Begin
  If LoopTop > 0 Then
    Dec(LoopTop);
End;

{ ---- ParseWhileStmt : while cond: bloc [else: bloc] ------------- }
Procedure ParseWhileStmt;
Var
  LblTest  : TString;
  LblEnd   : TString;
  LblElse  : TString;
  CondRes  : TExprVal;
Begin
  EmitComment('-- while --');
  ParserAdvance; { consommer 'while' }

  LblTest := LabelGen;
  LblEnd  := LabelGen;
  LblElse := LabelGen;

  { Label de test (re-evaluation de la condition) }
  EmitLabel(LblTest);

  { Parser la condition }
  ParseExpr(CondRes);
  ExprFlushToAX(CondRes);

  { Attendre ':' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    ParserAdvance
  Else
    CompileError(''':'' attendu apres condition while', CurToken.Line);

  { Saut conditionnel vers else ou fin si faux }
  EmitInstr('TEST   AX, AX');
  EmitInstr('JZ     ' + LblElse);

  { Empiler les labels pour break/continue }
  LoopPush(LblEnd, LblTest, LblElse);

  { Parser le corps de la boucle }
  ParseBlock;

  { Saut vers le test }
  EmitInstr('JMP    ' + LblTest);

  { Depiler les labels de boucle }
  LoopPop;

  { Bloc else optionnel (execute si la boucle termine normalement) }
  EmitLabel(LblElse);
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'else') Then
  Begin
    EmitComment('-- while else --');
    ParserAdvance;

    { Attendre ':' }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      ParserAdvance
    Else
      CompileError(''':'' attendu apres else', CurToken.Line);

    { Parser le bloc else }
    ParseBlock;
  End;

  { Label de fin }
  EmitLabel(LblEnd);
End;

{ ---- ParseForStmt : for var in range(...): bloc [else: bloc] ----- }
{ Supporte : for x in range(n), range(a,b), range(a,b,step)         }
Procedure ParseForStmt;
Var
  LblTest, LblIncr, LblEnd, LblElse : TString;
  VarName   : TString;
  VarIdx    : Integer;
  StartRes, EndRes, StepRes : TExprVal;
  HasStep   : Boolean;
Begin
  EmitComment('-- for --');
  ParserAdvance; { consommer 'for' }

  LblTest := LabelGen;
  LblIncr := LabelGen;
  LblEnd  := LabelGen;
  LblElse := LabelGen;

  { Parser le nom de la variable }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('identifiant attendu apres for', CurToken.Line);
    Exit;
  End;
  VarName := CurToken.Val;
  VarIdx := SymFind(VarName);
  If VarIdx < 0 Then
    VarIdx := SymAdd(VarName, SK_VAR, TY_IDX_INT, 0);
  EnsureVarInData(VarIdx);
  ParserAdvance;

  { Attendre 'in' }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'in') Then
    ParserAdvance
  Else
    CompileError('''in'' attendu apres variable for', CurToken.Line);

  { Parser l iterable : range(n), range(a,b), range(a,b,step) }
  HasStep := False;
  If (CurToken.Kind = TK_IDENT) And (CurToken.Val = 'range') Then
  Begin
    ParserAdvance; { consommer 'range' }

    { Attendre '(' }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      ParserAdvance;

    { Premier argument }
    ParseExpr(StartRes);
    ExprFlushToAX(StartRes);
    EmitInstr('PUSH   AX');   { sauvegarder arg1 }

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
    Begin
      ParserAdvance;
      { Deuxieme argument : range(start, end) }
      ParseExpr(EndRes);
      ExprFlushToAX(EndRes);
      EmitInstr('PUSH   AX');   { sauvegarder end }

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      Begin
        ParserAdvance;
        { Troisieme argument : range(start, end, step) }
        HasStep := True;
        ParseExpr(StepRes);
        ExprFlushToAX(StepRes);
        EmitInstr('PUSH   AX');   { sauvegarder step }
      End;

      { Attendre ')' }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;

      If HasStep Then
      Begin
        { range(start, end, step) : step dans PUSH, end dans PUSH, start dans PUSH }
        EmitInstr('POP    CX');    { CX = step }
        EmitInstr('POP    BX');    { BX = end  }
        EmitInstr('POP    AX');    { AX = start }
        EmitInstr('MOV    [' + SymTab[VarIdx].MangledName + '], AX');
        EmitInstr('MOV    [_PY_FOREND], BX');
        EmitInstr('MOV    [_PY_FORSTEP], CX');
      End
      Else
      Begin
        { range(start, end) : end dans PUSH, start dans PUSH }
        EmitInstr('POP    BX');    { BX = end }
        EmitInstr('POP    AX');    { AX = start }
        EmitInstr('MOV    [' + SymTab[VarIdx].MangledName + '], AX');
        EmitInstr('MOV    [_PY_FOREND], BX');
        EmitInstr('MOV    WORD PTR [_PY_FORSTEP], 1');
      End;
    End
    Else
    Begin
      { range(n) : n est la fin, debut = 0 }
      { Attendre ')' }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;

      EmitInstr('POP    BX');    { BX = n }
      EmitInstr('MOV    [_PY_FOREND], BX');
      EmitInstr('MOV    WORD PTR [' + SymTab[VarIdx].MangledName + '], 0');
      EmitInstr('MOV    WORD PTR [_PY_FORSTEP], 1');
    End;
  End
  Else
  Begin
    { for elem in iterable : iteration generique (stub basique) }
    { On evalue l iterable et on itere sur les caracteres si string }
    ParseExpr(StartRes);
    ExprFlushToAX(StartRes);
    EmitInstr('MOV    SI, AX');        { SI = ptr iterable }
    EmitInstr('MOV    WORD PTR [' + SymTab[VarIdx].MangledName + '], 0'); { index = 0 }
    { Stocker la longueur dans _PY_FOREND }
    EmitInstr('CALL   _PYRT_LEN');     { AX = longueur }
    EmitInstr('MOV    [_PY_FOREND], AX');
    EmitInstr('MOV    WORD PTR [_PY_FORSTEP], 1');
    EmitInstr('MOV    [_PY_FORITER], SI'); { sauvegarder le ptr iterable }
  End;

  { Attendre ':' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    ParserAdvance
  Else
    CompileError(''':'' attendu apres for', CurToken.Line);

  { Empiler les labels pour break/continue }
  LoopPush(LblEnd, LblIncr, LblElse);

  { Label de test }
  EmitLabel(LblTest);

  { Comparaison : var < end (ou > end si step negatif) }
  EmitInstr('MOV    AX, [' + SymTab[VarIdx].MangledName + ']');
  EmitInstr('CMP    AX, [_PY_FOREND]');
  EmitInstr('JGE    ' + LblElse);

  { Corps de la boucle }
  ParseBlock;

  { Label d increment }
  EmitLabel(LblIncr);

  { Incrementer la variable }
  EmitInstr('MOV    AX, [' + SymTab[VarIdx].MangledName + ']');
  EmitInstr('ADD    AX, [_PY_FORSTEP]');
  EmitInstr('MOV    [' + SymTab[VarIdx].MangledName + '], AX');

  { Saut vers le test }
  EmitInstr('JMP    ' + LblTest);

  { Bloc else optionnel }
  EmitLabel(LblElse);
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'else') Then
  Begin
    EmitComment('-- for else --');
    ParserAdvance;

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      ParserAdvance
    Else
      CompileError(''':'' attendu apres else', CurToken.Line);

    ParseBlock;
  End;

  { Label de fin }
  EmitLabel(LblEnd);

  { Depiler les labels de boucle }
  LoopPop;
End;

{ ============================================================
  TODO 17 - FONCTIONS (def) ET RETURN [IMPLEMENTE]
  ============================================================ }

{ ---- ParseDefStmt : parser une definition de fonction -------- }
{ def nom(param1, param2, ..., paramN=default): bloc             }
{ Convention d appel cdecl 16 bits :                              }
{   Arguments empiles droite a gauche par l appelant               }
{   Pile a l entree : [paramN][...][param1][ret addr]             }
{   Prologue : PUSH BP / MOV BP,SP / SUB SP, locals_size          }
{   Acces params : [BP+4] = param1, [BP+6] = param2, ...         }
{   Acces locaux : [BP-2] = local1, [BP-4] = local2, ...         }
{   Epilogue : label_ret: MOV SP,BP / POP BP / RET               }
{   Return : MOV AX, val + JMP label_ret                         }
Procedure ParseDefStmt;
Var
  FuncName     : TString;
  FuncIdx      : Integer;
  ParamName    : TString;
  ParamCount   : Integer;
  ParamIdx     : Integer;
  DefaultVal   : TExprVal;
  HasDefault   : Boolean;
  LblSkipFunc  : TString;
  LblRet       : TString;
  SaveRetLabel : TString;
  SaveLocals   : Integer;
  SaveInFunc   : Boolean;
  I            : Integer;
Begin
  EmitComment('-- def --');
  ParserAdvance;  { consommer 'def' }

  { Nom de la fonction }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('nom de fonction attendu apres ''def''', CurToken.Line);
    Exit;
  End;
  FuncName := CurToken.Val;
  ParserAdvance;

  { Enregistrer la fonction dans la table des symboles }
  FuncIdx := SymFind(FuncName);
  If FuncIdx < 0 Then
    FuncIdx := SymAdd(FuncName, SK_FUNC, TY_IDX_INT, 0)
  Else
  Begin
    SymTab[FuncIdx].Kind := SK_FUNC;
    SymTab[FuncIdx].MangledName := PY_FN_PFX + SymNameClean(FuncName);
  End;

  { Saut au-dela du corps de la fonction dans le flux d execution }
  LblSkipFunc := LabelGen;
  EmitInstr('JMP    ' + LblSkipFunc);
  EmitBlankLine;

  { Label de la fonction }
  EmitLabel(PY_FN_PFX + SymNameClean(FuncName));

  { Generer le label d epilogue }
  LblRet := LabelGen;

  { Sauvegarder le contexte englobant }
  SaveRetLabel := FuncRetLabel;
  SaveLocals   := FuncLocalsSize;
  SaveInFunc   := InFunction;
  FuncRetLabel   := LblRet;
  FuncLocalsSize := 0;
  InFunction     := True;

  { Entrer dans la portee de la fonction }
  SymEnterScope;

  { Parser les parametres }
  ParamCount := 0;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance;  { consommer '(' }
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
    Begin
      If CurToken.Kind = TK_IDENT Then
      Begin
        ParamName := CurToken.Val;
        ParserAdvance;
        { Verifier parametre par defaut }
        HasDefault := False;
        If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
        Begin
          ParserAdvance;  { consommer '=' }
          HasDefault := True;
          { Sauter la valeur par defaut (on la gere cote appelant) }
          While (CurToken.Kind <> TK_EOF) And
                Not ((CurToken.Kind = TK_PUNCT) And
                     ((CurToken.Val = ',') Or (CurToken.Val = ')'))) Do
            ParserAdvance;
        End;
        { Ajouter le parametre : offset = +4 + ParamCount*2 }
        { +4 pour sauter old BP (2) + return address (2)    }
        ParamIdx := SymAdd(ParamName, SK_PARAM, TY_UNKNOWN,
                           4 + ParamCount * 2);
        Inc(ParamCount);
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;  { consommer ')' }
  End;

  { Attendre ':' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    ParserAdvance
  Else
    CompileError(''':'' attendue apres la liste de parametres', CurToken.Line);

  { Prologue de la fonction }
  EmitProlog(0);   { locaux = 0 pour l instant (on n alloue pas) }

  { Parser le corps de la fonction }
  ParseBlock;

  { Si pas de return explicite, retourner None (AX=0) }
  EmitInstr('XOR    AX, AX');

  { Epilogue de la fonction }
  EmitLabel(LblRet);
  EmitEpilog;
  EmitBlankLine;

  { Quitter la portee de la fonction }
  SymLeaveScope;

  { Restaurer le contexte englobant }
  FuncRetLabel   := SaveRetLabel;
  FuncLocalsSize := SaveLocals;
  InFunction     := SaveInFunc;

  { Label pour reprendre l execution apres le def }
  EmitLabel(LblSkipFunc);
End;

{ ---- ParseReturnStmt : parser une instruction return --------- }
{ return expr  -> MOV AX, val + JMP label_ret                    }
{ return       -> XOR AX, AX + JMP label_ret (None)              }
Procedure ParseReturnStmt;
Var
  RetE : TExprVal;
Begin
  EmitComment('return');
  ParserAdvance;  { consommer 'return' }

  If Not InFunction Then
  Begin
    CompileError('return en dehors d''une fonction', CurToken.Line);
    { Sauter jusqu a la fin de ligne }
    While (CurToken.Kind <> TK_EOF) And
          (CurToken.Kind <> TK_NEWLINE) Do
      ParserAdvance;
    Exit;
  End;

  { return avec valeur ou sans valeur ? }
  If (CurToken.Kind <> TK_NEWLINE) And
     (CurToken.Kind <> TK_EOF) And
     (CurToken.Kind <> TK_DEDENT) Then
  Begin
    { return expr }
    ParseExpr(RetE);
    ExprFlushToAX(RetE);
  End
  Else
  Begin
    { return sans valeur -> None (AX=0) }
    EmitInstr('XOR    AX, AX');
  End;

  { Sauter vers l epilogue }
  EmitInstr('JMP    ' + FuncRetLabel);
End;

{ ============================================================
  TODO 18 - CLASSES (class) ET OBJETS [IMPLEMENTE]
  ============================================================ }

{ ---- ClassFind : chercher une classe par nom ------------------- }
Function ClassFind(Const Name : TString) : Integer;
Var I : Integer;
Begin
  ClassFind := -1;
  For I := 0 To ClassCount - 1 Do
    If ClassTab[I].Name = Name Then
    Begin
      ClassFind := I;
      Exit;
    End;
End;

{ ---- ClassFindAttr : chercher un attribut dans une classe ------ }
Function ClassFindAttr(ClsIdx : Integer; Const AName : TString) : Integer;
Var I : Integer;
Begin
  ClassFindAttr := -1;
  If (ClsIdx < 0) Or (ClsIdx >= ClassCount) Then Exit;
  For I := 0 To ClassTab[ClsIdx].AttrCount - 1 Do
    If ClassTab[ClsIdx].AttrNames[I] = AName Then
    Begin
      ClassFindAttr := I;
      Exit;
    End;
  { Chercher dans le parent si heritage }
  If ClassTab[ClsIdx].ParentIdx >= 0 Then
    ClassFindAttr := ClassFindAttr(ClassTab[ClsIdx].ParentIdx, AName);
End;

{ ---- ClassFindMeth : chercher une methode dans une classe ------ }
Function ClassFindMeth(ClsIdx : Integer; Const MName : TString) : Integer;
Var I : Integer;
Begin
  ClassFindMeth := -1;
  If (ClsIdx < 0) Or (ClsIdx >= ClassCount) Then Exit;
  For I := 0 To ClassTab[ClsIdx].MethCount - 1 Do
    If ClassTab[ClsIdx].MethNames[I] = MName Then
    Begin
      ClassFindMeth := I;
      Exit;
    End;
  { Chercher dans le parent si heritage }
  If ClassTab[ClsIdx].ParentIdx >= 0 Then
    ClassFindMeth := ClassFindMeth(ClassTab[ClsIdx].ParentIdx, MName);
End;

{ ---- ClassAddAttr : ajouter un attribut a une classe ----------- }
Function ClassAddAttr(ClsIdx : Integer; Const AName : TString) : Integer;
Var
  Existing : Integer;
Begin
  ClassAddAttr := -1;
  If (ClsIdx < 0) Or (ClsIdx >= ClassCount) Then Exit;
  { Verifier si deja present }
  Existing := ClassFindAttr(ClsIdx, AName);
  If Existing >= 0 Then
  Begin
    ClassAddAttr := Existing;
    Exit;
  End;
  { Ajouter }
  If ClassTab[ClsIdx].AttrCount >= MAX_CLS_ATTR Then Exit;
  ClassTab[ClsIdx].AttrNames[ClassTab[ClsIdx].AttrCount] := AName;
  ClassAddAttr := ClassTab[ClsIdx].AttrCount;
  Inc(ClassTab[ClsIdx].AttrCount);
  ClassTab[ClsIdx].ObjSize := 2 + ClassTab[ClsIdx].AttrCount * 2;
End;

{ ---- EmitClassRuntime : routines runtime pour les classes ------ }
{ _PYRT_OBJNEW : CX = taille en octets -> AX = pointeur objet    }
Procedure EmitClassRuntime;
Begin
  EmitBlankLine;
  EmitComment('=== Runtime classes (TODO 18) ===');
  EmitBlankLine;

  { _PYRT_OBJNEW : allouer un objet sur le heap }
  { Entree : CX = taille en octets               }
  { Sortie : AX = pointeur vers le nouvel objet  }
  EmitLabel(PY_RT_PFX + 'OBJNEW');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DI');
  EmitInstr('MOV    DI, WORD PTR [_PY_HEAPTOP]');
  EmitInstr('ADD    DI, OFFSET _PY_HEAP');
  EmitInstr('MOV    AX, DI');           { AX = adresse du nouvel objet }
  { Initialiser a zero }
  EmitInstr('PUSH   AX');
  EmitInstr('PUSH   CX');
  EmitInstr('XOR    BX, BX');
  EmitLabel(PY_RT_PFX + 'OBJNEW_Z');
  EmitInstr('CMP    BX, CX');
  EmitInstr('JGE    ' + PY_RT_PFX + 'OBJNEW_ZD');
  EmitInstr('MOV    BYTE PTR [DI+BX], 0');
  EmitInstr('INC    BX');
  EmitInstr('JMP    ' + PY_RT_PFX + 'OBJNEW_Z');
  EmitLabel(PY_RT_PFX + 'OBJNEW_ZD');
  EmitInstr('POP    CX');
  EmitInstr('POP    AX');
  { Mettre a jour le heap top }
  EmitInstr('ADD    WORD PTR [_PY_HEAPTOP], CX');
  EmitInstr('POP    DI');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ ---- ParseClassStmt : parser une definition de classe ---------- }
{ class Nom:              -> classe simple                         }
{ class Nom(Parent):      -> heritage simple                       }
{     def __init__(self, ...):                                     }
{         self.attr = val                                          }
{     def method(self, ...):                                       }
{         ...                                                      }
Procedure ParseClassStmt;
Var
  ClassName   : TString;
  ParentName  : TString;
  ClsIdx      : Integer;
  ParentClsIdx: Integer;
  SymIdx      : Integer;
  LblSkipCls  : TString;
  SaveInClass : Boolean;
  SaveClsIdx  : Integer;
  MethName    : TString;
  MethLabel   : TString;
  FuncIdx     : Integer;
  ParamName   : TString;
  ParamCount  : Integer;
  LblRet      : TString;
  SaveRetLabel: TString;
  SaveLocals  : Integer;
  SaveInFunc  : Boolean;
  I           : Integer;
  AttrName    : TString;
Begin
  EmitComment('-- class --');
  ParserAdvance;  { consommer 'class' }

  { Nom de la classe }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('nom de classe attendu apres ''class''', CurToken.Line);
    Exit;
  End;
  ClassName := CurToken.Val;
  ParserAdvance;

  { Verifier heritage : class Nom(Parent): }
  ParentName := '';
  ParentClsIdx := -1;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance;  { consommer '(' }
    If CurToken.Kind = TK_IDENT Then
    Begin
      ParentName := CurToken.Val;
      ParentClsIdx := ClassFind(ParentName);
      If ParentClsIdx < 0 Then
        WarnMsg('classe parente ''' + ParentName +
                       ''' non trouvee', CurToken.Line);
      ParserAdvance;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
  End;

  { Enregistrer la classe }
  If ClassCount >= MAX_CLASS Then
  Begin
    CompileError('trop de classes (max ' + IntToStr_(MAX_CLASS) + ')',
                 CurToken.Line);
    Exit;
  End;
  ClsIdx := ClassCount;
  ClassTab[ClsIdx].Name       := ClassName;
  ClassTab[ClsIdx].ParentIdx  := ParentClsIdx;
  ClassTab[ClsIdx].AttrCount  := 0;
  ClassTab[ClsIdx].MethCount  := 0;
  ClassTab[ClsIdx].ObjSize    := 2;  { au minimum : typecode DW }
  { Copier les attributs du parent si heritage }
  If ParentClsIdx >= 0 Then
  Begin
    For I := 0 To ClassTab[ParentClsIdx].AttrCount - 1 Do
    Begin
      ClassTab[ClsIdx].AttrNames[I] :=
        ClassTab[ParentClsIdx].AttrNames[I];
    End;
    ClassTab[ClsIdx].AttrCount := ClassTab[ParentClsIdx].AttrCount;
    ClassTab[ClsIdx].ObjSize := ClassTab[ParentClsIdx].ObjSize;
    { Copier les methodes du parent }
    For I := 0 To ClassTab[ParentClsIdx].MethCount - 1 Do
    Begin
      ClassTab[ClsIdx].MethNames[I] :=
        ClassTab[ParentClsIdx].MethNames[I];
      ClassTab[ClsIdx].MethLabels[I] :=
        ClassTab[ParentClsIdx].MethLabels[I];
    End;
    ClassTab[ClsIdx].MethCount := ClassTab[ParentClsIdx].MethCount;
  End;
  Inc(ClassCount);

  { Enregistrer le nom de classe comme symbole SK_CLASS }
  SymIdx := SymFind(ClassName);
  If SymIdx < 0 Then
    SymIdx := SymAdd(ClassName, SK_CLASS, TY_IDX_CLASS, ClsIdx)
  Else
  Begin
    SymTab[SymIdx].Kind    := SK_CLASS;
    SymTab[SymIdx].TypeIdx := TY_IDX_CLASS;
    SymTab[SymIdx].Offset  := ClsIdx;
  End;

  { Attendre ':' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    ParserAdvance
  Else
    CompileError(''':'' attendue apres le nom de classe', CurToken.Line);

  { Saut au-dela du corps de la classe }
  LblSkipCls := LabelGen;
  EmitInstr('JMP    ' + LblSkipCls);
  EmitBlankLine;

  { Sauvegarder le contexte }
  SaveInClass := InClass;
  SaveClsIdx  := CurClassIdx;
  InClass     := True;
  CurClassIdx := ClsIdx;

  { Parser le bloc de la classe (NEWLINE INDENT ... DEDENT) }
  { Sauter le NEWLINE }
  While CurToken.Kind = TK_NEWLINE Do
    ParserAdvance;
  { Attendre INDENT }
  If CurToken.Kind <> TK_INDENT Then
  Begin
    CompileError('bloc indente attendu pour la classe', CurToken.Line);
    InClass     := SaveInClass;
    CurClassIdx := SaveClsIdx;
    Exit;
  End;
  ParserAdvance;  { consommer INDENT }

  { Boucle de parsing du corps de la classe }
  While (CurToken.Kind <> TK_EOF) And
        (CurToken.Kind <> TK_DEDENT) Do
  Begin
    { Sauter les lignes vides }
    If CurToken.Kind = TK_NEWLINE Then
    Begin
      ParserAdvance;
      Continue;
    End;
    { pass }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'pass') Then
    Begin
      EmitComment('pass');
      ParserAdvance;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { def -> methode de la classe }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'def') Then
    Begin
      ParserAdvance;  { consommer 'def' }
      { Nom de la methode }
      If CurToken.Kind <> TK_IDENT Then
      Begin
        CompileError('nom de methode attendu', CurToken.Line);
        { Sauter la ligne }
        While (CurToken.Kind <> TK_EOF) And
              (CurToken.Kind <> TK_NEWLINE) Do
          ParserAdvance;
        Continue;
      End;
      MethName := CurToken.Val;
      ParserAdvance;
      { Label de la methode : _PYM_ClassName_method }
      MethLabel := PY_MTH_PFX + SymNameClean(ClassName) + '_' +
                   SymNameClean(MethName);
      { Enregistrer la methode dans ClassTab }
      If ClassTab[ClsIdx].MethCount < MAX_CLS_METH Then
      Begin
        { Verifier si deja presente (surcharge heritage) }
        I := ClassFindMeth(ClsIdx, MethName);
        If I >= 0 Then
          ClassTab[ClsIdx].MethLabels[I] := MethLabel
        Else
        Begin
          I := ClassTab[ClsIdx].MethCount;
          ClassTab[ClsIdx].MethNames[I]  := MethName;
          ClassTab[ClsIdx].MethLabels[I] := MethLabel;
          Inc(ClassTab[ClsIdx].MethCount);
        End;
      End;
      { Enregistrer comme fonction dans SymTab }
      FuncIdx := SymFind(ClassName + '.' + MethName);
      If FuncIdx < 0 Then
        FuncIdx := SymAdd(ClassName + '.' + MethName,
                          SK_FUNC, TY_IDX_INT, 0);
      SymTab[FuncIdx].MangledName := MethLabel;
      { Emettre le label de la methode }
      EmitComment('method: ' + ClassName + '.' + MethName);
      EmitLabel(MethLabel);
      { Generer le label d epilogue }
      LblRet := LabelGen;
      { Sauvegarder le contexte de fonction }
      SaveRetLabel := FuncRetLabel;
      SaveLocals   := FuncLocalsSize;
      SaveInFunc   := InFunction;
      FuncRetLabel   := LblRet;
      FuncLocalsSize := 0;
      InFunction     := True;
      { Entrer dans la portee de la methode }
      SymEnterScope;
      { Parser les parametres (self, ...) }
      ParamCount := 0;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        ParserAdvance;
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
        Begin
          If CurToken.Kind = TK_IDENT Then
          Begin
            ParamName := CurToken.Val;
            ParserAdvance;
            { Sauter la valeur par defaut si presente }
            If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
            Begin
              ParserAdvance;
              While (CurToken.Kind <> TK_EOF) And
                    Not ((CurToken.Kind = TK_PUNCT) And
                         ((CurToken.Val = ',') Or (CurToken.Val = ')'))) Do
                ParserAdvance;
            End;
            { Ajouter le parametre : [BP+4+ParamCount*2] }
            SymAdd(ParamName, SK_PARAM, TY_UNKNOWN,
                   4 + ParamCount * 2);
            Inc(ParamCount);
          End;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
      End;
      { Attendre ':' }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
        ParserAdvance
      Else
        CompileError(''':'' attendue apres les parametres', CurToken.Line);
      { Prologue de la methode }
      EmitProlog(0);
      { Parser le corps de la methode }
      ParseBlock;
      { Si __init__ : scanner les attributs pour la taille de l objet }
      { (Les attributs sont decouverts pendant le parsing via self.x) }
      { Retour par defaut : AX=0 (None) }
      EmitInstr('XOR    AX, AX');
      { Epilogue }
      EmitLabel(LblRet);
      EmitEpilog;
      EmitBlankLine;
      { Quitter la portee }
      SymLeaveScope;
      { Restaurer le contexte de fonction }
      FuncRetLabel   := SaveRetLabel;
      FuncLocalsSize := SaveLocals;
      InFunction     := SaveInFunc;
      { Sauter NEWLINE apres le def }
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { Autre instruction dans la classe : ignorer }
    While (CurToken.Kind <> TK_EOF) And
          (CurToken.Kind <> TK_NEWLINE) And
          (CurToken.Kind <> TK_DEDENT) Do
      ParserAdvance;
    If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
  End;

  { Consommer DEDENT }
  If CurToken.Kind = TK_DEDENT Then
    ParserAdvance;

  { Restaurer le contexte }
  InClass     := SaveInClass;
  CurClassIdx := SaveClsIdx;

  { Label pour reprendre l execution apres la classe }
  EmitLabel(LblSkipCls);
  EmitComment('end class ' + ClassName);
End;

{ ============================================================
  TODO 19 - TUPLES ET UNPACKING [IMPLEMENTE]
  ============================================================ }

{ ---- ParseTupleLiteral : tuple literal explicite --------------- }
{ Appele quand on sait qu il faut parser un tuple (e.g., depuis   }
{ un contexte ou l on attend un tuple). Le format heap est le     }
{ meme que pour les listes : [count DW][elem0 DW][elem1 DW]...   }
{ mais le type est TY_IDX_TUPLE (immutable).                      }
Procedure ParseTupleLiteral(Var Res : TExprVal);
Var
  ElemE     : TExprVal;
  ElemCount : Integer;
Begin
  EmitComment('tuple literal');
  { Consommer le '(' }
  ParserAdvance;
  ElemCount := 0;

  { Tuple vide : () -> heap [count=0] }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
  Begin
    ParserAdvance;
    EmitInstr('MOV    DI, [_PY_HEAPTOP]');
    EmitInstr('ADD    DI, OFFSET _PY_HEAP');
    EmitInstr('MOV    WORD PTR [DI], 0');  { count = 0 }
    EmitInstr('ADD    WORD PTR [_PY_HEAPTOP], 2');
    EmitInstr('MOV    AX, DI');
    ExprMakeAX(TY_IDX_TUPLE, Res);
    Exit;
  End;

  { Allouer le bloc dans le heap : bump allocator }
  EmitInstr('MOV    DI, [_PY_HEAPTOP]');
  EmitInstr('ADD    DI, OFFSET _PY_HEAP');

  { Parser chaque element et stocker dans [DI + 2 + 2*i] }
  ParseExpr(ElemE);
  ExprFlushToAX(ElemE);
  EmitInstr('MOV    [DI+2], AX');        { elem 0 a offset 2 }
  Inc(ElemCount);
  While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
  Begin
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      Break;  { virgule terminale }
    ParseExpr(ElemE);
    ExprFlushToAX(ElemE);
    EmitInstr('MOV    [DI+' + IntToStr_(2 + ElemCount * 2) + '], AX');
    Inc(ElemCount);
  End;

  { Ecrire le count en tete }
  EmitInstr('MOV    WORD PTR [DI], ' + IntToStr_(ElemCount));
  { Mettre a jour le HEAPTOP : (count + 1) * 2 }
  EmitInstr('ADD    WORD PTR [_PY_HEAPTOP], ' +
            IntToStr_((ElemCount + 1) * 2));
  { Retourner le pointeur vers le bloc }
  EmitInstr('MOV    AX, DI');

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance
  Else
    CompileError(''')'' attendue', CurToken.Line);
  ExprMakeAX(TY_IDX_TUPLE, Res);
End;

{ ---- EmitTupleRuntime : routines runtime pour tuples ----------- }
{ Layout tuple : [count DW][elem0 DW][elem1 DW]... (comme list)  }
{ Tuples immutables : pas de append/pop/insert                    }
{   _PYRT_TUPLECONCAT : SI=tup1, DI=tup2 -> AX=new tuple         }
{   _PYRT_TUPLEMUL    : SI=tuple, CX=repeat -> AX=new tuple       }
Procedure EmitTupleRuntime;
Begin
  EmitBlankLine;
  EmitComment('-- Runtime : tuples (TODO 19) --');

  { _PYRT_TUPLECONCAT : SI=tup1, DI=tup2 -> AX=new tuple }
  EmitLabel(PY_RT_PFX + 'TUPLECONCAT');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   DX');
  EmitInstr('MOV    AX, [SI]');          { AX = count1 }
  EmitInstr('MOV    BX, [DI]');          { BX = count2 }
  EmitInstr('MOV    CX, AX');
  EmitInstr('ADD    CX, BX');            { CX = total count }
  { Sauver contexte }
  EmitInstr('PUSH   CX');               { total }
  EmitInstr('PUSH   SI');               { tup1 }
  EmitInstr('PUSH   DI');               { tup2 }
  EmitInstr('PUSH   AX');               { count1 }
  EmitInstr('PUSH   BX');               { count2 }
  { Allouer sur le heap }
  EmitInstr('MOV    DI, [_PY_HEAPTOP]');
  EmitInstr('ADD    DI, OFFSET _PY_HEAP');
  { Depiler et organiser }
  EmitInstr('POP    CX');               { CX = count2 }
  EmitInstr('POP    AX');               { AX = count1 }
  EmitInstr('POP    BX');               { BX = ptr tup2 }
  EmitInstr('POP    SI');               { SI = ptr tup1 }
  EmitInstr('POP    DX');               { DX = total count }
  { Ecrire total count }
  EmitInstr('MOV    [DI], DX');
  EmitInstr('PUSH   DI');               { sauver ptr new tuple }
  EmitInstr('PUSH   BX');               { sauver ptr tup2 }
  EmitInstr('PUSH   CX');               { sauver count2 }
  EmitInstr('ADD    DI, 2');
  { Copier count1 elements depuis tup1 }
  EmitInstr('ADD    SI, 2');
  EmitInstr('MOV    CX, AX');
  EmitInstr('TEST   CX, CX');
  EmitInstr('JLE    ' + PY_RT_PFX + 'TC_P2');
  EmitLabel(PY_RT_PFX + 'TC_L1');
  EmitInstr('MOVSW');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'TC_L1');
  EmitLabel(PY_RT_PFX + 'TC_P2');
  { Copier count2 elements depuis tup2 }
  EmitInstr('POP    CX');               { CX = count2 }
  EmitInstr('POP    SI');               { SI = ptr tup2 }
  EmitInstr('ADD    SI, 2');
  EmitInstr('TEST   CX, CX');
  EmitInstr('JLE    ' + PY_RT_PFX + 'TC_DN');
  EmitLabel(PY_RT_PFX + 'TC_L2');
  EmitInstr('MOVSW');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'TC_L2');
  EmitLabel(PY_RT_PFX + 'TC_DN');
  { Mettre a jour HEAPTOP }
  EmitInstr('POP    AX');               { AX = ptr new tuple }
  EmitInstr('MOV    CX, [AX]');         { CX = total count }
  EmitInstr('INC    CX');               { +1 pour header }
  EmitInstr('SHL    CX, 1');
  EmitInstr('ADD    [_PY_HEAPTOP], CX');
  EmitInstr('POP    DX');
  EmitInstr('POP    BX');
  EmitInstr('RET');

  { _PYRT_TUPLEMUL : SI=tuple, CX=repeat -> AX=new tuple }
  EmitLabel(PY_RT_PFX + 'TUPLEMUL');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   DX');
  EmitInstr('MOV    AX, [SI]');          { AX = elem count }
  EmitInstr('MOV    BX, AX');
  EmitInstr('IMUL   CX');               { AX = total elements }
  EmitInstr('MOV    DX, AX');            { DX = total }
  { Allouer sur le heap }
  EmitInstr('MOV    DI, [_PY_HEAPTOP]');
  EmitInstr('ADD    DI, OFFSET _PY_HEAP');
  EmitInstr('MOV    [DI], DX');          { ecrire total count }
  EmitInstr('PUSH   DI');               { sauver ptr new tuple }
  EmitInstr('ADD    DI, 2');
  EmitInstr('TEST   CX, CX');
  EmitInstr('JLE    ' + PY_RT_PFX + 'TM_DN');
  EmitLabel(PY_RT_PFX + 'TM_LP');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   SI');
  EmitInstr('ADD    SI, 2');
  EmitInstr('MOV    CX, BX');            { CX = elem count per iter }
  EmitInstr('TEST   CX, CX');
  EmitInstr('JLE    ' + PY_RT_PFX + 'TM_NX');
  EmitLabel(PY_RT_PFX + 'TM_CP');
  EmitInstr('MOVSW');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'TM_CP');
  EmitLabel(PY_RT_PFX + 'TM_NX');
  EmitInstr('POP    SI');
  EmitInstr('POP    CX');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'TM_LP');
  EmitLabel(PY_RT_PFX + 'TM_DN');
  { Mettre a jour HEAPTOP }
  EmitInstr('POP    AX');               { AX = ptr new tuple }
  EmitInstr('MOV    CX, [AX]');
  EmitInstr('INC    CX');
  EmitInstr('SHL    CX, 1');
  EmitInstr('ADD    [_PY_HEAPTOP], CX');
  EmitInstr('POP    DX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
End;

{ ============================================================
  TODO 20 - CHAINES (str) OPERATIONS AVANCEES [IMPLEMENTE]
  ============================================================ }

{ ---- EmitStrRuntime : routines runtime pour chaines avancees --- }
{   _PYRT_STRSLICE    : SI=str, AX=start, BX=end -> AX=ptr       }
{   _PYRT_STRFIND     : SI=str, DI=sub -> AX=index ou -1          }
{   _PYRT_STRUPPER    : SI=str -> AX=ptr nouvelle chaine           }
{   _PYRT_STRLOWER    : SI=str -> AX=ptr nouvelle chaine           }
{   _PYRT_STRSTRIP    : SI=str -> AX=ptr nouvelle chaine           }
{   _PYRT_STRSPLIT    : SI=str, DI=sep -> AX=ptr liste             }
{   _PYRT_STRREPLACE  : SI=str, DI=old, DX=new -> AX=ptr          }
{   _PYRT_STARTSWITH  : SI=str, DI=prefix -> AX=0|1                }
{   _PYRT_ENDSWITH    : SI=str, DI=suffix -> AX=0|1                }
{   _PYRT_STRCONTAINS : SI=str, DI=sub -> AX=0|1                   }
{   _PYRT_STRCOUNT    : SI=str, DI=sub -> AX=nombre occurrences    }

Procedure EmitStrRuntime;
Begin
  EmitBlankLine;
  EmitComment('-- Runtime : chaines avancees (TODO 20) --');

  { _PYRT_STRSLICE : SI=str, AX=start, BX=end -> AX=ptr _PY_STRBUF2 }
  { Si BX = FFFFh, copier jusqu a la fin de la chaine                  }
  EmitLabel(PY_RT_PFX + 'STRSLICE');
  EmitInstr('PUSH   DX');
  EmitInstr('MOV    DX, AX');              { DX = start }
  EmitInstr('CMP    BX, 0FFFFh');
  EmitInstr('JNE    ' + PY_RT_PFX + 'SSL_OK');
  { BX = FFFFh : calculer la longueur pour b=len }
  EmitInstr('PUSH   SI');
  EmitInstr('CALL   ' + PY_RT_PFX + 'LEN');
  EmitInstr('MOV    BX, AX');
  EmitInstr('POP    SI');
  EmitLabel(PY_RT_PFX + 'SSL_OK');
  { DX=start, BX=end, SI=str }
  EmitInstr('ADD    SI, DX');              { SI pointe sur str[start] }
  EmitInstr('MOV    CX, BX');
  EmitInstr('SUB    CX, DX');              { CX = end - start }
  EmitInstr('MOV    DI, OFFSET _PY_STRBUF2');
  EmitInstr('TEST   CX, CX');
  EmitInstr('JLE    ' + PY_RT_PFX + 'SSL_DN');
  EmitLabel(PY_RT_PFX + 'SSL_CP');
  EmitInstr('MOVSB');
  EmitInstr('LOOP   ' + PY_RT_PFX + 'SSL_CP');
  EmitLabel(PY_RT_PFX + 'SSL_DN');
  EmitInstr('MOV    BYTE PTR [DI], 0');
  EmitInstr('MOV    AX, OFFSET _PY_STRBUF2');
  EmitInstr('POP    DX');
  EmitInstr('RET');

  { _PYRT_STRFIND : SI=str, DI=sub -> AX=index ou -1 }
  EmitLabel(PY_RT_PFX + 'STRFIND');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   DX');
  EmitInstr('XOR    BX, BX');              { BX = position courante }
  EmitLabel(PY_RT_PFX + 'SF_LP');
  EmitInstr('CMP    BYTE PTR [SI], 0');
  EmitInstr('JE     ' + PY_RT_PFX + 'SF_NO');
  { Comparer sub a partir de SI }
  EmitInstr('PUSH   SI');
  EmitInstr('PUSH   DI');
  EmitLabel(PY_RT_PFX + 'SF_CMP');
  EmitInstr('MOV    AL, [DI]');
  EmitInstr('TEST   AL, AL');
  EmitInstr('JZ     ' + PY_RT_PFX + 'SF_YES');  { fin de sub -> trouve }
  EmitInstr('CMP    AL, [SI]');
  EmitInstr('JNE    ' + PY_RT_PFX + 'SF_NX');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstr('JMP    ' + PY_RT_PFX + 'SF_CMP');
  EmitLabel(PY_RT_PFX + 'SF_YES');
  EmitInstr('POP    DI');
  EmitInstr('POP    SI');
  EmitInstr('MOV    AX, BX');              { AX = index trouve }
  EmitInstr('POP    DX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitLabel(PY_RT_PFX + 'SF_NX');
  EmitInstr('POP    DI');
  EmitInstr('POP    SI');
  EmitInstr('INC    SI');
  EmitInstr('INC    BX');
  EmitInstr('JMP    ' + PY_RT_PFX + 'SF_LP');
  EmitLabel(PY_RT_PFX + 'SF_NO');
  EmitInstr('MOV    AX, -1');
  EmitInstr('POP    DX');
  EmitInstr('POP    BX');
  EmitInstr('RET');

  { _PYRT_STRUPPER : SI=str -> AX=ptr _PY_STRBUF2 (copie majuscules) }
  EmitLabel(PY_RT_PFX + 'STRUPPER');
  EmitInstr('MOV    DI, OFFSET _PY_STRBUF2');
  EmitLabel(PY_RT_PFX + 'SU_LP');
  EmitInstr('LODSB');
  EmitInstr('TEST   AL, AL');
  EmitInstr('JZ     ' + PY_RT_PFX + 'SU_DN');
  EmitInstr('CMP    AL, 97');              { 'a' }
  EmitInstr('JB     ' + PY_RT_PFX + 'SU_ST');
  EmitInstr('CMP    AL, 122');             { 'z' }
  EmitInstr('JA     ' + PY_RT_PFX + 'SU_ST');
  EmitInstr('SUB    AL, 32');              { minuscule -> majuscule }
  EmitLabel(PY_RT_PFX + 'SU_ST');
  EmitInstr('STOSB');
  EmitInstr('JMP    ' + PY_RT_PFX + 'SU_LP');
  EmitLabel(PY_RT_PFX + 'SU_DN');
  EmitInstr('STOSB');                      { stocker le null terminal }
  EmitInstr('MOV    AX, OFFSET _PY_STRBUF2');
  EmitInstr('RET');

  { _PYRT_STRLOWER : SI=str -> AX=ptr _PY_STRBUF2 (copie minuscules) }
  EmitLabel(PY_RT_PFX + 'STRLOWER');
  EmitInstr('MOV    DI, OFFSET _PY_STRBUF2');
  EmitLabel(PY_RT_PFX + 'SL_LP');
  EmitInstr('LODSB');
  EmitInstr('TEST   AL, AL');
  EmitInstr('JZ     ' + PY_RT_PFX + 'SL_DN');
  EmitInstr('CMP    AL, 65');              { 'A' }
  EmitInstr('JB     ' + PY_RT_PFX + 'SL_ST');
  EmitInstr('CMP    AL, 90');              { 'Z' }
  EmitInstr('JA     ' + PY_RT_PFX + 'SL_ST');
  EmitInstr('ADD    AL, 32');              { majuscule -> minuscule }
  EmitLabel(PY_RT_PFX + 'SL_ST');
  EmitInstr('STOSB');
  EmitInstr('JMP    ' + PY_RT_PFX + 'SL_LP');
  EmitLabel(PY_RT_PFX + 'SL_DN');
  EmitInstr('STOSB');                      { stocker le null terminal }
  EmitInstr('MOV    AX, OFFSET _PY_STRBUF2');
  EmitInstr('RET');

  { _PYRT_STRSTRIP : SI=str -> AX=ptr _PY_STRBUF2 (sans espaces debut/fin) }
  EmitLabel(PY_RT_PFX + 'STRSTRIP');
  EmitInstr('PUSH   BX');
  { Sauter les espaces en debut }
  EmitLabel(PY_RT_PFX + 'SS_L1');
  EmitInstr('MOV    AL, [SI]');
  EmitInstr('CMP    AL, 32');              { espace }
  EmitInstr('JE     ' + PY_RT_PFX + 'SS_SK');
  EmitInstr('CMP    AL, 9');               { tab }
  EmitInstr('JE     ' + PY_RT_PFX + 'SS_SK');
  EmitInstr('JMP    ' + PY_RT_PFX + 'SS_CP');
  EmitLabel(PY_RT_PFX + 'SS_SK');
  EmitInstr('INC    SI');
  EmitInstr('JMP    ' + PY_RT_PFX + 'SS_L1');
  EmitLabel(PY_RT_PFX + 'SS_CP');
  { Copier dans STRBUF2 }
  EmitInstr('MOV    DI, OFFSET _PY_STRBUF2');
  EmitInstr('XOR    CX, CX');             { CX = longueur copiee }
  EmitLabel(PY_RT_PFX + 'SS_L2');
  EmitInstr('LODSB');
  EmitInstr('STOSB');
  EmitInstr('INC    CX');
  EmitInstr('TEST   AL, AL');
  EmitInstr('JNZ    ' + PY_RT_PFX + 'SS_L2');
  EmitInstr('DEC    CX');                  { ne pas compter le null }
  { Retirer les espaces en fin }
  EmitInstr('MOV    DI, OFFSET _PY_STRBUF2');
  EmitInstr('ADD    DI, CX');
  EmitInstr('DEC    DI');                  { pointer sur dernier char }
  EmitLabel(PY_RT_PFX + 'SS_L3');
  EmitInstr('TEST   CX, CX');
  EmitInstr('JZ     ' + PY_RT_PFX + 'SS_FN');
  EmitInstr('MOV    AL, [DI]');
  EmitInstr('CMP    AL, 32');
  EmitInstr('JE     ' + PY_RT_PFX + 'SS_TR');
  EmitInstr('CMP    AL, 9');
  EmitInstr('JE     ' + PY_RT_PFX + 'SS_TR');
  EmitInstr('JMP    ' + PY_RT_PFX + 'SS_FN');
  EmitLabel(PY_RT_PFX + 'SS_TR');
  EmitInstr('DEC    DI');
  EmitInstr('DEC    CX');
  EmitInstr('JMP    ' + PY_RT_PFX + 'SS_L3');
  EmitLabel(PY_RT_PFX + 'SS_FN');
  EmitInstr('INC    DI');
  EmitInstr('MOV    BYTE PTR [DI], 0');
  EmitInstr('MOV    AX, OFFSET _PY_STRBUF2');
  EmitInstr('POP    BX');
  EmitInstr('RET');

  { _PYRT_STRREPLACE : SI=str, DI=old, DX=new -> AX=ptr _PY_STRBUF2 }
  EmitLabel(PY_RT_PFX + 'STRREPLACE');
  EmitInstr('PUSH   BX');
  EmitInstr('MOV    BX, OFFSET _PY_STRBUF2'); { BX = dest }
  EmitLabel(PY_RT_PFX + 'SR_LP');
  EmitInstr('CMP    BYTE PTR [SI], 0');
  EmitInstr('JE     ' + PY_RT_PFX + 'SR_DN');
  { Tester si old commence ici }
  EmitInstr('PUSH   SI');
  EmitInstr('PUSH   DI');
  EmitLabel(PY_RT_PFX + 'SR_CM');
  EmitInstr('MOV    AL, [DI]');
  EmitInstr('TEST   AL, AL');
  EmitInstr('JZ     ' + PY_RT_PFX + 'SR_MT');   { fin de old -> match }
  EmitInstr('CMP    AL, [SI]');
  EmitInstr('JNE    ' + PY_RT_PFX + 'SR_NM');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstr('JMP    ' + PY_RT_PFX + 'SR_CM');
  EmitLabel(PY_RT_PFX + 'SR_MT');
  { Match : copier new dans dest, avancer SI }
  EmitInstr('POP    DI');                  { restaurer DI = old }
  EmitInstr('ADD    SP, 2');               { abandonner ancien SI }
  { Copier new (DX) dans BX }
  EmitInstr('PUSH   SI');                  { sauver SI (apres old) }
  EmitInstr('MOV    SI, DX');              { SI = new }
  EmitLabel(PY_RT_PFX + 'SR_CN');
  EmitInstr('LODSB');
  EmitInstr('TEST   AL, AL');
  EmitInstr('JZ     ' + PY_RT_PFX + 'SR_CD');
  EmitInstr('MOV    [BX], AL');
  EmitInstr('INC    BX');
  EmitInstr('JMP    ' + PY_RT_PFX + 'SR_CN');
  EmitLabel(PY_RT_PFX + 'SR_CD');
  EmitInstr('POP    SI');                  { SI = position apres match }
  EmitInstr('JMP    ' + PY_RT_PFX + 'SR_LP');
  EmitLabel(PY_RT_PFX + 'SR_NM');
  { Pas de match : copier le caractere courant }
  EmitInstr('POP    DI');                  { restaurer DI }
  EmitInstr('POP    SI');                  { restaurer SI }
  EmitInstr('MOV    AL, [SI]');
  EmitInstr('MOV    [BX], AL');
  EmitInstr('INC    BX');
  EmitInstr('INC    SI');
  EmitInstr('JMP    ' + PY_RT_PFX + 'SR_LP');
  EmitLabel(PY_RT_PFX + 'SR_DN');
  EmitInstr('MOV    BYTE PTR [BX], 0');
  EmitInstr('MOV    AX, OFFSET _PY_STRBUF2');
  EmitInstr('POP    BX');
  EmitInstr('RET');

  { _PYRT_STARTSWITH : SI=str, DI=prefix -> AX=0|1 }
  EmitLabel(PY_RT_PFX + 'STARTSWITH');
  EmitLabel(PY_RT_PFX + 'SW_LP');
  EmitInstr('MOV    AL, [DI]');
  EmitInstr('TEST   AL, AL');
  EmitInstr('JZ     ' + PY_RT_PFX + 'SW_YES');   { fin prefix -> ok }
  EmitInstr('CMP    AL, [SI]');
  EmitInstr('JNE    ' + PY_RT_PFX + 'SW_NO');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstr('JMP    ' + PY_RT_PFX + 'SW_LP');
  EmitLabel(PY_RT_PFX + 'SW_YES');
  EmitInstr('MOV    AX, 1');
  EmitInstr('RET');
  EmitLabel(PY_RT_PFX + 'SW_NO');
  EmitInstr('XOR    AX, AX');
  EmitInstr('RET');

  { _PYRT_ENDSWITH : SI=str, DI=suffix -> AX=0|1 }
  EmitLabel(PY_RT_PFX + 'ENDSWITH');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   DX');
  { Calculer len(str) }
  EmitInstr('PUSH   SI');
  EmitInstr('CALL   ' + PY_RT_PFX + 'LEN');
  EmitInstr('MOV    BX, AX');              { BX = len(str) }
  EmitInstr('POP    SI');
  { Calculer len(suffix) }
  EmitInstr('PUSH   SI');
  EmitInstr('MOV    SI, DI');
  EmitInstr('CALL   ' + PY_RT_PFX + 'LEN');
  EmitInstr('MOV    DX, AX');              { DX = len(suffix) }
  EmitInstr('POP    SI');
  { Si len(suffix) > len(str) -> false }
  EmitInstr('CMP    DX, BX');
  EmitInstr('JA     ' + PY_RT_PFX + 'EW_NO');
  { SI += len(str) - len(suffix) }
  EmitInstr('MOV    AX, BX');
  EmitInstr('SUB    AX, DX');
  EmitInstr('ADD    SI, AX');
  { Comparer SI avec DI }
  EmitLabel(PY_RT_PFX + 'EW_LP');
  EmitInstr('MOV    AL, [DI]');
  EmitInstr('TEST   AL, AL');
  EmitInstr('JZ     ' + PY_RT_PFX + 'EW_YES');
  EmitInstr('CMP    AL, [SI]');
  EmitInstr('JNE    ' + PY_RT_PFX + 'EW_NO');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstr('JMP    ' + PY_RT_PFX + 'EW_LP');
  EmitLabel(PY_RT_PFX + 'EW_YES');
  EmitInstr('MOV    AX, 1');
  EmitInstr('POP    DX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitLabel(PY_RT_PFX + 'EW_NO');
  EmitInstr('XOR    AX, AX');
  EmitInstr('POP    DX');
  EmitInstr('POP    BX');
  EmitInstr('RET');

  { _PYRT_STRCONTAINS : SI=str, DI=sub -> AX=0|1 }
  { Utilise STRFIND et convertit -1 en 0, sinon 1 }
  EmitLabel(PY_RT_PFX + 'STRCONTAINS');
  EmitInstr('CALL   ' + PY_RT_PFX + 'STRFIND');
  EmitInstr('CMP    AX, -1');
  EmitInstr('JE     ' + PY_RT_PFX + 'SC2_NO');
  EmitInstr('MOV    AX, 1');
  EmitInstr('RET');
  EmitLabel(PY_RT_PFX + 'SC2_NO');
  EmitInstr('XOR    AX, AX');
  EmitInstr('RET');

  { _PYRT_STRCOUNT : SI=str, DI=sub -> AX=nombre d occurrences }
  EmitLabel(PY_RT_PFX + 'STRCOUNT');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   DX');
  EmitInstr('XOR    DX, DX');              { DX = compteur }
  EmitLabel(PY_RT_PFX + 'SCT_LP');
  EmitInstr('CMP    BYTE PTR [SI], 0');
  EmitInstr('JE     ' + PY_RT_PFX + 'SCT_DN');
  { Tester si sub commence a SI }
  EmitInstr('PUSH   SI');
  EmitInstr('PUSH   DI');
  EmitLabel(PY_RT_PFX + 'SCT_CM');
  EmitInstr('MOV    AL, [DI]');
  EmitInstr('TEST   AL, AL');
  EmitInstr('JZ     ' + PY_RT_PFX + 'SCT_MT');
  EmitInstr('CMP    AL, [SI]');
  EmitInstr('JNE    ' + PY_RT_PFX + 'SCT_NM');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstr('JMP    ' + PY_RT_PFX + 'SCT_CM');
  EmitLabel(PY_RT_PFX + 'SCT_MT');
  { Match trouve : incrementer compteur, avancer SI apres le match }
  EmitInstr('INC    DX');
  EmitInstr('POP    DI');
  EmitInstr('ADD    SP, 2');               { abandonner ancien SI }
  EmitInstr('JMP    ' + PY_RT_PFX + 'SCT_LP');
  EmitLabel(PY_RT_PFX + 'SCT_NM');
  EmitInstr('POP    DI');
  EmitInstr('POP    SI');
  EmitInstr('INC    SI');
  EmitInstr('JMP    ' + PY_RT_PFX + 'SCT_LP');
  EmitLabel(PY_RT_PFX + 'SCT_DN');
  EmitInstr('MOV    AX, DX');
  EmitInstr('POP    DX');
  EmitInstr('POP    BX');
  EmitInstr('RET');

  { _PYRT_STRSPLIT : SI=str, DI=sep (1 char) -> AX=ptr liste heap }
  { Layout liste : [count DW][elem0 DW][elem1 DW]...              }
  { Chaque elem est un ptr vers une sous-chaine copiee sur heap    }
  EmitLabel(PY_RT_PFX + 'STRSPLIT');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   DX');
  EmitInstr('MOV    DX, DI');              { DX = ptr separateur }
  EmitInstr('MOV    AL, [DX]');            { AL = premier char sep }
  EmitInstr('MOV    AH, AL');              { AH = sep char }
  { Allouer la liste sur le heap }
  EmitInstr('MOV    BX, [_PY_HEAPTOP]');
  EmitInstr('ADD    BX, OFFSET _PY_HEAP'); { BX = debut liste }
  EmitInstr('PUSH   BX');                  { sauver ptr liste }
  EmitInstr('ADD    BX, 2');               { sauter le count header }
  EmitInstr('XOR    CX, CX');              { CX = nombre d elements }
  { Pour chaque token : copier dans heap, stocker ptr dans liste }
  EmitLabel(PY_RT_PFX + 'SPL_LP');
  { Debut d un token : position courante dans heap apres la liste }
  EmitInstr('MOV    DI, [_PY_HEAPTOP]');
  EmitInstr('ADD    DI, OFFSET _PY_HEAP');
  EmitInstr('ADD    DI, 256');             { zone temporaire plus loin }
  EmitInstr('PUSH   DI');                  { sauver debut du token }
  EmitLabel(PY_RT_PFX + 'SPL_CH');
  EmitInstr('MOV    AL, [SI]');
  EmitInstr('TEST   AL, AL');
  EmitInstr('JZ     ' + PY_RT_PFX + 'SPL_ET');   { fin chaine }
  EmitInstr('CMP    AL, AH');
  EmitInstr('JE     ' + PY_RT_PFX + 'SPL_ET');   { separateur }
  EmitInstr('STOSB');                      { copier le char }
  EmitInstr('INC    SI');
  EmitInstr('JMP    ' + PY_RT_PFX + 'SPL_CH');
  EmitLabel(PY_RT_PFX + 'SPL_ET');
  EmitInstr('MOV    BYTE PTR [DI], 0');   { null-terminer le token }
  EmitInstr('POP    DI');                  { DI = debut du token }
  { Stocker le ptr dans la liste }
  EmitInstr('MOV    [BX], DI');
  EmitInstr('ADD    BX, 2');
  EmitInstr('INC    CX');
  { Si fin de chaine, arreter }
  EmitInstr('CMP    BYTE PTR [SI], 0');
  EmitInstr('JE     ' + PY_RT_PFX + 'SPL_DN');
  EmitInstr('INC    SI');                  { sauter le separateur }
  EmitInstr('JMP    ' + PY_RT_PFX + 'SPL_LP');
  EmitLabel(PY_RT_PFX + 'SPL_DN');
  { Ecrire le count dans l en-tete de la liste }
  EmitInstr('POP    DI');                  { DI = debut liste }
  EmitInstr('MOV    [DI], CX');
  { Mettre a jour HEAPTOP }
  EmitInstr('MOV    AX, CX');
  EmitInstr('INC    AX');                  { +1 pour header }
  EmitInstr('SHL    AX, 1');               { *2 pour mots }
  EmitInstr('ADD    AX, 512');             { espace pour les sous-chaines }
  EmitInstr('ADD    [_PY_HEAPTOP], AX');
  EmitInstr('MOV    AX, DI');              { AX = ptr liste }
  EmitInstr('POP    DX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
End;

{ ============================================================
  TODO 21 - GESTION DES EXCEPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- TryPush : empiler les labels d un nouveau try/except ------ }
Procedure TryPush(ExceptLbl, FinallyLbl, EndLbl : TString);
Begin
  If TryTop >= MAX_TRY_NEST Then
  Begin
    CompileError('trop de try imbriques', CurToken.Line);
    Exit;
  End;
  TryExceptStack[TryTop]  := ExceptLbl;
  TryFinallyStack[TryTop] := FinallyLbl;
  TryEndStack[TryTop]     := EndLbl;
  Inc(TryTop);
End;

{ ---- TryPop : depiler les labels du try courant ----------------- }
Procedure TryPop;
Begin
  If TryTop > 0 Then
    Dec(TryTop);
End;

{ ---- ParseTryStmt : try: bloc except [Type [as var]]: bloc ------- }
{ Mecanisme : _PY_EXCFLAG = 0 (pas d exception), 1 (exception)     }
{ try:   -> executer le bloc, si pas d exception sauter a else/end  }
{ except: -> tester _PY_EXCFLAG, executer handler, clear flag       }
{ finally: -> toujours execute (label finally)                       }
{ raise:  -> positionner _PY_EXCFLAG et sauter a except              }
Procedure ParseTryStmt;
Var
  LblExcept  : TString;
  LblFinally : TString;
  LblEnd     : TString;
  LblElse    : TString;
  HasFinally : Boolean;
  HasElse    : Boolean;
  ExcVarName : TString;
  ExcVarIdx  : Integer;
Begin
  EmitComment('-- try --');
  ParserAdvance;  { consommer 'try' }

  LblExcept  := LabelGen;
  LblFinally := LabelGen;
  LblEnd     := LabelGen;
  LblElse    := LabelGen;
  HasFinally := False;
  HasElse    := False;

  { Initialiser le flag d exception a 0 }
  EmitInstr('MOV    WORD PTR [_PY_EXCFLAG], 0');

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    ParserAdvance;

  { Empiler le contexte try }
  TryPush(LblExcept, LblFinally, LblEnd);

  { Parser le bloc try }
  ParseBlock;

  { Si pas d exception, sauter a else ou finally ou end }
  EmitInstr('CMP    WORD PTR [_PY_EXCFLAG], 0');
  EmitInstr('JNE    ' + LblExcept);
  EmitInstr('JMP    ' + LblElse);

  { Label except }
  EmitLabel(LblExcept);

  { Parser les clauses except }
  While (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'except') Do
  Begin
    EmitComment('-- except --');
    ParserAdvance;  { consommer 'except' }

    { except avec type ou except generique }
    If (CurToken.Kind = TK_IDENT) Then
    Begin
      { except ExceptionType [as var]: }
      ParserAdvance;  { consommer le type (ignore pour simplification) }
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'as') Then
      Begin
        ParserAdvance;  { consommer 'as' }
        If CurToken.Kind = TK_IDENT Then
        Begin
          ExcVarName := CurToken.Val;
          ParserAdvance;  { consommer le nom de variable }
          { Stocker la valeur d exception dans la variable }
          ExcVarIdx := SymFind(ExcVarName);
          If ExcVarIdx < 0 Then
            ExcVarIdx := SymAdd(ExcVarName, SK_GLOBAL, TY_IDX_INT, 0);
          EmitInstr('MOV    AX, [_PY_EXCVAL]');
          EmitInstr('MOV    [' + SymTab[ExcVarIdx].MangledName + '], AX');
        End;
      End;
    End;

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      ParserAdvance;

    { Parser le bloc except }
    ParseBlock;

    { Apres le handler, effacer le flag et sauter a finally/end }
    EmitInstr('MOV    WORD PTR [_PY_EXCFLAG], 0');
    EmitInstr('JMP    ' + LblFinally);
  End;

  { Si aucun handler n a traite, sauter a finally quand meme }
  EmitInstr('JMP    ' + LblFinally);

  { Label else (execute si aucune exception) }
  EmitLabel(LblElse);
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'else') Then
  Begin
    HasElse := True;
    EmitComment('-- try/else --');
    ParserAdvance;  { consommer 'else' }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      ParserAdvance;
    ParseBlock;
  End;

  { Label finally }
  EmitLabel(LblFinally);
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'finally') Then
  Begin
    HasFinally := True;
    EmitComment('-- finally --');
    ParserAdvance;  { consommer 'finally' }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      ParserAdvance;
    ParseBlock;
  End;

  { Label fin du try/except/finally }
  EmitLabel(LblEnd);

  { Depiler le contexte try }
  TryPop;
End;

{ ---- ParseRaiseStmt : raise [expression] ------------------------- }
Procedure ParseRaiseStmt;
Var
  E : TExprVal;
Begin
  EmitComment('-- raise --');
  ParserAdvance;  { consommer 'raise' }

  { Positionner le flag d exception }
  EmitInstr('MOV    WORD PTR [_PY_EXCFLAG], 1');

  { Si une expression suit, l evaluer comme valeur d exception }
  If (CurToken.Kind <> TK_NEWLINE) And (CurToken.Kind <> TK_EOF) And
     (CurToken.Kind <> TK_DEDENT) Then
  Begin
    ParseExpr(E);
    ExprFlushToAX(E);
    EmitInstr('MOV    [_PY_EXCVAL], AX');
  End;

  { Sauter au handler except le plus proche }
  If TryTop > 0 Then
    EmitInstr('JMP    ' + TryExceptStack[TryTop - 1])
  Else
  Begin
    { raise sans handler : afficher erreur et quitter }
    EmitComment('raise sans handler : halt');
    EmitInstr('MOV    AX, 4C01h');
    EmitInstr('INT    21h');
  End;
End;

{ ---- ParseBlock : parser un bloc indente ---------------------- }
{ Attend NEWLINE INDENT ... instructions ... DEDENT              }
Procedure ParseBlock;
Var
  VarName    : TString;
  Idx        : Integer;
  AttrName   : TString;
  AttrIdx    : Integer;
  MethClsIdx : Integer;
  MethIdx    : Integer;
  ArgCnt     : Integer;
  ClsI       : Integer;
Begin
  { Sauter le NEWLINE apres ':' }
  While CurToken.Kind = TK_NEWLINE Do
    ParserAdvance;
  { Attendre INDENT }
  If CurToken.Kind <> TK_INDENT Then
  Begin
    CompileError('bloc indente attendu', CurToken.Line);
    Exit;
  End;
  ParserAdvance; { consommer INDENT }

  { Parser les instructions jusqu au DEDENT }
  While (CurToken.Kind <> TK_DEDENT) And (CurToken.Kind <> TK_EOF) Do
  Begin
    { Sauter les NEWLINE }
    If CurToken.Kind = TK_NEWLINE Then
    Begin
      ParserAdvance;
      Continue;
    End;
    { INDENT inattendu }
    If CurToken.Kind = TK_INDENT Then
    Begin
      ParserAdvance;
      Continue;
    End;
    { if / elif / else (recursif - TODO 13) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'if') Then
    Begin
      ParseIfStmt;
      Continue;
    End;
    { while (TODO 14) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'while') Then
    Begin
      ParseWhileStmt;
      Continue;
    End;
    { for (TODO 14) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'for') Then
    Begin
      ParseForStmt;
      Continue;
    End;
    { break (TODO 14) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'break') Then
    Begin
      EmitComment('break');
      If LoopTop > 0 Then
        EmitInstr('JMP    ' + LoopBreakStack[LoopTop - 1])
      Else
        CompileError('break en dehors d''une boucle', CurToken.Line);
      ParserAdvance;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { continue (TODO 14) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'continue') Then
    Begin
      EmitComment('continue');
      If LoopTop > 0 Then
        EmitInstr('JMP    ' + LoopContStack[LoopTop - 1])
      Else
        CompileError('continue en dehors d''une boucle', CurToken.Line);
      ParserAdvance;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { pass : instruction vide }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'pass') Then
    Begin
      EmitComment('pass');
      ParserAdvance;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { return (TODO 17) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'return') Then
    Begin
      ParseReturnStmt;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { def (TODO 17) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'def') Then
    Begin
      ParseDefStmt;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { class (TODO 18) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'class') Then
    Begin
      ParseClassStmt;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { global }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'global') Then
    Begin
      ParserAdvance;
      While (CurToken.Kind <> TK_EOF) And
            (CurToken.Kind <> TK_NEWLINE) Do
      Begin
        If CurToken.Kind = TK_IDENT Then
        Begin
          VarName := CurToken.Val;
          Idx := SymFind(VarName);
          If Idx < 0 Then
            Idx := SymAdd(VarName, SK_VAR, TY_UNKNOWN, 0);
          If Idx >= 0 Then
            SymTab[Idx].IsGlobal := True;
        End;
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          ParserAdvance;
      End;
      Continue;
    End;
    { nonlocal }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'nonlocal') Then
    Begin
      ParserAdvance;
      While (CurToken.Kind <> TK_EOF) And
            (CurToken.Kind <> TK_NEWLINE) Do
      Begin
        If CurToken.Kind = TK_IDENT Then
        Begin
          VarName := CurToken.Val;
          Idx := SymFind(VarName);
          If Idx < 0 Then
            Idx := SymAdd(VarName, SK_VAR, TY_UNKNOWN, 0);
          If Idx >= 0 Then
            SymTab[Idx].IsNonlocal := True;
        End;
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          ParserAdvance;
      End;
      Continue;
    End;
    { try/except/finally (TODO 21) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'try') Then
    Begin
      ParseTryStmt;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { raise (TODO 21) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'raise') Then
    Begin
      ParseRaiseStmt;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { import module (TODO 23) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'import') Then
    Begin
      ParseImportStmt;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { from module import ... (TODO 23) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'from') Then
    Begin
      ParseFromImportStmt;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { Autres mots-cles (stub) - sauter la ligne }
    If (CurToken.Kind = TK_KEYWORD) And
       (CurToken.Val <> 'True') And (CurToken.Val <> 'False') And
       (CurToken.Val <> 'None') And (CurToken.Val <> 'not') Then
    Begin
      While (CurToken.Kind <> TK_EOF) And
            (CurToken.Kind <> TK_NEWLINE) Do
        ParserAdvance;
      Continue;
    End;
    { Affectation : ident = expr / ident += expr / a, b = e1, e2 }
    If CurToken.Kind = TK_IDENT Then
    Begin
      VarName := CurToken.Val;
      Idx := SymFind(VarName);
      If Idx < 0 Then
        Idx := SymAdd(VarName, SK_VAR, TY_UNKNOWN, 0);
      ParserAdvance;
      { TODO 18 : self.attr = val dans un bloc de methode }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
      Begin
        ParserAdvance;  { consommer '.' }
        If CurToken.Kind = TK_IDENT Then
        Begin
          AttrName := CurToken.Val;
          ParserAdvance;
          If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
          Begin
            ParserAdvance;  { consommer '=' }
            EmitComment('attr assign: ' + VarName + '.' + AttrName +
                        ' = val');
            If InClass And (CurClassIdx >= 0) Then
              ClassAddAttr(CurClassIdx, AttrName);
            ExprLoadToAX(Idx);
            EmitInstr('PUSH   AX');
            ParseExpr(GExprDummy);
            ExprFlushToAX(GExprDummy);
            EmitInstr('MOV    DX, AX');
            EmitInstr('POP    BX');
            If InClass And (CurClassIdx >= 0) Then
            Begin
              AttrIdx := ClassFindAttr(CurClassIdx, AttrName);
              If AttrIdx >= 0 Then
                EmitInstr('MOV    [BX+' + IntToStr_(2 + AttrIdx * 2) +
                          '], DX')
              Else
                EmitInstr('MOV    [BX+2], DX');
            End
            Else
              EmitInstr('MOV    [BX+2], DX');
            If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
            Continue;
          End
          Else
          Begin
            { Lecture attribut ou appel methode }
            ExprLoadToAX(Idx);
            EmitInstr('MOV    SI, AX');
            If InClass And (CurClassIdx >= 0) Then
            Begin
              AttrIdx := ClassFindAttr(CurClassIdx, AttrName);
              If AttrIdx >= 0 Then
                EmitInstr('MOV    AX, [SI+' + IntToStr_(2 + AttrIdx * 2) + ']')
              Else
                EmitInstr('MOV    AX, [SI]');
            End
            Else
              EmitInstr('MOV    AX, [SI]');
            GExprDummy.Kind    := EK_AX;
            GExprDummy.TypeIdx := TY_IDX_INT;
            GExprDummy.Offset  := 0;
            GExprDummy.SymIdx  := -1;
            GExprDummy.ImmVal  := 0;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
            Begin
              MethClsIdx := -1;
              MethIdx := -1;
              For ClsI := 0 To ClassCount - 1 Do
              Begin
                MethIdx := ClassFindMeth(ClsI, AttrName);
                If MethIdx >= 0 Then
                Begin
                  MethClsIdx := ClsI;
                  Break;
                End;
              End;
              If MethIdx >= 0 Then
              Begin
                EmitComment('method: .' + AttrName);
                ParserAdvance;
                ArgCnt := 0;
                If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
                Begin
                  ParseExpr(GExprDummy);
                  ExprFlushToAX(GExprDummy);
                  EmitInstr('PUSH   AX');
                  Inc(ArgCnt);
                  While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
                  Begin
                    ParserAdvance;
                    ParseExpr(GExprDummy);
                    ExprFlushToAX(GExprDummy);
                    EmitInstr('PUSH   AX');
                    Inc(ArgCnt);
                  End;
                End;
                ExprLoadToAX(Idx);
                EmitInstr('PUSH   AX');
                EmitInstr('CALL   ' + ClassTab[MethClsIdx].MethLabels[MethIdx]);
                EmitInstr('ADD    SP, ' + IntToStr_((ArgCnt + 1) * 2));
                If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                  ParserAdvance;
              End
              Else
              Begin
                ParserAdvance;
                While (CurToken.Kind <> TK_EOF) And
                      Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
                  ParserAdvance;
                If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                  ParserAdvance;
              End;
            End;
          End;
        End;
        If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
        Continue;
      End;
      If ((CurToken.Kind = TK_OP) And IsAssignOp(CurToken.Val)) Or
         ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',')) Then
      Begin
        ParseAssign(Idx);
        If CurToken.Kind = TK_NEWLINE Then
          ParserAdvance;
        Continue;
      End
      Else
      Begin
        GExprDummy.Kind    := EK_MEM;
        GExprDummy.TypeIdx := SymTab[Idx].TypeIdx;
        GExprDummy.Offset  := SymTab[Idx].Offset;
        GExprDummy.SymIdx  := Idx;
        GExprDummy.ImmVal  := 0;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          ParseCallArgs(Idx, GExprDummy);
        If (CurToken.Kind = TK_OP) And (BinOpPrec(CurToken.Val) > 0) Then
          ExprFlushToAX(GExprDummy);
      End;
    End
    Else
    Begin
      ParseExpr(GExprDummy);
    End;
    { Avancer si bloque }
    If (CurToken.Kind <> TK_EOF) And
       (CurToken.Kind <> TK_NEWLINE) And
       (CurToken.Kind <> TK_DEDENT) Then
      ParserAdvance;
    If CurToken.Kind = TK_NEWLINE Then
      ParserAdvance;
  End;
  { Consommer le DEDENT }
  If CurToken.Kind = TK_DEDENT Then
    ParserAdvance;
End;

{ ---- ParseIfStmt : parser if / elif / else -------------------- }
Procedure ParseIfStmt;
Var
  LblElse  : TString;
  LblEndIf : TString;
  CondRes  : TExprVal;
Begin
  LblEndIf := LabelGen;

  { Consommer 'if' }
  EmitComment('-- if --');
  ParserAdvance;

  { Parser la condition }
  ParseExpr(CondRes);
  ExprFlushToAX(CondRes);

  { Attendre ':' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    ParserAdvance
  Else
    CompileError(''':'' attendu apres condition if', CurToken.Line);

  { Generer le saut conditionnel }
  LblElse := LabelGen;
  EmitInstr('TEST   AX, AX');
  EmitInstr('JZ     ' + LblElse);

  { Parser le bloc if }
  ParseBlock;

  { Saut vers la fin }
  EmitInstr('JMP    ' + LblEndIf);

  { Label else/elif }
  EmitLabel(LblElse);

  { Boucle pour les elif }
  While (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'elif') Do
  Begin
    EmitComment('-- elif --');
    ParserAdvance;

    { Parser la condition elif }
    ParseExpr(CondRes);
    ExprFlushToAX(CondRes);

    { Attendre ':' }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      ParserAdvance
    Else
      CompileError(''':'' attendu apres condition elif', CurToken.Line);

    { Generer le saut conditionnel }
    LblElse := LabelGen;
    EmitInstr('TEST   AX, AX');
    EmitInstr('JZ     ' + LblElse);

    { Parser le bloc elif }
    ParseBlock;

    { Saut vers la fin }
    EmitInstr('JMP    ' + LblEndIf);

    { Label pour le prochain elif/else }
    EmitLabel(LblElse);
  End;

  { Branche else optionnelle }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'else') Then
  Begin
    EmitComment('-- else --');
    ParserAdvance;

    { Attendre ':' }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      ParserAdvance
    Else
      CompileError(''':'' attendu apres else', CurToken.Line);

    { Parser le bloc else }
    ParseBlock;
  End;

  { Label fin du if }
  EmitLabel(LblEndIf);
End;

Procedure Run;
Var
  VarName    : TString;
  Idx        : Integer;
  LblSkip    : TString;
  AttrName   : TString;
  AttrIdx    : Integer;
  MethClsIdx : Integer;
  MethIdx    : Integer;
  ArgCnt     : Integer;
  ClsI       : Integer;
Begin
  GlobalInit;
  SymInit;
  TypeInit;
  If Opts.Verbose Then ShowBanner;

  EmitOpen;
  EmitHeader;

  { Point d entree principal }
  EmitComment('-- Point d entree principal --');
  EmitLabel('_PYF_Main');
  EmitInstr('MOV AX,_DATA');
  EmitInstr('MOV DS,AX');
  EmitProlog(0);
  EmitBlankLine;

  LexInit;

  { Lire le premier token }
  ParserAdvance;

  { Boucle principale : parser des expressions (TODO 04+) }
  While CurToken.Kind <> TK_EOF Do
  Begin
    { Sauter les NEWLINE et INDENT/DEDENT entre instructions }
    If (CurToken.Kind = TK_NEWLINE) Or
       (CurToken.Kind = TK_INDENT) Or
       (CurToken.Kind = TK_DEDENT) Then
    Begin
      ParserAdvance;
      Continue;
    End;
    { Instruction global : marquer les variables comme globales }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'global') Then
    Begin
      ParserAdvance;
      While (CurToken.Kind <> TK_EOF) And
            (CurToken.Kind <> TK_NEWLINE) Do
      Begin
        If CurToken.Kind = TK_IDENT Then
        Begin
          VarName := CurToken.Val;
          Idx := SymFind(VarName);
          If Idx < 0 Then
            Idx := SymAdd(VarName, SK_VAR, TY_UNKNOWN, 0);
          If Idx >= 0 Then
            SymTab[Idx].IsGlobal := True;
        End;
        ParserAdvance;
        { Sauter les virgules }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          ParserAdvance;
      End;
      Continue;
    End;
    { Instruction nonlocal : marquer les variables comme nonlocal }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'nonlocal') Then
    Begin
      ParserAdvance;
      While (CurToken.Kind <> TK_EOF) And
            (CurToken.Kind <> TK_NEWLINE) Do
      Begin
        If CurToken.Kind = TK_IDENT Then
        Begin
          VarName := CurToken.Val;
          Idx := SymFind(VarName);
          If Idx < 0 Then
            Idx := SymAdd(VarName, SK_VAR, TY_UNKNOWN, 0);
          If Idx >= 0 Then
            SymTab[Idx].IsNonlocal := True;
        End;
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          ParserAdvance;
      End;
      Continue;
    End;
    { Instruction def (TODO 17) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'def') Then
    Begin
      ParseDefStmt;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { Instruction class (TODO 18) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'class') Then
    Begin
      ParseClassStmt;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { Instruction return (TODO 17) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'return') Then
    Begin
      ParseReturnStmt;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { Instruction if / elif / else (TODO 13) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'if') Then
    Begin
      ParseIfStmt;
      Continue;
    End;
    { Instruction while (TODO 14) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'while') Then
    Begin
      ParseWhileStmt;
      Continue;
    End;
    { Instruction for (TODO 14) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'for') Then
    Begin
      ParseForStmt;
      Continue;
    End;
    { Instruction break (TODO 14) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'break') Then
    Begin
      EmitComment('break');
      If LoopTop > 0 Then
        EmitInstr('JMP    ' + LoopBreakStack[LoopTop - 1])
      Else
        CompileError('break en dehors d''une boucle', CurToken.Line);
      ParserAdvance;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { Instruction continue (TODO 14) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'continue') Then
    Begin
      EmitComment('continue');
      If LoopTop > 0 Then
        EmitInstr('JMP    ' + LoopContStack[LoopTop - 1])
      Else
        CompileError('continue en dehors d''une boucle', CurToken.Line);
      ParserAdvance;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { Instruction pass (TODO 13) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'pass') Then
    Begin
      EmitComment('pass');
      ParserAdvance;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { Instruction del (TODO 16) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'del') Then
    Begin
      EmitComment('del');
      ParserAdvance;  { consommer 'del' }
      If CurToken.Kind = TK_IDENT Then
      Begin
        VarName := CurToken.Val;
        Idx := SymFind(VarName);
        If Idx < 0 Then
          Idx := SymAdd(VarName, SK_VAR, TY_UNKNOWN, 0);
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
        Begin
          { del d[key] }
          ExprLoadToAX(Idx);
          EmitInstr('MOV    SI, AX');
          ParserAdvance;  { consommer '[' }
          ParseExpr(GExprDummy);
          ExprFlushToAX(GExprDummy);
          EmitInstr('CALL   ' + PY_RT_PFX + 'DICTDEL');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
            ParserAdvance;
        End;
      End;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { Instruction try/except/finally (TODO 21) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'try') Then
    Begin
      ParseTryStmt;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { Instruction raise (TODO 21) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'raise') Then
    Begin
      ParseRaiseStmt;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { Instruction import module (TODO 23) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'import') Then
    Begin
      ParseImportStmt;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { Instruction from module import ... (TODO 23) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'from') Then
    Begin
      ParseFromImportStmt;
      If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
      Continue;
    End;
    { Mots-cles d instruction : stub (TODO 06+) - sauter la ligne }
    If (CurToken.Kind = TK_KEYWORD) And
       (CurToken.Val <> 'True') And (CurToken.Val <> 'False') And
       (CurToken.Val <> 'None') And (CurToken.Val <> 'not') Then
    Begin
      While (CurToken.Kind <> TK_EOF) And
            (CurToken.Kind <> TK_NEWLINE) Do
        ParserAdvance;
      Continue;
    End;
    { Affectation : ident = expr / ident += expr / a, b = e1, e2 (TODO 09) }
    If CurToken.Kind = TK_IDENT Then
    Begin
      VarName := CurToken.Val;
      Idx := SymFind(VarName);
      If Idx < 0 Then
        Idx := SymAdd(VarName, SK_VAR, TY_UNKNOWN, 0);
      ParserAdvance;
      { TODO 18 : Detecter affectation attribut : ident.attr = val }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
      Begin
        ParserAdvance;  { consommer '.' }
        If CurToken.Kind = TK_IDENT Then
        Begin
          AttrName := CurToken.Val;
          ParserAdvance;
          If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
          Begin
            ParserAdvance;  { consommer '=' }
            EmitComment('attr assign: ' + VarName + '.' + AttrName +
                        ' = val');
            { Decouvrir l attribut si on est dans __init__ }
            If InClass And (CurClassIdx >= 0) Then
              ClassAddAttr(CurClassIdx, AttrName);
            { Charger le pointeur objet (self ou variable) }
            ExprLoadToAX(Idx);
            EmitInstr('PUSH   AX');      { sauver ptr objet }
            { Evaluer la valeur a assigner }
            ParseExpr(GExprDummy);
            ExprFlushToAX(GExprDummy);
            EmitInstr('MOV    DX, AX');  { DX = valeur }
            EmitInstr('POP    BX');      { BX = ptr objet }
            If InClass And (CurClassIdx >= 0) Then
            Begin
              AttrIdx := ClassFindAttr(CurClassIdx, AttrName);
              If AttrIdx >= 0 Then
                EmitInstr('MOV    [BX+' + IntToStr_(2 + AttrIdx * 2) +
                          '], DX')
              Else
                EmitInstr('MOV    [BX+2], DX');
            End
            Else
              EmitInstr('MOV    [BX+2], DX');
            If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
            Continue;
          End
          Else
          Begin
            { Lecture attribut ou appel de methode }
            ExprLoadToAX(Idx);
            EmitInstr('MOV    SI, AX');
            If InClass And (CurClassIdx >= 0) Then
            Begin
              AttrIdx := ClassFindAttr(CurClassIdx, AttrName);
              If AttrIdx >= 0 Then
                EmitInstr('MOV    AX, [SI+' + IntToStr_(2 + AttrIdx * 2) + ']')
              Else
                EmitInstr('MOV    AX, [SI]');
            End
            Else
              EmitInstr('MOV    AX, [SI]');
            GExprDummy.Kind    := EK_AX;
            GExprDummy.TypeIdx := TY_IDX_INT;
            GExprDummy.Offset  := 0;
            GExprDummy.SymIdx  := -1;
            GExprDummy.ImmVal  := 0;
            { Appel de methode : ident.method(args) (TODO 18) }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
            Begin
              MethClsIdx := -1;
              MethIdx := -1;
              For ClsI := 0 To ClassCount - 1 Do
              Begin
                MethIdx := ClassFindMeth(ClsI, AttrName);
                If MethIdx >= 0 Then
                Begin
                  MethClsIdx := ClsI;
                  Break;
                End;
              End;
              If MethIdx >= 0 Then
              Begin
                EmitComment('obj method: .' + AttrName);
                ParserAdvance;  { consommer '(' }
                ArgCnt := 0;
                If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
                Begin
                  ParseExpr(GExprDummy);
                  ExprFlushToAX(GExprDummy);
                  EmitInstr('PUSH   AX');
                  Inc(ArgCnt);
                  While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
                  Begin
                    ParserAdvance;
                    ParseExpr(GExprDummy);
                    ExprFlushToAX(GExprDummy);
                    EmitInstr('PUSH   AX');
                    Inc(ArgCnt);
                  End;
                End;
                ExprLoadToAX(Idx);
                EmitInstr('PUSH   AX');  { self }
                EmitInstr('CALL   ' + ClassTab[MethClsIdx].MethLabels[MethIdx]);
                EmitInstr('ADD    SP, ' + IntToStr_((ArgCnt + 1) * 2));
                If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                  ParserAdvance;
              End
              Else
              Begin
                ParserAdvance;
                While (CurToken.Kind <> TK_EOF) And
                      Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
                  ParserAdvance;
                If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                  ParserAdvance;
              End;
            End;
          End;
        End;
        If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
        Continue;
      End;
      { TODO 15 : Detecter affectation par index : ident[i] = val }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
      Begin
        ExprLoadToAX(Idx);
        EmitInstr('PUSH   AX');            { sauver ptr liste }
        ParserAdvance;                     { consommer '[' }
        ParseExpr(GExprDummy);
        ExprFlushToAX(GExprDummy);
        EmitInstr('PUSH   AX');            { sauver index }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
          ParserAdvance
        Else
          CompileError(''']'' attendue', CurToken.Line);
        If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
        Begin
          { TODO 19 : tuples immuables -> erreur de compilation }
          If SymTab[Idx].TypeIdx = TY_IDX_TUPLE Then
          Begin
            CompileError('les tuples sont immuables : affectation par index interdite', CurToken.Line);
            ParserAdvance;
            Continue;
          End;
          ParserAdvance;                   { consommer '=' }
          ParseExpr(GExprDummy);
          ExprFlushToAX(GExprDummy);
          If SymTab[Idx].TypeIdx = TY_IDX_DICT Then
          Begin
            { Dict : d[key] = val -> DICTSET }
            EmitComment('dict assign: ' + VarName + '[key] = val');
            EmitInstr('MOV    BX, AX');      { BX = valeur }
            EmitInstr('POP    AX');          { AX = key }
            EmitInstr('POP    SI');          { SI = ptr dict }
            EmitInstr('CALL   ' + PY_RT_PFX + 'DICTSET');
          End
          Else
          Begin
            { List : ident[i] = val }
            EmitComment('index assign: ' + VarName + '[i] = val');
            EmitInstr('MOV    BX, AX');      { BX = valeur }
            EmitInstr('POP    AX');          { AX = index }
            EmitInstr('POP    SI');          { SI = ptr liste }
            LblSkip := LabelGen;
            EmitInstr('TEST   AX, AX');
            EmitInstr('JGE    ' + LblSkip);
            EmitInstr('ADD    AX, [SI]');    { index negatif }
            EmitLabel(LblSkip);
            EmitInstr('SHL    AX, 1');
            EmitInstr('ADD    AX, 2');       { sauter count header }
            EmitInstr('ADD    SI, AX');
            EmitInstr('MOV    [SI], BX');
          End;
          If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
          Continue;
        End
        Else
        Begin
          If SymTab[Idx].TypeIdx = TY_IDX_DICT Then
          Begin
            { Dict access : d[key] }
            EmitComment('dict access: ' + VarName + '[key]');
            EmitInstr('POP    AX');          { AX = key }
            EmitInstr('POP    SI');          { SI = ptr dict }
            EmitInstr('CALL   ' + PY_RT_PFX + 'DICTGET');
          End
          Else
          Begin
            { Pas une affectation : acces index en expression }
            EmitComment('index access: ' + VarName + '[i]');
            EmitInstr('POP    BX');          { BX = index }
            EmitInstr('POP    SI');          { SI = ptr liste }
            LblSkip := LabelGen;
            EmitInstr('TEST   BX, BX');
            EmitInstr('JGE    ' + LblSkip);
            EmitInstr('ADD    BX, [SI]');
            EmitLabel(LblSkip);
            EmitInstr('SHL    BX, 1');
            EmitInstr('ADD    BX, 2');
            EmitInstr('ADD    SI, BX');
            EmitInstr('MOV    AX, [SI]');
          End;
          GExprDummy.Kind    := EK_AX;
          GExprDummy.TypeIdx := TY_IDX_INT;
          GExprDummy.Offset  := 0;
          GExprDummy.SymIdx  := -1;
          GExprDummy.ImmVal  := 0;
        End;
        If CurToken.Kind = TK_NEWLINE Then ParserAdvance;
        Continue;
      End;
      { Detecter affectation simple/augmentee/multiple }
      If ((CurToken.Kind = TK_OP) And IsAssignOp(CurToken.Val)) Or
         ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',')) Then
      Begin
        ParseAssign(Idx);
        { Sauter les NEWLINE apres l affectation }
        If CurToken.Kind = TK_NEWLINE Then
          ParserAdvance;
        Continue;
      End
      Else
      Begin
        { Pas une affectation : c est une expression commencant par ident }
        { L identifiant est deja consomme, il faut le traiter }
        { On construit un EK_MEM pour le symbole et on continue le parseur }
        GExprDummy.Kind    := EK_MEM;
        GExprDummy.TypeIdx := SymTab[Idx].TypeIdx;
        GExprDummy.Offset  := SymTab[Idx].Offset;
        GExprDummy.SymIdx  := Idx;
        GExprDummy.ImmVal  := 0;
        { Appel de fonction : f(args) (TODO 10) }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          ParseCallArgs(Idx, GExprDummy);
        { TODO 15 : Appel de methode : ident.method(args) }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
        Begin
          ExprFlushToAX(GExprDummy);
          EmitInstr('MOV    SI, AX');
          ParserAdvance;  { consommer '.' }
          If CurToken.Kind = TK_IDENT Then
          Begin
            VarName := CurToken.Val;
            EmitComment('method: .' + VarName);
            ParserAdvance;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
            Begin
              If (SymTab[Idx].TypeIdx = TY_IDX_LIST) And
                 (VarName = 'append') Then
              Begin
                EmitInstr('PUSH   SI');
                ParserAdvance;
                ParseExpr(GExprDummy);
                ExprFlushToAX(GExprDummy);
                EmitInstr('POP    SI');
                EmitInstr('CALL   ' + PY_RT_PFX + 'LISTAPPEND');
                If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                  ParserAdvance;
              End
              Else If (SymTab[Idx].TypeIdx = TY_IDX_LIST) And
                      (VarName = 'pop') Then
              Begin
                ParserAdvance;
                If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                  ParserAdvance;
                EmitInstr('CALL   ' + PY_RT_PFX + 'LISTPOP');
              End
              Else If (SymTab[Idx].TypeIdx = TY_IDX_LIST) And
                      (VarName = 'insert') Then
              Begin
                EmitInstr('PUSH   SI');
                ParserAdvance;
                ParseExpr(GExprDummy);
                ExprFlushToAX(GExprDummy);
                EmitInstr('PUSH   AX');
                If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
                  ParserAdvance;
                ParseExpr(GExprDummy);
                ExprFlushToAX(GExprDummy);
                EmitInstr('MOV    BX, AX');
                EmitInstr('POP    AX');
                EmitInstr('POP    SI');
                EmitInstr('CALL   ' + PY_RT_PFX + 'LISTINSERT');
                If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                  ParserAdvance;
              End
              Else
              Begin
                { Methode generique : sauter les arguments }
                ParserAdvance;
                While (CurToken.Kind <> TK_EOF) And
                      Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
                  ParserAdvance;
                If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                  ParserAdvance;
              End;
            End;
          End;
        End;
        { Si un operateur binaire suit, continuer le parsing }
        If (CurToken.Kind = TK_OP) And (BinOpPrec(CurToken.Val) > 0) Then
        Begin
          ExprFlushToAX(GExprDummy);
          { Continuer avec ParseExprPrec en utilisant le resultat courant }
          { On reparse depuis la boucle precedente }
        End;
      End;
    End
    Else
    Begin
      { Parser une expression }
      ParseExpr(GExprDummy);
    End;
    { Garde de securite : si le token n a pas avance, forcer }
    If (CurToken.Kind <> TK_EOF) And
       (CurToken.Kind <> TK_NEWLINE) Then
      ParserAdvance;
    { Sauter les NEWLINE apres l expression }
    If CurToken.Kind = TK_NEWLINE Then
      ParserAdvance;
  End;

  LexClose;

  { Epilogue et sortie DOS }
  EmitBlankLine;
  EmitComment('-- Fin du programme --');
  EmitEpilog;
  EmitInstr('MOV AX,4C00h');
  EmitInstr('INT 21h');

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
Begin
  ParseArgs;
  Run;
End.
