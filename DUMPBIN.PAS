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
 MaxPdbStreams = 512;
 MaxClrNames = 4096;
 MaxFileSize = 16 * 1024 * 1024;

 IMAGE_DIRECTORY_ENTRY_EXPORT      = 0;
 IMAGE_DIRECTORY_ENTRY_IMPORT      = 1;
 IMAGE_DIRECTORY_ENTRY_RESOURCE    = 2;
 IMAGE_DIRECTORY_ENTRY_EXCEPTION   = 3;
 IMAGE_DIRECTORY_ENTRY_SECURITY    = 4;
 IMAGE_DIRECTORY_ENTRY_BASERELOC   = 5;
 IMAGE_DIRECTORY_ENTRY_DEBUG       = 6;
 IMAGE_DIRECTORY_ENTRY_COPYRIGHT   = 7;
 IMAGE_DIRECTORY_ENTRY_GLOBALPTR   = 8;
 IMAGE_DIRECTORY_ENTRY_TLS         = 9;
 IMAGE_DIRECTORY_ENTRY_LOAD_CONFIG = 10;
 IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT = 11;
 IMAGE_DIRECTORY_ENTRY_IAT         = 12;
 IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT = 13;
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

IsPE, IsCOFF, IsArchive, Is64, IsBigObj : Boolean;
IsPDB : Boolean;
Machine, NumSections, SizeOpt : Word;
TimeDate, SymPtr, NumSyms : LongInt;
PEOff, OptOff, SecOff : LongInt;
EntryRVA, ImageBase, SectionAlign, FileAlign : LongInt;
SubSystem, DllChars : Word;
PdbPageSize, PdbNumPages, PdbDirSize, PdbBlockMapPage : LongInt;
Dirs : Array[0..MaxDirs - 1] Of TDir;
 Sections : Array[1..MaxSections] Of TSection;
 SectionCount : Integer;
 Symbols : Array[1..MaxSymbols] Of TSymbol;
SymbolCount : Integer;
ClrTypeNames   : Array[1..MaxClrNames] Of String[80];
ClrMethodNames : Array[1..MaxClrNames] Of String[80];
ClrMemberRefs  : Array[1..MaxClrNames] Of String[80];
ClrTypeCount, ClrMethodCount, ClrMemberRefCount : Integer;

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
  $02A0: MachineName := 'SPARC';
  $01A2: MachineName := 'SH3';
  $01A6: MachineName := 'SH4';
  $01C0: MachineName := 'ARM';
  $01C4: MachineName := 'ARMv7';
  $8664: MachineName := 'x64';
  $AA64: MachineName := 'ARM64';
 Else MachineName := 'inconnu';
 End;
End;

Function DirectoryName(I: Integer): String;
Begin
 Case I Of
  0: DirectoryName := 'EXPORT';
  1: DirectoryName := 'IMPORT';
  2: DirectoryName := 'RESOURCE';
  3: DirectoryName := 'EXCEPTION';
  4: DirectoryName := 'SECURITY';
  5: DirectoryName := 'BASERELOC';
  6: DirectoryName := 'DEBUG';
  7: DirectoryName := 'COPYRIGHT';
  8: DirectoryName := 'GLOBALPTR';
  9: DirectoryName := 'TLS';
 10: DirectoryName := 'LOAD_CONFIG';
 11: DirectoryName := 'BOUND_IMPORT';
 12: DirectoryName := 'IAT';
 13: DirectoryName := 'DELAY_IMPORT';
 14: DirectoryName := 'CLR';
 Else DirectoryName := 'RESERVED';
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

Function LooksBigObj: Boolean;
Begin
 LooksBigObj := (BufSize >= 56) And
  (GetWordAt(0) = 0) And (GetWordAt(2) = $FFFF) And
  (GetWordAt(4) >= 2);
End;

Procedure ParseBigObj;
Var I, P, J: LongInt; S: String;
Begin
 IsBigObj := False;
 If Not LooksBigObj Then Exit;
 IsBigObj := True;
 IsCOFF := True;
 Machine := GetWordAt(6);
 TimeDate := GetDWordAt(8);
 NumSections := 0;
 SectionCount := GetDWordAt(44);
 SymPtr := GetDWordAt(48);
 NumSyms := GetDWordAt(52);
 SizeOpt := 0;
 If SectionCount > MaxSections Then SectionCount := MaxSections;
 SecOff := 56;
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
 IsPE := False; IsCOFF := False; Is64 := False; IsBigObj := False;
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
  If LooksBigObj Then Begin
   ParseBigObj;
   Exit;
  End;
  Machine := GetWordAt(0);
  If ((Machine = $014C) Or (Machine = $8664) Or (Machine = $01C0) Or
      (Machine = $01C4) Or (Machine = $AA64) Or (Machine = $0166) Or
      (Machine = $01F0) Or (Machine = $01F2) Or (Machine = $01A2) Or
      (Machine = $01A6) Or (Machine = $0200) Or (Machine = $02A0)) And
      (GetWordAt(2) < 512) Then Begin
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

Function LooksPDB: Boolean;
Begin
 LooksPDB := (BufSize >= 64) And
  (GetCStr(0, 24) = 'Microsoft C/C++ MSF 7.00');
End;

Procedure ParsePDB;
Begin
 IsPDB := LooksPDB;
 If Not IsPDB Then Exit;
 PdbPageSize := GetDWordAt(32);
 PdbNumPages := GetDWordAt(40);
 PdbDirSize := GetDWordAt(44);
 PdbBlockMapPage := GetDWordAt(52);
 If (PdbPageSize <= 0) Or (PdbPageSize > 16384) Then IsPDB := False;
End;

Procedure Detect;
Begin
 IsPDB := False;
 ParsePDB;
 If IsPDB Then Exit;
 IsArchive := LooksArchive;
 If Not IsArchive Then ParsePE;
End;

Procedure CmdVersion;
Begin
 WriteLn('Microsoft (R) COFF/PE Dumper clone - DUMPBIN.PAS 1.0');
 WriteLn('Compatible Turbo Pascal / Free Pascal');
End;

Function DebugTypeName(T: LongInt): String;
Begin
 Case T Of
  0: DebugTypeName := 'UNKNOWN';
  1: DebugTypeName := 'COFF';
  2: DebugTypeName := 'CODEVIEW/PDB';
  3: DebugTypeName := 'FPO';
  4: DebugTypeName := 'MISC';
  5: DebugTypeName := 'EXCEPTION';
  6: DebugTypeName := 'FIXUP';
  9: DebugTypeName := 'BORLAND';
  10: DebugTypeName := 'RESERVED10';
  11: DebugTypeName := 'CLSID';
  12: DebugTypeName := 'VC_FEATURE';
  13: DebugTypeName := 'POGO';
  14: DebugTypeName := 'ILTCG';
  16: DebugTypeName := 'REPRO';
 Else DebugTypeName := 'TYPE ' + LToS(T);
 End;
End;

Function GetSig4(Off: LongInt): String;
Var S: String; I: Integer; B: Byte;
Begin
 S := '';
 For I := 0 To 3 Do Begin
  B := GetByteAt(Off + I);
  If (B >= 32) And (B < 127) Then S := S + Chr(B)
  Else S := S + '.';
 End;
 GetSig4 := S;
End;

Function GuidText(Off: LongInt): String;
Begin
 GuidText :=
  HexByte(GetByteAt(Off + 3)) + HexByte(GetByteAt(Off + 2)) +
  HexByte(GetByteAt(Off + 1)) + HexByte(GetByteAt(Off + 0)) + '-' +
  HexByte(GetByteAt(Off + 5)) + HexByte(GetByteAt(Off + 4)) + '-' +
  HexByte(GetByteAt(Off + 7)) + HexByte(GetByteAt(Off + 6)) + '-' +
  HexByte(GetByteAt(Off + 8)) + HexByte(GetByteAt(Off + 9)) + '-' +
  HexByte(GetByteAt(Off + 10)) + HexByte(GetByteAt(Off + 11)) +
  HexByte(GetByteAt(Off + 12)) + HexByte(GetByteAt(Off + 13)) +
  HexByte(GetByteAt(Off + 14)) + HexByte(GetByteAt(Off + 15));
End;

Procedure CmdDebugDirectory;
Var DirOff, Count, I, EOff, Typ, Size, RVA, Raw, DataOff: LongInt;
    Sig, PdbName: String;
Begin
 If (Not IsPE) Or (Dirs[IMAGE_DIRECTORY_ENTRY_DEBUG].RVA = 0) Or
    (Dirs[IMAGE_DIRECTORY_ENTRY_DEBUG].Size = 0) Then Exit;
 DirOff := RvaToOff(Dirs[IMAGE_DIRECTORY_ENTRY_DEBUG].RVA);
 If DirOff < 0 Then Exit;
 Count := Dirs[IMAGE_DIRECTORY_ENTRY_DEBUG].Size Div 28;
 If Count <= 0 Then Exit;
 WriteLn;
 WriteLn('DEBUG DIRECTORY');
 For I := 0 To Count - 1 Do Begin
  EOff := DirOff + I * 28;
  Typ := GetDWordAt(EOff + 12);
  Size := GetDWordAt(EOff + 16);
  RVA := GetDWordAt(EOff + 20);
  Raw := GetDWordAt(EOff + 24);
  DataOff := Raw;
  If (DataOff <= 0) Or (DataOff >= BufSize) Then DataOff := RvaToOff(RVA);
  WriteLn('  Type ', PadRight(DebugTypeName(Typ), 14),
   ' Size ', HexFixed(Size,8), ' RVA ', HexFixed(RVA,8),
   ' Raw ', HexFixed(Raw,8));
  If (Typ = 2) And (DataOff >= 0) And (DataOff + 4 < BufSize) Then Begin
   Sig := GetSig4(DataOff);
   If Sig = 'RSDS' Then Begin
    PdbName := GetCStr(DataOff + 24, 160);
    WriteLn('    CodeView: RSDS');
    WriteLn('    PDB GUID: ', GuidText(DataOff + 4));
    WriteLn('    PDB Age : ', GetDWordAt(DataOff + 20));
    If Not OptNoPdb Then WriteLn('    PDB File: ', PdbName)
    Else WriteLn('    PDB File: masque par /NOPDB');
   End Else If Sig = 'NB10' Then Begin
    PdbName := GetCStr(DataOff + 16, 160);
    WriteLn('    CodeView: NB10');
    WriteLn('    Signature: ', HexFixed(GetDWordAt(DataOff + 8),8));
    WriteLn('    PDB Age  : ', GetDWordAt(DataOff + 12));
    If Not OptNoPdb Then WriteLn('    PDB File : ', PdbName)
    Else WriteLn('    PDB File : masque par /NOPDB');
   End Else
    WriteLn('    CodeView signature: ', Sig);
  End;
 End;
End;

Procedure CmdRichHeader;
Var RichOff, DansOff, P, Key, DecVal, Prod, Build, Count: LongInt;
Begin
 If Not IsPE Then Exit;
 RichOff := -1;
 P := $80;
 While (P + 4 < PEOff) And (P + 4 < BufSize) Do Begin
  If GetDWordAt(P) = $68636952 Then Begin { "Rich" }
   RichOff := P; Break;
  End;
  Inc(P,4);
 End;
 If RichOff < 0 Then Exit;
 Key := GetDWordAt(RichOff + 4);
 DansOff := -1;
 P := RichOff - 4;
 While P >= $40 Do Begin
  If (GetDWordAt(P) Xor Key) = $536E6144 Then Begin { "DanS" }
   DansOff := P; Break;
  End;
  Dec(P,4);
 End;
 If DansOff < 0 Then Exit;
 WriteLn;
 WriteLn('RICH HEADER');
 WriteLn('        Key ', HexFixed(Key,8));
 P := DansOff + 16;
 While P + 8 <= RichOff Do Begin
  DecVal := GetDWordAt(P) Xor Key;
  Count := GetDWordAt(P + 4) Xor Key;
  Prod := DecVal Shr 16;
  Build := DecVal And $FFFF;
  WriteLn('        Product ', PadLeft(LToS(Prod),5),
   ' Build ', PadLeft(LToS(Build),5), ' Count ', Count);
  Inc(P,8);
 End;
End;

Function ResIdName(Base, EntryOff: LongInt): String;
Var NameVal, NameOff, Len, I: LongInt; S: String;
Begin
 NameVal := GetDWordAt(EntryOff);
 If NameVal < 0 Then Begin
  NameOff := Base + (NameVal And $7FFFFFFF);
  Len := GetWordAt(NameOff);
  S := '';
  For I := 0 To Len - 1 Do Begin
   If GetByteAt(NameOff + 2 + I * 2) >= 32 Then
    S := S + Chr(GetByteAt(NameOff + 2 + I * 2));
   If Length(S) >= 60 Then Break;
  End;
  ResIdName := '"' + S + '"';
 End Else
  ResIdName := '#' + LToS(NameVal);
End;

Procedure DumpResourceDir(Base, DirOff: LongInt; Level: Integer);
Var Named, Ids, I, Entries, EntryOff, DataVal, Child, DataEntry: LongInt;
    Ind: String;
Begin
 If (DirOff < Base) Or (DirOff + 16 > BufSize) Then Exit;
 Named := GetWordAt(DirOff + 12);
 Ids := GetWordAt(DirOff + 14);
 Entries := Named + Ids;
 Ind := '';
 For I := 1 To Level Do Ind := Ind + '  ';
 For I := 0 To Entries - 1 Do Begin
  EntryOff := DirOff + 16 + I * 8;
  DataVal := GetDWordAt(EntryOff + 4);
  Write(Ind, ResIdName(Base, EntryOff));
  If DataVal < 0 Then Begin
   Child := Base + (DataVal And $7FFFFFFF);
   WriteLn;
   DumpResourceDir(Base, Child, Level + 1);
  End Else Begin
   DataEntry := Base + DataVal;
   WriteLn(' RVA ', HexFixed(GetDWordAt(DataEntry),8),
    ' Size ', HexFixed(GetDWordAt(DataEntry + 4),8),
    ' CodePage ', GetDWordAt(DataEntry + 8));
  End;
 End;
End;

Procedure CmdResources;
Var Base: LongInt;
Begin
 If (Not IsPE) Or (Dirs[IMAGE_DIRECTORY_ENTRY_RESOURCE].RVA = 0) Then Exit;
 Base := RvaToOff(Dirs[IMAGE_DIRECTORY_ENTRY_RESOURCE].RVA);
 If Base < 0 Then Exit;
 WriteLn;
 WriteLn('RESOURCE DIRECTORY');
 DumpResourceDir(Base, Base, 1);
End;

Procedure CmdSecurityDirectory;
Var Off, EndOff, CertLen, Revision, CertType: LongInt;
Begin
 If (Not IsPE) Or (Dirs[IMAGE_DIRECTORY_ENTRY_SECURITY].RVA = 0) Then Exit;
 { SECURITY directory RVA is a file offset, not an RVA. }
 Off := Dirs[IMAGE_DIRECTORY_ENTRY_SECURITY].RVA;
 EndOff := Off + Dirs[IMAGE_DIRECTORY_ENTRY_SECURITY].Size;
 If (Off < 0) Or (Off + 8 > BufSize) Then Exit;
 WriteLn;
 WriteLn('SECURITY / CERTIFICATES');
 While Off + 8 <= EndOff Do Begin
  CertLen := GetDWordAt(Off);
  Revision := GetWordAt(Off + 4);
  CertType := GetWordAt(Off + 6);
  If CertLen < 8 Then Break;
  WriteLn('  Certificate at ', HexFixed(Off,8),
   ' size ', CertLen, ' revision ', HexFixed(Revision,4),
   ' type ', CertType);
  Off := Off + ((CertLen + 7) And Not 7);
 End;
End;

Function PdbDirByte(Idx: LongInt): Byte;
Var PageIndex, PageNumber, MapOff, FileOff: LongInt;
Begin
 PdbDirByte := 0;
 If (Idx < 0) Or (Idx >= PdbDirSize) Then Exit;
 PageIndex := Idx Div PdbPageSize;
 MapOff := PdbBlockMapPage * PdbPageSize + PageIndex * 4;
 If (MapOff < 0) Or (MapOff + 4 > BufSize) Then Exit;
 PageNumber := GetDWordAt(MapOff);
 FileOff := PageNumber * PdbPageSize + (Idx Mod PdbPageSize);
 If (FileOff >= 0) And (FileOff < BufSize) Then PdbDirByte := GetByteAt(FileOff);
End;

Function PdbDirDWord(Idx: LongInt): LongInt;
Var L: LongInt;
Begin
 L := PdbDirByte(Idx + 3);
 L := (L Shl 8) Or PdbDirByte(Idx + 2);
 L := (L Shl 8) Or PdbDirByte(Idx + 1);
 L := (L Shl 8) Or PdbDirByte(Idx);
 PdbDirDWord := L;
End;

Function PdbStreamCount: LongInt;
Begin
 PdbStreamCount := PdbDirDWord(0);
End;

Function PdbStreamSize(Stream: LongInt): LongInt;
Begin
 If (Stream < 0) Or (Stream >= PdbStreamCount) Or
    (Stream >= MaxPdbStreams) Then PdbStreamSize := -1
 Else PdbStreamSize := PdbDirDWord(4 + Stream * 4);
End;

Function PdbStreamPage(Stream, PageIndex: LongInt): LongInt;
Var I, Off, Size, Pages: LongInt;
Begin
 PdbStreamPage := -1;
 If (Stream < 0) Or (Stream >= PdbStreamCount) Or
    (Stream >= MaxPdbStreams) Then Exit;
 Off := 4 + PdbStreamCount * 4;
 For I := 0 To Stream - 1 Do Begin
  Size := PdbStreamSize(I);
  If Size < 0 Then Pages := 0
  Else Pages := (Size + PdbPageSize - 1) Div PdbPageSize;
  Inc(Off, Pages * 4);
 End;
 PdbStreamPage := PdbDirDWord(Off + PageIndex * 4);
End;

Function PdbStreamByte(Stream, Off: LongInt): Byte;
Var Size, PageIndex, PageNo, FileOff: LongInt;
Begin
 PdbStreamByte := 0;
 Size := PdbStreamSize(Stream);
 If (Off < 0) Or (Size < 0) Or (Off >= Size) Then Exit;
 PageIndex := Off Div PdbPageSize;
 PageNo := PdbStreamPage(Stream, PageIndex);
 If PageNo < 0 Then Exit;
 FileOff := PageNo * PdbPageSize + (Off Mod PdbPageSize);
 If (FileOff >= 0) And (FileOff < BufSize) Then
  PdbStreamByte := GetByteAt(FileOff);
