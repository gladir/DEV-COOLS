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
 BUFFER_PAGE_SIZE = 16384;
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

 DRI_MAGIC_NORMAL = $601A;
 DRI_MAGIC_BASES  = $601B;
 DRI_MAGIC_2K     = $601C;
 DRI_MAGIC_ID     = $601D;
 DRI_MAGIC_4K     = $601E;

 INDEX_NONE  = 0;
 INDEX_GNU32 = 1;
 INDEX_GNU64 = 2;
 INDEX_BSD32 = 3;
 INDEX_BSD64 = 4;

Type
 PBytePage = ^TBytePage;
 TBytePage = Record
  Next : PBytePage;
  Data : Array[0..BUFFER_PAGE_SIZE - 1] of Byte;
 End;
 PByteBuffer = ^TByteBuffer;
 TByteBuffer = Record
  FirstPage, LastPage, CachePage : PBytePage;
  Size, CacheNumber : LongInt;
 End;
 PWordBuffer = PByteBuffer;

 PSymbol = ^TSymbol;
 TSymbol = Record
  Next  : PSymbol;
  Name  : String[8];
  SType : Word;
  Value : LongInt;
 End;

 POverlay = ^TOverlay;
 PJump = ^TJump;

 PModule = ^TModule;
 TModule = Record
 Next : PModule;
  Overlay : POverlay;
  SourceMagic : Word;
  SourceAbsolute : Boolean;
  FileName : String;
  OrderKey : LongInt;
  TextSize, DataSize, BssSize : LongInt;
  TextOffset, DataOffset, BssOffset : LongInt;
 SymCount : LongInt;
  IncludeLocals : Boolean;
  FirstSymbol, LastSymbol, SymbolCache : PSymbol;
  SymbolCacheIndex : LongInt;
  TextData, DataData : PByteBuffer;
  TextRel, DataRel : PWordBuffer;
 End;

 PGlobal = ^TGlobal;
 TGlobal = Record
 Next : PGlobal;
  Overlay : POverlay;
  Name : String[8];
  ModuleIndex : Integer;
  SymbolIndex : LongInt;
  Defined, Needed : Boolean;
  IsSpecial : Boolean;
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
  CommonBss : LongInt;
  TextSize, DataSize, BssSize : LongInt;
  TextBase, DataBase, BssBase, Capacity : LongInt;
 End;

 TOptions = Record
  AllowUndefined, EmitSymbols, EmitLocals, Absolute, AllMods, IgnoreOverflow, Chained : Boolean;
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
  IncludeName : String;
  IndexPos, IndexSize : LongInt;
  IndexKind : Byte;
 End;

 PMember = ^TMember;
 TMember = Record
  Next : PMember;
  InputIndex : Integer;
  Name : String;
  HeaderPos, DataPos, DataSize : LongInt;
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
 StackSize : LongInt;
 ErrorCount, WarningCount : Integer;
 OutputRedirected : Boolean;
 TempTextName, TempDataName, TempTextRelName, TempDataRelName : String;
 PartialOutputName : String;
 LinkOutputFile : File;
 LinkOutputOpen : Boolean;
 TempSerial : Integer;

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

Function DecimalStr(V: LongInt): String;
Var S: String;
Begin Str(V, S); DecimalStr := TrimStr(S); End;

Function IsAbbrev(Const S, FullName: String; MinLen: Integer): Boolean;
Begin IsAbbrev := (Length(S) >= MinLen) and (Length(S) <= Length(FullName)) and
                  (Copy(FullName, 1, Length(S)) = S); End;

Procedure Error(Const S: String);
Begin Inc(ErrorCount); WriteLn('LINK68: ', S); End;

Procedure Warning(Const S: String);
Begin Inc(WarningCount); WriteLn('LINK68: WARNING: ', S); End;

Procedure RemovePartialOutput;
Var F: File;
Begin
 If LinkOutputOpen Then Begin Close(LinkOutputFile); If IOResult <> 0 Then Begin End; LinkOutputOpen := False; End;
 If PartialOutputName <> '' Then Begin Assign(F, PartialOutputName); Erase(F); If IOResult <> 0 Then Begin End; PartialOutputName := ''; End;
End;

Procedure Fatal(Const S: String);
Begin Error(S); RemovePartialOutput; Halt(2); End;

Function CheckedAdd(A, B: LongInt; Const Context: String): LongInt;
Begin
 If ((B > 0) and (A > $7FFFFFFF - B)) or ((B < 0) and (A < LongInt($80000000) - B)) Then
  Fatal('32-bit overflow: ' + Context);
 CheckedAdd := A + B;
End;

Function CheckedSub(A, B: LongInt; Const Context: String): LongInt;
Begin
 If B = LongInt($80000000) Then Fatal('32-bit overflow: ' + Context);
 CheckedSub := CheckedAdd(A, -B, Context);
End;

Function CheckedMul(A, B: LongInt; Const Context: String): LongInt;
Begin
 If (A < 0) or (B < 0) Then Fatal('multiplication negative interne: ' + Context);
 If (A <> 0) and (B > $7FFFFFFF div A) Then Fatal('32-bit overflow: ' + Context);
 CheckedMul := A * B;
End;

Function NewByteBuffer(Size: LongInt): PByteBuffer;
Var B: PByteBuffer; P: PBytePage; Left: LongInt;
Begin
 If Size < 0 Then Fatal('taille de tampon negative');
 New(B); B^.FirstPage := Nil; B^.LastPage := Nil; B^.CachePage := Nil;
 B^.Size := Size; B^.CacheNumber := -1; Left := Size;
 While Left > 0 do Begin
  New(P); P^.Next := Nil; FillChar(P^.Data, SizeOf(P^.Data), 0);
  If B^.FirstPage = Nil Then B^.FirstPage := P Else B^.LastPage^.Next := P;
  B^.LastPage := P; Dec(Left, BUFFER_PAGE_SIZE);
 End;
 NewByteBuffer := B;
End;

Procedure FreeByteBuffer(Var B: PByteBuffer);
Var P, N: PBytePage;
Begin
 If B = Nil Then Exit; P := B^.FirstPage;
 While P <> Nil do Begin N := P^.Next; Dispose(P); P := N; End;
 Dispose(B); B := Nil;
End;

Function BufferPage(B: PByteBuffer; Posn: LongInt): PBytePage;
Var P: PBytePage; PageNo, N: LongInt;
Begin
 If (B = Nil) or (Posn < 0) or (Posn >= B^.Size) Then Fatal('index de tampon interne invalide');
 PageNo := Posn div BUFFER_PAGE_SIZE;
 If (B^.CachePage <> Nil) and (PageNo >= B^.CacheNumber) Then Begin P := B^.CachePage; N := B^.CacheNumber; End
 Else Begin P := B^.FirstPage; N := 0; End;
 While N < PageNo do Begin P := P^.Next; Inc(N); End;
 B^.CachePage := P; B^.CacheNumber := PageNo; BufferPage := P;
End;

Function BufferByte(B: PByteBuffer; Posn: LongInt): Byte;
Begin BufferByte := BufferPage(B, Posn)^.Data[Posn mod BUFFER_PAGE_SIZE]; End;

Procedure StoreBufferByte(B: PByteBuffer; Posn: LongInt; V: Byte);
Begin BufferPage(B, Posn)^.Data[Posn mod BUFFER_PAGE_SIZE] := V; End;

Function BufferWord(B: PWordBuffer; Index: LongInt): Word;
Var P: LongInt;
Begin P := CheckedMul(Index, 2, 'word buffer index'); BufferWord := Word(BufferByte(B, P)) shl 8 or BufferByte(B, CheckedAdd(P, 1, 'word buffer index')); End;

Procedure StoreBufferWord(B: PWordBuffer; Index: LongInt; V: Word);
Var P: LongInt;
Begin P := CheckedMul(Index, 2, 'word buffer index'); StoreBufferByte(B, P, Byte(V shr 8)); StoreBufferByte(B, CheckedAdd(P, 1, 'word buffer index'), Byte(V)); End;

Function AppendSymbol(M: PModule): PSymbol;
Var S: PSymbol;
Begin
 New(S); S^.Next := Nil; S^.Name := ''; S^.SType := 0; S^.Value := 0;
 If M^.FirstSymbol = Nil Then M^.FirstSymbol := S Else M^.LastSymbol^.Next := S;
 M^.LastSymbol := S; Inc(M^.SymCount); AppendSymbol := S;
End;

Function ModuleSymbolAt(M: PModule; Index: LongInt): PSymbol;
Var S: PSymbol; N: LongInt;
Begin
 If (Index < 0) or (Index >= M^.SymCount) Then Fatal('index de symbole objet invalide');
 If (M^.SymbolCache <> Nil) and (Index >= M^.SymbolCacheIndex) Then Begin
  S := M^.SymbolCache; N := M^.SymbolCacheIndex;
 End Else Begin S := M^.FirstSymbol; N := 0; End;
 While N < Index do Begin S := S^.Next; Inc(N); End;
 M^.SymbolCache := S; M^.SymbolCacheIndex := N; ModuleSymbolAt := S;
End;

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
  If Opt.Chained and (P^.Depth > 1) Then Fatal('CHAINED interdit les overlays imbriques');
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

Function AlignLong(Value, Boundary: LongInt): LongInt;
Var R: LongInt;
Begin
 If (Value < 0) or (Boundary <= 0) Then Fatal('alignement 32 bits invalide');
 R := Value mod Boundary;
 If R = 0 Then AlignLong := Value Else AlignLong := CheckedAdd(Value, Boundary - R, 'alignement');
End;

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
Var N: Word;
Begin BlockWrite(F, B, 1, N); If (IOResult <> 0) or (N <> 1) Then Fatal('output write error'); End;

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

Procedure ReadBufferBytes(Var F: File; B: PByteBuffer; Count: LongInt);
Var P: PBytePage; N, Got: Word; Left: LongInt;
Begin
 If (Count < 0) or (Count > B^.Size) Then Fatal('taille de lecture de tampon invalide');
 P := B^.FirstPage; Left := Count;
 While Left > 0 do Begin N := BUFFER_PAGE_SIZE; If Left < N Then N := Left;
  BlockRead(F, P^.Data, N, Got); If (IOResult <> 0) or (Got <> N) Then Fatal('fin de fichier inattendue');
  Dec(Left, N); P := P^.Next;
 End;
End;

Procedure WriteBufferBytes(Var F: File; B: PByteBuffer; Count: LongInt);
Var P: PBytePage; N, PutCount: Word; Left: LongInt;
Begin
 If (Count < 0) or (Count > B^.Size) Then Fatal('taille d''ecriture de tampon invalide');
 P := B^.FirstPage; Left := Count;
 While Left > 0 do Begin N := BUFFER_PAGE_SIZE; If Left < N Then N := Left;
  BlockWrite(F, P^.Data, N, PutCount); If (IOResult <> 0) or (PutCount <> N) Then Fatal('erreur d''ecriture fichier');
  Dec(Left, N); P := P^.Next;
 End;
End;

Procedure CopyBufferRange(Src: PByteBuffer; SrcPos: LongInt; Dst: PByteBuffer; DstPos, Count: LongInt);
Var SP, DP: PBytePage; SO, DOff, N: LongInt;
Begin
 If (Count < 0) or (SrcPos < 0) or (DstPos < 0) or (Count > Src^.Size - SrcPos) or
    (Count > Dst^.Size - DstPos) Then Fatal('copie de tampon interne invalide');
 While Count > 0 do Begin
  SP := BufferPage(Src, SrcPos); DP := BufferPage(Dst, DstPos);
  SO := SrcPos mod BUFFER_PAGE_SIZE; DOff := DstPos mod BUFFER_PAGE_SIZE;
  N := BUFFER_PAGE_SIZE - SO; If BUFFER_PAGE_SIZE - DOff < N Then N := BUFFER_PAGE_SIZE - DOff;
  If Count < N Then N := Count; Move(SP^.Data[SO], DP^.Data[DOff], N);
  Inc(SrcPos, N); Inc(DstPos, N); Dec(Count, N);
 End;
End;

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

Function FindGlobalForModule(Const Name: String; M: Integer): Integer;
Var P: PGlobal; I, RootMatch, UndefinedMatch: Integer; O: POverlay;
Begin
 If not Opt.Chained Then Begin FindGlobalForModule := FindGlobal(Name); Exit; End;
 O := ModuleAt(M)^.Overlay; P := FirstGlobal; I := 1; RootMatch := 0; UndefinedMatch := 0;
 While P <> Nil do Begin
  If P^.Name = Name Then Begin
   If P^.Defined and (P^.Overlay = O) Then Begin FindGlobalForModule := I; Exit; End;
   If P^.Defined and (P^.Overlay = RootOverlay) Then RootMatch := I;
   If (not P^.Defined) and (UndefinedMatch = 0) Then UndefinedMatch := I;
  End;
  P := P^.Next; Inc(I);
 End;
 If RootMatch <> 0 Then FindGlobalForModule := RootMatch Else FindGlobalForModule := UndefinedMatch;
