{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur PSP (Pascal Server Pages) vers assembleur 8086
  @license: MIT
}

(* ============================================================
  PSP86.PAS - Compilateur Pascal Server Pages vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  Pascal Server Pages (.PSP) est un langage de template melant
  du code HTML statique et des blocs de code Pascal inseres
  entre les balises <% ... %> (similaire a ASP 3.0 mais en Pascal).
  Les expressions en ligne s ecrivent <%= expr %>.
  Le compilateur produit un fichier .ASM autonome (mode CGI DOS).

  ============================================================ *)

Program PSP86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  PSP86_VERSION = '1.0';
  PSP86_DATE    = '2026-03-06';

  { Limites internes }
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_INCLUDE   = {$IFDEF FPC}8{$ELSE}4{$ENDIF};     { profondeur max d inclusion }
  MAX_DEFINE    = {$IFDEF FPC}64{$ELSE}16{$ENDIF};    { nombre max de symboles de compilation }
  MAX_FIELD     = {$IFDEF FPC}32{$ELSE}16{$ENDIF};    { champs max par record }
  MAX_ENUM      = {$IFDEF FPC}64{$ELSE}16{$ENDIF};    { valeurs max par enumeration }
  MAX_WITH      = 8;     { profondeur max de with imbrique }
  STACK_SIZE    = 1024;
  FRAME_WARN    = 256;   { seuil avertissement taille cadre (octets) }
  NEST_MAX      = 4;     { profondeur max imbrication proc/func }

  { Prefixes de nommage ASM }
  PSP_VAR_PFX   = '_PSP_';     { variable globale              }
  PSP_FN_PFX    = '_PSPF_';    { fonction / procedure          }
  PSP_STR_PFX   = '_PSPK_';    { constante chaine litterale    }
  PSP_RT_PFX    = '_PSPRT_';   { routine runtime               }
  PSP_LBL_PFX   = '_PSPL_';    { label de saut interne         }
  PSP_ARR_PFX   = '_PSPA_';    { tableau                       }
  PSP_REC_PFX   = '_PSPR_';    { record                        }
  PSP_ENUM_PFX  = '_PSPE_';    { enumeration                   }
  PSP_HTML_PFX  = '_PSPK_HTML_'; { fragment HTML literal       }
  PSP_EX_PFX    = '_PSPX_';     { exception handler            }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Indices de types primitifs Pascal }
  TY_IDX_INTEGER = 0;   { entier 16 bits signe   }
  TY_IDX_WORD    = 1;   { entier 16 bits non signe }
  TY_IDX_BYTE    = 2;   { 8 bits non signe       }
  TY_IDX_CHAR    = 3;   { 8 bits caractere       }
  TY_IDX_BOOLEAN = 4;   { 0 | 1 dans AL/AX      }
  TY_IDX_STRING  = 5;   { pointeur ASCIIZ        }
  TY_IDX_REAL    = 6;   { tronque en entier      }
  TY_IDX_POINTER = 7;   { pointeur generique     }
  TY_IDX_NIL     = 8;   { pointeur nul           }
  TY_IDX_TEXT    = 9;    { fichier texte (handle) }
  TY_PRIM_COUNT  = 10;
  TY_UNKNOWN     = -1;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;   { fichier source (.psp)                }
    OutFile   : TString;   { fichier assembleur de sortie (.asm)  }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Warnings  : Boolean;   { -w : activer les avertissements      }
  End;

  { ---- Tokens Pascal / PSP ---------------------- }
  TTokenKind = (
    TK_EOF,            { fin de fichier                       }
    TK_INTEGER,        { literal entier 42 $FF                }
    TK_REAL,           { literal reel 3.14 1.5E3              }
    TK_STRING,         { literal chaine 'hello'               }
    TK_CHAR,           { literal caractere #65 #$41           }
    TK_IDENT,          { identificateur (non-mot-cle)         }
    TK_KEYWORD,        { mot-cle Pascal reconnu               }
    TK_OP,             { operateur := + - * / = <> < > etc.   }
    TK_PUNCT,          { ponctuation ; , ( ) [ ] . ..         }
    TK_HTML,           { texte HTML literal hors balises       }
    TK_PSP_OPEN,       { balise <% ouvrante                   }
    TK_PSP_CLOSE,      { balise %> fermante                   }
    TK_PSP_EXPR_OPEN,  { balise <%= (expression inline)       }
    TK_PSP_DIRECTIVE   { balise <%@ (directive de page)       }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;     { valeur textuelle brute           }
    IntVal   : LongInt;     { valeur entiere (TK_INTEGER)      }
    RealVal  : Real;        { valeur reelle (TK_REAL)          }
    Line     : Integer;     { ligne source (1-base)            }
    Col      : Integer;     { colonne source (1-base)          }
  End;

  { ---- Mode du template PSP --------------------- }
  TPSPMode = (TPL_HTML, TPL_CODE);

  { ---- Segment de donnees ------------ }
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY, DK_REC);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;   { nombre d elements (DK_ARRAY)        }
    ElemSize  : Integer;   { taille d un element (DK_ARRAY)      }
    RecSize   : Integer;   { taille totale en octets (DK_REC)    }
  End;

  { ---- Valeurs d expression --------------------- }
  TExprKind = (
    EK_NONE,   { void / pas de valeur                       }
    EK_IMM,    { valeur immediate dans ImmVal                }
    EK_AX,     { valeur dans registre AX                     }
    EK_MEM     { adresse memoire [BP+Offset] ou [_PSP_x]    }
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
    SymIdx  : Integer;   { indice dans SymTab (-1 si pas lvalue) }
  End;

  { ---- Genre de type ----------------------------- }
  TTypeKind = (
    TKP_INTEGER,   { entier 16 bits signe                    }
    TKP_WORD,      { entier 16 bits non signe                 }
    TKP_BYTE,      { 8 bits non signe                         }
    TKP_CHAR,      { 8 bits caractere                         }
    TKP_BOOLEAN,   { 0 ou 1 dans AL, etendu AX                }
    TKP_STRING,    { pointeur ASCIIZ dans AX                   }
    TKP_REAL,      { tronque en entier 16 bits                 }
    TKP_ARRAY,     { tableau (BaseTypeIdx = type element)      }
    TKP_RECORD,    { enregistrement (FieldCount champs)        }
    TKP_ENUM,      { enumeration (EnumCount valeurs)           }
    TKP_SUBRANGE,  { sous-intervalle (Lo..Hi)                  }
    TKP_POINTER,   { pointeur generique 16 bits                }
    TKP_NIL,       { pointeur nul                              }
    TKP_TEXT,      { fichier texte (handle)                    }
    TKP_VOID       { procedure, pas de valeur de retour        }
  );

  { ---- Champ de record --------------------------- }
  TFieldRec = Record
    Name    : TString;
    TypeIdx : Integer;
    Offset  : Integer;  { decalage en octets dans le record }
  End;

  { ---- Valeur d enumeration ---------------------- }
  TEnumValRec = Record
    Name  : TString;
    Value : Integer;
  End;

  { ---- Enregistrement de type -------------------- }
  TTypeRec = Record
    Kind        : TTypeKind;
    Size        : Integer;     { taille en octets                   }
    BaseTypeIdx : Integer;     { type de base (pointer/array/sub)   }
    Lo          : LongInt;     { borne inf (subrange/array)         }
    Hi          : LongInt;     { borne sup (subrange/array)         }
    FieldCount  : Integer;     { nombre de champs (record)          }
    Fields      : Array[0..MAX_FIELD - 1] Of TFieldRec;
    EnumCount   : Integer;     { nombre de valeurs (enum)           }
    Enums       : Array[0..MAX_ENUM - 1] Of TEnumValRec;
  End;

  { ---- Categorie de symbole ---------------------- }
  TSymCat = (
    SC_VAR,          { variable globale ou locale           }
    SC_CONST,        { constante non-typee (substitution)   }
    SC_TYPED_CONST,  { constante typee (en DATA)            }
    SC_PARAM,        { parametre par valeur                 }
    SC_VARPARAM,     { parametre var (par reference)        }
    SC_FUNC,         { fonction                             }
    SC_PROC,         { procedure                            }
    SC_TYPE,         { nom de type                          }
    SC_FIELD,        { champ de record                      }
    SC_ENUM_VAL,     { valeur d enumeration                 }
    SC_LABEL         { label nomme                          }
  );

  { ---- Enregistrement symbole -------------------- }
  TSymRec = Record
    Name        : TString;  { nom original Pascal (minuscule)    }
    MangledName : TString;  { nom ASM mangled (_PSP_xxx etc.)    }
    Cat         : TSymCat;  { categorie (var/const/func etc.)    }
    TypeIdx     : Integer;  { indice dans TypeTab (TY_IDX_*)     }
    Offset      : Integer;  { offset cadre local (BP+n)          }
    ScopeLevel  : Integer;  { profondeur de portee (0=global)    }
    ScopeId     : Integer;  { identifiant unique de portee       }
    IsForward   : Boolean;  { declaration forward non resolue    }
    IsLocal     : Boolean;  { True si variable locale            }
    ImmVal      : LongInt;  { valeur immediate (SC_CONST)        }
    DataIdx     : Integer;  { index DataTab (SC_TYPED_CONST)     }
    ParamCnt    : Integer;  { nb params (SC_FUNC/SC_PROC) T17   }
    VarParamMask: LongInt;  { bitmask var params (bit i=1) T17  }
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

  { Emetteur ASM (pour Cleanup) }
  OutF     : Text;
  OutFOpen : Boolean;

  { Lexeur }
  LexSrcF   : Text;
  LexOpened : Boolean;
  LexLine   : String;
  LexLineNo : Integer;
  LexColNo  : Integer;
  LexEOF    : Boolean;
  CurToken  : TToken;

  { Analyseur de template }
  TplMode      : TPSPMode;
  TplHtmlBuf   : TString;
  TplPending   : TTokenKind;
  TplHtmlCount : Integer;

  { Segment de donnees }
  DataTab      : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount    : Integer;
  LabelGenSeq  : Integer;

  { Table des symboles }
  SymTab        : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount      : Integer;
  CurScopeLevel : Integer;
  CurScopeId    : Integer;
  ScopeIdSeq    : Integer;

  { Table des types }
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

  { Variables et affectations }
  CurFrameOffset   : Integer;  { offset courant dans le cadre local (negatif) }
  PendingAssignName : TString; { nom ident en attente (lookahead ParseVarDecl) }
  HasPendingAssign  : Boolean; { True si une affectation a ete detectee }

  { Pile de boucles pour break/continue }
  LoopBreakLbl    : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContLbl     : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopTop         : Integer;  { sommet de la pile (-1 = vide) }

  { Fonctions et procedures }
  CurFuncName     : TString;  { nom de la fonction en cours ('' si aucune) }
  CurFuncRetOfs   : Integer;  { offset de la valeur de retour [BP+n] }
  CurRetLabel     : TString;  { label de retour (_PSPL_RET_N) pour Exit }
  CurNestLevel    : Integer;  { profondeur d imbrication proc/func }
  CurParamBytes   : Integer;  { taille des parametres pour RET n }
  MainBodyEmitted : Boolean;  { True si _PSPL_MAINBODY deja emis }
  RuntimeEmitted  : Boolean;  { True si routines runtime deja emises }

  { Pile with pour records }
  WithSymIdx      : Array[0..MAX_WITH - 1] Of Integer;  { symidx du record }
  WithTop         : Integer;  { sommet de la pile (-1 = vide) }

  { Directives et inclusions }
  IncSavedFName   : Array[0..MAX_INCLUDE - 1] Of TString; { nom fichier empile }
  IncSavedFLine   : Array[0..MAX_INCLUDE - 1] Of Integer;{ ligne dans fichier }
  IncSavedLine    : Array[0..MAX_INCLUDE - 1] Of String; { ligne courante  }
  IncSavedLineNo  : Array[0..MAX_INCLUDE - 1] Of Integer;{ numero de ligne }
  IncSavedColNo   : Array[0..MAX_INCLUDE - 1] Of Integer;{ colonne         }
  IncSavedEOF     : Array[0..MAX_INCLUDE - 1] Of Boolean;{ EOF sauvegarde  }
  LexSrcFName     : TString;  { nom du fichier source courant }
  IncTop          : Integer;  { sommet pile inclusion (-1 = vide) }
  DefineTab       : Array[0..MAX_DEFINE - 1] Of TString; { symboles defines }
  DefineCount     : Integer;  { nombre de defines actifs }
  CompilerMode    : TString;  { 'TP' ou 'FPC' }
  ContentTypeLbl  : TString;  { label content-type ou '' }

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
{ Utilitaires chaines }
Function  StrLowerCase(Const S : TString) : TString; Forward;
Function  StrUpperCase(Const S : TString) : TString; Forward;
Function  IntToStr(N : LongInt) : TString; Forward;
Function  BPOfs(Ofs : Integer) : TString; Forward;
Function  StrToIntDef(Const S : TString; Def : LongInt) : LongInt; Forward;
{ Messages }
Procedure FatalError(Const Msg : TString); Forward;
Procedure WarnMsg(Const Msg : TString); Forward;
Procedure ErrorMsg(Const Msg : TString); Forward;
Procedure Expect(Const Expected : TString); Forward;
Procedure SkipTo; Forward;
{ Lexeur }
Procedure LexInit;       Forward;
Procedure LexClose;      Forward;
Procedure LexNextLine;   Forward;
Procedure LexNextToken;  Forward;
Procedure LexScanIdent;  Forward;
Procedure LexScanNumber; Forward;
Procedure LexScanString; Forward;
Procedure LexScanCharLit;Forward;
Function  IsKeyword(Const S : TString) : Boolean; Forward;
Function  IsIdentStart(Ch : Char) : Boolean; Forward;
Function  IsIdentCont(Ch : Char) : Boolean; Forward;
Function  IsHexDigit(Ch : Char) : Boolean; Forward;
Function  HexVal(Ch : Char) : Integer; Forward;
Procedure PrintToken(Const T : TToken); Forward;
Procedure LexSkipBraceComment; Forward;
Procedure LexSkipParenStarComment; Forward;
Procedure LexSkipLineComment; Forward;
{ Directives et inclusions }
Procedure LexHandleDollarDirective; Forward;
Procedure IncludePush(Const FileName : TString); Forward;
Procedure IncludePop; Forward;
Function  DefineDefined(Const Name : TString) : Boolean; Forward;
Procedure DefineAdd(Const Name : TString); Forward;
Procedure DefineRemove(Const Name : TString); Forward;
Procedure ParsePSPDirective; Forward;
{ Analyseur de template }
Procedure TplInit;       Forward;
Procedure TplClose;      Forward;
Procedure TplEmitHtml;   Forward;
Procedure TplEmitPSPOpen(Kind : TTokenKind); Forward;
Procedure TplNextToken;  Forward;
{ Segment de donnees et litteraux }
Function  LabelGen : TString; Forward;
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : TString; Forward;
Function  DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer; Forward;
Function  DataAddByte(Const Lbl : TString; AIntVal : LongInt) : Integer; Forward;
Function  DataAddArray(Const Lbl : TString;
                ECount, ESz : Integer) : Integer; Forward;
Function  DataAddRec(Const Lbl : TString;
                RSz : Integer) : Integer; Forward;
Procedure EmitRaw(Const S : String); Forward;
Procedure EmitDataSeg; Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
Procedure ParseConstDecl; Forward;
{ Table des symboles }
Function  SymMangle(Const Name : TString; Cat : TSymCat) : TString; Forward;
Function  SymAdd(Const Name : TString; Cat : TSymCat;
               TIdx : Integer) : Integer; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindInScope(Const Name : TString;
               Level : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
Procedure SymInit; Forward;
{ Systeme de types }
Procedure TypeInit; Forward;
Function  TypeSizeof(TIdx : Integer) : Integer; Forward;
Function  TypeCompatible(T1, T2 : Integer) : Boolean; Forward;
Function  TypeCoerce(SrcType, DstType : Integer) : Integer; Forward;
Function  TypeResolve(Const Name : TString) : Integer; Forward;
Function  TypeIsOrdinal(TIdx : Integer) : Boolean; Forward;
Function  TypeIsNumeric(TIdx : Integer) : Boolean; Forward;
Function  TypeIsPointer(TIdx : Integer) : Boolean; Forward;
{ Emetteur ASM }
Procedure EmitComment(Const S : TString); Forward;
Procedure EmitLabel(Const Lbl : TString); Forward;
Procedure EmitInstr(Const Mnem : TString); Forward;
Procedure EmitInstrA(Const Mnem, A1 : TString); Forward;
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString); Forward;
{ Emetteur de code ASM }
Procedure EmitBlankLine; Forward;
Function  NewLabel : TString; Forward;
Procedure EmitHeader; Forward;
Procedure EmitFooter; Forward;
Procedure EmitProlog(FrameSize : Integer); Forward;
Procedure EmitEpilog(ParamBytes : Integer); Forward;
Procedure EmitPush(Const Reg : TString); Forward;
Procedure EmitPop(Const Reg : TString); Forward;
Procedure EmitMov(Const Dst, Src : TString); Forward;
Procedure EmitCall(Const Target : TString); Forward;
Procedure EmitJmp(Const Target : TString); Forward;
Procedure EmitJmpCond(Const Cond, Target : TString); Forward;
Procedure EmitCoerce(SrcType, DstType : Integer); Forward;
{ Operateurs et expressions }
Function  OpPrec(Const Op : TString) : Integer; Forward;
Procedure ExprMakeImm(V : LongInt; TIdx : Integer; Var R : TExprVal); Forward;
Procedure ExprFlushToAX(Var E : TExprVal); Forward;
Procedure ParseCallArgs(FuncIdx : Integer); Forward;
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Procedure ParseUnary(Var Res : TExprVal); Forward;
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Forward;
Procedure ParseExpr(Var Res : TExprVal); Forward;
{ Variables et affectations }
Procedure ParseVarDecl; Forward;
Procedure ParseAssignment(Const VarName : TString); Forward;
{ Write/WriteLn et emission HTML }
Procedure ParseWriteStmt(IsWriteLn : Boolean); Forward;
Procedure EmitHtmlFragment(Const Html : TString); Forward;
Procedure EmitExprInline; Forward;
{ If/Then/Else, Case/Of, Blocs }
Procedure ParseStatement; Forward;
Procedure ParseBlock; Forward;
Procedure ParseIfStmt; Forward;
Procedure ParseCaseStmt; Forward;
{ Boucles }
Procedure ParseForStmt; Forward;
Procedure ParseWhileStmt; Forward;
Procedure ParseRepeatStmt; Forward;
{ Fonctions et procedures }
Procedure ParseFuncDecl; Forward;
Procedure ParseProcDecl; Forward;
{ Types definis et enumerations }
Procedure ParseTypeDecl; Forward;
Procedure ParseIncDecStmt(IsInc : Boolean); Forward;
{ Enregistrements }
Procedure ParseWithStmt; Forward;
Procedure ParseTryExcept; Forward;

{ ============================================================
  LEXEUR (TOKENS PASCAL)
  ============================================================ }

{ ---- IsKeyword : teste si S est un mot-cle Pascal ---------- }
{ Comparaison insensible a la casse                            }
Function IsKeyword(Const S : TString) : Boolean;
Var
  L : TString;
Begin
  L := StrLowerCase(S);
  IsKeyword :=
    (L = 'program')   Or (L = 'begin')     Or (L = 'end')       Or
    (L = 'var')        Or (L = 'const')     Or (L = 'type')      Or
    (L = 'if')         Or (L = 'then')      Or (L = 'else')      Or
    (L = 'while')      Or (L = 'do')        Or (L = 'for')       Or
    (L = 'to')         Or (L = 'downto')    Or (L = 'repeat')    Or
    (L = 'until')      Or (L = 'case')      Or (L = 'of')        Or
    (L = 'function')   Or (L = 'procedure') Or (L = 'forward')   Or
    (L = 'array')      Or (L = 'record')    Or (L = 'string')    Or
    (L = 'integer')    Or (L = 'boolean')   Or (L = 'char')      Or
    (L = 'byte')       Or (L = 'word')      Or (L = 'real')      Or
    (L = 'nil')        Or (L = 'true')      Or (L = 'false')     Or
    (L = 'not')        Or (L = 'and')       Or (L = 'or')        Or
    (L = 'xor')        Or (L = 'div')       Or (L = 'mod')       Or
    (L = 'shl')        Or (L = 'shr')       Or (L = 'in')        Or
    (L = 'with')       Or (L = 'uses')      Or (L = 'write')     Or
    (L = 'writeln')    Or (L = 'read')      Or (L = 'readln')    Or
    (L = 'break')      Or (L = 'continue')  Or (L = 'exit')      Or
    (L = 'halt')       Or (L = 'try')       Or (L = 'except')    Or
    (L = 'finally')    Or (L = 'raise')     Or (L = 'result');
End;

{ ---- PrintToken : affichage debug d'un token --------------- }
Procedure PrintToken(Const T : TToken);
Var
  S : TString;
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF           : Write('EOF');
    TK_INTEGER       : Write('INT(', T.IntVal, ')');
    TK_REAL          : Write('REAL(', T.Val, ')');
    TK_STRING        : Write('STR(''', T.Val, ''')');
    TK_CHAR          : Write('CHAR(#', T.IntVal, ')');
    TK_IDENT         : Write('IDENT(', T.Val, ')');
    TK_KEYWORD       : Write('KW(', T.Val, ')');
    TK_OP            : Write('OP(', T.Val, ')');
    TK_PUNCT         : Write('PUNCT(', T.Val, ')');
    TK_HTML          : Begin
                         S := T.Val;
                         If Length(S) > 40 Then
                           S := Copy(S, 1, 37) + '...';
                         Write('HTML("', S, '")');
                       End;
    TK_PSP_OPEN      : Write('PSP_OPEN');
    TK_PSP_CLOSE     : Write('PSP_CLOSE');
    TK_PSP_EXPR_OPEN : Write('PSP_EXPR');
    TK_PSP_DIRECTIVE : Write('PSP_DIR');
  End;
  WriteLn;
End;

{ ---- LexNextLine : lire la prochaine ligne source ----------- }
Procedure LexNextLine;Begin
  If LexEOF Then Exit;
  If EOF(LexSrcF) Then
  Begin
    { Si on est dans un fichier inclus, depiler }
    If IncTop >= 0 Then
    Begin
      IncludePop;
      Exit;  { reprendre la lecture dans le fichier parent }
    End;
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

{ ---- LexSkipBraceComment : sauter accolade-commentaire ------ }
{ Si le premier caractere apres { est $, on dispatche vers       }
{ LexHandleDollarDirective pour les directives de compilation.   }
Procedure LexSkipBraceComment;
Begin
  { Detecter {$ : directive de compilation }
  If (LexColNo < Length(LexLine)) And
     (LexLine[LexColNo + 1] = '$') Then
  Begin
    LexHandleDollarDirective;
    Exit;
  End;
  Inc(LexColNo); { sauter '{' }
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
      LexNextLine
    Else If LexLine[LexColNo] = '}' Then
    Begin
      Inc(LexColNo);
      Exit;
    End
    Else
      Inc(LexColNo);
  End;
End;

{ ---- LexSkipParenStarComment : sauter paren-star comment ---- }
Procedure LexSkipParenStarComment;
Begin
  Inc(LexColNo); Inc(LexColNo); { sauter '(' et '*' }
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
      LexNextLine
    Else If (LexLine[LexColNo] = '*') And
            (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = ')') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      Exit;
    End
    Else
      Inc(LexColNo);
  End;
End;

{ ---- LexSkipLineComment : sauter // ... fin de ligne -------- }
Procedure LexSkipLineComment;
Begin
  LexColNo := Length(LexLine) + 1;
End;

{ ============================================================
  DIRECTIVES PSP ET INCLUSIONS
  ============================================================ }

{ ---- DefineDefined : teste si un symbole est defini --------- }
Function DefineDefined(Const Name : TString) : Boolean;
Var
  I : Integer;
  N : TString;
Begin
  N := StrUpperCase(Name);
  DefineDefined := False;
  For I := 0 To DefineCount - 1 Do
    If DefineTab[I] = N Then
    Begin
      DefineDefined := True;
      Exit;
    End;
End;

{ ---- DefineAdd : ajouter un symbole de compilation ---------- }
Procedure DefineAdd(Const Name : TString);
Var
  N : TString;
Begin
  N := StrUpperCase(Name);
  If DefineDefined(N) Then Exit;  { deja defini }
  If DefineCount >= MAX_DEFINE Then
  Begin
    WarnMsg('trop de symboles $DEFINE');
    Exit;
  End;
  DefineTab[DefineCount] := N;
  Inc(DefineCount);
End;

{ ---- DefineRemove : supprimer un symbole de compilation ----- }
Procedure DefineRemove(Const Name : TString);
Var
  I : Integer;
  N : TString;
Begin
  N := StrUpperCase(Name);
  For I := 0 To DefineCount - 1 Do
    If DefineTab[I] = N Then
    Begin
      DefineTab[I] := DefineTab[DefineCount - 1];
      Dec(DefineCount);
      Exit;
    End;
End;

{ ---- IncludePush : empiler le fichier courant et ouvrir un include }
Procedure IncludePush(Const FileName : TString);
Var
  FullPath : TString;
Begin
  If IncTop >= MAX_INCLUDE - 1 Then
  Begin
    WarnMsg('profondeur d''inclusion maximale atteinte');
    Exit;
  End;
  { Sauvegarder l etat du lexeur : nom fichier + ligne atteinte }
  Inc(IncTop);
  IncSavedFName[IncTop]  := LexSrcFName;
  IncSavedFLine[IncTop]  := LexLineNo;
  IncSavedLine[IncTop]   := LexLine;
  IncSavedLineNo[IncTop] := LexLineNo;
  IncSavedColNo[IncTop]  := LexColNo;
  IncSavedEOF[IncTop]    := LexEOF;
  { Fermer le fichier courant avant d ouvrir l include }
  Close(LexSrcF);
  { Ouvrir le fichier inclus }
  FullPath := FileName;
  {$I-}
  Assign(LexSrcF, FullPath);
  Reset(LexSrcF);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WarnMsg('impossible d''ouvrir le fichier include: ' + FullPath);
    { Rouvrir le fichier precedent }
    Assign(LexSrcF, IncSavedFName[IncTop]);
    Reset(LexSrcF);
    Dec(IncTop);
    Exit;
  End;
  LexSrcFName := FullPath;
  LexOpened := True;
  LexLine   := '';
  LexLineNo := 0;
  LexColNo  := 1;
  LexEOF    := False;
  LexNextLine;
End;

{ ---- IncludePop : depiler et restaurer le fichier precedent -- }
Procedure IncludePop;
Var
  I : Integer;
  Dummy : String;
Begin
  If IncTop < 0 Then Exit;
  Close(LexSrcF);
  { Rouvrir le fichier precedent et avancer jusqu a la bonne ligne }
  Assign(LexSrcF, IncSavedFName[IncTop]);
  Reset(LexSrcF);
  For I := 1 To IncSavedFLine[IncTop] Do
  Begin
    If Not EOF(LexSrcF) Then
      ReadLn(LexSrcF, Dummy);
  End;
  LexSrcFName := IncSavedFName[IncTop];
  LexLine   := IncSavedLine[IncTop];
  LexLineNo := IncSavedLineNo[IncTop];
  LexColNo  := IncSavedColNo[IncTop];
  LexEOF    := IncSavedEOF[IncTop];
  Dec(IncTop);
End;

(* ---- LexSkipCondFalse : sauter le code dans un IFDEF faux --- *)
(* Saute jusqu a trouver ELSE ou ENDIF au meme niveau            *)
Procedure LexSkipCondFalse;
Var
  Depth : Integer;
  P     : Integer;
  Dir   : TString;
Begin
  Depth := 1;
  While (Depth > 0) And (Not LexEOF) Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      LexNextLine;
      Continue;
    End;
    If LexLine[LexColNo] = '{' Then
    Begin
      P := LexColNo + 1;
      If (P <= Length(LexLine)) And (LexLine[P] = '$') Then
      Begin
        Inc(P);
        Dir := '';
        While (P <= Length(LexLine)) And (LexLine[P] <> '}') And
              (LexLine[P] <> ' ') Do
        Begin
          Dir := Dir + UpCase(LexLine[P]);
          Inc(P);
        End;
        If (Dir = 'IFDEF') Or (Dir = 'IFNDEF') Then
          Inc(Depth)
        Else If Dir = 'ENDIF' Then
        Begin
          Dec(Depth);
          If Depth = 0 Then
          Begin
            (* Trouver le accolade fermant *)
            While (P <= Length(LexLine)) And (LexLine[P] <> '}') Do
              Inc(P);
            LexColNo := P + 1;
            Exit;
          End;
        End
        Else If (Dir = 'ELSE') And (Depth = 1) Then
        Begin
          { $ELSE au meme niveau : on commence a compiler }
          While (P <= Length(LexLine)) And (LexLine[P] <> '}') Do
            Inc(P);
          LexColNo := P + 1;
          Exit;
        End;
      End;
      { Sauter toute l accolade }
      While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] <> '}') Do
        Inc(LexColNo);
      If LexColNo <= Length(LexLine) Then
        Inc(LexColNo);
    End
    Else
      Inc(LexColNo);
  End;
End;

(* ---- LexHandleDollarDirective : traiter dollar-directives -- *)
(* Appelee quand LexColNo pointe sur accolade et le char suivant *)
(* est $. Gere I, INCLUDE, DEFINE, UNDEF, IFDEF, IFNDEF,        *)
(* ELSE, ENDIF, MODE. Les autres sont ignores.                   *)
Procedure LexHandleDollarDirective;
Var
  Dir  : TString;
  Arg  : TString;
Begin
  Inc(LexColNo);  { sauter { }
  Inc(LexColNo);  { sauter $ }
  { Lire le nom de la directive }
  Dir := '';
  While (LexColNo <= Length(LexLine)) And
        IsIdentCont(LexLine[LexColNo]) Do
  Begin
    Dir := Dir + UpCase(LexLine[LexColNo]);
    Inc(LexColNo);
  End;
  { Sauter espaces }
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] = ' ') Do
    Inc(LexColNo);
  (* Lire l argument jusqu a accolade fermante *)
  Arg := '';
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] <> '}') Do
  Begin
    Arg := Arg + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  { Supprimer espaces de fin de l argument }
  While (Length(Arg) > 0) And (Arg[Length(Arg)] = ' ') Do
    Delete(Arg, Length(Arg), 1);
  (* Consommer accolade fermante *)
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '}') Then
    Inc(LexColNo);

  { Dispatcher }
  If (Dir = 'I') Or (Dir = 'INCLUDE') Then
  Begin
    { Supprimer quotes eventuelles autour du nom de fichier }
    If (Length(Arg) >= 2) And
       ((Arg[1] = '''') Or (Arg[1] = '"')) Then
    Begin
      Delete(Arg, 1, 1);
      If (Length(Arg) > 0) And
         ((Arg[Length(Arg)] = '''') Or (Arg[Length(Arg)] = '"')) Then
        Delete(Arg, Length(Arg), 1);
    End;
    If Length(Arg) > 0 Then
      IncludePush(Arg)
    Else
      WarnMsg('nom de fichier attendu pour $INCLUDE');
  End
  Else If Dir = 'DEFINE' Then
    DefineAdd(Arg)
  Else If Dir = 'UNDEF' Then
    DefineRemove(Arg)
  Else If Dir = 'IFDEF' Then
  Begin
    If DefineDefined(Arg) Then
      { Condition vraie : on ne fait rien, le code suivant sera compile }
    Else
      LexSkipCondFalse;
  End
  Else If Dir = 'IFNDEF' Then
  Begin
    If Not DefineDefined(Arg) Then
      { Condition vraie : compiler }
    Else
      LexSkipCondFalse;
  End
  Else If Dir = 'ELSE' Then
  Begin
    { On est dans la branche vraie d un $IFDEF, sauter jusqu a $ENDIF }
    LexSkipCondFalse;
  End
  Else If Dir = 'ENDIF' Then
  Begin
    { Fin de bloc conditionnel, rien a faire }
  End
  Else If Dir = 'MODE' Then
  Begin
    Arg := StrUpperCase(Arg);
    If (Arg = 'TP') Or (Arg = 'FPC') Then
      CompilerMode := Arg
    Else
      WarnMsg('mode inconnu: ' + Arg + ' (TP ou FPC attendu)');
  End;
  { Autres directives : ignorees silencieusement }
End;

{ ---- ParsePSPDirective : traiter <%@ ... %> ------------------ }
{ Appelee quand CurToken = TK_PSP_DIRECTIVE. Parse les attributs  }
{ ContentType=xxx, Include file="xxx", CodePage=xxx               }
Procedure ParsePSPDirective;
Var
  AttrName  : TString;
  AttrVal   : TString;
  Lbl       : TString;
Begin
  TplNextToken;  { consommer <%@ }
  While (CurToken.Kind <> TK_EOF) And
        (CurToken.Kind <> TK_PSP_CLOSE) Do
  Begin
    If CurToken.Kind = TK_IDENT Then
    Begin
      AttrName := StrLowerCase(CurToken.Val);
      TplNextToken;
      { Consommer = }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
        TplNextToken;
      { Lire la valeur : peut etre une chaine ou un ident/keyword }
      AttrVal := '';
      If CurToken.Kind = TK_STRING Then
      Begin
        AttrVal := CurToken.Val;
        TplNextToken;
      End
      Else
      Begin
        { Lire jusqu a un espace, %> ou fin de ligne }
        While (CurToken.Kind <> TK_EOF) And
              (CurToken.Kind <> TK_PSP_CLOSE) And
              (CurToken.Kind <> TK_IDENT) Do
        Begin
          AttrVal := AttrVal + CurToken.Val;
          TplNextToken;
        End;
        If Length(AttrVal) = 0 Then
        Begin
          AttrVal := CurToken.Val;
          TplNextToken;
        End;
      End;

      { Dispatcher l attribut }
      If AttrName = 'contenttype' Then
      Begin
        { Generer un label pour le content-type }
        Lbl := PSP_STR_PFX + 'CT';
        DataAdd(Lbl, DK_STR, 0,
          'Content-Type: ' + AttrVal + #13#10#13#10);
        ContentTypeLbl := Lbl;
      End
      Else If AttrName = 'include' Then
      Begin
        { Supprimer le mot file= si present }
        If Length(AttrVal) > 0 Then
          IncludePush(AttrVal)
        Else
          WarnMsg('nom de fichier attendu dans <%@ Include %>');
      End
      Else If AttrName = 'codepage' Then
        WarnMsg('CodePage=' + AttrVal + ' ignore (pas de support Unicode)')
      Else
        WarnMsg('directive PSP inconnue: ' + AttrName);
    End
    { Gerer Include file="..." ou page language="..." }
    Else If (CurToken.Kind = TK_KEYWORD) Then
    Begin
      AttrName := StrLowerCase(CurToken.Val);
      TplNextToken;
      { Ignorer les keywords non reconnus, avancer }
    End
    Else
      TplNextToken;
  End;
  { Consommer %> }
  If CurToken.Kind = TK_PSP_CLOSE Then
    TplNextToken;
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
  CurToken.RealVal := 0.0;
  { Mots-cles Pascal : stocker en minuscules normalisees }
  If IsKeyword(S) Then
  Begin
    CurToken.Kind := TK_KEYWORD;
    CurToken.Val  := StrLowerCase(S);
  End
  Else
    CurToken.Kind := TK_IDENT;
End;

{ ---- LexScanNumber : scanner un litteral numerique ---------- }
{ Entiers decimaux, hexadecimaux ($FF), reels (3.14, 1.5E3)    }
Procedure LexScanNumber;
Var
  N       : LongInt;
  IsReal  : Boolean;
  NegExp  : Boolean;
  FracDiv : Real;
  FracVal : Real;
  ExpVal  : Integer;
  FltVal  : Real;
Begin
  N       := 0;
  IsReal  := False;
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

  { Partie decimale .ddd (mais pas '..' qui est le token de plage) }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And (LexLine[LexColNo + 1] <> '.') And
     (LexLine[LexColNo + 1] >= '0') And (LexLine[LexColNo + 1] <= '9') Then
  Begin
    IsReal := True;
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

  { Exposant E [+-] ddd }
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'E') Or (LexLine[LexColNo] = 'e')) Then
  Begin
    IsReal := True;
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

  If IsReal Then
  Begin
    FltVal := N + FracVal;
    While ExpVal > 0 Do
    Begin
      If NegExp Then FltVal := FltVal / 10.0
      Else           FltVal := FltVal * 10.0;
      Dec(ExpVal);
    End;
    CurToken.Kind    := TK_REAL;
    CurToken.RealVal := FltVal;
    If FltVal > 32767.0 Then N := 32767
    Else If FltVal < -32768.0 Then N := -32768
    Else N := Trunc(FltVal);
    CurToken.IntVal := N;
    Str(FltVal:0:6, CurToken.Val);
  End
  Else
  Begin
    CurToken.Kind    := TK_INTEGER;
    CurToken.IntVal  := N;
    CurToken.RealVal := 0.0;
    Str(N, CurToken.Val);
  End;
End;

{ ---- LexScanHexNumber : scanner un entier hexadecimal $FF -- }
Procedure LexScanHexNumber;
Var
  N : LongInt;
Begin
  Inc(LexColNo); { sauter '$' }
  N := 0;
  While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
  Begin
    N := N * 16 + HexVal(LexLine[LexColNo]);
    Inc(LexColNo);
  End;
  CurToken.Kind    := TK_INTEGER;
  CurToken.IntVal  := N;
  CurToken.RealVal := 0.0;
  Str(N, CurToken.Val);
End;

{ ---- LexScanString : chaine Pascal entre quotes simples ---- }
{ Gere le doublement de quote : 'l''echo' -> l'echo            }
Procedure LexScanString;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo); { sauter quote ouvrante }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '''' Then
    Begin
      Inc(LexColNo);
      { Quote doublee '' -> un seul caractere ' }
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
      Begin
        If Length(S) < MAX_STR Then
          S := S + '''';
        Inc(LexColNo);
      End
      Else
        Break; { fin de chaine }
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  CurToken.Kind    := TK_STRING;
  CurToken.Val     := S;
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  { Si chaine de longueur 1, stocker aussi le code ASCII }
  If Length(S) = 1 Then
    CurToken.IntVal := Ord(S[1]);
End;

{ ---- LexScanCharLit : caractere #nn ou #$nn ----------------- }
Procedure LexScanCharLit;
Var
  V : LongInt;
  S : TString;
Begin
  S := '';
  { Scanner une sequence de #nn segments et concatener }
  While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Do
  Begin
    Inc(LexColNo); { sauter '#' }
    V := 0;
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '$') Then
    Begin
      Inc(LexColNo); { sauter '$' }
      While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
      Begin
        V := V * 16 + HexVal(LexLine[LexColNo]);
        Inc(LexColNo);
      End;
    End
    Else
    Begin
      While (LexColNo <= Length(LexLine)) And
            (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
      Begin
        V := V * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
        Inc(LexColNo);
      End;
    End;
    If Length(S) < MAX_STR Then
      S := S + Chr(V And $FF);
  End;

  { Si suivi d'une chaine 'xxx', concatener }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
  Begin
    Inc(LexColNo); { sauter quote ouvrante }
    While LexColNo <= Length(LexLine) Do
    Begin
      If LexLine[LexColNo] = '''' Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
        Begin
          If Length(S) < MAX_STR Then S := S + '''';
          Inc(LexColNo);
        End
        Else
          Break;
      End
      Else
      Begin
        If Length(S) < MAX_STR Then
          S := S + LexLine[LexColNo];
        Inc(LexColNo);
      End;
    End;
    { Peut etre suivi d'un autre #nn }
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Then
    Begin
      { Recurse : appeler a nouveau LexScanCharLit et concatener }
      { Simplifie : on reitere dans la boucle While ci-dessus }
      While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Do
      Begin
        Inc(LexColNo);
        V := 0;
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '$') Then
        Begin
          Inc(LexColNo);
          While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
          Begin
            V := V * 16 + HexVal(LexLine[LexColNo]);
            Inc(LexColNo);
          End;
        End
        Else
        Begin
          While (LexColNo <= Length(LexLine)) And
                (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
          Begin
            V := V * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
            Inc(LexColNo);
          End;
        End;
        If Length(S) < MAX_STR Then
          S := S + Chr(V And $FF);
      End;
    End;
  End;

  { Si un seul caractere -> TK_CHAR, sinon TK_STRING }
  If Length(S) = 1 Then
  Begin
    CurToken.Kind   := TK_CHAR;
    CurToken.IntVal := Ord(S[1]);
  End
  Else
  Begin
    CurToken.Kind   := TK_STRING;
    CurToken.IntVal := 0;
  End;
  CurToken.Val     := S;
  CurToken.RealVal := 0.0;
End;

{ ---- LexInit / LexClose ------------------------------------ }
Procedure LexInit;
Begin
  LexLineNo := 0;
  LexColNo  := 1;
  LexEOF    := False;
  LexLine   := '';
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
  { Lire la premiere ligne }
  LexNextLine;
End;

Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
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

    { Commentaire // ligne }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      LexSkipLineComment;
    End

    { Commentaire accolade - ne pas confondre avec dollar-directives }
    Else If Ch = '{' Then
    Begin
      LexSkipBraceComment;
    End

    { Commentaire ( star ... star ) ou operateur '(' }
    Else If (Ch = '(') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      LexSkipParenStarComment;
    End

    { Entier hexadecimal $FF }
    Else If (Ch = '$') And (LexColNo < Length(LexLine)) And
            IsHexDigit(LexLine[LexColNo + 1]) Then
    Begin
      LexScanHexNumber;
      Scanning := False;
    End

    { Caractere literal #nn }
    Else If Ch = '#' Then
    Begin
      LexScanCharLit;
      Scanning := False;
    End

    { Chaine Pascal 'xxx' }
    Else If Ch = '''' Then
    Begin
      LexScanString;
      { Si suivi immediatement par #nn -> concatener (multi-segment) }
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Then
      Begin
        { Sauvegarder la chaine deja scannee et concatener }
        { On reutilise directement CurToken.Val comme base }
        { LexScanCharLit va produire un nouveau token, on doit fusionner }
        { Approche simplifiee : deja geree dans LexScanCharLit }
      End;
      Scanning := False;
    End

    { Identificateur ou mot-cle }
    Else If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      Scanning := False;
    End

    { Nombre decimal }
    Else If (Ch >= '0') And (Ch <= '9') Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    { Operateur d affectation := }
    Else If (Ch = ':') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := ':=';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateur <> }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '<>';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateur <= }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '<=';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateur >= }
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '>=';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Token de plage .. }
    Else If (Ch = '.') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '.') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := '..';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateurs simples }
    Else If (Ch = '+') Or (Ch = '-') Or (Ch = '*') Or (Ch = '/') Or
            (Ch = '=') Or (Ch = '<') Or (Ch = '>') Or (Ch = '@') Or
            (Ch = '^') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Scanning := False;
    End

    { Ponctuation }
    Else If (Ch = ';') Or (Ch = ',') Or (Ch = '(') Or (Ch = ')') Or
            (Ch = '[') Or (Ch = ']') Or (Ch = '.') Or (Ch = ':') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Scanning := False;
    End

    { Balise fermante %> (geree ici en contexte code Pascal) }
    Else If (Ch = '%') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      CurToken.Kind := TK_PSP_CLOSE;
      CurToken.Val  := '%>';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Caractere inconnu : avancer et signaler }
    Else
    Begin
      WarnMsg('caractere inattendu: ' + Ch + ' (ord=' + IntToStr(Ord(Ch)) + ')');
      Inc(LexColNo);
    End;
  End;

  PrintToken(CurToken);
End;

{ ============================================================
  ANALYSEUR DE TEMPLATE PSP [IMPLEMENTE]
  ============================================================ }

{ ---- TplInit : initialiser l analyseur de template --------- }
Procedure TplInit;
Begin
  TplMode      := TPL_HTML;
  TplHtmlBuf   := '';
  TplPending   := TK_EOF;
  TplHtmlCount := 0;
End;

{ ---- TplClose : finaliser l analyseur de template ---------- }
Procedure TplClose;
Begin
  If TplMode = TPL_CODE Then
    WarnMsg('fin de fichier atteinte en mode code (balise %> manquante ?)');
End;

{ ---- TplEmitHtml : emettre le buffer HTML comme token ------- }
{ Procedure interne utilisee par TplNextToken                   }
Procedure TplEmitHtml;
Begin
  CurToken.Kind    := TK_HTML;
  CurToken.Val     := TplHtmlBuf;
  CurToken.Line    := LexLineNo;
  CurToken.Col     := LexColNo;
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  Inc(TplHtmlCount);
  PrintToken(CurToken);
  TplHtmlBuf := '';
End;

{ ---- TplEmitPSPOpen : emettre un token PSP open ------------- }
Procedure TplEmitPSPOpen(Kind : TTokenKind);
Begin
  CurToken.Kind := Kind;
  CurToken.Line := LexLineNo;
  CurToken.Col  := LexColNo;
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  Case Kind Of
    TK_PSP_OPEN:      CurToken.Val := '<%';
    TK_PSP_EXPR_OPEN: CurToken.Val := '<%=';
    TK_PSP_DIRECTIVE:  CurToken.Val := '<%@';
  Else
    CurToken.Val := '';
  End;
  TplMode := TPL_CODE;
  PrintToken(CurToken);
End;

{ ---- TplNextToken : token suivant en mode template --------- }
{ Alterne entre mode HTML (accumulation texte brut) et mode    }
{ CODE (lexeur Pascal via LexNextToken).                       }
{ En HTML : accumule les caracteres jusqu a < pourcent ou EOF. }
{ En CODE : delegue a LexNextToken, revient en HTML sur        }
{   TK_PSP_CLOSE (pourcent >).                                 }
Procedure TplNextToken;
Var
  Ch    : Char;
  Kind  : TTokenKind;
Begin
  { 1) Si un tag PSP est en attente (apres emission de TK_HTML) }
  If TplPending <> TK_EOF Then
  Begin
    Kind := TplPending;
    TplPending := TK_EOF;
    TplEmitPSPOpen(Kind);
    Exit;
  End;

  { 2) Mode HTML : scanner caractere par caractere }
  If TplMode = TPL_HTML Then
  Begin
    TplHtmlBuf := '';

    While Not LexEOF Do
    Begin
      { Fin de ligne : ajouter saut de ligne au buffer }
      If LexColNo > Length(LexLine) Then
      Begin
        { Vider le buffer si presque plein (reserve pour CR+LF) }
        If Length(TplHtmlBuf) >= MAX_STR - 1 Then
        Begin
          TplEmitHtml;
          Exit;
        End;
        TplHtmlBuf := TplHtmlBuf + #13#10;
        LexNextLine;
        Continue;
      End;

      Ch := LexLine[LexColNo];

      { Detection de la balise ouvrante <pourcent }
      If (Ch = '<') And (LexColNo < Length(LexLine)) And
         (LexLine[LexColNo + 1] = '%') Then
      Begin
        Inc(LexColNo, 2);

        { Determiner le type : <%=  <%@  ou  <% simple }
        If (LexColNo <= Length(LexLine)) And
           (LexLine[LexColNo] = '=') Then
        Begin
          Kind := TK_PSP_EXPR_OPEN;
          Inc(LexColNo);
        End
        Else If (LexColNo <= Length(LexLine)) And
                (LexLine[LexColNo] = '@') Then
        Begin
          Kind := TK_PSP_DIRECTIVE;
          Inc(LexColNo);
        End
        Else
          Kind := TK_PSP_OPEN;

        { Si du HTML a emettre d abord, mettre le tag en attente }
        If Length(TplHtmlBuf) > 0 Then
        Begin
          TplPending := Kind;
          TplEmitHtml;
          Exit;
        End
        Else
        Begin
          { Pas de HTML, emettre directement le tag PSP }
          TplEmitPSPOpen(Kind);
          Exit;
        End;
      End
      Else
      Begin
        { Caractere HTML normal }
        If Length(TplHtmlBuf) >= MAX_STR Then
        Begin
          { Buffer plein : emettre le fragment }
          TplEmitHtml;
          Exit;
        End;
        TplHtmlBuf := TplHtmlBuf + Ch;
        Inc(LexColNo);
      End;
    End;

    { EOF atteint en mode HTML }
    If Length(TplHtmlBuf) > 0 Then
    Begin
      TplEmitHtml;
      Exit;
    End;

    { Plus de HTML, emettre TK_EOF }
    CurToken.Kind    := TK_EOF;
    CurToken.Val     := '';
    CurToken.Line    := LexLineNo;
    CurToken.Col     := LexColNo;
    CurToken.IntVal  := 0;
    CurToken.RealVal := 0.0;
    PrintToken(CurToken);
  End

  { 3) Mode CODE : deleguer au lexeur Pascal }
  Else
  Begin
    LexNextToken;

    { Si le lexeur retourne pourcent>, repasser en mode HTML }
    If CurToken.Kind = TK_PSP_CLOSE Then
      TplMode := TPL_HTML;
  End;
