{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Clone compact de DUMPBIN pour Turbo Pascal / Free Pascal.

  Formats pris en charge :
    - PE/COFF Windows 32/64 bits (.exe/.dll)
    - objets COFF (.obj)
    - bibliotheques COFF archive (.lib)

  L'objectif est d'offrir les options usuelles de DUMPBIN sans dependance
  externe. Certaines informations rarement presentes (FPO, lignes source)
  sont affichees quand la structure correspondante est trouvable, sinon un
  message explicite est produit. }

Program DUMPBIN;

{$IFDEF FPC}
 {$MODE TP}
{$ENDIF}

Uses Dos;

Const
 MaxSections = 256;
 MaxDirs     = 16;
 MaxSymbols  = 8192;
 MaxFileSize = 16 * 1024 * 1024;

 IMAGE_DIRECTORY_ENTRY_EXPORT      = 0;
 IMAGE_DIRECTORY_ENTRY_IMPORT      = 1;
 IMAGE_DIRECTORY_ENTRY_EXCEPTION   = 3;
 IMAGE_DIRECTORY_ENTRY_BASERELOC   = 5;
 IMAGE_DIRECTORY_ENTRY_DEBUG       = 6;
 IMAGE_DIRECTORY_ENTRY_TLS         = 9;
 IMAGE_DIRECTORY_ENTRY_LOAD_CONFIG = 10;
 IMAGE_DIRECTORY_ENTRY_IAT         = 12;
 IMAGE_DIRECTORY_ENTRY_CLR         = 14;

Type
 PByteArray = ^TByteArray;
 TByteArray = Array[0..MaxFileSize - 1] Of Byte;

 TSection = Record
  Name       : String[32];
  VSize      : LongInt;
  VAddr      : LongInt;
  RawSize    : LongInt;
  RawPtr     : LongInt;
  RelocPtr   : LongInt;
  LinePtr    : LongInt;
  RelocCount : Word;
  LineCount  : Word;
  Chars      : LongInt;
 End;

 TDir = Record
  RVA  : LongInt;
  Size : LongInt;
 End;

 TSymbol = Record
  Name   : String[64];
  Value  : LongInt;
  SecNum : Integer;
  Typ    : Word;
  SClass : Byte;
 End;

Var
 Buf      : PByteArray;
 BufSize  : LongInt;
 FileName : String;

 IsPE, IsCOFF, IsArchive, Is64 : Boolean;
 Machine, NumSections, SizeOpt : Word;
 TimeDate, SymPtr, NumSyms : LongInt;
 PEOff, OptOff, SecOff : LongInt;
 EntryRVA, ImageBase, SectionAlign, FileAlign : LongInt;
 SubSystem, DllChars : Word;
 Dirs : Array[0..MaxDirs - 1] Of TDir;
 Sections : Array[1..MaxSections] Of TSection;
 SectionCount : Integer;
 Symbols : Array[1..MaxSymbols] Of TSymbol;
 SymbolCount : Integer;

 OptAll, OptArchiveMembers, OptClrHeader, OptDependents : Boolean;
 OptDirectives, OptDisasm, OptDisasmNoBytes, OptExports : Boolean;
 OptFPO, OptHeaders, OptImports, OptLineNumbers : Boolean;
 OptLinkerMember, OptLoadConfig, OptNoPdb, OptPData : Boolean;
 OptRawData, OptRawBytes, OptRawNone, OptRelocs : Boolean;
 OptSummary, OptSymbols, OptTLS, OptUnwind, OptVersion : Boolean;
 SectionFilter, OutName : String;

Function UpStr(S: String): String;
Var I: Integer;
Begin
 For I := 1 To Length(S) Do
  If (S[I] >= 'a') And (S[I] <= 'z') Then S[I] := Chr(Ord(S[I]) - 32);
 UpStr := S;
End;

Function StartsWith(S, P: String): Boolean;
Begin
 StartsWith := Copy(S, 1, Length(P)) = P;
End;

Function HexDigit(N: Byte): Char;
Begin
 N := N And 15;
 If N < 10 Then HexDigit := Chr(Ord('0') + N)
 Else HexDigit := Chr(Ord('A') + N - 10);
End;

Function HexByte(B: Byte): String;
Begin
 HexByte := HexDigit(B Shr 4) + HexDigit(B);
End;

Function HexFixed(V: LongInt; Digits: Integer): String;
Var I: Integer; S: String;
Begin
 S := '';
 For I := 1 To Digits Do Begin
  S := HexDigit(Byte(V And $F)) + S;
  V := V Shr 4;
 End;
 HexFixed := S;
End;

Function PadRight(S: String; W: Integer): String;
Begin
 While Length(S) < W Do S := S + ' ';
 PadRight := S;
End;

Function PadLeft(S: String; W: Integer): String;
Begin
 While Length(S) < W Do S := ' ' + S;
 PadLeft := S;
End;

Function LToS(V: LongInt): String;
Var S: String;
Begin
 Str(V, S);
 LToS := S;
End;

Function TrimS(S: String): String;
Begin
 While (Length(S) > 0) And (S[1] <= ' ') Do Delete(S, 1, 1);
 While (Length(S) > 0) And (S[Length(S)] <= ' ') Do Delete(S, Length(S), 1);
 TrimS := S;
End;

Function GetByteAt(Off: LongInt): Byte;
Begin
 If (Off < 0) Or (Off >= BufSize) Then GetByteAt := 0
 Else GetByteAt := Buf^[Off];
End;

Function GetWordAt(Off: LongInt): Word;
Begin
 GetWordAt := GetByteAt(Off) Or (GetByteAt(Off + 1) Shl 8);
End;

