{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Clone partiel de l outil GNU "objdump", couvrant les
    formats binaires ELF32/ELF64 (Linux) et PE32/PE32+ (Windows), avec
    desassemblage x86 32 bits pour les instructions courantes.

    Portee assumee (voir discussion avec l utilisateur) :
    - Formats : ELF (32 et 64 bits, ce dernier en lecture d en-tetes
      best-effort) et PE/PE32 (32 et 64 bits, idem).
    - Desassemblage (-d) : jeu d instructions x86 32 bits courant
      (mov, push/pop, arithmetique, branchements, etc.), pas une
      couverture exhaustive (pas de SSE/AVX/x86-64 REX).
    - L option -S (melange source/assembleur) necessiterait de lire
      les informations de debogage (DWARF pour ELF, CodeView/PDB pour
      PE), hors de portee ici : elle affiche un message explicite
      plutot que de simuler un resultat.

    Architecture : le fichier est charge entierement en memoire (via
    GetMem), puis lu par decalage (Off) avec des fonctions GetByte/
    GetWord/GetDWord. Chaque format (ELF, PE) remplit les memes
    tableaux Sections[]/Symbols[], consultes ensuite par les
    commandes -h/-t/-d, independamment du format d origine.
}

Program OBJDUMP;

{$A-}
{$I-}
{$R-}

Const
 MaxSections = 256;       { nombre maximal de sections gerees }
 MaxSymbols  = 16384;     { nombre maximal de symboles geres }

 { ----- Formats binaires reconnus ----- }
 FMT_UNKNOWN = 0;
 FMT_ELF32   = 1;
 FMT_ELF64   = 2;
 FMT_PE32    = 3;
 FMT_PE64    = 4;

Type
 String64 = String[64];

 { Une section du binaire (texte, donnees, ...), normalisee quel que
   soit le format d origine. }
 TSection = Record
  Name      : String[32];   { nom de la section (ex: .text)         }
  VAddr     : LongInt;      { adresse virtuelle de chargement (VMA) }
  FileOff   : LongInt;      { decalage dans le fichier               }
  Size      : LongInt;      { taille en octets                       }
  IsCode    : Boolean;      { vrai si executable (pour -d)           }
 End;

 { Un symbole (nom + adresse), normalise quel que soit le format. }
 TSymbol = Record
  Name      : String64;
  Value     : LongInt;      { adresse (VMA) du symbole               }
  SecIdx    : Integer;      { index 1-based dans Sections, 0 si rien }
  IsFunc    : Boolean;      { vrai si le symbole designe une fonction}
 End;

 { Tableau d octets de taille ouverte, accede via un pointeur ; les
   bornes statiques ([0..0]) n empechent pas l indexation au-dela
   tant que la verification de portee est desactivee (directive R
   moins, en tete de fichier). }
 TByteBuf = Array[0..0] Of Byte;
 PByteBuf = ^TByteBuf;

Var
 Buf          : PByteBuf;
 BufSize      : LongInt;
 BinFormat    : Integer;          { FMT_xxx }
 InFileName   : String;
 EntryPoint   : LongInt;
 ImageBase    : LongInt;
 Sections     : Array[1..MaxSections] Of TSection;
 SectionCount : Integer;
 Symbols      : Array[1..MaxSymbols] Of TSymbol;
 SymbolCount  : Integer;
 OptHeaders   : Boolean;          { -h }
 OptSymbols   : Boolean;          { -t }
 OptDisasm    : Boolean;          { -d }
 OptSource    : Boolean;          { -S (non supporte) }

{ ============================================================
  UTILITAIRES GENERAUX
  ============================================================ }

{ @description: Convertit une chaine en majuscules.
  @param S Chaine a convertir
  @return Chaine convertie en majuscules }
Function UpStr(S: String): String;
Var
 I: Integer;
Begin
 For I := 1 To Length(S) Do
  If S[I] In ['a'..'z'] Then S[I] := Chr(Ord(S[I]) - 32);
 UpStr := S;
End;

{ @description: Indique si S commence par Prefix, sans tenir compte
    de la casse.
  @param S Chaine a tester
  @param Prefix Prefixe recherche
  @return Vrai si S commence par Prefix }
Function StartsWithStr(S, Prefix: String): Boolean;
Begin
 StartsWithStr := (UpStr(Copy(S, 1, Length(Prefix))) = UpStr(Prefix));
End;

{ @description: Construit une chaine de N espaces (au moins zero).
  @param N Nombre d espaces souhaite
  @return Chaine de N espaces }
Function SpaceStr(N: Integer): String;
Var
 I: Integer;
 Accum: String;
Begin
 Accum := '';
 For I := 1 To N Do Accum := Accum + ' ';
 SpaceStr := Accum;
End;

{ @description: Complete S a droite avec des espaces jusqu a la
    largeur W (ne tronque jamais S si elle est deja plus longue).
  @param S Chaine a completer
  @param W Largeur totale souhaitee
  @return Chaine completee }
Function PadRight(S: String; W: Integer): String;
Begin
 If Length(S) < W Then S := S + SpaceStr(W - Length(S));
 PadRight := S;
End;

{ @description: Convertit un octet en deux chiffres hexadecimaux
    minuscules, sans prefixe.
  @param B Octet a convertir
  @return Deux chiffres hexadecimaux (ex: "1f") }
Function HexByte(B: Byte): String;
Const
 Digits: Array[0..15] Of Char = '0123456789abcdef';
Begin
 HexByte := Digits[(B Shr 4) And 15] + Digits[B And 15];
End;

{ @description: Convertit un entier 32 bits (signe ou non, vu comme
    un patron binaire brut) en hexadecimal minuscule, sans prefixe ni
    zeros de tete inutiles (au moins un chiffre, "0" pour la valeur
    nulle). Passe par Move plutot que par des decalages binaires sur
    un type signe, pour rester independant de leur comportement exact.
  @param V Valeur a convertir (interpretee en non signe)
  @return Chiffres hexadecimaux de V, sans prefixe }
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

{ @description: Comme ToHexU, mais pour une valeur signee destinee a
    un affichage de deplacement ("-0x4", "0x8"). La valeur 0 produit
    une chaine vide (aucun deplacement a afficher).
  @param V Valeur signee a convertir
  @return "-0xNN", "0xNN", ou chaine vide si V = 0 }
