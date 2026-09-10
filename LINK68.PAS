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

 MAX_OVERLAYS = 255;
 MAX_OV_DEPTH = 5;
 OVTAB_SIZE   = 16;
 OVCALL_SIZE  = 16;

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

 POverlay = ^TOverlay;
 PJump = ^TJump;

 PModule = ^TModule;
 TModule = Record
 Next : PModule;
  Overlay : POverlay;
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

 PGlobal = ^TGlobal;
 TGlobal = Record
 Next : PGlobal;
  Overlay : POverlay;
  Name : String[8];
  ModuleIndex, SymbolIndex : Integer;
  Defined, Needed : Boolean;
  IsCommon : Boolean;
  CommonSize : LongInt;
  FinalType : Word;
 FinalValue : LongInt;
 End;

 TJump = Record
  Next : PJump;
  Target : PGlobal;
  Address : LongInt;
 End;

 TOverlay = Record
  NextAll, Parent, FirstChild, LastChild, NextSibling : POverlay;
  FirstJump, LastJump : PJump;
  Number, Depth, JumpCount : Integer;
  OutputName : String;
  ModuleText, ModuleData, ModuleBss : LongInt;
  TextSize, DataSize, BssSize : LongInt;
  TextBase, DataBase, BssBase, Capacity : LongInt;
 End;

 TOptions = Record
  AllowUndefined, EmitSymbols, EmitLocals, Absolute, AllMods, IgnoreOverflow : Boolean;
  TextBaseSet, DataBaseSet, BssBaseSet : Boolean;
  TextBase, DataBase, BssBase : LongInt;
  OutputName : String;
  TempPath : String;
 End;

 PInput = ^TInput;
 TInput = Record
 Next : PInput;
  Overlay : POverlay;
  FileName : String;
  IncludeLocals, AllMods : Boolean;
  IncludeName : String[64];
  IndexPos, IndexSize : LongInt;
 End;

 PMember = ^TMember;
 TMember = Record
  Next : PMember;
  InputIndex : Integer;
  Name : String[64];
  DataPos, DataSize : LongInt;
  Loaded, Selected : Boolean;
 End;

Var
 Opt : TOptions;
 FirstModule, LastModule : PModule;
 ModuleCount : Integer;
 FirstGlobal, LastGlobal : PGlobal;
 GlobalCount : Integer;
 FirstInput, LastInput : PInput;
 InputCount : Integer;
 FirstMember, LastMember : PMember;
 MemberCount : Integer;
 RootOverlay, FirstOverlay, LastOverlay : POverlay;
 OverlayCount : Integer;
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

Function ModuleAt(Index: Integer): PModule;
Var P: PModule; I: Integer;
Begin P := FirstModule; I := 1; While (P <> Nil) and (I < Index) do Begin P := P^.Next; Inc(I); End;
 If P = Nil Then Fatal('index de module interne invalide'); ModuleAt := P; End;

Function GlobalAt(Index: Integer): PGlobal;
Var P: PGlobal; I: Integer;
Begin P := FirstGlobal; I := 1; While (P <> Nil) and (I < Index) do Begin P := P^.Next; Inc(I); End;
 If P = Nil Then Fatal('index de symbole global interne invalide'); GlobalAt := P; End;

Function InputAt(Index: Integer): PInput;
Var P: PInput; I: Integer;
Begin P := FirstInput; I := 1; While (P <> Nil) and (I < Index) do Begin P := P^.Next; Inc(I); End;
 If P = Nil Then Fatal('index d''entree interne invalide'); InputAt := P; End;

Function MemberAt(Index: Integer): PMember;
Var P: PMember; I: Integer;
Begin P := FirstMember; I := 1; While (P <> Nil) and (I < Index) do Begin P := P^.Next; Inc(I); End;
 If P = Nil Then Fatal('index de membre interne invalide'); MemberAt := P; End;

Function AppendModule: PModule;
Var P: PModule;
Begin New(P); FillChar(P^, SizeOf(TModule), 0); If FirstModule = Nil Then FirstModule := P Else LastModule^.Next := P;
 LastModule := P; Inc(ModuleCount); AppendModule := P; End;

Function AppendGlobal: PGlobal;
Var P: PGlobal;
Begin New(P); FillChar(P^, SizeOf(TGlobal), 0); If FirstGlobal = Nil Then FirstGlobal := P Else LastGlobal^.Next := P;
 LastGlobal := P; Inc(GlobalCount); AppendGlobal := P; End;

Function AppendInput: PInput;
Var P: PInput;
Begin New(P); FillChar(P^, SizeOf(TInput), 0); If FirstInput = Nil Then FirstInput := P Else LastInput^.Next := P;
 LastInput := P; Inc(InputCount); AppendInput := P; End;

Function AppendMember: PMember;
Var P: PMember;
Begin New(P); FillChar(P^, SizeOf(TMember), 0); If FirstMember = Nil Then FirstMember := P Else LastMember^.Next := P;
 LastMember := P; Inc(MemberCount); AppendMember := P; End;

Function AppendOverlay(Parent: POverlay): POverlay;
Var P: POverlay;
Begin
 New(P); FillChar(P^, SizeOf(TOverlay), 0); P^.Parent := Parent;
 If Parent = Nil Then Begin P^.Number := 0; P^.Depth := 0; RootOverlay := P; End
 Else Begin
  If OverlayCount >= MAX_OVERLAYS Then Fatal('plus de 255 overlays');
  P^.Number := OverlayCount + 1; P^.Depth := Parent^.Depth + 1;
  If P^.Depth > MAX_OV_DEPTH Then Fatal('plus de cinq niveaux d''overlays');
  If Parent^.FirstChild = Nil Then Parent^.FirstChild := P Else Parent^.LastChild^.NextSibling := P;
  Parent^.LastChild := P; Inc(OverlayCount);
 End;
 If FirstOverlay = Nil Then FirstOverlay := P Else LastOverlay^.NextAll := P;
 LastOverlay := P; AppendOverlay := P;
End;

Procedure ClearGlobals;
Var P, N: PGlobal;
Begin P := FirstGlobal; While P <> Nil do Begin N := P^.Next; Dispose(P); P := N; End;
 FirstGlobal := Nil; LastGlobal := Nil; GlobalCount := 0; End;

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
Var I: Integer; P: PGlobal;
Begin
 I := 1; P := FirstGlobal;
 While P <> Nil do Begin If P^.Name = Name Then Begin FindGlobal := I; Exit; End; P := P^.Next; Inc(I); End;
 FindGlobal := 0;
End;

Function AddGlobal(Const Name: String): Integer;
Var P: PGlobal;
Begin
 P := AppendGlobal; P^.Name := Name; AddGlobal := GlobalCount;
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
 WriteLn('Overlays : sortie=root,(OV1=a,b),(OV2=c,(OV3=d)); fichiers .068 par defaut');
 WriteLn('           255 overlays maximum, cinq niveaux maximum');
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