Function GetDWordAt(Off: LongInt): LongInt;
Var L: LongInt;
Begin
 L := GetByteAt(Off + 3);
 L := (L Shl 8) Or GetByteAt(Off + 2);
 L := (L Shl 8) Or GetByteAt(Off + 1);
 L := (L Shl 8) Or GetByteAt(Off);
 GetDWordAt := L;
End;

Function GetCStr(Off: LongInt; MaxLen: Integer): String;
Var S: String; C: Byte;
Begin
 S := '';
 While (Off < BufSize) And (Length(S) < MaxLen) Do Begin
  C := GetByteAt(Off);
  If C = 0 Then Break;
  S := S + Chr(C);
  Inc(Off);
 End;
 GetCStr := S;
End;

Function MachineName(M: Word): String;
Begin
 Case M Of
  $014C: MachineName := 'x86';
  $0166: MachineName := 'MIPS R4000';
  $01F0: MachineName := 'PowerPC';
  $01F2: MachineName := 'PowerPC FP';
  $0200: MachineName := 'IA-64';
  $01A2: MachineName := 'SH3';
  $01A6: MachineName := 'SH4';
  $01C0: MachineName := 'ARM';
  $01C4: MachineName := 'ARMv7';
  $8664: MachineName := 'x64';
  $AA64: MachineName := 'ARM64';
 Else MachineName := 'inconnu';
 End;
End;

Function SectionCharText(C: LongInt): String;
Var S: String;
Begin
 S := '';
 If (C And $00000020) <> 0 Then S := S + 'CODE ';
 If (C And $00000040) <> 0 Then S := S + 'IDATA ';
 If (C And $00000080) <> 0 Then S := S + 'UDATA ';
 If (C And $02000000) <> 0 Then S := S + 'DISCARDABLE ';
 If (C And $04000000) <> 0 Then S := S + 'NOCACHE ';
 If (C And $08000000) <> 0 Then S := S + 'NOPAGE ';
 If (C And $10000000) <> 0 Then S := S + 'SHARED ';
 If (C And $20000000) <> 0 Then S := S + 'EXECUTE ';
 If (C And $40000000) <> 0 Then S := S + 'READ ';
 If (C And LongInt($80000000)) <> 0 Then S := S + 'WRITE ';
 SectionCharText := TrimS(S);
End;

Procedure LoadFile(Name: String);
Var F: File; R: Word; Total: LongInt;
Begin
 Assign(F, Name);
 FileMode := 0;
 {$I-} Reset(F, 1); {$I+}
 If IOResult <> 0 Then Begin
  WriteLn('DUMPBIN: impossible d''ouvrir ', Name);
  Halt(1);
 End;
 BufSize := FileSize(F);
 If BufSize > MaxFileSize Then Begin
  WriteLn('DUMPBIN: fichier trop grand (limite ', MaxFileSize, ' octets).');
  Close(F);
  Halt(1);
 End;
 GetMem(Buf, BufSize);
 Total := 0;
 While Total < BufSize Do Begin
  BlockRead(F, Buf^[Total], 32768, R);
  If R = 0 Then Break;
  Inc(Total, R);
 End;
 Close(F);
 BufSize := Total;
End;

Function RvaToOff(RVA: LongInt): LongInt;
Var I: Integer; A, S: LongInt;
Begin
 RvaToOff := -1;
 For I := 1 To SectionCount Do Begin
  A := Sections[I].VAddr;
  S := Sections[I].VSize;
  If Sections[I].RawSize > S Then S := Sections[I].RawSize;
  If (RVA >= A) And (RVA < A + S) Then Begin
   RvaToOff := Sections[I].RawPtr + (RVA - A);
   Exit;
  End;
 End;
 If RVA < BufSize Then RvaToOff := RVA;
End;

Function SectionMatches(Name: String): Boolean;
Begin
 SectionMatches := (SectionFilter = '') Or (UpStr(Name) = UpStr(SectionFilter));
End;

Procedure ReadCOFFHeader(Base: LongInt; HasOpt: Boolean);
Var I, P, J: Integer; S: String;
Begin
 Machine := GetWordAt(Base);
 NumSections := GetWordAt(Base + 2);
 TimeDate := GetDWordAt(Base + 4);
 SymPtr := GetDWordAt(Base + 8);
 NumSyms := GetDWordAt(Base + 12);
 SizeOpt := GetWordAt(Base + 16);
 If Not HasOpt Then SizeOpt := GetWordAt(Base + 16);
 OptOff := Base + 20;
 SecOff := OptOff + SizeOpt;
 SectionCount := NumSections;
 If SectionCount > MaxSections Then SectionCount := MaxSections;
 For I := 1 To SectionCount Do Begin
  P := SecOff + (I - 1) * 40;
  S := '';
  For J := 0 To 7 Do
   If GetByteAt(P + J) <> 0 Then S := S + Chr(GetByteAt(P + J));
  Sections[I].Name := TrimS(S);
  Sections[I].VSize := GetDWordAt(P + 8);
  Sections[I].VAddr := GetDWordAt(P + 12);
  Sections[I].RawSize := GetDWordAt(P + 16);
  Sections[I].RawPtr := GetDWordAt(P + 20);
  Sections[I].RelocPtr := GetDWordAt(P + 24);
  Sections[I].LinePtr := GetDWordAt(P + 28);
  Sections[I].RelocCount := GetWordAt(P + 32);
  Sections[I].LineCount := GetWordAt(P + 34);
  Sections[I].Chars := GetDWordAt(P + 36);
 End;
End;

Function COFFString(StrOff: LongInt): String;
Begin
 COFFString := GetCStr(SymPtr + NumSyms * 18 + StrOff, 63);
End;