End;

Function PdbStreamWord(Stream, Off: LongInt): Word;
Begin
 PdbStreamWord := PdbStreamByte(Stream, Off) Or
  (PdbStreamByte(Stream, Off + 1) Shl 8);
End;

Function PdbStreamDWord(Stream, Off: LongInt): LongInt;
Var L: LongInt;
Begin
 L := PdbStreamByte(Stream, Off + 3);
 L := (L Shl 8) Or PdbStreamByte(Stream, Off + 2);
 L := (L Shl 8) Or PdbStreamByte(Stream, Off + 1);
 L := (L Shl 8) Or PdbStreamByte(Stream, Off);
 PdbStreamDWord := L;
End;

Function PdbStreamCStr(Stream, Off: LongInt; MaxLen: Integer): String;
Var S: String; C: Byte; Size: LongInt;
Begin
 S := '';
 Size := PdbStreamSize(Stream);
 While (Off < Size) And (Length(S) < MaxLen) Do Begin
  C := PdbStreamByte(Stream, Off);
  If C = 0 Then Break;
  If C >= 32 Then S := S + Chr(C) Else S := S + '.';
  Inc(Off);
 End;
 PdbStreamCStr := S;
End;

Function PdbStreamGuid(Stream, Off: LongInt): String;
Begin
 PdbStreamGuid :=
  HexByte(PdbStreamByte(Stream, Off + 3)) + HexByte(PdbStreamByte(Stream, Off + 2)) +
  HexByte(PdbStreamByte(Stream, Off + 1)) + HexByte(PdbStreamByte(Stream, Off + 0)) + '-' +
  HexByte(PdbStreamByte(Stream, Off + 5)) + HexByte(PdbStreamByte(Stream, Off + 4)) + '-' +
  HexByte(PdbStreamByte(Stream, Off + 7)) + HexByte(PdbStreamByte(Stream, Off + 6)) + '-' +
  HexByte(PdbStreamByte(Stream, Off + 8)) + HexByte(PdbStreamByte(Stream, Off + 9)) + '-' +
  HexByte(PdbStreamByte(Stream, Off + 10)) + HexByte(PdbStreamByte(Stream, Off + 11)) +
  HexByte(PdbStreamByte(Stream, Off + 12)) + HexByte(PdbStreamByte(Stream, Off + 13)) +
  HexByte(PdbStreamByte(Stream, Off + 14)) + HexByte(PdbStreamByte(Stream, Off + 15));
End;

Function PdbSymKindName(K: Word): String;
Begin
 Case K Of
  $110C: PdbSymKindName := 'LDATA32';
  $110D: PdbSymKindName := 'GDATA32';
  $110E: PdbSymKindName := 'PUB32';
  $110F: PdbSymKindName := 'LPROC32_ID';
  $1110: PdbSymKindName := 'GPROC32';
  $1111: PdbSymKindName := 'LPROC32';
  $1125: PdbSymKindName := 'PROCREF';
  $1127: PdbSymKindName := 'LPROCREF';
  $113E: PdbSymKindName := 'ANNOTATIONREF';
  $1147: PdbSymKindName := 'GPROC32_ID';
  $114C: PdbSymKindName := 'BUILDINFO';
  $115D: PdbSymKindName := 'OBJNAME';
  $115E: PdbSymKindName := 'COMPILE3';
  $1160: PdbSymKindName := 'ENVBLOCK';
  $1169: PdbSymKindName := 'INLINESITE';
  $116C: PdbSymKindName := 'FILESTATIC';
 Else PdbSymKindName := 'S_' + HexFixed(K,4);
 End;
End;

Function PdbTypeKindName(K: Word): String;
Begin
 Case K Of
  $1001: PdbTypeKindName := 'LF_MODIFIER';
  $1002: PdbTypeKindName := 'LF_POINTER';
  $1003: PdbTypeKindName := 'LF_ARRAY';
  $1004: PdbTypeKindName := 'LF_CLASS';
  $1005: PdbTypeKindName := 'LF_STRUCTURE';
  $1006: PdbTypeKindName := 'LF_UNION';
  $1007: PdbTypeKindName := 'LF_ENUM';
  $1008: PdbTypeKindName := 'LF_PROCEDURE';
  $1009: PdbTypeKindName := 'LF_MFUNCTION';
  $1201: PdbTypeKindName := 'LF_FIELDLIST';
  $1502: PdbTypeKindName := 'LF_ENUMERATE';
  $1503: PdbTypeKindName := 'LF_ARRAY_ST';
  $1504: PdbTypeKindName := 'LF_CLASS_ST';
  $1505: PdbTypeKindName := 'LF_STRUCTURE_ST';
  $1506: PdbTypeKindName := 'LF_UNION_ST';
  $1507: PdbTypeKindName := 'LF_ENUM_ST';
  $150D: PdbTypeKindName := 'LF_FUNC_ID';
  $150E: PdbTypeKindName := 'LF_MFUNC_ID';
  $150F: PdbTypeKindName := 'LF_BUILDINFO';
  $1511: PdbTypeKindName := 'LF_STRING_ID';
  $1512: PdbTypeKindName := 'LF_UDT_SRC_LINE';
  $1513: PdbTypeKindName := 'LF_UDT_MOD_SRC_LINE';
  $1515: PdbTypeKindName := 'LF_FUNC_ID_16T';
  $1516: PdbTypeKindName := 'LF_MFUNC_ID_16T';
  $1519: PdbTypeKindName := 'LF_SUBSTR_LIST';
  $151A: PdbTypeKindName := 'LF_STRING_ID_16T';
  $151B: PdbTypeKindName := 'LF_UDT_SRC_LINE_16T';
  $151C: PdbTypeKindName := 'LF_UDT_MOD_SRC_LINE_16T';
 Else PdbTypeKindName := 'LF_' + HexFixed(K,4);
 End;
End;

Function PdbTypeTailName(Stream: Integer; Off, RecLen: LongInt): String;
Var P, EndP, Start: LongInt; S: String; C: Byte;
Begin
 PdbTypeTailName := '';
 EndP := Off + RecLen + 2;
 P := EndP - 1;
 While (P > Off + 4) And (PdbStreamByte(Stream, P) = 0) Do Dec(P);
 Start := P;
 While (Start > Off + 4) Do Begin
  C := PdbStreamByte(Stream, Start - 1);
  If (C < 32) Or (C >= 127) Then Break;
  Dec(Start);
 End;
 S := '';
 While Start <= P Do Begin
  C := PdbStreamByte(Stream, Start);
  If (C >= 32) And (C < 127) Then S := S + Chr(C);
  Inc(Start);
 End;
 If Length(S) > 0 Then PdbTypeTailName := S;
End;

Procedure DumpPdbTypeStream(Stream: Integer; Title: String; MaxRecs: LongInt);
Var Off, Size, RecLen, Count, TypeIndex: LongInt; Kind: Word; TN: String;
Begin
 Size := PdbStreamSize(Stream);
 If Size < 24 Then Exit;
 WriteLn;
 WriteLn(Title, ' TYPES (stream ', Stream, ')');
 WriteLn('  Version         ', HexFixed(PdbStreamDWord(Stream,0),8));
 WriteLn('  Header size     ', PdbStreamDWord(Stream,4));
 WriteLn('  Type index begin ', HexFixed(PdbStreamDWord(Stream,8),8));
 WriteLn('  Type index end   ', HexFixed(PdbStreamDWord(Stream,12),8));
 WriteLn('  Record bytes     ', HexFixed(PdbStreamDWord(Stream,16),8));
 Off := PdbStreamDWord(Stream,4);
 If Off <= 0 Then Off := 56;
 TypeIndex := PdbStreamDWord(Stream,8);
 Count := 0;
 While (Off + 4 <= Size) And ((MaxRecs <= 0) Or (Count < MaxRecs)) Do Begin
  RecLen := PdbStreamWord(Stream, Off);
  If (RecLen < 2) Or (Off + RecLen + 2 > Size) Then Break;
  Kind := PdbStreamWord(Stream, Off + 2);
  TN := '';
  If (Kind = $1004) Or (Kind = $1005) Or (Kind = $1006) Or (Kind = $1007) Or
     (Kind = $1504) Or (Kind = $1505) Or (Kind = $1506) Or (Kind = $1507) Then
   TN := PdbTypeTailName(Stream, Off, RecLen);
  Write('    ', HexFixed(TypeIndex,8), ' ',
   PadRight(PdbTypeKindName(Kind), 22), ' len ', RecLen);
  If TN <> '' Then Write(' name ', TN);
  WriteLn;
  Inc(Off, RecLen + 2);
  Inc(TypeIndex);
  Inc(Count);
 End;
End;

Procedure DumpPdbModules;
Var Off, EndOff, Stream, SymBytes, OldLineBytes, C13Bytes: LongInt;
    FileCount, ModIdx: Integer; ModName, ObjName: String; NameOff: LongInt;
Begin
 If PdbStreamSize(3) < 64 Then Exit;
 Off := 64;
 EndOff := Off + PdbStreamDWord(3,24);
 If EndOff > PdbStreamSize(3) Then EndOff := PdbStreamSize(3);
 WriteLn;
 WriteLn('DBI MODULES');
 ModIdx := 0;
 While Off + 64 <= EndOff Do Begin
  Stream := PdbStreamWord(3, Off + 34);
  SymBytes := PdbStreamDWord(3, Off + 36);
  OldLineBytes := PdbStreamDWord(3, Off + 40);
  C13Bytes := PdbStreamDWord(3, Off + 44);
  FileCount := PdbStreamWord(3, Off + 48);
  NameOff := Off + 64;
  ModName := PdbStreamCStr(3, NameOff, 120);
  Inc(NameOff, Length(ModName) + 1);
  ObjName := PdbStreamCStr(3, NameOff, 120);
  WriteLn('  [', ModIdx, '] stream ', Stream,
   ' sym ', SymBytes, ' c13 ', C13Bytes, ' oldline ', OldLineBytes,
   ' files ', FileCount);
  WriteLn('      module ', ModName);
  If ObjName <> '' Then WriteLn('      object ', ObjName);
  Inc(NameOff, Length(ObjName) + 1);
  While (NameOff Mod 4) <> 0 Do Inc(NameOff);
  Off := NameOff;
  Inc(ModIdx);
 End;
End;

Procedure DumpPdbLines;
Var ModOff, ModEnd, Stream, SymBytes, C13Bytes, StreamOff, SubKind, SubLen: LongInt;
    LinesStart, LinesEnd, Seg, ConOff, FileBlock, NLines, I, LineRec: LongInt;
    ModName: String; NameOff: LongInt;
Begin
 If PdbStreamSize(3) < 64 Then Exit;
 ModOff := 64;
 ModEnd := ModOff + PdbStreamDWord(3,24);
 If ModEnd > PdbStreamSize(3) Then ModEnd := PdbStreamSize(3);
 WriteLn;
 WriteLn('PDB LINE NUMBERS (C13)');
 While ModOff + 64 <= ModEnd Do Begin
  Stream := PdbStreamWord(3, ModOff + 34);
  SymBytes := PdbStreamDWord(3, ModOff + 36);
  C13Bytes := PdbStreamDWord(3, ModOff + 44);
  NameOff := ModOff + 64;
  ModName := PdbStreamCStr(3, NameOff, 80);
  If (Stream > 0) And (C13Bytes > 0) Then Begin
   StreamOff := SymBytes;
   LinesEnd := StreamOff + C13Bytes;
   While StreamOff + 8 <= LinesEnd Do Begin
    SubKind := PdbStreamDWord(Stream, StreamOff);
    SubLen := PdbStreamDWord(Stream, StreamOff + 4);
    If SubLen <= 0 Then Break;
    If SubKind = $F2 Then Begin { DEBUG_S_LINES }
     LinesStart := StreamOff + 8;
     ConOff := PdbStreamDWord(Stream, LinesStart);
     Seg := PdbStreamWord(Stream, LinesStart + 4);
     WriteLn('  ', ModName, ' seg ', Seg, ' base ', HexFixed(ConOff,8));
     FileBlock := LinesStart + 12;
     While FileBlock + 12 <= LinesStart + SubLen Do Begin
      NLines := PdbStreamDWord(Stream, FileBlock + 4);
      LineRec := FileBlock + 12;
      For I := 0 To NLines - 1 Do Begin
       If LineRec + 8 > LinesStart + SubLen Then Break;
       WriteLn('    ', HexFixed(ConOff + PdbStreamDWord(Stream, LineRec),8),
        ' line ', PdbStreamDWord(Stream, LineRec + 4) And $00FFFFFF);
       Inc(LineRec, 8);
      End;
      FileBlock := FileBlock + PdbStreamDWord(Stream, FileBlock + 8);
      If PdbStreamDWord(Stream, FileBlock - PdbStreamDWord(Stream, FileBlock - 4)) = 0 Then Break;
      If FileBlock <= LineRec Then Break;
     End;
    End;
    StreamOff := StreamOff + 8 + SubLen;
    While (StreamOff Mod 4) <> 0 Do Inc(StreamOff);
   End;
  End;
  NameOff := ModOff + 64;
  Inc(NameOff, Length(PdbStreamCStr(3, NameOff, 120)) + 1);
  Inc(NameOff, Length(PdbStreamCStr(3, NameOff, 120)) + 1);
  While (NameOff Mod 4) <> 0 Do Inc(NameOff);
  ModOff := NameOff;
 End;
End;

Function PdbDbiPublicStream: Integer;
Begin
 If PdbStreamSize(3) >= 24 Then PdbDbiPublicStream := PdbStreamWord(3, 16)
 Else PdbDbiPublicStream := -1;
End;

Function PdbDbiGlobalStream: Integer;
Begin
 If PdbStreamSize(3) >= 16 Then PdbDbiGlobalStream := PdbStreamWord(3, 12)
 Else PdbDbiGlobalStream := -1;
End;

Function PdbDbiSymRecordStream: Integer;
Begin
 If PdbStreamSize(3) >= 24 Then PdbDbiSymRecordStream := PdbStreamWord(3, 20)
 Else PdbDbiSymRecordStream := -1;
End;

Procedure DecodePdbSymbol(Stream, RecOff: LongInt);
Var Len, Kind, Seg: Word; Offs, Flags, Typ, ProcLen: LongInt; Name: String;
Begin
 Len := PdbStreamWord(Stream, RecOff);
 If Len < 2 Then Exit;
 Kind := PdbStreamWord(Stream, RecOff + 2);
 Case Kind Of
  $110E: Begin { S_PUB32 }
   Flags := PdbStreamDWord(Stream, RecOff + 4);
   Offs := PdbStreamDWord(Stream, RecOff + 8);
   Seg := PdbStreamWord(Stream, RecOff + 12);
   Name := PdbStreamCStr(Stream, RecOff + 14, 120);
   WriteLn('  ', PadRight(PdbSymKindName(Kind), 10), ' ',
    HexFixed(Seg,4), ':', HexFixed(Offs,8), ' flags ',
    HexFixed(Flags,8), ' ', Name);
  End;
  $110C, $110D: Begin { S_LDATA32 / S_GDATA32 }
   Typ := PdbStreamDWord(Stream, RecOff + 4);
   Offs := PdbStreamDWord(Stream, RecOff + 8);
   Seg := PdbStreamWord(Stream, RecOff + 12);
   Name := PdbStreamCStr(Stream, RecOff + 14, 120);
   WriteLn('  ', PadRight(PdbSymKindName(Kind), 10), ' ',
    HexFixed(Seg,4), ':', HexFixed(Offs,8), ' type ',
    HexFixed(Typ,8), ' ', Name);
  End;
  $1110, $1111, $110F, $1147: Begin { PROC32 variants }
   ProcLen := PdbStreamDWord(Stream, RecOff + 16);
   Typ := PdbStreamDWord(Stream, RecOff + 28);
   Offs := PdbStreamDWord(Stream, RecOff + 32);
   Seg := PdbStreamWord(Stream, RecOff + 36);
   Name := PdbStreamCStr(Stream, RecOff + 39, 120);
   WriteLn('  ', PadRight(PdbSymKindName(Kind), 10), ' ',
    HexFixed(Seg,4), ':', HexFixed(Offs,8), ' len ',
    HexFixed(ProcLen,8), ' type ', HexFixed(Typ,8), ' ', Name);
  End;
  $1125, $1127: Begin { PROCREF/LPROCREF }
   Offs := PdbStreamDWord(Stream, RecOff + 8);
   Seg := PdbStreamWord(Stream, RecOff + 12);
   Name := PdbStreamCStr(Stream, RecOff + 14, 120);
   WriteLn('  ', PadRight(PdbSymKindName(Kind), 10), ' module ',
    Seg, ' symoff ', HexFixed(Offs,8), ' ', Name);
  End;
  $115D: Begin { OBJNAME }
   Name := PdbStreamCStr(Stream, RecOff + 8, 120);
   WriteLn('  ', PadRight(PdbSymKindName(Kind), 10), ' ', Name);
  End;
 Else
  If Len <= 256 Then
   WriteLn('  ', PadRight(PdbSymKindName(Kind), 10), ' len ', Len);
 End;
End;

Procedure DumpPdbSymbolStream(Stream: Integer; Title: String; MaxRecs: LongInt);
Var Off, Size, Len, Count: LongInt;
Begin
 If (Stream < 0) Or (PdbStreamSize(Stream) <= 0) Then Exit;
 WriteLn;
 WriteLn(Title, ' (stream ', Stream, ')');
 Off := 0;
 Size := PdbStreamSize(Stream);
 Count := 0;
 While (Off + 4 <= Size) And ((MaxRecs <= 0) Or (Count < MaxRecs)) Do Begin
  Len := PdbStreamWord(Stream, Off);
  If (Len < 2) Or (Off + Len + 2 > Size) Then Break;
  DecodePdbSymbol(Stream, Off);
  Inc(Off, Len + 2);
  Inc(Count);
 End;
 If (MaxRecs > 0) And (Off + 4 <= Size) Then
  WriteLn('  ... sortie limitee a ', MaxRecs, ' enregistrements.');
End;

Procedure CmdSymbols; Forward;