Procedure AddInputToOverlay(S: String; O: POverlay);
Var P, Q: Integer; LocalOpt, U: String; IP: PInput;
Begin
 S := TrimStr(S); If S = '' Then Exit;
 P := Pos('[', S);
 LocalOpt := '';
 If P > 0 Then Begin LocalOpt := UpCaseStr(Copy(S, P + 1, Length(S) - P - 1)); S := TrimStr(Copy(S, 1, P - 1)); End;
 IP := AppendInput; IP^.FileName := S; IP^.Overlay := O;
 IP^.IncludeLocals := Opt.EmitLocals or (Pos('LOCALS', LocalOpt) > 0) or (LocalOpt = 'LO');
 If (Pos('NOLOCALS', LocalOpt) > 0) or (LocalOpt = 'NO') Then IP^.IncludeLocals := False;
 IP^.AllMods := Opt.AllMods or (Pos('ALLMODS', LocalOpt) > 0) or (LocalOpt = 'AL');
 IP^.IncludeName := '';
 U := LocalOpt; P := Pos('INCLUDE', U); If P = 0 Then P := Pos('IN[', U);
 If P > 0 Then Begin
  P := Pos('[', U); Q := Pos(']', U);
  If (P > 0) and (Q > P) Then IP^.IncludeName := TrimStr(Copy(U, P + 1, Q - P - 1))
  Else Begin Delete(U, 1, Length('INCLUDE')); IP^.IncludeName := TrimStr(U); End;
 End;
End;

Function FindTopLevelChar(Const S: String; Wanted: Char): Integer;
Var I, ParenDepth, BracketDepth: Integer;
Begin
 FindTopLevelChar := 0; ParenDepth := 0; BracketDepth := 0;
 For I := 1 to Length(S) do
 Begin
  If S[I] = '[' Then Inc(BracketDepth) Else If S[I] = ']' Then Dec(BracketDepth)
  Else If BracketDepth = 0 Then Begin
   If S[I] = '(' Then Inc(ParenDepth) Else If S[I] = ')' Then Dec(ParenDepth)
   Else If (S[I] = Wanted) and (ParenDepth = 0) Then Begin FindTopLevelChar := I; Exit; End;
  End;
 End;
End;

Procedure ParseNodeItems(Const S: String; O: POverlay);
Var I, Start, Depth, BracketDepth, EqPos, ClosePos: Integer; Part, Body: String; Child: POverlay;
Begin
 I := 1; Start := 1; BracketDepth := 0;
 While I <= Length(S) + 1 do
 Begin
  If I <= Length(S) Then Begin
   If S[I] = '[' Then Inc(BracketDepth) Else If S[I] = ']' Then Dec(BracketDepth);
  End;
  If (I <= Length(S)) and (BracketDepth = 0) and (S[I] = '(') Then
  Begin
   If TrimStr(Copy(S, Start, I - Start)) <> '' Then AddInputToOverlay(Copy(S, Start, I - Start), O);
   Depth := 1; ClosePos := I + 1;
   While (ClosePos <= Length(S)) and (Depth > 0) do Begin
    If S[ClosePos] = '(' Then Inc(Depth) Else If S[ClosePos] = ')' Then Dec(Depth); Inc(ClosePos);
   End;
   If Depth <> 0 Then Fatal('parenthese fermante manquante');
   Body := TrimStr(Copy(S, I + 1, ClosePos - I - 2)); Child := AppendOverlay(O);
   EqPos := FindTopLevelChar(Body, '=');
   If EqPos > 0 Then Begin Child^.OutputName := TrimStr(Copy(Body, 1, EqPos - 1)); Delete(Body, 1, EqPos); End;
   ParseNodeItems(Body, Child);
   I := ClosePos; Start := I + 1;
   If (I <= Length(S)) and (S[I] = ',') Then Begin Inc(I); Start := I; End;
   Continue;
  End;
  If (I > Length(S)) or ((S[I] = ',') and (BracketDepth = 0)) Then Begin
   Part := TrimStr(Copy(S, Start, I - Start)); If Part <> '' Then AddInputToOverlay(Part, O); Start := I + 1;
  End;
  Inc(I);
 End;
End;

Procedure SetDefaultOverlayNames;
Var O: POverlay; IP: PInput;
Begin
 O := FirstOverlay;
 While O <> Nil do Begin
  If (O <> RootOverlay) and (O^.OutputName = '') Then Begin
   IP := FirstInput; While (IP <> Nil) and (IP^.Overlay <> O) do IP := IP^.Next;
   If IP = Nil Then Fatal('overlay vide');
   O^.OutputName := BaseName68(IP^.FileName) + '.068';
  End;
  If O <> RootOverlay Then O^.OutputName := DefaultExtension(O^.OutputName, '.068');
  O := O^.NextAll;
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
 P := FindTopLevelChar(Rest, '=');
 If P > 0 Then
 Begin Opt.OutputName := TrimStr(Copy(Rest, 1, P - 1)); ParseNodeItems(Copy(Rest, P + 1, Length(Rest)), RootOverlay); End
 Else Begin ParseNodeItems(Rest, RootOverlay); If InputCount > 0 Then Opt.OutputName := BaseName68(FirstInput^.FileName) + '.68K'; End;
 If Opt.OutputName = '' Then Fatal('nom du fichier de sortie manquant');
 If InputCount = 0 Then Fatal('aucun fichier objet');
 Opt.OutputName := DefaultExtension(Opt.OutputName, '.68K');
 RootOverlay^.OutputName := Opt.OutputName; SetDefaultOverlayNames;
 If (OverlayCount > 0) and (Opt.DataBaseSet or Opt.BssBaseSet) Then
  Fatal('DATABASE et BSSBASE sont incompatibles avec les overlays');
End;

Procedure AllocateModuleBuffers(M: Integer);
Var MP: PModule;
Begin
 MP := ModuleAt(M);
 If MP^.SymCount > 0 Then GetMem(MP^.Symbols, LongInt(MP^.SymCount) * SizeOf(TSymbol)) Else MP^.Symbols := Nil;
 GetMem(MP^.TextData, MP^.TextSize + 1); GetMem(MP^.DataData, MP^.DataSize + 1);
 GetMem(MP^.TextRel, ((MP^.TextSize + 1) div 2) * 2 + 2); GetMem(MP^.DataRel, ((MP^.DataSize + 1) div 2) * 2 + 2);
 FillChar(MP^.TextData^, MP^.TextSize, 0); FillChar(MP^.DataData^, MP^.DataSize, 0);
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
                       IncludeLocals: Boolean; O: POverlay);
Var F: File; Magic, AbsFlag: Word; SymBytes, Reserved, Entry: LongInt;
    I, J, N: Integer; C: Byte; HeaderSize, RelPos: LongInt; MP: PModule;
