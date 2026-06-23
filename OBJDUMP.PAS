{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Clone partiel de l outil GNU "objdump", couvrant les
    formats binaires ELF32/ELF64 (Linux), PE32/PE32+ (Windows), EXE
    DOS reel (MZ) et ROM NES (iNES), avec desassemblage x86 32 bits,
    x86-64, 8086/80186, 6502, Z80, Motorola 6800 et Motorola 68000
    pour les instructions courantes.

    Portee assumee (voir discussion avec l utilisateur) :
    - Formats : ELF et PE (32 et 64 bits), EXE DOS MZ, ROM NES,
      fichier objet COFF brut (.o/.obj), bibliotheque statique "ar"
      (.a, traitee membre par membre), et binaire brut (avec -m/-b).
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
 MaxSections = 4096;      { nombre maximal de sections gerees (les .o
                             FPC en "smart-linking" ont une section par
                             routine : plusieurs centaines, voire plus) }
 MaxSymbols  = 16384;     { nombre maximal de symboles geres }
 MaxArchiveMembers = 2048; { nombre maximal de membres geres dans un .a }

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
 FMT_CLASS   = 10;       { fichier Java .class (bytecode JVM/Jasmin)   }
 FMT_LLVMBC  = 11;       { LLVM IR bitcode (brut ou wrapper)           }
 FMT_COFFOBJ = 12;       { fichier objet COFF brut (.o/.obj), sans MZ/PE}
 FMT_ARCHIVE = 13;       { bibliotheque statique "ar" (.a), entete     }
                          { "!<arch>\n" : traite par membre (-h/-t/-d) }

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
 ARCH_68000 = 9;         { Motorola 68000 16/32 bits (voir Disasm68kOne)}
 ARCH_8080  = 10;        { Intel 8080 8 bits (voir Disasm8080One)      }
 ARCH_SPARC = 11;        { SPARC V8/V9 (voir DisasmSparcOne)           }
 ARCH_MIPS  = 12;        { MIPS gros-boutiste (MIPS I/II/MIPS32)       }
 ARCH_MIPSEL = 13;       { MIPS little-endian                          }
 ARCH_PPC   = 14;        { PowerPC gros-boutiste                       }
 ARCH_PPCLE = 15;        { PowerPC little-endian                       }
 ARCH_SH    = 16;        { SuperH gros-boutiste                        }
 ARCH_SHLE  = 17;        { SuperH little-endian                        }
 ARCH_IA64  = 18;        { Intel Itanium IA-64 little-endian           }
 ARCH_IA64BE = 19;       { Intel Itanium IA-64 big-endian              }
 ARCH_PCODE = 20;        { p-Code UCSD p-System II.0/II.1              }
 ARCH_MSIL  = 21;        { Microsoft Intermediate Language / CIL       }
 ARCH_JVM   = 22;        { bytecode JVM / assembleur Jasmin            }
 ARCH_LLVM  = 23;        { LLVM IR bitcode structurel                  }

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
 EM_68K       = 4;         { Motorola 68000 (e_machine ELF)              }
 EM_SPARC     = 2;         { SPARC V8                                    }
 EM_SPARC32PLUS = 18;      { SPARC V8+                                   }
 EM_SPARCV9   = 43;        { SPARC V9 64 bits                            }
 EM_MIPS      = 8;         { MIPS I/II/III/IV, MIPS32 et MIPS64          }
 EM_PPC       = 20;        { PowerPC 32 bits                             }
 EM_PPC64     = 21;        { PowerPC 64 bits                             }
 EM_SH        = 42;        { Hitachi/Renesas SuperH                      }
 EM_IA_64     = 50;        { Intel Itanium IA-64                         }
 PE_MACHINE_ARM   = $01C0;
 PE_MACHINE_ARMNT = $01C4;  { Thumb-2 (ARMv7 et plus, convention Windows) }
 PE_MACHINE_ARM64 = $AA64;
 CPU_TYPE_ARM     = $0000000C;
 CPU_TYPE_ARM64   : LongInt = LongInt($0100000C);
 CPU_TYPE_MC680x0 = $00000006; { Motorola 68000 (cputype Mach-O)         }

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

 TJavaCPRec = Record
  Tag: Byte;
  Ref1, Ref2: Word;
  StrOff: LongInt;
  StrLen: Word;
 End;
 TJavaCPArray = Array[0..4095] Of TJavaCPRec;
 PJavaCPArray = ^TJavaCPArray;

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

 { Un membre d une bibliotheque "ar" (.a) : nom resolu (table des
   noms longs GNU deja appliquee) et plage d octets dans le fichier
   archive, traitee ensuite comme un mini-fichier independant. }
 TArchiveMember = Record
  Name     : String[200];
  DataOff  : LongInt;
  DataSize : LongInt;
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
 ArchiveMembers     : Array[1..MaxArchiveMembers] Of TArchiveMember;
 ArchiveMemberCount : Integer;
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
 ElfBigEndian : Boolean;          { EI_DATA = ELFDATA2MSB                 }
 PEMachine    : LongInt;          { Machine du IMAGE_FILE_HEADER PE, idem }
 Mnem6502     : Array[0..255] Of String[4];
 Mode6502     : Array[0..255] Of Byte;
 Mnem6800     : Array[0..255] Of String[4];
 Mode6800     : Array[0..255] Of Byte;
 JavaCP       : PJavaCPArray;
 JavaCPCount  : Word;

Const
 LLVM_MAX_ABBREVS = 32;
 LLVM_MAX_ABBREV_OPS = 32;

Type
 TLLVMAbbrevOp = Record
  IsLiteral: Boolean;
  Encoding: Byte;
  Value: LongInt;
 End;
 TLLVMAbbrev = Record
  Count: Integer;
  Ops: Array[0..LLVM_MAX_ABBREV_OPS - 1] Of TLLVMAbbrevOp;
 End;
 TLLVMAbbrevList = Record
  Count: Integer;
  Items: Array[0..LLVM_MAX_ABBREVS - 1] Of TLLVMAbbrev;
 End;
 PLLVMAbbrevList = ^TLLVMAbbrevList;

Var
 LLVMBitPos: LongInt;
 LLVMBlockInfo: Array[0..63] Of PLLVMAbbrevList;

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

{ @description: Lit un mot ELF selon l ordre des octets indique par
    EI_DATA dans l entete ELF. }
Function GetElfWord(Off: LongInt): Word;
Begin
 If ElfBigEndian Then GetElfWord := GetWordBE(Off)
 Else GetElfWord := GetWord(Off);
End;

{ @description: Lit un double mot ELF selon EI_DATA. }
Function GetElfDWord(Off: LongInt): LongInt;
Begin
 If ElfBigEndian Then GetElfDWord := GetDWordBE(Off)
 Else GetElfDWord := GetDWord(Off);
End;

{ @description: Retourne les 32 bits bas d un champ ELF64. }
Function GetElfQWordLow(Off: LongInt): LongInt;
Begin
 If ElfBigEndian Then GetElfQWordLow := GetDWordBE(Off + 4)
 Else GetElfQWordLow := GetDWord(Off);
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
  If GetByte(4) = 2 Then BinFormat := FMT_ELF64
  Else BinFormat := FMT_ELF32;
  Exit;
 End;
 If (GetDWordBE(0) = FAT_MAGIC) And (BufSize >= 10) And
    (GetWordBE(6) >= 45) And (GetWordBE(8) > 0) Then Begin
  { CAFEBABE est aussi le magic Mach-O fat. Une version JVM >=45 et
    un constant_pool_count non nul identifient un fichier .class. }
  BinFormat := FMT_CLASS;
  Exit;
 End;
 If (GetByte(0) = Ord('B')) And (GetByte(1) = Ord('C')) And
    (GetByte(2) = $C0) And (GetByte(3) = $DE) Then Begin
  BinFormat := FMT_LLVMBC;
  Exit;
 End;
 If GetDWord(0) = $0B17C0DE Then Begin
  BinFormat := FMT_LLVMBC; { wrapper bitcode LLVM }
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
 { Fichier objet COFF brut (.o/.obj) : aucune signature propre (a la
   difference de MZ/ELF/Mach-O), mais l entete IMAGE_FILE_HEADER (20
   octets) a une forme reconnaissable : Machine parmi un jeu connu,
   et surtout SizeOfOptionalHeader nul (un fichier objet n a jamais
   d en-tete optionnel, a la difference d un PE). Heuristique testee
   contre des .o reels produits par cette chaine FPC. }
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
 ElfBigEndian := GetByte(5) = 2; { ELFDATA2MSB }
 ElfMachine := GetElfWord(18); { e_machine, meme decalage en 32 et 64 bits }
 EntryPoint := 0;
 ImageBase := 0;
 If Is64 Then Begin
  EntryPoint := GetElfQWordLow(24);
  ShOff      := GetElfQWordLow(40);
  ShEntSize  := GetElfWord(58);
  ShNum      := GetElfWord(60);
  ShStrNdx   := GetElfWord(62);
 End Else Begin
  EntryPoint := GetElfDWord(24);
  ShOff      := GetElfDWord(32);
  ShEntSize  := GetElfWord(46);
  ShNum      := GetElfWord(48);
  ShStrNdx   := GetElfWord(50);
 End;
 If (ShOff <= 0) Or (ShNum <= 0) Or (ShNum > MaxSections) Then Exit;
 { Localiser la table de noms de sections (.shstrtab) }
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
   Sections[SectionCount].Name    := GetCStr(StrTabOff + NameOff, 31);
   Sections[SectionCount].VAddr   := GetElfQWordLow(Base + 16);
   Sections[SectionCount].FileOff := GetElfQWordLow(Base + 24);
   Sections[SectionCount].Size    := GetElfQWordLow(Base + 32);
   Sections[SectionCount].IsCode  := (GetElfDWord(Base + 4) = 1) And
    ((GetElfQWordLow(Base + 8) And 4) <> 0); { SHT_PROGBITS + SHF_EXECINSTR }
   If GetElfDWord(Base + 4) = 2 Then Begin { SHT_SYMTAB }
    SymTabOff  := GetElfQWordLow(Base + 24);
    SymTabSize := GetElfQWordLow(Base + 32);
    SymEntSize := GetElfQWordLow(Base + 56);
    SymStrOff  := GetElfQWordLow(ShOff + GetElfDWord(Base + 40) * ShEntSize + 24);
    FoundSymTab := True;
   End;
  End Else Begin
   NameOff := GetElfDWord(Base);
   Sections[SectionCount].Name    := GetCStr(StrTabOff + NameOff, 31);
   Sections[SectionCount].VAddr   := GetElfDWord(Base + 12);
   Sections[SectionCount].FileOff := GetElfDWord(Base + 16);
   Sections[SectionCount].Size    := GetElfDWord(Base + 20);
   Sections[SectionCount].IsCode  := (GetElfDWord(Base + 4) = 1) And
    ((GetElfDWord(Base + 8) And 4) <> 0);
   If GetElfDWord(Base + 4) = 2 Then Begin { SHT_SYMTAB }
    SymTabOff  := GetElfDWord(Base + 16);
    SymTabSize := GetElfDWord(Base + 20);
    SymEntSize := GetElfDWord(Base + 36);
    SymStrOff  := GetElfDWord(ShOff + GetElfDWord(Base + 28) * ShEntSize + 16);
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
    NameOff := GetElfDWord(Base);
    Info    := GetByte(Base + 4);
    Value   := GetElfQWordLow(Base + 8);
    SecIdx  := GetElfWord(Base + 6);
   End Else Begin
    NameOff := GetElfDWord(Base);
    Value   := GetElfDWord(Base + 4);
    Info    := GetByte(Base + 12);
    SecIdx  := GetElfWord(Base + 14);
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
    Symbols[SymbolCount].Name   := SName;
    Symbols[SymbolCount].Value  := ImageBase + GetDWord(Base + 8);
    Symbols[SymbolCount].SecIdx := GetWord(Base + 12);
    Symbols[SymbolCount].IsFunc := True; { COFF ne distingue pas finement ici }
   End;
   { Entrees auxiliaires : voir le commentaire equivalent dans
     ParseCoffObj. }
   I := I + 1 + GetByte(Base + 17);
  End;
 End;
End;

{ ============================================================
  ANALYSE D UN FICHIER OBJET COFF BRUT (.o/.obj, sans MZ/PE)
  ============================================================
  Identique a un PE du point de vue de l entete COFF et de la table
  de symboles (memes structures, voir ParsePE), mais sans enveloppe
  MZ/PE ni en-tete optionnel : l entete IMAGE_FILE_HEADER (20
  octets) est directement au debut du fichier, et SizeOfOptionalHeader
  y est habituellement nul. Pas d ImageBase (fichier non relogeable
  : les adresses de section restent celles, generalement nulles,
  ecrites par le compilateur/assembleur). Valide contre des .o reels
  produits par cette meme chaine FPC (ex: COMMENT.o, 1177 sections
  en "smart linking"). }
Procedure ParseCoffObj;
Var
 SecOff: LongInt;
 NumSections, SizeOptHdr: Integer;
 I, J: Integer;
 Base: LongInt;
 RawName: String;
 SymTabOff, NumSyms, StrTabOff: LongInt;
 SName: String;
 ZeroLead: Boolean;
 StrOffInTab: LongInt;
 NameIdx: LongInt;
 Code: Integer;
Begin
 PEMachine   := GetWord(0);
 NumSections := GetWord(2);
 SymTabOff   := GetDWord(8);
 NumSyms     := GetDWord(12);
 SizeOptHdr  := GetWord(16);
 ImageBase   := 0;
 EntryPoint  := 0;
 SecOff := 20 + SizeOptHdr;
 { La table de chaines COFF (noms de section/symbole de plus de 8
   caracteres, references par "/N") suit immediatement la table des
   symboles ; ses 4 premiers octets sont sa propre taille totale, et
   les chaines elles-memes (terminees par un octet nul) commencent
   donc a son decalage de base + l index N lu dans le champ. }
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
  Sections[SectionCount].Name    := RawName;
  Sections[SectionCount].VAddr   := GetDWord(Base + 12);
  Sections[SectionCount].FileOff := GetDWord(Base + 20);
  Sections[SectionCount].Size    := GetDWord(Base + 16); { SizeOfRawData :
   VirtualSize (Base+8) vaut generalement 0 dans un objet non reloge }
  Sections[SectionCount].IsCode  := (GetDWord(Base + 36) And $20000000) <> 0;
 End;
 SymbolCount := 0;
 If (SymTabOff > 0) And (NumSyms > 0) Then Begin
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
    Symbols[SymbolCount].Name   := SName;
    Symbols[SymbolCount].Value  := GetDWord(Base + 8);
    Symbols[SymbolCount].SecIdx := GetWord(Base + 12);
    Symbols[SymbolCount].IsFunc := True;
   End;
   { Les entrees auxiliaires (ex: nom de fichier complet apres un
     symbole ".file", informations de section apres un symbole de
     section) suivent immediatement le symbole principal et ne sont
     pas des symboles a part : NumberOfAuxSymbols (octet 17) indique
     combien d entrees de 18 octets supplementaires sauter. }
   I := I + 1 + GetByte(Base + 17);
  End;
 End;
End;

{ ============================================================
  ANALYSE D UNE BIBLIOTHEQUE STATIQUE "ar" (.a)
  ============================================================
  Format "ar" classique (entete "!<arch>\n" puis une suite de
  membres) : chaque membre a un en-tete de 60 octets en ASCII
  (nom/date/uid/gid/mode/taille/marqueur "`\n"), suivi des octets du
  membre, complete par un octet de bourrage "\n" si la taille est
  impaire. Le nom est tronque a 16 caracteres dans l en-tete ; deux
  conventions courantes l etendent : un "/" final (BSD/Microsoft,
  simple marqueur de fin de nom court) ou "/N" (GNU, ou N est un
  decalage ASCII dans le membre special "//" qui liste les noms
  longs). Les membres speciaux "/" (table des symboles) et "//"
  (table des noms longs) ne sont pas exposes comme membres normaux.
  Valide contre BINLINUX/libimpDEVENV.a, une bibliotheque reelle
  presente dans ce depot. }

{ @description: Lit une chaine dans la table des noms longs ("//"),
    ou chaque entree est terminee par "/\n" (et non par un octet
    nul, a la difference de GetCStr).
  @param Off Decalage (0-based) du debut de la chaine
  @param MaxLen Longueur maximale de securite
  @return Chaine lue, sans le "/" terminal }
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

{ @description: Remplit ArchiveMembers[] a partir d un fichier .a
    deja charge, en resolvant les noms longs GNU ("/N") via le
    membre "//" et en ignorant les membres speciaux ("/" et "//"
    eux-memes).}
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
 Off := 8; { taille de la signature "!<arch>\n" }
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
  Else If Name = '/' Then
   { table des symboles : ignoree, non necessaire par membre }
  Else Begin
   If (Length(Name) > 0) And (Name[1] = '/') Then Begin
    Val(Copy(Name, 2, Length(Name) - 1), NameIdx, Code);
    If (Code = 0) And (LongNamesOff >= 0) Then
     Name := GetArName(LongNamesOff + NameIdx, 200);
   End Else If (Length(Name) > 0) And (Name[Length(Name)] = '/') Then
    Name := Copy(Name, 1, Length(Name) - 1); { terminateur court BSD/MS }
   If ArchiveMemberCount < MaxArchiveMembers Then Begin
    Inc(ArchiveMemberCount);
    ArchiveMembers[ArchiveMemberCount].Name := Name;
    ArchiveMembers[ArchiveMemberCount].DataOff := Off + 60;
    ArchiveMembers[ArchiveMemberCount].DataSize := Sz;
   End;
  End;
  Off := Off + 60 + Sz;
  If (Sz Mod 2) = 1 Then Inc(Off); { octet de bourrage }
 End;
End;

{ ============================================================
  ANALYSE CLI/.NET : COR20 + METADONNEES METHODDEF
  ============================================================ }

{ @description: Convertit une RVA PE en decalage fichier. }
Function PERvaToFile(RVA: LongInt): LongInt;
Var
 I: Integer;
 Rel: LongInt;
Begin
 PERvaToFile := -1;
 For I := 1 To SectionCount Do Begin
  Rel := RVA - (Sections[I].VAddr - ImageBase);
  If (Rel >= 0) And (Rel < Sections[I].Size) Then Begin
   PERvaToFile := Sections[I].FileOff + Rel;
   Exit;
  End;
 End;
End;

Function MetaIndexSize(RowCount: LongInt): Integer;
Begin
 If RowCount < 65536 Then MetaIndexSize := 2 Else MetaIndexSize := 4;
End;

Function MetaCodedSize(A, B, C, D: LongInt; TagBits: Integer): Integer;
Var
 M, Limit: LongInt;
Begin
 M := A; If B > M Then M := B; If C > M Then M := C; If D > M Then M := D;
 Limit := LongInt(1) Shl (16 - TagBits);
 If M < Limit Then MetaCodedSize := 2 Else MetaCodedSize := 4;
End;

{ @description: Extrait les corps de methodes MSIL d un PE manage.
    Retourne vrai si un en-tete CLI et une table MethodDef valides ont
    ete trouves. Sections[] devient alors une liste de methodes IL. }
Function ParseMSILPE: Boolean;
Var
 PEOff, OptOff, DataDirOff, CliRva, CliOff, MetaRva, MetaOff: LongInt;
 VersionLen, P, Streams, I, J, TablesOff, RowsOff, DataOff: LongInt;
 StreamOff, StreamSize: LongInt;
 StreamName: String;
 HeapSizes: Byte;
 ValidLo, ValidHi: LongInt;
 Rows: Array[0..63] Of LongInt;
 StrSize, GuidSize, BlobSize: Integer;
 ModuleSize, TypeRefSize, TypeDefSize, FieldPtrSize, FieldSize: LongInt;
 MethodPtrSize, MethodRowSize, MethodOff, MethodRva, BodyOff: LongInt;
 CodeOff, CodeSize, HeaderSize: LongInt;
 FlagsSize: Word;
 NameIdx: LongInt;
 MethodName: String;
 StringHeapOff: LongInt;
 OldSections: Array[1..MaxSections] Of TSection;
 OldCount, Sec: Integer;

 Function ReadIndex(At: LongInt; Sz: Integer): LongInt;
 Begin
  If Sz = 2 Then ReadIndex := GetWord(At) Else ReadIndex := GetDWord(At);
 End;

 Function TablePresent(T: Integer): Boolean;
 Begin
  If T < 32 Then TablePresent := (ValidLo And (LongInt(1) Shl T)) <> 0
  Else TablePresent := (ValidHi And (LongInt(1) Shl (T - 32))) <> 0;
 End;

Begin
 ParseMSILPE := False;
 OldCount := SectionCount;
 For I := 1 To OldCount Do OldSections[I] := Sections[I];
 PEOff := GetDWord($3C);
 OptOff := PEOff + 24;
 If GetWord(OptOff) = $20B Then DataDirOff := OptOff + 112
 Else DataDirOff := OptOff + 96;
 CliRva := GetDWord(DataDirOff + 14 * 8);
 If CliRva = 0 Then Exit;
 CliOff := PERvaToFile(CliRva);
 If CliOff < 0 Then Exit;
 MetaRva := GetDWord(CliOff + 8);
 MetaOff := PERvaToFile(MetaRva);
 If (MetaOff < 0) Or (GetDWord(MetaOff) <> $424A5342) Then Exit; { BSJB }

 VersionLen := GetDWord(MetaOff + 12);
 P := MetaOff + 16 + VersionLen;
 P := (P + 3) And Not 3;
 Streams := GetWord(P + 2);
 P := P + 4;
 TablesOff := -1;
 StringHeapOff := -1;
 For I := 0 To Streams - 1 Do Begin
  StreamOff := GetDWord(P);
  StreamSize := GetDWord(P + 4);
  StreamName := '';
  J := 0;
  While (J < 32) And (GetByte(P + 8 + J) <> 0) Do Begin
   StreamName := StreamName + Chr(GetByte(P + 8 + J));
   Inc(J);
  End;
  If (StreamName = '#~') Or (StreamName = '#-') Then TablesOff := MetaOff + StreamOff;
  If StreamName = '#Strings' Then StringHeapOff := MetaOff + StreamOff;
  J := J + 1;
  While (J And 3) <> 0 Do Inc(J);
  P := P + 8 + J;
  If StreamSize < 0 Then Exit;
 End;
 If (TablesOff < 0) Or (StringHeapOff < 0) Then Exit;

 HeapSizes := GetByte(TablesOff + 6);
 If (HeapSizes And 1) <> 0 Then StrSize := 4 Else StrSize := 2;
 If (HeapSizes And 2) <> 0 Then GuidSize := 4 Else GuidSize := 2;
 If (HeapSizes And 4) <> 0 Then BlobSize := 4 Else BlobSize := 2;
 ValidLo := GetDWord(TablesOff + 8);
 ValidHi := GetDWord(TablesOff + 12);
 FillChar(Rows, SizeOf(Rows), 0);
 RowsOff := TablesOff + 24;
 For I := 0 To 63 Do
  If TablePresent(I) Then Begin
   Rows[I] := GetDWord(RowsOff);
   RowsOff := RowsOff + 4;
  End;
 If Not TablePresent(6) Then Exit;

 ModuleSize := 2 + StrSize + GuidSize * 3;
 TypeRefSize := MetaCodedSize(Rows[0], Rows[1], Rows[26], Rows[35], 2) +
  StrSize * 2;
 TypeDefSize := 4 + StrSize * 2 +
  MetaCodedSize(Rows[2], Rows[1], Rows[27], 0, 2) +
  MetaIndexSize(Rows[4]) + MetaIndexSize(Rows[6]);
 FieldPtrSize := MetaIndexSize(Rows[4]);
 FieldSize := 2 + StrSize + BlobSize;
 MethodPtrSize := MetaIndexSize(Rows[6]);
 MethodRowSize := 8 + StrSize + BlobSize + MetaIndexSize(Rows[8]);
 DataOff := RowsOff;
 If TablePresent(0) Then DataOff := DataOff + Rows[0] * ModuleSize;
 If TablePresent(1) Then DataOff := DataOff + Rows[1] * TypeRefSize;
 If TablePresent(2) Then DataOff := DataOff + Rows[2] * TypeDefSize;
 If TablePresent(3) Then DataOff := DataOff + Rows[3] * FieldPtrSize;
 If TablePresent(4) Then DataOff := DataOff + Rows[4] * FieldSize;
 If TablePresent(5) Then DataOff := DataOff + Rows[5] * MethodPtrSize;

 SectionCount := 0;
 For I := 0 To Rows[6] - 1 Do Begin
  MethodOff := DataOff + I * MethodRowSize;
  MethodRva := GetDWord(MethodOff);
  If MethodRva = 0 Then Continue;
  NameIdx := ReadIndex(MethodOff + 8, StrSize);
  MethodName := GetCStr(StringHeapOff + NameIdx, 31);
  BodyOff := -1;
  For Sec := 1 To OldCount Do Begin
   J := MethodRva - (OldSections[Sec].VAddr - ImageBase);
   If (J >= 0) And (J < OldSections[Sec].Size) Then
    BodyOff := OldSections[Sec].FileOff + J;
  End;
  If BodyOff < 0 Then Continue;
  If (GetByte(BodyOff) And 3) = 2 Then Begin { tiny header }
   HeaderSize := 1;
   CodeSize := GetByte(BodyOff) Shr 2;
  End Else If (GetByte(BodyOff) And 3) = 3 Then Begin { fat header }
   FlagsSize := GetWord(BodyOff);
   HeaderSize := ((FlagsSize Shr 12) And 15) * 4;
   CodeSize := GetDWord(BodyOff + 4);
  End Else Continue;
  CodeOff := BodyOff + HeaderSize;
  If (CodeSize <= 0) Or (CodeOff + CodeSize > BufSize) Then Continue;
  If SectionCount >= MaxSections Then Break;
  Inc(SectionCount);
  If MethodName = '' Then MethodName := 'method_' + IntToStr(I + 1);
  Sections[SectionCount].Name := MethodName;
  Sections[SectionCount].FileOff := CodeOff;
  Sections[SectionCount].VAddr := MethodRva + HeaderSize;
  Sections[SectionCount].Size := CodeSize;
  Sections[SectionCount].IsCode := True;
 End;
 If SectionCount = 0 Then Begin
  SectionCount := OldCount;
  For I := 1 To OldCount Do Sections[I] := OldSections[I];
  Exit;
 End;
 EntryPoint := Sections[1].VAddr;
 SymbolCount := 0;
 ParseMSILPE := True;
End;

{ ============================================================
  ANALYSE D UN FICHIER JAVA .CLASS / JASMIN
  ============================================================ }

Function JavaCPUtf8(Index: Word): String;
Var
 I, N: Integer;
 S: String;
Begin
 JavaCPUtf8 := '';
 If (JavaCP = Nil) Or (Index = 0) Or (Index >= JavaCPCount) Then Exit;
 If JavaCP^[Index].Tag <> 1 Then Exit;
 N := JavaCP^[Index].StrLen;
 If N > 255 Then N := 255;
 S := '';
 For I := 0 To N - 1 Do S := S + Chr(GetByte(JavaCP^[Index].StrOff + I));
 JavaCPUtf8 := S;
End;

Function JavaCPDescription(Index: Word): String;
Var
 N, D: String;
 R: Word;
Begin
 JavaCPDescription := '#' + IntToStr(Index);
 If (JavaCP = Nil) Or (Index = 0) Or (Index >= JavaCPCount) Then Exit;
 Case JavaCP^[Index].Tag Of
  1: JavaCPDescription := JavaCPUtf8(Index);
  7, 8, 16, 19, 20: JavaCPDescription := JavaCPUtf8(JavaCP^[Index].Ref1);
  12: Begin
   N := JavaCPUtf8(JavaCP^[Index].Ref1);
   D := JavaCPUtf8(JavaCP^[Index].Ref2);
   JavaCPDescription := N + D;
  End;
  9, 10, 11: Begin
   R := JavaCP^[Index].Ref1;
   If (R > 0) And (R < JavaCPCount) Then
    N := JavaCPUtf8(JavaCP^[R].Ref1) Else N := '';
   R := JavaCP^[Index].Ref2;
   If (R > 0) And (R < JavaCPCount) Then
    D := JavaCPUtf8(JavaCP^[R].Ref1) + JavaCPUtf8(JavaCP^[R].Ref2)
   Else D := '';
   If N <> '' Then JavaCPDescription := N + '.' + D Else JavaCPDescription := D;
  End;
 End;
End;

Procedure JavaSkipAttributes(Var P: LongInt; Count: Word);
Var
 I: Integer;
 L: LongInt;
Begin
 For I := 1 To Count Do Begin
  L := GetDWordBE(P + 2);
  P := P + 6 + L;
 End;
End;

{ @description: Analyse le constant pool et les attributs Code d un
    fichier .class. Chaque methode concrete devient une section de
    bytecode, avec une adresse locale commencant a zero. }
Procedure ParseJavaClass;
Var
 P, L, CodeLen, CodeOff: LongInt;
 CPCount, I, AttrCount, FieldCount, MethodCount, IfaceCount: Word;
 Tag: Byte;
 NameIdx, DescIdx, AttrNameIdx: Word;
 Name, Desc, AttrName: String;
 J: Integer;
Begin
 SectionCount := 0;
 SymbolCount := 0;
 EntryPoint := 0;
 ImageBase := 0;
 If JavaCP <> Nil Then Begin
  FreeMem(JavaCP, SizeOf(TJavaCPArray));
  JavaCP := Nil;
 End;
 CPCount := GetWordBE(8);
 If (CPCount < 1) Or (CPCount > 4096) Then Exit;
 GetMem(JavaCP, SizeOf(TJavaCPArray));
 FillChar(JavaCP^, SizeOf(TJavaCPArray), 0);
 JavaCPCount := CPCount;
 P := 10;
 I := 1;
 While I < CPCount Do Begin
  Tag := GetByte(P); Inc(P);
  JavaCP^[I].Tag := Tag;
  Case Tag Of
   1: Begin
    JavaCP^[I].StrLen := GetWordBE(P); Inc(P, 2);
    JavaCP^[I].StrOff := P;
    P := P + JavaCP^[I].StrLen;
   End;
   3, 4: Inc(P, 4);
   5, 6: Begin Inc(P, 8); Inc(I); End;
   7, 8, 16, 19, 20: Begin JavaCP^[I].Ref1 := GetWordBE(P); Inc(P, 2); End;
   9, 10, 11, 12, 17, 18: Begin
    JavaCP^[I].Ref1 := GetWordBE(P);
    JavaCP^[I].Ref2 := GetWordBE(P + 2);
    Inc(P, 4);
   End;
   15: Begin
    JavaCP^[I].Ref1 := GetWordBE(P + 1);
    Inc(P, 3);
   End;
  Else
   Exit;
  End;
  Inc(I);
 End;

 Inc(P, 6); { access_flags, this_class, super_class }
 IfaceCount := GetWordBE(P); Inc(P, 2 + IfaceCount * 2);
 FieldCount := GetWordBE(P); Inc(P, 2);
 For I := 1 To FieldCount Do Begin
  AttrCount := GetWordBE(P + 6);
  Inc(P, 8);
  JavaSkipAttributes(P, AttrCount);
 End;
 MethodCount := GetWordBE(P); Inc(P, 2);
 For I := 1 To MethodCount Do Begin
  NameIdx := GetWordBE(P + 2);
  DescIdx := GetWordBE(P + 4);
  AttrCount := GetWordBE(P + 6);
  Name := JavaCPUtf8(NameIdx);
  Desc := JavaCPUtf8(DescIdx);
  Inc(P, 8);
  For J := 1 To AttrCount Do Begin
   AttrNameIdx := GetWordBE(P);
   L := GetDWordBE(P + 2);
   AttrName := JavaCPUtf8(AttrNameIdx);
   If (AttrName = 'Code') And (L >= 12) Then Begin
    CodeLen := GetDWordBE(P + 10);
    CodeOff := P + 14;
    If (CodeLen > 0) And (CodeOff + CodeLen <= BufSize) And
       (SectionCount < MaxSections) Then Begin
     Inc(SectionCount);
     If Name = '' Then Name := 'method_' + IntToStr(I);
     Sections[SectionCount].Name := Copy(Name + Desc, 1, 32);
     Sections[SectionCount].FileOff := CodeOff;
     Sections[SectionCount].VAddr := 0;
     Sections[SectionCount].Size := CodeLen;
     Sections[SectionCount].IsCode := True;
    End;
   End;
   P := P + 6 + L;
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
  DESASSEMBLEUR INTEL 8080
  ============================================================ }

