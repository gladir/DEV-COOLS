{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal / Free Pascal 3.2)
  @description: Clone de LINK68 Digital Research/Alcyon pour Atari ST.
                Lie des objets DRI .O et produit un fichier .68K.
  @license: MIT
}

Program LINK68;

{$A-}
{$I-}

Const
 MAX_MODULES = 1024;
 MAX_INPUTS  = 1024;
 MAX_MEMBERS = 32767;
 MAX_SYMBOLS = 32767;
 MAX_IMAGE   = 16 * 1024 * 1024;
 MAX_CMDLINE = 8192;

 SYM_DEFINED = $8000;
 SYM_EQUATED = $4000;
 SYM_GLOBAL  = $2000;
 SYM_EXTERN  = $0800;
 SYM_DATA    = $0400;
 SYM_TEXT    = $0200;
 SYM_BSS     = $0100;

 REL_ABS     = 0;
 REL_DATA    = 1;
 REL_TEXT    = 2;
 REL_BSS     = 3;
 REL_EXTERN  = 4;
 REL_UPPER   = 5;
 REL_PCREL   = 6;
 REL_INSTR   = 7;

Type
 TByteBuffer = Array[0..MAX_IMAGE - 1] of Byte;
 PByteBuffer = ^TByteBuffer;
 TWordBuffer = Array[0..(MAX_IMAGE div 2) - 1] of Word;
 PWordBuffer = ^TWordBuffer;

 TSymbol = Record
  Name  : String[8];
  SType : Word;
  Value : LongInt;
 End;
 TSymbolBuffer = Array[0..MAX_SYMBOLS - 1] of TSymbol;
 PSymbolBuffer = ^TSymbolBuffer;

 TModule = Record
  FileName : String;
  OrderKey : LongInt;
  TextSize, DataSize, BssSize : LongInt;
  TextOffset, DataOffset, BssOffset : LongInt;
 SymCount : Integer;
  IncludeLocals : Boolean;
  Symbols : PSymbolBuffer;
  TextData, DataData : PByteBuffer;
  TextRel, DataRel : PWordBuffer;
 End;

 TGlobal = Record
  Name : String[8];
  ModuleIndex, SymbolIndex : Integer;
  Defined, Needed : Boolean;
  IsCommon : Boolean;
  CommonSize : LongInt;
  FinalType : Word;
  FinalValue : LongInt;
 End;

 TOptions = Record
  AllowUndefined, EmitSymbols, EmitLocals, Absolute, AllMods, IgnoreOverflow : Boolean;
  TextBaseSet, DataBaseSet, BssBaseSet : Boolean;
  TextBase, DataBase, BssBase : LongInt;
  OutputName : String;
  TempPath : String;
 End;

 TInput = Record
  FileName : String;
  IncludeLocals, AllMods : Boolean;
  IncludeName : String[64];
  IndexPos, IndexSize : LongInt;
 End;

 TMember = Record
  InputIndex : Integer;
  Name : String[64];
  DataPos, DataSize : LongInt;
  Loaded, Selected : Boolean;
 End;

Var
 Opt : TOptions;
 Modules : Array[1..MAX_MODULES] of TModule;
 ModuleCount : Integer;
 Globals : Array[1..MAX_SYMBOLS] of TGlobal;
 GlobalCount : Integer;
 Inputs : Array[1..MAX_INPUTS] of TInput;
 InputCount : Integer;
 Members : Array[1..MAX_MEMBERS] of TMember;
 MemberCount : Integer;
 OutText, OutData : PByteBuffer;
 OutTextRel, OutDataRel : PWordBuffer;
 TotalText, TotalData, TotalBss : LongInt;
 ErrorCount, WarningCount : Integer;

Function UpCaseStr(Const S: String): String;
Var I: Integer; R: String;
Begin R := S; For I := 1 to Length(R) do R[I] := UpCase(R[I]); UpCaseStr := R; End;

Function TrimStr(Const S: String): String;
Var A, B: Integer;
Begin
 A := 1; While (A <= Length(S)) and (S[A] <= ' ') do Inc(A);
 B := Length(S); While (B >= A) and (S[B] <= ' ') do Dec(B);
 TrimStr := Copy(S, A, B - A + 1);
End;

Function IsAbbrev(Const S, FullName: String; MinLen: Integer): Boolean;
Begin IsAbbrev := (Length(S) >= MinLen) and (Length(S) <= Length(FullName)) and
                  (Copy(FullName, 1, Length(S)) = S); End;

Procedure Error(Const S: String);
Begin Inc(ErrorCount); WriteLn('LINK68: erreur: ', S); End;

Procedure Warning(Const S: String);
Begin Inc(WarningCount); WriteLn('LINK68: avertissement: ', S); End;

Procedure Fatal(Const S: String);
Begin Error(S); Halt(2); End;

Function FileExists68(Const Name: String): Boolean;
Var F: File; Exists: Boolean;
Begin
 Assign(F, Name); Reset(F, 1); Exists := IOResult = 0;
 If Exists Then Close(F); FileExists68 := Exists;
End;