Begin
 MP := AppendModule; MP^.FileName := DisplayName; MP^.OrderKey := OrderKey; MP^.IncludeLocals := IncludeLocals; MP^.Overlay := O;
 Assign(F, FN); Reset(F, 1); If IOResult <> 0 Then Fatal('impossible de lire ' + FN);
 SeekFile(F, BasePos);
 Magic := GetWord(F);
 If (Magic <> $601A) and (Magic <> $601B) Then Fatal(DisplayName + ': format DRI invalide');
 MP^.TextSize := GetLong(F); MP^.DataSize := GetLong(F); MP^.BssSize := GetLong(F); SymBytes := GetLong(F);
 Reserved := GetLong(F); Entry := GetLong(F); AbsFlag := GetWord(F);
 HeaderSize := 28; If Magic = $601B Then Begin GetLong(F); GetLong(F); HeaderSize := 36; End;
 If (MP^.TextSize < 0) or (MP^.DataSize < 0) or (MP^.TextSize > MAX_IMAGE) or (MP^.DataSize > MAX_IMAGE) Then Fatal(DisplayName + ': segment trop grand');
 If (SymBytes mod 14) <> 0 Then Fatal(DisplayName + ': taille de table des symboles invalide');
 If SymBytes div 14 > MAX_SYMBOLS Then Fatal(FN + ': trop de symboles');
 MP^.SymCount := SymBytes div 14;
 AllocateModuleBuffers(ModuleCount);
 If (MemberSize > 0) and (HeaderSize + MP^.TextSize + MP^.DataSize + SymBytes > MemberSize) Then
  Fatal(DisplayName + ': membre d''archive tronque');
 SeekFile(F, BasePos + HeaderSize);
 For I := 0 to MP^.TextSize - 1 do MP^.TextData^[I] := GetByte(F);
 For I := 0 to MP^.DataSize - 1 do MP^.DataData^[I] := GetByte(F);
 For I := 0 to MP^.SymCount - 1 do
 Begin
  MP^.Symbols^[I].Name := '';
  For J := 1 to 8 do Begin C := GetByte(F); If C <> 0 Then MP^.Symbols^[I].Name := MP^.Symbols^[I].Name + Chr(C); End;
  MP^.Symbols^[I].SType := GetWord(F); MP^.Symbols^[I].Value := GetLong(F);
 End;
 RelPos := BasePos + HeaderSize + MP^.TextSize + MP^.DataSize + SymBytes;
 If AbsFlag = 0 Then
 Begin
  SeekFile(F, RelPos); N := (MP^.TextSize + 1) div 2;
  For I := 0 to N - 1 do MP^.TextRel^[I] := GetWord(F);
  N := (MP^.DataSize + 1) div 2; For I := 0 to N - 1 do MP^.DataRel^[I] := GetWord(F);
 End
 Else Begin
  FillChar(MP^.TextRel^, ((MP^.TextSize + 1) div 2) * 2, 0);
  FillChar(MP^.DataRel^, ((MP^.DataSize + 1) div 2) * 2, 0);
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
Var MP: PMember;
Begin
 MP := AppendMember; MP^.InputIndex := InputIndex; MP^.Name := Name; MP^.DataPos := DataPos;
 MP^.DataSize := DataSize; MP^.Loaded := False; MP^.Selected := False;
End;

Procedure ReadUnixArchiveCatalog(InputIndex: Integer; Var F: File);
Var H, N, LongNames: String; P, Sz, NameLen, I: LongInt; C: Char;
Begin
 LongNames := ''; P := 8;
 While P + 60 <= FileSize(F) do
 Begin
  SeekFile(F, P); H := ReadAscii(F, 60);
  If Copy(H, 59, 2) <> '`' + Chr(10) Then Fatal(InputAt(InputIndex)^.FileName + ': entete archive invalide');
  N := TrimStr(Copy(H, 1, 16)); Sz := DecimalField(Copy(H, 49, 10));
  If (Sz < 0) or (P + 60 + Sz > FileSize(F)) Then Fatal(InputAt(InputIndex)^.FileName + ': membre archive tronque');
  If N = '//' Then Begin SeekFile(F, P + 60); LongNames := ReadAscii(F, Sz); End
  Else If (N = '/') or (N = '/SYM64/') Then Begin InputAt(InputIndex)^.IndexPos := P + 60; InputAt(InputIndex)^.IndexSize := Sz; End
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
 If (InputAt(InputIndex)^.IndexPos = 0) or (InputAt(InputIndex)^.IndexSize < 4) Then Exit;
 Assign(F, InputAt(InputIndex)^.FileName); Reset(F, 1); If IOResult <> 0 Then Exit;
 Count := GetLongBEAt(F, InputAt(InputIndex)^.IndexPos);
 If (Count < 0) or (4 + Count * 4 > InputAt(InputIndex)^.IndexSize) Then Begin Close(F); Exit; End;
 NamePos := InputAt(InputIndex)^.IndexPos + 4 + Count * 4; SeekFile(F, NamePos);
 For I := 0 to Count - 1 do Begin
  N := '';
  While FilePos(F) < InputAt(InputIndex)^.IndexPos + InputAt(InputIndex)^.IndexSize do Begin C := GetByte(F); If C = 0 Then Break; If Length(N) < 8 Then N := N + Chr(C); End;
  G := FindGlobal(N);
  If (G > 0) and GlobalAt(G)^.Needed and (not GlobalAt(G)^.Defined) Then Begin
   SavePos := FilePos(F); Offs := GetLongBEAt(F, InputAt(InputIndex)^.IndexPos + 4 + I * 4); SeekFile(F, SavePos);
   For M := 1 to MemberCount do If (MemberAt(M)^.InputIndex = InputIndex) and (MemberAt(M)^.DataPos - 60 = Offs) and (not MemberAt(M)^.Loaded) Then
   Begin MemberAt(M)^.Selected := True; MarkIndexedNeeded := True; Break; End;
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
  If (Sz < 0) or (P + 28 + Sz > FileSize(F)) Then Fatal(InputAt(InputIndex)^.FileName + ': membre AR68 tronque');
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
  If P + 16 + Sz > FileSize(F) Then Fatal(InputAt(InputIndex)^.FileName + ': ancien membre AR68 tronque');
  AddMember(InputIndex, N, P + 16, Sz); P := P + 16 + Sz; If Odd(P) Then Inc(P);
 End;
End;

Procedure CollectGlobalNeeds;
Var M, I, G: Integer; S: TSymbol;
Begin
 ClearGlobals;
 For M := 1 to ModuleCount do For I := 0 to ModuleAt(M)^.SymCount - 1 do
 Begin
  S := ModuleAt(M)^.Symbols^[I];
  If (S.SType and (SYM_GLOBAL or SYM_EXTERN)) = 0 Then Continue;
  G := FindGlobal(S.Name); If G = 0 Then G := AddGlobal(S.Name);
  If IsCommonSymbol(S) Then Begin GlobalAt(G)^.Needed := True; GlobalAt(G)^.IsCommon := True;
   If S.Value > GlobalAt(G)^.CommonSize Then GlobalAt(G)^.CommonSize := S.Value; End
  Else If (S.SType and SYM_DEFINED) <> 0 Then GlobalAt(G)^.Defined := True Else GlobalAt(G)^.Needed := True;
 End;