{ @description: Desassemble une instruction Intel 8080 avec les
    mnemoniques et operandes Intel d origine. Le jeu documente complet
    est pris en charge ; les opcodes non documentes du 8080 produisent
    "(bad)" et occupent un octet. Cette separation avec le decodeur Z80
    evite d afficher LD/JR/IX/IY ou les prefixes CB/DD/ED/FD pour un
    binaire strictement 8080.
  @param Off Decalage de l instruction dans le fichier
  @param VAddrBase Adresse virtuelle correspondant a Off
  @param Mnemonic Mnemonique de l instruction (sortie)
  @param Operands Operandes formates (sortie)
  @return Nombre d octets occupes par l instruction (1, 2 ou 3) }
Function Disasm8080One(Off, VAddrBase: LongInt;
 Var Mnemonic, Operands: String): Integer;
Const
 Reg8080: Array[0..7] Of String[1] = (
  'B', 'C', 'D', 'E', 'H', 'L', 'M', 'A');
 Pair8080: Array[0..3] Of String[2] = ('B', 'D', 'H', 'SP');
 PairPush8080: Array[0..3] Of String[3] = ('B', 'D', 'H', 'PSW');
 Alu8080: Array[0..7] Of String[3] = (
  'ADD', 'ADC', 'SUB', 'SBB', 'ANA', 'XRA', 'ORA', 'CMP');
 ImmAlu8080: Array[0..7] Of String[3] = (
  'ADI', 'ACI', 'SUI', 'SBI', 'ANI', 'XRI', 'ORI', 'CPI');
 Ret8080: Array[0..7] Of String[3] = (
  'RNZ', 'RZ', 'RNC', 'RC', 'RPO', 'RPE', 'RP', 'RM');
 Jump8080: Array[0..7] Of String[3] = (
  'JNZ', 'JZ', 'JNC', 'JC', 'JPO', 'JPE', 'JP', 'JM');
 Call8080: Array[0..7] Of String[3] = (
  'CNZ', 'CZ', 'CNC', 'CC', 'CPO', 'CPE', 'CP', 'CM');
Var
 Op, Y, Z, P2: Byte;
 P: LongInt;
 D8: Byte;
 D16: Word;
Begin
 P := Off + 1;
 Op := GetByte(Off);
 Y := (Op Shr 3) And 7;
 Z := Op And 7;
 P2 := (Op Shr 4) And 3;
 Mnemonic := '(bad)';
 Operands := '';

 If (Op >= $40) And (Op <= $7F) Then Begin
  If Op = $76 Then
   Mnemonic := 'HLT'
  Else Begin
   Mnemonic := 'MOV';
   Operands := Reg8080[Y] + ',' + Reg8080[Z];
  End;
 End Else If (Op >= $80) And (Op <= $BF) Then Begin
  Mnemonic := Alu8080[Y];
  Operands := Reg8080[Z];
 End Else If Op < $40 Then Begin
  Case Op Of
   $00: Mnemonic := 'NOP';
   $01, $11, $21, $31: Begin
    D16 := GetWord(P); P := P + 2;
    Mnemonic := 'LXI';
    Operands := Pair8080[P2] + ',0x' + ToHexFixed(D16, 4);
   End;
   $02, $12: Begin
    Mnemonic := 'STAX';
    Operands := Pair8080[P2];
   End;
   $03, $13, $23, $33: Begin
    Mnemonic := 'INX';
    Operands := Pair8080[P2];
   End;
   $04, $0C, $14, $1C, $24, $2C, $34, $3C: Begin
    Mnemonic := 'INR';
    Operands := Reg8080[Y];
   End;
   $05, $0D, $15, $1D, $25, $2D, $35, $3D: Begin
    Mnemonic := 'DCR';
    Operands := Reg8080[Y];
   End;
   $06, $0E, $16, $1E, $26, $2E, $36, $3E: Begin
    D8 := GetByte(P); Inc(P);
    Mnemonic := 'MVI';
    Operands := Reg8080[Y] + ',0x' + ToHexFixed(D8, 2);
   End;
   $07: Mnemonic := 'RLC';
   $09, $19, $29, $39: Begin
    Mnemonic := 'DAD';
    Operands := Pair8080[P2];
   End;
   $0A, $1A: Begin
    Mnemonic := 'LDAX';
    Operands := Pair8080[P2];
   End;
   $0B, $1B, $2B, $3B: Begin
    Mnemonic := 'DCX';
    Operands := Pair8080[P2];
   End;
   $0F: Mnemonic := 'RRC';
   $17: Mnemonic := 'RAL';
   $1F: Mnemonic := 'RAR';
   $22, $2A, $32, $3A: Begin
    D16 := GetWord(P); P := P + 2;
    Case Op Of
     $22: Mnemonic := 'SHLD';
     $2A: Mnemonic := 'LHLD';
     $32: Mnemonic := 'STA';
     $3A: Mnemonic := 'LDA';
    End;
    Operands := '0x' + ToHexFixed(D16, 4);
   End;
   $27: Mnemonic := 'DAA';
   $2F: Mnemonic := 'CMA';
   $37: Mnemonic := 'STC';
   $3F: Mnemonic := 'CMC';
  End;
 End Else Begin
  If (Op And $C7) = $C0 Then
   Mnemonic := Ret8080[Y]
  Else If (Op And $C7) = $C2 Then Begin
   D16 := GetWord(P); P := P + 2;
   Mnemonic := Jump8080[Y];
   Operands := '0x' + ToHexFixed(D16, 4);
  End Else If (Op And $C7) = $C4 Then Begin
   D16 := GetWord(P); P := P + 2;
   Mnemonic := Call8080[Y];
   Operands := '0x' + ToHexFixed(D16, 4);
  End Else If (Op And $CF) = $C1 Then Begin
   Mnemonic := 'POP';
   Operands := PairPush8080[P2];
  End Else If (Op And $CF) = $C5 Then Begin
   Mnemonic := 'PUSH';
   Operands := PairPush8080[P2];
  End Else If (Op And $C7) = $C6 Then Begin
   D8 := GetByte(P); Inc(P);
   Mnemonic := ImmAlu8080[Y];
   Operands := '0x' + ToHexFixed(D8, 2);
  End Else If (Op And $C7) = $C7 Then Begin
   Mnemonic := 'RST';
   Operands := IntToStr(Y);
  End Else Case Op Of
   $C3: Begin
    D16 := GetWord(P); P := P + 2;
    Mnemonic := 'JMP';
    Operands := '0x' + ToHexFixed(D16, 4);
   End;
   $C9: Mnemonic := 'RET';
   $CD: Begin
    D16 := GetWord(P); P := P + 2;
    Mnemonic := 'CALL';
    Operands := '0x' + ToHexFixed(D16, 4);
   End;
   $D3: Begin
    D8 := GetByte(P); Inc(P);
    Mnemonic := 'OUT';
    Operands := '0x' + ToHexFixed(D8, 2);
   End;
   $DB: Begin
    D8 := GetByte(P); Inc(P);
    Mnemonic := 'IN';
    Operands := '0x' + ToHexFixed(D8, 2);
   End;
   $E3: Mnemonic := 'XTHL';
   $E9: Mnemonic := 'PCHL';
   $EB: Mnemonic := 'XCHG';
   $F3: Mnemonic := 'DI';
   $F9: Mnemonic := 'SPHL';
   $FB: Mnemonic := 'EI';
  End;
 End;

 Disasm8080One := P - Off;
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
  DESASSEMBLEUR MOTOROLA 68000
  ============================================================
  A la difference du 6502/Z80/6800 (table d opcode fixe de 256
  entrees), le 68000 encode ses instructions par champs de bits
  (taille, mode d adressage, registre) sur un mot de 16 bits de
  base, suivi de 0 a 2 mots d extension. Le decodage se fait donc
  algorithmiquement plutot que par table, en suivant la table de
  decodage officielle du M68000 Programmer s Reference Manual
  (dispatch par les 4 bits de poids fort, puis sous-decodage par
  groupe). Boutisme : comme le 6800, le 68000 est gros-boutiste
  (voir GetWordBE/GetDWordBE). }

{ @description: Nom d un registre de donnees D0-D7.
  @param R Numero de registre (0-7)
  @return "D0".."D7" }
Function RegD68k(R: Byte): String;
Begin
 RegD68k := 'D' + Chr(Ord('0') + (R And 7));
End;

{ @description: Nom d un registre d adresse A0-A7.
  @param R Numero de registre (0-7)
  @return "A0".."A7" }
Function RegA68k(R: Byte): String;
Begin
 RegA68k := 'A' + Chr(Ord('0') + (R And 7));
End;

{ @description: Suffixe de taille pour un mnemonique 68000.
  @param Size 0=octet, 1=mot, 2=long
  @return ".B", ".W" ou ".L" }
Function SizeSuf68k(Size: Byte): String;
Begin
 If Size = 0 Then SizeSuf68k := '.B'
 Else If Size = 1 Then SizeSuf68k := '.W'
 Else SizeSuf68k := '.L';
End;

{ @description: Formate un deplacement signe avec signe explicite
    ("+$nn" rendu comme "$nn", "-$nn" pour negatif), pour les modes
    d adressage indexes/indirects du 68000.
  @param V Valeur signee
  @return "$nn" ou "-$nn" }
Function Disp68kStr(V: LongInt): String;
Begin
 If V < 0 Then Disp68kStr := '-$' + ToHexU(-V)
 Else Disp68kStr := '$' + ToHexU(V);
End;

{ @description: Nom de condition 68000 (utilise par Scc, DBcc et
    Bcc, ce dernier remplacant les codes 0/1 par BRA/BSR).
  @param C Code de condition (0-15)
  @return Code mnemonique a 2 lettres ("EQ", "NE", "CC", ...) }
Function CondName68k(C: Byte): String;
Const
 Names: Array[0..15] Of String[2] = (
  'T', 'F', 'HI', 'LS', 'CC', 'CS', 'NE', 'EQ',
  'VC', 'VS', 'PL', 'MI', 'GE', 'LT', 'GT', 'LE');
Begin
 CondName68k := Names[C And 15];
End;

{ @description: Lit une valeur immediate de taille Size a la
    position Off (mot(s) d extension), pour les operandes "#imm".
    Le format .B utilise l octet de poids faible d un mot complet
    (l octet de poids fort est ignore par convention 68000).
  @param Off Decalage (0-based) du premier mot d extension
  @param Size 0=octet, 1=mot, 2=long
  @param ExtraLen (sortie) nombre d octets d extension consommes
  @return "#$nn" / "#$nnnn" / "#$nnnnnnnn" }
Function ImmStr68k(Off: LongInt; Size: Byte; Var ExtraLen: Integer): String;
Begin
 If Size = 0 Then Begin
  ImmStr68k := '#$' + ToHexFixed(GetWordBE(Off) And $FF, 2);
  ExtraLen := 2;
 End Else If Size = 1 Then Begin
  ImmStr68k := '#$' + ToHexFixed(GetWordBE(Off), 4);
  ExtraLen := 2;
 End Else Begin
  ImmStr68k := '#$' + ToHexFixed(GetDWordBE(Off), 8);
  ExtraLen := 4;
 End;
End;

{ @description: Decode un operande EA (effective address) 68000
    complet (les 7 modes d adressage standards, dont les 5 formes
    speciales du mode 7), et indique combien d octets d extension
    ont ete consommes par cette EA (deplacements/valeurs absolues/
    immediat).
  @param Off Decalage (0-based) du premier octet suivant le mot
    d instruction (ou le mot d extension precedent, si l EA n est
    pas le premier operande)
  @param VAddr Adresse virtuelle correspondant a Off (necessaire
    pour resoudre les modes relatifs au PC)
  @param Mode Champ mode (3 bits, 0-7)
  @param Reg Champ registre (3 bits, 0-7, ou sous-mode si Mode=7)
  @param Size Taille de l instruction (0=octet,1=mot,2=long), pour
    le mode immediat
  @param ExtraLen (sortie) nombre d octets d extension consommes
  @return Texte de l operande }
Function DecodeEA68k(Off, VAddr: LongInt; Mode, Reg, Size: Byte;
 Var ExtraLen: Integer): String;
Var
 D16: Integer;
 D8: ShortInt;
 Ext: Word;
 XnIsA: Boolean;
 XnReg: Byte;
 XnLong: Boolean;
 XnStr: String;
 Target: LongInt;
Begin
 ExtraLen := 0;
 Case Mode Of
  0: DecodeEA68k := RegD68k(Reg);
  1: DecodeEA68k := RegA68k(Reg);
  2: DecodeEA68k := '(' + RegA68k(Reg) + ')';
  3: DecodeEA68k := '(' + RegA68k(Reg) + ')+';
  4: DecodeEA68k := '-(' + RegA68k(Reg) + ')';
  5: Begin
   D16 := SmallInt(GetWordBE(Off));
   ExtraLen := 2;
   DecodeEA68k := Disp68kStr(D16) + '(' + RegA68k(Reg) + ')';
  End;
  6: Begin
   Ext := GetWordBE(Off);
   ExtraLen := 2;
   XnIsA := (Ext And $8000) <> 0;
   XnReg := (Ext Shr 12) And 7;
   XnLong := (Ext And $0800) <> 0;
   D8 := ShortInt(Ext And $FF);
   If XnIsA Then XnStr := RegA68k(XnReg) Else XnStr := RegD68k(XnReg);
   If XnLong Then XnStr := XnStr + '.L' Else XnStr := XnStr + '.W';
   DecodeEA68k := Disp68kStr(D8) + '(' + RegA68k(Reg) + ',' + XnStr + ')';
  End;
 Else Begin { Mode = 7 : formes speciales, selectionnees par Reg }
  Case Reg Of
   0: Begin
    D16 := SmallInt(GetWordBE(Off));
    ExtraLen := 2;
    DecodeEA68k := '$' + ToHexFixed(D16 And $FFFF, 4) + '.W';
   End;
   1: Begin
    DecodeEA68k := '$' + ToHexFixed(GetDWordBE(Off), 8);
    ExtraLen := 4;
   End;
   2: Begin
    D16 := SmallInt(GetWordBE(Off));
    ExtraLen := 2;
    Target := VAddr + D16;
    DecodeEA68k := '$' + ToHexFixed(Target, 8) + '(PC)';
   End;
   3: Begin
    Ext := GetWordBE(Off);
    ExtraLen := 2;
    XnIsA := (Ext And $8000) <> 0;
    XnReg := (Ext Shr 12) And 7;
    XnLong := (Ext And $0800) <> 0;
    D8 := ShortInt(Ext And $FF);
    If XnIsA Then XnStr := RegA68k(XnReg) Else XnStr := RegD68k(XnReg);
    If XnLong Then XnStr := XnStr + '.L' Else XnStr := XnStr + '.W';
    DecodeEA68k := Disp68kStr(D8) + '(PC,' + XnStr + ')';
   End;
   4: DecodeEA68k := ImmStr68k(Off, Size, ExtraLen);
  Else
   DecodeEA68k := '?';
  End;
 End;
 End;
End;

{ @description: Construit la liste de registres d une instruction
    MOVEM ("D0-D3/D7/A0", etc.), avec compression des suites
    consecutives. L ordre des bits du masque est inverse pour la
    forme predecrement vers la memoire ("MOVEM regs,-(An)"), comme
    specifie par le manuel Motorola.
  @param Mask Masque 16 bits (bit 0 = D0 ou A7 selon Reverse)
  @param Reverse Vrai si l EA destination est -(An)
  @return Liste de registres separes par "/", plages par "-" }
Function RegList68k(Mask: Word; Reverse: Boolean): String;
Var
 I, RunStart: Integer;
 Names: Array[0..15] Of String[3];
 Bits: Array[0..15] Of Boolean;
 S: String;
Begin
 For I := 0 To 7 Do Names[I] := RegD68k(I);
 For I := 0 To 7 Do Names[8 + I] := RegA68k(I);
 For I := 0 To 15 Do Begin
  If Reverse Then Bits[I] := (Mask And (1 Shl (15 - I))) <> 0
  Else Bits[I] := (Mask And (1 Shl I)) <> 0;
 End;
 { Deux passes separees (D0-D7 puis A0-A7) : une plage ne doit
   jamais franchir la frontiere entre registres de donnees et
   registres d adresse, meme si leurs bits sont contigus dans le
   masque (ex: "D6/D7/A0" doit rester "D6-D7/A0", pas "D6-A0"). }
 S := '';
 I := 0;
 While I <= 7 Do Begin
  If Bits[I] Then Begin
   RunStart := I;
   While (I <= 7) And Bits[I] Do Inc(I);
   If S <> '' Then S := S + '/';
   If I - 1 = RunStart Then S := S + Names[RunStart]
   Else S := S + Names[RunStart] + '-' + Names[I - 1];
  End Else Inc(I);
 End;
 I := 8;
 While I <= 15 Do Begin
  If Bits[I] Then Begin
   RunStart := I;
   While (I <= 15) And Bits[I] Do Inc(I);
   If S <> '' Then S := S + '/';
   If I - 1 = RunStart Then S := S + Names[RunStart]
   Else S := S + Names[RunStart] + '-' + Names[I - 1];
  End Else Inc(I);
 End;
 RegList68k := S;
End;

{ @description: Decode une instruction 68000 a la position Off et
    renvoie son mnemonique, ses operandes et sa longueur en octets.
    Couvre le jeu d instructions utilisateur du 68000 simple (pas
    68010/68020+, pas de FPU 68881, pas de MMU 68851, pas de
    CAS/CAS2/bitfields). MOVEP est decode avec une confiance plus
    faible que le reste (instruction rarissime en pratique, jamais
    validee contre un binaire reel).
  @param Off Decalage (0-based) du mot d instruction
  @param VAddrBase Adresse virtuelle de l instruction (pour les
    branchements et les modes relatifs au PC)
  @param Mnemonic (sortie) mnemonique decode
  @param Operands (sortie) operandes formates
  @return Longueur de l instruction en octets (toujours paire) }
Function Disasm68kOne(Off, VAddrBase: LongInt;
 Var Mnemonic, Operands: String): Integer;
Var
 Op: Word;
 Len: Integer;
 Top4, Nibble, Bit8, Nib2: Integer;
 SrcMode, SrcReg, DstMode, DstReg: Byte;
 Size, OpMode: Byte;
 EA: String;
 Ext: Integer;
 Rx: Byte;
 Cond: Byte;
 DispB: ShortInt;
 DispW: Integer;
 Target: LongInt;
 Mask: Word;
 IsLong: Boolean;
 Data3: Byte;
 IsReg: Boolean;
 TypeNames: Array[0..3] Of String[4];
 ShCount, ShType: Byte;