Procedure CmdPDBSymbols;
Var GS, PS, SS: Integer;
Begin
 If Not IsPDB Then Begin
  CmdSymbols;
  Exit;
 End;
 GS := PdbDbiGlobalStream;
 PS := PdbDbiPublicStream;
 SS := PdbDbiSymRecordStream;
 If PdbStreamSize(3) <= 0 Then Begin
  WriteLn('Aucun stream DBI PDB.');
  Exit;
 End;
 WriteLn('PDB SYMBOLS');
 WriteLn('  Global stream       : ', GS);
 WriteLn('  Public stream       : ', PS);
 WriteLn('  Symbol record stream: ', SS);
 DumpPdbSymbolStream(GS, 'Global symbols', 0);
 DumpPdbSymbolStream(PS, 'Public symbols', 0);
 DumpPdbSymbolStream(SS, 'Symbol records', 0);
End;

Procedure CmdPDBHeaders;
Var StreamCount, I, Size, Pages, PageListOff: LongInt;
    GS, PS, SS: Integer;
Begin
 WriteLn('PDB FILE HEADER VALUES');
 WriteLn('        Microsoft C/C++ MSF 7.00');
 WriteLn('        ', HexFixed(PdbPageSize,8), ' page size');
 WriteLn('        ', HexFixed(PdbNumPages,8), ' number of pages');
 WriteLn('        ', HexFixed(PdbDirSize,8), ' directory size');
 WriteLn('        ', HexFixed(PdbBlockMapPage,8), ' block map page');
 StreamCount := PdbDirDWord(0);
 If (StreamCount < 0) Or (StreamCount > 4096) Then Begin
  WriteLn('        Repertoire PDB invalide.');
  Exit;
 End;
 WriteLn;
 WriteLn('PDB STREAMS');
 WriteLn('Idx Size      Pages');
 PageListOff := 4 + StreamCount * 4;
 For I := 0 To StreamCount - 1 Do Begin
  Size := PdbDirDWord(4 + I * 4);
  If Size < 0 Then Pages := 0
  Else Pages := (Size + PdbPageSize - 1) Div PdbPageSize;
  WriteLn(PadLeft(LToS(I), 3), ' ',
   PadLeft(HexFixed(Size,8), 9), ' ', Pages);
  Inc(PageListOff, Pages * 4);
 End;
 If PdbStreamSize(1) >= 28 Then Begin
  WriteLn;
  WriteLn('PDB INFO STREAM');
  WriteLn('        ', HexFixed(PdbStreamDWord(1,0),8), ' version');
  WriteLn('        ', HexFixed(PdbStreamDWord(1,4),8), ' signature');
  WriteLn('        ', PdbStreamDWord(1,8), ' age');
  WriteLn('        ', PdbStreamGuid(1,12), ' guid');
 End;
 If PdbStreamSize(2) >= 24 Then Begin
  WriteLn;
  WriteLn('TPI STREAM');
  WriteLn('        ', HexFixed(PdbStreamDWord(2,0),8), ' version');
  WriteLn('        ', HexFixed(PdbStreamDWord(2,8),8), ' type index begin');
  WriteLn('        ', HexFixed(PdbStreamDWord(2,12),8), ' type index end');
  WriteLn('        ', HexFixed(PdbStreamDWord(2,16),8), ' type record bytes');
 End;
 DumpPdbTypeStream(2, 'TPI', 32);
 If (PdbStreamSize(4) >= 24) And
    ((PdbStreamDWord(4,0) = 20040203) Or
     (PdbStreamDWord(4,0) = 20091201) Or
     (PdbStreamDWord(4,0) = 20040203)) Then
  DumpPdbTypeStream(4, 'IPI', 32);
 If PdbStreamSize(3) >= 64 Then Begin
  GS := PdbDbiGlobalStream;
  PS := PdbDbiPublicStream;
  SS := PdbDbiSymRecordStream;
  WriteLn;
  WriteLn('DBI STREAM');
  WriteLn('        ', HexFixed(PdbStreamDWord(3,4),8), ' version');
  WriteLn('        ', PdbStreamDWord(3,8), ' age');
  WriteLn('        ', GS, ' global symbol stream');
  WriteLn('        ', PS, ' public symbol stream');
  WriteLn('        ', SS, ' symbol record stream');
  WriteLn('        ', HexFixed(PdbStreamDWord(3,24),8), ' module info size');
  WriteLn('        ', HexFixed(PdbStreamDWord(3,48),8), ' optional debug header size');
  WriteLn('        ', HexFixed(PdbStreamWord(3,58),4), ' machine');
 End;
 DumpPdbModules;
End;

Procedure CmdHeaders;
Var I: Integer;
Begin
 If IsPDB Then Begin
  CmdPDBHeaders;
  Exit;
 End;
 If IsArchive Then Begin
  WriteLn('Archive COFF: ', FileName);
  Exit;
 End;
 WriteLn('FILE HEADER VALUES');
 WriteLn('             ', HexFixed(Machine,4), ' machine (', MachineName(Machine), ')');
 If IsBigObj Then WriteLn('             bigobj COFF object');
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
    WriteLn(PadLeft(LToS(I), 3), '  ',
     PadRight(DirectoryName(I), 13), ' RVA ', HexFixed(Dirs[I].RVA,8),
     '  Size ', HexFixed(Dirs[I].Size,8));
  CmdDebugDirectory;
  CmdRichHeader;
  CmdResources;
  CmdSecurityDirectory;
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

Function Reg32I(R: Byte): String;
Const Names: Array[0..7] Of String[3] =
 ('eax','ecx','edx','ebx','esp','ebp','esi','edi');
Begin
 Reg32I := Names[R And 7];
End;

Function Reg8I(R: Byte): String;
Const Names: Array[0..7] Of String[3] =
 ('al','cl','dl','bl','ah','ch','dh','bh');
Begin
 Reg8I := Names[R And 7];
End;

Function Grp1Name(N: Byte): String;
Begin
 Case N And 7 Of
  0: Grp1Name := 'add';
  1: Grp1Name := 'or';
  2: Grp1Name := 'adc';
  3: Grp1Name := 'sbb';
  4: Grp1Name := 'and';
  5: Grp1Name := 'sub';
  6: Grp1Name := 'xor';
 Else Grp1Name := 'cmp';
 End;
End;

Function JccName(N: Byte): String;
Begin
 Case N And 15 Of
  0: JccName := 'jo';
  1: JccName := 'jno';
  2: JccName := 'jb';
  3: JccName := 'jae';
  4: JccName := 'je';
  5: JccName := 'jne';
  6: JccName := 'jbe';
  7: JccName := 'ja';
  8: JccName := 'js';
  9: JccName := 'jns';
 10: JccName := 'jp';
 11: JccName := 'jnp';
 12: JccName := 'jl';
 13: JccName := 'jge';
 14: JccName := 'jle';
 Else JccName := 'jg';
 End;
End;

Function SignedByte(B: Byte): LongInt;
Begin
 If B < 128 Then SignedByte := B Else SignedByte := LongInt(B) - 256;
End;

Function IntelHex(V: LongInt): String;
Begin
 IntelHex := HexFixed(V, 8) + 'h';
End;

Function ImmText(V: LongInt; Digits: Integer): String;
Begin
 If Digits <= 2 Then ImmText := HexFixed(V And $FF, 2) + 'h'
 Else ImmText := HexFixed(V, Digits) + 'h';
End;

Function DispText(D: LongInt): String;
Begin
 If D = 0 Then DispText := ''
 Else If D > 0 Then DispText := '+' + HexFixed(D, 8) + 'h'
 Else DispText := '-' + HexFixed(-D, 8) + 'h';
End;

Function GetDWordBEAt(P: LongInt): LongInt;
Begin
 GetDWordBEAt := (LongInt(GetByteAt(P)) Shl 24) Or
  (LongInt(GetByteAt(P + 1)) Shl 16) Or
  (LongInt(GetByteAt(P + 2)) Shl 8) Or
  LongInt(GetByteAt(P + 3));
End;

Function SignExtend(V, Bits: LongInt): LongInt;
Var Mask: LongInt;
Begin
 Mask := 1 Shl (Bits - 1);
 If (V And Mask) <> 0 Then SignExtend := V Or (-1 Shl Bits)
 Else SignExtend := V;
End;

Function DecodeModRMIntel(Off: LongInt; Var Consumed: Integer;
 Var RegField: Byte; Wide: Boolean): String;
Var M, ModBits, RM, Scale, Idx, BaseR: Byte;
    P, Disp: LongInt;
    S, Inner, BaseText, IdxText: String;
Begin
 M := GetByteAt(Off);
 ModBits := M Shr 6;
 RegField := (M Shr 3) And 7;
 RM := M And 7;
 P := Off + 1;
 Consumed := 1;

 If ModBits = 3 Then Begin
  If Wide Then DecodeModRMIntel := Reg32I(RM)
  Else DecodeModRMIntel := Reg8I(RM);
  Exit;
 End;

 Disp := 0;
 Inner := '';
 If RM = 4 Then Begin
  M := GetByteAt(P); Inc(P); Inc(Consumed);
  Scale := M Shr 6;
  Idx := (M Shr 3) And 7;
  BaseR := M And 7;
  If (ModBits = 0) And (BaseR = 5) Then Begin
   Disp := GetDWordAt(P); Inc(P, 4); Inc(Consumed, 4);
   BaseText := '';
  End Else
   BaseText := Reg32I(BaseR);
  If Idx = 4 Then IdxText := ''
  Else Begin
   IdxText := Reg32I(Idx);
   If Scale <> 0 Then IdxText := IdxText + '*' + LToS(1 Shl Scale);
  End;
  Inner := BaseText;
  If IdxText <> '' Then Begin
   If Inner <> '' Then Inner := Inner + '+';
   Inner := Inner + IdxText;
  End;
 End Else If (ModBits = 0) And (RM = 5) Then Begin
  Disp := GetDWordAt(P); Inc(P, 4); Inc(Consumed, 4);
  DecodeModRMIntel := 'dword ptr [' + IntelHex(Disp) + ']';
  Exit;
 End Else
  Inner := Reg32I(RM);

 If ModBits = 1 Then Begin
  Disp := SignedByte(GetByteAt(P)); Inc(P); Inc(Consumed);
 End Else If ModBits = 2 Then Begin
  Disp := GetDWordAt(P); Inc(P, 4); Inc(Consumed, 4);
 End;

 S := '[' + Inner + DispText(Disp) + ']';
 If Wide Then DecodeModRMIntel := 'dword ptr ' + S
 Else DecodeModRMIntel := 'byte ptr ' + S;
End;

Function DecodeX86(Off, VAddr: LongInt; Var Len: Integer): String;
Var B, Op2, RegF: Byte; D, Target, Imm: LongInt;
    Used: Integer; RM, R: String;
Begin
 B := GetByteAt(Off); Len := 1;
 Case B Of
  $00: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, False); Len := 1 + Used; DecodeX86 := 'add         ' + RM + ',' + Reg8I(RegF); End;
  $02: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, False); Len := 1 + Used; DecodeX86 := 'add         ' + Reg8I(RegF) + ',' + RM; End;
  $05: Begin Len := 5; DecodeX86 := 'add         eax,' + ImmText(GetDWordAt(Off+1),8); End;
  $09: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used; DecodeX86 := 'or          ' + RM + ',' + Reg32I(RegF); End;
  $0B: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used; DecodeX86 := 'or          ' + Reg32I(RegF) + ',' + RM; End;
  $0D: Begin Len := 5; DecodeX86 := 'or          eax,' + ImmText(GetDWordAt(Off+1),8); End;
  $21: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used; DecodeX86 := 'and         ' + RM + ',' + Reg32I(RegF); End;
  $23: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used; DecodeX86 := 'and         ' + Reg32I(RegF) + ',' + RM; End;
  $25: Begin Len := 5; DecodeX86 := 'and         eax,' + ImmText(GetDWordAt(Off+1),8); End;
  $2D: Begin Len := 5; DecodeX86 := 'sub         eax,' + ImmText(GetDWordAt(Off+1),8); End;
  $35: Begin Len := 5; DecodeX86 := 'xor         eax,' + ImmText(GetDWordAt(Off+1),8); End;
  $3D: Begin Len := 5; DecodeX86 := 'cmp         eax,' + ImmText(GetDWordAt(Off+1),8); End;
  $50..$57: DecodeX86 := 'push        ' + Reg32I(B - $50);
  $58..$5F: DecodeX86 := 'pop         ' + Reg32I(B - $58);
  $40..$47: DecodeX86 := 'inc         ' + Reg32I(B - $40);
  $48..$4F: DecodeX86 := 'dec         ' + Reg32I(B - $48);
  $90: DecodeX86 := 'nop';
  $C3: DecodeX86 := 'ret';
  $C2: Begin Len := 3; DecodeX86 := 'ret         ' + ImmText(GetWordAt(Off+1),4); End;
  $CC: DecodeX86 := 'int         3';
  $68: Begin Len := 5; DecodeX86 := 'push        ' + ImmText(GetDWordAt(Off+1),8); End;
  $6A: Begin Len := 2; DecodeX86 := 'push        ' + ImmText(GetByteAt(Off+1),2); End;
  $84: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, False); Len := 1 + Used; DecodeX86 := 'test        ' + RM + ',' + Reg8I(RegF); End;
  $B8..$BF: Begin Len := 5; DecodeX86 := 'mov         ' + Reg32I(B - $B8) + ',' + ImmText(GetDWordAt(Off+1),8); End;
  $B0..$B7: Begin Len := 2; DecodeX86 := 'mov         ' + Reg8I(B - $B0) + ',' + ImmText(GetByteAt(Off+1),2); End;
  $A1: Begin Len := 5; DecodeX86 := 'mov         eax,dword ptr [' + IntelHex(GetDWordAt(Off+1)) + ']'; End;
  $A3: Begin Len := 5; DecodeX86 := 'mov         dword ptr [' + IntelHex(GetDWordAt(Off+1)) + '],eax'; End;
  $E0: Begin Len := 2; Target := VAddr + 2 + SignedByte(GetByteAt(Off+1)); DecodeX86 := 'loopne      ' + HexFixed(Target,8); End;
  $E1: Begin Len := 2; Target := VAddr + 2 + SignedByte(GetByteAt(Off+1)); DecodeX86 := 'loope       ' + HexFixed(Target,8); End;
  $E2: Begin Len := 2; Target := VAddr + 2 + SignedByte(GetByteAt(Off+1)); DecodeX86 := 'loop        ' + HexFixed(Target,8); End;
  $E3: Begin Len := 2; Target := VAddr + 2 + SignedByte(GetByteAt(Off+1)); DecodeX86 := 'jecxz       ' + HexFixed(Target,8); End;
  $E8: Begin Len := 5; D := GetDWordAt(Off+1); Target := VAddr + 5 + D; DecodeX86 := 'call        ' + HexFixed(Target,8); End;
  $E9: Begin Len := 5; D := GetDWordAt(Off+1); Target := VAddr + 5 + D; DecodeX86 := 'jmp         ' + HexFixed(Target,8); End;
  $EB: Begin Len := 2; Target := VAddr + 2 + SignedByte(GetByteAt(Off+1)); DecodeX86 := 'jmp         ' + HexFixed(Target,8); End;
  $70..$7F: Begin Len := 2; Target := VAddr + 2 + SignedByte(GetByteAt(Off+1)); DecodeX86 := PadRight(JccName(B And 15), 12) + HexFixed(Target,8); End;
  $88: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, False); Len := 1 + Used; DecodeX86 := 'mov         ' + RM + ',' + Reg8I(RegF); End;
  $8A: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, False); Len := 1 + Used; DecodeX86 := 'mov         ' + Reg8I(RegF) + ',' + RM; End;
  $89: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used; DecodeX86 := 'mov         ' + RM + ',' + Reg32I(RegF); End;
  $8B: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used; DecodeX86 := 'mov         ' + Reg32I(RegF) + ',' + RM; End;
  $8D: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used; DecodeX86 := 'lea         ' + Reg32I(RegF) + ',' + RM; End;
  $87: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used; DecodeX86 := 'xchg        ' + RM + ',' + Reg32I(RegF); End;
  $8F: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used; DecodeX86 := 'pop         ' + RM; End;
  $C6: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, False); Imm := GetByteAt(Off+1+Used); Len := 2 + Used; DecodeX86 := 'mov         ' + RM + ',' + ImmText(Imm,2); End;
  $C7: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, True); Imm := GetDWordAt(Off+1+Used); Len := 5 + Used; DecodeX86 := 'mov         ' + RM + ',' + ImmText(Imm,8); End;
  $C0,$C1: Begin
        RM := DecodeModRMIntel(Off+1, Used, RegF, B = $C1);
        Imm := GetByteAt(Off+1+Used); Len := 2 + Used;
        Case RegF And 7 Of
         0: R := 'rol'; 1: R := 'ror'; 2: R := 'rcl'; 3: R := 'rcr';
         4: R := 'shl'; 5: R := 'shr'; 7: R := 'sar';
        Else R := 'sh?';
        End;
        DecodeX86 := PadRight(R, 12) + RM + ',' + ImmText(Imm,2);
       End;
  $D1,$D3: Begin
        RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used;
        Case RegF And 7 Of
         0: R := 'rol'; 1: R := 'ror'; 2: R := 'rcl'; 3: R := 'rcr';
         4: R := 'shl'; 5: R := 'shr'; 7: R := 'sar';
        Else R := 'sh?';
        End;
        If B = $D1 Then DecodeX86 := PadRight(R, 12) + RM + ',1'
        Else DecodeX86 := PadRight(R, 12) + RM + ',cl';
       End;
  $01: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used; DecodeX86 := 'add         ' + RM + ',' + Reg32I(RegF); End;
  $03: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used; DecodeX86 := 'add         ' + Reg32I(RegF) + ',' + RM; End;
  $29: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used; DecodeX86 := 'sub         ' + RM + ',' + Reg32I(RegF); End;
  $2B: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used; DecodeX86 := 'sub         ' + Reg32I(RegF) + ',' + RM; End;
  $31: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used; DecodeX86 := 'xor         ' + RM + ',' + Reg32I(RegF); End;
  $33: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used; DecodeX86 := 'xor         ' + Reg32I(RegF) + ',' + RM; End;
  $39: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used; DecodeX86 := 'cmp         ' + RM + ',' + Reg32I(RegF); End;
  $3B: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used; DecodeX86 := 'cmp         ' + Reg32I(RegF) + ',' + RM; End;
  $83: Begin
        RM := DecodeModRMIntel(Off+1, Used, RegF, True);
        Imm := SignedByte(GetByteAt(Off+1+Used));
        Len := 2 + Used;
        DecodeX86 := PadRight(Grp1Name(RegF), 12) + RM + ',' + ImmText(Imm,2);
       End;
  $81: Begin
        RM := DecodeModRMIntel(Off+1, Used, RegF, True);
        Imm := GetDWordAt(Off+1+Used);
        Len := 5 + Used;
        DecodeX86 := PadRight(Grp1Name(RegF), 12) + RM + ',' + ImmText(Imm,8);
       End;
  $85: Begin RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used; DecodeX86 := 'test        ' + RM + ',' + Reg32I(RegF); End;
  $0F: Begin
        Op2 := GetByteAt(Off+1);
        If (Op2 >= $80) And (Op2 <= $8F) Then Begin
         D := GetDWordAt(Off+2); Len := 6; Target := VAddr + 6 + D;
         DecodeX86 := PadRight(JccName(Op2 And 15), 12) + HexFixed(Target,8);
        End Else If Op2 = $1F Then Begin
         RM := DecodeModRMIntel(Off+2, Used, RegF, True);
         Len := 2 + Used;
         DecodeX86 := 'nop         ' + RM;
        End Else If Op2 = $AF Then Begin
         RM := DecodeModRMIntel(Off+2, Used, RegF, True);
         Len := 2 + Used;
         DecodeX86 := 'imul        ' + Reg32I(RegF) + ',' + RM;
        End Else If (Op2 = $B6) Or (Op2 = $B7) Then Begin
         RM := DecodeModRMIntel(Off+2, Used, RegF, Op2 = $B7);
         Len := 2 + Used;
         DecodeX86 := 'movzx       ' + Reg32I(RegF) + ',' + RM;
        End Else If (Op2 = $BE) Or (Op2 = $BF) Then Begin
         RM := DecodeModRMIntel(Off+2, Used, RegF, Op2 = $BF);
         Len := 2 + Used;
         DecodeX86 := 'movsx       ' + Reg32I(RegF) + ',' + RM;
        End Else Begin
         Len := 2;
         DecodeX86 := 'db          0Fh,' + HexByte(Op2) + 'h';
        End;
       End;
  $F7: Begin
        RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used;
        Case RegF And 7 Of
         0: Begin Imm := GetDWordAt(Off+1+Used); Len := 5 + Used; DecodeX86 := 'test        ' + RM + ',' + ImmText(Imm,8); End;
         2: DecodeX86 := 'not         ' + RM;
         3: DecodeX86 := 'neg         ' + RM;
         4: DecodeX86 := 'mul         ' + RM;
         5: DecodeX86 := 'imul        ' + RM;
         6: DecodeX86 := 'div         ' + RM;
        Else DecodeX86 := 'idiv        ' + RM;
        End;
       End;
  $FF: Begin
        RM := DecodeModRMIntel(Off+1, Used, RegF, True); Len := 1 + Used;
        Case RegF And 7 Of
         0: R := 'inc';
         1: R := 'dec';
         2: R := 'call';
         4: R := 'jmp';
         6: R := 'push';
        Else R := 'grpff';
        End;
        DecodeX86 := PadRight(R, 12) + RM;
       End;
 Else DecodeX86 := 'db ' + HexByte(B);
 End;