Function ToHexSignedDisp(V: LongInt): String;
Begin
 If V = 0 Then ToHexSignedDisp := ''
 Else If V < 0 Then ToHexSignedDisp := '-0x' + ToHexU(-V)
 Else ToHexSignedDisp := '0x' + ToHexU(V);
End;

{ @description: Formate une adresse sur un nombre fixe de chiffres
    hexadecimaux (complete a gauche par des zeros), sans prefixe.
  @param V Valeur a formater
  @param Digits Nombre de chiffres hexadecimaux souhaite
  @return Chaine hexadecimale de longueur exactement Digits (ou plus
    si V ne rentre pas dans Digits chiffres) }
Function ToHexFixed(V: LongInt; Digits: Integer): String;
Var
 S: String;
Begin
 S := ToHexU(V);
 While Length(S) < Digits Do S := '0' + S;
 ToHexFixed := S;
End;

{ ============================================================
  LECTURE BAS NIVEAU DU TAMPON FICHIER
  ============================================================ }

{ @description: Lit un octet a la position Off du tampon fichier (0
    si hors limites, pour eviter un acces invalide).
  @param Off Decalage (0-based) dans le fichier
  @return Octet lu }
Function GetByte(Off: LongInt): Byte;
Begin
 If (Off < 0) Or (Off >= BufSize) Then GetByte := 0
 Else GetByte := Buf^[Off];
End;

{ @description: Lit un mot de 16 bits non signe en little-endian a la
    position Off.
  @param Off Decalage (0-based) dans le fichier
  @return Valeur 16 bits lue }
Function GetWord(Off: LongInt): Word;
Begin
 GetWord := GetByte(Off) Or (GetByte(Off + 1) Shl 8);
End;

{ @description: Lit un mot de 32 bits en little-endian a la position
    Off (interprete comme LongInt, donc potentiellement negatif si le
    bit de poids fort est positionne).
  @param Off Decalage (0-based) dans le fichier
  @return Valeur 32 bits lue }
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

{ @description: Lit une chaine terminee par un octet nul a partir de
    la position Off, avec une longueur maximale de securite.
  @param Off Decalage (0-based) du premier caractere
  @param MaxLen Longueur maximale a lire (securite anti-boucle)
  @return Chaine lue (sans le terminateur nul) }
Function GetCStr(Off: LongInt; MaxLen: Integer): String;
Var
 S: String;
 C: Byte;
 N: Integer;
Begin
 S := '';
 N := 0;
 C := GetByte(Off);
 While (C <> 0) And (N < MaxLen) Do Begin
  S := S + Chr(C);
  Inc(N);
  Inc(Off);
  C := GetByte(Off);
 End;
 GetCStr := S;
End;

{ @description: Charge entierement le fichier FName en memoire (tas)
    dans Buf/BufSize. Arrete le programme avec un message d erreur si
    le fichier est introuvable ou illisible.
  @param FName Chemin du fichier a charger }
Procedure LoadFile(FName: String);
Var
 F: File;
 NRead: LongInt;
Begin
 Assign(F, FName);
 {$I-} Reset(F, 1); {$I+}
 If IOResult <> 0 Then Begin
  WriteLn('Erreur : impossible d''ouvrir "', FName, '"');
  Halt(1);
 End;
 BufSize := FileSize(F);
 If BufSize <= 0 Then Begin
  WriteLn('Erreur : fichier vide ou taille illisible.');
  Close(F);
  Halt(1);
 End;
 GetMem(Buf, BufSize);
 {$I-} BlockRead(F, Buf^, BufSize, NRead); {$I+}
 Close(F);
 If NRead <> BufSize Then Begin
  WriteLn('Erreur : lecture incomplete du fichier.');
  Halt(1);
 End;
End;

{ ============================================================
  DETECTION DU FORMAT
  ============================================================ }

{ @description: Identifie le format binaire (ELF/PE, 32/64 bits) a
    partir des octets magiques en tete de fichier, et le place dans
    BinFormat (FMT_UNKNOWN si non reconnu). }
Procedure DetectFormat;
Var
 PEOff: LongInt;
Begin
 BinFormat := FMT_UNKNOWN;
 If BufSize < 4 Then Exit;
 If (GetByte(0) = $7F) And (GetByte(1) = Ord('E')) And
    (GetByte(2) = Ord('L')) And (GetByte(3) = Ord('F')) Then Begin
  If GetByte(4) = 2 Then BinFormat := FMT_ELF64
  Else BinFormat := FMT_ELF32;
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
 End;
End;

{ ============================================================
  ANALYSE DU FORMAT ELF (32 et 64 bits)
  ============================================================ }

{ @description: Remplit Sections[]/Symbols[] a partir d un fichier
    ELF deja charge (32 ou 64 bits). Les champs 64 bits sont lus
    integralement mais les adresses/tailles ne sont conservees que
    sur 32 bits pour l affichage (suffisant pour des binaires de
    taille raisonnable ; un veritable support 64 bits complet
    demanderait l arithmetique Int64 sur toute la chaine). }
Procedure ParseELF;
Var
 Is64: Boolean;
 ShOff, ShEntSize, ShNum, ShStrNdx: LongInt;
 StrTabOff: LongInt;
 I: Integer;
 Base: LongInt;
 SymTabOff, SymTabSize, SymEntSize, SymStrOff: LongInt;
 NameOff, Value: LongInt;
 SecIdx: Integer;
 Info: Byte;
 SName: String;
 FoundSymTab: Boolean;
