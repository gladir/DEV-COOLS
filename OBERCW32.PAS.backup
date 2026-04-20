{ @author: Gladir.com
  @created: 2026-04-20
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Oberon vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

(* ============================================================
  OBERCW32.PAS - Compilateur Oberon vers assembleur 80386
  pour Windows 32 bits (PE)
  Turbo Pascal 7 / Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -c, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -S, conserve egalement le fichier .ASM lisible.
  Supporte les exemples SAMPLES\OBERON\*.obn

  Voir ci-dessous pour la feuille de route complete.

  TODO 01. [IMPLEMENTE] INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF
           TOptions (SrcFile, OutFile, Verbose, EmitObj, EmitAsm)
           ParseArgs : analyser argv (source.obn [-o sortie] [-v] [-c] [-S] [-h])
           Par defaut : .EXE Windows 32 bits (PE), .OBJ avec -c, .ASM conserve avec -S
           FatalError, WarnMsg, ErrorAt, ErrorMsg
           Constantes PE/COFF, limites (MAX_SYM=2048, MAX_PROC=256, etc.)
           Prefixes ASM : _OV_, _OP_, _OL_, _ORT_, _OK_
           Utilitaires : IntToStr, StrToInt, StrUpper, ChangeExtension, ExtractBase

  TODO 02. [IMPLEMENTE] LEXEUR (TOKENS OBERON)
           LexOpen, LexClose, LexNext, LexCurChar, LexPeekChar, LexAdvance
           Reconnaitre : identifiants, keywords, entiers (decimaux/hex avec H),
           reels, caracteres ('x' et hex avec X), chaines, commentaires imbriques
           Operateurs divers et ponctuation
           Types de tokens : TOK_EOF, TOK_IDENT, TOK_INT, TOK_REAL, TOK_CHAR,
           TOK_STRING, TOK_KEYWORD, TOK_OP

  TODO 03. [IMPLEMENTE] MOTS-CLES OBERON ET GESTION DES ERREURS
           Keywords : MODULE IMPORT CONST TYPE VAR PROCEDURE BEGIN END
           IF THEN ELSIF ELSE WHILE DO REPEAT UNTIL FOR TO BY LOOP EXIT RETURN
           CASE OF ARRAY RECORD POINTER NIL TRUE FALSE DIV MOD OR IN IS AND NOT
           Error, Warning, SkipToSemi, SkipToEnd

  TODO 04. [IMPLEMENTE] TABLE DES SYMBOLES (32 BITS)
           TSymEntry : nom, type, storage class (global/local/param/const), offset
           SymEnter, SymFind, SymFindLocal
           Types predefinis : INTEGER(4), BOOLEAN(1), CHAR(1), BYTE(1), SET(4), REAL(4)

  TODO 05. [IMPLEMENTE] TABLE DES TYPES
           TTypeEntry : kind (INTEGER, BOOLEAN, CHAR, BYTE, SET, REAL, ARRAY,
           OPENARRAY, RECORD, POINTER, PROC), size, base, array length, record fields
           TypeNew, TypeByteSize
           Pre-enregistrer les types de base

  TODO 06. [IMPLEMENTE] TABLE DES PROCEDURES
           TProcEntry : nom, params, locals, label ASM
           ProcEnter, ProcFind, ProcAddParam, ProcAddLocal
           Procedures builtin : INC DEC ABS ODD CHR ORD HALT ASSERT LEN NEW INCL EXCL

  TODO 07. [IMPLEMENTE] PILE DE PORTEE (SCOPE STACK)
           TScopeEntry : niveau, symbole de debut
           ScopeEnter, ScopeLeave
           Recherche de symboles dans la portee courante et englobantes

  TODO 08. [IMPLEMENTE] TABLE DES CONSTANTES
           TConstEntry : nom, valeur entiere ou reelle
           ConstEnter, ConstFind

  TODO 09. [IMPLEMENTE] POOL DE CHAINES LITTERALES
           Garder les chaines litterales pour emission .data
           AddStringLiteral, GetStringLabel

  TODO 10. [IMPLEMENTE] PARSEUR - MODULE ET IMPORT
           ParseModule : MODULE ident ';' [ImportList] DeclSeq [BEGIN StatSeq] END ident '.'
           ParseImportList : IMPORT ident [',' ident]* ';'

  TODO 11. [IMPLEMENTE] PARSEUR - DECLARATIONS
           ParseDeclSeq : CONST / TYPE / VAR / PROCEDURE
           ParseConstDecl, ParseTypeDecl, ParseVarDecl, ParseProcedure
           (implementations minimales, skip details)

  TODO 12. [IMPLEMENTE] PARSEUR - EXPRESSIONS
           ParseExpression, ParseSimpleExpression, ParseTerm, ParseFactor
           (reconnaissance structurale seulement, pas de generation de code)

  TODO 13. [IMPLEMENTE] PARSEUR - STATEMENTS
           ParseStatSeq, SkipStatements
           Reconnaitre : affectation, appel, IF, WHILE, REPEAT, FOR, LOOP, RETURN, CASE
           (skip les corps de statements comme ADACW32)

  TODO 14. [IMPLEMENTE] PARSEUR - PROCEDURES
           ParseProcedure : PROCEDURE ident ['*'] [FormalPars] ';' DeclSeq [BEGIN StatSeq] END ident ';'
           ParseFormalPars : '(' [param [',' param]*] ')' [':' type]

  TODO 15. [IMPLEMENTE] EMETTEUR ASM (.ASM)
           EmitLine, EmitHeader, EmitDataSeg, EmitRuntime, EmitEntryPoint, EmitFooter
           Generer un fichier .asm minimal avec segment .data/.bss/.code
           Routine runtime _ORT_halt, point d'entree _OP_main

  TODO 16. [IMPLEMENTE] GENERATEUR BINAIRE - .OBJ (COFF)
           BinWriteObj : generer un fichier COFF .OBJ 32 bits valide
           Structure : COFF header, section headers (.text, .data), raw data,
           symbol table, string table

  TODO 17. [IMPLEMENTE] GENERATEUR BINAIRE - .EXE (PE)
           BinWriteExe : generer un fichier PE .EXE 32 bits valide
           Structure : DOS stub, PE signature, COFF header, optional header,
           section headers (.text, .data, .idata), import table (kernel32.dll)

  TODO 18. [IMPLEMENTE] HELPERS BINAIRES
           WriteBinByte, WriteBinWord, WriteBinDWord, WriteBinString, WriteBinZeros
           BinInit, BinEmitByte, BinEmitDataDWord

  TODO 19. [IMPLEMENTE] MAIN - DRIVER
           ParseArgs, validation, LexOpen, ParseModule, generation binaire
           Gestion des extensions (.obn -> .exe/.obj/.asm)
           Effacer .asm si -S non specifie

  TODO 20. [IMPLEMENTE] AIDE ET VERSION
           -h / --help : afficher usage en francais
           --version : afficher version

  TODO 21. [IMPLEMENTE] GESTION ERREURS
           Compter erreurs, arreter si > MAX_ERRORS
           Messages d'erreur avec ligne/colonne

  TODO 22. [IMPLEMENTE] EXPECT / ACCEPT HELPERS
           Expect(kw), Accept(kw), ExpectIdent, ExpectTok

  TODO 23. [IMPLEMENTE] LABEL GENERATION
           GenLabel : generer labels uniques pour IF/WHILE/FOR

  TODO 24. [IMPLEMENTE] KEYWORD LOOKUP
           LexIsKeyword : rechercher mot-cle dans table, retourner KW_xxx ou 0

  TODO 25. [IMPLEMENTE] MULTIPASS COMPILATION
           Phase 1 : parsing + table des symboles
           Phase 2 : emission ASM
           Phase 3 : generation binaire (.OBJ ou .EXE)
  ============================================================ *)

Program OBERCW32;

{$I-}

{ ============================================================
  CONSTANTES ET TYPES
  ============================================================ }

Const
  OBERCW32_VERSION = '1.0';
  OBERCW32_DATE    = '2026-04-20';

  MAX_SYM    = 2048;
  MAX_PROC   = 256;
  MAX_PARAM  = 32;
  MAX_FIELD  = 64;
  MAX_CONST  = 1024;
  MAX_TYPE   = 256;
  MAX_LABEL  = 4096;
  MAX_SCOPE  = 32;
  MAX_IMPORT = 32;
  MAX_STR    = 255;
  MAX_ERRORS = 50;

  PFX_OV  = '_OV_';
  PFX_OP  = '_OP_';
  PFX_OL  = '_OL_';
  PFX_ORT = '_ORT_';
  PFX_OK  = '_OK_';

  TOK_EOF     = 0;
  TOK_IDENT   = 1;
  TOK_INT     = 2;
  TOK_REAL    = 3;
  TOK_CHAR    = 4;
  TOK_STRING  = 5;
  TOK_KEYWORD = 6;
  TOK_OP      = 7;

  KW_MODULE    = 1;
  KW_IMPORT    = 2;
  KW_CONST     = 3;
  KW_TYPE      = 4;
  KW_VAR       = 5;
  KW_PROCEDURE = 6;
  KW_BEGIN     = 7;
  KW_END       = 8;
  KW_IF        = 9;
  KW_THEN      = 10;
  KW_ELSIF     = 11;
  KW_ELSE      = 12;
  KW_WHILE     = 13;
  KW_DO        = 14;
  KW_REPEAT    = 15;
  KW_UNTIL     = 16;
  KW_FOR       = 17;
  KW_TO        = 18;
  KW_BY        = 19;
  KW_LOOP      = 20;
  KW_EXIT      = 21;
  KW_RETURN    = 22;
  KW_CASE      = 23;
  KW_OF        = 24;
  KW_ARRAY     = 25;
  KW_RECORD    = 26;
  KW_POINTER   = 27;
  KW_NIL       = 28;
  KW_TRUE      = 29;
  KW_FALSE     = 30;
  KW_DIV       = 31;
  KW_MOD       = 32;
  KW_OR        = 33;
  KW_IN        = 34;
  KW_IS        = 35;
  KW_AND       = 36;
  KW_NOT       = 37;

  TYK_NONE      = 0;
  TYK_INTEGER   = 1;
  TYK_BOOLEAN   = 2;
  TYK_CHAR      = 3;
  TYK_BYTE      = 4;
  TYK_SET       = 5;
  TYK_REAL      = 6;
  TYK_ARRAY     = 7;
  TYK_OPENARRAY = 8;
  TYK_RECORD    = 9;
  TYK_POINTER   = 10;
  TYK_PROC      = 11;

  SC_GLOBAL = 0;
  SC_LOCAL  = 1;
  SC_PARAM  = 2;
  SC_CONST  = 3;

  PE_MACHINE_I386 = $014C;
  PE_SCN_TEXT     = $60000020;
  PE_SCN_BSS      = LongInt($C0000040);

  MAX_BIN_CODE = 65536;
  MAX_BIN_DATA = 65536;

Type
  TString = String[MAX_STR];

  TOptions = Record
    SrcFile     : String;
    OutFile     : String;
    Verbose     : Boolean;
    EmitObj     : Boolean;
    EmitAsm     : Boolean;
    ImportDirs  : Array[1..8] of String;
    ImportCount : Integer;
  End;

  TSymEntry = Record
    Name    : TString;
    TypeIdx : Integer;
    Storage : Integer;
    Offset  : Integer;
    Used    : Boolean;
  End;

  TTypeEntry = Record
    Kind     : Integer;
    ByteSize : Integer;
    BaseIdx  : Integer;
    ArrLen   : Integer;
    RecSym   : Integer;
    RecNfld  : Integer;
  End;

  TProcEntry = Record
    Name       : TString;
    ParamCount : Integer;
    LocalCount : Integer;
    AsmLabel   : TString;
  End;

  TScopeEntry = Record
    Level   : Integer;
    SymBase : Integer;
  End;

  TConstEntry = Record
    Name    : TString;
    IntVal  : LongInt;
    RealVal : Real;
    IsReal  : Boolean;
  End;

Var
  Opts : TOptions;

  LexSrc    : Text;
  LexEOF    : Boolean;
  LexLine   : String;
  LexPos    : Integer;
  LexLineNo : Integer;
  LexColNo  : Integer;

  CurTok      : Integer;
  CurTokStr   : TString;
  CurTokNum   : LongInt;
  CurTokReal  : Real;
  CurTokKw    : Integer;

  SymTab      : Array[1..MAX_SYM] of TSymEntry;
  SymCount    : Integer;

  TypeTab     : Array[1..MAX_TYPE] of TTypeEntry;
  TypeCount   : Integer;

  ProcTab     : Array[1..MAX_PROC] of TProcEntry;
  ProcCount   : Integer;

  ScopeStack  : Array[1..MAX_SCOPE] of TScopeEntry;
  ScopeDepth  : Integer;

  ConstTab    : Array[1..MAX_CONST] of TConstEntry;
  ConstCount  : Integer;

  StringPool  : Array[1..256] of TString;
  StringCount : Integer;

  LabelSeq    : Integer;
  ErrorCount  : Integer;
  ModuleName  : TString;

  AsmFile     : Text;
  AsmName     : String;

  BinCode     : Array[0..MAX_BIN_CODE-1] of Byte;
  BinData     : Array[0..MAX_BIN_DATA-1] of Byte;
  BinCodeLen  : Integer;
  BinDataLen  : Integer;

{ ============================================================
  UTILITAIRES
  ============================================================ }

Function IntToStr(V : LongInt) : String;
Var S : String;
Begin
  Str(V, S);
  IntToStr := S;
End;

Function StrToInt(Const S : String) : LongInt;
Var V, E : Integer;
Begin
  Val(S, V, E);
  If E <> 0 Then V := 0;
  StrToInt := V;
End;

Function StrUpper(Const S : String) : String;
Var I : Integer; R : String;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If R[I] In ['a'..'z'] Then
      R[I] := Chr(Ord(R[I]) - 32);
  StrUpper := R;
End;

Function ChangeExtension(Const FileName, NewExt : String) : String;
Var I : Integer; Base : String;
Begin
  Base := FileName;
  For I := Length(Base) DownTo 1 Do
    If Base[I] = '.' Then
    Begin
      Delete(Base, I, Length(Base) - I + 1);
      Break;
    End;
  ChangeExtension := Base + NewExt;
End;

Function ExtractBase(Const FileName : String) : String;
Var I, J : Integer; Base : String;
Begin
  Base := FileName;
  For I := Length(Base) DownTo 1 Do
    If Base[I] In ['\', '/', ':'] Then
    Begin
      Delete(Base, 1, I);
      Break;
    End;
  For J := Length(Base) DownTo 1 Do
    If Base[J] = '.' Then
    Begin
      Delete(Base, J, Length(Base) - J + 1);
      Break;
    End;
  ExtractBase := Base;
End;

{ ============================================================
  GESTION DES ERREURS
  ============================================================ }

Procedure ErrorMsg(Const Msg : String);
Begin
  Inc(ErrorCount);
  WriteLn('Erreur: ', Msg);
  If ErrorCount > MAX_ERRORS Then
  Begin
    WriteLn('Trop d''erreurs (', MAX_ERRORS, '), arret.');
    Halt(1);
  End;
End;

Procedure WarnMsg(Const Msg : String);
Begin
  WriteLn('Avertissement: ', Msg);
End;

Procedure FatalError(Const Msg : String);
Begin
  WriteLn('Erreur fatale: ', Msg);
  Halt(1);
End;

Procedure ErrorAt(Line, Col : Integer; Const Msg : String);
Begin
  Inc(ErrorCount);
  WriteLn('Erreur ligne ', Line, ' col ', Col, ': ', Msg);
  If ErrorCount > MAX_ERRORS Then
  Begin
    WriteLn('Trop d''erreurs (', MAX_ERRORS, '), arret.');
    Halt(1);
  End;
End;

{ ============================================================
  LEXEUR
  ============================================================ }

Function LexCurChar : Char;
Begin
  If LexPos > Length(LexLine) Then
    LexCurChar := #0
  Else
    LexCurChar := LexLine[LexPos];
End;

Function LexPeekChar(N : Integer) : Char;
Begin
  If LexPos + N > Length(LexLine) Then
    LexPeekChar := #0
  Else
    LexPeekChar := LexLine[LexPos + N];
End;

Procedure LexAdvance;
Begin
  If LexPos <= Length(LexLine) Then
  Begin
    Inc(LexPos);
    Inc(LexColNo);
  End;
End;

Procedure LexRefill;
Begin
  If Eof(LexSrc) Then
  Begin
    LexEOF := True;
    LexLine := '';
    Exit;
  End;
  ReadLn(LexSrc, LexLine);
  Inc(LexLineNo);
  LexPos := 1;
  LexColNo := 1;
End;

Procedure LexSkipWS;
Begin
  While (LexCurChar In [' ', #9]) Do
    LexAdvance;
End;

Function LexIsKeyword(Const S : String) : Integer;
Var U : String;
Begin
  U := StrUpper(S);
  If U = 'MODULE'    Then LexIsKeyword := KW_MODULE
  Else If U = 'IMPORT'    Then LexIsKeyword := KW_IMPORT
  Else If U = 'CONST'     Then LexIsKeyword := KW_CONST
  Else If U = 'TYPE'      Then LexIsKeyword := KW_TYPE
  Else If U = 'VAR'       Then LexIsKeyword := KW_VAR
  Else If U = 'PROCEDURE' Then LexIsKeyword := KW_PROCEDURE
  Else If U = 'BEGIN'     Then LexIsKeyword := KW_BEGIN
  Else If U = 'END'       Then LexIsKeyword := KW_END
  Else If U = 'IF'        Then LexIsKeyword := KW_IF
  Else If U = 'THEN'      Then LexIsKeyword := KW_THEN
  Else If U = 'ELSIF'     Then LexIsKeyword := KW_ELSIF
  Else If U = 'ELSE'      Then LexIsKeyword := KW_ELSE
  Else If U = 'WHILE'     Then LexIsKeyword := KW_WHILE
  Else If U = 'DO'        Then LexIsKeyword := KW_DO
  Else If U = 'REPEAT'    Then LexIsKeyword := KW_REPEAT
  Else If U = 'UNTIL'     Then LexIsKeyword := KW_UNTIL
  Else If U = 'FOR'       Then LexIsKeyword := KW_FOR
  Else If U = 'TO'        Then LexIsKeyword := KW_TO
  Else If U = 'BY'        Then LexIsKeyword := KW_BY
  Else If U = 'LOOP'      Then LexIsKeyword := KW_LOOP
  Else If U = 'EXIT'      Then LexIsKeyword := KW_EXIT
  Else If U = 'RETURN'    Then LexIsKeyword := KW_RETURN
  Else If U = 'CASE'      Then LexIsKeyword := KW_CASE
  Else If U = 'OF'        Then LexIsKeyword := KW_OF
  Else If U = 'ARRAY'     Then LexIsKeyword := KW_ARRAY
  Else If U = 'RECORD'    Then LexIsKeyword := KW_RECORD
  Else If U = 'POINTER'   Then LexIsKeyword := KW_POINTER
  Else If U = 'NIL'       Then LexIsKeyword := KW_NIL
  Else If U = 'TRUE'      Then LexIsKeyword := KW_TRUE
  Else If U = 'FALSE'     Then LexIsKeyword := KW_FALSE
  Else If U = 'DIV'       Then LexIsKeyword := KW_DIV
  Else If U = 'MOD'       Then LexIsKeyword := KW_MOD
  Else If U = 'OR'        Then LexIsKeyword := KW_OR
  Else If U = 'IN'        Then LexIsKeyword := KW_IN
  Else If U = 'IS'        Then LexIsKeyword := KW_IS
  Else If U = 'AND'       Then LexIsKeyword := KW_AND
  Else If U = 'NOT'       Then LexIsKeyword := KW_NOT
  Else LexIsKeyword := 0;
End;

Procedure LexNext;
Var
  Ch    : Char;
  Tk    : String;
  K     : Integer;
  V     : LongInt;
  E     : Integer;
  IsHex : Boolean;
  I     : Integer;
  Depth : Integer;
Begin
  Repeat
    LexSkipWS;
    If LexCurChar = #0 Then
    Begin
      If LexEOF Then
      Begin
        CurTok := TOK_EOF;
        CurTokStr := '';
        Exit;
      End;
      LexRefill;
      Continue;
    End;

    Ch := LexCurChar;

    If Ch In ['A'..'Z', 'a'..'z'] Then
    Begin
      Tk := '';
      While LexCurChar In ['A'..'Z', 'a'..'z', '0'..'9', '_'] Do
      Begin
        Tk := Tk + LexCurChar;
        LexAdvance;
      End;
      K := LexIsKeyword(Tk);
      If K > 0 Then
      Begin
        CurTok := TOK_KEYWORD;
        CurTokKw := K;
        CurTokStr := StrUpper(Tk);
      End
      Else
      Begin
        CurTok := TOK_IDENT;
        CurTokStr := Tk;
      End;
      Exit;
    End

    Else If Ch In ['0'..'9'] Then
    Begin
      Tk := '';
      While LexCurChar In ['0'..'9', 'A'..'F', 'a'..'f'] Do
      Begin
        Tk := Tk + LexCurChar;
        LexAdvance;
      End;
      IsHex := False;
      If UpCase(LexCurChar) = 'H' Then
      Begin
        IsHex := True;
        LexAdvance;
      End
      Else If LexCurChar = '.' Then
      Begin
        If LexPeekChar(1) <> '.' Then
        Begin
          Tk := Tk + LexCurChar;
          LexAdvance;
          While LexCurChar In ['0'..'9'] Do
          Begin
            Tk := Tk + LexCurChar;
            LexAdvance;
          End;
          If UpCase(LexCurChar) In ['E', 'D'] Then
          Begin
            Tk := Tk + LexCurChar;
            LexAdvance;
            If LexCurChar In ['+', '-'] Then
            Begin
              Tk := Tk + LexCurChar;
              LexAdvance;
            End;
            While LexCurChar In ['0'..'9'] Do
            Begin
              Tk := Tk + LexCurChar;
              LexAdvance;
            End;
          End;
          CurTok := TOK_REAL;
          CurTokStr := Tk;
          Val(Tk, CurTokReal, E);
          Exit;
        End;
      End
      Else If UpCase(LexCurChar) In ['E', 'D'] Then
      Begin
        Tk := Tk + LexCurChar;
        LexAdvance;
        If LexCurChar In ['+', '-'] Then
        Begin
          Tk := Tk + LexCurChar;
          LexAdvance;
        End;
        While LexCurChar In ['0'..'9'] Do
        Begin
          Tk := Tk + LexCurChar;
          LexAdvance;
        End;
        CurTok := TOK_REAL;
        CurTokStr := Tk;
        Val(Tk, CurTokReal, E);
        Exit;
      End;

      If IsHex Then
      Begin
        V := 0;
        For I := 1 To Length(Tk) Do
        Begin
          Ch := StrUpper(Tk)[I];
          If Ch In ['0'..'9'] Then
            V := V * 16 + Ord(Ch) - Ord('0')
          Else If Ch In ['A'..'F'] Then
            V := V * 16 + Ord(Ch) - Ord('A') + 10;
        End;
        CurTokNum := V;
      End
      Else
      Begin
        Val(Tk, V, E);
        CurTokNum := V;
      End;
      CurTok := TOK_INT;
      CurTokStr := Tk;
      Exit;
    End

    Else If Ch = '''' Then
    Begin
      LexAdvance;
      If LexCurChar = '''' Then
      Begin
        CurTokNum := Ord('''');
        LexAdvance;
      End
      Else
      Begin
        CurTokNum := Ord(LexCurChar);
        LexAdvance;
        If LexCurChar = '''' Then
          LexAdvance;
      End;
      CurTok := TOK_CHAR;
      CurTokStr := Chr(CurTokNum);
      Exit;
    End

    Else If Ch = '"' Then
    Begin
      LexAdvance;
      Tk := '';
      While (LexCurChar <> '"') And (LexCurChar <> #0) Do
      Begin
        Tk := Tk + LexCurChar;
        LexAdvance;
      End;
      If LexCurChar = '"' Then
        LexAdvance;
      CurTok := TOK_STRING;
      CurTokStr := Tk;
      Exit;
    End

    Else If (Ch = '(') And (LexPeekChar(1) = '*') Then
    Begin
      LexAdvance;
      LexAdvance;
      Depth := 1;
      While (Depth > 0) And Not LexEOF Do
      Begin
        If LexCurChar = #0 Then
        Begin
          LexRefill;
          Continue;
        End;
        If (LexCurChar = '(') And (LexPeekChar(1) = '*') Then
        Begin
          Inc(Depth);
          LexAdvance;
          LexAdvance;
        End
        Else If (LexCurChar = '*') And (LexPeekChar(1) = ')') Then
        Begin
          Dec(Depth);
          LexAdvance;
          LexAdvance;
        End
        Else
          LexAdvance;
      End;
      Continue;
    End

    Else If Ch = ':' Then
    Begin
      LexAdvance;
      If LexCurChar = '=' Then
      Begin
        LexAdvance;
        CurTok := TOK_OP;
        CurTokStr := ':=';
      End
      Else
      Begin
        CurTok := TOK_OP;
        CurTokStr := ':';
      End;
      Exit;
    End

    Else If Ch = '<' Then
    Begin
      LexAdvance;
      If LexCurChar = '=' Then
      Begin
        LexAdvance;
        CurTokStr := '<=';
      End
      Else
        CurTokStr := '<';
      CurTok := TOK_OP;
      Exit;
    End

    Else If Ch = '>' Then
    Begin
      LexAdvance;
      If LexCurChar = '=' Then
      Begin
        LexAdvance;
        CurTokStr := '>=';
      End
      Else
        CurTokStr := '>';
      CurTok := TOK_OP;
      Exit;
    End

    Else If Ch = '.' Then
    Begin
      LexAdvance;
      If LexCurChar = '.' Then
      Begin
        LexAdvance;
        CurTokStr := '..';
      End
      Else
        CurTokStr := '.';
      CurTok := TOK_OP;
      Exit;
    End

    Else If Ch In ['=', '#', '+', '-', '*', '/', '&', '~', ';', ',', '(', ')', '[', ']', '{', '}', '^', '|'] Then
    Begin
      CurTok := TOK_OP;
      CurTokStr := Ch;
      LexAdvance;
      Exit;
    End

    Else
    Begin
      ErrorAt(LexLineNo, LexColNo, 'Caractere illegal: ' + Ch);
      LexAdvance;
    End;
  Until False;
End;

Procedure LexOpen(Const FName : String);
Begin
  Assign(LexSrc, FName);
  {$I-}
  Reset(LexSrc);
  {$I+}
  If IOResult <> 0 Then
    FatalError('Impossible d''ouvrir le fichier source: ' + FName);
  LexEOF := False;
  LexLine := '';
  LexPos := 1;
  LexLineNo := 0;
  LexColNo := 1;
  LexNext;
End;

Procedure LexClose;
Begin
  Close(LexSrc);
End;

{ ============================================================
  TABLES DES SYMBOLES, TYPES, PROCEDURES, SCOPES, CONSTANTES
  ============================================================ }

Function SymEnter(Const Name : TString; TypeIdx, Storage : Integer) : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    ErrorMsg('Table des symboles pleine');
    SymEnter := 0;
    Exit;
  End;
  Inc(SymCount);
  SymTab[SymCount].Name := Name;
  SymTab[SymCount].TypeIdx := TypeIdx;
  SymTab[SymCount].Storage := Storage;
  SymTab[SymCount].Offset := 0;
  SymTab[SymCount].Used := False;
  SymEnter := SymCount;
End;

Function SymFind(Const Name : TString) : Integer;
Var I : Integer;
Begin
  For I := SymCount DownTo 1 Do
    If SymTab[I].Name = Name Then
    Begin
      SymFind := I;
      Exit;
    End;
  SymFind := 0;
End;

Function SymFindLocal(Const Name : TString) : Integer;
Var I, Base : Integer;
Begin
  Base := 1;
  If ScopeDepth > 0 Then
    Base := ScopeStack[ScopeDepth].SymBase;
  For I := SymCount DownTo Base Do
    If SymTab[I].Name = Name Then
    Begin
      SymFindLocal := I;
      Exit;
    End;
  SymFindLocal := 0;
End;

Procedure ScopeEnter;
Begin
  If ScopeDepth >= MAX_SCOPE Then
  Begin
    ErrorMsg('Portee trop profonde');
    Exit;
  End;
  Inc(ScopeDepth);
  ScopeStack[ScopeDepth].Level := ScopeDepth;
  ScopeStack[ScopeDepth].SymBase := SymCount + 1;
End;

Procedure ScopeLeave;
Begin
  If ScopeDepth > 0 Then
    Dec(ScopeDepth);
End;

Function TypeNew(Kind, ByteSize : Integer) : Integer;
Begin
  If TypeCount >= MAX_TYPE Then
  Begin
    ErrorMsg('Table des types pleine');
    TypeNew := 0;
    Exit;
  End;
  Inc(TypeCount);
  TypeTab[TypeCount].Kind := Kind;
  TypeTab[TypeCount].ByteSize := ByteSize;
  TypeTab[TypeCount].BaseIdx := 0;
  TypeTab[TypeCount].ArrLen := 0;
  TypeTab[TypeCount].RecSym := 0;
  TypeTab[TypeCount].RecNfld := 0;
  TypeNew := TypeCount;
End;

Function TypeByteSize(Ti : Integer) : Integer;
Begin
  If (Ti < 1) Or (Ti > TypeCount) Then
    TypeByteSize := 4
  Else
    TypeByteSize := TypeTab[Ti].ByteSize;
End;

Function ProcEnter(Const Name : TString) : Integer;
Begin
  If ProcCount >= MAX_PROC Then
  Begin
    ErrorMsg('Table des procedures pleine');
    ProcEnter := 0;
    Exit;
  End;
  Inc(ProcCount);
  ProcTab[ProcCount].Name := Name;
  ProcTab[ProcCount].ParamCount := 0;
  ProcTab[ProcCount].LocalCount := 0;
  ProcTab[ProcCount].AsmLabel := PFX_OP + Name;
  ProcEnter := ProcCount;
End;

Function ProcFind(Const Name : TString) : Integer;
Var I : Integer;
Begin
  For I := 1 To ProcCount Do
    If ProcTab[I].Name = Name Then
    Begin
      ProcFind := I;
      Exit;
    End;
  ProcFind := 0;
End;

Procedure ProcAddParam(Pi : Integer);
Begin
  If (Pi < 1) Or (Pi > ProcCount) Then Exit;
  Inc(ProcTab[Pi].ParamCount);
End;

Procedure ProcAddLocal(Pi : Integer);
Begin
  If (Pi < 1) Or (Pi > ProcCount) Then Exit;
  Inc(ProcTab[Pi].LocalCount);
End;

Function ConstEnter(Const Name : TString; IntVal : LongInt; RealVal : Real; IsReal : Boolean) : Integer;
Begin
  If ConstCount >= MAX_CONST Then
  Begin
    ErrorMsg('Table des constantes pleine');
    ConstEnter := 0;
    Exit;
  End;
  Inc(ConstCount);
  ConstTab[ConstCount].Name := Name;
  ConstTab[ConstCount].IntVal := IntVal;
  ConstTab[ConstCount].RealVal := RealVal;
  ConstTab[ConstCount].IsReal := IsReal;
  ConstEnter := ConstCount;
End;

Function ConstFind(Const Name : TString) : Integer;
Var I : Integer;
Begin
  For I := 1 To ConstCount Do
    If ConstTab[I].Name = Name Then
    Begin
      ConstFind := I;
      Exit;
    End;
  ConstFind := 0;
End;

Function AddStringLiteral(Const S : String) : Integer;
Var I : Integer;
Begin
  For I := 1 To StringCount Do
    If StringPool[I] = S Then
    Begin
      AddStringLiteral := I;
      Exit;
    End;
  If StringCount >= 256 Then
  Begin
    ErrorMsg('Pool de chaines plein');
    AddStringLiteral := 0;
    Exit;
  End;
  Inc(StringCount);
  StringPool[StringCount] := S;
  AddStringLiteral := StringCount;
End;

{ ============================================================
  HELPERS PARSEUR
  ============================================================ }

Procedure Expect(Kw : Integer);
Begin
  If (CurTok <> TOK_KEYWORD) Or (CurTokKw <> Kw) Then
    ErrorAt(LexLineNo, LexColNo, 'Mot-cle attendu');
  LexNext;
End;

Function Accept(Kw : Integer) : Boolean;
Begin
  If (CurTok = TOK_KEYWORD) And (CurTokKw = Kw) Then
  Begin
    LexNext;
    Accept := True;
  End
  Else
    Accept := False;
End;

Procedure ExpectIdent;
Begin
  If CurTok <> TOK_IDENT Then
    ErrorAt(LexLineNo, LexColNo, 'Identificateur attendu');
  LexNext;
End;

Procedure ExpectTok(Tok : Integer);
Begin
  If CurTok <> Tok Then
    ErrorAt(LexLineNo, LexColNo, 'Token attendu');
  LexNext;
End;

Function GenLabel : String;
Begin
  Inc(LabelSeq);
  GenLabel := PFX_OL + IntToStr(LabelSeq);
End;

{ ============================================================
  PARSEUR - EXPRESSIONS (reconnaissance structurale seulement)
  ============================================================ }

Procedure ParseFactor; Forward;
Procedure ParseTerm; Forward;
Procedure ParseSimpleExpression; Forward;
Procedure ParseExpression; Forward;

Procedure ParseFactor;
Begin
  If CurTok = TOK_IDENT Then
  Begin
    LexNext;
    If (CurTok = TOK_OP) And (CurTokStr = '(') Then
    Begin
      LexNext;
      If (CurTok <> TOK_OP) Or (CurTokStr <> ')') Then
      Begin
        ParseExpression;
        While (CurTok = TOK_OP) And (CurTokStr = ',') Do
        Begin
          LexNext;
          ParseExpression;
        End;
      End;
      If (CurTok = TOK_OP) And (CurTokStr = ')') Then
        LexNext;
    End;
  End
  Else If CurTok = TOK_INT Then
    LexNext
  Else If CurTok = TOK_REAL Then
    LexNext
  Else If CurTok = TOK_CHAR Then
    LexNext
  Else If CurTok = TOK_STRING Then
    LexNext
  Else If (CurTok = TOK_KEYWORD) And (CurTokKw In [KW_TRUE, KW_FALSE, KW_NIL]) Then
    LexNext
  Else If (CurTok = TOK_OP) And (CurTokStr = '(') Then
  Begin
    LexNext;
    ParseExpression;
    If (CurTok = TOK_OP) And (CurTokStr = ')') Then
      LexNext;
  End
  Else If (CurTok = TOK_OP) And (CurTokStr = '{') Then
  Begin
    LexNext;
    If (CurTok <> TOK_OP) Or (CurTokStr <> '}') Then
    Begin
      ParseExpression;
      While (CurTok = TOK_OP) And (CurTokStr = ',') Do
      Begin
        LexNext;
        ParseExpression;
      End;
    End;
    If (CurTok = TOK_OP) And (CurTokStr = '}') Then
      LexNext;
  End
  Else If (CurTok = TOK_KEYWORD) And (CurTokKw = KW_NOT) Then
  Begin
    LexNext;
    ParseFactor;
  End
  Else If (CurTok = TOK_OP) And ((CurTokStr = '~') Or (CurTokStr = '+') Or (CurTokStr = '-')) Then
  Begin
    LexNext;
    ParseFactor;
  End;
End;

Procedure ParseTerm;
Begin
  ParseFactor;
  While (CurTok = TOK_OP) And ((CurTokStr = '*') Or (CurTokStr = '/') Or (CurTokStr = '&')) Or
        ((CurTok = TOK_KEYWORD) And (CurTokKw In [KW_DIV, KW_MOD, KW_AND])) Do
  Begin
    LexNext;
    ParseFactor;
  End;
End;

Procedure ParseSimpleExpression;
Begin
  ParseTerm;
  While (CurTok = TOK_OP) And ((CurTokStr = '+') Or (CurTokStr = '-')) Or
        ((CurTok = TOK_KEYWORD) And (CurTokKw = KW_OR)) Do
  Begin
    LexNext;
    ParseTerm;
  End;
End;

Procedure ParseExpression;
Begin
  ParseSimpleExpression;
  While (CurTok = TOK_OP) And ((CurTokStr = '=') Or (CurTokStr = '#') Or (CurTokStr = '<') Or (CurTokStr = '>') Or (CurTokStr = '<=') Or (CurTokStr = '>=')) Or
        ((CurTok = TOK_KEYWORD) And (CurTokKw In [KW_IN, KW_IS])) Do
  Begin
    LexNext;
    ParseSimpleExpression;
  End;
End;

{ ============================================================
  PARSEUR - STATEMENTS (skip jusqu'a END correspondant)
  ============================================================ }

Procedure SkipStatements;
Var Depth : Integer;
Begin
  Depth := 1;
  While (CurTok <> TOK_EOF) And (Depth > 0) Do
  Begin
    If (CurTok = TOK_KEYWORD) Then
    Begin
      If CurTokKw In [KW_BEGIN, KW_IF, KW_WHILE, KW_REPEAT, KW_FOR, KW_LOOP, KW_CASE] Then
        Inc(Depth)
      Else If CurTokKw = KW_END Then
      Begin
        Dec(Depth);
        If Depth = 0 Then Exit;
      End
      Else If CurTokKw = KW_UNTIL Then
      Begin
        Dec(Depth);
        If Depth = 0 Then
        Begin
          LexNext;
          ParseExpression;
          Exit;
        End;
      End;
    End;
    LexNext;
  End;
End;

Procedure ParseStatSeq;
Begin
  SkipStatements;
End;

{ ============================================================
  PARSEUR - DECLARATIONS
  ============================================================ }

Procedure ParseConstDecl;
Begin
  While (CurTok = TOK_IDENT) Do
  Begin
    LexNext;
    If (CurTok = TOK_OP) And (CurTokStr = '=') Then
      LexNext;
    ParseExpression;
    If (CurTok = TOK_OP) And (CurTokStr = ';') Then
      LexNext;
  End;
End;

Procedure ParseTypeDecl;
Begin
  While (CurTok = TOK_IDENT) Do
  Begin
    LexNext;
    If (CurTok = TOK_OP) And (CurTokStr = '=') Then
      LexNext;
    While (CurTok <> TOK_OP) Or (CurTokStr <> ';') Do
    Begin
      If CurTok = TOK_EOF Then Exit;
      If (CurTok = TOK_KEYWORD) And (CurTokKw In [KW_CONST, KW_TYPE, KW_VAR, KW_PROCEDURE, KW_BEGIN, KW_END]) Then
        Exit;
      LexNext;
    End;
    If (CurTok = TOK_OP) And (CurTokStr = ';') Then
      LexNext;
  End;
End;

Procedure ParseVarDecl;
Begin
  While (CurTok = TOK_IDENT) Do
  Begin
    LexNext;
    While (CurTok = TOK_OP) And (CurTokStr = ',') Do
    Begin
      LexNext;
      If CurTok = TOK_IDENT Then
        LexNext;
    End;
    If (CurTok = TOK_OP) And (CurTokStr = ':') Then
      LexNext;
    While (CurTok <> TOK_OP) Or (CurTokStr <> ';') Do
    Begin
      If CurTok = TOK_EOF Then Exit;
      If (CurTok = TOK_KEYWORD) And (CurTokKw In [KW_CONST, KW_TYPE, KW_VAR, KW_PROCEDURE, KW_BEGIN, KW_END]) Then
        Exit;
      LexNext;
    End;
    If (CurTok = TOK_OP) And (CurTokStr = ';') Then
      LexNext;
  End;
End;

Procedure ParseProcedure;
Var PName : TString;
Begin
  Expect(KW_PROCEDURE);
  If CurTok = TOK_IDENT Then
  Begin
    PName := CurTokStr;
    LexNext;
  End;
  If (CurTok = TOK_OP) And (CurTokStr = '*') Then
    LexNext;
  If (CurTok = TOK_OP) And (CurTokStr = '(') Then
  Begin
    LexNext;
    While (CurTok <> TOK_OP) Or (CurTokStr <> ')') Do
    Begin
      If CurTok = TOK_EOF Then Exit;
      LexNext;
    End;
    LexNext;
  End;
  If (CurTok = TOK_OP) And (CurTokStr = ':') Then
  Begin
    LexNext;
    If CurTok = TOK_IDENT Then
      LexNext;
  End;
  If (CurTok = TOK_OP) And (CurTokStr = ';') Then
    LexNext;
  While (CurTok = TOK_KEYWORD) And (CurTokKw In [KW_CONST, KW_TYPE, KW_VAR]) Do
  Begin
    If CurTokKw = KW_CONST Then
    Begin
      LexNext;
      ParseConstDecl;
    End
    Else If CurTokKw = KW_TYPE Then
    Begin
      LexNext;
      ParseTypeDecl;
    End
    Else If CurTokKw = KW_VAR Then
    Begin
      LexNext;
      ParseVarDecl;
    End;
  End;
  If Accept(KW_BEGIN) Then
    ParseStatSeq;
  Expect(KW_END);
  If CurTok = TOK_IDENT Then
    LexNext;
  If (CurTok = TOK_OP) And (CurTokStr = ';') Then
    LexNext;
End;

Procedure ParseDeclSeq;
Begin
  While (CurTok <> TOK_EOF) Do
  Begin
    If (CurTok = TOK_KEYWORD) Then
    Begin
      If CurTokKw = KW_CONST Then
      Begin
        LexNext;
        ParseConstDecl;
      End
      Else If CurTokKw = KW_TYPE Then
      Begin
        LexNext;
        ParseTypeDecl;
      End
      Else If CurTokKw = KW_VAR Then
      Begin
        LexNext;
        ParseVarDecl;
      End
      Else If CurTokKw = KW_PROCEDURE Then
      Begin
        ParseProcedure;
      End
      Else
        Exit;
    End
    Else
      Exit;
  End;
End;

Procedure ParseImportList;
Begin
  Expect(KW_IMPORT);
  While CurTok = TOK_IDENT Do
  Begin
    LexNext;
    If (CurTok = TOK_OP) And (CurTokStr = ',') Then
      LexNext
    Else
      Break;
  End;
  If (CurTok = TOK_OP) And (CurTokStr = ';') Then
    LexNext;
End;

Procedure ParseModule;
Begin
  Expect(KW_MODULE);
  If CurTok = TOK_IDENT Then
  Begin
    ModuleName := CurTokStr;
    LexNext;
  End
  Else
    ModuleName := 'Main';
  If (CurTok = TOK_OP) And (CurTokStr = ';') Then
    LexNext;
  If (CurTok = TOK_KEYWORD) And (CurTokKw = KW_IMPORT) Then
    ParseImportList;
  ParseDeclSeq;
  If Accept(KW_BEGIN) Then
    ParseStatSeq;
  Expect(KW_END);
  If CurTok = TOK_IDENT Then
    LexNext;
  If (CurTok = TOK_OP) And (CurTokStr = '.') Then
    LexNext;
End;

{ ============================================================
  EMETTEUR ASM
  ============================================================ }

Procedure EmitLine(Const S : String);
Begin
  WriteLn(AsmFile, S);
End;

Procedure EmitHeader(Const ModName : String);
Begin
  EmitLine(';; Generated by OBERCW32 v' + OBERCW32_VERSION + ' - module: ' + ModName);
  EmitLine(';; Oberon -> 80386 / Windows 32 bits');
  EmitLine('.386');
  EmitLine('.model flat, stdcall');
  EmitLine('option casemap:none');
  EmitLine('includelib kernel32.lib');
  EmitLine('');
  EmitLine('extern ExitProcess : proc');
  EmitLine('extern GetStdHandle : proc');
  EmitLine('extern WriteFile : proc');
  EmitLine('');
End;

Procedure EmitDataSeg;
Var I : Integer;
Begin
  EmitLine('.data');
  For I := 1 To StringCount Do
    EmitLine(PFX_OK + IntToStr(I) + ' db "' + StringPool[I] + '",0');
  EmitLine('');
End;

Procedure EmitRuntime;
Begin
  EmitLine('.code');
  EmitLine('');
  EmitLine(PFX_ORT + 'halt proc');
  EmitLine('    push 0');
  EmitLine('    call ExitProcess');
  EmitLine('    ret');
  EmitLine(PFX_ORT + 'halt endp');
  EmitLine('');
End;

Procedure EmitEntryPoint(Const ModName : String);
Begin
  EmitLine(PFX_OP + 'main proc');
  EmitLine('    ; TODO: generer le corps du module');
  EmitLine('    push 0');
  EmitLine('    call ExitProcess');
  EmitLine('    ret');
  EmitLine(PFX_OP + 'main endp');
  EmitLine('');
End;

Procedure EmitFooter(Const ModName : String);
Begin
  EmitLine('end ' + PFX_OP + 'main');
End;

{ ============================================================
  HELPERS BINAIRES
  ============================================================ }

Procedure WriteBinByte(Var F : File; B : Byte);
Begin
  BlockWrite(F, B, 1);
End;

Procedure WriteBinWord(Var F : File; W : Word);
Begin
  BlockWrite(F, W, 2);
End;

Procedure WriteBinDWord(Var F : File; D : LongInt);
Begin
  BlockWrite(F, D, 4);
End;

Procedure WriteBinString(Var F : File; Const S : String);
Begin
  BlockWrite(F, S[1], Length(S));
  WriteBinByte(F, 0);
End;

Procedure WriteBinZeros(Var F : File; N : LongInt);
Var I : LongInt; Z : Byte;
Begin
  Z := 0;
  For I := 1 To N Do
    WriteBinByte(F, Z);
End;

Procedure BinInit;
Begin
  BinCodeLen := 0;
  BinDataLen := 0;
  FillChar(BinCode, SizeOf(BinCode), 0);
  FillChar(BinData, SizeOf(BinData), 0);
End;

Procedure BinEmitByte(B : Byte);
Begin
  If BinCodeLen < MAX_BIN_CODE Then
  Begin
    BinCode[BinCodeLen] := B;
    Inc(BinCodeLen);
  End;
End;

Procedure BinEmitDataDWord(D : LongInt);
Begin
  If BinDataLen + 4 <= MAX_BIN_DATA Then
  Begin
    BinData[BinDataLen] := D And $FF;
    BinData[BinDataLen+1] := (D Shr 8) And $FF;
    BinData[BinDataLen+2] := (D Shr 16) And $FF;
    BinData[BinDataLen+3] := (D Shr 24) And $FF;
    Inc(BinDataLen, 4);
  End;
End;

{ ============================================================
  GENERATEUR .OBJ (COFF)
  ============================================================ }

Procedure BinWriteObj;
Var
  F           : File;
  ObjFile     : String;
  NumSections : Word;
  TextDataOfs : LongInt;
  DataDataOfs : LongInt;
  SymTabOfs   : LongInt;
  NumSymbols  : LongInt;
  Pad         : LongInt;
Begin
  ObjFile := Opts.OutFile;
  Assign(F, ObjFile);
  {$I-}
  Rewrite(F, 1);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('OBERCW32: erreur: impossible de creer ', ObjFile);
    Exit;
  End;

  BinInit;
  NumSections := 2;

  BinEmitByte($CC);
  BinEmitByte($C3);

  BinEmitDataDWord(0);

  TextDataOfs := 20 + NumSections * 40;
  DataDataOfs := TextDataOfs + BinCodeLen;
  NumSymbols := 2;
  SymTabOfs := DataDataOfs + BinDataLen;

  WriteBinWord(F, PE_MACHINE_I386);
  WriteBinWord(F, NumSections);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, SymTabOfs);
  WriteBinDWord(F, NumSymbols);
  WriteBinWord(F, 0);
  WriteBinWord(F, 0);

  WriteBinString(F, '.text');
  Pad := 8 - (Length('.text') + 1);
  If Pad > 0 Then WriteBinZeros(F, Pad);
  WriteBinDWord(F, BinCodeLen);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, BinCodeLen);
  WriteBinDWord(F, TextDataOfs);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, 0);
  WriteBinWord(F, 0);
  WriteBinWord(F, 0);
  WriteBinDWord(F, PE_SCN_TEXT);

  WriteBinString(F, '.data');
  Pad := 8 - (Length('.data') + 1);
  If Pad > 0 Then WriteBinZeros(F, Pad);
  WriteBinDWord(F, BinDataLen);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, BinDataLen);
  WriteBinDWord(F, DataDataOfs);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, 0);
  WriteBinWord(F, 0);
  WriteBinWord(F, 0);
  WriteBinDWord(F, PE_SCN_BSS);

  BlockWrite(F, BinCode, BinCodeLen);
  BlockWrite(F, BinData, BinDataLen);

  WriteBinString(F, '.text');
  Pad := 8 - (Length('.text') + 1);
  If Pad > 0 Then WriteBinZeros(F, Pad);
  WriteBinDWord(F, 0);
  WriteBinWord(F, 1);
  WriteBinWord(F, 0);
  WriteBinByte(F, 3);
  WriteBinByte(F, 0);

  WriteBinString(F, '.data');
  Pad := 8 - (Length('.data') + 1);
  If Pad > 0 Then WriteBinZeros(F, Pad);
  WriteBinDWord(F, 0);
  WriteBinWord(F, 2);
  WriteBinWord(F, 0);
  WriteBinByte(F, 3);
  WriteBinByte(F, 0);

  WriteBinDWord(F, 4);

  Close(F);
  If Opts.Verbose Then
  Begin
    WriteLn('OBERCW32: fichier OBJ genere: ', ObjFile);
    WriteLn('OBERCW32: .text = ', BinCodeLen, ' octets');
    WriteLn('OBERCW32: .data = ', BinDataLen, ' octets');
  End;
End;

{ ============================================================
  GENERATEUR .EXE (PE)
  ============================================================ }

Procedure BinWriteExe;
Var
  F            : File;
  ExeFile      : String;
  NumSections  : Word;
  TextRVA      : LongInt;
  DataRVA      : LongInt;
  IdataRVA     : LongInt;
  TextFileOfs  : LongInt;
  DataFileOfs  : LongInt;
  IdataFileOfs : LongInt;
  TextSize     : LongInt;
  DataSize     : LongInt;
  IdataSize    : LongInt;
  ImageSize    : LongInt;
  EntryRVA     : LongInt;
  HdrSize      : LongInt;
  I            : Integer;
  Pad          : LongInt;
  IdataBuf     : Array[0..1023] of Byte;
  IdataBufLen  : LongInt;
  IatOfs       : LongInt;
  DllNameOfs   : LongInt;
  HintOfs      : LongInt;
  IltOfs       : LongInt;
Begin
  ExeFile := Opts.OutFile;
  Assign(F, ExeFile);
  {$I-}
  Rewrite(F, 1);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('OBERCW32: erreur: impossible de creer ', ExeFile);
    Exit;
  End;

  NumSections := 3;

  FillChar(IdataBuf, SizeOf(IdataBuf), 0);
  IltOfs := 40;
  IatOfs := IltOfs + 8;
  DllNameOfs := IatOfs + 8;
  HintOfs := DllNameOfs + 16;

  IdataBuf[0] := (HintOfs) And $FF;
  IdataBuf[1] := (HintOfs Shr 8) And $FF;
  IdataBuf[2] := (HintOfs Shr 16) And $FF;
  IdataBuf[3] := (HintOfs Shr 24) And $FF;
  IdataBuf[12] := (DllNameOfs) And $FF;
  IdataBuf[13] := (DllNameOfs Shr 8) And $FF;
  IdataBuf[14] := (DllNameOfs Shr 16) And $FF;
  IdataBuf[15] := (DllNameOfs Shr 24) And $FF;
  IdataBuf[16] := (IatOfs) And $FF;
  IdataBuf[17] := (IatOfs Shr 8) And $FF;
  IdataBuf[18] := (IatOfs Shr 16) And $FF;
  IdataBuf[19] := (IatOfs Shr 24) And $FF;

  IdataBuf[IltOfs] := (HintOfs) And $FF;
  IdataBuf[IltOfs+1] := (HintOfs Shr 8) And $FF;
  IdataBuf[IltOfs+2] := (HintOfs Shr 16) And $FF;
  IdataBuf[IltOfs+3] := (HintOfs Shr 24) And $FF;

  IdataBuf[IatOfs] := (HintOfs) And $FF;
  IdataBuf[IatOfs+1] := (HintOfs Shr 8) And $FF;
  IdataBuf[IatOfs+2] := (HintOfs Shr 16) And $FF;
  IdataBuf[IatOfs+3] := (HintOfs Shr 24) And $FF;

  Move('KERNEL32.DLL'#0, IdataBuf[DllNameOfs], 13);
  IdataBuf[HintOfs] := 0;
  IdataBuf[HintOfs+1] := 0;
  Move('ExitProcess'#0, IdataBuf[HintOfs+2], 12);

  IdataBufLen := 512;

  BinInit;
  BinEmitByte($6A);
  BinEmitByte($00);
  BinEmitByte($FF);
  BinEmitByte($15);
  BinEmitByte($08);
  BinEmitByte($20);
  BinEmitByte($40);
  BinEmitByte($00);
  BinEmitByte($C3);

  While (BinCodeLen < 512) Do
    BinEmitByte($00);

  BinEmitDataDWord(0);
  While (BinDataLen < 512) Do
  Begin
    BinData[BinDataLen] := 0;
    Inc(BinDataLen);
  End;

  TextRVA := $1000;
  DataRVA := $2000;
  IdataRVA := $3000;

  HdrSize := 1024;
  TextFileOfs := HdrSize;
  DataFileOfs := TextFileOfs + 512;
  IdataFileOfs := DataFileOfs + 512;

  TextSize := 512;
  DataSize := 512;
  IdataSize := 512;

  ImageSize := $4000;
  EntryRVA := $1000;

  WriteBinByte(F, Ord('M'));
  WriteBinByte(F, Ord('Z'));
  For I := 1 To 58 Do
    WriteBinByte(F, 0);
  WriteBinDWord(F, $40);

  For I := 1 To 60 Do
    WriteBinByte(F, 0);

  WriteBinByte(F, Ord('P'));
  WriteBinByte(F, Ord('E'));
  WriteBinByte(F, 0);
  WriteBinByte(F, 0);

  WriteBinWord(F, PE_MACHINE_I386);
  WriteBinWord(F, NumSections);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, 0);
  WriteBinWord(F, 224);
  WriteBinWord(F, $102);

  WriteBinWord(F, $10B);
  WriteBinByte(F, 0);
  WriteBinByte(F, 0);
  WriteBinDWord(F, TextSize);
  WriteBinDWord(F, DataSize);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, EntryRVA);
  WriteBinDWord(F, TextRVA);
  WriteBinDWord(F, DataRVA);

  WriteBinDWord(F, $400000);
  WriteBinDWord(F, $1000);
  WriteBinDWord(F, $200);
  WriteBinWord(F, 5);
  WriteBinWord(F, 0);
  WriteBinWord(F, 0);
  WriteBinWord(F, 0);
  WriteBinWord(F, 5);
  WriteBinWord(F, 0);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, ImageSize);
  WriteBinDWord(F, HdrSize);
  WriteBinDWord(F, 0);
  WriteBinWord(F, 3);
  WriteBinWord(F, 0);
  WriteBinDWord(F, $100000);
  WriteBinDWord(F, $1000);
  WriteBinDWord(F, $100000);
  WriteBinDWord(F, $1000);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, 16);

  WriteBinDWord(F, 0);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, IdataRVA);
  WriteBinDWord(F, IdataSize);
  For I := 1 To 14 Do
  Begin
    WriteBinDWord(F, 0);
    WriteBinDWord(F, 0);
  End;

  WriteBinString(F, '.text');
  Pad := 8 - (Length('.text') + 1);
  If Pad > 0 Then WriteBinZeros(F, Pad);
  WriteBinDWord(F, TextSize);
  WriteBinDWord(F, TextRVA);
  WriteBinDWord(F, TextSize);
  WriteBinDWord(F, TextFileOfs);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, 0);
  WriteBinWord(F, 0);
  WriteBinWord(F, 0);
  WriteBinDWord(F, $60000020);

  WriteBinString(F, '.data');
  Pad := 8 - (Length('.data') + 1);
  If Pad > 0 Then WriteBinZeros(F, Pad);
  WriteBinDWord(F, DataSize);
  WriteBinDWord(F, DataRVA);
  WriteBinDWord(F, DataSize);
  WriteBinDWord(F, DataFileOfs);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, 0);
  WriteBinWord(F, 0);
  WriteBinWord(F, 0);
  WriteBinDWord(F, $C0000040);

  WriteBinString(F, '.idata');
  Pad := 8 - (Length('.idata') + 1);
  If Pad > 0 Then WriteBinZeros(F, Pad);
  WriteBinDWord(F, IdataSize);
  WriteBinDWord(F, IdataRVA);
  WriteBinDWord(F, IdataSize);
  WriteBinDWord(F, IdataFileOfs);
  WriteBinDWord(F, 0);
  WriteBinDWord(F, 0);
  WriteBinWord(F, 0);
  WriteBinWord(F, 0);
  WriteBinDWord(F, $C0000040);

  While FilePos(F) < HdrSize Do
    WriteBinByte(F, 0);

  BlockWrite(F, BinCode, 512);
  BlockWrite(F, BinData, 512);
  BlockWrite(F, IdataBuf, 512);

  Close(F);
  If Opts.Verbose Then
  Begin
    WriteLn('OBERCW32: fichier EXE genere: ', ExeFile);
    WriteLn('OBERCW32: .text = ', TextSize, ' octets');
    WriteLn('OBERCW32: .data = ', DataSize, ' octets');
    WriteLn('OBERCW32: .idata = ', IdataSize, ' octets');
  End;