End;

{ ============================================================
  LITTERAUX ET CONSTANTES PASCAL
  ============================================================ }

{ ---- LabelGen : generateur de labels uniques ---------------- }
Function LabelGen : TString;
Begin
  Inc(LabelGenSeq);
  LabelGen := PSP_LBL_PFX + IntToStr(LabelGenSeq);
End;

{ ---- EmitRaw : ecrire une ligne brute dans le fichier ASM --- }
Procedure EmitRaw(Const S : String);
Begin
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
  DataTab[DataCount].ElemSize  := 0;
  DataTab[DataCount].RecSize   := 0;
  DataAdd := DataCount;
  Inc(DataCount);
End;

{ ---- DataAddStr : creer un label et stocker une chaine ------ }
{ Retourne le label genere (_PSPK_N).                           }
Function DataAddStr(Const S : TString) : TString;
Var
  Lbl : TString;
Begin
  Inc(LabelGenSeq);
  Lbl := PSP_STR_PFX + IntToStr(LabelGenSeq);
  DataAdd(Lbl, DK_STR, 0, S);
  DataAddStr := Lbl;
End;

{ ---- DataAddWord : ajouter un mot 16 bits dans DataTab ------ }
Function DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

{ ---- DataAddByte : ajouter un octet dans DataTab -- }
Function DataAddByte(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddByte := DataAdd(Lbl, DK_BYTE, AIntVal, '');
End;

{ ---- DataAddArray : ajouter un tableau dans DataTab }
{ ECount = nombre d elements, ESz = taille d un element en octets }
Function DataAddArray(Const Lbl : TString;
                ECount, ESz : Integer) : Integer;
Var
  Idx : Integer;
Begin
  Idx := DataAdd(Lbl, DK_ARRAY, 0, '');
  DataTab[Idx].ElemCount := ECount;
  DataTab[Idx].ElemSize  := ESz;
  DataAddArray := Idx;
End;

{ ---- DataAddRec : ajouter un record dans DataTab --- }
{ RSz = taille totale du record en octets                         }
Function DataAddRec(Const Lbl : TString;
                RSz : Integer) : Integer;
Var
  Idx : Integer;
Begin
  Idx := DataAdd(Lbl, DK_REC, 0, '');
  DataTab[Idx].RecSize := RSz;
  DataAddRec := Idx;
End;

{ ---- EmitDataSeg : emettre le segment _DATA complet --------- }
{ Genere _DATA SEGMENT, les buffers internes, les entrees         }
{ dynamiques de DataTab, puis _DATA ENDS.            }
Procedure EmitDataSeg;
Var
  I, J : Integer;
  S    : TString;
  Sz   : Integer;
Begin
  EmitRaw('_DATA   SEGMENT WORD PUBLIC ''DATA''');

  { --- Buffers internes --- }
  EmitComment('--- Buffers internes ---');
  EmitRaw(PSP_RT_PFX + 'CRLF    DB  13,10,0');
  EmitRaw(PSP_RT_PFX + 'STRBUF  DB  512 DUP(0)');
  EmitRaw(PSP_RT_PFX + 'CHRBUF  DB  2 DUP(0)');
  EmitRaw(PSP_RT_PFX + 'NUMBUF  DB  12 DUP(0)');
  EmitRaw(PSP_RT_PFX + 'TRUE_S  DB  ''TRUE'',0');
  EmitRaw(PSP_RT_PFX + 'FALSE_S DB  ''FALSE'',0');
  EmitRaw(PSP_RT_PFX + 'HEAP    DB  4096 DUP(0)');
  EmitRaw(PSP_RT_PFX + 'HEAPTOP DW  OFFSET ' + PSP_RT_PFX + 'HEAP');
  EmitRaw(PSP_RT_PFX + 'SEED    DW  1');
  { Variables exception handler et messages panic }
  EmitRaw(PSP_EX_PFX + 'HANDLER DW  0');
  EmitRaw(PSP_EX_PFX + 'SAVESP  DW  0');
  EmitRaw(PSP_EX_PFX + 'SAVEBP  DW  0');
  EmitRaw(PSP_RT_PFX + 'DIV0MSG DB  ''Runtime error: Division by zero'',0');
  EmitRaw(PSP_RT_PFX + 'PANICMSG DB 0');
  EmitBlankLine;

  { --- Entrees dynamiques de DataTab --- }
  If DataCount > 0 Then
    EmitComment('--- Donnees du programme ---');
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
          { Doubler les apostrophes pour syntaxe MASM }
          S := '';
          For J := 1 To Length(DataTab[I].StrVal) Do
          Begin
            If DataTab[I].StrVal[J] = '''' Then
              S := S + ''''''
            Else
              S := S + DataTab[I].StrVal[J];
          End;
          EmitRaw(DataTab[I].LblName + '  DB  ''' + S + ''',0');
        End;
      DK_ARRAY :
        Begin
          { Tableau : DW/DB elem_count DUP(0) selon taille element }
          Sz := DataTab[I].ElemSize;
          If Sz <= 1 Then
            EmitRaw(DataTab[I].LblName + '  DB  ' +
                    IntToStr(DataTab[I].ElemCount) + ' DUP(0)')
          Else If Sz = 2 Then
            EmitRaw(DataTab[I].LblName + '  DW  ' +
                    IntToStr(DataTab[I].ElemCount) + ' DUP(0)')
          Else
            EmitRaw(DataTab[I].LblName + '  DB  ' +
                    IntToStr(DataTab[I].ElemCount * Sz) + ' DUP(0)');
        End;
      DK_REC :
        Begin
          { Record : DB rec_size DUP(0) }
          EmitRaw(DataTab[I].LblName + '  DB  ' +
                  IntToStr(DataTab[I].RecSize) + ' DUP(0)');
        End;
    End;
  End;

  EmitRaw('_DATA   ENDS');
End;

{ ---- LitEval : evaluer un token litteral en TExprVal -------- }
{ Gere : TK_INTEGER, TK_REAL (tronque+warn), TK_STRING,         }
{        TK_CHAR, TK_KEYWORD (true/false/nil).                  }
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Var
  Lw : TString;
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;

  Case T.Kind Of
    { --- Entiers (decimaux et hexadecimaux) --- }
    TK_INTEGER :
    Begin
      Res.Kind    := EK_IMM;
      Res.ImmVal  := T.IntVal;
      Res.TypeIdx := TY_IDX_INTEGER;
    End;

    { --- Reels : tronquer en entier + avertissement --- }
    TK_REAL :
    Begin
      WarnMsg('reel ' + T.Val + ' tronque en entier');
      Res.Kind    := EK_IMM;
      Res.ImmVal  := Trunc(T.RealVal);
      Res.TypeIdx := TY_IDX_INTEGER;
    End;

    { --- Chaines : stocker en DATA, retourner index DataTab --- }
    TK_STRING :
    Begin
      DataAddStr(T.Val);
      Res.Kind    := EK_AX;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STRING;
      Res.SymIdx  := DataCount - 1;  { index de l entree dans DataTab }
    End;

    { --- Caracteres : valeur ordinale dans ImmVal --- }
    TK_CHAR :
    Begin
      If Length(T.Val) = 1 Then
      Begin
        Res.Kind    := EK_IMM;
        Res.ImmVal  := Ord(T.Val[1]);
        Res.TypeIdx := TY_IDX_CHAR;
      End
      Else
      Begin
        { Multi-caractere (#13#10 etc.) : traiter comme chaine }
        DataAddStr(T.Val);
        Res.Kind    := EK_AX;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_STRING;
      End;
    End;

    { --- Mots-cles speciaux : true, false, nil --- }
    TK_KEYWORD :
    Begin
      Lw := T.Val;
      If Lw = 'true' Then
      Begin
        Res.Kind    := EK_IMM;
        Res.ImmVal  := 1;
        Res.TypeIdx := TY_IDX_BOOLEAN;
      End
      Else If Lw = 'false' Then
      Begin
        Res.Kind    := EK_IMM;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_BOOLEAN;
      End
      Else If Lw = 'nil' Then
      Begin
        Res.Kind    := EK_IMM;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_NIL;
      End;
    End;
  Else
    { Token non reconnu comme litteral }
    Res.Kind := EK_NONE;
  End;
End;

{ ---- ParseConstDecl : analyser un bloc const ---------------- }
{ Syntaxe : const Ident = Expr;                                 }
{           const Ident : Type = Expr;                          }
{ Apres le mot-cle 'const', peut contenir plusieurs constantes. }
Procedure ParseConstDecl;
Var
  CName    : TString;
  CType    : TString;
  IsTyped  : Boolean;
  Ev       : TExprVal;
  Idx      : Integer;
  DIdx     : Integer;
  ResTIdx  : Integer;
Begin
  { Le mot-cle 'const' a deja ete consomme par l appelant }
  { Boucle : tant qu on voit un identificateur, on parse une constante }
  While (CurToken.Kind = TK_IDENT) Or
        ((CurToken.Kind = TK_KEYWORD) And
         ((CurToken.Val = 'integer') Or (CurToken.Val = 'word') Or
          (CurToken.Val = 'byte') Or (CurToken.Val = 'char') Or
          (CurToken.Val = 'boolean') Or (CurToken.Val = 'string') Or
          (CurToken.Val = 'real'))) Do
  Begin
    { Nom de la constante }
    If CurToken.Kind <> TK_IDENT Then
      Break;
    CName := CurToken.Val;
    TplNextToken;

    { Constante typee ? const X : Integer = 42; }
    IsTyped := False;
    CType   := '';
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    Begin
      IsTyped := True;
      TplNextToken;
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
      Begin
        CType := CurToken.Val;
        TplNextToken;
      End
      Else
        WarnMsg('type attendu apres '':'' dans la constante ' + CName);
    End;

    { Signe = }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
      TplNextToken
    Else
    Begin
      WarnMsg('''='' attendu dans la declaration de constante ' + CName);
      Break;
    End;

    { Valeur : expression constante (pliage de constantes) }
    ParseExpr(Ev);

    { Enregistrer la constante dans la table des symboles }
    If IsTyped Then
    Begin
      { Resoudre le nom de type }
      ResTIdx := TypeResolve(CType);
      If ResTIdx = TY_UNKNOWN Then
        WarnMsg('type inconnu: ' + CType);
      { Verifier compatibilite type declare vs valeur }
      If (ResTIdx <> TY_UNKNOWN) And (Ev.TypeIdx <> TY_UNKNOWN) Then
      Begin
        If Not TypeCompatible(ResTIdx, Ev.TypeIdx) Then
          WarnMsg('type incompatible pour la constante ' + CName);
      End;
      { Constante typee -> entree DATA + symbole SC_TYPED_CONST }
      If Ev.TypeIdx = TY_IDX_STRING Then
      Begin
        If Opts.DebugMode Then
          WriteLn('  CONST_TYPED: ', CName, ' : ', CType,
                  ' = ''', DataTab[Ev.SymIdx].StrVal, '''');
        DIdx := DataAdd(PSP_VAR_PFX + CName, DK_WORD, 0,
                        DataTab[Ev.SymIdx].LblName);
      End
      Else
      Begin
        If Opts.DebugMode Then
          WriteLn('  CONST_TYPED: ', CName, ' : ', CType,
                  ' = ', Ev.ImmVal);
        DIdx := DataAddWord(PSP_VAR_PFX + CName, Ev.ImmVal);
      End;
      Idx := SymAdd(CName, SC_TYPED_CONST, Ev.TypeIdx);
      If Idx >= 0 Then
      Begin
        SymTab[Idx].ImmVal  := Ev.ImmVal;
        SymTab[Idx].DataIdx := DIdx;
      End;
    End
    Else
    Begin
      { Constante non-typee -> substitution : symbole SC_CONST }
      { Valeur immediate stockee dans ImmVal de TSymRec         }
      If Ev.TypeIdx = TY_IDX_STRING Then
      Begin
        If Opts.DebugMode Then
          WriteLn('  CONST: ', CName,
                  ' = ''', DataTab[Ev.SymIdx].StrVal, '''');
        DIdx := DataAdd(PSP_VAR_PFX + CName, DK_WORD, 0,
                        DataTab[Ev.SymIdx].LblName);
        Idx := SymAdd(CName, SC_CONST, Ev.TypeIdx);
        If Idx >= 0 Then
        Begin
          SymTab[Idx].ImmVal  := 0;
          SymTab[Idx].DataIdx := DIdx;
        End;
      End
      Else
      Begin
        If Opts.DebugMode Then
          WriteLn('  CONST: ', CName, ' = ', Ev.ImmVal);
        Idx := SymAdd(CName, SC_CONST, Ev.TypeIdx);
        If Idx >= 0 Then
        Begin
          SymTab[Idx].ImmVal  := Ev.ImmVal;
          SymTab[Idx].DataIdx := -1;
        End;
      End;
    End;

    { Point-virgule }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
  End;
End;

{ ============================================================
  CONSTANTES, TYPES DEFINIS ET ENUMERATIONS [IMPLEMENTE]
  ============================================================ }

{ ---- ParseTypeDecl : analyser un bloc type -------------------- }
{ Syntaxe : type TName = TypeDef;                                  }
{   Alias     : type TEntier = Integer;                            }
{   Enum      : type TCouleur = (Rouge, Vert, Bleu);               }
{   Sous-plage: type TJour = 1..31;                                }
{   Pointeur  : type PInt = ^Integer;                              }
{ Le mot-cle 'type' a deja ete consomme par l appelant.           }
Procedure ParseTypeDecl;
Var
  TName    : TString;
  NewTIdx  : Integer;
  BaseTIdx : Integer;
  BaseStr  : TString;
  Idx      : Integer;
  OrdVal   : Integer;
  EnName   : TString;
  LoVal    : LongInt;
  Ev       : TExprVal;
Begin
  { Boucle : plusieurs declarations type possibles }
  While (CurToken.Kind = TK_IDENT) Do
  Begin
    TName := CurToken.Val;
    TplNextToken;

    { Signe = : si absent, c est une variable pas un type -> sortir }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
      TplNextToken
    Else
    Begin
      { Ce n est pas une declaration de type, restaurer l ident }
      PendingAssignName := TName;
      HasPendingAssign  := True;
      Break;
    End;

    { --- Enumeration : (val1, val2, ...) --- }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      TplNextToken;  { consommer ( }
      If TypeCount >= MAX_TYPE Then
      Begin
        WarnMsg('nombre maximal de types atteint');
        Break;
      End;
      NewTIdx := TypeCount;
      Inc(TypeCount);
      TypeTab[NewTIdx].Kind        := TKP_ENUM;
      TypeTab[NewTIdx].Size        := 2;
      TypeTab[NewTIdx].BaseTypeIdx := TY_IDX_INTEGER;
      TypeTab[NewTIdx].Lo          := 0;
      TypeTab[NewTIdx].Hi          := 0;
      TypeTab[NewTIdx].FieldCount  := 0;
      TypeTab[NewTIdx].EnumCount   := 0;

      { Enregistrer le nom de type dans SymTab }
      Idx := SymAdd(TName, SC_TYPE, NewTIdx);
      If Idx >= 0 Then
        SymTab[Idx].MangledName := PSP_ENUM_PFX + StrUpperCase(TName);

      OrdVal := 0;
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
      Begin
        If CurToken.Kind = TK_IDENT Then
        Begin
          EnName := CurToken.Val;
          TplNextToken;

          { Ajouter la valeur d enumeration dans SymTab }
          Idx := SymAdd(EnName, SC_ENUM_VAL, NewTIdx);
          If Idx >= 0 Then
          Begin
            SymTab[Idx].ImmVal      := OrdVal;
            SymTab[Idx].MangledName := PSP_ENUM_PFX +
                                         StrUpperCase(EnName);
          End;

          { Ajouter dans TypeTab.Enums }
          If TypeTab[NewTIdx].EnumCount < MAX_ENUM Then
          Begin
            TypeTab[NewTIdx].Enums[TypeTab[NewTIdx].EnumCount].Name := EnName;
            TypeTab[NewTIdx].Enums[TypeTab[NewTIdx].EnumCount].Value := OrdVal;
            Inc(TypeTab[NewTIdx].EnumCount);
          End;

          If Opts.DebugMode Then
            WriteLn('  ENUM: ', TName, '.', EnName, ' = ', OrdVal);

          Inc(OrdVal);
        End
        Else
        Begin
          WarnMsg('identificateur attendu dans enumeration');
          TplNextToken;
        End;

        { Virgule entre valeurs }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          TplNextToken;
      End;

      { Borne sup }
      If OrdVal > 0 Then
        TypeTab[NewTIdx].Hi := OrdVal - 1;

      { Consommer ) }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        TplNextToken;

      { Point-virgule }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        TplNextToken;

      Continue;
    End;

    { --- Pointeur : ^TypeBase --- }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '^') Then
    Begin
      TplNextToken;  { consommer ^ }
      BaseStr := '';
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
      Begin
        BaseStr := CurToken.Val;
        TplNextToken;
      End;
      BaseTIdx := TypeResolve(BaseStr);
      If BaseTIdx = TY_UNKNOWN Then
        BaseTIdx := TY_IDX_INTEGER;

      If TypeCount >= MAX_TYPE Then
      Begin
        WarnMsg('nombre maximal de types atteint');
        Break;
      End;
      NewTIdx := TypeCount;
      Inc(TypeCount);
      TypeTab[NewTIdx].Kind        := TKP_POINTER;
      TypeTab[NewTIdx].Size        := 2;
      TypeTab[NewTIdx].BaseTypeIdx := BaseTIdx;
      TypeTab[NewTIdx].Lo          := 0;
      TypeTab[NewTIdx].Hi          := 0;
      TypeTab[NewTIdx].FieldCount  := 0;
      TypeTab[NewTIdx].EnumCount   := 0;

      Idx := SymAdd(TName, SC_TYPE, NewTIdx);
      If Idx >= 0 Then
        SymTab[Idx].MangledName := StrUpperCase(TName);

      If Opts.DebugMode Then
        WriteLn('  TYPE_PTR: ', TName, ' = ^', BaseStr);

      { Point-virgule }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        TplNextToken;

      Continue;
    End;

    { --- type TArr = array[lo..hi] of TypeElem --- }
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'array') Then
    Begin
      TplNextToken;  { consommer array }

      { Consommer [ }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
        TplNextToken
      Else
        WarnMsg('''['' attendu apres array');

      { Borne inferieure }
      LoVal := 0;
      If CurToken.Kind = TK_INTEGER Then
      Begin
        LoVal := CurToken.IntVal;
        TplNextToken;
      End
      Else If (CurToken.Kind = TK_IDENT) Or
              (CurToken.Kind = TK_KEYWORD) Then
      Begin
        Idx := SymFind(CurToken.Val);
        If (Idx >= 0) And
           (SymTab[Idx].Cat In [SC_CONST, SC_ENUM_VAL]) Then
          LoVal := SymTab[Idx].ImmVal;
        TplNextToken;
      End;

      { Consommer .. }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '..') Then
        TplNextToken
      Else
        WarnMsg('''..'' attendu dans declaration array');

      { Borne superieure }
      Ev.ImmVal := 0;
      If CurToken.Kind = TK_INTEGER Then
      Begin
        Ev.ImmVal := CurToken.IntVal;
        TplNextToken;
      End
      Else If (CurToken.Kind = TK_IDENT) Or
              (CurToken.Kind = TK_KEYWORD) Then
      Begin
        Idx := SymFind(CurToken.Val);
        If (Idx >= 0) And
           (SymTab[Idx].Cat In [SC_CONST, SC_ENUM_VAL]) Then
          Ev.ImmVal := SymTab[Idx].ImmVal;
        TplNextToken;
      End;

      { Consommer ] }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
        TplNextToken
      Else
        WarnMsg(''']'' attendu');

      { Consommer of }
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'of') Then
        TplNextToken
      Else
        WarnMsg('''of'' attendu apres array[...]');

      { Lire le type element }
      BaseStr := '';
      If (CurToken.Kind = TK_KEYWORD) Or
         (CurToken.Kind = TK_IDENT) Then
      Begin
        BaseStr := CurToken.Val;
        TplNextToken;
      End;

      BaseTIdx := TypeResolve(BaseStr);
      If BaseTIdx = TY_UNKNOWN Then
        BaseTIdx := TY_IDX_INTEGER;

      If TypeCount >= MAX_TYPE Then
      Begin
        WarnMsg('nombre maximal de types atteint');
        Break;
      End;
      NewTIdx := TypeCount;
      Inc(TypeCount);
      TypeTab[NewTIdx].Kind        := TKP_ARRAY;
      TypeTab[NewTIdx].Size        := (Ev.ImmVal - LoVal + 1) *
                                       TypeSizeof(BaseTIdx);
      TypeTab[NewTIdx].BaseTypeIdx := BaseTIdx;
      TypeTab[NewTIdx].Lo          := LoVal;
      TypeTab[NewTIdx].Hi          := Ev.ImmVal;
      TypeTab[NewTIdx].FieldCount  := 0;
      TypeTab[NewTIdx].EnumCount   := 0;

      Idx := SymAdd(TName, SC_TYPE, NewTIdx);
      If Idx >= 0 Then
        SymTab[Idx].MangledName := StrUpperCase(TName);

      If Opts.DebugMode Then
        WriteLn('  TYPE_ARRAY: ', TName,
                ' = array[', LoVal, '..', Ev.ImmVal,
                '] of ', BaseStr);

      { Point-virgule }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        TplNextToken;

      Continue;
    End;

    { --- type TRec = record ... end --- }
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'record') Then
    Begin
      TplNextToken;  { consommer record }

      If TypeCount >= MAX_TYPE Then
      Begin
        WarnMsg('nombre maximal de types atteint');
        Break;
      End;
      NewTIdx := TypeCount;
      Inc(TypeCount);
      TypeTab[NewTIdx].Kind        := TKP_RECORD;
      TypeTab[NewTIdx].Size        := 0;
      TypeTab[NewTIdx].BaseTypeIdx := TY_IDX_INTEGER;
      TypeTab[NewTIdx].Lo          := 0;
      TypeTab[NewTIdx].Hi          := 0;
      TypeTab[NewTIdx].FieldCount  := 0;
      TypeTab[NewTIdx].EnumCount   := 0;

      { Parser les champs : ident[, ident...]: Type; ... end }
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_KEYWORD) And
                 (CurToken.Val = 'end')) Do
      Begin
        { Lire un ou plusieurs noms de champs }
        If (CurToken.Kind = TK_IDENT) Or
           (CurToken.Kind = TK_KEYWORD) Then
        Begin
          BaseStr := CurToken.Val;   { reutiliser BaseStr comme nom champ }
          TplNextToken;

          { Virgules supplementaires }
          { Pour simplifier, on gere un seul champ par ligne }
          { multi-champs par ligne }

          { Deux-points }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
            TplNextToken
          Else
            WarnMsg(''':'' attendu apres nom de champ');

          { Lire le type du champ }
          BaseTIdx := TY_IDX_INTEGER;
          If (CurToken.Kind = TK_KEYWORD) Or
             (CurToken.Kind = TK_IDENT) Then
          Begin
            BaseTIdx := TypeResolve(CurToken.Val);
            If BaseTIdx = TY_UNKNOWN Then
            Begin
              WarnMsg('type de champ inconnu: ' + CurToken.Val);
              BaseTIdx := TY_IDX_INTEGER;
            End;
            TplNextToken;
          End;

          { Ajouter le champ dans TypeTab }
          If TypeTab[NewTIdx].FieldCount < MAX_FIELD Then
          Begin
            TypeTab[NewTIdx].Fields[TypeTab[NewTIdx].FieldCount].Name :=
              StrLowerCase(BaseStr);
            TypeTab[NewTIdx].Fields[TypeTab[NewTIdx].FieldCount].TypeIdx :=
              BaseTIdx;
            TypeTab[NewTIdx].Fields[TypeTab[NewTIdx].FieldCount].Offset :=
              TypeTab[NewTIdx].Size;
            Inc(TypeTab[NewTIdx].FieldCount);

            { Incrementer la taille du record }
            TypeTab[NewTIdx].Size :=
              TypeTab[NewTIdx].Size + TypeSizeof(BaseTIdx);

            If Opts.DebugMode Then
              WriteLn('  FIELD: ', BaseStr, ' : type=', BaseTIdx,
                      ' ofs=',
                      TypeTab[NewTIdx].Fields[
                        TypeTab[NewTIdx].FieldCount - 1].Offset);
          End
          Else
            WarnMsg('trop de champs dans le record');

          { Point-virgule entre champs }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
            TplNextToken;
        End
        Else
        Begin
          { Token inattendu dans record }
          WarnMsg('identificateur attendu dans record');
          TplNextToken;
        End;
      End;

      { Consommer end }
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'end') Then
        TplNextToken;

      { Enregistrer dans SymTab }
      Idx := SymAdd(TName, SC_TYPE, NewTIdx);
      If Idx >= 0 Then
        SymTab[Idx].MangledName := StrUpperCase(TName);

      If Opts.DebugMode Then
        WriteLn('  TYPE_RECORD: ', TName,
                ' size=', TypeTab[NewTIdx].Size,
                ' fields=', TypeTab[NewTIdx].FieldCount);

      { Point-virgule }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        TplNextToken;

      Continue;
    End;

    { --- Sous-plage ou alias --- }
    { Essayer de detecter un litteral entier suivi de .. }
    If (CurToken.Kind = TK_INTEGER) Then
    Begin
      { Possible sous-plage : lo..hi }
      LoVal := CurToken.IntVal;
      TplNextToken;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '..') Then
      Begin
        TplNextToken;  { consommer .. }
        ParseExpr(Ev);
        If TypeCount >= MAX_TYPE Then
        Begin
          WarnMsg('nombre maximal de types atteint');
          Break;
        End;
        NewTIdx := TypeCount;
        Inc(TypeCount);
        TypeTab[NewTIdx].Kind        := TKP_SUBRANGE;
        TypeTab[NewTIdx].Size        := 2;
        TypeTab[NewTIdx].BaseTypeIdx := TY_IDX_INTEGER;
        TypeTab[NewTIdx].Lo          := LoVal;
        TypeTab[NewTIdx].Hi          := Ev.ImmVal;
        TypeTab[NewTIdx].FieldCount  := 0;
        TypeTab[NewTIdx].EnumCount   := 0;

        Idx := SymAdd(TName, SC_TYPE, NewTIdx);
        If Idx >= 0 Then
          SymTab[Idx].MangledName := StrUpperCase(TName);

        If Opts.DebugMode Then
          WriteLn('  TYPE_SUBRANGE: ', TName, ' = ',
                  LoVal, '..', Ev.ImmVal);

        { Point-virgule }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          TplNextToken;

        Continue;
      End
      Else
      Begin
        { Ce n est pas une sous-plage, c est un alias bizarre }
        WarnMsg('declaration de type inattendue pour ' + TName);
        { Point-virgule }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          TplNextToken;
        Continue;
      End;
    End;

    { --- Alias de type : type TEntier = Integer; --- }
    { Ou un nom de type existant }
    BaseStr := '';
    If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
    Begin
      BaseStr := CurToken.Val;
      TplNextToken;

      { Verifier si c est un sous-intervalle avec ident..hi }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '..') Then
      Begin
        { type T = ident..hi }
        { Resoudre ident comme une constante }
        Idx := SymFind(BaseStr);
        If (Idx >= 0) And (SymTab[Idx].Cat In [SC_CONST, SC_ENUM_VAL]) Then
          LoVal := SymTab[Idx].ImmVal
        Else
          LoVal := 0;
        TplNextToken;  { consommer .. }
        ParseExpr(Ev);
        If TypeCount >= MAX_TYPE Then
        Begin
          WarnMsg('nombre maximal de types atteint');
          Break;
        End;
        NewTIdx := TypeCount;
        Inc(TypeCount);
        TypeTab[NewTIdx].Kind        := TKP_SUBRANGE;
        TypeTab[NewTIdx].Size        := 2;
        TypeTab[NewTIdx].BaseTypeIdx := TY_IDX_INTEGER;
        TypeTab[NewTIdx].Lo          := LoVal;
        TypeTab[NewTIdx].Hi          := Ev.ImmVal;
        TypeTab[NewTIdx].FieldCount  := 0;
        TypeTab[NewTIdx].EnumCount   := 0;

        Idx := SymAdd(TName, SC_TYPE, NewTIdx);
        If Idx >= 0 Then
          SymTab[Idx].MangledName := StrUpperCase(TName);

        If Opts.DebugMode Then
          WriteLn('  TYPE_SUBRANGE: ', TName, ' = ',
                  LoVal, '..', Ev.ImmVal);

        { Point-virgule }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          TplNextToken;
        Continue;
      End;

      { Simple alias de type }
      BaseTIdx := TypeResolve(BaseStr);
      If BaseTIdx = TY_UNKNOWN Then
      Begin
        WarnMsg('type inconnu dans alias: ' + BaseStr);
        BaseTIdx := TY_IDX_INTEGER;
      End;

      Idx := SymAdd(TName, SC_TYPE, BaseTIdx);
      If Idx >= 0 Then
        SymTab[Idx].MangledName := StrUpperCase(TName);

      If Opts.DebugMode Then
        WriteLn('  TYPE_ALIAS: ', TName, ' = ', BaseStr,
                ' (idx=', BaseTIdx, ')');
    End
    Else
    Begin
      WarnMsg('definition de type attendue pour ' + TName);
    End;

    { Point-virgule }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
  End;