Begin
 Is64 := (BinFormat = FMT_ELF64);
 EntryPoint := 0;
 ImageBase := 0;
 If Is64 Then Begin
  EntryPoint := GetDWord(24);          { partie basse de e_entry }
  ShOff      := GetDWord(40);          { partie basse de e_shoff }
  ShEntSize  := GetWord(58);
  ShNum      := GetWord(60);
  ShStrNdx   := GetWord(62);
 End Else Begin
  EntryPoint := GetDWord(24);
  ShOff      := GetDWord(32);
  ShEntSize  := GetWord(46);
  ShNum      := GetWord(48);
  ShStrNdx   := GetWord(50);
 End;
 If (ShOff <= 0) Or (ShNum <= 0) Or (ShNum > MaxSections) Then Exit;
 { Localiser la table de noms de sections (.shstrtab) }
 If Is64 Then StrTabOff := GetDWord(ShOff + ShStrNdx * ShEntSize + 24)
 Else StrTabOff := GetDWord(ShOff + ShStrNdx * ShEntSize + 16);
 SectionCount := 0;
 FoundSymTab := False;
 SymTabOff := 0; SymTabSize := 0; SymEntSize := 0; SymStrOff := 0;
 For I := 0 To ShNum - 1 Do Begin
  Base := ShOff + I * ShEntSize;
  Inc(SectionCount);
  If Is64 Then Begin
   NameOff := GetDWord(Base);
   Sections[SectionCount].Name    := GetCStr(StrTabOff + NameOff, 31);
   Sections[SectionCount].VAddr   := GetDWord(Base + 16);
   Sections[SectionCount].FileOff := GetDWord(Base + 24);
   Sections[SectionCount].Size    := GetDWord(Base + 32);
   Sections[SectionCount].IsCode  := (GetDWord(Base + 4) = 1) And
    ((GetDWord(Base + 8) And 4) <> 0); { SHT_PROGBITS + SHF_EXECINSTR }
   If GetDWord(Base + 4) = 2 Then Begin { SHT_SYMTAB }
    SymTabOff  := GetDWord(Base + 24);
    SymTabSize := GetDWord(Base + 32);
    SymEntSize := GetDWord(Base + 56);
    SymStrOff  := GetDWord(ShOff + GetDWord(Base + 28) * ShEntSize + 24);
    FoundSymTab := True;
   End;
  End Else Begin
   NameOff := GetDWord(Base);
   Sections[SectionCount].Name    := GetCStr(StrTabOff + NameOff, 31);
   Sections[SectionCount].VAddr   := GetDWord(Base + 12);
   Sections[SectionCount].FileOff := GetDWord(Base + 16);
   Sections[SectionCount].Size    := GetDWord(Base + 20);
   Sections[SectionCount].IsCode  := (GetDWord(Base + 4) = 1) And
    ((GetDWord(Base + 8) And 4) <> 0);
   If GetDWord(Base + 4) = 2 Then Begin { SHT_SYMTAB }
    SymTabOff  := GetDWord(Base + 16);
    SymTabSize := GetDWord(Base + 20);
    SymEntSize := GetDWord(Base + 36);
    SymStrOff  := GetDWord(ShOff + GetDWord(Base + 28) * ShEntSize + 16);
    FoundSymTab := True;
   End;
  End;
 End;
 { Table des symboles ELF (.symtab / .strtab) }
 SymbolCount := 0;
 If FoundSymTab And (SymEntSize > 0) Then Begin
  For I := 0 To (SymTabSize Div SymEntSize) - 1 Do Begin
   If SymbolCount >= MaxSymbols Then Break;
   Base := SymTabOff + I * SymEntSize;
   If Is64 Then Begin
    NameOff := GetDWord(Base);
    Info    := GetByte(Base + 4);
    Value   := GetDWord(Base + 8);
    SecIdx  := GetWord(Base + 6);
   End Else Begin
    NameOff := GetDWord(Base);
    Value   := GetDWord(Base + 4);
    Info    := GetByte(Base + 12);
    SecIdx  := GetWord(Base + 14);
   End;
   SName := GetCStr(SymStrOff + NameOff, 63);
   If SName <> '' Then Begin
    Inc(SymbolCount);
    Symbols[SymbolCount].Name   := SName;
    Symbols[SymbolCount].Value  := Value;
    Symbols[SymbolCount].SecIdx := SecIdx;
    Symbols[SymbolCount].IsFunc := (Info And 15) = 2; { STT_FUNC }
   End;
  End;
 End;
End;

{ ============================================================
  ANALYSE DU FORMAT PE / PE32(+)
  ============================================================ }

{ @description: Remplit Sections[]/Symbols[] a partir d un fichier
    PE deja charge (32 ou 64 bits). La table de symboles COFF est
    rarement presente dans les executables PE modernes (la plupart
    sont compiles sans /DEBUG:COFF) : SymbolCount peut rester a 0. }
Procedure ParsePE;
Var
 PEOff, OptOff, SecOff: LongInt;
 NumSections, SizeOptHdr: Integer;
 I, J: Integer;
 Base: LongInt;
 RawName: String;
 SymTabOff, NumSyms, StrTabOff: LongInt;
 SName: String;
 ZeroLead: Boolean;
 StrOffInTab: LongInt;
Begin
 PEOff := GetDWord($3C);
 NumSections := GetWord(PEOff + 6);
 SizeOptHdr  := GetWord(PEOff + 20);
 SymTabOff   := GetDWord(PEOff + 12);
 NumSyms     := GetDWord(PEOff + 16);
 OptOff := PEOff + 24;
 ImageBase  := GetDWord(OptOff + 28);
 EntryPoint := ImageBase + GetDWord(OptOff + 16);
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
  Sections[SectionCount].Name    := RawName;
  Sections[SectionCount].VAddr   := ImageBase + GetDWord(Base + 12);
  Sections[SectionCount].FileOff := GetDWord(Base + 20);
  Sections[SectionCount].Size    := GetDWord(Base + 8);
  Sections[SectionCount].IsCode  := (GetDWord(Base + 36) And $20000000) <> 0;
 End;
 { Table de symboles COFF (souvent absente des PE modernes) }
 SymbolCount := 0;
 If (SymTabOff > 0) And (NumSyms > 0) Then Begin
  StrTabOff := SymTabOff + NumSyms * 18;
  For I := 0 To NumSyms - 1 Do Begin
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
    Symbols[SymbolCount].Name   := SName;
    Symbols[SymbolCount].Value  := ImageBase + GetDWord(Base + 8);
    Symbols[SymbolCount].SecIdx := GetWord(Base + 12);
    Symbols[SymbolCount].IsFunc := True; { COFF ne distingue pas finement ici }
   End;
  End;
 End;
End;

{ ============================================================
  DESASSEMBLEUR X86 32 BITS (JEU D INSTRUCTIONS COURANT)
  ============================================================ }