Begin
 Op := GetWordBE(Off);
 Len := 2;
 Mnemonic := '(bad)';
 Operands := '';
 Top4 := (Op Shr 12) And $F;

 Case Top4 Of

  $0: Begin { immediat / bit ops / MOVEP }
   Nibble := (Op Shr 8) And $F;
   If (Nibble And 1) = 1 Then Begin
    SrcMode := (Op Shr 3) And 7;
    SrcReg  := Op And 7;
    Rx := (Op Shr 9) And 7;
    If SrcMode = 1 Then Begin { MOVEP Dx,(d16,Ay) ou l inverse }
     DispW := SmallInt(GetWordBE(Off + 2));
     Len := 4;
     OpMode := (Op Shr 6) And 3;
     If OpMode < 2 Then Begin { memoire -> registre }
      If OpMode = 0 Then Mnemonic := 'MOVEP.W' Else Mnemonic := 'MOVEP.L';
      Operands := Disp68kStr(DispW) + '(' + RegA68k(SrcReg) + '),' + RegD68k(Rx);
     End Else Begin { registre -> memoire }
      If OpMode = 2 Then Mnemonic := 'MOVEP.W' Else Mnemonic := 'MOVEP.L';
      Operands := RegD68k(Rx) + ',' + Disp68kStr(DispW) + '(' + RegA68k(SrcReg) + ')';
     End;
    End Else Begin { BTST/BCHG/BCLR/BSET Dn,<ea> }
     OpMode := (Op Shr 6) And 3;
     If OpMode = 0 Then Mnemonic := 'BTST'
     Else If OpMode = 1 Then Mnemonic := 'BCHG'
     Else If OpMode = 2 Then Mnemonic := 'BCLR'
     Else Mnemonic := 'BSET';
     EA := DecodeEA68k(Off + 2, VAddrBase + 2, SrcMode, SrcReg, 0, Ext);
     Len := 2 + Ext;
     Operands := RegD68k(Rx) + ',' + EA;
    End;
   End Else Begin
    Case Nibble Of
     $0, $2, $4, $6, $A, $C: Begin
      Size := (Op Shr 6) And 3;
      SrcMode := (Op Shr 3) And 7;
      SrcReg  := Op And 7;
      If (Size = 3) And (SrcMode = 7) And (SrcReg = 4) Then
       Mnemonic := '(bad)' { taille invalide }
      Else If (SrcMode = 7) And (SrcReg = 4) And
              ((Nibble = 0) Or (Nibble = 2) Or (Nibble = $A)) Then Begin
       { formes speciales vers CCR/SR (ORI/ANDI/EORI uniquement) }
       EA := ImmStr68k(Off + 2, Size, Ext);
       Len := 2 + Ext;
       If Nibble = 0 Then Mnemonic := 'ORI'
       Else If Nibble = 2 Then Mnemonic := 'ANDI'
       Else Mnemonic := 'EORI';
       If Size = 0 Then Operands := EA + ',CCR'
       Else Operands := EA + ',SR';
      End Else Begin
       EA := ImmStr68k(Off + 2, Size, Ext);
       Len := 2 + Ext;
       EA := EA + ',' + DecodeEA68k(Off + Len, VAddrBase + Len, SrcMode, SrcReg, Size, Ext);
       Len := Len + Ext;
       Case Nibble Of
        $0: Mnemonic := 'ORI' + SizeSuf68k(Size);
        $2: Mnemonic := 'ANDI' + SizeSuf68k(Size);
        $4: Mnemonic := 'SUBI' + SizeSuf68k(Size);
        $6: Mnemonic := 'ADDI' + SizeSuf68k(Size);
        $A: Mnemonic := 'EORI' + SizeSuf68k(Size);
        $C: Mnemonic := 'CMPI' + SizeSuf68k(Size);
       End;
       Operands := EA;
      End;
     End;
     $8: Begin { BTST/BCHG/BCLR/BSET #imm,<ea> }
      OpMode := (Op Shr 6) And 3;
      SrcMode := (Op Shr 3) And 7;
      SrcReg  := Op And 7;
      EA := ImmStr68k(Off + 2, 0, Ext);
      Len := 2 + Ext;
      EA := EA + ',' + DecodeEA68k(Off + Len, VAddrBase + Len, SrcMode, SrcReg, 0, Ext);
      Len := Len + Ext;
      If OpMode = 0 Then Mnemonic := 'BTST'
      Else If OpMode = 1 Then Mnemonic := 'BCHG'
      Else If OpMode = 2 Then Mnemonic := 'BCLR'
      Else Mnemonic := 'BSET';
      Operands := EA;
     End;
    End; { Case Nibble }
   End;
  End;

  $1, $2, $3: Begin { MOVE.B / MOVE.L / MOVE.W (et MOVEA) }
   If Top4 = 1 Then Size := 0 Else If Top4 = 3 Then Size := 1 Else Size := 2;
   DstReg  := (Op Shr 9) And 7;
   DstMode := (Op Shr 6) And 7;
   SrcMode := (Op Shr 3) And 7;
   SrcReg  := Op And 7;
   EA := DecodeEA68k(Off + 2, VAddrBase + 2, SrcMode, SrcReg, Size, Ext);
   Len := 2 + Ext;
   If DstMode = 1 Then Begin { MOVEA }
    Mnemonic := 'MOVEA' + SizeSuf68k(Size);
    Operands := EA + ',' + RegA68k(DstReg);
   End Else Begin
    Mnemonic := 'MOVE' + SizeSuf68k(Size);
    Operands := EA + ',' + DecodeEA68k(Off + Len, VAddrBase + Len, DstMode, DstReg, Size, Ext);
    Len := Len + Ext;
   End;
  End;

  $4: Begin { groupe divers }
   Bit8 := (Op Shr 8) And 1;
   Nibble := (Op Shr 8) And $F;
   If Bit8 = 1 Then Begin { CHK / LEA, registre variable }
    Rx := (Op Shr 9) And 7;
    SrcMode := (Op Shr 3) And 7;
    SrcReg  := Op And 7;
    OpMode := (Op Shr 6) And 3;
    EA := DecodeEA68k(Off + 2, VAddrBase + 2, SrcMode, SrcReg, 1, Ext);
    Len := 2 + Ext;
    If OpMode = 2 Then Begin
     Mnemonic := 'CHK';
     Operands := EA + ',' + RegD68k(Rx);
    End Else If OpMode = 3 Then Begin
     Mnemonic := 'LEA';
     Operands := EA + ',' + RegA68k(Rx);
    End Else
     Mnemonic := '(bad)';
   End Else Begin
    Case Nibble Of
     $0, $2, $4, $6: Begin { NEGX/CLR/NEG/NOT, ou MOVE SR/CCR a size=11 }
      Size := (Op Shr 6) And 3;
      SrcMode := (Op Shr 3) And 7;
      SrcReg  := Op And 7;
      EA := DecodeEA68k(Off + 2, VAddrBase + 2, SrcMode, SrcReg, 1, Ext);
      Len := 2 + Ext;
      If Size = 3 Then Begin
       If Nibble = 0 Then Begin Mnemonic := 'MOVE'; Operands := 'SR,' + EA; End
       Else If Nibble = 4 Then Begin Mnemonic := 'MOVE'; Operands := EA + ',CCR'; End
       Else If Nibble = 6 Then Begin Mnemonic := 'MOVE'; Operands := EA + ',SR'; End
       Else Mnemonic := '(bad)';
      End Else Begin
       Case Nibble Of
        $0: Mnemonic := 'NEGX' + SizeSuf68k(Size);
        $2: Mnemonic := 'CLR' + SizeSuf68k(Size);
        $4: Mnemonic := 'NEG' + SizeSuf68k(Size);
        $6: Mnemonic := 'NOT' + SizeSuf68k(Size);
       End;
       Operands := EA;
      End;
     End;
     $8: Begin { NBCD / SWAP / PEA / MOVEM (stockage) }
      OpMode := (Op Shr 6) And 3;
      SrcMode := (Op Shr 3) And 7;
      SrcReg  := Op And 7;
      If OpMode = 0 Then Begin
       EA := DecodeEA68k(Off + 2, VAddrBase + 2, SrcMode, SrcReg, 0, Ext);
       Len := 2 + Ext;
       Mnemonic := 'NBCD';
       Operands := EA;
      End Else If OpMode = 1 Then Begin
       If SrcMode = 0 Then Begin
        Mnemonic := 'SWAP';
        Operands := RegD68k(SrcReg);
       End Else Begin
        EA := DecodeEA68k(Off + 2, VAddrBase + 2, SrcMode, SrcReg, 2, Ext);
        Len := 2 + Ext;
        Mnemonic := 'PEA';
        Operands := EA;
       End;
      End Else Begin
       IsLong := OpMode = 3;
       Mask := GetWordBE(Off + 2);
       EA := DecodeEA68k(Off + 4, VAddrBase + 4, SrcMode, SrcReg, 0, Ext);
       Len := 4 + Ext;
       If IsLong Then Mnemonic := 'MOVEM.L' Else Mnemonic := 'MOVEM.W';
       Operands := RegList68k(Mask, SrcMode = 4) + ',' + EA;
      End;
     End;
     $A: Begin { TST / TAS / ILLEGAL }
      Size := (Op Shr 6) And 3;
      SrcMode := (Op Shr 3) And 7;
      SrcReg  := Op And 7;
      If (Size = 3) And (SrcMode = 7) And (SrcReg = 4) Then Begin
       Mnemonic := 'ILLEGAL';
       Len := 2;
      End Else If Size = 3 Then Begin
       EA := DecodeEA68k(Off + 2, VAddrBase + 2, SrcMode, SrcReg, 0, Ext);
       Len := 2 + Ext;
       Mnemonic := 'TAS';
       Operands := EA;
      End Else Begin
       EA := DecodeEA68k(Off + 2, VAddrBase + 2, SrcMode, SrcReg, Size, Ext);
       Len := 2 + Ext;
       Mnemonic := 'TST' + SizeSuf68k(Size);
       Operands := EA;
      End;
     End;
     $C: Begin { MOVEM (chargement) }
      OpMode := (Op Shr 6) And 3;
      SrcMode := (Op Shr 3) And 7;
      SrcReg  := Op And 7;
      If OpMode >= 2 Then Begin
       IsLong := OpMode = 3;
       Mask := GetWordBE(Off + 2);
       EA := DecodeEA68k(Off + 4, VAddrBase + 4, SrcMode, SrcReg, 0, Ext);
       Len := 4 + Ext;
       If IsLong Then Mnemonic := 'MOVEM.L' Else Mnemonic := 'MOVEM.W';
       Operands := EA + ',' + RegList68k(Mask, False);
      End Else
       Mnemonic := '(bad)';
     End;
     $E: Begin { TRAP / LINK / UNLK / MOVE USP / RTx / JSR / JMP / ... }
      Nib2 := (Op Shr 4) And $F;
      Case Nib2 Of
       $4: Begin Mnemonic := 'TRAP'; Operands := '#' + IntToStr(Op And $F); End;
       $5: Begin
        If (Op And 8) = 0 Then Begin
         DispW := SmallInt(GetWordBE(Off + 2));
         Len := 4;
         Mnemonic := 'LINK';
         Operands := RegA68k(Op And 7) + ',' + Disp68kStr(DispW);
        End Else Begin
         Mnemonic := 'UNLK'; Operands := RegA68k(Op And 7);
        End;
       End;
       $6: Begin
        If (Op And 8) = 0 Then Begin
         Mnemonic := 'MOVE'; Operands := RegA68k(Op And 7) + ',USP';
        End Else Begin
         Mnemonic := 'MOVE'; Operands := 'USP,' + RegA68k(Op And 7);
        End;
       End;
       $7: Begin
        Case Op And $F Of
         $0: Mnemonic := 'RESET';
         $1: Mnemonic := 'NOP';
         $2: Begin
          Mnemonic := 'STOP';
          Operands := ImmStr68k(Off + 2, 1, Ext);
          Len := 2 + Ext;
         End;
         $3: Mnemonic := 'RTE';
         $5: Mnemonic := 'RTS';
         $6: Mnemonic := 'TRAPV';
         $7: Mnemonic := 'RTR';
        Else
         Mnemonic := '(bad)';
        End;
       End;
      Else Begin
       OpMode := (Op Shr 6) And 3;
       SrcMode := (Op Shr 3) And 7;
       SrcReg  := Op And 7;
       If OpMode >= 2 Then Begin
        EA := DecodeEA68k(Off + 2, VAddrBase + 2, SrcMode, SrcReg, 2, Ext);
        Len := 2 + Ext;
        If OpMode = 2 Then Mnemonic := 'JSR' Else Mnemonic := 'JMP';
        Operands := EA;
       End Else
        Mnemonic := '(bad)';
      End;
      End;
     End;
    Else
     Mnemonic := '(bad)';
    End; { Case Nibble }
   End;
  End;

  $5: Begin { ADDQ/SUBQ ou Scc/DBcc }
   Size := (Op Shr 6) And 3;
   SrcMode := (Op Shr 3) And 7;
   SrcReg  := Op And 7;
   If Size = 3 Then Begin
    Cond := (Op Shr 8) And $F;
    If SrcMode = 1 Then Begin { DBcc Dn,label }
     DispW := SmallInt(GetWordBE(Off + 2));
     Len := 4;
     Target := VAddrBase + 2 + DispW;
     Mnemonic := 'DB' + CondName68k(Cond);
     Operands := RegD68k(SrcReg) + ',$' + ToHexFixed(Target, 8);
    End Else Begin
     EA := DecodeEA68k(Off + 2, VAddrBase + 2, SrcMode, SrcReg, 0, Ext);
     Len := 2 + Ext;
     Mnemonic := 'S' + CondName68k(Cond);
     Operands := EA;
    End;
   End Else Begin
    Data3 := (Op Shr 9) And 7;
    If Data3 = 0 Then Data3 := 8;
    EA := DecodeEA68k(Off + 2, VAddrBase + 2, SrcMode, SrcReg, Size, Ext);
    Len := 2 + Ext;
    If ((Op Shr 8) And 1) = 0 Then Mnemonic := 'ADDQ' + SizeSuf68k(Size)
    Else Mnemonic := 'SUBQ' + SizeSuf68k(Size);
    Operands := '#$' + ToHexU(Data3) + ',' + EA;
   End;
  End;

  $6: Begin { Bcc / BRA / BSR }
   Cond := (Op Shr 8) And $F;
   DispB := ShortInt(Op And $FF);
   IsLong := False; { reutilise comme drapeau "deplacement invalide" }
   If (Op And $FF) = 0 Then Begin
    DispW := SmallInt(GetWordBE(Off + 2));
    Len := 4;
    Target := VAddrBase + 2 + DispW;
   End Else If (Op And $FF) = $FF Then Begin
    IsLong := True; { deplacement 32 bits, 68020+ uniquement : non supporte }
    Len := 2;
   End Else Begin
    Target := VAddrBase + 2 + DispB;
    Len := 2;
   End;
   If Not IsLong Then Begin
    If Cond = 0 Then Mnemonic := 'BRA'
    Else If Cond = 1 Then Mnemonic := 'BSR'
    Else Mnemonic := 'B' + CondName68k(Cond);
    Operands := '$' + ToHexFixed(Target, 8);
   End;
  End;

  $7: Begin { MOVEQ }
   Rx := (Op Shr 9) And 7;
   Mnemonic := 'MOVEQ';
   Operands := '#$' + ToHexFixed(ShortInt(Op And $FF), 8) + ',' + RegD68k(Rx);
  End;

  $8, $9, $B, $C, $D: Begin { OR/SUB/CMP+EOR/AND/ADD, et formes A/X/M associees }
   Rx := (Op Shr 9) And 7;
   OpMode := (Op Shr 6) And 7;
   SrcMode := (Op Shr 3) And 7;
   SrcReg  := Op And 7;
   If (OpMode = 3) Or (OpMode = 7) Then Begin
    { forme A : DIVU/DIVS (8), MULU/MULS (C), xxxA.W/.L <ea>,Ax (9,B,D) }
    If OpMode = 3 Then Size := 1 Else Size := 2;
    EA := DecodeEA68k(Off + 2, VAddrBase + 2, SrcMode, SrcReg, Size, Ext);
    Len := 2 + Ext;
    Case Top4 Of
     $8: If OpMode = 3 Then Mnemonic := 'DIVU.W' Else Mnemonic := 'DIVS.W';
     $C: If OpMode = 3 Then Mnemonic := 'MULU.W' Else Mnemonic := 'MULS.W';
     $9: Mnemonic := 'SUBA' + SizeSuf68k(Size);
     $B: Mnemonic := 'CMPA' + SizeSuf68k(Size);
     $D: Mnemonic := 'ADDA' + SizeSuf68k(Size);
    End;
    If (Top4 = $8) Or (Top4 = $C) Then
     Operands := EA + ',' + RegD68k(Rx) { DIVU/DIVS/MULU/MULS ecrivent dans Dn }
    Else
     Operands := EA + ',' + RegA68k(Rx);
   End Else If OpMode <= 2 Then Begin
    { forme normale : op.sz <ea>,Dn }
    Size := OpMode;
    EA := DecodeEA68k(Off + 2, VAddrBase + 2, SrcMode, SrcReg, Size, Ext);
    Len := 2 + Ext;
    Case Top4 Of
     $8: Mnemonic := 'OR' + SizeSuf68k(Size);
     $9: Mnemonic := 'SUB' + SizeSuf68k(Size);
     $B: Mnemonic := 'CMP' + SizeSuf68k(Size);
     $C: Mnemonic := 'AND' + SizeSuf68k(Size);
     $D: Mnemonic := 'ADD' + SizeSuf68k(Size);
    End;
    Operands := EA + ',' + RegD68k(Rx);
   End Else Begin
    { OpMode in [4,5,6] : Dn,<ea>, ou formes X/BCD/EXG/CMPM selon SrcMode }
    Size := OpMode - 4;
    If Top4 = $C Then Begin { AND : ABCD ou EXG ou AND Dn,<ea> }
     If (OpMode = 4) And (SrcMode <= 1) Then Begin
      Mnemonic := 'ABCD';
      If SrcMode = 0 Then
       Operands := RegD68k(SrcReg) + ',' + RegD68k(Rx)
      Else
       Operands := '-(' + RegA68k(SrcReg) + '),-(' + RegA68k(Rx) + ')';
     End Else If (OpMode = 5) And (SrcMode = 0) Then Begin
      Mnemonic := 'EXG'; Operands := RegD68k(Rx) + ',' + RegD68k(SrcReg);
     End Else If (OpMode = 5) And (SrcMode = 1) Then Begin
      Mnemonic := 'EXG'; Operands := RegA68k(Rx) + ',' + RegA68k(SrcReg);
     End Else If (OpMode = 6) And (SrcMode = 1) Then Begin
      Mnemonic := 'EXG'; Operands := RegD68k(Rx) + ',' + RegA68k(SrcReg);
     End Else Begin
      EA := DecodeEA68k(Off + 2, VAddrBase + 2, SrcMode, SrcReg, Size, Ext);
      Len := 2 + Ext;
      Mnemonic := 'AND' + SizeSuf68k(Size);
      Operands := RegD68k(Rx) + ',' + EA;
     End;
    End Else If Top4 = $B Then Begin { CMP/EOR : CMPM ou EOR Dn,<ea> }
     If SrcMode = 1 Then Begin
      Mnemonic := 'CMPM' + SizeSuf68k(Size);
      Operands := '(' + RegA68k(SrcReg) + ')+,(' + RegA68k(Rx) + ')+';
     End Else Begin
      EA := DecodeEA68k(Off + 2, VAddrBase + 2, SrcMode, SrcReg, Size, Ext);
      Len := 2 + Ext;
      Mnemonic := 'EOR' + SizeSuf68k(Size);
      Operands := RegD68k(Rx) + ',' + EA;
     End;
    End Else Begin { SUB(9)/OR(8)/ADD(D) : SUBX/ADDX/SBCD ou op Dn,<ea> }
     If SrcMode <= 1 Then Begin
      IsReg := SrcMode = 0;
      If Top4 = $8 Then Begin
       Mnemonic := 'SBCD';
       If IsReg Then Operands := RegD68k(SrcReg) + ',' + RegD68k(Rx)
       Else Operands := '-(' + RegA68k(SrcReg) + '),-(' + RegA68k(Rx) + ')';
      End Else Begin
       If Top4 = $9 Then Mnemonic := 'SUBX' + SizeSuf68k(Size)
       Else Mnemonic := 'ADDX' + SizeSuf68k(Size);
       If IsReg Then Operands := RegD68k(SrcReg) + ',' + RegD68k(Rx)
       Else Operands := '-(' + RegA68k(SrcReg) + '),-(' + RegA68k(Rx) + ')';
      End;
     End Else Begin
      EA := DecodeEA68k(Off + 2, VAddrBase + 2, SrcMode, SrcReg, Size, Ext);
      Len := 2 + Ext;
      If Top4 = $8 Then Mnemonic := 'OR' + SizeSuf68k(Size)
      Else Mnemonic := 'ADD' + SizeSuf68k(Size);
      Operands := RegD68k(Rx) + ',' + EA;
     End;
    End;
   End;
  End;

  $E: Begin { decalages/rotations, registre uniquement sur 68000 }
   TypeNames[0] := 'AS'; TypeNames[1] := 'LS';
   TypeNames[2] := 'ROX'; TypeNames[3] := 'RO';
   Size := (Op Shr 6) And 3;
   ShType := (Op Shr 3) And 3;
   If Size = 3 Then
    Mnemonic := '(bad)' { forme memoire, 68020+ uniquement }
   Else Begin
    If ((Op Shr 8) And 1) = 1 Then Mnemonic := TypeNames[ShType] + 'L'
    Else Mnemonic := TypeNames[ShType] + 'R';
    Mnemonic := Mnemonic + SizeSuf68k(Size);
    If ((Op Shr 5) And 1) = 1 Then
     Operands := RegD68k((Op Shr 9) And 7) + ',' + RegD68k(Op And 7)
    Else Begin
     ShCount := (Op Shr 9) And 7;
     If ShCount = 0 Then ShCount := 8;
     Operands := '#$' + ToHexU(ShCount) + ',' + RegD68k(Op And 7);
    End;
   End;
  End;

 Else
  Mnemonic := '(bad)';
 End; { Case Top4 }

 Disasm68kOne := Len;
End;

{ ============================================================
  DESASSEMBLEUR SPARC V8 / SOUS-ENSEMBLE ENTIER V9
  ============================================================ }

{ @description: Retourne le nom ABI d un registre SPARC. }
Function SparcReg(R: Byte): String;
Const
 Names: Array[0..31] Of String[3] = (
  '%g0', '%g1', '%g2', '%g3', '%g4', '%g5', '%g6', '%g7',
  '%o0', '%o1', '%o2', '%o3', '%o4', '%o5', '%o6', '%o7',
  '%l0', '%l1', '%l2', '%l3', '%l4', '%l5', '%l6', '%l7',
  '%i0', '%i1', '%i2', '%i3', '%i4', '%i5', '%i6', '%i7');
Begin
 SparcReg := Names[R And 31];
End;

{ @description: Formate l operande rs2/simm13 du format 3 SPARC. }
Function SparcOp2(Instr: LongInt): String;
Var
 V: LongInt;
Begin
 If (Instr And $2000) <> 0 Then Begin
  V := Instr And $1FFF;
  If (V And $1000) <> 0 Then V := V Or LongInt($FFFFE000);
  SparcOp2 := ToHexSignedDisp(V);
  If V = 0 Then SparcOp2 := '0';
 End Else
  SparcOp2 := SparcReg(Instr And 31);
End;

{ @description: Formate une adresse memoire SPARC [rs1+rs2/simm13]. }
Function SparcAddr(Instr: LongInt): String;
Var
 R1, O2: String;
Begin
 R1 := SparcReg((Instr Shr 14) And 31);
 O2 := SparcOp2(Instr);
 If O2 = '0' Then SparcAddr := '[' + R1 + ']'
 Else If Copy(O2, 1, 1) = '-' Then SparcAddr := '[' + R1 + O2 + ']'
 Else SparcAddr := '[' + R1 + '+' + O2 + ']';
End;

{ @description: Desassemble une instruction SPARC de 32 bits. Les
    formats V8 entiers principaux sont couverts, ainsi que leur noyau
    commun avec V9 : CALL, branches Bicc, SETHI, ALU, decalages,
    SAVE/RESTORE, JMPL/RETT, traps et chargements/stockages. }
Function DisasmSparcOne(Off, VAddrBase: LongInt;
 Var Mnemonic, Operands: String): Integer;
Const
 BCond: Array[0..15] Of String[4] = (
  'bn', 'be', 'ble', 'bl', 'bleu', 'bcs', 'bneg', 'bvs',
  'ba', 'bne', 'bg', 'bge', 'bgu', 'bcc', 'bpos', 'bvc');
 TCond: Array[0..15] Of String[4] = (
  'tn', 'te', 'tle', 'tl', 'tleu', 'tcs', 'tneg', 'tvs',
  'ta', 'tne', 'tg', 'tge', 'tgu', 'tcc', 'tpos', 'tvc');
 AluNames: Array[0..31] Of String[8] = (
  'add', 'and', 'or', 'xor', 'sub', 'andn', 'orn', 'xnor',
  'addx', '', 'umul', 'smul', 'subx', '', 'udiv', 'sdiv',
  'addcc', 'andcc', 'orcc', 'xorcc', 'subcc', 'andncc', 'orncc', 'xnorcc',
  'taddcc', 'tsubcc', 'taddcctv', 'tsubcctv', 'mulscc', '', 'udivcc', 'sdivcc');
 LoadNames: Array[0..27] Of String[7] = (
  'ld', 'ldub', 'lduh', 'ldd', 'st', 'stb', 'sth', 'std',
  'ldsb', 'ldsh', 'ldstub', 'swap', '', '', '', '',
  'lda', 'lduba', 'lduha', 'ldda', 'sta', 'stba', 'stha', 'stda',
  'ldsba', 'ldsha', 'ldstuba', 'swapa');
Var
 Instr, Disp, Target: LongInt;
 Op, Op2, Op3, Rd, Rs1, Cond: Byte;
 Annul: Boolean;
 A, B, Dst, Addr, Asi: String;
 IsStore: Boolean;
Begin
 Instr := GetDWordBE(Off);
 Op := (Instr Shr 30) And 3;
 Rd := (Instr Shr 25) And 31;
 Mnemonic := '(bad)';
 Operands := '';

 If Op = 1 Then Begin
  Disp := Instr Shl 2;
  Target := VAddrBase + Disp;
  Mnemonic := 'call';
  Operands := '0x' + ToHexFixed(Target, 8);
 End Else If Op = 0 Then Begin
  Op2 := (Instr Shr 22) And 7;
  If Op2 = 4 Then Begin
   Disp := (Instr And $3FFFFF) Shl 10;
   If (Rd = 0) And (Disp = 0) Then
    Mnemonic := 'nop'
   Else Begin
    Mnemonic := 'sethi';
    Operands := '%hi(0x' + ToHexFixed(Disp, 8) + '),' + SparcReg(Rd);
   End;
  End Else If Op2 = 2 Then Begin
   Cond := (Instr Shr 25) And 15;
   Annul := (Instr And LongInt($20000000)) <> 0;
   Disp := Instr And $3FFFFF;
   If (Disp And $200000) <> 0 Then Disp := Disp Or LongInt($FFC00000);
   Target := VAddrBase + Disp * 4;
   Mnemonic := BCond[Cond];
   If Annul Then Mnemonic := Mnemonic + ',a';
   Operands := '0x' + ToHexFixed(Target, 8);
  End Else If Op2 = 0 Then Begin
   Mnemonic := 'unimp';
   Operands := '0x' + ToHexU(Instr And $3FFFFF);
  End;
 End Else Begin
  Op3 := (Instr Shr 19) And 63;
  Rs1 := (Instr Shr 14) And 31;
  A := SparcReg(Rs1);
  B := SparcOp2(Instr);
  Dst := SparcReg(Rd);

  If Op = 2 Then Begin
   If Op3 <= 31 Then Begin
    Mnemonic := AluNames[Op3];
    If Mnemonic <> '' Then Operands := A + ',' + B + ',' + Dst
    Else Mnemonic := '(bad)';
   End Else Case Op3 Of
    $25: Begin Mnemonic := 'sll'; Operands := A + ',' + B + ',' + Dst; End;
    $26: Begin Mnemonic := 'srl'; Operands := A + ',' + B + ',' + Dst; End;
    $27: Begin Mnemonic := 'sra'; Operands := A + ',' + B + ',' + Dst; End;
    $28: Begin
     Mnemonic := 'rd';
     If Rs1 = 0 Then Operands := '%y,' + Dst
     Else Operands := '%asr' + IntToStr(Rs1) + ',' + Dst;
    End;
    $29: Begin Mnemonic := 'rd'; Operands := '%psr,' + Dst; End;
    $2A: Begin Mnemonic := 'rd'; Operands := '%wim,' + Dst; End;
    $2B: Begin Mnemonic := 'rd'; Operands := '%tbr,' + Dst; End;
    $30, $31, $32, $33: Begin
     Mnemonic := 'wr';
     Case Op3 Of
      $30: If Rd = 0 Then Dst := '%y' Else Dst := '%asr' + IntToStr(Rd);
      $31: Dst := '%psr';
      $32: Dst := '%wim';
      $33: Dst := '%tbr';
     End;
     Operands := A + ',' + B + ',' + Dst;
    End;
    $38: Begin
     If (Rd = 0) And ((Instr And $2000) <> 0) And
        ((Instr And $1FFF) = 8) And (Rs1 = 31) Then Mnemonic := 'ret'
     Else If (Rd = 0) And ((Instr And $2000) <> 0) And
             ((Instr And $1FFF) = 8) And (Rs1 = 15) Then Mnemonic := 'retl'
     Else Begin
      Mnemonic := 'jmpl';
      Operands := SparcAddr(Instr) + ',' + Dst;
     End;
    End;
    $39: Begin Mnemonic := 'rett'; Operands := SparcAddr(Instr); End;
    $3A: Begin
     Cond := (Instr Shr 25) And 15;
     Mnemonic := TCond[Cond];
     Operands := A + '+' + B;
    End;
    $3B: Begin Mnemonic := 'flush'; Operands := SparcAddr(Instr); End;
    $3C: Begin Mnemonic := 'save'; Operands := A + ',' + B + ',' + Dst; End;
    $3D: Begin Mnemonic := 'restore'; Operands := A + ',' + B + ',' + Dst; End;
   End;
  End Else Begin
   Addr := SparcAddr(Instr);
   If Op3 <= $1B Then Begin
    Mnemonic := LoadNames[Op3];
    If Mnemonic <> '' Then Begin
     IsStore := (Op3 And 4) <> 0;
     If Op3 In [$0B, $1B] Then IsStore := False; { SWAP/SWAPA }
     If Op3 >= $10 Then Begin
      Asi := '';
      If (Instr And $2000) = 0 Then
       Asi := ' 0x' + ToHexFixed((Instr Shr 5) And $FF, 2);
      Addr := Addr + Asi;
     End;
     If IsStore Then Operands := Dst + ',' + Addr
     Else Operands := Addr + ',' + Dst;
    End;
   End Else Case Op3 Of
    $20: Begin Mnemonic := 'ld'; Operands := Addr + ',%f' + IntToStr(Rd); End;
    $21: Begin Mnemonic := 'ld'; Operands := Addr + ',%fsr'; End;
    $23: Begin Mnemonic := 'ldd'; Operands := Addr + ',%f' + IntToStr(Rd); End;
    $24: Begin Mnemonic := 'st'; Operands := '%f' + IntToStr(Rd) + ',' + Addr; End;
    $25: Begin Mnemonic := 'st'; Operands := '%fsr,' + Addr; End;
    $27: Begin Mnemonic := 'std'; Operands := '%f' + IntToStr(Rd) + ',' + Addr; End;
   End;
  End;
 End;

 DisasmSparcOne := 4;
End;

{ ============================================================
  DESASSEMBLEUR MIPS I/II ET MIPS32
  ============================================================ }

{ @description: Retourne le nom ABI usuel d un registre MIPS. }
Function MipsReg(R: Byte): String;
Const
 Names: Array[0..31] Of String[5] = (
  '$zero', '$at', '$v0', '$v1', '$a0', '$a1', '$a2', '$a3',
  '$t0', '$t1', '$t2', '$t3', '$t4', '$t5', '$t6', '$t7',
  '$s0', '$s1', '$s2', '$s3', '$s4', '$s5', '$s6', '$s7',
  '$t8', '$t9', '$k0', '$k1', '$gp', '$sp', '$fp', '$ra');
Begin
 MipsReg := Names[R And 31];
End;

{ @description: Etend un immediat 16 bits signe en LongInt. }
Function MipsSign16(V: Word): LongInt;
Begin
 If (V And $8000) <> 0 Then MipsSign16 := LongInt(V) Or LongInt($FFFF0000)
 Else MipsSign16 := V;
End;

{ @description: Formate une adresse base+deplacement MIPS. }
Function MipsMem(Imm: Word; Base: Byte): String;
Var
 V: LongInt;
 S: String;
Begin
 V := MipsSign16(Imm);
 If V < 0 Then S := '-0x' + ToHexU(-V)
 Else S := '0x' + ToHexU(V);
 MipsMem := S + '(' + MipsReg(Base) + ')';
End;

{ @description: Desassemble une instruction MIPS de 32 bits. Le noyau
    entier MIPS I/II et MIPS32 est couvert : SPECIAL, REGIMM, sauts,
    branches, immediats, HI/LO, SPECIAL2, COP0 et acces memoire. Le
    boutisme est choisi par ARCH_MIPS/ARCH_MIPSEL ou par EI_DATA ELF. }
Function DisasmMipsOne(Off, VAddrBase: LongInt;
 Var Mnemonic, Operands: String): Integer;
Const
 LoadStoreNames: Array[$20..$3F] Of String[5] = (
  'lb', 'lh', 'lwl', 'lw', 'lbu', 'lhu', 'lwr', '',
  'sb', 'sh', 'swl', 'sw', '', '', 'swr', 'cache',
  'll', 'lwc1', 'lwc2', 'pref', '', 'ldc1', 'ldc2', '',
  'sc', 'swc1', 'swc2', '', '', 'sdc1', 'sdc2', '');
Var
 Instr, Target, SImm: LongInt;
 Op, Rs, Rt, Rd, Sa, Funct: Byte;
 Imm: Word;
 Code: LongInt;
 Mem, ImmText, RegText: String;
Begin
 If Arch = ARCH_MIPSEL Then Instr := GetDWord(Off)
 Else Instr := GetDWordBE(Off);
 Op := (Instr Shr 26) And $3F;
 Rs := (Instr Shr 21) And $1F;
 Rt := (Instr Shr 16) And $1F;
 Rd := (Instr Shr 11) And $1F;
 Sa := (Instr Shr 6) And $1F;
 Funct := Instr And $3F;
 Imm := Instr And $FFFF;
 SImm := MipsSign16(Imm);
 Mnemonic := '(bad)';
 Operands := '';

 Case Op Of
  $00: Begin { SPECIAL }
   If Instr = 0 Then Mnemonic := 'nop'
   Else Case Funct Of
    $00: Begin Mnemonic := 'sll'; Operands := MipsReg(Rd) + ',' + MipsReg(Rt) + ',' + IntToStr(Sa); End;
    $02: Begin Mnemonic := 'srl'; Operands := MipsReg(Rd) + ',' + MipsReg(Rt) + ',' + IntToStr(Sa); End;
    $03: Begin Mnemonic := 'sra'; Operands := MipsReg(Rd) + ',' + MipsReg(Rt) + ',' + IntToStr(Sa); End;
    $04: Begin Mnemonic := 'sllv'; Operands := MipsReg(Rd) + ',' + MipsReg(Rt) + ',' + MipsReg(Rs); End;
    $06: Begin Mnemonic := 'srlv'; Operands := MipsReg(Rd) + ',' + MipsReg(Rt) + ',' + MipsReg(Rs); End;
    $07: Begin Mnemonic := 'srav'; Operands := MipsReg(Rd) + ',' + MipsReg(Rt) + ',' + MipsReg(Rs); End;
    $08: Begin Mnemonic := 'jr'; Operands := MipsReg(Rs); End;
    $09: Begin
     Mnemonic := 'jalr';
     If Rd = 31 Then Operands := MipsReg(Rs)
     Else Operands := MipsReg(Rd) + ',' + MipsReg(Rs);
    End;
    $0A: Begin Mnemonic := 'movz'; Operands := MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt); End;
    $0B: Begin Mnemonic := 'movn'; Operands := MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt); End;
    $0C: Begin
     Mnemonic := 'syscall';
     Code := (Instr Shr 6) And $FFFFF;
     If Code <> 0 Then Operands := '0x' + ToHexU(Code);
    End;
    $0D: Begin
     Mnemonic := 'break';
     Code := (Instr Shr 6) And $FFFFF;
     If Code <> 0 Then Operands := '0x' + ToHexU(Code);
    End;
    $0F: Mnemonic := 'sync';
    $10: Begin Mnemonic := 'mfhi'; Operands := MipsReg(Rd); End;
    $11: Begin Mnemonic := 'mthi'; Operands := MipsReg(Rs); End;
    $12: Begin Mnemonic := 'mflo'; Operands := MipsReg(Rd); End;
    $13: Begin Mnemonic := 'mtlo'; Operands := MipsReg(Rs); End;
    $18: Begin Mnemonic := 'mult'; Operands := MipsReg(Rs) + ',' + MipsReg(Rt); End;
    $19: Begin Mnemonic := 'multu'; Operands := MipsReg(Rs) + ',' + MipsReg(Rt); End;
    $1A: Begin Mnemonic := 'div'; Operands := MipsReg(Rs) + ',' + MipsReg(Rt); End;
    $1B: Begin Mnemonic := 'divu'; Operands := MipsReg(Rs) + ',' + MipsReg(Rt); End;
    $20: Begin Mnemonic := 'add'; Operands := MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt); End;
    $21: Begin
     If Rt = 0 Then Begin Mnemonic := 'move'; Operands := MipsReg(Rd) + ',' + MipsReg(Rs); End
     Else Begin Mnemonic := 'addu'; Operands := MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt); End;
    End;
    $22: Begin Mnemonic := 'sub'; Operands := MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt); End;
    $23: Begin Mnemonic := 'subu'; Operands := MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt); End;
    $24: Begin Mnemonic := 'and'; Operands := MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt); End;
    $25: Begin
     If Rs = 0 Then Begin Mnemonic := 'move'; Operands := MipsReg(Rd) + ',' + MipsReg(Rt); End
     Else Begin Mnemonic := 'or'; Operands := MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt); End;
    End;
    $26: Begin Mnemonic := 'xor'; Operands := MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt); End;
    $27: Begin Mnemonic := 'nor'; Operands := MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt); End;
    $2A: Begin Mnemonic := 'slt'; Operands := MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt); End;
    $2B: Begin Mnemonic := 'sltu'; Operands := MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt); End;
   End;
  End;
  $01: Begin { REGIMM }
   Target := VAddrBase + 4 + SImm * 4;
   Case Rt Of
    $00: Mnemonic := 'bltz';
    $01: Mnemonic := 'bgez';
    $02: Mnemonic := 'bltzl';
    $03: Mnemonic := 'bgezl';
    $10: Mnemonic := 'bltzal';
    $11: Mnemonic := 'bgezal';
    $12: Mnemonic := 'bltzall';
    $13: Mnemonic := 'bgezall';
   End;
   If Mnemonic <> '(bad)' Then
    Operands := MipsReg(Rs) + ',0x' + ToHexFixed(Target, 8);
  End;
  $02, $03: Begin
   Target := ((VAddrBase + 4) And LongInt($F0000000)) Or
             ((Instr And $03FFFFFF) Shl 2);
   If Op = $02 Then Mnemonic := 'j' Else Mnemonic := 'jal';
   Operands := '0x' + ToHexFixed(Target, 8);
  End;
  $04, $05, $06, $07, $14, $15, $16, $17: Begin
   Target := VAddrBase + 4 + SImm * 4;
   Case Op Of
    $04: Mnemonic := 'beq'; $05: Mnemonic := 'bne';
    $06: Mnemonic := 'blez'; $07: Mnemonic := 'bgtz';
    $14: Mnemonic := 'beql'; $15: Mnemonic := 'bnel';
    $16: Mnemonic := 'blezl'; $17: Mnemonic := 'bgtzl';
   End;
   If Op In [$06, $07, $16, $17] Then
    Operands := MipsReg(Rs) + ',0x' + ToHexFixed(Target, 8)
   Else
    Operands := MipsReg(Rs) + ',' + MipsReg(Rt) + ',0x' + ToHexFixed(Target, 8);
  End;
  $08, $09: Begin
   If Op = $08 Then Mnemonic := 'addi' Else Mnemonic := 'addiu';
   ImmText := ToHexSignedDisp(SImm);
   If SImm = 0 Then ImmText := '0';
   Operands := MipsReg(Rt) + ',' + MipsReg(Rs) + ',' + ImmText;
  End;
  $0A, $0B: Begin
   If Op = $0A Then Mnemonic := 'slti' Else Mnemonic := 'sltiu';
   ImmText := ToHexSignedDisp(SImm);
   If SImm = 0 Then ImmText := '0';
   Operands := MipsReg(Rt) + ',' + MipsReg(Rs) + ',' + ImmText;
  End;
  $0C, $0D, $0E: Begin
   Case Op Of $0C: Mnemonic := 'andi'; $0D: Mnemonic := 'ori'; $0E: Mnemonic := 'xori'; End;
   Operands := MipsReg(Rt) + ',' + MipsReg(Rs) + ',0x' + ToHexFixed(Imm, 4);
  End;
  $0F: Begin Mnemonic := 'lui'; Operands := MipsReg(Rt) + ',0x' + ToHexFixed(Imm, 4); End;
  $10: Begin { COP0 }
   Case Rs Of
    $00: Begin Mnemonic := 'mfc0'; Operands := MipsReg(Rt) + ',$' + IntToStr(Rd); End;
    $04: Begin Mnemonic := 'mtc0'; Operands := MipsReg(Rt) + ',$' + IntToStr(Rd); End;
    $10: If Funct = $18 Then Mnemonic := 'eret'
         Else If Funct = $01 Then Mnemonic := 'tlbr'
         Else If Funct = $02 Then Mnemonic := 'tlbwi'
         Else If Funct = $06 Then Mnemonic := 'tlbwr'
         Else If Funct = $08 Then Mnemonic := 'tlbp';
   End;
  End;
  $1C: Begin { SPECIAL2 }
   Case Funct Of
    $00: Begin Mnemonic := 'madd'; Operands := MipsReg(Rs) + ',' + MipsReg(Rt); End;
    $01: Begin Mnemonic := 'maddu'; Operands := MipsReg(Rs) + ',' + MipsReg(Rt); End;
    $02: Begin Mnemonic := 'mul'; Operands := MipsReg(Rd) + ',' + MipsReg(Rs) + ',' + MipsReg(Rt); End;
    $04: Begin Mnemonic := 'msub'; Operands := MipsReg(Rs) + ',' + MipsReg(Rt); End;
    $05: Begin Mnemonic := 'msubu'; Operands := MipsReg(Rs) + ',' + MipsReg(Rt); End;
    $20: Begin Mnemonic := 'clz'; Operands := MipsReg(Rd) + ',' + MipsReg(Rs); End;
    $21: Begin Mnemonic := 'clo'; Operands := MipsReg(Rd) + ',' + MipsReg(Rs); End;
   End;
  End;
  $20..$3F: Begin
   Mnemonic := LoadStoreNames[Op];
   If Mnemonic <> '' Then Begin
    Mem := MipsMem(Imm, Rs);
    If Op In [$2F, $33] Then RegText := IntToStr(Rt)
    Else If Op In [$31, $35, $39, $3D] Then RegText := '$f' + IntToStr(Rt)
    Else If Op In [$32, $36, $3A, $3E] Then RegText := '$c2r' + IntToStr(Rt)
    Else RegText := MipsReg(Rt);
    Operands := RegText + ',' + Mem;
   End Else Mnemonic := '(bad)';
  End;
 End;

 DisasmMipsOne := 4;