End;

{ ---- ParseIncDecStmt : Inc(x) / Inc(x,n) / Dec(x) / Dec(x,n) }
{ IsInc = True pour Inc, False pour Dec.                          }
{ Le mot 'inc'/'dec' a deja ete consomme.                         }
Procedure ParseIncDecStmt(IsInc : Boolean);
Var
  SIdx    : Integer;
  VarRef  : TString;
  ArgExpr : TExprVal;
  HasStep : Boolean;
Begin
  { Consommer ( }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    TplNextToken
  Else
  Begin
    WarnMsg('''('' attendu apres Inc/Dec');
    Exit;
  End;

  { Premier argument : variable }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    WarnMsg('variable attendue dans Inc/Dec');
    { Sauter jusqu a ) }
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
      TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      TplNextToken;
    Exit;
  End;

  SIdx := SymFind(CurToken.Val);
  TplNextToken;

  If SIdx < 0 Then
  Begin
    WarnMsg('symbole non declare dans Inc/Dec');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      TplNextToken;
    Exit;
  End;

  { Construire la reference memoire }
  Case SymTab[SIdx].Cat Of
    SC_VAR :
    Begin
      If SymTab[SIdx].IsLocal Then
        VarRef := 'WORD PTR ' + BPOfs(SymTab[SIdx].Offset)
      Else
        VarRef := 'WORD PTR [' + SymTab[SIdx].MangledName + ']';
    End;
    SC_PARAM :
      VarRef := 'WORD PTR ' + BPOfs(SymTab[SIdx].Offset);
    SC_VARPARAM :
    Begin
      { Parametre var : deref via BX }
      EmitInstrAB('MOV', 'BX',
        'WORD PTR ' + BPOfs(SymTab[SIdx].Offset));
      VarRef := 'WORD PTR [BX]';
    End;
  Else
    Begin
      WarnMsg('variable attendue pour Inc/Dec');
      VarRef := 'AX';
    End;
  End;

  { Deuxieme argument optionnel : pas }
  HasStep := False;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
  Begin
    TplNextToken;  { consommer , }
    HasStep := True;
    ParseExpr(ArgExpr);
    ExprFlushToAX(ArgExpr);
  End;

  If HasStep Then
  Begin
    If IsInc Then
      EmitInstrAB('ADD', VarRef, 'AX')
    Else
      EmitInstrAB('SUB', VarRef, 'AX');
  End
  Else
  Begin
    If IsInc Then
      EmitInstrA('INC', VarRef)
    Else
      EmitInstrA('DEC', VarRef);
  End;

  { Consommer ) }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    TplNextToken;

  { Point-virgule optionnel }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    TplNextToken;
End;

{ ============================================================
  VARIABLES ET AFFECTATIONS [IMPLEMENTE]
  ============================================================ }

{ ---- ParseVarDecl : analyser un bloc var ---------------------- }
{ Syntaxe : var a, b, c: Integer; s: String;                      }
{ Gere les declarations multiples sur une meme ligne.             }
{ Scope global -> entree DataTab, scope local -> offset cadre.    }
Procedure ParseVarDecl;
Var
  Names    : Array[0..MAX_PARAM - 1] Of TString;
  NCount   : Integer;
  TName    : TString;
  TIdx     : Integer;
  TSz      : Integer;
  I, Idx   : Integer;
  DIdx     : Integer;
  { Tableaux }
  ArrLo, ArrHi   : LongInt;
  ArrCount        : LongInt;
  ArrSize         : LongInt;
  ElemTIdx        : Integer;
  NewArrTIdx      : Integer;
  ElemTName       : TString;
  ElemSz          : Integer;
Begin
  { Le mot-cle 'var' a deja ete consomme par l appelant }
  HasPendingAssign := False;
  While (CurToken.Kind = TK_IDENT) Do
  Begin
    { Lookahead : lire le premier ident puis verifier le token suivant }
    Names[0] := CurToken.Val;
    NCount := 1;
    TplNextToken;

    { Si := suit, c est une affectation, pas une declaration var }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    Begin
      PendingAssignName := Names[0];
      HasPendingAssign  := True;
      Exit;  { Quitter ParseVarDecl, laisser CurToken sur := }
    End;

    { Collecter d eventuels noms supplementaires separes par virgule }
    While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
    Begin
      TplNextToken;
      If CurToken.Kind = TK_IDENT Then
      Begin
        If NCount < MAX_PARAM Then
        Begin
          Names[NCount] := CurToken.Val;
          Inc(NCount);
        End
        Else
          WarnMsg('trop de variables dans une declaration');
        TplNextToken;
      End
      Else
      Begin
        WarnMsg('identificateur attendu apres virgule');
        Break;
      End;
    End;

    { Deux-points + nom de type }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      TplNextToken
    Else
    Begin
      WarnMsg(''':'' attendu apres le(s) nom(s) de variable');
      { Sauter jusqu au prochain ; }
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
        TplNextToken;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        TplNextToken;
      Continue;
    End;

    { --- Detection array[lo..hi] of TypeElem --- }
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'array') Then
    Begin
      TplNextToken;  { consommer array }

      { Consommer [ }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
        TplNextToken
      Else
        WarnMsg('''['' attendu apres array');

      { Borne inferieure }
      ArrLo := 0;
      If CurToken.Kind = TK_INTEGER Then
      Begin
        ArrLo := CurToken.IntVal;
        TplNextToken;
      End
      Else If (CurToken.Kind = TK_IDENT) Or
              (CurToken.Kind = TK_KEYWORD) Then
      Begin
        Idx := SymFind(CurToken.Val);
        If (Idx >= 0) And
           (SymTab[Idx].Cat In [SC_CONST, SC_ENUM_VAL]) Then
          ArrLo := SymTab[Idx].ImmVal
        Else
          WarnMsg('constante attendue pour borne inferieure');
        TplNextToken;
      End;

      { Consommer .. }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '..') Then
        TplNextToken
      Else
        WarnMsg('''..'' attendu dans declaration array');

      { Borne superieure }
      ArrHi := 0;
      If CurToken.Kind = TK_INTEGER Then
      Begin
        ArrHi := CurToken.IntVal;
        TplNextToken;
      End
      Else If (CurToken.Kind = TK_IDENT) Or
              (CurToken.Kind = TK_KEYWORD) Then
      Begin
        Idx := SymFind(CurToken.Val);
        If (Idx >= 0) And
           (SymTab[Idx].Cat In [SC_CONST, SC_ENUM_VAL]) Then
          ArrHi := SymTab[Idx].ImmVal
        Else
          WarnMsg('constante attendue pour borne superieure');
        TplNextToken;
      End;

      { Consommer ] }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
        TplNextToken
      Else
        WarnMsg(''']'' attendu');

      { Consommer of }
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'of') Then
        TplNextToken
      Else
        WarnMsg('''of'' attendu apres array[...]');

      { Lire le type element }
      ElemTName := '';
      If (CurToken.Kind = TK_KEYWORD) Or
         (CurToken.Kind = TK_IDENT) Then
      Begin
        ElemTName := CurToken.Val;
        TplNextToken;
      End
      Else
        WarnMsg('type element attendu');

      ElemTIdx := TypeResolve(ElemTName);
      If ElemTIdx = TY_UNKNOWN Then
      Begin
        WarnMsg('type element inconnu: ' + ElemTName);
        ElemTIdx := TY_IDX_INTEGER;
      End;
      ElemSz := TypeSizeof(ElemTIdx);

      ArrCount := ArrHi - ArrLo + 1;
      If ArrCount < 1 Then ArrCount := 1;
      ArrSize := ArrCount * ElemSz;

      { Creer entree TypeTab pour ce type array }
      NewArrTIdx := TY_IDX_INTEGER;
      If TypeCount < MAX_TYPE Then
      Begin
        NewArrTIdx := TypeCount;
        Inc(TypeCount);
        TypeTab[NewArrTIdx].Kind        := TKP_ARRAY;
        TypeTab[NewArrTIdx].Size        := ArrSize;
        TypeTab[NewArrTIdx].BaseTypeIdx := ElemTIdx;
        TypeTab[NewArrTIdx].Lo          := ArrLo;
        TypeTab[NewArrTIdx].Hi          := ArrHi;
        TypeTab[NewArrTIdx].FieldCount  := 0;
        TypeTab[NewArrTIdx].EnumCount   := 0;
      End
      Else
        WarnMsg('nombre maximal de types atteint');

      { Enregistrer chaque variable tableau }
      For I := 0 To NCount - 1 Do
      Begin
        Idx := SymAdd(Names[I], SC_VAR, NewArrTIdx);
        If Idx >= 0 Then
        Begin
          If CurScopeLevel = 0 Then
          Begin
            { Tableau global }
            SymTab[Idx].MangledName := PSP_ARR_PFX +
              StrUpperCase(Names[I]);
            DIdx := DataAddArray(
              SymTab[Idx].MangledName, ArrCount, ElemSz);
            SymTab[Idx].DataIdx := DIdx;
            SymTab[Idx].IsLocal := False;
            If Opts.DebugMode Then
              WriteLn('  VAR_ARRAY_GLOBAL: ', Names[I],
                      ' [', ArrLo, '..', ArrHi, '] of ',
                      ElemTName, ' -> ',
                      SymTab[Idx].MangledName);
          End
          Else
          Begin
            { Tableau local : allouer sur la pile }
            Dec(CurFrameOffset, ArrSize);
            SymTab[Idx].Offset  := CurFrameOffset;
            SymTab[Idx].IsLocal := True;
            If Opts.DebugMode Then
              WriteLn('  VAR_ARRAY_LOCAL: ', Names[I],
                      ' [', ArrLo, '..', ArrHi, '] of ',
                      ElemTName, ' -> [BP',
                      CurFrameOffset, ']');
          End;
        End;
      End;

      { Point-virgule }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        TplNextToken;
      Continue;
    End;

    { Lire le nom de type }
    TName := '';
    If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
    Begin
      TName := CurToken.Val;
      TplNextToken;
    End
    Else
      WarnMsg('nom de type attendu');

    { Resoudre le type }
    TIdx := TypeResolve(TName);
    If TIdx = TY_UNKNOWN Then
    Begin
      WarnMsg('type inconnu: ' + TName);
      TIdx := TY_IDX_INTEGER;  { defaut }
    End;
    TSz := TypeSizeof(TIdx);

    { Enregistrer chaque variable }
    For I := 0 To NCount - 1 Do
    Begin
      Idx := SymAdd(Names[I], SC_VAR, TIdx);
      If Idx >= 0 Then
      Begin
        If CurScopeLevel = 0 Then
        Begin
          { Variable globale : ajouter dans DataTab }
          { records utilise DataAddRec }
          If (TIdx >= 0) And (TIdx < TypeCount) And
             (TypeTab[TIdx].Kind = TKP_RECORD) Then
          Begin
            SymTab[Idx].MangledName := PSP_REC_PFX +
              StrUpperCase(Names[I]);
            DIdx := DataAddRec(SymTab[Idx].MangledName, TSz);
            SymTab[Idx].DataIdx := DIdx;
            SymTab[Idx].IsLocal := False;
            If Opts.DebugMode Then
              WriteLn('  VAR_REC_GLOBAL: ', Names[I], ' : ',
                      TName, ' size=', TSz,
                      ' -> ', SymTab[Idx].MangledName);
          End
          Else If TSz = 1 Then
          Begin
            DIdx := DataAddByte(SymTab[Idx].MangledName, 0);
            SymTab[Idx].DataIdx := DIdx;
            SymTab[Idx].IsLocal := False;
            If Opts.DebugMode Then
              WriteLn('  VAR_GLOBAL: ', Names[I], ' : ', TName,
                      ' -> ', SymTab[Idx].MangledName);
          End
          Else
          Begin
            DIdx := DataAddWord(SymTab[Idx].MangledName, 0);
            SymTab[Idx].DataIdx := DIdx;
            SymTab[Idx].IsLocal := False;
            If Opts.DebugMode Then
              WriteLn('  VAR_GLOBAL: ', Names[I], ' : ', TName,
                      ' -> ', SymTab[Idx].MangledName);
          End;
        End
        Else
        Begin
          { Variable locale : allouer sur la pile }
          { Aligner Byte/Char/Boolean sur 2 octets }
          If TSz < 2 Then
            TSz := 2;
          Dec(CurFrameOffset, TSz);
          SymTab[Idx].Offset  := CurFrameOffset;
          SymTab[Idx].IsLocal := True;
          If Opts.DebugMode Then
            WriteLn('  VAR_LOCAL: ', Names[I], ' : ', TName,
                    ' -> [BP', CurFrameOffset, ']');
        End;
      End;
    End;

    { Point-virgule }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
  End;
End;

{ ---- ParseAssignment : analyser une affectation --------------- }
{ Syntaxe : ident := expr ;                                       }
{ Le nom de la variable a ete lu par l appelant.                  }
{ CurToken est sur :=                                             }
Procedure ParseAssignment(Const VarName : TString);
Var
  SIdx : Integer;
  Ev   : TExprVal;
Begin
  { Affectation a la valeur de retour : FuncName := expr }
  If (CurFuncName <> '') And
     ((StrLowerCase(VarName) = CurFuncName) Or
      (StrLowerCase(VarName) = 'result')) Then
  Begin
    { Consommer := }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
      TplNextToken
    Else
    Begin
      WarnMsg(''':='' attendu pour l''affectation');
      Exit;
    End;

    EmitComment('assign retval ' + VarName);
    ParseExpr(Ev);
    ExprFlushToAX(Ev);
    EmitInstrAB('MOV',
      'WORD PTR ' + BPOfs(CurFuncRetOfs), 'AX');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { Rechercher la variable }
  SIdx := SymFind(VarName);
  If SIdx < 0 Then
  Begin
    WarnMsg('variable non declaree: ' + VarName);
    { Sauter jusqu au ; }
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
      TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { Verifier que c est bien une variable/param }
  If Not (SymTab[SIdx].Cat In [SC_VAR, SC_PARAM, SC_VARPARAM,
                                 SC_TYPED_CONST]) Then
  Begin
    WarnMsg('cible d''affectation invalide: ' + VarName);
  End;

  { Consommer := }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    TplNextToken
  Else
  Begin
    WarnMsg(''':='' attendu pour l''affectation');
    Exit;
  End;

  EmitComment('assign ' + VarName);

  { Evaluer l expression }
  ParseExpr(Ev);

  { Verification de compatibilite de type (erreur) }
  If (SymTab[SIdx].TypeIdx <> TY_UNKNOWN) And
     (Ev.TypeIdx <> TY_UNKNOWN) Then
  Begin
    If Not TypeCompatible(SymTab[SIdx].TypeIdx, Ev.TypeIdx) Then
      ErrorMsg('type incompatible dans l''affectation de ' + VarName);
  End;

  { Materialiser la valeur dans AX }
  ExprFlushToAX(Ev);

  { Stocker AX dans la cible }
  If SymTab[SIdx].IsLocal Then
  Begin
    If SymTab[SIdx].Cat = SC_VARPARAM Then
    Begin
      { Parametre var (reference) : MOV BX,[BP+n] / MOV [BX], AX }
      EmitInstrAB('MOV', 'BX',
        'WORD PTR ' + BPOfs(SymTab[SIdx].Offset));
      EmitInstrAB('MOV', 'WORD PTR [BX]', 'AX');
    End
    Else
    Begin
      { Variable locale : MOV [BP-n], AX }
      If TypeSizeof(SymTab[SIdx].TypeIdx) = 1 Then
        EmitInstrAB('MOV',
          'BYTE PTR ' + BPOfs(SymTab[SIdx].Offset), 'AL')
      Else
        EmitInstrAB('MOV',
          'WORD PTR ' + BPOfs(SymTab[SIdx].Offset), 'AX');
    End;
  End
  Else
  Begin
    { Variable globale : MOV [_PSP_xxx], AX }
    If TypeSizeof(SymTab[SIdx].TypeIdx) = 1 Then
      EmitInstrAB('MOV',
        'BYTE PTR [' + SymTab[SIdx].MangledName + ']', 'AL')
    Else
      EmitInstrAB('MOV',
        'WORD PTR [' + SymTab[SIdx].MangledName + ']', 'AX');
  End;

  { Point-virgule }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    TplNextToken;
End;

{ ============================================================
  WRITE / WRITELN ET EMISSION HTML [IMPLEMENTE]
  ============================================================ }

{ ---- EmitPrintAX : emettre code pour afficher AX selon type -- }
{ TypeIdx determine le mode d affichage :                        }
{   String  -> CALL _PSPRT_PRINT  (AX = ptr ASCIIZ)             }
{   Integer/Word/Byte -> CALL _PSPRT_NUMTOSTR + _PSPRT_PRINT    }
{   Boolean -> CMP AX,0 + branche TRUE/FALSE                    }
{   Char    -> MOV DL,AL / MOV AH,02h / INT 21h                 }
Procedure EmitPrintAX(TypeIdx : Integer);
Var
  LblFalse, LblDone : TString;
Begin
  If TypeIdx = TY_IDX_STRING Then
  Begin
    { AX = pointeur ASCIIZ -> imprimer directement }
    EmitInstrAB('MOV', 'SI', 'AX');
    EmitCall(PSP_RT_PFX + 'PRINTSTR');
  End
  Else If TypeIdx = TY_IDX_CHAR Then
  Begin
    { Afficher un caractere via DOS INT 21h/02h }
    EmitInstrAB('MOV', 'DL', 'AL');
    EmitInstrAB('MOV', 'AH', '02h');
    EmitInstr('INT    21h');
  End
  Else If TypeIdx = TY_IDX_BOOLEAN Then
  Begin
    { AX = 0 -> FALSE, sinon -> TRUE }
    LblFalse := LabelGen;
    LblDone  := LabelGen;
    EmitInstrAB('CMP', 'AX', '0');
    EmitInstrA('JE', LblFalse);
    EmitInstrAB('MOV', 'SI', 'OFFSET ' + PSP_RT_PFX + 'TRUE_S');
    EmitInstrA('JMP', LblDone);
    EmitLabel(LblFalse);
    EmitInstrAB('MOV', 'SI', 'OFFSET ' + PSP_RT_PFX + 'FALSE_S');
    EmitLabel(LblDone);
    EmitCall(PSP_RT_PFX + 'PRINTSTR');
  End
  Else
  Begin
    { Integer/Word/Byte/Real -> convertir en chaine + afficher }
    EmitCall(PSP_RT_PFX + 'NUMTOSTR');
    EmitInstrAB('MOV', 'SI', 'OFFSET ' + PSP_RT_PFX + 'NUMBUF');
    EmitCall(PSP_RT_PFX + 'PRINTSTR');
  End;
End;

{ ---- ParseWriteStmt : analyser Write ou WriteLn -------------- }
{ Le mot-cle write/writeln a deja ete consomme.                  }
{ CurToken est sur ( si arguments, ou ; si WriteLn sans args.    }
Procedure ParseWriteStmt(IsWriteLn : Boolean);
Var
  Ev      : TExprVal;
  WidthEv : TExprVal;
Begin
  If IsWriteLn Then
    EmitComment('writeln')
  Else
    EmitComment('write');

  { Gerer WriteLn sans arguments -> juste CR+LF }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
  Begin
    If IsWriteLn Then
    Begin
      EmitInstrAB('MOV', 'SI', 'OFFSET ' + PSP_RT_PFX + 'CRLF');
      EmitCall(PSP_RT_PFX + 'PRINTSTR');
    End;
    TplNextToken;  { consommer ; }
    Exit;
  End;

  { Consommer ( }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    TplNextToken
  Else
  Begin
    { WriteLn sans parentheses -> CR+LF }
    If IsWriteLn Then
    Begin
      EmitInstrAB('MOV', 'SI', 'OFFSET ' + PSP_RT_PFX + 'CRLF');
      EmitCall(PSP_RT_PFX + 'PRINTSTR');
    End;
    Exit;
  End;

  { Boucle sur les arguments }
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
  Begin
    { Evaluer l expression argument }
    ParseExpr(Ev);

    { Detecter formatage Write(val:width) }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    Begin
      TplNextToken;  { consommer : }
      ParseExpr(WidthEv);
      { Stub formatage : ignorer width, emettre un avertissement }
      { Si :w:d (champ flottant) : ignorer le deuxieme }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      Begin
        TplNextToken;
        ParseExpr(WidthEv);  { ignorer d }
        WarnMsg('formatage flottant :w:d non supporte, ignore');
      End;
      { On ignore la largeur pour l instant }
    End;

    { Materialiser et afficher }
    ExprFlushToAX(Ev);
    EmitPrintAX(Ev.TypeIdx);

    { Virgule entre arguments }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      TplNextToken;
  End;

  { Consommer ) }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    TplNextToken;

  { WriteLn : ajouter CR+LF }
  If IsWriteLn Then
  Begin
    EmitInstrAB('MOV', 'SI', 'OFFSET ' + PSP_RT_PFX + 'CRLF');
    EmitCall(PSP_RT_PFX + 'PRINTSTR');
  End;

  { Point-virgule }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    TplNextToken;
End;

{ ---- EmitHtmlFragment : emettre un fragment HTML literal ------ }
{ Stocke le texte en DATA sous _PSPK_HTML_N et emet le code       }
{ pour l afficher via _PSPRT_PRINTSTR.                            }
Procedure EmitHtmlFragment(Const Html : TString);
Var
  Lbl : TString;
Begin
  If Length(Html) = 0 Then Exit;
  { Creer le label HTML }
  Inc(LabelGenSeq);
  Lbl := PSP_HTML_PFX + IntToStr(LabelGenSeq);
  { Ajouter dans DataTab }
  DataAdd(Lbl, DK_STR, 0, Html);
  { Emettre le code d affichage }
  EmitComment('html fragment');
  EmitInstrAB('MOV', 'SI', 'OFFSET ' + Lbl);
  EmitCall(PSP_RT_PFX + 'PRINTSTR');
End;

{ ---- EmitExprInline : emettre une expression <%= expr %> ----- }
{ Evalue l expression, materialise dans AX, imprime selon type.  }
{ CurToken doit etre sur le premier token de l expression.       }
{ Consomme jusqu au PSP_CLOSE.                                   }
Procedure EmitExprInline;
Var
  Ev : TExprVal;
Begin
  EmitComment('expr inline');
  ParseExpr(Ev);
  ExprFlushToAX(Ev);
  EmitPrintAX(Ev.TypeIdx);
  { Consommer le %> (PSP_CLOSE) s il est present }
  If CurToken.Kind = TK_PSP_CLOSE Then
    TplNextToken;
End;

{ ============================================================
  IF / THEN / ELSE + CASE / OF [IMPLEMENTE]
  ============================================================ }

{ ---- ParseStatement : analyser une instruction simple --------- }
{ Dispatch vers : begin..end, if, case, write, writeln, var,      }
{                 const, affectation ident := expr ;               }
{ Ne consomme PAS le ; terminal (sauf quand le sub-parser le fait)}
Procedure ParseStatement;
Var
  SavedName : TString;
  ProcIdx   : Integer;
  { Tableaux }
  ArrSIdx   : Integer;
  ArrTIdx   : Integer;
  ArrLo     : LongInt;
  ElemSz    : Integer;
  IdxExpr   : TExprVal;
  ValExpr   : TExprVal;
  { Records }
  RecSIdx   : Integer;
  RecTIdx   : Integer;
  FldIdx    : Integer;
  FI        : Integer;
  FldTIdx   : Integer;
  FldSz     : Integer;
  WIdx      : Integer;
  WI        : Integer;
  { Standard lib }
  HaltExpr  : TExprVal;
  ReadVarIdx : Integer;
Begin
  { Emettre le label MAINBODY avant la premiere instruction }
  { du code principal (pas les declarations func/proc) }
  If (Not MainBodyEmitted) And (CurScopeLevel = 0) And
     Not ((CurToken.Kind = TK_KEYWORD) And
          ((CurToken.Val = 'function') Or (CurToken.Val = 'procedure'))) Then
  Begin
    MainBodyEmitted := True;
    EmitLabel(PSP_LBL_PFX + 'MAINBODY');
    { emettre Content-Type si defini par <%@ ContentType=...%> }
    If ContentTypeLbl <> '' Then
    Begin
      EmitInstrAB('MOV', 'SI', 'OFFSET ' + ContentTypeLbl);
      EmitInstrA('CALL', PSP_RT_PFX + 'PRINTSTR');
    End;
  End;

  { Bloc begin ... end }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'begin') Then
  Begin
    ParseBlock;
    Exit;
  End;

  { if ... then ... [else ...] }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'if') Then
  Begin
    ParseIfStmt;
    Exit;
  End;

  { case ... of ... end }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'case') Then
  Begin
    ParseCaseStmt;
    Exit;
  End;

  { for ... to|downto ... do }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'for') Then
  Begin
    ParseForStmt;
    Exit;
  End;

  { while ... do ... }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'while') Then
  Begin
    ParseWhileStmt;
    Exit;
  End;

  { repeat ... until ... }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'repeat') Then
  Begin
    ParseRepeatStmt;
    Exit;
  End;

  { break }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'break') Then
  Begin
    TplNextToken;
    If LoopTop < 0 Then
      WarnMsg('''break'' en dehors d''une boucle')
    Else
      EmitInstrA('JMP', LoopBreakLbl[LoopTop]);
    Exit;
  End;

  { continue }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'continue') Then
  Begin
    TplNextToken;
    If LoopTop < 0 Then
      WarnMsg('''continue'' en dehors d''une boucle')
    Else
      EmitInstrA('JMP', LoopContLbl[LoopTop]);
    Exit;
  End;

  { Write / WriteLn }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'write') Then
  Begin
    TplNextToken;
    ParseWriteStmt(False);
    Exit;
  End;
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'writeln') Then
  Begin
    TplNextToken;
    ParseWriteStmt(True);
    Exit;
  End;

  { Declarations var }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'var') Then
  Begin
    TplNextToken;
    ParseVarDecl;
    If HasPendingAssign Then
    Begin
      HasPendingAssign := False;
      ParseAssignment(PendingAssignName);
    End;
    Exit;
  End;

  { Declarations const }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'const') Then
  Begin
    TplNextToken;
    ParseConstDecl;
    Exit;
  End;

  { Declarations type }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'type') Then
  Begin
    TplNextToken;
    ParseTypeDecl;
    If HasPendingAssign Then
    Begin
      HasPendingAssign := False;
      If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
        ParseAssignment(PendingAssignName)
      Else
      Begin
        { Ce n est pas := non plus, traiter comme ident standalone }
        ProcIdx := SymFind(PendingAssignName);
        If (ProcIdx >= 0) And
           (SymTab[ProcIdx].Cat In [SC_FUNC, SC_PROC]) Then
        Begin
          EmitComment('call ' + PendingAssignName);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
            ParseCallArgs(ProcIdx)
          Else
            { Appel sans () };
          EmitInstrA('CALL', SymTab[ProcIdx].MangledName);
        End;
      End;
    End;
    Exit;
  End;

  { Inc/Dec comme instructions }
  If (CurToken.Kind = TK_IDENT) And
     (StrLowerCase(CurToken.Val) = 'inc') Then
  Begin
    TplNextToken;
    ParseIncDecStmt(True);
    Exit;
  End;
  If (CurToken.Kind = TK_IDENT) And
     (StrLowerCase(CurToken.Val) = 'dec') Then
  Begin
    TplNextToken;
    ParseIncDecStmt(False);
    Exit;
  End;

  { --- FillChar(var, count, value) --- }
  If (CurToken.Kind = TK_IDENT) And
     (StrLowerCase(CurToken.Val) = 'fillchar') Then
  Begin
    TplNextToken;  { consommer fillchar }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      TplNextToken;

    { Arg 1 : variable (adresse -> DI) }
    If CurToken.Kind = TK_IDENT Then
    Begin
      ArrSIdx := SymFind(CurToken.Val);
      If ArrSIdx >= 0 Then
      Begin
        If SymTab[ArrSIdx].IsLocal Then
          EmitInstrAB('LEA', 'DI',
            BPOfs(SymTab[ArrSIdx].Offset))
        Else
          EmitInstrAB('MOV', 'DI',
            'OFFSET ' + SymTab[ArrSIdx].MangledName);
      End
      Else
        WarnMsg('variable non declaree dans FillChar');
      TplNextToken;
    End
    Else
    Begin
      WarnMsg('variable attendue dans FillChar');
      TplNextToken;
    End;

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      TplNextToken;

    { Arg 2 : count -> CX }
    ParseExpr(IdxExpr);
    ExprFlushToAX(IdxExpr);
    EmitInstrAB('MOV', 'CX', 'AX');

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      TplNextToken;

    { Arg 3 : value -> AL }
    ParseExpr(ValExpr);
    ExprFlushToAX(ValExpr);

    { Appeler FILLCHAR : DI=ptr, CX=count, AL=val }
    EmitInstrA('CALL', PSP_RT_PFX + 'FILLCHAR');

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { --- Move(src, dst, count) --- }
  If (CurToken.Kind = TK_IDENT) And
     (StrLowerCase(CurToken.Val) = 'move') Then
  Begin
    TplNextToken;  { consommer move }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      TplNextToken;

    { Arg 1 : source (adresse -> SI) }
    If CurToken.Kind = TK_IDENT Then
    Begin
      ArrSIdx := SymFind(CurToken.Val);
      If ArrSIdx >= 0 Then
      Begin
        If SymTab[ArrSIdx].IsLocal Then
          EmitInstrAB('LEA', 'SI',
            BPOfs(SymTab[ArrSIdx].Offset))
        Else
          EmitInstrAB('MOV', 'SI',
            'OFFSET ' + SymTab[ArrSIdx].MangledName);
      End
      Else
        WarnMsg('variable non declaree dans Move');
      TplNextToken;
    End
    Else
    Begin
      WarnMsg('variable attendue dans Move');
      TplNextToken;
    End;

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      TplNextToken;

    { Arg 2 : destination (adresse -> DI) }
    If CurToken.Kind = TK_IDENT Then
    Begin
      ArrSIdx := SymFind(CurToken.Val);
      If ArrSIdx >= 0 Then
      Begin
        If SymTab[ArrSIdx].IsLocal Then
          EmitInstrAB('LEA', 'DI',
            BPOfs(SymTab[ArrSIdx].Offset))
        Else
          EmitInstrAB('MOV', 'DI',
            'OFFSET ' + SymTab[ArrSIdx].MangledName);
      End
      Else
        WarnMsg('variable non declaree dans Move');
      TplNextToken;
    End
    Else
    Begin
      WarnMsg('variable attendue dans Move');
      TplNextToken;
    End;

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      TplNextToken;

    { Arg 3 : count -> CX }
    ParseExpr(IdxExpr);
    ExprFlushToAX(IdxExpr);
    EmitInstrAB('MOV', 'CX', 'AX');

    { Appeler MOVE : SI=src, DI=dst, CX=count }
    EmitInstrA('CALL', PSP_RT_PFX + 'MOVE');

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { ====== Procedures standard ====== }

  { --- Read(var) / ReadLn(var) --- }
  If (CurToken.Kind = TK_IDENT) And
     ((StrLowerCase(CurToken.Val) = 'read') Or
      (StrLowerCase(CurToken.Val) = 'readln')) Then
  Begin
    SavedName := StrLowerCase(CurToken.Val);
    TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      TplNextToken;
      { Lire la variable cible }
      ReadVarIdx := SymFind(CurToken.Val);
      If ReadVarIdx >= 0 Then
      Begin
        If (SymTab[ReadVarIdx].TypeIdx = TY_IDX_CHAR) Or
           (SymTab[ReadVarIdx].TypeIdx = TY_IDX_STRING) Then
        Begin
          (* Lire un caractere *)
          EmitInstrA('CALL', PSP_RT_PFX + 'READCHAR');
          If SymTab[ReadVarIdx].TypeIdx = TY_IDX_CHAR Then
          Begin
            If SymTab[ReadVarIdx].IsLocal Then
              EmitInstrAB('MOV', BPOfs(SymTab[ReadVarIdx].Offset), 'AL')
            Else
              EmitInstrAB('MOV', 'BYTE PTR [' + SymTab[ReadVarIdx].MangledName + ']', 'AL');
          End
          Else
          Begin
            (* Pour String : stocker dans STRBUF puis copier *)
            EmitInstrAB('XOR', 'AH', 'AH');
            EmitInstrAB('MOV', 'BYTE PTR [' + PSP_RT_PFX + 'STRBUF]', 'AL');
            EmitInstrAB('MOV', 'BYTE PTR [' + PSP_RT_PFX + 'STRBUF + 1]', '0');
            EmitInstrAB('LEA', 'SI', PSP_RT_PFX + 'STRBUF');
            If SymTab[ReadVarIdx].IsLocal Then
              EmitInstrAB('LEA', 'DI', BPOfs(SymTab[ReadVarIdx].Offset))
            Else
              EmitInstrAB('MOV', 'DI', 'OFFSET ' + SymTab[ReadVarIdx].MangledName);
            EmitInstrAB('MOV', 'CX', '2');
            EmitInstrA('CALL', PSP_RT_PFX + 'MOVE');
          End;
        End
        Else
        Begin
          (* Lire un entier *)
          EmitInstrA('CALL', PSP_RT_PFX + 'READNUM');
          If SymTab[ReadVarIdx].IsLocal Then
            EmitInstrAB('MOV', BPOfs(SymTab[ReadVarIdx].Offset), 'AX')
          Else
            EmitInstrAB('MOV', 'WORD PTR [' + SymTab[ReadVarIdx].MangledName + ']', 'AX');
        End;
        TplNextToken;
      End
      Else
      Begin
        WarnMsg('variable attendue pour Read/ReadLn');
        TplNextToken;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        TplNextToken;
    End
    Else
    Begin
      (* ReadLn sans argument : attendre un CR *)
      If SavedName = 'readln' Then
      Begin
        EmitInstrA('CALL', PSP_RT_PFX + 'READCHAR');
      End;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { --- Halt / Halt(code) --- }
  If (CurToken.Kind = TK_IDENT) And
     (StrLowerCase(CurToken.Val) = 'halt') Then
  Begin
    TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      TplNextToken;
      ParseExpr(HaltExpr);
      ExprFlushToAX(HaltExpr);
      EmitInstrAB('MOV', 'AH', '4Ch');
      EmitInstr('INT    21h');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        TplNextToken;
    End
    Else
    Begin
      EmitInstrAB('MOV', 'AX', '4C00h');
      EmitInstr('INT    21h');
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { --- New(ptr) --- }
  If (CurToken.Kind = TK_IDENT) And
     (StrLowerCase(CurToken.Val) = 'new') Then
  Begin
    TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      TplNextToken;
    ReadVarIdx := SymFind(CurToken.Val);
    If ReadVarIdx >= 0 Then
    Begin
      EmitInstrAB('MOV', 'CX', IntToStr(TypeSizeof(SymTab[ReadVarIdx].TypeIdx)));
      EmitInstrA('CALL', PSP_RT_PFX + 'ALLOC');
      If SymTab[ReadVarIdx].IsLocal Then
        EmitInstrAB('MOV', BPOfs(SymTab[ReadVarIdx].Offset), 'AX')
      Else
        EmitInstrAB('MOV', 'WORD PTR [' + SymTab[ReadVarIdx].MangledName + ']', 'AX');
      TplNextToken;
    End
    Else
    Begin
      WarnMsg('variable pointeur attendue pour New');
      TplNextToken;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { --- Dispose(ptr) : stub --- }
  If (CurToken.Kind = TK_IDENT) And
     (StrLowerCase(CurToken.Val) = 'dispose') Then
  Begin
    TplNextToken;
    WarnMsg('Dispose : stub (memoire non liberee)');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      TplNextToken;
      While (CurToken.Kind <> TK_PUNCT) Or (CurToken.Val <> ')') Do
      Begin
        If CurToken.Kind = TK_EOF Then Break;
        TplNextToken;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        TplNextToken;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { --- GetMem(ptr, size) --- }
  If (CurToken.Kind = TK_IDENT) And
     (StrLowerCase(CurToken.Val) = 'getmem') Then
  Begin
    TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      TplNextToken;
    ReadVarIdx := SymFind(CurToken.Val);
    If ReadVarIdx >= 0 Then
    Begin
      TplNextToken;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        TplNextToken;
      ParseExpr(ValExpr);
      ExprFlushToAX(ValExpr);
      EmitInstrAB('MOV', 'CX', 'AX');
      EmitInstrA('CALL', PSP_RT_PFX + 'ALLOC');
      If SymTab[ReadVarIdx].IsLocal Then
        EmitInstrAB('MOV', BPOfs(SymTab[ReadVarIdx].Offset), 'AX')
      Else
        EmitInstrAB('MOV', 'WORD PTR [' + SymTab[ReadVarIdx].MangledName + ']', 'AX');
    End
    Else
    Begin
      WarnMsg('variable pointeur attendue pour GetMem');
      TplNextToken;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { --- FreeMem(ptr, size) : stub --- }
  If (CurToken.Kind = TK_IDENT) And
     (StrLowerCase(CurToken.Val) = 'freemem') Then
  Begin
    TplNextToken;
    WarnMsg('FreeMem : stub (memoire non liberee)');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      TplNextToken;
      While (CurToken.Kind <> TK_PUNCT) Or (CurToken.Val <> ')') Do
      Begin
        If CurToken.Kind = TK_EOF Then Break;
        TplNextToken;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        TplNextToken;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { --- Str(n, s) --- }
  If (CurToken.Kind = TK_IDENT) And
     (StrLowerCase(CurToken.Val) = 'str') Then
  Begin
    TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      TplNextToken;
    ParseExpr(ValExpr);
    ExprFlushToAX(ValExpr);
    EmitInstrA('CALL', PSP_RT_PFX + 'NUMTOSTR');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      TplNextToken;
    ReadVarIdx := SymFind(CurToken.Val);
    If ReadVarIdx >= 0 Then
    Begin
      (* Copier NUMBUF vers la variable string *)
      EmitInstrAB('LEA', 'SI', PSP_RT_PFX + 'NUMBUF');
      If SymTab[ReadVarIdx].IsLocal Then
        EmitInstrAB('LEA', 'DI', BPOfs(SymTab[ReadVarIdx].Offset))
      Else
        EmitInstrAB('MOV', 'DI', 'OFFSET ' + SymTab[ReadVarIdx].MangledName);
      EmitInstrAB('MOV', 'CX', '12');
      EmitInstrA('CALL', PSP_RT_PFX + 'MOVE');
      TplNextToken;
    End
    Else
    Begin
      WarnMsg('variable string attendue pour Str');
      TplNextToken;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { --- Val(s, n, code) --- }
  If (CurToken.Kind = TK_IDENT) And
     (StrLowerCase(CurToken.Val) = 'val') Then
  Begin
    TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      TplNextToken;
    ParseExpr(ValExpr);
    ExprFlushToAX(ValExpr);
    EmitInstrAB('MOV', 'SI', 'AX');
    EmitInstrA('CALL', PSP_RT_PFX + 'STRTONUM');
    (* AX = entier converti, stocker dans deuxieme arg *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      TplNextToken;
    ReadVarIdx := SymFind(CurToken.Val);
    If ReadVarIdx >= 0 Then
    Begin
      If SymTab[ReadVarIdx].IsLocal Then
        EmitInstrAB('MOV', BPOfs(SymTab[ReadVarIdx].Offset), 'AX')
      Else
        EmitInstrAB('MOV', 'WORD PTR [' + SymTab[ReadVarIdx].MangledName + ']', 'AX');
      TplNextToken;
    End
    Else
    Begin
      WarnMsg('variable entiere attendue pour Val');
      TplNextToken;
    End;
    (* Troisieme arg code : stocker 0 (pas d erreur) *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
    Begin
      TplNextToken;
      ReadVarIdx := SymFind(CurToken.Val);
      If ReadVarIdx >= 0 Then
      Begin
        EmitInstrAB('XOR', 'BX', 'BX');
        If SymTab[ReadVarIdx].IsLocal Then
          EmitInstrAB('MOV', BPOfs(SymTab[ReadVarIdx].Offset), 'BX')
        Else
          EmitInstrAB('MOV', 'WORD PTR [' + SymTab[ReadVarIdx].MangledName + ']', 'BX');
        TplNextToken;
      End
      Else
        TplNextToken;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { --- Randomize --- }
  If (CurToken.Kind = TK_IDENT) And
     (StrLowerCase(CurToken.Val) = 'randomize') Then
  Begin
    TplNextToken;
    EmitInstrA('CALL', PSP_RT_PFX + 'RANDOMIZE');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { --- Assign / Reset / Rewrite / Close : stubs --- }
  If (CurToken.Kind = TK_IDENT) And
     ((StrLowerCase(CurToken.Val) = 'assign') Or
      (StrLowerCase(CurToken.Val) = 'reset') Or
      (StrLowerCase(CurToken.Val) = 'rewrite') Or
      (StrLowerCase(CurToken.Val) = 'close')) Then
  Begin
    SavedName := CurToken.Val;
    TplNextToken;
    WarnMsg(SavedName + ' : stub (I/O fichier non supporte)');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      TplNextToken;
      While (CurToken.Kind <> TK_PUNCT) Or (CurToken.Val <> ')') Do
      Begin
        If CurToken.Kind = TK_EOF Then Break;
        TplNextToken;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        TplNextToken;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { --- Delete(s, pos, len) --- }
  If (CurToken.Kind = TK_IDENT) And
     (StrLowerCase(CurToken.Val) = 'delete') Then
  Begin
    TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      TplNextToken;
    { Arg 1 : variable string -> SI }
    ReadVarIdx := SymFind(CurToken.Val);
    If ReadVarIdx >= 0 Then
    Begin
      If SymTab[ReadVarIdx].IsLocal Then
        EmitInstrAB('LEA', 'SI', BPOfs(SymTab[ReadVarIdx].Offset))
      Else
        EmitInstrAB('MOV', 'SI', 'OFFSET ' + SymTab[ReadVarIdx].MangledName);
      TplNextToken;
    End
    Else
    Begin
      WarnMsg('variable string attendue pour Delete');
      TplNextToken;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      TplNextToken;
    { Arg 2 : pos -> BX }
    ParseExpr(ValExpr);
    ExprFlushToAX(ValExpr);
    EmitInstrAB('MOV', 'BX', 'AX');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      TplNextToken;
    { Arg 3 : len -> CX }
    ParseExpr(IdxExpr);
    ExprFlushToAX(IdxExpr);
    EmitInstrAB('MOV', 'CX', 'AX');
    EmitInstrA('CALL', PSP_RT_PFX + 'DELETE');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { --- Insert(sub, s, pos) --- }
  If (CurToken.Kind = TK_IDENT) And
     (StrLowerCase(CurToken.Val) = 'insert') Then
  Begin
    TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      TplNextToken;
    { Arg 1 : sub (expression string) -> SI }
    ParseExpr(ValExpr);
    ExprFlushToAX(ValExpr);
    EmitInstrA('PUSH', 'AX');  { sauver ptr sub }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      TplNextToken;
    { Arg 2 : variable string destination -> DI }
    ReadVarIdx := SymFind(CurToken.Val);
    If ReadVarIdx >= 0 Then
    Begin
      If SymTab[ReadVarIdx].IsLocal Then
        EmitInstrAB('LEA', 'DI', BPOfs(SymTab[ReadVarIdx].Offset))
      Else
        EmitInstrAB('MOV', 'DI', 'OFFSET ' + SymTab[ReadVarIdx].MangledName);
      TplNextToken;
    End
    Else
    Begin
      WarnMsg('variable string attendue pour Insert');
      TplNextToken;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      TplNextToken;
    { Arg 3 : pos -> BX }
    ParseExpr(IdxExpr);
    ExprFlushToAX(IdxExpr);
    EmitInstrAB('MOV', 'BX', 'AX');
    EmitInstrA('POP', 'SI');    { SI = ptr sub }
    EmitInstrA('CALL', PSP_RT_PFX + 'INSERT');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { Declarations function / procedure }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'function') Then
  Begin
    ParseFuncDecl;
    Exit;
  End;
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'procedure') Then
  Begin
    ParseProcDecl;
    Exit;
  End;

  { Exit : saut au label de retour de la fonction courante }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'exit') Then
  Begin
    TplNextToken;
    If CurRetLabel <> '' Then
      EmitInstrA('JMP', CurRetLabel)
    Else
      WarnMsg('''exit'' en dehors d''une fonction/procedure');
    Exit;
  End;

  { Result := expr (valeur de retour via Result) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'result') Then
  Begin
    If CurFuncName <> '' Then
    Begin
      TplNextToken;  { consommer result }
      ParseAssignment('result');
    End
    Else
    Begin
      WarnMsg('''result'' en dehors d''une fonction');
      TplNextToken;
    End;
    Exit;
  End;

  { ====== try ... except ... [finally ...] end ====== }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'try') Then
  Begin
    ParseTryExcept;
    Exit;
  End;

  { ====== raise ====== }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'raise') Then
  Begin
    TplNextToken;
    { Evaluer l expression optionnelle (ignoree, stub) }
    If (CurToken.Kind <> TK_PUNCT) Or (CurToken.Val <> ';') Then
    Begin
      ParseExpr(ValExpr);
      ExprFlushToAX(ValExpr);
    End;
    { Sauter vers le handler installe ou panic generique }
    EmitInstrAB('CMP', 'WORD PTR [' + PSP_EX_PFX + 'HANDLER]', '0');
    EmitInstrA('JE', PSP_RT_PFX + 'PANIC_RAISE');
    EmitInstrAB('MOV', 'SP', 'WORD PTR [' + PSP_EX_PFX + 'SAVESP]');
    EmitInstrAB('MOV', 'BP', 'WORD PTR [' + PSP_EX_PFX + 'SAVEBP]');
    EmitInstrA('JMP', 'WORD PTR [' + PSP_EX_PFX + 'HANDLER]');
    EmitRaw(PSP_RT_PFX + 'PANIC_RAISE:');
    EmitInstrAB('MOV', 'SI', 'OFFSET ' + PSP_RT_PFX + 'PANICMSG');
    EmitInstrA('CALL', PSP_RT_PFX + 'PANIC');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { with RecVar do Stmt (Records) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'with') Then
  Begin
    ParseWithStmt;
    Exit;
  End;

  { Affectation : ident := expr ; }
  If (CurToken.Kind = TK_IDENT) Then
  Begin
    SavedName := CurToken.Val;
    TplNextToken;
    { --- rec.field := expr --- }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
    Begin
      RecSIdx := SymFind(SavedName);
      If (RecSIdx >= 0) And
         (SymTab[RecSIdx].TypeIdx >= 0) And
         (SymTab[RecSIdx].TypeIdx < TypeCount) And
         (TypeTab[SymTab[RecSIdx].TypeIdx].Kind = TKP_RECORD) Then
      Begin
        RecTIdx := SymTab[RecSIdx].TypeIdx;
        { Charger adresse de base dans BX }
        If SymTab[RecSIdx].IsLocal Then
          EmitInstrAB('LEA', 'BX',
            BPOfs(SymTab[RecSIdx].Offset))
        Else
          EmitInstrAB('MOV', 'BX',
            'OFFSET ' + SymTab[RecSIdx].MangledName);
        FldTIdx := TY_IDX_INTEGER;
        FldSz   := 2;
        While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Do
        Begin
          TplNextToken;  { consommer . }
          If CurToken.Kind = TK_IDENT Then
          Begin
            FldIdx := -1;
            For FI := 0 To TypeTab[RecTIdx].FieldCount - 1 Do
              If StrLowerCase(TypeTab[RecTIdx].Fields[FI].Name) =
                 StrLowerCase(CurToken.Val) Then
              Begin
                FldIdx := FI;
                Break;
              End;
            If FldIdx >= 0 Then
            Begin
              If TypeTab[RecTIdx].Fields[FldIdx].Offset > 0 Then
                EmitInstrAB('ADD', 'BX',
                  IntToStr(TypeTab[RecTIdx].Fields[FldIdx].Offset));
              FldTIdx := TypeTab[RecTIdx].Fields[FldIdx].TypeIdx;
              FldSz   := TypeSizeof(FldTIdx);
              TplNextToken;  { consommer nom du champ }
              If (FldTIdx >= 0) And (FldTIdx < TypeCount) And
                 (TypeTab[FldTIdx].Kind = TKP_RECORD) Then
                RecTIdx := FldTIdx;
            End
            Else
            Begin
              WarnMsg('champ inconnu: ' + CurToken.Val);
              TplNextToken;
              Break;
            End;
          End
          Else
          Begin
            WarnMsg('nom de champ attendu apres "."');
            Break;
          End;
        End;
        { Sauvegarder adresse du champ }
        EmitInstrA('PUSH', 'BX');
        { Consommer := }
        If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
          TplNextToken
        Else
          WarnMsg(''':='' attendu apres rec.field');
        EmitComment('assign ' + SavedName + '.field');
        { Evaluer la valeur dans AX }
        ParseExpr(ValExpr);
        ExprFlushToAX(ValExpr);
        { Restaurer adresse du champ }
        EmitInstrA('POP', 'BX');
        { Stocker la valeur }
        If FldSz = 1 Then
          EmitInstrAB('MOV', 'BYTE PTR [BX]', 'AL')
        Else
          EmitInstrAB('MOV', 'WORD PTR [BX]', 'AX');
        { Point-virgule }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          TplNextToken;
      End
      Else
      Begin
        WarnMsg('acces "." sur un non-record: ' + SavedName);
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And
                   (CurToken.Val = ';')) Do
          TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          TplNextToken;
      End;
    End
    Else
    { --- with-stack field := expr --- }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    Begin
      WIdx := -1;
      If WithTop >= 0 Then
      Begin
        For WI := WithTop DownTo 0 Do
        Begin
          RecTIdx := SymTab[WithSymIdx[WI]].TypeIdx;
          For FI := 0 To TypeTab[RecTIdx].FieldCount - 1 Do
            If StrLowerCase(TypeTab[RecTIdx].Fields[FI].Name) =
               StrLowerCase(SavedName) Then
            Begin
              WIdx := WI;
              FldIdx := FI;
              Break;
            End;
          If WIdx >= 0 Then Break;
        End;
      End;
      If WIdx >= 0 Then
      Begin
        { Champ trouve dans le with-stack : generer write }
        RecTIdx := SymTab[WithSymIdx[WIdx]].TypeIdx;
        If SymTab[WithSymIdx[WIdx]].IsLocal Then
          EmitInstrAB('LEA', 'BX',
            BPOfs(SymTab[WithSymIdx[WIdx]].Offset))
        Else
          EmitInstrAB('MOV', 'BX',
            'OFFSET ' + SymTab[WithSymIdx[WIdx]].MangledName);
        If TypeTab[RecTIdx].Fields[FldIdx].Offset > 0 Then
          EmitInstrAB('ADD', 'BX',
            IntToStr(TypeTab[RecTIdx].Fields[FldIdx].Offset));
        EmitInstrA('PUSH', 'BX');
        FldTIdx := TypeTab[RecTIdx].Fields[FldIdx].TypeIdx;
        FldSz   := TypeSizeof(FldTIdx);
        TplNextToken;  { consommer := }
        EmitComment('with-assign ' + SavedName);
        ParseExpr(ValExpr);
        ExprFlushToAX(ValExpr);
        EmitInstrA('POP', 'BX');
        If FldSz = 1 Then
          EmitInstrAB('MOV', 'BYTE PTR [BX]', 'AL')
        Else
          EmitInstrAB('MOV', 'WORD PTR [BX]', 'AX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          TplNextToken;
      End
      Else
        ParseAssignment(SavedName);
    End
    { --- arr[i] := expr ; --- }
    Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
    Begin
      ArrSIdx := SymFind(SavedName);
      If (ArrSIdx >= 0) And
         (SymTab[ArrSIdx].TypeIdx >= 0) And
         (SymTab[ArrSIdx].TypeIdx < TypeCount) And
         (TypeTab[SymTab[ArrSIdx].TypeIdx].Kind = TKP_ARRAY) Then
      Begin
        ArrTIdx := SymTab[ArrSIdx].TypeIdx;
        ArrLo   := TypeTab[ArrTIdx].Lo;
        ElemSz  := TypeSizeof(TypeTab[ArrTIdx].BaseTypeIdx);

        TplNextToken;  { consommer [ }

        { Evaluer l index dans AX }
        ParseExpr(IdxExpr);
        ExprFlushToAX(IdxExpr);

        { Sauvegarder l index calcule }
        EmitInstrA('PUSH', 'AX');

        { Consommer ] }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
          TplNextToken;

        { Consommer := }
        If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
          TplNextToken
        Else
          WarnMsg(''':='' attendu apres arr[i]');

        EmitComment('assign ' + SavedName + '[]');

        { Evaluer la valeur dans AX }
        ParseExpr(ValExpr);
        ExprFlushToAX(ValExpr);

        { AX = valeur, restaurer index }
        EmitInstrA('POP', 'CX');  { CX = index }

        { Calculer offset = (index - lo) * elemsize }
        If ArrLo <> 0 Then
          EmitInstrAB('SUB', 'CX', IntToStr(ArrLo));
        If ElemSz = 2 Then
          EmitInstrAB('SHL', 'CX', '1')
        Else If (ElemSz <> 1) And (ElemSz > 2) Then
        Begin
          EmitInstrA('PUSH', 'AX');
          EmitInstrAB('MOV', 'AX', 'CX');
          EmitInstrAB('MOV', 'CX', IntToStr(ElemSz));
          EmitInstr('MUL    CX');
          EmitInstrAB('MOV', 'CX', 'AX');
          EmitInstrA('POP', 'AX');
        End;

        { Adresse de base dans BX }
        If SymTab[ArrSIdx].IsLocal Then
          EmitInstrAB('LEA', 'BX',
            BPOfs(SymTab[ArrSIdx].Offset))
        Else
          EmitInstrAB('MOV', 'BX',
            'OFFSET ' + SymTab[ArrSIdx].MangledName);

        { Ajouter offset }
        EmitInstrAB('ADD', 'BX', 'CX');

        { Stocker la valeur }
        If ElemSz = 1 Then
          EmitInstrAB('MOV', 'BYTE PTR [BX]', 'AL')
        Else
          EmitInstrAB('MOV', 'WORD PTR [BX]', 'AX');

        { Point-virgule }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          TplNextToken;
      End
      Else
      Begin
        WarnMsg('indexation sur un non-tableau: ' + SavedName);
        { Sauter jusqu au ; }
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And
                   (CurToken.Val = ';')) Do
          TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          TplNextToken;
      End;
    End
    Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      { Appel de procedure comme instruction }
      ProcIdx := SymFind(SavedName);
      If (ProcIdx >= 0) And
         (SymTab[ProcIdx].Cat In [SC_FUNC, SC_PROC]) Then
      Begin
        EmitComment('call ' + SavedName);
        ParseCallArgs(ProcIdx);
        EmitInstrA('CALL', SymTab[ProcIdx].MangledName);
      End
      Else
      Begin
        { Pas une proc connue : evaluer et ignorer }
        WarnMsg('appel de procedure inconnue: ' + SavedName);
        ParseCallArgs(-1);
      End;
    End
    Else
    Begin
      { Pas une affectation ni un appel avec () : }
      { verifier si c est un appel de proc sans parentheses }
      ProcIdx := SymFind(SavedName);
      If (ProcIdx >= 0) And
         (SymTab[ProcIdx].Cat In [SC_FUNC, SC_PROC]) Then
      Begin
        EmitComment('call ' + SavedName);
        EmitInstrA('CALL', SymTab[ProcIdx].MangledName);
      End;
    End;
    Exit;
  End;

  { Instruction vide (;) ou token inconnu : consommer pour eviter boucle infinie }
  If (CurToken.Kind <> TK_EOF) And
     (CurToken.Kind <> TK_PSP_CLOSE) And
     Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'end')) And
     Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'else')) And
     Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Then
    TplNextToken;