Procedure ReadSymbols;
Var I, Aux: LongInt; P, StrOff: LongInt; S: String; J: Integer;
Begin
 SymbolCount := 0;
 If (SymPtr <= 0) Or (NumSyms <= 0) Then Exit;
 I := 0;
 While (I < NumSyms) And (SymbolCount < MaxSymbols) Do Begin
  P := SymPtr + I * 18;
  If P + 18 > BufSize Then Break;
  If GetDWordAt(P) = 0 Then Begin
   StrOff := GetDWordAt(P + 4);
   S := COFFString(StrOff);
  End Else Begin
   S := '';
   For J := 0 To 7 Do If GetByteAt(P + J) <> 0 Then S := S + Chr(GetByteAt(P + J));
  End;
  Inc(SymbolCount);
  Symbols[SymbolCount].Name := S;
  Symbols[SymbolCount].Value := GetDWordAt(P + 8);
  Symbols[SymbolCount].SecNum := Integer(GetWordAt(P + 12));
  Symbols[SymbolCount].Typ := GetWordAt(P + 14);
  Symbols[SymbolCount].SClass := GetByteAt(P + 16);
  Aux := GetByteAt(P + 17);
  Inc(I, 1 + Aux);
 End;
End;

Procedure ParsePE;
Var I, DirBase, Magic: Integer;
Begin
 IsPE := False; IsCOFF := False; Is64 := False;
 If (GetByteAt(0) = Ord('M')) And (GetByteAt(1) = Ord('Z')) Then Begin
  PEOff := GetDWordAt($3C);
  If (PEOff > 0) And (PEOff + 24 < BufSize) And
     (GetByteAt(PEOff) = Ord('P')) And (GetByteAt(PEOff+1) = Ord('E')) Then Begin
   IsPE := True;
   ReadCOFFHeader(PEOff + 4, True);
   Magic := GetWordAt(OptOff);
   Is64 := Magic = $20B;
   EntryRVA := GetDWordAt(OptOff + 16);
   If Is64 Then ImageBase := GetDWordAt(OptOff + 24)
   Else ImageBase := GetDWordAt(OptOff + 28);
   SectionAlign := GetDWordAt(OptOff + 32);
   FileAlign := GetDWordAt(OptOff + 36);
   SubSystem := GetWordAt(OptOff + 68);
   DllChars := GetWordAt(OptOff + 70);
   If Is64 Then DirBase := OptOff + 112 Else DirBase := OptOff + 96;
   For I := 0 To MaxDirs - 1 Do Begin
    Dirs[I].RVA := GetDWordAt(DirBase + I * 8);
    Dirs[I].Size := GetDWordAt(DirBase + I * 8 + 4);
   End;
   ReadSymbols;
  End;
 End Else Begin
  Machine := GetWordAt(0);
  If ((Machine = $014C) Or (Machine = $8664) Or (Machine = $01C0) Or
      (Machine = $AA64) Or (Machine = $0200)) And (GetWordAt(2) < 512) Then Begin
   IsCOFF := True;
   PEOff := 0;
   ReadCOFFHeader(0, False);
   ReadSymbols;
  End;
 End;
End;

Function LooksArchive: Boolean;
Begin
 LooksArchive := (BufSize >= 8) And
  (GetByteAt(0) = Ord('!')) And (GetByteAt(1) = Ord('<')) And
  (GetByteAt(2) = Ord('a')) And (GetByteAt(3) = Ord('r')) And
  (GetByteAt(4) = Ord('c')) And (GetByteAt(5) = Ord('h')) And
  (GetByteAt(6) = Ord('>'));
End;

Procedure Detect;
Begin
 IsArchive := LooksArchive;
 If Not IsArchive Then ParsePE;
End;

Procedure CmdVersion;
Begin
 WriteLn('Microsoft (R) COFF/PE Dumper clone - DUMPBIN.PAS 1.0');
 WriteLn('Compatible Turbo Pascal / Free Pascal');
End;

Procedure CmdHeaders;
Var I: Integer;
Begin
 If IsArchive Then Begin
  WriteLn('Archive COFF: ', FileName);
  Exit;
 End;
 WriteLn('FILE HEADER VALUES');
 WriteLn('             ', HexFixed(Machine,4), ' machine (', MachineName(Machine), ')');
 WriteLn(PadLeft(LToS(NumSections), 16), ' number of sections');
 WriteLn('        ', HexFixed(TimeDate,8), ' time date stamp');
 WriteLn('        ', HexFixed(SymPtr,8), ' file pointer to symbol table');
 WriteLn(PadLeft(LToS(NumSyms), 16), ' number of symbols');
 WriteLn(PadLeft(LToS(SizeOpt), 16), ' size of optional header');
 If IsPE Then Begin
  WriteLn;
  WriteLn('OPTIONAL HEADER VALUES');
  If Is64 Then WriteLn('             20B magic # (PE32+)')
  Else WriteLn('             10B magic # (PE32)');
  WriteLn('        ', HexFixed(EntryRVA,8), ' address of entry point');
  WriteLn('        ', HexFixed(ImageBase,8), ' image base');
  WriteLn('        ', HexFixed(SectionAlign,8), ' section alignment');
  WriteLn('        ', HexFixed(FileAlign,8), ' file alignment');
  WriteLn('            ', HexFixed(SubSystem,4), ' subsystem');
  WriteLn('            ', HexFixed(DllChars,4), ' DLL characteristics');
  WriteLn;
  WriteLn('DATA DIRECTORIES');
  For I := 0 To MaxDirs - 1 Do
   If Dirs[I].RVA <> 0 Then
    WriteLn(PadLeft(LToS(I), 3), '  RVA ', HexFixed(Dirs[I].RVA,8),
     '  Size ', HexFixed(Dirs[I].Size,8));
 End;
 WriteLn;
 WriteLn('SECTION HEADER VALUES');
 For I := 1 To SectionCount Do If SectionMatches(Sections[I].Name) Then Begin
  WriteLn(Sections[I].Name);
  WriteLn('        ', HexFixed(Sections[I].VSize,8), ' virtual size');
  WriteLn('        ', HexFixed(Sections[I].VAddr,8), ' virtual address');
  WriteLn('        ', HexFixed(Sections[I].RawSize,8), ' size of raw data');
  WriteLn('        ', HexFixed(Sections[I].RawPtr,8), ' file pointer to raw data');
  WriteLn('        ', HexFixed(Sections[I].RelocPtr,8), ' file pointer to relocation table');
  WriteLn('        ', HexFixed(Sections[I].LinePtr,8), ' file pointer to line numbers');
  WriteLn('            ', HexFixed(Sections[I].RelocCount,4), ' relocations');
  WriteLn('            ', HexFixed(Sections[I].LineCount,4), ' line numbers');
  WriteLn('        ', HexFixed(Sections[I].Chars,8), ' flags ', SectionCharText(Sections[I].Chars));
 End;