End;

{ ============================================================
  DESASSEMBLEUR POWERPC 32 / NOYAU ENTIER POWERPC 64
  ============================================================ }

{ @description: Retourne le nom d un registre general PowerPC. }
Function PpcReg(R: Byte): String;
Begin
 PpcReg := 'r' + IntToStr(R And 31);
End;

{ @description: Etend un immediat PowerPC 16 bits signe. }
Function PpcSign16(V: Word): LongInt;
Begin
 If (V And $8000) <> 0 Then PpcSign16 := LongInt(V) Or LongInt($FFFF0000)
 Else PpcSign16 := V;
End;

{ @description: Formate un entier signe PowerPC en hexadecimal. }
Function PpcSigned(V: LongInt): String;
Begin
 If V < 0 Then PpcSigned := '-0x' + ToHexU(-V)
 Else PpcSigned := '0x' + ToHexU(V);
End;

{ @description: Retourne le nom usuel d un registre special PowerPC. }
Function PpcSprName(Spr: Word): String;
Begin
 Case Spr Of
  1: PpcSprName := 'xer';
  8: PpcSprName := 'lr';
  9: PpcSprName := 'ctr';
  18: PpcSprName := 'dsisr';
  19: PpcSprName := 'dar';
  22: PpcSprName := 'dec';
  25: PpcSprName := 'sdr1';
  26: PpcSprName := 'srr0';
  27: PpcSprName := 'srr1';
 Else
  PpcSprName := IntToStr(Spr);
 End;
End;

{ @description: Desassemble une instruction PowerPC de 32 bits. Couvre
    les formats D/X/XL/XO/M principaux, les branches, les operations
    entieres, CR/SPR, synchronisation et les chargements/stockages.
    Les instructions communes PPC64 ld/std sont egalement reconnues. }
Function DisasmPpcOne(Off, VAddrBase: LongInt;
 Var Mnemonic, Operands: String): Integer;
Const
 DLoadStore: Array[32..55] Of String[5] = (
  'lwz', 'lwzu', 'lbz', 'lbzu', 'stw', 'stwu', 'stb', 'stbu',
  'lhz', 'lhzu', 'lha', 'lhau', 'sth', 'sthu', 'lmw', 'stmw',
  'lfs', 'lfsu', 'lfd', 'lfdu', 'stfs', 'stfsu', 'stfd', 'stfdu');
Var
 Instr, Disp, Target: LongInt;
 Op, Rt, Ra, Rb, Bo, Bi, CrfD, LBit: Byte;
 Imm: Word;
 XO, Spr: Word;
 LK, AA, OE, RcBit: Boolean;
 A, B, D, Suffix: String;
Begin
 If Arch = ARCH_PPCLE Then Instr := GetDWord(Off)
 Else Instr := GetDWordBE(Off);
 Op := (Instr Shr 26) And $3F;
 Rt := (Instr Shr 21) And 31;
 Ra := (Instr Shr 16) And 31;
 Rb := (Instr Shr 11) And 31;
 Imm := Instr And $FFFF;
 Mnemonic := '(bad)';
 Operands := '';

 Case Op Of
  2, 3: Begin
   If Op = 2 Then Mnemonic := 'tdi' Else Mnemonic := 'twi';
   Operands := IntToStr(Rt) + ',' + PpcReg(Ra) + ',' +
    PpcSigned(PpcSign16(Imm));
  End;
  7: Begin Mnemonic := 'mulli'; Operands := PpcReg(Rt) + ',' + PpcReg(Ra) + ',' + PpcSigned(PpcSign16(Imm)); End;
  8: Begin Mnemonic := 'subfic'; Operands := PpcReg(Rt) + ',' + PpcReg(Ra) + ',' + PpcSigned(PpcSign16(Imm)); End;
  10, 11: Begin
   CrfD := (Instr Shr 23) And 7;
   LBit := (Instr Shr 21) And 1;
   If Op = 10 Then Mnemonic := 'cmpli' Else Mnemonic := 'cmpi';
   Operands := IntToStr(CrfD) + ',' + IntToStr(LBit) + ',' +
    PpcReg(Ra) + ',';
   If Op = 10 Then Operands := Operands + '0x' + ToHexFixed(Imm, 4)
   Else Operands := Operands + PpcSigned(PpcSign16(Imm));
  End;
  12, 13: Begin
   If Op = 12 Then Mnemonic := 'addic' Else Mnemonic := 'addic.';
   Operands := PpcReg(Rt) + ',' + PpcReg(Ra) + ',' + PpcSigned(PpcSign16(Imm));
  End;
  14, 15: Begin
   If (Op = 14) And (Ra = 0) Then Begin
    Mnemonic := 'li';
    Operands := PpcReg(Rt) + ',' + PpcSigned(PpcSign16(Imm));
   End Else If (Op = 15) And (Ra = 0) Then Begin
    Mnemonic := 'lis';
    Operands := PpcReg(Rt) + ',0x' + ToHexFixed(Imm, 4);
   End Else Begin
    If Op = 14 Then Mnemonic := 'addi' Else Mnemonic := 'addis';
    Operands := PpcReg(Rt) + ',' + PpcReg(Ra) + ',' + PpcSigned(PpcSign16(Imm));
   End;
  End;
  16: Begin { bc }
   Bo := (Instr Shr 21) And 31;
   Bi := (Instr Shr 16) And 31;
   Disp := Instr And $FFFC;
   If (Disp And $8000) <> 0 Then Disp := Disp Or LongInt($FFFF0000);
   AA := (Instr And 2) <> 0;
   LK := (Instr And 1) <> 0;
   If AA Then Target := Disp Else Target := VAddrBase + Disp;
   If Bo = 20 Then Begin
    Mnemonic := 'b';
    Operands := '0x' + ToHexFixed(Target, 8);
   End Else Begin
    Mnemonic := 'bc';
    Operands := IntToStr(Bo) + ',' + IntToStr(Bi) + ',0x' + ToHexFixed(Target, 8);
   End;
   If LK Then Mnemonic := Mnemonic + 'l';
   If AA Then Mnemonic := Mnemonic + 'a';
  End;
  17: Mnemonic := 'sc';
  18: Begin { b/bl }
   Disp := Instr And $03FFFFFC;
   If (Disp And $02000000) <> 0 Then Disp := Disp Or LongInt($FC000000);
   AA := (Instr And 2) <> 0;
   LK := (Instr And 1) <> 0;
   If AA Then Target := Disp Else Target := VAddrBase + Disp;
   Mnemonic := 'b';
   If LK Then Mnemonic := 'bl';
   If AA Then Mnemonic := Mnemonic + 'a';
   Operands := '0x' + ToHexFixed(Target, 8);
  End;
  19: Begin { XL }
   XO := (Instr Shr 1) And $3FF;
   LK := (Instr And 1) <> 0;
   Bo := (Instr Shr 21) And 31;
   Bi := (Instr Shr 16) And 31;
   Case XO Of
    0: Begin Mnemonic := 'mcrf'; Operands := IntToStr((Instr Shr 23) And 7) + ',' + IntToStr((Instr Shr 18) And 7); End;
    16: Begin
     If (Bo = 20) And (Bi = 0) Then Begin
      If LK Then Mnemonic := 'blrl' Else Mnemonic := 'blr';
     End Else Begin
      Mnemonic := 'bclr'; If LK Then Mnemonic := 'bclrl';
      Operands := IntToStr(Bo) + ',' + IntToStr(Bi);
     End;
    End;
    33: Mnemonic := 'crnor';
    50: Mnemonic := 'rfi';
    129: Mnemonic := 'crandc';
    150: Mnemonic := 'isync';
    193: Mnemonic := 'crxor';
    225: Mnemonic := 'crnand';
    257: Mnemonic := 'crand';
    289: Mnemonic := 'creqv';
    417: Mnemonic := 'crorc';
    449: Mnemonic := 'cror';
    528: Begin
     If (Bo = 20) And (Bi = 0) Then Begin
      If LK Then Mnemonic := 'bctrl' Else Mnemonic := 'bctr';
     End Else Begin
      Mnemonic := 'bcctr'; If LK Then Mnemonic := 'bcctrl';
      Operands := IntToStr(Bo) + ',' + IntToStr(Bi);
     End;
    End;
   End;
   If (Mnemonic <> '(bad)') And
      ((XO = 33) Or (XO = 129) Or (XO = 193) Or (XO = 225) Or
       (XO = 257) Or (XO = 289) Or (XO = 417) Or (XO = 449)) Then
    Operands := IntToStr((Instr Shr 21) And 31) + ',' +
     IntToStr((Instr Shr 16) And 31) + ',' + IntToStr((Instr Shr 11) And 31);
  End;
  20, 21, 23: Begin
   If Op = 20 Then Mnemonic := 'rlwimi'
   Else If Op = 21 Then Mnemonic := 'rlwinm'
   Else Mnemonic := 'rlwnm';
   If Op = 23 Then B := PpcReg(Rb) Else B := IntToStr(Rb);
   Operands := PpcReg(Ra) + ',' + PpcReg(Rt) + ',' + B + ',' +
    IntToStr((Instr Shr 6) And 31) + ',' + IntToStr((Instr Shr 1) And 31);
   If (Instr And 1) <> 0 Then Mnemonic := Mnemonic + '.';
  End;
  24, 25, 26, 27, 28, 29: Begin
   Case Op Of
    24: Mnemonic := 'ori'; 25: Mnemonic := 'oris';
    26: Mnemonic := 'xori'; 27: Mnemonic := 'xoris';
    28: Mnemonic := 'andi.'; 29: Mnemonic := 'andis.';
   End;
   If (Op = 24) And (Rt = 0) And (Ra = 0) And (Imm = 0) Then
    Mnemonic := 'nop'
   Else Operands := PpcReg(Ra) + ',' + PpcReg(Rt) + ',0x' + ToHexFixed(Imm, 4);
  End;
  31: Begin { X/XO }
   XO := (Instr Shr 1) And $3FF;
   OE := (Instr And $400) <> 0;
   RcBit := (Instr And 1) <> 0;
   If (XO = 520) Or (XO = 522) Or (XO = 552) Or (XO = 616) Or
      (XO = 648) Or (XO = 650) Or (XO = 712) Or (XO = 714) Or
      (XO = 744) Or (XO = 746) Or (XO = 747) Or (XO = 778) Or
      (XO = 971) Or (XO = 1003) Then
    XO := XO - 512; { bit OE separe du XO pour les formes arithmetiques }
   A := PpcReg(Ra); B := PpcReg(Rb); D := PpcReg(Rt);
   Suffix := ''; If OE Then Suffix := 'o'; If RcBit Then Suffix := Suffix + '.';
   Case XO Of
    0, 32: Begin
     If XO = 0 Then Mnemonic := 'cmp' Else Mnemonic := 'cmpl';
     Operands := IntToStr((Instr Shr 23) And 7) + ',' +
      IntToStr((Instr Shr 21) And 1) + ',' + A + ',' + B;
    End;
    4: Begin Mnemonic := 'tw'; Operands := IntToStr(Rt) + ',' + A + ',' + B; End;
    8: Begin Mnemonic := 'subfc' + Suffix; Operands := D + ',' + A + ',' + B; End;
    10: Begin Mnemonic := 'addc' + Suffix; Operands := D + ',' + A + ',' + B; End;
    11: Begin Mnemonic := 'mulhwu'; Operands := D + ',' + A + ',' + B; End;
    19: Begin Mnemonic := 'mfcr'; Operands := D; End;
    20: Begin Mnemonic := 'lwarx'; Operands := D + ',' + A + ',' + B; End;
    23: Begin Mnemonic := 'lwzx'; Operands := D + ',' + A + ',' + B; End;
    24: Begin Mnemonic := 'slw'; Operands := D + ',' + A + ',' + B; End;
    26: Begin Mnemonic := 'cntlzw'; Operands := D + ',' + A; End;
    28: Begin Mnemonic := 'and'; Operands := A + ',' + D + ',' + B; If RcBit Then Mnemonic := Mnemonic + '.'; End;
    40: Begin Mnemonic := 'subf' + Suffix; Operands := D + ',' + A + ',' + B; End;
    54: Mnemonic := 'dcbst';
    55: Begin Mnemonic := 'lwzux'; Operands := D + ',' + A + ',' + B; End;
    60: Begin Mnemonic := 'andc'; Operands := A + ',' + D + ',' + B; If RcBit Then Mnemonic := Mnemonic + '.'; End;
    75: Begin Mnemonic := 'mulhw'; Operands := D + ',' + A + ',' + B; End;
    83: Begin Mnemonic := 'mfmsr'; Operands := D; End;
    86: Mnemonic := 'dcbf';
    87: Begin Mnemonic := 'lbzx'; Operands := D + ',' + A + ',' + B; End;
    104: Begin Mnemonic := 'neg' + Suffix; Operands := D + ',' + A; End;
    124: Begin Mnemonic := 'nor'; Operands := A + ',' + D + ',' + B; If RcBit Then Mnemonic := Mnemonic + '.'; End;
    136: Begin Mnemonic := 'subfe' + Suffix; Operands := D + ',' + A + ',' + B; End;
    138: Begin Mnemonic := 'adde' + Suffix; Operands := D + ',' + A + ',' + B; End;
    144: Begin Mnemonic := 'mtcrf'; Operands := '0x' + ToHexFixed((Instr Shr 12) And $FF, 2) + ',' + D; End;
    146: Begin Mnemonic := 'mtmsr'; Operands := D; End;
    150: Begin Mnemonic := 'stwcx.'; Operands := D + ',' + A + ',' + B; End;
    151: Begin Mnemonic := 'stwx'; Operands := D + ',' + A + ',' + B; End;
    183: Begin Mnemonic := 'stwux'; Operands := D + ',' + A + ',' + B; End;
    200: Begin Mnemonic := 'subfze' + Suffix; Operands := D + ',' + A; End;
    202: Begin Mnemonic := 'addze' + Suffix; Operands := D + ',' + A; End;
    215: Begin Mnemonic := 'stbx'; Operands := D + ',' + A + ',' + B; End;
    232: Begin Mnemonic := 'subfme' + Suffix; Operands := D + ',' + A; End;
    234: Begin Mnemonic := 'addme' + Suffix; Operands := D + ',' + A; End;
    235: Begin Mnemonic := 'mullw' + Suffix; Operands := D + ',' + A + ',' + B; End;
    266: Begin Mnemonic := 'add' + Suffix; Operands := D + ',' + A + ',' + B; End;
    278: Mnemonic := 'dcbt';
    279: Begin Mnemonic := 'lhzx'; Operands := D + ',' + A + ',' + B; End;
    284: Begin Mnemonic := 'eqv'; Operands := A + ',' + D + ',' + B; If RcBit Then Mnemonic := Mnemonic + '.'; End;
    311: Begin Mnemonic := 'lhzux'; Operands := D + ',' + A + ',' + B; End;
    316: Begin Mnemonic := 'xor'; Operands := A + ',' + D + ',' + B; If RcBit Then Mnemonic := Mnemonic + '.'; End;
    339: Begin
     Spr := ((Instr Shr 16) And $1F) Or ((Instr Shr 6) And $3E0);
     If Spr = 8 Then Mnemonic := 'mflr'
     Else If Spr = 9 Then Mnemonic := 'mfctr'
     Else Mnemonic := 'mfspr';
     Operands := D;
     If Mnemonic = 'mfspr' Then Operands := Operands + ',' + PpcSprName(Spr);
    End;
    343: Begin Mnemonic := 'lhax'; Operands := D + ',' + A + ',' + B; End;
    371: Begin Mnemonic := 'mftb'; Operands := D; End;
    407: Begin Mnemonic := 'sthx'; Operands := D + ',' + A + ',' + B; End;
    412: Begin Mnemonic := 'orc'; Operands := A + ',' + D + ',' + B; If RcBit Then Mnemonic := Mnemonic + '.'; End;
    439: Begin Mnemonic := 'sthux'; Operands := D + ',' + A + ',' + B; End;
    444: Begin
     If Rb = Rt Then Begin Mnemonic := 'mr'; Operands := A + ',' + D; End
     Else Begin Mnemonic := 'or'; Operands := A + ',' + D + ',' + B; If RcBit Then Mnemonic := Mnemonic + '.'; End;
    End;
    459: Begin Mnemonic := 'divwu' + Suffix; Operands := D + ',' + A + ',' + B; End;
    467: Begin
     Spr := ((Instr Shr 16) And $1F) Or ((Instr Shr 6) And $3E0);
     If Spr = 8 Then Mnemonic := 'mtlr'
     Else If Spr = 9 Then Mnemonic := 'mtctr'
     Else Mnemonic := 'mtspr';
     Operands := D;
     If Mnemonic = 'mtspr' Then Operands := PpcSprName(Spr) + ',' + D;
    End;
    476: Begin Mnemonic := 'nand'; Operands := A + ',' + D + ',' + B; If RcBit Then Mnemonic := Mnemonic + '.'; End;
    491: Begin Mnemonic := 'divw' + Suffix; Operands := D + ',' + A + ',' + B; End;
    534: Begin Mnemonic := 'lwbrx'; Operands := D + ',' + A + ',' + B; End;
    536: Begin Mnemonic := 'srw'; Operands := D + ',' + A + ',' + B; End;
    598: Mnemonic := 'sync';
    662: Begin Mnemonic := 'stwbrx'; Operands := D + ',' + A + ',' + B; End;
    792: Begin Mnemonic := 'sraw'; Operands := D + ',' + A + ',' + B; End;
    824: Begin Mnemonic := 'srawi'; Operands := D + ',' + A + ',' + IntToStr(Rb); End;
    854: Mnemonic := 'eieio';
    922: Begin Mnemonic := 'extsh'; Operands := A + ',' + D; If RcBit Then Mnemonic := Mnemonic + '.'; End;
    954: Begin Mnemonic := 'extsb'; Operands := A + ',' + D; If RcBit Then Mnemonic := Mnemonic + '.'; End;
   End;
   If (Mnemonic = 'dcbst') Or (Mnemonic = 'dcbf') Or
      (Mnemonic = 'dcbt') Then Operands := A + ',' + B;
  End;
  32..55: Begin
   Mnemonic := DLoadStore[Op];
   Operands := PpcReg(Rt) + ',' + PpcSigned(PpcSign16(Imm)) + '(' + PpcReg(Ra) + ')';
  End;
  58, 62: Begin { DS-form PPC64 }
   Disp := Instr And $FFFC;
   If (Disp And $8000) <> 0 Then Disp := Disp Or LongInt($FFFF0000);
   If Op = 58 Then Begin
    Case Instr And 3 Of 0: Mnemonic := 'ld'; 1: Mnemonic := 'ldu'; 2: Mnemonic := 'lwa'; End;
   End Else Begin
    Case Instr And 3 Of 0: Mnemonic := 'std'; 1: Mnemonic := 'stdu'; End;
   End;
   If Mnemonic <> '(bad)' Then
    Operands := PpcReg(Rt) + ',' + PpcSigned(Disp) + '(' + PpcReg(Ra) + ')';
  End;
 End;

 DisasmPpcOne := 4;
End;

{ ============================================================
  DESASSEMBLEUR SUPERH SH-1/SH-2/SH-3/SH-4
  ============================================================ }

{ @description: Retourne le nom d un registre general SuperH. }
Function ShReg(R: Byte): String;
Begin
 ShReg := 'r' + IntToStr(R And 15);
End;

{ @description: Etend un octet signe en LongInt. }
Function ShSign8(V: Byte): LongInt;
Begin
 If (V And $80) <> 0 Then ShSign8 := LongInt(V) Or LongInt($FFFFFF00)
 Else ShSign8 := V;
End;

{ @description: Formate un deplacement signe SuperH. }
Function ShSigned(V: LongInt): String;
Begin
 If V < 0 Then ShSigned := '-0x' + ToHexU(-V)
 Else ShSigned := '0x' + ToHexU(V);
End;

{ @description: Desassemble une instruction SuperH de 16 bits. Le
    noyau SH-1/SH-2 est couvert, avec les registres de controle SH-3,
    SHAD/SHLD et les operations flottantes SH-4 les plus courantes.
    Les branchements et chargements PC-relatifs utilisent PC+4. }
Function DisasmShOne(Off, VAddrBase: LongInt;
 Var Mnemonic, Operands: String): Integer;
Var
 Instr: Word;
 Top, N, M, Low: Byte;
 Disp, Target: LongInt;
 Imm8: Byte;
 Rn, Rm: String;