End;

{ ---- ParseBlock : analyser un bloc begin ... end ------------- }
{ Consomme begin, execute les instructions separees par ;,        }
{ jusqu a end. Consomme end.                                      }
Procedure ParseBlock;
Begin
  { Consommer begin }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'begin') Then
    TplNextToken
  Else
  Begin
    WarnMsg('''begin'' attendu');
    Exit;
  End;

  { Boucle : instructions separees par ; }
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'end')) Do
  Begin
    ParseStatement;
    { Consommer les ; separateurs }
    While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Do
      TplNextToken;
  End;

  { Consommer end }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'end') Then
    TplNextToken
  Else
    WarnMsg('''end'' attendu pour fermer le bloc begin');
End;

{ ---- ParseWithStmt : analyser with RecVar do Stmt ---- }
{ CurToken est sur 'with'. Empile l index symbole du record dans   }
{ WithStack, execute le bloc interne, puis depile.                 }
Procedure ParseWithStmt;
Var
  WSIdx : Integer;
Begin
  TplNextToken;  { consommer with }
  If CurToken.Kind = TK_IDENT Then
  Begin
    WSIdx := SymFind(CurToken.Val);
    If (WSIdx >= 0) And
       (SymTab[WSIdx].TypeIdx >= 0) And
       (SymTab[WSIdx].TypeIdx < TypeCount) And
       (TypeTab[SymTab[WSIdx].TypeIdx].Kind = TKP_RECORD) Then
    Begin
      TplNextToken;  { consommer ident }
      If WithTop < MAX_WITH - 1 Then
      Begin
        Inc(WithTop);
        WithSymIdx[WithTop] := WSIdx;
      End
      Else
        WarnMsg('imbrication with trop profonde');
      { Consommer do }
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'do') Then
        TplNextToken;
      { Executer le bloc/instruction interne }
      ParseStatement;
      { Depiler }
      If WithTop >= 0 Then
        Dec(WithTop);
    End
    Else
    Begin
      WarnMsg('with : variable record attendue');
      TplNextToken;
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'do') Then
        TplNextToken;
      ParseStatement;
    End;
  End
  Else
    WarnMsg('identificateur attendu apres with');
End;

{ ---- ParseTryExcept -------------------------------- }
{ try bloc except [on E: Exception do bloc end;] end;            }
{ Gere aussi finally apres except (toujours execute).             }
{ Implem simplifie : handler unique, attrape toute exception.     }
Procedure ParseTryExcept;
Var
  LblExcept  : TString;
  LblFinally : TString;
  LblEnd     : TString;