Function HasExtension(Const Name: String): Boolean;
Var I: Integer;
Begin
 HasExtension := False;
 For I := Length(Name) DownTo 1 do
 Begin
  If Name[I] = '.' Then Begin HasExtension := True; Exit; End;
  If (Name[I] = '\') or (Name[I] = '/') or (Name[I] = ':') Then Exit;
 End;
End;

Function DefaultExtension(Const Name, Ext: String): String;
Begin If HasExtension(Name) Then DefaultExtension := Name Else DefaultExtension := Name + Ext; End;

Function BaseName68(Const Name: String): String;
Var I, P: Integer; R: String;
Begin
 P := 0;
 For I := Length(Name) DownTo 1 do If Name[I] = '.' Then Begin P := I; Break; End;
 If P > 0 Then R := Copy(Name, 1, P - 1) Else R := Name;
 BaseName68 := R;
End;

Function HexDigit(C: Char): Integer;
Begin
 If C in ['0'..'9'] Then HexDigit := Ord(C) - Ord('0')
 Else If UpCase(C) in ['A'..'F'] Then HexDigit := Ord(UpCase(C)) - Ord('A') + 10
 Else HexDigit := -1;
End;

Function ParseAddress(S: String; Var V: LongInt): Boolean;
Var I, D: Integer; X: LongWord;
Begin
 S := TrimStr(S);
 If (Length(S) > 0) and (S[1] = '$') Then Delete(S, 1, 1)
 Else If (Length(S) > 1) and (S[1] = '0') and (UpCase(S[2]) = 'X') Then Delete(S, 1, 2);
 If (Length(S) > 0) and (UpCase(S[Length(S)]) = 'H') Then Delete(S, Length(S), 1);
 X := 0; ParseAddress := False; If S = '' Then Exit;
 For I := 1 to Length(S) do
 Begin D := HexDigit(S[I]); If D < 0 Then Exit; X := X * 16 + LongWord(D); End;
 V := LongInt(X); ParseAddress := True;
End;

Procedure PutByte(Var F: File; B: Byte);
Begin BlockWrite(F, B, 1); End;

Procedure PutWord(Var F: File; W: Word);
Begin PutByte(F, Byte(W shr 8)); PutByte(F, Byte(W)); End;

Procedure PutLong(Var F: File; L: LongInt);
Begin PutWord(F, Word(LongWord(L) shr 16)); PutWord(F, Word(L)); End;

Function GetByte(Var F: File): Byte;
Var B: Byte; N: Integer;
Begin BlockRead(F, B, 1, N); If N <> 1 Then Fatal('fin de fichier inattendue'); GetByte := B; End;

Function GetWord(Var F: File): Word;
Begin GetWord := Word(GetByte(F)) shl 8 or GetByte(F); End;

Function GetLong(Var F: File): LongInt;
Var A, B: Word;
Begin A := GetWord(F); B := GetWord(F); GetLong := LongInt((LongWord(A) shl 16) or B); End;

Procedure SeekFile(Var F: File; Posn: LongInt);
Begin Seek(F, Posn); If IOResult <> 0 Then Fatal('position invalide dans un objet'); End;

Function FindGlobal(Const Name: String): Integer;
Var I: Integer;
Begin
 For I := 1 to GlobalCount do If Globals[I].Name = Name Then Begin FindGlobal := I; Exit; End;
 FindGlobal := 0;
End;

Function AddGlobal(Const Name: String): Integer;
Begin
 If GlobalCount >= MAX_SYMBOLS Then Fatal('trop de symboles globaux');
 Inc(GlobalCount); FillChar(Globals[GlobalCount], SizeOf(TGlobal), 0);
 Globals[GlobalCount].Name := Name; AddGlobal := GlobalCount;
End;

Function SegmentOf(T: Word): Integer;
Begin
 If (T and SYM_TEXT) <> 0 Then SegmentOf := REL_TEXT
 Else If (T and SYM_DATA) <> 0 Then SegmentOf := REL_DATA
 Else If (T and SYM_BSS) <> 0 Then SegmentOf := REL_BSS
 Else SegmentOf := REL_ABS;
End;

Function IsCommonSymbol(Const S: TSymbol): Boolean;
Begin IsCommonSymbol := (S.SType and (SYM_DEFINED or SYM_EXTERN)) = (SYM_DEFINED or SYM_EXTERN); End;

Procedure ShowHelp;
Begin
 WriteLn('LINK68 - Cette commande permet de lancer un clone du linker Digital Research/Alcyon pour Atari ST.');
 WriteLn;
 WriteLn('Syntaxe : LINK68 [options] sortie = objet1,objet2,...');
 WriteLn('          LINK68 objet1,objet2,...');
 WriteLn;
 WriteLn('Options entre crochets :');
 WriteLn('  U              Autorise les symboles non definis');
 WriteLn('  S              Inclut la table des symboles');
 WriteLn('  ALLMODS (AL)   Charge tous les modules des bibliotheques');
 WriteLn('  IGNORE (IG)    Continue apres un debordement d''adresse 16 bits');
 WriteLn('  TEMPFILES[p]   Repertoire reserve aux fichiers temporaires');
 WriteLn('  ABSOLUTE       Produit une image non relogeable');
 WriteLn('  TEXTBASE[n]    Adresse de base TEXT (hexadecimal)');
 WriteLn('  DATABASE[n]    Adresse de base DATA (hexadecimal)');
 WriteLn('  BSSBASE[n]     Adresse de base BSS (hexadecimal)');
 WriteLn('Options locales apres une entree : LOCALS, NOLOCALS, INCLUDE[module]');
 WriteLn('Bibliotheques reconnues : archives Unix/AR68 .L68 (membres objets DRI)');
 WriteLn;
 WriteLn('Exemple : LINK68 [U,S] TEST.68K=TEST,OSBIND');
End;

Procedure ParseOneOption(S: String);
Var U, A: String; P: Integer; V: LongInt;
Begin
 S := TrimStr(S); U := UpCaseStr(S);
 If U = '' Then Exit;
 If IsAbbrev(U, 'UNDEFINED', 1) Then Opt.AllowUndefined := True
 Else If IsAbbrev(U, 'SYMBOLS', 1) Then Opt.EmitSymbols := True
 Else If IsAbbrev(U, 'LOCALS', 2) Then Opt.EmitLocals := True
 Else If IsAbbrev(U, 'NOLOCALS', 2) Then Opt.EmitLocals := False
 Else If IsAbbrev(U, 'ABSOLUTE', 2) Then Opt.Absolute := True
 Else If IsAbbrev(U, 'ALLMODS', 2) Then Opt.AllMods := True
 Else If IsAbbrev(U, 'IGNORE', 2) Then Opt.IgnoreOverflow := True
 Else Begin
  P := Pos('[', U);
  If (P > 0) and (U[Length(U)] = ']') Then
  Begin
   A := Copy(U, P + 1, Length(U) - P - 1);
   U := Copy(U, 1, P - 1);
   If IsAbbrev(U, 'TEMPFILES', 3) Then Opt.TempPath := A
   Else Begin
    If Not ParseAddress(A, V) Then Begin Error('adresse invalide dans ' + S); Exit; End;
    If IsAbbrev(U, 'TEXTBASE', 3) Then Begin Opt.TextBase := V; Opt.TextBaseSet := True; End
    Else If IsAbbrev(U, 'DATABASE', 1) Then Begin Opt.DataBase := V; Opt.DataBaseSet := True; End
    Else If IsAbbrev(U, 'BSSBASE', 1) Then Begin Opt.BssBase := V; Opt.BssBaseSet := True; End
    Else Warning('option inconnue: ' + S);
   End
  End Else Warning('option inconnue: ' + S);
 End;
End;

Procedure ParseOptionList(Const S: String);
Var I, Start, Depth: Integer; Part: String;
Begin
 Start := 1; Depth := 0;
 For I := 1 to Length(S) + 1 do
 Begin
  If (I <= Length(S)) and (S[I] = '[') Then Inc(Depth)
  Else If (I <= Length(S)) and (S[I] = ']') Then Dec(Depth);
  If (I > Length(S)) or ((S[I] = ',') and (Depth = 0)) Then
  Begin Part := Copy(S, Start, I - Start); ParseOneOption(Part); Start := I + 1; End;
 End;
End;

Procedure AddInput(S: String);
Var P, Q: Integer; LocalOpt, U: String;
Begin
 S := TrimStr(S); If S = '' Then Exit;
 P := Pos('[', S);
 LocalOpt := '';
 If P > 0 Then Begin LocalOpt := UpCaseStr(Copy(S, P + 1, Length(S) - P - 1)); S := TrimStr(Copy(S, 1, P - 1)); End;
 If InputCount >= MAX_INPUTS Then Fatal('trop de fichiers d''entree');
 Inc(InputCount); Inputs[InputCount].FileName := S;
 Inputs[InputCount].IncludeLocals := Opt.EmitLocals or (Pos('LOCALS', LocalOpt) > 0) or (LocalOpt = 'LO');
 If (Pos('NOLOCALS', LocalOpt) > 0) or (LocalOpt = 'NO') Then Inputs[InputCount].IncludeLocals := False;
 Inputs[InputCount].AllMods := Opt.AllMods or (Pos('ALLMODS', LocalOpt) > 0) or (LocalOpt = 'AL');
 Inputs[InputCount].IncludeName := '';
 U := LocalOpt; P := Pos('INCLUDE', U); If P = 0 Then P := Pos('IN[', U);
 If P > 0 Then Begin
  P := Pos('[', U); Q := Pos(']', U);
  If (P > 0) and (Q > P) Then Inputs[InputCount].IncludeName := TrimStr(Copy(U, P + 1, Q - P - 1))
  Else Begin Delete(U, 1, Length('INCLUDE')); Inputs[InputCount].IncludeName := TrimStr(U); End;
 End;
End;

Procedure ParseInputs(Const S: String);
Var I, Start, Depth: Integer;
Begin
 Start := 1; Depth := 0;
 For I := 1 to Length(S) + 1 do
 Begin
  If (I <= Length(S)) and (S[I] = '[') Then Inc(Depth)
  Else If (I <= Length(S)) and (S[I] = ']') Then Dec(Depth);
  If (I > Length(S)) or ((S[I] = ',') and (Depth = 0)) Then
  Begin AddInput(Copy(S, Start, I - Start)); Start := I + 1; End;
 End;
End;

Procedure ParseCommandLine;
Var Cmd, Rest, OptText: String; I, P, Depth, ClosePos: Integer;
Begin
 FillChar(Opt, SizeOf(Opt), 0); InputCount := 0; Cmd := '';
 For I := 1 to ParamCount do Begin If Cmd <> '' Then Cmd := Cmd + ' '; Cmd := Cmd + ParamStr(I); End;
 Cmd := TrimStr(Cmd);
 If (Cmd = '') or (Cmd = '/?') or (Cmd = '-?') or (Cmd = '--help') Then Begin ShowHelp; Halt(Ord(Cmd = '')); End;
 Rest := Cmd;
 If Rest[1] = '[' Then
 Begin
  Depth := 0; ClosePos := 0;
  For I := 1 to Length(Rest) do
  Begin
   If Rest[I] = '[' Then Inc(Depth) Else If Rest[I] = ']' Then Begin Dec(Depth); If Depth = 0 Then Begin ClosePos := I; Break; End; End;
  End;
  If ClosePos = 0 Then Fatal('crochet fermant manquant');
  OptText := Copy(Rest, 2, ClosePos - 2); ParseOptionList(OptText);
  Rest := TrimStr(Copy(Rest, ClosePos + 1, Length(Rest)));
 End;
 P := Pos('=', Rest);
 If P > 0 Then
 Begin Opt.OutputName := TrimStr(Copy(Rest, 1, P - 1)); ParseInputs(Copy(Rest, P + 1, Length(Rest))); End
 Else Begin ParseInputs(Rest); If InputCount > 0 Then Opt.OutputName := BaseName68(Inputs[1].FileName) + '.68K'; End;
 If Opt.OutputName = '' Then Fatal('nom du fichier de sortie manquant');
 If InputCount = 0 Then Fatal('aucun fichier objet');
 Opt.OutputName := DefaultExtension(Opt.OutputName, '.68K');
End;

Procedure AllocateModuleBuffers(M: Integer);
Begin
 If Modules[M].SymCount > 0 Then GetMem(Modules[M].Symbols, LongInt(Modules[M].SymCount) * SizeOf(TSymbol))
 Else Modules[M].Symbols := Nil;
 GetMem(Modules[M].TextData, Modules[M].TextSize + 1);
 GetMem(Modules[M].DataData, Modules[M].DataSize + 1);
 GetMem(Modules[M].TextRel, ((Modules[M].TextSize + 1) div 2) * 2 + 2);
 GetMem(Modules[M].DataRel, ((Modules[M].DataSize + 1) div 2) * 2 + 2);
 FillChar(Modules[M].TextData^, Modules[M].TextSize, 0);
 FillChar(Modules[M].DataData^, Modules[M].DataSize, 0);
End;

Function ResolveInputName(Const RequestedName: String): String;
Var N: String;
Begin
 N := RequestedName;
 If FileExists68(N) Then Begin ResolveInputName := N; Exit; End;
 If Not HasExtension(N) Then
 Begin
  If FileExists68(N + '.O') Then Begin ResolveInputName := N + '.O'; Exit; End;
  If FileExists68(N + '.L68') Then Begin ResolveInputName := N + '.L68'; Exit; End;
  If FileExists68(N + '.A') Then Begin ResolveInputName := N + '.A'; Exit; End;
 End;
 N := UpCaseStr(RequestedName);
 If FileExists68(N) Then Begin ResolveInputName := N; Exit; End;
 If Not HasExtension(N) Then
 Begin
  If FileExists68(N + '.O') Then Begin ResolveInputName := N + '.O'; Exit; End;
  If FileExists68(N + '.L68') Then Begin ResolveInputName := N + '.L68'; Exit; End;
  If FileExists68(N + '.A') Then Begin ResolveInputName := N + '.A'; Exit; End;
 End;
 ResolveInputName := '';
End;

Procedure ReadObjectAt(Const FN, DisplayName: String; BasePos, MemberSize, OrderKey: LongInt;
                       IncludeLocals: Boolean);
Var F: File; Magic, AbsFlag: Word; SymBytes, Reserved, Entry: LongInt;
    I, J, N: Integer; C: Byte; HeaderSize, RelPos: LongInt;
Begin
 If ModuleCount >= MAX_MODULES Then Fatal('trop de modules');
 Inc(ModuleCount); Modules[ModuleCount].FileName := DisplayName;
 Modules[ModuleCount].OrderKey := OrderKey;
 Modules[ModuleCount].IncludeLocals := IncludeLocals;
 Assign(F, FN); Reset(F, 1); If IOResult <> 0 Then Fatal('impossible de lire ' + FN);
 SeekFile(F, BasePos);
 Magic := GetWord(F);
 If (Magic <> $601A) and (Magic <> $601B) Then Fatal(DisplayName + ': format DRI invalide');
 Modules[ModuleCount].TextSize := GetLong(F); Modules[ModuleCount].DataSize := GetLong(F);
 Modules[ModuleCount].BssSize := GetLong(F); SymBytes := GetLong(F);
 Reserved := GetLong(F); Entry := GetLong(F); AbsFlag := GetWord(F);
 HeaderSize := 28; If Magic = $601B Then Begin GetLong(F); GetLong(F); HeaderSize := 36; End;
 If (Modules[ModuleCount].TextSize < 0) or (Modules[ModuleCount].DataSize < 0) or
    (Modules[ModuleCount].TextSize > MAX_IMAGE) or (Modules[ModuleCount].DataSize > MAX_IMAGE) Then Fatal(DisplayName + ': segment trop grand');
 If (SymBytes mod 14) <> 0 Then Fatal(DisplayName + ': taille de table des symboles invalide');
 If SymBytes div 14 > MAX_SYMBOLS Then Fatal(FN + ': trop de symboles');
 Modules[ModuleCount].SymCount := SymBytes div 14;
 AllocateModuleBuffers(ModuleCount);
 If (MemberSize > 0) and (HeaderSize + Modules[ModuleCount].TextSize + Modules[ModuleCount].DataSize + SymBytes > MemberSize) Then
  Fatal(DisplayName + ': membre d''archive tronque');
 SeekFile(F, BasePos + HeaderSize);
 For I := 0 to Modules[ModuleCount].TextSize - 1 do Modules[ModuleCount].TextData^[I] := GetByte(F);
 For I := 0 to Modules[ModuleCount].DataSize - 1 do Modules[ModuleCount].DataData^[I] := GetByte(F);
 For I := 0 to Modules[ModuleCount].SymCount - 1 do
 Begin
  Modules[ModuleCount].Symbols^[I].Name := '';
  For J := 1 to 8 do Begin C := GetByte(F); If C <> 0 Then Modules[ModuleCount].Symbols^[I].Name := Modules[ModuleCount].Symbols^[I].Name + Chr(C); End;
  Modules[ModuleCount].Symbols^[I].SType := GetWord(F); Modules[ModuleCount].Symbols^[I].Value := GetLong(F);
 End;
 RelPos := BasePos + HeaderSize + Modules[ModuleCount].TextSize + Modules[ModuleCount].DataSize + SymBytes;
 If AbsFlag = 0 Then
 Begin
  SeekFile(F, RelPos); N := (Modules[ModuleCount].TextSize + 1) div 2;
  For I := 0 to N - 1 do Modules[ModuleCount].TextRel^[I] := GetWord(F);
  N := (Modules[ModuleCount].DataSize + 1) div 2;
  For I := 0 to N - 1 do Modules[ModuleCount].DataRel^[I] := GetWord(F);
 End
 Else Begin
  FillChar(Modules[ModuleCount].TextRel^, ((Modules[ModuleCount].TextSize + 1) div 2) * 2, 0);
  FillChar(Modules[ModuleCount].DataRel^, ((Modules[ModuleCount].DataSize + 1) div 2) * 2, 0);
 End;
 Close(F);
 If Reserved <> 0 Then Warning(DisplayName + ': champ reserve non nul');
 If Entry <> 0 Then Warning(DisplayName + ': point d''entree objet ignore');
End;

Function DecimalField(Const S: String): LongInt;
Var I: Integer; V: LongInt;
Begin V := 0; For I := 1 to Length(S) do If S[I] in ['0'..'9'] Then V := V * 10 + Ord(S[I]) - Ord('0'); DecimalField := V; End;

Function ReadAscii(Var F: File; N: Integer): String;
Var I: Integer; C: Char; R: String;
Begin R := ''; For I := 1 to N do Begin C := Chr(GetByte(F)); R := R + C; End; ReadAscii := R; End;

Procedure AddMember(InputIndex: Integer; Const Name: String; DataPos, DataSize: LongInt);
Begin
 If MemberCount >= MAX_MEMBERS Then Fatal('trop de membres de bibliotheque');
 Inc(MemberCount); Members[MemberCount].InputIndex := InputIndex;
 Members[MemberCount].Name := Name; Members[MemberCount].DataPos := DataPos;
 Members[MemberCount].DataSize := DataSize; Members[MemberCount].Loaded := False;
 Members[MemberCount].Selected := False;
End;

Procedure ReadUnixArchiveCatalog(InputIndex: Integer; Var F: File);
Var H, N, LongNames: String; P, Sz, NameLen, I: LongInt; C: Char;
Begin
 LongNames := ''; P := 8;
 While P + 60 <= FileSize(F) do
 Begin
  SeekFile(F, P); H := ReadAscii(F, 60);
  If Copy(H, 59, 2) <> '`' + Chr(10) Then Fatal(Inputs[InputIndex].FileName + ': entete archive invalide');
  N := TrimStr(Copy(H, 1, 16)); Sz := DecimalField(Copy(H, 49, 10));
  If (Sz < 0) or (P + 60 + Sz > FileSize(F)) Then Fatal(Inputs[InputIndex].FileName + ': membre archive tronque');
  If N = '//' Then Begin SeekFile(F, P + 60); LongNames := ReadAscii(F, Sz); End
  Else If (N = '/') or (N = '/SYM64/') Then Begin Inputs[InputIndex].IndexPos := P + 60; Inputs[InputIndex].IndexSize := Sz; End
  Else
  Begin
   NameLen := 0;
   If Copy(N, 1, 3) = '#1/' Then Begin NameLen := DecimalField(Copy(N, 4, Length(N))); SeekFile(F, P + 60); N := ReadAscii(F, NameLen); End
   Else If (Length(N) > 1) and (N[1] = '/') and (N[2] in ['0'..'9']) Then
   Begin
    I := DecimalField(Copy(N, 2, Length(N))); N := '';
    Inc(I); While (I <= Length(LongNames)) and not (LongNames[I] in ['/', Chr(10), Chr(13)]) do Begin N := N + LongNames[I]; Inc(I); End;
   End Else If (Length(N) > 0) and (N[Length(N)] = '/') Then Delete(N, Length(N), 1);
   AddMember(InputIndex, N, P + 60 + NameLen, Sz - NameLen);
  End;
  P := P + 60 + Sz; If Odd(P) Then Inc(P);
 End;
End;

Function GetLongBEAt(Var F: File; P: LongInt): LongInt;
Begin SeekFile(F, P); GetLongBEAt := GetLong(F); End;

Function MarkIndexedNeeded(InputIndex: Integer): Boolean;
Var F: File; Count, I, G, M: LongInt; NamePos, Offs, SavePos: LongInt; N: String[8]; C: Byte;
Begin
 MarkIndexedNeeded := False;
 If (Inputs[InputIndex].IndexPos = 0) or (Inputs[InputIndex].IndexSize < 4) Then Exit;
 Assign(F, Inputs[InputIndex].FileName); Reset(F, 1); If IOResult <> 0 Then Exit;
 Count := GetLongBEAt(F, Inputs[InputIndex].IndexPos);
 If (Count < 0) or (4 + Count * 4 > Inputs[InputIndex].IndexSize) Then Begin Close(F); Exit; End;
 NamePos := Inputs[InputIndex].IndexPos + 4 + Count * 4; SeekFile(F, NamePos);
 For I := 0 to Count - 1 do Begin
  N := '';
  While FilePos(F) < Inputs[InputIndex].IndexPos + Inputs[InputIndex].IndexSize do Begin C := GetByte(F); If C = 0 Then Break; If Length(N) < 8 Then N := N + Chr(C); End;
  G := FindGlobal(N);
  If (G > 0) and Globals[G].Needed and (not Globals[G].Defined) Then Begin
   SavePos := FilePos(F); Offs := GetLongBEAt(F, Inputs[InputIndex].IndexPos + 4 + I * 4); SeekFile(F, SavePos);
   For M := 1 to MemberCount do If (Members[M].InputIndex = InputIndex) and (Members[M].DataPos - 60 = Offs) and (not Members[M].Loaded) Then
   Begin Members[M].Selected := True; MarkIndexedNeeded := True; Break; End;
  End;
 End;
 Close(F);
End;

Function GetLongEndian(Var F: File; BigEndian: Boolean): LongInt;
Var B0, B1, B2, B3: Byte;
Begin B0 := GetByte(F); B1 := GetByte(F); B2 := GetByte(F); B3 := GetByte(F);
 If BigEndian Then GetLongEndian := LongInt((LongWord(B0) shl 24) or (LongWord(B1) shl 16) or (LongWord(B2) shl 8) or B3)
 Else GetLongEndian := LongInt((LongWord(B3) shl 24) or (LongWord(B2) shl 16) or (LongWord(B1) shl 8) or B0); End;

Function GetWordEndian(Var F: File; BigEndian: Boolean): Word;
Var A, B: Byte;
Begin A := GetByte(F); B := GetByte(F); If BigEndian Then GetWordEndian := Word(A) shl 8 or B Else GetWordEndian := Word(B) shl 8 or A; End;

Procedure ReadOldArchiveCatalog(InputIndex: Integer; Var F: File; BigEndian: Boolean);
Var P, Sz, Dummy: LongInt; N: String; I: Integer;
Begin
 P := 2;
 While P + 28 <= FileSize(F) do
 Begin
  SeekFile(F, P); N := '';
  For I := 1 to 14 do Begin If I = 1 Then N := ''; N := N + Chr(GetByte(F)); End;
  While (Length(N) > 0) and (N[Length(N)] in [#0, ' ']) do Delete(N, Length(N), 1);
  Dummy := GetLongEndian(F, BigEndian); GetByte(F); GetByte(F); GetByte(F); GetByte(F);
  Sz := GetLongEndian(F, BigEndian);
  Dummy := GetWordEndian(F, BigEndian);
  If (Sz < 0) or (P + 28 + Sz > FileSize(F)) Then Fatal(Inputs[InputIndex].FileName + ': membre AR68 tronque');
  AddMember(InputIndex, N, P + 28, Sz);
  P := P + 28 + Sz; If Odd(P) Then Inc(P);
 End;
End;

Procedure ReadVeryOldArchiveCatalog(InputIndex: Integer; Var F: File; BigEndian: Boolean);
Var P, Sz, Dummy: LongInt; N: String; I: Integer;
Begin
 P := 2;
 While P + 16 <= FileSize(F) do Begin
  SeekFile(F, P); N := ''; For I := 1 to 8 do N := N + Chr(GetByte(F));
  While (Length(N) > 0) and (N[Length(N)] in [#0, ' ']) do Delete(N, Length(N), 1);
  Dummy := GetLongEndian(F, BigEndian); GetByte(F); GetByte(F); Sz := GetWordEndian(F, BigEndian);
  If P + 16 + Sz > FileSize(F) Then Fatal(Inputs[InputIndex].FileName + ': ancien membre AR68 tronque');
  AddMember(InputIndex, N, P + 16, Sz); P := P + 16 + Sz; If Odd(P) Then Inc(P);
 End;
End;

Procedure CollectGlobalNeeds;
Var M, I, G: Integer; S: TSymbol;
Begin
 GlobalCount := 0;
 For M := 1 to ModuleCount do For I := 0 to Modules[M].SymCount - 1 do
 Begin
  S := Modules[M].Symbols^[I];
  If (S.SType and (SYM_GLOBAL or SYM_EXTERN)) = 0 Then Continue;
  G := FindGlobal(S.Name); If G = 0 Then G := AddGlobal(S.Name);
  If IsCommonSymbol(S) Then Begin Globals[G].Needed := True; Globals[G].IsCommon := True;
   If S.Value > Globals[G].CommonSize Then Globals[G].CommonSize := S.Value; End
  Else If (S.SType and SYM_DEFINED) <> 0 Then Globals[G].Defined := True Else Globals[G].Needed := True;
 End;
End;

Function MemberDefinesNeeded(MemberIndex: Integer): Boolean;
Var F: File; Magic: Word; TextSize, DataSize, BssSize, SymBytes, P: LongInt;
    I, J: Integer; N: String[8]; T: Word; C: Byte; G: Integer;
Begin
 MemberDefinesNeeded := False;
 Assign(F, Inputs[Members[MemberIndex].InputIndex].FileName); Reset(F, 1);
 If IOResult <> 0 Then Fatal('impossible de relire la bibliotheque');
 SeekFile(F, Members[MemberIndex].DataPos); Magic := GetWord(F);
  If (Magic <> $601A) and (Magic <> $601B) Then Begin Close(F); Exit; End;
 TextSize := GetLong(F); DataSize := GetLong(F); BssSize := GetLong(F); SymBytes := GetLong(F);
 GetLong(F); GetLong(F); GetWord(F); P := 28; If Magic = $601B Then P := 36;
 If (SymBytes < 0) or ((SymBytes mod 14) <> 0) or
    (P + TextSize + DataSize + SymBytes > Members[MemberIndex].DataSize) Then Begin Close(F); Exit; End;
 SeekFile(F, Members[MemberIndex].DataPos + P + TextSize + DataSize);
 For I := 1 to SymBytes div 14 do
 Begin
  N := ''; For J := 1 to 8 do Begin C := GetByte(F); If C <> 0 Then N := N + Chr(C); End;
  T := GetWord(F); GetLong(F);
  If ((T and (SYM_DEFINED or SYM_GLOBAL)) = (SYM_DEFINED or SYM_GLOBAL)) and ((T and SYM_EXTERN) = 0) Then
  Begin G := FindGlobal(N); If (G > 0) and Globals[G].Needed and (not Globals[G].Defined) Then Begin MemberDefinesNeeded := True; Break; End; End;
 End;
 Close(F);
End;

Function MemberNameMatches(Const A, B: String): Boolean;
Var X, Y: String;
Begin X := UpCaseStr(A); Y := UpCaseStr(B); MemberNameMatches := (X = Y) or (UpCaseStr(BaseName68(X)) = UpCaseStr(BaseName68(Y))); End;

Procedure LoadMember(MemberIndex: Integer);
Var I: Integer; D: String;
Begin
 I := Members[MemberIndex].InputIndex; D := Inputs[I].FileName + '(' + Members[MemberIndex].Name + ')';
 ReadObjectAt(Inputs[I].FileName, D, Members[MemberIndex].DataPos, Members[MemberIndex].DataSize,
              LongInt(I) * 10000 + MemberIndex, Inputs[I].IncludeLocals);
 Members[MemberIndex].Loaded := True;
End;

Procedure LoadInputs;
Var I, M: Integer; F: File; S: String; B0, B1: Byte; Changed, Found: Boolean;
Begin
 MemberCount := 0;
 For I := 1 to InputCount do
 Begin
  S := ResolveInputName(Inputs[I].FileName);
  If S = '' Then Fatal('fichier d''entree introuvable: ' + Inputs[I].FileName);
  Inputs[I].FileName := S; Assign(F, S); Reset(F, 1); If IOResult <> 0 Then Fatal('impossible de lire ' + S);
  If FileSize(F) < 2 Then Fatal(S + ': fichier vide');
  B0 := GetByte(F); B1 := GetByte(F);
  If (B0 = $60) and (B1 in [$1A, $1B]) Then
  Begin Close(F); ReadObjectAt(S, S, 0, 0, LongInt(I) * 10000, Inputs[I].IncludeLocals); End
  Else
  Begin
   SeekFile(F, 0); If (FileSize(F) >= 8) and (ReadAscii(F, 8) = '!<arch>' + Chr(10)) Then ReadUnixArchiveCatalog(I, F)
   Else If (B0 = $FF) and (B1 = $65) Then ReadOldArchiveCatalog(I, F, True)
   Else If (B0 = $FF) and (B1 = $66) Then ReadOldArchiveCatalog(I, F, True)
   Else If (B0 = $65) and (B1 = $FF) Then ReadOldArchiveCatalog(I, F, False)
   Else If (B0 = $66) and (B1 = $FF) Then ReadOldArchiveCatalog(I, F, False)
   Else If (B0 = $FF) and (B1 = $6D) Then ReadVeryOldArchiveCatalog(I, F, True)
   Else If (B0 = $6D) and (B1 = $FF) Then ReadVeryOldArchiveCatalog(I, F, False)
   Else Begin Close(F); Fatal(S + ': ni objet DRI ni bibliotheque AR68'); End;
   Close(F);
  End;
 End;
 For I := 1 to InputCount do If Inputs[I].AllMods or (Inputs[I].IncludeName <> '') Then
 Begin
  Found := Inputs[I].IncludeName = '';
  For M := 1 to MemberCount do If Members[M].InputIndex = I Then
   If Inputs[I].AllMods or MemberNameMatches(Members[M].Name, Inputs[I].IncludeName) Then
   Begin If not Members[M].Loaded Then LoadMember(M); If Inputs[I].IncludeName <> '' Then Found := True; End;
  If not Found Then Error(Inputs[I].FileName + ': module INCLUDE introuvable: ' + Inputs[I].IncludeName);
 End;
 Repeat
  CollectGlobalNeeds; Changed := False;
  For I := 1 to InputCount do If MarkIndexedNeeded(I) Then
   For M := 1 to MemberCount do If Members[M].Selected and (not Members[M].Loaded) Then Begin LoadMember(M); Changed := True; End;
  If Changed Then CollectGlobalNeeds;
  For M := 1 to MemberCount do If (not Members[M].Loaded) and MemberDefinesNeeded(M) Then
  Begin LoadMember(M); Changed := True; CollectGlobalNeeds; End;
 Until not Changed;
End;

Procedure SortModules;
Var I, J: Integer; T: TModule;
Begin
 For I := 2 to ModuleCount do Begin T := Modules[I]; J := I - 1;
  While (J > 0) and (Modules[J].OrderKey > T.OrderKey) do Begin Modules[J + 1] := Modules[J]; Dec(J); End;
  Modules[J + 1] := T;
 End;
End;

Procedure LayoutModules;
Var I: Integer;
Begin
 TotalText := 0; TotalData := 0; TotalBss := 0;
 For I := 1 to ModuleCount do Begin Modules[I].TextOffset := TotalText; Inc(TotalText, Modules[I].TextSize); If Odd(TotalText) Then Inc(TotalText); End;
 For I := 1 to ModuleCount do Begin Modules[I].DataOffset := TotalData; Inc(TotalData, Modules[I].DataSize); If Odd(TotalData) Then Inc(TotalData); End;
 For I := 1 to ModuleCount do Begin Modules[I].BssOffset := TotalBss; Inc(TotalBss, Modules[I].BssSize); If Odd(TotalBss) Then Inc(TotalBss); End;
 If Not Opt.TextBaseSet Then Opt.TextBase := 0;
 If Not Opt.DataBaseSet Then Opt.DataBase := Opt.TextBase + TotalText;
 If Not Opt.BssBaseSet Then Opt.BssBase := Opt.DataBase + TotalData;
End;

Function SymbolFinalValue(M: Integer; Const S: TSymbol): LongInt;
Begin
 Case SegmentOf(S.SType) of
  REL_TEXT: SymbolFinalValue := Opt.TextBase + Modules[M].TextOffset + S.Value;
  REL_DATA: SymbolFinalValue := Opt.DataBase + Modules[M].DataOffset + S.Value;
  REL_BSS:  SymbolFinalValue := Opt.BssBase + Modules[M].BssOffset + S.Value;
 Else SymbolFinalValue := S.Value;
 End;
End;

Procedure BuildGlobals;
Var M, I, G: Integer; S: TSymbol;
Begin
 GlobalCount := 0;
 For M := 1 to ModuleCount do For I := 0 to Modules[M].SymCount - 1 do
 Begin
  S := Modules[M].Symbols^[I];
  If (S.SType and (SYM_GLOBAL or SYM_EXTERN)) = 0 Then Continue;
  G := FindGlobal(S.Name); If G = 0 Then G := AddGlobal(S.Name);
  If IsCommonSymbol(S) Then
  Begin
   Globals[G].Needed := True; Globals[G].IsCommon := True;
   If S.Value > Globals[G].CommonSize Then Globals[G].CommonSize := S.Value;
  End
  Else If (S.SType and SYM_DEFINED) <> 0 Then
  Begin
   If Globals[G].Defined Then Error('symbole defini plusieurs fois: ' + S.Name)
   Else Begin Globals[G].Defined := True; Globals[G].ModuleIndex := M; Globals[G].SymbolIndex := I;
    Globals[G].FinalType := S.SType; Globals[G].FinalValue := SymbolFinalValue(M, S); End;
  End Else Globals[G].Needed := True;
 End;
 For G := 1 to GlobalCount do If Globals[G].IsCommon and (not Globals[G].Defined) Then
 Begin
  If Odd(TotalBss) Then Inc(TotalBss);
  Globals[G].Defined := True; Globals[G].FinalType := SYM_DEFINED or SYM_GLOBAL or SYM_BSS;
  Globals[G].FinalValue := Opt.BssBase + TotalBss;
  Inc(TotalBss, (Globals[G].CommonSize + 1) and not 1);
 End;
 For G := 1 to GlobalCount do If Globals[G].Needed and (not Globals[G].Defined) Then
  If Opt.AllowUndefined Then Warning('symbole non defini conserve: ' + Globals[G].Name)
  Else Error('symbole non defini: ' + Globals[G].Name);
End;

Function ReadLongBuf(B: PByteBuffer; P: LongInt): LongInt;
Begin ReadLongBuf := LongInt((LongWord(B^[P]) shl 24) or (LongWord(B^[P+1]) shl 16) or (LongWord(B^[P+2]) shl 8) or B^[P+3]); End;

Procedure WriteLongBuf(B: PByteBuffer; P: LongInt; V: LongInt);
Begin B^[P] := Byte(LongWord(V) shr 24); B^[P+1] := Byte(LongWord(V) shr 16); B^[P+2] := Byte(LongWord(V) shr 8); B^[P+3] := Byte(V); End;

Function ReadWordBuf(B: PByteBuffer; P: LongInt): Word;
Begin ReadWordBuf := Word(B^[P]) shl 8 or B^[P+1]; End;

Procedure WriteWordBuf(B: PByteBuffer; P: LongInt; V: Word);
Begin B^[P] := Byte(V shr 8); B^[P+1] := Byte(V); End;

Function RelocBase(M, RType: Integer): LongInt;
Begin
 Case RType of
  REL_TEXT: RelocBase := Opt.TextBase + Modules[M].TextOffset;
  REL_DATA: RelocBase := Opt.DataBase + Modules[M].DataOffset;
  REL_BSS: RelocBase := Opt.BssBase + Modules[M].BssOffset;
 Else RelocBase := 0;
 End;
End;

Function OutputSymbolIndex(G: Integer): Integer;
Var I, N: Integer;
Begin
 N := 0;
 For I := 1 to G do If Opt.EmitSymbols or (not Globals[I].Defined) Then Inc(N);
 OutputSymbolIndex := N - 1;
End;

Procedure CheckShortOverflow(Value: LongInt; SignedOnly: Boolean; Const Where: String);
Var Bad: Boolean;
Begin
 If SignedOnly Then Bad := (Value < -32768) or (Value > 32767)
 Else Bad := (Value < -32768) or (Value > 65535);
 If Bad Then
  If Opt.IgnoreOverflow Then Warning('debordement 16 bits ignore: ' + Where)
  Else Error('debordement 16 bits: ' + Where);
End;

Procedure ApplyOneRelocation(M: Integer; Src: PByteBuffer; SrcRel: PWordBuffer;
                             Dst: PByteBuffer; DstRel: PWordBuffer;
                             SrcSize, DstBase: LongInt);
Var WI, Words, RT, NextRT, SI, G: Integer; P: LongInt; V32: LongInt; V16: Word;
    AddValue, FullValue: LongInt; OutType: Word; SName: String;
Begin
 Words := (SrcSize + 1) div 2; WI := 0;
 While WI < Words do
 Begin
  P := LongInt(WI) * 2; RT := SrcRel^[WI] and 7; AddValue := 0; OutType := RT;
  If RT = REL_UPPER Then
  Begin
   If WI + 1 >= Words Then Begin Error(Modules[M].FileName + ': relogement long tronque'); Exit; End;
   NextRT := SrcRel^[WI + 1] and 7;
   If NextRT = REL_PCREL Then Begin Error(Modules[M].FileName + ': PCREL long invalide'); NextRT := REL_ABS; End;
   If NextRT in [REL_TEXT, REL_DATA, REL_BSS] Then AddValue := RelocBase(M, NextRT)
   Else If NextRT = REL_EXTERN Then
   Begin
    SI := SrcRel^[WI + 1] shr 3;
    If SI >= Modules[M].SymCount Then Begin Error('index de symbole externe invalide'); SI := 0; End;
    SName := Modules[M].Symbols^[SI].Name; G := FindGlobal(SName);
    If (G > 0) and Globals[G].Defined Then Begin AddValue := Globals[G].FinalValue; NextRT := SegmentOf(Globals[G].FinalType); End
    Else If Opt.AllowUndefined and (G > 0) Then NextRT := (OutputSymbolIndex(G) shl 3) or REL_EXTERN
    Else NextRT := REL_ABS;
   End;
   V32 := ReadLongBuf(Src, P) + AddValue; WriteLongBuf(Dst, DstBase + P, V32);
   If Opt.Absolute Then Begin DstRel^[(DstBase div 2) + WI] := 0; DstRel^[(DstBase div 2) + WI + 1] := 0; End
   Else Begin DstRel^[(DstBase div 2) + WI] := REL_UPPER; DstRel^[(DstBase div 2) + WI + 1] := NextRT; End;
   Inc(WI, 2); Continue;
  End;
  If RT in [REL_TEXT, REL_DATA, REL_BSS] Then AddValue := RelocBase(M, RT)
  Else If RT = REL_EXTERN Then
  Begin
   SI := SrcRel^[WI] shr 3;
   If SI >= Modules[M].SymCount Then Begin Error('index de symbole externe invalide'); SI := 0; End;
   SName := Modules[M].Symbols^[SI].Name; G := FindGlobal(SName);
   If (G > 0) and Globals[G].Defined Then Begin AddValue := Globals[G].FinalValue; OutType := SegmentOf(Globals[G].FinalType); End
   Else If Opt.AllowUndefined and (G > 0) Then OutType := (OutputSymbolIndex(G) shl 3) or REL_EXTERN
   Else OutType := REL_ABS;
  End
  Else If RT = REL_PCREL Then
  Begin
   SI := SrcRel^[WI] shr 3;
   If SI >= Modules[M].SymCount Then Begin Error(Modules[M].FileName + ': index PCREL invalide'); SI := 0; End;
   SName := Modules[M].Symbols^[SI].Name; G := FindGlobal(SName);
   If (G > 0) and Globals[G].Defined Then AddValue := Globals[G].FinalValue - (Opt.TextBase + Modules[M].TextOffset + P)
   Else Begin Error(Modules[M].FileName + ': symbole PCREL non defini: ' + SName); AddValue := 0; End;
   OutType := REL_ABS;
  End
  Else If (RT <> REL_ABS) and (RT <> REL_INSTR) Then Error(Modules[M].FileName + ': type de relogement invalide');
  If P + 1 < SrcSize Then Begin
   V16 := ReadWordBuf(Src, P); FullValue := SmallInt(V16) + AddValue;
   If RT = REL_PCREL Then CheckShortOverflow(FullValue, True, Modules[M].FileName)
   Else If RT in [REL_TEXT, REL_DATA, REL_BSS, REL_EXTERN] Then CheckShortOverflow(FullValue, False, Modules[M].FileName);
   WriteWordBuf(Dst, DstBase + P, Word(FullValue));
  End
  Else Dst^[DstBase + P] := Src^[P];
  If Opt.Absolute Then DstRel^[(DstBase div 2) + WI] := 0 Else DstRel^[(DstBase div 2) + WI] := OutType;
  Inc(WI);
 End;
End;

Procedure LinkModules;
Var M, I: Integer;
Begin
 GetMem(OutText, TotalText + 1); GetMem(OutData, TotalData + 1);
 GetMem(OutTextRel, ((TotalText + 1) div 2) * 2 + 2);
 GetMem(OutDataRel, ((TotalData + 1) div 2) * 2 + 2);
 FillChar(OutText^, TotalText, 0); FillChar(OutData^, TotalData, 0);
 FillChar(OutTextRel^, ((TotalText + 1) div 2) * 2, 0); FillChar(OutDataRel^, ((TotalData + 1) div 2) * 2, 0);
 For M := 1 to ModuleCount do
 Begin
  For I := 0 to Modules[M].TextSize - 1 do OutText^[Modules[M].TextOffset + I] := Modules[M].TextData^[I];
  For I := 0 to Modules[M].DataSize - 1 do OutData^[Modules[M].DataOffset + I] := Modules[M].DataData^[I];
  ApplyOneRelocation(M, Modules[M].TextData, Modules[M].TextRel, OutText, OutTextRel, Modules[M].TextSize, Modules[M].TextOffset);
  ApplyOneRelocation(M, Modules[M].DataData, Modules[M].DataRel, OutData, OutDataRel, Modules[M].DataSize, Modules[M].DataOffset);
 End;
End;

Function OutputSymbolCount: Integer;
Var I, M, N: Integer; S: TSymbol;
Begin
 N := 0;
 For I := 1 to GlobalCount do If Opt.EmitSymbols or (not Globals[I].Defined) Then Inc(N);
 If Opt.EmitSymbols Then For M := 1 to ModuleCount do If Modules[M].IncludeLocals Then
  For I := 0 to Modules[M].SymCount - 1 do
  Begin
   S := Modules[M].Symbols^[I];
   If ((S.SType and (SYM_GLOBAL or SYM_EXTERN)) = 0) and
      ((Length(S.Name) = 0) or (UpCase(S.Name[1]) <> 'L')) Then Inc(N);
  End;
 OutputSymbolCount := N;
End;

Procedure WriteOutput;
Var F: File; I, J, M, SymN: Integer; Magic, ST: Word; NonContiguous: Boolean; S: TSymbol;
Begin
 Assign(F, Opt.OutputName); Rewrite(F, 1); If IOResult <> 0 Then Fatal('impossible de creer ' + Opt.OutputName);
 NonContiguous := (Opt.DataBase <> Opt.TextBase + TotalText) or (Opt.BssBase <> Opt.DataBase + TotalData);
 If NonContiguous Then Magic := $601B Else Magic := $601A;
 SymN := OutputSymbolCount;
 PutWord(F, Magic); PutLong(F, TotalText); PutLong(F, TotalData); PutLong(F, TotalBss);
 PutLong(F, LongInt(SymN) * 14); PutLong(F, 0); PutLong(F, Opt.TextBase);
 If Opt.Absolute Then PutWord(F, 1) Else PutWord(F, 0);
 If NonContiguous Then Begin PutLong(F, Opt.DataBase); PutLong(F, Opt.BssBase); End;
 For I := 0 to TotalText - 1 do PutByte(F, OutText^[I]);
 For I := 0 to TotalData - 1 do PutByte(F, OutData^[I]);
 For I := 1 to GlobalCount do If Opt.EmitSymbols or (not Globals[I].Defined) Then
 Begin
  For J := 1 to 8 do If J <= Length(Globals[I].Name) Then PutByte(F, Ord(Globals[I].Name[J])) Else PutByte(F, 0);
  If Globals[I].Defined Then Begin ST := Globals[I].FinalType or SYM_DEFINED or SYM_GLOBAL; PutWord(F, ST); PutLong(F, Globals[I].FinalValue); End
  Else Begin PutWord(F, SYM_EXTERN or SYM_GLOBAL); PutLong(F, 0); End;
 End;
 If Opt.EmitSymbols Then For M := 1 to ModuleCount do If Modules[M].IncludeLocals Then
  For I := 0 to Modules[M].SymCount - 1 do
  Begin
   S := Modules[M].Symbols^[I];
   If ((S.SType and (SYM_GLOBAL or SYM_EXTERN)) = 0) and
      ((Length(S.Name) = 0) or (UpCase(S.Name[1]) <> 'L')) Then
   Begin
    For J := 1 to 8 do If J <= Length(S.Name) Then PutByte(F, Ord(S.Name[J])) Else PutByte(F, 0);
    PutWord(F, S.SType); PutLong(F, SymbolFinalValue(M, S));
   End;
  End;
 If Not Opt.Absolute Then
 Begin
  For I := 0 to (TotalText div 2) - 1 do PutWord(F, OutTextRel^[I]);
  For I := 0 to (TotalData div 2) - 1 do PutWord(F, OutDataRel^[I]);
 End;
 Close(F);
End;

Procedure FreeAll;
Var I: Integer;
Begin
 For I := 1 to ModuleCount do Begin
  If Modules[I].Symbols <> Nil Then FreeMem(Modules[I].Symbols, LongInt(Modules[I].SymCount) * SizeOf(TSymbol));
  FreeMem(Modules[I].TextData, Modules[I].TextSize + 1); FreeMem(Modules[I].DataData, Modules[I].DataSize + 1);
  FreeMem(Modules[I].TextRel, ((Modules[I].TextSize + 1) div 2) * 2 + 2);
  FreeMem(Modules[I].DataRel, ((Modules[I].DataSize + 1) div 2) * 2 + 2);
 End;
 If OutText <> Nil Then FreeMem(OutText, TotalText + 1); If OutData <> Nil Then FreeMem(OutData, TotalData + 1);
 If OutTextRel <> Nil Then FreeMem(OutTextRel, ((TotalText + 1) div 2) * 2 + 2);
 If OutDataRel <> Nil Then FreeMem(OutDataRel, ((TotalData + 1) div 2) * 2 + 2);
End;

Procedure Run;
Begin
 ErrorCount := 0; WarningCount := 0; ModuleCount := 0; GlobalCount := 0; MemberCount := 0;
 OutText := Nil; OutData := Nil; OutTextRel := Nil; OutDataRel := Nil;
 ParseCommandLine;
 LoadInputs; SortModules;
 LayoutModules; BuildGlobals;
 If ErrorCount = 0 Then Begin LinkModules; If ErrorCount = 0 Then WriteOutput; End;
 WriteLn('LINK68: ', ModuleCount, ' module(s), TEXT=', TotalText,
         ', DATA=', TotalData, ', BSS=', TotalBss,
         ', symboles=', GlobalCount, ', erreurs=', ErrorCount);
 If ErrorCount = 0 Then WriteLn('LINK68: fichier produit: ', Opt.OutputName);
 FreeAll;
 If ErrorCount <> 0 Then Halt(1);
End;

Begin
 Run;
End.