End;

Function Reg64I(R: Byte): String;
Const Names: Array[0..15] Of String[4] =
 ('rax','rcx','rdx','rbx','rsp','rbp','rsi','rdi',
  'r8','r9','r10','r11','r12','r13','r14','r15');
Begin
 Reg64I := Names[R And 15];
End;

Function Reg32IX(R: Byte): String;
Const Names: Array[0..15] Of String[4] =
 ('eax','ecx','edx','ebx','esp','ebp','esi','edi',
  'r8d','r9d','r10d','r11d','r12d','r13d','r14d','r15d');
Begin
 Reg32IX := Names[R And 15];
End;

Function X64Reg(R: Byte; Wide64: Boolean): String;
Begin
 If Wide64 Then X64Reg := Reg64I(R) Else X64Reg := Reg32IX(R);
End;

Function DecodeModRM64Intel(Off, VAddr, InstLenGuess: LongInt;
 Var Consumed: Integer; Var RegField: Byte;
 Wide64, RexR, RexX, RexB: Boolean): String; Forward;

Function XmmReg(R: Byte): String;
Begin
 XmmReg := 'xmm' + LToS(R And 15);
End;

Function YmmReg(R: Byte): String;
Begin
 YmmReg := 'ymm' + LToS(R And 15);
End;

Function DecodeModRM64Xmm(Off, VAddr, InstLenGuess: LongInt;
 Var Consumed: Integer; Var RegField: Byte;
 RexR, RexX, RexB: Boolean; UseYmm: Boolean): String;
Var M, RM: Byte;
Begin
 M := GetByteAt(Off);
 RegField := (M Shr 3) And 7;
 If RexR Then RegField := RegField Or 8;
 RM := M And 7;
 If RexB Then RM := RM Or 8;
 If (M Shr 6) = 3 Then Begin
  Consumed := 1;
  If UseYmm Then DecodeModRM64Xmm := YmmReg(RM)
  Else DecodeModRM64Xmm := XmmReg(RM);
 End Else
  DecodeModRM64Xmm := DecodeModRM64Intel(Off, VAddr, InstLenGuess,
   Consumed, RegField, True, RexR, RexX, RexB);
End;

Function SseMnemonic(Prefix: Byte; Base: String): String;
Begin
 If Base = 'mov' Then Begin
  If Prefix = $66 Then SseMnemonic := 'movapd'
  Else If Prefix = $F3 Then SseMnemonic := 'movss'
  Else If Prefix = $F2 Then SseMnemonic := 'movsd'
  Else SseMnemonic := 'movaps';
 End Else If Base = 'movu' Then Begin
  If Prefix = $66 Then SseMnemonic := 'movupd'
  Else If Prefix = $F3 Then SseMnemonic := 'movss'
  Else If Prefix = $F2 Then SseMnemonic := 'movsd'
  Else SseMnemonic := 'movups';
 End Else If Base = 'add' Then Begin
  If Prefix = $66 Then SseMnemonic := 'addpd'
  Else If Prefix = $F3 Then SseMnemonic := 'addss'
  Else If Prefix = $F2 Then SseMnemonic := 'addsd'
  Else SseMnemonic := 'addps';
 End Else If Base = 'sub' Then Begin
  If Prefix = $66 Then SseMnemonic := 'subpd'
  Else If Prefix = $F3 Then SseMnemonic := 'subss'
  Else If Prefix = $F2 Then SseMnemonic := 'subsd'
  Else SseMnemonic := 'subps';
 End Else If Base = 'mul' Then Begin
  If Prefix = $66 Then SseMnemonic := 'mulpd'
  Else If Prefix = $F3 Then SseMnemonic := 'mulss'
  Else If Prefix = $F2 Then SseMnemonic := 'mulsd'
  Else SseMnemonic := 'mulps';
 End Else If Base = 'div' Then Begin
  If Prefix = $66 Then SseMnemonic := 'divpd'
  Else If Prefix = $F3 Then SseMnemonic := 'divss'
  Else If Prefix = $F2 Then SseMnemonic := 'divsd'
  Else SseMnemonic := 'divps';
 End Else If Base = 'min' Then Begin
  If Prefix = $66 Then SseMnemonic := 'minpd'
  Else If Prefix = $F3 Then SseMnemonic := 'minss'
  Else If Prefix = $F2 Then SseMnemonic := 'minsd'
  Else SseMnemonic := 'minps';
 End Else If Base = 'max' Then Begin
  If Prefix = $66 Then SseMnemonic := 'maxpd'
  Else If Prefix = $F3 Then SseMnemonic := 'maxss'
  Else If Prefix = $F2 Then SseMnemonic := 'maxsd'
  Else SseMnemonic := 'maxps';
 End Else If Base = 'and' Then Begin
  If Prefix = $66 Then SseMnemonic := 'andpd'
  Else SseMnemonic := 'andps';
 End Else If Base = 'or' Then Begin
  If Prefix = $66 Then SseMnemonic := 'orpd'
  Else SseMnemonic := 'orps';
 End Else If Base = 'xor' Then Begin
  If Prefix = $66 Then SseMnemonic := 'xorpd'
  Else SseMnemonic := 'xorps';
 End Else SseMnemonic := Base;
End;

Function VexSseName(Op2, PP: Byte): String;
Begin
 Case Op2 Of
  $10: If PP = 1 Then VexSseName := 'vmovupd' Else VexSseName := 'vmovups';
  $11: If PP = 1 Then VexSseName := 'vmovupd' Else VexSseName := 'vmovups';
  $28: If PP = 1 Then VexSseName := 'vmovapd' Else VexSseName := 'vmovaps';
  $29: If PP = 1 Then VexSseName := 'vmovapd' Else VexSseName := 'vmovaps';
  $54: If PP = 1 Then VexSseName := 'vandpd' Else VexSseName := 'vandps';
  $55: If PP = 1 Then VexSseName := 'vandnpd' Else VexSseName := 'vandnps';
  $56: If PP = 1 Then VexSseName := 'vorpd' Else VexSseName := 'vorps';
  $57: If PP = 1 Then VexSseName := 'vxorpd' Else VexSseName := 'vxorps';
  $58: If PP = 1 Then VexSseName := 'vaddpd' Else VexSseName := 'vaddps';
  $59: If PP = 1 Then VexSseName := 'vmulpd' Else VexSseName := 'vmulps';
  $5C: If PP = 1 Then VexSseName := 'vsubpd' Else VexSseName := 'vsubps';
  $5D: If PP = 1 Then VexSseName := 'vminpd' Else VexSseName := 'vminps';
  $5E: If PP = 1 Then VexSseName := 'vdivpd' Else VexSseName := 'vdivps';
  $5F: If PP = 1 Then VexSseName := 'vmaxpd' Else VexSseName := 'vmaxps';
 Else VexSseName := '';
 End;
End;

Function DecodeModRM64Intel(Off, VAddr, InstLenGuess: LongInt;
 Var Consumed: Integer; Var RegField: Byte;
 Wide64, RexR, RexX, RexB: Boolean): String;
Var M, ModBits, RM, Scale, Idx, BaseR: Byte;
    P, Disp, AbsAddr: LongInt; Inner, BaseText, IdxText: String;
Begin
 M := GetByteAt(Off);
 ModBits := M Shr 6;
 RegField := ((M Shr 3) And 7);
 If RexR Then RegField := RegField Or 8;
 RM := M And 7;
 If RexB Then RM := RM Or 8;
 P := Off + 1;
 Consumed := 1;
 If ModBits = 3 Then Begin
  DecodeModRM64Intel := X64Reg(RM, Wide64);
  Exit;
 End;
 Disp := 0; Inner := '';
 If (RM And 7) = 4 Then Begin
  M := GetByteAt(P); Inc(P); Inc(Consumed);
  Scale := M Shr 6;
  Idx := (M Shr 3) And 7; If RexX Then Idx := Idx Or 8;
  BaseR := M And 7; If RexB Then BaseR := BaseR Or 8;
  If (ModBits = 0) And ((BaseR And 7) = 5) Then BaseText := ''
  Else BaseText := Reg64I(BaseR);
  If (Idx And 7) = 4 Then IdxText := ''
  Else Begin
   IdxText := Reg64I(Idx);
   If Scale <> 0 Then IdxText := IdxText + '*' + LToS(1 Shl Scale);
  End;
  Inner := BaseText;
  If IdxText <> '' Then Begin
   If Inner <> '' Then Inner := Inner + '+';
   Inner := Inner + IdxText;
  End;
  If (ModBits = 0) And ((BaseR And 7) = 5) Then Begin
   Disp := GetDWordAt(P); Inc(P, 4); Inc(Consumed, 4);
   DecodeModRM64Intel := 'qword ptr [' + HexFixed(Disp,8) + 'h]';
   Exit;
  End;
 End Else If (ModBits = 0) And ((RM And 7) = 5) Then Begin
  Disp := GetDWordAt(P); Inc(P, 4); Inc(Consumed, 4);
  AbsAddr := VAddr + InstLenGuess + Disp;
  DecodeModRM64Intel := 'qword ptr [rip' + DispText(Disp) + '] ; ' + HexFixed(AbsAddr,8);
  Exit;
 End Else Inner := Reg64I(RM);
 If ModBits = 1 Then Begin
  Disp := SignedByte(GetByteAt(P)); Inc(P); Inc(Consumed);
 End Else If ModBits = 2 Then Begin
  Disp := GetDWordAt(P); Inc(P, 4); Inc(Consumed, 4);
 End;
 If Wide64 Then DecodeModRM64Intel := 'qword ptr [' + Inner + DispText(Disp) + ']'
 Else DecodeModRM64Intel := 'dword ptr [' + Inner + DispText(Disp) + ']';
End;

Function DecodeX64(Off, VAddr: LongInt; Var Len: Integer): String;
Var P: LongInt; Rex, B, Op2, RegF, Prefix, PP, VReg: Byte; RexW, RexR, RexX, RexB: Boolean;
    Used: Integer; RM, Mnem, VName: String; D, Target, Imm: LongInt; UseYmm: Boolean;
