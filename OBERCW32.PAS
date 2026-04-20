{ @author: Gladir.com
  @created: 2026-04-20
  @version: 2.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Oberon vers Win32 PE executables natifs
  @license: MIT
}

Program OBERCW32;

{$I-}

Const
  OBERCW32_VERSION = '2.0';
  OBERCW32_DATE    = '2026-04-20';

  MAX_SYM    = 2048;
  MAX_PROC   = 256;
  MAX_CONST  = 1024;
  MAX_TYPE   = 256;
  MAX_STR    = 255;
  MAX_ERRORS = 50;
  MAX_FIXUP  = 8192;
  MAX_LABEL  = 4096;

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
  KW_RETURN    = 20;
  KW_DIV       = 21;
  KW_MOD       = 22;
  KW_OR        = 23;
  KW_AND       = 24;
  KW_NOT       = 25;
  KW_TRUE      = 26;
  KW_FALSE     = 27;
  KW_NIL       = 28;

  TYK_INTEGER   = 1;
  TYK_BOOLEAN   = 2;
  TYK_CHAR      = 3;

  FIX_IAT_GETSTD   = 1;
  FIX_IAT_WRITE    = 2;
  FIX_IAT_EXIT     = 3;
  FIX_STRING       = 4;
  FIX_VAR          = 5;
  FIX_CODE_REL     = 6;
  FIX_INTBUF       = 7;
  FIX_BYTES_WRITTEN = 8;
  FIX_STDOUT       = 9;
  FIX_CRLF         = 10;
  FIX_INTBUF_END   = 11;

  PE_MACHINE_I386 = $014C;

  MAX_BIN_CODE = 262144;
  MAX_BIN_DATA = 65536;

Type
  TString = String[MAX_STR];

  TOptions = Record
    SrcFile     : String;
    OutFile     : String;
    Verbose     : Boolean;
    EmitObj     : Boolean;
    EmitAsm     : Boolean;
  End;

  TSymEntry = Record
    Name     : TString;
    TypeIdx  : Integer;
    DataOffs : Integer;
    Used     : Boolean;
  End;

  TTypeEntry = Record
    Kind     : Integer;
    ByteSize : Integer;
  End;

  TFixup = Record
    Offset : LongInt;
    Kind   : Integer;
    Target : LongInt;
  End;

  TLabel = Record
    Name   : TString;
    Offset : LongInt;
    Defined : Boolean;
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
  CurTokKw    : Integer;

  SymTab      : Array[1..MAX_SYM] of TSymEntry;
  SymCount    : Integer;

  TypeTab     : Array[1..MAX_TYPE] of TTypeEntry;
  TypeCount   : Integer;

  ConstTab    : Array[1..MAX_CONST] of TSymEntry;
  ConstCount  : Integer;

  StringPool  : Array[1..256] of String;
  StringCount : Integer;

  Fixups      : Array[1..MAX_FIXUP] of TFixup;
  FixupCount  : Integer;

  Labels      : Array[1..MAX_LABEL] of TLabel;
  LabelCount  : Integer;

  LabelSeq    : Integer;
  ErrorCount  : Integer;
  ModuleName  : TString;

  AsmFile     : Text;
  AsmName     : String;

  BinCode     : Array[0..MAX_BIN_CODE-1] of Byte;
  BinData     : Array[0..MAX_BIN_DATA-1] of Byte;
  BinCodeLen  : Integer;
  BinDataLen  : Integer;

  DataOffset  : Integer;

Function IntToStr(V : LongInt) : String;
Var S : String;
Begin
  Str(V, S);
  IntToStr := S;
End;

Function StrToInt(Const S : String) : LongInt;
Var V : LongInt; E : Integer;
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
  Else If U = 'RETURN'    Then LexIsKeyword := KW_RETURN
  Else If U = 'DIV'       Then LexIsKeyword := KW_DIV
  Else If U = 'MOD'       Then LexIsKeyword := KW_MOD
  Else If U = 'OR'        Then LexIsKeyword := KW_OR
  Else If U = 'AND'       Then LexIsKeyword := KW_AND
  Else If U = 'NOT'       Then LexIsKeyword := KW_NOT
  Else If U = 'TRUE'      Then LexIsKeyword := KW_TRUE
  Else If U = 'FALSE'     Then LexIsKeyword := KW_FALSE
  Else If U = 'NIL'       Then LexIsKeyword := KW_NIL
  Else LexIsKeyword := 0;
End;

Procedure LexNext;
Var
  Ch    : Char;
  Tk    : String;
  K     : Integer;
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
      While LexCurChar In ['0'..'9'] Do
      Begin
        Tk := Tk + LexCurChar;
        LexAdvance;
      End;
      CurTok := TOK_INT;
      CurTokNum := StrToInt(Tk);
      CurTokStr := Tk;
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
      While (Depth > 0) And (Not LexEOF) Do
      Begin
        If LexCurChar = #0 Then
          LexRefill
        Else If (LexCurChar = '(') And (LexPeekChar(1) = '*') Then
        Begin
          LexAdvance;
          LexAdvance;
          Inc(Depth);
        End
        Else If (LexCurChar = '*') And (LexPeekChar(1) = ')') Then
        Begin
          LexAdvance;
          LexAdvance;
          Dec(Depth);
        End
        Else
          LexAdvance;
      End;
      Continue;
    End

    Else If (Ch = '<') And (LexPeekChar(1) = '=') Then
    Begin
      CurTok := TOK_OP;
      CurTokStr := '<=';
      LexAdvance;
      LexAdvance;
      Exit;
    End
    Else If (Ch = '>') And (LexPeekChar(1) = '=') Then
    Begin
      CurTok := TOK_OP;
      CurTokStr := '>=';
      LexAdvance;
      LexAdvance;
      Exit;
    End
    Else If (Ch = ':') And (LexPeekChar(1) = '=') Then
    Begin
      CurTok := TOK_OP;
      CurTokStr := ':=';
      LexAdvance;
      LexAdvance;
      Exit;
    End
    Else If Ch In ['(', ')', '[', ']', '{', '}', ',', ';', ':', '.', '=', '#', '<', '>', '+', '-', '*', '/', '&', '~'] Then
    Begin
      CurTok := TOK_OP;
      CurTokStr := Ch;
      LexAdvance;
      Exit;
    End
    Else
    Begin
      ErrorAt(LexLineNo, LexColNo, 'Caractere invalide: ' + Ch);
      LexAdvance;
      Continue;
    End;
  Until False;
End;