End;

Procedure CmdSummary;
Var I: Integer;
Begin
 WriteLn(' Summary');
 WriteLn;
 For I := 1 To SectionCount Do
  If SectionMatches(Sections[I].Name) Then
   WriteLn(PadLeft(HexFixed(Sections[I].RawSize,8), 10), ' ', Sections[I].Name);
End;

Procedure DumpBytes(Off, Size, RVA: LongInt; ByteByByte: Boolean);
Var Row, J: LongInt; Hex, Asc: String; B: Byte;
Begin
 Row := 0;
 While Row < Size Do Begin
  Write(HexFixed(RVA + Row,8), '  ');
  Hex := ''; Asc := '';
  For J := 0 To 15 Do Begin
   If Row + J < Size Then Begin
    B := GetByteAt(Off + Row + J);
    Hex := Hex + HexByte(B);
    If ByteByByte Then Hex := Hex + ' ' Else If (J Mod 2) = 1 Then Hex := Hex + ' ';
    If (B >= 32) And (B < 127) Then Asc := Asc + Chr(B) Else Asc := Asc + '.';
   End Else Begin
    If ByteByByte Then Hex := Hex + '   ' Else Hex := Hex + '  ';
   End;
  End;
  WriteLn(PadRight(Hex, 50), ' ', Asc);
  Inc(Row, 16);
 End;
End;

Procedure CmdRawData;
Var I: Integer;
Begin
 If OptRawNone Then Exit;
 For I := 1 To SectionCount Do If SectionMatches(Sections[I].Name) Then Begin
  If Sections[I].RawSize <= 0 Then Continue;
  WriteLn;
  WriteLn('RAW DATA #', I, ' ', Sections[I].Name);
  DumpBytes(Sections[I].RawPtr, Sections[I].RawSize, Sections[I].VAddr, OptRawBytes);
 End;
End;

Function DecodeX86(Off: LongInt; Var Len: Integer): String;
Var B, B2: Byte; D: LongInt;
Begin
 B := GetByteAt(Off); Len := 1;
 Case B Of
  $55: DecodeX86 := 'push ebp';
  $53: DecodeX86 := 'push ebx';
  $56: DecodeX86 := 'push esi';
  $57: DecodeX86 := 'push edi';
  $5D: DecodeX86 := 'pop ebp';
  $5B: DecodeX86 := 'pop ebx';
  $5E: DecodeX86 := 'pop esi';
  $5F: DecodeX86 := 'pop edi';
  $90: DecodeX86 := 'nop';
  $C3: DecodeX86 := 'ret';
  $CC: DecodeX86 := 'int 3';
  $E8: Begin Len := 5; D := GetDWordAt(Off+1); DecodeX86 := 'call ' + HexFixed(Off + 5 + D,8); End;
  $E9: Begin Len := 5; D := GetDWordAt(Off+1); DecodeX86 := 'jmp ' + HexFixed(Off + 5 + D,8); End;
  $EB: Begin Len := 2; DecodeX86 := 'jmp short'; End;
  $68: Begin Len := 5; DecodeX86 := 'push ' + HexFixed(GetDWordAt(Off+1),8); End;
  $6A: Begin Len := 2; DecodeX86 := 'push ' + HexFixed(GetByteAt(Off+1),2); End;
  $B8..$BF: Begin Len := 5; DecodeX86 := 'mov r' + Chr(Ord('0') + (B And 7)) + ', ' + HexFixed(GetDWordAt(Off+1),8); End;
  $8B: Begin Len := 2; B2 := GetByteAt(Off+1); DecodeX86 := 'mov /r ' + HexFixed(B2,2); End;
  $89: Begin Len := 2; B2 := GetByteAt(Off+1); DecodeX86 := 'mov /r ' + HexFixed(B2,2); End;
  $83: Begin Len := 3; DecodeX86 := 'op83 /r imm8'; End;
  $0F: Begin Len := 2; DecodeX86 := '0f ' + HexFixed(GetByteAt(Off+1),2); End;
 Else DecodeX86 := 'db ' + HexByte(B);
 End;
End;

Procedure CmdDisasm;
Var I: Integer; Off, EndOff, V, L, J: LongInt; Mn: String;
Begin
 For I := 1 To SectionCount Do Begin
  If Not SectionMatches(Sections[I].Name) Then Continue;
  If (Sections[I].Chars And $20000000) = 0 Then Continue;
  WriteLn;
  WriteLn('Disassembly of section ', Sections[I].Name);
  Off := Sections[I].RawPtr;
  EndOff := Off + Sections[I].RawSize;
  V := Sections[I].VAddr;
  While Off < EndOff Do Begin
   Mn := DecodeX86(Off, Integer(L));
   Write(HexFixed(V,8), ': ');
   If Not OptDisasmNoBytes Then Begin
    For J := 0 To L - 1 Do Write(HexByte(GetByteAt(Off + J)), ' ');
    For J := L To 7 Do Write('   ');
   End;
   WriteLn(Mn);
   Inc(Off, L); Inc(V, L);
  End;
 End;