Begin
 P := Off;
 Rex := 0;
 Prefix := 0;
 B := GetByteAt(P);
 While (B = $66) Or (B = $F2) Or (B = $F3) Do Begin
  Prefix := B; Inc(P); B := GetByteAt(P);
 End;
 If (B >= $40) And (B <= $4F) Then Begin
  Rex := B; Inc(P);
 End;
 RexW := (Rex And 8) <> 0;
 RexR := (Rex And 4) <> 0;
 RexX := (Rex And 2) <> 0;
 RexB := (Rex And 1) <> 0;
 B := GetByteAt(P); Len := (P - Off) + 1;
 Case B Of
  $C5: Begin
        PP := GetByteAt(P + 1) And 3;
        VReg := ((GetByteAt(P + 1) Shr 3) And 15) Xor 15;
        UseYmm := (GetByteAt(P + 1) And 4) <> 0;
        Op2 := GetByteAt(P + 2);
        RexR := (GetByteAt(P + 1) And $80) = 0;
        If (GetByteAt(P + 1) = $F8) And (Op2 = $77) Then Begin
         Len := (P - Off) + 3;
         DecodeX64 := 'vzeroupper';
        End Else If (Op2 = $10) Or (Op2 = $28) Or
          ((Op2 >= $54) And (Op2 <= $5F)) Then Begin
         RM := DecodeModRM64Xmm(P+3, VAddr, 5, Used, RegF, RexR, False, False, UseYmm);
         Len := (P-Off)+3+Used;
         VName := VexSseName(Op2, PP);
         If VName = '' Then VName := 'vop';
         If UseYmm Then
          DecodeX64 := PadRight(VName, 12) + YmmReg(RegF) + ',' +
           YmmReg(VReg) + ',' + RM
         Else
          DecodeX64 := PadRight(VName, 12) + XmmReg(RegF) + ',' +
           XmmReg(VReg) + ',' + RM;
        End Else If (Op2 = $11) Or (Op2 = $29) Then Begin
         RM := DecodeModRM64Xmm(P+3, VAddr, 5, Used, RegF, RexR, False, False, UseYmm);
         Len := (P-Off)+3+Used;
         VName := VexSseName(Op2, PP);
         If VName = '' Then VName := 'vmov';
         If UseYmm Then DecodeX64 := PadRight(VName, 12) + RM + ',' + YmmReg(RegF)
         Else DecodeX64 := PadRight(VName, 12) + RM + ',' + XmmReg(RegF);
        End Else Begin
         Len := (P - Off) + 3;
         DecodeX64 := 'vex         C5 ' + HexByte(GetByteAt(P+1)) + ' ' + HexByte(Op2);
        End;
       End;
  $C4: Begin
        Len := (P - Off) + 4;
        DecodeX64 := 'vex         C4 ' + HexByte(GetByteAt(P+1)) + ' ' +
         HexByte(GetByteAt(P+2)) + ' ' + HexByte(GetByteAt(P+3));
       End;
  $50..$57: DecodeX64 := 'push        ' + Reg64I((B - $50) Or ((Rex And 1) Shl 3));
  $58..$5F: DecodeX64 := 'pop         ' + Reg64I((B - $58) Or ((Rex And 1) Shl 3));
  $90: DecodeX64 := 'nop';
  $C3: DecodeX64 := 'ret';
  $C2: Begin Len := Len + 2; DecodeX64 := 'ret         ' + ImmText(GetWordAt(P+1),4); End;
  $05: Begin Len := Len + 4; DecodeX64 := 'add         ' + X64Reg(0, RexW) + ',' + ImmText(GetDWordAt(P+1),8); End;
  $0D: Begin Len := Len + 4; DecodeX64 := 'or          ' + X64Reg(0, RexW) + ',' + ImmText(GetDWordAt(P+1),8); End;
  $25: Begin Len := Len + 4; DecodeX64 := 'and         ' + X64Reg(0, RexW) + ',' + ImmText(GetDWordAt(P+1),8); End;
  $2D: Begin Len := Len + 4; DecodeX64 := 'sub         ' + X64Reg(0, RexW) + ',' + ImmText(GetDWordAt(P+1),8); End;
  $35: Begin Len := Len + 4; DecodeX64 := 'xor         ' + X64Reg(0, RexW) + ',' + ImmText(GetDWordAt(P+1),8); End;
  $3D: Begin Len := Len + 4; DecodeX64 := 'cmp         ' + X64Reg(0, RexW) + ',' + ImmText(GetDWordAt(P+1),8); End;
  $E8: Begin Len := Len + 4; D := GetDWordAt(P+1); Target := VAddr + Len + D; DecodeX64 := 'call        ' + HexFixed(Target,8); End;
  $E9: Begin Len := Len + 4; D := GetDWordAt(P+1); Target := VAddr + Len + D; DecodeX64 := 'jmp         ' + HexFixed(Target,8); End;
  $EB: Begin Len := Len + 1; Target := VAddr + Len + SignedByte(GetByteAt(P+1)); DecodeX64 := 'jmp         ' + HexFixed(Target,8); End;
  $70..$7F: Begin Len := Len + 1; Target := VAddr + Len + SignedByte(GetByteAt(P+1)); DecodeX64 := PadRight(JccName(B And 15), 12) + HexFixed(Target,8); End;
  $B8..$BF: Begin Len := Len + 4; DecodeX64 := 'mov         ' + X64Reg((B - $B8) Or ((Rex And 1) Shl 3), RexW) + ',' + ImmText(GetDWordAt(P+1),8); End;
  $01: Begin RM := DecodeModRM64Intel(P+1, VAddr, 3, Used, RegF, RexW, RexR, RexX, RexB); Len := (P-Off)+1+Used; DecodeX64 := 'add         ' + RM + ',' + X64Reg(RegF, RexW); End;
  $03: Begin RM := DecodeModRM64Intel(P+1, VAddr, 3, Used, RegF, RexW, RexR, RexX, RexB); Len := (P-Off)+1+Used; DecodeX64 := 'add         ' + X64Reg(RegF, RexW) + ',' + RM; End;
  $09: Begin RM := DecodeModRM64Intel(P+1, VAddr, 3, Used, RegF, RexW, RexR, RexX, RexB); Len := (P-Off)+1+Used; DecodeX64 := 'or          ' + RM + ',' + X64Reg(RegF, RexW); End;
  $0B: Begin RM := DecodeModRM64Intel(P+1, VAddr, 3, Used, RegF, RexW, RexR, RexX, RexB); Len := (P-Off)+1+Used; DecodeX64 := 'or          ' + X64Reg(RegF, RexW) + ',' + RM; End;
  $21: Begin RM := DecodeModRM64Intel(P+1, VAddr, 3, Used, RegF, RexW, RexR, RexX, RexB); Len := (P-Off)+1+Used; DecodeX64 := 'and         ' + RM + ',' + X64Reg(RegF, RexW); End;
  $23: Begin RM := DecodeModRM64Intel(P+1, VAddr, 3, Used, RegF, RexW, RexR, RexX, RexB); Len := (P-Off)+1+Used; DecodeX64 := 'and         ' + X64Reg(RegF, RexW) + ',' + RM; End;
  $29: Begin RM := DecodeModRM64Intel(P+1, VAddr, 3, Used, RegF, RexW, RexR, RexX, RexB); Len := (P-Off)+1+Used; DecodeX64 := 'sub         ' + RM + ',' + X64Reg(RegF, RexW); End;
  $2B: Begin RM := DecodeModRM64Intel(P+1, VAddr, 3, Used, RegF, RexW, RexR, RexX, RexB); Len := (P-Off)+1+Used; DecodeX64 := 'sub         ' + X64Reg(RegF, RexW) + ',' + RM; End;
  $89: Begin RM := DecodeModRM64Intel(P+1, VAddr, 3, Used, RegF, RexW, RexR, RexX, RexB); Len := (P-Off)+1+Used; DecodeX64 := 'mov         ' + RM + ',' + X64Reg(RegF, RexW); End;
  $8B: Begin RM := DecodeModRM64Intel(P+1, VAddr, 3, Used, RegF, RexW, RexR, RexX, RexB); Len := (P-Off)+1+Used; DecodeX64 := 'mov         ' + X64Reg(RegF, RexW) + ',' + RM; End;
  $8D: Begin RM := DecodeModRM64Intel(P+1, VAddr, 3, Used, RegF, RexW, RexR, RexX, RexB); Len := (P-Off)+1+Used; DecodeX64 := 'lea         ' + X64Reg(RegF, RexW) + ',' + RM; End;
  $31: Begin RM := DecodeModRM64Intel(P+1, VAddr, 3, Used, RegF, RexW, RexR, RexX, RexB); Len := (P-Off)+1+Used; DecodeX64 := 'xor         ' + RM + ',' + X64Reg(RegF, RexW); End;
  $33: Begin RM := DecodeModRM64Intel(P+1, VAddr, 3, Used, RegF, RexW, RexR, RexX, RexB); Len := (P-Off)+1+Used; DecodeX64 := 'xor         ' + X64Reg(RegF, RexW) + ',' + RM; End;
  $39: Begin RM := DecodeModRM64Intel(P+1, VAddr, 3, Used, RegF, RexW, RexR, RexX, RexB); Len := (P-Off)+1+Used; DecodeX64 := 'cmp         ' + RM + ',' + X64Reg(RegF, RexW); End;
  $3B: Begin RM := DecodeModRM64Intel(P+1, VAddr, 3, Used, RegF, RexW, RexR, RexX, RexB); Len := (P-Off)+1+Used; DecodeX64 := 'cmp         ' + X64Reg(RegF, RexW) + ',' + RM; End;
  $85: Begin RM := DecodeModRM64Intel(P+1, VAddr, 3, Used, RegF, RexW, RexR, RexX, RexB); Len := (P-Off)+1+Used; DecodeX64 := 'test        ' + RM + ',' + X64Reg(RegF, RexW); End;
  $83: Begin
        RM := DecodeModRM64Intel(P+1, VAddr, 4, Used, RegF, RexW, RexR, RexX, RexB);
        Imm := SignedByte(GetByteAt(P+1+Used));
        Len := (P-Off)+2+Used;
        DecodeX64 := PadRight(Grp1Name(RegF), 12) + RM + ',' + ImmText(Imm,2);
       End;
  $81: Begin
        RM := DecodeModRM64Intel(P+1, VAddr, 7, Used, RegF, RexW, RexR, RexX, RexB);
        Imm := GetDWordAt(P+1+Used);
        Len := (P-Off)+5+Used;
        DecodeX64 := PadRight(Grp1Name(RegF), 12) + RM + ',' + ImmText(Imm,8);
       End;
  $0F: Begin
        Op2 := GetByteAt(P+1);
        If (Op2 >= $80) And (Op2 <= $8F) Then Begin
         D := GetDWordAt(P+2); Len := (P-Off)+6; Target := VAddr + Len + D;
         DecodeX64 := PadRight(JccName(Op2 And 15), 12) + HexFixed(Target,8);
        End Else If Op2 = $1F Then Begin
         RM := DecodeModRM64Intel(P+2, VAddr, 4, Used, RegF, RexW, RexR, RexX, RexB);
         Len := (P-Off)+2+Used;
         DecodeX64 := 'nop         ' + RM;
        End Else If Op2 = $AF Then Begin
         RM := DecodeModRM64Intel(P+2, VAddr, 4, Used, RegF, RexW, RexR, RexX, RexB);
         Len := (P-Off)+2+Used;
         DecodeX64 := 'imul        ' + X64Reg(RegF, RexW) + ',' + RM;
        End Else If (Op2 = $B6) Or (Op2 = $B7) Then Begin
         RM := DecodeModRM64Intel(P+2, VAddr, 4, Used, RegF, Op2 = $B7, RexR, RexX, RexB);
         Len := (P-Off)+2+Used;
         DecodeX64 := 'movzx       ' + X64Reg(RegF, RexW) + ',' + RM;
        End Else If (Op2 = $BE) Or (Op2 = $BF) Then Begin
         RM := DecodeModRM64Intel(P+2, VAddr, 4, Used, RegF, Op2 = $BF, RexR, RexX, RexB);
         Len := (P-Off)+2+Used;
         DecodeX64 := 'movsx       ' + X64Reg(RegF, RexW) + ',' + RM;
        End Else If (Op2 = $10) Or (Op2 = $28) Then Begin
         RM := DecodeModRM64Xmm(P+2, VAddr, 4, Used, RegF, RexR, RexX, RexB, False);
         Len := (P-Off)+2+Used;
         If Op2 = $10 Then Mnem := SseMnemonic(Prefix, 'movu')
         Else Mnem := SseMnemonic(Prefix, 'mov');
         DecodeX64 := PadRight(Mnem, 12) + XmmReg(RegF) + ',' + RM;
        End Else If (Op2 = $11) Or (Op2 = $29) Then Begin
         RM := DecodeModRM64Xmm(P+2, VAddr, 4, Used, RegF, RexR, RexX, RexB, False);
         Len := (P-Off)+2+Used;
         If Op2 = $11 Then Mnem := SseMnemonic(Prefix, 'movu')
         Else Mnem := SseMnemonic(Prefix, 'mov');
         DecodeX64 := PadRight(Mnem, 12) + RM + ',' + XmmReg(RegF);
        End Else If Op2 = $57 Then Begin
         RM := DecodeModRM64Xmm(P+2, VAddr, 4, Used, RegF, RexR, RexX, RexB, False);
         Len := (P-Off)+2+Used;
         DecodeX64 := PadRight(SseMnemonic(Prefix, 'xor'), 12) + XmmReg(RegF) + ',' + RM;
        End Else If (Op2 = $54) Or (Op2 = $56) Or (Op2 = $58) Or
          (Op2 = $59) Or ((Op2 >= $5C) And (Op2 <= $5F)) Then Begin
         RM := DecodeModRM64Xmm(P+2, VAddr, 4, Used, RegF, RexR, RexX, RexB, False);
         Len := (P-Off)+2+Used;
         Case Op2 Of
          $54: Mnem := SseMnemonic(Prefix, 'and');
          $56: Mnem := SseMnemonic(Prefix, 'or');
          $58: Mnem := SseMnemonic(Prefix, 'add');
          $59: Mnem := SseMnemonic(Prefix, 'mul');
          $5C: Mnem := SseMnemonic(Prefix, 'sub');
          $5D: Mnem := SseMnemonic(Prefix, 'min');
          $5E: Mnem := SseMnemonic(Prefix, 'div');
         Else Mnem := SseMnemonic(Prefix, 'max');
         End;
         DecodeX64 := PadRight(Mnem, 12) + XmmReg(RegF) + ',' + RM;
        End Else Begin
         Len := (P-Off)+2;
         DecodeX64 := 'db          0Fh,' + HexByte(Op2) + 'h';
        End;
       End;
  $FF: Begin
        RM := DecodeModRM64Intel(P+1, VAddr, 3, Used, RegF, True, RexR, RexX, RexB);
        Len := (P-Off)+1+Used;
        Case RegF And 7 Of
         0: Mnem := 'inc';
         1: Mnem := 'dec';
         2: Mnem := 'call';
         4: Mnem := 'jmp';
         6: Mnem := 'push';
        Else Mnem := 'grpff';
        End;
        DecodeX64 := PadRight(Mnem, 12) + RM;
       End;
 Else Begin
  Len := (P-Off)+1;
  DecodeX64 := 'db          ' + HexByte(B) + 'h';
 End;
 End;
End;

Function ArmReg(R: Byte): String;
Begin
 Case R And 15 Of
  13: ArmReg := 'sp';
  14: ArmReg := 'lr';
  15: ArmReg := 'pc';
 Else ArmReg := 'r' + LToS(R And 15);
 End;
End;

Function ArmCond(C: Byte): String;
Begin
 Case C And 15 Of
  0: ArmCond := 'eq';
  1: ArmCond := 'ne';
  2: ArmCond := 'cs';
  3: ArmCond := 'cc';
  4: ArmCond := 'mi';
  5: ArmCond := 'pl';
  6: ArmCond := 'vs';
  7: ArmCond := 'vc';
  8: ArmCond := 'hi';
  9: ArmCond := 'ls';
 10: ArmCond := 'ge';
 11: ArmCond := 'lt';
 12: ArmCond := 'gt';
 13: ArmCond := 'le';
 14: ArmCond := '';
 Else ArmCond := '';
 End;
End;

Function Ror32(V: LongInt; N: Byte): LongInt;
Var I: Byte;
Begin
 N := N And 31;
 For I := 1 To N Do
  V := (V Shr 1) Or ((V And 1) Shl 31);
 Ror32 := V;
End;

Function ArmImm12(Op: LongInt): LongInt;
Begin
 ArmImm12 := Ror32(Op And $FF, ((Op Shr 8) And 15) * 2);
End;

Function ArmDPName(N: Byte): String;
Begin
 Case N And 15 Of
  0: ArmDPName := 'and';
  1: ArmDPName := 'eor';
  2: ArmDPName := 'sub';
  3: ArmDPName := 'rsb';
  4: ArmDPName := 'add';
  5: ArmDPName := 'adc';
  6: ArmDPName := 'sbc';
  7: ArmDPName := 'rsc';
  8: ArmDPName := 'tst';
  9: ArmDPName := 'teq';
 10: ArmDPName := 'cmp';
 11: ArmDPName := 'cmn';
 12: ArmDPName := 'orr';
 13: ArmDPName := 'mov';
 14: ArmDPName := 'bic';
 Else ArmDPName := 'mvn';
 End;
End;

Function ArmRegList(Mask: Word): String;
Var I: Integer; S: String;
Begin
 S := '{';
 For I := 0 To 15 Do
  If (Mask And (1 Shl I)) <> 0 Then Begin
   If Length(S) > 1 Then S := S + ',';
   S := S + ArmReg(I);
  End;
 ArmRegList := S + '}';
End;

Function DecodeARM32(Off, VAddr: LongInt; Var Len: Integer): String;
Var Op, Cond, Cls, Code, Rn, Rd, Rm, Imm, Target: LongInt;
    Mnem, Suf, Op2: String;
Begin
 Len := 4;
 Op := GetDWordAt(Off);
 Cond := (Op Shr 28) And 15;
 Suf := ArmCond(Cond);
 If (Op And $0FFFFFF0) = $012FFF10 Then Begin
  DecodeARM32 := 'bx' + Suf + '          ' + ArmReg(Op And 15);
  Exit;
 End;
 If (Op And $0F000000) = $0A000000 Then Begin
  Imm := Op And $00FFFFFF;
  If (Imm And $00800000) <> 0 Then Imm := Imm Or LongInt($FF000000);
  Target := VAddr + 8 + (Imm Shl 2);
  If (Op And $01000000) <> 0 Then Mnem := 'bl' Else Mnem := 'b';
  DecodeARM32 := PadRight(Mnem + Suf, 12) + HexFixed(Target, 8);
  Exit;
 End;
 Cls := (Op Shr 26) And 3;
 If Cls = 0 Then Begin
  Code := (Op Shr 21) And 15;
  Rn := (Op Shr 16) And 15;
  Rd := (Op Shr 12) And 15;
  If (Op And $02000000) <> 0 Then
   Op2 := '#' + ImmText(ArmImm12(Op), 8)
  Else Begin
   Rm := Op And 15;
   Op2 := ArmReg(Rm);
  End;
  Mnem := ArmDPName(Code) + Suf;
  If ((Code >= 8) And (Code <= 11)) Then
   DecodeARM32 := PadRight(Mnem, 12) + ArmReg(Rn) + ',' + Op2
  Else If (Code = 13) Or (Code = 15) Then
   DecodeARM32 := PadRight(Mnem, 12) + ArmReg(Rd) + ',' + Op2
  Else
   DecodeARM32 := PadRight(Mnem, 12) + ArmReg(Rd) + ',' + ArmReg(Rn) + ',' + Op2;
  Exit;
 End;
 If Cls = 1 Then Begin
  Rn := (Op Shr 16) And 15;
  Rd := (Op Shr 12) And 15;
  Imm := Op And $FFF;
  If (Op And $00100000) <> 0 Then Mnem := 'ldr' Else Mnem := 'str';
  Mnem := Mnem + Suf;
  If (Op And $00800000) = 0 Then Imm := -Imm;
  DecodeARM32 := PadRight(Mnem, 12) + ArmReg(Rd) + ',[' + ArmReg(Rn) + DispText(Imm) + ']';
  Exit;
 End;
 If ((Op Shr 25) And 7) = 4 Then Begin
  Rn := (Op Shr 16) And 15;
  If (Op And $00100000) <> 0 Then Mnem := 'ldm' Else Mnem := 'stm';
  DecodeARM32 := PadRight(Mnem + Suf, 12) + ArmReg(Rn) + ',' + ArmRegList(Op And $FFFF);
  Exit;
 End;
 DecodeARM32 := 'dcd         ' + HexFixed(Op, 8) + 'h';
End;

Function ThumbCondName(C: Byte): String;
Begin
 Case C And 15 Of
  0: ThumbCondName := 'beq';
  1: ThumbCondName := 'bne';
  2: ThumbCondName := 'bcs';
  3: ThumbCondName := 'bcc';
  4: ThumbCondName := 'bmi';
  5: ThumbCondName := 'bpl';
  6: ThumbCondName := 'bvs';
  7: ThumbCondName := 'bvc';
  8: ThumbCondName := 'bhi';
  9: ThumbCondName := 'bls';
 10: ThumbCondName := 'bge';
 11: ThumbCondName := 'blt';
 12: ThumbCondName := 'bgt';
 13: ThumbCondName := 'ble';
 Else ThumbCondName := 'b';
 End;
End;

Function DecodeThumb(Off, VAddr: LongInt; Var Len: Integer): String;
Var H, H2: Word; Op, Rd, Rn, Rm, Imm, Target: LongInt; M: String;
Begin
 H := GetWordAt(Off);
 Len := 2;
 If ((H And $F800) = $F000) Or ((H And $F800) = $F800) Or
    ((H And $F800) = $E800) Then Begin
  H2 := GetWordAt(Off + 2);
  Len := 4;
  DecodeThumb := 'dcd         ' + HexFixed(H Or (LongInt(H2) Shl 16), 8) + 'h';
  Exit;
 End;
 If (H And $FF00) = $B500 Then Begin
  DecodeThumb := 'push        ' + ArmRegList((H And $FF) Or ((H And $0100) Shl 6));
  Exit;
 End;
 If (H And $FF00) = $BD00 Then Begin
  DecodeThumb := 'pop         ' + ArmRegList((H And $FF) Or ((H And $0100) Shl 7));
  Exit;
 End;
 If (H And $F800) = $2000 Then Begin
  Rd := (H Shr 8) And 7; Imm := H And $FF;
  DecodeThumb := 'movs        ' + ArmReg(Rd) + ',#' + ImmText(Imm, 2);
  Exit;
 End;
 If (H And $F800) = $2800 Then Begin
  Rn := (H Shr 8) And 7; Imm := H And $FF;
  DecodeThumb := 'cmp         ' + ArmReg(Rn) + ',#' + ImmText(Imm, 2);
  Exit;
 End;
 If (H And $F800) = $3000 Then Begin
  Rd := (H Shr 8) And 7; Imm := H And $FF;
  DecodeThumb := 'adds        ' + ArmReg(Rd) + ',#' + ImmText(Imm, 2);
  Exit;
 End;
 If (H And $F800) = $3800 Then Begin
  Rd := (H Shr 8) And 7; Imm := H And $FF;
  DecodeThumb := 'subs        ' + ArmReg(Rd) + ',#' + ImmText(Imm, 2);
  Exit;
 End;
 If (H And $F800) = $4800 Then Begin
  Rd := (H Shr 8) And 7; Imm := (H And $FF) Shl 2;
  DecodeThumb := 'ldr         ' + ArmReg(Rd) + ',[pc+' + ImmText(Imm, 4) + ']';
  Exit;
 End;
 If (H And $F800) = $6000 Then Begin
  Imm := ((H Shr 6) And 31) Shl 2; Rn := (H Shr 3) And 7; Rd := H And 7;
  DecodeThumb := 'str         ' + ArmReg(Rd) + ',[' + ArmReg(Rn) + DispText(Imm) + ']';
  Exit;
 End;
 If (H And $F800) = $6800 Then Begin
  Imm := ((H Shr 6) And 31) Shl 2; Rn := (H Shr 3) And 7; Rd := H And 7;
  DecodeThumb := 'ldr         ' + ArmReg(Rd) + ',[' + ArmReg(Rn) + DispText(Imm) + ']';
  Exit;
 End;
 If (H And $F000) = $D000 Then Begin
  Op := (H Shr 8) And 15;
  If Op <> 15 Then Begin
   Imm := H And $FF; If (Imm And $80) <> 0 Then Imm := Imm Or LongInt($FFFFFF00);
   Target := VAddr + 4 + (Imm Shl 1);
   DecodeThumb := PadRight(ThumbCondName(Op), 12) + HexFixed(Target, 8);
   Exit;
  End;
 End;
 If (H And $F800) = $E000 Then Begin
  Imm := H And $7FF; If (Imm And $400) <> 0 Then Imm := Imm Or LongInt($FFFFF800);
  Target := VAddr + 4 + (Imm Shl 1);
  DecodeThumb := 'b           ' + HexFixed(Target, 8);
  Exit;
 End;
 If (H And $FC00) = $4400 Then Begin
  Op := (H Shr 8) And 3;
  Rd := (H And 7) Or ((H Shr 4) And 8);
  Rm := (H Shr 3) And 15;
  Case Op Of
   0: M := 'add';
   1: M := 'cmp';
   2: M := 'mov';
  Else M := 'bx';
  End;
  If M = 'bx' Then DecodeThumb := 'bx          ' + ArmReg(Rm)
  Else DecodeThumb := PadRight(M, 12) + ArmReg(Rd) + ',' + ArmReg(Rm);
  Exit;
 End;
 DecodeThumb := 'dcw         ' + HexFixed(H, 4) + 'h';