Procedure LexOpen(Const FileName : String);
Begin
  Assign(LexSrc, FileName);
  {$I-}
  Reset(LexSrc);
  {$I+}
  If IOResult <> 0 Then
    FatalError('Impossible d''ouvrir le fichier source: ' + FileName);
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

Function TypeNew(Kind : Integer; ByteSize : Integer) : Integer;
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
  TypeNew := TypeCount;
End;

Function TypeByteSize(Ti : Integer) : Integer;
Begin
  If (Ti < 1) Or (Ti > TypeCount) Then
    TypeByteSize := 4
  Else
    TypeByteSize := TypeTab[Ti].ByteSize;
End;

Function SymEnter(Const Name : TString; TypeIdx : Integer) : Integer;
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
  SymTab[SymCount].DataOffs := DataOffset;
  SymTab[SymCount].Used := False;
  Inc(DataOffset, TypeByteSize(TypeIdx));
  SymEnter := SymCount;
End;

Function SymFind(Const Name : TString) : Integer;
Var I : Integer;
Begin
  For I := 1 To SymCount Do
    If SymTab[I].Name = Name Then
    Begin
      SymFind := I;
      Exit;
    End;
  SymFind := 0;
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

Procedure AddFixup(Kind : Integer; Target : LongInt);
Begin
  If FixupCount >= MAX_FIXUP Then
  Begin
    ErrorMsg('Table de fixup pleine');
    Exit;
  End;
  Inc(FixupCount);
  Fixups[FixupCount].Offset := BinCodeLen;
  Fixups[FixupCount].Kind := Kind;
  Fixups[FixupCount].Target := Target;
End;

Function GenLabel : String;
Begin
  Inc(LabelSeq);
  GenLabel := 'L' + IntToStr(LabelSeq);
End;

Function DefineLabel(Const Name : TString) : Integer;
Var I : Integer;
Begin
  For I := 1 To LabelCount Do
    If Labels[I].Name = Name Then
    Begin
      Labels[I].Offset := BinCodeLen;
      Labels[I].Defined := True;
      DefineLabel := I;
      Exit;
    End;
  If LabelCount >= MAX_LABEL Then
  Begin
    ErrorMsg('Table de labels pleine');
    DefineLabel := 0;
    Exit;
  End;
  Inc(LabelCount);
  Labels[LabelCount].Name := Name;
  Labels[LabelCount].Offset := BinCodeLen;
  Labels[LabelCount].Defined := True;
  DefineLabel := LabelCount;
End;

Function FindLabel(Const Name : TString) : Integer;
Var I : Integer;
Begin
  For I := 1 To LabelCount Do
    If Labels[I].Name = Name Then
    Begin
      FindLabel := I;
      Exit;
    End;
  If LabelCount >= MAX_LABEL Then
  Begin
    ErrorMsg('Table de labels pleine');
    FindLabel := 0;
    Exit;
  End;
  Inc(LabelCount);
  Labels[LabelCount].Name := Name;
  Labels[LabelCount].Offset := 0;
  Labels[LabelCount].Defined := False;
  FindLabel := LabelCount;
End;

Procedure BinEmitByte(B : Byte);
Begin
  If BinCodeLen < MAX_BIN_CODE Then
  Begin
    BinCode[BinCodeLen] := B;
    Inc(BinCodeLen);
  End;
End;

Procedure BinEmitWord(W : Word);
Begin
  BinEmitByte(W And $FF);
  BinEmitByte((W Shr 8) And $FF);
End;

Procedure BinEmitDWord(D : LongInt);
Begin
  BinEmitByte(D And $FF);
  BinEmitByte((D Shr 8) And $FF);
  BinEmitByte((D Shr 16) And $FF);
  BinEmitByte((D Shr 24) And $FF);
End;

Procedure EmitPushImm32(Val : LongInt);
Begin
  BinEmitByte($68);
  BinEmitDWord(Val);
End;

Procedure EmitPushEAX;
Begin
  BinEmitByte($50);
End;

Procedure EmitPopEAX;
Begin
  BinEmitByte($58);
End;

Procedure EmitMovEAXImm32(Val : LongInt);
Begin
  BinEmitByte($B8);
  BinEmitDWord(Val);
End;

Procedure EmitMovEAXMem32(Addr : LongInt);
Begin
  BinEmitByte($A1);
  BinEmitDWord(Addr);
End;

Procedure EmitMovMem32EAX(Addr : LongInt);
Begin
  BinEmitByte($A3);
  BinEmitDWord(Addr);
End;

Procedure EmitMovECXEAX;
Begin
  BinEmitByte($89);
  BinEmitByte($C1);
End;

Procedure EmitCallIAT(Kind : Integer);
Begin
  BinEmitByte($FF);
  BinEmitByte($15);
  AddFixup(Kind, 0);
  BinEmitDWord(0);
End;

Procedure EmitJmp(Target : String);
Var Li : Integer;
Begin
  Li := FindLabel(Target);
  BinEmitByte($E9);
  AddFixup(FIX_CODE_REL, Li);
  BinEmitDWord(0);
End;

Procedure EmitJZ(Target : String);
Var Li : Integer;
Begin
  Li := FindLabel(Target);
  BinEmitByte($0F);
  BinEmitByte($84);
  AddFixup(FIX_CODE_REL, Li);
  BinEmitDWord(0);
End;

Procedure EmitJNZ(Target : String);
Var Li : Integer;
Begin
  Li := FindLabel(Target);
  BinEmitByte($0F);
  BinEmitByte($85);
  AddFixup(FIX_CODE_REL, Li);
  BinEmitDWord(0);
End;

Procedure EmitTestEAX;
Begin
  BinEmitByte($85);
  BinEmitByte($C0);
End;

Procedure EmitCmpEAXECX;
Begin
  BinEmitByte($39);
  BinEmitByte($C8);
End;

Procedure EmitAddEAXECX;
Begin
  BinEmitByte($01);
  BinEmitByte($C8);
End;

Procedure EmitSubEAXECX;
Begin
  BinEmitByte($29);
  BinEmitByte($C8);
End;

Procedure EmitImulEAXECX;
Begin
  BinEmitByte($0F);
  BinEmitByte($AF);
  BinEmitByte($C1);
End;

Procedure EmitCdq;
Begin
  BinEmitByte($99);
End;

Procedure EmitIdivECX;
Begin
  BinEmitByte($F7);
  BinEmitByte($F9);
End;

Procedure EmitMovEAXEDX;
Begin
  BinEmitByte($89);
  BinEmitByte($D0);
End;

Procedure EmitIncMem32(Addr : LongInt);
Begin
  BinEmitByte($FF);
  BinEmitByte($05);
  BinEmitDWord(Addr);
