{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Desassembleur de fichiers .OVL (overlay DOS, en-tete MZ charge
                via INT 21h AH=4Bh AL=03h - "Load Overlay", voir Ralf Brown
                Interrupt List) - genere un fichier .ASM (assembleur 8086,
                80286, 80386). Base sur le moteur de decodage de DISEXE.PAS
                (meme table d'opcodes 8086/0Fh complete), specialise pour la
                semantique PARTICULIERE d'un overlay : contrairement a un
                .EXE normal, un .OVL n'a PAS son propre PSP/point d'entree
                exploitable par le CHARGEUR (CS:IP/SS:SP de l'en-tete MZ sont
                ignores par un vrai chargeur d'overlay - voir le parametre
                ES:BX d'AH=4Bh AL=03h, DIFFERENT du bloc EXEC normal) ; le
                segment de chargement ET le facteur de relogement sont fournis
                par l'APPELANT au moment du chargement, pas par le fichier -
                DISOVL les accepte donc en parametres (-loadseg/-reloc) pour
                reconstituer des adresses absolues plausibles. Annotations
                "maximum d'information" specifiques a l'ingenierie inverse
                d'un extenseur DOS/pilote charge en overlay : sous-fonctions
                AH/AX connues pour INT 21h/2Fh/15h/1Ah/31h (reconstituees en
                remontant au plus recent MOV AH,imm/MOV AX,imm precedant
                l'INT), ports d'E/S materiels courants (CMOS 70h/71h, 8042
                60h/64h, A20 92h, PIC/PIT) pour IN/OUT, et signalement special
                des instructions mode protege (LGDT/SGDT/LIDT/SIDT/SMSW/LMSW/
                MOV CRn) - exactement les indices cherches en retro-ingenierie
                sur un extenseur DPMI proprietaire (voir
                project_devenv_xms_int2f_recursion.md, enquete TPX.EXE/
                DPMI16BI.OVL).
  @license: MIT
}

Program DISOVL;

{$IFDEF FPC}
 {$MODE TP}
 {$H-}
{$ENDIF}

{$A-}
{$I-}

Uses DOS;

{ ============================================================
  CONSTANTES GLOBALES
  ============================================================ }
Const
  DISOVL_VERSION = '1.0';
  DISOVL_DATE    = '2026-10-14';

  { Signature MZ pour les fichiers EXE DOS }
  MZ_SIGNATURE   = $5A4D;  { 'MZ' }
  ZM_SIGNATURE   = $4D5A;  { 'ZM' variante }

  { Signature PE pour les fichiers Windows 32 bits }
  PE_SIGNATURE   = $00004550;  { 'PE\0\0' }

  { Machine types pour IMAGE_FILE_HEADER }
  IMAGE_FILE_MACHINE_I386 = $014C;

  { Magic pour IMAGE_OPTIONAL_HEADER }
  PE32_MAGIC     = $010B;  { PE32 (32 bits) }

  { Section characteristics flags }
  IMAGE_SCN_CNT_CODE               = $00000020;
  IMAGE_SCN_CNT_INITIALIZED_DATA   = $00000040;
  IMAGE_SCN_CNT_UNINITIALIZED_DATA = $00000080;
  IMAGE_SCN_MEM_EXECUTE            = $20000000;
  IMAGE_SCN_MEM_READ               = $40000000;
  IMAGE_SCN_MEM_WRITE              = LongInt($80000000); { cast requis : depasse LongInt signe }

  { Types de relogement PE (Base Relocation) }
  IMAGE_REL_BASED_ABSOLUTE = 0;   { padding, ignorer }
  IMAGE_REL_BASED_HIGHLOW  = 3;   { ajuster un DWORD 32 bits }

  { Limites des tableaux internes }
  MAX_SECTIONS   = 64;
  MAX_IMPORTS    = 4096;
  MAX_EXPORTS    = 4096;
  MAX_RELOCS     = 65536;
  MAX_LABELS     = 65536;
  MAX_XREFS      = 65536;
  BUFFER_SIZE    = 65536;

  { Nombre d'entrees dans le DataDirectory PE }
  MAX_DATA_DIRS  = 16;

  { Taille maximale de l'image en memoire (16 Mo) }
  MAX_IMAGE_SIZE = 16 * 1024 * 1024;

  { Types d'operandes pour la table des opcodes 8086/8088 }
  OT_NONE    = 0;   { pas d'operande }
  OT_REG8    = 1;   { registre 8 bits }
  OT_REG16   = 2;   { registre 16 bits }
  OT_SEGREG  = 3;   { registre de segment }
  OT_MEM     = 4;   { memoire (via ModR/M) }
  OT_RM8     = 5;   { registre/memoire 8 bits (ModR/M) }
  OT_RM16    = 6;   { registre/memoire 16 bits (ModR/M) }
  OT_IMM8    = 7;   { immediat 8 bits }
  OT_IMM16   = 8;   { immediat 16 bits }
  OT_REL8    = 9;   { deplacement relatif 8 bits (sauts courts) }
  OT_REL16   = 10;  { deplacement relatif 16 bits (sauts et appels) }
  OT_FAR     = 11;  { adresse far (segment:offset) }
  OT_AL      = 12;  { registre AL implicite }
  OT_AX      = 13;  { registre AX implicite }
  OT_CL      = 14;  { registre CL implicite (pour rotations) }
  OT_DX      = 15;  { registre DX implicite (pour IN/OUT) }
  OT_ONE     = 16;  { constante 1 implicite (pour rotations) }
  OT_CS      = 17;  { registre CS implicite }
  OT_DS      = 18;  { registre DS implicite }
  OT_ES      = 19;  { registre ES implicite }
  OT_SS      = 20;  { registre SS implicite }
  OT_MEM16   = 21;  { adresse memoire directe 16 bits }
  OT_IMM8X   = 22;  { immediat 8 bits signe-etendu a 16 bits }
  { Constantes de types d'operandes 80386 (32 bits) }
  OT_REG32   = 23;  { registre 32 bits }
  OT_RM32    = 24;  { registre/memoire 32 bits (ModR/M) }
  OT_IMM32   = 25;  { immediat 32 bits }
  OT_EAX     = 26;  { registre EAX implicite }
  OT_FS      = 27;  { registre FS implicite }
  OT_GS      = 28;  { registre GS implicite }
  OT_CR      = 29;  { registre de controle CRn }
  OT_DR      = 30;  { registre de debogage DRn }
  OT_TR      = 31;  { registre de test TRn }
  OT_REL32   = 32;  { deplacement relatif 32 bits }

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String;

  { Tampon dynamique pour l'image en memoire }
  TByteArray = Array[0..($7FFFFFFF - 1)] Of Byte;
  PByteArray = ^TByteArray;

  { Entete MZ (DOS EXE header - 28 octets minimum) }
  TMZHeader = Record
    Signature    : Word;    { $5A4D = 'MZ' }
    LastPageSize : Word;    { octets dans la derniere page }
    PageCount    : Word;    { nombre de pages de 512 octets }
    RelocCount   : Word;    { nombre d'entrees de relogement }
    HeaderSize   : Word;    { taille de l'entete en paragraphes (16 octets) }
    MinAlloc     : Word;    { paragraphes minimum requis }
    MaxAlloc     : Word;    { paragraphes maximum requis }
    InitSS       : Word;    { valeur initiale de SS }
    InitSP       : Word;    { valeur initiale de SP }
    Checksum     : Word;    { somme de controle }
    InitIP       : Word;    { valeur initiale de IP }
    InitCS       : Word;    { valeur initiale de CS }
    RelocOfs     : Word;    { offset de la table de relogement }
    OverlayNum   : Word;    { numero d'overlay }
  End;

  { Entete PE - IMAGE_FILE_HEADER (20 octets) }
  TPEFileHeader = Record
    Machine              : Word;
    NumberOfSections     : Word;
    TimeDateStamp        : LongInt;
    PointerToSymbolTable : LongInt;
    NumberOfSymbols      : LongInt;
    SizeOfOptionalHeader : Word;
    Characteristics      : Word;
  End;

  { Entete PE - IMAGE_OPTIONAL_HEADER32 (premiers champs) }
  TPEOptionalHeader = Record
    Magic                : Word;
    MajorLinkerVersion   : Byte;
    MinorLinkerVersion   : Byte;
    SizeOfCode           : LongInt;
    SizeOfInitializedData   : LongInt;
    SizeOfUninitializedData : LongInt;
    AddressOfEntryPoint  : LongInt;
    BaseOfCode           : LongInt;
    BaseOfData           : LongInt;
    ImageBase            : LongInt;
    SectionAlignment     : LongInt;
    FileAlignment        : LongInt;
    MajorOSVersion       : Word;
    MinorOSVersion       : Word;
    MajorImageVersion    : Word;
    MinorImageVersion    : Word;
    MajorSubsysVersion   : Word;
    MinorSubsysVersion   : Word;
    Win32VersionValue    : LongInt;
    SizeOfImage          : LongInt;
    SizeOfHeaders        : LongInt;
    CheckSum             : LongInt;
    Subsystem            : Word;
    DllCharacteristics   : Word;
    SizeOfStackReserve   : LongInt;
    SizeOfStackCommit    : LongInt;
    SizeOfHeapReserve    : LongInt;
    SizeOfHeapCommit     : LongInt;
    LoaderFlags          : LongInt;
    NumberOfRvaAndSizes  : LongInt;
  End;

  { Entree du DataDirectory PE (8 octets) }
  TDataDirectory = Record
    VirtualAddress : LongInt;
    Size           : LongInt;
  End;

  { Section PE - IMAGE_SECTION_HEADER (40 octets) }
  TPESectionHeader = Record
    Name            : Array[0..7] Of Char;
    VirtualSize     : LongInt;
    VirtualAddress  : LongInt;
    SizeOfRawData   : LongInt;
    PointerToRawData: LongInt;
    PointerToRelocs : LongInt;
    PointerToLineNums : LongInt;
    NumberOfRelocs  : Word;
    NumberOfLineNums: Word;
    Characteristics : LongInt;
  End;

  { Entree de relogement DOS (segment:offset) }
  TMZReloc = Record
    Offset  : Word;
    Segment : Word;
  End;

  { Information de label/symbole }
  TLabelInfo = Record
    Address  : LongInt;   { adresse dans l'image }
    Name     : TString;   { nom du label }
    IsProc   : Boolean;   { est-ce un sous-programme ? }
    IsImport : Boolean;   { est-ce un import ? }
    IsExport : Boolean;   { est-ce un export ? }
  End;

  { Reference croisee }
  TXRef = Record
    FromAddr : LongInt;   { adresse source }
    ToAddr   : LongInt;   { adresse cible }
    IsCall   : Boolean;   { CALL (True) ou JMP/Jcc (False) }
  End;

  { Entree d'importation PE }
  TImportEntry = Record
    DLLName   : TString;    { nom de la DLL }
    FuncName  : TString;    { nom de la fonction (vide si par ordinal) }
    IATAddr   : LongInt;    { RVA de l'entree IAT }
    Hint      : Word;       { hint index }
    Ordinal   : Word;       { ordinal (si importation par ordinal) }
    ByOrdinal : Boolean;    { True si importation par ordinal }
  End;

  { Entree d'exportation PE }
  TExportEntry = Record
    FuncName  : TString;    { nom de la fonction (vide si par ordinal seul) }
    Ordinal   : Word;       { ordinal de la fonction }
    FuncRVA   : LongInt;    { RVA de la fonction }
    HasName   : Boolean;    { True si la fonction a un nom }
  End;

  { Entree de relogement PE }
  TPERelocEntry = Record
    Address   : LongInt;    { RVA de l'adresse a reloger }
    RelocType : Byte;       { type de relogement (0=ABS, 3=HIGHLOW) }
  End;

  { Entree de la table des opcodes 8086/8088 }
  TOpcodeEntry = Record
    Mnemonic  : String[10];  { mnemonique (MOV, ADD, ...) }
    OpCount   : Byte;        { nombre d'operandes (0, 1 ou 2) }
    Op1Type   : Byte;        { type du 1er operande (OT_xxx) }
    Op2Type   : Byte;        { type du 2e operande (OT_xxx) }
    NeedModRM : Boolean;     { True si un octet ModR/M suit l'opcode }
    BaseSize  : Byte;        { taille de base en octets (1 pour la plupart) }
  End;

{ ============================================================
  NOMS DES REGISTRES 8086/8088
  ============================================================ }
Const
  { Registres 8 bits (indices 0..7) }
  RegNames8 : Array[0..7] Of String[2] = (
    'AL', 'CL', 'DL', 'BL', 'AH', 'CH', 'DH', 'BH'
  );

  { Registres 16 bits (indices 0..7) }
  RegNames16 : Array[0..7] Of String[2] = (
    'AX', 'CX', 'DX', 'BX', 'SP', 'BP', 'SI', 'DI'
  );

  { Registres de segment (indices 0..3) }
  SegRegNames : Array[0..3] Of String[2] = (
    'ES', 'CS', 'SS', 'DS'
  );

  { Registres 32 bits (indices 0..7, 80386+) }
  RegNames32 : Array[0..7] Of String[3] = (
    'EAX', 'ECX', 'EDX', 'EBX', 'ESP', 'EBP', 'ESI', 'EDI'
  );

  { Registres de segment etendus (indices 0..5, FS/GS sur 80386+) }
  SegRegNames6 : Array[0..5] Of String[2] = (
    'ES', 'CS', 'SS', 'DS', 'FS', 'GS'
  );

  { Registres de controle (indices 0..3, 80386+) }
  CRegNames : Array[0..3] Of String[3] = (
    'CR0', 'CR1', 'CR2', 'CR3'
  );

  { Registres de debogage (indices 0..7, 80386+) }
  DRegNames : Array[0..7] Of String[3] = (
    'DR0', 'DR1', 'DR2', 'DR3', 'DR4', 'DR5', 'DR6', 'DR7'
  );

  { Registres de test (indices 0..7, 80386+) }
  TRegNames : Array[0..7] Of String[3] = (
    'TR0', 'TR1', 'TR2', 'TR3', 'TR4', 'TR5', 'TR6', 'TR7'
  );

{ ============================================================
  TABLE DES 256 OPCODES 8086/8088
  ============================================================ }

  OpcodeTable : Array[0..255] Of TOpcodeEntry = (
    { $00 ADD r/m8, r8 }
    (Mnemonic:'ADD';      OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $01 ADD r/m16, r16 }
    (Mnemonic:'ADD';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $02 ADD r8, r/m8 }
    (Mnemonic:'ADD';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:1),
    { $03 ADD r16, r/m16 }
    (Mnemonic:'ADD';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:1),
    { $04 ADD AL, imm8 }
    (Mnemonic:'ADD';      OpCount:2; Op1Type:OT_AL;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $05 ADD AX, imm16 }
    (Mnemonic:'ADD';      OpCount:2; Op1Type:OT_AX;    Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    { $06 PUSH ES }
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_ES;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $07 POP ES }
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_ES;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $08 OR r/m8, r8 }
    (Mnemonic:'OR';       OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $09 OR r/m16, r16 }
    (Mnemonic:'OR';       OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $0A OR r8, r/m8 }
    (Mnemonic:'OR';       OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:1),
    { $0B OR r16, r/m16 }
    (Mnemonic:'OR';       OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:1),
    { $0C OR AL, imm8 }
    (Mnemonic:'OR';       OpCount:2; Op1Type:OT_AL;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $0D OR AX, imm16 }
    (Mnemonic:'OR';       OpCount:2; Op1Type:OT_AX;    Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    { $0E PUSH CS }
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_CS;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $0F (prefixe 0F - opcodes etendus 80286+, voir Opcode0FTable) }
    (Mnemonic:'0F';       OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $10 ADC r/m8, r8 }
    (Mnemonic:'ADC';      OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $11 ADC r/m16, r16 }
    (Mnemonic:'ADC';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $12 ADC r8, r/m8 }
    (Mnemonic:'ADC';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:1),
    { $13 ADC r16, r/m16 }
    (Mnemonic:'ADC';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:1),
    { $14 ADC AL, imm8 }
    (Mnemonic:'ADC';      OpCount:2; Op1Type:OT_AL;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $15 ADC AX, imm16 }
    (Mnemonic:'ADC';      OpCount:2; Op1Type:OT_AX;    Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    { $16 PUSH SS }
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_SS;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $17 POP SS }
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_SS;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $18 SBB r/m8, r8 }
    (Mnemonic:'SBB';      OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $19 SBB r/m16, r16 }
    (Mnemonic:'SBB';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $1A SBB r8, r/m8 }
    (Mnemonic:'SBB';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:1),
    { $1B SBB r16, r/m16 }
    (Mnemonic:'SBB';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:1),
    { $1C SBB AL, imm8 }
    (Mnemonic:'SBB';      OpCount:2; Op1Type:OT_AL;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $1D SBB AX, imm16 }
    (Mnemonic:'SBB';      OpCount:2; Op1Type:OT_AX;    Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    { $1E PUSH DS }
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_DS;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $1F POP DS }
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_DS;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $20 AND r/m8, r8 }
    (Mnemonic:'AND';      OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $21 AND r/m16, r16 }
    (Mnemonic:'AND';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $22 AND r8, r/m8 }
    (Mnemonic:'AND';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:1),
    { $23 AND r16, r/m16 }
    (Mnemonic:'AND';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:1),
    { $24 AND AL, imm8 }
    (Mnemonic:'AND';      OpCount:2; Op1Type:OT_AL;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $25 AND AX, imm16 }
    (Mnemonic:'AND';      OpCount:2; Op1Type:OT_AX;    Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    { $26 ES: (prefixe de segment) }
    (Mnemonic:'ES:';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $27 DAA }
    (Mnemonic:'DAA';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $28 SUB r/m8, r8 }
    (Mnemonic:'SUB';      OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $29 SUB r/m16, r16 }
    (Mnemonic:'SUB';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $2A SUB r8, r/m8 }
    (Mnemonic:'SUB';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:1),
    { $2B SUB r16, r/m16 }
    (Mnemonic:'SUB';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:1),
    { $2C SUB AL, imm8 }
    (Mnemonic:'SUB';      OpCount:2; Op1Type:OT_AL;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $2D SUB AX, imm16 }
    (Mnemonic:'SUB';      OpCount:2; Op1Type:OT_AX;    Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    { $2E CS: (prefixe de segment) }
    (Mnemonic:'CS:';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $2F DAS }
    (Mnemonic:'DAS';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $30 XOR r/m8, r8 }
    (Mnemonic:'XOR';      OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $31 XOR r/m16, r16 }
    (Mnemonic:'XOR';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $32 XOR r8, r/m8 }
    (Mnemonic:'XOR';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:1),
    { $33 XOR r16, r/m16 }
    (Mnemonic:'XOR';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:1),
    { $34 XOR AL, imm8 }
    (Mnemonic:'XOR';      OpCount:2; Op1Type:OT_AL;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $35 XOR AX, imm16 }
    (Mnemonic:'XOR';      OpCount:2; Op1Type:OT_AX;    Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    { $36 SS: (prefixe de segment) }
    (Mnemonic:'SS:';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $37 AAA }
    (Mnemonic:'AAA';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $38 CMP r/m8, r8 }
    (Mnemonic:'CMP';      OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $39 CMP r/m16, r16 }
    (Mnemonic:'CMP';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $3A CMP r8, r/m8 }
    (Mnemonic:'CMP';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:1),
    { $3B CMP r16, r/m16 }
    (Mnemonic:'CMP';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:1),
    { $3C CMP AL, imm8 }
    (Mnemonic:'CMP';      OpCount:2; Op1Type:OT_AL;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $3D CMP AX, imm16 }
    (Mnemonic:'CMP';      OpCount:2; Op1Type:OT_AX;    Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    { $3E DS: (prefixe de segment) }
    (Mnemonic:'DS:';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $3F AAS }
    (Mnemonic:'AAS';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $40..$47 INC r16 (AX..DI) }
    (Mnemonic:'INC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'INC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'INC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'INC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'INC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'INC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'INC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'INC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $48..$4F DEC r16 (AX..DI) }
    (Mnemonic:'DEC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'DEC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'DEC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'DEC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'DEC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'DEC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'DEC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'DEC';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $50..$57 PUSH r16 (AX..DI) }
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $58..$5F POP r16 (AX..DI) }
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_REG16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $60..$6F : instructions 80186/80286 }
    { $60 PUSHA }
    (Mnemonic:'PUSHA';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $61 POPA }
    (Mnemonic:'POPA';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $62 BOUND r16, m16&16 }
    (Mnemonic:'BOUND';    OpCount:2; Op1Type:OT_REG16; Op2Type:OT_MEM;   NeedModRM:True;  BaseSize:1),
    { $63 ARPL r/m16, r16 (mode protege 80286) }
    (Mnemonic:'ARPL';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $64 FS: (prefixe segment FS sur 80386+) }
    (Mnemonic:'FS:';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $65 GS: (prefixe segment GS sur 80386+) }
    (Mnemonic:'GS:';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $66 OPSIZ (prefixe taille operande sur 80386+) }
    (Mnemonic:'OPSIZ';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $67 ADDRSIZ (prefixe taille adresse sur 80386+) }
    (Mnemonic:'ADDRSIZ';  OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $68 PUSH imm16 }
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_IMM16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:3),
    { $69 IMUL r16, r/m16, imm16 }
    (Mnemonic:'IMUL';     OpCount:2; Op1Type:OT_REG16; Op2Type:OT_IMM16; NeedModRM:True;  BaseSize:1),
    { $6A PUSH imm8 (signe-etendu a 16 bits) }
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_IMM8X; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $6B IMUL r16, r/m16, imm8 }
    (Mnemonic:'IMUL';     OpCount:2; Op1Type:OT_REG16; Op2Type:OT_IMM8X; NeedModRM:True;  BaseSize:1),
    { $6C INSB }
    (Mnemonic:'INSB';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $6D INSW }
    (Mnemonic:'INSW';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $6E OUTSB }
    (Mnemonic:'OUTSB';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $6F OUTSW }
    (Mnemonic:'OUTSW';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $70..$7F Jcc rel8 (sauts conditionnels courts) }
    (Mnemonic:'JO';       OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JNO';      OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JB';       OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JNB';      OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JZ';       OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JNZ';      OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JBE';      OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JNBE';     OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JS';       OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JNS';      OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JP';       OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JNP';      OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JL';       OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JNL';      OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JLE';      OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'JNLE';     OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $80 GRP1 r/m8, imm8 (ADD/OR/ADC/SBB/AND/SUB/XOR/CMP selon reg) }
    (Mnemonic:'GRP1';     OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_IMM8;  NeedModRM:True;  BaseSize:1),
    { $81 GRP1 r/m16, imm16 }
    (Mnemonic:'GRP1';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_IMM16; NeedModRM:True;  BaseSize:1),
    { $82 GRP1 r/m8, imm8 (alias de $80) }
    (Mnemonic:'GRP1';     OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_IMM8;  NeedModRM:True;  BaseSize:1),
    { $83 GRP1 r/m16, imm8 (signe-etendu) }
    (Mnemonic:'GRP1';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_IMM8X; NeedModRM:True;  BaseSize:1),
    { $84 TEST r/m8, r8 }
    (Mnemonic:'TEST';     OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $85 TEST r/m16, r16 }
    (Mnemonic:'TEST';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $86 XCHG r/m8, r8 }
    (Mnemonic:'XCHG';     OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $87 XCHG r/m16, r16 }
    (Mnemonic:'XCHG';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $88 MOV r/m8, r8 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:1),
    { $89 MOV r/m16, r16 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:1),
    { $8A MOV r8, r/m8 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:1),
    { $8B MOV r16, r/m16 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:1),
    { $8C MOV r/m16, Sreg }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_SEGREG;NeedModRM:True;  BaseSize:1),
    { $8D LEA r16, m }
    (Mnemonic:'LEA';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_MEM;   NeedModRM:True;  BaseSize:1),
    { $8E MOV Sreg, r/m16 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_SEGREG;Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:1),
    { $8F POP r/m16 }
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    { $90 NOP (XCHG AX,AX) }
    (Mnemonic:'NOP';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $91..$97 XCHG AX, r16 }
    (Mnemonic:'XCHG';     OpCount:2; Op1Type:OT_AX;    Op2Type:OT_REG16; NeedModRM:False; BaseSize:1),
    (Mnemonic:'XCHG';     OpCount:2; Op1Type:OT_AX;    Op2Type:OT_REG16; NeedModRM:False; BaseSize:1),
    (Mnemonic:'XCHG';     OpCount:2; Op1Type:OT_AX;    Op2Type:OT_REG16; NeedModRM:False; BaseSize:1),
    (Mnemonic:'XCHG';     OpCount:2; Op1Type:OT_AX;    Op2Type:OT_REG16; NeedModRM:False; BaseSize:1),
    (Mnemonic:'XCHG';     OpCount:2; Op1Type:OT_AX;    Op2Type:OT_REG16; NeedModRM:False; BaseSize:1),
    (Mnemonic:'XCHG';     OpCount:2; Op1Type:OT_AX;    Op2Type:OT_REG16; NeedModRM:False; BaseSize:1),
    (Mnemonic:'XCHG';     OpCount:2; Op1Type:OT_AX;    Op2Type:OT_REG16; NeedModRM:False; BaseSize:1),
    { $98 CBW }
    (Mnemonic:'CBW';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $99 CWD }
    (Mnemonic:'CWD';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $9A CALL far ptr16:16 }
    (Mnemonic:'CALL';     OpCount:1; Op1Type:OT_FAR;   Op2Type:OT_NONE;  NeedModRM:False; BaseSize:5),
    { $9B WAIT/FWAIT }
    (Mnemonic:'FWAIT';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $9C PUSHF }
    (Mnemonic:'PUSHF';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $9D POPF }
    (Mnemonic:'POPF';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $9E SAHF }
    (Mnemonic:'SAHF';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $9F LAHF }
    (Mnemonic:'LAHF';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $A0 MOV AL, moffs8 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_AL;    Op2Type:OT_MEM16; NeedModRM:False; BaseSize:3),
    { $A1 MOV AX, moffs16 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_AX;    Op2Type:OT_MEM16; NeedModRM:False; BaseSize:3),
    { $A2 MOV moffs8, AL }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_MEM16; Op2Type:OT_AL;    NeedModRM:False; BaseSize:3),
    { $A3 MOV moffs16, AX }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_MEM16; Op2Type:OT_AX;    NeedModRM:False; BaseSize:3),
    { $A4 MOVSB }
    (Mnemonic:'MOVSB';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $A5 MOVSW }
    (Mnemonic:'MOVSW';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $A6 CMPSB }
    (Mnemonic:'CMPSB';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $A7 CMPSW }
    (Mnemonic:'CMPSW';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $A8 TEST AL, imm8 }
    (Mnemonic:'TEST';     OpCount:2; Op1Type:OT_AL;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $A9 TEST AX, imm16 }
    (Mnemonic:'TEST';     OpCount:2; Op1Type:OT_AX;    Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    { $AA STOSB }
    (Mnemonic:'STOSB';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $AB STOSW }
    (Mnemonic:'STOSW';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $AC LODSB }
    (Mnemonic:'LODSB';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $AD LODSW }
    (Mnemonic:'LODSW';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $AE SCASB }
    (Mnemonic:'SCASB';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $AF SCASW }
    (Mnemonic:'SCASW';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $B0..$B7 MOV r8, imm8 (AL..BH) }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG8;  Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $B8..$BF MOV r16, imm16 (AX..DI) }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_IMM16; NeedModRM:False; BaseSize:3),
    { $C0 GRP2 r/m8, imm8 (80186+ : shifts/rotations avec immediat) }
    (Mnemonic:'GRP2';     OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_IMM8;  NeedModRM:True;  BaseSize:1),
    { $C1 GRP2 r/m16, imm8 (80186+ : shifts/rotations avec immediat) }
    (Mnemonic:'GRP2';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_IMM8;  NeedModRM:True;  BaseSize:1),
    { $C2 RET imm16 (near return avec pop) }
    (Mnemonic:'RET';      OpCount:1; Op1Type:OT_IMM16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:3),
    { $C3 RET (near return) }
    (Mnemonic:'RET';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $C4 LES r16, m16:16 }
    (Mnemonic:'LES';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_MEM;   NeedModRM:True;  BaseSize:1),
    { $C5 LDS r16, m16:16 }
    (Mnemonic:'LDS';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_MEM;   NeedModRM:True;  BaseSize:1),
    { $C6 MOV r/m8, imm8 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_IMM8;  NeedModRM:True;  BaseSize:1),
    { $C7 MOV r/m16, imm16 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_IMM16; NeedModRM:True;  BaseSize:1),
    { $C8 ENTER imm16, imm8 (80186+) }
    (Mnemonic:'ENTER';    OpCount:2; Op1Type:OT_IMM16; Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:4),
    { $C9 LEAVE (80186+) }
    (Mnemonic:'LEAVE';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $CA RETF imm16 (far return avec pop) }
    (Mnemonic:'RETF';     OpCount:1; Op1Type:OT_IMM16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:3),
    { $CB RETF (far return) }
    (Mnemonic:'RETF';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $CC INT 3 (implicite, pas d'octet immediat) }
    (Mnemonic:'INT3';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $CD INT imm8 }
    (Mnemonic:'INT';      OpCount:1; Op1Type:OT_IMM8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $CE INTO }
    (Mnemonic:'INTO';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $CF IRET }
    (Mnemonic:'IRET';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $D0 GRP2 r/m8, 1 (ROL/ROR/RCL/RCR/SHL/SHR/-/SAR) }
    (Mnemonic:'GRP2';     OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_ONE;   NeedModRM:True;  BaseSize:1),
    { $D1 GRP2 r/m16, 1 }
    (Mnemonic:'GRP2';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_ONE;   NeedModRM:True;  BaseSize:1),
    { $D2 GRP2 r/m8, CL }
    (Mnemonic:'GRP2';     OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_CL;    NeedModRM:True;  BaseSize:1),
    { $D3 GRP2 r/m16, CL }
    (Mnemonic:'GRP2';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_CL;    NeedModRM:True;  BaseSize:1),
    { $D4 AAM (imm8 = 0Ah implicite) }
    (Mnemonic:'AAM';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $D5 AAD (imm8 = 0Ah implicite) }
    (Mnemonic:'AAD';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $D6 (reserve/SALC non documente) }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $D7 XLAT }
    (Mnemonic:'XLAT';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $D8..$DF ESC (opcodes coprocesseur x87) }
    (Mnemonic:'ESC';      OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    (Mnemonic:'ESC';      OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    (Mnemonic:'ESC';      OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    (Mnemonic:'ESC';      OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    (Mnemonic:'ESC';      OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    (Mnemonic:'ESC';      OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    (Mnemonic:'ESC';      OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    (Mnemonic:'ESC';      OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    { $E0 LOOPNZ rel8 }
    (Mnemonic:'LOOPNZ';   OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $E1 LOOPZ rel8 }
    (Mnemonic:'LOOPZ';    OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $E2 LOOP rel8 }
    (Mnemonic:'LOOP';     OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $E3 JCXZ rel8 }
    (Mnemonic:'JCXZ';     OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $E4 IN AL, imm8 }
    (Mnemonic:'IN';       OpCount:2; Op1Type:OT_AL;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $E5 IN AX, imm8 }
    (Mnemonic:'IN';       OpCount:2; Op1Type:OT_AX;    Op2Type:OT_IMM8;  NeedModRM:False; BaseSize:2),
    { $E6 OUT imm8, AL }
    (Mnemonic:'OUT';      OpCount:2; Op1Type:OT_IMM8;  Op2Type:OT_AL;    NeedModRM:False; BaseSize:2),
    { $E7 OUT imm8, AX }
    (Mnemonic:'OUT';      OpCount:2; Op1Type:OT_IMM8;  Op2Type:OT_AX;    NeedModRM:False; BaseSize:2),
    { $E8 CALL rel16 }
    (Mnemonic:'CALL';     OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:3),
    { $E9 JMP rel16 }
    (Mnemonic:'JMP';      OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:3),
    { $EA JMP far ptr16:16 }
    (Mnemonic:'JMP';      OpCount:1; Op1Type:OT_FAR;   Op2Type:OT_NONE;  NeedModRM:False; BaseSize:5),
    { $EB JMP rel8 }
    (Mnemonic:'JMP';      OpCount:1; Op1Type:OT_REL8;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $EC IN AL, DX }
    (Mnemonic:'IN';       OpCount:2; Op1Type:OT_AL;    Op2Type:OT_DX;    NeedModRM:False; BaseSize:1),
    { $ED IN AX, DX }
    (Mnemonic:'IN';       OpCount:2; Op1Type:OT_AX;    Op2Type:OT_DX;    NeedModRM:False; BaseSize:1),
    { $EE OUT DX, AL }
    (Mnemonic:'OUT';      OpCount:2; Op1Type:OT_DX;    Op2Type:OT_AL;    NeedModRM:False; BaseSize:1),
    { $EF OUT DX, AX }
    (Mnemonic:'OUT';      OpCount:2; Op1Type:OT_DX;    Op2Type:OT_AX;    NeedModRM:False; BaseSize:1),
    { $F0 LOCK (prefixe) }
    (Mnemonic:'LOCK';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $F1 (reserve / INT1 non documente) }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $F2 REPNZ (prefixe) }
    (Mnemonic:'REPNZ';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $F3 REP/REPZ (prefixe) }
    (Mnemonic:'REP';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $F4 HLT }
    (Mnemonic:'HLT';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $F5 CMC }
    (Mnemonic:'CMC';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $F6 GRP3a r/m8 (TEST/???/NOT/NEG/MUL/IMUL/DIV/IDIV) }
    (Mnemonic:'GRP3';     OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    { $F7 GRP3b r/m16 }
    (Mnemonic:'GRP3';     OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    { $F8 CLC }
    (Mnemonic:'CLC';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $F9 STC }
    (Mnemonic:'STC';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $FA CLI }
    (Mnemonic:'CLI';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $FB STI }
    (Mnemonic:'STI';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $FC CLD }
    (Mnemonic:'CLD';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $FD STD }
    (Mnemonic:'STD';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:1),
    { $FE GRP4 r/m8 (INC/DEC) }
    (Mnemonic:'GRP4';     OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1),
    { $FF GRP5 r/m16 (INC/DEC/CALL/CALL far/JMP/JMP far/PUSH) }
    (Mnemonic:'GRP5';     OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:1)
  );

  { Mnemoniques du groupe 1 (opcodes $80-$83, selon champ reg de ModR/M) }
  Grp1Mnemonics : Array[0..7] Of String[3] = (
    'ADD', 'OR', 'ADC', 'SBB', 'AND', 'SUB', 'XOR', 'CMP'
  );

  { Mnemoniques du groupe 2 (opcodes $D0-$D3, selon champ reg de ModR/M) }
  Grp2Mnemonics : Array[0..7] Of String[3] = (
    'ROL', 'ROR', 'RCL', 'RCR', 'SHL', 'SHR', '???', 'SAR'
  );

  { Mnemoniques du groupe 3 (opcodes $F6-$F7, selon champ reg de ModR/M) }
  Grp3Mnemonics : Array[0..7] Of String[4] = (
    'TEST', '???', 'NOT', 'NEG', 'MUL', 'IMUL', 'DIV', 'IDIV'
  );

  { Mnemoniques du groupe 4 (opcode $FE, selon champ reg de ModR/M) }
  Grp4Mnemonics : Array[0..7] Of String[3] = (
    'INC', 'DEC', '???', '???', '???', '???', '???', '???'
  );

  { Mnemoniques du groupe 5 (opcode $FF, selon champ reg de ModR/M) }
  Grp5Mnemonics : Array[0..7] Of String[4] = (
    'INC', 'DEC', 'CALL', 'CALL', 'JMP', 'JMP', 'PUSH', '???'
  );

  { Mnemoniques du groupe 6 (opcode 0F 00, selon champ reg de ModR/M) }
  { Instructions mode protege 80286 }
  Grp6Mnemonics : Array[0..7] Of String[4] = (
    'SLDT', 'STR', 'LLDT', 'LTR', 'VERR', 'VERW', '???', '???'
  );

  { Mnemoniques du groupe 7 (opcode 0F 01, selon champ reg de ModR/M) }
  { Instructions mode protege 80286 }
  Grp7Mnemonics : Array[0..7] Of String[4] = (
    'SGDT', 'SIDT', 'LGDT', 'LIDT', 'SMSW', '???', 'LMSW', '???'
  );

  { Mnemoniques du groupe 8 (opcode 0F BA, selon champ reg de ModR/M) }
  { Instructions bit test 80386+ }
  Grp8Mnemonics : Array[0..7] Of String[3] = (
    '???', '???', '???', '???', 'BT', 'BTS', 'BTR', 'BTC'
  );

{ ============================================================
  TABLE DES OPCODES ETENDUS 0Fh (80286+)
  ============================================================ }

  { Nombre d'opcodes etendus 0Fh definis }
  MAX_0F_OPCODES = 256;

  Opcode0FTable : Array[0..255] Of TOpcodeEntry = (
    { $0F 00 GRP6 r/m16 (SLDT/STR/LLDT/LTR/VERR/VERW) }
    (Mnemonic:'GRP6';     OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    { $0F 01 GRP7 (SGDT/SIDT/LGDT/LIDT/SMSW/LMSW) }
    (Mnemonic:'GRP7';     OpCount:1; Op1Type:OT_RM16;  Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    { $0F 02 LAR r16, r/m16 }
    (Mnemonic:'LAR';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 03 LSL r16, r/m16 }
    (Mnemonic:'LSL';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 04 reserve }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 05 reserve (LOADALL 80286 / SYSCALL 686+) }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 06 CLTS (Clear Task-Switched Flag) }
    (Mnemonic:'CLTS';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 07 reserve (LOADALL 80386 / SYSRET 686+) }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 08 INVD (Invalidate Cache, 80486+) }
    (Mnemonic:'INVD';     OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 09 WBINVD (Write Back and Invalidate Cache, 80486+) }
    (Mnemonic:'WBINVD';   OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 0A..$0F 0F reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 10..$0F 1F reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 20..$0F 2F MOV CRn/DRn/TRn (80386+) }
    { $0F 20 MOV r32, CRn }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG32; Op2Type:OT_CR;    NeedModRM:True;  BaseSize:2),
    { $0F 21 MOV r32, DRn }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG32; Op2Type:OT_DR;    NeedModRM:True;  BaseSize:2),
    { $0F 22 MOV CRn, r32 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_CR;    Op2Type:OT_REG32; NeedModRM:True;  BaseSize:2),
    { $0F 23 MOV DRn, r32 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_DR;    Op2Type:OT_REG32; NeedModRM:True;  BaseSize:2),
    { $0F 24 MOV r32, TRn }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_REG32; Op2Type:OT_TR;    NeedModRM:True;  BaseSize:2),
    { $0F 25 reserve }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 26 MOV TRn, r32 }
    (Mnemonic:'MOV';      OpCount:2; Op1Type:OT_TR;    Op2Type:OT_REG32; NeedModRM:True;  BaseSize:2),
    { $0F 27 reserve }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 28..$0F 2F reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 30..$0F 3F instructions systeme (Pentium+) }
    { $0F 30 WRMSR (Write Model Specific Register) }
    (Mnemonic:'WRMSR';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 31 RDTSC (Read Time Stamp Counter) }
    (Mnemonic:'RDTSC';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 32 RDMSR (Read Model Specific Register) }
    (Mnemonic:'RDMSR';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 33 RDPMC (Read Performance Monitoring Counter, P6+) }
    (Mnemonic:'RDPMC';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 34..$0F 3F reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 40..$0F 4F CMOVcc r16, r/m16 (P6+) }
    { $0F 40 CMOVO }
    (Mnemonic:'CMOVO';    OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 41 CMOVNO }
    (Mnemonic:'CMOVNO';   OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 42 CMOVB }
    (Mnemonic:'CMOVB';    OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 43 CMOVNB }
    (Mnemonic:'CMOVNB';   OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 44 CMOVZ }
    (Mnemonic:'CMOVZ';    OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 45 CMOVNZ }
    (Mnemonic:'CMOVNZ';   OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 46 CMOVBE }
    (Mnemonic:'CMOVBE';   OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 47 CMOVNBE }
    (Mnemonic:'CMOVNBE';  OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 48 CMOVS }
    (Mnemonic:'CMOVS';    OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 49 CMOVNS }
    (Mnemonic:'CMOVNS';   OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 4A CMOVP }
    (Mnemonic:'CMOVP';    OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 4B CMOVNP }
    (Mnemonic:'CMOVNP';   OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 4C CMOVL }
    (Mnemonic:'CMOVL';    OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 4D CMOVNL }
    (Mnemonic:'CMOVNL';   OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 4E CMOVLE }
    (Mnemonic:'CMOVLE';   OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 4F CMOVNLE }
    (Mnemonic:'CMOVNLE';  OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F 50..$0F 5F reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 60..$0F 6F reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 70..$0F 7F reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F 80..$0F 8F Jcc rel16 (sauts conditionnels longs, 80386+) }
    (Mnemonic:'JO';       OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JNO';      OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JB';       OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JNB';      OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JZ';       OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JNZ';      OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JBE';      OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JNBE';     OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JS';       OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JNS';      OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JP';       OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JNP';      OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JL';       OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JNL';      OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JLE';      OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    (Mnemonic:'JNLE';     OpCount:1; Op1Type:OT_REL16; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:4),
    { $0F 90..$0F 9F SETcc r/m8 (set byte on condition, 80386+) }
    (Mnemonic:'SETO';     OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETNO';    OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETB';     OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETNB';    OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETZ';     OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETNZ';    OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETBE';    OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETNBE';   OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETS';     OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETNS';    OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETP';     OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETNP';    OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETL';     OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETNL';    OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETLE';    OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    (Mnemonic:'SETNLE';   OpCount:1; Op1Type:OT_RM8;   Op2Type:OT_NONE;  NeedModRM:True;  BaseSize:2),
    { $0F A0..$0F AF (PUSH FS/GS, BT/BTS/BTR/BTC, SHLD/SHRD, IMUL sur 80386+) }
    { $0F A0 PUSH FS }
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_FS;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F A1 POP FS }
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_FS;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F A2 CPUID (Pentium+, reserve ici) }
    (Mnemonic:'CPUID';    OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F A3 BT r/m16, r16 }
    (Mnemonic:'BT';       OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:2),
    { $0F A4 SHLD r/m16, r16, imm8 }
    (Mnemonic:'SHLD';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_IMM8;  NeedModRM:True;  BaseSize:2),
    { $0F A5 SHLD r/m16, r16, CL }
    (Mnemonic:'SHLD';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_CL;    NeedModRM:True;  BaseSize:2),
    { $0F A6 reserve }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F A7 reserve }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F A8 PUSH GS }
    (Mnemonic:'PUSH';     OpCount:1; Op1Type:OT_GS;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F A9 POP GS }
    (Mnemonic:'POP';      OpCount:1; Op1Type:OT_GS;    Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F AA RSM (resume from SMM, Pentium+) }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F AB BTS r/m16, r16 }
    (Mnemonic:'BTS';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:2),
    { $0F AC SHRD r/m16, r16, imm8 }
    (Mnemonic:'SHRD';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_IMM8;  NeedModRM:True;  BaseSize:2),
    { $0F AD SHRD r/m16, r16, CL }
    (Mnemonic:'SHRD';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_CL;    NeedModRM:True;  BaseSize:2),
    { $0F AE reserve (FXSAVE/FXRSTOR/etc., Pentium+) }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F AF IMUL r16, r/m16 }
    (Mnemonic:'IMUL';     OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F B0..$0F BF (CMPXCHG, MOVZX, MOVSX, BSF, BSR sur 80386+) }
    { $0F B0 CMPXCHG r/m8, r8 (80486+) }
    (Mnemonic:'CMPXCHG';  OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:2),
    { $0F B1 CMPXCHG r/m16, r16 (80486+) }
    (Mnemonic:'CMPXCHG';  OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:2),
    { $0F B2 LSS r16, m16:16 }
    (Mnemonic:'LSS';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_MEM;   NeedModRM:True;  BaseSize:2),
    { $0F B3 BTR r/m16, r16 }
    (Mnemonic:'BTR';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:2),
    { $0F B4 LFS r16, m16:16 }
    (Mnemonic:'LFS';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_MEM;   NeedModRM:True;  BaseSize:2),
    { $0F B5 LGS r16, m16:16 }
    (Mnemonic:'LGS';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_MEM;   NeedModRM:True;  BaseSize:2),
    { $0F B6 MOVZX r16, r/m8 }
    (Mnemonic:'MOVZX';    OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:2),
    { $0F B7 MOVZX r32, r/m16 }
    (Mnemonic:'MOVZX';    OpCount:2; Op1Type:OT_REG32; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F B8 reserve }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F B9 reserve }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F BA GRP8 r/m16, imm8 (BT/BTS/BTR/BTC) }
    (Mnemonic:'GRP8';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_IMM8;  NeedModRM:True;  BaseSize:2),
    { $0F BB BTC r/m16, r16 }
    (Mnemonic:'BTC';      OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:2),
    { $0F BC BSF r16, r/m16 }
    (Mnemonic:'BSF';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F BD BSR r16, r/m16 }
    (Mnemonic:'BSR';      OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F BE MOVSX r16, r/m8 }
    (Mnemonic:'MOVSX';    OpCount:2; Op1Type:OT_REG16; Op2Type:OT_RM8;   NeedModRM:True;  BaseSize:2),
    { $0F BF MOVSX r32, r/m16 }
    (Mnemonic:'MOVSX';    OpCount:2; Op1Type:OT_REG32; Op2Type:OT_RM16;  NeedModRM:True;  BaseSize:2),
    { $0F C0..$0F CF (XADD, BSWAP sur 80486+) }
    { $0F C0 XADD r/m8, r8 (80486+) }
    (Mnemonic:'XADD';     OpCount:2; Op1Type:OT_RM8;   Op2Type:OT_REG8;  NeedModRM:True;  BaseSize:2),
    { $0F C1 XADD r/m16, r16 (80486+) }
    (Mnemonic:'XADD';     OpCount:2; Op1Type:OT_RM16;  Op2Type:OT_REG16; NeedModRM:True;  BaseSize:2),
    { $0F C2..$0F C7 reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F C8..$0F CF BSWAP r32 (80486+) }
    (Mnemonic:'BSWAP';    OpCount:1; Op1Type:OT_REG32; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'BSWAP';    OpCount:1; Op1Type:OT_REG32; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'BSWAP';    OpCount:1; Op1Type:OT_REG32; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'BSWAP';    OpCount:1; Op1Type:OT_REG32; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'BSWAP';    OpCount:1; Op1Type:OT_REG32; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'BSWAP';    OpCount:1; Op1Type:OT_REG32; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'BSWAP';    OpCount:1; Op1Type:OT_REG32; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'BSWAP';    OpCount:1; Op1Type:OT_REG32; Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F D0..$0F DF reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F E0..$0F EF reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    { $0F F0..$0F FF reserves }
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2),
    (Mnemonic:'???';      OpCount:0; Op1Type:OT_NONE;  Op2Type:OT_NONE;  NeedModRM:False; BaseSize:2)
  );
Var
  { Fichiers }
  InputFileName  : TString;
  OutputFileName : TString;
  MapFileName    : TString;
  InFile         : File;
  OutFile        : Text;

  { Options }
  OptForce16     : Boolean;   { forcer mode 16 bits }
  OptForce32     : Boolean;   { forcer mode 32 bits }
  OptVerbose     : Boolean;   { mode verbose }
  OptHex         : Boolean;   { inclure octets hex en commentaire }
  OptUseMap      : Boolean;   { utiliser un fichier .MAP }

  { Entetes }
  MZHeader       : TMZHeader;
  PEFileHeader   : TPEFileHeader;
  PEOptHeader    : TPEOptionalHeader;
  IsPEFile       : Boolean;   { True si fichier PE detecte }
  PEOffset       : LongInt;   { offset de la signature PE }
  DataDirs       : Array[0..MAX_DATA_DIRS - 1] Of TDataDirectory;

  { Sections }
  Sections       : Array[0..MAX_SECTIONS - 1] Of TPESectionHeader;
  SectionCount   : Integer;

  { Image en memoire }
  ImageBuffer    : PByteArray;  { tampon de l'image en memoire }
  ImageSize      : LongInt;
  EntryCS        : Word;        { CS du point d'entree }
  EntryIP        : Word;        { IP du point d'entree }
  EntrySS        : Word;        { SS initial }
  EntrySP        : Word;        { SP initial }
  BaseSegment    : Word;        { facteur de relogement (-reloc:), ajoute a }
                                 { chaque mot fixe par la table de relogement}
                                 { MZ - voir ApplyMZRelocs/WriteASMHeader.   }
  OvlLoadSegment : Word;        { segment de chargement affiche (-loadseg:),}
                                 { PUREMENT COSMETIQUE ici (ImageBuffer est  }
                                 { deja indexe a partir de 0 = ce segment) ; }
                                 { independant de BaseSegment (le VRAI       }
                                 { chargeur d'overlay les fournit separement,}
                                 { voir le commentaire de tete du programme }
                                 { et d'Emu_LoadExeOverlay dans DEVENV.PAS). }
  OvlEntryOfs    : LongInt;     { offset de depart pour l'analyse de flux   }
                                 { (-entry:), defaut 0 - un .OVL n'a PAS de  }
                                 { point d'entree exploitable dans son en-   }
                                 { tete (CS:IP y est ignore par un vrai      }
                                 { chargeur d'overlay, voir WriteASMHeader). }
  PEEntryPointRVA : LongInt;    { RVA du point d'entree PE 32 bits }

  { Labels et references croisees }
  Labels         : Array[0..MAX_LABELS - 1] Of TLabelInfo;
  LabelCount     : LongInt;
  XRefs          : Array[0..MAX_XREFS - 1] Of TXRef;
  XRefCount      : LongInt;

  { Statistiques }
  InstrCount     : LongInt;  { nombre d'instructions desassemblees }
  ProcCount      : LongInt;  { nombre de sous-programmes detectes }
  DataBytes      : LongInt;  { nombre d'octets de donnees }
  ImportCount    : LongInt;  { nombre d'imports }
  ExportCount    : LongInt;  { nombre d'exports }
  Imports        : Array[0..MAX_IMPORTS - 1] Of TImportEntry;
  ExportList     : Array[0..MAX_EXPORTS - 1] Of TExportEntry;
  ExportDLLName  : TString;   { nom de la DLL exportee }
  IterI          : Integer;  { variable d'iteration generale }

  { Relogements DOS MZ }
  MZRelocs       : Array[0..MAX_RELOCS - 1] Of TMZReloc;
  MZRelocCount   : LongInt;  { nombre d'entrees de relogement lues }
  RelocFlags     : PByteArray; { 1 octet par octet de l'image : 1 = position relogee }

  { Relogements PE }
  PERelocs       : Array[0..MAX_RELOCS - 1] Of TPERelocEntry;
  PERelocCount   : LongInt;  { nombre d'entrees de relogement PE }

  { Discrimination code/donnees }
  ByteFlags      : PByteArray; { 1 octet par octet de l'image : BF_xxx }
  StringCount    : LongInt;  { nombre de chaines ASCII detectees }
  StringRefCount : LongInt;  { immediats MOV resolus vers des chaines }
  JumpTblCount   : LongInt;  { nombre de tables de saut detectees }

{ ============================================================
  FONCTIONS UTILITAIRES
  ============================================================ }

Function UpCaseStr(S : TString) : TString;
Var
 I : Integer;
Begin
 For I := 1 To Length(S) Do S[I] := UpCase(S[I]);
 UpCaseStr := S;
End;

Function HexByte(B : Byte) : TString;
Const
 HexDigits : Array[0..15] Of Char = '0123456789ABCDEF';
Begin
 HexByte := HexDigits[B Shr 4] + HexDigits[B And $0F];
End;

Function HexWord(W : Word) : TString;
Begin
 HexWord := HexByte(Hi(W)) + HexByte(Lo(W));
End;

Function HexDWord(D : LongInt) : TString;
Begin
 HexDWord := HexWord(Word(D Shr 16)) + HexWord(Word(D And $FFFF));
End;

Function ChangeFileExt(Const FileName, NewExt : TString) : TString;
Var
 I : Integer;
 Base : TString;
Begin
 Base := FileName;
 For I := Length(FileName) DownTo 1 Do Begin
  If FileName[I] = '.' Then Begin
   Base := Copy(FileName, 1, I - 1);
   Break;
  End;
  If (FileName[I] = '\') Or (FileName[I] = '/') Then Break;
 End;
 ChangeFileExt := Base + NewExt;
End;

Function IntToStr(N : LongInt) : TString;
Var
 S : TString;
Begin
 Str(N, S);
 IntToStr := S;
End;

Function FileExists(Const FileName : TString) : Boolean;
Var
 F : File;
Begin
 Assign(F, FileName);
 {$I-}
 Reset(F, 1);
 {$I+}
 If IOResult = 0 Then Begin
  Close(F);
  FileExists := True;
 End Else
  FileExists := False;
End;

Function GetSectionName(Const Hdr : TPESectionHeader) : TString;
Var
 I : Integer;
 S : TString;
Begin
 S := '';
 For I := 0 To 7 Do Begin
  If Hdr.Name[I] = #0 Then Break;
  S := S + Hdr.Name[I];
 End;
 GetSectionName := S;
End;

Function SectionFlagsStr(Chars : LongInt) : TString;
Var
 S : TString;
Begin
 S := '';
 If (Chars And IMAGE_SCN_CNT_CODE) <> 0 Then S := S + 'CODE ';
 If (Chars And IMAGE_SCN_CNT_INITIALIZED_DATA) <> 0 Then S := S + 'IDATA ';
 If (Chars And IMAGE_SCN_CNT_UNINITIALIZED_DATA) <> 0 Then S := S + 'UDATA ';
 If (Chars And IMAGE_SCN_MEM_EXECUTE) <> 0 Then S := S + 'EXEC ';
 If (Chars And IMAGE_SCN_MEM_READ) <> 0 Then S := S + 'READ ';
 If (Chars And IMAGE_SCN_MEM_WRITE) <> 0 Then S := S + 'WRITE ';
 If S = '' Then S := '-';
 SectionFlagsStr := S;
End;

{ ============================================================
  FONCTIONS D'ACCES A L'IMAGE EN MEMOIRE
  ============================================================ }

Function ReadImageByte(RVA : LongInt) : Byte;
Begin
 If (RVA >= 0) And (RVA < ImageSize) And (ImageBuffer <> Nil) Then
  ReadImageByte := ImageBuffer^[RVA]
 Else
  ReadImageByte := 0;
End;

Function ReadImageWord(RVA : LongInt) : Word;
Begin
 If (RVA >= 0) And (RVA + 1 < ImageSize) And (ImageBuffer <> Nil) Then
  ReadImageWord := ImageBuffer^[RVA] Or (Word(ImageBuffer^[RVA + 1]) Shl 8)
 Else
  ReadImageWord := 0;
End;

Function ReadImageDWord(RVA : LongInt) : LongInt;
Begin
 If (RVA >= 0) And (RVA + 3 < ImageSize) And (ImageBuffer <> Nil) Then
  ReadImageDWord := LongInt(ImageBuffer^[RVA])
                 Or (LongInt(ImageBuffer^[RVA + 1]) Shl 8)
                 Or (LongInt(ImageBuffer^[RVA + 2]) Shl 16)
                 Or (LongInt(ImageBuffer^[RVA + 3]) Shl 24)
 Else
  ReadImageDWord := 0;
End;

Function ReadImageString(RVA : LongInt) : TString;
Var
 S : TString;
 B : Byte;
Begin
 S := '';
 If (RVA >= 0) And (RVA < ImageSize) And (ImageBuffer <> Nil) Then Begin
  While (RVA < ImageSize) And (Length(S) < 255) Do Begin
   B := ImageBuffer^[RVA];
   If B = 0 Then Break;
   S := S + Chr(B);
   Inc(RVA);
  End;
 End;
 ReadImageString := S;
End;

{ ============================================================
  DECODAGE MODR/M 16 BITS
  ============================================================ }

Const
  { Noms des 8 modes d'adressage effectifs 16 bits (r/m 0..7, mod<>11) }
  RM16Names : Array[0..7] Of String[5] = (
    'BX+SI', 'BX+DI', 'BP+SI', 'BP+DI',
    'SI',    'DI',    'BP',    'BX'
  );

{ DecodeModRM16 - Decode l'octet ModR/M pour le mode 16 bits.
  Parametres :
    Offset    : position dans l'image (pointe vers l'octet ModR/M)
    OpSize    : taille de l'operande (1 = 8 bits, 2 = 16 bits)
  Resultats retournes par var :
    RegField  : valeur du champ reg (3 bits, indice de registre)
    RMStr     : chaine d'operande pour le champ r/m
    BytesUsed : nombre d'octets consommes (1 pour ModR/M + deplacements)
}
Procedure DecodeModRM16(Offset : LongInt; OpSize : Byte;
                        Var RegField : Byte; Var RMStr : TString;
                        Var BytesUsed : Integer);
Var
  ModRM    : Byte;
  ModVal   : Byte;   { champ mod (2 bits superieurs) }
  RegVal   : Byte;   { champ reg (3 bits du milieu) }
  RMVal    : Byte;   { champ r/m (3 bits inferieurs) }
  Disp8    : ShortInt;
  Disp16   : SmallInt;
  DispW    : Word;
Begin
  ModRM := ReadImageByte(Offset);
  ModVal := (ModRM Shr 6) And $03;
  RegVal := (ModRM Shr 3) And $07;
  RMVal  := ModRM And $07;
  RegField := RegVal;
  BytesUsed := 1; { au minimum, l'octet ModR/M lui-meme }

  Case ModVal Of
    { mod=11 : registre direct }
    3 : Begin
      If OpSize = 1 Then
        RMStr := RegNames8[RMVal]
      Else
        RMStr := RegNames16[RMVal];
    End;
    { mod=00 : pas de deplacement (sauf cas special r/m=110 -> disp16) }
    0 : Begin
      If RMVal = 6 Then Begin
        { Cas special : adresse directe 16 bits }
        DispW := ReadImageWord(Offset + 1);
        RMStr := '[' + HexWord(DispW) + 'h]';
        BytesUsed := 3; { ModR/M + disp16 }
      End Else Begin
        RMStr := '[' + RM16Names[RMVal] + ']';
      End;
    End;
    { mod=01 : deplacement 8 bits signe }
    1 : Begin
      Disp8 := ShortInt(ReadImageByte(Offset + 1));
      BytesUsed := 2; { ModR/M + disp8 }
      If Disp8 = 0 Then
        RMStr := '[' + RM16Names[RMVal] + ']'
      Else If Disp8 > 0 Then
        RMStr := '[' + RM16Names[RMVal] + '+' + HexByte(Byte(Disp8)) + 'h]'
      Else
        RMStr := '[' + RM16Names[RMVal] + '-' + HexByte(Byte(-Disp8)) + 'h]';
    End;
    { mod=10 : deplacement 16 bits }
    2 : Begin
      Disp16 := SmallInt(ReadImageWord(Offset + 1));
      BytesUsed := 3; { ModR/M + disp16 }
      If Disp16 = 0 Then
        RMStr := '[' + RM16Names[RMVal] + ']'
      Else If Disp16 > 0 Then Begin
        DispW := Word(Disp16);
        RMStr := '[' + RM16Names[RMVal] + '+' + HexWord(DispW) + 'h]';
      End Else Begin
        DispW := Word(-Disp16);
        RMStr := '[' + RM16Names[RMVal] + '-' + HexWord(DispW) + 'h]';
      End;
    End;
  End;
End;

{ DecodeRegField16 - Retourne le nom du registre pour le champ reg (mode 16 bits).
  OpSize = 1 : registre 8 bits, OpSize = 2 : registre 16 bits }
Function DecodeRegField16(RegIndex : Byte; OpSize : Byte) : TString;
Begin
  If OpSize = 1 Then
    DecodeRegField16 := RegNames8[RegIndex And $07]
  Else
    DecodeRegField16 := RegNames16[RegIndex And $07];
End;

{ DecodeModRM16Full - Decode ModR/M et retourne les deux operandes.
  Parametres :
    Offset    : position dans l'image (pointe vers l'octet ModR/M)
    OpSize    : taille de l'operande (1 = 8 bits, 2 = 16 bits)
    DirBit    : True = reg est destination (reg, r/m), False = r/m est destination (r/m, reg)
  Resultats retournes par var :
    Op1Str    : chaine du 1er operande
    Op2Str    : chaine du 2e operande
    BytesUsed : nombre d'octets consommes (ModR/M + deplacements)
}
Procedure DecodeModRM16Full(Offset : LongInt; OpSize : Byte; DirBit : Boolean;
                            Var Op1Str, Op2Str : TString;
                            Var BytesUsed : Integer);
Var
  RegField  : Byte;
  RMStr     : TString;
  RegStr    : TString;
Begin
  DecodeModRM16(Offset, OpSize, RegField, RMStr, BytesUsed);
  RegStr := DecodeRegField16(RegField, OpSize);
  If DirBit Then Begin
    { reg est destination : op1=reg, op2=r/m }
    Op1Str := RegStr;
    Op2Str := RMStr;
  End Else Begin
    { r/m est destination : op1=r/m, op2=reg }
    Op1Str := RMStr;
    Op2Str := RegStr;
  End;
End;

{ ============================================================
  DECODAGE MODR/M ET SIB 32 BITS
  ============================================================ }

Const
  { Facteurs d'echelle SIB : scale field (2 bits) -> multiplicateur }
  ScaleFactors : Array[0..3] Of Byte = (1, 2, 4, 8);

{ DecodeSIB - Decode l'octet SIB (Scale-Index-Base) pour le mode 32 bits.
  Parametres :
    SIBByte   : valeur de l'octet SIB
    ModVal    : valeur du champ mod de l'octet ModR/M (pour cas special base=5)
    Offset    : position dans l'image apres l'octet SIB (pour lire disp32)
  Resultats retournes par var :
    SIBStr    : chaine d'adresse generee (sans crochets)
    ExtraBytes: nombre d'octets supplementaires consommes (0 ou 4 pour disp32)
}
Procedure DecodeSIB(SIBByte : Byte; ModVal : Byte; Offset : LongInt;
                    Var SIBStr : TString; Var ExtraBytes : Integer);
Var
  Scale  : Byte;    { champ scale (2 bits superieurs) }
  Idx    : Byte;    { champ index (3 bits du milieu) }
  Base   : Byte;    { champ base (3 bits inferieurs) }
  Disp32 : LongInt;
  HasBase  : Boolean;
  HasIndex : Boolean;
Begin
  Scale := (SIBByte Shr 6) And $03;
  Idx   := (SIBByte Shr 3) And $07;
  Base  := SIBByte And $07;
  ExtraBytes := 0;
  SIBStr := '';
  HasBase := True;
  HasIndex := True;

  { index=100 (ESP) signifie pas d'index }
  If Idx = 4 Then
    HasIndex := False;

  { base=101 (EBP) avec mod=00 signifie pas de base, disp32 a la place }
  If (Base = 5) And (ModVal = 0) Then Begin
    HasBase := False;
    Disp32 := ReadImageDWord(Offset);
    ExtraBytes := 4;
  End;

  { Construire la chaine d'adresse }
  If HasBase Then
    SIBStr := RegNames32[Base];

  If HasIndex Then Begin
    If SIBStr <> '' Then
      SIBStr := SIBStr + '+';
    SIBStr := SIBStr + RegNames32[Idx];
    If Scale > 0 Then
      SIBStr := SIBStr + '*' + IntToStr(ScaleFactors[Scale]);
  End;

  If Not HasBase Then Begin
    { disp32 sans base }
    If SIBStr <> '' Then
      SIBStr := SIBStr + '+' + HexDWord(Disp32) + 'h'
    Else
      SIBStr := HexDWord(Disp32) + 'h';
  End;

  { Si aucun composant (ne devrait pas arriver normalement) }
  If SIBStr = '' Then
    SIBStr := '0';
End;

{ DecodeModRM32 - Decode l'octet ModR/M pour le mode 32 bits.
  Parametres :
    Offset    : position dans l'image (pointe vers l'octet ModR/M)
    OpSize    : taille de l'operande (1 = 8 bits, 4 = 32 bits)
  Resultats retournes par var :
    RegField  : valeur du champ reg (3 bits, indice de registre)
    RMStr     : chaine d'operande pour le champ r/m
    BytesUsed : nombre d'octets consommes (ModR/M + SIB + deplacements)
}
Procedure DecodeModRM32(Offset : LongInt; OpSize : Byte;
                        Var RegField : Byte; Var RMStr : TString;
                        Var BytesUsed : Integer);
Var
  ModRM    : Byte;
  ModVal   : Byte;    { champ mod (2 bits superieurs) }
  RegVal   : Byte;    { champ reg (3 bits du milieu) }
  RMVal    : Byte;    { champ r/m (3 bits inferieurs) }
  SIBByte  : Byte;
  SIBStr   : TString;
  SIBExtra : Integer;
  Disp8    : ShortInt;
  Disp32   : LongInt;
  DispDW   : LongInt;
Begin
  ModRM := ReadImageByte(Offset);
  ModVal := (ModRM Shr 6) And $03;
  RegVal := (ModRM Shr 3) And $07;
  RMVal  := ModRM And $07;
  RegField := RegVal;
  BytesUsed := 1; { au minimum, l'octet ModR/M lui-meme }

  Case ModVal Of
    { mod=11 : registre direct }
    3 : Begin
      If OpSize = 1 Then
        RMStr := RegNames8[RMVal]
      Else
        RMStr := RegNames32[RMVal];
    End;
    { mod=00 : pas de deplacement }
    0 : Begin
      If RMVal = 5 Then Begin
        { Cas special : adresse directe 32 bits (disp32) }
        Disp32 := ReadImageDWord(Offset + 1);
        RMStr := '[' + HexDWord(Disp32) + 'h]';
        BytesUsed := 5; { ModR/M + disp32 }
      End
      Else If RMVal = 4 Then Begin
        { SIB byte suit le ModR/M }
        SIBByte := ReadImageByte(Offset + 1);
        DecodeSIB(SIBByte, ModVal, Offset + 2, SIBStr, SIBExtra);
        RMStr := '[' + SIBStr + ']';
        BytesUsed := 2 + SIBExtra; { ModR/M + SIB + eventuellement disp32 }
      End Else Begin
        RMStr := '[' + RegNames32[RMVal] + ']';
      End;
    End;
    { mod=01 : deplacement 8 bits signe }
    1 : Begin
      If RMVal = 4 Then Begin
        { SIB byte suit le ModR/M, puis disp8 }
        SIBByte := ReadImageByte(Offset + 1);
        DecodeSIB(SIBByte, ModVal, Offset + 2, SIBStr, SIBExtra);
        Disp8 := ShortInt(ReadImageByte(Offset + 2 + SIBExtra));
        BytesUsed := 3 + SIBExtra; { ModR/M + SIB + disp8 + SIBExtra }
        If Disp8 = 0 Then
          RMStr := '[' + SIBStr + ']'
        Else If Disp8 > 0 Then
          RMStr := '[' + SIBStr + '+' + HexByte(Byte(Disp8)) + 'h]'
        Else
          RMStr := '[' + SIBStr + '-' + HexByte(Byte(-Disp8)) + 'h]';
      End Else Begin
        Disp8 := ShortInt(ReadImageByte(Offset + 1));
        BytesUsed := 2; { ModR/M + disp8 }
        If Disp8 = 0 Then
          RMStr := '[' + RegNames32[RMVal] + ']'
        Else If Disp8 > 0 Then
          RMStr := '[' + RegNames32[RMVal] + '+' + HexByte(Byte(Disp8)) + 'h]'
        Else
          RMStr := '[' + RegNames32[RMVal] + '-' + HexByte(Byte(-Disp8)) + 'h]';
      End;
    End;
    { mod=10 : deplacement 32 bits }
    2 : Begin
      If RMVal = 4 Then Begin
        { SIB byte suit le ModR/M, puis disp32 }
        SIBByte := ReadImageByte(Offset + 1);
        DecodeSIB(SIBByte, ModVal, Offset + 2, SIBStr, SIBExtra);
        Disp32 := ReadImageDWord(Offset + 2 + SIBExtra);
        BytesUsed := 6 + SIBExtra; { ModR/M + SIB + disp32 + SIBExtra }
        If Disp32 = 0 Then
          RMStr := '[' + SIBStr + ']'
        Else If Disp32 > 0 Then Begin
          DispDW := Disp32;
          RMStr := '[' + SIBStr + '+' + HexDWord(DispDW) + 'h]';
        End Else Begin
          DispDW := -Disp32;
          RMStr := '[' + SIBStr + '-' + HexDWord(DispDW) + 'h]';
        End;
      End Else Begin
        Disp32 := ReadImageDWord(Offset + 1);
        BytesUsed := 5; { ModR/M + disp32 }
        If Disp32 = 0 Then
          RMStr := '[' + RegNames32[RMVal] + ']'
        Else If Disp32 > 0 Then Begin
          DispDW := Disp32;
          RMStr := '[' + RegNames32[RMVal] + '+' + HexDWord(DispDW) + 'h]';
        End Else Begin
          DispDW := -Disp32;
          RMStr := '[' + RegNames32[RMVal] + '-' + HexDWord(DispDW) + 'h]';
        End;
      End;
    End;
  End;
End;

{ DecodeRegField32 - Retourne le nom du registre pour le champ reg (mode 32 bits).
  OpSize = 1 : registre 8 bits, OpSize = 4 : registre 32 bits }
Function DecodeRegField32(RegIndex : Byte; OpSize : Byte) : TString;
Begin
  If OpSize = 1 Then
    DecodeRegField32 := RegNames8[RegIndex And $07]
  Else
    DecodeRegField32 := RegNames32[RegIndex And $07];
End;

{ DecodeModRM32Full - Decode ModR/M et retourne les deux operandes (mode 32 bits).
  Parametres :
    Offset    : position dans l'image (pointe vers l'octet ModR/M)
    OpSize    : taille de l'operande (1 = 8 bits, 4 = 32 bits)
    DirBit    : True = reg est destination (reg, r/m), False = r/m est destination (r/m, reg)
  Resultats retournes par var :
    Op1Str    : chaine du 1er operande
    Op2Str    : chaine du 2e operande
    BytesUsed : nombre d'octets consommes (ModR/M + SIB + deplacements)
}
Procedure DecodeModRM32Full(Offset : LongInt; OpSize : Byte; DirBit : Boolean;
                            Var Op1Str, Op2Str : TString;
                            Var BytesUsed : Integer);
Var
  RegField  : Byte;
  RMStr     : TString;
  RegStr    : TString;
Begin
  DecodeModRM32(Offset, OpSize, RegField, RMStr, BytesUsed);
  RegStr := DecodeRegField32(RegField, OpSize);
  If DirBit Then Begin
    { reg est destination : op1=reg, op2=r/m }
    Op1Str := RegStr;
    Op2Str := RMStr;
  End Else Begin
    { r/m est destination : op1=r/m, op2=reg }
    Op1Str := RMStr;
    Op2Str := RegStr;
  End;
End;

{ ============================================================
  DECODAGE DES PREFIXES D'INSTRUCTIONS
  ============================================================ }

Type
  { Etat des prefixes accumules avant une instruction }
  TPrefixState = Record
    HasSegOverride : Boolean;    { True si un prefixe de segment est present }
    SegOverride    : Byte;       { indice segment (0=ES,1=CS,2=SS,3=DS,4=FS,5=GS) }
    SegOverrideStr : String[3];  { chaine du segment ('ES:','CS:',...) }
    HasLock        : Boolean;    { True si LOCK (F0h) est present }
    HasRep         : Boolean;    { True si REP/REPE (F3h) est present }
    HasRepNE       : Boolean;    { True si REPNE (F2h) est present }
    HasOpSize      : Boolean;    { True si prefixe taille operande (66h) }
    HasAddrSize    : Boolean;    { True si prefixe taille adresse (67h) }
    PrefixCount    : Integer;    { nombre total d'octets de prefixes consommes }
    EffOpSize      : Byte;       { taille effective de l'operande (1, 2 ou 4) }
    EffAddrSize    : Byte;       { taille effective de l'adresse (2 ou 4) }
  End;

{ IsPrefix - Retourne True si l'octet est un prefixe d'instruction.
  Prefixes reconnus : 26h,2Eh,36h,3Eh (seg 8086+), 64h,65h (seg 386+),
                      66h (OpSize), 67h (AddrSize), F0h (LOCK),
                      F2h (REPNE), F3h (REP/REPE) }
Function IsPrefix(B : Byte) : Boolean;
Begin
  Case B Of
    $26, $2E, $36, $3E,  { ES:, CS:, SS:, DS: }
    $64, $65,             { FS:, GS: }
    $66,                  { operand size override }
    $67,                  { address size override }
    $F0,                  { LOCK }
    $F2,                  { REPNE/REPNZ }
    $F3 :                 { REP/REPE/REPZ }
      IsPrefix := True;
  Else
    IsPrefix := False;
  End;
End;

{ InitPrefixState - Initialise l'etat des prefixes.
  Mode32 : True si le mode par defaut est 32 bits, False si 16 bits.
  En mode 16 bits : operande 16 bits, adresse 16 bits par defaut.
  En mode 32 bits : operande 32 bits, adresse 32 bits par defaut. }
Procedure InitPrefixState(Var PFX : TPrefixState; Mode32 : Boolean);
Begin
  PFX.HasSegOverride := False;
  PFX.SegOverride    := 0;
  PFX.SegOverrideStr := '';
  PFX.HasLock        := False;
  PFX.HasRep         := False;
  PFX.HasRepNE       := False;
  PFX.HasOpSize      := False;
  PFX.HasAddrSize    := False;
  PFX.PrefixCount    := 0;
  If Mode32 Then Begin
    PFX.EffOpSize   := 4;   { 32 bits par defaut }
    PFX.EffAddrSize := 4;
  End Else Begin
    PFX.EffOpSize   := 2;   { 16 bits par defaut }
    PFX.EffAddrSize := 2;
  End;
End;

{ DecodePrefixes - Lit les octets de prefixes a partir de Offset dans l'image.
  Accumule tous les prefixes consecutifs et met a jour l'etat PFX.
  Mode32 : True si le mode courant est 32 bits.
  PFX doit etre initialise par InitPrefixState avant l'appel.
  Apres l'appel, PFX.PrefixCount contient le nombre d'octets de prefixes.
  L'opcode reel se trouve donc a Offset + PFX.PrefixCount. }
Procedure DecodePrefixes(Offset : LongInt; Mode32 : Boolean;
                         Var PFX : TPrefixState);
Var
  B    : Byte;
  Done : Boolean;
Begin
  Done := False;
  While Not Done Do Begin
    If (Offset + PFX.PrefixCount) >= ImageSize Then
      Break;
    B := ReadImageByte(Offset + PFX.PrefixCount);
    Case B Of
      $26 : Begin { ES: segment override }
        PFX.HasSegOverride := True;
        PFX.SegOverride    := 0;
        PFX.SegOverrideStr := 'ES:';
        Inc(PFX.PrefixCount);
      End;
      $2E : Begin { CS: segment override }
        PFX.HasSegOverride := True;
        PFX.SegOverride    := 1;
        PFX.SegOverrideStr := 'CS:';
        Inc(PFX.PrefixCount);
      End;
      $36 : Begin { SS: segment override }
        PFX.HasSegOverride := True;
        PFX.SegOverride    := 2;
        PFX.SegOverrideStr := 'SS:';
        Inc(PFX.PrefixCount);
      End;
      $3E : Begin { DS: segment override }
        PFX.HasSegOverride := True;
        PFX.SegOverride    := 3;
        PFX.SegOverrideStr := 'DS:';
        Inc(PFX.PrefixCount);
      End;
      $64 : Begin { FS: segment override (80386+) }
        PFX.HasSegOverride := True;
        PFX.SegOverride    := 4;
        PFX.SegOverrideStr := 'FS:';
        Inc(PFX.PrefixCount);
      End;
      $65 : Begin { GS: segment override (80386+) }
        PFX.HasSegOverride := True;
        PFX.SegOverride    := 5;
        PFX.SegOverrideStr := 'GS:';
        Inc(PFX.PrefixCount);
      End;
      $66 : Begin { operand size override (80386+) }
        PFX.HasOpSize := True;
        Inc(PFX.PrefixCount);
        { Bascule la taille d'operande : 32->16 ou 16->32 }
        If Mode32 Then
          PFX.EffOpSize := 2
        Else
          PFX.EffOpSize := 4;
      End;
      $67 : Begin { address size override (80386+) }
        PFX.HasAddrSize := True;
        Inc(PFX.PrefixCount);
        { Bascule la taille d'adresse : 32->16 ou 16->32 }
        If Mode32 Then
          PFX.EffAddrSize := 2
        Else
          PFX.EffAddrSize := 4;
      End;
      $F0 : Begin { LOCK }
        PFX.HasLock := True;
        Inc(PFX.PrefixCount);
      End;
      $F2 : Begin { REPNE/REPNZ }
        PFX.HasRepNE := True;
        PFX.HasRep   := False;  { REPNE ecrase REP si deja vu }
        Inc(PFX.PrefixCount);
      End;
      $F3 : Begin { REP/REPE/REPZ }
        PFX.HasRep   := True;
        PFX.HasRepNE := False;  { REP ecrase REPNE si deja vu }
        Inc(PFX.PrefixCount);
      End;
    Else
      Done := True;  { octet non-prefixe : on arrete }
    End;
  End;
End;

{ PrefixToStr - Retourne la chaine des prefixes accumules pour l'affichage.
  Exemple : 'LOCK REP ES:' si LOCK, REP et ES: sont presents.
  Retourne une chaine vide si aucun prefixe n'est present. }
Function PrefixToStr(Const PFX : TPrefixState) : TString;
Var
  S : TString;
Begin
  S := '';
  If PFX.HasLock Then
    S := S + 'LOCK ';
  If PFX.HasRep Then
    S := S + 'REP ';
  If PFX.HasRepNE Then
    S := S + 'REPNE ';
  PrefixToStr := S;
End;

{ InjectSegOvr - Insere un prefixe de segment devant la premiere reference
  memoire '[' dans la chaine d'operandes S.
  Si aucune reference memoire n'est present, retourne S inchange.
  Exemple : InjectSegOvr('SS:', '[0148h], SP') -> 'SS:[0148h], SP' }
Function InjectSegOvr(Const SegOvr, S : TString) : TString;
Var
  P : Integer;
Begin
  If SegOvr = '' Then Begin
    InjectSegOvr := S;
    Exit;
  End;
  P := Pos('[', S);
  If P > 0 Then
    InjectSegOvr := Copy(S, 1, P - 1) + SegOvr + Copy(S, P, Length(S))
  Else
    InjectSegOvr := S;
End;

{ ============================================================
  DECODAGE DES OPCODES ETENDUS 0Fh
  ============================================================ }

{ Decode0FOpcode - Decode un opcode etendu 0Fh et retourne le mnemonique,
  les operandes et le nombre d'octets consommes APRES l'octet 0Fh.
  Parametres :
    SecondByte : valeur du second octet (apres le 0Fh)
    Offset     : position dans l'image du premier octet APRES le second octet
                 (c.-a-d. l'octet ModR/M ou immediat eventuel)
    PFX        : etat des prefixes (EffOpSize, EffAddrSize, etc.)
  Resultats retournes par var :
    Mnem       : mnemonique de l'instruction (ex: 'JNZ', 'MOVZX', ...)
    Operands   : chaine des operandes (ex: 'EAX, [EBX+04h]')
    BytesUsed  : nombre d'octets consommes APRES le 0Fh (inclut le second octet)
}
Procedure Decode0FOpcode(SecondByte : Byte; Offset : LongInt;
                         Const PFX : TPrefixState;
                         Var Mnem : TString; Var Operands : TString;
                         Var BytesUsed : Integer);
Var
  Entry      : TOpcodeEntry;
  RegField   : Byte;
  RMStr      : TString;
  RegStr     : TString;
  ModRMBytes : Integer;
  Rel16      : SmallInt;
  Rel32      : LongInt;
  Imm8       : Byte;
  TargetAddr : LongInt;
  OpSz       : Byte;       { taille effective d'operande (2 ou 4) }
  AddrSz     : Byte;       { taille effective d'adresse (2 ou 4) }
  ModRM      : Byte;
  RegIdx     : Byte;
Begin
  Entry := Opcode0FTable[SecondByte];
  OpSz  := PFX.EffOpSize;
  AddrSz := PFX.EffAddrSize;
  Mnem := Entry.Mnemonic;
  Operands := '';
  BytesUsed := 1; { le second octet lui-meme est toujours consomme }

  { Instructions inconnues ou reservees }
  If Entry.Mnemonic = '???' Then Begin
    Mnem := 'DB';
    Operands := '0Fh, ' + HexByte(SecondByte) + 'h';
    Exit;
  End;

  { --- Cas speciaux des instructions de groupe (GRP6/GRP7/GRP8) --- }
  If Entry.Mnemonic = 'GRP6' Then Begin
    If Offset < ImageSize Then Begin
      ModRM := ReadImageByte(Offset);
      RegField := (ModRM Shr 3) And $07;
      Mnem := Grp6Mnemonics[RegField];
      If AddrSz = 4 Then
        DecodeModRM32(Offset, 2, RegField, RMStr, ModRMBytes)
      Else
        DecodeModRM16(Offset, 2, RegField, RMStr, ModRMBytes);
      Operands := RMStr;
      BytesUsed := 1 + ModRMBytes;
    End;
    Exit;
  End;

  If Entry.Mnemonic = 'GRP7' Then Begin
    If Offset < ImageSize Then Begin
      ModRM := ReadImageByte(Offset);
      RegField := (ModRM Shr 3) And $07;
      Mnem := Grp7Mnemonics[RegField];
      If AddrSz = 4 Then
        DecodeModRM32(Offset, 2, RegField, RMStr, ModRMBytes)
      Else
        DecodeModRM16(Offset, 2, RegField, RMStr, ModRMBytes);
      Operands := RMStr;
      BytesUsed := 1 + ModRMBytes;
    End;
    Exit;
  End;

  If Entry.Mnemonic = 'GRP8' Then Begin
    If Offset < ImageSize Then Begin
      ModRM := ReadImageByte(Offset);
      RegField := (ModRM Shr 3) And $07;
      Mnem := Grp8Mnemonics[RegField];
      If AddrSz = 4 Then
        DecodeModRM32(Offset, OpSz, RegField, RMStr, ModRMBytes)
      Else
        DecodeModRM16(Offset, OpSz, RegField, RMStr, ModRMBytes);
      Imm8 := ReadImageByte(Offset + ModRMBytes);
      Operands := RMStr + ', ' + HexByte(Imm8) + 'h';
      BytesUsed := 1 + ModRMBytes + 1;
    End;
    Exit;
  End;

  { --- BSWAP : registre encode dans les 3 bits bas du second octet --- }
  If (SecondByte >= $C8) And (SecondByte <= $CF) And
     (Entry.Mnemonic = 'BSWAP') Then Begin
    RegIdx := SecondByte And $07;
    Operands := RegNames32[RegIdx];
    Exit;
  End;

  { --- Jcc near : deplacement relatif 16/32 bits --- }
  If (SecondByte >= $80) And (SecondByte <= $8F) Then Begin
    If OpSz = 4 Then Begin
      Rel32 := ReadImageDWord(Offset);
      TargetAddr := Offset + 4 + Rel32;
      Operands := HexDWord(TargetAddr) + 'h';
      BytesUsed := 1 + 4;
    End Else Begin
      Rel16 := SmallInt(ReadImageWord(Offset));
      TargetAddr := Offset + 2 + Rel16;
      Operands := HexWord(Word(TargetAddr And $FFFF)) + 'h';
      BytesUsed := 1 + 2;
    End;
    Exit;
  End;

  { --- MOV CRn/DRn/TRn : registres speciaux --- }
  If (SecondByte >= $20) And (SecondByte <= $27) And
     (Entry.Mnemonic = 'MOV') Then Begin
    If Offset < ImageSize Then Begin
      ModRM := ReadImageByte(Offset);
      RegField := (ModRM Shr 3) And $07;
      RegIdx := ModRM And $07;
      BytesUsed := 1 + 1; { second byte + ModR/M }
      Case SecondByte Of
        $20 : Operands := RegNames32[RegIdx] + ', ' + CRegNames[RegField And $03];
        $21 : Operands := RegNames32[RegIdx] + ', ' + DRegNames[RegField];
        $22 : Operands := CRegNames[RegField And $03] + ', ' + RegNames32[RegIdx];
        $23 : Operands := DRegNames[RegField] + ', ' + RegNames32[RegIdx];
        $24 : Operands := RegNames32[RegIdx] + ', ' + TRegNames[RegField];
        $26 : Operands := TRegNames[RegField] + ', ' + RegNames32[RegIdx];
      Else
        Operands := '???';
      End;
    End;
    Exit;
  End;

  { --- SHLD/SHRD : 3 operandes (r/m, reg, imm8 ou CL) --- }
  If ((SecondByte = $A4) Or (SecondByte = $A5) Or
      (SecondByte = $AC) Or (SecondByte = $AD)) And
     ((Entry.Mnemonic = 'SHLD') Or (Entry.Mnemonic = 'SHRD')) Then Begin
    If Offset < ImageSize Then Begin
      If AddrSz = 4 Then Begin
        DecodeModRM32(Offset, OpSz, RegField, RMStr, ModRMBytes);
        If OpSz = 4 Then
          RegStr := RegNames32[RegField]
        Else
          RegStr := RegNames16[RegField];
      End Else Begin
        DecodeModRM16(Offset, OpSz, RegField, RMStr, ModRMBytes);
        If OpSz = 4 Then
          RegStr := RegNames32[RegField]
        Else
          RegStr := RegNames16[RegField];
      End;
      If (SecondByte = $A4) Or (SecondByte = $AC) Then Begin
        { SHLD/SHRD r/m, r, imm8 }
        Imm8 := ReadImageByte(Offset + ModRMBytes);
        Operands := RMStr + ', ' + RegStr + ', ' + HexByte(Imm8) + 'h';
        BytesUsed := 1 + ModRMBytes + 1;
      End Else Begin
        { SHLD/SHRD r/m, r, CL }
        Operands := RMStr + ', ' + RegStr + ', CL';
        BytesUsed := 1 + ModRMBytes;
      End;
    End;
    Exit;
  End;

  { --- Instructions sans operande (CLTS, CPUID, INVD, WBINVD, etc.) --- }
  If Entry.OpCount = 0 Then Begin
    Operands := '';
    Exit;
  End;

  { --- Instructions avec 1 operande (SETcc, PUSH/POP FS/GS) --- }
  If Entry.OpCount = 1 Then Begin
    Case Entry.Op1Type Of
      OT_RM8 : Begin
        If Offset < ImageSize Then Begin
          If AddrSz = 4 Then
            DecodeModRM32(Offset, 1, RegField, RMStr, ModRMBytes)
          Else
            DecodeModRM16(Offset, 1, RegField, RMStr, ModRMBytes);
          Operands := RMStr;
          BytesUsed := 1 + ModRMBytes;
        End;
      End;
      OT_FS : Operands := 'FS';
      OT_GS : Operands := 'GS';
      OT_REG32 : Begin
        { BSWAP fallback (deja traite au-dessus normalement) }
        RegIdx := SecondByte And $07;
        Operands := RegNames32[RegIdx];
      End;
    Else
      Operands := '???';
    End;
    Exit;
  End;

  { --- Instructions avec 2 operandes (generique) --- }
  If Entry.OpCount = 2 Then Begin
    { Determiner la taille d'operande effective pour les types 16-bit }
    { Les types RM16/REG16 deviennent RM32/REG32 si EffOpSize=4 }

    { Cas: premier operande = registre, second = r/m (direction reg<-r/m) }
    If (Entry.Op1Type In [OT_REG16, OT_REG32]) And
       (Entry.Op2Type In [OT_RM8, OT_RM16, OT_RM32, OT_MEM]) Then Begin
      If Entry.Op2Type = OT_RM8 Then Begin
        { MOVZX/MOVSX r16, r/m8 ou r32, r/m8 }
        If Offset < ImageSize Then Begin
          If AddrSz = 4 Then
            DecodeModRM32(Offset, 1, RegField, RMStr, ModRMBytes)
          Else
            DecodeModRM16(Offset, 1, RegField, RMStr, ModRMBytes);
          If (Entry.Op1Type = OT_REG32) Or (OpSz = 4) Then
            RegStr := RegNames32[RegField]
          Else
            RegStr := RegNames16[RegField];
          Operands := RegStr + ', ' + RMStr;
          BytesUsed := 1 + ModRMBytes;
        End;
      End
      Else If Entry.Op2Type = OT_RM16 Then Begin
        { MOVZX/MOVSX r32, r/m16 ou CMOVcc r, r/m etc. }
        If Offset < ImageSize Then Begin
          If (Entry.Op1Type = OT_REG32) Then Begin
            { Op1 toujours 32 bits, Op2 toujours 16 bits }
            If AddrSz = 4 Then
              DecodeModRM32(Offset, 2, RegField, RMStr, ModRMBytes)
            Else
              DecodeModRM16(Offset, 2, RegField, RMStr, ModRMBytes);
            RegStr := RegNames32[RegField];
          End Else Begin
            { Op taille selon EffOpSize }
            If AddrSz = 4 Then
              DecodeModRM32(Offset, OpSz, RegField, RMStr, ModRMBytes)
            Else
              DecodeModRM16(Offset, OpSz, RegField, RMStr, ModRMBytes);
            If OpSz = 4 Then
              RegStr := RegNames32[RegField]
            Else
              RegStr := RegNames16[RegField];
          End;
          Operands := RegStr + ', ' + RMStr;
          BytesUsed := 1 + ModRMBytes;
        End;
      End
      Else If Entry.Op2Type = OT_MEM Then Begin
        { LSS/LFS/LGS r, m16:16 }
        If Offset < ImageSize Then Begin
          If AddrSz = 4 Then
            DecodeModRM32(Offset, OpSz, RegField, RMStr, ModRMBytes)
          Else
            DecodeModRM16(Offset, OpSz, RegField, RMStr, ModRMBytes);
          If OpSz = 4 Then
            RegStr := RegNames32[RegField]
          Else
            RegStr := RegNames16[RegField];
          Operands := RegStr + ', ' + RMStr;
          BytesUsed := 1 + ModRMBytes;
        End;
      End
      Else Begin
        { Autre cas RM32, etc. }
        If Offset < ImageSize Then Begin
          If AddrSz = 4 Then
            DecodeModRM32(Offset, OpSz, RegField, RMStr, ModRMBytes)
          Else
            DecodeModRM16(Offset, OpSz, RegField, RMStr, ModRMBytes);
          If OpSz = 4 Then
            RegStr := RegNames32[RegField]
          Else
            RegStr := RegNames16[RegField];
          Operands := RegStr + ', ' + RMStr;
          BytesUsed := 1 + ModRMBytes;
        End;
      End;
      Exit;
    End;

    { Cas: premier operande = r/m, second = registre (direction r/m<-reg) }
    If (Entry.Op1Type In [OT_RM8, OT_RM16, OT_RM32]) And
       (Entry.Op2Type In [OT_REG8, OT_REG16, OT_REG32, OT_IMM8, OT_CL]) Then Begin
      If Offset < ImageSize Then Begin
        If Entry.Op1Type = OT_RM8 Then Begin
          If AddrSz = 4 Then
            DecodeModRM32(Offset, 1, RegField, RMStr, ModRMBytes)
          Else
            DecodeModRM16(Offset, 1, RegField, RMStr, ModRMBytes);
          If Entry.Op2Type = OT_REG8 Then
            RegStr := RegNames8[RegField]
          Else If Entry.Op2Type = OT_IMM8 Then Begin
            Imm8 := ReadImageByte(Offset + ModRMBytes);
            Operands := RMStr + ', ' + HexByte(Imm8) + 'h';
            BytesUsed := 1 + ModRMBytes + 1;
            Exit;
          End Else
            RegStr := 'CL';
        End Else Begin
          { RM16 ou RM32 }
          If AddrSz = 4 Then
            DecodeModRM32(Offset, OpSz, RegField, RMStr, ModRMBytes)
          Else
            DecodeModRM16(Offset, OpSz, RegField, RMStr, ModRMBytes);
          If Entry.Op2Type = OT_REG8 Then
            RegStr := RegNames8[RegField]
          Else If Entry.Op2Type = OT_REG16 Then Begin
            If OpSz = 4 Then
              RegStr := RegNames32[RegField]
            Else
              RegStr := RegNames16[RegField];
          End
          Else If Entry.Op2Type = OT_REG32 Then
            RegStr := RegNames32[RegField]
          Else If Entry.Op2Type = OT_IMM8 Then Begin
            Imm8 := ReadImageByte(Offset + ModRMBytes);
            Operands := RMStr + ', ' + HexByte(Imm8) + 'h';
            BytesUsed := 1 + ModRMBytes + 1;
            Exit;
          End
          Else If Entry.Op2Type = OT_CL Then
            RegStr := 'CL'
          Else
            RegStr := '???';
        End;
        Operands := RMStr + ', ' + RegStr;
        BytesUsed := 1 + ModRMBytes;
      End;
      Exit;
    End;

    { Cas: MOV CRn/DRn/TRn (deja traite ci-dessus normalement) }
    { Fallback generique pour les autres cas a 2 operandes }
    Operands := '???';
  End;
End;

{ ============================================================
  ANALYSE DU FLUX DE CONTROLE ET REFERENCES CROISEES
  ============================================================ }

{ AddLabel - Ajoute un label a la table des labels.
  Si l'adresse existe deja, ne fait rien (evite les doublons).
  Parametres :
    Addr   : adresse dans l'image
    AName  : nom du label (vide pour auto-generation)
    Proc   : True si c'est un sous-programme (cible de CALL)
    Imp    : True si c'est un import
    Exp    : True si c'est un export
  Retourne True si le label a ete ajoute, False si deja present ou table pleine. }
Function AddLabel(Addr : LongInt; AName : TString;
                  Proc, Imp, Exp : Boolean) : Boolean;
Var
  I : LongInt;
Begin
  { Verifier si l'adresse existe deja }
  For I := 0 To LabelCount - 1 Do Begin
    If Labels[I].Address = Addr Then Begin
      { Mettre a jour les flags si necessaire }
      If Proc Then Labels[I].IsProc := True;
      If Imp Then Labels[I].IsImport := True;
      If Exp Then Labels[I].IsExport := True;
      If (AName <> '') And (Labels[I].Name = '') Then
        Labels[I].Name := AName;
      AddLabel := False;
      Exit;
    End;
  End;
  { Verifier si la table est pleine }
  If LabelCount >= MAX_LABELS Then Begin
    AddLabel := False;
    Exit;
  End;
  { Ajouter le nouveau label }
  Labels[LabelCount].Address  := Addr;
  Labels[LabelCount].Name     := AName;
  Labels[LabelCount].IsProc   := Proc;
  Labels[LabelCount].IsImport := Imp;
  Labels[LabelCount].IsExport := Exp;
  Inc(LabelCount);
  AddLabel := True;
End;

{ FindLabel - Recherche un label par adresse.
  Retourne l'indice dans Labels[] ou -1 si non trouve. }
Function FindLabel(Addr : LongInt) : LongInt;
Var
  I : LongInt;
Begin
  For I := 0 To LabelCount - 1 Do Begin
    If Labels[I].Address = Addr Then Begin
      FindLabel := I;
      Exit;
    End;
  End;
  FindLabel := -1;
End;

{ AddXRef - Ajoute une reference croisee a la table.
  Parametres :
    FromA  : adresse source (adresse de l'instruction de branchement)
    ToA    : adresse cible (destination du saut/appel)
    IsCALL : True si c'est un CALL, False si c'est un JMP/Jcc/LOOP
  Retourne True si ajoute, False si table pleine. }
Function AddXRef(FromA, ToA : LongInt; IsCALL : Boolean) : Boolean;
Begin
  If XRefCount >= MAX_XREFS Then Begin
    AddXRef := False;
    Exit;
  End;
  XRefs[XRefCount].FromAddr := FromA;
  XRefs[XRefCount].ToAddr   := ToA;
  XRefs[XRefCount].IsCall   := IsCALL;
  Inc(XRefCount);
  AddXRef := True;
End;

{ SortLabels - Tri des labels par adresse croissante (tri a bulles simple). }
Procedure SortLabels;
Var
  I, J  : LongInt;
  Tmp   : TLabelInfo;
Begin
  For I := 0 To LabelCount - 2 Do
    For J := 0 To LabelCount - 2 - I Do
      If Labels[J].Address > Labels[J + 1].Address Then Begin
        Tmp := Labels[J];
        Labels[J] := Labels[J + 1];
        Labels[J + 1] := Tmp;
      End;
End;

{ SortXRefs - Tri des references croisees par adresse cible croissante. }
Procedure SortXRefs;
Var
  I, J : LongInt;
  Tmp  : TXRef;
Begin
  For I := 0 To XRefCount - 2 Do
    For J := 0 To XRefCount - 2 - I Do
      If XRefs[J].ToAddr > XRefs[J + 1].ToAddr Then Begin
        Tmp := XRefs[J];
        XRefs[J] := XRefs[J + 1];
        XRefs[J + 1] := Tmp;
      End;
End;

{ ComputeModRMSize16 - Calcule le nombre d'octets ModR/M + deplacement en mode 16 bits.
  Retourne le nombre d'octets (1..3). }
Function ComputeModRMSize16(Offset : LongInt) : Integer;
Var
  ModRM  : Byte;
  ModVal : Byte;
  RMVal  : Byte;
Begin
  ModRM  := ReadImageByte(Offset);
  ModVal := (ModRM Shr 6) And $03;
  RMVal  := ModRM And $07;
  Case ModVal Of
    0 : If RMVal = 6 Then
          ComputeModRMSize16 := 3   { ModR/M + disp16 }
        Else
          ComputeModRMSize16 := 1;  { ModR/M seul }
    1 : ComputeModRMSize16 := 2;    { ModR/M + disp8 }
    2 : ComputeModRMSize16 := 3;    { ModR/M + disp16 }
    3 : ComputeModRMSize16 := 1;    { ModR/M seul (registre) }
  Else
    ComputeModRMSize16 := 1;
  End;
End;

{ ComputeModRMSize32 - Calcule le nombre d'octets ModR/M + SIB + deplacement en mode 32 bits.
  Retourne le nombre d'octets (1..6). }
Function ComputeModRMSize32(Offset : LongInt) : Integer;
Var
  ModRM   : Byte;
  ModVal  : Byte;
  RMVal   : Byte;
  SIBByte : Byte;
  SIBBase : Byte;
  Size    : Integer;
Begin
  ModRM  := ReadImageByte(Offset);
  ModVal := (ModRM Shr 6) And $03;
  RMVal  := ModRM And $07;
  Size := 1; { ModR/M byte }
  Case ModVal Of
    3 : Begin { registre direct }
      ComputeModRMSize32 := 1;
      Exit;
    End;
    0 : Begin
      If RMVal = 5 Then Begin
        ComputeModRMSize32 := 5; { ModR/M + disp32 }
        Exit;
      End;
      If RMVal = 4 Then Begin
        { SIB byte present }
        SIBByte := ReadImageByte(Offset + 1);
        SIBBase := SIBByte And $07;
        Size := 2; { ModR/M + SIB }
        If SIBBase = 5 Then
          Size := Size + 4; { + disp32 }
        ComputeModRMSize32 := Size;
        Exit;
      End;
      ComputeModRMSize32 := 1;
      Exit;
    End;
    1 : Begin
      If RMVal = 4 Then
        ComputeModRMSize32 := 3  { ModR/M + SIB + disp8 }
      Else
        ComputeModRMSize32 := 2; { ModR/M + disp8 }
      Exit;
    End;
    2 : Begin
      If RMVal = 4 Then
        ComputeModRMSize32 := 6  { ModR/M + SIB + disp32 }
      Else
        ComputeModRMSize32 := 5; { ModR/M + disp32 }
      Exit;
    End;
  End;
  ComputeModRMSize32 := Size;
End;

{ ComputeModRMSize - Calcule la taille ModR/M selon la taille d'adresse effective. }
Function ComputeModRMSize(Offset : LongInt; AddrSz : Byte) : Integer;
Begin
  If AddrSz = 4 Then
    ComputeModRMSize := ComputeModRMSize32(Offset)
  Else
    ComputeModRMSize := ComputeModRMSize16(Offset);
End;

{ Compute0FInstrSize - Calcule la taille d'un opcode etendu 0Fh
  (en octets apres le prefixe 0Fh, inclut le second octet).
  Parametres :
    Offset : position du second octet (apres 0Fh) dans l'image
    PFX    : etat des prefixes
  Retourne le nombre d'octets consommes APRES le 0Fh. }
Function Compute0FInstrSize(Offset : LongInt; Const PFX : TPrefixState) : Integer;
Var
  SecondByte : Byte;
  Entry      : TOpcodeEntry;
  OpSz       : Byte;
  AddrSz     : Byte;
  MRMSize    : Integer;
Begin
  SecondByte := ReadImageByte(Offset);
  Entry := Opcode0FTable[SecondByte];
  OpSz  := PFX.EffOpSize;
  AddrSz := PFX.EffAddrSize;

  { Instructions reservees/inconnues }
  If Entry.Mnemonic = '???' Then Begin
    Compute0FInstrSize := 1;
    Exit;
  End;

  { GRP6/GRP7 : ModR/M }
  If (Entry.Mnemonic = 'GRP6') Or (Entry.Mnemonic = 'GRP7') Then Begin
    MRMSize := ComputeModRMSize(Offset + 1, AddrSz);
    Compute0FInstrSize := 1 + MRMSize;
    Exit;
  End;

  { GRP8 : ModR/M + imm8 }
  If Entry.Mnemonic = 'GRP8' Then Begin
    MRMSize := ComputeModRMSize(Offset + 1, AddrSz);
    Compute0FInstrSize := 1 + MRMSize + 1;
    Exit;
  End;

  { BSWAP : juste le second octet }
  If (SecondByte >= $C8) And (SecondByte <= $CF) Then Begin
    Compute0FInstrSize := 1;
    Exit;
  End;

  { Jcc near : rel16/rel32 }
  If (SecondByte >= $80) And (SecondByte <= $8F) Then Begin
    If OpSz = 4 Then
      Compute0FInstrSize := 1 + 4  { second byte + rel32 }
    Else
      Compute0FInstrSize := 1 + 2; { second byte + rel16 }
    Exit;
  End;

  { MOV CRn/DRn/TRn : second byte + ModR/M }
  If (SecondByte >= $20) And (SecondByte <= $27) Then Begin
    Compute0FInstrSize := 1 + 1;
    Exit;
  End;

  { SHLD/SHRD : second byte + ModR/M + (imm8 ou rien) }
  If (SecondByte = $A4) Or (SecondByte = $AC) Then Begin
    { SHLD/SHRD r/m, r, imm8 }
    MRMSize := ComputeModRMSize(Offset + 1, AddrSz);
    Compute0FInstrSize := 1 + MRMSize + 1;
    Exit;
  End;
  If (SecondByte = $A5) Or (SecondByte = $AD) Then Begin
    { SHLD/SHRD r/m, r, CL }
    MRMSize := ComputeModRMSize(Offset + 1, AddrSz);
    Compute0FInstrSize := 1 + MRMSize;
    Exit;
  End;

  { Instructions sans operande }
  If Entry.OpCount = 0 Then Begin
    Compute0FInstrSize := 1;
    Exit;
  End;

  { Instructions avec ModR/M (1 ou 2 operandes) }
  If Entry.NeedModRM Then Begin
    MRMSize := ComputeModRMSize(Offset + 1, AddrSz);
    Compute0FInstrSize := 1 + MRMSize;
    Exit;
  End;

  { Fallback }
  Compute0FInstrSize := 1;
End;

{ ComputeInstrSize - Calcule la taille totale d'une instruction a l'offset donne.
  Inclut les prefixes. Retourne le nombre d'octets de l'instruction complete.
  Parametres :
    Offset : position du premier octet de l'instruction dans l'image
    Mode32 : True si mode 32 bits par defaut
}
Function ComputeInstrSize(Offset : LongInt; Mode32 : Boolean) : Integer;
Var
  PFX       : TPrefixState;
  OpcOffset : LongInt;    { offset de l'opcode reel (apres les prefixes) }
  Opcode    : Byte;
  Entry     : TOpcodeEntry;
  OpSz      : Byte;
  AddrSz    : Byte;
  Size      : Integer;
  MRMSize   : Integer;
  RegField  : Byte;
Begin
  InitPrefixState(PFX, Mode32);
  DecodePrefixes(Offset, Mode32, PFX);
  OpcOffset := Offset + PFX.PrefixCount;

  If OpcOffset >= ImageSize Then Begin
    ComputeInstrSize := 1;
    Exit;
  End;

  Opcode := ReadImageByte(OpcOffset);
  OpSz   := PFX.EffOpSize;
  AddrSz := PFX.EffAddrSize;
  Size   := PFX.PrefixCount;

  { Opcode etendu 0Fh }
  If Opcode = $0F Then Begin
    Size := Size + 1 + Compute0FInstrSize(OpcOffset + 1, PFX);
    ComputeInstrSize := Size;
    Exit;
  End;

  Entry := OpcodeTable[Opcode];

  { Instructions inconnues }
  If Entry.Mnemonic = '???' Then Begin
    ComputeInstrSize := Size + 1;
    Exit;
  End;

  { Instructions de groupe GRP1..GRP5 avec ModR/M }
  If (Entry.Mnemonic = 'GRP1') Or (Entry.Mnemonic = 'GRP2') Or
     (Entry.Mnemonic = 'GRP3') Or (Entry.Mnemonic = 'GRP4') Or
     (Entry.Mnemonic = 'GRP5') Then Begin
    MRMSize := ComputeModRMSize(OpcOffset + 1, AddrSz);
    Size := Size + 1 + MRMSize; { opcode + ModR/M+disp }
    { Ajouter l'immediat si present }
    Case Opcode Of
      $80 : Size := Size + 1; { GRP1 r/m8, imm8 }
      $81 : If OpSz = 4 Then  { GRP1 r/m16, imm16 ou r/m32, imm32 }
              Size := Size + 4
            Else
              Size := Size + 2;
      $82 : Size := Size + 1; { GRP1 r/m8, imm8 (alias) }
      $83 : Size := Size + 1; { GRP1 r/m16, imm8x }
      $C0 : Size := Size + 1; { GRP2 r/m8, imm8 }
      $C1 : Size := Size + 1; { GRP2 r/m16, imm8 }
      $F6 : Begin { GRP3 r/m8 : TEST a un imm8, les autres non }
              RegField := (ReadImageByte(OpcOffset + 1) Shr 3) And $07;
              If RegField = 0 Then Size := Size + 1; { TEST r/m8, imm8 }
            End;
      $F7 : Begin { GRP3 r/m16 : TEST a un imm16, les autres non }
              RegField := (ReadImageByte(OpcOffset + 1) Shr 3) And $07;
              If RegField = 0 Then Begin
                If OpSz = 4 Then
                  Size := Size + 4
                Else
                  Size := Size + 2;
              End;
            End;
    End;
    ComputeInstrSize := Size;
    Exit;
  End;

  { Taille de base }
  Size := Size + Entry.BaseSize;

  { Ajuster pour le mode 32 bits (certains operandes changent de taille) }
  If OpSz = 4 Then Begin
    { IMM16 -> IMM32 en mode 32 bits }
    If Entry.Op1Type = OT_IMM16 Then
      Size := Size + 2  { 16->32 bits : +2 octets }
    Else If Entry.Op2Type = OT_IMM16 Then
      Size := Size + 2;
    { REL16 -> REL32 en mode 32 bits }
    If Entry.Op1Type = OT_REL16 Then
      Size := Size + 2;
    { AX -> EAX, MEM16 -> MEM32, FAR -> FAR 32 }
    If (Entry.Op1Type = OT_MEM16) Or (Entry.Op2Type = OT_MEM16) Then Begin
      If AddrSz = 4 Then
        Size := Size + 2; { adresse 16->32 bits : +2 octets }
    End;
    If Entry.Op1Type = OT_FAR Then
      Size := Size + 2; { segment:offset32 au lieu de segment:offset16 }
  End;
  If AddrSz = 4 Then Begin
    If (Entry.Op1Type = OT_MEM16) Or (Entry.Op2Type = OT_MEM16) Then Begin
      If OpSz <> 4 Then { Si pas deja ajuste ci-dessus }
        Size := Size + 2;
    End;
  End;

  { Ajouter la taille du ModR/M si necessaire }
  If Entry.NeedModRM Then Begin
    MRMSize := ComputeModRMSize(OpcOffset + 1, AddrSz);
    Size := Size + MRMSize;
    { Ajouter l'immediat pour certains opcodes a 2 operandes }
    If Entry.Op2Type = OT_IMM8 Then
      Size := Size + 1
    Else If Entry.Op2Type = OT_IMM8X Then
      Size := Size + 1
    Else If Entry.Op2Type = OT_IMM16 Then Begin
      If OpSz = 4 Then
        Size := Size + 4
      Else
        Size := Size + 2;
    End;
  End;

  ComputeInstrSize := Size;
End;

{ BranchType constants for classification }
Const
  BT_NONE     = 0;  { pas une instruction de branchement }
  BT_JCC_REL8 = 1;  { saut conditionnel court (Jcc rel8, LOOP, JCXZ) }
  BT_JMP_REL8 = 2;  { saut inconditionnel court (JMP rel8) }
  BT_JCC_REL  = 3;  { saut conditionnel near (0F 80..8F rel16/rel32) }
  BT_JMP_REL  = 4;  { saut inconditionnel near (JMP rel16/rel32) }
  BT_JMP_FAR  = 5;  { saut far (JMP far) }
  BT_CALL_REL = 6;  { appel near relatif (CALL rel16/rel32) }
  BT_CALL_FAR = 7;  { appel far (CALL far) }
  BT_CALL_IND = 8;  { appel indirect (GRP5 reg=2 ou 3) }
  BT_JMP_IND  = 9;  { saut indirect (GRP5 reg=4 ou 5) }
  BT_RET      = 10; { retour near (RET) }
  BT_RETF     = 11; { retour far (RETF) }
  BT_IRET     = 12; { retour d'interruption (IRET) }

{ ByteFlags - Marqueurs pour la discrimination code/donnees }
  BF_UNKNOWN = 0;  { octet non classifie }
  BF_CODE    = 1;  { octet d'instruction }
  BF_DATA    = 2;  { octet de donnees (DB) }
  BF_STRING  = 3;  { octet de chaine ASCII }
  BF_JUMPTBL = 4;  { entree de table de saut }
  BF_PADDING = 5;  { padding/alignement (NOP, INT3, 00) }
  BF_PSTRING = 6;  { chaine Pascal : longueur sur un octet + caracteres }

{ ClassifyInstruction - Classifie une instruction selon son type de flux.
  Parametres :
    Offset : position du premier octet de l'instruction (apres les prefixes)
    Mode32 : True si mode 32 bits
  Retourne une constante BT_xxx. }
Function ClassifyInstruction(Offset : LongInt; Mode32 : Boolean) : Integer;
Var
  PFX       : TPrefixState;
  OpcOffset : LongInt;
  Opcode    : Byte;
  SecondByte: Byte;
  RegField  : Byte;
Begin
  InitPrefixState(PFX, Mode32);
  DecodePrefixes(Offset, Mode32, PFX);
  OpcOffset := Offset + PFX.PrefixCount;

  If OpcOffset >= ImageSize Then Begin
    ClassifyInstruction := BT_NONE;
    Exit;
  End;

  Opcode := ReadImageByte(OpcOffset);

  { Sauts conditionnels courts $70-$7F }
  If (Opcode >= $70) And (Opcode <= $7F) Then Begin
    ClassifyInstruction := BT_JCC_REL8;
    Exit;
  End;

  { LOOP, LOOPZ, LOOPNZ, JCXZ $E0-$E3 }
  If (Opcode >= $E0) And (Opcode <= $E3) Then Begin
    ClassifyInstruction := BT_JCC_REL8;
    Exit;
  End;

  { JMP short $EB }
  If Opcode = $EB Then Begin
    ClassifyInstruction := BT_JMP_REL8;
    Exit;
  End;

  { JMP near rel16/rel32 $E9 }
  If Opcode = $E9 Then Begin
    ClassifyInstruction := BT_JMP_REL;
    Exit;
  End;

  { JMP far $EA }
  If Opcode = $EA Then Begin
    ClassifyInstruction := BT_JMP_FAR;
    Exit;
  End;

  { CALL near rel16/rel32 $E8 }
  If Opcode = $E8 Then Begin
    ClassifyInstruction := BT_CALL_REL;
    Exit;
  End;

  { CALL far $9A }
  If Opcode = $9A Then Begin
    ClassifyInstruction := BT_CALL_FAR;
    Exit;
  End;

  { RET $C2, $C3 }
  If (Opcode = $C2) Or (Opcode = $C3) Then Begin
    ClassifyInstruction := BT_RET;
    Exit;
  End;

  { RETF $CA, $CB }
  If (Opcode = $CA) Or (Opcode = $CB) Then Begin
    ClassifyInstruction := BT_RETF;
    Exit;
  End;

  { IRET $CF }
  If Opcode = $CF Then Begin
    ClassifyInstruction := BT_IRET;
    Exit;
  End;

  { GRP5 $FF : CALL indirect (reg=2,3) et JMP indirect (reg=4,5) }
  If Opcode = $FF Then Begin
    If (OpcOffset + 1) < ImageSize Then Begin
      RegField := (ReadImageByte(OpcOffset + 1) Shr 3) And $07;
      If (RegField = 2) Or (RegField = 3) Then Begin
        ClassifyInstruction := BT_CALL_IND;
        Exit;
      End;
      If (RegField = 4) Or (RegField = 5) Then Begin
        ClassifyInstruction := BT_JMP_IND;
        Exit;
      End;
    End;
  End;

  { Opcode etendu 0Fh }
  If Opcode = $0F Then Begin
    If (OpcOffset + 1) < ImageSize Then Begin
      SecondByte := ReadImageByte(OpcOffset + 1);
      { Jcc near $0F 80-8F }
      If (SecondByte >= $80) And (SecondByte <= $8F) Then Begin
        ClassifyInstruction := BT_JCC_REL;
        Exit;
      End;
    End;
  End;

  ClassifyInstruction := BT_NONE;
End;

{ ComputeBranchTarget - Calcule l'adresse cible d'une instruction de branchement.
  Parametres :
    Offset     : position du premier octet de l'instruction dans l'image
    Mode32     : True si mode 32 bits
    BranchType : type de branchement (BT_xxx) retourne par ClassifyInstruction
  Retourne l'adresse cible, ou -1 si impossible a calculer (indirect, far). }
Function ComputeBranchTarget(Offset : LongInt; Mode32 : Boolean;
                             BranchType : Integer) : LongInt;
Var
  PFX       : TPrefixState;
  OpcOffset : LongInt;
  OpSz      : Byte;
  Rel8      : ShortInt;
  Rel16     : SmallInt;
  Rel32     : LongInt;
  InstrSize : Integer;
Begin
  InitPrefixState(PFX, Mode32);
  DecodePrefixes(Offset, Mode32, PFX);
  OpcOffset := Offset + PFX.PrefixCount;
  OpSz := PFX.EffOpSize;
  InstrSize := ComputeInstrSize(Offset, Mode32);

  ComputeBranchTarget := -1;

  Case BranchType Of
    BT_JCC_REL8, BT_JMP_REL8 : Begin
      { rel8 est le dernier octet de l'instruction }
      Rel8 := ShortInt(ReadImageByte(OpcOffset + 1));
      ComputeBranchTarget := Offset + InstrSize + Rel8;
    End;
    BT_JMP_REL : Begin
      { JMP rel16/rel32 - l'immediat commence apres l'opcode }
      If OpSz = 4 Then Begin
        Rel32 := ReadImageDWord(OpcOffset + 1);
        ComputeBranchTarget := Offset + InstrSize + Rel32;
      End Else Begin
        Rel16 := SmallInt(ReadImageWord(OpcOffset + 1));
        ComputeBranchTarget := Offset + InstrSize + Rel16;
      End;
    End;
    BT_CALL_REL : Begin
      { CALL rel16/rel32 }
      If OpSz = 4 Then Begin
        Rel32 := ReadImageDWord(OpcOffset + 1);
        ComputeBranchTarget := Offset + InstrSize + Rel32;
      End Else Begin
        Rel16 := SmallInt(ReadImageWord(OpcOffset + 1));
        ComputeBranchTarget := Offset + InstrSize + Rel16;
      End;
    End;
    BT_JCC_REL : Begin
      { 0F 80..8F rel16/rel32 - immediat commence apres 0F + second byte }
      If OpSz = 4 Then Begin
        Rel32 := ReadImageDWord(OpcOffset + 2);
        ComputeBranchTarget := Offset + InstrSize + Rel32;
      End Else Begin
        Rel16 := SmallInt(ReadImageWord(OpcOffset + 2));
        ComputeBranchTarget := Offset + InstrSize + Rel16;
      End;
    End;
  Else
    { FAR, indirect, RET, IRET : cible non calculable }
    ComputeBranchTarget := -1;
  End;
End;

{ GenerateLabelName - Genere un nom automatique pour un label.
  Parametres :
    Addr   : adresse du label
    IsProc : True si c'est un sous-programme
    Mode32 : True si mode 32 bits (noms longs) }
Function GenerateLabelName(Addr : LongInt; IsProc : Boolean;
                           Mode32 : Boolean) : TString;
Begin
  If IsProc Then Begin
    If Mode32 Then
      GenerateLabelName := 'sub_' + HexDWord(Addr)
    Else
      GenerateLabelName := 'sub_' + HexWord(Word(Addr));
  End Else Begin
    If Mode32 Then
      GenerateLabelName := 'loc_' + HexDWord(Addr)
    Else
      GenerateLabelName := 'loc_' + HexWord(Word(Addr));
  End;
End;

{ AnalyzeControlFlow - Premiere passe de desassemblage lineaire.
  Parcourt le code a partir du point d'entree et identifie :
  - Les instructions de saut (JMP, Jcc, LOOP) et d'appel (CALL)
  - Les adresses cibles -> ajoutees comme labels et references croisees
  - Les instructions de retour (RET, RETF, IRET)
  Construit la table des labels et des XRefs.
  Parametres :
    StartOffset : adresse du premier octet de code dans l'image
    EndOffset   : adresse apres le dernier octet de code
    Mode32      : True si mode 32 bits
}
Procedure AnalyzeControlFlow(StartOffset, EndOffset : LongInt;
                             Mode32 : Boolean);
Var
  CurOffset  : LongInt;
  ISize      : Integer;
  BType      : Integer;
  Target     : LongInt;
  LabelName  : TString;
  BadCount   : Integer;  { compteur d'instructions invalides consecutives }
Begin
  { Ajouter le point d'entree comme label en premier }
  LabelName := GenerateLabelName(StartOffset, True, Mode32);
  AddLabel(StartOffset, LabelName, True, False, False);

  CurOffset := StartOffset;
  BadCount := 0;
  While CurOffset < EndOffset Do Begin
    { Verifier les bornes }
    If CurOffset >= ImageSize Then Break;
    If CurOffset < 0 Then Break;

    { Calculer la taille de l'instruction courante }
    ISize := ComputeInstrSize(CurOffset, Mode32);
    If ISize <= 0 Then Begin
      ISize := 1; { securite }
      Inc(BadCount);
      If BadCount > 16 Then Break; { eviter boucle infinie }
    End Else
      BadCount := 0;

    { Classifier l'instruction }
    BType := ClassifyInstruction(CurOffset, Mode32);

    If BType <> BT_NONE Then Begin
      { Calculer l'adresse cible }
      Target := ComputeBranchTarget(CurOffset, Mode32, BType);

      If Target >= 0 Then Begin
        { Verifier que la cible est dans les bornes de l'image }
        If (Target >= 0) And (Target < ImageSize) Then Begin
          { Determiner si c'est un appel (CALL) ou un saut (JMP/Jcc) }
          If (BType = BT_CALL_REL) Then Begin
            { Cible de CALL : marquer comme sous-programme }
            LabelName := GenerateLabelName(Target, True, Mode32);
            AddLabel(Target, LabelName, True, False, False);
            AddXRef(CurOffset, Target, True);
            Inc(ProcCount);
          End Else If (BType >= BT_JCC_REL8) And (BType <= BT_JMP_REL) Then Begin
            { Cible de saut : marquer comme label de code }
            LabelName := GenerateLabelName(Target, False, Mode32);
            AddLabel(Target, LabelName, False, False, False);
            AddXRef(CurOffset, Target, False);
          End;
        End;
      End;

      { Pour les sauts inconditionnels et les retours, noter la fin du bloc }
      { (les adresses suivantes pourraient etre des donnees) }
    End;

    { Compter l'instruction }
    Inc(InstrCount);

    { Avancer a l'instruction suivante }
    CurOffset := CurOffset + ISize;
  End;

  { Ajouter les labels pour les imports PE }
  If IsPEFile Then Begin
    For IterI := 0 To ImportCount - 1 Do Begin
      If Imports[IterI].IATAddr > 0 Then Begin
        If Imports[IterI].FuncName <> '' Then
          AddLabel(Imports[IterI].IATAddr, Imports[IterI].FuncName, True, True, False)
        Else
          AddLabel(Imports[IterI].IATAddr, 'ord_' + HexWord(Imports[IterI].Ordinal),
                   True, True, False);
      End;
    End;
  End;

  { Ajouter les labels pour les exports PE }
  If IsPEFile Then Begin
    For IterI := 0 To ExportCount - 1 Do Begin
      If ExportList[IterI].FuncRVA > 0 Then Begin
        If ExportList[IterI].HasName And (ExportList[IterI].FuncName <> '') Then
          AddLabel(ExportList[IterI].FuncRVA, ExportList[IterI].FuncName, True, False, True)
        Else
          AddLabel(ExportList[IterI].FuncRVA,
                   'export_' + HexWord(ExportList[IterI].Ordinal),
                   True, False, True);
      End;
    End;
  End;

  { Trier les labels et les XRefs pour un acces efficace }
  SortLabels;
  SortXRefs;
End;

{ ============================================================
  DETECTION DES PROCEDURES, FONCTIONS ET POINTS D'ENTREE
  ============================================================ }

{ IsProloguePattern - Detecte un pattern de prologue de fonction.
  Mode 16 bits : PUSH BP ($55) suivi de MOV BP,SP ($8B $EC ou $89 $E5)
  Mode 32 bits : PUSH EBP ($55) suivi de MOV EBP,ESP ($8B $EC ou $89 $E5)
  Note : en mode 32 bits, $55 = PUSH EBP et les encodages MOV sont
  identiques a ceux du mode 16 bits car reg/rm utilisent les memes
  champs pour BP/SP et EBP/ESP selon la taille d'operande effective.
  Retourne True si un pattern de prologue est detecte a Offset. }
Function IsProloguePattern(Offset : LongInt; Mode32 : Boolean) : Boolean;
Var
  B0, B1, B2 : Byte;
Begin
  IsProloguePattern := False;
  If (Offset < 0) Or (Offset + 2 >= ImageSize) Then Exit;
  B0 := ReadImageByte(Offset);
  B1 := ReadImageByte(Offset + 1);
  B2 := ReadImageByte(Offset + 2);
  { PUSH BP/EBP = $55 }
  If B0 <> $55 Then Exit;
  { MOV BP,SP / MOV EBP,ESP }
  { Encodage 1 : $8B $EC (MOV reg,r/m avec reg=BP/EBP, r/m=SP/ESP) }
  { Encodage 2 : $89 $E5 (MOV r/m,reg avec r/m=BP/EBP, reg=SP/ESP) }
  If ((B1 = $8B) And (B2 = $EC)) Or
     ((B1 = $89) And (B2 = $E5)) Then
    IsProloguePattern := True;
End;

{ IsEpiloguePattern - Detecte un pattern d'epilogue de fonction.
  Patterns reconnus :
  1. POP BP/EBP ($5D) + RET ($C3)
  2. POP BP/EBP ($5D) + RET imm16 ($C2)
  3. LEAVE ($C9) + RET ($C3)
  4. LEAVE ($C9) + RET imm16 ($C2)
  5. RET seul ($C3) - fin de procedure sans frame pointer
  6. RET imm16 seul ($C2) - fin de procedure avec nettoyage de pile
  Retourne True si un pattern d'epilogue est detecte a Offset. }
Function IsEpiloguePattern(Offset : LongInt; Mode32 : Boolean) : Boolean;
Var
  B0, B1 : Byte;
Begin
  IsEpiloguePattern := False;
  If (Offset < 0) Or (Offset >= ImageSize) Then Exit;
  B0 := ReadImageByte(Offset);
  { Pattern 1 & 2 : POP BP/EBP ($5D) suivi de RET ($C3) ou RET imm ($C2) }
  If B0 = $5D Then Begin
    If Offset + 1 < ImageSize Then Begin
      B1 := ReadImageByte(Offset + 1);
      If (B1 = $C3) Or (B1 = $C2) Then Begin
        IsEpiloguePattern := True;
        Exit;
      End;
    End;
  End;
  { Pattern 3 & 4 : LEAVE ($C9) suivi de RET ($C3) ou RET imm ($C2) }
  If B0 = $C9 Then Begin
    If Offset + 1 < ImageSize Then Begin
      B1 := ReadImageByte(Offset + 1);
      If (B1 = $C3) Or (B1 = $C2) Then Begin
        IsEpiloguePattern := True;
        Exit;
      End;
    End;
  End;
  { Pattern 5 & 6 : RET ($C3) ou RET imm ($C2) seuls }
  If (B0 = $C3) Or (B0 = $C2) Then
    IsEpiloguePattern := True;
End;

{ FindProcEnd - Cherche la fin d'une procedure.
  Parcourt les instructions a partir de StartOffset et retourne
  l'adresse du premier octet apres la derniere instruction de retour
  (RET/RETF/IRET) trouvee. Retourne -1 si aucun retour n'est
  trouve dans la limite de MaxScan instructions. }
Function FindProcEnd(StartOffset, EndOffset : LongInt;
                     Mode32 : Boolean) : LongInt;
Const
  MaxScan = 10000;
Var
  CurOffset  : LongInt;
  ISize      : Integer;
  BType      : Integer;
  ScanCount  : Integer;
Begin
  FindProcEnd := -1;
  CurOffset := StartOffset;
  ScanCount := 0;
  While (CurOffset < EndOffset) And (CurOffset < ImageSize) And
        (ScanCount < MaxScan) Do Begin
    ISize := ComputeInstrSize(CurOffset, Mode32);
    If ISize <= 0 Then Exit;
    BType := ClassifyInstruction(CurOffset, Mode32);
    If (BType = BT_RET) Or (BType = BT_RETF) Or (BType = BT_IRET) Then Begin
      FindProcEnd := CurOffset + ISize;
      Exit;
    End;
    CurOffset := CurOffset + ISize;
    Inc(ScanCount);
  End;
End;

{ DetectProcedures - Seconde passe pour identifier les procedures.
  Actions :
  1. Pour chaque label marque IsProc (cible de CALL), verifier la
     presence d'un pattern de prologue et chercher l'epilogue.
  2. Scanner le code pour des prologues non encore detectes et
     les ajouter comme nouvelles procedures.
  3. Reutiliser les noms d'imports et d'exports comme noms de labels.
  4. Generer les noms automatiques manquants (sub_XXXX / loc_XXXX).
  Parametres :
    StartOffset : debut de la zone de code
    EndOffset   : fin de la zone de code
    Mode32      : True si mode 32 bits }
Procedure DetectProcedures(StartOffset, EndOffset : LongInt;
                           Mode32 : Boolean);
Var
  I          : LongInt;
  CurOffset  : LongInt;
  LIdx       : LongInt;
  NewProcs   : Integer;
  ProlProcs  : Integer;
  LabelName  : TString;
Begin
  NewProcs := 0;
  ProlProcs := 0;

  { Passe 1 : Verifier les prologues pour les labels deja marques IsProc }
  For I := 0 To LabelCount - 1 Do Begin
    If Labels[I].IsProc And (Not Labels[I].IsImport) Then Begin
      If IsProloguePattern(Labels[I].Address, Mode32) Then
        Inc(ProlProcs);
    End;
  End;

  { Passe 2 : Scanner l'image octet par octet pour les prologues non encore
    detectes. Un parcours depuis le seul point d'entree perd ses frontieres
    des qu'un compilateur melange code et constantes dans le meme segment;
    il ignorait alors toutes les procedures situees apres ces donnees. }
  { Les procedures peuvent preceder le point d'entree (cas habituel des
    programmes Turbo Pascal). Scanner toute l'image chargee. }
  CurOffset := 0;
  While CurOffset < EndOffset Do Begin
    If CurOffset >= ImageSize Then Break;
    If CurOffset < 0 Then Break;

    { Verifier s'il y a un prologue a cette adresse }
    If IsProloguePattern(CurOffset, Mode32) Then Begin
      LIdx := FindLabel(CurOffset);
      If LIdx < 0 Then Begin
        { Nouveau sous-programme detecte par pattern de prologue }
        LabelName := GenerateLabelName(CurOffset, True, Mode32);
        AddLabel(CurOffset, LabelName, True, False, False);
        Inc(NewProcs);
        Inc(ProcCount);
      End Else Begin
        { Label existant : s'assurer qu'il est marque comme proc }
        If Not Labels[LIdx].IsProc Then Begin
          Labels[LIdx].IsProc := True;
          { Renommer de loc_XXXX a sub_XXXX si le nom est auto-genere }
          If (Labels[LIdx].Name <> '') And
             (Copy(Labels[LIdx].Name, 1, 4) = 'loc_') Then Begin
            Labels[LIdx].Name := GenerateLabelName(CurOffset, True, Mode32);
          End;
          Inc(NewProcs);
          Inc(ProcCount);
        End;
      End;
    End;

    Inc(CurOffset);
  End;

  { Passe 3 : Assurer que les imports et exports ont leurs vrais noms.
    Les imports PE utilisent le nom de la fonction importee (DLL!func).
    Les exports PE utilisent le nom de la fonction exportee. }
  If IsPEFile Then Begin
    For I := 0 To ImportCount - 1 Do Begin
      If Imports[I].IATAddr > 0 Then Begin
        If Imports[I].FuncName <> '' Then
          AddLabel(Imports[I].IATAddr, Imports[I].FuncName,
                   True, True, False);
      End;
    End;
    For I := 0 To ExportCount - 1 Do Begin
      If ExportList[I].FuncRVA > 0 Then Begin
        If ExportList[I].HasName And (ExportList[I].FuncName <> '') Then
          AddLabel(ExportList[I].FuncRVA, ExportList[I].FuncName,
                   True, False, True);
      End;
    End;
  End;

  { Passe 4 : Generer les noms manquants pour tous les labels }
  For I := 0 To LabelCount - 1 Do Begin
    If Labels[I].Name = '' Then Begin
      Labels[I].Name := GenerateLabelName(Labels[I].Address,
                                          Labels[I].IsProc, Mode32);
    End;
  End;

  { Re-trier les labels si de nouveaux ont ete ajoutes }
  If NewProcs > 0 Then
    SortLabels;

  If OptVerbose Then Begin
    WriteLn('Detection des procedures terminee :');
    WriteLn('  Procedures avec prologue confirme  : ', ProlProcs);
    WriteLn('  Nouvelles procedures par prologue  : ', NewProcs);
    WriteLn('  Total sous-programmes              : ', ProcCount);
  End;
End;

{ ============================================================
  DISCRIMINATION CODE/DONNEES
  ============================================================ }

{ IsAsciiPrintable - Teste si un octet est un caractere ASCII imprimable
  ou un caractere de controle courant (tab, CR, LF). }
Function IsAsciiPrintable(B : Byte) : Boolean;
Begin
  IsAsciiPrintable := (B >= 32) And (B <= 126)
                   Or (B = 9) Or (B = 10) Or (B = 13);
End;

{ MarkCodeBytes - Premiere passe : marque tous les octets des instructions
  accessibles comme BF_CODE en suivant le flux de controle lineaire.
  Utilise les labels generes par AnalyzeControlFlow comme
  points de depart et trace chaque bloc d'instructions jusqu'a un
  saut inconditionnel ou un retour. }
Procedure MarkCodeBytes(StartOffset, EndOffset : LongInt;
                        Mode32 : Boolean);
Var
  I, J       : LongInt;
  CurOffset  : LongInt;
  ISize      : Integer;
  BType      : Integer;
  BadCount   : Integer;
  Visited    : Boolean;
  TraceProc  : Boolean;
Begin
  { Passe 1 : Tracer le code depuis chaque label connu }
  For I := 0 To LabelCount - 1 Do Begin
    CurOffset := Labels[I].Address;
    { Verifier que le label est dans les bornes }
    If (CurOffset < 0) Or (CurOffset >= EndOffset) Then Continue;
    If CurOffset >= ImageSize Then Continue;
    TraceProc := Labels[I].IsProc;
    { Les procedures sont retracees meme si leur prologue etait deja marque :
      le premier parcours a pu s'arreter sur un JMP interne. }
    If(ByteFlags^[CurOffset]=BF_CODE)and(Not TraceProc)Then Continue;

    BadCount := 0;
    While CurOffset < EndOffset Do Begin
      If CurOffset >= ImageSize Then Break;
      If CurOffset < 0 Then Break;
      { Si deja marque comme code, le bloc a deja ete trace }
      If(ByteFlags^[CurOffset]=BF_CODE)and(Not TraceProc)Then Break;

      { Calculer la taille de l'instruction }
      ISize := ComputeInstrSize(CurOffset, Mode32);
      If ISize <= 0 Then Begin
        ISize := 1;
        Inc(BadCount);
        If BadCount > 16 Then Break;
      End Else
        BadCount := 0;

      { Marquer tous les octets de cette instruction comme code }
      For J := 0 To ISize - 1 Do Begin
        If (CurOffset + J >= 0) And (CurOffset + J < ImageSize) Then
          ByteFlags^[CurOffset + J] := BF_CODE;
      End;

      { Classifier l'instruction pour detecter les fins de bloc }
      BType := ClassifyInstruction(CurOffset, Mode32);

      CurOffset := CurOffset + ISize;

      { Arreter le tracage apres un saut inconditionnel ou un retour }
      If ((Not TraceProc) And
         ((BType = BT_JMP_REL8) Or (BType = BT_JMP_REL) Or
          (BType = BT_JMP_FAR) Or (BType = BT_JMP_IND))) Or
         (BType = BT_RET) Or (BType = BT_RETF) Or
         (BType = BT_IRET) Then
        Break;
    End;
  End;

  { Passe 2 : Marquer le padding (NOP=$90, INT3=$CC, $00) entre les blocs de code }
  For I := 0 To ImageSize - 1 Do Begin
    If ByteFlags^[I] = BF_UNKNOWN Then Begin
      If (ReadImageByte(I) = $90) Or (ReadImageByte(I) = $CC) Or
         (ReadImageByte(I) = $00) Then Begin
        { Verifier qu'il est entre deux zones de code }
        Visited := False;
        If I > 0 Then Begin
          If (ByteFlags^[I - 1] = BF_CODE) Or (ByteFlags^[I - 1] = BF_PADDING) Then
            Visited := True;
        End;
        If Visited Then
          ByteFlags^[I] := BF_PADDING;
      End;
    End;
  End;
End;

{ MarkSectionFlags - Pour les fichiers PE, utilise les flags de section
  pour classifier les octets. Les sections sans flag CODE ni EXECUTE sont
  marquees comme BF_DATA. Les sections .rdata sont marquees comme BF_DATA. }
Procedure MarkSectionFlags;
Var
  I, J       : LongInt;
  SecStart   : LongInt;
  SecEnd     : LongInt;
  SecName    : TString;
  IsCode     : Boolean;
Begin
  If Not IsPEFile Then Exit;

  For I := 0 To SectionCount - 1 Do Begin
    SecStart := Sections[I].VirtualAddress;
    If Sections[I].VirtualSize > 0 Then
      SecEnd := SecStart + Sections[I].VirtualSize
    Else
      SecEnd := SecStart + Sections[I].SizeOfRawData;
    If SecEnd > ImageSize Then SecEnd := ImageSize;
    SecName := GetSectionName(Sections[I]);

    { Verifier si c'est une section de code }
    IsCode := ((Sections[I].Characteristics And IMAGE_SCN_CNT_CODE) <> 0) Or
              ((Sections[I].Characteristics And IMAGE_SCN_MEM_EXECUTE) <> 0);

    If Not IsCode Then Begin
      { Section de donnees : marquer tous les octets inconnus comme BF_DATA }
      For J := SecStart To SecEnd - 1 Do Begin
        If (J >= 0) And (J < ImageSize) Then Begin
          If ByteFlags^[J] = BF_UNKNOWN Then
            ByteFlags^[J] := BF_DATA;
        End;
      End;
    End;
  End;
End;

{ DetectAsciiStrings - Recherche les chaines ASCII (terminee par 0) dans
  les zones non classifiees ou marquees comme donnees.
  Une chaine est detectee si elle contient au moins 4 caracteres imprimables
  consecutifs suivis d'un octet nul. }
Procedure DetectAsciiStrings;
Var
  I, J       : LongInt;
  RunStart   : LongInt;
  RunLen     : LongInt;
  B          : Byte;
  InRun      : Boolean;
Begin
  StringCount := 0;
  InRun := False;
  RunStart := 0;
  RunLen := 0;

  For I := 0 To ImageSize - 1 Do Begin
    B := ReadImageByte(I);

    If (ByteFlags^[I] = BF_UNKNOWN) Or (ByteFlags^[I] = BF_DATA) Then Begin
      If IsAsciiPrintable(B) Then Begin
        If Not InRun Then Begin
          RunStart := I;
          RunLen := 0;
          InRun := True;
        End;
        Inc(RunLen);
      End Else If (B = 0) And InRun And (RunLen >= 4) Then Begin
        { Chaine terminee par nul : marquer comme BF_STRING }
        For J := RunStart To I Do Begin
          If (J >= 0) And (J < ImageSize) Then
            ByteFlags^[J] := BF_STRING;
        End;
        Inc(StringCount);
        { Creer un label pour la chaine si aucun n'existe }
        If FindLabel(RunStart) < 0 Then
          AddLabel(RunStart, 'aStr_' + HexDWord(RunStart), False, False, False);
        InRun := False;
        RunLen := 0;
      End Else Begin
        InRun := False;
        RunLen := 0;
      End;
    End Else Begin
      InRun := False;
      RunLen := 0;
    End;
  End;
End;

{ DetectPascalStrings - Recherche les chaines Pascal courtes dans les zones
  de donnees. Leur premier octet contient le nombre de caracteres (1..255),
  sans terminateur NUL. On accepte aussi les options courtes (par ex. /h),
  ce qui permet de conserver l'alignement d'une suite de chaines Pascal. }
Procedure DetectPascalStrings;
Var
  I, J       : LongInt;
  StrLen     : Integer;
  LetterCount: Integer;
  Valid      : Boolean;
  B          : Byte;
Begin
  I := 0;
  While I < ImageSize Do Begin
    If (ByteFlags^[I] = BF_UNKNOWN) Or (ByteFlags^[I] = BF_DATA) Then Begin
      StrLen := ReadImageByte(I);
      Valid := (StrLen >= 2) And (I + StrLen < ImageSize);
      LetterCount := 0;

      If Valid Then Begin
        For J := I + 1 To I + StrLen Do Begin
          B := ReadImageByte(J);
          If Not ((ByteFlags^[J] = BF_UNKNOWN) Or
                  (ByteFlags^[J] = BF_DATA)) Or
             Not IsAsciiPrintable(B) Then Begin
            Valid := False;
            Break;
          End;
          If ((B >= Ord('A')) And (B <= Ord('Z'))) Or
             ((B >= Ord('a')) And (B <= Ord('z'))) Then
            Inc(LetterCount);
        End;
        If ((StrLen < 4) And (LetterCount < 1) And
            Not ((StrLen = 2) And
                 ((ReadImageByte(I + 1) = Ord('/')) Or
                  (ReadImageByte(I + 1) = Ord('-'))))) Or
           ((StrLen >= 4) And (LetterCount < 3)) Then
          Valid := False;
      End;

      If Valid Then Begin
        For J := I To I + StrLen Do
          ByteFlags^[J] := BF_PSTRING;
        Inc(StringCount);
        If FindLabel(I) < 0 Then
          AddLabel(I, 'pStr_' + HexDWord(I), False, False, False);
        I := I + StrLen + 1;
      End Else
        Inc(I);
    End Else
      Inc(I);
  End;
End;

{ DetectStringReferences - Recherche dans les zones encore considerees comme
  donnees les MOV registre,immediat qui chargent exactement l'adresse d'une
  chaine deja detectee. Les compilateurs 16 bits melangent frequemment code
  et constantes dans le meme segment; cette passe recupere ces references
  meme lorsque le bloc englobant n'a pas ete atteint par le suivi de flux. }
Procedure DetectStringReferences(Mode32:Boolean);
Var
 I,J,Cur,RecoverStart,RecoverEnd:LongInt;
 InstrSize  :Integer;
 RecoverSize:Integer;
 BType      :Integer;
 Target     :LongInt;
 Value      :LongWord;
 ValidBytes :Boolean;
Begin
 StringRefCount:=0;
 I:=0;
 If Mode32 Then InstrSize:=5 Else InstrSize:=3;

 While I+InstrSize<=ImageSize do Begin
  If(ReadImageByte(I)>=$B8)and(ReadImageByte(I)<=$BF)Then Begin
   ValidBytes:=True;
   For J:=0 to InstrSize-1 do
    If(ByteFlags^[I+J]<>BF_UNKNOWN)and(ByteFlags^[I+J]<>BF_DATA)Then Begin
     ValidBytes:=False;
     Break;
    End;

   If ValidBytes Then Begin
    { Confirmer le motif de pointeur FAR utilise par Turbo Pascal :
      MOV reg,offset / PUSH segment / PUSH meme_reg. En mode 32 bits,
      accepter au minimum le PUSH immediat du meme registre. }
    If Mode32 Then Begin
     ValidBytes:=(I+InstrSize<ImageSize)and
      (ReadImageByte(I+InstrSize)=$50+(ReadImageByte(I)-$B8));
    End Else Begin
     ValidBytes:=(I+InstrSize+1<ImageSize)and
      (ReadImageByte(I+InstrSize) in [$06,$0E,$16,$1E])and
      (ReadImageByte(I+InstrSize+1)=$50+(ReadImageByte(I)-$B8));
    End;
   End;

   If ValidBytes Then Begin
    If Mode32 Then Value:=LongWord(ReadImageDWord(I+1))
              Else Value:=LongWord(ReadImageWord(I+1));
    Target:=LongInt(Value);
    If Mode32 And IsPEFile And
      (Value>=LongWord(PEOptHeader.ImageBase))and
      (Value-LongWord(PEOptHeader.ImageBase)<LongWord(ImageSize))Then
     Target:=LongInt(Value-LongWord(PEOptHeader.ImageBase));

    If(Target>=0)and(Target<ImageSize)and
      ((ByteFlags^[Target]=BF_STRING)or
       (ByteFlags^[Target]=BF_PSTRING))and(FindLabel(Target)>=0)Then Begin
     RecoverStart:=I;
     { Inclure la selection du fichier Output placee juste avant le
       chargement de chaine : MOV DI,088Ah / PUSH DS / PUSH DI. }
     If(Not Mode32)and(I>=5)and(ReadImageByte(I-5)=$BF)and
       (ReadImageWord(I-4)=$088A)and(ReadImageByte(I-2)=$1E)and
       (ReadImageByte(I-1)=$57)Then
      RecoverStart:=I-5;

     { Suivre lineairement l'ilot de code revele par cette reference.
       Arreter sur une vraie chaine, un saut inconditionnel ou un retour. }
     Cur:=RecoverStart;
     { Une procedure Turbo Pascal peut contenir plusieurs sorties et
       liberations consecutives; laisser le suivi continuer jusqu'a 4096
       octets, tout en conservant les arrets structurels ci-dessous. }
     RecoverEnd:=RecoverStart+4096;
     If RecoverEnd>ImageSize Then RecoverEnd:=ImageSize;
     While Cur<RecoverEnd do Begin
      If(ByteFlags^[Cur]=BF_STRING)or(ByteFlags^[Cur]=BF_PSTRING)Then Break;
      RecoverSize:=ComputeInstrSize(Cur,Mode32);
      If RecoverSize<=0 Then Break;
      ValidBytes:=True;
      For J:=0 to RecoverSize-1 do
       If(Cur+J>=ImageSize)or(ByteFlags^[Cur+J]=BF_STRING)or
         (ByteFlags^[Cur+J]=BF_PSTRING)Then Begin
        ValidBytes:=False;
        Break;
       End;
      If Not ValidBytes Then Break;
      For J:=0 to RecoverSize-1 do ByteFlags^[Cur+J]:=BF_CODE;
      BType:=ClassifyInstruction(Cur,Mode32);
      Cur:=Cur+RecoverSize;
      If(BType=BT_JMP_REL8)or(BType=BT_JMP_REL)or
        (BType=BT_JMP_FAR)or(BType=BT_JMP_IND)or
        (BType=BT_RET)or(BType=BT_RETF)or(BType=BT_IRET)Then Break;
     End;
     Inc(StringRefCount);
     I:=Cur;
     Continue;
    End;
   End;
  End;
  Inc(I);
 End;

 { Les references situees dans du code deja atteint par l'analyse de flux
   n'ont pas besoin d'etre recuperees, mais elles doivent tout de meme etre
   comptees. Parcourir les ilots BF_CODE instruction par instruction evite
   de confondre un octet B8..BF contenu dans un operande avec un opcode. }
 StringRefCount:=0;
 I:=0;
 While I<ImageSize do Begin
  If ByteFlags^[I]<>BF_CODE Then Begin Inc(I); Continue; End;
  InstrSize:=ComputeInstrSize(I,Mode32);
  If InstrSize<=0 Then Begin Inc(I); Continue; End;
  If(ReadImageByte(I)>=$B8)and(ReadImageByte(I)<=$BF)Then Begin
   ValidBytes:=False;
   If Mode32 Then Begin
    ValidBytes:=(InstrSize>=5)and(I+5<ImageSize)and
      (ReadImageByte(I+5)=$50+(ReadImageByte(I)-$B8));
    If ValidBytes Then Value:=LongWord(ReadImageDWord(I+1));
   End Else Begin
    ValidBytes:=(InstrSize>=3)and(I+4<ImageSize)and
      (ReadImageByte(I+3) in [$06,$0E,$16,$1E])and
      (ReadImageByte(I+4)=$50+(ReadImageByte(I)-$B8));
    If ValidBytes Then Value:=LongWord(ReadImageWord(I+1));
   End;
   If ValidBytes Then Begin
    Target:=LongInt(Value);
    If Mode32 And IsPEFile And
      (Value>=LongWord(PEOptHeader.ImageBase))and
      (Value-LongWord(PEOptHeader.ImageBase)<LongWord(ImageSize))Then
     Target:=LongInt(Value-LongWord(PEOptHeader.ImageBase));
    If(Target>=0)and(Target<ImageSize)and
      ((ByteFlags^[Target]=BF_STRING)or
       (ByteFlags^[Target]=BF_PSTRING))and(FindLabel(Target)>=0)Then
     Inc(StringRefCount);
   End;
  End;
  Inc(I,InstrSize);
 End;
End;

{ DetectJumpTables - Recherche les tables de saut (switch/case) dans les
  zones non classifiees. Une table de saut est une sequence d'adresses
  (16 ou 32 bits) qui pointent toutes vers des labels connus dans les
  sections de code. Elle est detectee apres un JMP indirect. }
Procedure DetectJumpTables(Mode32 : Boolean);
Var
  I, J, K    : LongInt;
  Addr       : LongInt;
  EntrySize  : Integer;
  EntryCount : Integer;
  AllValid   : Boolean;
Begin
  JumpTblCount := 0;

  If Mode32 Then
    EntrySize := 4
  Else
    EntrySize := 2;

  { Chercher les tables de saut apres les JMP indirects dans les XRefs }
  For I := 0 To XRefCount - 1 Do Begin
    { Verifier s'il y a un JMP indirect dont la cible pourrait etre
      suivie d'une table de saut }
  End;

  { Approche heuristique : chercher des sequences d'adresses alignees
    dans les zones inconnues qui pointent vers des labels connus }
  I := 0;
  While I < ImageSize - EntrySize Do Begin
    If (ByteFlags^[I] = BF_UNKNOWN) Or (ByteFlags^[I] = BF_DATA) Then Begin
      { Tester si c'est le debut d'une table de saut }
      EntryCount := 0;
      AllValid := True;
      K := I;
      While (K + EntrySize <= ImageSize) And AllValid Do Begin
        If Mode32 Then
          Addr := ReadImageDWord(K)
        Else
          Addr := ReadImageWord(K);
        { Verifier que l'adresse pointe vers un label connu. BOGUE REEL     }
        { CORRIGE (2026-09-07, demande explicite de l utilisateur) :        }
        { Addr=0 est REJETE explicitement - le point d entree du programme  }
        { est (InitCS=InitIP=0 pour la plupart des .EXE) presque toujours   }
        { l adresse 0 de l image, donc un label EXISTE bel et bien a cette  }
        { adresse (FindLabel(0)>=0 est vrai) - mais une longue plage de     }
        { donnees NON-INITIALISEES (BSS, remplissage) contient typiquement  }
        { des dizaines/centaines de mots nuls consecutifs, qui se faisaient }
        { donc TOUS confirmer a tort comme "pointeurs valides vers le       }
        { point d entree" par ce seul test d egalite d adresse - de vraies  }
        { zones de donnees entieres etaient reclassees BF_JUMPTBL et        }
        { rendues comme des dizaines d entrees "DD OFFSET sub_0000"         }
        { factices (confirme sur TURBO.EXE : 384 entrees sub_0000 sur les   }
        { 46 "tables de saut" detectees). Une vraie table de saut ne pointe }
        { pour ainsi dire jamais vers l adresse 0 elle-meme. }
        If (Addr <> 0) And (FindLabel(Addr) >= 0) Then Begin
          Inc(EntryCount);
          K := K + EntrySize;
        End Else
          AllValid := False;
      End;

      If EntryCount >= 3 Then Begin
        { Marquer comme table de saut }
        For J := I To I + (EntryCount * EntrySize) - 1 Do Begin
          If (J >= 0) And (J < ImageSize) Then
            ByteFlags^[J] := BF_JUMPTBL;
        End;
        Inc(JumpTblCount);
        { Creer un label pour la table }
        If FindLabel(I) < 0 Then
          AddLabel(I, 'jtbl_' + HexDWord(I), False, False, False);
        I := I + EntryCount * EntrySize;
      End Else
        Inc(I);
    End Else
      Inc(I);
  End;
End;

{ DetectDataPatterns - Marque les zones restantes inconnues comme donnees.
  Detecte les motifs courants : sequences de zeros (BSS), pointeurs
  alignes et constantes numeriques. }
Procedure DetectDataPatterns;
Var
  I          : LongInt;
Begin
  { Marquer tous les octets encore inconnus comme donnees }
  DataBytes := 0;
  For I := 0 To ImageSize - 1 Do Begin
    If ByteFlags^[I] = BF_UNKNOWN Then Begin
      ByteFlags^[I] := BF_DATA;
    End;
    { Compter les octets de donnees }
    If (ByteFlags^[I] = BF_DATA) Or (ByteFlags^[I] = BF_STRING) Or
       (ByteFlags^[I] = BF_PSTRING) Or
       (ByteFlags^[I] = BF_JUMPTBL) Then
      Inc(DataBytes);
  End;
End;

{ DiscriminateCodeData - Procedure principale pour la discrimination
  code/donnees. Orchestre les differentes passes. }
Procedure DiscriminateCodeData(StartOffset, EndOffset : LongInt;
                               Mode32 : Boolean);
Var
  CodeBytes   : LongInt;
  PadBytes    : LongInt;
  I           : LongInt;
Begin
  { Allouer et initialiser ByteFlags }
  If ImageSize <= 0 Then Exit;
  GetMem(ByteFlags, ImageSize);
  FillChar(ByteFlags^, ImageSize, BF_UNKNOWN);

  WriteLn('Discrimination code/donnees...');

  { Passe 1 : Marquer les octets de code via le flux de controle }
  MarkCodeBytes(StartOffset, EndOffset, Mode32);

  { Passe 2 : Pour PE, utiliser les flags de section }
  MarkSectionFlags;

  { Passe 3 : Detecter les chaines ASCII }
  DetectAsciiStrings;

  { Passe 4 : Detecter les chaines Pascal (longueur + caracteres) }
  DetectPascalStrings;

  { Passe 5 : Retrouver les chargements d'adresse de chaines dans les blocs
    que le suivi de flux n'avait pas classes comme code }
  DetectStringReferences(Mode32);

  { Passe 6 : Detecter les tables de saut }
  DetectJumpTables(Mode32);

  { Passe 7 : Marquer les zones restantes comme donnees }
  DetectDataPatterns;

  { Calculer les statistiques }
  CodeBytes := 0;
  PadBytes := 0;
  For I := 0 To ImageSize - 1 Do Begin
    Case ByteFlags^[I] Of
      BF_CODE    : Inc(CodeBytes);
      BF_PADDING : Inc(PadBytes);
    End;
  End;

  WriteLn('Discrimination terminee :');
  WriteLn('  Octets de code      : ', CodeBytes);
  WriteLn('  Octets de donnees   : ', DataBytes);
  WriteLn('  Chaines ASCII       : ', StringCount);
  WriteLn('  References chaines  : ', StringRefCount);
  WriteLn('  Tables de saut      : ', JumpTblCount);
  WriteLn('  Octets de padding   : ', PadBytes);
End;

{ ============================================================
  GENERATION DU FICHIER .ASM : EN-TETE, DIRECTIVES, SEGMENTS
  ============================================================ }

{ Ecrit l'en-tete du fichier .ASM avec des commentaires :
  nom du fichier source, date, outil. }
Procedure WriteASMHeader(Var F : Text);
Begin
  WriteLn(F, '; ============================================================');
  WriteLn(F, '; Fichier genere par DISOVL v', DISOVL_VERSION, ' (', DISOVL_DATE, ')');
  WriteLn(F, '; Source  : ', InputFileName);
  WriteLn(F, '; Format  : overlay DOS (en-tete MZ), charge via INT 21h');
  WriteLn(F, ';           AH=4Bh AL=03h "Load Overlay" - voir Ralf Brown');
  WriteLn(F, ';           Interrupt List. Numero d''overlay (en-tete) : ',
          MZHeader.OverlayNum);
  WriteLn(F, '; IMPORTANT : un VRAI chargeur d''overlay ignore le CS:IP/SS:SP');
  WriteLn(F, ';           de l''en-tete MZ (pas de PSP/tache propre a l''overlay) et');
  WriteLn(F, ';           fournit LUI-MEME, au moment du chargement (bloc ES:BX,');
  WriteLn(F, ';           DIFFERENT du bloc EXEC normal), le segment de chargement');
  WriteLn(F, ';           et le facteur de relogement - ils ne sont PAS dans ce');
  WriteLn(F, ';           fichier. Valeurs utilisees pour CE desassemblage :');
  WriteLn(F, ';           segment de chargement = ', HexWord(OvlLoadSegment), 'h');
  WriteLn(F, ';           facteur de relogement  = ', HexWord(BaseSegment), 'h');
  WriteLn(F, ';           (voir -loadseg:/-reloc: - des valeurs differentes');
  WriteLn(F, ';           donneraient des adresses absolues differentes).');
  WriteLn(F, '; ============================================================');
  WriteLn(F);
End;

{ ============================================================
  GENERATION DU FICHIER .ASM : SECTION DE CODE
  ============================================================ }

Function FormatImmediateOperand(Value : LongWord;
                                Mode32 : Boolean) : TString; Forward;

{ DisassembleInstruction - Decode une instruction a l'adresse donnee.
  Parametres :
    Offset : position dans ImageBuffer
    Mode32 : True si mode 32 bits
  Resultats :
    Mnem     : mnemonique de l'instruction
    Operands : chaine des operandes
    BytesUsed : nombre total d'octets consommes
}
Procedure DisassembleInstruction(Offset : LongInt; Mode32 : Boolean;
                                  Var Mnem : TString; Var Operands : TString;
                                  Var BytesUsed : Integer);
Var
  PFX       : TPrefixState;
  OpcOffset : LongInt;
  Opcode    : Byte;
  Entry     : TOpcodeEntry;
  OpSz      : Byte;
  AddrSz    : Byte;
  RegField  : Byte;
  ModRM     : Byte;
  MRMBytes  : Integer;
  RMStr     : TString;
  RegStr    : TString;
  Imm8      : Byte;
  Imm16     : Word;
  Imm32     : LongInt;
  Rel8      : ShortInt;
  Rel16     : SmallInt;
  Rel32     : LongInt;
  TargetAddr: LongInt;
  PrefStr   : TString;
  LblIdx    : LongInt;
  TotalSize : Integer;
  SecByte   : Byte;
  Mnem0F    : TString;
  Ops0F     : TString;
  Bytes0F   : Integer;
Begin
  Mnem := '';
  Operands := '';
  BytesUsed := 1;

  If (Offset < 0) Or (Offset >= ImageSize) Then Begin
    Mnem := 'DB';
    Operands := '??';
    Exit;
  End;

  { Decoder les prefixes }
  InitPrefixState(PFX, Mode32);
  DecodePrefixes(Offset, Mode32, PFX);
  OpcOffset := Offset + PFX.PrefixCount;
  OpSz  := PFX.EffOpSize;
  AddrSz := PFX.EffAddrSize;
  TotalSize := PFX.PrefixCount;

  If OpcOffset >= ImageSize Then Begin
    Mnem := 'DB';
    Operands := HexByte(ReadImageByte(Offset)) + 'h';
    BytesUsed := 1;
    Exit;
  End;

  Opcode := ReadImageByte(OpcOffset);
  PrefStr := PrefixToStr(PFX);

  { Opcode etendu 0Fh }
  If Opcode = $0F Then Begin
    If OpcOffset + 1 < ImageSize Then Begin
      SecByte := ReadImageByte(OpcOffset + 1);
      Decode0FOpcode(SecByte, OpcOffset + 2, PFX, Mnem0F, Ops0F, Bytes0F);
      Mnem := PrefStr + Mnem0F;
      Operands := InjectSegOvr(PFX.SegOverrideStr, Ops0F);
      BytesUsed := TotalSize + 1 + Bytes0F; { prefixes + 0F byte + (second+rest) }
    End Else Begin
      Mnem := 'DB';
      Operands := '0Fh';
      BytesUsed := TotalSize + 1;
    End;
    Exit;
  End;

  Entry := OpcodeTable[Opcode];

  { Instruction inconnue }
  If Entry.Mnemonic = '???' Then Begin
    Mnem := 'DB';
    Operands := HexByte(Opcode) + 'h';
    BytesUsed := TotalSize + 1;
    Exit;
  End;

  { Instructions de groupe }
  If (Entry.Mnemonic = 'GRP1') Or (Entry.Mnemonic = 'GRP2') Or
     (Entry.Mnemonic = 'GRP3') Or (Entry.Mnemonic = 'GRP4') Or
     (Entry.Mnemonic = 'GRP5') Then Begin
    If OpcOffset + 1 >= ImageSize Then Begin
      Mnem := 'DB';
      Operands := HexByte(Opcode) + 'h';
      BytesUsed := TotalSize + 1;
      Exit;
    End;
    ModRM := ReadImageByte(OpcOffset + 1);
    RegField := (ModRM Shr 3) And $07;
    Case Entry.Mnemonic[4] Of
      '1' : Mnem := Grp1Mnemonics[RegField];
      '2' : Mnem := Grp2Mnemonics[RegField];
      '3' : Mnem := Grp3Mnemonics[RegField];
      '4' : Mnem := Grp4Mnemonics[RegField];
      '5' : Mnem := Grp5Mnemonics[RegField];
    Else
      Mnem := '???';
    End;
    Mnem := PrefStr + Mnem;
    { Decoder l'operande r/m }
    If AddrSz = 4 Then
      DecodeModRM32(OpcOffset + 1, OpSz, RegField, RMStr, MRMBytes)
    Else
      DecodeModRM16(OpcOffset + 1, OpSz, RegField, RMStr, MRMBytes);
    Operands := RMStr;
    BytesUsed := TotalSize + 1 + MRMBytes;
    { Ajouter l'immediat pour certains groupes }
    Case Opcode Of
      $80 : Begin { GRP1 r/m8, imm8 }
        Imm8 := ReadImageByte(OpcOffset + 1 + MRMBytes);
        Operands := Operands + ', ' + HexByte(Imm8) + 'h';
        Inc(BytesUsed);
      End;
      $81 : Begin { GRP1 r/m, imm16/32 }
        If OpSz = 4 Then Begin
          Imm32 := ReadImageDWord(OpcOffset + 1 + MRMBytes);
          Operands := Operands + ', ' + HexDWord(Imm32) + 'h';
          BytesUsed := BytesUsed + 4;
        End Else Begin
          Imm16 := ReadImageWord(OpcOffset + 1 + MRMBytes);
          Operands := Operands + ', ' + HexWord(Imm16) + 'h';
          BytesUsed := BytesUsed + 2;
        End;
      End;
      $82 : Begin { GRP1 r/m8, imm8 (alias) }
        Imm8 := ReadImageByte(OpcOffset + 1 + MRMBytes);
        Operands := Operands + ', ' + HexByte(Imm8) + 'h';
        Inc(BytesUsed);
      End;
      $83 : Begin { GRP1 r/m, imm8 sign-extended }
        Imm8 := ReadImageByte(OpcOffset + 1 + MRMBytes);
        Operands := Operands + ', ' + HexByte(Imm8) + 'h';
        Inc(BytesUsed);
      End;
      $C0 : Begin { GRP2 r/m8, imm8 }
        Imm8 := ReadImageByte(OpcOffset + 1 + MRMBytes);
        Operands := Operands + ', ' + HexByte(Imm8) + 'h';
        Inc(BytesUsed);
      End;
      $C1 : Begin { GRP2 r/m, imm8 }
        Imm8 := ReadImageByte(OpcOffset + 1 + MRMBytes);
        Operands := Operands + ', ' + HexByte(Imm8) + 'h';
        Inc(BytesUsed);
      End;
      $D0, $D1 : Begin { GRP2 r/m, 1 }
        Operands := Operands + ', 1';
      End;
      $D2, $D3 : Begin { GRP2 r/m, CL }
        Operands := Operands + ', CL';
      End;
      $F6 : Begin { GRP3 r/m8 }
        If RegField = 0 Then Begin { TEST r/m8, imm8 }
          Imm8 := ReadImageByte(OpcOffset + 1 + MRMBytes);
          Operands := Operands + ', ' + HexByte(Imm8) + 'h';
          Inc(BytesUsed);
        End;
      End;
      $F7 : Begin { GRP3 r/m }
        If RegField = 0 Then Begin { TEST r/m, imm }
          If OpSz = 4 Then Begin
            Imm32 := ReadImageDWord(OpcOffset + 1 + MRMBytes);
            Operands := Operands + ', ' + HexDWord(Imm32) + 'h';
            BytesUsed := BytesUsed + 4;
          End Else Begin
            Imm16 := ReadImageWord(OpcOffset + 1 + MRMBytes);
            Operands := Operands + ', ' + HexWord(Imm16) + 'h';
            BytesUsed := BytesUsed + 2;
          End;
        End;
      End;
    End; { case }
    Operands := InjectSegOvr(PFX.SegOverrideStr, Operands);
    Exit;
  End;

  { Instruction normale - commencer par le mnemonique }
  Mnem := PrefStr + Entry.Mnemonic;
  BytesUsed := TotalSize + Entry.BaseSize;

  { Instructions sans operande }
  If Entry.OpCount = 0 Then Begin
    Operands := '';
    Exit;
  End;

  { Instructions avec ModR/M et deux operandes }
  If Entry.NeedModRM Then Begin
    If Entry.OpCount = 2 Then Begin
      If AddrSz = 4 Then
        DecodeModRM32Full(OpcOffset + 1, OpSz, (Opcode And $02) <> 0,
                          RMStr, RegStr, MRMBytes)
      Else
        DecodeModRM16Full(OpcOffset + 1, OpSz, (Opcode And $02) <> 0,
                          RMStr, RegStr, MRMBytes);
      BytesUsed := TotalSize + 1 + MRMBytes;
      { Selon direction bit : reg,r/m ou r/m,reg }
      If (Opcode And $02) <> 0 Then
        Operands := RMStr + ', ' + RegStr
      Else
        Operands := RMStr + ', ' + RegStr;
      { Ajouter immediat si Op2 est un immediat }
      If Entry.Op2Type = OT_IMM8 Then Begin
        Imm8 := ReadImageByte(OpcOffset + 1 + MRMBytes);
        Operands := RMStr + ', ' + HexByte(Imm8) + 'h';
        Inc(BytesUsed);
      End Else If Entry.Op2Type = OT_IMM8X Then Begin
        Imm8 := ReadImageByte(OpcOffset + 1 + MRMBytes);
        Operands := RMStr + ', ' + HexByte(Imm8) + 'h';
        Inc(BytesUsed);
      End Else If Entry.Op2Type = OT_IMM16 Then Begin
        If OpSz = 4 Then Begin
          Imm32 := ReadImageDWord(OpcOffset + 1 + MRMBytes);
          Operands := RMStr + ', ' + HexDWord(Imm32) + 'h';
          BytesUsed := BytesUsed + 4;
        End Else Begin
          Imm16 := ReadImageWord(OpcOffset + 1 + MRMBytes);
          Operands := RMStr + ', ' + HexWord(Imm16) + 'h';
          BytesUsed := BytesUsed + 2;
        End;
      End;
    End Else Begin
      { 1 operande avec ModR/M }
      RegField := 0;
      If AddrSz = 4 Then
        DecodeModRM32(OpcOffset + 1, OpSz, RegField, RMStr, MRMBytes)
      Else
        DecodeModRM16(OpcOffset + 1, OpSz, RegField, RMStr, MRMBytes);
      Operands := RMStr;
      BytesUsed := TotalSize + 1 + MRMBytes;
    End;
    Operands := InjectSegOvr(PFX.SegOverrideStr, Operands);
    Exit;
  End;

  { Instructions sans ModR/M - operandes implicites ou immediats }
  Case Entry.OpCount Of
    1 : Begin
      Case Entry.Op1Type Of
        OT_AL    : Operands := 'AL';
        OT_AX    : If OpSz = 4 Then Operands := 'EAX' Else Operands := 'AX';
        OT_CL    : Operands := 'CL';
        OT_DX    : Operands := 'DX';
        OT_ONE   : Operands := '1';
        OT_CS    : Operands := 'CS';
        OT_DS    : Operands := 'DS';
        OT_ES    : Operands := 'ES';
        OT_SS    : Operands := 'SS';
        OT_FS    : Operands := 'FS';
        OT_GS    : Operands := 'GS';
        OT_REG8  : Begin
          RegField := Opcode And $07;
          Operands := RegNames8[RegField];
        End;
        OT_REG16 : Begin
          RegField := Opcode And $07;
          If OpSz = 4 Then
            Operands := RegNames32[RegField]
          Else
            Operands := RegNames16[RegField];
        End;
        OT_SEGREG : Begin
          RegField := (Opcode Shr 3) And $03;
          Operands := SegRegNames[RegField];
        End;
        OT_IMM8  : Begin
          Imm8 := ReadImageByte(OpcOffset + 1);
          Operands := HexByte(Imm8) + 'h';
        End;
        OT_IMM16 : Begin
          If OpSz = 4 Then Begin
            Imm32 := ReadImageDWord(OpcOffset + 1);
            Operands := FormatImmediateOperand(LongWord(Imm32), True);
            BytesUsed := BytesUsed + 2; { 16->32 bits }
          End Else Begin
            Imm16 := ReadImageWord(OpcOffset + 1);
            Operands := FormatImmediateOperand(LongWord(Imm16), False);
          End;
        End;
        OT_REL8  : Begin
          Rel8 := ShortInt(ReadImageByte(OpcOffset + 1));
          TargetAddr := OpcOffset + 2 + LongInt(Rel8);
          LblIdx := FindLabel(TargetAddr);
          If LblIdx >= 0 Then
            Operands := Labels[LblIdx].Name
          Else If Mode32 Then
            Operands := HexDWord(TargetAddr) + 'h'
          Else
            Operands := HexWord(Word(TargetAddr)) + 'h';
        End;
        OT_REL16 : Begin
          If OpSz = 4 Then Begin
            Rel32 := ReadImageDWord(OpcOffset + 1);
            TargetAddr := OpcOffset + 5 + Rel32;
            BytesUsed := BytesUsed + 2; { 16->32 bits }
          End Else Begin
            Rel16 := SmallInt(ReadImageWord(OpcOffset + 1));
            TargetAddr := OpcOffset + 3 + LongInt(Rel16);
          End;
          LblIdx := FindLabel(TargetAddr);
          If LblIdx >= 0 Then
            Operands := Labels[LblIdx].Name
          Else If Mode32 Then
            Operands := HexDWord(TargetAddr) + 'h'
          Else
            Operands := HexWord(Word(TargetAddr)) + 'h';
        End;
        OT_FAR   : Begin
          If OpSz = 4 Then Begin
            Imm32 := ReadImageDWord(OpcOffset + 1);
            Imm16 := ReadImageWord(OpcOffset + 5);
            Operands := HexWord(Imm16) + ':' + HexDWord(Imm32) + 'h';
            BytesUsed := BytesUsed + 2; { 32 bit offset }
          End Else Begin
            Imm16 := ReadImageWord(OpcOffset + 1);
            Operands := HexWord(ReadImageWord(OpcOffset + 3)) + ':' + HexWord(Imm16) + 'h';
          End;
        End;
        OT_MEM16 : Begin
          If AddrSz = 4 Then Begin
            Imm32 := ReadImageDWord(OpcOffset + 1);
            Operands := '[' + HexDWord(Imm32) + 'h]';
            BytesUsed := BytesUsed + 2; { 16->32 adresse }
          End Else Begin
            Imm16 := ReadImageWord(OpcOffset + 1);
            Operands := '[' + HexWord(Imm16) + 'h]';
          End;
        End;
      Else
        Operands := '?';
      End;
    End;
    2 : Begin
      { Deux operandes sans ModR/M (operandes implicites) }
      { Premiere operande }
      Case Entry.Op1Type Of
        OT_AL    : Operands := 'AL, ';
        OT_AX    : If OpSz = 4 Then Operands := 'EAX, ' Else Operands := 'AX, ';
        OT_CL    : Operands := 'CL, ';
        OT_DX    : Operands := 'DX, ';
        OT_CS    : Operands := 'CS, ';
        OT_DS    : Operands := 'DS, ';
        OT_ES    : Operands := 'ES, ';
        OT_SS    : Operands := 'SS, ';
        OT_FS    : Operands := 'FS, ';
        OT_GS    : Operands := 'GS, ';
        OT_REG8  : Begin
          RegField := Opcode And $07;
          Operands := RegNames8[RegField] + ', ';
        End;
        OT_REG16 : Begin
          RegField := Opcode And $07;
          If OpSz = 4 Then
            Operands := RegNames32[RegField] + ', '
          Else
            Operands := RegNames16[RegField] + ', ';
        End;
        OT_REG32 : Begin
          RegField := Opcode And $07;
          Operands := RegNames32[RegField] + ', ';
        End;
        OT_SEGREG : Begin
          RegField := (Opcode Shr 3) And $03;
          Operands := SegRegNames[RegField] + ', ';
        End;
        OT_MEM16 : Begin
          If AddrSz = 4 Then Begin
            Imm32 := ReadImageDWord(OpcOffset + 1);
            Operands := '[' + HexDWord(Imm32) + 'h], ';
            BytesUsed := BytesUsed + 2;
          End Else Begin
            Imm16 := ReadImageWord(OpcOffset + 1);
            Operands := '[' + HexWord(Imm16) + 'h], ';
          End;
        End;
      Else
        Operands := '?, ';
      End;
      { Deuxieme operande }
      Case Entry.Op2Type Of
        OT_AL    : Operands := Operands + 'AL';
        OT_AX    : If OpSz = 4 Then Operands := Operands + 'EAX' Else Operands := Operands + 'AX';
        OT_DX    : Operands := Operands + 'DX';
        OT_CL    : Operands := Operands + 'CL';
        OT_ONE   : Operands := Operands + '1';
        OT_CS    : Operands := Operands + 'CS';
        OT_DS    : Operands := Operands + 'DS';
        OT_ES    : Operands := Operands + 'ES';
        OT_SS    : Operands := Operands + 'SS';
        OT_FS    : Operands := Operands + 'FS';
        OT_GS    : Operands := Operands + 'GS';
        OT_REG8  : Begin
          RegField := Opcode And $07;
          Operands := Operands + RegNames8[RegField];
        End;
        OT_REG16 : Begin
          RegField := Opcode And $07;
          If OpSz = 4 Then
            Operands := Operands + RegNames32[RegField]
          Else
            Operands := Operands + RegNames16[RegField];
        End;
        OT_REG32 : Begin
          RegField := Opcode And $07;
          Operands := Operands + RegNames32[RegField];
        End;
        OT_SEGREG : Begin
          RegField := (Opcode Shr 3) And $03;
          Operands := Operands + SegRegNames[RegField];
        End;
        OT_IMM8  : Begin
          Imm8 := ReadImageByte(OpcOffset + Entry.BaseSize - 1);
          Operands := Operands + HexByte(Imm8) + 'h';
        End;
        OT_IMM16 : Begin
          If OpSz = 4 Then Begin
            Imm32 := ReadImageDWord(OpcOffset + Entry.BaseSize - 4);
            Operands := Operands +
                        FormatImmediateOperand(LongWord(Imm32), True);
            BytesUsed := BytesUsed + 2;
          End Else Begin
            Imm16 := ReadImageWord(OpcOffset + Entry.BaseSize - 2);
            Operands := Operands +
                        FormatImmediateOperand(LongWord(Imm16), False);
          End;
        End;
        OT_MEM16 : Begin
          If AddrSz = 4 Then Begin
            Imm32 := ReadImageDWord(OpcOffset + 1);
            Operands := Operands + '[' + HexDWord(Imm32) + 'h]';
            BytesUsed := BytesUsed + 2;
          End Else Begin
            Imm16 := ReadImageWord(OpcOffset + 1);
            Operands := Operands + '[' + HexWord(Imm16) + 'h]';
          End;
        End;
      Else
        Operands := Operands + '?';
      End;
    End;
  End;
  Operands := InjectSegOvr(PFX.SegOverrideStr, Operands);
End;

{ FormatHexBytes - Formate les octets hexadecimaux d'une instruction
  pour un commentaire ASM. }
Function FormatHexBytes(Offset : LongInt; Count : Integer) : TString;
Var
  S : TString;
  I : Integer;
Begin
  S := '';
  For I := 0 To Count - 1 Do Begin
    If I > 0 Then S := S + ' ';
    If Offset + I < ImageSize Then
      S := S + HexByte(ReadImageByte(Offset + I))
    Else
      S := S + '??';
    { Limiter la longueur pour eviter debordement }
    If Length(S) > 40 Then Begin
      S := S + '...';
      Break;
    End;
  End;
  FormatHexBytes := S;
End;

{ ============================================================
  COMMENTAIRES ET ANNOTATIONS DANS LE FICHIER .ASM
  ============================================================ }

{ GetINTDescription - Retourne un commentaire descriptif pour un numero
  d'interruption connu. Les principales interruptions DOS et BIOS sont
  documentees. Retourne une chaine vide si l'interruption est inconnue. }
Function GetINTDescription(IntNum : Byte) : TString;
Begin
  Case IntNum Of
    $10 : GetINTDescription := 'BIOS video service';
    $11 : GetINTDescription := 'BIOS equipment list';
    $12 : GetINTDescription := 'BIOS memory size';
    $13 : GetINTDescription := 'BIOS disk service';
    $14 : GetINTDescription := 'BIOS serial port service';
    $15 : GetINTDescription := 'BIOS miscellaneous service';
    $16 : GetINTDescription := 'BIOS keyboard service';
    $17 : GetINTDescription := 'BIOS printer service';
    $19 : GetINTDescription := 'BIOS bootstrap loader';
    $1A : GetINTDescription := 'BIOS time service';
    $20 : GetINTDescription := 'DOS terminate program';
    $21 : GetINTDescription := 'DOS function call';
    $22 : GetINTDescription := 'DOS terminate address';
    $23 : GetINTDescription := 'DOS Ctrl-C handler';
    $24 : GetINTDescription := 'DOS critical error handler';
    $25 : GetINTDescription := 'DOS absolute disk read';
    $26 : GetINTDescription := 'DOS absolute disk write';
    $27 : GetINTDescription := 'DOS terminate and stay resident';
    $2F : GetINTDescription := 'DOS multiplex interrupt';
    $33 : GetINTDescription := 'Mouse driver';
    $67 : GetINTDescription := 'EMS (Expanded Memory)';
  Else
    GetINTDescription := '';
  End;
End;


{ ============================================================
  ANNOTATIONS "MAXIMUM D'INFORMATION" : sous-fonctions AH/AX connues des
  interruptions DOS/BIOS/DPMI les plus consultees en retro-ingenierie d'un
  extenseur ou d'un pilote charge en overlay (voir le commentaire de tete
  du programme - enquete TPX.EXE/DPMI16BI.OVL), et ports d'E/S materiels
  courants pour IN/OUT. KnownAH/KnownAX/KnownDX sont deduits par SUIVI
  INCREMENTAL FORWARD (pas de remontee en arriere, risquee sur un ISA a
  longueur variable) du plus recent MOV AH,imm8/MOV AX,imm16/MOV DX,imm16
  rencontre AVANT l'instruction courante - voir WriteASMCodeRange, qui
  maintient cet etat et le reinitialise a "inconnu" a chaque label (un
  point de jonction de flux de controle rend la valeur precedente non
  fiable).
  ============================================================ }

{ GetINT21AHDescription - Sous-fonctions DOS (INT 21h) les plus courantes. }
Function GetINT21AHDescription(AH : Byte) : TString;
Begin
  Case AH Of
    $00 : GetINT21AHDescription := 'Terminate program (ancien, voir INT 20h)';
    $09 : GetINT21AHDescription := 'Print string ($-terminated), DS:DX';
    $0A : GetINT21AHDescription := 'Buffered keyboard input, DS:DX';
    $0F : GetINT21AHDescription := 'Open file (FCB)';
    $19 : GetINT21AHDescription := 'Get default drive';
    $1A : GetINT21AHDescription := 'Set DTA address, DS:DX';
    $25 : GetINT21AHDescription := 'Set interrupt vector, AL=num, DS:DX';
    $2A : GetINT21AHDescription := 'Get system date';
    $2C : GetINT21AHDescription := 'Get system time';
    $2F : GetINT21AHDescription := 'Get DTA address -> ES:BX';
    $30 : GetINT21AHDescription := 'Get DOS version -> AL=major,AH=minor';
    $31 : GetINT21AHDescription := 'Terminate and stay resident (TSR)';
    $35 : GetINT21AHDescription := 'Get interrupt vector, AL=num -> ES:BX';
    $3C : GetINT21AHDescription := 'Create file, DS:DX';
    $3D : GetINT21AHDescription := 'Open file, DS:DX';
    $3E : GetINT21AHDescription := 'Close file, BX=handle';
    $3F : GetINT21AHDescription := 'Read file/device, BX=handle';
    $40 : GetINT21AHDescription := 'Write file/device, BX=handle';
    $41 : GetINT21AHDescription := 'Delete file, DS:DX';
    $42 : GetINT21AHDescription := 'Seek (LSEEK), BX=handle';
    $43 : GetINT21AHDescription := 'Get/set file attributes (AL=0/1)';
    $44 : GetINT21AHDescription := 'IOCTL, BX=handle';
    $47 : GetINT21AHDescription := 'Get current directory';
    $48 : GetINT21AHDescription := 'Allocate memory, BX=paragraphs (BX=FFFFh: interroger le plus gros bloc libre)';
    $49 : GetINT21AHDescription := 'Free memory, ES=segment';
    $4A : GetINT21AHDescription := 'Resize memory block, ES=segment, BX=nouvelle taille';
    $4B : GetINT21AHDescription := 'EXEC (AL=0 normal, AL=1 load-no-exec, AL=3 load overlay)';
    $4C : GetINT21AHDescription := 'Terminate with return code, AL=code';
    $4D : GetINT21AHDescription := 'Get return code of child process';
    $4E : GetINT21AHDescription := 'Find first file, DS:DX';
    $4F : GetINT21AHDescription := 'Find next file';
    $54 : GetINT21AHDescription := 'Get verify flag';
    $57 : GetINT21AHDescription := 'Get/set file date/time (AL=0/1)';
    $58 : GetINT21AHDescription := 'Get/set memory allocation strategy (AL=0/1), BX=strategie';
    $59 : GetINT21AHDescription := 'Get extended error information';
    $5A : GetINT21AHDescription := 'Create temporary file';
    $5B : GetINT21AHDescription := 'Create new file';
    $62 : GetINT21AHDescription := 'Get PSP address -> BX';
    $65 : GetINT21AHDescription := 'Get extended country information';
    $66 : GetINT21AHDescription := 'Get/set global code page';
    $68 : GetINT21AHDescription := 'Commit file (flush)';
  Else
    GetINT21AHDescription := '';
  End;
End;

{ GetINT2FAXDescription - Sous-fonctions du multiplex DOS (INT 2Fh), cle
  pour la detection de pilotes/extenseurs (XMS, DPMI, Windows, reseau...). }
Function GetINT2FAXDescription(AX : Word) : TString;
Begin
  Case AX Of
    $1600 : GetINT2FAXDescription := 'Windows enhanced mode - installation check';
    $1605 : GetINT2FAXDescription := 'Windows enhanced mode - init notification';
    $1606 : GetINT2FAXDescription := 'Windows enhanced mode - exit notification';
    $1680 : GetINT2FAXDescription := 'Release current virtual machine time-slice (idle)';
    $1687 : GetINT2FAXDescription := 'DPMI installation check (voir ES:DI = entree du commutateur)';
    $1689 : GetINT2FAXDescription := 'DPMI - get DPMI entry point apres bascule reel->protege';
    $4300 : GetINT2FAXDescription := 'XMS installation check';
    $4310 : GetINT2FAXDescription := 'XMS - get driver entry point -> ES:BX';
    $4A01 : GetINT2FAXDescription := 'EMS - get EMM import/function entry';
  Else
    GetINT2FAXDescription := '';
  End;
End;

{ GetINT15AHDescription - Sous-fonctions BIOS diverses (INT 15h), le point
  d'entree "memoire etendue/mode protege" classique AVANT XMS/DPMI - voir
  l'enquete "DPMI error (400A): insufficient extended memory" ou AUCUN de
  ces appels n'etait en cause (confirme par tracage), mais qui reste le
  premier suspect naturel pour tout extenseur similaire. }
Function GetINT15AHDescription(AH : Byte) : TString;
Begin
  Case AH Of
    $87 : GetINT15AHDescription := 'Move block to/from extended memory, CX=mots, ES:SI=table GDT';
    $88 : GetINT15AHDescription := 'Get extended memory size (Ko au-dela de 1 Mo) -> AX';
    $89 : GetINT15AHDescription := 'Switch to protected mode (ancien, pre-DPMI)';
    $90 : GetINT15AHDescription := 'Device busy loop (multitache cooperatif)';
    $91 : GetINT15AHDescription := 'Interrupt complete (multitache cooperatif)';
    $C0 : GetINT15AHDescription := 'Get system configuration parameters -> ES:BX';
    $C2 : GetINT15AHDescription := 'PS/2 mouse services';
  Else
    GetINT15AHDescription := '';
  End;
End;

{ GetINT1AAHDescription - Sous-fonctions horloge temps reel (INT 1Ah). }
Function GetINT1AAHDescription(AH : Byte) : TString;
Begin
  Case AH Of
    $00 : GetINT1AAHDescription := 'Get system timer tick count -> CX:DX';
    $01 : GetINT1AAHDescription := 'Set system timer tick count';
    $02 : GetINT1AAHDescription := 'Get RTC time (BCD) -> CH:CL:DH';
    $03 : GetINT1AAHDescription := 'Set RTC time (BCD)';
    $04 : GetINT1AAHDescription := 'Get RTC date (BCD) -> CH=siecle,CL=annee,DH:DL';
    $05 : GetINT1AAHDescription := 'Set RTC date (BCD)';
    $06 : GetINT1AAHDescription := 'Set RTC alarm';
    $07 : GetINT1AAHDescription := 'Reset RTC alarm';
  Else
    GetINT1AAHDescription := '';
  End;
End;

{ GetINT31AXDescription - Sous-fonctions DPMI (INT 31h) - utile si
  l'overlay desassemble est lui-meme CLIENT DPMI (rare pour un hote comme
  DPMI16BI.OVL, mais documente par completude - et utile pour desassembler
  le CLIENT qui l'appelle, ex. TPX.EXE/RTM.EXE). }
Function GetINT31AXDescription(AX : Word) : TString;
Begin
  Case AX Of
    $0000 : GetINT31AXDescription := 'Allocate LDT descriptors';
    $0001 : GetINT31AXDescription := 'Free LDT descriptor';
    $0002 : GetINT31AXDescription := 'Segment to descriptor';
    $0006 : GetINT31AXDescription := 'Get segment base address';
    $0007 : GetINT31AXDescription := 'Set segment base address';
    $0008 : GetINT31AXDescription := 'Set segment limit';
    $0009 : GetINT31AXDescription := 'Set descriptor access rights';
    $000A : GetINT31AXDescription := 'Create alias descriptor';
    $0300 : GetINT31AXDescription := 'Simulate real mode interrupt';
    $0301 : GetINT31AXDescription := 'Call real mode procedure (retf frame)';
    $0302 : GetINT31AXDescription := 'Call real mode procedure (iret frame)';
    $0303 : GetINT31AXDescription := 'Allocate real mode callback address';
    $0304 : GetINT31AXDescription := 'Free real mode callback address';
    $0305 : GetINT31AXDescription := 'Get Version (un hote reel NE DOIT PAS modifier SI)';
    $0306 : GetINT31AXDescription := 'Get raw mode switch address -> BX:CX(16b)/SI:DI(32b)';
    $0400 : GetINT31AXDescription := 'Get DPMI version (ancien format)';
    $0500 : GetINT31AXDescription := 'Get free memory information';
    $0501 : GetINT31AXDescription := 'Allocate memory block (extended)';
    $0502 : GetINT31AXDescription := 'Free memory block (extended)';
  Else
    GetINT31AXDescription := '';
  End;
End;

{ GetFullIntDescription - Combine la description generique de
  l'interruption (GetINTDescription) avec la sous-fonction AH/AX si elle a
  pu etre deduite (KnownAH/KnownAX < 0 si inconnue). }
Function GetFullIntDescription(IntNum : Byte; KnownAH : Integer;
                                KnownAX : LongInt) : TString;
Var
  BaseDesc : TString;
  SubDesc  : TString;
Begin
  BaseDesc := GetINTDescription(IntNum);
  SubDesc := '';
  Case IntNum Of
    $15 : If KnownAH >= 0 Then SubDesc := GetINT15AHDescription(Byte(KnownAH));
    $1A : If KnownAH >= 0 Then SubDesc := GetINT1AAHDescription(Byte(KnownAH));
    $21 : If KnownAH >= 0 Then SubDesc := GetINT21AHDescription(Byte(KnownAH));
    $2F : If KnownAX >= 0 Then SubDesc := GetINT2FAXDescription(Word(KnownAX));
    $31 : If KnownAX >= 0 Then SubDesc := GetINT31AXDescription(Word(KnownAX));
  End;
  If (SubDesc = '') And (KnownAH >= 0) And
     ((IntNum = $21) Or (IntNum = $15) Or (IntNum = $1A)) Then
    SubDesc := 'AH=' + HexByte(Byte(KnownAH)) + 'h (sous-fonction non repertoriee)';
  If BaseDesc = '' Then BaseDesc := 'INT ' + HexByte(IntNum) + 'h';
  If SubDesc <> '' Then
    GetFullIntDescription := BaseDesc + ' - ' + SubDesc
  Else
    GetFullIntDescription := BaseDesc;
End;

{ GetIOPortAnnotation - Identifie un port materiel courant pour IN/OUT. Le
  port peut etre un immediat (ex. "IN AL, 70h") ou passer par DX (ex.
  "IN AL, DX") - dans ce dernier cas, KnownDX (suivi incremental du plus
  recent MOV DX,imm16) est utilise s'il est connu. }
Function GetIOPortAnnotation(Mnem, Ops : TString; KnownDX : LongInt) : TString;
Var
  Port     : LongInt;
  Code     : Integer;
  CommaPos : Integer;
  PortStr  : TString;
  Desc     : TString;
Begin
  GetIOPortAnnotation := '';
  Port := -1;
  CommaPos := Pos(',', Ops);
  If UpCaseStr(Mnem) = 'IN' Then Begin
    { IN AL/AX, port - le port est le 2e operande }
    If CommaPos > 0 Then
      PortStr := Copy(Ops, CommaPos + 1, Length(Ops))
    Else
      PortStr := '';
  End Else Begin
    { OUT port, AL/AX - le port est le 1er operande }
    If CommaPos > 0 Then
      PortStr := Copy(Ops, 1, CommaPos - 1)
    Else
      PortStr := Ops;
  End;
  { Retirer un eventuel espace d'en-tete (le formateur d'operandes separe
    toujours par ", " - pas besoin de TrimStr, non encore declaree ici). }
  While (Length(PortStr) > 0) And (PortStr[1] = ' ') Do
    PortStr := Copy(PortStr, 2, Length(PortStr) - 1);
  If UpCaseStr(PortStr) = 'DX' Then Begin
    If KnownDX >= 0 Then Port := KnownDX;
  End Else If (Length(PortStr) > 1) And (PortStr[Length(PortStr)] = 'h') Then Begin
    Val('$' + Copy(PortStr, 1, Length(PortStr) - 1), Port, Code);
    If Code <> 0 Then Port := -1;
  End;
  If Port < 0 Then Exit;
  Desc := '';
  Case Port Of
    $0020, $0021 : Desc := 'PIC maitre (8259A)';
    $0040, $0041, $0042, $0043 : Desc := 'PIT (8253/8254), compteur/mode';
    $0060 : Desc := '8042 clavier - donnees (ou PPI 8255 port A sur PC/XT)';
    $0061 : Desc := 'PPI port B (haut-parleur, verrou temporisation)';
    $0064 : Desc := '8042 clavier - commande/etat';
    $0070, $0071 : Desc := 'CMOS/RTC - index/donnees (voir NMI au bit 7 de 70h)';
    $00A0, $00A1 : Desc := 'PIC esclave (8259A, AT+)';
    $0092 : Desc := 'PS/2 port de controle systeme - bit1 = GATE A20 RAPIDE';
    $03F8 : Desc := 'COM1 - UART (8250/16450/16550)';
    $02F8 : Desc := 'COM2 - UART';
  Else
    Desc := '';
  End;
  If Desc <> '' Then
    GetIOPortAnnotation := 'port ' + HexDWord(Port) + 'h = ' + Desc;
End;

{ GetInstructionAnnotation - Determine le commentaire d'annotation a ajouter
  apres une instruction desassemblee.
  Parametres :
    Mnem    : mnemonique de l'instruction
    Ops     : operandes de l'instruction
    Addr    : adresse de l'instruction dans l'image
    Mode32  : True si mode 32 bits
    KnownAH : derniere valeur AH connue par suivi incremental (-1 inconnue)
    KnownAX : derniere valeur AX/eAX connue (-1 inconnue)
    KnownDX : derniere valeur DX connue, pour IN/OUT via DX (-1 inconnue)
  Retourne une chaine de commentaire (vide si aucun commentaire a ajouter). }
Function GetInstructionAnnotation(Mnem, Ops : TString;
                                    Addr : LongInt; Mode32 : Boolean;
                                    KnownAH : Integer;
                                    KnownAX, KnownDX : LongInt) : TString;
Var
  UMnem   : TString;
  UOps    : TString;
  IntNum  : Byte;
  Code    : Integer;
  IntVal  : LongInt;
Begin
  GetInstructionAnnotation := '';
  UMnem := UpCaseStr(Mnem);
  UOps := UpCaseStr(Ops);

  { INT imm8 : annoter le numero ET, si deductible, la sous-fonction AH/AX }
  If UMnem = 'INT' Then Begin
    IntVal := 0;
    If Length(Ops) > 0 Then Begin
      Val('$' + Copy(Ops, 1, Length(Ops) - 1), IntVal, Code);
      If Code = 0 Then Begin
        IntNum := Byte(IntVal And $FF);
        GetInstructionAnnotation := GetFullIntDescription(IntNum, KnownAH, KnownAX);
      End;
    End;
    Exit;
  End;

  { IN/OUT : port materiel connu (immediat ou DX suivi incrementalement) }
  If (UMnem = 'IN') Or (UMnem = 'OUT') Then Begin
    GetInstructionAnnotation := GetIOPortAnnotation(Mnem, Ops, KnownDX);
    Exit;
  End;

  { Instructions mode protege 80286+ : LGDT/SGDT/LIDT/SIDT chargent/lisent
    les tables de descripteurs, SMSW/LMSW lisent/ecrivent le mot d etat
    machine (bit 0 = PE) - rares et hautement diagnostiques pour reperer
    une VRAIE bascule protege dans un extenseur. }
  If (UMnem = 'LGDT') Or (UMnem = 'SGDT') Or (UMnem = 'LIDT') Or
     (UMnem = 'SIDT') Or (UMnem = 'SMSW') Or (UMnem = 'LMSW') Then Begin
    GetInstructionAnnotation := '*** MODE PROTEGE *** ' + Mnem;
    Exit;
  End;
  { MOV CRn,r32 ou MOV r32,CRn : CR0 bit 0 = PE (Protection Enable) - LE
    moment exact ou un extenseur bascule reellement en mode protege. }
  If (UMnem = 'MOV') And
     ((Pos('CR0', UOps) > 0) Or (Pos('CR1', UOps) > 0) Or
      (Pos('CR2', UOps) > 0) Or (Pos('CR3', UOps) > 0)) Then Begin
    GetInstructionAnnotation := '*** MODE PROTEGE *** registre de controle (CR0 bit0=PE)';
    Exit;
  End;
End;

{ WriteASMCodeRange - Emet le code desassemble pour une plage d'adresses.
  Parametres :
    F         : fichier de sortie
    StartAddr : adresse de debut dans l'image
    EndAddr   : adresse de fin (exclue) dans l'image
    Mode32    : True si mode 32 bits }
Procedure WriteASMCodeRange(Var F : Text; StartAddr, EndAddr : LongInt;
                             Mode32 : Boolean);
Var
  Addr       : LongInt;
  Mnem       : TString;
  Ops        : TString;
  InstrSize  : Integer;
  LblIdx     : LongInt;
  PrevIsProc : Boolean;
  LineStr    : TString;
  HexStr     : TString;
  BFlag      : Byte;
  Annotation : TString;
  AddrStr    : TString;
  { Suivi incremental FORWARD de AH/AX/DX pour les annotations INT/IN/OUT -
    voir GetInstructionAnnotation. LIMITE ASSUMEE (documentee, acceptable  }
  { pour un commentaire "au mieux" plutot qu'une garantie) : seul un MOV   }
  { AH/AX/DX,immediat direct met a jour le suivi ; toute AUTRE instruction }
  { qui modifierait ces registres autrement (POP AX, ADD AL,.., XCHG...)   }
  { n'invalide PAS le suivi - un commentaire peut donc occasionnellement   }
  { refleter une sous-fonction perimee plutot que la vraie. }
  TrackAH    : Integer;
  TrackAX    : LongInt;
  TrackDX    : LongInt;
  TrkComma   : Integer;
  TrkLeft    : TString;
  TrkRight   : TString;
  TrkVal     : LongInt;
  TrkCode    : Integer;
Begin
  Addr := StartAddr;
  PrevIsProc := False;
  TrackAH := -1;
  TrackAX := -1;
  TrackDX := -1;

  While Addr < EndAddr Do Begin
    { Verifier si cet octet est du code (ByteFlags) }
    BFlag := BF_UNKNOWN;
    If (ByteFlags <> Nil) And (Addr >= 0) And (Addr < ImageSize) Then
      BFlag := ByteFlags^[Addr];

    { Si c'est de la donnee, du string, du padding ou un jump table, emettre en DB }
    If (BFlag = BF_DATA) Or (BFlag = BF_STRING) Or
       (BFlag = BF_PSTRING) Or
       (BFlag = BF_JUMPTBL) Or (BFlag = BF_PADDING) Then Begin
      { En mode DOS 16 bits, les donnees sont deja emises dans DSEG }
      If Not Mode32 Then Begin
        Inc(Addr);
        Continue;
      End;
      { Emettre un label si necessaire }
      LblIdx := FindLabel(Addr);
      If LblIdx >= 0 Then Begin
        If Labels[LblIdx].IsProc Then Begin
          WriteLn(F);
          WriteLn(F, '; ---------------------------------------------------------------------------');
        End;
        WriteLn(F, Labels[LblIdx].Name, ':');
      End;
      { Emettre un DB pour cet octet }
      LineStr := '        DB      ' + HexByte(ReadImageByte(Addr)) + 'h';
      If OptHex Then
        LineStr := LineStr + '                ; ' + HexByte(ReadImageByte(Addr));
      WriteLn(F, LineStr);
      Inc(Addr);
      Continue;
    End;

    { Emettre un label si cette adresse en a un }
    LblIdx := FindLabel(Addr);
    If LblIdx >= 0 Then Begin
      { Inserer un separateur visuel entre sous-programmes  }
      If Labels[LblIdx].IsProc Then Begin
        If PrevIsProc Or (Addr > StartAddr) Then
          WriteLn(F);
        WriteLn(F, '; ===========================================================================');
        If Mode32 Then
          AddrStr := HexDWord(Addr) + 'h'
        Else
          AddrStr := HexWord(Word(Addr)) + 'h';
        WriteLn(F, '; Sous-programme ', Labels[LblIdx].Name, '  (', AddrStr, ')');
        If Labels[LblIdx].IsExport Then
          WriteLn(F, '; Exported entry point');
        WriteLn(F, '; ===========================================================================');
        PrevIsProc := True;
      End Else Begin
        PrevIsProc := False;
      End;
      WriteLn(F, Labels[LblIdx].Name, ':');
      { Un label = point de jonction de flux de controle possible depuis
        n'importe ou : le suivi AH/AX/DX accumule jusqu'ici n'est plus
        fiable, on repart a "inconnu". }
      TrackAH := -1; TrackAX := -1; TrackDX := -1;
    End Else
      PrevIsProc := False;

    { Desassembler l'instruction }
    DisassembleInstruction(Addr, Mode32, Mnem, Ops, InstrSize);

    { Securite : eviter boucle infinie }
    If InstrSize < 1 Then InstrSize := 1;

    { Formater la ligne }
    If Ops <> '' Then
      LineStr := '        ' + Mnem + '      ' + Ops
    Else
      LineStr := '        ' + Mnem;

    { Generer les annotations automatiques (utilise l'etat AH/AX/DX
      ACCUMULE JUSQU'ICI, donc avant la mise a jour ci-dessous - une
      annotation sur un MOV AH,imm lui-meme ne doit pas se voir elle-meme). }
    Annotation := GetInstructionAnnotation(Mnem, Ops, Addr, Mode32,
                    TrackAH, TrackAX, TrackDX);

    { Mettre a jour le suivi AH/AX/DX pour les instructions suivantes }
    If UpCaseStr(Mnem) = 'MOV' Then Begin
      TrkComma := Pos(',', Ops);
      If TrkComma > 0 Then Begin
        TrkLeft := UpCaseStr(Copy(Ops, 1, TrkComma - 1));
        TrkRight := Copy(Ops, TrkComma + 2, Length(Ops)); { saute ", " }
        If (Length(TrkRight) > 0) And (TrkRight[Length(TrkRight)] = 'h') And
           ((TrkRight[1] = '$') Or (TrkRight[1] In ['0'..'9'])) Then Begin
          Val('$' + Copy(TrkRight, 1, Length(TrkRight) - 1), TrkVal, TrkCode);
          If TrkCode = 0 Then Begin
            If TrkLeft = 'AH' Then
              TrackAH := Byte(TrkVal)
            Else If (TrkLeft = 'AX') Or (TrkLeft = 'EAX') Then Begin
              TrackAX := Word(TrkVal);
              TrackAH := (Word(TrkVal) Shr 8) And $FF;
            End Else If TrkLeft = 'DX' Then
              TrackDX := Word(TrkVal);
          End;
        End Else Begin
          { MOV AH/AX/DX,<non-immediat> (registre, memoire...) : la valeur
            devient indeterminee plutot que de laisser une ancienne valeur
            perimee se faire passer pour la nouvelle. }
          If TrkLeft = 'AH' Then TrackAH := -1
          Else If (TrkLeft = 'AX') Or (TrkLeft = 'EAX') Then Begin
            TrackAX := -1; TrackAH := -1;
          End Else If TrkLeft = 'DX' Then TrackDX := -1;
        End;
      End;
    End;

    { Ajouter les octets hexadecimaux en commentaire si -hex }
    If OptHex Then Begin
      { Completer avec des espaces pour aligner le commentaire }
      While Length(LineStr) < 48 Do
        LineStr := LineStr + ' ';
      HexStr := FormatHexBytes(Addr, InstrSize);
      If Annotation <> '' Then
        LineStr := LineStr + '; ' + HexStr + '  ' + Annotation
      Else
        LineStr := LineStr + '; ' + HexStr;
    End Else If Annotation <> '' Then Begin
      { Ajouter l'annotation meme sans -hex }
      While Length(LineStr) < 48 Do
        LineStr := LineStr + ' ';
      LineStr := LineStr + '; ' + Annotation;
    End;

    WriteLn(F, LineStr);
    Inc(InstrCount);
    Addr := Addr + InstrSize;
  End;
End;

{ WriteASMCodeDOS16 - Emet la section de code pour l'overlay. Le code EMIS
  couvre TOUJOURS l'image entiere (0..ImageSize, "maximum d'information") -
  OvlEntryOfs n'influence que la discrimination code/donnees prealable
  (AnalyzeControlFlow/DetectProcedures/DiscriminateCodeData), pas ce qui
  est ecrit ici. }
Procedure WriteASMCodeDOS16(Var F : Text);
Begin
  WriteLn(F, '; Offset de depart utilise pour l''analyse de flux (-entry:) : ',
          HexDWord(OvlEntryOfs), 'h');
  WriteLn(F);
  WriteASMCodeRange(F, 0, ImageSize, False);
End;

{ FormatImmediateOperand - Remplace une valeur immediate par le label d'une
  chaine lorsqu'elle pointe exactement sur son premier octet. Pour un PE,
  accepte aussi bien une RVA qu'une adresse virtuelle ImageBase+RVA.
  Les autres constantes restent numeriques afin de ne pas transformer les
  constantes ordinaires en fausses references de donnees. }
Function FormatImmediateOperand(Value : LongWord; Mode32 : Boolean) : TString;
Var
  Addr   : LongInt;
  LblIdx : LongInt;
  Flag   : Byte;
Begin
  Addr := LongInt(Value);
  LblIdx := -1;

  If (Addr >= 0) And (Addr < ImageSize) Then
    LblIdx := FindLabel(Addr)
  Else If Mode32 And IsPEFile And
          (Value >= LongWord(PEOptHeader.ImageBase)) And
          (Value - LongWord(PEOptHeader.ImageBase) < LongWord(ImageSize)) Then Begin
    Addr := LongInt(Value - LongWord(PEOptHeader.ImageBase));
    LblIdx := FindLabel(Addr);
  End;

  If (LblIdx >= 0) And (ByteFlags <> Nil) And
     (Addr >= 0) And (Addr < ImageSize) Then Begin
    Flag := ByteFlags^[Addr];
    If (Flag = BF_STRING) Or (Flag = BF_PSTRING) Then Begin
      FormatImmediateOperand := 'OFFSET ' + Labels[LblIdx].Name;
      Exit;
    End;
  End;

  If Mode32 Then
    FormatImmediateOperand := HexDWord(LongInt(Value)) + 'h'
  Else
    FormatImmediateOperand := HexWord(Word(Value)) + 'h';
End;

{ ============================================================
  GENERATION DU FICHIER .ASM : SECTION DE DONNEES
  ============================================================ }

{ IsASMSafeChar - Teste si un caractere peut apparaitre directement dans
  une chaine entre apostrophes en syntaxe MASM (ASCII imprimable sauf
  l'apostrophe qui doit etre doublee). }
Function IsASMSafeChar(B : Byte) : Boolean;
Begin
  IsASMSafeChar := (B >= 32) And (B <= 126);
End;

{ EmitASMString - Emet une chaine ASCII detectee sous forme DB 'texte',0.
  Gere les apostrophes en les doublant ('') et les caracteres de controle
  courants (TAB=09h, CR=0Dh, LF=0Ah) en les emettant numeriquement.
  Parametres :
    F         : fichier de sortie
    Addr      : adresse de debut de la chaine dans l'image
    Mode32    : True si mode 32 bits (pour le format hex des commentaires)
  Retourne le nombre d'octets consommes (longueur chaine + NUL terminal). }
Function EmitASMString(Var F : Text; Addr : LongInt; Mode32 : Boolean) : LongInt;
Var
  StartAddr : LongInt;
  B         : Byte;
  InStr     : Boolean;  { on est en cours d'emission dans une chaine '' }
  LineStr   : TString;
  StrLen    : LongInt;
  First     : Boolean;  { premier element sur la ligne }
Begin
  StartAddr := Addr;
  LineStr := '        DB      ';
  InStr := False;
  First := True;

  { Parcourir la chaine jusqu'au NUL terminal }
  While Addr < ImageSize Do Begin
    B := ReadImageByte(Addr);
    If B = 0 Then Begin
      { Terminer la chaine en cours si necessaire }
      If InStr Then Begin
        LineStr := LineStr + '''';
        InStr := False;
      End;
      If Not First Then
        LineStr := LineStr + ',';
      LineStr := LineStr + '0';
      Inc(Addr);
      Break;
    End;
    If IsASMSafeChar(B) Then Begin
      If Not InStr Then Begin
        If Not First Then
          LineStr := LineStr + ',';
        LineStr := LineStr + '''';
        InStr := True;
      End;
      If Chr(B) = '''' Then
        LineStr := LineStr + ''''''  { doubler l'apostrophe }
      Else
        LineStr := LineStr + Chr(B);
    End Else Begin
      { Caractere non imprimable : emettre numeriquement }
      If InStr Then Begin
        LineStr := LineStr + '''';
        InStr := False;
      End;
      If Not First Then
        LineStr := LineStr + ',';
      LineStr := LineStr + HexByte(B) + 'h';
    End;
    First := False;
    Inc(Addr);
    { Securite : limiter la longueur de la ligne }
    If Length(LineStr) > 200 Then Begin
      If InStr Then Begin
        LineStr := LineStr + '''';
        InStr := False;
      End;
      WriteLn(F, LineStr);
      LineStr := '        DB      ';
      First := True;
    End;
  End;
  If InStr Then
    LineStr := LineStr + '''';
  WriteLn(F, LineStr);
  StrLen := Addr - StartAddr;
  EmitASMString := StrLen;
End;

{ EmitASMPascalString - Emet une chaine Pascal courte sous la forme
  DB longueur,'texte'. Les caracteres de controle sont conserves sous forme
  numerique et les apostrophes sont doublees pour la syntaxe MASM. }
Function EmitASMPascalString(Var F : Text; Addr : LongInt) : LongInt;
Var
  StartAddr : LongInt;
  EndAddr   : LongInt;
  B         : Byte;
  InStr     : Boolean;
  LineStr   : TString;
  First     : Boolean;
Begin
  StartAddr := Addr;
  EndAddr := Addr + ReadImageByte(Addr) + 1;
  LineStr := '        DB      ' + IntToStr(ReadImageByte(Addr));
  Inc(Addr);
  InStr := False;
  First := False;

  While (Addr < EndAddr) And (Addr < ImageSize) Do Begin
    B := ReadImageByte(Addr);
    If IsASMSafeChar(B) Then Begin
      If Not InStr Then Begin
        If Not First Then LineStr := LineStr + ',';
        LineStr := LineStr + '''';
        InStr := True;
      End;
      If Chr(B) = '''' Then
        LineStr := LineStr + ''''''
      Else
        LineStr := LineStr + Chr(B);
    End Else Begin
      If InStr Then Begin
        LineStr := LineStr + '''';
        InStr := False;
      End;
      If Not First Then LineStr := LineStr + ',';
      LineStr := LineStr + HexByte(B) + 'h';
    End;
    First := False;
    Inc(Addr);

    If Length(LineStr) > 200 Then Begin
      If InStr Then Begin
        LineStr := LineStr + '''';
        InStr := False;
      End;
      WriteLn(F, LineStr);
      LineStr := '        DB      ';
      First := True;
    End;
  End;
  If InStr Then LineStr := LineStr + '''';
  WriteLn(F, LineStr);
  EmitASMPascalString := Addr - StartAddr;
End;

{ WriteASMDataRange - Emet les donnees d'une plage d'adresses avec les
  directives DB, DW, DD. Detecte les chaines ASCII (BF_STRING) et les
  emet avec DB 'texte',0. Regroupe les octets consecutifs non-chaine en
  lignes de DB xx,xx,xx,... (16 octets max par ligne). Emet les entrees
  de table de saut (BF_JUMPTBL) en DD avec le label correspondant.
  Genere des labels pour les variables referencees.
  Parametres :
    F         : fichier de sortie
    StartAddr : adresse de debut dans l'image
    EndAddr   : adresse de fin (exclue) dans l'image
    Mode32    : True si mode 32 bits }
Procedure WriteASMDataRange(Var F : Text; StartAddr, EndAddr : LongInt;
                             Mode32 : Boolean);
Var
  Addr      : LongInt;
  LblIdx    : LongInt;
  BFlag     : Byte;
  B         : Byte;
  LineStr   : TString;
  ByteCount : Integer;
  StrBytes  : LongInt;
  DWordVal  : LongInt;
  TargetLbl : LongInt;
Begin
  Addr := StartAddr;
  If EndAddr > ImageSize Then EndAddr := ImageSize;

  While Addr < EndAddr Do Begin
    { Determiner le flag de cet octet }
    BFlag := BF_UNKNOWN;
    If (ByteFlags <> Nil) And (Addr >= 0) And (Addr < ImageSize) Then
      BFlag := ByteFlags^[Addr];

    { Si c'est du code, sauter jusqu'au prochain non-code }
    If BFlag = BF_CODE Then Begin
      Inc(Addr);
      Continue;
    End;

    { Emettre un label si cette adresse en a un }
    LblIdx := FindLabel(Addr);
    If LblIdx >= 0 Then Begin
      WriteLn(F, Labels[LblIdx].Name, ':');
    End;

    { Chaine ASCII : emettre avec DB 'texte',0 }
    If BFlag = BF_STRING Then Begin
      StrBytes := EmitASMString(F, Addr, Mode32);
      If StrBytes < 1 Then StrBytes := 1;
      Addr := Addr + StrBytes;
      Continue;
    End;

    { Chaine Pascal courte : emettre longueur puis texte }
    If BFlag = BF_PSTRING Then Begin
      StrBytes := EmitASMPascalString(F, Addr);
      If StrBytes < 1 Then StrBytes := 1;
      Addr := Addr + StrBytes;
      Continue;
    End;

    { Table de saut : emettre en DD avec label si possible }
    If (BFlag = BF_JUMPTBL) And (Addr + 3 < EndAddr) Then Begin
      DWordVal := ReadImageDWord(Addr);
      TargetLbl := FindLabel(DWordVal);
      If TargetLbl >= 0 Then
        WriteLn(F, '        DD      OFFSET ', Labels[TargetLbl].Name)
      Else
        WriteLn(F, '        DD      ', HexDWord(DWordVal), 'h');
      Addr := Addr + 4;
      Continue;
    End;

    { Padding : emettre en DB avec commentaire }
    If BFlag = BF_PADDING Then Begin
      B := ReadImageByte(Addr);
      { Compter les octets de padding consecutifs identiques }
      ByteCount := 0;
      While (Addr + ByteCount < EndAddr) And (ByteCount < 256) Do Begin
        If (ByteFlags <> Nil) And (ByteFlags^[Addr + ByteCount] = BF_PADDING) And
           (ReadImageByte(Addr + ByteCount) = B) Then
          Inc(ByteCount)
        Else
          Break;
      End;
      If ByteCount < 1 Then ByteCount := 1;
      If ByteCount > 1 Then
        WriteLn(F, '        DB      ', IntToStr(ByteCount), ' DUP(', HexByte(B), 'h)',
                '  ; padding')
      Else
        WriteLn(F, '        DB      ', HexByte(B), 'h  ; padding');
      Addr := Addr + ByteCount;
      Continue;
    End;

    { Donnees generiques (BF_DATA ou BF_UNKNOWN) : emettre en lignes de DB }
    LineStr := '        DB      ';
    ByteCount := 0;
    While (Addr < EndAddr) And (ByteCount < 16) Do Begin
      { Verifier le flag de l'octet courant }
      BFlag := BF_UNKNOWN;
      If (ByteFlags <> Nil) And (Addr >= 0) And (Addr < ImageSize) Then
        BFlag := ByteFlags^[Addr];
      { Arreter si on tombe sur du code, une chaine, un jump table ou un padding }
      If (BFlag = BF_CODE) Or (BFlag = BF_STRING) Or
         (BFlag = BF_PSTRING) Or
         (BFlag = BF_JUMPTBL) Or (BFlag = BF_PADDING) Then
        Break;
      { Arreter si l'adresse suivante a un label (sauf le premier octet) }
      If (ByteCount > 0) And (FindLabel(Addr) >= 0) Then
        Break;
      B := ReadImageByte(Addr);
      If ByteCount > 0 Then
        LineStr := LineStr + ',';
      LineStr := LineStr + HexByte(B) + 'h';
      Inc(ByteCount);
      Inc(Addr);
    End;
    If ByteCount > 0 Then
      WriteLn(F, LineStr);
    { Securite : si rien n'a ete emis, avancer d'un octet }
    If ByteCount = 0 Then Begin
      B := ReadImageByte(Addr);
      WriteLn(F, '        DB      ', HexByte(B), 'h');
      Inc(Addr);
    End;
  End;
End;

{ WriteASMDataDOS16 - Emet les donnees du segment de donnees pour un EXE
  DOS 16 bits. Parcourt l'image et emet les octets marques comme donnees
  (BF_DATA, BF_STRING, etc.) dans le segment DSEG. }
Procedure WriteASMDataDOS16(Var F : Text);
Begin
  WriteLn(F, '; Donnees extraites de l''image');
  WriteLn(F);
  WriteASMDataRange(F, 0, ImageSize, False);
End;

{ ============================================================
  ETIQUETTES AUTOMATIQUES ET TABLE DES SYMBOLES
  ============================================================ }

{ FindLabelByName - Recherche un label dans la table par son nom.
  Retourne l'index du label si trouve, -1 sinon.
  La comparaison est insensible a la casse. }
Function FindLabelByName(AName : TString) : LongInt;
Var
  I    : LongInt;
  UName : TString;
  ULbl  : TString;
Begin
  UName := UpCaseStr(AName);
  For I := 0 To LabelCount - 1 Do Begin
    ULbl := UpCaseStr(Labels[I].Name);
    If ULbl = UName Then Begin
      FindLabelByName := I;
      Exit;
    End;
  End;
  FindLabelByName := -1;
End;

{ ResolveSymbolName - Retourne le meilleur nom disponible pour une adresse.
  Priorite : import/export (nom reel) > nom existant non-vide > generation auto.
  Si aucun label n'existe, retourne une chaine vide. }
Function ResolveSymbolName(Addr : LongInt; Mode32 : Boolean) : TString;
Var
  Idx : LongInt;
Begin
  Idx := FindLabel(Addr);
  If Idx >= 0 Then Begin
    { Le label existe, retourner son nom }
    If Labels[Idx].Name <> '' Then Begin
      ResolveSymbolName := Labels[Idx].Name;
      Exit;
    End;
    { Nom vide, generer un nom automatique }
    ResolveSymbolName := GenerateLabelName(Addr, Labels[Idx].IsProc, Mode32);
  End Else
    ResolveSymbolName := '';
End;

{ IsDataLabel - Teste si un label pointe vers une zone de donnees
  (BF_DATA, BF_STRING, BF_JUMPTBL, BF_PADDING ou BF_UNKNOWN).
  Retourne True si le label n'est pas dans du code. }
Function IsDataLabel(Addr : LongInt) : Boolean;
Var
  BF : Byte;
Begin
  IsDataLabel := False;
  If (ByteFlags = Nil) Or (Addr < 0) Or (Addr >= ImageSize) Then Exit;
  BF := ByteFlags^[Addr];
  IsDataLabel := (BF <> BF_CODE);
End;

{ CountConsecutiveDataBytes - Compte le nombre d'octets consecutifs de
  donnees (BF_DATA) a partir d'une adresse donnee, sans depasser un label.
  Utilise pour determiner la taille du bloc de donnees (dword, word, byte). }
Function CountConsecutiveDataBytes(Addr : LongInt) : LongInt;
Var
  Count : LongInt;
  Limit : LongInt;
Begin
  Count := 0;
  Limit := ImageSize;
  If Limit > Addr + 16 Then Limit := Addr + 16;
  While (Addr + Count < Limit) Do Begin
    If ByteFlags = Nil Then Break;
    If ByteFlags^[Addr + Count] <> BF_DATA Then Break;
    { S'arreter si on rencontre un autre label (sauf le premier octet) }
    If (Count > 0) And (FindLabel(Addr + Count) >= 0) Then Break;
    Inc(Count);
  End;
  CountConsecutiveDataBytes := Count;
End;

{ IsRelocatedAddress - Teste si une adresse est une position relogee
  (contient un offset/pointeur). Retourne True si l'adresse fait partie
  d'un relogement MZ ou PE. }
Function IsRelocatedAddress(Addr : LongInt) : Boolean;
Begin
  IsRelocatedAddress := False;
  If (RelocFlags <> Nil) And (Addr >= 0) And (Addr < ImageSize) Then Begin
    If RelocFlags^[Addr] = 1 Then
      IsRelocatedAddress := True;
  End;
End;

{ RefineDataLabels - Parcourt la table des labels et ameliore les noms
  des labels de donnees generiques (loc_XXXX) en noms plus specifiques
  selon le type de donnees :
    - off_XXXX  : offset/pointeur (adresse relogee)
    - dword_XXXX : donnee de 4 octets
    - word_XXXX  : donnee de 2 octets
    - byte_XXXX  : donnee de 1 octet
  Les labels deja nommes (aStr_, jtbl_, imports, exports, sub_) ne sont
  pas modifies. }
Procedure RefineDataLabels(Mode32 : Boolean);
Var
  I         : LongInt;
  Addr      : LongInt;
  OldName   : TString;
  NewName   : TString;
  DataSize  : LongInt;
  AddrStr   : TString;
  Prefix    : TString;
  Refined   : LongInt;
Begin
  Refined := 0;
  For I := 0 To LabelCount - 1 Do Begin
    Addr := Labels[I].Address;
    OldName := Labels[I].Name;
    { Ne pas modifier les imports, exports ou procedures }
    If Labels[I].IsImport Then Continue;
    If Labels[I].IsExport Then Continue;
    If Labels[I].IsProc Then Continue;
    { Ne modifier que les labels loc_XXXX (generes automatiquement pour du code) }
    If Length(OldName) < 4 Then Continue;
    If Copy(OldName, 1, 4) <> 'loc_' Then Continue;
    { Verifier que l'adresse pointe vers des donnees }
    If Not IsDataLabel(Addr) Then Continue;
    { Generer le suffixe d'adresse }
    If Mode32 Then
      AddrStr := HexDWord(Addr)
    Else
      AddrStr := HexWord(Word(Addr));
    { Determiner le type de donnees }
    If IsRelocatedAddress(Addr) Then Begin
      { C'est un pointeur/offset reloge }
      Prefix := 'off_';
    End Else Begin
      { Classifier selon la taille du bloc de donnees }
      DataSize := CountConsecutiveDataBytes(Addr);
      If DataSize >= 4 Then
        Prefix := 'dword_'
      Else If DataSize >= 2 Then
        Prefix := 'word_'
      Else
        Prefix := 'byte_';
    End;
    NewName := Prefix + AddrStr;
    Labels[I].Name := NewName;
    Inc(Refined);
  End;
  If OptVerbose And (Refined > 0) Then
    WriteLn('  Labels de donnees raffines : ', Refined);
End;

{ ParseHexValue - Convertit une chaine hexadecimale en LongInt.
  Accepte les prefixes 0x, $, et les suffixes h.
  Retourne True si la conversion a reussi. }
Function ParseHexValue(S : TString; Var Value : LongInt) : Boolean;
Var
  I      : Integer;
  C      : Char;
  Digit  : Integer;
  Result : LongInt;
Begin
  ParseHexValue := False;
  { Retirer espaces de debut/fin }
  While (Length(S) > 0) And (S[1] = ' ') Do Delete(S, 1, 1);
  While (Length(S) > 0) And (S[Length(S)] = ' ') Do Delete(S, Length(S), 1);
  If Length(S) = 0 Then Exit;
  { Retirer prefixes 0x ou $ }
  If (Length(S) >= 2) And (S[1] = '0') And ((S[2] = 'x') Or (S[2] = 'X')) Then
    Delete(S, 1, 2)
  Else If S[1] = '$' Then
    Delete(S, 1, 1);
  { Retirer suffixe h }
  If (Length(S) > 0) And ((S[Length(S)] = 'h') Or (S[Length(S)] = 'H')) Then
    Delete(S, Length(S), 1);
  If Length(S) = 0 Then Exit;
  Result := 0;
  For I := 1 To Length(S) Do Begin
    C := S[I];
    If (C >= '0') And (C <= '9') Then
      Digit := Ord(C) - Ord('0')
    Else If (C >= 'A') And (C <= 'F') Then
      Digit := Ord(C) - Ord('A') + 10
    Else If (C >= 'a') And (C <= 'f') Then
      Digit := Ord(C) - Ord('a') + 10
    Else
      Exit;  { caractere invalide }
    Result := Result * 16 + Digit;
  End;
  Value := Result;
  ParseHexValue := True;
End;

{ TrimLeft - Retire les espaces en debut de chaine }
Function TrimLeft(S : TString) : TString;
Begin
  While (Length(S) > 0) And (S[1] = ' ') Do Delete(S, 1, 1);
  TrimLeft := S;
End;

{ TrimRight - Retire les espaces en fin de chaine }
Function TrimRight(S : TString) : TString;
Begin
  While (Length(S) > 0) And (S[Length(S)] = ' ') Do Delete(S, Length(S), 1);
  TrimRight := S;
End;

{ TrimStr - Retire les espaces en debut et fin de chaine }
Function TrimStr(S : TString) : TString;
Begin
  TrimStr := TrimRight(TrimLeft(S));
End;

{ ParseMapLine - Tente de parser une ligne de fichier .MAP pour en
  extraire un symbole avec son adresse. Supporte les formats courants :
    - Microsoft LINK : "  0001:00000010  _symbol  00401010  module.obj"
    - Borland TLINK  : "  0001:0010  _symbol"
    - Adresse simple  : "00401010 _symbol"
  Retourne True si un symbole a ete extrait avec succes.
  L'adresse retournee est un offset lineaire (pour MZ : segment*16+offset,
  pour PE : le RVA apres le ':' seulement). }
Function ParseMapLine(Line : TString; Mode32 : Boolean;
                      Var Addr : LongInt; Var SymName : TString) : Boolean;
Var
  S       : TString;
  ColPos  : Integer;
  SegStr  : TString;
  OfsStr  : TString;
  SegVal  : LongInt;
  OfsVal  : LongInt;
  I       : Integer;
  NameStart : Integer;
Begin
  ParseMapLine := False;
  S := TrimStr(Line);
  If Length(S) = 0 Then Exit;
  { Ignorer les lignes de commentaire ou d'en-tete }
  If S[1] = ';' Then Exit;
  If S[1] = '-' Then Exit;
  If S[1] = '=' Then Exit;
  { Chercher le format segment:offset }
  ColPos := 0;
  For I := 1 To Length(S) Do Begin
    If S[I] = ':' Then Begin
      ColPos := I;
      Break;
    End;
    If S[I] = ' ' Then Break; { pas de ':' dans le premier mot }
  End;
  If ColPos > 1 Then Begin
    { Format segment:offset nom }
    SegStr := Copy(S, 1, ColPos - 1);
    { Extraire l'offset apres le ':' }
    I := ColPos + 1;
    While (I <= Length(S)) And (S[I] <> ' ') And (S[I] <> #9) Do Inc(I);
    OfsStr := Copy(S, ColPos + 1, I - ColPos - 1);
    { Parser segment et offset }
    If Not ParseHexValue(SegStr, SegVal) Then Exit;
    If Not ParseHexValue(OfsStr, OfsVal) Then Exit;
    { Calculer l'adresse lineaire }
    If Mode32 Then
      Addr := OfsVal  { PE : l'offset est le RVA direct }
    Else
      Addr := SegVal * 16 + OfsVal;  { DOS : segment*16 + offset }
    { Extraire le nom du symbole (premier mot apres les espaces) }
    While (I <= Length(S)) And ((S[I] = ' ') Or (S[I] = #9)) Do Inc(I);
    If I > Length(S) Then Exit;  { pas de nom }
    NameStart := I;
    While (I <= Length(S)) And (S[I] <> ' ') And (S[I] <> #9) Do Inc(I);
    SymName := Copy(S, NameStart, I - NameStart);
    If Length(SymName) = 0 Then Exit;
    ParseMapLine := True;
  End Else Begin
    { Format adresse_hex nom (sans segment) }
    I := 1;
    While (I <= Length(S)) And (S[I] <> ' ') And (S[I] <> #9) Do Inc(I);
    OfsStr := Copy(S, 1, I - 1);
    If Not ParseHexValue(OfsStr, OfsVal) Then Exit;
    Addr := OfsVal;
    { Extraire le nom }
    While (I <= Length(S)) And ((S[I] = ' ') Or (S[I] = #9)) Do Inc(I);
    If I > Length(S) Then Exit;
    NameStart := I;
    While (I <= Length(S)) And (S[I] <> ' ') And (S[I] <> #9) Do Inc(I);
    SymName := Copy(S, NameStart, I - NameStart);
    If Length(SymName) = 0 Then Exit;
    ParseMapLine := True;
  End;
End;

{ LoadMapFile - Charge un fichier .MAP et importe les symboles dans
  la table des labels. Les symboles du fichier MAP ont la priorite
  la plus elevee et remplacent les noms auto-generes.
  Si un label existe deja a l'adresse, son nom est mis a jour.
  Sinon, un nouveau label est ajoute. }
Procedure LoadMapFile(FileName : TString; Mode32 : Boolean);
Var
  MapFile     : Text;
  Line        : TString;
  Addr        : LongInt;
  SymName     : TString;
  LblIdx      : LongInt;
  Loaded      : LongInt;
  Skipped     : LongInt;
Begin
  Loaded := 0;
  Skipped := 0;
  WriteLn('Chargement du fichier MAP : ', FileName);
  Assign(MapFile, FileName);
  {$I-}
  Reset(MapFile);
  {$I+}
  If IOResult <> 0 Then Begin
    WriteLn('Erreur : impossible d''ouvrir le fichier MAP ', FileName);
    Exit;
  End;
  While Not Eof(MapFile) Do Begin
    ReadLn(MapFile, Line);
    If ParseMapLine(Line, Mode32, Addr, SymName) Then Begin
      { Verifier que l'adresse est dans l'image }
      If (Addr < 0) Or (Addr >= ImageSize) Then Begin
        Inc(Skipped);
        Continue;
      End;
      { Chercher si un label existe deja a cette adresse }
      LblIdx := FindLabel(Addr);
      If LblIdx >= 0 Then Begin
        { Remplacer le nom auto-genere par le nom du MAP }
        Labels[LblIdx].Name := SymName;
      End Else Begin
        { Ajouter un nouveau label }
        AddLabel(Addr, SymName, False, False, False);
      End;
      Inc(Loaded);
    End;
  End;
  Close(MapFile);
  WriteLn('  Symboles charges depuis MAP : ', Loaded);
  If Skipped > 0 Then
    WriteLn('  Symboles ignores (hors image) : ', Skipped);
End;

{ BuildSymbolTable - Orchestre la construction de la table de symboles
  unifiant tous les labels. Les etapes sont :
  1. Si un fichier .MAP est fourni, charger les symboles
  2. Raffiner les labels de donnees (loc_ -> dword_/word_/byte_/off_)
  3. Trier les labels par adresse pour faciliter la recherche }
Procedure BuildSymbolTable(Mode32 : Boolean);
Var
  SymCount : LongInt;
  ProcLabels : LongInt;
  DataLabels : LongInt;
  ImpLabels  : LongInt;
  ExpLabels  : LongInt;
  I          : LongInt;
Begin
  WriteLn('Construction de la table des symboles...');
  { Etape 1 : charger le fichier .MAP si fourni }
  If OptUseMap And (MapFileName <> '') Then
    LoadMapFile(MapFileName, Mode32);
  { Etape 2 : raffiner les labels de donnees }
  RefineDataLabels(Mode32);
  { Etape 3 : trier les labels }
  SortLabels;
  { Statistiques }
  SymCount := LabelCount;
  ProcLabels := 0;
  DataLabels := 0;
  ImpLabels := 0;
  ExpLabels := 0;
  For I := 0 To LabelCount - 1 Do Begin
    If Labels[I].IsProc Then Inc(ProcLabels);
    If Labels[I].IsImport Then Inc(ImpLabels);
    If Labels[I].IsExport Then Inc(ExpLabels);
    If (Not Labels[I].IsProc) And (Not Labels[I].IsImport)
       And (Not Labels[I].IsExport) Then Inc(DataLabels);
  End;
  WriteLn('Table des symboles construite :');
  WriteLn('  Total symboles    : ', SymCount);
  WriteLn('  Sous-programmes   : ', ProcLabels);
  WriteLn('  Labels de donnees : ', DataLabels);
  WriteLn('  Imports           : ', ImpLabels);
  WriteLn('  Exports           : ', ExpLabels);
  If OptVerbose Then Begin
    WriteLn('Detail des symboles :');
    For I := 0 To LabelCount - 1 Do Begin
      Write('  ', Labels[I].Name, ' @ ');
      If Mode32 Then
        Write('$', HexDWord(Labels[I].Address))
      Else
        Write('$', HexWord(Word(Labels[I].Address)));
      If Labels[I].IsProc Then Write(' [PROC]');
      If Labels[I].IsImport Then Write(' [IMPORT]');
      If Labels[I].IsExport Then Write(' [EXPORT]');
      WriteLn;
    End;
  End;
End;

{ Ecrit les directives de modele et segments pour un EXE DOS 16 bits.
  Genere .MODEL SMALL, .STACK, et les directives SEGMENT/ENDS. }
Procedure WriteASMDirectivesDOS16(Var F : Text);
Begin
  WriteLn(F, '.8086');
  WriteLn(F, '.MODEL SMALL');
  WriteLn(F);
  { Pile : SP initial = taille de la pile pour MZ DOS }
  WriteLn(F, '.STACK ', HexWord(EntrySP), 'h  ; SP initial');
  WriteLn(F);
  { Segment de donnees }
  WriteLn(F, 'DSEG SEGMENT PARA PUBLIC ''DATA''');
  WriteLn(F);
  WriteASMDataDOS16(F);
  WriteLn(F);
  WriteLn(F, 'DSEG ENDS');
  WriteLn(F);
  { Segment de code }
  WriteLn(F, 'CSEG SEGMENT PARA PUBLIC ''CODE''');
  WriteLn(F, '  ASSUME CS:CSEG, DS:DSEG, SS:STACK');
  WriteLn(F);
  WriteASMCodeDOS16(F);
  WriteLn(F);
  WriteLn(F, 'CSEG ENDS');
  WriteLn(F);
  WriteLn(F, 'END');
End;

{ Orchestre la generation de l'en-tete du fichier .ASM.
  Cree le fichier de sortie, ecrit l'en-tete avec commentaires,
  puis les directives adaptees au format (DOS 16 ou PE 32 bits). }
Procedure GenerateASMHeader;
Var
  F : Text;
Begin
  WriteLn('Generation du fichier .ASM : ', OutputFileName);
  Assign(F, OutputFileName);
  {$I-}
  Rewrite(F);
  {$I+}
  If IOResult <> 0 Then Begin
    WriteLn('Erreur : impossible de creer le fichier ', OutputFileName);
    Exit;
  End;
  { En-tete avec commentaires }
  WriteASMHeader(F);
  { Un .OVL est toujours un en-tete MZ (overlay DOS, voir le commentaire de
    tete du programme) - jamais de format PE ici. }
  WriteASMDirectivesDOS16(F);
  Close(F);
  WriteLn('Fichier .ASM genere avec succes.');
End;

{ ============================================================
  VERIFICATION FINALE ET RAPPORT
  ============================================================ }

{ VerifyASMCoherence - Verifie la coherence du desassemblage :
  1. Pas de labels en double (meme adresse et meme nom)
  2. Toutes les references croisees ont un label cible
  3. Les noms de labels sont uniques
  Retourne True si tout est coherent, False sinon. }
Function VerifyASMCoherence : Boolean;
Var
  I, J     : LongInt;
  Errors   : LongInt;
  Found    : Boolean;
Begin
  Errors := 0;
  { Verification 1 : labels uniques par nom }
  For I := 0 To LabelCount - 2 Do Begin
    For J := I + 1 To LabelCount - 1 Do Begin
      If (Labels[I].Name = Labels[J].Name) And
         (Labels[I].Address <> Labels[J].Address) Then Begin
        If OptVerbose Then
          WriteLn('  Avertissement : label duplique "', Labels[I].Name,
                  '" aux adresses $', HexDWord(Labels[I].Address),
                  ' et $', HexDWord(Labels[J].Address));
        Inc(Errors);
      End;
    End;
  End;
  { Verification 2 : chaque cible de reference croisee a un label }
  For I := 0 To XRefCount - 1 Do Begin
    Found := False;
    For J := 0 To LabelCount - 1 Do Begin
      If Labels[J].Address = XRefs[I].ToAddr Then Begin
        Found := True;
        Break;
      End;
    End;
    If Not Found Then Begin
      If OptVerbose Then
        WriteLn('  Avertissement : reference croisee vers $',
                HexDWord(XRefs[I].ToAddr), ' sans label correspondant');
      Inc(Errors);
    End;
  End;
  If Errors = 0 Then
    WriteLn('Verification de coherence : OK (aucune anomalie)')
  Else
    WriteLn('Verification de coherence : ', Errors, ' anomalie(s) detectee(s)');
  VerifyASMCoherence := (Errors = 0);
End;

{ GetFileSize - Retourne la taille d'un fichier en octets, ou -1 si erreur }
Function GetFileSize(Const FileName : TString) : LongInt;
Var
  F    : File Of Byte;
  Size : LongInt;
Begin
  {$I-}
  Assign(F, FileName);
  Reset(F);
  {$I+}
  If IOResult <> 0 Then Begin
    GetFileSize := -1;
    Exit;
  End;
  Size := System.FileSize(F);
  Close(F);
  GetFileSize := Size;
End;

{ DisplayFinalReport - Affiche le rapport final du desassemblage.
  Toujours affiche le resume principal.
  Si OptVerbose, affiche des statistiques detaillees. }
Procedure DisplayFinalReport;
Var
  ASMSize   : LongInt;
  NbImport  : LongInt;
  NbExport  : LongInt;
  NbProc    : LongInt;
  I         : LongInt;
Begin
  WriteLn;
  WriteLn('============================================================');
  WriteLn('  RAPPORT FINAL');
  WriteLn('============================================================');
  WriteLn;
  { Compter les sous-programmes parmi les labels }
  NbProc := 0;
  NbImport := 0;
  NbExport := 0;
  For I := 0 To LabelCount - 1 Do Begin
    If Labels[I].IsProc Then Inc(NbProc);
    If Labels[I].IsImport Then Inc(NbImport);
    If Labels[I].IsExport Then Inc(NbExport);
  End;
  WriteLn('  Fichier source          : ', InputFileName);
  WriteLn('  Fichier ASM genere      : ', OutputFileName);
  If IsPEFile Then
    WriteLn('  Format                  : PE 32 bits (Windows)')
  Else
    WriteLn('  Format                  : MZ 16 bits (DOS)');
  WriteLn;
  WriteLn('  Instructions analysees  : ', InstrCount);
  WriteLn('  Sous-programmes         : ', NbProc);
  WriteLn('  Labels generes          : ', LabelCount);
  WriteLn('  References croisees     : ', XRefCount);
  WriteLn('  Imports                 : ', ImportCount);
  WriteLn('  Exports                 : ', ExportCount);
  WriteLn('  Octets de donnees       : ', DataBytes);
  WriteLn('  Chaines ASCII           : ', StringCount);
  WriteLn('  References chaines      : ', StringRefCount);
  WriteLn('  Tables de saut          : ', JumpTblCount);
  { Taille du fichier ASM genere }
  ASMSize := GetFileSize(OutputFileName);
  If ASMSize >= 0 Then
    WriteLn('  Taille du fichier .ASM  : ', ASMSize, ' octets')
  Else
    WriteLn('  Taille du fichier .ASM  : (non disponible)');
  WriteLn('  Taille de l''image       : ', ImageSize, ' octets');
  { Statistiques detaillees en mode verbose }
  If OptVerbose Then Begin
    WriteLn;
    WriteLn('  --- Statistiques detaillees ---');
    If IsPEFile Then Begin
      WriteLn('  Point d''entree PE       : $', HexDWord(PEEntryPointRVA));
      WriteLn('  Nombre de sections      : ', SectionCount);
      WriteLn('  Relogements PE          : ', PERelocCount);
      For I := 0 To SectionCount - 1 Do Begin
        WriteLn('    Section ', GetSectionName(Sections[I]),
                ' : VA=$', HexDWord(Sections[I].VirtualAddress),
                ' Taille=$', HexDWord(Sections[I].VirtualSize));
      End;
    End Else Begin
      WriteLn('  Point d''entree DOS      : ',
              HexWord(EntryCS), ':', HexWord(EntryIP));
      WriteLn('  Pile initiale           : ',
              HexWord(EntrySS), ':', HexWord(EntrySP));
      WriteLn('  Segment de base         : ', HexWord(BaseSegment));
      WriteLn('  Relogements MZ          : ', MZRelocCount);
    End;
    WriteLn('  Labels de type PROC     : ', NbProc);
    WriteLn('  Labels de type IMPORT   : ', NbImport);
    WriteLn('  Labels de type EXPORT   : ', NbExport);
  End;
  WriteLn;
  WriteLn('============================================================');
End;

{ ============================================================
  ANALYSE DES OPTIONS DE LIGNE DE COMMANDE
  ============================================================ }

Procedure ShowHelp;Begin
 WriteLn('DISOVL v', DISOVL_VERSION, ' - Cette commande permet de desassembler un overlay DOS (.OVL)');
 WriteLn('DISOVL desassemble un fichier .OVL (en-tete MZ, charge via INT 21h');
 WriteLn('AH=4Bh AL=03h "Load Overlay") avec le maximum d''annotations utiles');
 WriteLn('en retro-ingenierie : sous-fonctions AH/AX connues des INT 21h/2Fh/');
 WriteLn('15h/1Ah/31h, ports d''E/S materiels courants (CMOS/8042/A20/PIC/PIT)');
 WriteLn('pour IN/OUT, et signalement special des instructions mode protege');
 WriteLn('(LGDT/SGDT/LIDT/SIDT/SMSW/LMSW/MOV CRn).');
 WriteLn;
 WriteLn('Syntaxe : DISOVL [options] fichier.ovl');
 WriteLn;
 WriteLn('Options :');
 WriteLn('  -o file       Nom du fichier .ASM de sortie (defaut: meme nom, .ASM)');
 WriteLn('  -loadseg:XXXX Segment de chargement affiche, en hexadecimal (cosmetique');
 WriteLn('                uniquement - voir le commentaire d''en-tete du .ASM genere ;');
 WriteLn('                defaut 1000h). Un VRAI chargeur d''overlay le fournit lui-');
 WriteLn('                meme au moment du chargement, il n''est PAS dans le fichier.');
 WriteLn('  -reloc:XXXX   Facteur de relogement, en hexadecimal : ajoute a chaque mot');
 WriteLn('                fixe par la table de relogement MZ (defaut : meme valeur que');
 WriteLn('                -loadseg, cas le plus courant, mais un VRAI chargeur peut les');
 WriteLn('                fournir INDEPENDAMMENT - voir Ralf Brown Interrupt List).');
 WriteLn('  -entry:XXXX   Offset de depart (hexadecimal, relatif au debut de l''overlay)');
 WriteLn('                pour l''analyse de flux de controle (defaut 0 - un .OVL n''a');
 WriteLn('                pas de point d''entree exploitable dans son en-tete, CS:IP y');
 WriteLn('                est ignore par un vrai chargeur). Le CODE EMIS couvre quand');
 WriteLn('                meme TOUJOURS l''image entiere, quel que soit -entry: - cette');
 WriteLn('                option affecte seulement la discrimination code/donnees.');
 WriteLn('  -map file     Charger un fichier .MAP pour les symboles');
 WriteLn('  -v            Mode verbose');
 WriteLn('  -hex          Inclure les octets hex en commentaire');
 WriteLn('  -h            Afficher cette aide');
 Halt(0);
End;

Procedure ParseArgs;
Var
 I : Integer;
 Arg : TString;
 HexPart : TString;
 HexVal  : LongInt;
 HexCode : Integer;
 OptRelocSet : Boolean;
Begin
 InputFileName := '';
 OutputFileName := '';
 MapFileName := '';
 OptVerbose := False;
 OptHex := False;
 OptUseMap := False;
 OvlLoadSegment := $1000;
 BaseSegment := 0;
 OvlEntryOfs := 0;
 OptRelocSet := False;
 I := 1;
 While I <= ParamCount Do Begin
  Arg := ParamStr(I);
  If (Arg = '-v') Then
   OptVerbose := True
  Else If (Arg = '-hex') Then
   OptHex := True
  Else If (Arg = '-h') Or (Arg = '-?') Or (Arg = '--help') Then
   ShowHelp
  Else If (Arg = '-o') And (I < ParamCount) Then Begin
   Inc(I);
   OutputFileName := ParamStr(I);
  End
  Else If (Arg = '-map') And (I < ParamCount) Then Begin
   Inc(I);
   MapFileName := ParamStr(I);
   OptUseMap := True;
  End
  Else If Copy(Arg, 1, 9) = '-loadseg:' Then Begin
   HexPart := Copy(Arg, 10, Length(Arg));
   Val('$' + HexPart, HexVal, HexCode);
   If HexCode = 0 Then OvlLoadSegment := Word(HexVal)
   Else Begin WriteLn('Erreur : valeur hexadecimale invalide pour -loadseg: ', HexPart); Halt(1); End;
  End
  Else If Copy(Arg, 1, 7) = '-reloc:' Then Begin
   HexPart := Copy(Arg, 8, Length(Arg));
   Val('$' + HexPart, HexVal, HexCode);
   If HexCode = 0 Then Begin BaseSegment := Word(HexVal); OptRelocSet := True; End
   Else Begin WriteLn('Erreur : valeur hexadecimale invalide pour -reloc: ', HexPart); Halt(1); End;
  End
  Else If Copy(Arg, 1, 7) = '-entry:' Then Begin
   HexPart := Copy(Arg, 8, Length(Arg));
   Val('$' + HexPart, HexVal, HexCode);
   If HexCode = 0 Then OvlEntryOfs := HexVal
   Else Begin WriteLn('Erreur : valeur hexadecimale invalide pour -entry: ', HexPart); Halt(1); End;
  End
  Else If (Arg[1] <> '-') And (InputFileName = '') Then
   InputFileName := Arg
  Else Begin
   WriteLn('Option inconnue : ', Arg);
   Halt(1);
  End;
  Inc(I);
 End;
 { Sans -reloc: explicite, aligner le facteur de relogement sur le segment }
 { de chargement - c'est le cas le plus courant en pratique (voir -h). }
 If Not OptRelocSet Then BaseSegment := OvlLoadSegment;
 If InputFileName = '' Then Begin
  WriteLn('Erreur : aucun fichier d''entree specifie.');
  WriteLn('Utilisez DISOVL -h pour l''aide.');
  Halt(1);
 End;
 If OutputFileName = '' Then
  OutputFileName := ChangeFileExt(InputFileName, '.ASM');
End;

{ ============================================================
  LECTURE DE L'ENTETE MZ
  ============================================================ }

Function ReadMZHeader : Boolean;
Var
 BytesRead : Word;
Begin
 ReadMZHeader := False;
 Assign(InFile, InputFileName);
 {$I-}
 Reset(InFile, 1);
 {$I+}
 If IOResult <> 0 Then Begin
  WriteLn('Erreur : impossible d''ouvrir ', InputFileName);
  Exit;
 End;
 {$I-}
 BlockRead(InFile, MZHeader, SizeOf(TMZHeader), BytesRead);
 {$I+}
 If (IOResult <> 0) Or (BytesRead < SizeOf(TMZHeader)) Then Begin
  WriteLn('Erreur : fichier trop petit pour un entete MZ.');
  Close(InFile);
  Exit;
 End;
 If (MZHeader.Signature <> MZ_SIGNATURE) And
    (MZHeader.Signature <> ZM_SIGNATURE) Then Begin
  WriteLn('Erreur : signature MZ invalide ($', HexWord(MZHeader.Signature), ').');
  Close(InFile);
  Exit;
 End;
 ReadMZHeader := True;
End;

{ ============================================================
  LECTURE DE LA TABLE DE RELOGEMENT MZ (DOS)
  ============================================================ }

Function ReadMZRelocs : Boolean;
Var
 I         : LongInt;
 BytesRead : Word;
Begin
 ReadMZRelocs := False;
 MZRelocCount := 0;
 { Verifier qu'il y a des relogements }
 If MZHeader.RelocCount = 0 Then Begin
  ReadMZRelocs := True;
  Exit;
 End;
 { Limiter au maximum }
 If LongInt(MZHeader.RelocCount) > MAX_RELOCS Then Begin
  WriteLn('Erreur : trop de relogements MZ (', MZHeader.RelocCount, ', max=', MAX_RELOCS, ').');
  Exit;
 End;
 { Positionner a l'offset de la table de relogement }
 Seek(InFile, MZHeader.RelocOfs);
 If IOResult <> 0 Then Begin
  WriteLn('Erreur : impossible de positionner a la table de relogement ($', HexWord(MZHeader.RelocOfs), ').');
  Exit;
 End;
 { Lire les entrees de relogement (4 octets chacune : offset + segment) }
 For I := 0 To MZHeader.RelocCount - 1 Do Begin
  BlockRead(InFile, MZRelocs[I], SizeOf(TMZReloc), BytesRead);
  If (IOResult <> 0) Or (BytesRead <> SizeOf(TMZReloc)) Then Begin
   WriteLn('Erreur : lecture relogement MZ #', I, ' echouee.');
   Exit;
  End;
 End;
 MZRelocCount := MZHeader.RelocCount;
 ReadMZRelocs := True;
End;

{ ============================================================
  APPLICATION DES RELOGEMENTS MZ (DOS)
  ============================================================ }

Function ApplyMZRelocs : Boolean;
Var
 I        : LongInt;
 Addr     : LongInt;
 OldWord  : Word;
 NewWord  : Word;
 FlagSize : LongInt;
Begin
 ApplyMZRelocs := False;
 { Calculer la taille du tableau de flags (1 octet par position de mot possible) }
 FlagSize := ImageSize;
 GetMem(RelocFlags, FlagSize);
 If RelocFlags = Nil Then Begin
  WriteLn('Erreur : memoire insuffisante pour les flags de relogement.');
  Exit;
 End;
 FillChar(RelocFlags^, FlagSize, 0);
 { Appliquer chaque relogement }
 For I := 0 To MZRelocCount - 1 Do Begin
  { Calculer l'adresse lineaire dans l'image }
  Addr := LongInt(MZRelocs[I].Segment) * 16 + LongInt(MZRelocs[I].Offset);
  { Verifier les limites (il faut 2 octets pour un mot) }
  If (Addr < 0) Or (Addr + 1 >= ImageSize) Then Begin
   If OptVerbose Then
    WriteLn('  Avertissement : relogement #', I, ' hors limites ($', HexDWord(Addr), ').');
   Continue;
  End;
  { Lire le mot a l'adresse indiquee }
  OldWord := ImageBuffer^[Addr] Or (Word(ImageBuffer^[Addr + 1]) Shl 8);
  { Ajouter le segment de base }
  NewWord := OldWord + BaseSegment;
  { Ecrire le mot modifie }
  ImageBuffer^[Addr] := Byte(NewWord And $FF);
  ImageBuffer^[Addr + 1] := Byte((NewWord Shr 8) And $FF);
  { Marquer l'adresse comme relogee }
  RelocFlags^[Addr] := 1;
 End;
 ApplyMZRelocs := True;
End;

{ ============================================================
  CHARGEMENT DU PROGRAMME DOS 16 BITS
  ============================================================ }

Function LoadDOS16Image : Boolean;
Var
 HeaderBytes : LongInt;
 FileBytes   : LongInt;
 BytesRead   : Word;
 Remaining   : LongInt;
 Offset      : LongInt;
 ChunkSize   : Word;
Begin
 LoadDOS16Image := False;
 { Calculer la taille de l'entete en octets }
 HeaderBytes := LongInt(MZHeader.HeaderSize) * 16;
 { Calculer la taille totale du fichier a partir des champs MZ }
 If MZHeader.LastPageSize = 0 Then
  FileBytes := LongInt(MZHeader.PageCount) * 512
 Else
  FileBytes := (LongInt(MZHeader.PageCount) - 1) * 512 + MZHeader.LastPageSize;
 { Calculer la taille de l'image executable }
 ImageSize := FileBytes - HeaderBytes;
 If (ImageSize <= 0) Or (ImageSize > MAX_IMAGE_SIZE) Then Begin
  WriteLn('Erreur : taille image invalide (', ImageSize, ' octets).');
  Exit;
 End;
 { Allouer le tampon dynamique pour l'image }
 GetMem(ImageBuffer, ImageSize);
 If ImageBuffer = Nil Then Begin
  WriteLn('Erreur : memoire insuffisante pour ', ImageSize, ' octets.');
  Exit;
 End;
 { Positionner a la fin de l'entete MZ }
 Seek(InFile, HeaderBytes);
 If IOResult <> 0 Then Begin
  WriteLn('Erreur : impossible de positionner dans le fichier.');
  FreeMem(ImageBuffer, ImageSize);
  ImageBuffer := Nil;
  Exit;
 End;
 { Lire l'image en blocs de BUFFER_SIZE }
 Offset := 0;
 Remaining := ImageSize;
 While Remaining > 0 Do Begin
  If Remaining > 32768 Then
   ChunkSize := 32768
  Else
   ChunkSize := Word(Remaining);
  BlockRead(InFile, ImageBuffer^[Offset], ChunkSize, BytesRead);
  If (IOResult <> 0) Or (BytesRead = 0) Then Begin
   WriteLn('Erreur : lecture incomplete de l''image.');
   FreeMem(ImageBuffer, ImageSize);
   ImageBuffer := Nil;
   Exit;
  End;
  Inc(Offset, BytesRead);
  Dec(Remaining, BytesRead);
 End;
 { Initialiser le point d'entree CS:IP }
 EntryCS := MZHeader.InitCS;
 EntryIP := MZHeader.InitIP;
 { Initialiser la pile SS:SP }
 EntrySS := MZHeader.InitSS;
 EntrySP := MZHeader.InitSP;
 { BaseSegment N'EST PAS reinitialise ici (contrairement a DISEXE d'ou ce   }
 { code derive) : pour un .OVL, c'est le facteur de relogement fourni par  }
 { l'UTILISATEUR via -reloc: (voir ParseArgs), jamais derive du fichier    }
 { lui-meme - un vrai chargeur d'overlay le fournit lui aussi separement,  }
 { voir le commentaire de tete du programme. }
 LoadDOS16Image := True;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }

BEGIN
 { BOGUE REEL (herite de DISEXE.PAS, voir son historique 2026-08-18) :
   FileMode par defaut demande un acces en ECRITURE meme pour Reset() en
   lecture seule - echoue silencieusement ("impossible d'ouvrir") sur tout
   fichier .OVL en lecture seule (cas tres courant pour un vieux binaire
   DOS historique recupere d'un CD-ROM/d'une archive, ex. DPMI16BI.OVL
   installe en lecture seule). DISOVL ne fait jamais qu'ANALYSER le
   fichier source (jamais y ecrire), donc forcer l'acces en lecture seule
   ici est strictement correct et leve la limitation. }
 FileMode := 0;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  ShowHelp;
  Halt;
 End;
 WriteLn('DISOVL v', DISOVL_VERSION, ' (', DISOVL_DATE, ')');
 WriteLn('Desassembleur d''overlay DOS (.OVL, en-tete MZ)');
 WriteLn;
 ParseArgs;
 ImageBuffer := Nil;
 RelocFlags := Nil;
 MZRelocCount := 0;
 PERelocCount := 0;
 If OptVerbose Then Begin
  WriteLn('Fichier d''entree  : ', InputFileName);
  WriteLn('Fichier de sortie : ', OutputFileName);
  If OptUseMap Then
   WriteLn('Fichier MAP       : ', MapFileName);
 End;
 { Lecture de l'entete MZ }
 If Not ReadMZHeader Then Halt(1);
 If OptVerbose Then Begin
  WriteLn('Entete MZ valide.');
  WriteLn('  Signature     : $', HexWord(MZHeader.Signature));
  WriteLn('  Derniere page : ', MZHeader.LastPageSize, ' octets');
  WriteLn('  Pages         : ', MZHeader.PageCount);
  WriteLn('  Relogements   : ', MZHeader.RelocCount);
  WriteLn('  Taille entete : ', MZHeader.HeaderSize, ' paragraphes (', MZHeader.HeaderSize * 16, ' octets)');
  WriteLn('  MINALLOC      : ', MZHeader.MinAlloc, ' paragraphes');
  WriteLn('  MAXALLOC      : ', MZHeader.MaxAlloc, ' paragraphes');
  WriteLn('  SS:SP initial : ', HexWord(MZHeader.InitSS), ':', HexWord(MZHeader.InitSP));
  WriteLn('  Checksum      : $', HexWord(MZHeader.Checksum));
  WriteLn('  CS:IP initial : ', HexWord(MZHeader.InitCS), ':', HexWord(MZHeader.InitIP));
  WriteLn('  Offset reloc  : $', HexWord(MZHeader.RelocOfs));
  WriteLn('  Overlay       : ', MZHeader.OverlayNum);
  If MZHeader.PageCount > 0 Then Begin
   If MZHeader.LastPageSize = 0 Then
    WriteLn('  Taille image  : ', LongInt(MZHeader.PageCount) * 512 - LongInt(MZHeader.HeaderSize) * 16, ' octets')
   Else
    WriteLn('  Taille image  : ', (LongInt(MZHeader.PageCount) - 1) * 512 + MZHeader.LastPageSize - LongInt(MZHeader.HeaderSize) * 16, ' octets');
  End;
 End;
 { Un .OVL est toujours un en-tete MZ - jamais de detection/chemin PE ici. }
 IsPEFile := False;
 WriteLn('Overlay DOS (en-tete MZ) - segment de chargement affiche = ',
         HexWord(OvlLoadSegment), 'h, facteur de relogement = ',
         HexWord(BaseSegment), 'h.');
 If (MZHeader.InitCS <> 0) Or (MZHeader.InitIP <> 0) Then
  WriteLn('Avertissement : CS:IP de l''en-tete = ', HexWord(MZHeader.InitCS),
          ':', HexWord(MZHeader.InitIP),
          ' - un VRAI chargeur d''overlay l''IGNORE (voir -h et WriteASMHeader).');
 { Lecture de la table de relogement MZ }
 If Not ReadMZRelocs Then Begin
  Close(InFile);
  Halt(1);
 End;
 { Chargement de l'image DOS en memoire }
 If Not LoadDOS16Image Then Begin
  Close(InFile);
  Halt(1);
 End;
 If OptVerbose Then Begin
  WriteLn('Image overlay chargee : ', ImageSize, ' octets.');
  WriteLn('  CS:IP d''en-tete (ignore par un vrai chargeur) : ',
          HexWord(EntryCS), ':', HexWord(EntryIP));
  WriteLn('  SS:SP d''en-tete (ignore par un vrai chargeur) : ',
          HexWord(EntrySS), ':', HexWord(EntrySP));
  WriteLn('  Segment de chargement (affichage, -loadseg:)  : ', HexWord(OvlLoadSegment));
  WriteLn('  Facteur de relogement (-reloc:)               : ', HexWord(BaseSegment));
  WriteLn('  Offset de depart pour l''analyse (-entry:)     : $', HexDWord(OvlEntryOfs));
 End;
 { Application des relogements MZ }
 If MZRelocCount > 0 Then Begin
  If Not ApplyMZRelocs Then Begin
   WriteLn('Erreur : application des relogements MZ echouee.');
   Close(InFile);
   Halt(1);
  End;
 End;
 If OptVerbose Then Begin
  WriteLn('Relogements MZ : ', MZRelocCount, ' entrees.');
  If MZRelocCount > 0 Then Begin
   For IterI := 0 To MZRelocCount - 1 Do Begin
    WriteLn('  [', IterI, '] ', HexWord(MZRelocs[IterI].Segment), ':',
            HexWord(MZRelocs[IterI].Offset),
            '  -> offset $', HexDWord(LongInt(MZRelocs[IterI].Segment) * 16 +
                                      LongInt(MZRelocs[IterI].Offset)));
   End;
  End;
 End;
 Close(InFile);
 { Initialiser les compteurs }
 LabelCount := 0;
 XRefCount := 0;
 InstrCount := 0;
 ProcCount := 0;
 DataBytes := 0;
 ByteFlags := Nil;
 WriteLn;
 WriteLn('Analyse du flux de controle...');
 { Overlay DOS : desassembler a partir de -entry: (defaut 0 - voir le
   commentaire de tete du programme : un .OVL n'a pas de CS:IP exploitable). }
 AnalyzeControlFlow(OvlEntryOfs, ImageSize, False);
 If OptVerbose Then Begin
  WriteLn('Analyse du flux de controle terminee :');
  WriteLn('  Instructions analysees  : ', InstrCount);
  WriteLn('  Sous-programmes trouves : ', ProcCount);
  WriteLn('  Labels generes          : ', LabelCount);
  WriteLn('  References croisees     : ', XRefCount);
 End;
 { Detection des procedures, fonctions et points d'entree }
 WriteLn('Detection des procedures...');
 DetectProcedures(OvlEntryOfs, ImageSize, False);
 If OptVerbose Then Begin
  If LabelCount > 0 Then Begin
   WriteLn('Labels (apres detection des procedures) :');
   For IterI := 0 To LabelCount - 1 Do Begin
    Write('  ', Labels[IterI].Name, ' @ $');
    If IsPEFile Then
     Write(HexDWord(Labels[IterI].Address))
    Else
     Write(HexWord(Word(Labels[IterI].Address)));
    If Labels[IterI].IsProc Then Write(' [PROC]');
    If Labels[IterI].IsImport Then Write(' [IMPORT]');
    If Labels[IterI].IsExport Then Write(' [EXPORT]');
    WriteLn;
   End;
  End;
  If XRefCount > 0 Then Begin
   WriteLn('References croisees (', XRefCount, ') :');
   For IterI := 0 To XRefCount - 1 Do Begin
    Write('  $');
    If IsPEFile Then
     Write(HexDWord(XRefs[IterI].FromAddr), ' -> $', HexDWord(XRefs[IterI].ToAddr))
    Else
     Write(HexWord(Word(XRefs[IterI].FromAddr)), ' -> $', HexWord(Word(XRefs[IterI].ToAddr)));
    If XRefs[IterI].IsCall Then Write(' [CALL]') Else Write(' [JMP]');
    WriteLn;
   End;
  End;
 End;
 { Discrimination code/donnees }
 DiscriminateCodeData(OvlEntryOfs, ImageSize, False);
 If OptVerbose And IsPEFile Then Begin
  WriteLn('Repartition par section :');
  For IterI := 0 To SectionCount - 1 Do Begin
   WriteLn('  ', GetSectionName(Sections[IterI]), ' : ',
           SectionFlagsStr(Sections[IterI].Characteristics));
  End;
 End;
 { Etiquettes automatiques et table des symboles }
 If IsPEFile Then
  BuildSymbolTable(True)
 Else
  BuildSymbolTable(False);
 { Generation du fichier .ASM : en-tete, directives et segments }
 GenerateASMHeader;
 { Verification finale et rapport }
 VerifyASMCoherence;
 DisplayFinalReport;
 WriteLn('Termine.');
 { Liberation de la memoire }
 If (ByteFlags <> Nil) And (ImageSize > 0) Then
  FreeMem(ByteFlags, ImageSize);
 If (RelocFlags <> Nil) And (ImageSize > 0) Then
  FreeMem(RelocFlags, ImageSize);
 If (ImageBuffer <> Nil) And (ImageSize > 0) Then
  FreeMem(ImageBuffer, ImageSize);
END.
