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
  KW_ARRAY     = 29;
  KW_CASE      = 30;
  KW_EXIT      = 31;
  KW_IN        = 32;
  KW_LOOP      = 33;
  KW_OF        = 34;
  KW_POINTER   = 35;
  KW_RECORD    = 36;
  KW_WITH      = 37;

  TYK_INTEGER   = 1;
  TYK_BOOLEAN   = 2;
  TYK_CHAR      = 3;
  TYK_ARRCHAR   = 4;   { ARRAY N OF CHAR : taille stockee dans SymTab.ArrSize }
  TYK_REAL      = 5;   { REAL IEEE 754 simple precision (4 octets) }

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
  FIX_IAT_SLEEP    = 12;
  FIX_IAT_GETTICK  = 13;
  FIX_IAT_GETCMD   = 14;
  FIX_STDERR       = 15;
  FIX_RNDSEED      = 16;
  FIX_HEXBUF       = 17;
  FIX_HEXBUF_END   = 18;
  FIX_IAT_READ     = 19;
  FIX_STDIN        = 20;
  FIX_INBUF        = 21;     { tampon de lecture ligne (256 octets) }
  FIX_INLEN        = 22;     { zone INTEGER "bytes read" }
  FIX_INDONE       = 23;     { zone INTEGER booleen (1 = derniere lecture OK) }
  FIX_REAL_CONST   = 24;     { litteral REAL (4 octets IEEE 754 simple) }
  FIX_REAL_TMP     = 25;     { zone temporaire REAL (4 octets) pour helpers }
  FIX_FPCW_TRUNC   = 26;     { mot de controle x87 mode troncature }
  FIX_FPCW_SAVE    = 27;     { zone de sauvegarde du mot de controle courant }

  { Palier 4 : imports Win32 supplementaires. }
  FIX_IAT_CREATEFILE = 28;   { KERNEL32!CreateFileA }
  FIX_IAT_CLOSEHANDLE= 29;   { KERNEL32!CloseHandle }
  FIX_IAT_SETFILEPTR = 30;   { KERNEL32!SetFilePointer }
  FIX_IAT_GETPROCHEAP= 31;   { KERNEL32!GetProcessHeap }
  FIX_IAT_HEAPALLOC  = 32;   { KERNEL32!HeapAlloc }
  FIX_IAT_HEAPFREE   = 33;   { KERNEL32!HeapFree }
  FIX_IAT_LOADLIB    = 34;   { KERNEL32!LoadLibraryA }
  FIX_IAT_GETPROC    = 35;   { KERNEL32!GetProcAddress }
  FIX_IAT_FREELIB    = 36;   { KERNEL32!FreeLibrary }

  { Palier 5 : imports Win32 fibers (coroutines). }
  FIX_IAT_CVTFIBER   = 37;   { KERNEL32!ConvertThreadToFiber }
  FIX_IAT_CREATEFIBER= 38;   { KERNEL32!CreateFiber }
  FIX_IAT_SWITCHFIBER= 39;   { KERNEL32!SwitchToFiber }
  FIX_IAT_DELETEFIBER= 40;   { KERNEL32!DeleteFiber }

  { Adresse absolue d'un label de code (par opposition a FIX_CODE_REL qui
    calcule un deplacement PC-relatif pour les instructions CALL/Jxx).
    Utilise par Coroutines.Body pour exposer un pointeur d'entree. }
  FIX_CODE_ABS       = 41;

  { Nombre total d'imports Win32 reconnus par le generateur .idata. }
  IMPORT_COUNT       = 20;

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
    ArrSize  : Integer;   { nombre d'octets reserves pour ARRAY OF CHAR,
                            0 pour les autres types }
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
  CurTokReal  : LongInt;   { bits IEEE 754 simple precision du dernier TOK_REAL }
  CurTokKw    : Integer;

  SymTab      : Array[1..MAX_SYM] of TSymEntry;
  SymCount    : Integer;

  TypeTab     : Array[1..MAX_TYPE] of TTypeEntry;
  TypeCount   : Integer;

  ConstTab    : Array[1..MAX_CONST] of TSymEntry;
  ConstCount  : Integer;

  StringPool  : Array[1..256] of String;
  StringCount : Integer;

  { Pool de litteraux REAL : chaque entree = 4 octets IEEE 754 simple. }
  RealPool    : Array[1..256] of LongInt;
  RealCount   : Integer;

  { Palier 4 : table des imports Win32 (KERNEL32.DLL).  Chaque entree a un
    nom ASCII et un fixup kind.  Les offsets dans .idata (IAT et Hint/Name)
    sont calcules par BuildIdataSection, stockes ici et lus par ResolveFixups. }
  ImportNames    : Array[1..IMPORT_COUNT] of String[32];
  ImportFixKinds : Array[1..IMPORT_COUNT] of Integer;
  ImportIATAddr  : Array[1..IMPORT_COUNT] of LongInt;  { adresse absolue IAT }

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

  { Pile d'etiquettes de sortie pour LOOP...EXIT }
  ExitLabels    : Array[1..32] of String;
  ExitLabelTop  : Integer;

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

{ Convertit une chaine de type "3.14", "1.5E-2", "0.5E2" en bits IEEE 754
  simple precision.  La chaine a deja ete validee par le lexeur. }
Function LexParseReal(Const S : String) : LongInt;
Var
  Sng  : Single;
  Bits : LongInt;
  Code : Integer;
Begin
  Val(S, Sng, Code);
  If Code <> 0 Then
    Sng := 0.0;
  Move(Sng, Bits, 4);
  LexParseReal := Bits;
End;

{ Ajoute un litteral REAL (bits IEEE 754) au pool et retourne son index
  (1-base).  Les doublons sont fusionnes.  Retourne 0 en cas de saturation. }
Function AddRealLiteral(Bits : LongInt) : Integer;
Var I : Integer;
Begin
  For I := 1 To RealCount Do
    If RealPool[I] = Bits Then
    Begin
      AddRealLiteral := I;
      Exit;
    End;
  If RealCount >= 256 Then
  Begin
    ErrorMsg('Pool de litteraux REAL plein');
    AddRealLiteral := 0;
    Exit;
  End;
  Inc(RealCount);
  RealPool[RealCount] := Bits;
  AddRealLiteral := RealCount;
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
  Else If U = 'ARRAY'     Then LexIsKeyword := KW_ARRAY
  Else If U = 'CASE'      Then LexIsKeyword := KW_CASE
  Else If U = 'EXIT'      Then LexIsKeyword := KW_EXIT
  Else If U = 'IN'        Then LexIsKeyword := KW_IN
  Else If U = 'LOOP'      Then LexIsKeyword := KW_LOOP
  Else If U = 'OF'        Then LexIsKeyword := KW_OF
  Else If U = 'POINTER'   Then LexIsKeyword := KW_POINTER
  Else If U = 'RECORD'    Then LexIsKeyword := KW_RECORD
  Else If U = 'WITH'      Then LexIsKeyword := KW_WITH
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
      { Oberon standard : "IN" est un mot-cle seulement en majuscules.
        "In" (casse mixte) doit rester un identificateur pour permettre
        le module Oberon standard du meme nom. }
      If (K = KW_IN) And (Tk <> 'IN') Then
        K := 0;
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
      { Detection d'un litteral REAL :
          - Partie decimale : '.' suivi d'au moins un chiffre ('.' seul ou
            '..' sont rejetes pour ne pas consommer le sous-intervalle).
          - Exposant optionnel : 'E'['+'|'-']chiffres. }
      If (LexCurChar = '.') And (LexPeekChar(1) In ['0'..'9']) Then
      Begin
        Tk := Tk + '.';
        LexAdvance;
        While LexCurChar In ['0'..'9'] Do
        Begin
          Tk := Tk + LexCurChar;
          LexAdvance;
        End;
        If (LexCurChar = 'E') Or (LexCurChar = 'e') Then
        Begin
          Tk := Tk + 'E';
          LexAdvance;
          If (LexCurChar = '+') Or (LexCurChar = '-') Then
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
        CurTokReal := LexParseReal(Tk);
        Exit;
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
    Else If Ch In ['(', ')', '[', ']', '{', '}', ',', ';', ':', '.', '=', '#', '<', '>', '+', '-', '*', '/', '&', '~', '|'] Then
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
  SymTab[SymCount].ArrSize := 0;
  Inc(DataOffset, TypeByteSize(TypeIdx));
  SymEnter := SymCount;
End;

{ Enregistre un ARRAY OF CHAR de taille fixe (N octets, alignes sur 4). }
Function SymEnterArr(Const Name : TString; N : Integer) : Integer;
Var Aligned : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    ErrorMsg('Table des symboles pleine');
    SymEnterArr := 0;
    Exit;
  End;
  If N < 1 Then N := 1;
  Aligned := N;
  While (Aligned Mod 4) <> 0 Do
    Inc(Aligned);
  Inc(SymCount);
  SymTab[SymCount].Name := Name;
  SymTab[SymCount].TypeIdx := TYK_ARRCHAR;
  SymTab[SymCount].DataOffs := DataOffset;
  SymTab[SymCount].Used := False;
  SymTab[SymCount].ArrSize := N;
  Inc(DataOffset, Aligned);
  SymEnterArr := SymCount;
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

{ --------------------- Palier 3 : emissions x87 FPU ------------------- }

{ fld dword [addr]  -->  D9 05 <addr32> }
Procedure EmitFLD_Real_At(FixKind, Target : Integer);
Begin
  BinEmitByte($D9); BinEmitByte($05);
  AddFixup(FixKind, Target);
  BinEmitDWord(0);
End;

{ fstp dword [addr]  -->  D9 1D <addr32> }
Procedure EmitFSTP_Real_At(FixKind, Target : Integer);
Begin
  BinEmitByte($D9); BinEmitByte($1D);
  AddFixup(FixKind, Target);
  BinEmitDWord(0);
End;

{ fild dword [addr]  -->  DB 05 <addr32> }
Procedure EmitFILD_At(FixKind, Target : Integer);
Begin
  BinEmitByte($DB); BinEmitByte($05);
  AddFixup(FixKind, Target);
  BinEmitDWord(0);
End;

{ fistp dword [addr]  -->  DB 1D <addr32> }
Procedure EmitFISTP_At(FixKind, Target : Integer);
Begin
  BinEmitByte($DB); BinEmitByte($1D);
  AddFixup(FixKind, Target);
  BinEmitDWord(0);
End;

{ fnstcw word [addr]  -->  D9 3D <addr32> }
Procedure EmitFNSTCW_At(FixKind, Target : Integer);
Begin
  BinEmitByte($D9); BinEmitByte($3D);
  AddFixup(FixKind, Target);
  BinEmitDWord(0);
End;

{ fldcw word [addr]  -->  D9 2D <addr32> }
Procedure EmitFLDCW_At(FixKind, Target : Integer);
Begin
  BinEmitByte($D9); BinEmitByte($2D);
  AddFixup(FixKind, Target);
  BinEmitDWord(0);
End;

Procedure EmitFADDP;   Begin BinEmitByte($DE); BinEmitByte($C1); End;
Procedure EmitFSUBP;   Begin BinEmitByte($DE); BinEmitByte($E9); End;
Procedure EmitFMULP;   Begin BinEmitByte($DE); BinEmitByte($C9); End;
Procedure EmitFDIVP;   Begin BinEmitByte($DE); BinEmitByte($F9); End;
Procedure EmitFCHS;    Begin BinEmitByte($D9); BinEmitByte($E0); End;
Procedure EmitFABS;    Begin BinEmitByte($D9); BinEmitByte($E1); End;
Procedure EmitFSQRT;   Begin BinEmitByte($D9); BinEmitByte($FA); End;
Procedure EmitFSIN;    Begin BinEmitByte($D9); BinEmitByte($FE); End;
Procedure EmitFCOS;    Begin BinEmitByte($D9); BinEmitByte($FF); End;
Procedure EmitF2XM1;   Begin BinEmitByte($D9); BinEmitByte($F0); End;
Procedure EmitFYL2X;   Begin BinEmitByte($D9); BinEmitByte($F1); End;
Procedure EmitFPATAN;  Begin BinEmitByte($D9); BinEmitByte($F3); End;
Procedure EmitFSCALE;  Begin BinEmitByte($D9); BinEmitByte($FD); End;
Procedure EmitFRNDINT; Begin BinEmitByte($D9); BinEmitByte($FC); End;
Procedure EmitFXCH;    Begin BinEmitByte($D9); BinEmitByte($C9); End;
Procedure EmitFSTP_ST0;Begin BinEmitByte($DD); BinEmitByte($D8); End; { fstp st(0) : pop }
Procedure EmitFLD1;    Begin BinEmitByte($D9); BinEmitByte($E8); End;
Procedure EmitFLDZ;    Begin BinEmitByte($D9); BinEmitByte($EE); End;
Procedure EmitFLDPI;   Begin BinEmitByte($D9); BinEmitByte($EB); End;
Procedure EmitFLDL2E;  Begin BinEmitByte($D9); BinEmitByte($EA); End;
Procedure EmitFLDLN2;  Begin BinEmitByte($D9); BinEmitByte($ED); End;
Procedure EmitFLD_ST1; Begin BinEmitByte($D9); BinEmitByte($C1); End; { fld st(1) - duplique }
Procedure EmitFLD_ST0; Begin BinEmitByte($D9); BinEmitByte($C0); End; { fld st(0) - duplique }

{ fcomip st, st(1)  -->  DF F1  (compare + pop, positionne EFLAGS) }
Procedure EmitFCOMIP;  Begin BinEmitByte($DF); BinEmitByte($F1); End;


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

Procedure EmitMovEAXStackTop;
Begin
  { mov eax, dword ptr [esp]  -->  8B 04 24 }
  BinEmitByte($8B);
  BinEmitByte($04);
  BinEmitByte($24);
End;

Procedure EmitAddESP4;
Begin
  { add esp, 4  -->  83 C4 04 }
  BinEmitByte($83);
  BinEmitByte($C4);
  BinEmitByte($04);
End;

Procedure EmitJE(Target : String);
Var Li : Integer;
Begin
  Li := FindLabel(Target);
  BinEmitByte($0F);
  BinEmitByte($84);
  AddFixup(FIX_CODE_REL, Li);
  BinEmitDWord(0);
End;

Procedure EmitJL(Target : String);
Var Li : Integer;
Begin
  Li := FindLabel(Target);
  BinEmitByte($0F);
  BinEmitByte($8C);
  AddFixup(FIX_CODE_REL, Li);
  BinEmitDWord(0);
End;

Procedure EmitJGE(Target : String);
Var Li : Integer;
Begin
  Li := FindLabel(Target);
  BinEmitByte($0F);
  BinEmitByte($8D);
  AddFixup(FIX_CODE_REL, Li);
  BinEmitDWord(0);
End;

Procedure EmitJNE(Target : String);
Var Li : Integer;
Begin
  Li := FindLabel(Target);
  BinEmitByte($0F);
  BinEmitByte($85);
  AddFixup(FIX_CODE_REL, Li);
  BinEmitDWord(0);
End;

Procedure EmitNegEAX;
Begin
  { neg eax  -->  F7 D8 }
  BinEmitByte($F7);
  BinEmitByte($D8);
End;

Procedure EmitAndEAXImm(Val : LongInt);
Begin
  If (Val >= -128) And (Val <= 127) Then
  Begin
    { and eax, imm8  -->  83 E0 ii }
    BinEmitByte($83);
    BinEmitByte($E0);
    BinEmitByte(Val And $FF);
  End
  Else
  Begin
    { and eax, imm32  -->  25 ii ii ii ii }
    BinEmitByte($25);
    BinEmitDWord(Val);
  End;
End;

Procedure EmitShlEAXImm8(N : Integer);
Begin
  { shl eax, n  -->  C1 E0 nn }
  BinEmitByte($C1);
  BinEmitByte($E0);
  BinEmitByte(N And $FF);
End;

Procedure EmitSarEAXImm8(N : Integer);
Begin
  { sar eax, n  -->  C1 F8 nn }
  BinEmitByte($C1);
  BinEmitByte($F8);
  BinEmitByte(N And $FF);
End;

Procedure EmitSubEAXImm(Val : LongInt);
Begin
  If (Val >= -128) And (Val <= 127) Then
  Begin
    { sub eax, imm8  -->  83 E8 ii }
    BinEmitByte($83);
    BinEmitByte($E8);
    BinEmitByte(Val And $FF);
  End
  Else
  Begin
    { sub eax, imm32  -->  2D ii ii ii ii }
    BinEmitByte($2D);
    BinEmitDWord(Val);
  End;
End;

{ Charge l'adresse du symbole Si dans EAX : mov eax, imm32 (fixup FIX_VAR). }
Procedure EmitLoadAddrEAX(Si : Integer);
Begin
  If Si > 0 Then
    SymTab[Si].Used := True;
  BinEmitByte($B8);
  AddFixup(FIX_VAR, Si);
  BinEmitDWord(0);
End;

{ Charge l'adresse du symbole Si dans ECX : mov ecx, imm32 (fixup FIX_VAR). }
Procedure EmitLoadAddrECX(Si : Integer);
Begin
  If Si > 0 Then
    SymTab[Si].Used := True;
  BinEmitByte($B9);
  AddFixup(FIX_VAR, Si);
  BinEmitDWord(0);
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
Procedure GenFactor; Forward;

{ --- Helper Palier 4 : pousse sur la pile l'adresse d'un argument chaine.
      Accepte un litteral de chaine (stocke dans le StringPool, termine
      par un nul) ou un identificateur ARRAY OF CHAR (dont l'adresse est
      resolue par FIX_VAR).  ShFail est utilise dans le message d'erreur. --- }
Procedure PushStrArg(Const FnName : String);
Var
  Si, Idx : Integer;
Begin
  If CurTok = TOK_STRING Then
  Begin
    Idx := AddStringLiteral(CurTokStr);
    BinEmitByte($68);                   { push imm32 (addresse chaine litterale) }
    AddFixup(FIX_STRING, Idx);
    BinEmitDWord(0);
    LexNext;
  End
  Else If CurTok = TOK_IDENT Then
  Begin
    Si := SymFind(CurTokStr);
    If (Si > 0) And (SymTab[Si].TypeIdx = TYK_ARRCHAR) Then
    Begin
      SymTab[Si].Used := True;
      BinEmitByte($68);                 { push imm32 (adresse variable) }
      AddFixup(FIX_VAR, Si);
      BinEmitDWord(0);
      LexNext;
    End
    Else
    Begin
      ErrorAt(LexLineNo, LexColNo, FnName + ' : ARRAY OF CHAR ou litteral chaine attendu');
      EmitPushImm32(0);
      LexNext;
    End;
  End
  Else
  Begin
    ErrorAt(LexLineNo, LexColNo, FnName + ' : litteral chaine ou identificateur attendu');
    EmitPushImm32(0);
  End;
End;

{ --- Helper Palier 4 : genere l'appel CreateFileA pour Files.Open.
      Le mode est un litteral entier :
        0 : GENERIC_READ | OPEN_EXISTING  (lecture seule)
        1 : GENERIC_WRITE | CREATE_ALWAYS (ecriture, ecrase si existe)
        2 : GENERIC_WRITE | OPEN_ALWAYS + seek a la fin (ajout)
      Retourne le handle dans EAX. --- }
Procedure GenFilesOpen;
Var
  Si : Integer;
  NameKind : Integer;   { 0=litteral, 1=ARRCHAR ident }
  NameIdx  : Integer;
  ModeVal : LongInt;
  Access, Share, Disp : LongInt;
  IsAppend : Boolean;
Begin
  ExpectOp('(');
  NameKind := -1;
  NameIdx := 0;
  If CurTok = TOK_STRING Then
  Begin
    NameIdx := AddStringLiteral(CurTokStr);
    NameKind := 0;
    LexNext;
  End
  Else If CurTok = TOK_IDENT Then
  Begin
    Si := SymFind(CurTokStr);
    If (Si > 0) And (SymTab[Si].TypeIdx = TYK_ARRCHAR) Then
    Begin
      SymTab[Si].Used := True;
      NameIdx := Si;
      NameKind := 1;
    End
    Else
      ErrorAt(LexLineNo, LexColNo, 'Files.Open : ARRAY OF CHAR attendu');
    LexNext;
  End
  Else
    ErrorAt(LexLineNo, LexColNo, 'Files.Open : litteral ou ident attendu');
  ExpectOp(',');
  { Mode : litteral entier (0, 1, 2). }
  If CurTok = TOK_INT Then
  Begin
    ModeVal := CurTokNum;
    LexNext;
  End
  Else
  Begin
    ErrorAt(LexLineNo, LexColNo, 'Files.Open : mode = entier litteral 0, 1 ou 2 attendu');
    ModeVal := 0;
  End;
  Case ModeVal Of
    0: Begin
     Access := LongInt($80000000);
     Share := 1;
     Disp := 3;
     IsAppend := False;
    End;
    1: Begin
     Access := $40000000;
     Share := 0;
     Disp := 2;
     IsAppend := False;
    End;
    2: Begin
     Access := $40000000;
     Share := 0;
     Disp := 4;
     IsAppend := True;
    End;
  Else
    Begin
      ErrorAt(LexLineNo, LexColNo, 'Files.Open : mode invalide (0, 1 ou 2)');
      Access := LongInt($80000000);
      Share := 1; Disp := 3;
      IsAppend := False;
    End;
  End;
  ExpectOp(')');

  { Emission (stdcall, push right-to-left) :
      push 0             ; hTemplateFile
      push $80           ; FILE_ATTRIBUTE_NORMAL
      push Disp          ; dwCreationDisposition
      push 0             ; lpSecurityAttributes
      push Share         ; dwShareMode
      push Access        ; dwDesiredAccess
      push name_addr     ; lpFileName
      call [CreateFileA] }
  EmitPushImm32(0);
  EmitPushImm32($80);
  EmitPushImm32(Disp);
  EmitPushImm32(0);
  EmitPushImm32(Share);
  EmitPushImm32(Access);
  If NameKind = 0 Then
  Begin
    BinEmitByte($68);
    AddFixup(FIX_STRING, NameIdx);
    BinEmitDWord(0);
  End
  Else If NameKind = 1 Then
  Begin
    BinEmitByte($68);
    AddFixup(FIX_VAR, NameIdx);
    BinEmitDWord(0);
  End
  Else
    EmitPushImm32(0);
  EmitCallIAT(FIX_IAT_CREATEFILE);        { eax = handle, stack nettoyee }

  If IsAppend Then
  Begin
    { Apres l'open en ajout, positionner a la fin. }
    BinEmitByte($89); BinEmitByte($C3);   { mov ebx, eax }
    EmitPushImm32(2);                      { FILE_END }
    EmitPushImm32(0);                      { lpDistanceToMoveHigh = NULL }
    EmitPushImm32(0);                      { lDistanceToMove = 0 }
    BinEmitByte($53);                      { push ebx (hFile) }
    EmitCallIAT(FIX_IAT_SETFILEPTR);
    BinEmitByte($89); BinEmitByte($D8);   { mov eax, ebx (restaure handle) }
  End;
End;

{ --- Files.Read(h, buf, n) ou Files.Write(h, buf, n).  Retourne dans
      EAX le nombre d'octets lus / ecrits.  Pour Read, &nBytesRead est
      lu dans la zone BYTES_WRITTEN (reutilisee). --- }
Procedure GenFilesReadWrite(IsRead : Boolean);
Var
  Si : Integer;
Begin
  ExpectOp('(');
  GenExpression;                   { eax = h }
  BinEmitByte($89); BinEmitByte($C3); { mov ebx, eax (sauve handle) }
  ExpectOp(',');
  { Argument buf : ARRAY OF CHAR. }
  If CurTok = TOK_IDENT Then
  Begin
    Si := SymFind(CurTokStr);
    If (Si > 0) And (SymTab[Si].TypeIdx = TYK_ARRCHAR) Then
    Begin
      SymTab[Si].Used := True;
      BinEmitByte($BF);             { mov edi, imm32 (addr de buf) }
      AddFixup(FIX_VAR, Si);
      BinEmitDWord(0);
      LexNext;
    End
    Else
    Begin
      ErrorAt(LexLineNo, LexColNo, 'Files : 2e argument ARRAY OF CHAR attendu');
      BinEmitByte($BF); BinEmitDWord(0);
      LexNext;
    End;
  End
  Else
    ErrorAt(LexLineNo, LexColNo, 'Files : identificateur attendu');
  ExpectOp(',');
  GenExpression;                   { eax = n, buf reste dans edi }

  { Emission :
      push 0                       ; lpOverlapped
      push &bytes_written          ; lpNumberOfBytesRead
      push eax                     ; nNumberOfBytesToRead
      push edi                     ; lpBuffer
      push ebx                     ; hFile
      call [ReadFile|WriteFile] }
  EmitPushImm32(0);
  BinEmitByte($68);                { push imm32 &bytes_written }
  AddFixup(FIX_BYTES_WRITTEN, 0);
  BinEmitDWord(0);
  EmitPushEAX;
  BinEmitByte($57);                { push edi }
  BinEmitByte($53);                { push ebx }
  If IsRead Then
    EmitCallIAT(FIX_IAT_READ)
  Else
    EmitCallIAT(FIX_IAT_WRITE);
  { Apres appel : eax = BOOL success (ignore).  On recupere
    bytes_written dans eax.  Si success=0, on renvoie -1. }
  BinEmitByte($85); BinEmitByte($C0);   { test eax, eax }
  BinEmitByte($75); BinEmitByte($07);   { jnz +7 (vers ok) }
  BinEmitByte($B8); BinEmitDWord(-1);   { mov eax, -1 (erreur) }
  BinEmitByte($EB); BinEmitByte($06);   { jmp +6 (vers done) }
  { ok: mov eax, [bytes_written] }
  BinEmitByte($A1);
  AddFixup(FIX_BYTES_WRITTEN, 0);
  BinEmitDWord(0);
  ExpectOp(')');
End;

{ --- Files.Size(h) : retourne la taille du fichier via deux appels a
      SetFilePointer : position courante, puis fin, puis on restore.  A
      l'entree, EAX = handle. --- }
Procedure GenFilesSize;
Begin
  BinEmitByte($89); BinEmitByte($C3);    { mov ebx, eax (handle) }
  { Position courante. }
  EmitPushImm32(1);                       { FILE_CURRENT }
  EmitPushImm32(0);
  EmitPushImm32(0);
  BinEmitByte($53);                       { push ebx }
  EmitCallIAT(FIX_IAT_SETFILEPTR);        { eax = cur }
  { Sauve cur dans real_tmp (4 octets). }
  BinEmitByte($A3);
  AddFixup(FIX_REAL_TMP, 0);
  BinEmitDWord(0);
  { Seek FILE_END. }
  EmitPushImm32(2);                       { FILE_END }
  EmitPushImm32(0);
  EmitPushImm32(0);
  BinEmitByte($53);
  EmitCallIAT(FIX_IAT_SETFILEPTR);        { eax = taille }
  BinEmitByte($50);                       { push eax (sauve taille) }
  { Restaure position originale. }
  EmitPushImm32(0);                       { FILE_BEGIN }
  EmitPushImm32(0);
  BinEmitByte($FF); BinEmitByte($35);     { push dword [real_tmp] }
  AddFixup(FIX_REAL_TMP, 0);
  BinEmitDWord(0);
  BinEmitByte($53);
  EmitCallIAT(FIX_IAT_SETFILEPTR);        { eax = restaure (ignore) }
  BinEmitByte($58);                       { pop eax (taille) }
End;

Procedure GenQualifiedFactor(Const QName : String);
Var
  Si : Integer;
  SubTokStr : String;
  QN : String;
  I : Integer;
Begin
  QN := StrUpper(QName);
  { Tous ces constructeurs retournent une valeur dans EAX. }

  { --- Bit.* : operateurs binaires sur 32 bits --- }
  If QN = 'BIT.AND' Then
  Begin
    ExpectOp('(');
    GenExpression;
    ExpectOp(',');
    EmitPushEAX;
    GenExpression;
    EmitMovECXEAX;
    EmitPopEAX;
    BinEmitByte($21); BinEmitByte($C8);      { and eax, ecx }
    ExpectOp(')');
  End
  Else If QN = 'BIT.OR' Then
  Begin
    ExpectOp('(');
    GenExpression;
    ExpectOp(',');
    EmitPushEAX;
    GenExpression;
    EmitMovECXEAX;
    EmitPopEAX;
    BinEmitByte($09); BinEmitByte($C8);      { or eax, ecx }
    ExpectOp(')');
  End
  Else If QN = 'BIT.XOR' Then
  Begin
    ExpectOp('(');
    GenExpression;
    ExpectOp(',');
    EmitPushEAX;
    GenExpression;
    EmitMovECXEAX;
    EmitPopEAX;
    BinEmitByte($31); BinEmitByte($C8);      { xor eax, ecx }
    ExpectOp(')');
  End
  Else If QN = 'BIT.NOT' Then
  Begin
    ExpectOp('(');
    GenExpression;
    BinEmitByte($F7); BinEmitByte($D0);      { not eax }
    ExpectOp(')');
  End
  Else If QN = 'BIT.SHL' Then
  Begin
    ExpectOp('(');
    GenExpression;
    ExpectOp(',');
    EmitPushEAX;
    GenExpression;
    { ecx doit contenir le compte de decalage (8 bits bas). }
    BinEmitByte($89); BinEmitByte($C1);      { mov ecx, eax }
    EmitPopEAX;
    BinEmitByte($D3); BinEmitByte($E0);      { shl eax, cl }
    ExpectOp(')');
  End
  Else If QN = 'BIT.SHR' Then
  Begin
    ExpectOp('(');
    GenExpression;
    ExpectOp(',');
    EmitPushEAX;
    GenExpression;
    BinEmitByte($89); BinEmitByte($C1);
    EmitPopEAX;
    BinEmitByte($D3); BinEmitByte($E8);      { shr eax, cl (logique) }
    ExpectOp(')');
  End
  Else If QN = 'BIT.TEST' Then
  Begin
    { Test(v, bit) : retourne 1 si (v Shr bit) And 1 = 1, sinon 0. }
    ExpectOp('(');
    GenExpression;
    ExpectOp(',');
    EmitPushEAX;
    GenExpression;
    BinEmitByte($89); BinEmitByte($C1);      { mov ecx, eax }
    EmitPopEAX;
    BinEmitByte($D3); BinEmitByte($E8);      { shr eax, cl }
    EmitAndEAXImm(1);
    ExpectOp(')');
  End
  Else If QN = 'BIT.SET' Then
  Begin
    { Set(v, bit) : retourne v OR (1 SHL bit). }
    ExpectOp('(');
    GenExpression;
    ExpectOp(',');
    EmitPushEAX;
    GenExpression;
    BinEmitByte($89); BinEmitByte($C1);      { mov ecx, eax }
    EmitMovEAXImm32(1);
    BinEmitByte($D3); BinEmitByte($E0);      { shl eax, cl }
    BinEmitByte($89); BinEmitByte($C1);      { mov ecx, eax }
    EmitPopEAX;
    BinEmitByte($09); BinEmitByte($C8);      { or eax, ecx }
    ExpectOp(')');
  End
  Else If QN = 'BIT.CLEAR' Then
  Begin
    { Clear(v, bit) : retourne v AND NOT (1 SHL bit). }
    ExpectOp('(');
    GenExpression;
    ExpectOp(',');
    EmitPushEAX;
    GenExpression;
    BinEmitByte($89); BinEmitByte($C1);      { mov ecx, eax }
    EmitMovEAXImm32(1);
    BinEmitByte($D3); BinEmitByte($E0);      { shl eax, cl }
    BinEmitByte($F7); BinEmitByte($D0);      { not eax }
    BinEmitByte($89); BinEmitByte($C1);      { mov ecx, eax }
    EmitPopEAX;
    BinEmitByte($21); BinEmitByte($C8);      { and eax, ecx }
    ExpectOp(')');
  End

  { --- Timer.Time --- }
  Else If QN = 'TIMER.TIME' Then
  Begin
    If AcceptOp('(') Then
      ExpectOp(')');
    EmitCallIAT(FIX_IAT_GETTICK);
    { Retour dans EAX directement. }
  End

  { --- Random.Int(bound) : LCG Numerical Recipes
        seed := seed * 1664525 + 1013904223 ; retour = (seed SHR 1) MOD bound --- }
  Else If QN = 'RANDOM.INT' Then
  Begin
    ExpectOp('(');
    GenExpression;      { bound dans eax }
    EmitPushEAX;        { [esp] = bound }
    { eax := seed ; eax := eax * 1664525 ; eax += 1013904223 ; seed := eax }
    BinEmitByte($A1);                        { mov eax, [rnd_seed] }
    AddFixup(FIX_RNDSEED, 0);
    BinEmitDWord(0);
    BinEmitByte($69); BinEmitByte($C0);      { imul eax, eax, 1664525 }
    BinEmitDWord(1664525);
    BinEmitByte($05);                        { add eax, 1013904223 }
    BinEmitDWord(1013904223);
    BinEmitByte($A3);                        { mov [rnd_seed], eax }
    AddFixup(FIX_RNDSEED, 0);
    BinEmitDWord(0);
    { eax := eax SHR 1 (force non-negatif pour modulo positif) }
    BinEmitByte($D1); BinEmitByte($E8);      { shr eax, 1 }
    BinEmitByte($59);                        { pop ecx (bound) }
    BinEmitByte($83); BinEmitByte($F9); BinEmitByte($00);  { cmp ecx, 0 }
    BinEmitByte($7F); BinEmitByte($04);      { jg +4 (vers do_div) }
    BinEmitByte($31); BinEmitByte($C0);      { xor eax, eax }
    BinEmitByte($EB); BinEmitByte($06);      { jmp +6 (vers done) }
    { do_div: }
    BinEmitByte($31); BinEmitByte($D2);      { xor edx, edx }
    BinEmitByte($F7); BinEmitByte($F1);      { div ecx }
    BinEmitByte($89); BinEmitByte($D0);      { mov eax, edx }
    { done: }
    ExpectOp(')');
  End

  { --- Args.Count : retourne 1 (toujours au moins le nom du programme).
        Implementation minimale : compte les espaces blancs dans
        GetCommandLineA en tenant compte des guillemets. --- }
  Else If QN = 'ARGS.COUNT' Then
  Begin
    If AcceptOp('(') Then
      ExpectOp(')');
    BinEmitByte($E8);
    AddFixup(FIX_CODE_REL, FindLabel('_args_count'));
    BinEmitDWord(0);
  End

  { --- SYSTEM.* --- }
  Else If QN = 'SYSTEM.ADR' Then
  Begin
    { Retourne l'adresse du symbole nomme. }
    ExpectOp('(');
    If CurTok = TOK_IDENT Then
    Begin
      Si := SymFind(CurTokStr);
      LexNext;
      If Si > 0 Then
      Begin
        SymTab[Si].Used := True;
        BinEmitByte($B8);                    { mov eax, imm32 (fixup) }
        AddFixup(FIX_VAR, Si);
        BinEmitDWord(0);
      End
      Else
      Begin
        ErrorAt(LexLineNo, LexColNo, 'SYSTEM.ADR : variable inconnue');
        EmitMovEAXImm32(0);
      End;
    End
    Else
    Begin
      ErrorAt(LexLineNo, LexColNo, 'SYSTEM.ADR : identificateur attendu');
      EmitMovEAXImm32(0);
    End;
    ExpectOp(')');
  End
  Else If QN = 'SYSTEM.VAL' Then
  Begin
    { VAL(T, x) : conversion de representation ; identite en 32 bits. }
    ExpectOp('(');
    { Premier arg : nom de type (ignore) }
    If CurTok = TOK_IDENT Then
      LexNext;
    ExpectOp(',');
    GenExpression;
    ExpectOp(')');
  End
  Else If QN = 'SYSTEM.GET' Then
  Begin
    { Forme non standard : GET(addr) utilisee dans une expression
      retourne mem[addr]. (La forme Oberon GET(addr, VAR x) est
      supportee comme instruction.) }
    ExpectOp('(');
    GenExpression;
    { eax = addr ; mov eax, [eax] }
    BinEmitByte($8B); BinEmitByte($00);
    ExpectOp(')');
  End

  { --- Strings.Length(s) : longueur de la chaine nul-terminee. --- }
  Else If QN = 'STRINGS.LENGTH' Then
  Begin
    ExpectOp('(');
    If CurTok = TOK_IDENT Then
    Begin
      Si := SymFind(CurTokStr);
      If (Si > 0) And (SymTab[Si].TypeIdx = TYK_ARRCHAR) Then
      Begin
        SymTab[Si].Used := True;
        BinEmitByte($B8);
        AddFixup(FIX_VAR, Si);
        BinEmitDWord(0);
        BinEmitByte($E8);
        AddFixup(FIX_CODE_REL, FindLabel('_strlen'));
        BinEmitDWord(0);
        LexNext;
      End
      Else
      Begin
        ErrorAt(LexLineNo, LexColNo, 'Strings.Length : ARRAY OF CHAR attendu');
        EmitMovEAXImm32(0);
      End;
    End
    Else
      ErrorAt(LexLineNo, LexColNo, 'Strings.Length : identificateur attendu');
    ExpectOp(')');
  End

  { --- Strings.Pos(pat, s, start) : recherche naive, retour -1 si absent. --- }
  Else If QN = 'STRINGS.POS' Then
  Begin
    Si := SymFind('');  { reset for safety }
    ExpectOp('(');
    { Premier arg : pat (identifiant ARRCHAR ou litteral). }
    If CurTok = TOK_STRING Then
    Begin
      I := AddStringLiteral(CurTokStr);
      BinEmitByte($B8);                 { mov eax, imm32 (&literal) }
      AddFixup(FIX_STRING, I);
      BinEmitDWord(0);
      EmitPushEAX;
      LexNext;
    End
    Else If CurTok = TOK_IDENT Then
    Begin
      Si := SymFind(CurTokStr);
      If (Si > 0) And (SymTab[Si].TypeIdx = TYK_ARRCHAR) Then
      Begin
        SymTab[Si].Used := True;
        BinEmitByte($B8);
        AddFixup(FIX_VAR, Si);
        BinEmitDWord(0);
        EmitPushEAX;
        LexNext;
      End
      Else
      Begin
        ErrorAt(LexLineNo, LexColNo, 'Strings.Pos : premier arg ARRAY OF CHAR ou litteral attendu');
        EmitPushImm32(0);
      End;
    End
    Else
    Begin
      ErrorAt(LexLineNo, LexColNo, 'Strings.Pos : identificateur ou litteral attendu');
      EmitPushImm32(0);
    End;
    ExpectOp(',');
    If CurTok = TOK_IDENT Then
    Begin
      Si := SymFind(CurTokStr);
      If (Si > 0) And (SymTab[Si].TypeIdx = TYK_ARRCHAR) Then
      Begin
        SymTab[Si].Used := True;
        BinEmitByte($B8);
        AddFixup(FIX_VAR, Si);
        BinEmitDWord(0);
        EmitPushEAX;
        LexNext;
      End
      Else
      Begin
        ErrorAt(LexLineNo, LexColNo, 'Strings.Pos : deuxieme arg ARRAY OF CHAR attendu');
        EmitPushImm32(0);
      End;
    End;
    ExpectOp(',');
    GenExpression;       { eax = start }
    EmitPushEAX;
    { Appel _str_pos(pat, s, start) -> eax }
    BinEmitByte($E8);
    AddFixup(FIX_CODE_REL, FindLabel('_str_pos'));
    BinEmitDWord(0);
    { Nettoie 3 args }
    BinEmitByte($83); BinEmitByte($C4); BinEmitByte($0C);
    ExpectOp(')');
  End

  { --- In.Done : etat de la derniere lecture (1=OK, 0=EOF). --- }
  Else If QN = 'IN.DONE' Then
  Begin
    If AcceptOp('(') Then
      ExpectOp(')');
    BinEmitByte($A1);                    { mov eax, [InDone] }
    AddFixup(FIX_INDONE, 0);
    BinEmitDWord(0);
  End

  { ========= Palier 4 : Heap, Files, DynLink ========= }

  { --- Heap.Alloc(n) : allocation dans le tas du processus avec
        zero-fill.  Retourne l'adresse dans EAX (0 si echec). --- }
  Else If QN = 'HEAP.ALLOC' Then
  Begin
    ExpectOp('(');
    GenExpression;                     { eax = n }
    EmitPushEAX;                       { arg3 = size }
    EmitPushImm32(8);                  { arg2 = HEAP_ZERO_MEMORY }
    EmitCallIAT(FIX_IAT_GETPROCHEAP);  { eax = hHeap }
    EmitPushEAX;                       { arg1 = hHeap }
    EmitCallIAT(FIX_IAT_HEAPALLOC);    { stdcall : nettoie 12 octets }
    ExpectOp(')');
  End

  { --- DynLink.Load(name) : LoadLibraryA.  name = litteral chaine ou
        identificateur ARRAY OF CHAR. --- }
  Else If QN = 'DYNLINK.LOAD' Then
  Begin
    ExpectOp('(');
    PushStrArg('DynLink.Load');
    EmitCallIAT(FIX_IAT_LOADLIB);
    ExpectOp(')');
  End

  { --- DynLink.GetProc(h, name) : GetProcAddress. --- }
  Else If QN = 'DYNLINK.GETPROC' Then
  Begin
    ExpectOp('(');
    GenExpression;               { eax = handle }
    BinEmitByte($89); BinEmitByte($C3);  { mov ebx, eax (sauvegarde handle) }
    ExpectOp(',');
    PushStrArg('DynLink.GetProc');  { push name (arg2, droite) }
    BinEmitByte($53);              { push ebx (arg1 hModule, gauche) }
    EmitCallIAT(FIX_IAT_GETPROC);
    ExpectOp(')');
  End

  { --- Files.Open(name, mode) : CreateFileA.
        mode = litteral entier : 0 lecture, 1 ecriture/creation,
        2 ajout (ouvre ou cree, puis positionne en fin de fichier).
        Retourne le handle dans EAX (ou -1 = INVALID_HANDLE_VALUE). --- }
  Else If QN = 'FILES.OPEN' Then
  Begin
    GenFilesOpen;
  End

  { --- Files.Read(h, buf, n) : lecture vers ARRAY OF CHAR.
        Retourne le nombre d'octets effectivement lus (0 si EOF, -1 si
        erreur). --- }
  Else If QN = 'FILES.READ' Then
  Begin
    GenFilesReadWrite(True);
  End

  { --- Files.Write(h, buf, n) : ecriture depuis ARRAY OF CHAR.
        Retourne le nombre d'octets ecrits. --- }
  Else If QN = 'FILES.WRITE' Then
  Begin
    GenFilesReadWrite(False);
  End

  { --- Files.Size(h) : retourne la taille du fichier en octets. --- }
  Else If QN = 'FILES.SIZE' Then
  Begin
    ExpectOp('(');
    GenExpression;               { eax = handle }
    GenFilesSize;
    ExpectOp(')');
  End

  { ========= Palier 5 : Coroutines (Win32 fibers) ========= }

  { --- Coroutines.Init() : ConvertThreadToFiber(NULL).  Doit etre
        appele une fois par le thread principal avant d'utiliser les
        autres primitives.  Retourne le handle du fiber principal. --- }
  Else If QN = 'COROUTINES.INIT' Then
  Begin
    If AcceptOp('(') Then
      ExpectOp(')');
    EmitPushImm32(0);                      { lpParameter = NULL }
    EmitCallIAT(FIX_IAT_CVTFIBER);
  End

  { --- Coroutines.Body : adresse du helper _coro_body (voir
        GenCoroBodyHelper) utilisable comme entry pour Coroutines.New.
        Emis comme une constante absolue (FIX_CODE_ABS). --- }
  Else If QN = 'COROUTINES.BODY' Then
  Begin
    If AcceptOp('(') Then
      ExpectOp(')');
    BinEmitByte($B8);                      { mov eax, imm32 }
    AddFixup(FIX_CODE_ABS, FindLabel('_coro_body'));
    BinEmitDWord(0);
  End

  { --- Coroutines.New(entry, param) : CreateFiber(64K, entry, param).
        Retourne le handle du nouveau fiber ou 0 si echec. --- }
  Else If QN = 'COROUTINES.NEW' Then
  Begin
    ExpectOp('(');
    GenExpression;                         { eax = entry }
    EmitPushEAX;                           { a pousser en 2e (lpStartAddress) }
    ExpectOp(',');
    GenExpression;                         { eax = param }
    { Reordre stdcall : push param (droite), puis entry, puis size. }
    EmitPushEAX;                           { arg3 = lpParameter }
    { arg2 = lpStartAddress deja sur la pile.  Mais ordre :
      CreateFiber(dwStackSize, lpStartAddress, lpParameter), donc
      stdcall push droite-a-gauche : lpParameter, lpStartAddress,
      dwStackSize.  Or nous avons pousse entry en premier (sous param).
      Il faut inverser les deux du haut : nous avons actuellement
      [esp]=param, [esp+4]=entry.  Echange : }
    BinEmitByte($58);                      { pop eax (param) }
    BinEmitByte($5A);                      { pop edx (entry) }
    BinEmitByte($50);                      { push eax (param) }
    BinEmitByte($52);                      { push edx (entry) }
    EmitPushImm32($10000);                 { arg1 = dwStackSize = 64K }
    EmitCallIAT(FIX_IAT_CREATEFIBER);
    ExpectOp(')');
  End

  Else
  Begin
    { Qualificatif inconnu : on essaie la recherche symbolique
      sur le nom complet, sinon erreur. }
    Si := SymFind(QName);
    If Si > 0 Then
    Begin
      EmitMovEAXMem32($400000 + $2000 + SymTab[Si].DataOffs);
      BinCodeLen := BinCodeLen - 4;
      AddFixup(FIX_VAR, Si);
      BinCodeLen := BinCodeLen + 4;
    End
    Else
    Begin
      ErrorAt(LexLineNo, LexColNo, 'Fonction qualifiee inconnue: ' + QName);
      EmitMovEAXImm32(0);
      { Consomme d'eventuels arguments pour ne pas deraper. }
      If AcceptOp('(') Then
      Begin
        While (CurTok <> TOK_EOF) And
              ((CurTok <> TOK_OP) Or (CurTokStr <> ')')) Do
        Begin
          SubTokStr := CurTokStr;
          LexNext;
        End;
        If (CurTok = TOK_OP) And (CurTokStr = ')') Then
          LexNext;
      End;
    End;
  End;
End;


Procedure GenFactor;
Var
  Si, N : Integer;
  Name : String;
  TypeName : String;
  Val : LongInt;
  LabSkip : String;
Begin
  If CurTok = TOK_IDENT Then
  Begin
    Name := CurTokStr;
    { Fonctions built-in Oberon.  Reconnues avant la recherche symbolique
      pour qu'elles soient toujours disponibles meme sans declaration. }
    If Name = 'LEN' Then
    Begin
      { LEN(s) : capacite compile-time d'un ARRAY OF CHAR declare. }
      LexNext;
      ExpectOp('(');
      If CurTok = TOK_IDENT Then
      Begin
        Si := SymFind(CurTokStr);
        If (Si > 0) And (SymTab[Si].TypeIdx = TYK_ARRCHAR) Then
          EmitMovEAXImm32(SymTab[Si].ArrSize)
        Else
        Begin
          ErrorAt(LexLineNo, LexColNo, 'LEN: identifiant ARRAY OF CHAR attendu');
          EmitMovEAXImm32(0);
        End;
        LexNext;
      End
      Else
      Begin
        ErrorAt(LexLineNo, LexColNo, 'LEN: identifiant attendu');
        EmitMovEAXImm32(0);
      End;
      ExpectOp(')');
    End
    Else If (Name = 'ABS') Or (Name = 'ODD') Or (Name = 'CHR') Or
       (Name = 'ORD') Or (Name = 'CAP') Or (Name = 'ASH') Or
       (Name = 'MAX') Or (Name = 'MIN') Or (Name = 'SIZE') Then
    Begin
      LexNext;
      ExpectOp('(');
      If (Name = 'MAX') Or (Name = 'MIN') Or (Name = 'SIZE') Then
      Begin
        { Argument : nom d'un type de base, evalue a la compilation }
        If CurTok = TOK_IDENT Then
        Begin
          TypeName := StrUpper(CurTokStr);
          LexNext;
        End
        Else
          TypeName := 'INTEGER';
        If Name = 'SIZE' Then
        Begin
          If TypeName = 'INTEGER' Then Val := 4
          Else If TypeName = 'BOOLEAN' Then Val := 1
          Else If TypeName = 'CHAR' Then Val := 1
          Else Val := 4;
        End
        Else If Name = 'MAX' Then
        Begin
          If TypeName = 'INTEGER' Then Val := 2147483647
          Else If TypeName = 'BOOLEAN' Then Val := 1
          Else If TypeName = 'CHAR' Then Val := 255
          Else Val := 2147483647;
        End
        Else   { MIN }
        Begin
          If TypeName = 'INTEGER' Then Val := LongInt($80000000)
          Else If TypeName = 'BOOLEAN' Then Val := 0
          Else If TypeName = 'CHAR' Then Val := 0
          Else Val := 0;
        End;
        EmitMovEAXImm32(Val);
      End
      Else If Name = 'ASH' Then
      Begin
        { ASH(x, n) : x est une expression, n doit etre une constante
          entiere litterale (eventuellement signee) dans ce compilateur
          minimal. }
        GenExpression;
        ExpectOp(',');
        Si := 1;   { signe = +1 par defaut }
        If (CurTok = TOK_OP) And (CurTokStr = '-') Then
        Begin
          Si := -1;
          LexNext;
        End
        Else If (CurTok = TOK_OP) And (CurTokStr = '+') Then
          LexNext;
        If CurTok = TOK_INT Then
        Begin
          N := Si * CurTokNum;
          LexNext;
          If N > 0 Then
            EmitShlEAXImm8(N And $1F)
          Else If N < 0 Then
            EmitSarEAXImm8((-N) And $1F);
        End
        Else
          ErrorAt(LexLineNo, LexColNo,
                  'ASH: le deuxieme argument doit etre une constante entiere');
      End
      Else
      Begin
        GenExpression;
        If Name = 'ABS' Then
        Begin
          LabSkip := GenLabel;
          { test eax, eax ; jge LabSkip ; neg eax ; LabSkip: }
          EmitTestEAX;
          BinEmitByte($0F); BinEmitByte($8D);
          AddFixup(FIX_CODE_REL, FindLabel(LabSkip));
          BinEmitDWord(0);
          EmitNegEAX;
          DefineLabel(LabSkip);
        End
        Else If Name = 'ODD' Then
        Begin
          EmitAndEAXImm(1);
        End
        Else If (Name = 'CHR') Or (Name = 'ORD') Then
        Begin
          { Identite : les caracteres et entiers partagent la meme
            representation 32 bits dans ce compilateur. }
        End
        Else If Name = 'CAP' Then
        Begin
          { Si 'a' <= eax <= 'z' alors eax -= 32 ; sinon inchange }
          LabSkip := GenLabel;
          EmitCmpEAXImm(Ord('a'));
          EmitJL(LabSkip);
          EmitCmpEAXImm(Ord('z'));
          EmitJG(LabSkip);
          EmitSubEAXImm(32);
          DefineLabel(LabSkip);
        End;
      End;
      ExpectOp(')');
    End
    Else
    Begin
      { Appel qualifie Module.Proc(...) ou variable locale. }
      LexNext;
      If (CurTok = TOK_OP) And (CurTokStr = '.') Then
      Begin
        LexNext;
        { Apres un qualificateur, certains noms Oberon peuvent etre
          des mots-cles du langage (And, Or, ...) ; on les accepte
          comme partie du nom qualifie. }
        If (CurTok = TOK_IDENT) Or (CurTok = TOK_KEYWORD) Then
        Begin
          Name := Name + '.' + CurTokStr;
          LexNext;
        End;
        GenQualifiedFactor(Name);
      End
      Else
      Begin
        Si := SymFind(Name);
        If Si > 0 Then
        Begin
          SymTab[Si].Used := True;
          If (CurTok = TOK_OP) And (CurTokStr = '[') Then
          Begin
            { Indexation s[i] sur ARRAY OF CHAR : retourne l'octet indexe
              en extension zero dans eax. }
            LexNext;
            GenExpression;                { eax := index }
            EmitMovECXEAX;                { ecx := index }
            ExpectOp(']');
            If SymTab[Si].TypeIdx <> TYK_ARRCHAR Then
              ErrorAt(LexLineNo, LexColNo,
                      'Indexation impossible : ' + Name + ' n''est pas ARRAY OF CHAR');
            EmitLoadAddrEAX(Si);          { eax := adresse de s }
            EmitAddEAXECX;                { eax := &s[i] }
            { movzx eax, byte [eax]  -->  0F B6 00 }
            BinEmitByte($0F); BinEmitByte($B6); BinEmitByte($00);
          End
          Else
          Begin
            EmitMovEAXMem32($400000 + $2000 + SymTab[Si].DataOffs);
            BinCodeLen := BinCodeLen - 4;
            AddFixup(FIX_VAR, Si);
            BinCodeLen := BinCodeLen + 4;
          End;
        End
        Else
          ErrorAt(LexLineNo, LexColNo, 'Variable inconnue: ' + Name);
      End;
    End;
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

{ ============================================================
  Palier 3 : generateur d'expressions REAL (FPU x87).

  Conventions :
   * Chaque appel a GenRealExpression / GenRealTerm / GenRealFactor
     laisse le resultat sur le sommet de la pile FPU (st(0)).
   * Le contexte appelant consomme ce resultat (typiquement par
     fstp dword [var]).
   * Les appels Math.* et Random.Real sont traites comme des facteurs.
   * Un litteral INTEGER rencontre dans un contexte REAL est
     automatiquement converti (cree un litteral REAL equivalent).
  ============================================================ }
Procedure GenRealExpression; Forward;

Procedure GenRealFactor;
Var
  Ch, Name, QN, Tok : String;
  Si, Idx : Integer;
  Bits : LongInt;
  Sng : Single;
Begin
  If CurTok = TOK_REAL Then
  Begin
    Idx := AddRealLiteral(CurTokReal);
    EmitFLD_Real_At(FIX_REAL_CONST, Idx);
    LexNext;
  End
  Else If CurTok = TOK_INT Then
  Begin
    Sng := CurTokNum;
    Move(Sng, Bits, 4);
    Idx := AddRealLiteral(Bits);
    EmitFLD_Real_At(FIX_REAL_CONST, Idx);
    LexNext;
  End
  Else If (CurTok = TOK_OP) And (CurTokStr = '(') Then
  Begin
    LexNext;
    GenRealExpression;
    ExpectOp(')');
  End
  Else If (CurTok = TOK_OP) And (CurTokStr = '-') Then
  Begin
    LexNext;
    GenRealFactor;
    EmitFCHS;
  End
  Else If (CurTok = TOK_OP) And (CurTokStr = '+') Then
  Begin
    LexNext;
    GenRealFactor;
  End
  Else If CurTok = TOK_IDENT Then
  Begin
    Name := CurTokStr;
    LexNext;
    QN := Name;
    If (CurTok = TOK_OP) And (CurTokStr = '.') Then
    Begin
      LexNext;
      If CurTok = TOK_IDENT Then
      Begin
        QN := Name + '.' + CurTokStr;
        LexNext;
      End;
    End;
    { ----- Math.* ----- }
    If QN = 'Math.Pi' Then
    Begin
      EmitFLDPI;
    End
    Else If QN = 'Math.Sqrt' Then
    Begin
      ExpectOp('('); GenRealExpression; ExpectOp(')');
      EmitFSQRT;
    End
    Else If QN = 'Math.Abs' Then
    Begin
      ExpectOp('('); GenRealExpression; ExpectOp(')');
      EmitFABS;
    End
    Else If QN = 'Math.Sin' Then
    Begin
      ExpectOp('('); GenRealExpression; ExpectOp(')');
      EmitFSIN;
    End
    Else If QN = 'Math.Cos' Then
    Begin
      ExpectOp('('); GenRealExpression; ExpectOp(')');
      EmitFCOS;
    End
    Else If QN = 'Math.ArcTan' Then
    Begin
      ExpectOp('('); GenRealExpression; ExpectOp(')');
      { atan(x) : pousser 1 puis fpatan -> atan(st1/st0) = atan(x/1). }
      EmitFLD1;
      EmitFPATAN;
    End
    Else If QN = 'Math.Ln' Then
    Begin
      ExpectOp('('); GenRealExpression; ExpectOp(')');
      { ln(x) = ln(2) * log2(x).  fldln2 ; fxch ; fyl2x. }
      EmitFLDLN2;
      EmitFXCH;
      EmitFYL2X;
    End
    Else If QN = 'Math.Exp' Then
    Begin
      ExpectOp('('); GenRealExpression; ExpectOp(')');
      { exp(x) = 2^(x*log2(e)).  Sequence standard x87. }
      EmitFLDL2E;        { st0=log2(e), st1=x }
      EmitFMULP;         { st0 = x*log2(e) }
      EmitFLD_ST0;       { duplique }
      EmitFRNDINT;       { st0 = round(y), st1 = y }
      EmitFXCH;          { st0 = y, st1 = round(y) }
      BinEmitByte($D8); BinEmitByte($E1);  { fsub st, st(1) : st0 = y - round(y) }
      EmitF2XM1;         { st0 = 2^(y-round(y)) - 1 }
      EmitFLD1;
      EmitFADDP;         { st0 = 2^(y-round(y)), st1 = round(y) }
      EmitFSCALE;        { st0 = st0 * 2^st1 = 2^y }
      { Pop st(1) (l'exposant entier) en utilisant fstp st(1) : DD D9. }
      BinEmitByte($DD); BinEmitByte($D9);
    End
    { ----- Random.Real ----- }
    Else If QN = 'Random.Real' Then
    Begin
      If (CurTok = TOK_OP) And (CurTokStr = '(') Then
      Begin
        LexNext;
        ExpectOp(')');
      End;
      { On reutilise le LCG INTEGER existant : Random.Int(MAXINT) puis
        division par 2^31.  Inline : newseed = seed*1103515245+12345 ;
        val = (newseed shr 1) ; x = val / 2147483648.0.  Stocke val
        dans real_tmp comme INTEGER positif, fild, divise par 2^31. }
      { eax := rndseed }
      BinEmitByte($A1); AddFixup(FIX_RNDSEED, 0); BinEmitDWord(0); { mov eax, [rndseed] }
      BinEmitByte($69); BinEmitByte($C0); BinEmitDWord(1103515245); { imul eax, eax, 1103515245 }
      BinEmitByte($05); BinEmitDWord(12345);                       { add eax, 12345 }
      { Sauvegarde la nouvelle seed. }
      BinEmitByte($A3); AddFixup(FIX_RNDSEED, 0); BinEmitDWord(0); { mov [rndseed], eax }
      { val = eax shr 1, dans real_tmp. }
      BinEmitByte($D1); BinEmitByte($E8);                          { shr eax, 1 }
      BinEmitByte($A3); AddFixup(FIX_REAL_TMP, 0); BinEmitDWord(0); { mov [real_tmp], eax }
      EmitFILD_At(FIX_REAL_TMP, 0);
      { Divise par 2147483648.0 = 0x4F000000. }
      Bits := $4F000000;
      Idx := AddRealLiteral(Bits);
      EmitFLD_Real_At(FIX_REAL_CONST, Idx);
      EmitFDIVP;
    End
    Else
    Begin
      { Variable reelle. }
      Si := SymFind(Name);
      If (Si > 0) And (SymTab[Si].TypeIdx = TYK_REAL) Then
      Begin
        SymTab[Si].Used := True;
        EmitFLD_Real_At(FIX_VAR, Si);
      End
      Else If (Si > 0) And (SymTab[Si].TypeIdx = TYK_INTEGER) Then
      Begin
        { Variable INTEGER dans un contexte REAL : conversion implicite. }
        SymTab[Si].Used := True;
        { fild dword [var]. }
        BinEmitByte($DB); BinEmitByte($05);
        AddFixup(FIX_VAR, Si); BinEmitDWord(0);
      End
      Else
        ErrorAt(LexLineNo, LexColNo,
                'Facteur REAL attendu, inconnu : ' + QN);
    End;
  End
  Else
  Begin
    Ch := CurTokStr;
    Tok := Ch;
    ErrorAt(LexLineNo, LexColNo, 'Facteur REAL attendu (vu: ' + Tok + ')');
  End;
End;

Procedure GenRealTerm;
Var Op : String;
Begin
  GenRealFactor;
  While (CurTok = TOK_OP) And ((CurTokStr = '*') Or (CurTokStr = '/')) Do
  Begin
    Op := CurTokStr;
    LexNext;
    GenRealFactor;
    If Op = '*' Then
      EmitFMULP
    Else
      EmitFDIVP;
  End;
End;

Procedure GenRealExpression;
Var Op : String;
Begin
  GenRealTerm;
  While (CurTok = TOK_OP) And ((CurTokStr = '+') Or (CurTokStr = '-')) Do
  Begin
    Op := CurTokStr;
    LexNext;
    GenRealTerm;
    If Op = '+' Then
      EmitFADDP
    Else
      EmitFSUBP;
  End;
End;

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

{ --- Ecrit le contenu du tableau DstSi (ARRAY OF CHAR) sur le handle
  specifie par HandleFixup (FIX_STDOUT ou FIX_STDERR), en s'arretant
  au premier octet nul ou a ArrSize octets. --- }
Procedure GenWriteArrSym(Si, HandleFixup : Integer);
Var
  LabLoop, LabDone : String;
Begin
  SymTab[Si].Used := True;
  LabLoop := GenLabel;
  LabDone := GenLabel;
  { edi := addr(s) }
  BinEmitByte($BF);
  AddFixup(FIX_VAR, Si);
  BinEmitDWord(0);
  { xor ebx, ebx ; ecx := ArrSize }
  BinEmitByte($31); BinEmitByte($DB);
  BinEmitByte($B9); BinEmitDWord(SymTab[Si].ArrSize);
  DefineLabel(LabLoop);
  { cmp ebx, ecx ; je LabDone }
  BinEmitByte($39); BinEmitByte($CB);
  EmitJZ(LabDone);
  { mov al, [edi+ebx] ; test al, al ; jz LabDone }
  BinEmitByte($8A); BinEmitByte($04); BinEmitByte($1F);
  BinEmitByte($84); BinEmitByte($C0);
  EmitJZ(LabDone);
  BinEmitByte($43);                          { inc ebx }
  EmitJmp(LabLoop);
  DefineLabel(LabDone);
  { WriteFile(handle, edi, ebx, &bytes_written, 0) }
  EmitPushImm32(0);
  BinEmitByte($68);                          { push imm32 (bytes_written) }
  AddFixup(FIX_BYTES_WRITTEN, 0);
  BinEmitDWord(0);
  BinEmitByte($53);                          { push ebx (len) }
  BinEmitByte($57);                          { push edi (buf) }
  { push [handle] }
  BinEmitByte($FF); BinEmitByte($35);
  AddFixup(HandleFixup, 0);
  BinEmitDWord(0);
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

{ --- Out.Char(n) : ecrit un octet (code ASCII) sur stdout --- }
Procedure GenOutChar;
Begin
  GenExpression;
  { Stocke le byte bas de eax dans le buffer int (reutilise comme tampon
    de 1 octet).  mov [IntBuf], al --> A2 imm32 }
  BinEmitByte($A2);
  AddFixup(FIX_INTBUF, 0);
  BinEmitDWord(0);

  { WriteFile(stdout, IntBuf, 1, &bytes_written, NULL) }
  EmitPushImm32(0);
  EmitPushImm32(0);
  BinCodeLen := BinCodeLen - 4;
  AddFixup(FIX_BYTES_WRITTEN, 0);
  BinCodeLen := BinCodeLen + 4;
  EmitPushImm32(1);
  EmitPushImm32(0);
  BinCodeLen := BinCodeLen - 4;
  AddFixup(FIX_INTBUF, 0);
  BinCodeLen := BinCodeLen + 4;
  EmitMovEAXMem32(0);
  BinCodeLen := BinCodeLen - 4;
  AddFixup(FIX_STDOUT, 0);
  BinCodeLen := BinCodeLen + 4;
  EmitPushEAX;
  EmitCallIAT(FIX_IAT_WRITE);
End;

{ --- Out.Hex(n) : ecrit n sur stdout en hexadecimal 8 chiffres --- }
Procedure GenOutHex;
Begin
  GenExpression;
  EmitPushEAX;
  BinEmitByte($E8);
  AddFixup(FIX_CODE_REL, FindLabel('_printhex'));
  BinEmitDWord(0);
End;

{ --- Err.String("..."), Err.Int(n), Err.Ln : sortie sur stderr --- }
Procedure GenErrString(Const S : String);
Var StrIdx : Integer;
Begin
  StrIdx := AddStringLiteral(S);
  EmitPushImm32(0);
  EmitPushImm32(0);
  BinCodeLen := BinCodeLen - 4;
  AddFixup(FIX_BYTES_WRITTEN, 0);
  BinCodeLen := BinCodeLen + 4;
  EmitPushImm32(Length(S));
  EmitPushImm32(0);
  BinCodeLen := BinCodeLen - 4;
  AddFixup(FIX_STRING, StrIdx);
  BinCodeLen := BinCodeLen + 4;
  EmitMovEAXMem32(0);
  BinCodeLen := BinCodeLen - 4;
  AddFixup(FIX_STDERR, 0);
  BinCodeLen := BinCodeLen + 4;
  EmitPushEAX;
  EmitCallIAT(FIX_IAT_WRITE);
End;

Procedure GenErrLn;
Begin
  EmitPushImm32(0);
  EmitPushImm32(0);
  BinCodeLen := BinCodeLen - 4;
  AddFixup(FIX_BYTES_WRITTEN, 0);
  BinCodeLen := BinCodeLen + 4;
  EmitPushImm32(2);
  EmitPushImm32(0);
  BinCodeLen := BinCodeLen - 4;
  AddFixup(FIX_CRLF, 0);
  BinCodeLen := BinCodeLen + 4;
  EmitMovEAXMem32(0);
  BinCodeLen := BinCodeLen - 4;
  AddFixup(FIX_STDERR, 0);
  BinCodeLen := BinCodeLen + 4;
  EmitPushEAX;
  EmitCallIAT(FIX_IAT_WRITE);
End;

Procedure GenErrInt;
Begin
  GenExpression;
  EmitPushEAX;
  BinEmitByte($E8);
  AddFixup(FIX_CODE_REL, FindLabel('_printint_err'));
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

{ -------- Helpers COPY / APPEND pour ARRAY OF CHAR --------

  Convention : tous ces helpers produisent du code inline qui copie
  un nombre borne d'octets depuis la source vers la destination
  (adresses statiques connues), respecte la terminaison nulle et
  respecte la capacite de la destination (Dst.ArrSize).  Les registres
  eax/ecx/edx/esi/edi sont clobberes.
}

{ Copie une chaine litterale S dans le tableau DstSi.
  Ecrit au plus (DstSize-1) octets puis un nul de fin si possible. }
Procedure GenCopyLiteralToArr(Const S : String; DstSi : Integer);
Var
  DstSize, N, I : Integer;
  StrIdx : Integer;
Begin
  DstSize := SymTab[DstSi].ArrSize;
  N := Length(S);
  If N > DstSize - 1 Then
    N := DstSize - 1;
  If N < 0 Then N := 0;
  StrIdx := AddStringLiteral(S);
  { edi := dest ; esi := source ; rep movsb ; mov [edi], 0 }
  { mov edi, imm32 (fixup var) }
  BinEmitByte($BF);
  SymTab[DstSi].Used := True;
  AddFixup(FIX_VAR, DstSi);
  BinEmitDWord(0);
  { mov esi, imm32 (fixup string) }
  BinEmitByte($BE);
  AddFixup(FIX_STRING, StrIdx);
  BinEmitDWord(0);
  { mov ecx, N }
  BinEmitByte($B9);
  BinEmitDWord(N);
  { cld ; rep movsb  -->  FC F3 A4 }
  BinEmitByte($FC);
  BinEmitByte($F3);
  BinEmitByte($A4);
  { mov byte [edi], 0  -->  C6 07 00 }
  BinEmitByte($C6); BinEmitByte($07); BinEmitByte($00);
  I := N; { unused warning suppression }
End;

{ Copie depuis ARRAY OF CHAR (SrcSi) vers ARRAY OF CHAR (DstSi), en
  s'arretant au premier octet nul et en respectant DstSize-1. }
Procedure GenCopyArrToArr(SrcSi, DstSi : Integer);
Var
  DstSize : Integer;
  LabLoop, LabDone : String;
Begin
  DstSize := SymTab[DstSi].ArrSize;
  { edi := &dst ; esi := &src ; ecx := DstSize-1 }
  BinEmitByte($BF);
  SymTab[DstSi].Used := True;
  AddFixup(FIX_VAR, DstSi);
  BinEmitDWord(0);
  BinEmitByte($BE);
  SymTab[SrcSi].Used := True;
  AddFixup(FIX_VAR, SrcSi);
  BinEmitDWord(0);
  BinEmitByte($B9);
  BinEmitDWord(DstSize - 1);
  LabLoop := GenLabel;
  LabDone := GenLabel;
  DefineLabel(LabLoop);
  { test ecx, ecx ; jz LabDone }
  BinEmitByte($85); BinEmitByte($C9);
  EmitJZ(LabDone);
  { mov al, [esi]  -->  8A 06 }
  BinEmitByte($8A); BinEmitByte($06);
  { mov [edi], al  -->  88 07 }
  BinEmitByte($88); BinEmitByte($07);
  { test al, al ; jz LabDone (apres avoir copie le nul) }
  BinEmitByte($84); BinEmitByte($C0);
  EmitJZ(LabDone);
  { inc esi ; inc edi ; dec ecx }
  BinEmitByte($46); BinEmitByte($47); BinEmitByte($49);
  EmitJmp(LabLoop);
  DefineLabel(LabDone);
  { mov byte [edi], 0 pour s'assurer de la terminaison. }
  BinEmitByte($C6); BinEmitByte($07); BinEmitByte($00);
End;

{ Append d'une chaine litterale S a la fin du tableau DstSi (comme
  Strings.Append).  Parcourt dst pour trouver le nul, puis copie au
  plus (DstSize - longueur_courante - 1) octets. }
Procedure GenAppendLiteralToArr(Const S : String; DstSi : Integer);
Var
  DstSize : Integer;
  StrIdx : Integer;
  LabSeek, LabSeekEnd, LabCopy, LabCopyEnd : String;
Begin
  DstSize := SymTab[DstSi].ArrSize;
  StrIdx := AddStringLiteral(S);
  { edi := &dst }
  BinEmitByte($BF);
  SymTab[DstSi].Used := True;
  AddFixup(FIX_VAR, DstSi);
  BinEmitDWord(0);
  { ecx := DstSize }
  BinEmitByte($B9);
  BinEmitDWord(DstSize);
  LabSeek    := GenLabel;
  LabSeekEnd := GenLabel;
  LabCopy    := GenLabel;
  LabCopyEnd := GenLabel;
  { Boucle de recherche du nul, avec garde sur ecx pour ne pas
    deborder le tableau. }
  DefineLabel(LabSeek);
  { test ecx, ecx ; jz LabSeekEnd }
  BinEmitByte($85); BinEmitByte($C9);
  EmitJZ(LabSeekEnd);
  { mov al, [edi] ; test al, al ; jz LabSeekEnd }
  BinEmitByte($8A); BinEmitByte($07);
  BinEmitByte($84); BinEmitByte($C0);
  EmitJZ(LabSeekEnd);
  BinEmitByte($47);                { inc edi }
  BinEmitByte($49);                { dec ecx }
  EmitJmp(LabSeek);
  DefineLabel(LabSeekEnd);
  { Ici ecx = DstSize - longueur_courante = capacite restante + 1 terminator.
    Capacite utile = ecx - 1.  On garantit ecx > 0 avant de copier. }
  { esi := source literal }
  BinEmitByte($BE);
  AddFixup(FIX_STRING, StrIdx);
  BinEmitDWord(0);
  { ebx := longueur du litteral }
  BinEmitByte($BB);
  BinEmitDWord(Length(S));
  { Boucle copie : tant que ebx > 0 et ecx > 1, copie et avance. }
  DefineLabel(LabCopy);
  { test ebx, ebx ; jz LabCopyEnd }
  BinEmitByte($85); BinEmitByte($DB);
  EmitJZ(LabCopyEnd);
  { cmp ecx, 1 ; jle LabCopyEnd }
  BinEmitByte($83); BinEmitByte($F9); BinEmitByte($01);
  EmitJLE(LabCopyEnd);
  { mov al, [esi] ; mov [edi], al ; inc esi ; inc edi ; dec ebx ; dec ecx }
  BinEmitByte($8A); BinEmitByte($06);
  BinEmitByte($88); BinEmitByte($07);
  BinEmitByte($46); BinEmitByte($47);
  BinEmitByte($4B); BinEmitByte($49);
  EmitJmp(LabCopy);
  DefineLabel(LabCopyEnd);
  { Terminator. }
  BinEmitByte($C6); BinEmitByte($07); BinEmitByte($00);
End;

{ Append de SrcSi (ARRAY OF CHAR) a DstSi (ARRAY OF CHAR). }
Procedure GenAppendArrToArr(SrcSi, DstSi : Integer);
Var
  DstSize : Integer;
  LabSeek, LabSeekEnd, LabCopy, LabCopyEnd : String;
Begin
  DstSize := SymTab[DstSi].ArrSize;
  BinEmitByte($BF);
  SymTab[DstSi].Used := True;
  AddFixup(FIX_VAR, DstSi);
  BinEmitDWord(0);
  BinEmitByte($B9);
  BinEmitDWord(DstSize);
  LabSeek := GenLabel; LabSeekEnd := GenLabel;
  LabCopy := GenLabel; LabCopyEnd := GenLabel;
  DefineLabel(LabSeek);
  BinEmitByte($85); BinEmitByte($C9);
  EmitJZ(LabSeekEnd);
  BinEmitByte($8A); BinEmitByte($07);
  BinEmitByte($84); BinEmitByte($C0);
  EmitJZ(LabSeekEnd);
  BinEmitByte($47);
  BinEmitByte($49);
  EmitJmp(LabSeek);
  DefineLabel(LabSeekEnd);
  { esi := &src }
  BinEmitByte($BE);
  SymTab[SrcSi].Used := True;
  AddFixup(FIX_VAR, SrcSi);
  BinEmitDWord(0);
  DefineLabel(LabCopy);
  { cmp ecx, 1 ; jle LabCopyEnd }
  BinEmitByte($83); BinEmitByte($F9); BinEmitByte($01);
  EmitJLE(LabCopyEnd);
  BinEmitByte($8A); BinEmitByte($06);        { mov al, [esi] }
  BinEmitByte($84); BinEmitByte($C0);        { test al, al }
  EmitJZ(LabCopyEnd);
  BinEmitByte($88); BinEmitByte($07);        { mov [edi], al }
  BinEmitByte($46); BinEmitByte($47);        { inc esi ; inc edi }
  BinEmitByte($49);                          { dec ecx }
  EmitJmp(LabCopy);
  DefineLabel(LabCopyEnd);
  BinEmitByte($C6); BinEmitByte($07); BinEmitByte($00);
End;

{ ============================================================
  Palier 2 : helpers de module (Strings, Conv, In, Args).

  Conventions :
  * `(` a ete consomme par l'appelant, `)` sera consomme par l'appelant.
  * Chaque procedure consomme ses arguments du flux de tokens et
    emet le code qui realise l'action ; rien n'est retourne.
  * Les arguments ARRAY OF CHAR doivent etre des identifiants globaux
    (TYK_ARRCHAR).  Les expressions arbitraires produisant une adresse
    ne sont pas supportees.
  ============================================================ }

{ Utilitaire : attend un identifiant ARRCHAR, retourne son Si ou -1. }
Function ParseArrCharIdent(Const Ctx : String) : Integer;
Var Si : Integer;
Begin
  ParseArrCharIdent := -1;
  If CurTok = TOK_IDENT Then
  Begin
    Si := SymFind(CurTokStr);
    If (Si > 0) And (SymTab[Si].TypeIdx = TYK_ARRCHAR) Then
    Begin
      SymTab[Si].Used := True;
      LexNext;
      ParseArrCharIdent := Si;
    End
    Else
    Begin
      ErrorAt(LexLineNo, LexColNo, Ctx + ' : ARRAY OF CHAR attendu');
      LexNext;
    End;
  End
  Else
    ErrorAt(LexLineNo, LexColNo, Ctx + ' : identificateur attendu');
End;

{ Utilitaire : charge addr(Si) dans eax. }
Procedure EmitLoadArrAddr(Si : Integer);
Begin
  BinEmitByte($B8);        { mov eax, imm32 }
  AddFixup(FIX_VAR, Si);
  BinEmitDWord(0);
End;

{ --- Strings.Replace(src, pos, dst) : ecrit src a partir de dst[pos],
   sans decalage, borne par LEN(dst)-1.  src peut etre literal ou ARRCHAR. --- }
Procedure GenStringsReplace;
Var
  SrcSi, DstSi, StrIdx : Integer;
  SrcLit : String;
  LabLoop, LabEnd : String;
  IsLit : Boolean;
Begin
  IsLit := False;
  SrcSi := -1;
  SrcLit := '';
  StrIdx := 0;
  If CurTok = TOK_STRING Then
  Begin
    SrcLit := CurTokStr;
    IsLit := True;
    StrIdx := AddStringLiteral(SrcLit);
    LexNext;
  End
  Else
    SrcSi := ParseArrCharIdent('Strings.Replace (src)');
  ExpectOp(',');
  GenExpression;                         { eax = pos }
  EmitPushEAX;
  ExpectOp(',');
  DstSi := ParseArrCharIdent('Strings.Replace (dst)');
  If DstSi <= 0 Then Exit;
  { edi := &dst + pos }
  EmitLoadArrAddr(DstSi);
  BinEmitByte($59);                      { pop ecx (pos) }
  BinEmitByte($01); BinEmitByte($C8);    { add eax, ecx }
  BinEmitByte($89); BinEmitByte($C7);    { mov edi, eax }
  { esi := &src }
  If IsLit Then
  Begin
    BinEmitByte($BE);                    { mov esi, imm32 }
    AddFixup(FIX_STRING, StrIdx);
    BinEmitDWord(0);
  End
  Else If SrcSi > 0 Then
  Begin
    BinEmitByte($BE);
    AddFixup(FIX_VAR, SrcSi);
    BinEmitDWord(0);
  End;
  { ecx := adresse limite = &dst + LEN(dst) - 1 }
  BinEmitByte($B9);                      { mov ecx, imm32 &dst }
  AddFixup(FIX_VAR, DstSi);
  BinEmitDWord(0);
  BinEmitByte($81); BinEmitByte($C1);    { add ecx, imm32 (cap-1) }
  BinEmitDWord(SymTab[DstSi].ArrSize - 1);
  { Boucle : tant que *esi != 0 et edi < ecx, copier. }
  LabLoop := GenLabel;
  LabEnd  := GenLabel;
  DefineLabel(LabLoop);
  { cmp edi, ecx ; jae LabEnd }
  BinEmitByte($39); BinEmitByte($CF);
  BinEmitByte($0F); BinEmitByte($83);    { jae rel32 }
  AddFixup(FIX_CODE_REL, FindLabel(LabEnd));
  BinEmitDWord(0);
  BinEmitByte($8A); BinEmitByte($06);    { mov al, [esi] }
  BinEmitByte($84); BinEmitByte($C0);    { test al, al }
  EmitJZ(LabEnd);
  BinEmitByte($88); BinEmitByte($07);    { mov [edi], al }
  BinEmitByte($46); BinEmitByte($47);    { inc esi; inc edi }
  EmitJmp(LabLoop);
  DefineLabel(LabEnd);
End;

{ --- Strings.Delete(s, pos, n) : supprime n chars a partir de pos en
   decalant la suite vers la gauche, puis tronque par nul. --- }
Procedure GenStringsDelete;
Var
  DstSi : Integer;
  LabLoop, LabEnd : String;
Begin
  DstSi := ParseArrCharIdent('Strings.Delete');
  If DstSi <= 0 Then Exit;
  ExpectOp(',');
  GenExpression;                         { eax = pos }
  EmitPushEAX;
  ExpectOp(',');
  GenExpression;                         { eax = n }
  BinEmitByte($89); BinEmitByte($C1);    { mov ecx, eax  (n) }
  BinEmitByte($5A);                      { pop edx       (pos) }
  { edi := &s + pos, esi := &s + pos + n, ebx := LEN(s)-1-pos }
  EmitLoadArrAddr(DstSi);
  BinEmitByte($89); BinEmitByte($C7);    { mov edi, eax }
  BinEmitByte($01); BinEmitByte($D7);    { add edi, edx }
  BinEmitByte($89); BinEmitByte($FE);    { mov esi, edi }
  BinEmitByte($01); BinEmitByte($CE);    { add esi, ecx }
  BinEmitByte($BB);                      { mov ebx, imm32 (cap-1) }
  BinEmitDWord(SymTab[DstSi].ArrSize - 1);
  BinEmitByte($29); BinEmitByte($D3);    { sub ebx, edx (ebx = reste = cap-1-pos) }
  LabLoop := GenLabel;
  LabEnd  := GenLabel;
  DefineLabel(LabLoop);
  BinEmitByte($85); BinEmitByte($DB);    { test ebx, ebx }
  EmitJZ(LabEnd);
  BinEmitByte($8A); BinEmitByte($06);    { mov al, [esi] }
  BinEmitByte($88); BinEmitByte($07);    { mov [edi], al }
  BinEmitByte($84); BinEmitByte($C0);    { test al, al }
  EmitJZ(LabEnd);
  BinEmitByte($46); BinEmitByte($47);    { inc esi; inc edi }
  BinEmitByte($4B);                      { dec ebx }
  EmitJmp(LabLoop);
  DefineLabel(LabEnd);
  { Terminer par nul pour securite. }
  BinEmitByte($C6); BinEmitByte($07); BinEmitByte($00);
End;

{ --- Strings.Insert(src, pos, dst) : insere src a la position pos
   dans dst.  Decale d'abord la queue vers la droite, puis ecrit src. --- }
Procedure GenStringsInsert;
Var
  SrcSi, DstSi, StrIdx : Integer;
  SrcLit : String;
  IsLit : Boolean;
  LabShiftLoop, LabShiftEnd, LabWriteLoop, LabWriteEnd : String;
Begin
  IsLit := False;
  SrcSi := -1;
  SrcLit := '';
  StrIdx := 0;
  If CurTok = TOK_STRING Then
  Begin
    SrcLit := CurTokStr;
    IsLit := True;
    StrIdx := AddStringLiteral(SrcLit);
    LexNext;
  End
  Else
    SrcSi := ParseArrCharIdent('Strings.Insert (src)');
  ExpectOp(',');
  GenExpression;                         { eax = pos }
  EmitPushEAX;                           { [esp] = pos }
  ExpectOp(',');
  DstSi := ParseArrCharIdent('Strings.Insert (dst)');
  If DstSi <= 0 Then Exit;

  { Calcule srclen d'abord dans ecx. }
  If IsLit Then
  Begin
    BinEmitByte($B9);                    { mov ecx, imm32 (Length(SrcLit)) }
    BinEmitDWord(Length(SrcLit));
  End
  Else
  Begin
    { eax := &src ; call _strlen ; ecx := eax }
    EmitLoadArrAddr(SrcSi);
    BinEmitByte($E8);
    AddFixup(FIX_CODE_REL, FindLabel('_strlen'));
    BinEmitDWord(0);
    BinEmitByte($89); BinEmitByte($C1);  { mov ecx, eax }
  End;

  { Calcule dstlen dans edx. }
  EmitLoadArrAddr(DstSi);
  EmitPushEAX;                           { garde &dst sur pile }
  BinEmitByte($E8);
  AddFixup(FIX_CODE_REL, FindLabel('_strlen'));
  BinEmitDWord(0);
  BinEmitByte($89); BinEmitByte($C2);    { mov edx, eax (dstlen) }

  { Maintenant [esp]=&dst, [esp+4]=pos, ecx=srclen, edx=dstlen. }
  BinEmitByte($5B);                      { pop ebx (=&dst) }
  BinEmitByte($58);                      { pop eax (=pos) }
  { esi := &dst + dstlen (source de la copie arriere) }
  BinEmitByte($89); BinEmitByte($DE);    { mov esi, ebx }
  BinEmitByte($01); BinEmitByte($D6);    { add esi, edx }
  { edi := esi + srclen (dest de la copie arriere) }
  BinEmitByte($89); BinEmitByte($F7);    { mov edi, esi }
  BinEmitByte($01); BinEmitByte($CF);    { add edi, ecx }
  { Clamp edi a &dst + cap-1. }
  BinEmitByte($BA);                      { mov edx, imm32 &dst }
  AddFixup(FIX_VAR, DstSi);
  BinEmitDWord(0);
  BinEmitByte($81); BinEmitByte($C2);    { add edx, imm32 (cap-1) }
  BinEmitDWord(SymTab[DstSi].ArrSize - 1);
  BinEmitByte($39); BinEmitByte($D7);    { cmp edi, edx }
  BinEmitByte($76); BinEmitByte($02);    { jbe +2 }
  BinEmitByte($89); BinEmitByte($D7);    { mov edi, edx }

  { edx := &dst + pos (limite inferieure de la copie arriere) }
  BinEmitByte($89); BinEmitByte($DA);    { mov edx, ebx }
  BinEmitByte($01); BinEmitByte($C2);    { add edx, eax }

  LabShiftLoop := GenLabel;
  LabShiftEnd  := GenLabel;
  DefineLabel(LabShiftLoop);
  { if esi < edx goto end }
  BinEmitByte($39); BinEmitByte($D6);    { cmp esi, edx }
  BinEmitByte($0F); BinEmitByte($82);    { jb LabShiftEnd }
  AddFixup(FIX_CODE_REL, FindLabel(LabShiftEnd));
  BinEmitDWord(0);
  BinEmitByte($8A); BinEmitByte($06);    { mov al, [esi] }
  BinEmitByte($88); BinEmitByte($07);    { mov [edi], al }
  BinEmitByte($4E); BinEmitByte($4F);    { dec esi ; dec edi }
  EmitJmp(LabShiftLoop);
  DefineLabel(LabShiftEnd);

  { Maintenant ecrit src a &dst+pos.  edi := &dst+pos, esi := &src. }
  BinEmitByte($89); BinEmitByte($D7);    { mov edi, edx }
  If IsLit Then
  Begin
    BinEmitByte($BE);
    AddFixup(FIX_STRING, StrIdx);
    BinEmitDWord(0);
  End
  Else If SrcSi > 0 Then
  Begin
    BinEmitByte($BE);
    AddFixup(FIX_VAR, SrcSi);
    BinEmitDWord(0);
  End;
  { edx := &dst + cap-1 (borne haute) ; ecx est deja srclen }
  BinEmitByte($BA);
  AddFixup(FIX_VAR, DstSi);
  BinEmitDWord(0);
  BinEmitByte($81); BinEmitByte($C2);
  BinEmitDWord(SymTab[DstSi].ArrSize - 1);
  LabWriteLoop := GenLabel;
  LabWriteEnd  := GenLabel;
  DefineLabel(LabWriteLoop);
  BinEmitByte($85); BinEmitByte($C9);    { test ecx, ecx }
  EmitJZ(LabWriteEnd);
  BinEmitByte($39); BinEmitByte($D7);    { cmp edi, edx }
  BinEmitByte($73); BinEmitByte($0C);    { jae +12 (vers LabWriteEnd via short jmp) }
  BinEmitByte($8A); BinEmitByte($06);    { mov al, [esi] }
  BinEmitByte($88); BinEmitByte($07);    { mov [edi], al }
  BinEmitByte($46); BinEmitByte($47);    { inc esi ; inc edi }
  BinEmitByte($49);                      { dec ecx }
  EmitJmp(LabWriteLoop);
  DefineLabel(LabWriteEnd);
  { Termine toujours par un nul a &dst + cap-1 (securite). }
  BinEmitByte($C6); BinEmitByte($02); BinEmitByte($00); { mov byte [edx], 0 }
End;

{ --- Conv.IntToString(n, s) : convertit n en decimal dans s. --- }
Procedure GenConvIntToString;
Var
  DstSi : Integer;
Begin
  GenExpression;                         { eax = n }
  EmitPushEAX;
  ExpectOp(',');
  DstSi := ParseArrCharIdent('Conv.IntToString');
  If DstSi <= 0 Then Exit;
  BinEmitByte($58);                      { pop eax (n) }
  BinEmitByte($BF);                      { mov edi, &s }
  AddFixup(FIX_VAR, DstSi);
  BinEmitDWord(0);
  BinEmitByte($B9);                      { mov ecx, cap }
  BinEmitDWord(SymTab[DstSi].ArrSize);
  BinEmitByte($E8);                      { call _inttobuf }
  AddFixup(FIX_CODE_REL, FindLabel('_inttobuf'));
  BinEmitDWord(0);
End;

{ --- Conv.HexToString(n, s) : convertit n en 8 chiffres hexa. --- }
Procedure GenConvHexToString;
Var
  DstSi : Integer;
Begin
  GenExpression;                         { eax = n }
  EmitPushEAX;
  ExpectOp(',');
  DstSi := ParseArrCharIdent('Conv.HexToString');
  If DstSi <= 0 Then Exit;
  BinEmitByte($58);                      { pop eax }
  BinEmitByte($BF);
  AddFixup(FIX_VAR, DstSi);
  BinEmitDWord(0);
  BinEmitByte($B9);
  BinEmitDWord(SymTab[DstSi].ArrSize);
  BinEmitByte($E8);
  AddFixup(FIX_CODE_REL, FindLabel('_hextobuf'));
  BinEmitDWord(0);
End;

{ --- Conv.StringToInt(s, n, done) : parse s comme decimal signe,
   stocke la valeur dans n et 1/0 dans done. --- }
Procedure GenConvStringToInt;
Var
  SrcSi, NSi, DoneSi : Integer;
Begin
  SrcSi := ParseArrCharIdent('Conv.StringToInt (s)');
  If SrcSi <= 0 Then Exit;
  ExpectOp(',');
  NSi := -1; DoneSi := -1;
  If CurTok = TOK_IDENT Then
  Begin
    NSi := SymFind(CurTokStr);
    LexNext;
  End
  Else
    ErrorAt(LexLineNo, LexColNo, 'Conv.StringToInt : identificateur n attendu');
  ExpectOp(',');
  If CurTok = TOK_IDENT Then
  Begin
    DoneSi := SymFind(CurTokStr);
    LexNext;
  End
  Else
    ErrorAt(LexLineNo, LexColNo, 'Conv.StringToInt : identificateur done attendu');
  { esi := &s ; call _strtoint ; eax = val, edx = done }
  BinEmitByte($BE);
  AddFixup(FIX_VAR, SrcSi);
  BinEmitDWord(0);
  BinEmitByte($E8);
  AddFixup(FIX_CODE_REL, FindLabel('_strtoint'));
  BinEmitDWord(0);
  If NSi > 0 Then
  Begin
    BinEmitByte($A3);                    { mov [n], eax }
    AddFixup(FIX_VAR, NSi);
    BinEmitDWord(0);
  End;
  If DoneSi > 0 Then
  Begin
    BinEmitByte($89); BinEmitByte($15);  { mov [done], edx }
    AddFixup(FIX_VAR, DoneSi);
    BinEmitDWord(0);
  End;
End;

{ --- In.Line(s) : lit une ligne dans InBuf puis la copie dans s. --- }
Procedure GenInLine;
Var
  DstSi : Integer;
  LabLoop, LabEnd : String;
Begin
  DstSi := ParseArrCharIdent('In.Line');
  If DstSi <= 0 Then Exit;
  { call _readline }
  BinEmitByte($E8);
  AddFixup(FIX_CODE_REL, FindLabel('_readline'));
  BinEmitDWord(0);
  { Copie InBuf -> &s bornee par cap-1. }
  BinEmitByte($BF);                      { mov edi, &s }
  AddFixup(FIX_VAR, DstSi);
  BinEmitDWord(0);
  BinEmitByte($BE);                      { mov esi, InBuf }
  AddFixup(FIX_INBUF, 0);
  BinEmitDWord(0);
  BinEmitByte($B9);                      { mov ecx, cap - 1 }
  BinEmitDWord(SymTab[DstSi].ArrSize - 1);
  LabLoop := GenLabel;
  LabEnd  := GenLabel;
  DefineLabel(LabLoop);
  BinEmitByte($85); BinEmitByte($C9);    { test ecx, ecx }
  EmitJZ(LabEnd);
  BinEmitByte($8A); BinEmitByte($06);    { mov al, [esi] }
  BinEmitByte($88); BinEmitByte($07);    { mov [edi], al }
  BinEmitByte($84); BinEmitByte($C0);    { test al, al }
  EmitJZ(LabEnd);
  BinEmitByte($46); BinEmitByte($47);    { inc esi; inc edi }
  BinEmitByte($49);
  EmitJmp(LabLoop);
  DefineLabel(LabEnd);
  BinEmitByte($C6); BinEmitByte($07); BinEmitByte($00);
End;

{ --- In.Int(n) : lit une ligne et parse un entier. --- }
Procedure GenInInt;
Var
  NSi : Integer;
Begin
  If CurTok = TOK_IDENT Then
  Begin
    NSi := SymFind(CurTokStr);
    LexNext;
    If NSi <= 0 Then
    Begin
      ErrorAt(LexLineNo, LexColNo, 'In.Int : variable inconnue');
      Exit;
    End;
  End
  Else
  Begin
    ErrorAt(LexLineNo, LexColNo, 'In.Int : identificateur attendu');
    Exit;
  End;
  BinEmitByte($E8);                      { call _readline }
  AddFixup(FIX_CODE_REL, FindLabel('_readline'));
  BinEmitDWord(0);
  BinEmitByte($BE);                      { mov esi, InBuf }
  AddFixup(FIX_INBUF, 0);
  BinEmitDWord(0);
  BinEmitByte($E8);                      { call _strtoint }
  AddFixup(FIX_CODE_REL, FindLabel('_strtoint'));
  BinEmitDWord(0);
  BinEmitByte($A3);                      { mov [n], eax }
  AddFixup(FIX_VAR, NSi);
  BinEmitDWord(0);
  BinEmitByte($89); BinEmitByte($15);    { mov [InDone], edx }
  AddFixup(FIX_INDONE, 0);
  BinEmitDWord(0);
End;

{ --- In.Char(c) : lit 1 octet dans c (variable integer, seul al). --- }
Procedure GenInChar;
Var
  CSi : Integer;
Begin
  If CurTok = TOK_IDENT Then
  Begin
    CSi := SymFind(CurTokStr);
    LexNext;
    If CSi <= 0 Then
    Begin
      ErrorAt(LexLineNo, LexColNo, 'In.Char : variable inconnue');
      Exit;
    End;
  End
  Else
  Begin
    ErrorAt(LexLineNo, LexColNo, 'In.Char : identificateur attendu');
    Exit;
  End;
  { ReadFile(stdin, InBuf, 1, &InLen, 0) }
  EmitPushImm32(0);
  BinEmitByte($68); AddFixup(FIX_INLEN, 0); BinEmitDWord(0);
  EmitPushImm32(1);
  BinEmitByte($68); AddFixup(FIX_INBUF, 0); BinEmitDWord(0);
  BinEmitByte($FF); BinEmitByte($35); AddFixup(FIX_STDIN, 0); BinEmitDWord(0);
  EmitCallIAT(FIX_IAT_READ);
  { InDone := eax (nombre lu vaut 1 sur succes) }
  BinEmitByte($89); BinEmitByte($C2);    { mov edx, eax }
  BinEmitByte($A1); AddFixup(FIX_INLEN, 0); BinEmitDWord(0); { eax := [InLen] }
  BinEmitByte($85); BinEmitByte($C0);    { test eax, eax }
  BinEmitByte($0F); BinEmitByte($95); BinEmitByte($C2);      { setne dl }
  { non utilisable tel quel ; simplifions : [InDone] := 1 si InLen>0, sinon 0 }
  BinEmitByte($0F); BinEmitByte($B6); BinEmitByte($D2);      { movzx edx, dl }
  BinEmitByte($89); BinEmitByte($15); AddFixup(FIX_INDONE, 0); BinEmitDWord(0);
  { Charge octet lu en al, stocke dans [c] (ecrit 4 octets : zero-extend) }
  BinEmitByte($31); BinEmitByte($C0);    { xor eax, eax }
  BinEmitByte($8A); BinEmitByte($05); AddFixup(FIX_INBUF, 0); BinEmitDWord(0); { mov al, [InBuf] }
  BinEmitByte($A3); AddFixup(FIX_VAR, CSi); BinEmitDWord(0);
End;

{ --- Args.Get(i, s) : copie le i-eme argument de GetCommandLineA dans s.
   L'arg 0 est le nom du programme.  Gere les guillemets ("...") simplement. --- }
Procedure GenArgsGet;
Var
  DstSi : Integer;
Begin
  GenExpression;                         { eax = i }
  EmitPushEAX;
  ExpectOp(',');
  DstSi := ParseArrCharIdent('Args.Get');
  If DstSi <= 0 Then Exit;
  BinEmitByte($58);                      { pop eax (i) }
  BinEmitByte($BF);                      { mov edi, &s }
  AddFixup(FIX_VAR, DstSi);
  BinEmitDWord(0);
  BinEmitByte($B9);                      { mov ecx, cap }
  BinEmitDWord(SymTab[DstSi].ArrSize);
  BinEmitByte($E8);
  AddFixup(FIX_CODE_REL, FindLabel('_args_get'));
  BinEmitDWord(0);
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
    If (CurTok = TOK_OP) And (CurTokStr = '[') Then
    Begin
      { Affectation indexee s[i] := expr sur ARRAY OF CHAR. }
      LexNext;
      GenExpression;                      { eax := index }
      EmitPushEAX;
      ExpectOp(']');
      ExpectOp(':=');
      GenExpression;                      { eax := valeur (byte dans al) }
      EmitMovECXEAX;                      { ecx := valeur }
      EmitPopEAX;                         { eax := index }
      If (Si > 0) And (SymTab[Si].TypeIdx = TYK_ARRCHAR) Then
      Begin
        { eax := addr(s) + index  (addr dans edx pour ne pas ecraser eax) }
        BinEmitByte($BA);                 { mov edx, imm32 }
        SymTab[Si].Used := True;
        AddFixup(FIX_VAR, Si);
        BinEmitDWord(0);
        BinEmitByte($01); BinEmitByte($D0);      { add eax, edx }
        { mov [eax], cl  -->  88 08 }
        BinEmitByte($88); BinEmitByte($08);
      End
      Else If Si > 0 Then
        ErrorAt(LexLineNo, LexColNo,
                VarName + ' n''est pas ARRAY OF CHAR')
      Else
        ErrorAt(LexLineNo, LexColNo, 'Variable inconnue: ' + VarName);
    End
    Else If AcceptOp(':=') Then
    Begin
      { Cas 1 : cible ARRAY OF CHAR et source litterale string -> COPY. }
      If (Si > 0) And (SymTab[Si].TypeIdx = TYK_ARRCHAR) And
         (CurTok = TOK_STRING) Then
      Begin
        GenCopyLiteralToArr(CurTokStr, Si);
        LexNext;
      End
      { Cas 2 : cible ARRAY OF CHAR et source = identifiant ARRAY OF CHAR. }
      Else If (Si > 0) And (SymTab[Si].TypeIdx = TYK_ARRCHAR) And
              (CurTok = TOK_IDENT) And
              (SymFind(CurTokStr) > 0) And
              (SymTab[SymFind(CurTokStr)].TypeIdx = TYK_ARRCHAR) Then
      Begin
        GenCopyArrToArr(SymFind(CurTokStr), Si);
        LexNext;
      End
      { Cas 3 : cible REAL -> evaluation FPU puis fstp. }
      Else If (Si > 0) And (SymTab[Si].TypeIdx = TYK_REAL) Then
      Begin
        GenRealExpression;
        SymTab[Si].Used := True;
        EmitFSTP_Real_At(FIX_VAR, Si);
      End
      Else
      Begin
        GenExpression;
        If Si > 0 Then
        Begin
          EmitMovMem32EAX($400000 + $2000 + SymTab[Si].DataOffs);
          BinCodeLen := BinCodeLen - 4;
          AddFixup(FIX_VAR, Si);
          BinCodeLen := BinCodeLen + 4;
        End;
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
          End
          Else If CurTok = TOK_IDENT Then
          Begin
            Si := SymFind(CurTokStr);
            If (Si > 0) And (SymTab[Si].TypeIdx = TYK_ARRCHAR) Then
            Begin
              GenWriteArrSym(Si, FIX_STDOUT);
              LexNext;
            End
            Else
              ErrorAt(LexLineNo, LexColNo,
                      'Out.String : chaine litterale ou ARRAY OF CHAR attendu');
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
      End
      Else If VarName = 'Out.Char' Then
      Begin
        If AcceptOp('(') Then
        Begin
          GenOutChar;
          ExpectOp(')');
        End;
      End
      Else If VarName = 'Out.Hex' Then
      Begin
        If AcceptOp('(') Then
        Begin
          GenOutHex;
          ExpectOp(')');
        End;
      End
      Else If (VarName = 'Out.Real') Or (VarName = 'Out.LongReal') Then
      Begin
        { Out.Real(r) ou Out.Real(r, w). Le parametre de largeur w est
          accepte mais ignore (le format est fixe : "%f" 6 decimales). }
        If AcceptOp('(') Then
        Begin
          GenRealExpression;
          { fstp dword [real_tmp] ; call _print_real }
          EmitFSTP_Real_At(FIX_REAL_TMP, 0);
          BinEmitByte($E8);
          AddFixup(FIX_CODE_REL, FindLabel('_print_real'));
          BinEmitDWord(0);
          If AcceptOp(',') Then
            GenExpression;   { largeur eventuellement ignoree }
          ExpectOp(')');
        End;
      End
      Else If VarName = 'Err.String' Then
      Begin
        If AcceptOp('(') Then
        Begin
          If CurTok = TOK_STRING Then
          Begin
            GenErrString(CurTokStr);
            LexNext;
          End
          Else If CurTok = TOK_IDENT Then
          Begin
            Si := SymFind(CurTokStr);
            If (Si > 0) And (SymTab[Si].TypeIdx = TYK_ARRCHAR) Then
            Begin
              GenWriteArrSym(Si, FIX_STDERR);
              LexNext;
            End
            Else
              ErrorAt(LexLineNo, LexColNo,
                      'Err.String : chaine litterale ou ARRAY OF CHAR attendu');
          End;
          ExpectOp(')');
        End;
      End
      Else If VarName = 'Err.Ln' Then
        GenErrLn
      Else If VarName = 'Err.Int' Then
      Begin
        If AcceptOp('(') Then
        Begin
          GenErrInt;
          If AcceptOp(',') Then
            GenExpression;
          ExpectOp(')');
        End;
      End
      Else If VarName = 'Timer.Sleep' Then
      Begin
        If AcceptOp('(') Then
        Begin
          GenExpression;
          EmitPushEAX;
          EmitCallIAT(FIX_IAT_SLEEP);
          ExpectOp(')');
        End;
      End
      Else If VarName = 'Random.Init' Then
      Begin
        If AcceptOp('(') Then
        Begin
          GenExpression;
          { mov [rnd_seed], eax }
          BinEmitByte($A3);
          AddFixup(FIX_RNDSEED, 0);
          BinEmitDWord(0);
          ExpectOp(')');
        End;
      End

      { --- Palier 4 : instructions Files/Heap/DynLink --- }
      Else If VarName = 'Files.Close' Then
      Begin
        If AcceptOp('(') Then
        Begin
          GenExpression;         { eax = h }
          EmitPushEAX;           { arg = hObject }
          EmitCallIAT(FIX_IAT_CLOSEHANDLE);
          ExpectOp(')');
        End;
      End
      Else If VarName = 'Files.Seek' Then
      Begin
        { Files.Seek(h, pos) : positionne depuis le debut. }
        If AcceptOp('(') Then
        Begin
          GenExpression;             { eax = h }
          BinEmitByte($89); BinEmitByte($C3);  { mov ebx, eax }
          ExpectOp(',');
          GenExpression;             { eax = pos }
          EmitPushImm32(0);          { FILE_BEGIN = 0 }
          EmitPushImm32(0);          { lpDistanceToMoveHigh = NULL }
          EmitPushEAX;               { lDistanceToMove = pos }
          BinEmitByte($53);          { push ebx (hFile) }
          EmitCallIAT(FIX_IAT_SETFILEPTR);
          ExpectOp(')');
        End;
      End
      Else If VarName = 'Heap.Free' Then
      Begin
        { Heap.Free(addr) -> HeapFree(GetProcessHeap(), 0, addr). }
        If AcceptOp('(') Then
        Begin
          GenExpression;            { eax = addr }
          EmitPushEAX;              { arg3 = lpMem }
          EmitPushImm32(0);         { arg2 = dwFlags }
          EmitCallIAT(FIX_IAT_GETPROCHEAP);
          EmitPushEAX;              { arg1 = hHeap }
          EmitCallIAT(FIX_IAT_HEAPFREE);
          ExpectOp(')');
        End;
      End
      Else If VarName = 'DynLink.Free' Then
      Begin
        If AcceptOp('(') Then
        Begin
          GenExpression;            { eax = hModule }
          EmitPushEAX;
          EmitCallIAT(FIX_IAT_FREELIB);
          ExpectOp(')');
        End;
      End

      { --- Palier 5 : instructions Coroutines --- }
      Else If VarName = 'Coroutines.Switch' Then
      Begin
        If AcceptOp('(') Then
        Begin
          GenExpression;            { eax = fiber }
          EmitPushEAX;
          EmitCallIAT(FIX_IAT_SWITCHFIBER);
          ExpectOp(')');
        End;
      End
      Else If VarName = 'Coroutines.Delete' Then
      Begin
        If AcceptOp('(') Then
        Begin
          GenExpression;            { eax = fiber }
          EmitPushEAX;
          EmitCallIAT(FIX_IAT_DELETEFIBER);
          ExpectOp(')');
        End;
      End
      Else If VarName = 'SYSTEM.PUT' Then
      Begin
        If AcceptOp('(') Then
        Begin
          GenExpression;      { eax = addr }
          EmitPushEAX;
          ExpectOp(',');
          GenExpression;      { eax = val }
          EmitMovECXEAX;      { ecx = val }
          EmitPopEAX;         { eax = addr }
          { mov [eax], ecx  --> 89 08 }
          BinEmitByte($89); BinEmitByte($08);
          ExpectOp(')');
        End;
      End
      Else If VarName = 'SYSTEM.GET' Then
      Begin
        { Forme instruction : GET(addr, VAR v).  Stocke mem[addr]
          dans la variable v. }
        If AcceptOp('(') Then
        Begin
          GenExpression;      { eax = addr }
          { eax := [eax] }
          BinEmitByte($8B); BinEmitByte($00);
          If AcceptOp(',') Then
          Begin
            If CurTok = TOK_IDENT Then
            Begin
              Si := SymFind(CurTokStr);
              LexNext;
              If Si > 0 Then
              Begin
                EmitMovMem32EAX(0);
                BinCodeLen := BinCodeLen - 4;
                AddFixup(FIX_VAR, Si);
                BinCodeLen := BinCodeLen + 4;
              End;
            End;
          End;
          ExpectOp(')');
        End;
      End

      { -------- Strings.* -------- }
      Else If (VarName = 'Strings.Copy') Or (VarName = 'Strings.COPY') Then
      Begin
        If AcceptOp('(') Then
        Begin
          If CurTok = TOK_STRING Then
          Begin
            VarName := CurTokStr;
            LexNext;
            ExpectOp(',');
            If CurTok = TOK_IDENT Then
            Begin
              Si := SymFind(CurTokStr);
              If (Si > 0) And (SymTab[Si].TypeIdx = TYK_ARRCHAR) Then
                GenCopyLiteralToArr(VarName, Si)
              Else
                ErrorAt(LexLineNo, LexColNo, 'Strings.Copy : destination ARRAY OF CHAR attendue');
              LexNext;
            End;
          End
          Else If CurTok = TOK_IDENT Then
          Begin
            LoopVarSi := SymFind(CurTokStr);
            LexNext;
            ExpectOp(',');
            If CurTok = TOK_IDENT Then
            Begin
              Si := SymFind(CurTokStr);
              If (LoopVarSi > 0) And (Si > 0) And
                 (SymTab[LoopVarSi].TypeIdx = TYK_ARRCHAR) And
                 (SymTab[Si].TypeIdx = TYK_ARRCHAR) Then
                GenCopyArrToArr(LoopVarSi, Si)
              Else
                ErrorAt(LexLineNo, LexColNo, 'Strings.Copy : ARRAY OF CHAR attendus');
              LexNext;
            End;
          End;
          ExpectOp(')');
        End;
      End
      Else If VarName = 'Strings.Append' Then
      Begin
        If AcceptOp('(') Then
        Begin
          If CurTok = TOK_STRING Then
          Begin
            VarName := CurTokStr;
            LexNext;
            ExpectOp(',');
            If CurTok = TOK_IDENT Then
            Begin
              Si := SymFind(CurTokStr);
              If (Si > 0) And (SymTab[Si].TypeIdx = TYK_ARRCHAR) Then
                GenAppendLiteralToArr(VarName, Si)
              Else
                ErrorAt(LexLineNo, LexColNo, 'Strings.Append : destination ARRAY OF CHAR attendue');
              LexNext;
            End;
          End
          Else If CurTok = TOK_IDENT Then
          Begin
            LoopVarSi := SymFind(CurTokStr);
            LexNext;
            ExpectOp(',');
            If CurTok = TOK_IDENT Then
            Begin
              Si := SymFind(CurTokStr);
              If (LoopVarSi > 0) And (Si > 0) And
                 (SymTab[LoopVarSi].TypeIdx = TYK_ARRCHAR) And
                 (SymTab[Si].TypeIdx = TYK_ARRCHAR) Then
                GenAppendArrToArr(LoopVarSi, Si)
              Else
                ErrorAt(LexLineNo, LexColNo, 'Strings.Append : ARRAY OF CHAR attendus');
              LexNext;
            End;
          End;
          ExpectOp(')');
        End;
      End
      Else If VarName = 'Strings.Cap' Then
      Begin
        If AcceptOp('(') Then
        Begin
          If CurTok = TOK_IDENT Then
          Begin
            Si := SymFind(CurTokStr);
            If (Si > 0) And (SymTab[Si].TypeIdx = TYK_ARRCHAR) Then
            Begin
              SymTab[Si].Used := True;
              { eax := &s ; ecx := cap ; call _cap_helper }
              BinEmitByte($B8);
              AddFixup(FIX_VAR, Si);
              BinEmitDWord(0);
              BinEmitByte($B9); BinEmitDWord(SymTab[Si].ArrSize);
              BinEmitByte($E8);
              AddFixup(FIX_CODE_REL, FindLabel('_strcap'));
              BinEmitDWord(0);
              LexNext;
            End
            Else
              ErrorAt(LexLineNo, LexColNo, 'Strings.Cap : ARRAY OF CHAR attendu');
          End;
          ExpectOp(')');
        End;
      End
      Else If VarName = 'Strings.Insert' Then
      Begin
        { Strings.Insert(src, pos, dst) : src literal ou ARRCHAR,
          pos entier, dst ARRCHAR. }
        If AcceptOp('(') Then
        Begin
          GenStringsInsert;
          ExpectOp(')');
        End;
      End
      Else If VarName = 'Strings.Delete' Then
      Begin
        { Strings.Delete(s, pos, n) : supprime n chars a partir de pos. }
        If AcceptOp('(') Then
        Begin
          GenStringsDelete;
          ExpectOp(')');
        End;
      End
      Else If VarName = 'Strings.Replace' Then
      Begin
        { Strings.Replace(src, pos, dst) : ecrit src dans dst a partir de pos. }
        If AcceptOp('(') Then
        Begin
          GenStringsReplace;
          ExpectOp(')');
        End;
      End

      { -------- Conv.* -------- }
      Else If VarName = 'Conv.IntToString' Then
      Begin
        If AcceptOp('(') Then
        Begin
          GenConvIntToString;
          ExpectOp(')');
        End;
      End
      Else If VarName = 'Conv.StringToInt' Then
      Begin
        If AcceptOp('(') Then
        Begin
          GenConvStringToInt;
          ExpectOp(')');
        End;
      End
      Else If VarName = 'Conv.HexToString' Then
      Begin
        If AcceptOp('(') Then
        Begin
          GenConvHexToString;
          ExpectOp(')');
        End;
      End

      { -------- In.* -------- }
      Else If VarName = 'In.Line' Then
      Begin
        If AcceptOp('(') Then
        Begin
          GenInLine;
          ExpectOp(')');
        End;
      End
      Else If VarName = 'In.String' Then
      Begin
        If AcceptOp('(') Then
        Begin
          GenInLine;
          ExpectOp(')');
        End;
      End
      Else If VarName = 'In.Int' Then
      Begin
        If AcceptOp('(') Then
        Begin
          GenInInt;
          ExpectOp(')');
        End;
      End
      Else If VarName = 'In.Char' Then
      Begin
        If AcceptOp('(') Then
        Begin
          GenInChar;
          ExpectOp(')');
        End;
      End

      { -------- Args.Get -------- }
      Else If VarName = 'Args.Get' Then
      Begin
        If AcceptOp('(') Then
        Begin
          GenArgsGet;
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
                { add dword ptr [addr], imm  -->  83 05 addr imm8
                                              ou 81 05 addr imm32 }
                BinEmitByte($83);
                BinEmitByte($05);
                AddFixup(FIX_VAR, Si);
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
                { sub dword ptr [addr], imm8  -->  83 2D addr imm8 }
                BinEmitByte($83);
                BinEmitByte($2D);
                AddFixup(FIX_VAR, Si);
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
      End
      Else If VarName = 'HALT' Then
      Begin
        { HALT(n) : appelle ExitProcess avec n comme code de sortie. }
        If (CurTok = TOK_OP) And (CurTokStr = ')') Then
          EmitPushImm32(0)
        Else
        Begin
          GenExpression;
          EmitPushEAX;
        End;
        EmitCallIAT(FIX_IAT_EXIT);
        ExpectOp(')');
      End
      Else If VarName = 'COPY' Then
      Begin
        { COPY(src, dst) : src est une chaine litterale ou un identifiant
          ARRAY OF CHAR, dst est un identifiant ARRAY OF CHAR. }
        If CurTok = TOK_STRING Then
        Begin
          VarName := CurTokStr;
          LexNext;
          ExpectOp(',');
          If CurTok = TOK_IDENT Then
          Begin
            Si := SymFind(CurTokStr);
            If (Si > 0) And (SymTab[Si].TypeIdx = TYK_ARRCHAR) Then
              GenCopyLiteralToArr(VarName, Si)
            Else
              ErrorAt(LexLineNo, LexColNo, 'COPY: destination ARRAY OF CHAR attendue');
            LexNext;
          End
          Else
            ErrorAt(LexLineNo, LexColNo, 'COPY: destination attendue');
        End
        Else If CurTok = TOK_IDENT Then
        Begin
          LoopVarSi := SymFind(CurTokStr);
          LexNext;
          ExpectOp(',');
          If CurTok = TOK_IDENT Then
          Begin
            Si := SymFind(CurTokStr);
            If (LoopVarSi > 0) And (Si > 0) And
               (SymTab[LoopVarSi].TypeIdx = TYK_ARRCHAR) And
               (SymTab[Si].TypeIdx = TYK_ARRCHAR) Then
              GenCopyArrToArr(LoopVarSi, Si)
            Else
              ErrorAt(LexLineNo, LexColNo, 'COPY: ARRAY OF CHAR attendus');
            LexNext;
          End
          Else
            ErrorAt(LexLineNo, LexColNo, 'COPY: destination attendue');
        End
        Else
          ErrorAt(LexLineNo, LexColNo, 'COPY: source attendue');
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
  End

  Else If (CurTok = TOK_KEYWORD) And (CurTokKw = KW_LOOP) Then
  Begin
    LexNext;
    Lab1 := GenLabel;   { debut de boucle }
    Lab2 := GenLabel;   { sortie EXIT }
    DefineLabel(Lab1);
    Inc(ExitLabelTop);
    If ExitLabelTop > 32 Then
      ErrorAt(LexLineNo, LexColNo, 'LOOP imbriques trop profondement');
    ExitLabels[ExitLabelTop] := Lab2;
    GenStatSeq;
    Dec(ExitLabelTop);
    EmitJmp(Lab1);
    DefineLabel(Lab2);
    Expect(KW_END);
  End

  Else If (CurTok = TOK_KEYWORD) And (CurTokKw = KW_EXIT) Then
  Begin
    LexNext;
    If ExitLabelTop <= 0 Then
      ErrorAt(LexLineNo, LexColNo, 'EXIT en dehors d''un LOOP')
    Else
      EmitJmp(ExitLabels[ExitLabelTop]);
  End

  Else If (CurTok = TOK_KEYWORD) And (CurTokKw = KW_CASE) Then
  Begin
    LexNext;
    GenExpression;
    Expect(KW_OF);
    { Sauvegarde la valeur sur la pile : push eax }
    BinEmitByte($50);
    Lab3 := GenLabel;   { etiquette de fin (EndCase) }
    Lab4 := GenLabel;   { etiquette "saut vers ELSE ou sortie" apres tests }
    Lab2 := Lab4;       { Lab2 sera le "prochain test" pour l'alternative en cours }
    { Parse chaque alternative : littereaux puis stmts, separees par | }
    If (CurTok = TOK_INT) Or (CurTok = TOK_STRING) Then
    Begin
      While True Do
      Begin
        Lab1 := GenLabel;   { corps de cette alternative }
        { Emet les comparaisons : pour chaque litteral, cmp + je Lab1 }
        While (CurTok = TOK_INT) Or (CurTok = TOK_STRING) Do
        Begin
          If CurTok = TOK_INT Then
          Begin
            EmitMovEAXStackTop;
            EmitCmpEAXImm(CurTokNum);
            EmitJE(Lab1);
            LexNext;
          End
          Else
          Begin
            { chaine de 1 caractere : on compare par valeur ASCII }
            If Length(CurTokStr) >= 1 Then
            Begin
              EmitMovEAXStackTop;
              EmitCmpEAXImm(Ord(CurTokStr[1]));
              EmitJE(Lab1);
            End;
            LexNext;
          End;
          If AcceptOp(',') Then
            Continue
          Else
            Break;
        End;
        ExpectOp(':');
        { Pas de correspondance pour cette alternative : saute au test suivant }
        EmitJmp(Lab2);
        { Corps de l'alternative : pop valeur saved ; stmts ; jmp EndCase }
        DefineLabel(Lab1);
        EmitAddESP4;
        GenStatSeq;
        EmitJmp(Lab3);
        { Prepare le label du test suivant }
        DefineLabel(Lab2);
        { Separateur d'alternatives '|' ? }
        If (CurTok = TOK_OP) And (CurTokStr = '|') Then
        Begin
          LexNext;
          Lab2 := GenLabel;
          Continue;
        End
        Else
          Break;
      End;
    End;
    { Partie ELSE ou sortie : on arrive ici sans match }
    EmitAddESP4;
    If Accept(KW_ELSE) Then
      GenStatSeq;
    DefineLabel(Lab3);
    Expect(KW_END);
  End;
End;

Procedure GenPrintIntHelper;
Var
  LabZero, LabLoop, LabPos, LabNoMinus, LabWrite : String;
  LabZero2, LabLoop2, LabPos2, LabNoMinus2, LabWrite2 : String;
  LabHexLoop : String;
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

  { ----------------------------------------------------------------
    _printint_err : identique a _printint mais ecrit sur stderr. }
  DefineLabel('_printint_err');

  BinEmitByte($53);                        { push ebx }
  BinEmitByte($56);                        { push esi }
  BinEmitByte($57);                        { push edi }
  BinEmitByte($55);                        { push ebp }

  BinEmitByte($8B); BinEmitByte($44); BinEmitByte($24); BinEmitByte($14);

  LabZero2    := GenLabel;
  LabLoop2    := GenLabel;
  LabPos2     := GenLabel;
  LabNoMinus2 := GenLabel;
  LabWrite2   := GenLabel;

  EmitTestEAX;
  EmitJZ(LabZero2);

  BinEmitByte($31); BinEmitByte($ED);
  EmitTestEAX;
  BinEmitByte($0F); BinEmitByte($89);
  AddFixup(FIX_CODE_REL, FindLabel(LabPos2));
  BinEmitDWord(0);
  BinEmitByte($F7); BinEmitByte($D8);
  BinEmitByte($BD); BinEmitDWord(1);
  DefineLabel(LabPos2);

  BinEmitByte($BF);
  AddFixup(FIX_INTBUF_END, 0);
  BinEmitDWord(0);

  BinEmitByte($BB); BinEmitDWord(10);

  DefineLabel(LabLoop2);
  BinEmitByte($31); BinEmitByte($D2);
  BinEmitByte($F7); BinEmitByte($F3);
  BinEmitByte($80); BinEmitByte($C2); BinEmitByte($30);
  BinEmitByte($4F);
  BinEmitByte($88); BinEmitByte($17);
  EmitTestEAX;
  EmitJNZ(LabLoop2);

  BinEmitByte($85); BinEmitByte($ED);
  EmitJZ(LabNoMinus2);
  BinEmitByte($4F);
  BinEmitByte($C6); BinEmitByte($07); BinEmitByte($2D);
  DefineLabel(LabNoMinus2);

  BinEmitByte($BE);
  AddFixup(FIX_INTBUF_END, 0);
  BinEmitDWord(0);
  BinEmitByte($29); BinEmitByte($FE);
  EmitJmp(LabWrite2);

  DefineLabel(LabZero2);
  BinEmitByte($BF);
  AddFixup(FIX_INTBUF, 0);
  BinEmitDWord(0);
  BinEmitByte($C6); BinEmitByte($07); BinEmitByte($30);
  BinEmitByte($BE); BinEmitDWord(1);

  DefineLabel(LabWrite2);
  BinEmitByte($6A); BinEmitByte($00);

  BinEmitByte($68);
  AddFixup(FIX_BYTES_WRITTEN, 0);
  BinEmitDWord(0);

  BinEmitByte($56);
  BinEmitByte($57);

  BinEmitByte($FF); BinEmitByte($35);
  AddFixup(FIX_STDERR, 0);
  BinEmitDWord(0);

  EmitCallIAT(FIX_IAT_WRITE);

  BinEmitByte($5D);
  BinEmitByte($5F);
  BinEmitByte($5E);
  BinEmitByte($5B);
  BinEmitByte($C2); BinEmitWord(4);

  { ----------------------------------------------------------------
    _printhex : ecrit EAX (non signe) sur stdout en hexadecimal
    (8 chiffres, format '%08X'). }
  DefineLabel('_printhex');

  BinEmitByte($53);                        { push ebx }
  BinEmitByte($56);                        { push esi }
  BinEmitByte($57);                        { push edi }

  { eax = value from [esp + 16] (3 saved regs + ret addr) }
  BinEmitByte($8B); BinEmitByte($44); BinEmitByte($24); BinEmitByte($10);

  { edi := HexBufEnd (pointeur d'ecriture, digits stockes a l'envers) }
  BinEmitByte($BF);
  AddFixup(FIX_HEXBUF_END, 0);
  BinEmitDWord(0);

  { ecx := 8 (nombre de digits) }
  BinEmitByte($B9); BinEmitDWord(8);

  LabHexLoop := GenLabel;
  DefineLabel(LabHexLoop);

  { edx := eax & 0xF }
  BinEmitByte($89); BinEmitByte($C2);      { mov edx, eax }
  BinEmitByte($83); BinEmitByte($E2); BinEmitByte($0F);  { and edx, 0Fh }

  { si edx < 10 : dl := dl + '0' ; sinon dl := dl - 10 + 'A' }
  BinEmitByte($80); BinEmitByte($FA); BinEmitByte($0A);  { cmp dl, 0Ah }
  BinEmitByte($7C); BinEmitByte($05);      { jl +5 }
  BinEmitByte($80); BinEmitByte($C2); BinEmitByte($37);  { add dl, 55 (=>'A'-10) }
  BinEmitByte($EB); BinEmitByte($03);      { jmp +3 }
  BinEmitByte($80); BinEmitByte($C2); BinEmitByte($30);  { add dl, '0' }

  BinEmitByte($4F);                        { dec edi }
  BinEmitByte($88); BinEmitByte($17);      { mov [edi], dl }

  { eax := eax >> 4 (non signe) }
  BinEmitByte($C1); BinEmitByte($E8); BinEmitByte($04);  { shr eax, 4 }

  BinEmitByte($49);                        { dec ecx }
  { jnz LabHexLoop en forme rel32 (0F 85 rel32) via fixup. }
  BinEmitByte($0F); BinEmitByte($85);
  AddFixup(FIX_CODE_REL, FindLabel(LabHexLoop));
  BinEmitDWord(0);

  { WriteFile(stdout, edi (=HexBuf), 8, &bytes_written, NULL) }
  BinEmitByte($6A); BinEmitByte($00);      { push 0 }
  BinEmitByte($68);
  AddFixup(FIX_BYTES_WRITTEN, 0);
  BinEmitDWord(0);
  BinEmitByte($6A); BinEmitByte($08);      { push 8 (length) }
  BinEmitByte($57);                        { push edi (buffer) }
  BinEmitByte($FF); BinEmitByte($35);
  AddFixup(FIX_STDOUT, 0);
  BinEmitDWord(0);

  EmitCallIAT(FIX_IAT_WRITE);

  BinEmitByte($5F);                        { pop edi }
  BinEmitByte($5E);                        { pop esi }
  BinEmitByte($5B);                        { pop ebx }
  BinEmitByte($C2); BinEmitWord(4);        { ret 4 }
End;

Procedure GenArgsCountHelper;
Var LabLoop, LabChkEnd, LabWasSpace, LabSpace, LabDone : String;
Begin
  DefineLabel('_args_count');

  { Preserve ebx, esi, edi }
  BinEmitByte($53);
  BinEmitByte($56);
  BinEmitByte($57);

  { eax := GetCommandLineA() ; retour = pointeur vers ligne de commande }
  EmitCallIAT(FIX_IAT_GETCMD);

  { esi := eax (pointeur courant) }
  BinEmitByte($89); BinEmitByte($C6);                { mov esi, eax }

  { ecx := 0 (compteur d'arguments), edi := 1 (etat : 1=dans un blanc),
    ebx := 0 (in_quote 0/nz). }
  BinEmitByte($31); BinEmitByte($C9);                { xor ecx, ecx }
  BinEmitByte($BF); BinEmitDWord(1);                 { mov edi, 1 }
  BinEmitByte($31); BinEmitByte($DB);                { xor ebx, ebx }

  LabLoop     := GenLabel;
  LabChkEnd   := GenLabel;
  LabWasSpace := GenLabel;
  LabSpace    := GenLabel;
  LabDone     := GenLabel;

  DefineLabel(LabLoop);
  BinEmitByte($0F); BinEmitByte($B6); BinEmitByte($06);     { movzx eax, byte [esi] }
  BinEmitByte($85); BinEmitByte($C0);                        { test eax, eax }
  EmitJZ(LabDone);
  { Toggle in_quote sur le caractere '"'. }
  BinEmitByte($83); BinEmitByte($F8); BinEmitByte($22);      { cmp eax, '"' }
  BinEmitByte($0F); BinEmitByte($85);                        { jne rel32 _args_count_nq }
  AddFixup(FIX_CODE_REL, FindLabel('_args_count_nq'));
  BinEmitDWord(0);
  BinEmitByte($F7); BinEmitByte($D3);                        { not ebx }
  EmitJmp(LabChkEnd);
  DefineLabel('_args_count_nq');
  { Si on est entre guillemets, on ne considere pas les blancs. }
  BinEmitByte($85); BinEmitByte($DB);                        { test ebx, ebx }
  BinEmitByte($0F); BinEmitByte($85);                        { jne rel32 _args_count_nw }
  AddFixup(FIX_CODE_REL, FindLabel('_args_count_nw'));
  BinEmitDWord(0);
  { Teste si al == ' ' ou '\t' }
  BinEmitByte($83); BinEmitByte($F8); BinEmitByte($20);      { cmp eax, ' ' }
  EmitJE(LabSpace);
  BinEmitByte($83); BinEmitByte($F8); BinEmitByte($09);      { cmp eax, 9 }
  EmitJE(LabSpace);
  DefineLabel('_args_count_nw');
  { Non-blanc : si etat precedent etait blanc, nouveau mot. }
  BinEmitByte($85); BinEmitByte($FF);                        { test edi, edi }
  EmitJZ(LabChkEnd);
  BinEmitByte($41);                                          { inc ecx }
  BinEmitByte($31); BinEmitByte($FF);                        { xor edi, edi (etat = dans un mot) }
  EmitJmp(LabChkEnd);

  DefineLabel(LabSpace);
  BinEmitByte($BF); BinEmitDWord(1);                         { mov edi, 1 (etat = blanc) }

  DefineLabel(LabChkEnd);
  BinEmitByte($46);                                          { inc esi }
  EmitJmp(LabLoop);

  DefineLabel(LabDone);
  BinEmitByte($89); BinEmitByte($C8);                        { mov eax, ecx }

  BinEmitByte($5F);                                          { pop edi }
  BinEmitByte($5E);                                          { pop esi }
  BinEmitByte($5B);                                          { pop ebx }
  BinEmitByte($C3);                                          { ret }
End;

{ --- _readline : lit une ligne depuis stdin dans le tampon global InBuf
   (256 octets).  Consomme les octets jusqu'a '\n' ou EOF en appelant
   ReadFile 1 octet a la fois sur le handle stdin.  Ecrit la longueur
   effective (sans CR/LF) dans InLen et 1/0 dans InDone.  Ne touche
   pas a ebp ; preserve ebx, esi, edi. --- }
Procedure GenReadLineHelper;
Var
  LabLoop, LabStoreStop, LabDone, LabCRLF, LabNoCR : String;
Begin
  DefineLabel('_readline');
  BinEmitByte($53);                                { push ebx }
  BinEmitByte($56);                                { push esi }
  BinEmitByte($57);                                { push edi }

  { edi := InBuf }
  BinEmitByte($BF);
  AddFixup(FIX_INBUF, 0);
  BinEmitDWord(0);
  { ebx := 0 (nombre d'octets stockes), esi := 0 (termine / EOF flag) }
  BinEmitByte($31); BinEmitByte($DB);
  BinEmitByte($31); BinEmitByte($F6);

  LabLoop      := GenLabel;
  LabStoreStop := GenLabel;
  LabDone      := GenLabel;
  LabCRLF      := GenLabel;
  LabNoCR      := GenLabel;

  DefineLabel(LabLoop);
  { Limite : 255 octets max pour laisser place au nul. }
  BinEmitByte($81); BinEmitByte($FB);              { cmp ebx, 255 }
  BinEmitDWord(255);
  EmitJGE(LabDone);

  { ReadFile(stdin, InBuf+ebx, 1, &InLen, 0) }
  EmitPushImm32(0);
  BinEmitByte($68);
  AddFixup(FIX_INLEN, 0);
  BinEmitDWord(0);
  EmitPushImm32(1);
  { push (InBuf + ebx) -> lea eax, [edi+ebx] ; push eax }
  BinEmitByte($8D); BinEmitByte($04); BinEmitByte($1F);
  BinEmitByte($50);
  BinEmitByte($FF); BinEmitByte($35);
  AddFixup(FIX_STDIN, 0);
  BinEmitDWord(0);
  EmitCallIAT(FIX_IAT_READ);

  { eax = 1 si succes, 0 si echec. Si echec -> EOF. }
  EmitTestEAX;
  EmitJZ(LabDone);
  { Lire combien d'octets ont ete lus depuis InLen. }
  BinEmitByte($A1);                                { mov eax, [InLen] }
  AddFixup(FIX_INLEN, 0);
  BinEmitDWord(0);
  EmitTestEAX;
  EmitJZ(LabDone);

  { al := byte lu : test contre 0x0A (LF) }
  BinEmitByte($8A); BinEmitByte($04); BinEmitByte($1F);  { mov al, [edi+ebx] }
  BinEmitByte($3C); BinEmitByte($0A);              { cmp al, 0Ah }
  EmitJE(LabCRLF);
  { Sinon incremente ebx et boucle. }
  BinEmitByte($43);                                { inc ebx }
  EmitJmp(LabLoop);

  DefineLabel(LabCRLF);
  { Ligne terminee.  Si l'octet precedent etait CR (0x0D), le retirer. }
  BinEmitByte($85); BinEmitByte($DB);              { test ebx, ebx }
  EmitJZ(LabNoCR);
  { mov al, [edi+ebx-1] }
  BinEmitByte($8A); BinEmitByte($44); BinEmitByte($1F); BinEmitByte($FF);
  BinEmitByte($3C); BinEmitByte($0D);              { cmp al, 0Dh }
  EmitJNE(LabNoCR);
  BinEmitByte($4B);                                { dec ebx }
  DefineLabel(LabNoCR);
  { esi := 1 (succes) }
  BinEmitByte($BE); BinEmitDWord(1);
  EmitJmp(LabStoreStop);

  DefineLabel(LabDone);
  { EOF ou buffer plein : on marque done en fonction de ebx.
    (esi reste a 0 si on est arrive ici sans rien lire, sinon on le
     laisse a 0 aussi par simplicite ; le caller peut tester InLen.)
    On rebascule simplement la logique : si ebx > 0, on marque done. }
  BinEmitByte($85); BinEmitByte($DB);              { test ebx, ebx }
  EmitJZ(LabStoreStop);
  BinEmitByte($BE); BinEmitDWord(1);               { mov esi, 1 }

  DefineLabel(LabStoreStop);
  { Nul terminator en fin : mov byte [edi+ebx], 0 }
  BinEmitByte($C6); BinEmitByte($04); BinEmitByte($1F); BinEmitByte($00);
  { InLen := ebx }
  BinEmitByte($89); BinEmitByte($1D);              { mov [InLen], ebx }
  AddFixup(FIX_INLEN, 0);
  BinEmitDWord(0);
  { InDone := esi }
  BinEmitByte($89); BinEmitByte($35);              { mov [InDone], esi }
  AddFixup(FIX_INDONE, 0);
  BinEmitDWord(0);

  BinEmitByte($5F);                                { pop edi }
  BinEmitByte($5E);                                { pop esi }
  BinEmitByte($5B);                                { pop ebx }
  BinEmitByte($C3);                                { ret }
End;

{ --- _strlen : eax = addr(zstring) -> eax = longueur.  Stoppe au
   premier octet nul.  Ne touche pas a ecx/edx. --- }
Procedure GenStrLenHelper;
Var
  LabLoop, LabDone : String;
Begin
  DefineLabel('_strlen');
  BinEmitByte($53);                        { push ebx }
  BinEmitByte($89); BinEmitByte($C3);      { mov ebx, eax }
  BinEmitByte($89); BinEmitByte($C2);      { mov edx, eax }
  LabLoop := GenLabel;
  LabDone := GenLabel;
  DefineLabel(LabLoop);
  { cmp byte [ebx], 0 ; je LabDone ; inc ebx ; jmp LabLoop }
  BinEmitByte($80); BinEmitByte($3B); BinEmitByte($00);
  EmitJE(LabDone);
  BinEmitByte($43);
  EmitJmp(LabLoop);
  DefineLabel(LabDone);
  { eax := ebx - edx }
  BinEmitByte($89); BinEmitByte($D8);      { mov eax, ebx }
  BinEmitByte($29); BinEmitByte($D0);      { sub eax, edx }
  BinEmitByte($5B);                        { pop ebx }
  BinEmitByte($C3);                        { ret }
End;

{ --- _str_pos(pat, s, start) -> eax : index de la premiere occurrence
   de pat dans s a partir de start, ou -1 si absent.  Implementation
   naive.  Arguments sur la pile (cdecl-like, nettoyes par l'appelant). --- }
Procedure GenStrPosHelper;
Var
  LabOuter, LabInner, LabMatch, LabNext, LabFound, LabNotFound : String;
Begin
  DefineLabel('_str_pos');
  { Prologue : preserve ebx, esi, edi ; ebp n'est pas utilise. }
  BinEmitByte($53); BinEmitByte($56); BinEmitByte($57);
  { Ordre des push de l'appelant : pat, s, start (dernier pushe = start
    a [esp+16]). }
  BinEmitByte($8B); BinEmitByte($44); BinEmitByte($24); BinEmitByte($18);  { mov eax, [esp+24] pat }
  BinEmitByte($89); BinEmitByte($C7);                            { mov edi, eax }
  BinEmitByte($8B); BinEmitByte($44); BinEmitByte($24); BinEmitByte($14);  { mov eax, [esp+20] s }
  BinEmitByte($89); BinEmitByte($C6);                            { mov esi, eax }
  BinEmitByte($8B); BinEmitByte($44); BinEmitByte($24); BinEmitByte($10);  { mov eax, [esp+16] start }
  BinEmitByte($01); BinEmitByte($C6);                            { add esi, eax }
  BinEmitByte($89); BinEmitByte($C3);                            { mov ebx, eax  (position courante) }

  LabOuter    := GenLabel;
  LabInner    := GenLabel;
  LabMatch    := GenLabel;
  LabNext     := GenLabel;
  LabFound    := GenLabel;
  LabNotFound := GenLabel;

  DefineLabel(LabOuter);
  { Si s[esi]==0 et pat non vide -> absent. }
  BinEmitByte($8A); BinEmitByte($06);                            { mov al, [esi] }
  BinEmitByte($84); BinEmitByte($C0);                            { test al, al }
  EmitJZ(LabNotFound);
  { Compare char par char : ecx=0, loop tant que pat[ecx]!=0 et pat[ecx]==s[esi+ecx]. }
  BinEmitByte($31); BinEmitByte($C9);                            { xor ecx, ecx }
  DefineLabel(LabInner);
  { al := pat[ecx] }
  BinEmitByte($8A); BinEmitByte($04); BinEmitByte($0F);          { mov al, [edi+ecx] }
  BinEmitByte($84); BinEmitByte($C0);                            { test al, al }
  EmitJZ(LabFound);
  { dl := s[esi+ecx] }
  BinEmitByte($8A); BinEmitByte($14); BinEmitByte($0E);          { mov dl, [esi+ecx] }
  BinEmitByte($38); BinEmitByte($D0);                            { cmp al, dl }
  EmitJNE(LabNext);
  BinEmitByte($41);                                              { inc ecx }
  EmitJmp(LabInner);
  DefineLabel(LabNext);
  BinEmitByte($46);                                              { inc esi }
  BinEmitByte($43);                                              { inc ebx }
  EmitJmp(LabOuter);

  DefineLabel(LabFound);
  BinEmitByte($89); BinEmitByte($D8);                            { mov eax, ebx }
  EmitJmp(LabMatch);

  DefineLabel(LabNotFound);
  BinEmitByte($B8); BinEmitDWord(-1);                            { mov eax, -1 }

  DefineLabel(LabMatch);
  BinEmitByte($5F); BinEmitByte($5E); BinEmitByte($5B);
  BinEmitByte($C3);
End;

{ --- _strcap : eax=addr, ecx=cap.  Uppercase ASCII a..z -> A..Z,
   s'arrete au premier nul ou apres cap octets. --- }
Procedure GenStrCapHelper;
Var LabLoop, LabEnd, LabSkip : String;
Begin
  DefineLabel('_strcap');
  BinEmitByte($89); BinEmitByte($C7);                            { mov edi, eax }
  LabLoop := GenLabel;
  LabEnd  := GenLabel;
  LabSkip := GenLabel;
  DefineLabel(LabLoop);
  BinEmitByte($85); BinEmitByte($C9);                            { test ecx, ecx }
  EmitJZ(LabEnd);
  BinEmitByte($8A); BinEmitByte($07);                            { mov al, [edi] }
  BinEmitByte($84); BinEmitByte($C0);                            { test al, al }
  EmitJZ(LabEnd);
  { si al < 'a' ou al > 'z' skip }
  BinEmitByte($3C); BinEmitByte($61);                            { cmp al, 'a' }
  BinEmitByte($72); BinEmitByte($08);                            { jb +8 }
  BinEmitByte($3C); BinEmitByte($7A);                            { cmp al, 'z' }
  BinEmitByte($77); BinEmitByte($04);                            { ja +4 }
  BinEmitByte($2C); BinEmitByte($20);                            { sub al, 0x20 }
  BinEmitByte($88); BinEmitByte($07);                            { mov [edi], al }
  BinEmitByte($47);                                              { inc edi }
  BinEmitByte($49);                                              { dec ecx }
  EmitJmp(LabLoop);
  DefineLabel(LabEnd);
  BinEmitByte($C3);
End;

{ --- _inttobuf : eax = value, edi = dst, ecx = cap.
   Ecrit la representation decimale signee suivie d'un nul, dans la
   limite de cap octets.  Prefere tronquer les chiffres de tete pour
   ne jamais ecrire au-dela de cap. --- }
Procedure GenIntToBufHelper;
Var
  LabPos, LabLoop, LabPrependMinus, LabNoMinus, LabCopy, LabCopyLoop, LabCopyEnd, LabZero, LabDone : String;
Begin
  DefineLabel('_inttobuf');
  BinEmitByte($53); BinEmitByte($56); BinEmitByte($57); BinEmitByte($55); { push ebx/esi/edi/ebp }

  { Sauve cap dans ebp (restant dans dst), edi sera deplace. }
  BinEmitByte($89); BinEmitByte($CD);                            { mov ebp, ecx }
  { Si cap == 0 -> rien a ecrire. }
  BinEmitByte($85); BinEmitByte($ED);
  LabDone := GenLabel;
  EmitJZ(LabDone);

  { Utilise IntBufAddr comme scratch (12 octets).  esi := IntBufAddr+12. }
  BinEmitByte($BE);
  AddFixup(FIX_INTBUF_END, 0);
  BinEmitDWord(0);
  BinEmitByte($31); BinEmitByte($DB);                            { xor ebx, ebx (sign flag) }

  LabPos := GenLabel;
  EmitTestEAX;
  BinEmitByte($0F); BinEmitByte($89);                            { jns LabPos }
  AddFixup(FIX_CODE_REL, FindLabel(LabPos));
  BinEmitDWord(0);
  BinEmitByte($F7); BinEmitByte($D8);                            { neg eax }
  BinEmitByte($BB); BinEmitDWord(1);                             { mov ebx, 1 }
  DefineLabel(LabPos);

  { Cas 0 special. }
  LabZero := GenLabel;
  LabLoop := GenLabel;
  EmitTestEAX;
  EmitJNZ(LabLoop);
  BinEmitByte($4E);                                              { dec esi }
  BinEmitByte($C6); BinEmitByte($06); BinEmitByte($30);          { mov byte [esi], '0' }
  LabPrependMinus := GenLabel;
  EmitJmp(LabPrependMinus);
  DefineLabel(LabLoop);
  BinEmitByte($B9); BinEmitDWord(10);                            { mov ecx, 10 }
  BinEmitByte($31); BinEmitByte($D2);                            { xor edx, edx }
  BinEmitByte($F7); BinEmitByte($F1);                            { div ecx }
  BinEmitByte($80); BinEmitByte($C2); BinEmitByte($30);          { add dl, '0' }
  BinEmitByte($4E);                                              { dec esi }
  BinEmitByte($88); BinEmitByte($16);                            { mov [esi], dl }
  EmitTestEAX;
  EmitJNZ(LabLoop);

  DefineLabel(LabPrependMinus);
  BinEmitByte($85); BinEmitByte($DB);                            { test ebx, ebx }
  LabNoMinus := GenLabel;
  EmitJZ(LabNoMinus);
  BinEmitByte($4E);                                              { dec esi }
  BinEmitByte($C6); BinEmitByte($06); BinEmitByte($2D);          { mov byte [esi], '-' }
  DefineLabel(LabNoMinus);

  { Longueur = IntBufAddr+12 - esi ; dans ecx. }
  BinEmitByte($B9);
  AddFixup(FIX_INTBUF_END, 0);
  BinEmitDWord(0);
  BinEmitByte($29); BinEmitByte($F1);                            { sub ecx, esi }

  { Tronque si ecx > ebp-1 (garde 1 pour nul). }
  BinEmitByte($89); BinEmitByte($EA);                            { mov edx, ebp }
  BinEmitByte($4A);                                              { dec edx }
  BinEmitByte($85); BinEmitByte($D2);                            { test edx, edx }
  BinEmitByte($0F); BinEmitByte($8D); BinEmitDWord(2);           { jge +2 (not taken when edx<0) }
  BinEmitByte($31); BinEmitByte($D2);                            { xor edx, edx }
  BinEmitByte($39); BinEmitByte($D1);                            { cmp ecx, edx }
  BinEmitByte($76); BinEmitByte($02);                            { jbe +2 }
  BinEmitByte($89); BinEmitByte($D1);                            { mov ecx, edx }

  { Copie ecx octets de esi vers edi. }
  LabCopyLoop := GenLabel;
  LabCopyEnd := GenLabel;
  DefineLabel(LabCopyLoop);
  BinEmitByte($85); BinEmitByte($C9);                            { test ecx, ecx }
  EmitJZ(LabCopyEnd);
  BinEmitByte($8A); BinEmitByte($06);                            { mov al, [esi] }
  BinEmitByte($88); BinEmitByte($07);                            { mov [edi], al }
  BinEmitByte($46); BinEmitByte($47);                            { inc esi ; inc edi }
  BinEmitByte($49);                                              { dec ecx }
  EmitJmp(LabCopyLoop);
  DefineLabel(LabCopyEnd);
  BinEmitByte($C6); BinEmitByte($07); BinEmitByte($00);          { mov [edi], 0 }

  DefineLabel(LabDone);
  BinEmitByte($5D); BinEmitByte($5F); BinEmitByte($5E); BinEmitByte($5B);
  BinEmitByte($C3);

  { LabCopy etait declare mais jamais utilise ; no-op. }
  LabCopy := LabCopyLoop;
  If Length(LabCopy) < 0 Then ;
End;

{ --- _hextobuf : eax=value, edi=dst, ecx=cap.  Ecrit 8 chiffres hex
   majuscules suivis d'un nul, si cap >= 9.  Sinon tronque a cap-1 chars. --- }
Procedure GenHexToBufHelper;
Var
  LabLoop, LabSkip : String;
  Hex : String;
Begin
  DefineLabel('_hextobuf');
  BinEmitByte($53);                                              { push ebx }
  { Si cap <= 1 -> juste ecrire nul (ou rien). }
  BinEmitByte($83); BinEmitByte($F9); BinEmitByte($01);          { cmp ecx, 1 }
  BinEmitByte($0F); BinEmitByte($8C); BinEmitDWord(0);           { jl rel32 (vers fin apres rev) }
  { Decide combien de chiffres ecrire : min(8, cap-1) dans ebx. }
  BinEmitByte($BB); BinEmitDWord(8);                             { mov ebx, 8 }
  BinEmitByte($49);                                              { dec ecx (cap-1) }
  BinEmitByte($39); BinEmitByte($CB);                            { cmp ebx, ecx }
  BinEmitByte($76); BinEmitByte($02);                            { jbe +2 }
  BinEmitByte($89); BinEmitByte($CB);                            { mov ebx, ecx }
  { ecx := ebx (count) }
  BinEmitByte($89); BinEmitByte($D9);                            { mov ecx, ebx }
  { Decale eax pour ne garder que les ecx*4 bits bas en position haute. }
  { Simplification : toujours extraire 8 hex puis prendre les (ecx) bas. }
  { Approche : shift eax pour aligner le chiffre courant a gauche. }
  { Utilise une boucle qui extrait les 4 bits hauts puis shift left. }
  { Mais on veut les derniers ecx chiffres hexa du mot (bits bas) en ordre. }
  { Strategie : on ajuste eax tel que le chiffre de tete a ecrire soit en bits 31..28.
    Pour ecx chiffres, on shl eax de (8-ecx)*4 bits. }
  BinEmitByte($BA); BinEmitDWord(8);                             { mov edx, 8 }
  BinEmitByte($29); BinEmitByte($CA);                            { sub edx, ecx }
  BinEmitByte($C1); BinEmitByte($E2); BinEmitByte($02);          { shl edx, 2  (mul par 4) }
  { rep : shl eax, cl (nombre variable via ecx) : on doit mettre edx dans cl }
  { Utilise push/pop pour swapper. }
  BinEmitByte($51);                                              { push ecx }
  BinEmitByte($89); BinEmitByte($D1);                            { mov ecx, edx }
  BinEmitByte($D3); BinEmitByte($E0);                            { shl eax, cl }
  BinEmitByte($59);                                              { pop ecx }

  LabLoop := GenLabel;
  LabSkip := GenLabel;
  DefineLabel(LabLoop);
  BinEmitByte($85); BinEmitByte($C9);                            { test ecx, ecx }
  EmitJZ(LabSkip);
  { dl := (eax >> 28) & 0xF }
  BinEmitByte($89); BinEmitByte($C2);                            { mov edx, eax }
  BinEmitByte($C1); BinEmitByte($EA); BinEmitByte($1C);          { shr edx, 28 }
  BinEmitByte($83); BinEmitByte($E2); BinEmitByte($0F);          { and edx, 0x0F }
  { if dl < 10 : + '0' ; else + 'A'-10 = 0x37 }
  BinEmitByte($80); BinEmitByte($FA); BinEmitByte($0A);          { cmp dl, 10 }
  BinEmitByte($72); BinEmitByte($05);                            { jb +5 }
  BinEmitByte($80); BinEmitByte($C2); BinEmitByte($37);          { add dl, 0x37 }
  BinEmitByte($EB); BinEmitByte($03);                            { jmp +3 }
  BinEmitByte($80); BinEmitByte($C2); BinEmitByte($30);          { add dl, '0' }
  BinEmitByte($88); BinEmitByte($17);                            { mov [edi], dl }
  BinEmitByte($47);                                              { inc edi }
  BinEmitByte($C1); BinEmitByte($E0); BinEmitByte($04);          { shl eax, 4 }
  BinEmitByte($49);                                              { dec ecx }
  EmitJmp(LabLoop);
  DefineLabel(LabSkip);
  BinEmitByte($C6); BinEmitByte($07); BinEmitByte($00);          { mov [edi], 0 }
  BinEmitByte($5B);                                              { pop ebx }
  BinEmitByte($C3);
  Hex := ''; If Length(Hex) < 0 Then ;
End;

{ --- _strtoint : esi = src addr.  Retourne eax = valeur signee,
   edx = 1 si succes (au moins un chiffre valide), 0 sinon.
   Skip espaces de tete, signe +/- optionnel, suite de chiffres. --- }
Procedure GenStrToIntHelper;
Var
  LabSkip, LabNoSign, LabLoop, LabDone, LabOk : String;
Begin
  DefineLabel('_strtoint');
  BinEmitByte($53); BinEmitByte($57);                            { push ebx, edi }
  BinEmitByte($31); BinEmitByte($C0);                            { xor eax, eax }
  BinEmitByte($31); BinEmitByte($DB);                            { xor ebx, ebx  (sign: 0=+) }
  BinEmitByte($31); BinEmitByte($FF);                            { xor edi, edi  (count) }

  LabSkip    := GenLabel;
  LabNoSign  := GenLabel;
  LabLoop    := GenLabel;
  LabDone    := GenLabel;
  LabOk      := GenLabel;

  DefineLabel(LabSkip);
  BinEmitByte($8A); BinEmitByte($16);                            { mov dl, [esi] }
  BinEmitByte($80); BinEmitByte($FA); BinEmitByte($20);          { cmp dl, ' ' }
  EmitJNE(LabNoSign);                                             { pas une espace -> sortir }
  BinEmitByte($46);
  EmitJmp(LabSkip);

  DefineLabel(LabNoSign);
  BinEmitByte($80); BinEmitByte($FA); BinEmitByte($2D);          { cmp dl, '-' }
  BinEmitByte($0F); BinEmitByte($85);                            { jne rel32 LabCheckPlus }
  AddFixup(FIX_CODE_REL, FindLabel('_strtoint_chkplus'));
  BinEmitDWord(0);
  BinEmitByte($BB); BinEmitDWord(1);                             { mov ebx, 1 }
  BinEmitByte($46);                                              { inc esi }
  EmitJmp(LabLoop);
  DefineLabel('_strtoint_chkplus');
  BinEmitByte($80); BinEmitByte($FA); BinEmitByte($2B);          { cmp dl, '+' }
  BinEmitByte($0F); BinEmitByte($85);                            { jne rel32 LabLoop }
  AddFixup(FIX_CODE_REL, FindLabel(LabLoop));
  BinEmitDWord(0);
  BinEmitByte($46);                                              { inc esi }
  EmitJmp(LabLoop);

  DefineLabel(LabLoop);
  BinEmitByte($8A); BinEmitByte($16);                            { mov dl, [esi] }
  BinEmitByte($80); BinEmitByte($FA); BinEmitByte($30);          { cmp dl, '0' }
  BinEmitByte($0F); BinEmitByte($82);                            { jb rel32 LabDone }
  AddFixup(FIX_CODE_REL, FindLabel(LabDone));
  BinEmitDWord(0);
  BinEmitByte($80); BinEmitByte($FA); BinEmitByte($39);          { cmp dl, '9' }
  BinEmitByte($0F); BinEmitByte($87);                            { ja rel32 LabDone }
  AddFixup(FIX_CODE_REL, FindLabel(LabDone));
  BinEmitDWord(0);
  BinEmitByte($80); BinEmitByte($EA); BinEmitByte($30);          { sub dl, '0' }
  BinEmitByte($6B); BinEmitByte($C0); BinEmitByte($0A);          { imul eax, eax, 10 }
  BinEmitByte($0F); BinEmitByte($B6); BinEmitByte($D2);          { movzx edx, dl }
  BinEmitByte($01); BinEmitByte($D0);                            { add eax, edx }
  BinEmitByte($46);                                              { inc esi }
  BinEmitByte($47);                                              { inc edi }
  EmitJmp(LabLoop);
  DefineLabel(LabDone);

  { Si ebx != 0 -> neg eax }
  BinEmitByte($85); BinEmitByte($DB);                            { test ebx, ebx }
  EmitJZ(LabOk);
  BinEmitByte($F7); BinEmitByte($D8);                            { neg eax }
  DefineLabel(LabOk);

  { edx := (edi > 0) ? 1 : 0 }
  BinEmitByte($85); BinEmitByte($FF);                            { test edi, edi }
  BinEmitByte($0F); BinEmitByte($95); BinEmitByte($C2);          { setne dl }
  BinEmitByte($0F); BinEmitByte($B6); BinEmitByte($D2);          { movzx edx, dl }

  BinEmitByte($5F); BinEmitByte($5B);                            { pop edi, ebx }
  BinEmitByte($C3);
End;

{ --- _args_get : eax=i (0-based), edi=dst, ecx=cap.
   Copie le i-eme argument de GetCommandLineA (forme ASCII) dans dst.
   Gere les espaces separateurs et les guillemets ".." simplement.
   Convention d'entree : ebp sauvegarde, esi courant dans la ligne de
   commande, ebx = cap restante, ecx (=0/1) = in_quote. --- }
Procedure GenArgsGetHelper;
Var
  LSkipWS, LScanTok, LOutTok, LCopyLoop, LStoreNul, LEOS : String;
  LTogQ, LNotQ, LTokChk, LTokQuote, LTokEnd : String;
  LCopyChk, LCopyQuote, LCopyNotQ, LCopyPut, LCopyEnd : String;
Begin
  DefineLabel('_args_get');
  BinEmitByte($53); BinEmitByte($56); BinEmitByte($55);          { push ebx, esi, ebp }
  BinEmitByte($89); BinEmitByte($C5);                            { mov ebp, eax  (i) }
  BinEmitByte($89); BinEmitByte($CB);                            { mov ebx, ecx  (cap) }
  EmitCallIAT(FIX_IAT_GETCMD);
  BinEmitByte($89); BinEmitByte($C6);                            { mov esi, eax }

  LSkipWS   := GenLabel;
  LScanTok  := GenLabel;
  LOutTok   := GenLabel;
  LCopyLoop := GenLabel;
  LStoreNul := GenLabel;
  LEOS      := GenLabel;

  { Boucle exterieure : skip espaces puis si ebp==0 copier, sinon consommer. }
  DefineLabel(LSkipWS);
  BinEmitByte($8A); BinEmitByte($06);                            { mov al, [esi] }
  BinEmitByte($84); BinEmitByte($C0);                            { test al, al }
  EmitJZ(LEOS);
  BinEmitByte($3C); BinEmitByte($20);                            { cmp al, ' ' }
  EmitJNE(LTokEnd);                                               { sortir si pas espace }
  BinEmitByte($46);                                              { inc esi }
  EmitJmp(LSkipWS);
  DefineLabel(LTokEnd);
  BinEmitByte($85); BinEmitByte($ED);                            { test ebp, ebp }
  BinEmitByte($0F); BinEmitByte($84);                            { je rel32 LCopyEntry }
  AddFixup(FIX_CODE_REL, FindLabel('_args_copy_entry'));
  BinEmitDWord(0);

  { Consomme un token (respecte les guillemets). }
  LTogQ    := GenLabel;
  LNotQ    := GenLabel;
  LTokChk  := GenLabel;
  LTokQuote:= GenLabel;
  LTokEnd  := GenLabel;
  BinEmitByte($31); BinEmitByte($C9);                            { xor ecx, ecx }
  DefineLabel(LScanTok);
  BinEmitByte($8A); BinEmitByte($06);                            { mov al, [esi] }
  BinEmitByte($84); BinEmitByte($C0);
  EmitJZ(LEOS);
  BinEmitByte($3C); BinEmitByte($22);                            { cmp al, '"' }
  EmitJNE(LTokChk);
  BinEmitByte($F7); BinEmitByte($D1);                            { not ecx }
  BinEmitByte($46);
  EmitJmp(LScanTok);
  DefineLabel(LTokChk);
  BinEmitByte($85); BinEmitByte($C9);                            { test ecx, ecx }
  EmitJNZ(LTokQuote);
  BinEmitByte($3C); BinEmitByte($20);
  EmitJE(LOutTok);
  DefineLabel(LTokQuote);
  BinEmitByte($46);
  EmitJmp(LScanTok);
  DefineLabel(LOutTok);
  BinEmitByte($4D);                                              { dec ebp }
  EmitJmp(LSkipWS);

  { Boucle de copie. ebx = cap restante, ecx (=0/1) = in_quote, edi = dst. }
  LCopyChk    := GenLabel;
  LCopyQuote  := GenLabel;
  LCopyNotQ   := GenLabel;
  LCopyPut    := GenLabel;
  LCopyEnd    := GenLabel;
  DefineLabel('_args_copy_entry');
  BinEmitByte($31); BinEmitByte($C9);                            { xor ecx, ecx }
  DefineLabel(LCopyLoop);
  BinEmitByte($83); BinEmitByte($FB); BinEmitByte($01);          { cmp ebx, 1 }
  BinEmitByte($0F); BinEmitByte($8E);                            { jle rel32 LStoreNul }
  AddFixup(FIX_CODE_REL, FindLabel(LStoreNul));
  BinEmitDWord(0);
  BinEmitByte($8A); BinEmitByte($06);                            { mov al, [esi] }
  BinEmitByte($84); BinEmitByte($C0);
  EmitJZ(LStoreNul);
  BinEmitByte($3C); BinEmitByte($22);                            { cmp al, '"' }
  EmitJNE(LCopyChk);
  BinEmitByte($F7); BinEmitByte($D1);
  BinEmitByte($46);
  EmitJmp(LCopyLoop);
  DefineLabel(LCopyChk);
  BinEmitByte($85); BinEmitByte($C9);                            { test ecx, ecx }
  EmitJNZ(LCopyPut);
  BinEmitByte($3C); BinEmitByte($20);                            { cmp al, ' ' }
  EmitJE(LStoreNul);
  DefineLabel(LCopyPut);
  BinEmitByte($88); BinEmitByte($07);                            { mov [edi], al }
  BinEmitByte($47); BinEmitByte($46);                            { inc edi ; inc esi }
  BinEmitByte($4B);                                              { dec ebx }
  EmitJmp(LCopyLoop);

  DefineLabel(LEOS);
  DefineLabel(LStoreNul);
  BinEmitByte($C6); BinEmitByte($07); BinEmitByte($00);          { mov [edi], 0 }
  BinEmitByte($5D); BinEmitByte($5E); BinEmitByte($5B);
  BinEmitByte($C3);
  LCopyQuote := LCopyQuote; LCopyNotQ := LCopyNotQ;
  LCopyEnd := LCopyEnd; LNotQ := LNotQ; LTokEnd := LTokEnd;
End;

{ --- Palier 3 : helper _print_real -----------------------------------
  Ecrit sur stdout la valeur REAL stockee en [real_tmp] avec le format
  fixe "-?ddd...d.dddddd" (6 chiffres apres la virgule).  Le runtime
  utilise _printint pour la partie entiere et les zones intbuf/real_tmp.
  Le helper preserve ebx, esi, edi, ebp et n'utilise pas de parametres
  pile (la valeur a imprimer doit etre pre-enregistree en [real_tmp]).
----------------------------------------------------------------------- }
Procedure GenPrintRealHelper;
Var
  LPos, LLoop : String;
  Sng : Single;
  Bits : LongInt;
  Idx : Integer;
Begin
  { Inscrit le litteral REAL 1000000.0 dans le pool (servira au decalage
    de la fraction vers l'integer pour impression). }
  Sng := 1000000.0;
  Move(Sng, Bits, 4);
  Idx := AddRealLiteral(Bits);

  DefineLabel('_print_real');
  BinEmitByte($53); BinEmitByte($56);                { push ebx, esi }
  BinEmitByte($57); BinEmitByte($55);                { push edi, ebp }

  LPos  := GenLabel;
  LLoop := GenLabel;

  { eax := [real_tmp]. }
  BinEmitByte($A1); AddFixup(FIX_REAL_TMP, 0); BinEmitDWord(0);
  { test eax, 0x80000000 ; jz LPos }
  BinEmitByte($A9); BinEmitDWord(LongInt($80000000));
  BinEmitByte($0F); BinEmitByte($84);
  AddFixup(FIX_CODE_REL, FindLabel(LPos)); BinEmitDWord(0);

  { Valeur negative : force le bit de signe a 0 en memoire. }
  { and dword [real_tmp], 0x7FFFFFFF : 81 25 imm32 imm32 }
  BinEmitByte($81); BinEmitByte($25);
  AddFixup(FIX_REAL_TMP, 0); BinEmitDWord(0);
  BinEmitDWord($7FFFFFFF);

  { Ecrit '-' : on reutilise intbuf (12 octets). Place '-' en intbuf[0]
    puis WriteFile(stdout, intbuf, 1, &bytes_written, NULL). }
  { mov byte [intbuf+0], '-' : C6 05 imm32 imm8 }
  BinEmitByte($C6); BinEmitByte($05);
  AddFixup(FIX_INTBUF, 0); BinEmitDWord(0);
  BinEmitByte(Ord('-'));
  BinEmitByte($6A); BinEmitByte($00);                  { push 0 }
  BinEmitByte($68); AddFixup(FIX_BYTES_WRITTEN, 0); BinEmitDWord(0); { push &bw }
  BinEmitByte($6A); BinEmitByte($01);                  { push 1 }
  BinEmitByte($68); AddFixup(FIX_INTBUF, 0); BinEmitDWord(0);        { push &intbuf }
  BinEmitByte($FF); BinEmitByte($35); AddFixup(FIX_STDOUT, 0); BinEmitDWord(0);
  EmitCallIAT(FIX_IAT_WRITE);

  DefineLabel(LPos);

  { Decomposition partie entiere / fraction.
    fnstcw [fpcw_save] ; fldcw [fpcw_trunc] : mode troncature. }
  EmitFNSTCW_At(FIX_FPCW_SAVE, 0);
  EmitFLDCW_At(FIX_FPCW_TRUNC, 0);

  { fld dword [real_tmp] ; fld st(0) ; fistp dword [real_tmp+4] }
  EmitFLD_Real_At(FIX_REAL_TMP, 0);
  EmitFLD_ST0;
  { fistp dword [real_tmp+4] : DB 1D <addr+4>.  On emet un fixup
    FIX_REAL_TMP et on ajoute 4 a l'adresse via add apres resolution :
    plus simple : on emet directement DB 1D puis une constante absolue
    qui sera patchee.  On reutilise FIX_REAL_TMP avec un decalage
    post-fixup code dans un nouveau kind... Simplification : on utilise
    un fixup FIX_REAL_TMP puis on ecrit l'octet supplementaire via add.
    Approche retenue : emettre le fixup FIX_REAL_TMP en [real_tmp], puis
    ajouter +4 a l'immediat apres resolution par une relocation
    distincte.  Pour eviter ce surcout, on se sert d'une astuce : on
    emet "mov ebx, imm32(real_tmp)" ; "add ebx, 4" ; "fistp dword [ebx]"
    -> fistp [ebx] = DB 1B. }
  { mov ebx, imm32 (real_tmp) }
  BinEmitByte($BB); AddFixup(FIX_REAL_TMP, 0); BinEmitDWord(0);
  BinEmitByte($83); BinEmitByte($C3); BinEmitByte($04);    { add ebx, 4 }
  BinEmitByte($DB); BinEmitByte($1B);                       { fistp dword [ebx] }

  { fldcw [fpcw_save] : restaure mode arrondi. }
  EmitFLDCW_At(FIX_FPCW_SAVE, 0);

  { Push la partie entiere et appelle _printint. push dword [ebx]. }
  BinEmitByte($FF); BinEmitByte($33);                       { push dword [ebx] }
  BinEmitByte($E8);                                         { call rel32 _printint }
  AddFixup(FIX_CODE_REL, FindLabel('_printint'));
  BinEmitDWord(0);

  { Ecrit '.'. }
  BinEmitByte($C6); BinEmitByte($05);
  AddFixup(FIX_INTBUF, 0); BinEmitDWord(0);
  BinEmitByte(Ord('.'));
  BinEmitByte($6A); BinEmitByte($00);
  BinEmitByte($68); AddFixup(FIX_BYTES_WRITTEN, 0); BinEmitDWord(0);
  BinEmitByte($6A); BinEmitByte($01);
  BinEmitByte($68); AddFixup(FIX_INTBUF, 0); BinEmitDWord(0);
  BinEmitByte($FF); BinEmitByte($35); AddFixup(FIX_STDOUT, 0); BinEmitDWord(0);
  EmitCallIAT(FIX_IAT_WRITE);

  { Calcul de la fraction.  Apres l'impression de la partie entiere, le
    sommet de la pile FPU contient encore |x| (grace au fld st(0) avant
    le fistp).  On pousse juste le int_part et on soustrait. }
  BinEmitByte($BB); AddFixup(FIX_REAL_TMP, 0); BinEmitDWord(0);
  BinEmitByte($83); BinEmitByte($C3); BinEmitByte($04);    { add ebx, 4 }
  BinEmitByte($DB); BinEmitByte($03);                      { fild dword [ebx] }
  EmitFSUBP;                               { st0 = |x| - int = frac >= 0 }

  { Multiplie par 1e6. }
  EmitFLD_Real_At(FIX_REAL_CONST, Idx);
  EmitFMULP;

  { Truncature -> int ; stocke dans [real_tmp+4]. }
  EmitFNSTCW_At(FIX_FPCW_SAVE, 0);
  EmitFLDCW_At(FIX_FPCW_TRUNC, 0);
  BinEmitByte($BB); AddFixup(FIX_REAL_TMP, 0); BinEmitDWord(0);
  BinEmitByte($83); BinEmitByte($C3); BinEmitByte($04);
  BinEmitByte($DB); BinEmitByte($1B);                      { fistp dword [ebx] }
  EmitFLDCW_At(FIX_FPCW_SAVE, 0);

  { eax := [ebx] (frac_int). }
  BinEmitByte($8B); BinEmitByte($03);                      { mov eax, [ebx] }

  { Formate 6 chiffres avec zeros de tete dans intbuf[0..5]. }
  { edi := &intbuf + 5 (on remplit du dernier chiffre au premier). }
  BinEmitByte($BF); AddFixup(FIX_INTBUF, 0); BinEmitDWord(0);
  BinEmitByte($83); BinEmitByte($C7); BinEmitByte($05);    { add edi, 5 }
  BinEmitByte($BB); BinEmitDWord(10);                      { mov ebx, 10 }
  BinEmitByte($BE); BinEmitDWord(6);                       { mov esi, 6 }

  DefineLabel(LLoop);
  BinEmitByte($31); BinEmitByte($D2);                      { xor edx, edx }
  BinEmitByte($F7); BinEmitByte($F3);                      { div ebx }
  BinEmitByte($80); BinEmitByte($C2); BinEmitByte($30);    { add dl, '0' }
  BinEmitByte($88); BinEmitByte($17);                      { mov [edi], dl }
  BinEmitByte($4F);                                        { dec edi }
  BinEmitByte($4E);                                        { dec esi }
  { jnz LLoop : 0F 85 rel32 }
  BinEmitByte($0F); BinEmitByte($85);
  AddFixup(FIX_CODE_REL, FindLabel(LLoop));
  BinEmitDWord(0);

  { WriteFile(stdout, intbuf, 6, &bw, NULL). }
  BinEmitByte($6A); BinEmitByte($00);
  BinEmitByte($68); AddFixup(FIX_BYTES_WRITTEN, 0); BinEmitDWord(0);
  BinEmitByte($6A); BinEmitByte($06);
  BinEmitByte($68); AddFixup(FIX_INTBUF, 0); BinEmitDWord(0);
  BinEmitByte($FF); BinEmitByte($35); AddFixup(FIX_STDOUT, 0); BinEmitDWord(0);
  EmitCallIAT(FIX_IAT_WRITE);

  BinEmitByte($5D); BinEmitByte($5F);                      { pop ebp, edi }
  BinEmitByte($5E); BinEmitByte($5B);                      { pop esi, ebx }
  BinEmitByte($C3);                                         { ret }
End;

{ --- Helper coroutine body (Palier 5).
  Entree d'un fiber generique : lpParameter (conventionnellement le
  handle du fiber principal) arrive sur la pile.  Le corps sauvegarde
  ce handle dans EBX (callee-saved pour stdcall, donc preserve a
  travers SwitchToFiber) puis re-yield en boucle : chaque appel a
  Coroutines.Switch(co) cede la main au code principal, et tout appel
  suivant a Switch(co) reprend l'execution dans la boucle ci-dessous.

  Prototype Win32 du callback :
      VOID CALLBACK FiberProc(LPVOID lpParameter);
  stdcall a 1 argument, donc a l'entree :
      [esp]   = adresse de retour (jamais utilisee)
      [esp+4] = lpParameter (main fiber handle) --- }
Procedure GenCoroBodyHelper;
Var
  LLoop : String;
Begin
  DefineLabel('_coro_body');
  { mov ebx, [esp+4]  (8B 5C 24 04) }
  BinEmitByte($8B); BinEmitByte($5C); BinEmitByte($24); BinEmitByte($04);
  LLoop := GenLabel;
  DefineLabel(LLoop);
  { push ebx }
  BinEmitByte($53);
  { call [SwitchToFiber] }
  EmitCallIAT(FIX_IAT_SWITCHFIBER);
  { jmp LLoop }
  EmitJmp(LLoop);
End;

Procedure ParseVarDecl;
Var
  VarNames : Array[1..32] of String;
  VarCount : Integer;
  I, Depth : Integer;
  TypeName : String;
  TypeNameU : String;
  TypeIdx : Integer;
  ArrN : Integer;
  IsCharArray : Boolean;
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
    TypeIdx := 1;
    ArrN := 0;
    IsCharArray := False;
    If CurTok = TOK_IDENT Then
    Begin
      TypeName := StrUpper(CurTokStr);
      If TypeName = 'INTEGER' Then
        TypeIdx := 1
      Else If TypeName = 'BOOLEAN' Then
        TypeIdx := 2
      Else If TypeName = 'CHAR' Then
        TypeIdx := 3
      Else If (TypeName = 'REAL') Or (TypeName = 'LONGREAL') Then
        TypeIdx := TYK_REAL
      Else
        TypeIdx := 1;
      LexNext;
    End
    Else If (CurTok = TOK_KEYWORD) And (CurTokKw = KW_ARRAY) Then
    Begin
      LexNext;
      If CurTok = TOK_INT Then
      Begin
        ArrN := CurTokNum;
        LexNext;
        If (CurTok = TOK_KEYWORD) And (CurTokKw = KW_OF) Then
        Begin
          LexNext;
          If CurTok = TOK_IDENT Then
          Begin
            TypeNameU := StrUpper(CurTokStr);
            If TypeNameU = 'CHAR' Then
              IsCharArray := True;
            LexNext;
          End;
        End;
      End;
      If Not IsCharArray Then
      Begin
        { Variante non supportee : on consomme jusqu'au ';' en equilibrant
          les RECORD...END, on reserve 4 octets. }
        Depth := 0;
        While (CurTok <> TOK_EOF) And
              (((CurTok <> TOK_OP) Or (CurTokStr <> ';')) Or (Depth > 0)) Do
        Begin
          If CurTok = TOK_KEYWORD Then
          Begin
            If CurTokKw = KW_RECORD Then
              Inc(Depth)
            Else If (CurTokKw = KW_END) And (Depth > 0) Then
              Dec(Depth);
          End;
          LexNext;
        End;
        TypeIdx := 1;
      End;
    End
    Else If (CurTok = TOK_KEYWORD) And
            ((CurTokKw = KW_POINTER) Or (CurTokKw = KW_RECORD)) Then
    Begin
      { Type construit : non supporte semantiquement, on reserve 4 octets
        et on saute jusqu'au ';' en equilibrant les RECORD...END. }
      Depth := 0;
      While (CurTok <> TOK_EOF) And
            (((CurTok <> TOK_OP) Or (CurTokStr <> ';')) Or (Depth > 0)) Do
      Begin
        If CurTok = TOK_KEYWORD Then
        Begin
          If CurTokKw = KW_RECORD Then
            Inc(Depth)
          Else If (CurTokKw = KW_END) And (Depth > 0) Then
            Dec(Depth);
        End;
        LexNext;
      End;
      TypeIdx := 1;
    End;
    If IsCharArray Then
    Begin
      For I := 1 To VarCount Do
        SymEnterArr(VarNames[I], ArrN);
    End
    Else
    Begin
      For I := 1 To VarCount Do
        SymEnter(VarNames[I], TypeIdx);
    End;
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
Var
  I : Integer;
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
        { Skip jusqu'a ';' de la meme profondeur en comptant RECORD...END }
        I := 0;
        While (CurTok <> TOK_EOF) And
              (((CurTok <> TOK_OP) Or (CurTokStr <> ';')) Or (I > 0)) Do
        Begin
          If CurTok = TOK_KEYWORD Then
          Begin
            If CurTokKw = KW_RECORD Then
              Inc(I)
            Else If (CurTokKw = KW_END) And (I > 0) Then
              Dec(I);
          End;
          LexNext;
        End;
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
  { Recupere le handle stdout (-11) }
  EmitPushImm32(-11);
  EmitCallIAT(FIX_IAT_GETSTD);
  EmitMovMem32EAX($400000 + $2000);
  BinCodeLen := BinCodeLen - 4;
  AddFixup(FIX_STDOUT, 0);
  BinCodeLen := BinCodeLen + 4;

  { Recupere le handle stderr (-12) }
  EmitPushImm32(-12);
  EmitCallIAT(FIX_IAT_GETSTD);
  EmitMovMem32EAX($400000 + $2000);
  BinCodeLen := BinCodeLen - 4;
  AddFixup(FIX_STDERR, 0);
  BinCodeLen := BinCodeLen + 4;

  { Recupere le handle stdin (-10) }
  EmitPushImm32(-10);
  EmitCallIAT(FIX_IAT_GETSTD);
  EmitMovMem32EAX($400000 + $2000);
  BinCodeLen := BinCodeLen - 4;
  AddFixup(FIX_STDIN, 0);
  BinCodeLen := BinCodeLen + 4;

  { Initialise la seed du generateur aleatoire avec GetTickCount
    (ecrit eax dans rnd_seed). }
  EmitCallIAT(FIX_IAT_GETTICK);
  EmitMovMem32EAX($400000 + $2000);
  BinCodeLen := BinCodeLen - 4;
  AddFixup(FIX_RNDSEED, 0);
  BinCodeLen := BinCodeLen + 4;
End;

Procedure EmitCodeEpilogue;
Begin
  EmitPushImm32(0);
  EmitCallIAT(FIX_IAT_EXIT);
End;

Procedure ResolveFixups(TextRVA, DataRVA, IdataRVA : LongInt);
Var
  I, J, Si, Li : Integer;
  TargetAddr, CalleeAddr, RelAddr : LongInt;
  ImageBase : LongInt;
  StdoutAddr, CRLFAddr, IntBufAddr, BytesWrittenAddr : LongInt;
  StderrAddr, RndSeedAddr, HexBufAddr : LongInt;
  StdinAddr, InLenAddr, InDoneAddr, InBufAddr : LongInt;
  StrAddr : LongInt;
  IATBase : LongInt;
  VarBase, TotalStr : LongInt;
  RealPoolBase : LongInt;
  FPCWTruncAddr, FPCWSaveAddr, RealTmpAddr : LongInt;
  Handled : Boolean;
Begin
  ImageBase := $400000;
  StdoutAddr := ImageBase + DataRVA;
  BytesWrittenAddr := StdoutAddr + 4;
  IntBufAddr := BytesWrittenAddr + 4;
  CRLFAddr := IntBufAddr + 12;
  { Nouvelles zones : stderr handle, seed aleatoire, tampon hexa 8 digits. }
  StderrAddr := CRLFAddr + 2;
  RndSeedAddr := StderrAddr + 4;
  HexBufAddr := RndSeedAddr + 4;
  { Palier 2 : stdin handle + tampon lecture ligne. }
  StdinAddr  := HexBufAddr + 8;
  InLenAddr  := StdinAddr + 4;
  InDoneAddr := InLenAddr + 4;
  InBufAddr  := InDoneAddr + 4;

  TotalStr := 0;
  For Li := 1 To StringCount Do
    TotalStr := TotalStr + Length(StringPool[Li]) + 1;   { +1 pour le nul }
  { Offset de base des variables utilisateur :
      306 octets du bloc fixe
    + chaines litterales, alignees sur 4
    + Palier 3 : pool de REAL (4 * RealCount octets)
                 + fpcw_trunc (2) + fpcw_save (2) + real_tmp (8) = 12 octets
    alignes sur 4. }
  RealPoolBase := 306 + TotalStr;
  While (RealPoolBase Mod 4) <> 0 Do
    RealPoolBase := RealPoolBase + 1;
  FPCWTruncAddr := ImageBase + DataRVA + RealPoolBase + RealCount * 4;
  FPCWSaveAddr  := FPCWTruncAddr + 2;
  RealTmpAddr   := FPCWSaveAddr + 2;
  VarBase := RealPoolBase + RealCount * 4 + 12;
  While (VarBase Mod 4) <> 0 Do
    VarBase := VarBase + 1;

  { Palier 4 : IAT pilotee par la table des imports.  Disposition :
      ILT a offset 40, IMPORT_COUNT+1 entrees de 4 octets (terminateur null).
      IAT immediatement apres, idem.  IATBase = 40 + (IMPORT_COUNT+1)*4. }
  IATBase := 40 + (IMPORT_COUNT + 1) * 4;
  For I := 1 To IMPORT_COUNT Do
    ImportIATAddr[I] := ImageBase + IdataRVA + IATBase + (I - 1) * 4;

  For I := 1 To FixupCount Do
  Begin
    { Resolution generique des fixups IAT via la table des imports. }
    Handled := False;
    For J := 1 To IMPORT_COUNT Do
    Begin
      If Fixups[I].Kind = ImportFixKinds[J] Then
      Begin
        TargetAddr := ImportIATAddr[J];
        BinCode[Fixups[I].Offset] := TargetAddr And $FF;
        BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
        BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
        BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
        Handled := True;
        Break;
      End;
    End;
    If Handled Then
      Continue;

    Case Fixups[I].Kind Of
      FIX_STRING:
        Begin
          Si := Fixups[I].Target;
          { Les chaines litterales viennent apres le bloc fixe de 306 octets. }
          StrAddr := InBufAddr + 256;
          If Si > 0 Then
          Begin
            For Li := 1 To Si-1 Do
              StrAddr := StrAddr + Length(StringPool[Li]) + 1;   { +1 pour le nul }
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
      FIX_CODE_ABS:
        Begin
          { Adresse absolue d'un label de code (utilise par Coroutines.Body
            pour exposer l'entree du helper _coro_body). }
          Li := Fixups[I].Target;
          If (Li > 0) And (Li <= LabelCount) Then
          Begin
            If Labels[Li].Defined Then
            Begin
              TargetAddr := ImageBase + TextRVA + Labels[Li].Offset;
              BinCode[Fixups[I].Offset] := TargetAddr And $FF;
              BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
              BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
              BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
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
      FIX_STDERR:
        Begin
          TargetAddr := StderrAddr;
          BinCode[Fixups[I].Offset] := TargetAddr And $FF;
          BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
          BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
          BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
        End;
      FIX_RNDSEED:
        Begin
          TargetAddr := RndSeedAddr;
          BinCode[Fixups[I].Offset] := TargetAddr And $FF;
          BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
          BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
          BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
        End;
      FIX_HEXBUF:
        Begin
          TargetAddr := HexBufAddr;
          BinCode[Fixups[I].Offset] := TargetAddr And $FF;
          BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
          BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
          BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
        End;
      FIX_HEXBUF_END:
        Begin
          TargetAddr := HexBufAddr + 8;
          BinCode[Fixups[I].Offset] := TargetAddr And $FF;
          BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
          BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
          BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
        End;
      FIX_STDIN:
        Begin
          TargetAddr := StdinAddr;
          BinCode[Fixups[I].Offset] := TargetAddr And $FF;
          BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
          BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
          BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
        End;
      FIX_INBUF:
        Begin
          TargetAddr := InBufAddr;
          BinCode[Fixups[I].Offset] := TargetAddr And $FF;
          BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
          BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
          BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
        End;
      FIX_INLEN:
        Begin
          TargetAddr := InLenAddr;
          BinCode[Fixups[I].Offset] := TargetAddr And $FF;
          BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
          BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
          BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
        End;
      FIX_INDONE:
        Begin
          TargetAddr := InDoneAddr;
          BinCode[Fixups[I].Offset] := TargetAddr And $FF;
          BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
          BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
          BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
        End;
      FIX_REAL_CONST:
        Begin
          { Target = indice 1-base dans le pool REAL. }
          Si := Fixups[I].Target;
          If (Si > 0) And (Si <= RealCount) Then
          Begin
            TargetAddr := ImageBase + DataRVA + RealPoolBase + (Si - 1) * 4;
            BinCode[Fixups[I].Offset] := TargetAddr And $FF;
            BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
            BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
            BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
          End;
        End;
      FIX_REAL_TMP:
        Begin
          TargetAddr := RealTmpAddr;
          BinCode[Fixups[I].Offset] := TargetAddr And $FF;
          BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
          BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
          BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
        End;
      FIX_FPCW_TRUNC:
        Begin
          TargetAddr := FPCWTruncAddr;
          BinCode[Fixups[I].Offset] := TargetAddr And $FF;
          BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
          BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
          BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
        End;
      FIX_FPCW_SAVE:
        Begin
          TargetAddr := FPCWSaveAddr;
          BinCode[Fixups[I].Offset] := TargetAddr And $FF;
          BinCode[Fixups[I].Offset+1] := (TargetAddr Shr 8) And $FF;
          BinCode[Fixups[I].Offset+2] := (TargetAddr Shr 16) And $FF;
          BinCode[Fixups[I].Offset+3] := (TargetAddr Shr 24) And $FF;
        End;
    End;
  End;
End;

Procedure BuildDataSection;
Var I, J, K : Integer;
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

  { Zone stderr handle : 4 octets. }
  For I := 1 To 4 Do
  Begin
    BinData[BinDataLen] := 0;
    Inc(BinDataLen);
  End;

  { Zone seed aleatoire : 4 octets. }
  For I := 1 To 4 Do
  Begin
    BinData[BinDataLen] := 0;
    Inc(BinDataLen);
  End;

  { Tampon hexa : 8 octets (8 chiffres '%08X'). }
  For I := 1 To 8 Do
  Begin
    BinData[BinDataLen] := Ord('0');
    Inc(BinDataLen);
  End;

  { Palier 2 : zones lecture ligne. }
  { Stdin handle : 4 octets. }
  For I := 1 To 4 Do
  Begin
    BinData[BinDataLen] := 0;
    Inc(BinDataLen);
  End;
  { InLen : 4 octets. }
  For I := 1 To 4 Do
  Begin
    BinData[BinDataLen] := 0;
    Inc(BinDataLen);
  End;
  { InDone : 4 octets. }
  For I := 1 To 4 Do
  Begin
    BinData[BinDataLen] := 0;
    Inc(BinDataLen);
  End;
  { InBuf : 256 octets. }
  For I := 1 To 256 Do
  Begin
    BinData[BinDataLen] := 0;
    Inc(BinDataLen);
  End;

  For I := 1 To StringCount Do
  Begin
    For J := 1 To Length(StringPool[I]) Do
    Begin
      BinData[BinDataLen] := Ord(StringPool[I][J]);
      Inc(BinDataLen);
    End;
    { Terminateur nul pour que les helpers runtime (_strlen, _str_pos, etc.)
      puissent traiter les litteraux comme des C-strings. }
    BinData[BinDataLen] := 0;
    Inc(BinDataLen);
  End;

  { Alignement sur 4 octets pour le pool de REAL qui suit. }
  While (BinDataLen Mod 4) <> 0 Do
  Begin
    BinData[BinDataLen] := 0;
    Inc(BinDataLen);
  End;

  { Palier 3 : pool des litteraux REAL (4 octets chacun, IEEE 754 simple). }
  For I := 1 To RealCount Do
  Begin
    BinData[BinDataLen]     := RealPool[I] And $FF;
    BinData[BinDataLen + 1] := (RealPool[I] Shr 8) And $FF;
    BinData[BinDataLen + 2] := (RealPool[I] Shr 16) And $FF;
    BinData[BinDataLen + 3] := (RealPool[I] Shr 24) And $FF;
    Inc(BinDataLen, 4);
  End;

  { Palier 3 : mot de controle x87 mode troncature (0x0F7F = PC=64, RC=truncate,
    masquer toutes les exceptions). }
  BinData[BinDataLen]     := $7F;
  BinData[BinDataLen + 1] := $0F;
  Inc(BinDataLen, 2);
  { Zone de sauvegarde du cw courant. }
  BinData[BinDataLen]     := 0;
  BinData[BinDataLen + 1] := 0;
  Inc(BinDataLen, 2);
  { Zone temporaire REAL (8 octets : aligne, utilisable pour qword fistp). }
  For I := 1 To 8 Do
  Begin
    BinData[BinDataLen] := 0;
    Inc(BinDataLen);
  End;

  While (BinDataLen Mod 4) <> 0 Do
  Begin
    BinData[BinDataLen] := 0;
    Inc(BinDataLen);
  End;

  For I := 1 To SymCount Do
  Begin
    If SymTab[I].TypeIdx = TYK_ARRCHAR Then
    Begin
      { Reserve N octets arrondis a 4. }
      K := SymTab[I].ArrSize;
      While (K Mod 4) <> 0 Do Inc(K);
      For J := 1 To K Do
      Begin
        BinData[BinDataLen] := 0;
        Inc(BinDataLen);
      End;
    End
    Else
    Begin
      For J := 1 To TypeByteSize(SymTab[I].TypeIdx) Do
      Begin
        BinData[BinDataLen] := 0;
        Inc(BinDataLen);
      End;
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
  I, J         : Integer;
  Pad          : LongInt;
  IdataBuf     : Array[0..1023] of Byte;
  ILTBase, IATBase, DllNameBase, HNBase : Integer;
  Ofs, TotalIdata : Integer;
  Rva          : LongInt;
  ImportHNOffs : Array[1..IMPORT_COUNT] of Integer;
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

  { ==========================================================
    Construction .idata pilotee par la table ImportNames[] :
      offset 0..19  : Import Descriptor KERNEL32 (20 octets).
      offset 20..39 : Descriptor terminateur nul.
      offset 40     : ILT, IMPORT_COUNT+1 entrees de 4 octets.
      puis          : IAT, IMPORT_COUNT+1 entrees de 4 octets.
      puis          : nom DLL "KERNEL32.DLL", aligne.
      puis          : Hint/Name par import (2 octets hint + nom + nul,
                      aligne sur 2).
    ========================================================== }
  Begin
    { ILTBase / IATBase / NameBase sont des OFFSETS dans IdataBuf ; les
      champs Import Descriptor stockent des RVA (IdataRVA + offset). }
    ILTBase := 40;
    IATBase := ILTBase + (IMPORT_COUNT + 1) * 4;
    DllNameBase := IATBase + (IMPORT_COUNT + 1) * 4;
    { Copie le nom de la DLL (13 octets y compris le nul). }
    Move('KERNEL32.DLL'#0, IdataBuf[DllNameBase], 13);
    { Hint/Name pour chaque import, aligne sur 2. }
    HNBase := DllNameBase + 13;
    While (HNBase And 1) <> 0 Do
      HNBase := HNBase + 1;
    Ofs := HNBase;
    For I := 1 To IMPORT_COUNT Do
    Begin
      ImportHNOffs[I] := Ofs;
      { 2 octets de hint (0) suivis du nom ASCII termine par un nul. }
      IdataBuf[Ofs]   := 0;
      IdataBuf[Ofs+1] := 0;
      J := Length(ImportNames[I]);
      Move(ImportNames[I][1], IdataBuf[Ofs + 2], J);
      IdataBuf[Ofs + 2 + J] := 0;
      Ofs := Ofs + 2 + J + 1;
      If (Ofs And 1) <> 0 Then
        Ofs := Ofs + 1;
    End;
    TotalIdata := Ofs;

    { --- Import Descriptor pour KERNEL32.DLL (20 octets). --- }
    Rva := IdataRVA + ILTBase;
    IdataBuf[0] := Rva And $FF;
    IdataBuf[1] := (Rva Shr 8) And $FF;
    IdataBuf[2] := (Rva Shr 16) And $FF;
    IdataBuf[3] := (Rva Shr 24) And $FF;
    Rva := IdataRVA + DllNameBase;
    IdataBuf[12] := Rva And $FF;
    IdataBuf[13] := (Rva Shr 8) And $FF;
    IdataBuf[14] := (Rva Shr 16) And $FF;
    IdataBuf[15] := (Rva Shr 24) And $FF;
    Rva := IdataRVA + IATBase;
    IdataBuf[16] := Rva And $FF;
    IdataBuf[17] := (Rva Shr 8) And $FF;
    IdataBuf[18] := (Rva Shr 16) And $FF;
    IdataBuf[19] := (Rva Shr 24) And $FF;
    { Descriptor terminateur (zero) a 20..39, deja a 0 via FillChar. }

    { --- ILT et IAT : chaque entree pointe sur son Hint/Name. --- }
    For I := 1 To IMPORT_COUNT Do
    Begin
      Rva := IdataRVA + ImportHNOffs[I];
      Ofs := ILTBase + (I - 1) * 4;
      IdataBuf[Ofs]   := Rva And $FF;
      IdataBuf[Ofs+1] := (Rva Shr 8) And $FF;
      IdataBuf[Ofs+2] := (Rva Shr 16) And $FF;
      IdataBuf[Ofs+3] := (Rva Shr 24) And $FF;
      Ofs := IATBase + (I - 1) * 4;
      IdataBuf[Ofs]   := Rva And $FF;
      IdataBuf[Ofs+1] := (Rva Shr 8) And $FF;
      IdataBuf[Ofs+2] := (Rva Shr 16) And $FF;
      IdataBuf[Ofs+3] := (Rva Shr 24) And $FF;
    End;
    { Terminateurs nuls de l'ILT et de l'IAT sont deja a 0. }

    { Taille de la section : arrondie sur 512 octets. }
    If TotalIdata > IdataSize Then
    Begin
      While IdataSize < TotalIdata Do
        IdataSize := IdataSize + 512;
    End;
  End;

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
  WriteBinDWord(F, LongInt($C0000040));

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
  WriteBinDWord(F, LongInt($C0000040));

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

Procedure PrintUsage;Begin
 WriteLn('OBERCW32 version ', OBERCW32_VERSION,' - Cette commande permet de ',
         'lancer le compilateur Oberon pour l''assembleur du microprocesseur ',
         '80386 pour Windows 32 bits.');
 WriteLn;
 WriteLn('Syntaxe : OBERCW32 <source.obn> [options]');
 WriteLn;
 WriteLn('Options :');
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
  ExitLabelTop := 0;
  RealCount := 0;

  Ti := TypeNew(TYK_INTEGER, 4);
  Ti := TypeNew(TYK_BOOLEAN, 1);
  Ti := TypeNew(TYK_CHAR, 1);
  Ti := TypeNew(TYK_REAL, 4);

  { Table des imports KERNEL32.DLL.  L'ordre est arbitraire mais doit
    rester stable car les offsets IAT sont calcules a partir de l'index. }
  ImportNames[1]  := 'GetStdHandle';     ImportFixKinds[1]  := FIX_IAT_GETSTD;
  ImportNames[2]  := 'WriteFile';        ImportFixKinds[2]  := FIX_IAT_WRITE;
  ImportNames[3]  := 'ExitProcess';      ImportFixKinds[3]  := FIX_IAT_EXIT;
  ImportNames[4]  := 'Sleep';            ImportFixKinds[4]  := FIX_IAT_SLEEP;
  ImportNames[5]  := 'GetTickCount';     ImportFixKinds[5]  := FIX_IAT_GETTICK;
  ImportNames[6]  := 'GetCommandLineA';  ImportFixKinds[6]  := FIX_IAT_GETCMD;
  ImportNames[7]  := 'ReadFile';         ImportFixKinds[7]  := FIX_IAT_READ;
  ImportNames[8]  := 'CreateFileA';      ImportFixKinds[8]  := FIX_IAT_CREATEFILE;
  ImportNames[9]  := 'CloseHandle';      ImportFixKinds[9]  := FIX_IAT_CLOSEHANDLE;
  ImportNames[10] := 'SetFilePointer';   ImportFixKinds[10] := FIX_IAT_SETFILEPTR;
  ImportNames[11] := 'GetProcessHeap';   ImportFixKinds[11] := FIX_IAT_GETPROCHEAP;
  ImportNames[12] := 'HeapAlloc';        ImportFixKinds[12] := FIX_IAT_HEAPALLOC;
  ImportNames[13] := 'HeapFree';         ImportFixKinds[13] := FIX_IAT_HEAPFREE;
  ImportNames[14] := 'LoadLibraryA';     ImportFixKinds[14] := FIX_IAT_LOADLIB;
  ImportNames[15] := 'GetProcAddress';   ImportFixKinds[15] := FIX_IAT_GETPROC;
  ImportNames[16] := 'FreeLibrary';      ImportFixKinds[16] := FIX_IAT_FREELIB;
  ImportNames[17] := 'ConvertThreadToFiber'; ImportFixKinds[17] := FIX_IAT_CVTFIBER;
  ImportNames[18] := 'CreateFiber';      ImportFixKinds[18] := FIX_IAT_CREATEFIBER;
  ImportNames[19] := 'SwitchToFiber';    ImportFixKinds[19] := FIX_IAT_SWITCHFIBER;
  ImportNames[20] := 'DeleteFiber';      ImportFixKinds[20] := FIX_IAT_DELETEFIBER;
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  PrintUsage;
  Halt;
 End;
 ParseArgs;
 InitTables;
 LexOpen(Opts.SrcFile);
 EmitCodePrologue;
 ParseModule;
 EmitCodeEpilogue;
 GenPrintIntHelper;
 GenArgsCountHelper;
 GenReadLineHelper;
 GenStrLenHelper;
 GenStrPosHelper;
 GenStrCapHelper;
 GenIntToBufHelper;
 GenHexToBufHelper;
 GenStrToIntHelper;
 GenArgsGetHelper;
 GenPrintRealHelper;
 GenCoroBodyHelper;
 LexClose;
 If ErrorCount > 0 Then Begin
  WriteLn('OBERCW32: ', ErrorCount, ' erreur(s), compilation abandonnee');
  Halt(1);
 End;
 BuildDataSection;
 BinWriteExe;
 If Opts.Verbose Then Begin
  WriteLn('OBERCW32 v', OBERCW32_VERSION, ': compilation OK (', ErrorCount, ' erreur(s))');
 End;
END.