End;

Procedure EmitDecMem32(Addr : LongInt);
Begin
  BinEmitByte($FF);
  BinEmitByte($0D);
  BinEmitDWord(Addr);
End;

Procedure EmitAddMem32Imm(Addr : LongInt; Val : LongInt);
Begin
  BinEmitByte($83);
  BinEmitByte($05);
  BinEmitDWord(Addr);
  BinEmitByte(Val And $FF);
End;

Procedure EmitSubMem32Imm(Addr : LongInt; Val : LongInt);
Begin
  BinEmitByte($83);
  BinEmitByte($2D);
  BinEmitDWord(Addr);
  BinEmitByte(Val And $FF);
End;

Procedure EmitCmpMem32Imm(Addr : LongInt; Val : LongInt);
Begin
  If (Val >= -128) And (Val <= 127) Then
  Begin
    BinEmitByte($83);
    BinEmitByte($3D);
    BinEmitDWord(Addr);
    BinEmitByte(Val And $FF);
  End
  Else
  Begin
    BinEmitByte($81);
    BinEmitByte($3D);
    BinEmitDWord(Addr);
    BinEmitDWord(Val);
  End;
End;

Procedure EmitCmpEAXImm(Val : LongInt);
Begin
  If (Val >= -128) And (Val <= 127) Then
  Begin
    BinEmitByte($83);
    BinEmitByte($F8);
    BinEmitByte(Val And $FF);
  End
  Else
  Begin
    BinEmitByte($3D);
    BinEmitDWord(Val);
  End;
End;

Procedure EmitJG(Target : String);
Var Li : Integer;
Begin
  Li := FindLabel(Target);
  BinEmitByte($0F);
  BinEmitByte($8F);
  AddFixup(FIX_CODE_REL, Li);
  BinEmitDWord(0);
End;

Procedure EmitJLE(Target : String);
Var Li : Integer;
Begin
  Li := FindLabel(Target);
  BinEmitByte($0F);
  BinEmitByte($8E);
  AddFixup(FIX_CODE_REL, Li);
  BinEmitDWord(0);
End;

Procedure EmitSetE;
Begin
  BinEmitByte($0F);
  BinEmitByte($94);
  BinEmitByte($C0);
End;

Procedure EmitSetNE;
Begin
  BinEmitByte($0F);
  BinEmitByte($95);
  BinEmitByte($C0);
End;

Procedure EmitSetL;
Begin
  BinEmitByte($0F);
  BinEmitByte($9C);
  BinEmitByte($C0);
End;

Procedure EmitSetLE;
Begin
  BinEmitByte($0F);
  BinEmitByte($9E);
  BinEmitByte($C0);
End;

Procedure EmitSetG;
Begin
  BinEmitByte($0F);
  BinEmitByte($9F);
  BinEmitByte($C0);
End;

Procedure EmitSetGE;
Begin
  BinEmitByte($0F);
  BinEmitByte($9D);
  BinEmitByte($C0);
End;

Procedure EmitMovzxEAXAL;
Begin
  BinEmitByte($0F);
  BinEmitByte($B6);
  BinEmitByte($C0);
End;

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
End;

Procedure ExpectOp(Const Op : String);
Begin
  If (CurTok <> TOK_OP) Or (CurTokStr <> Op) Then
    ErrorAt(LexLineNo, LexColNo, 'Operateur "' + Op + '" attendu');
  LexNext;
End;

Function AcceptOp(Const Op : String) : Boolean;
Begin
  If (CurTok = TOK_OP) And (CurTokStr = Op) Then
  Begin
    LexNext;
    AcceptOp := True;
  End
  Else
    AcceptOp := False;
End;

Procedure GenExpression; Forward;

Procedure GenFactor;
Var Si, StrIdx : Integer;
Begin
  If CurTok = TOK_IDENT Then
  Begin
    Si := SymFind(CurTokStr);
    If Si > 0 Then
    Begin
      SymTab[Si].Used := True;
      EmitMovEAXMem32($400000 + $2000 + SymTab[Si].DataOffs);
      BinCodeLen := BinCodeLen - 4;
      AddFixup(FIX_VAR, Si);
      BinCodeLen := BinCodeLen + 4;
    End
    Else
      ErrorAt(LexLineNo, LexColNo, 'Variable inconnue: ' + CurTokStr);
    LexNext;
  End
  Else If CurTok = TOK_INT Then
  Begin
    EmitMovEAXImm32(CurTokNum);
    LexNext;
  End
  Else If (CurTok = TOK_KEYWORD) And (CurTokKw = KW_TRUE) Then
  Begin
    EmitMovEAXImm32(1);
    LexNext;
  End
  Else If (CurTok = TOK_KEYWORD) And (CurTokKw = KW_FALSE) Then
  Begin
    EmitMovEAXImm32(0);
    LexNext;
  End
  Else If (CurTok = TOK_OP) And (CurTokStr = '(') Then
  Begin
    LexNext;
    GenExpression;
    ExpectOp(')');
  End
  Else If (CurTok = TOK_OP) And (CurTokStr = '-') Then
  Begin
    LexNext;
    GenFactor;
    BinEmitByte($F7);
    BinEmitByte($D8);
  End
  Else
    ErrorAt(LexLineNo, LexColNo, 'Facteur attendu');
End;

Procedure GenTerm;
Var Op : String;
Begin
  GenFactor;
  While ((CurTok = TOK_OP) And ((CurTokStr = '*') Or (CurTokStr = '/'))) Or
        ((CurTok = TOK_KEYWORD) And ((CurTokKw = KW_DIV) Or (CurTokKw = KW_MOD))) Do
  Begin
    Op := CurTokStr;
    If CurTok = TOK_KEYWORD Then
    Begin
      If CurTokKw = KW_DIV Then
        Op := 'DIV'
      Else
        Op := 'MOD';
    End;
    LexNext;
    EmitPushEAX;
    GenFactor;
    EmitMovECXEAX;
    EmitPopEAX;
    If Op = '*' Then
      EmitImulEAXECX
    Else If Op = 'DIV' Then
    Begin
      EmitCdq;
      EmitIdivECX;
    End
    Else If Op = 'MOD' Then
    Begin
      EmitCdq;
      EmitIdivECX;
      EmitMovEAXEDX;
    End;
  End;
End;

Procedure GenSimpleExpression;
Var Op : String;
Begin
  GenTerm;
  While ((CurTok = TOK_OP) And ((CurTokStr = '+') Or (CurTokStr = '-'))) Do
  Begin
    Op := CurTokStr;
    LexNext;
    EmitPushEAX;
    GenTerm;
    EmitMovECXEAX;
    EmitPopEAX;
    If Op = '+' Then
      EmitAddEAXECX
    Else If Op = '-' Then
      EmitSubEAXECX;
  End;