Begin
 If Arch = ARCH_SHLE Then Instr := GetWord(Off)
 Else Instr := GetWordBE(Off);
 Top := Instr Shr 12;
 N := (Instr Shr 8) And 15;
 M := (Instr Shr 4) And 15;
 Low := Instr And 15;
 Imm8 := Instr And $FF;
 Rn := ShReg(N);
 Rm := ShReg(M);
 Mnemonic := '(bad)';
 Operands := '';

 Case Top Of
  $0: Begin
   Case Low Of
    $2: Begin
     Mnemonic := 'stc';
     Case M Of
      0: Operands := 'sr,' + Rn;
      1: Operands := 'gbr,' + Rn;
      2: Operands := 'vbr,' + Rn;
      3: Operands := 'ssr,' + Rn;
      4: Operands := 'spc,' + Rn;
     Else Mnemonic := '(bad)';
     End;
    End;
    $3: Begin
     If M = 0 Then Begin Mnemonic := 'bsrf'; Operands := Rn; End
     Else If M = 2 Then Begin Mnemonic := 'braf'; Operands := Rn; End;
    End;
    $4: Begin Mnemonic := 'mov.b'; Operands := Rm + ',@(r0,' + Rn + ')'; End;
    $5: Begin Mnemonic := 'mov.w'; Operands := Rm + ',@(r0,' + Rn + ')'; End;
    $6: Begin Mnemonic := 'mov.l'; Operands := Rm + ',@(r0,' + Rn + ')'; End;
    $7: Begin Mnemonic := 'mul.l'; Operands := Rm + ',' + Rn; End;
    $8: Case (Instr Shr 4) And $FF Of
     $00: Mnemonic := 'clrt';
     $01: Mnemonic := 'sett';
     $02: Mnemonic := 'clrmac';
     $03: Mnemonic := 'ldtlb';
     $04: Mnemonic := 'clrs';
     $05: Mnemonic := 'sets';
    End;
    $9: Case (Instr Shr 4) And $FF Of
     $00: Mnemonic := 'nop';
     $01: Mnemonic := 'div0u';
     $02: Begin Mnemonic := 'movt'; Operands := Rn; End;
    End;
    $A: Begin
     Mnemonic := 'sts';
     Case M Of
      0: Operands := 'mach,' + Rn;
      1: Operands := 'macl,' + Rn;
      2: Operands := 'pr,' + Rn;
      5: Operands := 'fpul,' + Rn;
      6: Operands := 'fpscr,' + Rn;
     Else Mnemonic := '(bad)';
     End;
    End;
    $B: Case (Instr Shr 4) And $FF Of
     $00: Mnemonic := 'rts';
     $01: Mnemonic := 'sleep';
     $02: Mnemonic := 'rte';
    End;
    $C: Begin Mnemonic := 'mov.b'; Operands := '@(r0,' + Rm + '),' + Rn; End;
    $D: Begin Mnemonic := 'mov.w'; Operands := '@(r0,' + Rm + '),' + Rn; End;
    $E: Begin Mnemonic := 'mov.l'; Operands := '@(r0,' + Rm + '),' + Rn; End;
    $F: Begin Mnemonic := 'mac.l'; Operands := '@' + Rm + '+,@' + Rn + '+'; End;
   End;
  End;
  $1: Begin
   Mnemonic := 'mov.l';
   Operands := Rm + ',@(' + IntToStr(Low * 4) + ',' + Rn + ')';
  End;
  $2: Case Low Of
   $0: Begin Mnemonic := 'mov.b'; Operands := Rm + ',@' + Rn; End;
   $1: Begin Mnemonic := 'mov.w'; Operands := Rm + ',@' + Rn; End;
   $2: Begin Mnemonic := 'mov.l'; Operands := Rm + ',@' + Rn; End;
   $4: Begin Mnemonic := 'mov.b'; Operands := Rm + ',@-' + Rn; End;
   $5: Begin Mnemonic := 'mov.w'; Operands := Rm + ',@-' + Rn; End;
   $6: Begin Mnemonic := 'mov.l'; Operands := Rm + ',@-' + Rn; End;
   $7: Begin Mnemonic := 'div0s'; Operands := Rm + ',' + Rn; End;
   $8: Begin Mnemonic := 'tst'; Operands := Rm + ',' + Rn; End;
   $9: Begin Mnemonic := 'and'; Operands := Rm + ',' + Rn; End;
   $A: Begin Mnemonic := 'xor'; Operands := Rm + ',' + Rn; End;
   $B: Begin Mnemonic := 'or'; Operands := Rm + ',' + Rn; End;
   $C: Begin Mnemonic := 'cmp/str'; Operands := Rm + ',' + Rn; End;
   $D: Begin Mnemonic := 'xtrct'; Operands := Rm + ',' + Rn; End;
   $E: Begin Mnemonic := 'mulu.w'; Operands := Rm + ',' + Rn; End;
   $F: Begin Mnemonic := 'muls.w'; Operands := Rm + ',' + Rn; End;
  End;
  $3: Case Low Of
   $0: Begin Mnemonic := 'cmp/eq'; Operands := Rm + ',' + Rn; End;
   $2: Begin Mnemonic := 'cmp/hs'; Operands := Rm + ',' + Rn; End;
   $3: Begin Mnemonic := 'cmp/ge'; Operands := Rm + ',' + Rn; End;
   $4: Begin Mnemonic := 'div1'; Operands := Rm + ',' + Rn; End;
   $5: Begin Mnemonic := 'dmulu.l'; Operands := Rm + ',' + Rn; End;
   $6: Begin Mnemonic := 'cmp/hi'; Operands := Rm + ',' + Rn; End;
   $7: Begin Mnemonic := 'cmp/gt'; Operands := Rm + ',' + Rn; End;
   $8: Begin Mnemonic := 'sub'; Operands := Rm + ',' + Rn; End;
   $A: Begin Mnemonic := 'subc'; Operands := Rm + ',' + Rn; End;
   $B: Begin Mnemonic := 'subv'; Operands := Rm + ',' + Rn; End;
   $C: Begin Mnemonic := 'add'; Operands := Rm + ',' + Rn; End;
   $D: Begin Mnemonic := 'dmuls.l'; Operands := Rm + ',' + Rn; End;
   $E: Begin Mnemonic := 'addc'; Operands := Rm + ',' + Rn; End;
   $F: Begin Mnemonic := 'addv'; Operands := Rm + ',' + Rn; End;
  End;
  $4: Begin
   Case Instr And $FF Of
    $00: Begin Mnemonic := 'shll'; Operands := Rn; End;
    $01: Begin Mnemonic := 'shlr'; Operands := Rn; End;
    $02: Begin Mnemonic := 'sts.l'; Operands := 'mach,@-' + Rn; End;
    $03: Begin Mnemonic := 'stc.l'; Operands := 'sr,@-' + Rn; End;
    $04: Begin Mnemonic := 'rotl'; Operands := Rn; End;
    $05: Begin Mnemonic := 'rotr'; Operands := Rn; End;
    $06: Begin Mnemonic := 'lds.l'; Operands := '@' + Rn + '+,mach'; End;
    $07: Begin Mnemonic := 'ldc.l'; Operands := '@' + Rn + '+,sr'; End;
    $08: Begin Mnemonic := 'shll2'; Operands := Rn; End;
    $09: Begin Mnemonic := 'shlr2'; Operands := Rn; End;
    $0A: Begin Mnemonic := 'lds'; Operands := Rn + ',mach'; End;
    $0B: Begin Mnemonic := 'jsr'; Operands := '@' + Rn; End;
    $0E: Begin Mnemonic := 'ldc'; Operands := Rn + ',sr'; End;
    $10: Begin Mnemonic := 'dt'; Operands := Rn; End;
    $11: Begin Mnemonic := 'cmp/pz'; Operands := Rn; End;
    $12: Begin Mnemonic := 'sts.l'; Operands := 'macl,@-' + Rn; End;
    $13: Begin Mnemonic := 'stc.l'; Operands := 'gbr,@-' + Rn; End;
    $15: Begin Mnemonic := 'cmp/pl'; Operands := Rn; End;
    $16: Begin Mnemonic := 'lds.l'; Operands := '@' + Rn + '+,macl'; End;
    $17: Begin Mnemonic := 'ldc.l'; Operands := '@' + Rn + '+,gbr'; End;
    $18: Begin Mnemonic := 'shll8'; Operands := Rn; End;
    $19: Begin Mnemonic := 'shlr8'; Operands := Rn; End;
    $1A: Begin Mnemonic := 'lds'; Operands := Rn + ',macl'; End;
    $1B: Begin Mnemonic := 'tas.b'; Operands := '@' + Rn; End;
    $1E: Begin Mnemonic := 'ldc'; Operands := Rn + ',gbr'; End;
    $20: Begin Mnemonic := 'shal'; Operands := Rn; End;
    $21: Begin Mnemonic := 'shar'; Operands := Rn; End;
    $22: Begin Mnemonic := 'sts.l'; Operands := 'pr,@-' + Rn; End;
    $23: Begin Mnemonic := 'stc.l'; Operands := 'vbr,@-' + Rn; End;
    $24: Begin Mnemonic := 'rotcl'; Operands := Rn; End;
    $25: Begin Mnemonic := 'rotcr'; Operands := Rn; End;
    $26: Begin Mnemonic := 'lds.l'; Operands := '@' + Rn + '+,pr'; End;
    $27: Begin Mnemonic := 'ldc.l'; Operands := '@' + Rn + '+,vbr'; End;
    $28: Begin Mnemonic := 'shll16'; Operands := Rn; End;
    $29: Begin Mnemonic := 'shlr16'; Operands := Rn; End;
    $2A: Begin Mnemonic := 'lds'; Operands := Rn + ',pr'; End;
    $2B: Begin Mnemonic := 'jmp'; Operands := '@' + Rn; End;
    $2E: Begin Mnemonic := 'ldc'; Operands := Rn + ',vbr'; End;
    $32: Begin Mnemonic := 'stc.l'; Operands := 'sgr,@-' + Rn; End;
    $33: Begin Mnemonic := 'stc.l'; Operands := 'ssr,@-' + Rn; End;
    $37: Begin Mnemonic := 'ldc.l'; Operands := '@' + Rn + '+,ssr'; End;
    $3E: Begin Mnemonic := 'ldc'; Operands := Rn + ',ssr'; End;
    $43: Begin Mnemonic := 'stc.l'; Operands := 'spc,@-' + Rn; End;
    $47: Begin Mnemonic := 'ldc.l'; Operands := '@' + Rn + '+,spc'; End;
    $4E: Begin Mnemonic := 'ldc'; Operands := Rn + ',spc'; End;
    $52: Begin Mnemonic := 'sts.l'; Operands := 'fpul,@-' + Rn; End;
    $56: Begin Mnemonic := 'lds.l'; Operands := '@' + Rn + '+,fpul'; End;
    $5A: Begin Mnemonic := 'lds'; Operands := Rn + ',fpul'; End;
    $62: Begin Mnemonic := 'sts.l'; Operands := 'fpscr,@-' + Rn; End;
    $66: Begin Mnemonic := 'lds.l'; Operands := '@' + Rn + '+,fpscr'; End;
    $6A: Begin Mnemonic := 'lds'; Operands := Rn + ',fpscr'; End;
   End;
   If (Instr And $F00F) = $400C Then Begin
    Mnemonic := 'shad'; Operands := Rm + ',' + Rn;
   End Else If (Instr And $F00F) = $400D Then Begin
    Mnemonic := 'shld'; Operands := Rm + ',' + Rn;
   End Else If (Instr And $F00F) = $400F Then Begin
    Mnemonic := 'mac.w'; Operands := '@' + Rm + '+,@' + Rn + '+';
   End;
  End;
  $5: Begin
   Mnemonic := 'mov.l';
   Operands := '@(' + IntToStr(Low * 4) + ',' + Rm + '),' + Rn;
  End;
  $6: Case Low Of
   $0: Begin Mnemonic := 'mov.b'; Operands := '@' + Rm + ',' + Rn; End;
   $1: Begin Mnemonic := 'mov.w'; Operands := '@' + Rm + ',' + Rn; End;
   $2: Begin Mnemonic := 'mov.l'; Operands := '@' + Rm + ',' + Rn; End;
   $3: Begin Mnemonic := 'mov'; Operands := Rm + ',' + Rn; End;
   $4: Begin Mnemonic := 'mov.b'; Operands := '@' + Rm + '+,' + Rn; End;
   $5: Begin Mnemonic := 'mov.w'; Operands := '@' + Rm + '+,' + Rn; End;
   $6: Begin Mnemonic := 'mov.l'; Operands := '@' + Rm + '+,' + Rn; End;
   $7: Begin Mnemonic := 'not'; Operands := Rm + ',' + Rn; End;
   $8: Begin Mnemonic := 'swap.b'; Operands := Rm + ',' + Rn; End;
   $9: Begin Mnemonic := 'swap.w'; Operands := Rm + ',' + Rn; End;
   $A: Begin Mnemonic := 'negc'; Operands := Rm + ',' + Rn; End;
   $B: Begin Mnemonic := 'neg'; Operands := Rm + ',' + Rn; End;
   $C: Begin Mnemonic := 'extu.b'; Operands := Rm + ',' + Rn; End;
   $D: Begin Mnemonic := 'extu.w'; Operands := Rm + ',' + Rn; End;
   $E: Begin Mnemonic := 'exts.b'; Operands := Rm + ',' + Rn; End;
   $F: Begin Mnemonic := 'exts.w'; Operands := Rm + ',' + Rn; End;
  End;
  $7: Begin
   Mnemonic := 'add';
   Operands := '#' + ShSigned(ShSign8(Imm8)) + ',' + Rn;
  End;
  $8: Begin
   Case (Instr Shr 8) And $F Of
    $0: Begin Mnemonic := 'mov.b'; Operands := 'r0,@(' + IntToStr(Instr And 15) + ',' + Rm + ')'; End;
    $1: Begin Mnemonic := 'mov.w'; Operands := 'r0,@(' + IntToStr((Instr And 15) * 2) + ',' + Rm + ')'; End;
    $4: Begin Mnemonic := 'mov.b'; Operands := '@(' + IntToStr(Instr And 15) + ',' + Rm + '),r0'; End;
    $5: Begin Mnemonic := 'mov.w'; Operands := '@(' + IntToStr((Instr And 15) * 2) + ',' + Rm + '),r0'; End;
    $8: Begin Mnemonic := 'cmp/eq'; Operands := '#0x' + ToHexFixed(Imm8, 2) + ',r0'; End;
    $9, $B, $D, $F: Begin
     Disp := ShSign8(Imm8) * 2;
     Target := VAddrBase + 4 + Disp;
     Case (Instr Shr 8) And $F Of
      $9: Mnemonic := 'bt';
      $B: Mnemonic := 'bf';
      $D: Mnemonic := 'bt/s';
      $F: Mnemonic := 'bf/s';
     End;
     Operands := '0x' + ToHexFixed(Target, 8);
    End;
   End;
  End;
  $9: Begin
   Target := VAddrBase + 4 + Imm8 * 2;
   Mnemonic := 'mov.w';
   Operands := '@(0x' + ToHexFixed(Target, 8) + ',pc),' + Rn;
  End;
  $A, $B: Begin
   Disp := Instr And $0FFF;
   If (Disp And $0800) <> 0 Then Disp := Disp Or LongInt($FFFFF000);
   Target := VAddrBase + 4 + Disp * 2;
   If Top = $A Then Mnemonic := 'bra' Else Mnemonic := 'bsr';
   Operands := '0x' + ToHexFixed(Target, 8);
  End;
  $C: Case (Instr Shr 8) And 15 Of
   $0: Begin Mnemonic := 'mov.b'; Operands := 'r0,@(' + IntToStr(Imm8) + ',gbr)'; End;
   $1: Begin Mnemonic := 'mov.w'; Operands := 'r0,@(' + IntToStr(Imm8 * 2) + ',gbr)'; End;
   $2: Begin Mnemonic := 'mov.l'; Operands := 'r0,@(' + IntToStr(Imm8 * 4) + ',gbr)'; End;
   $3: Begin Mnemonic := 'trapa'; Operands := '#0x' + ToHexFixed(Imm8, 2); End;
   $4: Begin Mnemonic := 'mov.b'; Operands := '@(' + IntToStr(Imm8) + ',gbr),r0'; End;
   $5: Begin Mnemonic := 'mov.w'; Operands := '@(' + IntToStr(Imm8 * 2) + ',gbr),r0'; End;
   $6: Begin Mnemonic := 'mov.l'; Operands := '@(' + IntToStr(Imm8 * 4) + ',gbr),r0'; End;
   $7: Begin
    Target := ((VAddrBase + 4) And LongInt($FFFFFFFC)) + Imm8 * 4;
    Mnemonic := 'mova'; Operands := '@(0x' + ToHexFixed(Target, 8) + ',pc),r0';
   End;
   $8: Begin Mnemonic := 'tst'; Operands := '#0x' + ToHexFixed(Imm8, 2) + ',r0'; End;
   $9: Begin Mnemonic := 'and'; Operands := '#0x' + ToHexFixed(Imm8, 2) + ',r0'; End;
   $A: Begin Mnemonic := 'xor'; Operands := '#0x' + ToHexFixed(Imm8, 2) + ',r0'; End;
   $B: Begin Mnemonic := 'or'; Operands := '#0x' + ToHexFixed(Imm8, 2) + ',r0'; End;
   $C: Begin Mnemonic := 'tst.b'; Operands := '#0x' + ToHexFixed(Imm8, 2) + ',@(r0,gbr)'; End;
   $D: Begin Mnemonic := 'and.b'; Operands := '#0x' + ToHexFixed(Imm8, 2) + ',@(r0,gbr)'; End;
   $E: Begin Mnemonic := 'xor.b'; Operands := '#0x' + ToHexFixed(Imm8, 2) + ',@(r0,gbr)'; End;
   $F: Begin Mnemonic := 'or.b'; Operands := '#0x' + ToHexFixed(Imm8, 2) + ',@(r0,gbr)'; End;
  End;
  $D: Begin
   Target := ((VAddrBase + 4) And LongInt($FFFFFFFC)) + Imm8 * 4;
   Mnemonic := 'mov.l';
   Operands := '@(0x' + ToHexFixed(Target, 8) + ',pc),' + Rn;
  End;
  $E: Begin
   Mnemonic := 'mov';
   Operands := '#' + ShSigned(ShSign8(Imm8)) + ',' + Rn;
  End;
  $F: Case Low Of
   $0: Begin Mnemonic := 'fadd'; Operands := 'fr' + IntToStr(M) + ',fr' + IntToStr(N); End;
   $1: Begin Mnemonic := 'fsub'; Operands := 'fr' + IntToStr(M) + ',fr' + IntToStr(N); End;
   $2: Begin Mnemonic := 'fmul'; Operands := 'fr' + IntToStr(M) + ',fr' + IntToStr(N); End;
   $3: Begin Mnemonic := 'fdiv'; Operands := 'fr' + IntToStr(M) + ',fr' + IntToStr(N); End;
   $4: Begin Mnemonic := 'fcmp/eq'; Operands := 'fr' + IntToStr(M) + ',fr' + IntToStr(N); End;
   $5: Begin Mnemonic := 'fcmp/gt'; Operands := 'fr' + IntToStr(M) + ',fr' + IntToStr(N); End;
   $6: Begin Mnemonic := 'fmov.s'; Operands := '@(r0,' + Rm + '),fr' + IntToStr(N); End;
   $7: Begin Mnemonic := 'fmov.s'; Operands := 'fr' + IntToStr(M) + ',@(r0,' + Rn + ')'; End;
   $8: Begin Mnemonic := 'fmov.s'; Operands := '@' + Rm + ',fr' + IntToStr(N); End;
   $9: Begin Mnemonic := 'fmov.s'; Operands := '@' + Rm + '+,fr' + IntToStr(N); End;
   $A: Begin Mnemonic := 'fmov.s'; Operands := 'fr' + IntToStr(M) + ',@' + Rn; End;
   $B: Begin Mnemonic := 'fmov.s'; Operands := 'fr' + IntToStr(M) + ',@-' + Rn; End;
   $C: Begin Mnemonic := 'fmov'; Operands := 'fr' + IntToStr(M) + ',fr' + IntToStr(N); End;
   $D: Case M Of
    $0: Begin Mnemonic := 'fsts'; Operands := 'fpul,fr' + IntToStr(N); End;
    $1: Begin Mnemonic := 'flds'; Operands := 'fr' + IntToStr(N) + ',fpul'; End;
    $2: Begin Mnemonic := 'float'; Operands := 'fpul,fr' + IntToStr(N); End;
    $3: Begin Mnemonic := 'ftrc'; Operands := 'fr' + IntToStr(N) + ',fpul'; End;
    $4: Begin Mnemonic := 'fneg'; Operands := 'fr' + IntToStr(N); End;
    $5: Begin Mnemonic := 'fabs'; Operands := 'fr' + IntToStr(N); End;
    $6: Begin Mnemonic := 'fsqrt'; Operands := 'fr' + IntToStr(N); End;
    $8: Begin Mnemonic := 'fldi0'; Operands := 'fr' + IntToStr(N); End;
    $9: Begin Mnemonic := 'fldi1'; Operands := 'fr' + IntToStr(N); End;
    $A: Begin Mnemonic := 'fcnvsd'; Operands := 'fpul,dr' + IntToStr(N And $E); End;
    $B: Begin Mnemonic := 'fcnvds'; Operands := 'dr' + IntToStr(N And $E) + ',fpul'; End;
   End;
   $E: Begin Mnemonic := 'fmac'; Operands := 'fr0,fr' + IntToStr(M) + ',fr' + IntToStr(N); End;
  End;
 End;

 DisasmShOne := 2;
End;

{ ============================================================
  DESASSEMBLEUR STRUCTUREL INTEL ITANIUM IA-64
  ============================================================ }

{ @description: Lit un octet d un paquet IA-64 en tenant compte du
    boutisme. Un paquet architectural contient toujours 16 octets. }
Function Ia64BundleByte(Off: LongInt; Index: Integer): Byte;
Begin
 If Arch = ARCH_IA64BE Then Ia64BundleByte := GetByte(Off + 15 - Index)
 Else Ia64BundleByte := GetByte(Off + Index);
End;

{ @description: Extrait un slot IA-64 de 41 bits dans Lo (bits 0..31)
    et Hi (bits 32..40). Slot vaut 0, 1 ou 2. }
Procedure Ia64GetSlot(Off: LongInt; Slot: Integer; Var Lo: LongInt;
 Var Hi: Word);
Var
 StartBit, I, SrcBit, ByteIndex, BitIndex: Integer;
 B: Byte;
Begin
 Lo := 0;
 Hi := 0;
 StartBit := 5 + Slot * 41;
 For I := 0 To 40 Do Begin
  SrcBit := StartBit + I;
  ByteIndex := SrcBit Div 8;
  BitIndex := SrcBit Mod 8;
  B := Ia64BundleByte(Off, ByteIndex);
  If (B And (1 Shl BitIndex)) <> 0 Then Begin
   If I < 32 Then Lo := Lo Or (LongInt(1) Shl I)
   Else Hi := Hi Or (1 Shl (I - 32));
  End;
 End;
End;

{ @description: Retourne le template textuel d un paquet IA-64. Le
    point-virgule indique un arret de groupe d instructions. }
Function Ia64TemplateName(T: Byte): String;
Const
 Names: Array[0..31] Of String[5] = (
  'MII', 'MII;', 'M;II', 'M;II;', 'MLX', 'MLX;', 'res', 'res',
  'MMI', 'MMI;', 'M;MI', 'M;MI;', 'MFI', 'MFI;', 'MMF', 'MMF;',
  'MIB', 'MIB;', 'MBB', 'MBB;', 'res', 'res', 'BBB', 'BBB;',
  'MMB', 'MMB;', 'res', 'res', 'MFB', 'MFB;', 'res', 'res');
Begin
 Ia64TemplateName := Names[T And 31];
End;

{ @description: Retourne le type d unite du slot (M/I/F/B/L/X). }
Function Ia64SlotType(T: Byte; Slot: Integer): Char;
Const
 Types: Array[0..31] Of String[3] = (
  'MII', 'MII', 'MII', 'MII', 'MLX', 'MLX', '???', '???',
  'MMI', 'MMI', 'MMI', 'MMI', 'MFI', 'MFI', 'MMF', 'MMF',
  'MIB', 'MIB', 'MBB', 'MBB', '???', '???', 'BBB', 'BBB',
  'MMB', 'MMB', '???', '???', 'MFB', 'MFB', '???', '???');
Begin
 Ia64SlotType := Types[T And 31][Slot + 1];
End;

{ @description: Formate les 41 bits d un slot en hexadecimal fixe. }
Function Ia64SlotHex(Lo: LongInt; Hi: Word): String;
Begin
 Ia64SlotHex := ToHexFixed(Hi And $1FF, 3) + ToHexFixed(Lo, 8);
End;

{ @description: Desassemble structurellement un paquet IA-64. Le
    template, les trois types d unites, les predicats et les opcodes
    majeurs sont affiches. Les 41 bits bruts de chaque slot sont
    conserves, ce qui permet une inspection fiable meme lorsque le
    mnemonique detaille n est pas encore decode. }
Function DisasmIa64One(Off, VAddrBase: LongInt;
 Var Mnemonic, Operands: String): Integer;
Var
 T, Pred, Major: Byte;
 Slot: Integer;
 Lo: LongInt;
 Hi: Word;
 S, Part: String;
 UnitType: Char;
Begin
 T := Ia64BundleByte(Off, 0) And $1F;
 Mnemonic := 'bundle.' + Ia64TemplateName(T);
 S := '';
 For Slot := 0 To 2 Do Begin
  Ia64GetSlot(Off, Slot, Lo, Hi);
  Pred := Lo And $3F;
  Major := (Hi Shr 5) And $0F;
  UnitType := Ia64SlotType(T, Slot);
  Part := 's' + IntToStr(Slot) + '=' + UnitType +
   '(p' + IntToStr(Pred) + ',op' + ToHexFixed(Major, 1) +
   ',0x' + Ia64SlotHex(Lo, Hi) + ')';
  If S <> '' Then S := S + ' ';
  S := S + Part;
 End;
 Operands := S;
 DisasmIa64One := 16;
End;

{ ============================================================
  DESASSEMBLEUR p-CODE UCSD p-SYSTEM II.0 / II.1
  ============================================================ }

{ @description: Lit un operande BIG du p-Code UCSD. Les valeurs
    inferieures a 128 occupent un octet ; les autres utilisent 14 bits
    sur deux octets en ordre gros-boutiste. }
Function PCodeReadBig(Off: LongInt; Var Used: Integer): LongInt;
Var
 B1, B2: Byte;
Begin
 B1 := GetByte(Off);
 If B1 < 128 Then Begin
  Used := 1;
  PCodeReadBig := B1;
 End Else Begin
  B2 := GetByte(Off + 1);
  Used := 2;
  PCodeReadBig := LongInt(B1 And $7F) * 256 + B2;
 End;
End;

{ @description: Desassemble une instruction du p-Code UCSD p-System.
    La table et les formats d operandes sont partages conceptuellement
    avec DISPCODE.PAS : SLDC, UB/SB, WORD, BIG, niveaux lexicaux,
    chaines LSA, constantes LDC et appels CSP. }
Function DisasmPCodeOne(Off, VAddrBase: LongInt;
 Var Mnemonic, Operands: String): Integer;
Const
 OPK_NONE  = 0; OPK_UB = 1; OPK_SB = 2; OPK_W = 3; OPK_BIG = 4;
 OPK_UBUB  = 5; OPK_UBBIG = 6; OPK_DBBIG = 7; OPK_LSA = 8;
 OPK_LDC   = 9; OPK_XJP = 10;
 Mnem128: Array[128..255] Of String[6] = (
  'ABI','ABR','ADI','ADR','LAND','DIF','DVI','DVR',
  'CHK','FLO','FLT','INN','INT','IOR','MODI','MPI',
  'MPR','NGI','NGR','LNOT','SRS','SBI','SBR','SGS',
  'SQI','SQR','STO','IXS','UNI','LDE','CSP','LDCN',
  'ADJ','FJP','INC','IND','IXA','LAO','LSA','LAE',
  'MOV','LDO','SAS','SRO','XJP','RNP','CIP','EQU',
  'GEQ','GRT','LDA','LDC','LEQ','LES','LOD','NEQ',
  'STR','UJP','LDP','STP','LDM','STM','LDB','STB',
  'IXP','RBP','CBP','EQUI','GEQI','GRTI','LLA','LDCI',
  'LEQI','LESI','LDL','NEQI','STL','CXP','CLP','CGP',
  'LPA','STE','???','EFJ','NFJ','BPT','XIT','NOP',
  'SLDL1','SLDL2','SLDL3','SLDL4','SLDL5','SLDL6','SLDL7','SLDL8',
  'SLDL9','SLDL10','SLDL11','SLDL12','SLDL13','SLDL14','SLDL15','SLDL16',
  'SLDO1','SLDO2','SLDO3','SLDO4','SLDO5','SLDO6','SLDO7','SLDO8',
  'SLDO9','SLDO10','SLDO11','SLDO12','SLDO13','SLDO14','SLDO15','SLDO16',
  'SIND0','SIND1','SIND2','SIND3','SIND4','SIND5','SIND6','SIND7');
 Kind128: Array[128..255] Of Byte = (
  0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0, 0,0,0,0,0,6,1,0,
  1,2,4,4,4,4,8,6, 4,4,1,4,10,1,1,1,
  1,1,7,9,1,1,7,1, 7,2,0,0,1,1,0,0,
  5,1,1,0,0,0,4,3, 0,0,4,0,4,5,1,1,
  5,6,0,2,2,0,0,0, 0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0);
 CSPName: Array[0..37] Of String[6] = (
  'IOC','NEW','MVL','MVR','EXIT','UREAD','UWRITE','IDS',
  'TRS','TIM','FLC','SCN','USTAT','???','???','???',
  'LDSEG','ULSEG','TRC','RND','SIN','COS','TAN','ATAN',
  'LN','EXP','SQT','MARK','RLS','IOR','UBUSY','POT',
  'UWAIT','CHN','INN','OUT','ATT','IORSLT');
Var
 Op, Kind, B, B2, Lo, Hi: Byte;
 Used, I, N, Size: Integer;
 W, Target: LongInt;
 S: String;
 C: Char;
Begin
 Op := GetByte(Off);
 Operands := '';
 If Op < 128 Then Begin
  Mnemonic := 'SLDC';
  Operands := IntToStr(Op);
  DisasmPCodeOne := 1;
  Exit;
 End;

 Mnemonic := Mnem128[Op];
 Kind := Kind128[Op];
 Size := 1;
 Case Kind Of
  OPK_NONE: ;
  OPK_UB: Begin
   B := GetByte(Off + 1);
   Operands := IntToStr(B);
   Size := 2;
   If Op = 158 Then Begin
    If B <= 37 Then Operands := Operands + ' ; ' + CSPName[B]
    Else Operands := Operands + ' ; CSP#' + IntToStr(B);
   End;
  End;
  OPK_SB: Begin
   B := GetByte(Off + 1);
   If B < 128 Then W := B Else W := Integer(B) - 256;
   Target := VAddrBase + 2 + W;
   Operands := IntToStr(W) + ' ; -> 0x' + ToHexFixed(Target, 6);
   Size := 2;
  End;
  OPK_W: Begin
   Lo := GetByte(Off + 1);
   Hi := GetByte(Off + 2);
   W := LongInt(Hi) * 256 + Lo;
   If W >= 32768 Then W := W - 65536;
   Operands := IntToStr(W);
   Size := 3;
  End;
  OPK_BIG: Begin
   W := PCodeReadBig(Off + 1, Used);
   Operands := IntToStr(W);
   Size := 1 + Used;
  End;
  OPK_UBUB: Begin
   B := GetByte(Off + 1); B2 := GetByte(Off + 2);
   Operands := IntToStr(B) + ',' + IntToStr(B2);
   Size := 3;
  End;
  OPK_UBBIG: Begin
   B := GetByte(Off + 1);
   W := PCodeReadBig(Off + 2, Used);
   Operands := IntToStr(B) + ',' + IntToStr(W);
   Size := 2 + Used;
  End;
  OPK_DBBIG: Begin
   B := GetByte(Off + 1);
   W := PCodeReadBig(Off + 2, Used);
   Operands := 'L' + IntToStr(B) + ',' + IntToStr(W);
   Size := 2 + Used;
  End;
  OPK_LSA: Begin
   B := GetByte(Off + 1);
   N := B;
   S := '';
   For I := 0 To N - 1 Do Begin
    B2 := GetByte(Off + 2 + I);
    If (B2 >= 32) And (B2 < 127) Then C := Chr(B2) Else C := '.';
    S := S + C;
   End;
   Operands := IntToStr(B) + ',"' + S + '"';
   Size := 2 + N;
  End;
  OPK_LDC: Begin
   B := GetByte(Off + 1);
   Operands := IntToStr(B);
   For I := 0 To B - 1 Do Begin
    Lo := GetByte(Off + 2 + I * 2);
    Hi := GetByte(Off + 3 + I * 2);
    Operands := Operands + ',$' + ToHexFixed(LongInt(Hi) * 256 + Lo, 4);
   End;
   Size := 2 + B * 2;
  End;
  OPK_XJP: Operands := '(table de cas)';
 End;
 DisasmPCodeOne := Size;
End;

{ ============================================================
  DESASSEMBLEUR MICROSOFT INTERMEDIATE LANGUAGE (MSIL/CIL)
  ============================================================ }

{ @description: Retourne le mnemonique et le type d operande d un
    opcode CIL ECMA-335. Kind: 0 rien, 1 octet signe, 2 entier 4,
    3 entier 8, 4 flottant 4, 5 flottant 8, 6 branche courte,
    7 branche longue, 8 switch, 9 jeton metadata, 10 variable courte,
    11 variable 16 bits. }