Const
 Reg32Names: Array[0..7] Of String[4] =
  ('eax', 'ecx', 'edx', 'ebx', 'esp', 'ebp', 'esi', 'edi');
 Reg16Names: Array[0..7] Of String[3] =
  ('ax', 'cx', 'dx', 'bx', 'sp', 'bp', 'si', 'di');
 Reg8Names: Array[0..7] Of String[3] =
  ('al', 'cl', 'dl', 'bl', 'ah', 'ch', 'dh', 'bh');
 Cc16Names: Array[0..15] Of String[4] = (
  'o', 'no', 'b', 'ae', 'e', 'ne', 'be', 'a',
  's', 'ns', 'p', 'np', 'l', 'ge', 'le', 'g');
 Grp1Names: Array[0..7] Of String[4] = (
  'add', 'or', 'adc', 'sbb', 'and', 'sub', 'xor', 'cmp');
 ShiftNames: Array[0..7] Of String[4] = (
  'rol', 'ror', 'rcl', 'rcr', 'shl', 'shr', 'sal', 'sar');

{ @description: Nom du registre 32 bits numero R (0..7).
  @param R Numero de registre (champ Reg/RM d un ModRM)
  @return Nom du registre, prefixe par % }
Function Reg32(R: Byte): String;
Begin
 Reg32 := '%' + Reg32Names[R And 7];
End;

{ @description: Nom du registre 16 bits numero R (0..7).
  @param R Numero de registre
  @return Nom du registre, prefixe par % }
Function Reg16(R: Byte): String;
Begin
 Reg16 := '%' + Reg16Names[R And 7];
End;

{ @description: Nom du registre 8 bits numero R (0..7).
  @param R Numero de registre
  @return Nom du registre, prefixe par % }
Function Reg8(R: Byte): String;
Begin
 Reg8 := '%' + Reg8Names[R And 7];
End;

{ @description: Decode l octet ModRM (et l eventuel octet SIB et
    deplacement) a la position Off, et renvoie la representation
    textuelle (syntaxe AT&T) de l operande memoire/registre qu il
    designe. Le nombre total d octets consommes (ModRM + SIB +
    deplacement) est renvoye via Consumed ; le champ Reg du ModRM
    (utilise soit comme registre, soit comme selecteur de
    sous-instruction) est renvoye via RegField.
  @param Off Decalage du premier octet (le ModRM lui-meme)
  @param Consumed Nombre d octets consommes (sortie)
  @param RegField Champ Reg (3 bits) du ModRM (sortie)
  @param Wide Vrai pour un registre 32 bits, faux pour 8 bits, quand
    le mode est registre direct (Mod=11)
  @return Texte de l operande (registre ou adresse memoire) }
Function DecodeModRM(Off: LongInt; Var Consumed: Integer;
 Var RegField: Byte; Wide: Boolean): String;
Var
 ModB, RM, Scale, Idx, BaseR: Byte;
 Disp: LongInt;
 HasSIB, NoBase: Boolean;
 P: LongInt;
 Inner: String;
 DispTxt: String;
Begin
 P := Off;
 ModB := (GetByte(P) Shr 6) And 3;
 RegField := (GetByte(P) Shr 3) And 7;
 RM := GetByte(P) And 7;
 Inc(P);
 Consumed := 1;
 If ModB = 3 Then Begin
  If Wide Then DecodeModRM := Reg32(RM) Else DecodeModRM := Reg8(RM);
  Exit;
 End;
 HasSIB := (RM = 4);
 Scale := 0; Idx := 0; BaseR := 0; NoBase := False;
 If HasSIB Then Begin
  Scale := (GetByte(P) Shr 6) And 3;
  Idx   := (GetByte(P) Shr 3) And 7;
  BaseR := GetByte(P) And 7;
  Inc(P); Inc(Consumed);
  NoBase := (BaseR = 5) And (ModB = 0);
 End;
 Disp := 0;
 If (ModB = 0) And (RM = 5) And (Not HasSIB) Then Begin
  Disp := GetDWord(P); P := P + 4; Consumed := Consumed + 4;
  DecodeModRM := '0x' + ToHexU(Disp);
  Exit;
 End;
 If NoBase Then Begin
  Disp := GetDWord(P); P := P + 4; Consumed := Consumed + 4;
 End Else If ModB = 1 Then Begin
  Disp := ShortInt(GetByte(P)); Inc(P); Inc(Consumed);
 End Else If ModB = 2 Then Begin
  Disp := GetDWord(P); P := P + 4; Consumed := Consumed + 4;
 End;
 Inner := '';
 If HasSIB Then Begin
  If Not NoBase Then Inner := Reg32(BaseR);
  If Idx <> 4 Then Begin { Idx=4 (esp) signifie "pas d index" }
   If Inner <> '' Then Inner := Inner + ',';
   Inner := Inner + Reg32(Idx) + ',' + Chr(Ord('0') + (1 Shl Scale));
  End;
 End Else
  Inner := Reg32(RM);
 DispTxt := ToHexSignedDisp(Disp);
 DecodeModRM := DispTxt + '(' + Inner + ')';
End;

{ @description: Desassemble une seule instruction x86 32 bits a
    partir du decalage Off dans le fichier, en remplissant Mnemonic
    et Operands (syntaxe AT&T, comme objdump). Les opcodes non
    reconnus produisent le mnemonique "(bad)" et avancent d un octet,
    pour que le flux de desassemblage ne se bloque jamais. VAddrBase
    est l adresse virtuelle correspondant a Off : Off sert a LIRE les
    octets dans le fichier, VAddrBase sert a CALCULER les cibles des
    branchements relatifs (call/jmp/jcc), les deux pouvant differer
    largement (le decalage fichier d une section n a aucun rapport
    avec son adresse de chargement en memoire).
  @param Off Decalage de l instruction dans le fichier
  @param VAddrBase Adresse virtuelle correspondant a Off
  @param Mnemonic Mnemonique de l instruction (sortie)
  @param Operands Operandes formates, syntaxe AT&T (sortie)
  @return Nombre d octets occupes par l instruction }
Function DisasmOne(Off, VAddrBase: LongInt;
 Var Mnemonic, Operands: String): Integer;