End;

Function A64Reg(R: LongInt; Is64: Boolean): String;
Begin
 If R = 31 Then Begin
  If Is64 Then A64Reg := 'sp' Else A64Reg := 'wsp';
 End Else If Is64 Then A64Reg := 'x' + LToS(R)
 Else A64Reg := 'w' + LToS(R);
End;

Function DecodeARM64(Off, VAddr: LongInt; Var Len: Integer): String;
Var Op, Rd, Rn, Rm, Rt2, Imm, Target: LongInt; Is64: Boolean; M: String;
Begin
 Len := 4;
 Op := GetDWordAt(Off);
 If Op = LongInt($D65F03C0) Then Begin DecodeARM64 := 'ret'; Exit; End;
 If (Op And $FF000010) = $54000000 Then Begin
  Imm := (Op Shr 5) And $7FFFF; If (Imm And $40000) <> 0 Then Imm := Imm Or LongInt($FFF80000);
  Target := VAddr + (Imm Shl 2);
  DecodeARM64 := PadRight(JccName(Op And 15), 12) + HexFixed(Target,8);
  Exit;
 End;
 If (Op And $7C000000) = $14000000 Then Begin
  Imm := Op And $03FFFFFF; If (Imm And $02000000) <> 0 Then Imm := Imm Or LongInt($FC000000);
  Target := VAddr + (Imm Shl 2);
  If Op < 0 Then M := 'bl' Else M := 'b';
  DecodeARM64 := PadRight(M, 12) + HexFixed(Target, 8);
  Exit;
 End;
 If (Op And $7C000000) = $34000000 Then Begin
  Imm := (Op Shr 5) And $7FFFF; If (Imm And $40000) <> 0 Then Imm := Imm Or LongInt($FFF80000);
  Rd := Op And 31; Target := VAddr + (Imm Shl 2);
  If (Op And $01000000) <> 0 Then M := 'cbnz' Else M := 'cbz';
  Is64 := Op < 0;
  DecodeARM64 := PadRight(M, 12) + A64Reg(Rd, Is64) + ',' + HexFixed(Target, 8);
  Exit;
 End;
 If (Op And $9F000000) = $90000000 Then Begin
  Rd := Op And 31;
  Imm := ((Op Shr 5) And $7FFFF) Or ((Op Shr 29) And 3);
  Target := (VAddr And LongInt($FFFFF000)) + (Imm Shl 12);
  DecodeARM64 := 'adrp        ' + A64Reg(Rd, True) + ',' + HexFixed(Target,8);
  Exit;
 End;
 If (Op And $7F800000) = $52800000 Then Begin
  Rd := Op And 31; Imm := (Op Shr 5) And $FFFF;
  Is64 := Op < 0;
  If (Op And $20000000) <> 0 Then M := 'movk' Else M := 'movz';
  DecodeARM64 := PadRight(M, 12) + A64Reg(Rd, Is64) + ',#' + ImmText(Imm,4);
  Exit;
 End;
 If (Op And $FFC00000) = $91000000 Then Begin
  Rd := Op And 31; Rn := (Op Shr 5) And 31; Imm := (Op Shr 10) And $FFF;
  DecodeARM64 := 'add         ' + A64Reg(Rd, True) + ',' + A64Reg(Rn, True) + ',#' + ImmText(Imm, 4);
  Exit;
 End;
 If (Op And $FFC00000) = $D1000000 Then Begin
  Rd := Op And 31; Rn := (Op Shr 5) And 31; Imm := (Op Shr 10) And $FFF;
  DecodeARM64 := 'sub         ' + A64Reg(Rd, True) + ',' + A64Reg(Rn, True) + ',#' + ImmText(Imm, 4);
  Exit;
 End;
 If (Op And $FFC00000) = $F9400000 Then Begin
  Rd := Op And 31; Rn := (Op Shr 5) And 31; Imm := ((Op Shr 10) And $FFF) Shl 3;
  DecodeARM64 := 'ldr         ' + A64Reg(Rd, True) + ',[' + A64Reg(Rn, True) + DispText(Imm) + ']';
  Exit;
 End;
 If (Op And $FFC00000) = $F9000000 Then Begin
  Rd := Op And 31; Rn := (Op Shr 5) And 31; Imm := ((Op Shr 10) And $FFF) Shl 3;
  DecodeARM64 := 'str         ' + A64Reg(Rd, True) + ',[' + A64Reg(Rn, True) + DispText(Imm) + ']';
  Exit;
 End;
 If (Op And $FFC00000) = $B9400000 Then Begin
  Rd := Op And 31; Rn := (Op Shr 5) And 31; Imm := ((Op Shr 10) And $FFF) Shl 2;
  DecodeARM64 := 'ldr         ' + A64Reg(Rd, False) + ',[' + A64Reg(Rn, True) + DispText(Imm) + ']';
  Exit;
 End;
 If (Op And $FFC00000) = $B9000000 Then Begin
  Rd := Op And 31; Rn := (Op Shr 5) And 31; Imm := ((Op Shr 10) And $FFF) Shl 2;
  DecodeARM64 := 'str         ' + A64Reg(Rd, False) + ',[' + A64Reg(Rn, True) + DispText(Imm) + ']';
  Exit;
 End;
 If (Op And $7E000000) = $28000000 Then Begin
  Rd := Op And 31; Rt2 := (Op Shr 10) And 31; Rn := (Op Shr 5) And 31;
  Imm := ((Op Shr 15) And $7F); If (Imm And $40) <> 0 Then Imm := Imm Or LongInt($FFFFFF80);
  If (Op And $00400000) <> 0 Then M := 'ldp' Else M := 'stp';
  DecodeARM64 := PadRight(M, 12) + A64Reg(Rd, True) + ',' + A64Reg(Rt2, True) +
   ',[' + A64Reg(Rn, True) + DispText(Imm Shl 3) + ']';
  Exit;
 End;
 If (Op And $FFC00000) = $A9000000 Then Begin
  Rd := Op And 31; Rt2 := (Op Shr 10) And 31; Rn := (Op Shr 5) And 31;
  Imm := ((Op Shr 15) And $7F); If (Imm And $40) <> 0 Then Imm := Imm Or LongInt($FFFFFF80);
  DecodeARM64 := 'stp         ' + A64Reg(Rd, True) + ',' + A64Reg(Rt2, True) +
   ',[' + A64Reg(Rn, True) + DispText(Imm Shl 3) + ']';
  Exit;
 End;
 If (Op And $FFC00000) = $A9400000 Then Begin
  Rd := Op And 31; Rt2 := (Op Shr 10) And 31; Rn := (Op Shr 5) And 31;
  Imm := ((Op Shr 15) And $7F); If (Imm And $40) <> 0 Then Imm := Imm Or LongInt($FFFFFF80);
  DecodeARM64 := 'ldp         ' + A64Reg(Rd, True) + ',' + A64Reg(Rt2, True) +
   ',[' + A64Reg(Rn, True) + DispText(Imm Shl 3) + ']';
  Exit;
 End;
 If (Op And $FFE0FC00) = $AA0003E0 Then Begin
  Rd := Op And 31; Rm := (Op Shr 16) And 31;
  DecodeARM64 := 'mov         ' + A64Reg(Rd, True) + ',' + A64Reg(Rm, True);
  Exit;
 End;
 DecodeARM64 := 'dcd         ' + HexFixed(Op, 8) + 'h';
End;

Function MipsReg(R: LongInt): String;
Const Names: Array[0..31] Of String[5] =
 ('zero','at','v0','v1','a0','a1','a2','a3',
  't0','t1','t2','t3','t4','t5','t6','t7',
  's0','s1','s2','s3','s4','s5','s6','s7',
  't8','t9','k0','k1','gp','sp','fp','ra');
Begin
 MipsReg := '$' + Names[R And 31];
End;

Function DecodeMIPS(Off, VAddr: LongInt; Var Len: Integer): String;
Var Op, Opc, Rs, Rt, Rd, Sa, Fn, Imm, Target: LongInt; M: String;
Begin
 Len := 4;
 Op := GetDWordAt(Off);
 Opc := (Op Shr 26) And 63; Rs := (Op Shr 21) And 31;
 Rt := (Op Shr 16) And 31; Rd := (Op Shr 11) And 31;
 Sa := (Op Shr 6) And 31; Fn := Op And 63;
 If Op = 0 Then Begin DecodeMIPS := 'nop'; Exit; End;
 If Opc = 0 Then Begin
  Case Fn Of
   $08: DecodeMIPS := 'jr          ' + MipsReg(Rs);
   $09: DecodeMIPS := 'jalr        ' + MipsReg(Rd) + ',' + MipsReg(Rs);
   $20: DecodeMIPS := 'add         ' + MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt);
   $21: DecodeMIPS := 'addu        ' + MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt);
   $22: DecodeMIPS := 'sub         ' + MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt);
   $23: DecodeMIPS := 'subu        ' + MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt);
   $24: DecodeMIPS := 'and         ' + MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt);
   $25: DecodeMIPS := 'or          ' + MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt);
   $26: DecodeMIPS := 'xor         ' + MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt);
   $2A: DecodeMIPS := 'slt         ' + MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt);
   $00: DecodeMIPS := 'sll         ' + MipsReg(Rd) + ',' + MipsReg(Rt) + ',' + LToS(Sa);
   $02: DecodeMIPS := 'srl         ' + MipsReg(Rd) + ',' + MipsReg(Rt) + ',' + LToS(Sa);
   $03: DecodeMIPS := 'sra         ' + MipsReg(Rd) + ',' + MipsReg(Rt) + ',' + LToS(Sa);
  Else DecodeMIPS := 'word        ' + HexFixed(Op,8) + 'h';
  End;
  Exit;
 End;
 Imm := SignExtend(Op And $FFFF, 16);
 Case Opc Of
  $02,$03: Begin
       Target := ((VAddr + 4) And LongInt($F0000000)) Or ((Op And $03FFFFFF) Shl 2);
       If Opc = $03 Then M := 'jal' Else M := 'j';
       DecodeMIPS := PadRight(M, 12) + HexFixed(Target,8);
      End;
  $04: DecodeMIPS := 'beq         ' + MipsReg(Rs) + ',' + MipsReg(Rt) + ',' + HexFixed(VAddr + 4 + (Imm Shl 2),8);
  $05: DecodeMIPS := 'bne         ' + MipsReg(Rs) + ',' + MipsReg(Rt) + ',' + HexFixed(VAddr + 4 + (Imm Shl 2),8);
  $08: DecodeMIPS := 'addi        ' + MipsReg(Rt) + ',' + MipsReg(Rs) + ',' + ImmText(Imm,4);
  $09: DecodeMIPS := 'addiu       ' + MipsReg(Rt) + ',' + MipsReg(Rs) + ',' + ImmText(Imm,4);
  $0A: DecodeMIPS := 'slti        ' + MipsReg(Rt) + ',' + MipsReg(Rs) + ',' + ImmText(Imm,4);
  $0C: DecodeMIPS := 'andi        ' + MipsReg(Rt) + ',' + MipsReg(Rs) + ',' + ImmText(Op And $FFFF,4);
  $0D: DecodeMIPS := 'ori         ' + MipsReg(Rt) + ',' + MipsReg(Rs) + ',' + ImmText(Op And $FFFF,4);
  $0E: DecodeMIPS := 'xori        ' + MipsReg(Rt) + ',' + MipsReg(Rs) + ',' + ImmText(Op And $FFFF,4);
  $0F: DecodeMIPS := 'lui         ' + MipsReg(Rt) + ',' + ImmText(Op And $FFFF,4);
  $23: DecodeMIPS := 'lw          ' + MipsReg(Rt) + ',' + ImmText(Imm,4) + '(' + MipsReg(Rs) + ')';
  $2B: DecodeMIPS := 'sw          ' + MipsReg(Rt) + ',' + ImmText(Imm,4) + '(' + MipsReg(Rs) + ')';
  $20: DecodeMIPS := 'lb          ' + MipsReg(Rt) + ',' + ImmText(Imm,4) + '(' + MipsReg(Rs) + ')';
  $28: DecodeMIPS := 'sb          ' + MipsReg(Rt) + ',' + ImmText(Imm,4) + '(' + MipsReg(Rs) + ')';
 Else DecodeMIPS := 'word        ' + HexFixed(Op,8) + 'h';
 End;
End;

Function PPCReg(R: LongInt): String;
Begin
 PPCReg := 'r' + LToS(R And 31);
End;

Function DecodePowerPC(Off, VAddr: LongInt; Var Len: Integer): String;
Var Op, Opc, Rt, Ra, Rb, Imm, Target, XO: LongInt; M: String;
Begin
 Len := 4;
 Op := GetDWordBEAt(Off);
 Opc := (Op Shr 26) And 63; Rt := (Op Shr 21) And 31;
 Ra := (Op Shr 16) And 31; Rb := (Op Shr 11) And 31;
 Imm := SignExtend(Op And $FFFF, 16);
 Case Opc Of
  14: DecodePowerPC := 'addi        ' + PPCReg(Rt) + ',' + PPCReg(Ra) + ',' + ImmText(Imm,4);
  15: DecodePowerPC := 'addis       ' + PPCReg(Rt) + ',' + PPCReg(Ra) + ',' + ImmText(Imm,4);
  24: DecodePowerPC := 'ori         ' + PPCReg(Rt) + ',' + PPCReg(Ra) + ',' + ImmText(Op And $FFFF,4);
  25: DecodePowerPC := 'oris        ' + PPCReg(Rt) + ',' + PPCReg(Ra) + ',' + ImmText(Op And $FFFF,4);
  32: DecodePowerPC := 'lwz         ' + PPCReg(Rt) + ',' + ImmText(Imm,4) + '(' + PPCReg(Ra) + ')';
  36: DecodePowerPC := 'stw         ' + PPCReg(Rt) + ',' + ImmText(Imm,4) + '(' + PPCReg(Ra) + ')';
  34: DecodePowerPC := 'lbz         ' + PPCReg(Rt) + ',' + ImmText(Imm,4) + '(' + PPCReg(Ra) + ')';
  38: DecodePowerPC := 'stb         ' + PPCReg(Rt) + ',' + ImmText(Imm,4) + '(' + PPCReg(Ra) + ')';
  16: Begin
       Target := VAddr + SignExtend(Op And $FFFC, 16);
       If (Op And 1) <> 0 Then M := 'bcl' Else M := 'bc';
       DecodePowerPC := PadRight(M, 12) + HexFixed(Target,8);
      End;
  18: Begin
       Target := SignExtend(Op And $03FFFFFC, 26);
       If (Op And 2) = 0 Then Target := VAddr + Target;
       If (Op And 1) <> 0 Then M := 'bl' Else M := 'b';
       DecodePowerPC := PadRight(M, 12) + HexFixed(Target,8);
      End;
  31: Begin
       XO := (Op Shr 1) And 1023;
       Case XO Of
        266: DecodePowerPC := 'add         ' + PPCReg(Rt) + ',' + PPCReg(Ra) + ',' + PPCReg(Rb);
        40: DecodePowerPC := 'subf        ' + PPCReg(Rt) + ',' + PPCReg(Ra) + ',' + PPCReg(Rb);
        444: DecodePowerPC := 'or          ' + PPCReg(Rt) + ',' + PPCReg(Ra) + ',' + PPCReg(Rb);
        28: DecodePowerPC := 'and         ' + PPCReg(Rt) + ',' + PPCReg(Ra) + ',' + PPCReg(Rb);
        467: DecodePowerPC := 'mtspr       ' + LToS(((Op Shr 16) And 31) Or ((Op Shr 6) And 992)) + ',' + PPCReg(Rt);
        339: DecodePowerPC := 'mfspr       ' + PPCReg(Rt) + ',' + LToS(((Op Shr 16) And 31) Or ((Op Shr 6) And 992));
       Else DecodePowerPC := 'long        ' + HexFixed(Op,8) + 'h';
       End;
      End;
 Else DecodePowerPC := 'long        ' + HexFixed(Op,8) + 'h';
 End;
End;

Function SHReg(R: LongInt): String;
Begin
 SHReg := 'r' + LToS(R And 15);
End;

