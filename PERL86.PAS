{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur Perl vers assembleur 8086
  @license: MIT
}

(* ============================================================
  Cible : MASM .MODEL SMALL, DOS 16 bits
  ============================================================ *)

Program PERL86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES GLOBALES
  ============================================================ }
Const
  PERL86_VERSION = '1.0';
  PERL86_DATE    = '2026-03-05';

  { Limites des tableaux internes }
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}100{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}32{$ELSE}16{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_INCLUDE   = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_PKG       = {$IFDEF FPC}16{$ELSE}4{$ENDIF};
  MAX_ARR_ELEMS  = 32;   { elements max par tableau @arr local (fixe) }
  MAX_HASH_PAIRS  = 16;   { paires cle/valeur max par %hash local       }
  MAX_HASH_KEYS   = {$IFDEF FPC}512{$ELSE}100{$ENDIF};  { entrees totales dans la table de hachage    }
  STACK_SIZE      = 1024;

  { Prefixes de nommage ASM }
  PR_VAR_PFX  = '_PRV_';    { variable scalaire/tableau/hash }
  PR_FN_PFX   = '_PRF_';    { sous-routine sub              }
  PR_STR_PFX  = '_PRK_';    { constante chaine              }
  PR_RT_PFX   = '_PRRT_';   { routine runtime               }
  PR_LBL_PFX  = '_PRL_';    { label de saut interne         }
  PR_CAP_PFX  = '_PRCAP_';  { capture regexp $1/$2/...      }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Contexte d''evaluation Perl }
  CTX_SCALAR = 0;  { scalaire : un seul entier/pointeur }
  CTX_LIST   = 1;  { liste   : plusieurs valeurs        }
  CTX_BOOL   = 2;  { booleen : test vrai/faux           }
  CTX_VOID   = 3;  { void   : valeur ignoree            }

  { Indices de types primitifs Perl }
  TY_IDX_SCALAR  = 0;   { scalaire entier/chaine unifie }
  TY_IDX_ARRAY   = 1;   { tableau @arr                  }
  TY_IDX_HASH    = 2;   { hash %h                       }
  TY_IDX_REF     = 3;   { reference \$v                 }
  TY_IDX_CODE    = 4;   { reference de code \&sub       }
  TY_IDX_UNDEF   = 5;   { undef                         }
  TY_IDX_MIXED   = 6;   { contexte indetermine          }
  TY_PRIM_COUNT  = 7;
  TY_UNKNOWN     = -1;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Tokens Perl ---------------------------------------- }
  TTokenKind = (
    TK_EOF,         { fin de fichier                       }
    TK_IDENT,       { identificateur (mot-cle ou bare-word) }
    TK_KEYWORD,     { mot-cle Perl reconnu                  }
    TK_SCALAR,      { variable scalaire $nom               }
    TK_ARRAY_SIG,   { variable tableau @nom                }
    TK_HASH_SIG,    { variable hash %nom                   }
    TK_INTEGER,     { litteral entier                      }
    TK_FLOAT,       { litteral flottant                    }
    TK_STRING,      { litteral chaine (simple- ou double-q) }
    TK_HEREDOC,     { heredoc <<LABEL                      }
    TK_REGEXP,      { expression reguliere /pat/flags      }
    TK_FILEHANDLE,  { descripteur STDOUT STDERR STDIN <FH> }
    TK_OP,          { operateur                            }
    TK_PUNCT        { ponctuation () [] ; , ->              }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;       { valeur textuelle brute             }
    IntVal   : LongInt;       { valeur entiere (TK_INTEGER)        }
    FloatVal : Real;          { valeur flottante (TK_FLOAT)        }
    Line     : Integer;       { ligne source (1-base)              }
    Col      : Integer;       { colonne source (1-base)            }
  End;

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;   { script source (.pl)                  }
    OutFile   : TString;   { fichier assembleur de sortie (.asm)  }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugTok  : Boolean;   { -d : affichage de chaque token       }
    Strict    : Boolean;   { -s : equivalence use strict          }
    Warnings  : Boolean;   { -w : equivalence use warnings        }
  End;

  { ---- Categories de symboles ----------------------------- }
  TSymCat = (
    SC_SCALAR,       { my/our $var scalaire              }
    SC_ARRAY_VAR,    { my/our @arr tableau                }
    SC_HASH_VAR,     { my/our %h hash                    }
    SC_PARAM,        { parametre de sous-routine          }
    SC_FN,           { sous-routine (sub)                 }
    SC_PKG,          { package / namespace                }
    SC_CONST,        { use constant NOM => val            }
    SC_FILEHANDLE    { filehandle open(my $fh, ...)       }
  );

  TSymRec = Record
    Name        : TString;   { nom Perl sans sigil             }
    SigilName   : TString;   { nom avec sigil ($foo @foo %foo) }
    MangledName : TString;   { _PRV_foo / _PRF_foo             }
    Cat         : TSymCat;
    TypeIdx     : Integer;   { indice dans TypeTab             }
    ScopeLevel  : Integer;
    Offset      : Integer;   { [BP-n] pour locaux, DATA sinon  }
    IsMy        : Boolean;   { lexical my                      }
    IsOur       : Boolean;   { global our                      }
    IsLocal     : Boolean;   { dynamique local                 }
    IsRef       : Boolean;   { passe par reference \$p         }
    DeclLine    : Integer;
  End;

  { ---- Types internes ------------------------------------- }
  TTypeKind = (
    TKD_SCALAR,
    TKD_ARRAY,
    TKD_HASH,
    TKD_REF,
    TKD_CODE,
    TKD_UNDEF,
    TKD_MIXED,
    TKD_UNKNOWN
  );

  TTypeRec = Record
    Name    : TString;
    Kind    : TTypeKind;
    Size    : Integer;   { taille en octets : scalar=2, ref=2 }
    ElemIdx : Integer;   { type des elements (TKD_ARRAY)      }
  End;

  { ---- Valeurs d'expression ------------------------------- }
  TExprKind = (
    EK_NONE,   { void / pas de valeur  }
    EK_IMM,    { immediat dans ImmVal  }
    EK_AX,     { valeur dans AX        }
    EK_DXAX,   { valeur longue DX:AX   }
    EK_MEM     { adresse [BP+Offset] ou [_PRV_x] }
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
  End;

  { ---- Segment de donnees --------------------------------- }
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY_BLK);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;   { DK_ARRAY_BLK : nombre d'elements }
  End;

  { ---- Table de hachage (compile-time) ------------------- }
  { Pour chaque paire cle/valeur d'un %hash local, on stocke  }
  { l'indice du hash dans SymTab, la cle Perl (string) et le  }
  { numero de slot (0..MAX_HASH_PAIRS-1).                     }
  THashKeyRec = Record
    HashSym : Integer;   { indice SymTab du %hash              }
    KeyStr  : TString;   { cle Perl (chaine ou bareword)       }
    SlotIdx : Integer;   { slot 0..MAX_HASH_PAIRS-1            }
    KeyLbl  : TString;   { label ASM de la cle en DATA         }
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  { Options }
  Opts : TOptions;

  { Compteurs globaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;
  TotalSyms  : Integer;

  { Valeur fictive pour ignorer un retour TExprVal }
  GExprDummy : TExprVal;

  { Lexeur }
  LexSrcF   : Text;
  LexLine   : String;
  LexLineNo : Integer;
  LexColNo  : Integer;
  LexEOF    : Boolean;
  LexOpened : Boolean;
  CurToken  : TToken;

  { Table des symboles }
  SymTab    : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount  : Integer;
  ScopeStack: Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeTop  : Integer;
  CurScope  : Integer;
  LabelSeq  : Integer;

  { Table des types }
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

  { Emetteur ASM }
  OutF         : Text;
  OutFOpen     : Boolean;
  CurFrameSize : Integer;   { taille du cadre local courant        }
  CurFnDepth   : Integer;   { 0 = global, >0 = dans une sub       }
  CurFnRetLbl  : TString;   { label epilogue de la sub courante    }
  CurFnName    : TString;   { nom de la sub courante               }
  LoopTop      : Integer;
  LoopBreakLbl : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContLbl  : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopRedoLbl  : Array[0..MAX_LOOP_NEST - 1] Of TString;

  { Segment de donnees statiques }
  DataTab   : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount : Integer;

  { Table de hachage compile-time pour %hash locaux }
  HashKeyTab   : Array[0..MAX_HASH_KEYS - 1] Of THashKeyRec;
  HashKeyCount : Integer;

  { Etat general }
  RuntimeEmitted : Boolean;

  { Garde d'inclusion (require_once / use) }
  IncludeTab   : Array[0..MAX_INCLUDE - 1] Of TString;
  IncludeCount : Integer;

  { Package courant }
  CurPackage : TString;   { 'main' par defaut }

  { Drapeau : le mot-clef courant a deja ete consomme avant l'appel }
  GKwConsumed : Boolean;
  { Compteur d'args du dernier appel + arg shift @_ }
  GCallArgCount  : Integer;  { nb args du dernier ParseCallArgs }
  CurArgShiftIdx : Integer;  { index prochain shift dans @_ }

  { Expressions regulieres }
  LexExpectRegex : Boolean;  { True apres =~ ou !~ pour scanner regex }
  RegexSeq       : Integer;  { compteur labels regex dans DataTab }

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
Procedure LexInit;       Forward;
Procedure LexClose;      Forward;
Procedure EmitOpen;      Forward;
Procedure EmitClose;     Forward;
Procedure EmitDataSeg;   Forward;
Procedure EmitRuntime;   Forward;
Procedure EmitHeader;    Forward;
Procedure ParserAdvance; Forward;
Procedure ParseStmt;     Forward;
Procedure TypeInit;      Forward;
Procedure SymInit;       Forward;
Function  DataAddStr(Const S : TString) : Integer; Forward;
Function  DataAdd(Const ALbl : TString; AKind : TDataKind;
                  AInt : LongInt; Const AStr : TString) : Integer; Forward;
Procedure EmitDataStr(Const Lbl, S : TString); Forward;
Function  DataAddWord(Const ALbl : TString; AVal : LongInt) : Integer; Forward;
Function  DataAddConst(Const ALbl : TString; AVal : LongInt;
                       Const AStr : TString) : Integer; Forward;
Function  DataFindByLabel(Const ALbl : TString) : Integer; Forward;
Procedure EmitAllocLocal(Sz : Integer); Forward;
Procedure EmitStoreScalar(Const Lv : TExprVal); Forward;
Function  ExprMakeMem(SymIdx : Integer) : TExprVal; Forward;
Procedure ParseVarDecl; Forward;
Procedure ParseCallArgs; Forward;
Procedure EmitIncrDecr(Const Lv : TExprVal; IsInc : Boolean; Pre : Boolean;
                       Var Res : TExprVal); Forward;
Procedure ParsePostfixOps(Var Res : TExprVal); Forward;
Procedure EmitPrintVal(Const BXval : TString; Var E : TExprVal); Forward;
Procedure ParsePrintStmt; Forward;
Procedure ParseBlock; Forward;
Procedure ParseIfStmt; Forward;
Procedure LoopPush(Const BrkLbl, ContLbl, RedoLbl : TString); Forward;
Procedure LoopPop; Forward;
Procedure ParseWhileStmt; Forward;
Procedure ParseForStmt; Forward;
Procedure ParseForeachStmt; Forward;
Procedure ParseDoStmt; Forward;
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ExprMakeNone(Var Res : TExprVal); Forward;
Procedure ExprMakeUndef(Var Res : TExprVal); Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
Procedure ParseArrElemAccess(ArrIdx : Integer; Var Res : TExprVal); Forward;
Procedure ParseArrBuiltin(IsStmt : Boolean); Forward;
Function  HashSlotFind(HashSym : Integer; Const Key : TString) : Integer; Forward;
Function  HashSlotAdd(HashSym : Integer; Const Key : TString;
                      Const KeyLbl : TString) : Integer; Forward;
Procedure ParseHashElemAccess(HashIdx : Integer; Var Res : TExprVal); Forward;
Procedure ParseSubDecl; Forward;
Procedure ParseUseStmt; Forward;
Procedure ParseOpenStmt; Forward;
Procedure ParseCloseStmt; Forward;
Function  BinOpPrec(Const Op : TString) : Integer; Forward;
Function  IsRightAssoc(Const Op : TString) : Boolean; Forward;
Procedure ExprLoad(Var E : TExprVal); Forward;
Procedure ExprEmitBinOp(Const Op : TString;
                         Var Left, Right : TExprVal;
                         Var Res         : TExprVal); Forward;
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Function  CurTokIsInfixOp(Var OpStr : TString) : Boolean; Forward;
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Forward;
Procedure ParseExpr(Var Res : TExprVal); Forward;
Procedure ParseRegexOp(Const Op : TString;
                        Var Left : TExprVal;
                        Var Res  : TExprVal); Forward;
Function  SymMangle(Cat : TSymCat; IsMy : Boolean;
                    Const Name, Pkg : TString;
                    SeqN : Integer) : TString; Forward;
Function  SymAdd(Const Name : TString; Sigil : Char; Cat : TSymCat;
                 TypeIdx : Integer;
                 IsMy, IsOur, IsLocal : Boolean) : Integer; Forward;
Function  SymFind(Const Name : TString; Sigil : Char) : Integer; Forward;
Function  SymFindCat(Const Name : TString; Cat : TSymCat) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
Procedure SymWarn(Const Msg : TString); Forward;
Procedure SymError(Const Msg : TString); Forward;
Function  TypeSizeof(TypeIdx : Integer) : Integer; Forward;
Function  TypeMangle(TypeIdx : Integer) : TString; Forward;
Function  TypeKindName(TypeIdx : Integer) : TString; Forward;
Function  TypeIsCompatible(SrcIdx, DstIdx : Integer) : Boolean; Forward;
Function  ExprIsBoolFalse(Const E : TExprVal) : Boolean; Forward;
Function  LabelGen(Const Prefix : TString) : TString; Forward;
Procedure EmitRaw(Const S : TString); Forward;
Procedure EmitBlankLine; Forward;
Procedure EmitComment(Const S : TString); Forward;
Procedure EmitLabel(Const Name : TString); Forward;
Procedure EmitInstr(Const Mnem, Ops : TString); Forward;
Procedure EmitInstr1(Const Mnem : TString); Forward;

{ ============================================================
  INFRASTRUCTURE ET OPTIONS
  ============================================================ }

{ ---- Erreur fatale ---------------------------------------- }
Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('PERL86: ERREUR FATALE - ', Msg);
  Halt(EXIT_ERROR);
End;

{ ---- Aide en ligne ---------------------------------------- }
Procedure ShowHelp;Begin
 WriteLn('PERL86 - Cette commande permet de lancer le compilateur Perl pour de l''assembleur du microprocesseur ',
         '8086 ou 8088.');
 WriteLn;
 WriteLn('Syntaxe : PERL86 <source.pl> [sortie.asm] [-v] [-d] [-s] [-w]');
 WriteLn;
 WriteLn('  -v   mode verbeux (banniere + statistiques)');
 WriteLn('  -d   debug tokens (affiche chaque token)');
 WriteLn('  -s   use strict (toute variable doit etre declaree)');
 WriteLn('  -w   use warnings (avertissements supplementaires)');
 WriteLn('  -h   cette aide');
 WriteLn;
 WriteLn('Le fichier source doit avoir l''extension .pl');
 WriteLn('Le fichier de sortie defaut remplace .pl par .asm');
 Halt(EXIT_OK);
End;

{ ---- Initialisation des options --------------------------- }
Procedure InitOptions;
Begin
  Opts.SrcFile  := '';
  Opts.OutFile  := '';
  Opts.Verbose  := False;
  Opts.DebugTok := False;
  Opts.Strict   := False;
  Opts.Warnings := False;
End;

{ ---- Construction du nom de sortie par defaut ------------- }
Procedure BuildOutName;
Var
  Base : TString;
  I    : Integer;
Begin
  Base := Opts.SrcFile;
  { Retrancher l'extension .pl ou .PL }
  For I := Length(Base) DownTo 1 Do
  Begin
    If Base[I] = '.' Then
    Begin
      If (Copy(Base, I, 3) = '.pl') Or (Copy(Base, I, 3) = '.PL') Then
        Base := Copy(Base, 1, I - 1);
      Break;
    End;
  End;
  Opts.OutFile := Base + '.asm';
End;

{ ---- Analyse des arguments de la ligne de commande -------- }
Procedure ParseArgs;
Var
  I   : Integer;
  Arg : TString;
Begin
  If ParamCount = 0 Then
    ShowHelp;
  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    If (Arg = '-h') Or (Arg = '--help') Then
      ShowHelp
    Else If (Arg = '-v') Or (Arg = '--verbose') Then
      Opts.Verbose := True
    Else If (Arg = '-d') Or (Arg = '--debug') Then
      Opts.DebugTok := True
    Else If (Arg = '-s') Or (Arg = '--strict') Then
      Opts.Strict := True
    Else If (Arg = '-w') Or (Arg = '--warnings') Then
      Opts.Warnings := True
    Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
    Begin
      WriteLn('PERL86: option inconnue : ', Arg);
      Halt(EXIT_USAGE);
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('PERL86: argument inattendu : ', Arg);
      Halt(EXIT_USAGE);
    End;
    Inc(I);
  End;
  If Opts.SrcFile = '' Then
  Begin
    WriteLn('PERL86: aucun fichier source specifie.');
    Halt(EXIT_USAGE);
  End;
  If Opts.OutFile = '' Then
    BuildOutName;
End;

{ ---- Banniere --------------------------------------------- }
Procedure ShowBanner;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn('================================================');
  WriteLn(' PERL86 v', PERL86_VERSION, ' (', PERL86_DATE, ')');
  WriteLn(' Compilateur Perl -> assembleur 8086 / DOS');
  WriteLn('================================================');
  WriteLn(' Source  : ', Opts.SrcFile);
  WriteLn(' Sortie  : ', Opts.OutFile);
  If Opts.Strict   Then WriteLn(' Mode    : use strict');
  If Opts.Warnings Then WriteLn(' Mode    : use warnings');
  WriteLn('------------------------------------------------');
End;

{ ---- Statistiques finales --------------------------------- }
Procedure ShowStats;
Begin
  WriteLn('------------------------------------------------');
  WriteLn(' Lignes   : ', TotalLines);
  WriteLn(' Symboles : ', SymCount);
  WriteLn(' Erreurs  : ', ErrorCount);
  WriteLn(' Avert.   : ', WarnCount);
  If ErrorCount = 0 Then
    WriteLn(' Resultat : OK -> ', Opts.OutFile)
  Else
    WriteLn(' Resultat : ECHEC (', ErrorCount, ' erreur(s))');
  WriteLn('================================================');
End;

{ ---- Nettoyage des ressources ----------------------------- }
Procedure Cleanup;Begin
  LexClose;
  EmitClose;
End;

{ ============================================================
  STUBS
  ============================================================ }

Procedure TypeInit;
Var
  I : Integer;
Begin
  TypeCount := 0;
  For I := 0 To MAX_TYPE - 1 Do
  Begin
    TypeTab[I].Name    := '';
    TypeTab[I].Kind    := TKD_UNKNOWN;
    TypeTab[I].Size    := 0;
    TypeTab[I].ElemIdx := TY_UNKNOWN;
  End;
  { TY_IDX_SCALAR = 0 : scalaire unifie int/float/str, taille 2 octets (mot) }
  TypeTab[TY_IDX_SCALAR].Name    := 'scalar';
  TypeTab[TY_IDX_SCALAR].Kind    := TKD_SCALAR;
  TypeTab[TY_IDX_SCALAR].Size    := 2;
  TypeTab[TY_IDX_SCALAR].ElemIdx := TY_UNKNOWN;
  { TY_IDX_ARRAY = 1 : tableau @arr, represente comme pointeur (2 octets) }
  TypeTab[TY_IDX_ARRAY].Name    := 'array';
  TypeTab[TY_IDX_ARRAY].Kind    := TKD_ARRAY;
  TypeTab[TY_IDX_ARRAY].Size    := 2;
  TypeTab[TY_IDX_ARRAY].ElemIdx := TY_IDX_SCALAR;
  { TY_IDX_HASH = 2 : hash %h, represente comme pointeur (2 octets) }
  TypeTab[TY_IDX_HASH].Name    := 'hash';
  TypeTab[TY_IDX_HASH].Kind    := TKD_HASH;
  TypeTab[TY_IDX_HASH].Size    := 2;
  TypeTab[TY_IDX_HASH].ElemIdx := TY_IDX_SCALAR;
  { TY_IDX_REF = 3 : reference \$v ou \@arr, taille 2 octets (pointeur) }
  TypeTab[TY_IDX_REF].Name    := 'ref';
  TypeTab[TY_IDX_REF].Kind    := TKD_REF;
  TypeTab[TY_IDX_REF].Size    := 2;
  TypeTab[TY_IDX_REF].ElemIdx := TY_UNKNOWN;
  { TY_IDX_CODE = 4 : reference de code \&sub, taille 2 octets }
  TypeTab[TY_IDX_CODE].Name    := 'code';
  TypeTab[TY_IDX_CODE].Kind    := TKD_CODE;
  TypeTab[TY_IDX_CODE].Size    := 2;
  TypeTab[TY_IDX_CODE].ElemIdx := TY_UNKNOWN;
  { TY_IDX_UNDEF = 5 : undef, taille 2 octets (valeur 0) }
  TypeTab[TY_IDX_UNDEF].Name    := 'undef';
  TypeTab[TY_IDX_UNDEF].Kind    := TKD_UNDEF;
  TypeTab[TY_IDX_UNDEF].Size    := 2;
  TypeTab[TY_IDX_UNDEF].ElemIdx := TY_UNKNOWN;
  { TY_IDX_MIXED = 6 : contexte indetermine (liste heterogene) }
  TypeTab[TY_IDX_MIXED].Name    := 'mixed';
  TypeTab[TY_IDX_MIXED].Kind    := TKD_MIXED;
  TypeTab[TY_IDX_MIXED].Size    := 2;
  TypeTab[TY_IDX_MIXED].ElemIdx := TY_UNKNOWN;
  TypeCount := TY_PRIM_COUNT;  { 7 types primitifs enregistres }
End;

Procedure SymInit;
Var
  I : Integer;
Begin
  SymCount     := 0;
  ScopeTop     := 0;
  CurScope     := 0;
  LabelSeq     := 0;
  CurFrameSize := 0;
  CurFnDepth   := 0;
  LoopTop      := 0;
  GKwConsumed  := False;
  CurFnRetLbl  := '';
  CurFnName    := '';
  For I := 0 To MAX_SYM - 1 Do
  Begin
    SymTab[I].Name        := '';
    SymTab[I].SigilName   := '';
    SymTab[I].MangledName := '';
    SymTab[I].Cat         := SC_SCALAR;
    SymTab[I].TypeIdx     := TY_UNKNOWN;
    SymTab[I].ScopeLevel  := 0;
    SymTab[I].Offset      := 0;
    SymTab[I].IsMy        := False;
    SymTab[I].IsOur       := False;
    SymTab[I].IsLocal     := False;
    SymTab[I].IsRef       := False;
    SymTab[I].DeclLine    := 0;
  End;
End;

Procedure EmitOpen;
Begin
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  If IOResult <> 0 Then
    FatalError('Impossible d''ouvrir le fichier de sortie : ' + Opts.OutFile);
  OutFOpen := True;
  EmitHeader;   { emet le preambule ASM }
End;

Procedure EmitClose;
Begin
  If Not OutFOpen Then Exit;
  { Code de sortie par defaut : exit(0) en cas de chute de fin de script }
  EmitBlankLine;
  EmitComment('Fin du script Perl - sortie implicite code 0');
  EmitInstr('MOV', 'AX, 4C00h');
  EmitInstr('INT', '21h');
  EmitRaw('_PRF_main ENDP');
  EmitBlankLine;
  EmitRuntime;   { Routines runtime dans _TEXT }
  EmitRaw('_TEXT   ENDS');
  EmitBlankLine;
  EmitDataSeg;   { Segment de donnees }
  EmitBlankLine;
  EmitRaw('        END     _PRF_main');
  Close(OutF);
  OutFOpen := False;
End;

Procedure EmitHeader;
Begin
  EmitComment('Generated by PERL86 v' + PERL86_VERSION + ' - ' + PERL86_DATE);
  EmitComment('Source : ' + Opts.SrcFile);
  EmitBlankLine;
  EmitRaw('        .MODEL  SMALL');
  EmitRaw('        .STACK  1024');
  EmitBlankLine;
  EmitRaw('_TEXT   SEGMENT WORD PUBLIC ''CODE''');
  EmitRaw('        ASSUME  CS:_TEXT, DS:_DATA');
  EmitBlankLine;
  EmitRaw('_PRF_main PROC NEAR');
  EmitInstr('MOV', 'AX, @DATA');
  EmitInstr('MOV', 'DS, AX');
  EmitBlankLine;
End;

Procedure EmitDataSeg;
{ Emet le segment _DATA complet : DW (scalaires our/constantes),           }
{ DB (octets), DB '...',0 (chaines litterales), DW N DUP(0) (tableaux).    }
Var
  I   : Integer;
  Tmp : TString;
Begin
  EmitRaw('_DATA   SEGMENT WORD PUBLIC ''DATA''');
  If DataCount = 0 Then
    EmitRaw('; _PRL_DUMMY  DB  0')  { segment vide : rien a emettre }
  Else
    For I := 0 To DataCount - 1 Do
    Begin
      EmitBlankLine;
      Case DataTab[I].Kind Of
        DK_WORD :
          Begin
            Str(DataTab[I].IntVal, Tmp);
            EmitRaw(DataTab[I].LblName + ':');
            EmitRaw('        DW  ' + Tmp);
          End;
        DK_BYTE :
          Begin
            Str(DataTab[I].IntVal And $FF, Tmp);
            EmitRaw(DataTab[I].LblName + ':');
            EmitRaw('        DB  ' + Tmp);
          End;
        DK_STR :
          EmitDataStr(DataTab[I].LblName, DataTab[I].StrVal);
        DK_ARRAY_BLK :
          Begin
            Str(DataTab[I].ElemCount, Tmp);
            EmitRaw(DataTab[I].LblName + ':');
            EmitRaw('        DW  ' + Tmp + ' DUP(0)');
          End;
      End;
    End;
  EmitBlankLine;
  { Variables globales de capture $1 et $2 }
  EmitRaw('_PRCAP_1:');
  EmitRaw('        DW  0');
  EmitRaw('_PRCAP_2:');
  EmitRaw('        DW  0');
  EmitBlankLine;
  EmitRaw('_DATA   ENDS');
End;

{ ============================================================
  EmitRuntime : procedures helper 8086 dans _TEXT
  _PRRT_REMATCH  : SI=sujet DI=pattern -> AX=1 si trouve
  _PRRT_RESUB    : SI=sujet DI=pattern BX=repl -> AX=1 si subst
  ============================================================ }
Procedure EmitRuntime;
Var
  Idx : Integer;
Begin
  If RuntimeEmitted Then Exit;  { Emettre le runtime une seule fois }
  RuntimeEmitted := True;
  EmitBlankLine;
  EmitRaw('; === Runtime PERL86 ===');
  EmitBlankLine;
  { ---- _PRRT_REMATCH : recherche de chaine (strstr basique) ---- }
  EmitRaw('_PRRT_REMATCH PROC NEAR');
  EmitRaw('        PUSH  BP');
  EmitRaw('        MOV   BP, SP');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('        PUSH  BX');
  EmitRaw('        PUSH  CX');
  EmitRaw('        PUSH  DX');
  EmitRaw('        MOV   BX, SI');
  EmitRaw('_PRRT_RML:');
  EmitRaw('        MOV   AL, [BX]');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_RMFL');
  EmitRaw('        MOV   SI, BX');
  EmitRaw('        MOV   CX, DI');
  EmitRaw('_PRRT_RMC:');
  EmitRaw('        MOV   AL, [CX]');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_RMOK');
  EmitRaw('        MOV   DL, [SI]');
  EmitRaw('        CMP   AL, DL');
  EmitRaw('        JNE   _PRRT_RMN');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   CX');
  EmitRaw('        JMP   _PRRT_RMC');
  EmitRaw('_PRRT_RMN:');
  EmitRaw('        INC   BX');
  EmitRaw('        JMP   _PRRT_RML');
  EmitRaw('_PRRT_RMOK:');
  EmitRaw('        MOV   AX, 1');
  EmitRaw('        JMP   _PRRT_RMDN');
  EmitRaw('_PRRT_RMFL:');
  EmitRaw('        XOR   AX, AX');
  EmitRaw('_PRRT_RMDN:');
  EmitRaw('        POP   DX');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        POP   BP');
  EmitRaw('        RET');
  EmitRaw('_PRRT_REMATCH ENDP');
  EmitBlankLine;
  { ---- _PRRT_RESUB : substitution premiere occurrence ---- }
  { SI=sujet DI=pattern BX=remplacement -> AX=1 si effectuee }
  EmitRaw('_PRRT_RESUB PROC NEAR');
  EmitRaw('        PUSH  BP');
  EmitRaw('        MOV   BP, SP');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('        PUSH  BX');
  EmitRaw('        PUSH  CX');
  EmitRaw('        PUSH  DX');
  EmitRaw('        MOV   BX, SI');
  EmitRaw('_PRRT_RSL:');
  EmitRaw('        MOV   AL, [BX]');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_RSFL');
  EmitRaw('        MOV   SI, BX');
  EmitRaw('        MOV   CX, DI');
  EmitRaw('_PRRT_RSC:');
  EmitRaw('        MOV   AL, [CX]');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_RSOK');
  EmitRaw('        MOV   DL, [SI]');
  EmitRaw('        CMP   AL, DL');
  EmitRaw('        JNE   _PRRT_RSN');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   CX');
  EmitRaw('        JMP   _PRRT_RSC');
  EmitRaw('_PRRT_RSN:');
  EmitRaw('        INC   BX');
  EmitRaw('        JMP   _PRRT_RSL');
  EmitRaw('_PRRT_RSOK:');
  EmitRaw('        MOV   SI, BX');
  EmitRaw('        MOV   CX, [BP-6]');
  EmitRaw('_PRRT_RSCPY:');
  EmitRaw('        MOV   AL, [CX]');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_RS0');
  EmitRaw('        MOV   [SI], AL');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   CX');
  EmitRaw('        JMP   _PRRT_RSCPY');
  EmitRaw('_PRRT_RS0:');
  EmitRaw('        MOV   BYTE PTR [SI], 0');
  EmitRaw('        MOV   AX, 1');
  EmitRaw('        JMP   _PRRT_RSDN');
  EmitRaw('_PRRT_RSFL:');
  EmitRaw('        XOR   AX, AX');
  EmitRaw('_PRRT_RSDN:');
  EmitRaw('        POP   DX');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        POP   BP');
  EmitRaw('        RET');
  EmitRaw('_PRRT_RESUB ENDP');
  EmitBlankLine;
  { ---- _PRRT_ABS : AX=|AX| ---- }
  EmitRaw('_PRRT_ABS PROC NEAR');
  EmitRaw('        TEST  AX, AX');
  EmitRaw('        JNS   _PRRT_ABS_OK');
  EmitRaw('        NEG   AX');
  EmitRaw('_PRRT_ABS_OK:');
  EmitRaw('        RET');
  EmitRaw('_PRRT_ABS ENDP');
  EmitBlankLine;
  { ---- _PRRT_ORD : SI=str -> AX=premier octet ---- }
  EmitRaw('_PRRT_ORD PROC NEAR');
  EmitRaw('        XOR   AX, AX');
  EmitRaw('        MOV   AL, [SI]');
  EmitRaw('        RET');
  EmitRaw('_PRRT_ORD ENDP');
  EmitBlankLine;
  { ---- _PRRT_CHR : AX=n, DI=buf -> buf[0]=chr(n), buf[1]=0 ---- }
  EmitRaw('_PRRT_CHR PROC NEAR');
  EmitRaw('        MOV   [DI], AL');
  EmitRaw('        PUSH  BX');
  EmitRaw('        MOV   BX, DI');
  EmitRaw('        INC   BX');
  EmitRaw('        MOV   BYTE PTR [BX], 0');
  EmitRaw('        POP   BX');
  EmitRaw('        RET');
  EmitRaw('_PRRT_CHR ENDP');
  EmitBlankLine;
  { ---- _PRRT_CHOMP : SI=str -> supprime '\n' final, AX=0/1 ---- }
  EmitRaw('_PRRT_CHOMP PROC NEAR');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('        MOV   DI, SI');
  EmitRaw('_PRRT_CHML:');
  EmitRaw('        MOV   AL, [DI]');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_CHME');
  EmitRaw('        INC   DI');
  EmitRaw('        JMP   _PRRT_CHML');
  EmitRaw('_PRRT_CHME:');
  EmitRaw('        CMP   DI, SI');
  EmitRaw('        JE    _PRRT_CHMNO');
  EmitRaw('        DEC   DI');
  EmitRaw('        MOV   AL, [DI]');
  EmitRaw('        CMP   AL, 10');
  EmitRaw('        JNE   _PRRT_CHMNO');
  EmitRaw('        MOV   BYTE PTR [DI], 0');
  EmitRaw('        MOV   AX, 1');
  EmitRaw('        JMP   _PRRT_CHMRN');
  EmitRaw('_PRRT_CHMNO:');
  EmitRaw('        XOR   AX, AX');
  EmitRaw('_PRRT_CHMRN:');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_PRRT_CHOMP ENDP');
  EmitBlankLine;
  { ---- _PRRT_CHOP : SI=str -> supprime dernier car, AX=ce car ---- }
  EmitRaw('_PRRT_CHOP PROC NEAR');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('        MOV   DI, SI');
  EmitRaw('_PRRT_CHPL:');
  EmitRaw('        MOV   AL, [DI]');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_CHPE');
  EmitRaw('        INC   DI');
  EmitRaw('        JMP   _PRRT_CHPL');
  EmitRaw('_PRRT_CHPE:');
  EmitRaw('        XOR   AX, AX');
  EmitRaw('        CMP   DI, SI');
  EmitRaw('        JE    _PRRT_CHPRN');
  EmitRaw('        DEC   DI');
  EmitRaw('        MOV   AL, [DI]');
  EmitRaw('        MOV   BYTE PTR [DI], 0');
  EmitRaw('_PRRT_CHPRN:');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_PRRT_CHOP ENDP');
  EmitBlankLine;
  { ---- _PRRT_UC : SI=src, DI=dst -> uppercased copy, AX=DI ---- }
  EmitRaw('_PRRT_UC PROC NEAR');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('_PRRT_UCL:');
  EmitRaw('        MOV   AL, [SI]');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_UCE');
  EmitRaw('        CMP   AL, 97');
  EmitRaw('        JL    _PRRT_UCCP');
  EmitRaw('        CMP   AL, 122');
  EmitRaw('        JG    _PRRT_UCCP');
  EmitRaw('        SUB   AL, 32');
  EmitRaw('_PRRT_UCCP:');
  EmitRaw('        MOV   [DI], AL');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   DI');
  EmitRaw('        JMP   _PRRT_UCL');
  EmitRaw('_PRRT_UCE:');
  EmitRaw('        MOV   BYTE PTR [DI], 0');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_PRRT_UC ENDP');
  EmitBlankLine;
  { ---- _PRRT_LC : SI=src, DI=dst -> lowercased copy, AX=DI ---- }
  EmitRaw('_PRRT_LC PROC NEAR');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('_PRRT_LCL:');
  EmitRaw('        MOV   AL, [SI]');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_LCE');
  EmitRaw('        CMP   AL, 65');
  EmitRaw('        JL    _PRRT_LCCP');
  EmitRaw('        CMP   AL, 90');
  EmitRaw('        JG    _PRRT_LCCP');
  EmitRaw('        ADD   AL, 32');
  EmitRaw('_PRRT_LCCP:');
  EmitRaw('        MOV   [DI], AL');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   DI');
  EmitRaw('        JMP   _PRRT_LCL');
  EmitRaw('_PRRT_LCE:');
  EmitRaw('        MOV   BYTE PTR [DI], 0');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_PRRT_LC ENDP');
  EmitBlankLine;
  { ---- _PRRT_UCFIRST : comme UC mais seulement premier char ---- }
  EmitRaw('_PRRT_UCFIRST PROC NEAR');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('        MOV   AL, [SI]');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_UCFE');
  EmitRaw('        CMP   AL, 97');
  EmitRaw('        JL    _PRRT_UCFC');
  EmitRaw('        CMP   AL, 122');
  EmitRaw('        JG    _PRRT_UCFC');
  EmitRaw('        SUB   AL, 32');
  EmitRaw('_PRRT_UCFC:');
  EmitRaw('        MOV   [DI], AL');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   DI');
  EmitRaw('_PRRT_UCFR:');
  EmitRaw('        MOV   AL, [SI]');
  EmitRaw('        MOV   [DI], AL');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_UCFE');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   DI');
  EmitRaw('        JMP   _PRRT_UCFR');
  EmitRaw('_PRRT_UCFE:');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_PRRT_UCFIRST ENDP');
  EmitBlankLine;
  { ---- _PRRT_LCFIRST : comme LC mais seulement premier char ---- }
  EmitRaw('_PRRT_LCFIRST PROC NEAR');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('        MOV   AL, [SI]');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_LCFE');
  EmitRaw('        CMP   AL, 65');
  EmitRaw('        JL    _PRRT_LCFC');
  EmitRaw('        CMP   AL, 90');
  EmitRaw('        JG    _PRRT_LCFC');
  EmitRaw('        ADD   AL, 32');
  EmitRaw('_PRRT_LCFC:');
  EmitRaw('        MOV   [DI], AL');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   DI');
  EmitRaw('_PRRT_LCFR:');
  EmitRaw('        MOV   AL, [SI]');
  EmitRaw('        MOV   [DI], AL');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_LCFE');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   DI');
  EmitRaw('        JMP   _PRRT_LCFR');
  EmitRaw('_PRRT_LCFE:');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_PRRT_LCFIRST ENDP');
  EmitBlankLine;
  { ---- _PRRT_INDEX : SI=str, DI=pat -> AX=pos (0-base) ou -1 ---- }
  EmitRaw('_PRRT_INDEX PROC NEAR');
  EmitRaw('        PUSH  BP');
  EmitRaw('        MOV   BP, SP');
  EmitRaw('        SUB   SP, 2');
  EmitRaw('        MOV   WORD PTR [BP-2], DI');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('        PUSH  BX');
  EmitRaw('        PUSH  DX');
  EmitRaw('        MOV   BX, SI');
  EmitRaw('        XOR   DX, DX');
  EmitRaw('_PRRT_IDXL:');
  EmitRaw('        MOV   AL, [BX]');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_IDXFL');
  EmitRaw('        MOV   SI, BX');
  EmitRaw('        MOV   DI, WORD PTR [BP-2]');
  EmitRaw('_PRRT_IDXC:');
  EmitRaw('        MOV   AL, [DI]');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_IDXOK');
  EmitRaw('        MOV   AH, [SI]');
  EmitRaw('        CMP   AL, AH');
  EmitRaw('        JNE   _PRRT_IDXN');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   DI');
  EmitRaw('        JMP   _PRRT_IDXC');
  EmitRaw('_PRRT_IDXN:');
  EmitRaw('        INC   BX');
  EmitRaw('        INC   DX');
  EmitRaw('        JMP   _PRRT_IDXL');
  EmitRaw('_PRRT_IDXOK:');
  EmitRaw('        MOV   AX, DX');
  EmitRaw('        JMP   _PRRT_IDXDN');
  EmitRaw('_PRRT_IDXFL:');
  EmitRaw('        MOV   AX, 0FFFFh');
  EmitRaw('_PRRT_IDXDN:');
  EmitRaw('        POP   DX');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        ADD   SP, 2');
  EmitRaw('        POP   BP');
  EmitRaw('        RET');
  EmitRaw('_PRRT_INDEX ENDP');
  EmitBlankLine;
  { ---- _PRRT_RINDEX : SI=str, DI=pat -> AX=derniere pos ou -1 ---- }
  EmitRaw('_PRRT_RINDEX PROC NEAR');
  EmitRaw('        PUSH  BP');
  EmitRaw('        MOV   BP, SP');
  EmitRaw('        SUB   SP, 2');
  EmitRaw('        MOV   WORD PTR [BP-2], DI');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('        PUSH  BX');
  EmitRaw('        PUSH  DX');
  EmitRaw('        MOV   BX, SI');
  EmitRaw('        XOR   DX, DX');
  EmitRaw('        MOV   AX, 0FFFFh');
  EmitRaw('_PRRT_RIL:');
  EmitRaw('        MOV   AL, [BX]');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_RIDN');
  EmitRaw('        MOV   SI, BX');
  EmitRaw('        MOV   DI, WORD PTR [BP-2]');
  EmitRaw('_PRRT_RIC:');
  EmitRaw('        MOV   AL, [DI]');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_RIOK');
  EmitRaw('        MOV   AH, [SI]');
  EmitRaw('        CMP   AL, AH');
  EmitRaw('        JNE   _PRRT_RIN');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   DI');
  EmitRaw('        JMP   _PRRT_RIC');
  EmitRaw('_PRRT_RIN:');
  EmitRaw('        INC   BX');
  EmitRaw('        INC   DX');
  EmitRaw('        JMP   _PRRT_RIL');
  EmitRaw('_PRRT_RIOK:');
  EmitRaw('        MOV   AX, DX');
  EmitRaw('        INC   BX');
  EmitRaw('        INC   DX');
  EmitRaw('        JMP   _PRRT_RIL');
  EmitRaw('_PRRT_RIDN:');
  EmitRaw('        POP   DX');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        ADD   SP, 2');
  EmitRaw('        POP   BP');
  EmitRaw('        RET');
  EmitRaw('_PRRT_RINDEX ENDP');
  EmitBlankLine;
  { ---- _PRRT_SUBSTR : SI=str, BX=off, CX=len, DI=dst -> copy ---- }
  EmitRaw('_PRRT_SUBSTR PROC NEAR');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('        PUSH  BX');
  EmitRaw('        PUSH  CX');
  EmitRaw('        TEST  BX, BX');
  EmitRaw('        JZ    _PRRT_SUBST');
  EmitRaw('_PRRT_SUBADV:');
  EmitRaw('        MOV   AL, [SI]');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_SUBEN');
  EmitRaw('        INC   SI');
  EmitRaw('        DEC   BX');
  EmitRaw('        JNZ   _PRRT_SUBADV');
  EmitRaw('_PRRT_SUBST:');
  EmitRaw('_PRRT_SUBCPY:');
  EmitRaw('        MOV   AL, [SI]');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_SUBEN');
  EmitRaw('        CMP   CX, 0FFFFh');
  EmitRaw('        JE    _PRRT_SUBND');
  EmitRaw('        TEST  CX, CX');
  EmitRaw('        JZ    _PRRT_SUBEN');
  EmitRaw('        DEC   CX');
  EmitRaw('_PRRT_SUBND:');
  EmitRaw('        MOV   [DI], AL');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   DI');
  EmitRaw('        JMP   _PRRT_SUBCPY');
  EmitRaw('_PRRT_SUBEN:');
  EmitRaw('        MOV   BYTE PTR [DI], 0');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_PRRT_SUBSTR ENDP');
  EmitBlankLine;
  { ---- _PRRT_HEX2INT : SI=str hex -> AX ---- }
  EmitRaw('_PRRT_HEX2INT PROC NEAR');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  BX');
  EmitRaw('        XOR   AX, AX');
  EmitRaw('        XOR   BX, BX');
  EmitRaw('        MOV   BL, [SI]');
  EmitRaw('        CMP   BL, 48');
  EmitRaw('        JNE   _PRRT_HIL');
  EmitRaw('        MOV   BL, [SI+1]');
  EmitRaw('        CMP   BL, 120');
  EmitRaw('        JE    _PRRT_HISKIP');
  EmitRaw('        CMP   BL, 88');
  EmitRaw('        JNE   _PRRT_HIL');
  EmitRaw('_PRRT_HISKIP:');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   SI');
  EmitRaw('_PRRT_HIL:');
  EmitRaw('        XOR   BX, BX');
  EmitRaw('        MOV   BL, [SI]');
  EmitRaw('        TEST  BL, BL');
  EmitRaw('        JZ    _PRRT_HIDN');
  EmitRaw('        CMP   BL, 48');
  EmitRaw('        JL    _PRRT_HIDN');
  EmitRaw('        CMP   BL, 57');
  EmitRaw('        JLE   _PRRT_HIDIG');
  EmitRaw('        CMP   BL, 65');
  EmitRaw('        JL    _PRRT_HIDN');
  EmitRaw('        CMP   BL, 70');
  EmitRaw('        JLE   _PRRT_HIHEX');
  EmitRaw('        CMP   BL, 97');
  EmitRaw('        JL    _PRRT_HIDN');
  EmitRaw('        CMP   BL, 102');
  EmitRaw('        JG    _PRRT_HIDN');
  EmitRaw('        SUB   BL, 87');
  EmitRaw('        JMP   _PRRT_HIACC');
  EmitRaw('_PRRT_HIHEX:');
  EmitRaw('        SUB   BL, 55');
  EmitRaw('        JMP   _PRRT_HIACC');
  EmitRaw('_PRRT_HIDIG:');
  EmitRaw('        SUB   BL, 48');
  EmitRaw('_PRRT_HIACC:');
  EmitRaw('        SHL   AX, 1');
  EmitRaw('        SHL   AX, 1');
  EmitRaw('        SHL   AX, 1');
  EmitRaw('        SHL   AX, 1');
  EmitRaw('        OR    AX, BX');
  EmitRaw('        INC   SI');
  EmitRaw('        JMP   _PRRT_HIL');
  EmitRaw('_PRRT_HIDN:');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_PRRT_HEX2INT ENDP');
  EmitBlankLine;
  { ---- _PRRT_OCT2INT : SI=str octal -> AX ---- }
  EmitRaw('_PRRT_OCT2INT PROC NEAR');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  BX');
  EmitRaw('        XOR   AX, AX');
  EmitRaw('_PRRT_OIL:');
  EmitRaw('        XOR   BX, BX');
  EmitRaw('        MOV   BL, [SI]');
  EmitRaw('        TEST  BL, BL');
  EmitRaw('        JZ    _PRRT_OIDN');
  EmitRaw('        SUB   BL, 48');
  EmitRaw('        JL    _PRRT_OIDN');
  EmitRaw('        CMP   BL, 7');
  EmitRaw('        JG    _PRRT_OIDN');
  EmitRaw('        SHL   AX, 1');
  EmitRaw('        SHL   AX, 1');
  EmitRaw('        SHL   AX, 1');
  EmitRaw('        OR    AX, BX');
  EmitRaw('        INC   SI');
  EmitRaw('        JMP   _PRRT_OIL');
  EmitRaw('_PRRT_OIDN:');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   SI');
  EmitRaw('        RET');
  EmitRaw('_PRRT_OCT2INT ENDP');
  EmitBlankLine;
  { _PRRT_READLINE - lire une ligne depuis un handle DOS }
  { Entree : BX=handle                                             }
  { Sortie : AX=OFFSET _PRRT_FHBUF (ptr ligne null-terminee)      }
  {          AX=0 si EOF avant de lire quoi que ce soit            }
  { Utilise : _PRRT_FHBUF (256 octets dans DATA)                   }
  { Garantir que _PRRT_FHBUF est dans la table de donnees          }
  If DataFindByLabel('_PRRT_FHBUF') < 0 Then
  Begin
    Idx := DataAdd('_PRRT_FHBUF', DK_ARRAY_BLK, 0, '');
    If Idx >= 0 Then DataTab[Idx].ElemCount := 128;  { 256 octets }
  End;
  EmitRaw('_PRRT_READLINE PROC NEAR');
  EmitRaw('        PUSH  BP');
  EmitRaw('        MOV   BP, SP');
  EmitRaw('        PUSH  BX');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('        MOV   DI, OFFSET _PRRT_FHBUF');
  EmitRaw('        MOV   SI, 0');
  EmitRaw('_PRRT_RLL:');
  EmitRaw('        CMP   SI, 0FEh');
  EmitRaw('        JGE   _PRRT_RLDON');
  EmitRaw('        MOV   BX, WORD PTR [BP-2]');
  EmitRaw('        MOV   AH, 3Fh');
  EmitRaw('        MOV   CX, 1');
  EmitRaw('        MOV   DX, DI');
  EmitRaw('        INT   21h');
  EmitRaw('        JC    _PRRT_RLEOF');
  EmitRaw('        TEST  AX, AX');
  EmitRaw('        JZ    _PRRT_RLEOF');
  EmitRaw('        MOV   AL, BYTE PTR [DI]');
  EmitRaw('        CMP   AL, 0Ah');
  EmitRaw('        JE    _PRRT_RLDON');
  EmitRaw('        CMP   AL, 0Dh');
  EmitRaw('        JE    _PRRT_RLDON');
  EmitRaw('        INC   DI');
  EmitRaw('        INC   SI');
  EmitRaw('        JMP   _PRRT_RLL');
  EmitRaw('_PRRT_RLEOF:');
  EmitRaw('        TEST  SI, SI');
  EmitRaw('        JZ    _PRRT_RLNUL');
  EmitRaw('        JMP   _PRRT_RLDON');
  EmitRaw('_PRRT_RLNUL:');
  EmitRaw('        XOR   AX, AX');
  EmitRaw('        JMP   _PRRT_RLRET');
  EmitRaw('_PRRT_RLDON:');
  EmitRaw('        MOV   BYTE PTR [DI], 0');
  EmitRaw('        MOV   AX, OFFSET _PRRT_FHBUF');
  EmitRaw('_PRRT_RLRET:');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   BP');
  EmitRaw('        RET');
  EmitRaw('_PRRT_READLINE ENDP');
  EmitBlankLine;
  { _PRRT_STRLEN - longueur d''une chaine C                }
  { Entree : SI=ptr chaine null-terminee                             }
  { Sortie : AX=longueur, CX=longueur                               }
  EmitRaw('_PRRT_STRLEN PROC NEAR');
  EmitRaw('        PUSH  DI');
  EmitRaw('        MOV   DI, SI');
  EmitRaw('_PRRT_STL:');
  EmitRaw('        MOV   AL, [DI]');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_STE');
  EmitRaw('        INC   DI');
  EmitRaw('        JMP   _PRRT_STL');
  EmitRaw('_PRRT_STE:');
  EmitRaw('        MOV   AX, DI');
  EmitRaw('        SUB   AX, SI');
  EmitRaw('        MOV   CX, AX');
  EmitRaw('        POP   DI');
  EmitRaw('        RET');
  EmitRaw('_PRRT_STRLEN ENDP');
  EmitBlankLine;
  { _PRRT_PRINT - ecrire une chaine sur un handle DOS     }
  { Entree : BX=handle, SI=msg, CX=longueur                         }
  { Appel DOS : AH=40h BX=handle CX=nb_octets DS:DX=buf             }
  EmitRaw('_PRRT_PRINT PROC NEAR');
  EmitRaw('        PUSH  AX');
  EmitRaw('        PUSH  DX');
  EmitRaw('        MOV   DX, SI');
  EmitRaw('        MOV   AH, 40h');
  EmitRaw('        INT   21h');
  EmitRaw('        POP   DX');
  EmitRaw('        POP   AX');
  EmitRaw('        RET');
  EmitRaw('_PRRT_PRINT ENDP');
  EmitBlankLine;
  { _PRRT_PRINTLN - ecrire CR+LF sur un handle DOS        }
  { Entree : BX=handle                                               }
  If DataFindByLabel('_PRRT_CRLF') < 0 Then
    DataAdd('_PRRT_CRLF', DK_STR, 0, #13#10);
  EmitRaw('_PRRT_PRINTLN PROC NEAR');
  EmitRaw('        PUSH  AX');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  CX');
  EmitRaw('        PUSH  DX');
  EmitRaw('        MOV   SI, OFFSET _PRRT_CRLF');
  EmitRaw('        MOV   DX, SI');
  EmitRaw('        MOV   CX, 2');
  EmitRaw('        MOV   AH, 40h');
  EmitRaw('        INT   21h');
  EmitRaw('        POP   DX');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   SI');
  EmitRaw('        POP   AX');
  EmitRaw('        RET');
  EmitRaw('_PRRT_PRINTLN ENDP');
  EmitBlankLine;
  { _PRRT_ITOA - convertir entier signe en chaine ASCII   }
  { Entree : AX=entier, DI=buffer de destination                     }
  { Sortie : DI inchange (pointe debut buffer), null-termine         }
  EmitRaw('_PRRT_ITOA PROC NEAR');
  EmitRaw('        PUSH  BP');
  EmitRaw('        MOV   BP, SP');
  EmitRaw('        PUSH  BX');
  EmitRaw('        PUSH  CX');
  EmitRaw('        PUSH  DX');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('        TEST  AX, AX');
  EmitRaw('        JGE   _PRRT_ITP');
  EmitRaw('        NEG   AX');
  EmitRaw('        MOV   BYTE PTR [DI], ''-''');
  EmitRaw('        INC   DI');
  EmitRaw('_PRRT_ITP:');
  EmitRaw('        MOV   SI, DI');
  EmitRaw('        MOV   BX, 10');
  EmitRaw('        XOR   CX, CX');
  EmitRaw('_PRRT_ITDL:');
  EmitRaw('        XOR   DX, DX');
  EmitRaw('        DIV   BX');
  EmitRaw('        ADD   DL, 48');
  EmitRaw('        PUSH  DX');
  EmitRaw('        INC   CX');
  EmitRaw('        TEST  AX, AX');
  EmitRaw('        JNZ   _PRRT_ITDL');
  EmitRaw('_PRRT_ITRL:');
  EmitRaw('        POP   DX');
  EmitRaw('        MOV   [SI], DL');
  EmitRaw('        INC   SI');
  EmitRaw('        LOOP  _PRRT_ITRL');
  EmitRaw('        MOV   BYTE PTR [SI], 0');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        POP   DX');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   BP');
  EmitRaw('        RET');
  EmitRaw('_PRRT_ITOA ENDP');
  EmitBlankLine;
  { _PRRT_CONCAT - strcat(DI, SI) : ajouter SI a la fin  }
  { Entree : DI=dst (chaine C), SI=src (chaine C)                   }
  EmitRaw('_PRRT_CONCAT PROC NEAR');
  EmitRaw('        PUSH  AX');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('_PRRT_CCW:');
  EmitRaw('        MOV   AL, [DI]');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_CCC');
  EmitRaw('        INC   DI');
  EmitRaw('        JMP   _PRRT_CCW');
  EmitRaw('_PRRT_CCC:');
  EmitRaw('        MOV   AL, [SI]');
  EmitRaw('        MOV   [DI], AL');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_CCE');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   DI');
  EmitRaw('        JMP   _PRRT_CCC');
  EmitRaw('_PRRT_CCE:');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        POP   AX');
  EmitRaw('        RET');
  EmitRaw('_PRRT_CONCAT ENDP');
  EmitBlankLine;
  { _PRRT_STRREPEAT - repeter src n fois dans dst         }
  { Entree : DI=dst, SI=src, CX=n  (CX=0 -> chaine vide)            }
  EmitRaw('_PRRT_STRREPEAT PROC NEAR');
  EmitRaw('        PUSH  BP');
  EmitRaw('        MOV   BP, SP');
  EmitRaw('        PUSH  SI');
  EmitRaw('        PUSH  DI');
  EmitRaw('        PUSH  CX');
  EmitRaw('        PUSH  BX');
  EmitRaw('        PUSH  AX');
  EmitRaw('        MOV   BYTE PTR [DI], 0');
  EmitRaw('        TEST  CX, CX');
  EmitRaw('        JZ    _PRRT_SRPE');
  EmitRaw('        MOV   BX, DI');
  EmitRaw('_PRRT_SRPL:');
  EmitRaw('        MOV   SI, WORD PTR [BP-2]');
  EmitRaw('_PRRT_SRCPY:');
  EmitRaw('        MOV   AL, [SI]');
  EmitRaw('        MOV   [BX], AL');
  EmitRaw('        TEST  AL, AL');
  EmitRaw('        JZ    _PRRT_SRD1');
  EmitRaw('        INC   SI');
  EmitRaw('        INC   BX');
  EmitRaw('        JMP   _PRRT_SRCPY');
  EmitRaw('_PRRT_SRD1:');
  EmitRaw('        DEC   CX');
  EmitRaw('        JNZ   _PRRT_SRPL');
  EmitRaw('_PRRT_SRPE:');
  EmitRaw('        POP   AX');
  EmitRaw('        POP   BX');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   DI');
  EmitRaw('        POP   SI');
  EmitRaw('        POP   BP');
  EmitRaw('        RET');
  EmitRaw('_PRRT_STRREPEAT ENDP');
  EmitBlankLine;
  { _PRRT_PUSH - pousser une valeur dans un tableau       }
  { Entree : SI=ptr word count, AX=valeur                            }
  { Disposition : [SI]=count, [SI+2]=elem[0], [SI+4]=elem[1], ...   }
  EmitRaw('_PRRT_PUSH PROC NEAR');
  EmitRaw('        PUSH  BX');
  EmitRaw('        PUSH  CX');
  EmitRaw('        MOV   CX, [SI]');
  EmitRaw('        INC   CX');
  EmitRaw('        MOV   BX, SI');
  EmitRaw('        SHL   CX, 1');
  EmitRaw('        ADD   BX, CX');
  EmitRaw('        MOV   [BX], AX');
  EmitRaw('        INC   WORD PTR [SI]');
  EmitRaw('        POP   CX');
  EmitRaw('        POP   BX');
  EmitRaw('        RET');
  EmitRaw('_PRRT_PUSH ENDP');
  EmitBlankLine;
  { _PRRT_PANIC - afficher msg + terminer code 1           }
  { Entree : SI=ptr chaine d''erreur                                  }
  EmitRaw('_PRRT_PANIC PROC NEAR');
  EmitRaw('        PUSH  DX');
  EmitRaw('        CALL  _PRRT_STRLEN');
  EmitRaw('        MOV   DX, SI');
  EmitRaw('        MOV   BX, 2');
  EmitRaw('        MOV   AH, 40h');
  EmitRaw('        INT   21h');
  EmitRaw('        POP   DX');
  EmitRaw('        MOV   AX, 4C01h');
  EmitRaw('        INT   21h');
  EmitRaw('_PRRT_PANIC ENDP');
  EmitBlankLine;
End;

{ ============================================================
  ParseSubDecl : declare et compile une sous-routine
  Supporte : sub nom BLOC et sub anonyme dans expression
  Convention : push gauche->droite, callee fait PUSH BP/MOV BP,SP
  var_k depuis @_ = WORD PTR [BP + 4 + (N-1-k)*2]
  ============================================================ }
Procedure ParseSubDecl;
Var
  SubName    : TString;
  SubSeq     : TString;
  LblEnd     : TString;
  LblRet     : TString;
  SaveFrame  : Integer;
  SaveDepth  : Integer;
  SaveRetLbl : TString;
  SaveFnName : TString;
  SaveArgSh  : Integer;
  IsAnon     : Boolean;
  Idx        : Integer;
Begin
  { Consommer 'sub' si encore present }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'sub') Then
    ParserAdvance;
  { Verifier si sub anonyme (pas d''identifiant avant le bloc) }
  IsAnon := Not (CurToken.Kind = TK_IDENT);
  If Not IsAnon Then
  Begin
    SubName := CurToken.Val;
    ParserAdvance;  { consommer le nom }
    { Ignorer le prototype eventuel (...) }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
                (CurToken.Kind <> TK_EOF) Do
        ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    { Enregistrer dans la table des symboles }
    Idx := SymAdd(SubName, '&', SC_FN, TY_IDX_CODE, False, True, False);
  End Else
  Begin
    { Sous-routine anonyme : generer un nom unique }
    Inc(LabelSeq);
    Str(LabelSeq, SubSeq);
    SubName := '_ANON_' + SubSeq;
  End;
  { Generer les labels uniques }
  Inc(LabelSeq);
  Str(LabelSeq, SubSeq);
  LblEnd := '_PRL_SUBEND_' + SubSeq;
  LblRet := '_PRL_SUBRET_' + SubSeq;
  { Sauter le corps de la sous-routine a l''execution }
  EmitInstr('JMP', LblEnd);
  EmitLabel(PR_FN_PFX + SubName);
  { Prologue cdecl 16 bits }
  EmitInstr1('PUSH BP');
  EmitInstr('MOV', 'BP, SP');
  { Sauvegarder registres appel (cdecl : SI et DI preserves) }
  EmitInstr1('PUSH SI');
  EmitInstr1('PUSH DI');
  { Sauver le contexte du compilateur }
  SaveFrame  := CurFrameSize;
  SaveDepth  := CurFnDepth;
  SaveRetLbl := CurFnRetLbl;
  SaveFnName := CurFnName;
  SaveArgSh  := CurArgShiftIdx;
  { CurFrameSize demarre a 4 (SI+DI deja pousses, 2 octets chacun) }
  CurFrameSize   := 4;
  CurFnDepth     := CurFnDepth + 1;
  CurFnRetLbl    := LblRet;
  CurFnName      := SubName;
  CurArgShiftIdx := 0;
  SymEnterScope;
  ParseBlock;
  SymLeaveScope;
  { Epilogue : restaurer SP, DI, SI puis BP avant RET }
  EmitLabel(LblRet);
  EmitInstr('MOV', 'SP, BP');   { liberer les locaux }
  EmitInstr('SUB', 'SP, 4');    { pointer sur zone DI puis SI }
  EmitInstr1('POP DI');         { restaurer DI }
  EmitInstr1('POP SI');         { restaurer SI }
  EmitInstr1('POP BP');
  EmitInstr1('RET');
  EmitLabel(LblEnd);
  { Restaurer le contexte }
  CurFrameSize   := SaveFrame;
  CurFnDepth     := SaveDepth;
  CurFnRetLbl    := SaveRetLbl;
  CurFnName      := SaveFnName;
  CurArgShiftIdx := SaveArgSh;
  { Pour sous-routine anonyme : charger l''offset dans AX }
  If IsAnon Then
    EmitInstr('MOV', 'AX, OFFSET ' + PR_FN_PFX + SubName);
End;

{ ============================================================
  PAQUETS ET MODULES (simple)
  ============================================================ }

{ ---- ParseUseStmt : use strict / warnings / constant / mod - }
{ CurToken.Val = 'use' au moment de l''appel.                  }
Procedure ParseUseStmt;
Var
  ModName  : TString;
  CstName  : TString;
  CstLbl   : TString;
  CstInt   : LongInt;
  CstStr   : TString;
  IsStr    : Boolean;
  Idx      : Integer;
Begin
  ParserAdvance;   { consommer 'use' }
  If CurToken.Kind = TK_EOF Then Exit;
  { Obtenir le nom du module (peut etre un TK_IDENT ou TK_KEYWORD) }
  ModName := CurToken.Val;
  { --- use strict --- }
  If ModName = 'strict' Then
  Begin
    Opts.Strict := True;
    EmitComment('use strict: mode strict active');
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) And
              (CurToken.Kind <> TK_EOF) Do
      ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
    Exit;
  End;
  { --- use warnings --- }
  If ModName = 'warnings' Then
  Begin
    Opts.Warnings := True;
    EmitComment('use warnings: mode warnings active');
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) And
              (CurToken.Kind <> TK_EOF) Do
      ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
    Exit;
  End;
  { --- use constant NOM => val --- }
  If ModName = 'constant' Then
  Begin
    ParserAdvance;   { consommer 'constant' }
    CstName := '';
    CstInt  := 0;
    CstStr  := '';
    IsStr   := False;
    { Nom de la constante : TK_IDENT ou TK_KEYWORD }
    If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
    Begin
      CstName := CurToken.Val;
      ParserAdvance;
    End;
    { Consommer '=>' }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=>') Then
      ParserAdvance;
    { Valeur : entier ou chaine (negation optionnelle) }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '-') Then
    Begin
      ParserAdvance;
      If CurToken.Kind = TK_INTEGER Then
      Begin
        CstInt := -CurToken.IntVal;
        ParserAdvance;
      End;
    End Else If CurToken.Kind = TK_INTEGER Then
    Begin
      CstInt := CurToken.IntVal;
      ParserAdvance;
    End Else If CurToken.Kind = TK_STRING Then
    Begin
      CstStr := CurToken.Val;
      IsStr  := True;
      ParserAdvance;
    End;
    { Enregistrer dans SymTab + DataTab si nom valide }
    If CstName <> '' Then
    Begin
      Idx := SymAdd(CstName, '$', SC_CONST, TY_IDX_SCALAR,
                    False, True, False);
      If Idx >= 0 Then
      Begin
        CstLbl := SymTab[Idx].MangledName;
        If DataFindByLabel(CstLbl) < 0 Then
          DataAddConst(CstLbl, CstInt, CstStr);
        If IsStr Then
          EmitComment('use constant ' + CstName + ' => ''' + CstStr + '''')
        Else
        Begin
          Str(CstInt, CstStr);
          EmitComment('use constant ' + CstName + ' => ' + CstStr);
        End;
      End;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
    Exit;
  End;
  { --- Tout autre module : avertissement + skip --- }
  WriteLn('PERL86:', CurToken.Line, ': Avert: module ''', ModName,
          ''' non pris en charge');
  Inc(WarnCount);
  While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) And
            (CurToken.Kind <> TK_EOF) Do
    ParserAdvance;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
End;

{ ============================================================
  ENTREES/SORTIES FICHIERS (simple)
  ParseOpenStmt  : open(my $fh, '<'|'>'|'>>', 'fichier')
  ParseCloseStmt : close($fh)
  ============================================================ }

{ ---- ParseOpenStmt : open(my $fh, mode, 'fichier') ---------- }
{ Mode '<'  -> INT 21h AH=3Dh AL=0 (lecture seule)             }
{ Mode '>'  -> INT 21h AH=3Ch CX=0 (creation / troncature)     }
{ Mode '>>' -> INT 21h AH=3Dh AL=1 + seek fin AH=42h AL=2      }
{ Le handle DOS (AX) est stocke dans WORD PTR [BP-Offset]       }
Procedure ParseOpenStmt;
Var
  FhName  : TString;
  FhIdx   : Integer;
  Mode    : TString;
  FName   : TString;
  FLbl    : TString;
  FhOfs   : TString;
  DIdx    : Integer;
  IsAppnd : Boolean;
  IsWrite : Boolean;
  LblOk   : TString;
Begin
  ParserAdvance;  { consommer 'open' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
  { Lire le filehandle : my $fh ou $fh }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'my') Then
    ParserAdvance;  { consommer 'my' }
  FhName := '';
  If CurToken.Kind = TK_SCALAR Then
  Begin
    FhName := CurToken.Val;
    ParserAdvance;
  End Else
  Begin
    WriteLn('PERL86:', CurToken.Line,
            ': Erreur: ''$fh'' attendu dans open()');
    Inc(ErrorCount);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
    Exit;
  End;
  { Allouer ou trouver le filehandle dans le cadre local }
  FhIdx := SymFindCat(FhName, SC_FILEHANDLE);
  If FhIdx < 0 Then
    FhIdx := SymAdd(FhName, '$', SC_FILEHANDLE, TY_IDX_SCALAR,
                    True, False, False);
  If FhIdx < 0 Then
  Begin
    WriteLn('PERL86:', CurToken.Line,
            ': Erreur: Impossible d''allouer filehandle $', FhName);
    Inc(ErrorCount);
    Exit;
  End;
  EmitAllocLocal(2);  { WORD sur la pile pour stocker le handle DOS }
  Str(SymTab[FhIdx].Offset, FhOfs);
  { Consommer ',' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then ParserAdvance;
  { Lire le mode (toujours une chaine literale) }
  Mode    := '<';
  IsAppnd := False;
  IsWrite := False;
  If CurToken.Kind = TK_STRING Then
  Begin
    Mode := CurToken.Val;
    ParserAdvance;
  End Else If CurToken.Kind = TK_OP Then
  Begin
    Mode := CurToken.Val;
    ParserAdvance;
  End;
  If      Mode = '<'  Then IsWrite := False
  Else If Mode = '>'  Then Begin IsWrite := True; IsAppnd := False; End
  Else If Mode = '>>' Then Begin IsWrite := True; IsAppnd := True;  End
  Else
  Begin
    WriteLn('PERL86:', CurToken.Line,
            ': Avert: mode ''', Mode, ''' non supporte dans open() (pipe/socket)');
    Inc(WarnCount);
  End;
  { Consommer ',' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then ParserAdvance;
  { Lire le nom de fichier }
  FName := '';
  If CurToken.Kind = TK_STRING Then
  Begin
    FName := CurToken.Val;
    ParserAdvance;
  End Else If CurToken.Kind = TK_IDENT Then
  Begin
    FName := CurToken.Val;
    ParserAdvance;
  End;
  { Consommer ')' et ';' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
  { Ajouter le nom de fichier dans le segment de donnees }
  DIdx := DataAddStr(FName);
  FLbl := DataTab[DIdx].LblName;
  { Emettre le commentaire et l''appel DOS }
  EmitComment('open $' + FhName + ', ''' + Mode + ''', ''' + FName + '''');
  LblOk := LabelGen('_PRL_OPOK_');
  EmitInstr('MOV', 'DX, OFFSET ' + FLbl);
  If IsWrite And Not IsAppnd Then
  Begin
    { Creation / troncature : AH=3Ch CX=0 }
    EmitInstr('MOV', 'AH, 3Ch');
    EmitInstr('MOV', 'CX, 0');
    EmitInstr1('INT 21h');
    EmitInstr('JC', LblOk);
    EmitInstr('MOV', 'WORD PTR [BP-' + FhOfs + '], AX');
  End Else If IsAppnd Then
  Begin
    { Append : ouvrir en ecriture seule (AH=3Dh AL=1) }
    EmitInstr('MOV', 'AX, 3D01h');
    EmitInstr1('INT 21h');
    EmitInstr('JC', LblOk);
    EmitInstr('MOV', 'BX, AX');
    { Seek a la fin : AH=42h AL=2 CX=0 DX=0 }
    EmitInstr('MOV', 'AX, 4202h');
    EmitInstr('MOV', 'CX, 0');
    EmitInstr('MOV', 'DX, 0');
    EmitInstr1('INT 21h');
    EmitInstr('MOV', 'WORD PTR [BP-' + FhOfs + '], BX');
  End Else
  Begin
    { Lecture : AH=3Dh AL=0 }
    EmitInstr('MOV', 'AX, 3D00h');
    EmitInstr1('INT 21h');
    EmitInstr('JC', LblOk);
    EmitInstr('MOV', 'WORD PTR [BP-' + FhOfs + '], AX');
  End;
  EmitLabel(LblOk);
End;

{ ---- ParseCloseStmt : close($fh) ----------------------------- }
{ INT 21h AH=3Eh BX=handle DOS                                  }
Procedure ParseCloseStmt;
Var
  FhName : TString;
  FhIdx  : Integer;
  FhOfs  : TString;
Begin
  ParserAdvance;   { consommer 'close' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
  FhName := '';
  If CurToken.Kind = TK_SCALAR Then
  Begin
    FhName := CurToken.Val;
    ParserAdvance;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
  If FhName = '' Then
  Begin
    WriteLn('PERL86:', CurToken.Line,
            ': Erreur: ''$fh'' attendu dans close()');
    Inc(ErrorCount);
    Exit;
  End;
  FhIdx := SymFindCat(FhName, SC_FILEHANDLE);
  If FhIdx < 0 Then
    FhIdx := SymFind(FhName, '$');
  If FhIdx < 0 Then
  Begin
    WriteLn('PERL86:', CurToken.Line,
            ': Avert: filehandle $', FhName, ' inconnu dans close()');
    Inc(WarnCount);
    Exit;
  End;
  Str(SymTab[FhIdx].Offset, FhOfs);
  EmitComment('close $' + FhName);
  EmitInstr('MOV', 'BX, WORD PTR [BP-' + FhOfs + ']');
  EmitInstr('MOV', 'AH, 3Eh');
  EmitInstr1('INT 21h');
End;

Procedure ParseStmt;
{ Analyse une instruction Perl et emet le code ASM correspondant.         }
{ Reconnait : my/our/local ; use ; print/say ; if/unless ; expr [MOD] ;   }
Var
  KW                       : TString;
  E                        : TExprVal;
  LblBody, LblCond, LblEnd : TString;
  HasMod                   : Boolean;
  ModKW                    : TString;
  CondE                    : TExprVal;
Begin
  { Ignorer les points-virgules isoles (instructions vides) }
  While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Do
    ParserAdvance;
  If CurToken.Kind = TK_EOF Then Exit;
  { Mots-cles de declaration et instructions speciales }
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    KW := CurToken.Val;
    If (KW = 'my') Or (KW = 'our') Or (KW = 'local') Then
    Begin
      ParseVarDecl;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
      Exit;
    End;
    { use strict / warnings / constant / module }
    If KW = 'use' Then
    Begin
      ParseUseStmt;
      Exit;
    End;
    { open(my $fh, mode, 'fichier') }
    If KW = 'open' Then Begin
      ParseOpenStmt;
      Exit;
    End;
    { close($fh) }
    If KW = 'close' Then
    Begin
      ParseCloseStmt;
      Exit;
    End;
    { paquet NomModule; -> changer le namespace courant }
    If KW = 'package' Then
    Begin
      ParserAdvance;   { consommer 'package' }
      If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
      Begin
        CurPackage := CurToken.Val;
        EmitComment('package ' + CurPackage);
        ParserAdvance;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
      Exit;
    End;
    { require 'fichier.pl' -> avertissement }
    If KW = 'require' Then
    Begin
      ParserAdvance;   { consommer 'require' }
      If CurToken.Kind = TK_STRING Then
      Begin
        WriteLn('PERL86:', CurToken.Line, ': Avert: require ''',
                CurToken.Val, ''' non pris en charge');
        Inc(WarnCount);
        ParserAdvance;
      End Else If CurToken.Kind = TK_IDENT Then
      Begin
        WriteLn('PERL86:', CurToken.Line, ': Avert: require ',
                CurToken.Val, ' non pris en charge');
        Inc(WarnCount);
        ParserAdvance;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
      Exit;
    End;
    { BEGIN bloc -> emis inline au moment de la compilation }
    If KW = 'BEGIN' Then Begin
      ParserAdvance;   { consommer 'BEGIN' }
      EmitComment('BEGIN: bloc execute au chargement (inline)');
      ParseBlock;
      Exit;
    End;
    { END bloc -> stub, le bloc est ignore }
    If KW = 'END' Then Begin
      ParserAdvance;   { consommer 'END' }
      EmitComment('END: bloc ignore (non execute)');
      { Sauter le bloc sans l''emettre : compter les accolades }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
      Begin
        ParserAdvance;   { consommer '{' }
        While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) And
                  (CurToken.Kind <> TK_EOF) Do
          ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
          ParserAdvance;
      End;
      Exit;
    End;
    { print / say / printf / warn / die }
    If (KW = 'print') Or (KW = 'say') Or (KW = 'printf') Or
       (KW = 'warn') Or (KW = 'die') Then
    Begin
      ParsePrintStmt;
      Exit;
    End;
    { if / unless }
    If (KW = 'if') Or (KW = 'unless') Then Begin
      ParseIfStmt;
      Exit;
    End;
    { while / until / foreach / do }
    If (KW = 'while') Or (KW = 'until') Then Begin
      ParseWhileStmt;
      Exit;
    End;
    If KW = 'foreach' Then
    Begin
      ParseForeachStmt;
      Exit;
    End;
    If KW = 'for' Then
    Begin
      { Avancer au-dela de 'for' pour detecter le style de boucle }
      ParserAdvance;   { CurToken = token apres 'for' }
      GKwConsumed := True;
      { foreach-alias : for my $var (...) ou for $var (...) }
      If ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'my')) Or
          (CurToken.Kind = TK_SCALAR) Then
        ParseForeachStmt
      Else
        ParseForStmt;
      GKwConsumed := False;
      Exit;
    End;
    If KW = 'do' Then
    Begin
      ParseDoStmt;
      Exit;
    End;
    { last / next / redo }
    If KW = 'last' Then
    Begin
      If LoopTop > 0 Then
        EmitInstr('JMP', LoopBreakLbl[LoopTop - 1])
      Else
        EmitComment('last: hors d''une boucle (ignore)');
      { eventuel label de boucle (on ignore) }
      If CurToken.Kind = TK_IDENT Then ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
      Exit;
    End;
    If KW = 'next' Then
    Begin
      If LoopTop > 0 Then
        EmitInstr('JMP', LoopContLbl[LoopTop - 1])
      Else
        EmitComment('next: hors d''une boucle (ignore)');
      If CurToken.Kind = TK_IDENT Then ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
      Exit;
    End;
    If KW = 'redo' Then
    Begin
      If LoopTop > 0 Then
        EmitInstr('JMP', LoopRedoLbl[LoopTop - 1])
      Else
        EmitComment('redo: hors d''une boucle (ignore)');
      If CurToken.Kind = TK_IDENT Then ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
      Exit;
    End;
    { push / pop / shift / unshift / scalar sur @arr }
    If (KW = 'push') Or (KW = 'pop') Or
       (KW = 'shift') Or (KW = 'unshift') Then
    Begin
      ParseArrBuiltin(True);
      Exit;
    End;
    { sub declaration }
    If KW = 'sub' Then
    Begin
      ParseSubDecl;
      Exit;
    End;
    { return [expr] }
    If KW = 'return' Then
    Begin
      ParserAdvance;  { consommer 'return' }
      If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) And
         (CurToken.Kind <> TK_EOF) Then
      Begin
        ParseExpr(E);
        ExprLoad(E);
      End Else
        EmitInstr('XOR', 'AX, AX');  { return; sans valeur -> 0 }
      If CurFnDepth > 0 Then
        EmitInstr('JMP', CurFnRetLbl)  { retour sous-routine }
      Else
      Begin
        { return au niveau global -> sortie programme }
        EmitInstr('MOV', 'BX, AX');
        EmitInstr('MOV', 'AH, 4Ch');
        EmitInstr1('INT 21h');
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
      Exit;
    End;
  End;
  { ----------------------------------------------------------- }
  { Instruction expression avec modificateur potentiel          }
  { Structure :                                                  }
  {   JMP Lcond                                                  }
  {   Lbody:  [corps - expression Perl]                         }
  {           JMP Lend                                          }
  {   Lcond:  [condition] JNZ/JZ Lbody  ou  JMP Lbody          }
  {   Lend:                                                      }
  { ----------------------------------------------------------- }
  LblBody := LabelGen('_PRL_SMBOD_');
  LblCond := LabelGen('_PRL_SMCND_');
  LblEnd  := LabelGen('_PRL_SMEND_');
  EmitInstr('JMP', LblCond);
  EmitLabel(LblBody);
  ParseExpr(E);
  EmitInstr('JMP', LblEnd);
  EmitLabel(LblCond);
  { Detecter modificateur if / unless / while / until }
  HasMod := False;
  ModKW  := '';
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    ModKW := CurToken.Val;
    If (ModKW = 'if') Or (ModKW = 'unless') Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      ParseExpr(CondE);
      ExprLoad(CondE);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      EmitInstr('TEST', 'AX, AX');
      If ModKW = 'if' Then
        EmitInstr('JNZ', LblBody)   { if: executer si VRAI }
      Else
        EmitInstr('JZ', LblBody);   { unless: executer si FAUX }
      HasMod := True;
    End Else If (ModKW = 'while') Or (ModKW = 'until') Then
    Begin
      { Structure deja en place : LblCond est le bon point d'entree }
      { On emet la condition ici et on reboucle vers LblBody }
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      ParseExpr(CondE);
      ExprLoad(CondE);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      EmitInstr('TEST', 'AX, AX');
      If ModKW = 'while' Then
        EmitInstr('JNZ', LblBody)   { while: executer tant que VRAI }
      Else
        EmitInstr('JZ', LblBody);   { until: executer tant que FAUX }
      HasMod := True;
    End;
  End;
  If Not HasMod Then
    EmitInstr('JMP', LblBody);  { pas de modificateur : toujours executer }
  EmitLabel(LblEnd);
  { Consommer '';'' ou tolerer EOF }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance
  Else If CurToken.Kind <> TK_EOF Then
  Begin
    WriteLn('PERL86:', CurToken.Line, ': Erreur: '';'' attendu, obtenu ''',
            CurToken.Val, '''');
    Inc(ErrorCount);
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) And
              (CurToken.Kind <> TK_EOF) Do
      ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
  End;
End;

{ ============================================================
  LEXEUR PERL
  ============================================================ }

{ ---- Primitives de bas niveau ----------------------------- }
Function LexCurChar : Char;
Begin
  If (LexEOF) Or (LexColNo > Length(LexLine)) Then
    LexCurChar := #0
  Else
    LexCurChar := LexLine[LexColNo];
End;

Function LexPeek : Char;
Begin
  If (LexEOF) Or (LexColNo + 1 > Length(LexLine)) Then
    LexPeek := #0
  Else
    LexPeek := LexLine[LexColNo + 1];
End;

Function LexPeek2 : Char;
Begin
  If (LexEOF) Or (LexColNo + 2 > Length(LexLine)) Then
    LexPeek2 := #0
  Else
    LexPeek2 := LexLine[LexColNo + 2];
End;

Procedure LexAdvance;
Begin
  Inc(LexColNo);
End;

Procedure LexNextLine;
Begin
  If EOF(LexSrcF) Then
  Begin
    LexEOF   := True;
    LexLine  := '';
    LexColNo := 1;
  End Else
  Begin
    ReadLn(LexSrcF, LexLine);
    Inc(LexLineNo);
    Inc(TotalLines);
    LexColNo := 1;
  End;
End;

{ ---- Erreur lexicale (non fatale) ------------------------- }
Procedure LexError(Const Msg : TString);
Begin
  WriteLn('PERL86:', LexLineNo, ':', LexColNo, ': Erreur: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('Trop d''erreurs - compilation abandonnee');
End;

{ ---- Constructeur de token -------------------------------- }
Procedure MakeToken(Var T : TToken; K : TTokenKind;
                    Const V : TString; L, C : Integer);
Begin
  T.Kind     := K;
  T.Val      := V;
  T.IntVal   := 0;
  T.FloatVal := 0.0;
  T.Line     := L;
  T.Col      := C;
End;

{ ---- Commentaires Perl : # jusqu''a la fin de ligne ------- }
{ (Perl n''a pas de /* */ contrairement a PHP)                }
Procedure LexSkipLineComment;
Begin
  LexColNo := Length(LexLine) + 1;
End;

{ ---- Passer les espaces et les commentaires --------------- }
Procedure LexSkipWS;
Var
  C : Char;
Begin
  Repeat
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;
    If LexEOF Then Exit;
    C := LexCurChar;
    If (C = ' ') Or (C = #9) Or (C = #13) Or (C = #10) Then
      LexAdvance
    Else If C = '#' Then
      LexSkipLineComment   { seul type de commentaire en Perl }
    Else
      Exit;
  Until False;
End;

{ ---- Utilitaires caracteres ------------------------------- }
Function IsAlpha(C : Char) : Boolean;
Begin
  IsAlpha := ((C >= 'a') And (C <= 'z')) Or
             ((C >= 'A') And (C <= 'Z')) Or (C = '_');
End;

Function IsDigit(C : Char) : Boolean;
Begin
  IsDigit := (C >= '0') And (C <= '9');
End;

Function IsAlNum(C : Char) : Boolean;
Begin
  IsAlNum := IsAlpha(C) Or IsDigit(C);
End;

Function IsHexDigit(C : Char) : Boolean;
Begin
  IsHexDigit := IsDigit(C) Or
                ((C >= 'a') And (C <= 'f')) Or
                ((C >= 'A') And (C <= 'F'));
End;

Function HexVal(C : Char) : Integer;
Begin
  If   (C >= '0') And (C <= '9') Then HexVal := Ord(C) - Ord('0')
  Else If (C >= 'a') And (C <= 'f') Then HexVal := Ord(C) - Ord('a') + 10
  Else HexVal := Ord(C) - Ord('A') + 10;
End;

{ ---- Table des mots-cles Perl ----------------------------- }
Const
  PERL_KW_COUNT = 73;
  PERL_KW : Array[0..72] Of String[14] = (
    { Declaration de portee }
    'my',           'our',          'local',
    { Sous-routines }
    'sub',          'return',       'wantarray',
    { Packages et modules }
    'use',          'require',      'package',
    'BEGIN',        'END',
    { Conditionnels }
    'if',           'elsif',        'else',
    'unless',
    { Boucles }
    'while',        'until',        'for',
    'foreach',      'do',
    'last',         'next',         'redo',
    { E/S et print }
    'print',        'say',          'printf',
    'sprintf',      'warn',         'die',
    'exit',
    { Tableaux }
    'push',         'pop',          'shift',
    'unshift',      'splice',       'reverse',
    'sort',         'join',         'split',
    'grep',         'map',
    { Hashes }
    'keys',         'values',       'each',
    'exists',       'delete',
    { Scalaires et types }
    'defined',      'undef',        'ref',
    'chomp',        'chop',         'length',
    'substr',       'index',        'int',
    'abs',          'hex',          'oct',
    'chr',          'ord',          'lc',
    'uc',           'ucfirst',      'lcfirst',
    'rindex',
    { Logiques basse precedence }
    'not',          'and',          'or',
    { Operateur de repetition }
    'x',
    { E/S fichiers }
    'open',         'close',        'readline',
    'eof'
  );

Function IsPerlKeyword(Const S : TString) : Boolean;
Var
  I : Integer;
Begin
  IsPerlKeyword := False;
  For I := 0 To PERL_KW_COUNT - 1 Do
    If S = PERL_KW[I] Then
    Begin IsPerlKeyword := True; Exit; End;
End;

{ ---- LexScanIdent : identificateur, mot-cle ou bareword --- }
{ Les barewords STDOUT STDERR STDIN deviennent TK_FILEHANDLE  }
Procedure LexScanIdent(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
Begin
  S := '';
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
        IsAlNum(LexCurChar) Do
  Begin
    If Length(S) < MAX_STR Then S := S + LexCurChar;
    LexAdvance;
  End;
  { Filehandles connus }
  If (S = 'STDOUT') Or (S = 'STDERR') Or (S = 'STDIN') Then
    MakeToken(T, TK_FILEHANDLE, S, SL, SC)
  Else If IsPerlKeyword(S) Then
    MakeToken(T, TK_KEYWORD, S, SL, SC)
  Else
    MakeToken(T, TK_IDENT, S, SL, SC);
End;

{ ---- LexScanNumber : entier ou flottant ------------------- }
{ Perl : 0x hex, 0b binaire, 0 octal, 1_000 separateurs       }
Procedure LexScanNumber(Var T : TToken; SL, SC : Integer);
Var
  S     : TString;
  Val   : LongInt;
  Base  : Integer;
  C     : Char;
  Fv    : Real;
  Div10 : Real;
Begin
  S    := '';
  Val  := 0;
  Base := 10;
  C    := LexCurChar;
  If (C = '0') And (LexPeek <> #0) Then
  Begin
    Case LexPeek Of
      'x','X': Begin S := '0x'; LexAdvance; LexAdvance; Base := 16; End;
      'b','B': Begin S := '0b'; LexAdvance; LexAdvance; Base := 2;  End;
    Else
      { octal classique en Perl : 0NNN }
      If IsDigit(LexPeek) Then
      Begin
        S := '0'; Val := 0;
        LexAdvance;
        Base := 8;
      End Else
      Begin
        S := '0'; Val := 0; LexAdvance;
      End;
    End;
  End Else
  Begin
    Val := Ord(C) - Ord('0');
    S   := C;
    LexAdvance;
  End;
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) Do
  Begin
    C := LexCurChar;
    If C = '_' Then Begin LexAdvance; Continue; End;  { separateur numerique }
    Case Base Of
      2  : If (C = '0') Or (C = '1') Then
           Begin Val:=Val*2+(Ord(C)-Ord('0')); If Length(S)<MAX_STR Then S:=S+C; LexAdvance; End
           Else Break;
      8  : If (C >= '0') And (C <= '7') Then
           Begin Val:=Val*8+(Ord(C)-Ord('0')); If Length(S)<MAX_STR Then S:=S+C; LexAdvance; End
           Else Break;
      10 : If IsDigit(C) Then
           Begin Val:=Val*10+(Ord(C)-Ord('0')); If Length(S)<MAX_STR Then S:=S+C; LexAdvance; End
           Else Break;
      16 : If IsHexDigit(C) Then
           Begin Val:=Val*16+HexVal(C); If Length(S)<MAX_STR Then S:=S+C; LexAdvance; End
           Else Break;
    End;
  End;
  { Detection flottant (base 10 uniquement) }
  If (Base = 10) And (Not LexEOF) And (LexColNo <= Length(LexLine)) And
     (LexCurChar = '.') And IsDigit(LexPeek) Then
  Begin
    Fv    := Val * 1.0;
    Div10 := 10.0;
    If Length(S) < MAX_STR Then S := S + '.';
    LexAdvance;
    While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
          (IsDigit(LexCurChar) Or (LexCurChar = '_')) Do
    Begin
      If LexCurChar <> '_' Then
      Begin
        Fv    := Fv + (Ord(LexCurChar) - Ord('0')) / Div10;
        Div10 := Div10 * 10.0;
        If Length(S) < MAX_STR Then S := S + LexCurChar;
      End;
      LexAdvance;
    End;
    { Exposant e/E }
    If (Not LexEOF) And (LexColNo <= Length(LexLine)) And
       ((LexCurChar = 'e') Or (LexCurChar = 'E')) Then
    Begin
      If Length(S) < MAX_STR Then S := S + LexCurChar;
      LexAdvance;
      If (LexColNo <= Length(LexLine)) And
         ((LexCurChar = '+') Or (LexCurChar = '-')) Then
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
      While (Not LexEOF) And (LexColNo <= Length(LexLine)) And IsDigit(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
    End;
    MakeToken(T, TK_FLOAT, S, SL, SC);
    T.FloatVal := Fv;
    Exit;
  End;
  MakeToken(T, TK_INTEGER, S, SL, SC);
  T.IntVal := Val;
End;

{ ---- LexScanEscape : sequence d''echappement (double-quote) }
{ Perl : \n \t \r \f \e \0 \\ \' \" \$ \@ \xNN \NNN (octal)  }
Function LexScanEscape(Var IntOut : LongInt) : Char;
Var
  C    : Char;
  Code : LongInt;
  I    : Integer;
Begin
  IntOut := 0;
  Code   := 0;
  If LexColNo > Length(LexLine) Then
  Begin
    LexError('Sequence d''echappement incomplete');
    LexScanEscape := '?';
    Exit;
  End;
  C := LexCurChar;
  LexAdvance;
  Case C Of
    'n' : Begin LexScanEscape := #10; IntOut := 10;  End;
    't' : Begin LexScanEscape := #9;  IntOut := 9;   End;
    'r' : Begin LexScanEscape := #13; IntOut := 13;  End;
    'f' : Begin LexScanEscape := #12; IntOut := 12;  End;
    'e' : Begin LexScanEscape := #27; IntOut := 27;  End;  { ESC }
    '0' : Begin LexScanEscape := #0;  IntOut := 0;   End;
    '"' : Begin LexScanEscape := '"'; IntOut := 34;  End;
    '''': Begin LexScanEscape := ''''; IntOut := 39; End;
    '\' : Begin LexScanEscape := '\'; IntOut := 92;  End;
    '$' : Begin LexScanEscape := '$'; IntOut := 36;  End;
    '@' : Begin LexScanEscape := '@'; IntOut := 64;  End;
    'x' : Begin
            Code := 0;
            For I := 1 To 2 Do
            Begin
              If (LexColNo > Length(LexLine)) Or (Not IsHexDigit(LexCurChar)) Then
              Begin LexError('\x: 2 chiffres hexa attendus'); Break; End;
              Code := Code * 16 + HexVal(LexCurChar);
              LexAdvance;
            End;
            IntOut := Code;
            LexScanEscape := Chr(Code And $FF);
          End;
  Else
    LexScanEscape := C;
    IntOut := Ord(C);
  End;
End;

{ ---- LexScanStrSingle : simple-quote (pas d''interpolation) }
Procedure LexScanStrSingle(Var T : TToken; SL, SC : Integer);
Var
  S    : TString;
  C    : Char;
  Done : Boolean;
Begin
  LexAdvance; { consommer le guillemet-simple ouverture }
  S    := '';
  Done := False;
  Repeat
    If LexColNo > Length(LexLine) Then
    Begin
      { Continuer sur la ligne suivante (chaine multi-ligne) }
      If LexEOF Then
      Begin
        LexError('Chaine simple-quote non fermee (EOF)');
        Done := True;
      End Else
      Begin
        If Length(S) < MAX_STR Then S := S + #10;
        LexNextLine;
      End;
    End Else
    Begin
      C := LexCurChar;
      If Ord(C) = 39 Then                { '  : fermeture }
      Begin
        LexAdvance; Done := True;
      End Else If Ord(C) = 92 Then       { \  : echappement limite }
      Begin
        LexAdvance;
        If (LexColNo <= Length(LexLine)) And
           ((LexCurChar = #39) Or (LexCurChar = #92)) Then
        Begin
          If Length(S) < MAX_STR Then S := S + LexCurChar;
          LexAdvance;
        End Else
          If Length(S) < MAX_STR Then S := S + '\';
      End Else
      Begin
        If Length(S) < MAX_STR Then S := S + C;
        LexAdvance;
      End;
    End;
  Until Done;
  MakeToken(T, TK_STRING, S, SL, SC);
End;

{ ---- LexScanStrDouble : double-quote avec interpolation ---- }
{ Les interpolations $var et @arr sont encodees dans Val :     }
{   $nom  -> #1 + nom + #2                                     }
{   @nom  -> #3 + nom + #4                                     }
Procedure LexScanStrDouble(Var T : TToken; SL, SC : Integer);
Var
  S    : TString;
  C    : Char;
  IV   : LongInt;
  VN   : TString;
  Done : Boolean;
Begin
  LexAdvance; { consommer le guillemet-double ouverture }
  S    := '';
  Done := False;
  Repeat
    If LexColNo > Length(LexLine) Then
    Begin
      If LexEOF Then
      Begin
        LexError('Chaine double-quote non fermee (EOF)');
        Done := True;
      End Else
      Begin
        If Length(S) < MAX_STR Then S := S + #10;
        LexNextLine;
      End;
    End Else
    Begin
      C := LexCurChar;
      If Ord(C) = 34 Then                { "  : fermeture }
      Begin
        LexAdvance; Done := True;
      End Else If Ord(C) = 92 Then       { \  : echappement }
      Begin
        LexAdvance;
        C := LexScanEscape(IV);
        If Length(S) < MAX_STR Then S := S + C;
      End Else If C = '$' Then           { $var : interpolation scalaire }
      Begin
        LexAdvance;
        VN := '';
        While (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
        Begin
          If Length(VN) < 30 Then VN := VN + LexCurChar;
          LexAdvance;
        End;
        If VN <> '' Then
        Begin
          If Length(S) < MAX_STR Then S := S + #1;  { marqueur debut $var }
          If Length(S) + Length(VN) <= MAX_STR Then S := S + VN;
          If Length(S) < MAX_STR Then S := S + #2;  { marqueur fin $var   }
        End Else
          If Length(S) < MAX_STR Then S := S + '$';
      End Else If C = '@' Then           { @arr : interpolation tableau }
      Begin
        LexAdvance;
        VN := '';
        While (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
        Begin
          If Length(VN) < 30 Then VN := VN + LexCurChar;
          LexAdvance;
        End;
        If VN <> '' Then
        Begin
          If Length(S) < MAX_STR Then S := S + #3;  { marqueur debut @arr }
          If Length(S) + Length(VN) <= MAX_STR Then S := S + VN;
          If Length(S) < MAX_STR Then S := S + #4;  { marqueur fin @arr   }
        End Else
          If Length(S) < MAX_STR Then S := S + '@';
      End Else
      Begin
        If Length(S) < MAX_STR Then S := S + C;
        LexAdvance;
      End;
    End;
  Until Done;
  MakeToken(T, TK_STRING, S, SL, SC);
End;

{ ---- LexScanStrBacktick : backtick ` (commande systeme) ---  }
{ Non supporte sur DOS 8086 : on consomme et on emet warning   }
Procedure LexScanStrBacktick(Var T : TToken; SL, SC : Integer);
Var
  C : Char;
Begin
  LexAdvance; { consommer le backtick ouverture }
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      If LexEOF Then Break;
      LexNextLine;
    End Else
    Begin
      C := LexCurChar;
      LexAdvance;
      If C = '`' Then Break;
    End;
  End;
  WriteLn('PERL86:', SL, ':', SC,
          ': Avertissement: backtick (commande systeme) non supporte - chaine vide');
  Inc(WarnCount);
  MakeToken(T, TK_STRING, '', SL, SC);
End;

{ ---- LexScanHeredoc : << LABEL, <<"LABEL", <<''LABEL''     }
{ Fin : ligne contenant exactement le label (sans espaces)    }
Procedure LexScanHeredoc(Var T : TToken; SL, SC : Integer);
Var
  Lbl      : TString;
  IsNowdoc : Boolean;
  S        : TString;
  LLen     : Integer;
Begin
  { Consommer '<< ' (deux caracteres, le curseur est sur le 2e '<') }
  LexAdvance; LexAdvance;  { passer << (le 1er '<' a deja ete vu dans LexNextToken) }
  IsNowdoc := False;
  Lbl      := '';
  { Ignorer les espaces apres << }
  While (LexColNo <= Length(LexLine)) And (LexCurChar = ' ') Do LexAdvance;
  If (LexColNo <= Length(LexLine)) Then
  Begin
    Case LexCurChar Of
      '''': { Nowdoc <<'LABEL' : pas d''interpolation }
        Begin
          IsNowdoc := True;
          LexAdvance;
          While (LexColNo <= Length(LexLine)) And (Ord(LexCurChar) <> 39) Do
          Begin
            If Length(Lbl) < 30 Then Lbl := Lbl + LexCurChar;
            LexAdvance;
          End;
          If LexColNo <= Length(LexLine) Then LexAdvance; { fermer ' }
        End;
      '"': { Heredoc <<"LABEL" : avec interpolation (meme comportement que sans quote) }
        Begin
          LexAdvance;
          While (LexColNo <= Length(LexLine)) And (Ord(LexCurChar) <> 34) Do
          Begin
            If Length(Lbl) < 30 Then Lbl := Lbl + LexCurChar;
            LexAdvance;
          End;
          If LexColNo <= Length(LexLine) Then LexAdvance; { fermer " }
        End;
    Else
      { Heredoc <<LABEL }
      While (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
      Begin
        If Length(Lbl) < 30 Then Lbl := Lbl + LexCurChar;
        LexAdvance;
      End;
    End;
  End;
  If Lbl = '' Then
  Begin
    LexError('Heredoc: label manquant apres <<');
    MakeToken(T, TK_STRING, '', SL, SC);
    Exit;
  End;
  { Passer a la premiere ligne de contenu }
  LexNextLine;
  S    := '';
  LLen := Length(Lbl);
  While Not LexEOF Do
  Begin
    { Le label de fermeture doit etre seul sur sa ligne }
    If (Length(LexLine) = LLen) And (Copy(LexLine, 1, LLen) = Lbl) Then
    Begin
      LexColNo := LLen + 1;  { positionner apres le label }
      MakeToken(T, TK_HEREDOC, S, SL, SC);
      Exit;
    End;
    If (Length(LexLine) > LLen) And
       (Copy(LexLine, 1, LLen) = Lbl) And
       (LexLine[LLen + 1] = ';') Then
    Begin
      LexColNo := LLen + 1;  { laisser ';' pour le parseur }
      MakeToken(T, TK_HEREDOC, S, SL, SC);
      Exit;
    End;
    { Accumuler la ligne }
    If Length(S) + Length(LexLine) < MAX_STR Then
      S := S + LexLine;
    If Length(S) < MAX_STR Then S := S + #10;
    LexNextLine;
  End;
  LexError('Heredoc: label de fermeture "' + Lbl + '" introuvable (EOF)');
  MakeToken(T, TK_HEREDOC, S, SL, SC);
End;

{ ---- LexScanOp : operateurs Perl (simples et composes) ---- }
{ Specificites Perl vs PHP :                                   }
{   x=   repetition-assigne                                    }
{   ..   plage (range)                                         }
{   ...  plage exclusive                                       }
{   //   defined-or (PAS un commentaire en Perl !)             }
{   //=  defined-or-assign                                     }
{   ->   dereferencement fleche                                }
{   =>   grosse-virgule (fat comma)                            }
{   <=>  spaceship numerique                                   }
{   ~~   smartmatch (tokenise mais non supporte)               }
Procedure LexScanOp(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
  C : Char;
  P : Char;
  P2: Char;
Begin
  C  := LexCurChar;
  P  := LexPeek;
  P2 := LexPeek2;
  S  := C;
  LexAdvance;
  Case C Of
    '+': If P = '+' Then Begin S := '++'; LexAdvance; End
         Else If P = '=' Then Begin S := '+='; LexAdvance; End;
    '-': If P = '-' Then Begin S := '--'; LexAdvance; End
         Else If P = '>' Then Begin S := '->'; LexAdvance; End
         Else If P = '=' Then Begin S := '-='; LexAdvance; End;
    '*': If P = '*' Then
         Begin
           S := '**'; LexAdvance;
           If LexCurChar = '=' Then Begin S := '**='; LexAdvance; End;
         End
         Else If P = '=' Then Begin S := '*='; LexAdvance; End;
    '/': If P = '/' Then
         Begin
           S := '//'; LexAdvance;          { defined-or, PAS commentaire }
           If LexCurChar = '=' Then Begin S := '//='; LexAdvance; End;
         End
         Else If P = '=' Then Begin S := '/='; LexAdvance; End;
    '%': If P = '=' Then Begin S := '%='; LexAdvance; End;
    '.': If P = '.' Then
         Begin
           S := '..'; LexAdvance;
           If LexCurChar = '.' Then Begin S := '...'; LexAdvance; End;
         End
         Else If P = '=' Then Begin S := '.='; LexAdvance; End;
    '!': If P = '=' Then Begin S := '!='; LexAdvance; End
         Else If P = '~' Then Begin S := '!~'; LexAdvance; End;  { not-match }
    '=': If P = '=' Then
         Begin
           S := '=='; LexAdvance;
           If LexCurChar = '=' Then Begin S := '==='; LexAdvance; End;  { non-Perl, securite }
         End
         Else If P = '>' Then Begin S := '=>'; LexAdvance; End  { fat comma }
         Else If P = '~' Then Begin S := '=~'; LexAdvance; End; { match }
    '<': If P = '=' Then
         Begin
           S := '<='; LexAdvance;
           If LexCurChar = '>' Then Begin S := '<=>'; LexAdvance; End; { spaceship }
         End
         Else If P = '<' Then
         Begin
           S := '<<'; LexAdvance;
           If LexCurChar = '=' Then Begin S := '<<='; LexAdvance; End;
         End;
    '>': If P = '=' Then Begin S := '>='; LexAdvance; End
         Else If P = '>' Then
         Begin
           S := '>>'; LexAdvance;
           If LexCurChar = '=' Then Begin S := '>>='; LexAdvance; End;
         End;
    '&': If P = '&' Then Begin S := '&&'; LexAdvance; End
         Else If P = '=' Then Begin S := '&='; LexAdvance; End;
    '|': If P = '|' Then
         Begin
           S := '||'; LexAdvance;
           If LexCurChar = '=' Then Begin S := '||='; LexAdvance; End;
         End
         Else If P = '=' Then Begin S := '|='; LexAdvance; End;
    '^': If P = '=' Then Begin S := '^='; LexAdvance; End;
    ':': If P = ':' Then Begin S := '::'; LexAdvance; End;  { separateur package }
    '~': If P = '~' Then Begin S := '~~'; LexAdvance; End;  { smartmatch (tokenise) }
    '?': ; { ternaire simple }
  End;
  MakeToken(T, TK_OP, S, SL, SC);
End;

{ ---- LexScanPunct : ponctuation simple -------------------- }
Procedure LexScanPunct(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
Begin
  S := LexCurChar;
  LexAdvance;
  MakeToken(T, TK_PUNCT, S, SL, SC);
End;

{ ---- LexScanRegexLit : scanner un literal regex apres =~ ou !~ }
{ Formes supportees :                                              }
{   /pat/flags   m/pat/flags   s/pat/repl/flags   tr/s1/s2/flags  }
{ Encode dans T.Val : kind + Chr(1) + pat + Chr(1) + repl         }
{   kind = 'm' (match), 's' (substitution), 't' (transliteration) }
Procedure LexScanRegexLit(Var T : TToken; SL, SC : Integer);
Var
  C    : Char;
  Kind : Char;
  Pat  : TString;
  Repl : TString;
Begin
  C    := LexCurChar;
  Kind := 'm';
  Pat  := '';
  Repl := '';
  { Determiner le type et avancer jusqu'au premier '/' }
  If C = 's' Then
  Begin
    Kind := 's';
    LexAdvance;  { skip 's' }
    { skip '/' delimiter }
    If (Not LexEOF) And (LexColNo <= Length(LexLine)) Then LexAdvance;
  End
  Else If (C = 't') And (LexPeek = 'r') Then
  Begin
    Kind := 't';
    LexAdvance;  { skip 't' }
    LexAdvance;  { skip 'r' }
    { skip '/' delimiter }
    If (Not LexEOF) And (LexColNo <= Length(LexLine)) Then LexAdvance;
  End
  Else If C = 'm' Then
  Begin
    LexAdvance;  { skip 'm' }
    { skip '/' delimiter }
    If (Not LexEOF) And (LexColNo <= Length(LexLine)) Then LexAdvance;
  End
  Else
  Begin
    { C = '/' : delimiter direct }
    LexAdvance;  { skip '/' }
  End;
  { Scanner le pattern jusqu'au prochain '/' }
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
        (LexCurChar <> '/') Do
  Begin
    If LexCurChar = '\' Then
    Begin
      { Sequence d'echappement : conserver les deux caracteres }
      If Length(Pat) < MAX_STR - 1 Then Pat := Pat + '\';
      LexAdvance;
      If (Not LexEOF) And (LexColNo <= Length(LexLine)) Then
      Begin
        If Length(Pat) < MAX_STR Then Pat := Pat + LexCurChar;
        LexAdvance;
      End;
    End
    Else
    Begin
      If Length(Pat) < MAX_STR Then Pat := Pat + LexCurChar;
      LexAdvance;
    End;
  End;
  { Consommer le '/' de fermeture du pattern }
  If (Not LexEOF) And (LexColNo <= Length(LexLine)) Then LexAdvance;
  { Pour s/// et tr/// : scanner la chaine de remplacement }
  If (Kind = 's') Or (Kind = 't') Then
  Begin
    While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
          (LexCurChar <> '/') Do
    Begin
      If Length(Repl) < MAX_STR Then Repl := Repl + LexCurChar;
      LexAdvance;
    End;
    { Consommer le '/' final }
    If (Not LexEOF) And (LexColNo <= Length(LexLine)) Then LexAdvance;
  End;
  { Sauter les flags eventuels : g i m s x (on les ignore dans cette version) }
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
        IsAlpha(LexCurChar) Do
    LexAdvance;
  { Encoder dans Val : kind + Chr(1) + pat + Chr(1) + repl }
  MakeToken(T, TK_REGEXP, Kind + Chr(1) + Pat + Chr(1) + Repl, SL, SC);
End;

{ ---- LexNextToken : produire le prochain token Perl ------- }
Procedure LexNextToken(Var T : TToken);
Var
  SL, SC : Integer;
  C      : Char;
  S      : TString;
Begin
  LexSkipWS;
  If LexEOF Or (LexColNo > Length(LexLine)) Then
  Begin
    MakeToken(T, TK_EOF, '', LexLineNo, LexColNo);
    Exit;
  End;
  SL := LexLineNo;
  SC := LexColNo;
  C  := LexCurChar;

  { Literal regex attendu apres =~ ou !~ }
  If LexExpectRegex Then
  Begin
    LexExpectRegex := False;
    If (C = '/') Or
       ((C = 'm') And (LexPeek = '/')) Or
       ((C = 's') And (LexPeek = '/')) Or
       ((C = 't') And (LexPeek = 'r')) Then
    Begin
      LexScanRegexLit(T, SL, SC);
      Exit;
    End;
    { Pas une regex reconnue : continuer le scan normal }
  End;

  { Sigil $ : variable scalaire $nom }
  If C = '$' Then
  Begin
    LexAdvance;
    S := '';
    If (Not LexEOF) And (LexColNo <= Length(LexLine)) And IsAlpha(LexCurChar) Then
    Begin
      While (Not LexEOF) And (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
    End Else If (LexColNo <= Length(LexLine)) And (LexCurChar = '{') Then
    Begin
      (* Forme avec accolades : $-nom- *)
      LexAdvance;
      While (LexColNo <= Length(LexLine)) And (LexCurChar <> '}') Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
      If LexColNo <= Length(LexLine) Then LexAdvance; (* fermer l'accolade de ${nom} *)
    End;
    MakeToken(T, TK_SCALAR, S, SL, SC);
    Exit;
  End;

  { Sigil @ : variable tableau @nom }
  If C = '@' Then
  Begin
    LexAdvance;
    S := '';
    If (Not LexEOF) And (LexColNo <= Length(LexLine)) And IsAlpha(LexCurChar) Then
    Begin
      While (Not LexEOF) And (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
    End;
    MakeToken(T, TK_ARRAY_SIG, S, SL, SC);
    Exit;
  End;

  { Sigil % : variable hash %nom }
  If C = '%' Then
  Begin
    { Attention : '%=' est un operateur, '%' seul suivi d''ident = hash }
    If IsAlpha(LexPeek) Then
    Begin
      LexAdvance;
      S := '';
      While (Not LexEOF) And (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
      MakeToken(T, TK_HASH_SIG, S, SL, SC);
      Exit;
    End;
    { Sinon : operateur % ou %= }
    LexScanOp(T, SL, SC);
    Exit;
  End;

  { Identifiant ou mot-cle }
  If IsAlpha(C) Then Begin LexScanIdent(T, SL, SC); Exit; End;

  { Litteraux numeriques }
  If IsDigit(C) Then Begin LexScanNumber(T, SL, SC); Exit; End;

  { Chaine simple-quote }
  If Ord(C) = 39 Then Begin LexScanStrSingle(T, SL, SC); Exit; End;

  { Chaine double-quote }
  If Ord(C) = 34 Then Begin LexScanStrDouble(T, SL, SC); Exit; End;

  { Backtick : commande systeme (non supporte) }
  If C = '`' Then Begin LexScanStrBacktick(T, SL, SC); Exit; End;

  { Diamond <$fh> : readline depuis un filehandle scalaire }
  { Detecter avant le heredoc << et l''operateur < de LexScanOp      }
  If (C = '<') And (LexPeek = '$') Then
  Begin
    LexAdvance;  { sauter '<' }
    LexAdvance;  { sauter '$' : on pointe sur le 1er char du nom }
    S := '';
    While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
          (LexCurChar <> '>') And IsAlNum(LexCurChar) Do
    Begin
      If Length(S) < MAX_STR Then S := S + LexCurChar;
      LexAdvance;
    End;
    If (Not LexEOF) And (LexColNo <= Length(LexLine)) And
       (LexCurChar = '>') Then
      LexAdvance;  { sauter '>' }
    MakeToken(T, TK_FILEHANDLE, S, SL, SC);
    Exit;
  End;

  { Heredoc : << (detecter avant LexScanOp qui consomme '<') }
  { Condition : suivant est '<' et caractere suivant n''est PAS '<' }
  { (C = '<' et LexPeek = '<' et LexPeek2 != '<')                  }
  If (C = '<') And (LexPeek = '<') And (LexPeek2 <> '<') Then
  Begin
    { Verifier que ce n''est pas un operateur binaire :            }
    { heuristique : si la chaine apres << commence par un ident,   }
    { une quote ou un espace -> heredoc                            }
    If IsAlpha(LexPeek2) Or (LexPeek2 = '''') Or
       (LexPeek2 = '"')  Or (LexPeek2 = ' ')  Then
    Begin
      LexAdvance;  { consommer le 1er '<' }
      LexScanHeredoc(T, SL, SC);
      Exit;
    End;
  End;

  { Operateurs Perl }
  Case C Of
    '+','-','*','/','.',
    '!','=','<','>','&','|','^','~','?',':','\':
      Begin LexScanOp(T, SL, SC); Exit; End;
  End;

  { Ponctuation }
  LexScanPunct(T, SL, SC);
End;

{ ---- LexInit : ouvrir le fichier source et initialiser ---- }
{ Gestion du shebang : si la 1ere ligne commence par #!,      }
{ elle est ignoree silencieusement.                           }
Procedure LexInit;
Begin
  LexOpened := False;
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('Impossible d''ouvrir: ' + Opts.SrcFile);
  LexOpened := True;
  LexEOF    := False;
  LexLineNo := 0;
  LexColNo  := 1;
  LexLine   := '';
  { Lire la premiere ligne }
  LexNextLine;
  { Shebang : ignorer #!/usr/bin/perl ou #!/usr/bin/env perl }
  If (Length(LexLine) >= 2) And
     (LexLine[1] = '#') And (LexLine[2] = '!') Then
  Begin
    LexSkipLineComment;  { sauter toute la ligne }
    LexNextLine;         { passer a la ligne suivante }
  End;
End;

{ ---- LexClose : fermer le fichier source ------------------ }
Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ---- PrintToken : mode debug -d --------------------------- }
Procedure PrintToken(Const T : TToken);
Var
  KS : String[12];
  NS : TString;
Begin
  Case T.Kind Of
    TK_IDENT      : KS := 'IDENT   ';
    TK_KEYWORD    : KS := 'KEYWORD ';
    TK_SCALAR     : KS := 'SCALAR  ';
    TK_ARRAY_SIG  : KS := 'ARRAY@  ';
    TK_HASH_SIG   : KS := 'HASH%   ';
    TK_INTEGER    : KS := 'INTEGER ';
    TK_FLOAT      : KS := 'FLOAT   ';
    TK_STRING     : KS := 'STRING  ';
    TK_HEREDOC    : KS := 'HEREDOC ';
    TK_REGEXP     : KS := 'REGEXP  ';
    TK_FILEHANDLE : KS := 'FILEHND ';
    TK_OP         : KS := 'OP      ';
    TK_PUNCT      : KS := 'PUNCT   ';
    TK_EOF        : KS := 'EOF     ';
  End;
  Write('[', T.Line, ':', T.Col, '] ', KS, ' "', T.Val, '"');
  If T.Kind = TK_INTEGER Then
  Begin Str(T.IntVal, NS); Write(' =', NS); End
  Else If T.Kind = TK_FLOAT Then
  Begin Str(T.FloatVal : 0 : 6, NS); Write(' =', NS); End;
  WriteLn;
End;

{ ---- ParserAdvance : lire le prochain token --------------- }
Procedure ParserAdvance;
Begin
  LexNextToken(CurToken);
  If Opts.DebugTok Then
    PrintToken(CurToken);
End;

{ ============================================================
  LITTERAUX ET CONSTANTES PERL
  ============================================================ }

{ ---- DataAdd / DataAddStr : table de donnees statiques ------- }
{ Implementation complete (initialement ebauche, stabilise) }
Function DataAdd(Const ALbl : TString; AKind : TDataKind;
                 AInt : LongInt; Const AStr : TString) : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    WriteLn('PERL86: ERREUR - table de donnees saturee (MAX_DATA=', MAX_DATA, ')');
    Inc(ErrorCount);
    DataAdd := -1;
    Exit;
  End;
  DataTab[DataCount].LblName   := ALbl;
  DataTab[DataCount].Kind      := AKind;
  DataTab[DataCount].IntVal    := AInt;
  DataTab[DataCount].StrVal    := AStr;
  DataTab[DataCount].ElemCount := 0;
  DataAdd := DataCount;
  Inc(DataCount);
End;

Function DataAddStr(Const S : TString) : Integer;
Var
  I   : Integer;
  Lbl : TString;
  Seq : TString;
Begin
  { Chercher si la chaine existe deja pour eviter les doublons }
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_STR) And (DataTab[I].StrVal = S) Then
    Begin
      DataAddStr := I;
      Exit;
    End;
  { Nouvelle entree }
  Inc(LabelSeq);
  Str(LabelSeq, Seq);
  Lbl := PR_STR_PFX + Seq;
  DataAddStr := DataAdd(Lbl, DK_STR, 0, S);
End;

{ ---- ExprMakeImm : construire une valeur immediate -------- }
{ TP7 : pas de retour de Record -> parametre Var Res          }
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
End;

{ ---- ExprMakeNone : valeur void/invalide ------------------ }
Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
End;

{ ---- ExprMakeUndef : valeur undef (pointeur nul) ---------- }
{ En Perl, undef est la valeur « non definie » ; on la         }
{ represente par un immediat 0 avec le type TY_IDX_UNDEF.      }
Procedure ExprMakeUndef(Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_UNDEF;
  Res.Offset  := 0;
End;

{ ---- LitEvalInt : token TK_INTEGER -> TExprVal ------------ }
{ IntVal est deja calcule par LexScanNumber (hex/bin/oct/dec)  }
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_SCALAR, Res);
End;

{ ---- LitEvalFloat : TK_FLOAT -> int tronque + warning ----- }
{ Cible 8086 sans FPU : les flottants sont tronques en entier. }
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal);
Var
  IV : LongInt;
Begin
  IV := Trunc(T.FloatVal);
  ExprMakeImm(IV, TY_IDX_SCALAR, Res);
  WriteLn('PERL86:', T.Line, ':', T.Col,
          ': Avertissement: flottant tronque a ', IV,
          ' (pas de FPU sur 8086)');
  Inc(WarnCount);
End;

{ ---- LitEvalStr : TK_STRING -> EK_MEM pointant dans DataSeg }
{ La chaine est ajoutee au segment de donnees.                 }
{ Les interpolations encodees (#1nom#2, #3nom#4) seront        }
{ resolues par EmitInterpolatedStr.                            }
Procedure LitEvalStr(Const T : TToken; Var Res : TExprVal);
Begin
  Res.Kind    := EK_MEM;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_SCALAR;
  Res.Offset  := DataAddStr(T.Val);
End;

{ ---- LitEvalHeredoc : TK_HEREDOC -> meme chemin que STRING -- }
Procedure LitEvalHeredoc(Const T : TToken; Var Res : TExprVal);
Begin
  Res.Kind    := EK_MEM;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_SCALAR;
  Res.Offset  := DataAddStr(T.Val);
End;

{ ---- ParseQwList : qw(mot1 mot2 mot3) -> tableau statique -- }
{ Consomme les tokens jusqu''a la parenthese fermante.         }
{ Retourne le nombre d''elements lus (max MAX_PARAM).          }
{ Les elements sont deposes dans DataTab comme DK_STR.         }
{ Res re�oit EK_NONE }
Function ParseQwList(Var Items : Array Of Integer;
                     Var ItemCount : Integer) : Boolean;
Var
  S    : TString;
  Sep  : Char;
Begin
  ParseQwList := False;
  ItemCount  := 0;
  { CurToken doit etre '(' }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
  Begin
    WriteLn('PERL86:', CurToken.Line, ': Erreur: ''('' attendu apres qw');
    Inc(ErrorCount);
    Exit;
  End;
  { Determiner le separateur de fermeture }
  Sep := ')';
  ParserAdvance;  { consommer ''('' }
  { Accumuler les barewords separes par des espaces ou virgules }
  S := '';
  While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
        Not (CurToken.Kind = TK_EOF) Do
  Begin
    { Les tokens dans qw() sont des IDENTs ou mot-cles (barewords) }
    If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Or
       (CurToken.Kind = TK_INTEGER) Or (CurToken.Kind = TK_STRING) Then
    Begin
      S := CurToken.Val;
      If ItemCount <= High(Items) Then
      Begin
        Items[ItemCount] := DataAddStr(S);
        Inc(ItemCount);
      End;
    End Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
    Begin
      { virgule optionnelle : on ignore }
    End;
    ParserAdvance;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance;  { consommer '')'' }
  ParseQwList := True;
End;

{ ---- LitEval : dispatcher principal des litteraux Perl ----- }
{ Tokens traites : TK_INTEGER, TK_FLOAT, TK_STRING,           }
{   TK_HEREDOC, TK_KEYWORD (undef / true / false).            }
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeNone(Res);  { valeur par defaut }
  Case T.Kind Of
    TK_INTEGER : LitEvalInt(T, Res);
    TK_FLOAT   : LitEvalFloat(T, Res);
    TK_STRING  : LitEvalStr(T, Res);
    TK_HEREDOC : LitEvalHeredoc(T, Res);
    TK_KEYWORD :
    Begin
      If T.Val = 'undef' Then
        ExprMakeUndef(Res)
      Else If (T.Val = 'not') Then
        ExprMakeImm(1, TY_IDX_SCALAR, Res) { sera inverse par l''expression parente }
      Else
      Begin
        WriteLn('PERL86:', T.Line, ':', T.Col,
                ': Erreur: mot-cle non utilisable comme litteral : ', T.Val);
        Inc(ErrorCount);
      End;
    End;
    TK_IDENT :
    Begin
      { Bareword : traite comme chaine litterale en contexte litteral }
      { Ex: print FOO; -> "FOO" }
      If Opts.Strict Then
      Begin
        WriteLn('PERL86:', T.Line, ':', T.Col,
                ': Erreur (strict): bareword "', T.Val, '" non autorise');
        Inc(ErrorCount);
      End Else
      Begin
        WriteLn('PERL86:', T.Line, ':', T.Col,
                ': Avertissement: bareword "', T.Val,
                '" interprete comme chaine');
        Inc(WarnCount);
        Res.Kind    := EK_MEM;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_SCALAR;
        Res.Offset  := DataAddStr(T.Val);
      End;
    End;
  Else
    WriteLn('PERL86:', T.Line, ':', T.Col,
            ': Erreur: token non litteral : ', T.Val);
    Inc(ErrorCount);
  End;
End;

{ ============================================================
  OPERATEURS ET PRECEDENCE (PRATT PARSER)
  ============================================================ }

{ ---- BinOpPrec : precedence d''un operateur binaire -------- }
{ Retourne 0 si ce n''est pas un operateur binaire infix.      }
{ Perl : deux familles logiques :                              }
{   haute  &&  ||  //  !   (precedence C-style)               }
{   basse  and  or  not    (precedence tres basse)             }
{ Niveaux numeriques : plus le chiffre est eleve, plus l''op   }
{ est prioritaire dans les expressions.                        }
Function BinOpPrec(Const Op : TString) : Integer;
Begin
  { Prec 1 (plus basse) : or xor }
  If (Op = 'or') Or (Op = 'xor') Then Begin BinOpPrec := 1; Exit; End;
  { Prec 2 : and }
  If Op = 'and' Then Begin BinOpPrec := 2; Exit; End;
  { Prec 3 : affectations = += -= *= /= %= .= //= &&= ||= x= **= <<= >>= &= |= ^= }
  If (Op = '=')   Or (Op = '+=')  Or (Op = '-=')  Or (Op = '*=')  Or
     (Op = '/=')  Or (Op = '%=')  Or (Op = '.=')  Or (Op = '//=') Or
     (Op = '&&=') Or (Op = '||=') Or (Op = 'x=')  Or (Op = '**=') Or
     (Op = '<<=') Or (Op = '>>=') Or (Op = '&=')  Or (Op = '|=')  Or
     (Op = '^=')  Then Begin BinOpPrec := 3; Exit; End;
  { Prec 4 : ternaire '?' et ':' traites directement dans ParseExprPrec }
  { Prec 5 : .. et ... (plage) }
  If (Op = '..') Or (Op = '...') Then Begin BinOpPrec := 5; Exit; End;
  { Prec 6 : || // (defined-or) }
  If (Op = '||') Or (Op = '//') Then Begin BinOpPrec := 6; Exit; End;
  { Prec 7 : && }
  If Op = '&&' Then Begin BinOpPrec := 7; Exit; End;
  { Prec 8 : | ^ (bitwise or / xor) }
  If (Op = '|') Or (Op = '^') Then Begin BinOpPrec := 8; Exit; End;
  { Prec 9 : & (bitwise and) }
  If Op = '&' Then Begin BinOpPrec := 9; Exit; End;
  { Prec 10 : == != <=> eq ne cmp ~~ =~ !~ }
  If (Op = '==')  Or (Op = '!=')  Or (Op = '<=>') Or
     (Op = 'eq')  Or (Op = 'ne')  Or (Op = 'cmp') Or
     (Op = '~~')  Then Begin BinOpPrec := 10; Exit; End;
  { operateurs de matching =~ et !~ (meme precedence 10) }
  If (Op = '=~') Or (Op = '!~') Then Begin BinOpPrec := 10; Exit; End;
  { Prec 11 : < > <= >= lt gt le ge }
  If (Op = '<')  Or (Op = '>')  Or (Op = '<=') Or (Op = '>=') Or
     (Op = 'lt') Or (Op = 'gt') Or (Op = 'le') Or (Op = 'ge') Then
  Begin BinOpPrec := 11; Exit; End;
  { Prec 12 : << >> (decalage bit) }
  If (Op = '<<') Or (Op = '>>') Then Begin BinOpPrec := 12; Exit; End;
  { Prec 13 : + - . (addition, soustraction, concatenation) }
  If (Op = '+') Or (Op = '-') Or (Op = '.') Then Begin BinOpPrec := 13; Exit; End;
  { Prec 14 : * / % x (multiplication, modulo, repetition) }
  If (Op = '*') Or (Op = '/') Or (Op = '%') Or (Op = 'x') Then
  Begin BinOpPrec := 14; Exit; End;
  { Prec 15 (plus haute, binaire) : ** (puissance, assoc droite) }
  If Op = '**' Then Begin BinOpPrec := 15; Exit; End;
  BinOpPrec := 0;  { Pas un operateur binaire connu }
End;

{ ---- IsRightAssoc : operateur droite-associatif ? ---------- }
{ En Perl : = += -= etc. et ** sont associatifs a droite       }
{ Ex : $a = $b = 5  -> $a = ($b = 5)                          }
{       2 ** 3 ** 4 -> 2 ** (3 ** 4)                          }
Function IsRightAssoc(Const Op : TString) : Boolean;
Begin
  IsRightAssoc :=
    (Op = '=')   Or (Op = '+=')  Or (Op = '-=')  Or (Op = '*=')  Or
    (Op = '/=')  Or (Op = '%=')  Or (Op = '.=')  Or (Op = '//=') Or
    (Op = '&&=') Or (Op = '||=') Or (Op = 'x=')  Or (Op = '**=') Or
    (Op = '<<=') Or (Op = '>>=') Or (Op = '&=')  Or (Op = '|=')  Or
    (Op = '^=')  Or (Op = '**');
End;

{ ---- ExprLoad : charger une TExprVal dans le registre AX -- }
{ Stub - implementation complete (emetteur ASM)                }
{ En mode stub, on marque simplement la valeur comme etant en  }
{ AX pour que le parseur puisse continuer a travailler.        }
Procedure ExprLoad(Var E : TExprVal);
{ Convention EK_MEM :                                          }
{   ImmVal = 0 -> Offset = indice DataTab (donnee statique)    }
{   ImmVal = 1 -> Offset = deplacement pile (local [BP-Offset]) }
Var
  S : TString;
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      Str(E.ImmVal, S);
      EmitInstr('MOV', 'AX, ' + S);
    End;
    EK_MEM :
    Begin
      If E.ImmVal = 1 Then
      Begin
        { Variable locale my/local : acces [BP - Offset] }
        Str(E.Offset, S);
        EmitInstr('MOV', 'AX, WORD PTR [BP-' + S + ']');
      End Else If E.ImmVal = 2 Then
      Begin
        { Element tableau dynamique : adresse deja dans BX }
        EmitInstr('MOV', 'AX, [BX]');
      End Else
      Begin
        { Donnee statique DATA : Offset = indice dans DataTab }
        If (E.Offset >= 0) And (E.Offset < DataCount) Then
        Begin
          If DataTab[E.Offset].Kind = DK_STR Then
            EmitInstr('MOV', 'AX, OFFSET ' + DataTab[E.Offset].LblName)
          Else
            EmitInstr('MOV', 'AX, [' + DataTab[E.Offset].LblName + ']');
        End Else
          EmitInstr('MOV', 'AX, 0');  { securite : indice invalide }
      End;
    End;
    EK_AX   : ;  { deja dans AX, rien a emettre }
    EK_DXAX : ;  { deja dans DX:AX, rien a emettre }
    EK_NONE : ;  { expression vide, rien a emettre }
  End;
  E.Kind := EK_AX;
End;

{ ---- ExprEmitBinOp : code ASM pour un operateur binaire ---- }
{ Stub - implementation complete (expressions)                 }
{ Convention d''appel :                                         }
{   Left  : operande gauche (ExprLoad l''a mis en AX)          }
{   Right : operande droite (sera charge en BX ou CX)          }
{   Res   : valeur resultante -> EK_AX                         }
{ Operateurs impliques :                                        }
{   +  -> ADD  AX, BX        -  -> SUB  AX, BX                }
{   *  -> IMUL BX            /  -> CWD / IDIV BX -> AX = quotient }
{   %  -> CWD / IDIV BX -> residue dans DX                    }
{   ** -> appel runtime _PRRT_POW (entier, boucle de mul)      }
{   .  -> appel runtime _PRRT_CONCAT(DI=dst, SI=src)           }
{   x  -> appel runtime _PRRT_STRREPEAT(DI, SI, CX)           }
{   == -> CMP AX, BX ; SETE  AL ; MOVZX AX, AL               }
{   != -> CMP AX, BX ; SETNE AL ; MOVZX AX, AL               }
{   <  -> CMP AX, BX ; SETL  AL  etc.                         }
{   <=> -> CMP AX, BX ; SETL/SETE -> AX=-1/0/1                }
{   && -> court-circuit via labels _PRL_LAND_N                 }
{   || -> court-circuit via labels _PRL_LOR_N                  }
{   // -> test defined (!=undef) puis court-circuit             }
{   &  -> AND AX, BX  |  -> OR AX, BX  ^  -> XOR AX, BX      }
{   << -> SAL AX, CL   >> -> SAR AX, CL                       }
{   eq / ne / lt / le / gt / ge / cmp -> _PRRT_STRCMP          }
{ ---- ExprEmitBinOp : code ASM pour un operateur binaire ---- }
{ Convention d''appel (etablie par ParseExprPrec) :             }
{   Affectations (prec=3) : Left=EK_MEM (lvalue), AX=Right     }
{   Tous les autres (prec>=4 et prec=1,2) :                    }
{     BX = valeur gauche, AX = valeur droite                    }
{   &&, ||, // : traites directement dans ParseExprPrec         }
Procedure ExprEmitBinOp(Const Op : TString;
                         Var Left, Right : TExprVal;
                         Var Res         : TExprVal);
Var
  LblA : TString;
  LblB : TString;
  LblC : TString;
  SaveLeft : TExprVal;   { copie de Left pour affectations composees }
  Idx  : Integer;        { DataTab pour _PRRT_STRBUF }
Begin
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_SCALAR;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  { ==============================================================
    Affectation simple '=' : Left=EK_MEM, AX=Right
    ============================================================== }
  If Op = '=' Then
  Begin
    EmitStoreScalar(Left);
    Res.TypeIdx := Left.TypeIdx;
    Exit;
  End;
  { ==============================================================
    Affectations composees : Left=EK_MEM, AX=Right (valeur)
    On sauve Right dans CX, charge Left, applique l''op, re-stocke.
    ============================================================== }
  SaveLeft := Left;   { garder l''adresse lvalue }
  If (Op = '+=') Or (Op = '-=') Or (Op = '*=') Or (Op = '/=') Or
     (Op = '%=') Or (Op = '&=') Or (Op = '|=') Or (Op = '^=') Or
     (Op = '<<=') Or (Op = '>>=') Or (Op = '.=') Or (Op = '**=') Or
     (Op = '||=') Or (Op = '&&=') Or (Op = '//=') Or (Op = 'x=') Then
  Begin
    { CX = Right (valeur du membre droit) }
    EmitInstr('MOV', 'CX, AX');
    { Charger Left dans AX }
    ExprLoad(SaveLeft);
    { Appliquer l''operation }
    If      Op = '+='  Then EmitInstr('ADD',  'AX, CX')
    Else If Op = '-='  Then EmitInstr('SUB',  'AX, CX')
    Else If Op = '*='  Then
    Begin EmitInstr('IMUL', 'CX'); End
    Else If Op = '/='  Then
    Begin EmitInstr1('CWD'); EmitInstr('IDIV', 'CX'); End
    Else If Op = '%='  Then
    Begin EmitInstr1('CWD'); EmitInstr('IDIV', 'CX'); EmitInstr('MOV', 'AX, DX'); End
    Else If Op = '&='  Then EmitInstr('AND',  'AX, CX')
    Else If Op = '|='  Then EmitInstr('OR',   'AX, CX')
    Else If Op = '^='  Then EmitInstr('XOR',  'AX, CX')
    Else If Op = '<<=' Then Begin EmitInstr('MOV', 'CL, CL'); EmitInstr('SHL', 'AX, CL'); End
    Else If Op = '>>=' Then Begin EmitInstr('SAR', 'AX, CL'); End
    Else If Op = '||=' Then
    Begin
      { AX = Left ; si non-zero, ne rien changer ; sinon AX = Right (CX) }
      EmitInstr('TEST', 'AX, AX');
      LblA := LabelGen(PR_LBL_PFX);
      EmitInstr('JNZ', LblA);
      EmitInstr('MOV', 'AX, CX');
      EmitLabel(LblA);
    End
    Else If (Op = '&&=') Or (Op = '//=') Then
    Begin
      { AX = Left ; si zero, ne rien changer ; sinon AX = Right (CX) }
      EmitInstr('TEST', 'AX, AX');
      LblA := LabelGen(PR_LBL_PFX);
      EmitInstr('JZ', LblA);
      EmitInstr('MOV', 'AX, CX');
      EmitLabel(LblA);
    End
    Else If Op = '.=' Then
    Begin
      { concat-assign : STRBUF = Left + Right, AX = STRBUF }
      If DataFindByLabel('_PRRT_STRBUF') < 0 Then
      Begin
        Idx := DataAdd('_PRRT_STRBUF', DK_ARRAY_BLK, 0, '');
        DataTab[Idx].ElemCount := 128;
      End;
      EmitInstr('MOV', 'BYTE PTR [_PRRT_STRBUF], 0');
      EmitInstr('MOV', 'DI, OFFSET _PRRT_STRBUF');
      EmitInstr('MOV', 'SI, AX');   { Left (courante) en SI }
      EmitInstr('CALL', '_PRRT_CONCAT');   { copie Left -> STRBUF }
      EmitInstr('MOV', 'SI, CX');   { Right (appended) en SI }
      EmitInstr('MOV', 'DI, OFFSET _PRRT_STRBUF');
      EmitInstr('CALL', '_PRRT_CONCAT');   { ajoute Right }
      EmitInstr('MOV', 'AX, OFFSET _PRRT_STRBUF');
    End
    Else { **= x= : stub, garder l''ancienne valeur }
      EmitComment(Op + ' : stub, valeur inchangee');
    { Stocker le resultat dans la lvalue }
    EmitStoreScalar(Left);
    Exit;
  End;
  { ==============================================================
    Operateurs binaires standard : BX=Left, AX=Right
    ============================================================== }
  { ---- Arithmetiques ---- }
  If Op = '+' Then Begin EmitInstr('ADD', 'AX, BX'); Exit; End;
  If Op = '-' Then
  Begin
    { AX = Right, BX = Left -> voulons Left-Right }
    EmitInstr('XCHG', 'AX, BX');
    EmitInstr('SUB',  'AX, BX');
    Exit;
  End;
  If Op = '*' Then Begin EmitInstr('IMUL', 'BX'); Exit; End;
  If Op = '/' Then
  Begin
    { BX=Left, AX=Right : voulons Left/Right -> AX=Left, BX=Right }
    EmitInstr('XCHG', 'AX, BX');
    EmitInstr1('CWD');
    EmitInstr('IDIV', 'BX');
    Exit;
  End;
  If Op = '%' Then
  Begin
    EmitInstr('XCHG', 'AX, BX');
    EmitInstr1('CWD');
    EmitInstr('IDIV', 'BX');
    EmitInstr('MOV', 'AX, DX');
    Exit;
  End;
  If Op = '**' Then
  Begin
    { Puissance entiere : stub -> CALL _PRRT_POW }
    EmitComment('** : CALL _PRRT_POW non implemente (stub)');
    EmitInstr('MOV', 'AX, 1');
    Exit;
  End;
  { ---- Concatenation et repetition ---- }
  If Op = '.' Then
  Begin
    { BX=Left string ptr, AX=Right string ptr -> concat -> STRBUF }
    If DataFindByLabel('_PRRT_STRBUF') < 0 Then
    Begin
      Idx := DataAdd('_PRRT_STRBUF', DK_ARRAY_BLK, 0, '');
      DataTab[Idx].ElemCount := 128;
    End;
    EmitInstr('PUSH', 'AX');                           { sauver Right }
    EmitInstr('MOV', 'BYTE PTR [_PRRT_STRBUF], 0');   { vider STRBUF }
    EmitInstr('MOV', 'DI, OFFSET _PRRT_STRBUF');
    EmitInstr('MOV', 'SI, BX');                        { SI = Left }
    EmitInstr('CALL', '_PRRT_CONCAT');                 { copie Left }
    EmitInstr('POP', 'SI');                            { SI = Right }
    EmitInstr('MOV', 'DI, OFFSET _PRRT_STRBUF');
    EmitInstr('CALL', '_PRRT_CONCAT');                 { ajoute Right }
    EmitInstr('MOV', 'AX, OFFSET _PRRT_STRBUF');
    Exit;
  End;
  If Op = 'x' Then
  Begin
    { BX=src string ptr, AX=count -> repete -> STRBUF }
    If DataFindByLabel('_PRRT_STRBUF') < 0 Then
    Begin
      Idx := DataAdd('_PRRT_STRBUF', DK_ARRAY_BLK, 0, '');
      DataTab[Idx].ElemCount := 128;
    End;
    EmitInstr('MOV', 'CX, AX');                        { CX = count }
    EmitInstr('MOV', 'SI, BX');                        { SI = src }
    EmitInstr('MOV', 'DI, OFFSET _PRRT_STRBUF');
    EmitInstr('CALL', '_PRRT_STRREPEAT');
    EmitInstr('MOV', 'AX, OFFSET _PRRT_STRBUF');
    Exit;
  End;
  { ---- Comparaisons numeriques : BX=Left, AX=Right ---- }
  If Op = '==' Then
  Begin EmitInstr('CMP', 'BX, AX'); EmitInstr('SETE',  'AL'); EmitInstr('MOVZX', 'AX, AL'); Exit; End;
  If Op = '!=' Then
  Begin EmitInstr('CMP', 'BX, AX'); EmitInstr('SETNE', 'AL'); EmitInstr('MOVZX', 'AX, AL'); Exit; End;
  If Op = '<'  Then
  Begin EmitInstr('CMP', 'BX, AX'); EmitInstr('SETL',  'AL'); EmitInstr('MOVZX', 'AX, AL'); Exit; End;
  If Op = '<=' Then
  Begin EmitInstr('CMP', 'BX, AX'); EmitInstr('SETLE', 'AL'); EmitInstr('MOVZX', 'AX, AL'); Exit; End;
  If Op = '>'  Then
  Begin EmitInstr('CMP', 'BX, AX'); EmitInstr('SETG',  'AL'); EmitInstr('MOVZX', 'AX, AL'); Exit; End;
  If Op = '>=' Then
  Begin EmitInstr('CMP', 'BX, AX'); EmitInstr('SETGE', 'AL'); EmitInstr('MOVZX', 'AX, AL'); Exit; End;
  If Op = '<=>' Then
  Begin
    { Spaceship : BX=Left, AX=Right -> AX = -1/0/+1 }
    LblA := LabelGen(PR_LBL_PFX);   { label ''Left < Right'' }
    LblB := LabelGen(PR_LBL_PFX);   { label ''Left = Right'' }
    LblC := LabelGen(PR_LBL_PFX);   { label ''fin'' }
    EmitInstr('CMP', 'BX, AX');
    EmitInstr('JL',  LblA);
    EmitInstr('JE',  LblB);
    { Left > Right }
    EmitInstr('MOV', 'AX, 1');
    EmitInstr('JMP', LblC);
    EmitLabel(LblA);
    EmitInstr('MOV', 'AX, 0FFFFh');  { -1 en 16 bits }
    EmitInstr('JMP', LblC);
    EmitLabel(LblB);
    EmitInstr('XOR', 'AX, AX');
    EmitLabel(LblC);
    Exit;
  End;
  { ---- Comparaisons de chaines : stub ---- }
  If (Op = 'eq') Or (Op = 'ne') Or (Op = 'lt') Or (Op = 'le') Or
     (Op = 'gt') Or (Op = 'ge') Or (Op = 'cmp') Then
  Begin
    EmitComment(Op + ' : CALL _PRRT_STRCMP');
    EmitInstr('XOR', 'AX, AX');
    Exit;
  End;
  { ---- Bitwise ---- }
  If Op = '&' Then Begin EmitInstr('AND', 'AX, BX'); Exit; End;
  If Op = '|' Then Begin EmitInstr('OR',  'AX, BX'); Exit; End;
  If Op = '^' Then Begin EmitInstr('XOR', 'AX, BX'); Exit; End;
  If Op = '<<' Then
  Begin
    { BX=Left, AX=Right (shift count) : Left << Right }
    EmitInstr('MOV', 'CX, AX');
    EmitInstr('MOV', 'AX, BX');
    EmitInstr('SHL', 'AX, CL');
    Exit;
  End;
  If Op = '>>' Then
  Begin
    EmitInstr('MOV', 'CX, AX');
    EmitInstr('MOV', 'AX, BX');
    EmitInstr('SAR', 'AX, CL');
    Exit;
  End;
  { ---- Logiques bas niveau : BX=Left, AX=Right ---- }
  { ''and'' : equiv && mais prec basse : booleens sans court-circuit }
  If Op = 'and' Then
  Begin
    EmitInstr('TEST', 'BX, BX');
    EmitInstr('SETNE', 'BL');
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('SETNE', 'AL');
    EmitInstr('AND', 'AL, BL');
    EmitInstr('MOVZX', 'AX, AL');
    Exit;
  End;
  If Op = 'or' Then
  Begin
    EmitInstr('TEST', 'BX, BX');
    EmitInstr('SETNE', 'BL');
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('SETNE', 'AL');
    EmitInstr('OR',  'AL, BL');
    EmitInstr('MOVZX', 'AX, AL');
    Exit;
  End;
  If Op = 'xor' Then
  Begin
    EmitInstr('TEST', 'BX, BX');
    EmitInstr('SETNE', 'BL');
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('SETNE', 'AL');
    EmitInstr('XOR', 'AL, BL');
    EmitInstr('MOVZX', 'AX, AL');
    Exit;
  End;
  { ---- Plage .. et ... : stub ---- }
  If (Op = '..') Or (Op = '...') Then
  Begin
    EmitComment(Op + ' : plage, stub');
    EmitInstr('XOR', 'AX, AX');
    Exit;
  End;
  { Operateur inconnu : ne rien emettre }
  EmitComment('ExprEmitBinOp : operateur non gere : ' + Op);
End;

{ ---- ParsePrimary : expression primaire (atome) -- }
{ Unaires : -  !  ~  not  pre++ pre--  \(ref)                  }
{ Parens, litteraux, $var, @arr/%hash scalaire, func(), &sub() }
{ defined($v), ref($v), mots-cles builtins a 1 arg             }
Procedure ParsePrimary(Var Res : TExprVal);
Var
  Op      : TString;
  Sub     : TExprVal;
  Idx     : Integer;
  NStr    : TString;
  S       : TString;
  NCStr   : TString;   { taille nettoyage pile apres CALL }
  HKIdx   : Integer;   { indice entree HashKeyTab pour hash }
  SlotIdx : Integer;   { slot 0..MAX_HASH_PAIRS-1           }
Begin
  ExprMakeNone(Res);
  { ---- Operateurs unaires prefixes ---- }
  If CurToken.Kind = TK_OP Then
  Begin
    Op := CurToken.Val;
    If (Op = '-') Or (Op = '!') Or (Op = '~') Then
    Begin
      ParserAdvance;   { consommer l''operateur }
      ParsePrimary(Sub);
      ExprLoad(Sub);
      If Op = '-' Then
        EmitInstr1('NEG AX')
      Else If Op = '!' Then
      Begin
        EmitInstr('TEST',  'AX, AX');
        EmitInstr('SETE',  'AL');
        EmitInstr('MOVZX', 'AX, AL');
      End Else
        EmitInstr1('NOT AX');
      Res.Kind    := EK_AX;
      Res.TypeIdx := Sub.TypeIdx;
      Res.ImmVal  := 0;
      Res.Offset  := 0;
      Exit;
    End;
    { Pre-++ et pre-- : EmitIncrDecr }
    If (Op = '++') Or (Op = '--') Then
    Begin
      ParserAdvance;
      ParsePrimary(Sub);
      EmitIncrDecr(Sub, Op = '++', True, Res);
      Exit;
    End;
    { \ (reference) : LEA si lvalue memoire, sinon adresse OFFSET }
    { \@arr, \%hash speciaux (avant ParsePrimary recursif) }
    If Op = '\' Then
    Begin
      ParserAdvance;
      { \@arr : retourner l''adresse du tableau }
      If CurToken.Kind = TK_ARRAY_SIG Then
      Begin
        NStr := CurToken.Val;
        Idx  := SymFindCat(NStr, SC_ARRAY_VAR);
        ParserAdvance;
        If Idx >= 0 Then
        Begin
          If SymTab[Idx].IsMy Then
          Begin Str(SymTab[Idx].Offset, S); EmitInstr('LEA', 'AX, [BP-' + S + ']'); End
          Else  EmitInstr('MOV', 'AX, OFFSET ' + SymTab[Idx].MangledName);
        End Else EmitInstr('XOR', 'AX, AX');
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_ARRAY;   { ref to array }
        Res.ImmVal := 0; Res.Offset := 0;
        Exit;
      End;
      { \%hash : retourner l''adresse du hash }
      If CurToken.Kind = TK_HASH_SIG Then
      Begin
        NStr := CurToken.Val;
        Idx  := SymFindCat(NStr, SC_HASH_VAR);
        ParserAdvance;
        If Idx >= 0 Then
        Begin
          If SymTab[Idx].IsMy Then
          Begin Str(SymTab[Idx].Offset, S); EmitInstr('LEA', 'AX, [BP-' + S + ']'); End
          Else  EmitInstr('MOV', 'AX, OFFSET ' + SymTab[Idx].MangledName);
        End Else EmitInstr('XOR', 'AX, AX');
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_HASH;    { ref to hash }
        Res.ImmVal := 0; Res.Offset := 0;
        Exit;
      End;
      { Cas general : \$scalar ou \expr }
      ParsePrimary(Sub);
      If (Sub.Kind = EK_MEM) And (Sub.ImmVal = 1) Then
      Begin
        Str(Sub.Offset, S);
        EmitInstr('LEA', 'AX, [BP-' + S + ']');
      End Else If (Sub.Kind = EK_MEM) And (Sub.ImmVal = 0) And
                  (Sub.Offset >= 0) And (Sub.Offset < DataCount) Then
        EmitInstr('MOV', 'AX, OFFSET ' + DataTab[Sub.Offset].LblName)
      Else
        ExprLoad(Sub);
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_REF;
      Res.ImmVal  := 0;
      Res.Offset  := 0;
      Exit;
    End;
  End;
  { ---- Unaire 'not' (mot-cle, basse precedence) ---- }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'not') Then
  Begin
    ParserAdvance;
    ParsePrimary(Sub);
    ExprLoad(Sub);
    EmitInstr('TEST',  'AX, AX');
    EmitInstr('SETE',  'AL');
    EmitInstr('MOVZX', 'AX, AL');
    Res.Kind    := EK_AX;
    Res.TypeIdx := TY_IDX_SCALAR;
    Res.ImmVal  := 0;
    Res.Offset  := 0;
    Exit;
  End;
  { ---- defined($v) : AX = (AX != 0) ---- }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'defined') Then
  Begin
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
    ParsePrimary(Sub);
    ExprLoad(Sub);
    EmitInstr('TEST',  'AX, AX');
    EmitInstr('SETNE', 'AL');
    EmitInstr('MOVZX', 'AX, AL');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
    Res.ImmVal := 0; Res.Offset := 0;
    Exit;
  End;
  { ---- ref($v) : retourne chaine type ou 0 ---- }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'ref') Then
  Begin
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
    ParsePrimary(Sub);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    { Determination du type au moment de la compilation selon TypeIdx }
    Case Sub.TypeIdx Of
      TY_IDX_REF :
      Begin
        Idx := DataAddStr('SCALAR');
        If Idx >= 0 Then EmitInstr('MOV', 'AX, OFFSET ' + DataTab[Idx].LblName)
        Else EmitInstr('XOR', 'AX, AX');
      End;
      TY_IDX_ARRAY :
      Begin
        Idx := DataAddStr('ARRAY');
        If Idx >= 0 Then EmitInstr('MOV', 'AX, OFFSET ' + DataTab[Idx].LblName)
        Else EmitInstr('XOR', 'AX, AX');
      End;
      TY_IDX_HASH :
      Begin
        Idx := DataAddStr('HASH');
        If Idx >= 0 Then EmitInstr('MOV', 'AX, OFFSET ' + DataTab[Idx].LblName)
        Else EmitInstr('XOR', 'AX, AX');
      End;
      TY_IDX_CODE :
      Begin
        Idx := DataAddStr('CODE');
        If Idx >= 0 Then EmitInstr('MOV', 'AX, OFFSET ' + DataTab[Idx].LblName)
        Else EmitInstr('XOR', 'AX, AX');
      End;
    Else
      { Non-reference : tester si non-nul (compatibilite) }
      ExprLoad(Sub);
      EmitInstr('TEST',  'AX, AX');
      EmitInstr('SETNE', 'AL');
      EmitInstr('MOVZX', 'AX, AL');
    End;
    Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
    Res.ImmVal := 0; Res.Offset := 0;
    Exit;
  End;
  { ---- Builtins : simples et multi-args ---- }
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    NStr := CurToken.Val;
    { index(s, sub [,pos]) -> _PRRT_INDEX -> AX(-1 si absent) }
    If NStr = 'index' Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      ParseExpr(Sub); ExprLoad(Sub);
      EmitInstr('PUSH', 'AX');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then ParserAdvance;
      ParseExpr(Sub); ExprLoad(Sub);
      EmitInstr('MOV', 'DI, AX');
      EmitInstr('POP', 'SI');
      EmitInstr('CALL', '_PRRT_INDEX');
      While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
      Begin ParserAdvance; ParseExpr(Sub); End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Exit;
    End;
    { rindex(s, sub [,pos]) -> _PRRT_RINDEX -> AX (derniere occ) }
    If NStr = 'rindex' Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      ParseExpr(Sub); ExprLoad(Sub);
      EmitInstr('PUSH', 'AX');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then ParserAdvance;
      ParseExpr(Sub); ExprLoad(Sub);
      EmitInstr('MOV', 'DI, AX');
      EmitInstr('POP', 'SI');
      EmitInstr('CALL', '_PRRT_RINDEX');
      While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
      Begin ParserAdvance; ParseExpr(Sub); End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Exit;
    End;
    { substr(s, off [,len]) -> _PRRT_SUBSTR -> AX=ptr buf }
    If NStr = 'substr' Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      ParseExpr(Sub); ExprLoad(Sub);
      EmitInstr('PUSH', 'AX');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then ParserAdvance;
      ParseExpr(Sub); ExprLoad(Sub);
      EmitInstr('MOV', 'BX, AX');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      Begin
        ParserAdvance; ParseExpr(Sub); ExprLoad(Sub);
        EmitInstr('MOV', 'CX, AX');
      End Else
        EmitInstr('MOV', 'CX, 0FFFFh');
      EmitInstr('POP', 'SI');
      If DataFindByLabel('_PRRT_STRBUF') < 0 Then
      Begin
        Idx := DataAdd('_PRRT_STRBUF', DK_ARRAY_BLK, 0, '');
        DataTab[Idx].ElemCount := 128;
      End;
      EmitInstr('MOV', 'DI, OFFSET _PRRT_STRBUF');
      EmitInstr('CALL', '_PRRT_SUBSTR');
      EmitInstr('MOV', 'AX, DI');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Exit;
    End;
    { join(sep, list) -> stub AX=0 }
    If NStr = 'join' Then
    Begin
      EmitComment('join : stub AX=0');
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      ParseExpr(Sub);
      While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
      Begin ParserAdvance; ParseExpr(Sub); End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      EmitInstr('XOR', 'AX, AX');
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Exit;
    End;
    { split(pat, str) -> stub AX=0 }
    If NStr = 'split' Then
    Begin
      EmitComment('split : stub AX=0');
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
                (CurToken.Kind <> TK_EOF) Do
        ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      EmitInstr('XOR', 'AX, AX');
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Exit;
    End;
    { builtins a un argument avec dispatch real }
    If (NStr = 'chomp') Or (NStr = 'chop')    Or (NStr = 'chr')     Or
       (NStr = 'ord')   Or (NStr = 'length')  Or (NStr = 'lc')      Or
       (NStr = 'uc')    Or (NStr = 'lcfirst') Or (NStr = 'ucfirst') Or
       (NStr = 'int')   Or (NStr = 'abs')     Or (NStr = 'hex')     Or
       (NStr = 'oct')   Or (NStr = 'sqrt')    Or (NStr = 'pos')     Or
       (NStr = 'chdir') Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      ParsePrimary(Sub);
      ExprLoad(Sub);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      { Dispatch vers la routine runtime adequate }
      If NStr = 'length' Then
      Begin
        EmitInstr('MOV', 'SI, AX');
        EmitInstr('CALL', '_PRRT_STRLEN');
      End
      Else If (NStr = 'uc') Or (NStr = 'lc') Or
              (NStr = 'ucfirst') Or (NStr = 'lcfirst') Then
      Begin
        EmitInstr('MOV', 'SI, AX');
        If DataFindByLabel('_PRRT_STRBUF') < 0 Then
        Begin
          Idx := DataAdd('_PRRT_STRBUF', DK_ARRAY_BLK, 0, '');
          DataTab[Idx].ElemCount := 128;
        End;
        EmitInstr('MOV', 'DI, OFFSET _PRRT_STRBUF');
        If NStr = 'uc' Then EmitInstr('CALL', '_PRRT_UC')
        Else If NStr = 'lc' Then EmitInstr('CALL', '_PRRT_LC')
        Else If NStr = 'ucfirst' Then EmitInstr('CALL', '_PRRT_UCFIRST')
        Else EmitInstr('CALL', '_PRRT_LCFIRST');
        EmitInstr('MOV', 'AX, DI');
      End
      Else If NStr = 'chr' Then
      Begin
        If DataFindByLabel('_PRRT_STRBUF') < 0 Then
        Begin
          Idx := DataAdd('_PRRT_STRBUF', DK_ARRAY_BLK, 0, '');
          DataTab[Idx].ElemCount := 128;
        End;
        EmitInstr('MOV', 'DI, OFFSET _PRRT_STRBUF');
        EmitInstr('CALL', '_PRRT_CHR');
        EmitInstr('MOV', 'AX, DI');
      End
      Else If NStr = 'ord' Then
      Begin
        EmitInstr('MOV', 'SI, AX');
        EmitInstr('CALL', '_PRRT_ORD');
      End
      Else If NStr = 'chomp' Then
      Begin
        EmitInstr('MOV', 'SI, AX');
        EmitInstr('CALL', '_PRRT_CHOMP');
      End
      Else If NStr = 'chop' Then
      Begin
        EmitInstr('MOV', 'SI, AX');
        EmitInstr('CALL', '_PRRT_CHOP');
      End
      Else If NStr = 'abs' Then
        EmitInstr('CALL', '_PRRT_ABS')
      Else If NStr = 'hex' Then
      Begin
        EmitInstr('MOV', 'SI, AX');
        EmitInstr('CALL', '_PRRT_HEX2INT');
      End
      Else If NStr = 'oct' Then
      Begin
        EmitInstr('MOV', 'SI, AX');
        EmitInstr('CALL', '_PRRT_OCT2INT');
      End;
      { int sqrt pos chdir : AX reste inchange }
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Exit;
    End;
    { exists et delete sur hash }
    If (NStr = 'exists') Or (NStr = 'delete') Then
    Begin
      Op := NStr;   { sauver 'exists'/'delete' avant de reutiliser NStr }
      ParserAdvance;  { consommer 'exists'/'delete' }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      { Detecter hash-aware : $h[key] }
      If CurToken.Kind = TK_SCALAR Then
      Begin
        S := CurToken.Val;  { nom du hash }
        ParserAdvance;  { consommer $h }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
        Begin
          Idx := SymFindCat(S, SC_HASH_VAR);
          If Idx >= 0 Then
          Begin
            ParserAdvance;  { consommer '{' }
            { Cle constante : bareword ou chaine }
            NStr := '';
            If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_STRING) Then
            Begin
              NStr := CurToken.Val;
              ParserAdvance;
            End;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then ParserAdvance;
            HKIdx := HashSlotFind(Idx, NStr);
            If HKIdx >= 0 Then
            Begin
              SlotIdx := HashKeyTab[HKIdx].SlotIdx;
              Str(SymTab[Idx].Offset + 4 + SlotIdx * 4, S);
              If Op = 'exists' Then
                EmitInstr('MOV', 'AX, 1')  { cle connue -> existe toujours }
              Else
              Begin
                { delete : zeroiser la valeur }
                EmitInstr('MOV', 'WORD PTR [BP-' + S + '], 0');
                EmitInstr('MOV', 'AX, 1');
              End;
            End Else
              EmitInstr('MOV', 'AX, 0');  { cle inconnue }
            Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
            Res.ImmVal := 0; Res.Offset := 0;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
            Exit;
          End;
        End;
        { Fallback : traitement generique }
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
        Res.ImmVal := 0; Res.Offset := 0;
      End Else
      Begin
        ParsePrimary(Sub);
        ExprLoad(Sub);
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
        Res.ImmVal := 0; Res.Offset := 0;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      Exit;
    End;
    { pop / shift en contexte expression }
    If (NStr = 'pop') Or (NStr = 'shift') Then
    Begin
      ParseArrBuiltin(False);
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Exit;
    End;
    { scalar(@arr) en contexte expression }
    If NStr = 'scalar' Then
    Begin
      ParserAdvance;  { consommer 'scalar' }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      If CurToken.Kind = TK_ARRAY_SIG Then
      Begin
        Idx := SymFindCat(CurToken.Val, SC_ARRAY_VAR);
        If Idx >= 0 Then
        Begin
          Str(SymTab[Idx].Offset, S);
          EmitInstr('MOV', 'AX, WORD PTR [BP-' + S + ']');
        End Else
          EmitInstr('MOV', 'AX, 0');
        ParserAdvance;
      End Else
        EmitInstr('MOV', 'AX, 0');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Exit;
    End;
    { wantarray() -> 0 (contexte toujours scalaire dans impl.) }
    If NStr = 'wantarray' Then
    Begin
      ParserAdvance;  { consommer 'wantarray' }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      EmitInstr('MOV', 'AX, 0');
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Exit;
    End;
    { sous-routine anonyme en contexte expression }
    If NStr = 'sub' Then
    Begin
      ParseSubDecl;
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_CODE;
      Res.ImmVal := 0; Res.Offset := 0;
      Exit;
    End;
    { readline($fh) -> CALL _PRRT_READLINE -> AX=ptr ligne }
    If NStr = 'readline' Then
    Begin
      ParserAdvance;  { consommer 'readline' }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      If CurToken.Kind = TK_SCALAR Then
      Begin
        Idx := SymFindCat(CurToken.Val, SC_FILEHANDLE);
        If Idx < 0 Then Idx := SymFind(CurToken.Val, '$');
        ParserAdvance;
        If Idx >= 0 Then
        Begin
          Str(SymTab[Idx].Offset, S);
          EmitInstr('MOV', 'BX, WORD PTR [BP-' + S + ']');
        End Else
          EmitInstr('MOV', 'BX, 0');
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      If DataFindByLabel('_PRRT_FHBUF') < 0 Then
      Begin
        Idx := DataAdd('_PRRT_FHBUF', DK_ARRAY_BLK, 0, '');
        DataTab[Idx].ElemCount := 128;  { 256 octets }
      End;
      EmitInstr('CALL', '_PRRT_READLINE');
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Exit;
    End;
    { eof($fh) -> AX=1 si fin de fichier, 0 sinon }
    If NStr = 'eof' Then
    Begin
      ParserAdvance;  { consommer 'eof' }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      If CurToken.Kind = TK_SCALAR Then
      Begin
        Idx := SymFindCat(CurToken.Val, SC_FILEHANDLE);
        If Idx < 0 Then Idx := SymFind(CurToken.Val, '$');
        ParserAdvance;
        If Idx >= 0 Then
        Begin
          Str(SymTab[Idx].Offset, S);
          EmitInstr('MOV', 'BX, WORD PTR [BP-' + S + ']');
        End Else
          EmitInstr('MOV', 'BX, 0');
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      { Essayer de lire 1 octet : si AX=0 -> EOF }
      If DataFindByLabel('_PRRT_FHBUF') < 0 Then
      Begin
        Idx := DataAdd('_PRRT_FHBUF', DK_ARRAY_BLK, 0, '');
        DataTab[Idx].ElemCount := 128;
      End;
      S    := LabelGen('_PRL_EOFYES_');
      NStr := LabelGen('_PRL_EOFEND_');
      EmitInstr('MOV', 'AH, 3Fh');
      EmitInstr('MOV', 'CX, 1');
      EmitInstr('MOV', 'DX, OFFSET _PRRT_FHBUF');
      EmitInstr1('INT 21h');
      EmitInstr('JC', S);
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('JZ', S);
      { Pas EOF : reculer d''un octet (seek relatif -1) }
      EmitInstr('MOV', 'AX, 4201h');
      EmitInstr('MOV', 'CX, 0FFFFh');
      EmitInstr('MOV', 'DX, 0FFFFh');
      EmitInstr1('INT 21h');
      EmitInstr('MOV', 'AX, 0');
      EmitInstr('JMP', NStr);
      EmitLabel(S);
      EmitInstr('MOV', 'AX, 1');
      EmitLabel(NStr);
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Exit;
    End;
    { Appel de sous-routine avec mot-cle non reconnu : avancer }
    ParserAdvance;
    ExprMakeNone(Res);
    Exit;
  End;
  { ---- Appel &sub(args) ---- }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '&') Then
  Begin
    ParserAdvance;
    If CurToken.Kind = TK_IDENT Then
    Begin
      NStr := CurToken.Val;
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        ParseCallArgs;
      EmitInstr('CALL', PR_FN_PFX + NStr);
      If GCallArgCount > 0 Then
      Begin
        Str(GCallArgCount * 2, NCStr);
        EmitInstr('ADD', 'SP, ' + NCStr);
      End;
    End;
    Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
    Res.ImmVal := 0; Res.Offset := 0;
    Exit;
  End;
  { ---- Sous-expression parenthesee ---- }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance;     { consommer '(' }
    ParseExpr(Res);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance    { consommer ')' }
    Else
    Begin
      WriteLn('PERL86:', CurToken.Line, ': Erreur: '')'' attendu dans expression');
      Inc(ErrorCount);
    End;
    ParsePostfixOps(Res);
    Exit;
  End;
  { ---- TK_FILEHANDLE <$fh> : readline depuis filehandle ---- }
  { STDOUT/STDERR/STDIN en contexte expression -> valeur nulle (pas readline) }
  If CurToken.Kind = TK_FILEHANDLE Then
  Begin
    NStr := CurToken.Val;  { nom du filehandle (sans $) }
    If (NStr = 'STDOUT') Or (NStr = 'STDERR') Or (NStr = 'STDIN') Then
    Begin
      { Bareword standard en expression : avancer sans emettre de code }
      ParserAdvance;
      ExprMakeNone(Res);
      Exit;
    End;
    ParserAdvance;
    { Charger le handle DOS dans BX }
    Idx := SymFindCat(NStr, SC_FILEHANDLE);
    If Idx >= 0 Then
    Begin
      Str(SymTab[Idx].Offset, S);
      EmitInstr('MOV', 'BX, WORD PTR [BP-' + S + ']');
    End Else
      EmitInstr('MOV', 'BX, 0');
    { Garantir _PRRT_FHBUF dans DataTab }
    If DataFindByLabel('_PRRT_FHBUF') < 0 Then
    Begin
      Idx := DataAdd('_PRRT_FHBUF', DK_ARRAY_BLK, 0, '');
      DataTab[Idx].ElemCount := 128;
    End;
    EmitInstr('CALL', '_PRRT_READLINE');
    Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
    Res.ImmVal := 0; Res.Offset := 0;
    Exit;
  End;
  { ---- Litteraux directs ---- }
  If (CurToken.Kind = TK_INTEGER) Or
     (CurToken.Kind = TK_FLOAT)   Or
     (CurToken.Kind = TK_STRING)  Or
     (CurToken.Kind = TK_HEREDOC) Or
     ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'undef')) Then
  Begin
    LitEval(CurToken, Res);
    ParserAdvance;
    ParsePostfixOps(Res);
    Exit;
  End;
  { ---- Variable scalaire $var ---- }
  If CurToken.Kind = TK_SCALAR Then
  Begin
    NStr := CurToken.Val;
    { variables de capture $1 et $2 -> _PRCAP_1, _PRCAP_2 }
    If (NStr = '1') Or (NStr = '2') Then
    Begin
      ParserAdvance;
      EmitInstr('MOV', 'AX, WORD PTR [_PRCAP_' + NStr + ']');
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal  := 0;
      Res.Offset  := 0;
      ParsePostfixOps(Res);
      Exit;
    End;
    Idx  := SymFind(NStr, '$');
    ParserAdvance;
    { Acces a un element de hash : signe $ suivi de accolade }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    Begin
      HKIdx := SymFindCat(NStr, SC_HASH_VAR);
      If HKIdx >= 0 Then
      Begin
        ParseHashElemAccess(HKIdx, Res);
        ParsePostfixOps(Res);
        Exit;
      End;
    End;
    { Acces a un element de tableau : $arr[idx] }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
    Begin
      { Chercher d''abord un tableau @arr avec le meme nom }
      Idx := SymFindCat(NStr, SC_ARRAY_VAR);
      If Idx >= 0 Then
      Begin
        ParseArrElemAccess(Idx, Res);
        ParsePostfixOps(Res);
        Exit;
      End;
    End;
    { $$ref et deref-brace -> dereferencement scalaire (NStr vide) }
    If NStr = '' Then
    Begin
      If CurToken.Kind = TK_SCALAR Then
      Begin
        { $$ref : charger $ref dans BX puis AX = [BX] }
        Idx := SymFind(CurToken.Val, '$');
        ParserAdvance;
        If Idx >= 0 Then
        Begin
          Sub := ExprMakeMem(Idx);
          ExprLoad(Sub);
          EmitInstr('MOV', 'BX, AX');
          EmitInstr('MOV', 'AX, [BX]');
        End Else EmitInstr('XOR', 'AX, AX');
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
        Res.ImmVal := 0; Res.Offset := 0;
        ParsePostfixOps(Res);
        Exit;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
      Begin
        { deref-brace-ref : idem avec accolades }
        ParserAdvance;  { consommer { }
        If CurToken.Kind = TK_SCALAR Then
        Begin
          Idx := SymFind(CurToken.Val, '$');
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then ParserAdvance;
          If Idx >= 0 Then
          Begin
            Sub := ExprMakeMem(Idx);
            ExprLoad(Sub);
            EmitInstr('MOV', 'BX, AX');
            EmitInstr('MOV', 'AX, [BX]');
          End Else EmitInstr('XOR', 'AX, AX');
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
          Res.ImmVal := 0; Res.Offset := 0;
          ParsePostfixOps(Res);
          Exit;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then ParserAdvance;
      End;
      ExprMakeNone(Res);
      Exit;
    End;
    If Idx < 0 Then
    Begin
      If Opts.Strict Then
        SymError('Variable non declaree : $' + NStr);
      ExprMakeNone(Res);
      Exit;
    End;
    Res := ExprMakeMem(Idx);
    ParsePostfixOps(Res);
    Exit;
  End;
  { ---- @arr / %hash en contexte scalaire ou dereferencement ---- }
  If (CurToken.Kind = TK_ARRAY_SIG) Or (CurToken.Kind = TK_HASH_SIG) Then
  Begin
    If CurToken.Kind = TK_ARRAY_SIG Then
    Begin
      { @$ref -> dereference reference tableau (sigil vide) }
      If CurToken.Val = '' Then
      Begin
        ParserAdvance;  { consommer @-sigil vide }
        If CurToken.Kind = TK_SCALAR Then
        Begin
          Idx := SymFind(CurToken.Val, '$');
          ParserAdvance;
          If Idx >= 0 Then
          Begin
            Sub := ExprMakeMem(Idx);
            ExprLoad(Sub);
            EmitComment('@$ref: dereferencement tableau');
            EmitInstr('MOV', 'BX, AX');
            EmitInstr('MOV', 'AX, [BX]');
          End Else EmitInstr('XOR', 'AX, AX');
        End Else EmitInstr('XOR', 'AX, AX');
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
        Res.ImmVal := 0; Res.Offset := 0;
        Exit;
      End;
      { scalar(@arr) = mot [BP-Offset] = count }
      Idx := SymFindCat(CurToken.Val, SC_ARRAY_VAR);
      If Idx >= 0 Then
      Begin
        Str(SymTab[Idx].Offset, S);
        EmitInstr('MOV', 'AX, WORD PTR [BP-' + S + ']');
      End Else
        EmitInstr('MOV', 'AX, 0');  { tableau inconnu -> 0 }
    End Else
    Begin
      { %hash en contexte scalaire -> count }
      Idx := SymFindCat(CurToken.Val, SC_HASH_VAR);
      If Idx >= 0 Then
      Begin
        Str(SymTab[Idx].Offset, S);
        EmitInstr('MOV', 'AX, WORD PTR [BP-' + S + ']');
      End Else
        EmitInstr('MOV', 'AX, 0');  { hash inconnu -> 0 }
    End;
    ParserAdvance;
    Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
    Res.ImmVal := 0; Res.Offset := 0;
    Exit;
  End;
  { ---- TK_IDENT : appel de fonction ou bareword ---- }
  If CurToken.Kind = TK_IDENT Then
  Begin
    NStr := CurToken.Val;
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParseCallArgs;
      EmitInstr('CALL', PR_FN_PFX + NStr);
      If GCallArgCount > 0 Then
      Begin
        Str(GCallArgCount * 2, NCStr);
        EmitInstr('ADD', 'SP, ' + NCStr);
      End;
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Exit;
    End;
    { constante use constant NOM => val }
    Idx := SymFindCat(NStr, SC_CONST);
    If Idx >= 0 Then
    Begin
      EmitInstr('MOV', 'AX, [' + SymTab[Idx].MangledName + ']');
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Exit;
    End;
    If Opts.Warnings Then
      WriteLn('PERL86:', CurToken.Line, ': Avert: bareword ''', NStr, '''');
    ExprMakeNone(Res);
    Exit;
  End;
  { ---- Fin ou ponctuation non reconnue : ne rien consommer ---- }
End;

{ ---- CurTokIsInfixOp : le token courant est-il un op infix? }
{ Retourne True si le token peut etre un operateur binaire     }
{ infix, et place le nom de l''operateur dans OpStr.           }
{ Teste : TK_OP avec prec > 0, et TK_KEYWORD pour and/or etc. }
Function CurTokIsInfixOp(Var OpStr : TString) : Boolean;
Begin
  OpStr := '';
  CurTokIsInfixOp := False;
  If CurToken.Kind = TK_OP Then
  Begin
    OpStr := CurToken.Val;
    If BinOpPrec(OpStr) > 0 Then
    Begin CurTokIsInfixOp := True; Exit; End;
    OpStr := '';
    Exit;
  End;
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    If (CurToken.Val = 'and') Or (CurToken.Val = 'or')  Or
       (CurToken.Val = 'xor') Or (CurToken.Val = 'eq')  Or
       (CurToken.Val = 'ne')  Or (CurToken.Val = 'lt')  Or
       (CurToken.Val = 'le')  Or (CurToken.Val = 'gt')  Or
       (CurToken.Val = 'ge')  Or (CurToken.Val = 'cmp') Or
       (CurToken.Val = 'x')   Then
    Begin
      OpStr := CurToken.Val;
      CurTokIsInfixOp := True;
    End;
  End;
End;

{ ---- ParseRegexOp : generer le code pour $str =~ /pat/ ------ }
{                                                                 }
{ CurToken doit etre TK_REGEXP (Val = kind+Chr(1)+pat+Chr(1)+repl)}
{ Left = expression gauche (la chaine sujet).                      }
{ Op = '=~' ou '!~'.                                               }
{ Resultat dans AX : 1 si match (ou subst), 0 sinon.               }
{ Negation si Op = '!~'.                                            }
Procedure ParseRegexOp(Const Op : TString;
                        Var Left : TExprVal;
                        Var Res  : TExprVal);
Var
  RKind  : Char;
  RPat   : TString;
  RRepl  : TString;
  PatLbl : TString;
  ReplLbl: TString;
  SeqStr : TString;
  I      : Integer;
  C      : Char;
  HasMeta: Boolean;
Begin
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_SCALAR;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  If CurToken.Kind <> TK_REGEXP Then
  Begin
    SymError('Expression reguliere attendue apres ' + Op);
    ExprMakeNone(Res);
    Exit;
  End;
  { Decoder Val : kind + Chr(1) + pat + Chr(1) + repl }
  If Length(CurToken.Val) < 1 Then
  Begin
    SymError('Token regex invalide');
    ParserAdvance;
    ExprMakeNone(Res);
    Exit;
  End;
  RKind := CurToken.Val[1];
  RPat  := '';
  RRepl := '';
  { Extraire pat : entre le 1er et 2eme Chr(1) }
  I := 3;  { sauter kind + Chr(1) }
  While (I <= Length(CurToken.Val)) And (CurToken.Val[I] <> Chr(1)) Do
  Begin
    RPat := RPat + CurToken.Val[I];
    Inc(I);
  End;
  { Extraire repl : apres le 2eme Chr(1) }
  If (I <= Length(CurToken.Val)) And (CurToken.Val[I] = Chr(1)) Then
  Begin
    Inc(I);
    While I <= Length(CurToken.Val) Do
    Begin
      RRepl := RRepl + CurToken.Val[I];
      Inc(I);
    End;
  End;
  { Avertir si metacaracteres dans le pattern }
  HasMeta := False;
  For I := 1 To Length(RPat) Do
  Begin
    C := RPat[I];
    If (C = '^') Or (C = '$') Or (C = '.') Or (C = '*') Or
       (C = '+') Or (C = '?') Or (C = '(') Or (C = ')') Or
       (C = '[') Or (C = ']') Or (C = '{') Or (C = '}') Or
       (C = '|') Then
      HasMeta := True;
  End;
  If HasMeta Then
    WriteLn('PERL86:', CurToken.Line, ': Avertissement: metacaracteres ignores dans /', RPat, '/');
  { Creer un label unique pour ce pattern dans DataTab }
  Inc(RegexSeq);
  Str(RegexSeq, SeqStr);
  PatLbl := '_PRRX_P' + SeqStr;
  DataAdd(PatLbl, DK_STR, 0, RPat);
  { Consommer le token TK_REGEXP }
  ParserAdvance;
  { Charger l'adresse de la chaine sujet dans SI }
  ExprLoad(Left);
  EmitInstr('MOV', 'SI, AX');
  { Charger l'adresse du pattern dans DI }
  EmitInstr('MOV', 'DI, OFFSET ' + PatLbl);
  { Emettre l'appel runtime selon le type }
  If RKind = 's' Then
  Begin
    { Substitution s/pat/repl/ }
    ReplLbl := '_PRRX_R' + SeqStr;
    DataAdd(ReplLbl, DK_STR, 0, RRepl);
    EmitInstr('MOV', 'BX, OFFSET ' + ReplLbl);
    EmitInstr('CALL', '_PRRT_RESUB');
    EmitComment('s/pat/repl/ : AX=1 si substitution effectuee');
  End
  Else If RKind = 't' Then
  Begin
    { Transliteration tr/// : stub minimal }
    EmitComment('tr/// : non implemente -> AX=0');
    EmitInstr('XOR', 'AX, AX');
  End
  Else
  Begin
    { Match /pat/ ou m/pat/ }
    EmitInstr('CALL', '_PRRT_REMATCH');
    EmitComment('/pat/ : AX=1 si trouve');
  End;
  { Stocker le resultat dans la variable capture $1 }
  EmitInstr('MOV', 'WORD PTR [_PRCAP_1], AX');
  { Negation pour !~ }
  If Op = '!~' Then
  Begin
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('SETZ', 'AL');
    EmitInstr('MOVZX', 'AX, AL');
  End;
End;

{ ---- ParseExprPrec : coeur du parseur Pratt  ------ }
{ Convention BX=Left, AX=Right pour les ops non-affectation.    }
{ Court-circuit inline pour && || //.                           }
{ Ternaire ? : avec labels _PRL_N.                              }
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op    : TString;
  Prec  : Integer;
  Right : TExprVal;
  Left  : TExprVal;
  CondT : TExprVal;
  TSeq  : TString;
  TernL : Integer;
  LblA  : TString;
  LblB  : TString;
Begin
  ParsePrimary(Left);
  Res := Left;
  Repeat
    { ---- Ternaire '?' : traitement special avec labels ---- }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '?') And
       (MinPrec <= 4) Then
    Begin
      ParserAdvance;
      Inc(LabelSeq); TernL := LabelSeq; Str(TernL, TSeq);
      ExprLoad(Left);
      LblA := PR_LBL_PFX + 'TE' + TSeq;   { ternaire else }
      LblB := PR_LBL_PFX + 'TD' + TSeq;   { ternaire done }
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('JZ',   LblA);
      ParseExprPrec(1, CondT);
      ExprLoad(CondT);
      EmitInstr('JMP', LblB);
      EmitLabel(LblA);
      If Not ((CurToken.Kind = TK_OP) And (CurToken.Val = ':')) Then
      Begin
        WriteLn('PERL86:', CurToken.Line, ': Erreur: '':'' attendu');
        Inc(ErrorCount);
      End Else
        ParserAdvance;
      ParseExprPrec(4, Right);
      ExprLoad(Right);
      EmitLabel(LblB);
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Left := Res;
      Continue;
    End;
    { ---- Operateur binaire standard ---- }
    If Not CurTokIsInfixOp(Op) Then Break;
    Prec := BinOpPrec(Op);
    If Prec < MinPrec Then Break;
    { signaler avant avance si regex attendue apres =~ !~ }
    If (Op = '=~') Or (Op = '!~') Then LexExpectRegex := True;
    ParserAdvance;
    { ---- matching =~ et !~ -> ParseRegexOp ---- }
    If (Op = '=~') Or (Op = '!~') Then
    Begin
      ParseRegexOp(Op, Left, Res);
      Left := Res;
      Continue;
    End;
    { ---- Court-circuit && : si Left faux, sauter Right ---- }
    If (Op = '&&') Or (Op = 'and') Then
    Begin
      ExprLoad(Left);
      LblA := LabelGen(PR_LBL_PFX);
      LblB := LabelGen(PR_LBL_PFX);
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('JZ',   LblA);
      If IsRightAssoc(Op) Then ParseExprPrec(Prec, Right)
      Else ParseExprPrec(Prec + 1, Right);
      ExprLoad(Right);
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('SETNE', 'AL');
      EmitInstr('MOVZX', 'AX, AL');
      EmitInstr('JMP', LblB);
      EmitLabel(LblA);
      EmitInstr('XOR', 'AX, AX');   { Left etait faux -> 0 }
      EmitLabel(LblB);
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Left := Res;
      Continue;
    End;
    { ---- Court-circuit || : si Left vrai, sauter Right ---- }
    If (Op = '||') Or (Op = 'or') Then
    Begin
      ExprLoad(Left);
      LblA := LabelGen(PR_LBL_PFX);
      LblB := LabelGen(PR_LBL_PFX);
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('JNZ',  LblA);
      If IsRightAssoc(Op) Then ParseExprPrec(Prec, Right)
      Else ParseExprPrec(Prec + 1, Right);
      ExprLoad(Right);
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('SETNE', 'AL');
      EmitInstr('MOVZX', 'AX, AL');
      EmitInstr('JMP', LblB);
      EmitLabel(LblA);
      EmitInstr('MOV', 'AX, 1');    { Left etait vrai -> 1 }
      EmitLabel(LblB);
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Left := Res;
      Continue;
    End;
    { ---- Court-circuit // (defined-or) : si Left defini (!=0) ---- }
    If Op = '//' Then
    Begin
      ExprLoad(Left);
      LblA := LabelGen(PR_LBL_PFX);
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('JNZ',  LblA);   { defini : garder AX }
      If IsRightAssoc(Op) Then ParseExprPrec(Prec, Right)
      Else ParseExprPrec(Prec + 1, Right);
      ExprLoad(Right);
      EmitLabel(LblA);
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Left := Res;
      Continue;
    End;
    { ---- Affectations (prec=3) : garder Left en EK_MEM ---- }
    If Prec = 3 Then
    Begin
      { Evaluer Right (IsRightAssoc pour toutes les affectations) }
      ParseExprPrec(Prec, Right);
      ExprLoad(Right);
      ExprEmitBinOp(Op, Left, Right, Res);
      Left := Res;
      Continue;
    End;
    { ---- Autres operateurs binaires : BX=Left, AX=Right ---- }
    If IsRightAssoc(Op) Then ParseExprPrec(Prec, Right)
    Else ParseExprPrec(Prec + 1, Right);
    { Charger Left dans BX avant de charger Right dans AX }
    ExprLoad(Left);
    EmitInstr('PUSH', 'AX');   { sauver Left }
    ExprLoad(Right);
    EmitInstr('POP', 'BX');    { BX = Left, AX = Right }
    ExprEmitBinOp(Op, Left, Right, Res);
    Left := Res;
  Until False;
  Res := Left;
End;

{ ---- ParseExpr : point d''entree principal des expressions -- }
{ Accepte tous les operateurs (precedence minimale = 1).        }
{ C''est la procedure a appeler depuis ParseStmt et les autres  }
{ contextes d''expressions.                                      }
Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParseExprPrec(1, Res);
End;

{ ============================================================
  TABLE DES SYMBOLES
  ============================================================ }

{ ---- SymWarn / SymError : messages contextuels -----------  }
Procedure SymWarn(Const Msg : TString);
Begin
  WriteLn('PERL86:', CurToken.Line, ': Avertissement: ', Msg);
  Inc(WarnCount);
End;

Procedure SymError(Const Msg : TString);
Begin
  WriteLn('PERL86:', CurToken.Line, ': Erreur: ', Msg);
  Inc(ErrorCount);
End;

{ ---- SymMangle : generer le nom mangle ASM d''un symbole -- }
{ Convention de nommage :                                      }
{   SC_FN             -> _PRF_nom                             }
{   SC_FILEHANDLE     -> nom (tel quel)                       }
{   SC_CONST          -> _PRV_PKG_nom                         }
{   SC_SCALAR/ARRAY/HASH/PARAM (our)  -> _PRV_PKG_nom         }
{   SC_SCALAR/ARRAY/HASH/PARAM (my)   -> _PRV_nom_Nseq        }
{     (les vars my sont sur la pile ; le label sert au debug)  }
Function SymMangle(Cat : TSymCat; IsMy : Boolean;
                   Const Name, Pkg : TString;
                   SeqN : Integer) : TString;
Var
  Seq : TString;
Begin
  Case Cat Of
    SC_FN :
      SymMangle := PR_FN_PFX + Name;
    SC_FILEHANDLE :
      SymMangle := Name;
  Else
    { SC_SCALAR, SC_ARRAY_VAR, SC_HASH_VAR, SC_PARAM, SC_PKG, SC_CONST }
    If IsMy Then
    Begin
      { Variable lexicale : suffixe de sequence pour unicite }
      Str(SeqN, Seq);
      SymMangle := PR_VAR_PFX + Name + '_' + Seq;
    End Else
    Begin
      { Variable globale our / constante : prefixe package }
      If Pkg = 'main' Then
        SymMangle := PR_VAR_PFX + Name
      Else
        SymMangle := PR_VAR_PFX + Pkg + '_' + Name;
    End;
  End;
End;

{ ---- SymAdd : ajouter un symbole dans la table ------------ }
{ Retourne l''indice du nouveau symbole, ou -1 en cas d''erreur }
{ IsMy    : portee lexicale (variable sur la pile)             }
{ IsOur   : portee package (variable dans DATA)               }
{ IsLocal : portee dynamique (sauvegarde/restauration pile)    }
Function SymAdd(Const Name : TString; Sigil : Char; Cat : TSymCat;
                TypeIdx : Integer;
                IsMy, IsOur, IsLocal : Boolean) : Integer;
Var
  R   : TSymRec;
  Seq : TString;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    SymError('Table des symboles saturee (MAX_SYM)');
    SymAdd := -1;
    Exit;
  End;
  { En mode strict, toute redeclaration est une erreur }
  If Opts.Strict And (SymFind(Name, Sigil) >= 0) And
     (Cat = SC_SCALAR) Then
    SymWarn('Redeclaration de ' + Sigil + Name);
  R.Name        := Name;
  R.SigilName   := Sigil + Name;
  R.Cat         := Cat;
  R.TypeIdx     := TypeIdx;
  R.IsMy        := IsMy;
  R.IsOur       := IsOur;
  R.IsLocal     := IsLocal;
  R.IsRef       := False;
  R.DeclLine    := CurToken.Line;
  R.ScopeLevel  := CurScope;
  { Offset dans le cadre de pile (IsMy ou IsLocal) }
  If IsMy Or IsLocal Then
  Begin
    Inc(CurFrameSize, 2);       { un scalaire = 1 mot de 2 octets }
    R.Offset := CurFrameSize;   { acces via [BP - Offset] }
  End Else
    R.Offset := 0;              { resoluble via MangledName dans DATA }
  { Nom mangle : generer un numero de sequence unique }
  Inc(LabelSeq);
  R.MangledName := SymMangle(Cat, IsMy, Name, CurPackage, LabelSeq);
  SymTab[SymCount] := R;
  SymAdd          := SymCount;
  Inc(SymCount);
  Inc(TotalSyms);
End;

{ ---- SymAddFn : raccourci pour declarer une sous-routine -- }
{ Retourne l''indice, ou -1. Toujours global (our implicite).   }
Function SymAddFn(Const Name : TString) : Integer;
Begin
  SymAddFn := SymAdd(Name, '&', SC_FN, TY_IDX_CODE,
                     False{ IsMy }, True{ IsOur }, False{ IsLocal });
End;

{ ---- SymFind : chercher un symbole par nom et sigil ------- }
{ Parcourt la table de bas en haut pour respecter la portee    }
{ lexicale (le symbole le plus recent a la priorite).          }
{ Sigil : ''$'' ''@'' ''%'' ''&'' (utiliser #0 pour toute categorie) }
{ Retourne l''indice dans SymTab, ou -1 si introuvable.         }
Function SymFind(Const Name : TString; Sigil : Char) : Integer;
Var
  I    : Integer;
  SCat : TSymCat;
Begin
  SymFind := -1;
  If Sigil = '&' Then SCat := SC_FN
  Else SCat := SC_SCALAR;  { valeur par defaut, non utilisee si Sigil=#0 }
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If SymTab[I].Name <> Name Then Continue;
    If Sigil = #0 Then
    Begin
      { Chercher quelle que soit la categorie }
      SymFind := I; Exit;
    End;
    If Sigil = '&' Then
    Begin
      If SymTab[I].Cat = SC_FN Then Begin SymFind := I; Exit; End;
    End Else If Sigil = '$' Then
    Begin
      If SymTab[I].Cat In [SC_SCALAR, SC_PARAM, SC_CONST] Then
      Begin SymFind := I; Exit; End;
    End Else If Sigil = '@' Then
    Begin
      If SymTab[I].Cat = SC_ARRAY_VAR Then Begin SymFind := I; Exit; End;
    End Else If Sigil = '%' Then
    Begin
      If SymTab[I].Cat = SC_HASH_VAR Then Begin SymFind := I; Exit; End;
    End Else
    Begin
      { Sigil inconnu : comparer le premier caractere de SigilName }
      If (Length(SymTab[I].SigilName) > 0) And
         (SymTab[I].SigilName[1] = Sigil) Then
      Begin SymFind := I; Exit; End;
    End;
  End;
End;

{ ---- SymFindCat : chercher par nom et categorie exacte ---- }
Function SymFindCat(Const Name : TString; Cat : TSymCat) : Integer;
Var
  I : Integer;
Begin
  SymFindCat := -1;
  For I := SymCount - 1 DownTo 0 Do
    If (SymTab[I].Name = Name) And (SymTab[I].Cat = Cat) Then
    Begin
      SymFindCat := I;
      Exit;
    End;
End;

{ ---- SymFindOrError : chercher ou signaler une erreur ----- }
{ Utilisee quand une variable doit obligatoirement etre declaree }
{ (notamment en mode use strict).                              }
Function SymFindOrError(Const Name : TString; Sigil : Char) : Integer;
Var
  Idx : Integer;
Begin
  Idx := SymFind(Name, Sigil);
  If Idx < 0 Then
  Begin
    If Opts.Strict Then
      SymError('Variable non declaree: ' + Sigil + Name +
               ' (use strict actif)')
    Else
      SymWarn('Variable non declaree: ' + Sigil + Name);
  End;
  SymFindOrError := Idx;
End;

{ ---- SymEnterScope : entrer dans un nouveau bloc ---------- }
{ Sauvegarde l''index courant de SymCount pour restauration     }
{ lors de SymLeaveScope. Aussi utilise pour gerer le cadre     }
{ local d''une sous-routine (CurFrameSize).                     }
Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
    FatalError('Trop d''imbrications de blocs (MAX_SCOPE)');
  ScopeStack[ScopeTop] := SymCount;
  Inc(ScopeTop);
  Inc(CurScope);
End;

{ ---- SymLeaveScope : sortir du bloc courant --------------- }
{ Supprime les symboles my/local ajoutes dans ce bloc.         }
{ Les symboles our (globaux) sont compactes et conserves.      }
Procedure SymLeaveScope;
Var
  I, Base, NewCount : Integer;
Begin
  If ScopeTop = 0 Then
  Begin
    SymError('SymLeaveScope: pas de portee ouverte (erreur interne)');
    Exit;
  End;
  Dec(ScopeTop);
  Dec(CurScope);
  Base     := ScopeStack[ScopeTop];  { limite inferieure ancienne }
  { Conserver les symboles our (portee package) en compactant }
  NewCount := Base;
  For I := Base To SymCount - 1 Do
    If SymTab[I].IsOur Or (SymTab[I].Cat = SC_FN) Then
    Begin
      If NewCount <> I Then
        SymTab[NewCount] := SymTab[I];
      Inc(NewCount);
    End;
  SymCount := NewCount;
End;

{ ---- SymDump : affichage de la table (mode debug -d) ------ }
Procedure SymDump;
Var
  I   : Integer;
  CS  : TString;
Begin
  WriteLn('--- TABLE DES SYMBOLES (', SymCount, ' entrees) ---');
  For I := 0 To SymCount - 1 Do
  Begin
    Case SymTab[I].Cat Of
      SC_SCALAR    : CS := 'SCALAR';
      SC_ARRAY_VAR : CS := 'ARRAY ';
      SC_HASH_VAR  : CS := 'HASH  ';
      SC_PARAM     : CS := 'PARAM ';
      SC_FN        : CS := 'FN    ';
      SC_PKG       : CS := 'PKG   ';
      SC_CONST     : CS := 'CONST ';
      SC_FILEHANDLE: CS := 'FILEHD';
    End;
    Write('[', I, '] ', CS, ' ', SymTab[I].SigilName);
    Write(' scope=', SymTab[I].ScopeLevel);
    Write(' ofs=', SymTab[I].Offset);
    If SymTab[I].IsMy    Then Write(' my');
    If SymTab[I].IsOur   Then Write(' our');
    If SymTab[I].IsLocal Then Write(' local');
    WriteLn('  -> ', SymTab[I].MangledName);
  End;
  WriteLn('---');
End;

{ ============================================================
  SYSTEME DE TYPES ET CONTEXTE
  ============================================================ }

{ ---- TypeSizeof : taille en octets d''un type --------------- }
{ Sur 8086 DOS : scalaire = 2 octets (mot 16 bits)             }
{   ref = 2 octets (pointeur near 16 bits)                     }
{   array/hash = 2 octets (pointeur vers bloc memoire)         }
Function TypeSizeof(TypeIdx : Integer) : Integer;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeSizeof := TypeTab[TypeIdx].Size
  Else
    TypeSizeof := 2;  { defaut : 1 mot }
End;

{ ---- TypeMangle : suffixe de type pour les labels ASM ------ }
{ Exemples : TY_IDX_SCALAR -> 'S', TY_IDX_ARRAY -> 'A', ...   }
{ Ces suffixes sont utilises dans les labels de runtime        }
{ _PRRT_CONCAT_S, _PRRT_PUSH_A, etc.                          }
Function TypeMangle(TypeIdx : Integer) : TString;
Begin
  Case TypeIdx Of
    TY_IDX_SCALAR : TypeMangle := 'S';
    TY_IDX_ARRAY  : TypeMangle := 'A';
    TY_IDX_HASH   : TypeMangle := 'H';
    TY_IDX_REF    : TypeMangle := 'R';
    TY_IDX_CODE   : TypeMangle := 'C';
    TY_IDX_UNDEF  : TypeMangle := 'U';
    TY_IDX_MIXED  : TypeMangle := 'M';
  Else
    TypeMangle := 'X';
  End;
End;

{ ---- TypeKindName : nom lisible d''un type (messages, debug) -}
Function TypeKindName(TypeIdx : Integer) : TString;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeKindName := TypeTab[TypeIdx].Name
  Else
    TypeKindName := 'unknown';
End;

{ ---- TypeIsCompatible : deux types sont-ils compatibles ? -- }
{ Regles simplifiees pour 8086 DOS :                           }
{   - UNDEF est compatible avec tout (affectation d''undef)    }
{   - MIXED est compatible avec tout                           }
{   - Meme TypeIdx toujours compatible                         }
{   - SCALAR <-> REF : accepte (pointeur vs entier)            }
{   - Sinon : incompatible -> warning (pas erreur fatale)      }
Function TypeIsCompatible(SrcIdx, DstIdx : Integer) : Boolean;
Begin
  If (SrcIdx = DstIdx) Or
     (SrcIdx = TY_IDX_UNDEF) Or (DstIdx = TY_IDX_UNDEF) Or
     (SrcIdx = TY_IDX_MIXED) Or (DstIdx = TY_IDX_MIXED) Then
  Begin
    TypeIsCompatible := True;
    Exit;
  End;
  { Scalaire <-> Reference : tolere (usage courant en Perl) }
  If ((SrcIdx = TY_IDX_SCALAR) And (DstIdx = TY_IDX_REF)) Or
     ((SrcIdx = TY_IDX_REF)    And (DstIdx = TY_IDX_SCALAR)) Then
  Begin
    TypeIsCompatible := True;
    Exit;
  End;
  TypeIsCompatible := False;
End;

{ ---- ExprIsBoolFalse : tester la faussete d''une expression - }
{ Perl boolean : faux = undef, 0 (entier), "" (chaine vide),   }
{   "0" (chaine contenant zero).                               }
{ Pour les immediats connus a la compilation, on peut           }
{ determiner la valeur booleenne sans emettre de code.         }
{ Retourne True si expr est CERTAINEMENT fausse (EK_IMM=0 ou   }
{ EK_NONE). Pour toute autre valeur -> False (incertain).      }
Function ExprIsBoolFalse(Const E : TExprVal) : Boolean;
Begin
  If E.Kind = EK_NONE Then
    ExprIsBoolFalse := True
  Else If (E.Kind = EK_IMM) And
          ((E.ImmVal = 0) Or (E.TypeIdx = TY_IDX_UNDEF)) Then
    ExprIsBoolFalse := True
  Else
    ExprIsBoolFalse := False;
End;

{ ---- ExprIsBoolTrue : tester la verite certaine a la compile }
{ Retourne True si on sait avec certitude que E est vraie.     }
Function ExprIsBoolTrue(Const E : TExprVal) : Boolean;
Begin
  If (E.Kind = EK_IMM) And
     (E.TypeIdx <> TY_IDX_UNDEF) And
     (E.ImmVal <> 0) Then
    ExprIsBoolTrue := True
  Else
    ExprIsBoolTrue := False;
End;

{ ---- TypeWarn : avertissement de type --------------------- }
Procedure TypeWarn(SrcIdx, DstIdx : Integer);
Begin
  WriteLn('PERL86:', CurToken.Line,
          ': Avertissement: conversion de type ',
          TypeKindName(SrcIdx), ' -> ', TypeKindName(DstIdx));
  Inc(WarnCount);
End;

{ ============================================================
  SEGMENT DE DONNEES ET STATIQUES
  ============================================================ }

{ ---- EmitDataStr : emettre une chaine DB dans le segment DATA }
{ Format : label:         <- ligne du label                     }
{          DB  b,b,...,0  <- octets par tranches de 16          }
{ Caracteres printables (32..126 sauf '') = litteral MASM.      }
{ Autres : valeur decimale.                                     }
{ Le quote simple dans MASM se double : '' -> ''''              }
Procedure EmitDataStr(Const Lbl, S : TString);
Const
  CHUNK = 16;
Var
  I      : Integer;
  C      : Char;
  InQ    : Boolean;
  Line   : TString;
  Tmp    : TString;
  NeedSep: Boolean;
  Count  : Integer;
Begin
  EmitRaw(Lbl + ':');
  I      := 1;
  { Boucle sur tous les octets de S + 1 octet pour le zero final }
  While I <= Length(S) + 1 Do
  Begin
    Line    := '        DB  ';
    InQ     := False;
    NeedSep := False;
    Count   := 0;
    While (Count < CHUNK) And (I <= Length(S) + 1) Do
    Begin
      If I > Length(S) Then
      Begin
        { Zero final : fermer quote si ouverte }
        If InQ Then Begin Line := Line + ''''; InQ := False; End;
        If NeedSep Then Line := Line + ',';
        Line := Line + '0';
        NeedSep := True;
        Inc(I);
      End Else
      Begin
        C := S[I];
        If (Ord(C) >= 32) And (Ord(C) <= 126) And (C <> '''') Then
        Begin
          { Caractere imprimable (sauf quote simple traitee comme non-imprimable) }
          If Not InQ Then
          Begin
            If NeedSep Then Line := Line + ',';
            Line    := Line + '''';
            InQ     := True;
            NeedSep := False;
          End;
          Line := Line + C;
        End Else
        Begin
          { Caractere non imprimable ou quote : valeur decimale }
          If InQ Then Begin Line := Line + ''''; InQ := False; End;
          If NeedSep Then Line := Line + ',';
          Str(Ord(C), Tmp);
          Line    := Line + Tmp;
          NeedSep := True;
        End;
        Inc(I);
      End;
      Inc(Count);
    End;
    If InQ Then Line := Line + '''';
    EmitRaw(Line);
  End;
End;

{ ---- DataAddWord : ajouter une variable globale DK_WORD ----- }
{ Utilise pour : our $var (valeur initiale 0), use constant N.  }
{ Retourne l''indice dans DataTab, ou -1 si sature.              }
Function DataAddWord(Const ALbl : TString; AVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(ALbl, DK_WORD, AVal, '');
End;

{ ---- DataAddConst : constante use constant NOM => val ------- }
{ Si AStr <> '' -> DK_STR ; sinon -> DK_WORD.                  }
Function DataAddConst(Const ALbl : TString; AVal : LongInt;
                      Const AStr : TString) : Integer;
Begin
  If AStr <> '' Then
    DataAddConst := DataAdd(ALbl, DK_STR, 0, AStr)
  Else
    DataAddConst := DataAdd(ALbl, DK_WORD, AVal, '');
End;

{ ---- DataFindByLabel : chercher une entree par son label ---- }
{ Retourne l''indice dans DataTab, ou -1 si introuvable.         }
Function DataFindByLabel(Const ALbl : TString) : Integer;
Var
  I : Integer;
Begin
  DataFindByLabel := -1;
  For I := 0 To DataCount - 1 Do
    If DataTab[I].LblName = ALbl Then
    Begin
      DataFindByLabel := I;
      Exit;
    End;
End;

{ ---- DataDump : affichage de la table de donnees (debug) ---- }
Procedure DataDump;
Var
  I  : Integer;
  KS : TString;
Begin
  WriteLn('--- TABLE DE DONNEES (', DataCount, ' entrees) ---');
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_WORD      : KS := 'DW';
      DK_BYTE      : KS := 'DB';
      DK_STR       : KS := 'STR';
      DK_ARRAY_BLK : KS := 'ARR';
    End;
    Write('[', I, '] ', KS, ' ', DataTab[I].LblName);
    If DataTab[I].Kind = DK_STR Then
      WriteLn(' = "', Copy(DataTab[I].StrVal, 1, 32), '.."')
    Else
    Begin
      WriteLn(' = ', DataTab[I].IntVal);
    End;
  End;
  WriteLn('---');
End;

{ ============================================================
  VARIABLES ET AFFECTATIONS
  ============================================================ }

{ ---- ExprMakeMem : construire EK_MEM pour un symbole ------- }
{ Convention EK_MEM :                                           }
{   ImmVal=1, Offset=n  -> variable locale my/local [BP-n]    }
{   ImmVal=0, Offset=di -> donnee statique DataTab[di]         }
Function ExprMakeMem(SymIdx : Integer) : TExprVal;
Var
  Res : TExprVal;
  Di  : Integer;
Begin
  Res.TypeIdx := SymTab[SymIdx].TypeIdx;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.Kind    := EK_MEM;
  If SymTab[SymIdx].IsMy Or SymTab[SymIdx].IsLocal Then
  Begin
    { Variable locale : acces [BP - Offset] }
    Res.ImmVal := 1;
    Res.Offset := SymTab[SymIdx].Offset;
  End Else
  Begin
    { Variable globale our : dans le segment DATA }
    Di := DataFindByLabel(SymTab[SymIdx].MangledName);
    If Di >= 0 Then
      Res.Offset := Di
    Else
      Res.Offset := 0;   { securite }
  End;
  ExprMakeMem := Res;
End;

{ ---- EmitAllocLocal : allouer des octets sur la pile ------- }
{ Emet SUB SP, Sz pour reserver de l''espace pour une locale.   }
Procedure EmitAllocLocal(Sz : Integer);
Var
  S : TString;
Begin
  Str(Sz, S);
  EmitInstr('SUB', 'SP, ' + S);
End;

{ ---- EmitStoreScalar : stocker AX dans une lvalue ---------- }
{ Si Lv.ImmVal=1 -> MOV WORD PTR [BP-n], AX (locale)          }
{ Si Lv.ImmVal=0 -> MOV [label], AX          (statique)        }
Procedure EmitStoreScalar(Const Lv : TExprVal);
Var
  S : TString;
Begin
  If Lv.Kind <> EK_MEM Then Exit;  { rien a stocker }
  If Lv.ImmVal = 2 Then
  Begin
    { Element tableau dynamique : adresse deja dans BX }
    EmitInstr('MOV', '[BX], AX');
  End Else If Lv.ImmVal = 1 Then
  Begin
    { Variable locale my/local }
    Str(Lv.Offset, S);
    EmitInstr('MOV', 'WORD PTR [BP-' + S + '], AX');
  End Else
  Begin
    { Donnee statique our }
    If (Lv.Offset >= 0) And (Lv.Offset < DataCount) Then
      EmitInstr('MOV', '[' + DataTab[Lv.Offset].LblName + '], AX')
    Else
      EmitComment('EmitStoreScalar: indice DataTab invalide');
  End;
End;

{ ---- ParseVarDecl : declaration my/our/local $var [= expr] - }
{ Ajoute le symbole dans SymTab, emet l''allocation et l''init.  }
Procedure ParseVarDecl;
Var
  Kw        : TString;
  IsMy      : Boolean;
  IsOur     : Boolean;
  IsLoc     : Boolean;
  Sigil     : Char;
  VName     : TString;
  Cat       : TSymCat;
  TIdx      : Integer;
  Idx       : Integer;
  E         : TExprVal;
  Lv        : TExprVal;
  OffS      : TString;
  ElemCount : Integer;
  TmpS      : TString;
  KeyCount  : Integer;
  KeyStr    : TString;
  KeyLbl    : TString;
  SlotIdx   : Integer;
  HKIdx     : Integer;   { indice entrée dans HashKeyTab }
  ParamNames: Array[0..MAX_PARAM - 1] Of TString;
  I         : Integer;   { index de boucle }
  Idx2      : Integer;   { second indice SymTab }
Begin
  Kw    := CurToken.Val;
  IsMy  := Kw = 'my';
  IsOur := Kw = 'our';
  IsLoc := Kw = 'local';
  ParserAdvance;   { consommer 'my'/'our'/'local' }
  { my ($a, $b, ...) = @_ : liste de parametres }
  If (Kw = 'my') And (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance;  { consommer '(' }
    { Collecter les noms de params scalaires }
    Idx := 0;
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
              (CurToken.Kind <> TK_EOF) And (Idx < MAX_PARAM) Do
    Begin
      If CurToken.Kind = TK_SCALAR Then
      Begin
        ParamNames[Idx] := CurToken.Val;
        ParserAdvance;
        Inc(Idx);
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    { Consommer '=' }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
    Begin
      ParserAdvance;
      { Verifier '@_' ou expression liste }
      If CurToken.Kind = TK_ARRAY_SIG Then
      Begin
        If CurToken.Val = '_' Then
        Begin
          { Assignation depuis @_ : [BP+4+(N-1-k)*2] pour param k }
          ParserAdvance;  { consommer '@_' }
          ElemCount := Idx;  { nombre de params }
          For I := 0 To ElemCount - 1 Do
          Begin
            Idx2 := SymAdd(ParamNames[I], '$', SC_SCALAR, TY_IDX_SCALAR, True, False, False);
            EmitAllocLocal(2);
            Str(SymTab[Idx2].Offset, OffS);
            EmitComment('param $' + ParamNames[I] + ' depuis @_[' + ParamNames[I] + ']');
            { arg[k] = [BP + 4 + (N-1-k)*2] avec notre convention push gauche->droite }
            Str(4 + (ElemCount - 1 - I) * 2, TmpS);
            EmitInstr('MOV', 'AX, WORD PTR [BP+' + TmpS + ']');
            EmitInstr('MOV', 'WORD PTR [BP-' + OffS + '], AX');
          End;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
          Exit;
        End;
      End;
      { Fallback : evaluer l''expression liste et ignorer }
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
    Exit;
  End;
  { Determiner le sigil et le type associe }
  If CurToken.Kind = TK_SCALAR Then
  Begin
    Sigil := '$';  Cat := SC_SCALAR;    TIdx := TY_IDX_SCALAR;
  End Else If CurToken.Kind = TK_ARRAY_SIG Then
  Begin
    Sigil := '@';  Cat := SC_ARRAY_VAR; TIdx := TY_IDX_ARRAY;
  End Else If CurToken.Kind = TK_HASH_SIG Then
  Begin
    Sigil := '%';  Cat := SC_HASH_VAR;  TIdx := TY_IDX_HASH;
  End Else
  Begin
    WriteLn('PERL86:', CurToken.Line,
            ': Erreur: variable attendue apres ''', Kw, '''');
    Inc(ErrorCount);
    Exit;
  End;
  VName := CurToken.Val;
  ParserAdvance;   { consommer le nom de variable }
  { Enregistrer dans la table des symboles }
  Idx := SymAdd(VName, Sigil, Cat, TIdx, IsMy, IsOur, IsLoc);
  { Allouer / reserver l''espace selon la portee }
  If IsMy Or IsLoc Then
  Begin
    If Cat = SC_ARRAY_VAR Then
    Begin
      { Tableau @arr : mot de count + MAX_ARR_ELEMS slots de 2 octets }
      EmitAllocLocal(2);   { SymAdd a deja incremente CurFrameSize de 2 }
      Str(SymTab[Idx].Offset, OffS);
      EmitComment('init @' + VName + ' : count=0, ' + OffS + ' slots');
      EmitInstr('MOV', 'WORD PTR [BP-' + OffS + '], 0');
      { Reserver les slots elements : CurFrameSize avance manuellement }
      Inc(CurFrameSize, 2 * MAX_ARR_ELEMS);
      Str(2 * MAX_ARR_ELEMS, TmpS);
      EmitInstr('SUB', 'SP, ' + TmpS);
      { Init optionnelle depuis liste : my @arr = (e1, e2, ...) }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
      Begin
        ParserAdvance;   { consommer '=' }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          ParserAdvance;  { consommer '(' }
        ElemCount := 0;
        While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
                  (CurToken.Kind <> TK_EOF) And
                  (ElemCount < MAX_ARR_ELEMS) Do
        Begin
          ParseExpr(E);
          ExprLoad(E);
          { Stocker AX dans arr[ElemCount] = [BP - (Offset+2 + ElemCount*2)] }
          Str(SymTab[Idx].Offset + 2 + ElemCount * 2, TmpS);
          EmitInstr('MOV', 'WORD PTR [BP-' + TmpS + '], AX');
          Inc(ElemCount);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        { Mettre a jour le count }
        Str(SymTab[Idx].Offset, OffS);
        Str(ElemCount, TmpS);
        EmitInstr('MOV', 'WORD PTR [BP-' + OffS + '], ' + TmpS);
      End;
      Exit;
    End Else If Cat = SC_HASH_VAR Then
    Begin
      { Hash %h : mot de count + MAX_HASH_PAIRS*(key_ptr+val) slots }
      EmitAllocLocal(2);   { CurFrameSize += 2, count word }
      Str(SymTab[Idx].Offset, OffS);
      EmitComment('init %' + VName + ' : count=0, ' + OffS);
      EmitInstr('MOV', 'WORD PTR [BP-' + OffS + '], 0');
      Inc(CurFrameSize, MAX_HASH_PAIRS * 4);
      Str(MAX_HASH_PAIRS * 4, TmpS);
      EmitInstr('SUB', 'SP, ' + TmpS);
      { Init optionnelle : my %h = (cle => val, ...) }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
      Begin
        ParserAdvance;   { consommer '=' }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          ParserAdvance;  { consommer '(' }
        KeyCount := 0;
        While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
                  (CurToken.Kind <> TK_EOF) And
                  (KeyCount < MAX_HASH_PAIRS) Do
        Begin
          { -- Parse cle (bareword, chaine ou scalaire) -- }
          KeyStr := '';
          If (CurToken.Kind = TK_IDENT) Or
             ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val <> 'undef')) Then
          Begin
            KeyStr := CurToken.Val;   { bareword : stringification }
            ParserAdvance;
          End Else If CurToken.Kind = TK_STRING Then
          Begin
            KeyStr := CurToken.Val;
            ParserAdvance;
          End Else
          Begin
            { Cle variable ou complexe : traiter comme expr mais pas stocker }
            ParseExpr(E);
            ExprLoad(E);
            KeyStr := '__var__';
          End;
          { Consommer '=>' ou ',' separant cle et valeur }
          If (CurToken.Kind = TK_OP) And (CurToken.Val = '=>') Then
            ParserAdvance
          Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          { -- Parse valeur -- }
          ParseExpr(E);
          ExprLoad(E);   { AX = valeur }
          { -- Enregistrer la paire cle/valeur -- }
          If KeyStr <> '__var__' Then
          Begin
            SlotIdx := -1;
            HKIdx   := HashSlotFind(Idx, KeyStr);
            If HKIdx < 0 Then
            Begin
              { Ajouter la cle dans DATA }
              ElemCount := DataAddStr(KeyStr);
              KeyLbl    := DataTab[ElemCount].LblName;
              SlotIdx   := HashSlotAdd(Idx, KeyStr, KeyLbl);
            End Else
            Begin
              SlotIdx := HashKeyTab[HKIdx].SlotIdx;
              KeyLbl  := HashKeyTab[HKIdx].KeyLbl;
            End;
            { key_ptr[SlotIdx] = OFFSET KeyLbl }
            Str(SymTab[Idx].Offset + 2 + SlotIdx * 4, TmpS);
            EmitInstr('MOV', 'WORD PTR [BP-' + TmpS + '], OFFSET ' + KeyLbl);
            { val[SlotIdx] = AX }
            Str(SymTab[Idx].Offset + 4 + SlotIdx * 4, TmpS);
            EmitInstr('MOV', 'WORD PTR [BP-' + TmpS + '], AX');
          End;
          Inc(KeyCount);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        { Mettre a jour count }
        Str(SymTab[Idx].Offset, OffS);
        Str(KeyCount, TmpS);
        EmitInstr('MOV', 'WORD PTR [BP-' + OffS + '], ' + TmpS);
      End;
      Exit;
    End Else
    Begin
      { Variable scalaire : SymAdd a incremente CurFrameSize, emet SUB SP, 2 }
      EmitAllocLocal(2);
      Str(SymTab[Idx].Offset, OffS);
      EmitComment('init my ' + Sigil + VName);
      EmitInstr('MOV', 'WORD PTR [BP-' + OffS + '], 0');
    End;
  End Else If IsOur Then
  Begin
    { Variable globale : reservee dans _DATA }
    DataAddWord(SymTab[Idx].MangledName, 0);
    EmitComment('our ' + Sigil + VName + ' dans _DATA');
  End;
  { Affectation initiale optionnelle : my $x = expr }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
  Begin
    ParserAdvance;   { consommer ''='' }
    ParseExpr(E);
    ExprLoad(E);
    { Stocker AX dans la variable nouvellement declaree }
    Lv := ExprMakeMem(Idx);
    EmitStoreScalar(Lv);
  End;
End;

{ ============================================================
  EXPRESSIONS PRIMAIRES
  ============================================================ }

{ ---- ParseCallArgs : evaluer + empiler les arguments -------- }
{ Parse ''('' expr, expr, ... '')'' ; empile chaque arg en AX.   }
{ Retourne le nombre d''arguments empiles dans N (var globale).  }
Procedure ParseCallArgs;
Var
  A    : TExprVal;
  ArgN : Integer;
Begin
  ArgN := 0;
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
  Begin GCallArgCount := 0; Exit; End;
  ParserAdvance;   { consommer '(' }
  While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
        (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseExpr(A);
    ExprLoad(A);
    EmitInstr1('PUSH AX');
    Inc(ArgN);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance
    Else
      Break;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance
  Else
  Begin
    WriteLn('PERL86:', CurToken.Line, ': Erreur: '')'' attendu dans appel');
    Inc(ErrorCount);
  End;
  GCallArgCount := ArgN;
End;

{ ---- EmitIncrDecr : ++ ou -- avec effet de bord ------------ }
{ Pre=True  -> pre  : inc d''abord, puis charge AX dans Res     }
{ Pre=False -> post : charge AX d''abord, puis inc dans memoire  }
Procedure EmitIncrDecr(Const Lv : TExprVal; IsInc : Boolean; Pre : Boolean;
                       Var Res : TExprVal);
Var
  S      : TString;
  Addr   : TString;
  LvKind : TExprKind;   { copie locale : Lv et Res peuvent etre aliases }
  LvImmV : LongInt;
  LvOff  : Integer;
Begin
  { Copier les champs de Lv avant de toucher a Res (aliasing possible) }
  LvKind := Lv.Kind;
  LvImmV := Lv.ImmVal;
  LvOff  := Lv.Offset;
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_SCALAR;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  If LvKind <> EK_MEM Then
  Begin
    EmitComment('++ / -- sur non-lvalue : ignore');
    EmitInstr('MOV', 'AX, 0');
    Exit;
  End;
  If LvImmV = 1 Then
  Begin
    Str(LvOff, S);
    Addr := 'WORD PTR [BP-' + S + ']';
  End Else
  Begin
    If (LvOff >= 0) And (LvOff < DataCount) Then
      Addr := 'WORD PTR [' + DataTab[LvOff].LblName + ']'
    Else
    Begin
      EmitComment('++ / -- : indice DataTab invalide');
      EmitInstr('MOV', 'AX, 0');
      Exit;
    End;
  End;
  If Pre Then
  Begin
    If IsInc Then EmitInstr('INC', Addr)
    Else          EmitInstr('DEC', Addr);
    EmitInstr('MOV', 'AX, ' + Addr);
  End Else
  Begin
    EmitInstr('MOV', 'AX, ' + Addr);
    If IsInc Then EmitInstr('INC', Addr)
    Else          EmitInstr('DEC', Addr);
  End;
End;

{ ---- ParsePostfixOps : operateurs postfixe apres une primaire }
{ Boucle sur post-++ post-- .                                    }
Procedure ParsePostfixOps(Var Res : TExprVal);
Var
  ArgCnt : Integer;
  S      : TString;
  Sub    : TExprVal;   { expression d''index pour ->[] }
Begin
  Repeat
    If CurToken.Kind = TK_OP Then
    Begin
      If CurToken.Val = '++' Then
      Begin ParserAdvance; EmitIncrDecr(Res, True,  False, Res); Continue; End;
      If CurToken.Val = '--' Then
      Begin ParserAdvance; EmitIncrDecr(Res, False, False, Res); Continue; End;
      { operateur fleche -> }
      If CurToken.Val = '->' Then
      Begin
        ParserAdvance;  { consommer '->' }
        { $ref->() : appel via coderef }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ExprLoad(Res);
          EmitInstr('MOV', 'BX, AX');
          ParseCallArgs;
          ArgCnt := GCallArgCount;
          EmitInstr('CALL', 'BX');
          If ArgCnt > 0 Then
          Begin Str(ArgCnt * 2, S); EmitInstr('ADD', 'SP, ' + S); End;
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
          Res.ImmVal := 0; Res.Offset := 0;
          Continue;
        End;
        { $ref->[$i] : acces element tableau reference }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
        Begin
          ExprLoad(Res);               { AX = ptr vers tableau }
          EmitInstr('MOV', 'BX, AX'); { BX = base du tableau  }
          ParserAdvance;               { consommer '[' }
          ParseExpr(Sub);
          ExprLoad(Sub);               { AX = index }
          EmitInstr('SHL', 'AX, 1');   { AX = idx * 2 }
          EmitInstr('ADD', 'AX, 2');   { +2 pour sauter le count }
          EmitInstr('MOV', 'SI, AX');
          EmitInstr('MOV', 'AX, [BX+SI]'); { element du tableau }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then ParserAdvance;
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
          Res.ImmVal := 0; Res.Offset := 0;
          Continue;
        End;
        { ref-fleche-cle : acces element hash reference (stub) }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
        Begin
          ParserAdvance;  { consommer '{' }
          If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_STRING) Or
             (CurToken.Kind = TK_SCALAR) Then
            ParserAdvance;  { ignorer la cle }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then ParserAdvance;
          EmitComment('$ref->{key}: dereferencement hash (stub)');
          EmitInstr('XOR', 'AX, AX');
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
          Res.ImmVal := 0; Res.Offset := 0;
          Continue;
        End;
      End;
    End;
    Break;
  Until False;
End;

{ ============================================================
  PRINT / SAY / PRINTF / WARN / DIE
  ============================================================ }

{ ---- EmitPrintVal : emet AX ou chaine statique sur handle -- }
{ BXval = '1' (STDOUT), '2' (STDERR), '0' (STDIN)             }
{ Chaine statique DK_STR -> MOV SI,OFFSET lbl + _PRRT_STRLEN  }
{ Sinon : ExprLoad -> AX puis _PRRT_ITOA + _PRRT_STRLEN        }
Procedure EmitPrintVal(Const BXval : TString; Var E : TExprVal);
Var
  DidStr : Boolean;
  Idx    : Integer;
Begin
  DidStr := False;
  { Chaine statique dans DataTab }
  If (E.Kind = EK_MEM) And (E.ImmVal = 0) Then
  Begin
    Idx := E.Offset;
    If (Idx >= 0) And (Idx < DataCount) And (DataTab[Idx].Kind = DK_STR) Then
    Begin
      EmitInstr('MOV', 'SI, OFFSET ' + DataTab[Idx].LblName);
      EmitInstr('CALL', '_PRRT_STRLEN');
      EmitInstr('MOV', 'CX, AX');
      EmitInstr('MOV', 'BX, ' + BXval);
      EmitInstr('CALL', '_PRRT_PRINT');
      DidStr := True;
    End;
  End;
  If Not DidStr Then
  Begin
    { Valeur entiere : charger AX puis convertir via _PRRT_ITOA }
    ExprLoad(E);
    { S'assurer que le buffer ITOA est dans DataTab }
    If DataFindByLabel('_PRRT_IBUF') < 0 Then
    Begin
      Idx := DataAdd('_PRRT_IBUF', DK_ARRAY_BLK, 0, '');
      If Idx >= 0 Then DataTab[Idx].ElemCount := 8;  { 8 DW = 16 octets }
    End;
    EmitInstr('MOV', 'DI, OFFSET _PRRT_IBUF');
    EmitInstr('CALL', '_PRRT_ITOA');
    EmitInstr('MOV', 'SI, DI');
    EmitInstr('CALL', '_PRRT_STRLEN');
    EmitInstr('MOV', 'CX, AX');
    EmitInstr('MOV', 'BX, ' + BXval);
    EmitInstr('CALL', '_PRRT_PRINT');
  End;
End;

{ ---- ParsePrintStmt : print / say / printf / warn / die --- }
{ CurToken.Val = le mot-cle. Le consomme puis parse la liste.  }
Procedure ParsePrintStmt;
Var
  KW    : TString;
  BXval : TString;
  IsSay : Boolean;
  IsDie : Boolean;
  E     : TExprVal;
  FhIdx : Integer;
  FhOfs : TString;
Begin
  KW    := CurToken.Val;
  ParserAdvance;                            { consommer le mot-cle }
  BXval := '1';                             { STDOUT par defaut }
  IsSay := (KW = 'say');
  IsDie := (KW = 'die');
  If (KW = 'warn') Or IsDie Then BXval := '2';  { STDERR }
  { Filehandle explicite : STDOUT / STDERR / STDIN (TK_IDENT ou TK_FILEHANDLE) }
  If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_FILEHANDLE) Then
  Begin
    If      CurToken.Val = 'STDOUT' Then Begin BXval := '1'; ParserAdvance; End
    Else If CurToken.Val = 'STDERR' Then Begin BXval := '2'; ParserAdvance; End
    Else If CurToken.Val = 'STDIN'  Then Begin BXval := '0'; ParserAdvance; End;
    { Sinon : identifiant inconnu -> traiter comme premiere expression }
  End;
  { print $fh, LIST -> filehandle scalaire (SC_FILEHANDLE uniquement) }
  If CurToken.Kind = TK_SCALAR Then
  Begin
    FhIdx := SymFindCat(CurToken.Val, SC_FILEHANDLE);
    { Pas de fallback SymFind : seuls les vrais filehandles sont detectes ici }
    If FhIdx >= 0 Then
    Begin
      Str(SymTab[FhIdx].Offset, FhOfs);
      BXval := 'WORD PTR [BP-' + FhOfs + ']';
      ParserAdvance;  { consommer $fh }
      { Consommer ',' separant $fh de la liste }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then ParserAdvance;
    End;
  End;
  { printf : note dans le commentaire ASM }
  If KW = 'printf' Then
    EmitComment('printf : format interprete simple');
  { Evaluer et imprimer chaque argument de la liste }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) And
         (CurToken.Kind <> TK_EOF) Then
  Begin
    ParseExpr(E);
    EmitPrintVal(BXval, E);
    While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then Break;
      If CurToken.Kind = TK_EOF Then Break;
      ParseExpr(E);
      EmitPrintVal(BXval, E);
    End;
  End;
  { say : saut de ligne final via _PRRT_PRINTLN }
  If IsSay Then
  Begin
    EmitInstr('MOV', 'BX, ' + BXval);
    EmitInstr('CALL', '_PRRT_PRINTLN');
  End;
  { die : terminer le programme avec code 255 }
  If IsDie Then
  Begin
    EmitInstr('MOV', 'AX, 4CFFh');
    EmitInstr('INT', '21h');
  End;
  { Consommer le '';'' de fin de statement }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

{ ============================================================
  IF / ELSIF / ELSE / UNLESS + MODIFICATEURS DE STATEMENT
  ============================================================ }

{ ---- ParseBlock : parse un bloc de stmts avec portee lexicale ---- }
{ restaurer SP a la fin du bloc si des locaux ont ete alloues }
Procedure ParseBlock;
Var
  SaveFrameSz : Integer;   { taille cadre avant ce bloc }
  Delta       : Integer;   { octets alloues dans ce bloc }
  DeltaS      : TString;
Begin
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{')) Then
  Begin
    WriteLn('PERL86:', CurToken.Line,
            ': Erreur: ''{'' attendu pour bloc, obtenu ''', CurToken.Val, '''');
    Inc(ErrorCount);
    Exit;
  End;
  ParserAdvance;   { consommer '{' }
  SaveFrameSz := CurFrameSize;   { sauver taille cadre avant les locaux du bloc }
  SymEnterScope;
  While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) And
            (CurToken.Kind <> TK_EOF) Do
    ParseStmt;
  SymLeaveScope;
  { liberer les locaux alloues dans ce bloc (sauf dans l''epilogue sub) }
  If (CurFnDepth > 0) And (CurFrameSize > SaveFrameSz) Then
  Begin
    Delta := CurFrameSize - SaveFrameSz;
    Str(Delta, DeltaS);
    EmitInstr('ADD', 'SP, ' + DeltaS);   { restaurer SP }
    CurFrameSize := SaveFrameSz;          { mettre a jour le traqueur }
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance;  { consommer accolade fermante }
End;

{ ---- ParseIfStmt : if/unless/elsif/else ------------------- }
{ if (cond) BLOC [elsif (cond) BLOC]* [else BLOC]             }
{ unless (cond) BLOC [else BLOC]  (condition inversee)        }
Procedure ParseIfStmt;
Var
  KW       : TString;
  IsUnless : Boolean;
  LblNext  : TString;
  LblEnd   : TString;
  Cond     : TExprVal;
Begin
  KW       := CurToken.Val;   { 'if' ou 'unless' }
  IsUnless := (KW = 'unless');
  ParserAdvance;               { consommer 'if' ou 'unless' }
  LblEnd  := LabelGen('_PRL_ENDIF_');
  LblNext := LabelGen('_PRL_ELSE_');
  { Evaluer la condition (parentheses optionnelles) }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
  ParseExpr(Cond);
  ExprLoad(Cond);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
  EmitInstr('TEST', 'AX, AX');
  If IsUnless Then
    EmitInstr('JNZ', LblNext)  { unless: sauter vers else/fin si VRAI }
  Else
    EmitInstr('JZ', LblNext);  { if: sauter vers else/fin si FAUX }
  { Bloc then }
  ParseBlock;
  { Chaines elsif }
  While (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'elsif') Do
  Begin
    EmitInstr('JMP', LblEnd);
    EmitLabel(LblNext);
    LblNext := LabelGen('_PRL_ELSE_');
    ParserAdvance;  { consommer 'elsif' }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
    ParseExpr(Cond);
    ExprLoad(Cond);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('JZ', LblNext);
    ParseBlock;
  End;
  { Saut vers la fin + etiquette de la branche suivante/else }
  EmitInstr('JMP', LblEnd);
  EmitLabel(LblNext);
  { Bloc else optionnel }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'else') Then
  Begin
    ParserAdvance;  { consommer 'else' }
    ParseBlock;
  End;
  EmitLabel(LblEnd);
End;

{ ============================================================
  BOUCLES : while / until / for / foreach / do
  ============================================================ }

{ ---- LoopPush / LoopPop : gestion de la pile de boucles --- }
Procedure LoopPush(Const BrkLbl, ContLbl, RedoLbl : TString);
Begin
  If LoopTop >= MAX_LOOP_NEST Then
  Begin
    WriteLn('PERL86: Erreur: Boucles trop imbriquees (max=', MAX_LOOP_NEST, ')');
    Inc(ErrorCount);
    Exit;
  End;
  LoopBreakLbl[LoopTop] := BrkLbl;
  LoopContLbl[LoopTop]  := ContLbl;
  LoopRedoLbl[LoopTop]  := RedoLbl;
  Inc(LoopTop);
End;

Procedure LoopPop;Begin
  If LoopTop > 0 Then Dec(LoopTop);
End;

{ ---- ParseWhileStmt : while/until (cond) BLOC [continue BL] }
{ CurToken.Val = 'while' ou 'until'                            }
Procedure ParseWhileStmt;
Var
  IsUntil : Boolean;
  LblTop  : TString;
  LblEnd  : TString;
  LblCont : TString;
  Cond    : TExprVal;
Begin
  IsUntil := (CurToken.Val = 'until');
  ParserAdvance;  { consommer 'while'/'until' }
  LblTop  := LabelGen('_PRL_WTOP_');
  LblEnd  := LabelGen('_PRL_WEND_');
  LblCont := LabelGen('_PRL_WCNT_');
  LoopPush(LblEnd, LblCont, LblTop);
  EmitLabel(LblTop);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
  ParseExpr(Cond);
  ExprLoad(Cond);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
  EmitInstr('TEST', 'AX, AX');
  If IsUntil Then
    EmitInstr('JNZ', LblEnd)   { until: sortir si VRAI }
  Else
    EmitInstr('JZ', LblEnd);   { while: sortir si FAUX }
  ParseBlock;
  { bloc continue (optionnel) }
  EmitLabel(LblCont);
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'continue') Then
  Begin
    ParserAdvance;
    ParseBlock;
  End;
  EmitInstr('JMP', LblTop);
  EmitLabel(LblEnd);
  LoopPop;
End;

{ ---- ParseForStmt : for (init; cond; incr) BLOC (style C) -- }
Procedure ParseForStmt;
Var
  LblTop  : TString;
  LblEnd  : TString;
  LblIncr : TString;
  Cond    : TExprVal;
  Dummy   : TExprVal;
Begin
  If Not GKwConsumed Then ParserAdvance;  { consommer 'for' }
  GKwConsumed := False;
  LblTop  := LabelGen('_PRL_FTOP_');
  LblEnd  := LabelGen('_PRL_FEND_');
  LblIncr := LabelGen('_PRL_FINCR_');
  LoopPush(LblEnd, LblIncr, LblTop);
  { Parenthese ouvrante }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
  { Init : my $i = expr ; ou expr ; ou juste ; }
  If (CurToken.Kind = TK_KEYWORD) And
     ((CurToken.Val = 'my') Or (CurToken.Val = 'our')) Then
    ParseVarDecl
  Else If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Then
  Begin
    ParseExpr(Dummy);
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
  { Test de condition }
  EmitLabel(LblTop);
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Then
  Begin
    ParseExpr(Cond);
    ExprLoad(Cond);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('JZ', LblEnd);
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
  { Sauvegarder l'expression d'incrementation a la fin du bloc }
  { On emet un JMP vers le corps, puis l'increment, puis JMP LblTop }
  { Structure : LblTop; [cond]; JZ LblEnd; JMP LblBody; }
  {             LblIncr: [incr]; JMP LblTop; }
  {             LblBody: [bloc]; JMP LblIncr; LblEnd: }
  { Simple : on place l'increment dans le "continue" }
  { Pour simplifier : on emmet l'increment inline apres le corps }
  { via goto LblIncr apres le bloc, LblIncr: [incr] JMP LblTop }
  { On doit lire l'expr incr maintenant et la "stocker" - impossible }
  { Solution : lire et ignorer l'incr sur le plan textuel est mauvais }
  { On emet: JMP LblBody; LblIncr: [incr]; JMP LblTop; LblBody: [bloc]; JMP LblIncr }
  EmitInstr('JMP', '_PRL_FBOD_' + Copy(LblTop, 10, 20));
  EmitLabel(LblIncr);
  { Lire l'expression d'incrementation }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
    ParseExpr(Dummy);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
  EmitInstr('JMP', LblTop);
  EmitLabel('_PRL_FBOD_' + Copy(LblTop, 10, 20));
  ParseBlock;
  EmitInstr('JMP', LblIncr);
  EmitLabel(LblEnd);
  LoopPop;
End;

{ ---- ParseForeachStmt : foreach [my $var] (LIST) BLOC ------- }
Procedure ParseForeachStmt;
Var
  VarName    : TString;
  SymIdx     : Integer;
  LblTop     : TString;
  LblEnd     : TString;
  LblCont    : TString;
  ListLbl    : TString;
  CntLbl     : TString;
  IdxLbl     : TString;
  E          : TExprVal;
  HasVar     : Boolean;
  RangeStart : TExprVal;
  RangeEnd   : TExprVal;
  IsRange    : Boolean;
  DummyE     : TExprVal;
Begin
  If Not GKwConsumed Then ParserAdvance;  { consommer 'foreach'/'for' }
  GKwConsumed := False;
  LblTop  := LabelGen('_PRL_EITOP_');
  LblEnd  := LabelGen('_PRL_EIEND_');
  LblCont := LabelGen('_PRL_EICNT_');
  HasVar  := False;
  IsRange := False;
  SymIdx  := -1;
  VarName := '_';
  { Variable d'iteration optionnelle : my $var }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'my') Then
  Begin
    ParserAdvance;  { consommer 'my' }
    If CurToken.Kind = TK_SCALAR Then
    Begin
      VarName := CurToken.Val;
      ParserAdvance;
      SymIdx := SymAdd(VarName, '$', SC_SCALAR, TY_IDX_SCALAR,
                       True, False, False);
      If SymIdx >= 0 Then EmitAllocLocal(2);
      HasVar := True;
    End;
  End;
  LoopPush(LblEnd, LblCont, LblTop);
  { Parenthese ouvrante }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
  { Detecter plage A..B }
  ParseExpr(RangeStart);
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '..') Then
  Begin
    IsRange := True;
    ParserAdvance;  { consommer '..' }
    ParseExpr(RangeEnd);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    { Allouer compteur de boucle sur la pile }
    CntLbl := LabelGen('_PRL_FECNT_');
    { Chargement de la valeur de debut dans $var et le compteur }
    ExprLoad(RangeStart);
    If HasVar And (SymIdx >= 0) Then
    Begin
      Str(SymTab[SymIdx].Offset, CntLbl);
      EmitInstr('MOV', 'WORD PTR [BP-' + CntLbl + '], AX');
    End;
    EmitLabel(LblTop);
    { Test : compteur <= fin }
    If HasVar And (SymIdx >= 0) Then
    Begin
      Str(SymTab[SymIdx].Offset, CntLbl);
      EmitInstr('MOV', 'AX, WORD PTR [BP-' + CntLbl + ']');
    End Else
      EmitInstr('MOV', 'AX, 0');
    ExprLoad(RangeEnd);
    EmitInstr('XCHG', 'AX, BX');
    EmitInstr('MOV', 'AX, BX');
    { BX = courant, AX charge RangeEnd - on veut courant <= fin }
    { En fait: charger courant dans BX, fin dans AX }
    If HasVar And (SymIdx >= 0) Then
    Begin
      Str(SymTab[SymIdx].Offset, CntLbl);
      EmitInstr('MOV', 'BX, WORD PTR [BP-' + CntLbl + ']');
      ExprLoad(RangeEnd);
    End Else
      EmitInstr('MOV', 'BX, 0');
    EmitInstr('CMP', 'BX, AX');
    EmitInstr('JG', LblEnd);
    LoopPush(LblEnd, LblCont, LblTop);
    ParseBlock;
    EmitLabel(LblCont);
    { Incrementer $var }
    If HasVar And (SymIdx >= 0) Then
    Begin
      Str(SymTab[SymIdx].Offset, CntLbl);
      EmitInstr('INC', 'WORD PTR [BP-' + CntLbl + ']');
    End;
    EmitInstr('JMP', LblTop);
    EmitLabel(LblEnd);
    LoopPop;
  End Else
  Begin
    { Liste simple : foreach (expr, ...) }
    { Allocation : compteur d'index dans DATA }
    IdxLbl  := LabelGen('_PRL_FEIDX_');
    ListLbl := IdxLbl;
    { Evaluer et imprimer la premiere expr  }
    ExprLoad(RangeStart);
    If HasVar And (SymIdx >= 0) Then
    Begin
      Str(SymTab[SymIdx].Offset, CntLbl);
      EmitInstr('MOV', 'WORD PTR [BP-' + CntLbl + '], AX');
    End;
    { Consommer le reste de la liste silencieusement }
    While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
    Begin
      ParserAdvance;
      ParseExpr(DummyE);
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    { Boucle simplifiee : une seule iteration (limitation) }
    EmitComment('foreach: boucle simplifiee (liste literale 1 iteration)');
    LoopPush(LblEnd, LblCont, LblTop);
    EmitLabel(LblTop);
    ParseBlock;
    EmitLabel(LblCont);
    EmitLabel(LblEnd);
    LoopPop;
  End;
  LoopPop;
End;

{ ---- ParseDoStmt : do BLOC [while/until cond]  --------------- }
Procedure ParseDoStmt;
Var
  LblTop  : TString;
  LblEnd  : TString;
  LblCont : TString;
  Cond    : TExprVal;
  HasLoop : Boolean;
  IsUntil : Boolean;
Begin
  ParserAdvance;  { consommer 'do' }
  { do 'fichier.pl' -> non pris en charge }
  If CurToken.Kind = TK_STRING Then
  Begin
    WriteLn('PERL86:', CurToken.Line, ': Avert: do ''',
            CurToken.Val, ''' non pris en charge');
    Inc(WarnCount);
    ParserAdvance;
    EmitInstr('XOR', 'AX, AX');   { retourner 0 }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
    Exit;
  End;
  LblTop  := LabelGen('_PRL_DOTOP_');
  LblEnd  := LabelGen('_PRL_DOEND_');
  LblCont := LabelGen('_PRL_DOCNT_');
  HasLoop := False;
  IsUntil := False;
  LoopPush(LblEnd, LblCont, LblTop);
  EmitLabel(LblTop);
  ParseBlock;
  EmitLabel(LblCont);
  { do BLOC while/until cond }
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    If (CurToken.Val = 'while') Or (CurToken.Val = 'until') Then
    Begin
      IsUntil := (CurToken.Val = 'until');
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      ParseExpr(Cond);
      ExprLoad(Cond);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      EmitInstr('TEST', 'AX, AX');
      If IsUntil Then
        EmitInstr('JZ', LblTop)    { until: reboucler si FAUX }
      Else
        EmitInstr('JNZ', LblTop);  { while: reboucler si VRAI }
      HasLoop := True;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
    End;
  End;
  If Not HasLoop Then
  Begin
    { do BLOC seul (pas de while/until) : executer une fois }
    EmitComment('do BLOC : execution unique');
  End;
  EmitLabel(LblEnd);
  LoopPop;
End;

{ ============================================================
  TABLEAUX @arr
  ============================================================ }

{ ---- ParseArrElemAccess : $arr[idx] -> TExprVal lvalue ----- }
{ ArrIdx = indice dans SymTab de @arr.                         }
{ Layout pile : [BP-Offset]=count, [BP-Offset-2]=elem[0], ... }
{ Pour idx constant (EK_IMM), Res = EK_MEM ImmVal=1 direct.   }
{ Pour idx variable, adresse calculee dans BX : EK_MEM ImmVal=2 }
Procedure ParseArrElemAccess(ArrIdx : Integer; Var Res : TExprVal);
Var
  IdxE    : TExprVal;
  ElemOff : LongInt;
  S       : TString;
  BaseOff : Integer;
Begin
  ParserAdvance;  { consommer '[' }
  ParseExpr(IdxE);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
    ParserAdvance;
  BaseOff := SymTab[ArrIdx].Offset;
  If IdxE.Kind = EK_IMM Then
  Begin
    { Index constant : acces direct [BP - (BaseOff+2 + idx*2)] }
    ElemOff := BaseOff + 2 + IdxE.ImmVal * 2;
    Str(ElemOff, S);
    Res.Kind    := EK_MEM;
    Res.ImmVal  := 1;
    Res.Offset  := ElemOff;
    Res.TypeIdx := TY_IDX_SCALAR;
  End Else
  Begin
    { Index dynamique : calculer adresse dans BX }
    ExprLoad(IdxE);      { AX = index }
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('SHL', 'SI, 1');         { SI = idx * 2 }
    Str(BaseOff + 2, S);
    EmitInstr('ADD', 'SI, ' + S);      { SI = offset base elements + idx*2 }
    EmitInstr('MOV', 'BX, BP');
    EmitInstr('SUB', 'BX, SI');        { BX = &arr[idx] }
    Res.Kind    := EK_MEM;
    Res.ImmVal  := 2;
    Res.Offset  := 0;
    Res.TypeIdx := TY_IDX_SCALAR;
  End;
End;

{ ---- ParseArrBuiltin : push / pop / shift / unshift @arr -- }
{ push  @arr, val => ajouter val a la fin, incr count         }
{ pop   @arr      => retirer dernier elem dans AX, decr count }
{ shift @arr      => retirer premier elem dans AX, decr count }
{ unshift @arr, val => inserer val au debut, incr count       }
Procedure ParseArrBuiltin(IsStmt : Boolean);
Var
  KW     : TString;
  ArrIdx : Integer;
  E      : TExprVal;
  OffS   : TString;
  BaseS  : TString;
  I      : Integer;
  IS     : TString;
Begin
  KW := CurToken.Val;
  ParserAdvance;  { consommer le keyword }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    ParserAdvance;
  { Identifier @arr }
  ArrIdx := -1;
  If CurToken.Kind = TK_ARRAY_SIG Then
  Begin
    ArrIdx := SymFindCat(CurToken.Val, SC_ARRAY_VAR);
    ParserAdvance;
  End;
  If KW = 'push' Then
  Begin
    { push @arr, val }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;    ParseExpr(E);
    ExprLoad(E);  { AX = valeur a pousser }
    If ArrIdx >= 0 Then
    Begin
      Str(SymTab[ArrIdx].Offset, OffS);
      Str(SymTab[ArrIdx].Offset + 2, BaseS);
      EmitComment('push @arr');
      EmitInstr('MOV', 'CX, WORD PTR [BP-' + OffS + ']');  { CX = count }
      EmitInstr('MOV', 'SI, CX');
      EmitInstr('SHL', 'SI, 1');          { SI = count*2 }
      EmitInstr('ADD', 'SI, ' + BaseS);   { SI = offset de arr[count] }
      EmitInstr('MOV', 'BX, BP');
      EmitInstr('SUB', 'BX, SI');         { BX = &arr[count] }
      EmitInstr('MOV', '[BX], AX');       { arr[count] = val }
      EmitInstr('INC', 'WORD PTR [BP-' + OffS + ']');  { count++ }
    End;
  End Else If KW = 'pop' Then
  Begin
    { pop @arr : retourne dernier element dans AX }
    If ArrIdx >= 0 Then
    Begin
      Str(SymTab[ArrIdx].Offset, OffS);
      Str(SymTab[ArrIdx].Offset + 2, BaseS);
      EmitComment('pop @arr');
      EmitInstr('MOV', 'CX, WORD PTR [BP-' + OffS + ']');  { CX = count }
      EmitInstr('DEC', 'CX');             { CX = last idx }
      EmitInstr('DEC', 'WORD PTR [BP-' + OffS + ']');  { count-- }
      EmitInstr('MOV', 'SI, CX');
      EmitInstr('SHL', 'SI, 1');
      EmitInstr('ADD', 'SI, ' + BaseS);
      EmitInstr('MOV', 'BX, BP');
      EmitInstr('SUB', 'BX, SI');
      EmitInstr('MOV', 'AX, [BX]');      { AX = valeur retournee }
    End Else
      EmitInstr('MOV', 'AX, 0');
  End Else If KW = 'shift' Then
  Begin
    { shift @arr : retirer et retourner premier element, decaler }
    If ArrIdx >= 0 Then
    Begin
      Str(SymTab[ArrIdx].Offset, OffS);
      Str(SymTab[ArrIdx].Offset + 2, BaseS);
      EmitComment('shift @arr');
      { Sauvegarder arr[0] dans AX }
      Str(SymTab[ArrIdx].Offset + 2, IS);
      EmitInstr('MOV', 'AX, WORD PTR [BP-' + IS + ']');
      EmitInstr('PUSH', 'AX');  { sauver valeur retournee }
      { Decaler arr[1..n-1] vers arr[0..n-2] via boucle }
      EmitInstr('MOV', 'CX, WORD PTR [BP-' + OffS + ']');
      EmitInstr('DEC', 'CX');   { CX = count-1 (nombre d''elements a decaler) }
      EmitInstr('JCXZ', '_PRL_SHFTE_' + OffS);
      EmitLabel('_PRL_SHFTS_' + OffS);
      { BX = &arr[1] initialement -> avancer }
      EmitInstr('MOV', 'SI, ' + BaseS);
      EmitInstr('MOV', 'BX, BP');
      EmitInstr('SUB', 'BX, SI');     { BX = &arr[0] }
      EmitInstr('MOV', 'DI, SI');
      EmitInstr('SUB', 'DI, 2');      { DI = offset arr[1] }
      EmitInstr('MOV', 'DX, BP');
      EmitInstr('SUB', 'DX, DI');     { DX = &arr[1] = src }
      EmitInstr('MOV', 'AX, [DX]');
      EmitInstr('MOV', '[BX], AX');
      EmitLabel('_PRL_SHFTE_' + OffS);
      EmitInstr('DEC', 'WORD PTR [BP-' + OffS + ']');
      EmitInstr('POP', 'AX');
    End Else If CurFnDepth > 0 Then
    Begin
      { shift sans @arr explicite dans un sub -> shift @_ }
      { Convention push gauche->droite : arg0=[BP+4+(N-1)*2], arg1=[BP+4+(N-2)*2] }
      { CurArgShiftIdx 0 = dernier argument pousse = [BP+4] }
      Str(4 + CurArgShiftIdx * 2, OffS);
      EmitComment('shift @_[' + OffS + ']');
      EmitInstr('MOV', 'AX, WORD PTR [BP+' + OffS + ']');
      Inc(CurArgShiftIdx);
    End Else
      EmitInstr('MOV', 'AX, 0');
  End Else If KW = 'unshift' Then
  Begin
    { unshift @arr, val : inserer val en tete }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;
    ParseExpr(E);
    ExprLoad(E);
    If ArrIdx >= 0 Then
    Begin
      Str(SymTab[ArrIdx].Offset, OffS);
      Str(SymTab[ArrIdx].Offset + 2, BaseS);
      EmitComment('unshift @arr');
      { Incr count d''abord }
      EmitInstr('INC', 'WORD PTR [BP-' + OffS + ']');
      { Stocker val dans arr[0] }
      Str(SymTab[ArrIdx].Offset + 2, IS);
      EmitInstr('MOV', 'WORD PTR [BP-' + IS + '], AX');
    End;
  End;
End;  { ParseArrBuiltin }

{ ---- HashSlotFind : chercher une cle dans HashKeyTab ------- }
{ Retourne l''indice de l''entree dans HashKeyTab, ou -1.       }
Function HashSlotFind(HashSym : Integer; Const Key : TString) : Integer;
Var
  I : Integer;
Begin
  HashSlotFind := -1;
  For I := 0 To HashKeyCount - 1 Do
    If (HashKeyTab[I].HashSym = HashSym) And (HashKeyTab[I].KeyStr = Key) Then
    Begin
      HashSlotFind := I;
      Exit;
    End;
End;

{ ---- HashSlotAdd : ajouter une nouvelle cle dans le hash --- }
{ Retourne le SlotIdx (position 0..N-1) dans le hash.         }
Function HashSlotAdd(HashSym : Integer; Const Key : TString;
                     Const KeyLbl : TString) : Integer;
Var
  I     : Integer;
  SlotN : Integer;
Begin
  { Compter les slots existants pour ce hash }
  SlotN := 0;
  For I := 0 To HashKeyCount - 1 Do
    If HashKeyTab[I].HashSym = HashSym Then
      Inc(SlotN);
  { Ajouter la nouvelle entree }
  If HashKeyCount < MAX_HASH_KEYS Then
  Begin
    HashKeyTab[HashKeyCount].HashSym := HashSym;
    HashKeyTab[HashKeyCount].KeyStr  := Key;
    HashKeyTab[HashKeyCount].SlotIdx := SlotN;
    HashKeyTab[HashKeyCount].KeyLbl  := KeyLbl;
    Inc(HashKeyCount);
  End Else
  Begin
    WriteLn('PERL86: ERREUR - HashKeyTab pleine (MAX_HASH_KEYS=', MAX_HASH_KEYS, ')');
    Inc(ErrorCount);
  End;
  HashSlotAdd := SlotN;
End;

{ ---- ParseHashElemAccess : acces element hash -> TExprVal -- }
{ HashIdx = indice dans SymTab du %hash.                       }
{ Layout pile :                                                }
{   [BP-hashOff]           = count (paires initialisees)       }
{   [BP-hashOff-2-k*4]     = key_ptr[k] (OFFSET string DATA)  }
{   [BP-hashOff-4-k*4]     = val[k]     (mot valeur)           }
{ Cle constante -> EK_MEM ImmVal=1 (acces direct [BP-n])       }
{ Cle variable  -> stub, EK_AX = 0                             }
Procedure ParseHashElemAccess(HashIdx : Integer; Var Res : TExprVal);
Var
  KeyStr  : TString;
  HKIdx   : Integer;
  SlotIdx : Integer;
  KeyLbl  : TString;
  ValOff  : Integer;
  S       : TString;
  ElemIdx : Integer;
Begin
  ParserAdvance;  { consommer '{' }
  { -- Cle constante : bareword, string ou keyword-as-string -- }
  If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_STRING) Or
     ((CurToken.Kind = TK_KEYWORD) And
      (CurToken.Val <> 'undef') And (CurToken.Val <> 'my') And
      (CurToken.Val <> 'our')   And (CurToken.Val <> 'if')) Then
  Begin
    KeyStr := CurToken.Val;
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then ParserAdvance;
    HKIdx := HashSlotFind(HashIdx, KeyStr);
    If HKIdx >= 0 Then
    Begin
      { Cle deja connue : acces direct }
      SlotIdx := HashKeyTab[HKIdx].SlotIdx;
    End Else
    Begin
      { Cle inconnue : ajouter en DATA + enregistrer }
      ElemIdx := DataAddStr(KeyStr);
      KeyLbl  := DataTab[ElemIdx].LblName;
      SlotIdx := HashSlotAdd(HashIdx, KeyStr, KeyLbl);
      { Initialiser key_ptr au moment de la premiere mention }
      Str(SymTab[HashIdx].Offset + 2 + SlotIdx * 4, S);
      EmitInstr('MOV', 'WORD PTR [BP-' + S + '], OFFSET ' + KeyLbl);
      { Incremeter count pour ce nouveau slot }
      Str(SymTab[HashIdx].Offset, S);
      EmitInstr('INC', 'WORD PTR [BP-' + S + ']');
    End;
    ValOff      := SymTab[HashIdx].Offset + 4 + SlotIdx * 4;
    Res.Kind    := EK_MEM;
    Res.ImmVal  := 1;
    Res.Offset  := ValOff;
    Res.TypeIdx := TY_IDX_SCALAR;
  End Else
  Begin
    { -- Cle variable : stub -> retourner 0 -- }
    EmitComment('$h var-key : runtime non implemente (stub)');
    EmitInstr('MOV', 'AX, 0');
    If (CurToken.Kind <> TK_PUNCT) Or (CurToken.Val <> '}') Then
    Begin
      { Consommer la cle variable }
      While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) And
                (CurToken.Kind <> TK_EOF) Do
        ParserAdvance;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then ParserAdvance;
    Res.Kind    := EK_AX;
    Res.ImmVal  := 0;
    Res.Offset  := 0;
    Res.TypeIdx := TY_IDX_SCALAR;
  End;
End;

{ ============================================================
  EMETTEUR DE CODE ASM
  ============================================================ }

{ ---- LabelGen : generateur de labels ASM uniques ---------- }
{ Incremente LabelSeq et retourne Prefix + N.                  }
{ Ex : LabelGen(PR_LBL_PFX) -> ''_PRL_42''                     }
Function LabelGen(Const Prefix : TString) : TString;
Var
  S : TString;
Begin
  Inc(LabelSeq);
  Str(LabelSeq, S);
  LabelGen := Prefix + S;
End;

{ ---- EmitRaw : ecriture directe dans le fichier de sortie - }
Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, S);
End;

{ ---- EmitBlankLine : ligne vide --------------------------- }
Procedure EmitBlankLine;
Begin
  EmitRaw('');
End;

{ ---- EmitComment : commentaire ASM (prefixe ;) ------------ }
Procedure EmitComment(Const S : TString);
Begin
  EmitRaw('; ' + S);
End;

{ ---- EmitLabel : etiquette ASM (non indentee) ------------- }
{ Convention MASM : label sur sa propre ligne, suivi de '':''. }
Procedure EmitLabel(Const Name : TString);
Begin
  EmitRaw(Name + ':');
End;

{ ---- EmitInstr : instruction a 2 operandes (indenation 8sp) }
{ Format : ''        MNEM  OPS''                               }
Procedure EmitInstr(Const Mnem, Ops : TString);
Begin
  EmitRaw('        ' + Mnem + '  ' + Ops);
End;

{ ---- EmitInstr1 : instruction sans operande (MOV SP,BP ...) }
Procedure EmitInstr1(Const Mnem : TString);
Begin
  EmitRaw('        ' + Mnem);
End;

{ ============================================================
  RUN  [IMPLEMENTE]
  Pipeline complet : TypeInit/SymInit/EmitOpen -> LexInit/ParseStmt ->
  LexClose -> EmitClose (EmitRuntime + EmitDataSeg + END _PRF_main)
  ============================================================ }
Procedure Run;Begin
 TypeInit;
 SymInit;
 EmitOpen;
 If ErrorCount > 0 Then Exit;
  { Lexeur + analyse syntaxique }
 LexInit;
 ParserAdvance;
 If Opts.DebugTok Then Begin
    { Mode debug : afficher tous les tokens sans emettre de code }
  While CurToken.Kind <> TK_EOF Do ParserAdvance;
 End
  Else
 Begin
   { Analyse normale : stub }
  While CurToken.Kind <> TK_EOF Do ParseStmt;
 End;
 LexClose;
 EmitClose;
 If Opts.Verbose Then WriteLn('PERL86: ', TotalLines, ' ligne(s) lues depuis ', Opts.SrcFile);
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  ShowHelp;
  Halt(0);
 End;
 ErrorCount   := 0;
 WarnCount    := 0;
 TotalLines   := 0;
 TotalSyms    := 0;
 LexOpened    := False;
 OutFOpen     := False;
 SymCount     := 0;
 ScopeTop     := 0;
 CurScope     := 0;
 LabelSeq     := 0;
 TypeCount    := 0;
 DataCount    := 0;
 CurFrameSize := 0;
 CurFnDepth   := 0;
 LoopTop      := 0;
 GKwConsumed  := False;
 CurFnRetLbl  := '';
 CurFnName    := '';
 CurPackage   := 'main';
 RuntimeEmitted := False;
 IncludeCount := 0;
  { Expressions regulieres }
 LexExpectRegex := False;
 RegexSeq       := 0;
 GExprDummy.Kind    := EK_NONE;
 GExprDummy.ImmVal  := 0;
 GExprDummy.TypeIdx := TY_UNKNOWN;
 GExprDummy.Offset  := 0;
 InitOptions;
 ParseArgs;
 ShowBanner;
 Run;
 Cleanup;
 If Opts.Verbose Then ShowStats;
 If ErrorCount > 0 Then Halt(EXIT_ERROR)
                   Else Halt(EXIT_OK);
END.