End;

Function MemberDefinesNeeded(MemberIndex: Integer): Boolean;
Var F: File; Magic: Word; TextSize, DataSize, BssSize, SymBytes, P: LongInt;
    I, J: Integer; N: String[8]; T: Word; C: Byte; G: Integer;
Begin
 MemberDefinesNeeded := False;
 Assign(F, InputAt(MemberAt(MemberIndex)^.InputIndex)^.FileName); Reset(F, 1);
 If IOResult <> 0 Then Fatal('impossible de relire la bibliotheque');
 SeekFile(F, MemberAt(MemberIndex)^.DataPos); Magic := GetWord(F);
  If (Magic <> $601A) and (Magic <> $601B) Then Begin Close(F); Exit; End;
 TextSize := GetLong(F); DataSize := GetLong(F); BssSize := GetLong(F); SymBytes := GetLong(F);
 GetLong(F); GetLong(F); GetWord(F); P := 28; If Magic = $601B Then P := 36;
 If (SymBytes < 0) or ((SymBytes mod 14) <> 0) or
    (P + TextSize + DataSize + SymBytes > MemberAt(MemberIndex)^.DataSize) Then Begin Close(F); Exit; End;
 SeekFile(F, MemberAt(MemberIndex)^.DataPos + P + TextSize + DataSize);
 For I := 1 to SymBytes div 14 do
 Begin
  N := ''; For J := 1 to 8 do Begin C := GetByte(F); If C <> 0 Then N := N + Chr(C); End;
  T := GetWord(F); GetLong(F);
  If ((T and (SYM_DEFINED or SYM_GLOBAL)) = (SYM_DEFINED or SYM_GLOBAL)) and ((T and SYM_EXTERN) = 0) Then
  Begin G := FindGlobal(N); If (G > 0) and GlobalAt(G)^.Needed and (not GlobalAt(G)^.Defined) Then Begin MemberDefinesNeeded := True; Break; End; End;
 End;
 Close(F);
End;

Function MemberNameMatches(Const A, B: String): Boolean;
Var X, Y: String;
Begin X := UpCaseStr(A); Y := UpCaseStr(B); MemberNameMatches := (X = Y) or (UpCaseStr(BaseName68(X)) = UpCaseStr(BaseName68(Y))); End;

Procedure LoadMember(MemberIndex: Integer);
Var I: Integer; D: String;
Begin
 I := MemberAt(MemberIndex)^.InputIndex; D := InputAt(I)^.FileName + '(' + MemberAt(MemberIndex)^.Name + ')';
 ReadObjectAt(InputAt(I)^.FileName, D, MemberAt(MemberIndex)^.DataPos, MemberAt(MemberIndex)^.DataSize,
              LongInt(I) * 10000 + MemberIndex, InputAt(I)^.IncludeLocals, InputAt(I)^.Overlay);
 MemberAt(MemberIndex)^.Loaded := True;
End;

Procedure LoadInputs;
Var I, M: Integer; F: File; S: String; B0, B1: Byte; Changed, Found: Boolean;
Begin
 MemberCount := 0;
 For I := 1 to InputCount do
 Begin
  S := ResolveInputName(InputAt(I)^.FileName);
  If S = '' Then Fatal('fichier d''entree introuvable: ' + InputAt(I)^.FileName);
  InputAt(I)^.FileName := S; Assign(F, S); Reset(F, 1); If IOResult <> 0 Then Fatal('impossible de lire ' + S);
  If FileSize(F) < 2 Then Fatal(S + ': fichier vide');
  B0 := GetByte(F); B1 := GetByte(F);
  If (B0 = $60) and (B1 in [$1A, $1B]) Then
  Begin Close(F); ReadObjectAt(S, S, 0, 0, LongInt(I) * 10000, InputAt(I)^.IncludeLocals, InputAt(I)^.Overlay); End
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
 For I := 1 to InputCount do If InputAt(I)^.AllMods or (InputAt(I)^.IncludeName <> '') Then
 Begin
  Found := InputAt(I)^.IncludeName = '';
  For M := 1 to MemberCount do If MemberAt(M)^.InputIndex = I Then
   If InputAt(I)^.AllMods or MemberNameMatches(MemberAt(M)^.Name, InputAt(I)^.IncludeName) Then
   Begin If not MemberAt(M)^.Loaded Then LoadMember(M); If InputAt(I)^.IncludeName <> '' Then Found := True; End;
  If not Found Then Error(InputAt(I)^.FileName + ': module INCLUDE introuvable: ' + InputAt(I)^.IncludeName);
 End;
 Repeat
  CollectGlobalNeeds; Changed := False;
  For I := 1 to InputCount do If MarkIndexedNeeded(I) Then
   For M := 1 to MemberCount do If MemberAt(M)^.Selected and (not MemberAt(M)^.Loaded) Then Begin LoadMember(M); Changed := True; End;
  If Changed Then CollectGlobalNeeds;
  For M := 1 to MemberCount do If (not MemberAt(M)^.Loaded) and MemberDefinesNeeded(M) Then
  Begin LoadMember(M); Changed := True; CollectGlobalNeeds; End;
 Until not Changed;
End;

Procedure SortModules;
Var I, J: Integer; T: TModule; A, B: PModule; ANext, BNext: PModule;
Begin
 For I := 1 to ModuleCount - 1 do For J := I + 1 to ModuleCount do
  If ModuleAt(I)^.OrderKey > ModuleAt(J)^.OrderKey Then Begin
   A := ModuleAt(I); B := ModuleAt(J); ANext := A^.Next; BNext := B^.Next;
   T := A^; A^ := B^; B^ := T; A^.Next := ANext; B^.Next := BNext;
  End;
End;

Procedure LayoutModules;
Var I: Integer; O: POverlay; M: PModule;
Begin
 O := FirstOverlay; While O <> Nil do Begin O^.ModuleText := 0; O^.ModuleData := 0; O^.ModuleBss := 0; O := O^.NextAll; End;
 M := FirstModule; While M <> Nil do Begin
  O := M^.Overlay; M^.TextOffset := O^.ModuleText; Inc(O^.ModuleText, M^.TextSize); If Odd(O^.ModuleText) Then Inc(O^.ModuleText);
  M := M^.Next;
 End;
 M := FirstModule; While M <> Nil do Begin O := M^.Overlay; M^.DataOffset := O^.ModuleData; Inc(O^.ModuleData, M^.DataSize); If Odd(O^.ModuleData) Then Inc(O^.ModuleData); M := M^.Next; End;
 M := FirstModule; While M <> Nil do Begin O := M^.Overlay; M^.BssOffset := O^.ModuleBss; Inc(O^.ModuleBss, M^.BssSize); If Odd(O^.ModuleBss) Then Inc(O^.ModuleBss); M := M^.Next; End;
 O := FirstOverlay; While O <> Nil do Begin
  O^.TextSize := O^.ModuleText + LongInt(O^.JumpCount) * OVCALL_SIZE;
  O^.DataSize := O^.ModuleData; If O = RootOverlay Then Inc(O^.DataSize, LongInt(OverlayCount) * OVTAB_SIZE);
  O^.BssSize := O^.ModuleBss; O := O^.NextAll;
 End;
