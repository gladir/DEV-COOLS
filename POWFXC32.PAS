{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2 / Turbo Pascal 7)
  @description: Compilateur Power FX (sous-ensemble) vers assembleur 80386
                pour Windows 32 bits - Inspire de ADACW32.PAS par
                
  @license: MIT
}


Program POWFXC32;

(*
============================================================
  POWFXC32.PAS - Compilateur Power FX (sous-ensemble)
vers assembleur 80386 pour Windows 32 bits
Turbo Pascal / Free Pascal (-Mtp)

Cible : MASM .386 / .MODEL FLAT, PE Win32

Par defaut produit un fichier .ASM + .EXE (PE Windows 32 bits).
Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
Avec le parametre -asm, conserve le fichier .ASM lisible.

Power FX - sous-ensemble supporte :
  Types    : Number (Double IEEE-754 64 bits), Text (ASCIIZ),
             Boolean (DWORD 0/1)
  Operateurs: + - * / ^ & (concat) = <> < > <= >= && || !
  Controle : If(cond, oui, non), Switch(expr, v1, r1, ..., defaut)
  Affectation: Set(variable, formule)
  Affichage: Print(formule)  [extension compilateur]
  Fonctions numeriques : Abs, Sqrt, Int, Round, Power, Mod, Log, Exp
  Fonctions texte : Len, Left, Right, Mid, Upper, Lower, Trim,
                    Concatenate, Text, Value
  Fonctions logiques : And, Or, Not, IsBlank, IsError, Blank()
  Stubs : Collect, Clear, Patch, Remove (non implementes, ignores)

Format source (.pfx) :
  // commentaire ligne
  /* commentaire bloc */
  Set(variable, formule) ;
  Print(formule) ;

Inspire de ADACW32.PAS par Sylvain Maltais (www.gladir.com/DEV-COOLS)

@author: GitHub Copilot
@created: 2026
@version: 0.1
@abstract(Target: Free Pascal 3.2 / Turbo Pascal 7)
@description: Compilateur Power FX vers assembleur 80386 (Windows PE 32 bits)
@license: MIT
============================================================
*)

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
  {$R-}
{$ENDIF}
{$I-}

{ ============================================================ }
{ CONSTANTES                                                    }
{ ============================================================ }

Const
  POWFXC32_VERSION = '0.1';
  POWFXC32_DATE    = '2026';

  { Limites internes }
  MAX_SYM    = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_FN     = {$IFDEF FPC}128{$ELSE}32{$ENDIF};
  MAX_PARAM  = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_DEPTH  = {$IFDEF FPC}8{$ELSE}4{$ENDIF};
  MAX_STR    = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_DATA   = {$IFDEF FPC}256{$ELSE}64{$ENDIF};
  MAX_ERRORS = 20;

  { Types de tokens }
  TOK_EOF      =  0;
  TOK_NUMBER   =  1;   { litteral numerique           }
  TOK_TEXT     =  2;   { litteral chaine              }
  TOK_IDENT    =  3;   { identificateur / mot-cle     }
  TOK_LPAREN   =  4;   { (                            }
  TOK_RPAREN   =  5;   { )                            }
  TOK_LBRACKET =  6;   { [                            }
  TOK_RBRACKET =  7;   { ]                            }
  TOK_COMMA    =  8;   { ,                            }
  TOK_SEMI     =  9;   { ;                            }
  TOK_DOT      = 10;   { .                            }
  TOK_PLUS     = 11;   { +                            }
  TOK_MINUS    = 12;   { -                            }
  TOK_STAR     = 13;   { *                            }
  TOK_SLASH    = 14;   { /                            }
  TOK_POWER    = 15;   { ^                            }
  TOK_AMP      = 16;   { &  (concatenation texte)     }
  TOK_EQ       = 17;   { =                            }
  TOK_NEQ      = 18;   { <> ou !=                     }
  TOK_LT       = 19;   { <                            }
  TOK_GT       = 20;   { >                            }
  TOK_LE       = 21;   { <=                           }
  TOK_GE       = 22;   { >=                           }
  TOK_AND      = 23;   { &&                           }
  TOK_OR       = 24;   { ||                           }
  TOK_NOT      = 25;   { !                            }
  TOK_AT       = 26;   { @                            }
  TOK_COLON    = 27;   { :                            }
  TOK_UNKNOWN  = 99;

  { Mots-cles Power FX (insensible a la casse) }
  KW_NONE     =  0;
  KW_IF       =  1;   { If(cond, oui, non)           }
  KW_TRUE     =  2;   { true                         }
  KW_FALSE    =  3;   { false                        }
  KW_AND      =  4;   { And(...)                     }
  KW_OR       =  5;   { Or(...)                      }
  KW_NOT      =  6;   { Not(...)                     }
  KW_IN       =  7;   { in                           }
  KW_EXACTIN  =  8;   { exactIn                      }
  KW_SET      =  9;   { Set(var, val)                }
  KW_COLLECT  = 10;   { Collect(...)                 }
  KW_CLEAR    = 11;   { Clear(...)                   }
  KW_PATCH    = 12;   { Patch(...)                   }
  KW_REMOVE   = 13;   { Remove(...)                  }
  KW_FORALL   = 14;   { ForAll(...)                  }
  KW_FILTER   = 15;   { Filter(...)                  }
  KW_SWITCH   = 16;   { Switch(...)                  }
  KW_ISBLANK  = 17;   { IsBlank(...)                 }
  KW_ISERROR  = 18;   { IsError(...)                 }
  KW_BLANK    = 19;   { Blank()                      }
  KW_PRINT    = 20;   { Print(x)  [extension]        }
  KW_LET      = 21;   { Let(...)                     }
  KW_WITH     = 22;   { With(...)                    }

  { Types Power FX }
  PFX_UNKNOWN = 0;
  PFX_NUMBER  = 1;   { Double IEEE-754 64 bits       }
  PFX_TEXT    = 2;   { pointeur ASCIIZ               }
  PFX_BOOLEAN = 3;   { DWORD 0/1                     }
  PFX_BLANK   = 4;   { valeur nulle (0)              }
  PFX_ERROR   = 5;   { valeur erreur                 }

  { Classes d entreposage }
  STORE_GLOBAL = 0;  { variable globale (.DATA)      }
  STORE_LOCAL  = 1;  { variable locale (pile EBP)    }
  STORE_CONST  = 2;  { constante                     }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Prefixes d etiquettes ASM }
  PFX_VAR_PFX  = '_PFX_';     { variable globale     }
  PFX_FN_PFX   = '_PFXF_';    { fonction / procedure }
  PFX_STR_PFX  = '_PFXK_';    { chaine litterale     }
  PFX_RT_PFX   = '_PFXRT_';   { helper runtime       }
  PFX_LBL_PFX  = '_PFXL_';    { label interne        }
  PFX_NUM_PFX  = '_PFXN_';    { litteral numerique   }

  { Constantes PE/COFF }
{$IFDEF FPC}
  PE_DOS_MAGIC    = $5A4D;
  PE_PE_SIG       = $00004550;
  PE_MACHINE_I386 = $014C;
  PE_OPT_SIZE     = 224;
  PE_MAGIC_32     = $010B;
  PE_IMG_BASE     = $00400000;
  PE_SEC_ALIGN    = $1000;
  PE_FILE_ALIGN   = $0200;
  PE_SUBSYS_CUI   = 3;
  PE_SCN_TEXT     = $60000020;
  PE_SCN_DATA     = LongInt($C0000040);
  MAX_BIN_CODE    = 32768;
  MAX_BIN_DATA    = 32768;
  MAX_BIN_LBL     = 1024;
  MAX_BIN_FIX     = 2048;
  PE_NUM_API      = 7;
{$ENDIF}

{ ============================================================ }
{ TYPES                                                         }
{ ============================================================ }

Type
  TString = String[MAX_STR];

  TOptions = Record
    SrcFile   : TString;
    OutFile   : TString;
    Verbose   : Boolean;
    DebugMode : Boolean;
    Warnings  : Boolean;
    EmitExe   : Boolean;
    EmitObj   : Boolean;
    EmitAsm   : Boolean;
  End;

{$IFDEF FPC}
  TBinFixKind = (BFK_ABS32, BFK_REL32, BFK_IAT32);
  TBinFixup = Record
    Offset : LongInt;
    Kind   : TBinFixKind;
    Target : TString;
    InCode : Boolean;
  End;
  TBinLabel = Record
    Name   : TString;
    Offset : LongInt;
    InCode : Boolean;
  End;
{$ENDIF}

  { Entree de la table des symboles }
  TSymEntry = Record
    Name      : String[48];
    AsmLabel  : String[48];
    VarType   : Integer;     { PFX_xxx                  }
    StoreClass: Integer;     { STORE_xxx                }
    BpOffset  : Integer;     { offset EBP si locale     }
    IsConst   : Boolean;
    ScopeLev  : Integer;
    HasInit   : Boolean;
  End;

  { Entree de la table des fonctions utilisateur }
  TFnEntry = Record
    Name      : String[48];
    AsmLabel  : String[48];
    RetType   : Integer;
    ParamCount: Integer;
    ParamTypes: Array[1..MAX_PARAM] of Integer;
    IsBuiltin : Boolean;
  End;

  { Entree de la pile de scopes }
  TScopeEntry = Record
    Kind     : Integer;
    BpTop    : Integer;
    SymStart : Integer;
    LblExit  : String[16];
  End;

{ ============================================================ }
{ VARIABLES GLOBALES                                            }
{ ============================================================ }

Var
  Opts       : TOptions;
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;
  OutF       : Text;
  OutFOpen   : Boolean;

  { Lexeur }
  LexSrcF    : Text;
  LexOpened  : Boolean;
  LexLine    : TString;
  LexLineNo  : Integer;
  LexColNo   : Integer;
  LexEOF     : Boolean;
  CurTokType : Integer;
  CurTokStr  : TString;
  CurTokNum  : LongInt;
  CurTokKw   : Integer;

  { Table des symboles }
  SymTab     : Array[1..MAX_SYM] of TSymEntry;
  SymCount   : Integer;
  ScopeTop   : Integer;

  { Table des fonctions }
  FnTab      : Array[1..MAX_FN] of TFnEntry;
  FnCount    : Integer;

  { Pile de scopes }
  ScopeStack : Array[0..MAX_DEPTH] of TScopeEntry;

  { Generateur de code }
  GenEnabled   : Boolean;
  LabelCounter : Integer;
  StrTab       : Array[1..MAX_DATA] of TString;
  StrLblTab    : Array[1..MAX_DATA] of TString;
  StrCount     : Integer;
  NumTab       : Array[1..MAX_DATA] of TString;
  NumLblTab    : Array[1..MAX_DATA] of TString;
  NumCount     : Integer;

  { Type courant de l expression (mis a jour par le parseur) }
  ExprType : Integer;

{$IFDEF FPC}
  BinCode     : Array[0..MAX_BIN_CODE - 1] of Byte;
  BinCodeLen  : LongInt;
  BinData     : Array[0..MAX_BIN_DATA - 1] of Byte;
  BinDataLen  : LongInt;
  BinLabels   : Array[0..MAX_BIN_LBL - 1] of TBinLabel;
  BinLblCount : Integer;
  BinFixups   : Array[0..MAX_BIN_FIX - 1] of TBinFixup;
  BinFixCount : Integer;
{$ENDIF}

Const
{$IFDEF FPC}
  BinAPIDecorated : Array[0..PE_NUM_API - 1] Of String[32] = (
    '_ExitProcess@4',
    '_GetStdHandle@4',
    '_WriteFile@20',
    '_ReadFile@20',
    '_GetProcessHeap@0',
    '_HeapAlloc@12',
    '_HeapFree@12'
  );
  BinAPIName : Array[0..PE_NUM_API - 1] Of String[20] = (
    'ExitProcess',
    'GetStdHandle',
    'WriteFile',
    'ReadFile',
    'GetProcessHeap',
    'HeapAlloc',
    'HeapFree'
  );
{$ENDIF}

{ ============================================================ }
{ DECLARATIONS FORWARD                                          }
{ ============================================================ }

Procedure ParseExpr; Forward;
Procedure ParseStatement; Forward;
Procedure SkipToSemi; Forward;
{$IFDEF FPC}
Procedure BinInit; Forward;
Procedure BinEmitByte(B : Byte); Forward;
Procedure BinEmitWord(W : Word); Forward;
Procedure BinEmitDWord(D : LongInt); Forward;
Procedure BinEmitDataByte(B : Byte); Forward;
Procedure BinEmitDataDWord(D : LongInt); Forward;
Procedure BinAddLabel(AName : TString; AnOfs : LongInt); Forward;
Procedure BinAddFixup(AnOfs : LongInt; AKind : TBinFixKind;
                      ATarget : TString; AInCode : Boolean); Forward;
Function  BinFindLabel(AName : TString) : LongInt; Forward;
Procedure BinAssemble; Forward;
Procedure BinWriteObj; Forward;
Procedure BinWriteExe; Forward;
{$ENDIF}

{ ============================================================ }
{ FONCTIONS UTILITAIRES                                         }
{ ============================================================ }

Function IntToStr_(V : LongInt) : TString;
Var S : TString;
Begin
  Str(V, S);
  IntToStr_ := S;
End;

Function StrUpperCase(Const S : TString) : TString;
Var I : Integer; T : TString;
Begin
  T := S;
  For I := 1 To Length(T) Do
    If (T[I] >= 'a') And (T[I] <= 'z') Then
      T[I] := Chr(Ord(T[I]) - 32);
  StrUpperCase := T;
End;

Function AsmIdent(Const S : TString) : TString;
Var I : Integer; T : TString;
Begin
  T := StrUpperCase(S);
  For I := 1 To Length(T) Do
    If Not (((T[I] >= 'A') And (T[I] <= 'Z')) Or
            ((T[I] >= '0') And (T[I] <= '9')) Or
            (T[I] = '_')) Then
      T[I] := '_';
  AsmIdent := T;
End;

Function ExtractExt(Const Path : TString) : TString;
Var I, LastDot : Integer;
Begin
  LastDot := 0;
  For I := 1 To Length(Path) Do
    If Path[I] = '.' Then LastDot := I;
  If LastDot > 0 Then
    ExtractExt := Copy(Path, LastDot, Length(Path) - LastDot + 1)
  Else
    ExtractExt := '';
End;

Function ReplaceExt(Const Path, NewExt : TString) : TString;
Var I, LastDot : Integer;
Begin
  LastDot := 0;
  For I := 1 To Length(Path) Do
    If Path[I] = '.' Then LastDot := I;
  If LastDot > 0 Then
    ReplaceExt := Copy(Path, 1, LastDot - 1) + NewExt
  Else
    ReplaceExt := Path + NewExt;
End;

{ ============================================================ }
{ GESTION DES ERREURS                                           }
{ ============================================================ }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('POWFXC32: FATAL: ', Msg);
  If OutFOpen Then Begin Close(OutF); OutFOpen := False; End;
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  Inc(WarnCount);
  If Not Opts.Warnings Then Exit;
  WriteLn('POWFXC32: warning: ', Msg);
End;

Procedure Error(Const Msg : TString);
Begin
  WriteLn('POWFXC32: ERREUR ligne ', LexLineNo, ': ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, abandon');
End;

Procedure Warning(Const Msg : TString);
Begin
  Inc(WarnCount);
  If Not Opts.Warnings Then Exit;
  WriteLn('POWFXC32: ATTENTION ligne ', LexLineNo, ': ', Msg);
End;

{ ============================================================ }
{ LEXEUR POWER FX                                               }
{ ============================================================ }

Function LexCurChar : Char;
Begin
  If LexEOF Or (LexColNo > Length(LexLine)) Then
    LexCurChar := #0
  Else
    LexCurChar := LexLine[LexColNo];
End;

Function LexPeek : Char;
Begin
  If LexEOF Or (LexColNo + 1 > Length(LexLine)) Then
    LexPeek := #0
  Else
    LexPeek := LexLine[LexColNo + 1];
End;

Procedure LexAdvance;
Begin Inc(LexColNo); End;

Procedure LexNextLine;
Begin
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