End;

Procedure GenExpression;
Var Op : String;
Begin
  GenSimpleExpression;
  If (CurTok = TOK_OP) And ((CurTokStr = '=') Or (CurTokStr = '#') Or 
     (CurTokStr = '<') Or (CurTokStr = '>') Or (CurTokStr = '<=') Or (CurTokStr = '>=')) Then
  Begin
    Op := CurTokStr;
    LexNext;
    EmitPushEAX;
    GenSimpleExpression;
    EmitMovECXEAX;
    EmitPopEAX;
    EmitCmpEAXECX;
    If Op = '=' Then
      EmitSetE
    Else If Op = '#' Then
      EmitSetNE
    Else If Op = '<' Then
      EmitSetL
    Else If Op = '<=' Then
      EmitSetLE
    Else If Op = '>' Then
      EmitSetG
    Else If Op = '>=' Then
      EmitSetGE;
    EmitMovzxEAXAL;
  End;
End;

Procedure GenStatement; Forward;

Procedure GenStatSeq;
Begin
  GenStatement;
  While AcceptOp(';') Do
    GenStatement;
End;

Procedure GenOutString(Const S : String);
Var StrIdx : Integer;
Begin
  StrIdx := AddStringLiteral(S);
  EmitPushImm32(0);
  EmitPushImm32($400000 + $2000);
  BinCodeLen := BinCodeLen - 4;
  AddFixup(FIX_BYTES_WRITTEN, 0);
  BinCodeLen := BinCodeLen + 4;
  EmitPushImm32(Length(S));
  EmitPushImm32($400000 + $2000);
  BinCodeLen := BinCodeLen - 4;
  AddFixup(FIX_STRING, StrIdx);
  BinCodeLen := BinCodeLen + 4;
  EmitMovEAXMem32($400000 + $2000);
  BinCodeLen := BinCodeLen - 4;
  AddFixup(FIX_STDOUT, 0);
  BinCodeLen := BinCodeLen + 4;
  EmitPushEAX;
  EmitCallIAT(FIX_IAT_WRITE);
End;

Procedure GenOutLn;
Begin
  EmitPushImm32(0);
  EmitPushImm32($400000 + $2000);
  BinCodeLen := BinCodeLen - 4;
  AddFixup(FIX_BYTES_WRITTEN, 0);
  BinCodeLen := BinCodeLen + 4;
  EmitPushImm32(2);
  EmitPushImm32($400000 + $2000);
  BinCodeLen := BinCodeLen - 4;
  AddFixup(FIX_CRLF, 0);
  BinCodeLen := BinCodeLen + 4;
  EmitMovEAXMem32($400000 + $2000);
  BinCodeLen := BinCodeLen - 4;
  AddFixup(FIX_STDOUT, 0);
  BinCodeLen := BinCodeLen + 4;
  EmitPushEAX;
  EmitCallIAT(FIX_IAT_WRITE);
End;

Procedure GenOutInt;
Begin
  GenExpression;
  EmitPushEAX;
  BinEmitByte($E8);
  AddFixup(FIX_CODE_REL, FindLabel('_printint'));
  BinEmitDWord(0);
End;

Procedure GenOutCall;
Var Proc : String;
Begin
  Proc := CurTokStr;
  LexNext;
  If AcceptOp('.') Then
  Begin
    If CurTok = TOK_IDENT Then
    Begin
      Proc := Proc + '.' + CurTokStr;
      LexNext;
    End;
  End;
  If AcceptOp('(') Then
  Begin
    If (CurTok <> TOK_OP) Or (CurTokStr <> ')') Then
    Begin
      If Proc = 'Out.Int' Then
      Begin
        GenOutInt;
        If AcceptOp(',') Then
        Begin
          GenExpression;
        End;
      End
      Else
      Begin
        GenExpression;
        While AcceptOp(',') Do
          GenExpression;
      End;
    End;
    ExpectOp(')');
  End;
  If Proc = 'Out.String' Then
  Begin
  End
  Else If Proc = 'Out.Ln' Then
    GenOutLn
  Else If Proc = 'Out.Int' Then
  Begin
  End;
End;

Procedure GenStatement;
Var 
  VarName : String;
  Si : Integer;
  Lab1, Lab2, Lab3, Lab4 : String;
  LoopVar : String;
  LoopVarSi : Integer;
  HiVal : LongInt;
