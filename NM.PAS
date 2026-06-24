{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Clone de l outil GNU "nm" (binutils) : affiche la table
    des symboles d un fichier objet, d une bibliotheque statique ou d un
    executable, avec leur adresse, leur taille et leur type (texte,
    donnees, BSS, indefini, absolu, faible...).

    Formats reconnus : ELF32/ELF64 (Linux), PE32/PE32+ et fichier objet
    COFF brut .o/.obj (Windows/MinGW), Mach-O 32/64 bits (macOS, dont
    "fat"/universel), bibliotheque statique "ar" (.a, chaque membre
    traite comme un fichier independant, comme le ferait "nm" reel).
    EXE DOS (MZ), ROM NES et binaires bruts n ont pas de table de
    symboles exploitable et sont explicitement signales comme tels.

    La classification des symboles (lettre de type) est un sous-
    ensemble pratique de celle du vrai nm : T/t (code), D/d (donnees
    initialisees), B/b (BSS), R/r (lecture seule), A/a (absolu),
    U (indefini), W/w (faible, defini/indefini), C (commun) ; les cas
    plus rares du vrai nm (symboles indirects "i", "u" unique global,
    petites donnees "g"/"S", stabs "-") ne sont pas distingues et
    retombent sur "?" ou la lettre la plus proche.

    Le demangleur C++ (-C) est le meme sous-ensemble Itanium ABI que
    celui d OBJDUMP.PAS (noms imbriques + types de parametres natifs,
    sans compression de substitution S_/S0_). }

Program NM;

{$A-}
{$I-}
{$R-}

Const
 MaxSections = 4096;
 MaxSymbols  = 32768;
 MaxArchiveMembers = 2048;

 FMT_UNKNOWN = 0;
 FMT_ELF32   = 1;
 FMT_ELF64   = 2;
 FMT_PE32    = 3;
 FMT_PE64    = 4;
 FMT_MACHO32 = 5;
 FMT_MACHO64 = 6;
 FMT_COFFOBJ = 7;
 FMT_ARCHIVE = 8;
 FMT_MZ      = 9;
 FMT_NES     = 10;
 FMT_RAW     = 11;

 { Mach-O : constantes magiques (typees LongInt explicitement car leur
   bit de poids fort en ferait des valeurs hors plage pour un entier
   signe non type, comme dans OBJDUMP.PAS). }
 MH_MAGIC      : LongInt = LongInt($FEEDFACE);
 MH_MAGIC_64   : LongInt = LongInt($FEEDFACF);
 MH_CIGAM      : LongInt = LongInt($CEFAEDFE);
 MH_CIGAM_64   : LongInt = LongInt($CFFAEDFE);
 FAT_MAGIC     : LongInt = LongInt($CAFEBABE);
 FAT_CIGAM     : LongInt = LongInt($BEBAFECA);
 LC_SEGMENT    = $00000001;
 LC_SYMTAB     = $00000002;
 LC_SEGMENT_64 = $00000019;

 { ELF : indices de section speciaux (champ st_shndx) }
 SHN_UNDEF  = 0;
 SHN_ABS    = $FFF1;
 SHN_COMMON = $FFF2;

Type
 String64 = String[64];

 TSection = Record
  Name      : String[32];
  VAddr     : LongInt;
  FileOff   : LongInt;
  Size      : LongInt;
  IsCode    : Boolean;
  IsBss     : Boolean;
  IsWritable: Boolean;
 End;

 TNmSymbol = Record
  Name     : String64;
  Value    : LongInt;
  SizeVal  : LongInt;
  SecIdx   : Integer;   { 1-based dans Sections[], 0 = aucune }
  IsUndef  : Boolean;
  IsAbs    : Boolean;
  IsCommon : Boolean;
  IsWeak   : Boolean;
  IsGlobal : Boolean;
  TypeChar : Char;
 End;

 TArchiveMember = Record
  Name     : String[200];
  DataOff  : LongInt;
  DataSize : LongInt;
 End;

 TByteBuf = Array[0..0] Of Byte;
 PByteBuf = ^TByteBuf;

Var
 Buf          : PByteBuf;
 BufSize      : LongInt;
 BinFormat    : Integer;
 InFileName   : String;
 ImageBase    : LongInt;
 MachOBase    : LongInt;
 ElfBigEndian : Boolean;
 Sections     : Array[1..MaxSections] Of TSection;
 SectionCount : Integer;
 Symbols      : Array[1..MaxSymbols] Of TNmSymbol;
 SymbolCount  : Integer;
 ArchiveMembers     : Array[1..MaxArchiveMembers] Of TArchiveMember;
 ArchiveMemberCount : Integer;

 { Options CLI }
 OptDemangle      : Boolean; { -C / --demangle }
 OptExternOnly    : Boolean; { -g / --extern-only }
 OptUndefinedOnly : Boolean; { -u / --undefined-only }
 OptNumericSort   : Boolean; { -n / --numeric-sort }
 OptNoSort        : Boolean; { -p / --no-sort }
 OptReverseSort   : Boolean; { -r / --reverse-sort }
 OptSizeSort      : Boolean; { --size-sort }
 OptPrintSize     : Boolean; { -S / --print-size }
 OptPrintFileName : Boolean; { -A / --print-file-name }
 OptPrintArmap    : Boolean; { -s / --print-armap }
 OptRadix         : Char;    { -t : 'x' (defaut), 'd', 'o' }
 OutFormat        : Integer; { 0=bsd (defaut), 1=sysv, 2=posix }
 CurFileLabel     : String;  { nom affiche par -A (fichier ou fichier(membre)) }
 InArchiveMember  : Boolean; { vrai pendant le traitement d un membre .a,
                               pour afficher l en-tete "archive[membre]:" }

{ ============================================================
  UTILITAIRES GENERAUX
  ============================================================ }

Function UpStr(S: String): String;
Var
 I: Integer;
Begin
 For I := 1 To Length(S) Do
  If S[I] In ['a'..'z'] Then S[I] := Chr(Ord(S[I]) - 32);
 UpStr := S;
End;

Function StartsWithStr(S, Prefix: String): Boolean;
Begin
 StartsWithStr := Copy(S, 1, Length(Prefix)) = Prefix;
End;

Function PadRight(S: String; W: Integer): String;
Begin
 While Length(S) < W Do S := S + ' ';
 PadRight := S;
End;

Function HexByte(B: Byte): String;
Const
 Digits: Array[0..15] Of Char = '0123456789abcdef';
Begin
 HexByte := Digits[(B Shr 4) And 15] + Digits[B And 15];
End;

Function ToHexU(V: LongInt): String;
Var
 B: Array[0..3] Of Byte;
 I: Integer;
 S: String;
 Started: Boolean;
Begin
 Move(V, B, 4);
 S := '';
 Started := False;
 For I := 3 DownTo 0 Do Begin
  If Started Then
   S := S + HexByte(B[I])
  Else If B[I] <> 0 Then Begin
   If (B[I] Shr 4) <> 0 Then S := S + HexByte(B[I])
   Else S := S + HexByte(B[I] And 15);
   Started := True;
  End;
 End;
 If S = '' Then S := '0';
 ToHexU := S;
End;

Function ToHexFixed(V: LongInt; Digits: Integer): String;
Var
 S: String;
Begin
 S := ToHexU(V);
 While Length(S) < Digits Do S := '0' + S;
 ToHexFixed := S;
End;

Function ToOctFixed(V: LongInt; Digits: Integer): String;
Var
 S: String;
 U: LongInt;
 D: Integer;
Begin
 S := '';
 U := V;
 If U = 0 Then S := '0';
 While U <> 0 Do Begin
  D := U And 7;
  S := Chr(Ord('0') + D) + S;
  U := (U Shr 3) And $1FFFFFFF;
 End;
 While Length(S) < Digits Do S := '0' + S;
 ToOctFixed := S;