End;

Procedure PlaceOverlay(O: POverlay; LoadBase: LongInt);
Var C: POverlay; High: LongInt;
Begin
 O^.TextBase := LoadBase; O^.DataBase := O^.TextBase + O^.TextSize;
 O^.BssBase := O^.DataBase + O^.DataSize; O^.Capacity := O^.BssBase + O^.BssSize;
 High := O^.Capacity; C := O^.FirstChild;
 While C <> Nil do Begin PlaceOverlay(C, O^.BssBase + O^.BssSize); If C^.Capacity > High Then High := C^.Capacity; C := C^.NextSibling; End;
 O^.Capacity := High;
End;

Procedure PlaceAllOverlays;
Begin
 If Not Opt.TextBaseSet Then Opt.TextBase := 0;
 RootOverlay^.TextBase := Opt.TextBase;
 If Opt.DataBaseSet Then RootOverlay^.DataBase := Opt.DataBase Else RootOverlay^.DataBase := RootOverlay^.TextBase + RootOverlay^.TextSize;
 If Opt.BssBaseSet Then RootOverlay^.BssBase := Opt.BssBase Else RootOverlay^.BssBase := RootOverlay^.DataBase + RootOverlay^.DataSize;
 RootOverlay^.Capacity := RootOverlay^.BssBase + RootOverlay^.BssSize;
 PlaceOverlay(RootOverlay, RootOverlay^.TextBase);
 { PlaceOverlay applique le placement contigu normal, les bases forcees ne concernent que le cas sans overlay. }
 If OverlayCount = 0 Then Begin
  If Opt.DataBaseSet Then RootOverlay^.DataBase := Opt.DataBase;
  If Opt.BssBaseSet Then RootOverlay^.BssBase := Opt.BssBase;
  RootOverlay^.Capacity := RootOverlay^.BssBase + RootOverlay^.BssSize;
 End;
 Opt.TextBase := RootOverlay^.TextBase; Opt.DataBase := RootOverlay^.DataBase; Opt.BssBase := RootOverlay^.BssBase;
 TotalText := RootOverlay^.TextSize; TotalData := RootOverlay^.DataSize;
 TotalBss := RootOverlay^.BssSize + (RootOverlay^.Capacity - (RootOverlay^.BssBase + RootOverlay^.BssSize));
End;

Function SymbolFinalValue(M: Integer; Const S: TSymbol): LongInt;
Var O: POverlay;
Begin
 O := ModuleAt(M)^.Overlay;
 Case SegmentOf(S.SType) of
  REL_TEXT: SymbolFinalValue := O^.TextBase + ModuleAt(M)^.TextOffset + S.Value;
  REL_DATA: SymbolFinalValue := O^.DataBase + ModuleAt(M)^.DataOffset + S.Value;
  REL_BSS:  SymbolFinalValue := O^.BssBase + ModuleAt(M)^.BssOffset + S.Value;
 Else SymbolFinalValue := S.Value;
 End;
End;

Procedure BuildGlobals;
Var M, I, G: Integer; S: TSymbol;
Begin
 ClearGlobals;
 For M := 1 to ModuleCount do For I := 0 to ModuleAt(M)^.SymCount - 1 do
 Begin
  S := ModuleAt(M)^.Symbols^[I];
  If (S.SType and (SYM_GLOBAL or SYM_EXTERN)) = 0 Then Continue;
  G := FindGlobal(S.Name); If G = 0 Then G := AddGlobal(S.Name);
  If IsCommonSymbol(S) Then
  Begin
   GlobalAt(G)^.Needed := True; GlobalAt(G)^.IsCommon := True;
   If S.Value > GlobalAt(G)^.CommonSize Then GlobalAt(G)^.CommonSize := S.Value;
  End
  Else If (S.SType and SYM_DEFINED) <> 0 Then
  Begin
   If GlobalAt(G)^.Defined Then Error('symbole defini plusieurs fois: ' + S.Name)
   Else Begin GlobalAt(G)^.Defined := True; GlobalAt(G)^.ModuleIndex := M; GlobalAt(G)^.SymbolIndex := I;
    GlobalAt(G)^.Overlay := ModuleAt(M)^.Overlay;
    GlobalAt(G)^.FinalType := S.SType; GlobalAt(G)^.FinalValue := SymbolFinalValue(M, S); End;
  End Else GlobalAt(G)^.Needed := True;
 End;
 For G := 1 to GlobalCount do If GlobalAt(G)^.IsCommon and (not GlobalAt(G)^.Defined) Then
 Begin
  If Odd(RootOverlay^.BssSize) Then Inc(RootOverlay^.BssSize);
  GlobalAt(G)^.Defined := True; GlobalAt(G)^.FinalType := SYM_DEFINED or SYM_GLOBAL or SYM_BSS;
  GlobalAt(G)^.Overlay := RootOverlay; GlobalAt(G)^.FinalValue := RootOverlay^.BssBase + RootOverlay^.BssSize;
  Inc(RootOverlay^.BssSize, (GlobalAt(G)^.CommonSize + 1) and not 1);
 End;
 PlaceAllOverlays;
 For G := 1 to GlobalCount do If GlobalAt(G)^.Defined Then
  If GlobalAt(G)^.ModuleIndex > 0 Then
   GlobalAt(G)^.FinalValue := SymbolFinalValue(GlobalAt(G)^.ModuleIndex,
     ModuleAt(GlobalAt(G)^.ModuleIndex)^.Symbols^[GlobalAt(G)^.SymbolIndex]);
 For G := 1 to GlobalCount do If GlobalAt(G)^.Needed and (not GlobalAt(G)^.Defined) Then
  If Opt.AllowUndefined Then Warning('symbole non defini conserve: ' + GlobalAt(G)^.Name)
  Else Error('symbole non defini: ' + GlobalAt(G)^.Name);
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
Var O: POverlay;
Begin
 O := ModuleAt(M)^.Overlay;
 Case RType of
  REL_TEXT: RelocBase := O^.TextBase + ModuleAt(M)^.TextOffset;
  REL_DATA: RelocBase := O^.DataBase + ModuleAt(M)^.DataOffset;
  REL_BSS: RelocBase := O^.BssBase + ModuleAt(M)^.BssOffset;
 Else RelocBase := 0;
 End;