Begin
  If CurTok = TOK_IDENT Then
  Begin
    VarName := CurTokStr;
    Si := SymFind(VarName);
    LexNext;
    If AcceptOp(':=') Then
    Begin
      GenExpression;
      If Si > 0 Then
      Begin
        EmitMovMem32EAX($400000 + $2000 + SymTab[Si].DataOffs);
        BinCodeLen := BinCodeLen - 4;
        AddFixup(FIX_VAR, Si);
        BinCodeLen := BinCodeLen + 4;
      End;
    End
    Else If AcceptOp('.') Then
    Begin
      If (CurTok = TOK_IDENT) Then
      Begin
        VarName := VarName + '.' + CurTokStr;
        LexNext;
      End;
      If VarName = 'Out.String' Then
      Begin
        If AcceptOp('(') Then
        Begin
          If CurTok = TOK_STRING Then
          Begin
            GenOutString(CurTokStr);
            LexNext;
          End;
          ExpectOp(')');
        End;
      End
      Else If VarName = 'Out.Ln' Then
        GenOutLn
      Else If VarName = 'Out.Int' Then
      Begin
        If AcceptOp('(') Then
        Begin
          GenOutInt;
          If AcceptOp(',') Then
          Begin
            GenExpression;
          End;
          ExpectOp(')');
        End;
      End;
    End
    Else If AcceptOp('(') Then
    Begin
      If VarName = 'INC' Then
      Begin
        If CurTok = TOK_IDENT Then
        Begin
          Si := SymFind(CurTokStr);
          If Si > 0 Then
          Begin
            LexNext;
            If AcceptOp(',') Then
            Begin
              If CurTok = TOK_INT Then
              Begin
                EmitAddMem32Imm($400000 + $2000 + SymTab[Si].DataOffs, CurTokNum);
                AddFixup(FIX_VAR, Si);
                BinCodeLen := BinCodeLen - 6;
                BinEmitByte(0);
                BinEmitDWord(0);
                BinEmitByte(CurTokNum And $FF);
                LexNext;
              End;
            End
            Else
            Begin
              EmitIncMem32($400000 + $2000 + SymTab[Si].DataOffs);
              BinCodeLen := BinCodeLen - 4;
              AddFixup(FIX_VAR, Si);
              BinCodeLen := BinCodeLen + 4;
            End;
          End;
        End;
        ExpectOp(')');
      End
      Else If VarName = 'DEC' Then
      Begin
        If CurTok = TOK_IDENT Then
        Begin
          Si := SymFind(CurTokStr);
          If Si > 0 Then
          Begin
            LexNext;
            If AcceptOp(',') Then
            Begin
              If CurTok = TOK_INT Then
              Begin
                EmitSubMem32Imm($400000 + $2000 + SymTab[Si].DataOffs, CurTokNum);
                AddFixup(FIX_VAR, Si);
                BinCodeLen := BinCodeLen - 6;
                BinEmitByte(0);
                BinEmitDWord(0);
                BinEmitByte(CurTokNum And $FF);
                LexNext;
              End;
            End
            Else
            Begin
              EmitDecMem32($400000 + $2000 + SymTab[Si].DataOffs);
              BinCodeLen := BinCodeLen - 4;
              AddFixup(FIX_VAR, Si);
              BinCodeLen := BinCodeLen + 4;
            End;
          End;
        End;
        ExpectOp(')');
      End;
    End;
  End

  Else If (CurTok = TOK_KEYWORD) And (CurTokKw = KW_IF) Then
  Begin
    LexNext;
    GenExpression;
    Expect(KW_THEN);
    Lab1 := GenLabel;
    Lab2 := GenLabel;
    EmitTestEAX;
    EmitJZ(Lab1);
    GenStatSeq;
    While (CurTok = TOK_KEYWORD) And (CurTokKw = KW_ELSIF) Do
    Begin
      LexNext;
      EmitJmp(Lab2);
      DefineLabel(Lab1);
      GenExpression;
      Expect(KW_THEN);
      Lab1 := GenLabel;
      EmitTestEAX;
      EmitJZ(Lab1);
      GenStatSeq;
    End;
    If Accept(KW_ELSE) Then
    Begin
      EmitJmp(Lab2);
      DefineLabel(Lab1);
      GenStatSeq;
      Lab1 := Lab2;
    End;
    DefineLabel(Lab1);
    If Lab1 <> Lab2 Then
      DefineLabel(Lab2);
    Expect(KW_END);
  End

  Else If (CurTok = TOK_KEYWORD) And (CurTokKw = KW_WHILE) Then
  Begin
    LexNext;
    Lab1 := GenLabel;
    Lab2 := GenLabel;
    DefineLabel(Lab1);
    GenExpression;
    Expect(KW_DO);
    EmitTestEAX;
    EmitJZ(Lab2);
    GenStatSeq;
    EmitJmp(Lab1);
    DefineLabel(Lab2);
    Expect(KW_END);
  End

  Else If (CurTok = TOK_KEYWORD) And (CurTokKw = KW_REPEAT) Then
  Begin
    LexNext;
    Lab1 := GenLabel;
    DefineLabel(Lab1);
    GenStatSeq;
    Expect(KW_UNTIL);
    GenExpression;
    EmitTestEAX;
    EmitJZ(Lab1);
  End

  Else If (CurTok = TOK_KEYWORD) And (CurTokKw = KW_FOR) Then
  Begin
    LexNext;
    If CurTok = TOK_IDENT Then
    Begin
      LoopVar := CurTokStr;
      LoopVarSi := SymFind(LoopVar);
      LexNext;
      ExpectOp(':=');
      GenExpression;
      If LoopVarSi > 0 Then
      Begin
        EmitMovMem32EAX($400000 + $2000 + SymTab[LoopVarSi].DataOffs);
        BinCodeLen := BinCodeLen - 4;
        AddFixup(FIX_VAR, LoopVarSi);
        BinCodeLen := BinCodeLen + 4;
      End;
      Expect(KW_TO);
      If CurTok = TOK_INT Then
      Begin
        HiVal := CurTokNum;
        LexNext;
      End
      Else
        HiVal := 10;
      If Accept(KW_BY) Then
      Begin
        If CurTok = TOK_INT Then
          LexNext;
      End;
      Expect(KW_DO);
      Lab1 := GenLabel;
      Lab2 := GenLabel;
      DefineLabel(Lab1);
      If LoopVarSi > 0 Then
      Begin
        EmitMovEAXMem32($400000 + $2000 + SymTab[LoopVarSi].DataOffs);
        BinCodeLen := BinCodeLen - 4;
        AddFixup(FIX_VAR, LoopVarSi);
        BinCodeLen := BinCodeLen + 4;
      End;
      EmitCmpEAXImm(HiVal);
      EmitJG(Lab2);
      GenStatSeq;
      If LoopVarSi > 0 Then
      Begin
        EmitIncMem32($400000 + $2000 + SymTab[LoopVarSi].DataOffs);
        BinCodeLen := BinCodeLen - 4;
        AddFixup(FIX_VAR, LoopVarSi);
        BinCodeLen := BinCodeLen + 4;
      End;
      EmitJmp(Lab1);
      DefineLabel(Lab2);
      Expect(KW_END);
    End;
  End;
End;

Procedure GenPrintIntHelper;
Var
  LabZero, LabLoop, LabPos, LabNoMinus, LabWrite : String;