End;

Function ToDecFixed(V: LongInt; Digits: Integer): String;
Var
 S: String;
Begin
 Str(V, S);
 While Length(S) < Digits Do S := '0' + S;
 ToDecFixed := S;
End;

{ @description: Formate V selon le radix actif (-t), toujours sur
    8 chiffres (16 pour x si la valeur l exige), comme le vrai nm.
  @param V Valeur a formater
  @return Texte forme selon OptRadix }
Function FormatRadix(V: LongInt): String;
Begin
 Case OptRadix Of
  'd': FormatRadix := ToDecFixed(V, 8);
  'o': FormatRadix := ToOctFixed(V, 8);
 Else
  FormatRadix := ToHexFixed(V, 8);
 End;
End;

Function IntToStr(N: LongInt): String;
Var
 S: String;
Begin
 Str(N, S);
 IntToStr := S;
End;

{ ============================================================
  LECTURE BAS NIVEAU DU TAMPON FICHIER
  ============================================================ }

Function GetByte(Off: LongInt): Byte;
Begin
 If (Off < 0) Or (Off >= BufSize) Then GetByte := 0
 Else GetByte := Buf^[Off];
End;

Function GetWord(Off: LongInt): Word;
Begin
 GetWord := GetByte(Off) Or (GetByte(Off + 1) Shl 8);
End;

Function GetDWord(Off: LongInt): LongInt;
Var
 B: Array[0..3] Of Byte;
 I: Integer;
 R: LongInt;
Begin
 For I := 0 To 3 Do B[I] := GetByte(Off + I);
 Move(B, R, 4);
 GetDWord := R;
End;

Function GetDWordBE(Off: LongInt): LongInt;
Var
 B: Array[0..3] Of Byte;
 I: Integer;
 R: LongInt;
Begin
 For I := 0 To 3 Do B[3 - I] := GetByte(Off + I);
 Move(B, R, 4);
 GetDWordBE := R;
End;

Function GetWordBE(Off: LongInt): Word;
Begin
 GetWordBE := (GetByte(Off) Shl 8) Or GetByte(Off + 1);
End;

{ @description: Lecteurs "endian-aware" pour ELF (gros-boutiste
    possible, voir ElfBigEndian, detecte depuis EI_DATA). }
Function GetElfWord(Off: LongInt): Word;
Begin
 If ElfBigEndian Then GetElfWord := GetWordBE(Off)
 Else GetElfWord := GetWord(Off);
End;

Function GetElfDWord(Off: LongInt): LongInt;
Begin
 If ElfBigEndian Then GetElfDWord := GetDWordBE(Off)
 Else GetElfDWord := GetDWord(Off);
End;

Function GetElfQWordLow(Off: LongInt): LongInt;
Begin
 If ElfBigEndian Then GetElfQWordLow := GetDWordBE(Off + 4)
 Else GetElfQWordLow := GetDWord(Off);
End;

Function GetCStr(Off: LongInt; MaxLen: Integer): String;
Var
 S: String;
 B: Byte;
Begin
 S := '';
 While Length(S) < MaxLen Do Begin
  B := GetByte(Off + Length(S));
  If B = 0 Then Break;
  S := S + Chr(B);
 End;
 GetCStr := S;
End;

{ @description: Comme GetCStr, mais pour la table des noms longs
    "ar" ("//"), ou chaque entree est terminee par "/" (et non par
    un octet nul). }
Function GetArName(Off: LongInt; MaxLen: Integer): String;
Var
 S: String;
 B: Byte;
Begin
 S := '';
 While Length(S) < MaxLen Do Begin
  B := GetByte(Off + Length(S));
  If (B = Ord('/')) Or (B = 10) Or (B = 0) Then Break;
  S := S + Chr(B);
 End;
 GetArName := S;
End;

Procedure LoadFile(FName: String);
Var
 F: File;
 NRead: LongInt;