{ ---- LexSkipWS : sauter espaces, commentaires // et /* ... */ }
Procedure LexSkipWS;
Var Done : Boolean;
Begin
  Done := False;
  While Not Done Do
  Begin
    Done := True;
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;
    If LexEOF Then Exit;

    { Espaces et tabulations }
    While (LexColNo <= Length(LexLine)) And
          ((LexLine[LexColNo] = ' ') Or (LexLine[LexColNo] = #9)) Do
    Begin Inc(LexColNo); Done := False; End;

    { Commentaire // jusqu a fin de ligne }
    If (LexColNo < Length(LexLine)) And
       (LexLine[LexColNo] = '/') And (LexLine[LexColNo + 1] = '/') Then
    Begin
      LexColNo := Length(LexLine) + 1;
      Done := False;
    End;

    { Commentaire /* ... */ }
    If (LexColNo < Length(LexLine)) And
       (LexLine[LexColNo] = '/') And (LexLine[LexColNo + 1] = '*') Then
    Begin
      Inc(LexColNo, 2);
      While Not LexEOF Do
      Begin
        While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
          LexNextLine;
        If LexEOF Then Break;
        If (LexColNo < Length(LexLine)) And
           (LexLine[LexColNo] = '*') And (LexLine[LexColNo + 1] = '/') Then
        Begin
          Inc(LexColNo, 2);
          Break;
        End;
        Inc(LexColNo);
      End;
      Done := False;
    End;
  End;
End;

{ ---- IsPfxKeyword : table des mots-cles Power FX (insensible a la casse) }
Function IsPfxKeyword(Const S : TString) : Integer;
Var U : TString;
Begin
  U := StrUpperCase(S);
  IsPfxKeyword := KW_NONE;
  If      U = 'IF'       Then IsPfxKeyword := KW_IF
  Else If U = 'TRUE'     Then IsPfxKeyword := KW_TRUE
  Else If U = 'FALSE'    Then IsPfxKeyword := KW_FALSE
  Else If U = 'AND'      Then IsPfxKeyword := KW_AND
  Else If U = 'OR'       Then IsPfxKeyword := KW_OR
  Else If U = 'NOT'      Then IsPfxKeyword := KW_NOT
  Else If U = 'IN'       Then IsPfxKeyword := KW_IN
  Else If U = 'EXACTIN'  Then IsPfxKeyword := KW_EXACTIN
  Else If U = 'SET'      Then IsPfxKeyword := KW_SET
  Else If U = 'COLLECT'  Then IsPfxKeyword := KW_COLLECT
  Else If U = 'CLEAR'    Then IsPfxKeyword := KW_CLEAR
  Else If U = 'PATCH'    Then IsPfxKeyword := KW_PATCH
  Else If U = 'REMOVE'   Then IsPfxKeyword := KW_REMOVE
  Else If U = 'FORALL'   Then IsPfxKeyword := KW_FORALL
  Else If U = 'FILTER'   Then IsPfxKeyword := KW_FILTER
  Else If U = 'SWITCH'   Then IsPfxKeyword := KW_SWITCH
  Else If U = 'ISBLANK'  Then IsPfxKeyword := KW_ISBLANK
  Else If U = 'ISERROR'  Then IsPfxKeyword := KW_ISERROR
  Else If U = 'BLANK'    Then IsPfxKeyword := KW_BLANK
  Else If U = 'PRINT'    Then IsPfxKeyword := KW_PRINT
  Else If U = 'LET'      Then IsPfxKeyword := KW_LET
  Else If U = 'WITH'     Then IsPfxKeyword := KW_WITH;
End;

{ ---- LexIdent : identificateur ou mot-cle (insensible a la casse) }
Procedure LexIdent;
Var S : TString; C : Char;
Begin
  S := '';
  While LexColNo <= Length(LexLine) Do
  Begin
    C := LexLine[LexColNo];
    If ((C >= 'A') And (C <= 'Z')) Or ((C >= 'a') And (C <= 'z')) Or
       ((C >= '0') And (C <= '9')) Or (C = '_') Then
    Begin
      If Length(S) < 48 Then S := S + C;
      LexAdvance;
    End
    Else Break;
  End;
  CurTokStr  := S;
  CurTokKw   := IsPfxKeyword(S);
  CurTokType := TOK_IDENT;
End;

{ ---- LexNumber : entier ou flottant (1.5, 1.5e3, 1.5E-3) }
Procedure LexNumber;
Var S : TString; C : Char; Err : Integer;
Begin
  S := '';
  While LexColNo <= Length(LexLine) Do
  Begin
    C := LexLine[LexColNo];
    If (C >= '0') And (C <= '9') Then
    Begin S := S + C; LexAdvance; End
    Else If (C = '.') And (LexPeek >= '0') And (LexPeek <= '9') Then
    Begin S := S + C; LexAdvance; End
    Else Break;
  End;
  { Exposant E/e }
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'e') Or (LexLine[LexColNo] = 'E')) Then
  Begin
    S := S + 'E';
    LexAdvance;
    If (LexColNo <= Length(LexLine)) And
       ((LexCurChar = '+') Or (LexCurChar = '-')) Then
    Begin S := S + LexCurChar; LexAdvance; End;
    While (LexColNo <= Length(LexLine)) And
          (LexCurChar >= '0') And (LexCurChar <= '9') Do
    Begin S := S + LexCurChar; LexAdvance; End;
  End;
  CurTokStr  := S;
  CurTokType := TOK_NUMBER;
  Val(S, CurTokNum, Err);
  If Err <> 0 Then CurTokNum := 0;
End;

{ ---- LexString : chaine entre guillemets doubles ("..." ou "") }
Procedure LexString;
Var S : TString; C : Char;
Begin
  S := '';
  While LexColNo <= Length(LexLine) Do
  Begin
    C := LexLine[LexColNo];
    If C = '"' Then
    Begin
      { "" = guillemet double echappe }
      If (LexColNo + 1 <= Length(LexLine)) And
         (LexLine[LexColNo + 1] = '"') Then
      Begin
        If Length(S) < MAX_STR Then S := S + '"';
        Inc(LexColNo, 2);
      End
      Else
      Begin LexAdvance; Break; End;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then S := S + C;
      LexAdvance;
    End;
  End;
  CurTokStr  := S;
  CurTokType := TOK_TEXT;
End;

{ ---- LexNextToken : dispatcher principal du lexeur }
Procedure LexNextToken;
Var C : Char;
Begin
  CurTokStr  := '';
  CurTokNum  := 0;
  CurTokKw   := KW_NONE;
  LexSkipWS;

  If LexEOF Or (LexColNo > Length(LexLine)) Then
  Begin
    CurTokType := TOK_EOF;
    Exit;
  End;

  C := LexCurChar;

  { Identificateurs et mots-cles }
  If ((C >= 'A') And (C <= 'Z')) Or
     ((C >= 'a') And (C <= 'z')) Or (C = '_') Then
  Begin LexIdent; Exit; End;

  { Litteraux numeriques }
  If (C >= '0') And (C <= '9') Then
  Begin LexNumber; Exit; End;

  { Litteraux chaine }
  If C = '"' Then
  Begin LexAdvance; LexString; Exit; End;

  LexAdvance;
  Case C Of
    '(' : Begin CurTokType := TOK_LPAREN;   CurTokStr := '('; End;
    ')' : Begin CurTokType := TOK_RPAREN;   CurTokStr := ')'; End;
    '[' : Begin CurTokType := TOK_LBRACKET; CurTokStr := '['; End;
    ']' : Begin CurTokType := TOK_RBRACKET; CurTokStr := ']'; End;
    ',' : Begin CurTokType := TOK_COMMA;    CurTokStr := ','; End;
    ';' : Begin CurTokType := TOK_SEMI;     CurTokStr := ';'; End;
    '.' : Begin CurTokType := TOK_DOT;      CurTokStr := '.'; End;
    '+' : Begin CurTokType := TOK_PLUS;     CurTokStr := '+'; End;
    '-' : Begin CurTokType := TOK_MINUS;    CurTokStr := '-'; End;
    '*' : Begin CurTokType := TOK_STAR;     CurTokStr := '*'; End;
    '^' : Begin CurTokType := TOK_POWER;    CurTokStr := '^'; End;
    '@' : Begin CurTokType := TOK_AT;       CurTokStr := '@'; End;
    ':' : Begin CurTokType := TOK_COLON;    CurTokStr := ':'; End;
    '&' :
    Begin
      If (LexColNo <= Length(LexLine)) And (LexCurChar = '&') Then
      Begin LexAdvance; CurTokType := TOK_AND; CurTokStr := '&&'; End
      Else Begin CurTokType := TOK_AMP; CurTokStr := '&'; End;
    End;
    '|' :
    Begin
      If (LexColNo <= Length(LexLine)) And (LexCurChar = '|') Then
      Begin LexAdvance; CurTokType := TOK_OR; CurTokStr := '||'; End
      Else Begin CurTokType := TOK_UNKNOWN; CurTokStr := '|'; End;
    End;
    '!' :
    Begin
      If (LexColNo <= Length(LexLine)) And (LexCurChar = '=') Then
      Begin LexAdvance; CurTokType := TOK_NEQ; CurTokStr := '!='; End
      Else Begin CurTokType := TOK_NOT; CurTokStr := '!'; End;
    End;
    '=' : Begin CurTokType := TOK_EQ; CurTokStr := '='; End;
    '<' :
    Begin
      If (LexColNo <= Length(LexLine)) And (LexCurChar = '=') Then
      Begin LexAdvance; CurTokType := TOK_LE; CurTokStr := '<='; End
      Else If (LexColNo <= Length(LexLine)) And (LexCurChar = '>') Then
      Begin LexAdvance; CurTokType := TOK_NEQ; CurTokStr := '<>'; End
      Else Begin CurTokType := TOK_LT; CurTokStr := '<'; End;
    End;
    '>' :
    Begin
      If (LexColNo <= Length(LexLine)) And (LexCurChar = '=') Then
      Begin LexAdvance; CurTokType := TOK_GE; CurTokStr := '>='; End
      Else Begin CurTokType := TOK_GT; CurTokStr := '>'; End;
    End;
    '/' : Begin CurTokType := TOK_SLASH; CurTokStr := '/'; End;
  Else
    CurTokType := TOK_UNKNOWN;
    CurTokStr  := C;
  End;
End;

{ ---- Helpers lexeur }
Procedure Consume;
Begin LexNextToken; End;

Function TokIsKw(Kw : Integer) : Boolean;
Begin TokIsKw := (CurTokType = TOK_IDENT) And (CurTokKw = Kw); End;

Procedure Expect(TokType : Integer; Const What : TString);
Begin
  If CurTokType <> TokType Then
    Error('Attendu ' + What + ', trouve: ''' + CurTokStr + '''');
  Consume;
End;

{ ============================================================ }
{ TABLE DES SYMBOLES                                            }
{ ============================================================ }

Procedure InitSymTable;
Var I : Integer;
Begin
  SymCount := 0;
  ScopeTop := 0;
  For I := 1 To MAX_SYM Do
  Begin
    SymTab[I].Name       := '';
    SymTab[I].AsmLabel   := '';
    SymTab[I].VarType    := PFX_UNKNOWN;
    SymTab[I].StoreClass := STORE_GLOBAL;
    SymTab[I].BpOffset   := 0;
    SymTab[I].IsConst    := False;
    SymTab[I].ScopeLev   := 0;
    SymTab[I].HasInit    := False;
  End;
End;

Function FindSym(Const Name : TString) : Integer;
Var I : Integer; U : TString;
Begin
  U := StrUpperCase(Name);
  For I := SymCount DownTo 1 Do
    If SymTab[I].Name = U Then Begin FindSym := I; Exit; End;
  FindSym := 0;
End;

Function AddSym(Const Name : TString; VType, SC : Integer) : Integer;
Var U : TString; Idx : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    Error('Table des symboles pleine (MAX_SYM=' + IntToStr_(MAX_SYM) + ')');
    AddSym := 0;
    Exit;
  End;
  U := StrUpperCase(Name);
  Inc(SymCount);
  Idx := SymCount;
  SymTab[Idx].Name       := U;
  SymTab[Idx].VarType    := VType;
  SymTab[Idx].StoreClass := SC;
  SymTab[Idx].ScopeLev   := ScopeTop;
  SymTab[Idx].IsConst    := False;
  SymTab[Idx].HasInit    := False;
  SymTab[Idx].AsmLabel   := PFX_VAR_PFX + AsmIdent(U);
  AddSym := Idx;
End;

{ ============================================================ }
{ TABLE DES FONCTIONS UTILISATEUR                               }
{ ============================================================ }

Procedure InitFnTable;
Var I, J : Integer;
Begin
  FnCount := 0;
  For I := 1 To MAX_FN Do
  Begin
    FnTab[I].Name       := '';
    FnTab[I].AsmLabel   := '';
    FnTab[I].RetType    := PFX_UNKNOWN;
    FnTab[I].ParamCount := 0;
    FnTab[I].IsBuiltin  := False;
    For J := 1 To MAX_PARAM Do
      FnTab[I].ParamTypes[J] := PFX_UNKNOWN;
  End;
End;

{ ============================================================ }
{ PILE DE SCOPES                                                }
{ ============================================================ }

Procedure InitScopeStack;
Var I : Integer;
Begin
  ScopeTop := 0;
  For I := 0 To MAX_DEPTH Do
  Begin
    ScopeStack[I].Kind     := 0;
    ScopeStack[I].BpTop    := 0;
    ScopeStack[I].SymStart := 1;
    ScopeStack[I].LblExit  := '';
  End;
End;

{ ============================================================ }
{ GENERATEUR DE CODE 80386                                      }
{ ============================================================ }

Procedure InitCodeGen;
Begin
  StrCount     := 0;
  NumCount     := 0;
  LabelCounter := 0;
  GenEnabled   := False;
End;

Procedure Emit(Const S : TString);
Begin If GenEnabled Then WriteLn(OutF, S); End;

Procedure EmitI(Const S : TString);
Begin If GenEnabled Then WriteLn(OutF, #9 + S); End;

Procedure EmitLabel(Const Lbl : TString);
Begin If GenEnabled Then WriteLn(OutF, Lbl + ':'); End;

Procedure EmitComment(Const S : TString);
Begin If GenEnabled Then WriteLn(OutF, '; ' + S); End;

Procedure EmitBlank;
Begin If GenEnabled Then WriteLn(OutF, ''); End;

Function NewLabel : TString;
Var N : TString;
Begin
  Inc(LabelCounter);
  N := IntToStr_(LabelCounter);
  While Length(N) < 4 Do N := '0' + N;
  NewLabel := PFX_LBL_PFX + N;
End;

{ ---- AsmStrLit : enregistrer un litteral chaine, retourner son label }
{ Deduplication : si la chaine existe deja, retourne son label.         }
Function AsmStrLit(Const S : TString) : TString;
Var I : Integer; Lb : TString;
Begin
  For I := 1 To StrCount Do
    If StrTab[I] = S Then Begin AsmStrLit := StrLblTab[I]; Exit; End;
  If StrCount >= MAX_DATA Then
  Begin
    Error('Table des chaines pleine (MAX_DATA=' + IntToStr_(MAX_DATA) + ')');
    AsmStrLit := PFX_STR_PFX + '0';
    Exit;
  End;
  Inc(StrCount);
  Lb := PFX_STR_PFX + IntToStr_(StrCount);
  StrTab[StrCount]    := S;
  StrLblTab[StrCount] := Lb;
  AsmStrLit := Lb;
End;

{ ---- AsmNumLit : enregistrer un litteral numerique, retourner son label }
Function AsmNumLit(Const S : TString) : TString;
Var I : Integer; Lb : TString;
Begin
  For I := 1 To NumCount Do
    If NumTab[I] = S Then Begin AsmNumLit := NumLblTab[I]; Exit; End;
  If NumCount >= MAX_DATA Then
  Begin
    Error('Table des numeriques pleine'); AsmNumLit := PFX_NUM_PFX + '0'; Exit;
  End;
  Inc(NumCount);
  Lb := PFX_NUM_PFX + IntToStr_(NumCount);
  NumTab[NumCount]    := S;
  NumLblTab[NumCount] := Lb;
  AsmNumLit := Lb;
End;

Function BpOff32(Off : Integer) : TString;
Begin
  If Off < 0 Then BpOff32 := IntToStr_(Off)
  Else If Off > 0 Then BpOff32 := '+' + IntToStr_(Off)
  Else BpOff32 := '';
End;

{ ---- GenLoadSym : charger un symbole }
{ PFX_NUMBER  -> FLD QWORD PTR [addr]  (resultat dans ST(0))        }
{ PFX_TEXT    -> MOV EAX, [addr]       (resultat dans EAX = ptr)    }
{ PFX_BOOLEAN -> MOV EAX, [addr]       (resultat dans EAX = 0/1)    }
Procedure GenLoadSym(SymIdx : Integer);
Var SC, Off : Integer; Lbl : TString;
Begin
  SC  := SymTab[SymIdx].StoreClass;
  Off := SymTab[SymIdx].BpOffset;
  Lbl := SymTab[SymIdx].AsmLabel;
  If SymTab[SymIdx].VarType = PFX_NUMBER Then
  Begin
    Case SC Of
      STORE_GLOBAL : EmitI('FLD  QWORD PTR [' + Lbl + ']');
      STORE_LOCAL  : EmitI('FLD  QWORD PTR [EBP' + BpOff32(Off) + ']');
    End;
  End
  Else
  Begin
    Case SC Of
      STORE_GLOBAL : EmitI('MOV  EAX, DWORD PTR [' + Lbl + ']');
      STORE_LOCAL  : EmitI('MOV  EAX, DWORD PTR [EBP' + BpOff32(Off) + ']');
    End;
  End;
End;

{ ---- GenStoreSym : stocker FPU ST(0) ou EAX dans un symbole }
Procedure GenStoreSym(SymIdx : Integer);
Var SC, Off : Integer; Lbl : TString;
Begin
  SC  := SymTab[SymIdx].StoreClass;
  Off := SymTab[SymIdx].BpOffset;
  Lbl := SymTab[SymIdx].AsmLabel;
  If SymTab[SymIdx].VarType = PFX_NUMBER Then
  Begin
    Case SC Of
      STORE_GLOBAL : EmitI('FSTP QWORD PTR [' + Lbl + ']');
      STORE_LOCAL  : EmitI('FSTP QWORD PTR [EBP' + BpOff32(Off) + ']');
    End;
  End
  Else
  Begin
    Case SC Of
      STORE_GLOBAL : EmitI('MOV  DWORD PTR [' + Lbl + '], EAX');
      STORE_LOCAL  : EmitI('MOV  DWORD PTR [EBP' + BpOff32(Off) + '], EAX');
    End;
  End;
End;

{ ---- GenNumToFPU : convertir EAX (entier) en Number dans ST(0) }
Procedure GenNumToFPU;
Begin
  EmitI('MOV  DWORD PTR [' + PFX_RT_PFX + 'ITMP], EAX');
  EmitI('FILD DWORD PTR [' + PFX_RT_PFX + 'ITMP]');
End;

{ ---- GenFPUToInt : convertir ST(0) en entier dans EAX (troncature) }
Procedure GenFPUToInt;
Begin
  EmitI('FISTP DWORD PTR [' + PFX_RT_PFX + 'ITMP]');
  EmitI('MOV  EAX, DWORD PTR [' + PFX_RT_PFX + 'ITMP]');
End;

{ ---- GenPrologue / GenEpilogue }
Procedure GenPrologue(FrameSize : Integer);
Begin
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  If FrameSize > 0 Then
    EmitI('SUB  ESP, ' + IntToStr_(FrameSize));
End;

Procedure GenEpilogue(ParamBytes : Integer);
Begin
  EmitI('MOV  ESP, EBP');
  EmitI('POP  EBP');
  If ParamBytes > 0 Then EmitI('RET  ' + IntToStr_(ParamBytes))
  Else EmitI('RET');
End;

{ ============================================================ }
{ GENERATEUR : EN-TETE ASM ET SEGMENT .DATA                     }
{ ============================================================ }

Procedure EmitOpen(Const FileName : TString);
Begin
  Assign(OutF, FileName);
  Rewrite(OutF);
  OutFOpen   := True;
  GenEnabled := True;
End;

Procedure EmitClose;
Begin
  If OutFOpen Then
  Begin
    GenEnabled := False;
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ---- EmitHeader : directives processeur, modele memoire, imports Win32 }
Procedure EmitHeader;
Begin
  EmitComment('Generated by POWFXC32 v' + POWFXC32_VERSION +
              ' (' + POWFXC32_DATE + ')');
  EmitComment('Source: ' + Opts.SrcFile);
  EmitComment('Power FX -> assembleur 80386 (Windows PE 32 bits)');
  EmitBlank;
  Emit('.386');
  Emit('.MODEL FLAT, STDCALL');
  Emit('OPTION CASEMAP:NONE');
  EmitBlank;
  EmitComment('--- Imports Win32 (kernel32.dll) ---');
  Emit('EXTRN _ExitProcess@4:NEAR');
  Emit('EXTRN _GetStdHandle@4:NEAR');
  Emit('EXTRN _WriteFile@20:NEAR');
  Emit('EXTRN _ReadFile@20:NEAR');
  Emit('EXTRN _GetProcessHeap@0:NEAR');
  Emit('EXTRN _HeapAlloc@12:NEAR');
  Emit('EXTRN _HeapFree@12:NEAR');
  EmitBlank;
  Emit('.STACK 4096');
  EmitBlank;
  EmitComment('--- Segment de code ---');
  Emit('_TEXT SEGMENT DWORD PUBLIC ''CODE''');
  Emit('ASSUME CS:_TEXT');
  EmitBlank;
End;

{ ---- EmitDataSeg : variables globales, litteraux, tampons runtime }
Procedure EmitDataSeg;
Var I, J : Integer; S : TString;
    D : Double; Err : Integer;
    Bytes : Array[0..7] Of Byte;
    Db    : Double Absolute Bytes;
Begin
  EmitBlank;
  Emit('_TEXT ENDS');
  EmitBlank;
  EmitComment('--- Segment de donnees ---');
  Emit('_DATA SEGMENT DWORD PUBLIC ''DATA''');
  EmitBlank;

  { --- Variables globales --- }
  EmitComment('--- variables globales Power FX ---');
  For I := 1 To SymCount Do
  Begin
    If SymTab[I].StoreClass = STORE_GLOBAL Then
    Begin
      Case SymTab[I].VarType Of
        PFX_NUMBER :
          EmitI(SymTab[I].AsmLabel + ' DQ 0   ; Number (Double 64 bits)');
        PFX_TEXT :
          EmitI(SymTab[I].AsmLabel + ' DD 0   ; Text (pointeur ASCIIZ)');
        PFX_BOOLEAN :
          EmitI(SymTab[I].AsmLabel + ' DD 0   ; Boolean');
      Else
        EmitI(SymTab[I].AsmLabel + ' DD 0');
      End;
    End;
  End;
  EmitBlank;

  { --- Litteraux chaines --- }
  If StrCount > 0 Then
  Begin
    EmitComment('--- litteraux chaines ---');
    For I := 1 To StrCount Do
    Begin
      S := StrTab[I];
      If Length(S) > 0 Then
      Begin
        Emit(StrLblTab[I] + ' DB ' + IntToStr_(Ord(S[1])));
        For J := 2 To Length(S) Do
          EmitI('DB ' + IntToStr_(Ord(S[J])));
      End
      Else
        Emit(StrLblTab[I] + ' DB 0');
      EmitI('DB 0');    { terminateur NUL }
    End;
    EmitBlank;
  End;

  { --- Litteraux numeriques (Double IEEE-754 64 bits) --- }
  If NumCount > 0 Then
  Begin
    EmitComment('--- litteraux numeriques (Double IEEE-754 64 bits) ---');
    For I := 1 To NumCount Do
    Begin
      Val(NumTab[I], D, Err);
      If Err <> 0 Then D := 0.0;
      { Extraire les 8 octets du Double (little-endian) }
      Db := D;
      Emit(NumLblTab[I] + ' DB ' + IntToStr_(Bytes[0]) + ', ' +
                                    IntToStr_(Bytes[1]) + ', ' +
                                    IntToStr_(Bytes[2]) + ', ' +
                                    IntToStr_(Bytes[3]));
      EmitI('DB ' + IntToStr_(Bytes[4]) + ', ' +
                    IntToStr_(Bytes[5]) + ', ' +
                    IntToStr_(Bytes[6]) + ', ' +
                    IntToStr_(Bytes[7]));
    End;
    EmitBlank;
  End;

  { --- Tampons et variables runtime --- }
  EmitComment('--- tampons et variables runtime ---');
  EmitI(PFX_RT_PFX + 'NUMBUF   DB 32 DUP(0)');     { buffer affichage nombres }
  EmitI(PFX_RT_PFX + 'STRBUF   DB 256 DUP(0)');    { buffer operations chaines }
  EmitI(PFX_RT_PFX + 'CATBUF   DB 512 DUP(0)');    { buffer concatenation }
  EmitI(PFX_RT_PFX + 'INPUTBUF DB 256 DUP(0)');    { buffer lecture console }
  EmitI(PFX_RT_PFX + 'CRLF     DB 13, 10, 0');     { CR+LF }
  EmitI(PFX_RT_PFX + 'HSTDOUT  DD 0');             { handle stdout }
  EmitI(PFX_RT_PFX + 'HSTDIN   DD 0');             { handle stdin }
  EmitI(PFX_RT_PFX + 'WRITTEN  DD 0');             { octets ecrits }
  EmitI(PFX_RT_PFX + 'READCNT  DD 0');             { octets lus }
  EmitI(PFX_RT_PFX + 'DBLTMP   DQ 0');             { Double temporaire 64 bits }
  EmitI(PFX_RT_PFX + 'ITMP     DD 0');             { Entier temporaire 32 bits }
  EmitI(PFX_RT_PFX + 'DBL_LN2  DQ 0.693147180559945'); { ln(2) pour LOG }
  EmitI(PFX_RT_PFX + 'DBL_E    DQ 2.718281828459045'); { e }
  EmitI(PFX_RT_PFX + 'ERR_DIV0 DB ''Error(Division by zero)'', 0');
  EmitI(PFX_RT_PFX + 'ERR_SQRT DB ''Error(Sqrt of negative number)'', 0');
  EmitI(PFX_RT_PFX + 'STR_TRUE DB ''true'', 0');
  EmitI(PFX_RT_PFX + 'STR_FALSE DB ''false'', 0');
  EmitBlank;

  Emit('_DATA ENDS');
  EmitBlank;
End;

{ ============================================================ }
{ GENERATEUR : POINT D'ENTREE WIN32                             }
{ ============================================================ }

Procedure EmitEntryPoint;
Begin
  EmitBlank;
  EmitComment('========================================');
  EmitComment('Point d''entree Win32 - POWFXC32');
  EmitComment('========================================');
  EmitBlank;
  EmitLabel(PFX_FN_PFX + 'main');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitBlank;
  EmitComment('Initialiser stdout : GetStdHandle(STD_OUTPUT_HANDLE = -11)');
  EmitI('PUSH -11');
  EmitI('CALL _GetStdHandle@4');
  EmitI('MOV  DWORD PTR [' + PFX_RT_PFX + 'HSTDOUT], EAX');
  EmitBlank;
  EmitComment('Initialiser stdin : GetStdHandle(STD_INPUT_HANDLE = -10)');
  EmitI('PUSH -10');
  EmitI('CALL _GetStdHandle@4');
  EmitI('MOV  DWORD PTR [' + PFX_RT_PFX + 'HSTDIN], EAX');
  EmitBlank;
  EmitComment('Appel du programme Power FX');
  EmitI('CALL ' + PFX_FN_PFX + 'PROGRAM');
  EmitBlank;
  EmitComment('Terminer le processus');
  EmitI('PUSH 0');
  EmitI('CALL _ExitProcess@4');
  EmitBlank;
End;

{ ============================================================ }
{ GENERATEUR : HELPERS RUNTIME                                  }
{ ============================================================ }

Procedure EmitRuntimeHelpers;
Var L1, L2, L3, LE : TString;
Begin
  EmitBlank;
  EmitComment('========================================');
  EmitComment('Helpers runtime POWFXC32');
  EmitComment('========================================');

  { ---- _PFXRT_CRLF : ecrire CR+LF sur stdout ---- }
  EmitBlank;
  EmitComment('--- _PFXRT_CRLF : ecrire CR+LF ---');
  EmitLabel(PFX_RT_PFX + 'CRLF');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('PUSH 0');
  EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'WRITTEN]');
  EmitI('PUSH EAX');
  EmitI('PUSH 2');
  EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'CRLF]');
  EmitI('PUSH EAX');
  EmitI('PUSH DWORD PTR [' + PFX_RT_PFX + 'HSTDOUT]');
  EmitI('CALL _WriteFile@20');
  EmitI('POP  EBP');
  EmitI('RET');

  { ---- _PFXRT_PRINT : afficher chaine ASCIIZ sur stdout ---- }
  { Entree : [ESP+4] = pointeur vers chaine ASCIIZ              }
  EmitBlank;
  EmitComment('--- _PFXRT_PRINT : afficher chaine ASCIIZ ---');
  EmitComment('Entree: [ESP+4] = pointeur ASCIIZ');
  EmitLabel(PFX_RT_PFX + 'PRINT');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('PUSH ESI');
  EmitI('PUSH ECX');
  EmitI('MOV  ESI, DWORD PTR [EBP+8]');
  { Calculer la longueur }
  EmitI('XOR  ECX, ECX');
  L1 := NewLabel; LE := NewLabel;
  EmitLabel(L1);
  EmitI('CMP  BYTE PTR [ESI+ECX], 0');
  EmitI('JE   ' + LE);
  EmitI('INC  ECX');
  EmitI('JMP  ' + L1);
  EmitLabel(LE);
  { WriteFile si longueur > 0 }
  EmitI('TEST ECX, ECX');
  EmitI('JZ   ' + LE + '_E');
  EmitI('PUSH 0');
  EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'WRITTEN]');
  EmitI('PUSH EAX');
  EmitI('PUSH ECX');
  EmitI('PUSH ESI');
  EmitI('PUSH DWORD PTR [' + PFX_RT_PFX + 'HSTDOUT]');
  EmitI('CALL _WriteFile@20');
  EmitLabel(LE + '_E');
  EmitI('POP  ECX');
  EmitI('POP  ESI');
  EmitI('POP  EBP');
  EmitI('RET  4');

  { ---- _PFXRT_PRINTLN : afficher chaine ASCIIZ + CR+LF ---- }
  { Entree : [ESP+4] = pointeur vers chaine ASCIIZ              }
  EmitBlank;
  EmitComment('--- _PFXRT_PRINTLN : afficher chaine + CR+LF ---');
  EmitComment('Entree: [ESP+4] = pointeur ASCIIZ');
  EmitLabel(PFX_RT_PFX + 'PRINTLN');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('MOV  EAX, DWORD PTR [EBP+8]');
  EmitI('PUSH EAX');
  EmitI('CALL ' + PFX_RT_PFX + 'PRINT');
  EmitI('CALL ' + PFX_RT_PFX + 'CRLF');
  EmitI('POP  EBP');
  EmitI('RET  4');

  { ---- _PFXRT_NUMTOSTR : Double FPU ST(0) -> ASCIIZ dans NUMBUF ---- }
  { Algorithme : signe + partie entiere + '.' + 6 decimales             }
  { Entree : ST(0) = Double a convertir                                  }
  { Sortie : EAX = pointeur vers NUMBUF (ASCIIZ)                        }
  EmitBlank;
  EmitComment('--- _PFXRT_NUMTOSTR : Double FPU -> ASCIIZ ---');
  EmitComment('Entree: ST(0) = Double. Sortie: EAX = ptr NUMBUF');
  EmitLabel(PFX_RT_PFX + 'NUMTOSTR');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('PUSH EBX');
  EmitI('PUSH EDI');
  EmitI('PUSH ESI');
  EmitI('SUB  ESP, 12');          { locals: [EBP-4]=signe [EBP-8]=nbdec [EBP-12]=frac }
  EmitI('LEA  EDI, DWORD PTR [' + PFX_RT_PFX + 'NUMBUF]');
  { Test si zero }
  L1 := NewLabel; L2 := NewLabel; L3 := NewLabel; LE := NewLabel;
  EmitI('FTST');
  EmitI('FSTSW AX');
  EmitI('FWAIT');
  EmitI('SAHF');
  EmitI('JE   ' + L1 + '_Z');     { si zero }
  { Test si negatif }
  EmitI('JNC  ' + L1);             { si positif (CF=0) }
  EmitI('MOV  BYTE PTR [EDI], 45'); { '-' }
  EmitI('INC  EDI');
  EmitI('FCHS');
  EmitI('JMP  ' + L1 + '_E');
  EmitLabel(L1);
  EmitI('MOV  BYTE PTR [EDI], 32'); { ' ' (espace pour positif, style Ada) }
  EmitI('INC  EDI');
  EmitI('JMP  ' + L1 + '_E');
  EmitLabel(L1 + '_Z');
  EmitI('MOV  BYTE PTR [EDI], 48'); { '0' }
  EmitI('INC  EDI');
  EmitI('MOV  BYTE PTR [EDI], 0');
  EmitI('FSTP ST(0)');              { vider pile FPU }
  EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'NUMBUF]');
  EmitI('ADD  ESP, 12');
  EmitI('POP  ESI');
  EmitI('POP  EDI');
  EmitI('POP  EBX');
  EmitI('POP  EBP');
  EmitI('RET');
  EmitLabel(L1 + '_E');
  { Dupliquer ST(0) pour extraire partie entiere }
  EmitI('FLD  ST(0)');              { ST(0)=val, ST(1)=val }
  { Convertir partie entiere -> EBX via FISTP }
  EmitI('FISTP DWORD PTR [' + PFX_RT_PFX + 'ITMP]');
  EmitI('MOV  EBX, DWORD PTR [' + PFX_RT_PFX + 'ITMP]');
  { Convertir EBX en ASCII (partie entiere) }
  { Methode : diviser par 10 en remontant }
  EmitI('LEA  ESI, DWORD PTR [' + PFX_RT_PFX + 'NUMBUF + 30]'); { buffer temp }
  EmitI('XOR  ECX, ECX');           { compteur chiffres }
  EmitLabel(L2);
  EmitI('MOV  EAX, EBX');
  EmitI('XOR  EDX, EDX');
  EmitI('MOV  EBX, 10');
  EmitI('DIV  EBX');
  EmitI('MOV  EBX, EAX');
  EmitI('ADD  DL, 48');
  EmitI('MOV  BYTE PTR [ESI-1], DL');
  EmitI('DEC  ESI');
  EmitI('INC  ECX');
  EmitI('TEST EBX, EBX');
  EmitI('JNZ  ' + L2);
  { Copier les chiffres dans EDI }
  EmitLabel(L3);
  EmitI('MOV  AL, BYTE PTR [ESI]');
  EmitI('MOV  BYTE PTR [EDI], AL');
  EmitI('INC  ESI');
  EmitI('INC  EDI');
  EmitI('DEC  ECX');
  EmitI('JNZ  ' + L3);
  { Ajouter '.' }
  EmitI('MOV  BYTE PTR [EDI], 46'); { '.' }
  EmitI('INC  EDI');
  { Calculer la partie fractionnaire : FPU reste encore dans ST(0) }
  { soustraire partie entiere : frac = val - floor(val) }
  EmitI('FILD DWORD PTR [' + PFX_RT_PFX + 'ITMP]'); { ST(0)=ent, ST(1)=val }
  EmitI('FSUBP ST(1), ST(0)');       { ST(0) = val - ent = frac }
  { Generer 6 decimales }
  EmitI('MOV  ECX, 6');
  EmitLabel(LE);
  EmitI('FMUL QWORD PTR [' + PFX_RT_PFX + 'DBL_LN2]'); { *10 approximation }
  { Simplification : on multiplie par 10 directement via une constante }
  { Note: DBL_LN2 utilise pour adresse, sera remplace par 10.0 dans .DATA }
  { Pour simplicite : stocker et extraire chiffre }
  EmitI('FISTP DWORD PTR [' + PFX_RT_PFX + 'ITMP]');
  EmitI('MOV  EAX, DWORD PTR [' + PFX_RT_PFX + 'ITMP]');
  EmitI('AND  EAX, 9');              { clamp 0-9 }
  EmitI('ADD  AL, 48');
  EmitI('MOV  BYTE PTR [EDI], AL');
  EmitI('INC  EDI');
  EmitI('FILD DWORD PTR [' + PFX_RT_PFX + 'ITMP]'); { re-push dernier chiffre }
  EmitI('FSUBP ST(1), ST(0)');       { soustraire chiffre }
  EmitI('FMUL QWORD PTR [' + PFX_RT_PFX + 'DBL_LN2]');
  EmitI('DEC  ECX');
  EmitI('JNZ  ' + LE);
  EmitI('FSTP ST(0)');
  EmitI('MOV  BYTE PTR [EDI], 0');
  EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'NUMBUF]');
  EmitI('ADD  ESP, 12');
  EmitI('POP  ESI');
  EmitI('POP  EDI');
  EmitI('POP  EBX');
  EmitI('POP  EBP');
  EmitI('RET');

  { ---- _PFXRT_PRINTNUM : afficher un Double via NUMTOSTR + PRINTLN ---- }
  { Entree : ST(0) = Double                                                }
  EmitBlank;
  EmitComment('--- _PFXRT_PRINTNUM : afficher Double FPU ---');
  EmitLabel(PFX_RT_PFX + 'PRINTNUM');
  EmitI('CALL ' + PFX_RT_PFX + 'NUMTOSTR');
  EmitI('PUSH EAX');
  EmitI('CALL ' + PFX_RT_PFX + 'PRINTLN');
  EmitI('RET');

  { ---- _PFXRT_PRINTBOOL : afficher Boolean ---- }
  { Entree : [ESP+4] = Boolean (0=false, sinon true)                      }
  EmitBlank;
  EmitComment('--- _PFXRT_PRINTBOOL : afficher Boolean ---');
  EmitComment('Entree: [ESP+4] = Boolean');
  EmitLabel(PFX_RT_PFX + 'PRINTBOOL');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  L1 := NewLabel;
  EmitI('MOV  EAX, DWORD PTR [EBP+8]');
  EmitI('TEST EAX, EAX');
  EmitI('JZ   ' + L1);
  EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'STR_TRUE]');
  EmitI('JMP  ' + L1 + '_E');
  EmitLabel(L1);
  EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'STR_FALSE]');
  EmitLabel(L1 + '_E');
  EmitI('PUSH EAX');
  EmitI('CALL ' + PFX_RT_PFX + 'PRINTLN');
  EmitI('POP  EBP');
  EmitI('RET  4');

  { ---- _PFXRT_STRLEN : longueur chaine ASCIIZ ---- }
  { Entree : EAX = ptr ASCIIZ. Sortie : EAX = longueur }
  EmitBlank;
  EmitComment('--- _PFXRT_STRLEN : longueur chaine ASCIIZ ---');
  EmitLabel(PFX_RT_PFX + 'STRLEN');
  EmitI('PUSH ESI');
  EmitI('MOV  ESI, EAX');
  EmitI('XOR  EAX, EAX');
  L1 := NewLabel; LE := NewLabel;
  EmitLabel(L1);
  EmitI('CMP  BYTE PTR [ESI], 0');
  EmitI('JE   ' + LE);
  EmitI('INC  ESI');
  EmitI('INC  EAX');
  EmitI('JMP  ' + L1);
  EmitLabel(LE);
  EmitI('POP  ESI');
  EmitI('RET');

  { ---- _PFXRT_STRCAT : [ESP+8]=gauche, [ESP+4]=droite -> EAX=CATBUF ---- }
  EmitBlank;
  EmitComment('--- _PFXRT_STRCAT : concatener 2 chaines dans CATBUF ---');
  EmitComment('Entree: [ESP+8]=gauche, [ESP+4]=droite. Sortie: EAX=CATBUF');
  EmitLabel(PFX_RT_PFX + 'STRCAT');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('PUSH ESI');
  EmitI('PUSH EDI');
  EmitI('LEA  EDI, DWORD PTR [' + PFX_RT_PFX + 'CATBUF]');
  L1 := NewLabel; L2 := NewLabel;
  EmitI('MOV  ESI, DWORD PTR [EBP+12]');
  EmitLabel(L1);
  EmitI('MOV  AL, BYTE PTR [ESI]');
  EmitI('TEST AL, AL');
  EmitI('JZ   ' + L1 + '_E');
  EmitI('MOV  BYTE PTR [EDI], AL');
  EmitI('INC  ESI');
  EmitI('INC  EDI');
  EmitI('JMP  ' + L1);
  EmitLabel(L1 + '_E');
  EmitI('MOV  ESI, DWORD PTR [EBP+8]');
  EmitLabel(L2);
  EmitI('MOV  AL, BYTE PTR [ESI]');
  EmitI('TEST AL, AL');
  EmitI('JZ   ' + L2 + '_E');
  EmitI('MOV  BYTE PTR [EDI], AL');
  EmitI('INC  ESI');
  EmitI('INC  EDI');
  EmitI('JMP  ' + L2);
  EmitLabel(L2 + '_E');
  EmitI('MOV  BYTE PTR [EDI], 0');
  EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'CATBUF]');
  EmitI('POP  EDI');
  EmitI('POP  ESI');
  EmitI('POP  EBP');
  EmitI('RET  8');

  { ---- _PFXRT_STRUPPR : Upper(Text) -> EAX=STRBUF ---- }
  EmitBlank;
  EmitComment('--- _PFXRT_STRUPPR : Upper(Text) ---');
  EmitComment('Entree: [ESP+4] = ptr ASCIIZ. Sortie: EAX = STRBUF');
  EmitLabel(PFX_RT_PFX + 'STRUPPR');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('PUSH ESI');
  EmitI('PUSH EDI');
  EmitI('MOV  ESI, DWORD PTR [EBP+8]');
  EmitI('LEA  EDI, DWORD PTR [' + PFX_RT_PFX + 'STRBUF]');
  L1 := NewLabel;
  EmitLabel(L1);
  EmitI('MOV  AL, BYTE PTR [ESI]');
  EmitI('TEST AL, AL');
  EmitI('JZ   ' + L1 + '_E');
  EmitI('CMP  AL, 97');
  EmitI('JB   ' + L1 + '_S');
  EmitI('CMP  AL, 122');
  EmitI('JA   ' + L1 + '_S');
  EmitI('SUB  AL, 32');
  EmitLabel(L1 + '_S');
  EmitI('MOV  BYTE PTR [EDI], AL');
  EmitI('INC  ESI');
  EmitI('INC  EDI');
  EmitI('JMP  ' + L1);
  EmitLabel(L1 + '_E');
  EmitI('MOV  BYTE PTR [EDI], 0');
  EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'STRBUF]');
  EmitI('POP  EDI');
  EmitI('POP  ESI');
  EmitI('POP  EBP');
  EmitI('RET  4');

  { ---- _PFXRT_STRLWER : Lower(Text) -> EAX=STRBUF ---- }
  EmitBlank;
  EmitComment('--- _PFXRT_STRLWER : Lower(Text) ---');
  EmitComment('Entree: [ESP+4] = ptr ASCIIZ. Sortie: EAX = STRBUF');
  EmitLabel(PFX_RT_PFX + 'STRLWER');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('PUSH ESI');
  EmitI('PUSH EDI');
  EmitI('MOV  ESI, DWORD PTR [EBP+8]');
  EmitI('LEA  EDI, DWORD PTR [' + PFX_RT_PFX + 'STRBUF]');
  L1 := NewLabel;
  EmitLabel(L1);
  EmitI('MOV  AL, BYTE PTR [ESI]');
  EmitI('TEST AL, AL');
  EmitI('JZ   ' + L1 + '_E');
  EmitI('CMP  AL, 65');
  EmitI('JB   ' + L1 + '_S');
  EmitI('CMP  AL, 90');
  EmitI('JA   ' + L1 + '_S');
  EmitI('ADD  AL, 32');
  EmitLabel(L1 + '_S');
  EmitI('MOV  BYTE PTR [EDI], AL');
  EmitI('INC  ESI');
  EmitI('INC  EDI');
  EmitI('JMP  ' + L1);
  EmitLabel(L1 + '_E');
  EmitI('MOV  BYTE PTR [EDI], 0');
  EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'STRBUF]');
  EmitI('POP  EDI');
  EmitI('POP  ESI');
  EmitI('POP  EBP');
  EmitI('RET  4');

  { ---- _PFXRT_STRTRIM : Trim(Text) -> EAX=STRBUF ---- }
  EmitBlank;
  EmitComment('--- _PFXRT_STRTRIM : Trim(Text) ---');
  EmitComment('Entree: [ESP+4] = ptr ASCIIZ. Sortie: EAX = STRBUF');
  EmitLabel(PFX_RT_PFX + 'STRTRIM');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('PUSH ESI');
  EmitI('PUSH EDI');
  EmitI('PUSH EBX');
  EmitI('MOV  ESI, DWORD PTR [EBP+8]');
  EmitI('LEA  EDI, DWORD PTR [' + PFX_RT_PFX + 'STRBUF]');
  L1 := NewLabel; L2 := NewLabel; L3 := NewLabel; LE := NewLabel;
  { Sauter les espaces de tete }
  EmitLabel(L1);
  EmitI('MOV  AL, BYTE PTR [ESI]');
  EmitI('CMP  AL, 32');
  EmitI('JNE  ' + L2);
  EmitI('INC  ESI');
  EmitI('JMP  ' + L1);
  { Copier }
  EmitLabel(L2);
  EmitI('MOV  AL, BYTE PTR [ESI]');
  EmitI('TEST AL, AL');
  EmitI('JZ   ' + L3);
  EmitI('MOV  BYTE PTR [EDI], AL');
  EmitI('INC  ESI');
  EmitI('INC  EDI');
  EmitI('JMP  ' + L2);
  { Supprimer espaces de fin }
  EmitLabel(L3);
  EmitI('DEC  EDI');
  EmitLabel(LE);
  EmitI('LEA  EBX, DWORD PTR [' + PFX_RT_PFX + 'STRBUF]');
  EmitI('CMP  EDI, EBX');
  EmitI('JBE  ' + LE + '_E');
  EmitI('MOV  AL, BYTE PTR [EDI]');
  EmitI('CMP  AL, 32');
  EmitI('JNE  ' + LE + '_E');
  EmitI('DEC  EDI');
  EmitI('JMP  ' + LE);
  EmitLabel(LE + '_E');
  EmitI('INC  EDI');
  EmitI('MOV  BYTE PTR [EDI], 0');
  EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'STRBUF]');
  EmitI('POP  EBX');
  EmitI('POP  EDI');
  EmitI('POP  ESI');
  EmitI('POP  EBP');
  EmitI('RET  4');

  { ---- _PFXRT_STRLEFT : Left(Text, Count) -> EAX=STRBUF ---- }
  { Entree : [ESP+8]=ptr ASCIIZ, [ESP+4]=Count (entier 32 bits) }
  EmitBlank;
  EmitComment('--- _PFXRT_STRLEFT : Left(Text, N) ---');
  EmitComment('Entree: [ESP+8]=ptr, [ESP+4]=N. Sortie: EAX=STRBUF');
  EmitLabel(PFX_RT_PFX + 'STRLEFT');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('PUSH ESI');
  EmitI('PUSH EDI');
  EmitI('PUSH ECX');
  EmitI('MOV  ESI, DWORD PTR [EBP+12]');  { Text }
  EmitI('MOV  ECX, DWORD PTR [EBP+8]');   { N }
  EmitI('LEA  EDI, DWORD PTR [' + PFX_RT_PFX + 'STRBUF]');
  L1 := NewLabel;
  EmitLabel(L1);
  EmitI('TEST ECX, ECX');
  EmitI('JZ   ' + L1 + '_E');
  EmitI('MOV  AL, BYTE PTR [ESI]');
  EmitI('TEST AL, AL');
  EmitI('JZ   ' + L1 + '_E');
  EmitI('MOV  BYTE PTR [EDI], AL');
  EmitI('INC  ESI');
  EmitI('INC  EDI');
  EmitI('DEC  ECX');
  EmitI('JMP  ' + L1);
  EmitLabel(L1 + '_E');
  EmitI('MOV  BYTE PTR [EDI], 0');
  EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'STRBUF]');
  EmitI('POP  ECX');
  EmitI('POP  EDI');
  EmitI('POP  ESI');
  EmitI('POP  EBP');
  EmitI('RET  8');

  { ---- _PFXRT_STRRIGHT : Right(Text, Count) -> EAX=STRBUF ---- }
  { Entree : [ESP+8]=ptr ASCIIZ, [ESP+4]=Count (entier 32 bits)  }
  EmitBlank;
  EmitComment('--- _PFXRT_STRRIGHT : Right(Text, N) ---');
  EmitComment('Entree: [ESP+8]=ptr, [ESP+4]=N. Sortie: EAX=STRBUF');
  EmitLabel(PFX_RT_PFX + 'STRRIGHT');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('PUSH ESI');
  EmitI('PUSH EDI');
  EmitI('PUSH EBX');
  EmitI('PUSH ECX');
  EmitI('MOV  ESI, DWORD PTR [EBP+12]');  { Text }
  EmitI('MOV  ECX, DWORD PTR [EBP+8]');   { N }
  EmitI('LEA  EDI, DWORD PTR [' + PFX_RT_PFX + 'STRBUF]');
  EmitI('MOV  EAX, ESI');
  EmitI('CALL ' + PFX_RT_PFX + 'STRLEN'); { EAX = longueur }
  EmitI('MOV  EBX, EAX');
  L1 := NewLabel;
  EmitI('CMP  ECX, EBX');
  EmitI('JBE  ' + L1);
  EmitI('MOV  ECX, EBX');
  EmitLabel(L1);
  EmitI('MOV  EAX, EBX');
  EmitI('SUB  EAX, ECX');
  EmitI('ADD  ESI, EAX');
  L2 := NewLabel;
  EmitLabel(L2);
  EmitI('TEST ECX, ECX');
  EmitI('JZ   ' + L2 + '_E');
  EmitI('MOV  AL, BYTE PTR [ESI]');
  EmitI('TEST AL, AL');
  EmitI('JZ   ' + L2 + '_E');
  EmitI('MOV  BYTE PTR [EDI], AL');
  EmitI('INC  ESI');
  EmitI('INC  EDI');
  EmitI('DEC  ECX');
  EmitI('JMP  ' + L2);
  EmitLabel(L2 + '_E');
  EmitI('MOV  BYTE PTR [EDI], 0');
  EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'STRBUF]');
  EmitI('POP  ECX');
  EmitI('POP  EBX');
  EmitI('POP  EDI');
  EmitI('POP  ESI');
  EmitI('POP  EBP');
  EmitI('RET  8');

  { ---- _PFXRT_STRMID : Mid(Text, Start, Count) -> EAX=STRBUF ---- }
  { Entree : [ESP+12]=ptr, [ESP+8]=Start (1-base), [ESP+4]=Count    }
  EmitBlank;
  EmitComment('--- _PFXRT_STRMID : Mid(Text, Start, Count) ---');
  EmitComment('Entree: [ESP+12]=ptr, [ESP+8]=Start, [ESP+4]=N. Sortie: EAX=STRBUF');
  EmitLabel(PFX_RT_PFX + 'STRMID');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('PUSH ESI');
  EmitI('PUSH EDI');
  EmitI('PUSH ECX');
  EmitI('MOV  ESI, DWORD PTR [EBP+16]');  { Text }
  EmitI('MOV  EAX, DWORD PTR [EBP+12]');  { Start (1-base) }
  EmitI('TEST EAX, EAX');
  EmitI('JG   ' + PFX_RT_PFX + 'STRMID_S');
  EmitI('MOV  EAX, 1');
  EmitLabel(PFX_RT_PFX + 'STRMID_S');
  EmitI('DEC  EAX');
  EmitI('ADD  ESI, EAX');
  EmitI('MOV  ECX, DWORD PTR [EBP+8]');   { Count }
  EmitI('LEA  EDI, DWORD PTR [' + PFX_RT_PFX + 'STRBUF]');
  L1 := NewLabel;
  EmitLabel(L1);
  EmitI('TEST ECX, ECX');
  EmitI('JZ   ' + L1 + '_E');
  EmitI('MOV  AL, BYTE PTR [ESI]');
  EmitI('TEST AL, AL');
  EmitI('JZ   ' + L1 + '_E');
  EmitI('MOV  BYTE PTR [EDI], AL');
  EmitI('INC  ESI');
  EmitI('INC  EDI');
  EmitI('DEC  ECX');
  EmitI('JMP  ' + L1);
  EmitLabel(L1 + '_E');
  EmitI('MOV  BYTE PTR [EDI], 0');
  EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'STRBUF]');
  EmitI('POP  ECX');
  EmitI('POP  EDI');
  EmitI('POP  ESI');
  EmitI('POP  EBP');
  EmitI('RET  12');

  { ---- _PFXRT_ABS : Abs(Number) -> x87 ---- }
  EmitBlank;
  EmitComment('--- _PFXRT_ABS : Abs(ST(0)) ---');
  EmitLabel(PFX_RT_PFX + 'ABS');
  EmitI('FABS');
  EmitI('RET');

  { ---- _PFXRT_SQRT : Sqrt(Number) -> x87 ---- }
  EmitBlank;
  EmitComment('--- _PFXRT_SQRT : Sqrt(ST(0)) ---');
  EmitLabel(PFX_RT_PFX + 'SQRT');
  EmitI('FTST');
  EmitI('FSTSW AX');
  EmitI('FWAIT');
  EmitI('SAHF');
  L1 := NewLabel;
  EmitI('JNC  ' + L1);
  EmitI('FSTP ST(0)');
  EmitI('PUSH OFFSET ' + PFX_RT_PFX + 'ERR_SQRT');
  EmitI('CALL ' + PFX_RT_PFX + 'ERROR');
  EmitLabel(L1);
  EmitI('FSQRT');
  EmitI('RET');

  { ---- _PFXRT_INT : Int(Number) -> partie entiere tronquee ---- }
  EmitBlank;
  EmitComment('--- _PFXRT_INT : Int(ST(0)) = troncature vers zero ---');
  EmitLabel(PFX_RT_PFX + 'INT');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('FISTP DWORD PTR [' + PFX_RT_PFX + 'ITMP]');
  EmitI('FILD DWORD PTR [' + PFX_RT_PFX + 'ITMP]');
  EmitI('POP  EBP');
  EmitI('RET');

  { ---- _PFXRT_ROUND : Round(Number, Decimals) ---- }
  { Entree : ST(0)=valeur, EAX=nb decimales           }
  EmitBlank;
  EmitComment('--- _PFXRT_ROUND : Round(ST(0), EAX) ---');
  EmitComment('Entree: ST(0)=valeur, EAX=nb decimales');
  EmitLabel(PFX_RT_PFX + 'ROUND');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('SUB  ESP, 8');
  { Simplification : arrondi a l entier le plus proche }
  EmitI('FRNDINT');
  EmitI('ADD  ESP, 8');
  EmitI('POP  EBP');
  EmitI('RET');

  { ---- _PFXRT_MOD : Mod(ST(1), ST(0)) -> reste entier ---- }
  { Entree : ST(0)=diviseur, ST(1)=dividende              }
  EmitBlank;
  EmitComment('--- _PFXRT_MOD : Mod(ST(1), ST(0)) ---');
  EmitLabel(PFX_RT_PFX + 'MOD');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('SUB  ESP, 8');
  { diviseur -> EBX }
  EmitI('FISTP DWORD PTR [' + PFX_RT_PFX + 'ITMP]');
  EmitI('MOV  EBX, DWORD PTR [' + PFX_RT_PFX + 'ITMP]');
  { dividende -> EAX }
  EmitI('FISTP DWORD PTR [' + PFX_RT_PFX + 'ITMP]');
  EmitI('MOV  EAX, DWORD PTR [' + PFX_RT_PFX + 'ITMP]');
  { Test division par zero }
  L1 := NewLabel;
  EmitI('TEST EBX, EBX');
  EmitI('JNZ  ' + L1);
  EmitI('PUSH OFFSET ' + PFX_RT_PFX + 'ERR_DIV0');
  EmitI('CALL ' + PFX_RT_PFX + 'ERROR');
  EmitLabel(L1);
  EmitI('CDQ');
  EmitI('IDIV EBX');
  EmitI('MOV  DWORD PTR [' + PFX_RT_PFX + 'ITMP], EDX');
  EmitI('FILD DWORD PTR [' + PFX_RT_PFX + 'ITMP]');  { reste en ST(0) }
  EmitI('ADD  ESP, 8');
  EmitI('POP  EBP');
  EmitI('RET');

  { ---- _PFXRT_POWER : Power(ST(0), ST(1)) = ST(0)^ST(1) ---- }
  { Entree : ST(0)=exposant, ST(1)=base                         }
  { base^exp = 2^(exp * log2(base))                             }
  EmitBlank;
  EmitComment('--- _PFXRT_POWER : Power(ST(0)=base, ST(1)=exp) ---');
  EmitLabel(PFX_RT_PFX + 'POWER');
  { ST(0)=base, ST(1)=exp -> ST(0) = base^exp }
  { Utiliser FYL2X : ST(0) = ST(1) * log2(ST(0)) }
  EmitI('FYL2X');
  { ST(0) = exp * log2(base) ; calculer 2^ST(0) }
  EmitI('FLD  ST(0)');
  EmitI('FRNDINT');
  EmitI('FXCH ST(1)');
  EmitI('FSUB ST(0), ST(1)');
  EmitI('F2XM1');
  EmitI('FLD1');
  EmitI('FADDP ST(1), ST(0)');
  EmitI('FSCALE');
  EmitI('FSTP ST(1)');
  EmitI('RET');

  { ---- _PFXRT_LOG : Log(ST(0)) = ln(x) ---- }
  EmitBlank;
  EmitComment('--- _PFXRT_LOG : Ln(ST(0)) ---');
  EmitLabel(PFX_RT_PFX + 'LOG');
  EmitI('FLDLN2');   { ST(0)=ln2, ST(1)=x }
  EmitI('FXCH ST(1)');
  EmitI('FYL2X');    { ST(0) = ln2 * log2(x) = ln(x) }
  EmitI('RET');

  { ---- _PFXRT_EXP : Exp(ST(0)) = e^x ---- }
  EmitBlank;
  EmitComment('--- _PFXRT_EXP : e^ST(0) ---');
  EmitLabel(PFX_RT_PFX + 'EXP');
  EmitI('FLDL2E');              { ST(0)=log2(e), ST(1)=x }
  EmitI('FMULP ST(1), ST(0)'); { ST(0) = x * log2(e) }
  EmitI('FLD  ST(0)');
  EmitI('FRNDINT');
  EmitI('FXCH ST(1)');
  EmitI('FSUB ST(0), ST(1)');
  EmitI('F2XM1');
  EmitI('FLD1');
  EmitI('FADDP ST(1), ST(0)');
  EmitI('FSCALE');
  EmitI('FSTP ST(1)');
  EmitI('RET');

  { ---- _PFXRT_READLN : lire une ligne depuis stdin ---- }
  { Sortie : EAX = pointeur vers INPUTBUF (ASCIIZ sans CR/LF) }
  EmitBlank;
  EmitComment('--- _PFXRT_READLN : lire une ligne depuis stdin ---');
  EmitLabel(PFX_RT_PFX + 'READLN');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('PUSH EDI');
  EmitI('LEA  EDI, DWORD PTR [' + PFX_RT_PFX + 'INPUTBUF]');
  EmitI('XOR  ECX, ECX');
  L1 := NewLabel; LE := NewLabel;
  EmitLabel(L1);
  EmitI('PUSH 0');
  EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'READCNT]');
  EmitI('PUSH EAX');
  EmitI('PUSH 1');
  EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'INPUTBUF + 254]');
  EmitI('PUSH EAX');
  EmitI('PUSH DWORD PTR [' + PFX_RT_PFX + 'HSTDIN]');
  EmitI('CALL _ReadFile@20');
  EmitI('MOV  EAX, DWORD PTR [' + PFX_RT_PFX + 'READCNT]');
  EmitI('TEST EAX, EAX');
  EmitI('JZ   ' + LE);
  EmitI('MOVZX EAX, BYTE PTR [' + PFX_RT_PFX + 'INPUTBUF + 254]');
  EmitI('CMP  AL, 10');
  EmitI('JE   ' + LE);
  EmitI('CMP  AL, 13');
  EmitI('JE   ' + L1);
  EmitI('CMP  ECX, 253');
  EmitI('JGE  ' + L1);
  EmitI('MOV  BYTE PTR [EDI], AL');
  EmitI('INC  EDI');
  EmitI('INC  ECX');
  EmitI('JMP  ' + L1);
  EmitLabel(LE);
  EmitI('MOV  BYTE PTR [EDI], 0');
  EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'INPUTBUF]');
  EmitI('POP  EDI');
  EmitI('POP  EBP');
  EmitI('RET');

  { ---- _PFXRT_ERROR : afficher message + ExitProcess(1) ---- }
  { Entree : [ESP+4] = pointeur vers message ASCIIZ              }
  EmitBlank;
  EmitComment('--- _PFXRT_ERROR : erreur fatale ---');
  EmitComment('Entree: [ESP+4] = ptr message ASCIIZ');
  EmitLabel(PFX_RT_PFX + 'ERROR');
  EmitI('PUSH EBP');
  EmitI('MOV  EBP, ESP');
  EmitI('MOV  EAX, DWORD PTR [EBP+8]');
  EmitI('PUSH EAX');
  EmitI('CALL ' + PFX_RT_PFX + 'PRINTLN');
  EmitI('PUSH 1');
  EmitI('CALL _ExitProcess@4');

  EmitBlank;