Begin
  EmitComment('try');
  TplNextToken;  { consommer try }

  LblExcept  := LabelGen;
  LblFinally := LabelGen;
  LblEnd     := LabelGen;

  { Sauver ancien handler et installer le nouveau }
  EmitInstrA('PUSH', 'WORD PTR [' + PSP_EX_PFX + 'HANDLER]');
  EmitInstrA('PUSH', 'WORD PTR [' + PSP_EX_PFX + 'SAVESP]');
  EmitInstrA('PUSH', 'WORD PTR [' + PSP_EX_PFX + 'SAVEBP]');
  EmitInstrAB('MOV', 'WORD PTR [' + PSP_EX_PFX + 'HANDLER]',
              'OFFSET ' + LblExcept);
  EmitInstrAB('MOV', 'WORD PTR [' + PSP_EX_PFX + 'SAVESP]', 'SP');
  EmitInstrAB('MOV', 'WORD PTR [' + PSP_EX_PFX + 'SAVEBP]', 'BP');

  { --- Bloc try --- }
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_KEYWORD) And
             ((CurToken.Val = 'except') Or (CurToken.Val = 'finally')
              Or (CurToken.Val = 'end'))) Do
  Begin
    ParseStatement;
    While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Do
      TplNextToken;
  End;

  { Pas d exception : sauter le bloc except, aller au finally/end }
  EmitInstrA('JMP', LblFinally);

  { --- Bloc except --- }
  EmitLabel(LblExcept);
  EmitComment('except handler');

  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'except') Then
  Begin
    TplNextToken;  { consommer except }
    { Gerer 'on E: Exception do' si present (optionnel, skip syntax) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'on') Then
    Begin
      TplNextToken;  { on }
      TplNextToken;  { E (ident) }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
        TplNextToken;  { : }
      TplNextToken;  { Exception (type) }
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'do') Then
        TplNextToken;  { do }
    End;
    { Bloc except }
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_KEYWORD) And
               ((CurToken.Val = 'finally') Or (CurToken.Val = 'end'))) Do
    Begin
      ParseStatement;
      While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Do
        TplNextToken;
    End;
  End;

  { --- Bloc finally (optionnel) --- }
  EmitLabel(LblFinally);
  EmitComment('finally');

  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'finally') Then
  Begin
    TplNextToken;  { consommer finally }
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'end')) Do
    Begin
      ParseStatement;
      While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Do
        TplNextToken;
    End;
  End;

  { Restaurer l ancien handler }
  EmitInstrA('POP', 'WORD PTR [' + PSP_EX_PFX + 'SAVEBP]');
  EmitInstrA('POP', 'WORD PTR [' + PSP_EX_PFX + 'SAVESP]');
  EmitInstrA('POP', 'WORD PTR [' + PSP_EX_PFX + 'HANDLER]');

  EmitLabel(LblEnd);

  { Consommer end }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'end') Then
    TplNextToken
  Else
    WarnMsg('''end'' attendu pour fermer try/except');
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    TplNextToken;
End;

{ ---- ParseIfStmt : analyser if expr then stmt [else stmt] ---- }
{ CurToken est sur 'if'. Gere les dangling else par rattachement  }
{ au if le plus proche (standard Pascal).                         }
Procedure ParseIfStmt;
Var
  Ev          : TExprVal;
  LblElse     : TString;
  LblEndIf    : TString;
  HasElsePart : Boolean;
Begin
  EmitComment('if');

  { Consommer if }
  TplNextToken;

  { Evaluer la condition }
  ParseExpr(Ev);
  ExprFlushToAX(Ev);

  { Generer labels }
  LblElse  := LabelGen;
  LblEndIf := LabelGen;

  { TEST AX,AX / JZ lbl_else }
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JZ', LblElse);

  { Consommer then }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'then') Then
    TplNextToken
  Else
    WarnMsg('''then'' attendu apres condition if');

  { Compiler le bloc then }
  ParseStatement;

  { Consommer le ; optionnel apres le stmt du then }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    TplNextToken;

  { Verifier si else suit }
  HasElsePart := (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'else');

  If HasElsePart Then
  Begin
    { JMP endif pour sauter le bloc else }
    EmitInstrA('JMP', LblEndIf);
    { Label else }
    EmitLabel(LblElse);

    { Consommer else }
    TplNextToken;

    { Compiler le bloc else }
    ParseStatement;

    { Consommer le ; optionnel apres le stmt du else }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;

    { Label endif }
    EmitLabel(LblEndIf);
  End
  Else
  Begin
    { Pas de else : label else = label endif }
    EmitLabel(LblElse);
  End;
End;

{ ---- ParseCaseStmt : analyser case expr of ... end ----------- }
{ CurToken est sur 'case'.                                        }
{ Syntaxe : case expr of                                          }
{             val1 : stmt;                                        }
{             val2, val3 : stmt;                                  }
{             val4..val5 : stmt;                                  }
{           [else stmt;]                                          }
{           end;                                                  }
Procedure ParseCaseStmt;
Var
  Ev           : TExprVal;
  CaseEv       : TExprVal;
  LblEnd       : TString;
  LblNext      : TString;
  LblHit       : TString;
  RangeHi      : LongInt;
  FirstVal     : Boolean;
Begin
  EmitComment('case');

  { Consommer case }
  TplNextToken;

  { Evaluer l expression switch }
  ParseExpr(Ev);
  ExprFlushToAX(Ev);
  EmitInstrA('PUSH', 'AX');  { sauvegarder la valeur sur la pile }

  { Consommer of }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'of') Then
    TplNextToken
  Else
    WarnMsg('''of'' attendu apres expression case');

  LblEnd := LabelGen;

  { Boucle sur les branches }
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_KEYWORD) And
             ((CurToken.Val = 'end') Or (CurToken.Val = 'else'))) Do
  Begin
    LblNext := LabelGen;
    LblHit  := LabelGen;
    FirstVal := True;

    { Lire les valeurs de la branche (separees par virgule) }
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':')) Do
    Begin
      { Recuperer la valeur de la branche }
      ParseExpr(CaseEv);

      If Not FirstVal Then
      Begin
        { Valeurs multiples : restaurer AX depuis la pile }
      End;
      FirstVal := False;

      { Restaurer la valeur switch dans AX }
      EmitInstrAB('MOV', 'AX', 'WORD PTR [SP]');

      { Detecter plage val1..val2 }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '..') Then
      Begin
        { Plage : CaseEv.ImmVal est la borne basse }
        TplNextToken;  { consommer .. }
        RangeHi := 0;
        If CurToken.Kind = TK_INTEGER Then
        Begin
          RangeHi := CurToken.IntVal;
          TplNextToken;
        End
        Else
        Begin
          { Evaluer la borne haute }
          ParseExpr(CaseEv);
          RangeHi := CaseEv.ImmVal;
        End;
        { CMP AX, lo / JB next }
        EmitInstrAB('CMP', 'AX', IntToStr(CaseEv.ImmVal));
        EmitInstrA('JB', LblNext);
        { CMP AX, hi / JA next }
        EmitInstrAB('CMP', 'AX', IntToStr(RangeHi));
        EmitInstrA('JBE', LblHit);
        { Si pas dans la plage, aller a next }
        EmitInstrA('JMP', LblNext);
      End
      Else
      Begin
        { Valeur simple : CMP AX, val / JE hit }
        If CaseEv.Kind = EK_IMM Then
          EmitInstrAB('CMP', 'AX', IntToStr(CaseEv.ImmVal))
        Else
        Begin
          ExprFlushToAX(CaseEv);
          EmitInstrAB('MOV', 'BX', 'AX');
          EmitInstrAB('MOV', 'AX', 'WORD PTR [SP]');
          EmitInstrAB('CMP', 'AX', 'BX');
        End;
        EmitInstrA('JE', LblHit);
      End;

      { Virgule : autre valeur pour la meme branche }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        TplNextToken
      Else
        Break;
    End;

    { Si aucune valeur n a matche, sauter a LblNext }
    EmitInstrA('JMP', LblNext);

    { Label hit : on entre dans la branche }
    EmitLabel(LblHit);

    { Consommer : }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      TplNextToken
    Else
      WarnMsg(''':'' attendu apres valeur(s) case');

    { Compiler l instruction de la branche }
    ParseStatement;

    { Consommer le ; separateur }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;

    { Sauter a la fin du case }
    EmitInstrA('JMP', LblEnd);

    { Label suivant : branche non matchee }
    EmitLabel(LblNext);
  End;

  { Branche else (default) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'else') Then
  Begin
    TplNextToken;
    EmitComment('case else');
    { Boucle : instructions jusqu a end }
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'end')) Do
    Begin
      ParseStatement;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        TplNextToken;
    End;
  End;

  { Label fin du case }
  EmitLabel(LblEnd);

  { Depiler la valeur switch }
  EmitInstrA('POP', 'AX');

  { Consommer end }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'end') Then
    TplNextToken
  Else
    WarnMsg('''end'' attendu pour fermer le case');

  { Consommer le ; optionnel }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    TplNextToken;
End;

{ ============================================================
  BOUCLES : FOR / WHILE / REPEAT [IMPLEMENTE]
  ============================================================ }

{ ---- LoopPush : empiler un contexte de boucle ---------------- }
Procedure LoopPush(Const LblBreak, LblCont : TString);
Begin
  Inc(LoopTop);
  If LoopTop >= MAX_LOOP_NEST Then
  Begin
    WarnMsg('trop de boucles imbriquees');
    Dec(LoopTop);
    Exit;
  End;
  LoopBreakLbl[LoopTop] := LblBreak;
  LoopContLbl[LoopTop]  := LblCont;
End;

{ ---- LoopPop : depiler un contexte de boucle ----------------- }
Procedure LoopPop;
Begin
  If LoopTop >= 0 Then
    Dec(LoopTop);
End;

{ ---- ParseForStmt : for v := expr1 to|downto expr2 do stmt --- }
{ CurToken est sur 'for'.                                        }
Procedure ParseForStmt;
Var
  VarName   : TString;
  Ev        : TExprVal;
  LimLabel  : TString;
  LblTest   : TString;
  LblEnd    : TString;
  LblCont   : TString;
  IsDownTo  : Boolean;
  SymIdx    : Integer;
  VarRef    : TString;
Begin
  EmitComment('for');

  { Consommer for }
  TplNextToken;

  { Lire la variable de boucle }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    WarnMsg('variable de boucle attendue apres ''for''');
    Exit;
  End;
  VarName := CurToken.Val;
  TplNextToken;

  { Consommer := }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    TplNextToken
  Else
    WarnMsg(''':='' attendu apres variable de boucle');

  { Evaluer l expression de depart }
  ParseExpr(Ev);
  ExprFlushToAX(Ev);

  { Chercher le symbole de la variable }
  SymIdx := SymFind(VarName);
  If SymIdx < 0 Then
  Begin
    WarnMsg('variable de boucle ''' + VarName + ''' non declaree');
    Exit;
  End;
  If SymTab[SymIdx].IsLocal Then
    VarRef := 'WORD PTR ' + BPOfs(SymTab[SymIdx].Offset)
  Else
    VarRef := 'WORD PTR [' + SymTab[SymIdx].MangledName + ']';

  { Stocker la valeur de depart }
  EmitInstrAB('MOV', VarRef, 'AX');

  { Consommer to ou downto }
  IsDownTo := False;
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'to') Then
    TplNextToken
  Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'downto') Then
  Begin
    IsDownTo := True;
    TplNextToken;
  End
  Else
    WarnMsg('''to'' ou ''downto'' attendu');

  { Evaluer l expression limite et la stocker dans une variable data }
  ParseExpr(Ev);
  ExprFlushToAX(Ev);
  LimLabel := LabelGen;
  EmitInstrAB('MOV', 'WORD PTR [' + LimLabel + ']', 'AX');

  { Generer les labels de boucle }
  LblTest := LabelGen;
  LblEnd  := LabelGen;
  LblCont := LabelGen;

  { Consommer do }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'do') Then
    TplNextToken
  Else
    WarnMsg('''do'' attendu apres expression limite');

  { Label de test }
  EmitLabel(LblTest);

  { Test : CMP var, limite }
  EmitInstrAB('MOV', 'AX', VarRef);
  EmitInstrAB('CMP', 'AX', 'WORD PTR [' + LimLabel + ']');
  If IsDownTo Then
    EmitInstrA('JL', LblEnd)
  Else
    EmitInstrA('JG', LblEnd);

  { Empiler le contexte de boucle }
  LoopPush(LblEnd, LblCont);

  { Compiler le corps de la boucle }
  ParseStatement;

  { Consommer le ; optionnel }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    TplNextToken;

  { Label continue (increment) }
  EmitLabel(LblCont);

  { Increment ou decrement }
  If IsDownTo Then
    EmitInstrA('DEC', VarRef)
  Else
    EmitInstrA('INC', VarRef);

  { Retour au test }
  EmitInstrA('JMP', LblTest);

  { Label fin }
  EmitLabel(LblEnd);

  { Depiler le contexte de boucle }
  LoopPop;

  { Ajouter la variable limite dans le segment de donnees }
  DataAddWord(LimLabel, 0);
End;

{ ---- ParseWhileStmt : while expr do stmt --------------------- }
{ CurToken est sur 'while'.                                       }
Procedure ParseWhileStmt;
Var
  Ev      : TExprVal;
  LblTest : TString;
  LblEnd  : TString;
Begin
  EmitComment('while');

  { Consommer while }
  TplNextToken;

  { Generer les labels }
  LblTest := LabelGen;
  LblEnd  := LabelGen;

  { Label de test }
  EmitLabel(LblTest);

  { Evaluer la condition }
  ParseExpr(Ev);
  ExprFlushToAX(Ev);

  { TEST AX,AX / JZ fin }
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JZ', LblEnd);

  { Consommer do }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'do') Then
    TplNextToken
  Else
    WarnMsg('''do'' attendu apres condition while');

  { Empiler le contexte de boucle }
  LoopPush(LblEnd, LblTest);

  { Compiler le corps }
  ParseStatement;

  { Consommer le ; optionnel }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    TplNextToken;

  { Retour au test }
  EmitInstrA('JMP', LblTest);

  { Label fin }
  EmitLabel(LblEnd);

  { Depiler le contexte de boucle }
  LoopPop;
End;

{ ---- ParseRepeatStmt : repeat stmts until expr --------------- }
{ CurToken est sur 'repeat'.                                     }
Procedure ParseRepeatStmt;
Var
  Ev     : TExprVal;
  LblBeg : TString;
  LblEnd : TString;
Begin
  EmitComment('repeat');

  { Consommer repeat }
  TplNextToken;

  { Generer les labels }
  LblBeg := LabelGen;
  LblEnd := LabelGen;

  { Label debut }
  EmitLabel(LblBeg);

  { Empiler le contexte de boucle }
  LoopPush(LblEnd, LblBeg);

  { Compiler les instructions jusqu a until }
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'until')) Do
  Begin
    ParseStatement;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
  End;

  { Consommer until }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'until') Then
    TplNextToken
  Else
    WarnMsg('''until'' attendu pour fermer le repeat');

  { Evaluer la condition }
  ParseExpr(Ev);
  ExprFlushToAX(Ev);

  { TEST AX,AX / JZ debut (si faux, on boucle) }
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JZ', LblBeg);

  { Label fin }
  EmitLabel(LblEnd);

  { Depiler le contexte de boucle }
  LoopPop;
End;

{ ============================================================
  FONCTIONS ET PROCEDURES [IMPLEMENTE]
  ============================================================ }

{ ---- ParseParamList : analyser la liste de parametres --------- }
{ Syntaxe : (a: Integer; var b: Integer; c, d: Word)              }
{ Enregistre chaque param dans SymTab comme SC_PARAM ou SC_VARPARAM }
{ Retourne le nombre total d octets de parametres.                }
Function ParseParamList : Integer;
Var
  Names      : Array[0..MAX_PARAM - 1] Of TString;
  IsVar      : Array[0..MAX_PARAM - 1] Of Boolean;
  NCount     : Integer;
  TName      : TString;
  TIdx       : Integer;
  ParamBytes : Integer;
  I, Idx     : Integer;
  Cat        : TSymCat;
Begin
  ParamBytes := 0;

  { Consommer ( }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    TplNextToken
  Else
  Begin
    ParseParamList := 0;
    Exit;
  End;

  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
  Begin
    NCount := 0;

    { Detecter var }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'var') Then
    Begin
      For I := 0 To MAX_PARAM - 1 Do
        IsVar[I] := True;
      TplNextToken;
    End
    Else
    Begin
      For I := 0 To MAX_PARAM - 1 Do
        IsVar[I] := False;
    End;

    { Collecter les noms }
    While (CurToken.Kind = TK_IDENT) Do
    Begin
      If NCount < MAX_PARAM Then
      Begin
        Names[NCount] := CurToken.Val;
        Inc(NCount);
      End;
      TplNextToken;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        TplNextToken
      Else
        Break;
    End;

    { Deux-points + type }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      TplNextToken
    Else
      WarnMsg(''':'' attendu dans liste de parametres');

    TName := '';
    If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
    Begin
      TName := CurToken.Val;
      TplNextToken;
    End;

    TIdx := TypeResolve(TName);
    If TIdx = TY_UNKNOWN Then
    Begin
      WarnMsg('type de parametre inconnu: ' + TName);
      TIdx := TY_IDX_INTEGER;
    End;

    { Enregistrer les parametres }
    For I := 0 To NCount - 1 Do
    Begin
      If IsVar[I] Then
        Cat := SC_VARPARAM
      Else
        Cat := SC_PARAM;
      Idx := SymAdd(Names[I], Cat, TIdx);
      If Idx >= 0 Then
      Begin
        { Offset sera fixe apres : [BP+4] pour premier param, +2 etc. }
        { On stocke d abord le rang, on corrigera apres }
        SymTab[Idx].Offset  := ParamBytes;
        SymTab[Idx].IsLocal := True;
      End;
      Inc(ParamBytes, 2);  { tout parametre = 1 word sur la pile }
    End;

    { Point-virgule entre groupes de params }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
  End;

  { Consommer ) }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    TplNextToken;

  { Corriger les offsets : convention Pascal, premier param en [BP+4+paramBytes-2] }
  { Le premier param pousse est le plus a gauche, donc en haut de la pile.        }
  { Apres PUSH BP / MOV BP,SP : [BP+0]=old BP, [BP+2]=ret addr }
  { Args empiles gauche->droite : premier arg = [BP+4+(NTotal-1)*2] }
  { Pour simplifier : on recalcule l offset final }
  { Le rang est dans Offset (0, 2, 4, ...) }
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If (SymTab[I].ScopeLevel = CurScopeLevel) And
       (SymTab[I].Cat In [SC_PARAM, SC_VARPARAM]) Then
    Begin
      { Param rang R (0-based en bytes) -> offset = +4 + (ParamBytes - 2 - R) }
      SymTab[I].Offset := 4 + (ParamBytes - 2 - SymTab[I].Offset);
      If Opts.DebugMode Then
        WriteLn('  PARAM: ', SymTab[I].Name, ' [BP+',
                SymTab[I].Offset, ']');
    End;
  End;

  ParseParamList := ParamBytes;
End;

{ ---- ParseFuncOrProc : analyse commune func/proc -------------- }
{ IsFunc = True pour function, False pour procedure.              }
Procedure ParseFuncOrProc(IsFunc : Boolean);
Var
  FuncName     : TString;
  RetTypeName  : TString;
  RetTypeIdx   : Integer;
  FIdx         : Integer;
  ParamBytes   : Integer;
  FrameSize    : Integer;
  RetLabel     : TString;
  SaveFrame    : Integer;
  SaveFuncName : TString;
  SaveRetOfs   : Integer;
  SaveRetLabel : TString;
  SaveParamB   : Integer;
  Cat          : TSymCat;
  RetVarIdx    : Integer;
  VarMask      : LongInt;   { bitmask params var }
  PCnt         : Integer;   { compteur params }
  I            : Integer;   { iterateur }
