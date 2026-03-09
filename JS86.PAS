{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur JavaScript vers assembleur 8086
  @license: MIT
}

(* ============================================================
  JS86.PAS - Compilateur JavaScript vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits
  ============================================================ *)

Program JS86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  JS86_VERSION = '1.0';
  JS86_DATE    = '2026-03-05';

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
  MAX_ARR_ELEM  = 64;   { elements max par tableau literal inline }
  MAX_OBJ_PROP  = 16;   { proprietes max par objet literal inline }
  STACK_SIZE    = 1024;
  CALL_DEPTH_WARN = 32;  { seuil d avertissement profondeur appels }

  { Prefixes de nommage ASM }
  JS_VAR_PFX  = '_JSV_';    { variable scalaire / objet / tableau }
  JS_FN_PFX   = '_JSF_';    { fonction / methode                  }
  JS_STR_PFX  = '_JSK_';    { constante chaine litterale          }
  JS_RT_PFX   = '_JSRT_';   { routine runtime                     }
  JS_LBL_PFX  = '_JSL_';    { label de saut interne               }
  JS_OBJ_PFX  = '_JSO_';    { objet literal DATA                  }
  JS_ARR_PFX  = '_JSA_';    { tableau literal DATA                }
  JS_CLS_PFX  = '_JSC_';    { classe / prototype                  }
  JS_UNDEF_LBL = '_JS_UNDEF';  { etiquette DATA chaine 'undefined'   }
  JS_NULL_LBL  = '_JS_NULL';   { etiquette DATA chaine 'null'        }
  JS_TRUE_LBL  = '_JS_TRUE';   { etiquette DATA chaine 'true'        }
  JS_FALSE_LBL = '_JS_FALSE';  { etiquette DATA chaine 'false'       }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Indices de types primitifs JavaScript }
  TY_IDX_NUMBER   = 0;  { entier 16 bits signe  }
  TY_IDX_STRING   = 1;  { pointeur chaine DATA  }
  TY_IDX_BOOLEAN  = 2;  { 0 ou 1 dans AX        }
  TY_IDX_OBJECT   = 3;  { pointeur struct DATA   }
  TY_IDX_ARRAY    = 4;  { pointeur bloc DATA     }
  TY_IDX_FUNCTION = 5;  { pointeur de code       }
  TY_IDX_NULL     = 6;  { AX=0                   }
  TY_IDX_UNDEF    = 7;  { AX=0 (undefined)       }
  TY_PRIM_COUNT   = 8;
  TY_UNKNOWN      = -1;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;   { script source (.js)                  }
    OutFile   : TString;   { fichier assembleur de sortie (.asm)  }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Strict    : Boolean;   { -s ou 'use strict' detecte           }
    Warnings  : Boolean;   { -w : activer les avertissements      }
  End;

  { ---- Tokens JavaScript ----------------------- }
  TTokenKind = (
    TK_EOF,       { fin de fichier                          }
    TK_INTEGER,   { literal entier 42 0xFF 0b101 0o17      }
    TK_FLOAT,     { literal flottant 3.14 1.5e3            }
    TK_STRING,    { literal chaine simple ou double quote  }
    TK_TEMPLATE,  { template literal backtick-dollar-brace }
    TK_REGEXP,    { expression reguliere /pat/flags        }
    TK_IDENT,     { identificateur (non-mot-cle)           }
    TK_KEYWORD,   { mot-cle JS reconnu                     }
    TK_OP,        { operateur + - * / === !==  etc.        }
    TK_PUNCT      { ponctuation ; , ( ) [ ] accolades        }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;     { valeur textuelle brute          }
    IntVal   : LongInt;     { valeur entiere (TK_INTEGER)     }
    FloatVal : Real;        { valeur flottante (TK_FLOAT)     }
    Line     : Integer;     { ligne source (1-base)           }
    Col      : Integer;     { colonne source (1-base)         }
  End;

  { ---- Categories de symboles ------------------ }
  TSymCat = (
    SC_VAR,        { var (hoist)                      }
    SC_LET,        { let (block-scope)                }
    SC_CONST_JS,   { const (block-scope, immutable)   }
    SC_PARAM,      { parametre formel de fonction      }
    SC_FUNCTION,   { declaration function             }
    SC_CLASS,      { declaration class                }
    SC_LABEL       { label de boucle etiquetee        }
  );

  TSymRec = Record
    Name        : TString;   { identifiant JS                  }
    MangledName : TString;   { _JSV_nom / _JSF_nom             }
    Cat         : TSymCat;
    TypeIdx     : Integer;   { indice dans TypeTab             }
    ScopeLevel  : Integer;
    Offset      : Integer;   { [BP-n] pour locaux              }
    IsHoisted   : Boolean;   { var : hisse au sommet fn        }
    IsConst     : Boolean;   { const : erreur si reassigne     }
    IsParam     : Boolean;   { parametre de fonction           }
    IsCapture   : Boolean;   { variable capturee par closure   }
    CaptureLabel: TString;    { label DATA pour var capturee }
    FnDepthLvl  : Integer;    { CurFnDepth au moment de la creation  }
    DeclLine    : Integer;
  End;

  { ---- Types internes -------------------------- }
  TTypeKind = (
    TKJ_NUMBER,
    TKJ_STRING,
    TKJ_BOOLEAN,
    TKJ_OBJECT,
    TKJ_ARRAY,
    TKJ_FUNCTION,
    TKJ_NULL,
    TKJ_UNDEFINED,
    TKJ_UNKNOWN
  );

  TTypeRec = Record
    Name    : TString;
    Kind    : TTypeKind;
    Size    : Integer;   { octets : number=2, ptr=2 }
  End;

  { ---- Valeurs d'expression -------------------- }
  TExprKind = (
    EK_NONE,   { void / pas de valeur            }
    EK_IMM,    { immediate dans ImmVal           }
    EK_AX,     { valeur dans AX                  }
    EK_MEM     { adresse [BP+Offset] ou [_JSV_x] }
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
    SymIdx  : Integer;   { indice dans SymTab (-1 = pas de lvalue) }
  End;

  { ---- Segment de donnees ---------------------- }
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY_BLK, DK_OBJ_BLK);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;  { DK_ARRAY_BLK : nb elements, DK_OBJ_BLK : nb props }
  End;

  { Etat lexer sauvegardable pour lookahead speculatif }
  TLexState = Record
    Token     : TToken;
    Line      : TString;
    LineNo    : Integer;
    ColNo     : Integer;
    IsEOF     : Boolean;
    ASIFlag   : Boolean;
    PrevKind  : TTokenKind;
    PrevVal   : TString;
    ExpRegex  : Boolean;
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

  { Lexeur }
  LexSrcF        : Text;
  LexLine        : String;
  LexLineNo      : Integer;
  LexColNo       : Integer;
  LexEOF         : Boolean;
  LexOpened      : Boolean;
  CurToken       : TToken;
  LexExpectRegex : Boolean;  { True apres = ( [ ! & | ? : , ; return }
  LexASIFlag     : Boolean;  { True si ASI doit etre insere avant }
  LexPrevKind    : TTokenKind; { type du token precedent pour ASI }
  LexPrevVal     : TString;    { valeur du token precedent pour ASI }

  { Table des symboles }
  SymTab     : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount   : Integer;
  ScopeStack      : Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeFrameStack  : Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeTop   : Integer;
  CurScope   : Integer;
  LabelSeq   : Integer;

  { Table des types }
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

  { Emetteur ASM }
  OutF         : Text;
  OutFOpen     : Boolean;
  CurFrameSize : Integer;    { taille cadre local courant (words)   }
  CurFnDepth   : Integer;    { 0 = global, >0 = dans une function  }
  CurFnRetLbl  : TString;    { label epilogue de la function        }
  CurFnName    : TString;    { nom de la function courante          }
  CurClassName : TString;    { nom de la classe courante }
  CurParentClass : TString;  { nom de la classe parente  }
  CurMethodThis  : Integer;  { offset BP du param cache this (0=no) }
  LoopTop      : Integer;
  LoopBreakLbl : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContLbl  : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LabelGenSeq  : Integer;    { compteur unique pour LabelGen        }

  { Segment de donnees }
  DataTab   : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount : Integer;

  { Etat general }
  RuntimeEmitted : Boolean;
  GKwConsumed    : Boolean;  { mot-cle deja consomme avant ParseStmt }
  GCallArgCount  : Integer;  { nb args du dernier ParseCallArgs      }
  TempRegMask    : Integer;  { masque BX=1 CX=2 DX=4 registres temporaires }

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
Procedure LexInit;             Forward;
Procedure LexClose;            Forward;
Function  IsKeyword(Const S : TString) : Boolean; Forward;
Procedure PrintToken(Const T : TToken); Forward;
Procedure LexNextLine;         Forward;
Procedure LexCheckASI;         Forward;
Procedure LexSkipBlockComment; Forward;
Function  IsIdentStart(Ch : Char) : Boolean; Forward;
Function  IsIdentCont(Ch : Char) : Boolean; Forward;
Function  IsHexDigit(Ch : Char) : Boolean; Forward;
Function  HexVal(Ch : Char) : Integer; Forward;
Procedure LexScanIdent;        Forward;
Procedure LexScanNumber;       Forward;
Function  LexScanEscChar : Char; Forward;
Procedure LexScanString(Quote : Char); Forward;
Procedure LexScanTemplate;     Forward;
Procedure LexScanRegexp;       Forward;
Procedure LexNextToken;        Forward;

Function  LexRegexpFlagOk(Ch : Char) : Boolean; Forward;
Procedure LexCheckTagTemplate; Forward;
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ExprMakeNone(Var Res : TExprVal); Forward;
Procedure ExprMakeNull(Var Res : TExprVal); Forward;
Procedure ExprMakeUndef(Var Res : TExprVal); Forward;
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal); Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;

Function  BinOpPrec(Const Op : TString) : Integer; Forward;
Function  BinOpIsRight(Const Op : TString) : Boolean; Forward;
Function  IsAssignOp(Const Op : TString) : Boolean; Forward;
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Procedure ParseUnary(Var Res : TExprVal); Forward;
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Forward;
Procedure ParseExpr(Var Res : TExprVal); Forward;

Function  SymNameClean(Const Name : TString) : TString; Forward;
Function  SymMangle(Const Name : TString; Cat : TSymCat) : TString; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindCat(Const Name : TString; Cat : TSymCat) : Integer; Forward;
Function  SymAdd(Const Name : TString; Cat : TSymCat;
                 TypeIdx, Offset : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
Function  SymNextOffset : Integer; Forward;
Function  TempRegAcquire : TString; Forward;
Procedure TempRegRelease(Const RegName : TString); Forward;

Function  LabelGen : TString; Forward;
Procedure EmitRaw(Const S : TString); Forward;
Procedure EmitBlankLine; Forward;
Procedure EmitComment(Const S : TString); Forward;
Procedure EmitLabel(Const Lbl : TString); Forward;
Procedure EmitInstr(Const Mnem : TString); Forward;
Procedure EmitInstrA(Const Mnem, A1 : TString); Forward;
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString); Forward;
Procedure EmitProlog; Forward;
Procedure EmitEpilog; Forward;
Procedure EmitCoerce(SrcTypeIdx, DstTypeIdx : Integer); Forward;

Function  TypeSizeof(TypeIdx : Integer) : Integer; Forward;
Function  TypeMangle(TypeIdx : Integer) : TString; Forward;
Function  TypeKindOf(TypeIdx : Integer) : TTypeKind; Forward;
Function  TypeIsNumeric(TypeIdx : Integer) : Boolean; Forward;
Function  TypeIsPtr(TypeIdx : Integer) : Boolean; Forward;
Function  TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean; Forward;
Function  TypeCoerceResult(LeftIdx, RightIdx : Integer;
                           Const Op : TString) : Integer; Forward;
Procedure EmitOpen;            Forward;
Procedure EmitClose;     Forward;
Procedure EmitDataSeg;   Forward;

Function  ExprAddrOf(SIdx : Integer) : TString; Forward;
Procedure ExprFlushToAX(Const E : TExprVal); Forward;
Procedure ExprStore(SIdx : Integer); Forward;
Procedure ExprLoad(SIdx : Integer; Var Res : TExprVal); Forward;
Function  DeclAllocSym(Const Name : TString; Cat : TSymCat) : Integer; Forward;
Procedure ParseDeclStmt(Const Kw : TString); Forward;
Procedure ParseExprStmt; Forward;

Procedure ParseCallArgs(Var ArgCount : Integer); Forward;
Procedure ParsePostfix(Var Res : TExprVal); Forward;

Procedure ParseWhileStmt; Forward;
Procedure ParseDoWhileStmt; Forward;
Procedure ParseForStmt; Forward;

Procedure ParseIfStmt; Forward;
Procedure ParseSwitchStmt; Forward;
Procedure ParseBlock; Forward;
Procedure ParseStmtOrBlock; Forward;

Procedure ParseFuncDecl; Forward;

Procedure ParseClassDecl; Forward;

Procedure EmitCaptureSync(OuterDepth : Integer); Forward;

Procedure ParseTryStmt; Forward;
Procedure LexSaveState(Var St : TLexState); Forward;
Procedure LexRestoreState(Const St : TLexState); Forward;

Procedure EmitPrintAX(TIdx : Integer); Forward;
Procedure EmitPrintAXFD(TIdx, FD : Integer); Forward;
Procedure EmitPrintNewline(FD : Integer); Forward;
Procedure EmitPrintStr(Const Lbl : TString; FD : Integer); Forward;
Procedure EmitPrintSpace(FD : Integer); Forward;

Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                  AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : TString; Forward;
Function  DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer; Forward;
Procedure EmitRuntime;   Forward;
Procedure EmitHeader;    Forward;
Procedure ParserAdvance; Forward;
Procedure ParseStmt;     Forward;
Procedure TypeInit;      Forward;
Procedure SymInit;       Forward;

{ ============================================================
  INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- Messages d'erreur et d'avertissement ---------------- }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('JS86: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
    { Supprimer le fichier de sortie partiel }
    Assign(OutF, Opts.OutFile);
    Erase(OutF);
  End;
  Halt(EXIT_ERROR);
End;

Procedure CompileError(Const Msg : TString);
Begin
  Write('JS86:');
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
  Write('JS86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('warning: ', Msg);
  Inc(WarnCount);
End;

{ ---- Banniere ---------------------------------------------- }

Procedure ShowBanner;
Begin
  WriteLn('JS86 v', JS86_VERSION, ' (', JS86_DATE, ')');
  WriteLn('Compilateur JavaScript -> assembleur 8086 (MASM .MODEL SMALL)');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

Procedure ShowUsage;Begin
 WriteLn('JS86 - Cette commande permet de lancer le compilateur JavaScript ',
         'pour l''assembleur du microprocesseur 8086 ou 8088.');
 WriteLn;
 WriteLn('Syntaxe : JS86 <source.js> [sortie.asm] [-v] [-d] [-w] [-s]');
 WriteLn;
 WriteLn('  source.js  : fichier JavaScript source');
 WriteLn('  sortie.asm : fichier assembleur de sortie (defaut: source.asm)');
 WriteLn('  -v         : mode verbeux (banniere + statistiques)');
 WriteLn('  -d         : debug tokens (affiche chaque token)');
 WriteLn('  -w         : activer les avertissements');
 WriteLn('  -s         : mode strict (equivalent ''use strict'')');
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

Function StrReplace(Const S, Old, New : TString) : TString;
Var
  P   : Integer;
  Res : TString;
Begin
  Res := S;
  P := Pos(Old, Res);
  While P > 0 Do
  Begin
    Delete(Res, P, Length(Old));
    Insert(New, Res, P);
    P := Pos(Old, Res);
  End;
  StrReplace := Res;
End;

Function IntToStr(N : LongInt) : TString;
Var
  S : TString;
Begin
  Str(N, S);
  IntToStr := S;
End;

Function StrToIntDef(Const S : TString; Def : LongInt) : LongInt;
Var
  V : LongInt;
  C : Integer;
Begin
  Val(S, V, C);
  If C = 0 Then StrToIntDef := V
  Else          StrToIntDef := Def;
End;

{ Extrait le nom de base d'un chemin (sans extension) }
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

{ Replace extension d'un chemin }
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
  Opts.SrcFile  := '';
  Opts.OutFile  := '';
  Opts.Verbose  := False;
  Opts.DebugMode := False;
  Opts.Strict   := False;
  Opts.Warnings := False;
End;

{ ---- Analyse des arguments de la ligne de commande --------- }

Procedure ParseArgs;
Var
  I     : Integer;
  Arg   : TString;
  ALow  : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowUsage;

  For I := 1 To ParamCount Do
  Begin
    Arg  := ParamStr(I);
    ALow := StrLowerCase(Arg);

    If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg = '-s' Then
      Opts.Strict := True
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('JS86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('JS86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('JS86: fichier source manquant');
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
  LexExpectRegex := False;
  LexASIFlag     := False;
  LexPrevKind    := TK_EOF;
  LexPrevVal     := '';
  CurFnDepth     := 0;
  CurFnRetLbl    := '';
  CurFnName      := '';
  CurClassName   := '';
  CurParentClass := '';
  CurMethodThis  := 0;
  LoopTop        := 0;
  RuntimeEmitted := False;
  GKwConsumed    := False;
  GCallArgCount  := 0;
  CurFrameSize   := 0;
  TempRegMask    := 0;
  LabelGenSeq    := 0;
  GExprDummy.Kind    := EK_NONE;
  GExprDummy.ImmVal  := 0;
  GExprDummy.TypeIdx := TY_UNKNOWN;
  GExprDummy.Offset  := 0;
  GExprDummy.SymIdx  := -1;
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.FloatVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
End;

{ ============================================================
  LEXEUR (TOKENS JAVASCRIPT)
  ============================================================ }

{ ---- IsKeyword : teste si S est un mot-cle JavaScript ------ }
Function IsKeyword(Const S : TString) : Boolean;
Begin
  IsKeyword :=
    (S = 'var')       Or (S = 'let')       Or (S = 'const')      Or
    (S = 'function')  Or (S = 'return')    Or (S = 'if')         Or
    (S = 'else')      Or (S = 'while')     Or (S = 'do')         Or
    (S = 'for')       Or (S = 'of')        Or (S = 'in')         Or
    (S = 'break')     Or (S = 'continue')  Or (S = 'switch')     Or
    (S = 'case')      Or (S = 'default')   Or (S = 'new')        Or
    (S = 'delete')    Or (S = 'typeof')    Or (S = 'instanceof') Or
    (S = 'void')      Or (S = 'throw')     Or (S = 'try')        Or
    (S = 'catch')     Or (S = 'finally')   Or (S = 'class')      Or
    (S = 'extends')   Or (S = 'super')     Or (S = 'import')     Or
    (S = 'export')    Or (S = 'this')      Or (S = 'null')       Or
    (S = 'undefined') Or (S = 'true')      Or (S = 'false')      Or
    (S = 'async')     Or (S = 'await')     Or (S = 'yield')      Or
    (S = 'debugger')  Or (S = 'with')      Or (S = 'static')     Or
    (S = 'get')       Or (S = 'set');
End;

{ ---- PrintToken : affichage debug d'un token --------------- }
Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF      : Write('EOF');
    TK_INTEGER  : Write('INT(', T.IntVal, ')');
    TK_FLOAT    : Write('FLOAT(', T.Val, ')');
    TK_STRING   : Write('STR(', T.Val, ')');
    TK_TEMPLATE : Write('TMPL(', T.Val, ')');
    TK_REGEXP   : Write('RE(', StrReplace(T.Val, Chr(1), '|'), ')');
    TK_IDENT    : Write('IDENT(', T.Val, ')');
    TK_KEYWORD  : Write('KW(', T.Val, ')');
    TK_OP       : Write('OP(', T.Val, ')');
    TK_PUNCT    : Write('PUNCT(', T.Val, ')');
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

{ ---- LexCheckASI : faut-il inserer un ';' apres ce saut ? -- }
Procedure LexCheckASI;
Begin
  LexASIFlag := False;
  Case LexPrevKind Of
    TK_INTEGER, TK_FLOAT, TK_STRING, TK_TEMPLATE, TK_REGEXP, TK_IDENT :
      LexASIFlag := True;
    TK_KEYWORD :
      If (LexPrevVal = 'return')    Or (LexPrevVal = 'break')     Or
         (LexPrevVal = 'continue')  Or (LexPrevVal = 'throw')     Or
         (LexPrevVal = 'this')      Or (LexPrevVal = 'null')      Or
         (LexPrevVal = 'undefined') Or (LexPrevVal = 'true')      Or
         (LexPrevVal = 'false')     Or (LexPrevVal = 'super') Then
        LexASIFlag := True;
    TK_OP :
      If (LexPrevVal = '++') Or (LexPrevVal = '--') Then
        LexASIFlag := True;
    TK_PUNCT :
      If (LexPrevVal = ')') Or (LexPrevVal = ']') Then
        LexASIFlag := True;
  End;
End;

{ ---- LexSkipBlockComment : sauter le commentaire /* ... */ -- }
Procedure LexSkipBlockComment;
Var
  Done : Boolean;
Begin
  Inc(LexColNo); Inc(LexColNo); { sauter '/' et '*' }
  Done := False;
  While (Not LexEOF) And (Not Done) Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      LexNextLine;
    End
    Else If (LexLine[LexColNo] = '*') And
            (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      Done := True;
    End
    Else
      Inc(LexColNo);
  End;
End;

{ ---- Fonctions de test sur les caracteres ------------------- }
Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or
                  (Ch = '_') Or (Ch = '$');
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
  { Partie decimale .ddd }
  If (Base = 10) And (LexColNo <= Length(LexLine)) And
     (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And
     (LexLine[LexColNo + 1] >= '0') And (LexLine[LexColNo + 1] <= '9') Then
  Begin
    IsFloat := True;
    Inc(LexColNo); { sauter '.' }
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
          (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
    Begin
      ExpVal := ExpVal * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
      Inc(LexColNo);
    End;
  End;
  { Calculer la valeur finale (tronquee a entier 16 bits) }
  If IsFloat Then
  Begin
    FltVal := N + FracVal;
    While ExpVal > 0 Do
    Begin
      If NegExp Then FltVal := FltVal / 10.0
      Else            FltVal := FltVal * 10.0;
      Dec(ExpVal);
    End;
    If FltVal > 32767.0 Then N := 32767
    Else If FltVal < -32768.0 Then N := -32768
    Else N := Trunc(FltVal);
  End;
  CurToken.IntVal := N;
  Str(N, CurToken.Val);
  If IsFloat Then
    CurToken.Kind := TK_FLOAT
  Else
    CurToken.Kind := TK_INTEGER;
End;

{ ---- LexScanEscChar : traiter une sequence d'echappement --- }
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
    'b'        : LexScanEscChar := #8;
    'f'        : LexScanEscChar := #12;
    'v'        : LexScanEscChar := #11;
    '\'        : LexScanEscChar := '\';
    ''''       : LexScanEscChar := '''';
    '"'        : LexScanEscChar := '"';
    '`'        : LexScanEscChar := '`';
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
    'u', 'U'  :
    Begin
      V := 0;
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '{') Then
        Inc(LexColNo);
      While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
      Begin
        V := V * 16 + HexVal(LexLine[LexColNo]);
        Inc(LexColNo);
      End;
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '}') Then
        Inc(LexColNo);
      LexScanEscChar := Chr(V And $FF);
    End;
  Else
    LexScanEscChar := Ch;
  End;
End;

{ ---- LexScanString : chaine simple ou double quote --------- }
Procedure LexScanString(Quote : Char);
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
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
      If (Ch <> #0) And (Length(S) < MAX_STR) Then
        S := S + Ch;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexScanTemplate : template literal backtick ----------- }
Procedure LexScanTemplate;
Var
  S      : TString;
  Ch     : Char;
  Braces : Integer;
Begin
  S := '';
  Inc(LexColNo); { sauter backtick ouvrant }
  Braces := 0;
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      If Length(S) < MAX_STR Then S := S + #10;
      LexNextLine;
    End
    Else
    Begin
      Ch := LexLine[LexColNo];
      If (Ch = '`') And (Braces = 0) Then
      Begin
        Inc(LexColNo);
        Break;
      End
      Else If (Ch = '$') And (LexColNo < Length(LexLine)) And
              (LexLine[LexColNo + 1] = '{') Then
      Begin
        If Length(S) < MAX_STR Then S := S + '$';
        If Length(S) < MAX_STR Then S := S + '{';
        Inc(LexColNo); Inc(LexColNo);
        Inc(Braces);
      End
      Else If (Ch = '}') And (Braces > 0) Then
      Begin
        If Length(S) < MAX_STR Then S := S + '}';
        Inc(LexColNo);
        Dec(Braces);
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
  CurToken.Kind   := TK_TEMPLATE;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexScanRegexp : expression reguliere /pat/flags ------- }
Procedure LexScanRegexp;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo); { sauter '/' ouvrant }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '/' Then
    Begin
      Inc(LexColNo);
      Break;
    End
    Else If Ch = '\' Then
    Begin
      If Length(S) < MAX_STR Then S := S + '\';
      Inc(LexColNo);
      If LexColNo <= Length(LexLine) Then
      Begin
        If Length(S) < MAX_STR Then S := S + LexLine[LexColNo];
        Inc(LexColNo);
      End;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  { separateur Chr(1) entre pattern et flags }
  If Length(S) < MAX_STR Then S := S + Chr(1);
  { Flags : g i m s reconnus, autres -> avertissement }
  While (LexColNo <= Length(LexLine)) And IsIdentStart(LexLine[LexColNo]) Do
  Begin
    Ch := LexLine[LexColNo];
    If Length(S) < MAX_STR Then S := S + Ch;
    If Not LexRegexpFlagOk(Ch) Then
      WarnMsg('flag regexp inconnu: ' + Ch);
    Inc(LexColNo);
  End;
  CurToken.Kind   := TK_REGEXP;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexMake2 : retourner un operateur 2 chars et avancer -- }
{ (utilitaire interne, non Forward-declare car utilisee inline) }

{ ---- LexNextToken : scanner principal ----------------------- }
Procedure LexNextToken;
Var
  Ch, Ch2, Ch3 : Char;
  Scanning     : Boolean;
Begin
  CurToken.IntVal  := 0;
  CurToken.FloatVal := 0.0;

  { ASI en attente du saut de ligne precedent }
  If LexASIFlag Then
  Begin
    LexASIFlag    := False;
    CurToken.Kind := TK_PUNCT;
    CurToken.Val  := ';';
    CurToken.Line := LexLineNo;
    CurToken.Col  := 0;
    LexPrevKind   := TK_PUNCT;
    LexPrevVal    := ';';
    Exit;
  End;

  Scanning := True;
  While Scanning Do
  Begin
    { Avancer jusqu'a la prochaine ligne si on est en fin de ligne }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
    Begin
      LexCheckASI;
      LexNextLine;
      If LexASIFlag Then
      Begin
        LexASIFlag    := False;
        CurToken.Kind := TK_PUNCT;
        CurToken.Val  := ';';
        CurToken.Line := LexLineNo;
        CurToken.Col  := 0;
        LexPrevKind   := TK_PUNCT;
        LexPrevVal    := ';';
        Scanning      := False;
        Break;
      End;
    End;
    If Not Scanning Then Break;

    { Fin de fichier }
    If LexEOF Then
    Begin
      CurToken.Kind := TK_EOF;
      CurToken.Val  := '';
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      LexPrevKind   := TK_EOF;
      LexPrevVal    := '';
      Scanning      := False;
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

    { Commentaire // jusqu'a fin de ligne }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      LexCheckASI;
      LexColNo := Length(LexLine) + 1;
    End

    { Commentaire bloc /* ... */ }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      LexSkipBlockComment;
    End

    { Identificateur ou mot-cle }
    Else If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      LexPrevKind    := CurToken.Kind;
      LexPrevVal     := CurToken.Val;
      LexExpectRegex := (CurToken.Kind = TK_KEYWORD) And
                        ((CurToken.Val = 'return')     Or
                         (CurToken.Val = 'typeof')     Or
                         (CurToken.Val = 'delete')     Or
                         (CurToken.Val = 'void')       Or
                         (CurToken.Val = 'throw')      Or
                         (CurToken.Val = 'new')        Or
                         (CurToken.Val = 'in')         Or
                         (CurToken.Val = 'of')         Or
                         (CurToken.Val = 'instanceof'));
      Scanning := False;
    End

    { Nombre decimal }
    Else If (Ch >= '0') And (Ch <= '9') Then
    Begin
      LexScanNumber;
      LexPrevKind    := CurToken.Kind;
      LexPrevVal     := CurToken.Val;
      LexExpectRegex := False;
      Scanning       := False;
    End

    { Nombre .5 (point suivi de chiffre) }
    Else If (Ch = '.') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] >= '0') And
            (LexLine[LexColNo + 1] <= '9') Then
    Begin
      CurToken.Kind   := TK_FLOAT;
      CurToken.IntVal := 0;
      CurToken.Val    := '0';
      Inc(LexColNo);
      While (LexColNo <= Length(LexLine)) And
            (LexLine[LexColNo] >= '0') And
            (LexLine[LexColNo] <= '9') Do
        Inc(LexColNo);
      LexPrevKind    := TK_FLOAT;
      LexPrevVal     := '0';
      LexExpectRegex := False;
      Scanning       := False;
    End

    { Spread ... }
    Else If (Ch = '.') And (LexColNo + 2 <= Length(LexLine)) And
            (LexLine[LexColNo + 1] = '.') And
            (LexLine[LexColNo + 2] = '.') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '...';
      Inc(LexColNo); Inc(LexColNo); Inc(LexColNo);
      LexPrevKind    := TK_OP;
      LexPrevVal     := '...';
      LexExpectRegex := False;
      Scanning       := False;
    End

    { Acces propriete . }
    Else If Ch = '.' Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := '.';
      Inc(LexColNo);
      LexPrevKind    := TK_PUNCT;
      LexPrevVal     := '.';
      LexExpectRegex := False;
      Scanning       := False;
    End

    { Chaine simple-quote }
    Else If Ch = '''' Then
    Begin
      LexScanString('''');
      LexPrevKind    := TK_STRING;
      LexPrevVal     := '';
      LexExpectRegex := False;
      Scanning       := False;
    End

    { Chaine double-quote }
    Else If Ch = '"' Then
    Begin
      LexScanString('"');
      LexPrevKind    := TK_STRING;
      LexPrevVal     := '';
      LexExpectRegex := False;
      Scanning       := False;
    End

    { Template literal backtick }
    Else If Ch = '`' Then
    Begin
      { Detection tag template : ident immediatement suivi du backtick }
      If LexPrevKind = TK_IDENT Then
        WarnMsg('tag template non supporte, traite comme template literal');
      LexScanTemplate;
      LexPrevKind    := TK_TEMPLATE;
      LexPrevVal     := '';
      LexExpectRegex := False;
      Scanning       := False;
    End

    { = == === => }
    Else If Ch = '=' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '===';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '==';
        End;
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '>') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '=>';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '=';
      End;
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      LexExpectRegex := True;
      Scanning := False;
    End

    { ! != !== }
    Else If Ch = '!' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '!==';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '!=';
        End;
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '!';
      End;
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      LexExpectRegex := True;
      Scanning := False;
    End

    { < <= << <<= }
    Else If Ch = '<' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '<') Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '<<=';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '<<';
        End;
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '<=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '<';
      End;
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      LexExpectRegex := True;
      Scanning := False;
    End

    { > >= >> >>= >>> >>>= }
    Else If Ch = '>' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '>') Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '>') Then
        Begin
          Inc(LexColNo);
          If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
          Begin
            Inc(LexColNo);
            CurToken.Kind := TK_OP; CurToken.Val := '>>>=';
          End
          Else
          Begin
            CurToken.Kind := TK_OP; CurToken.Val := '>>>';
          End;
        End
        Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '>>=';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '>>';
        End;
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '>=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '>';
      End;
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      LexExpectRegex := True;
      Scanning := False;
    End

    { + ++ += }
    Else If Ch = '+' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '+') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '++';
        LexExpectRegex := False;
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '+=';
        LexExpectRegex := True;
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '+';
        LexExpectRegex := True;
      End;
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      Scanning := False;
    End

    { - -- -= }
    Else If Ch = '-' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '-') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '--';
        LexExpectRegex := False;
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '-=';
        LexExpectRegex := True;
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '-';
        LexExpectRegex := True;
      End;
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      Scanning := False;
    End

    { * ** *= **= }
    Else If Ch = '*' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '*') Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '**=';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '**';
        End;
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '*=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '*';
      End;
      LexExpectRegex := True;
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      Scanning := False;
    End

    { / /= regexp }
    Else If Ch = '/' Then
    Begin
      If LexExpectRegex Then
      Begin
        LexScanRegexp;
        LexPrevKind    := TK_REGEXP;
        LexPrevVal     := '';
        LexExpectRegex := False;
      End
      Else
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '/=';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '/';
        End;
        LexPrevKind    := TK_OP;
        LexPrevVal     := CurToken.Val;
        LexExpectRegex := True;
      End;
      Scanning := False;
    End

    { % %= }
    Else If Ch = '%' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '%=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '%';
      End;
      LexExpectRegex := True;
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      Scanning := False;
    End

    { & && &= &&= }
    Else If Ch = '&' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '&') Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '&&=';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '&&';
        End;
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '&=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '&';
      End;
      LexExpectRegex := True;
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      Scanning := False;
    End

    { | || |= ||= }
    Else If Ch = '|' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '|') Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '||=';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '||';
        End;
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '|=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '|';
      End;
      LexExpectRegex := True;
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      Scanning := False;
    End

    { ^ ^= }
    Else If Ch = '^' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '^=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '^';
      End;
      LexExpectRegex := True;
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      Scanning := False;
    End

    { ~ }
    Else If Ch = '~' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '~';
      LexExpectRegex := True;
      LexPrevKind := TK_OP; LexPrevVal := '~';
      Scanning := False;
    End

    { ? ?? ??= ?. }
    Else If Ch = '?' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '?') Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '??=';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '??';
        End;
        LexExpectRegex := True;
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '?.';
        LexExpectRegex := False;
      End
      Else
      Begin
        CurToken.Kind := TK_PUNCT; CurToken.Val := '?';
        LexExpectRegex := True;
      End;
      LexPrevKind := CurToken.Kind; LexPrevVal := CurToken.Val;
      Scanning := False;
    End

    { : }
    Else If Ch = ':' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := ':';
      LexExpectRegex := True;
      LexPrevKind := TK_PUNCT; LexPrevVal := ':';
      Scanning := False;
    End

    { Ponctuation simple }
    Else If (Ch = ';') Or (Ch = ',') Or (Ch = '(') Or (Ch = ')') Or
            (Ch = '[') Or (Ch = ']') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      LexPrevKind    := TK_PUNCT;
      LexPrevVal     := CurToken.Val;
      LexExpectRegex := (Ch = '(') Or (Ch = '[') Or
                        (Ch = ';') Or (Ch = ',');
      Scanning := False;
    End

    { Accolades ouvrantes et fermantes }
    Else If Ch = '{' Then
    Begin
      CurToken.Kind := TK_PUNCT; CurToken.Val := '{';
      Inc(LexColNo);
      LexPrevKind := TK_PUNCT; LexPrevVal := '{';
      LexExpectRegex := True;
      Scanning := False;
    End
    Else If Ch = '}' Then
    Begin
      CurToken.Kind := TK_PUNCT; CurToken.Val := '}';
      Inc(LexColNo);
      LexPrevKind := TK_PUNCT; LexPrevVal := '}';
      LexExpectRegex := False;
      Scanning := False;
    End

    { Caractere inconnu : ignorer avec avertissement }
    Else
    Begin
      WarnMsg('caractere inconnu: ' + Ch);
      Inc(LexColNo);
    End;

  End; { While Scanning }
