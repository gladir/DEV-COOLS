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
  EmitI(PFX_RT_PFX + 'CRLFBUF  DB 13, 10, 0');     { CR+LF (nom distinct de la procedure CRLF) }
  EmitI(PFX_RT_PFX + 'HSTDOUT  DD 0');             { handle stdout }
  EmitI(PFX_RT_PFX + 'HSTDIN   DD 0');             { handle stdin }
  EmitI(PFX_RT_PFX + 'WRITTEN  DD 0');             { octets ecrits }
  EmitI(PFX_RT_PFX + 'READCNT  DD 0');             { octets lus }
  EmitI(PFX_RT_PFX + 'DBLTMP   DQ 0');             { Double temporaire 64 bits }
  EmitI(PFX_RT_PFX + 'ITMP     DD 0');             { Entier temporaire 32 bits }
  EmitI(PFX_RT_PFX + 'DBL_LN2  DQ 0.693147180559945'); { ln(2) pour LOG }
  EmitI(PFX_RT_PFX + 'DBL_E    DQ 2.718281828459045'); { e }
  EmitI(PFX_RT_PFX + 'DBL_TEN  DQ 10.0'); { pour extraction des decimales dans NUMTOSTR }
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
  EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'CRLFBUF]');
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
  EmitI('LEA  ESI, DWORD PTR [' + PFX_RT_PFX + 'NUMBUF+30]'); { buffer temp }
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
  EmitI('FMUL QWORD PTR [' + PFX_RT_PFX + 'DBL_TEN]'); { frac *= 10 }
  EmitI('FLD  ST(0)');                { dupliquer : ST(0)=frac*10, ST(1)=frac*10 }
  EmitI('FISTP DWORD PTR [' + PFX_RT_PFX + 'ITMP]'); { pop la copie -> chiffre entier }
  EmitI('MOV  EAX, DWORD PTR [' + PFX_RT_PFX + 'ITMP]');
  { Clamp 0-9 : AND EAX,9 n est PAS un clamp valide (ex: 4 AND 9 = 0) et  }
  { corrompait la plupart des chiffres. Un vrai clamp est necessaire aux }
  { deux bornes : l arrondi-par-chiffre peut produire un reste legerement}
  { negatif apres quelques iterations (derive d erreur flottante), et    }
  { occasionnellement 10 (arrondi pile a la limite).                    }
  L1 := NewLabel;
  L2 := NewLabel;
  EmitI('CMP  EAX, 0');
  EmitI('JGE  ' + L2);
  EmitI('XOR  EAX, EAX');
  EmitLabel(L2);
  EmitI('CMP  EAX, 9');
  EmitI('JLE  ' + L1);
  EmitI('MOV  EAX, 9');
  EmitLabel(L1);
  EmitI('ADD  AL, 48');
  EmitI('MOV  BYTE PTR [EDI], AL');
  EmitI('INC  EDI');
  EmitI('FILD DWORD PTR [' + PFX_RT_PFX + 'ITMP]'); { ST(0)=chiffre, ST(1)=frac*10 }
  EmitI('FSUBP ST(1), ST(0)');       { ST(0) = frac*10 - chiffre = reste }
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
  { A l entree reelle : ST(0)=exposant, ST(1)=base (le site d appel evalue }
  { la base avant l exposant). FYL2X exige ST(0)=base, ST(1)=exp : on      }
  { echange donc les deux avant de calculer.                              }
  EmitI('FXCH ST(1)');
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
  EmitI('LEA  EAX, DWORD PTR [' + PFX_RT_PFX + 'INPUTBUF+254]');
  EmitI('PUSH EAX');
  EmitI('PUSH DWORD PTR [' + PFX_RT_PFX + 'HSTDIN]');
  EmitI('CALL _ReadFile@20');
  EmitI('MOV  EAX, DWORD PTR [' + PFX_RT_PFX + 'READCNT]');
  EmitI('TEST EAX, EAX');
  EmitI('JZ   ' + LE);
  EmitI('MOVZX EAX, BYTE PTR [' + PFX_RT_PFX + 'INPUTBUF+254]');
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
            { Chaque CALL STRCAT nettoie deja sa propre pile (RET 8) et       }
            { renvoie le resultat dans EAX. On repousse ce resultat pour     }
            { l iteration suivante afin de chainer correctement 3+ arguments }
            { (Concatenate(a,b,c,...)), puis on le recupere une fois la      }
            { boucle terminee.                                              }
            If CurTokType = TOK_COMMA Then
            Begin
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
                EmitI('PUSH EAX');
              End;
              EmitI('POP  EAX');
            End;
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

{ ============================================================ }
{ ASSEMBLEUR X86 INTEGRE (encodeur d instructions -> BinCode)   }
{ ============================================================ }
{ Encode directement le texte .ASM (syntaxe MASM generee par ce }
{ compilateur) en code machine 80386, sans dependance externe. }

Function AsmRegIdx32(Const S : String) : Integer;
Begin
  If S = 'EAX' Then AsmRegIdx32 := 0
  Else If S = 'ECX' Then AsmRegIdx32 := 1
  Else If S = 'EDX' Then AsmRegIdx32 := 2
  Else If S = 'EBX' Then AsmRegIdx32 := 3
  Else If S = 'ESP' Then AsmRegIdx32 := 4
  Else If S = 'EBP' Then AsmRegIdx32 := 5
  Else If S = 'ESI' Then AsmRegIdx32 := 6
  Else If S = 'EDI' Then AsmRegIdx32 := 7
  Else AsmRegIdx32 := -1;
End;

Function AsmRegIdx8(Const S : String) : Integer;
Begin
  If S = 'AL' Then AsmRegIdx8 := 0
  Else If S = 'CL' Then AsmRegIdx8 := 1
  Else If S = 'DL' Then AsmRegIdx8 := 2
  Else If S = 'BL' Then AsmRegIdx8 := 3
  Else AsmRegIdx8 := -1;
End;

Function AsmFindAPI(Const S : String) : Integer;
Var I : Integer;
Begin
  AsmFindAPI := -1;
  For I := 0 To PE_NUM_API - 1 Do
    If S = BinAPIDecorated[I] Then
    Begin
      AsmFindAPI := I;
      Exit;
    End;
End;

Function AsmParseImm(Const S : String) : LongInt;
Var Code : Integer; V : LongInt;
Begin
  Val(S, V, Code);
  If Code = 0 Then AsmParseImm := V
  Else AsmParseImm := 0;
End;

{ Parse un litteral Double MASM (ex: '0' ou '0.693147180559945') et retourne
  ses 8 octets IEEE-754 (little-endian) dans Out8. Utilise pour DQ. }
Procedure AsmParseDouble(Const S : String; Var Out8 : Array of Byte);
Var D : Double; Err : Integer;
    Bytes : Array[0..7] Of Byte;
    Db : Double Absolute Bytes;
    I : Integer;
Begin
  Val(S, D, Err);
  If Err <> 0 Then D := 0.0;
  Db := D;
  For I := 0 To 7 Do Out8[I] := Bytes[I];
End;

{ Retourne True si le contenu du crochet reference un registre (pas un label) }
Function AsmIsRegBased(Const S : String) : Boolean;
Var Base : String;
    I : Integer;
Begin
  AsmIsRegBased := False;
  Base := S;
  For I := 1 To Length(Base) Do
    If (Base[I] = '+') Or (Base[I] = '-') Or (Base[I] = '*') Then
    Begin
      Base := Copy(Base, 1, I - 1);
      Break;
    End;
  While (Length(Base) > 0) And (Base[Length(Base)] = ' ') Do
    Delete(Base, Length(Base), 1);
  AsmIsRegBased := (AsmRegIdx32(Base) >= 0);
End;