Begin
  DefineLabel('_printint');

  { Preserve callee-save registers used (ebx, esi, edi, ebp) }
  BinEmitByte($53);                        { push ebx }
  BinEmitByte($56);                        { push esi }
  BinEmitByte($57);                        { push edi }
  BinEmitByte($55);                        { push ebp }

  { eax = value from [esp + 20] (4 saved regs + ret addr) }
  BinEmitByte($8B); BinEmitByte($44); BinEmitByte($24); BinEmitByte($14);

  LabZero    := GenLabel;
  LabLoop    := GenLabel;
  LabPos     := GenLabel;
  LabNoMinus := GenLabel;
  LabWrite   := GenLabel;

  { if (eax == 0) goto LabZero }
  EmitTestEAX;
  EmitJZ(LabZero);

  { ebp := 0 (sign flag); if eax < 0 then neg eax; ebp := 1 }
  BinEmitByte($31); BinEmitByte($ED);      { xor ebp, ebp }
  EmitTestEAX;
  BinEmitByte($0F); BinEmitByte($89);      { jns rel32 to LabPos }
  AddFixup(FIX_CODE_REL, FindLabel(LabPos));
  BinEmitDWord(0);
  BinEmitByte($F7); BinEmitByte($D8);      { neg eax }
  BinEmitByte($BD); BinEmitDWord(1);       { mov ebp, 1 }
  DefineLabel(LabPos);

  { edi := IntBufAddr + 12 (write pointer, digits stored backwards) }
  BinEmitByte($BF);                        { mov edi, imm32 }
  AddFixup(FIX_INTBUF_END, 0);
  BinEmitDWord(0);

  { ebx := 10 }
  BinEmitByte($BB); BinEmitDWord(10);

  DefineLabel(LabLoop);
  BinEmitByte($31); BinEmitByte($D2);      { xor edx, edx }
  BinEmitByte($F7); BinEmitByte($F3);      { div ebx }
  BinEmitByte($80); BinEmitByte($C2); BinEmitByte($30);  { add dl, '0' }
  BinEmitByte($4F);                        { dec edi }
  BinEmitByte($88); BinEmitByte($17);      { mov [edi], dl }
  EmitTestEAX;
  EmitJNZ(LabLoop);

  { if ebp == 0 goto LabNoMinus ; else prepend '-' }
  BinEmitByte($85); BinEmitByte($ED);      { test ebp, ebp }
  EmitJZ(LabNoMinus);
  BinEmitByte($4F);                        { dec edi }
  BinEmitByte($C6); BinEmitByte($07); BinEmitByte($2D);  { mov byte [edi], '-' }
  DefineLabel(LabNoMinus);

  { esi := IntBufAddr + 12 ; esi -= edi  --> length }
  BinEmitByte($BE);                        { mov esi, imm32 }
  AddFixup(FIX_INTBUF_END, 0);
  BinEmitDWord(0);
  BinEmitByte($29); BinEmitByte($FE);      { sub esi, edi }
  EmitJmp(LabWrite);

  DefineLabel(LabZero);
  { edi := IntBufAddr ; byte [edi] := '0' ; esi := 1 }
  BinEmitByte($BF);                        { mov edi, imm32 }
  AddFixup(FIX_INTBUF, 0);
  BinEmitDWord(0);
  BinEmitByte($C6); BinEmitByte($07); BinEmitByte($30);  { mov byte [edi], '0' }
  BinEmitByte($BE); BinEmitDWord(1);       { mov esi, 1 }

  DefineLabel(LabWrite);
  { WriteFile(stdout, edi, esi, &bytes_written, NULL) }
  BinEmitByte($6A); BinEmitByte($00);      { push 0 (lpOverlapped) }

  BinEmitByte($68);                        { push imm32 bytes_written addr }
  AddFixup(FIX_BYTES_WRITTEN, 0);
  BinEmitDWord(0);

  BinEmitByte($56);                        { push esi (length) }
  BinEmitByte($57);                        { push edi (buffer) }

  { push dword [stdout_var] : FF 35 imm32 }
  BinEmitByte($FF); BinEmitByte($35);
  AddFixup(FIX_STDOUT, 0);
  BinEmitDWord(0);

  EmitCallIAT(FIX_IAT_WRITE);

  BinEmitByte($5D);                        { pop ebp }
  BinEmitByte($5F);                        { pop edi }
  BinEmitByte($5E);                        { pop esi }
  BinEmitByte($5B);                        { pop ebx }
  BinEmitByte($C2); BinEmitWord(4);        { ret 4 }
End;

Procedure ParseVarDecl;
Var
  VarNames : Array[1..32] of String;
  VarCount : Integer;
  I : Integer;
  TypeName : String;
  TypeIdx : Integer;
Begin
  While (CurTok = TOK_IDENT) Do
  Begin
    VarCount := 0;
    Inc(VarCount);
    VarNames[VarCount] := CurTokStr;
    LexNext;
    While AcceptOp(',') Do
    Begin
      If CurTok = TOK_IDENT Then
      Begin
        Inc(VarCount);
        VarNames[VarCount] := CurTokStr;
        LexNext;
      End;
    End;
    ExpectOp(':');
    If CurTok = TOK_IDENT Then
    Begin
      TypeName := StrUpper(CurTokStr);
      If TypeName = 'INTEGER' Then
        TypeIdx := 1
      Else If TypeName = 'BOOLEAN' Then
        TypeIdx := 2
      Else If TypeName = 'CHAR' Then
        TypeIdx := 3
      Else
        TypeIdx := 1;
      LexNext;
    End;
    For I := 1 To VarCount Do
      SymEnter(VarNames[I], TypeIdx);
    ExpectOp(';');
  End;
End;

Procedure ParseImportList;
Begin
  Expect(KW_IMPORT);
  While CurTok = TOK_IDENT Do
  Begin
    LexNext;
    If AcceptOp(',') Then
      Continue
    Else
      Break;
  End;
  ExpectOp(';');
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
  ExpectOp(';');
  If (CurTok = TOK_KEYWORD) And (CurTokKw = KW_IMPORT) Then
    ParseImportList;
  While (CurTok = TOK_KEYWORD) Do
  Begin
    If CurTokKw = KW_CONST Then
    Begin
      LexNext;
      While (CurTok = TOK_IDENT) Do
      Begin
        LexNext;
        While (CurTok <> TOK_EOF) And ((CurTok <> TOK_OP) Or (CurTokStr <> ';')) Do
          LexNext;
        If AcceptOp(';') Then
          Continue;
      End;
    End
    Else If CurTokKw = KW_TYPE Then
    Begin
      LexNext;
      While (CurTok = TOK_IDENT) Do
      Begin
        LexNext;
        While (CurTok <> TOK_EOF) And ((CurTok <> TOK_OP) Or (CurTokStr <> ';')) Do
          LexNext;
        If AcceptOp(';') Then
          Continue;
      End;
    End
    Else If CurTokKw = KW_VAR Then
    Begin
      LexNext;
      ParseVarDecl;
    End
    Else If CurTokKw = KW_PROCEDURE Then
    Begin
      LexNext;
      While (CurTok <> TOK_EOF) And ((CurTok <> TOK_KEYWORD) Or (CurTokKw <> KW_END)) Do
        LexNext;
      If (CurTok = TOK_KEYWORD) And (CurTokKw = KW_END) Then
        LexNext;
      If CurTok = TOK_IDENT Then
        LexNext;
      If AcceptOp(';') Then
        Continue;
    End
    Else
      Break;
  End;
  If Accept(KW_BEGIN) Then
    GenStatSeq;
  Expect(KW_END);
  If CurTok = TOK_IDENT Then
    LexNext;
  ExpectOp('.');
End;