End;

Function OutputSymbolIndex(G: Integer): Integer;
Var I, N: Integer;
Begin
 N := 0;
 For I := 1 to G do If Opt.EmitSymbols or (not GlobalAt(I)^.Defined) Then Inc(N);
 OutputSymbolIndex := N - 1;
End;

Function IsAncestor(Ancestor, Node: POverlay): Boolean;
Begin
 While Node <> Nil do Begin If Node = Ancestor Then Begin IsAncestor := True; Exit; End; Node := Node^.Parent; End;
 IsAncestor := False;
End;

Function FindJump(O: POverlay; G: PGlobal): PJump;
Var J: PJump;
Begin J := O^.FirstJump; While (J <> Nil) and (J^.Target <> G) do J := J^.Next; FindJump := J; End;

Function AddJump(O: POverlay; G: PGlobal): PJump;
Var J: PJump;
Begin
 J := FindJump(O, G); If J <> Nil Then Begin AddJump := J; Exit; End;
 New(J); FillChar(J^, SizeOf(TJump), 0); J^.Target := G;
 If O^.FirstJump = Nil Then O^.FirstJump := J Else O^.LastJump^.Next := J;
 O^.LastJump := J; Inc(O^.JumpCount); AddJump := J;
End;

Procedure CheckOverlayReference(M, SymbolIndex: Integer);
Var G: Integer; Caller, Target: POverlay; J: PJump; N: String;
Begin
 If (SymbolIndex < 0) or (SymbolIndex >= ModuleAt(M)^.SymCount) Then Begin Error('index de symbole externe invalide'); Exit; End;
 N := ModuleAt(M)^.Symbols^[SymbolIndex].Name; G := FindGlobal(N);
 If (G = 0) or (not GlobalAt(G)^.Defined) Then Exit;
 Caller := ModuleAt(M)^.Overlay; Target := GlobalAt(G)^.Overlay;
 If IsAncestor(Target, Caller) Then Exit;
 If (Target^.Parent = Caller) and (SegmentOf(GlobalAt(G)^.FinalType) = REL_TEXT) Then Begin J := AddJump(Caller, GlobalAt(G)); Exit; End;
 Error(ModuleAt(M)^.FileName + ': reference overlay illegale vers ' + N);
End;

Procedure ScanRelocationsForOverlay(M: Integer; R: PWordBuffer; Size: LongInt);
Var I, N, T: Integer;
Begin
 N := (Size + 1) div 2; I := 0;
 While I < N do Begin
  T := R^[I] and 7;
  If T = REL_UPPER Then Begin Inc(I); If I < N Then T := R^[I] and 7; End;
  If T in [REL_EXTERN, REL_PCREL] Then CheckOverlayReference(M, R^[I] shr 3);
  Inc(I);
 End;
End;

Procedure BuildOverlayJumps;
Var M, G: Integer; O: POverlay; J: PJump;
Begin
 If OverlayCount = 0 Then Exit;
 For M := 1 to ModuleCount do Begin
  ScanRelocationsForOverlay(M, ModuleAt(M)^.TextRel, ModuleAt(M)^.TextSize);
  ScanRelocationsForOverlay(M, ModuleAt(M)^.DataRel, ModuleAt(M)^.DataSize);
 End;
 LayoutModules; PlaceAllOverlays;
 For G := 1 to GlobalCount do If GlobalAt(G)^.Defined and (GlobalAt(G)^.ModuleIndex > 0) Then
  GlobalAt(G)^.FinalValue := SymbolFinalValue(GlobalAt(G)^.ModuleIndex,
   ModuleAt(GlobalAt(G)^.ModuleIndex)^.Symbols^[GlobalAt(G)^.SymbolIndex]);
 O := FirstOverlay; While O <> Nil do Begin
  J := O^.FirstJump; While J <> Nil do Begin
   J^.Address := O^.TextBase + O^.ModuleText;
   If J <> O^.FirstJump Then J^.Address := O^.FirstJump^.Address;
   J := J^.Next;
  End;
  J := O^.FirstJump; G := 0; While J <> Nil do Begin J^.Address := O^.TextBase + O^.ModuleText + LongInt(G) * OVCALL_SIZE; Inc(G); J := J^.Next; End;
  O := O^.NextAll;
 End;
End;

Function ResolveExternal(M, G: Integer; Var Value: LongInt; Var RType: Integer): Boolean;
Var Caller, Target: POverlay; J: PJump;
Begin
 ResolveExternal := False; If (G = 0) or (not GlobalAt(G)^.Defined) Then Exit;
 Caller := ModuleAt(M)^.Overlay; Target := GlobalAt(G)^.Overlay;
 If (OverlayCount = 0) or IsAncestor(Target, Caller) Then Begin
  Value := GlobalAt(G)^.FinalValue; RType := SegmentOf(GlobalAt(G)^.FinalType); ResolveExternal := True; Exit;
 End;
 J := FindJump(Caller, GlobalAt(G));
 If J <> Nil Then Begin Value := J^.Address; RType := REL_TEXT; ResolveExternal := True; Exit; End;
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
    AddValue, FullValue: LongInt; OutType: Word; ResType: Integer; SName: String;