Begin
  { Consommer function/procedure }
  TplNextToken;

  { Nom de la fonction / procedure }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    WarnMsg('nom de fonction/procedure attendu');
    Exit;
  End;
  FuncName := CurToken.Val;
  TplNextToken;

  { Categorie }
  If IsFunc Then
    Cat := SC_FUNC
  Else
    Cat := SC_PROC;

  { Type de retour par defaut }
  RetTypeIdx := TY_IDX_INTEGER;

  { Verifier si c est une redeclaration (forward resolue) }
  FIdx := SymFindInScope(FuncName, CurScopeLevel);
  If (FIdx >= 0) And SymTab[FIdx].IsForward Then
  Begin
    { Forward resolue : on reutilise le symbole }
    SymTab[FIdx].IsForward := False;
  End
  Else
  Begin
    { Nouvelle declaration }
    FIdx := SymAdd(FuncName, Cat, RetTypeIdx);
  End;

  { Entrer dans le scope de la fonction }
  SymEnterScope;
  Inc(CurNestLevel);
  If CurNestLevel > NEST_MAX Then
    WarnMsg('imbrication de fonctions trop profonde (>' +
            IntToStr(NEST_MAX) + ')');

  { Parser les parametres }
  ParamBytes := 0;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    ParamBytes := ParseParamList;

  { Construire le masque des parametres var }
  If FIdx >= 0 Then Begin
    VarMask := 0;
    PCnt    := 0;
    For I := 0 To SymCount - 1 Do
    Begin
      If (SymTab[I].ScopeLevel = CurScopeLevel) And
         (SymTab[I].ScopeId = CurScopeId) And
         (SymTab[I].Cat In [SC_PARAM, SC_VARPARAM]) Then
      Begin
        If SymTab[I].Cat = SC_VARPARAM Then
          VarMask := VarMask Or (LongInt(1) Shl PCnt);
        Inc(PCnt);
      End;
    End;
    SymTab[FIdx].ParamCnt     := PCnt;
    SymTab[FIdx].VarParamMask := VarMask;
    If Opts.DebugMode Then
      WriteLn('  FUNC_PARAMS: ', FuncName, ' cnt=', PCnt,
              ' varmask=', VarMask);
  End;

  { Type de retour pour les fonctions }
  If IsFunc Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    Begin
      TplNextToken;
      RetTypeName := '';
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
      Begin
        RetTypeName := CurToken.Val;
        TplNextToken;
      End;
      RetTypeIdx := TypeResolve(RetTypeName);
      If RetTypeIdx = TY_UNKNOWN Then
      Begin
        WarnMsg('type de retour inconnu: ' + RetTypeName);
        RetTypeIdx := TY_IDX_INTEGER;
      End;
    End;
    If FIdx >= 0 Then
      SymTab[FIdx].TypeIdx := RetTypeIdx;
  End
  Else
  Begin
    { Procedure : pas de valeur de retour }
    RetTypeIdx := TY_UNKNOWN;
    If FIdx >= 0 Then
      SymTab[FIdx].TypeIdx := TY_UNKNOWN;
  End;

  { Point-virgule apres la signature }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    TplNextToken;

  { Verifier si forward }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'forward') Then
  Begin
    If FIdx >= 0 Then
      SymTab[FIdx].IsForward := True;
    TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    SymLeaveScope;
    Dec(CurNestLevel);
    Exit;
  End;

  { Sauvegarder le contexte du cadre parent }
  SaveFrame    := CurFrameOffset;
  SaveFuncName := CurFuncName;
  SaveRetOfs   := CurFuncRetOfs;
  SaveRetLabel := CurRetLabel;
  SaveParamB   := CurParamBytes;

  CurFrameOffset := 0;
  CurParamBytes  := ParamBytes;
  RetLabel       := LabelGen;
  CurRetLabel    := RetLabel;

  { Pour les fonctions : allouer une variable locale pour la valeur de retour }
  { On la stocke en [BP-2] }
  If IsFunc Then
  Begin
    Dec(CurFrameOffset, 2);
    CurFuncName   := StrLowerCase(FuncName);
    CurFuncRetOfs := CurFrameOffset;

    { Ajouter "result" comme alias de la valeur de retour }
    RetVarIdx := SymAdd('result', SC_VAR, RetTypeIdx);
    If RetVarIdx >= 0 Then
    Begin
      SymTab[RetVarIdx].Offset  := CurFuncRetOfs;
      SymTab[RetVarIdx].IsLocal := True;
    End;
  End
  Else
    CurFuncName := '';

  { Declarations locales const/var avant le begin }
  While ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'const')) Or
        ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'var')) Do
  Begin
    If CurToken.Val = 'const' Then
    Begin
      TplNextToken;
      ParseConstDecl;
    End
    Else
    Begin
      TplNextToken;
      ParseVarDecl;
      If HasPendingAssign Then
      Begin
        HasPendingAssign := False;
        ParseAssignment(PendingAssignName);
      End;
    End;
  End;

  { Calculer la taille du cadre local }
  FrameSize := -CurFrameOffset;  { CurFrameOffset est negatif }

  { Emettre le code de la procedure }
  EmitBlankLine;
  EmitComment('--- ' + FuncName + ' ---');
  If FIdx >= 0 Then
    EmitRaw(SymTab[FIdx].MangledName + '   PROC NEAR')
  Else
    EmitRaw(PSP_FN_PFX + StrUpperCase(FuncName) + '   PROC NEAR');

  { Prologue }
  EmitProlog(FrameSize);

  { Initialiser la valeur de retour a 0 }
  If IsFunc Then
    EmitInstrAB('MOV', 'WORD PTR ' + BPOfs(CurFuncRetOfs), '0');

  { Corps : begin ... end }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'begin') Then
    ParseBlock
  Else
    WarnMsg('''begin'' attendu dans le corps de ' + FuncName);

  { Label de retour (pour Exit) }
  EmitLabel(RetLabel);

  { Charger la valeur de retour dans AX (fonctions) }
  If IsFunc Then
    EmitInstrAB('MOV', 'AX',
      'WORD PTR ' + BPOfs(CurFuncRetOfs));

  { Epilogue }
  EmitEpilog(ParamBytes);

  If FIdx >= 0 Then
    EmitRaw(SymTab[FIdx].MangledName + '   ENDP')
  Else
    EmitRaw(PSP_FN_PFX + StrUpperCase(FuncName) + '   ENDP');
  EmitBlankLine;

  { Consommer le ; final apres end }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    TplNextToken;

  { Restaurer le contexte }
  SymLeaveScope;
  Dec(CurNestLevel);
  CurFrameOffset := SaveFrame;
  CurFuncName    := SaveFuncName;
  CurFuncRetOfs  := SaveRetOfs;
  CurRetLabel    := SaveRetLabel;
  CurParamBytes  := SaveParamB;
End;

{ ---- ParseFuncDecl : analyser une declaration de fonction ----- }
Procedure ParseFuncDecl;
Begin
  ParseFuncOrProc(True);
End;

{ ---- ParseProcDecl : analyser une declaration de procedure ---- }
Procedure ParseProcDecl;
Begin
  ParseFuncOrProc(False);
End;

{ ============================================================
  TABLE DES SYMBOLES [IMPLEMENTE]
  ============================================================ }

{ ---- SymMangle : generer le nom ASM mangled ------------------- }
{ Le prefixe depend de la categorie du symbole.                   }
Function SymMangle(Const Name : TString; Cat : TSymCat) : TString;
Var
  Pfx : TString;
Begin
  Case Cat Of
    SC_VAR        : Pfx := PSP_VAR_PFX;
    SC_CONST      : Pfx := PSP_VAR_PFX;
    SC_TYPED_CONST: Pfx := PSP_VAR_PFX;
    SC_PARAM      : Pfx := PSP_VAR_PFX;
    SC_VARPARAM   : Pfx := PSP_VAR_PFX;
    SC_FUNC       : Pfx := PSP_FN_PFX;
    SC_PROC       : Pfx := PSP_FN_PFX;
    SC_TYPE       : Pfx := '';
    SC_FIELD      : Pfx := PSP_REC_PFX;
    SC_ENUM_VAL   : Pfx := PSP_ENUM_PFX;
    SC_LABEL      : Pfx := PSP_LBL_PFX;
  Else
    Pfx := PSP_VAR_PFX;
  End;
  SymMangle := Pfx + StrUpperCase(Name);
End;

{ ---- SymAdd : ajouter un symbole dans la table --------------- }
{ Retourne l indice du symbole ajoute, ou -1 si table pleine.    }
{ Verifie les doublons dans le scope courant.                     }
Function SymAdd(Const Name : TString; Cat : TSymCat;
               TIdx : Integer) : Integer;
Var
  Lw  : TString;
  Idx : Integer;
  Dup : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    WarnMsg('table des symboles pleine (MAX_SYM=' + IntToStr(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;

  Lw := StrLowerCase(Name);

  { Verifier doublon dans le scope courant }
  Dup := SymFindInScope(Lw, CurScopeLevel);
  If Dup >= 0 Then
  Begin
    { Si c est un forward, on autorise la redefinition }
    If SymTab[Dup].IsForward Then
    Begin
      SymTab[Dup].IsForward := False;
      SymTab[Dup].TypeIdx   := TIdx;
      SymAdd := Dup;
      Exit;
    End
    Else
    Begin
      WarnMsg('symbole deja declare dans ce scope: ' + Name);
      SymAdd := Dup;
      Exit;
    End;
  End;

  Idx := SymCount;
  Inc(SymCount);
  Inc(TotalSyms);

  SymTab[Idx].Name        := Lw;
  SymTab[Idx].MangledName := SymMangle(Lw, Cat);
  SymTab[Idx].Cat         := Cat;
  SymTab[Idx].TypeIdx     := TIdx;
  SymTab[Idx].Offset      := 0;
  SymTab[Idx].ScopeLevel  := CurScopeLevel;
  SymTab[Idx].ScopeId     := CurScopeId;
  SymTab[Idx].IsForward   := False;
  SymTab[Idx].IsLocal     := (CurScopeLevel > 0);
  SymTab[Idx].ImmVal      := 0;
  SymTab[Idx].DataIdx     := -1;

  If Opts.DebugMode Then
    WriteLn('  SYM_ADD[', Idx, ']: ', Lw,
            ' cat=', Ord(Cat),
            ' scope=', CurScopeLevel,
            ' -> ', SymTab[Idx].MangledName);

  SymAdd := Idx;
End;

{ ---- SymFind : rechercher un symbole (interne -> global) ----- }
{ Parcourt la table du plus recent au plus ancien, retourne le    }
{ premier symbole dont le ScopeLevel est inferieur ou egal au     }
{ scope courant. Retourne -1 si non trouve.                       }
Function SymFind(Const Name : TString) : Integer;
Var
  I  : Integer;
  Lw : TString;
Begin
  Lw := StrLowerCase(Name);
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If (SymTab[I].Name = Lw) And
       (SymTab[I].ScopeLevel <= CurScopeLevel) Then
    Begin
      SymFind := I;
      Exit;
    End;
  End;
  SymFind := -1;
End;

{ ---- SymFindInScope : rechercher dans un scope precis -------- }
{ Retourne l indice du symbole ou -1 si non trouve.               }
Function SymFindInScope(Const Name : TString;
                        Level : Integer) : Integer;
Var
  I  : Integer;
  Lw : TString;
Begin
  Lw := StrLowerCase(Name);
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If (SymTab[I].Name = Lw) And
       (SymTab[I].ScopeLevel = Level) And
       ((Level = 0) Or (SymTab[I].ScopeId = CurScopeId)) Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
  End;
  SymFindInScope := -1;
End;

{ ---- SymEnterScope : entrer dans un nouveau scope ------------ }
Procedure SymEnterScope;
Begin
  If CurScopeLevel >= MAX_SCOPE Then
  Begin
    WarnMsg('profondeur de scope maximale atteinte');
    Exit;
  End;
  Inc(CurScopeLevel);
  Inc(ScopeIdSeq);
  CurScopeId := ScopeIdSeq;
  If Opts.DebugMode Then
    WriteLn('  SCOPE_ENTER: level=', CurScopeLevel,
            ' id=', CurScopeId);
End;

{ ---- SymLeaveScope : quitter le scope courant ---------------- }
{ Les symboles du scope courant restent dans la table mais ne     }
{ seront plus trouves par SymFind car ScopeLevel > CurScopeLevel. }
Procedure SymLeaveScope;
Begin
  If CurScopeLevel <= 0 Then
  Begin
    WarnMsg('tentative de quitter le scope global');
    Exit;
  End;
  If Opts.DebugMode Then
    WriteLn('  SCOPE_LEAVE: level=', CurScopeLevel);
  Dec(CurScopeLevel);
  { Restaurer le ScopeId du scope parent }
  If CurScopeLevel = 0 Then
    CurScopeId := 0
  Else
    CurScopeId := CurScopeLevel;  { simplifie, suffisant pour l instant }
End;

{ ---- SymInit : predeclarer les types et symboles builtin ----- }
{ Enregistre les types primitifs et les constantes/procedures     }
{ predefinies dans la table des symboles au scope global (0).     }
Procedure SymInit;
Var
  Idx : Integer;
Begin
  { Types primitifs }
  Idx := SymAdd('integer', SC_TYPE, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'INTEGER';
  Idx := SymAdd('word', SC_TYPE, TY_IDX_WORD);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'WORD';
  Idx := SymAdd('byte', SC_TYPE, TY_IDX_BYTE);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'BYTE';
  Idx := SymAdd('char', SC_TYPE, TY_IDX_CHAR);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'CHAR';
  Idx := SymAdd('boolean', SC_TYPE, TY_IDX_BOOLEAN);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'BOOLEAN';
  Idx := SymAdd('string', SC_TYPE, TY_IDX_STRING);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'STRING';
  Idx := SymAdd('real', SC_TYPE, TY_IDX_REAL);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'REAL';

  { Constantes predefinies : true, false, nil }
  Idx := SymAdd('true', SC_CONST, TY_IDX_BOOLEAN);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].ImmVal := 1;
    SymTab[Idx].MangledName := 'TRUE';
  End;
  Idx := SymAdd('false', SC_CONST, TY_IDX_BOOLEAN);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].ImmVal := 0;
    SymTab[Idx].MangledName := 'FALSE';
  End;
  Idx := SymAdd('nil', SC_CONST, TY_IDX_NIL);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].ImmVal := 0;
    SymTab[Idx].MangledName := 'NIL';
  End;

  { Procedures/fonctions runtime predeclarees }
  Idx := SymAdd('write', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := PSP_RT_PFX + 'WRITE';
  Idx := SymAdd('writeln', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := PSP_RT_PFX + 'WRITELN';
  Idx := SymAdd('read', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := PSP_RT_PFX + 'READ';
  Idx := SymAdd('readln', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := PSP_RT_PFX + 'READLN';
End;

{ ============================================================
  SYSTEME DE TYPES [IMPLEMENTE]
  ============================================================ }

{ ---- TypeInit : enregistrer les types primitifs --------------- }
{ Place les 10 types de base aux indices reserves TY_IDX_*.       }
Procedure TypeInit;

  Procedure AddPrim(Idx : Integer; K : TTypeKind; Sz : Integer);
  Begin
    TypeTab[Idx].Kind        := K;
    TypeTab[Idx].Size        := Sz;
    TypeTab[Idx].BaseTypeIdx := TY_UNKNOWN;
    TypeTab[Idx].Lo          := 0;
    TypeTab[Idx].Hi          := 0;
    TypeTab[Idx].FieldCount  := 0;
    TypeTab[Idx].EnumCount   := 0;
  End;

Begin
  TypeCount := TY_PRIM_COUNT;
  AddPrim(TY_IDX_INTEGER, TKP_INTEGER, 2);   { Integer : 2 octets }
  AddPrim(TY_IDX_WORD,    TKP_WORD,    2);   { Word    : 2 octets }
  AddPrim(TY_IDX_BYTE,    TKP_BYTE,    1);   { Byte    : 1 octet  }
  AddPrim(TY_IDX_CHAR,    TKP_CHAR,    1);   { Char    : 1 octet  }
  AddPrim(TY_IDX_BOOLEAN, TKP_BOOLEAN, 1);   { Boolean : 1 octet  }
  AddPrim(TY_IDX_STRING,  TKP_STRING,  2);   { String  : 2 (ptr)  }
  AddPrim(TY_IDX_REAL,    TKP_REAL,    2);   { Real    : 2 (tronq)}
  AddPrim(TY_IDX_POINTER, TKP_POINTER, 2);   { Pointer : 2 octets }
  AddPrim(TY_IDX_NIL,     TKP_NIL,     2);   { nil     : 2 octets }
  AddPrim(TY_IDX_TEXT,    TKP_TEXT,    2);    { Text    : 2 (handle)}
End;

{ ---- TypeSizeof : retourner la taille d un type en octets ---- }
Function TypeSizeof(TIdx : Integer) : Integer;
Begin
  If (TIdx >= 0) And (TIdx < TypeCount) Then
    TypeSizeof := TypeTab[TIdx].Size
  Else
    TypeSizeof := 2;  { taille par defaut = mot 16 bits }
End;

{ ---- TypeIsOrdinal : le type est-il ordinal ? ---------------- }
{ Entiers, Byte, Char, Boolean, Enum, Subrange sont ordinaux.    }
Function TypeIsOrdinal(TIdx : Integer) : Boolean;
Begin
  If (TIdx < 0) Or (TIdx >= TypeCount) Then
  Begin
    TypeIsOrdinal := False;
    Exit;
  End;
  Case TypeTab[TIdx].Kind Of
    TKP_INTEGER, TKP_WORD, TKP_BYTE, TKP_CHAR,
    TKP_BOOLEAN, TKP_ENUM, TKP_SUBRANGE :
      TypeIsOrdinal := True;
  Else
    TypeIsOrdinal := False;
  End;
End;

{ ---- TypeIsNumeric : le type est-il numerique ? -------------- }
{ Integer, Word, Byte, Real (et Char via Ord implicite).         }
Function TypeIsNumeric(TIdx : Integer) : Boolean;
Begin
  If (TIdx < 0) Or (TIdx >= TypeCount) Then
  Begin
    TypeIsNumeric := False;
    Exit;
  End;
  Case TypeTab[TIdx].Kind Of
    TKP_INTEGER, TKP_WORD, TKP_BYTE, TKP_REAL :
      TypeIsNumeric := True;
  Else
    TypeIsNumeric := False;
  End;
End;

{ ---- TypeIsPointer : le type est-il un pointeur ? ------------ }
Function TypeIsPointer(TIdx : Integer) : Boolean;
Begin
  If (TIdx < 0) Or (TIdx >= TypeCount) Then
  Begin
    TypeIsPointer := False;
    Exit;
  End;
  Case TypeTab[TIdx].Kind Of
    TKP_POINTER, TKP_NIL, TKP_STRING :
      TypeIsPointer := True;
  Else
    TypeIsPointer := False;
  End;
End;

{ ---- TypeCompatible : deux types sont-ils compatibles ? ------- }
{ Retourne True si on peut affecter une valeur de type T2 a T1.   }
{ Couvre les promotions implicites Pascal classiques.              }
Function TypeCompatible(T1, T2 : Integer) : Boolean;
Var
  K1, K2 : TTypeKind;
Begin
  { Types identiques : toujours compatible }
  If T1 = T2 Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Si l un des deux est inconnu, accepter }
  If (T1 = TY_UNKNOWN) Or (T2 = TY_UNKNOWN) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Verifier les bornes }
  If (T1 < 0) Or (T1 >= TypeCount) Or
     (T2 < 0) Or (T2 >= TypeCount) Then
  Begin
    TypeCompatible := False;
    Exit;
  End;

  K1 := TypeTab[T1].Kind;
  K2 := TypeTab[T2].Kind;

  { nil -> tout type pointeur ou string }
  If K2 = TKP_NIL Then
  Begin
    TypeCompatible := (K1 = TKP_POINTER) Or (K1 = TKP_STRING) Or
                      (K1 = TKP_NIL);
    Exit;
  End;

  { Integer <-> Word (implicite, avec avertissement eventuel) }
  If ((K1 = TKP_INTEGER) Or (K1 = TKP_WORD)) And
     ((K2 = TKP_INTEGER) Or (K2 = TKP_WORD)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Byte -> Integer ou Word (promotion implicite) }
  If (K2 = TKP_BYTE) And
     ((K1 = TKP_INTEGER) Or (K1 = TKP_WORD) Or (K1 = TKP_BYTE)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Integer/Word -> Byte (retrecissement implicite avec avertissement) }
  If (K1 = TKP_BYTE) And
     ((K2 = TKP_INTEGER) Or (K2 = TKP_WORD)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Char <-> Integer (Ord/Chr) }
  If ((K1 = TKP_CHAR) And (K2 = TKP_INTEGER)) Or
     ((K1 = TKP_INTEGER) And (K2 = TKP_CHAR)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Char <-> Byte }
  If ((K1 = TKP_CHAR) And (K2 = TKP_BYTE)) Or
     ((K1 = TKP_BYTE) And (K2 = TKP_CHAR)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Char <-> String (1 caractere, conversion implicite) }
  If ((K1 = TKP_CHAR) And (K2 = TKP_STRING)) Or
     ((K1 = TKP_STRING) And (K2 = TKP_CHAR)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Boolean -> Integer (0|1) }
  If (K2 = TKP_BOOLEAN) And
     ((K1 = TKP_INTEGER) Or (K1 = TKP_WORD) Or (K1 = TKP_BYTE)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Integer -> Boolean (non-zero = true) }
  If (K1 = TKP_BOOLEAN) And
     ((K2 = TKP_INTEGER) Or (K2 = TKP_WORD) Or (K2 = TKP_BYTE)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Enum -> Integer (Ord) }
  If (K2 = TKP_ENUM) And
     ((K1 = TKP_INTEGER) Or (K1 = TKP_WORD)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Subrange -> son type de base }
  If (K2 = TKP_SUBRANGE) And
     (TypeTab[T2].BaseTypeIdx = T1) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;
  If (K1 = TKP_SUBRANGE) And
     (TypeTab[T1].BaseTypeIdx = T2) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Real <-> Integer (tronquage implicite) }
  If ((K1 = TKP_REAL) And ((K2 = TKP_INTEGER) Or (K2 = TKP_WORD))) Or
     (((K1 = TKP_INTEGER) Or (K1 = TKP_WORD)) And (K2 = TKP_REAL)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Pointer <-> tout type pointeur }
  If ((K1 = TKP_POINTER) And (K2 = TKP_POINTER)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  TypeCompatible := False;
End;

{ ---- TypeCoerce : emettre le code de conversion src -> dst ---- }
{ Retourne le TypeIdx du resultat. Si aucune conversion n est      }
{ necessaire, retourne SrcType. Si incompatible, avertit et        }
{ retourne DstType.                                                }
Function TypeCoerce(SrcType, DstType : Integer) : Integer;
Var
  Ks, Kd : TTypeKind;
Begin
  { Meme type : rien a faire }
  If SrcType = DstType Then
  Begin
    TypeCoerce := SrcType;
    Exit;
  End;

  { Inconnu : pas de conversion }
  If (SrcType = TY_UNKNOWN) Or (DstType = TY_UNKNOWN) Then
  Begin
    If DstType <> TY_UNKNOWN Then
      TypeCoerce := DstType
    Else
      TypeCoerce := SrcType;
    Exit;
  End;

  If (SrcType < 0) Or (SrcType >= TypeCount) Or
     (DstType < 0) Or (DstType >= TypeCount) Then
  Begin
    TypeCoerce := DstType;
    Exit;
  End;

  Ks := TypeTab[SrcType].Kind;
  Kd := TypeTab[DstType].Kind;

  { Byte -> Integer/Word : extension zero MOVZX ou XOR AH,AH }
  If (Ks = TKP_BYTE) And ((Kd = TKP_INTEGER) Or (Kd = TKP_WORD)) Then
  Begin
    EmitComment('coerce byte -> word');
    EmitInstrAB('XOR', 'AH', 'AH');
    TypeCoerce := DstType;
    Exit;
  End;

  { Char -> Integer : meme que Byte -> Integer (Ord) }
  If (Ks = TKP_CHAR) And ((Kd = TKP_INTEGER) Or (Kd = TKP_WORD)) Then
  Begin
    EmitComment('coerce char -> word (Ord)');
    EmitInstrAB('XOR', 'AH', 'AH');
    TypeCoerce := DstType;
    Exit;
  End;

  { Integer/Word -> Byte : troncature (prendre AL) }
  If ((Ks = TKP_INTEGER) Or (Ks = TKP_WORD)) And (Kd = TKP_BYTE) Then
  Begin
    EmitComment('coerce word -> byte (troncature)');
    { AX contient la valeur, AL est deja le byte bas }
    TypeCoerce := DstType;
    Exit;
  End;

  { Boolean -> Integer : deja 0|1 dans AX }
  If (Ks = TKP_BOOLEAN) And
     ((Kd = TKP_INTEGER) Or (Kd = TKP_WORD)) Then
  Begin
    EmitComment('coerce boolean -> word');
    EmitInstrAB('XOR', 'AH', 'AH');
    TypeCoerce := DstType;
    Exit;
  End;

  { Integer -> Boolean : CMP AX,0 / SETNE AL / XOR AH,AH }
  If ((Ks = TKP_INTEGER) Or (Ks = TKP_WORD)) And
     (Kd = TKP_BOOLEAN) Then
  Begin
    EmitComment('coerce word -> boolean');
    EmitInstrAB('CMP', 'AX', '0');
    EmitInstrAB('MOV', 'AX', '0');
    EmitInstr('JE     $+4');
    EmitInstrAB('MOV', 'AX', '1');
    TypeCoerce := DstType;
    Exit;
  End;

  { Char -> String : sera gere par le runtime (Chr) }
  If (Ks = TKP_CHAR) And (Kd = TKP_STRING) Then
  Begin
    EmitComment('coerce char -> string (runtime)');
    TypeCoerce := DstType;
    Exit;
  End;

  { nil -> Pointer : valeur deja 0 }
  If (Ks = TKP_NIL) And ((Kd = TKP_POINTER) Or (Kd = TKP_STRING)) Then
  Begin
    TypeCoerce := DstType;
    Exit;
  End;

  { Real -> Integer : tronquage (deja fait par le front-end) }
  If (Ks = TKP_REAL) And ((Kd = TKP_INTEGER) Or (Kd = TKP_WORD)) Then
  Begin
    WarnMsg('reel tronque en entier');
    TypeCoerce := DstType;
    Exit;
  End;

  { Integer -> Real : on garde la valeur entiere }
  If ((Ks = TKP_INTEGER) Or (Ks = TKP_WORD)) And (Kd = TKP_REAL) Then
  Begin
    TypeCoerce := DstType;
    Exit;
  End;

  { Enum -> Integer (Ord) }
  If (Ks = TKP_ENUM) And ((Kd = TKP_INTEGER) Or (Kd = TKP_WORD)) Then
  Begin
    EmitComment('coerce enum -> word (Ord)');
    TypeCoerce := DstType;
    Exit;
  End;

  { Integer <-> Word : meme representation, pas de code }
  If ((Ks = TKP_INTEGER) And (Kd = TKP_WORD)) Or
     ((Ks = TKP_WORD) And (Kd = TKP_INTEGER)) Then
  Begin
    If Opts.Warnings Then
      WarnMsg('conversion implicite signe <-> non-signe');
    TypeCoerce := DstType;
    Exit;
  End;

  { Pas de conversion connue : avertissement }
  If Opts.Warnings Then
    WarnMsg('conversion de type implicite non supportee');
  TypeCoerce := DstType;
End;

{ ---- TypeResolve : resoudre un nom de type en indice ---------- }
{ Cherche d abord dans SymTab (SC_TYPE), sinon retourne TY_UNKNOWN.}
Function TypeResolve(Const Name : TString) : Integer;
Var
  Idx : Integer;
Begin
  Idx := SymFind(Name);
  If (Idx >= 0) And (SymTab[Idx].Cat = SC_TYPE) Then
    TypeResolve := SymTab[Idx].TypeIdx
  Else
    TypeResolve := TY_UNKNOWN;
End;

{ ============================================================
  OPERATEURS ET PRECEDENCE [IMPLEMENTE]
  ============================================================ }

{ ---- Emetteur ASM : instructions formatees ------------------- }

{ EmitComment : commentaire ASM (prefixe ;) }
Procedure EmitComment(Const S : TString);
Begin
  WriteLn(OutF, '; ', S);
End;

{ EmitLabel : label ASM suivi de ':' en colonne 0 }
Procedure EmitLabel(Const Lbl : TString);
Begin
  WriteLn(OutF, Lbl, ':');
End;

{ EmitInstr : instruction sans operande (8 espaces) }
Procedure EmitInstr(Const Mnem : TString);
Begin
  WriteLn(OutF, '        ', Mnem);
End;

{ EmitInstrA : instruction + un operande }
Procedure EmitInstrA(Const Mnem, A1 : TString);
Begin
  WriteLn(OutF, '        ', Mnem, '   ', A1);
End;

{ EmitInstrAB : instruction + deux operandes }
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);
Begin
  WriteLn(OutF, '        ', Mnem, '   ', A1, ', ', A2);
End;

{ ============================================================
  EMETTEUR DE CODE ASM [IMPLEMENTE]
  ============================================================ }

{ ---- EmitBlankLine : ligne vide dans la sortie ASM ----------- }
Procedure EmitBlankLine;
Begin
  WriteLn(OutF);
End;

{ ---- NewLabel : generer un label unique ---------------------- }
{ Utilise le compteur LabelGenSeq existant avec prefixe _PSPL_.  }
Function NewLabel : TString;
Var
  S : TString;
Begin
  Inc(LabelGenSeq);
  Str(LabelGenSeq, S);
  While Length(S) < 5 Do
    S := '0' + S;
  NewLabel := PSP_LBL_PFX + S;
End;

{ ---- EmitHeader : en-tete du fichier ASM --------------------- }
{ Genere le prologue MASM .MODEL SMALL avec segment de code.      }
Procedure EmitHeader;
Begin
  EmitComment('========================================');
  EmitComment('Genere par PSP86 v' + PSP86_VERSION +
              ' (' + PSP86_DATE + ')');
  EmitComment('Source : ' + Opts.SrcFile);
  EmitComment('========================================');
  EmitBlankLine;
  EmitRaw('.MODEL SMALL');
  EmitRaw('.STACK ' + IntToStr(STACK_SIZE));
  EmitBlankLine;
  EmitComment('--- Segment de code ---');
  EmitRaw('_TEXT   SEGMENT WORD PUBLIC ''CODE''');
  EmitRaw('        ASSUME CS:_TEXT, DS:_DATA');
  EmitBlankLine;
  EmitComment('--- Point d entree principal ---');
  EmitLabel(PSP_FN_PFX + 'MAIN');
  EmitInstrAB('MOV', 'AX', '_DATA');
  EmitInstrAB('MOV', 'DS', 'AX');
  EmitBlankLine;
End;