Function DecodeSuperH(Off, VAddr: LongInt; Var Len: Integer): String;
Var H, N, M, D: LongInt;
Begin
 Len := 2;
 H := GetWordAt(Off); N := (H Shr 8) And 15; M := (H Shr 4) And 15; D := H And 15;
 If H = 9 Then Begin DecodeSuperH := 'nop'; Exit; End;
 If (H And $F000) = $E000 Then Begin DecodeSuperH := 'mov         #' + ImmText(SignExtend(H And $FF,8),2) + ',' + SHReg(N); Exit; End;
 If (H And $F000) = $6000 Then Begin
  Case D Of
   0: DecodeSuperH := 'mov.b       @' + SHReg(M) + ',' + SHReg(N);
   1: DecodeSuperH := 'mov.w       @' + SHReg(M) + ',' + SHReg(N);
   2: DecodeSuperH := 'mov.l       @' + SHReg(M) + ',' + SHReg(N);
   3: DecodeSuperH := 'mov         ' + SHReg(M) + ',' + SHReg(N);
   7: DecodeSuperH := 'not         ' + SHReg(M) + ',' + SHReg(N);
   8: DecodeSuperH := 'swap.b      ' + SHReg(M) + ',' + SHReg(N);
   9: DecodeSuperH := 'swap.w      ' + SHReg(M) + ',' + SHReg(N);
  Else DecodeSuperH := 'dc.w        ' + HexFixed(H,4) + 'h';
  End;
  Exit;
 End;
 If (H And $F00F) = $300C Then Begin DecodeSuperH := 'add         ' + SHReg(M) + ',' + SHReg(N); Exit; End;
 If (H And $F00F) = $3008 Then Begin DecodeSuperH := 'sub         ' + SHReg(M) + ',' + SHReg(N); Exit; End;
 If (H And $F00F) = $300D Then Begin DecodeSuperH := 'dmuls.l     ' + SHReg(M) + ',' + SHReg(N); Exit; End;
 If (H And $F000) = $A000 Then Begin D := SignExtend(H And $0FFF, 12); DecodeSuperH := 'bra         ' + HexFixed(VAddr + 4 + (D Shl 1),8); Exit; End;
 If (H And $F000) = $B000 Then Begin D := SignExtend(H And $0FFF, 12); DecodeSuperH := 'bsr         ' + HexFixed(VAddr + 4 + (D Shl 1),8); Exit; End;
 If (H And $FF00) = $8900 Then Begin D := SignExtend(H And $FF,8); DecodeSuperH := 'bt          ' + HexFixed(VAddr + 4 + (D Shl 1),8); Exit; End;
 If (H And $FF00) = $8B00 Then Begin D := SignExtend(H And $FF,8); DecodeSuperH := 'bf          ' + HexFixed(VAddr + 4 + (D Shl 1),8); Exit; End;
 DecodeSuperH := 'dc.w        ' + HexFixed(H,4) + 'h';
End;

Function SparcReg(R: LongInt): String;
Const Prefix: Array[0..3] Of String[2] = ('g','o','l','i');
Begin
 SparcReg := '%' + Prefix[(R Shr 3) And 3] + LToS(R And 7);
End;

Function DecodeSPARC(Off, VAddr: LongInt; Var Len: Integer): String;
Var Op, Op0, Op2, Op3, Rd, Rs1, Rs2, Imm, Target: LongInt; M: String;
Begin
 Len := 4;
 Op := GetDWordBEAt(Off);
 Op0 := (Op Shr 30) And 3; Rd := (Op Shr 25) And 31;
 If Op0 = 0 Then Begin
  Op2 := (Op Shr 22) And 7;
  If Op2 = 4 Then Begin
   Target := VAddr + (SignExtend(Op And $3FFFFF, 22) Shl 2);
   DecodeSPARC := 'sethi       %hi(' + HexFixed(Target,8) + '),' + SparcReg(Rd);
  End Else If Op2 = 2 Then Begin
   Target := VAddr + (SignExtend(Op And $3FFFFF, 22) Shl 2);
   DecodeSPARC := 'bicc        ' + HexFixed(Target,8);
  End Else DecodeSPARC := 'word        ' + HexFixed(Op,8) + 'h';
  Exit;
 End;
 If Op0 = 1 Then Begin
  Target := VAddr + (SignExtend(Op And $3FFFFFFF, 30) Shl 2);
  DecodeSPARC := 'call        ' + HexFixed(Target,8);
  Exit;
 End;
 Op3 := (Op Shr 19) And 63; Rs1 := (Op Shr 14) And 31; Rs2 := Op And 31;
 If (Op And $2000) <> 0 Then Imm := SignExtend(Op And $1FFF, 13)
 Else Imm := 0;
 If Op0 = 2 Then Begin
  Case Op3 Of
   0: M := 'add'; 4: M := 'sub'; 1: M := 'and'; 2: M := 'or'; 3: M := 'xor';
   32: M := 'taddcc'; 36: M := 'tsubcc';
  Else M := '';
  End;
  If M <> '' Then Begin
   If (Op And $2000) <> 0 Then DecodeSPARC := PadRight(M,12) + SparcReg(Rs1) + ',' + ImmText(Imm,4) + ',' + SparcReg(Rd)
   Else DecodeSPARC := PadRight(M,12) + SparcReg(Rs1) + ',' + SparcReg(Rs2) + ',' + SparcReg(Rd);
  End Else DecodeSPARC := 'word        ' + HexFixed(Op,8) + 'h';
 End Else Begin
  Case Op3 Of
   0: M := 'ld'; 4: M := 'st'; 1: M := 'ldub'; 5: M := 'stub'; 2: M := 'lduh'; 6: M := 'sth';
  Else M := '';
  End;
  If M <> '' Then Begin
   If (Op And $2000) <> 0 Then DecodeSPARC := PadRight(M,12) + '[' + SparcReg(Rs1) + DispText(Imm) + '],' + SparcReg(Rd)
   Else DecodeSPARC := PadRight(M,12) + '[' + SparcReg(Rs1) + '+' + SparcReg(Rs2) + '],' + SparcReg(Rd);
  End Else DecodeSPARC := 'word        ' + HexFixed(Op,8) + 'h';
 End;
End;

Function DecodeIA64(Off, VAddr: LongInt; Var Len: Integer): String;
Var T: Byte; Stop0, Stop1: Boolean; S: String;
Begin
 Len := 16;
 T := GetByteAt(Off) And 31;
 Stop0 := (GetByteAt(Off) And $20) <> 0;
 Stop1 := (GetByteAt(Off) And $40) <> 0;
 S := 'bundle      template=' + HexFixed(T,2) + 'h';
 If Stop0 Then S := S + ' stop0';
 If Stop1 Then S := S + ' stop1';
 S := S + ' raw=' + HexByte(GetByteAt(Off+15)) + HexByte(GetByteAt(Off+14)) +
  HexByte(GetByteAt(Off+13)) + HexByte(GetByteAt(Off+12)) + '...';
 DecodeIA64 := S;
End;

Procedure CmdDisasm;
Var I, L, J: Integer; Off, EndOff, V: LongInt; Mn: String;
Begin
 WriteLn('Dump of file ', FileName);
 WriteLn;
 If IsPE Then WriteLn('File Type: EXECUTABLE IMAGE')
 Else If IsCOFF Then WriteLn('File Type: COFF OBJECT')
 Else WriteLn('File Type: UNKNOWN');
 For I := 1 To SectionCount Do Begin
  If Not SectionMatches(Sections[I].Name) Then Continue;
  If (Sections[I].Chars And $20000000) = 0 Then Continue;
  WriteLn;
  WriteLn('  Section ', Sections[I].Name, ' contains the following code:');
  WriteLn;
  Off := Sections[I].RawPtr;
  EndOff := Off + Sections[I].RawSize;
  V := Sections[I].VAddr;
  While Off < EndOff Do Begin
   If (Machine = $01C0) Then Mn := DecodeARM32(Off, V, L)
   Else If (Machine = $01C4) Then Mn := DecodeThumb(Off, V, L)
   Else If (Machine = $AA64) Then Mn := DecodeARM64(Off, V, L)
   Else If (Machine = $8664) Then Mn := DecodeX64(Off, V, L)
   Else If (Machine = $0166) Then Mn := DecodeMIPS(Off, V, L)
   Else If (Machine = $01F0) Or (Machine = $01F2) Then Mn := DecodePowerPC(Off, V, L)
   Else If (Machine = $01A2) Or (Machine = $01A6) Then Mn := DecodeSuperH(Off, V, L)
   Else If (Machine = $0200) Then Mn := DecodeIA64(Off, V, L)
   Else If (Machine = $02A0) Then Mn := DecodeSPARC(Off, V, L)
   Else Mn := DecodeX86(Off, V, L);
   If L <= 0 Then L := 1;
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

Procedure CmdDelayImports(DependOnly: Boolean);
Var Off, Desc, Attr, NameRVA, INT_RVA, Thunk, NameOff: LongInt;
    DLL, Fn: String; IsOrd: Boolean; B: Byte;
Begin
 If (Not IsPE) Or (Dirs[IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT].RVA = 0) Then Exit;
 Off := RvaToOff(Dirs[IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT].RVA);
 If Off < 0 Then Exit;
 If Not DependOnly Then Begin
  WriteLn;
  WriteLn('Delay load imports');
 End;
 Desc := Off;
 While Desc + 32 <= BufSize Do Begin
  Attr := GetDWordAt(Desc);
  NameRVA := GetDWordAt(Desc + 4);
  INT_RVA := GetDWordAt(Desc + 16);
  If (Attr = 0) And (NameRVA = 0) And (INT_RVA = 0) Then Break;
  DLL := GetCStr(RvaToOff(NameRVA), 80);
  If DependOnly Then WriteLn('    ', DLL)
  Else Begin
   WriteLn;
   WriteLn('  ', DLL, ' (delay load)');
   Thunk := RvaToOff(INT_RVA);
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
    If IsOrd Then Fn := 'Ordinal ' + HexFixed(NameOff And $FFFF,4)
    Else Fn := GetCStr(RvaToOff(NameOff) + 2, 120);
    WriteLn('        ', Fn);
    If Is64 Then Inc(Thunk, 8) Else Inc(Thunk, 4);
   End;
  End;
  Inc(Desc, 32);
 End;
End;

Procedure CmdBoundImports;
Var Off, EndOff, P, NumFwd, I: LongInt; NameOff: Word; DLL: String;
Begin
 If (Not IsPE) Or (Dirs[IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT].RVA = 0) Then Exit;
 Off := RvaToOff(Dirs[IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT].RVA);
 If Off < 0 Then Exit;
 EndOff := Off + Dirs[IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT].Size;
 WriteLn;
 WriteLn('Bound imports');
 P := Off;
 While P + 8 <= EndOff Do Begin
  If (GetDWordAt(P) = 0) And (GetWordAt(P + 4) = 0) And
     (GetWordAt(P + 6) = 0) Then Break;
  NameOff := GetWordAt(P + 4);
  NumFwd := GetWordAt(P + 6);
  DLL := GetCStr(Off + NameOff, 80);
  WriteLn('  ', DLL, ' time ', HexFixed(GetDWordAt(P),8),
   ' forwarders ', NumFwd);
  Inc(P, 8);
  For I := 1 To NumFwd Do Begin
   If P + 8 > EndOff Then Break;
   DLL := GetCStr(Off + GetWordAt(P + 4), 80);
   WriteLn('    forwarder ', DLL, ' time ', HexFixed(GetDWordAt(P),8));
   Inc(P, 8);
  End;
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

 Function RelocName(T: Word): String;
 Begin
  Case Machine Of
   $014C: Case T Of
    $0000: RelocName := 'ABSOLUTE';
    $0006: RelocName := 'DIR32';
    $0007: RelocName := 'DIR32NB';
    $0014: RelocName := 'REL32';
   Else RelocName := 'I386_' + HexFixed(T,4); End;
   $8664: Case T Of
    $0000: RelocName := 'ABSOLUTE';
    $0001: RelocName := 'ADDR64';
    $0002: RelocName := 'ADDR32';
    $0003: RelocName := 'ADDR32NB';
    $0004: RelocName := 'REL32';
    $0005: RelocName := 'REL32_1';
    $0006: RelocName := 'REL32_2';
    $0007: RelocName := 'REL32_3';
    $0008: RelocName := 'REL32_4';
    $0009: RelocName := 'REL32_5';
    $000A: RelocName := 'SECTION';
    $000B: RelocName := 'SECREL';
    $000C: RelocName := 'SECREL7';
    $000D: RelocName := 'TOKEN';
    $000F: RelocName := 'PAIR';
    $0010: RelocName := 'SSPAN32';
   Else RelocName := 'AMD64_' + HexFixed(T,4); End;
   $01C0,$01C4: Case T Of
    $0000: RelocName := 'ABSOLUTE';
    $0001: RelocName := 'ADDR32';
    $0002: RelocName := 'ADDR32NB';
    $0003: RelocName := 'BRANCH24';
    $0004: RelocName := 'BRANCH11';
    $0006: RelocName := 'REL32';
    $0007: RelocName := 'SECTION';
    $0008: RelocName := 'SECREL';
    $0009: RelocName := 'MOV32A';
    $000A: RelocName := 'MOV32T';
    $000B: RelocName := 'BRANCH20T';
    $000C: RelocName := 'BRANCH24T';
    $000D: RelocName := 'BLX23T';
   Else RelocName := 'ARM_' + HexFixed(T,4); End;
   $AA64: Case T Of
    $0000: RelocName := 'ABSOLUTE';
    $0001: RelocName := 'ADDR32';
    $0002: RelocName := 'ADDR32NB';
    $0003: RelocName := 'BRANCH26';
    $0004: RelocName := 'PAGEBASE_REL21';
    $0005: RelocName := 'REL21';
    $0006: RelocName := 'PAGEOFFSET_12A';
    $0007: RelocName := 'PAGEOFFSET_12L';
    $0008: RelocName := 'SECREL';
    $0009: RelocName := 'SECREL_LOW12A';
    $000A: RelocName := 'SECREL_HIGH12A';
    $000B: RelocName := 'SECREL_LOW12L';
    $000C: RelocName := 'TOKEN';
    $000D: RelocName := 'SECTION';
    $000E: RelocName := 'ADDR64';
   Else RelocName := 'ARM64_' + HexFixed(T,4); End;
  Else RelocName := 'TYPE_' + HexFixed(T,4);
  End;
 End;
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
     HexFixed(GetDWordAt(P+4),8), ' type ', HexFixed(GetWordAt(P+8),4),
     ' ', RelocName(GetWordAt(P+8)));
    Inc(P, 10);
   End;
  End;
 End;
End;

Function UnwindOpName(Op: Byte): String;
Begin
 Case Op Of
  0: UnwindOpName := 'UWOP_PUSH_NONVOL';
  1: UnwindOpName := 'UWOP_ALLOC_LARGE';
  2: UnwindOpName := 'UWOP_ALLOC_SMALL';
  3: UnwindOpName := 'UWOP_SET_FPREG';
  4: UnwindOpName := 'UWOP_SAVE_NONVOL';
  5: UnwindOpName := 'UWOP_SAVE_NONVOL_FAR';
  8: UnwindOpName := 'UWOP_SAVE_XMM128';
  9: UnwindOpName := 'UWOP_SAVE_XMM128_FAR';
 10: UnwindOpName := 'UWOP_PUSH_MACHFRAME';
 Else UnwindOpName := 'UWOP_' + LToS(Op);
 End;
End;

Procedure DumpUnwindInfo(UnwindRVA: LongInt);
Var UOff: LongInt; VerFlags, Count, Frame, I, CodeOff: Integer;
    B1, B2, Op, Info: Byte; Extra: LongInt;
Begin
 UOff := RvaToOff(UnwindRVA);
 If UOff < 0 Then Begin
  WriteLn('    Unwind info invalide.');
  Exit;
 End;
 VerFlags := GetByteAt(UOff);
 Count := GetByteAt(UOff + 2);
 Frame := GetByteAt(UOff + 3);
 WriteLn('    Version ', VerFlags And 7, ' Flags ', HexFixed(VerFlags Shr 3,2),
  ' Prolog ', GetByteAt(UOff + 1), ' Codes ', Count,
  ' FrameReg ', Frame And 15, ' FrameOff ', Frame Shr 4);
 I := 0;
 CodeOff := UOff + 4;
 While I < Count Do Begin
  B1 := GetByteAt(CodeOff + I * 2);
  B2 := GetByteAt(CodeOff + I * 2 + 1);
  Op := B2 And 15;
  Info := B2 Shr 4;
  Write('      ', PadRight(UnwindOpName(Op), 22),
   ' offset ', HexFixed(B1,2), ' info ', Info);
  Extra := 0;
  If (Op = 1) And (Info = 0) And (I + 1 < Count) Then Begin
   Inc(I);
   Extra := GetWordAt(CodeOff + I * 2) * 8;
   Write(' size ', Extra);
  End Else If (Op = 1) And (Info = 1) And (I + 2 < Count) Then Begin
   Inc(I);
   Extra := GetWordAt(CodeOff + I * 2);
   Inc(I);
   Extra := Extra Or (LongInt(GetWordAt(CodeOff + I * 2)) Shl 16);
   Write(' size ', Extra);
  End Else If Op = 2 Then
   Write(' size ', (Info * 8) + 8)
  Else If ((Op = 4) Or (Op = 8)) And (I + 1 < Count) Then Begin
   Inc(I);
   Extra := GetWordAt(CodeOff + I * 2) * 8;
   Write(' stackoff ', Extra);
  End Else If ((Op = 5) Or (Op = 9)) And (I + 2 < Count) Then Begin
   Inc(I);
   Extra := GetWordAt(CodeOff + I * 2);
   Inc(I);
   Extra := Extra Or (LongInt(GetWordAt(CodeOff + I * 2)) Shl 16);
   Write(' stackoff ', Extra);
  End;
  WriteLn;
  Inc(I);
 End;
End;

Procedure CmdPData;
Var Off, EndOff, BeginRVA, EndRVA, UnwindRVA: LongInt;
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
  BeginRVA := GetDWordAt(Off);
  EndRVA := GetDWordAt(Off + 4);
  UnwindRVA := GetDWordAt(Off + 8);
  WriteLn('  Begin ', HexFixed(BeginRVA,8), ' End ',
   HexFixed(EndRVA,8), ' Unwind ', HexFixed(UnwindRVA,8));
  If (Machine = $8664) Or (Machine = $AA64) Then DumpUnwindInfo(UnwindRVA);
  Inc(Off, 12);
 End;
End;

Function MetaString(StrOff, Idx: LongInt): String;
Begin
 If Idx <= 0 Then MetaString := ''
 Else MetaString := GetCStr(StrOff + Idx, 120);
End;