Var
 Op, Op2: Byte;
 P: LongInt;
 Len: Integer;
 RM: String;
 RegF: Byte;
 Imm: LongInt;
 Rel: LongInt;
Begin
 P := Off;
 Op := GetByte(P);
 Inc(P);
 Mnemonic := '(bad)';
 Operands := '';

 { ----- push/pop registre ----- }
 If (Op >= $50) And (Op <= $57) Then Begin
  Mnemonic := 'push'; Operands := Reg32(Op - $50);
 End Else If (Op >= $58) And (Op <= $5F) Then Begin
  Mnemonic := 'pop'; Operands := Reg32(Op - $58);
 End

 { ----- push immediat ----- }
 Else If Op = $68 Then Begin
  Imm := GetDWord(P); P := P + 4;
  Mnemonic := 'push'; Operands := '$0x' + ToHexU(Imm);
 End Else If Op = $6A Then Begin
  Imm := ShortInt(GetByte(P)); Inc(P);
  Mnemonic := 'push'; Operands := '$0x' + ToHexU(Imm);
 End

 { ----- mov reg32, imm32 ----- }
 Else If (Op >= $B8) And (Op <= $BF) Then Begin
  Imm := GetDWord(P); P := P + 4;
  Mnemonic := 'mov';
  Operands := '$0x' + ToHexU(Imm) + ',' + Reg32(Op - $B8);
 End

 { ----- inc/dec reg32 ----- }
 Else If (Op >= $40) And (Op <= $47) Then Begin
  Mnemonic := 'inc'; Operands := Reg32(Op - $40);
 End Else If (Op >= $48) And (Op <= $4F) Then Begin
  Mnemonic := 'dec'; Operands := Reg32(Op - $48);
 End

 { ----- mov r/m32,r32 (89) / mov r32,r/m32 (8B) ----- }
 Else If Op = $89 Then Begin
  RM := DecodeModRM(P, Len, RegF, True); P := P + Len;
  Mnemonic := 'mov'; Operands := Reg32(RegF) + ',' + RM;
 End Else If Op = $8B Then Begin
  RM := DecodeModRM(P, Len, RegF, True); P := P + Len;
  Mnemonic := 'mov'; Operands := RM + ',' + Reg32(RegF);
 End

 { ----- mov r/m8,r8 (88) / mov r8,r/m8 (8A) ----- }
 Else If Op = $88 Then Begin
  RM := DecodeModRM(P, Len, RegF, False); P := P + Len;
  Mnemonic := 'mov'; Operands := Reg8(RegF) + ',' + RM;
 End Else If Op = $8A Then Begin
  RM := DecodeModRM(P, Len, RegF, False); P := P + Len;
  Mnemonic := 'mov'; Operands := RM + ',' + Reg8(RegF);
 End

 { ----- mov r/m32, imm32 (C7 /0) ----- }
 Else If Op = $C7 Then Begin
  RM := DecodeModRM(P, Len, RegF, True); P := P + Len;
  Imm := GetDWord(P); P := P + 4;
  Mnemonic := 'mov'; Operands := '$0x' + ToHexU(Imm) + ',' + RM;
 End Else If Op = $C6 Then Begin
  RM := DecodeModRM(P, Len, RegF, False); P := P + Len;
  Imm := GetByte(P); Inc(P);
  Mnemonic := 'mov'; Operands := '$0x' + ToHexU(Imm) + ',' + RM;
 End

 { ----- lea r32, m ----- }
 Else If Op = $8D Then Begin
  RM := DecodeModRM(P, Len, RegF, True); P := P + Len;
  Mnemonic := 'lea'; Operands := RM + ',' + Reg32(RegF);
 End

 { ----- groupe arithmetique 00-3F (add/or/adc/sbb/and/sub/xor/cmp) -----
   Les 8 mnemoniques se repetent tous les 8 opcodes ; au sein d un
   groupe, +0/+1 = r/m<-Gb/Gv->dest=r/m, +2/+3 = inverse (dest=reg). }
 Else If Op < $40 Then Begin
  Case Op And 7 Of
   0: Begin
       RM := DecodeModRM(P, Len, RegF, False); P := P + Len;
       Mnemonic := Grp1Names[(Op Shr 3) And 7];
       Operands := Reg8(RegF) + ',' + RM;
      End;
   1: Begin
       RM := DecodeModRM(P, Len, RegF, True); P := P + Len;
       Mnemonic := Grp1Names[(Op Shr 3) And 7];
       Operands := Reg32(RegF) + ',' + RM;
      End;
   2: Begin
       RM := DecodeModRM(P, Len, RegF, False); P := P + Len;
       Mnemonic := Grp1Names[(Op Shr 3) And 7];
       Operands := RM + ',' + Reg8(RegF);
      End;
   3: Begin
       RM := DecodeModRM(P, Len, RegF, True); P := P + Len;
       Mnemonic := Grp1Names[(Op Shr 3) And 7];
       Operands := RM + ',' + Reg32(RegF);
      End;
   4: Begin
       Imm := GetByte(P); Inc(P);
       Mnemonic := Grp1Names[(Op Shr 3) And 7];
       Operands := '$0x' + ToHexU(Imm) + ',' + Reg8(0);
      End;
   5: Begin
       Imm := GetDWord(P); P := P + 4;
       Mnemonic := Grp1Names[(Op Shr 3) And 7];
       Operands := '$0x' + ToHexU(Imm) + ',' + Reg32(0);
      End;
  Else
   Mnemonic := '(bad)';
  End;
 End

 { ----- groupe 1 avec immediat : 80/81/83 (add/or/.../cmp r/m,imm) ----- }
 Else If Op = $80 Then Begin
  RM := DecodeModRM(P, Len, RegF, False); P := P + Len;
  Imm := GetByte(P); Inc(P);
  Mnemonic := Grp1Names[RegF And 7];
  Operands := '$0x' + ToHexU(Imm) + ',' + RM;
 End Else If Op = $81 Then Begin
  RM := DecodeModRM(P, Len, RegF, True); P := P + Len;
  Imm := GetDWord(P); P := P + 4;
  Mnemonic := Grp1Names[RegF And 7];
  Operands := '$0x' + ToHexU(Imm) + ',' + RM;
 End Else If Op = $83 Then Begin
  RM := DecodeModRM(P, Len, RegF, True); P := P + Len;
  Imm := ShortInt(GetByte(P)); Inc(P);
  Mnemonic := Grp1Names[RegF And 7];
  Operands := '$0x' + ToHexU(Imm) + ',' + RM;
 End

 { ----- test r/m,r ; test AL/eAX,imm ----- }
 Else If Op = $84 Then Begin
  RM := DecodeModRM(P, Len, RegF, False); P := P + Len;
  Mnemonic := 'test'; Operands := Reg8(RegF) + ',' + RM;
 End Else If Op = $85 Then Begin
  RM := DecodeModRM(P, Len, RegF, True); P := P + Len;
  Mnemonic := 'test'; Operands := Reg32(RegF) + ',' + RM;
 End Else If Op = $A8 Then Begin
  Imm := GetByte(P); Inc(P);
  Mnemonic := 'test'; Operands := '$0x' + ToHexU(Imm) + ',' + Reg8(0);
 End Else If Op = $A9 Then Begin
  Imm := GetDWord(P); P := P + 4;
  Mnemonic := 'test'; Operands := '$0x' + ToHexU(Imm) + ',' + Reg32(0);
 End

 { ----- call/jmp relatifs ----- }
 Else If Op = $E8 Then Begin
  Rel := GetDWord(P); P := P + 4;
  Mnemonic := 'call'; Operands := '0x' + ToHexU(VAddrBase + (P - Off) + Rel);
 End Else If Op = $E9 Then Begin
  Rel := GetDWord(P); P := P + 4;
  Mnemonic := 'jmp'; Operands := '0x' + ToHexU(VAddrBase + (P - Off) + Rel);
 End Else If Op = $EB Then Begin
  Rel := ShortInt(GetByte(P)); Inc(P);
  Mnemonic := 'jmp'; Operands := '0x' + ToHexU(VAddrBase + (P - Off) + Rel);
 End

 { ----- Jcc rel8 (70-7F) ----- }
 Else If (Op >= $70) And (Op <= $7F) Then Begin
  Rel := ShortInt(GetByte(P)); Inc(P);
  Mnemonic := 'j' + Cc16Names[Op - $70];
  Operands := '0x' + ToHexU(VAddrBase + (P - Off) + Rel);
 End

 { ----- ret / leave / nop / int ----- }
 Else If Op = $C3 Then Begin
  Mnemonic := 'ret';
 End Else If Op = $C2 Then Begin
  Imm := GetWord(P); P := P + 2;
  Mnemonic := 'ret'; Operands := '$0x' + ToHexU(Imm);
 End Else If Op = $C9 Then Begin
  Mnemonic := 'leave';
 End Else If Op = $90 Then Begin
  Mnemonic := 'nop';
 End Else If Op = $CC Then Begin
  Mnemonic := 'int3';
 End Else If Op = $CD Then Begin
  Imm := GetByte(P); Inc(P);
  Mnemonic := 'int'; Operands := '$0x' + ToHexU(Imm);
 End Else If Op = $98 Then Begin
  Mnemonic := 'cwde';
 End Else If Op = $99 Then Begin
  Mnemonic := 'cdq';
 End

 { ----- groupe decalages : C0/C1 (imm8), D0-D3 (1 ou CL) ----- }
 Else If Op = $C0 Then Begin
  RM := DecodeModRM(P, Len, RegF, False); P := P + Len;
  Imm := GetByte(P); Inc(P);
  Mnemonic := ShiftNames[RegF And 7];
  Operands := '$0x' + ToHexU(Imm) + ',' + RM;
 End Else If Op = $C1 Then Begin
  RM := DecodeModRM(P, Len, RegF, True); P := P + Len;
  Imm := GetByte(P); Inc(P);
  Mnemonic := ShiftNames[RegF And 7];
  Operands := '$0x' + ToHexU(Imm) + ',' + RM;
 End Else If Op = $D0 Then Begin
  RM := DecodeModRM(P, Len, RegF, False); P := P + Len;
  Mnemonic := ShiftNames[RegF And 7]; Operands := RM;
 End Else If Op = $D1 Then Begin
  RM := DecodeModRM(P, Len, RegF, True); P := P + Len;
  Mnemonic := ShiftNames[RegF And 7]; Operands := RM;
 End Else If Op = $D2 Then Begin
  RM := DecodeModRM(P, Len, RegF, False); P := P + Len;
  Mnemonic := ShiftNames[RegF And 7]; Operands := '%cl,' + RM;
 End Else If Op = $D3 Then Begin
  RM := DecodeModRM(P, Len, RegF, True); P := P + Len;
  Mnemonic := ShiftNames[RegF And 7]; Operands := '%cl,' + RM;
 End

 { ----- groupe FE/FF : inc/dec/call/jmp/push selon RegField ----- }
 Else If Op = $FE Then Begin
  RM := DecodeModRM(P, Len, RegF, False); P := P + Len;
  If (RegF And 7) = 0 Then Mnemonic := 'inc' Else Mnemonic := 'dec';
  Operands := RM;
 End Else If Op = $FF Then Begin
  RM := DecodeModRM(P, Len, RegF, True); P := P + Len;
  Case RegF And 7 Of
   0: Mnemonic := 'inc';
   1: Mnemonic := 'dec';
   2: Mnemonic := 'call';
   4: Mnemonic := 'jmp';
   6: Mnemonic := 'push';
  Else
   Mnemonic := '(bad)';
  End;
  If Mnemonic <> '(bad)' Then Operands := '*' + RM;
 End

 { ----- groupe F6/F7 : test/not/neg/mul/imul/div/idiv ----- }
 Else If Op = $F6 Then Begin
  RM := DecodeModRM(P, Len, RegF, False); P := P + Len;
  Case RegF And 7 Of
   0, 1: Begin
          Imm := GetByte(P); Inc(P);
          Mnemonic := 'test'; Operands := '$0x' + ToHexU(Imm) + ',' + RM;
         End;
   2: Begin Mnemonic := 'not'; Operands := RM; End;
   3: Begin Mnemonic := 'neg'; Operands := RM; End;
   4: Begin Mnemonic := 'mul'; Operands := RM; End;
   5: Begin Mnemonic := 'imul'; Operands := RM; End;
   6: Begin Mnemonic := 'div'; Operands := RM; End;
   7: Begin Mnemonic := 'idiv'; Operands := RM; End;
  End;
 End Else If Op = $F7 Then Begin
  RM := DecodeModRM(P, Len, RegF, True); P := P + Len;
  Case RegF And 7 Of
   0, 1: Begin
          Imm := GetDWord(P); P := P + 4;
          Mnemonic := 'test'; Operands := '$0x' + ToHexU(Imm) + ',' + RM;
         End;
   2: Begin Mnemonic := 'not'; Operands := RM; End;
   3: Begin Mnemonic := 'neg'; Operands := RM; End;
   4: Begin Mnemonic := 'mul'; Operands := RM; End;
   5: Begin Mnemonic := 'imul'; Operands := RM; End;
   6: Begin Mnemonic := 'div'; Operands := RM; End;
   7: Begin Mnemonic := 'idiv'; Operands := RM; End;
  End;
 End

 { ----- imul r32, r/m32, imm (69 = imm32, 6B = imm8) ----- }
 Else If Op = $69 Then Begin
  RM := DecodeModRM(P, Len, RegF, True); P := P + Len;
  Imm := GetDWord(P); P := P + 4;
  Mnemonic := 'imul';
  Operands := '$0x' + ToHexU(Imm) + ',' + RM + ',' + Reg32(RegF);
 End Else If Op = $6B Then Begin
  RM := DecodeModRM(P, Len, RegF, True); P := P + Len;
  Imm := ShortInt(GetByte(P)); Inc(P);
  Mnemonic := 'imul';
  Operands := '$0x' + ToHexU(Imm) + ',' + RM + ',' + Reg32(RegF);
 End

 { ----- opcodes etendus 0F xx (Jcc rel32, movzx, movsx) ----- }
 Else If Op = $0F Then Begin
  Op2 := GetByte(P); Inc(P);
  If (Op2 >= $80) And (Op2 <= $8F) Then Begin
   Rel := GetDWord(P); P := P + 4;
   Mnemonic := 'j' + Cc16Names[Op2 - $80];
   Operands := '0x' + ToHexU(VAddrBase + (P - Off) + Rel);
  End Else If Op2 = $B6 Then Begin
   RM := DecodeModRM(P, Len, RegF, False); P := P + Len;
   Mnemonic := 'movzbl'; Operands := RM + ',' + Reg32(RegF);
  End Else If Op2 = $B7 Then Begin
   RM := DecodeModRM(P, Len, RegF, True); P := P + Len;
   Mnemonic := 'movzwl'; Operands := RM + ',' + Reg32(RegF);
  End Else If Op2 = $BE Then Begin
   RM := DecodeModRM(P, Len, RegF, False); P := P + Len;
   Mnemonic := 'movsbl'; Operands := RM + ',' + Reg32(RegF);
  End Else If Op2 = $BF Then Begin
   RM := DecodeModRM(P, Len, RegF, True); P := P + Len;
   Mnemonic := 'movswl'; Operands := RM + ',' + Reg32(RegF);
  End Else
   Mnemonic := '(bad)';
 End;

 If P <= Off Then P := Off + 1; { securite anti-boucle infinie }
 DisasmOne := P - Off;