End;

Function SegmentOf(T: Word): Integer;
Begin
 If (T and SYM_TEXT) <> 0 Then SegmentOf := REL_TEXT
 Else If (T and SYM_DATA) <> 0 Then SegmentOf := REL_DATA
 Else If (T and SYM_BSS) <> 0 Then SegmentOf := REL_BSS
 Else SegmentOf := REL_ABS;
End;

Function IsCommonSymbol(Const S: TSymbol): Boolean;
Begin
 { Une reference externe DRI ordinaire porte aussi SYM_DEFINED, mais vaut zero.
   Seule une taille non nulle demande une allocation COMMON. }
 IsCommonSymbol := ((S.SType and (SYM_DEFINED or SYM_EXTERN)) = (SYM_DEFINED or SYM_EXTERN)) and (S.Value > 0);
End;

Procedure ShowHelp;
Begin
 WriteLn('LINK68 - Cette commande permet de lancer un clone du linker Digital Research/Alcyon pour Atari ST.');
 WriteLn;
 WriteLn('Syntaxe : LINK68 [options] sortie = objet1,objet2,...');
 WriteLn('          LINK68 objet1,objet2,...');
 WriteLn('          LINK68 ... >fichier     (redirection des messages)');
 WriteLn('Le caractere \ commence un commentaire; certains ] finaux sont facultatifs.');
 WriteLn;
 WriteLn('Options entre crochets :');
 WriteLn('  U              Autorise les symboles non definis');
 WriteLn('  S              Inclut la table des symboles');
 WriteLn('  ALLMODS (AL)   Charge tous les modules des bibliotheques');
 WriteLn('  IGNORE (IG)    Continue apres un debordement d''adresse 16 bits');
 WriteLn('  TEMPFILES[p]   Repertoire des fichiers temporaires TEXT/DATA/relogements');
 WriteLn('  COMMAND[f] (C) Lit la commande dans le fichier f');
 WriteLn('  CHAINED (CH)   Produit des modules chaines sans table ni _ovhdlr');
 WriteLn('  ABSOLUTE       Produit une image non relogeable');
 WriteLn('  TEXTBASE[n]    Adresse de base TEXT (hexadecimal)');
 WriteLn('  DATABASE[n]    Adresse de base DATA (hexadecimal)');
 WriteLn('  BSSBASE[n]     Adresse de base BSS (hexadecimal)');
 WriteLn('Options locales apres une entree : LOCALS, NOLOCALS, INCLUDE[module]');
 WriteLn('Overlays : sortie=root,(OV1=a,b),(OV2=c,(OV3=d)); fichiers .068 par defaut');
 WriteLn('           255 overlays maximum, cinq niveaux maximum');
 WriteLn('Archives : AR68 $FF65/$FF66/$FF6D, GNU/BSD, /SYM64/, noms longs GNU/BSD');
 WriteLn('Formats DRI acceptes : $601A, $601B, $601C (2K), $601D (I/D), $601E (4K)');
 WriteLn('Symboles automatiques : _etext, _edata, _eroot, _end, _stksize');
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
 Else If IsAbbrev(U, 'CHAINED', 2) Then Opt.Chained := True
 Else Begin
  P := Pos('[', U);
  If P > 0 Then
  Begin
   If U[Length(U)] = ']' Then A := Copy(S, P + 1, Length(S) - P - 1)
   Else A := Copy(S, P + 1, Length(S) - P);
   U := Copy(U, 1, P - 1);
   If IsAbbrev(U, 'TEMPFILES', 3) Then Opt.TempPath := TrimStr(A)
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

Function StripComment(Const S: String): String;
Var I: Integer;
Begin
 For I := 1 to Length(S) do If S[I] = '\' Then
 Begin StripComment := Copy(S, 1, I - 1); Exit; End;
 StripComment := S;
End;

Function IsGlobalOnlyOption(Const U: String): Boolean;
Begin
 IsGlobalOnlyOption := IsAbbrev(U, 'UNDEFINED', 1) or IsAbbrev(U, 'SYMBOLS', 1) or
  IsAbbrev(U, 'ABSOLUTE', 2) or IsAbbrev(U, 'IGNORE', 2) or IsAbbrev(U, 'TEMPFILES', 3) or
  IsAbbrev(U, 'TEXTBASE', 3) or IsAbbrev(U, 'DATABASE', 1) or IsAbbrev(U, 'BSSBASE', 1) or
  IsAbbrev(U, 'CHAINED', 2);
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

Procedure ParseGlobalOptions(Const S: String; Var CommandName: String);
Var I, Start, Depth, P: Integer; Part, U, A: String;
Begin
 CommandName := ''; Start := 1; Depth := 0;
 For I := 1 to Length(S) + 1 do
 Begin
  If (I <= Length(S)) and (S[I] = '[') Then Inc(Depth)
  Else If (I <= Length(S)) and (S[I] = ']') Then Dec(Depth);
  If (I > Length(S)) or ((S[I] = ',') and (Depth = 0)) Then
  Begin
   Part := TrimStr(Copy(S, Start, I - Start)); U := UpCaseStr(Part); P := Pos('[', U);
   If P > 0 Then Begin
    If Part[Length(Part)] = ']' Then A := TrimStr(Copy(Part, P + 1, Length(Part) - P - 1))
    Else A := TrimStr(Copy(Part, P + 1, Length(Part) - P));
    U := TrimStr(Copy(U, 1, P - 1));
   End Else A := '';
   If IsAbbrev(U, 'COMMAND', 1) Then
   Begin
    If (P = 0) or (A = '') Then Fatal('syntaxe COMMAND[nom] invalide');
    CommandName := A; Exit;
   End;
   If IsAbbrev(U, 'INCLUDE', 2) Then Error('option locale ' + Part + ' placee dans les options globales')
   Else ParseOneOption(Part);
   Start := I + 1;
  End;
 End;
End;

Function ReadCommandFile(Const FileName: String): String;
Var F: Text; Line, R: String;
Begin
 Assign(F, FileName); Reset(F); If IOResult <> 0 Then Fatal('impossible de lire le fichier de commandes ' + FileName);
 R := '';
 While not EOF(F) do Begin
  ReadLn(F, Line); If IOResult <> 0 Then Begin Close(F); Fatal('erreur de lecture du fichier de commandes ' + FileName); End;
  Line := TrimStr(StripComment(Line));
  If Line <> '' Then Begin
   If Length(R) + Length(Line) + Ord(R <> '') > 255 Then Begin Close(F); Fatal('commande trop longue dans ' + FileName); End;
   If R <> '' Then R := R + ' '; R := R + Line;
  End;
 End;
 Close(F); ReadCommandFile := TrimStr(R);
End;

Procedure AddInputToOverlay(S: String; O: POverlay);
Var P, Q, I, Start, Depth: Integer; LocalOpt, U, Part, NamePart, Arg: String; IP: PInput;
Begin
 S := TrimStr(S); If S = '' Then Exit;
 P := Pos('[', S);
 LocalOpt := '';
 If P > 0 Then Begin
  Q := Pos(']', S); If Q = 0 Then Q := Length(S) + 1;
  LocalOpt := UpCaseStr(Copy(S, P + 1, Q - P - 1)); S := TrimStr(Copy(S, 1, P - 1));
 End;
 IP := AppendInput; IP^.FileName := S; IP^.Overlay := O; IP^.IncludeLocals := Opt.EmitLocals;
 IP^.AllMods := Opt.AllMods; IP^.IncludeName := '';
 Start := 1; Depth := 0;
 For I := 1 to Length(LocalOpt) + 1 do Begin
  If (I <= Length(LocalOpt)) and (LocalOpt[I] = '[') Then Inc(Depth)
  Else If (I <= Length(LocalOpt)) and (LocalOpt[I] = ']') Then Dec(Depth);
  If (I > Length(LocalOpt)) or ((LocalOpt[I] = ',') and (Depth = 0)) Then Begin
   Part := TrimStr(Copy(LocalOpt, Start, I - Start)); U := UpCaseStr(Part); P := Pos('[', U);
   If P > 0 Then Begin NamePart := TrimStr(Copy(U, 1, P - 1)); Q := Pos(']', U);
    If Q = 0 Then Q := Length(U) + 1; Arg := TrimStr(Copy(Part, P + 1, Q - P - 1)); End
   Else Begin NamePart := U; Arg := ''; End;
   If IsAbbrev(NamePart, 'LOCALS', 2) Then IP^.IncludeLocals := True
   Else If IsAbbrev(NamePart, 'NOLOCALS', 2) Then IP^.IncludeLocals := False
   Else If IsAbbrev(NamePart, 'ALLMODS', 2) Then IP^.AllMods := True
   Else If IsAbbrev(NamePart, 'INCLUDE', 2) Then Begin
    If Arg = '' Then Error('INCLUDE exige un nom de module apres ' + S) Else IP^.IncludeName := Arg;
   End
   Else If IsAbbrev(NamePart, 'COMMAND', 1) Then Error('COMMAND local n''est admis que comme relais de commande historique')
   Else If IsGlobalOnlyOption(NamePart) Then Error('option globale ' + Part + ' placee apres l''entree ' + S)
   Else If Part <> '' Then Error('option locale inconnue apres ' + S + ': ' + Part);
   Start := I + 1;
  End;
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
Var Cmd, Rest, OptText, CommandName, RedirectName: String; I, P, Depth, ClosePos, SplitPos: Integer;
    CommandUsed: Boolean;
Begin
 FillChar(Opt, SizeOf(Opt), 0); InputCount := 0; Cmd := '';
 For I := 1 to ParamCount do Begin If Cmd <> '' Then Cmd := Cmd + ' '; Cmd := Cmd + ParamStr(I); End;
 Cmd := TrimStr(Cmd);
 If (Cmd = '') or (Cmd = '/?') or (Cmd = '-?') or (Cmd = '--help') Then Begin ShowHelp; Halt(Ord(Cmd = '')); End;
 CommandUsed := False;
 Repeat
  Cmd := TrimStr(StripComment(Cmd)); RedirectName := ''; Depth := 0;
  For I := 1 to Length(Cmd) do Begin
   If Cmd[I] = '[' Then Inc(Depth) Else If Cmd[I] = ']' Then Begin If Depth > 0 Then Dec(Depth); End
   Else If (Cmd[I] = '>') and (Depth = 0) Then Begin RedirectName := TrimStr(Copy(Cmd, I + 1, Length(Cmd)));
    Cmd := TrimStr(Copy(Cmd, 1, I - 1)); Break; End;
  End;
  If RedirectName <> '' Then Begin
   If OutputRedirected Then Fatal('une seule redirection > est permise');
   Assign(Output, RedirectName); Rewrite(Output); If IOResult <> 0 Then Halt(2); OutputRedirected := True;
  End;
  Rest := TrimStr(Cmd); CommandName := '';
  If Rest = '' Then Fatal('commande vide');
  If Rest[1] = '[' Then
  Begin
   Depth := 0; ClosePos := 0; SplitPos := 0;
   For I := 1 to Length(Rest) do
   Begin
    If Rest[I] = '[' Then Inc(Depth) Else If Rest[I] = ']' Then Begin Dec(Depth); If Depth = 0 Then Begin ClosePos := I; Break; End; End
    Else If (Depth = 1) and (Rest[I] <= ' ') and (SplitPos = 0) Then SplitPos := I;
   End;
   If ClosePos = 0 Then Begin
    If SplitPos > 0 Then Begin OptText := Copy(Rest, 2, SplitPos - 2); Rest := TrimStr(Copy(Rest, SplitPos + 1, Length(Rest))); End
    Else Begin OptText := Copy(Rest, 2, Length(Rest) - 1); Rest := ''; End;
   End Else Begin OptText := Copy(Rest, 2, ClosePos - 2); Rest := TrimStr(Copy(Rest, ClosePos + 1, Length(Rest))); End;
   ParseGlobalOptions(OptText, CommandName);
  End;
  If CommandName <> '' Then Begin
   If CommandUsed Then Fatal('fichiers COMMAND imbriques interdits');
   CommandUsed := True; Cmd := ReadCommandFile(CommandName);
  End;
 Until CommandName = '';
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
 MP^.TextData := NewByteBuffer(CheckedAdd(MP^.TextSize, 1, 'tampon TEXT'));
 MP^.DataData := NewByteBuffer(CheckedAdd(MP^.DataSize, 1, 'tampon DATA'));
 MP^.TextRel := NewByteBuffer(CheckedAdd(CheckedMul((CheckedAdd(MP^.TextSize, 1, 'relogements TEXT') div 2), 2, 'relogements TEXT'), 2, 'relogements TEXT'));
 MP^.DataRel := NewByteBuffer(CheckedAdd(CheckedMul((CheckedAdd(MP^.DataSize, 1, 'relogements DATA') div 2), 2, 'relogements DATA'), 2, 'relogements DATA'));
End;