Function ILName(Op: Word): String;
Begin
 Case Op Of
  $00: ILName := 'nop';
  $02: ILName := 'ldarg.0';
  $03: ILName := 'ldarg.1';
  $04: ILName := 'ldarg.2';
  $05: ILName := 'ldarg.3';
  $06: ILName := 'ldloc.0';
  $07: ILName := 'ldloc.1';
  $08: ILName := 'ldloc.2';
  $09: ILName := 'ldloc.3';
  $0A: ILName := 'stloc.0';
  $0B: ILName := 'stloc.1';
  $0C: ILName := 'stloc.2';
  $0D: ILName := 'stloc.3';
  $0E: ILName := 'ldarg.s';
  $11: ILName := 'ldloc.s';
  $13: ILName := 'stloc.s';
  $14: ILName := 'ldnull';
  $15: ILName := 'ldc.i4.m1';
  $16: ILName := 'ldc.i4.0';
  $17: ILName := 'ldc.i4.1';
  $18: ILName := 'ldc.i4.2';
  $19: ILName := 'ldc.i4.3';
  $1A: ILName := 'ldc.i4.4';
  $1B: ILName := 'ldc.i4.5';
  $1C: ILName := 'ldc.i4.6';
  $1D: ILName := 'ldc.i4.7';
  $1E: ILName := 'ldc.i4.8';
  $1F: ILName := 'ldc.i4.s';
  $20: ILName := 'ldc.i4';
  $28: ILName := 'call';
  $2A: ILName := 'ret';
  $2B: ILName := 'br.s';
  $2C: ILName := 'brfalse.s';
  $2D: ILName := 'brtrue.s';
  $38: ILName := 'br';
  $39: ILName := 'brfalse';
  $3A: ILName := 'brtrue';
  $58: ILName := 'add';
  $59: ILName := 'sub';
  $5A: ILName := 'mul';
  $5B: ILName := 'div';
  $6F: ILName := 'callvirt';
  $72: ILName := 'ldstr';
  $7B: ILName := 'ldfld';
  $7D: ILName := 'stfld';
  $7E: ILName := 'ldsfld';
  $80: ILName := 'stsfld';
  $8C: ILName := 'box';
  $8D: ILName := 'newarr';
  $A2: ILName := 'stelem.ref';
  $A3: ILName := 'ldelem';
  $FE01: ILName := 'ceq';
  $FE02: ILName := 'cgt';
  $FE03: ILName := 'cgt.un';
  $FE04: ILName := 'clt';
  $FE09: ILName := 'ldarg';
  $FE0A: ILName := 'ldarga';
  $FE0B: ILName := 'starg';
  $FE0C: ILName := 'ldloc';
  $FE0D: ILName := 'ldloca';
  $FE0E: ILName := 'stloc';
 Else ILName := 'il_' + HexFixed(Op,4);
 End;
End;

Function ILOperandSize(Op: Word): Integer;
Begin
 Case Op Of
  $0E,$11,$13,$1F,$2B,$2C,$2D: ILOperandSize := 1;
  $20,$28,$38,$39,$3A,$6F,$72,$7B,$7D,$7E,$80,$8C,$8D,$A3: ILOperandSize := 4;
  $FE09,$FE0A,$FE0B,$FE0C,$FE0D,$FE0E: ILOperandSize := 2;
 Else ILOperandSize := 0;
 End;
End;

Function CLRTokenName(Token: LongInt): String;
Var Tbl, Idx: LongInt;
Begin
 Tbl := (Token Shr 24) And $FF;
 Idx := Token And $00FFFFFF;
 Case Tbl Of
  $02: If (Idx >= 1) And (Idx <= ClrTypeCount) Then
        CLRTokenName := ClrTypeNames[Idx]
       Else CLRTokenName := 'TypeDef:' + LToS(Idx);
  $06: If (Idx >= 1) And (Idx <= ClrMethodCount) Then
        CLRTokenName := ClrMethodNames[Idx]
       Else CLRTokenName := 'MethodDef:' + LToS(Idx);
  $0A: If (Idx >= 1) And (Idx <= ClrMemberRefCount) Then
        CLRTokenName := ClrMemberRefs[Idx]
       Else CLRTokenName := 'MemberRef:' + LToS(Idx);
 Else CLRTokenName := '';
 End;
End;

Procedure DisasmIL(CodeOff, CodeSize: LongInt);
Var P, EndP, Rel: LongInt; B: Byte; Op: Word; OSz: Integer; Operand: LongInt;
    TokName: String;
Begin
 P := CodeOff; EndP := CodeOff + CodeSize;
 While P < EndP Do Begin
  Rel := P - CodeOff;
  B := GetByteAt(P); Inc(P);
  If B = $FE Then Begin Op := $FE00 Or GetByteAt(P); Inc(P); End
  Else Op := B;
  OSz := ILOperandSize(Op);
  Operand := 0;
  If OSz = 1 Then Operand := SignedByte(GetByteAt(P))
  Else If OSz = 2 Then Operand := GetWordAt(P)
  Else If OSz = 4 Then Operand := GetDWordAt(P);
  Write('    IL_', HexFixed(Rel,4), ': ', PadRight(ILName(Op), 12));
  If OSz > 0 Then Begin
   Write(HexFixed(Operand, OSz * 2));
   If OSz = 4 Then Begin
    TokName := CLRTokenName(Operand);
    If TokName <> '' Then Write(' // ', TokName);
   End;
  End;
  WriteLn;
  Inc(P, OSz);
 End;
End;

Function MdIndexSize(Rows: LongInt): Integer;
Begin
 If Rows < 65536 Then MdIndexSize := 2 Else MdIndexSize := 4;
End;

Function MdCoded2(A, B: LongInt): Integer;
Begin
 If (A < 16384) And (B < 16384) Then MdCoded2 := 2 Else MdCoded2 := 4;
End;

Function MdCoded3(A, B, C: LongInt): Integer;
Begin
 If (A < 16384) And (B < 16384) And (C < 16384) Then MdCoded3 := 2
 Else MdCoded3 := 4;
End;

Function MdCoded4(A, B, C, D: LongInt): Integer;
Begin
 If (A < 16384) And (B < 16384) And (C < 16384) And (D < 16384) Then MdCoded4 := 2
 Else MdCoded4 := 4;
End;

Function MdTableRowSize(T: Integer; StrSz, GuidSz, BlobSz: Integer;
 Var Rows: Array Of LongInt): Integer;
Begin
 Case T Of
  0: MdTableRowSize := 2 + StrSz + GuidSz + GuidSz + GuidSz;
  1: MdTableRowSize := MdCoded4(Rows[0],Rows[26],Rows[35],Rows[1]) + StrSz + StrSz;
  2: MdTableRowSize := 4 + StrSz + StrSz + MdCoded3(Rows[2],Rows[1],Rows[27]) +
       MdIndexSize(Rows[4]) + MdIndexSize(Rows[6]);
  3: MdTableRowSize := MdIndexSize(Rows[4]);
  4: MdTableRowSize := 2 + StrSz + BlobSz;
  5: MdTableRowSize := MdIndexSize(Rows[6]);
  6: MdTableRowSize := 8 + StrSz + BlobSz + MdIndexSize(Rows[8]);
 Else MdTableRowSize := 0;
 End;
End;

Procedure CmdCLRMetadata(MetaOff: LongInt);
Var VerLen, Streams, I, P, NameP, StreamOff, StreamSize: LongInt;
    Name: String; TblOff, StrOff, HeapSizes, Present, CountPresent: LongInt;
    Rows: Array[0..63] Of LongInt; T, DataOff, TypeOff, MethodOff, MemberRefOff, MethodRowSize: LongInt;
    StrSz, GuidSz, BlobSz, NameIdx, MethodRVA, BodyOff, Header, CodeSize, CodeOff: LongInt;
    RowSize, ClassSize, SigSize: LongInt;
Begin
 If (MetaOff < 0) Or (MetaOff + 16 >= BufSize) Then Exit;
 If GetDWordAt(MetaOff) <> $424A5342 Then Begin
  WriteLn('METADATA CLR invalide.');
  Exit;
 End;
 VerLen := GetDWordAt(MetaOff + 12);
 Streams := GetWordAt(MetaOff + 16 + VerLen + 2);
 P := MetaOff + 16 + VerLen + 4;
 TblOff := -1; StrOff := -1;
 WriteLn;
 WriteLn('CLR METADATA STREAMS');
 For I := 0 To Streams - 1 Do Begin
  StreamOff := GetDWordAt(P);
  StreamSize := GetDWordAt(P + 4);
  NameP := P + 8;
  Name := GetCStr(NameP, 32);
  WriteLn('  ', PadRight(Name,12), ' off ', HexFixed(StreamOff,8),
   ' size ', HexFixed(StreamSize,8));
  If (Name = '#~') Or (Name = '#-') Then TblOff := MetaOff + StreamOff
  Else If Name = '#Strings' Then StrOff := MetaOff + StreamOff;
  P := NameP + Length(Name) + 1;
  While (P Mod 4) <> 0 Do Inc(P);
 End;
 If TblOff < 0 Then Exit;
 HeapSizes := GetByteAt(TblOff + 6);
 If (HeapSizes And 1) <> 0 Then StrSz := 4 Else StrSz := 2;
 If (HeapSizes And 2) <> 0 Then GuidSz := 4 Else GuidSz := 2;
 If (HeapSizes And 4) <> 0 Then BlobSz := 4 Else BlobSz := 2;
 Present := GetDWordAt(TblOff + 8);
 For T := 0 To 63 Do Rows[T] := 0;
 ClrTypeCount := 0; ClrMethodCount := 0; ClrMemberRefCount := 0;
 P := TblOff + 24;
 CountPresent := 0;
 For T := 0 To 63 Do
  If (T < 31) And ((Present And (LongInt(1) Shl T)) <> 0) Then Begin
   Rows[T] := GetDWordAt(P);
   Inc(P,4);
   Inc(CountPresent);
  End;
 WriteLn;
 WriteLn('CLR METADATA TABLES');
 For T := 0 To 63 Do If Rows[T] <> 0 Then
  WriteLn('  Table ', PadLeft(LToS(T),2), ' rows ', Rows[T]);
 DataOff := P;
 TypeOff := DataOff;
 For T := 0 To 1 Do
  If Rows[T] <> 0 Then Inc(TypeOff, Rows[T] * MdTableRowSize(T, StrSz, GuidSz, BlobSz, Rows));
 If Rows[2] > 0 Then Begin
  RowSize := MdTableRowSize(2, StrSz, GuidSz, BlobSz, Rows);
  ClrTypeCount := Rows[2];
  If ClrTypeCount > MaxClrNames Then ClrTypeCount := MaxClrNames;
  For I := 0 To ClrTypeCount - 1 Do Begin
   P := TypeOff + I * RowSize;
   If StrSz = 2 Then NameIdx := GetWordAt(P + 4)
   Else NameIdx := GetDWordAt(P + 4);
   ClrTypeNames[I + 1] := MetaString(StrOff, NameIdx);
  End;
 End;
 MethodOff := DataOff;
 For T := 0 To 5 Do
  If Rows[T] <> 0 Then
   Inc(MethodOff, Rows[T] * MdTableRowSize(T, StrSz, GuidSz, BlobSz, Rows));
 MethodRowSize := MdTableRowSize(6, StrSz, GuidSz, BlobSz, Rows);
 If Rows[6] > 0 Then Begin
  ClrMethodCount := Rows[6];
  If ClrMethodCount > MaxClrNames Then ClrMethodCount := MaxClrNames;
  For I := 0 To ClrMethodCount - 1 Do Begin
   P := MethodOff + I * MethodRowSize;
   If StrSz = 2 Then NameIdx := GetWordAt(P + 8)
   Else NameIdx := GetDWordAt(P + 8);
   ClrMethodNames[I + 1] := MetaString(StrOff, NameIdx);
  End;
 End;
 MemberRefOff := DataOff;
 For T := 0 To 9 Do
  If Rows[T] <> 0 Then Begin
   If T = 7 Then RowSize := 2 + MdIndexSize(Rows[4])
   Else If T = 8 Then RowSize := 2 + MdIndexSize(Rows[6])
   Else If T = 9 Then RowSize := MdIndexSize(Rows[2]) + MdIndexSize(Rows[4])
   Else RowSize := MdTableRowSize(T, StrSz, GuidSz, BlobSz, Rows);
   Inc(MemberRefOff, Rows[T] * RowSize);
  End;
 If Rows[10] > 0 Then Begin
  ClrMemberRefCount := Rows[10];
  If ClrMemberRefCount > MaxClrNames Then ClrMemberRefCount := MaxClrNames;
  ClassSize := MdCoded4(Rows[2], Rows[1], Rows[26], Rows[6]);
  SigSize := BlobSz;
  For I := 0 To ClrMemberRefCount - 1 Do Begin
   P := MemberRefOff + I * (ClassSize + StrSz + SigSize);
   If StrSz = 2 Then NameIdx := GetWordAt(P + ClassSize)
   Else NameIdx := GetDWordAt(P + ClassSize);
   ClrMemberRefs[I + 1] := MetaString(StrOff, NameIdx);
  End;
 End;
 If (Rows[6] = 0) Or (MethodRowSize = 0) Then Exit;
 WriteLn;
 WriteLn('CLR METHODS / IL');
 For I := 0 To Rows[6] - 1 Do Begin
  P := MethodOff + I * MethodRowSize;
  MethodRVA := GetDWordAt(P);
  If StrSz = 2 Then NameIdx := GetWordAt(P + 8)
  Else NameIdx := GetDWordAt(P + 8);
  WriteLn('  ', HexFixed(MethodRVA,8), ' ', MetaString(StrOff, NameIdx));
  BodyOff := RvaToOff(MethodRVA);
  If BodyOff >= 0 Then Begin
   Header := GetByteAt(BodyOff);
   If (Header And 3) = 2 Then Begin
    CodeSize := Header Shr 2;
    CodeOff := BodyOff + 1;
   End Else Begin
    CodeSize := GetDWordAt(BodyOff + 4);
    CodeOff := BodyOff + ((Header Shr 4) * 4);
   End;
   If (CodeSize > 0) And (CodeSize < 65536) Then DisasmIL(CodeOff, CodeSize);
  End;
 End;
End;

Procedure CmdCLRHeader;
Var Off, MetaOff: LongInt;
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
 MetaOff := RvaToOff(GetDWordAt(Off + 8));
 CmdCLRMetadata(MetaOff);
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
 If IsPDB Then Begin
  DumpPdbLines;
  Exit;
 End;
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

Function ArchiveMemberName(Off: LongInt): String;
Var I: Integer; C: Byte; S: String;
Begin
 S := '';
 For I := 0 To 15 Do Begin
  C := GetByteAt(Off + I);
  If C > 32 Then S := S + Chr(C);
 End;
 ArchiveMemberName := S;
End;

Function ArchiveMemberSize(Off: LongInt): LongInt;
Var I, Code: Integer; C: Byte; S: String; V: LongInt;
Begin
 S := '';
 For I := 48 To 57 Do Begin
  C := GetByteAt(Off + I);
  If C > 32 Then S := S + Chr(C);
 End;
 Val(S, V, Code);
 If Code <> 0 Then V := 0;
 ArchiveMemberSize := V;
End;

Procedure DumpArchiveLinkerMember(Off, Size: LongInt; IndexNo: Integer);
Var P, Count, I, SymIndex, MemberCount, FirstSym: LongInt;
    Name: String;
Begin
 If Size <= 4 Then Exit;
 WriteLn;
 WriteLn('Linker member ', IndexNo, ' at archive offset ', HexFixed(Off,8));
 If IndexNo = 1 Then Begin
  Count := GetDWordBEAt(Off + 60);
  WriteLn('  Symbol count: ', Count);
  P := Off + 64 + Count * 4;
  For I := 0 To Count - 1 Do Begin
   Name := GetCStr(P, 120);
   WriteLn('    ', PadLeft(LToS(I),5), ' member ',
    HexFixed(GetDWordBEAt(Off + 64 + I * 4),8), ' ', Name);
   Inc(P, Length(Name) + 1);
   If P >= Off + 60 + Size Then Break;
  End;
 End Else Begin
  MemberCount := GetDWordAt(Off + 60);
  FirstSym := Off + 64 + MemberCount * 4;
  Count := GetDWordAt(FirstSym);
  WriteLn('  Member count: ', MemberCount);
  WriteLn('  Symbol count: ', Count);
  P := FirstSym + 4 + Count * 2;
  For I := 0 To Count - 1 Do Begin
   SymIndex := GetWordAt(FirstSym + 4 + I * 2);
   Name := GetCStr(P, 120);
   WriteLn('    ', PadLeft(LToS(I),5), ' member-index ',
    SymIndex, ' ', Name);
   Inc(P, Length(Name) + 1);
   If P >= Off + 60 + Size Then Break;
  End;
 End;
End;

Procedure CmdArchiveMembers(Linker: Boolean);
Var Off, Size, I: LongInt; Name, Sz: String; C: Byte; LinkNo: Integer;
Begin
 If Not IsArchive Then Begin
  WriteLn('Ce fichier n''est pas une bibliotheque COFF archive.');
  Exit;
 End;
 Off := 8;
 LinkNo := 0;
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
  If (Not Linker) Or (Name <> '/') Then
   WriteLn('  ', PadRight(Name,24), ' ', Size, ' bytes');
  If Linker And (Name = '/') Then Begin
   Inc(LinkNo);
   DumpArchiveLinkerMember(Off, Size, LinkNo);
  End;
  Off := Off + 60 + Size;
  If (Off And 1) <> 0 Then Inc(Off);
 End;
End;

Procedure Help;Begin
 WriteLn('DUMPBIN clone - Cette commande permet d''analyser et d''afficher en detail le contenu des fichiers ',
         'binaires Windows, tels que les executables (.exe), les bibliotheques dynamiques (.dll), les fichiers ',
         'objets (.obj) et les bibliotheques statiques (.lib), afin d''en examiner les en-tetes, les symboles, ',
         'les importations, les exportations, les informations PDB et le code machine.');
 WriteLn;
 WriteLn('Syntaxe: DUMPBIN /OPTION fichier.exe');
 WriteLn('        DUMPBIN fichier.pdb');
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
 If Not (IsPE Or IsCOFF Or IsArchive Or IsPDB) Then Begin
  WriteLn('DUMPBIN: format non reconnu (PE/COFF/.lib/.pdb attendu).');
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
 If OptDependents Then Begin
  WriteLn('Image has the following dependencies:');
  CmdImports(True);
  CmdDelayImports(True);
 End;
 If OptImports Then Begin
  CmdImports(False);
  CmdDelayImports(False);
  CmdBoundImports;
 End;
 If OptExports Then CmdExports;
 If OptDirectives Then CmdDirectives;
 If OptSymbols Then Begin
  If IsPDB Then CmdPDBSymbols Else CmdSymbols;
 End;
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