{ ---- EmitFooter : fin du fichier ASM ------------------------- }
{ Genere le code de sortie DOS (INT 21h/4Ch), ferme le segment.   }
Procedure EmitFooter;
Begin
  { Si le label MAINBODY n a pas ete emis (code sans instructions) }
  If Not MainBodyEmitted Then
  Begin
    MainBodyEmitted := True;
    EmitLabel(PSP_LBL_PFX + 'MAINBODY');
    { emettre Content-Type si defini par <%@ ContentType=...%> }
    If ContentTypeLbl <> '' Then
    Begin
      EmitInstrAB('MOV', 'SI', 'OFFSET ' + ContentTypeLbl);
      EmitInstrA('CALL', PSP_RT_PFX + 'PRINTSTR');
    End;
  End;

  EmitBlankLine;
  EmitComment('--- Sortie programme (DOS INT 21h) ---');
  EmitInstrAB('MOV', 'AH', '4Ch');
  EmitInstrAB('MOV', 'AL', '0');
  EmitInstr('INT    21h');
  EmitBlankLine;

  { --- Routines runtime --- }
  If RuntimeEmitted Then Exit;
  RuntimeEmitted := True;
  EmitComment('=== Routines runtime ===');
  EmitBlankLine;

  { _PSPRT_PRINTSTR : afficher chaine ASCIIZ pointee par SI }
  EmitComment('PRINTSTR : affiche chaine ASCIIZ (SI -> chaine)');
  EmitLabel(PSP_RT_PFX + 'PRINTSTR');
  EmitRaw(PSP_RT_PFX + 'PRINTSTR_LP:');
  EmitInstr('LODSB');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'PRINTSTR_DONE');
  EmitInstrAB('MOV', 'DL', 'AL');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstr('INT    21h');
  EmitInstrA('JMP', PSP_RT_PFX + 'PRINTSTR_LP');
  EmitRaw(PSP_RT_PFX + 'PRINTSTR_DONE:');
  EmitInstr('RET');
  EmitBlankLine;

  { _PSPRT_NUMTOSTR : convertir AX (signe) en chaine dans NUMBUF }
  EmitComment('NUMTOSTR : convertit AX (signe) -> NUMBUF (ASCIIZ)');
  EmitLabel(PSP_RT_PFX + 'NUMTOSTR');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('MOV', 'DI', 'OFFSET ' + PSP_RT_PFX + 'NUMBUF');
  EmitInstrAB('MOV', 'CX', '0');        { compteur chiffres }
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JGE', PSP_RT_PFX + 'NTS_POS');
  { Nombre negatif : stocker '-' et prendre AX = -AX }
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '''-''');
  EmitInstr('INC    DI');
  EmitInstr('NEG    AX');
  EmitRaw(PSP_RT_PFX + 'NTS_POS:');
  EmitInstrAB('MOV', 'BX', '10');
  EmitRaw(PSP_RT_PFX + 'NTS_DIV:');
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitInstrA('DIV', 'BX');           { AX = quotient, DX = reste }
  EmitInstrAB('ADD', 'DL', '''0''');
  EmitInstrA('PUSH', 'DX');          { empiler chiffre }
  EmitInstr('INC    CX');
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JNE', PSP_RT_PFX + 'NTS_DIV');
  { Depiler chiffres dans l ordre }
  EmitRaw(PSP_RT_PFX + 'NTS_POP:');
  EmitInstrA('POP', 'AX');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstr('INC    DI');
  EmitInstr('LOOP   ' + PSP_RT_PFX + 'NTS_POP');
  { Terminer la chaine par NUL }
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- Routines runtime chaines --- }

  { _PSPRT_STRLEN : longueur chaine ASCIIZ }
  { Entree : SI = pointeur chaine. Sortie : AX = longueur }
  EmitComment('STRLEN : longueur chaine ASCIIZ (SI -> AX)');
  EmitLabel(PSP_RT_PFX + 'STRLEN');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitRaw(PSP_RT_PFX + 'STRLEN_LP:');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'STRLEN_DONE');
  EmitInstr('INC    AX');
  EmitInstr('INC    SI');
  EmitInstrA('JMP', PSP_RT_PFX + 'STRLEN_LP');
  EmitRaw(PSP_RT_PFX + 'STRLEN_DONE:');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitBlankLine;

  { _PSPRT_CONCAT : concatener deux chaines ASCIIZ }
  { Entree : SI = s1, DI = s2. Sortie : AX = ptr _PSPRT_STRBUF }
  EmitComment('CONCAT : SI + DI -> AX = ptr STRBUF');
  EmitLabel(PSP_RT_PFX + 'CONCAT');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('MOV', 'BX', 'OFFSET ' + PSP_RT_PFX + 'STRBUF');
  { Copier s1 }
  EmitRaw(PSP_RT_PFX + 'CONCAT_S1:');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'CONCAT_S2');
  EmitInstrAB('MOV', '[BX]', 'AL');
  EmitInstr('INC    SI');
  EmitInstr('INC    BX');
  EmitInstrA('JMP', PSP_RT_PFX + 'CONCAT_S1');
  { Copier s2 }
  EmitRaw(PSP_RT_PFX + 'CONCAT_S2:');
  EmitInstrAB('MOV', 'AL', '[DI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'CONCAT_END');
  EmitInstrAB('MOV', '[BX]', 'AL');
  EmitInstr('INC    DI');
  EmitInstr('INC    BX');
  EmitInstrA('JMP', PSP_RT_PFX + 'CONCAT_S2');
  EmitRaw(PSP_RT_PFX + 'CONCAT_END:');
  EmitInstrAB('MOV', 'BYTE PTR [BX]', '0');
  EmitInstrAB('LEA', 'AX', PSP_RT_PFX + 'STRBUF');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitBlankLine;

  { _PSPRT_STRCMP : comparer deux chaines ASCIIZ }
  { Entree : SI = s1, DI = s2. Sortie : AX = <0, 0 ou >0 }
  EmitComment('STRCMP : SI vs DI -> AX (signe)');
  EmitLabel(PSP_RT_PFX + 'STRCMP');
  EmitRaw(PSP_RT_PFX + 'STRCMP_LP:');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', 'AH', '[DI]');
  EmitInstrAB('CMP', 'AL', 'AH');
  EmitInstrA('JNE', PSP_RT_PFX + 'STRCMP_DIFF');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'STRCMP_EQ');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstrA('JMP', PSP_RT_PFX + 'STRCMP_LP');
  EmitRaw(PSP_RT_PFX + 'STRCMP_EQ:');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstr('RET');
  EmitRaw(PSP_RT_PFX + 'STRCMP_DIFF:');
  EmitInstrAB('XOR', 'AH', 'AH');
  EmitInstrAB('MOV', 'BL', '[DI]');
  EmitInstrAB('XOR', 'BH', 'BH');
  EmitInstrAB('SUB', 'AX', 'BX');
  EmitInstr('RET');
  EmitBlankLine;

  { _PSPRT_CHR : convertir code ASCII en chaine 1 caractere }
  { Entree : AL = code. Sortie : AX = ptr _PSPRT_CHRBUF }
  EmitComment('CHR : AL -> AX = ptr chaine 1 car');
  EmitLabel(PSP_RT_PFX + 'CHR');
  EmitInstrAB('MOV', 'BYTE PTR [' + PSP_RT_PFX + 'CHRBUF]', 'AL');
  EmitInstrAB('MOV', 'BYTE PTR [' + PSP_RT_PFX + 'CHRBUF+1]', '0');
  EmitInstrAB('LEA', 'AX', PSP_RT_PFX + 'CHRBUF');
  EmitInstr('RET');
  EmitBlankLine;

  { _PSPRT_STRTONUM : convertir chaine ASCIIZ en entier signe }
  { Entree : SI = ptr chaine. Sortie : AX = valeur }
  EmitComment('STRTONUM : SI -> AX (entier signe)');
  EmitLabel(PSP_RT_PFX + 'STRTONUM');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrAB('XOR', 'CX', 'CX');       { CX = flag negatif }
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '''-''');
  EmitInstrA('JNE', PSP_RT_PFX + 'STN_LP');
  EmitInstrAB('MOV', 'CX', '1');
  EmitInstr('INC    SI');
  EmitRaw(PSP_RT_PFX + 'STN_LP:');
  EmitInstrAB('MOV', 'BL', '[SI]');
  EmitInstrAB('CMP', 'BL', '''0''');
  EmitInstrA('JB', PSP_RT_PFX + 'STN_DONE');
  EmitInstrAB('CMP', 'BL', '''9''');
  EmitInstrA('JA', PSP_RT_PFX + 'STN_DONE');
  EmitInstrAB('SUB', 'BL', '''0''');
  EmitInstrAB('XOR', 'BH', 'BH');
  EmitInstrA('PUSH', 'BX');
  EmitInstrAB('MOV', 'BX', '10');
  EmitInstrA('IMUL', 'BX');
  EmitInstrA('POP', 'BX');
  EmitInstrAB('ADD', 'AX', 'BX');
  EmitInstr('INC    SI');
  EmitInstrA('JMP', PSP_RT_PFX + 'STN_LP');
  EmitRaw(PSP_RT_PFX + 'STN_DONE:');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'STN_RET');
  EmitInstr('NEG    AX');
  EmitRaw(PSP_RT_PFX + 'STN_RET:');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitBlankLine;

  { _PSPRT_COPY : sous-chaine }
  { Entree : SI=source, BX=pos(1-base), CX=len. Sortie : AX=ptr STRBUF }
  EmitComment('COPY : SI,BX,CX -> AX = ptr STRBUF');
  EmitLabel(PSP_RT_PFX + 'COPY');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('MOV', 'DI', 'OFFSET ' + PSP_RT_PFX + 'STRBUF');
  { Avancer SI de (BX-1) positions }
  EmitInstrA('DEC', 'BX');
  EmitInstrAB('ADD', 'SI', 'BX');
  EmitRaw(PSP_RT_PFX + 'COPY_LP:');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'COPY_END');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'COPY_END');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstr('DEC    CX');
  EmitInstrA('JMP', PSP_RT_PFX + 'COPY_LP');
  EmitRaw(PSP_RT_PFX + 'COPY_END:');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('LEA', 'AX', PSP_RT_PFX + 'STRBUF');
  EmitInstrA('POP', 'DI');
  EmitInstr('RET');
  EmitBlankLine;

  { _PSPRT_POS : position d une sous-chaine }
  { Entree : SI=sub, DI=str. Sortie : AX = pos (1-base) ou 0 }
  EmitComment('POS : SI=sub, DI=str -> AX (1-base ou 0)');
  EmitLabel(PSP_RT_PFX + 'POS');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('XOR', 'DX', 'DX');       { DX = position courante (0-base) }
  EmitRaw(PSP_RT_PFX + 'POS_OUTER:');
  EmitInstrAB('CMP', 'BYTE PTR [DI]', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'POS_NOTFOUND');
  { Comparer sub a partir de DI+DX }
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('ADD', 'DI', 'DX');
  EmitRaw(PSP_RT_PFX + 'POS_CMP:');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'POS_FOUND');
  EmitInstrAB('CMP', 'AL', '[DI]');
  EmitInstrA('JNE', PSP_RT_PFX + 'POS_NEXT');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstrA('JMP', PSP_RT_PFX + 'POS_CMP');
  EmitRaw(PSP_RT_PFX + 'POS_FOUND:');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstrAB('MOV', 'AX', 'DX');
  EmitInstr('INC    AX');                { 1-base }
  EmitInstrA('JMP', PSP_RT_PFX + 'POS_RET');
  EmitRaw(PSP_RT_PFX + 'POS_NEXT:');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('INC    DX');
  EmitInstrA('JMP', PSP_RT_PFX + 'POS_OUTER');
  EmitRaw(PSP_RT_PFX + 'POS_NOTFOUND:');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitRaw(PSP_RT_PFX + 'POS_RET:');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- Routines runtime tableaux --- }

  { _PSPRT_FILLCHAR : remplir un bloc memoire }
  { Entree : DI = ptr dest, CX = count, AL = valeur }
  EmitComment('FILLCHAR : DI=ptr, CX=n, AL=val -> REP STOSB');
  EmitLabel(PSP_RT_PFX + 'FILLCHAR');
  EmitInstr('REP    STOSB');
  EmitInstr('RET');
  EmitBlankLine;

  { _PSPRT_MOVE : copier un bloc memoire }
  { Entree : SI = ptr src, DI = ptr dest, CX = count }
  EmitComment('MOVE : SI=src, DI=dst, CX=n -> REP MOVSB');
  EmitLabel(PSP_RT_PFX + 'MOVE');
  EmitInstr('REP    MOVSB');
  EmitInstr('RET');
  EmitBlankLine;

  { --- Routines runtime --- }

  { _PSPRT_SQRT : racine carree entiere (Newton-Raphson) }
  { Entree : AX = n. Sortie : AX = floor(sqrt(n)) }
  EmitComment('SQRT : AX=n -> AX=floor(sqrt(n))');
  EmitLabel(PSP_RT_PFX + 'SQRT');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JLE', PSP_RT_PFX + 'SQRT_RET0');
  EmitInstrAB('MOV', 'BX', 'AX');        { BX = n }
  EmitInstrAB('SHR', 'AX', '1');         { AX = x(0) = n/2 }
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'SQRT_ONE');
  EmitRaw(PSP_RT_PFX + 'SQRT_LP:');
  EmitInstrAB('MOV', 'CX', 'AX');        { CX = x(k) }
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitInstrA('DIV', 'CX');               { AX = n / x(k) }
  EmitInstrAB('ADD', 'AX', 'CX');        { AX = x(k) + n/x(k) }
  EmitInstrAB('SHR', 'AX', '1');         { AX = x(k+1) }
  EmitInstrAB('CMP', 'AX', 'CX');
  EmitInstrA('JB', PSP_RT_PFX + 'SQRT_LP');
  EmitInstrAB('MOV', 'AX', 'CX');        { resultat = x(k) }
  EmitInstrA('JMP', PSP_RT_PFX + 'SQRT_END');
  EmitRaw(PSP_RT_PFX + 'SQRT_RET0:');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrA('JMP', PSP_RT_PFX + 'SQRT_END');
  EmitRaw(PSP_RT_PFX + 'SQRT_ONE:');
  EmitInstrAB('MOV', 'AX', '1');
  EmitRaw(PSP_RT_PFX + 'SQRT_END:');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitBlankLine;

  { _PSPRT_RANDOM : generateur LCG 16 bits }
  { Sortie : AX = nombre pseudo-aleatoire 0..32767 }
  EmitComment('RANDOM : AX = pseudo-aleatoire 0..32767');
  EmitLabel(PSP_RT_PFX + 'RANDOM');
  EmitInstrAB('MOV', 'AX', 'WORD PTR [' + PSP_RT_PFX + 'SEED]');
  EmitInstrAB('MOV', 'CX', '25173');
  EmitInstr('MUL    CX');
  EmitInstrAB('ADD', 'AX', '13849');
  EmitInstrAB('MOV', 'WORD PTR [' + PSP_RT_PFX + 'SEED]', 'AX');
  EmitInstrAB('AND', 'AX', '7FFFh');
  EmitInstr('RET');
  EmitBlankLine;

  { _PSPRT_RANDOMIZE : initialiser la graine depuis l horloge }
  EmitComment('RANDOMIZE : graine depuis horloge DOS');
  EmitLabel(PSP_RT_PFX + 'RANDOMIZE');
  EmitInstrAB('MOV', 'AH', '00h');
  EmitInstr('INT    1Ah');                { CX:DX = ticks }
  EmitInstrAB('MOV', 'WORD PTR [' + PSP_RT_PFX + 'SEED]', 'DX');
  EmitInstr('RET');
  EmitBlankLine;

  { _PSPRT_ALLOC : allocation bump dans le heap statique }
  { Entree : CX = taille. Sortie : AX = pointeur }
  EmitComment('ALLOC : CX=taille -> AX=ptr (bump alloc)');
  EmitLabel(PSP_RT_PFX + 'ALLOC');
  EmitInstrAB('MOV', 'AX', 'WORD PTR [' + PSP_RT_PFX + 'HEAPTOP]');
  EmitInstrAB('ADD', 'WORD PTR [' + PSP_RT_PFX + 'HEAPTOP]', 'CX');
  EmitInstr('RET');
  EmitBlankLine;

  { _PSPRT_READCHAR : lire un caractere depuis clavier }
  { Sortie : AL = caractere lu }
  EmitComment('READCHAR : AL = caractere clavier (INT 21h/01h)');
  EmitLabel(PSP_RT_PFX + 'READCHAR');
  EmitInstrAB('MOV', 'AH', '01h');
  EmitInstr('INT    21h');
  EmitInstr('RET');
  EmitBlankLine;

  { _PSPRT_READNUM : lire un entier depuis clavier }
  { Lit des caracteres jusqu a CR, convertit en entier }
  { Sortie : AX = entier lu }
  EmitComment('READNUM : AX = entier lu depuis clavier');
  EmitLabel(PSP_RT_PFX + 'READNUM');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('MOV', 'DI', 'OFFSET ' + PSP_RT_PFX + 'NUMBUF');
  EmitInstrAB('XOR', 'CX', 'CX');        { CX = index }
  EmitRaw(PSP_RT_PFX + 'RN_LP:');
  EmitInstrAB('MOV', 'AH', '01h');
  EmitInstr('INT    21h');                { AL = char }
  EmitInstrAB('CMP', 'AL', '13');        { CR ? }
  EmitInstrA('JE', PSP_RT_PFX + 'RN_DONE');
  EmitInstrAB('CMP', 'AL', '10');        { LF ? }
  EmitInstrA('JE', PSP_RT_PFX + 'RN_DONE');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstr('INC    DI');
  EmitInstr('INC    CX');
  EmitInstrAB('CMP', 'CX', '10');        { max 10 chiffres }
  EmitInstrA('JB', PSP_RT_PFX + 'RN_LP');
  EmitRaw(PSP_RT_PFX + 'RN_DONE:');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  { Convertir via STRTONUM }
  EmitInstrAB('MOV', 'SI', 'OFFSET ' + PSP_RT_PFX + 'NUMBUF');
  EmitInstrA('CALL', PSP_RT_PFX + 'STRTONUM');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _PSPRT_PRINT : ecriture brute via handle --- }
  { Entree : BX=handle, DX=buf, CX=len }
  EmitComment('PRINT : BX=handle, DX=buf, CX=len -> INT 21h/40h');
  EmitLabel(PSP_RT_PFX + 'PRINT');
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstr('INT    21h');
  EmitInstr('RET');
  EmitBlankLine;

  { _PSPRT_PRINTLN : affiche chaine ASCIIZ + CR LF }
  { Entree : SI = pointeur chaine ASCIIZ }
  EmitComment('PRINTLN : SI=chaine ASCIIZ -> affiche + CRLF');
  EmitLabel(PSP_RT_PFX + 'PRINTLN');
  EmitInstrA('CALL', PSP_RT_PFX + 'PRINTSTR');
  EmitInstrAB('MOV', 'SI', 'OFFSET ' + PSP_RT_PFX + 'CRLF');
  EmitInstrA('CALL', PSP_RT_PFX + 'PRINTSTR');
  EmitInstr('RET');
  EmitBlankLine;

  { _PSPRT_DELETE : supprimer len caracteres a pos dans chaine }
  { Entree : SI=chaine ASCIIZ, BX=pos (1-base), CX=len }
  { Modifie la chaine en place via copie STRBUF }
  EmitComment('DELETE : SI=str, BX=pos(1), CX=len -> modifie en place');
  EmitLabel(PSP_RT_PFX + 'DELETE');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstr('DEC    BX');               { pos 0-base }
  { Copier la partie avant pos dans STRBUF }
  EmitInstrAB('MOV', 'DI', 'OFFSET ' + PSP_RT_PFX + 'STRBUF');
  EmitInstrA('PUSH', 'CX');            { sauver len }
  EmitInstrAB('MOV', 'CX', 'BX');     { CX = pos-1 (nb chars avant) }
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'DEL_SKIP1');
  EmitRaw(PSP_RT_PFX + 'DEL_CP1:');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstr('LOOP   ' + PSP_RT_PFX + 'DEL_CP1');
  EmitRaw(PSP_RT_PFX + 'DEL_SKIP1:');
  { Avancer SI de len caracteres }
  EmitInstrA('POP', 'CX');            { restaurer len }
  EmitRaw(PSP_RT_PFX + 'DEL_ADV:');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'DEL_TAIL');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'DEL_TAIL');
  EmitInstr('INC    SI');
  EmitInstr('DEC    CX');
  EmitInstrA('JMP', PSP_RT_PFX + 'DEL_ADV');
  { Copier le reste (y compris NUL terminal) }
  EmitRaw(PSP_RT_PFX + 'DEL_TAIL:');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'DEL_END');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstrA('JMP', PSP_RT_PFX + 'DEL_TAIL');
  EmitRaw(PSP_RT_PFX + 'DEL_END:');
  { Copier STRBUF vers la chaine originale }
  EmitInstrA('POP', 'DI');            { DI = ptr chaine originale }
  EmitInstrAB('MOV', 'SI', 'OFFSET ' + PSP_RT_PFX + 'STRBUF');
  EmitRaw(PSP_RT_PFX + 'DEL_BACK:');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'DEL_RET');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstrA('JMP', PSP_RT_PFX + 'DEL_BACK');
  EmitRaw(PSP_RT_PFX + 'DEL_RET:');
  EmitInstrA('POP', 'DI');
  EmitInstr('RET');
  EmitBlankLine;

  { _PSPRT_INSERT : inserer sous-chaine dans chaine a position }
  { Entree : SI=sub, DI=str (dest), BX=pos (1-base) }
  { Resultat dans STRBUF puis recopie vers str }
  EmitComment('INSERT : SI=sub, DI=str, BX=pos(1) -> modifie str');
  EmitLabel(PSP_RT_PFX + 'INSERT');
  EmitInstrA('PUSH', 'DI');            { sauver ptr str original }
  EmitInstrA('PUSH', 'SI');            { sauver ptr sub }
  EmitInstr('DEC    BX');              { pos 0-base }
  EmitInstrAB('MOV', 'SI', 'DI');     { SI = str source }
  EmitInstrAB('MOV', 'DI', 'OFFSET ' + PSP_RT_PFX + 'STRBUF');
  { Copier pos premiers chars de str }
  EmitInstrAB('MOV', 'CX', 'BX');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'INS_SUB');
  EmitRaw(PSP_RT_PFX + 'INS_CP1:');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'INS_SUB');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstr('LOOP   ' + PSP_RT_PFX + 'INS_CP1');
  { Copier la sous-chaine }
  EmitRaw(PSP_RT_PFX + 'INS_SUB:');
  EmitInstrA('POP', 'AX');            { AX = ptr sub (sauvegarde) }
  EmitInstrA('PUSH', 'SI');           { sauver position courante dans str }
  EmitInstrAB('MOV', 'SI', 'AX');    { SI = sub }
  EmitRaw(PSP_RT_PFX + 'INS_CP2:');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'INS_REST');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstrA('JMP', PSP_RT_PFX + 'INS_CP2');
  { Copier le reste de str }
  EmitRaw(PSP_RT_PFX + 'INS_REST:');
  EmitInstrA('POP', 'SI');            { SI = position dans str apres prefix }
  EmitRaw(PSP_RT_PFX + 'INS_CP3:');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'INS_DONE');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstrA('JMP', PSP_RT_PFX + 'INS_CP3');
  EmitRaw(PSP_RT_PFX + 'INS_DONE:');
  { Recopier STRBUF vers str original }
  EmitInstrA('POP', 'DI');            { DI = ptr str original }
  EmitInstrAB('MOV', 'SI', 'OFFSET ' + PSP_RT_PFX + 'STRBUF');
  EmitRaw(PSP_RT_PFX + 'INS_BACK:');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'INS_RET');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstrA('JMP', PSP_RT_PFX + 'INS_BACK');
  EmitRaw(PSP_RT_PFX + 'INS_RET:');
  EmitInstr('RET');
  EmitBlankLine;

  { _PSPRT_LOWERCASE : convertir en minuscules }
  { Entree : SI=chaine ASCIIZ. Sortie : AX=ptr STRBUF }
  EmitComment('LOWERCASE : SI=str -> AX=ptr STRBUF (minuscules)');
  EmitLabel(PSP_RT_PFX + 'LOWERCASE');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('MOV', 'DI', 'OFFSET ' + PSP_RT_PFX + 'STRBUF');
  EmitRaw(PSP_RT_PFX + 'LC_LP:');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'LC_END');
  EmitInstrAB('CMP', 'AL', '''A''');
  EmitInstrA('JB', PSP_RT_PFX + 'LC_STORE');
  EmitInstrAB('CMP', 'AL', '''Z''');
  EmitInstrA('JA', PSP_RT_PFX + 'LC_STORE');
  EmitInstrAB('ADD', 'AL', '32');
  EmitRaw(PSP_RT_PFX + 'LC_STORE:');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstrA('JMP', PSP_RT_PFX + 'LC_LP');
  EmitRaw(PSP_RT_PFX + 'LC_END:');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('LEA', 'AX', PSP_RT_PFX + 'STRBUF');
  EmitInstrA('POP', 'DI');
  EmitInstr('RET');
  EmitBlankLine;

  { _PSPRT_TRIM : supprimer espaces de debut et fin }
  { Entree : SI=chaine ASCIIZ. Sortie : AX=ptr STRBUF }
  EmitComment('TRIM : SI=str -> AX=ptr STRBUF (sans espaces)');
  EmitLabel(PSP_RT_PFX + 'TRIM');
  EmitInstrA('PUSH', 'DI');
  { Avancer SI tant que espace }
  EmitRaw(PSP_RT_PFX + 'TRIM_L:');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '32');
  EmitInstrA('JNE', PSP_RT_PFX + 'TRIM_COPY');
  EmitInstr('INC    SI');
  EmitInstrA('JMP', PSP_RT_PFX + 'TRIM_L');
  { Copier dans STRBUF }
  EmitRaw(PSP_RT_PFX + 'TRIM_COPY:');
  EmitInstrAB('MOV', 'DI', 'OFFSET ' + PSP_RT_PFX + 'STRBUF');
  EmitRaw(PSP_RT_PFX + 'TRIM_CP:');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'TRIM_R');
  EmitInstr('INC    SI');
  EmitInstr('INC    DI');
  EmitInstrA('JMP', PSP_RT_PFX + 'TRIM_CP');
  { Recul depuis la fin pour supprimer espaces }
  EmitRaw(PSP_RT_PFX + 'TRIM_R:');
  EmitInstr('DEC    DI');
  EmitInstrAB('CMP', 'DI', 'OFFSET ' + PSP_RT_PFX + 'STRBUF');
  EmitInstrA('JB', PSP_RT_PFX + 'TRIM_DONE');
  EmitInstrAB('CMP', 'BYTE PTR [DI]', '32');
  EmitInstrA('JNE', PSP_RT_PFX + 'TRIM_DONE');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrA('JMP', PSP_RT_PFX + 'TRIM_R');
  EmitRaw(PSP_RT_PFX + 'TRIM_DONE:');
  EmitInstr('INC    DI');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('LEA', 'AX', PSP_RT_PFX + 'STRBUF');
  EmitInstrA('POP', 'DI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _PSPRT_PANIC : affiche message + halt(1) --- }
  EmitComment('PANIC : SI=msg ASCIIZ -> affiche + halt(1)');
  EmitLabel(PSP_RT_PFX + 'PANIC');
  EmitInstrA('CALL', PSP_RT_PFX + 'PRINTSTR');
  EmitComment('CRLF apres message');
  EmitInstrAB('MOV', 'SI', 'OFFSET ' + PSP_RT_PFX + 'CRLF');
  EmitInstrA('CALL', PSP_RT_PFX + 'PRINTSTR');
  EmitInstrAB('MOV', 'AX', '4C01h');
  EmitInstr('INT    21h');
  EmitBlankLine;

  { --- _PSPRT_PANIC_DIV0 : division par zero --- }
  EmitComment('PANIC_DIV0 : Runtime error division by zero');
  EmitLabel(PSP_RT_PFX + 'PANIC_DIV0');
  EmitInstrAB('MOV', 'SI', 'OFFSET ' + PSP_RT_PFX + 'DIV0MSG');
  { Check si handler installe }
  EmitInstrAB('CMP', 'WORD PTR [' + PSP_EX_PFX + 'HANDLER]', '0');
  EmitInstrA('JE', PSP_RT_PFX + 'PANIC_DIV0_FATAL');
  { Handler present : sauter vers le handler }
  EmitInstrAB('MOV', 'SP', 'WORD PTR [' + PSP_EX_PFX + 'SAVESP]');
  EmitInstrAB('MOV', 'BP', 'WORD PTR [' + PSP_EX_PFX + 'SAVEBP]');
  EmitInstrA('JMP', 'WORD PTR [' + PSP_EX_PFX + 'HANDLER]');
  EmitRaw(PSP_RT_PFX + 'PANIC_DIV0_FATAL:');
  EmitInstrA('CALL', PSP_RT_PFX + 'PANIC');
  EmitBlankLine;

  EmitRaw('_TEXT   ENDS');
  EmitBlankLine;
End;

{ ---- EmitProlog : prologue de procedure/fonction ------------- }
{ PUSH BP / MOV BP,SP / SUB SP,framesize / PUSH SI / PUSH DI     }
Procedure EmitProlog(FrameSize : Integer);
Begin
  EmitPush('BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  If FrameSize > 0 Then
  Begin
    EmitInstrAB('SUB', 'SP', IntToStr(FrameSize));
    If (FrameSize > FRAME_WARN) And Opts.Warnings Then
      WarnMsg('cadre de pile volumineux : ' + IntToStr(FrameSize) +
              ' octets');
  End;
  { Sauvegarder SI/DI }
  EmitPush('SI');
  EmitPush('DI');
End;

{ ---- EmitEpilog : epilogue de procedure/fonction ------------- }
{ POP DI / POP SI / MOV SP,BP / POP BP / RET [n]                  }
Procedure EmitEpilog(ParamBytes : Integer);
Begin
  { Restaurer DI/SI }
  EmitPop('DI');
  EmitPop('SI');
  EmitInstrAB('MOV', 'SP', 'BP');
  EmitPop('BP');
  If ParamBytes > 0 Then
    EmitInstrA('RET', IntToStr(ParamBytes))
  Else
    EmitInstr('RET');
End;

{ ---- EmitPush : PUSH registre -------------------------------- }
Procedure EmitPush(Const Reg : TString);
Begin
  EmitInstrA('PUSH', Reg);
End;

{ ---- EmitPop : POP registre ---------------------------------- }
Procedure EmitPop(Const Reg : TString);
Begin
  EmitInstrA('POP', Reg);
End;

{ ---- EmitMov : MOV dst, src ---------------------------------- }
Procedure EmitMov(Const Dst, Src : TString);
Begin
  EmitInstrAB('MOV', Dst, Src);
End;

{ ---- EmitCall : CALL target ---------------------------------- }
Procedure EmitCall(Const Target : TString);
Begin
  EmitInstrA('CALL', Target);
End;

{ ---- EmitJmp : JMP target ------------------------------------ }
Procedure EmitJmp(Const Target : TString);
Begin
  EmitInstrA('JMP', Target);
End;

{ ---- EmitJmpCond : saut conditionnel (JE, JNE, JL, etc.) ----- }
Procedure EmitJmpCond(Const Cond, Target : TString);
Begin
  EmitInstrA(Cond, Target);
End;

{ ---- EmitCoerce : conversion de type inline ------------------- }
{ Wrapper autour de TypeCoerce pour uniformite.                    }
Procedure EmitCoerce(SrcType, DstType : Integer);
Begin
  If TypeCoerce(SrcType, DstType) <> SrcType Then
    { conversion emise par TypeCoerce };
End;

{ ---- OpPrec : precedence des operateurs binaires Pascal ------ }
{ Retourne 0 si ce n est pas un operateur binaire connu.         }
{ Niveaux Pascal :                                               }
{   4 = multiplicatifs : * / div mod and shl shr                 }
{   3 = additifs       : + - or xor                              }
{   2 = comparaison    : = <> < > <= >= in                       }
{   1 = pas d operateur (seuil pour ParseExpr)                   }
Function OpPrec(Const Op : TString) : Integer;
Begin
  If (Op = '*') Or (Op = '/') Or (Op = 'div') Or (Op = 'mod') Or
     (Op = 'and') Or (Op = 'shl') Or (Op = 'shr') Then
    OpPrec := 4
  Else If (Op = '+') Or (Op = '-') Or (Op = 'or') Or (Op = 'xor') Then
    OpPrec := 3
  Else If (Op = '=') Or (Op = '<>') Or (Op = '<') Or (Op = '>') Or
          (Op = '<=') Or (Op = '>=') Or (Op = 'in') Then
    OpPrec := 2
  Else
    OpPrec := 0;
End;

{ ---- ExprMakeImm : creer une valeur immediate --------------- }
Procedure ExprMakeImm(V : LongInt; TIdx : Integer; Var R : TExprVal);
Begin
  R.Kind    := EK_IMM;
  R.ImmVal  := V;
  R.TypeIdx := TIdx;
  R.Offset  := 0;
  R.SymIdx  := -1;
End;

{ ---- ExprFlushToAX : materialiser une expression dans AX ---- }
{ Si deja AX, ne rien faire. Si immediate, MOV AX, imm.         }
{ Si memoire, charger depuis variable locale ou globale.         }
Procedure ExprFlushToAX(Var E : TExprVal);
Var
  SIdx : Integer;
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      If E.ImmVal = 0 Then
        EmitInstrAB('XOR', 'AX', 'AX')
      Else
        EmitInstrAB('MOV', 'AX', IntToStr(E.ImmVal));
      E.Kind := EK_AX;
    End;
    EK_AX :
      ; { deja dans AX }
    EK_MEM :
    Begin
      SIdx := E.SymIdx;
      If (SIdx >= 0) And (SIdx < SymCount) Then
      Begin
        If SymTab[SIdx].IsLocal Then
        Begin
          { Variable locale : MOV AX, [BP-n] }
          If SymTab[SIdx].Cat = SC_VARPARAM Then
          Begin
            { Parametre var (reference) : MOV BX,[BP+n] / MOV AX,[BX] }
            EmitInstrAB('MOV', 'BX',
              'WORD PTR ' + BPOfs(SymTab[SIdx].Offset));
            EmitInstrAB('MOV', 'AX', 'WORD PTR [BX]');
          End
          Else
          Begin
            If TypeSizeof(E.TypeIdx) = 1 Then
            Begin
              EmitInstrAB('XOR', 'AH', 'AH');
              EmitInstrAB('MOV', 'AL',
                'BYTE PTR ' + BPOfs(SymTab[SIdx].Offset));
            End
            Else
              EmitInstrAB('MOV', 'AX',
                'WORD PTR ' + BPOfs(SymTab[SIdx].Offset));
          End;
        End
        Else
        Begin
          { Variable globale : MOV AX, [_PSP_xxx] }
          If TypeSizeof(E.TypeIdx) = 1 Then
          Begin
            EmitInstrAB('XOR', 'AH', 'AH');
            EmitInstrAB('MOV', 'AL',
              'BYTE PTR [' + SymTab[SIdx].MangledName + ']');
          End
          Else
            EmitInstrAB('MOV', 'AX',
              'WORD PTR [' + SymTab[SIdx].MangledName + ']');
        End;
      End
      Else
      Begin
        { Symbole inconnu : XOR AX,AX par defaut }
        EmitInstrAB('XOR', 'AX', 'AX');
      End;
      E.Kind := EK_AX;
    End;
    EK_NONE :
    Begin
      EmitInstrAB('XOR', 'AX', 'AX');
      E.Kind := EK_AX;
    End;
  End;
End;

{ ---- ParseCallArgs : evaluer et PUSH des arguments ----------- }
{ FuncIdx est l indice du symbole de la fonction dans SymTab.    }
{ Evalue chaque argument, flush dans AX et PUSH AX.             }
{ Pour un parametre var, empile l adresse (LEA) au lieu de la   }
{ valeur .                                                      }
{ CurToken doit etre sur ( au debut. Consomme jusqu a ).        }
Procedure ParseCallArgs(FuncIdx : Integer);
Var
  ArgExpr  : TExprVal;
  ArgCnt   : Integer;
  IsVarArg : Boolean;
  ArgSym   : Integer;
Begin
  ArgCnt := 0;
  { Consommer ( }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    TplNextToken
  Else
    Exit;

  { Boucle sur les arguments }
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
  Begin
    { Verifier si cet argument est un parametre var }
    IsVarArg := False;
    If (FuncIdx >= 0) And
       (SymTab[FuncIdx].Cat In [SC_FUNC, SC_PROC]) And
       (ArgCnt < SymTab[FuncIdx].ParamCnt) Then
    Begin
      If (SymTab[FuncIdx].VarParamMask And
          (LongInt(1) Shl ArgCnt)) <> 0 Then
        IsVarArg := True;
    End;

    If IsVarArg Then
    Begin
      { Parametre var : empiler l adresse de la variable }
      If CurToken.Kind = TK_IDENT Then
      Begin
        ArgSym := SymFind(CurToken.Val);
        If ArgSym >= 0 Then
        Begin
          TplNextToken;
          Case SymTab[ArgSym].Cat Of
            SC_VARPARAM :
            Begin
              { Deja une reference : passer le pointeur tel quel }
              EmitInstrAB('MOV', 'AX',
                'WORD PTR ' + BPOfs(SymTab[ArgSym].Offset));
              EmitInstrA('PUSH', 'AX');
            End;
            SC_VAR, SC_PARAM, SC_TYPED_CONST :
            Begin
              If SymTab[ArgSym].IsLocal Then
              Begin
                { Variable locale : LEA AX, [BP+ofs] }
                EmitInstrAB('LEA', 'AX',
                  BPOfs(SymTab[ArgSym].Offset));
                EmitInstrA('PUSH', 'AX');
              End
              Else
              Begin
                { Variable globale : OFFSET }
                EmitInstrAB('MOV', 'AX',
                  'OFFSET ' + SymTab[ArgSym].MangledName);
                EmitInstrA('PUSH', 'AX');
              End;
            End;
          Else
            Begin
              WarnMsg('variable attendue pour parametre var');
              ParseExpr(ArgExpr);
              ExprFlushToAX(ArgExpr);
              EmitInstrA('PUSH', 'AX');
            End;
          End;
        End
        Else
        Begin
          WarnMsg('symbole non declare: ' + CurToken.Val);
          TplNextToken;
          EmitInstrAB('XOR', 'AX', 'AX');
          EmitInstrA('PUSH', 'AX');
        End;
      End
      Else
      Begin
        WarnMsg('variable attendue pour parametre var');
        ParseExpr(ArgExpr);
        ExprFlushToAX(ArgExpr);
        EmitInstrA('PUSH', 'AX');
      End;
    End
    Else
    Begin
      { Parametre normal : empiler la valeur }
      ParseExpr(ArgExpr);
      ExprFlushToAX(ArgExpr);
      EmitInstrA('PUSH', 'AX');
    End;

    Inc(ArgCnt);
    { Virgule entre arguments }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      TplNextToken;
  End;

  { Consommer ) }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    TplNextToken;

  If Opts.DebugMode Then
    WriteLn('  CALL_ARGS: ', ArgCnt, ' argument(s)');
End;

{ ---- ParsePrimary : token primaire -> TExprVal --------------- }
{ Gere : litteraux (entier, reel, chaine, char, true/false/nil), }
{        identificateurs (variable, constante, appel fonction),  }
{        sous-expression parenthesee (expr),                     }
{        transtypage : Integer(expr), Char(expr), etc.           }
Procedure ParsePrimary(Var Res : TExprVal);
Var
  CastTypeIdx : Integer;
  LblUC       : String;
  BaseTIdx    : Integer;   { pour Low/High/SizeOf }
  Idx         : Integer;   { pour Low/High/SizeOf }
  { Tableaux }
  ArrTIdx     : Integer;
  IdxExpr     : TExprVal;
  ArrLo       : LongInt;
  ElemSz      : Integer;
  { Records }
  RecTIdx     : Integer;
  FldIdx      : Integer;
  FI          : Integer;
  FldTIdx     : Integer;
  FldSz       : Integer;
  WIdx        : Integer;
  WI          : Integer;
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;

  Case CurToken.Kind Of
    { Litteraux numeriques }
    TK_INTEGER, TK_REAL, TK_CHAR :
    Begin
      LitEval(CurToken, Res);
      TplNextToken;
    End;

    { Chaine litterale }
    TK_STRING :
    Begin
      LitEval(CurToken, Res);
      { Emettre LEA AX, label de la chaine }
      If (Res.SymIdx >= 0) And (Res.SymIdx < DataCount) Then
        EmitInstrAB('LEA', 'AX', DataTab[Res.SymIdx].LblName)
      Else If DataCount > 0 Then
        EmitInstrAB('LEA', 'AX', DataTab[DataCount - 1].LblName);
      Res.Kind := EK_AX;
      TplNextToken;
    End;

    { Mots-cles speciaux : true, false, nil, transtypage }
    TK_KEYWORD :
    Begin
      If (CurToken.Val = 'true') Or (CurToken.Val = 'false') Or
         (CurToken.Val = 'nil') Then
      Begin
        LitEval(CurToken, Res);
        TplNextToken;
      End
      { Transtypage : Integer(expr), Char(expr), Byte(expr), Word(expr) }
      Else If (CurToken.Val = 'integer') Or (CurToken.Val = 'word') Or
              (CurToken.Val = 'byte') Or (CurToken.Val = 'char') Then
      Begin
        { Sauvegarder le type cible }
        CastTypeIdx := TypeResolve(CurToken.Val);
        TplNextToken;  { consommer le nom de type }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          TplNextToken;  { consommer ( }
          ParseExpr(Res);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            TplNextToken;  { consommer ) }
          { Forcer le type resultat au type cible du cast }
          Res.TypeIdx := CastTypeIdx;
          { Appliquer la coercition si la valeur est en AX }
          If Res.Kind <> EK_IMM Then
          Begin
            ExprFlushToAX(Res);
            { Pour Byte/Char on masque }
            If (CastTypeIdx = TY_IDX_BYTE) Or
               (CastTypeIdx = TY_IDX_CHAR) Then
              EmitInstrAB('AND', 'AX', '00FFh');
            Res.Kind := EK_AX;
          End
          Else
          Begin
            { Pliage : masquer la valeur pour Byte/Char }
            If (CastTypeIdx = TY_IDX_BYTE) Or
               (CastTypeIdx = TY_IDX_CHAR) Then
              Res.ImmVal := Res.ImmVal And $FF;
          End;
          If Opts.DebugMode Then
            WriteLn('  TYPECAST -> type ', CastTypeIdx);
        End
        Else
          WarnMsg('''('' attendu apres le type dans le transtypage');
      End
      Else
      Begin
        { Mot-cle non gere comme expression : erreur douce }
        WarnMsg('mot-cle inattendu dans expression: ' + CurToken.Val);
        TplNextToken;
      End;
    End;

    { Identificateur (variable, constante nommee, appel fonction) }
    TK_IDENT :
    Begin
      { --- Fonctions builtin string --- }
      If StrLowerCase(CurToken.Val) = 'length' Then
      Begin
        TplNextToken;  { consommer length }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;  { consommer ( }
        { Si argument est un tableau, retourner hi-lo+1 }
        Idx := -1;
        If (CurToken.Kind = TK_IDENT) Then
          Idx := SymFind(CurToken.Val);
        If (Idx >= 0) And
           (SymTab[Idx].TypeIdx >= 0) And
           (SymTab[Idx].TypeIdx < TypeCount) And
           (TypeTab[SymTab[Idx].TypeIdx].Kind = TKP_ARRAY) Then
        Begin
          ArrTIdx := SymTab[Idx].TypeIdx;
          EmitInstrAB('MOV', 'AX',
            IntToStr(TypeTab[ArrTIdx].Hi - TypeTab[ArrTIdx].Lo + 1));
          TplNextToken;  { consommer ident }
        End
        Else
        Begin
          ParseExpr(Res);
          ExprFlushToAX(Res);
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrA('CALL', PSP_RT_PFX + 'STRLEN');
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;  { consommer ) }
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'chr' Then
      Begin
        TplNextToken;  { consommer chr }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstrA('CALL', PSP_RT_PFX + 'CHR');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'ord' Then
      Begin
        TplNextToken;  { consommer ord }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        { Si l argument est une chaine, dereferencer le 1er octet }
        If Res.TypeIdx = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstr('LODSB');
          EmitInstrAB('XOR', 'AH', 'AH');
        End
        Else
          EmitInstrAB('AND', 'AX', '00FFh');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'inttostr' Then
      Begin
        TplNextToken;  { consommer inttostr }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstrA('CALL', PSP_RT_PFX + 'NUMTOSTR');
        EmitInstrAB('LEA', 'AX', PSP_RT_PFX + 'NUMBUF');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'strtoint' Then
      Begin
        TplNextToken;  { consommer strtoint }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('CALL', PSP_RT_PFX + 'STRTONUM');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'upcase' Then
      Begin
        TplNextToken;  { consommer upcase }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        { UpCase : AND AL, 0DFh si 'a'..'z' }
        LblUC := LabelGen;
        EmitInstrAB('CMP', 'AL', '''a''');
        EmitInstrA('JB', LblUC);
        EmitInstrAB('CMP', 'AL', '''z''');
        EmitInstrA('JA', LblUC);
        EmitInstrAB('AND', 'AL', '0DFh');
        EmitLabel(LblUC);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'copy' Then
      Begin
        TplNextToken;  { consommer copy }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        { Arg 1 : chaine source -> SI }
        ParseExpr(Res); ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          TplNextToken;
        { Arg 2 : position -> BX }
        ParseExpr(Res); ExprFlushToAX(Res);
        EmitInstrA('PUSH', 'AX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          TplNextToken;
        { Arg 3 : longueur -> CX }
        ParseExpr(Res); ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'CX', 'AX');
        EmitInstrA('POP', 'BX');
        EmitInstrA('CALL', PSP_RT_PFX + 'COPY');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'pos' Then
      Begin
        TplNextToken;  { consommer pos }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        { Arg 1 : sous-chaine -> SI }
        ParseExpr(Res); ExprFlushToAX(Res);
        EmitInstrA('PUSH', 'AX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          TplNextToken;
        { Arg 2 : chaine -> DI }
        ParseExpr(Res); ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'DI', 'AX');
        EmitInstrA('POP', 'SI');
        EmitInstrA('CALL', PSP_RT_PFX + 'POS');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If (StrLowerCase(CurToken.Val) = 'concat') Then
      Begin
        TplNextToken;  { consommer concat }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        { Premier argument }
        ParseExpr(Res); ExprFlushToAX(Res);
        { Arguments suivants : concatener un par un }
        While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
        Begin
          TplNextToken;
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrA('PUSH', 'SI');
          ParseExpr(Res); ExprFlushToAX(Res);
          EmitInstrAB('MOV', 'DI', 'AX');
          EmitInstrA('POP', 'SI');
          EmitInstrA('CALL', PSP_RT_PFX + 'CONCAT');
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := -1;
      End
      { --- Succ(x) : INC AX --- }
      Else If StrLowerCase(CurToken.Val) = 'succ' Then
      Begin
        TplNextToken;  { consommer succ }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstr('INC    AX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        If Res.TypeIdx = TY_UNKNOWN Then
          Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      { --- Pred(x) : DEC AX --- }
      Else If StrLowerCase(CurToken.Val) = 'pred' Then
      Begin
        TplNextToken;  { consommer pred }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstr('DEC    AX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        If Res.TypeIdx = TY_UNKNOWN Then
          Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      { --- Low(T) : borne inf du type --- }
      Else If StrLowerCase(CurToken.Val) = 'low' Then
      Begin
        TplNextToken;  { consommer low }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
        Begin
          BaseTIdx := TypeResolve(CurToken.Val);
          If BaseTIdx = TY_UNKNOWN Then
          Begin
            { Essayer comme variable pour obtenir son type }
            Idx := SymFind(CurToken.Val);
            If Idx >= 0 Then
              BaseTIdx := SymTab[Idx].TypeIdx
            Else
              BaseTIdx := TY_IDX_INTEGER;
          End;
          TplNextToken;
          If (BaseTIdx >= 0) And (BaseTIdx < TypeCount) Then
            Res.ImmVal := TypeTab[BaseTIdx].Lo
          Else
            Res.ImmVal := 0;
          EmitInstrAB('MOV', 'AX', IntToStr(Res.ImmVal));
        End
        Else
        Begin
          WarnMsg('type ou variable attendu pour Low');
          EmitInstrAB('XOR', 'AX', 'AX');
          Res.ImmVal := 0;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      { --- High(T) : borne sup du type --- }
      Else If StrLowerCase(CurToken.Val) = 'high' Then
      Begin
        TplNextToken;  { consommer high }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
        Begin
          BaseTIdx := TypeResolve(CurToken.Val);
          If BaseTIdx = TY_UNKNOWN Then
          Begin
            Idx := SymFind(CurToken.Val);
            If Idx >= 0 Then
              BaseTIdx := SymTab[Idx].TypeIdx
            Else
              BaseTIdx := TY_IDX_INTEGER;
          End;
          TplNextToken;
          If (BaseTIdx >= 0) And (BaseTIdx < TypeCount) Then
            Res.ImmVal := TypeTab[BaseTIdx].Hi
          Else
            Res.ImmVal := 0;
          EmitInstrAB('MOV', 'AX', IntToStr(Res.ImmVal));
        End
        Else
        Begin
          WarnMsg('type ou variable attendu pour High');
          EmitInstrAB('XOR', 'AX', 'AX');
          Res.ImmVal := 0;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      { --- SizeOf(T) : taille en octets --- }
      Else If StrLowerCase(CurToken.Val) = 'sizeof' Then
      Begin
        TplNextToken;  { consommer sizeof }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
        Begin
          BaseTIdx := TypeResolve(CurToken.Val);
          If BaseTIdx = TY_UNKNOWN Then
          Begin
            Idx := SymFind(CurToken.Val);
            If Idx >= 0 Then
              BaseTIdx := SymTab[Idx].TypeIdx
            Else
              BaseTIdx := TY_IDX_INTEGER;
          End;
          TplNextToken;
          Res.ImmVal := TypeSizeof(BaseTIdx);
          EmitInstrAB('MOV', 'AX', IntToStr(Res.ImmVal));
        End
        Else
        Begin
          WarnMsg('type ou variable attendu pour SizeOf');
          EmitInstrAB('XOR', 'AX', 'AX');
          Res.ImmVal := 0;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      { --- Abs(n) --- }
      Else If StrLowerCase(CurToken.Val) = 'abs' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstr('CWD');
        EmitInstrAB('XOR', 'AX', 'DX');
        EmitInstrAB('SUB', 'AX', 'DX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      { --- Sqr(n) --- }
      Else If StrLowerCase(CurToken.Val) = 'sqr' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstrAB('IMUL', 'AX', 'AX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      { --- Odd(n) --- }
      Else If StrLowerCase(CurToken.Val) = 'odd' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstrAB('AND', 'AX', '1');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      { --- Lo(w) --- }
      Else If StrLowerCase(CurToken.Val) = 'lo' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstrAB('AND', 'AX', '00FFh');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      { --- Hi(w) --- }
      Else If StrLowerCase(CurToken.Val) = 'hi' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'AL', 'AH');
        EmitInstrAB('XOR', 'AH', 'AH');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      { --- Swap(w) --- }
      Else If StrLowerCase(CurToken.Val) = 'swap' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstrAB('XCHG', 'AL', 'AH');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      { --- Sqrt(n) --- }
      Else If StrLowerCase(CurToken.Val) = 'sqrt' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstrA('CALL', PSP_RT_PFX + 'SQRT');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      { --- Random / Random(n) --- }
      Else If StrLowerCase(CurToken.Val) = 'random' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          TplNextToken;
          ParseExpr(Res);
          ExprFlushToAX(Res);
          EmitInstrA('PUSH', 'AX');       (* sauver n *)
          EmitInstrA('CALL', PSP_RT_PFX + 'RANDOM');
          EmitInstrA('POP', 'CX');        (* CX = n *)
          EmitInstrAB('XOR', 'DX', 'DX');
          EmitInstrA('DIV', 'CX');        (* DX = AX mod n *)
          EmitInstrAB('MOV', 'AX', 'DX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            TplNextToken;
        End
        Else
        Begin
          EmitInstrA('CALL', PSP_RT_PFX + 'RANDOM');
        End;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      { --- IntToStr(n) --- }
      Else If StrLowerCase(CurToken.Val) = 'inttostr' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstrA('CALL', PSP_RT_PFX + 'NUMTOSTR');
        EmitInstrAB('LEA', 'AX', PSP_RT_PFX + 'NUMBUF');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := -1;
      End

      { --- StrToInt(s) --- }
      Else If StrLowerCase(CurToken.Val) = 'strtoint' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('CALL', PSP_RT_PFX + 'STRTONUM');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      { --- LowerCase(s) --- }
      Else If StrLowerCase(CurToken.Val) = 'lowercase' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('CALL', PSP_RT_PFX + 'LOWERCASE');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := -1;
      End

      { --- Trim(s) --- }
      Else If StrLowerCase(CurToken.Val) = 'trim' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('CALL', PSP_RT_PFX + 'TRIM');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := -1;
      End

      { --- EOF (stub retourne True=1) --- }
      Else If StrLowerCase(CurToken.Val) = 'eof' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          TplNextToken; (* skip argument si present *)
          While (CurToken.Kind <> TK_PUNCT) Or (CurToken.Val <> ')') Do
          Begin
            If CurToken.Kind = TK_EOF Then Break;
            TplNextToken;
          End;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            TplNextToken;
        End;
        EmitInstrAB('MOV', 'AX', '1');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_BOOLEAN;
        Res.SymIdx  := -1;
      End

      { --- EOLN (stub retourne True=1) --- }
      Else If StrLowerCase(CurToken.Val) = 'eoln' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          TplNextToken;
          While (CurToken.Kind <> TK_PUNCT) Or (CurToken.Val <> ')') Do
          Begin
            If CurToken.Kind = TK_EOF Then Break;
            TplNextToken;
          End;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            TplNextToken;
        End;
        EmitInstrAB('MOV', 'AX', '1');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_BOOLEAN;
        Res.SymIdx  := -1;
      End

      { --- ParamCount (stub retourne 0) --- }
      Else If StrLowerCase(CurToken.Val) = 'paramcount' Then
      Begin
        TplNextToken;
        WarnMsg('ParamCount : stub, retourne 0');
        EmitInstrAB('XOR', 'AX', 'AX');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End

      { --- ParamStr(n) (stub retourne chaine vide) --- }
      Else If StrLowerCase(CurToken.Val) = 'paramstr' Then
      Begin
        TplNextToken;
        WarnMsg('ParamStr : stub, retourne chaine vide');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          TplNextToken;
          ParseExpr(Res);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            TplNextToken;
        End;
        EmitInstrAB('LEA', 'AX', PSP_RT_PFX + 'CRLF + 2');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := -1;
      End

      { --- GetEnv(s) (stub retourne chaine vide) --- }
      Else If StrLowerCase(CurToken.Val) = 'getenv' Then
      Begin
        TplNextToken;
        WarnMsg('GetEnv : stub, retourne chaine vide');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          TplNextToken;
          ParseExpr(Res);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            TplNextToken;
        End;
        EmitInstrAB('LEA', 'AX', PSP_RT_PFX + 'CRLF + 2');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := -1;
      End

      Else
      Begin
      { --- Fin fonctions builtin, debut gestion ident standard --- }
      { --- Resolution with-stack pour lecture champ --- }
      WIdx := -1;
      If WithTop >= 0 Then
      Begin
        For WI := WithTop DownTo 0 Do
        Begin
          RecTIdx := SymTab[WithSymIdx[WI]].TypeIdx;
          For FI := 0 To TypeTab[RecTIdx].FieldCount - 1 Do
            If StrLowerCase(TypeTab[RecTIdx].Fields[FI].Name) =
               StrLowerCase(CurToken.Val) Then
            Begin
              WIdx := WI;
              FldIdx := FI;
              Break;
            End;
          If WIdx >= 0 Then Break;
        End;
      End;
      If WIdx >= 0 Then
      Begin
        { Champ trouve dans le with-stack }
        RecTIdx := SymTab[WithSymIdx[WIdx]].TypeIdx;
        If SymTab[WithSymIdx[WIdx]].IsLocal Then
          EmitInstrAB('LEA', 'BX',
            BPOfs(SymTab[WithSymIdx[WIdx]].Offset))
        Else
          EmitInstrAB('MOV', 'BX',
            'OFFSET ' + SymTab[WithSymIdx[WIdx]].MangledName);
        If TypeTab[RecTIdx].Fields[FldIdx].Offset > 0 Then
          EmitInstrAB('ADD', 'BX',
            IntToStr(TypeTab[RecTIdx].Fields[FldIdx].Offset));
        FldTIdx := TypeTab[RecTIdx].Fields[FldIdx].TypeIdx;
        FldSz   := TypeSizeof(FldTIdx);
        If FldSz = 1 Then
        Begin
          EmitInstrAB('XOR', 'AH', 'AH');
          EmitInstrAB('MOV', 'AL', 'BYTE PTR [BX]');
        End
        Else
          EmitInstrAB('MOV', 'AX', 'WORD PTR [BX]');
        Res.Kind    := EK_AX;
        Res.TypeIdx := FldTIdx;
        Res.SymIdx  := -1;
        TplNextToken;
      End
      Else
      Begin
      { --- Resolution standard ident --- }
      Res.SymIdx := SymFind(CurToken.Val);
      If Res.SymIdx >= 0 Then
      Begin
        { Symbole trouve }
        If Opts.DebugMode Then
          WriteLn('  EXPR_IDENT: ', CurToken.Val,
                  ' -> sym[', Res.SymIdx, '] cat=',
                  Ord(SymTab[Res.SymIdx].Cat));
        Case SymTab[Res.SymIdx].Cat Of
          SC_CONST :
          Begin
            { Constante non-typee : substitution immediate }
            Res.Kind    := EK_IMM;
            Res.ImmVal  := SymTab[Res.SymIdx].ImmVal;
            Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
          End;
          SC_TYPED_CONST :
          Begin
            { Constante typee : valeur connue a la compilation,     }
            { on l expose comme immediate pour le pliage.           }
            { En generation de code, elle est aussi en DATA.        }
            Res.Kind    := EK_IMM;
            Res.ImmVal  := SymTab[Res.SymIdx].ImmVal;
            Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
          End;
          SC_VAR, SC_PARAM, SC_VARPARAM :
          Begin
            { Variable : reference memoire }
            Res.Kind    := EK_MEM;
            Res.ImmVal  := 0;
            Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
            Res.Offset  := SymTab[Res.SymIdx].Offset;
          End;
          SC_FUNC :
          Begin
            { Fonction : sera un appel }
            Res.Kind    := EK_AX;
            Res.ImmVal  := 0;
            Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
          End;
          SC_ENUM_VAL :
          Begin
            { Valeur d enumeration : immediate }
            Res.Kind    := EK_IMM;
            Res.ImmVal  := SymTab[Res.SymIdx].ImmVal;
            Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
          End;
        Else
          { Autre categorie (type, proc, field, label) }
          Res.Kind    := EK_MEM;
          Res.ImmVal  := 0;
          Res.TypeIdx := TY_IDX_INTEGER;
        End;
      End
      Else
      Begin
        { Symbole non trouve : avertissement, traiter comme 0 }
        WarnMsg('symbole non declare: ' + CurToken.Val);
        Res.Kind    := EK_MEM;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End;
      TplNextToken;
      { --- Detecter acces champ record : ident.field --- }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
      Begin
        If (Res.SymIdx >= 0) And (Res.SymIdx < SymCount) And
           (SymTab[Res.SymIdx].TypeIdx >= 0) And
           (SymTab[Res.SymIdx].TypeIdx < TypeCount) And
           (TypeTab[SymTab[Res.SymIdx].TypeIdx].Kind = TKP_RECORD) Then
        Begin
          RecTIdx := SymTab[Res.SymIdx].TypeIdx;
          { Charger adresse de base du record dans BX }
          If SymTab[Res.SymIdx].IsLocal Then
            EmitInstrAB('LEA', 'BX',
              BPOfs(SymTab[Res.SymIdx].Offset))
          Else
            EmitInstrAB('MOV', 'BX',
              'OFFSET ' + SymTab[Res.SymIdx].MangledName);
          FldTIdx := TY_IDX_INTEGER;
          While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Do
          Begin
            TplNextToken;  { consommer . }
            If CurToken.Kind = TK_IDENT Then
            Begin
              FldIdx := -1;
              For FI := 0 To TypeTab[RecTIdx].FieldCount - 1 Do
                If StrLowerCase(TypeTab[RecTIdx].Fields[FI].Name) =
                   StrLowerCase(CurToken.Val) Then
                Begin
                  FldIdx := FI;
                  Break;
                End;
              If FldIdx >= 0 Then
              Begin
                If TypeTab[RecTIdx].Fields[FldIdx].Offset > 0 Then
                  EmitInstrAB('ADD', 'BX',
                    IntToStr(TypeTab[RecTIdx].Fields[FldIdx].Offset));
                FldTIdx := TypeTab[RecTIdx].Fields[FldIdx].TypeIdx;
                TplNextToken;  { consommer nom du champ }
                { Si le champ est un record imbrique, continuer }
                If (FldTIdx >= 0) And (FldTIdx < TypeCount) And
                   (TypeTab[FldTIdx].Kind = TKP_RECORD) Then
                  RecTIdx := FldTIdx;
              End
              Else
              Begin
                WarnMsg('champ inconnu: ' + CurToken.Val);
                TplNextToken;
                Break;
              End;
            End
            Else
            Begin
              WarnMsg('nom de champ attendu apres "."');
              Break;
            End;
          End;
          { Charger la valeur finale du champ }
          FldSz := TypeSizeof(FldTIdx);
          If FldSz = 1 Then
          Begin
            EmitInstrAB('XOR', 'AH', 'AH');
            EmitInstrAB('MOV', 'AL', 'BYTE PTR [BX]');
          End
          Else
            EmitInstrAB('MOV', 'AX', 'WORD PTR [BX]');
          Res.Kind    := EK_AX;
          Res.TypeIdx := FldTIdx;
          Res.SymIdx  := -1;
        End
        Else
        Begin
          WarnMsg('acces "." sur un non-record');
          TplNextToken;  { sauter . }
          If CurToken.Kind = TK_IDENT Then
            TplNextToken;  { sauter nom du champ }
        End;
      End
      Else
      { --- Detecter indexation tableau : ident[ --- }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
      Begin
        If (Res.SymIdx >= 0) And (Res.SymIdx < SymCount) And
           (SymTab[Res.SymIdx].TypeIdx >= 0) And
           (SymTab[Res.SymIdx].TypeIdx < TypeCount) And
           (TypeTab[SymTab[Res.SymIdx].TypeIdx].Kind = TKP_ARRAY) Then
        Begin
          ArrTIdx := SymTab[Res.SymIdx].TypeIdx;
          ArrLo   := TypeTab[ArrTIdx].Lo;
          ElemSz  := TypeSizeof(TypeTab[ArrTIdx].BaseTypeIdx);

          TplNextToken;  { consommer [ }

          { Evaluer l index dans AX }
          ParseExpr(IdxExpr);
          ExprFlushToAX(IdxExpr);

          { Calculer offset = (index - lo) * elemsize }
          If ArrLo <> 0 Then
            EmitInstrAB('SUB', 'AX', IntToStr(ArrLo));
          If ElemSz = 2 Then
            EmitInstrAB('SHL', 'AX', '1')
          Else If (ElemSz <> 1) And (ElemSz > 2) Then
          Begin
            EmitInstrAB('MOV', 'CX', IntToStr(ElemSz));
            EmitInstr('MUL    CX');
          End;

          { Adresse de base dans BX }
          If SymTab[Res.SymIdx].IsLocal Then
            EmitInstrAB('LEA', 'BX',
              BPOfs(SymTab[Res.SymIdx].Offset))
          Else
            EmitInstrAB('MOV', 'BX',
              'OFFSET ' + SymTab[Res.SymIdx].MangledName);

          { Ajouter offset }
          EmitInstrAB('ADD', 'BX', 'AX');

          { Charger element }
          If ElemSz = 1 Then
          Begin
            EmitInstrAB('XOR', 'AH', 'AH');
            EmitInstrAB('MOV', 'AL', 'BYTE PTR [BX]');
          End
          Else
            EmitInstrAB('MOV', 'AX', 'WORD PTR [BX]');

          { Consommer ] }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
            TplNextToken;

          Res.Kind    := EK_AX;
          Res.TypeIdx := TypeTab[ArrTIdx].BaseTypeIdx;
          Res.SymIdx  := -1;
        End
        Else
        Begin
          WarnMsg('indexation sur un non-tableau');
          TplNextToken;  { consommer [ }
          While (CurToken.Kind <> TK_EOF) And
                Not ((CurToken.Kind = TK_PUNCT) And
                     (CurToken.Val = ']')) Do
            TplNextToken;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
            TplNextToken;
        End;
      End
      { Detecter un appel de fonction : ident( }
      Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        If (Res.SymIdx >= 0) And
           (SymTab[Res.SymIdx].Cat In [SC_FUNC, SC_PROC]) Then
        Begin
          { Appel de fonction / procedure }
          EmitComment('call ' + SymTab[Res.SymIdx].Name);
          ParseCallArgs(Res.SymIdx);
          EmitInstrA('CALL', SymTab[Res.SymIdx].MangledName);
          Res.Kind    := EK_AX;
          Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
          Res.SymIdx  := -1;
        End
        Else
        Begin
          { Pas une fonction connue : sauter les arguments }
          TplNextToken;
          While (CurToken.Kind <> TK_EOF) And
                Not ((CurToken.Kind = TK_PUNCT) And
                     (CurToken.Val = ')')) Do
            TplNextToken;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            TplNextToken;
          Res.Kind := EK_AX;
        End;
      End;
      End; { fin Else Begin Resolution standard ident }
      End; { fin du else (ident standard / with-stack) }
    End;

    { Sous-expression parenthesee }
    TK_PUNCT :
    Begin
      If CurToken.Val = '(' Then
      Begin
        TplNextToken;  { consommer ( }
        ParseExpr(Res);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken  { consommer ) }
        Else
          WarnMsg(''')'' attendu apres expression parenthesee');
      End
      Else
      Begin
        WarnMsg('token inattendu dans expression: ' + CurToken.Val);
        TplNextToken;
      End;
    End;

  Else
    WarnMsg('expression attendue, token: ' + CurToken.Val);
    TplNextToken;
  End;
End;

{ ---- ParseUnary : operateurs unaires prefixes --------------- }
{ Niveau 1 : not, -, @, ^                                       }
Procedure ParseUnary(Var Res : TExprVal);
Begin
  { not (logique ou bits selon type) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'not') Then
  Begin
    TplNextToken;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
    Begin
      { Pliage de constantes }
      If Res.TypeIdx = TY_IDX_BOOLEAN Then
      Begin
        If Res.ImmVal = 0 Then Res.ImmVal := 1
        Else Res.ImmVal := 0;
      End
      Else
        Res.ImmVal := Not Res.ImmVal;
    End
    Else
    Begin
      ExprFlushToAX(Res);
      If Res.TypeIdx = TY_IDX_BOOLEAN Then
      Begin
        { not booleen : XOR AX,1 }
        EmitInstrAB('XOR', 'AX', '1');
      End
      Else
      Begin
        { not entier (bits) : NOT AX }
        EmitInstr('NOT    AX');
      End;
      Res.Kind   := EK_AX;
      Res.SymIdx := -1;
    End;
    Exit;
  End;

  { Moins unaire }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '-') Then
  Begin
    TplNextToken;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
      Res.ImmVal := -Res.ImmVal
    Else
    Begin
      ExprFlushToAX(Res);
      EmitInstr('NEG    AX');
      Res.Kind   := EK_AX;
      Res.SymIdx := -1;
    End;
    Exit;
  End;

  { Plus unaire (no-op) }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '+') Then
  Begin
    TplNextToken;
    ParseUnary(Res);
    Exit;
  End;

  { @ (adresse de) }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '@') Then
  Begin
    TplNextToken;
    ParsePrimary(Res);
    { Emettre LEA pour obtenir l adresse de la variable }
    If (Res.SymIdx >= 0) And (Res.SymIdx < SymCount) Then
    Begin
      If SymTab[Res.SymIdx].IsLocal Then
      Begin
        EmitInstrAB('LEA', 'AX',
          BPOfs(SymTab[Res.SymIdx].Offset));
      End
      Else
      Begin
        EmitInstrAB('MOV', 'AX',
          'OFFSET ' + SymTab[Res.SymIdx].MangledName);
      End;
    End
    Else
    Begin
      WarnMsg('@ requiert une variable ou un parametre');
      EmitInstrAB('XOR', 'AX', 'AX');
    End;
    Res.Kind    := EK_AX;
    Res.TypeIdx := TY_IDX_POINTER;
    Res.SymIdx  := -1;
    Exit;
  End;

  { ^ (dereferencement pointeur : prefixe en Pascal = ptr^) }
  { En Pascal, ^ est normalement postfixe, mais on le gere ici en prefixe }

  { Pas d operateur unaire : appeler ParsePrimary }
  ParsePrimary(Res);