Procedure MSILInfo(Op: Word; Var Mn: String; Var Kind: Byte);
Begin
 Mn := '(bad)'; Kind := 0;
 Case Op Of
  $00: Mn := 'nop'; $01: Mn := 'break';
  $02: Mn := 'ldarg.0'; $03: Mn := 'ldarg.1'; $04: Mn := 'ldarg.2'; $05: Mn := 'ldarg.3';
  $06: Mn := 'ldloc.0'; $07: Mn := 'ldloc.1'; $08: Mn := 'ldloc.2'; $09: Mn := 'ldloc.3';
  $0A: Mn := 'stloc.0'; $0B: Mn := 'stloc.1'; $0C: Mn := 'stloc.2'; $0D: Mn := 'stloc.3';
  $0E: Begin Mn := 'ldarg.s'; Kind := 10; End;
  $0F: Begin Mn := 'ldarga.s'; Kind := 10; End;
  $10: Begin Mn := 'starg.s'; Kind := 10; End;
  $11: Begin Mn := 'ldloc.s'; Kind := 10; End;
  $12: Begin Mn := 'ldloca.s'; Kind := 10; End;
  $13: Begin Mn := 'stloc.s'; Kind := 10; End;
  $14: Mn := 'ldnull';
  $15: Mn := 'ldc.i4.m1'; $16: Mn := 'ldc.i4.0'; $17: Mn := 'ldc.i4.1';
  $18: Mn := 'ldc.i4.2'; $19: Mn := 'ldc.i4.3'; $1A: Mn := 'ldc.i4.4';
  $1B: Mn := 'ldc.i4.5'; $1C: Mn := 'ldc.i4.6'; $1D: Mn := 'ldc.i4.7';
  $1E: Mn := 'ldc.i4.8';
  $1F: Begin Mn := 'ldc.i4.s'; Kind := 1; End;
  $20: Begin Mn := 'ldc.i4'; Kind := 2; End;
  $21: Begin Mn := 'ldc.i8'; Kind := 3; End;
  $22: Begin Mn := 'ldc.r4'; Kind := 4; End;
  $23: Begin Mn := 'ldc.r8'; Kind := 5; End;
  $25: Mn := 'dup'; $26: Mn := 'pop';
  $27: Begin Mn := 'jmp'; Kind := 9; End;
  $28: Begin Mn := 'call'; Kind := 9; End;
  $29: Begin Mn := 'calli'; Kind := 9; End;
  $2A: Mn := 'ret';
  $2B: Begin Mn := 'br.s'; Kind := 6; End;
  $2C: Begin Mn := 'brfalse.s'; Kind := 6; End;
  $2D: Begin Mn := 'brtrue.s'; Kind := 6; End;
  $2E: Begin Mn := 'beq.s'; Kind := 6; End;
  $2F: Begin Mn := 'bge.s'; Kind := 6; End;
  $30: Begin Mn := 'bgt.s'; Kind := 6; End;
  $31: Begin Mn := 'ble.s'; Kind := 6; End;
  $32: Begin Mn := 'blt.s'; Kind := 6; End;
  $33: Begin Mn := 'bne.un.s'; Kind := 6; End;
  $34: Begin Mn := 'bge.un.s'; Kind := 6; End;
  $35: Begin Mn := 'bgt.un.s'; Kind := 6; End;
  $36: Begin Mn := 'ble.un.s'; Kind := 6; End;
  $37: Begin Mn := 'blt.un.s'; Kind := 6; End;
  $38: Begin Mn := 'br'; Kind := 7; End;
  $39: Begin Mn := 'brfalse'; Kind := 7; End;
  $3A: Begin Mn := 'brtrue'; Kind := 7; End;
  $3B: Begin Mn := 'beq'; Kind := 7; End;
  $3C: Begin Mn := 'bge'; Kind := 7; End;
  $3D: Begin Mn := 'bgt'; Kind := 7; End;
  $3E: Begin Mn := 'ble'; Kind := 7; End;
  $3F: Begin Mn := 'blt'; Kind := 7; End;
  $40: Begin Mn := 'bne.un'; Kind := 7; End;
  $41: Begin Mn := 'bge.un'; Kind := 7; End;
  $42: Begin Mn := 'bgt.un'; Kind := 7; End;
  $43: Begin Mn := 'ble.un'; Kind := 7; End;
  $44: Begin Mn := 'blt.un'; Kind := 7; End;
  $45: Begin Mn := 'switch'; Kind := 8; End;
  $46: Mn := 'ldind.i1'; $47: Mn := 'ldind.u1'; $48: Mn := 'ldind.i2';
  $49: Mn := 'ldind.u2'; $4A: Mn := 'ldind.i4'; $4B: Mn := 'ldind.u4';
  $4C: Mn := 'ldind.i8'; $4D: Mn := 'ldind.i'; $4E: Mn := 'ldind.r4';
  $4F: Mn := 'ldind.r8'; $50: Mn := 'ldind.ref';
  $51: Mn := 'stind.ref'; $52: Mn := 'stind.i1'; $53: Mn := 'stind.i2';
  $54: Mn := 'stind.i4'; $55: Mn := 'stind.i8'; $56: Mn := 'stind.r4';
  $57: Mn := 'stind.r8';
  $58: Mn := 'add'; $59: Mn := 'sub'; $5A: Mn := 'mul'; $5B: Mn := 'div';
  $5C: Mn := 'div.un'; $5D: Mn := 'rem'; $5E: Mn := 'rem.un'; $5F: Mn := 'and';
  $60: Mn := 'or'; $61: Mn := 'xor'; $62: Mn := 'shl'; $63: Mn := 'shr';
  $64: Mn := 'shr.un'; $65: Mn := 'neg'; $66: Mn := 'not';
  $67: Mn := 'conv.i1'; $68: Mn := 'conv.i2'; $69: Mn := 'conv.i4';
  $6A: Mn := 'conv.i8'; $6B: Mn := 'conv.r4'; $6C: Mn := 'conv.r8';
  $6D: Mn := 'conv.u4'; $6E: Mn := 'conv.u8';
  $6F: Begin Mn := 'callvirt'; Kind := 9; End;
  $70: Begin Mn := 'cpobj'; Kind := 9; End;
  $71: Begin Mn := 'ldobj'; Kind := 9; End;
  $72: Begin Mn := 'ldstr'; Kind := 9; End;
  $73: Begin Mn := 'newobj'; Kind := 9; End;
  $74: Begin Mn := 'castclass'; Kind := 9; End;
  $75: Begin Mn := 'isinst'; Kind := 9; End;
  $76: Mn := 'conv.r.un';
  $79: Begin Mn := 'unbox'; Kind := 9; End;
  $7A: Mn := 'throw';
  $7B: Begin Mn := 'ldfld'; Kind := 9; End;
  $7C: Begin Mn := 'ldflda'; Kind := 9; End;
  $7D: Begin Mn := 'stfld'; Kind := 9; End;
  $7E: Begin Mn := 'ldsfld'; Kind := 9; End;
  $7F: Begin Mn := 'ldsflda'; Kind := 9; End;
  $80: Begin Mn := 'stsfld'; Kind := 9; End;
  $81: Begin Mn := 'stobj'; Kind := 9; End;
  $82: Mn := 'conv.ovf.i1.un'; $83: Mn := 'conv.ovf.i2.un';
  $84: Mn := 'conv.ovf.i4.un'; $85: Mn := 'conv.ovf.i8.un';
  $86: Mn := 'conv.ovf.u1.un'; $87: Mn := 'conv.ovf.u2.un';
  $88: Mn := 'conv.ovf.u4.un'; $89: Mn := 'conv.ovf.u8.un';
  $8A: Mn := 'conv.ovf.i.un'; $8B: Mn := 'conv.ovf.u.un';
  $8C: Begin Mn := 'box'; Kind := 9; End;
  $8D: Begin Mn := 'newarr'; Kind := 9; End;
  $8E: Mn := 'ldlen';
  $8F: Begin Mn := 'ldelema'; Kind := 9; End;
  $90: Mn := 'ldelem.i1'; $91: Mn := 'ldelem.u1'; $92: Mn := 'ldelem.i2';
  $93: Mn := 'ldelem.u2'; $94: Mn := 'ldelem.i4'; $95: Mn := 'ldelem.u4';
  $96: Mn := 'ldelem.i8'; $97: Mn := 'ldelem.i'; $98: Mn := 'ldelem.r4';
  $99: Mn := 'ldelem.r8'; $9A: Mn := 'ldelem.ref';
  $9B: Mn := 'stelem.i'; $9C: Mn := 'stelem.i1'; $9D: Mn := 'stelem.i2';
  $9E: Mn := 'stelem.i4'; $9F: Mn := 'stelem.i8'; $A0: Mn := 'stelem.r4';
  $A1: Mn := 'stelem.r8'; $A2: Mn := 'stelem.ref';
  $A3: Begin Mn := 'ldelem'; Kind := 9; End;
  $A4: Begin Mn := 'stelem'; Kind := 9; End;
  $A5: Begin Mn := 'unbox.any'; Kind := 9; End;
  $B3: Mn := 'conv.ovf.i1'; $B4: Mn := 'conv.ovf.u1';
  $B5: Mn := 'conv.ovf.i2'; $B6: Mn := 'conv.ovf.u2';
  $B7: Mn := 'conv.ovf.i4'; $B8: Mn := 'conv.ovf.u4';
  $B9: Mn := 'conv.ovf.i8'; $BA: Mn := 'conv.ovf.u8';
  $C2: Begin Mn := 'refanyval'; Kind := 9; End;
  $C3: Mn := 'ckfinite';
  $C6: Begin Mn := 'mkrefany'; Kind := 9; End;
  $D0: Begin Mn := 'ldtoken'; Kind := 9; End;
  $D1: Mn := 'conv.u2'; $D2: Mn := 'conv.u1'; $D3: Mn := 'conv.i';
  $D4: Mn := 'conv.ovf.i'; $D5: Mn := 'conv.ovf.u';
  $D6: Mn := 'add.ovf'; $D7: Mn := 'add.ovf.un';
  $D8: Mn := 'mul.ovf'; $D9: Mn := 'mul.ovf.un';
  $DA: Mn := 'sub.ovf'; $DB: Mn := 'sub.ovf.un';
  $DC: Mn := 'endfinally';
  $DD: Begin Mn := 'leave'; Kind := 7; End;
  $DE: Begin Mn := 'leave.s'; Kind := 6; End;
  $DF: Mn := 'stind.i'; $E0: Mn := 'conv.u';

  $FE00: Mn := 'arglist'; $FE01: Mn := 'ceq'; $FE02: Mn := 'cgt';
  $FE03: Mn := 'cgt.un'; $FE04: Mn := 'clt'; $FE05: Mn := 'clt.un';
  $FE06: Begin Mn := 'ldftn'; Kind := 9; End;
  $FE07: Begin Mn := 'ldvirtftn'; Kind := 9; End;
  $FE09: Begin Mn := 'ldarg'; Kind := 11; End;
  $FE0A: Begin Mn := 'ldarga'; Kind := 11; End;
  $FE0B: Begin Mn := 'starg'; Kind := 11; End;
  $FE0C: Begin Mn := 'ldloc'; Kind := 11; End;
  $FE0D: Begin Mn := 'ldloca'; Kind := 11; End;
  $FE0E: Begin Mn := 'stloc'; Kind := 11; End;
  $FE0F: Mn := 'localloc'; $FE11: Mn := 'endfilter';
  $FE12: Begin Mn := 'unaligned.'; Kind := 1; End;
  $FE13: Mn := 'volatile.'; $FE14: Mn := 'tail.';
  $FE15: Begin Mn := 'initobj'; Kind := 9; End;
  $FE16: Begin Mn := 'constrained.'; Kind := 9; End;
  $FE17: Mn := 'cpblk'; $FE18: Mn := 'initblk'; $FE1A: Mn := 'rethrow';
  $FE1C: Begin Mn := 'sizeof'; Kind := 9; End;
  $FE1D: Mn := 'refanytype'; $FE1E: Mn := 'readonly.';
 End;
End;

Function DisasmMSILOne(Off, VAddrBase: LongInt;
 Var Mnemonic, Operands: String): Integer;
Var
 Op: Word;
 Kind: Byte;
 P, I, Count, BaseSize: Integer;
 V, Target: LongInt;
 B: Byte;
 S: String;
Begin
 B := GetByte(Off);
 If B = $FE Then Begin
  Op := $FE00 Or GetByte(Off + 1);
  P := 2;
 End Else Begin
  Op := B;
  P := 1;
 End;
 MSILInfo(Op, Mnemonic, Kind);
 Operands := '';
 Case Kind Of
  1: Begin
   B := GetByte(Off + P);
   If B < 128 Then V := B Else V := Integer(B) - 256;
   Operands := IntToStr(V); Inc(P);
  End;
  2: Begin V := GetDWord(Off + P); Operands := IntToStr(V); Inc(P, 4); End;
  3: Begin
   Operands := '0x' + ToHexFixed(GetDWord(Off + P + 4), 8) +
    ToHexFixed(GetDWord(Off + P), 8); Inc(P, 8);
  End;
  4: Begin Operands := 'float32(0x' + ToHexFixed(GetDWord(Off + P), 8) + ')'; Inc(P, 4); End;
  5: Begin
   Operands := 'float64(0x' + ToHexFixed(GetDWord(Off + P + 4), 8) +
    ToHexFixed(GetDWord(Off + P), 8) + ')'; Inc(P, 8);
  End;
  6: Begin
   B := GetByte(Off + P);
   If B < 128 Then V := B Else V := Integer(B) - 256;
   Inc(P);
   Target := VAddrBase + P + V;
   Operands := 'IL_' + ToHexFixed(Target, 4);
  End;
  7: Begin
   V := GetDWord(Off + P); Inc(P, 4);
   Target := VAddrBase + P + V;
   Operands := 'IL_' + ToHexFixed(Target, 4);
  End;
  8: Begin
   Count := GetDWord(Off + P); Inc(P, 4);
   BaseSize := P + Count * 4;
   S := '';
   For I := 0 To Count - 1 Do Begin
    V := GetDWord(Off + P + I * 4);
    Target := VAddrBase + BaseSize + V;
    If S <> '' Then S := S + ',';
    S := S + 'IL_' + ToHexFixed(Target, 4);
   End;
   Operands := '(' + S + ')';
   P := BaseSize;
  End;
  9: Begin
   V := GetDWord(Off + P);
   Operands := 'token(0x' + ToHexFixed(V, 8) + ')'; Inc(P, 4);
  End;
  10: Begin Operands := IntToStr(GetByte(Off + P)); Inc(P); End;
  11: Begin Operands := IntToStr(GetWord(Off + P)); Inc(P, 2); End;
 End;
 DisasmMSILOne := P;
End;

{ ============================================================
  DESASSEMBLEUR BYTECODE JAVA JVM / JASMIN
  ============================================================ }

Function JVMName(Op: Byte): String;
Const
 C0: Array[0..20] Of String[12] = (
  'nop','aconst_null','iconst_m1','iconst_0','iconst_1','iconst_2',
  'iconst_3','iconst_4','iconst_5','lconst_0','lconst_1','fconst_0',
  'fconst_1','fconst_2','dconst_0','dconst_1','bipush','sipush',
  'ldc','ldc_w','ldc2_w');
 Ld: Array[21..45] Of String[10] = (
  'iload','lload','fload','dload','aload',
  'iload_0','iload_1','iload_2','iload_3',
  'lload_0','lload_1','lload_2','lload_3',
  'fload_0','fload_1','fload_2','fload_3',
  'dload_0','dload_1','dload_2','dload_3',
  'aload_0','aload_1','aload_2','aload_3');
 ArrLd: Array[46..53] Of String[7] = (
  'iaload','laload','faload','daload','aaload','baload','caload','saload');
 St: Array[54..78] Of String[10] = (
  'istore','lstore','fstore','dstore','astore',
  'istore_0','istore_1','istore_2','istore_3',
  'lstore_0','lstore_1','lstore_2','lstore_3',
  'fstore_0','fstore_1','fstore_2','fstore_3',
  'dstore_0','dstore_1','dstore_2','dstore_3',
  'astore_0','astore_1','astore_2','astore_3');
 ArrSt: Array[79..86] Of String[8] = (
  'iastore','lastore','fastore','dastore','aastore','bastore','castore','sastore');
 Stack: Array[87..95] Of String[8] = (
  'pop','pop2','dup','dup_x1','dup_x2','dup2','dup2_x1','dup2_x2','swap');
 Math: Array[96..131] Of String[6] = (
  'iadd','ladd','fadd','dadd','isub','lsub','fsub','dsub',
  'imul','lmul','fmul','dmul','idiv','ldiv','fdiv','ddiv',
  'irem','lrem','frem','drem','ineg','lneg','fneg','dneg',
  'ishl','lshl','ishr','lshr','iushr','lushr','iand','land',
  'ior','lor','ixor','lxor');
 Conv: Array[133..147] Of String[4] = (
  'i2l','i2f','i2d','l2i','l2f','l2d','f2i','f2l','f2d',
  'd2i','d2l','d2f','i2b','i2c','i2s');
 Cmp: Array[148..152] Of String[5] = ('lcmp','fcmpl','fcmpg','dcmpl','dcmpg');
 Br: Array[153..166] Of String[10] = (
  'ifeq','ifne','iflt','ifge','ifgt','ifle',
  'if_icmpeq','if_icmpne','if_icmplt','if_icmpge','if_icmpgt','if_icmple',
  'if_acmpeq','if_acmpne');
Begin
 If Op <= 20 Then JVMName := C0[Op]
 Else If (Op >= 21) And (Op <= 45) Then JVMName := Ld[Op]
 Else If (Op >= 46) And (Op <= 53) Then JVMName := ArrLd[Op]
 Else If (Op >= 54) And (Op <= 78) Then JVMName := St[Op]
 Else If (Op >= 79) And (Op <= 86) Then JVMName := ArrSt[Op]
 Else If (Op >= 87) And (Op <= 95) Then JVMName := Stack[Op]
 Else If (Op >= 96) And (Op <= 131) Then JVMName := Math[Op]
 Else If Op = 132 Then JVMName := 'iinc'
 Else If (Op >= 133) And (Op <= 147) Then JVMName := Conv[Op]
 Else If (Op >= 148) And (Op <= 152) Then JVMName := Cmp[Op]
 Else If (Op >= 153) And (Op <= 166) Then JVMName := Br[Op]
 Else Case Op Of
  167: JVMName := 'goto'; 168: JVMName := 'jsr'; 169: JVMName := 'ret';
  170: JVMName := 'tableswitch'; 171: JVMName := 'lookupswitch';
  172: JVMName := 'ireturn'; 173: JVMName := 'lreturn';
  174: JVMName := 'freturn'; 175: JVMName := 'dreturn';
  176: JVMName := 'areturn'; 177: JVMName := 'return';
  178: JVMName := 'getstatic'; 179: JVMName := 'putstatic';
  180: JVMName := 'getfield'; 181: JVMName := 'putfield';
  182: JVMName := 'invokevirtual'; 183: JVMName := 'invokespecial';
  184: JVMName := 'invokestatic'; 185: JVMName := 'invokeinterface';
  186: JVMName := 'invokedynamic'; 187: JVMName := 'new';
  188: JVMName := 'newarray'; 189: JVMName := 'anewarray';
  190: JVMName := 'arraylength'; 191: JVMName := 'athrow';
  192: JVMName := 'checkcast'; 193: JVMName := 'instanceof';
  194: JVMName := 'monitorenter'; 195: JVMName := 'monitorexit';
  196: JVMName := 'wide'; 197: JVMName := 'multianewarray';
  198: JVMName := 'ifnull'; 199: JVMName := 'ifnonnull';
  200: JVMName := 'goto_w'; 201: JVMName := 'jsr_w';
  202: JVMName := 'breakpoint'; 254: JVMName := 'impdep1'; 255: JVMName := 'impdep2';
 Else JVMName := '(bad)';
 End;
End;

Function JVMShortBE(Off: LongInt): LongInt;
Var W: Word;
Begin
 W := GetWordBE(Off);
 If (W And $8000) <> 0 Then JVMShortBE := LongInt(W) Or LongInt($FFFF0000)
 Else JVMShortBE := W;
End;

Function DisasmJVMOne(Off, VAddrBase: LongInt;
 Var Mnemonic, Operands: String): Integer;
Var
 Op, SubOp, B: Byte;
 P, Padding, Count, I: Integer;
 V, V2, Target, LowVal, HighVal: LongInt;
 Idx: Word;
 S: String;
Begin
 Op := GetByte(Off);
 Mnemonic := JVMName(Op);
 Operands := '';
 P := 1;
 Case Op Of
  16: Begin B := GetByte(Off + 1); If B < 128 Then V := B Else V := Integer(B)-256;
       Operands := IntToStr(V); P := 2; End;
  17: Begin Operands := IntToStr(JVMShortBE(Off + 1)); P := 3; End;
  18: Begin Idx := GetByte(Off + 1); Operands := '#' + IntToStr(Idx) +
       ' ; ' + JavaCPDescription(Idx); P := 2; End;
  19,20,178..184,187,189,192,193: Begin
   Idx := GetWordBE(Off + 1);
   Operands := '#' + IntToStr(Idx) + ' ; ' + JavaCPDescription(Idx);
   P := 3;
  End;
  21..25,54..58,169: Begin Operands := IntToStr(GetByte(Off + 1)); P := 2; End;
  132: Begin
   B := GetByte(Off + 2); If B < 128 Then V := B Else V := Integer(B)-256;
   Operands := IntToStr(GetByte(Off + 1)) + ',' + IntToStr(V); P := 3;
  End;
  153..168,198,199: Begin
   V := JVMShortBE(Off + 1);
   Target := VAddrBase + V;
   Operands := 'L' + ToHexFixed(Target, 4); P := 3;
  End;
  185: Begin
   Idx := GetWordBE(Off + 1);
   Operands := '#' + IntToStr(Idx) + ',' + IntToStr(GetByte(Off + 3)) +
    ' ; ' + JavaCPDescription(Idx); P := 5;
  End;
  186: Begin
   Idx := GetWordBE(Off + 1);
   Operands := '#' + IntToStr(Idx) + ' ; ' + JavaCPDescription(Idx); P := 5;
  End;
  188: Begin
   B := GetByte(Off + 1);
   Case B Of
    4: S := 'boolean'; 5: S := 'char'; 6: S := 'float'; 7: S := 'double';
    8: S := 'byte'; 9: S := 'short'; 10: S := 'int'; 11: S := 'long';
   Else S := IntToStr(B);
   End;
   Operands := S; P := 2;
  End;
  197: Begin
   Idx := GetWordBE(Off + 1);
   Operands := '#' + IntToStr(Idx) + ',' + IntToStr(GetByte(Off + 3)) +
    ' ; ' + JavaCPDescription(Idx); P := 4;
  End;
  200,201: Begin
   V := GetDWordBE(Off + 1);
   Target := VAddrBase + V;
   Operands := 'L' + ToHexFixed(Target, 4); P := 5;
  End;
  196: Begin
   SubOp := GetByte(Off + 1);
   Mnemonic := 'wide ' + JVMName(SubOp);
   Idx := GetWordBE(Off + 2);
   Operands := IntToStr(Idx);
   If SubOp = 132 Then Begin
    Operands := Operands + ',' + IntToStr(JVMShortBE(Off + 4)); P := 6;
   End Else P := 4;
  End;
  170: Begin
   Padding := (4 - ((VAddrBase + 1) And 3)) And 3;
   V := GetDWordBE(Off + 1 + Padding);
   LowVal := GetDWordBE(Off + 5 + Padding);
   HighVal := GetDWordBE(Off + 9 + Padding);
   Count := HighVal - LowVal + 1;
   S := 'low=' + IntToStr(LowVal) + ',high=' + IntToStr(HighVal) +
    ',default=L' + ToHexFixed(VAddrBase + V, 4);
   For I := 0 To Count - 1 Do Begin
    V2 := GetDWordBE(Off + 13 + Padding + I * 4);
    S := S + ',' + IntToStr(LowVal + I) + ':L' + ToHexFixed(VAddrBase + V2, 4);
   End;
   Operands := S; P := 1 + Padding + 12 + Count * 4;
  End;
  171: Begin
   Padding := (4 - ((VAddrBase + 1) And 3)) And 3;
   V := GetDWordBE(Off + 1 + Padding);
   Count := GetDWordBE(Off + 5 + Padding);
   S := 'default=L' + ToHexFixed(VAddrBase + V, 4);
   For I := 0 To Count - 1 Do Begin
    V2 := GetDWordBE(Off + 9 + Padding + I * 8);
    Target := GetDWordBE(Off + 13 + Padding + I * 8);
    S := S + ',' + IntToStr(V2) + ':L' + ToHexFixed(VAddrBase + Target, 4);
   End;
   Operands := S; P := 1 + Padding + 8 + Count * 8;
  End;
 End;
 DisasmJVMOne := P;
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

{ @description: Cherche une section par son nom exact (ex:
    ".debug_line"), utilise par l option -S pour localiser les
    informations de debogage DWARF dans un binaire ELF.
  @param Name Nom de section recherche
  @return Index (1-based) de la section, ou 0 si absente }
Function FindSectionByName(Name: String): Integer;
Var
 I: Integer;
Begin
 FindSectionByName := 0;
 For I := 1 To SectionCount Do
  If Sections[I].Name = Name Then Begin
   FindSectionByName := I;
   Exit;
  End;
End;

{ ============================================================
  ANALYSE STRUCTURELLE LLVM BITCODE
  ============================================================ }

Function LLVMReadBits(Count: Integer): LongInt;
Var
 I, BytePos, BitInByte: Integer;
 R: LongInt;
Begin
 R := 0;
 For I := 0 To Count - 1 Do Begin
  BytePos := LLVMBitPos Div 8;
  BitInByte := LLVMBitPos Mod 8;
  If (BytePos < BufSize) And
     ((GetByte(BytePos) And (1 Shl BitInByte)) <> 0) And (I < 31) Then
   R := R Or (LongInt(1) Shl I);
  Inc(LLVMBitPos);
 End;
 LLVMReadBits := R;
End;

Function LLVMReadVBR(Width: Integer): LongInt;
Var
 Piece, Payload, Shift, Acc: LongInt;
Begin
 Acc := 0;
 Shift := 0;
 Repeat
  Piece := LLVMReadBits(Width);
  Payload := Piece And ((LongInt(1) Shl (Width - 1)) - 1);
  If Shift < 30 Then Acc := Acc Or (Payload Shl Shift);
  Inc(Shift, Width - 1);
 Until (Piece And (LongInt(1) Shl (Width - 1))) = 0;
 LLVMReadVBR := Acc;
End;

Procedure LLVMAlign32;
Begin
 LLVMBitPos := (LLVMBitPos + 31) And Not 31;
End;

Function LLVMBlockName(ID: LongInt): String;
Begin
 Case ID Of
  0: LLVMBlockName := 'BLOCKINFO';
  8: LLVMBlockName := 'MODULE';
  9: LLVMBlockName := 'PARAMATTR';
  10: LLVMBlockName := 'PARAMATTR_GROUP';
  11: LLVMBlockName := 'CONSTANTS';
  12: LLVMBlockName := 'FUNCTION';
  14: LLVMBlockName := 'VALUE_SYMTAB';
  15: LLVMBlockName := 'METADATA';
  16: LLVMBlockName := 'METADATA_ATTACHMENT';
  17: LLVMBlockName := 'TYPE';
  18: LLVMBlockName := 'USELIST';
  19: LLVMBlockName := 'MODULE_STRTAB';
  21: LLVMBlockName := 'GLOBALVAL_SUMMARY';
  22: LLVMBlockName := 'OPERAND_BUNDLE_TAGS';
  23: LLVMBlockName := 'STRTAB';
  25: LLVMBlockName := 'SYMTAB';
 Else LLVMBlockName := 'BLOCK';
 End;
End;

Function LLVMIndent(Level: Integer): String;
Begin
 LLVMIndent := SpaceStr(Level * 2);
End;

Procedure LLVMReadAbbrev(Var A: TLLVMAbbrev);
Var
 I, N, Stored: Integer;
 Enc: Byte;
 IsLit: Boolean;
 V: LongInt;
Begin
 FillChar(A, SizeOf(A), 0);
 N := LLVMReadVBR(5);
 Stored := N;
 If Stored > LLVM_MAX_ABBREV_OPS Then Stored := LLVM_MAX_ABBREV_OPS;
 A.Count := Stored;
 For I := 0 To N - 1 Do Begin
  IsLit := LLVMReadBits(1) <> 0;
  Enc := 0; V := 0;
  If IsLit Then
   V := LLVMReadVBR(8)
  Else Begin
   Enc := LLVMReadBits(3);
   If (Enc = 1) Or (Enc = 2) Then V := LLVMReadVBR(5);
  End;
  If I < Stored Then Begin
   A.Ops[I].IsLiteral := IsLit;
   A.Ops[I].Encoding := Enc;
   A.Ops[I].Value := V;
  End;
 End;
End;

Function LLVMReadEncodedValue(Const O: TLLVMAbbrevOp): LongInt;
Begin
 Case O.Encoding Of
  1: LLVMReadEncodedValue := LLVMReadBits(O.Value);
  2: LLVMReadEncodedValue := LLVMReadVBR(O.Value);
  4: LLVMReadEncodedValue := LLVMReadBits(6);
 Else LLVMReadEncodedValue := 0;
 End;
End;

Procedure LLVMPrintRecord(Level: Integer; Code: LongInt; Const Values: String);
Begin
 If Values = '' Then
  WriteLn(LLVMIndent(Level), 'record ', Code)
 Else
  WriteLn(LLVMIndent(Level), 'record ', Code, ' [', Values, ']');
End;

Procedure LLVMDecodeAbbrevRecord(Const A: TLLVMAbbrev; Level: Integer);
Var
 I, J, N: Integer;
 Code, V: LongInt;
 Values: String;
 Elem: TLLVMAbbrevOp;
Begin
 Code := -1;
 Values := '';
 I := 0;
 While I < A.Count Do Begin
  If A.Ops[I].IsLiteral Then V := A.Ops[I].Value
  Else If A.Ops[I].Encoding = 3 Then Begin { Array }
   Inc(I);
   If I >= A.Count Then Break;
   Elem := A.Ops[I];
   N := LLVMReadVBR(6);
   For J := 0 To N - 1 Do Begin
    V := LLVMReadEncodedValue(Elem);
    If Length(Values) < 180 Then Begin
     If Values <> '' Then Values := Values + ',';
     Values := Values + IntToStr(V);
    End;
   End;
   Inc(I);
   Continue;
  End Else If A.Ops[I].Encoding = 5 Then Begin { Blob }
   N := LLVMReadVBR(6);
   LLVMAlign32;
   If Values <> '' Then Values := Values + ',';
   Values := Values + 'blob(' + IntToStr(N) + ')';
   Inc(LLVMBitPos, N * 8);
   LLVMAlign32;
   Inc(I);
   Continue;
  End Else
   V := LLVMReadEncodedValue(A.Ops[I]);

  If Code < 0 Then Code := V
  Else Begin
   If Values <> '' Then Values := Values + ',';
   Values := Values + IntToStr(V);
  End;
  Inc(I);
 End;
 LLVMPrintRecord(Level, Code, Values);
End;

Procedure LLVMParseBlock(BlockID, CodeWidth, EndBit, Level: LongInt);
Var
 Local: PLLVMAbbrevList;
 AbbrevID, SubID, NewWidth, BlockWords: LongInt;
 Code, N, I, TargetBID: LongInt;
 Values: String;
 A: TLLVMAbbrev;
Begin
 GetMem(Local, SizeOf(TLLVMAbbrevList));
 FillChar(Local^, SizeOf(TLLVMAbbrevList), 0);
 If (BlockID >= 0) And (BlockID <= 63) And
    (LLVMBlockInfo[BlockID] <> Nil) Then Local^ := LLVMBlockInfo[BlockID]^;
 TargetBID := -1;
 While (LLVMBitPos < EndBit) And (LLVMBitPos < BufSize * 8) Do Begin
  AbbrevID := LLVMReadBits(CodeWidth);
  Case AbbrevID Of
   0: Begin
    LLVMAlign32;
    Break;
   End;
   1: Begin
    SubID := LLVMReadVBR(8);
    NewWidth := LLVMReadVBR(4);
    LLVMAlign32;
    BlockWords := LLVMReadBits(32);
    WriteLn(LLVMIndent(Level), '<', LLVMBlockName(SubID),
     ' id=', SubID, ' words=', BlockWords, '>');
    LLVMParseBlock(SubID, NewWidth, LLVMBitPos + BlockWords * 32, Level + 1);
    WriteLn(LLVMIndent(Level), '</', LLVMBlockName(SubID), '>');
   End;
   2: Begin
    LLVMReadAbbrev(A);
    If (BlockID = 0) And (TargetBID >= 0) And (TargetBID <= 63) Then Begin
     If LLVMBlockInfo[TargetBID] = Nil Then Begin
      GetMem(LLVMBlockInfo[TargetBID], SizeOf(TLLVMAbbrevList));
      FillChar(LLVMBlockInfo[TargetBID]^, SizeOf(TLLVMAbbrevList), 0);
     End;
     N := LLVMBlockInfo[TargetBID]^.Count;
     If N < LLVM_MAX_ABBREVS Then Begin
      LLVMBlockInfo[TargetBID]^.Items[N] := A;
      Inc(LLVMBlockInfo[TargetBID]^.Count);
     End;
    End Else If Local^.Count < LLVM_MAX_ABBREVS Then Begin
     Local^.Items[Local^.Count] := A;
     Inc(Local^.Count);
    End;
    WriteLn(LLVMIndent(Level), 'abbrev #', Local^.Count + 3);
   End;
   3: Begin
    Code := LLVMReadVBR(6);
    N := LLVMReadVBR(6);
    Values := '';
    For I := 0 To N - 1 Do Begin
     If Values <> '' Then Values := Values + ',';
     Values := Values + IntToStr(LLVMReadVBR(6));
    End;
    LLVMPrintRecord(Level, Code, Values);
    If (BlockID = 0) And (Code = 1) And (N > 0) Then Begin
     { SETBID est toujours le premier operande du record. }
     Val(Copy(Values, 1, Pos(',', Values + ',') - 1), TargetBID, I);
    End;
   End;
  Else
   I := AbbrevID - 4;
   If (I >= 0) And (I < Local^.Count) Then
    LLVMDecodeAbbrevRecord(Local^.Items[I], Level)
   Else Begin
    WriteLn(LLVMIndent(Level), 'abbrev inconnu #', AbbrevID);
    Break;
   End;
  End;
 End;
 LLVMBitPos := EndBit;
 FreeMem(Local, SizeOf(TLLVMAbbrevList));
End;

Procedure CmdLLVM;
Var
 I: Integer;
 StartOff: LongInt;
Begin
 For I := 0 To 63 Do Begin
  If LLVMBlockInfo[I] <> Nil Then Begin
   FreeMem(LLVMBlockInfo[I], SizeOf(TLLVMAbbrevList));
   LLVMBlockInfo[I] := Nil;
  End;
 End;
 If GetDWord(0) = $0B17C0DE Then StartOff := GetDWord(8) Else StartOff := 0;
 WriteLn;
 WriteLn(InFileName, ':     format llvm-bitcode');
 WriteLn('LLVM bitstream structure:');
 If (GetByte(StartOff) <> Ord('B')) Or (GetByte(StartOff + 1) <> Ord('C')) Or
    (GetByte(StartOff + 2) <> $C0) Or (GetByte(StartOff + 3) <> $DE) Then Begin
  WriteLn('Erreur : signature LLVM BC C0 DE absente.');
  Exit;
 End;
 LLVMBitPos := (StartOff + 4) * 8;
 LLVMParseBlock(-1, 2, BufSize * 8, 0);
End;

{ ============================================================
  COMMANDES
  ============================================================ }

{ @description: Nom du format binaire detecte, pour l affichage
    d entete (style "objdump").
  @return Nom du format (ex: "elf32-i386", "pei-i386") }
