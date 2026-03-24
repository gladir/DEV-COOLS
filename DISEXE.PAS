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

  8.  Traitement de la table de relogement MZ (DOS).
      Lire la table de relogement DOS a partir de l'offset
      indique dans l'entete MZ. Chaque entree est un couple
      segment:offset (4 octets). Appliquer les relogements
      en ajoutant le segment de base aux mots aux positions
      indiquees. Marquer les adresses relogees pour generer
      des references symboliques segment:offset dans le .ASM
      plutot que des valeurs numeriques brutes.

  9.  Traitement de la table de relogement PE (Base Relocation).
      Lire la Base Relocation Table via DataDirectory[5].
      Chaque bloc contient VirtualAddress et SizeOfBlock, suivi
      d'entrees de 16 bits (4 bits type + 12 bits offset).
      Types supportes : IMAGE_REL_BASED_ABSOLUTE (padding),
      IMAGE_REL_BASED_HIGHLOW (ajuster un DWORD 32 bits).
      Marquer les adresses relogees pour generer des
      references symboliques dans le .ASM.

  10. Table des opcodes et mnemoniques 8086/8088.
      Definir les 256 opcodes de base du 8086/8088 avec pour
      chacun : le mnemonique (MOV, ADD, SUB, CMP, JMP, CALL,
      RET, PUSH, POP, INT, etc.), la taille de base, le type
      d'operandes (reg, mem, imm, rel8, rel16), le besoin
      d'un octet ModR/M. Inclure les opcodes du coprocesseur
      x87 (ESC, FWAIT). Definir les noms des registres 8 bits
      (AL,CL,DL,BL,AH,CH,DH,BH), 16 bits (AX,CX,DX,BX,
      SP,BP,SI,DI) et de segment (ES,CS,SS,DS).

  11. Table des opcodes et mnemoniques 80286.
      Etendre la table avec les instructions ajoutees par le
      80286 : BOUND, ENTER, LEAVE, INS, OUTS, PUSHA, POPA,
      PUSH imm8/imm16, IMUL imm, SHL/SHR/SAR/ROL/ROR/RCL/RCR
      avec operande immediat. Opcodes etendus 0Fh du 80286 :
      LGDT, SGDT, LIDT, SIDT, LLDT, SLDT, LTR, STR, LMSW,
      SMSW, CLTS, LAR, LSL, VERR, VERW.
      Instructions protegees pour le mode protege.

  12. Table des opcodes et mnemoniques 80386 (32 bits).
      Etendre la table pour le mode 32 bits : prefixes de
      taille d'operande (66h) et de taille d'adresse (67h),
      registres 32 bits (EAX,ECX,EDX,EBX,ESP,EBP,ESI,EDI),
      registres de segment supplementaires (FS, GS),
      instructions 32 bits (MOVZX, MOVSX, CWDE, CDQ, BSWAP,
      XADD, CMPXCHG, SETcc, CMOVcc, BSF, BSR, BT, BTS,
      BTR, BTC, SHLD, SHRD, IMUL reg,r/m,imm).
      Gerer le basculement 16/32 bits selon le mode.

  13. Decodage des modes d'adressage ModR/M 16 bits.
      Decoder l'octet ModR/M pour le mode 16 bits :
      mod (2 bits), reg (3 bits), r/m (3 bits).
      8 modes effectifs : [BX+SI], [BX+DI], [BP+SI], [BP+DI],
      [SI], [DI], [BP] (sauf mod=00 r/m=110 -> disp16), [BX].
      Avec mod=01 : deplacement 8 bits signe.
      Avec mod=10 : deplacement 16 bits.
      Avec mod=11 : registre direct.
      Generer la chaine d'operande correspondante pour le .ASM.

  14. Decodage des modes d'adressage ModR/M et SIB 32 bits.
      Decoder l'octet ModR/M pour le mode 32 bits :
      si r/m=100 (ESP), lire l'octet SIB : scale (2 bits),
      index (3 bits), base (3 bits). Formule d'adresse :
      [base + index*scale + deplacement].
      Scale = 1, 2, 4 ou 8. Base=101 avec mod=00 -> disp32.
      Index=100 -> pas d'index. Generer la chaine d'operande
      avec les crochets, registres et facteur d'echelle.

  15. Decodage des prefixes d'instructions.
      Gerer les prefixes avant chaque instruction : segment
      override (26h=ES:, 2Eh=CS:, 36h=SS:, 3Eh=DS:, 64h=FS:,
      65h=GS:), LOCK (F0h), REP/REPE (F3h), REPNE (F2h),
      taille d'operande (66h), taille d'adresse (67h).
      Un meme opcode peut etre precede de plusieurs prefixes.
      Le prefix 66h bascule entre operandes 16 et 32 bits.
      Le prefix 67h bascule entre adresses 16 et 32 bits.
      Accumuler les prefixes avant le decodage de l'opcode.

  16. Decodage des opcodes etendus (0Fh) et instructions avancees.
      Decoder les opcodes a deux octets (0Fh + second octet) :
      Jcc near (80h-8Fh), SETcc (90h-9Fh), CMOVcc (40h-4Fh),
      MOVZX (B6h/B7h), MOVSX (BEh/BFh), BSF (BCh), BSR (BDh),
      BT/BTS/BTR/BTC (A3h/ABh/B3h/BBh/BAh),
      SHLD (A4h/A5h), SHRD (ACh/ADh),
      IMUL r,r/m (AFh), XADD (C0h/C1h),
      CMPXCHG (B0h/B1h), BSWAP (C8h-CFh).
      Instructions systeme : INVD, WBINVD, CPUID, RDTSC, etc.

  17. Analyse du flux de controle et references croisees.
      Premiere passe de desassemblage lineaire pour identifier
      les instructions de saut (JMP, Jcc, LOOP), d'appel (CALL)
      et de retour (RET, RETF, IRET). Pour chaque instruction
      de branchement, calculer l'adresse cible et l'ajouter
      a la table des references croisees (XREF). Construire
      un graphe de flux de controle simplifie pour distinguer
      les blocs de code accessibles des zones potentiellement
      non-code (donnees intercalees, padding).

  18. Detection des procedures, fonctions et points d'entree.
      A partir du point d'entree (CS:IP pour MZ, AddressOfEntryPoint
      pour PE) et des adresses cibles de CALL, identifier les
      debuts de sous-programmes. Attribuer un label automatique
      a chaque sous-programme (sub_XXXX pour MZ, sub_XXXXXXXX pour
      PE). Detecter les patterns de prologue (PUSH BP / MOV BP,SP
      pour 16 bits, PUSH EBP / MOV EBP,ESP pour 32 bits) et
      d'epilogue (POP BP / RET, LEAVE / RET). Marquer les
      fonctions importees et exportees avec leurs vrais noms.

  19. Discrimination code/donnees dans les sections executables.
      Utiliser les informations de flux de controle (TODO 17)
      pour separer le code des donnees dans les sections
      executables. Les octets non atteints par le parcours du
      flux sont marques comme donnees (DB). Detecter les
      tables de saut (switch/case), les chaines de caracteres
      (ASCII terminee par 0), les tables de pointeurs et les
      constantes numeriques. Pour les fichiers PE, utiliser
      les flags de section pour distinguer .text (code) de
      .data et .rdata (donnees).

  20. Generation du fichier .ASM : en-tete, directives et segments.
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

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
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
 End Else Begin
  WriteLn('Format DOS MZ (16 bits) detecte.');
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
 End;
 Close(InFile);
 { Initialiser les compteurs }
 LabelCount := 0;
 XRefCount := 0;
 InstrCount := 0;
 ProcCount := 0;
 DataBytes := 0;
 WriteLn;
 WriteLn('Desassemblage en cours...');
 WriteLn('(les TODOs 8 a 25 restent a implementer)');
 WriteLn;
 WriteLn('Termine.');
End.