Procedure EmitCodePrologue;
Begin
  EmitPushImm32(-11);
  EmitCallIAT(FIX_IAT_GETSTD);
  EmitMovMem32EAX($400000 + $2000);
  BinCodeLen := BinCodeLen - 4;
  AddFixup(FIX_STDOUT, 0);
  BinCodeLen := BinCodeLen + 4;
End;

Procedure EmitCodeEpilogue;
Begin
  EmitPushImm32(0);
  EmitCallIAT(FIX_IAT_EXIT);
End;

Procedure ResolveFixups(TextRVA, DataRVA, IdataRVA : LongInt);
Var
  I, Si, Li : Integer;
  TargetAddr, CalleeAddr, RelAddr : LongInt;
  ImageBase : LongInt;
  StdoutAddr, CRLFAddr, IntBufAddr, BytesWrittenAddr : LongInt;
  StrAddr : LongInt;
  IATGetStd, IATWrite, IATExit : LongInt;
  VarBase, TotalStr : LongInt;
Begin
  ImageBase := $400000;
  StdoutAddr := ImageBase + DataRVA;
  BytesWrittenAddr := StdoutAddr + 4;
  IntBufAddr := BytesWrittenAddr + 4;
  CRLFAddr := IntBufAddr + 12;

  TotalStr := 0;
  For Li := 1 To StringCount Do
    TotalStr := TotalStr + Length(StringPool[Li]);
  VarBase := 22 + TotalStr;
  While (VarBase Mod 4) <> 0 Do
    VarBase := VarBase + 1;
  
  IATGetStd := ImageBase + IdataRVA + 60;
  IATWrite := IATGetStd + 4;
  IATExit := IATWrite + 4;
  
  For I := 1 To FixupCount Do
  Begin
    Case Fixups[I].Kind Of
      FIX_IAT_GETSTD:
        Begin
          TargetAddr := IATGetStd;
          BinCode[Fixups[I].Offset] := TargetAddr And $FF;
          BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
          BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
          BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
        End;
      FIX_IAT_WRITE:
        Begin
          TargetAddr := IATWrite;
          BinCode[Fixups[I].Offset] := TargetAddr And $FF;
          BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
          BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
          BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
        End;
      FIX_IAT_EXIT:
        Begin
          TargetAddr := IATExit;
          BinCode[Fixups[I].Offset] := TargetAddr And $FF;
          BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
          BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
          BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
        End;
      FIX_STRING:
        Begin
          Si := Fixups[I].Target;
          StrAddr := CRLFAddr + 2;
          If Si > 0 Then
          Begin
            For Li := 1 To Si-1 Do
              StrAddr := StrAddr + Length(StringPool[Li]);
            TargetAddr := StrAddr;
            BinCode[Fixups[I].Offset] := TargetAddr And $FF;
            BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
            BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
            BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
          End;
        End;
      FIX_VAR:
        Begin
          Si := Fixups[I].Target;
          If (Si > 0) And (Si <= SymCount) Then
          Begin
            TargetAddr := ImageBase + DataRVA + VarBase + SymTab[Si].DataOffs;
            BinCode[Fixups[I].Offset] := TargetAddr And $FF;
            BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
            BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
            BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
          End;
        End;
      FIX_CODE_REL:
        Begin
          Li := Fixups[I].Target;
          If (Li > 0) And (Li <= LabelCount) Then
          Begin
            If Labels[Li].Defined Then
            Begin
              CalleeAddr := ImageBase + TextRVA + Labels[Li].Offset;
              RelAddr := CalleeAddr - (ImageBase + TextRVA + Fixups[I].Offset + 4);
              BinCode[Fixups[I].Offset] := RelAddr And $FF;
              BinCode[Fixups[I].Offset+1] := (RelAddr Shr 8) And $FF;
              BinCode[Fixups[I].Offset+2] := (RelAddr Shr 16) And $FF;
              BinCode[Fixups[I].Offset+3] := (RelAddr Shr 24) And $FF;
            End;
          End;
        End;
      FIX_INTBUF:
        Begin
          TargetAddr := IntBufAddr;
          BinCode[Fixups[I].Offset] := TargetAddr And $FF;
          BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
          BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
          BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
        End;
      FIX_BYTES_WRITTEN:
        Begin
          TargetAddr := BytesWrittenAddr;
          BinCode[Fixups[I].Offset] := TargetAddr And $FF;
          BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
          BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
          BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
        End;
      FIX_STDOUT:
        Begin
          TargetAddr := StdoutAddr;
          BinCode[Fixups[I].Offset] := TargetAddr And $FF;
          BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
          BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
          BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
        End;
      FIX_CRLF:
        Begin
          TargetAddr := CRLFAddr;
          BinCode[Fixups[I].Offset] := TargetAddr And $FF;
          BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
          BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
          BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
        End;
      FIX_INTBUF_END:
        Begin
          TargetAddr := IntBufAddr + 12;
          BinCode[Fixups[I].Offset] := TargetAddr And $FF;
          BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
          BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
          BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
        End;
    End;
  End;
End;

Procedure BuildDataSection;
Var I, J : Integer;
Begin
  BinDataLen := 0;
  
  For I := 1 To 4 Do
  Begin
    BinData[BinDataLen] := 0;
    Inc(BinDataLen);
  End;
  
  For I := 1 To 4 Do
  Begin
    BinData[BinDataLen] := 0;
    Inc(BinDataLen);
  End;
  
  For I := 1 To 12 Do
  Begin
    BinData[BinDataLen] := Ord(' ');
    Inc(BinDataLen);
  End;
  
  BinData[BinDataLen] := $0D;
  Inc(BinDataLen);
  BinData[BinDataLen] := $0A;
  Inc(BinDataLen);
  
  For I := 1 To StringCount Do
  Begin
    For J := 1 To Length(StringPool[I]) Do
    Begin
      BinData[BinDataLen] := Ord(StringPool[I][J]);
      Inc(BinDataLen);
    End;
  End;
  
  While (BinDataLen Mod 4) <> 0 Do
  Begin
    BinData[BinDataLen] := 0;
    Inc(BinDataLen);
  End;
  
  For I := 1 To SymCount Do
  Begin
    For J := 1 To TypeByteSize(SymTab[I].TypeIdx) Do
    Begin
      BinData[BinDataLen] := 0;
      Inc(BinDataLen);
    End;
  End;
  
  While (BinDataLen Mod 512) <> 0 Do
  Begin
    BinData[BinDataLen] := 0;
    Inc(BinDataLen);
  End;