Begin
 Assign(F, FName);
 FileMode := 0;
 {$I-} Reset(F, 1); {$I+}
 If IOResult <> 0 Then Begin
  WriteLn('nm: ''', FName, ''': impossible d''ouvrir le fichier');
  Halt(1);
 End;
 BufSize := FileSize(F);
 If BufSize <= 0 Then Begin
  WriteLn('nm: ''', FName, ''': fichier vide ou taille illisible');
  Close(F);
  Halt(1);
 End;
 GetMem(Buf, BufSize);
 {$I-} BlockRead(F, Buf^, BufSize, NRead); {$I+}
 Close(F);
 If NRead <> BufSize Then Begin
  WriteLn('nm: ''', FName, ''': lecture incomplete du fichier');
  Halt(1);
 End;
End;

{ ============================================================
  DETECTION DU FORMAT
  ============================================================ }

Procedure DetectFormat;
Var
 PEOff: LongInt;
 Magic: LongInt;
 CoffMachine, CoffNSec, CoffSizeOpt: Integer;
Begin
 BinFormat := FMT_UNKNOWN;
 MachOBase := 0;
 If BufSize < 4 Then Exit;
 If (BufSize >= 8) And (GetByte(0) = Ord('!')) And (GetByte(1) = Ord('<')) And
    (GetByte(2) = Ord('a')) And (GetByte(3) = Ord('r')) And
    (GetByte(4) = Ord('c')) And (GetByte(5) = Ord('h')) And
    (GetByte(6) = Ord('>')) And (GetByte(7) = 10) Then Begin
  BinFormat := FMT_ARCHIVE;
  Exit;
 End;
 If (GetByte(0) = $7F) And (GetByte(1) = Ord('E')) And
    (GetByte(2) = Ord('L')) And (GetByte(3) = Ord('F')) Then Begin
  If GetByte(4) = 2 Then BinFormat := FMT_ELF64 Else BinFormat := FMT_ELF32;
  Exit;
 End;
 If (GetByte(0) = Ord('M')) And (GetByte(1) = Ord('Z')) Then Begin
  If BufSize > $40 Then Begin
   PEOff := GetDWord($3C);
   If (PEOff > 0) And (PEOff + 24 < BufSize) Then Begin
    If (GetByte(PEOff) = Ord('P')) And (GetByte(PEOff + 1) = Ord('E')) And
       (GetByte(PEOff + 2) = 0) And (GetByte(PEOff + 3) = 0) Then Begin
     If GetWord(PEOff + 24) = $20B Then BinFormat := FMT_PE64
     Else BinFormat := FMT_PE32;
     Exit;
    End;
   End;
  End;
  BinFormat := FMT_MZ;
  Exit;
 End;
 If (GetByte(0) = Ord('N')) And (GetByte(1) = Ord('E')) And
    (GetByte(2) = Ord('S')) And (GetByte(3) = $1A) Then Begin
  BinFormat := FMT_NES;
  Exit;
 End;
 Magic := GetDWord(0);
 If Magic = MH_MAGIC_64 Then Begin BinFormat := FMT_MACHO64; Exit; End;
 If Magic = MH_MAGIC Then Begin BinFormat := FMT_MACHO32; Exit; End;
 If (Magic = MH_CIGAM) Or (Magic = MH_CIGAM_64) Then Begin
  WriteLn('nm: Mach-O gros-boutiste (PowerPC) non supporte.');
  Halt(1);
 End;
 If GetDWordBE(0) = FAT_MAGIC Then Begin
  { Binaire universel : on choisit la premiere tranche, par
    simplicite (contrairement a OBJDUMP.PAS, nm n a pas besoin de
    preferer x86-64 puisqu il n y a pas de desassemblage). }
  MachOBase := GetDWordBE(8 + 8);
  Magic := GetDWord(MachOBase);
  If Magic = MH_MAGIC_64 Then BinFormat := FMT_MACHO64
  Else If Magic = MH_MAGIC Then BinFormat := FMT_MACHO32;
  Exit;
 End Else If GetDWordBE(0) = FAT_CIGAM Then Begin
  WriteLn('nm: binaire universel gros-boutiste non supporte.');
  Halt(1);
 End;
 { Fichier objet COFF brut (.o/.obj) : meme heuristique qu OBJDUMP.PAS
   (Machine connu + SizeOfOptionalHeader nul). }
 If BufSize >= 20 Then Begin
  CoffMachine := GetWord(0);
  CoffNSec := GetWord(2);
  CoffSizeOpt := GetWord(16);
  If ((CoffMachine = $14C) Or (CoffMachine = $8664) Or
      (CoffMachine = $1C0) Or (CoffMachine = $1C4) Or
      (CoffMachine = $AA64) Or (CoffMachine = $166) Or
      (CoffMachine = $1F0) Or (CoffMachine = $1F1) Or
      (CoffMachine = $200)) And
     (CoffNSec > 0) And (CoffNSec <= 8192) And (CoffSizeOpt = 0) Then Begin
   BinFormat := FMT_COFFOBJ;
   Exit;
  End;
 End;
End;

{ ============================================================
  ANALYSE DU FORMAT ELF (32 et 64 bits)
  ============================================================ }

{ @description: Remplit Sections[]/Symbols[] a partir d un ELF deja
    charge. Classification : IsCode via SHF_EXECINSTR, IsBss via
    SHT_NOBITS, IsWritable via SHF_WRITE ; les symboles capturent
    le triplet bind/type/shndx necessaire a ClassifySymbol. Le
    decalage du champ sh_link (Base+24 en 32 bits, Base+36 en 64
    bits) doit etre exact pour resoudre la table de chaines des
    symboles : une confusion avec sh_info (Base+28/+40) produirait
    des noms corrompus (corrige une fois deja dans OBJDUMP.PAS). }
Procedure ParseELF;
Var
 Is64: Boolean;
 ShOff, ShEntSize, ShNum, ShStrNdx: LongInt;
 StrTabOff: LongInt;
 I: Integer;
 Base: LongInt;
 SymTabOff, SymTabSize, SymEntSize, SymStrOff: LongInt;
 NameOff, Value, SizeVal: LongInt;
 SecIdx: Integer;
 Info, Bind, SType: Byte;
 SName: String;
 FoundSymTab: Boolean;
 ShFlags, ShType: LongInt;
Begin
 Is64 := (BinFormat = FMT_ELF64);
 ElfBigEndian := GetByte(5) = 2;
 If Is64 Then Begin
  ShOff      := GetElfQWordLow(40);
  ShEntSize  := GetElfWord(58);
  ShNum      := GetElfWord(60);
  ShStrNdx   := GetElfWord(62);
 End Else Begin
  ShOff      := GetElfDWord(32);
  ShEntSize  := GetElfWord(46);
  ShNum      := GetElfWord(48);
  ShStrNdx   := GetElfWord(50);
 End;
 If (ShOff <= 0) Or (ShNum <= 0) Or (ShNum > MaxSections) Then Exit;
 If Is64 Then StrTabOff := GetElfQWordLow(ShOff + ShStrNdx * ShEntSize + 24)
 Else StrTabOff := GetElfDWord(ShOff + ShStrNdx * ShEntSize + 16);
 SectionCount := 0;
 FoundSymTab := False;
 SymTabOff := 0; SymTabSize := 0; SymEntSize := 0; SymStrOff := 0;
 For I := 0 To ShNum - 1 Do Begin
  Base := ShOff + I * ShEntSize;
  Inc(SectionCount);
  If Is64 Then Begin
   NameOff := GetElfDWord(Base);
   ShType  := GetElfDWord(Base + 4);
   ShFlags := GetElfQWordLow(Base + 8);
   Sections[SectionCount].Name    := GetCStr(StrTabOff + NameOff, 31);
   Sections[SectionCount].VAddr   := GetElfQWordLow(Base + 16);
   Sections[SectionCount].FileOff := GetElfQWordLow(Base + 24);
   Sections[SectionCount].Size    := GetElfQWordLow(Base + 32);
   Sections[SectionCount].IsCode  := (ShType = 1) And ((ShFlags And 4) <> 0);
   Sections[SectionCount].IsBss   := ShType = 8; { SHT_NOBITS }
   Sections[SectionCount].IsWritable := (ShFlags And 1) <> 0; { SHF_WRITE }
   If ShType = 2 Then Begin { SHT_SYMTAB }
    SymTabOff  := GetElfQWordLow(Base + 24);
    SymTabSize := GetElfQWordLow(Base + 32);
    SymEntSize := GetElfQWordLow(Base + 56);
    SymStrOff  := GetElfQWordLow(ShOff + GetElfDWord(Base + 36) * ShEntSize + 24);
    FoundSymTab := True;
   End;
  End Else Begin
   NameOff := GetElfDWord(Base);
   ShType  := GetElfDWord(Base + 4);
   ShFlags := GetElfDWord(Base + 8);
   Sections[SectionCount].Name    := GetCStr(StrTabOff + NameOff, 31);
   Sections[SectionCount].VAddr   := GetElfDWord(Base + 12);
   Sections[SectionCount].FileOff := GetElfDWord(Base + 16);
   Sections[SectionCount].Size    := GetElfDWord(Base + 20);
   Sections[SectionCount].IsCode  := (ShType = 1) And ((ShFlags And 4) <> 0);
   Sections[SectionCount].IsBss   := ShType = 8;
   Sections[SectionCount].IsWritable := (ShFlags And 1) <> 0;
   If ShType = 2 Then Begin
    SymTabOff  := GetElfDWord(Base + 16);
    SymTabSize := GetElfDWord(Base + 20);
    SymEntSize := GetElfDWord(Base + 36);
    SymStrOff  := GetElfDWord(ShOff + GetElfDWord(Base + 24) * ShEntSize + 16);
    FoundSymTab := True;
   End;
  End;
 End;
 SymbolCount := 0;
 If FoundSymTab And (SymEntSize > 0) Then Begin
  For I := 0 To (SymTabSize Div SymEntSize) - 1 Do Begin
   If SymbolCount >= MaxSymbols Then Break;
   Base := SymTabOff + I * SymEntSize;
   If Is64 Then Begin
    NameOff := GetElfDWord(Base);
    Info    := GetByte(Base + 4);
    Value   := GetElfQWordLow(Base + 8);
    SizeVal := GetElfQWordLow(Base + 16);
    SecIdx  := GetElfWord(Base + 6);
   End Else Begin
    NameOff := GetElfDWord(Base);
    Value   := GetElfDWord(Base + 4);
    SizeVal := GetElfDWord(Base + 8);
    Info    := GetByte(Base + 12);
    SecIdx  := GetElfWord(Base + 14);
   End;
   SName := GetCStr(SymStrOff + NameOff, 63);
   If SName <> '' Then Begin
    Inc(SymbolCount);
    Bind  := Info Shr 4;
    SType := Info And 15;
    Symbols[SymbolCount].Name    := SName;
    Symbols[SymbolCount].Value   := Value;
    Symbols[SymbolCount].SizeVal := SizeVal;
    Symbols[SymbolCount].IsWeak  := Bind = 2; { STB_WEAK }
    Symbols[SymbolCount].IsGlobal := (Bind = 1) Or (Bind = 2);
    Symbols[SymbolCount].IsUndef  := SecIdx = SHN_UNDEF;
    Symbols[SymbolCount].IsAbs    := SecIdx = (SHN_ABS And $FFFF);
    Symbols[SymbolCount].IsCommon := (SecIdx = (SHN_COMMON And $FFFF)) Or
     (SType = 5); { STT_COMMON }
    { st_shndx ELF est 0-based (l index 0 designe la section NULL
      conventionnelle), alors que Sections[] est rempli en 1-based
      EN Y INCLUANT cette meme section NULL (premiere iteration de
      la boucle de ParseELF, I=0, stocke dans Sections[1]) : il faut
      donc decaler de +1 pour que Sections[SecIdx] designe la bonne
      section reelle (sans ce decalage, tous les symboles d une
      section donnee se retrouvaient classes d apres la section
      PRECEDENTE dans le fichier ELF). }
    If (SecIdx >= 1) And ((SecIdx + 1) <= SectionCount) And
       (Not Symbols[SymbolCount].IsUndef) And
       (Not Symbols[SymbolCount].IsAbs) Then
     Symbols[SymbolCount].SecIdx := SecIdx + 1
    Else
     Symbols[SymbolCount].SecIdx := 0;
   End;
  End;
 End;
End;

{ ============================================================
  ANALYSE DU FORMAT PE / PE32(+) ET FICHIER OBJET COFF BRUT
  ============================================================
  Meme table de symboles COFF dans les deux cas (StorageClass et
  SectionNumber au lieu du bind/shndx ELF) ; seule la presence ou
  non de l enveloppe MZ/PE et de l ImageBase differe, d ou les deux
  procedures distinctes mais tres proches (comme dans OBJDUMP.PAS). }

Procedure ParsePESymbolsCommon(SymTabOff, NumSyms: LongInt);
Var
 StrTabOff: LongInt;
 I, J: Integer;
 Base: LongInt;
 SName: String;
 ZeroLead: Boolean;
 StrOffInTab: LongInt;
 StorClass: Byte;
 SecNum: Integer;
Begin
 SymbolCount := 0;
 If (SymTabOff <= 0) Or (NumSyms <= 0) Then Exit;
 StrTabOff := SymTabOff + NumSyms * 18;
 I := 0;
 While I < NumSyms Do Begin
  If SymbolCount >= MaxSymbols Then Break;
  Base := SymTabOff + I * 18;
  ZeroLead := (GetDWord(Base) = 0);
  If ZeroLead Then Begin
   StrOffInTab := GetDWord(Base + 4);
   SName := GetCStr(StrTabOff + StrOffInTab, 63);
  End Else Begin
   SName := '';
   For J := 0 To 7 Do Begin
    If GetByte(Base + J) = 0 Then Break;
    SName := SName + Chr(GetByte(Base + J));
   End;
  End;
  If SName <> '' Then Begin
   Inc(SymbolCount);
   SecNum := SmallInt(GetWord(Base + 12));
   StorClass := GetByte(Base + 16);
   Symbols[SymbolCount].Name    := SName;
   Symbols[SymbolCount].Value   := ImageBase + GetDWord(Base + 8);
   Symbols[SymbolCount].SizeVal := 0;
   Symbols[SymbolCount].IsWeak  := StorClass = 105; { IMAGE_SYM_CLASS_WEAK_EXTERNAL }
   Symbols[SymbolCount].IsGlobal := (StorClass = 2) Or (StorClass = 105);
   Symbols[SymbolCount].IsUndef := (SecNum = 0) And (Symbols[SymbolCount].Value = 0);
   Symbols[SymbolCount].IsAbs   := SecNum = -1;
   Symbols[SymbolCount].IsCommon := (SecNum = 0) And (Symbols[SymbolCount].Value <> 0);
   If (SecNum >= 1) And (SecNum <= SectionCount) Then
    Symbols[SymbolCount].SecIdx := SecNum
   Else
    Symbols[SymbolCount].SecIdx := 0;
  End;
  I := I + 1 + GetByte(Base + 17); { sauter les entrees auxiliaires }
 End;
End;

Procedure ParsePE;
Var
 PEOff, OptOff, SecOff: LongInt;
 NumSections, SizeOptHdr: Integer;
 I, J: Integer;
 Base: LongInt;
 RawName: String;
 SymTabOff, NumSyms: LongInt;
 Charac: LongInt;
Begin
 PEOff := GetDWord($3C);
 NumSections := GetWord(PEOff + 6);
 SizeOptHdr  := GetWord(PEOff + 20);
 SymTabOff   := GetDWord(PEOff + 12);
 NumSyms     := GetDWord(PEOff + 16);
 OptOff := PEOff + 24;
 ImageBase := GetDWord(OptOff + 28);
 SecOff := OptOff + SizeOptHdr;
 If NumSections > MaxSections Then NumSections := MaxSections;
 SectionCount := 0;
 For I := 0 To NumSections - 1 Do Begin
  Base := SecOff + I * 40;
  RawName := '';
  For J := 0 To 7 Do Begin
   If GetByte(Base + J) = 0 Then Break;
   RawName := RawName + Chr(GetByte(Base + J));
  End;
  Inc(SectionCount);
  Charac := GetDWord(Base + 36);
  Sections[SectionCount].Name    := RawName;
  Sections[SectionCount].VAddr   := ImageBase + GetDWord(Base + 12);
  Sections[SectionCount].FileOff := GetDWord(Base + 20);
  Sections[SectionCount].Size    := GetDWord(Base + 8);
  Sections[SectionCount].IsCode  := (Charac And $20000000) <> 0; { MEM_EXECUTE }
  Sections[SectionCount].IsBss   := (Charac And $00000080) <> 0; { CNT_UNINITIALIZED_DATA }
  Sections[SectionCount].IsWritable := (Charac And $80000000) <> 0; { MEM_WRITE }
 End;
 ParsePESymbolsCommon(SymTabOff, NumSyms);
End;

Procedure ParseCoffObj;
Var
 SecOff: LongInt;
 NumSections, SizeOptHdr: Integer;
 I, J: Integer;
 Base, StrTabOff: LongInt;
 RawName: String;
 SymTabOff, NumSyms: LongInt;
 NameIdx: LongInt;
 Code: Integer;
 Charac: LongInt;
Begin
 NumSections := GetWord(2);
 SymTabOff   := GetDWord(8);
 NumSyms     := GetDWord(12);
 SizeOptHdr  := GetWord(16);
 ImageBase   := 0;
 SecOff := 20 + SizeOptHdr;
 StrTabOff := SymTabOff + NumSyms * 18;
 If NumSections > MaxSections Then NumSections := MaxSections;
 SectionCount := 0;
 For I := 0 To NumSections - 1 Do Begin
  Base := SecOff + I * 40;
  RawName := '';
  For J := 0 To 7 Do Begin
   If GetByte(Base + J) = 0 Then Break;
   RawName := RawName + Chr(GetByte(Base + J));
  End;
  If (Length(RawName) > 0) And (RawName[1] = '/') And (StrTabOff > 0) Then Begin
   Val(Copy(RawName, 2, Length(RawName) - 1), NameIdx, Code);
   If Code = 0 Then RawName := GetCStr(StrTabOff + NameIdx, 63);
  End;
  Inc(SectionCount);
  Charac := GetDWord(Base + 36);
  Sections[SectionCount].Name    := RawName;
  Sections[SectionCount].VAddr   := GetDWord(Base + 12);
  Sections[SectionCount].FileOff := GetDWord(Base + 20);
  Sections[SectionCount].Size    := GetDWord(Base + 16);
  Sections[SectionCount].IsCode  := (Charac And $20000000) <> 0;
  Sections[SectionCount].IsBss   := (Charac And $00000080) <> 0;
  Sections[SectionCount].IsWritable := (Charac And $80000000) <> 0;
 End;
 ParsePESymbolsCommon(SymTabOff, NumSyms);
End;

{ ============================================================
  ANALYSE DU FORMAT MACH-O (32 et 64 bits)
  ============================================================
  Classification de section par convention de nom (la plus fiable
  sans decoder le champ "flags" complet de section_64) : segment
  __TEXT/section __text = code ; section __bss/__common = BSS ;
  segment __TEXT (hors __text) = lecture seule ; segment __DATA et
  autres = donnees inscriptibles. n_sect (1-based, numerotation
  globale toutes sections confondues) correspond directement a
  l index dans Sections[], rempli dans le meme ordre. }
Procedure ParseMachO;
Var
 Is64: Boolean;
 HdrSize: LongInt;
 NCmds: LongInt;
 CmdOff, Cmd, CmdSize: LongInt;
 I, J: Integer;
 NSects, SectOff, SegHdrSize, SectEntrySize: LongInt;
 SName, SSegName: String;
 SAddr, SSize, SFileOff: LongInt;
 SymOff, NSyms, StrOff: LongInt;
 SymEntrySize: LongInt;
 SBase: LongInt;
 NStrx, NValue: LongInt;
 NType, NSect: Byte;
Begin
 Is64 := (BinFormat = FMT_MACHO64);
 If Is64 Then HdrSize := 32 Else HdrSize := 28;
 NCmds := GetDWord(MachOBase + 16);
 SectionCount := 0;
 SymbolCount := 0;
 SymOff := 0; NSyms := 0; StrOff := 0;
 CmdOff := MachOBase + HdrSize;
 For I := 0 To NCmds - 1 Do Begin
  If (CmdOff + 8 > BufSize) Or (CmdOff + 8 < 0) Then Break;
  Cmd     := GetDWord(CmdOff);
  CmdSize := GetDWord(CmdOff + 4);
  If CmdSize <= 0 Then Break;
  If (Cmd = LC_SEGMENT) Or (Cmd = LC_SEGMENT_64) Then Begin
   SSegName := GetCStr(CmdOff + 8, 16);
   If Cmd = LC_SEGMENT_64 Then Begin
    NSects   := GetDWord(CmdOff + 64);
    SegHdrSize := 72; SectEntrySize := 80;
   End Else Begin
    NSects   := GetDWord(CmdOff + 48);
    SegHdrSize := 56; SectEntrySize := 68;
   End;
   SectOff := CmdOff + SegHdrSize;
   For J := 0 To NSects - 1 Do Begin
    If SectionCount >= MaxSections Then Break;
    SName    := GetCStr(SectOff, 16);
    SSegName := GetCStr(SectOff + 16, 16);
    If Cmd = LC_SEGMENT_64 Then Begin
     SAddr    := GetDWord(SectOff + 32);
     SSize    := GetDWord(SectOff + 40);
     SFileOff := GetDWord(SectOff + 48);
    End Else Begin
     SAddr    := GetDWord(SectOff + 32);
     SSize    := GetDWord(SectOff + 36);
     SFileOff := GetDWord(SectOff + 40);
    End;
    Inc(SectionCount);
    Sections[SectionCount].Name    := SSegName + ',' + SName;
    Sections[SectionCount].VAddr   := SAddr;
    Sections[SectionCount].FileOff := MachOBase + SFileOff;
    Sections[SectionCount].Size    := SSize;
    Sections[SectionCount].IsCode  := (SSegName = '__TEXT') And (SName = '__text');
    Sections[SectionCount].IsBss   := (SName = '__bss') Or (SName = '__common');
    Sections[SectionCount].IsWritable := SSegName <> '__TEXT';
    SectOff := SectOff + SectEntrySize;
   End;
  End Else If Cmd = LC_SYMTAB Then Begin
   SymOff := MachOBase + GetDWord(CmdOff + 8);
   NSyms  := GetDWord(CmdOff + 12);
   StrOff := MachOBase + GetDWord(CmdOff + 16);
  End;
  CmdOff := CmdOff + CmdSize;
 End;
 ImageBase := 0;
 If Is64 Then SymEntrySize := 16 Else SymEntrySize := 12;
 If (NSyms > 0) And (SymOff > 0) Then
  For I := 0 To NSyms - 1 Do Begin
   If SymbolCount >= MaxSymbols Then Break;
   SBase := SymOff + I * SymEntrySize;
   NStrx  := GetDWord(SBase);
   NType  := GetByte(SBase + 4);
   NSect  := GetByte(SBase + 5);
   NValue := GetDWord(SBase + 8);
   If (NType And $E0) <> 0 Then Continue; { entree de debogage (stab) }
   SName := GetCStr(StrOff + NStrx, 63);
   If SName <> '' Then Begin
    Inc(SymbolCount);
    Symbols[SymbolCount].Name    := SName;
    Symbols[SymbolCount].Value   := NValue;
    Symbols[SymbolCount].SizeVal := 0;
    Symbols[SymbolCount].IsGlobal := (NType And $01) <> 0; { N_EXT }
    Symbols[SymbolCount].IsWeak  := False;
    Case NType And $0E Of
     $00: Begin { N_UNDF }
      Symbols[SymbolCount].IsUndef  := NValue = 0;
      Symbols[SymbolCount].IsCommon := NValue <> 0;
      Symbols[SymbolCount].SecIdx := 0;
     End;
     $02: Begin { N_ABS }
      Symbols[SymbolCount].IsAbs := True;
      Symbols[SymbolCount].SecIdx := 0;
     End;
    Else Begin { N_SECT et autres : section reelle }
     If (NSect >= 1) And (NSect <= SectionCount) Then
      Symbols[SymbolCount].SecIdx := NSect
     Else
      Symbols[SymbolCount].SecIdx := 0;
    End;
    End;
   End;
  End;
End;

{ ============================================================
  ANALYSE D UNE BIBLIOTHEQUE STATIQUE "ar" (.a)
  ============================================================ }
Procedure ParseArchive;
Var
 Off, Sz: LongInt;
 Name, SizeStr: String;
 I: Integer;
 LongNamesOff: LongInt;
 NameIdx: LongInt;
 Code: Integer;
Begin
 ArchiveMemberCount := 0;
 LongNamesOff := -1;
 Off := 8;
 While Off + 60 <= BufSize Do Begin
  Name := '';
  For I := 0 To 15 Do Begin
   If GetByte(Off + I) = Ord(' ') Then Break;
   Name := Name + Chr(GetByte(Off + I));
  End;
  SizeStr := '';
  For I := 0 To 9 Do Begin
   If GetByte(Off + 48 + I) = Ord(' ') Then Break;
   SizeStr := SizeStr + Chr(GetByte(Off + 48 + I));
  End;
  Val(SizeStr, Sz, Code);
  If Code <> 0 Then Sz := 0;
  If Name = '//' Then
   LongNamesOff := Off + 60
  Else If Name = '/' Then Begin
   { table des symboles : ignoree }
  End Else Begin
   If (Length(Name) > 0) And (Name[1] = '/') Then Begin
    Val(Copy(Name, 2, Length(Name) - 1), NameIdx, Code);
    If (Code = 0) And (LongNamesOff >= 0) Then
     Name := GetArName(LongNamesOff + NameIdx, 200);
   End Else If (Length(Name) > 0) And (Name[Length(Name)] = '/') Then
    Name := Copy(Name, 1, Length(Name) - 1);
   If ArchiveMemberCount < MaxArchiveMembers Then Begin
    Inc(ArchiveMemberCount);
    ArchiveMembers[ArchiveMemberCount].Name := Name;
    ArchiveMembers[ArchiveMemberCount].DataOff := Off + 60;
    ArchiveMembers[ArchiveMemberCount].DataSize := Sz;
   End;
  End;
  Off := Off + 60 + Sz;
  If (Sz Mod 2) = 1 Then Inc(Off);
 End;
End;

{ ============================================================
  DEMANGLAGE C++ (ITANIUM ABI, SOUS-ENSEMBLE) -- OPTION -C
  ============================================================
  Identique a OBJDUMP.PAS : voir son commentaire d en-tete pour le
  detail des limitations (pas de substitution S_/S0_, gabarits
  affiches en abrege). }

Function DemangleReadNumber(S: String; Var Pos: Integer): Integer;
Var
 N: Integer;
Begin
 N := 0;
 While (Pos <= Length(S)) And (S[Pos] >= '0') And (S[Pos] <= '9') Do Begin
  N := N * 10 + (Ord(S[Pos]) - Ord('0'));
  Inc(Pos);
 End;
 DemangleReadNumber := N;
End;

Function DemangleSourceName(S: String; Var Pos: Integer): String;
Var
 Len: Integer;
Begin
 Len := DemangleReadNumber(S, Pos);
 If (Len <= 0) Or (Pos + Len - 1 > Length(S)) Then Begin
  DemangleSourceName := '';
  Exit;
 End;
 DemangleSourceName := Copy(S, Pos, Len);
 Pos := Pos + Len;
End;

Function DemangleBuiltinType(C: Char): String;
Begin
 Case C Of
  'v': DemangleBuiltinType := 'void';
  'b': DemangleBuiltinType := 'bool';
  'c': DemangleBuiltinType := 'char';
  'a': DemangleBuiltinType := 'signed char';
  'h': DemangleBuiltinType := 'unsigned char';
  's': DemangleBuiltinType := 'short';
  't': DemangleBuiltinType := 'unsigned short';
  'i': DemangleBuiltinType := 'int';
  'j': DemangleBuiltinType := 'unsigned int';
  'l': DemangleBuiltinType := 'long';
  'm': DemangleBuiltinType := 'unsigned long';
  'x': DemangleBuiltinType := 'long long';
  'y': DemangleBuiltinType := 'unsigned long long';
  'f': DemangleBuiltinType := 'float';
  'd': DemangleBuiltinType := 'double';
  'e': DemangleBuiltinType := 'long double';
  'w': DemangleBuiltinType := 'wchar_t';
  'z': DemangleBuiltinType := '...';
 Else
  DemangleBuiltinType := '';
 End;
End;

Function DemangleNestedName(S: String; Var Pos: Integer): String;
Var
 Parts, Part: String;
 Failed: Boolean;
Begin
 Inc(Pos);
 While (Pos <= Length(S)) And ((S[Pos] = 'r') Or (S[Pos] = 'V') Or
       (S[Pos] = 'K')) Do Inc(Pos);
 Parts := '';
 Failed := False;
 While (Pos <= Length(S)) And (S[Pos] <> 'E') And (Not Failed) Do Begin
  If (S[Pos] >= '0') And (S[Pos] <= '9') Then
   Part := DemangleSourceName(S, Pos)
  Else If (S[Pos] = 'C') And (Pos < Length(S)) And
          (S[Pos + 1] In ['1', '2', '3']) Then Begin
   Part := '{ctor}'; Pos := Pos + 2;
  End Else If (S[Pos] = 'D') And (Pos < Length(S)) And
          (S[Pos + 1] In ['0', '1', '2']) Then Begin
   Part := '~{dtor}'; Pos := Pos + 2;
  End Else Begin
   Part := ''; Failed := True;
  End;
  If Part = '' Then Begin Failed := True; Break; End;
  If Parts <> '' Then Parts := Parts + '::';
  Parts := Parts + Part;
  If (Pos <= Length(S)) And (S[Pos] = 'I') Then Begin
   Parts := Parts + '<...>';
   Inc(Pos);
   While (Pos <= Length(S)) And (S[Pos] <> 'E') Do Inc(Pos);
   If Pos <= Length(S) Then Inc(Pos);
  End;
 End;
 If (Pos <= Length(S)) And (S[Pos] = 'E') Then Inc(Pos);
 If Failed Then DemangleNestedName := '' Else DemangleNestedName := Parts;
End;

Function DemangleType(S: String; Var Pos: Integer): String;
Var
 Inner, Suffix: String;
 C: Char;
Begin
 If Pos > Length(S) Then Begin DemangleType := ''; Exit; End;
 C := S[Pos];
 If C = 'P' Then Begin
  Inc(Pos);
  Inner := DemangleType(S, Pos);
  If Inner = '' Then DemangleType := '' Else DemangleType := Inner + '*';
 End Else If C = 'R' Then Begin
  Inc(Pos);
  Inner := DemangleType(S, Pos);
  If Inner = '' Then DemangleType := '' Else DemangleType := Inner + '&';
 End Else If C = 'K' Then Begin
  Inc(Pos);
  Inner := DemangleType(S, Pos);
  If Inner = '' Then DemangleType := '' Else DemangleType := 'const ' + Inner;
 End Else If (C >= '0') And (C <= '9') Then
  DemangleType := DemangleSourceName(S, Pos)
 Else If C = 'N' Then
  DemangleType := DemangleNestedName(S, Pos)
 Else Begin
  Suffix := DemangleBuiltinType(C);
  If Suffix <> '' Then Begin
   Inc(Pos);
   DemangleType := Suffix;
  End Else
   DemangleType := '';
 End;
End;

Function DemangleCpp(S: String): String;
Var
 Pos: Integer;
 Name, Params, PType: String;
 Ok: Boolean;
Begin
 DemangleCpp := S;
 If Copy(S, 1, 2) <> '_Z' Then Exit;
 Pos := 3;
 If Pos > Length(S) Then Exit;
 If S[Pos] = 'N' Then
  Name := DemangleNestedName(S, Pos)
 Else If (S[Pos] >= '0') And (S[Pos] <= '9') Then
  Name := DemangleSourceName(S, Pos)
 Else
  Exit;
 If Name = '' Then Exit;
 If (Pos <= Length(S)) And (S[Pos] = 'I') Then Begin
  Name := Name + '<...>';
  Inc(Pos);
  While (Pos <= Length(S)) And (S[Pos] <> 'E') Do Inc(Pos);
  If Pos <= Length(S) Then Inc(Pos);
 End;
 If Pos > Length(S) Then Begin
  DemangleCpp := Name;
  Exit;
 End;
 If (S[Pos] = 'v') And (Pos = Length(S)) Then Begin
  DemangleCpp := Name + '(void)';
  Exit;
 End;
 Params := '';
 Ok := True;
 While (Pos <= Length(S)) And Ok Do Begin
  PType := DemangleType(S, Pos);
  If PType = '' Then Begin Ok := False; Break; End;
  If Params <> '' Then Params := Params + ', ';
  Params := Params + PType;
 End;
 If Not Ok Then
  DemangleCpp := Name + '(...)'
 Else
  DemangleCpp := Name + '(' + Params + ')';
End;

{ ============================================================
  CLASSIFICATION DES SYMBOLES (LETTRE DE TYPE)
  ============================================================ }

{ @description: Calcule la lettre de type "nm" d un symbole, une
    fois sa section resolue. Priorite : faible (W/w) > indefini (U)
    > absolu (A/a) > commun (C) > section (T/D/B/R selon le
    drapeaux de la section, ou "?" si aucune section resolue),
    majuscule si global, minuscule si local (sauf U, toujours
    majuscule, et C, toujours majuscule par convention).
  @param Sym Symbole deja rempli (IsUndef/IsAbs/IsCommon/IsWeak/
    IsGlobal/SecIdx)
  @return Lettre de type }
Function ClassifySymbol(Var Sym: TNmSymbol): Char;
Var
 Base: Char;
Begin
 If Sym.IsWeak Then Begin
  If Sym.IsUndef Then ClassifySymbol := 'w' Else ClassifySymbol := 'W';
  Exit;
 End;
 If Sym.IsUndef Then Begin ClassifySymbol := 'U'; Exit; End;
 If Sym.IsAbs Then Begin
  If Sym.IsGlobal Then ClassifySymbol := 'A' Else ClassifySymbol := 'a';
  Exit;
 End;
 If Sym.IsCommon Then Begin ClassifySymbol := 'C'; Exit; End;
 If (Sym.SecIdx >= 1) And (Sym.SecIdx <= SectionCount) Then Begin
  If Sections[Sym.SecIdx].IsCode Then Base := 'T'
  Else If Sections[Sym.SecIdx].IsBss Then Base := 'B'
  Else If Not Sections[Sym.SecIdx].IsWritable Then Base := 'R'
  Else Base := 'D';
 End Else
  Base := '?';
 If Base = '?' Then Begin ClassifySymbol := '?'; Exit; End;
 If Sym.IsGlobal Then ClassifySymbol := Base
 Else ClassifySymbol := Chr(Ord(Base) + 32);
End;

{ ============================================================
  TRI DES SYMBOLES
  ============================================================ }

Function SymLess(Var A, B: TNmSymbol): Boolean;
Begin
 If OptSizeSort Then SymLess := A.SizeVal < B.SizeVal
 Else If OptNumericSort Then SymLess := A.Value < B.Value
 Else SymLess := A.Name < B.Name; { tri alphabetique, defaut du vrai nm }
End;

{ @description: Tri rapide (quicksort) des symboles selon le
    critere actif (-n/--size-sort/alphabetique par defaut), avec
    inversion eventuelle (-r). Pas de tri du tout si -p. }
Procedure QuickSortSymbols(Lo, Hi: Integer);
Var
 I, J: Integer;
 Pivot, Tmp: TNmSymbol;
Begin
 If Lo >= Hi Then Exit;
 I := Lo; J := Hi;
 Pivot := Symbols[(Lo + Hi) Div 2];
 Repeat
  While SymLess(Symbols[I], Pivot) Do Inc(I);
  While SymLess(Pivot, Symbols[J]) Do Dec(J);
  If I <= J Then Begin
   Tmp := Symbols[I]; Symbols[I] := Symbols[J]; Symbols[J] := Tmp;
   Inc(I); Dec(J);
  End;
 Until I > J;
 If Lo < J Then QuickSortSymbols(Lo, J);
 If I < Hi Then QuickSortSymbols(I, Hi);
End;

Procedure ReverseSymbols;
Var
 I: Integer;
 Tmp: TNmSymbol;
Begin
 I := 1;
 While I < SymbolCount - I + 1 Do Begin
  Tmp := Symbols[I]; Symbols[I] := Symbols[SymbolCount - I + 1];
  Symbols[SymbolCount - I + 1] := Tmp;
  Inc(I);
 End;
End;

{ ============================================================
  AFFICHAGE
  ============================================================ }

Function DisplayName(Var Sym: TNmSymbol): String;
Begin
 If OptDemangle Then DisplayName := DemangleCpp(Sym.Name)
 Else DisplayName := Sym.Name;
End;

Procedure PrintOneSymbol(Var Sym: TNmSymbol);
Var
 NameTxt, Prefix: String;
Begin
 NameTxt := DisplayName(Sym);
 Prefix := '';
 If OptPrintFileName Then Prefix := CurFileLabel + ':';
 Case OutFormat Of
  1: Begin { sysv }
   Write(Prefix, PadRight(NameTxt, 32), '|');
   If Sym.TypeChar = 'U' Then Write(PadRight('', 9), '|')
   Else Write(PadRight(FormatRadix(Sym.Value), 9), '|');
   Write(' ', Sym.TypeChar, '               |');
   If OptPrintSize And (Sym.TypeChar <> 'U') Then
    Write(PadRight(FormatRadix(Sym.SizeVal), 9))
   Else
    Write(PadRight('', 9));
   WriteLn('|        |');
  End;
  2: Begin { posix }
   Write(Prefix, NameTxt, ' ', Sym.TypeChar);
   If Sym.TypeChar <> 'U' Then Begin
    Write(' ', FormatRadix(Sym.Value));
    If OptPrintSize Then Write(' ', FormatRadix(Sym.SizeVal));
   End;
   WriteLn;
  End;
 Else Begin { bsd, par defaut }
  Write(Prefix);
  If Sym.TypeChar = 'U' Then
   Write(PadRight('', 8))
  Else
   Write(FormatRadix(Sym.Value));
  If OptPrintSize Then Begin
   If Sym.TypeChar <> 'U' Then Write(' ', FormatRadix(Sym.SizeVal))
   Else Write(' ', PadRight('', 8));
  End;
  WriteLn(' ', Sym.TypeChar, ' ', NameTxt);
 End;
 End;
End;

{ @description: Filtre et affiche les symboles actuellement dans
    Symbols[] (deja remplis par le parseur de format concerne),
    apres avoir calcule leur lettre de type, trie et applique les
    filtres -g/-u. Appele une fois par fichier ou par membre
    d archive. }
Procedure PrintSymbols;
Var
 I: Integer;
 Show: Boolean;
Begin
 For I := 1 To SymbolCount Do
  Symbols[I].TypeChar := ClassifySymbol(Symbols[I]);
 If Not OptNoSort Then Begin
  If SymbolCount > 1 Then QuickSortSymbols(1, SymbolCount);
  If OptReverseSort Then ReverseSymbols;
 End;
 If OutFormat = 1 Then Begin
  WriteLn;
  WriteLn(CurFileLabel, ':');
  WriteLn;
  WriteLn('Name                            Value  |Class| Type|       Size  |Line  Section');
  WriteLn;
 End;
 For I := 1 To SymbolCount Do Begin
  Show := True;
  If OptExternOnly And (Not (Symbols[I].TypeChar In
   ['A'..'Z'])) Then Show := False; { majuscule = global, sauf 'C' deja majuscule }
  If OptUndefinedOnly And (Symbols[I].TypeChar <> 'U') Then Show := False;
  If Show Then PrintOneSymbol(Symbols[I]);
 End;
End;

{ ============================================================
  ANALYSE D UN FICHIER (OU D UN MEMBRE D ARCHIVE) CHARGE
  ============================================================ }

Procedure AnalyzeLoadedBuffer;
Begin
 If InArchiveMember Then Begin
  WriteLn;
  WriteLn(CurFileLabel, ':');
 End;
 Case BinFormat Of
  FMT_ELF32, FMT_ELF64: ParseELF;
  FMT_PE32, FMT_PE64: ParsePE;
  FMT_COFFOBJ: ParseCoffObj;
  FMT_MACHO32, FMT_MACHO64: ParseMachO;
  FMT_MZ: Begin
   WriteLn(CurFileLabel, ': format EXE DOS (MZ) sans table de symboles exploitable.');
   SymbolCount := 0;
   Exit;
  End;
  FMT_NES: Begin
   WriteLn(CurFileLabel, ': ROM NES (iNES) sans table de symboles.');
   SymbolCount := 0;
   Exit;
  End;
 Else Begin
  WriteLn(CurFileLabel, ': format non reconnu, aucune table de symboles.');
  SymbolCount := 0;
  Exit;
 End;
 End;
 If SymbolCount = 0 Then
  WriteLn(CurFileLabel, ': nm: aucun symbole')
 Else
  PrintSymbols;
End;

{ ============================================================
  AIDE ET PROGRAMME PRINCIPAL
  ============================================================ }

Procedure Help;
Begin
 WriteLn('NM - Cette commande permet d''afficher la table des symboles d''un fichier objet, d''une');
 WriteLn('bibliotheque statique ou d''un executable.');
 WriteLn;
 WriteLn('Syntaxe : NM [options] fichier');
 WriteLn('  -A, --print-file-name   Prefixe chaque symbole par le nom du fichier');
 WriteLn('  -a, --debug-syms        Accepte, sans effet (pas de filtrage debug ici)');
 WriteLn('  -B                      Equivaut a --format=bsd (defaut)');
 WriteLn('  -C, --demangle          Demangle les noms C++ (Itanium ABI, sous-ensemble)');
 WriteLn('      --no-demangle       Desactive le demangling (defaut)');
 WriteLn('  -D, --dynamic           Accepte ; ce clone n''affiche que la table');
 WriteLn('                          statique (.symtab), deja la plus utile en pratique');
 WriteLn('  -f format               bsd (defaut), sysv, ou posix');
 WriteLn('  -g, --extern-only       N''affiche que les symboles externes (globaux)');
 WriteLn('  -l, --line-numbers      Accepte, sans effet (pas d''info DWARF/PDB ici)');
 WriteLn('  -n, --numeric-sort      Trie par adresse plutot que par nom');
 WriteLn('  -p, --no-sort           N''effectue aucun tri (ordre du fichier)');
 WriteLn('  -P, --portability       Equivaut a --format=posix');
 WriteLn('  -r, --reverse-sort      Inverse l''ordre de tri');
 WriteLn('  -S, --print-size        Affiche la taille des symboles definis');
 WriteLn('  -s, --print-armap       Accepte, sans effet (index d''archive non genere)');
 WriteLn('  --size-sort             Trie par taille');
 WriteLn('  -t radix                Base d''affichage : d (decimal), o (octal),');
 WriteLn('                          x (hexadecimal, defaut)');
 WriteLn('  -u, --undefined-only    N''affiche que les symboles indefinis');
 WriteLn('  --target=fmt            Accepte, sans effet (detection automatique)');
 WriteLn('  -V, --version           Affiche la version');
 WriteLn('  -h, --help, -?          Cette aide');
 WriteLn;
 WriteLn('Formats supportes : ELF32/ELF64, PE32/PE32+, fichier objet COFF brut');
 WriteLn('(.o/.obj), Mach-O 32/64 bits (dont "fat"), bibliotheque statique "ar"');
 WriteLn('(.a, chaque membre traite comme un fichier independant). EXE DOS (MZ)');
 WriteLn('et ROM NES sont detectes mais n''ont pas de table de symboles.');
 WriteLn('Lettres de type (sous-ensemble pratique) : T/t code, D/d donnees,');
 WriteLn('B/b BSS, R/r lecture seule, A/a absolu, C commun, U indefini,');
 WriteLn('W/w faible (defini/indefini). Majuscule = global, minuscule = local.');
End;

Var
 Arg: String;
 I: Integer;
 ArchiveBuf: PByteBuf;
 ArchiveBufSize: LongInt;
 MemberBuf: PByteBuf;
 SavedFileName: String;
 AI: Integer;
BEGIN
 If((ParamStr(1)='-h')Or(ParamStr(1)='--help')Or(ParamStr(1)='/?')Or(ParamStr(1)='/h')Or(ParamStr(1) = '/H'))Then Begin
  Help;
  Halt(0);
 End;
 InFileName := '';
 InArchiveMember := False;
 OptDemangle := False;
 OptExternOnly := False;
 OptUndefinedOnly := False;
 OptNumericSort := False;
 OptNoSort := False;
 OptReverseSort := False;
 OptSizeSort := False;
 OptPrintSize := False;
 OptPrintFileName := False;
 OptPrintArmap := False;
 OptRadix := 'x';
 OutFormat := 0;

 If ParamCount < 1 Then Begin
  Help;
  Halt(1);
 End;

 I := 1;
 While I <= ParamCount Do Begin
  Arg := ParamStr(I);
  If (Arg = '-?') Or (Arg = '-h') Or (Arg = '--help') Then Begin
   Help;
   Halt(0);
  End Else If (Arg = '-V') Or (Arg = '--version') Then Begin
   WriteLn('NM.PAS (clone partiel de GNU nm, Pascal/FPC).');
   Halt(0);
  End Else If (Arg = '-A') Or (Arg = '--print-file-name') Then
   OptPrintFileName := True
  Else If (Arg = '-a') Or (Arg = '--debug-syms') Then
   { accepte, sans effet }
  Else If Arg = '-B' Then
   OutFormat := 0
  Else If (Arg = '-C') Or (Arg = '--demangle') Then
   OptDemangle := True
  Else If Arg = '--no-demangle' Then
   OptDemangle := False
  Else If (Arg = '-D') Or (Arg = '--dynamic') Then
   { accepte, sans effet : voir Help }
  Else If Arg = '-f' Then Begin
   Inc(I);
   If I > ParamCount Then Begin
    WriteLn('nm: -f necessite un format (bsd, sysv, posix).');
    Halt(1);
   End;
   If UpStr(ParamStr(I)) = 'SYSV' Then OutFormat := 1
   Else If UpStr(ParamStr(I)) = 'POSIX' Then OutFormat := 2
   Else OutFormat := 0;
  End Else If StartsWithStr(Arg, '--format=') Then Begin
   If UpStr(Copy(Arg, 10, Length(Arg) - 9)) = 'SYSV' Then OutFormat := 1
   Else If UpStr(Copy(Arg, 10, Length(Arg) - 9)) = 'POSIX' Then OutFormat := 2
   Else OutFormat := 0;
  End
  Else If (Arg = '-g') Or (Arg = '--extern-only') Then
   OptExternOnly := True
  Else If (Arg = '-l') Or (Arg = '--line-numbers') Then
   { accepte, sans effet }
  Else If (Arg = '-n') Or (Arg = '--numeric-sort') Then
   OptNumericSort := True
  Else If (Arg = '-p') Or (Arg = '--no-sort') Then
   OptNoSort := True
  Else If (Arg = '-P') Or (Arg = '--portability') Then
   OutFormat := 2
  Else If (Arg = '-r') Or (Arg = '--reverse-sort') Then
   OptReverseSort := True
  Else If (Arg = '-S') Or (Arg = '--print-size') Then
   OptPrintSize := True
  Else If (Arg = '-s') Or (Arg = '--print-armap') Then
   OptPrintArmap := True
  Else If Arg = '--size-sort' Then
   OptSizeSort := True
  Else If Arg = '-t' Then Begin
   Inc(I);
   If I > ParamCount Then Begin
    WriteLn('nm: -t necessite une base (d, o, x).');
    Halt(1);
   End;
   OptRadix := ParamStr(I)[1];
  End
  Else If (Arg = '-u') Or (Arg = '--undefined-only') Then
   OptUndefinedOnly := True
  Else If (Arg = '--target') Then Begin
   Inc(I); { accepte, sans effet : detection automatique uniquement }
  End Else If StartsWithStr(Arg, '--target=') Then
   { idem, forme attachee }

  Else If StartsWithStr(Arg, '-') Then Begin
   WriteLn('nm: option inconnue : ', Arg);
   Halt(1);
  End Else
   InFileName := Arg;
  Inc(I);
 End;

 If InFileName = '' Then Begin
  WriteLn('nm: aucun fichier specifie.');
  Halt(1);
 End;

 LoadFile(InFileName);
 DetectFormat;

 If BinFormat = FMT_ARCHIVE Then Begin
  ParseArchive;
  InArchiveMember := True;
  ArchiveBuf := Buf;
  ArchiveBufSize := BufSize;
  SavedFileName := InFileName;
  For AI := 1 To ArchiveMemberCount Do Begin
   If ArchiveMembers[AI].DataSize > 0 Then Begin
    GetMem(MemberBuf, ArchiveMembers[AI].DataSize);
    Move(ArchiveBuf^[ArchiveMembers[AI].DataOff], MemberBuf^,
     ArchiveMembers[AI].DataSize);
    Buf := MemberBuf;
    BufSize := ArchiveMembers[AI].DataSize;
    CurFileLabel := SavedFileName + '[' + ArchiveMembers[AI].Name + ']';
    InFileName := CurFileLabel;
    DetectFormat;
    AnalyzeLoadedBuffer;
    FreeMem(MemberBuf, ArchiveMembers[AI].DataSize);
   End;
  End;
  Buf := ArchiveBuf;
  BufSize := ArchiveBufSize;
 End Else Begin
  CurFileLabel := InFileName;
  AnalyzeLoadedBuffer;
 End;
END.
