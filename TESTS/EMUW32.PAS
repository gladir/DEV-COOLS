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

  9.  [IMPLEMENTE] Implementer les instructions arithmetiques 32 bits : ADD, SUB,
      ADC, SBB, CMP, INC, DEC, NEG, MUL, IMUL, DIV, IDIV sur des
      operandes 8/16/32 bits avec mise a jour correcte des drapeaux
      (CF, ZF, SF, OF, AF, PF) dans EFLAGS.

  10. [IMPLEMENTE] Implementer les instructions logiques et de decalage 32 bits :
      AND, OR, XOR, NOT, TEST, SHL, SHR, SAR, ROL, ROR, RCL, RCR,
      BT, BTS, BTR, BTC, BSF, BSR sur des operandes 32 bits.

  11. [IMPLEMENTE] Implementer les instructions de chaines 32 bits : MOVSD, STOSD,
      LODSD, CMPSD, SCASD ainsi que les prefixes REP/REPE/REPNE
      utilisant ECX comme compteur, et les variantes 8/16 bits.

  12. [IMPLEMENTE] Implementer les instructions de saut conditionnel 32 bits (Jcc
      near avec deplacement rel32, prefixe 0Fh) et les sauts
      inconditionnels JMP rel32/JMP [mem] en mode plat.

  13. [IMPLEMENTE] Implementer CALL rel32, CALL [mem], RET, RET imm16 en mode
      plat 32 bits avec empilement/depilement de EIP sur la pile,
      incluant les appels indirects via registre (CALL EAX, etc.).

  14. [IMPLEMENTE] Implementer les instructions SET conditionnel (SETcc), CMOVcc
      (conditional move du 80686/Pentium Pro), CDQ, CBW, CWDE, CLC,
      STC, CMC, CLD, STD, NOP, LEAVE, ENTER et INT3 (breakpoint).

  15. [IMPLEMENTE] Implementer l'emulation de KERNEL32.DLL - Gestion de processus
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

  { TODO 15 : Constantes Win32 pour GetStdHandle }
 STD_INPUT_HANDLE=LongInt(-10);
 STD_OUTPUT_HANDLE=LongInt(-11);
 STD_ERROR_HANDLE=LongInt(-12);

  { TODO 15 : Handles emules pour stdin, stdout, stderr }
 EMU_STDIN_HANDLE=1;
 EMU_STDOUT_HANDLE=2;
 EMU_STDERR_HANDLE=3;

  { TODO 15 : PID fictif du processus emule }
 EMU_PROCESS_ID=1000;

  { TODO 15 : Pseudo-handle du processus courant }
 EMU_CURRENT_PROCESS=LongInt(-1);

  { TODO 15 : Zone de donnees pour les chaines du processus emule.
    Utilise la zone $D00000-$DFFFFF (1 Mo) juste avant les thunks. }
 ProcessDataBase=$D00000;

  { TODO 15 : Taille de la structure STARTUPINFOA (68 octets) }
 STARTUPINFOA_SIZE=68;

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

  { TODO 15 : Adresse en memoire lineaire de la chaine de commande ASCII }
 CmdLineAddrA:LongInt;
  { TODO 15 : Adresse en memoire lineaire de la chaine de commande Unicode }
 CmdLineAddrW:LongInt;
  { TODO 15 : Adresse en memoire lineaire de la structure STARTUPINFOA }
 StartupInfoAddr:LongInt;
  { TODO 15 : Code de sortie du processus emule }
 EmuExitCode:LongInt;
  { TODO 15 : Indicateur d'arret du processus par ExitProcess }
 EmuRunning:Boolean;

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

  { TODO 9 : Calcul de la parite du byte de poids faible.
    Retourne True si le nombre de bits a 1 dans l'octet est pair
    (PF=1 selon la convention x86). }
Function Parity8(Value:Byte):Boolean;
Var
 I,Count:Byte;
Begin
 Count:=0;
 For I:=0 to 7 do
  If(Value and (1 shl I))<>0 Then Inc(Count);
 Parity8:=(Count mod 2)=0;
End;

  { TODO 9 : Addition 8 bits avec mise a jour de tous les drapeaux.
    Calcule A + B, met a jour CF, ZF, SF, OF, AF, PF dans EFLAGS
    et retourne le resultat tronque sur 8 bits. }
Function ArithAdd8(A,B:Byte):Byte;
Var
 Res:Word;
 R8:Byte;
Begin
 Res:=Word(A)+Word(B);
 R8:=Byte(Res);
 If Res>255 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 If R8=0 Then EFlags.s:=EFlags.s+[ZF]
 Else EFlags.s:=EFlags.s-[ZF];
 If(R8 and $80)<>0 Then EFlags.s:=EFlags.s+[SF]
 Else EFlags.s:=EFlags.s-[SF];
 If((A xor R8)and(B xor R8)and $80)<>0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If((A xor B xor R8)and $10)<>0 Then EFlags.s:=EFlags.s+[AF]
 Else EFlags.s:=EFlags.s-[AF];
 If Parity8(R8)Then EFlags.s:=EFlags.s+[PF]
 Else EFlags.s:=EFlags.s-[PF];
 ArithAdd8:=R8;
End;

  { TODO 9 : Addition 32 bits avec mise a jour de tous les drapeaux.
    Calcule A + B, met a jour CF, ZF, SF, OF, AF, PF dans EFLAGS
    et retourne le resultat. Le carry est detecte par decomposition
    en deux moities de 16 bits. }
Function ArithAdd32(A,B:LongInt):LongInt;
Var
 Res:LongInt;
 SumLo,CarryLo,SumHi:LongInt;
Begin
 Res:=A+B;
 SumLo:=(A and $FFFF)+(B and $FFFF);
 CarryLo:=SumLo shr 16;
 SumHi:=((A shr 16) and $FFFF)+((B shr 16) and $FFFF)+CarryLo;
 If(SumHi shr 16)<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 If Res=0 Then EFlags.s:=EFlags.s+[ZF]
 Else EFlags.s:=EFlags.s-[ZF];
 If Res<0 Then EFlags.s:=EFlags.s+[SF]
 Else EFlags.s:=EFlags.s-[SF];
 If((A xor Res)and(B xor Res))<0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If((A xor B xor Res)and $10)<>0 Then EFlags.s:=EFlags.s+[AF]
 Else EFlags.s:=EFlags.s-[AF];
 If Parity8(Byte(Res))Then EFlags.s:=EFlags.s+[PF]
 Else EFlags.s:=EFlags.s-[PF];
 ArithAdd32:=Res;
End;

  { TODO 9 : Soustraction 8 bits avec mise a jour de tous les drapeaux.
    Calcule A - B, met a jour CF (borrow si B > A non-signe), ZF,
    SF, OF, AF, PF dans EFLAGS et retourne le resultat. }
Function ArithSub8(A,B:Byte):Byte;
Var
 R8:Byte;
Begin
 R8:=A-B;
 If B>A Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 If R8=0 Then EFlags.s:=EFlags.s+[ZF]
 Else EFlags.s:=EFlags.s-[ZF];
 If(R8 and $80)<>0 Then EFlags.s:=EFlags.s+[SF]
 Else EFlags.s:=EFlags.s-[SF];
 If((A xor B)and(A xor R8)and $80)<>0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If((A xor B xor R8)and $10)<>0 Then EFlags.s:=EFlags.s+[AF]
 Else EFlags.s:=EFlags.s-[AF];
 If Parity8(R8)Then EFlags.s:=EFlags.s+[PF]
 Else EFlags.s:=EFlags.s-[PF];
 ArithSub8:=R8;
End;

  { TODO 11 : Soustraction 16 bits avec mise a jour de tous les drapeaux.
    Calcule A - B, met a jour CF (borrow si B > A non-signe), ZF,
    SF, OF, AF, PF dans EFLAGS et retourne le resultat. }
Function ArithSub16(A,B:Word):Word;
Var
 R16:Word;
Begin
 R16:=A-B;
 If B>A Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 If R16=0 Then EFlags.s:=EFlags.s+[ZF]
 Else EFlags.s:=EFlags.s-[ZF];
 If(R16 and $8000)<>0 Then EFlags.s:=EFlags.s+[SF]
 Else EFlags.s:=EFlags.s-[SF];
 If((A xor B)and(A xor R16)and $8000)<>0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If((A xor B xor R16)and $10)<>0 Then EFlags.s:=EFlags.s+[AF]
 Else EFlags.s:=EFlags.s-[AF];
 If Parity8(Byte(R16))Then EFlags.s:=EFlags.s+[PF]
 Else EFlags.s:=EFlags.s-[PF];
 ArithSub16:=R16;
End;

  { TODO 9 : Soustraction 32 bits avec mise a jour de tous les drapeaux.
    Calcule A - B, met a jour CF (borrow = comparaison non-signee
    B > A par decomposition 16 bits), ZF, SF, OF, AF, PF. }
Function ArithSub32(A,B:LongInt):LongInt;
Var
 Res:LongInt;
 HiA,HiB:LongInt;
Begin
 Res:=A-B;
 HiA:=(A shr 16) and $FFFF;
 HiB:=(B shr 16) and $FFFF;
 If HiA<>HiB Then Begin
  If HiA<HiB Then EFlags.s:=EFlags.s+[CF]
  Else EFlags.s:=EFlags.s-[CF];
 End
 Else Begin
  If(A and $FFFF)<(B and $FFFF)Then EFlags.s:=EFlags.s+[CF]
  Else EFlags.s:=EFlags.s-[CF];
 End;
 If Res=0 Then EFlags.s:=EFlags.s+[ZF]
 Else EFlags.s:=EFlags.s-[ZF];
 If Res<0 Then EFlags.s:=EFlags.s+[SF]
 Else EFlags.s:=EFlags.s-[SF];
 If((A xor B)and(A xor Res))<0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If((A xor B xor Res)and $10)<>0 Then EFlags.s:=EFlags.s+[AF]
 Else EFlags.s:=EFlags.s-[AF];
 If Parity8(Byte(Res))Then EFlags.s:=EFlags.s+[PF]
 Else EFlags.s:=EFlags.s-[PF];
 ArithSub32:=Res;
End;

  { TODO 9 : Addition avec retenue 8 bits (ADC).
    Calcule A + B + CF, met a jour tous les drapeaux. }
Function ArithAdc8(A,B:Byte):Byte;
Var
 C:Word;
 Res:Word;
 R8:Byte;
Begin
 If CF in EFlags.s Then C:=1 Else C:=0;
 Res:=Word(A)+Word(B)+C;
 R8:=Byte(Res);
 If Res>255 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 If R8=0 Then EFlags.s:=EFlags.s+[ZF]
 Else EFlags.s:=EFlags.s-[ZF];
 If(R8 and $80)<>0 Then EFlags.s:=EFlags.s+[SF]
 Else EFlags.s:=EFlags.s-[SF];
 If((A xor R8)and(B xor R8)and $80)<>0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If((A xor B xor R8)and $10)<>0 Then EFlags.s:=EFlags.s+[AF]
 Else EFlags.s:=EFlags.s-[AF];
 If Parity8(R8)Then EFlags.s:=EFlags.s+[PF]
 Else EFlags.s:=EFlags.s-[PF];
 ArithAdc8:=R8;
End;

  { TODO 9 : Addition avec retenue 32 bits (ADC).
    Calcule A + B + CF, met a jour tous les drapeaux.
    Le carry entrant (ancien CF) est ajoute a la somme. }
Function ArithAdc32(A,B:LongInt):LongInt;
Var
 C:LongInt;
 Res:LongInt;
 SumLo,CarryLo,SumHi:LongInt;
Begin
 If CF in EFlags.s Then C:=1 Else C:=0;
 Res:=A+B+C;
 SumLo:=(A and $FFFF)+(B and $FFFF)+C;
 CarryLo:=SumLo shr 16;
 SumHi:=((A shr 16) and $FFFF)+((B shr 16) and $FFFF)+CarryLo;
 If(SumHi shr 16)<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 If Res=0 Then EFlags.s:=EFlags.s+[ZF]
 Else EFlags.s:=EFlags.s-[ZF];
 If Res<0 Then EFlags.s:=EFlags.s+[SF]
 Else EFlags.s:=EFlags.s-[SF];
 If((A xor Res)and(B xor Res))<0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If((A xor B xor Res)and $10)<>0 Then EFlags.s:=EFlags.s+[AF]
 Else EFlags.s:=EFlags.s-[AF];
 If Parity8(Byte(Res))Then EFlags.s:=EFlags.s+[PF]
 Else EFlags.s:=EFlags.s-[PF];
 ArithAdc32:=Res;
End;

  { TODO 9 : Soustraction avec emprunt 8 bits (SBB).
    Calcule A - B - CF, met a jour tous les drapeaux. }
Function ArithSbb8(A,B:Byte):Byte;
Var
 C:Word;
 Res:Integer;
 R8:Byte;
Begin
 If CF in EFlags.s Then C:=1 Else C:=0;
 Res:=Integer(A)-Integer(B)-Integer(C);
 R8:=Byte(Res);
 If Res<0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 If R8=0 Then EFlags.s:=EFlags.s+[ZF]
 Else EFlags.s:=EFlags.s-[ZF];
 If(R8 and $80)<>0 Then EFlags.s:=EFlags.s+[SF]
 Else EFlags.s:=EFlags.s-[SF];
 If((A xor B)and(A xor R8)and $80)<>0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If((A xor B xor R8)and $10)<>0 Then EFlags.s:=EFlags.s+[AF]
 Else EFlags.s:=EFlags.s-[AF];
 If Parity8(R8)Then EFlags.s:=EFlags.s+[PF]
 Else EFlags.s:=EFlags.s-[PF];
 ArithSbb8:=R8;
End;

  { TODO 9 : Soustraction avec emprunt 32 bits (SBB).
    Calcule A - B - CF, met a jour tous les drapeaux. }
Function ArithSbb32(A,B:LongInt):LongInt;
Var
 C:LongInt;
 Res:LongInt;
 DiffLo,BorrowLo,DiffHi:LongInt;
Begin
 If CF in EFlags.s Then C:=1 Else C:=0;
 Res:=A-B-C;
 DiffLo:=(A and $FFFF)-(B and $FFFF)-C;
 If DiffLo<0 Then BorrowLo:=1 Else BorrowLo:=0;
 DiffHi:=((A shr 16) and $FFFF)-((B shr 16) and $FFFF)-BorrowLo;
 If DiffHi<0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 If Res=0 Then EFlags.s:=EFlags.s+[ZF]
 Else EFlags.s:=EFlags.s-[ZF];
 If Res<0 Then EFlags.s:=EFlags.s+[SF]
 Else EFlags.s:=EFlags.s-[SF];
 If((A xor B)and(A xor Res))<0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If((A xor B xor Res)and $10)<>0 Then EFlags.s:=EFlags.s+[AF]
 Else EFlags.s:=EFlags.s-[AF];
 If Parity8(Byte(Res))Then EFlags.s:=EFlags.s+[PF]
 Else EFlags.s:=EFlags.s-[PF];
 ArithSbb32:=Res;
End;

  { TODO 9 : ADD r/m8, r8 (opcode $00).
    Additionne le registre r8 a r/m8 avec mise a jour des drapeaux. }
Procedure OpAddRM8R8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 A,R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Begin
  A:=ReadByte(Eff);
  R:=ArithAdd8(A,GetReg8(RegF));
  WriteByte(Eff,R);
 End
 Else Begin
  A:=GetReg8(RMF);
  R:=ArithAdd8(A,GetReg8(RegF));
  SetReg8(RMF,R);
 End;
End;

  { TODO 9 : ADD r/m32, r32 (opcode $01).
    Additionne le registre r32 a r/m32 avec mise a jour des drapeaux. }
Procedure OpAddRM32R32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 A,R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Begin
  A:=ReadDWord(Eff);
  R:=ArithAdd32(A,GetReg32(RegF));
  WriteDWord(Eff,R);
 End
 Else Begin
  A:=GetReg32(RMF);
  R:=ArithAdd32(A,GetReg32(RegF));
  SetReg32(RMF,R);
 End;
End;

  { TODO 9 : ADD r8, r/m8 (opcode $02).
    Additionne r/m8 au registre r8 avec mise a jour des drapeaux. }
Procedure OpAddR8RM8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 B,R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then B:=ReadByte(Eff)
 Else B:=GetReg8(RMF);
 R:=ArithAdd8(GetReg8(RegF),B);
 SetReg8(RegF,R);
End;

  { TODO 9 : ADD r32, r/m32 (opcode $03).
    Additionne r/m32 au registre r32 avec mise a jour des drapeaux. }
Procedure OpAddR32RM32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 B,R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then B:=ReadDWord(Eff)
 Else B:=GetReg32(RMF);
 R:=ArithAdd32(GetReg32(RegF),B);
 SetReg32(RegF,R);
End;

  { TODO 9 : ADD AL, imm8 (opcode $04).
    Additionne un immediat 8 bits a AL. }
Procedure OpAddALImm8;
Var
 Imm:Byte;
Begin
 Imm:=ReadByte(EIP);
 Inc(EIP);
 Regs.AL:=ArithAdd8(Regs.AL,Imm);
End;

  { TODO 9 : ADD EAX, imm32 (opcode $05).
    Additionne un immediat 32 bits a EAX. }
Procedure OpAddEAXImm32;
Var
 Imm:LongInt;
Begin
 Imm:=ReadDWord(EIP);
 Inc(EIP,4);
 Regs.EAX:=ArithAdd32(Regs.EAX,Imm);
End;

  { TODO 9 : SUB r/m8, r8 (opcode $28). }
Procedure OpSubRM8R8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 A,R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Begin
  A:=ReadByte(Eff);
  R:=ArithSub8(A,GetReg8(RegF));
  WriteByte(Eff,R);
 End
 Else Begin
  A:=GetReg8(RMF);
  R:=ArithSub8(A,GetReg8(RegF));
  SetReg8(RMF,R);
 End;
End;

  { TODO 9 : SUB r/m32, r32 (opcode $29). }
Procedure OpSubRM32R32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 A,R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Begin
  A:=ReadDWord(Eff);
  R:=ArithSub32(A,GetReg32(RegF));
  WriteDWord(Eff,R);
 End
 Else Begin
  A:=GetReg32(RMF);
  R:=ArithSub32(A,GetReg32(RegF));
  SetReg32(RMF,R);
 End;
End;

  { TODO 9 : SUB r8, r/m8 (opcode $2A). }
Procedure OpSubR8RM8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 B,R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then B:=ReadByte(Eff)
 Else B:=GetReg8(RMF);
 R:=ArithSub8(GetReg8(RegF),B);
 SetReg8(RegF,R);
End;

  { TODO 9 : SUB r32, r/m32 (opcode $2B). }
Procedure OpSubR32RM32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 B,R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then B:=ReadDWord(Eff)
 Else B:=GetReg32(RMF);
 R:=ArithSub32(GetReg32(RegF),B);
 SetReg32(RegF,R);
End;

  { TODO 9 : SUB AL, imm8 (opcode $2C). }
Procedure OpSubALImm8;
Var
 Imm:Byte;
Begin
 Imm:=ReadByte(EIP);
 Inc(EIP);
 Regs.AL:=ArithSub8(Regs.AL,Imm);
End;

  { TODO 9 : SUB EAX, imm32 (opcode $2D). }
Procedure OpSubEAXImm32;
Var
 Imm:LongInt;
Begin
 Imm:=ReadDWord(EIP);
 Inc(EIP,4);
 Regs.EAX:=ArithSub32(Regs.EAX,Imm);
End;

  { TODO 9 : ADC r/m8, r8 (opcode $10). }
Procedure OpAdcRM8R8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 A,R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Begin
  A:=ReadByte(Eff);
  R:=ArithAdc8(A,GetReg8(RegF));
  WriteByte(Eff,R);
 End
 Else Begin
  A:=GetReg8(RMF);
  R:=ArithAdc8(A,GetReg8(RegF));
  SetReg8(RMF,R);
 End;
End;

  { TODO 9 : ADC r/m32, r32 (opcode $11). }
Procedure OpAdcRM32R32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 A,R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Begin
  A:=ReadDWord(Eff);
  R:=ArithAdc32(A,GetReg32(RegF));
  WriteDWord(Eff,R);
 End
 Else Begin
  A:=GetReg32(RMF);
  R:=ArithAdc32(A,GetReg32(RegF));
  SetReg32(RMF,R);
 End;
End;

  { TODO 9 : ADC r8, r/m8 (opcode $12). }
Procedure OpAdcR8RM8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 B,R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then B:=ReadByte(Eff)
 Else B:=GetReg8(RMF);
 R:=ArithAdc8(GetReg8(RegF),B);
 SetReg8(RegF,R);
End;

  { TODO 9 : ADC r32, r/m32 (opcode $13). }
Procedure OpAdcR32RM32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 B,R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then B:=ReadDWord(Eff)
 Else B:=GetReg32(RMF);
 R:=ArithAdc32(GetReg32(RegF),B);
 SetReg32(RegF,R);
End;

  { TODO 9 : ADC AL, imm8 (opcode $14). }
Procedure OpAdcALImm8;
Var
 Imm:Byte;
Begin
 Imm:=ReadByte(EIP);
 Inc(EIP);
 Regs.AL:=ArithAdc8(Regs.AL,Imm);
End;

  { TODO 9 : ADC EAX, imm32 (opcode $15). }
Procedure OpAdcEAXImm32;
Var
 Imm:LongInt;
Begin
 Imm:=ReadDWord(EIP);
 Inc(EIP,4);
 Regs.EAX:=ArithAdc32(Regs.EAX,Imm);
End;

  { TODO 9 : SBB r/m8, r8 (opcode $18). }
Procedure OpSbbRM8R8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 A,R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Begin
  A:=ReadByte(Eff);
  R:=ArithSbb8(A,GetReg8(RegF));
  WriteByte(Eff,R);
 End
 Else Begin
  A:=GetReg8(RMF);
  R:=ArithSbb8(A,GetReg8(RegF));
  SetReg8(RMF,R);
 End;
End;

  { TODO 9 : SBB r/m32, r32 (opcode $19). }
Procedure OpSbbRM32R32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 A,R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Begin
  A:=ReadDWord(Eff);
  R:=ArithSbb32(A,GetReg32(RegF));
  WriteDWord(Eff,R);
 End
 Else Begin
  A:=GetReg32(RMF);
  R:=ArithSbb32(A,GetReg32(RegF));
  SetReg32(RMF,R);
 End;
End;

  { TODO 9 : SBB r8, r/m8 (opcode $1A). }
Procedure OpSbbR8RM8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 B,R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then B:=ReadByte(Eff)
 Else B:=GetReg8(RMF);
 R:=ArithSbb8(GetReg8(RegF),B);
 SetReg8(RegF,R);
End;

  { TODO 9 : SBB r32, r/m32 (opcode $1B). }
Procedure OpSbbR32RM32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 B,R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then B:=ReadDWord(Eff)
 Else B:=GetReg32(RMF);
 R:=ArithSbb32(GetReg32(RegF),B);
 SetReg32(RegF,R);
End;

  { TODO 9 : SBB AL, imm8 (opcode $1C). }
Procedure OpSbbALImm8;
Var
 Imm:Byte;
Begin
 Imm:=ReadByte(EIP);
 Inc(EIP);
 Regs.AL:=ArithSbb8(Regs.AL,Imm);
End;

  { TODO 9 : SBB EAX, imm32 (opcode $1D). }
Procedure OpSbbEAXImm32;
Var
 Imm:LongInt;
Begin
 Imm:=ReadDWord(EIP);
 Inc(EIP,4);
 Regs.EAX:=ArithSbb32(Regs.EAX,Imm);
End;

  { TODO 9 : CMP r/m8, r8 (opcode $38).
    Compare par soustraction sans stocker le resultat. }
Procedure OpCmpRM8R8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 A:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then A:=ReadByte(Eff)
 Else A:=GetReg8(RMF);
 ArithSub8(A,GetReg8(RegF));
End;

  { TODO 9 : CMP r/m32, r32 (opcode $39). }
Procedure OpCmpRM32R32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 A:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then A:=ReadDWord(Eff)
 Else A:=GetReg32(RMF);
 ArithSub32(A,GetReg32(RegF));
End;

  { TODO 9 : CMP r8, r/m8 (opcode $3A). }
Procedure OpCmpR8RM8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 B:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then B:=ReadByte(Eff)
 Else B:=GetReg8(RMF);
 ArithSub8(GetReg8(RegF),B);
End;

  { TODO 9 : CMP r32, r/m32 (opcode $3B). }
Procedure OpCmpR32RM32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 B:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then B:=ReadDWord(Eff)
 Else B:=GetReg32(RMF);
 ArithSub32(GetReg32(RegF),B);
End;

  { TODO 9 : CMP AL, imm8 (opcode $3C). }
Procedure OpCmpALImm8;
Var
 Imm:Byte;
Begin
 Imm:=ReadByte(EIP);
 Inc(EIP);
 ArithSub8(Regs.AL,Imm);
End;

  { TODO 9 : CMP EAX, imm32 (opcode $3D). }
Procedure OpCmpEAXImm32;
Var
 Imm:LongInt;
Begin
 Imm:=ReadDWord(EIP);
 Inc(EIP,4);
 ArithSub32(Regs.EAX,Imm);
End;

  { TODO 9 : INC r32 (opcode $40+r).
    Incremente le registre r32 de 1. CF n'est pas modifie. }
Procedure OpIncR32(RegIdx:Byte);
Var
 SaveCF:Boolean;
Begin
 SaveCF:=CF in EFlags.s;
 SetReg32(RegIdx,ArithAdd32(GetReg32(RegIdx),1));
 If SaveCF Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
End;

  { TODO 9 : DEC r32 (opcode $48+r).
    Decremente le registre r32 de 1. CF n'est pas modifie. }
Procedure OpDecR32(RegIdx:Byte);
Var
 SaveCF:Boolean;
Begin
 SaveCF:=CF in EFlags.s;
 SetReg32(RegIdx,ArithSub32(GetReg32(RegIdx),1));
 If SaveCF Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
End;

  { TODO 9 : INC r/m8 (opcode $FE /0).
    Incremente r/m8 de 1. CF n'est pas modifie. }
Procedure OpIncRM8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 SaveCF:Boolean;
 A,R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 SaveCF:=CF in EFlags.s;
 If IsMem Then Begin
  A:=ReadByte(Eff);
  R:=ArithAdd8(A,1);
  WriteByte(Eff,R);
 End
 Else Begin
  A:=GetReg8(RMF);
  R:=ArithAdd8(A,1);
  SetReg8(RMF,R);
 End;
 If SaveCF Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
End;

  { TODO 9 : DEC r/m8 (opcode $FE /1).
    Decremente r/m8 de 1. CF n'est pas modifie. }
Procedure OpDecRM8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 SaveCF:Boolean;
 A,R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 SaveCF:=CF in EFlags.s;
 If IsMem Then Begin
  A:=ReadByte(Eff);
  R:=ArithSub8(A,1);
  WriteByte(Eff,R);
 End
 Else Begin
  A:=GetReg8(RMF);
  R:=ArithSub8(A,1);
  SetReg8(RMF,R);
 End;
 If SaveCF Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
End;

  { TODO 9 : INC r/m32 (opcode $FF /0).
    Incremente r/m32 de 1. CF n'est pas modifie. }
Procedure OpIncRM32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 SaveCF:Boolean;
 A,R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 SaveCF:=CF in EFlags.s;
 If IsMem Then Begin
  A:=ReadDWord(Eff);
  R:=ArithAdd32(A,1);
  WriteDWord(Eff,R);
 End
 Else Begin
  A:=GetReg32(RMF);
  R:=ArithAdd32(A,1);
  SetReg32(RMF,R);
 End;
 If SaveCF Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
End;

  { TODO 9 : DEC r/m32 (opcode $FF /1).
    Decremente r/m32 de 1. CF n'est pas modifie. }
Procedure OpDecRM32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 SaveCF:Boolean;
 A,R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 SaveCF:=CF in EFlags.s;
 If IsMem Then Begin
  A:=ReadDWord(Eff);
  R:=ArithSub32(A,1);
  WriteDWord(Eff,R);
 End
 Else Begin
  A:=GetReg32(RMF);
  R:=ArithSub32(A,1);
  SetReg32(RMF,R);
 End;
 If SaveCF Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
End;

  { TODO 9 : NEG r/m8 (opcode $F6 /3).
    Negation en complement a deux : r/m8 = 0 - r/m8.
    CF est mis a 1 sauf si l'operande est 0. }
Procedure OpNegRM8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 A,R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then A:=ReadByte(Eff)
 Else A:=GetReg8(RMF);
 R:=ArithSub8(0,A);
 If A<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 If IsMem Then WriteByte(Eff,R)
 Else SetReg8(RMF,R);
End;

  { TODO 9 : NEG r/m32 (opcode $F7 /3).
    Negation en complement a deux : r/m32 = 0 - r/m32.
    CF est mis a 1 sauf si l'operande est 0. }
Procedure OpNegRM32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 A,R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then A:=ReadDWord(Eff)
 Else A:=GetReg32(RMF);
 R:=ArithSub32(0,A);
 If A<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 If IsMem Then WriteDWord(Eff,R)
 Else SetReg32(RMF,R);
End;

  { TODO 9 : MUL r/m8 (opcode $F6 /4).
    Multiplication non-signee : AX = AL * r/m8.
    CF et OF sont mis a 1 si AH <> 0 (resultat deborde sur 8 bits). }
Procedure OpMulRM8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:Byte;
 Res:Word;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadByte(Eff)
 Else Val:=GetReg8(RMF);
 Res:=Word(Regs.AL)*Word(Val);
 Regs.AX:=Res;
 If Regs.AH<>0 Then Begin
  EFlags.s:=EFlags.s+[CF];
  EFlags.s:=EFlags.s+[_OF];
 End
 Else Begin
  EFlags.s:=EFlags.s-[CF];
  EFlags.s:=EFlags.s-[_OF];
 End;
End;

  { TODO 9 : MUL r/m32 (opcode $F7 /4).
    Multiplication non-signee : EDX:EAX = EAX * r/m32.
    CF et OF sont mis a 1 si EDX <> 0 (resultat deborde sur 32 bits).
    Utilise Int64 pour le calcul intermediaire 64 bits. }
Procedure OpMulRM32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:LongInt;
 A64,B64,Res64:Int64;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 A64:=Int64(Regs.EAX) and $FFFFFFFF;
 B64:=Int64(Val) and $FFFFFFFF;
 Res64:=A64*B64;
 Regs.EAX:=LongInt(Res64);
 Regs.EDX:=LongInt(Res64 shr 32);
 If Regs.EDX<>0 Then Begin
  EFlags.s:=EFlags.s+[CF];
  EFlags.s:=EFlags.s+[_OF];
 End
 Else Begin
  EFlags.s:=EFlags.s-[CF];
  EFlags.s:=EFlags.s-[_OF];
 End;
End;

  { TODO 9 : IMUL r/m8 (opcode $F6 /5).
    Multiplication signee : AX = AL * r/m8 (avec extension de signe).
    CF et OF sont mis a 1 si le resultat ne tient pas dans 8 bits signes. }
Procedure OpImulRM8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:ShortInt;
 Res:Integer;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ShortInt(ReadByte(Eff))
 Else Val:=ShortInt(GetReg8(RMF));
 Res:=Integer(ShortInt(Regs.AL))*Integer(Val);
 Regs.AX:=Word(Res);
 If(Res<-128)or(Res>127)Then Begin
  EFlags.s:=EFlags.s+[CF];
  EFlags.s:=EFlags.s+[_OF];
 End
 Else Begin
  EFlags.s:=EFlags.s-[CF];
  EFlags.s:=EFlags.s-[_OF];
 End;
End;

  { TODO 9 : IMUL r/m32 (opcode $F7 /5).
    Multiplication signee : EDX:EAX = EAX * r/m32.
    CF et OF sont mis a 1 si le resultat ne tient pas dans 32 bits signes.
    Utilise Int64 pour le calcul intermediaire 64 bits. }
Procedure OpImulRM32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:LongInt;
 Res64:Int64;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 Res64:=Int64(Regs.EAX)*Int64(Val);
 Regs.EAX:=LongInt(Res64);
 Regs.EDX:=LongInt(Res64 shr 32);
 If(Res64<Int64(-2147483648))or(Res64>Int64(2147483647))Then Begin
  EFlags.s:=EFlags.s+[CF];
  EFlags.s:=EFlags.s+[_OF];
 End
 Else Begin
  EFlags.s:=EFlags.s-[CF];
  EFlags.s:=EFlags.s-[_OF];
 End;
End;

  { TODO 9 : IMUL r32, r/m32 (opcode $0F $AF).
    Multiplication signee a deux operandes : r32 = r32 * r/m32.
    Seuls les 32 bits bas du resultat sont stockes.
    CF et OF sont mis a 1 si le resultat deborde. }
Procedure OpImulR32RM32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 B:LongInt;
 Res64:Int64;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then B:=ReadDWord(Eff)
 Else B:=GetReg32(RMF);
 Res64:=Int64(GetReg32(RegF))*Int64(B);
 SetReg32(RegF,LongInt(Res64));
 If(Res64<Int64(-2147483648))or(Res64>Int64(2147483647))Then Begin
  EFlags.s:=EFlags.s+[CF];
  EFlags.s:=EFlags.s+[_OF];
 End
 Else Begin
  EFlags.s:=EFlags.s-[CF];
  EFlags.s:=EFlags.s-[_OF];
 End;
End;

  { TODO 9 : IMUL r32, r/m32, imm32 (opcode $69).
    Multiplication signee a trois operandes : r32 = r/m32 * imm32. }
Procedure OpImulR32RM32Imm32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 B,Imm:LongInt;
 Res64:Int64;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 Imm:=ReadDWord(EIP);
 Inc(EIP,4);
 If IsMem Then B:=ReadDWord(Eff)
 Else B:=GetReg32(RMF);
 Res64:=Int64(B)*Int64(Imm);
 SetReg32(RegF,LongInt(Res64));
 If(Res64<Int64(-2147483648))or(Res64>Int64(2147483647))Then Begin
  EFlags.s:=EFlags.s+[CF];
  EFlags.s:=EFlags.s+[_OF];
 End
 Else Begin
  EFlags.s:=EFlags.s-[CF];
  EFlags.s:=EFlags.s-[_OF];
 End;
End;

  { TODO 9 : IMUL r32, r/m32, imm8 (opcode $6B).
    Multiplication signee a trois operandes : r32 = r/m32 * imm8
    (l'immediat 8 bits est etendu avec signe a 32 bits). }
Procedure OpImulR32RM32Imm8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 B:LongInt;
 Imm:LongInt;
 Res64:Int64;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 Imm:=LongInt(ShortInt(ReadByte(EIP)));
 Inc(EIP);
 If IsMem Then B:=ReadDWord(Eff)
 Else B:=GetReg32(RMF);
 Res64:=Int64(B)*Int64(Imm);
 SetReg32(RegF,LongInt(Res64));
 If(Res64<Int64(-2147483648))or(Res64>Int64(2147483647))Then Begin
  EFlags.s:=EFlags.s+[CF];
  EFlags.s:=EFlags.s+[_OF];
 End
 Else Begin
  EFlags.s:=EFlags.s-[CF];
  EFlags.s:=EFlags.s-[_OF];
 End;
End;

  { TODO 9 : DIV r/m8 (opcode $F6 /6).
    Division non-signee : AL = AX / r/m8, AH = AX mod r/m8.
    Genere une erreur si le diviseur est 0 ou si le quotient
    depasse 255. Les drapeaux sont indefinis. }
Procedure OpDivRM8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:Byte;
 Dividend:Word;
 Quot:Word;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadByte(Eff)
 Else Val:=GetReg8(RMF);
 If Val=0 Then Begin
  WriteLn('DIV: erreur de division par zero (8 bits)');
  Exit;
 End;
 Dividend:=Regs.AX;
 Quot:=Dividend div Val;
 If Quot>255 Then Begin
  WriteLn('DIV: debordement du quotient (8 bits)');
  Exit;
 End;
 Regs.AL:=Byte(Quot);
 Regs.AH:=Byte(Dividend mod Val);
End;

  { TODO 9 : DIV r/m32 (opcode $F7 /6).
    Division non-signee : EAX = EDX:EAX / r/m32,
    EDX = EDX:EAX mod r/m32.
    Utilise Int64 pour le dividende 64 bits. }
Procedure OpDivRM32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:LongInt;
 Dividend64,Divisor64,Quot64:Int64;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If Val=0 Then Begin
  WriteLn('DIV: erreur de division par zero (32 bits)');
  Exit;
 End;
 Dividend64:=((Int64(Regs.EDX) and $FFFFFFFF) shl 32) or
             (Int64(Regs.EAX) and $FFFFFFFF);
 Divisor64:=Int64(Val) and $FFFFFFFF;
 Quot64:=Dividend64 div Divisor64;
 If Quot64>$FFFFFFFF Then Begin
  WriteLn('DIV: debordement du quotient (32 bits)');
  Exit;
 End;
 Regs.EAX:=LongInt(Quot64);
 Regs.EDX:=LongInt(Dividend64 mod Divisor64);
End;

  { TODO 9 : IDIV r/m8 (opcode $F6 /7).
    Division signee : AL = AX / r/m8, AH = AX mod r/m8 (signes).
    Genere une erreur si le diviseur est 0 ou si le quotient
    depasse la plage [-128, 127]. Les drapeaux sont indefinis. }
Procedure OpIdivRM8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:ShortInt;
 Dividend:Integer;
 Quot:Integer;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ShortInt(ReadByte(Eff))
 Else Val:=ShortInt(GetReg8(RMF));
 If Val=0 Then Begin
  WriteLn('IDIV: erreur de division par zero (8 bits)');
  Exit;
 End;
 Dividend:=Integer(Regs.AX);
 Quot:=Dividend div Integer(Val);
 If(Quot<-128)or(Quot>127)Then Begin
  WriteLn('IDIV: debordement du quotient (8 bits)');
  Exit;
 End;
 Regs.AL:=Byte(Quot);
 Regs.AH:=Byte(Dividend mod Integer(Val));
End;

  { TODO 9 : IDIV r/m32 (opcode $F7 /7).
    Division signee : EAX = EDX:EAX / r/m32,
    EDX = EDX:EAX mod r/m32 (signes).
    Utilise Int64 pour le dividende 64 bits. }
Procedure OpIdivRM32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:LongInt;
 Dividend64,Quot64,Rem64:Int64;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If Val=0 Then Begin
  WriteLn('IDIV: erreur de division par zero (32 bits)');
  Exit;
 End;
 Dividend64:=(Int64(Regs.EDX) shl 32) or (Int64(Regs.EAX) and $FFFFFFFF);
 Quot64:=Dividend64 div Int64(Val);
 Rem64:=Dividend64 mod Int64(Val);
 If(Quot64<Int64(-2147483648))or(Quot64>Int64(2147483647))Then Begin
  WriteLn('IDIV: debordement du quotient (32 bits)');
  Exit;
 End;
 Regs.EAX:=LongInt(Quot64);
 Regs.EDX:=LongInt(Rem64);
End;

  { TODO 10 : Mise a jour des drapeaux logiques 8 bits.
    Les operations logiques (AND, OR, XOR, TEST) effacent CF et OF,
    mettent a jour ZF, SF et PF, et laissent AF indefini (efface ici). }
Procedure LogicFlags8(Res:Byte);
Begin
 EFlags.s:=EFlags.s-[CF,_OF,AF];
 If Res=0 Then EFlags.s:=EFlags.s+[ZF]
 Else EFlags.s:=EFlags.s-[ZF];
 If(Res and $80)<>0 Then EFlags.s:=EFlags.s+[SF]
 Else EFlags.s:=EFlags.s-[SF];
 If Parity8(Res)Then EFlags.s:=EFlags.s+[PF]
 Else EFlags.s:=EFlags.s-[PF];
End;

  { TODO 10 : Mise a jour des drapeaux logiques 32 bits. }
Procedure LogicFlags32(Res:LongInt);
Begin
 EFlags.s:=EFlags.s-[CF,_OF,AF];
 If Res=0 Then EFlags.s:=EFlags.s+[ZF]
 Else EFlags.s:=EFlags.s-[ZF];
 If Res<0 Then EFlags.s:=EFlags.s+[SF]
 Else EFlags.s:=EFlags.s-[SF];
 If Parity8(Byte(Res))Then EFlags.s:=EFlags.s+[PF]
 Else EFlags.s:=EFlags.s-[PF];
End;

  { TODO 10 : AND r/m8, r8 (opcode $20). }
Procedure OpAndRM8R8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Begin
  R:=ReadByte(Eff)and GetReg8(RegF);
  WriteByte(Eff,R);
 End
 Else Begin
  R:=GetReg8(RMF)and GetReg8(RegF);
  SetReg8(RMF,R);
 End;
 LogicFlags8(R);
End;

  { TODO 10 : AND r/m32, r32 (opcode $21). }
Procedure OpAndRM32R32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Begin
  R:=ReadDWord(Eff)and GetReg32(RegF);
  WriteDWord(Eff,R);
 End
 Else Begin
  R:=GetReg32(RMF)and GetReg32(RegF);
  SetReg32(RMF,R);
 End;
 LogicFlags32(R);
End;

  { TODO 10 : AND r8, r/m8 (opcode $22). }
Procedure OpAndR8RM8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 B,R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then B:=ReadByte(Eff)
 Else B:=GetReg8(RMF);
 R:=GetReg8(RegF)and B;
 SetReg8(RegF,R);
 LogicFlags8(R);
End;

  { TODO 10 : AND r32, r/m32 (opcode $23). }
Procedure OpAndR32RM32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 B,R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then B:=ReadDWord(Eff)
 Else B:=GetReg32(RMF);
 R:=GetReg32(RegF)and B;
 SetReg32(RegF,R);
 LogicFlags32(R);
End;

  { TODO 10 : AND AL, imm8 (opcode $24). }
Procedure OpAndALImm8;
Var
 Imm:Byte;
Begin
 Imm:=ReadByte(EIP);
 Inc(EIP);
 Regs.AL:=Regs.AL and Imm;
 LogicFlags8(Regs.AL);
End;

  { TODO 10 : AND EAX, imm32 (opcode $25). }
Procedure OpAndEAXImm32;
Var
 Imm:LongInt;
Begin
 Imm:=ReadDWord(EIP);
 Inc(EIP,4);
 Regs.EAX:=Regs.EAX and Imm;
 LogicFlags32(Regs.EAX);
End;

  { TODO 10 : OR r/m8, r8 (opcode $08). }
Procedure OpOrRM8R8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Begin
  R:=ReadByte(Eff)or GetReg8(RegF);
  WriteByte(Eff,R);
 End
 Else Begin
  R:=GetReg8(RMF)or GetReg8(RegF);
  SetReg8(RMF,R);
 End;
 LogicFlags8(R);
End;

  { TODO 10 : OR r/m32, r32 (opcode $09). }
Procedure OpOrRM32R32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Begin
  R:=ReadDWord(Eff)or GetReg32(RegF);
  WriteDWord(Eff,R);
 End
 Else Begin
  R:=GetReg32(RMF)or GetReg32(RegF);
  SetReg32(RMF,R);
 End;
 LogicFlags32(R);
End;

  { TODO 10 : OR r8, r/m8 (opcode $0A). }
Procedure OpOrR8RM8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 B,R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then B:=ReadByte(Eff)
 Else B:=GetReg8(RMF);
 R:=GetReg8(RegF)or B;
 SetReg8(RegF,R);
 LogicFlags8(R);
End;

  { TODO 10 : OR r32, r/m32 (opcode $0B). }
Procedure OpOrR32RM32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 B,R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then B:=ReadDWord(Eff)
 Else B:=GetReg32(RMF);
 R:=GetReg32(RegF)or B;
 SetReg32(RegF,R);
 LogicFlags32(R);
End;

  { TODO 10 : OR AL, imm8 (opcode $0C). }
Procedure OpOrALImm8;
Var
 Imm:Byte;
Begin
 Imm:=ReadByte(EIP);
 Inc(EIP);
 Regs.AL:=Regs.AL or Imm;
 LogicFlags8(Regs.AL);
End;

  { TODO 10 : OR EAX, imm32 (opcode $0D). }
Procedure OpOrEAXImm32;
Var
 Imm:LongInt;
Begin
 Imm:=ReadDWord(EIP);
 Inc(EIP,4);
 Regs.EAX:=Regs.EAX or Imm;
 LogicFlags32(Regs.EAX);
End;

  { TODO 10 : XOR r/m8, r8 (opcode $30). }
Procedure OpXorRM8R8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Begin
  R:=ReadByte(Eff)xor GetReg8(RegF);
  WriteByte(Eff,R);
 End
 Else Begin
  R:=GetReg8(RMF)xor GetReg8(RegF);
  SetReg8(RMF,R);
 End;
 LogicFlags8(R);
End;

  { TODO 10 : XOR r/m32, r32 (opcode $31). }
Procedure OpXorRM32R32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Begin
  R:=ReadDWord(Eff)xor GetReg32(RegF);
  WriteDWord(Eff,R);
 End
 Else Begin
  R:=GetReg32(RMF)xor GetReg32(RegF);
  SetReg32(RMF,R);
 End;
 LogicFlags32(R);
End;

  { TODO 10 : XOR r8, r/m8 (opcode $32). }
Procedure OpXorR8RM8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 B,R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then B:=ReadByte(Eff)
 Else B:=GetReg8(RMF);
 R:=GetReg8(RegF)xor B;
 SetReg8(RegF,R);
 LogicFlags8(R);
End;

  { TODO 10 : XOR r32, r/m32 (opcode $33). }
Procedure OpXorR32RM32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 B,R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then B:=ReadDWord(Eff)
 Else B:=GetReg32(RMF);
 R:=GetReg32(RegF)xor B;
 SetReg32(RegF,R);
 LogicFlags32(R);
End;

  { TODO 10 : XOR AL, imm8 (opcode $34). }
Procedure OpXorALImm8;
Var
 Imm:Byte;
Begin
 Imm:=ReadByte(EIP);
 Inc(EIP);
 Regs.AL:=Regs.AL xor Imm;
 LogicFlags8(Regs.AL);
End;

  { TODO 10 : XOR EAX, imm32 (opcode $35). }
Procedure OpXorEAXImm32;
Var
 Imm:LongInt;
Begin
 Imm:=ReadDWord(EIP);
 Inc(EIP,4);
 Regs.EAX:=Regs.EAX xor Imm;
 LogicFlags32(Regs.EAX);
End;

  { TODO 10 : NOT r/m8 (opcode $F6, reg=2). }
Procedure OpNotRM8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then WriteByte(Eff,not ReadByte(Eff))
 Else SetReg8(RMF,not GetReg8(RMF));
End;

  { TODO 10 : NOT r/m32 (opcode $F7, reg=2). }
Procedure OpNotRM32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then WriteDWord(Eff,not ReadDWord(Eff))
 Else SetReg32(RMF,not GetReg32(RMF));
End;

  { TODO 10 : TEST r/m8, r8 (opcode $84).
    Effectue un AND logique sans stocker le resultat. }
Procedure OpTestRM8R8;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then R:=ReadByte(Eff)and GetReg8(RegF)
 Else R:=GetReg8(RMF)and GetReg8(RegF);
 LogicFlags8(R);
End;

  { TODO 10 : TEST r/m32, r32 (opcode $85). }
Procedure OpTestRM32R32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then R:=ReadDWord(Eff)and GetReg32(RegF)
 Else R:=GetReg32(RMF)and GetReg32(RegF);
 LogicFlags32(R);
End;

  { TODO 10 : TEST AL, imm8 (opcode $A8). }
Procedure OpTestALImm8;
Var
 Imm:Byte;
Begin
 Imm:=ReadByte(EIP);
 Inc(EIP);
 LogicFlags8(Regs.AL and Imm);
End;

  { TODO 10 : TEST EAX, imm32 (opcode $A9). }
Procedure OpTestEAXImm32;
Var
 Imm:LongInt;
Begin
 Imm:=ReadDWord(EIP);
 Inc(EIP,4);
 LogicFlags32(Regs.EAX and Imm);
End;

  { TODO 10 : SHL r/m8, 1 (opcode $D0, reg=4).
    Decalage logique a gauche de 1 bit sur operande 8 bits.
    CF recoit le bit le plus significatif evince. }
Procedure OpShlRM8By1;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadByte(Eff)
 Else Val:=GetReg8(RMF);
 If(Val and $80)<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 R:=Val shl 1;
 If((Val xor R)and $80)<>0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If IsMem Then WriteByte(Eff,R)
 Else SetReg8(RMF,R);
 If R=0 Then EFlags.s:=EFlags.s+[ZF]Else EFlags.s:=EFlags.s-[ZF];
 If(R and $80)<>0 Then EFlags.s:=EFlags.s+[SF]Else EFlags.s:=EFlags.s-[SF];
 If Parity8(R)Then EFlags.s:=EFlags.s+[PF]Else EFlags.s:=EFlags.s-[PF];
End;

  { TODO 10 : SHL r/m32, 1 (opcode $D1, reg=4). }
Procedure OpShlRM32By1;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If Val<0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 R:=Val shl 1;
 If((Val xor R))<0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If IsMem Then WriteDWord(Eff,R)
 Else SetReg32(RMF,R);
 If R=0 Then EFlags.s:=EFlags.s+[ZF]Else EFlags.s:=EFlags.s-[ZF];
 If R<0 Then EFlags.s:=EFlags.s+[SF]Else EFlags.s:=EFlags.s-[SF];
 If Parity8(Byte(R))Then EFlags.s:=EFlags.s+[PF]Else EFlags.s:=EFlags.s-[PF];
End;

  { TODO 10 : SHL r/m8, CL (opcode $D2, reg=4). }
Procedure OpShlRM8ByCL;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:Byte;
 Cnt:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadByte(Eff)
 Else Val:=GetReg8(RMF);
 Cnt:=Regs.CL and $1F;
 If Cnt=0 Then Exit;
 If Cnt<=8 Then Begin
  If(Val and(1 shl(8-Cnt)))<>0 Then EFlags.s:=EFlags.s+[CF]
  Else EFlags.s:=EFlags.s-[CF];
 End
 Else EFlags.s:=EFlags.s-[CF];
 R:=Val shl Cnt;
 If IsMem Then WriteByte(Eff,R)
 Else SetReg8(RMF,R);
 If R=0 Then EFlags.s:=EFlags.s+[ZF]Else EFlags.s:=EFlags.s-[ZF];
 If(R and $80)<>0 Then EFlags.s:=EFlags.s+[SF]Else EFlags.s:=EFlags.s-[SF];
 If Parity8(R)Then EFlags.s:=EFlags.s+[PF]Else EFlags.s:=EFlags.s-[PF];
End;

  { TODO 10 : SHL r/m32, CL (opcode $D3, reg=4). }
Procedure OpShlRM32ByCL;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:LongInt;
 Cnt:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 Cnt:=Regs.CL and $1F;
 If Cnt=0 Then Exit;
 If(Val and(LongInt(1)shl(32-Cnt)))<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 R:=Val shl Cnt;
 If IsMem Then WriteDWord(Eff,R)
 Else SetReg32(RMF,R);
 If R=0 Then EFlags.s:=EFlags.s+[ZF]Else EFlags.s:=EFlags.s-[ZF];
 If R<0 Then EFlags.s:=EFlags.s+[SF]Else EFlags.s:=EFlags.s-[SF];
 If Parity8(Byte(R))Then EFlags.s:=EFlags.s+[PF]Else EFlags.s:=EFlags.s-[PF];
End;

  { TODO 10 : SHL r/m8, imm8 (opcode $C0, reg=4). }
Procedure OpShlRM8Imm;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:Byte;
 Cnt:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 Cnt:=ReadByte(EIP)and $1F;
 Inc(EIP);
 If IsMem Then Val:=ReadByte(Eff)
 Else Val:=GetReg8(RMF);
 If Cnt=0 Then Exit;
 If Cnt<=8 Then Begin
  If(Val and(1 shl(8-Cnt)))<>0 Then EFlags.s:=EFlags.s+[CF]
  Else EFlags.s:=EFlags.s-[CF];
 End
 Else EFlags.s:=EFlags.s-[CF];
 R:=Val shl Cnt;
 If IsMem Then WriteByte(Eff,R)
 Else SetReg8(RMF,R);
 If R=0 Then EFlags.s:=EFlags.s+[ZF]Else EFlags.s:=EFlags.s-[ZF];
 If(R and $80)<>0 Then EFlags.s:=EFlags.s+[SF]Else EFlags.s:=EFlags.s-[SF];
 If Parity8(R)Then EFlags.s:=EFlags.s+[PF]Else EFlags.s:=EFlags.s-[PF];
End;

  { TODO 10 : SHL r/m32, imm8 (opcode $C1, reg=4). }
Procedure OpShlRM32Imm;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:LongInt;
 Cnt:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 Cnt:=ReadByte(EIP)and $1F;
 Inc(EIP);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If Cnt=0 Then Exit;
 If(Val and(LongInt(1)shl(32-Cnt)))<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 R:=Val shl Cnt;
 If IsMem Then WriteDWord(Eff,R)
 Else SetReg32(RMF,R);
 If R=0 Then EFlags.s:=EFlags.s+[ZF]Else EFlags.s:=EFlags.s-[ZF];
 If R<0 Then EFlags.s:=EFlags.s+[SF]Else EFlags.s:=EFlags.s-[SF];
 If Parity8(Byte(R))Then EFlags.s:=EFlags.s+[PF]Else EFlags.s:=EFlags.s-[PF];
End;

  { TODO 10 : SHR r/m8, 1 (opcode $D0, reg=5).
    Decalage logique a droite de 1 bit sur operande 8 bits.
    CF recoit le bit le moins significatif evince. }
Procedure OpShrRM8By1;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadByte(Eff)
 Else Val:=GetReg8(RMF);
 If(Val and 1)<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 R:=Val shr 1;
 If(Val and $80)<>0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If IsMem Then WriteByte(Eff,R)
 Else SetReg8(RMF,R);
 If R=0 Then EFlags.s:=EFlags.s+[ZF]Else EFlags.s:=EFlags.s-[ZF];
 If(R and $80)<>0 Then EFlags.s:=EFlags.s+[SF]Else EFlags.s:=EFlags.s-[SF];
 If Parity8(R)Then EFlags.s:=EFlags.s+[PF]Else EFlags.s:=EFlags.s-[PF];
End;

  { TODO 10 : SHR r/m32, 1 (opcode $D1, reg=5). }
Procedure OpShrRM32By1;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If(Val and 1)<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 R:=LongInt((Int64(Val)and $FFFFFFFF)shr 1);
 If Val<0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If IsMem Then WriteDWord(Eff,R)
 Else SetReg32(RMF,R);
 If R=0 Then EFlags.s:=EFlags.s+[ZF]Else EFlags.s:=EFlags.s-[ZF];
 If R<0 Then EFlags.s:=EFlags.s+[SF]Else EFlags.s:=EFlags.s-[SF];
 If Parity8(Byte(R))Then EFlags.s:=EFlags.s+[PF]Else EFlags.s:=EFlags.s-[PF];
End;

  { TODO 10 : SHR r/m8, CL (opcode $D2, reg=5). }
Procedure OpShrRM8ByCL;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:Byte;
 Cnt:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadByte(Eff)
 Else Val:=GetReg8(RMF);
 Cnt:=Regs.CL and $1F;
 If Cnt=0 Then Exit;
 If(Val and(1 shl(Cnt-1)))<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 R:=Val shr Cnt;
 If IsMem Then WriteByte(Eff,R)
 Else SetReg8(RMF,R);
 If R=0 Then EFlags.s:=EFlags.s+[ZF]Else EFlags.s:=EFlags.s-[ZF];
 If(R and $80)<>0 Then EFlags.s:=EFlags.s+[SF]Else EFlags.s:=EFlags.s-[SF];
 If Parity8(R)Then EFlags.s:=EFlags.s+[PF]Else EFlags.s:=EFlags.s-[PF];
End;

  { TODO 10 : SHR r/m32, CL (opcode $D3, reg=5). }
Procedure OpShrRM32ByCL;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:LongInt;
 Cnt:Byte;
 R64:Int64;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 Cnt:=Regs.CL and $1F;
 If Cnt=0 Then Exit;
 If(Val and(LongInt(1)shl(Cnt-1)))<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 R64:=(Int64(Val)and $FFFFFFFF)shr Cnt;
 Val:=LongInt(R64);
 If IsMem Then WriteDWord(Eff,Val)
 Else SetReg32(RMF,Val);
 If Val=0 Then EFlags.s:=EFlags.s+[ZF]Else EFlags.s:=EFlags.s-[ZF];
 If Val<0 Then EFlags.s:=EFlags.s+[SF]Else EFlags.s:=EFlags.s-[SF];
 If Parity8(Byte(Val))Then EFlags.s:=EFlags.s+[PF]Else EFlags.s:=EFlags.s-[PF];
End;

  { TODO 10 : SHR r/m8, imm8 (opcode $C0, reg=5). }
Procedure OpShrRM8Imm;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:Byte;
 Cnt:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 Cnt:=ReadByte(EIP)and $1F;
 Inc(EIP);
 If IsMem Then Val:=ReadByte(Eff)
 Else Val:=GetReg8(RMF);
 If Cnt=0 Then Exit;
 If(Val and(1 shl(Cnt-1)))<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 R:=Val shr Cnt;
 If IsMem Then WriteByte(Eff,R)
 Else SetReg8(RMF,R);
 If R=0 Then EFlags.s:=EFlags.s+[ZF]Else EFlags.s:=EFlags.s-[ZF];
 If(R and $80)<>0 Then EFlags.s:=EFlags.s+[SF]Else EFlags.s:=EFlags.s-[SF];
 If Parity8(R)Then EFlags.s:=EFlags.s+[PF]Else EFlags.s:=EFlags.s-[PF];
End;

  { TODO 10 : SHR r/m32, imm8 (opcode $C1, reg=5). }
Procedure OpShrRM32Imm;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:LongInt;
 Cnt:Byte;
 R64:Int64;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 Cnt:=ReadByte(EIP)and $1F;
 Inc(EIP);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If Cnt=0 Then Exit;
 If(Val and(LongInt(1)shl(Cnt-1)))<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 R64:=(Int64(Val)and $FFFFFFFF)shr Cnt;
 Val:=LongInt(R64);
 If IsMem Then WriteDWord(Eff,Val)
 Else SetReg32(RMF,Val);
 If Val=0 Then EFlags.s:=EFlags.s+[ZF]Else EFlags.s:=EFlags.s-[ZF];
 If Val<0 Then EFlags.s:=EFlags.s+[SF]Else EFlags.s:=EFlags.s-[SF];
 If Parity8(Byte(Val))Then EFlags.s:=EFlags.s+[PF]Else EFlags.s:=EFlags.s-[PF];
End;

  { TODO 10 : SAR r/m8, 1 (opcode $D0, reg=7).
    Decalage arithmetique a droite de 1 bit, preserve le signe. }
Procedure OpSarRM8By1;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:ShortInt;
 R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ShortInt(ReadByte(Eff))
 Else Val:=ShortInt(GetReg8(RMF));
 If(Val and 1)<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 EFlags.s:=EFlags.s-[_OF];
 Val:=Val div 2;
 R:=Byte(Val);
 If IsMem Then WriteByte(Eff,R)
 Else SetReg8(RMF,R);
 If R=0 Then EFlags.s:=EFlags.s+[ZF]Else EFlags.s:=EFlags.s-[ZF];
 If(R and $80)<>0 Then EFlags.s:=EFlags.s+[SF]Else EFlags.s:=EFlags.s-[SF];
 If Parity8(R)Then EFlags.s:=EFlags.s+[PF]Else EFlags.s:=EFlags.s-[PF];
End;

  { TODO 10 : SAR r/m32, 1 (opcode $D1, reg=7). }
Procedure OpSarRM32By1;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If(Val and 1)<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 EFlags.s:=EFlags.s-[_OF];
 If(Val<0)and((Val and 1)<>0)Then R:=(Val div 2)-1
 Else R:=Val div 2;
 If IsMem Then WriteDWord(Eff,R)
 Else SetReg32(RMF,R);
 If R=0 Then EFlags.s:=EFlags.s+[ZF]Else EFlags.s:=EFlags.s-[ZF];
 If R<0 Then EFlags.s:=EFlags.s+[SF]Else EFlags.s:=EFlags.s-[SF];
 If Parity8(Byte(R))Then EFlags.s:=EFlags.s+[PF]Else EFlags.s:=EFlags.s-[PF];
End;

  { TODO 10 : SAR r/m8, CL (opcode $D2, reg=7). }
Procedure OpSarRM8ByCL;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:ShortInt;
 R:Byte;
 Cnt,I:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ShortInt(ReadByte(Eff))
 Else Val:=ShortInt(GetReg8(RMF));
 Cnt:=Regs.CL and $1F;
 If Cnt=0 Then Exit;
 For I:=1 to Cnt do Begin
  If(Val and 1)<>0 Then EFlags.s:=EFlags.s+[CF]
  Else EFlags.s:=EFlags.s-[CF];
  If(Val<0)and((Val and 1)<>0)Then Val:=(Val div 2)-1
  Else Val:=Val div 2;
 End;
 R:=Byte(Val);
 If IsMem Then WriteByte(Eff,R)
 Else SetReg8(RMF,R);
 If R=0 Then EFlags.s:=EFlags.s+[ZF]Else EFlags.s:=EFlags.s-[ZF];
 If(R and $80)<>0 Then EFlags.s:=EFlags.s+[SF]Else EFlags.s:=EFlags.s-[SF];
 If Parity8(R)Then EFlags.s:=EFlags.s+[PF]Else EFlags.s:=EFlags.s-[PF];
End;

  { TODO 10 : SAR r/m32, CL (opcode $D3, reg=7). }
Procedure OpSarRM32ByCL;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:LongInt;
 Cnt,I:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 Cnt:=Regs.CL and $1F;
 If Cnt=0 Then Exit;
 For I:=1 to Cnt do Begin
  If(Val and 1)<>0 Then EFlags.s:=EFlags.s+[CF]
  Else EFlags.s:=EFlags.s-[CF];
  If(Val<0)and((Val and 1)<>0)Then Val:=(Val div 2)-1
  Else Val:=Val div 2;
 End;
 R:=Val;
 If IsMem Then WriteDWord(Eff,R)
 Else SetReg32(RMF,R);
 If R=0 Then EFlags.s:=EFlags.s+[ZF]Else EFlags.s:=EFlags.s-[ZF];
 If R<0 Then EFlags.s:=EFlags.s+[SF]Else EFlags.s:=EFlags.s-[SF];
 If Parity8(Byte(R))Then EFlags.s:=EFlags.s+[PF]Else EFlags.s:=EFlags.s-[PF];
End;

  { TODO 10 : SAR r/m8, imm8 (opcode $C0, reg=7). }
Procedure OpSarRM8Imm;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:ShortInt;
 R:Byte;
 Cnt,I:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 Cnt:=ReadByte(EIP)and $1F;
 Inc(EIP);
 If IsMem Then Val:=ShortInt(ReadByte(Eff))
 Else Val:=ShortInt(GetReg8(RMF));
 If Cnt=0 Then Exit;
 For I:=1 to Cnt do Begin
  If(Val and 1)<>0 Then EFlags.s:=EFlags.s+[CF]
  Else EFlags.s:=EFlags.s-[CF];
  If(Val<0)and((Val and 1)<>0)Then Val:=(Val div 2)-1
  Else Val:=Val div 2;
 End;
 R:=Byte(Val);
 If IsMem Then WriteByte(Eff,R)
 Else SetReg8(RMF,R);
 If R=0 Then EFlags.s:=EFlags.s+[ZF]Else EFlags.s:=EFlags.s-[ZF];
 If(R and $80)<>0 Then EFlags.s:=EFlags.s+[SF]Else EFlags.s:=EFlags.s-[SF];
 If Parity8(R)Then EFlags.s:=EFlags.s+[PF]Else EFlags.s:=EFlags.s-[PF];
End;

  { TODO 10 : SAR r/m32, imm8 (opcode $C1, reg=7). }
Procedure OpSarRM32Imm;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:LongInt;
 Cnt,I:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 Cnt:=ReadByte(EIP)and $1F;
 Inc(EIP);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If Cnt=0 Then Exit;
 For I:=1 to Cnt do Begin
  If(Val and 1)<>0 Then EFlags.s:=EFlags.s+[CF]
  Else EFlags.s:=EFlags.s-[CF];
  If(Val<0)and((Val and 1)<>0)Then Val:=(Val div 2)-1
  Else Val:=Val div 2;
 End;
 R:=Val;
 If IsMem Then WriteDWord(Eff,R)
 Else SetReg32(RMF,R);
 If R=0 Then EFlags.s:=EFlags.s+[ZF]Else EFlags.s:=EFlags.s-[ZF];
 If R<0 Then EFlags.s:=EFlags.s+[SF]Else EFlags.s:=EFlags.s-[SF];
 If Parity8(Byte(R))Then EFlags.s:=EFlags.s+[PF]Else EFlags.s:=EFlags.s-[PF];
End;

  { TODO 10 : ROL r/m8, 1 (opcode $D0, reg=0).
    Rotation a gauche de 1 bit. Le bit MSB est deplace dans CF et
    dans le bit LSB. }
Procedure OpRolRM8By1;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadByte(Eff)
 Else Val:=GetReg8(RMF);
 R:=(Val shl 1)or(Val shr 7);
 If(Val and $80)<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 If((Val xor R)and $80)<>0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If IsMem Then WriteByte(Eff,R)
 Else SetReg8(RMF,R);
End;

  { TODO 10 : ROL r/m32, 1 (opcode $D1, reg=0). }
Procedure OpRolRM32By1;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:LongInt;
 Bit31:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If Val<0 Then Bit31:=1 Else Bit31:=0;
 R:=(Val shl 1)or LongInt(Bit31);
 If Bit31<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 If((Val xor R))<0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If IsMem Then WriteDWord(Eff,R)
 Else SetReg32(RMF,R);
End;

  { TODO 10 : ROL r/m8, CL (opcode $D2, reg=0). }
Procedure OpRolRM8ByCL;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:Byte;
 Cnt,I:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadByte(Eff)
 Else Val:=GetReg8(RMF);
 Cnt:=Regs.CL and $1F;
 If Cnt=0 Then Exit;
 R:=Val;
 For I:=1 to Cnt do Begin
  If(R and $80)<>0 Then EFlags.s:=EFlags.s+[CF]
  Else EFlags.s:=EFlags.s-[CF];
  R:=(R shl 1)or(R shr 7);
 End;
 If IsMem Then WriteByte(Eff,R)
 Else SetReg8(RMF,R);
End;

  { TODO 10 : ROL r/m32, CL (opcode $D3, reg=0). }
Procedure OpRolRM32ByCL;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:LongInt;
 Cnt,I:Byte;
 Bit31:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 Cnt:=Regs.CL and $1F;
 If Cnt=0 Then Exit;
 R:=Val;
 For I:=1 to Cnt do Begin
  If R<0 Then Bit31:=1 Else Bit31:=0;
  If Bit31<>0 Then EFlags.s:=EFlags.s+[CF]
  Else EFlags.s:=EFlags.s-[CF];
  R:=(R shl 1)or LongInt(Bit31);
 End;
 If IsMem Then WriteDWord(Eff,R)
 Else SetReg32(RMF,R);
End;

  { TODO 10 : ROR r/m8, 1 (opcode $D0, reg=1).
    Rotation a droite de 1 bit. }
Procedure OpRorRM8By1;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadByte(Eff)
 Else Val:=GetReg8(RMF);
 R:=(Val shr 1)or(Val shl 7);
 If(Val and 1)<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 If((R xor(R shl 1))and $80)<>0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If IsMem Then WriteByte(Eff,R)
 Else SetReg8(RMF,R);
End;

  { TODO 10 : ROR r/m32, 1 (opcode $D1, reg=1). }
Procedure OpRorRM32By1;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If(Val and 1)<>0 Then Begin
  R:=LongInt((Int64(Val)and $FFFFFFFF)shr 1)or LongInt($80000000);
  EFlags.s:=EFlags.s+[CF];
 End
 Else Begin
  R:=LongInt((Int64(Val)and $FFFFFFFF)shr 1);
  EFlags.s:=EFlags.s-[CF];
 End;
 If((R xor(R shl 1)))<0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If IsMem Then WriteDWord(Eff,R)
 Else SetReg32(RMF,R);
End;

  { TODO 10 : ROR r/m8, CL (opcode $D2, reg=1). }
Procedure OpRorRM8ByCL;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:Byte;
 Cnt,I:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadByte(Eff)
 Else Val:=GetReg8(RMF);
 Cnt:=Regs.CL and $1F;
 If Cnt=0 Then Exit;
 R:=Val;
 For I:=1 to Cnt do Begin
  If(R and 1)<>0 Then EFlags.s:=EFlags.s+[CF]
  Else EFlags.s:=EFlags.s-[CF];
  R:=(R shr 1)or(R shl 7);
 End;
 If IsMem Then WriteByte(Eff,R)
 Else SetReg8(RMF,R);
End;

  { TODO 10 : ROR r/m32, CL (opcode $D3, reg=1). }
Procedure OpRorRM32ByCL;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:LongInt;
 Cnt,I:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 Cnt:=Regs.CL and $1F;
 If Cnt=0 Then Exit;
 R:=Val;
 For I:=1 to Cnt do Begin
  If(R and 1)<>0 Then Begin
   EFlags.s:=EFlags.s+[CF];
   R:=LongInt((Int64(R)and $FFFFFFFF)shr 1)or LongInt($80000000);
  End
  Else Begin
   EFlags.s:=EFlags.s-[CF];
   R:=LongInt((Int64(R)and $FFFFFFFF)shr 1);
  End;
 End;
 If IsMem Then WriteDWord(Eff,R)
 Else SetReg32(RMF,R);
End;

  { TODO 10 : RCL r/m8, 1 (opcode $D0, reg=2).
    Rotation a gauche a travers CF. Le bit MSB va dans CF,
    l'ancien CF va dans le bit LSB. }
Procedure OpRclRM8By1;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:Byte;
 OldCF:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadByte(Eff)
 Else Val:=GetReg8(RMF);
 If CF in EFlags.s Then OldCF:=1 Else OldCF:=0;
 If(Val and $80)<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 R:=(Val shl 1)or OldCF;
 If((Val xor R)and $80)<>0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If IsMem Then WriteByte(Eff,R)
 Else SetReg8(RMF,R);
End;

  { TODO 10 : RCL r/m32, 1 (opcode $D1, reg=2). }
Procedure OpRclRM32By1;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:LongInt;
 OldCF:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If CF in EFlags.s Then OldCF:=1 Else OldCF:=0;
 If Val<0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 R:=(Val shl 1)or OldCF;
 If((Val xor R))<0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If IsMem Then WriteDWord(Eff,R)
 Else SetReg32(RMF,R);
End;

  { TODO 10 : RCL r/m8, CL (opcode $D2, reg=2). }
Procedure OpRclRM8ByCL;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:Byte;
 Cnt,I,OldCF:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadByte(Eff)
 Else Val:=GetReg8(RMF);
 Cnt:=Regs.CL and $1F;
 If Cnt=0 Then Exit;
 R:=Val;
 For I:=1 to Cnt do Begin
  If CF in EFlags.s Then OldCF:=1 Else OldCF:=0;
  If(R and $80)<>0 Then EFlags.s:=EFlags.s+[CF]
  Else EFlags.s:=EFlags.s-[CF];
  R:=(R shl 1)or OldCF;
 End;
 If IsMem Then WriteByte(Eff,R)
 Else SetReg8(RMF,R);
End;

  { TODO 10 : RCL r/m32, CL (opcode $D3, reg=2). }
Procedure OpRclRM32ByCL;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:LongInt;
 Cnt,I:Byte;
 OldCF:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 Cnt:=Regs.CL and $1F;
 If Cnt=0 Then Exit;
 R:=Val;
 For I:=1 to Cnt do Begin
  If CF in EFlags.s Then OldCF:=1 Else OldCF:=0;
  If R<0 Then EFlags.s:=EFlags.s+[CF]
  Else EFlags.s:=EFlags.s-[CF];
  R:=(R shl 1)or OldCF;
 End;
 If IsMem Then WriteDWord(Eff,R)
 Else SetReg32(RMF,R);
End;

  { TODO 10 : RCR r/m8, 1 (opcode $D0, reg=3).
    Rotation a droite a travers CF. Le bit LSB va dans CF,
    l'ancien CF va dans le bit MSB. }
Procedure OpRcrRM8By1;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:Byte;
 OldCF:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadByte(Eff)
 Else Val:=GetReg8(RMF);
 If CF in EFlags.s Then OldCF:=$80 Else OldCF:=0;
 If(Val and 1)<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 R:=(Val shr 1)or OldCF;
 If((Val xor R)and $80)<>0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If IsMem Then WriteByte(Eff,R)
 Else SetReg8(RMF,R);
End;

  { TODO 10 : RCR r/m32, 1 (opcode $D1, reg=3). }
Procedure OpRcrRM32By1;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:LongInt;
 OldCFBit:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If CF in EFlags.s Then OldCFBit:=LongInt($80000000)Else OldCFBit:=0;
 If(Val and 1)<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 R:=LongInt((Int64(Val)and $FFFFFFFF)shr 1)or OldCFBit;
 If((Val xor R))<0 Then EFlags.s:=EFlags.s+[_OF]
 Else EFlags.s:=EFlags.s-[_OF];
 If IsMem Then WriteDWord(Eff,R)
 Else SetReg32(RMF,R);
End;

  { TODO 10 : RCR r/m8, CL (opcode $D2, reg=3). }
Procedure OpRcrRM8ByCL;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:Byte;
 Cnt,I,OldCF:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadByte(Eff)
 Else Val:=GetReg8(RMF);
 Cnt:=Regs.CL and $1F;
 If Cnt=0 Then Exit;
 R:=Val;
 For I:=1 to Cnt do Begin
  If CF in EFlags.s Then OldCF:=$80 Else OldCF:=0;
  If(R and 1)<>0 Then EFlags.s:=EFlags.s+[CF]
  Else EFlags.s:=EFlags.s-[CF];
  R:=(R shr 1)or OldCF;
 End;
 If IsMem Then WriteByte(Eff,R)
 Else SetReg8(RMF,R);
End;

  { TODO 10 : RCR r/m32, CL (opcode $D3, reg=3). }
Procedure OpRcrRM32ByCL;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val,R:LongInt;
 Cnt,I:Byte;
 OldCFBit:LongInt;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 Cnt:=Regs.CL and $1F;
 If Cnt=0 Then Exit;
 R:=Val;
 For I:=1 to Cnt do Begin
  If CF in EFlags.s Then OldCFBit:=LongInt($80000000)Else OldCFBit:=0;
  If(R and 1)<>0 Then EFlags.s:=EFlags.s+[CF]
  Else EFlags.s:=EFlags.s-[CF];
  R:=LongInt((Int64(R)and $FFFFFFFF)shr 1)or OldCFBit;
 End;
 If IsMem Then WriteDWord(Eff,R)
 Else SetReg32(RMF,R);
End;

  { TODO 10 : BT r/m32, r32 (opcode 0F A3).
    Teste le bit specifie par r32 dans r/m32 et copie dans CF. }
Procedure OpBtRM32R32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:LongInt;
 BitIdx:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 BitIdx:=GetReg32(RegF)and 31;
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If(Val and(LongInt(1)shl BitIdx))<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
End;

  { TODO 10 : BTS r/m32, r32 (opcode 0F AB).
    Teste et positionne le bit. CF recoit l'ancienne valeur. }
Procedure OpBtsRM32R32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:LongInt;
 BitIdx:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 BitIdx:=GetReg32(RegF)and 31;
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If(Val and(LongInt(1)shl BitIdx))<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 Val:=Val or(LongInt(1)shl BitIdx);
 If IsMem Then WriteDWord(Eff,Val)
 Else SetReg32(RMF,Val);
End;

  { TODO 10 : BTR r/m32, r32 (opcode 0F B3).
    Teste et efface le bit. CF recoit l'ancienne valeur. }
Procedure OpBtrRM32R32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:LongInt;
 BitIdx:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 BitIdx:=GetReg32(RegF)and 31;
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If(Val and(LongInt(1)shl BitIdx))<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 Val:=Val and not(LongInt(1)shl BitIdx);
 If IsMem Then WriteDWord(Eff,Val)
 Else SetReg32(RMF,Val);
End;

  { TODO 10 : BTC r/m32, r32 (opcode 0F BB).
    Teste et inverse le bit. CF recoit l'ancienne valeur. }
Procedure OpBtcRM32R32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:LongInt;
 BitIdx:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 BitIdx:=GetReg32(RegF)and 31;
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If(Val and(LongInt(1)shl BitIdx))<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 Val:=Val xor(LongInt(1)shl BitIdx);
 If IsMem Then WriteDWord(Eff,Val)
 Else SetReg32(RMF,Val);
End;

  { TODO 10 : BT r/m32, imm8 (opcode 0F BA, reg=4). }
Procedure OpBtRM32Imm;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:LongInt;
 BitIdx:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 BitIdx:=ReadByte(EIP)and 31;
 Inc(EIP);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If(Val and(LongInt(1)shl BitIdx))<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
End;

  { TODO 10 : BTS r/m32, imm8 (opcode 0F BA, reg=5). }
Procedure OpBtsRM32Imm;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:LongInt;
 BitIdx:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 BitIdx:=ReadByte(EIP)and 31;
 Inc(EIP);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If(Val and(LongInt(1)shl BitIdx))<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 Val:=Val or(LongInt(1)shl BitIdx);
 If IsMem Then WriteDWord(Eff,Val)
 Else SetReg32(RMF,Val);
End;

  { TODO 10 : BTR r/m32, imm8 (opcode 0F BA, reg=6). }
Procedure OpBtrRM32Imm;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:LongInt;
 BitIdx:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 BitIdx:=ReadByte(EIP)and 31;
 Inc(EIP);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If(Val and(LongInt(1)shl BitIdx))<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 Val:=Val and not(LongInt(1)shl BitIdx);
 If IsMem Then WriteDWord(Eff,Val)
 Else SetReg32(RMF,Val);
End;

  { TODO 10 : BTC r/m32, imm8 (opcode 0F BA, reg=7). }
Procedure OpBtcRM32Imm;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:LongInt;
 BitIdx:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 BitIdx:=ReadByte(EIP)and 31;
 Inc(EIP);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If(Val and(LongInt(1)shl BitIdx))<>0 Then EFlags.s:=EFlags.s+[CF]
 Else EFlags.s:=EFlags.s-[CF];
 Val:=Val xor(LongInt(1)shl BitIdx);
 If IsMem Then WriteDWord(Eff,Val)
 Else SetReg32(RMF,Val);
End;

  { TODO 10 : BSF r32, r/m32 (opcode 0F BC).
    Recherche du premier bit a 1 en partant du bit 0 (LSB).
    Si l'operande source est 0, ZF=1 et la destination est indefinie.
    Sinon ZF=0 et la destination contient l'index du bit. }
Procedure OpBsfR32RM32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:LongInt;
 I:Byte;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If Val=0 Then
  EFlags.s:=EFlags.s+[ZF]
 Else Begin
  EFlags.s:=EFlags.s-[ZF];
  For I:=0 to 31 do
   If(Val and(LongInt(1)shl I))<>0 Then Begin
    SetReg32(RegF,I);
    Exit;
   End;
 End;
End;

  { TODO 10 : BSR r32, r/m32 (opcode 0F BD).
    Recherche du premier bit a 1 en partant du bit 31 (MSB).
    Si l'operande source est 0, ZF=1 et la destination est indefinie.
    Sinon ZF=0 et la destination contient l'index du bit. }
Procedure OpBsrR32RM32;
Var
 ModF,RegF,RMF:Byte;
 Eff:LongInt;
 IsMem:Boolean;
 Val:LongInt;
 I:Integer;
Begin
 DecodeModRM(ModF,RegF,RMF,Eff,IsMem);
 If IsMem Then Val:=ReadDWord(Eff)
 Else Val:=GetReg32(RMF);
 If Val=0 Then
  EFlags.s:=EFlags.s+[ZF]
 Else Begin
  EFlags.s:=EFlags.s-[ZF];
  For I:=31 downto 0 do
   If(Val and(LongInt(1)shl I))<>0 Then Begin
    SetReg32(RegF,I);
    Exit;
   End;
 End;
End;

  { TODO 11 : MOVSB (opcode A4).
    Copie un octet de [ESI] vers [EDI] et ajuste ESI/EDI selon DF. }
Procedure OpMovsB;
Begin
 WriteByte(Regs.EDI,ReadByte(Regs.ESI));
 If DF in EFlags.s Then Begin
  Dec(Regs.ESI);
  Dec(Regs.EDI);
 End Else Begin
  Inc(Regs.ESI);
  Inc(Regs.EDI);
 End;
End;

  { TODO 11 : MOVSW (opcode 66 A5).
    Copie un mot de [ESI] vers [EDI] et ajuste ESI/EDI selon DF. }
Procedure OpMovsW;
Begin
 WriteWord(Regs.EDI,ReadWord(Regs.ESI));
 If DF in EFlags.s Then Begin
  Dec(Regs.ESI,2);
  Dec(Regs.EDI,2);
 End Else Begin
  Inc(Regs.ESI,2);
  Inc(Regs.EDI,2);
 End;
End;

  { TODO 11 : MOVSD (opcode A5).
    Copie un double mot de [ESI] vers [EDI] et ajuste ESI/EDI selon DF. }
Procedure OpMovsD;
Begin
 WriteDWord(Regs.EDI,ReadDWord(Regs.ESI));
 If DF in EFlags.s Then Begin
  Dec(Regs.ESI,4);
  Dec(Regs.EDI,4);
 End Else Begin
  Inc(Regs.ESI,4);
  Inc(Regs.EDI,4);
 End;
End;

  { TODO 11 : STOSB (opcode AA).
    Ecrit AL dans [EDI] et ajuste EDI selon DF. }
Procedure OpStosB;
Begin
 WriteByte(Regs.EDI,Regs.AL);
 If DF in EFlags.s Then Dec(Regs.EDI)
 Else Inc(Regs.EDI);
End;

  { TODO 11 : STOSW (opcode 66 AB).
    Ecrit AX dans [EDI] et ajuste EDI selon DF. }
Procedure OpStosW;
Begin
 WriteWord(Regs.EDI,Regs.AX);
 If DF in EFlags.s Then Dec(Regs.EDI,2)
 Else Inc(Regs.EDI,2);
End;

  { TODO 11 : STOSD (opcode AB).
    Ecrit EAX dans [EDI] et ajuste EDI selon DF. }
Procedure OpStosD;
Begin
 WriteDWord(Regs.EDI,Regs.EAX);
 If DF in EFlags.s Then Dec(Regs.EDI,4)
 Else Inc(Regs.EDI,4);
End;

  { TODO 11 : LODSB (opcode AC).
    Charge un octet de [ESI] dans AL et ajuste ESI selon DF. }
Procedure OpLodsB;
Begin
 Regs.AL:=ReadByte(Regs.ESI);
 If DF in EFlags.s Then Dec(Regs.ESI)
 Else Inc(Regs.ESI);
End;

  { TODO 11 : LODSW (opcode 66 AD).
    Charge un mot de [ESI] dans AX et ajuste ESI selon DF. }
Procedure OpLodsW;
Begin
 Regs.AX:=ReadWord(Regs.ESI);
 If DF in EFlags.s Then Dec(Regs.ESI,2)
 Else Inc(Regs.ESI,2);
End;

  { TODO 11 : LODSD (opcode AD).
    Charge un double mot de [ESI] dans EAX et ajuste ESI selon DF. }
Procedure OpLodsD;
Begin
 Regs.EAX:=ReadDWord(Regs.ESI);
 If DF in EFlags.s Then Dec(Regs.ESI,4)
 Else Inc(Regs.ESI,4);
End;

  { TODO 11 : CMPSB (opcode A6).
    Compare l'octet [ESI] avec [EDI] (soustraction sans stocker le
    resultat), met a jour les drapeaux et ajuste ESI/EDI selon DF. }
Procedure OpCmpsB;
Begin
 ArithSub8(ReadByte(Regs.ESI),ReadByte(Regs.EDI));
 If DF in EFlags.s Then Begin
  Dec(Regs.ESI);
  Dec(Regs.EDI);
 End Else Begin
  Inc(Regs.ESI);
  Inc(Regs.EDI);
 End;
End;

  { TODO 11 : CMPSW (opcode 66 A7).
    Compare le mot [ESI] avec [EDI], met a jour les drapeaux
    et ajuste ESI/EDI selon DF. }
Procedure OpCmpsW;
Begin
 ArithSub16(ReadWord(Regs.ESI),ReadWord(Regs.EDI));
 If DF in EFlags.s Then Begin
  Dec(Regs.ESI,2);
  Dec(Regs.EDI,2);
 End Else Begin
  Inc(Regs.ESI,2);
  Inc(Regs.EDI,2);
 End;
End;

  { TODO 11 : CMPSD (opcode A7).
    Compare le double mot [ESI] avec [EDI], met a jour les drapeaux
    et ajuste ESI/EDI selon DF. }
Procedure OpCmpsD;
Begin
 ArithSub32(ReadDWord(Regs.ESI),ReadDWord(Regs.EDI));
 If DF in EFlags.s Then Begin
  Dec(Regs.ESI,4);
  Dec(Regs.EDI,4);
 End Else Begin
  Inc(Regs.ESI,4);
  Inc(Regs.EDI,4);
 End;
End;

  { TODO 11 : SCASB (opcode AE).
    Compare AL avec l'octet [EDI] (soustraction AL - [EDI] sans
    stocker le resultat), met a jour les drapeaux et ajuste EDI. }
Procedure OpScasB;
Begin
 ArithSub8(Regs.AL,ReadByte(Regs.EDI));
 If DF in EFlags.s Then Dec(Regs.EDI)
 Else Inc(Regs.EDI);
End;

  { TODO 11 : SCASW (opcode 66 AF).
    Compare AX avec le mot [EDI], met a jour les drapeaux
    et ajuste EDI. }
Procedure OpScasW;
Begin
 ArithSub16(Regs.AX,ReadWord(Regs.EDI));
 If DF in EFlags.s Then Dec(Regs.EDI,2)
 Else Inc(Regs.EDI,2);
End;

  { TODO 11 : SCASD (opcode AF).
    Compare EAX avec le double mot [EDI], met a jour les drapeaux
    et ajuste EDI. }
Procedure OpScasD;
Begin
 ArithSub32(Regs.EAX,ReadDWord(Regs.EDI));
 If DF in EFlags.s Then Dec(Regs.EDI,4)
 Else Inc(Regs.EDI,4);
End;

  { TODO 11 : REP MOVSB (prefixe F3, opcode A4).
    Copie ECX octets de [ESI] vers [EDI]. }
Procedure OpRepMovsB;
Begin
 While Regs.ECX<>0 do Begin
  OpMovsB;
  Dec(Regs.ECX);
 End;
End;

  { TODO 11 : REP MOVSW (prefixe F3, opcode 66 A5).
    Copie ECX mots de [ESI] vers [EDI]. }
Procedure OpRepMovsW;
Begin
 While Regs.ECX<>0 do Begin
  OpMovsW;
  Dec(Regs.ECX);
 End;
End;

  { TODO 11 : REP MOVSD (prefixe F3, opcode A5).
    Copie ECX doubles mots de [ESI] vers [EDI]. }
Procedure OpRepMovsD;
Begin
 While Regs.ECX<>0 do Begin
  OpMovsD;
  Dec(Regs.ECX);
 End;
End;

  { TODO 11 : REP STOSB (prefixe F3, opcode AA).
    Remplit ECX octets a [EDI] avec AL. }
Procedure OpRepStosB;
Begin
 While Regs.ECX<>0 do Begin
  OpStosB;
  Dec(Regs.ECX);
 End;
End;

  { TODO 11 : REP STOSW (prefixe F3, opcode 66 AB).
    Remplit ECX mots a [EDI] avec AX. }
Procedure OpRepStosW;
Begin
 While Regs.ECX<>0 do Begin
  OpStosW;
  Dec(Regs.ECX);
 End;
End;

  { TODO 11 : REP STOSD (prefixe F3, opcode AB).
    Remplit ECX doubles mots a [EDI] avec EAX. }
Procedure OpRepStosD;
Begin
 While Regs.ECX<>0 do Begin
  OpStosD;
  Dec(Regs.ECX);
 End;
End;

  { TODO 11 : REP LODSB (prefixe F3, opcode AC).
    Charge ECX octets successifs de [ESI] dans AL. }
Procedure OpRepLodsB;
Begin
 While Regs.ECX<>0 do Begin
  OpLodsB;
  Dec(Regs.ECX);
 End;
End;

  { TODO 11 : REP LODSW (prefixe F3, opcode 66 AD).
    Charge ECX mots successifs de [ESI] dans AX. }
Procedure OpRepLodsW;
Begin
 While Regs.ECX<>0 do Begin
  OpLodsW;
  Dec(Regs.ECX);
 End;
End;

  { TODO 11 : REP LODSD (prefixe F3, opcode AD).
    Charge ECX doubles mots successifs de [ESI] dans EAX. }
Procedure OpRepLodsD;
Begin
 While Regs.ECX<>0 do Begin
  OpLodsD;
  Dec(Regs.ECX);
 End;
End;

  { TODO 11 : REPE CMPSB (prefixe F3, opcode A6).
    Compare les octets [ESI] et [EDI] tant que ECX<>0 et ZF=1.
    Decremente ECX apres chaque comparaison. }
Procedure OpRepeCmpsB;
Begin
 While Regs.ECX<>0 do Begin
  OpCmpsB;
  Dec(Regs.ECX);
  If Not(ZF in EFlags.s)Then Exit;
 End;
End;

  { TODO 11 : REPE CMPSW (prefixe F3, opcode 66 A7).
    Compare les mots [ESI] et [EDI] tant que ECX<>0 et ZF=1. }
Procedure OpRepeCmpsW;
Begin
 While Regs.ECX<>0 do Begin
  OpCmpsW;
  Dec(Regs.ECX);
  If Not(ZF in EFlags.s)Then Exit;
 End;
End;

  { TODO 11 : REPE CMPSD (prefixe F3, opcode A7).
    Compare les doubles mots [ESI] et [EDI] tant que ECX<>0 et ZF=1. }
Procedure OpRepeCmpsD;
Begin
 While Regs.ECX<>0 do Begin
  OpCmpsD;
  Dec(Regs.ECX);
  If Not(ZF in EFlags.s)Then Exit;
 End;
End;

  { TODO 11 : REPNE CMPSB (prefixe F2, opcode A6).
    Compare les octets [ESI] et [EDI] tant que ECX<>0 et ZF=0.
    Decremente ECX apres chaque comparaison. }
Procedure OpRepneCmpsB;
Begin
 While Regs.ECX<>0 do Begin
  OpCmpsB;
  Dec(Regs.ECX);
  If ZF in EFlags.s Then Exit;
 End;
End;

  { TODO 11 : REPNE CMPSW (prefixe F2, opcode 66 A7).
    Compare les mots [ESI] et [EDI] tant que ECX<>0 et ZF=0. }
Procedure OpRepneCmpsW;
Begin
 While Regs.ECX<>0 do Begin
  OpCmpsW;
  Dec(Regs.ECX);
  If ZF in EFlags.s Then Exit;
 End;
End;

  { TODO 11 : REPNE CMPSD (prefixe F2, opcode A7).
    Compare les doubles mots [ESI] et [EDI] tant que ECX<>0 et ZF=0. }
Procedure OpRepneCmpsD;
Begin
 While Regs.ECX<>0 do Begin
  OpCmpsD;
  Dec(Regs.ECX);
  If ZF in EFlags.s Then Exit;
 End;
End;

  { TODO 11 : REPE SCASB (prefixe F3, opcode AE).
    Compare AL avec [EDI] tant que ECX<>0 et ZF=1.
    Decremente ECX apres chaque comparaison. }
Procedure OpRepeScasB;
Begin
 While Regs.ECX<>0 do Begin
  OpScasB;
  Dec(Regs.ECX);
  If Not(ZF in EFlags.s)Then Exit;
 End;
End;

  { TODO 11 : REPE SCASW (prefixe F3, opcode 66 AF).
    Compare AX avec [EDI] tant que ECX<>0 et ZF=1. }
Procedure OpRepeScasW;
Begin
 While Regs.ECX<>0 do Begin
  OpScasW;
  Dec(Regs.ECX);
  If Not(ZF in EFlags.s)Then Exit;
 End;
End;

  { TODO 11 : REPE SCASD (prefixe F3, opcode AF).
    Compare EAX avec [EDI] tant que ECX<>0 et ZF=1. }
Procedure OpRepeScasD;
Begin
 While Regs.ECX<>0 do Begin
  OpScasD;
  Dec(Regs.ECX);
  If Not(ZF in EFlags.s)Then Exit;
 End;
End;

  { TODO 11 : REPNE SCASB (prefixe F2, opcode AE).
    Compare AL avec [EDI] tant que ECX<>0 et ZF=0.
    Decremente ECX apres chaque comparaison. }
Procedure OpRepneScasB;
Begin
 While Regs.ECX<>0 do Begin
  OpScasB;
  Dec(Regs.ECX);
  If ZF in EFlags.s Then Exit;
 End;
End;

  { TODO 11 : REPNE SCASW (prefixe F2, opcode 66 AF).
    Compare AX avec [EDI] tant que ECX<>0 et ZF=0. }
Procedure OpRepneScasW;
Begin
 While Regs.ECX<>0 do Begin
  OpScasW;
  Dec(Regs.ECX);
  If ZF in EFlags.s Then Exit;
 End;
End;

  { TODO 11 : REPNE SCASD (prefixe F2, opcode AF).
    Compare EAX avec [EDI] tant que ECX<>0 et ZF=0. }
Procedure OpRepneScasD;
Begin
 While Regs.ECX<>0 do Begin
  OpScasD;
  Dec(Regs.ECX);
  If ZF in EFlags.s Then Exit;
 End;
End;

  { TODO 12 : Evaluation d'une condition x86 (cc = 0..15).
    Retourne True si la condition est satisfaite selon EFLAGS.
    Les 16 conditions correspondent aux opcodes Jcc ($70+cc)
    et aux opcodes etendus 0F Jcc ($0F $80+cc) :
      0=O, 1=NO, 2=B/C, 3=NB/NC, 4=Z/E, 5=NZ/NE,
      6=BE/NA, 7=NBE/A, 8=S, 9=NS, 10=P/PE, 11=NP/PO,
      12=L/NGE, 13=NL/GE, 14=LE/NG, 15=NLE/G }
Function CheckCondition(cc:Byte):Boolean;
Var
 SFVal,OFVal:Boolean;
Begin
 SFVal:=SF in EFlags.s;
 OFVal:=_OF in EFlags.s;
 Case cc of
  0:CheckCondition:=_OF in EFlags.s;                                { JO }
  1:CheckCondition:=Not(_OF in EFlags.s);                           { JNO }
  2:CheckCondition:=CF in EFlags.s;                                 { JB/JC/JNAE }
  3:CheckCondition:=Not(CF in EFlags.s);                            { JNB/JNC/JAE }
  4:CheckCondition:=ZF in EFlags.s;                                 { JZ/JE }
  5:CheckCondition:=Not(ZF in EFlags.s);                            { JNZ/JNE }
  6:CheckCondition:=(CF in EFlags.s)or(ZF in EFlags.s);             { JBE/JNA }
  7:CheckCondition:=Not(CF in EFlags.s)and Not(ZF in EFlags.s);     { JNBE/JA }
  8:CheckCondition:=SF in EFlags.s;                                 { JS }
  9:CheckCondition:=Not(SF in EFlags.s);                            { JNS }
  10:CheckCondition:=PF in EFlags.s;                                { JP/JPE }
  11:CheckCondition:=Not(PF in EFlags.s);                           { JNP/JPO }
  12:CheckCondition:=SFVal<>OFVal;                                  { JL/JNGE }
  13:CheckCondition:=SFVal=OFVal;                                   { JNL/JGE }
  14:CheckCondition:=(ZF in EFlags.s)or(SFVal<>OFVal);              { JLE/JNG }
  15:CheckCondition:=Not(ZF in EFlags.s)and(SFVal=OFVal);           { JNLE/JG }
  Else CheckCondition:=False;
 End;
End;

  { TODO 12 : Jcc short rel8 (opcodes $70-$7F).
    Saut conditionnel avec deplacement relatif signe de 8 bits.
    Le deplacement est relatif a l'adresse apres l'instruction
    (EIP pointe deja apres l'opcode quand cette procedure est appelee,
    on lit le rel8 et on avance EIP de 1, puis on ajoute le
    deplacement si la condition est satisfaite). }
Procedure OpJccShort(cc:Byte);
Var
 Rel8:ShortInt;
Begin
 Rel8:=ShortInt(ReadByte(EIP));
 Inc(EIP);
 If CheckCondition(cc)Then
  EIP:=EIP+LongInt(Rel8);
End;

  { TODO 12 : Jcc near rel32 (opcodes $0F $80-$8F).
    Saut conditionnel avec deplacement relatif signe de 32 bits.
    Le deplacement est relatif a l'adresse apres l'instruction
    (apres les 2 octets d'opcode 0F xx et les 4 octets de rel32). }
Procedure OpJccNear(cc:Byte);
Var
 Rel32:LongInt;
Begin
 Rel32:=ReadDWord(EIP);
 Inc(EIP,4);
 If CheckCondition(cc)Then
  EIP:=EIP+Rel32;
End;

  { TODO 12 : JMP short rel8 (opcode $EB).
    Saut inconditionnel avec deplacement relatif signe de 8 bits. }
Procedure OpJmpShort;
Var
 Rel8:ShortInt;
Begin
 Rel8:=ShortInt(ReadByte(EIP));
 Inc(EIP);
 EIP:=EIP+LongInt(Rel8);
End;

  { TODO 12 : JMP near rel32 (opcode $E9).
    Saut inconditionnel avec deplacement relatif signe de 32 bits. }
Procedure OpJmpNear;
Var
 Rel32:LongInt;
Begin
 Rel32:=ReadDWord(EIP);
 Inc(EIP,4);
 EIP:=EIP+Rel32;
End;

  { TODO 12 : JMP r/m32 (opcode $FF /4).
    Saut inconditionnel indirect : l'adresse cible est lue depuis
    un registre 32 bits ou une adresse memoire. L'octet ModR/M
    a deja ete lu par le dispatch ; le champ reg doit valoir 4.
    Si mod=11, la cible est un registre ; sinon, elle est lue
    depuis la memoire a l'adresse effective. }
Procedure OpJmpRM32;
Var
 ModField,RegField,RMField:Byte;
 EffAddr:LongInt;
 IsMemory:Boolean;
Begin
 DecodeModRM(ModField,RegField,RMField,EffAddr,IsMemory);
 If IsMemory Then
  EIP:=ReadDWord(EffAddr)
 Else
  EIP:=GetReg32(RMField);
End;

  { TODO 12 : JMP short rel8 conditionnel - JCXZ/JECXZ (opcode $E3).
    Saut si ECX = 0 avec deplacement relatif signe de 8 bits.
    En mode 32 bits, c'est JECXZ. }
Procedure OpJecxz;
Var
 Rel8:ShortInt;
Begin
 Rel8:=ShortInt(ReadByte(EIP));
 Inc(EIP);
 If Regs.ECX=0 Then
  EIP:=EIP+LongInt(Rel8);
End;

  { TODO 12 : LOOP rel8 (opcode $E2).
    Decremente ECX et saute si ECX <> 0. }
Procedure OpLoop;
Var
 Rel8:ShortInt;
Begin
 Rel8:=ShortInt(ReadByte(EIP));
 Inc(EIP);
 Dec(Regs.ECX);
 If Regs.ECX<>0 Then
  EIP:=EIP+LongInt(Rel8);
End;

  { TODO 12 : LOOPE/LOOPZ rel8 (opcode $E1).
    Decremente ECX et saute si ECX <> 0 et ZF = 1. }
Procedure OpLoope;
Var
 Rel8:ShortInt;
Begin
 Rel8:=ShortInt(ReadByte(EIP));
 Inc(EIP);
 Dec(Regs.ECX);
 If(Regs.ECX<>0)and(ZF in EFlags.s)Then
  EIP:=EIP+LongInt(Rel8);
End;

  { TODO 12 : LOOPNE/LOOPNZ rel8 (opcode $E0).
    Decremente ECX et saute si ECX <> 0 et ZF = 0. }
Procedure OpLoopne;
Var
 Rel8:ShortInt;
Begin
 Rel8:=ShortInt(ReadByte(EIP));
 Inc(EIP);
 Dec(Regs.ECX);
 If(Regs.ECX<>0)and Not(ZF in EFlags.s)Then
  EIP:=EIP+LongInt(Rel8);
End;

  { TODO 13 : CALL near rel32 (opcode $E8).
    Appel de sous-programme avec deplacement relatif signe de 32 bits.
    Empile l'adresse de retour (EIP apres lecture du rel32) sur la
    pile, puis ajoute le deplacement a EIP. }
Procedure OpCallNear;
Var
 Rel32:LongInt;
Begin
 Rel32:=ReadDWord(EIP);
 Inc(EIP,4);
 Push32(EIP);
 EIP:=EIP+Rel32;
End;

  { TODO 13 : CALL r/m32 (opcode $FF /2).
    Appel de sous-programme indirect : la cible est lue depuis
    un registre 32 bits ou une adresse memoire. Empile l'adresse
    de retour (EIP courant) sur la pile, puis charge EIP avec
    la valeur lue. Cela inclut CALL EAX, CALL [mem], etc. }
Procedure OpCallRM32;
Var
 ModField,RegField,RMField:Byte;
 EffAddr:LongInt;
 IsMemory:Boolean;
 Target:LongInt;
Begin
 DecodeModRM(ModField,RegField,RMField,EffAddr,IsMemory);
 If IsMemory Then
  Target:=ReadDWord(EffAddr)
 Else
  Target:=GetReg32(RMField);
 Push32(EIP);
 EIP:=Target;
End;

  { TODO 13 : RET (opcode $C3).
    Retour de sous-programme : depile l'adresse de retour depuis
    la pile et la charge dans EIP. }
Procedure OpRet;
Begin
 EIP:=Pop32;
End;

  { TODO 13 : RET imm16 (opcode $C2).
    Retour de sous-programme avec nettoyage de la pile : depile
    l'adresse de retour dans EIP, puis ajoute imm16 octets a ESP
    pour liberer les parametres empiles par l'appelant.
    Utilise par la convention STDCALL de Win32. }
Procedure OpRetImm16;
Var
 Imm16:Word;
Begin
 Imm16:=ReadWord(EIP);
 Inc(EIP,2);
 EIP:=Pop32;
 Regs.ESP:=Regs.ESP+LongInt(Imm16);
End;

  { TODO 14 : SETcc r/m8 (opcodes $0F $90-$9F).
    Positionne l'octet destination a 1 si la condition cc est
    satisfaite, a 0 sinon. Utilise CheckCondition(cc) du TODO 12.
    Le ModR/M utilise le champ reg=0 (non significatif). }
Procedure OpSETcc(cc:Byte);
Var
 ModField,RegField,RMField:Byte;
 EffAddr:LongInt;
 IsMemory:Boolean;
 Val:Byte;
Begin
 DecodeModRM(ModField,RegField,RMField,EffAddr,IsMemory);
 If CheckCondition(cc)Then
  Val:=1
 Else
  Val:=0;
 If IsMemory Then
  WriteByte(EffAddr,Val)
 Else
  SetReg8(RMField,Val);
End;

  { TODO 14 : CMOVcc r32,r/m32 (opcodes $0F $40-$4F).
    Deplacement conditionnel : copie la source dans le registre
    destination 32 bits seulement si la condition cc est satisfaite.
    Instruction du Pentium Pro (architecture P6). Le ModR/M encode
    la destination dans le champ reg et la source dans le champ r/m. }
Procedure OpCMOVcc(cc:Byte);
Var
 ModField,RegField,RMField:Byte;
 EffAddr:LongInt;
 IsMemory:Boolean;
 SrcVal:LongInt;
Begin
 DecodeModRM(ModField,RegField,RMField,EffAddr,IsMemory);
 If IsMemory Then
  SrcVal:=ReadDWord(EffAddr)
 Else
  SrcVal:=GetReg32(RMField);
 If CheckCondition(cc)Then
  SetReg32(RegField,SrcVal);
End;

  { TODO 14 : CDQ (opcode $99).
    Convert Doubleword to Quadword : etend le bit de signe de EAX
    dans EDX. Si EAX est negatif (bit 31 = 1), EDX := $FFFFFFFF,
    sinon EDX := $00000000. Utilise pour preparer IDIV. }
Procedure OpCdq;
Begin
 If Regs.EAX<0 Then
  Regs.EDX:=LongInt($FFFFFFFF)
 Else
  Regs.EDX:=0;
End;

  { TODO 14 : CBW (opcode $66 $98).
    Convert Byte to Word : etend le bit de signe de AL dans AH.
    Si AL >= $80 alors AH := $FF, sinon AH := $00. }
Procedure OpCbw;
Begin
 If Regs.AL>=$80 Then
  Regs.AH:=$FF
 Else
  Regs.AH:=$00;
End;

  { TODO 14 : CWDE (opcode $98).
    Convert Word to Doubleword Extended : etend le bit de signe
    de AX dans la partie haute de EAX (bits 16-31).
    EAX := sign-extend(AX). }
Procedure OpCwde;
Var
 Val16:SmallInt;
Begin
 Val16:=SmallInt(Regs.AX);
 Regs.EAX:=LongInt(Val16);
End;

  { TODO 14 : CLC (opcode $F8).
    Clear Carry Flag : met CF a 0 dans EFLAGS. }
Procedure OpClc;
Begin
 EFlags.s:=EFlags.s-[CF];
End;

  { TODO 14 : STC (opcode $F9).
    Set Carry Flag : met CF a 1 dans EFLAGS. }
Procedure OpStc;
Begin
 EFlags.s:=EFlags.s+[CF];
End;

  { TODO 14 : CMC (opcode $F5).
    Complement Carry Flag : inverse l'etat de CF dans EFLAGS. }
Procedure OpCmc;
Begin
 If CF in EFlags.s Then
  EFlags.s:=EFlags.s-[CF]
 Else
  EFlags.s:=EFlags.s+[CF];
End;

  { TODO 14 : CLD (opcode $FC).
    Clear Direction Flag : met DF a 0 dans EFLAGS.
    Les instructions de chaines incrementent ESI/EDI. }
Procedure OpCld;
Begin
 EFlags.s:=EFlags.s-[DF];
End;

  { TODO 14 : STD (opcode $FD).
    Set Direction Flag : met DF a 1 dans EFLAGS.
    Les instructions de chaines decrementent ESI/EDI. }
Procedure OpStd;
Begin
 EFlags.s:=EFlags.s+[DF];
End;

  { TODO 14 : NOP (opcode $90).
    No Operation : ne fait rien. Correspond aussi a XCHG EAX,EAX. }
Procedure OpNop;
Begin
 { Ne fait rien }
End;

  { TODO 14 : LEAVE (opcode $C9).
    Restaure le cadre de pile : ESP := EBP, puis EBP := Pop32.
    Equivalent a MOV ESP,EBP suivi de POP EBP.
    Inverse de l'instruction ENTER. }
Procedure OpLeave;
Begin
 Regs.ESP:=Regs.EBP;
 Regs.EBP:=Pop32;
End;

  { TODO 14 : ENTER imm16,imm8 (opcode $C8).
    Cree un cadre de pile : empile EBP, copie ESP dans EBP,
    puis soustrait imm16 octets a ESP pour les variables locales.
    Le parametre imm8 (niveau d'imbrication) est lu mais seul
    le niveau 0 est implemente (cas usuel en Win32). }
Procedure OpEnter;
Var
 Imm16:Word;
 Level:Byte;
Begin
 Imm16:=ReadWord(EIP);
 Inc(EIP,2);
 Level:=ReadByte(EIP);
 Inc(EIP);
 Push32(Regs.EBP);
 Regs.EBP:=Regs.ESP;
 Regs.ESP:=Regs.ESP-LongInt(Imm16);
End;

  { TODO 14 : INT3 (opcode $CC).
    Breakpoint : declenche une interruption logicielle de debogage.
    Dans l'emulateur, on affiche un message et on arrete l'execution
    en positionnant EIP a 0 (convention d'arret de l'emulateur). }
Procedure OpInt3;
Begin
 WriteLn('INT3 breakpoint a EIP=$',HexStr(EIP-1,8));
 EIP:=0;
End;

  { TODO 15 : Ecriture d'une chaine ASCII terminee par un zero
    dans la memoire lineaire 32 bits a l'adresse donnee.
    Retourne l'adresse juste apres le zero terminal. }
Function WriteStringToMem(Addr:LongInt;Const S:String):LongInt;
Var
 I:Integer;
Begin
 For I:=1 to Length(S) do
  WriteByte(Addr+LongInt(I-1),Byte(S[I]));
 WriteByte(Addr+LongInt(Length(S)),0);
 WriteStringToMem:=Addr+LongInt(Length(S))+1;
End;

  { TODO 15 : Ecriture d'une chaine Unicode (UTF-16LE) terminee par un
    zero dans la memoire lineaire 32 bits. Chaque caractere ASCII
    est etendu sur 2 octets (octet bas = ASCII, octet haut = 0).
    Retourne l'adresse juste apres le zero terminal (2 octets). }
Function WriteWideStringToMem(Addr:LongInt;Const S:String):LongInt;
Var
 I:Integer;
Begin
 For I:=1 to Length(S) do Begin
  WriteByte(Addr+LongInt((I-1)*2),Byte(S[I]));
  WriteByte(Addr+LongInt((I-1)*2+1),0);
 End;
 WriteWord(Addr+LongInt(Length(S)*2),0);
 WriteWideStringToMem:=Addr+LongInt(Length(S)*2)+2;
End;

  { TODO 15 : Initialisation des donnees du processus emule.
    Ecrit la chaine de commande ASCII et Unicode, et la structure
    STARTUPINFOA dans la zone ProcessDataBase ($D00000). }
Procedure InitProcessData;
Var
 CmdLine:String;
 NextAddr:LongInt;
 I:Integer;
Begin
  { Construire la chaine de commande a partir des parametres reels }
 CmdLine:=ParamStr(0);
 For I:=1 to ParamCount do
  CmdLine:=CmdLine+' '+ParamStr(I);
 If CmdLine='' Then CmdLine:='EMUW32.EXE';
  { Ecrire la chaine de commande ASCII }
 CmdLineAddrA:=ProcessDataBase;
 NextAddr:=WriteStringToMem(CmdLineAddrA,CmdLine);
  { Aligner sur 4 octets }
 If(NextAddr and 3)<>0 Then
  NextAddr:=(NextAddr or 3)+1;
  { Ecrire la chaine de commande Unicode (UTF-16LE) }
 CmdLineAddrW:=NextAddr;
 NextAddr:=WriteWideStringToMem(CmdLineAddrW,CmdLine);
  { Aligner sur 4 octets }
 If(NextAddr and 3)<>0 Then
  NextAddr:=(NextAddr or 3)+1;
  { Ecrire la structure STARTUPINFOA initialisee a zero
    sauf le champ cb (taille de la structure, offset 0, 4 octets) }
 StartupInfoAddr:=NextAddr;
 For I:=0 to STARTUPINFOA_SIZE-1 do
  WriteByte(StartupInfoAddr+LongInt(I),0);
 WriteDWord(StartupInfoAddr,STARTUPINFOA_SIZE);
  { Initialiser les variables d'etat du processus }
 EmuExitCode:=0;
 EmuRunning:=True;
End;

  { TODO 15 : Emulation de GetStdHandle (KERNEL32.DLL).
    HANDLE WINAPI GetStdHandle(DWORD nStdHandle);
    Convention STDCALL : 1 parametre (4 octets), nettoyage par l'appele.
    Retourne un handle emule dans EAX. }
Procedure EmuGetStdHandle;
Var
 nStdHandle:LongInt;
Begin
 nStdHandle:=ReadDWord(Regs.ESP+4);
 Case nStdHandle of
  STD_INPUT_HANDLE:Regs.EAX:=EMU_STDIN_HANDLE;
  STD_OUTPUT_HANDLE:Regs.EAX:=EMU_STDOUT_HANDLE;
  STD_ERROR_HANDLE:Regs.EAX:=EMU_STDERR_HANDLE;
 Else
  Regs.EAX:=LongInt(-1);  { INVALID_HANDLE_VALUE }
 End;
  { Nettoyer la pile (RET deja fait par l'appelant via RET dans le thunk,
    mais en STDCALL l'appele nettoie les parametres).
    Ici on simule le RET imm16 : depiler l'adresse de retour + 4 octets
    de parametres. L'adresse de retour est deja depilee par le
    mecanisme de CALL/RET, donc on nettoie seulement les parametres. }
 Regs.ESP:=Regs.ESP+4;
End;

  { TODO 15 : Emulation de ExitProcess (KERNEL32.DLL).
    VOID WINAPI ExitProcess(UINT uExitCode);
    Convention STDCALL : 1 parametre (4 octets).
    Arrete l'emulation avec le code de sortie donne. }
Procedure EmuExitProcessProc;
Var
 uExitCode:LongInt;
Begin
 uExitCode:=ReadDWord(Regs.ESP+4);
 EmuExitCode:=uExitCode;
 EmuRunning:=False;
 EIP:=0;
 WriteLn('ExitProcess(',uExitCode,') appele.');
  { Nettoyer la pile : 1 parametre }
 Regs.ESP:=Regs.ESP+4;
End;

  { TODO 15 : Emulation de GetCommandLineA (KERNEL32.DLL).
    LPSTR WINAPI GetCommandLineA(void);
    Convention STDCALL : 0 parametres.
    Retourne dans EAX un pointeur vers la chaine de commande ASCII. }
Procedure EmuGetCommandLineA;
Begin
 Regs.EAX:=CmdLineAddrA;
End;

  { TODO 15 : Emulation de GetCommandLineW (KERNEL32.DLL).
    LPWSTR WINAPI GetCommandLineW(void);
    Convention STDCALL : 0 parametres.
    Retourne dans EAX un pointeur vers la chaine de commande Unicode. }
Procedure EmuGetCommandLineW;
Begin
 Regs.EAX:=CmdLineAddrW;
End;

  { TODO 15 : Emulation de GetCurrentProcessId (KERNEL32.DLL).
    DWORD WINAPI GetCurrentProcessId(void);
    Convention STDCALL : 0 parametres.
    Retourne dans EAX un identifiant de processus fictif. }
Procedure EmuGetCurrentProcessId;
Begin
 Regs.EAX:=EMU_PROCESS_ID;
End;

  { TODO 15 : Emulation de GetCurrentProcess (KERNEL32.DLL).
    HANDLE WINAPI GetCurrentProcess(void);
    Convention STDCALL : 0 parametres.
    Retourne dans EAX le pseudo-handle du processus courant (-1). }
Procedure EmuGetCurrentProcess;
Begin
 Regs.EAX:=EMU_CURRENT_PROCESS;
End;

  { TODO 15 : Emulation de GetExitCodeProcess (KERNEL32.DLL).
    BOOL WINAPI GetExitCodeProcess(HANDLE hProcess,
                                    LPDWORD lpExitCode);
    Convention STDCALL : 2 parametres (8 octets).
    Ecrit le code de sortie du processus dans *lpExitCode et
    retourne TRUE (1) dans EAX. }
Procedure EmuGetExitCodeProcess;
Var
 lpExitCode:LongInt;
Begin
 lpExitCode:=ReadDWord(Regs.ESP+8);
 If lpExitCode<>0 Then
  WriteDWord(lpExitCode,EmuExitCode);
 Regs.EAX:=1;  { TRUE }
  { Nettoyer la pile : 2 parametres }
 Regs.ESP:=Regs.ESP+8;
End;

  { TODO 15 : Emulation de GetStartupInfoA (KERNEL32.DLL).
    VOID WINAPI GetStartupInfoA(LPSTARTUPINFOA lpStartupInfo);
    Convention STDCALL : 1 parametre (4 octets).
    Copie la structure STARTUPINFOA pre-initialisee vers l'adresse
    fournie par l'appelant. }
Procedure EmuGetStartupInfoA;
Var
 lpStartupInfo:LongInt;
 I:Integer;
 B:Byte;
Begin
 lpStartupInfo:=ReadDWord(Regs.ESP+4);
 If lpStartupInfo<>0 Then Begin
  For I:=0 to STARTUPINFOA_SIZE-1 do Begin
   B:=ReadByte(StartupInfoAddr+LongInt(I));
   WriteByte(lpStartupInfo+LongInt(I),B);
  End;
 End;
  { Nettoyer la pile : 1 parametre }
 Regs.ESP:=Regs.ESP+4;
End;

  { TODO 15 : Comparaison de chaines insensible a la casse.
    Compare deux String Pascal en ignorant la casse des lettres.
    Retourne True si les chaines sont identiques (insensible a la casse). }
Function StrIComp(Const A,B:String):Boolean;
Var
 I:Integer;
Begin
 StrIComp:=False;
 If Length(A)<>Length(B) Then Exit;
 For I:=1 to Length(A) do
  If UpCase(A[I])<>UpCase(B[I]) Then Exit;
 StrIComp:=True;
End;

  { TODO 15 : Dispatche un appel a une fonction de KERNEL32.DLL.
    Recoit l'index de l'entree d'importation dans ImportEntries
    et appelle la procedure d'emulation correspondante.
    Retourne True si la fonction a ete emulée, False sinon. }
Function DispatchKernel32(Idx:Integer):Boolean;
Var
 FName:String;
Begin
 DispatchKernel32:=True;
 FName:=ImportEntries[Idx].FuncName;
 If StrIComp(FName,'GetStdHandle') Then
  EmuGetStdHandle
 Else If StrIComp(FName,'ExitProcess') Then
  EmuExitProcessProc
 Else If StrIComp(FName,'GetCommandLineA') Then
  EmuGetCommandLineA
 Else If StrIComp(FName,'GetCommandLineW') Then
  EmuGetCommandLineW
 Else If StrIComp(FName,'GetCurrentProcessId') Then
  EmuGetCurrentProcessId
 Else If StrIComp(FName,'GetCurrentProcess') Then
  EmuGetCurrentProcess
 Else If StrIComp(FName,'GetExitCodeProcess') Then
  EmuGetExitCodeProcess
 Else If StrIComp(FName,'GetStartupInfoA') Then
  EmuGetStartupInfoA
 Else Begin
  WriteLn('KERNEL32: fonction non emulée: ',FName);
  DispatchKernel32:=False;
 End;
End;

  { TODO 15 : Dispatche un appel vers un thunk d'importation.
    Verifie si l'adresse courante (EIP) est dans la zone des thunks
    ($E00000-$EFFFFF). Si oui, cherche l'entree d'importation
    correspondante et dispatche vers l'emulation KERNEL32.DLL.
    Retourne True si le thunk a ete traite. }
Function HandleThunkCall(Addr:LongInt):Boolean;
Var
 Idx:Integer;
 OK:Boolean;
Begin
 HandleThunkCall:=False;
 If(Addr<ThunkBase)or(Addr>=$F00000)Then Exit;
 Idx:=FindImportByAddr(Addr);
 If Idx<0 Then Begin
  WriteLn('HandleThunkCall: thunk inconnu a $',HexStr(Addr,8));
  Exit;
 End;
 If StrIComp(ImportEntries[Idx].DLLName,'KERNEL32.DLL')or
    StrIComp(ImportEntries[Idx].DLLName,'kernel32.dll')or
    StrIComp(ImportEntries[Idx].DLLName,'KERNEL32')or
    StrIComp(ImportEntries[Idx].DLLName,'kernel32')Then Begin
  OK:=DispatchKernel32(Idx);
  HandleThunkCall:=OK;
  If OK Then Begin
    { Simuler le RET : depiler l'adresse de retour }
   EIP:=Pop32;
  End;
 End
 Else
  WriteLn('HandleThunkCall: DLL non emulée: ',
          ImportEntries[Idx].DLLName,'!',
          ImportEntries[Idx].FuncName);
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