End;

{ ============================================================
  LITTERAUX ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

{ LexRegexpFlagOk : valider un flag de regexp JS (g i m s u) }
Function LexRegexpFlagOk(Ch : Char) : Boolean;
Begin
  LexRegexpFlagOk := (Ch = 'g') Or (Ch = 'i') Or (Ch = 'm') Or
                     (Ch = 's') Or (Ch = 'u');
End;

{ LexCheckTagTemplate : avertir si backtick suit un identifiant (tag template) }
Procedure LexCheckTagTemplate;
Begin
  { Appele depuis LexNextToken avant LexScanTemplate }
  { La detection est deja faite dans LexNextToken via LexPrevKind }
  WarnMsg('tag template non supporte, traite comme template literal');
End;

{ ExprMakeImm : construire une valeur immediate }
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ExprMakeNone : expression sans valeur (void) }
Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ExprMakeNull : valeur null (AX=0, type null) }
Procedure ExprMakeNull(Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_NULL;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ExprMakeUndef : valeur undefined (AX=0, type undefined) }
Procedure ExprMakeUndef(Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_UNDEF;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ExprMakeBool : valeur booleenne (0 ou 1) }
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  If AVal <> 0 Then Res.ImmVal := 1 Else Res.ImmVal := 0;
  Res.TypeIdx := TY_IDX_BOOLEAN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ LitEval : evaluer un token litteral en TExprVal }
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Begin
  Case T.Kind Of
    TK_INTEGER :
      ExprMakeImm(T.IntVal, TY_IDX_NUMBER, Res);
    TK_FLOAT :
      ExprMakeImm(T.IntVal, TY_IDX_NUMBER, Res);  { IntVal = Trunc(float) }
    TK_STRING :
    Begin
      Res.Kind    := EK_AX;    { l'adresse data sera resolue plus tard }
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STRING;
      Res.Offset  := 0;
    End;
    TK_TEMPLATE :
    Begin
      Res.Kind    := EK_AX;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STRING;
      Res.Offset  := 0;
    End;
    TK_REGEXP :
    Begin
      Res.Kind    := EK_AX;    { pointeur vers objet RegExp DATA }
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_OBJECT;
      Res.Offset  := 0;
    End;
    TK_KEYWORD :
    Begin
      If T.Val = 'null' Then
        ExprMakeNull(Res)
      Else If T.Val = 'undefined' Then
        ExprMakeUndef(Res)
      Else If T.Val = 'true' Then
        ExprMakeBool(1, Res)
      Else If T.Val = 'false' Then
        ExprMakeBool(0, Res)
      Else
        ExprMakeNone(Res);
    End;
    TK_IDENT :
    Begin
      { NaN et Infinity sont techniquement des identifiants globaux }
      If T.Val = 'NaN' Then
      Begin
        WarnMsg('NaN non representable en 16 bits, traite comme 0');
        ExprMakeImm(0, TY_IDX_NUMBER, Res);
      End
      Else If T.Val = 'Infinity' Then
      Begin
        WarnMsg('Infinity non representable en 16 bits, traite comme 0');
        ExprMakeImm(0, TY_IDX_NUMBER, Res);
      End
      Else
        ExprMakeNone(Res);
    End;
  Else
    ExprMakeNone(Res);
  End;
End;

{ ============================================================
  OPERATEURS ET PRECEDENCE [IMPLEMENTE]
  ============================================================ }

{ BinOpPrec : priorite d'un operateur binaire (plus grand = plus serre, 0=aucun) }
Function IsAssignOp(Const Op : TString) : Boolean;
Begin
  IsAssignOp :=
    (Op = '=')    Or (Op = '+=')   Or (Op = '-=')  Or (Op = '*=')   Or
    (Op = '/=')   Or (Op = '%=')   Or (Op = '**=') Or (Op = '&=')   Or
    (Op = '|=')   Or (Op = '^=')  Or (Op = '<<=') Or (Op = '>>=')  Or
    (Op = '>>>=') Or (Op = '&&=') Or (Op = '||=') Or (Op = '??=');
End;

Function BinOpPrec(Const Op : TString) : Integer;
Begin
  If IsAssignOp(Op)    Then BinOpPrec := 2
  Else If Op = '?'     Then BinOpPrec := 3
  Else If Op = '??'    Then BinOpPrec := 4
  Else If Op = '||'    Then BinOpPrec := 5
  Else If Op = '&&'    Then BinOpPrec := 6
  Else If Op = '|'     Then BinOpPrec := 7
  Else If Op = '^'     Then BinOpPrec := 8
  Else If Op = '&'     Then BinOpPrec := 9
  Else If (Op = '==')  Or (Op = '!=') Or
          (Op = '===') Or (Op = '!==') Then BinOpPrec := 10
  Else If (Op = '<')   Or (Op = '<=') Or
          (Op = '>')   Or (Op = '>=') Or
          (Op = 'in')  Or (Op = 'instanceof') Then BinOpPrec := 11
  Else If (Op = '<<')  Or (Op = '>>') Or
          (Op = '>>>') Then BinOpPrec := 12
  Else If (Op = '+')   Or (Op = '-') Then BinOpPrec := 13
  Else If (Op = '*')   Or (Op = '/') Or (Op = '%') Then BinOpPrec := 14
  Else If Op = '**'    Then BinOpPrec := 15
  Else BinOpPrec := 0;
End;

Function BinOpIsRight(Const Op : TString) : Boolean;
Begin
  BinOpIsRight :=
    (Op = '**') Or IsAssignOp(Op);
End;

{ ============================================================
  EXPRESSIONS PRIMAIRES [IMPLEMENTE]
  ============================================================ }

{ ParseCallArgs : parse (e1, e2, ...) et PUSH chaque arg. Retourne ArgCount. }
Procedure ParseCallArgs(Var ArgCount : Integer);
Var
  Arg : TExprVal;
Begin
  ArgCount := 0;
  ParserAdvance; { consomme '(' }
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
  Begin
    { Spread argument : stub }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '...') Then
    Begin
      WarnMsg('spread dans appel de fonction : stub');
      ParserAdvance;
    End;
    ParseExprPrec(2, Arg); { precedence > virgule }
    ExprFlushToAX(Arg);
    EmitInstrA('PUSH', 'AX');
    Inc(ArgCount);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance
  Else
    CompileError('")" attendu apres les arguments');
End;

{ ParsePostfix : gere les operations postfixe : appel f(), membre .p, index [i] }
{ Intercepte console.log/error/warn, process.exit/stdout/stderr, alert, prompt }
Procedure ParsePostfix(Var Res : TExprVal);
Var
  ArgCount  : Integer;
  FnIdx     : Integer;
  PropName  : TString;
  IdxExpr   : TExprVal;
  LblArr    : TString;
  SymName   : TString;
  Arg       : TExprVal;
  FD        : Integer;
  SubProp   : TString;
  I         : Integer;
  StrLbl    : TString;
  ObjThisSaved : Boolean; { true si BX (this objet) empile }
Begin
  ObjThisSaved := False;
  While True Do
  Begin
    { ---- Appel de fonction : expr(...) ---- }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      FnIdx := Res.SymIdx;
      { Intercepter alert(s) et prompt(s) }
      If FnIdx >= 0 Then
        SymName := SymTab[FnIdx].Name
      Else
        SymName := '';
      If SymName = 'alert' Then
      Begin
        { alert(s) -> console.log(s) : affiche sur stdout + newline }
        ParserAdvance; { consomme '(' }
        I := 0;
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
        Begin
          If I > 0 Then EmitPrintSpace(1);
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          EmitPrintAX(Arg.TypeIdx);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          Inc(I);
        End;
        EmitPrintNewline(1);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_UNDEF;
        Res.SymIdx  := -1;
        Continue;
      End
      Else If SymName = 'prompt' Then
      Begin
        { prompt(s) -> stub : XOR AX,AX + warning }
        ParseCallArgs(ArgCount);
        WarnMsg('prompt() non supporte en environnement DOS, retourne undefined');
        EmitInstrAB('XOR', 'AX', 'AX');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_UNDEF;
        Res.SymIdx  := -1;
        Continue;
      End
      (* ---- Fonctions globales natives ---- *)
      Else If SymName = 'parseInt' Then
      Begin
        ParserAdvance; { consomme '(' }
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrAB('MOV', 'SI', 'AX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        Begin
          ParserAdvance;
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'CX', 'AX');
        End
        Else
          EmitInstrAB('MOV', 'CX', '10');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        EmitInstrA('CALL', '_JSRT_STRTOINT');
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_NUMBER; Res.SymIdx := -1;
        Continue;
      End
      Else If SymName = 'parseFloat' Then
      Begin
        ParserAdvance; { consomme '(' }
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrAB('MOV', 'CX', '10');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        EmitInstrA('CALL', '_JSRT_STRTOINT');
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_NUMBER; Res.SymIdx := -1;
        Continue;
      End
      Else If SymName = 'Number' Then
      Begin
        ParserAdvance; { consomme '(' }
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrAB('MOV', 'SI', 'AX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        EmitInstrA('CALL', '_JSRT_STRTONUM');
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_NUMBER; Res.SymIdx := -1;
        Continue;
      End
      Else If SymName = 'isNaN' Then
      Begin
        ParserAdvance; { consomme '(' }
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        EmitInstrAB('XOR', 'AX', 'AX'); { jamais NaN en 16 bits entier }
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_BOOLEAN; Res.SymIdx := -1;
        Continue;
      End
      Else If SymName = 'isFinite' Then
      Begin
        ParserAdvance; { consomme '(' }
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        EmitInstrAB('MOV', 'AX', '1'); { toujours fini en 16 bits entier }
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_BOOLEAN; Res.SymIdx := -1;
        Continue;
      End;
      { Appel de fonction standard }
      { Si methode objet, sauver le ptr de fn avant ParseCallArgs }
      If ObjThisSaved Then
        EmitInstrA('PUSH', 'AX');  { sauver fn ptr sur pile }
      ParseCallArgs(ArgCount);
      GCallArgCount := ArgCount;
      { Passer this pour les methodes d objet }
      If ObjThisSaved Then
      Begin
        EmitInstrA('PUSH', 'WORD PTR [_JSRT_OBJTMP]');
      End;
      If ObjThisSaved Then
      Begin
        { Restaurer fn ptr depuis la pile (sous les args + this) }
        EmitInstrAB('MOV', 'AX', '[SP+' + IntToStr((ArgCount + 1) * 2) + ']');
        EmitInstrA('CALL', 'AX');
      End
      Else If (FnIdx >= 0) And (SymTab[FnIdx].Cat = SC_FUNCTION) Then
        EmitInstrA('CALL', SymTab[FnIdx].MangledName)
      Else If FnIdx >= 0 Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrA('CALL', 'AX');
      End
      Else
      Begin
        ExprFlushToAX(Res);
        EmitInstrA('CALL', 'AX');
      End;
      { Nettoyage pile : args + this + fn_ptr si methode objet }
      If ObjThisSaved Then
      Begin
        { args + this + fn_ptr sauvegarde }
        EmitInstrAB('ADD', 'SP', IntToStr((ArgCount + 2) * 2));
        ObjThisSaved := False;
      End
      Else If ArgCount > 0 Then
        EmitInstrAB('ADD', 'SP', IntToStr(ArgCount * 2));
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_UNKNOWN;
      Res.SymIdx  := -1;
      Continue;
    End;

    { ---- Acces membre : expr.prop ---- }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
    Begin
      { Determiner le nom du symbole gauche (pour console/process) }
      If Res.SymIdx >= 0 Then
        SymName := SymTab[Res.SymIdx].Name
      Else
        SymName := '';

      ParserAdvance; { consomme '.' }
      If (CurToken.Kind <> TK_IDENT) And (CurToken.Kind <> TK_KEYWORD) Then
      Begin
        CompileError('identifiant attendu apres "."');
        Continue;
      End;
      PropName := CurToken.Val;
      ParserAdvance;

      { ---- console.log / console.error / console.warn ---- }
      If SymName = 'console' Then
      Begin
        If PropName = 'log' Then FD := 1
        Else If PropName = 'error' Then FD := 2
        Else If PropName = 'warn' Then FD := 2
        Else FD := -1;
        If FD > 0 Then
        Begin
          { Consommer (args) et emettre le code d'affichage inline }
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
          Begin
            CompileError('"(" attendu apres console.' + PropName);
            Continue;
          End;
          ParserAdvance; { consomme '(' }
          { Prefixe Warning: pour console.warn }
          If PropName = 'warn' Then
            EmitPrintStr('_JS_WARNPFX', FD);
          I := 0;
          While (CurToken.Kind <> TK_EOF) And
                Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
          Begin
            If I > 0 Then EmitPrintSpace(FD);
            ParseExprPrec(2, Arg);
            ExprFlushToAX(Arg);
            EmitPrintAXFD(Arg.TypeIdx, FD);
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
              ParserAdvance;
            Inc(I);
          End;
          EmitPrintNewline(FD);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
          Res.Kind    := EK_AX;
          Res.TypeIdx := TY_IDX_UNDEF;
          Res.SymIdx  := -1;
          Continue;
        End;
        { Autre propriete de console : stub }
        WarnMsg('console.' + PropName + ' non supporte : stub');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_UNKNOWN;
        Res.SymIdx  := -1;
        Continue;
      End;

      { ---- process.exit / process.stdout.write / process.stderr.write ---- }
      If SymName = 'process' Then
      Begin
        If PropName = 'exit' Then
        Begin
          { process.exit(code) -> MOV AH,4Ch + MOV AL,code + INT 21h }
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
          Begin
            CompileError('"(" attendu apres process.exit');
            Continue;
          End;
          ParserAdvance; { consomme '(' }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          Begin
            { process.exit() sans argument : code 0 }
            EmitInstrAB('MOV', 'AX', '4C00h');
          End
          Else
          Begin
            ParseExprPrec(2, Arg);
            ExprFlushToAX(Arg);
            EmitInstrAB('MOV', 'AH', '4Ch');
          End;
          EmitInstr('INT    21h');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
          Res.Kind    := EK_AX;
          Res.TypeIdx := TY_IDX_UNDEF;
          Res.SymIdx  := -1;
          Continue;
        End
        Else If (PropName = 'stdout') Or (PropName = 'stderr') Then
        Begin
          { process.stdout.write(s) / process.stderr.write(s) }
          If PropName = 'stdout' Then FD := 1
          Else FD := 2;
          { Attendre .write }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
          Begin
            ParserAdvance; { consomme '.' }
            If CurToken.Kind = TK_IDENT Then
            Begin
              SubProp := CurToken.Val;
              ParserAdvance;
            End
            Else
              SubProp := '';
            If SubProp = 'write' Then
            Begin
              If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
              Begin
                CompileError('"(" attendu apres process.' + PropName + '.write');
                Continue;
              End;
              ParserAdvance; { consomme '(' }
              I := 0;
              While (CurToken.Kind <> TK_EOF) And
                    Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
              Begin
                If I > 0 Then EmitPrintSpace(FD);
                ParseExprPrec(2, Arg);
                ExprFlushToAX(Arg);
                EmitPrintAXFD(Arg.TypeIdx, FD);
                If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
                  ParserAdvance;
                Inc(I);
              End;
              { Pas de newline pour write }
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                ParserAdvance;
              Res.Kind    := EK_AX;
              Res.TypeIdx := TY_IDX_UNDEF;
              Res.SymIdx  := -1;
              Continue;
            End
            Else
              WarnMsg('process.' + PropName + '.' + SubProp + ' non supporte');
          End;
          Res.Kind    := EK_AX;
          Res.TypeIdx := TY_UNKNOWN;
          Res.SymIdx  := -1;
          Continue;
        End;
        { Autre propriete de process : stub }
        WarnMsg('process.' + PropName + ' non supporte : stub');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_UNKNOWN;
        Res.SymIdx  := -1;
        Continue;
      End;

      { ---- Object.keys / Object.assign / Object.create ---- }
      If SymName = 'Object' Then
      Begin
        If PropName = 'keys' Then
        Begin
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
          Begin CompileError('"(" attendu apres Object.keys'); Continue; End;
          ParserAdvance;
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'BX', 'AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
          EmitInstrA('CALL', '_JSRT_OBJKEYS');
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_ARRAY; Res.SymIdx := -1;
        End
        Else If PropName = 'assign' Then
        Begin
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
          Begin CompileError('"(" attendu apres Object.assign'); Continue; End;
          ParserAdvance;
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          EmitInstrA('PUSH', 'AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrA('POP', 'BX');
          EmitInstrA('CALL', '_JSRT_OBJASSIGN');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_OBJECT; Res.SymIdx := -1;
        End
        Else If PropName = 'create' Then
        Begin
          WarnMsg('Object.create() : stub, retourne objet vide');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          Begin
            ParserAdvance;
            While (CurToken.Kind <> TK_EOF) And
                  Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
              ParserAdvance;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
          End;
          EmitInstrAB('XOR', 'AX', 'AX');
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_OBJECT; Res.SymIdx := -1;
        End
        Else
        Begin
          WarnMsg('Object.' + PropName + ' non supporte : stub');
          Res.Kind := EK_AX; Res.TypeIdx := TY_UNKNOWN; Res.SymIdx := -1;
        End;
        Continue;
      End;

      (* ---- Objet Math ---- *)
      If SymName = 'Math' Then
      Begin
        If PropName = 'abs' Then
        Begin
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
          Begin CompileError('"(" attendu apres Math.abs'); Continue; End;
          ParserAdvance;
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
          EmitInstrA('CALL', '_JSRT_ABS');
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_NUMBER; Res.SymIdx := -1;
        End
        Else If PropName = 'max' Then
        Begin
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
          Begin CompileError('"(" attendu apres Math.max'); Continue; End;
          ParserAdvance;
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          EmitInstrA('PUSH', 'AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          EmitInstrA('POP', 'BX');
          LblArr := LabelGen;
          EmitInstrAB('CMP', 'BX', 'AX');
          EmitInstrA('JLE', LblArr);
          EmitInstrAB('MOV', 'AX', 'BX');
          EmitLabel(LblArr);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_NUMBER; Res.SymIdx := -1;
        End
        Else If PropName = 'min' Then
        Begin
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
          Begin CompileError('"(" attendu apres Math.min'); Continue; End;
          ParserAdvance;
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          EmitInstrA('PUSH', 'AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          EmitInstrA('POP', 'BX');
          LblArr := LabelGen;
          EmitInstrAB('CMP', 'BX', 'AX');
          EmitInstrA('JGE', LblArr);
          EmitInstrAB('MOV', 'AX', 'BX');
          EmitLabel(LblArr);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_NUMBER; Res.SymIdx := -1;
        End
        Else If (PropName = 'floor') Or (PropName = 'ceil') Or
                (PropName = 'round') Or (PropName = 'trunc') Then
        Begin
          { Entier 16 bits -> pass-through }
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
          Begin CompileError('"(" attendu apres Math.' + PropName); Continue; End;
          ParserAdvance;
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_NUMBER; Res.SymIdx := -1;
        End
        Else If PropName = 'pow' Then
        Begin
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
          Begin CompileError('"(" attendu apres Math.pow'); Continue; End;
          ParserAdvance;
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          EmitInstrA('PUSH', 'AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'BX', 'AX');
          EmitInstrA('POP', 'AX');
          EmitInstrA('CALL', '_JSRT_POW');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_NUMBER; Res.SymIdx := -1;
        End
        Else If PropName = 'sqrt' Then
        Begin
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
          Begin CompileError('"(" attendu apres Math.sqrt'); Continue; End;
          ParserAdvance;
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
          EmitInstrA('CALL', '_JSRT_SQRT');
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_NUMBER; Res.SymIdx := -1;
        End
        Else If PropName = 'random' Then
        Begin
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          Begin
            ParserAdvance;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
          End;
          EmitInstrA('CALL', '_JSRT_RAND');
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_NUMBER; Res.SymIdx := -1;
        End
        Else If PropName = 'sign' Then
        Begin
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
          Begin CompileError('"(" attendu apres Math.sign'); Continue; End;
          ParserAdvance;
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
          EmitInstrA('CALL', '_JSRT_SIGN');
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_NUMBER; Res.SymIdx := -1;
        End
        Else If PropName = 'PI' Then
        Begin
          WarnMsg('Math.PI tronque a 3 (entier 16 bits)');
          EmitInstrAB('MOV', 'AX', '3');
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_NUMBER; Res.SymIdx := -1;
        End
        Else
        Begin
          WarnMsg('Math.' + PropName + ' non supporte : stub');
          EmitInstrAB('XOR', 'AX', 'AX');
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_NUMBER; Res.SymIdx := -1;
        End;
        Continue;
      End;

      (* ---- Objet Number ---- *)
      If SymName = 'Number' Then
      Begin
        If PropName = 'isInteger' Then
        Begin
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
          Begin CompileError('"(" attendu apres Number.isInteger'); Continue; End;
          ParserAdvance;
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
          EmitInstrAB('MOV', 'AX', '1'); { tous les nombres sont entiers }
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_BOOLEAN; Res.SymIdx := -1;
        End
        Else
        Begin
          WarnMsg('Number.' + PropName + ' non supporte : stub');
          EmitInstrAB('XOR', 'AX', 'AX');
          Res.Kind := EK_AX; Res.TypeIdx := TY_UNKNOWN; Res.SymIdx := -1;
        End;
        Continue;
      End;

      (* ---- Objet String ---- *)
      If SymName = 'String' Then
      Begin
        If PropName = 'fromCharCode' Then
        Begin
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
          Begin CompileError('"(" attendu apres String.fromCharCode'); Continue; End;
          ParserAdvance;
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
          EmitInstrA('CALL', '_JSRT_CHR');
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_STRING; Res.SymIdx := -1;
        End
        Else
        Begin
          WarnMsg('String.' + PropName + ' non supporte : stub');
          EmitInstrAB('XOR', 'AX', 'AX');
          Res.Kind := EK_AX; Res.TypeIdx := TY_UNKNOWN; Res.SymIdx := -1;
        End;
        Continue;
      End;

      (* ---- Objet JSON ---- *)
      If SymName = 'JSON' Then
      Begin
        If PropName = 'stringify' Then
        Begin
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
          Begin CompileError('"(" attendu apres JSON.stringify'); Continue; End;
          ParserAdvance;
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
          EmitInstrA('CALL', '_JSRT_JSONSTR');
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_STRING; Res.SymIdx := -1;
        End
        Else If PropName = 'parse' Then
        Begin
          WarnMsg('JSON.parse() : stub, retourne 0');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          Begin
            ParserAdvance;
            While (CurToken.Kind <> TK_EOF) And
                  Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
              ParserAdvance;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
          End;
          EmitInstrAB('XOR', 'AX', 'AX');
          Res.Kind := EK_AX; Res.TypeIdx := TY_UNKNOWN; Res.SymIdx := -1;
        End
        Else
        Begin
          WarnMsg('JSON.' + PropName + ' non supporte : stub');
          EmitInstrAB('XOR', 'AX', 'AX');
          Res.Kind := EK_AX; Res.TypeIdx := TY_UNKNOWN; Res.SymIdx := -1;
        End;
        Continue;
      End;

      { ---- Proprietes speciales generiques ---- }
      { ---- Proprietes / methodes de tableau + string ---- }
      If PropName = 'length' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        If Res.TypeIdx = TY_IDX_STRING Then
          EmitInstrA('CALL', '_JSRT_STRLEN')
        Else
          EmitInstrAB('MOV', 'AX', '[SI]');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_NUMBER;
        Res.SymIdx  := -1;
      End
      Else If PropName = 'push' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('PUSH', 'SI');
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
        Begin CompileError('"(" attendu apres .push'); Continue; End;
        ParserAdvance;
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrA('POP', 'SI');
        EmitInstrA('CALL', '_JSRT_ARRPUSH');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_NUMBER; Res.SymIdx := -1;
      End
      Else If PropName = 'pop' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('CALL', '_JSRT_ARRPOP');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX; Res.TypeIdx := TY_UNKNOWN; Res.SymIdx := -1;
      End
      Else If PropName = 'shift' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('CALL', '_JSRT_ARRSHIFT');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX; Res.TypeIdx := TY_UNKNOWN; Res.SymIdx := -1;
      End
      Else If PropName = 'unshift' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('PUSH', 'SI');
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
        Begin CompileError('"(" attendu apres .unshift'); Continue; End;
        ParserAdvance;
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrA('POP', 'SI');
        EmitInstrA('CALL', '_JSRT_ARRUNSHIFT');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_NUMBER; Res.SymIdx := -1;
      End
      Else If PropName = 'indexOf' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('PUSH', 'SI');
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
        Begin CompileError('"(" attendu apres .indexOf'); Continue; End;
        ParserAdvance;
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        If Res.TypeIdx = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'DI', 'AX');
          EmitInstrA('POP', 'SI');
          EmitInstrA('CALL', '_JSRT_STRINDEXOF');
        End
        Else
        Begin
          EmitInstrAB('MOV', 'BX', 'AX');
          EmitInstrA('POP', 'SI');
          EmitInstrA('CALL', '_JSRT_ARRIDXOF');
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_NUMBER; Res.SymIdx := -1;
      End
      Else If PropName = 'reverse' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('CALL', '_JSRT_ARRREV');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_ARRAY; Res.SymIdx := -1;
      End
      Else If PropName = 'sort' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('CALL', '_JSRT_ARRSORT');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          { Ignorer le comparateur s il y en a un }
          While (CurToken.Kind <> TK_EOF) And
                Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
            ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_ARRAY; Res.SymIdx := -1;
      End
      Else If PropName = 'join' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('PUSH', 'SI');
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
        Begin CompileError('"(" attendu apres .join'); Continue; End;
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        Begin
          { join() sans argument -> separateur virgule }
          StrLbl := DataAddStr(',');
          EmitInstrAB('LEA', 'DI', StrLbl);
          ParserAdvance;
        End
        Else
        Begin
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'DI', 'AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('POP', 'SI');
        EmitInstrA('CALL', '_JSRT_ARRJOIN');
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_STRING; Res.SymIdx := -1;
      End
      Else If PropName = 'forEach' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrA('PUSH', 'AX');
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
        Begin CompileError('"(" attendu apres .forEach'); Continue; End;
        ParserAdvance;
        If CurToken.Kind = TK_IDENT Then
        Begin
          SymName := CurToken.Val;
          ParserAdvance;
        End
        Else
          SymName := '';
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        EmitInstrA('POP', 'SI');
        If SymName <> '' Then
        Begin
          FnIdx := SymFind(SymName);
          LblArr := LabelGen;
          SubProp := LabelGen;
          EmitInstrAB('MOV', 'CX', '[SI]');
          EmitInstrAB('ADD', 'SI', '2');
          EmitLabel(LblArr);
          EmitInstrAB('OR', 'CX', 'CX');
          EmitInstrA('JZ', SubProp);
          EmitInstrA('PUSH', 'CX');
          EmitInstrA('PUSH', 'SI');
          EmitInstrAB('MOV', 'AX', '[SI]');
          EmitInstrA('PUSH', 'AX');
          If (FnIdx >= 0) And (SymTab[FnIdx].Cat = SC_FUNCTION) Then
            EmitInstrA('CALL', SymTab[FnIdx].MangledName)
          Else
            EmitInstrA('CALL', JS_FN_PFX + SymName);
          EmitInstrAB('ADD', 'SP', '2');
          EmitInstrA('POP', 'SI');
          EmitInstrA('POP', 'CX');
          EmitInstrAB('ADD', 'SI', '2');
          EmitInstrA('DEC', 'CX');
          EmitInstrA('JMP', LblArr);
          EmitLabel(SubProp);
        End
        Else
          WarnMsg('forEach sans callback identifiee : stub');
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_UNDEF; Res.SymIdx := -1;
      End
      Else If (PropName = 'map') Or (PropName = 'filter') Then
      Begin
        ExprFlushToAX(Res);
        WarnMsg(PropName + '() non supporte, retourne tableau original');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          While (CurToken.Kind <> TK_EOF) And
                Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
            ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_ARRAY; Res.SymIdx := -1;
      End
      Else If PropName = 'slice' Then
      Begin
        ExprFlushToAX(Res);
        If Res.TypeIdx = TY_IDX_STRING Then
        Begin
          { s.slice(a, b) -> _JSRT_STRSLICE(SI, BX=start, CX=end) }
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrA('PUSH', 'SI');
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
          Begin CompileError('"(" attendu apres .slice'); Continue; End;
          ParserAdvance;
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'BX', 'AX'); { BX = start }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          Begin
            ParserAdvance;
            ParseExprPrec(2, Arg);
            ExprFlushToAX(Arg);
            EmitInstrAB('MOV', 'CX', 'AX'); { CX = end }
          End
          Else
            EmitInstrAB('MOV', 'CX', '7FFFh'); { end = max }
          EmitInstrA('POP', 'SI');
          EmitInstrA('CALL', '_JSRT_STRSLICE');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_STRING; Res.SymIdx := -1;
        End
        Else
        Begin
          WarnMsg('slice() sur tableau : stub, retourne tableau original');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          Begin
            ParserAdvance;
            While (CurToken.Kind <> TK_EOF) And
                  Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
              ParserAdvance;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
          End;
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_ARRAY; Res.SymIdx := -1;
        End;
      End
      (* ---- Methodes RegExp : re.test(str), re.exec(str) ---- *)
      Else If PropName = 'test' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'DI', 'AX');  { DI = ptr pattern regexp }
        EmitInstrA('PUSH', 'DI');
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
        Begin CompileError('"(" attendu apres .test'); Continue; End;
        ParserAdvance;
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrAB('MOV', 'SI', 'AX');  { SI = ptr string }
        EmitInstrA('POP', 'DI');
        EmitInstrA('CALL', '_JSRT_REMATCH');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_BOOLEAN; Res.SymIdx := -1;
      End
      Else If PropName = 'exec' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'DI', 'AX');  { DI = ptr regexp }
        EmitInstrA('PUSH', 'DI');
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
        Begin CompileError('"(" attendu apres .exec'); Continue; End;
        ParserAdvance;
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrAB('MOV', 'SI', 'AX');  { SI = ptr string }
        EmitInstrA('POP', 'DI');
        EmitInstrA('CALL', '_JSRT_REEXEC');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_ARRAY; Res.SymIdx := -1;
      End
      (* ---- Methodes String sur regexp : .match .search .replace .split ---- *)
      Else If PropName = 'match' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');  { SI = ptr string }
        EmitInstrA('PUSH', 'SI');
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
        Begin CompileError('"(" attendu apres .match'); Continue; End;
        ParserAdvance;
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrAB('MOV', 'DI', 'AX');  { DI = ptr regexp/string }
        EmitInstrA('POP', 'SI');
        EmitInstrA('CALL', '_JSRT_REMATCH');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_BOOLEAN; Res.SymIdx := -1;
      End
      Else If PropName = 'search' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');  { SI = ptr string }
        EmitInstrA('PUSH', 'SI');
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
        Begin CompileError('"(" attendu apres .search'); Continue; End;
        ParserAdvance;
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrAB('MOV', 'DI', 'AX');  { DI = ptr regexp/string }
        EmitInstrA('POP', 'SI');
        EmitInstrA('CALL', '_JSRT_REINDEX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_NUMBER; Res.SymIdx := -1;
      End
      Else If PropName = 'replace' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');  { SI = ptr string }
        EmitInstrA('PUSH', 'SI');
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
        Begin CompileError('"(" attendu apres .replace'); Continue; End;
        ParserAdvance;
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrA('PUSH', 'AX');  { sauver pattern }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          ParserAdvance;
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrAB('MOV', 'BX', 'AX');  { BX = ptr replacement }
        EmitInstrA('POP', 'DI');          { DI = ptr pattern }
        EmitInstrA('POP', 'SI');          { SI = ptr string }
        EmitInstrA('CALL', '_JSRT_RESUB');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_STRING; Res.SymIdx := -1;
      End
      Else If PropName = 'split' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');  { SI = ptr string }
        EmitInstrA('PUSH', 'SI');
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
        Begin CompileError('"(" attendu apres .split'); Continue; End;
        ParserAdvance;
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
        Begin
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'DI', 'AX'); { DI = ptr separateur }
        End
        Else
        Begin
          StrLbl := DataAddStr(',');
          EmitInstrAB('LEA', 'DI', StrLbl); { separateur virgule par defaut }
        End;
        EmitInstrA('POP', 'SI');
        EmitInstrA('CALL', '_JSRT_STRSPLIT');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_ARRAY; Res.SymIdx := -1;
      End
      (* ---- Methodes String natives ---- *)
      Else If PropName = 'charAt' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('PUSH', 'SI');
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
        Begin CompileError('"(" attendu apres .charAt'); Continue; End;
        ParserAdvance;
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrAB('MOV', 'CX', 'AX');
        EmitInstrA('POP', 'SI');
        EmitInstrA('CALL', '_JSRT_STRCHAR');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_STRING; Res.SymIdx := -1;
      End
      Else If PropName = 'charCodeAt' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('PUSH', 'SI');
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
        Begin CompileError('"(" attendu apres .charCodeAt'); Continue; End;
        ParserAdvance;
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrAB('MOV', 'CX', 'AX');
        EmitInstrA('POP', 'SI');
        EmitInstrA('CALL', '_JSRT_STRORD');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_NUMBER; Res.SymIdx := -1;
      End
      Else If PropName = 'toUpperCase' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
        End;
        EmitInstrA('CALL', '_JSRT_STRTOUPPER');
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_STRING; Res.SymIdx := -1;
      End
      Else If PropName = 'toLowerCase' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
        End;
        EmitInstrA('CALL', '_JSRT_STRTOLOWER');
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_STRING; Res.SymIdx := -1;
      End
      Else If PropName = 'trim' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
        End;
        EmitInstrA('CALL', '_JSRT_STRTRIM');
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_STRING; Res.SymIdx := -1;
      End
      Else If PropName = 'lastIndexOf' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('PUSH', 'SI');
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
        Begin CompileError('"(" attendu apres .lastIndexOf'); Continue; End;
        ParserAdvance;
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrAB('MOV', 'DI', 'AX');
        EmitInstrA('POP', 'SI');
        EmitInstrA('CALL', '_JSRT_STRLASTIDX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_NUMBER; Res.SymIdx := -1;
      End
      Else If PropName = 'includes' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('PUSH', 'SI');
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
        Begin CompileError('"(" attendu apres .includes'); Continue; End;
        ParserAdvance;
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrAB('MOV', 'DI', 'AX');
        EmitInstrA('POP', 'SI');
        EmitInstrA('CALL', '_JSRT_STRINDEXOF');
        { AX = index ou -1 -> convertir en booleen : AX != -1 }
        LblArr := LabelGen;
        SubProp := LabelGen;
        EmitInstrAB('CMP', 'AX', '0FFFFh');
        EmitInstrA('JE', LblArr);
        EmitInstrAB('MOV', 'AX', '1');
        EmitInstrA('JMP', SubProp);
        EmitLabel(LblArr);
        EmitInstrAB('XOR', 'AX', 'AX');
        EmitLabel(SubProp);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_BOOLEAN; Res.SymIdx := -1;
      End
      Else If PropName = 'startsWith' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('PUSH', 'SI');
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
        Begin CompileError('"(" attendu apres .startsWith'); Continue; End;
        ParserAdvance;
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrAB('MOV', 'DI', 'AX');
        EmitInstrA('POP', 'SI');
        EmitInstrA('CALL', '_JSRT_STRSTARTW');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_BOOLEAN; Res.SymIdx := -1;
      End
      Else If PropName = 'endsWith' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('PUSH', 'SI');
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
        Begin CompileError('"(" attendu apres .endsWith'); Continue; End;
        ParserAdvance;
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrAB('MOV', 'DI', 'AX');
        EmitInstrA('POP', 'SI');
        EmitInstrA('CALL', '_JSRT_STRENDW');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_BOOLEAN; Res.SymIdx := -1;
      End
      Else If PropName = 'substring' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('PUSH', 'SI');
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
        Begin CompileError('"(" attendu apres .substring'); Continue; End;
        ParserAdvance;
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrAB('MOV', 'BX', 'AX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        Begin
          ParserAdvance;
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'CX', 'AX');
        End
        Else
          EmitInstrAB('MOV', 'CX', '7FFFh');
        EmitInstrA('POP', 'SI');
        EmitInstrA('CALL', '_JSRT_STRSLICE');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_STRING; Res.SymIdx := -1;
      End
      Else If PropName = 'repeat' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('PUSH', 'SI');
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
        Begin CompileError('"(" attendu apres .repeat'); Continue; End;
        ParserAdvance;
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrAB('MOV', 'CX', 'AX');
        EmitInstrA('POP', 'SI');
        EmitInstrAB('LEA', 'DI', '_JSRT_STRBUF');
        EmitInstrA('CALL', '_JSRT_STRREPEAT');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_STRING; Res.SymIdx := -1;
      End
      Else If PropName = 'padStart' Then
      Begin
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('PUSH', 'SI');
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
        Begin CompileError('"(" attendu apres .padStart'); Continue; End;
        ParserAdvance;
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrAB('MOV', 'CX', 'AX'); { CX = target length }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        Begin
          ParserAdvance;
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'DI', 'AX'); { DI = pad string }
        End
        Else
        Begin
          StrLbl := DataAddStr(' ');
          EmitInstrAB('LEA', 'DI', StrLbl); { defaut = espace }
        End;
        EmitInstrA('POP', 'SI');
        EmitInstrA('CALL', '_JSRT_STRPADS');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_STRING; Res.SymIdx := -1;
      End
      Else
      Begin
        { ---- Acces / affectation propriete objet generique ---- }
        ExprFlushToAX(Res);
        StrLbl := DataAddStr(PropName);
        If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
        Begin
          { obj.prop = val -> _JSRT_OBJSET(BX=ptr, DI=kptr, AX=val) }
          ParserAdvance; { consomme '=' }
          EmitInstrA('PUSH', 'AX');
          ParseExprPrec(2, Arg);
          ExprFlushToAX(Arg);
          EmitInstrA('POP', 'BX');
          EmitInstrAB('LEA', 'DI', StrLbl);
          EmitInstrA('CALL', '_JSRT_OBJSET');
          Res.Kind    := EK_AX;
          Res.TypeIdx := Arg.TypeIdx;
          Res.SymIdx  := -1;
        End
        Else
        Begin
          { obj.prop -> _JSRT_OBJGET(BX=ptr, DI=kptr) -> AX }
          EmitInstrAB('MOV', 'BX', 'AX');
          EmitInstrAB('LEA', 'DI', StrLbl);
          EmitInstrA('CALL', '_JSRT_OBJGET');
          { Si suivi de ( -> appel de methode, sauver this dans tmp }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          Begin
            EmitInstrAB('MOV', '[_JSRT_OBJTMP]', 'BX');
            ObjThisSaved := True;
          End;
          Res.Kind    := EK_AX;
          Res.TypeIdx := TY_UNKNOWN;
          Res.SymIdx  := -1;
        End;
      End;
      Continue;
    End;

    { ---- Optional chaining : expr?.prop ---- }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '?.') Then
    Begin
      ParserAdvance;
      If CurToken.Kind = TK_IDENT Then
        ParserAdvance
      Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        { expr?.(args) - appel optionnel }
      End
      Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
      Begin
        { expr?.[idx] - index optionnel }
      End;
      WarnMsg('?. (optional chaining) : stub');
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_UNKNOWN;
      Res.SymIdx  := -1;
      Continue;
    End;

    { ---- Acces index : expr[idx] / affectation arr[idx]=expr ---- }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
    Begin
      ParserAdvance; { consomme '[' }
      ExprFlushToAX(Res);
      EmitInstrA('PUSH', 'AX');
      ParseExpr(IdxExpr);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
        ParserAdvance
      Else
        CompileError('"]" attendu apres l''index');
      ExprFlushToAX(IdxExpr);
      EmitInstrAB('SHL', 'AX', '1');
      EmitInstrAB('ADD', 'AX', '2');
      EmitInstrAB('MOV', 'SI', 'AX');
      EmitInstrA('POP', 'BX');
      EmitInstrAB('ADD', 'SI', 'BX');
      { Verifier si c est une affectation arr[i] = expr }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
      Begin
        ParserAdvance; { consomme '=' }
        EmitInstrA('PUSH', 'SI');
        ParseExprPrec(2, Arg);
        ExprFlushToAX(Arg);
        EmitInstrA('POP', 'SI');
        EmitInstrAB('MOV', '[SI]', 'AX');
        Res.Kind    := EK_AX;
        Res.TypeIdx := Arg.TypeIdx;
        Res.SymIdx  := -1;
      End
      Else
      Begin
        EmitInstrAB('MOV', 'AX', '[SI]');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_UNKNOWN;
        Res.SymIdx  := -1;
      End;
      Continue;
    End;

    { ---- Template tag : expr`tmpl` (non supporte) ---- }
    If CurToken.Kind = TK_TEMPLATE Then
    Begin
      WarnMsg('tagged template : stub');
      ParserAdvance;
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_STRING;
      Res.SymIdx  := -1;
      Continue;
    End;

    Break; { aucun postfixe reconnu -> sortir }
  End;
End;

{ ParsePrimary : evaluer un token primaire }
Procedure ParsePrimary(Var Res : TExprVal);
Var
  StrLbl      : TString;
  ArrLbl      : TString;
  ObjLbl      : TString;
  ElemRes     : TExprVal;
  ElemCnt     : Integer;
  FnIdx       : Integer;
  ArgCount    : Integer;
  CtorName    : TString;
  I           : Integer;
  ObjKeyLbls  : Array[0..15] Of TString;
  ObjValImm   : Array[0..15] Of LongInt;
  ObjValIsImm : Array[0..15] Of Boolean;
  SavedLex    : TLexState;
  IsArrowOk   : Boolean;
  RegPat      : TString;    { pattern regexp }
  RegFlags    : TString;    { flags regexp   }
  RegSep      : Integer;    { position du Chr(1) separateur }
  RegI        : Integer;    { index boucle regexp }
  SuperMethod : TString;    { nom methode parent }
  SaveThis    : Integer;    { sauvegarde CurMethodThis }
Begin
  Case CurToken.Kind Of

    { ---- Litteraux numeriques ---- }
    TK_INTEGER, TK_FLOAT :
    Begin
      LitEval(CurToken, Res);
      ParserAdvance;
    End;

    { ---- Litteral chaine ---- }
    TK_STRING :
    Begin
      StrLbl := DataAddStr(CurToken.Val);
      EmitInstrAB('LEA', 'AX', StrLbl);
      Res.Kind    := EK_AX;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STRING;
      Res.Offset  := 0;
      Res.SymIdx  := -1;
      ParserAdvance;
    End;

    { ---- Template literal ---- }
    TK_TEMPLATE :
    Begin
      StrLbl := DataAddStr(CurToken.Val);
      EmitInstrAB('LEA', 'AX', StrLbl);
      Res.Kind    := EK_AX;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STRING;
      Res.Offset  := 0;
      Res.SymIdx  := -1;
      ParserAdvance;
    End;

    { ---- Regexp literal ---- }
    TK_REGEXP :
    Begin
      (* Analyser le pattern pour metacaracteres et captures *)
      RegPat := '';
      RegFlags := '';
      RegSep := Pos(Chr(1), CurToken.Val);
      If RegSep > 0 Then
      Begin
        RegPat   := Copy(CurToken.Val, 1, RegSep - 1);
        RegFlags := Copy(CurToken.Val, RegSep + 1,
                         Length(CurToken.Val) - RegSep);
      End
      Else
        RegPat := CurToken.Val;
      (* Avertir si metacaracteres non supportes *)
      For RegI := 1 To Length(RegPat) Do
      Begin
        If (RegPat[RegI] = '.') Or (RegPat[RegI] = '^') Or
           (RegPat[RegI] = '$') Or (RegPat[RegI] = '*') Or
           (RegPat[RegI] = '+') Or (RegPat[RegI] = '?') Or
           (RegPat[RegI] = '[') Or (RegPat[RegI] = ']') Or
           (RegPat[RegI] = '{') Or (RegPat[RegI] = '}') Or
           (RegPat[RegI] = '|') Then
        Begin
          WarnMsg('regexp metacaractere "' + RegPat[RegI] +
                  '" non supporte : recherche litterale');
          Break;
        End;
        If (RegPat[RegI] = '(') Then
        Begin
          WarnMsg('regexp captures non supportees : stub');
          Break;
        End;
      End;
      (* Avertir pour flags speciaux *)
      For RegI := 1 To Length(RegFlags) Do
      Begin
        If RegFlags[RegI] = 'i' Then
          WarnMsg('flag /i (case-insensitive) : non supporte, ignore')
        Else If (RegFlags[RegI] = 'm') Or (RegFlags[RegI] = 's') Or
                (RegFlags[RegI] = 'u') Then
          WarnMsg('flag /' + RegFlags[RegI] + ' : non supporte, ignore');
      End;
      StrLbl := DataAddStr(CurToken.Val);
      EmitInstrAB('LEA', 'AX', StrLbl);
      Res.Kind    := EK_AX;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_OBJECT;
      Res.Offset  := 0;
      Res.SymIdx  := -1;
      ParserAdvance;
    End;

    { ---- Mots-cles (valeurs) ---- }
    TK_KEYWORD :
    Begin
      If CurToken.Val = 'null' Then
      Begin
        ExprMakeNull(Res);
        EmitInstrAB('XOR', 'AX', 'AX');
        ParserAdvance;
      End
      Else If CurToken.Val = 'undefined' Then
      Begin
        ExprMakeUndef(Res);
        EmitInstrAB('XOR', 'AX', 'AX');
        ParserAdvance;
      End
      Else If CurToken.Val = 'true' Then
      Begin
        ExprMakeBool(1, Res);
        ParserAdvance;
      End
      Else If CurToken.Val = 'false' Then
      Begin
        ExprMakeBool(0, Res);
        ParserAdvance;
      End
      Else If CurToken.Val = 'this' Then
      Begin
        If CurMethodThis > 0 Then
        Begin
          { Dans une methode de classe : this = param cache }
          EmitInstrAB('MOV', 'AX', '[BP+' + IntToStr(CurMethodThis) + ']');
        End
        Else
        Begin
          WarnMsg('this : contexte global, traite comme 0');
          EmitInstrAB('XOR', 'AX', 'AX');
        End;
        Res.Kind    := EK_AX;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_OBJECT;
        Res.Offset  := 0;
        Res.SymIdx  := -1;
        ParserAdvance;
      End
      Else If CurToken.Val = 'super' Then
      Begin
        { super() -> appel constructeur parent }
        { super.method() -> appel methode parent }
        ParserAdvance; { consomme 'super' }
        If CurParentClass = '' Then
        Begin
          WarnMsg('super utilise hors d''une classe derivee');
          EmitInstrAB('XOR', 'AX', 'AX');
          Res.Kind    := EK_AX;
          Res.ImmVal  := 0;
          Res.TypeIdx := TY_IDX_OBJECT;
          Res.Offset  := 0;
          Res.SymIdx  := -1;
        End
        Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          { super(args) -> PUSH this, push args, CALL _JSF_Parent_ctor }
          ParseCallArgs(ArgCount);
          If CurMethodThis > 0 Then
          Begin
            EmitInstrAB('MOV', 'AX', '[BP+' + IntToStr(CurMethodThis) + ']');
            EmitInstrA('PUSH', 'AX');
            EmitInstrA('CALL', JS_FN_PFX + CurParentClass + '_ctor');
            EmitInstrAB('ADD', 'SP', IntToStr((ArgCount + 1) * 2));
          End
          Else
          Begin
            EmitInstrA('CALL', JS_FN_PFX + CurParentClass + '_ctor');
            If ArgCount > 0 Then
              EmitInstrAB('ADD', 'SP', IntToStr(ArgCount * 2));
          End;
          Res.Kind    := EK_AX;
          Res.ImmVal  := 0;
          Res.TypeIdx := TY_IDX_UNDEF;
          Res.Offset  := 0;
          Res.SymIdx  := -1;
        End
        Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
        Begin
          { super.method(args) }
          ParserAdvance; { consomme '.' }
          If CurToken.Kind = TK_IDENT Then
          Begin
            SuperMethod := CurToken.Val;
            ParserAdvance;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
            Begin
              ParseCallArgs(ArgCount);
              If CurMethodThis > 0 Then
              Begin
                EmitInstrAB('MOV', 'AX', '[BP+' + IntToStr(CurMethodThis) + ']');
                EmitInstrA('PUSH', 'AX');
                EmitInstrA('CALL', JS_FN_PFX + CurParentClass + '_' + SuperMethod);
                EmitInstrAB('ADD', 'SP', IntToStr((ArgCount + 1) * 2));
              End
              Else
              Begin
                EmitInstrA('CALL', JS_FN_PFX + CurParentClass + '_' + SuperMethod);
                If ArgCount > 0 Then
                  EmitInstrAB('ADD', 'SP', IntToStr(ArgCount * 2));
              End;
            End
            Else
            Begin
              { super.prop sans appel }
              WarnMsg('super.' + SuperMethod + ' sans appel : stub');
              EmitInstrAB('XOR', 'AX', 'AX');
            End;
          End
          Else
          Begin
            CompileError('identifiant attendu apres super.');
            EmitInstrAB('XOR', 'AX', 'AX');
          End;
          Res.Kind    := EK_AX;
          Res.ImmVal  := 0;
          Res.TypeIdx := TY_UNKNOWN;
          Res.Offset  := 0;
          Res.SymIdx  := -1;
        End
        Else
        Begin
          WarnMsg('super sans () ni .method : stub');
          EmitInstrAB('XOR', 'AX', 'AX');
          Res.Kind    := EK_AX;
          Res.ImmVal  := 0;
          Res.TypeIdx := TY_IDX_OBJECT;
          Res.Offset  := 0;
          Res.SymIdx  := -1;
        End;
      End
      Else If CurToken.Val = 'new' Then
      Begin
        { new Ctor(args) }
        ParserAdvance; { consomme 'new' }
        If CurToken.Kind = TK_IDENT Then
        Begin
          CtorName := CurToken.Val;
          ParserAdvance;
          { new Array(n) -> allouer tableau en DATA }
          If CtorName = 'Array' Then
          Begin
            Inc(LabelGenSeq);
            ArrLbl := JS_ARR_PFX + IntToStr(LabelGenSeq);
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
            Begin
              ParserAdvance;
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              Begin
                { new Array() -> tableau vide }
                DataAdd(ArrLbl, DK_ARRAY_BLK, 0, '');
                DataTab[DataCount - 1].ElemCount := 0;
                ParserAdvance;
              End
              Else
              Begin
                ParseExprPrec(2, ElemRes);
                If ElemRes.Kind = EK_IMM Then
                Begin
                  ElemCnt := ElemRes.ImmVal;
                  If ElemCnt > MAX_ARR_ELEM Then ElemCnt := MAX_ARR_ELEM;
                  If ElemCnt < 0 Then ElemCnt := 0;
                  DataAdd(ArrLbl, DK_ARRAY_BLK, 0, '');
                  For I := 0 To ElemCnt - 1 Do
                    DataAddWord(ArrLbl + '_E' + IntToStr(I), 0);
                  DataTab[DataCount - ElemCnt - 1].ElemCount := ElemCnt;
                End
                Else
                Begin
                  DataAdd(ArrLbl, DK_ARRAY_BLK, 0, '');
                  DataTab[DataCount - 1].ElemCount := 0;
                  WarnMsg('new Array(expr) dynamique : tab vide alloue');
                End;
                If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                  ParserAdvance;
              End;
            End
            Else
            Begin
              DataAdd(ArrLbl, DK_ARRAY_BLK, 0, '');
              DataTab[DataCount - 1].ElemCount := 0;
            End;
            EmitInstrAB('LEA', 'AX', ArrLbl);
            Res.Kind    := EK_AX;
            Res.ImmVal  := 0;
            Res.TypeIdx := TY_IDX_ARRAY;
            Res.Offset  := 0;
            Res.SymIdx  := -1;
          End
          Else If CtorName = 'RegExp' Then
          Begin
            (* new RegExp(pat, flags) -> synthetiser un TK_REGEXP *)
            RegPat := ''; RegFlags := '';
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
            Begin
              ParserAdvance;
              If CurToken.Kind = TK_STRING Then
              Begin
                RegPat := CurToken.Val;
                ParserAdvance;
              End Else Begin
                WarnMsg('new RegExp() : pattern non litteral, stub');
                While (CurToken.Kind <> TK_EOF) And
                      Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
                  ParserAdvance;
              End;
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
              Begin
                ParserAdvance;
                If CurToken.Kind = TK_STRING Then
                Begin
                  RegFlags := CurToken.Val;
                  ParserAdvance;
                End;
              End;
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                ParserAdvance;
            End;
            StrLbl := DataAddStr(RegPat + Chr(1) + RegFlags);
            EmitInstrAB('LEA', 'AX', StrLbl);
            Res.Kind    := EK_AX;
            Res.ImmVal  := 0;
            Res.TypeIdx := TY_IDX_OBJECT;
            Res.Offset  := 0;
            Res.SymIdx  := -1;
          End
          Else If (CtorName = 'Error') Or (CtorName = 'TypeError') Or
                  (CtorName = 'RangeError') Or (CtorName = 'SyntaxError') Or
                  (CtorName = 'ReferenceError') Then
          Begin
            { new Error(msg) -> CALL _JSRT_MKERROR }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
            Begin
              ParserAdvance; { consomme '(' }
              If (CurToken.Kind <> TK_EOF) And
                 Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
              Begin
                ParseExprPrec(2, ElemRes);
                ExprFlushToAX(ElemRes);
                EmitInstrAB('MOV', 'SI', 'AX');
              End
              Else
              Begin
                StrLbl := DataAddStr(CtorName);
                EmitInstrAB('LEA', 'SI', StrLbl);
              End;
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                ParserAdvance;
            End
            Else
            Begin
              StrLbl := DataAddStr(CtorName);
              EmitInstrAB('LEA', 'SI', StrLbl);
            End;
            EmitInstrA('CALL', '_JSRT_MKERROR');
            Res.Kind    := EK_AX;
            Res.ImmVal  := 0;
            Res.TypeIdx := TY_IDX_OBJECT;
            Res.Offset  := 0;
            Res.SymIdx  := -1;
          End
          Else
          Begin
          { Chercher le constructeur dans la table des symboles }
          FnIdx := SymFind(CtorName);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          Begin
            ParseCallArgs(ArgCount);
            If (FnIdx >= 0) And (SymTab[FnIdx].Cat = SC_CLASS) Then
            Begin
              { new ClassName(args) -> OBJCREATE + init methodes + appel ctor }
              EmitInstrAB('LEA', 'BX', SymTab[FnIdx].MangledName);
              EmitInstrA('CALL', '_JSRT_OBJCREATE');
              { Initialiser les methodes sur l'objet }
              EmitInstrAB('MOV', 'BX', 'AX');
              EmitInstrA('CALL', JS_FN_PFX + CtorName + '__init');
              EmitInstrAB('MOV', 'AX', 'BX'); { restaurer AX=obj ptr }
              EmitInstrAB('MOV', '[_JSRT_OBJTMP]', 'AX'); { sauver ptr }
              EmitInstrA('PUSH', 'AX');    { passer this en dernier (cdecl) }
              EmitInstrA('CALL', JS_FN_PFX + CtorName + '_ctor');
              EmitInstrAB('ADD', 'SP', IntToStr((ArgCount + 1) * 2));
              EmitInstrAB('MOV', 'AX', '[_JSRT_OBJTMP]'); { recuperer ptr }
            End
            Else If (FnIdx >= 0) And (SymTab[FnIdx].Cat = SC_FUNCTION) Then
            Begin
              EmitInstrA('CALL', '_JSRT_NEW');
              EmitInstrA('PUSH', 'AX');    { sauver this }
              EmitInstrA('CALL', SymTab[FnIdx].MangledName);
              If ArgCount > 0 Then
                EmitInstrAB('ADD', 'SP', IntToStr(ArgCount * 2));
              EmitInstrA('POP', 'AX');     { restaurer this }
            End
            Else
            Begin
              WarnMsg('new ' + CtorName + ' : constructeur non trouve, stub');
              EmitInstrA('CALL', '_JSRT_NEW');
              If ArgCount > 0 Then
                EmitInstrAB('ADD', 'SP', IntToStr(ArgCount * 2));
            End;
          End
          Else
          Begin
            { new Ctor sans parentheses }
            EmitInstrA('CALL', '_JSRT_NEW');
            WarnMsg('new ' + CtorName + ' sans arguments');
          End;
        End; { Else non-Array }
        End { If CurToken.Kind = TK_IDENT }
        Else
        Begin
          CompileError('identifiant attendu apres "new"');
          EmitInstrAB('XOR', 'AX', 'AX');
        End;
        Res.Kind    := EK_AX;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_OBJECT;
        Res.Offset  := 0;
        Res.SymIdx  := -1;
      End
      Else If CurToken.Val = 'function' Then
      Begin
        (* Expression function : function name?(params) { body } *)
        ParserAdvance; { consomme 'function' }
        { Generateur : function* }
        If (CurToken.Kind = TK_OP) And (CurToken.Val = '*') Then
        Begin
          WarnMsg('function* (generateur) non supporte : stub');
          ParserAdvance;
        End;
        { Nom optionnel }
        ObjLbl := '';
        If CurToken.Kind = TK_IDENT Then
        Begin
          ObjLbl := CurToken.Val;
          ParserAdvance;
        End;
        Inc(LabelGenSeq);
        If ObjLbl <> '' Then
          ArrLbl := JS_FN_PFX + ObjLbl
        Else
          ArrLbl := JS_FN_PFX + 'ANON_' + IntToStr(LabelGenSeq);
        StrLbl := LabelGen; { skip label }
        CtorName := LabelGen; { return label }
        ElemCnt := 0; { param count }
        { Parametres }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          While (CurToken.Kind <> TK_EOF) And
                Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
          Begin
            If (CurToken.Kind = TK_OP) And (CurToken.Val = '...') Then
            Begin WarnMsg('rest params (...) : stub'); ParserAdvance; End;
            If CurToken.Kind = TK_IDENT Then
            Begin
              If ElemCnt < MAX_PARAM Then
                ObjKeyLbls[ElemCnt] := CurToken.Val;
              Inc(ElemCnt);
              ParserAdvance;
            End;
            If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
            Begin
              WarnMsg('valeur par defaut de parametre : stub');
              ParserAdvance;
              ParseExprPrec(2, ElemRes);
            End;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
              ParserAdvance;
          End;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        { Emettre JMP par-dessus le corps }
        EmitInstrA('JMP', StrLbl);
        EmitLabel(ArrLbl);
        EmitInstrA('PUSH', 'BP');
        EmitInstrAB('MOV', 'BP', 'SP');
        EmitInstrA('PUSH', 'SI');
        EmitInstrA('PUSH', 'DI');
        EmitInstrA('INC', 'WORD PTR [_JS_CALLDEPTH]');
        { Sauvegarder contexte }
        ArgCount := CurFnDepth;  { reuse ArgCount as save slot }
        Inc(CurFnDepth);
        CurFnRetLbl := CtorName;
        FnIdx := CurFrameSize; { reuse FnIdx as save frame }
        CurFrameSize := 2;  { 2 words pour SI/DI }
        SymEnterScope;
        For I := 0 To ElemCnt - 1 Do
          SymAdd(ObjKeyLbls[I], SC_PARAM, TY_UNKNOWN,
                 4 + 2 * (ElemCnt - 1 - I));
        { Corps }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
        Begin
          ParserAdvance;
          While (CurToken.Kind <> TK_EOF) And
                Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
            ParseStmt;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
            ParserAdvance;
        End;
        EmitInstrAB('XOR', 'AX', 'AX');
        EmitLabel(CtorName);
        EmitInstrA('DEC', 'WORD PTR [_JS_CALLDEPTH]');
        EmitInstrAB('MOV', 'SI', '[BP-2]');
        EmitInstrAB('MOV', 'DI', '[BP-4]');
        EmitInstrAB('MOV', 'SP', 'BP');
        EmitInstrA('POP', 'BP');
        EmitInstr('RET');
        CurFnDepth := ArgCount;
        SymLeaveScope;
        CurFrameSize := FnIdx;
        EmitLabel(StrLbl);
        { Sync des variables capturees }
        EmitCaptureSync(CurFnDepth);
        EmitInstrAB('LEA', 'AX', ArrLbl);
        Res.Kind    := EK_AX;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_FUNCTION;
        Res.Offset  := 0;
        Res.SymIdx  := -1;
      End
      Else
      Begin
        { Autre mot-cle en position d'expression (class, etc.) }
        ExprMakeNone(Res);
        ParserAdvance;
      End;
    End;

    { ---- Identifiants ---- }
    TK_IDENT :
    Begin
      If CurToken.Val = 'NaN' Then
      Begin
        WarnMsg('NaN non representable en 16 bits, traite comme 0');
        ExprMakeImm(0, TY_IDX_NUMBER, Res);
        ParserAdvance;
      End
      Else If CurToken.Val = 'Infinity' Then
      Begin
        WarnMsg('Infinity non representable en 16 bits, traite comme 32767');
        ExprMakeImm(32767, TY_IDX_NUMBER, Res);
        ParserAdvance;
      End
      Else If CurToken.Val = 'arguments' Then
      Begin
        WarnMsg('objet "arguments" non implemente');
        EmitInstrAB('XOR', 'AX', 'AX');
        Res.Kind := EK_AX; Res.ImmVal := 0;
        Res.TypeIdx := TY_UNKNOWN; Res.Offset := 0; Res.SymIdx := -1;
        ParserAdvance;
      End
      Else If (CurToken.Val = 'yield') Or (CurToken.Val = 'await') Then
      Begin
        WarnMsg(CurToken.Val + ' non supporte : stub');
        ParserAdvance;
        If (CurToken.Kind <> TK_PUNCT) Or
           ((CurToken.Val <> ';') And (CurToken.Val <> ')') And
            (CurToken.Val <> '}')) Then
        Begin
          ParseExprPrec(2, ElemRes);
          ExprFlushToAX(ElemRes);
        End
        Else
          EmitInstrAB('XOR', 'AX', 'AX');
        Res.Kind := EK_AX; Res.ImmVal := 0;
        Res.TypeIdx := TY_UNKNOWN; Res.Offset := 0; Res.SymIdx := -1;
      End
      Else
      Begin
        { Verifier arrow function : ident => expr }
        ObjLbl := CurToken.Val; { sauver le nom de l identifiant }
        LexSaveState(SavedLex);
        ParserAdvance; { consommer l identifiant }
        If (CurToken.Kind = TK_OP) And (CurToken.Val = '=>') Then
        Begin
          { ---- Arrow function single-param : ident => ... ---- }
          ParserAdvance; { consomme => }
          Inc(LabelGenSeq);
          ArrLbl := JS_FN_PFX + 'ANON_' + IntToStr(LabelGenSeq);
          StrLbl := LabelGen; { skip }
          CtorName := LabelGen; { ret }
          EmitInstrA('JMP', StrLbl);
          EmitLabel(ArrLbl);
          EmitInstrA('PUSH', 'BP');
          EmitInstrAB('MOV', 'BP', 'SP');
          EmitInstrA('PUSH', 'SI');
          EmitInstrA('PUSH', 'DI');
          EmitInstrA('INC', 'WORD PTR [_JS_CALLDEPTH]');
          ArgCount := CurFnDepth;
          Inc(CurFnDepth);
          SaveThis := CurMethodThis;   { arrow : this = 0 }
          CurMethodThis := 0;
          CurFnRetLbl := CtorName;
          FnIdx := CurFrameSize;
          CurFrameSize := 2;  { SI/DI }
          SymEnterScope;
          SymAdd(ObjLbl, SC_PARAM, TY_UNKNOWN, 4);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
          Begin
            ParserAdvance;
            While (CurToken.Kind <> TK_EOF) And
                  Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
              ParseStmt;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
              ParserAdvance;
            EmitInstrAB('XOR', 'AX', 'AX');
          End
          Else
          Begin
            ParseExprPrec(2, ElemRes);
            ExprFlushToAX(ElemRes);
          End;
          EmitLabel(CtorName);
          EmitInstrA('DEC', 'WORD PTR [_JS_CALLDEPTH]');
          EmitInstrAB('MOV', 'SI', '[BP-2]');
          EmitInstrAB('MOV', 'DI', '[BP-4]');
          EmitInstrAB('MOV', 'SP', 'BP');
          EmitInstrA('POP', 'BP');
          EmitInstr('RET');
          CurFnDepth := ArgCount;
          CurMethodThis := SaveThis;   { restaurer }
          SymLeaveScope;
          CurFrameSize := FnIdx;
          EmitLabel(StrLbl);
          { Sync des variables capturees }
          EmitCaptureSync(CurFnDepth);
          EmitInstrAB('LEA', 'AX', ArrLbl);
          Res.Kind := EK_AX; Res.ImmVal := 0;
          Res.TypeIdx := TY_IDX_FUNCTION; Res.Offset := 0; Res.SymIdx := -1;
        End
        Else
        Begin
          { Pas une arrow function, restaurer et resoudre normalement }
          LexRestoreState(SavedLex);
          FnIdx := SymFind(CurToken.Val);
          If FnIdx >= 0 Then
          Begin
            Res.Kind    := EK_MEM;
            Res.ImmVal  := 0;
            Res.TypeIdx := SymTab[FnIdx].TypeIdx;
            Res.Offset  := SymTab[FnIdx].Offset;
            Res.SymIdx  := FnIdx;
          End
          Else
          Begin
            { Variable non declaree : reference globale implicite }
            If (CurToken.Val <> 'console') And (CurToken.Val <> 'process') And
               (CurToken.Val <> 'alert')   And (CurToken.Val <> 'prompt')  And
               (CurToken.Val <> 'Object')  And (CurToken.Val <> 'Math') Then
              WarnMsg('variable non declaree: "' + CurToken.Val +
                      '", reference globale implicite');
            FnIdx := SymAdd(CurToken.Val, SC_VAR, TY_UNKNOWN, 0);
            If FnIdx >= 0 Then
            Begin
              Res.Kind    := EK_MEM;
              Res.ImmVal  := 0;
              Res.TypeIdx := TY_UNKNOWN;
              Res.Offset  := 0;
              Res.SymIdx  := FnIdx;
            End
            Else
              ExprMakeNone(Res);
          End;
          ParserAdvance;
        End;
      End;
    End;

    { ---- Ponctuation ---- }
    TK_PUNCT :
    Begin
      { Groupement parenthese / arrow function : (expr) ou (params) => ... }
      If CurToken.Val = '(' Then
      Begin
        { Detection speculative d arrow function }
        LexSaveState(SavedLex);
        ParserAdvance; { consomme '(' }
        IsArrowOk := True;
        ElemCnt := 0;
        { Cas () => : zero params }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        Begin
          ParserAdvance; { consomme ')' }
          If Not ((CurToken.Kind = TK_OP) And (CurToken.Val = '=>')) Then
            IsArrowOk := False;
        End
        Else
        Begin
          { Collecter les identifiants : ident [, ident]* }
          While IsArrowOk Do
          Begin
            If CurToken.Kind = TK_IDENT Then
            Begin
              If ElemCnt < MAX_PARAM Then
                ObjKeyLbls[ElemCnt] := CurToken.Val;
              Inc(ElemCnt);
              ParserAdvance;
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
                ParserAdvance
              Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              Begin
                ParserAdvance;
                If Not ((CurToken.Kind = TK_OP) And (CurToken.Val = '=>')) Then
                  IsArrowOk := False;
                Break;
              End
              Else
              Begin
                IsArrowOk := False;
                Break;
              End;
            End
            Else
            Begin
              IsArrowOk := False;
              Break;
            End;
          End;
        End;
        If IsArrowOk And ((CurToken.Kind = TK_OP) And (CurToken.Val = '=>')) Then
        Begin
          { ---- Arrow function multi-params ---- }
          ParserAdvance; { consomme => }
          Inc(LabelGenSeq);
          ArrLbl := JS_FN_PFX + 'ANON_' + IntToStr(LabelGenSeq);
          StrLbl := LabelGen; { skip }
          CtorName := LabelGen; { ret }
          EmitInstrA('JMP', StrLbl);
          EmitLabel(ArrLbl);
          EmitInstrA('PUSH', 'BP');
          EmitInstrAB('MOV', 'BP', 'SP');
          EmitInstrA('PUSH', 'SI');
          EmitInstrA('PUSH', 'DI');
          EmitInstrA('INC', 'WORD PTR [_JS_CALLDEPTH]');
          ArgCount := CurFnDepth;
          Inc(CurFnDepth);
          SaveThis := CurMethodThis;   { arrow : this = 0 }
          CurMethodThis := 0;
          CurFnRetLbl := CtorName;
          FnIdx := CurFrameSize;
          CurFrameSize := 2;  { SI/DI }
          SymEnterScope;
          For I := 0 To ElemCnt - 1 Do
            SymAdd(ObjKeyLbls[I], SC_PARAM, TY_UNKNOWN,
                   4 + 2 * (ElemCnt - 1 - I));
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
          Begin
            ParserAdvance;
            While (CurToken.Kind <> TK_EOF) And
                  Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
              ParseStmt;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
              ParserAdvance;
            EmitInstrAB('XOR', 'AX', 'AX');
          End
          Else
          Begin
            ParseExprPrec(2, ElemRes);
            ExprFlushToAX(ElemRes);
          End;
          EmitLabel(CtorName);
          EmitInstrA('DEC', 'WORD PTR [_JS_CALLDEPTH]');
          EmitInstrAB('MOV', 'SI', '[BP-2]');
          EmitInstrAB('MOV', 'DI', '[BP-4]');
          EmitInstrAB('MOV', 'SP', 'BP');
          EmitInstrA('POP', 'BP');
          EmitInstr('RET');
          CurFnDepth := ArgCount;
          CurMethodThis := SaveThis;   { restaurer }
          SymLeaveScope;
          CurFrameSize := FnIdx;
          EmitLabel(StrLbl);
          { Sync des variables capturees }
          EmitCaptureSync(CurFnDepth);
          EmitInstrAB('LEA', 'AX', ArrLbl);
          Res.Kind := EK_AX; Res.ImmVal := 0;
          Res.TypeIdx := TY_IDX_FUNCTION; Res.Offset := 0; Res.SymIdx := -1;
        End
        Else
        Begin
          { Pas une arrow function : restaurer et parser comme (expr) }
          LexRestoreState(SavedLex);
          ParserAdvance; { consomme '(' }
          ParseExpr(Res);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance
          Else
            CompileError('")" attendu');
        End;
      End

      { Tableau litteral : [e0, e1, ...] }
      Else If CurToken.Val = '[' Then
      Begin
        ParserAdvance; { consomme '[' }
        { Generer un label pour le bloc tableau en DATA }
        Inc(LabelGenSeq);
        ArrLbl := JS_ARR_PFX + IntToStr(LabelGenSeq);
        ElemCnt := 0;
        { Tableau vide ? }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
        Begin
          ParserAdvance;
          DataAdd(ArrLbl, DK_ARRAY_BLK, 0, '');
          DataTab[DataCount - 1].ElemCount := 0;
        End
        Else
        Begin
          { Allouer le header du tableau (count) }
          DataAdd(ArrLbl, DK_ARRAY_BLK, 0, '');
          { Parser chaque element }
          While (CurToken.Kind <> TK_EOF) And
                Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']')) Do
          Begin
            { Trou/elision : [,, e] }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            Begin
              { Element undefined (trou) }
              DataAddWord(ArrLbl + '_E' + IntToStr(ElemCnt), 0);
              Inc(ElemCnt);
              ParserAdvance;
              Continue;
            End;
            { Spread }
            If (CurToken.Kind = TK_OP) And (CurToken.Val = '...') Then
            Begin
              WarnMsg('spread dans tableau litteral : stub');
              ParserAdvance;
            End;
            ParseExprPrec(2, ElemRes);
            If ElemRes.Kind = EK_IMM Then
              DataAddWord(ArrLbl + '_E' + IntToStr(ElemCnt), ElemRes.ImmVal)
            Else
            Begin
              { Element non constant : stocker dans DATA avec valeur 0, }
              { et emettre du code pour ecrire la valeur a l'execution }
              DataAddWord(ArrLbl + '_E' + IntToStr(ElemCnt), 0);
              ExprFlushToAX(ElemRes);
              EmitInstrAB('MOV', '[' + ArrLbl + '_E' + IntToStr(ElemCnt) + ']', 'AX');
            End;
            Inc(ElemCnt);
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
              ParserAdvance;
          End;
          DataTab[DataCount - ElemCnt - 1].ElemCount := ElemCnt;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
            ParserAdvance
          Else
            CompileError('"]" attendu dans tableau litteral');
        End;
        { Charger l'adresse du tableau dans AX }
        EmitInstrAB('LEA', 'AX', ArrLbl);
        Res.Kind    := EK_AX;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_ARRAY;
        Res.Offset  := 0;
        Res.SymIdx  := -1;
      End

      { Objet litteral : accolades k:v, ... }
      Else If CurToken.Val = '{' Then
      Begin
        ParserAdvance; { consomme '{' }
        Inc(LabelGenSeq);
        ObjLbl := JS_OBJ_PFX + IntToStr(LabelGenSeq);
        ElemCnt := 0;
        { Phase 1 : parser les proprietes et collecter cles/valeurs }
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
        Begin
          { Spread : ...obj }
          If (CurToken.Kind = TK_OP) And (CurToken.Val = '...') Then
          Begin
            WarnMsg('spread dans objet litteral : stub');
            ParserAdvance;
            ParseExprPrec(2, ElemRes); { consommer l'expression }
            ObjKeyLbls[ElemCnt]  := DataAddStr('_spread_');
            ObjValImm[ElemCnt]   := 0;
            ObjValIsImm[ElemCnt] := True;
            Inc(ElemCnt);
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
              ParserAdvance;
            Continue;
          End;
          { Cle : identificateur, chaine ou nombre }
          If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
          Begin
            StrLbl := DataAddStr(CurToken.Val);
            ParserAdvance;
          End
          Else If CurToken.Kind = TK_STRING Then
          Begin
            StrLbl := DataAddStr(CurToken.Val);
            ParserAdvance;
          End
          Else If (CurToken.Kind = TK_INTEGER) Or (CurToken.Kind = TK_FLOAT) Then
          Begin
            StrLbl := DataAddStr(CurToken.Val);
            ParserAdvance;
          End
          Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
          Begin
            WarnMsg('propriete calculee [expr] dans objet : stub');
            ParserAdvance;
            ParseExpr(ElemRes);
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
              ParserAdvance;
            StrLbl := DataAddStr('_computed_');
          End
          Else
          Begin
            CompileError('cle attendue dans objet litteral');
            Break;
          End;
          ObjKeyLbls[ElemCnt] := StrLbl;
          { Separateur ':' puis valeur, ou shorthand prop }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
          Begin
            ParserAdvance; { consomme ':' }
            ParseExprPrec(2, ElemRes);
            If ElemRes.Kind = EK_IMM Then
            Begin
              ObjValImm[ElemCnt]   := ElemRes.ImmVal;
              ObjValIsImm[ElemCnt] := True;
            End
            Else
            Begin
              ObjValIsImm[ElemCnt] := False;
              ExprFlushToAX(ElemRes);
              EmitInstrAB('MOV', '[' + ObjLbl + '_V' + IntToStr(ElemCnt) + ']', 'AX');
            End;
          End
          Else
          Begin
            ObjValImm[ElemCnt]   := 0;
            ObjValIsImm[ElemCnt] := True;
            WarnMsg('shorthand property : stub');
          End;
          Inc(ElemCnt);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
        End;
        { Phase 2 : emettre le bloc DATA contigu [n][K0][V0][K1][V1]... }
        DataAdd(ObjLbl, DK_OBJ_BLK, 0, '');
        DataTab[DataCount - 1].ElemCount := ElemCnt;
        For I := 0 To ElemCnt - 1 Do
        Begin
          DataAdd(ObjLbl + '_K' + IntToStr(I), DK_WORD, 0, ObjKeyLbls[I]);
          If ObjValIsImm[I] Then
            DataAddWord(ObjLbl + '_V' + IntToStr(I), ObjValImm[I])
          Else
            DataAddWord(ObjLbl + '_V' + IntToStr(I), 0);
        End;
        { Remplissage pour proprietes ajoutees a l execution (4 slots) }
        For I := ElemCnt To ElemCnt + 3 Do
        Begin
          DataAddWord(ObjLbl + '_K' + IntToStr(I), 0);
          DataAddWord(ObjLbl + '_V' + IntToStr(I), 0);
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
          ParserAdvance
        Else
          CompileError('"}" attendu dans objet litteral');
        EmitInstrAB('LEA', 'AX', ObjLbl);
        Res.Kind    := EK_AX;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_OBJECT;
        Res.Offset  := 0;
        Res.SymIdx  := -1;
      End

      Else
      Begin
        ExprMakeNone(Res);
        ParserAdvance;
      End;
    End;

  Else
    ExprMakeNone(Res);
    ParserAdvance;
  End;

  { Postfix : appels, membres, index }
  ParsePostfix(Res);
End;

{ ParseUnary : operateurs unaires prefixe + postfixe }
Procedure ParseUnary(Var Res : TExprVal);
Var
  Op    : TString;
  Addr  : TString;
  TLbl  : TString;
  FnIdx : Integer;   { pour & }
Begin
  { Unaire prefixe sur TK_OP }
  If CurToken.Kind = TK_OP Then
  Begin
    Op := CurToken.Val;
    If (Op = '+') Or (Op = '-') Or (Op = '!') Or (Op = '~') Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      { Pliage de constantes }
      If Res.Kind = EK_IMM Then
      Begin
        If Op = '-' Then
          Res.ImmVal := -Res.ImmVal
        Else If Op = '+' Then
          { rien : coerce en nombre }
        Else If Op = '!' Then
        Begin
          If Res.ImmVal = 0 Then Res.ImmVal := 1 Else Res.ImmVal := 0;
          Res.TypeIdx := TY_IDX_BOOLEAN;
        End
        Else If Op = '~' Then
          Res.ImmVal := Not Res.ImmVal;
      End
      Else
      Begin
        { Emission du code unaire }
        ExprFlushToAX(Res);
        If Op = '-' Then
          EmitInstr('NEG    AX')
        Else If Op = '+' Then
          { coerce en nombre : rien pour les entiers }
        Else If Op = '!' Then
        Begin
          TLbl := LabelGen;
          EmitInstrAB('CMP', 'AX', '0');
          EmitInstrAB('MOV', 'AX', '0');
          EmitInstrA('JNE', TLbl);
          EmitInstr('INC    AX');
          EmitLabel(TLbl);
          Res.TypeIdx := TY_IDX_BOOLEAN;
        End
        Else If Op = '~' Then
          EmitInstr('NOT    AX');
        Res.Kind   := EK_AX;
        Res.SymIdx := -1;
      End;
      Exit;
    End;
    { Prefixe ++/-- }
    If (Op = '++') Or (Op = '--') Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      If (Res.Kind = EK_MEM) And (Res.SymIdx >= 0) Then
      Begin
        Addr := ExprAddrOf(Res.SymIdx);
        If Op = '++' Then
        Begin
          EmitInstrAB('MOV', 'AX', Addr);
          EmitInstr('INC    AX');
          EmitInstrAB('MOV', Addr, 'AX');
        End
        Else
        Begin
          EmitInstrAB('MOV', 'AX', Addr);
          EmitInstr('DEC    AX');
          EmitInstrAB('MOV', Addr, 'AX');
        End;
        Res.Kind := EK_AX;
        Res.SymIdx := -1;
      End
      Else
      Begin
        ExprFlushToAX(Res);
        If Op = '++' Then EmitInstr('INC    AX')
        Else              EmitInstr('DEC    AX');
        Res.Kind := EK_AX;
        Res.SymIdx := -1;
      End;
      Exit;
    End;
    { Operateur de reference & : &ident -> adresse }
    If Op = '&' Then
    Begin
      ParserAdvance;
      If CurToken.Kind = TK_IDENT Then
      Begin
        FnIdx := SymFind(CurToken.Val);
        If FnIdx >= 0 Then
        Begin
          If SymTab[FnIdx].Cat = SC_FUNCTION Then
            EmitInstrAB('LEA', 'AX', SymTab[FnIdx].MangledName)
          Else If SymTab[FnIdx].IsCapture Then
            EmitInstrAB('LEA', 'AX', SymTab[FnIdx].CaptureLabel)
          Else If SymTab[FnIdx].Offset < 0 Then
            EmitInstrAB('LEA', 'AX', '[BP' + IntToStr(SymTab[FnIdx].Offset) + ']')
          Else If SymTab[FnIdx].Offset > 0 Then
            EmitInstrAB('LEA', 'AX', '[BP+' + IntToStr(SymTab[FnIdx].Offset) + ']')
          Else
            EmitInstrAB('LEA', 'AX', SymTab[FnIdx].MangledName);
        End
        Else
        Begin
          WarnMsg('& sur identifiant inconnu "' + CurToken.Val + '"');
          EmitInstrAB('XOR', 'AX', 'AX');
        End;
        ParserAdvance;
      End
      Else
      Begin
        WarnMsg('& attend un identifiant');
        ParseUnary(Res);
        ExprFlushToAX(Res);
      End;
      Res.Kind    := EK_AX;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_NUMBER;
      Res.Offset  := 0;
      Res.SymIdx  := -1;
      Exit;
    End;
    { Operateur de dereference * : *expr -> MOV BX,AX / MOV AX,[BX] }
    If Op = '*' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      ExprFlushToAX(Res);
      EmitInstrAB('MOV', 'BX', 'AX');
      EmitInstrAB('MOV', 'AX', '[BX]');
      Res.Kind    := EK_AX;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_NUMBER;
      Res.Offset  := 0;
      Res.SymIdx  := -1;
      Exit;
    End;
    { '?.' optional chaining : stub (geree aussi dans ParsePostfix) }
    If Op = '?.' Then
    Begin
      WarnMsg('?. (optional chaining) non supporte: stub');
      ParserAdvance;
      ParseUnary(Res);
      Res.Kind := EK_AX;
      Exit;
    End;
  End;
  { Unaire prefixe sur TK_KEYWORD }
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    Op := CurToken.Val;
    If Op = 'typeof' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      { Appel _JSRT_TYPEOF : AX = type index -> AX = ptr nom de type }
      ExprFlushToAX(Res);
      EmitInstrA('CALL', '_JSRT_TYPEOF');
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_STRING;
      Res.SymIdx  := -1;
      Exit;
    End
    Else If Op = 'void' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      { Evalue l'expression, puis retourne undefined (0) }
      ExprFlushToAX(Res);
      EmitInstrAB('XOR', 'AX', 'AX');
      ExprMakeUndef(Res);
      Res.Kind := EK_AX;
      Exit;
    End
    Else If Op = 'delete' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      { stub : toujours retourne true (1) }
      ExprFlushToAX(Res);
      EmitInstrAB('MOV', 'AX', '1');
      ExprMakeImm(1, TY_IDX_BOOLEAN, Res);
      Res.Kind := EK_AX;
      Exit;
    End;
  End;
  { Appel ParsePrimary }
  ParsePrimary(Res);
  { Postfixe ++ -- (la valeur AVANT incr est retournee) }
  If (CurToken.Kind = TK_OP) And
     ((CurToken.Val = '++') Or (CurToken.Val = '--')) Then
  Begin
    Op := CurToken.Val;
    ParserAdvance;
    If (Res.Kind = EK_MEM) And (Res.SymIdx >= 0) Then
    Begin
      Addr := ExprAddrOf(Res.SymIdx);
      EmitInstrAB('MOV', 'AX', Addr);
      EmitInstrA('PUSH', 'AX');  { sauver ancienne valeur }
      If Op = '++' Then EmitInstr('INC    AX')
      Else              EmitInstr('DEC    AX');
      EmitInstrAB('MOV', Addr, 'AX');
      EmitInstrA('POP', 'AX');   { restaurer ancienne valeur }
    End
    Else
      ExprFlushToAX(Res); { cas douteux : pas de lvalue }
    Res.Kind   := EK_AX;
    Res.SymIdx := -1;
  End;
End;

{ ParseExprPrec : boucle de montee de precedence (Pratt) }
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op        : String[12];
  Prec      : Integer;
  Right     : TExprVal;
  TrueBr    : TExprVal;
  FoldOk    : Boolean;
  ShiftAmt  : Integer;
  Addr      : String[32];  { adresse temporaire pour les assignations }
  LblSkip   : String[24];
  LblDone   : String[24];
  LblNeg    : String[24];
  LblFalse  : String[24];
  LblEnd    : String[24];
  LeftIsImm : Boolean;
  LeftImm   : LongInt;
  ResType   : Integer;
Begin
  ParseUnary(Res);
  Repeat
    Op   := '';
    Prec := 0;
    { Detecter operateur binaire }
    If CurToken.Kind = TK_OP Then
    Begin
      Op   := CurToken.Val;
      Prec := BinOpPrec(Op);
    End
    Else If (CurToken.Kind = TK_KEYWORD) And
            ((CurToken.Val = 'in') Or (CurToken.Val = 'instanceof')) Then
    Begin
      Op   := CurToken.Val;
      Prec := BinOpPrec(Op);
    End
    Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '?') Then
    Begin
      Op   := '?';
      Prec := BinOpPrec('?');
    End;
    { Arreter si fin ou priorite insuffisante ou assignation }
    If (Prec = 0) Or (Prec < MinPrec) Or IsAssignOp(Op) Then Break;
    ParserAdvance;
    { Ternaire : cond ? vrai : faux }
    If Op = '?' Then
    Begin
      If Res.Kind = EK_IMM Then
      Begin
        { Condition constante : plier }
        ParseExprPrec(3, TrueBr);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
          ParserAdvance
        Else
          WarnMsg('ternaire : attend ":"');
        ParseExprPrec(3, Right);
        If Res.ImmVal <> 0 Then Res := TrueBr
        Else                    Res := Right;
      End
      Else
      Begin
        { Emettre branches conditionnelles }
        LblFalse := LabelGen;
        LblEnd   := LabelGen;
        ExprFlushToAX(Res);
        EmitInstrAB('OR', 'AX', 'AX');
        EmitInstrA('JZ', LblFalse);
        ParseExprPrec(3, TrueBr);
        ExprFlushToAX(TrueBr);
        EmitInstrA('JMP', LblEnd);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
          ParserAdvance
        Else
          WarnMsg('ternaire : attend ":"');
        EmitLabel(LblFalse);
        ParseExprPrec(3, Right);
        ExprFlushToAX(Right);
        EmitLabel(LblEnd);
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_UNKNOWN;
        Res.SymIdx  := -1;
      End;
      Continue;
    End;
    { Court-circuit : &&, ||, ?? (emission avant parse droite) }
    If (Op = '&&') Or (Op = '||') Or (Op = '??') Then
    Begin
      LblSkip := LabelGen;
      ExprFlushToAX(Res);
      If Op = '&&' Then
      Begin
        EmitInstrAB('OR', 'AX', 'AX');
        EmitInstrA('JZ', LblSkip);
      End
      Else If Op = '||' Then
      Begin
        EmitInstrAB('OR', 'AX', 'AX');
        EmitInstrA('JNZ', LblSkip);
      End
      Else
      Begin
        { ?? : null/undefined approx = 0 }
        EmitInstrAB('CMP', 'AX', '0');
        EmitInstrA('JNE', LblSkip);
      End;
      If BinOpIsRight(Op) Then ParseExprPrec(Prec, Right)
      Else ParseExprPrec(Prec + 1, Right);
      ExprFlushToAX(Right);
      EmitLabel(LblSkip);
      Res.Kind    := EK_AX;
      Res.TypeIdx := TypeCoerceResult(Res.TypeIdx, Right.TypeIdx, Op);
      Res.SymIdx  := -1;
      Continue;
    End;
    { Avertissements specifiques }
    If (Op = '>>>') And Opts.Warnings Then
      WarnMsg('>>> (unsigned right shift) traite comme >>');
    { Sauvegarder operande gauche avant parse droite }
    LeftIsImm := (Res.Kind = EK_IMM);
    LeftImm   := Res.ImmVal;
    If Not LeftIsImm Then
    Begin
      ExprFlushToAX(Res);
      EmitInstrA('PUSH', 'AX');
    End;
    { Recurser cote droit }
    If BinOpIsRight(Op) Then
      ParseExprPrec(Prec, Right)
    Else
      ParseExprPrec(Prec + 1, Right);
    { Pliage de constantes si les deux membres sont immediats }
    FoldOk := LeftIsImm And (Right.Kind = EK_IMM);
    If FoldOk Then
    Begin
      If Op = '+' Then
        ExprMakeImm(Res.ImmVal + Right.ImmVal, TY_IDX_NUMBER, Res)
      Else If Op = '-' Then
        ExprMakeImm(Res.ImmVal - Right.ImmVal, TY_IDX_NUMBER, Res)
      Else If Op = '*' Then
        ExprMakeImm(Res.ImmVal * Right.ImmVal, TY_IDX_NUMBER, Res)
      Else If (Op = '/') And (Right.ImmVal <> 0) Then
        ExprMakeImm(Res.ImmVal Div Right.ImmVal, TY_IDX_NUMBER, Res)
      Else If (Op = '%') And (Right.ImmVal <> 0) Then
        ExprMakeImm(Res.ImmVal Mod Right.ImmVal, TY_IDX_NUMBER, Res)
      Else If Op = '&' Then
        ExprMakeImm(Res.ImmVal And Right.ImmVal, TY_IDX_NUMBER, Res)
      Else If Op = '|' Then
        ExprMakeImm(Res.ImmVal Or Right.ImmVal, TY_IDX_NUMBER, Res)
      Else If Op = '^' Then
        ExprMakeImm(Res.ImmVal Xor Right.ImmVal, TY_IDX_NUMBER, Res)
      Else If Op = '<<' Then
      Begin
        ShiftAmt := Integer(Right.ImmVal And 31);
        ExprMakeImm(Res.ImmVal Shl ShiftAmt, TY_IDX_NUMBER, Res);
      End
      Else If (Op = '>>') Or (Op = '>>>') Then
      Begin
        ShiftAmt := Integer(Right.ImmVal And 31);
        ExprMakeImm(Res.ImmVal Shr ShiftAmt, TY_IDX_NUMBER, Res);
      End
      Else If Op = '==' Then
        ExprMakeBool(Ord(Res.ImmVal = Right.ImmVal), Res)
      Else If Op = '!=' Then
        ExprMakeBool(Ord(Res.ImmVal <> Right.ImmVal), Res)
      Else If Op = '===' Then
        ExprMakeBool(
          Ord((Res.ImmVal = Right.ImmVal) And (Res.TypeIdx = Right.TypeIdx)), Res)
      Else If Op = '!==' Then
        ExprMakeBool(
          Ord(Not ((Res.ImmVal = Right.ImmVal) And
                   (Res.TypeIdx = Right.TypeIdx))), Res)
      Else If Op = '<'  Then ExprMakeBool(Ord(Res.ImmVal <  Right.ImmVal), Res)
      Else If Op = '<=' Then ExprMakeBool(Ord(Res.ImmVal <= Right.ImmVal), Res)
      Else If Op = '>'  Then ExprMakeBool(Ord(Res.ImmVal >  Right.ImmVal), Res)
      Else If Op = '>=' Then ExprMakeBool(Ord(Res.ImmVal >= Right.ImmVal), Res)
      Else If Op = 'instanceof' Then
        ExprMakeBool(0, Res)
      Else If Op = 'in' Then
        ExprMakeBool(0, Res)
      Else
      Begin
        Res.Kind    := EK_AX;
        Res.TypeIdx := TypeCoerceResult(Res.TypeIdx, Right.TypeIdx, Op);
      End;
    End
    Else
    Begin
      { ---- Emission code binaire ---- }
      ResType := TypeCoerceResult(Res.TypeIdx, Right.TypeIdx, Op);
      { Charger droite dans BX }
      ExprFlushToAX(Right);
      EmitInstrAB('MOV', 'BX', 'AX');
      { Restaurer gauche dans AX }
      If LeftIsImm Then
        EmitInstrAB('MOV', 'AX', IntToStr(LeftImm))
      Else
        EmitInstrA('POP', 'AX');
      { AX = gauche, BX = droite }
      If Op = '+' Then
      Begin
        If ResType = TY_IDX_STRING Then
          EmitInstr('CALL   _JSRT_CONCAT')
        Else
          EmitInstrAB('ADD', 'AX', 'BX');
      End
      Else If Op = '-' Then
        EmitInstrAB('SUB', 'AX', 'BX')
      Else If Op = '*' Then
        EmitInstrA('IMUL', 'BX')
      Else If Op = '/' Then
      Begin
        LblSkip := LabelGen;
        LblDone := LabelGen;
        EmitInstrAB('CMP', 'BX', '0');
        EmitInstrA('JE', LblSkip);
        EmitInstr('CWD');
        EmitInstrA('IDIV', 'BX');
        EmitInstrA('JMP', LblDone);
        EmitLabel(LblSkip);
        EmitInstrAB('XOR', 'AX', 'AX');
        EmitLabel(LblDone);
      End
      Else If Op = '%' Then
      Begin
        LblSkip := LabelGen;
        LblDone := LabelGen;
        EmitInstrAB('CMP', 'BX', '0');
        EmitInstrA('JE', LblSkip);
        EmitInstr('CWD');
        EmitInstrA('IDIV', 'BX');
        EmitInstrAB('MOV', 'AX', 'DX');
        EmitInstrA('JMP', LblDone);
        EmitLabel(LblSkip);
        EmitInstrAB('XOR', 'AX', 'AX');
        EmitLabel(LblDone);
      End
      Else If Op = '**' Then
        EmitInstr('CALL   _JSRT_POW')
      Else If Op = '&' Then
        EmitInstrAB('AND', 'AX', 'BX')
      Else If Op = '|' Then
        EmitInstrAB('OR', 'AX', 'BX')
      Else If Op = '^' Then
        EmitInstrAB('XOR', 'AX', 'BX')
      Else If Op = '<<' Then
      Begin
        EmitInstrAB('MOV', 'CL', 'BL');
        EmitInstrAB('SAL', 'AX', 'CL');
      End
      Else If (Op = '>>') Or (Op = '>>>') Then
      Begin
        EmitInstrAB('MOV', 'CL', 'BL');
        EmitInstrAB('SAR', 'AX', 'CL');
      End
      Else If (Op = '==') Or (Op = '===') Then
      Begin
        LblSkip := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JNE', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End
      Else If (Op = '!=') Or (Op = '!==') Then
      Begin
        LblSkip := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JE', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End
      Else If Op = '<' Then
      Begin
        LblSkip := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JGE', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End
      Else If Op = '<=' Then
      Begin
        LblSkip := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JG', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End
      Else If Op = '>' Then
      Begin
        LblSkip := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JLE', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End
      Else If Op = '>=' Then
      Begin
        LblSkip := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JL', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End
      Else If Op = 'instanceof' Then
      Begin
        { AX = instance ptr (pointe vers n_props, proto a [AX-2]) }
        { BX = LEA _JSC_Class (adresse du proto de la classe) }
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrAB('MOV', 'AX', '[SI-2]'); { proto ptr de l'objet }
        LblSkip := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JNE', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End
      Else If Op = 'in' Then
      Begin
        EmitInstrAB('XOR', 'AX', 'AX');
        If Opts.Warnings Then WarnMsg('in : stub, retourne 0');
      End;
      Res.Kind    := EK_AX;
      Res.TypeIdx := ResType;
      Res.SymIdx  := -1;
    End;
  Until False;
  { Operateurs d'assignation (prec=2, droite-assoc) }
  If (CurToken.Kind = TK_OP) And IsAssignOp(CurToken.Val) Then
  Begin
    Op := CurToken.Val;
    ParserAdvance;
    ParseExprPrec(2, Right); { droite-assoc }
    Res.Kind    := EK_AX;
    If Op = '=' Then
      Res.TypeIdx := Right.TypeIdx
    Else
      Res.TypeIdx := TY_UNKNOWN;
    If Res.SymIdx < 0 Then
    Begin
      CompileError('cible d''affectation invalide');
      Exit;
    End;
    { Emission du store si lvalue connue }
    If Res.SymIdx >= 0 Then
    Begin
      If SymTab[Res.SymIdx].IsConst Then
        CompileError('affectation a une constante: "' +
                     SymTab[Res.SymIdx].Name + '"');
      If Op = '=' Then
      Begin
        ExprFlushToAX(Right);
        ExprStore(Res.SymIdx);
        SymTab[Res.SymIdx].TypeIdx := Right.TypeIdx;
      End
      Else If Op = '&&=' Then
      Begin
        Addr := ExprAddrOf(Res.SymIdx);
        LblSkip := LabelGen;
        EmitInstrAB('MOV', 'AX', Addr);
        EmitInstrAB('OR', 'AX', 'AX');
        EmitInstrA('JZ', LblSkip);
        ExprFlushToAX(Right);
        ExprStore(Res.SymIdx);
        EmitLabel(LblSkip);
        SymTab[Res.SymIdx].TypeIdx := TY_UNKNOWN;
      End
      Else If Op = '||=' Then
      Begin
        Addr := ExprAddrOf(Res.SymIdx);
        LblSkip := LabelGen;
        EmitInstrAB('MOV', 'AX', Addr);
        EmitInstrAB('OR', 'AX', 'AX');
        EmitInstrA('JNZ', LblSkip);
        ExprFlushToAX(Right);
        ExprStore(Res.SymIdx);
        EmitLabel(LblSkip);
        SymTab[Res.SymIdx].TypeIdx := TY_UNKNOWN;
      End
      Else If Op = '??=' Then
      Begin
        Addr := ExprAddrOf(Res.SymIdx);
        LblSkip := LabelGen;
        EmitInstrAB('MOV', 'AX', Addr);
        EmitInstrAB('CMP', 'AX', '0');
        EmitInstrA('JNE', LblSkip);
        ExprFlushToAX(Right);
        ExprStore(Res.SymIdx);
        EmitLabel(LblSkip);
        SymTab[Res.SymIdx].TypeIdx := TY_UNKNOWN;
        WarnMsg('??= : approximation nullish (0 traite comme null/undefined)');
      End
      Else
      Begin
        { Operateur compose : RHS dans BX, old val dans AX, op, stocker }
        ExprFlushToAX(Right);
        EmitInstrAB('MOV', 'BX', 'AX');
        Addr := ExprAddrOf(Res.SymIdx);
        EmitInstrAB('MOV', 'AX', Addr);
        If Op = '+='  Then EmitInstrAB('ADD', 'AX', 'BX')
        Else If Op = '-='  Then EmitInstrAB('SUB', 'AX', 'BX')
        Else If Op = '*='  Then EmitInstrA('IMUL', 'BX')
        Else If Op = '/='  Then
        Begin
          LblSkip := LabelGen;
          LblDone := LabelGen;
          EmitInstrAB('CMP', 'BX', '0');
          EmitInstrA('JE', LblSkip);
          EmitInstr('CWD');
          EmitInstrA('IDIV', 'BX');
          EmitInstrA('JMP', LblDone);
          EmitLabel(LblSkip);
          EmitInstrAB('XOR', 'AX', 'AX');
          EmitLabel(LblDone);
        End
        Else If Op = '%='  Then
        Begin
          LblSkip := LabelGen;
          LblDone := LabelGen;
          EmitInstrAB('CMP', 'BX', '0');
          EmitInstrA('JE', LblSkip);
          EmitInstr('CWD');
          EmitInstrA('IDIV', 'BX');
          EmitInstrAB('MOV', 'AX', 'DX');
          EmitInstrA('JMP', LblDone);
          EmitLabel(LblSkip);
          EmitInstrAB('XOR', 'AX', 'AX');
          EmitLabel(LblDone);
        End
        Else If Op = '**=' Then
        Begin
          LblNeg  := LabelGen;
          LblSkip := LabelGen;
          LblDone := LabelGen;
          EmitInstrAB('MOV', 'CX', 'BX');
          EmitInstrAB('CMP', 'CX', '0');
          EmitInstrA('JL', LblNeg);
          EmitInstrAB('MOV', 'BX', 'AX');
          EmitInstrAB('MOV', 'AX', '1');
          EmitLabel(LblSkip);
          EmitInstrAB('CMP', 'CX', '0');
          EmitInstrA('JE', LblDone);
          EmitInstrA('IMUL', 'BX');
          EmitInstr('DEC    CX');
          EmitInstrA('JMP', LblSkip);
          EmitLabel(LblNeg);
          EmitInstrAB('XOR', 'AX', 'AX');
          EmitLabel(LblDone);
        End
        Else If Op = '&='  Then EmitInstrAB('AND', 'AX', 'BX')
        Else If Op = '|='  Then EmitInstrAB('OR',  'AX', 'BX')
        Else If Op = '^='  Then EmitInstrAB('XOR', 'AX', 'BX')
        Else If Op = '<<=' Then
        Begin
          EmitInstrAB('MOV', 'CL', 'BL');
          EmitInstrAB('SAL', 'AX', 'CL');
        End
        Else If (Op = '>>=') Or (Op = '>>>=') Then
        Begin
          EmitInstrAB('MOV', 'CL', 'BL');
          EmitInstrAB('SAR', 'AX', 'CL');
        End
        Else
          WarnMsg('operateur compose "' + Op + '" : stub');
        ExprStore(Res.SymIdx);
        SymTab[Res.SymIdx].TypeIdx := TY_UNKNOWN;
      End;
    End;
  End;
End;

{ ParseExpr : point d'entree principal (comma operator prec=1 ou superieur) }
Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParseExprPrec(2, Res); { MinPrec=2 : evaluer sous-exprs hors virgule }
  { Operateur virgule : (a, b, c) retourne la derniere }
  While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
  Begin
    ParserAdvance;
    ParseExprPrec(2, Res);
  End;
End;

{ ============================================================
  TABLE DES SYMBOLES [IMPLEMENTE]
  ============================================================ }

{ SymNameClean : supprimer les caracteres invalides en MASM ($ etc.) }
Function SymNameClean(Const Name : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := '';
  For I := 1 To Length(Name) Do
    If Name[I] <> '$' Then
    Begin
      If Length(R) < MAX_STR Then
        R := R + Name[I];
    End;
  If R = '' Then R := '_anon';
  SymNameClean := R;
End;

{ SymMangle : calculer le nom ASM mangled selon la categorie du symbole }
Function SymMangle(Const Name : TString; Cat : TSymCat) : TString;
Var
  Clean : TString;
Begin
  Clean := SymNameClean(Name);
  Case Cat Of
    SC_FUNCTION : SymMangle := JS_FN_PFX  + Clean;
    SC_CLASS    : SymMangle := JS_CLS_PFX + Clean;
    SC_LABEL    : SymMangle := JS_LBL_PFX + Clean;
  Else
    SymMangle := JS_VAR_PFX + Clean;
  End;
End;

{ SymFind : chercher un symbole par nom, du plus interne au plus externe }
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

{ SymFindCat : chercher un symbole par nom ET categorie }
Function SymFindCat(Const Name : TString; Cat : TSymCat) : Integer;
Var
  I : Integer;
Begin
  For I := SymCount - 1 DownTo 0 Do
    If (SymTab[I].Name = Name) And (SymTab[I].Cat = Cat) Then
    Begin
      SymFindCat := I;
      Exit;
    End;
  SymFindCat := -1;
End;

{ SymAdd : ajouter un symbole dans la table, retourne son indice (ou -1) }
Function SymAdd(Const Name : TString; Cat : TSymCat;
                TypeIdx, Offset : Integer) : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    CompileError('table des symboles pleine (max=' + IntToStr(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;
  SymTab[SymCount].Name        := Name;
  SymTab[SymCount].MangledName := SymMangle(Name, Cat);
  SymTab[SymCount].Cat         := Cat;
  SymTab[SymCount].TypeIdx     := TypeIdx;
  SymTab[SymCount].ScopeLevel  := CurScope;
  SymTab[SymCount].Offset      := Offset;
  SymTab[SymCount].IsHoisted   := (Cat = SC_VAR);
  SymTab[SymCount].IsConst     := (Cat = SC_CONST_JS);
  SymTab[SymCount].IsParam     := (Cat = SC_PARAM);
  SymTab[SymCount].IsCapture   := False;
  SymTab[SymCount].CaptureLabel := '';
  SymTab[SymCount].FnDepthLvl  := CurFnDepth;
  SymTab[SymCount].DeclLine    := CurToken.Line;
  SymAdd := SymCount;
  Inc(SymCount);
  Inc(TotalSyms);
End;

{ SymEnterScope : entrer dans une nouvelle portee de bloc }
Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
  Begin
    CompileError('portees trop imbriquees (max=' + IntToStr(MAX_SCOPE) + ')');
    Exit;
  End;
  ScopeStack[ScopeTop]      := SymCount;
  ScopeFrameStack[ScopeTop] := CurFrameSize;
  Inc(ScopeTop);
  Inc(CurScope);
End;

{ SymLeaveScope : quitter la portee, effacer les symboles de bloc de la table }
Procedure SymLeaveScope;
Var
  FrameDelta : Integer;
Begin
  If ScopeTop <= 0 Then Exit;
  Dec(ScopeTop);
  SymCount := ScopeStack[ScopeTop];  { let/const de bloc effaces }
  Dec(CurScope);
  { Liberer espace pile des locales de ce scope }
  If CurFnDepth > 0 Then
  Begin
    FrameDelta := CurFrameSize - ScopeFrameStack[ScopeTop];
    If FrameDelta > 0 Then
    Begin
      EmitInstrAB('ADD', 'SP', IntToStr(FrameDelta * 2));
      CurFrameSize := ScopeFrameStack[ScopeTop];
    End;
  End;
End;

{ SymNextOffset : prochain offset [BP-n] pour une variable locale (2 octets) }
Function SymNextOffset : Integer;
Begin
  Inc(CurFrameSize);
  SymNextOffset := -(CurFrameSize * 2);
End;

{ ---- Allocation de registres temporaires (BX CX DX) --------- }
{ Convention : AX est reserve pour la valeur de retour d'expression   }
{ TempRegMask : bit0=BX bit1=CX bit2=DX  (0=libre 1=occupe)          }

Function TempRegAcquire : TString;
Begin
  If (TempRegMask And 1) = 0 Then
  Begin
    TempRegMask   := TempRegMask Or 1;
    TempRegAcquire := 'BX';
  End
  Else If (TempRegMask And 2) = 0 Then
  Begin
    TempRegMask   := TempRegMask Or 2;
    TempRegAcquire := 'CX';
  End
  Else If (TempRegMask And 4) = 0 Then
  Begin
    TempRegMask   := TempRegMask Or 4;
    TempRegAcquire := 'DX';
  End
  Else
  Begin
    WarnMsg('plus de registres temporaires (BX CX DX tous occupes)');
    TempRegAcquire := '';
  End;
End;

Procedure TempRegRelease(Const RegName : TString);
Begin
  If RegName = 'BX' Then TempRegMask := TempRegMask And Not 1
  Else If RegName = 'CX' Then TempRegMask := TempRegMask And Not 2
  Else If RegName = 'DX' Then TempRegMask := TempRegMask And Not 4;
End;

{ ============================================================
  SYSTEME DE TYPES [IMPLEMENTE]
  ============================================================ }

{ TypeKindOf : retourner le TTypeKind associe a un indice de type }
Function TypeKindOf(TypeIdx : Integer) : TTypeKind;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeKindOf := TypeTab[TypeIdx].Kind
  Else
    TypeKindOf := TKJ_UNKNOWN;
End;

{ TypeSizeof : taille en octets d'un type (toujours 2 en 16-bit) }
Function TypeSizeof(TypeIdx : Integer) : Integer;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeSizeof := TypeTab[TypeIdx].Size
  Else
    TypeSizeof := 2;
End;

{ TypeMangle : prefixe ASM selon le type pour les labels }
Function TypeMangle(TypeIdx : Integer) : TString;
Begin
  Case TypeKindOf(TypeIdx) Of
    TKJ_NUMBER    : TypeMangle := '_JSN_';
    TKJ_STRING    : TypeMangle := '_JSS_';
    TKJ_BOOLEAN   : TypeMangle := '_JSB_';
    TKJ_OBJECT    : TypeMangle := '_JSO_';
    TKJ_ARRAY     : TypeMangle := '_JSA_';
    TKJ_FUNCTION  : TypeMangle := '_JSF_';
    TKJ_NULL      : TypeMangle := '_JSN_';  { null=0, traite comme number }
    TKJ_UNDEFINED : TypeMangle := '_JSU_';
  Else
    TypeMangle := '_JSX_'; { inconnu / polymorphe }
  End;
End;

{ TypeIsNumeric : vrai si le type est comparable a un nombre }
Function TypeIsNumeric(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsNumeric :=
    (K = TKJ_NUMBER) Or (K = TKJ_BOOLEAN) Or
    (K = TKJ_NULL)   Or (K = TKJ_UNDEFINED);
End;

{ TypeIsPtr : vrai si le type est un pointeur (string/object/array/function) }
Function TypeIsPtr(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsPtr :=
    (K = TKJ_STRING) Or (K = TKJ_OBJECT) Or
    (K = TKJ_ARRAY)  Or (K = TKJ_FUNCTION);
End;

{ TypeCanCoerce : peut-on convertir SrcIdx vers DstIdx a la compilation ? }
Function TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean;
Begin
  If SrcIdx = DstIdx Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { anything -> UNKNOWN est toujours OK (perd l'info de type) }
  If DstIdx = TY_UNKNOWN Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { null/undefined -> number : force AX=0 }
  If (DstIdx = TY_IDX_NUMBER) And
     ((SrcIdx = TY_IDX_NULL) Or (SrcIdx = TY_IDX_UNDEF)) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { boolean -> number : AX est deja 0 ou 1 }
  If (DstIdx = TY_IDX_NUMBER) And (SrcIdx = TY_IDX_BOOLEAN) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { number -> boolean : toute valeur non nulle = true }
  If (DstIdx = TY_IDX_BOOLEAN) And TypeIsNumeric(SrcIdx) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { number + string (concat) : pris en charge par TypeCoerceResult }
  TypeCanCoerce := False;
End;

{ TypeCoerceResult : deduire le type de resultat d'une operation binaire }
Function TypeCoerceResult(LeftIdx, RightIdx : Integer;
                          Const Op : TString) : Integer;
Var
  LK, RK : TTypeKind;
Begin
  LK := TypeKindOf(LeftIdx);
  RK := TypeKindOf(RightIdx);
  { Operateurs toujours booleens }
  If (Op = '==')  Or (Op = '!=')  Or
     (Op = '===') Or (Op = '!==') Or
     (Op = '<')   Or (Op = '<=')  Or
     (Op = '>')   Or (Op = '>=')  Or
     (Op = '&&')  Or (Op = '||')  Or
     (Op = 'instanceof') Or (Op = 'in') Then
  Begin
    TypeCoerceResult := TY_IDX_BOOLEAN;
    Exit;
  End;
  { Nullish : retourne le type du cote non-null }
  If Op = '??' Then
  Begin
    If (LeftIdx = TY_IDX_NULL) Or (LeftIdx = TY_IDX_UNDEF) Then
      TypeCoerceResult := RightIdx
    Else
      TypeCoerceResult := LeftIdx;
    Exit;
  End;
  { + avec une chaine : concatenation -> string }
  If Op = '+' Then
  Begin
    If (LK = TKJ_STRING) Or (RK = TKJ_STRING) Then
    Begin
      TypeCoerceResult := TY_IDX_STRING;
      Exit;
    End;
  End;
  { Operateurs bit a bit -> number }
  If (Op = '&')   Or (Op = '|')  Or (Op = '^') Or
     (Op = '<<')  Or (Op = '>>') Or (Op = '>>>') Then
  Begin
    TypeCoerceResult := TY_IDX_NUMBER;
    Exit;
  End;
  { Arithmetiques generaux }
  If (Op = '+') Or (Op = '-') Or (Op = '*') Or
     (Op = '/') Or (Op = '%') Or (Op = '**') Then
  Begin
    { Si les deux sont numeriques -> number }
    If TypeIsNumeric(LeftIdx) And TypeIsNumeric(RightIdx) Then
    Begin
      TypeCoerceResult := TY_IDX_NUMBER;
      Exit;
    End;
    { Sinon : polymorphe UNKNOWN }
    TypeCoerceResult := TY_UNKNOWN;
    Exit;
  End;
  { Assignation : type du cote droit }
  TypeCoerceResult := RightIdx;
End;

{ ============================================================
  EMETTEUR DE CODE ASM [IMPLEMENTE]
  ============================================================ }

{ LabelGen : generer un label unique _JSL_NNNNN }
Function LabelGen : TString;
Var
  S : TString;
Begin
  Inc(LabelGenSeq);
  Str(LabelGenSeq, S);
  LabelGen := JS_LBL_PFX + S;
End;

{ EmitRaw : ecrire une ligne brute dans le fichier de sortie }
Procedure EmitRaw(Const S : TString);
Begin
  WriteLn(OutF, S);
End;

{ EmitBlankLine : ligne vide }
Procedure EmitBlankLine;
Begin
  WriteLn(OutF);
End;

{ EmitComment : commentaire ASM '; texte' }
Procedure EmitComment(Const S : TString);
Begin
  WriteLn(OutF, '; ', S);
End;

{ EmitLabel : label ASM suivi de ':' en colonne 0 }
Procedure EmitLabel(Const Lbl : TString);
Begin
  WriteLn(OutF, Lbl, ':');
End;

{ EmitInstr : instruction sans operandes (8 espaces d'indentation) }
Procedure EmitInstr(Const Mnem : TString);
Begin
  WriteLn(OutF, '        ', Mnem);
End;

{ EmitInstrA : instruction + un operande }
Procedure EmitInstrA(Const Mnem, A1 : TString);
Begin
  WriteLn(OutF, '        ', Mnem, '   ', A1);
End;

{ EmitInstrAB : instruction + deux operandes separes par ', ' }
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);
Begin
  WriteLn(OutF, '        ', Mnem, '   ', A1, ', ', A2);
End;

{ EmitProlog : preambule de fonction (BP frame + SI/DI + profondeur) }
Procedure EmitProlog;
Begin
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('INC', 'WORD PTR [_JS_CALLDEPTH]');
End;

{ EmitEpilog : epilogue de fonction (restaurer SI/DI/SP/BP et retourner) }
Procedure EmitEpilog;
Begin
  If CurFnRetLbl <> '' Then
    EmitLabel(CurFnRetLbl);
  EmitInstrA('DEC', 'WORD PTR [_JS_CALLDEPTH]');
  EmitInstrAB('MOV', 'SI', '[BP-2]');
  EmitInstrAB('MOV', 'DI', '[BP-4]');
  EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstrA('POP', 'BP');
  EmitInstr('RET');
End;

{ EmitCoerce : emettre le code de coercition SrcTypeIdx -> DstTypeIdx }
{ Lorsque les types sont connus a la compilation, on evite des appels runtime }
Procedure EmitCoerce(SrcTypeIdx, DstTypeIdx : Integer);
Var
  SK, DK : TTypeKind;
Begin
  If SrcTypeIdx = DstTypeIdx Then Exit; { rien a faire }
  SK := TypeKindOf(SrcTypeIdx);
  DK := TypeKindOf(DstTypeIdx);
  { null/undefined -> number : AX=0 deja ou il faut forcer 0 }
  If (DK = TKJ_NUMBER) And ((SK = TKJ_NULL) Or (SK = TKJ_UNDEFINED)) Then
  Begin
    EmitInstrAB('XOR', 'AX', 'AX');
    Exit;
  End;
  { boolean -> number : AX = 0 ou 1, rien a faire }
  If (DK = TKJ_NUMBER) And (SK = TKJ_BOOLEAN) Then
    Exit;
  { number -> boolean : AND AX,AX / SETNZ AL }
  If (DK = TKJ_BOOLEAN) And (SK = TKJ_NUMBER) Then
  Begin
    EmitInstrAB('AND', 'AX', 'AX');
    EmitComment('  (coerce number->boolean)');
    Exit;
  End;
  { number -> string : appel runtime }
  If (DK = TKJ_STRING) And TypeIsNumeric(SrcTypeIdx) Then
  Begin
    EmitInstrA('CALL', JS_RT_PFX + 'NUMTOSTR');
    Exit;
  End;
  { tout -> UNKNOWN : rien ne garantit la coercition }
  { on emet juste un commentaire pour le futur (runtime) }
  EmitComment('  [coerce ' + IntToStr(SrcTypeIdx) +
              ' -> ' + IntToStr(DstTypeIdx) + ' : runtime]');
End;

{ ============================================================
  STUBS PREALABLES
  ============================================================ }

Procedure TypeInit;
Var
  I : Integer;
Begin
  TypeCount := 0;
  For I := 0 To MAX_TYPE - 1 Do
  Begin
    TypeTab[I].Name := '';
    TypeTab[I].Kind := TKJ_UNKNOWN;
    TypeTab[I].Size := 0;
  End;
  { Types primitifs JavaScript }
  TypeTab[TY_IDX_NUMBER].Name   := 'number';
  TypeTab[TY_IDX_NUMBER].Kind   := TKJ_NUMBER;
  TypeTab[TY_IDX_NUMBER].Size   := 2;
  TypeTab[TY_IDX_STRING].Name   := 'string';
  TypeTab[TY_IDX_STRING].Kind   := TKJ_STRING;
  TypeTab[TY_IDX_STRING].Size   := 2;
  TypeTab[TY_IDX_BOOLEAN].Name  := 'boolean';
  TypeTab[TY_IDX_BOOLEAN].Kind  := TKJ_BOOLEAN;
  TypeTab[TY_IDX_BOOLEAN].Size  := 2;
  TypeTab[TY_IDX_OBJECT].Name   := 'object';
  TypeTab[TY_IDX_OBJECT].Kind   := TKJ_OBJECT;
  TypeTab[TY_IDX_OBJECT].Size   := 2;
  TypeTab[TY_IDX_ARRAY].Name    := 'array';
  TypeTab[TY_IDX_ARRAY].Kind    := TKJ_ARRAY;
  TypeTab[TY_IDX_ARRAY].Size    := 2;
  TypeTab[TY_IDX_FUNCTION].Name := 'function';
  TypeTab[TY_IDX_FUNCTION].Kind := TKJ_FUNCTION;
  TypeTab[TY_IDX_FUNCTION].Size := 2;
  TypeTab[TY_IDX_NULL].Name     := 'object';   { typeof null = 'object' en JS }
  TypeTab[TY_IDX_NULL].Kind     := TKJ_NULL;
  TypeTab[TY_IDX_NULL].Size     := 2;
  TypeTab[TY_IDX_UNDEF].Name    := 'undefined';
  TypeTab[TY_IDX_UNDEF].Kind    := TKJ_UNDEFINED;
  TypeTab[TY_IDX_UNDEF].Size    := 2;
  TypeCount := TY_PRIM_COUNT;
End;

Procedure SymInit;
Var
  I : Integer;
Begin
  SymCount := 0;
  ScopeTop := 0;
  CurScope := 0;
  TempRegMask := 0;
  For I := 0 To MAX_SYM - 1 Do
  Begin
    SymTab[I].Name        := '';
    SymTab[I].MangledName := '';
    SymTab[I].Cat         := SC_VAR;
    SymTab[I].TypeIdx     := TY_UNKNOWN;
    SymTab[I].ScopeLevel  := 0;
    SymTab[I].Offset      := 0;
    SymTab[I].IsHoisted   := False;
    SymTab[I].IsConst     := False;
    SymTab[I].IsParam     := False;
    SymTab[I].IsCapture   := False;
    SymTab[I].DeclLine    := 0;
  End;
End;

{ ---- LexInit : ouvrir le source, lire premiere ligne, shebang }
Procedure LexInit;
Begin
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir: ' + Opts.SrcFile);
  LexOpened      := True;
  LexLineNo      := 0;
  LexColNo       := 1;
  LexEOF         := False;
  LexLine        := '';
  LexPrevKind    := TK_EOF;
  LexPrevVal     := '';
  LexExpectRegex := True;
  LexASIFlag     := False;
  { Lire la premiere ligne }
  LexNextLine;
  { Detecter shebang #!/... et le sauter }
  If (Not LexEOF) And (Length(LexLine) >= 2) And
     (LexLine[1] = '#') And (LexLine[2] = '!') Then
    LexColNo := Length(LexLine) + 1;
End;

Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

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
  EmitComment('Genere par JS86 v' + JS86_VERSION + ' - ' + Opts.SrcFile);
  EmitBlankLine;
  EmitRaw('        .MODEL SMALL');
  EmitRaw('        .STACK ' + IntToStr(STACK_SIZE));
  EmitBlankLine;
  EmitRaw('_TEXT   SEGMENT WORD PUBLIC ''CODE''');
  EmitRaw('        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK');
  EmitBlankLine;
  EmitLabel('_JSF_main');
  EmitComment('--- initialisation segment de donnees ---');
  EmitInstrAB('MOV', 'AX', '_DATA');
  EmitInstrAB('MOV', 'DS', 'AX');
  EmitBlankLine;
  EmitComment('--- debut du code genere ---');
  EmitBlankLine;
End;

{ ============================================================
  SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
  ============================================================ }

{ Ajoute une entree generique dans DataTab et retourne son index. }
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

{ Cree un label _JSK_N et stocke la chaine litterale S. Retourne le label. }
Function DataAddStr(Const S : TString) : TString;
Var
  Lbl : TString;
Begin
  Inc(LabelGenSeq);
  Lbl := '_JSK_' + IntToStr(LabelGenSeq);
  DataAdd(Lbl, DK_STR, 0, S);
  DataAddStr := Lbl;
End;

{ Ajoute une variable/constante globale comme mot 16 bits. Retourne l index. }
Function DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

{ Emet le segment _DATA complet : constantes JS, strbuf, puis DataTab. }
Procedure EmitDataSeg;
Var
  I : Integer;
  S : TString;
  J : Integer;
  Quote : Char;
Begin
  EmitRaw('_DATA   SEGMENT WORD PUBLIC ''DATA''');
  { Constantes JS standard (null/undefined/true/false) }
  EmitRaw('_JS_UNDEF   DB  ''undefined'',0');
  EmitRaw('_JS_NULL    DB  ''null'',0');
  EmitRaw('_JS_TRUE    DB  ''true'',0');
  EmitRaw('_JS_FALSE   DB  ''false'',0');
  { Buffer de travail pour concatenation et coercition de chaines }
  EmitRaw('_JSRT_STRBUF DB 512 DUP(0)');
  { Constantes console/IO }
  EmitRaw('_JS_CRLF    DB  13,10,0');
  EmitRaw('_JS_SPACE   DB  '' '',0');
  EmitRaw('_JS_WARNPFX DB  ''Warning: '',0');
  { Buffer statique pour Object.keys() }
  EmitRaw('_JSRT_OKBUF  DW  ' + IntToStr(MAX_OBJ_PROP + 1) + ' DUP(0)');
  (* Compteur profondeur d appels *)
  EmitRaw('_JS_CALLDEPTH  DW  0');
  (* Stubs de capture regexp _JSCAP_1.._JSCAP_9 *)
  For I := 1 To 9 Do
    EmitRaw('_JSCAP_' + Chr(Ord('0') + I) + '  DW  0');
  (* Buffer temporaire pour _JSRT_RESUB *)
  EmitRaw('_JSRT_REBUF  DB  256 DUP(0)');
  (* Buffers et donnees pour methodes natives *)
  EmitRaw('_JSRT_CHRBUF DB  2 DUP(0)');
  EmitRaw('_JSRT_JSONBUF DB 256 DUP(0)');
  EmitRaw('_JSRT_SPLITBUF DW 64 DUP(0)');
  EmitRaw('_JS_RNDSEED  DW  12345');
  (* Heap et compteur pour objets classes *)
  EmitRaw('_JSRT_OBJHEAP DB 4096 DUP(0)');
  EmitRaw('_JSRT_HEAPTOP DW 0');
  EmitRaw('_JSRT_OBJTMP  DW 0');
  (* Gestion des exceptions *)
  EmitRaw('_JSX_HANDLER  DW  0');
  EmitRaw('_JSX_SAVESP   DW  0');
  EmitRaw('_JSX_SAVEBP   DW  0');
  EmitRaw('_JSX_ERRPTR   DW  0');
  EmitRaw('_JS_ERR_DIV0  DB  ''Division by zero'',0');
  EmitRaw('_JS_ERR_UNCAUGHT DB ''Uncaught: '',0');
  EmitRaw('_JSRT_ERRBUF  DB  64 DUP(0)');
  (* Runtime core *)
  EmitRaw('_JSRT_NUMBUF  DB  12 DUP(0)');
  EmitRaw('_JS_TYP_NUMBER  DB ''number'',0');
  EmitRaw('_JS_TYP_STRING  DB ''string'',0');
  EmitRaw('_JS_TYP_BOOLEAN DB ''boolean'',0');
  EmitRaw('_JS_TYP_OBJECT  DB ''object'',0');
  EmitRaw('_JS_TYP_FUNCTION DB ''function'',0');
  EmitRaw('_JS_HEAP      DB 4096 DUP(0)');
  EmitRaw('_JS_HEAPTOP   DW 0');
  { Entrees dynamiques de DataTab }
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_WORD :
        If DataTab[I].StrVal <> '' Then
          EmitRaw(DataTab[I].LblName + '  DW  OFFSET ' + DataTab[I].StrVal)
        Else
          EmitRaw(DataTab[I].LblName + '  DW  ' +
                  IntToStr(DataTab[I].IntVal));
      DK_BYTE :
        EmitRaw(DataTab[I].LblName + '  DB  ' +
                IntToStr(DataTab[I].IntVal));
      DK_STR :
        Begin
          { Double les apostrophes pour MASM : '' }
          S := '';
          Quote := '''';
          For J := 1 To Length(DataTab[I].StrVal) Do
          Begin
            If DataTab[I].StrVal[J] = Quote Then
              S := S + ''''''
            Else
              S := S + DataTab[I].StrVal[J];
          End;
          EmitRaw(DataTab[I].LblName + '  DB  ''' + S + ''',0');
        End;
      DK_ARRAY_BLK :
        EmitRaw(DataTab[I].LblName + '  DW  ' +
                IntToStr(DataTab[I].ElemCount) +
                '   ; tableau (' + IntToStr(DataTab[I].ElemCount) + ' elem)');
      DK_OBJ_BLK :
        EmitRaw(DataTab[I].LblName + '  DW  ' +
                IntToStr(DataTab[I].ElemCount) +
                '   ; objet (' + IntToStr(DataTab[I].ElemCount) + ' props)');
    End;
  End;
  EmitRaw('_DATA   ENDS');
End;

{ ============================================================
  CONSOLE / PROCESS / SORTIES [IMPLEMENTE]
  ============================================================ }

{ EmitStrLen : emet code pour calculer longueur chaine ASCIIZ.
  IN  : DI = ptr chaine     OUT : CX = longueur
  Utilise DI, AL, CX. }
Procedure EmitStrLen;
Var
  LblLoop, LblDone : TString;
Begin
  LblLoop := LabelGen;
  LblDone := LabelGen;
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitLabel(LblLoop);
  EmitRaw('        MOV   AL, [DI]');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', LblDone);
  EmitInstr('INC    CX');
  EmitInstr('INC    DI');
  EmitInstrA('JMP', LblLoop);
  EmitLabel(LblDone);
  { DI pointe apres le 0, rembobiner }
  EmitInstrAB('SUB', 'DI', 'CX');
End;

{ EmitWriteFD : emet INT 21h AH=40h pour BX=fd, DX=buf, CX=len }
Procedure EmitWriteFD(FD : Integer);
Begin
  EmitInstrAB('MOV', 'BX', IntToStr(FD));
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstr('INT    21h');
End;

{ EmitPrintStr : affiche la chaine constante Lbl sur fd.
  Utilise DI, CX, DX, AH, BX }
Procedure EmitPrintStr(Const Lbl : TString; FD : Integer);
Begin
  EmitInstrAB('LEA', 'DI', Lbl);
  EmitStrLen;
  EmitInstrAB('LEA', 'DX', Lbl);
  EmitWriteFD(FD);
End;

{ EmitPrintNewline : affiche CRLF sur fd }
Procedure EmitPrintNewline(FD : Integer);
Begin
  EmitInstrAB('LEA', 'DX', '_JS_CRLF');
  EmitInstrAB('MOV', 'CX', '2');
  EmitWriteFD(FD);
End;

{ EmitPrintSpace : affiche un espace sur fd }
Procedure EmitPrintSpace(FD : Integer);
Begin
  EmitInstrAB('LEA', 'DX', '_JS_SPACE');
  EmitInstrAB('MOV', 'CX', '1');
  EmitWriteFD(FD);
End;

{ EmitPrintAX : affiche la valeur de AX sur fd=1 (stdout) en fonction du type.
  - TY_IDX_STRING : AX=ptr chaine ASCIIZ -> strlen + write
  - TY_IDX_NUMBER ou autre : CALL _JSRT_NUMTOSTR -> AX=ptr -> strlen + write
  - TY_IDX_BOOLEAN : affiche "true" ou "false"
  - TY_IDX_NULL : affiche "null"
  - TY_IDX_UNDEF : affiche "undefined" }
Procedure EmitPrintAX(TIdx : Integer);
Var
  LblTrue, LblDone : TString;
Begin
  If TIdx = TY_IDX_STRING Then
  Begin
    { AX = ptr chaine ASCIIZ }
    EmitInstrAB('MOV', 'DI', 'AX');
    EmitStrLen;
    EmitInstrAB('MOV', 'DX', 'DI');
    EmitWriteFD(1);
  End
  Else If TIdx = TY_IDX_BOOLEAN Then
  Begin
    LblTrue := LabelGen;
    LblDone := LabelGen;
    EmitInstrAB('OR', 'AX', 'AX');
    EmitInstrA('JNZ', LblTrue);
    EmitPrintStr('_JS_FALSE', 1);
    EmitInstrA('JMP', LblDone);
    EmitLabel(LblTrue);
    EmitPrintStr('_JS_TRUE', 1);
    EmitLabel(LblDone);
  End
  Else If TIdx = TY_IDX_NULL Then
    EmitPrintStr('_JS_NULL', 1)
  Else If TIdx = TY_IDX_UNDEF Then
    EmitPrintStr('_JS_UNDEF', 1)
  Else
  Begin
    { Number ou inconnu : convertir en chaine puis afficher }
    EmitInstr('CALL   _JSRT_NUMTOSTR');
    EmitInstrAB('MOV', 'DI', 'AX');
    EmitStrLen;
    EmitInstrAB('MOV', 'DX', 'DI');
    EmitWriteFD(1);
  End;
End;

{ EmitPrintAXFD : comme EmitPrintAX mais pour un fd arbitraire }
Procedure EmitPrintAXFD(TIdx, FD : Integer);
Var
  LblTrue, LblDone : TString;
Begin
  If TIdx = TY_IDX_STRING Then
  Begin
    EmitInstrAB('MOV', 'DI', 'AX');
    EmitStrLen;
    EmitInstrAB('MOV', 'DX', 'DI');
    EmitWriteFD(FD);
  End
  Else If TIdx = TY_IDX_BOOLEAN Then
  Begin
    LblTrue := LabelGen;
    LblDone := LabelGen;
    EmitInstrAB('OR', 'AX', 'AX');
    EmitInstrA('JNZ', LblTrue);
    EmitPrintStr('_JS_FALSE', FD);
    EmitInstrA('JMP', LblDone);
    EmitLabel(LblTrue);
    EmitPrintStr('_JS_TRUE', FD);
    EmitLabel(LblDone);
  End
  Else If TIdx = TY_IDX_NULL Then
    EmitPrintStr('_JS_NULL', FD)
  Else If TIdx = TY_IDX_UNDEF Then
    EmitPrintStr('_JS_UNDEF', FD)
  Else
  Begin
    EmitInstr('CALL   _JSRT_NUMTOSTR');
    EmitInstrAB('MOV', 'DI', 'AX');
    EmitStrLen;
    EmitInstrAB('MOV', 'DX', 'DI');
    EmitWriteFD(FD);
  End;
End;

Procedure EmitRuntime;
Var
  Lbl1, Lbl2, Lbl3, Lbl4 : TString;
Begin
  { Guard : ne pas emettre deux fois }
  If RuntimeEmitted Then Exit;
  RuntimeEmitted := True;

  EmitBlankLine;
  EmitComment('--- runtime core routines ---');

  { _JSRT_NUMTOSTR : entier signe -> ASCII (itoa)
    IN  : AX = nombre (signe 16 bits)
    OUT : AX = ptr chaine ASCIIZ dans _JSRT_NUMBUF
    Preserve : BX, CX }
  EmitLabel('_JSRT_NUMTOSTR');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('LEA', 'DI', '_JSRT_NUMBUF');
  EmitInstrAB('ADD', 'DI', '11');     { pointer vers la fin du buffer }
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0'); { terminateur }
  EmitInstrA('DEC', 'DI');
  EmitInstrAB('XOR', 'CX', 'CX');     { CX = compteur de chiffres }
  EmitInstrAB('MOV', 'BX', 'AX');     { sauver signe }
  EmitInstrAB('OR', 'AX', 'AX');
  Lbl1 := LabelGen; { not negative }
  EmitInstrA('JNS', Lbl1);
  EmitInstr('NEG    AX');
  EmitLabel(Lbl1);
  EmitInstrAB('MOV', 'SI', '10');     { diviseur }
  Lbl1 := LabelGen; { digit loop }
  Lbl2 := LabelGen; { done digits }
  EmitLabel(Lbl1);
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitInstr('DIV    SI');              { AX=quotient, DX=reste }
  EmitInstrAB('ADD', 'DL', '''0''');
  EmitInstrAB('MOV', '[DI]', 'DL');
  EmitInstrA('DEC', 'DI');
  EmitInstrA('INC', 'CX');
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JNZ', Lbl1);
  { Ajouter signe si negatif }
  EmitInstrAB('OR', 'BX', 'BX');
  EmitInstrA('JNS', Lbl2);
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '''-''');
  EmitInstrA('DEC', 'DI');
  EmitLabel(Lbl2);
  EmitInstrA('INC', 'DI');            { DI = debut chaine }
  EmitInstrAB('MOV', 'AX', 'DI');    { AX = ptr resultat }
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');

  { _JSRT_CONCAT : concatenation de chaines
    IN  : AX = ptr chaine gauche, BX = ptr chaine droite
    OUT : AX = ptr _JSRT_STRBUF (resultat concatene) }
  EmitLabel('_JSRT_CONCAT');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('LEA', 'DI', '_JSRT_STRBUF');
  EmitInstrAB('MOV', 'SI', 'AX');    { SI = gauche }
  Lbl1 := LabelGen; { copy left }
  Lbl2 := LabelGen; { copy right }
  Lbl3 := LabelGen; { done }
  EmitLabel(Lbl1);
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', Lbl2);
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl2);
  EmitInstrAB('MOV', 'SI', 'BX');    { SI = droite }
  Lbl2 := LabelGen;
  EmitLabel(Lbl2);
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', Lbl3);
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl3);
  EmitInstrAB('LEA', 'AX', '_JSRT_STRBUF');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');

  { _JSRT_PRINT : ecriture brute sur un handle
    IN  : BX = handle (1=stdout, 2=stderr), DX = ptr buf, CX = longueur
    OUT : AX = nb octets ecrits }
  EmitLabel('_JSRT_PRINT');
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstr('INT    21h');
  EmitInstr('RET');

  { _JSRT_PRINTLN : _JSRT_PRINT + CR LF
    IN  : BX = handle, DX = ptr buf, CX = longueur }
  EmitLabel('_JSRT_PRINTLN');
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstr('INT    21h');
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('LEA', 'DX', '_JS_CRLF');
  EmitInstrAB('MOV', 'CX', '2');
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstr('INT    21h');
  EmitInstrA('POP', 'CX');
  EmitInstr('RET');

  { _JSRT_TYPEOF : retourne ptr chaine du type
    IN  : AX = valeur, BX = type index (compile-time)
    OUT : AX = ptr chaine type (ASCIIZ)
    Types: 0=number, 1=string, 2=boolean, 3=object, 4=undefined, 5=function }
  EmitLabel('_JSRT_TYPEOF');
  Lbl1 := LabelGen; { string }
  Lbl2 := LabelGen; { boolean }
  Lbl3 := LabelGen; { object }
  Lbl4 := LabelGen; { undefined }
  EmitInstrAB('CMP', 'BX', IntToStr(TY_IDX_STRING));
  EmitInstrA('JE', Lbl1);
  EmitInstrAB('CMP', 'BX', IntToStr(TY_IDX_BOOLEAN));
  EmitInstrA('JE', Lbl2);
  EmitInstrAB('CMP', 'BX', IntToStr(TY_IDX_OBJECT));
  EmitInstrA('JE', Lbl3);
  EmitInstrAB('CMP', 'BX', IntToStr(TY_IDX_UNDEF));
  EmitInstrA('JE', Lbl4);
  { default : "number" }
  EmitInstrAB('LEA', 'AX', '_JS_TYP_NUMBER');
  EmitInstr('RET');
  EmitLabel(Lbl1);
  EmitInstrAB('LEA', 'AX', '_JS_TYP_STRING');
  EmitInstr('RET');
  EmitLabel(Lbl2);
  EmitInstrAB('LEA', 'AX', '_JS_TYP_BOOLEAN');
  EmitInstr('RET');
  EmitLabel(Lbl3);
  EmitInstrAB('LEA', 'AX', '_JS_TYP_OBJECT');
  EmitInstr('RET');
  EmitLabel(Lbl4);
  EmitInstrAB('LEA', 'AX', '_JS_UNDEF');
  EmitInstr('RET');

  { _JSRT_TRUTHY : conversion en booleen (truthiness)
    IN  : AX = valeur, BX = type index
    OUT : AX = 0 (falsy) ou 1 (truthy)
    Falsy : 0, '', null, undefined, false, NaN
    Truthy : tout le reste }
  EmitLabel('_JSRT_TRUTHY');
  Lbl1 := LabelGen; { string check }
  Lbl2 := LabelGen; { truthy }
  Lbl3 := LabelGen; { falsy }
  EmitInstrAB('CMP', 'BX', IntToStr(TY_IDX_UNDEF));
  EmitInstrA('JE', Lbl3);
  EmitInstrAB('CMP', 'BX', IntToStr(TY_IDX_NULL));
  EmitInstrA('JE', Lbl3);
  EmitInstrAB('CMP', 'BX', IntToStr(TY_IDX_STRING));
  EmitInstrA('JE', Lbl1);
  { number/boolean/object : falsy si AX=0 }
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JZ', Lbl3);
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl1); { string : falsy si premier octet = 0 (chaine vide) }
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', Lbl3);
  EmitLabel(Lbl2);
  EmitInstrAB('MOV', 'AX', '1');
  EmitInstr('RET');
  EmitLabel(Lbl3);
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstr('RET');

  { _JSRT_STRTRUTHY : truthiness pour chaine
    IN  : SI = ptr chaine (ou AX = ptr)
    OUT : AX = 1 sauf si chaine vide ou "0" }
  EmitLabel('_JSRT_STRTRUTHY');
  Lbl1 := LabelGen; { truthy }
  Lbl2 := LabelGen; { falsy }
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', Lbl2);
  { Verifier "0" : un seul caractere '0' suivi de NUL }
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '''0''');
  EmitInstrA('JNE', Lbl1);
  EmitInstrAB('CMP', 'BYTE PTR [SI+1]', '0');
  EmitInstrA('JE', Lbl2);
  EmitLabel(Lbl1);
  EmitInstrAB('MOV', 'AX', '1');
  EmitInstr('RET');
  EmitLabel(Lbl2);
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstr('RET');

  { _JSRT_ALLOC : allocateur heap statique
    IN  : CX = nombre d octets a allouer
    OUT : AX = ptr dans _JS_HEAP }
  EmitLabel('_JSRT_ALLOC');
  EmitInstrA('PUSH', 'BX');
  EmitInstrAB('MOV', 'BX', '[_JS_HEAPTOP]');
  EmitInstrAB('LEA', 'AX', '_JS_HEAP');
  EmitInstrAB('ADD', 'AX', 'BX');
  EmitInstrAB('ADD', 'BX', 'CX');
  EmitInstrAB('MOV', '[_JS_HEAPTOP]', 'BX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');

  EmitBlankLine;
  EmitComment('--- runtime array routines ---');

  { _JSRT_ARRPUSH : SI=ptr tableau, AX=valeur a ajouter }
  { Resultat : AX = nouveau count }
  EmitLabel('_JSRT_ARRPUSH');
  EmitInstrAB('MOV', 'BX', '[SI]');
  EmitInstrAB('MOV', 'DI', 'BX');
  EmitInstrAB('SHL', 'DI', '1');
  EmitInstrAB('ADD', 'DI', '2');
  EmitInstrAB('ADD', 'DI', 'SI');
  EmitInstrAB('MOV', '[DI]', 'AX');
  EmitInstrA('INC', 'BX');
  EmitInstrAB('MOV', '[SI]', 'BX');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstr('RET');

  { _JSRT_ARRPOP : SI=ptr tableau }
  { Resultat : AX = dernier element }
  EmitLabel('_JSRT_ARRPOP');
  EmitInstrAB('MOV', 'BX', '[SI]');
  EmitInstrAB('OR', 'BX', 'BX');
  Lbl1 := LabelGen;
  EmitInstrA('JZ', Lbl1);
  EmitInstrA('DEC', 'BX');
  EmitInstrAB('MOV', '[SI]', 'BX');
  EmitInstrAB('MOV', 'DI', 'BX');
  EmitInstrAB('SHL', 'DI', '1');
  EmitInstrAB('ADD', 'DI', '2');
  EmitInstrAB('ADD', 'DI', 'SI');
  EmitInstrAB('MOV', 'AX', '[DI]');
  EmitInstr('RET');
  EmitLabel(Lbl1);
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstr('RET');

  { _JSRT_ARRSHIFT : SI=ptr tableau }
  { Resultat : AX = premier element, decale le reste }
  EmitLabel('_JSRT_ARRSHIFT');
  EmitInstrAB('MOV', 'CX', '[SI]');
  EmitInstrAB('OR', 'CX', 'CX');
  Lbl1 := LabelGen;
  EmitInstrA('JZ', Lbl1);
  EmitInstrAB('MOV', 'AX', '[SI+2]');
  EmitInstrA('PUSH', 'AX');
  EmitInstrA('DEC', 'CX');
  EmitInstrAB('MOV', '[SI]', 'CX');
  EmitInstrAB('LEA', 'DI', '[SI+2]');
  EmitInstrAB('LEA', 'BX', '[SI+4]');
  Lbl2 := LabelGen;
  Lbl3 := LabelGen;
  EmitLabel(Lbl2);
  EmitInstrAB('OR', 'CX', 'CX');
  EmitInstrA('JZ', Lbl3);
  EmitInstrAB('MOV', 'AX', '[BX]');
  EmitInstrAB('MOV', '[DI]', 'AX');
  EmitInstrAB('ADD', 'DI', '2');
  EmitInstrAB('ADD', 'BX', '2');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl3);
  EmitInstrA('POP', 'AX');
  EmitInstr('RET');
  EmitLabel(Lbl1);
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstr('RET');

  { _JSRT_ARRUNSHIFT : SI=ptr tableau, AX=valeur a inserer en tete }
  { Resultat : AX = nouveau count }
  EmitLabel('_JSRT_ARRUNSHIFT');
  EmitInstrA('PUSH', 'AX');
  EmitInstrAB('MOV', 'CX', '[SI]');
  EmitInstrAB('MOV', 'DI', 'CX');
  EmitInstrAB('SHL', 'DI', '1');
  EmitInstrAB('ADD', 'DI', 'SI');
  EmitInstrAB('ADD', 'DI', '2');
  Lbl1 := LabelGen;
  Lbl2 := LabelGen;
  EmitLabel(Lbl1);
  EmitInstrAB('OR', 'CX', 'CX');
  EmitInstrA('JZ', Lbl2);
  EmitInstrAB('MOV', 'AX', '[DI-2]');
  EmitInstrAB('MOV', '[DI]', 'AX');
  EmitInstrAB('SUB', 'DI', '2');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl2);
  EmitInstrA('POP', 'AX');
  EmitInstrAB('MOV', '[SI+2]', 'AX');
  EmitInstrAB('MOV', 'AX', '[SI]');
  EmitInstrA('INC', 'AX');
  EmitInstrAB('MOV', '[SI]', 'AX');
  EmitInstr('RET');

  { _JSRT_ARRIDXOF : SI=ptr tableau, BX=valeur cherchee }
  { Resultat : AX = index (0-based) ou -1 si non trouve }
  EmitLabel('_JSRT_ARRIDXOF');
  EmitInstrAB('MOV', 'CX', '[SI]');
  EmitInstrAB('ADD', 'SI', '2');
  EmitInstrAB('XOR', 'DX', 'DX');
  Lbl1 := LabelGen;
  Lbl2 := LabelGen;
  Lbl3 := LabelGen;
  EmitLabel(Lbl1);
  EmitInstrAB('OR', 'CX', 'CX');
  EmitInstrA('JZ', Lbl2);
  EmitInstrAB('CMP', '[SI]', 'BX');
  EmitInstrA('JE', Lbl3);
  EmitInstrAB('ADD', 'SI', '2');
  EmitInstrA('INC', 'DX');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl3);
  EmitInstrAB('MOV', 'AX', 'DX');
  EmitInstr('RET');
  EmitLabel(Lbl2);
  EmitInstrAB('MOV', 'AX', '-1');
  EmitInstr('RET');

  { _JSRT_ARRREV : SI=ptr tableau }
  { Inverse in-place, retourne AX=SI }
  EmitLabel('_JSRT_ARRREV');
  EmitInstrAB('MOV', 'CX', '[SI]');
  EmitInstrAB('CMP', 'CX', '2');
  Lbl1 := LabelGen;
  EmitInstrA('JL', Lbl1);
  EmitInstrAB('LEA', 'BX', '[SI+2]');
  EmitInstrAB('MOV', 'DI', 'CX');
  EmitInstrAB('SHL', 'DI', '1');
  EmitInstrAB('ADD', 'DI', 'SI');
  EmitInstrAB('SUB', 'DI', '2');
  Lbl2 := LabelGen;
  Lbl3 := LabelGen;
  EmitLabel(Lbl2);
  EmitInstrAB('CMP', 'BX', 'DI');
  EmitInstrA('JGE', Lbl3);
  EmitInstrAB('MOV', 'AX', '[BX]');
  EmitInstrAB('MOV', 'DX', '[DI]');
  EmitInstrAB('MOV', '[BX]', 'DX');
  EmitInstrAB('MOV', '[DI]', 'AX');
  EmitInstrAB('ADD', 'BX', '2');
  EmitInstrAB('SUB', 'DI', '2');
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl3);
  EmitLabel(Lbl1);
  EmitInstrAB('MOV', 'AX', 'SI');
  EmitInstr('RET');

  { _JSRT_ARRSORT : SI=ptr tableau }
  { Tri a bulles numerique ascendant in-place, retourne AX=SI }
  EmitLabel('_JSRT_ARRSORT');
  EmitInstrA('PUSH', 'SI');
  Lbl1 := LabelGen;
  Lbl2 := LabelGen;
  Lbl3 := LabelGen;
  Lbl4 := LabelGen;
  EmitLabel(Lbl1);
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitInstrAB('MOV', 'CX', '[SI]');
  EmitInstrA('DEC', 'CX');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JLE', Lbl4);
  EmitInstrAB('LEA', 'BX', '[SI+2]');
  EmitLabel(Lbl2);
  EmitInstrAB('MOV', 'AX', '[BX]');
  EmitInstrAB('CMP', 'AX', '[BX+2]');
  EmitInstrA('JLE', Lbl3);
  EmitInstrAB('MOV', 'DI', '[BX+2]');
  EmitInstrAB('MOV', '[BX]', 'DI');
  EmitInstrAB('MOV', '[BX+2]', 'AX');
  EmitInstrAB('MOV', 'DX', '1');
  EmitLabel(Lbl3);
  EmitInstrAB('ADD', 'BX', '2');
  EmitInstrA('DEC', 'CX');
  EmitInstrAB('OR', 'CX', 'CX');
  EmitInstrA('JNZ', Lbl2);
  EmitInstrAB('OR', 'DX', 'DX');
  EmitInstrA('JNZ', Lbl1);
  EmitLabel(Lbl4);
  EmitInstrA('POP', 'AX');
  EmitInstr('RET');

  { ============================================================
    Routines runtime objet
    ============================================================ }
  EmitBlankLine;
  EmitComment('--- runtime object routines ---');

  { _JSRT_STRCMP : compare deux chaines ASCIIZ
    IN  : SI = chaine 1, DI = chaine 2
    OUT : AX = 0 si egales, 1 sinon
    Preserve : SI, DI }
  EmitLabel('_JSRT_STRCMP');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  Lbl1 := LabelGen; { loop }
  Lbl2 := LabelGen; { equal }
  Lbl3 := LabelGen; { not equal }
  EmitLabel(Lbl1);
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '[DI]');
  EmitInstrA('JNE', Lbl3);
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', Lbl2);
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl2);
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitLabel(Lbl3);
  EmitInstrAB('MOV', 'AX', '1');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');

  { _JSRT_OBJGET : cherche une propriete dans un objet
    IN  : BX = ptr objet [n][K0][V0][K1][V1]...
           DI = ptr chaine cle a chercher
    OUT : AX = valeur de la propriete (0 si non trouvee) }
  EmitLabel('_JSRT_OBJGET');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'BX');
  EmitInstrAB('MOV', 'CX', '[BX]');    { CX = n_props }
  EmitInstrAB('ADD', 'BX', '2');        { BX -> premier K0 }
  Lbl1 := LabelGen; { loop }
  Lbl2 := LabelGen; { found }
  Lbl3 := LabelGen; { not found }
  EmitLabel(Lbl1);
  EmitInstrAB('OR', 'CX', 'CX');
  EmitInstrA('JZ', Lbl3);
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('MOV', 'SI', '[BX]');     { SI = ptr cle stockee }
  EmitInstrA('CALL', '_JSRT_STRCMP');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'CX');
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JZ', Lbl2);              { AX=0 -> egal -> trouve }
  EmitInstrAB('ADD', 'BX', '4');        { paire suivante }
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl2);
  EmitInstrAB('MOV', 'AX', '[BX+2]');  { AX = valeur }
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'CX');
  EmitInstr('RET');
  EmitLabel(Lbl3);
  EmitInstrAB('XOR', 'AX', 'AX');      { non trouve -> 0 }
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'CX');
  EmitInstr('RET');

  { _JSRT_OBJSET : affecte une propriete dans un objet
    IN  : BX = ptr objet, DI = ptr chaine cle, AX = valeur
    OUT : AX = valeur affectee
    Met a jour la paire existante ou ajoute une nouvelle paire }
  EmitLabel('_JSRT_OBJSET');
  EmitInstrAB('MOV', 'DX', 'AX');      { DX = valeur a stocker }
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('MOV', 'CX', '[BX]');    { CX = n_props }
  EmitInstrA('PUSH', 'BX');             { sauver base }
  EmitInstrAB('ADD', 'BX', '2');        { BX -> premier K0 }
  Lbl1 := LabelGen; { loop }
  Lbl2 := LabelGen; { found }
  Lbl3 := LabelGen; { append }
  EmitLabel(Lbl1);
  EmitInstrAB('OR', 'CX', 'CX');
  EmitInstrA('JZ', Lbl3);
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('MOV', 'SI', '[BX]');     { SI = cle stockee }
  EmitInstrA('CALL', '_JSRT_STRCMP');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'CX');
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JZ', Lbl2);
  EmitInstrAB('ADD', 'BX', '4');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl2);                       { cle trouvee -> maj valeur }
  EmitInstrAB('MOV', '[BX+2]', 'DX');
  EmitInstrAB('MOV', 'AX', 'DX');
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'CX');
  EmitInstr('RET');
  EmitLabel(Lbl3);                       { cle non trouvee -> ajouter }
  EmitInstrAB('MOV', '[BX]', 'DI');     { stocker ptr cle }
  EmitInstrAB('MOV', '[BX+2]', 'DX');   { stocker valeur }
  EmitInstrA('POP', 'BX');              { BX = base objet }
  EmitInstrAB('MOV', 'CX', '[BX]');
  EmitInstrA('INC', 'CX');
  EmitInstrAB('MOV', '[BX]', 'CX');    { incrementer n_props }
  EmitInstrAB('MOV', 'AX', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstr('RET');

  { _JSRT_OBJKEYS : retourne un tableau des cles d un objet
    IN  : BX = ptr objet
    OUT : AX = ptr tableau (dans _JSRT_OKBUF) }
  EmitLabel('_JSRT_OBJKEYS');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('MOV', 'CX', '[BX]');       { CX = n_props }
  EmitInstrAB('LEA', 'SI', '[BX+2]');     { SI = premiere paire }
  EmitInstrAB('LEA', 'DI', '_JSRT_OKBUF');
  EmitInstrAB('MOV', '[DI]', 'CX');       { stocker count }
  EmitInstrAB('ADD', 'DI', '2');
  Lbl1 := LabelGen; { loop }
  Lbl2 := LabelGen; { done }
  EmitLabel(Lbl1);
  EmitInstrAB('OR', 'CX', 'CX');
  EmitInstrA('JZ', Lbl2);
  EmitInstrAB('MOV', 'AX', '[SI]');       { ptr cle }
  EmitInstrAB('MOV', '[DI]', 'AX');
  EmitInstrAB('ADD', 'SI', '4');           { paire suivante }
  EmitInstrAB('ADD', 'DI', '2');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl2);
  EmitInstrAB('LEA', 'AX', '_JSRT_OKBUF');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'CX');
  EmitInstr('RET');

  { _JSRT_OBJASSIGN : copie les proprietes de src vers dest
    IN  : BX = dest, SI = src
    OUT : AX = dest ptr }
  EmitLabel('_JSRT_OBJASSIGN');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'BX');
  EmitInstrAB('MOV', 'CX', '[SI]');       { CX = n_props src }
  EmitInstrAB('ADD', 'SI', '2');
  Lbl1 := LabelGen; { loop }
  Lbl2 := LabelGen; { done }
  EmitLabel(Lbl1);
  EmitInstrAB('OR', 'CX', 'CX');
  EmitInstrA('JZ', Lbl2);
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'BX');
  EmitInstrAB('MOV', 'DI', '[SI]');       { DI = ptr cle src }
  EmitInstrAB('MOV', 'AX', '[SI+2]');     { AX = valeur src }
  EmitInstrA('CALL', '_JSRT_OBJSET');
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'CX');
  EmitInstrAB('ADD', 'SI', '4');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl2);
  EmitInstrA('POP', 'BX');
  EmitInstrAB('MOV', 'AX', 'BX');        { retourner dest }
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'CX');
  EmitInstr('RET');

  (* ---- routines regexp ---- *)
  EmitBlankLine;
  EmitComment('--- runtime regexp routines ---');

  { _JSRT_REPARSE : utilitaire interne
    Extrait le pattern pur de DI (ptr regexp = pattern + Chr(1) + flags)
    Avance DI jusqu a sauter le Chr(1) dans le buffer regexp
    Ne modifie que DI (pointe apres Chr(1))
    Pattern pur reste a l adresse originale de DI
    Retourne la longueur du pattern dans CX }
  EmitLabel('_JSRT_REPARSE');
  EmitInstrA('PUSH', 'BX');
  EmitInstrAB('MOV', 'BX', 'DI');  { BX = debut pattern }
  Lbl1 := LabelGen; { scan loop }
  Lbl2 := LabelGen; { done }
  EmitLabel(Lbl1);
  EmitInstrAB('MOV', 'AL', '[BX]');
  EmitInstrAB('CMP', 'AL', '1');   { Chr(1) = separateur }
  EmitInstrA('JZ', Lbl2);
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', Lbl2);
  EmitInstrA('INC', 'BX');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl2);
  EmitInstrAB('MOV', 'CX', 'BX');
  EmitInstrAB('SUB', 'CX', 'DI');  { CX = longueur pattern }
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');

  { _JSRT_REMATCH : recherche de sous-chaine (strstr basique)
    IN  : SI = ptr string, DI = ptr regexp (pattern + Chr(1) + flags)
    OUT : AX = 1 si trouve, 0 sinon }
  EmitLabel('_JSRT_REMATCH');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrA('CALL', '_JSRT_REPARSE'); { CX = len pattern, DI = ptr pat }
  EmitInstrAB('OR', 'CX', 'CX');
  Lbl1 := LabelGen; { outer loop }
  Lbl2 := LabelGen; { inner loop }
  Lbl3 := LabelGen; { found }
  Lbl4 := LabelGen; { not found }
  EmitInstrA('JZ', Lbl3);           { pattern vide -> match }
  EmitLabel(Lbl1);                   { pour chaque position dans SI }
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', Lbl4);           { fin de chaine -> pas trouve }
  EmitInstrA('PUSH', 'SI');          { sauver position }
  EmitInstrA('PUSH', 'DI');          { sauver debut pattern }
  EmitInstrA('PUSH', 'CX');          { sauver len }
  EmitInstrAB('MOV', 'DX', 'CX');   { DX = compteur }
  EmitLabel(Lbl2);                   { comparer char par char }
  EmitInstrAB('OR', 'DX', 'DX');
  EmitInstrA('JZ', Lbl3 + 'B');     { tous chars matches -> found }
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '[DI]');
  EmitInstrA('JNZ', Lbl4 + 'B');    { mismatch -> avancer }
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'DX');
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl3 + 'B');             { match complet a cette position }
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstrA('JMP', Lbl3);
  EmitLabel(Lbl4 + 'B');             { mismatch -> avancer position }
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl3);                   { found }
  EmitInstrAB('MOV', 'AX', '1');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitLabel(Lbl4);                   { not found }
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');

  { _JSRT_REINDEX : retourne la position de la 1ere occurrence
    IN  : SI = ptr string, DI = ptr regexp (pattern + Chr(1) + flags)
    OUT : AX = index (0-based) ou -1 si non trouve }
  EmitLabel('_JSRT_REINDEX');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('MOV', 'BX', 'SI');   { BX = debut chaine originale }
  EmitInstrA('CALL', '_JSRT_REPARSE'); { CX = len pattern }
  Lbl1 := LabelGen; { outer loop }
  Lbl2 := LabelGen; { inner loop }
  Lbl3 := LabelGen; { found }
  Lbl4 := LabelGen; { not found }
  EmitInstrAB('OR', 'CX', 'CX');
  EmitInstrA('JZ', Lbl3);
  EmitLabel(Lbl1);
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', Lbl4);
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('MOV', 'DX', 'CX');
  EmitLabel(Lbl2);
  EmitInstrAB('OR', 'DX', 'DX');
  EmitInstrA('JZ', Lbl3 + 'B');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '[DI]');
  EmitInstrA('JNZ', Lbl4 + 'B');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'DX');
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl3 + 'B');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstrA('JMP', Lbl3);
  EmitLabel(Lbl4 + 'B');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl3);
  EmitInstrAB('MOV', 'AX', 'SI');
  EmitInstrAB('SUB', 'AX', 'BX');   { AX = index 0-based }
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitLabel(Lbl4);
  EmitInstrAB('MOV', 'AX', '-1');   { pas trouve }
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');

  { _JSRT_REEXEC : exec simplifie (retourne ptr string si match, 0 sinon)
    IN  : SI = ptr string, DI = ptr regexp
    OUT : AX = ptr sous-chaine trouvee ou 0 }
  EmitLabel('_JSRT_REEXEC');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('CALL', '_JSRT_REMATCH');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstrAB('OR', 'AX', 'AX');
  Lbl1 := LabelGen;
  EmitInstrA('JZ', Lbl1);
  EmitInstrAB('MOV', 'AX', 'SI');   { retourner ptr string }
  EmitInstr('RET');
  EmitLabel(Lbl1);
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstr('RET');

  { _JSRT_RESUB : substitution de la 1ere occurrence
    IN  : SI = ptr string source, DI = ptr pattern (regexp format)
          BX = ptr remplacement
    OUT : AX = ptr _JSRT_REBUF (resultat)
    Algorithme : copier src vers REBUF, quand on trouve pattern on copie
                 le remplacement a la place, puis on continue avec le reste.
    On utilise la pile pour sauvegarder les params et des registres de travail. }
  EmitLabel('_JSRT_RESUB');
  EmitInstrA('PUSH', 'BX');       { [SP+8] = repl ptr }
  EmitInstrA('PUSH', 'DI');       { [SP+6] = pattern ptr }
  EmitInstrA('PUSH', 'SI');       { [SP+4] = src ptr }
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrA('CALL', '_JSRT_REPARSE');   { CX = len pattern, DI unchanged }
  EmitInstrAB('MOV', 'DX', 'CX');       { DX = pattern length }
  EmitInstrAB('LEA', 'BX', '_JSRT_REBUF'); { BX = dest ptr }
  Lbl1 := LabelGen; { main copy loop }
  Lbl2 := LabelGen; { try match }
  Lbl3 := LabelGen; { match found - copy repl }
  Lbl4 := LabelGen; { done }
  EmitLabel(Lbl1);
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', Lbl4);           { fin de src -> terminaison }
  { Essayer de matcher le pattern a cette position }
  EmitInstrAB('OR', 'DX', 'DX');
  EmitInstrA('JZ', Lbl2 + 'C');     { pattern vide -> copier char }
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('MOV', 'CX', 'DX');
  EmitLabel(Lbl2);
  EmitInstrAB('OR', 'CX', 'CX');
  EmitInstrA('JZ', Lbl3);           { tous chars matches }
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '[DI]');
  EmitInstrA('JNZ', Lbl2 + 'N');    { mismatch }
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl2 + 'N');            { mismatch -> restaurer et copier 1 char }
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitLabel(Lbl2 + 'C');            { copier 1 char de src vers dest }
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[BX]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'BX');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl3);                   { match trouve! }
  EmitInstrA('POP', 'CX');          { restaurer CX }
  EmitInstrA('POP', 'DI');          { restaurer DI }
  EmitInstrA('POP', 'AX');          { jeter ancien SI (on garde le nouveau) }
  { SI pointe maintenant apres le match - copier le remplacement }
  EmitInstrA('PUSH', 'SI');          { sauver SI (suite apres match) }
  EmitInstrAB('MOV', 'SI', '[SP+10]'); { SI = ptr remplacement (BX initial) }
  Lbl3 := LabelGen; { copy repl loop }
  EmitLabel(Lbl3);
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', Lbl3 + 'D');
  EmitInstrAB('MOV', '[BX]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'BX');
  EmitInstrA('JMP', Lbl3);
  EmitLabel(Lbl3 + 'D');
  EmitInstrA('POP', 'SI');           { SI = suite source apres match }
  { Copier le reste de la source sans plus chercher }
  Lbl3 := LabelGen; { copy rest loop }
  EmitLabel(Lbl3);
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', Lbl4);
  EmitInstrAB('MOV', '[BX]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'BX');
  EmitInstrA('JMP', Lbl3);
  EmitLabel(Lbl4);                   { terminer la chaine dest }
  EmitInstrAB('MOV', 'BYTE PTR [BX]', '0');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BX');
  EmitInstrAB('LEA', 'AX', '_JSRT_REBUF');
  EmitInstr('RET');

  EmitBlankLine;
  EmitComment('--- runtime string / math / number routines ---');

  { _JSRT_STRLEN : SI = ptr chaine ASCIIZ -> AX = longueur }
  EmitLabel('_JSRT_STRLEN');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('XOR', 'AX', 'AX');
  Lbl1 := LabelGen;
  Lbl2 := LabelGen;
  EmitLabel(Lbl1);
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', Lbl2);
  EmitInstrA('INC', 'AX');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl2);
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');

  { _JSRT_STRINDEXOF : SI = string, DI = substring -> AX = index ou -1 }
  EmitLabel('_JSRT_STRINDEXOF');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('MOV', 'BX', 'SI');  { BX = debut original }
  Lbl1 := LabelGen; { boucle exterieure }
  Lbl2 := LabelGen; { boucle interieure }
  Lbl3 := LabelGen; { trouve }
  Lbl4 := LabelGen; { pas trouve }
  EmitLabel(Lbl1);
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', Lbl4);
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitLabel(Lbl2);
  EmitInstrAB('CMP', 'BYTE PTR [DI]', '0');
  EmitInstrA('JE', Lbl3);
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '[DI]');
  EmitInstrA('JNE', Lbl2 + 'N');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl3);  { trouvé }
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'AX');  { AX = position de match }
  EmitInstrAB('SUB', 'AX', 'BX');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitLabel(Lbl2 + 'N');  { mismatch }
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl4);  { pas trouvé }
  EmitInstrAB('MOV', 'AX', '0FFFFh');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');

  { _JSRT_STRLASTIDX : SI = string, DI = substring -> AX = last index ou -1 }
  EmitLabel('_JSRT_STRLASTIDX');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('MOV', 'BX', 'SI');
  EmitInstrAB('MOV', 'DX', '0FFFFh');  { DX = meilleur index = -1 }
  Lbl1 := LabelGen;
  Lbl2 := LabelGen;
  Lbl3 := LabelGen;
  Lbl4 := LabelGen;
  EmitLabel(Lbl1);
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', Lbl4);
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitLabel(Lbl2);
  EmitInstrAB('CMP', 'BYTE PTR [DI]', '0');
  EmitInstrA('JE', Lbl3);
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '[DI]');
  EmitInstrA('JNE', Lbl2 + 'N');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl3);  { match }
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'AX');
  EmitInstrAB('SUB', 'AX', 'BX');
  EmitInstrAB('MOV', 'DX', 'AX');  { DX = dernier index trouvé }
  EmitInstrAB('ADD', 'AX', 'BX');
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl2 + 'N');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl4);
  EmitInstrAB('MOV', 'AX', 'DX');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');

  { _JSRT_STRSTARTW : SI = string, DI = prefix -> AX = 0|1 }
  EmitLabel('_JSRT_STRSTARTW');
  Lbl1 := LabelGen;
  Lbl2 := LabelGen;
  EmitLabel(Lbl1);
  EmitInstrAB('CMP', 'BYTE PTR [DI]', '0');
  EmitInstrA('JE', Lbl1 + 'Y');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '[DI]');
  EmitInstrA('JNE', Lbl2);
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl1 + 'Y');
  EmitInstrAB('MOV', 'AX', '1');
  EmitInstr('RET');
  EmitLabel(Lbl2);
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstr('RET');

  { _JSRT_STRENDW : SI = string, DI = suffix -> AX = 0|1 }
  EmitLabel('_JSRT_STRENDW');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  { calculer strlen(SI) }
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('CALL', '_JSRT_STRLEN');
  EmitInstrAB('MOV', 'BX', 'AX');  { BX = len(str) }
  EmitInstrA('POP', 'SI');
  { calculer strlen(DI) }
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', 'DI');
  EmitInstrA('CALL', '_JSRT_STRLEN');
  EmitInstrAB('MOV', 'CX', 'AX');  { CX = len(suffix) }
  EmitInstrA('POP', 'SI');
  Lbl1 := LabelGen;
  { si suffix plus long que string -> false }
  EmitInstrAB('CMP', 'CX', 'BX');
  EmitInstrA('JA', Lbl1);
  { pointer SI vers la fin - len(suffix) }
  EmitInstrAB('SUB', 'BX', 'CX');
  EmitInstrAB('ADD', 'SI', 'BX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstrA('JMP', '_JSRT_STRSTARTW');  { reutilise startsWith }
  EmitLabel(Lbl1);
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');

  { _JSRT_STRSLICE : SI = string, BX = start, CX = end -> AX = ptr _JSRT_STRBUF }
  EmitLabel('_JSRT_STRSLICE');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('LEA', 'DI', '_JSRT_STRBUF');
  { avancer SI de BX caracteres }
  EmitInstrAB('MOV', 'DX', 'BX');  { DX = start counter }
  Lbl1 := LabelGen;
  Lbl2 := LabelGen;
  Lbl3 := LabelGen;
  EmitLabel(Lbl1);
  EmitInstrAB('OR', 'DX', 'DX');
  EmitInstrA('JZ', Lbl2);
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', Lbl3);
  EmitInstrA('INC', 'SI');
  EmitInstrA('DEC', 'DX');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl2);  { copier de BX a CX }
  EmitInstrAB('CMP', 'BX', 'CX');
  EmitInstrA('JGE', Lbl3);
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', Lbl3);
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('INC', 'BX');
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl3);
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('LEA', 'AX', '_JSRT_STRBUF');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'DI');
  EmitInstr('RET');

  { _JSRT_STRTOUPPER : SI = string -> AX = ptr _JSRT_STRBUF (uppercased) }
  EmitLabel('_JSRT_STRTOUPPER');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('LEA', 'DI', '_JSRT_STRBUF');
  Lbl1 := LabelGen;
  Lbl2 := LabelGen;
  EmitLabel(Lbl1);
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', Lbl2);
  EmitInstrAB('CMP', 'AL', '''a''');
  EmitInstrA('JB', Lbl1 + 'C');
  EmitInstrAB('CMP', 'AL', '''z''');
  EmitInstrA('JA', Lbl1 + 'C');
  EmitInstrAB('SUB', 'AL', '32');
  EmitLabel(Lbl1 + 'C');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl2);
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('LEA', 'AX', '_JSRT_STRBUF');
  EmitInstrA('POP', 'DI');
  EmitInstr('RET');

  { _JSRT_STRTOLOWER : SI = string -> AX = ptr _JSRT_STRBUF (lowercased) }
  EmitLabel('_JSRT_STRTOLOWER');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('LEA', 'DI', '_JSRT_STRBUF');
  Lbl1 := LabelGen;
  Lbl2 := LabelGen;
  EmitLabel(Lbl1);
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', Lbl2);
  EmitInstrAB('CMP', 'AL', '''A''');
  EmitInstrA('JB', Lbl1 + 'C');
  EmitInstrAB('CMP', 'AL', '''Z''');
  EmitInstrA('JA', Lbl1 + 'C');
  EmitInstrAB('ADD', 'AL', '32');
  EmitLabel(Lbl1 + 'C');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl2);
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('LEA', 'AX', '_JSRT_STRBUF');
  EmitInstrA('POP', 'DI');
  EmitInstr('RET');

  { _JSRT_STRTRIM : SI = string -> AX = ptr _JSRT_STRBUF (trimmed) }
  EmitLabel('_JSRT_STRTRIM');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'BX');
  Lbl1 := LabelGen;
  Lbl2 := LabelGen;
  Lbl3 := LabelGen;
  { Skip leading spaces/tabs }
  EmitLabel(Lbl1);
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '32');
  EmitInstrA('JE', Lbl1 + 'S');
  EmitInstrAB('CMP', 'AL', '9');
  EmitInstrA('JE', Lbl1 + 'S');
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl1 + 'S');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl2);
  { Copy to buffer }
  EmitInstrAB('LEA', 'DI', '_JSRT_STRBUF');
  EmitInstrAB('MOV', 'BX', 'DI');  { BX = start of buffer }
  Lbl2 := LabelGen;
  EmitLabel(Lbl2);
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', Lbl3);
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl3);
  { Remove trailing spaces: walk back from DI }
  Lbl3 := LabelGen;
  EmitLabel(Lbl3);
  EmitInstrA('DEC', 'DI');
  EmitInstrAB('CMP', 'DI', 'BX');
  EmitInstrA('JB', Lbl3 + 'D');
  EmitInstrAB('CMP', 'BYTE PTR [DI]', '32');
  EmitInstrA('JE', Lbl3);
  EmitInstrAB('CMP', 'BYTE PTR [DI]', '9');
  EmitInstrA('JE', Lbl3);
  EmitLabel(Lbl3 + 'D');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('LEA', 'AX', '_JSRT_STRBUF');
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'DI');
  EmitInstr('RET');

  { _JSRT_STRSPLIT : SI = string, DI = separator -> AX = ptr _JSRT_SPLITBUF
    Format resultat : [count, ptr1, ptr2, ...] (pointeurs dans la chaine source) }
  EmitLabel('_JSRT_STRSPLIT');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('LEA', 'BX', '_JSRT_SPLITBUF');
  EmitInstrAB('MOV', 'WORD PTR [BX]', '0');  { count = 0 }
  EmitInstrAB('ADD', 'BX', '2');  { skip count field }
  { Calculer longueur du separateur }
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', 'DI');
  EmitInstrA('CALL', '_JSRT_STRLEN');
  EmitInstrAB('MOV', 'DX', 'AX');  { DX = sep len }
  EmitInstrA('POP', 'SI');
  Lbl1 := LabelGen;
  Lbl2 := LabelGen;
  Lbl3 := LabelGen;
  Lbl4 := LabelGen;
  { Ajouter premier element }
  EmitInstrAB('MOV', '[BX]', 'SI');
  EmitInstrAB('ADD', 'BX', '2');
  EmitInstrA('PUSH', 'AX');
  EmitInstrAB('LEA', 'AX', '_JSRT_SPLITBUF');
  EmitInstrAB('MOV', 'CX', 'AX');
  EmitInstrA('POP', 'AX');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', 'CX');
  EmitInstrAB('MOV', 'AX', '[SI]');
  EmitInstrA('INC', 'AX');
  EmitInstrAB('MOV', '[SI]', 'AX');
  EmitInstrA('POP', 'SI');
  EmitLabel(Lbl1);  { boucle principale }
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', Lbl4);
  { Tester si separateur a cette position }
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('MOV', 'CX', 'DX');  { CX = sep len }
  EmitLabel(Lbl2);
  EmitInstrAB('OR', 'CX', 'CX');
  EmitInstrA('JZ', Lbl3);  { match complet }
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '[DI]');
  EmitInstrA('JNE', Lbl2 + 'N');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl2 + 'N');  { pas de match }
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl3);  { match trouvé -> couper }
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'AX');  { jeter ancien SI }
  { SI pointe après le separateur; mettre NUL avant }
  EmitInstrAB('MOV', '[BX]', 'SI');  { ajouter nouvel element }
  EmitInstrAB('ADD', 'BX', '2');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', 'CX');
  EmitInstrAB('MOV', 'AX', '[SI]');
  EmitInstrA('INC', 'AX');
  EmitInstrAB('MOV', '[SI]', 'AX');
  EmitInstrA('POP', 'SI');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl4);
  EmitInstrAB('LEA', 'AX', '_JSRT_SPLITBUF');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');

  { _JSRT_STRCHAR : SI = string, CX = index -> AX = ptr _JSRT_CHRBUF }
  EmitLabel('_JSRT_STRCHAR');
  EmitInstrAB('ADD', 'SI', 'CX');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', 'BYTE PTR [_JSRT_CHRBUF]', 'AL');
  EmitInstrAB('MOV', 'BYTE PTR [_JSRT_CHRBUF+1]', '0');
  EmitInstrAB('LEA', 'AX', '_JSRT_CHRBUF');
  EmitInstr('RET');

  { _JSRT_STRORD : SI = string, CX = index -> AX = char code }
  EmitLabel('_JSRT_STRORD');
  EmitInstrAB('ADD', 'SI', 'CX');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstr('RET');

  { _JSRT_STRREPEAT : SI = src, DI = dest buf, CX = count -> AX = DI }
  EmitLabel('_JSRT_STRREPEAT');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('MOV', 'BX', 'DI');  { BX = debut buf }
  EmitInstrAB('MOV', 'DX', 'SI');  { DX = src original }
  Lbl1 := LabelGen;
  Lbl2 := LabelGen;
  Lbl3 := LabelGen;
  EmitLabel(Lbl1);  { boucle des repetitions }
  EmitInstrAB('OR', 'CX', 'CX');
  EmitInstrA('JZ', Lbl3);
  EmitInstrAB('MOV', 'SI', 'DX');  { remettre SI au debut }
  EmitLabel(Lbl2);  { copier une occurrence }
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', Lbl2 + 'D');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl2 + 'D');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl3);
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'BX');  { AX = debut buf }
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');

  { _JSRT_STRPADS : SI = string, CX = target len, DI = pad string -> AX = ptr buf }
  EmitLabel('_JSRT_STRPADS');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'DX');
  { Calculer strlen(SI) }
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('CALL', '_JSRT_STRLEN');
  EmitInstrAB('MOV', 'DX', 'AX');  { DX = strlen(str) }
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'CX');
  Lbl1 := LabelGen;
  Lbl2 := LabelGen;
  Lbl3 := LabelGen;
  { Si deja assez long -> copier tel quel }
  EmitInstrAB('CMP', 'DX', 'CX');
  EmitInstrA('JAE', Lbl3);
  { Besoin de (CX - DX) caracteres de padding }
  EmitInstrAB('SUB', 'CX', 'DX');  { CX = nb chars a ajouter }
  EmitInstrAB('LEA', 'BX', '_JSRT_STRBUF');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', 'DI');  { SI = pad string }
  EmitLabel(Lbl1);
  EmitInstrAB('OR', 'CX', 'CX');
  EmitInstrA('JZ', Lbl2);
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JNZ', Lbl1 + 'C');
  EmitInstrAB('MOV', 'SI', 'DI');  { recommencer le pad }
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitLabel(Lbl1 + 'C');
  EmitInstrAB('MOV', '[BX]', 'AL');
  EmitInstrA('INC', 'BX');
  EmitInstrA('INC', 'SI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl2);
  EmitInstrA('POP', 'SI');  { SI = original string }
  { Copier la chaine originale }
  Lbl2 := LabelGen;
  EmitLabel(Lbl2);
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[BX]', 'AL');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', Lbl2 + 'D');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'BX');
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl2 + 'D');
  EmitInstrAB('LEA', 'AX', '_JSRT_STRBUF');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitLabel(Lbl3);
  { Chaine deja assez longue -> copier directement }
  EmitInstrAB('LEA', 'BX', '_JSRT_STRBUF');
  Lbl3 := LabelGen;
  EmitLabel(Lbl3);
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[BX]', 'AL');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', Lbl3 + 'D');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'BX');
  EmitInstrA('JMP', Lbl3);
  EmitLabel(Lbl3 + 'D');
  EmitInstrAB('LEA', 'AX', '_JSRT_STRBUF');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');

  { _JSRT_CHR : AX = char code -> AX = ptr _JSRT_CHRBUF (1-char string) }
  EmitLabel('_JSRT_CHR');
  EmitInstrAB('MOV', 'BYTE PTR [_JSRT_CHRBUF]', 'AL');
  EmitInstrAB('MOV', 'BYTE PTR [_JSRT_CHRBUF+1]', '0');
  EmitInstrAB('LEA', 'AX', '_JSRT_CHRBUF');
  EmitInstr('RET');

  { _JSRT_STRTONUM : SI = ptr string -> AX = integer (atoi simple, base 10) }
  EmitLabel('_JSRT_STRTONUM');
  EmitInstrAB('MOV', 'CX', '10');
  EmitInstrA('JMP', '_JSRT_STRTOINT');

  { _JSRT_STRTOINT : SI = ptr string, CX = radix -> AX = integer }
  EmitLabel('_JSRT_STRTOINT');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrAB('XOR', 'BX', 'BX');  { BX = signe (0=positif) }
  { Ignorer espaces }
  Lbl1 := LabelGen;
  Lbl2 := LabelGen;
  Lbl3 := LabelGen;
  EmitLabel(Lbl1);
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '32');
  EmitInstrA('JE', Lbl1 + 'S');
  EmitInstrA('JMP', Lbl1 + 'E');
  EmitLabel(Lbl1 + 'S');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl1 + 'E');
  { Verifier signe }
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '''-''');
  EmitInstrA('JNE', Lbl1 + 'P');
  EmitInstrAB('MOV', 'BX', '1');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl1 + 'P');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '''+''');
  EmitInstrA('JNE', Lbl2);
  EmitInstrA('INC', 'SI');
  EmitLabel(Lbl2);  { boucle de conversion }
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitInstrAB('MOV', 'DL', '[SI]');
  EmitInstrAB('OR', 'DL', 'DL');
  EmitInstrA('JZ', Lbl3);
  { Convertir caractere en digit }
  EmitInstrAB('CMP', 'DL', '''0''');
  EmitInstrA('JB', Lbl3);
  EmitInstrAB('CMP', 'DL', '''9''');
  EmitInstrA('JA', Lbl2 + 'H');
  EmitInstrAB('SUB', 'DL', '''0''');
  EmitInstrA('JMP', Lbl2 + 'M');
  EmitLabel(Lbl2 + 'H');  { hex a-f/A-F }
  EmitInstrAB('CMP', 'DL', '''a''');
  EmitInstrA('JB', Lbl2 + 'U');
  EmitInstrAB('CMP', 'DL', '''f''');
  EmitInstrA('JA', Lbl3);
  EmitInstrAB('SUB', 'DL', '''a''');
  EmitInstrAB('ADD', 'DL', '10');
  EmitInstrA('JMP', Lbl2 + 'M');
  EmitLabel(Lbl2 + 'U');  { A-F }
  EmitInstrAB('CMP', 'DL', '''A''');
  EmitInstrA('JB', Lbl3);
  EmitInstrAB('CMP', 'DL', '''F''');
  EmitInstrA('JA', Lbl3);
  EmitInstrAB('SUB', 'DL', '''A''');
  EmitInstrAB('ADD', 'DL', '10');
  EmitLabel(Lbl2 + 'M');  { digit en DL, verifier < radix }
  EmitInstrAB('CMP', 'DL', 'CL');
  EmitInstrA('JAE', Lbl3);
  { AX = AX * CX + DL }
  EmitInstrA('PUSH', 'DX');
  EmitInstrA('PUSH', 'CX');
  EmitInstr('MUL    CX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DX');
  EmitInstrAB('ADD', 'AX', 'DX');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl3);  { fin }
  EmitInstrAB('OR', 'BX', 'BX');
  EmitInstrA('JZ', Lbl3 + 'D');
  EmitInstr('NEG    AX');
  EmitLabel(Lbl3 + 'D');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');

  { _JSRT_ABS : AX = n -> AX = |n| }
  EmitLabel('_JSRT_ABS');
  Lbl1 := LabelGen;
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JNS', Lbl1);
  EmitInstr('NEG    AX');
  EmitLabel(Lbl1);
  EmitInstr('RET');

  { _JSRT_POW : AX = base, BX = exponent -> AX = base^exp }
  EmitLabel('_JSRT_POW');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('MOV', 'CX', 'BX');  { CX = exp }
  EmitInstrAB('MOV', 'BX', 'AX');  { BX = base }
  EmitInstrAB('MOV', 'AX', '1');
  Lbl1 := LabelGen;
  Lbl2 := LabelGen;
  EmitLabel(Lbl1);
  EmitInstrAB('OR', 'CX', 'CX');
  EmitInstrA('JZ', Lbl2);
  EmitInstrA('PUSH', 'DX');
  EmitInstr('MUL    BX');
  EmitInstrA('POP', 'DX');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', Lbl1);
  EmitLabel(Lbl2);
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstr('RET');

  { _JSRT_SQRT : AX = n -> AX = isqrt(n) (Newton-Raphson entier) }
  EmitLabel('_JSRT_SQRT');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('OR', 'AX', 'AX');
  Lbl1 := LabelGen;
  Lbl2 := LabelGen;
  EmitInstrA('JZ', Lbl2);
  EmitInstrAB('MOV', 'BX', 'AX');  { BX = n }
  EmitInstrAB('SHR', 'AX', '1');   { guess = n/2 }
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JZ', Lbl2 + 'O');
  EmitLabel(Lbl1);  { iteration }
  EmitInstrAB('MOV', 'CX', 'AX');  { CX = old guess }
  EmitInstrA('PUSH', 'BX');
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstr('DIV    CX');  { AX = n / guess }
  EmitInstrA('POP', 'BX');
  EmitInstrAB('ADD', 'AX', 'CX');  { AX = guess + n/guess }
  EmitInstrAB('SHR', 'AX', '1');   { AX = (guess + n/guess) / 2 }
  EmitInstrAB('CMP', 'AX', 'CX');
  EmitInstrA('JB', Lbl1);
  EmitInstrAB('MOV', 'AX', 'CX');  { retourner le plus petit }
  EmitLabel(Lbl2);
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitLabel(Lbl2 + 'O');
  EmitInstrAB('MOV', 'AX', '1');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');

  { _JSRT_RAND : LCG 16 bits -> AX = pseudo-random 0..32767 }
  EmitLabel('_JSRT_RAND');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('MOV', 'AX', '[_JS_RNDSEED]');
  EmitInstrAB('MOV', 'DX', '25173');
  EmitInstr('MUL    DX');
  EmitInstrAB('ADD', 'AX', '13849');
  EmitInstrAB('MOV', '[_JS_RNDSEED]', 'AX');
  EmitInstrAB('AND', 'AX', '7FFFh');
  EmitInstrA('POP', 'DX');
  EmitInstr('RET');

  { _JSRT_SIGN : AX = n -> AX = -1|0|1 }
  EmitLabel('_JSRT_SIGN');
  Lbl1 := LabelGen;
  Lbl2 := LabelGen;
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JZ', Lbl2);
  EmitInstrA('JS', Lbl1);
  EmitInstrAB('MOV', 'AX', '1');
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl1);
  EmitInstrAB('MOV', 'AX', '0FFFFh');
  EmitLabel(Lbl2);
  EmitInstr('RET');

  { _JSRT_JSONSTR : AX = valeur (traite comme nombre) -> AX = ptr buf }
  EmitLabel('_JSRT_JSONSTR');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('LEA', 'DI', '_JSRT_JSONBUF');
  EmitInstrA('CALL', '_JSRT_NUMTOSTR');
  EmitInstrAB('LEA', 'AX', '_JSRT_JSONBUF');
  EmitInstrA('POP', 'DI');
  EmitInstr('RET');

  (* ---- routines classes/heritage ---- *)
  EmitBlankLine;
  EmitComment('--- runtime class routines ---');

  { _JSRT_NEW : alloue un objet vide (bloc DW) dans _JSRT_OBJHEAP
    IN  : rien
    OUT : AX = ptr nouvel objet (n_props=0, proto=0) }
  EmitLabel('_JSRT_NEW');
  EmitInstrA('PUSH', 'BX');
  EmitInstrAB('MOV', 'BX', '[_JSRT_HEAPTOP]');
  EmitInstrAB('LEA', 'AX', '_JSRT_OBJHEAP');
  EmitInstrAB('ADD', 'AX', 'BX');
  EmitInstrA('PUSH', 'AX');              { sauver ptr retour }
  EmitInstrAB('MOV', 'WORD PTR [AX]', '0');   { proto = 0 }
  EmitInstrAB('MOV', 'WORD PTR [AX+2]', '0'); { n_props = 0 }
  EmitInstrAB('ADD', 'BX', IntToStr(2 + 2 + MAX_OBJ_PROP * 4));
  EmitInstrAB('MOV', '[_JSRT_HEAPTOP]', 'BX');
  EmitInstrA('POP', 'AX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');

  { _JSRT_OBJCREATE : alloue un objet avec proto
    IN  : BX = ptr label proto classe (_JSC_Nom)
    OUT : AX = ptr nouvel objet (pointe vers n_props)
          Layout en memoire : [proto_ptr][n_props][paires...]
          AX pointe vers n_props pour compatibilite OBJGET/OBJSET }
  EmitLabel('_JSRT_OBJCREATE');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('MOV', 'DX', 'BX');       { DX = proto ptr }
  EmitInstrA('PUSH', 'BX');
  EmitInstrAB('MOV', 'BX', '[_JSRT_HEAPTOP]');
  EmitInstrAB('LEA', 'AX', '_JSRT_OBJHEAP');
  EmitInstrAB('ADD', 'AX', 'BX');
  EmitInstrAB('MOV', '[AX]', 'DX');     { proto ptr at offset 0 }
  EmitInstrAB('MOV', 'WORD PTR [AX+2]', '0'); { n_props = 0 at offset 2 }
  EmitInstrAB('ADD', 'AX', '2');        { AX -> n_props (compatible OBJGET) }
  EmitInstrA('PUSH', 'AX');             { sauver ptr retour }
  EmitInstrAB('ADD', 'BX', IntToStr(2 + 2 + MAX_OBJ_PROP * 4));
  EmitInstrAB('MOV', '[_JSRT_HEAPTOP]', 'BX');
  EmitInstrA('POP', 'AX');
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'DX');
  EmitInstr('RET');

  (* ---- routines exceptions ---- *)
  EmitBlankLine;
  EmitComment('--- runtime exception routines ---');

  { _JSRT_MKERROR : cree une struct Error minimale
    IN  : SI = ptr message (ASCIIZ)
    OUT : AX = SI (retourne le ptr message directement) }
  EmitLabel('_JSRT_MKERROR');
  EmitInstrAB('MOV', 'AX', 'SI');
  EmitInstr('RET');

  { _JSRT_THROW : lance une exception
    IN  : AX = ptr objet erreur / chaine
    Si _JSX_HANDLER != 0 : saute vers le handler catch
    Sinon : panic (uncaught exception) }
  Lbl1 := LabelGen; { unhandled }
  EmitLabel('_JSRT_THROW');
  EmitInstrAB('MOV', '[_JSX_ERRPTR]', 'AX');
  EmitInstrAB('CMP', 'WORD PTR [_JSX_HANDLER]', '0');
  EmitInstrA('JZ', Lbl1);
  { Restaurer SP/BP et sauter au handler }
  EmitInstrAB('MOV', 'SP', '[_JSX_SAVESP]');
  EmitInstrAB('MOV', 'BP', '[_JSX_SAVEBP]');
  EmitInstrAB('MOV', 'BX', '[_JSX_HANDLER]');
  EmitInstrA('JMP', 'BX');
  EmitLabel(Lbl1);
  { Uncaught exception : afficher message et quitter }
  EmitInstrA('PUSH', 'AX');
  EmitInstrAB('LEA', 'DX', '_JS_ERR_UNCAUGHT');
  EmitInstrAB('MOV', 'DI', 'DX');
  EmitInstrAB('XOR', 'CX', 'CX');
  Lbl2 := LabelGen; { strlen loop }
  Lbl3 := LabelGen; { strlen done }
  EmitLabel(Lbl2);
  EmitInstrAB('MOV', 'AL', '[DI]');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', Lbl3);
  EmitInstrA('INC', 'CX');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl3);
  EmitInstrAB('SUB', 'DI', 'CX');
  EmitInstrAB('MOV', 'DX', 'DI');
  EmitInstrAB('MOV', 'BX', '2');   { stderr }
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstr('INT    21h');
  { Afficher le message d erreur }
  EmitInstrA('POP', 'AX');
  EmitInstrAB('MOV', 'DI', 'AX');
  EmitInstrAB('XOR', 'CX', 'CX');
  Lbl2 := LabelGen;
  Lbl3 := LabelGen;
  EmitLabel(Lbl2);
  EmitInstrAB('MOV', 'AL', '[DI]');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', Lbl3);
  EmitInstrA('INC', 'CX');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', Lbl2);
  EmitLabel(Lbl3);
  EmitInstrAB('SUB', 'DI', 'CX');
  EmitInstrAB('MOV', 'DX', 'DI');
  EmitInstrAB('MOV', 'BX', '2');   { stderr }
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstr('INT    21h');
  { Newline }
  EmitInstrAB('LEA', 'DX', '_JS_CRLF');
  EmitInstrAB('MOV', 'CX', '2');
  EmitInstrAB('MOV', 'BX', '2');
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstr('INT    21h');
  { Quitter avec code 1 }
  EmitInstrAB('MOV', 'AX', '4C01h');
  EmitInstr('INT    21h');

  { _JSRT_PANIC : affiche message et quitte
    IN  : SI = ptr message ASCIIZ  }
  EmitLabel('_JSRT_PANIC');
  EmitInstrAB('MOV', 'AX', 'SI');
  EmitInstrA('CALL', '_JSRT_THROW');
  EmitInstr('RET');
End;

Procedure EmitClose;
Begin
  EmitBlankLine;
  EmitComment('--- fin du code genere ---');
  EmitBlankLine;
  EmitRaw('_TEXT   ENDS');
  EmitBlankLine;
  EmitDataSeg;
  EmitBlankLine;
  EmitRaw('        END   _JSF_main');
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ============================================================
  VARIABLES ET AFFECTATIONS [IMPLEMENTE]
  ============================================================ }

{ ExprAddrOf : retourne la chaine d'adressage MASM d'un symbole }
Function ExprAddrOf(SIdx : Integer) : TString;
Var
  Ofs    : Integer;
  CapLbl : TString;
Begin
  Ofs := SymTab[SIdx].Offset;
  (* Si deja marque capture : toujours utiliser cellule DATA *)
  If SymTab[SIdx].IsCapture Then
  Begin
    ExprAddrOf := '[' + SymTab[SIdx].CaptureLabel + ']';
    Exit;
  End;
  (* Detection de capture closure *)
  If (Ofs <> 0) And (SymTab[SIdx].FnDepthLvl < CurFnDepth) And
     (CurFnDepth > 0) Then
  Begin
    (* Variable d une portee de fonction externe : acces via cellule DATA *)
    CapLbl := '_JSCAP_' + SymTab[SIdx].Name;
    DataAddWord(CapLbl, 0);
    SymTab[SIdx].IsCapture   := True;
    SymTab[SIdx].CaptureLabel := CapLbl;
    If (CurFnDepth - SymTab[SIdx].FnDepthLvl) > 1 Then
      WarnMsg('closure profonde (>' + IntToStr(1) +
              ' niveau) pour "' + SymTab[SIdx].Name +
              '" : approximation statique')
    Else
      WarnMsg('variable capturee "' + SymTab[SIdx].Name +
              '" : cellule DATA statique (approximation closure)');
    ExprAddrOf := '[' + SymTab[SIdx].CaptureLabel + ']';
    Exit;
  End;
  If Ofs < 0 Then
    ExprAddrOf := '[BP' + IntToStr(Ofs) + ']'     { locale : [BP-2] }
  Else If Ofs > 0 Then
    ExprAddrOf := '[BP+' + IntToStr(Ofs) + ']'    { parametre : [BP+4] }
  Else
    ExprAddrOf := '[' + SymTab[SIdx].MangledName + ']'; { global }
End;

{ EmitCaptureSync : sync captured stack vars -> DATA cells }
{ Appele apres compilation d une fonction imbriquee, au skip label, pour
  copier la valeur actuelle des locales/params capturees dans la cellule DATA. }
Procedure EmitCaptureSync(OuterDepth : Integer);
Var
  I   : Integer;
  Ofs : Integer;
Begin
  For I := 0 To SymCount - 1 Do
  Begin
    If SymTab[I].IsCapture And (SymTab[I].FnDepthLvl = OuterDepth) And
       (SymTab[I].Offset <> 0) Then
    Begin
      Ofs := SymTab[I].Offset;
      If Ofs < 0 Then
        EmitInstrAB('MOV', 'AX', '[BP' + IntToStr(Ofs) + ']')
      Else
        EmitInstrAB('MOV', 'AX', '[BP+' + IntToStr(Ofs) + ']');
      EmitInstrAB('MOV', '[' + SymTab[I].CaptureLabel + ']', 'AX');
    End;
  End;
End;

{ ExprFlushToAX : s'assurer que la valeur d'expression est dans AX }
Procedure ExprFlushToAX(Const E : TExprVal);
Var
  Addr : TString;
  SVal : TString;
Begin
  Case E.Kind Of
    EK_IMM  :
      Begin
        SVal := IntToStr(E.ImmVal);
        EmitInstrAB('MOV', 'AX', SVal);
      End;
    EK_MEM  :
      If E.SymIdx >= 0 Then
      Begin
        { Pour les classes et fonctions, charger l'adresse du label (LEA) }
        If SymTab[E.SymIdx].Cat = SC_CLASS Then
          EmitInstrAB('LEA', 'AX', SymTab[E.SymIdx].MangledName)
        Else If SymTab[E.SymIdx].Cat = SC_FUNCTION Then
          EmitInstrAB('LEA', 'AX', SymTab[E.SymIdx].MangledName)
        Else
        Begin
          Addr := ExprAddrOf(E.SymIdx);
          EmitInstrAB('MOV', 'AX', Addr);
        End;
      End
      Else
        EmitInstrAB('XOR', 'AX', 'AX'); { undefined }
    EK_AX   : ; { deja dans AX }
    EK_NONE : EmitInstrAB('XOR', 'AX', 'AX'); { undefined = 0 }
  End;
End;

{ ExprStore : stocker AX dans le symbole SIdx }
Procedure ExprStore(SIdx : Integer);
Var
  Addr : TString;
Begin
  If SIdx < 0 Then Exit;
  Addr := ExprAddrOf(SIdx);
  EmitInstrAB('MOV', Addr, 'AX');
End;

{ ExprLoad : charger le symbole SIdx dans AX et initialiser Res }
Procedure ExprLoad(SIdx : Integer; Var Res : TExprVal);
Var
  Addr : TString;
Begin
  Res.Kind    := EK_AX;
  Res.TypeIdx := SymTab[SIdx].TypeIdx;
  Res.ImmVal  := 0;
  Res.Offset  := SymTab[SIdx].Offset;
  Res.SymIdx  := SIdx;
  Addr := ExprAddrOf(SIdx);
  EmitInstrAB('MOV', 'AX', Addr);
End;

{ DeclAllocSym : creer/retrouver un symbole de declaration }
Function DeclAllocSym(Const Name : TString; Cat : TSymCat) : Integer;
Var
  SIdx   : Integer;
  Offset : Integer;
Begin
  { Verifier la redeclaration dans le meme scope }
  SIdx := SymFind(Name);
  If (SIdx >= 0) And (SymTab[SIdx].ScopeLevel = CurScope) Then
  Begin
    { var admet la redeclaration (hoist), let/const non }
    If Cat <> SC_VAR Then
      CompileError('redeclaration de "' + Name + '"');
    DeclAllocSym := SIdx;
    Exit;
  End;
  { Calculer l'offset selon la portee courante }
  If CurFnDepth = 0 Then
    Offset := 0            { global : stocke dans _DATA }
  Else
  Begin
    Offset := SymNextOffset; { local : [BP-n] }
    EmitInstrAB('SUB', 'SP', '2'); { allouer pile pour locale }
  End;
  SIdx := SymAdd(Name, Cat, TY_UNKNOWN, Offset);
  { Variable globale : entree dans le segment de donnees }
  If CurFnDepth = 0 Then
    DataAddWord(SymTab[SIdx].MangledName, 0);
  DeclAllocSym := SIdx;
End;

Procedure DeclInitUndef(SIdx : Integer);
Var
  Addr : TString;
Begin
  Addr := ExprAddrOf(SIdx);
  EmitInstrAB('MOV', Addr, '0');
  SymTab[SIdx].TypeIdx := TY_IDX_UNDEF;
End;

Procedure ParseDeclArrayPattern(Cat : TSymCat);
Var
  BindSym    : Array[0..MAX_PARAM - 1] Of Integer;
  BindIndex  : Array[0..MAX_PARAM - 1] Of Integer;
  BindSpread : Array[0..MAX_PARAM - 1] Of Boolean;
  BindCount  : Integer;
  SlotIdx    : Integer;
  SIdx       : Integer;
  Name       : TString;
  I          : Integer;
  Res        : TExprVal;
  Addr       : TString;
  LblMiss    : TString;
  LblDone    : TString;
Begin
  BindCount := 0;
  SlotIdx   := 0;
  ParserAdvance; { consomme '[' }
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']')) Do
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
    Begin
      Inc(SlotIdx);
      ParserAdvance;
      Continue;
    End;
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '...') Then
    Begin
      ParserAdvance;
      If CurToken.Kind <> TK_IDENT Then
      Begin
        CompileError('identifiant attendu apres "..." en destructuration');
        Exit;
      End;
      Name := CurToken.Val;
      ParserAdvance;
      SIdx := DeclAllocSym(Name, Cat);
      If BindCount < MAX_PARAM Then
      Begin
        BindSym[BindCount]    := SIdx;
        BindIndex[BindCount]  := SlotIdx;
        BindSpread[BindCount] := True;
        Inc(BindCount);
      End
      Else
        WarnMsg('trop de variables en destructuration tableau');
    End
    Else
    Begin
      If CurToken.Kind <> TK_IDENT Then
      Begin
        CompileError('identifiant attendu en destructuration tableau');
        Exit;
      End;
      Name := CurToken.Val;
      ParserAdvance;
      SIdx := DeclAllocSym(Name, Cat);
      If BindCount < MAX_PARAM Then
      Begin
        BindSym[BindCount]    := SIdx;
        BindIndex[BindCount]  := SlotIdx;
        BindSpread[BindCount] := False;
        Inc(BindCount);
      End
      Else
        WarnMsg('trop de variables en destructuration tableau');
      Inc(SlotIdx);
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
    ParserAdvance
  Else
    CompileError('"]" attendu en destructuration tableau');

  If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
  Begin
    ParserAdvance;
    ParseExpr(Res);
    ExprFlushToAX(Res);
    EmitInstrAB('MOV', 'SI', 'AX');
    For I := 0 To BindCount - 1 Do
    Begin
      If BindSpread[I] Then
      Begin
        WarnMsg('destructuration tableau avec spread : stub');
        DeclInitUndef(BindSym[I]);
      End
      Else
      Begin
        LblMiss := LabelGen;
        LblDone := LabelGen;
        EmitInstrAB('MOV', 'AX', '[SI]');
        EmitInstrAB('CMP', 'AX', IntToStr(BindIndex[I] + 1));
        EmitInstrA('JL', LblMiss);
        Addr := '[SI+' + IntToStr(2 + (BindIndex[I] * 2)) + ']';
        EmitInstrAB('MOV', 'AX', Addr);
        EmitInstrA('JMP', LblDone);
        EmitLabel(LblMiss);
        EmitInstrAB('XOR', 'AX', 'AX');
        EmitLabel(LblDone);
        ExprStore(BindSym[I]);
        SymTab[BindSym[I]].TypeIdx := TY_UNKNOWN;
      End;
    End;
  End
  Else
  Begin
    If Cat = SC_CONST_JS Then
      CompileError('const destructuree doit etre initialisee');
    For I := 0 To BindCount - 1 Do
      DeclInitUndef(BindSym[I]);
  End;
End;

Procedure ParseDeclObjectPattern(Cat : TSymCat);
Var
  BindSym    : Array[0..MAX_PARAM - 1] Of Integer;
  BindCount  : Integer;
  KeyName    : TString;
  AliasName  : TString;
  SIdx       : Integer;
  I          : Integer;
  Res        : TExprVal;
Begin
  BindCount := 0;
  ParserAdvance; { consomme '{' }
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
  Begin
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '...') Then
    Begin
      ParserAdvance;
      If CurToken.Kind <> TK_IDENT Then
      Begin
        CompileError('identifiant attendu apres "..." en destructuration objet');
        Exit;
      End;
      AliasName := CurToken.Val;
      ParserAdvance;
      SIdx := DeclAllocSym(AliasName, Cat);
      If BindCount < MAX_PARAM Then
      Begin
        BindSym[BindCount]    := SIdx;
        Inc(BindCount);
      End
      Else
        WarnMsg('trop de variables en destructuration objet');
      WarnMsg('destructuration objet avec spread : stub');
    End
    Else
    Begin
      If (CurToken.Kind <> TK_IDENT) And
         (CurToken.Kind <> TK_KEYWORD) And
         (CurToken.Kind <> TK_STRING) Then
      Begin
        CompileError('cle attendue en destructuration objet');
        Exit;
      End;
      KeyName := CurToken.Val;
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      Begin
        ParserAdvance;
        If CurToken.Kind <> TK_IDENT Then
        Begin
          CompileError('alias identifiant attendu apres ":"');
          Exit;
        End;
        AliasName := CurToken.Val;
        ParserAdvance;
      End
      Else
        AliasName := KeyName;
      SIdx := DeclAllocSym(AliasName, Cat);
      If BindCount < MAX_PARAM Then
      Begin
        BindSym[BindCount]    := SIdx;
        Inc(BindCount);
      End
      Else
        WarnMsg('trop de variables en destructuration objet');
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance
  Else
    CompileError('"}" attendu en destructuration objet');

  If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
  Begin
    ParserAdvance;
    ParseExpr(Res);
    ExprFlushToAX(Res);
    WarnMsg('destructuration objet : extraction de proprietes en stub');
    For I := 0 To BindCount - 1 Do
      DeclInitUndef(BindSym[I]);
  End
  Else
  Begin
    If Cat = SC_CONST_JS Then
      CompileError('const destructuree doit etre initialisee');
    For I := 0 To BindCount - 1 Do
      DeclInitUndef(BindSym[I]);
  End;
End;

{ ParseDeclStmt : var/let/const name [= expr] [, name [= expr] ...] [;] }
Procedure ParseDeclStmt(Const Kw : TString);
Var
  Cat  : TSymCat;
  Name : TString;
  SIdx : Integer;
  Res  : TExprVal;
  More : Boolean;
Begin

  If Kw = 'var'   Then Cat := SC_VAR
  Else If Kw = 'let' Then Cat := SC_LET
  Else Cat := SC_CONST_JS;
  More := True;
  While More Do
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
    Begin
      ParseDeclArrayPattern(Cat);
    End
    Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    Begin
      ParseDeclObjectPattern(Cat);
    End
    Else
    Begin
      If CurToken.Kind <> TK_IDENT Then
      Begin
        CompileError('identifiant attendu apres "' + Kw + '"');
        Exit;
      End;
      Name := CurToken.Val;
      ParserAdvance;
      SIdx := DeclAllocSym(Name, Cat);
      { Initialisation optionnelle : = expr }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
      Begin
        ParserAdvance; { consomme '=' }

        ParseExpr(Res);

        ExprFlushToAX(Res);

        ExprStore(SIdx);

        SymTab[SIdx].TypeIdx := Res.TypeIdx;

      End
      Else
      Begin
        If Cat = SC_CONST_JS Then
          CompileError('const "' + Name + '" doit etre initialisee');
        DeclInitUndef(SIdx);
      End;
    End;
    { Plusieurs declarateurs separes par virgule }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance
    Else
      More := False;
  End;
  { Consommer ';' optionnel }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

{ ParseExprStmt : statement-expression (affectation, appel...) }
Procedure ParseExprStmt;
Var
  Res : TExprVal;
Begin
  ParseExpr(Res);
  { Le store a deja ete emis par ParseExprPrec pour les assignations }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

Procedure ParserAdvance;
Begin
  LexNextToken;
  If Opts.DebugMode Then
    PrintToken(CurToken);
End;

{ ============================================================
  FONCTIONS (function / arrow / return) [IMPLEMENTE]
  ============================================================ }

{ LexSaveState : sauvegarder l etat complet du lexer pour lookahead }
Procedure LexSaveState(Var St : TLexState);
Begin
  St.Token    := CurToken;
  St.Line     := LexLine;
  St.LineNo   := LexLineNo;
  St.ColNo    := LexColNo;
  St.IsEOF    := LexEOF;
  St.ASIFlag  := LexASIFlag;
  St.PrevKind := LexPrevKind;
  St.PrevVal  := LexPrevVal;
  St.ExpRegex := LexExpectRegex;
End;

{ LexRestoreState : restaurer l etat du lexer apres un lookahead }
Procedure LexRestoreState(Const St : TLexState);
Begin
  CurToken        := St.Token;
  LexLine         := St.Line;
  LexLineNo       := St.LineNo;
  LexColNo        := St.ColNo;
  LexEOF          := St.IsEOF;
  LexASIFlag      := St.ASIFlag;
  LexPrevKind     := St.PrevKind;
  LexPrevVal      := St.PrevVal;
  LexExpectRegex  := St.ExpRegex;
End;

{ ============================================================
  IF / ELSE IF / ELSE + SWITCH / CASE / DEFAULT
  ============================================================ }

{ ============================================================
  BOUCLES : while / do-while / for / for-of / for-in
  ============================================================ }

{ LoopPush : empile les labels break/continue pour la boucle courante }
Procedure LoopPush(Const BrkLbl, ContLbl : TString);
Begin
  If LoopTop >= MAX_LOOP_NEST Then
  Begin
    CompileError('imbrication de boucles trop profonde');
    Exit;
  End;
  LoopBreakLbl[LoopTop] := BrkLbl;
  LoopContLbl[LoopTop]  := ContLbl;
  Inc(LoopTop);
End;

{ LoopPop : depile les labels break/continue }
Procedure LoopPop;
Begin
  If LoopTop > 0 Then
    Dec(LoopTop);
End;

{ ParseWhileStmt : while (cond) stmt_ou_bloc }
Procedure ParseWhileStmt;
Var
  Cond    : TExprVal;
  LblTest : TString;
  LblEnd  : TString;
Begin
  LblTest := LabelGen;
  LblEnd  := LabelGen;
  LoopPush(LblEnd, LblTest);

  EmitLabel(LblTest);

  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
  Begin
    CompileError('"(" attendu apres "while"');
    LoopPop;
    Exit;
  End;
  ParserAdvance;
  ParseExpr(Cond);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance
  Else
    CompileError('")" attendu apres condition while');

  ExprFlushToAX(Cond);
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JZ', LblEnd);

  ParseStmtOrBlock;

  EmitInstrA('JMP', LblTest);
  EmitLabel(LblEnd);
  LoopPop;
End;

{ ParseDoWhileStmt : do stmt_ou_bloc while (cond) ; }
Procedure ParseDoWhileStmt;
Var
  Cond    : TExprVal;
  LblBody : TString;
  LblTest : TString;
  LblEnd  : TString;
Begin
  LblBody := LabelGen;
  LblTest := LabelGen;
  LblEnd  := LabelGen;
  LoopPush(LblEnd, LblTest);

  EmitLabel(LblBody);
  ParseStmtOrBlock;

  If Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'while')) Then
  Begin
    CompileError('"while" attendu apres corps du do');
    LoopPop;
    Exit;
  End;
  ParserAdvance;

  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
  Begin
    CompileError('"(" attendu apres "while"');
    LoopPop;
    Exit;
  End;
  ParserAdvance;

  EmitLabel(LblTest);
  ParseExpr(Cond);

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance
  Else
    CompileError('")" attendu apres condition do-while');

  ExprFlushToAX(Cond);
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JNZ', LblBody);

  EmitLabel(LblEnd);
  LoopPop;

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

(* ParseForStmt : for (init;cond;incr) body | for (let v of arr) | for (let k in obj) *)
Procedure ParseForStmt;
Var
  Cond     : TExprVal;
  Incr     : TExprVal;
  IterExpr : TExprVal;
  LblTest  : TString;
  LblIncr  : TString;
  LblEnd   : TString;
  LblBody  : TString;
  Kw       : TString;
  VarName  : TString;
  VarIdx   : Integer;
  IdxIdx   : Integer;
  Cat      : TSymCat;
  IsForOf  : Boolean;
  IsForIn  : Boolean;
Begin
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
  Begin
    CompileError('"(" attendu apres "for"');
    Exit;
  End;
  ParserAdvance;
  SymEnterScope;

  { Detecter for-of / for-in : on regarde si on a let/var/const IDENT of/in }
  IsForOf := False;
  IsForIn := False;
  Kw := '';
  VarName := '';
  Cat := SC_LET;

  If (CurToken.Kind = TK_KEYWORD) And
     ((CurToken.Val = 'let') Or (CurToken.Val = 'var') Or (CurToken.Val = 'const')) Then
  Begin
    Kw := CurToken.Val;
    If Kw = 'var' Then Cat := SC_VAR
    Else If Kw = 'const' Then Cat := SC_CONST_JS
    Else Cat := SC_LET;
  End;

  If Kw <> '' Then
  Begin
    { Sauvegarder position pour tester of/in }
    ParserAdvance; { consomme let/var/const }
    If CurToken.Kind = TK_IDENT Then
    Begin
      VarName := CurToken.Val;
      ParserAdvance; { consomme identifiant }
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'of') Then
      Begin
        IsForOf := True;
        ParserAdvance; { consomme 'of' }
      End
      Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'in') Then
      Begin
        IsForIn := True;
        ParserAdvance; { consomme 'in' }
      End;
    End;
  End;

  { --- for-of --- }
  If IsForOf Then
  Begin
    LblTest := LabelGen;
    LblIncr := LabelGen;
    LblEnd  := LabelGen;

    VarIdx := DeclAllocSym(VarName, Cat);

    { Evaluer l expression iterable (tableau) }
    ParseExpr(IterExpr);
    ExprFlushToAX(IterExpr);
    { AX = pointeur vers tableau : [count:word][e0:word]... }

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance
    Else
      CompileError('")" attendu apres for-of');

    { Allouer un index interne _idx }
    IdxIdx := DeclAllocSym('_foridx$', SC_LET);
    EmitInstrAB('MOV', 'SI', 'AX');         { SI = ptr tableau }
    EmitInstrAB('MOV', 'AX', '[SI]');       { AX = count }
    EmitInstrA('PUSH', 'AX');               { sauver count sur pile }
    EmitInstrA('PUSH', 'SI');               { sauver SI (ptr) sur pile }
    EmitInstrAB('XOR', 'AX', 'AX');
    ExprStore(IdxIdx);                       { _foridx$ = 0 }

    LoopPush(LblEnd, LblIncr);
    EmitLabel(LblTest);
    { Comparer index < count }
    EmitInstrA('POP', 'SI');                { SI = ptr tableau }
    EmitInstrA('POP', 'CX');                { CX = count }
    EmitInstrA('PUSH', 'CX');               { resauver count }
    EmitInstrA('PUSH', 'SI');               { resauver ptr }
    EmitInstrAB('MOV', 'AX', ExprAddrOf(IdxIdx));
    EmitInstrAB('CMP', 'AX', 'CX');
    EmitInstrA('JGE', LblEnd);
    { Charger element : arr + 2 + idx*2 }
    EmitInstrAB('SHL', 'AX', '1');          { AX = idx*2 }
    EmitInstrAB('ADD', 'AX', '2');          { skip count word }
    EmitInstrAB('ADD', 'SI', 'AX');
    EmitInstrAB('MOV', 'AX', '[SI]');       { AX = arr[idx] }
    ExprStore(VarIdx);                       { v = arr[idx] }

    ParseStmtOrBlock;

    EmitLabel(LblIncr);
    EmitInstrAB('MOV', 'AX', ExprAddrOf(IdxIdx));
    EmitInstrA('INC', 'AX');
    EmitInstrAB('MOV', ExprAddrOf(IdxIdx), 'AX');
    EmitInstrA('JMP', LblTest);
    EmitLabel(LblEnd);
    { Nettoyer pile : ptr + count }
    EmitInstrAB('ADD', 'SP', '4');
    LoopPop;
    SymLeaveScope;
    Exit;
  End;

  { --- for-in --- }
  If IsForIn Then
  Begin
    { Stub : avertissement, parse et ignore le corps }
    WarnMsg('for-in non entierement supporte, stub');
    VarIdx := DeclAllocSym(VarName, Cat);
    ParseExpr(IterExpr);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
    ParseStmtOrBlock;
    SymLeaveScope;
    Exit;
  End;

  { --- for classique : for (init; cond; incr) body --- }
  LblTest := LabelGen;
  LblIncr := LabelGen;
  LblEnd  := LabelGen;

  { init }
  If Kw <> '' Then
  Begin
    { On a deja consomme let/var/const et le nom de variable }
    { VarName est deja lu, on est juste apres le nom }
    VarIdx := DeclAllocSym(VarName, Cat);
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
    Begin
      ParserAdvance;
      ParseExpr(Cond);
      ExprFlushToAX(Cond);
      ExprStore(VarIdx);
    End
    Else
      DeclInitUndef(VarIdx);
    { Gerer declarations multiples separees par virgule }
    While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
    Begin
      ParserAdvance;
      If CurToken.Kind = TK_IDENT Then
      Begin
        VarName := CurToken.Val;
        ParserAdvance;
        VarIdx := DeclAllocSym(VarName, Cat);
        If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
        Begin
          ParserAdvance;
          ParseExpr(Cond);
          ExprFlushToAX(Cond);
          ExprStore(VarIdx);
        End
        Else
          DeclInitUndef(VarIdx);
      End;
    End;
  End
  Else If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Then
  Begin
    { Expression init (ex: i = 0) }
    If VarName <> '' Then
    Begin
      { On a deja lu l ident VarName mais pas of/in, c est un ident nu }
      { Re-injecter: chercher le symbole et gerer l affectation }
      VarIdx := SymFind(VarName);
      If VarIdx < 0 Then
        VarIdx := DeclAllocSym(VarName, SC_VAR);
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
      Begin
        ParserAdvance;
        ParseExpr(Cond);
        ExprFlushToAX(Cond);
        ExprStore(VarIdx);
      End;
    End
    Else
    Begin
      ParseExpr(Cond); { expression init generique }
    End;
  End;

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance
  Else
    CompileError('";" attendu apres init du for');

  LoopPush(LblEnd, LblIncr);
  EmitLabel(LblTest);

  { cond }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Then
  Begin
    ParseExpr(Cond);
    ExprFlushToAX(Cond);
    EmitInstrAB('OR', 'AX', 'AX');
    EmitInstrA('JZ', LblEnd);
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance
  Else
    CompileError('";" attendu apres condition du for');

  { Sauter par-dessus l increment pour aller au corps }
  LblBody := LabelGen;
  EmitInstrA('JMP', LblBody);

  { incr }
  EmitLabel(LblIncr);
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
  Begin
    ParseExpr(Incr);
    { Pas besoin de flush, l effet de bord (affectation) suffit }
  End;
  EmitInstrA('JMP', LblTest);

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance
  Else
    CompileError('")" attendu apres increment du for');

  { body }
  EmitLabel(LblBody);
  ParseStmtOrBlock;
  EmitInstrA('JMP', LblIncr);

  EmitLabel(LblEnd);
  LoopPop;
  SymLeaveScope;
End;

(* ParseTryStmt : try { bloc } [catch(e) { bloc }] [finally { bloc }] *)
Procedure ParseTryStmt;
Var
  LblCatch    : TString;
  LblFinally  : TString;
  LblEnd      : TString;
  LblTryOk    : TString;
  HasCatch    : Boolean;
  HasFinally  : Boolean;
  ErrVarName  : TString;
  SIdx        : Integer;
  SaveHandler : TString;
Begin
  HasCatch   := False;
  HasFinally := False;
  SaveHandler := LabelGen; { label pour stocker ancien handler }

  LblCatch   := LabelGen;
  LblTryOk   := LabelGen;
  LblFinally := LabelGen;
  LblEnd     := LabelGen;

  { Sauvegarder l ancien handler }
  EmitInstrAB('MOV', 'AX', '[_JSX_HANDLER]');
  EmitInstrA('PUSH', 'AX');
  EmitInstrAB('MOV', 'AX', '[_JSX_SAVESP]');
  EmitInstrA('PUSH', 'AX');
  EmitInstrAB('MOV', 'AX', '[_JSX_SAVEBP]');
  EmitInstrA('PUSH', 'AX');

  { Installer le handler catch }
  EmitInstrAB('MOV', 'WORD PTR [_JSX_HANDLER]', 'OFFSET ' + LblCatch);
  EmitInstrAB('MOV', '[_JSX_SAVESP]', 'SP');
  EmitInstrAB('MOV', '[_JSX_SAVEBP]', 'BP');

  { ---- try block ---- }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
  Begin
    ParserAdvance;
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
      ParseStmt;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
      ParserAdvance;
  End
  Else
    CompileError('"{" attendu apres try');

  { Terminaison normale du try }
  EmitInstrA('JMP', LblTryOk);

  { ---- catch label ---- }
  EmitLabel(LblCatch);
  { AX = ptr erreur (via _JSX_ERRPTR) }
  EmitInstrAB('MOV', 'AX', '[_JSX_ERRPTR]');

  If ((CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT)) And
     (CurToken.Val = 'catch') Then
  Begin
    HasCatch := True;
    ParserAdvance; { consomme 'catch' }
    ErrVarName := 'e';
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      If CurToken.Kind = TK_IDENT Then
      Begin
        ErrVarName := CurToken.Val;
        ParserAdvance;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    { Declarer la variable d erreur dans un nouveau scope }
    SymEnterScope;
    SIdx := DeclAllocSym(ErrVarName, SC_LET);
    SymTab[SIdx].TypeIdx := TY_IDX_STRING;
    ExprStore(SIdx); { stocker AX (ptr erreur) dans la variable }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    Begin
      ParserAdvance;
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
        ParseStmt;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
        ParserAdvance;
    End
    Else
      CompileError('"{" attendu apres catch');
    SymLeaveScope;
  End
  Else
  Begin
    { catch implicite : ignorer l exception }
  End;

  { --- try-ok : restaurer handler et sauter au finally --- }
  EmitLabel(LblTryOk);
  { Restaurer l ancien handler }
  EmitInstrA('POP', 'AX');
  EmitInstrAB('MOV', '[_JSX_SAVEBP]', 'AX');
  EmitInstrA('POP', 'AX');
  EmitInstrAB('MOV', '[_JSX_SAVESP]', 'AX');
  EmitInstrA('POP', 'AX');
  EmitInstrAB('MOV', '[_JSX_HANDLER]', 'AX');

  { ---- finally block ---- }
  If ((CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT)) And
     (CurToken.Val = 'finally') Then
  Begin
    HasFinally := True;
    ParserAdvance; { consomme 'finally' }
    EmitLabel(LblFinally);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    Begin
      ParserAdvance;
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
        ParseStmt;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
        ParserAdvance;
    End
    Else
      CompileError('"{" attendu apres finally');
  End;

  If (Not HasCatch) And (Not HasFinally) Then
    WarnMsg('try sans catch ni finally');

  EmitLabel(LblEnd);
End;

(* ParseFuncDecl : function nom(params) bloc *)
Procedure ParseFuncDecl;
Var
  FnName     : TString;
  FnLabel    : TString;
  RetLabel   : TString;
  SkipLabel  : TString;
  ParamNames : Array[0..MAX_PARAM - 1] Of TString;
  ParamCount : Integer;
  SIdx       : Integer;
  I          : Integer;
  SaveDepth  : Integer;
  SaveRetLbl : TString;
  SaveFnName : TString;
  SaveFrame  : Integer;
  DummyRes   : TExprVal;
Begin
  { Le mot-cle 'function' a deja ete consomme }
  { Generateur : function* }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '*') Then
  Begin
    WarnMsg('function* (generateur) non supporte : stub');
    ParserAdvance;
  End;
  { Nom de la fonction }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('nom de fonction attendu');
    Exit;
  End;
  FnName := CurToken.Val;
  ParserAdvance;
  { Enregistrer le symbole de fonction }
  SIdx := SymAdd(FnName, SC_FUNCTION, TY_IDX_FUNCTION, 0);
  FnLabel := SymTab[SIdx].MangledName;
  RetLabel := LabelGen;
  SkipLabel := LabelGen;
  { Parametres }
  ParamCount := 0;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance;
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
    Begin
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '...') Then
      Begin WarnMsg('rest params (...) : stub'); ParserAdvance; End;
      If CurToken.Kind = TK_IDENT Then
      Begin
        If ParamCount < MAX_PARAM Then
          ParamNames[ParamCount] := CurToken.Val;
        Inc(ParamCount);
        ParserAdvance;
      End;
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
      Begin
        WarnMsg('valeur par defaut de parametre : stub');
        ParserAdvance;
        ParseExprPrec(2, DummyRes);
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
  End;
  { Emettre JMP par-dessus le corps }
  EmitInstrA('JMP', SkipLabel);
  EmitLabel(FnLabel);
  { Prologue (sauvegarde SI/DI + profondeur appels) }
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('INC', 'WORD PTR [_JS_CALLDEPTH]');
  { Sauvegarder le contexte }
  SaveDepth  := CurFnDepth;
  SaveRetLbl := CurFnRetLbl;
  SaveFnName := CurFnName;
  SaveFrame  := CurFrameSize;
  Inc(CurFnDepth);
  If CurFnDepth > 2 Then
    WarnMsg('fonctions imbriquees > 2 niveaux : fermeture approximative');
  If CurFnDepth >= CALL_DEPTH_WARN Then
    WarnMsg('imbrication de fonctions >= ' + IntToStr(CALL_DEPTH_WARN) +
            ' niveaux : risque de debordement de pile');
  CurFnRetLbl := RetLabel;
  CurFnName   := FnName;
  CurFrameSize := 2;  { 2 words reserves pour SI/DI sauvegardes }
  { Scope et parametres }
  SymEnterScope;
  For I := 0 To ParamCount - 1 Do
    SymAdd(ParamNames[I], SC_PARAM, TY_UNKNOWN,
           4 + 2 * (ParamCount - 1 - I));
  { Corps de la fonction }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
  Begin
    ParserAdvance;
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
      ParseStmt;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
      ParserAdvance
    Else
      CompileError('"}" attendu apres corps de fonction');
  End
  Else
    CompileError('"{" attendu apres parametres de fonction');
  { Retour par defaut : undefined }
  EmitInstrAB('XOR', 'AX', 'AX');
  { Epilogue (restauration SI/DI + profondeur appels) }
  EmitLabel(RetLabel);
  EmitInstrA('DEC', 'WORD PTR [_JS_CALLDEPTH]');
  EmitInstrAB('MOV', 'SI', '[BP-2]');
  EmitInstrAB('MOV', 'DI', '[BP-4]');
  EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstrA('POP', 'BP');
  EmitInstr('RET');
  { Restaurer contexte (avant SymLeaveScope pour eviter ADD SP mort) }
  CurFnDepth   := SaveDepth;
  CurFnRetLbl  := SaveRetLbl;
  CurFnName    := SaveFnName;
  SymLeaveScope;
  CurFrameSize := SaveFrame;
  { Label de saut apres la fonction }
  EmitLabel(SkipLabel);
  { Sync des variables capturees vers cellules DATA }
  EmitCaptureSync(CurFnDepth);
End;

(* ParseClassDecl : class Nom [extends Parent] { corps } *)
Procedure ParseClassDecl;
Const
  MAX_CLASS_METH = 32;
Var
  ClassName   : TString;
  ParentName  : TString;
  SIdx        : Integer;
  MethName    : TString;
  MethLabel   : TString;
  RetLabel    : TString;
  SkipLabel   : TString;
  ParamNames  : Array[0..MAX_PARAM - 1] Of TString;
  ParamCount  : Integer;
  I           : Integer;
  SaveDepth   : Integer;
  SaveRetLbl  : TString;
  SaveFnName  : TString;
  SaveFrame   : Integer;
  SaveClass   : TString;
  SaveParent  : TString;
  SaveThis    : Integer;
  ThisOffset  : Integer;
  IsStatic    : Boolean;
  IsGetter    : Boolean;
  IsSetter    : Boolean;
  DummyRes    : TExprVal;
  HasCtor     : Boolean;
  ClassSkip   : TString;
  { Suivi des methodes pour init des instances }
  MethNames   : Array[0..MAX_CLASS_METH - 1] Of TString;
  MethLabels  : Array[0..MAX_CLASS_METH - 1] Of TString;
  MethKeyLbls : Array[0..MAX_CLASS_METH - 1] Of TString;
  MethCount   : Integer;
Begin
  { Le mot-cle 'class' a deja ete consomme }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('nom de classe attendu apres "class"');
    Exit;
  End;
  ClassName := CurToken.Val;
  ParserAdvance;

  { extends Parent ? }
  ParentName := '';
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'extends') Then
  Begin
    ParserAdvance; { consomme 'extends' }
    If CurToken.Kind = TK_IDENT Then
    Begin
      ParentName := CurToken.Val;
      ParserAdvance;
    End
    Else
      CompileError('nom de classe parente attendu apres "extends"');
  End;

  { Enregistrer la classe dans la table des symboles }
  SIdx := SymAdd(ClassName, SC_CLASS, TY_IDX_OBJECT, 0);

  { Ajouter la zone prototype dans DATA : _JSC_Nom DW OFFSET _JSC_Parent ou 0 }
  If ParentName <> '' Then
    DataAdd(JS_CLS_PFX + ClassName, DK_WORD, 0, JS_CLS_PFX + ParentName)
  Else
    DataAddWord(JS_CLS_PFX + ClassName, 0);

  { Sauvegarder le contexte de classe }
  SaveClass  := CurClassName;
  SaveParent := CurParentClass;
  SaveThis   := CurMethodThis;
  CurClassName   := ClassName;
  CurParentClass := ParentName;

  { JMP par-dessus toutes les methodes de la classe }
  ClassSkip := LabelGen;
  EmitInstrA('JMP', ClassSkip);

  { Accolade ouvrante }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{')) Then
  Begin
    CompileError('"{" attendu apres declaration de classe');
    CurClassName   := SaveClass;
    CurParentClass := SaveParent;
    CurMethodThis  := SaveThis;
    Exit;
  End;
  ParserAdvance; { consomme '{' }

  HasCtor := False;
  MethCount := 0;

  { Parcourir le corps de la classe }
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
  Begin
    { Points-virgules parasites }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    Begin
      ParserAdvance;
      Continue;
    End;

    IsStatic := False;
    IsGetter := False;
    IsSetter := False;

    { static ? }
    If ((CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD)) And
       (CurToken.Val = 'static') Then
    Begin
      IsStatic := True;
      ParserAdvance;
    End;

    { get / set ? }
    If ((CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD)) And
       (CurToken.Val = 'get') Then
    Begin
      IsGetter := True;
      ParserAdvance;
    End
    Else If ((CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD)) And
            (CurToken.Val = 'set') Then
    Begin
      IsSetter := True;
      ParserAdvance;
    End;

    { Champs prives #x }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '#') Then
    Begin
      WarnMsg('champ prive (#) : stub');
      ParserAdvance;
    End;

    { Nom de la methode ou du champ }
    If (CurToken.Kind <> TK_IDENT) And (CurToken.Kind <> TK_KEYWORD) Then
    Begin
      { Token inattendu dans le corps de classe }
      WarnMsg('token inattendu dans corps de classe : ' + CurToken.Val);
      ParserAdvance;
      Continue;
    End;

    MethName := CurToken.Val;
    ParserAdvance;

    { Constructeur ou methode avec parentheses }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      { Getter/setter : stubs }
      If IsGetter Or IsSetter Then
      Begin
        If IsGetter Then
          WarnMsg('getter "' + MethName + '" : stub, compile comme methode')
        Else
          WarnMsg('setter "' + MethName + '" : stub, compile comme methode');
      End;

      { Determiner le label de la methode }
      If MethName = 'constructor' Then
      Begin
        HasCtor := True;
        MethLabel := JS_FN_PFX + ClassName + '_ctor';
      End
      Else If IsStatic Then
        MethLabel := JS_FN_PFX + ClassName + '_S_' + MethName
      Else
        MethLabel := JS_FN_PFX + ClassName + '_' + MethName;

      { Parser les parametres }
      ParamCount := 0;
      ParserAdvance; { consomme '(' }
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
      Begin
        If (CurToken.Kind = TK_OP) And (CurToken.Val = '...') Then
        Begin WarnMsg('rest params (...) : stub'); ParserAdvance; End;
        If CurToken.Kind = TK_IDENT Then
        Begin
          If ParamCount < MAX_PARAM Then
            ParamNames[ParamCount] := CurToken.Val;
          Inc(ParamCount);
          ParserAdvance;
        End;
        If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
        Begin
          WarnMsg('valeur par defaut de parametre : stub');
          ParserAdvance;
          ParseExprPrec(2, DummyRes);
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          ParserAdvance;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;

      { Calculer offset du this cache }
      { Convention : this est empile en dernier (comme args cdecl)
        this   -> [BP + 4 + 2 * ParamCount]
        param0 -> [BP + 4 + 2 * (ParamCount - 1)]
        ...
        paramN -> [BP + 4] }
      If IsStatic Then
        ThisOffset := 0
      Else
        ThisOffset := 4;  { this est empile en dernier, a [BP+4] }

      { Emettre le code de la methode }
      RetLabel  := LabelGen;
      SkipLabel := LabelGen;

      EmitLabel(MethLabel);
      { Prologue }
      EmitInstrA('PUSH', 'BP');
      EmitInstrAB('MOV', 'BP', 'SP');
      EmitInstrA('PUSH', 'SI');
      EmitInstrA('PUSH', 'DI');
      EmitInstrA('INC', 'WORD PTR [_JS_CALLDEPTH]');

      { Sauvegarder le contexte courant }
      SaveDepth  := CurFnDepth;
      SaveRetLbl := CurFnRetLbl;
      SaveFnName := CurFnName;
      SaveFrame  := CurFrameSize;

      Inc(CurFnDepth);
      CurFnRetLbl  := RetLabel;
      CurFnName    := ClassName + '.' + MethName;
      CurFrameSize := 2;  { SI/DI sauvegardes }
      CurMethodThis := ThisOffset;

      { Scope et parametres }
      SymEnterScope;
      If IsStatic Then
      Begin
        { Statique : pas de this, offsetting normal }
        For I := 0 To ParamCount - 1 Do
          SymAdd(ParamNames[I], SC_PARAM, TY_UNKNOWN,
                 4 + 2 * (ParamCount - 1 - I));
      End
      Else
      Begin
        { Instance : this est a [BP+4], params decalent de +2 }
        For I := 0 To ParamCount - 1 Do
          SymAdd(ParamNames[I], SC_PARAM, TY_UNKNOWN,
                 6 + 2 * (ParamCount - 1 - I));
      End;

      { Corps de la methode }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
      Begin
        ParserAdvance;
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
          ParseStmt;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
          ParserAdvance
        Else
          CompileError('"}" attendu apres corps de methode');
      End
      Else
        CompileError('"{" attendu apres parametres de methode');

      { Retour par defaut : undefined (ou this pour constructeur) }
      If MethName = 'constructor' Then
      Begin
        If ThisOffset > 0 Then
          EmitInstrAB('MOV', 'AX', '[BP+' + IntToStr(ThisOffset) + ']')
        Else
          EmitInstrAB('XOR', 'AX', 'AX');
      End
      Else
        EmitInstrAB('XOR', 'AX', 'AX');

      { Epilogue }
      EmitLabel(RetLabel);
      EmitInstrA('DEC', 'WORD PTR [_JS_CALLDEPTH]');
      EmitInstrAB('MOV', 'SI', '[BP-2]');
      EmitInstrAB('MOV', 'DI', '[BP-4]');
      EmitInstrAB('MOV', 'SP', 'BP');
      EmitInstrA('POP', 'BP');
      EmitInstr('RET');

      { Restaurer contexte }
      CurFnDepth   := SaveDepth;
      CurFnRetLbl  := SaveRetLbl;
      CurFnName    := SaveFnName;
      SymLeaveScope;
      CurFrameSize := SaveFrame;

      { Suivi des methodes non-statiques, non-constructeur }
      If (Not IsStatic) And (MethName <> 'constructor') Then
      Begin
        If MethCount < MAX_CLASS_METH Then
        Begin
          MethNames[MethCount]   := MethName;
          MethLabels[MethCount]  := MethLabel;
          MethKeyLbls[MethCount] := DataAddStr(MethName);
          Inc(MethCount);
        End;
      End;
    End
    Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
    Begin
      { Champ public : fieldName = value; -> stub/warning }
      WarnMsg('champ de classe "' + MethName + '" : stub, init ignoree');
      ParserAdvance; { consomme '=' }
      ParseExprPrec(2, DummyRes);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
    End
    Else
    Begin
      { Champ sans valeur ou token inattendu }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
    End;
  End; { While corps de classe }

  { Si pas de constructeur defini, emettre un constructeur par defaut }
  If Not HasCtor Then
  Begin
    MethLabel := JS_FN_PFX + ClassName + '_ctor';
    EmitLabel(MethLabel);
    EmitInstrA('PUSH', 'BP');
    EmitInstrAB('MOV', 'BP', 'SP');
    { Si extends, appeler super constructeur par defaut }
    If ParentName <> '' Then
    Begin
      EmitInstrAB('MOV', 'AX', '[BP+4]');   { this }
      EmitInstrA('PUSH', 'AX');
      EmitInstrA('CALL', JS_FN_PFX + ParentName + '_ctor');
      EmitInstrAB('ADD', 'SP', '2');
    End;
    EmitInstrAB('MOV', 'AX', '[BP+4]');     { return this }
    EmitInstrAB('MOV', 'SP', 'BP');
    EmitInstrA('POP', 'BP');
    EmitInstr('RET');
  End;

  { Emettre la routine d'init des methodes : _JSF_Nom__init(BX=this)
    Stocke les ptrs de methode comme proprietes de l'objet
    Si extends, appelle d'abord __init du parent }
  EmitLabel(JS_FN_PFX + ClassName + '__init');
  EmitInstrA('PUSH', 'BX');
  { Appeler __init du parent pour heriter les methodes }
  If ParentName <> '' Then
    EmitInstrA('CALL', JS_FN_PFX + ParentName + '__init');
  { Stocker les methodes de cette classe }
  For I := 0 To MethCount - 1 Do
  Begin
    EmitInstrAB('LEA', 'DI', MethKeyLbls[I]);
    EmitInstrAB('LEA', 'AX', MethLabels[I]);
    EmitInstrA('CALL', '_JSRT_OBJSET');
  End;
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');

  { Accolade fermante }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance
  Else
    CompileError('"}" attendu apres corps de classe');

  { Label de saut apres la classe }
  EmitLabel(ClassSkip);

  { Restaurer le contexte de classe }
  CurClassName   := SaveClass;
  CurParentClass := SaveParent;
  CurMethodThis  := SaveThis;
End;

{ ParseBlock : parse un bloc entre accolades stmt* avec scope }
Procedure ParseBlock;
Begin
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{')) Then
  Begin
    CompileError('accolade ouvrante attendue');
    Exit;
  End;
  ParserAdvance; { consomme la accolade ouvrante }
  SymEnterScope;
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
    ParseStmt;
  SymLeaveScope;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance
  Else
    CompileError('accolade fermante attendue');
End;

{ ParseStmtOrBlock : parse soit un bloc entre accolades, soit un statement }
Procedure ParseStmtOrBlock;
Begin
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    ParseBlock
  Else
    ParseStmt;
End;

{ ParseIfStmt : if (cond) stmt [else if (cond) stmt]* [else stmt] }
Procedure ParseIfStmt;
Var
  Cond     : TExprVal;
  LblElse  : TString;
  LblEnd   : TString;
Begin
  { Le mot-cle 'if' a deja ete consomme par ParseStmt }
  LblEnd := LabelGen;  { label fin du if complet }

  { --- Premiere branche if --- }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
  Begin
    CompileError('"(" attendu apres "if"');
    Exit;
  End;
  ParserAdvance; { consomme '(' }
  ParseExpr(Cond);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance
  Else
    CompileError('")" attendu apres condition du if');

  LblElse := LabelGen;
  { Evaluer la condition }
  If Cond.Kind = EK_IMM Then
  Begin
    { Condition constante : si faux, sauter }
    If Cond.ImmVal = 0 Then
      EmitInstrA('JMP', LblElse);
    { Si vrai, ne rien emettre (fall through) }
  End
  Else
  Begin
    ExprFlushToAX(Cond);
    EmitInstrAB('OR', 'AX', 'AX');
    EmitInstrA('JZ', LblElse);
  End;

  { Corps du if }
  ParseStmtOrBlock;

  { Verifier else / else if }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'else') Then
  Begin
    EmitInstrA('JMP', LblEnd);
    EmitLabel(LblElse);
    ParserAdvance; { consomme 'else' }
    { else if (...) -> appel recursif }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'if') Then
    Begin
      ParserAdvance; { consomme 'if' }
      ParseIfStmt;   { recursion pour else if }
      { LblEnd est cree par le if recursif, mais on doit quand meme
        emettre notre propre label de fin }
      EmitLabel(LblEnd);
      Exit;
    End
    Else
    Begin
      { else simple : corps du else }
      ParseStmtOrBlock;
      EmitLabel(LblEnd);
    End;
  End
  Else
  Begin
    { Pas de else : le label else = label fin }
    EmitLabel(LblElse);
    EmitLabel(LblEnd);
  End;
End;

(* ParseSwitchStmt : switch (expr) { case v: stmts break; ... default: stmts } *)
Procedure ParseSwitchStmt;
Var
  SwitchExpr   : TExprVal;
  CaseVal      : TExprVal;
  LblEnd       : TString;
  LblNextCase  : TString;
  LblDefault   : TString;
  LblBody      : TString;
  HasDefault   : Boolean;
Begin
  { Le mot-cle 'switch' a deja ete consomme par ParseStmt }
  LblEnd     := LabelGen;
  LblDefault := '';
  HasDefault := False;

  { Condition du switch }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
  Begin
    CompileError('"(" attendu apres "switch"');
    Exit;
  End;
  ParserAdvance;
  ParseExpr(SwitchExpr);
  ExprFlushToAX(SwitchExpr);
  EmitInstrA('PUSH', 'AX'); { sauver la valeur du switch sur la pile }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance
  Else
    CompileError('")" attendu apres expression switch');

  { Attendre le bloc switch }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{')) Then
  Begin
    CompileError('accolade ouvrante attendue apres switch()');
    Exit;
  End;
  ParserAdvance; { consomme la accolade ouvrante }
  SymEnterScope;

  { Boucle sur les clauses case/default }
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
  Begin
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'case') Then
    Begin
      ParserAdvance; { consomme 'case' }
      { Evaluer la valeur du case }
      ParseExpr(CaseVal);
      { Attendre ':' }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
        ParserAdvance
      Else
        CompileError('":" attendu apres valeur du case');

      { Comparaison : POP BX (valeur switch), CMP, PUSH BX (resauver) }
      LblNextCase := LabelGen;
      EmitInstrA('POP', 'BX');  { BX = valeur du switch }
      EmitInstrA('PUSH', 'BX'); { resauver pour le prochain case }
      ExprFlushToAX(CaseVal);
      EmitInstrAB('CMP', 'BX', 'AX');
      EmitInstrA('JNE', LblNextCase);

      { Corps du case : instructions jusqu au prochain case/default/fin }
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) And
            Not ((CurToken.Kind = TK_KEYWORD) And
                 ((CurToken.Val = 'case') Or (CurToken.Val = 'default'))) Do
      Begin
        If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'break') Then
        Begin
          ParserAdvance; { consomme 'break' }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
            ParserAdvance;
          EmitInstrA('JMP', LblEnd);
        End
        Else
          ParseStmt;
      End;

      EmitLabel(LblNextCase);
    End
    Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'default') Then
    Begin
      ParserAdvance; { consomme 'default' }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
        ParserAdvance
      Else
        CompileError('":" attendu apres default');

      HasDefault := True;
      { Corps du default }
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) And
            Not ((CurToken.Kind = TK_KEYWORD) And
                 ((CurToken.Val = 'case') Or (CurToken.Val = 'default'))) Do
      Begin
        If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'break') Then
        Begin
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
            ParserAdvance;
          EmitInstrA('JMP', LblEnd);
        End
        Else
          ParseStmt;
      End;
    End
    Else
    Begin
      { Statement orphelin dans un switch (fallthrough) }
      ParseStmt;
    End;
  End;

  SymLeaveScope;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance
  Else
    CompileError('accolade fermante attendue apres switch');

  { Nettoyer la pile (la valeur du switch est encore PUSH) }
  EmitLabel(LblEnd);
  EmitInstrAB('ADD', 'SP', '2');
End;

{ ParseStmt : statement principal }
Procedure ParseStmt;
Var
  Kw  : TString;
  Res : TExprVal;
Begin
  { Bloc entre accolades }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
  Begin
    ParseBlock;
    Exit;
  End;
  { Statement vide ';' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
  Begin
    ParserAdvance;
    Exit;
  End;
  { async : stub, consommer et traiter le reste normalement }
  If (CurToken.Kind = TK_IDENT) And (CurToken.Val = 'async') Then
  Begin
    WarnMsg('async non supporte : stub');
    ParserAdvance;
    { Fall through pour traiter function/arrow qui suit }
  End;
  { Mots-cles }
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    Kw := CurToken.Val;

    If (Kw = 'var') Or (Kw = 'let') Or (Kw = 'const') Then
    Begin
      ParserAdvance; { consomme var/let/const }
      ParseDeclStmt(Kw);
      Exit;
    End;

    If Kw = 'function' Then
    Begin
      ParserAdvance; { consomme 'function' }
      ParseFuncDecl;
      Exit;
    End;

    If Kw = 'class' Then
    Begin
      ParserAdvance; { consomme 'class' }
      ParseClassDecl;
      Exit;
    End;

    If Kw = 'return' Then
    Begin
      ParserAdvance; { consomme 'return' }
      If CurFnDepth <= 0 Then
        CompileError('return en dehors d''une fonction');
      { Verifier return vide }
      If (CurToken.Kind = TK_PUNCT) And
         ((CurToken.Val = ';') Or (CurToken.Val = '}')) Then
        EmitInstrAB('XOR', 'AX', 'AX')
      Else If CurToken.Kind = TK_EOF Then
        EmitInstrAB('XOR', 'AX', 'AX')
      Else
      Begin
        ParseExpr(Res);
        ExprFlushToAX(Res);
      End;
      If CurFnRetLbl <> '' Then
        EmitInstrA('JMP', CurFnRetLbl);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
      Exit;
    End;

    If Kw = 'if' Then
    Begin
      ParserAdvance; { consomme 'if' }
      ParseIfStmt;
      Exit;
    End;

    If Kw = 'switch' Then
    Begin
      ParserAdvance; { consomme 'switch' }
      ParseSwitchStmt;
      Exit;
    End;

    If Kw = 'while' Then
    Begin
      ParserAdvance; { consomme 'while' }
      ParseWhileStmt;
      Exit;
    End;

    If Kw = 'do' Then
    Begin
      ParserAdvance; { consomme 'do' }
      ParseDoWhileStmt;
      Exit;
    End;

    If Kw = 'for' Then
    Begin
      ParserAdvance; { consomme 'for' }
      ParseForStmt;
      Exit;
    End;

    If Kw = 'break' Then
    Begin
      ParserAdvance; { consomme 'break' }
      If LoopTop > 0 Then
        EmitInstrA('JMP', LoopBreakLbl[LoopTop - 1])
      Else
        CompileError('break en dehors d''une boucle');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
      Exit;
    End;

    If Kw = 'continue' Then
    Begin
      ParserAdvance; { consomme 'continue' }
      If LoopTop > 0 Then
        EmitInstrA('JMP', LoopContLbl[LoopTop - 1])
      Else
        CompileError('continue en dehors d''une boucle');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
      Exit;
    End;

    If Kw = 'try' Then
    Begin
      ParserAdvance; { consomme 'try' }
      ParseTryStmt;
      Exit;
    End;

    If Kw = 'throw' Then
    Begin
      ParserAdvance; { consomme 'throw' }
      ParseExpr(Res);
      ExprFlushToAX(Res);
      EmitInstrA('CALL', '_JSRT_THROW');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
      Exit;
    End;
  End;
  { Expression-statement (affectation, appel de fn, etc.) }
  If CurToken.Kind <> TK_EOF Then
    ParseExprStmt;
End;

{ ---- Pipeline de compilation -------------------------------- }

Procedure Run;
Begin
  GlobalInit;
  If Opts.Verbose Then ShowBanner;

  TypeInit;
  SymInit;
  EmitOpen;
  EmitHeader;
  LexInit;

  { Lire le premier token }
  ParserAdvance;

  { Detecter 'use strict'; en tete de fichier }
  If (CurToken.Kind = TK_IDENT) And (CurToken.Val = 'use') Then
  Begin
    ParserAdvance;
    If (CurToken.Kind = TK_IDENT) And (CurToken.Val = 'strict') Then
    Begin
      Opts.Strict := True;
      ParserAdvance; { consomme 'strict' }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance; { consomme ';' }
    End;
  End;

  { Boucle principale de compilation }
  While CurToken.Kind <> TK_EOF Do
    ParseStmt;

  { Terminaison propre du programme }
  EmitBlankLine;
  EmitComment('--- sortie programme ---');
  EmitInstrAB('MOV', 'AX', '4C00h');
  EmitInstr('INT    21h');

  LexClose;
  EmitRuntime;
  EmitClose;   { EmitDataSeg est appele depuis EmitClose }

  If Opts.Verbose Then
  Begin
    WriteLn('Compilation terminee : ', Opts.SrcFile, ' -> ', Opts.OutFile);
    WriteLn('  Lignes      : ', TotalLines);
    WriteLn('  Symboles    : ', TotalSyms);
    WriteLn('  Erreurs     : ', ErrorCount);
    WriteLn('  Avertissements : ', WarnCount);
  End;

  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
BEGIN
 If (ParamStr(1) = '/?') Or (ParamStr(1) = '--help') Or
    (ParamStr(1) = '-h') Or (ParamStr(1) = '/h') Or
    (ParamStr(1) = '/H') Then
 Begin
  ShowUsage;
  Halt(0);
 End;
 ParseArgs;
 Run;
END.