End;

Procedure CmdSymbols;
Var I: Integer; SecName: String;
Begin
 If SymbolCount = 0 Then Begin
  WriteLn('Aucune table de symboles COFF.');
  Exit;
 End;
 WriteLn('COFF SYMBOL TABLE');
 For I := 1 To SymbolCount Do Begin
  If (Symbols[I].SecNum >= 1) And (Symbols[I].SecNum <= SectionCount) Then
   SecName := Sections[Symbols[I].SecNum].Name
  Else SecName := 'UNDEF';
  If SectionMatches(SecName) Then
   WriteLn(HexFixed(Symbols[I].Value,8), ' ',
    PadRight(SecName,10), ' ', HexFixed(Symbols[I].Typ,4), ' ',
    HexFixed(Symbols[I].SClass,2), ' ', Symbols[I].Name);
 End;
End;

Procedure CmdDirectives;
Var I: Integer; Off, N: LongInt; S: String; B: Byte;
Begin
 For I := 1 To SectionCount Do
  If UpStr(Sections[I].Name) = '.DRECTVE' Then Begin
   S := ''; Off := Sections[I].RawPtr;
   For N := 0 To Sections[I].RawSize - 1 Do Begin
    B := GetByteAt(Off + N);
    If B >= 32 Then S := S + Chr(B) Else S := S + ' ';
   End;
   WriteLn('Directives:');
   WriteLn(S);
   Exit;
  End;
 WriteLn('Aucune section .drectve.');
End;

Procedure CmdImports(DependOnly: Boolean);
Var DirOff, NameOff, Desc, Thunk, Lookup, DLLRVA, FirstThunk: LongInt;
    DLL, Fn: String; Ordinal, IsOrd: Boolean; B: Byte;
Begin
 If (Not IsPE) Or (Dirs[IMAGE_DIRECTORY_ENTRY_IMPORT].RVA = 0) Then Begin
  If Not DependOnly Then WriteLn('Aucune table d''importation.');
  Exit;
 End;
 DirOff := RvaToOff(Dirs[IMAGE_DIRECTORY_ENTRY_IMPORT].RVA);
 If DirOff < 0 Then Exit;
 Desc := DirOff;
 While (Desc + 20 <= BufSize) And
       ((GetDWordAt(Desc) <> 0) Or (GetDWordAt(Desc + 12) <> 0)) Do Begin
  DLLRVA := GetDWordAt(Desc + 12);
  DLL := GetCStr(RvaToOff(DLLRVA), 80);
  If DependOnly Then WriteLn('    ', DLL)
  Else Begin
   WriteLn;
   WriteLn('  ', DLL);
  End;
  If Not DependOnly Then Begin
   Lookup := GetDWordAt(Desc);
   FirstThunk := GetDWordAt(Desc + 16);
   If Lookup = 0 Then Lookup := FirstThunk;
   Thunk := RvaToOff(Lookup);
   While (Thunk >= 0) And (Thunk < BufSize) Do Begin
    If Is64 Then Begin
     B := GetByteAt(Thunk + 7);
     IsOrd := (B And $80) <> 0;
     NameOff := GetDWordAt(Thunk);
    End Else Begin
     NameOff := GetDWordAt(Thunk);
     IsOrd := (NameOff And LongInt($80000000)) <> 0;
    End;
    If NameOff = 0 Then Break;
    If IsOrd Then Begin
     Ordinal := True;
     Fn := 'Ordinal ' + HexFixed(NameOff And $FFFF,4);
    End Else Begin
     Ordinal := False;
     Fn := GetCStr(RvaToOff(NameOff) + 2, 120);
    End;
    If Ordinal Then WriteLn('        ', Fn)
    Else WriteLn('        ', Fn);
    If Is64 Then Inc(Thunk, 8) Else Inc(Thunk, 4);
   End;
  End;
  Inc(Desc, 20);
 End;
End;

Procedure CmdExports;
Var Off, NamesOff, OrdOff, FuncOff, I, Count: LongInt;
    NameRVA, OrdIndex, FuncRVA: LongInt;
Begin
 If (Not IsPE) Or (Dirs[IMAGE_DIRECTORY_ENTRY_EXPORT].RVA = 0) Then Begin
  WriteLn('Aucune table d''exportation.');
  Exit;
 End;
 Off := RvaToOff(Dirs[IMAGE_DIRECTORY_ENTRY_EXPORT].RVA);
 If Off < 0 Then Exit;
 WriteLn('Exports');
 WriteLn('  DLL name: ', GetCStr(RvaToOff(GetDWordAt(Off + 12)), 80));
 Count := GetDWordAt(Off + 24);
 FuncOff := RvaToOff(GetDWordAt(Off + 28));
 NamesOff := RvaToOff(GetDWordAt(Off + 32));
 OrdOff := RvaToOff(GetDWordAt(Off + 36));
 For I := 0 To Count - 1 Do Begin
  NameRVA := GetDWordAt(NamesOff + I * 4);
  OrdIndex := GetWordAt(OrdOff + I * 2);
  FuncRVA := GetDWordAt(FuncOff + OrdIndex * 4);
  WriteLn(PadLeft(LToS(OrdIndex + GetDWordAt(Off + 16)), 5), ' ',
   HexFixed(FuncRVA,8), ' ', GetCStr(RvaToOff(NameRVA), 120));
 End;
End;