End;

{ ============================================================
  RECHERCHE DE SYMBOLE / SECTION POUR L AFFICHAGE
  ============================================================ }

{ @description: Cherche un symbole dont la valeur correspond
    exactement a Addr, pour l etiquette "adresse <nom>:" affichee au
    debut de chaque fonction desassemblee.
  @param Addr Adresse (VMA) recherchee
  @return Nom du symbole trouve, ou chaine vide si aucun }
Function FindSymbolAt(Addr: LongInt): String;
Var
 I: Integer;
Begin
 FindSymbolAt := '';
 For I := 1 To SymbolCount Do
  If Symbols[I].Value = Addr Then Begin
   FindSymbolAt := Symbols[I].Name;
   Exit;
  End;
End;

{ @description: Cherche la section dont l intervalle [VAddr,
    VAddr+Size) contient Addr.
  @param Addr Adresse (VMA) recherchee
  @return Index (1-based) de la section, ou 0 si aucune ne contient
    cette adresse }
Function FindSectionAt(Addr: LongInt): Integer;
Var
 I: Integer;
Begin
 FindSectionAt := 0;
 For I := 1 To SectionCount Do
  If (Addr >= Sections[I].VAddr) And
     (Addr < Sections[I].VAddr + Sections[I].Size) Then Begin
   FindSectionAt := I;
   Exit;
  End;