Function FormatName: String;
Begin
 If Arch = ARCH_LLVM Then Begin
  FormatName := 'llvm-bitcode';
  Exit;
 End;
 If Arch = ARCH_JVM Then Begin
  If BinFormat = FMT_CLASS Then FormatName := 'java-class'
  Else FormatName := 'raw-jvm-bytecode';
  Exit;
 End;
 If Arch = ARCH_MSIL Then Begin
  If (BinFormat = FMT_PE32) Or (BinFormat = FMT_PE64) Then
   FormatName := 'pei-managed-msil'
  Else FormatName := 'raw-msil';
  Exit;
 End;
 If Arch = ARCH_PCODE Then Begin
  FormatName := 'ucsd-pcode';
  Exit;
 End;
 If ((Arch = ARCH_IA64) Or (Arch = ARCH_IA64BE)) And
    (BinFormat = FMT_ELF64) Then Begin
  If Arch = ARCH_IA64BE Then FormatName := 'elf64-ia64-big'
  Else FormatName := 'elf64-ia64-little';
  Exit;
 End;
 If ((Arch = ARCH_SH) Or (Arch = ARCH_SHLE)) And
    (BinFormat = FMT_ELF32) Then Begin
  If Arch = ARCH_SHLE Then FormatName := 'elf32-shl'
  Else FormatName := 'elf32-sh';
  Exit;
 End;
 If ((Arch = ARCH_PPC) Or (Arch = ARCH_PPCLE)) And
    (BinFormat = FMT_ELF32) Then Begin
  If Arch = ARCH_PPCLE Then FormatName := 'elf32-powerpcle'
  Else FormatName := 'elf32-powerpc';
  Exit;
 End;
 If ((Arch = ARCH_PPC) Or (Arch = ARCH_PPCLE)) And
    (BinFormat = FMT_ELF64) Then Begin
  If Arch = ARCH_PPCLE Then FormatName := 'elf64-powerpcle'
  Else FormatName := 'elf64-powerpc';
  Exit;
 End;
 If ((Arch = ARCH_MIPS) Or (Arch = ARCH_MIPSEL)) And
    (BinFormat = FMT_ELF32) Then Begin
  If Arch = ARCH_MIPSEL Then FormatName := 'elf32-tradlittlemips'
  Else FormatName := 'elf32-tradbigmips';
  Exit;
 End;
 If ((Arch = ARCH_MIPS) Or (Arch = ARCH_MIPSEL)) And
    (BinFormat = FMT_ELF64) Then Begin
  If Arch = ARCH_MIPSEL Then FormatName := 'elf64-tradlittlemips'
  Else FormatName := 'elf64-tradbigmips';
  Exit;
 End;
 If (Arch = ARCH_SPARC) And (BinFormat = FMT_ELF32) Then Begin
  FormatName := 'elf32-sparc';
  Exit;
 End;
 If (Arch = ARCH_SPARC) And (BinFormat = FMT_ELF64) Then Begin
  FormatName := 'elf64-sparc';
  Exit;
 End;
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
  FMT_COFFOBJ: Begin
   If PEMachine = $14C Then FormatName := 'coff-i386'
   Else If PEMachine = $8664 Then FormatName := 'coff-x86-64'
   Else If (PEMachine = PE_MACHINE_ARM) Or (PEMachine = PE_MACHINE_ARMNT) Then
    FormatName := 'coff-arm'
   Else If PEMachine = PE_MACHINE_ARM64 Then FormatName := 'coff-arm64'
   Else FormatName := 'coff-object (machine 0x' + ToHexU(PEMachine) + ')';
  End;
  FMT_ARCHIVE: FormatName := 'ar-archive';
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

{ @description: Determine le nombre de chiffres hexadecimaux a
    utiliser pour afficher une adresse, selon l architecture et la
    largeur de bus (32/64 bits) du format charge. Factorise hors de
    CmdDisasm pour etre reutilise par CmdSourceMix (option -S).
  @return Nombre de chiffres hexadecimaux }
Function GetAddrDigits: Integer;
Begin
 If (Arch = ARCH_6502) Or (Arch = ARCH_8086) Or (Arch = ARCH_8080) Or
    (Arch = ARCH_Z80) Or (Arch = ARCH_6800) Or (Arch = ARCH_MSIL) Or
    (Arch = ARCH_JVM) Then
  GetAddrDigits := 4
 Else If (Arch = ARCH_X64) Or (Arch = ARCH_ARM64) Or
         (Arch = ARCH_IA64) Or (Arch = ARCH_IA64BE) Or
         ((Arch = ARCH_SPARC) And (BinFormat = FMT_ELF64)) Or
         (((Arch = ARCH_MIPS) Or (Arch = ARCH_MIPSEL)) And
          (BinFormat = FMT_ELF64)) Or
         (((Arch = ARCH_PPC) Or (Arch = ARCH_PPCLE)) And
          (BinFormat = FMT_ELF64)) Then GetAddrDigits := 16
 Else If (Arch = ARCH_ARM32) Or (Arch = ARCH_THUMB) Or
         (Arch = ARCH_68000) Or (Arch = ARCH_SPARC) Or
         (Arch = ARCH_MIPS) Or (Arch = ARCH_MIPSEL) Or
         (Arch = ARCH_PPC) Or (Arch = ARCH_PPCLE) Or
         (Arch = ARCH_SH) Or (Arch = ARCH_SHLE) Then GetAddrDigits := 8
 Else GetAddrDigits := 6;
End;

{ @description: Decode une instruction a la position Off, en
    aiguillant vers le desassembleur de Arch. Factorise hors de
    CmdDisasm pour etre reutilise par CmdSourceMix (option -S), qui a
    besoin du meme decodage instruction par instruction mais avec un
    affichage entrelace different.
  @param Off Decalage (0-based) dans le fichier
  @param VAddr Adresse virtuelle de l instruction
  @param Mnemonic (sortie) mnemonique decode
  @param Operands (sortie) operandes formates
  @return Longueur de l instruction en octets }
Function DecodeInstruction(Off, VAddr: LongInt;
 Var Mnemonic, Operands: String): Integer;
Begin
 If Arch = ARCH_6502 Then
  DecodeInstruction := Disasm6502One(Off, VAddr, Mnemonic, Operands)
 Else If Arch = ARCH_8086 Then
  DecodeInstruction := Disasm8086One(Off, VAddr, Mnemonic, Operands)
 Else If Arch = ARCH_X64 Then
  DecodeInstruction := Disasm64One(Off, VAddr, Mnemonic, Operands)
 Else If Arch = ARCH_ARM64 Then
  DecodeInstruction := DisasmArm64One(Off, VAddr, Mnemonic, Operands)
 Else If Arch = ARCH_ARM32 Then
  DecodeInstruction := DisasmArm32One(Off, VAddr, Mnemonic, Operands)
 Else If Arch = ARCH_THUMB Then
  DecodeInstruction := DisasmThumbOne(Off, VAddr, Mnemonic, Operands)
 Else If Arch = ARCH_8080 Then
  DecodeInstruction := Disasm8080One(Off, VAddr, Mnemonic, Operands)
 Else If Arch = ARCH_Z80 Then
  DecodeInstruction := DisasmZ80One(Off, VAddr, Mnemonic, Operands)
 Else If Arch = ARCH_6800 Then
  DecodeInstruction := Disasm6800One(Off, VAddr, Mnemonic, Operands)
 Else If Arch = ARCH_68000 Then
  DecodeInstruction := Disasm68kOne(Off, VAddr, Mnemonic, Operands)
 Else If Arch = ARCH_SPARC Then
  DecodeInstruction := DisasmSparcOne(Off, VAddr, Mnemonic, Operands)
 Else If (Arch = ARCH_MIPS) Or (Arch = ARCH_MIPSEL) Then
  DecodeInstruction := DisasmMipsOne(Off, VAddr, Mnemonic, Operands)
 Else If (Arch = ARCH_PPC) Or (Arch = ARCH_PPCLE) Then
  DecodeInstruction := DisasmPpcOne(Off, VAddr, Mnemonic, Operands)
 Else If (Arch = ARCH_SH) Or (Arch = ARCH_SHLE) Then
  DecodeInstruction := DisasmShOne(Off, VAddr, Mnemonic, Operands)
 Else If (Arch = ARCH_IA64) Or (Arch = ARCH_IA64BE) Then
  DecodeInstruction := DisasmIa64One(Off, VAddr, Mnemonic, Operands)
 Else If Arch = ARCH_PCODE Then
  DecodeInstruction := DisasmPCodeOne(Off, VAddr, Mnemonic, Operands)
 Else If Arch = ARCH_MSIL Then
  DecodeInstruction := DisasmMSILOne(Off, VAddr, Mnemonic, Operands)
 Else If Arch = ARCH_JVM Then
  DecodeInstruction := DisasmJVMOne(Off, VAddr, Mnemonic, Operands)
 Else
  DecodeInstruction := DisasmOne(Off, VAddr, Mnemonic, Operands);
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
 AddrDigits := GetAddrDigits;
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
   InstrLen := DecodeInstruction(Off, VAddr, Mnemonic, Operands);
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

{ ============================================================
  OPTION -S : LECTURE DES INFORMATIONS DE DEBOGAGE
  ============================================================
  Couvre deux chaines completement distinctes :
   - ELF : table de lignes DWARF (.debug_line), versions 2 a 4
     (le format DWARF5, qui remplace les tables repertoire/fichier
     par des "formulaires" generiques DW_FORM_*, n est pas pris en
     charge ; il est detecte et signale explicitement).
   - PE : repertoire de debogage IMAGE_DEBUG_DIRECTORY, entree
     CodeView (type 2) au format "RSDS" (PDB 7.0), qui designe un
     fichier .pdb externe ; ce fichier est ensuite lu comme un
     conteneur MSF (Multi-Stream File), pour en extraire le flux
     DBI puis les sous-sections de lignes C13 de chaque module.
  Aucun des deux n a pu etre valide contre un binaire reel produit
  par un compilateur (aucune chaine ELF+gcc/clang ni aucun fichier
  .pdb reel n est disponible dans cet environnement) : la confiance
  repose uniquement sur l encodage manuel de donnees synthetiques
  conformes aux specifications DWARF et PDB/MSF. }

Const
 MaxLineRows     = 16384;  { lignes source->adresse cumulees (-S) }
 MaxIncludeDirs  = 256;
 MaxLineFilesCU  = 256;    { fichiers par unite de compilation DWARF }

Type
 TLineRow = Record
  Addr     : LongInt;
  FileName : String[160]; { resolu immediatement (table par-CU)     }
  Line     : Integer;
 End;

Var
 LineRows        : Array[1..MaxLineRows] Of TLineRow;
 LineRowCount    : Integer;
 DwarfLineFound  : Boolean;
 DwarfSawV5      : Boolean; { au moins une unite DWARF5 ignoree }
 IncludeDirNames : Array[1..MaxIncludeDirs] Of String[160];
 IncludeDirCount : Integer;
 CULineFiles     : Array[1..MaxLineFilesCU] Of String[160];
 CULineFileDirs  : Array[1..MaxLineFilesCU] Of Integer;
 CULineFileCount : Integer;

{ @description: Lit un entier non signe encode en LEB128 a la
    position Off (avancee automatiquement), tronque a 32 bits.
  @param Off (entree/sortie) decalage, avance apres l entier lu
  @return Valeur lue }
Function ReadULEB128(Var Off: LongInt): LongInt;
Var
 ShiftN: Integer;
 B: Byte;
 Acc: LongInt;
Begin
 Acc := 0; ShiftN := 0;
 Repeat
  B := GetByte(Off);
  Inc(Off);
  If ShiftN < 32 Then Acc := Acc Or (LongInt(B And $7F) Shl ShiftN);
  Inc(ShiftN, 7);
 Until (B And $80) = 0;
 ReadULEB128 := Acc;
End;

{ @description: Lit un entier signe encode en LEB128 a la position
    Off (avancee automatiquement), tronque a 32 bits.
  @param Off (entree/sortie) decalage, avance apres l entier lu
  @return Valeur lue }
Function ReadSLEB128(Var Off: LongInt): LongInt;
Var
 ShiftN: Integer;
 B: Byte;
 Acc: LongInt;
Begin
 Acc := 0; ShiftN := 0;
 Repeat
  B := GetByte(Off);
  Inc(Off);
  If ShiftN < 32 Then Acc := Acc Or (LongInt(B And $7F) Shl ShiftN);
  Inc(ShiftN, 7);
 Until (B And $80) = 0;
 If (ShiftN < 32) And ((B And $40) <> 0) Then
  Acc := Acc Or (LongInt(-1) Shl ShiftN);
 ReadSLEB128 := Acc;
End;

{ @description: Resout l index de fichier FIdx (table DWARF de
    l unite de compilation courante, remplie par ParseDwarfUnit) en
    chemin affichable, en prefixant par son repertoire si connu.
  @param FIdx Index 1-based dans CULineFiles
  @return Chemin resolu, ou chaine vide si index invalide }
Function ResolveDwarfFile(FIdx: Integer): String;
Var
 D: Integer;
Begin
 If (FIdx < 1) Or (FIdx > CULineFileCount) Then Begin
  ResolveDwarfFile := '';
  Exit;
 End;
 D := CULineFileDirs[FIdx];
 If (D >= 1) And (D <= IncludeDirCount) Then
  ResolveDwarfFile := IncludeDirNames[D] + '/' + CULineFiles[FIdx]
 Else
  ResolveDwarfFile := CULineFiles[FIdx];
End;

{ @description: Decode le programme de lignes DWARF d une unite de
    compilation (.debug_line), de UnitOff (debut, juste apres le
    champ unit_length deja consomme par l appelant) a UnitEnd
    (exclu), et accumule les lignes resultantes dans LineRows[].
    Les tables repertoire/fichier sont locales a l unite (DWARF
    2-4) : elles sont reinitialisees a chaque appel, et resolues en
    chemin complet immediatement a l emission de chaque ligne, pour
    eviter toute ambiguite d index entre unites differentes.
  @param UnitOff Decalage du champ version (apres unit_length)
  @param UnitEnd Decalage de fin de l unite (exclu) }
Procedure ParseDwarfUnit(UnitOff, UnitEnd: LongInt);
Var
 Off, ProgStart: LongInt;
 Version: Word;
 HeaderLength: LongInt;
 MinInstrLen: Byte;
 LineBase: ShortInt;
 LineRange, OpcodeBase: Byte;
 StdOpLens: Array[1..255] Of Byte;
 I: Integer;
 S: String;
 DirIdx: LongInt;
 Address: LongInt;
 FileReg, LineReg: Integer;
 Opcode: Byte;
 ExtLen, ExtEnd: LongInt;
 SubOp: Byte;
 Adj: Integer;
 Op2: Word;
Begin
 Off := UnitOff;
 Version := GetElfWord(Off); Off := Off + 2;
 If Version >= 5 Then Begin
  DwarfSawV5 := True;
  Exit; { tables dir/fichier par formulaires DW_FORM_* : non gere }
 End;
 HeaderLength := GetElfDWord(Off); Off := Off + 4;
 ProgStart := Off + HeaderLength;
 MinInstrLen := GetByte(Off); Inc(Off);
 If Version >= 4 Then Inc(Off); { maximum_operations_per_instruction }
 Inc(Off); { default_is_stmt : ignore, l etat is_stmt n est pas utilise }
 LineBase := ShortInt(GetByte(Off)); Inc(Off);
 LineRange := GetByte(Off); Inc(Off);
 OpcodeBase := GetByte(Off); Inc(Off);
 For I := 1 To OpcodeBase - 1 Do Begin
  StdOpLens[I] := GetByte(Off); Inc(Off);
 End;
 IncludeDirCount := 0;
 Repeat
  S := GetCStr(Off, 160);
  Off := Off + Length(S) + 1;
  If (S <> '') And (IncludeDirCount < MaxIncludeDirs) Then Begin
   Inc(IncludeDirCount);
   IncludeDirNames[IncludeDirCount] := S;
  End;
 Until S = '';
 CULineFileCount := 0;
 Repeat
  S := GetCStr(Off, 160);
  Off := Off + Length(S) + 1;
  If S <> '' Then Begin
   DirIdx := ReadULEB128(Off);
   ReadULEB128(Off); { mtime, ignore }
   ReadULEB128(Off); { taille du fichier, ignore }
   If CULineFileCount < MaxLineFilesCU Then Begin
    Inc(CULineFileCount);
    CULineFiles[CULineFileCount] := S;
    CULineFileDirs[CULineFileCount] := DirIdx;
   End;
  End;
 Until S = '';
 { La machine a etats du programme de lignes commence a ProgStart
   (annonce par header_length), independamment de la position
   atteinte par l analyse des tables ci-dessus. }
 Off := ProgStart;
 Address := 0; FileReg := 1; LineReg := 1;
 While Off < UnitEnd Do Begin
  Opcode := GetByte(Off); Inc(Off);
  If Opcode = 0 Then Begin { opcode etendu }
   ExtLen := ReadULEB128(Off);
   ExtEnd := Off + ExtLen;
   If ExtLen > 0 Then Begin
    SubOp := GetByte(Off);
    If SubOp = 1 Then Begin { DW_LNE_end_sequence }
     Address := 0; FileReg := 1; LineReg := 1;
    End Else If SubOp = 2 Then Begin { DW_LNE_set_address }
     Address := GetElfDWord(Off + 1);
    End;
    { DW_LNE_define_file / DW_LNE_set_discriminator : ignores }
   End;
   Off := ExtEnd;
  End Else If Opcode < OpcodeBase Then Begin { opcode standard }
   Case Opcode Of
    1: Begin { DW_LNS_copy }
     If LineRowCount < MaxLineRows Then Begin
      Inc(LineRowCount);
      LineRows[LineRowCount].Addr := Address;
      LineRows[LineRowCount].FileName := ResolveDwarfFile(FileReg);
      LineRows[LineRowCount].Line := LineReg;
     End;
    End;
    2: Address := Address + ReadULEB128(Off) * MinInstrLen;
    3: LineReg := LineReg + ReadSLEB128(Off);
    4: FileReg := ReadULEB128(Off);
    5: ReadULEB128(Off); { set_column, ignore }
    6, 7, 10, 11: ; { negate_stmt/basic_block/prologue/epilogue : ignores }
    8: Begin { DW_LNS_const_add_pc }
     Adj := 255 - OpcodeBase;
     Address := Address + (Adj Div LineRange) * MinInstrLen;
    End;
    9: Begin { DW_LNS_fixed_advance_pc }
     Op2 := GetElfWord(Off); Off := Off + 2;
     Address := Address + Op2;
    End;
    12: ReadULEB128(Off); { set_isa, ignore }
   Else
    For I := 1 To StdOpLens[Opcode] Do ReadULEB128(Off);
   End;
  End Else Begin { opcode special }
   Adj := Opcode - OpcodeBase;
   Address := Address + (Adj Div LineRange) * MinInstrLen;
   LineReg := LineReg + LineBase + (Adj Mod LineRange);
   If LineRowCount < MaxLineRows Then Begin
    Inc(LineRowCount);
    LineRows[LineRowCount].Addr := Address;
    LineRows[LineRowCount].FileName := ResolveDwarfFile(FileReg);
    LineRows[LineRowCount].Line := LineReg;
   End;
  End;
 End;
End;

{ @description: Localise la section ".debug_line" et decode chacune
    de ses unites de compilation (en boucle, jusqu a epuisement de
    la section), pour remplir LineRows[]. Sans effet si la section
    est absente ou si le format n est pas ELF. }
Procedure LoadDwarfLineTable;
Var
 SI: Integer;
 SecOff, SecEnd, Off, UnitLen, UnitEnd: LongInt;
Begin
 LineRowCount := 0;
 DwarfLineFound := False;
 DwarfSawV5 := False;
 SI := FindSectionByName('.debug_line');
 If SI = 0 Then Exit;
 SecOff := Sections[SI].FileOff;
 SecEnd := SecOff + Sections[SI].Size;
 Off := SecOff;
 While Off + 4 <= SecEnd Do Begin
  UnitLen := GetElfDWord(Off);
  If UnitLen <= 0 Then Break;
  UnitEnd := Off + 4 + UnitLen;
  If UnitEnd > SecEnd Then Break;
  ParseDwarfUnit(Off + 4, UnitEnd);
  Off := UnitEnd;
 End;
 DwarfLineFound := LineRowCount > 0;
End;

{ @description: Cherche, parmi les lignes accumulees dans
    LineRows[], celle dont l adresse est la plus grande valeur
    inferieure ou egale a VAddr (recherche du "plancher"), c est a
    dire la ligne source active a cette adresse.
  @param VAddr Adresse virtuelle recherchee
  @param FName (sortie) chemin du fichier source resolu
  @param LineNo (sortie) numero de ligne
  @return Vrai si une correspondance a ete trouvee }
Function FindLineForAddr(VAddr: LongInt; Var FName: String;
 Var LineNo: Integer): Boolean;
Var
 I, Best: Integer;
Begin
 Best := 0;
 For I := 1 To LineRowCount Do
  If (LineRows[I].Addr <= VAddr) And
     ((Best = 0) Or (LineRows[I].Addr > LineRows[Best].Addr)) Then
   Best := I;
 If Best = 0 Then Begin
  FindLineForAddr := False;
 End Else Begin
  FName := LineRows[Best].FileName;
  LineNo := LineRows[Best].Line;
  FindLineForAddr := True;
 End;
End;

{ ============================================================
  OPTION -S (PE) : CODEVIEW (RSDS) + PDB/MSF EXTERNE
  ============================================================
  Le PE n embarque presque jamais les lignes elles-memes : son
  repertoire de debogage (IMAGE_DEBUG_DIRECTORY, entree de type 2 =
  CODEVIEW) contient un enregistrement "RSDS" qui ne fait que
  DESIGNER un fichier .pdb externe par son chemin (le plus souvent
  un chemin absolu de la machine de compilation d origine). Ce
  fichier .pdb est lui-meme un conteneur "MSF" (Multi-Stream File) :
  un super-bloc, un repertoire de flux (liste de blocs par flux),
  puis des flux numerotes dont le flux 3 (fixe par convention) est
  le flux "DBI" (debug info), qui liste les modules et, pour
  chacun, le flux prive contenant ses symboles et ses sous-sections
  de lignes au format "C13" (DEBUG_S_LINES / DEBUG_S_FILECHKSMS /
  DEBUG_S_STRINGTABLE). Les lignes resolues sont fusionnees dans le
  meme tableau LineRows[] que le chemin DWARF, et reutilisent donc
  FindLineForAddr/ReadSourceLine sans changement.
  Confiance : la plus faible de tout ce fichier. Le format MSF/PDB
  n est documente que par la source du projet Microsoft-PDB et par
  LLVM ; aucun fichier .pdb reel n a pu etre obtenu dans cet
  environnement pour validation. Seul un aller-retour avec un
  fichier .pdb synthetique, encode a la main selon la specification
  telle que je m en souviens, a pu etre verifie. }

Const
 MaxPdbDirBlocks = 256;

Var
 PdbBuf         : PByteBuf;
 PdbBufSize     : LongInt;
 MsfBlockSize   : LongInt;
 MsfDirBlockList: Array[0..MaxPdbDirBlocks - 1] Of LongInt;
 MsfDirBlockCnt : Integer;

Function GetPdbByte(Off: LongInt): Byte;
Begin
 If (Off < 0) Or (Off >= PdbBufSize) Then GetPdbByte := 0
 Else GetPdbByte := PdbBuf^[Off];
End;

Function GetPdbDWord(Off: LongInt): LongInt;
Var
 B: Array[0..3] Of Byte;
 I: Integer;
 R: LongInt;
Begin
 For I := 0 To 3 Do B[I] := GetPdbByte(Off + I);
 Move(B, R, 4);
 GetPdbDWord := R;
End;

Function CeilDivLong(A, B: LongInt): LongInt;
Begin
 CeilDivLong := (A + B - 1) Div B;
End;

{ @description: Lit un octet du repertoire de flux MSF (le tableau
    NumStreams/StreamSizes[]/blocs-par-flux), via sa propre liste de
    blocs (MsfDirBlockList, remplie par OpenPdbSuperblock).
  @param LogicalOff Decalage logique (0-based) dans le repertoire
  @return Octet lu, ou 0 si hors limites }
Function MsfDirByte(LogicalOff: LongInt): Byte;
Var
 BlkIdx: LongInt;
Begin
 BlkIdx := LogicalOff Div MsfBlockSize;
 If (BlkIdx < 0) Or (BlkIdx >= MsfDirBlockCnt) Then Begin
  MsfDirByte := 0;
  Exit;
 End;
 MsfDirByte := GetPdbByte(MsfDirBlockList[BlkIdx] * MsfBlockSize +
  (LogicalOff Mod MsfBlockSize));
End;

Function MsfDirDWord(LogicalOff: LongInt): LongInt;
Var
 B: Array[0..3] Of Byte;
 I: Integer;
 R: LongInt;
Begin
 For I := 0 To 3 Do B[I] := MsfDirByte(LogicalOff + I);
 Move(B, R, 4);
 MsfDirDWord := R;
End;

Function MsfStreamCount: LongInt;
Begin
 MsfStreamCount := MsfDirDWord(0);
End;

{ @description: Taille en octets du flux Idx (0-based), d apres le
    repertoire de flux MSF.
  @param Idx Index de flux
  @return Taille en octets ($FFFFFFFF = flux nul/absent) }
Function MsfStreamSize(Idx: LongInt): LongInt;
Begin
 MsfStreamSize := MsfDirDWord(4 + Idx * 4);
End;

{ @description: Calcule le decalage logique, dans le repertoire de
    flux, ou commence la liste des numeros de bloc du flux Idx (en
    sommant le nombre de blocs de tous les flux precedents).
  @param Idx Index de flux
  @return Decalage logique dans le repertoire }
Function MsfStreamBlockListOff(Idx: LongInt): LongInt;
Var
 N, I, Acc, Sz: LongInt;
Begin
 N := MsfStreamCount;
 Acc := 0;
 For I := 0 To Idx - 1 Do Begin
  Sz := MsfStreamSize(I);
  If Sz = LongInt($FFFFFFFF) Then Sz := 0;
  Acc := Acc + CeilDivLong(Sz, MsfBlockSize);
 End;
 MsfStreamBlockListOff := 4 + N * 4 + Acc * 4;
End;

Function MsfStreamBlockNum(Idx, BlockIdxInStream: LongInt): LongInt;
Begin
 MsfStreamBlockNum := MsfDirDWord(MsfStreamBlockListOff(Idx) +
  BlockIdxInStream * 4);
End;

{ @description: Lit un octet logique d un flux MSF quelconque, en
    traduisant via sa liste de blocs (elle-meme lue dans le
    repertoire de flux a la demande, sans mise en cache).
  @param Idx Index de flux
  @param LogicalOff Decalage logique (0-based) dans le flux
  @return Octet lu }
Function MsfStreamByte(Idx, LogicalOff: LongInt): Byte;
Var
 BlkNum: LongInt;
Begin
 BlkNum := MsfStreamBlockNum(Idx, LogicalOff Div MsfBlockSize);
 MsfStreamByte := GetPdbByte(BlkNum * MsfBlockSize +
  (LogicalOff Mod MsfBlockSize));
End;

Function MsfStreamWord(Idx, Off: LongInt): Word;
Begin
 MsfStreamWord := MsfStreamByte(Idx, Off) Or
  (MsfStreamByte(Idx, Off + 1) Shl 8);
End;

Function MsfStreamDWord(Idx, Off: LongInt): LongInt;
Var
 B: Array[0..3] Of Byte;
 I: Integer;
 R: LongInt;
Begin
 For I := 0 To 3 Do B[I] := MsfStreamByte(Idx, Off + I);
 Move(B, R, 4);
 MsfStreamDWord := R;
End;

Function MsfStreamCStr(Idx, Off: LongInt; MaxLen: Integer): String;
Var
 S: String;
 B: Byte;
Begin
 S := '';
 While Length(S) < MaxLen Do Begin
  B := MsfStreamByte(Idx, Off + Length(S));
  If B = 0 Then Break;
  S := S + Chr(B);
 End;
 MsfStreamCStr := S;
End;

{ @description: Charge un fichier .pdb en memoire (PdbBuf), sans
    interrompre le programme en cas d echec (a la difference de
    LoadFile, utilisee pour le fichier principal).
  @param FName Chemin du fichier .pdb
  @return Vrai si le fichier a ete charge avec succes }
Function LoadPdbFile(FName: String): Boolean;
Var
 F: File;
 NRead: LongInt;
Begin
 LoadPdbFile := False;
 Assign(F, FName);
 FileMode := 0;
 {$I-} Reset(F, 1); {$I+}
 If IOResult <> 0 Then Exit;
 PdbBufSize := FileSize(F);
 If PdbBufSize <= 56 Then Begin Close(F); Exit; End;
 GetMem(PdbBuf, PdbBufSize);
 {$I-} BlockRead(F, PdbBuf^, PdbBufSize, NRead); {$I+}
 Close(F);
 If NRead <> PdbBufSize Then Exit;
 LoadPdbFile := True;
End;