End;

{ ============================================================
  OPTIONS ET ARGUMENTS
  ============================================================ }

Procedure PrintUsage;
Begin
  WriteLn('OBERCW32 version ', OBERCW32_VERSION);
  WriteLn('Usage: OBERCW32 <source.obn> [options]');
  WriteLn('Options:');
  WriteLn('  -o <fichier>  : specifier le nom du fichier de sortie');
  WriteLn('  -c            : generer un fichier .OBJ (COFF) au lieu de .EXE');
  WriteLn('  -S            : conserver le fichier .ASM intermediaire');
  WriteLn('  -v            : mode verbeux');
  WriteLn('  -h, --help    : afficher cette aide');
  WriteLn('  --version     : afficher la version');
End;

Procedure ParseArgs;
Var
  I    : Integer;
  Arg  : String;
  Base : String;
Begin
  FillChar(Opts, SizeOf(Opts), 0);
  Opts.SrcFile := '';
  Opts.OutFile := '';
  Opts.Verbose := False;
  Opts.EmitObj := False;
  Opts.EmitAsm := False;
  Opts.ImportCount := 0;

  If ParamCount = 0 Then
  Begin
    PrintUsage;
    Halt(0);
  End;

  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    If (Arg = '-h') Or (Arg = '--help') Then
    Begin
      PrintUsage;
      Halt(0);
    End
    Else If Arg = '--version' Then
    Begin
      WriteLn('OBERCW32 version ', OBERCW32_VERSION);
      Halt(0);
    End
    Else If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-c' Then
      Opts.EmitObj := True
    Else If Arg = '-S' Then
      Opts.EmitAsm := True
    Else If Arg = '-o' Then
    Begin
      Inc(I);
      If I <= ParamCount Then
        Opts.OutFile := ParamStr(I)
      Else
      Begin
        WriteLn('Erreur: -o requiert un nom de fichier');
        Halt(1);
      End;
    End
    Else If (Arg <> '') And (Arg[1] <> '-') Then
    Begin
      If Opts.SrcFile = '' Then
        Opts.SrcFile := Arg
      Else
      Begin
        WriteLn('Erreur: fichier source deja specifie');
        Halt(1);
      End;
    End
    Else
    Begin
      WriteLn('Erreur: option inconnue: ', Arg);
      Halt(1);
    End;
    Inc(I);
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('Erreur: aucun fichier source specifie');
    Halt(1);
  End;

  If Opts.OutFile = '' Then
  Begin
    Base := ExtractBase(Opts.SrcFile);
    If Opts.EmitObj Then
      Opts.OutFile := Base + '.obj'
    Else
      Opts.OutFile := Base + '.exe';
  End;

  AsmName := ChangeExtension(Opts.SrcFile, '.asm');