End;

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

  TextRVA := $1000;
  DataRVA := $2000;
  IdataRVA := $3000;

  HdrSize := 1024;
  TextFileOfs := HdrSize;
  
  While (BinCodeLen Mod 512) <> 0 Do
    BinEmitByte($90);
  
  TextSize := BinCodeLen;
  If TextSize < 512 Then
    TextSize := 512;
  
  DataFileOfs := TextFileOfs + TextSize;
  DataSize := BinDataLen;
  If DataSize < 512 Then
    DataSize := 512;
  
  IdataFileOfs := DataFileOfs + DataSize;
  IdataSize := 512;
  
  ImageSize := $4000;
  EntryRVA := $1000;

  ResolveFixups(TextRVA, DataRVA, IdataRVA);

  FillChar(IdataBuf, SizeOf(IdataBuf), 0);
  
  IdataBuf[0] := ($3000 + 40) And $FF;
  IdataBuf[1] := (($3000 + 40) Shr 8) And $FF;
  IdataBuf[2] := (($3000 + 40) Shr 16) And $FF;
  IdataBuf[3] := (($3000 + 40) Shr 24) And $FF;
  
  IdataBuf[12] := ($3000 + 100) And $FF;
  IdataBuf[13] := (($3000 + 100) Shr 8) And $FF;
  IdataBuf[14] := (($3000 + 100) Shr 16) And $FF;
  IdataBuf[15] := (($3000 + 100) Shr 24) And $FF;
  
  IdataBuf[16] := ($3000 + 60) And $FF;
  IdataBuf[17] := (($3000 + 60) Shr 8) And $FF;
  IdataBuf[18] := (($3000 + 60) Shr 16) And $FF;
  IdataBuf[19] := (($3000 + 60) Shr 24) And $FF;
  
  IdataBuf[40] := ($3000 + 120) And $FF;
  IdataBuf[41] := (($3000 + 120) Shr 8) And $FF;
  IdataBuf[42] := (($3000 + 120) Shr 16) And $FF;
  IdataBuf[43] := (($3000 + 120) Shr 24) And $FF;
  
  IdataBuf[44] := ($3000 + 136) And $FF;
  IdataBuf[45] := (($3000 + 136) Shr 8) And $FF;
  IdataBuf[46] := (($3000 + 136) Shr 16) And $FF;
  IdataBuf[47] := (($3000 + 136) Shr 24) And $FF;
  
  IdataBuf[48] := ($3000 + 150) And $FF;
  IdataBuf[49] := (($3000 + 150) Shr 8) And $FF;
  IdataBuf[50] := (($3000 + 150) Shr 16) And $FF;
  IdataBuf[51] := (($3000 + 150) Shr 24) And $FF;
  
  IdataBuf[60] := ($3000 + 120) And $FF;
  IdataBuf[61] := (($3000 + 120) Shr 8) And $FF;
  IdataBuf[62] := (($3000 + 120) Shr 16) And $FF;
  IdataBuf[63] := (($3000 + 120) Shr 24) And $FF;
  
  IdataBuf[64] := ($3000 + 136) And $FF;
  IdataBuf[65] := (($3000 + 136) Shr 8) And $FF;
  IdataBuf[66] := (($3000 + 136) Shr 16) And $FF;
  IdataBuf[67] := (($3000 + 136) Shr 24) And $FF;
  
  IdataBuf[68] := ($3000 + 150) And $FF;
  IdataBuf[69] := (($3000 + 150) Shr 8) And $FF;
  IdataBuf[70] := (($3000 + 150) Shr 16) And $FF;
  IdataBuf[71] := (($3000 + 150) Shr 24) And $FF;
  
  Move('KERNEL32.DLL'#0, IdataBuf[100], 13);
  IdataBuf[120] := 0;
  IdataBuf[121] := 0;
  Move('GetStdHandle'#0, IdataBuf[122], 13);
  IdataBuf[136] := 0;
  IdataBuf[137] := 0;
  Move('WriteFile'#0, IdataBuf[138], 10);
  IdataBuf[150] := 0;
  IdataBuf[151] := 0;
  Move('ExitProcess'#0, IdataBuf[152], 12);

  WriteBinByte(F, Ord('M'));
  WriteBinByte(F, Ord('Z'));
  For I := 1 To 58 Do
    WriteBinByte(F, 0);
  WriteBinDWord(F, $40);

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
  WriteBinDWord(F, 0);         { LoaderFlags }
  WriteBinDWord(F, 16);        { NumberOfRvaAndSizes }

  WriteBinDWord(F, 0);         { Export Table RVA }
  WriteBinDWord(F, 0);         { Export Table Size }
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

  BlockWrite(F, BinCode, TextSize);
  BlockWrite(F, BinData, DataSize);
  BlockWrite(F, IdataBuf, IdataSize);

  Close(F);
  If Opts.Verbose Then
  Begin
    WriteLn('OBERCW32: fichier EXE genere: ', ExeFile);
    WriteLn('OBERCW32: .text = ', TextSize, ' octets');
    WriteLn('OBERCW32: .data = ', DataSize, ' octets');
    WriteLn('OBERCW32: .idata = ', IdataSize, ' octets');
  End;
End;

Procedure PrintUsage;
Begin
  WriteLn('OBERCW32 version ', OBERCW32_VERSION);
  WriteLn('Usage: OBERCW32 <source.obn> [options]');
  WriteLn('Options:');
  WriteLn('  -o <fichier>  : specifier le nom du fichier de sortie');
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
    Opts.OutFile := Base + '.exe';
  End;

  AsmName := ChangeExtension(Opts.SrcFile, '.asm');
End;

Procedure InitTables;
Var Ti : Integer;
Begin
  SymCount := 0;
  TypeCount := 0;
  ConstCount := 0;
  StringCount := 0;
  FixupCount := 0;
  LabelCount := 0;
  LabelSeq := 0;
  ErrorCount := 0;
  BinCodeLen := 0;
  BinDataLen := 0;
  DataOffset := 0;

  Ti := TypeNew(TYK_INTEGER, 4);
  Ti := TypeNew(TYK_BOOLEAN, 1);
  Ti := TypeNew(TYK_CHAR, 1);
End;

Begin
  ParseArgs;
  InitTables;
  LexOpen(Opts.SrcFile);
  
  EmitCodePrologue;
  ParseModule;
  EmitCodeEpilogue;
  GenPrintIntHelper;
  
  LexClose;

  If ErrorCount > 0 Then
  Begin
    WriteLn('OBERCW32: ', ErrorCount, ' erreur(s), compilation abandonnee');
    Halt(1);
  End;

  BuildDataSection;
  BinWriteExe;

  If Opts.Verbose Then
  Begin
    WriteLn('OBERCW32 v', OBERCW32_VERSION, ': compilation OK (', ErrorCount, ' erreur(s))');
  End;
End.