Procedure CmdRelocations;
Var Off, EndOff, Page, Size, P, E: LongInt; Typ, ROff: Word;
    I, J: Integer; Found: Boolean;
Begin
 If IsPE Then Begin
  If (Dirs[IMAGE_DIRECTORY_ENTRY_BASERELOC].RVA = 0) Or
     (Dirs[IMAGE_DIRECTORY_ENTRY_BASERELOC].Size = 0) Then Begin
   WriteLn('Aucune relocation de base.');
   Exit;
  End;
  Off := RvaToOff(Dirs[IMAGE_DIRECTORY_ENTRY_BASERELOC].RVA);
  If Off < 0 Then Begin
   WriteLn('Table de relocation de base invalide.');
   Exit;
  End;
  EndOff := Off + Dirs[IMAGE_DIRECTORY_ENTRY_BASERELOC].Size;
  WriteLn('BASE RELOCATIONS');
  While (Off >= 0) And (Off + 8 <= EndOff) Do Begin
   Page := GetDWordAt(Off); Size := GetDWordAt(Off + 4);
   If Size <= 8 Then Break;
   WriteLn('  Page RVA ', HexFixed(Page,8));
   P := Off + 8;
   While P < Off + Size Do Begin
    E := GetWordAt(P); Typ := E Shr 12; ROff := E And $0FFF;
    WriteLn('    ', HexFixed(Page + ROff,8), ' type ', Typ);
    Inc(P, 2);
   End;
   Inc(Off, Size);
  End;
 End Else Begin
  Found := False;
  For I := 1 To SectionCount Do
   If SectionMatches(Sections[I].Name) And (Sections[I].RelocCount <> 0) Then
    Found := True;
  If Not Found Then Begin
   WriteLn('Aucune relocation COFF.');
   Exit;
  End;
  WriteLn('COFF RELOCATIONS');
  For I := 1 To SectionCount Do If SectionMatches(Sections[I].Name) Then Begin
   If Sections[I].RelocCount = 0 Then Continue;
   WriteLn('Section ', Sections[I].Name);
   P := Sections[I].RelocPtr;
   For J := 0 To Sections[I].RelocCount - 1 Do Begin
    WriteLn('  ', HexFixed(GetDWordAt(P),8), ' sym ',
     HexFixed(GetDWordAt(P+4),8), ' type ', HexFixed(GetWordAt(P+8),4));
    Inc(P, 10);
   End;
  End;
 End;
End;

Procedure CmdPData;
Var Off, EndOff: LongInt;
Begin
 If IsPE And (Dirs[IMAGE_DIRECTORY_ENTRY_EXCEPTION].RVA <> 0) Then Begin
  Off := RvaToOff(Dirs[IMAGE_DIRECTORY_ENTRY_EXCEPTION].RVA);
  EndOff := Off + Dirs[IMAGE_DIRECTORY_ENTRY_EXCEPTION].Size;
 End Else Begin
  Off := -1; EndOff := -1;
 End;
 If Off < 0 Then Begin
  WriteLn('Aucune information .pdata / exception.');
  Exit;
 End;
 WriteLn('.pdata / exception directory');
 While Off + 12 <= EndOff Do Begin
  WriteLn('  Begin ', HexFixed(GetDWordAt(Off),8), ' End ',
   HexFixed(GetDWordAt(Off+4),8), ' Unwind ', HexFixed(GetDWordAt(Off+8),8));
  Inc(Off, 12);
 End;
End;

Procedure CmdCLRHeader;
Var Off: LongInt;
Begin
 If (Not IsPE) Or (Dirs[IMAGE_DIRECTORY_ENTRY_CLR].RVA = 0) Then Begin
  WriteLn('Aucun en-tete CLR.');
  Exit;
 End;
 Off := RvaToOff(Dirs[IMAGE_DIRECTORY_ENTRY_CLR].RVA);
 WriteLn('CLR HEADER');
 WriteLn('        ', HexFixed(GetDWordAt(Off),8), ' cb');
 WriteLn('        ', GetWordAt(Off+4), '.', GetWordAt(Off+6), ' runtime version');
 WriteLn('        ', HexFixed(GetDWordAt(Off+8),8), ' metadata RVA');
 WriteLn('        ', HexFixed(GetDWordAt(Off+12),8), ' metadata size');
 WriteLn('        ', HexFixed(GetDWordAt(Off+16),8), ' flags');
 WriteLn('        ', HexFixed(GetDWordAt(Off+20),8), ' entry point token/RVA');
End;

Procedure CmdTLS;
Var Off: LongInt;
Begin
 If (Not IsPE) Or (Dirs[IMAGE_DIRECTORY_ENTRY_TLS].RVA = 0) Then Begin
  WriteLn('Aucune information TLS.');
  Exit;
 End;
 Off := RvaToOff(Dirs[IMAGE_DIRECTORY_ENTRY_TLS].RVA);
 WriteLn('TLS DIRECTORY');
 WriteLn('        ', HexFixed(GetDWordAt(Off),8), ' start raw data');
 WriteLn('        ', HexFixed(GetDWordAt(Off+4),8), ' end raw data');
 WriteLn('        ', HexFixed(GetDWordAt(Off+8),8), ' address of index');
 WriteLn('        ', HexFixed(GetDWordAt(Off+12),8), ' callbacks');
 WriteLn('        ', HexFixed(GetDWordAt(Off+16),8), ' zero fill');
 WriteLn('        ', HexFixed(GetDWordAt(Off+20),8), ' characteristics');
End;

