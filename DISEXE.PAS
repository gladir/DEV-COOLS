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

  2.  Lecture et validation de l'entete MZ (DOS EXE header).
      Lire les 28 octets de l'entete MZ : signature (MZ ou ZM),
      nombre d'octets dans la derniere page, nombre de pages de
      512 octets, nombre d'entrees de relogement, taille de l'entete
      en paragraphes, MINALLOC, MAXALLOC, SS:SP initial, checksum,
      CS:IP initial (point d'entree), offset de la table de relogement,
      numero d'overlay. Valider la signature $5A4D (MZ).
      Detecter la presence d'un entete PE via le champ a l'offset
      $3C (e_lfanew) pointant vers la signature PE.

  3.  Chargement du programme DOS 16 bits en memoire.
      Si le fichier est un EXE DOS pur (pas de signature PE), charger
      l'image executable en memoire a partir de la fin de l'entete MZ
      (taille entete * 16 octets). Calculer la taille de l'image :
      (nombre de pages - 1) * 512 + octets derniere page - taille
      entete * 16. Allouer un tampon dynamique pour l'image.
      Initialiser CS:IP et SS:SP a partir de l'entete MZ.
      Stocker les segments de base pour le relogement.

  4.  Lecture et validation des entetes PE (Portable Executable).
      Si e_lfanew pointe vers une signature PE ($00004550), lire
      IMAGE_FILE_HEADER (20 octets) : Machine ($014C = i386),
      NumberOfSections, TimeDateStamp, SizeOfOptionalHeader,
      Characteristics. Puis lire IMAGE_OPTIONAL_HEADER32 :
      Magic ($010B = PE32), AddressOfEntryPoint, ImageBase,
      SectionAlignment, FileAlignment, SizeOfImage,
      SizeOfHeaders, NumberOfRvaAndSizes, DataDirectory[16].
      Valider Machine=$014C et Magic=$010B pour PE 32 bits.

  5.  Lecture des sections PE et chargement en memoire.
      Lire chaque IMAGE_SECTION_HEADER (40 octets) : Name[8],
      VirtualSize, VirtualAddress, SizeOfRawData,
      PointerToRawData, Characteristics (flags executable,
      lisible, inscriptible, contient du code, contient des
      donnees initialisees/non-initialisees).
      Charger chaque section dans le tampon memoire a son
      VirtualAddress relatif a ImageBase. Identifier les
      sections .text, .data, .rdata, .bss, .idata, .edata,
      .reloc par leur nom et/ou leurs flags.

  6.  Traitement de la table d'importation PE (Import Directory).
      Lire la Import Directory Table via DataDirectory[1] :
      chaque IMAGE_IMPORT_DESCRIPTOR contient OriginalFirstThunk,
      Name (RVA du nom de la DLL), FirstThunk (RVA de la IAT).
      Pour chaque DLL importee, lire les IMAGE_THUNK_DATA :
      si le bit haut est a 1, importation par ordinal, sinon
      par RVA vers IMAGE_IMPORT_BY_NAME (Hint + Name).
      Stocker les noms des DLL et des fonctions importees
      avec leur adresse IAT pour generer les EXTRN dans le .ASM.

  7.  Traitement de la table d'exportation PE (Export Directory).
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

  { Limites des tableaux internes }
  MAX_SECTIONS   = 64;
  MAX_IMPORTS    = 4096;
  MAX_EXPORTS    = 4096;
  MAX_RELOCS     = 65536;
  MAX_LABELS     = 65536;
  MAX_XREFS      = 65536;
  BUFFER_SIZE    = 65536;

  { Taille maximale de l'image en memoire (16 Mo) }
  MAX_IMAGE_SIZE = 16 * 1024 * 1024;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String;

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

  { Sections }
  Sections       : Array[0..MAX_SECTIONS - 1] Of TPESectionHeader;
  SectionCount   : Integer;

  { Image en memoire }
  ImageSize      : LongInt;

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
  PROGRAMME PRINCIPAL
  ============================================================ }

Begin
 WriteLn('DISEXE v', DISEXE_VERSION, ' (', DISEXE_DATE, ')');
 WriteLn('Desassembleur de fichiers EXE (MZ DOS 16 bits / PE Windows 32 bits)');
 WriteLn;
 ParseArgs;
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
  WriteLn('  Pages         : ', MZHeader.PageCount);
  WriteLn('  Relogements   : ', MZHeader.RelocCount);
  WriteLn('  CS:IP initial : ', HexWord(MZHeader.InitCS), ':', HexWord(MZHeader.InitIP));
  WriteLn('  SS:SP initial : ', HexWord(MZHeader.InitSS), ':', HexWord(MZHeader.InitSP));
 End;
 { Detection PE }
 If DetectPE Then Begin
  WriteLn('Format PE (Windows 32 bits) detecte a l''offset $', HexDWord(PEOffset), '.');
 End Else Begin
  WriteLn('Format DOS MZ (16 bits) detecte.');
 End;
 Close(InFile);
 { Initialiser les compteurs }
 LabelCount := 0;
 XRefCount := 0;
 InstrCount := 0;
 ProcCount := 0;
 DataBytes := 0;
 ImportCount := 0;
 ExportCount := 0;
 SectionCount := 0;
 WriteLn;
 WriteLn('Desassemblage en cours...');
 WriteLn('(les TODOs 3 a 25 restent a implementer)');
 WriteLn;
 WriteLn('Termine.');
End.