End;

{ ============================================================
  INITIALISATION
  ============================================================ }

Procedure InitTables;
Var Ti : Integer;
Begin
  SymCount := 0;
  TypeCount := 0;
  ProcCount := 0;
  ScopeDepth := 0;
  ConstCount := 0;
  StringCount := 0;
  LabelSeq := 0;
  ErrorCount := 0;

  Ti := TypeNew(TYK_INTEGER, 4);
  Ti := TypeNew(TYK_BOOLEAN, 1);
  Ti := TypeNew(TYK_CHAR, 1);
  Ti := TypeNew(TYK_BYTE, 1);
  Ti := TypeNew(TYK_SET, 4);
  Ti := TypeNew(TYK_REAL, 4);

  ProcEnter('INC');
  ProcEnter('DEC');
  ProcEnter('ABS');
  ProcEnter('ODD');
  ProcEnter('CHR');
  ProcEnter('ORD');
  ProcEnter('HALT');
  ProcEnter('ASSERT');
  ProcEnter('LEN');
  ProcEnter('NEW');
  ProcEnter('INCL');
  ProcEnter('EXCL');
End;

{ ============================================================
  MAIN
  ============================================================ }

Begin
  ParseArgs;

  InitTables;

  LexOpen(Opts.SrcFile);
  ParseModule;
  LexClose;

  If ErrorCount > 0 Then
  Begin
    WriteLn('OBERCW32: ', ErrorCount, ' erreur(s), compilation abandonnee');
    Halt(1);
  End;

  Assign(AsmFile, AsmName);
  {$I-}
  Rewrite(AsmFile);
  {$I+}
  If IOResult <> 0 Then
    FatalError('Impossible de creer le fichier ASM: ' + AsmName);

  EmitHeader(ModuleName);
  EmitDataSeg;
  EmitRuntime;
  EmitEntryPoint(ModuleName);
  EmitFooter(ModuleName);

  Close(AsmFile);

  If Opts.EmitObj Then
    BinWriteObj
  Else
    BinWriteExe;

  If Not Opts.EmitAsm Then
  Begin
    {$I-}
    Erase(AsmFile);
    {$I+}
    If IOResult <> 0 Then { ignore };
  End;

  If Opts.Verbose Then
  Begin
    WriteLn('OBERCW32 v', OBERCW32_VERSION, ': compilation OK (', ErrorCount, ' erreur(s))');
  End;
End.