Procedure CmdLoadConfig;
Var Off: LongInt;
Begin
 If (Not IsPE) Or (Dirs[IMAGE_DIRECTORY_ENTRY_LOAD_CONFIG].RVA = 0) Then Begin
  WriteLn('Aucune configuration du chargeur.');
  Exit;
 End;
 Off := RvaToOff(Dirs[IMAGE_DIRECTORY_ENTRY_LOAD_CONFIG].RVA);
 WriteLn('LOAD CONFIGURATION');
 WriteLn('        ', HexFixed(GetDWordAt(Off),8), ' size');
 WriteLn('        ', HexFixed(GetDWordAt(Off+4),8), ' time date stamp');
 WriteLn('        ', HexFixed(GetWordAt(Off+8),4), ' major version');
 WriteLn('        ', HexFixed(GetWordAt(Off+10),4), ' minor version');
 WriteLn('        ', HexFixed(GetDWordAt(Off+48),8), ' security cookie / guard flags area');
End;

Procedure CmdLineNumbers;
Var I, J: Integer; P: LongInt;
Begin
 WriteLn('COFF LINE NUMBERS');
 For I := 1 To SectionCount Do If SectionMatches(Sections[I].Name) Then Begin
  If Sections[I].LineCount = 0 Then Continue;
  WriteLn('Section ', Sections[I].Name);
  P := Sections[I].LinePtr;
  For J := 0 To Sections[I].LineCount - 1 Do Begin
   WriteLn('  ', HexFixed(GetDWordAt(P),8), ' line ', GetWordAt(P+4));
   Inc(P, 6);
  End;
 End;
End;

Procedure CmdFPO;
Begin
 If IsPE And (Dirs[IMAGE_DIRECTORY_ENTRY_DEBUG].RVA <> 0) Then
  WriteLn('DEBUG directory presente; le decodage FPO ancien n''est pas detaille par ce clone.')
 Else
  WriteLn('Aucune information FPO trouvee.');
End;

Procedure CmdArchiveMembers(Linker: Boolean);
Var Off, Size, I: LongInt; Name, Sz: String; C: Byte;
Begin
 If Not IsArchive Then Begin
  WriteLn('Ce fichier n''est pas une bibliotheque COFF archive.');
  Exit;
 End;
 Off := 8;
 WriteLn('Archive members');
 While Off + 60 <= BufSize Do Begin
  Name := ''; Sz := '';
  For I := 0 To 15 Do Begin
   C := GetByteAt(Off + I);
   If C > 32 Then Name := Name + Chr(C);
  End;
  For I := 48 To 57 Do Begin
   C := GetByteAt(Off + I);
   If C > 32 Then Sz := Sz + Chr(C);
  End;
  Val(Sz, Size, I);
  WriteLn('  ', PadRight(Name,24), ' ', Size, ' bytes');
  Off := Off + 60 + Size;
  If (Off And 1) <> 0 Then Inc(Off);
 End;
 If Linker Then
  WriteLn('Note: les membres "/" et "/<n>" sont les index de l''editeur de liens si presents.');
End;

Procedure Help;Begin
 WriteLn('DUMPBIN clone - Cette commande permet d''analyser et d''afficher en detail le contenu des fichiers ',
         'binaires Windows, tels que les executables (.exe), les bibliotheques dynamiques (.dll), les fichiers ',
         'objets (.obj) et les bibliotheques statiques (.lib), afin d''en examiner les en-tetes, les symboles, ',
         'les importations, les exportations et le code machine.');
 WriteLn;
 WriteLn('Syntaxe: DUMPBIN /OPTION fichier.exe');
 WriteLn;
 WriteLn('Options:');
 WriteLn('  /ALL              Affiche toutes les informations disponibles.');
 WriteLn('  /ARCHIVEMEMBERS   Affiche les membres contenus dans une bibliotheque .lib.');
 WriteLn('  /CLRHEADER        Affiche l''en-tete CLR des programmes .NET.');
 WriteLn('  /DEPENDENTS       Affiche les DLL dont depend le programme.');
 WriteLn('  /DIRECTIVES       Affiche les directives compilateur/editeur de liens.');
 WriteLn('  /DISASM           Desassemble les sections de code du programme.');
 WriteLn('  /DISASM:NOBYTES   Desassemble sans afficher les octets machine.');
 WriteLn('  /EXPORTS          Affiche les fonctions exportees par une DLL.');
 WriteLn('  /FPO              Affiche les informations Frame Pointer Omission.');
 WriteLn('  /HEADERS          Affiche les en-tetes du fichier executable ou objet.');
 WriteLn('  /IMPORTS          Affiche les fonctions et DLL importees.');
 WriteLn('  /LINENUMBERS      Affiche les numeros de lignes associes aux adresses.');
 WriteLn('  /LINKERMEMBER     Affiche les informations de l''editeur de liens .lib.');
 WriteLn('  /LOADCONFIG       Affiche la configuration du chargeur Windows.');
 WriteLn('  /NOPDB            Ne charge pas le fichier PDB associe.');
 WriteLn('  /OUT:fichier.txt  Redirige la sortie vers un fichier texte.');
 WriteLn('  /PDATA            Affiche les informations de gestion des exceptions.');
 WriteLn('  /RAWDATA          Affiche les donnees brutes des sections.');
 WriteLn('  /RAWDATA:BYTES    Affiche les donnees brutes octet par octet.');
 WriteLn('  /RAWDATA:NONE     Masque les donnees brutes.');
 WriteLn('  /RELOCATIONS      Affiche les entrees de relocalisation.');
 WriteLn('  /SECTION:nom      Limite l''affichage a une section specifique.');
 WriteLn('  /SUMMARY          Affiche un resume des sections du fichier.');
 WriteLn('  /SYMBOLS          Affiche la table des symboles.');
 WriteLn('  /TLS              Affiche les informations Thread Local Storage.');
 WriteLn('  /UNWINDINFO       Affiche les informations de deroulement de pile x64.');
 WriteLn('  /VERSION          Affiche la version de DUMPBIN.');
