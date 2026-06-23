{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Clone partiel de l outil GNU "objdump", couvrant les
    formats binaires ELF32/ELF64 (Linux), PE32/PE32+ (Windows), EXE
    DOS reel (MZ) et ROM NES (iNES), avec desassemblage x86 32 bits,
    x86-64, 8086/80186 et 6502 pour les instructions courantes.

    Portee assumee (voir discussion avec l utilisateur) :
    - Formats : ELF et PE (32 et 64 bits), EXE DOS MZ, ROM NES, et
      binaire brut (avec -m/-b).
    - Desassemblage (-d) : jeu d instructions courant de chaque
      architecture (mov, push/pop, arithmetique, branchements, etc.),
      pas une couverture exhaustive (pas de SSE/AVX).
    - L option -S (melange source/assembleur) necessiterait de lire
      les informations de debogage (DWARF pour ELF, CodeView/PDB pour
      PE), hors de portee ici : elle affiche un message explicite
      plutot que de simuler un resultat.

    Architecture : le fichier est charge entierement en memoire (via
    GetMem), puis lu par decalage (Off) avec des fonctions GetByte/
    GetWord/GetDWord. Chaque format (ELF, PE, MZ, NES) remplit les
    memes tableaux Sections[]/Symbols[], consultes ensuite par les
    commandes -h/-t/-d, independamment du format d origine. De meme,
    chaque architecture (DisasmOne, Disasm64One, Disasm8086One,
    Disasm6502One) expose une fonction d appel uniforme, choisie par
    Arch (detectee automatiquement selon le format, ou forcee par -m).
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
 FMT_NES     = 5;        { ROM NES (entete iNES, code 6502)            }
 FMT_RAW     = 6;        { binaire brut sans entete (code force par -m)}
 FMT_MZ      = 7;        { EXE DOS reel (entete MZ, sans entete PE)    }
 FMT_MACHO32 = 8;        { Mach-O 32 bits (macOS), natif little-endian }
 FMT_MACHO64 = 9;        { Mach-O 64 bits (macOS), natif little-endian }

 { ----- Mach-O : valeurs magiques et types de commande utiles -----
   Les constantes dont le bit de poids fort est positionne doivent
   etre typees explicitement en LongInt (signe) : sinon FPC les
   considere hors de la plage d un LongInt et compare toujours a
   faux face a une valeur lue par GetDWord (qui renvoie elle aussi un
   LongInt signe, via Move sur les octets bruts). }
 MH_MAGIC      : LongInt = LongInt($FEEDFACE);
 MH_MAGIC_64   : LongInt = LongInt($FEEDFACF);
 MH_CIGAM      : LongInt = LongInt($CEFAEDFE); { boutisme inverse (PowerPC) }
 MH_CIGAM_64   : LongInt = LongInt($CFFAEDFE);
 FAT_MAGIC     : LongInt = LongInt($CAFEBABE);
 FAT_CIGAM     : LongInt = LongInt($BEBAFECA);
 LC_SEGMENT    = $00000001;
 LC_SYMTAB     = $00000002;
 LC_SEGMENT_64 = $00000019;
 LC_MAIN       : LongInt = LongInt($80000028);
 CPU_TYPE_X86    = $00000007;
 CPU_TYPE_X86_64 = $01000007;

 { ----- Architectures de desassemblage (option -m) ----- }
 ARCH_X86   = 0;         { x86 32 bits (defaut, voir DisasmOne)         }
 ARCH_6502  = 1;         { 6502/65C02 8 bits (voir Disasm6502One)      }
 ARCH_8086  = 2;         { 8086/80186 16 bits (voir Disasm8086One)     }
 ARCH_X64   = 3;         { x86-64 (prefixes REX, voir Disasm64One)     }
 ARCH_ARM32 = 4;         { ARM 32 bits classique (voir DisasmArm32One) }
 ARCH_THUMB = 5;         { Thumb/Thumb-2 16+32 bits (voir DisasmThumbOne) }
 ARCH_ARM64 = 6;         { AArch64 (voir DisasmArm64One)               }
 ARCH_Z80   = 7;         { Z80/8080 8 bits (voir DisasmZ80One)         }
 ARCH_6800  = 8;         { Motorola 6800 8 bits (voir Disasm6800One)   }

 { ----- Modes d adressage 6800 ----- }
 AM68_INH   = 0;         { inherent : aucun operande                   }
 AM68_IMM8  = 1;         { immediat 8 bits : #$nn                      }
 AM68_IMM16 = 2;         { immediat 16 bits : #$nnnn (LDX/LDS/CPX)     }
 AM68_DIR   = 3;         { direct (page zero) : $nn                    }
 AM68_EXT   = 4;         { etendu (absolu 16 bits) : $nnnn             }
 AM68_IDX   = 5;         { indexe : $nn,X                              }
 AM68_REL   = 6;         { relatif (branchements) : $nnnn (resolu)     }

 { ----- Types de machine ELF/PE utiles au choix automatique de Arch -----}
 EM_ARM       = 40;
 EM_AARCH64   = 183;
 PE_MACHINE_ARM   = $01C0;
 PE_MACHINE_ARMNT = $01C4;  { Thumb-2 (ARMv7 et plus, convention Windows) }
 PE_MACHINE_ARM64 = $AA64;
 CPU_TYPE_ARM     = $0000000C;
 CPU_TYPE_ARM64   : LongInt = LongInt($0100000C);

 { ----- Modes d adressage 6502 ----- }
 AM_NONE = 0;            { opcode illegal/non documente                 }
 AM_IMP  = 1;            { implicite : aucun operande                   }
 AM_ACC  = 2;            { accumulateur : "A"                           }
 AM_IMM  = 3;            { immediat : #$nn                              }
 AM_ZP   = 4;            { page zero : $nn                              }
 AM_ZPX  = 5;            { page zero,X : $nn,X                          }
 AM_ZPY  = 6;            { page zero,Y : $nn,Y                          }
 AM_ABS  = 7;            { absolu : $nnnn                                }
 AM_ABSX = 8;            { absolu,X : $nnnn,X                            }
 AM_ABSY = 9;            { absolu,Y : $nnnn,Y                            }
 AM_IND  = 10;           { indirect (JMP uniquement) : ($nnnn)          }
 AM_INDX = 11;           { indirect indexe par X : ($nn,X)              }
 AM_INDY = 12;           { indirect indexe par Y : ($nn),Y              }
 AM_REL  = 13;           { relatif (branchements) : $nnnn (resolu)      }

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
 Arch         : Integer;          { ARCH_xxx, selectionne par -m }
 ArchForced   : Boolean;          { vrai si -m a ete passe explicitement }
 BaseAddr     : LongInt;          { adresse de chargement pour un binaire brut (-b) }
 MachOBase    : LongInt;          { decalage de la tranche choisie dans un binaire universel (fat), 0 sinon }
 MachOCpuType : LongInt;          { cputype Mach-O, pour le choix automatique de Arch }
 ElfMachine   : LongInt;          { e_machine ELF, pour le choix automatique de Arch }
 PEMachine    : LongInt;          { Machine du IMAGE_FILE_HEADER PE, idem }
 Mnem6502     : Array[0..255] Of String[4];
 Mode6502     : Array[0..255] Of Byte;
 Mnem6800     : Array[0..255] Of String[4];
 Mode6800     : Array[0..255] Of Byte;

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

{ @description: Lit un mot de 16 bits non signe en BIG-endian a la
    position Off (convention Motorola, utilisee par le 6800 pour ses
    valeurs immediates/etendues 16 bits, a l inverse du little-endian
    x86 lu par GetWord).
  @param Off Decalage (0-based) dans le fichier
  @return Valeur 16 bits lue, interpretation gros-boutiste }
Function GetWordBE(Off: LongInt): Word;
Begin
 GetWordBE := (GetByte(Off) Shl 8) Or GetByte(Off + 1);
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

{ @description: Lit un mot de 32 bits en BIG-endian a la position Off
    (l en-tete "fat" d un binaire universel Mach-O est toujours stocke
    en gros-boutiste, independamment de l architecture cible, pour
    rester identifiable sans ambiguite).
  @param Off Decalage (0-based) dans le fichier
  @return Valeur 32 bits lue, interpretation gros-boutiste }
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
 FileMode := 0; { ouverture en lecture seule : accepte aussi les
                   fichiers proteges en ecriture (ROM, dumps, ...) }
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
 Magic, NArch, I, ArchOff, ArchCpu: LongInt;
 ChosenOff: LongInt;
 Found: Boolean;
Begin
 BinFormat := FMT_UNKNOWN;
 MachOBase := 0;
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
  { "MZ" sans en-tete PE valide a e_lfanew : EXE DOS reel (16 bits) }
  BinFormat := FMT_MZ;
  Exit;
 End;
 If (GetByte(0) = Ord('N')) And (GetByte(1) = Ord('E')) And
    (GetByte(2) = Ord('S')) And (GetByte(3) = $1A) Then Begin
  BinFormat := FMT_NES;
  Exit;
 End;
 Magic := GetDWord(0);
 If Magic = MH_MAGIC_64 Then Begin
  BinFormat := FMT_MACHO64;
  Exit;
 End;
 If Magic = MH_MAGIC Then Begin
  BinFormat := FMT_MACHO32;
  Exit;
 End;
 If (Magic = MH_CIGAM) Or (Magic = MH_CIGAM_64) Then Begin
  WriteLn('Erreur : Mach-O gros-boutiste (PowerPC) non supporte.');
  Halt(1);
 End;
 If GetDWordBE(0) = FAT_MAGIC Then Begin
  { Binaire universel : choisir de preference la tranche x86-64, sinon
    x86 32 bits, sinon la premiere tranche du fichier. L en-tete fat
    et les entrees fat_arch sont toujours en gros-boutiste. }
  NArch := GetDWordBE(4);
  ChosenOff := -1;
  Found := False;
  For I := 0 To NArch - 1 Do Begin
   ArchOff := 8 + I * 20;
   ArchCpu := GetDWordBE(ArchOff);
   If ArchCpu = CPU_TYPE_X86_64 Then Begin
    { Meilleur choix possible : on arrete la recherche immediatement. }
    ChosenOff := GetDWordBE(ArchOff + 8);
    Found := True;
    Break;
   End;
   If (ArchCpu = CPU_TYPE_X86) And (Not Found) Then Begin
    ChosenOff := GetDWordBE(ArchOff + 8);
    Found := True; { x86 trouve ; on continue, un x86-64 ferait mieux }
   End;
   If ChosenOff < 0 Then
    ChosenOff := GetDWordBE(ArchOff + 8); { repli : 1ere tranche vue }
  End;
  If ChosenOff < 0 Then Exit; { fat_header sans tranche exploitable }
  MachOBase := ChosenOff;
  Magic := GetDWord(MachOBase);
  If Magic = MH_MAGIC_64 Then BinFormat := FMT_MACHO64
  Else If Magic = MH_MAGIC Then BinFormat := FMT_MACHO32;
  Exit;
 End Else If GetDWordBE(0) = FAT_CIGAM Then Begin
  WriteLn('Erreur : binaire universel gros-boutiste non supporte.');
  Halt(1);
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
 ElfMachine := GetWord(18); { e_machine, meme decalage en 32 et 64 bits }
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
 PEMachine := GetWord(PEOff + 4);
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
  ANALYSE D UNE ROM NES (entete iNES) ET D UN BINAIRE BRUT 6502
  ============================================================ }

{ @description: Remplit Sections[] a partir d une ROM NES (entete
    iNES de 16 octets). La banque PRG-ROM est mappee a $8000, soit
    directement (32 Ko, mapping lineaire courant) soit reproduite en
    miroir sur $8000-$FFFF (16 Ko, mapping le plus repandu des
    cartouches simples type NROM). Le CHR-ROM (graphismes, pas du
    code 6502) n est pas mappe pour le desassemblage. }
Procedure ParseNES;
Var
 PrgBanks: Integer;
 PrgSize: LongInt;
Begin
 PrgBanks := GetByte(4);
 PrgSize := LongInt(PrgBanks) * 16384;
 SectionCount := 0;
 If PrgSize > 0 Then Begin
  SectionCount := 1;
  Sections[1].Name    := '.prg';
  Sections[1].FileOff := 16; { fin de l entete iNES }
  Sections[1].IsCode  := True;
  If PrgSize >= 32768 Then Begin
   Sections[1].VAddr := $8000;
   Sections[1].Size  := 32768;
  End Else Begin
   { Banque unique de 16 Ko, miroir habituel sur toute la fenetre
     $8000-$FFFF des cartouches NROM ; on ne desassemble que
     l exemplaire reel, present une seule fois dans le fichier. }
   Sections[1].VAddr := $C000;
   Sections[1].Size  := PrgSize;
  End;
 End;
 SymbolCount := 0;
 EntryPoint := 0;
 ImageBase := 0;
End;

{ @description: Cree une unique section couvrant tout le fichier,
    pour un binaire brut sans entete reconnu (option -m force,
    chargee a l adresse BaseAddr fixee par -b, $0000 par defaut). }
Procedure ParseRaw;
Begin
 SectionCount := 1;
 Sections[1].Name    := '.rom';
 Sections[1].VAddr   := BaseAddr;
 Sections[1].FileOff := 0;
 Sections[1].Size    := BufSize;
 Sections[1].IsCode  := True;
 SymbolCount := 0;
 EntryPoint := BaseAddr;
 ImageBase := 0;
End;

{ @description: Remplit Sections[] a partir d un EXE DOS reel (entete
    MZ, 16 bits). Comme les segments d un EXE MZ sont tous relatifs au
    debut du module charge (le loader DOS ajoute le segment reel
    d execution a chaque reference), tout le module post-entete est
    traite comme une seule section ".text" partant de l adresse
    relative 0000 ; le point d entree affiche est CS*16+IP, relatif a
    ce meme debut de module. Cette approximation ignore les segments
    multiples eventuels (donnees apres code, overlays, ...) : tout le
    corps du fichier est presente comme du code desassemblable. }
Procedure ParseMZ;
Var
 CblpVal, CpVal, CparHdrVal: Word;
 IpVal, CsVal: Word;
 PageBytes: LongInt;
 ImgSize, HdrSize: LongInt;
Begin
 CblpVal    := GetWord(2);
 CpVal      := GetWord(4);
 CparHdrVal := GetWord(8);
 IpVal      := GetWord(14);
 CsVal      := GetWord(16);
 If CblpVal = 0 Then PageBytes := 512 Else PageBytes := CblpVal;
 ImgSize := LongInt(CpVal - 1) * 512 + PageBytes;
 HdrSize := LongInt(CparHdrVal) * 16;
 If (ImgSize <= 0) Or (ImgSize > BufSize) Then ImgSize := BufSize;
 If HdrSize >= ImgSize Then HdrSize := 0; { entete incoherente : repli }
 SectionCount := 1;
 Sections[1].Name    := '.text';
 Sections[1].VAddr   := 0;
 Sections[1].FileOff := HdrSize;
 Sections[1].Size    := ImgSize - HdrSize;
 Sections[1].IsCode  := True;
 SymbolCount := 0;
 ImageBase := 0;
 EntryPoint := (LongInt(CsVal) * 16) + IpVal;
End;

{ ============================================================
  ANALYSE DU FORMAT MACH-O (32 et 64 bits, macOS)
  ============================================================ }

{ @description: Remplit Sections[]/Symbols[] a partir d un fichier
    Mach-O deja charge (32 ou 64 bits, natif little-endian), eventu-
    ellement une tranche extraite d un binaire universel "fat" via
    MachOBase (0 pour un Mach-O simple). Parcourt les commandes de
    chargement (load commands) a la recherche des segments
    (LC_SEGMENT/LC_SEGMENT_64, pour remplir Sections[]), de la table
    des symboles (LC_SYMTAB), et du point d entree (LC_MAIN). Comme
    pour ELF64/PE64, les champs 64 bits ne sont conserves que sur 32
    bits pour l affichage.

    Avertissement : implementation ecrite directement a partir des
    structures documentees du format Mach-O (mach_header, segment_
    command, section, nlist), sans pouvoir la verifier contre un
    binaire macOS reel (aucun disponible dans cet environnement
    Windows/Linux/DOS) ; verifiee uniquement par un fichier Mach-O
    synthetique minimal construit a la main pour ce test. }
Procedure ParseMachO;
Var
 Is64: Boolean;
 HdrSize: LongInt;
 NCmds: LongInt;
 CmdOff, Cmd, CmdSize: LongInt;
 I, J: Integer;
 NSects, SectOff, SegHdrSize, SectEntrySize: LongInt;
 SegVAddr: LongInt;
 SName, SSegName: String;
 SAddr, SSize, SFileOff: LongInt;
 SymOff, NSyms, StrOff: LongInt;
 SymEntrySize: LongInt;
 SBase: LongInt;
 NStrx, NValue: LongInt;
 NType, NSect: Byte;
 EntryOff: LongInt;
 FoundMain: Boolean;
 TextVAddr: LongInt;
Begin
 Is64 := (BinFormat = FMT_MACHO64);
 MachOCpuType := GetDWord(MachOBase + 4);
 If Is64 Then HdrSize := 32 Else HdrSize := 28;
 NCmds := GetDWord(MachOBase + 16);
 SectionCount := 0;
 SymbolCount := 0;
 TextVAddr := 0;
 FoundMain := False;
 EntryOff := 0;
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
    SegVAddr := GetDWord(CmdOff + 24);    { partie basse de vmaddr (8 octets) }
    NSects   := GetDWord(CmdOff + 64);
    SegHdrSize := 72; SectEntrySize := 80;
   End Else Begin
    SegVAddr := GetDWord(CmdOff + 24);
    NSects   := GetDWord(CmdOff + 48);
    SegHdrSize := 56; SectEntrySize := 68;
   End;
   If (TextVAddr = 0) And (SSegName = '__TEXT') Then TextVAddr := SegVAddr;
   SectOff := CmdOff + SegHdrSize;
   For J := 0 To NSects - 1 Do Begin
    If SectionCount >= MaxSections Then Break;
    SName    := GetCStr(SectOff, 16);
    SSegName := GetCStr(SectOff + 16, 16);
    If Cmd = LC_SEGMENT_64 Then Begin
     SAddr    := GetDWord(SectOff + 32); { partie basse de addr (8 octets) }
     SSize    := GetDWord(SectOff + 40); { partie basse de size (8 octets) }
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
    Sections[SectionCount].IsCode  :=
     (SSegName = '__TEXT') And (SName = '__text');
    SectOff := SectOff + SectEntrySize;
   End;
  End Else If Cmd = LC_SYMTAB Then Begin
   SymOff := MachOBase + GetDWord(CmdOff + 8);
   NSyms  := GetDWord(CmdOff + 12);
   StrOff := MachOBase + GetDWord(CmdOff + 16);
  End Else If Cmd = LC_MAIN Then Begin
   EntryOff := GetDWord(CmdOff + 8); { partie basse de entryoff (8 octets) }
   FoundMain := True;
  End;
  CmdOff := CmdOff + CmdSize;
 End;
 ImageBase := 0;
 If FoundMain Then EntryPoint := TextVAddr + EntryOff
 Else EntryPoint := TextVAddr;
 { Table des symboles (nlist / nlist_64) }
 If Is64 Then SymEntrySize := 16 Else SymEntrySize := 12;
 If (NSyms > 0) And (SymOff > 0) Then
  For I := 0 To NSyms - 1 Do Begin
   If SymbolCount >= MaxSymbols Then Break;
   SBase := SymOff + I * SymEntrySize;
   NStrx := GetDWord(SBase);
   NType := GetByte(SBase + 4);
   NSect := GetByte(SBase + 5);
   NValue := GetDWord(SBase + 8); { partie basse de n_value si 64 bits }
   If (NType And $E0) <> 0 Then Continue; { entree de debogage (stab) }
   SName := GetCStr(StrOff + NStrx, 63);
   If SName <> '' Then Begin
    Inc(SymbolCount);
    Symbols[SymbolCount].Name   := SName;
    Symbols[SymbolCount].Value  := NValue;
    Symbols[SymbolCount].SecIdx := NSect;
    Symbols[SymbolCount].IsFunc := (NType And $0E) = $0E; { N_SECT }
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
  DESASSEMBLEUR X86-64 (prefixes REX, registres etendus, RIP-relatif)
  ============================================================ }

{ @description: Nom (prefixe %) du registre 64 bits numero R (0..15,
    les valeurs 8..15 designant R8..R15, accessibles uniquement via
    l extension REX du champ correspondant du ModRM/SIB).
  @param R Numero de registre etendu (0..15)
  @return Nom du registre 64 bits }
Function Reg64(R: Byte): String;
Const
 Names: Array[0..15] Of String[4] = (
  'rax', 'rcx', 'rdx', 'rbx', 'rsp', 'rbp', 'rsi', 'rdi',
  'r8', 'r9', 'r10', 'r11', 'r12', 'r13', 'r14', 'r15');
Begin
 Reg64 := '%' + Names[R And 15];
End;

{ @description: Nom (prefixe %) du registre 32 bits numero R (0..15),
    forme par defaut en mode 64 bits (operandes 32 bits implicites
    sauf REX.W). R8..R15 sont notes r8d..r15d.
  @param R Numero de registre etendu (0..15)
  @return Nom du registre 32 bits }
Function Reg32X(R: Byte): String;
Const
 Names: Array[0..15] Of String[5] = (
  'eax', 'ecx', 'edx', 'ebx', 'esp', 'ebp', 'esi', 'edi',
  'r8d', 'r9d', 'r10d', 'r11d', 'r12d', 'r13d', 'r14d', 'r15d');
Begin
 Reg32X := '%' + Names[R And 15];
End;

{ @description: Nom (prefixe %) du registre 8 bits numero R (0..15).
    En presence d un prefixe REX (RexPresent vrai), les numeros 4..7
    designent spl/bpl/sil/dil (et non plus ah/ch/dh/bh, qui deviennent
    inaccessibles dans une instruction prefixee REX) ; sans REX, la
    convention historique ah/ch/dh/bh s applique.
  @param R Numero de registre etendu (0..15)
  @param RexPresent Vrai si l instruction courante porte un prefixe REX
  @return Nom du registre 8 bits }
Function Reg8X(R: Byte; RexPresent: Boolean): String;
Const
 NamesNoRex: Array[0..7] Of String[3] = (
  'al', 'cl', 'dl', 'bl', 'ah', 'ch', 'dh', 'bh');
 NamesRex: Array[0..15] Of String[4] = (
  'al', 'cl', 'dl', 'bl', 'spl', 'bpl', 'sil', 'dil',
  'r8b', 'r9b', 'r10b', 'r11b', 'r12b', 'r13b', 'r14b', 'r15b');
Begin
 If RexPresent Then Reg8X := '%' + NamesRex[R And 15]
 Else Reg8X := '%' + NamesNoRex[R And 7];
End;

{ @description: Decode l octet ModRM (et l eventuel octet SIB et
    deplacement) en mode 64 bits : structurellement identique a
    DecodeModRM (meme codage SIB, mêmes cas particuliers Mod=00/RM=101
    et SIB.base=101), mais (a) les champs Reg/RM/Index/Base sont
    etendus a 4 bits par les bits REX.R/REX.X/REX.B, et (b) le cas
    Mod=00,RM=101 (sans SIB), qui designait une adresse absolue
    disp32 en 32 bits, designe desormais une adresse RIP-relative
    ([RIP+disp32]) : le deplacement brut est affiche suivi de
    "(%rip)", sans resoudre l adresse absolue (la longueur totale de
    l instruction, necessaire pour ce calcul, n est pas encore connue
    a cet instant si un immediat suit).
  @param Off Decalage du premier octet (le ModRM lui-meme)
  @param Consumed Nombre d octets consommes (sortie)
  @param RegField Champ Reg (4 bits, etendu par REX.R) du ModRM (sortie)
  @param Width Taille du registre pour le mode Mod=11 (8, 32 ou 64)
  @param RexR Bit REX.R (etend le champ Reg)
  @param RexX Bit REX.X (etend le champ Index du SIB)
  @param RexB Bit REX.B (etend le champ RM/Base)
  @param RexPresent Vrai si l instruction porte un prefixe REX (pour
    le choix de la convention des registres 8 bits)
  @return Texte de l operande (registre ou adresse memoire) }
Function DecodeModRM64(Off: LongInt; Var Consumed: Integer;
 Var RegField: Byte; Width: Integer;
 RexR, RexX, RexB, RexPresent: Boolean): String;
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
 If RexR Then RegField := RegField Or 8;
 RM := GetByte(P) And 7;
 If RexB Then RM := RM Or 8;
 Inc(P);
 Consumed := 1;
 If ModB = 3 Then Begin
  Case Width Of
   64: DecodeModRM64 := Reg64(RM);
   8:  DecodeModRM64 := Reg8X(RM, RexPresent);
  Else
   DecodeModRM64 := Reg32X(RM);
  End;
  Exit;
 End;
 HasSIB := ((RM And 7) = 4);
 Scale := 0; Idx := 0; BaseR := 0; NoBase := False;
 If HasSIB Then Begin
  Scale := (GetByte(P) Shr 6) And 3;
  Idx   := (GetByte(P) Shr 3) And 7;
  If RexX Then Idx := Idx Or 8;
  BaseR := GetByte(P) And 7;
  If RexB Then BaseR := BaseR Or 8;
  Inc(P); Inc(Consumed);
  NoBase := (BaseR = 5) And (ModB = 0);
 End;
 Disp := 0;
 If (ModB = 0) And ((RM And 7) = 5) And (Not HasSIB) Then Begin
  Disp := GetDWord(P); P := P + 4; Consumed := Consumed + 4;
  DecodeModRM64 := ToHexSignedDisp(Disp) + '(%rip)';
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
  If Not NoBase Then Inner := Reg64(BaseR);
  If Idx <> 4 Then Begin { Idx=4 (rsp, sans extension REX.X) signifie
    "pas d index" ; avec REX.X, ce meme champ designe r12, un index
    valide, donc le test porte sur la valeur ETENDUE. }
   If Inner <> '' Then Inner := Inner + ',';
   Inner := Inner + Reg64(Idx) + ',' + Chr(Ord('0') + (1 Shl Scale));
  End;
 End Else
  Inner := Reg64(RM);
 DispTxt := ToHexSignedDisp(Disp);
 DecodeModRM64 := DispTxt + '(' + Inner + ')';
End;

{ @description: Desassemble une seule instruction x86-64 a partir du
    decalage Off, en syntaxe AT&T (comme DisasmOne). Consomme d abord
    un eventuel prefixe REX (0x40-0x4F, qui en mode 64 bits ne signifie
    plus jamais inc/dec comme en 32 bits) pour determiner la taille
    par defaut des operandes "larges" (32 bits sans REX.W, 64 bits
    avec) et les bits d extension de registre R/X/B. Reutilise pour
    le reste la meme structure d opcodes que DisasmOne (les
    significations de base sont identiques), avec les differences
    propres au mode 64 bits : adressage RIP-relatif, MOVSXD (0x63),
    MOVABS (B8-BF avec REX.W, immediat 64 bits), absence des formes
    inc/dec a un octet (0x40-0x4F, reservees aux prefixes REX).
  @param Off Decalage de l instruction dans le fichier
  @param VAddrBase Adresse virtuelle correspondant a Off
  @param Mnemonic Mnemonique de l instruction (sortie)
  @param Operands Operandes formates, syntaxe AT&T (sortie)
  @return Nombre d octets occupes par l instruction }
Function Disasm64One(Off, VAddrBase: LongInt;
 Var Mnemonic, Operands: String): Integer;
Var
 Op, Op2, RexByte: Byte;
 RexW, RexR, RexX, RexB, RexPresent: Boolean;
 P: LongInt;
 Len, WideSz: Integer;
 RM: String;
 RegF: Byte;
 Imm: LongInt;
 ImmHi: LongInt;
 Rel: LongInt;
Begin
 P := Off;
 RexByte := GetByte(P);
 RexPresent := (RexByte And $F0) = $40;
 If RexPresent Then Begin
  RexW := (RexByte And 8) <> 0;
  RexR := (RexByte And 4) <> 0;
  RexX := (RexByte And 2) <> 0;
  RexB := (RexByte And 1) <> 0;
  Inc(P);
 End Else Begin
  RexW := False; RexR := False; RexX := False; RexB := False;
 End;
 If RexW Then WideSz := 64 Else WideSz := 32;
 Op := GetByte(P);
 Inc(P);
 Mnemonic := '(bad)';
 Operands := '';

 { ----- push/pop registre (toujours 64 bits par defaut, meme sans
   REX.W : REX.B etend seulement le numero de registre) ----- }
 If (Op >= $50) And (Op <= $57) Then Begin
  RegF := Op - $50; If RexB Then RegF := RegF Or 8;
  Mnemonic := 'push'; Operands := Reg64(RegF);
 End Else If (Op >= $58) And (Op <= $5F) Then Begin
  RegF := Op - $58; If RexB Then RegF := RegF Or 8;
  Mnemonic := 'pop'; Operands := Reg64(RegF);
 End

 { ----- push immediat ----- }
 Else If Op = $68 Then Begin
  Imm := GetDWord(P); P := P + 4;
  Mnemonic := 'push'; Operands := '$0x' + ToHexU(Imm);
 End Else If Op = $6A Then Begin
  Imm := ShortInt(GetByte(P)); Inc(P);
  Mnemonic := 'push'; Operands := '$0x' + ToHexU(Imm);
 End

 { ----- mov reg,imm : MOVABS reg64,imm64 avec REX.W (immediat 8
   octets), sinon mov reg32,imm32 comme en 32 bits ----- }
 Else If (Op >= $B8) And (Op <= $BF) Then Begin
  RegF := Op - $B8; If RexB Then RegF := RegF Or 8;
  If RexW Then Begin
   Imm := GetDWord(P); ImmHi := GetDWord(P + 4); P := P + 8;
   Mnemonic := 'movabs';
   If ImmHi = 0 Then
    Operands := '$0x' + ToHexU(Imm) + ',' + Reg64(RegF)
   Else
    Operands := '$0x' + ToHexU(ImmHi) + ToHexFixed(Imm, 8) + ',' +
     Reg64(RegF);
  End Else Begin
   Imm := GetDWord(P); P := P + 4;
   Mnemonic := 'mov'; Operands := '$0x' + ToHexU(Imm) + ',' + Reg32X(RegF);
  End;
 End

 { ----- mov r/m,r (89) / mov r,r/m (8B), largeur selon REX.W ----- }
 Else If Op = $89 Then Begin
  RM := DecodeModRM64(P, Len, RegF, WideSz, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Mnemonic := 'mov';
  If RexW Then Operands := Reg64(RegF) + ',' + RM
  Else Operands := Reg32X(RegF) + ',' + RM;
 End Else If Op = $8B Then Begin
  RM := DecodeModRM64(P, Len, RegF, WideSz, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Mnemonic := 'mov';
  If RexW Then Operands := RM + ',' + Reg64(RegF)
  Else Operands := RM + ',' + Reg32X(RegF);
 End

 { ----- mov r/m8,r8 (88) / mov r8,r/m8 (8A) ----- }
 Else If Op = $88 Then Begin
  RM := DecodeModRM64(P, Len, RegF, 8, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Mnemonic := 'mov'; Operands := Reg8X(RegF, RexPresent) + ',' + RM;
 End Else If Op = $8A Then Begin
  RM := DecodeModRM64(P, Len, RegF, 8, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Mnemonic := 'mov'; Operands := RM + ',' + Reg8X(RegF, RexPresent);
 End

 { ----- mov r/m, imm32 (C7, signe-etendu en 64 bits si REX.W) ----- }
 Else If Op = $C7 Then Begin
  RM := DecodeModRM64(P, Len, RegF, WideSz, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Imm := GetDWord(P); P := P + 4;
  Mnemonic := 'mov'; Operands := '$0x' + ToHexU(Imm) + ',' + RM;
 End Else If Op = $C6 Then Begin
  RM := DecodeModRM64(P, Len, RegF, 8, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Imm := GetByte(P); Inc(P);
  Mnemonic := 'mov'; Operands := '$0x' + ToHexU(Imm) + ',' + RM;
 End

 { ----- lea reg, m ----- }
 Else If Op = $8D Then Begin
  RM := DecodeModRM64(P, Len, RegF, WideSz, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Mnemonic := 'lea';
  If RexW Then Operands := RM + ',' + Reg64(RegF)
  Else Operands := RM + ',' + Reg32X(RegF);
 End

 { ----- movsxd reg64, r/m32 (0x63 : signification propre au mode 64
   bits, remplace l ancien ARPL 16 bits) ----- }
 Else If Op = $63 Then Begin
  RM := DecodeModRM64(P, Len, RegF, 32, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Mnemonic := 'movslq'; Operands := RM + ',' + Reg64(RegF);
 End

 { ----- groupe arithmetique 00-3F (add/or/adc/sbb/and/sub/xor/cmp) ----- }
 Else If Op < $40 Then Begin
  Case Op And 7 Of
   0: Begin
       RM := DecodeModRM64(P, Len, RegF, 8, RexR, RexX, RexB, RexPresent);
       P := P + Len;
       Mnemonic := Grp1Names[(Op Shr 3) And 7];
       Operands := Reg8X(RegF, RexPresent) + ',' + RM;
      End;
   1: Begin
       RM := DecodeModRM64(P, Len, RegF, WideSz, RexR, RexX, RexB, RexPresent);
       P := P + Len;
       Mnemonic := Grp1Names[(Op Shr 3) And 7];
       If RexW Then Operands := Reg64(RegF) + ',' + RM
       Else Operands := Reg32X(RegF) + ',' + RM;
      End;
   2: Begin
       RM := DecodeModRM64(P, Len, RegF, 8, RexR, RexX, RexB, RexPresent);
       P := P + Len;
       Mnemonic := Grp1Names[(Op Shr 3) And 7];
       Operands := RM + ',' + Reg8X(RegF, RexPresent);
      End;
   3: Begin
       RM := DecodeModRM64(P, Len, RegF, WideSz, RexR, RexX, RexB, RexPresent);
       P := P + Len;
       Mnemonic := Grp1Names[(Op Shr 3) And 7];
       If RexW Then Operands := RM + ',' + Reg64(RegF)
       Else Operands := RM + ',' + Reg32X(RegF);
      End;
   4: Begin
       Imm := GetByte(P); Inc(P);
       Mnemonic := Grp1Names[(Op Shr 3) And 7];
       Operands := '$0x' + ToHexU(Imm) + ',' + Reg8X(0, RexPresent);
      End;
   5: Begin
       Imm := GetDWord(P); P := P + 4;
       Mnemonic := Grp1Names[(Op Shr 3) And 7];
       If RexW Then Operands := '$0x' + ToHexU(Imm) + ',' + Reg64(0)
       Else Operands := '$0x' + ToHexU(Imm) + ',' + Reg32X(0);
      End;
  Else
   Mnemonic := '(bad)';
  End;
 End

 { ----- groupe 1 avec immediat : 80/81/83 ----- }
 Else If Op = $80 Then Begin
  RM := DecodeModRM64(P, Len, RegF, 8, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Imm := GetByte(P); Inc(P);
  Mnemonic := Grp1Names[RegF And 7];
  Operands := '$0x' + ToHexU(Imm) + ',' + RM;
 End Else If Op = $81 Then Begin
  RM := DecodeModRM64(P, Len, RegF, WideSz, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Imm := GetDWord(P); P := P + 4;
  Mnemonic := Grp1Names[RegF And 7];
  Operands := '$0x' + ToHexU(Imm) + ',' + RM;
 End Else If Op = $83 Then Begin
  RM := DecodeModRM64(P, Len, RegF, WideSz, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Imm := ShortInt(GetByte(P)); Inc(P);
  Mnemonic := Grp1Names[RegF And 7];
  Operands := '$0x' + ToHexU(Imm) + ',' + RM;
 End

 { ----- test r/m,r ; test AL/eAX,imm ----- }
 Else If Op = $84 Then Begin
  RM := DecodeModRM64(P, Len, RegF, 8, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Mnemonic := 'test'; Operands := Reg8X(RegF, RexPresent) + ',' + RM;
 End Else If Op = $85 Then Begin
  RM := DecodeModRM64(P, Len, RegF, WideSz, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Mnemonic := 'test';
  If RexW Then Operands := Reg64(RegF) + ',' + RM
  Else Operands := Reg32X(RegF) + ',' + RM;
 End Else If Op = $A8 Then Begin
  Imm := GetByte(P); Inc(P);
  Mnemonic := 'test'; Operands := '$0x' + ToHexU(Imm) + ',' + Reg8X(0, RexPresent);
 End Else If Op = $A9 Then Begin
  Imm := GetDWord(P); P := P + 4;
  Mnemonic := 'test';
  If RexW Then Operands := '$0x' + ToHexU(Imm) + ',' + Reg64(0)
  Else Operands := '$0x' + ToHexU(Imm) + ',' + Reg32X(0);
 End

 { ----- call/jmp relatifs (toujours rel32, meme en 64 bits) ----- }
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
  If RexW Then Mnemonic := 'cdqe' Else Mnemonic := 'cwde';
 End Else If Op = $99 Then Begin
  If RexW Then Mnemonic := 'cqto' Else Mnemonic := 'cdq';
 End

 { ----- groupe decalages : C0/C1 (imm8), D0-D3 (1 ou CL) ----- }
 Else If Op = $C0 Then Begin
  RM := DecodeModRM64(P, Len, RegF, 8, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Imm := GetByte(P); Inc(P);
  Mnemonic := ShiftNames[RegF And 7];
  Operands := '$0x' + ToHexU(Imm) + ',' + RM;
 End Else If Op = $C1 Then Begin
  RM := DecodeModRM64(P, Len, RegF, WideSz, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Imm := GetByte(P); Inc(P);
  Mnemonic := ShiftNames[RegF And 7];
  Operands := '$0x' + ToHexU(Imm) + ',' + RM;
 End Else If Op = $D0 Then Begin
  RM := DecodeModRM64(P, Len, RegF, 8, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Mnemonic := ShiftNames[RegF And 7]; Operands := RM;
 End Else If Op = $D1 Then Begin
  RM := DecodeModRM64(P, Len, RegF, WideSz, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Mnemonic := ShiftNames[RegF And 7]; Operands := RM;
 End Else If Op = $D2 Then Begin
  RM := DecodeModRM64(P, Len, RegF, 8, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Mnemonic := ShiftNames[RegF And 7]; Operands := '%cl,' + RM;
 End Else If Op = $D3 Then Begin
  RM := DecodeModRM64(P, Len, RegF, WideSz, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Mnemonic := ShiftNames[RegF And 7]; Operands := '%cl,' + RM;
 End

 { ----- groupe FE/FF : inc/dec/call/jmp/push selon RegField ----- }
 Else If Op = $FE Then Begin
  RM := DecodeModRM64(P, Len, RegF, 8, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  If (RegF And 7) = 0 Then Mnemonic := 'inc' Else Mnemonic := 'dec';
  Operands := RM;
 End Else If Op = $FF Then Begin
  RM := DecodeModRM64(P, Len, RegF, WideSz, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Case RegF And 7 Of
   0: Mnemonic := 'inc';
   1: Mnemonic := 'dec';
   2: Mnemonic := 'call';
   4: Mnemonic := 'jmp';
   6: Begin
       { push : toujours 64 bits, le decodage ci-dessus en WideSz
         (32 par defaut) ne s applique qu au texte de l operande deja
         construit ; comme RM est deja forme, on l utilise tel quel. }
       Mnemonic := 'push';
      End;
  Else
   Mnemonic := '(bad)';
  End;
  If Mnemonic <> '(bad)' Then Operands := '*' + RM;
 End

 { ----- groupe F6/F7 : test/not/neg/mul/imul/div/idiv ----- }
 Else If Op = $F6 Then Begin
  RM := DecodeModRM64(P, Len, RegF, 8, RexR, RexX, RexB, RexPresent);
  P := P + Len;
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
  RM := DecodeModRM64(P, Len, RegF, WideSz, RexR, RexX, RexB, RexPresent);
  P := P + Len;
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

 { ----- imul reg, r/m, imm (69 = imm32, 6B = imm8) ----- }
 Else If Op = $69 Then Begin
  RM := DecodeModRM64(P, Len, RegF, WideSz, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Imm := GetDWord(P); P := P + 4;
  Mnemonic := 'imul';
  If RexW Then Operands := '$0x' + ToHexU(Imm) + ',' + RM + ',' + Reg64(RegF)
  Else Operands := '$0x' + ToHexU(Imm) + ',' + RM + ',' + Reg32X(RegF);
 End Else If Op = $6B Then Begin
  RM := DecodeModRM64(P, Len, RegF, WideSz, RexR, RexX, RexB, RexPresent);
  P := P + Len;
  Imm := ShortInt(GetByte(P)); Inc(P);
  Mnemonic := 'imul';
  If RexW Then Operands := '$0x' + ToHexU(Imm) + ',' + RM + ',' + Reg64(RegF)
  Else Operands := '$0x' + ToHexU(Imm) + ',' + RM + ',' + Reg32X(RegF);
 End

 { ----- opcodes etendus 0F xx (Jcc rel32, movzx, movsx) ----- }
 Else If Op = $0F Then Begin
  Op2 := GetByte(P); Inc(P);
  If (Op2 >= $80) And (Op2 <= $8F) Then Begin
   Rel := GetDWord(P); P := P + 4;
   Mnemonic := 'j' + Cc16Names[Op2 - $80];
   Operands := '0x' + ToHexU(VAddrBase + (P - Off) + Rel);
  End Else If Op2 = $B6 Then Begin
   RM := DecodeModRM64(P, Len, RegF, 8, RexR, RexX, RexB, RexPresent);
   P := P + Len;
   Mnemonic := 'movzbl';
   If RexW Then Operands := RM + ',' + Reg64(RegF)
   Else Operands := RM + ',' + Reg32X(RegF);
  End Else If Op2 = $B7 Then Begin
   RM := DecodeModRM64(P, Len, RegF, 16, RexR, RexX, RexB, RexPresent);
   P := P + Len;
   Mnemonic := 'movzwl';
   If RexW Then Operands := RM + ',' + Reg64(RegF)
   Else Operands := RM + ',' + Reg32X(RegF);
  End Else If Op2 = $BE Then Begin
   RM := DecodeModRM64(P, Len, RegF, 8, RexR, RexX, RexB, RexPresent);
   P := P + Len;
   Mnemonic := 'movsbl';
   If RexW Then Operands := RM + ',' + Reg64(RegF)
   Else Operands := RM + ',' + Reg32X(RegF);
  End Else If Op2 = $BF Then Begin
   RM := DecodeModRM64(P, Len, RegF, 16, RexR, RexX, RexB, RexPresent);
   P := P + Len;
   Mnemonic := 'movswl';
   If RexW Then Operands := RM + ',' + Reg64(RegF)
   Else Operands := RM + ',' + Reg32X(RegF);
  End Else
   Mnemonic := '(bad)';
 End;

 If P <= Off Then P := Off + 1; { securite anti-boucle infinie }
 Disasm64One := P - Off;
End;

{ ============================================================
  DESASSEMBLEUR AARCH64 (ARM 64 bits, instructions courantes)
  ============================================================ }

{ @description: Nom (prefixe %) du registre 64 bits numero R, dans un
    contexte d ADRESSE/BASE (registre 31 affiche "sp").
  @param R Numero de registre (0..31)
  @return Nom du registre 64 bits }
Function RegX(R: Byte): String;
Begin
 If (R And 31) = 31 Then RegX := '%sp' Else RegX := '%x' + IntToStr(R And 31);
End;

{ @description: Nom (prefixe %) du registre 64 bits numero R, dans un
    contexte de VALEUR (registre 31 affiche le registre zero "xzr").
  @param R Numero de registre (0..31)
  @return Nom du registre 64 bits ou "xzr" }
Function RegXZ(R: Byte): String;
Begin
 If (R And 31) = 31 Then RegXZ := '%xzr' Else RegXZ := '%x' + IntToStr(R And 31);
End;

{ @description: Nom (prefixe %) du registre 32 bits (vue basse d un
    registre 64 bits) numero R, contexte VALEUR (registre 31 = "wzr").
  @param R Numero de registre (0..31)
  @return Nom du registre 32 bits ou "wzr" }
Function RegWZ(R: Byte): String;
Begin
 If (R And 31) = 31 Then RegWZ := '%wzr' Else RegWZ := '%w' + IntToStr(R And 31);
End;

{ @description: Desassemble une seule instruction AArch64 (largeur
    fixe 4 octets) a partir du decalage Off, en syntaxe AT&T simplifiee
    (registres prefixes %, comme pour DisasmOne/Disasm64One). Couvre
    un sous-ensemble pratique : branchements (B/BL/B.cond/CBZ/CBNZ/
    BR/BLR/RET), deplacement de constantes (MOVZ/MOVN/MOVK), arithmetique
    et logique de base (ADD/SUB/AND/ORR/EOR, formes immediat et
    registre, avec les alias CMP/CMN/MOV), chargement/rangement simple
    et par paire (LDR/STR/STP/LDP, decalage non signe ou signe), NOP,
    SVC. Pas de SIMD/FP, pas de logique a immediat (masque de bits),
    pas d adressage indexe par registre.

    Avertissement de confiance : l encodage exact des instructions
    LDR/STR/STP/LDP (notamment le sous-champ "mode" de STP/LDP qui
    distingue decalage signe / pre-index / post-index) est implemente
    a partir du souvenir des tables de l ARM ARM (Architecture
    Reference Manual), sans reference disponible pour le verifier
    dans cet environnement ; les branchements, MOVZ/MOVN/MOVK et
    ADD/SUB sont les parties les plus sures de ce decodeur.
  @param Off Decalage de l instruction dans le fichier
  @param VAddrBase Adresse virtuelle correspondant a Off
  @param Mnemonic Mnemonique de l instruction (sortie)
  @param Operands Operandes formates (sortie)
  @return Nombre d octets occupes par l instruction (toujours 4, ou 4
    par securite si l instruction n est pas reconnue) }
Function DisasmArm64One(Off, VAddrBase: LongInt;
 Var Mnemonic, Operands: String): Integer;
Const
 CondA64: Array[0..15] Of String[3] = (
  'eq', 'ne', 'cs', 'cc', 'mi', 'pl', 'vs', 'vc',
  'hi', 'ls', 'ge', 'lt', 'gt', 'le', 'al', 'nv');
Var
 Instr: LongInt;
 Sf, Op, S, L, Opc, Cond, Hw, ShiftBits, Mode, Sz: Byte;
 Rd, Rn, Rm, Rt, Rt2: Byte;
 Imm26, Imm19, Imm16, Imm12, Imm7, Imm6: LongInt;
Begin
 Instr := GetDWord(Off);
 Mnemonic := '(bad)';
 Operands := '';

 If Instr = LongInt($D503201F) Then
  Mnemonic := 'nop'

 Else If (Instr And LongInt($FE1FFC1F)) = LongInt($D61F0000) Then Begin
  Rn := (Instr Shr 5) And 31;
  Opc := (Instr Shr 21) And 15;
  Case Opc Of
   0: Mnemonic := 'br';
   1: Mnemonic := 'blr';
   2: Mnemonic := 'ret';
  Else
   Mnemonic := '(bad)';
  End;
  If Mnemonic <> '(bad)' Then Operands := RegX(Rn);
 End

 Else If ((Instr Shr 26) And 63) = 5 Then Begin
  Imm26 := Instr And $03FFFFFF;
  If (Imm26 And $02000000) <> 0 Then Imm26 := Imm26 Or LongInt($FC000000);
  Mnemonic := 'b';
  Operands := '0x' + ToHexU(VAddrBase + (Imm26 Shl 2));
 End Else If ((Instr Shr 26) And 63) = 37 Then Begin
  Imm26 := Instr And $03FFFFFF;
  If (Imm26 And $02000000) <> 0 Then Imm26 := Imm26 Or LongInt($FC000000);
  Mnemonic := 'bl';
  Operands := '0x' + ToHexU(VAddrBase + (Imm26 Shl 2));
 End

 Else If ((Instr Shr 24) And 255) = 84 Then Begin
  If (Instr And 1) = 0 Then Begin
   Cond := Instr And 15;
   Imm19 := (Instr Shr 5) And $7FFFF;
   If (Imm19 And $40000) <> 0 Then Imm19 := Imm19 Or LongInt($FFF80000);
   Mnemonic := 'b.' + CondA64[Cond];
   Operands := '0x' + ToHexU(VAddrBase + (Imm19 Shl 2));
  End;
 End

 Else If (((Instr Shr 24) And 255) = $D4) And ((Instr And 3) = 1) And
         (((Instr Shr 21) And 7) = 0) And (((Instr Shr 2) And 7) = 0) Then Begin
  Imm16 := (Instr Shr 5) And $FFFF;
  Mnemonic := 'svc';
  Operands := '#0x' + ToHexU(Imm16);
 End

 Else If ((Instr Shr 25) And 63) = 26 Then Begin
  Sf := (Instr Shr 31) And 1;
  L  := (Instr Shr 24) And 1;
  Imm19 := (Instr Shr 5) And $7FFFF;
  If (Imm19 And $40000) <> 0 Then Imm19 := Imm19 Or LongInt($FFF80000);
  Rt := Instr And 31;
  If L = 0 Then Mnemonic := 'cbz' Else Mnemonic := 'cbnz';
  If Sf = 1 Then Operands := RegXZ(Rt) Else Operands := RegWZ(Rt);
  Operands := Operands + ',0x' + ToHexU(VAddrBase + (Imm19 Shl 2));
 End

 Else If ((Instr Shr 23) And 63) = 37 Then Begin
  Sf := (Instr Shr 31) And 1;
  Opc := (Instr Shr 29) And 3;
  Hw := (Instr Shr 21) And 3;
  Imm16 := (Instr Shr 5) And $FFFF;
  Rd := Instr And 31;
  Case Opc Of
   0: Mnemonic := 'movn';
   2: Mnemonic := 'movz';
   3: Mnemonic := 'movk';
  Else
   Mnemonic := '(bad)';
  End;
  If Mnemonic <> '(bad)' Then Begin
   If Sf = 1 Then Operands := RegXZ(Rd) Else Operands := RegWZ(Rd);
   Operands := Operands + ',#0x' + ToHexU(Imm16);
   If Hw > 0 Then Operands := Operands + ',lsl #' + IntToStr(Hw * 16);
  End;
 End

 Else If ((Instr Shr 24) And 31) = 17 Then Begin
  Sf := (Instr Shr 31) And 1;
  Op := (Instr Shr 30) And 1;
  S  := (Instr Shr 29) And 1;
  ShiftBits := (Instr Shr 22) And 3;
  Imm12 := (Instr Shr 10) And $FFF;
  Rn := (Instr Shr 5) And 31;
  Rd := Instr And 31;
  If ShiftBits = 1 Then Imm12 := Imm12 Shl 12;
  If (S = 1) And (Rd = 31) Then Begin
   If Op = 0 Then Mnemonic := 'cmn' Else Mnemonic := 'cmp';
   If Sf = 1 Then Operands := RegX(Rn) Else Operands := '%w' + IntToStr(Rn);
   Operands := Operands + ',#0x' + ToHexU(Imm12);
  End Else Begin
   If Op = 0 Then Mnemonic := 'add' Else Mnemonic := 'sub';
   If S = 1 Then Mnemonic := Mnemonic + 's';
   If Sf = 1 Then Operands := RegX(Rd) + ',' + RegX(Rn)
   Else Operands := '%w' + IntToStr(Rd) + ',%w' + IntToStr(Rn);
   Operands := Operands + ',#0x' + ToHexU(Imm12);
  End;
 End

 Else If (((Instr Shr 24) And 31) = 11) And (((Instr Shr 21) And 1) = 0) Then Begin
  Sf := (Instr Shr 31) And 1;
  Op := (Instr Shr 30) And 1;
  S  := (Instr Shr 29) And 1;
  Rm := (Instr Shr 16) And 31;
  Imm6 := (Instr Shr 10) And 63;
  Rn := (Instr Shr 5) And 31;
  Rd := Instr And 31;
  If (S = 1) And (Rd = 31) Then Begin
   If Op = 0 Then Mnemonic := 'cmn' Else Mnemonic := 'cmp';
   If Sf = 1 Then Operands := RegX(Rn) + ',' + RegX(Rm)
   Else Operands := '%w' + IntToStr(Rn) + ',%w' + IntToStr(Rm);
  End Else Begin
   If Op = 0 Then Mnemonic := 'add' Else Mnemonic := 'sub';
   If S = 1 Then Mnemonic := Mnemonic + 's';
   If Sf = 1 Then Operands := RegX(Rd) + ',' + RegX(Rn) + ',' + RegX(Rm)
   Else Operands := '%w' + IntToStr(Rd) + ',%w' + IntToStr(Rn) +
    ',%w' + IntToStr(Rm);
  End;
  If Imm6 > 0 Then Operands := Operands + ',lsl #' + IntToStr(Imm6);
 End

 Else If ((Instr Shr 24) And 31) = 10 Then Begin
  Sf := (Instr Shr 31) And 1;
  Opc := (Instr Shr 29) And 3;
  L := (Instr Shr 21) And 1; { reutilise pour le bit N }
  Rm := (Instr Shr 16) And 31;
  Imm6 := (Instr Shr 10) And 63;
  Rn := (Instr Shr 5) And 31;
  Rd := Instr And 31;
  If L = 1 Then Mnemonic := '(bad)' { N=1 : BIC/ORN/EON/BICS, non couverts }
  Else Begin
   Case Opc Of
    0: Mnemonic := 'and';
    1: Mnemonic := 'orr';
    2: Mnemonic := 'eor';
    3: Mnemonic := 'ands';
   End;
   If (Opc = 1) And (Rn = 31) And (Imm6 = 0) Then Begin
    Mnemonic := 'mov';
    If Sf = 1 Then Operands := RegXZ(Rd) + ',' + RegXZ(Rm)
    Else Operands := RegWZ(Rd) + ',' + RegWZ(Rm);
   End Else Begin
    If Sf = 1 Then
     Operands := RegXZ(Rd) + ',' + RegXZ(Rn) + ',' + RegXZ(Rm)
    Else
     Operands := RegWZ(Rd) + ',' + RegWZ(Rn) + ',' + RegWZ(Rm);
    If Imm6 > 0 Then Operands := Operands + ',lsl #' + IntToStr(Imm6);
   End;
  End;
 End

 Else If (((Instr Shr 27) And 7) = 7) And (((Instr Shr 26) And 1) = 0) And
         (((Instr Shr 24) And 3) = 1) Then Begin
  Sz := (Instr Shr 30) And 3;
  Opc := (Instr Shr 22) And 3;
  Imm12 := (Instr Shr 10) And $FFF;
  Rn := (Instr Shr 5) And 31;
  Rt := Instr And 31;
  If (Sz >= 2) And (Opc <= 1) Then Begin
   If Opc = 0 Then Mnemonic := 'str' Else Mnemonic := 'ldr';
   If Sz = 3 Then Begin
    Operands := RegXZ(Rt) + ',[' + RegX(Rn);
    Imm12 := Imm12 * 8;
   End Else Begin
    Operands := RegWZ(Rt) + ',[' + RegX(Rn);
    Imm12 := Imm12 * 4;
   End;
   If Imm12 > 0 Then Operands := Operands + ',#0x' + ToHexU(Imm12);
   Operands := Operands + ']';
  End Else
   Mnemonic := '(bad)';
 End

 Else If (((Instr Shr 27) And 7) = 5) And (((Instr Shr 26) And 1) = 0) Then Begin
  Sz   := (Instr Shr 30) And 3;
  Mode := (Instr Shr 23) And 7;
  L    := (Instr Shr 22) And 1;
  Imm7 := (Instr Shr 15) And $7F;
  If (Imm7 And $40) <> 0 Then Imm7 := Imm7 Or LongInt($FFFFFF80);
  Rt2 := (Instr Shr 10) And 31;
  Rn  := (Instr Shr 5) And 31;
  Rt  := Instr And 31;
  If L = 0 Then Mnemonic := 'stp' Else Mnemonic := 'ldp';
  If Sz = 2 Then Begin
   Operands := RegXZ(Rt) + ',' + RegXZ(Rt2) + ',[' + RegX(Rn);
   Imm7 := Imm7 * 8;
  End Else Begin
   Operands := RegWZ(Rt) + ',' + RegWZ(Rt2) + ',[' + RegX(Rn);
   Imm7 := Imm7 * 4;
  End;
  If Mode = 1 Then Begin { post-index : "[Rn], #imm" }
   Operands := Operands + ']';
   If Imm7 <> 0 Then Operands := Operands + ',#' + ToHexSignedDisp(Imm7);
  End Else Begin { decalage signe ou pre-index : "[Rn, #imm]" ou "...]!" }
   If Imm7 <> 0 Then Operands := Operands + ',#' + ToHexSignedDisp(Imm7);
   Operands := Operands + ']';
   If Mode = 3 Then Operands := Operands + '!';
  End;
 End;

 DisasmArm64One := 4;
End;

{ ============================================================
  DESASSEMBLEUR ARM 32 BITS CLASSIQUE (execution conditionnelle)
  ============================================================ }

{ @description: Nom (prefixe %) du registre ARM 32 bits numero R
    (0..15), avec les alias usuels GNU pour les registres speciaux
    (sp, lr, pc plutot que r13/r14/r15).
  @param R Numero de registre (0..15)
  @return Nom du registre }
Function RegArm(R: Byte): String;
Const
 Names: Array[0..15] Of String[3] = (
  'r0', 'r1', 'r2', 'r3', 'r4', 'r5', 'r6', 'r7',
  'r8', 'r9', 'r10', 'r11', 'r12', 'sp', 'lr', 'pc');
Begin
 RegArm := '%' + Names[R And 15];
End;

{ @description: Desassemble une seule instruction ARM 32 bits classique
    (largeur fixe 4 octets) a partir du decalage Off, en syntaxe AT&T
    simplifiee. Couvre un sous-ensemble pratique : traitement de
    donnees (AND/EOR/SUB/RSB/ADD/ADC/SBC/RSC/TST/TEQ/CMP/CMN/ORR/MOV/
    BIC/MVN, formes immediat-tourne et registre-decale), branchements
    B/BL, BX/BLX (registre), chargement/rangement simple LDR/STR(B),
    chargement/rangement multiple LDM/STM (push/pop), SVC, NOP. Le
    code condition (bits 31-28, ex: EQ/NE/CS/...) est ajoute en
    suffixe du mnemonique sauf pour AL (toujours vrai, omis comme le
    fait objdump). Pas de coprocesseur/NEON/VFP, pas de decalage par
    registre pour l adressage memoire, pas de double-mot LDRD/STRD.
  @param Off Decalage de l instruction dans le fichier
  @param VAddrBase Adresse virtuelle correspondant a Off
  @param Mnemonic Mnemonique de l instruction (sortie)
  @param Operands Operandes formates (sortie)
  @return Nombre d octets occupes par l instruction (toujours 4) }
Function DisasmArm32One(Off, VAddrBase: LongInt;
 Var Mnemonic, Operands: String): Integer;
Const
 CondArm: Array[0..15] Of String[3] = (
  'eq', 'ne', 'cs', 'cc', 'mi', 'pl', 'vs', 'vc',
  'hi', 'ls', 'ge', 'lt', 'gt', 'le', '', 'nv');
 DPNames: Array[0..15] Of String[4] = (
  'and', 'eor', 'sub', 'rsb', 'add', 'adc', 'sbc', 'rsc',
  'tst', 'teq', 'cmp', 'cmn', 'orr', 'mov', 'bic', 'mvn');
 ShiftNamesArm: Array[0..3] Of String[3] = ('lsl', 'lsr', 'asr', 'ror');
Var
 Instr: LongInt;
 Cond: Byte;
 CondTxt: String;
 IBit, OpcodeDP, SBit, Rn, Rd, Rm: Byte;
 ShiftType, ShiftImm: Byte;
 Operand2Txt: String;
 RotateAmt, ImmVal: LongInt;
 PBit, UBit, BBit, WBit, LBit: Byte;
 OffsetImm: LongInt;
 RegListTxt: String;
 I: Integer;
 Imm24, Target: LongInt;
 First: Boolean;
Begin
 Instr := GetDWord(Off);
 Mnemonic := '(bad)';
 Operands := '';
 Cond := (Instr Shr 28) And 15;
 CondTxt := CondArm[Cond];

 { ----- NOP (encodage dedie ARMv6K+) ----- }
 If (Instr And LongInt($0FFFFFFF)) = LongInt($0320F000) Then
  Mnemonic := 'nop'

 { ----- BX / BLX (registre) ----- }
 Else If (Instr And LongInt($0FFFFFF0)) = LongInt($012FFF10) Then Begin
  Rm := Instr And 15;
  Mnemonic := 'bx' + CondTxt;
  Operands := RegArm(Rm);
 End Else If (Instr And LongInt($0FFFFFF0)) = LongInt($012FFF30) Then Begin
  Rm := Instr And 15;
  Mnemonic := 'blx' + CondTxt;
  Operands := RegArm(Rm);
 End

 { ----- B / BL ----- }
 Else If ((Instr Shr 25) And 7) = 5 Then Begin
  Imm24 := Instr And $00FFFFFF;
  If (Imm24 And $00800000) <> 0 Then Imm24 := Imm24 Or LongInt($FF000000);
  Target := VAddrBase + 8 + (Imm24 Shl 2);
  If ((Instr Shr 24) And 1) = 1 Then Mnemonic := 'bl' + CondTxt
  Else Mnemonic := 'b' + CondTxt;
  Operands := '0x' + ToHexU(Target);
 End

 { ----- SVC / SWI ----- }
 Else If ((Instr Shr 24) And 15) = 15 Then Begin
  ImmVal := Instr And $00FFFFFF;
  Mnemonic := 'svc' + CondTxt;
  Operands := '#0x' + ToHexU(ImmVal);
 End

 { ----- Chargement/rangement multiple (LDM/STM, alias push/pop) ----- }
 Else If ((Instr Shr 25) And 7) = 4 Then Begin
  PBit := (Instr Shr 24) And 1;
  UBit := (Instr Shr 23) And 1;
  WBit := (Instr Shr 21) And 1;
  LBit := (Instr Shr 20) And 1;
  Rn   := (Instr Shr 16) And 15;
  { Alias courant : STMDB sp! (liste) = PUSH, LDMIA sp! (liste) = POP }
  If (Rn = 13) And (WBit = 1) And (LBit = 0) And (PBit = 1) And (UBit = 0) Then
   Mnemonic := 'push'
  Else If (Rn = 13) And (WBit = 1) And (LBit = 1) And (PBit = 0) And
          (UBit = 1) Then
   Mnemonic := 'pop'
  Else Begin
   If LBit = 1 Then Mnemonic := 'ldm' Else Mnemonic := 'stm';
   If UBit = 1 Then Begin
    If PBit = 1 Then Mnemonic := Mnemonic + 'ib' Else Mnemonic := Mnemonic + 'ia';
   End Else Begin
    If PBit = 1 Then Mnemonic := Mnemonic + 'db' Else Mnemonic := Mnemonic + 'da';
   End;
  End;
  Mnemonic := Mnemonic + CondTxt;
  If (Mnemonic <> 'push' + CondTxt) And (Mnemonic <> 'pop' + CondTxt) Then Begin
   Operands := RegArm(Rn);
   If WBit = 1 Then Operands := Operands + '!';
   Operands := Operands + ',';
  End;
  Operands := Operands + '{';
  RegListTxt := '';
  First := True;
  For I := 0 To 15 Do
   If ((Instr Shr I) And 1) = 1 Then Begin
    If Not First Then RegListTxt := RegListTxt + ',';
    RegListTxt := RegListTxt + RegArm(I);
    First := False;
   End;
  Operands := Operands + RegListTxt + '}';
 End

 { ----- Chargement/rangement simple (LDR/STR/LDRB/STRB, decalage
   immediat uniquement ; le decalage par registre n est pas couvert) ----- }
 Else If ((Instr Shr 26) And 3) = 1 Then Begin
  PBit := (Instr Shr 24) And 1;
  UBit := (Instr Shr 23) And 1;
  BBit := (Instr Shr 22) And 1;
  WBit := (Instr Shr 21) And 1;
  LBit := (Instr Shr 20) And 1;
  Rn   := (Instr Shr 16) And 15;
  Rd   := (Instr Shr 12) And 15;
  If LBit = 1 Then Mnemonic := 'ldr' Else Mnemonic := 'str';
  If BBit = 1 Then Mnemonic := Mnemonic + 'b';
  Mnemonic := Mnemonic + CondTxt;
  If ((Instr Shr 25) And 1) = 0 Then Begin
   { decalage immediat (12 bits) }
   OffsetImm := Instr And $FFF;
   Operands := RegArm(Rd) + ',[' + RegArm(Rn);
   If PBit = 1 Then Begin
    If OffsetImm <> 0 Then Begin
     If UBit = 1 Then Operands := Operands + ',#0x' + ToHexU(OffsetImm)
     Else Operands := Operands + ',#-0x' + ToHexU(OffsetImm);
    End;
    Operands := Operands + ']';
    If WBit = 1 Then Operands := Operands + '!';
   End Else Begin
    Operands := Operands + ']';
    If OffsetImm <> 0 Then Begin
     If UBit = 1 Then Operands := Operands + ',#0x' + ToHexU(OffsetImm)
     Else Operands := Operands + ',#-0x' + ToHexU(OffsetImm);
    End;
   End;
  End Else
   Mnemonic := '(bad)'; { decalage par registre : non couvert }
 End

 { ----- Traitement de donnees (bits[27:26]=00) ----- }
 Else If ((Instr Shr 26) And 3) = 0 Then Begin
  IBit     := (Instr Shr 25) And 1;
  OpcodeDP := (Instr Shr 21) And 15;
  SBit     := (Instr Shr 20) And 1;
  Rn       := (Instr Shr 16) And 15;
  Rd       := (Instr Shr 12) And 15;
  Mnemonic := DPNames[OpcodeDP];
  If (SBit = 1) And (OpcodeDP < 8) Then Mnemonic := Mnemonic + 's';
  Mnemonic := Mnemonic + CondTxt;
  If IBit = 1 Then Begin
   { operande 2 immediat : imm8 tourne de rotate*2 vers la droite }
   RotateAmt := (Instr Shr 8) And 15;
   ImmVal := Instr And 255;
   If RotateAmt > 0 Then
    ImmVal := (ImmVal Shr (RotateAmt * 2)) Or
              (ImmVal Shl (32 - RotateAmt * 2));
   Operand2Txt := '#0x' + ToHexU(ImmVal And LongInt($FFFFFFFF));
  End Else Begin
   { operande 2 registre, decalage immediat (le decalage par
     registre, bit[4]=1, n est pas couvert : (bad)) }
   If (Instr And 16) <> 0 Then Begin
    Mnemonic := '(bad)';
    Operand2Txt := '';
   End Else Begin
    Rm := Instr And 15;
    ShiftType := (Instr Shr 5) And 3;
    ShiftImm  := (Instr Shr 7) And 31;
    Operand2Txt := RegArm(Rm);
    If ShiftImm > 0 Then
     Operand2Txt := Operand2Txt + ',' + ShiftNamesArm[ShiftType] +
      ' #' + IntToStr(ShiftImm);
   End;
  End;
  If Mnemonic <> '(bad)' Then Begin
   If OpcodeDP In [8, 9, 10, 11] Then { TST/TEQ/CMP/CMN : pas de Rd }
    Operands := RegArm(Rn) + ',' + Operand2Txt
   Else If OpcodeDP In [13, 15] Then { MOV/MVN : pas de Rn }
    Operands := RegArm(Rd) + ',' + Operand2Txt
   Else
    Operands := RegArm(Rd) + ',' + RegArm(Rn) + ',' + Operand2Txt;
  End;
 End;

 DisasmArm32One := 4;
End;

{ ============================================================
  DESASSEMBLEUR THUMB / THUMB-2 (sous-ensemble courant)
  ============================================================ }

{ @description: Desassemble une seule instruction Thumb a partir du
    decalage Off. La plupart des instructions Thumb1 tiennent sur un
    seul demi-mot (2 octets) ; BL/BLX (32 bits, formee d une paire de
    demi-mots 11110xxxxxxxxxxx 11111xxxxxxxxxxx) est la seule
    extension Thumb-2 couverte ici, car omniprésente meme dans du
    code par ailleurs Thumb1. Couvre : decalage immediat (LSL/LSR/
    ASR), addition/soustraction (registre et immediat court), MOV/
    CMP/ADD/SUB immediat 8 bits, operations ALU registre a registre,
    operations sur registres hauts et BX/BLX, chargement PC-relatif,
    chargement/rangement immediat, push/pop, branchement conditionnel
    et inconditionnel, BL, SVC, NOP. Ne couvre pas : chargement/
    rangement par registre ou signe-etendu, LDM/STM generique,
    relatif a SP, ADD SP, et le reste des instructions Thumb-2 32
    bits (seul le cas BL/BLX est traite).
  @param Off Decalage de l instruction dans le fichier
  @param VAddrBase Adresse virtuelle correspondant a Off
  @param Mnemonic Mnemonique de l instruction (sortie)
  @param Operands Operandes formates (sortie)
  @return Nombre d octets occupes (2, ou 4 pour BL/BLX 32 bits) }
Function DisasmThumbOne(Off, VAddrBase: LongInt;
 Var Mnemonic, Operands: String): Integer;
Const
 CondThumb: Array[0..15] Of String[3] = (
  'eq', 'ne', 'cs', 'cc', 'mi', 'pl', 'vs', 'vc',
  'hi', 'ls', 'ge', 'lt', 'gt', 'le', '', 'nv');
Var
 W, W2: Word;
 Op, Rd, Rs, Rb, Rn: Byte;
 IBit, SBit, BBit, LBit, HBit1, HBit2: Byte;
 Offset5, Offset8, Offset11: LongInt;
 Cond: Byte;
 Target: LongInt;
 RegListTxt: String;
 First: Boolean;
 I: Integer;
Begin
 W := GetWord(Off);
 Mnemonic := '(bad)';
 Operands := '';

 { ----- format 19 : BL/BLX 32 bits (paire de demi-mots Thumb-2) ----- }
 If ((W Shr 11) And 31) = 30 Then Begin
  W2 := GetWord(Off + 2);
  If ((W2 Shr 11) And 31) = 31 Then Begin
   Offset11 := W And $7FF;
   Target := (Offset11 Shl 12) Or ((W2 And $7FF) Shl 1);
   If (Offset11 And $400) <> 0 Then Target := Target Or LongInt($FFC00000);
   Mnemonic := 'bl';
   Operands := '0x' + ToHexU(VAddrBase + 4 + Target);
   DisasmThumbOne := 4;
   Exit;
  End;
 End;

 { ----- NOP (deux idiomes courants) ----- }
 If (W = $46C0) Or (W = $BF00) Then
  Mnemonic := 'nop'

 { ----- format 18 : branchement inconditionnel ----- }
 Else If ((W Shr 11) And 31) = 28 Then Begin
  Offset11 := W And $7FF;
  If (Offset11 And $400) <> 0 Then Offset11 := Offset11 Or LongInt($FFFFF800);
  Mnemonic := 'b';
  Operands := '0x' + ToHexU(VAddrBase + 4 + (Offset11 Shl 1));
 End

 { ----- format 16 : branchement conditionnel / SVC ----- }
 Else If ((W Shr 12) And 15) = 13 Then Begin
  Cond := (W Shr 8) And 15;
  If Cond = 15 Then Begin
   Mnemonic := 'svc';
   Operands := '#0x' + ToHexU(W And 255);
  End Else Begin
   Offset8 := W And 255;
   If (Offset8 And 128) <> 0 Then Offset8 := Offset8 Or LongInt($FFFFFF00);
   Mnemonic := 'b' + CondThumb[Cond];
   Operands := '0x' + ToHexU(VAddrBase + 4 + (Offset8 Shl 1));
  End;
 End

 { ----- format 14 : push / pop ----- }
 Else If ((W Shr 12) And 15) = 11 Then Begin
  If ((W Shr 9) And 3) = 2 Then Begin
   LBit  := (W Shr 11) And 1;
   HBit1 := (W Shr 8) And 1; { bit R : inclut LR (push) ou PC (pop) }
   If LBit = 0 Then Mnemonic := 'push' Else Mnemonic := 'pop';
   RegListTxt := '';
   First := True;
   For I := 0 To 7 Do
    If ((W Shr I) And 1) = 1 Then Begin
     If Not First Then RegListTxt := RegListTxt + ',';
     RegListTxt := RegListTxt + RegArm(I);
     First := False;
    End;
   If HBit1 = 1 Then Begin
    If Not First Then RegListTxt := RegListTxt + ',';
    If LBit = 0 Then RegListTxt := RegListTxt + RegArm(14)
    Else RegListTxt := RegListTxt + RegArm(15);
   End;
   Operands := '{' + RegListTxt + '}';
  End;
 End

 { ----- format 6 : chargement PC-relatif ----- }
 Else If ((W Shr 11) And 31) = 9 Then Begin
  Rd := (W Shr 8) And 7;
  Offset8 := (W And 255) * 4;
  Mnemonic := 'ldr';
  Operands := RegArm(Rd) + ',[' + RegArm(15) + ',#0x' + ToHexU(Offset8) + ']';
 End

 { ----- format 9 : chargement/rangement avec deplacement immediat ----- }
 Else If ((W Shr 13) And 7) = 3 Then Begin
  BBit := (W Shr 12) And 1;
  LBit := (W Shr 11) And 1;
  Offset5 := (W Shr 6) And 31;
  Rb := (W Shr 3) And 7;
  Rd := W And 7;
  If LBit = 1 Then Mnemonic := 'ldr' Else Mnemonic := 'str';
  If BBit = 1 Then Mnemonic := Mnemonic + 'b' Else Offset5 := Offset5 * 4;
  Operands := RegArm(Rd) + ',[' + RegArm(Rb);
  If Offset5 <> 0 Then Operands := Operands + ',#0x' + ToHexU(Offset5);
  Operands := Operands + ']';
 End

 { ----- format 3 : MOV/CMP/ADD/SUB immediat ----- }
 Else If ((W Shr 13) And 7) = 1 Then Begin
  Op := (W Shr 11) And 3;
  Rd := (W Shr 8) And 7;
  Offset8 := W And 255;
  Case Op Of
   0: Mnemonic := 'mov'; 1: Mnemonic := 'cmp';
   2: Mnemonic := 'add'; 3: Mnemonic := 'sub';
  End;
  Operands := RegArm(Rd) + ',#0x' + ToHexU(Offset8);
 End

 { ----- format 4 : operations ALU registre a registre ----- }
 Else If ((W Shr 10) And 63) = 16 Then Begin
  Op := (W Shr 6) And 15;
  Rs := (W Shr 3) And 7;
  Rd := W And 7;
  Case Op Of
   0: Mnemonic := 'and'; 1: Mnemonic := 'eor'; 2: Mnemonic := 'lsl';
   3: Mnemonic := 'lsr'; 4: Mnemonic := 'asr'; 5: Mnemonic := 'adc';
   6: Mnemonic := 'sbc'; 7: Mnemonic := 'ror'; 8: Mnemonic := 'tst';
   9: Mnemonic := 'neg'; 10: Mnemonic := 'cmp'; 11: Mnemonic := 'cmn';
   12: Mnemonic := 'orr'; 13: Mnemonic := 'mul'; 14: Mnemonic := 'bic';
   15: Mnemonic := 'mvn';
  End;
  Operands := RegArm(Rd) + ',' + RegArm(Rs);
 End

 { ----- format 5 : operations registres hauts / BX/BLX ----- }
 Else If ((W Shr 10) And 63) = 17 Then Begin
  Op := (W Shr 8) And 3;
  HBit1 := (W Shr 7) And 1;
  HBit2 := (W Shr 6) And 1;
  Rs := ((W Shr 3) And 7) Or (HBit2 Shl 3);
  Rd := (W And 7) Or (HBit1 Shl 3);
  Case Op Of
   0: Begin Mnemonic := 'add'; Operands := RegArm(Rd) + ',' + RegArm(Rs); End;
   1: Begin Mnemonic := 'cmp'; Operands := RegArm(Rd) + ',' + RegArm(Rs); End;
   2: Begin Mnemonic := 'mov'; Operands := RegArm(Rd) + ',' + RegArm(Rs); End;
   3: Begin
       If HBit1 = 0 Then Mnemonic := 'bx' Else Mnemonic := 'blx';
       Operands := RegArm(Rs);
      End;
  End;
 End

 { ----- format 1/2 : decalage immediat, ou addition/soustraction ----- }
 Else If ((W Shr 13) And 7) = 0 Then Begin
  Op := (W Shr 11) And 3;
  If Op = 3 Then Begin
   IBit := (W Shr 10) And 1;
   SBit := (W Shr 9) And 1;
   Rn := (W Shr 6) And 7;
   Rs := (W Shr 3) And 7;
   Rd := W And 7;
   If SBit = 0 Then Mnemonic := 'add' Else Mnemonic := 'sub';
   If IBit = 0 Then
    Operands := RegArm(Rd) + ',' + RegArm(Rs) + ',' + RegArm(Rn)
   Else
    Operands := RegArm(Rd) + ',' + RegArm(Rs) + ',#0x' + ToHexU(Rn);
  End Else Begin
   Offset5 := (W Shr 6) And 31;
   Rs := (W Shr 3) And 7;
   Rd := W And 7;
   Case Op Of
    0: Mnemonic := 'lsl'; 1: Mnemonic := 'lsr'; 2: Mnemonic := 'asr';
   End;
   Operands := RegArm(Rd) + ',' + RegArm(Rs) + ',#0x' + ToHexU(Offset5);
  End;
 End;

 DisasmThumbOne := 2;
End;

{ ============================================================
  DESASSEMBLEUR 8086/80186 16 BITS (syntaxe Intel/MASM)
  ============================================================ }

{ @description: Nom (majuscules, sans prefixe) du registre 16 bits
    numero R, pour la syntaxe Intel/MASM utilisee par le 8086 (a la
    difference du x86 32 bits AT&T, qui prefixe par % en minuscules).
  @param R Numero de registre (0..7)
  @return Nom du registre en majuscules (ex: "AX") }
Function Reg16I(R: Byte): String;
Begin
 Reg16I := UpStr(Reg16Names[R And 7]);
End;

{ @description: Nom (majuscules, sans prefixe) du registre 8 bits
    numero R, syntaxe Intel/MASM.
  @param R Numero de registre (0..7)
  @return Nom du registre en majuscules (ex: "AL") }
Function Reg8I(R: Byte): String;
Begin
 Reg8I := UpStr(Reg8Names[R And 7]);
End;

{ @description: Formate une valeur en hexadecimal selon la convention
    MASM (suffixe "h", zero de tete ajoute si le premier chiffre est
    une lettre, pour ne pas etre pris pour un identificateur).
  @param V Valeur a formater
  @return Chaine hexadecimale suffixee de "h" }
Function MasmHex(V: LongInt): String;
Var
 S: String;
Begin
 S := ToHexU(V);
 If S[1] In ['a'..'f'] Then S := '0' + S;
 MasmHex := S + 'h';
End;

{ @description: Interprete un mot de 16 bits non signe comme une
    valeur signee (complement a deux), independamment du comportement
    de Shr/And sur les types signes.
  @param W Mot non signe a interpreter
  @return Valeur signee equivalente, -32768..32767 }
Function SignedWord(W: Word): LongInt;
Begin
 If W >= 32768 Then SignedWord := LongInt(W) - 65536
 Else SignedWord := LongInt(W);
End;

{ @description: Decode l octet ModRM (et l eventuel deplacement) en
    adressage 16 bits (8086), tres different du 32 bits : pas d octet
    SIB, et le champ RM (Mod<>11) designe directement une des sept
    combinaisons fixes de registres de base/index ([BX+SI], [BX+DI],
    [BP+SI], [BP+DI], [SI], [DI], [BP], [BX]), ou une adresse directe
    disp16 dans le cas particulier Mod=00,RM=110.
  @param Off Decalage du premier octet (le ModRM lui-meme)
  @param Consumed Nombre d octets consommes (sortie)
  @param RegField Champ Reg (3 bits) du ModRM (sortie)
  @param Wide Vrai pour un registre 16 bits, faux pour 8 bits, quand
    le mode est registre direct (Mod=11)
  @return Texte de l operande (registre ou adresse memoire) }
Function DecodeModRM16(Off: LongInt; Var Consumed: Integer;
 Var RegField: Byte; Wide: Boolean): String;
Const
 RM16: Array[0..7] Of String[7] = (
  'BX+SI', 'BX+DI', 'BP+SI', 'BP+DI', 'SI', 'DI', 'BP', 'BX');
Var
 ModB, RM: Byte;
 Disp: LongInt;
 P: LongInt;
Begin
 P := Off;
 ModB := (GetByte(P) Shr 6) And 3;
 RegField := (GetByte(P) Shr 3) And 7;
 RM := GetByte(P) And 7;
 Inc(P);
 Consumed := 1;
 If ModB = 3 Then Begin
  If Wide Then DecodeModRM16 := Reg16I(RM) Else DecodeModRM16 := Reg8I(RM);
  Exit;
 End;
 If (ModB = 0) And (RM = 6) Then Begin
  Disp := GetWord(P); P := P + 2; Consumed := Consumed + 2;
  DecodeModRM16 := '[' + MasmHex(Disp) + ']';
  Exit;
 End;
 Disp := 0;
 If ModB = 1 Then Begin
  Disp := ShortInt(GetByte(P)); Inc(P); Inc(Consumed);
 End Else If ModB = 2 Then Begin
  Disp := SignedWord(GetWord(P)); P := P + 2; Consumed := Consumed + 2;
 End;
 If Disp = 0 Then DecodeModRM16 := '[' + RM16[RM] + ']'
 Else If Disp > 0 Then
  DecodeModRM16 := '[' + RM16[RM] + '+' + MasmHex(Disp) + ']'
 Else
  DecodeModRM16 := '[' + RM16[RM] + '-' + MasmHex(-Disp) + ']';
End;

{ @description: Desassemble une seule instruction 8086/80186 16 bits
    a partir du decalage Off, en syntaxe Intel/MASM (mnemonique en
    majuscules, ordre destination puis source, registres sans
    prefixe). Couvre le jeu d instructions courant (mov, push/pop,
    arithmetique, branchements, decalages, multiplications/divisions)
    ; pas de prefixes de segment repliés dans l operande (affiches
    comme pseudo-instruction separee), pas d opcodes etendus 0F
    (Jcc longue, movzx/movsx : introduits avec le 386, hors de
    portee du 8086/80186).
  @param Off Decalage de l instruction dans le fichier
  @param VAddrBase Adresse (relative au debut du module) de Off
  @param Mnemonic Mnemonique de l instruction (sortie)
  @param Operands Operandes formates, syntaxe Intel (sortie)
  @return Nombre d octets occupes par l instruction }
Function Disasm8086One(Off, VAddrBase: LongInt;
 Var Mnemonic, Operands: String): Integer;
Const
 Cc8086: Array[0..15] Of String[4] = (
  'JO', 'JNO', 'JB', 'JAE', 'JE', 'JNE', 'JBE', 'JA',
  'JS', 'JNS', 'JP', 'JNP', 'JL', 'JGE', 'JLE', 'JG');
 Grp1Names8086: Array[0..7] Of String[4] = (
  'ADD', 'OR', 'ADC', 'SBB', 'AND', 'SUB', 'XOR', 'CMP');
 ShiftNames8086: Array[0..7] Of String[4] = (
  'ROL', 'ROR', 'RCL', 'RCR', 'SHL', 'SHR', 'SAL', 'SAR');
 SegNames8086: Array[0..3] Of String[2] = ('ES', 'CS', 'SS', 'DS');
Var
 Op: Byte;
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

 { ----- prefixes de segment : affiches comme pseudo-instruction ----- }
 If Op = $2E Then Begin Mnemonic := 'CS:'; End
 Else If Op = $36 Then Begin Mnemonic := 'SS:'; End
 Else If Op = $3E Then Begin Mnemonic := 'DS:'; End
 Else If Op = $26 Then Begin Mnemonic := 'ES:'; End

 { ----- push/pop registre general ----- }
 Else If (Op >= $50) And (Op <= $57) Then Begin
  Mnemonic := 'PUSH'; Operands := Reg16I(Op - $50);
 End Else If (Op >= $58) And (Op <= $5F) Then Begin
  Mnemonic := 'POP'; Operands := Reg16I(Op - $58);
 End

 { ----- push/pop registre de segment ----- }
 Else If Op = $06 Then Begin Mnemonic := 'PUSH'; Operands := 'ES'; End
 Else If Op = $07 Then Begin Mnemonic := 'POP';  Operands := 'ES'; End
 Else If Op = $0E Then Begin Mnemonic := 'PUSH'; Operands := 'CS'; End
 Else If Op = $16 Then Begin Mnemonic := 'PUSH'; Operands := 'SS'; End
 Else If Op = $17 Then Begin Mnemonic := 'POP';  Operands := 'SS'; End
 Else If Op = $1E Then Begin Mnemonic := 'PUSH'; Operands := 'DS'; End
 Else If Op = $1F Then Begin Mnemonic := 'POP';  Operands := 'DS'; End

 { ----- push immediat (80186+, tolere pour usage pratique) ----- }
 Else If Op = $68 Then Begin
  Imm := GetWord(P); P := P + 2;
  Mnemonic := 'PUSH'; Operands := MasmHex(Imm);
 End Else If Op = $6A Then Begin
  Imm := ShortInt(GetByte(P)); Inc(P);
  Mnemonic := 'PUSH'; Operands := MasmHex(Imm);
 End

 { ----- mov reg16, imm16 ----- }
 Else If (Op >= $B8) And (Op <= $BF) Then Begin
  Imm := GetWord(P); P := P + 2;
  Mnemonic := 'MOV'; Operands := Reg16I(Op - $B8) + ',' + MasmHex(Imm);
 End

 { ----- mov reg8, imm8 ----- }
 Else If (Op >= $B0) And (Op <= $B7) Then Begin
  Imm := GetByte(P); Inc(P);
  Mnemonic := 'MOV'; Operands := Reg8I(Op - $B0) + ',' + MasmHex(Imm);
 End

 { ----- inc/dec reg16 ----- }
 Else If (Op >= $40) And (Op <= $47) Then Begin
  Mnemonic := 'INC'; Operands := Reg16I(Op - $40);
 End Else If (Op >= $48) And (Op <= $4F) Then Begin
  Mnemonic := 'DEC'; Operands := Reg16I(Op - $48);
 End

 { ----- mov r/m16,r16 (89) / mov r16,r/m16 (8B) ----- }
 Else If Op = $89 Then Begin
  RM := DecodeModRM16(P, Len, RegF, True); P := P + Len;
  Mnemonic := 'MOV'; Operands := RM + ',' + Reg16I(RegF);
 End Else If Op = $8B Then Begin
  RM := DecodeModRM16(P, Len, RegF, True); P := P + Len;
  Mnemonic := 'MOV'; Operands := Reg16I(RegF) + ',' + RM;
 End

 { ----- mov r/m16,segreg (8C) / mov segreg,r/m16 (8E) ----- }
 Else If Op = $8C Then Begin
  RM := DecodeModRM16(P, Len, RegF, True); P := P + Len;
  Mnemonic := 'MOV'; Operands := RM + ',' + SegNames8086[RegF And 3];
 End Else If Op = $8E Then Begin
  RM := DecodeModRM16(P, Len, RegF, True); P := P + Len;
  Mnemonic := 'MOV'; Operands := SegNames8086[RegF And 3] + ',' + RM;
 End

 { ----- mov AL/AX,[adresse directe] (A0/A1) et inverse (A2/A3) ----- }
 Else If Op = $A0 Then Begin
  Imm := GetWord(P); P := P + 2;
  Mnemonic := 'MOV'; Operands := 'AL,[' + MasmHex(Imm) + ']';
 End Else If Op = $A1 Then Begin
  Imm := GetWord(P); P := P + 2;
  Mnemonic := 'MOV'; Operands := 'AX,[' + MasmHex(Imm) + ']';
 End Else If Op = $A2 Then Begin
  Imm := GetWord(P); P := P + 2;
  Mnemonic := 'MOV'; Operands := '[' + MasmHex(Imm) + '],AL';
 End Else If Op = $A3 Then Begin
  Imm := GetWord(P); P := P + 2;
  Mnemonic := 'MOV'; Operands := '[' + MasmHex(Imm) + '],AX';
 End

 { ----- instructions sur chaines (octet/mot) et prefixes REP/REPNE ----- }
 Else If Op = $A4 Then Begin Mnemonic := 'MOVSB'; End
 Else If Op = $A5 Then Begin Mnemonic := 'MOVSW'; End
 Else If Op = $A6 Then Begin Mnemonic := 'CMPSB'; End
 Else If Op = $A7 Then Begin Mnemonic := 'CMPSW'; End
 Else If Op = $AA Then Begin Mnemonic := 'STOSB'; End
 Else If Op = $AB Then Begin Mnemonic := 'STOSW'; End
 Else If Op = $AC Then Begin Mnemonic := 'LODSB'; End
 Else If Op = $AD Then Begin Mnemonic := 'LODSW'; End
 Else If Op = $AE Then Begin Mnemonic := 'SCASB'; End
 Else If Op = $AF Then Begin Mnemonic := 'SCASW'; End
 Else If Op = $F2 Then Begin Mnemonic := 'REPNE'; End
 Else If Op = $F3 Then Begin Mnemonic := 'REP'; End

 { ----- mov r/m8,r8 (88) / mov r8,r/m8 (8A) ----- }
 Else If Op = $88 Then Begin
  RM := DecodeModRM16(P, Len, RegF, False); P := P + Len;
  Mnemonic := 'MOV'; Operands := RM + ',' + Reg8I(RegF);
 End Else If Op = $8A Then Begin
  RM := DecodeModRM16(P, Len, RegF, False); P := P + Len;
  Mnemonic := 'MOV'; Operands := Reg8I(RegF) + ',' + RM;
 End

 { ----- mov r/m16, imm16 (C7) / mov r/m8, imm8 (C6) ----- }
 Else If Op = $C7 Then Begin
  RM := DecodeModRM16(P, Len, RegF, True); P := P + Len;
  Imm := GetWord(P); P := P + 2;
  Mnemonic := 'MOV'; Operands := RM + ',' + MasmHex(Imm);
 End Else If Op = $C6 Then Begin
  RM := DecodeModRM16(P, Len, RegF, False); P := P + Len;
  Imm := GetByte(P); Inc(P);
  Mnemonic := 'MOV'; Operands := RM + ',' + MasmHex(Imm);
 End

 { ----- lea reg16, m ----- }
 Else If Op = $8D Then Begin
  RM := DecodeModRM16(P, Len, RegF, True); P := P + Len;
  Mnemonic := 'LEA'; Operands := Reg16I(RegF) + ',' + RM;
 End

 { ----- les/lds reg16, m (charge ES:reg ou DS:reg depuis dword) ----- }
 Else If Op = $C4 Then Begin
  RM := DecodeModRM16(P, Len, RegF, True); P := P + Len;
  Mnemonic := 'LES'; Operands := Reg16I(RegF) + ',' + RM;
 End Else If Op = $C5 Then Begin
  RM := DecodeModRM16(P, Len, RegF, True); P := P + Len;
  Mnemonic := 'LDS'; Operands := Reg16I(RegF) + ',' + RM;
 End

 { ----- instructions BCD intercalees dans le bloc 00-3F : doivent
   etre interceptees AVANT le groupe arithmetique generique ci-dessous,
   sinon "Op < $40" les absorbe a tort comme formes 7 inexistantes. ----- }
 Else If Op = $27 Then Begin
  Mnemonic := 'DAA';
 End Else If Op = $2F Then Begin
  Mnemonic := 'DAS';
 End Else If Op = $37 Then Begin
  Mnemonic := 'AAA';
 End Else If Op = $3F Then Begin
  Mnemonic := 'AAS';
 End

 { ----- groupe arithmetique 00-3F (add/or/adc/sbb/and/sub/xor/cmp) ----- }
 Else If Op < $40 Then Begin
  Case Op And 7 Of
   0: Begin
       RM := DecodeModRM16(P, Len, RegF, False); P := P + Len;
       Mnemonic := Grp1Names8086[(Op Shr 3) And 7];
       Operands := RM + ',' + Reg8I(RegF);
      End;
   1: Begin
       RM := DecodeModRM16(P, Len, RegF, True); P := P + Len;
       Mnemonic := Grp1Names8086[(Op Shr 3) And 7];
       Operands := RM + ',' + Reg16I(RegF);
      End;
   2: Begin
       RM := DecodeModRM16(P, Len, RegF, False); P := P + Len;
       Mnemonic := Grp1Names8086[(Op Shr 3) And 7];
       Operands := Reg8I(RegF) + ',' + RM;
      End;
   3: Begin
       RM := DecodeModRM16(P, Len, RegF, True); P := P + Len;
       Mnemonic := Grp1Names8086[(Op Shr 3) And 7];
       Operands := Reg16I(RegF) + ',' + RM;
      End;
   4: Begin
       Imm := GetByte(P); Inc(P);
       Mnemonic := Grp1Names8086[(Op Shr 3) And 7];
       Operands := Reg8I(0) + ',' + MasmHex(Imm);
      End;
   5: Begin
       Imm := GetWord(P); P := P + 2;
       Mnemonic := Grp1Names8086[(Op Shr 3) And 7];
       Operands := Reg16I(0) + ',' + MasmHex(Imm);
      End;
  Else
   Mnemonic := '(bad)';
  End;
 End

 { ----- groupe 1 avec immediat : 80/81/83 ----- }
 Else If Op = $80 Then Begin
  RM := DecodeModRM16(P, Len, RegF, False); P := P + Len;
  Imm := GetByte(P); Inc(P);
  Mnemonic := Grp1Names8086[RegF And 7];
  Operands := RM + ',' + MasmHex(Imm);
 End Else If Op = $81 Then Begin
  RM := DecodeModRM16(P, Len, RegF, True); P := P + Len;
  Imm := GetWord(P); P := P + 2;
  Mnemonic := Grp1Names8086[RegF And 7];
  Operands := RM + ',' + MasmHex(Imm);
 End Else If Op = $83 Then Begin
  RM := DecodeModRM16(P, Len, RegF, True); P := P + Len;
  Imm := ShortInt(GetByte(P)); Inc(P);
  Mnemonic := Grp1Names8086[RegF And 7];
  Operands := RM + ',' + MasmHex(Imm);
 End

 { ----- test r/m,r ; test AL/AX,imm ----- }
 Else If Op = $84 Then Begin
  RM := DecodeModRM16(P, Len, RegF, False); P := P + Len;
  Mnemonic := 'TEST'; Operands := RM + ',' + Reg8I(RegF);
 End Else If Op = $85 Then Begin
  RM := DecodeModRM16(P, Len, RegF, True); P := P + Len;
  Mnemonic := 'TEST'; Operands := RM + ',' + Reg16I(RegF);
 End Else If Op = $A8 Then Begin
  Imm := GetByte(P); Inc(P);
  Mnemonic := 'TEST'; Operands := 'AL,' + MasmHex(Imm);
 End Else If Op = $A9 Then Begin
  Imm := GetWord(P); P := P + 2;
  Mnemonic := 'TEST'; Operands := 'AX,' + MasmHex(Imm);
 End

 { ----- call/jmp relatifs (deplacement 16 bits, pas 32) ----- }
 Else If Op = $E8 Then Begin
  Rel := SignedWord(GetWord(P)); P := P + 2;
  Mnemonic := 'CALL'; Operands := MasmHex(VAddrBase + (P - Off) + Rel);
 End Else If Op = $E9 Then Begin
  Rel := SignedWord(GetWord(P)); P := P + 2;
  Mnemonic := 'JMP'; Operands := MasmHex(VAddrBase + (P - Off) + Rel);
 End Else If Op = $EB Then Begin
  Rel := ShortInt(GetByte(P)); Inc(P);
  Mnemonic := 'JMP'; Operands := MasmHex(VAddrBase + (P - Off) + Rel);
 End

 { ----- Jcc rel8 (70-7F) ----- }
 Else If (Op >= $70) And (Op <= $7F) Then Begin
  Rel := ShortInt(GetByte(P)); Inc(P);
  Mnemonic := Cc8086[Op - $70];
  Operands := MasmHex(VAddrBase + (P - Off) + Rel);
 End

 { ----- JCXZ / LOOP / LOOPE / LOOPNE (rel8) ----- }
 Else If Op = $E0 Then Begin
  Rel := ShortInt(GetByte(P)); Inc(P);
  Mnemonic := 'LOOPNE'; Operands := MasmHex(VAddrBase + (P - Off) + Rel);
 End Else If Op = $E1 Then Begin
  Rel := ShortInt(GetByte(P)); Inc(P);
  Mnemonic := 'LOOPE'; Operands := MasmHex(VAddrBase + (P - Off) + Rel);
 End Else If Op = $E2 Then Begin
  Rel := ShortInt(GetByte(P)); Inc(P);
  Mnemonic := 'LOOP'; Operands := MasmHex(VAddrBase + (P - Off) + Rel);
 End Else If Op = $E3 Then Begin
  Rel := ShortInt(GetByte(P)); Inc(P);
  Mnemonic := 'JCXZ'; Operands := MasmHex(VAddrBase + (P - Off) + Rel);
 End

 { ----- ret / leave / nop / int / cbw / cwd ----- }
 Else If Op = $C3 Then Begin
  Mnemonic := 'RET';
 End Else If Op = $C2 Then Begin
  Imm := GetWord(P); P := P + 2;
  Mnemonic := 'RET'; Operands := MasmHex(Imm);
 End Else If Op = $CB Then Begin
  Mnemonic := 'RETF';
 End Else If Op = $CA Then Begin
  Imm := GetWord(P); P := P + 2;
  Mnemonic := 'RETF'; Operands := MasmHex(Imm);
 End Else If Op = $C9 Then Begin
  Mnemonic := 'LEAVE';
 End Else If Op = $90 Then Begin
  Mnemonic := 'NOP';
 End Else If Op = $CC Then Begin
  Mnemonic := 'INT3';
 End Else If Op = $CD Then Begin
  Imm := GetByte(P); Inc(P);
  Mnemonic := 'INT'; Operands := MasmHex(Imm);
 End Else If Op = $98 Then Begin
  Mnemonic := 'CBW';
 End Else If Op = $99 Then Begin
  Mnemonic := 'CWD';
 End Else If Op = $F4 Then Begin
  Mnemonic := 'HLT';
 End Else If Op = $F8 Then Begin
  Mnemonic := 'CLC';
 End Else If Op = $F9 Then Begin
  Mnemonic := 'STC';
 End Else If Op = $FA Then Begin
  Mnemonic := 'CLI';
 End Else If Op = $FB Then Begin
  Mnemonic := 'STI';
 End Else If Op = $FC Then Begin
  Mnemonic := 'CLD';
 End Else If Op = $FD Then Begin
  Mnemonic := 'STD';
 End Else If Op = $F5 Then Begin
  Mnemonic := 'CMC';
 End

 { ----- appel/saut lointain (inter-segment) : ptr16:16, 5 octets ----- }
 Else If Op = $9A Then Begin
  Imm := GetWord(P);          { offset }
  Rel := GetWord(P + 2);      { segment }
  P := P + 4;
  Mnemonic := 'CALLF';
  Operands := MasmHex(Rel) + ':' + MasmHex(Imm);
 End Else If Op = $EA Then Begin
  Imm := GetWord(P);
  Rel := GetWord(P + 2);
  P := P + 4;
  Mnemonic := 'JMPF';
  Operands := MasmHex(Rel) + ':' + MasmHex(Imm);
 End

 { ----- pile des indicateurs, table de conversion, BCD ----- }
 Else If Op = $9C Then Begin
  Mnemonic := 'PUSHF';
 End Else If Op = $9D Then Begin
  Mnemonic := 'POPF';
 End Else If Op = $D7 Then Begin
  Mnemonic := 'XLAT';
 End Else If Op = $D4 Then Begin
  Inc(P); { octet immediat de l encodage, toujours 0Ah en pratique }
  Mnemonic := 'AAM';
 End Else If Op = $D5 Then Begin
  Inc(P);
  Mnemonic := 'AAD';
 End

 { ----- groupe decalages : C0/C1 (imm8), D0-D3 (1 ou CL) ----- }
 Else If Op = $C0 Then Begin
  RM := DecodeModRM16(P, Len, RegF, False); P := P + Len;
  Imm := GetByte(P); Inc(P);
  Mnemonic := ShiftNames8086[RegF And 7];
  Operands := RM + ',' + MasmHex(Imm);
 End Else If Op = $C1 Then Begin
  RM := DecodeModRM16(P, Len, RegF, True); P := P + Len;
  Imm := GetByte(P); Inc(P);
  Mnemonic := ShiftNames8086[RegF And 7];
  Operands := RM + ',' + MasmHex(Imm);
 End Else If Op = $D0 Then Begin
  RM := DecodeModRM16(P, Len, RegF, False); P := P + Len;
  Mnemonic := ShiftNames8086[RegF And 7]; Operands := RM + ',1';
 End Else If Op = $D1 Then Begin
  RM := DecodeModRM16(P, Len, RegF, True); P := P + Len;
  Mnemonic := ShiftNames8086[RegF And 7]; Operands := RM + ',1';
 End Else If Op = $D2 Then Begin
  RM := DecodeModRM16(P, Len, RegF, False); P := P + Len;
  Mnemonic := ShiftNames8086[RegF And 7]; Operands := RM + ',CL';
 End Else If Op = $D3 Then Begin
  RM := DecodeModRM16(P, Len, RegF, True); P := P + Len;
  Mnemonic := ShiftNames8086[RegF And 7]; Operands := RM + ',CL';
 End

 { ----- groupe FE/FF : inc/dec/call/jmp/push selon RegField ----- }
 Else If Op = $FE Then Begin
  RM := DecodeModRM16(P, Len, RegF, False); P := P + Len;
  If (RegF And 7) = 0 Then Mnemonic := 'INC' Else Mnemonic := 'DEC';
  Operands := RM;
 End Else If Op = $FF Then Begin
  RM := DecodeModRM16(P, Len, RegF, True); P := P + Len;
  Case RegF And 7 Of
   0: Mnemonic := 'INC';
   1: Mnemonic := 'DEC';
   2: Mnemonic := 'CALL';
   4: Mnemonic := 'JMP';
   6: Mnemonic := 'PUSH';
  Else
   Mnemonic := '(bad)';
  End;
  If Mnemonic <> '(bad)' Then Operands := RM;
 End

 { ----- groupe F6/F7 : test/not/neg/mul/imul/div/idiv ----- }
 Else If Op = $F6 Then Begin
  RM := DecodeModRM16(P, Len, RegF, False); P := P + Len;
  Case RegF And 7 Of
   0, 1: Begin
          Imm := GetByte(P); Inc(P);
          Mnemonic := 'TEST'; Operands := RM + ',' + MasmHex(Imm);
         End;
   2: Begin Mnemonic := 'NOT'; Operands := RM; End;
   3: Begin Mnemonic := 'NEG'; Operands := RM; End;
   4: Begin Mnemonic := 'MUL'; Operands := RM; End;
   5: Begin Mnemonic := 'IMUL'; Operands := RM; End;
   6: Begin Mnemonic := 'DIV'; Operands := RM; End;
   7: Begin Mnemonic := 'IDIV'; Operands := RM; End;
  End;
 End Else If Op = $F7 Then Begin
  RM := DecodeModRM16(P, Len, RegF, True); P := P + Len;
  Case RegF And 7 Of
   0, 1: Begin
          Imm := GetWord(P); P := P + 2;
          Mnemonic := 'TEST'; Operands := RM + ',' + MasmHex(Imm);
         End;
   2: Begin Mnemonic := 'NOT'; Operands := RM; End;
   3: Begin Mnemonic := 'NEG'; Operands := RM; End;
   4: Begin Mnemonic := 'MUL'; Operands := RM; End;
   5: Begin Mnemonic := 'IMUL'; Operands := RM; End;
   6: Begin Mnemonic := 'DIV'; Operands := RM; End;
   7: Begin Mnemonic := 'IDIV'; Operands := RM; End;
  End;
 End

 { ----- imul reg16, r/m16, imm (69 = imm16, 6B = imm8) ----- }
 Else If Op = $69 Then Begin
  RM := DecodeModRM16(P, Len, RegF, True); P := P + Len;
  Imm := GetWord(P); P := P + 2;
  Mnemonic := 'IMUL';
  Operands := Reg16I(RegF) + ',' + RM + ',' + MasmHex(Imm);
 End Else If Op = $6B Then Begin
  RM := DecodeModRM16(P, Len, RegF, True); P := P + Len;
  Imm := ShortInt(GetByte(P)); Inc(P);
  Mnemonic := 'IMUL';
  Operands := Reg16I(RegF) + ',' + RM + ',' + MasmHex(Imm);
 End;

 If P <= Off Then P := Off + 1; { securite anti-boucle infinie }
 Disasm8086One := P - Off;
End;

{ ============================================================
  DESASSEMBLEUR 6502 (jeu d instructions documente complet, 151 opcodes)
  ============================================================ }

{ @description: Enregistre un opcode 6502 dans les tables Mnem6502/
    Mode6502.
  @param Code Valeur de l opcode (0..255)
  @param M Mnemonique (ex: "LDA")
  @param Mode Mode d adressage (AM_xxx) }
Procedure SetOp6502(Code: Byte; M: String; Mode: Byte);
Begin
 Mnem6502[Code] := M;
 Mode6502[Code] := Mode;
End;

{ @description: Remplit les tables d opcodes 6502 (Mnem6502/Mode6502)
    avec les 151 opcodes documentes du 6502 NMOS. Les opcodes non
    renseignes restent a chaine vide (illegaux/non documentes), et
    sont affiches comme "(bad)" par Disasm6502One. }
Procedure InitOpcodes6502;
Var
 I: Integer;
Begin
 For I := 0 To 255 Do Begin
  Mnem6502[I] := '';
  Mode6502[I] := AM_NONE;
 End;
 SetOp6502($69, 'ADC', AM_IMM); SetOp6502($65, 'ADC', AM_ZP);
 SetOp6502($75, 'ADC', AM_ZPX); SetOp6502($6D, 'ADC', AM_ABS);
 SetOp6502($7D, 'ADC', AM_ABSX); SetOp6502($79, 'ADC', AM_ABSY);
 SetOp6502($61, 'ADC', AM_INDX); SetOp6502($71, 'ADC', AM_INDY);
 SetOp6502($29, 'AND', AM_IMM); SetOp6502($25, 'AND', AM_ZP);
 SetOp6502($35, 'AND', AM_ZPX); SetOp6502($2D, 'AND', AM_ABS);
 SetOp6502($3D, 'AND', AM_ABSX); SetOp6502($39, 'AND', AM_ABSY);
 SetOp6502($21, 'AND', AM_INDX); SetOp6502($31, 'AND', AM_INDY);
 SetOp6502($0A, 'ASL', AM_ACC); SetOp6502($06, 'ASL', AM_ZP);
 SetOp6502($16, 'ASL', AM_ZPX); SetOp6502($0E, 'ASL', AM_ABS);
 SetOp6502($1E, 'ASL', AM_ABSX);
 SetOp6502($90, 'BCC', AM_REL); SetOp6502($B0, 'BCS', AM_REL);
 SetOp6502($F0, 'BEQ', AM_REL);
 SetOp6502($24, 'BIT', AM_ZP); SetOp6502($2C, 'BIT', AM_ABS);
 SetOp6502($30, 'BMI', AM_REL); SetOp6502($D0, 'BNE', AM_REL);
 SetOp6502($10, 'BPL', AM_REL);
 SetOp6502($00, 'BRK', AM_IMP);
 SetOp6502($50, 'BVC', AM_REL); SetOp6502($70, 'BVS', AM_REL);
 SetOp6502($18, 'CLC', AM_IMP); SetOp6502($D8, 'CLD', AM_IMP);
 SetOp6502($58, 'CLI', AM_IMP); SetOp6502($B8, 'CLV', AM_IMP);
 SetOp6502($C9, 'CMP', AM_IMM); SetOp6502($C5, 'CMP', AM_ZP);
 SetOp6502($D5, 'CMP', AM_ZPX); SetOp6502($CD, 'CMP', AM_ABS);
 SetOp6502($DD, 'CMP', AM_ABSX); SetOp6502($D9, 'CMP', AM_ABSY);
 SetOp6502($C1, 'CMP', AM_INDX); SetOp6502($D1, 'CMP', AM_INDY);
 SetOp6502($E0, 'CPX', AM_IMM); SetOp6502($E4, 'CPX', AM_ZP);
 SetOp6502($EC, 'CPX', AM_ABS);
 SetOp6502($C0, 'CPY', AM_IMM); SetOp6502($C4, 'CPY', AM_ZP);
 SetOp6502($CC, 'CPY', AM_ABS);
 SetOp6502($C6, 'DEC', AM_ZP); SetOp6502($D6, 'DEC', AM_ZPX);
 SetOp6502($CE, 'DEC', AM_ABS); SetOp6502($DE, 'DEC', AM_ABSX);
 SetOp6502($CA, 'DEX', AM_IMP); SetOp6502($88, 'DEY', AM_IMP);
 SetOp6502($49, 'EOR', AM_IMM); SetOp6502($45, 'EOR', AM_ZP);
 SetOp6502($55, 'EOR', AM_ZPX); SetOp6502($4D, 'EOR', AM_ABS);
 SetOp6502($5D, 'EOR', AM_ABSX); SetOp6502($59, 'EOR', AM_ABSY);
 SetOp6502($41, 'EOR', AM_INDX); SetOp6502($51, 'EOR', AM_INDY);
 SetOp6502($E6, 'INC', AM_ZP); SetOp6502($F6, 'INC', AM_ZPX);
 SetOp6502($EE, 'INC', AM_ABS); SetOp6502($FE, 'INC', AM_ABSX);
 SetOp6502($E8, 'INX', AM_IMP); SetOp6502($C8, 'INY', AM_IMP);
 SetOp6502($4C, 'JMP', AM_ABS); SetOp6502($6C, 'JMP', AM_IND);
 SetOp6502($20, 'JSR', AM_ABS);
 SetOp6502($A9, 'LDA', AM_IMM); SetOp6502($A5, 'LDA', AM_ZP);
 SetOp6502($B5, 'LDA', AM_ZPX); SetOp6502($AD, 'LDA', AM_ABS);
 SetOp6502($BD, 'LDA', AM_ABSX); SetOp6502($B9, 'LDA', AM_ABSY);
 SetOp6502($A1, 'LDA', AM_INDX); SetOp6502($B1, 'LDA', AM_INDY);
 SetOp6502($A2, 'LDX', AM_IMM); SetOp6502($A6, 'LDX', AM_ZP);
 SetOp6502($B6, 'LDX', AM_ZPY); SetOp6502($AE, 'LDX', AM_ABS);
 SetOp6502($BE, 'LDX', AM_ABSY);
 SetOp6502($A0, 'LDY', AM_IMM); SetOp6502($A4, 'LDY', AM_ZP);
 SetOp6502($B4, 'LDY', AM_ZPX); SetOp6502($AC, 'LDY', AM_ABS);
 SetOp6502($BC, 'LDY', AM_ABSX);
 SetOp6502($4A, 'LSR', AM_ACC); SetOp6502($46, 'LSR', AM_ZP);
 SetOp6502($56, 'LSR', AM_ZPX); SetOp6502($4E, 'LSR', AM_ABS);
 SetOp6502($5E, 'LSR', AM_ABSX);
 SetOp6502($EA, 'NOP', AM_IMP);
 SetOp6502($09, 'ORA', AM_IMM); SetOp6502($05, 'ORA', AM_ZP);
 SetOp6502($15, 'ORA', AM_ZPX); SetOp6502($0D, 'ORA', AM_ABS);
 SetOp6502($1D, 'ORA', AM_ABSX); SetOp6502($19, 'ORA', AM_ABSY);
 SetOp6502($01, 'ORA', AM_INDX); SetOp6502($11, 'ORA', AM_INDY);
 SetOp6502($48, 'PHA', AM_IMP); SetOp6502($08, 'PHP', AM_IMP);
 SetOp6502($68, 'PLA', AM_IMP); SetOp6502($28, 'PLP', AM_IMP);
 SetOp6502($2A, 'ROL', AM_ACC); SetOp6502($26, 'ROL', AM_ZP);
 SetOp6502($36, 'ROL', AM_ZPX); SetOp6502($2E, 'ROL', AM_ABS);
 SetOp6502($3E, 'ROL', AM_ABSX);
 SetOp6502($6A, 'ROR', AM_ACC); SetOp6502($66, 'ROR', AM_ZP);
 SetOp6502($76, 'ROR', AM_ZPX); SetOp6502($6E, 'ROR', AM_ABS);
 SetOp6502($7E, 'ROR', AM_ABSX);
 SetOp6502($40, 'RTI', AM_IMP); SetOp6502($60, 'RTS', AM_IMP);
 SetOp6502($E9, 'SBC', AM_IMM); SetOp6502($E5, 'SBC', AM_ZP);
 SetOp6502($F5, 'SBC', AM_ZPX); SetOp6502($ED, 'SBC', AM_ABS);
 SetOp6502($FD, 'SBC', AM_ABSX); SetOp6502($F9, 'SBC', AM_ABSY);
 SetOp6502($E1, 'SBC', AM_INDX); SetOp6502($F1, 'SBC', AM_INDY);
 SetOp6502($38, 'SEC', AM_IMP); SetOp6502($F8, 'SED', AM_IMP);
 SetOp6502($78, 'SEI', AM_IMP);
 SetOp6502($85, 'STA', AM_ZP); SetOp6502($95, 'STA', AM_ZPX);
 SetOp6502($8D, 'STA', AM_ABS); SetOp6502($9D, 'STA', AM_ABSX);
 SetOp6502($99, 'STA', AM_ABSY); SetOp6502($81, 'STA', AM_INDX);
 SetOp6502($91, 'STA', AM_INDY);
 SetOp6502($86, 'STX', AM_ZP); SetOp6502($96, 'STX', AM_ZPY);
 SetOp6502($8E, 'STX', AM_ABS);
 SetOp6502($84, 'STY', AM_ZP); SetOp6502($94, 'STY', AM_ZPX);
 SetOp6502($8C, 'STY', AM_ABS);
 SetOp6502($AA, 'TAX', AM_IMP); SetOp6502($A8, 'TAY', AM_IMP);
 SetOp6502($BA, 'TSX', AM_IMP); SetOp6502($8A, 'TXA', AM_IMP);
 SetOp6502($9A, 'TXS', AM_IMP); SetOp6502($98, 'TYA', AM_IMP);
End;

{ @description: Desassemble une seule instruction 6502 a partir du
    decalage Off dans le fichier. Chaque opcode 6502 a un mode
    d adressage fixe (contrairement au x86, pas de ModRM a decoder) :
    Mode6502[octet] indique combien d octets supplementaires lire et
    comment les formater. Les opcodes non documentes (Mnem6502[octet]
    vide) produisent "(bad)" et avancent d un octet.
  @param Off Decalage de l instruction dans le fichier
  @param VAddrBase Adresse virtuelle correspondant a Off (pour
    resoudre la cible des branchements relatifs)
  @param Mnemonic Mnemonique de l instruction (sortie)
  @param Operands Operandes formates (sortie)
  @return Nombre d octets occupes par l instruction (1, 2 ou 3) }
Function Disasm6502One(Off, VAddrBase: LongInt;
 Var Mnemonic, Operands: String): Integer;
Var
 Op: Byte;
 Mode: Byte;
 B1: Byte;
 W1: Word;
 Rel: ShortInt;
 Target: LongInt;
Begin
 Op := GetByte(Off);
 Mnemonic := Mnem6502[Op];
 Mode := Mode6502[Op];
 If Mnemonic = '' Then Begin
  Mnemonic := '(bad)';
  Operands := '';
  Disasm6502One := 1;
  Exit;
 End;
 Operands := '';
 Case Mode Of
  AM_IMP: Disasm6502One := 1;
  AM_ACC: Begin
   Operands := 'A';
   Disasm6502One := 1;
  End;
  AM_IMM: Begin
   B1 := GetByte(Off + 1);
   Operands := '#$' + ToHexFixed(B1, 2);
   Disasm6502One := 2;
  End;
  AM_ZP: Begin
   B1 := GetByte(Off + 1);
   Operands := '$' + ToHexFixed(B1, 2);
   Disasm6502One := 2;
  End;
  AM_ZPX: Begin
   B1 := GetByte(Off + 1);
   Operands := '$' + ToHexFixed(B1, 2) + ',X';
   Disasm6502One := 2;
  End;
  AM_ZPY: Begin
   B1 := GetByte(Off + 1);
   Operands := '$' + ToHexFixed(B1, 2) + ',Y';
   Disasm6502One := 2;
  End;
  AM_ABS: Begin
   W1 := GetWord(Off + 1);
   Operands := '$' + ToHexFixed(W1, 4);
   Disasm6502One := 3;
  End;
  AM_ABSX: Begin
   W1 := GetWord(Off + 1);
   Operands := '$' + ToHexFixed(W1, 4) + ',X';
   Disasm6502One := 3;
  End;
  AM_ABSY: Begin
   W1 := GetWord(Off + 1);
   Operands := '$' + ToHexFixed(W1, 4) + ',Y';
   Disasm6502One := 3;
  End;
  AM_IND: Begin
   W1 := GetWord(Off + 1);
   Operands := '($' + ToHexFixed(W1, 4) + ')';
   Disasm6502One := 3;
  End;
  AM_INDX: Begin
   B1 := GetByte(Off + 1);
   Operands := '($' + ToHexFixed(B1, 2) + ',X)';
   Disasm6502One := 2;
  End;
  AM_INDY: Begin
   B1 := GetByte(Off + 1);
   Operands := '($' + ToHexFixed(B1, 2) + '),Y';
   Disasm6502One := 2;
  End;
  AM_REL: Begin
   Rel := ShortInt(GetByte(Off + 1));
   Target := VAddrBase + 2 + Rel;
   Operands := '$' + ToHexFixed(Target, 4);
   Disasm6502One := 2;
  End;
 Else
  Disasm6502One := 1;
 End;
End;

{ ============================================================
  DESASSEMBLEUR Z80 (sur-ensemble du 8080, sous-ensemble pratique)
  ============================================================ }

{ @description: Desassemble une seule instruction Z80 a partir du
    decalage Off. Le Z80 a une structure d opcode tres reguliere pour
    les instructions non prefixees (xx yyy zzz), exploitee directement
    ici plutot que par une grande table comme pour le 6502. Couvre
    le jeu de base complet (compatible 8080 : LD, ALU, INC/DEC, JP/
    JR/CALL/RET conditionnels ou non, PUSH/POP, RST, rotations de
    l accumulateur, DJNZ, EX) ainsi qu un sous-ensemble pratique des
    formes prefixees : CB (rotations/decalages de registre, BIT/SET/
    RES), ED (16 bits ADC/SBC/LD, NEG, IM, RETI/RETN, instructions de
    bloc LDIR/LDDR/CPIR/CPDR et variantes courtes LDI/LDD/CPI/CPD) et
    DD/FD (acces indexes (IX+d)/(IY+d) pour LD/ALU/INC/DEC, plus
    PUSH/POP/INC/DEC/ADD/JP sur IX/IY directement). Ne couvre pas les
    formes DDCB/FDCB (bit indexe), ni l ensemble des instructions
    d entree/sortie ED, ni RLD/RRD.
  @param Off Decalage de l instruction dans le fichier
  @param VAddrBase Adresse virtuelle correspondant a Off
  @param Mnemonic Mnemonique de l instruction (sortie)
  @param Operands Operandes formates (sortie)
  @return Nombre d octets occupes par l instruction }

{ @description: Formate un deplacement signe pour la syntaxe Z80
    "(IX+d)"/"(IY+d)" : contrairement a ToHexSignedDisp (qui omet le
    signe "+" pour une valeur positive, adaptee a un contexte ou le
    signe est deja fourni par ailleurs), le "+" doit ici toujours
    apparaitre explicitement pour un deplacement positif ou nul.
  @param D Deplacement signe (-128..127)
  @return "+0xNN" ou "-0xNN" }
Function IxDispStr(D: ShortInt): String;
Begin
 If D < 0 Then IxDispStr := '-0x' + ToHexU(-D)
 Else IxDispStr := '+0x' + ToHexU(D);
End;

Function DisasmZ80One(Off, VAddrBase: LongInt;
 Var Mnemonic, Operands: String): Integer;
Const
 Reg8Z80: Array[0..7] Of String[4] = (
  'B', 'C', 'D', 'E', 'H', 'L', '(HL)', 'A');
 Reg16Z80: Array[0..3] Of String[2] = ('BC', 'DE', 'HL', 'SP');
 Reg16Z80AF: Array[0..3] Of String[2] = ('BC', 'DE', 'HL', 'AF');
 AluZ80: Array[0..7] Of String[3] = (
  'ADD', 'ADC', 'SUB', 'SBC', 'AND', 'XOR', 'OR', 'CP');
 CondZ80: Array[0..7] Of String[2] = (
  'NZ', 'Z', 'NC', 'C', 'PO', 'PE', 'P', 'M');
 CondJrZ80: Array[0..3] Of String[2] = ('NZ', 'Z', 'NC', 'C');
 RotZ80: Array[0..7] Of String[3] = (
  'RLC', 'RRC', 'RL', 'RR', 'SLA', 'SRA', 'SLL', 'SRL');
Var
 Op, Op2: Byte;
 P: LongInt;
 X, Y, Z, P2, Q: Byte;
 D8: LongInt;
 D16: LongInt;
 Disp: ShortInt;
 IxName: String[2];
Begin
 P := Off;
 Op := GetByte(P);
 Inc(P);
 Mnemonic := '(bad)';
 Operands := '';

 { ----- CB : rotations/decalages de registre, BIT/SET/RES ----- }
 If Op = $CB Then Begin
  Op2 := GetByte(P); Inc(P);
  X := (Op2 Shr 6) And 3;
  Y := (Op2 Shr 3) And 7;
  Z := Op2 And 7;
  Case X Of
   0: Begin Mnemonic := RotZ80[Y]; Operands := Reg8Z80[Z]; End;
   1: Begin Mnemonic := 'BIT'; Operands := IntToStr(Y) + ',' + Reg8Z80[Z]; End;
   2: Begin Mnemonic := 'RES'; Operands := IntToStr(Y) + ',' + Reg8Z80[Z]; End;
   3: Begin Mnemonic := 'SET'; Operands := IntToStr(Y) + ',' + Reg8Z80[Z]; End;
  End;
 End

 { ----- ED : instructions etendues (sous-ensemble pratique) ----- }
 Else If Op = $ED Then Begin
  Op2 := GetByte(P); Inc(P);
  P2 := (Op2 Shr 4) And 3;
  Q := (Op2 Shr 3) And 1;
  Case Op2 Of
   $44: Mnemonic := 'NEG';
   $4D: Mnemonic := 'RETI';
   $45: Mnemonic := 'RETN';
   $46, $4E: Begin Mnemonic := 'IM'; Operands := '0'; End;
   $56, $5E: Begin Mnemonic := 'IM'; Operands := '1'; End;
   $66, $6E: Begin Mnemonic := 'IM'; Operands := '2'; End;
   $47: Begin Mnemonic := 'LD'; Operands := 'I,A'; End;
   $4F: Begin Mnemonic := 'LD'; Operands := 'R,A'; End;
   $57: Begin Mnemonic := 'LD'; Operands := 'A,I'; End;
   $5F: Begin Mnemonic := 'LD'; Operands := 'A,R'; End;
   $67: Mnemonic := 'RRD';
   $6F: Mnemonic := 'RLD';
   $A0: Mnemonic := 'LDI';
   $A8: Mnemonic := 'LDD';
   $B0: Mnemonic := 'LDIR';
   $B8: Mnemonic := 'LDDR';
   $A1: Mnemonic := 'CPI';
   $A9: Mnemonic := 'CPD';
   $B1: Mnemonic := 'CPIR';
   $B9: Mnemonic := 'CPDR';
   $A2: Mnemonic := 'INI';
   $AA: Mnemonic := 'IND';
   $B2: Mnemonic := 'INIR';
   $BA: Mnemonic := 'INDR';
   $A3: Mnemonic := 'OUTI';
   $AB: Mnemonic := 'OUTD';
   $B3: Mnemonic := 'OTIR';
   $BB: Mnemonic := 'OTDR';
  Else Begin
   If (Op2 And $C7) = $42 Then Begin
    Mnemonic := 'SBC'; Operands := 'HL,' + Reg16Z80[P2];
   End Else If (Op2 And $C7) = $4A Then Begin
    Mnemonic := 'ADC'; Operands := 'HL,' + Reg16Z80[P2];
   End Else If (Op2 And $C7) = $43 Then Begin
    D16 := GetWord(P); P := P + 2;
    Mnemonic := 'LD';
    Operands := '(0x' + ToHexU(D16) + '),' + Reg16Z80[P2];
   End Else If (Op2 And $C7) = $4B Then Begin
    D16 := GetWord(P); P := P + 2;
    Mnemonic := 'LD';
    Operands := Reg16Z80[P2] + ',(0x' + ToHexU(D16) + ')';
   End Else
    Mnemonic := '(bad)';
  End;
  End;
 End

 { ----- DD/FD : variantes indexees par IX ou IY ----- }
 Else If (Op = $DD) Or (Op = $FD) Then Begin
  If Op = $DD Then IxName := 'IX' Else IxName := 'IY';
  Op2 := GetByte(P); Inc(P);
  Case Op2 Of
   $21: Begin
    D16 := GetWord(P); P := P + 2;
    Mnemonic := 'LD'; Operands := IxName + ',0x' + ToHexU(D16);
   End;
   $E5: Begin Mnemonic := 'PUSH'; Operands := IxName; End;
   $E1: Begin Mnemonic := 'POP'; Operands := IxName; End;
   $23: Begin Mnemonic := 'INC'; Operands := IxName; End;
   $2B: Begin Mnemonic := 'DEC'; Operands := IxName; End;
   $E9: Begin Mnemonic := 'JP'; Operands := '(' + IxName + ')'; End;
   $F9: Begin Mnemonic := 'LD'; Operands := 'SP,' + IxName; End;
   $09, $19, $39: Begin
    Mnemonic := 'ADD';
    Operands := IxName + ',' + Reg16Z80[(Op2 Shr 4) And 3];
   End;
   $29: Begin Mnemonic := 'ADD'; Operands := IxName + ',' + IxName; End;
   $34, $35, $36: Begin
    Disp := ShortInt(GetByte(P)); Inc(P);
    If Op2 = $34 Then Mnemonic := 'INC'
    Else If Op2 = $35 Then Mnemonic := 'DEC'
    Else Mnemonic := 'LD';
    Operands := '(' + IxName + IxDispStr(Disp) + ')';
    If Op2 = $36 Then Begin
     D8 := GetByte(P); Inc(P);
     Operands := Operands + ',0x' + ToHexU(D8);
    End;
   End;
  Else Begin
   X := (Op2 Shr 6) And 3;
   Y := (Op2 Shr 3) And 7;
   Z := Op2 And 7;
   If (X = 1) And (Z = 6) And (Y <> 6) Then Begin
    { LD r,(IX+d) }
    Disp := ShortInt(GetByte(P)); Inc(P);
    Mnemonic := 'LD';
    Operands := Reg8Z80[Y] + ',(' + IxName + IxDispStr(Disp) + ')';
   End Else If (X = 1) And (Y = 6) And (Z <> 6) Then Begin
    { LD (IX+d),r }
    Disp := ShortInt(GetByte(P)); Inc(P);
    Mnemonic := 'LD';
    Operands := '(' + IxName + IxDispStr(Disp) + '),' + Reg8Z80[Z];
   End Else If (X = 2) And (Z = 6) Then Begin
    { ALU A,(IX+d) }
    Disp := ShortInt(GetByte(P)); Inc(P);
    Mnemonic := AluZ80[Y];
    If Y In [0, 1, 3] Then
     Operands := 'A,(' + IxName + IxDispStr(Disp) + ')'
    Else
     Operands := '(' + IxName + IxDispStr(Disp) + ')';
   End Else
    Mnemonic := '(bad)';
  End;
  End;
 End

 { ----- instructions de base (non prefixees) ----- }
 Else Begin
  X := (Op Shr 6) And 3;
  Y := (Op Shr 3) And 7;
  Z := Op And 7;
  P2 := (Op Shr 4) And 3;
  Q := (Op Shr 3) And 1;

  Case X Of

   0: Case Z Of
       0: Case Y Of
           0: Mnemonic := 'NOP';
           1: Begin Mnemonic := 'EX'; Operands := 'AF,AF'''; End;
           2: Begin
               Disp := ShortInt(GetByte(P)); Inc(P);
               Mnemonic := 'DJNZ';
               Operands := '0x' + ToHexU(VAddrBase + (P - Off) + Disp);
              End;
           3: Begin
               Disp := ShortInt(GetByte(P)); Inc(P);
               Mnemonic := 'JR';
               Operands := '0x' + ToHexU(VAddrBase + (P - Off) + Disp);
              End;
          Else Begin
           Disp := ShortInt(GetByte(P)); Inc(P);
           Mnemonic := 'JR';
           Operands := CondJrZ80[Y - 4] + ',0x' +
            ToHexU(VAddrBase + (P - Off) + Disp);
          End;
          End;
       1: Begin
           If Q = 0 Then Begin
            D16 := GetWord(P); P := P + 2;
            Mnemonic := 'LD'; Operands := Reg16Z80[P2] + ',0x' + ToHexU(D16);
           End Else Begin
            Mnemonic := 'ADD'; Operands := 'HL,' + Reg16Z80[P2];
           End;
          End;
       2: Case Y Of
           0: Begin Mnemonic := 'LD'; Operands := '(BC),A'; End;
           1: Begin Mnemonic := 'LD'; Operands := 'A,(BC)'; End;
           2: Begin Mnemonic := 'LD'; Operands := '(DE),A'; End;
           3: Begin Mnemonic := 'LD'; Operands := 'A,(DE)'; End;
           4: Begin
               D16 := GetWord(P); P := P + 2;
               Mnemonic := 'LD'; Operands := '(0x' + ToHexU(D16) + '),HL';
              End;
           5: Begin
               D16 := GetWord(P); P := P + 2;
               Mnemonic := 'LD'; Operands := 'HL,(0x' + ToHexU(D16) + ')';
              End;
           6: Begin
               D16 := GetWord(P); P := P + 2;
               Mnemonic := 'LD'; Operands := '(0x' + ToHexU(D16) + '),A';
              End;
           7: Begin
               D16 := GetWord(P); P := P + 2;
               Mnemonic := 'LD'; Operands := 'A,(0x' + ToHexU(D16) + ')';
              End;
          End;
       3: Begin
           If Q = 0 Then Mnemonic := 'INC' Else Mnemonic := 'DEC';
           Operands := Reg16Z80[P2];
          End;
       4: Begin Mnemonic := 'INC'; Operands := Reg8Z80[Y]; End;
       5: Begin Mnemonic := 'DEC'; Operands := Reg8Z80[Y]; End;
       6: Begin
           D8 := GetByte(P); Inc(P);
           Mnemonic := 'LD'; Operands := Reg8Z80[Y] + ',0x' + ToHexU(D8);
          End;
       7: Case Y Of
           0: Mnemonic := 'RLCA'; 1: Mnemonic := 'RRCA';
           2: Mnemonic := 'RLA';  3: Mnemonic := 'RRA';
           4: Mnemonic := 'DAA';  5: Mnemonic := 'CPL';
           6: Mnemonic := 'SCF';  7: Mnemonic := 'CCF';
          End;
      End;

   1: Begin
       If Op = $76 Then Mnemonic := 'HALT'
       Else Begin
        Mnemonic := 'LD'; Operands := Reg8Z80[Y] + ',' + Reg8Z80[Z];
       End;
      End;

   2: Begin
       Mnemonic := AluZ80[Y];
       If Y In [0, 1, 3] Then Operands := 'A,' + Reg8Z80[Z] { ADD/ADC/SBC }
       Else Operands := Reg8Z80[Z]; { SUB/AND/XOR/OR/CP : pas de "A," }
      End;

   3: Case Z Of
       0: Begin Mnemonic := 'RET'; Operands := CondZ80[Y]; End;
       1: Begin
           If Q = 0 Then Begin
            Mnemonic := 'POP'; Operands := Reg16Z80AF[P2];
           End Else Case P2 Of
            0: Mnemonic := 'RET';
            1: Mnemonic := 'EXX';
            2: Begin Mnemonic := 'JP'; Operands := '(HL)'; End;
            3: Begin Mnemonic := 'LD'; Operands := 'SP,HL'; End;
           End;
          End;
       2: Begin
           D16 := GetWord(P); P := P + 2;
           Mnemonic := 'JP'; Operands := CondZ80[Y] + ',0x' + ToHexU(D16);
          End;
       3: Case Y Of
           0: Begin
               D16 := GetWord(P); P := P + 2;
               Mnemonic := 'JP'; Operands := '0x' + ToHexU(D16);
              End;
           2: Begin
               D8 := GetByte(P); Inc(P);
               Mnemonic := 'OUT'; Operands := '(0x' + ToHexU(D8) + '),A';
              End;
           3: Begin
               D8 := GetByte(P); Inc(P);
               Mnemonic := 'IN'; Operands := 'A,(0x' + ToHexU(D8) + ')';
              End;
           4: Begin Mnemonic := 'EX'; Operands := '(SP),HL'; End;
           5: Begin Mnemonic := 'EX'; Operands := 'DE,HL'; End;
           6: Mnemonic := 'DI';
           7: Mnemonic := 'EI';
          Else
           Mnemonic := '(bad)'; { Y=1 : CB deja intercepte plus haut }
          End;
       4: Begin
           D16 := GetWord(P); P := P + 2;
           Mnemonic := 'CALL'; Operands := CondZ80[Y] + ',0x' + ToHexU(D16);
          End;
       5: Begin
           If Q = 0 Then Begin
            Mnemonic := 'PUSH'; Operands := Reg16Z80AF[P2];
           End Else If P2 = 0 Then Begin
            D16 := GetWord(P); P := P + 2;
            Mnemonic := 'CALL'; Operands := '0x' + ToHexU(D16);
           End Else
            Mnemonic := '(bad)'; { P2=1/2/3 : DD/ED/FD deja intercepte }
          End;
       6: Begin
           D8 := GetByte(P); Inc(P);
           Mnemonic := AluZ80[Y];
           If Y In [0, 1, 3] Then Operands := 'A,0x' + ToHexU(D8)
           Else Operands := '0x' + ToHexU(D8);
          End;
       7: Begin Mnemonic := 'RST'; Operands := '0x' + ToHexU(Y * 8); End;
      End;
  End;
 End;

 If P <= Off Then P := Off + 1; { securite anti-boucle infinie }
 DisasmZ80One := P - Off;
End;

{ ============================================================
  DESASSEMBLEUR MOTOROLA 6800 (jeu d instructions documente complet)
  ============================================================ }

{ @description: Enregistre un opcode 6800 dans les tables Mnem6800/
    Mode6800.
  @param Code Valeur de l opcode (0..255)
  @param M Mnemonique (ex: "LDAA")
  @param Mode Mode d adressage (AM68_xxx) }
Procedure SetOp68(Code: Byte; M: String; Mode: Byte);
Begin
 Mnem6800[Code] := M;
 Mode6800[Code] := Mode;
End;

{ @description: Remplit les tables d opcodes 6800 (Mnem6800/Mode6800)
    avec le jeu d instructions documente complet du Motorola 6800
    (accumulateurs A/B, registre d index X, pile, branchements). Les
    opcodes non renseignes restent a chaine vide (illegaux), affiches
    comme "(bad)" par Disasm6800One. }
Procedure InitOpcodes6800;
Var
 I: Integer;
Begin
 For I := 0 To 255 Do Begin
  Mnem6800[I] := '';
  Mode6800[I] := AM68_INH;
 End;

 { ----- inherent (sans operande) ----- }
 SetOp68($01, 'NOP', AM68_INH);
 SetOp68($06, 'TAP', AM68_INH);  SetOp68($07, 'TPA', AM68_INH);
 SetOp68($08, 'INX', AM68_INH);  SetOp68($09, 'DEX', AM68_INH);
 SetOp68($0A, 'CLV', AM68_INH);  SetOp68($0B, 'SEV', AM68_INH);
 SetOp68($0C, 'CLC', AM68_INH);  SetOp68($0D, 'SEC', AM68_INH);
 SetOp68($0E, 'CLI', AM68_INH);  SetOp68($0F, 'SEI', AM68_INH);
 SetOp68($10, 'SBA', AM68_INH);  SetOp68($11, 'CBA', AM68_INH);
 SetOp68($16, 'TAB', AM68_INH);  SetOp68($17, 'TBA', AM68_INH);
 SetOp68($19, 'DAA', AM68_INH);
 SetOp68($1B, 'ABA', AM68_INH);
 SetOp68($30, 'TSX', AM68_INH);  SetOp68($31, 'INS', AM68_INH);
 SetOp68($32, 'PULA', AM68_INH); SetOp68($33, 'PULB', AM68_INH);
 SetOp68($34, 'DES', AM68_INH);  SetOp68($35, 'TXS', AM68_INH);
 SetOp68($36, 'PSHA', AM68_INH); SetOp68($37, 'PSHB', AM68_INH);
 SetOp68($39, 'RTS', AM68_INH);  SetOp68($3B, 'RTI', AM68_INH);
 SetOp68($3E, 'WAI', AM68_INH);  SetOp68($3F, 'SWI', AM68_INH);
 SetOp68($40, 'NEGA', AM68_INH); SetOp68($43, 'COMA', AM68_INH);
 SetOp68($44, 'LSRA', AM68_INH); SetOp68($46, 'RORA', AM68_INH);
 SetOp68($47, 'ASRA', AM68_INH); SetOp68($48, 'ASLA', AM68_INH);
 SetOp68($49, 'ROLA', AM68_INH); SetOp68($4A, 'DECA', AM68_INH);
 SetOp68($4C, 'INCA', AM68_INH); SetOp68($4D, 'TSTA', AM68_INH);
 SetOp68($4F, 'CLRA', AM68_INH);
 SetOp68($50, 'NEGB', AM68_INH); SetOp68($53, 'COMB', AM68_INH);
 SetOp68($54, 'LSRB', AM68_INH); SetOp68($56, 'RORB', AM68_INH);
 SetOp68($57, 'ASRB', AM68_INH); SetOp68($58, 'ASLB', AM68_INH);
 SetOp68($59, 'ROLB', AM68_INH); SetOp68($5A, 'DECB', AM68_INH);
 SetOp68($5C, 'INCB', AM68_INH); SetOp68($5D, 'TSTB', AM68_INH);
 SetOp68($5F, 'CLRB', AM68_INH);

 { ----- relatif (branchements, 1 octet signe) ----- }
 SetOp68($20, 'BRA', AM68_REL); SetOp68($21, 'BRN', AM68_REL);
 SetOp68($22, 'BHI', AM68_REL); SetOp68($23, 'BLS', AM68_REL);
 SetOp68($24, 'BCC', AM68_REL); SetOp68($25, 'BCS', AM68_REL);
 SetOp68($26, 'BNE', AM68_REL); SetOp68($27, 'BEQ', AM68_REL);
 SetOp68($28, 'BVC', AM68_REL); SetOp68($29, 'BVS', AM68_REL);
 SetOp68($2A, 'BPL', AM68_REL); SetOp68($2B, 'BMI', AM68_REL);
 SetOp68($2C, 'BGE', AM68_REL); SetOp68($2D, 'BLT', AM68_REL);
 SetOp68($2E, 'BGT', AM68_REL); SetOp68($2F, 'BLE', AM68_REL);
 SetOp68($8D, 'BSR', AM68_REL);

 { ----- etendu (memoire, sans accumulateur dedie) ----- }
 SetOp68($6E, 'JMP', AM68_IDX); SetOp68($7E, 'JMP', AM68_EXT);
 SetOp68($6D, 'TST', AM68_IDX); SetOp68($7D, 'TST', AM68_EXT);
 SetOp68($6F, 'CLR', AM68_IDX); SetOp68($7F, 'CLR', AM68_EXT);
 SetOp68($60, 'NEG', AM68_IDX); SetOp68($70, 'NEG', AM68_EXT);
 SetOp68($63, 'COM', AM68_IDX); SetOp68($73, 'COM', AM68_EXT);
 SetOp68($64, 'LSR', AM68_IDX); SetOp68($74, 'LSR', AM68_EXT);
 SetOp68($66, 'ROR', AM68_IDX); SetOp68($76, 'ROR', AM68_EXT);
 SetOp68($67, 'ASR', AM68_IDX); SetOp68($77, 'ASR', AM68_EXT);
 SetOp68($68, 'ASL', AM68_IDX); SetOp68($78, 'ASL', AM68_EXT);
 SetOp68($69, 'ROL', AM68_IDX); SetOp68($79, 'ROL', AM68_EXT);
 SetOp68($6A, 'DEC', AM68_IDX); SetOp68($7A, 'DEC', AM68_EXT);
 SetOp68($6C, 'INC', AM68_IDX); SetOp68($7C, 'INC', AM68_EXT);
 SetOp68($AD, 'JSR', AM68_IDX); SetOp68($BD, 'JSR', AM68_EXT);

 { ----- accumulateur A : immediat/direct/indexe/etendu ----- }
 SetOp68($80, 'SUBA', AM68_IMM8); SetOp68($90, 'SUBA', AM68_DIR);
 SetOp68($A0, 'SUBA', AM68_IDX);  SetOp68($B0, 'SUBA', AM68_EXT);
 SetOp68($81, 'CMPA', AM68_IMM8); SetOp68($91, 'CMPA', AM68_DIR);
 SetOp68($A1, 'CMPA', AM68_IDX);  SetOp68($B1, 'CMPA', AM68_EXT);
 SetOp68($82, 'SBCA', AM68_IMM8); SetOp68($92, 'SBCA', AM68_DIR);
 SetOp68($A2, 'SBCA', AM68_IDX);  SetOp68($B2, 'SBCA', AM68_EXT);
 SetOp68($84, 'ANDA', AM68_IMM8); SetOp68($94, 'ANDA', AM68_DIR);
 SetOp68($A4, 'ANDA', AM68_IDX);  SetOp68($B4, 'ANDA', AM68_EXT);
 SetOp68($85, 'BITA', AM68_IMM8); SetOp68($95, 'BITA', AM68_DIR);
 SetOp68($A5, 'BITA', AM68_IDX);  SetOp68($B5, 'BITA', AM68_EXT);
 SetOp68($86, 'LDAA', AM68_IMM8); SetOp68($96, 'LDAA', AM68_DIR);
 SetOp68($A6, 'LDAA', AM68_IDX);  SetOp68($B6, 'LDAA', AM68_EXT);
 SetOp68($97, 'STAA', AM68_DIR);
 SetOp68($A7, 'STAA', AM68_IDX);  SetOp68($B7, 'STAA', AM68_EXT);
 SetOp68($88, 'EORA', AM68_IMM8); SetOp68($98, 'EORA', AM68_DIR);
 SetOp68($A8, 'EORA', AM68_IDX);  SetOp68($B8, 'EORA', AM68_EXT);
 SetOp68($89, 'ADCA', AM68_IMM8); SetOp68($99, 'ADCA', AM68_DIR);
 SetOp68($A9, 'ADCA', AM68_IDX);  SetOp68($B9, 'ADCA', AM68_EXT);
 SetOp68($8A, 'ORAA', AM68_IMM8); SetOp68($9A, 'ORAA', AM68_DIR);
 SetOp68($AA, 'ORAA', AM68_IDX);  SetOp68($BA, 'ORAA', AM68_EXT);
 SetOp68($8B, 'ADDA', AM68_IMM8); SetOp68($9B, 'ADDA', AM68_DIR);
 SetOp68($AB, 'ADDA', AM68_IDX);  SetOp68($BB, 'ADDA', AM68_EXT);

 { ----- accumulateur B : immediat/direct/indexe/etendu ----- }
 SetOp68($C0, 'SUBB', AM68_IMM8); SetOp68($D0, 'SUBB', AM68_DIR);
 SetOp68($E0, 'SUBB', AM68_IDX);  SetOp68($F0, 'SUBB', AM68_EXT);
 SetOp68($C1, 'CMPB', AM68_IMM8); SetOp68($D1, 'CMPB', AM68_DIR);
 SetOp68($E1, 'CMPB', AM68_IDX);  SetOp68($F1, 'CMPB', AM68_EXT);
 SetOp68($C2, 'SBCB', AM68_IMM8); SetOp68($D2, 'SBCB', AM68_DIR);
 SetOp68($E2, 'SBCB', AM68_IDX);  SetOp68($F2, 'SBCB', AM68_EXT);
 SetOp68($C4, 'ANDB', AM68_IMM8); SetOp68($D4, 'ANDB', AM68_DIR);
 SetOp68($E4, 'ANDB', AM68_IDX);  SetOp68($F4, 'ANDB', AM68_EXT);
 SetOp68($C5, 'BITB', AM68_IMM8); SetOp68($D5, 'BITB', AM68_DIR);
 SetOp68($E5, 'BITB', AM68_IDX);  SetOp68($F5, 'BITB', AM68_EXT);
 SetOp68($C6, 'LDAB', AM68_IMM8); SetOp68($D6, 'LDAB', AM68_DIR);
 SetOp68($E6, 'LDAB', AM68_IDX);  SetOp68($F6, 'LDAB', AM68_EXT);
 SetOp68($D7, 'STAB', AM68_DIR);
 SetOp68($E7, 'STAB', AM68_IDX);  SetOp68($F7, 'STAB', AM68_EXT);
 SetOp68($C8, 'EORB', AM68_IMM8); SetOp68($D8, 'EORB', AM68_DIR);
 SetOp68($E8, 'EORB', AM68_IDX);  SetOp68($F8, 'EORB', AM68_EXT);
 SetOp68($C9, 'ADCB', AM68_IMM8); SetOp68($D9, 'ADCB', AM68_DIR);
 SetOp68($E9, 'ADCB', AM68_IDX);  SetOp68($F9, 'ADCB', AM68_EXT);
 SetOp68($CA, 'ORAB', AM68_IMM8); SetOp68($DA, 'ORAB', AM68_DIR);
 SetOp68($EA, 'ORAB', AM68_IDX);  SetOp68($FA, 'ORAB', AM68_EXT);
 SetOp68($CB, 'ADDB', AM68_IMM8); SetOp68($DB, 'ADDB', AM68_DIR);
 SetOp68($EB, 'ADDB', AM68_IDX);  SetOp68($FB, 'ADDB', AM68_EXT);

 { ----- registre d index X et pointeur de pile S (16 bits) ----- }
 SetOp68($8C, 'CPX', AM68_IMM16); SetOp68($9C, 'CPX', AM68_DIR);
 SetOp68($AC, 'CPX', AM68_IDX);   SetOp68($BC, 'CPX', AM68_EXT);
 SetOp68($CE, 'LDX', AM68_IMM16); SetOp68($DE, 'LDX', AM68_DIR);
 SetOp68($EE, 'LDX', AM68_IDX);   SetOp68($FE, 'LDX', AM68_EXT);
 SetOp68($DF, 'STX', AM68_DIR);
 SetOp68($EF, 'STX', AM68_IDX);   SetOp68($FF, 'STX', AM68_EXT);
 SetOp68($8E, 'LDS', AM68_IMM16); SetOp68($9E, 'LDS', AM68_DIR);
 SetOp68($AE, 'LDS', AM68_IDX);   SetOp68($BE, 'LDS', AM68_EXT);
 SetOp68($9F, 'STS', AM68_DIR);
 SetOp68($AF, 'STS', AM68_IDX);   SetOp68($BF, 'STS', AM68_EXT);
End;

{ @description: Desassemble une seule instruction Motorola 6800 a
    partir du decalage Off dans le fichier. Comme pour le 6502, chaque
    opcode a un mode d adressage fixe enregistre dans Mode6800[octet],
    indiquant combien d octets supplementaires lire et comment les
    formater (syntaxe Motorola usuelle : #$nn immediat, $nn direct,
    $nnnn etendu, $nn,X indexe). Les opcodes non documentes (Mnem6800
    vide) produisent "(bad)" et avancent d un octet.
  @param Off Decalage de l instruction dans le fichier
  @param VAddrBase Adresse virtuelle correspondant a Off (pour
    resoudre la cible des branchements relatifs)
  @param Mnemonic Mnemonique de l instruction (sortie)
  @param Operands Operandes formates (sortie)
  @return Nombre d octets occupes par l instruction (1, 2 ou 3) }
Function Disasm6800One(Off, VAddrBase: LongInt;
 Var Mnemonic, Operands: String): Integer;
Var
 Op: Byte;
 Mode: Byte;
 B1: Byte;
 W1: Word;
 Rel: ShortInt;
 Target: LongInt;
Begin
 Op := GetByte(Off);
 Mnemonic := Mnem6800[Op];
 Mode := Mode6800[Op];
 If Mnemonic = '' Then Begin
  Mnemonic := '(bad)';
  Operands := '';
  Disasm6800One := 1;
  Exit;
 End;
 Operands := '';
 Case Mode Of
  AM68_INH: Disasm6800One := 1;
  AM68_IMM8: Begin
   B1 := GetByte(Off + 1);
   Operands := '#$' + ToHexFixed(B1, 2);
   Disasm6800One := 2;
  End;
  AM68_IMM16: Begin
   W1 := GetWordBE(Off + 1);
   Operands := '#$' + ToHexFixed(W1, 4);
   Disasm6800One := 3;
  End;
  AM68_DIR: Begin
   B1 := GetByte(Off + 1);
   Operands := '$' + ToHexFixed(B1, 2);
   Disasm6800One := 2;
  End;
  AM68_EXT: Begin
   W1 := GetWordBE(Off + 1);
   Operands := '$' + ToHexFixed(W1, 4);
   Disasm6800One := 3;
  End;
  AM68_IDX: Begin
   B1 := GetByte(Off + 1);
   Operands := '$' + ToHexFixed(B1, 2) + ',X';
   Disasm6800One := 2;
  End;
  AM68_REL: Begin
   Rel := ShortInt(GetByte(Off + 1));
   Target := VAddrBase + 2 + Rel;
   Operands := '$' + ToHexFixed(Target, 4);
   Disasm6800One := 2;
  End;
 Else
  Disasm6800One := 1;
 End;
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

{ @description: Nom du format binaire detecte, pour l affichage
    d entete (style "objdump").
  @return Nom du format (ex: "elf32-i386", "pei-i386") }
Function FormatName: String;
Begin
 Case BinFormat Of
  FMT_ELF32: FormatName := 'elf32-i386';
  FMT_ELF64: FormatName := 'elf64-x86-64';
  FMT_PE32:  FormatName := 'pei-i386';
  FMT_PE64:  FormatName := 'pei-x86-64';
  FMT_NES:   FormatName := 'nes-rom (6502)';
  FMT_RAW:   FormatName := 'raw-binary (-m/-b)';
  FMT_MZ:    FormatName := 'mz-dos (8086)';
  FMT_MACHO32: Begin
   If MachOCpuType = CPU_TYPE_X86 Then FormatName := 'mach-o-i386'
   Else If MachOCpuType = CPU_TYPE_ARM Then FormatName := 'mach-o-arm'
   Else FormatName := 'mach-o-32 (cputype 0x' + ToHexU(MachOCpuType) + ')';
  End;
  FMT_MACHO64: Begin
   If MachOCpuType = CPU_TYPE_X86_64 Then FormatName := 'mach-o-x86-64'
   Else If MachOCpuType = CPU_TYPE_ARM64 Then FormatName := 'mach-o-arm64'
   Else FormatName := 'mach-o-64 (cputype 0x' + ToHexU(MachOCpuType) + ')';
  End;
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
   PadRight(SecName, 10), ' ',
   Symbols[I].Name);
 End;
End;

{ @description: Implemente l option -d : desassemble toutes les
    sections de code (IsCode = vrai), avec une etiquette de symbole
    au debut de chaque fonction connue, comme "objdump -d". }
Procedure CmdDisasm;
Var
 SI: Integer;
 Off, VAddr, EndAddr: LongInt;
 InstrLen, K, AddrDigits: Integer;
 Mnemonic, Operands, BytesTxt, Lbl: String;
Begin
 If (Arch = ARCH_6502) Or (Arch = ARCH_8086) Or (Arch = ARCH_Z80) Or
    (Arch = ARCH_6800) Then
  AddrDigits := 4
 Else If (Arch = ARCH_X64) Or (Arch = ARCH_ARM64) Then AddrDigits := 16
 Else If (Arch = ARCH_ARM32) Or (Arch = ARCH_THUMB) Then AddrDigits := 8
 Else AddrDigits := 6;
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
    WriteLn(ToHexFixed(VAddr, AddrDigits), ' <', Lbl, '>:');
   End;
   If Arch = ARCH_6502 Then
    InstrLen := Disasm6502One(Off, VAddr, Mnemonic, Operands)
   Else If Arch = ARCH_8086 Then
    InstrLen := Disasm8086One(Off, VAddr, Mnemonic, Operands)
   Else If Arch = ARCH_X64 Then
    InstrLen := Disasm64One(Off, VAddr, Mnemonic, Operands)
   Else If Arch = ARCH_ARM64 Then
    InstrLen := DisasmArm64One(Off, VAddr, Mnemonic, Operands)
   Else If Arch = ARCH_ARM32 Then
    InstrLen := DisasmArm32One(Off, VAddr, Mnemonic, Operands)
   Else If Arch = ARCH_THUMB Then
    InstrLen := DisasmThumbOne(Off, VAddr, Mnemonic, Operands)
   Else If Arch = ARCH_Z80 Then
    InstrLen := DisasmZ80One(Off, VAddr, Mnemonic, Operands)
   Else If Arch = ARCH_6800 Then
    InstrLen := Disasm6800One(Off, VAddr, Mnemonic, Operands)
   Else
    InstrLen := DisasmOne(Off, VAddr, Mnemonic, Operands);
   BytesTxt := '';
   For K := 0 To InstrLen - 1 Do Begin
    If K > 0 Then BytesTxt := BytesTxt + ' ';
    BytesTxt := BytesTxt + HexByte(GetByte(Off + K));
   End;
   Write('  ', ToHexFixed(VAddr, AddrDigits), ':' + #9, PadRight(BytesTxt, 21), #9);
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

{ @description: Convertit une chaine hexadecimale (avec prefixe
    optionnel "0x" ou "$") en valeur numerique, pour l option -b. Une
    chaine invalide donne 0 plutot que de planter.
  @param S Chaine a convertir
  @return Valeur numerique correspondante }
Function HexStrToLong(S: String): LongInt;
Var
 V: LongInt;
 Code: Integer;
Begin
 If StartsWithStr(S, '0x') Or StartsWithStr(S, '0X') Then Delete(S, 1, 2)
 Else If StartsWithStr(S, '$') Then Delete(S, 1, 1);
 Val('$' + S, V, Code);
 If Code <> 0 Then V := 0;
 HexStrToLong := V;
End;

Procedure Help;Begin
 WriteLn('OBJDUMP - Cette commande permet d''analyser des fichiers objets, biblioth'+#138+'ques et ex'+#130+'cutables ',
         'afin d''afficher leurs ent'+#136+'tes, sections, symboles et code d'+#130+'sassembl'+#130+'.');
 WriteLn;
 WriteLn('Syntaxe : OBJDUMP fichier [options]');
 WriteLn('  fichier  Fichier binaire a analyser');
 WriteLn('  -d       Desassemble les sections de code');
 WriteLn('  -h       Affiche l''en-tete des sections');
 WriteLn('  -t       Affiche la table des symboles');
 WriteLn('  -S       Melange source/assembleur (non supporte)');
 WriteLn('  -m arch  Force l''architecture de desassemblage :');
 WriteLn('           i386 (defaut), x86-64, 8086, 6502, z80, 6800,');
 WriteLn('           arm, thumb ou arm64');
 WriteLn('  -b adr   Adresse de chargement (hexa) pour un binaire');
 WriteLn('           brut sans entete, ex: -b 8000 ou -b $8000');
 WriteLn('  -?       Aide sur cette commande');
 WriteLn;
 WriteLn('Formats supportes : ELF32/ELF64 (Linux), PE32/PE32+ (Windows),');
 WriteLn('Mach-O 32/64 bits (macOS, dont binaires universels "fat"),');
 WriteLn('EXE DOS reel (entete MZ), ROM NES (entete iNES), binaire');
 WriteLn('brut (avec -m). L''architecture est choisie automatiquement');
 WriteLn('a partir de e_machine (ELF), Machine (PE) ou cputype (Mach-O).');
 WriteLn('Desassemblage : x86 32 bits / x86-64 (syntaxe AT&T, comme');
 WriteLn('objdump) ; 8086/80186 16 bits (syntaxe Intel/MASM) ; 6502');
 WriteLn('complet (151 opcodes) ; Z80 (jeu de base complet, plus un');
 WriteLn('sous-ensemble pratique de CB/ED/DD/FD) ; Motorola 6800');
 WriteLn('(jeu d''instructions complet) ; ARM 32 bits classique,');
 WriteLn('Thumb/Thumb-2 (sous-ensemble) et AArch64 (sous-ensemble).');
 WriteLn('Pas de SSE/AVX/NEON/VFP, pas d''opcodes etendus 0F pour le');
 WriteLn('8086, pas de DDCB/FDCB pour le Z80.');
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
 Arch       := ARCH_X86;
 ArchForced := False;
 BaseAddr   := 0;

 If ParamCount < 1 Then Begin
  Help;
  Halt(1);
 End;

 I := 1;
 While I <= ParamCount Do Begin
  Arg := ParamStr(I);
  If (Arg = '-?') Or (UpStr(Arg) = '/?') Then Begin
   Help;
   Halt(0);
  End Else If Arg = '-d' Then OptDisasm := True
  Else If Arg = '-h' Then OptHeaders := True
  Else If Arg = '-t' Then OptSymbols := True
  Else If Arg = '-S' Then OptSource := True
  Else If Arg = '-m' Then Begin
   Inc(I);
   If I > ParamCount Then Begin
    WriteLn('Erreur : -m necessite une architecture (i386, x86-64, 8086, ',
     '6502, z80, 6800, arm, thumb ou arm64).');
    Halt(1);
   End;
   If UpStr(ParamStr(I)) = '6502' Then Arch := ARCH_6502
   Else If (UpStr(ParamStr(I)) = '8086') Or
           (UpStr(ParamStr(I)) = '80186') Then Arch := ARCH_8086
   Else If (UpStr(ParamStr(I)) = 'X64') Or
           (UpStr(ParamStr(I)) = 'X86-64') Or
           (UpStr(ParamStr(I)) = 'X86_64') Or
           (UpStr(ParamStr(I)) = 'AMD64') Then Arch := ARCH_X64
   Else If UpStr(ParamStr(I)) = 'I386' Then Arch := ARCH_X86
   Else If (UpStr(ParamStr(I)) = 'ARM64') Or
           (UpStr(ParamStr(I)) = 'AARCH64') Then Arch := ARCH_ARM64
   Else If (UpStr(ParamStr(I)) = 'ARM') Or
           (UpStr(ParamStr(I)) = 'ARM32') Then Arch := ARCH_ARM32
   Else If UpStr(ParamStr(I)) = 'THUMB' Then Arch := ARCH_THUMB
   Else If UpStr(ParamStr(I)) = 'Z80' Then Arch := ARCH_Z80
   Else If UpStr(ParamStr(I)) = '6800' Then Arch := ARCH_6800
   Else Begin
    WriteLn('Architecture inconnue pour -m : ', ParamStr(I));
    Halt(1);
   End;
   ArchForced := True;
  End Else If Arg = '-b' Then Begin
   Inc(I);
   If I > ParamCount Then Begin
    WriteLn('Erreur : -b necessite une adresse (ex: -b 8000).');
    Halt(1);
   End;
   BaseAddr := HexStrToLong(ParamStr(I));
  End Else If StartsWithStr(Arg, '-') Then Begin
   WriteLn('Option inconnue : ', Arg);
   Halt(1);
  End Else
   InFileName := Arg;
  Inc(I);
 End;

 If InFileName = '' Then Begin
  WriteLn('Erreur : aucun fichier specifie.');
  Halt(1);
 End;
 If (Not OptDisasm) And (Not OptHeaders) And (Not OptSymbols) And
    (Not OptSource) Then OptDisasm := True; { comportement par defaut }

 InitOpcodes6502;
 InitOpcodes6800;
 LoadFile(InFileName);
 DetectFormat;

 If BinFormat = FMT_NES Then Begin
  ParseNES;
  If Not ArchForced Then Arch := ARCH_6502; { detection automatique }
 End Else If BinFormat = FMT_MZ Then Begin
  ParseMZ;
  If Not ArchForced Then Arch := ARCH_8086; { detection automatique }
 End Else If (BinFormat = FMT_ELF32) Or (BinFormat = FMT_ELF64) Then Begin
  ParseELF;
  If Not ArchForced Then Begin
   If ElfMachine = EM_AARCH64 Then Arch := ARCH_ARM64
   Else If ElfMachine = EM_ARM Then Arch := ARCH_ARM32
   Else If BinFormat = FMT_ELF64 Then Arch := ARCH_X64;
   { ELF32 sans e_machine ARM reconnu : on laisse ARCH_X86 par defaut,
     comme avant la prise en charge d e_machine. }
  End;
 End Else If (BinFormat = FMT_PE32) Or (BinFormat = FMT_PE64) Then Begin
  ParsePE;
  If Not ArchForced Then Begin
   If PEMachine = PE_MACHINE_ARM64 Then Arch := ARCH_ARM64
   Else If PEMachine = PE_MACHINE_ARMNT Then Arch := ARCH_THUMB
   Else If PEMachine = PE_MACHINE_ARM Then Arch := ARCH_ARM32
   Else If BinFormat = FMT_PE64 Then Arch := ARCH_X64;
  End;
 End Else If (BinFormat = FMT_MACHO32) Or (BinFormat = FMT_MACHO64) Then Begin
  ParseMachO;
  If Not ArchForced Then Begin
   If MachOCpuType = CPU_TYPE_X86_64 Then Arch := ARCH_X64
   Else If MachOCpuType = CPU_TYPE_X86 Then Arch := ARCH_X86
   Else If MachOCpuType = CPU_TYPE_ARM64 Then Arch := ARCH_ARM64
   Else If MachOCpuType = CPU_TYPE_ARM Then Arch := ARCH_ARM32
   Else If OptDisasm Then
    WriteLn('Avertissement : architecture Mach-O (cputype 0x',
     ToHexU(MachOCpuType), ') non prise en charge par le ',
     'desassembleur ; -h/-t restent fiables, -d sera incorrect ',
     'sans -m explicite.');
  End;
 End Else If ArchForced Then Begin
  { Format non reconnu, mais architecture explicitement choisie via
    -m : on traite le fichier comme un binaire brut, sans entete. }
  BinFormat := FMT_RAW;
  ParseRaw;
 End Else Begin
  WriteLn('Erreur : format de fichier non reconnu (ni ELF, ni PE, ni ROM NES, ni EXE DOS, ni Mach-O).');
  WriteLn('Pour un binaire brut, precisez l''architecture avec -m (ex: -m 6502).');
  Halt(1);
 End;

 If OptHeaders Then CmdHeaders;
 If OptSymbols Then CmdSymbols;
 If OptSource Then CmdSourceMix;
 If OptDisasm Then CmdDisasm;
End.
