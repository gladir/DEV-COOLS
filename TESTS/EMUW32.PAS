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

  6.  Implementer le chargement des sections PE (.text, .data,
      .rdata, .bss, .idata) dans la memoire lineaire en respectant
      les VirtualAddress et VirtualSize de chaque
      IMAGE_SECTION_HEADER, et remplir les zones .bss de zeros.

  7.  Implementer le traitement de la table d'importation (Import
      Directory Table / IAT) pour resoudre les appels aux DLL
      importees, en particulier KERNEL32.DLL, en remplissant la
      Import Address Table avec des adresses de thunks internes
      emulant chaque fonction.

  8.  Implementer les instructions de transfert de donnees 32 bits :
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
 Close(F);
 PELoaded:=True;
 LoadPE:=True;
 WriteLn('LoadPE: Fichier PE charge avec succes.');
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