End;

Procedure ParseArgs;
Var I: Integer; A, U: String;
Begin
 If ParamCount = 0 Then Begin Help; Halt(1); End;
 For I := 1 To ParamCount Do Begin
  A := ParamStr(I); U := UpStr(A);
  If (Length(A) > 0) And ((A[1] = '/') Or (A[1] = '-')) Then Begin
   If U = '/ALL' Then OptAll := True
   Else If U = '/ARCHIVEMEMBERS' Then OptArchiveMembers := True
   Else If U = '/CLRHEADER' Then OptClrHeader := True
   Else If U = '/DEPENDENTS' Then OptDependents := True
   Else If U = '/DIRECTIVES' Then OptDirectives := True
   Else If U = '/DISASM' Then OptDisasm := True
   Else If U = '/DISASM:NOBYTES' Then Begin OptDisasm := True; OptDisasmNoBytes := True; End
   Else If U = '/EXPORTS' Then OptExports := True
   Else If U = '/FPO' Then OptFPO := True
   Else If U = '/HEADERS' Then OptHeaders := True
   Else If U = '/IMPORTS' Then OptImports := True
   Else If U = '/LINENUMBERS' Then OptLineNumbers := True
   Else If U = '/LINKERMEMBER' Then OptLinkerMember := True
   Else If U = '/LOADCONFIG' Then OptLoadConfig := True
   Else If U = '/NOPDB' Then OptNoPdb := True
   Else If StartsWith(U, '/OUT:') Then OutName := Copy(A, 6, Length(A) - 5)
   Else If U = '/PDATA' Then OptPData := True
   Else If U = '/RAWDATA' Then OptRawData := True
   Else If U = '/RAWDATA:BYTES' Then Begin OptRawData := True; OptRawBytes := True; End
   Else If U = '/RAWDATA:NONE' Then Begin OptRawData := True; OptRawNone := True; End
   Else If U = '/RELOCATIONS' Then OptRelocs := True
   Else If StartsWith(U, '/SECTION:') Then SectionFilter := Copy(A, 10, Length(A) - 9)
   Else If U = '/SUMMARY' Then OptSummary := True
   Else If U = '/SYMBOLS' Then OptSymbols := True
   Else If U = '/TLS' Then OptTLS := True
   Else If U = '/UNWINDINFO' Then OptUnwind := True
   Else If U = '/VERSION' Then OptVersion := True
   Else Begin WriteLn('Option inconnue: ', A); Halt(1); End;
  End Else FileName := A;
 End;
 If OptAll Then Begin
  OptHeaders := True; OptImports := True; OptExports := True;
  OptDirectives := True; OptSummary := True; OptSymbols := True;
  OptRelocs := True; OptRawData := True; OptClrHeader := True;
  OptTLS := True; OptLoadConfig := True; OptPData := True;
  OptLineNumbers := True; OptFPO := True;
 End;
If (FileName = '') And Not OptVersion Then Begin Help; Halt(1); End;
End;

Function HasDumpOption: Boolean;
Begin
 HasDumpOption := OptArchiveMembers Or OptLinkerMember Or OptHeaders Or
  OptSummary Or OptDependents Or OptImports Or OptExports Or OptDirectives Or
  OptSymbols Or OptLineNumbers Or OptRelocs Or OptPData Or OptUnwind Or
  OptClrHeader Or OptTLS Or OptLoadConfig Or OptFPO Or OptRawData Or
  OptDisasm Or OptVersion;
End;

Procedure Run;
Begin
 If OptVersion Then CmdVersion;
 If FileName = '' Then Exit;
 LoadFile(FileName);
 Detect;
 If Not (IsPE Or IsCOFF Or IsArchive) Then Begin
  WriteLn('DUMPBIN: format non reconnu (PE/COFF/.lib attendu).');
  Halt(1);
 End;
 If Not HasDumpOption Then Begin
  If IsArchive Then OptArchiveMembers := True
  Else OptHeaders := True;
 End;
 If OptNoPdb Then Begin
  { Option acceptee pour compatibilite : ce clone ne charge jamais de PDB. }
 End;
 If OptArchiveMembers Then CmdArchiveMembers(False);
 If OptLinkerMember Then CmdArchiveMembers(True);
 If OptHeaders Then CmdHeaders;
 If OptSummary Then CmdSummary;
 If OptDependents Then Begin WriteLn('Image has the following dependencies:'); CmdImports(True); End;
 If OptImports Then CmdImports(False);
 If OptExports Then CmdExports;
 If OptDirectives Then CmdDirectives;
 If OptSymbols Then CmdSymbols;
 If OptLineNumbers Then CmdLineNumbers;
 If OptRelocs Then CmdRelocations;
 If OptPData Or OptUnwind Then CmdPData;
 If OptClrHeader Then CmdCLRHeader;
 If OptTLS Then CmdTLS;
 If OptLoadConfig Then CmdLoadConfig;
 If OptFPO Then CmdFPO;
 If OptRawData Then CmdRawData;
 If OptDisasm Then CmdDisasm;
End;

BEGIN
  If (ParamCount >= 1) And
     ((ParamStr(1) = '-h') Or (ParamStr(1) = '--help') Or
      (ParamStr(1) = '/?') Or (ParamStr(1) = '/h') Or
      (ParamStr(1) = '/H')) Then
  Begin
    Help;
    Halt(0);
  End;
 ParseArgs;
 If OutName <> '' Then Begin
  Assign(Output, OutName);
  Rewrite(Output);
 End;
 Run;
 If OutName <> '' Then Close(Output);
 If BufSize > 0 Then FreeMem(Buf, BufSize);
END.