Function BufferLong(B: PByteBuffer; P: LongInt): LongInt;
Begin BufferLong := LongInt((LongWord(BufferByte(B, P)) shl 24) or (LongWord(BufferByte(B, P+1)) shl 16) or
 (LongWord(BufferByte(B, P+2)) shl 8) or BufferByte(B, P+3)); End;

Procedure StoreBufferLong(B: PByteBuffer; P: LongInt; V: LongInt);
Begin StoreBufferByte(B, P, Byte(LongWord(V) shr 24)); StoreBufferByte(B, P+1, Byte(LongWord(V) shr 16));
 StoreBufferByte(B, P+2, Byte(LongWord(V) shr 8)); StoreBufferByte(B, P+3, Byte(V)); End;

Procedure NormalizeRelocBuffer(B: PByteBuffer; R: PWordBuffer; Size, SrcText, SrcData, SrcBss: LongInt);
Var I, Words: LongInt; T: Integer; P, Base, V: LongInt; W: Word;
Begin
 Words := CheckedAdd(Size, 1, 'relocation word count') div 2; I := 0;
 While I < Words do Begin
  P := I * 2; T := BufferWord(R, I) and 7;
  If T = REL_UPPER Then Begin
   If I + 1 >= Words Then Exit; T := BufferWord(R, I+1) and 7; Base := 0;
   Case T of REL_TEXT: Base := SrcText; REL_DATA: Base := SrcData; REL_BSS: Base := SrcBss; End;
   If (Base <> 0) and (P + 3 < Size) Then Begin V := BufferLong(B, P) - Base; StoreBufferLong(B, P, V); End;
   Inc(I, 2); Continue;
  End;
  Base := 0; Case T of REL_TEXT: Base := SrcText; REL_DATA: Base := SrcData; REL_BSS: Base := SrcBss; End;
  If (Base <> 0) and (P + 1 < Size) Then Begin W := Word(BufferByte(B, P)) shl 8 or BufferByte(B, P+1);
   W := Word(LongInt(SmallInt(W)) - Base); StoreBufferByte(B, P, Byte(W shr 8)); StoreBufferByte(B, P+1, Byte(W)); End;
  Inc(I);
 End;
End;

Procedure NormalizeLoadedModule(M: PModule; SrcText, SrcData, SrcBss: LongInt);
Var I: LongInt; Seg: Integer; S: PSymbol;
Begin
 For I := 0 to M^.SymCount - 1 do Begin S := ModuleSymbolAt(M, I); Seg := SegmentOf(S^.SType);
  Case Seg of REL_TEXT: Dec(S^.Value, SrcText); REL_DATA: Dec(S^.Value, SrcData);
   REL_BSS: Dec(S^.Value, SrcBss); End;
 End;
 NormalizeRelocBuffer(M^.TextData, M^.TextRel, M^.TextSize, SrcText, SrcData, SrcBss);
 NormalizeRelocBuffer(M^.DataData, M^.DataRel, M^.DataSize, SrcText, SrcData, SrcBss);
End;

Procedure ValidateExternalIndex(M: PModule; Index: LongInt; Const SegmentName: String; Offset: LongInt);
Var S: PSymbol;
Begin
 If (Index < 0) or (Index >= M^.SymCount) Then Begin
  Error(M^.FileName + ': bad external index in ' + SegmentName + ' relocation at ' + DecimalStr(Offset)); Exit;
 End;
 S := ModuleSymbolAt(M, Index);
 If (S^.SType and SYM_EXTERN) = 0 Then
  Error(M^.FileName + ': relocation index does not name an external symbol: ' + S^.Name);
End;

Procedure ValidateRelocationBuffer(M: PModule; R: PWordBuffer; Size: LongInt; Const SegmentName: String);
Var I, Words, P: LongInt; W, W2: Word; T, T2: Integer;
Begin
 Words := CheckedAdd(Size, 1, 'relocation validation') div 2; I := 0;
 While I < Words do Begin
  P := I * 2; W := BufferWord(R, I); T := W and 7;
  If T = REL_UPPER Then Begin
   If (I + 1 >= Words) or (P + 3 >= Size) Then Begin
    Error(M^.FileName + ': truncated long relocation in ' + SegmentName); Exit;
   End;
   W2 := BufferWord(R, I + 1); T2 := W2 and 7;
   If not (T2 in [REL_ABS, REL_DATA, REL_TEXT, REL_BSS, REL_EXTERN]) Then
    Error(M^.FileName + ': invalid long relocation type in ' + SegmentName);
   If T2 = REL_EXTERN Then ValidateExternalIndex(M, W2 shr 3, SegmentName, P);
   Inc(I, 2); Continue;
  End;
  If not (T in [REL_ABS, REL_DATA, REL_TEXT, REL_BSS, REL_EXTERN, REL_PCREL, REL_INSTR]) Then
   Error(M^.FileName + ': invalid relocation type in ' + SegmentName);
  If T in [REL_EXTERN, REL_PCREL] Then ValidateExternalIndex(M, W shr 3, SegmentName, P);
  If (P + 1 >= Size) and not (T in [REL_ABS, REL_INSTR]) Then
   Error(M^.FileName + ': relocation beyond end of ' + SegmentName);
  Inc(I);
 End;
End;

Procedure ValidateObjects;
Var M: PModule; S: PSymbol; SegBits: Word;
Begin
 M := FirstModule;
 While M <> Nil do Begin
  S := M^.FirstSymbol;
  While S <> Nil do Begin
   SegBits := S^.SType and (SYM_TEXT or SYM_DATA or SYM_BSS);
   If (SegBits <> 0) and (SegBits <> SYM_TEXT) and (SegBits <> SYM_DATA) and (SegBits <> SYM_BSS) Then
    Error(M^.FileName + ': invalid section flags for symbol ' + S^.Name);
   S := S^.Next;
  End;
  If not M^.SourceAbsolute Then Begin
   ValidateRelocationBuffer(M, M^.TextRel, M^.TextSize, 'TEXT');
   ValidateRelocationBuffer(M, M^.DataRel, M^.DataSize, 'DATA');
  End;
  M := M^.Next;
 End;
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
Var F: File; Magic, AbsFlag: Word; SymBytes, InputStack, Entry: LongInt;
    I, N, ExpectedSymbols: LongInt; J: Integer; C: Byte;
    HeaderSize, RelPos, SrcText, SrcData, SrcBss, Required, RelBytes: LongInt; MP: PModule; S: PSymbol;
Begin
 MP := AppendModule; MP^.FileName := DisplayName; MP^.OrderKey := OrderKey; MP^.IncludeLocals := IncludeLocals; MP^.Overlay := O;
 Assign(F, FN); Reset(F, 1); If IOResult <> 0 Then Fatal('impossible de lire ' + FN);
 SeekFile(F, BasePos);
 Magic := GetWord(F);
 If (Magic < DRI_MAGIC_NORMAL) or (Magic > DRI_MAGIC_4K) Then Fatal(DisplayName + ': format DRI invalide');
 MP^.SourceMagic := Magic;
 MP^.TextSize := GetLong(F); MP^.DataSize := GetLong(F); MP^.BssSize := GetLong(F); SymBytes := GetLong(F);
 InputStack := GetLong(F); Entry := GetLong(F); AbsFlag := GetWord(F);
 MP^.SourceAbsolute := AbsFlag <> 0;
 HeaderSize := 28; SrcText := Entry;
 If Magic = DRI_MAGIC_BASES Then Begin SrcData := GetLong(F); SrcBss := GetLong(F); HeaderSize := 36; End
 Else If Magic = DRI_MAGIC_2K Then Begin SrcData := AlignLong(CheckedAdd(Entry, MP^.TextSize, DisplayName + ' base DATA'), 2048); SrcBss := CheckedAdd(SrcData, MP^.DataSize, DisplayName + ' base BSS'); End
 Else If Magic = DRI_MAGIC_ID Then Begin SrcData := 0; SrcBss := MP^.DataSize; End
 Else If Magic = DRI_MAGIC_4K Then Begin SrcData := AlignLong(CheckedAdd(Entry, MP^.TextSize, DisplayName + ' base DATA'), 4096); SrcBss := CheckedAdd(SrcData, MP^.DataSize, DisplayName + ' base BSS'); End
 Else Begin SrcData := 0; SrcBss := 0; End;
 If (MP^.TextSize < 0) or (MP^.DataSize < 0) or (MP^.BssSize < 0) or (SymBytes < 0) Then
  Fatal(DisplayName + ': taille de segment negative');
 If (SymBytes mod 14) <> 0 Then Fatal(DisplayName + ': taille de table des symboles invalide');
 ExpectedSymbols := SymBytes div 14; MP^.SymCount := 0;
 AllocateModuleBuffers(ModuleCount);
 If MemberSize = 0 Then MemberSize := FileSize(F) - BasePos;
 If MemberSize > 0 Then Begin
  If (HeaderSize > MemberSize) or (MP^.TextSize > MemberSize - HeaderSize) or
     (MP^.DataSize > MemberSize - HeaderSize - MP^.TextSize) or
     (SymBytes > MemberSize - HeaderSize - MP^.TextSize - MP^.DataSize) Then
   Fatal(DisplayName + ': membre d''archive tronque');
 End;
 Required := CheckedAdd(HeaderSize, MP^.TextSize, DisplayName + ' taille objet');
 Required := CheckedAdd(Required, MP^.DataSize, DisplayName + ' taille objet');
 Required := CheckedAdd(Required, SymBytes, DisplayName + ' taille objet');
 If AbsFlag = 0 Then Begin
  RelBytes := CheckedAdd(CheckedMul((CheckedAdd(MP^.TextSize, 1, 'table TEXT') div 2), 2, 'table TEXT'),
                         CheckedMul((CheckedAdd(MP^.DataSize, 1, 'table DATA') div 2), 2, 'table DATA'), DisplayName + ' relogements');
  Required := CheckedAdd(Required, RelBytes, DisplayName + ' taille objet');
 End;
 If Required > MemberSize Then Fatal(DisplayName + ': objet tronque (table de relogement incomplete)');
 SeekFile(F, CheckedAdd(BasePos, HeaderSize, DisplayName + ' position TEXT'));
 ReadBufferBytes(F, MP^.TextData, MP^.TextSize);
 ReadBufferBytes(F, MP^.DataData, MP^.DataSize);
 For I := 0 to ExpectedSymbols - 1 do
 Begin
  S := AppendSymbol(MP);
  For J := 1 to 8 do Begin C := GetByte(F); If C <> 0 Then S^.Name := S^.Name + Chr(C); End;
  S^.SType := GetWord(F); S^.Value := GetLong(F);
 End;
 RelPos := CheckedAdd(BasePos, HeaderSize, DisplayName + ' position relogements');
 RelPos := CheckedAdd(RelPos, MP^.TextSize, DisplayName + ' position relogements');
 RelPos := CheckedAdd(RelPos, MP^.DataSize, DisplayName + ' position relogements');
 RelPos := CheckedAdd(RelPos, SymBytes, DisplayName + ' position relogements');
 If AbsFlag = 0 Then
 Begin
  SeekFile(F, RelPos); N := CheckedAdd(MP^.TextSize, 1, 'TEXT relocation count') div 2;
  ReadBufferBytes(F, MP^.TextRel, CheckedMul(N, 2, 'TEXT relocation table'));
  N := CheckedAdd(MP^.DataSize, 1, 'DATA relocation count') div 2;
  ReadBufferBytes(F, MP^.DataRel, CheckedMul(N, 2, 'DATA relocation table'));
 End;
 If Magic <> DRI_MAGIC_NORMAL Then Begin
  NormalizeLoadedModule(MP, SrcText, SrcData, SrcBss);
  If AbsFlag <> 0 Then Warning(DisplayName + ': image DRI sans relogements, les adresses internes ne peuvent pas toutes etre normalisees');
 End;
 Close(F);
 If (O = RootOverlay) and (InputStack > StackSize) Then StackSize := InputStack;
 If Entry <> 0 Then Warning(DisplayName + ': point d''entree objet ignore');
End;

Function DecimalField(Const S: String): LongInt;
Var I: Integer; V: LongInt;
Begin V := 0; For I := 1 to Length(S) do If S[I] in ['0'..'9'] Then V := V * 10 + Ord(S[I]) - Ord('0'); DecimalField := V; End;

Function ReadAscii(Var F: File; N: Integer): String;
Var I: Integer; C: Char; R: String;
Begin R := ''; For I := 1 to N do Begin C := Chr(GetByte(F)); R := R + C; End; ReadAscii := R; End;

Procedure AddMember(InputIndex: Integer; Const Name: String; HeaderPos, DataPos, DataSize: LongInt);
Var MP: PMember;
Begin
 MP := AppendMember; MP^.InputIndex := InputIndex; MP^.Name := Name; MP^.HeaderPos := HeaderPos; MP^.DataPos := DataPos;
 MP^.DataSize := DataSize; MP^.Loaded := False; MP^.Selected := False;
End;

