{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2024
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

{ TODO - Liste des 25 points a implementer pour l'emulateur Windows 32 bits :

  1.  [IMPLEMENTE] Creer le fichier d'echange de 16 Mo (EMUW32.$$$)
      servant de memoire lineaire pour l'espace d'adressage virtuel
      Win32, similaire au SwapFileMemory d'EMU8086.PAS et
      d'EMUDPMI.PAS mais avec un espace plat de 16 777 216 octets
      (16 Mo) pour emuler l'espace utilisateur d'un processus
      Windows 32 bits.

  2.  [IMPLEMENTE] Definir les registres 32 bits du 80386 : EAX, EBX,
      ECX, EDX, ESI, EDI, EBP, ESP, EIP avec un acces aux
      sous-parties 16 bits (AX, BX, ...) et 8 bits (AL, AH, ...)
      par des records variants, ainsi que le registre EFLAGS complet
      32 bits.

  3.  [IMPLEMENTE] Implementer les procedures ReadByte/ReadWord/ReadDWord
      et WriteByte/WriteWord/WriteDWord pour l'acces a la memoire
      lineaire 32 bits via le fichier de 16 Mo, en utilisant un
      modele d'adressage plat (flat) typique de Win32.

  4.  [IMPLEMENTE] Implementer la pile 32 bits (PUSH/POP en mode 32
      bits) avec ESP adressant la memoire lineaire, et allouer une
      pile par defaut (par exemple 1 Mo) dans l'espace de 16 Mo.

  5.  [IMPLEMENTE] Implementer le chargeur de fichiers PE (Portable
      Executable) : lecture de l'entete MZ/DOS stub, de la signature
      PE, de l'entete COFF (IMAGE_FILE_HEADER), de l'entete optionnel
      (IMAGE_OPTIONAL_HEADER32) incluant AddressOfEntryPoint,
      ImageBase, SectionAlignment et SizeOfStackReserve.

  6.  [IMPLEMENTE] Implementer le chargement des sections PE (.text,
      .data, .rdata, .bss, .idata) dans la memoire lineaire en
      respectant les VirtualAddress et VirtualSize de chaque
      IMAGE_SECTION_HEADER, et remplir les zones .bss de zeros.

  7.  [IMPLEMENTE] Implementer le traitement de la table d'importation
      (Import Directory Table / IAT) pour resoudre les appels aux DLL
      importees, en particulier KERNEL32.DLL, en remplissant la
      Import Address Table avec des adresses de thunks internes
      emulant chaque fonction.

  8.  [IMPLEMENTE] Implementer les instructions de transfert de donnees 32 bits :
      MOV reg32,reg32 / MOV reg32,imm32 / MOV reg32,[mem] /
      MOV [mem],reg32 / MOVZX / MOVSX / LEA / XCHG / BSWAP
      avec les modes d'adressage ModR/M et SIB du 80386.

  9.  Implementer les instructions arithmetiques 32 bits : ADD, SUB,
      ADC, SBB, CMP, INC, DEC, NEG, MUL, IMUL, DIV, IDIV sur des
      operandes 8/16/32 bits avec mise a jour correcte des drapeaux
      (CF, ZF, SF, OF, AF, PF) dans EFLAGS.

  10. Implementer les instructions logiques et de decalage 32 bits :
      AND, OR, XOR, NOT, TEST, SHL, SHR, SAR, ROL, ROR, RCL, RCR,
      BT, BTS, BTR, BTC, BSF, BSR sur des operandes 32 bits.

  11. Implementer les instructions de chaines 32 bits : MOVSD, STOSD,
      LODSD, CMPSD, SCASD ainsi que les prefixes REP/REPE/REPNE
      utilisant ECX comme compteur, et les variantes 8/16 bits.

  12. Implementer les instructions de saut conditionnel 32 bits (Jcc
      near avec deplacement rel32, prefixe 0Fh) et les sauts
      inconditionnels JMP rel32/JMP [mem] en mode plat.

  13. Implementer CALL rel32, CALL [mem], RET, RET imm16 en mode
      plat 32 bits avec empilement/depilement de EIP sur la pile,
      incluant les appels indirects via registre (CALL EAX, etc.).

  14. Implementer les instructions SET conditionnel (SETcc), CMOVcc
      (conditional move du 80686/Pentium Pro), CDQ, CBW, CWDE, CLC,
      STC, CMC, CLD, STD, NOP, LEAVE, ENTER et INT3 (breakpoint).

  15. Implementer l'emulation de KERNEL32.DLL - Gestion de processus
      et console : GetStdHandle, ExitProcess, GetCommandLineA,
      GetCommandLineW, GetCurrentProcessId, GetCurrentProcess,
      GetExitCodeProcess, GetStartupInfoA.

  16. Implementer l'emulation de KERNEL32.DLL - Entrees/sorties
      console : WriteConsoleA, ReadConsoleA, WriteFile, ReadFile
      sur les handles STD_INPUT_HANDLE, STD_OUTPUT_HANDLE et
      STD_ERROR_HANDLE, SetConsoleMode, GetConsoleMode.

  17. Implementer l'emulation de KERNEL32.DLL - Gestion des fichiers :
      CreateFileA, ReadFile, WriteFile, CloseHandle, SetFilePointer,
      GetFileSize, DeleteFileA, GetFileAttributesA,
      SetFileAttributesA, FlushFileBuffers.

  18. Implementer l'emulation de KERNEL32.DLL - Gestion de la memoire :
      VirtualAlloc, VirtualFree, GetProcessHeap, HeapCreate,
      HeapAlloc, HeapFree, HeapReAlloc, GlobalAlloc, GlobalFree,
      LocalAlloc, LocalFree dans l'espace de 16 Mo.

  19. Implementer l'emulation de KERNEL32.DLL - Chaines et
      environnement : GetEnvironmentVariableA, GetEnvironmentStringsA,
      FreeEnvironmentStringsA, lstrlenA, lstrcpyA, lstrcmpA,
      lstrcmpiA, lstrcatA, GetModuleFileNameA, GetModuleHandleA.

  20. Implementer l'emulation de KERNEL32.DLL - Date, heure et
      systeme : GetTickCount, GetSystemTime, GetLocalTime,
      QueryPerformanceCounter, GetSystemInfo, GetVersion,
      GetVersionExA, Sleep, GetLastError, SetLastError.

  21. Implementer l'emulation de KERNEL32.DLL - Synchronisation et
      divers : GetCurrentDirectoryA, SetCurrentDirectoryA,
      FindFirstFileA, FindNextFileA, FindClose,
      GetTempPathA, GetTempFileNameA, MoveFileA, CopyFileA.

  22. Implementer la convention d'appel STDCALL (Win32 API) : les
      parametres sont empiles de droite a gauche, l'appele nettoie
      la pile, la valeur de retour est dans EAX. Detecter les
      CALL vers les thunks IAT et rediriger vers les emulations.

  23. Implementer la boucle principale d'execution (Procedure Run)
      avec decodage du flux d'instructions 80386, gestion des
      prefixes (66h, 67h, 0Fh pour les opcodes etendus, F2h/F3h
      pour REP) et dispatch vers les procedures d'emulation.

  24. Implementer les options de ligne de commande : /DEBUG pour le
      mode debogage avec affichage de l'etat des registres a chaque
      instruction, /VERBOSE pour les messages informatifs, et
      /READONLY pour interdire les ecritures sur disque.

  25. Implementer la procedure de nettoyage (Procedure Done) qui
      ferme et supprime le fichier d'echange de 16 Mo, ferme tous
      les handles de fichiers emules, et affiche un rapport de
      sortie (code de retour du processus emule, statistiques).
}

Program EMUW32;

{$A-}

Uses DOS;

Const
  { TODO 1 : Fichier d'echange de 16 Mo pour la memoire lineaire }
 SwapFileMemory='EMUW32.$$$';

  { Taille totale de la memoire lineaire : 16 Mo }
 MemorySize=16*1024*1024;  { 16 777 216 octets }

  { Taille du tampon de nettoyage pour l'initialisation }
 ClearBufferSize=1024;

  { Nombre de blocs de 1 Ko pour couvrir 16 Mo }
 ClearBlockCount=MemorySize div ClearBufferSize;  { 16384 }

  { TODO 4 : Taille de la pile par defaut : 1 Mo }
 StackSize=1024*1024;  { 1 048 576 octets }

  { TODO 4 : Adresse de base de la pile dans l'espace lineaire.
    La pile occupe le dernier 1 Mo de l'espace de 16 Mo,
    soit de $F00000 a $FFFFFF (croissance vers le bas). }
 StackBase=MemorySize-StackSize;  { $F00000 = 15 Mo }

  { TODO 6 : Nombre maximum de sections PE supportees }
 MaxPESections=96;

  { TODO 7 : Zone des thunks d'importation dans la memoire lineaire.
    Les thunks occupent la zone de $E00000 a $EFFFFF (1 Mo),
    juste en dessous de la pile ($F00000-$FFFFFF). }
 ThunkBase=$E00000;

  { TODO 7 : Nombre maximum de fonctions importees supportees }
 MaxImportFuncs=1024;

  { TODO 7 : Nombre maximum de repertoires de donnees PE }
 MaxDataDirs=16;

Type
  { TODO 2 : Registres 32 bits du 80386 }
 LongRec=Record
  Lo,Hi:Word;
 End;

  { TODO 5 : En-tete DOS MZ (64 octets) }
 TImageDosHeader=Record
  e_magic:Word;                     { Signature MZ = $5A4D }
  e_cblp:Word;                      { Octets dans la derniere page }
  e_cp:Word;                        { Pages dans le fichier }
  e_crlc:Word;                      { Relocalisations }
  e_cparhdr:Word;                   { Taille de l'en-tete en paragraphes }
  e_minalloc:Word;                  { Memoire minimum supplementaire }
  e_maxalloc:Word;                  { Memoire maximum supplementaire }
  e_ss:Word;                        { Valeur initiale SS }
  e_sp:Word;                        { Valeur initiale SP }
  e_csum:Word;                      { Checksum }
  e_ip:Word;                        { Valeur initiale IP }
  e_cs:Word;                        { Valeur initiale CS }
  e_lfarlc:Word;                    { Offset table de relocalisation }
  e_ovno:Word;                      { Numero d'overlay }
  e_res:Array[0..3]of Word;         { Reserves }
  e_oemid:Word;                     { Identifiant OEM }
  e_oeminfo:Word;                   { Information OEM }
  e_res2:Array[0..9]of Word;        { Reserves }
  e_lfanew:LongInt;                 { Offset vers l'en-tete PE }
 End;

  { TODO 5 : En-tete COFF (IMAGE_FILE_HEADER, 20 octets) }
 TImageFileHeader=Record
  Machine:Word;                     { Architecture cible ($014C = i386) }
  NumberOfSections:Word;            { Nombre de sections }
  TimeDateStamp:LongInt;            { Horodatage de creation }
  PointerToSymbolTable:LongInt;     { Offset table de symboles }
  NumberOfSymbols:LongInt;          { Nombre de symboles }
  SizeOfOptionalHeader:Word;        { Taille de l'en-tete optionnel }
  Characteristics:Word;             { Drapeaux du fichier }
 End;

  { TODO 5 : En-tete optionnel PE32 (IMAGE_OPTIONAL_HEADER32, 96 octets
    pour les champs standard, sans les repertoires de donnees) }
 TImageOptionalHeader32=Record
  Magic:Word;                       { $010B = PE32 }
  MajorLinkerVersion:Byte;          { Version majeure du lieur }
  MinorLinkerVersion:Byte;          { Version mineure du lieur }
  SizeOfCode:LongInt;               { Taille totale du code }
  SizeOfInitializedData:LongInt;    { Taille des donnees initialisees }
  SizeOfUninitializedData:LongInt;  { Taille des donnees non initialisees }
  AddressOfEntryPoint:LongInt;      { RVA du point d'entree }
  BaseOfCode:LongInt;               { RVA de la base du code }
  BaseOfData:LongInt;               { RVA de la base des donnees }
  ImageBase:LongInt;                { Adresse de base preferee }
  SectionAlignment:LongInt;         { Alignement des sections en memoire }
  FileAlignment:LongInt;            { Alignement des sections dans le fichier }
  MajorOperatingSystemVersion:Word; { Version majeure du SE requise }
  MinorOperatingSystemVersion:Word; { Version mineure du SE requise }
  MajorImageVersion:Word;           { Version majeure de l'image }
  MinorImageVersion:Word;           { Version mineure de l'image }
  MajorSubsystemVersion:Word;      { Version majeure du sous-systeme }
  MinorSubsystemVersion:Word;      { Version mineure du sous-systeme }
  Win32VersionValue:LongInt;        { Reserve, doit etre 0 }
  SizeOfImage:LongInt;              { Taille totale de l'image en memoire }
  SizeOfHeaders:LongInt;            { Taille combinee des en-tetes }
  CheckSum:LongInt;                 { Somme de controle de l'image }
  Subsystem:Word;                   { Sous-systeme requis (3=CONSOLE) }
  DllCharacteristics:Word;          { Drapeaux DLL }
  SizeOfStackReserve:LongInt;       { Taille de la pile reservee }
  SizeOfStackCommit:LongInt;        { Taille de la pile initialement allouee }
  SizeOfHeapReserve:LongInt;        { Taille du tas reserve }
  SizeOfHeapCommit:LongInt;         { Taille du tas initialement alloue }
  LoaderFlags:LongInt;              { Drapeaux du chargeur (obsolete) }
  NumberOfRvaAndSizes:LongInt;      { Nombre de repertoires de donnees }
 End;

  { TODO 6 : En-tete de section PE (IMAGE_SECTION_HEADER, 40 octets) }
 TImageSectionHeader=Record
  Name:Array[0..7]of Char;          { Nom de la section (8 caracteres) }
  VirtualSize:LongInt;               { Taille en memoire de la section }
  VirtualAddress:LongInt;            { RVA de la section en memoire }
  SizeOfRawData:LongInt;             { Taille des donnees dans le fichier }
  PointerToRawData:LongInt;          { Offset des donnees dans le fichier }
  PointerToRelocations:LongInt;      { Offset des relocalisations }
  PointerToLinenumbers:LongInt;      { Offset des numeros de ligne }
  NumberOfRelocations:Word;          { Nombre de relocalisations }
  NumberOfLinenumbers:Word;          { Nombre de numeros de ligne }
  Characteristics:LongInt;           { Drapeaux de la section }
 End;

  { TODO 7 : Repertoire de donnees PE (IMAGE_DATA_DIRECTORY, 8 octets) }
 TImageDataDirectory=Record
  VirtualAddress:LongInt;            { RVA du repertoire de donnees }
  Size:LongInt;                      { Taille du repertoire de donnees }
 End;

  { TODO 7 : Descripteur d'importation PE (IMAGE_IMPORT_DESCRIPTOR,
    20 octets) }
 TImageImportDescriptor=Record
  OriginalFirstThunk:LongInt;        { RVA de l'Import Lookup Table }
  TimeDateStamp:LongInt;             { Horodatage (0 si non lie) }
  ForwarderChain:LongInt;            { Chaine de redirection }
  Name:LongInt;                      { RVA du nom de la DLL }
  FirstThunk:LongInt;                { RVA de l'Import Address Table }
 End;

  { TODO 7 : Entree dans la table d'importation resolue }
 TImportEntry=Record
  DLLName:String[63];                { Nom de la DLL importee }
  FuncName:String[127];              { Nom de la fonction importee }
  Ordinal:Word;                      { Numero d'ordinal (si import par ordinal) }
  ByOrdinal:Boolean;                 { True si import par ordinal }
  ThunkAddr:LongInt;                 { Adresse du thunk dans la memoire }
 End;

Var
  { TODO 1 : Fichier d'echange }
 Memory:File;
 ClrBuffer:Array[0..ClearBufferSize-1]of Byte;

  { TODO 2 : Registres generaux 32 bits du 80386 avec acces aux
    sous-parties 16 bits (AX, BX, ...) et 8 bits (AL, AH, ...) }
 Regs:Record Case Byte of
  0:(EAX,ECX,EDX,EBX,ESP,EBP,ESI,EDI:LongInt);
  1:(AX,EAH,CX,ECH,DX,EDH,BX,EBH,SP,SPH,BP,BPH,SI,SIH,DI,DIH:Word);
  2:(AL,AH,HAL,HAH,CL,CH,HCL,HCH,DL,DH,HDL,HDH,BL,BH,HBL,HBH:Byte);
  3:(Abs:Array[0..7]of LongInt);
  4:(AbsWord:Array[0..7]of LongRec);
 End;

  { TODO 2 : Pointeur d'instruction 32 bits }
 EIP:LongInt;

  { TODO 2 : Drapeaux du processeur (EFLAGS complet 32 bits) }
 EFlags:Record Case Byte of
  0:(s:Set of(CF,bit1,PF,bit3,AF,bit5,ZF,SF,TF,_IF,DF,_OF));
  1:(Base:Word);
  2:(Abs:LongInt);
  3:(DataByte:Byte);
 End;

  { TODO 5 : En-tetes PE charges par LoadPE }
 PEDosHeader:TImageDosHeader;
 PEFileHeader:TImageFileHeader;
 PEOptHeader:TImageOptionalHeader32;
 PELoaded:Boolean;

  { TODO 6 : Table des en-tetes de section PE }
 PESections:Array[0..MaxPESections-1]of TImageSectionHeader;
 PENumSections:Word;

  { TODO 7 : Repertoires de donnees PE (lus depuis l'en-tete optionnel) }
 PEDataDirs:Array[0..MaxDataDirs-1]of TImageDataDirectory;
 PENumDataDirs:LongInt;

  { TODO 7 : Table des fonctions importees resolues }
 ImportEntries:Array[0..MaxImportFuncs-1]of TImportEntry;
 ImportCount:Word;

  { TODO 3 : Lecture d'un octet dans la memoire lineaire 32 bits.
    L'adresse est une adresse lineaire plate (flat) dans l'espace
    de 16 Mo. Retourne 0 si l'adresse est hors limites. }
Function ReadByte(Addr:LongInt):Byte;
Var
 B:Byte;
 ByteRead:Word;
Begin
 If(Addr<0)or(Addr>=MemorySize)Then Begin
  WriteLn('Erreur: ReadByte adresse $',HexStr(Addr,8),' hors limites');
  ReadByte:=0;
  Exit;
 End;
 Seek(Memory,Addr);
 BlockRead(Memory,B,1,ByteRead);
 ReadByte:=B;
End;

  { TODO 3 : Lecture d'un mot 16 bits dans la memoire lineaire.
    Lit 2 octets consecutifs en little-endian a l'adresse donnee. }
Function ReadWord(Addr:LongInt):Word;
Var
 W:Word;
 ByteRead:Word;
Begin
 If(Addr<0)or(Addr>MemorySize-2)Then Begin
  WriteLn('Erreur: ReadWord adresse $',HexStr(Addr,8),' hors limites');
  ReadWord:=0;
  Exit;
 End;
 Seek(Memory,Addr);
 BlockRead(Memory,W,2,ByteRead);
 ReadWord:=W;
End;

  { TODO 3 : Lecture d'un double mot 32 bits dans la memoire lineaire.
    Lit 4 octets consecutifs en little-endian a l'adresse donnee. }
Function ReadDWord(Addr:LongInt):LongInt;
Var
 D:LongInt;
 ByteRead:Word;
Begin
 If(Addr<0)or(Addr>MemorySize-4)Then Begin
  WriteLn('Erreur: ReadDWord adresse $',HexStr(Addr,8),' hors limites');
  ReadDWord:=0;
  Exit;
 End;
 Seek(Memory,Addr);
 BlockRead(Memory,D,4,ByteRead);
 ReadDWord:=D;
End;

  { TODO 3 : Ecriture d'un octet dans la memoire lineaire 32 bits.
    L'adresse est une adresse lineaire plate (flat) dans l'espace
    de 16 Mo. }
Procedure WriteByte(Addr:LongInt;Value:Byte);
Var
 ByteWrited:Word;
Begin
 If(Addr<0)or(Addr>=MemorySize)Then Begin
  WriteLn('Erreur: WriteByte adresse $',HexStr(Addr,8),' hors limites');
  Exit;
 End;
 Seek(Memory,Addr);
 BlockWrite(Memory,Value,1,ByteWrited);
End;

  { TODO 3 : Ecriture d'un mot 16 bits dans la memoire lineaire.
    Ecrit 2 octets consecutifs en little-endian a l'adresse donnee. }
Procedure WriteWord(Addr:LongInt;Value:Word);
Var
 ByteWrited:Word;
Begin
 If(Addr<0)or(Addr>MemorySize-2)Then Begin
  WriteLn('Erreur: WriteWord adresse $',HexStr(Addr,8),' hors limites');
  Exit;
 End;
 Seek(Memory,Addr);
 BlockWrite(Memory,Value,2,ByteWrited);
End;

  { TODO 3 : Ecriture d'un double mot 32 bits dans la memoire lineaire.
    Ecrit 4 octets consecutifs en little-endian a l'adresse donnee. }
Procedure WriteDWord(Addr:LongInt;Value:LongInt);
Var
 ByteWrited:Word;
Begin
 If(Addr<0)or(Addr>MemorySize-4)Then Begin
  WriteLn('Erreur: WriteDWord adresse $',HexStr(Addr,8),' hors limites');
  Exit;
 End;
 Seek(Memory,Addr);
 BlockWrite(Memory,Value,4,ByteWrited);
End;

  { TODO 4 : Empiler un double mot 32 bits sur la pile.
    Decremente ESP de 4, puis ecrit la valeur 32 bits a l'adresse
    pointee par ESP dans la memoire lineaire plate. }
Procedure Push32(Value:LongInt);
Begin
 Regs.ESP:=Regs.ESP-4;
 WriteDWord(Regs.ESP,Value);
End;

  { TODO 4 : Depiler un double mot 32 bits de la pile.
    Lit la valeur 32 bits a l'adresse pointee par ESP, puis
    incremente ESP de 4. }
Function Pop32:LongInt;
Begin
 Pop32:=ReadDWord(Regs.ESP);
 Regs.ESP:=Regs.ESP+4;
End;

  { TODO 4 : Empiler un mot 16 bits sur la pile.
    Decremente ESP de 2, puis ecrit la valeur 16 bits a l'adresse
    pointee par ESP dans la memoire lineaire plate. }
Procedure Push16(Value:Word);
Begin
 Regs.ESP:=Regs.ESP-2;
 WriteWord(Regs.ESP,Value);
End;

  { TODO 4 : Depiler un mot 16 bits de la pile.
    Lit la valeur 16 bits a l'adresse pointee par ESP, puis
    incremente ESP de 2. }
Function Pop16:Word;
Begin
 Pop16:=ReadWord(Regs.ESP);
 Regs.ESP:=Regs.ESP+2;
End;

  { TODO 7 : Lecture d'une chaine ASCII terminee par un zero
    depuis la memoire lineaire 32 bits. Retourne une String Pascal
    (max 255 caracteres). }
Function ReadStringFromMem(Addr:LongInt):String;
Var
 S:String;
 B:Byte;
 I:Integer;
Begin
 S:='';
 I:=0;
 While I<255 do Begin
  B:=ReadByte(Addr+LongInt(I));
  If B=0 Then Break;
  S:=S+Chr(B);
  Inc(I);
 End;
 ReadStringFromMem:=S;
End;

  { TODO 7 : Recherche d'une entree d'importation par son adresse
    de thunk dans la memoire lineaire. Retourne l'index dans
    ImportEntries ou -1 si non trouvee. }
Function FindImportByAddr(Addr:LongInt):Integer;
Var
 I:Integer;
Begin
 FindImportByAddr:=-1;
 For I:=0 to ImportCount-1 do
  If ImportEntries[I].ThunkAddr=Addr Then Begin
   FindImportByAddr:=I;
   Exit;
  End;
End;

  { TODO 6 : Chargement des sections PE dans la memoire lineaire.
    Lit les en-tetes IMAGE_SECTION_HEADER et copie les donnees de
    chaque section (.text, .data, .rdata, .idata) a l'adresse
    ImageBase + VirtualAddress. Les sections .bss (donnees non
    initialisees, Characteristics bit $80) sont remplies de zeros.
    Si VirtualSize > SizeOfRawData, le surplus est mis a zero. }
Function LoadPESections(Var F:File):Boolean;
Const
 LoadBufSize=4096;
Var
 I:Integer;
 SecName:String;
 LoadAddr,Remaining:LongInt;
 ChunkSize:Word;
 LoadBuf:Array[0..LoadBufSize-1]of Byte;
 ByteRead,ByteWrited:Word;
 J,K:LongInt;
Begin
 LoadPESections:=False;
 PENumSections:=PEFileHeader.NumberOfSections;
 If PENumSections>MaxPESections Then Begin
  WriteLn('LoadPESections: trop de sections (',PENumSections,')');
  Exit;
 End;
  { Se positionner au debut de la table des en-tetes de section.
    Position = e_lfanew + 4 (signature PE) + 20 (COFF header) +
    SizeOfOptionalHeader (en-tete optionnel complet avec repertoires) }
 Seek(F,PEDosHeader.e_lfanew+4+SizeOf(TImageFileHeader)+
        LongInt(PEFileHeader.SizeOfOptionalHeader));
  { Lire les en-tetes de section }
 For I:=0 to PENumSections-1 do Begin
  BlockRead(F,PESections[I],SizeOf(TImageSectionHeader),ByteRead);
  If ByteRead<>SizeOf(TImageSectionHeader)Then Begin
   WriteLn('LoadPESections: erreur lecture en-tete section ',I);
   Exit;
  End;
 End;
  { Charger chaque section dans la memoire lineaire }
 For I:=0 to PENumSections-1 do Begin
   { Extraire le nom de la section (max 8 caracteres, termine par #0) }
  SecName:='';
  For K:=0 to 7 do Begin
   If PESections[I].Name[K]=#0 Then Break;
   SecName:=SecName+PESections[I].Name[K];
  End;
   { Adresse de chargement = ImageBase + RVA de la section }
  LoadAddr:=PEOptHeader.ImageBase+PESections[I].VirtualAddress;
  WriteLn('LoadPESections: "',SecName,
          '" RVA=$',HexStr(PESections[I].VirtualAddress,8),
          ' VSize=$',HexStr(PESections[I].VirtualSize,8),
          ' Raw=$',HexStr(PESections[I].SizeOfRawData,8),
          ' -> $',HexStr(LoadAddr,8));
   { Verifier que la section tient dans l'espace de 16 Mo }
  If(LoadAddr<0)or(LoadAddr+PESections[I].VirtualSize>MemorySize)Then Begin
   WriteLn('LoadPESections: section "',SecName,'" depasse la memoire');
   Exit;
  End;
   { Section .bss (donnees non initialisees) : remplir de zeros }
  If(PESections[I].Characteristics and $00000080)<>0 Then Begin
   WriteLn('LoadPESections: "',SecName,'" (bss) remplissage zeros');
   FillChar(LoadBuf,SizeOf(LoadBuf),0);
   Remaining:=PESections[I].VirtualSize;
   J:=LoadAddr;
   While Remaining>0 do Begin
    If Remaining>LoadBufSize Then ChunkSize:=LoadBufSize
    Else ChunkSize:=Word(Remaining);
    Seek(Memory,J);
    BlockWrite(Memory,LoadBuf,ChunkSize,ByteWrited);
    J:=J+LongInt(ChunkSize);
    Remaining:=Remaining-LongInt(ChunkSize);
   End;
  End
  Else If PESections[I].SizeOfRawData>0 Then Begin
    { Copier les donnees brutes du fichier vers la memoire lineaire }
   Seek(F,PESections[I].PointerToRawData);
   Remaining:=PESections[I].SizeOfRawData;
   J:=LoadAddr;
   While Remaining>0 do Begin
    If Remaining>LoadBufSize Then ChunkSize:=LoadBufSize
    Else ChunkSize:=Word(Remaining);
    BlockRead(F,LoadBuf,ChunkSize,ByteRead);
    If ByteRead<>ChunkSize Then Begin
     WriteLn('LoadPESections: erreur lecture "',SecName,'"');
     Exit;
    End;
    Seek(Memory,J);
    BlockWrite(Memory,LoadBuf,ChunkSize,ByteWrited);
    J:=J+LongInt(ChunkSize);
    Remaining:=Remaining-LongInt(ChunkSize);
   End;
    { Si VirtualSize > SizeOfRawData, remplir le reste de zeros }
   If PESections[I].VirtualSize>PESections[I].SizeOfRawData Then Begin
    FillChar(LoadBuf,SizeOf(LoadBuf),0);
    Remaining:=PESections[I].VirtualSize-PESections[I].SizeOfRawData;
    While Remaining>0 do Begin
     If Remaining>LoadBufSize Then ChunkSize:=LoadBufSize
     Else ChunkSize:=Word(Remaining);
     Seek(Memory,J);
     BlockWrite(Memory,LoadBuf,ChunkSize,ByteWrited);
     J:=J+LongInt(ChunkSize);
     Remaining:=Remaining-LongInt(ChunkSize);
    End;
   End;
  End;
 End;
 LoadPESections:=True;
 WriteLn('LoadPESections: ',PENumSections,' section(s) chargee(s).');
End;

  { TODO 7 : Lecture des repertoires de donnees PE depuis le fichier.
    Les repertoires (IMAGE_DATA_DIRECTORY, 8 octets chacun) suivent
    immediatement les champs standard de l'en-tete optionnel PE32.
    Ils incluent notamment le repertoire d'importation (index 1). }
Function LoadPEDataDirs(Var F:File):Boolean;
Var
 I:Integer;
 ByteRead:Word;
Begin
 LoadPEDataDirs:=False;
 PENumDataDirs:=PEOptHeader.NumberOfRvaAndSizes;
 If PENumDataDirs>MaxDataDirs Then PENumDataDirs:=MaxDataDirs;
 If PENumDataDirs<=0 Then Begin
  WriteLn('LoadPEDataDirs: pas de repertoire de donnees');
  LoadPEDataDirs:=True;
  Exit;
 End;
 For I:=0 to PENumDataDirs-1 do Begin
  BlockRead(F,PEDataDirs[I],SizeOf(TImageDataDirectory),ByteRead);
  If ByteRead<>SizeOf(TImageDataDirectory)Then Begin
   WriteLn('LoadPEDataDirs: erreur lecture repertoire ',I);
   Exit;
  End;
 End;
 WriteLn('LoadPEDataDirs: ',PENumDataDirs,' repertoire(s) lu(s).');
 If PENumDataDirs>=2 Then
  WriteLn('  Import Directory: RVA=$',HexStr(PEDataDirs[1].VirtualAddress,8),
          ' Size=',PEDataDirs[1].Size);
 LoadPEDataDirs:=True;
End;

  { TODO 7 : Traitement de la table d'importation PE.
    Parcourt l'Import Directory Table dans la memoire lineaire chargee,
    lit chaque IMAGE_IMPORT_DESCRIPTOR, extrait les noms de DLL et de
    fonctions (ou les numeros d'ordinal), et remplit l'Import Address
    Table (IAT) avec des adresses de thunks internes. Chaque thunk
    est une adresse unique dans la zone ThunkBase qui sera interceptee
    par la boucle d'execution pour rediriger vers l'emulation. }
Function ProcessImports:Boolean;
Var
 ImportRVA,ImportSize:LongInt;
 ImpAddr:LongInt;
 DLLName:String;
 ThunkRVA,LookupRVA:LongInt;
 ThunkVal:LongInt;
 HintAddr:LongInt;
 FuncName:String;
 NextThunk:LongInt;
Begin
 ProcessImports:=False;
 ImportCount:=0;
  { Verifier que le repertoire d'importation existe (index 1) }
 If PENumDataDirs<2 Then Begin
  WriteLn('ProcessImports: pas de repertoire d''importation');
  ProcessImports:=True;
  Exit;
 End;
 ImportRVA:=PEDataDirs[1].VirtualAddress;
 ImportSize:=PEDataDirs[1].Size;
 If(ImportRVA=0)or(ImportSize=0)Then Begin
  WriteLn('ProcessImports: table d''importation vide');
  ProcessImports:=True;
  Exit;
 End;
 WriteLn('ProcessImports: Import Directory RVA=$',HexStr(ImportRVA,8),
         ' Size=',ImportSize);
 NextThunk:=ThunkBase;
 ImpAddr:=PEOptHeader.ImageBase+ImportRVA;
  { Parcourir les IMAGE_IMPORT_DESCRIPTOR (20 octets chacun)
    jusqu'a un descripteur entierement nul }
 Repeat
   { Lire les champs du descripteur depuis la memoire lineaire }
  ThunkVal:=ReadDWord(ImpAddr);      { OriginalFirstThunk }
  LookupRVA:=ThunkVal;
  ThunkVal:=ReadDWord(ImpAddr+12);   { Name }
  If(ThunkVal=0)Then Break;          { Fin de la table }
  ThunkRVA:=ReadDWord(ImpAddr+16);   { FirstThunk }
  If(ThunkRVA=0)Then Break;
   { Lire le nom de la DLL }
  DLLName:=ReadStringFromMem(PEOptHeader.ImageBase+ThunkVal);
  WriteLn('ProcessImports: DLL "',DLLName,'"');
   { Utiliser OriginalFirstThunk (ILT) si disponible, sinon FirstThunk }
  If LookupRVA=0 Then LookupRVA:=ThunkRVA;
   { Parcourir les entrees de la table d'importation }
  While True do Begin
   ThunkVal:=ReadDWord(PEOptHeader.ImageBase+LookupRVA);
   If ThunkVal=0 Then Break;  { Fin de la liste }
   If ImportCount>=MaxImportFuncs Then Begin
    WriteLn('ProcessImports: trop de fonctions importees');
    Exit;
   End;
   ImportEntries[ImportCount].DLLName:=DLLName;
    { Verifier si c'est un import par ordinal (bit 31 = signe negatif) }
   If ThunkVal<0 Then Begin
    ImportEntries[ImportCount].Ordinal:=Word(ThunkVal and $FFFF);
    ImportEntries[ImportCount].ByOrdinal:=True;
    ImportEntries[ImportCount].FuncName:='';
    WriteLn('  Ordinal #',ImportEntries[ImportCount].Ordinal);
   End
   Else Begin
     { Import par nom : ThunkVal est un RVA vers IMAGE_IMPORT_BY_NAME }
    HintAddr:=PEOptHeader.ImageBase+ThunkVal;
    FuncName:=ReadStringFromMem(HintAddr+2);
    ImportEntries[ImportCount].Ordinal:=ReadWord(HintAddr);
    ImportEntries[ImportCount].ByOrdinal:=False;
    ImportEntries[ImportCount].FuncName:=FuncName;
    WriteLn('  ',FuncName,' (hint=',ImportEntries[ImportCount].Ordinal,')');
   End;
    { Assigner un thunk interne }
   ImportEntries[ImportCount].ThunkAddr:=NextThunk;
    { Ecrire l'adresse du thunk dans la IAT en memoire }
   WriteDWord(PEOptHeader.ImageBase+ThunkRVA,NextThunk);
    { Ecrire INT3 ($CC) + RET ($C3) au thunk pour pieger l'appel }
   WriteByte(NextThunk,$CC);
   WriteByte(NextThunk+1,$C3);
   Inc(ImportCount);
   NextThunk:=NextThunk+16;  { Espacement de 16 octets entre thunks }
   LookupRVA:=LookupRVA+4;
   ThunkRVA:=ThunkRVA+4;
  End;
  ImpAddr:=ImpAddr+20;  { Prochain descripteur }
 Until False;
 ProcessImports:=True;
 WriteLn('ProcessImports: ',ImportCount,' fonction(s) importee(s) resolue(s).');
End;

  { TODO 5 : Chargeur de fichiers PE (Portable Executable).
    Lit l'en-tete MZ/DOS stub, la signature PE, l'en-tete COFF
    (IMAGE_FILE_HEADER) et l'en-tete optionnel (IMAGE_OPTIONAL_HEADER32)
    incluant AddressOfEntryPoint, ImageBase, SectionAlignment et
    SizeOfStackReserve. Retourne True si le fichier est un PE valide. }
Function LoadPE(FileName:String):Boolean;
Var
 F:File;
 PESig:LongInt;
 ByteRead:Word;
Begin
 LoadPE:=False;
 PELoaded:=False;
  { Ouvrir le fichier PE }
 {$I-}Assign(F,FileName);
 Reset(F,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('LoadPE: impossible d''ouvrir "',FileName,'"');
  Exit;
 End;
  { Verifier que le fichier est assez grand pour l'en-tete DOS }
 If FileSize(F)<SizeOf(TImageDosHeader)Then Begin
  WriteLn('LoadPE: fichier trop petit pour un en-tete DOS MZ');
  Close(F);
  Exit;
 End;
  { Lire l'en-tete DOS MZ (64 octets) }
 BlockRead(F,PEDosHeader,SizeOf(TImageDosHeader),ByteRead);
 If ByteRead<>SizeOf(TImageDosHeader)Then Begin
  WriteLn('LoadPE: erreur de lecture de l''en-tete DOS');
  Close(F);
  Exit;
 End;
  { Verifier la signature MZ }
 If PEDosHeader.e_magic<>$5A4D Then Begin
  WriteLn('LoadPE: signature MZ invalide ($',HexStr(PEDosHeader.e_magic,4),
          ' au lieu de $5A4D)');
  Close(F);
  Exit;
 End;
 WriteLn('LoadPE: En-tete DOS MZ valide, e_lfanew=$',
         HexStr(PEDosHeader.e_lfanew,8));
  { Verifier que e_lfanew pointe vers une position valide }
 If(PEDosHeader.e_lfanew<$40)or
   (PEDosHeader.e_lfanew>=FileSize(F)-4)Then Begin
  WriteLn('LoadPE: e_lfanew invalide ($',HexStr(PEDosHeader.e_lfanew,8),')');
  Close(F);
  Exit;
 End;
  { Se positionner a l'offset de la signature PE }
 Seek(F,PEDosHeader.e_lfanew);
  { Lire la signature PE (4 octets : 'PE\0\0' = $00004550) }
 BlockRead(F,PESig,4,ByteRead);
 If ByteRead<>4 Then Begin
  WriteLn('LoadPE: erreur de lecture de la signature PE');
  Close(F);
  Exit;
 End;
 If PESig<>$00004550 Then Begin
  WriteLn('LoadPE: signature PE invalide ($',HexStr(PESig,8),
          ' au lieu de $00004550)');
  Close(F);
  Exit;
 End;
 WriteLn('LoadPE: Signature PE valide.');
  { Lire l'en-tete COFF (IMAGE_FILE_HEADER, 20 octets) }
 BlockRead(F,PEFileHeader,SizeOf(TImageFileHeader),ByteRead);
 If ByteRead<>SizeOf(TImageFileHeader)Then Begin
  WriteLn('LoadPE: erreur de lecture de l''en-tete COFF');
  Close(F);
  Exit;
 End;
  { Verifier que c'est bien une machine i386 }
 If PEFileHeader.Machine<>$014C Then Begin
  WriteLn('LoadPE: machine non supportee ($',HexStr(PEFileHeader.Machine,4),
          ', attendu $014C pour i386)');
  Close(F);
  Exit;
 End;
 WriteLn('LoadPE: En-tete COFF - Machine=i386, Sections=',
         PEFileHeader.NumberOfSections,
         ', OptHdrSize=',PEFileHeader.SizeOfOptionalHeader);
  { Verifier que l'en-tete optionnel est present et assez grand }
 If PEFileHeader.SizeOfOptionalHeader<SizeOf(TImageOptionalHeader32)Then Begin
  WriteLn('LoadPE: en-tete optionnel trop petit (',
          PEFileHeader.SizeOfOptionalHeader,' octets, minimum ',
          SizeOf(TImageOptionalHeader32),')');
  Close(F);
  Exit;
 End;
  { Lire l'en-tete optionnel PE32 (IMAGE_OPTIONAL_HEADER32, 96 octets) }
 BlockRead(F,PEOptHeader,SizeOf(TImageOptionalHeader32),ByteRead);
 If ByteRead<>SizeOf(TImageOptionalHeader32)Then Begin
  WriteLn('LoadPE: erreur de lecture de l''en-tete optionnel');
  Close(F);
  Exit;
 End;
  { Verifier la signature PE32 }
 If PEOptHeader.Magic<>$010B Then Begin
  WriteLn('LoadPE: magic optionnel invalide ($',HexStr(PEOptHeader.Magic,4),
          ', attendu $010B pour PE32)');
  Close(F);
  Exit;
 End;
  { Afficher les champs principaux de l'en-tete optionnel }
 WriteLn('LoadPE: En-tete optionnel PE32 :');
 WriteLn('  AddressOfEntryPoint = $',HexStr(PEOptHeader.AddressOfEntryPoint,8));
 WriteLn('  ImageBase           = $',HexStr(PEOptHeader.ImageBase,8));
 WriteLn('  SectionAlignment    = $',HexStr(PEOptHeader.SectionAlignment,8));
 WriteLn('  FileAlignment       = $',HexStr(PEOptHeader.FileAlignment,8));
 WriteLn('  SizeOfImage         = $',HexStr(PEOptHeader.SizeOfImage,8));
 WriteLn('  SizeOfHeaders       = $',HexStr(PEOptHeader.SizeOfHeaders,8));
 WriteLn('  SizeOfStackReserve  = $',HexStr(PEOptHeader.SizeOfStackReserve,8));
 WriteLn('  SizeOfStackCommit   = $',HexStr(PEOptHeader.SizeOfStackCommit,8));
 WriteLn('  Subsystem           = ',PEOptHeader.Subsystem);
 WriteLn('  NumberOfRvaAndSizes = ',PEOptHeader.NumberOfRvaAndSizes);
  { TODO 7 : Lire les repertoires de donnees PE }
 If Not LoadPEDataDirs(F)Then Begin
  WriteLn('LoadPE: echec de la lecture des repertoires de donnees');
  Close(F);
  Exit;
 End;
  { TODO 6 : Charger les sections PE dans la memoire lineaire }
 If Not LoadPESections(F)Then Begin
  WriteLn('LoadPE: echec du chargement des sections');
  Close(F);
  Exit;
 End;
 Close(F);
  { TODO 7 : Traiter la table d'importation }
 If Not ProcessImports Then Begin
  WriteLn('LoadPE: echec du traitement des importations');
  PELoaded:=False;
  LoadPE:=False;
  Exit;
 End;
 PELoaded:=True;
 LoadPE:=True;
 WriteLn('LoadPE: Fichier PE charge avec succes.');
End;

  { TODO 8 : Acces aux registres generaux 32 bits par index (0-7).
    Codage x86 : 0=EAX, 1=ECX, 2=EDX, 3=EBX, 4=ESP, 5=EBP,
    6=ESI, 7=EDI. Correspond directement a Regs.Abs[0..7]. }
Function GetReg32(Index:Byte):LongInt;
Begin
 GetReg32:=Regs.Abs[Index];
End;

Procedure SetReg32(Index:Byte;Value:LongInt);
Begin
 Regs.Abs[Index]:=Value;
End;

  { TODO 8 : Acces aux registres 16 bits par index (0-7).
    Codage x86 : 0=AX, 1=CX, 2=DX, 3=BX, 4=SP, 5=BP, 6=SI, 7=DI.
    Correspond a la partie basse (Lo) de Regs.AbsWord[0..7]. }
Function GetReg16(Index:Byte):Word;
Begin
 GetReg16:=Regs.AbsWord[Index].Lo;
End;

Procedure SetReg16(Index:Byte;Value:Word);
Begin
 Regs.AbsWord[Index].Lo:=Value;
End;

  { TODO 8 : Acces aux registres 8 bits par index (0-7).
    Codage x86 : 0=AL, 1=CL, 2=DL, 3=BL, 4=AH, 5=CH, 6=DH, 7=BH }
Function GetReg8(Index:Byte):Byte;
Begin
 Case Index of
  0:GetReg8:=Regs.AL;
  1:GetReg8:=Regs.CL;
  2:GetReg8:=Regs.DL;
  3:GetReg8:=Regs.BL;
  4:GetReg8:=Regs.AH;
  5:GetReg8:=Regs.CH;
  6:GetReg8:=Regs.DH;
  7:GetReg8:=Regs.BH;
  Else GetReg8:=0;
 End;
End;

Procedure SetReg8(Index:Byte;Value:Byte);
Begin
 Case Index of
  0:Regs.AL:=Value;
  1:Regs.CL:=Value;
  2:Regs.DL:=Value;
  3:Regs.BL:=Value;
  4:Regs.AH:=Value;
  5:Regs.CH:=Value;
  6:Regs.DH:=Value;
  7:Regs.BH:=Value;
 End;
End;

  { TODO 8 : Decodage de l'octet ModR/M et calcul de l'adresse effective.
    Lit l'octet ModR/M a l'adresse EIP, avance EIP, et retourne
    les champs mod (bits 7-6), reg (bits 5-3) et r/m (bits 2-0).
    Si necessaire, lit l'octet SIB et/ou un deplacement (disp8/disp32).
    EffAddr contient l'adresse memoire calculee si mod <> 11.
    IsMemory est True si l'operande r/m est une reference memoire. }
Procedure DecodeModRM(Var ModField,RegField,RMField:Byte;
                      Var EffAddr:LongInt;Var IsMemory:Boolean);
Var
 ModRM,SIBByte:Byte;
 Base,Index,Scale:Byte;
 BaseVal,IndexVal:LongInt;
 Disp8:ShortInt;
 Disp32:LongInt;
Begin
 ModRM:=ReadByte(EIP);
 Inc(EIP);
 ModField:=(ModRM shr 6) and 3;
 RegField:=(ModRM shr 3) and 7;
 RMField:=ModRM and 7;
 EffAddr:=0;
 IsMemory:=(ModField<>3);
 If ModField=3 Then Exit;  { Registre a registre, pas d'adresse effective }
  { Mode memoire : calculer l'adresse effective }
 If RMField=4 Then Begin
   { Octet SIB present (r/m=100 en mode memoire) }
  SIBByte:=ReadByte(EIP);
  Inc(EIP);
  Scale:=(SIBByte shr 6) and 3;
  Index:=(SIBByte shr 3) and 7;
  Base:=SIBByte and 7;
   { Calculer la valeur du registre de base.
     Si base=5 et mod=00, pas de registre de base (disp32 suit). }
  If(Base=5)and(ModField=0)Then
   BaseVal:=0
  Else
   BaseVal:=GetReg32(Base);
   { Calculer la valeur du registre d'index.
     Index=4 (ESP) signifie qu'il n'y a pas d'index. }
  If Index=4 Then
   IndexVal:=0
  Else Begin
   IndexVal:=GetReg32(Index);
   Case Scale of
    1:IndexVal:=IndexVal*2;
    2:IndexVal:=IndexVal*4;
    3:IndexVal:=IndexVal*8;
   End;
  End;
  EffAddr:=BaseVal+IndexVal;
   { Ajouter le deplacement selon le champ mod }
  If(Base=5)and(ModField=0)Then Begin
    { SIB avec base=5 et mod=00 : disp32 sans registre de base }
   Disp32:=ReadDWord(EIP);
   Inc(EIP,4);
   EffAddr:=EffAddr+Disp32;
  End
  Else If ModField=1 Then Begin
   Disp8:=ShortInt(ReadByte(EIP));
   Inc(EIP);
   EffAddr:=EffAddr+LongInt(Disp8);
  End
  Else If ModField=2 Then Begin
   Disp32:=ReadDWord(EIP);
   Inc(EIP,4);
   EffAddr:=EffAddr+Disp32;
  End;
 End
 Else Begin
   { Pas de SIB }
  If(ModField=0)and(RMField=5)Then Begin
    { mod=00, r/m=101 : adresse directe disp32 }
   Disp32:=ReadDWord(EIP);
   Inc(EIP,4);
   EffAddr:=Disp32;
  End
  Else Begin
   EffAddr:=GetReg32(RMField);
   If ModField=1 Then Begin
    Disp8:=ShortInt(ReadByte(EIP));
    Inc(EIP);
    EffAddr:=EffAddr+LongInt(Disp8);
   End
   Else If ModField=2 Then Begin
    Disp32:=ReadDWord(EIP);
    Inc(EIP,4);
    EffAddr:=EffAddr+Disp32;
   End;
  End;
 End;
End;

  { TODO 8 : MOV r/m8, r8 (opcode $88).
    Copie le registre 8 bits reg dans r/m8 (registre ou memoire). }
Procedure OpMovRM8R8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then
  WriteByte(Eff,GetReg8(RegF))
 Else
  SetReg8(RMF,GetReg8(RegF));
End;

  { TODO 8 : MOV r8, r/m8 (opcode $8A).
    Copie r/m8 (registre ou memoire) dans le registre 8 bits reg. }
Procedure OpMovR8RM8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then
  SetReg8(RegF,ReadByte(Eff))
 Else
  SetReg8(RegF,GetReg8(RMF));
End;

  { TODO 8 : MOV r/m32, r32 (opcode $89).
    Copie le registre 32 bits reg dans r/m32 (registre ou memoire).
    Gere les modes d'adressage ModR/M et SIB du 80386. }
Procedure OpMovRM32R32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then
  WriteDWord(Eff,GetReg32(RegF))
 Else
  SetReg32(RMF,GetReg32(RegF));
End;

  { TODO 8 : MOV r32, r/m32 (opcode $8B).
    Copie r/m32 (registre ou memoire) dans le registre 32 bits reg.
    Gere les modes d'adressage ModR/M et SIB du 80386. }
Procedure OpMovR32RM32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then
  SetReg32(RegF,ReadDWord(Eff))
 Else
  SetReg32(RegF,GetReg32(RMF));
End;

  { TODO 8 : MOV r/m8, imm8 (opcode $C6 /0).
    Charge une valeur immediate 8 bits dans r/m8. }
Procedure OpMovRM8Imm8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Imm:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 Imm:=ReadByte(EIP);
 Inc(EIP);
 If IsMem Then
  WriteByte(Eff,Imm)
 Else
  SetReg8(RMF,Imm);
End;

  { TODO 8 : MOV r/m32, imm32 (opcode $C7 /0).
    Charge une valeur immediate 32 bits dans r/m32. }
Procedure OpMovRM32Imm32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Imm:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 Imm:=ReadDWord(EIP);
 Inc(EIP,4);
 If IsMem Then
  WriteDWord(Eff,Imm)
 Else
  SetReg32(RMF,Imm);
End;

  { TODO 8 : MOV r8, imm8 (opcode $B0+r).
    Charge une valeur immediate 8 bits dans le registre r8. }
Procedure OpMovR8Imm8(RegIdx:Byte);
Var
 Imm:Byte;
Begin
 Imm:=ReadByte(EIP);
 Inc(EIP);
 SetReg8(RegIdx,Imm);
End;

  { TODO 8 : MOV r32, imm32 (opcode $B8+r).
    Charge une valeur immediate 32 bits dans le registre r32. }
Procedure OpMovR32Imm32(RegIdx:Byte);
Var
 Imm:LongInt;
Begin
 Imm:=ReadDWord(EIP);
 Inc(EIP,4);
 SetReg32(RegIdx,Imm);
End;

  { TODO 8 : MOVZX r32, r/m8 (opcode $0F $B6).
    Extension a zero d'un octet vers un double mot 32 bits.
    Lit un operande 8 bits et l'etend a 32 bits sans signe. }
Procedure OpMovzxR32RM8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then
  Val:=ReadByte(Eff)
 Else
  Val:=GetReg8(RMF);
 SetReg32(RegF,LongInt(Val));
End;

  { TODO 8 : MOVZX r32, r/m16 (opcode $0F $B7).
    Extension a zero d'un mot 16 bits vers un double mot 32 bits.
    Lit un operande 16 bits et l'etend a 32 bits sans signe. }
Procedure OpMovzxR32RM16;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:Word;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then
  Val:=ReadWord(Eff)
 Else
  Val:=GetReg16(RMF);
 SetReg32(RegF,LongInt(Val));
End;

  { TODO 8 : MOVSX r32, r/m8 (opcode $0F $BE).
    Extension de signe d'un octet vers un double mot 32 bits.
    Lit un operande 8 bits signe et l'etend a 32 bits avec signe. }
Procedure OpMovsxR32RM8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:ShortInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then
  Val:=ShortInt(ReadByte(Eff))
 Else
  Val:=ShortInt(GetReg8(RMF));
 SetReg32(RegF,LongInt(Val));
End;

  { TODO 8 : MOVSX r32, r/m16 (opcode $0F $BF).
    Extension de signe d'un mot 16 bits vers un double mot 32 bits.
    Lit un operande 16 bits signe et l'etend a 32 bits avec signe. }
Procedure OpMovsxR32RM16;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:Integer;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then
  Val:=Integer(ReadWord(Eff))
 Else
  Val:=Integer(GetReg16(RMF));
 SetReg32(RegF,LongInt(Val));
End;

  { TODO 8 : LEA r32, m (opcode $8D).
    Load Effective Address : calcule l'adresse effective de l'operande
    memoire r/m et la charge dans le registre reg32, sans acceder
    a la memoire. }
Procedure OpLea;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 SetReg32(RegF,Eff);
End;

  { TODO 8 : XCHG r/m32, r32 (opcode $87).
    Echange le contenu du registre reg32 avec r/m32 (registre ou
    memoire). Operation atomique sur le bus memoire en x86 reel. }
Procedure OpXchgRM32R32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Tmp:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Begin
  Tmp:=ReadDWord(Eff);
  WriteDWord(Eff,GetReg32(RegF));
  SetReg32(RegF,Tmp);
 End
 Else Begin
  Tmp:=GetReg32(RMF);
  SetReg32(RMF,GetReg32(RegF));
  SetReg32(RegF,Tmp);
 End;
End;

  { TODO 8 : XCHG EAX, r32 (opcode $90+r).
    Echange le contenu de EAX avec le registre r32 specifie.
    Le cas special $90 (r=0, XCHG EAX,EAX) est traite comme NOP. }
Procedure OpXchgEAXR32(RegIdx:Byte);
Var
 Tmp:LongInt;
Begin
 If RegIdx=0 Then Exit;  { NOP : XCHG EAX,EAX }
 Tmp:=Regs.EAX;
 Regs.EAX:=GetReg32(RegIdx);
 SetReg32(RegIdx,Tmp);
End;

  { TODO 8 : BSWAP r32 (opcode $0F $C8+r).
    Byte Swap : inverse l'ordre des 4 octets d'un registre 32 bits.
    Convertit entre big-endian et little-endian. }
Procedure OpBswap(RegIdx:Byte);
Var
 Val:LongInt;
 B0,B1,B2,B3:Byte;
Begin
 Val:=GetReg32(RegIdx);
 B0:=Byte(Val);
 B1:=Byte(Val shr 8);
 B2:=Byte(Val shr 16);
 B3:=Byte(Val shr 24);
 SetReg32(RegIdx,(LongInt(B0) shl 24) or (LongInt(B1) shl 16) or
                 (LongInt(B2) shl 8) or LongInt(B3));
End;

  { TODO 8 : XCHG r/m8, r8 (opcode $86).
    Echange le contenu du registre r8 avec r/m8 (registre ou memoire). }
Procedure OpXchgRM8R8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Tmp:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Begin
  Tmp:=ReadByte(Eff);
  WriteByte(Eff,GetReg8(RegF));
  SetReg8(RegF,Tmp);
 End
 Else Begin
  Tmp:=GetReg8(RMF);
  SetReg8(RMF,GetReg8(RegF));
  SetReg8(RegF,Tmp);
 End;
End;

  { TODO 1 : Procedure d'initialisation de la memoire lineaire.
    Cree le fichier d'echange de 16 Mo (EMUW32.$$$) et le remplit
    de zeros pour simuler un espace d'adressage plat Win32. }
Procedure Init;
Var
 J:LongInt;
 ByteWrited:Word;
Begin
 {$I-}Assign(Memory,SwapFileMemory);
 Rewrite(Memory,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de creer un fichier temporaire pour la memoire');
  Halt(1);
 End;
 WriteLn('Creation du fichier d''echange de 16 Mo...');
 FillChar(ClrBuffer,SizeOf(ClrBuffer),0);
 For J:=0 to ClearBlockCount-1 do Begin
  Seek(Memory,J*LongInt(ClearBufferSize));
  BlockWrite(Memory,ClrBuffer,ClearBufferSize,ByteWrited);
  If ByteWrited<>ClearBufferSize Then Begin
   WriteLn('Erreur d''ecriture lors de l''initialisation de la memoire');
   Close(Memory);
   Halt(1);
  End;
 End;
 WriteLn('Fichier d''echange de 16 Mo cree avec succes.');
  { TODO 4 : Initialiser les registres et le pointeur de pile.
    ESP pointe au sommet de la zone de pile (MemorySize = 16 Mo).
    La pile croit vers le bas de MemorySize vers StackBase. }
 FillChar(Regs,SizeOf(Regs),0);
 EIP:=0;
 EFlags.Abs:=0;
 Regs.ESP:=MemorySize;  { Sommet de pile : 16 Mo }
 WriteLn('Pile de 1 Mo allouee (ESP=$',HexStr(Regs.ESP,8),
         ', base=$',HexStr(StackBase,8),').');
End;

BEGIN
 Init;
 WriteLn('EMUW32 : Memoire lineaire de 16 Mo initialisee.');
  { Fermer et supprimer le fichier d'echange }
 {$I-}Close(Memory);{$I+}
 If IOResult<>0 Then
  WriteLn('EMUW32 : Avertissement - erreur lors de la fermeture du fichier d''echange.');
 {$I-}Assign(Memory,SwapFileMemory);
 Erase(Memory);{$I+}
 If IOResult<>0 Then
  WriteLn('EMUW32 : Avertissement - impossible de supprimer le fichier d''echange.');
END.
