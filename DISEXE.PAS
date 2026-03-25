{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Desassembleur de fichiers .EXE (MZ DOS 16 bits et PE Windows 32 bits)
                genere un fichier de sortie .ASM (assembleur 8086, 80286, 80386, ...)
}

{ TODO - Liste des 25 points a implementer pour le desassembleur EXE (MZ/PE) :

  1.  [IMPLEMENTE] Infrastructure, options de ligne de commande et constantes globales.
      Programme principal DISEXE en Turbo Pascal / Free Pascal.
      Analyse des options : nom du fichier .EXE en entree, nom du
      fichier .ASM en sortie (par defaut meme nom avec extension .ASM),
      options -16 (forcer mode 16 bits), -32 (forcer mode 32 bits),
      -map (charger un fichier .MAP pour les symboles), -v (verbose),
      -hex (inclure les octets hexadecimaux en commentaire).
      Constantes de dimensionnement : MAX_SECTIONS, MAX_IMPORTS,
      MAX_EXPORTS, MAX_RELOCS, MAX_LABELS, MAX_XREFS, BUFFER_SIZE.
      Fonctions utilitaires : UpCaseStr, HexByte, HexWord, HexDWord,
      IntToStr, FileExists, ChangeFileExt.

  2.  [IMPLEMENTE] Lecture et validation de l'entete MZ (DOS EXE header).
      Lire les 28 octets de l'entete MZ : signature (MZ ou ZM),
      nombre d'octets dans la derniere page, nombre de pages de
      512 octets, nombre d'entrees de relogement, taille de l'entete
      en paragraphes, MINALLOC, MAXALLOC, SS:SP initial, checksum,
      CS:IP initial (point d'entree), offset de la table de relogement,
      numero d'overlay. Valider la signature $5A4D (MZ).
      Detecter la presence d'un entete PE via le champ a l'offset
      $3C (e_lfanew) pointant vers la signature PE.

  3.  [IMPLEMENTE] Chargement du programme DOS 16 bits en memoire.
      Si le fichier est un EXE DOS pur (pas de signature PE), charger
      l'image executable en memoire a partir de la fin de l'entete MZ
      (taille entete * 16 octets). Calculer la taille de l'image :
      (nombre de pages - 1) * 512 + octets derniere page - taille
      entete * 16. Allouer un tampon dynamique pour l'image.
      Initialiser CS:IP et SS:SP a partir de l'entete MZ.
      Stocker les segments de base pour le relogement.

  4.  [IMPLEMENTE] Lecture et validation des entetes PE (Portable Executable).
      Si e_lfanew pointe vers une signature PE ($00004550), lire
      IMAGE_FILE_HEADER (20 octets) : Machine ($014C = i386),
      NumberOfSections, TimeDateStamp, SizeOfOptionalHeader,
      Characteristics. Puis lire IMAGE_OPTIONAL_HEADER32 :
      Magic ($010B = PE32), AddressOfEntryPoint, ImageBase,
      SectionAlignment, FileAlignment, SizeOfImage,
      SizeOfHeaders, NumberOfRvaAndSizes, DataDirectory[16].
      Valider Machine=$014C et Magic=$010B pour PE 32 bits.

  5.  [IMPLEMENTE] Lecture des sections PE et chargement en memoire.
      Lire chaque IMAGE_SECTION_HEADER (40 octets) : Name[8],
      VirtualSize, VirtualAddress, SizeOfRawData,
      PointerToRawData, Characteristics (flags executable,
      lisible, inscriptible, contient du code, contient des
      donnees initialisees/non-initialisees).
      Charger chaque section dans le tampon memoire a son
      VirtualAddress relatif a ImageBase. Identifier les
      sections .text, .data, .rdata, .bss, .idata, .edata,
      .reloc par leur nom et/ou leurs flags.

  6.  [IMPLEMENTE] Traitement de la table d'importation PE (Import Directory).
      Lire la Import Directory Table via DataDirectory[1] :
      chaque IMAGE_IMPORT_DESCRIPTOR contient OriginalFirstThunk,
      Name (RVA du nom de la DLL), FirstThunk (RVA de la IAT).
      Pour chaque DLL importee, lire les IMAGE_THUNK_DATA :
      si le bit haut est a 1, importation par ordinal, sinon
      par RVA vers IMAGE_IMPORT_BY_NAME (Hint + Name).
      Stocker les noms des DLL et des fonctions importees
      avec leur adresse IAT pour generer les EXTRN dans le .ASM.

  7.  [IMPLEMENTE] Traitement de la table d'exportation PE (Export Directory).
      Lire la Export Directory Table via DataDirectory[0] :
      Name (nom de la DLL), NumberOfFunctions, NumberOfNames,
      AddressOfFunctions, AddressOfNames, AddressOfNameOrdinals.
      Pour chaque fonction exportee, stocker le nom, l'ordinal
      et le RVA. Generer des labels PUBLIC dans le .ASM pour
      chaque export. Gerer les exports par ordinal sans nom.

  8.  [IMPLEMENTE] Traitement de la table de relogement MZ (DOS).
      Lire la table de relogement DOS a partir de l'offset
      indique dans l'entete MZ. Chaque entree est un couple
      segment:offset (4 octets). Appliquer les relogements
      en ajoutant le segment de base aux mots aux positions
      indiquees. Marquer les adresses relogees pour generer
      des references symboliques segment:offset dans le .ASM
      plutot que des valeurs numeriques brutes.

  9.  [IMPLEMENTE] Traitement de la table de relogement PE (Base Relocation).
      Lire la Base Relocation Table via DataDirectory[5].
      Chaque bloc contient VirtualAddress et SizeOfBlock, suivi
      d'entrees de 16 bits (4 bits type + 12 bits offset).
      Types supportes : IMAGE_REL_BASED_ABSOLUTE (padding),
      IMAGE_REL_BASED_HIGHLOW (ajuster un DWORD 32 bits).
      Marquer les adresses relogees pour generer des
      references symboliques dans le .ASM.

  10. [IMPLEMENTE] Table des opcodes et mnemoniques 8086/8088.
      Definir les 256 opcodes de base du 8086/8088 avec pour
      chacun : le mnemonique (MOV, ADD, SUB, CMP, JMP, CALL,
      RET, PUSH, POP, INT, etc.), la taille de base, le type
      d'operandes (reg, mem, imm, rel8, rel16), le besoin
      d'un octet ModR/M. Inclure les opcodes du coprocesseur
      x87 (ESC, FWAIT). Definir les noms des registres 8 bits
      (AL,CL,DL,BL,AH,CH,DH,BH), 16 bits (AX,CX,DX,BX,
      SP,BP,SI,DI) et de segment (ES,CS,SS,DS).

  11. [IMPLEMENTE] Table des opcodes et mnemoniques 80286.
      Etendre la table avec les instructions ajoutees par le
      80286 : BOUND, ENTER, LEAVE, INS, OUTS, PUSHA, POPA,
      PUSH imm8/imm16, IMUL imm, SHL/SHR/SAR/ROL/ROR/RCL/RCR
      avec operande immediat. Opcodes etendus 0Fh du 80286 :
      LGDT, SGDT, LIDT, SIDT, LLDT, SLDT, LTR, STR, LMSW,
      SMSW, CLTS, LAR, LSL, VERR, VERW.
      Instructions protegees pour le mode protege.

  12. [IMPLEMENTE] Table des opcodes et mnemoniques 80386 (32 bits).
      Etendre la table pour le mode 32 bits : prefixes de
      taille d'operande (66h) et de taille d'adresse (67h),
      registres 32 bits (EAX,ECX,EDX,EBX,ESP,EBP,ESI,EDI),
      registres de segment supplementaires (FS, GS),
      instructions 32 bits (MOVZX, MOVSX, CWDE, CDQ, BSWAP,
      XADD, CMPXCHG, SETcc, CMOVcc, BSF, BSR, BT, BTS,
      BTR, BTC, SHLD, SHRD, IMUL reg,r/m,imm).
      Gerer le basculement 16/32 bits selon le mode.

  13. [IMPLEMENTE] Decodage des modes d'adressage ModR/M 16 bits.
      Decoder l'octet ModR/M pour le mode 16 bits :
      mod (2 bits), reg (3 bits), r/m (3 bits).
      8 modes effectifs : [BX+SI], [BX+DI], [BP+SI], [BP+DI],
      [SI], [DI], [BP] (sauf mod=00 r/m=110 -> disp16), [BX].
      Avec mod=01 : deplacement 8 bits signe.
      Avec mod=10 : deplacement 16 bits.
      Avec mod=11 : registre direct.
      Generer la chaine d'operande correspondante pour le .ASM.

  14. [IMPLEMENTE] Decodage des modes d'adressage ModR/M et SIB 32 bits.
      Decoder l'octet ModR/M pour le mode 32 bits :
      si r/m=100 (ESP), lire l'octet SIB : scale (2 bits),
      index (3 bits), base (3 bits). Formule d'adresse :
      [base + index*scale + deplacement].
      Scale = 1, 2, 4 ou 8. Base=101 avec mod=00 -> disp32.
      Index=100 -> pas d'index. Generer la chaine d'operande
      avec les crochets, registres et facteur d'echelle.

  15. [IMPLEMENTE] Decodage des prefixes d'instructions.
      Gerer les prefixes avant chaque instruction : segment
      override (26h=ES:, 2Eh=CS:, 36h=SS:, 3Eh=DS:, 64h=FS:,
      65h=GS:), LOCK (F0h), REP/REPE (F3h), REPNE (F2h),
      taille d'operande (66h), taille d'adresse (67h).
      Un meme opcode peut etre precede de plusieurs prefixes.
      Le prefix 66h bascule entre operandes 16 et 32 bits.
      Le prefix 67h bascule entre adresses 16 et 32 bits.
      Accumuler les prefixes avant le decodage de l'opcode.

  16. [IMPLEMENTE] Decodage des opcodes etendus (0Fh) et instructions avancees.
      Decoder les opcodes a deux octets (0Fh + second octet) :
      Jcc near (80h-8Fh), SETcc (90h-9Fh), CMOVcc (40h-4Fh),
      MOVZX (B6h/B7h), MOVSX (BEh/BFh), BSF (BCh), BSR (BDh),
      BT/BTS/BTR/BTC (A3h/ABh/B3h/BBh/BAh),
      SHLD (A4h/A5h), SHRD (ACh/ADh),
      IMUL r,r/m (AFh), XADD (C0h/C1h),
      CMPXCHG (B0h/B1h), BSWAP (C8h-CFh).
      Instructions systeme : INVD, WBINVD, CPUID, RDTSC, etc.

  17. [IMPLEMENTE] Analyse du flux de controle et references croisees.
      Premiere passe de desassemblage lineaire pour identifier
      les instructions de saut (JMP, Jcc, LOOP), d'appel (CALL)
      et de retour (RET, RETF, IRET). Pour chaque instruction
      de branchement, calculer l'adresse cible et l'ajouter
      a la table des references croisees (XREF). Construire
      un graphe de flux de controle simplifie pour distinguer
      les blocs de code accessibles des zones potentiellement
      non-code (donnees intercalees, padding).

  18. [IMPLEMENTE] Detection des procedures, fonctions et points d'entree.
      A partir du point d'entree (CS:IP pour MZ, AddressOfEntryPoint
      pour PE) et des adresses cibles de CALL, identifier les
      debuts de sous-programmes. Attribuer un label automatique
      a chaque sous-programme (sub_XXXX pour MZ, sub_XXXXXXXX pour
      PE). Detecter les patterns de prologue (PUSH BP / MOV BP,SP
      pour 16 bits, PUSH EBP / MOV EBP,ESP pour 32 bits) et
      d'epilogue (POP BP / RET, LEAVE / RET). Marquer les
      fonctions importees et exportees avec leurs vrais noms.

  19. [IMPLEMENTE] Discrimination code/donnees dans les sections executables.
      Utiliser les informations de flux de controle (TODO 17)
      pour separer le code des donnees dans les sections
      executables. Les octets non atteints par le parcours du
      flux sont marques comme donnees (DB). Detecter les
      tables de saut (switch/case), les chaines de caracteres
      (ASCII terminee par 0), les tables de pointeurs et les
      constantes numeriques. Pour les fichiers PE, utiliser
      les flags de section pour distinguer .text (code) de
      .data et .rdata (donnees).

  20. [IMPLEMENTE] Generation du fichier .ASM : en-tete, directives et segments.
      Emettre l'en-tete du fichier .ASM avec des commentaires
      (nom du fichier source, date, outil). Pour les EXE DOS
      16 bits : .MODEL SMALL/MEDIUM/LARGE, .STACK, SEGMENT/ENDS.
      Pour les PE 32 bits : .386, .MODEL FLAT, STDCALL,
      .CODE/.DATA/.CONST. Emettre les directives EXTRN pour
      les fonctions importees et PUBLIC pour les exports.
      Definir les SEGMENT avec les noms et attributs corrects.

  21. Generation du fichier .ASM : section de code (instructions).
      Emettre le code desassemble instruction par instruction
      dans le segment de code. Format : label (si reference),
      tabulation, mnemonique, operandes. Inserer des lignes
      vides entre les sous-programmes. Generer les labels de
      saut (loc_XXXX, @@loop, etc.) aux adresses cibles.
      Si l'option -hex est active, ajouter en commentaire les
      octets hexadecimaux de chaque instruction.
      Gerer la largeur des operandes (BYTE PTR, WORD PTR,
      DWORD PTR) quand elle est ambigue.

  22. Generation du fichier .ASM : section de donnees (DB, DW, DD).
      Emettre les donnees dans les segments de donnees avec les
      directives DB, DW, DD selon le contexte. Detecter les
      chaines ASCII et les emettre avec DB 'texte',0.
      Regrouper les octets consecutifs non-chaine en lignes
      de DB xx,xx,xx,... (16 octets max par ligne). Emettre
      les donnees non-initialisees (.bss) avec des directives
      DB ? ou DUP(?). Generer des labels pour les variables
      referencees (dword_XXXX, byte_XXXX, aString_XXXX).

  23. Etiquettes automatiques et table des symboles.
      Gerer une table de symboles unifiant les labels generes
      automatiquement : sub_XXXX (sous-programmes), loc_XXXX
      (cibles de saut), dword_XXXX / word_XXXX / byte_XXXX
      (variables), aString_XXXX (chaines), off_XXXX (offsets).
      Pour les imports PE, utiliser les noms reels des fonctions
      (ex: _ExitProcess@4). Pour les exports, utiliser les noms
      exportes. Si un fichier .MAP est fourni (-map), charger
      les symboles et les utiliser a la place des labels generes.

  24. Commentaires et annotations dans le fichier .ASM.
      Generer des commentaires automatiques pour les appels
      systeme connus : INT 21h (fonctions DOS), INT 10h (BIOS
      video), INT 16h (BIOS clavier), INT 13h (BIOS disque).
      Pour les PE, annoter les appels aux fonctions importees
      (KERNEL32, USER32, GDI32, etc.) avec le nom de la fonction.
      Ajouter des commentaires pour les constantes connues
      (codes d'erreur Windows, flags de fichier, etc.).
      Inserer des separateurs visuels entre les sous-programmes.

  25. Options de sortie, verification finale et rapport.
      Verifier la coherence du fichier .ASM genere : toutes les
      references croisees sont resolues, les labels sont uniques,
      les segments sont correctement fermes. Afficher un rapport
      final : nombre d'instructions desassemblees, nombre de
      sous-programmes detectes, nombre de labels generes, nombre
      d'imports/exports, nombre d'octets de donnees, taille du
      fichier .ASM. Si -v est active, afficher des statistiques
      detaillees. Gerer le code de retour (0=succes, 1=erreur).
}

Program DISEXE;

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
  DISEXE_VERSION = '1.0';
  DISEXE_DATE    = '2026-03-24';

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
  TByteArray = Array[0..0] Of Byte;
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
  BaseSegment    : Word;        { segment de base pour relogement }
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

  { Discrimination code/donnees (TODO 19) }
  ByteFlags      : PByteArray; { 1 octet par octet de l'image : BF_xxx }
  StringCount    : LongInt;  { nombre de chaines ASCII detectees }
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
  DECODAGE MODR/M 16 BITS (TODO 13)
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
  DECODAGE MODR/M ET SIB 32 BITS (TODO 14)
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
  DECODAGE DES PREFIXES D'INSTRUCTIONS (TODO 15)
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
  If PFX.HasSegOverride Then
    S := S + PFX.SegOverrideStr;
  PrefixToStr := S;
End;

{ ============================================================
  DECODAGE DES OPCODES ETENDUS 0Fh (TODO 16)
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
  ANALYSE DU FLUX DE CONTROLE ET REFERENCES CROISEES (TODO 17)
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

{ ByteFlags - Marqueurs pour la discrimination code/donnees (TODO 19) }
  BF_UNKNOWN = 0;  { octet non classifie }
  BF_CODE    = 1;  { octet d'instruction }
  BF_DATA    = 2;  { octet de donnees (DB) }
  BF_STRING  = 3;  { octet de chaine ASCII }
  BF_JUMPTBL = 4;  { entree de table de saut }
  BF_PADDING = 5;  { padding/alignement (NOP, INT3, 00) }

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
  DETECTION DES PROCEDURES, FONCTIONS ET POINTS D'ENTREE (TODO 18)
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
  ISize      : Integer;
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

  { Passe 2 : Scanner le code pour des prologues non encore detectes.
    On cherche le pattern PUSH BP/EBP + MOV BP/EBP,SP/ESP a chaque
    frontiere d'instruction. Les adresses ou ce pattern apparait et
    qui ne sont pas deja des labels sont ajoutees comme procedures. }
  CurOffset := StartOffset;
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

    { Avancer instruction par instruction }
    ISize := ComputeInstrSize(CurOffset, Mode32);
    If ISize <= 0 Then ISize := 1;
    CurOffset := CurOffset + ISize;
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
  DISCRIMINATION CODE/DONNEES (TODO 19)
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
  Utilise les labels generes par AnalyzeControlFlow (TODO 17) comme
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
Begin
  { Passe 1 : Tracer le code depuis chaque label connu }
  For I := 0 To LabelCount - 1 Do Begin
    CurOffset := Labels[I].Address;
    { Verifier que le label est dans les bornes }
    If (CurOffset < 0) Or (CurOffset >= EndOffset) Then Continue;
    If CurOffset >= ImageSize Then Continue;
    { Ne pas retracer si deja marque comme code }
    If ByteFlags^[CurOffset] = BF_CODE Then Continue;

    BadCount := 0;
    While CurOffset < EndOffset Do Begin
      If CurOffset >= ImageSize Then Break;
      If CurOffset < 0 Then Break;
      { Si deja marque comme code, le bloc a deja ete trace }
      If ByteFlags^[CurOffset] = BF_CODE Then Break;

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
      If (BType = BT_JMP_REL8) Or (BType = BT_JMP_REL) Or
         (BType = BT_JMP_FAR) Or (BType = BT_JMP_IND) Or
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
        { Verifier que l'adresse pointe vers un label connu }
        If FindLabel(Addr) >= 0 Then Begin
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
       (ByteFlags^[I] = BF_JUMPTBL) Then
      Inc(DataBytes);
  End;
End;

{ DiscriminateCodeData - Procedure principale pour la discrimination
  code/donnees (TODO 19). Orchestre les differentes passes. }
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

  { Passe 4 : Detecter les tables de saut }
  DetectJumpTables(Mode32);

  { Passe 5 : Marquer les zones restantes comme donnees }
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
  WriteLn('  Tables de saut      : ', JumpTblCount);
  WriteLn('  Octets de padding   : ', PadBytes);
End;

{ ============================================================
  GENERATION DU FICHIER .ASM : EN-TETE, DIRECTIVES, SEGMENTS (TODO 20)
  ============================================================ }

{ Ecrit l'en-tete du fichier .ASM avec des commentaires :
  nom du fichier source, date, outil. }
Procedure WriteASMHeader(Var F : Text);
Begin
  WriteLn(F, '; ============================================================');
  WriteLn(F, '; Fichier genere par DISEXE v', DISEXE_VERSION, ' (', DISEXE_DATE, ')');
  WriteLn(F, '; Source : ', InputFileName);
  If IsPEFile Then
    WriteLn(F, '; Format : PE 32 bits (Portable Executable)')
  Else
    WriteLn(F, '; Format : MZ DOS 16 bits');
  WriteLn(F, '; ============================================================');
  WriteLn(F);
End;

{ Ecrit les directives EXTRN pour les fonctions importees (PE). }
Procedure WriteASMExterns(Var F : Text);
Var
  I : LongInt;
Begin
  If ImportCount <= 0 Then Exit;
  WriteLn(F, '; --- Fonctions importees ---');
  For I := 0 To ImportCount - 1 Do Begin
    If Imports[I].ByOrdinal Then
      WriteLn(F, 'EXTRN ', Imports[I].DLLName, '!ord_',
              IntToStr(Imports[I].Ordinal), ':PROC')
    Else
      WriteLn(F, 'EXTRN ', Imports[I].FuncName, ':PROC');
  End;
  WriteLn(F);
End;

{ Ecrit les directives PUBLIC pour les fonctions exportees (PE). }
Procedure WriteASMPublics(Var F : Text);
Var
  I : LongInt;
Begin
  If ExportCount <= 0 Then Exit;
  WriteLn(F, '; --- Fonctions exportees ---');
  For I := 0 To ExportCount - 1 Do Begin
    If ExportList[I].HasName Then
      WriteLn(F, 'PUBLIC ', ExportList[I].FuncName)
    Else
      WriteLn(F, 'PUBLIC ord_', IntToStr(ExportList[I].Ordinal));
  End;
  WriteLn(F);
End;

{ Ecrit les directives de modele et segments pour un EXE DOS 16 bits.
  Genere .MODEL SMALL, .STACK, et les directives SEGMENT/ENDS. }
Procedure WriteASMDirectivesDOS16(Var F : Text);
Begin
  WriteLn(F, '.8086');
  WriteLn(F, '.MODEL SMALL');
  WriteLn(F);
  { Pile }
  WriteLn(F, '.STACK ', HexWord(EntrySP), 'h');
  WriteLn(F);
  { Segment de donnees }
  WriteLn(F, 'DSEG SEGMENT PARA PUBLIC ''DATA''');
  WriteLn(F);
  WriteLn(F, '; (donnees a generer par TODO 22)');
  WriteLn(F);
  WriteLn(F, 'DSEG ENDS');
  WriteLn(F);
  { Segment de code }
  WriteLn(F, 'CSEG SEGMENT PARA PUBLIC ''CODE''');
  WriteLn(F, '  ASSUME CS:CSEG, DS:DSEG, SS:STACK');
  WriteLn(F);
  WriteLn(F, '; Point d''entree : ', HexWord(EntryCS), ':', HexWord(EntryIP));
  WriteLn(F);
  WriteLn(F, '; (code a generer par TODO 21)');
  WriteLn(F);
  WriteLn(F, 'CSEG ENDS');
  WriteLn(F);
  WriteLn(F, 'END');
End;

{ Ecrit les directives de modele et segments pour un PE 32 bits.
  Genere .386, .MODEL FLAT, STDCALL, et les sections. }
Procedure WriteASMDirectivesPE32(Var F : Text);
Var
  I       : Integer;
  SecName : TString;
  IsCode  : Boolean;
  IsData  : Boolean;
  IsBSS   : Boolean;
Begin
  WriteLn(F, '.386');
  WriteLn(F, '.MODEL FLAT, STDCALL');
  WriteLn(F, 'OPTION CASEMAP:NONE');
  WriteLn(F);
  { Declarations d'imports }
  WriteASMExterns(F);
  { Declarations d'exports }
  WriteASMPublics(F);
  { Generer les sections PE }
  For I := 0 To SectionCount - 1 Do Begin
    SecName := GetSectionName(Sections[I]);
    IsCode := ((Sections[I].Characteristics And IMAGE_SCN_CNT_CODE) <> 0) Or
              ((Sections[I].Characteristics And IMAGE_SCN_MEM_EXECUTE) <> 0);
    IsData := (Sections[I].Characteristics And IMAGE_SCN_CNT_INITIALIZED_DATA) <> 0;
    IsBSS  := (Sections[I].Characteristics And IMAGE_SCN_CNT_UNINITIALIZED_DATA) <> 0;
    If IsCode Then Begin
      WriteLn(F, '; --- Section ', SecName, ' (CODE) ---');
      WriteLn(F, '.CODE');
      WriteLn(F);
      WriteLn(F, '; Point d''entree RVA : ', HexDWord(PEEntryPointRVA), 'h');
      WriteLn(F, '; ImageBase : ', HexDWord(PEOptHeader.ImageBase), 'h');
      WriteLn(F);
      WriteLn(F, '; (code a generer par TODO 21)');
      WriteLn(F);
    End Else If IsBSS Then Begin
      WriteLn(F, '; --- Section ', SecName, ' (BSS) ---');
      WriteLn(F, '.DATA?');
      WriteLn(F);
      WriteLn(F, '; (donnees non-initialisees a generer par TODO 22)');
      WriteLn(F);
    End Else If IsData Then Begin
      If (Sections[I].Characteristics And IMAGE_SCN_MEM_WRITE) <> 0 Then Begin
        WriteLn(F, '; --- Section ', SecName, ' (DATA) ---');
        WriteLn(F, '.DATA');
      End Else Begin
        WriteLn(F, '; --- Section ', SecName, ' (CONST) ---');
        WriteLn(F, '.CONST');
      End;
      WriteLn(F);
      WriteLn(F, '; (donnees a generer par TODO 22)');
      WriteLn(F);
    End Else Begin
      WriteLn(F, '; --- Section ', SecName, ' (', SectionFlagsStr(Sections[I].Characteristics), ') ---');
      WriteLn(F);
    End;
  End;
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
  { Directives et segments selon le format }
  If IsPEFile Then
    WriteASMDirectivesPE32(F)
  Else
    WriteASMDirectivesDOS16(F);
  Close(F);
  WriteLn('Fichier .ASM genere avec succes.');
End;

{ ============================================================
  ANALYSE DES OPTIONS DE LIGNE DE COMMANDE
  ============================================================ }

Procedure ShowHelp;
Begin
 WriteLn('DISEXE v', DISEXE_VERSION, ' - Desassembleur EXE (MZ/PE)');
 WriteLn('Usage : DISEXE [options] fichier.exe');
 WriteLn;
 WriteLn('Options :');
 WriteLn('  -16       Forcer le mode 16 bits (DOS)');
 WriteLn('  -32       Forcer le mode 32 bits (PE)');
 WriteLn('  -o file   Nom du fichier .ASM de sortie');
 WriteLn('  -map file Charger un fichier .MAP pour les symboles');
 WriteLn('  -v        Mode verbose');
 WriteLn('  -hex      Inclure les octets hex en commentaire');
 WriteLn('  -h        Afficher cette aide');
 Halt(0);
End;

Procedure ParseArgs;
Var
 I : Integer;
 Arg : TString;
Begin
 InputFileName := '';
 OutputFileName := '';
 MapFileName := '';
 OptForce16 := False;
 OptForce32 := False;
 OptVerbose := False;
 OptHex := False;
 OptUseMap := False;
 I := 1;
 While I <= ParamCount Do Begin
  Arg := ParamStr(I);
  If (Arg = '-16') Then
   OptForce16 := True
  Else If (Arg = '-32') Then
   OptForce32 := True
  Else If (Arg = '-v') Then
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
  Else If (Arg[1] <> '-') And (InputFileName = '') Then
   InputFileName := Arg
  Else Begin
   WriteLn('Option inconnue : ', Arg);
   Halt(1);
  End;
  Inc(I);
 End;
 If InputFileName = '' Then Begin
  WriteLn('Erreur : aucun fichier d''entree specifie.');
  WriteLn('Utilisez DISEXE -h pour l''aide.');
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
 Reset(InFile, 1);
 If IOResult <> 0 Then Begin
  WriteLn('Erreur : impossible d''ouvrir ', InputFileName);
  Exit;
 End;
 BlockRead(InFile, MZHeader, SizeOf(TMZHeader), BytesRead);
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
  DETECTION PE
  ============================================================ }

Function DetectPE : Boolean;
Var
 Sig : LongInt;
 BytesRead : Word;
 PEOfs : LongInt;
Begin
 DetectPE := False;
 IsPEFile := False;
 { Lire l'offset PE a la position $3C de l'entete MZ }
 Seek(InFile, $3C);
 If IOResult <> 0 Then Exit;
 BlockRead(InFile, PEOfs, 4, BytesRead);
 If (IOResult <> 0) Or (BytesRead < 4) Then Exit;
 If (PEOfs < $40) Or (PEOfs > FileSize(InFile) - 4) Then Exit;
 PEOffset := PEOfs;
 { Verifier la signature PE }
 Seek(InFile, PEOfs);
 If IOResult <> 0 Then Exit;
 BlockRead(InFile, Sig, 4, BytesRead);
 If (IOResult <> 0) Or (BytesRead < 4) Then Exit;
 If Sig = PE_SIGNATURE Then Begin
  IsPEFile := True;
  DetectPE := True;
 End;
End;

{ ============================================================
  LECTURE DES ENTETES PE
  ============================================================ }

Function ReadPEHeaders : Boolean;
Var
 BytesRead : Word;
 I         : Integer;
 NumDirs   : LongInt;
Begin
 ReadPEHeaders := False;
 { Positionner apres la signature PE (4 octets) }
 Seek(InFile, PEOffset + 4);
 If IOResult <> 0 Then Begin
  WriteLn('Erreur : impossible de positionner a l''entete PE.');
  Exit;
 End;
 { Lire IMAGE_FILE_HEADER (20 octets) }
 BlockRead(InFile, PEFileHeader, SizeOf(TPEFileHeader), BytesRead);
 If (IOResult <> 0) Or (BytesRead < SizeOf(TPEFileHeader)) Then Begin
  WriteLn('Erreur : lecture IMAGE_FILE_HEADER echouee.');
  Exit;
 End;
 { Valider Machine = i386 }
 If PEFileHeader.Machine <> IMAGE_FILE_MACHINE_I386 Then Begin
  WriteLn('Erreur : Machine non supportee ($', HexWord(PEFileHeader.Machine),
          '). Seul i386 ($014C) est supporte.');
  Exit;
 End;
 { Lire IMAGE_OPTIONAL_HEADER32 }
 BlockRead(InFile, PEOptHeader, SizeOf(TPEOptionalHeader), BytesRead);
 If (IOResult <> 0) Or (BytesRead < SizeOf(TPEOptionalHeader)) Then Begin
  WriteLn('Erreur : lecture IMAGE_OPTIONAL_HEADER32 echouee.');
  Exit;
 End;
 { Valider Magic = PE32 }
 If PEOptHeader.Magic <> PE32_MAGIC Then Begin
  WriteLn('Erreur : Magic non supporte ($', HexWord(PEOptHeader.Magic),
          '). Seul PE32 ($010B) est supporte.');
  Exit;
 End;
 { Lire le DataDirectory }
 NumDirs := PEOptHeader.NumberOfRvaAndSizes;
 If NumDirs > MAX_DATA_DIRS Then NumDirs := MAX_DATA_DIRS;
 { Initialiser toutes les entrees a zero }
 For I := 0 To MAX_DATA_DIRS - 1 Do Begin
  DataDirs[I].VirtualAddress := 0;
  DataDirs[I].Size := 0;
 End;
 { Lire les entrees du DataDirectory }
 For I := 0 To NumDirs - 1 Do Begin
  BlockRead(InFile, DataDirs[I], SizeOf(TDataDirectory), BytesRead);
  If (IOResult <> 0) Or (BytesRead < SizeOf(TDataDirectory)) Then Begin
   WriteLn('Erreur : lecture DataDirectory[', I, '] echouee.');
   Exit;
  End;
 End;
 { Nombre de sections }
 SectionCount := PEFileHeader.NumberOfSections;
 If SectionCount > MAX_SECTIONS Then SectionCount := MAX_SECTIONS;
 ReadPEHeaders := True;
End;

{ ============================================================
  LECTURE DES SECTIONS PE
  ============================================================ }

Function ReadPESections : Boolean;
Var
 BytesRead : Word;
 I         : Integer;
 SectOfs   : LongInt;
Begin
 ReadPESections := False;
 { Les section headers se trouvent apres PE sig + FILE_HEADER + OptionalHeader }
 SectOfs := PEOffset + 4 + SizeOf(TPEFileHeader) + PEFileHeader.SizeOfOptionalHeader;
 Seek(InFile, SectOfs);
 If IOResult <> 0 Then Begin
  WriteLn('Erreur : impossible de positionner aux section headers.');
  Exit;
 End;
 { Lire chaque section header (40 octets) }
 For I := 0 To SectionCount - 1 Do Begin
  BlockRead(InFile, Sections[I], SizeOf(TPESectionHeader), BytesRead);
  If (IOResult <> 0) Or (BytesRead < SizeOf(TPESectionHeader)) Then Begin
   WriteLn('Erreur : lecture section header #', I, ' echouee.');
   Exit;
  End;
 End;
 ReadPESections := True;
End;

{ ============================================================
  CHARGEMENT DE L'IMAGE PE 32 BITS
  ============================================================ }

Function LoadPE32Image : Boolean;
Var
 BytesRead  : Word;
 I          : Integer;
 LoadSize   : LongInt;
 Remaining  : LongInt;
 FileOfs    : LongInt;
 BufOfs     : LongInt;
 ChunkSize  : Word;
Begin
 LoadPE32Image := False;
 { Taille de l'image = SizeOfImage de l'optional header }
 ImageSize := PEOptHeader.SizeOfImage;
 If (ImageSize <= 0) Or (ImageSize > MAX_IMAGE_SIZE) Then Begin
  WriteLn('Erreur : taille image PE invalide ($', HexDWord(ImageSize), ').');
  Exit;
 End;
 { Allouer le tampon et initialiser a zero }
 GetMem(ImageBuffer, ImageSize);
 If ImageBuffer = Nil Then Begin
  WriteLn('Erreur : memoire insuffisante pour ', ImageSize, ' octets.');
  Exit;
 End;
 FillChar(ImageBuffer^, ImageSize, 0);
 { Charger les entetes PE (SizeOfHeaders octets) au debut du tampon }
 LoadSize := PEOptHeader.SizeOfHeaders;
 If LoadSize > ImageSize Then LoadSize := ImageSize;
 Seek(InFile, 0);
 If IOResult <> 0 Then Begin
  FreeMem(ImageBuffer, ImageSize);
  ImageBuffer := Nil;
  Exit;
 End;
 Remaining := LoadSize;
 BufOfs := 0;
 While Remaining > 0 Do Begin
  If Remaining > 32768 Then
   ChunkSize := 32768
  Else
   ChunkSize := Word(Remaining);
  BlockRead(InFile, ImageBuffer^[BufOfs], ChunkSize, BytesRead);
  If (IOResult <> 0) Or (BytesRead = 0) Then Begin
   WriteLn('Erreur : lecture des entetes PE echouee.');
   FreeMem(ImageBuffer, ImageSize);
   ImageBuffer := Nil;
   Exit;
  End;
  Inc(BufOfs, BytesRead);
  Dec(Remaining, BytesRead);
 End;
 { Charger chaque section dans le tampon a son VirtualAddress }
 For I := 0 To SectionCount - 1 Do Begin
  If (Sections[I].SizeOfRawData > 0) And (Sections[I].PointerToRawData > 0) Then Begin
   { Verifier que la section tient dans le tampon }
   LoadSize := Sections[I].SizeOfRawData;
   If Sections[I].VirtualAddress + LoadSize > ImageSize Then
    LoadSize := ImageSize - Sections[I].VirtualAddress;
   If LoadSize <= 0 Then Continue;
   { Positionner dans le fichier }
   FileOfs := Sections[I].PointerToRawData;
   Seek(InFile, FileOfs);
   If IOResult <> 0 Then Begin
    WriteLn('Erreur : positionnement section ', GetSectionName(Sections[I]), ' echoue.');
    FreeMem(ImageBuffer, ImageSize);
    ImageBuffer := Nil;
    Exit;
   End;
   { Lire les donnees de la section }
   BufOfs := Sections[I].VirtualAddress;
   Remaining := LoadSize;
   While Remaining > 0 Do Begin
    If Remaining > 32768 Then
     ChunkSize := 32768
    Else
     ChunkSize := Word(Remaining);
    BlockRead(InFile, ImageBuffer^[BufOfs], ChunkSize, BytesRead);
    If (IOResult <> 0) Or (BytesRead = 0) Then Begin
     WriteLn('Erreur : lecture section ', GetSectionName(Sections[I]), ' incomplete.');
     FreeMem(ImageBuffer, ImageSize);
     ImageBuffer := Nil;
     Exit;
    End;
    Inc(BufOfs, BytesRead);
    Dec(Remaining, BytesRead);
   End;
  End;
 End;
 { Stocker le point d'entree PE }
 PEEntryPointRVA := PEOptHeader.AddressOfEntryPoint;
 LoadPE32Image := True;
End;

{ ============================================================
  LECTURE DE LA TABLE D'IMPORTATION PE
  ============================================================ }

Function ReadPEImports : Boolean;
Var
 ImportDirRVA : LongInt;
 ImportDirSize: LongInt;
 DescOfs      : LongInt;
 OrigThunk    : LongInt;
 FirstThunk   : LongInt;
 NameRVA      : LongInt;
 ThunkRVA     : LongInt;
 ThunkData    : LongInt;
 HintRVA      : LongInt;
 DLLName      : TString;
 ThunkIdx     : LongInt;
Begin
 ReadPEImports := False;
 ImportCount := 0;
 { Verifier que DataDirectory[1] (Import) est present }
 ImportDirRVA := DataDirs[1].VirtualAddress;
 ImportDirSize := DataDirs[1].Size;
 If (ImportDirRVA = 0) Or (ImportDirSize = 0) Then Begin
  { Pas de table d'importation - c'est valide }
  ReadPEImports := True;
  Exit;
 End;
 { Parcourir les IMAGE_IMPORT_DESCRIPTORs (20 octets chacun) }
 DescOfs := ImportDirRVA;
 While True Do Begin
  { Verifier les limites }
  If DescOfs + 19 >= ImageSize Then Break;
  { Lire les champs du descripteur }
  OrigThunk  := ReadImageDWord(DescOfs);       { OriginalFirstThunk }
  { DescOfs+4 = TimeDateStamp, DescOfs+8 = ForwarderChain }
  NameRVA    := ReadImageDWord(DescOfs + 12);   { Name (RVA) }
  FirstThunk := ReadImageDWord(DescOfs + 16);   { FirstThunk (IAT) }
  { Fin de la liste : tous les champs a zero }
  If (OrigThunk = 0) And (NameRVA = 0) And (FirstThunk = 0) Then Break;
  { Lire le nom de la DLL }
  If (NameRVA > 0) And (NameRVA < ImageSize) Then
   DLLName := ReadImageString(NameRVA)
  Else
   DLLName := '???';
  { Utiliser OriginalFirstThunk si disponible, sinon FirstThunk }
  If OrigThunk <> 0 Then
   ThunkRVA := OrigThunk
  Else
   ThunkRVA := FirstThunk;
  { Parcourir les IMAGE_THUNK_DATA (4 octets chacun) }
  ThunkIdx := 0;
  While (ThunkRVA + ThunkIdx * 4 + 3 < ImageSize) Do Begin
   ThunkData := ReadImageDWord(ThunkRVA + ThunkIdx * 4);
   If ThunkData = 0 Then Break;  { Fin de la liste }
   If ImportCount >= MAX_IMPORTS Then Break;
   Imports[ImportCount].DLLName := DLLName;
   Imports[ImportCount].IATAddr := FirstThunk + ThunkIdx * 4;
   { Tester si importation par ordinal (bit 31 a 1) }
   If (ThunkData And LongInt($80000000)) <> 0 Then Begin
    Imports[ImportCount].ByOrdinal := True;
    Imports[ImportCount].Ordinal := Word(ThunkData And $FFFF);
    Imports[ImportCount].FuncName := '';
    Imports[ImportCount].Hint := 0;
   End Else Begin
    Imports[ImportCount].ByOrdinal := False;
    HintRVA := ThunkData;
    If (HintRVA >= 0) And (HintRVA + 2 < ImageSize) Then Begin
     Imports[ImportCount].Hint := ReadImageWord(HintRVA);
     Imports[ImportCount].FuncName := ReadImageString(HintRVA + 2);
    End Else Begin
     Imports[ImportCount].Hint := 0;
     Imports[ImportCount].FuncName := '???';
    End;
    Imports[ImportCount].Ordinal := 0;
   End;
   Inc(ImportCount);
   Inc(ThunkIdx);
  End;
  { Descripteur suivant (20 octets) }
  Inc(DescOfs, 20);
 End;
 ReadPEImports := True;
End;

{ ============================================================
  LECTURE DE LA TABLE D'EXPORTATION PE
  ============================================================ }

Function ReadPEExports : Boolean;
Var
 ExportDirRVA  : LongInt;
 ExportDirSize : LongInt;
 ExportNameRVA : LongInt;
 NumFunctions  : LongInt;
 NumNames      : LongInt;
 AddrFuncsRVA  : LongInt;
 AddrNamesRVA  : LongInt;
 AddrOrdsRVA   : LongInt;
 OrdinalBase   : LongInt;
 FuncRVA       : LongInt;
 NameRVA       : LongInt;
 NameOrd       : Word;
 I, J          : LongInt;
Begin
 ReadPEExports := False;
 ExportCount := 0;
 ExportDLLName := '';
 { Verifier que DataDirectory[0] (Export) est present }
 ExportDirRVA := DataDirs[0].VirtualAddress;
 ExportDirSize := DataDirs[0].Size;
 If (ExportDirRVA = 0) Or (ExportDirSize = 0) Then Begin
  { Pas de table d'exportation - c'est valide }
  ReadPEExports := True;
  Exit;
 End;
 { Verifier les limites }
 If ExportDirRVA + 39 >= ImageSize Then Begin
  WriteLn('Erreur : Export Directory hors limites.');
  Exit;
 End;
 { Lire les champs de IMAGE_EXPORT_DIRECTORY (40 octets) }
 { Offset 0 : Characteristics (4) }
 { Offset 4 : TimeDateStamp (4) }
 { Offset 8 : MajorVersion (2), MinorVersion (2) }
 ExportNameRVA := ReadImageDWord(ExportDirRVA + 12);  { Name (RVA) }
 OrdinalBase   := ReadImageDWord(ExportDirRVA + 16);  { Base }
 NumFunctions  := ReadImageDWord(ExportDirRVA + 20);  { NumberOfFunctions }
 NumNames      := ReadImageDWord(ExportDirRVA + 24);  { NumberOfNames }
 AddrFuncsRVA  := ReadImageDWord(ExportDirRVA + 28);  { AddressOfFunctions }
 AddrNamesRVA  := ReadImageDWord(ExportDirRVA + 32);  { AddressOfNames }
 AddrOrdsRVA   := ReadImageDWord(ExportDirRVA + 36);  { AddressOfNameOrdinals }
 { Lire le nom de la DLL }
 If (ExportNameRVA > 0) And (ExportNameRVA < ImageSize) Then
  ExportDLLName := ReadImageString(ExportNameRVA)
 Else
  ExportDLLName := '';
 { Limiter le nombre de fonctions }
 If NumFunctions > MAX_EXPORTS Then NumFunctions := MAX_EXPORTS;
 { D'abord, enregistrer toutes les fonctions par ordinal }
 For I := 0 To NumFunctions - 1 Do Begin
  If ExportCount >= MAX_EXPORTS Then Break;
  FuncRVA := ReadImageDWord(AddrFuncsRVA + I * 4);
  If FuncRVA = 0 Then Continue;  { Entree vide }
  ExportList[ExportCount].FuncRVA := FuncRVA;
  ExportList[ExportCount].Ordinal := Word(OrdinalBase + I);
  ExportList[ExportCount].FuncName := '';
  ExportList[ExportCount].HasName := False;
  Inc(ExportCount);
 End;
 { Ensuite, associer les noms aux fonctions via la table des ordinals }
 If (NumNames > 0) And (AddrNamesRVA > 0) And (AddrOrdsRVA > 0) Then Begin
  For I := 0 To NumNames - 1 Do Begin
   NameRVA := ReadImageDWord(AddrNamesRVA + I * 4);
   NameOrd := ReadImageWord(AddrOrdsRVA + I * 2);
   { Chercher l'entree correspondante par ordinal }
   For J := 0 To ExportCount - 1 Do Begin
    If ExportList[J].Ordinal = Word(OrdinalBase + LongInt(NameOrd)) Then Begin
     If (NameRVA > 0) And (NameRVA < ImageSize) Then
      ExportList[J].FuncName := ReadImageString(NameRVA)
     Else
      ExportList[J].FuncName := '???';
     ExportList[J].HasName := True;
     Break;
    End;
   End;
  End;
 End;
 ReadPEExports := True;
End;

{ ============================================================
  LECTURE DE LA TABLE DE RELOGEMENT PE (BASE RELOCATION)
  ============================================================ }

Function ReadPERelocs : Boolean;
Var
 RelocRVA    : LongInt;
 RelocSize   : LongInt;
 BlockPos    : LongInt;
 BlockVA     : LongInt;
 BlockSize   : LongInt;
 EntryCount  : LongInt;
 I           : LongInt;
 Entry       : Word;
 RelocType   : Byte;
 RelocOffset : Word;
 TargetRVA   : LongInt;
 FlagSize    : LongInt;
Begin
 ReadPERelocs := False;
 PERelocCount := 0;
 { Verifier la presence de la Base Relocation Table (DataDirectory[5]) }
 RelocRVA := DataDirs[5].VirtualAddress;
 RelocSize := DataDirs[5].Size;
 If (RelocRVA = 0) Or (RelocSize = 0) Then Begin
  ReadPERelocs := True;  { pas de relogements, ce n'est pas une erreur }
  Exit;
 End;
 { Allouer le tableau de flags (meme taille que l'image, 1 = position relogee) }
 FlagSize := ImageSize;
 If FlagSize > 0 Then Begin
  GetMem(RelocFlags, FlagSize);
  If RelocFlags = Nil Then Begin
   WriteLn('Erreur : memoire insuffisante pour les flags de relogement PE.');
   Exit;
  End;
  FillChar(RelocFlags^, FlagSize, 0);
 End;
 { Parcourir les blocs de relogement }
 BlockPos := RelocRVA;
 While BlockPos < RelocRVA + RelocSize Do Begin
  { Lire l'entete du bloc : VirtualAddress (4) + SizeOfBlock (4) }
  BlockVA := ReadImageDWord(BlockPos);
  BlockSize := ReadImageDWord(BlockPos + 4);
  { Verifier la validite du bloc }
  If (BlockSize < 8) Or (BlockSize > RelocSize) Then Break;
  { Nombre d'entrees de 16 bits dans ce bloc }
  EntryCount := (BlockSize - 8) Div 2;
  { Traiter chaque entree }
  For I := 0 To EntryCount - 1 Do Begin
   Entry := ReadImageWord(BlockPos + 8 + I * 2);
   RelocType := Byte(Entry Shr 12);
   RelocOffset := Entry And $0FFF;
   Case RelocType Of
    IMAGE_REL_BASED_ABSOLUTE: ; { padding, ignorer }
    IMAGE_REL_BASED_HIGHLOW: Begin
     { Calculer la RVA cible }
     TargetRVA := BlockVA + LongInt(RelocOffset);
     { Enregistrer dans la liste }
     If PERelocCount < MAX_RELOCS Then Begin
      PERelocs[PERelocCount].Address := TargetRVA;
      PERelocs[PERelocCount].RelocType := RelocType;
      Inc(PERelocCount);
     End;
     { Marquer les 4 octets comme reloges }
     If (TargetRVA >= 0) And (TargetRVA + 3 < ImageSize) And
        (RelocFlags <> Nil) Then Begin
      RelocFlags^[TargetRVA] := 1;
      RelocFlags^[TargetRVA + 1] := 1;
      RelocFlags^[TargetRVA + 2] := 1;
      RelocFlags^[TargetRVA + 3] := 1;
     End;
    End;
   End; { case }
  End;
  { Passer au bloc suivant }
  Inc(BlockPos, BlockSize);
 End;
 ReadPERelocs := True;
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
 { Segment de base pour le relogement (0 par defaut, sera ajuste au relogement) }
 BaseSegment := 0;
 LoadDOS16Image := True;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }

Begin
 WriteLn('DISEXE v', DISEXE_VERSION, ' (', DISEXE_DATE, ')');
 WriteLn('Desassembleur de fichiers EXE (MZ DOS 16 bits / PE Windows 32 bits)');
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
 { Detection PE }
 If DetectPE Then Begin
  WriteLn('Format PE (Windows 32 bits) detecte a l''offset $', HexDWord(PEOffset), '.');
  { Lecture des entetes PE }
  If Not ReadPEHeaders Then Begin
   Close(InFile);
   Halt(1);
  End;
  If OptVerbose Then Begin
   WriteLn('IMAGE_FILE_HEADER :');
   WriteLn('  Machine            : $', HexWord(PEFileHeader.Machine));
   WriteLn('  NumberOfSections   : ', PEFileHeader.NumberOfSections);
   WriteLn('  TimeDateStamp      : $', HexDWord(PEFileHeader.TimeDateStamp));
   WriteLn('  SizeOfOptionalHeader : ', PEFileHeader.SizeOfOptionalHeader);
   WriteLn('  Characteristics    : $', HexWord(PEFileHeader.Characteristics));
   WriteLn('IMAGE_OPTIONAL_HEADER32 :');
   WriteLn('  Magic              : $', HexWord(PEOptHeader.Magic));
   WriteLn('  LinkerVersion      : ', PEOptHeader.MajorLinkerVersion, '.', PEOptHeader.MinorLinkerVersion);
   WriteLn('  SizeOfCode         : $', HexDWord(PEOptHeader.SizeOfCode));
   WriteLn('  AddressOfEntryPoint: $', HexDWord(PEOptHeader.AddressOfEntryPoint));
   WriteLn('  BaseOfCode         : $', HexDWord(PEOptHeader.BaseOfCode));
   WriteLn('  BaseOfData         : $', HexDWord(PEOptHeader.BaseOfData));
   WriteLn('  ImageBase          : $', HexDWord(PEOptHeader.ImageBase));
   WriteLn('  SectionAlignment   : $', HexDWord(PEOptHeader.SectionAlignment));
   WriteLn('  FileAlignment      : $', HexDWord(PEOptHeader.FileAlignment));
   WriteLn('  SizeOfImage        : $', HexDWord(PEOptHeader.SizeOfImage));
   WriteLn('  SizeOfHeaders      : $', HexDWord(PEOptHeader.SizeOfHeaders));
   WriteLn('  CheckSum           : $', HexDWord(PEOptHeader.CheckSum));
   WriteLn('  Subsystem          : ', PEOptHeader.Subsystem);
   WriteLn('  NumberOfRvaAndSizes: ', PEOptHeader.NumberOfRvaAndSizes);
   WriteLn('  Sections           : ', SectionCount);
  End;
  { Lecture des sections PE }
  If Not ReadPESections Then Begin
   Close(InFile);
   Halt(1);
  End;
  If OptVerbose Then Begin
   WriteLn('Sections PE :');
   For IterI := 0 To SectionCount - 1 Do Begin
    WriteLn('  [', IterI, '] ', GetSectionName(Sections[IterI]),
            '  VA=$', HexDWord(Sections[IterI].VirtualAddress),
            '  VSize=$', HexDWord(Sections[IterI].VirtualSize),
            '  RawSize=$', HexDWord(Sections[IterI].SizeOfRawData),
            '  RawPtr=$', HexDWord(Sections[IterI].PointerToRawData));
    WriteLn('         Flags=$', HexDWord(Sections[IterI].Characteristics),
            ' [', SectionFlagsStr(Sections[IterI].Characteristics), ']');
   End;
  End;
  { Chargement de l'image PE en memoire }
  If Not LoadPE32Image Then Begin
   Close(InFile);
   Halt(1);
  End;
  If OptVerbose Then Begin
   WriteLn('Image PE chargee : ', ImageSize, ' octets.');
   WriteLn('  ImageBase        : $', HexDWord(PEOptHeader.ImageBase));
   WriteLn('  Point d''entree   : RVA $', HexDWord(PEEntryPointRVA));
  End;
  { Lecture de la table d'importation PE }
  If Not ReadPEImports Then Begin
   Close(InFile);
   Halt(1);
  End;
  If OptVerbose Then Begin
   WriteLn('Imports PE : ', ImportCount, ' fonctions importees.');
   For IterI := 0 To ImportCount - 1 Do Begin
    If Imports[IterI].ByOrdinal Then
     WriteLn('  ', Imports[IterI].DLLName, ' ! ordinal #', Imports[IterI].Ordinal,
             '  IAT=$', HexDWord(Imports[IterI].IATAddr))
    Else
     WriteLn('  ', Imports[IterI].DLLName, ' ! ', Imports[IterI].FuncName,
             '  (hint=', Imports[IterI].Hint, ')',
             '  IAT=$', HexDWord(Imports[IterI].IATAddr));
   End;
  End;
  { Lecture de la table d'exportation PE }
  If Not ReadPEExports Then Begin
   Close(InFile);
   Halt(1);
  End;
  If OptVerbose Then Begin
   If ExportCount > 0 Then Begin
    WriteLn('Exports PE : ', ExportCount, ' fonctions exportees.');
    If ExportDLLName <> '' Then
     WriteLn('  DLL : ', ExportDLLName);
    For IterI := 0 To ExportCount - 1 Do Begin
     If ExportList[IterI].HasName Then
      WriteLn('  [', ExportList[IterI].Ordinal, '] ', ExportList[IterI].FuncName,
              '  RVA=$', HexDWord(ExportList[IterI].FuncRVA))
     Else
      WriteLn('  [', ExportList[IterI].Ordinal, '] (ordinal seul)',
              '  RVA=$', HexDWord(ExportList[IterI].FuncRVA));
    End;
   End Else
    WriteLn('Exports PE : aucune exportation.');
  End;
   { Lecture de la table de relogement PE (Base Relocation) }
   If Not ReadPERelocs Then Begin
    Close(InFile);
    Halt(1);
   End;
   If OptVerbose Then Begin
    WriteLn('Relogements PE : ', PERelocCount, ' entrees HIGHLOW.');
    If PERelocCount > 0 Then Begin
     For IterI := 0 To PERelocCount - 1 Do Begin
      WriteLn('  [', IterI, '] RVA=$', HexDWord(PERelocs[IterI].Address),
              '  type=', PERelocs[IterI].RelocType);
     End;
    End;
   End;
 End Else Begin
  WriteLn('Format DOS MZ (16 bits) detecte.');
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
   WriteLn('Image DOS chargee : ', ImageSize, ' octets.');
   WriteLn('  Point d''entree  : ', HexWord(EntryCS), ':', HexWord(EntryIP));
   WriteLn('  Pile initiale   : ', HexWord(EntrySS), ':', HexWord(EntrySP));
   WriteLn('  Segment de base : ', HexWord(BaseSegment));
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
 { Determiner le mode 32 bits et la zone de code }
 If IsPEFile Then Begin
  { PE 32 bits : desassembler a partir du point d'entree }
  AnalyzeControlFlow(PEEntryPointRVA, ImageSize, True);
 End Else Begin
  { DOS 16 bits : desassembler a partir de CS:IP }
  AnalyzeControlFlow(LongInt(EntryCS) * 16 + LongInt(EntryIP), ImageSize, False);
 End;
 If OptVerbose Then Begin
  WriteLn('Analyse du flux de controle terminee :');
  WriteLn('  Instructions analysees  : ', InstrCount);
  WriteLn('  Sous-programmes trouves : ', ProcCount);
  WriteLn('  Labels generes          : ', LabelCount);
  WriteLn('  References croisees     : ', XRefCount);
 End;
 { Detection des procedures, fonctions et points d'entree (TODO 18) }
 WriteLn('Detection des procedures...');
 If IsPEFile Then Begin
  DetectProcedures(PEEntryPointRVA, ImageSize, True);
 End Else Begin
  DetectProcedures(LongInt(EntryCS) * 16 + LongInt(EntryIP), ImageSize, False);
 End;
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
 { Discrimination code/donnees (TODO 19) }
 If IsPEFile Then Begin
  DiscriminateCodeData(PEEntryPointRVA, ImageSize, True);
 End Else Begin
  DiscriminateCodeData(LongInt(EntryCS) * 16 + LongInt(EntryIP), ImageSize, False);
 End;
 If OptVerbose And IsPEFile Then Begin
  WriteLn('Repartition par section :');
  For IterI := 0 To SectionCount - 1 Do Begin
   WriteLn('  ', GetSectionName(Sections[IterI]), ' : ',
           SectionFlagsStr(Sections[IterI].Characteristics));
  End;
 End;
 { Generation du fichier .ASM : en-tete, directives et segments (TODO 20) }
 GenerateASMHeader;
 WriteLn;
 WriteLn('(les TODOs 21 a 25 restent a implementer)');
 WriteLn;
 WriteLn('Termine.');
 { Liberation de la memoire }
 If (ByteFlags <> Nil) And (ImageSize > 0) Then
  FreeMem(ByteFlags, ImageSize);
 If (RelocFlags <> Nil) And (ImageSize > 0) Then
  FreeMem(RelocFlags, ImageSize);
 If (ImageBuffer <> Nil) And (ImageSize > 0) Then
  FreeMem(ImageBuffer, ImageSize);
End.