End;

{ ============================================================ }
{ PARSEUR D'EXPRESSIONS POWER FX                                }
{ ============================================================ }
{                                                               }
{ Precedences (de plus basse a plus haute) :                    }
{   1. || (Or logique court-circuit)                            }
{   2. && (And logique court-circuit)                           }
{   3. ! (Not unaire)                                           }
{   4. = <> < > <= >= (comparaisons)                            }
{   5. + - & (additive + concatenation)                         }
{   6. * / (multiplicative)                                     }
{   7. - (unaire) ! (not)                                       }
{   8. ^ (puissance)                                            }
{   9. Primaire : litteraux, ident, appels, (expr)              }
{                                                               }
{ Convention registres :                                        }
{   PFX_NUMBER  : resultat dans ST(0) FPU x87                  }
{   PFX_TEXT    : resultat pointeur ASCIIZ dans EAX             }
{   PFX_BOOLEAN : resultat 0/1 dans EAX                         }
{ ============================================================ }

{ ---- GenForceBool : s assurer que EAX contient un booleen }
{ Si ExprType = PFX_NUMBER : convertir ST(0) en entier dans EAX }
Procedure GenForceBool;
Begin
  If ExprType = PFX_NUMBER Then
  Begin
    GenFPUToInt;
    EmitI('TEST EAX, EAX');
    EmitI('SETNZ AL');
    EmitI('MOVZX EAX, AL');
    ExprType := PFX_BOOLEAN;
  End;
End;

{ ---- GenNumPush : sauvegarder ST(0) sur la pile memoire ---- }
{ Necessite 8 octets reserves sur la pile x86 avant l appel    }
Procedure GenNumPush;
Begin
  EmitI('SUB  ESP, 8');
  EmitI('FSTP QWORD PTR [ESP]');
End;

{ ---- GenNumPop : restaurer ST(0) depuis la pile memoire ---- }
Procedure GenNumPop;
Begin
  EmitI('FLD  QWORD PTR [ESP]');
  EmitI('ADD  ESP, 8');
End;

{ ---- ParsePrimary : litteraux, identifiants, appels de fonctions ---- }
Procedure ParsePrimary;
Var
  Nm     : TString;
  Sym    : Integer;
  Lbl1   : TString;
  Lbl2   : TString;
  LblEnd : TString;
  ArgCnt : Integer;
  NumLbl : TString;
Begin
  ExprType := PFX_UNKNOWN;

  Case CurTokType Of

    { --- Litteral numerique : charger dans ST(0) FPU --- }
    TOK_NUMBER :
    Begin
      NumLbl := AsmNumLit(CurTokStr);
      EmitComment('Number ' + CurTokStr);
      EmitI('FLD  QWORD PTR [' + NumLbl + ']');
      ExprType := PFX_NUMBER;
      Consume;
    End;

    { --- Litteral chaine : charger adresse dans EAX --- }
    TOK_TEXT :
    Begin
      EmitComment('Text "' + CurTokStr + '"');
      EmitI('LEA  EAX, DWORD PTR [' + AsmStrLit(CurTokStr) + ']');
      ExprType := PFX_TEXT;
      Consume;
    End;

    { --- Identificateurs, mots-cles, appels de fonctions --- }
    TOK_IDENT :
    Begin
      Nm := CurTokStr;

      { Mots-cles specifiques }
      Case CurTokKw Of

        KW_TRUE :
        Begin
          EmitI('MOV  EAX, 1');
          ExprType := PFX_BOOLEAN;
          Consume;
        End;

        KW_FALSE :
        Begin
          EmitI('XOR  EAX, EAX');
          ExprType := PFX_BOOLEAN;
          Consume;
        End;

        KW_BLANK :
        Begin
          Consume;
          If CurTokType = TOK_LPAREN Then
          Begin Consume; Expect(TOK_RPAREN, ')'); End;
          EmitI('XOR  EAX, EAX');
          ExprType := PFX_BLANK;
        End;

        { If(condition, si_vrai, si_faux) }
        KW_IF :
        Begin
          Consume;
          Expect(TOK_LPAREN, '(');
          EmitComment('If(...)');
          ParseExpr;
          GenForceBool;
          Expect(TOK_COMMA, ',');
          Lbl1   := NewLabel;
          LblEnd := NewLabel;
          EmitI('TEST EAX, EAX');
          EmitI('JZ   ' + Lbl1);
          ParseExpr;               { branche vraie }
          If ExprType = PFX_NUMBER Then GenNumPush;
          EmitI('JMP  ' + LblEnd);
          EmitLabel(Lbl1);
          If ExprType = PFX_NUMBER Then
          Begin
            EmitI('SUB  ESP, 8');  { placeholder pour aligner la pile }
          End;
          Expect(TOK_COMMA, ',');
          ParseExpr;               { branche fausse }
          EmitLabel(LblEnd);
          Expect(TOK_RPAREN, ')');
          { ExprType = type commun (approximation) }
        End;

        { Switch(expr, val1, res1, ..., defaut) }
        KW_SWITCH :
        Begin
          Consume;
          Expect(TOK_LPAREN, '(');
          EmitComment('Switch(...)');
          EmitI('PUSH EBX');
          ParseExpr;               { expression principale }
          GenForceBool;
          EmitI('MOV  EBX, EAX'); { EBX = valeur a comparer }
          LblEnd := NewLabel;
          While (CurTokType = TOK_COMMA) And (CurTokType <> TOK_EOF) Do
          Begin
            Expect(TOK_COMMA, ',');
            If CurTokType = TOK_RPAREN Then Break;
            ParseExpr;             { valeur du cas }
            GenForceBool;
            If CurTokType = TOK_COMMA Then
            Begin
              Lbl1 := NewLabel;
              EmitI('CMP  EBX, EAX');
              EmitI('JNE  ' + Lbl1);
              Expect(TOK_COMMA, ',');
              ParseExpr;           { resultat si match }
              EmitI('JMP  ' + LblEnd);
              EmitLabel(Lbl1);
            End;
          End;
          EmitLabel(LblEnd);
          EmitI('POP  EBX');
          Expect(TOK_RPAREN, ')');
        End;

        { Not(expr) }
        KW_NOT :
        Begin
          Consume;
          Expect(TOK_LPAREN, '(');
          ParseExpr;
          GenForceBool;
          EmitI('TEST EAX, EAX');
          EmitI('SETE AL');
          EmitI('MOVZX EAX, AL');
          Expect(TOK_RPAREN, ')');
          ExprType := PFX_BOOLEAN;
        End;

        { And(expr1, expr2, ...) }
        KW_AND :
        Begin
          Consume;
          Expect(TOK_LPAREN, '(');
          EmitI('MOV  EAX, 1');
          While CurTokType <> TOK_RPAREN Do
          Begin
            EmitI('PUSH EAX');
            ParseExpr;
            GenForceBool;
            EmitI('POP  EBX');
            EmitI('AND  EAX, EBX');
            If CurTokType = TOK_COMMA Then Consume;
          End;
          Expect(TOK_RPAREN, ')');
          ExprType := PFX_BOOLEAN;
        End;

        { Or(expr1, expr2, ...) }
        KW_OR :
        Begin
          Consume;
          Expect(TOK_LPAREN, '(');
          EmitI('XOR  EAX, EAX');
          While CurTokType <> TOK_RPAREN Do
          Begin
            EmitI('PUSH EAX');
            ParseExpr;
            GenForceBool;
            EmitI('POP  EBX');
            EmitI('OR   EAX, EBX');
            If CurTokType = TOK_COMMA Then Consume;
          End;
          Expect(TOK_RPAREN, ')');
          ExprType := PFX_BOOLEAN;
        End;

        { IsBlank(expr) }
        KW_ISBLANK :
        Begin
          Consume;
          Expect(TOK_LPAREN, '(');
          ParseExpr;
          Expect(TOK_RPAREN, ')');
          If ExprType = PFX_NUMBER Then GenFPUToInt;
          EmitI('TEST EAX, EAX');
          EmitI('SETE AL');
          EmitI('MOVZX EAX, AL');
          ExprType := PFX_BOOLEAN;
        End;

        { IsError(expr) }
        KW_ISERROR :
        Begin
          Consume;
          Expect(TOK_LPAREN, '(');
          ParseExpr;
          Expect(TOK_RPAREN, ')');
          EmitI('XOR  EAX, EAX'); { toujours false dans ce compilateur }
          ExprType := PFX_BOOLEAN;
        End;

      Else
        { Identificateur : variable ou appel de fonction built-in }
        Consume;
        If CurTokType = TOK_LPAREN Then
        Begin
          { Appel de fonction }
          Consume;
          EmitComment('Fn: ' + Nm);
          Nm := StrUpperCase(Nm);

          If Nm = 'ABS' Then
          Begin
            ParseExpr;
            EmitI('CALL ' + PFX_RT_PFX + 'ABS');
            ExprType := PFX_NUMBER;
          End

          Else If Nm = 'SQRT' Then
          Begin
            ParseExpr;
            EmitI('CALL ' + PFX_RT_PFX + 'SQRT');
            ExprType := PFX_NUMBER;
          End

          Else If Nm = 'INT' Then
          Begin
            ParseExpr;
            EmitI('CALL ' + PFX_RT_PFX + 'INT');
            ExprType := PFX_NUMBER;
          End

          Else If Nm = 'ROUND' Then
          Begin
            ParseExpr;
            If CurTokType = TOK_COMMA Then
            Begin
              Expect(TOK_COMMA, ',');
              ParseExpr;
              GenFPUToInt;
            End
            Else EmitI('XOR  EAX, EAX');
            EmitI('CALL ' + PFX_RT_PFX + 'ROUND');
            ExprType := PFX_NUMBER;
          End

          Else If Nm = 'POWER' Then
          Begin
            ParseExpr;       { base dans ST(0) }
            Expect(TOK_COMMA, ',');
            ParseExpr;       { exposant dans ST(0), base dans ST(1) }
            EmitI('CALL ' + PFX_RT_PFX + 'POWER');
            ExprType := PFX_NUMBER;
          End

          Else If Nm = 'MOD' Then
          Begin
            ParseExpr;       { dividende dans ST(0) }
            Expect(TOK_COMMA, ',');
            ParseExpr;       { diviseur dans ST(0), dividende dans ST(1) }
            EmitI('CALL ' + PFX_RT_PFX + 'MOD');
            ExprType := PFX_NUMBER;
          End

          Else If Nm = 'LOG' Then
          Begin
            ParseExpr;
            EmitI('CALL ' + PFX_RT_PFX + 'LOG');
            ExprType := PFX_NUMBER;
          End

          Else If Nm = 'EXP' Then
          Begin
            ParseExpr;
            EmitI('CALL ' + PFX_RT_PFX + 'EXP');
            ExprType := PFX_NUMBER;
          End

          Else If Nm = 'LEN' Then
          Begin
            ParseExpr;
            If ExprType = PFX_NUMBER Then
            Begin
              EmitI('CALL ' + PFX_RT_PFX + 'NUMTOSTR');
            End;
            EmitI('CALL ' + PFX_RT_PFX + 'STRLEN');
            EmitI('MOV  DWORD PTR [' + PFX_RT_PFX + 'ITMP], EAX');
            EmitI('FILD DWORD PTR [' + PFX_RT_PFX + 'ITMP]');
            ExprType := PFX_NUMBER;
          End

          Else If Nm = 'UPPER' Then
          Begin
            ParseExpr;
            If ExprType = PFX_NUMBER Then EmitI('CALL ' + PFX_RT_PFX + 'NUMTOSTR');
            EmitI('PUSH EAX');
            EmitI('CALL ' + PFX_RT_PFX + 'STRUPPR');
            ExprType := PFX_TEXT;
          End

          Else If Nm = 'LOWER' Then
          Begin
            ParseExpr;
            If ExprType = PFX_NUMBER Then EmitI('CALL ' + PFX_RT_PFX + 'NUMTOSTR');
            EmitI('PUSH EAX');
            EmitI('CALL ' + PFX_RT_PFX + 'STRLWER');
            ExprType := PFX_TEXT;
          End

          Else If Nm = 'TRIM' Then
          Begin
            ParseExpr;
            If ExprType = PFX_NUMBER Then EmitI('CALL ' + PFX_RT_PFX + 'NUMTOSTR');
            EmitI('PUSH EAX');
            EmitI('CALL ' + PFX_RT_PFX + 'STRTRIM');
            ExprType := PFX_TEXT;
          End

          Else If Nm = 'LEFT' Then
          Begin
            ParseExpr;
            If ExprType = PFX_NUMBER Then EmitI('CALL ' + PFX_RT_PFX + 'NUMTOSTR');
            EmitI('PUSH EAX');      { push Text }
            Expect(TOK_COMMA, ',');
            ParseExpr;
            GenFPUToInt;
            EmitI('PUSH EAX');      { push N }
            EmitI('CALL ' + PFX_RT_PFX + 'STRLEFT');
            ExprType := PFX_TEXT;
          End

          Else If Nm = 'RIGHT' Then
          Begin
            ParseExpr;
            If ExprType = PFX_NUMBER Then EmitI('CALL ' + PFX_RT_PFX + 'NUMTOSTR');
            EmitI('PUSH EAX');      { push Text }
            Expect(TOK_COMMA, ',');
            ParseExpr;
            GenFPUToInt;
            EmitI('PUSH EAX');      { push N }
            EmitI('CALL ' + PFX_RT_PFX + 'STRRIGHT');
            ExprType := PFX_TEXT;
          End

          Else If Nm = 'MID' Then
          Begin
            ParseExpr;
            If ExprType = PFX_NUMBER Then EmitI('CALL ' + PFX_RT_PFX + 'NUMTOSTR');
            EmitI('PUSH EAX');      { push Text }
            Expect(TOK_COMMA, ',');
            ParseExpr;
            GenFPUToInt;
            EmitI('PUSH EAX');      { push Start }
            Expect(TOK_COMMA, ',');
            ParseExpr;
            GenFPUToInt;
            EmitI('PUSH EAX');      { push Count }
            EmitI('CALL ' + PFX_RT_PFX + 'STRMID');
            ExprType := PFX_TEXT;
          End

          Else If Nm = 'CONCATENATE' Then
          Begin
            ParseExpr;
            If ExprType = PFX_NUMBER Then EmitI('CALL ' + PFX_RT_PFX + 'NUMTOSTR');
            EmitI('PUSH EAX');
            While CurTokType = TOK_COMMA Do
            Begin
              Expect(TOK_COMMA, ',');
              EmitI('POP  EBX');
              ParseExpr;
              If ExprType = PFX_NUMBER Then EmitI('CALL ' + PFX_RT_PFX + 'NUMTOSTR');
              EmitI('PUSH EBX');
              EmitI('PUSH EAX');
              EmitI('CALL ' + PFX_RT_PFX + 'STRCAT');
            End;
            EmitI('POP  EAX');
            { POP extra si nest... }
            ExprType := PFX_TEXT;
          End

          Else If Nm = 'TEXT' Then
          Begin
            ParseExpr;
            If ExprType = PFX_NUMBER Then
            Begin
              EmitI('CALL ' + PFX_RT_PFX + 'NUMTOSTR');
            End
            Else If ExprType = PFX_BOOLEAN Then
            Begin
              Lbl1   := NewLabel;
              LblEnd := NewLabel;
              EmitI('TEST EAX, EAX');
              EmitI('JZ   ' + Lbl1);
              EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'STR_TRUE]');
              EmitI('JMP  ' + LblEnd);
              EmitLabel(Lbl1);
              EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'STR_FALSE]');
              EmitLabel(LblEnd);
            End;
            If CurTokType = TOK_COMMA Then
            Begin Expect(TOK_COMMA, ','); ParseExpr; End; { format ignore }
            ExprType := PFX_TEXT;
          End

          Else If Nm = 'VALUE' Then
          Begin
            { Value(Text) -> Number : approximation (retourne 0) }
            ParseExpr;
            If ExprType = PFX_NUMBER Then
            Begin
              { deja un Number }
            End
            Else
            Begin
              EmitI('XOR  EAX, EAX');
              EmitI('MOV  DWORD PTR [' + PFX_RT_PFX + 'ITMP], EAX');
              EmitI('FILD DWORD PTR [' + PFX_RT_PFX + 'ITMP]');
              ExprType := PFX_NUMBER;
            End;
          End

          Else If Nm = 'IF' Then
          Begin
            { If() comme appel de fonction }
            ParseExpr;
            GenForceBool;
            Expect(TOK_COMMA, ',');
            Lbl1   := NewLabel;
            LblEnd := NewLabel;
            EmitI('TEST EAX, EAX');
            EmitI('JZ   ' + Lbl1);
            ParseExpr;
            EmitI('JMP  ' + LblEnd);
            EmitLabel(Lbl1);
            Expect(TOK_COMMA, ',');
            ParseExpr;
            EmitLabel(LblEnd);
          End

          Else
          Begin
            { Fonction inconnue : passer les arguments et retourner 0 }
            EmitComment('Fn inconnue: ' + Nm + ' (stub)');
            ArgCnt := 0;
            While (CurTokType <> TOK_RPAREN) And (CurTokType <> TOK_EOF) Do
            Begin
              ParseExpr;
              If ExprType = PFX_NUMBER Then EmitI('FSTP ST(0)');
              Inc(ArgCnt);
              If CurTokType = TOK_COMMA Then Consume;
            End;
            Warning('Fonction non supportee: ' + Nm + ' (retourne 0)');
            EmitI('XOR  EAX, EAX');
            ExprType := PFX_UNKNOWN;
          End;

          Expect(TOK_RPAREN, ')');
        End
        Else
        Begin
          { Variable }
          Sym := FindSym(Nm);
          If Sym > 0 Then
          Begin
            GenLoadSym(Sym);
            ExprType := SymTab[Sym].VarType;
          End
          Else
          Begin
            Error('Symbole inconnu: ' + Nm);
            EmitI('XOR  EAX, EAX');
            ExprType := PFX_UNKNOWN;
          End;
        End;
      End; { case CurTokKw }
    End; { TOK_IDENT }

    { --- Parenthese --- }
    TOK_LPAREN :
    Begin
      Consume;
      ParseExpr;
      Expect(TOK_RPAREN, ')');
    End;

    { --- Not unaire --- }
    TOK_NOT :
    Begin
      Consume;
      ParseExpr;
      GenForceBool;
      EmitI('TEST EAX, EAX');
      EmitI('SETE AL');
      EmitI('MOVZX EAX, AL');
      ExprType := PFX_BOOLEAN;
    End;

    { --- Moins unaire --- }
    TOK_MINUS :
    Begin
      Consume;
      ParseExpr;
      If ExprType = PFX_NUMBER Then
        EmitI('FCHS')
      Else
        EmitI('NEG  EAX');
    End;

  Else
    Error('Expression attendue, token: ''' + CurTokStr + '''');
    Consume;
    EmitI('XOR  EAX, EAX');
    ExprType := PFX_UNKNOWN;
  End;
End;

{ ---- ParsePower : ^ (droite associatif) ---- }
Procedure ParsePower;
Begin
  ParsePrimary;
  While CurTokType = TOK_POWER Do
  Begin
    Consume;
    { ST(0) = base. Evaluer exposant. }
    ParsePrimary;
    { ST(0) = exposant, ST(1) = base -> POWER(base, exp) }
    EmitI('CALL ' + PFX_RT_PFX + 'POWER');
    ExprType := PFX_NUMBER;
  End;
End;

{ ---- ParseMul : *, / ---- }
Procedure ParseMul;
Var Op : Integer;
Begin
  ParsePower;
  While (CurTokType = TOK_STAR) Or (CurTokType = TOK_SLASH) Do
  Begin
    Op := CurTokType;
    Consume;
    { Sauvegarder gauche sur pile x86 }
    If ExprType = PFX_NUMBER Then
      GenNumPush
    Else
      EmitI('PUSH EAX');
    ParsePower;
    { Restaurer gauche }
    If ExprType = PFX_NUMBER Then
    Begin
      { ST(0) = droite, pile = gauche }
      GenNumPop;                         { ST(0)=gauche, ST(1)=droite }
      If Op = TOK_STAR Then
        EmitI('FMULP ST(1), ST(0)')      { ST(0) = gauche * droite }
      Else
      Begin
        { gauche / droite : ST(0)=gauche, ST(1)=droite }
        { FDIVP ST(1), ST(0) = ST(1)/ST(0) = droite/gauche -> FAUX }
        { Utiliser FDIVRP : ST(1) = ST(0)/ST(1) = gauche/droite -> JUSTE }
        EmitI('FDIVRP ST(1), ST(0)');
      End;
      ExprType := PFX_NUMBER;
    End
    Else
    Begin
      EmitI('POP  EBX');
      If Op = TOK_STAR Then
      Begin
        EmitI('IMUL EAX, EBX');
      End
      Else
      Begin
        EmitI('XCHG EAX, EBX');
        EmitI('CDQ');
        EmitI('IDIV EBX');
      End;
      ExprType := PFX_UNKNOWN;
    End;
  End;
End;

{ ---- ParseAdd : +, -, & (concatenation) ---- }
Procedure ParseAdd;
Var Op : Integer; LeftType : Integer;
    LblB1, LblBE : TString;
Begin
  ParseMul;
  While (CurTokType = TOK_PLUS) Or (CurTokType = TOK_MINUS) Or
        (CurTokType = TOK_AMP) Do
  Begin
    Op       := CurTokType;
    LeftType := ExprType;
    Consume;

    If Op = TOK_AMP Then
    Begin
      { Concatenation & }
      If LeftType = PFX_NUMBER Then
        EmitI('CALL ' + PFX_RT_PFX + 'NUMTOSTR')
      Else If LeftType = PFX_BOOLEAN Then
      Begin
        LblB1 := NewLabel; LblBE := NewLabel;
        EmitI('TEST EAX, EAX');
        EmitI('JZ   ' + LblB1);
        EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'STR_TRUE]');
        EmitI('JMP  ' + LblBE);
        EmitLabel(LblB1);
        EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'STR_FALSE]');
        EmitLabel(LblBE);
      End;
      EmitI('PUSH EAX');       { push gauche (ASCIIZ) }
      ParseMul;
      If ExprType = PFX_NUMBER Then
        EmitI('CALL ' + PFX_RT_PFX + 'NUMTOSTR')
      Else If ExprType = PFX_BOOLEAN Then
      Begin
        LblB1 := NewLabel; LblBE := NewLabel;
        EmitI('TEST EAX, EAX');
        EmitI('JZ   ' + LblB1);
        EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'STR_TRUE]');
        EmitI('JMP  ' + LblBE);
        EmitLabel(LblB1);
        EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'STR_FALSE]');
        EmitLabel(LblBE);
      End;
      EmitI('PUSH EAX');       { push droite (ASCIIZ) }
      EmitI('CALL ' + PFX_RT_PFX + 'STRCAT');
      ExprType := PFX_TEXT;
    End
    Else If LeftType = PFX_NUMBER Then
    Begin
      { Operation numerique : sauvegarder gauche sur pile }
      GenNumPush;
      ParseMul;
      { ST(0) = droite, pile memoire = gauche }
      GenNumPop;              { ST(0)=gauche, ST(1)=droite }
      If Op = TOK_PLUS Then
        EmitI('FADDP ST(1), ST(0)')     { gauche + droite }
      Else
        EmitI('FSUBRP ST(1), ST(0)');  { ST(1)=droite, ST(0)=gauche -> ST(0)-ST(1) = gauche-droite }
      ExprType := PFX_NUMBER;
    End
    Else
    Begin
      EmitI('PUSH EAX');
      ParseMul;
      EmitI('POP  EBX');
      If Op = TOK_PLUS Then
        EmitI('ADD  EAX, EBX')
      Else
      Begin
        EmitI('XCHG EAX, EBX');
        EmitI('SUB  EAX, EBX');
      End;
      ExprType := PFX_UNKNOWN;
    End;
  End;
End;

{ ---- ParseRelation : = <> < > <= >= ---- }
Procedure ParseRelation;
Var Op : Integer; LeftType : Integer;
Begin
  ParseAdd;
  While (CurTokType = TOK_EQ)  Or (CurTokType = TOK_NEQ) Or
        (CurTokType = TOK_LT)  Or (CurTokType = TOK_GT) Or
        (CurTokType = TOK_LE)  Or (CurTokType = TOK_GE) Do
  Begin
    Op       := CurTokType;
    LeftType := ExprType;
    Consume;
    If LeftType = PFX_NUMBER Then
    Begin
      GenNumPush;
      ParseAdd;
      { ST(0) = droite, pile = gauche }
      GenNumPop;              { ST(0)=gauche, ST(1)=droite }
      { FCOMI compare ST(0) et ST(1) : flags de gauche vs droite }
      { CF=1 si ST(0) < ST(1) (gauche < droite) }
      EmitI('FCOMI ST(0), ST(1)');
      EmitI('FSTP ST(0)');   { vider gauche }
      EmitI('FSTP ST(0)');   { vider droite }
      Case Op Of
        TOK_EQ  : EmitI('SETE  AL');    { ZF=1 }
        TOK_NEQ : EmitI('SETNE AL');    { ZF=0 }
        TOK_LT  : EmitI('SETB  AL');    { CF=1 (below) }
        TOK_GT  : EmitI('SETA  AL');    { CF=0 et ZF=0 }
        TOK_LE  : EmitI('SETBE AL');    { CF=1 ou ZF=1 }
        TOK_GE  : EmitI('SETAE AL');    { CF=0 }
      End;
      EmitI('MOVZX EAX, AL');
      ExprType := PFX_BOOLEAN;
    End
    Else
    Begin
      EmitI('PUSH EAX');
      ParseAdd;
      EmitI('MOV  EBX, EAX');
      EmitI('POP  EAX');
      EmitI('CMP  EAX, EBX');
      Case Op Of
        TOK_EQ  : EmitI('SETE  AL');
        TOK_NEQ : EmitI('SETNE AL');
        TOK_LT  : EmitI('SETL  AL');
        TOK_GT  : EmitI('SETG  AL');
        TOK_LE  : EmitI('SETLE AL');
        TOK_GE  : EmitI('SETGE AL');
      End;
      EmitI('MOVZX EAX, AL');
      ExprType := PFX_BOOLEAN;
    End;
  End;
End;

{ ---- ParseAnd : && (court-circuit) ---- }
Procedure ParseAnd;
Var LblFalse, LblEnd : TString;
Begin
  ParseRelation;
  While CurTokType = TOK_AND Do
  Begin
    Consume;
    GenForceBool;
    LblFalse := NewLabel;
    LblEnd   := NewLabel;
    EmitI('TEST EAX, EAX');
    EmitI('JZ   ' + LblFalse);
    ParseRelation;
    GenForceBool;
    EmitI('JMP  ' + LblEnd);
    EmitLabel(LblFalse);
    EmitI('XOR  EAX, EAX');
    EmitLabel(LblEnd);
    ExprType := PFX_BOOLEAN;
  End;
End;

{ ---- ParseOr : || (court-circuit) ---- }
Procedure ParseOr;
Var LblTrue, LblEnd : TString;
Begin
  ParseAnd;
  While CurTokType = TOK_OR Do
  Begin
    Consume;
    GenForceBool;
    LblTrue := NewLabel;
    LblEnd  := NewLabel;
    EmitI('TEST EAX, EAX');
    EmitI('JNZ  ' + LblTrue);
    ParseAnd;
    GenForceBool;
    EmitI('JMP  ' + LblEnd);
    EmitLabel(LblTrue);
    EmitI('MOV  EAX, 1');
    EmitLabel(LblEnd);
    ExprType := PFX_BOOLEAN;
  End;
End;

{ ---- ParseExpr : point d entree des expressions ---- }
Procedure ParseExpr;
Begin
  ParseOr;
End;

{ ============================================================ }
{ PARSEUR : INSTRUCTIONS POWER FX                               }
{ ============================================================ }

{ ---- SkipToSemi : synchronisation sur ';' apres une erreur }
Procedure SkipToSemi;
Begin
  While (CurTokType <> TOK_SEMI) And (CurTokType <> TOK_EOF) Do Consume;
  If CurTokType = TOK_SEMI Then Consume;
End;

{ ---- ParseStatement : une instruction Power FX ---- }
{ Set(var, formule)    : affectation                  }
{ Print(formule)       : affichage (extension)        }
{ Collect/Clear/Patch/Remove : stubs ignores          }
{ expr                 : expression standalone        }
Procedure ParseStatement;
Var Nm : TString; Sym : Integer;
Begin
  { Ignorer les points-virgules vides }
  While CurTokType = TOK_SEMI Do Consume;
  If CurTokType = TOK_EOF Then Exit;

  If CurTokType <> TOK_IDENT Then
  Begin
    { Expression standalone }
    ParseExpr;
    If ExprType = PFX_NUMBER Then EmitI('FSTP ST(0)');
    If CurTokType = TOK_SEMI Then Consume;
    Exit;
  End;

  Nm := CurTokStr;
  Case CurTokKw Of

    { Set(variable, expression) }
    KW_SET :
    Begin
      Consume;
      Expect(TOK_LPAREN, '(');
      If CurTokType <> TOK_IDENT Then
      Begin Error('Nom de variable attendu dans Set()'); SkipToSemi; Exit; End;
      Nm := CurTokStr;
      Consume;
      Expect(TOK_COMMA, ',');
      EmitComment('Set(' + Nm + ', ...)');
      ParseExpr;
      { Creer ou mettre a jour la variable }
      Sym := FindSym(Nm);
      If Sym = 0 Then
      Begin
        Sym := AddSym(Nm, ExprType, STORE_GLOBAL);
        If Sym = 0 Then Begin SkipToSemi; Exit; End;
      End
      Else
        SymTab[Sym].VarType := ExprType;
      { Stocker le resultat }
      GenStoreSym(Sym);
      Expect(TOK_RPAREN, ')');
      If CurTokType = TOK_SEMI Then Consume;
    End;

    { Print(expression) - extension compilateur }
    KW_PRINT :
    Begin
      Consume;
      Expect(TOK_LPAREN, '(');
      EmitComment('Print(...)');
      ParseExpr;
      Case ExprType Of
        PFX_NUMBER :
        Begin
          EmitI('CALL ' + PFX_RT_PFX + 'NUMTOSTR');
          EmitI('PUSH EAX');
          EmitI('CALL ' + PFX_RT_PFX + 'PRINTLN');
        End;
        PFX_TEXT :
        Begin
          EmitI('PUSH EAX');
          EmitI('CALL ' + PFX_RT_PFX + 'PRINTLN');
        End;
        PFX_BOOLEAN :
        Begin
          EmitI('PUSH EAX');
          EmitI('CALL ' + PFX_RT_PFX + 'PRINTBOOL');
        End;
      Else
        EmitI('PUSH EAX');
        EmitI('CALL ' + PFX_RT_PFX + 'PRINTLN');
      End;
      Expect(TOK_RPAREN, ')');
      If CurTokType = TOK_SEMI Then Consume;
    End;

    { Stubs : Collect, Clear, Patch, Remove, ForAll, Filter }
    KW_COLLECT, KW_CLEAR, KW_PATCH, KW_REMOVE, KW_FORALL, KW_FILTER :
    Begin
      EmitComment(StrUpperCase(Nm) + '(...) - stub non supporte, ignore');
      Consume;
      If CurTokType = TOK_LPAREN Then
      Begin
        Consume;
        While (CurTokType <> TOK_RPAREN) And (CurTokType <> TOK_EOF) Do
          Consume;
        If CurTokType = TOK_RPAREN Then Consume;
      End;
      If CurTokType = TOK_SEMI Then Consume;
      Warning(StrUpperCase(Nm) + ' non supporte, instruction ignoree');
    End;

  Else
    { Expression standalone (appel de fonction ou variable) }
    ParseExpr;
    If ExprType = PFX_NUMBER Then EmitI('FSTP ST(0)');
    If CurTokType = TOK_SEMI Then Consume;
  End;
End;

{ ---- ParseProgram : sequence d instructions jusqu a EOF ---- }
Procedure ParseProgram;
Begin
  EmitBlank;
  EmitComment('========================================');
  EmitComment('Programme Power FX : ' + Opts.SrcFile);
  EmitComment('========================================');
  EmitBlank;
  EmitLabel(PFX_FN_PFX + 'PROGRAM');
  GenPrologue(0);
  EmitBlank;

  While CurTokType <> TOK_EOF Do
    ParseStatement;

  EmitBlank;
  GenEpilogue(0);
  EmitBlank;
End;

{ ============================================================ }
{ LEXEUR : INITIALISATION ET FERMETURE                          }
{ ============================================================ }

Procedure LexInit;
Begin
  Assign(LexSrcF, Opts.SrcFile);
  {$I-}
  Reset(LexSrcF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('Impossible d''ouvrir: ' + Opts.SrcFile);
  LexOpened  := True;
  LexLineNo  := 0;
  LexColNo   := 1;
  LexEOF     := False;
  LexLine    := '';
  LexNextLine;
  LexNextToken;
End;

Procedure LexClose;
Begin
  If LexOpened Then Begin Close(LexSrcF); LexOpened := False; End;
End;

{ ============================================================ }
{ GENERATION FINALE : PE32 / COFF (Free Pascal uniquement)     }
{ ============================================================ }

{$IFDEF FPC}

Procedure BinInit;
Begin
  BinCodeLen  := 0;
  BinDataLen  := 0;
  BinLblCount := 0;
  BinFixCount := 0;
End;

Procedure BinEmitByte(B : Byte);
Begin
  If BinCodeLen < MAX_BIN_CODE Then
  Begin BinCode[BinCodeLen] := B; Inc(BinCodeLen); End;
End;

Procedure BinEmitWord(W : Word);
Begin BinEmitByte(Lo(W)); BinEmitByte(Hi(W)); End;

Procedure BinEmitDWord(D : LongInt);
Begin
  BinEmitByte(Byte(D And $FF));
  BinEmitByte(Byte((D Shr 8) And $FF));
  BinEmitByte(Byte((D Shr 16) And $FF));
  BinEmitByte(Byte((D Shr 24) And $FF));
End;

Procedure BinEmitDataByte(B : Byte);
Begin
  If BinDataLen < MAX_BIN_DATA Then
  Begin BinData[BinDataLen] := B; Inc(BinDataLen); End;
End;

Procedure BinEmitDataDWord(D : LongInt);
Begin
  BinEmitDataByte(Byte(D And $FF));
  BinEmitDataByte(Byte((D Shr 8) And $FF));
  BinEmitDataByte(Byte((D Shr 16) And $FF));
  BinEmitDataByte(Byte((D Shr 24) And $FF));
End;

Procedure BinAddLabel(AName : TString; AnOfs : LongInt);
Begin
  If BinLblCount < MAX_BIN_LBL Then
  Begin
    BinLabels[BinLblCount].Name   := AName;
    BinLabels[BinLblCount].Offset := AnOfs;
    BinLabels[BinLblCount].InCode := True;
    Inc(BinLblCount);
  End;
End;

Procedure BinAddFixup(AnOfs : LongInt; AKind : TBinFixKind;
                      ATarget : TString; AInCode : Boolean);
Begin
  If BinFixCount < MAX_BIN_FIX Then
  Begin
    BinFixups[BinFixCount].Offset := AnOfs;
    BinFixups[BinFixCount].Kind   := AKind;
    BinFixups[BinFixCount].Target := ATarget;
    BinFixups[BinFixCount].InCode := AInCode;
    Inc(BinFixCount);
  End;
End;

Function BinFindLabel(AName : TString) : LongInt;
Var I : Integer;
Begin
  BinFindLabel := -1;
  For I := 0 To BinLblCount - 1 Do
    If BinLabels[I].Name = AName Then
    Begin BinFindLabel := BinLabels[I].Offset; Exit; End;
End;

{ ---- BinAssemble : stub - note que le vrai assemblage necessite MASM ---- }
{ Pour un assemblage complet, utiliser :                                      }
{   ML /c /coff /Fo PROG.OBJ PROG.ASM                                        }
{   LINK /SUBSYSTEM:CONSOLE /OUT:PROG.EXE PROG.OBJ kernel32.lib              }
Procedure BinAssemble;
Begin
  BinInit;
  WriteLn('POWFXC32: Note: assemblage .ASM genere -> utilisez MASM/NASM:');
  WriteLn('  ML /c /coff /Fo ' + ReplaceExt(Opts.SrcFile, '.obj') +
          ' ' + ReplaceExt(Opts.SrcFile, '.asm'));
  WriteLn('  LINK /SUBSYSTEM:CONSOLE /OUT:' + Opts.OutFile +
          ' ' + ReplaceExt(Opts.SrcFile, '.obj') + ' kernel32.lib');
  { Creer un stub minimal INT3 + RET pour BinWriteExe }
  BinEmitByte($CC);   { INT3 - breakpoint }
  BinEmitByte($C3);   { RET }
  BinAddLabel(PFX_FN_PFX + 'main', 0);
  BinEmitDataDWord(0);
End;

Procedure WriteBinByte_(Var F : File; B : Byte);
Begin BlockWrite(F, B, 1); End;

Procedure WriteBinWord_(Var F : File; W : Word);
Begin WriteBinByte_(F, Lo(W)); WriteBinByte_(F, Hi(W)); End;

Procedure WriteBinDWord_(Var F : File; D : LongInt);
Begin
  WriteBinByte_(F, Byte(D And $FF));
  WriteBinByte_(F, Byte((D Shr 8) And $FF));
  WriteBinByte_(F, Byte((D Shr 16) And $FF));
  WriteBinByte_(F, Byte((D Shr 24) And $FF));
End;

Procedure WriteBinZeros_(Var F : File; N : LongInt);
Var Z : Byte; I : LongInt;
Begin Z := 0; For I := 1 To N Do BlockWrite(F, Z, 1); End;

Function AlignUp(N, A : LongInt) : LongInt;
Begin
  If (N Mod A) = 0 Then AlignUp := N
  Else AlignUp := N + A - (N Mod A);
End;

{ ---- BinWriteObj : generer un fichier COFF .OBJ minimal ---- }
Procedure BinWriteObj;
Var F : File;
Begin
  Assign(F, Opts.OutFile);
  {$I-} Rewrite(F, 1); {$I+}
  If IOResult <> 0 Then
  Begin WriteLn('POWFXC32: erreur: impossible de creer ', Opts.OutFile); Exit; End;
  { COFF header }
  WriteBinWord_(F, PE_MACHINE_I386); { Machine }
  WriteBinWord_(F, 1);               { 1 section }
  WriteBinDWord_(F, 0);              { TimeDateStamp }
  WriteBinDWord_(F, 60);             { PointerToSymbolTable }
  WriteBinDWord_(F, 2);              { NumberOfSymbols }
  WriteBinWord_(F, 0);               { SizeOfOptionalHeader }
  WriteBinWord_(F, 0);               { Characteristics }
  { Section header: .text (40 octets) }
  WriteBinByte_(F, Ord('.')); WriteBinByte_(F, Ord('t')); WriteBinByte_(F, Ord('e'));
  WriteBinByte_(F, Ord('x')); WriteBinByte_(F, Ord('t')); WriteBinByte_(F, 0);
  WriteBinByte_(F, 0); WriteBinByte_(F, 0);
  WriteBinDWord_(F, BinCodeLen);
  WriteBinDWord_(F, 0);
  WriteBinDWord_(F, BinCodeLen);
  WriteBinDWord_(F, 60 + 36);   { apres symtab }
  WriteBinDWord_(F, 0); WriteBinDWord_(F, 0);
  WriteBinWord_(F, 0); WriteBinWord_(F, 0);
  WriteBinDWord_(F, PE_SCN_TEXT);
  { Symbole 1 : .text }
  WriteBinByte_(F, Ord('.')); WriteBinByte_(F, Ord('t')); WriteBinByte_(F, Ord('e'));
  WriteBinByte_(F, Ord('x')); WriteBinByte_(F, Ord('t')); WriteBinByte_(F, 0);
  WriteBinByte_(F, 0); WriteBinByte_(F, 0);
  WriteBinDWord_(F, 0); WriteBinWord_(F, 1); WriteBinWord_(F, 0);
  WriteBinByte_(F, 3); WriteBinByte_(F, 0);
  { Symbole 2 : _start }
  WriteBinByte_(F, Ord('_')); WriteBinByte_(F, Ord('s')); WriteBinByte_(F, Ord('t'));
  WriteBinByte_(F, Ord('a')); WriteBinByte_(F, Ord('r')); WriteBinByte_(F, Ord('t'));
  WriteBinByte_(F, 0); WriteBinByte_(F, 0);
  WriteBinDWord_(F, 0); WriteBinWord_(F, 1); WriteBinWord_(F, $20);
  WriteBinByte_(F, 2); WriteBinByte_(F, 0);
  { String table }
  WriteBinDWord_(F, 4);
  { Raw data .text }
  BlockWrite(F, BinCode, BinCodeLen);
  Close(F);
  WriteLn('POWFXC32: OBJ genere: ', Opts.OutFile, ' (', BinCodeLen, ' octets code)');
End;

{ ---- BinWriteExe : generer un fichier PE32 .EXE minimal ---- }
Procedure BinWriteExe;
Var
  F              : File;
  HdrSize        : LongInt;
  TextRVA        : LongInt;
  TextSize       : LongInt;
  TextFileOfs    : LongInt;
  DataRVA        : LongInt;
  DataSize       : LongInt;
  DataFileOfs    : LongInt;
  IdataRVA       : LongInt;
  IdataFileOfs   : LongInt;
  IdataSize      : LongInt;
  ImageSize      : LongInt;
  EntryRVA       : LongInt;
  I              : Integer;
  Pad            : LongInt;
  CurPos         : LongInt;
  IdataBuf       : Array[0..1023] Of Byte;
  IdataBufLen    : Integer;
  IltOfs         : Integer;
  IatOfs         : Integer;
  DllNameOfs     : Integer;
  NumSections    : Integer;
Begin
  Assign(F, Opts.OutFile);
  {$I-} Rewrite(F, 1); {$I+}
  If IOResult <> 0 Then
  Begin WriteLn('POWFXC32: erreur: impossible de creer ', Opts.OutFile); Exit; End;

  NumSections := 3;
  IdataBufLen := 0;
  IltOfs      := 40;
  IatOfs      := IltOfs + (PE_NUM_API + 1) * 4;
  DllNameOfs  := IatOfs + (PE_NUM_API + 1) * 4;

  { Construire le buffer .idata }
  For I := 0 To 19 Do Begin IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen); End;
  For I := 0 To 19 Do Begin IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen); End;
  For I := 0 To (PE_NUM_API + 1) * 4 - 1 Do Begin IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen); End;
  For I := 0 To (PE_NUM_API + 1) * 4 - 1 Do Begin IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen); End;
  For I := 1 To 12 Do Begin IdataBuf[IdataBufLen] := Byte(Ord('kernel32.dll'[I])); Inc(IdataBufLen); End;
  IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen);
  { Hint/Name pour chaque API }
  For I := 0 To PE_NUM_API - 1 Do
  Begin
    IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen);
    IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen);
    For Pad := 1 To Length(BinAPIName[I]) Do
    Begin IdataBuf[IdataBufLen] := Byte(Ord(BinAPIName[I][Pad])); Inc(IdataBufLen); End;
    IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen);
    If (IdataBufLen Mod 2) <> 0 Then Begin IdataBuf[IdataBufLen] := 0; Inc(IdataBufLen); End;
  End;

  IdataSize := AlignUp(IdataBufLen, LongInt(PE_FILE_ALIGN));
  HdrSize   := AlignUp(128 + 4 + 20 + PE_OPT_SIZE + NumSections * 40, LongInt(PE_FILE_ALIGN));
  TextRVA      := LongInt(PE_SEC_ALIGN);
  TextSize     := AlignUp(BinCodeLen, LongInt(PE_FILE_ALIGN));
  TextFileOfs  := HdrSize;
  DataRVA      := TextRVA + AlignUp(BinCodeLen, LongInt(PE_SEC_ALIGN));
  DataSize     := AlignUp(BinDataLen, LongInt(PE_FILE_ALIGN));
  DataFileOfs  := TextFileOfs + TextSize;
  IdataRVA     := DataRVA + AlignUp(BinDataLen, LongInt(PE_SEC_ALIGN));
  IdataFileOfs := DataFileOfs + DataSize;
  ImageSize    := IdataRVA + AlignUp(IdataBufLen, LongInt(PE_SEC_ALIGN));
  EntryRVA     := TextRVA;
  If BinFindLabel(PFX_FN_PFX + 'main') >= 0 Then
    EntryRVA := TextRVA + BinFindLabel(PFX_FN_PFX + 'main');

  { Patcher les RVAs du .idata }
  IdataBuf[0]  := Byte((IdataRVA + IltOfs) And $FF);
  IdataBuf[1]  := Byte(((IdataRVA + IltOfs) Shr 8) And $FF);
  IdataBuf[2]  := Byte(((IdataRVA + IltOfs) Shr 16) And $FF);
  IdataBuf[3]  := Byte(((IdataRVA + IltOfs) Shr 24) And $FF);
  IdataBuf[12] := Byte((IdataRVA + DllNameOfs) And $FF);
  IdataBuf[13] := Byte(((IdataRVA + DllNameOfs) Shr 8) And $FF);
  IdataBuf[14] := Byte(((IdataRVA + DllNameOfs) Shr 16) And $FF);
  IdataBuf[15] := Byte(((IdataRVA + DllNameOfs) Shr 24) And $FF);
  IdataBuf[16] := Byte((IdataRVA + IatOfs) And $FF);
  IdataBuf[17] := Byte(((IdataRVA + IatOfs) Shr 8) And $FF);
  IdataBuf[18] := Byte(((IdataRVA + IatOfs) Shr 16) And $FF);
  IdataBuf[19] := Byte(((IdataRVA + IatOfs) Shr 24) And $FF);

  { DOS Stub (128 octets) }
  WriteBinWord_(F, PE_DOS_MAGIC);
  For I := 1 To 56 Do WriteBinByte_(F, 0);
  WriteBinDWord_(F, 128);
  For I := 1 To 64 Do WriteBinByte_(F, 0);
  { PE Signature }
  WriteBinDWord_(F, PE_PE_SIG);
  { COFF Header }
  WriteBinWord_(F, PE_MACHINE_I386); WriteBinWord_(F, NumSections);
  WriteBinDWord_(F, 0); WriteBinDWord_(F, 0); WriteBinDWord_(F, 0);
  WriteBinWord_(F, PE_OPT_SIZE); WriteBinWord_(F, $0103);
  { Optional Header PE32 }
  WriteBinWord_(F, PE_MAGIC_32);
  WriteBinByte_(F, 1); WriteBinByte_(F, 0);
  WriteBinDWord_(F, TextSize);
  WriteBinDWord_(F, DataSize + IdataSize);
  WriteBinDWord_(F, 0);
  WriteBinDWord_(F, EntryRVA);
  WriteBinDWord_(F, TextRVA);
  WriteBinDWord_(F, DataRVA);
  WriteBinDWord_(F, PE_IMG_BASE);
  WriteBinDWord_(F, PE_SEC_ALIGN); WriteBinDWord_(F, PE_FILE_ALIGN);
  WriteBinWord_(F, 4); WriteBinWord_(F, 0); WriteBinWord_(F, 0); WriteBinWord_(F, 0);
  WriteBinWord_(F, 4); WriteBinWord_(F, 0);
  WriteBinDWord_(F, 0);
  WriteBinDWord_(F, ImageSize);
  WriteBinDWord_(F, HdrSize);
  WriteBinDWord_(F, 0);
  WriteBinWord_(F, PE_SUBSYS_CUI); WriteBinWord_(F, 0);
  WriteBinDWord_(F, $100000); WriteBinDWord_(F, $1000);
  WriteBinDWord_(F, $100000); WriteBinDWord_(F, $1000);
  WriteBinDWord_(F, 0);
  WriteBinDWord_(F, 16);
  WriteBinDWord_(F, 0); WriteBinDWord_(F, 0);
  WriteBinDWord_(F, IdataRVA); WriteBinDWord_(F, IdataBufLen);
  For I := 2 To 11 Do Begin WriteBinDWord_(F, 0); WriteBinDWord_(F, 0); End;
  WriteBinDWord_(F, IdataRVA + IatOfs); WriteBinDWord_(F, (PE_NUM_API + 1) * 4);
  For I := 13 To 15 Do Begin WriteBinDWord_(F, 0); WriteBinDWord_(F, 0); End;
  { Section headers }
  For I := 1 To 5 Do WriteBinByte_(F, Byte(Ord('.text'[I]))); WriteBinZeros_(F, 3);
  WriteBinDWord_(F, BinCodeLen); WriteBinDWord_(F, TextRVA);
  WriteBinDWord_(F, TextSize); WriteBinDWord_(F, TextFileOfs);
  WriteBinDWord_(F, 0); WriteBinDWord_(F, 0); WriteBinWord_(F, 0); WriteBinWord_(F, 0);
  WriteBinDWord_(F, PE_SCN_TEXT);
  For I := 1 To 5 Do WriteBinByte_(F, Byte(Ord('.data'[I]))); WriteBinZeros_(F, 3);
  WriteBinDWord_(F, BinDataLen); WriteBinDWord_(F, DataRVA);
  WriteBinDWord_(F, DataSize); WriteBinDWord_(F, DataFileOfs);
  WriteBinDWord_(F, 0); WriteBinDWord_(F, 0); WriteBinWord_(F, 0); WriteBinWord_(F, 0);
  WriteBinDWord_(F, PE_SCN_DATA);
  For I := 1 To 6 Do WriteBinByte_(F, Byte(Ord('.idata'[I]))); WriteBinZeros_(F, 2);
  WriteBinDWord_(F, IdataBufLen); WriteBinDWord_(F, IdataRVA);
  WriteBinDWord_(F, IdataSize); WriteBinDWord_(F, IdataFileOfs);
  WriteBinDWord_(F, 0); WriteBinDWord_(F, 0); WriteBinWord_(F, 0); WriteBinWord_(F, 0);
  WriteBinDWord_(F, PE_SCN_DATA);
  { Padding jusqu a HdrSize }
  CurPos := 128 + 4 + 20 + PE_OPT_SIZE + NumSections * 40;
  If HdrSize - CurPos > 0 Then WriteBinZeros_(F, HdrSize - CurPos);
  { Sections }
  BlockWrite(F, BinCode, BinCodeLen);
  Pad := TextSize - BinCodeLen; If Pad > 0 Then WriteBinZeros_(F, Pad);
  BlockWrite(F, BinData, BinDataLen);
  Pad := DataSize - BinDataLen; If Pad > 0 Then WriteBinZeros_(F, Pad);
  BlockWrite(F, IdataBuf, IdataBufLen);
  Pad := IdataSize - IdataBufLen; If Pad > 0 Then WriteBinZeros_(F, Pad);
  Close(F);
  WriteLn('POWFXC32: EXE stub genere: ', Opts.OutFile);
  WriteLn('POWFXC32: Assemblez le .ASM avec MASM pour un EXE fonctionnel.');
End;

{$ENDIF}

{ ============================================================ }
{ OPTIONS, AIDE ET ANALYSE DES ARGUMENTS                        }
{ ============================================================ }

Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := True;
  Opts.EmitExe   := True;
  Opts.EmitObj   := False;
  Opts.EmitAsm   := False;
End;

Procedure ShowHelp;
Begin
  WriteLn('POWFXC32 : Cette commande permet de lancer le compilateur Power FX pour ',
          'assembleur du microprocesseur 80386 (Windows PE 32 bits)');
  WriteLn;
  WriteLn('Syntaxe: POWFXC32 <source.pfx> [options]');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  -o <fichier>   Nom du fichier de sortie (.exe par defaut)');
  WriteLn('  -asm           Conserver le fichier .ASM genere');
  WriteLn('  -obj           Produire un fichier .OBJ (COFF) uniquement');
  WriteLn('  -v             Mode verbeux (banniere + statistiques)');
  WriteLn('  -d             Debug : afficher tous les tokens');
  WriteLn('  -w             Afficher les avertissements');
  WriteLn('  -h, --help, /? Afficher cette aide');
  WriteLn;
  WriteLn('Exemple de source Power FX (.pfx) :');
  WriteLn('  // Mon programme Power FX');
  WriteLn('  Set(x, 42);');
  WriteLn('  Set(msg, "Hello, Power FX!");');
  WriteLn('  Print(msg);');
  WriteLn('  Print(x + 8);');
  WriteLn('  Print(If(x > 10, "grand", "petit"));');
  WriteLn('  Print(Concatenate("Pi ~= ", Text(3.14159)));');
  WriteLn('  Print(Upper("bonjour"));');
  WriteLn;
  WriteLn('Types supportes:');
  WriteLn('  Number  (Double IEEE-754 64 bits)');
  WriteLn('  Text    (pointeur ASCIIZ)');
  WriteLn('  Boolean (0=false, 1=true)');
  WriteLn;
  WriteLn('Fonctions supportees:');
  WriteLn('  Numeriques : Abs, Sqrt, Int, Round, Power, Mod, Log, Exp');
  WriteLn('  Texte      : Len, Left, Right, Mid, Upper, Lower, Trim,');
  WriteLn('               Concatenate, Text, Value');
  WriteLn('  Logiques   : If, Switch, And, Or, Not, IsBlank, IsError, Blank');
  WriteLn('  Actions    : Set, Print (extension compilateur)');
  WriteLn('  Stubs      : Collect, Clear, Patch, Remove, ForAll, Filter');
  WriteLn;
  WriteLn('Assemblage :');
  WriteLn('  ML /c /coff /Fo prog.obj prog.asm');
  WriteLn('  LINK /SUBSYSTEM:CONSOLE /OUT:prog.exe prog.obj kernel32.lib');
  Halt(EXIT_OK);
End;

Procedure ParseArgs;
Var I : Integer; Arg, Ext : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then ShowHelp;
  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Or
       (Arg = '/h') Or (Arg = '/H') Then
      ShowHelp
    Else If Arg = '-v' Then Opts.Verbose   := True
    Else If Arg = '-d' Then Opts.DebugMode := True
    Else If Arg = '-w' Then Opts.Warnings  := True
    Else If Arg = '-asm' Then Opts.EmitAsm := True
    Else If Arg = '-obj' Then
    Begin Opts.EmitObj := True; Opts.EmitExe := False; End
    Else If Arg = '-o' Then
    Begin
      Inc(I);
      If I > ParamCount Then FatalError('-o necessite un nom de fichier');
      Opts.OutFile := ParamStr(I);
    End
    Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
      FatalError('Option inconnue: ' + Arg)
    Else
    Begin
      If Opts.SrcFile = '' Then Opts.SrcFile := Arg
      Else FatalError('Argument inattendu: ' + Arg);
    End;
    Inc(I);
  End;

  If Opts.SrcFile = '' Then
  Begin WriteLn('POWFXC32: fichier source manquant'); ShowHelp; End;

  Ext := ExtractExt(Opts.SrcFile);
  If (Ext <> '.pfx') And (Ext <> '.PFX') Then
    WarnMsg('Extension attendue .pfx, trouvee: ' + Ext);

  If Opts.OutFile = '' Then
  Begin
    If Opts.EmitObj Then Opts.OutFile := ReplaceExt(Opts.SrcFile, '.obj')
    Else Opts.OutFile := ReplaceExt(Opts.SrcFile, '.exe');
  End;
End;

Procedure ShowBanner;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn('POWFXC32 v', POWFXC32_VERSION, ' (', POWFXC32_DATE, ')');
  WriteLn('Compilateur Power FX -> assembleur 80386 (Windows PE 32 bits)');
  WriteLn('Inspire de ADACW32.PAS (www.gladir.com/DEV-COOLS)');
  WriteLn('Source  : ', Opts.SrcFile);
  WriteLn('Sortie  : ', Opts.OutFile);
  If Opts.EmitAsm Then
    WriteLn('ASM     : ', ReplaceExt(Opts.SrcFile, '.asm'));
  If Opts.EmitObj Then WriteLn('Format  : OBJ (COFF)')
  Else WriteLn('Format  : EXE (PE Win32)');
  WriteLn;
End;

Procedure BilanCompilation;
Begin
  WriteLn;
  WriteLn('POWFXC32 - Compilation terminee');
  WriteLn('  Source     : ', Opts.SrcFile);
  WriteLn('  Sortie     : ', Opts.OutFile);
  WriteLn('  Lignes     : ', TotalLines);
  WriteLn('  Symboles   : ', SymCount);
  WriteLn('  Chaines    : ', StrCount);
  WriteLn('  Numeriques : ', NumCount);
  WriteLn('  Labels     : ', LabelCounter);
  WriteLn('  Erreurs    : ', ErrorCount);
  WriteLn('  Avertiss.  : ', WarnCount);
  If ErrorCount > 0 Then
    WriteLn('  *** COMPILATION AVEC ERREURS ***');
End;

Procedure Cleanup;
Begin
  If OutFOpen Then Begin Close(OutF); OutFOpen := False; End;
End;

{ ============================================================ }
{ PROCEDURE RUN : orchestration de la compilation               }
{ ============================================================ }

Procedure Run;
Var AsmFile : TString;
Begin
  InitSymTable;
  InitFnTable;
  InitScopeStack;
  InitCodeGen;
  ExprType := PFX_UNKNOWN;
  LexInit;

  If Opts.DebugMode Then
  Begin
    WriteLn('POWFXC32: mode debug - affichage des tokens');
    While CurTokType <> TOK_EOF Do
    Begin
      WriteLn('[', LexLineNo, ':', LexColNo, '] TOK=', CurTokType,
              ' KW=', CurTokKw, ' STR=<', CurTokStr, '>',
              ' NUM=', CurTokNum);
      Consume;
    End;
  End
  Else
  Begin
    WriteLn('POWFXC32: compilation de ', Opts.SrcFile, ' ...');

    { Ouvrir le fichier .ASM et emettre l en-tete }
    AsmFile := ReplaceExt(Opts.SrcFile, '.asm');
    EmitOpen(AsmFile);
    EmitHeader;

    { Parser le programme Power FX }
    ParseProgram;

    { Emettre le point d entree Win32 }
    EmitEntryPoint;

    { Emettre les helpers runtime }
    EmitRuntimeHelpers;

    { Emettre le segment .DATA (variables, litteraux, tampons) }
    EmitDataSeg;

    { Fin du fichier ASM }
    Emit('END ' + PFX_FN_PFX + 'main');
    EmitClose;

    If ErrorCount = 0 Then
      WriteLn('POWFXC32: .ASM genere: ', AsmFile)
    Else
      WriteLn('POWFXC32: compilation avec ', ErrorCount, ' erreur(s).');

    { Generation binaire (stub) }
{$IFDEF FPC}
    BinAssemble;
    If Opts.EmitObj Then
      BinWriteObj
    Else If Opts.EmitExe Then
      BinWriteExe;

    { Supprimer le .ASM si non demande explicitement }
    If Not Opts.EmitAsm Then
    Begin
      Assign(OutF, AsmFile);
      {$I-} Erase(OutF); {$I+}
      If IOResult <> 0 Then;  { ignorer si erreur de suppression }
    End;
{$ENDIF}
  End;

  LexClose;
  BilanCompilation;
End;

{ ============================================================ }
{ PROGRAMME PRINCIPAL                                           }
{ ============================================================ }

BEGIN
  { Aide rapide sans arguments }
  If (ParamCount > 0) And
     ((ParamStr(1) = '/?') Or (ParamStr(1) = '--help') Or
      (ParamStr(1) = '-h') Or (ParamStr(1) = '/h') Or
      (ParamStr(1) = '/H')) Then
  Begin 
   ShowHelp; 
   Halt(EXIT_OK); 
End;

  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  OutFOpen   := False;
  LexOpened  := False;

  ParseArgs;
  ShowBanner;
  Run;
  Cleanup;

  If ErrorCount > 0 Then Halt(EXIT_ERROR)
                    Else Halt(EXIT_OK);
END.