Begin
 Words := (SrcSize + 1) div 2; WI := 0;
 While WI < Words do
 Begin
  P := LongInt(WI) * 2; RT := SrcRel^[WI] and 7; AddValue := 0; OutType := RT;
  If RT = REL_UPPER Then
  Begin
   If WI + 1 >= Words Then Begin Error(ModuleAt(M)^.FileName + ': relogement long tronque'); Exit; End;
   NextRT := SrcRel^[WI + 1] and 7;
   If NextRT = REL_PCREL Then Begin Error(ModuleAt(M)^.FileName + ': PCREL long invalide'); NextRT := REL_ABS; End;
   If NextRT in [REL_TEXT, REL_DATA, REL_BSS] Then AddValue := RelocBase(M, NextRT)
   Else If NextRT = REL_EXTERN Then
   Begin
    SI := SrcRel^[WI + 1] shr 3;
    If SI >= ModuleAt(M)^.SymCount Then Begin Error('index de symbole externe invalide'); SI := 0; End;
    SName := ModuleAt(M)^.Symbols^[SI].Name; G := FindGlobal(SName);
    If ResolveExternal(M, G, AddValue, NextRT) Then Begin End
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
   If SI >= ModuleAt(M)^.SymCount Then Begin Error('index de symbole externe invalide'); SI := 0; End;
   SName := ModuleAt(M)^.Symbols^[SI].Name; G := FindGlobal(SName);
   ResType := OutType;
   If ResolveExternal(M, G, AddValue, ResType) Then OutType := ResType
   Else If Opt.AllowUndefined and (G > 0) Then OutType := (OutputSymbolIndex(G) shl 3) or REL_EXTERN
   Else OutType := REL_ABS;
  End
  Else If RT = REL_PCREL Then
  Begin
   SI := SrcRel^[WI] shr 3;
   If SI >= ModuleAt(M)^.SymCount Then Begin Error(ModuleAt(M)^.FileName + ': index PCREL invalide'); SI := 0; End;
   SName := ModuleAt(M)^.Symbols^[SI].Name; G := FindGlobal(SName);
   ResType := OutType;
   If ResolveExternal(M, G, AddValue, ResType) Then AddValue := AddValue - (ModuleAt(M)^.Overlay^.TextBase + ModuleAt(M)^.TextOffset + P)
   Else Begin Error(ModuleAt(M)^.FileName + ': symbole PCREL non defini: ' + SName); AddValue := 0; End;
   OutType := REL_ABS;
  End
  Else If (RT <> REL_ABS) and (RT <> REL_INSTR) Then Error(ModuleAt(M)^.FileName + ': type de relogement invalide');
  If P + 1 < SrcSize Then Begin
   V16 := ReadWordBuf(Src, P); FullValue := SmallInt(V16) + AddValue;
   If RT = REL_PCREL Then CheckShortOverflow(FullValue, True, ModuleAt(M)^.FileName)
   Else If RT in [REL_TEXT, REL_DATA, REL_BSS, REL_EXTERN] Then CheckShortOverflow(FullValue, False, ModuleAt(M)^.FileName);
   WriteWordBuf(Dst, DstBase + P, Word(FullValue));
  End
  Else Dst^[DstBase + P] := Src^[P];
  If Opt.Absolute Then DstRel^[(DstBase div 2) + WI] := 0 Else DstRel^[(DstBase div 2) + WI] := OutType;
  Inc(WI);
 End;
End;

Procedure WriteJumpBlocks(O: POverlay);
Var J: PJump; P: LongInt; G: Integer; Handler, TableAddress: LongInt;
Begin
 If O^.FirstJump = Nil Then Exit;
 G := FindGlobal('_ovhdlr'); If (G = 0) or (not GlobalAt(G)^.Defined) Then Begin Error('symbole _ovhdlr non defini'); Exit; End;
 If GlobalAt(G)^.Overlay <> RootOverlay Then Begin Error('_ovhdlr doit etre defini dans la racine'); Exit; End;
 Handler := GlobalAt(G)^.FinalValue; TableAddress := RootOverlay^.DataBase + RootOverlay^.ModuleData;
 J := O^.FirstJump; P := O^.ModuleText;
 While J <> Nil do Begin
  WriteWordBuf(OutText, P, $4EB9); WriteLongBuf(OutText, P + 2, Handler);
  WriteLongBuf(OutText, P + 6, TableAddress + LongInt(J^.Target^.Overlay^.Number - 1) * OVTAB_SIZE);
  WriteWordBuf(OutText, P + 10, $4EF9); WriteLongBuf(OutText, P + 12, J^.Target^.FinalValue);
  OutTextRel^[(P div 2)] := REL_INSTR; OutTextRel^[(P div 2)+1] := REL_UPPER; OutTextRel^[(P div 2)+2] := REL_TEXT;
  OutTextRel^[(P div 2)+3] := REL_UPPER; OutTextRel^[(P div 2)+4] := REL_DATA;
  OutTextRel^[(P div 2)+5] := REL_INSTR; OutTextRel^[(P div 2)+6] := REL_UPPER; OutTextRel^[(P div 2)+7] := REL_TEXT;
  Inc(P, OVCALL_SIZE); J := J^.Next;
 End;
End;