Function ReadArchiveName(Var F: File; Count: LongInt): String;
Var I: LongInt; C: Byte; R: String;
Begin
 R := ''; For I := 1 to Count do Begin C := GetByte(F); If (C <> 0) and (Length(R) < 255) Then R := R + Chr(C); End;
 While (Length(R) > 0) and (R[Length(R)] in [#0, ' ']) do Delete(R, Length(R), 1);
 ReadArchiveName := R;
End;

Function IsBSDIndexName(Const Name: String): Boolean;
Var U: String;
Begin U := UpCaseStr(Name); IsBSDIndexName := (Copy(U, 1, 9) = '__.SYMDEF') or (Copy(U, 1, 8) = '._SYMDEF'); End;

Function IsBSD64IndexName(Const Name: String): Boolean;
Var U: String;
Begin U := UpCaseStr(Name); IsBSD64IndexName := IsBSDIndexName(U) and (Pos('_64', U) > 0); End;

Procedure ReadUnixArchiveCatalog(InputIndex: Integer; Var F: File);
Var H, N: String; P, Sz, NameLen, I, LongSize: LongInt; LongNames: PByteBuffer;
Begin
 LongNames := Nil; LongSize := 0; P := 8;
 { Premier passage: GNU autorise la table // avant ou apres ses utilisateurs. }
 While P <= FileSize(F) - 60 do Begin
  SeekFile(F, P); H := ReadAscii(F, 60); If Copy(H, 59, 2) <> '`' + Chr(10) Then Fatal(InputAt(InputIndex)^.FileName + ': entete archive invalide');
  N := TrimStr(Copy(H, 1, 16)); Sz := DecimalField(Copy(H, 49, 10));
  If (Sz < 0) or (Sz > FileSize(F) - P - 60) Then Fatal(InputAt(InputIndex)^.FileName + ': membre archive tronque');
  If N = '//' Then Begin
   FreeByteBuffer(LongNames); LongNames := NewByteBuffer(CheckedAdd(Sz, 1, 'GNU name table')); LongSize := Sz;
   SeekFile(F, P + 60); For I := 0 to Sz - 1 do StoreBufferByte(LongNames, I, GetByte(F));
  End;
  P := CheckedAdd(CheckedAdd(P, 60, 'archive member'), Sz, 'archive member'); If Odd(P) Then P := CheckedAdd(P, 1, 'archive padding');
 End;
 P := 8;
 While P <= FileSize(F) - 60 do
 Begin
  SeekFile(F, P); H := ReadAscii(F, 60);
  If Copy(H, 59, 2) <> '`' + Chr(10) Then Fatal(InputAt(InputIndex)^.FileName + ': entete archive invalide');
  N := TrimStr(Copy(H, 1, 16)); Sz := DecimalField(Copy(H, 49, 10));
  If (Sz < 0) or (Sz > FileSize(F) - P - 60) Then Fatal(InputAt(InputIndex)^.FileName + ': membre archive tronque');
  If N = '//' Then Begin End
  Else If (N = '/') or (N = '/SYM64/') Then Begin InputAt(InputIndex)^.IndexPos := P + 60; InputAt(InputIndex)^.IndexSize := Sz;
   If N = '/SYM64/' Then InputAt(InputIndex)^.IndexKind := INDEX_GNU64 Else InputAt(InputIndex)^.IndexKind := INDEX_GNU32; End
  Else
  Begin
   NameLen := 0;
   If Copy(N, 1, 3) = '#1/' Then Begin NameLen := DecimalField(Copy(N, 4, Length(N)));
    If (NameLen < 0) or (NameLen > Sz) Then Fatal(InputAt(InputIndex)^.FileName + ': nom BSD etendu invalide');
    SeekFile(F, P + 60); N := ReadArchiveName(F, NameLen); End
   Else If (Length(N) > 1) and (N[1] = '/') and (N[2] in ['0'..'9']) Then
   Begin
    I := DecimalField(Copy(N, 2, Length(N))); N := '';
    If (LongNames = Nil) or (I < 0) or (I >= LongSize) Then Fatal(InputAt(InputIndex)^.FileName + ': offset de nom GNU invalide');
    While (I < LongSize) and not (Chr(BufferByte(LongNames, I)) in ['/', Chr(10), Chr(13), #0]) do Begin
     If Length(N) < 255 Then N := N + Chr(BufferByte(LongNames, I)); Inc(I); End;
   End Else If (Length(N) > 0) and (N[Length(N)] = '/') Then Delete(N, Length(N), 1);
   If IsBSDIndexName(N) Then Begin InputAt(InputIndex)^.IndexPos := P + 60 + NameLen;
    InputAt(InputIndex)^.IndexSize := Sz - NameLen;
    If IsBSD64IndexName(N) Then InputAt(InputIndex)^.IndexKind := INDEX_BSD64 Else InputAt(InputIndex)^.IndexKind := INDEX_BSD32;
   End Else AddMember(InputIndex, N, P, P + 60 + NameLen, Sz - NameLen);
  End;
  P := CheckedAdd(CheckedAdd(P, 60, 'archive member'), Sz, 'archive member'); If Odd(P) Then P := CheckedAdd(P, 1, 'archive padding');
 End;
 FreeByteBuffer(LongNames);
End;

Function GetLongBEAt(Var F: File; P: LongInt): LongInt;
Begin SeekFile(F, P); GetLongBEAt := GetLong(F); End;

Function SwapLong(V: LongInt): LongInt;
Begin SwapLong := LongInt((LongWord(V) shr 24) or ((LongWord(V) shr 8) and $0000FF00) or
                           ((LongWord(V) shl 8) and $00FF0000) or (LongWord(V) shl 24)); End;

Function GetIndexLongAt(Var F: File; P: LongInt; LittleEndian: Boolean): LongInt;
Var V: LongInt;
Begin V := GetLongBEAt(F, P); If LittleEndian Then V := SwapLong(V); GetIndexLongAt := V; End;

Function GetIndex64At(Var F: File; P: LongInt; LittleEndian: Boolean; Var V: LongInt): Boolean;
Var A, B: LongInt; Hi, Lo: LongWord; Fits: Boolean;
Begin
 A := GetLongBEAt(F, P); B := GetLongBEAt(F, P + 4);
 If LittleEndian Then Begin Lo := LongWord(SwapLong(A)); Hi := LongWord(SwapLong(B)); End
 Else Begin Hi := LongWord(A); Lo := LongWord(B); End;
 Fits := (Hi = 0) and (Lo <= $7FFFFFFF); GetIndex64At := Fits; If Fits Then V := LongInt(Lo) Else V := -1;
End;

Function IndexedNameAt(Var F: File; P, Limit: LongInt): String;
Var C: Byte; R: String;
Begin
 R := ''; SeekFile(F, P);
 While FilePos(F) < Limit do Begin C := GetByte(F); If C = 0 Then Break; If Length(R) < 8 Then R := R + Chr(C); End;
 IndexedNameAt := R;
End;

Function AfterIndexedName(Var F: File; P, Limit: LongInt): LongInt;
Var C: Byte;
Begin
 SeekFile(F, P); While FilePos(F) < Limit do Begin C := GetByte(F); If C = 0 Then Break; End;
 AfterIndexedName := FilePos(F);
End;

Function SelectIndexedMember(InputIndex: Integer; Offs: LongInt): Boolean;
Var M: Integer;
Begin
 SelectIndexedMember := False;
 For M := 1 to MemberCount do If (MemberAt(M)^.InputIndex = InputIndex) and
   ((MemberAt(M)^.HeaderPos = Offs) or (MemberAt(M)^.DataPos = Offs) or (MemberAt(M)^.DataPos - 60 = Offs)) and
   (not MemberAt(M)^.Loaded) Then Begin MemberAt(M)^.Selected := True; SelectIndexedMember := True; Exit; End;
End;

Function NeededIndexSymbol(Const N: String): Boolean;
Var G: Integer;
Begin G := FindGlobal(N); NeededIndexSymbol := (G > 0) and GlobalAt(G)^.Needed and (not GlobalAt(G)^.Defined); End;

Function MarkIndexedNeeded(InputIndex: Integer): Boolean;
Var F: File; Count, I, Bytes, StrSize, NamePos, Offs, StrX: LongInt; N: String[8]; Little, Valid: Boolean;
Begin
 MarkIndexedNeeded := False;
 If (InputAt(InputIndex)^.IndexPos = 0) or (InputAt(InputIndex)^.IndexSize < 4) Then Exit;
 Assign(F, InputAt(InputIndex)^.FileName); Reset(F, 1); If IOResult <> 0 Then Exit;
 Case InputAt(InputIndex)^.IndexKind of
  INDEX_GNU32:
   Begin
    Count := GetLongBEAt(F, InputAt(InputIndex)^.IndexPos);
    If (Count >= 0) and (Count <= (InputAt(InputIndex)^.IndexSize - 4) div 4) Then Begin
     NamePos := InputAt(InputIndex)^.IndexPos + 4 + Count * 4;
     For I := 0 to Count - 1 do Begin N := IndexedNameAt(F, NamePos, InputAt(InputIndex)^.IndexPos + InputAt(InputIndex)^.IndexSize);
      NamePos := AfterIndexedName(F, NamePos, InputAt(InputIndex)^.IndexPos + InputAt(InputIndex)^.IndexSize);
      If NeededIndexSymbol(N) Then Begin Offs := GetLongBEAt(F, InputAt(InputIndex)^.IndexPos + 4 + I * 4);
       If (Offs >= 0) and SelectIndexedMember(InputIndex, Offs) Then MarkIndexedNeeded := True; End; End;
    End;
   End;
  INDEX_GNU64:
   Begin
    Valid := GetIndex64At(F, InputAt(InputIndex)^.IndexPos, False, Count);
    If Valid and (Count <= (InputAt(InputIndex)^.IndexSize - 8) div 8) Then Begin
     NamePos := InputAt(InputIndex)^.IndexPos + 8 + Count * 8;
     For I := 0 to Count - 1 do Begin N := IndexedNameAt(F, NamePos, InputAt(InputIndex)^.IndexPos + InputAt(InputIndex)^.IndexSize);
      NamePos := AfterIndexedName(F, NamePos, InputAt(InputIndex)^.IndexPos + InputAt(InputIndex)^.IndexSize);
      If NeededIndexSymbol(N) and
       GetIndex64At(F, InputAt(InputIndex)^.IndexPos + 8 + I * 8, False, Offs) and
       SelectIndexedMember(InputIndex, Offs) Then MarkIndexedNeeded := True; End;
    End;
   End;
  INDEX_BSD32:
   Begin
    Bytes := GetIndexLongAt(F, InputAt(InputIndex)^.IndexPos, False); Little := False;
    If (Bytes < 0) or ((Bytes mod 8) <> 0) or (Bytes + 8 > InputAt(InputIndex)^.IndexSize) Then Begin
     Bytes := GetIndexLongAt(F, InputAt(InputIndex)^.IndexPos, True); Little := True; End;
    If (Bytes >= 0) and ((Bytes mod 8) = 0) and (Bytes + 8 <= InputAt(InputIndex)^.IndexSize) Then Begin
     Count := Bytes div 8; NamePos := InputAt(InputIndex)^.IndexPos + 4 + Bytes + 4;
     StrSize := GetIndexLongAt(F, InputAt(InputIndex)^.IndexPos + 4 + Bytes, Little);
     If (StrSize >= 0) and (NamePos + StrSize <= InputAt(InputIndex)^.IndexPos + InputAt(InputIndex)^.IndexSize) Then
      For I := 0 to Count - 1 do Begin StrX := GetIndexLongAt(F, InputAt(InputIndex)^.IndexPos + 4 + I*8, Little);
       Offs := GetIndexLongAt(F, InputAt(InputIndex)^.IndexPos + 8 + I*8, Little);
       If (StrX >= 0) and (StrX < StrSize) Then Begin N := IndexedNameAt(F, NamePos + StrX, NamePos + StrSize);
        If NeededIndexSymbol(N) and (Offs >= 0) and SelectIndexedMember(InputIndex, Offs) Then MarkIndexedNeeded := True; End; End;
    End;
   End;
  INDEX_BSD64:
   Begin
    Little := False; Valid := GetIndex64At(F, InputAt(InputIndex)^.IndexPos, False, Bytes);
    If (not Valid) or ((Bytes mod 16) <> 0) or (Bytes + 16 > InputAt(InputIndex)^.IndexSize) Then Begin
     Little := True; Valid := GetIndex64At(F, InputAt(InputIndex)^.IndexPos, True, Bytes); End;
    If Valid and ((Bytes mod 16) = 0) and (Bytes + 16 <= InputAt(InputIndex)^.IndexSize) Then Begin
     Count := Bytes div 16; NamePos := InputAt(InputIndex)^.IndexPos + 8 + Bytes + 8;
     Valid := GetIndex64At(F, InputAt(InputIndex)^.IndexPos + 8 + Bytes, Little, StrSize);
     If Valid and (NamePos + StrSize <= InputAt(InputIndex)^.IndexPos + InputAt(InputIndex)^.IndexSize) Then
      For I := 0 to Count - 1 do Begin
       Valid := GetIndex64At(F, InputAt(InputIndex)^.IndexPos + 8 + I*16, Little, StrX) and
                GetIndex64At(F, InputAt(InputIndex)^.IndexPos + 16 + I*16, Little, Offs);
       If Valid and (StrX >= 0) and (StrX < StrSize) Then Begin N := IndexedNameAt(F, NamePos + StrX, NamePos + StrSize);
        If NeededIndexSymbol(N) and SelectIndexedMember(InputIndex, Offs) Then MarkIndexedNeeded := True; End; End;
    End;
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

Function IsDRIMagicAt(Var F: File; P: LongInt): Boolean;
Var W: Word;
Begin
 If (P < 0) or (P + 2 > FileSize(F)) Then Begin IsDRIMagicAt := False; Exit; End;
 SeekFile(F, P); W := GetWord(F); IsDRIMagicAt := (W >= DRI_MAGIC_NORMAL) and (W <= DRI_MAGIC_4K);
End;

Procedure SkipOldArchivePad(Var F: File; Var P: LongInt; HeaderSize: Integer);
Var B: Byte;
Begin
 If not Odd(P) or (P >= FileSize(F)) Then Exit;
 { Certaines productions FF6D omettent le bourrage pair. On privilegie
   la position qui conduit effectivement a un objet DRI. }
 If IsDRIMagicAt(F, P + HeaderSize) Then Exit;
 If IsDRIMagicAt(F, P + 1 + HeaderSize) Then Begin Inc(P); Exit; End;
 SeekFile(F, P); B := GetByte(F); If B in [0, 10] Then Inc(P);
End;

Procedure ReadOldArchiveCatalog(InputIndex: Integer; Var F: File; BigEndian: Boolean);
Var P, Sz, Dummy: LongInt; N: String; I: Integer;
Begin
 P := 2;
 While P <= FileSize(F) - 28 do
 Begin
  SeekFile(F, P); N := '';
  For I := 1 to 14 do Begin If I = 1 Then N := ''; N := N + Chr(GetByte(F)); End;
  While (Length(N) > 0) and (N[Length(N)] in [#0, ' ']) do Delete(N, Length(N), 1);
  If N = '' Then Exit;
  Dummy := GetLongEndian(F, BigEndian); GetByte(F); GetByte(F); GetByte(F); GetByte(F);
  Sz := GetLongEndian(F, BigEndian);
  Dummy := GetWordEndian(F, BigEndian);
  If (Sz < 0) or (Sz > FileSize(F) - P - 28) Then Fatal(InputAt(InputIndex)^.FileName + ': membre AR68 tronque');
  AddMember(InputIndex, N, P, P + 28, Sz);
  P := CheckedAdd(CheckedAdd(P, 28, 'AR68 member'), Sz, 'AR68 member'); SkipOldArchivePad(F, P, 28);
 End;
End;

Procedure ReadVeryOldArchiveCatalog(InputIndex: Integer; Var F: File; BigEndian: Boolean);
Var P, Sz, Dummy: LongInt; N: String; I: Integer;
Begin
 P := 2;
 While P <= FileSize(F) - 16 do Begin
  SeekFile(F, P); N := ''; For I := 1 to 8 do N := N + Chr(GetByte(F));
  While (Length(N) > 0) and (N[Length(N)] in [#0, ' ']) do Delete(N, Length(N), 1);
  If N = '' Then Exit;
  Dummy := GetLongEndian(F, BigEndian); GetByte(F); GetByte(F); Sz := GetWordEndian(F, BigEndian);
  If (Sz < 0) or (Sz > FileSize(F) - P - 16) Then Fatal(InputAt(InputIndex)^.FileName + ': ancien membre AR68 tronque');
  AddMember(InputIndex, N, P, CheckedAdd(P, 16, 'old AR68 member'), Sz);
  P := CheckedAdd(CheckedAdd(P, 16, 'old AR68 member'), Sz, 'old AR68 member'); SkipOldArchivePad(F, P, 16);
 End;
End;

Procedure CollectGlobalNeeds;
Var M, G: Integer; I: LongInt; S: TSymbol;
Begin
 ClearGlobals;
 For M := 1 to ModuleCount do For I := 0 to ModuleAt(M)^.SymCount - 1 do
 Begin
  S := ModuleSymbolAt(ModuleAt(M), I)^;
  If (S.SType and (SYM_GLOBAL or SYM_EXTERN)) = 0 Then Continue;
  G := FindGlobal(S.Name); If G = 0 Then G := AddGlobal(S.Name);
  If IsCommonSymbol(S) Then Begin GlobalAt(G)^.Needed := True; GlobalAt(G)^.IsCommon := True;
   If S.Value > GlobalAt(G)^.CommonSize Then GlobalAt(G)^.CommonSize := S.Value; End
  Else If (S.SType and SYM_EXTERN) <> 0 Then GlobalAt(G)^.Needed := True
  Else If (S.SType and SYM_DEFINED) <> 0 Then GlobalAt(G)^.Defined := True;
 End;
End;

Function MemberDefinesNeeded(MemberIndex: Integer): Boolean;
Var F: File; Magic: Word; TextSize, DataSize, BssSize, SymBytes, P: LongInt;
    I: LongInt; J: Integer; N: String[8]; T: Word; C: Byte; G: Integer;
Begin
 MemberDefinesNeeded := False;
 Assign(F, InputAt(MemberAt(MemberIndex)^.InputIndex)^.FileName); Reset(F, 1);
 If IOResult <> 0 Then Fatal('impossible de relire la bibliotheque');
 SeekFile(F, MemberAt(MemberIndex)^.DataPos); Magic := GetWord(F);
  If (Magic < DRI_MAGIC_NORMAL) or (Magic > DRI_MAGIC_4K) Then Begin Close(F); Exit; End;
 TextSize := GetLong(F); DataSize := GetLong(F); BssSize := GetLong(F); SymBytes := GetLong(F);
 GetLong(F); GetLong(F); GetWord(F); P := 28; If Magic = DRI_MAGIC_BASES Then P := 36;
 If (TextSize < 0) or (DataSize < 0) or (SymBytes < 0) or ((SymBytes mod 14) <> 0) or
    (P > MemberAt(MemberIndex)^.DataSize) or (TextSize > MemberAt(MemberIndex)^.DataSize - P) or
    (DataSize > MemberAt(MemberIndex)^.DataSize - P - TextSize) or
    (SymBytes > MemberAt(MemberIndex)^.DataSize - P - TextSize - DataSize) Then Begin Close(F); Exit; End;
 SeekFile(F, CheckedAdd(MemberAt(MemberIndex)^.DataPos,
  CheckedAdd(P, CheckedAdd(TextSize, DataSize, 'library symbol table'), 'library symbol table'), 'library symbol table'));
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
  If (B0 = $60) and (B1 in [$1A, $1B, $1C, $1D, $1E]) Then
  Begin Close(F); ReadObjectAt(S, S, 0, 0, LongInt(I) * 10000, InputAt(I)^.IncludeLocals, InputAt(I)^.Overlay); End
  Else
  Begin
   SeekFile(F, 0); If (FileSize(F) >= 8) and (ReadAscii(F, 8) = '!<arch>' + Chr(10)) Then ReadUnixArchiveCatalog(I, F)
   Else If (B0 = $FF) and (B1 = $65) Then ReadOldArchiveCatalog(I, F, True)
   Else If (B0 = $FF) and (B1 = $66) Then ReadOldArchiveCatalog(I, F, True)
   Else If (B0 = $65) and (B1 = $FF) Then ReadOldArchiveCatalog(I, F, False)
   Else If (B0 = $66) and (B1 = $FF) Then ReadOldArchiveCatalog(I, F, False)
   Else If (B0 = $FF) and (B1 = $6D) Then Begin
    If IsDRIMagicAt(F, 18) or not IsDRIMagicAt(F, 30) Then ReadVeryOldArchiveCatalog(I, F, True)
    Else ReadOldArchiveCatalog(I, F, True); End
   Else If (B0 = $6D) and (B1 = $FF) Then Begin
    If IsDRIMagicAt(F, 18) or not IsDRIMagicAt(F, 30) Then ReadVeryOldArchiveCatalog(I, F, False)
    Else ReadOldArchiveCatalog(I, F, False); End
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
  O := M^.Overlay; M^.TextOffset := O^.ModuleText;
  O^.ModuleText := CheckedAdd(O^.ModuleText, M^.TextSize, 'layout TEXT');
  If Odd(O^.ModuleText) Then O^.ModuleText := CheckedAdd(O^.ModuleText, 1, 'alignement TEXT');
  M := M^.Next;
 End;
 M := FirstModule; While M <> Nil do Begin O := M^.Overlay; M^.DataOffset := O^.ModuleData;
  O^.ModuleData := CheckedAdd(O^.ModuleData, M^.DataSize, 'layout DATA'); If Odd(O^.ModuleData) Then O^.ModuleData := CheckedAdd(O^.ModuleData, 1, 'alignement DATA'); M := M^.Next; End;
 M := FirstModule; While M <> Nil do Begin O := M^.Overlay; M^.BssOffset := O^.ModuleBss;
  O^.ModuleBss := CheckedAdd(O^.ModuleBss, M^.BssSize, 'layout BSS'); If Odd(O^.ModuleBss) Then O^.ModuleBss := CheckedAdd(O^.ModuleBss, 1, 'alignement BSS'); M := M^.Next; End;
 O := FirstOverlay; While O <> Nil do Begin
  O^.TextSize := CheckedAdd(O^.ModuleText, CheckedMul(O^.JumpCount, OVCALL_SIZE, 'blocs overlay'), 'taille TEXT overlay');
  O^.DataSize := O^.ModuleData;
  If (O = RootOverlay) and (not Opt.Chained) Then O^.DataSize := CheckedAdd(O^.DataSize, CheckedMul(OverlayCount, OVTAB_SIZE, 'table overlays'), 'taille DATA racine');
  O^.BssSize := CheckedAdd(O^.ModuleBss, O^.CommonBss, 'taille BSS'); O := O^.NextAll;
 End;
End;

Procedure PlaceOverlay(O: POverlay; LoadBase: LongInt);
Var C: POverlay; High: LongInt;
Begin
 O^.TextBase := LoadBase; O^.DataBase := CheckedAdd(O^.TextBase, O^.TextSize, 'base DATA overlay');
 O^.BssBase := CheckedAdd(O^.DataBase, O^.DataSize, 'base BSS overlay'); O^.Capacity := CheckedAdd(O^.BssBase, O^.BssSize, 'fin overlay');
 High := O^.Capacity; C := O^.FirstChild;
 While C <> Nil do Begin PlaceOverlay(C, CheckedAdd(O^.BssBase, O^.BssSize, 'zone de chargement overlay')); If C^.Capacity > High Then High := C^.Capacity; C := C^.NextSibling; End;
 O^.Capacity := High;
End;

Function RangesOverlap(BaseA, SizeA, BaseB, SizeB: LongInt): Boolean;
Var EndA, EndB: LongInt;
Begin
 If (SizeA = 0) or (SizeB = 0) Then Begin RangesOverlap := False; Exit; End;
 EndA := CheckedAdd(BaseA, SizeA, 'fin de segment'); EndB := CheckedAdd(BaseB, SizeB, 'fin de segment');
 RangesOverlap := (BaseA < EndB) and (BaseB < EndA);
End;

Procedure ValidateSegmentRanges;
Var O: POverlay;
Begin
 O := FirstOverlay;
 While O <> Nil do Begin
  If (O^.TextBase < 0) or (O^.DataBase < 0) or (O^.BssBase < 0) Then
   Error('negative segment base in ' + O^.OutputName);
  If RangesOverlap(O^.TextBase, O^.TextSize, O^.DataBase, O^.DataSize) Then
   Error('TEXT and DATA segments overlap in ' + O^.OutputName);
  If RangesOverlap(O^.TextBase, O^.TextSize, O^.BssBase, O^.BssSize) Then
   Error('TEXT and BSS segments overlap in ' + O^.OutputName);
  If RangesOverlap(O^.DataBase, O^.DataSize, O^.BssBase, O^.BssSize) Then
   Error('DATA and BSS segments overlap in ' + O^.OutputName);
  O := O^.NextAll;
 End;
End;

Procedure PlaceAllOverlays;
Begin
 If Not Opt.TextBaseSet Then Opt.TextBase := 0;
 RootOverlay^.TextBase := Opt.TextBase;
 If Opt.DataBaseSet Then RootOverlay^.DataBase := Opt.DataBase Else RootOverlay^.DataBase := CheckedAdd(RootOverlay^.TextBase, RootOverlay^.TextSize, 'base DATA');
 If Opt.BssBaseSet Then RootOverlay^.BssBase := Opt.BssBase Else RootOverlay^.BssBase := CheckedAdd(RootOverlay^.DataBase, RootOverlay^.DataSize, 'base BSS');
 RootOverlay^.Capacity := CheckedAdd(RootOverlay^.BssBase, RootOverlay^.BssSize, 'fin programme');
 PlaceOverlay(RootOverlay, RootOverlay^.TextBase);
 { PlaceOverlay applique le placement contigu normal, les bases forcees ne concernent que le cas sans overlay. }
 If OverlayCount = 0 Then Begin
  If Opt.DataBaseSet Then RootOverlay^.DataBase := Opt.DataBase;
  If Opt.BssBaseSet Then RootOverlay^.BssBase := Opt.BssBase;
  RootOverlay^.Capacity := CheckedAdd(RootOverlay^.BssBase, RootOverlay^.BssSize, 'fin programme');
 End;
 Opt.TextBase := RootOverlay^.TextBase; Opt.DataBase := RootOverlay^.DataBase; Opt.BssBase := RootOverlay^.BssBase;
 TotalText := RootOverlay^.TextSize; TotalData := RootOverlay^.DataSize;
 TotalBss := CheckedAdd(RootOverlay^.BssSize, CheckedSub(RootOverlay^.Capacity,
  CheckedAdd(RootOverlay^.BssBase, RootOverlay^.BssSize, 'fin BSS racine'), 'zone overlays'), 'BSS total');
End;

Function SymbolFinalValue(M: Integer; Const S: TSymbol): LongInt;
Var O: POverlay;
Begin
 O := ModuleAt(M)^.Overlay;
 Case SegmentOf(S.SType) of
  REL_TEXT: SymbolFinalValue := CheckedAdd(CheckedAdd(O^.TextBase, ModuleAt(M)^.TextOffset, 'adresse symbole TEXT'), S.Value, 'adresse symbole TEXT');
  REL_DATA: SymbolFinalValue := CheckedAdd(CheckedAdd(O^.DataBase, ModuleAt(M)^.DataOffset, 'adresse symbole DATA'), S.Value, 'adresse symbole DATA');
  REL_BSS:  SymbolFinalValue := CheckedAdd(CheckedAdd(O^.BssBase, ModuleAt(M)^.BssOffset, 'adresse symbole BSS'), S.Value, 'adresse symbole BSS');
 Else SymbolFinalValue := S.Value;
 End;
End;

Procedure BuildGlobals;
Var M, G: Integer; I: LongInt; S: TSymbol; GP: PGlobal;
Begin
 ClearGlobals;
 For M := 1 to ModuleCount do For I := 0 to ModuleAt(M)^.SymCount - 1 do
 Begin
  S := ModuleSymbolAt(ModuleAt(M), I)^;
  If (S.SType and (SYM_GLOBAL or SYM_EXTERN)) = 0 Then Continue;
  G := FindGlobal(S.Name); If G = 0 Then G := AddGlobal(S.Name);
  If IsCommonSymbol(S) Then
  Begin
   GlobalAt(G)^.Needed := True; GlobalAt(G)^.IsCommon := True;
   If S.Value > GlobalAt(G)^.CommonSize Then GlobalAt(G)^.CommonSize := S.Value;
  End
  Else If (S.SType and SYM_EXTERN) <> 0 Then GlobalAt(G)^.Needed := True
  Else If (S.SType and SYM_DEFINED) <> 0 Then
  Begin
   If GlobalAt(G)^.Defined and Opt.Chained and (GlobalAt(G)^.Overlay <> RootOverlay) and
      (GlobalAt(G)^.Overlay <> ModuleAt(M)^.Overlay) Then G := AddGlobal(S.Name);
   If GlobalAt(G)^.Defined Then Error('symbole defini plusieurs fois: ' + S.Name)
   Else Begin GlobalAt(G)^.Defined := True; GlobalAt(G)^.ModuleIndex := M; GlobalAt(G)^.SymbolIndex := I;
    GlobalAt(G)^.Overlay := ModuleAt(M)^.Overlay;
    GlobalAt(G)^.FinalType := S.SType; GlobalAt(G)^.FinalValue := SymbolFinalValue(M, S); End;
  End;
 End;
 For G := 1 to GlobalCount do If GlobalAt(G)^.IsCommon and (not GlobalAt(G)^.Defined) Then
 Begin
  If Odd(RootOverlay^.BssSize) Then Begin RootOverlay^.BssSize := CheckedAdd(RootOverlay^.BssSize, 1, 'alignement BSS');
   RootOverlay^.CommonBss := CheckedAdd(RootOverlay^.CommonBss, 1, 'alignement COMMON'); End;
  GlobalAt(G)^.Defined := True; GlobalAt(G)^.FinalType := SYM_DEFINED or SYM_GLOBAL or SYM_BSS;
  GlobalAt(G)^.Overlay := RootOverlay; GlobalAt(G)^.FinalValue := CheckedAdd(RootOverlay^.BssBase, RootOverlay^.BssSize, 'adresse COMMON');
  RootOverlay^.CommonBss := CheckedAdd(RootOverlay^.CommonBss,
   CheckedAdd(GlobalAt(G)^.CommonSize, GlobalAt(G)^.CommonSize and 1, 'alignement COMMON'), 'taille COMMON');
  RootOverlay^.BssSize := CheckedAdd(RootOverlay^.ModuleBss, RootOverlay^.CommonBss, 'taille BSS COMMON');
 End;
 PlaceAllOverlays;
 For G := 1 to GlobalCount do If GlobalAt(G)^.Defined Then
  If GlobalAt(G)^.ModuleIndex > 0 Then
   GlobalAt(G)^.FinalValue := SymbolFinalValue(GlobalAt(G)^.ModuleIndex,
     ModuleSymbolAt(ModuleAt(GlobalAt(G)^.ModuleIndex), GlobalAt(G)^.SymbolIndex)^);
 For G := 1 to GlobalCount do If GlobalAt(G)^.Needed and (not GlobalAt(G)^.Defined) Then
 Begin
  GP := GlobalAt(G);
  If GP^.Name = '_etext' Then Begin GP^.Defined := True; GP^.IsSpecial := True;
   GP^.Overlay := RootOverlay; GP^.FinalType := SYM_DEFINED or SYM_GLOBAL or SYM_TEXT;
   GP^.FinalValue := CheckedAdd(RootOverlay^.TextBase, RootOverlay^.TextSize, '_etext'); End
  Else If GP^.Name = '_edata' Then Begin GP^.Defined := True; GP^.IsSpecial := True;
   GP^.Overlay := RootOverlay; GP^.FinalType := SYM_DEFINED or SYM_GLOBAL or SYM_DATA;
   GP^.FinalValue := CheckedAdd(RootOverlay^.DataBase, RootOverlay^.DataSize, '_edata'); End
  Else If GP^.Name = '_eroot' Then Begin GP^.Defined := True; GP^.IsSpecial := True;
   GP^.Overlay := RootOverlay; GP^.FinalType := SYM_DEFINED or SYM_GLOBAL or SYM_DATA;
   GP^.FinalValue := CheckedAdd(RootOverlay^.BssBase, RootOverlay^.BssSize, '_eroot'); End
  Else If GP^.Name = '_end' Then Begin GP^.Defined := True; GP^.IsSpecial := True;
   GP^.Overlay := RootOverlay; GP^.FinalType := SYM_DEFINED or SYM_GLOBAL or SYM_BSS;
   GP^.FinalValue := RootOverlay^.Capacity; End
  Else If (GP^.Name = '_stksize') or (GP^.Name = '__stksiz') Then Begin
   GP^.Defined := True; GP^.IsSpecial := True; GP^.Overlay := RootOverlay;
   GP^.FinalType := SYM_DEFINED or SYM_GLOBAL or SYM_EQUATED; GP^.FinalValue := StackSize;
  End;
 End;
 For G := 1 to GlobalCount do If GlobalAt(G)^.Needed and (not GlobalAt(G)^.Defined) Then
  If Opt.AllowUndefined Then Warning('symbole non defini conserve: ' + GlobalAt(G)^.Name)
  Else Error('symbole non defini: ' + GlobalAt(G)^.Name);
End;

Procedure RefreshSpecialSymbols;
Var G: Integer; GP: PGlobal;
Begin
 For G := 1 to GlobalCount do Begin GP := GlobalAt(G); If GP^.IsSpecial Then Begin
  If GP^.Name = '_etext' Then GP^.FinalValue := CheckedAdd(RootOverlay^.TextBase, RootOverlay^.TextSize, '_etext')
  Else If GP^.Name = '_edata' Then GP^.FinalValue := CheckedAdd(RootOverlay^.DataBase, RootOverlay^.DataSize, '_edata')
  Else If GP^.Name = '_eroot' Then GP^.FinalValue := CheckedAdd(RootOverlay^.BssBase, RootOverlay^.BssSize, '_eroot')
  Else If GP^.Name = '_end' Then GP^.FinalValue := RootOverlay^.Capacity
 Else GP^.FinalValue := StackSize;
 End;
 End;
End;

Function ReadLongBuf(B: PByteBuffer; P: LongInt): LongInt;
Begin ReadLongBuf := BufferLong(B, P); End;

Procedure WriteLongBuf(B: PByteBuffer; P: LongInt; V: LongInt);
Begin StoreBufferLong(B, P, V); End;

Function ReadWordBuf(B: PByteBuffer; P: LongInt): Word;
Begin ReadWordBuf := Word(BufferByte(B, P)) shl 8 or BufferByte(B, P+1); End;

Procedure WriteWordBuf(B: PByteBuffer; P: LongInt; V: Word);
Begin StoreBufferByte(B, P, Byte(V shr 8)); StoreBufferByte(B, P+1, Byte(V)); End;

Function RelocBase(M, RType: Integer): LongInt;
Var O: POverlay;
Begin
 O := ModuleAt(M)^.Overlay;
 Case RType of
  REL_TEXT: RelocBase := CheckedAdd(O^.TextBase, ModuleAt(M)^.TextOffset, 'base relogement TEXT');
  REL_DATA: RelocBase := CheckedAdd(O^.DataBase, ModuleAt(M)^.DataOffset, 'base relogement DATA');
  REL_BSS: RelocBase := CheckedAdd(O^.BssBase, ModuleAt(M)^.BssOffset, 'base relogement BSS');
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

Function EncodedExternalRelocation(G: Integer): Word;
Var N: Integer;
Begin
 N := OutputSymbolIndex(G);
 If (N < 0) or (N > 8191) Then Begin
  Error('external symbol index exceeds DRI relocation field: ' + GlobalAt(G)^.Name);
  EncodedExternalRelocation := REL_ABS;
 End Else EncodedExternalRelocation := Word(N shl 3) or REL_EXTERN;
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
 N := ModuleSymbolAt(ModuleAt(M), SymbolIndex)^.Name; G := FindGlobalForModule(N, M);
 If (G = 0) or (not GlobalAt(G)^.Defined) Then Exit;
 Caller := ModuleAt(M)^.Overlay; Target := GlobalAt(G)^.Overlay;
 If IsAncestor(Target, Caller) Then Exit;
 If (Target^.Parent = Caller) and (SegmentOf(GlobalAt(G)^.FinalType) = REL_TEXT) Then Begin J := AddJump(Caller, GlobalAt(G)); Exit; End;
 Error(ModuleAt(M)^.FileName + ': reference overlay illegale vers ' + N);
End;

Procedure ScanRelocationsForOverlay(M: Integer; R: PWordBuffer; Size: LongInt);
Var I, N: LongInt; T: Integer;
Begin
 N := (Size + 1) div 2; I := 0;
 While I < N do Begin
  T := BufferWord(R, I) and 7;
  If T = REL_UPPER Then Begin Inc(I); If I < N Then T := BufferWord(R, I) and 7; End;
  If T in [REL_EXTERN, REL_PCREL] Then CheckOverlayReference(M, BufferWord(R, I) shr 3);
  Inc(I);
 End;
End;

Procedure BuildOverlayJumps;
Var M, G: Integer; O: POverlay; J: PJump;
Begin
 If OverlayCount = 0 Then Exit;
 If Opt.Chained Then Begin LayoutModules; PlaceAllOverlays; RefreshSpecialSymbols; Exit; End;
 For M := 1 to ModuleCount do Begin
  ScanRelocationsForOverlay(M, ModuleAt(M)^.TextRel, ModuleAt(M)^.TextSize);
  ScanRelocationsForOverlay(M, ModuleAt(M)^.DataRel, ModuleAt(M)^.DataSize);
 End;
 LayoutModules; PlaceAllOverlays;
 For G := 1 to GlobalCount do If GlobalAt(G)^.Defined and (GlobalAt(G)^.ModuleIndex > 0) Then
  GlobalAt(G)^.FinalValue := SymbolFinalValue(GlobalAt(G)^.ModuleIndex,
   ModuleSymbolAt(ModuleAt(GlobalAt(G)^.ModuleIndex), GlobalAt(G)^.SymbolIndex)^);
 RefreshSpecialSymbols;
 O := FirstOverlay; While O <> Nil do Begin
  J := O^.FirstJump; While J <> Nil do Begin
   J^.Address := CheckedAdd(O^.TextBase, O^.ModuleText, 'overlay jump address');
   If J <> O^.FirstJump Then J^.Address := O^.FirstJump^.Address;
   J := J^.Next;
  End;
  J := O^.FirstJump; G := 0; While J <> Nil do Begin J^.Address := CheckedAdd(CheckedAdd(O^.TextBase, O^.ModuleText, 'overlay jump address'),
   CheckedMul(G, OVCALL_SIZE, 'overlay jump address'), 'overlay jump address'); Inc(G); J := J^.Next; End;
  O := O^.NextAll;
 End;
End;

Function ResolveExternal(M, G: Integer; Var Value: LongInt; Var RType: Integer): Boolean;
Var Caller, Target: POverlay; J: PJump;
Begin
 ResolveExternal := False; If (G = 0) or (not GlobalAt(G)^.Defined) Then Exit;
 Caller := ModuleAt(M)^.Overlay; Target := GlobalAt(G)^.Overlay;
 If Opt.Chained Then Begin
  If (Target = RootOverlay) or (Target = Caller) Then Begin Value := GlobalAt(G)^.FinalValue;
   RType := SegmentOf(GlobalAt(G)^.FinalType); ResolveExternal := True; End
  Else Error(ModuleAt(M)^.FileName + ': reference illegale entre modules CHAINED vers ' + GlobalAt(G)^.Name);
  Exit;
 End;
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
Var WI, Words: LongInt; RT, NextRT, SI, G: Integer; P: LongInt; V32: LongInt; V16: Word;
    AddValue, FullValue: LongInt; OutType: Word; ResType: Integer; SName: String;
Begin
 Words := CheckedAdd(SrcSize, 1, 'relocation word count') div 2; WI := 0;
 While WI < Words do
 Begin
  P := LongInt(WI) * 2; RT := BufferWord(SrcRel, WI) and 7; AddValue := 0; OutType := RT;
  If RT = REL_UPPER Then
  Begin
   If WI + 1 >= Words Then Begin Error(ModuleAt(M)^.FileName + ': relogement long tronque'); Exit; End;
   NextRT := BufferWord(SrcRel, WI + 1) and 7;
   If NextRT = REL_PCREL Then Begin Error(ModuleAt(M)^.FileName + ': PCREL long invalide'); NextRT := REL_ABS; End;
   If NextRT in [REL_TEXT, REL_DATA, REL_BSS] Then AddValue := RelocBase(M, NextRT)
   Else If NextRT = REL_EXTERN Then
   Begin
    SI := BufferWord(SrcRel, WI + 1) shr 3;
    If SI >= ModuleAt(M)^.SymCount Then Begin Error('index de symbole externe invalide'); SI := 0; End;
    SName := ModuleSymbolAt(ModuleAt(M), SI)^.Name; G := FindGlobalForModule(SName, M);
    If ResolveExternal(M, G, AddValue, NextRT) Then Begin End
    Else If Opt.AllowUndefined and (G > 0) Then NextRT := EncodedExternalRelocation(G)
    Else NextRT := REL_ABS;
   End;
   V32 := CheckedAdd(ReadLongBuf(Src, P), AddValue, ModuleAt(M)^.FileName + ' long relocation');
   WriteLongBuf(Dst, CheckedAdd(DstBase, P, 'destination relocation'), V32);
   If Opt.Absolute Then Begin StoreBufferWord(DstRel, (DstBase div 2) + WI, 0); StoreBufferWord(DstRel, (DstBase div 2) + WI + 1, 0); End
   Else Begin StoreBufferWord(DstRel, (DstBase div 2) + WI, REL_UPPER); StoreBufferWord(DstRel, (DstBase div 2) + WI + 1, NextRT); End;
   Inc(WI, 2); Continue;
  End;
  If RT in [REL_TEXT, REL_DATA, REL_BSS] Then AddValue := RelocBase(M, RT)
  Else If RT = REL_EXTERN Then
  Begin
   SI := BufferWord(SrcRel, WI) shr 3;
   If SI >= ModuleAt(M)^.SymCount Then Begin Error('index de symbole externe invalide'); SI := 0; End;
   SName := ModuleSymbolAt(ModuleAt(M), SI)^.Name; G := FindGlobalForModule(SName, M);
   ResType := OutType;
   If ResolveExternal(M, G, AddValue, ResType) Then OutType := ResType
   Else If Opt.AllowUndefined and (G > 0) Then OutType := EncodedExternalRelocation(G)
   Else OutType := REL_ABS;
  End
  Else If RT = REL_PCREL Then
  Begin
   SI := BufferWord(SrcRel, WI) shr 3;
   If SI >= ModuleAt(M)^.SymCount Then Begin Error(ModuleAt(M)^.FileName + ': index PCREL invalide'); SI := 0; End;
   SName := ModuleSymbolAt(ModuleAt(M), SI)^.Name; G := FindGlobalForModule(SName, M);
   ResType := OutType;
   If ResolveExternal(M, G, AddValue, ResType) Then AddValue := CheckedSub(AddValue,
    CheckedAdd(CheckedAdd(ModuleAt(M)^.Overlay^.TextBase, ModuleAt(M)^.TextOffset, 'PCREL source'), P, 'PCREL source'), 'PCREL displacement')
   Else Begin Error(ModuleAt(M)^.FileName + ': symbole PCREL non defini: ' + SName); AddValue := 0; End;
   OutType := REL_ABS;
  End
  Else If (RT <> REL_ABS) and (RT <> REL_INSTR) Then Error(ModuleAt(M)^.FileName + ': type de relogement invalide');
  If P + 1 < SrcSize Then Begin
   V16 := ReadWordBuf(Src, P); FullValue := CheckedAdd(SmallInt(V16), AddValue, ModuleAt(M)^.FileName + ' word relocation');
   If RT = REL_PCREL Then CheckShortOverflow(FullValue, True, ModuleAt(M)^.FileName)
   Else If RT in [REL_TEXT, REL_DATA, REL_BSS, REL_EXTERN] Then CheckShortOverflow(FullValue, False, ModuleAt(M)^.FileName);
   WriteWordBuf(Dst, CheckedAdd(DstBase, P, 'destination relocation'), Word(FullValue));
  End
  Else StoreBufferByte(Dst, CheckedAdd(DstBase, P, 'destination relocation'), BufferByte(Src, P));
  If Opt.Absolute Then StoreBufferWord(DstRel, (DstBase div 2) + WI, 0)
  Else StoreBufferWord(DstRel, (DstBase div 2) + WI, OutType);
  Inc(WI);
 End;
End;

Procedure WriteJumpBlocks(O: POverlay);
Var J: PJump; P: LongInt; G: Integer; Handler, TableAddress: LongInt;
Begin
 If Opt.Chained or (O^.FirstJump = Nil) Then Exit;
 G := FindGlobal('_ovhdlr'); If (G = 0) or (not GlobalAt(G)^.Defined) Then Begin Error('symbole _ovhdlr non defini'); Exit; End;
 If GlobalAt(G)^.Overlay <> RootOverlay Then Begin Error('_ovhdlr doit etre defini dans la racine'); Exit; End;
 Handler := GlobalAt(G)^.FinalValue; TableAddress := CheckedAdd(RootOverlay^.DataBase, RootOverlay^.ModuleData, 'overlay table address');
 J := O^.FirstJump; P := O^.ModuleText;
 While J <> Nil do Begin
  WriteWordBuf(OutText, P, $4EB9); WriteLongBuf(OutText, P + 2, Handler);
  WriteLongBuf(OutText, CheckedAdd(P, 6, 'overlay call block'), CheckedAdd(TableAddress,
   CheckedMul(J^.Target^.Overlay^.Number - 1, OVTAB_SIZE, 'overlay table entry'), 'overlay table entry'));
  WriteWordBuf(OutText, P + 10, $4EF9); WriteLongBuf(OutText, P + 12, J^.Target^.FinalValue);
  StoreBufferWord(OutTextRel, P div 2, REL_INSTR); StoreBufferWord(OutTextRel, (P div 2)+1, REL_UPPER);
  StoreBufferWord(OutTextRel, (P div 2)+2, REL_TEXT); StoreBufferWord(OutTextRel, (P div 2)+3, REL_UPPER);
  StoreBufferWord(OutTextRel, (P div 2)+4, REL_DATA); StoreBufferWord(OutTextRel, (P div 2)+5, REL_INSTR);
  StoreBufferWord(OutTextRel, (P div 2)+6, REL_UPPER); StoreBufferWord(OutTextRel, (P div 2)+7, REL_TEXT);
  Inc(P, OVCALL_SIZE); J := J^.Next;
 End;
End;

Function FileLeaf(Const S: String): String;
Var I: Integer;
Begin I := Length(S); While (I > 0) and not (S[I] in ['\','/',':']) do Dec(I); FileLeaf := Copy(S, I + 1, Length(S)); End;

Procedure WriteOverlayTable;
Var O: POverlay; P: LongInt; N, B, E: String; I, DotPos: Integer;
Begin
 If Opt.Chained Then Exit;
 P := RootOverlay^.ModuleData; O := RootOverlay^.NextAll;
 While O <> Nil do Begin
  N := UpCaseStr(FileLeaf(O^.OutputName)); DotPos := Pos('.', N);
  If DotPos > 0 Then Begin B := Copy(N, 1, DotPos - 1); E := Copy(N, DotPos + 1, 3); End Else Begin B := N; E := ''; End;
  For I := 0 to 7 do If I < Length(B) Then StoreBufferByte(OutData, P+I, Ord(B[I+1])) Else StoreBufferByte(OutData, P+I, Ord(' '));
  For I := 0 to 2 do If I < Length(E) Then StoreBufferByte(OutData, P+8+I, Ord(E[I+1])) Else StoreBufferByte(OutData, P+8+I, Ord(' '));
  StoreBufferByte(OutData, P+11, 0); WriteLongBuf(OutData, P + 12, O^.TextBase);
  StoreBufferWord(OutDataRel, (P div 2)+6, REL_UPPER); StoreBufferWord(OutDataRel, (P div 2)+7, REL_TEXT);
  Inc(P, OVTAB_SIZE); O := O^.NextAll;
 End;
End;

Procedure LinkModules(O: POverlay);
Var M: Integer;
Begin
 TotalText := O^.TextSize; TotalData := O^.DataSize;
 OutText := NewByteBuffer(CheckedAdd(TotalText, 1, 'output TEXT')); OutData := NewByteBuffer(CheckedAdd(TotalData, 1, 'output DATA'));
 OutTextRel := NewByteBuffer(CheckedAdd(CheckedMul(CheckedAdd(TotalText, 1, 'output TEXT relocations') div 2, 2, 'output TEXT relocations'), 2, 'output TEXT relocations'));
 OutDataRel := NewByteBuffer(CheckedAdd(CheckedMul(CheckedAdd(TotalData, 1, 'output DATA relocations') div 2, 2, 'output DATA relocations'), 2, 'output DATA relocations'));
 For M := 1 to ModuleCount do
 If ModuleAt(M)^.Overlay = O Then Begin
  CopyBufferRange(ModuleAt(M)^.TextData, 0, OutText, ModuleAt(M)^.TextOffset, ModuleAt(M)^.TextSize);
  CopyBufferRange(ModuleAt(M)^.DataData, 0, OutData, ModuleAt(M)^.DataOffset, ModuleAt(M)^.DataSize);
  If not ModuleAt(M)^.SourceAbsolute Then Begin
   ApplyOneRelocation(M, ModuleAt(M)^.TextData, ModuleAt(M)^.TextRel, OutText, OutTextRel, ModuleAt(M)^.TextSize, ModuleAt(M)^.TextOffset);
   ApplyOneRelocation(M, ModuleAt(M)^.DataData, ModuleAt(M)^.DataRel, OutData, OutDataRel, ModuleAt(M)^.DataSize, ModuleAt(M)^.DataOffset);
  End;
 End;
 WriteJumpBlocks(O); If O = RootOverlay Then WriteOverlayTable;
End;

Procedure DetectStackSize;
Var G: Integer; GP: PGlobal; P: LongInt;
Begin
 G := FindGlobal('_stksize'); If G = 0 Then G := FindGlobal('__stksiz'); If G = 0 Then Exit;
 GP := GlobalAt(G);
 If GP^.IsSpecial Then Exit;
 If SegmentOf(GP^.FinalType) <> REL_DATA Then Begin Warning(GP^.Name + ' doit etre un symbole DATA pour fixer la pile'); Exit; End;
 P := GP^.FinalValue - RootOverlay^.DataBase;
 If (GP^.Overlay <> RootOverlay) or (P < 0) or (RootOverlay^.DataSize < 4) or (P > RootOverlay^.DataSize - 4) Then Begin
  Warning(GP^.Name + ': valeur de pile inaccessible dans le DATA racine'); Exit;
 End;
 StackSize := ReadLongBuf(OutData, P);
 If StackSize = 0 Then StackSize := $1000 Else If StackSize <= 4 Then StackSize := 0;
 RefreshSpecialSymbols;
End;

Function OutputSymbolCount: LongInt;
Var M: Integer; I, N: LongInt; S: TSymbol;
Begin
 N := 0;
 For I := 1 to GlobalCount do If Opt.EmitSymbols or (not GlobalAt(I)^.Defined) Then Inc(N);
 If Opt.EmitSymbols Then For M := 1 to ModuleCount do If ModuleAt(M)^.IncludeLocals Then
  For I := 0 to ModuleAt(M)^.SymCount - 1 do
  Begin
   S := ModuleSymbolAt(ModuleAt(M), I)^;
   If ((S.SType and (SYM_GLOBAL or SYM_EXTERN)) = 0) and
      ((Length(S.Name) = 0) or (UpCase(S.Name[1]) <> 'L')) Then Inc(N);
  End;
 OutputSymbolCount := N;
End;

Procedure WriteOutput(O: POverlay);
Var Old: File; J, M: Integer; I, SymN: LongInt; Magic, ST: Word; NonContiguous: Boolean; S: TSymbol;
Begin
 SymN := OutputSymbolCount;
 If O <> RootOverlay Then SymN := 0;
 If SymN > $7FFFFFFF div 14 Then Fatal('symbol table exceeds DRI 32-bit size');
 PartialOutputName := O^.OutputName + '.L68PART';
 If FileExists68(PartialOutputName) Then Begin Assign(Old, PartialOutputName); Erase(Old); If IOResult <> 0 Then Fatal('cannot remove stale output ' + PartialOutputName); End;
 Assign(LinkOutputFile, PartialOutputName); Rewrite(LinkOutputFile, 1);
 If IOResult <> 0 Then Fatal('cannot create ' + PartialOutputName); LinkOutputOpen := True;
 NonContiguous := (O = RootOverlay) and ((O^.DataBase <> CheckedAdd(O^.TextBase, TotalText, 'TEXT end')) or
  (O^.BssBase <> CheckedAdd(O^.DataBase, TotalData, 'DATA end')));
 If NonContiguous Then Magic := $601B Else Magic := $601A;
 If O = RootOverlay Then TotalBss := CheckedAdd(O^.BssSize, CheckedSub(O^.Capacity,
  CheckedAdd(O^.BssBase, O^.BssSize, 'root BSS end'), 'overlay area'), 'output BSS') Else TotalBss := O^.BssSize;
 PutWord(LinkOutputFile, Magic); PutLong(LinkOutputFile, TotalText); PutLong(LinkOutputFile, TotalData); PutLong(LinkOutputFile, TotalBss);
 PutLong(LinkOutputFile, SymN * 14); If O = RootOverlay Then PutLong(LinkOutputFile, StackSize) Else PutLong(LinkOutputFile, 0); PutLong(LinkOutputFile, O^.TextBase);
 If Opt.Absolute Then PutWord(LinkOutputFile, 1) Else PutWord(LinkOutputFile, 0);
 If NonContiguous Then Begin PutLong(LinkOutputFile, O^.DataBase); PutLong(LinkOutputFile, O^.BssBase); End;
 WriteBufferBytes(LinkOutputFile, OutText, TotalText);
 WriteBufferBytes(LinkOutputFile, OutData, TotalData);
 For I := 1 to GlobalCount do If (O = RootOverlay) and (Opt.EmitSymbols or (not GlobalAt(I)^.Defined)) Then
 Begin
  For J := 1 to 8 do If J <= Length(GlobalAt(I)^.Name) Then PutByte(LinkOutputFile, Ord(GlobalAt(I)^.Name[J])) Else PutByte(LinkOutputFile, 0);
  If GlobalAt(I)^.Defined Then Begin ST := GlobalAt(I)^.FinalType or SYM_DEFINED or SYM_GLOBAL; PutWord(LinkOutputFile, ST); PutLong(LinkOutputFile, GlobalAt(I)^.FinalValue); End
  Else Begin PutWord(LinkOutputFile, SYM_EXTERN or SYM_GLOBAL); PutLong(LinkOutputFile, 0); End;
 End;
 If Opt.EmitSymbols and (O = RootOverlay) Then For M := 1 to ModuleCount do If ModuleAt(M)^.IncludeLocals Then
  For I := 0 to ModuleAt(M)^.SymCount - 1 do
  Begin
   S := ModuleSymbolAt(ModuleAt(M), I)^;
   If ((S.SType and (SYM_GLOBAL or SYM_EXTERN)) = 0) and
      ((Length(S.Name) = 0) or (UpCase(S.Name[1]) <> 'L')) Then
   Begin
    For J := 1 to 8 do If J <= Length(S.Name) Then PutByte(LinkOutputFile, Ord(S.Name[J])) Else PutByte(LinkOutputFile, 0);
    PutWord(LinkOutputFile, S.SType); PutLong(LinkOutputFile, SymbolFinalValue(M, S));
   End;
  End;
 If Not Opt.Absolute Then
 Begin
  WriteBufferBytes(LinkOutputFile, OutTextRel, (TotalText div 2) * 2);
  WriteBufferBytes(LinkOutputFile, OutDataRel, (TotalData div 2) * 2);
 End;
 Close(LinkOutputFile); If IOResult <> 0 Then Fatal('cannot close ' + PartialOutputName); LinkOutputOpen := False;
 If FileExists68(O^.OutputName) Then Begin Assign(Old, O^.OutputName); Erase(Old); If IOResult <> 0 Then Fatal('cannot replace ' + O^.OutputName); End;
 Assign(Old, PartialOutputName); Rename(Old, O^.OutputName); If IOResult <> 0 Then Fatal('cannot rename output to ' + O^.OutputName);
 PartialOutputName := '';
End;

Procedure ReleaseOutputBuffers;
Begin
 FreeByteBuffer(OutText); FreeByteBuffer(OutData); FreeByteBuffer(OutTextRel); FreeByteBuffer(OutDataRel);
End;

Function FourDigits(N: Integer): String;
Var S: String;
Begin
 Str(N, S); S := TrimStr(S); While Length(S) < 4 do S := '0' + S; FourDigits := S;
End;

Function TempPrefix: String;
Var P: String;
Begin
 P := TrimStr(Opt.TempPath);
 If (P <> '') and not (P[Length(P)] in ['\','/']) Then P := P + '\';
 TempPrefix := P;
End;

Procedure ChooseTempNames;
Var P, N: String; Found: Boolean;
Begin
 Repeat
  Inc(TempSerial); If TempSerial > 9999 Then Fatal('impossible de trouver un nom de fichier temporaire libre');
  P := TempPrefix; N := FourDigits(TempSerial);
  TempTextName := P + 'L68T' + N + '.TMP'; TempDataName := P + 'L68D' + N + '.TMP';
  TempTextRelName := P + 'L68R' + N + '.TMP'; TempDataRelName := P + 'L68S' + N + '.TMP';
  Found := FileExists68(TempTextName) or FileExists68(TempDataName) or
           FileExists68(TempTextRelName) or FileExists68(TempDataRelName);
 Until not Found;
End;

Procedure SpillOutputToTemps;
Var F: File; I: LongInt;
Begin
 ChooseTempNames;
 Assign(F, TempTextName); Rewrite(F, 1); If IOResult <> 0 Then Fatal('impossible de creer ' + TempTextName);
 WriteBufferBytes(F, OutText, TotalText); Close(F);
 Assign(F, TempDataName); Rewrite(F, 1); If IOResult <> 0 Then Fatal('impossible de creer ' + TempDataName);
 WriteBufferBytes(F, OutData, TotalData); Close(F);
 Assign(F, TempTextRelName); Rewrite(F, 1); If IOResult <> 0 Then Fatal('impossible de creer ' + TempTextRelName);
 WriteBufferBytes(F, OutTextRel, (TotalText div 2) * 2); Close(F);
 Assign(F, TempDataRelName); Rewrite(F, 1); If IOResult <> 0 Then Fatal('impossible de creer ' + TempDataRelName);
 WriteBufferBytes(F, OutDataRel, (TotalData div 2) * 2); Close(F);
End;

Procedure ReloadOutputFromTemps;
Var F: File; I: LongInt;
Begin
 OutText := NewByteBuffer(CheckedAdd(TotalText, 1, 'temporary TEXT')); OutData := NewByteBuffer(CheckedAdd(TotalData, 1, 'temporary DATA'));
 OutTextRel := NewByteBuffer(CheckedAdd(CheckedMul(CheckedAdd(TotalText, 1, 'temporary TEXT relocations') div 2, 2, 'temporary TEXT relocations'), 2, 'temporary TEXT relocations'));
 OutDataRel := NewByteBuffer(CheckedAdd(CheckedMul(CheckedAdd(TotalData, 1, 'temporary DATA relocations') div 2, 2, 'temporary DATA relocations'), 2, 'temporary DATA relocations'));
 Assign(F, TempTextName); Reset(F, 1); If IOResult <> 0 Then Fatal('impossible de relire ' + TempTextName);
 ReadBufferBytes(F, OutText, TotalText); Close(F);
 Assign(F, TempDataName); Reset(F, 1); If IOResult <> 0 Then Fatal('impossible de relire ' + TempDataName);
 ReadBufferBytes(F, OutData, TotalData); Close(F);
 Assign(F, TempTextRelName); Reset(F, 1); If IOResult <> 0 Then Fatal('impossible de relire ' + TempTextRelName);
 ReadBufferBytes(F, OutTextRel, (TotalText div 2) * 2); Close(F);
 Assign(F, TempDataRelName); Reset(F, 1); If IOResult <> 0 Then Fatal('impossible de relire ' + TempDataRelName);
 ReadBufferBytes(F, OutDataRel, (TotalData div 2) * 2); Close(F);
End;

Procedure DeleteOneTemp(Var Name: String);
Var F: File;
Begin
 If Name = '' Then Exit; Assign(F, Name); Erase(F); If IOResult <> 0 Then Warning('impossible de supprimer le temporaire ' + Name); Name := '';
End;

Procedure DeleteTempFiles;
Begin
 DeleteOneTemp(TempTextName); DeleteOneTemp(TempDataName); DeleteOneTemp(TempTextRelName); DeleteOneTemp(TempDataRelName);
End;

Procedure FreeAll;
Var MP, MN: PModule; S, SNext: PSymbol; IP, INext: PInput; AP, AN: PMember; O, ONext: POverlay; J, JNext: PJump;
Begin
 MP := FirstModule; While MP <> Nil do Begin MN := MP^.Next;
  S := MP^.FirstSymbol; While S <> Nil do Begin SNext := S^.Next; Dispose(S); S := SNext; End;
  FreeByteBuffer(MP^.TextData); FreeByteBuffer(MP^.DataData);
  FreeByteBuffer(MP^.TextRel); FreeByteBuffer(MP^.DataRel);
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
  LinkModules(O); If O = RootOverlay Then DetectStackSize;
  If ErrorCount = 0 Then Begin SpillOutputToTemps; ReleaseOutputBuffers; ReloadOutputFromTemps; WriteOutput(O); End;
  ReleaseOutputBuffers; DeleteTempFiles; O := O^.NextAll;
 End;
End;

Procedure Run;
Begin
 ErrorCount := 0; WarningCount := 0; ModuleCount := 0; GlobalCount := 0; InputCount := 0; MemberCount := 0; OverlayCount := 0; StackSize := 0; TempSerial := 0;
 FirstModule := Nil; LastModule := Nil; FirstGlobal := Nil; LastGlobal := Nil;
 FirstInput := Nil; LastInput := Nil; FirstMember := Nil; LastMember := Nil;
 FirstOverlay := Nil; LastOverlay := Nil; RootOverlay := AppendOverlay(Nil);
 OutText := Nil; OutData := Nil; OutTextRel := Nil; OutDataRel := Nil;
 PartialOutputName := ''; LinkOutputOpen := False;
 TempTextName := ''; TempDataName := ''; TempTextRelName := ''; TempDataRelName := '';
 ParseCommandLine;
 LoadInputs; SortModules; ValidateObjects;
 If ErrorCount = 0 Then Begin LayoutModules; PlaceAllOverlays; BuildGlobals; ValidateSegmentRanges; End;
 If ErrorCount = 0 Then Begin BuildOverlayJumps; ValidateSegmentRanges; End;
 If ErrorCount = 0 Then EmitAllOutputs;
 TotalText := RootOverlay^.TextSize; TotalData := RootOverlay^.DataSize;
 TotalBss := RootOverlay^.Capacity - RootOverlay^.BssBase;
 WriteLn('LINK68: ', ModuleCount, ' module(s), TEXT=', TotalText,
         ', DATA=', TotalData, ', BSS=', TotalBss,
         ', symboles=', GlobalCount, ', erreurs=', ErrorCount);
 If ErrorCount = 0 Then WriteLn('LINK68: fichier produit: ', Opt.OutputName, ', overlays=', OverlayCount);
 FreeAll;
 If OutputRedirected Then Close(Output);
 If ErrorCount <> 0 Then Halt(1);
End;

Begin
 Run;
End.