End;

{ ---- ParseExprPrec : Pratt parser pour operateurs binaires --- }
{ Boucle de montee de precedence.                                }
{ AX = gauche, BX = droite pour emission.                        }
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op        : TString;
  Prec      : Integer;
  Right     : TExprVal;
  LeftIsImm : Boolean;
  LeftImm   : LongInt;
  ResType   : Integer;
  LblSkip   : TString;
Begin
  ParseUnary(Res);

  Repeat
    Op   := '';
    Prec := 0;

    { Detecter operateur binaire }
    If CurToken.Kind = TK_OP Then
    Begin
      Op   := CurToken.Val;
      Prec := OpPrec(Op);
    End
    Else If (CurToken.Kind = TK_KEYWORD) And
            ((CurToken.Val = 'div') Or (CurToken.Val = 'mod') Or
             (CurToken.Val = 'and') Or (CurToken.Val = 'or') Or
             (CurToken.Val = 'xor') Or (CurToken.Val = 'shl') Or
             (CurToken.Val = 'shr') Or (CurToken.Val = 'in')) Then
    Begin
      Op   := CurToken.Val;
      Prec := OpPrec(Op);
    End;

    { Arreter si pas operateur ou precedence insuffisante }
    If (Prec = 0) Or (Prec < MinPrec) Then Break;

    TplNextToken;  { consommer l operateur }

    { Sauvegarder operande gauche }
    LeftIsImm := (Res.Kind = EK_IMM);
    LeftImm   := Res.ImmVal;
    If Not LeftIsImm Then
    Begin
      ExprFlushToAX(Res);
      EmitInstrA('PUSH', 'AX');
    End;

    { Recurser cote droit (gauche-assoc : Prec + 1) }
    ParseExprPrec(Prec + 1, Right);

    { Pliage de constantes si les deux sont immediats }
    If LeftIsImm And (Right.Kind = EK_IMM) Then
    Begin
      If Op = '+' Then
        ExprMakeImm(LeftImm + Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = '-' Then
        ExprMakeImm(LeftImm - Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = '*' Then
        ExprMakeImm(LeftImm * Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If (Op = '/') Or (Op = 'div') Then
      Begin
        If Right.ImmVal <> 0 Then
          ExprMakeImm(LeftImm Div Right.ImmVal, TY_IDX_INTEGER, Res)
        Else
        Begin
          WarnMsg('division par zero dans constante');
          ExprMakeImm(0, TY_IDX_INTEGER, Res);
        End;
      End
      Else If Op = 'mod' Then
      Begin
        If Right.ImmVal <> 0 Then
          ExprMakeImm(LeftImm Mod Right.ImmVal, TY_IDX_INTEGER, Res)
        Else
        Begin
          WarnMsg('modulo par zero dans constante');
          ExprMakeImm(0, TY_IDX_INTEGER, Res);
        End;
      End
      Else If Op = 'and' Then
        ExprMakeImm(LeftImm And Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = 'or' Then
        ExprMakeImm(LeftImm Or Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = 'xor' Then
        ExprMakeImm(LeftImm Xor Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = 'shl' Then
        ExprMakeImm(LeftImm Shl Integer(Right.ImmVal And 15),
                    TY_IDX_INTEGER, Res)
      Else If Op = 'shr' Then
        ExprMakeImm(LeftImm Shr Integer(Right.ImmVal And 15),
                    TY_IDX_INTEGER, Res)
      { Comparaisons -> booleen }
      Else If Op = '=' Then
        ExprMakeImm(Ord(LeftImm = Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '<>' Then
        ExprMakeImm(Ord(LeftImm <> Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '<' Then
        ExprMakeImm(Ord(LeftImm < Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '>' Then
        ExprMakeImm(Ord(LeftImm > Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '<=' Then
        ExprMakeImm(Ord(LeftImm <= Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '>=' Then
        ExprMakeImm(Ord(LeftImm >= Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = 'in' Then
      Begin
        WarnMsg('in : ensembles non supportes, retourne 0');
        ExprMakeImm(0, TY_IDX_BOOLEAN, Res);
      End
      Else
        ExprMakeImm(0, TY_IDX_INTEGER, Res);
    End
    Else
    Begin
      { ---- Emission de code binaire ---- }
      { Determiner le type resultat }
      ResType := Res.TypeIdx;
      If (Res.TypeIdx = TY_IDX_STRING) Or (Right.TypeIdx = TY_IDX_STRING) Then
        ResType := TY_IDX_STRING
      Else If (Op = '=') Or (Op = '<>') Or (Op = '<') Or (Op = '>') Or
              (Op = '<=') Or (Op = '>=') Or (Op = 'in') Then
        ResType := TY_IDX_BOOLEAN;

      { Charger droite dans BX }
      ExprFlushToAX(Right);
      EmitInstrAB('MOV', 'BX', 'AX');

      { Restaurer gauche dans AX }
      If LeftIsImm Then
        EmitInstrAB('MOV', 'AX', IntToStr(LeftImm))
      Else
        EmitInstrA('POP', 'AX');

      { AX = gauche, BX = droite }

      { --- Arithmetique --- }
      If Op = '+' Then
      Begin
        If ResType = TY_IDX_STRING Then
        { Concatenation chaine : SI=s1, DI=s2, CALL _PSPRT_CONCAT }
      Begin
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrAB('MOV', 'DI', 'BX');
        EmitInstrA('CALL', PSP_RT_PFX + 'CONCAT');
      End
      Else
        EmitInstrAB('ADD', 'AX', 'BX');
      End
      Else If Op = '-' Then
        EmitInstrAB('SUB', 'AX', 'BX')

      Else If Op = '*' Then
        EmitInstrA('IMUL', 'BX')

      Else If (Op = '/') Or (Op = 'div') Then
      Begin
        { IDIV BX : AX = quotient, DX = reste (div0 = panic) }
        EmitInstrAB('CMP', 'BX', '0');
        EmitInstrA('JE', PSP_RT_PFX + 'PANIC_DIV0');
        EmitInstr('CWD');
        EmitInstrA('IDIV', 'BX');
      End

      Else If Op = 'mod' Then
      Begin
        EmitInstrAB('CMP', 'BX', '0');
        EmitInstrA('JE', PSP_RT_PFX + 'PANIC_DIV0');
        EmitInstr('CWD');
        EmitInstrA('IDIV', 'BX');
        EmitInstrAB('MOV', 'AX', 'DX');  { reste dans DX }
      End

      { --- Bits / Logiques (meme instruction, type determine le sens) --- }
      Else If Op = 'and' Then
        EmitInstrAB('AND', 'AX', 'BX')

      Else If Op = 'or' Then
        EmitInstrAB('OR', 'AX', 'BX')

      Else If Op = 'xor' Then
        EmitInstrAB('XOR', 'AX', 'BX')

      Else If Op = 'shl' Then
      Begin
        EmitInstrAB('MOV', 'CL', 'BL');
        EmitInstrAB('SHL', 'AX', 'CL');
      End

      Else If Op = 'shr' Then
      Begin
        EmitInstrAB('MOV', 'CL', 'BL');
        EmitInstrAB('SHR', 'AX', 'CL');
      End

      { --- Comparaisons : CMP + Jcc -> AX = 0|1 --- }
      Else If Op = '=' Then
      Begin
        LblSkip := LabelGen;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', PSP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'AX', '0');
        End
        Else
          EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JNE', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End

      Else If Op = '<>' Then
      Begin
        LblSkip := LabelGen;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', PSP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'AX', '0');
        End
        Else
          EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JE', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End

      Else If Op = '<' Then
      Begin
        LblSkip := LabelGen;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', PSP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'AX', '0');
        End
        Else
          EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JGE', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End

      Else If Op = '<=' Then
      Begin
        LblSkip := LabelGen;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', PSP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'AX', '0');
        End
        Else
          EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JG', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End

      Else If Op = '>' Then
      Begin
        LblSkip := LabelGen;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', PSP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'AX', '0');
        End
        Else
          EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JLE', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End

      Else If Op = '>=' Then
      Begin
        LblSkip := LabelGen;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', PSP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'AX', '0');
        End
        Else
          EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JL', LblSkip);
        EmitInstr('INC    AX');
        EmitLabel(LblSkip);
      End

      Else If Op = 'in' Then
      Begin
        { in : test appartenance sous-plage (stub) }
        EmitInstrAB('XOR', 'AX', 'AX');
        WarnMsg('in : ensembles non supportes, retourne 0');
      End;

      Res.Kind    := EK_AX;
      Res.TypeIdx := ResType;
      Res.SymIdx  := -1;
    End;
  Until False;
End;

{ ---- ParseExpr : point d entree pour les expressions --------- }
Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParseExprPrec(1, Res);
End;

{ ============================================================
  INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- Messages d'erreur et d'avertissement ---------------- }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('PSP86: FATAL: ', Msg);
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

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('PSP86: warning: ', Msg);
  Inc(WarnCount);
End;

{ ---- ErrorMsg, Expect, SkipTo -------------------- }

Procedure ErrorMsg(Const Msg : TString);
Begin
  WriteLn('PSP86: erreur ligne ', LexLineNo, ' : ', Msg);
  Inc(ErrorCount);
End;

Procedure Expect(Const Expected : TString);
Begin
  If CurToken.Val <> Expected Then
  Begin
    ErrorMsg('''' + Expected + ''' attendu, trouve ''' + CurToken.Val + '''');
    SkipTo;
  End
  Else
    TplNextToken;
End;

Procedure SkipTo;
Begin
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) And
        Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'end')) And
        Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'begin')) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '%>')) Do
    TplNextToken;
End;

{ ---- Banniere ---------------------------------------------- }

Procedure ShowBanner;
Begin
  WriteLn('PSP86 v', PSP86_VERSION, ' (', PSP86_DATE, ')');
  WriteLn('Compilateur Pascal Server Pages -> assembleur 8086');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)  Cible: MASM .MODEL SMALL');
  WriteLn;
End;

Procedure ShowUsage;Begin
 WriteLn('PSP86 - Cette commande permet de lancer le compilateur de PSP (Pascal Server Pages) pour ',
         'l''assembleur du microprocesseur 8086.');
 WriteLn;
 WriteLn('Syntaxe : PSP86 <page.psp> [sortie.asm] [-v] [-d] [-w]');
 WriteLn;
 WriteLn('  page.psp   : fichier Pascal Server Pages source');
 WriteLn('  sortie.asm : fichier assembleur de sortie (defaut: page.asm)');
 WriteLn('  -v         : mode verbeux (banniere + statistiques)');
 WriteLn('  -d         : debug tokens (affiche chaque token)');
 WriteLn('  -w         : activer les avertissements');
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

Function IntToStr(N : LongInt) : TString;
Var
  S : TString;
Begin
  Str(N, S);
  IntToStr := S;
End;

{ Retourne '[BP+n]' ou '[BP-n]' selon le signe }
Function BPOfs(Ofs : Integer) : TString;
Begin
  If Ofs >= 0 Then
    BPOfs := '[BP+' + IntToStr(Ofs) + ']'
  Else
    BPOfs := '[BP' + IntToStr(Ofs) + ']';
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

{ Retourne l extension d un chemin (avec le point) }
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

    If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('PSP86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('PSP86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('PSP86: fichier source manquant');
    ShowUsage;
  End;

  { Verifier l extension .psp }
  Ext := ExtractExt(Opts.SrcFile);
  If (Ext <> '.psp') Then
    WarnMsg('extension attendue .psp, trouvee: ' + Ext);

  { Fichier de sortie par defaut : meme nom avec .asm }
  If Opts.OutFile = '' Then
    Opts.OutFile := ReplaceExt(Opts.SrcFile, '.asm');
End;

{ ---- Nettoyage -------------------------------------------- }

Procedure Cleanup;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ---- Initialisation generale -------------------------------- }

Procedure GlobalInit;
Begin
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  TotalSyms  := 0;
  OutFOpen   := False;
  LexOpened  := False;
  LexEOF     := False;
  LexLineNo  := 0;
  LexColNo   := 1;
  LexLine    := '';
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
  DataCount   := 0;
  LabelGenSeq := 0;
  SymCount      := 0;
  CurScopeLevel := 0;
  CurScopeId    := 0;
  ScopeIdSeq    := 0;
  TypeCount := 0;
  CurFrameOffset    := 0;
  HasPendingAssign  := False;
  PendingAssignName := '';
  LoopTop := -1;
  CurFuncName   := '';
  CurFuncRetOfs := 0;
  CurRetLabel   := '';
  CurNestLevel  := 0;
  CurParamBytes := 0;
  MainBodyEmitted := False;
  RuntimeEmitted  := False;
  WithTop := -1;
  IncTop        := -1;
  DefineCount   := 0;
  CompilerMode  := 'TP';
  ContentTypeLbl := '';
  LexSrcFName   := '';
  TypeInit;
  SymInit;
End;

{ ---- Pipeline de compilation (stub) ------------------------- }

Procedure Run;
Begin
  GlobalInit;
  If Opts.Verbose Then ShowBanner;

  { Verifier que le fichier source existe }
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
  LexOpened := True;
  LexSrcFName := Opts.SrcFile;

  { Creer le fichier de sortie }
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  If IOResult <> 0 Then
    FatalError('impossible de creer le fichier de sortie: ' + Opts.OutFile);
  OutFOpen := True;

  { Initialiser le lexeur et l analyseur template }
  LexInit;
  TplInit;

  { Emettre l en-tete ASM }
  EmitHeader;

  { Boucle principale : analyseur de template PSP }
  TplNextToken;  { Lire le premier token }
  While CurToken.Kind <> TK_EOF Do
  Begin
    { --- Fragments HTML (hors <% %>) --- }
    If CurToken.Kind = TK_HTML Then
    Begin
      EmitHtmlFragment(CurToken.Val);
      TplNextToken;
    End
    { --- Balise ouvrante <% : passer en mode code --- }
    Else If CurToken.Kind = TK_PSP_OPEN Then
    Begin
      TplNextToken;  { consommer <%, prochain token = code Pascal }
    End
    { --- Expression inline <%= expr %> --- }
    Else If CurToken.Kind = TK_PSP_EXPR_OPEN Then
    Begin
      TplNextToken;  { consommer <%=, prochain token = debut expr }
      EmitExprInline;
    End
    { --- Balise fermante %> : retour HTML --- }
    Else If CurToken.Kind = TK_PSP_CLOSE Then
    Begin
      TplNextToken;  { consommer %>, retour en mode HTML }
    End
    { --- Directive <%@ ... %> : parser attributs --- }
    Else If CurToken.Kind = TK_PSP_DIRECTIVE Then
    Begin
      ParsePSPDirective;
    End
    { --- Instructions Pascal (delegation a ParseStatement) --- }
    Else If (CurToken.Kind = TK_KEYWORD) Or
            (CurToken.Kind = TK_IDENT) Then
    Begin
      { Emettre JMP MAINBODY juste avant la premiere function/procedure }
      If ((CurToken.Kind = TK_KEYWORD) And
          ((CurToken.Val = 'function') Or (CurToken.Val = 'procedure'))) And
         (Not MainBodyEmitted) Then
      Begin
        EmitInstrA('JMP', PSP_LBL_PFX + 'MAINBODY');
        EmitBlankLine;
      End;
      ParseStatement;
      { Consommer les ; residuels }
      While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Do
        TplNextToken;
    End
    Else
      TplNextToken;  { Avancer seulement si aucun match }
  End;
   { Emettre le pied de page ASM }
  EmitFooter;
   { Fermer l analyseur template et le lexeur }
  TplClose;
  LexClose;
   { Emettre le segment de donnees }
  EmitDataSeg;
   { Emettre la directive END }
  If OutFOpen Then
    WriteLn(OutF, '        END     ' + PSP_FN_PFX + 'main');
  Cleanup;
  If Opts.Verbose Then Begin
    WriteLn('Compilation terminee : ', Opts.SrcFile, ' -> ', Opts.OutFile);
    WriteLn('  Lignes         : ', TotalLines);
    WriteLn('  Symboles       : ', TotalSyms);
    WriteLn('  Erreurs        : ', ErrorCount);
    WriteLn('  Avertissements : ', WarnCount);
  End;
  If ErrorCount > 0 Then Halt(EXIT_ERROR)
                    Else Halt(EXIT_OK);
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  ShowUsage;
  Halt(0);
 End;
 ParseArgs;
 Run;
END.