{ @description: Verifie la signature MSF ("Microsoft C/C++ MSF
    7.00...") et remplit MsfBlockSize/MsfDirBlockList a partir du
    super-bloc (32 premiers octets de signature, puis BlockSize,
    NumDirectoryBytes et BlockMapAddr).
  @return Vrai si le super-bloc est valide et exploitable }
Function OpenPdbSuperblock: Boolean;
Const
 PdbMagic: Array[0..31] Of Byte = (
  $4D, $69, $63, $72, $6F, $73, $6F, $66, $74, $20, $43, $2F, $43,
  $2B, $2B, $20, $4D, $53, $46, $20, $37, $2E, $30, $30, $0D, $0A,
  $1A, $44, $53, $00, $00, $00);
Var
 I: Integer;
 NumDirBytes, BlockMapAddr: LongInt;
Begin
 OpenPdbSuperblock := False;
 For I := 0 To 31 Do
  If GetPdbByte(I) <> PdbMagic[I] Then Exit;
 MsfBlockSize := GetPdbDWord(32);
 If MsfBlockSize <= 0 Then Exit;
 NumDirBytes := GetPdbDWord(44);
 BlockMapAddr := GetPdbDWord(52);
 MsfDirBlockCnt := CeilDivLong(NumDirBytes, MsfBlockSize);
 If (MsfDirBlockCnt <= 0) Or (MsfDirBlockCnt > MaxPdbDirBlocks) Then Exit;
 For I := 0 To MsfDirBlockCnt - 1 Do
  MsfDirBlockList[I] := GetPdbDWord(BlockMapAddr * MsfBlockSize + I * 4);
 OpenPdbSuperblock := True;
End;

{ @description: Decode une sous-section DEBUG_S_LINES (C13) du flux
    prive d un module, et ajoute les lignes resolues a LineRows[].
    Le nom de fichier est resolu via DEBUG_S_FILECHKSMS puis
    DEBUG_S_STRINGTABLE (offsets ChksmsOff/StrTabOff, deja localises
    par l appelant). Les colonnes (fHasColumns) ne sont pas lues
    (hors de portee, non necessaires pour -S).
  @param StreamIdx Flux prive du module (ModuleSymStream)
  @param Start Decalage logique du contenu de la sous-section
  @param Len Longueur de la sous-section
  @param ChksmsOff Decalage logique de DEBUG_S_FILECHKSMS (-1 si absente)
  @param StrTabOff Decalage logique de DEBUG_S_STRINGTABLE (-1 si absente) }
Procedure ParseLinesSubsection(StreamIdx: Integer;
 Start, Len, ChksmsOff, StrTabOff: LongInt);
Var
 BaseOffset: LongInt;
 Pos, EndPos: LongInt;
 FileChkOff, NumLines, BlockSize: LongInt;
 I: Integer;
 LineOff, LineNumField: LongInt;
 LineNo: Integer;
 FName: String;
 NameOff: LongInt;
Begin
 BaseOffset := MsfStreamDWord(StreamIdx, Start);
 { CodeSize a Start+8 : non utilise, l etendue n est pas necessaire
   pour resoudre une adresse en ligne source }
 Pos := Start + 12;
 EndPos := Start + Len;
 While Pos + 12 <= EndPos Do Begin
  FileChkOff := MsfStreamDWord(StreamIdx, Pos);
  NumLines   := MsfStreamDWord(StreamIdx, Pos + 4);
  BlockSize  := MsfStreamDWord(StreamIdx, Pos + 8);
  If BlockSize <= 0 Then Break; { protection anti-boucle infinie }
  FName := '';
  If (ChksmsOff >= 0) And (StrTabOff >= 0) Then Begin
   NameOff := MsfStreamDWord(StreamIdx, ChksmsOff + FileChkOff);
   FName := MsfStreamCStr(StreamIdx, StrTabOff + NameOff, 160);
  End;
  For I := 0 To NumLines - 1 Do Begin
   LineOff := MsfStreamDWord(StreamIdx, Pos + 12 + I * 8);
   LineNumField := MsfStreamDWord(StreamIdx, Pos + 12 + I * 8 + 4);
   LineNo := LineNumField And $00FFFFFF;
   If LineRowCount < MaxLineRows Then Begin
    Inc(LineRowCount);
    { Les adresses C13 sont des RVA (relatives a l image, hors
      ImageBase), alors que Sections[].VAddr (et donc VAddr passe a
      FindLineForAddr) inclut deja ImageBase partout ailleurs dans
      cet outil : conversion necessaire pour rester comparable. }
    LineRows[LineRowCount].Addr := ImageBase + BaseOffset + LineOff;
    LineRows[LineRowCount].FileName := FName;
    LineRows[LineRowCount].Line := LineNo;
   End;
  End;
  Pos := Pos + BlockSize;
 End;
End;

{ @description: Parcourt les sous-sections C13 (DEBUG_S_*) du flux
    prive d un module, en deux passes : la premiere localise
    DEBUG_S_FILECHKSMS et DEBUG_S_STRINGTABLE (necessaires pour
    resoudre les noms de fichiers, qui peuvent apparaitre apres
    DEBUG_S_LINES dans le flux), la seconde decode DEBUG_S_LINES.
  @param StreamIdx Flux prive du module (ModuleSymStream)
  @param C13Start Decalage logique du debut des donnees C13
  @param C13Size Longueur des donnees C13 }
Procedure ParseModuleC13(StreamIdx: Integer; C13Start, C13Size: LongInt);
Var
 Off, EndOff: LongInt;
 SubType, SubLen: LongInt;
 ChksmsOff, StrTabOff: LongInt;
Begin
 ChksmsOff := -1; StrTabOff := -1;
 Off := C13Start;
 EndOff := C13Start + C13Size;
 While Off + 8 <= EndOff Do Begin
  SubType := MsfStreamDWord(StreamIdx, Off);
  SubLen  := MsfStreamDWord(StreamIdx, Off + 4);
  If SubLen < 0 Then Break;
  If SubType = $F4 Then ChksmsOff := Off + 8
  Else If SubType = $F3 Then StrTabOff := Off + 8;
  Off := Off + 8 + SubLen;
  While (Off Mod 4) <> 0 Do Inc(Off);
 End;
 Off := C13Start;
 While Off + 8 <= EndOff Do Begin
  SubType := MsfStreamDWord(StreamIdx, Off);
  SubLen  := MsfStreamDWord(StreamIdx, Off + 4);
  If SubLen < 0 Then Break;
  If SubType = $F2 Then
   ParseLinesSubsection(StreamIdx, Off + 8, SubLen, ChksmsOff, StrTabOff);
  Off := Off + 8 + SubLen;
  While (Off Mod 4) <> 0 Do Inc(Off);
 End;
End;

{ @description: Parcourt la sous-section "Module Info" du flux DBI
    (stream 3), et pour chaque module dote d un flux prive et de
    donnees C13, appelle ParseModuleC13. Le format de l entete DBI
    (64 octets) et de chaque enregistrement de module suit la
    documentation publique du format PDB (Microsoft-PDB / LLVM).
  @param DbiStreamIdx Index du flux DBI (toujours 3) }
Procedure ParseDbiModules(DbiStreamIdx: Integer);
Var
 ModInfoSize: LongInt;
 Off, EndOff: LongInt;
 ModuleSymStream: Word;
 SymSize, C11Size, C13Size: LongInt;
 S: String;
Begin
 ModInfoSize := MsfStreamDWord(DbiStreamIdx, 24);
 Off := 64;
 EndOff := 64 + ModInfoSize;
 While Off + 36 < EndOff Do Begin
  Off := Off + 4;  { Unused1 }
  Off := Off + 28; { SECTION_CONTRIB }
  Off := Off + 2;  { Flags }
  ModuleSymStream := Word(MsfStreamWord(DbiStreamIdx, Off)); Off := Off + 2;
  SymSize  := MsfStreamDWord(DbiStreamIdx, Off); Off := Off + 4;
  C11Size  := MsfStreamDWord(DbiStreamIdx, Off); Off := Off + 4;
  C13Size  := MsfStreamDWord(DbiStreamIdx, Off); Off := Off + 4;
  Off := Off + 2; { SourceFileCount }
  Off := Off + 2; { Padding }
  Off := Off + 4; { SourceFileNameIndex }
  Off := Off + 4; { PdbFilePathNameIndex }
  S := MsfStreamCStr(DbiStreamIdx, Off, 255); Off := Off + Length(S) + 1;
  S := MsfStreamCStr(DbiStreamIdx, Off, 255); Off := Off + Length(S) + 1;
  While (Off Mod 4) <> 0 Do Inc(Off);
  If (ModuleSymStream <> $FFFF) And (C13Size > 0) Then
   ParseModuleC13(ModuleSymStream, SymSize + C11Size, C13Size);
 End;
End;

{ @description: Point d entree du chargement PDB : ouvre le
    fichier, verifie le super-bloc MSF, puis decode le flux DBI
    (toujours l index 3) pour fusionner toutes les lignes C13 de
    tous les modules dans LineRows[].
  @param PdbPath Chemin du fichier .pdb a charger
  @return Vrai si au moins une ligne a ete trouvee }
Function LoadPdbLineTable(PdbPath: String): Boolean;
Var
 DbiSize: LongInt;
Begin
 LineRowCount := 0;
 LoadPdbLineTable := False;
 If Not LoadPdbFile(PdbPath) Then Exit;
 If Not OpenPdbSuperblock Then Begin
  FreeMem(PdbBuf, PdbBufSize);
  Exit;
 End;
 DbiSize := MsfStreamSize(3);
 If (DbiSize > 0) And (DbiSize <> LongInt($FFFFFFFF)) Then
  ParseDbiModules(3);
 FreeMem(PdbBuf, PdbBufSize);
 LoadPdbLineTable := LineRowCount > 0;
End;

{ @description: Localise l entree CodeView (type 2, format "RSDS")
    du repertoire de debogage PE, et en extrait le chemin du
    fichier .pdb externe qu elle designe.
  @return Chemin .pdb tel qu enregistre a la compilation, ou chaine
    vide si aucune entree CodeView/RSDS n a ete trouvee }
Function FindPECodeViewPdbPath: String;
Var
 PEOff, OptOff, DataDirOff: LongInt;
 DebugRVA, DebugSize, TableOff: LongInt;
 NumEntries, I: Integer;
 EntryOff, EntryType, PtrRaw, Sig: LongInt;
Begin
 FindPECodeViewPdbPath := '';
 PEOff := GetDWord($3C);
 OptOff := PEOff + 24;
 If BinFormat = FMT_PE64 Then DataDirOff := OptOff + 160
 Else DataDirOff := OptOff + 144;
 DebugRVA := GetDWord(DataDirOff);
 DebugSize := GetDWord(DataDirOff + 4);
 If DebugSize <= 0 Then Exit;
 TableOff := PERvaToFile(DebugRVA);
 If TableOff < 0 Then Exit;
 NumEntries := DebugSize Div 28;
 For I := 0 To NumEntries - 1 Do Begin
  EntryOff := TableOff + I * 28;
  EntryType := GetDWord(EntryOff + 12);
  If EntryType = 2 Then Begin { IMAGE_DEBUG_TYPE_CODEVIEW }
   PtrRaw := GetDWord(EntryOff + 24);
   Sig := GetDWord(PtrRaw);
   If Sig = $53445352 Then Begin { 'RSDS' }
    FindPECodeViewPdbPath := GetCStr(PtrRaw + 24, 260);
    Exit;
   End;
  End;
 End;
End;

{ @description: Renvoie le nom de fichier seul (sans repertoire) a
    partir d un chemin pouvant utiliser "/" ou "\".
  @param P Chemin complet ou partiel
  @return Composante finale de P }
Function ExtractBaseName(P: String): String;
Var
 I: Integer;
Begin
 For I := Length(P) DownTo 1 Do
  If (P[I] = '/') Or (P[I] = '\') Then Begin
   ExtractBaseName := Copy(P, I + 1, Length(P) - I);
   Exit;
  End;
 ExtractBaseName := P;
End;

{ @description: Renvoie le repertoire (avec separateur final) d un
    chemin, ou chaine vide si P ne contient aucun separateur.
  @param P Chemin complet ou partiel
  @return Repertoire de P, separateur final inclus }
Function DirOf(P: String): String;
Var
 I: Integer;
Begin
 For I := Length(P) DownTo 1 Do
  If (P[I] = '/') Or (P[I] = '\') Then Begin
   DirOf := Copy(P, 1, I);
   Exit;
  End;
 DirOf := '';
End;

{ @description: Tente de lire la ligne LineNo (1-based) du fichier
    source FName, en essayant successivement le chemin tel que
    fourni par les informations de debogage (souvent un chemin
    absolu de la machine de compilation d origine, donc rarement
    valide ici), puis le meme nom de base dans le repertoire du
    binaire analyse, puis dans le repertoire courant. Echec
    silencieux (chaine vide) si le fichier reste introuvable : -S
    affiche alors la reference fichier:ligne sans le texte source.
  @param FName Chemin du fichier source (issu du debogage)
  @param LineNo Numero de ligne (1-based)
  @return Texte de la ligne, ou chaine vide si indisponible }
Function ReadSourceLine(FName: String; LineNo: Integer): String;
Var
 F: Text;
 Candidate, LineTxt: String;
 L: Integer;
 Opened: Boolean;
Begin
 ReadSourceLine := '';
 If (LineNo <= 0) Or (FName = '') Then Exit;
 Candidate := FName;
 {$I-} Assign(F, Candidate); Reset(F); {$I+}
 Opened := IOResult = 0;
 If Not Opened Then Begin
  Candidate := DirOf(InFileName) + ExtractBaseName(FName);
  {$I-} Assign(F, Candidate); Reset(F); {$I+}
  Opened := IOResult = 0;
 End;
 If Not Opened Then Begin
  Candidate := ExtractBaseName(FName);
  {$I-} Assign(F, Candidate); Reset(F); {$I+}
  Opened := IOResult = 0;
 End;
 If Not Opened Then Exit;
 L := 0;
 While (Not Eof(F)) And (L < LineNo) Do Begin
  {$I-} ReadLn(F, LineTxt); {$I+}
  If IOResult <> 0 Then Break;
  Inc(L);
 End;
 Close(F);
 If L = LineNo Then ReadSourceLine := LineTxt;
End;

{ @description: Implemente l affichage -S commun aux deux sources
    de lignes (DWARF pour ELF, PDB pour PE) : desassemble comme
    CmdDisasm, mais affiche d abord la reference fichier:ligne (et
    le texte source si le fichier est accessible sur disque) chaque
    fois que la ligne active change. LineRows[] (rempli au prealable
    par LoadDwarfLineTable ou LoadPdbLineTable) est la seule donnee
    partagee entre les deux chemins.
  @param SourceKind Libelle affiche dans l en-tete ("DWARF" ou "PDB") }
Procedure CmdSourceMixGeneric(SourceKind: String);
Var
 SI: Integer;
 Off, VAddr, EndAddr: LongInt;
 InstrLen, K, AddrDigits: Integer;
 Mnemonic, Operands, BytesTxt, Lbl: String;
 CurFile, LastFile, SrcTxt: String;
 CurLine, LastLine: Integer;
 Have: Boolean;
Begin
 AddrDigits := GetAddrDigits;
 LastFile := ''; LastLine := -1; { force l affichage de la 1ere ligne }
 WriteLn;
 WriteLn(InFileName, ':     format ', FormatName, ' (avec table de lignes ',
  SourceKind, ')');
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
   Have := FindLineForAddr(VAddr, CurFile, CurLine);
   If Have And ((CurFile <> LastFile) Or (CurLine <> LastLine)) Then Begin
    WriteLn;
    SrcTxt := ReadSourceLine(CurFile, CurLine);
    If SrcTxt <> '' Then
     WriteLn(CurFile, ':', IntToStr(CurLine), ': ', SrcTxt)
    Else
     WriteLn(CurFile, ':', IntToStr(CurLine), ': (source indisponible)');
    LastFile := CurFile;
    LastLine := CurLine;
   End;
   InstrLen := DecodeInstruction(Off, VAddr, Mnemonic, Operands);
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

{ @description: Implemente l option -S : melange source/assembleur
    pour ELF (DWARF .debug_line) et PE (CodeView/RSDS + PDB
    externe) ; pour les autres formats, signale explicitement
    l etat du support plutot que d afficher un faux resultat. }
Procedure CmdSourceMix;
Var
 PdbPath, Candidate: String;
Begin
 If (BinFormat = FMT_ELF32) Or (BinFormat = FMT_ELF64) Then Begin
  LoadDwarfLineTable;
  If DwarfLineFound Then Begin
   CmdSourceMixGeneric('DWARF');
   Exit;
  End;
  WriteLn;
  If DwarfSawV5 Then
   WriteLn('Option -S : table de lignes DWARF version 5 detectee, ',
    'mais ce format (tables repertoire/fichier par formulaires) ',
    'n''est pas pris en charge.')
  Else
   WriteLn('Option -S : aucune information de debogage DWARF ',
    '(.debug_line) trouvee dans ce fichier ELF. Recompilez avec ',
    '-g pour en generer.');
  WriteLn('Utilisez -d pour le desassemblage seul.');
  Exit;
 End Else If (BinFormat = FMT_PE32) Or (BinFormat = FMT_PE64) Then Begin
  PdbPath := FindPECodeViewPdbPath;
  If PdbPath = '' Then Begin
   WriteLn;
   WriteLn('Option -S : aucune entree de debogage CodeView (RSDS) ',
    'trouvee dans ce fichier PE. Recompilez/relinkez avec les ',
    'informations de debogage actives (/Zi /DEBUG).');
   WriteLn('Utilisez -d pour le desassemblage seul.');
   Exit;
  End;
  { Le chemin .pdb enregistre par le lieur est presque toujours
    celui de la machine de compilation d origine : on essaie aussi
    le meme nom de base a cote du PE analyse, puis dans le
    repertoire courant. }
  If (Not LoadPdbLineTable(PdbPath)) Then Begin
   Candidate := DirOf(InFileName) + ExtractBaseName(PdbPath);
   If Not LoadPdbLineTable(Candidate) Then
    LoadPdbLineTable(ExtractBaseName(PdbPath));
  End;
  If LineRowCount > 0 Then Begin
   CmdSourceMixGeneric('PDB');
   Exit;
  End;
  WriteLn;
  WriteLn('Option -S : entree CodeView trouvee, pointant vers "',
   PdbPath, '", mais ce fichier .pdb n''a pas pu etre ouvert ou ',
   'ne contenait aucune ligne exploitable (chemin absolu de la ',
   'machine de compilation d''origine, probablement introuvable ici).');
  WriteLn('Utilisez -d pour le desassemblage seul.');
  Exit;
 End;
 WriteLn;
 WriteLn('Option -S non supportee pour ce format de fichier :');
 WriteLn('le melange source/assembleur necessite de lire les');
 WriteLn('informations de debogage (DWARF pour ELF, CodeView/PDB');
 WriteLn('pour PE), et seuls ces deux cas sont pris en charge ici.');
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
 WriteLn('  -S       Melange source/assembleur : DWARF .debug_line');
 WriteLn('           pour ELF, CodeView/RSDS + PDB externe pour PE');
 WriteLn('  -m arch  Force l''architecture de desassemblage :');
 WriteLn('           i386 (defaut), x86-64, 8086, 8080, 6502, z80, 6800,');
 WriteLn('           68000, sparc, sparcv9, mips, mipsel, ppc, ppcle,');
 WriteLn('           sh, shle, ia64, pcode, msil, jasmin, llvm, arm,');
 WriteLn('           thumb');
 WriteLn('           ou arm64');
 WriteLn('  -b adr   Adresse de chargement (hexa) pour un binaire');
 WriteLn('           brut sans entete, ex: -b 8000 ou -b $8000');
 WriteLn('  -?       Aide sur cette commande');
 WriteLn;
 WriteLn('Formats supportes : ELF32/ELF64 (Linux), PE32/PE32+ (Windows),');
 WriteLn('Mach-O 32/64 bits (macOS, dont binaires universels "fat"),');
 WriteLn('EXE DOS reel (entete MZ), ROM NES (entete iNES), fichier');
 WriteLn('objet COFF brut (.o/.obj, sans MZ/PE), bibliotheque statique');
 WriteLn('"ar" (.a, chaque membre traite comme un fichier independant),');
 WriteLn('binaire brut (avec -m). L''architecture est choisie automatiquement');
 WriteLn('a partir de e_machine (ELF), Machine (PE) ou cputype (Mach-O).');
 WriteLn('Desassemblage : x86 32 bits / x86-64 (syntaxe AT&T, comme');
 WriteLn('objdump) ; 8086/80186 16 bits (syntaxe Intel/MASM) ; Intel');
 WriteLn('8080 complet (syntaxe Intel) ; 6502 complet (151 opcodes) ;');
 WriteLn('Z80 (jeu de base complet, plus un');
 WriteLn('sous-ensemble pratique de CB/ED/DD/FD) ; Motorola 6800');
 WriteLn('(jeu d''instructions complet) ; Motorola 68000 (jeu utilisateur');
 WriteLn('complet, sans 68010/68020+/FPU/MMU) ; ARM 32 bits classique,');
 WriteLn('Thumb/Thumb-2 (sous-ensemble), AArch64 (sous-ensemble) et');
 WriteLn('SPARC V8/V8+ avec le noyau entier commun SPARC V9 ; MIPS');
 WriteLn('I/II et MIPS32 ; PowerPC 32 et noyau entier PowerPC 64,');
 WriteLn('gros-boutiste ou little-endian ; SuperH SH-1/SH-2/SH-3/SH-4 ;');
 WriteLn('IA-64 structurel ; p-Code UCSD p-System II.0/II.1 ; MSIL/CIL');
 WriteLn('avec extraction automatique des methodes des assemblies .NET ;');
 WriteLn('bytecode JVM/Jasmin avec extraction des methodes des .class ;');
 WriteLn('bitcode LLVM structurel (blocs, abbreviations et records).');
 WriteLn('Pas de SSE/AVX/NEON/VFP, pas d''opcodes etendus 0F pour le');
 WriteLn('8086, pas de DDCB/FDCB pour le Z80.');
End;

{ @description: Analyse le tampon courant (Buf/BufSize, deja passe
    par DetectFormat) : parse le format reconnu, choisit Arch
    automatiquement (sauf si -m a ete passe), puis execute les
    commandes demandees (-h/-t/-S/-d). Factorise pour etre reutilise
    a la fois pour le fichier principal et, membre par membre, pour
    une bibliotheque .a.
  @param FailHard Si vrai, un format non reconnu arrete le programme
    (comportement historique pour un fichier unique) ; si faux,
    signale simplement et renvoie Faux, pour permettre de passer au
    membre d archive suivant sans interrompre tout le traitement
  @return Faux si le format n a pas pu etre traite (seulement
    possible si FailHard est faux) }
Function AnalyzeBuffer(FailHard: Boolean): Boolean;
Begin
 AnalyzeBuffer := True;
 If Not ArchForced Then Arch := ARCH_X86; { evite toute fuite d etat
   entre deux appels successifs (membres d archive consecutifs) }

 If BinFormat = FMT_NES Then Begin
  ParseNES;
  If Not ArchForced Then Arch := ARCH_6502; { detection automatique }
 End Else If BinFormat = FMT_MZ Then Begin
  ParseMZ;
  If Not ArchForced Then Arch := ARCH_8086; { detection automatique }
 End Else If BinFormat = FMT_CLASS Then Begin
  ParseJavaClass;
  If Not ArchForced Then Arch := ARCH_JVM;
 End Else If BinFormat = FMT_LLVMBC Then Begin
  ParseRaw;
  If Not ArchForced Then Arch := ARCH_LLVM;
 End Else If (BinFormat = FMT_ELF32) Or (BinFormat = FMT_ELF64) Then Begin
  ParseELF;
  If Not ArchForced Then Begin
   If ElfMachine = EM_AARCH64 Then Arch := ARCH_ARM64
   Else If ElfMachine = EM_ARM Then Arch := ARCH_ARM32
   Else If ElfMachine = EM_68K Then Arch := ARCH_68000
   Else If (ElfMachine = EM_SPARC) Or (ElfMachine = EM_SPARC32PLUS) Or
           (ElfMachine = EM_SPARCV9) Then Arch := ARCH_SPARC
   Else If ElfMachine = EM_MIPS Then Begin
    If ElfBigEndian Then Arch := ARCH_MIPS Else Arch := ARCH_MIPSEL;
   End
   Else If (ElfMachine = EM_PPC) Or (ElfMachine = EM_PPC64) Then Begin
    If ElfBigEndian Then Arch := ARCH_PPC Else Arch := ARCH_PPCLE;
   End
   Else If ElfMachine = EM_SH Then Begin
    If ElfBigEndian Then Arch := ARCH_SH Else Arch := ARCH_SHLE;
   End
   Else If ElfMachine = EM_IA_64 Then Begin
    If ElfBigEndian Then Arch := ARCH_IA64BE Else Arch := ARCH_IA64;
   End
   Else If BinFormat = FMT_ELF64 Then Arch := ARCH_X64;
   { ELF32 sans e_machine ARM reconnu : on laisse ARCH_X86 par defaut,
     comme avant la prise en charge d e_machine. }
  End;
 End Else If (BinFormat = FMT_PE32) Or (BinFormat = FMT_PE64) Then Begin
  ParsePE;
  If ArchForced Then Begin
   If Arch = ARCH_MSIL Then ParseMSILPE;
  End Else Begin
   If ParseMSILPE Then Arch := ARCH_MSIL
   Else Begin
    If PEMachine = PE_MACHINE_ARM64 Then Arch := ARCH_ARM64
    Else If PEMachine = PE_MACHINE_ARMNT Then Arch := ARCH_THUMB
    Else If PEMachine = PE_MACHINE_ARM Then Arch := ARCH_ARM32
    Else If BinFormat = FMT_PE64 Then Arch := ARCH_X64;
   End;
  End;
 End Else If BinFormat = FMT_COFFOBJ Then Begin
  ParseCoffObj;
  If Not ArchForced Then Begin
   If PEMachine = $8664 Then Arch := ARCH_X64
   Else If PEMachine = PE_MACHINE_ARM64 Then Arch := ARCH_ARM64
   Else If PEMachine = PE_MACHINE_ARMNT Then Arch := ARCH_THUMB
   Else If PEMachine = PE_MACHINE_ARM Then Arch := ARCH_ARM32;
   { sinon (machine 0x14C, i386) : ARCH_X86, deja la valeur par defaut }
  End;
 End Else If (BinFormat = FMT_MACHO32) Or (BinFormat = FMT_MACHO64) Then Begin
  ParseMachO;
  If Not ArchForced Then Begin
   If MachOCpuType = CPU_TYPE_X86_64 Then Arch := ARCH_X64
   Else If MachOCpuType = CPU_TYPE_X86 Then Arch := ARCH_X86
   Else If MachOCpuType = CPU_TYPE_ARM64 Then Arch := ARCH_ARM64
   Else If MachOCpuType = CPU_TYPE_ARM Then Arch := ARCH_ARM32
   Else If MachOCpuType = CPU_TYPE_MC680x0 Then Arch := ARCH_68000
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
  If FailHard Then Begin
   WriteLn('Erreur : format de fichier non reconnu (ni ELF, ni PE, ni ROM NES, ni EXE DOS, ni Mach-O, ni objet COFF).');
   WriteLn('Pour un binaire brut, precisez l''architecture avec -m (ex: -m 6502).');
   Halt(1);
  End Else Begin
   WriteLn('  (format non reconnu, membre ignore)');
   AnalyzeBuffer := False;
   Exit;
  End;
 End;

 If OptHeaders Then CmdHeaders;
 If OptSymbols Then CmdSymbols;
 If OptSource Then CmdSourceMix;
 If OptDisasm Then Begin
  If Arch = ARCH_LLVM Then CmdLLVM Else CmdDisasm;
 End;
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
     '8080, z80, 6800, sparc, mips, ppc, sh, ia64, pcode, msil, jasmin, llvm ou arm).');
    Halt(1);
   End;
   If UpStr(ParamStr(I)) = '6502' Then Arch := ARCH_6502
   Else If (UpStr(ParamStr(I)) = '8080') Or
           (UpStr(ParamStr(I)) = 'I8080') Then Arch := ARCH_8080
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
   Else If (UpStr(ParamStr(I)) = '68000') Or (UpStr(ParamStr(I)) = '68K') Or
           (UpStr(ParamStr(I)) = 'M68K') Then Arch := ARCH_68000
   Else If (UpStr(ParamStr(I)) = 'SPARC') Or
           (UpStr(ParamStr(I)) = 'SPARC32') Or
           (UpStr(ParamStr(I)) = 'SPARCV8') Or
           (UpStr(ParamStr(I)) = 'SPARC64') Or
           (UpStr(ParamStr(I)) = 'SPARCV9') Then Arch := ARCH_SPARC
   Else If (UpStr(ParamStr(I)) = 'MIPS') Or
           (UpStr(ParamStr(I)) = 'MIPS32') Or
           (UpStr(ParamStr(I)) = 'MIPSEB') Then Arch := ARCH_MIPS
   Else If (UpStr(ParamStr(I)) = 'MIPSEL') Or
           (UpStr(ParamStr(I)) = 'MIPS32EL') Or
           (UpStr(ParamStr(I)) = 'MIPSEL32') Then Arch := ARCH_MIPSEL
   Else If (UpStr(ParamStr(I)) = 'PPC') Or
           (UpStr(ParamStr(I)) = 'POWERPC') Or
           (UpStr(ParamStr(I)) = 'PPC32') Or
           (UpStr(ParamStr(I)) = 'PPC64') Or
           (UpStr(ParamStr(I)) = 'POWERPC64') Then Arch := ARCH_PPC
   Else If (UpStr(ParamStr(I)) = 'PPCLE') Or
           (UpStr(ParamStr(I)) = 'POWERPCLE') Or
           (UpStr(ParamStr(I)) = 'PPC64LE') Or
           (UpStr(ParamStr(I)) = 'POWERPC64LE') Then Arch := ARCH_PPCLE
   Else If (UpStr(ParamStr(I)) = 'SH') Or
           (UpStr(ParamStr(I)) = 'SUPERH') Or
           (UpStr(ParamStr(I)) = 'SH1') Or
           (UpStr(ParamStr(I)) = 'SH2') Or
           (UpStr(ParamStr(I)) = 'SH3') Or
           (UpStr(ParamStr(I)) = 'SH4') Or
           (UpStr(ParamStr(I)) = 'SHEB') Then Arch := ARCH_SH
   Else If (UpStr(ParamStr(I)) = 'SHLE') Or
           (UpStr(ParamStr(I)) = 'SHEL') Or
           (UpStr(ParamStr(I)) = 'SH1LE') Or
           (UpStr(ParamStr(I)) = 'SH2LE') Or
           (UpStr(ParamStr(I)) = 'SH3LE') Or
           (UpStr(ParamStr(I)) = 'SH4LE') Then Arch := ARCH_SHLE
   Else If (UpStr(ParamStr(I)) = 'IA64') Or
           (UpStr(ParamStr(I)) = 'IA-64') Or
           (UpStr(ParamStr(I)) = 'ITANIUM') Then Arch := ARCH_IA64
   Else If (UpStr(ParamStr(I)) = 'IA64BE') Or
           (UpStr(ParamStr(I)) = 'ITANIUMBE') Then Arch := ARCH_IA64BE
   Else If (UpStr(ParamStr(I)) = 'PCODE') Or
           (UpStr(ParamStr(I)) = 'P-CODE') Or
           (UpStr(ParamStr(I)) = 'UCSD') Or
           (UpStr(ParamStr(I)) = 'UCSDPCODE') Then Arch := ARCH_PCODE
   Else If (UpStr(ParamStr(I)) = 'MSIL') Or
           (UpStr(ParamStr(I)) = 'CIL') Or
           (UpStr(ParamStr(I)) = 'IL') Or
           (UpStr(ParamStr(I)) = 'DOTNET') Then Arch := ARCH_MSIL
   Else If (UpStr(ParamStr(I)) = 'JASMIN') Or
           (UpStr(ParamStr(I)) = 'JVM') Or
           (UpStr(ParamStr(I)) = 'JAVA') Or
           (UpStr(ParamStr(I)) = 'BYTECODE') Then Arch := ARCH_JVM
   Else If (UpStr(ParamStr(I)) = 'LLVM') Or
           (UpStr(ParamStr(I)) = 'BITCODE') Or
           (UpStr(ParamStr(I)) = 'LLVMBC') Then Arch := ARCH_LLVM
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

 If BinFormat = FMT_ARCHIVE Then Begin
  { Bibliotheque statique .a : chaque membre est traite comme un
    mini-fichier independant, en echangeant temporairement Buf/
    BufSize (et InFileName, pour que les en-tetes "fichier: format
    ..." deja imprimes par CmdHeaders/CmdDisasm affichent le nom du
    membre), comme le ferait "objdump" sur une archive. }
  ParseArchive;
  WriteLn('In archive ', InFileName, ':');
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
    InFileName := SavedFileName + '(' + ArchiveMembers[AI].Name + ')';
    DetectFormat;
    AnalyzeBuffer(False);
    FreeMem(MemberBuf, ArchiveMembers[AI].DataSize);
   End;
  End;
  InFileName := SavedFileName;
  Buf := ArchiveBuf;
  BufSize := ArchiveBufSize;
 End Else
  AnalyzeBuffer(True);
END.