End;

{ ============================================================
  COMMANDES
  ============================================================ }

{ @description: Convertit un entier en chaine decimale.
  @param N Valeur a convertir
  @return Representation decimale de N }
Function IntToStr(N: LongInt): String;
Var
 S: String;
Begin
 Str(N, S);
 IntToStr := S;
End;

{ @description: Nom du format binaire detecte, pour l affichage
    d entete (style "objdump").
  @return Nom du format (ex: "elf32-i386", "pei-i386") }
Function FormatName: String;
Begin
 Case BinFormat Of
  FMT_ELF32: FormatName := 'elf32-i386';
  FMT_ELF64: FormatName := 'elf64-x86-64 (en-tetes seulement)';
  FMT_PE32:  FormatName := 'pei-i386';
  FMT_PE64:  FormatName := 'pei-x86-64 (en-tetes seulement)';
 Else
  FormatName := 'inconnu';
 End;
End;

{ @description: Implemente l option -h : affiche la liste des
    sections (index, nom, taille, adresse virtuelle), comme
    "objdump -h". }
Procedure CmdHeaders;
Var
 I: Integer;
Begin
 WriteLn;
 WriteLn(InFileName, ':     format ', FormatName);
 WriteLn('Point d''entree (entry point) : 0x', ToHexU(EntryPoint));
 WriteLn;
 WriteLn('Sections:');
 WriteLn('Idx Name          Size      VMA');
 For I := 1 To SectionCount Do
  WriteLn(PadRight(IntToStr(I - 1), 4),
   PadRight(Sections[I].Name, 14),
   PadRight(ToHexFixed(Sections[I].Size, 8), 10),
   ToHexFixed(Sections[I].VAddr, 8));