Function FileLeaf(Const S: String): String;
Var I: Integer;
Begin I := Length(S); While (I > 0) and not (S[I] in ['\','/',':']) do Dec(I); FileLeaf := Copy(S, I + 1, Length(S)); End;

Procedure WriteOverlayTable;
Var O: POverlay; P: LongInt; N, B, E: String; I, DotPos: Integer;
Begin
 P := RootOverlay^.ModuleData; O := RootOverlay^.NextAll;
 While O <> Nil do Begin
  N := UpCaseStr(FileLeaf(O^.OutputName)); DotPos := Pos('.', N);
  If DotPos > 0 Then Begin B := Copy(N, 1, DotPos - 1); E := Copy(N, DotPos + 1, 3); End Else Begin B := N; E := ''; End;
  For I := 0 to 7 do If I < Length(B) Then OutData^[P+I] := Ord(B[I+1]) Else OutData^[P+I] := Ord(' ');
  For I := 0 to 2 do If I < Length(E) Then OutData^[P+8+I] := Ord(E[I+1]) Else OutData^[P+8+I] := Ord(' ');
  OutData^[P+11] := 0; WriteLongBuf(OutData, P + 12, O^.TextBase);
  OutDataRel^[(P div 2)+6] := REL_UPPER; OutDataRel^[(P div 2)+7] := REL_TEXT;
  Inc(P, OVTAB_SIZE); O := O^.NextAll;
 End;
End;

Procedure LinkModules(O: POverlay);
Var M, I: Integer;
Begin
 TotalText := O^.TextSize; TotalData := O^.DataSize;
 GetMem(OutText, TotalText + 1); GetMem(OutData, TotalData + 1);
 GetMem(OutTextRel, ((TotalText + 1) div 2) * 2 + 2); GetMem(OutDataRel, ((TotalData + 1) div 2) * 2 + 2);
 FillChar(OutText^, TotalText, 0); FillChar(OutData^, TotalData, 0); FillChar(OutTextRel^, ((TotalText + 1) div 2) * 2, 0); FillChar(OutDataRel^, ((TotalData + 1) div 2) * 2, 0);
 For M := 1 to ModuleCount do
 If ModuleAt(M)^.Overlay = O Then Begin
  For I := 0 to ModuleAt(M)^.TextSize - 1 do OutText^[ModuleAt(M)^.TextOffset + I] := ModuleAt(M)^.TextData^[I];
  For I := 0 to ModuleAt(M)^.DataSize - 1 do OutData^[ModuleAt(M)^.DataOffset + I] := ModuleAt(M)^.DataData^[I];
  ApplyOneRelocation(M, ModuleAt(M)^.TextData, ModuleAt(M)^.TextRel, OutText, OutTextRel, ModuleAt(M)^.TextSize, ModuleAt(M)^.TextOffset);
  ApplyOneRelocation(M, ModuleAt(M)^.DataData, ModuleAt(M)^.DataRel, OutData, OutDataRel, ModuleAt(M)^.DataSize, ModuleAt(M)^.DataOffset);
 End;
 WriteJumpBlocks(O); If O = RootOverlay Then WriteOverlayTable;
End;

Function OutputSymbolCount: Integer;
Var I, M, N: Integer; S: TSymbol;
Begin
 N := 0;
 For I := 1 to GlobalCount do If Opt.EmitSymbols or (not GlobalAt(I)^.Defined) Then Inc(N);
 If Opt.EmitSymbols Then For M := 1 to ModuleCount do If ModuleAt(M)^.IncludeLocals Then
  For I := 0 to ModuleAt(M)^.SymCount - 1 do
  Begin
   S := ModuleAt(M)^.Symbols^[I];
   If ((S.SType and (SYM_GLOBAL or SYM_EXTERN)) = 0) and
      ((Length(S.Name) = 0) or (UpCase(S.Name[1]) <> 'L')) Then Inc(N);
  End;
 OutputSymbolCount := N;
End;

Procedure WriteOutput(O: POverlay);
Var F: File; I, J, M, SymN: Integer; Magic, ST: Word; NonContiguous: Boolean; S: TSymbol;
Begin
 Assign(F, O^.OutputName); Rewrite(F, 1); If IOResult <> 0 Then Fatal('impossible de creer ' + O^.OutputName);
 NonContiguous := (O = RootOverlay) and ((O^.DataBase <> O^.TextBase + TotalText) or (O^.BssBase <> O^.DataBase + TotalData));
 If NonContiguous Then Magic := $601B Else Magic := $601A;
 SymN := OutputSymbolCount;
 If O = RootOverlay Then TotalBss := O^.BssSize + (O^.Capacity - (O^.BssBase + O^.BssSize)) Else TotalBss := O^.BssSize;
 PutWord(F, Magic); PutLong(F, TotalText); PutLong(F, TotalData); PutLong(F, TotalBss);
 If O <> RootOverlay Then SymN := 0;
 PutLong(F, LongInt(SymN) * 14); PutLong(F, 0); PutLong(F, O^.TextBase);
 If Opt.Absolute Then PutWord(F, 1) Else PutWord(F, 0);
 If NonContiguous Then Begin PutLong(F, O^.DataBase); PutLong(F, O^.BssBase); End;
 For I := 0 to TotalText - 1 do PutByte(F, OutText^[I]);
 For I := 0 to TotalData - 1 do PutByte(F, OutData^[I]);
 For I := 1 to GlobalCount do If (O = RootOverlay) and (Opt.EmitSymbols or (not GlobalAt(I)^.Defined)) Then
 Begin
  For J := 1 to 8 do If J <= Length(GlobalAt(I)^.Name) Then PutByte(F, Ord(GlobalAt(I)^.Name[J])) Else PutByte(F, 0);
  If GlobalAt(I)^.Defined Then Begin ST := GlobalAt(I)^.FinalType or SYM_DEFINED or SYM_GLOBAL; PutWord(F, ST); PutLong(F, GlobalAt(I)^.FinalValue); End
  Else Begin PutWord(F, SYM_EXTERN or SYM_GLOBAL); PutLong(F, 0); End;
 End;
 If Opt.EmitSymbols and (O = RootOverlay) Then For M := 1 to ModuleCount do If ModuleAt(M)^.IncludeLocals Then
  For I := 0 to ModuleAt(M)^.SymCount - 1 do
  Begin
   S := ModuleAt(M)^.Symbols^[I];
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

Procedure ReleaseOutputBuffers;
Begin
 If OutText <> Nil Then FreeMem(OutText, TotalText + 1); If OutData <> Nil Then FreeMem(OutData, TotalData + 1);
 If OutTextRel <> Nil Then FreeMem(OutTextRel, ((TotalText + 1) div 2) * 2 + 2);
 If OutDataRel <> Nil Then FreeMem(OutDataRel, ((TotalData + 1) div 2) * 2 + 2);
 OutText := Nil; OutData := Nil; OutTextRel := Nil; OutDataRel := Nil;
End;

Procedure FreeAll;
Var MP, MN: PModule; IP, INext: PInput; AP, AN: PMember; O, ONext: POverlay; J, JNext: PJump;
Begin
 MP := FirstModule; While MP <> Nil do Begin MN := MP^.Next;
  If MP^.Symbols <> Nil Then FreeMem(MP^.Symbols, LongInt(MP^.SymCount) * SizeOf(TSymbol));
  FreeMem(MP^.TextData, MP^.TextSize + 1); FreeMem(MP^.DataData, MP^.DataSize + 1);
  FreeMem(MP^.TextRel, ((MP^.TextSize + 1) div 2) * 2 + 2); FreeMem(MP^.DataRel, ((MP^.DataSize + 1) div 2) * 2 + 2);
  Dispose(MP); MP := MN;
 End;
 ClearGlobals;
 IP := FirstInput; While IP <> Nil do Begin INext := IP^.Next; Dispose(IP); IP := INext; End;
 AP := FirstMember; While AP <> Nil do Begin AN := AP^.Next; Dispose(AP); AP := AN; End;
 ReleaseOutputBuffers;
 O := FirstOverlay; While O <> Nil do Begin ONext := O^.NextAll; J := O^.FirstJump;
  While J <> Nil do Begin JNext := J^.Next; Dispose(J); J := JNext; End;
  Dispose(O); O := ONext;
 End;
End;

Procedure EmitAllOutputs;
Var O: POverlay;
Begin
 O := FirstOverlay; While (O <> Nil) and (ErrorCount = 0) do Begin
  LinkModules(O); If ErrorCount = 0 Then WriteOutput(O); ReleaseOutputBuffers; O := O^.NextAll;
 End;
End;

Procedure Run;
Begin
 ErrorCount := 0; WarningCount := 0; ModuleCount := 0; GlobalCount := 0; InputCount := 0; MemberCount := 0; OverlayCount := 0;
 FirstModule := Nil; LastModule := Nil; FirstGlobal := Nil; LastGlobal := Nil;
 FirstInput := Nil; LastInput := Nil; FirstMember := Nil; LastMember := Nil;
 FirstOverlay := Nil; LastOverlay := Nil; RootOverlay := AppendOverlay(Nil);
 OutText := Nil; OutData := Nil; OutTextRel := Nil; OutDataRel := Nil;
 ParseCommandLine;
 LoadInputs; SortModules;
 LayoutModules; PlaceAllOverlays; BuildGlobals;
 If ErrorCount = 0 Then BuildOverlayJumps;
 If ErrorCount = 0 Then EmitAllOutputs;
 TotalText := RootOverlay^.TextSize; TotalData := RootOverlay^.DataSize;
 TotalBss := RootOverlay^.Capacity - RootOverlay^.BssBase;
 WriteLn('LINK68: ', ModuleCount, ' module(s), TEXT=', TotalText,
         ', DATA=', TotalData, ', BSS=', TotalBss,
         ', symboles=', GlobalCount, ', erreurs=', ErrorCount);
 If ErrorCount = 0 Then WriteLn('LINK68: fichier produit: ', Opt.OutputName, ', overlays=', OverlayCount);
 FreeAll;
 If ErrorCount <> 0 Then Halt(1);
End;

Begin
 Run;
End.