Function AsmTrimLine(Const S : String) : String;
Var I, J, K : Integer; R : String;
Begin
  R := S;
  K := 0;
  For I := 1 To Length(R) Do
    If R[I] = ';' Then Begin K := I; Break; End;
  If K > 0 Then R := Copy(R, 1, K - 1);
  I := 1;
  While (I <= Length(R)) And ((R[I] = ' ') Or (R[I] = #9)) Do Inc(I);
  J := Length(R);
  While (J >= I) And ((R[J] = ' ') Or (R[J] = #9)) Do Dec(J);
  If I > J Then AsmTrimLine := ''
  Else AsmTrimLine := Copy(R, I, J - I + 1);
End;

Function AsmIsLabel(Const S : String) : Boolean;
Begin
  AsmIsLabel := (Length(S) > 1) And (S[Length(S)] = ':');
End;

Function AsmExtractLabel(Const S : String) : String;
Begin
  AsmExtractLabel := Copy(S, 1, Length(S) - 1);
End;

Function AsmStartsWith(Const S, Prefix : String) : Boolean;
Var I : Integer;
Begin
  AsmStartsWith := False;
  If Length(S) < Length(Prefix) Then Exit;
  For I := 1 To Length(Prefix) Do
    If S[I] <> Prefix[I] Then Exit;
  AsmStartsWith := True;
End;

Function AsmGetMnemonic(Const S : String) : String;
Var I : Integer;
Begin
  I := 1;
  While (I <= Length(S)) And (S[I] <> ' ') And (S[I] <> #9) Do Inc(I);
  AsmGetMnemonic := Copy(S, 1, I - 1);
End;

Function AsmGetOperands(Const S : String) : String;
Var I : Integer;
Begin
  I := 1;
  While (I <= Length(S)) And (S[I] <> ' ') And (S[I] <> #9) Do Inc(I);
  While (I <= Length(S)) And ((S[I] = ' ') Or (S[I] = #9)) Do Inc(I);
  If I > Length(S) Then AsmGetOperands := ''
  Else AsmGetOperands := Copy(S, I, Length(S) - I + 1);
End;

Procedure AsmSplitOps(Const S : String; Var Op1, Op2 : String);
Var I : Integer;
Begin
  Op1 := ''; Op2 := '';
  I := 1;
  While (I <= Length(S)) And (S[I] <> ',') Do
  Begin
    Op1 := Op1 + S[I];
    Inc(I);
  End;
  While (Length(Op1) > 0) And (Op1[Length(Op1)] = ' ') Do
    Delete(Op1, Length(Op1), 1);
  If I <= Length(S) Then
  Begin
    Inc(I);
    While (I <= Length(S)) And (S[I] = ' ') Do Inc(I);
    Op2 := Copy(S, I, Length(S) - I + 1);
    While (Length(Op2) > 0) And (Op2[Length(Op2)] = ' ') Do
      Delete(Op2, Length(Op2), 1);
  End;
End;

Function AsmExtractBracket(Const S : String) : String;
Var I, Start : Integer;
Begin
  AsmExtractBracket := '';
  Start := 0;
  For I := 1 To Length(S) Do
    If S[I] = '[' Then Begin Start := I + 1; Break; End;
  If Start = 0 Then Exit;
  I := Start;
  While (I <= Length(S)) And (S[I] <> ']') Do Inc(I);
  AsmExtractBracket := Copy(S, Start, I - Start);
End;

{ Encode une reference memoire a l interieur des crochets.
  RegField = champ reg du ModRM/SIB. }
Procedure AsmEncodeMemory(Const Bracket : String; RegField : Integer);
Var
  PlusPos, MinusPos, I : Integer;
  Base, Idx : String;
  BaseR, IdxR : Integer;
  Disp : LongInt;
  StarP, PlusP2, ScaleV, ScaleF : Integer;
  IdxName, ScaleAndRest, ScaleStr, DispStr : String;
Begin
  PlusPos := 0; MinusPos := 0;
  For I := 1 To Length(Bracket) Do
  Begin
    If (Bracket[I] = '+') And (PlusPos = 0) Then PlusPos := I;
    If (Bracket[I] = '-') And (MinusPos = 0) Then MinusPos := I;
  End;

  If (PlusPos = 0) And (MinusPos = 0) Then
  Begin
    { Simple: [reg] ou [label] }
    BaseR := AsmRegIdx32(Bracket);
    If BaseR >= 0 Then
    Begin
      If BaseR = 5 Then
      Begin { [EBP] necessite mod=01 disp8=0 }
        BinEmitByte((1 Shl 6) Or (RegField Shl 3) Or 5);
        BinEmitByte(0);
      End
      Else If BaseR = 4 Then
      Begin { [ESP] necessite SIB }
        BinEmitByte((0 Shl 6) Or (RegField Shl 3) Or 4);
        BinEmitByte($24);
      End
      Else
        BinEmitByte((0 Shl 6) Or (RegField Shl 3) Or BaseR);
    End
    Else
    Begin { [label] = [disp32] }
      BinEmitByte((0 Shl 6) Or (RegField Shl 3) Or 5);
      BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
      BinEmitDWord(0);
    End;
  End
  Else If PlusPos > 0 Then
  Begin
    Base := Copy(Bracket, 1, PlusPos - 1);
    Idx := Copy(Bracket, PlusPos + 1, Length(Bracket) - PlusPos);
    While (Length(Base) > 0) And (Base[Length(Base)] = ' ') Do
      Delete(Base, Length(Base), 1);
    While (Length(Idx) > 0) And (Idx[1] = ' ') Do
      Delete(Idx, 1, 1);
    BaseR := AsmRegIdx32(Base);
    IdxR := AsmRegIdx32(Idx);
    If (BaseR >= 0) And (IdxR >= 0) Then
    Begin { [base+index] necessite SIB }
      If BaseR = 5 Then
      Begin { [EBP+index] necessite mod=01 disp8=0 }
        BinEmitByte((1 Shl 6) Or (RegField Shl 3) Or 4);
        BinEmitByte((0 Shl 6) Or (IdxR Shl 3) Or BaseR);
        BinEmitByte(0);
      End
      Else
      Begin
        BinEmitByte((0 Shl 6) Or (RegField Shl 3) Or 4);
        BinEmitByte((0 Shl 6) Or (IdxR Shl 3) Or BaseR);
      End;
    End
    Else If (BaseR >= 0) And (Pos('*', Idx) > 0) Then
    Begin { [base+index*scale] ou [base+index*scale+disp] }
      Disp := 0;
      StarP := Pos('*', Idx);
      IdxName := Copy(Idx, 1, StarP - 1);
      While (Length(IdxName) > 0) And (IdxName[Length(IdxName)] = ' ') Do
        Delete(IdxName, Length(IdxName), 1);
      ScaleAndRest := Copy(Idx, StarP + 1, Length(Idx) - StarP);
      While (Length(ScaleAndRest) > 0) And (ScaleAndRest[1] = ' ') Do
        Delete(ScaleAndRest, 1, 1);
      PlusP2 := Pos('+', ScaleAndRest);
      If PlusP2 > 0 Then
      Begin
        ScaleStr := Copy(ScaleAndRest, 1, PlusP2 - 1);
        DispStr := Copy(ScaleAndRest, PlusP2 + 1, Length(ScaleAndRest) - PlusP2);
        ScaleV := AsmParseImm(ScaleStr);
        Disp := AsmParseImm(DispStr);
      End
      Else
      Begin
        ScaleV := AsmParseImm(ScaleAndRest);
        Disp := 0;
      End;
      IdxR := AsmRegIdx32(IdxName);
      Case ScaleV Of
        1: ScaleF := 0;
        2: ScaleF := 1;
        4: ScaleF := 2;
        8: ScaleF := 3;
      Else ScaleF := 0;
      End;
      If (Disp = 0) And (BaseR <> 5) Then
      Begin
        BinEmitByte((0 Shl 6) Or (RegField Shl 3) Or 4);
        BinEmitByte((ScaleF Shl 6) Or (IdxR Shl 3) Or BaseR);
      End
      Else If (Disp >= -128) And (Disp <= 127) Then
      Begin
        BinEmitByte((1 Shl 6) Or (RegField Shl 3) Or 4);
        BinEmitByte((ScaleF Shl 6) Or (IdxR Shl 3) Or BaseR);
        BinEmitByte(Byte(Disp And $FF));
      End
      Else
      Begin
        BinEmitByte((2 Shl 6) Or (RegField Shl 3) Or 4);
        BinEmitByte((ScaleF Shl 6) Or (IdxR Shl 3) Or BaseR);
        BinEmitDWord(Disp);
      End;
    End
    Else If BaseR >= 0 Then
    Begin { [base+disp] }
      Disp := AsmParseImm(Idx);
      If (Disp >= -128) And (Disp <= 127) Then
      Begin
        If BaseR = 4 Then
        Begin
          BinEmitByte((1 Shl 6) Or (RegField Shl 3) Or 4);
          BinEmitByte($24);
        End
        Else
          BinEmitByte((1 Shl 6) Or (RegField Shl 3) Or BaseR);
        BinEmitByte(Byte(Disp And $FF));
      End
      Else
      Begin
        If BaseR = 4 Then
        Begin
          BinEmitByte((2 Shl 6) Or (RegField Shl 3) Or 4);
          BinEmitByte($24);
        End
        Else
          BinEmitByte((2 Shl 6) Or (RegField Shl 3) Or BaseR);
        BinEmitDWord(Disp);
      End;
    End;
  End
  Else
  Begin { [base-disp] }
    Base := Copy(Bracket, 1, MinusPos - 1);
    Idx := Copy(Bracket, MinusPos + 1, Length(Bracket) - MinusPos);
    While (Length(Base) > 0) And (Base[Length(Base)] = ' ') Do
      Delete(Base, Length(Base), 1);
    While (Length(Idx) > 0) And (Idx[1] = ' ') Do
      Delete(Idx, 1, 1);
    BaseR := AsmRegIdx32(Base);
    Disp := -AsmParseImm(Idx);
    If (Disp >= -128) And (Disp <= 127) Then
    Begin
      If BaseR = 4 Then
      Begin
        BinEmitByte((1 Shl 6) Or (RegField Shl 3) Or 4);
        BinEmitByte($24);
      End
      Else
        BinEmitByte((1 Shl 6) Or (RegField Shl 3) Or BaseR);
      BinEmitByte(Byte(Disp And $FF));
    End
    Else
    Begin
      If BaseR = 4 Then
      Begin
        BinEmitByte((2 Shl 6) Or (RegField Shl 3) Or 4);
        BinEmitByte($24);
      End
      Else
        BinEmitByte((2 Shl 6) Or (RegField Shl 3) Or BaseR);
      BinEmitDWord(Disp);
    End;
  End;
End;

{ ---- AsmEncodeInstr : encoder une instruction x86 ----------- }
Procedure AsmEncodeInstr(Const Line : String);
Var
  Mnem, Ops, Op1, Op2, Op3, Bracket : String;
  R1, R2, I, CommaPos : Integer;
  Imm : LongInt;
  ApiIdx : Integer;
Begin
  Mnem := AsmGetMnemonic(Line);
  Ops := AsmGetOperands(Line);
  AsmSplitOps(Ops, Op1, Op2);

  { ---- Instructions simples sans operande ---- }
  If Mnem = 'RET' Then
  Begin
    If Length(Op1) > 0 Then
    Begin BinEmitByte($C2); BinEmitWord(Word(AsmParseImm(Op1))); End
    Else BinEmitByte($C3);
    Exit;
  End;
  If Mnem = 'CDQ' Then Begin BinEmitByte($99); Exit; End;
  If Mnem = 'SAHF' Then Begin BinEmitByte($9E); Exit; End;
  If (Mnem = 'FWAIT') Or (Mnem = 'WAIT') Then Begin BinEmitByte($9B); Exit; End;

  If Mnem = 'FCHS'    Then Begin BinEmitByte($D9); BinEmitByte($E0); Exit; End;
  If Mnem = 'FTST'    Then Begin BinEmitByte($D9); BinEmitByte($E4); Exit; End;
  If Mnem = 'FSTSW'   Then
  Begin
    { FSTSW AX : DF E0 }
    If StrUpperCase(Op1) = 'AX' Then
    Begin BinEmitByte($DF); BinEmitByte($E0); Exit; End;
  End;
  If Mnem = 'FSQRT'   Then Begin BinEmitByte($D9); BinEmitByte($FA); Exit; End;
  If Mnem = 'FYL2X'   Then Begin BinEmitByte($D9); BinEmitByte($F1); Exit; End;
  If Mnem = 'FLDL2E'  Then Begin BinEmitByte($D9); BinEmitByte($EA); Exit; End;
  If Mnem = 'FLDLN2'  Then Begin BinEmitByte($D9); BinEmitByte($ED); Exit; End;
  If Mnem = 'FLD1'    Then Begin BinEmitByte($D9); BinEmitByte($E8); Exit; End;
  If Mnem = 'F2XM1'   Then Begin BinEmitByte($D9); BinEmitByte($F0); Exit; End;
  If Mnem = 'FSCALE'  Then Begin BinEmitByte($D9); BinEmitByte($FD); Exit; End;
  If Mnem = 'FRNDINT' Then Begin BinEmitByte($D9); BinEmitByte($FC); Exit; End;
  If Mnem = 'FABS'    Then Begin BinEmitByte($D9); BinEmitByte($E1); Exit; End;

  { ---- FPU : FCOMI (comparaison ST(0), ST(i), met a jour ZF/PF/CF) ---- }
  If Mnem = 'FCOMI' Then
  Begin
    { FCOMI ST(0), ST(i) : DB F0+i }
    If StrUpperCase(Op2) = 'ST(1)' Then
    Begin BinEmitByte($DB); BinEmitByte($F1); Exit; End;
    BinEmitByte($DB); BinEmitByte($F0);
    Exit;
  End;

  { ---- FPU : FMULP / FADDP / FSUBRP / FDIVRP (sans operandes ou ST(1),ST(0)) ---- }
  If Mnem = 'FMULP'   Then Begin BinEmitByte($DE); BinEmitByte($C9); Exit; End;
  If Mnem = 'FADDP'   Then Begin BinEmitByte($DE); BinEmitByte($C1); Exit; End;
  If Mnem = 'FSUBRP'  Then Begin BinEmitByte($DE); BinEmitByte($E1); Exit; End;
  If Mnem = 'FSUBP'   Then Begin BinEmitByte($DE); BinEmitByte($E9); Exit; End;
  If Mnem = 'FDIVRP'  Then Begin BinEmitByte($DE); BinEmitByte($F1); Exit; End;
  If Mnem = 'FDIVP'   Then Begin BinEmitByte($DE); BinEmitByte($F9); Exit; End;

  { ---- FPU : FXCH (sans operande = ST(1)) ---- }
  If Mnem = 'FXCH' Then
  Begin
    { Par defaut ou avec ST(1) : D9 C9. Pas de support des autres ST(n) ici }
    BinEmitByte($D9); BinEmitByte($C9);
    Exit;
  End;

  { ---- FPU : FLD ST(0), FSTP ST(i), FILD/FISTP memoire ---- }
  If Mnem = 'FLD' Then
  Begin
    { FLD ST(0) : duplique le sommet -> D9 C0 }
    If (StrUpperCase(Op1) = 'ST(0)') Or (StrUpperCase(Op1) = 'ST') Or
       (StrUpperCase(Op1) = 'ST0') Then
    Begin BinEmitByte($D9); BinEmitByte($C0); Exit; End;
    { FLD DWORD PTR [mem] : D9 /0 }
    If AsmStartsWith(Op1, 'DWORD PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op1);
      BinEmitByte($D9);
      AsmEncodeMemory(Bracket, 0);
      Exit;
    End;
    { FLD QWORD PTR [mem] : DD /0 }
    If AsmStartsWith(Op1, 'QWORD PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op1);
      BinEmitByte($DD);
      AsmEncodeMemory(Bracket, 0);
      Exit;
    End;
  End;
  If Mnem = 'FSTP' Then
  Begin
    { FSTP ST(i) : DD D8+i (ecrase ST(0) dans ST(i) avec pop) }
    If (StrUpperCase(Op1) = 'ST(0)') Or (StrUpperCase(Op1) = 'ST') Or
       (StrUpperCase(Op1) = 'ST0') Then
    Begin BinEmitByte($DD); BinEmitByte($D8); Exit; End;
    If StrUpperCase(Op1) = 'ST(1)' Then
    Begin BinEmitByte($DD); BinEmitByte($D9); Exit; End;
    If StrUpperCase(Op1) = 'ST(2)' Then
    Begin BinEmitByte($DD); BinEmitByte($DA); Exit; End;
    If StrUpperCase(Op1) = 'ST(3)' Then
    Begin BinEmitByte($DD); BinEmitByte($DB); Exit; End;
    If StrUpperCase(Op1) = 'ST(4)' Then
    Begin BinEmitByte($DD); BinEmitByte($DC); Exit; End;
    If StrUpperCase(Op1) = 'ST(5)' Then
    Begin BinEmitByte($DD); BinEmitByte($DD); Exit; End;
    If StrUpperCase(Op1) = 'ST(6)' Then
    Begin BinEmitByte($DD); BinEmitByte($DE); Exit; End;
    If StrUpperCase(Op1) = 'ST(7)' Then
    Begin BinEmitByte($DD); BinEmitByte($DF); Exit; End;
    { FSTP DWORD PTR [mem] : D9 /3 }
    If AsmStartsWith(Op1, 'DWORD PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op1);
      BinEmitByte($D9);
      AsmEncodeMemory(Bracket, 3);
      Exit;
    End;
    { FSTP QWORD PTR [mem] : DD /3 }
    If AsmStartsWith(Op1, 'QWORD PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op1);
      BinEmitByte($DD);
      AsmEncodeMemory(Bracket, 3);
      Exit;
    End;
  End;
  If Mnem = 'FILD' Then
  Begin
    { FILD DWORD PTR [mem] : DB /0 }
    If AsmStartsWith(Op1, 'DWORD PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op1);
      BinEmitByte($DB);
      AsmEncodeMemory(Bracket, 0);
      Exit;
    End;
  End;
  If Mnem = 'FISTP' Then
  Begin
    { FISTP DWORD PTR [mem] : DB /3 }
    If AsmStartsWith(Op1, 'DWORD PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op1);
      BinEmitByte($DB);
      AsmEncodeMemory(Bracket, 3);
      Exit;
    End;
    { FISTP QWORD PTR [mem] : DF /7 }
    If AsmStartsWith(Op1, 'QWORD PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op1);
      BinEmitByte($DF);
      AsmEncodeMemory(Bracket, 7);
      Exit;
    End;
  End;
  { ---- FPU : FADD/FSUB/FMUL/FDIV ST(0), ST(i) ---- }
  If (Mnem = 'FADD') Or (Mnem = 'FMUL') Or (Mnem = 'FSUB') Or
     (Mnem = 'FSUBR') Or (Mnem = 'FDIV') Or (Mnem = 'FDIVR') Then
  Begin
    { Forme registre : FADD ST(0), ST(i) }
    If (StrUpperCase(Op1) = 'ST(0)') Or (StrUpperCase(Op1) = 'ST') Or
       (StrUpperCase(Op1) = 'ST0') Then
    Begin
      R2 := -1;
      If StrUpperCase(Op2) = 'ST(0)' Then R2 := 0
      Else If StrUpperCase(Op2) = 'ST(1)' Then R2 := 1
      Else If StrUpperCase(Op2) = 'ST(2)' Then R2 := 2
      Else If StrUpperCase(Op2) = 'ST(3)' Then R2 := 3
      Else If StrUpperCase(Op2) = 'ST(4)' Then R2 := 4
      Else If StrUpperCase(Op2) = 'ST(5)' Then R2 := 5
      Else If StrUpperCase(Op2) = 'ST(6)' Then R2 := 6
      Else If StrUpperCase(Op2) = 'ST(7)' Then R2 := 7;
      If R2 >= 0 Then
      Begin
        BinEmitByte($D8);
        If Mnem = 'FADD'  Then BinEmitByte($C0 + R2)
        Else If Mnem = 'FMUL'  Then BinEmitByte($C8 + R2)
        Else If Mnem = 'FSUB'  Then BinEmitByte($E0 + R2)
        Else If Mnem = 'FSUBR' Then BinEmitByte($E8 + R2)
        Else If Mnem = 'FDIV'  Then BinEmitByte($F0 + R2)
        Else                       BinEmitByte($F8 + R2);
        Exit;
      End;
    End;
    { Forme memoire seule : FMUL/FADD/FSUB/FDIV QWORD PTR [mem] -> ST(0) op= m64 }
    If AsmStartsWith(Op1, 'QWORD PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op1);
      BinEmitByte($DC);
      If Mnem = 'FADD'  Then AsmEncodeMemory(Bracket, 0)
      Else If Mnem = 'FMUL'  Then AsmEncodeMemory(Bracket, 1)
      Else If Mnem = 'FSUB'  Then AsmEncodeMemory(Bracket, 4)
      Else If Mnem = 'FSUBR' Then AsmEncodeMemory(Bracket, 5)
      Else If Mnem = 'FDIV'  Then AsmEncodeMemory(Bracket, 6)
      Else                       AsmEncodeMemory(Bracket, 7);
      Exit;
    End;
  End;

  { ---- PUSH ---- }
  If Mnem = 'PUSH' Then
  Begin
    If AsmStartsWith(Op1, 'DWORD PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op1);
      If AsmIsRegBased(Bracket) Then
      Begin { Base registre : FF /6 + ModRM/SIB }
        BinEmitByte($FF);
        AsmEncodeMemory(Bracket, 6);
      End
      Else
      Begin { Label memoire direct }
        BinEmitByte($FF);
        BinEmitByte($35);
        BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
        BinEmitDWord(0);
      End;
      Exit;
    End;
    R1 := AsmRegIdx32(Op1);
    If R1 >= 0 Then
    Begin BinEmitByte($50 + R1); Exit; End;
    { PUSH OFFSET label -> fixup ABS32 }
    If AsmStartsWith(Op1, 'OFFSET ') Then
    Begin
      BinEmitByte($68);
      BinAddFixup(BinCodeLen, BFK_ABS32,
        Copy(Op1, 8, Length(Op1) - 7), True);
      BinEmitDWord(0);
      Exit;
    End;
    Imm := AsmParseImm(Op1);
    If (Imm >= -128) And (Imm <= 127) Then
    Begin
      BinEmitByte($6A);
      BinEmitByte(Byte(Imm And $FF));
    End
    Else
    Begin
      BinEmitByte($68);
      BinEmitDWord(Imm);
    End;
    Exit;
  End;

  { ---- POP ---- }
  If Mnem = 'POP' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    If R1 >= 0 Then BinEmitByte($58 + R1);
    Exit;
  End;

  { ---- MOV ---- }
  If Mnem = 'MOV' Then
  Begin
    { MOV DWORD PTR [mem], reg32 ou imm32 }
    If AsmStartsWith(Op1, 'DWORD PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op1);
      R2 := AsmRegIdx32(Op2);
      If R2 >= 0 Then
      Begin
        If AsmIsRegBased(Bracket) Then
        Begin
          BinEmitByte($89);
          AsmEncodeMemory(Bracket, R2);
        End
        Else If R2 = 0 Then
        Begin
          BinEmitByte($A3);
          BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
          BinEmitDWord(0);
        End
        Else
        Begin
          BinEmitByte($89);
          BinEmitByte((0 Shl 6) Or (R2 Shl 3) Or 5);
          BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
          BinEmitDWord(0);
        End;
      End
      Else
      Begin
        Imm := AsmParseImm(Op2);
        If AsmIsRegBased(Bracket) Then
        Begin
          BinEmitByte($C7);
          AsmEncodeMemory(Bracket, 0);
          BinEmitDWord(Imm);
        End
        Else
        Begin
          BinEmitByte($C7);
          BinEmitByte($05);
          BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
          BinEmitDWord(0);
          BinEmitDWord(Imm);
        End;
      End;
      Exit;
    End;
    { MOV BYTE PTR [mem], reg8/imm8 }
    If AsmStartsWith(Op1, 'BYTE PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op1);
      R2 := AsmRegIdx8(Op2);
      If R2 >= 0 Then
      Begin
        BinEmitByte($88);
        AsmEncodeMemory(Bracket, R2);
      End
      Else
      Begin
        Imm := AsmParseImm(Op2);
        BinEmitByte($C6);
        AsmEncodeMemory(Bracket, 0);
        BinEmitByte(Byte(Imm And $FF));
      End;
      Exit;
    End;
    { MOV reg, DWORD PTR [mem] }
    If AsmStartsWith(Op2, 'DWORD PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op2);
      R1 := AsmRegIdx32(Op1);
      If AsmIsRegBased(Bracket) Then
      Begin
        BinEmitByte($8B);
        AsmEncodeMemory(Bracket, R1);
      End
      Else If R1 = 0 Then
      Begin
        BinEmitByte($A1);
        BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
        BinEmitDWord(0);
      End
      Else
      Begin
        BinEmitByte($8B);
        BinEmitByte((0 Shl 6) Or (R1 Shl 3) Or 5);
        BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
        BinEmitDWord(0);
      End;
      Exit;
    End;
    { MOV reg8, BYTE PTR [mem] }
    If AsmStartsWith(Op2, 'BYTE PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op2);
      R1 := AsmRegIdx8(Op1);
      BinEmitByte($8A);
      AsmEncodeMemory(Bracket, R1);
      Exit;
    End;
    { MOV reg32, reg32 }
    R1 := AsmRegIdx32(Op1);
    R2 := AsmRegIdx32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin
      BinEmitByte($89);
      BinEmitByte((3 Shl 6) Or (R2 Shl 3) Or R1);
      Exit;
    End;
    { MOV reg32, OFFSET label -> fixup ABS32 }
    If (R1 >= 0) And AsmStartsWith(Op2, 'OFFSET ') Then
    Begin
      BinEmitByte($B8 + R1);
      BinAddFixup(BinCodeLen, BFK_ABS32,
        Copy(Op2, 8, Length(Op2) - 7), True);
      BinEmitDWord(0);
      Exit;
    End;
    { MOV reg32, imm32 }
    If R1 >= 0 Then
    Begin
      Imm := AsmParseImm(Op2);
      BinEmitByte($B8 + R1);
      BinEmitDWord(Imm);
      Exit;
    End;
    Exit;
  End;

  { ---- LEA ---- }
  If Mnem = 'LEA' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    Bracket := AsmExtractBracket(Op2);
    If AsmIsRegBased(Bracket) Then
    Begin
      BinEmitByte($8D);
      AsmEncodeMemory(Bracket, R1);
    End
    Else
    Begin
      BinEmitByte($8D);
      BinEmitByte((0 Shl 6) Or (R1 Shl 3) Or 5);
      BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
      BinEmitDWord(0);
    End;
    Exit;
  End;

  { ---- CALL ---- }
  If Mnem = 'CALL' Then
  Begin
    ApiIdx := AsmFindAPI(Op1);
    If ApiIdx >= 0 Then
    Begin
      BinEmitByte($FF);
      BinEmitByte($15);
      BinAddFixup(BinCodeLen, BFK_IAT32, Op1, True);
      BinEmitDWord(0);
    End
    Else
    Begin
      BinEmitByte($E8);
      BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
      BinEmitDWord(0);
    End;
    Exit;
  End;

  { ---- JMP ---- }
  If Mnem = 'JMP' Then
  Begin
    BinEmitByte($E9);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0);
    Exit;
  End;

  { ---- Jcc (sauts conditionnels) ---- }
  If (Mnem = 'JZ') Or (Mnem = 'JE') Then
  Begin
    BinEmitByte($0F); BinEmitByte($84);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;
  If (Mnem = 'JNZ') Or (Mnem = 'JNE') Then
  Begin
    BinEmitByte($0F); BinEmitByte($85);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JB' Then
  Begin
    BinEmitByte($0F); BinEmitByte($82);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JBE' Then
  Begin
    BinEmitByte($0F); BinEmitByte($86);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;
  If (Mnem = 'JAE') Or (Mnem = 'JNC') Then
  Begin
    BinEmitByte($0F); BinEmitByte($83);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JA' Then
  Begin
    BinEmitByte($0F); BinEmitByte($87);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JGE' Then
  Begin
    BinEmitByte($0F); BinEmitByte($8D);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JNS' Then
  Begin
    BinEmitByte($0F); BinEmitByte($89);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JG' Then
  Begin
    BinEmitByte($0F); BinEmitByte($8F);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JL' Then
  Begin
    BinEmitByte($0F); BinEmitByte($8C);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;
  If (Mnem = 'JLE') Or (Mnem = 'JNG') Then
  Begin
    BinEmitByte($0F); BinEmitByte($8E);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;
  If Mnem = 'JS' Then
  Begin
    BinEmitByte($0F); BinEmitByte($88);
    BinAddFixup(BinCodeLen, BFK_REL32, Op1, True);
    BinEmitDWord(0); Exit;
  End;

  { ---- ADD ---- }
  If Mnem = 'ADD' Then
  Begin
    If Op1 = 'AL' Then
    Begin
      BinEmitByte($04);
      BinEmitByte(Byte(AsmParseImm(Op2) And $FF));
      Exit;
    End;
    R1 := AsmRegIdx8(Op1);
    If R1 >= 0 Then
    Begin
      BinEmitByte($80);
      BinEmitByte($C0 Or R1);
      BinEmitByte(Byte(AsmParseImm(Op2) And $FF));
      Exit;
    End;
    R1 := AsmRegIdx32(Op1);
    R2 := AsmRegIdx32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin
      BinEmitByte($01);
      BinEmitByte((3 Shl 6) Or (R2 Shl 3) Or R1);
      Exit;
    End;
    If R1 >= 0 Then
    Begin
      Imm := AsmParseImm(Op2);
      If (Imm >= -128) And (Imm <= 127) Then
      Begin
        BinEmitByte($83);
        BinEmitByte($C0 Or R1);
        BinEmitByte(Byte(Imm And $FF));
      End
      Else
      Begin
        BinEmitByte($81);
        BinEmitByte($C0 Or R1);
        BinEmitByte(Byte(Imm And $FF));
        BinEmitByte(Byte((Imm Shr 8) And $FF));
        BinEmitByte(Byte((Imm Shr 16) And $FF));
        BinEmitByte(Byte((Imm Shr 24) And $FF));
      End;
      Exit;
    End;
    Exit;
  End;

  { ---- SUB ---- }
  If Mnem = 'SUB' Then
  Begin
    If Op1 = 'AL' Then
    Begin
      BinEmitByte($2C);
      BinEmitByte(Byte(AsmParseImm(Op2) And $FF));
      Exit;
    End;
    R1 := AsmRegIdx8(Op1);
    If R1 >= 0 Then
    Begin
      BinEmitByte($80);
      BinEmitByte($E8 Or R1);
      BinEmitByte(Byte(AsmParseImm(Op2) And $FF));
      Exit;
    End;
    R1 := AsmRegIdx32(Op1);
    R2 := AsmRegIdx32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin
      BinEmitByte($29);
      BinEmitByte((3 Shl 6) Or (R2 Shl 3) Or R1);
      Exit;
    End;
    If R1 >= 0 Then
    Begin
      Imm := AsmParseImm(Op2);
      If (Imm >= -128) And (Imm <= 127) Then
      Begin
        BinEmitByte($83);
        BinEmitByte($E8 Or R1);
        BinEmitByte(Byte(Imm And $FF));
      End
      Else
      Begin
        BinEmitByte($81);
        BinEmitByte($E8 Or R1);
        BinEmitByte(Byte(Imm And $FF));
        BinEmitByte(Byte((Imm Shr 8) And $FF));
        BinEmitByte(Byte((Imm Shr 16) And $FF));
        BinEmitByte(Byte((Imm Shr 24) And $FF));
      End;
      Exit;
    End;
    Exit;
  End;

  { ---- XOR ---- }
  If Mnem = 'XOR' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    R2 := AsmRegIdx32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin
      BinEmitByte($31);
      BinEmitByte((3 Shl 6) Or (R2 Shl 3) Or R1);
    End;
    Exit;
  End;

  { ---- AND ---- }
  If Mnem = 'AND' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    R2 := AsmRegIdx32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin
      BinEmitByte($21);
      BinEmitByte((3 Shl 6) Or (R2 Shl 3) Or R1);
      Exit;
    End;
    If R1 >= 0 Then
    Begin
      Imm := AsmParseImm(Op2);
      If (Imm >= -128) And (Imm <= 127) Then
      Begin
        BinEmitByte($83);
        BinEmitByte($E0 Or R1);
        BinEmitByte(Byte(Imm And $FF));
      End
      Else
      Begin
        BinEmitByte($81);
        BinEmitByte($E0 Or R1);
        BinEmitDWord(Imm);
      End;
    End;
    Exit;
  End;

  { ---- OR ---- }
  If Mnem = 'OR' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    R2 := AsmRegIdx32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin
      BinEmitByte($09);
      BinEmitByte((3 Shl 6) Or (R2 Shl 3) Or R1);
      Exit;
    End;
    If R1 >= 0 Then
    Begin
      Imm := AsmParseImm(Op2);
      If (Imm >= -128) And (Imm <= 127) Then
      Begin
        BinEmitByte($83);
        BinEmitByte($C8 Or R1);
        BinEmitByte(Byte(Imm And $FF));
      End
      Else
      Begin
        BinEmitByte($81);
        BinEmitByte($C8 Or R1);
        BinEmitDWord(Imm);
      End;
    End;
    Exit;
  End;

  { ---- XCHG ---- }
  If Mnem = 'XCHG' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    R2 := AsmRegIdx32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin
      BinEmitByte($87);
      BinEmitByte((3 Shl 6) Or (R2 Shl 3) Or R1);
    End;
    Exit;
  End;

  { ---- CMP ---- }
  If Mnem = 'CMP' Then
  Begin
    { CMP BYTE PTR [mem], imm8 }
    If AsmStartsWith(Op1, 'BYTE PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op1);
      Imm := AsmParseImm(Op2);
      BinEmitByte($80);
      AsmEncodeMemory(Bracket, 7);
      BinEmitByte(Byte(Imm And $FF));
      Exit;
    End;
    { CMP AL, imm8 (court) : uniquement si Op2 est un immediat }
    If (Op1 = 'AL') And (AsmRegIdx8(Op2) < 0) Then
    Begin
      BinEmitByte($3C);
      BinEmitByte(Byte(AsmParseImm(Op2) And $FF));
      Exit;
    End;
    { CMP reg8, imm8 ou CMP reg8, reg8 }
    R1 := AsmRegIdx8(Op1);
    If R1 >= 0 Then
    Begin
      R2 := AsmRegIdx8(Op2);
      If R2 >= 0 Then
      Begin
        BinEmitByte($38);
        BinEmitByte((3 Shl 6) Or (R2 Shl 3) Or R1);
      End
      Else
      Begin
        Imm := AsmParseImm(Op2);
        BinEmitByte($80);
        BinEmitByte($F8 Or R1);
        BinEmitByte(Byte(Imm And $FF));
      End;
      Exit;
    End;
    { CMP reg32, reg32 ou CMP reg32, imm32 ou CMP reg32, DWORD PTR [mem] }
    R1 := AsmRegIdx32(Op1);
    If R1 >= 0 Then
    Begin
      If AsmStartsWith(Op2, 'DWORD PTR [') Then
      Begin
        Bracket := AsmExtractBracket(Op2);
        BinEmitByte($3B);
        If AsmIsRegBased(Bracket) Then
          AsmEncodeMemory(Bracket, R1)
        Else
        Begin
          BinEmitByte((0 Shl 6) Or (R1 Shl 3) Or 5);
          BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
          BinEmitDWord(0);
        End;
        Exit;
      End;
      R2 := AsmRegIdx32(Op2);
      If R2 >= 0 Then
      Begin
        BinEmitByte($39);
        BinEmitByte((3 Shl 6) Or (R2 Shl 3) Or R1);
        Exit;
      End;
      Imm := AsmParseImm(Op2);
      If R1 = 0 Then
      Begin
        BinEmitByte($3D);
        BinEmitDWord(Imm);
      End
      Else
      Begin
        BinEmitByte($81);
        BinEmitByte($F8 Or R1);
        BinEmitDWord(Imm);
      End;
      Exit;
    End;
    Exit;
  End;

  { ---- TEST ---- }
  If Mnem = 'TEST' Then
  Begin
    R1 := AsmRegIdx8(Op1);
    R2 := AsmRegIdx8(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin
      BinEmitByte($84);
      BinEmitByte((3 Shl 6) Or (R2 Shl 3) Or R1);
      Exit;
    End;
    R1 := AsmRegIdx32(Op1);
    R2 := AsmRegIdx32(Op2);
    If (R1 >= 0) And (R2 >= 0) Then
    Begin
      BinEmitByte($85);
      BinEmitByte((3 Shl 6) Or (R2 Shl 3) Or R1);
    End;
    Exit;
  End;

  { ---- INC / DEC ---- }
  If Mnem = 'INC' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    If R1 >= 0 Then
      BinEmitByte($40 + R1)
    Else If AsmStartsWith(Op1, 'DWORD PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op1);
      BinEmitByte($FF);
      If AsmIsRegBased(Bracket) Then
        AsmEncodeMemory(Bracket, 0)
      Else
      Begin
        BinEmitByte($05);
        BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
        BinEmitDWord(0);
      End;
    End;
    Exit;
  End;
  If Mnem = 'DEC' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    If R1 >= 0 Then
      BinEmitByte($48 + R1)
    Else If AsmStartsWith(Op1, 'DWORD PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op1);
      BinEmitByte($FF);
      If AsmIsRegBased(Bracket) Then
        AsmEncodeMemory(Bracket, 1)
      Else
      Begin
        BinEmitByte($0D);
        BinAddFixup(BinCodeLen, BFK_ABS32, Bracket, True);
        BinEmitDWord(0);
      End;
    End;
    Exit;
  End;

  { ---- NEG ---- }
  If Mnem = 'NEG' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    If R1 >= 0 Then
    Begin BinEmitByte($F7); BinEmitByte($D8 Or R1); End;
    Exit;
  End;

  { ---- DIV ---- }
  If Mnem = 'DIV' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    If R1 >= 0 Then
    Begin BinEmitByte($F7); BinEmitByte($F0 Or R1); End;
    Exit;
  End;

  { ---- IDIV ---- }
  If Mnem = 'IDIV' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    If R1 >= 0 Then
    Begin BinEmitByte($F7); BinEmitByte($F8 Or R1); End;
    Exit;
  End;

  { ---- IMUL ---- }
  If Mnem = 'IMUL' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    CommaPos := 0;
    For I := 1 To Length(Op2) Do
      If Op2[I] = ',' Then Begin CommaPos := I; Break; End;
    If CommaPos > 0 Then
    Begin
      Op3 := Copy(Op2, CommaPos + 1, Length(Op2) - CommaPos);
      Op2 := Copy(Op2, 1, CommaPos - 1);
      While (Length(Op2) > 0) And (Op2[Length(Op2)] = ' ') Do
        Delete(Op2, Length(Op2), 1);
      While (Length(Op3) > 0) And (Op3[1] = ' ') Do
        Delete(Op3, 1, 1);
      R2 := AsmRegIdx32(Op2);
      Imm := AsmParseImm(Op3);
      If (Imm >= -128) And (Imm <= 127) Then
      Begin
        BinEmitByte($6B);
        BinEmitByte((3 Shl 6) Or (R1 Shl 3) Or R2);
        BinEmitByte(Byte(Imm And $FF));
      End
      Else
      Begin
        BinEmitByte($69);
        BinEmitByte((3 Shl 6) Or (R1 Shl 3) Or R2);
        BinEmitDWord(Imm);
      End;
    End
    Else If Length(Op2) > 0 Then
    Begin
      R2 := AsmRegIdx32(Op2);
      If R2 < 0 Then
      Begin
        Imm := AsmParseImm(Op2);
        If (Imm >= -128) And (Imm <= 127) Then
        Begin
          BinEmitByte($6B);
          BinEmitByte((3 Shl 6) Or (R1 Shl 3) Or R1);
          BinEmitByte(Byte(Imm And $FF));
        End
        Else
        Begin
          BinEmitByte($69);
          BinEmitByte((3 Shl 6) Or (R1 Shl 3) Or R1);
          BinEmitDWord(Imm);
        End;
      End
      Else
      Begin
        BinEmitByte($0F);
        BinEmitByte($AF);
        BinEmitByte((3 Shl 6) Or (R1 Shl 3) Or R2);
      End;
    End;
    Exit;
  End;

  { ---- SETcc ---- }
  If Mnem = 'SETE' Then
  Begin
    R1 := AsmRegIdx8(Op1);
    BinEmitByte($0F); BinEmitByte($94);
    BinEmitByte($C0 Or R1); Exit;
  End;
  If Mnem = 'SETNE' Then
  Begin
    R1 := AsmRegIdx8(Op1);
    BinEmitByte($0F); BinEmitByte($95);
    BinEmitByte($C0 Or R1); Exit;
  End;
  If Mnem = 'SETG' Then
  Begin
    R1 := AsmRegIdx8(Op1);
    BinEmitByte($0F); BinEmitByte($9F);
    BinEmitByte($C0 Or R1); Exit;
  End;
  If Mnem = 'SETGE' Then
  Begin
    R1 := AsmRegIdx8(Op1);
    BinEmitByte($0F); BinEmitByte($9D);
    BinEmitByte($C0 Or R1); Exit;
  End;
  If Mnem = 'SETL' Then
  Begin
    R1 := AsmRegIdx8(Op1);
    BinEmitByte($0F); BinEmitByte($9C);
    BinEmitByte($C0 Or R1); Exit;
  End;
  If Mnem = 'SETLE' Then
  Begin
    R1 := AsmRegIdx8(Op1);
    BinEmitByte($0F); BinEmitByte($9E);
    BinEmitByte($C0 Or R1); Exit;
  End;
  If Mnem = 'SETB' Then
  Begin
    R1 := AsmRegIdx8(Op1);
    BinEmitByte($0F); BinEmitByte($92);
    BinEmitByte($C0 Or R1); Exit;
  End;
  If Mnem = 'SETAE' Then
  Begin
    R1 := AsmRegIdx8(Op1);
    BinEmitByte($0F); BinEmitByte($93);
    BinEmitByte($C0 Or R1); Exit;
  End;
  If Mnem = 'SETBE' Then
  Begin
    R1 := AsmRegIdx8(Op1);
    BinEmitByte($0F); BinEmitByte($96);
    BinEmitByte($C0 Or R1); Exit;
  End;
  If Mnem = 'SETA' Then
  Begin
    R1 := AsmRegIdx8(Op1);
    BinEmitByte($0F); BinEmitByte($97);
    BinEmitByte($C0 Or R1); Exit;
  End;

  { ---- MOVZX ---- }
  If Mnem = 'MOVZX' Then
  Begin
    R1 := AsmRegIdx32(Op1);
    R2 := AsmRegIdx8(Op2);
    If R2 >= 0 Then
    Begin
      BinEmitByte($0F); BinEmitByte($B6);
      BinEmitByte((3 Shl 6) Or (R1 Shl 3) Or R2);
      Exit;
    End;
    If AsmStartsWith(Op2, 'BYTE PTR [') Then
    Begin
      Bracket := AsmExtractBracket(Op2);
      BinEmitByte($0F); BinEmitByte($B6);
      AsmEncodeMemory(Bracket, R1);
      Exit;
    End;
    Exit;
  End;
End;

{ ---- AsmEncodeData : encoder une directive de donnees (_DATA) - }
Procedure AsmEncodeData(Const Line : String);
Var
  I, J, DupPos : Integer;
  LabelName, Rest, Directive, Tok : String;
  DupCount, DupVal : LongInt;
  HasLabel : Boolean;
  DBytes : Array[0..7] Of Byte;
Begin
  { Extraire le premier token }
  I := 1;
  While (I <= Length(Line)) And (Line[I] <> ' ') Do Inc(I);
  LabelName := Copy(Line, 1, I - 1);
  If (LabelName = 'ASSUME') Or (LabelName = '') Then Exit;

  { Le 1er token est-il une directive (ligne de continuation, sans label) ? }
  HasLabel := Not ((LabelName = 'DB') Or (LabelName = 'DW') Or
                   (LabelName = 'DD') Or (LabelName = 'DQ'));

  If HasLabel Then
  Begin
    BinAddLabel(LabelName, BinDataLen);
    BinLabels[BinLblCount - 1].InCode := False;

    While (I <= Length(Line)) And (Line[I] = ' ') Do Inc(I);
    J := I;
    While (J <= Length(Line)) And (Line[J] <> ' ') Do Inc(J);
    Directive := Copy(Line, I, J - I);
    I := J;
    While (I <= Length(Line)) And (Line[I] = ' ') Do Inc(I);
    Rest := Copy(Line, I, Length(Line) - I + 1);
  End
  Else
  Begin
    Directive := LabelName;
    While (I <= Length(Line)) And (Line[I] = ' ') Do Inc(I);
    Rest := Copy(Line, I, Length(Line) - I + 1);
  End;

  If Directive = 'DQ' Then
  Begin
    { Nombre Double 64 bits (litteral decimal) -> 8 octets IEEE-754 }
    AsmParseDouble(Rest, DBytes);
    For I := 0 To 7 Do BinEmitDataByte(DBytes[I]);
  End
  Else If Directive = 'DD' Then
  Begin
    DupPos := Pos('DUP(', Rest);
    If DupPos > 0 Then
    Begin
      Tok := '';
      For I := 1 To DupPos - 1 Do
        If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
      DupCount := AsmParseImm(Tok);
      I := DupPos + 4;
      Tok := '';
      While (I <= Length(Rest)) And (Rest[I] <> ')') Do
      Begin
        If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
        Inc(I);
      End;
      DupVal := AsmParseImm(Tok);
      For J := 1 To DupCount Do
        BinEmitDataDWord(DupVal);
    End
    Else
      BinEmitDataDWord(AsmParseImm(Rest));
  End
  Else If Directive = 'DB' Then
  Begin
    DupPos := Pos('DUP(', Rest);
    If DupPos > 0 Then
    Begin
      Tok := '';
      For I := 1 To DupPos - 1 Do
        If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
      DupCount := AsmParseImm(Tok);
      I := DupPos + 4;
      Tok := '';
      While (I <= Length(Rest)) And (Rest[I] <> ')') Do
      Begin
        If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
        Inc(I);
      End;
      DupVal := AsmParseImm(Tok);
      For J := 1 To DupCount Do
        BinEmitDataByte(Byte(DupVal And $FF));
      Inc(I);
      While (I <= Length(Rest)) And ((Rest[I] = ' ') Or (Rest[I] = ',')) Do
        Inc(I);
      While I <= Length(Rest) Do
      Begin
        Tok := '';
        While (I <= Length(Rest)) And (Rest[I] <> ',') Do
        Begin
          If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
          Inc(I);
        End;
        If Length(Tok) > 0 Then
          BinEmitDataByte(Byte(AsmParseImm(Tok) And $FF));
        If (I <= Length(Rest)) And (Rest[I] = ',') Then Inc(I);
        While (I <= Length(Rest)) And (Rest[I] = ' ') Do Inc(I);
      End;
    End
    Else If (Length(Rest) > 0) And (Rest[1] = '''') Then
    Begin
      I := 2;
      While I <= Length(Rest) Do
      Begin
        If Rest[I] = '''' Then
        Begin
          If (I + 1 <= Length(Rest)) And (Rest[I + 1] = '''') Then
          Begin
            BinEmitDataByte(Byte(Ord('''')));
            Inc(I, 2);
          End
          Else
          Begin
            Inc(I);
            Break;
          End;
        End
        Else
        Begin
          BinEmitDataByte(Byte(Ord(Rest[I])));
          Inc(I);
        End;
      End;
      While (I <= Length(Rest)) And ((Rest[I] = ' ') Or (Rest[I] = ',')) Do
        Inc(I);
      While I <= Length(Rest) Do
      Begin
        If Rest[I] = '''' Then
        Begin
          Inc(I);
          While I <= Length(Rest) Do
          Begin
            If Rest[I] = '''' Then
            Begin
              If (I + 1 <= Length(Rest)) And (Rest[I + 1] = '''') Then
              Begin
                BinEmitDataByte(Byte(Ord('''')));
                Inc(I, 2);
              End
              Else
              Begin
                Inc(I);
                Break;
              End;
            End
            Else
            Begin
              BinEmitDataByte(Byte(Ord(Rest[I])));
              Inc(I);
            End;
          End;
        End
        Else
        Begin
          Tok := '';
          While (I <= Length(Rest)) And (Rest[I] <> ',') Do
          Begin
            If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
            Inc(I);
          End;
          If Length(Tok) > 0 Then
            BinEmitDataByte(Byte(AsmParseImm(Tok) And $FF));
        End;
        If (I <= Length(Rest)) And (Rest[I] = ',') Then Inc(I);
        While (I <= Length(Rest)) And (Rest[I] = ' ') Do Inc(I);
      End;
    End
    Else
    Begin
      I := 1;
      While I <= Length(Rest) Do
      Begin
        Tok := '';
        While (I <= Length(Rest)) And (Rest[I] <> ',') Do
        Begin
          If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
          Inc(I);
        End;
        If Length(Tok) > 0 Then
          BinEmitDataByte(Byte(AsmParseImm(Tok) And $FF));
        If (I <= Length(Rest)) And (Rest[I] = ',') Then Inc(I);
        While (I <= Length(Rest)) And (Rest[I] = ' ') Do Inc(I);
      End;
    End;
  End;
End;

{ ---- AsmIsCodeData : la ligne est-elle DD/DB/DQ en section code ? }
Function AsmIsCodeData(Const S : String) : Boolean;
Var I : Integer;
Begin
  AsmIsCodeData := False;
  I := 1;
  While (I <= Length(S)) And (S[I] <> ' ') Do Inc(I);
  While (I <= Length(S)) And (S[I] = ' ') Do Inc(I);
  If (I + 1 <= Length(S)) And (S[I] = 'D') Then
  Begin
    If (S[I+1] = 'D') Or (S[I+1] = 'B') Or (S[I+1] = 'Q') Then
    Begin
      If (I + 2 > Length(S)) Or (S[I+2] = ' ') Then
        AsmIsCodeData := True;
    End;
  End;
End;

{ ---- AsmEncodeCodeData : encoder DD/DB/DQ inline dans BinCode[] - }
Procedure AsmEncodeCodeData(Const Line : String);
Var
  I, J, DupPos : Integer;
  LabelName, Rest, Directive, Tok : String;
  DupCount, DupVal : LongInt;
  DBytes : Array[0..7] Of Byte;
Begin
  I := 1;
  While (I <= Length(Line)) And (Line[I] <> ' ') Do Inc(I);
  LabelName := Copy(Line, 1, I - 1);

  BinAddLabel(LabelName, BinCodeLen);
  BinLabels[BinLblCount - 1].InCode := True;

  While (I <= Length(Line)) And (Line[I] = ' ') Do Inc(I);
  J := I;
  While (J <= Length(Line)) And (Line[J] <> ' ') Do Inc(J);
  Directive := Copy(Line, I, J - I);
  I := J;
  While (I <= Length(Line)) And (Line[I] = ' ') Do Inc(I);
  Rest := Copy(Line, I, Length(Line) - I + 1);

  If Directive = 'DQ' Then
  Begin
    AsmParseDouble(Rest, DBytes);
    For I := 0 To 7 Do BinEmitByte(DBytes[I]);
  End
  Else If Directive = 'DD' Then
    BinEmitDWord(AsmParseImm(Rest))
  Else If Directive = 'DB' Then
  Begin
    DupPos := Pos('DUP(', Rest);
    If DupPos > 0 Then
    Begin
      Tok := '';
      For I := 1 To DupPos - 1 Do
        If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
      DupCount := AsmParseImm(Tok);
      I := DupPos + 4;
      Tok := '';
      While (I <= Length(Rest)) And (Rest[I] <> ')') Do
      Begin
        If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
        Inc(I);
      End;
      DupVal := AsmParseImm(Tok);
      For J := 1 To DupCount Do
        BinEmitByte(Byte(DupVal And $FF));
      Inc(I);
      While (I <= Length(Rest)) And ((Rest[I] = ' ') Or (Rest[I] = ',')) Do
        Inc(I);
      While I <= Length(Rest) Do
      Begin
        Tok := '';
        While (I <= Length(Rest)) And (Rest[I] <> ',') Do
        Begin
          If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
          Inc(I);
        End;
        If Length(Tok) > 0 Then
          BinEmitByte(Byte(AsmParseImm(Tok) And $FF));
        If (I <= Length(Rest)) And (Rest[I] = ',') Then Inc(I);
        While (I <= Length(Rest)) And (Rest[I] = ' ') Do Inc(I);
      End;
    End
    Else
    Begin
      I := 1;
      While I <= Length(Rest) Do
      Begin
        Tok := '';
        While (I <= Length(Rest)) And (Rest[I] <> ',') Do
        Begin
          If Rest[I] <> ' ' Then Tok := Tok + Rest[I];
          Inc(I);
        End;
        If Length(Tok) > 0 Then
          BinEmitByte(Byte(AsmParseImm(Tok) And $FF));
        If (I <= Length(Rest)) And (Rest[I] = ',') Then Inc(I);
        While (I <= Length(Rest)) And (Rest[I] = ' ') Do Inc(I);
      End;
    End;
  End;
End;

{ ---- BinAssemble : relit le .ASM genere et encode chaque ligne ---- }
Procedure BinAssemble;
Var
  AsmF : Text;
  AsmPath, Line, Trimmed : String;
  InCodeSec, InDataSec : Boolean;
Begin
  BinInit;
  AsmPath := ReplaceExt(Opts.SrcFile, '.asm');
  Assign(AsmF, AsmPath);
  {$I-}
  Reset(AsmF);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('POWFXC32: erreur assembleur: impossible de lire ', AsmPath);
    Exit;
  End;

  InCodeSec := False;
  InDataSec := False;

  While Not EOF(AsmF) Do
  Begin
    ReadLn(AsmF, Line);
    Trimmed := AsmTrimLine(Line);
    If Length(Trimmed) = 0 Then Continue;

    If AsmStartsWith(Trimmed, '_TEXT') And (Pos('SEGMENT', Trimmed) > 0) Then
    Begin InCodeSec := True; InDataSec := False; Continue; End;
    If AsmStartsWith(Trimmed, '_TEXT') And (Pos('ENDS', Trimmed) > 0) Then
    Begin InCodeSec := False; Continue; End;
    If AsmStartsWith(Trimmed, '_DATA') And (Pos('SEGMENT', Trimmed) > 0) Then
    Begin InDataSec := True; InCodeSec := False; Continue; End;
    If AsmStartsWith(Trimmed, '_DATA') And (Pos('ENDS', Trimmed) > 0) Then
    Begin InDataSec := False; Continue; End;

    If AsmStartsWith(Trimmed, '.') Then Continue;
    If AsmStartsWith(Trimmed, 'ASSUME') Then Continue;
    If AsmStartsWith(Trimmed, 'EXTRN') Then Continue;
    If AsmStartsWith(Trimmed, 'OPTION') Then Continue;
    If AsmStartsWith(Trimmed, 'END ') Then Continue;
    If Trimmed = 'END' Then Continue;

    If InCodeSec Then
    Begin
      If AsmIsLabel(Trimmed) Then
      Begin
        BinAddLabel(AsmExtractLabel(Trimmed), BinCodeLen);
        BinLabels[BinLblCount - 1].InCode := True;
      End
      Else If AsmIsCodeData(Trimmed) Then
        AsmEncodeCodeData(Trimmed)
      Else
        AsmEncodeInstr(Trimmed);
    End
    Else If InDataSec Then
      AsmEncodeData(Trimmed);
  End;

  Close(AsmF);
  WriteLn('POWFXC32: assemblage: ', BinCodeLen, ' octets code, ',
          BinDataLen, ' octets data, ', BinLblCount, ' labels, ',
          BinFixCount, ' fixups');
End;

{ ---- BinResolveFixups : resoudre les relocations PE ---------- }
Procedure BinResolveFixups(TextRVA, DataRVA, IdataRVA, IatOfs : LongInt);
Var
  I, J : Integer;
  TgtOfs : LongInt;
  TgtInCode : Boolean;
  Addr : LongInt;
  ApiIdx : Integer;
  TgtName : TString;
  LblExtraOfs : LongInt;
  PlusP : Integer;
Begin
  For I := 0 To BinFixCount - 1 Do
  Begin
    If BinFixups[I].Kind = BFK_IAT32 Then
    Begin
      ApiIdx := AsmFindAPI(BinFixups[I].Target);
      If ApiIdx >= 0 Then
      Begin
        Addr := PE_IMG_BASE + IdataRVA + IatOfs + ApiIdx * 4;
        BinCode[BinFixups[I].Offset]     := Byte(Addr And $FF);
        BinCode[BinFixups[I].Offset + 1] := Byte((Addr Shr 8) And $FF);
        BinCode[BinFixups[I].Offset + 2] := Byte((Addr Shr 16) And $FF);
        BinCode[BinFixups[I].Offset + 3] := Byte((Addr Shr 24) And $FF);
      End;
    End
    Else
    Begin
      TgtName := BinFixups[I].Target;
      LblExtraOfs := 0;
      PlusP := Pos('+', TgtName);
      If PlusP > 0 Then
      Begin
        LblExtraOfs := AsmParseImm(Copy(TgtName, PlusP + 1, Length(TgtName) - PlusP));
        TgtName := Copy(TgtName, 1, PlusP - 1);
      End;
      TgtOfs := -1;
      TgtInCode := True;
      For J := 0 To BinLblCount - 1 Do
        If BinLabels[J].Name = TgtName Then
        Begin
          TgtOfs := BinLabels[J].Offset;
          TgtInCode := BinLabels[J].InCode;
          Break;
        End;
      If TgtOfs < 0 Then Continue;

      TgtOfs := TgtOfs + LblExtraOfs;

      If BinFixups[I].Kind = BFK_REL32 Then
      Begin
        Addr := TgtOfs - (BinFixups[I].Offset + 4);
        BinCode[BinFixups[I].Offset]     := Byte(Addr And $FF);
        BinCode[BinFixups[I].Offset + 1] := Byte((Addr Shr 8) And $FF);
        BinCode[BinFixups[I].Offset + 2] := Byte((Addr Shr 16) And $FF);
        BinCode[BinFixups[I].Offset + 3] := Byte((Addr Shr 24) And $FF);
      End
      Else If BinFixups[I].Kind = BFK_ABS32 Then
      Begin
        If TgtInCode Then
          Addr := PE_IMG_BASE + TextRVA + TgtOfs
        Else
          Addr := PE_IMG_BASE + DataRVA + TgtOfs;
        BinCode[BinFixups[I].Offset]     := Byte(Addr And $FF);
        BinCode[BinFixups[I].Offset + 1] := Byte((Addr Shr 8) And $FF);
        BinCode[BinFixups[I].Offset + 2] := Byte((Addr Shr 16) And $FF);
        BinCode[BinFixups[I].Offset + 3] := Byte((Addr Shr 24) And $FF);
      End;
    End;
  End;
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
  HintOfs        : Array[0..PE_NUM_API - 1] Of Integer;
  RvaVal         : LongInt;
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
    HintOfs[I] := IdataBufLen;
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

  { Patcher l ILT et l IAT : chaque entree pointe vers son Hint/Name.     }
  { Sans ceci, le loader Win32 ne resout aucune fonction importee et les }
  { emplacements de l IAT restent a 0 (plantage au premier appel API).   }
  For I := 0 To PE_NUM_API - 1 Do
  Begin
    RvaVal := IdataRVA + HintOfs[I];
    IdataBuf[IltOfs + I * 4]     := Byte(RvaVal And $FF);
    IdataBuf[IltOfs + I * 4 + 1] := Byte((RvaVal Shr 8) And $FF);
    IdataBuf[IltOfs + I * 4 + 2] := Byte((RvaVal Shr 16) And $FF);
    IdataBuf[IltOfs + I * 4 + 3] := Byte((RvaVal Shr 24) And $FF);
    IdataBuf[IatOfs + I * 4]     := Byte(RvaVal And $FF);
    IdataBuf[IatOfs + I * 4 + 1] := Byte((RvaVal Shr 8) And $FF);
    IdataBuf[IatOfs + I * 4 + 2] := Byte((RvaVal Shr 16) And $FF);
    IdataBuf[IatOfs + I * 4 + 3] := Byte((RvaVal Shr 24) And $FF);
  End;

  { Resoudre les fixups (CALL/JMP internes, adresses .DATA, imports IAT) }
  BinResolveFixups(TextRVA, DataRVA, IdataRVA, IatOfs);

  { DOS Stub (128 octets) }
  { IMAGE_DOS_HEADER fait 64 octets : e_magic (2) + reserve (58) +           }
  { e_lfanew (4) a l offset fixe 0x3C=60, obligatoire pour le loader Win32. }
  WriteBinWord_(F, PE_DOS_MAGIC);
  For I := 1 To 58 Do WriteBinByte_(F, 0);
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
  WriteLn('POWFXC32: EXE genere: ', Opts.OutFile);
  WriteLn('POWFXC32: assemblage et edition de liens integres, aucun outil externe requis.');
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
  WriteLn('Assemblage et edition de liens :');
  WriteLn('  Integres au compilateur (assembleur x86 et writer PE maison).');
  WriteLn('  Aucun outil externe (MASM/LINK) n''est requis : l''.EXE Win32');
  WriteLn('  est genere directement et est immediatement executable.');
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