End;

{ @description: Implemente l option -t : affiche la table des
    symboles (adresse, section, nom), comme "objdump -t". }
Procedure CmdSymbols;
Var
 I, SIdx: Integer;
 SecName: String;
Begin
 WriteLn;
 WriteLn('SYMBOL TABLE:');
 If SymbolCount = 0 Then Begin
  WriteLn('(aucun symbole trouve dans ce fichier)');
  Exit;
 End;
 For I := 1 To SymbolCount Do Begin
  SIdx := FindSectionAt(Symbols[I].Value);
  If SIdx > 0 Then SecName := Sections[SIdx].Name Else SecName := '*UND*';
  WriteLn(ToHexFixed(Symbols[I].Value, 8), ' ',
   PadRight(SecName, 10),
   PadRight(Symbols[I].Name, 0));
 End;
End;

{ @description: Implemente l option -d : desassemble toutes les
    sections de code (IsCode = vrai), avec une etiquette de symbole
    au debut de chaque fonction connue, comme "objdump -d". }
Procedure CmdDisasm;
Var
 SI: Integer;
 Off, VAddr, EndAddr: LongInt;
 InstrLen, K: Integer;
 Mnemonic, Operands, BytesTxt, Lbl: String;
Begin
 WriteLn;
 WriteLn(InFileName, ':     format ', FormatName);
 For SI := 1 To SectionCount Do Begin
  If Not Sections[SI].IsCode Then Continue;
  WriteLn;
  WriteLn('Disassembly of section ', Sections[SI].Name, ':');
  VAddr := Sections[SI].VAddr;
  EndAddr := VAddr + Sections[SI].Size;
  While VAddr < EndAddr Do Begin
   Off := Sections[SI].FileOff + (VAddr - Sections[SI].VAddr);
   Lbl := FindSymbolAt(VAddr);
   If Lbl <> '' Then Begin
    WriteLn;
    WriteLn(ToHexFixed(VAddr, 16), ' <', Lbl, '>:');
   End;
   InstrLen := DisasmOne(Off, VAddr, Mnemonic, Operands);
   BytesTxt := '';
   For K := 0 To InstrLen - 1 Do Begin
    If K > 0 Then BytesTxt := BytesTxt + ' ';
    BytesTxt := BytesTxt + HexByte(GetByte(Off + K));
   End;
   Write('  ', ToHexFixed(VAddr, 6), ':' + #9, PadRight(BytesTxt, 21), #9);
   If Operands <> '' Then WriteLn(PadRight(Mnemonic, 6), ' ', Operands)
   Else WriteLn(Mnemonic);
   VAddr := VAddr + InstrLen;
  End;
 End;
End;

{ @description: Implemente l option -S : signale clairement que le
    melange source/assembleur n est pas pris en charge (necessiterait
    de lire les informations de debogage DWARF ou CodeView/PDB), au
    lieu d afficher un faux resultat. }
Procedure CmdSourceMix;
Begin
 WriteLn;
 WriteLn('Option -S non supportee par cette implementation :');
 WriteLn('le melange source/assembleur necessite de lire les');
 WriteLn('informations de debogage (DWARF pour ELF, CodeView/PDB');
 WriteLn('pour PE), ce qui depasse la portee de cet outil.');
 WriteLn('Utilisez -d pour le desassemblage seul.');
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }

Procedure Help;
Begin
 WriteLn('OBJDUMP - Clone partiel de l''outil GNU objdump.');
 WriteLn('Syntaxe : OBJDUMP fichier [options]');
 WriteLn('  fichier  Fichier binaire a analyser (ELF ou PE/PE32)');
 WriteLn('  -d       Desassemble les sections de code');
 WriteLn('  -h       Affiche l''en-tete des sections');
 WriteLn('  -t       Affiche la table des symboles');
 WriteLn('  -S       Melange source/assembleur (non supporte)');
 WriteLn('  -?       Aide sur cette commande');
 WriteLn;
 WriteLn('Formats supportes : ELF32/ELF64 (Linux), PE32/PE32+ (Windows).');
 WriteLn('Desassemblage : jeu d''instructions x86 32 bits courant');
 WriteLn('(mov, push/pop, arithmetique, branchements, etc.) ; pas de');
 WriteLn('SSE/AVX ni de mode x86-64 (prefixes REX).');
End;

Var
 Arg: String;
 I: Integer;
Begin
 InFileName := '';
 OptHeaders := False;
 OptSymbols := False;
 OptDisasm  := False;
 OptSource  := False;

 If ParamCount < 1 Then Begin
  Help;
  Halt(1);
 End;

 For I := 1 To ParamCount Do Begin
  Arg := ParamStr(I);
  If (Arg = '-?') Or (UpStr(Arg) = '/?') Then Begin
   Help;
   Halt(0);
  End Else If Arg = '-d' Then OptDisasm := True
  Else If Arg = '-h' Then OptHeaders := True
  Else If Arg = '-t' Then OptSymbols := True
  Else If Arg = '-S' Then OptSource := True
  Else If StartsWithStr(Arg, '-') Then Begin
   WriteLn('Option inconnue : ', Arg);
   Halt(1);
  End Else
   InFileName := Arg;
 End;

 If InFileName = '' Then Begin
  WriteLn('Erreur : aucun fichier specifie.');
  Halt(1);
 End;
 If (Not OptDisasm) And (Not OptHeaders) And (Not OptSymbols) And
    (Not OptSource) Then OptDisasm := True; { comportement par defaut }

 LoadFile(InFileName);
 DetectFormat;
 If BinFormat = FMT_UNKNOWN Then Begin
  WriteLn('Erreur : format de fichier non reconnu (ni ELF, ni PE).');
  Halt(1);
 End;

 If (BinFormat = FMT_ELF32) Or (BinFormat = FMT_ELF64) Then ParseELF
 Else ParsePE;

 If OptHeaders Then CmdHeaders;
 If OptSymbols Then CmdSymbols;
 If OptSource Then CmdSourceMix;
 If OptDisasm Then CmdDisasm;
End.
