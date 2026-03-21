{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2024
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

{ TODO - Liste des 25 points a implementer pour l'emulateur DPMI :

  1.  Creer le fichier d'echange de 16 Mo (EMUDPMI.$$$) servant de
      memoire lineaire pour l'espace d'adressage en mode protege,
      similaire au SwapFileMemory d'EMU8086.PAS mais avec un espace
      de 16 777 216 octets (16 Mo) au lieu de 1 Mo.

  2.  Definir les registres 32 bits du 80386 : EAX, EBX, ECX, EDX,
      ESI, EDI, EBP, ESP avec un acces aux sous-parties 16 bits
      (AX, BX, ...) et 8 bits (AL, AH, ...) par des records variants.

  3.  Definir les registres de segment en mode protege : CS, DS, ES,
      SS, FS, GS comme des selecteurs (16 bits) et non comme des
      adresses reelles de paragraphe.

  4.  Implementer la table des descripteurs (LDT - Local Descriptor
      Table) contenant au minimum 256 entrees, chaque descripteur
      stockant : adresse de base 32 bits, limite, type d'acces, et
      granularite (bit G pour pages 4 Ko).

  5.  Implementer la conversion d'adresse selecteur:offset en adresse
      lineaire 32 bits a l'aide de la LDT, en remplacement de la
      formule segment*16+offset du mode reel.

  6.  Implementer les procedures ReadByte/ReadWord/ReadDWord et
      WriteByte/WriteWord/WriteDWord pour l'acces a la memoire
      lineaire 32 bits via le fichier de 16 Mo.

  7.  Implementer la pile 32 bits (PUSH/POP en mode 32 bits) avec
      ESP et SS pouvant adresser tout l'espace 16 Mo.

  8.  Implementer les instructions de transfert de donnees 32 bits :
      MOV reg32,reg32 / MOV reg32,imm32 / MOV reg32,[mem] /
      MOV [mem],reg32 avec le prefixe de taille d'operande (66h).

  9.  Implementer les instructions arithmetiques 32 bits : ADD, SUB,
      ADC, SBB, CMP, INC, DEC, NEG, MUL, IMUL, DIV, IDIV sur des
      operandes 32 bits avec mise a jour correcte des drapeaux
      (CF, ZF, SF, OF, AF, PF).

  10. Implementer les instructions logiques et de decalage 32 bits :
      AND, OR, XOR, NOT, TEST, SHL, SHR, SAR, ROL, ROR, RCL, RCR
      sur des operandes 32 bits.

  11. Implementer les instructions de chaines 32 bits : MOVSD, STOSD,
      LODSD, CMPSD, SCASD ainsi que le prefixe REP/REPE/REPNE
      utilisant ECX comme compteur.

  12. Implementer les instructions de saut conditionnel 32 bits (Jcc
      near avec deplacement 32 bits, prefixe 0Fh) et les sauts
      inconditionnels JMP near/far en mode protege.

  13. Implementer CALL near/far et RET/RETF en mode protege 32 bits,
      avec empilement/depilement de EIP et CS sur la pile 32 bits.

  14. Implementer les prefixes de remplacement de segment (ES:, CS:,
      SS:, DS:, FS:, GS:) et le prefixe de taille d'adresse (67h).

  15. Implementer l'INT 31h fonction 0000h (Allocate LDT Descriptors)
      pour allouer des selecteurs dans la LDT.

  16. Implementer l'INT 31h fonction 0001h (Free LDT Descriptor) pour
      liberer un selecteur precedemment alloue.

  17. Implementer l'INT 31h fonctions 0007h/0008h (Set/Get Segment
      Base Address) pour modifier et lire l'adresse de base d'un
      descripteur.

  18. Implementer l'INT 31h fonctions 0009h/000Ah (Set/Get Segment
      Limit et Set/Get Descriptor Access Rights) pour modifier la
      limite et les droits d'acces d'un descripteur.

  19. Implementer l'INT 31h fonction 0501h (Allocate Memory Block)
      pour allouer un bloc de memoire lineaire dans l'espace de
      16 Mo, retournant l'adresse lineaire et un handle.

  20. Implementer l'INT 31h fonction 0502h (Free Memory Block) et
      la fonction 0503h (Resize Memory Block) pour liberer et
      redimensionner un bloc memoire.

  21. Implementer l'INT 21h (services DOS) en mode protege DPMI :
      les appels DOS classiques ($02, $09, $3C-$40, $4Ch, ...) en
      traduisant les adresses selecteur:offset en adresses lineaires
      pour l'acces aux tampons.

  22. Implementer le chargeur de programme binaire plat (flat binary)
      qui charge un fichier executable dans la memoire lineaire,
      initialise les selecteurs CS/DS/ES/SS avec des descripteurs
      couvrant tout l'espace 16 Mo, et fixe EIP au point d'entree.

  23. Implementer la boucle principale d'execution (Procedure Run)
      avec decodage du flux d'instructions, gestion des prefixes
      (66h, 67h, segments, REP) et dispatch vers les procedures
      d'emulation de chaque opcode.

  24. Implementer les options de ligne de commande : /DEBUG pour le
      mode debogage avec affichage de l'etat des registres a chaque
      instruction, /VERBOSE pour les messages informatifs, et
      /READONLY pour interdire les ecritures sur disque.

  25. Implementer la procedure de nettoyage (Procedure Done) qui
      ferme et supprime le fichier d'echange de 16 Mo, et libere
      toutes les ressources (handles de fichiers ouverts).
}

Program EMUDPMI;

{$A-}

Uses DOS;

Const
  { TODO 1 : Fichier d'echange de 16 Mo pour la memoire lineaire }
 SwapFileMemory='EMUDPMI.$$$';

  { Taille totale de la memoire lineaire : 16 Mo }
 MemorySize=16*1024*1024;  { 16 777 216 octets }

  { Taille du tampon de nettoyage pour l'initialisation }
 ClearBufferSize=1024;

  { Nombre de blocs de 1 Ko pour couvrir 16 Mo }
 ClearBlockCount=MemorySize div ClearBufferSize;  { 16384 }

  { TODO 4 : Nombre d'entrees dans la LDT }
 LDTSize=256;

  { TODO 19 : Nombre maximum de blocs memoire allouables }
 MaxMemBlocks=128;

  { TODO 21 : Nombre maximum de fichiers DOS ouverts simultanement }
 MaxDosFiles=20;

  { TODO 22 : Adresse de base pour le chargement de programme binaire plat }
 FlatLoadBase=$100000;  { 1 Mo }

Type
  { TODO 2 : Registres 32 bits du 80386 }
 LongRec=Record
  Lo,Hi:Word;
 End;

  { TODO 4 : Descripteur de segment pour la LDT }
 TDescriptor=Record
  BaseAddr:LongInt;  { Adresse de base 32 bits }
  Limit:LongInt;     { Limite du segment (20 bits effectifs) }
  AccessType:Byte;   { Type d'acces (P, DPL, S, Type) }
  Granularity:Byte;  { Bit G (granularite 4 Ko), D/B, L, AVL }
  InUse:Boolean;     { Indique si le descripteur est alloue }
 End;

  { TODO 19 : Bloc memoire lineaire alloue via INT 31h fonction 0501h }
 TMemBlock=Record
  BaseAddr:LongInt;  { Adresse lineaire du bloc }
  Size:LongInt;      { Taille du bloc en octets }
  Handle:LongInt;    { Handle unique du bloc }
  InUse:Boolean;     { Indique si l'entree est utilisee }
 End;

  { TODO 21 : Fichier DOS ouvert en mode protege DPMI }
 TDosFile=Record
  F:File;            { Handle de fichier Pascal }
  InUse:Boolean;     { Indique si l'entree est utilisee }
 End;

Var
  { TODO 1 : Fichier d'echange }
 Memory:File;
 ClrBuffer:Array[0..ClearBufferSize-1]of Byte;

  { TODO 9 : Table de parite pour le drapeau PF }
 ParityTable:Array[0..255]of Boolean;

  { TODO 2 : Registres generaux 32 bits du 80386 avec acces aux
    sous-parties 16 bits (AX, BX, ...) et 8 bits (AL, AH, ...) }
 Regs:Record Case Byte of
  0:(EAX,ECX,EDX,EBX,ESP,EBP,ESI,EDI:LongInt);
  1:(AX,EAH,CX,ECH,DX,EDH,BX,EBH,SP,SPH,BP,BPH,SI,SIH,DI,DIH:Word);
  2:(AL,AH,HAL,HAH,CL,CH,HCL,HCH,DL,DH,HDL,HDH,BL,BH,HBL,HBH:Byte);
  3:(Abs:Array[0..7]of LongInt);
  4:(AbsWord:Array[0..7]of LongRec);
 End;

  { TODO 3 : Registres de segment en mode protege (selecteurs 16 bits) }
 Segs:Record Case Byte of
  0:(ES,CS,SS,DS,FS,GS:Word);
  1:(Abs:Array[0..5]of Word);
 End;

  { TODO 4 : Table des descripteurs locaux (LDT) }
 LDT:Array[0..LDTSize-1]of TDescriptor;

  { TODO 19 : Table des blocs memoire alloues }
 MemBlocks:Array[0..MaxMemBlocks-1]of TMemBlock;
 NextLinearAddr:LongInt;  { Prochaine adresse lineaire disponible }
 NextHandle:LongInt;      { Prochain handle a attribuer }

  { TODO 21 : Table des fichiers DOS ouverts et drapeau de terminaison }
 DosFiles:Array[0..MaxDosFiles-1]of TDosFile;
 DosExitCode:Byte;        { Code de retour du programme emule }
 Terminated:Boolean;       { True quand INT 21h/4Ch est appelee }

  { Pointeur d'instruction 32 bits }
 EIP:LongInt;

  { TODO 14 : Prefixes de remplacement de segment et de taille d'adresse.
    SegOverride contient le selecteur de segment courant pour l'acces
    memoire (ES, CS, SS, DS, FS, GS), ou -1 si aucun prefixe n'est actif.
    AddrSizeOverride vaut True quand le prefixe 67h a ete detecte,
    pour basculer du mode d'adressage 32 bits vers 16 bits. }
 SegOverride:LongInt;
 AddrSizeOverride:Boolean;

  { TODO 24 : Options de ligne de commande }
 DebugMode:Boolean;     { /DEBUG : affiche l'etat des registres a chaque instruction }
 VerboseMode:Boolean;   { /VERBOSE : affiche les messages informatifs }
 ReadOnlyMode:Boolean;  { /READONLY : interdit les ecritures sur disque }
 ProgramFile:String;    { Nom du fichier programme a charger }
 ParamIdx:Integer;      { Index de parcours des parametres }

  { Drapeaux du processeur }
 EFlags:Record Case Byte of
  0:(s:Set of(CF,bit1,PF,bit3,AF,bit5,ZF,SF,TF,_IF,DF,_OF));
  1:(Base:Word);
  2:(Abs:LongInt);
  3:(DataByte:Byte);
 End;

  { TODO 5 : Conversion d'adresse selecteur:offset en adresse lineaire
    32 bits. Le selecteur contient l'index LDT dans les bits 15..3
    (bits 1..0 = RPL, bit 2 = TI). L'adresse lineaire est calculee
    comme BaseAddr + Offset au lieu de Segment*16+Offset du mode reel. }
Function SelOfsToLinear(Sel:Word;Ofs:LongInt):LongInt;
Var
 Idx:Word;
Begin
 Idx:=Sel shr 3;
 If Idx>=LDTSize Then Begin
  WriteLn('Erreur: selecteur $',HexStr(Sel,4),' hors limites LDT');
  SelOfsToLinear:=0;
  Exit;
 End;
 If Not LDT[Idx].InUse Then Begin
  WriteLn('Erreur: selecteur $',HexStr(Sel,4),' non alloue');
  SelOfsToLinear:=0;
  Exit;
 End;
  { Verifier que l'offset est dans la limite du segment }
 If(LDT[Idx].Granularity and $80)<>0 Then Begin
   { Bit G=1 : limite en pages de 4 Ko }
  If Ofs>(LDT[Idx].Limit*4096+4095)Then Begin
   WriteLn('Erreur: offset $',HexStr(Ofs,8),' depasse la limite du segment');
   SelOfsToLinear:=0;
   Exit;
  End;
 End Else Begin
   { Bit G=0 : limite en octets }
  If Ofs>LDT[Idx].Limit Then Begin
   WriteLn('Erreur: offset $',HexStr(Ofs,8),' depasse la limite du segment');
   SelOfsToLinear:=0;
   Exit;
  End;
 End;
 SelOfsToLinear:=LDT[Idx].BaseAddr+Ofs;
End;

  { TODO 6 : Acces a la memoire lineaire 32 bits via le fichier de 16 Mo }

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

  { TODO 20 : Copie d'un bloc dans le fichier d'echange.
    Copie Count octets de l'adresse SrcAddr vers DestAddr dans le
    fichier de memoire lineaire, par blocs de ClearBufferSize octets. }
Procedure CopySwapBlock(SrcAddr,DestAddr,Count:LongInt);
Var
 Chunk:LongInt;
 ByteRead,ByteWrited:Word;
Begin
 While Count>0 do Begin
  Chunk:=Count;
  If Chunk>ClearBufferSize Then Chunk:=ClearBufferSize;
  Seek(Memory,SrcAddr);
  BlockRead(Memory,ClrBuffer,Chunk,ByteRead);
  Seek(Memory,DestAddr);
  BlockWrite(Memory,ClrBuffer,Chunk,ByteWrited);
  Inc(SrcAddr,Chunk);
  Inc(DestAddr,Chunk);
  Dec(Count,Chunk);
 End;
End;

  { TODO 7 : Pile 32 bits (PUSH/POP) avec ESP et SS adressant
    tout l'espace 16 Mo. PUSH decremente ESP puis ecrit la valeur,
    POP lit la valeur puis incremente ESP. }

Procedure Push32(Value:LongInt);
Var
 Addr:LongInt;
Begin
 Regs.ESP:=Regs.ESP-4;
 Addr:=SelOfsToLinear(Segs.SS,Regs.ESP);
 WriteDWord(Addr,Value);
End;

Function Pop32:LongInt;
Var
 Addr:LongInt;
Begin
 Addr:=SelOfsToLinear(Segs.SS,Regs.ESP);
 Pop32:=ReadDWord(Addr);
 Regs.ESP:=Regs.ESP+4;
End;

Procedure Push16(Value:Word);
Var
 Addr:LongInt;
Begin
 Regs.ESP:=Regs.ESP-2;
 Addr:=SelOfsToLinear(Segs.SS,Regs.ESP);
 WriteWord(Addr,Value);
End;

Function Pop16:Word;
Var
 Addr:LongInt;
Begin
 Addr:=SelOfsToLinear(Segs.SS,Regs.ESP);
 Pop16:=ReadWord(Addr);
 Regs.ESP:=Regs.ESP+2;
End;

  { TODO 8 : Instructions de transfert de donnees 32 bits
    MOV reg32,reg32 / MOV reg32,imm32 / MOV reg32,[mem] /
    MOV [mem],reg32 avec decodage du ModR/M en mode 32 bits. }

  { Lecture d'un octet a CS:EIP et avancement de EIP }
Function FetchByte:Byte;
Var
 Addr:LongInt;
Begin
 Addr:=SelOfsToLinear(Segs.CS,EIP);
 FetchByte:=ReadByte(Addr);
 Inc(EIP);
End;

  { Lecture d'un mot 16 bits a CS:EIP et avancement de EIP }
Function FetchWord:Word;
Var
 Addr:LongInt;
Begin
 Addr:=SelOfsToLinear(Segs.CS,EIP);
 FetchWord:=ReadWord(Addr);
 Inc(EIP,2);
End;

  { Lecture d'un double mot 32 bits a CS:EIP et avancement de EIP }
Function FetchDWord:LongInt;
Var
 Addr:LongInt;
Begin
 Addr:=SelOfsToLinear(Segs.CS,EIP);
 FetchDWord:=ReadDWord(Addr);
 Inc(EIP,4);
End;

  { Lecture d'un registre 32 bits par index (0=EAX..7=EDI) }
Function GetReg32(Idx:Byte):LongInt;
Begin
 GetReg32:=Regs.Abs[Idx and 7];
End;

  { Ecriture d'un registre 32 bits par index (0=EAX..7=EDI) }
Procedure SetReg32(Idx:Byte;Value:LongInt);
Begin
 Regs.Abs[Idx and 7]:=Value;
End;

  { Retourne le selecteur de segment effectif pour l'acces memoire.
    Si un prefixe de remplacement de segment est actif (SegOverride>=0),
    il est utilise. Sinon, le segment par defaut est utilise. }
Function GetEffectiveSeg(DefaultSeg:Word):Word;
Begin
 If SegOverride>=0 Then
  GetEffectiveSeg:=Word(SegOverride)
 Else
  GetEffectiveSeg:=DefaultSeg;
End;

  { Decodage du ModR/M en mode 32 bits. Retourne l'adresse effective
    lineaire si Mod<>11b, ou -1 si l'operande est un registre (Mod=11b).
    RegField recoit le champ reg (bits 5..3).
    RmField recoit le champ r/m (bits 2..0).
    Utilise SS par defaut si la base est EBP ou ESP, sinon DS. }
Function DecodeModRM32(Var RegField,RmField:Byte):LongInt;
Var
 ModRM,_Mod,SIB,Base,Index,Scale:Byte;
 Addr:LongInt;
 UseSS:Boolean;
Begin
 ModRM:=FetchByte;
 _Mod:=(ModRM shr 6) and 3;
 RegField:=(ModRM shr 3) and 7;
 RmField:=ModRM and 7;
 If _Mod=3 Then Begin
   { Operande registre, pas d'adresse memoire }
  DecodeModRM32:=-1;
  Exit;
 End;
  { Calcul de l'adresse effective }
 Addr:=0;
 UseSS:=False;
 If RmField=4 Then Begin
   { SIB byte present }
  SIB:=FetchByte;
  Base:=SIB and 7;
  Index:=(SIB shr 3) and 7;
  Scale:=(SIB shr 6) and 3;
   { Adresse de base }
  If(Base=5)and(_Mod=0)Then
   Addr:=FetchDWord  { [disp32+scaled index] }
  Else Begin
   Addr:=GetReg32(Base);
    { SS par defaut si base = EBP (5) ou ESP (4) }
   If(Base=4)or(Base=5)Then UseSS:=True;
  End;
   { Index echelonne (sauf si index=4 => pas d'index) }
  If Index<>4 Then
   Addr:=Addr+(GetReg32(Index) shl Scale);
 End Else If(RmField=5)and(_Mod=0)Then
  Addr:=FetchDWord  { [disp32] direct }
 Else Begin
  Addr:=GetReg32(RmField);
   { SS par defaut si r/m = EBP (5) }
  If RmField=5 Then UseSS:=True;
 End;
  { Deplacement }
 Case _Mod of
  1:Begin
    Addr:=Addr+ShortInt(FetchByte);  { disp8 signe }
     { Mod=01 avec r/m=5 => base EBP, utilise SS }
    If RmField=5 Then UseSS:=True;
   End;
  2:Begin
    Addr:=Addr+FetchDWord;            { disp32 }
    If RmField=5 Then UseSS:=True;
   End;
 End;
  { Conversion en adresse lineaire via le segment effectif }
 If UseSS Then
  DecodeModRM32:=SelOfsToLinear(GetEffectiveSeg(Segs.SS),Addr)
 Else
  DecodeModRM32:=SelOfsToLinear(GetEffectiveSeg(Segs.DS),Addr);
End;

  { TODO 14 : Decodage du ModR/M en mode d'adressage 16 bits
    (actif lorsque le prefixe 67h est detecte en mode protege 32 bits).
    Les modes d'adressage 16 bits utilisent BX, BP, SI, DI. }
Function DecodeModRM16(Var RegField,RmField:Byte):LongInt;
Var
 ModRM,_Mod:Byte;
 Addr:LongInt;
 UseSS:Boolean;
Begin
 ModRM:=FetchByte;
 _Mod:=(ModRM shr 6) and 3;
 RegField:=(ModRM shr 3) and 7;
 RmField:=ModRM and 7;
 If _Mod=3 Then Begin
  DecodeModRM16:=-1;
  Exit;
 End;
 Addr:=0;
 UseSS:=False;
 Case RmField of
  0:Addr:=LongInt(Regs.BX)+LongInt(Regs.SI);
  1:Addr:=LongInt(Regs.BX)+LongInt(Regs.DI);
  2:Begin Addr:=LongInt(Regs.BP)+LongInt(Regs.SI);UseSS:=True;End;
  3:Begin Addr:=LongInt(Regs.BP)+LongInt(Regs.DI);UseSS:=True;End;
  4:Addr:=LongInt(Regs.SI);
  5:Addr:=LongInt(Regs.DI);
  6:If _Mod=0 Then
    Addr:=LongInt(FetchWord)
   Else Begin
    Addr:=LongInt(Regs.BP);
    UseSS:=True;
   End;
  7:Addr:=LongInt(Regs.BX);
 End;
 Case _Mod of
  1:Begin
    Addr:=Addr+ShortInt(FetchByte);
    If(RmField=6)Then UseSS:=True;
   End;
  2:Begin
    Addr:=Addr+SmallInt(FetchWord);
    If(RmField=6)Then UseSS:=True;
   End;
 End;
 Addr:=Addr and $FFFF;
 If UseSS Then
  DecodeModRM16:=SelOfsToLinear(GetEffectiveSeg(Segs.SS),Addr)
 Else
  DecodeModRM16:=SelOfsToLinear(GetEffectiveSeg(Segs.DS),Addr);
End;

  { TODO 14 : Reinitialisation des prefixes apres chaque instruction }
Procedure ResetPrefixes;
Begin
 SegOverride:=-1;
 AddrSizeOverride:=False;
End;

  { MOV r/m32, reg32 - opcode $89 }
Procedure ExecMOV_Rm32_Reg32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RmField,GetReg32(RegField))
 Else
  WriteDWord(Addr,GetReg32(RegField));
End;

  { MOV reg32, r/m32 - opcode $8B }
Procedure ExecMOV_Reg32_Rm32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RegField,GetReg32(RmField))
 Else
  SetReg32(RegField,ReadDWord(Addr));
End;

  { MOV reg32, imm32 - opcodes $B8..$BF }
Procedure ExecMOV_Reg32_Imm32(RegIdx:Byte);
Begin
 SetReg32(RegIdx,FetchDWord);
End;

  { MOV r/m32, imm32 - opcode $C7 /0 }
Procedure ExecMOV_Rm32_Imm32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
 Imm:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 Imm:=FetchDWord;
 If Addr=-1 Then
  SetReg32(RmField,Imm)
 Else
  WriteDWord(Addr,Imm);
End;

  { TODO 9 : Instructions arithmetiques 32 bits : ADD, SUB, ADC,
    SBB, CMP, INC, DEC, NEG, MUL, IMUL, DIV, IDIV sur des
    operandes 32 bits avec mise a jour correcte des drapeaux
    (CF, ZF, SF, OF, AF, PF). }

  { Initialisation de la table de parite (PF) }
Procedure InitParityTable;
Var
 I,J,Cnt:Integer;
Begin
 For I:=0 to 255 do Begin
  Cnt:=0;
  For J:=0 to 7 do
   If(I shr J)and 1<>0 Then Inc(Cnt);
  ParityTable[I]:=(Cnt mod 2=0);
 End;
End;

  { Mise a jour du drapeau Zero (ZF) pour resultat 32 bits }
Procedure SetZFD(X:LongInt);
Begin
 If X=0 Then Include(EFlags.s,ZF)
        Else Exclude(EFlags.s,ZF);
End;

  { Mise a jour du drapeau Signe (SF) pour resultat 32 bits }
Procedure SetSFD(X:LongInt);
Begin
 If X<0 Then Include(EFlags.s,SF)
        Else Exclude(EFlags.s,SF);
End;

  { Mise a jour du drapeau Parite (PF) sur l'octet bas du resultat }
Procedure SetPFD(X:LongInt);
Begin
 If ParityTable[Byte(X)]Then Include(EFlags.s,PF)
                        Else Exclude(EFlags.s,PF);
End;

  { Comparaison non signee : A >= B en interpretant LongInt comme
    des valeurs non signees 32 bits }
Function UnsignedGeq32(A,B:LongInt):Boolean;
Begin
 If(A xor B)<0 Then
  UnsignedGeq32:=(A<0)
 Else
  UnsignedGeq32:=(A>=B);
End;

  { ADD 32 bits : Dest + Source avec mise a jour de tous les drapeaux }
Function ArithAdd32(Dest,Source:LongInt):LongInt;
Var
 R:LongInt;
Begin
 R:=Dest+Source;
  { CF : retenue sortante du bit 31 (addition non signee) }
 If((Dest<0)and(Source<0))or
   (((Dest<0)or(Source<0))and(R>=0))Then Include(EFlags.s,CF)
 Else Exclude(EFlags.s,CF);
  { OF : debordement signe }
 If((Dest xor R)<0)and((Source xor R)<0)Then Include(EFlags.s,_OF)
 Else Exclude(EFlags.s,_OF);
  { AF : retenue auxiliaire du bit 3 }
 If(Dest xor Source xor R)and $10<>0 Then Include(EFlags.s,AF)
 Else Exclude(EFlags.s,AF);
 SetZFD(R);
 SetSFD(R);
 SetPFD(R);
 ArithAdd32:=R;
End;

  { SUB 32 bits : Dest - Source avec mise a jour de tous les drapeaux }
Function ArithSub32(Dest,Source:LongInt):LongInt;
Var
 R:LongInt;
Begin
 R:=Dest-Source;
  { CF : emprunt (Dest < Source en non signe) }
 If(Dest xor Source)<0 Then Begin
  If Dest>=0 Then Include(EFlags.s,CF)
             Else Exclude(EFlags.s,CF);
 End Else Begin
  If Dest<Source Then Include(EFlags.s,CF)
                Else Exclude(EFlags.s,CF);
 End;
  { OF : debordement signe }
 If((Dest xor Source)<0)and((Dest xor R)<0)Then Include(EFlags.s,_OF)
 Else Exclude(EFlags.s,_OF);
  { AF : retenue auxiliaire du bit 3 }
 If(Dest xor Source xor R)and $10<>0 Then Include(EFlags.s,AF)
 Else Exclude(EFlags.s,AF);
 SetZFD(R);
 SetSFD(R);
 SetPFD(R);
 ArithSub32:=R;
End;

  { ADC 32 bits : Dest + Source + CF avec mise a jour de tous les drapeaux }
Function ArithAdc32(Dest,Source:LongInt):LongInt;
Var
 Tmp,R:LongInt;
 Carry1,Carry2:Boolean;
Begin
 Tmp:=Dest+Source;
  { Retenue de Dest + Source }
 Carry1:=((Dest<0)and(Source<0))or
         (((Dest<0)or(Source<0))and(Tmp>=0));
 If CF in EFlags.s Then Begin
  R:=Tmp+1;
   { Retenue supplementaire si Tmp = $FFFFFFFF }
  Carry2:=(Tmp=-1);
 End Else Begin
  R:=Tmp;
  Carry2:=False;
 End;
 If Carry1 or Carry2 Then Include(EFlags.s,CF)
 Else Exclude(EFlags.s,CF);
 If((Dest xor R)<0)and((Source xor R)<0)Then Include(EFlags.s,_OF)
 Else Exclude(EFlags.s,_OF);
 If(Dest xor Source xor R)and $10<>0 Then Include(EFlags.s,AF)
 Else Exclude(EFlags.s,AF);
 SetZFD(R);
 SetSFD(R);
 SetPFD(R);
 ArithAdc32:=R;
End;

  { SBB 32 bits : Dest - Source - CF avec mise a jour de tous les drapeaux }
Function ArithSbb32(Dest,Source:LongInt):LongInt;
Var
 Tmp,R:LongInt;
 Borrow1,Borrow2:Boolean;
Begin
 Tmp:=Dest-Source;
  { Emprunt de Dest - Source }
 If(Dest xor Source)<0 Then
  Borrow1:=(Dest>=0)
 Else
  Borrow1:=(Dest<Source);
 If CF in EFlags.s Then Begin
  R:=Tmp-1;
   { Emprunt supplementaire si Tmp = 0 }
  Borrow2:=(Tmp=0);
 End Else Begin
  R:=Tmp;
  Borrow2:=False;
 End;
 If Borrow1 or Borrow2 Then Include(EFlags.s,CF)
 Else Exclude(EFlags.s,CF);
 If((Dest xor Source)<0)and((Dest xor R)<0)Then Include(EFlags.s,_OF)
 Else Exclude(EFlags.s,_OF);
 If(Dest xor Source xor R)and $10<>0 Then Include(EFlags.s,AF)
 Else Exclude(EFlags.s,AF);
 SetZFD(R);
 SetSFD(R);
 SetPFD(R);
 ArithSbb32:=R;
End;

  { CMP 32 bits : comme SUB mais sans stocker le resultat }
Procedure ArithCmp32(Dest,Source:LongInt);
Var
 R:LongInt;
Begin
 R:=Dest-Source;
 If(Dest xor Source)<0 Then Begin
  If Dest>=0 Then Include(EFlags.s,CF)
             Else Exclude(EFlags.s,CF);
 End Else Begin
  If Dest<Source Then Include(EFlags.s,CF)
                Else Exclude(EFlags.s,CF);
 End;
 If((Dest xor Source)<0)and((Dest xor R)<0)Then Include(EFlags.s,_OF)
 Else Exclude(EFlags.s,_OF);
 If(Dest xor Source xor R)and $10<>0 Then Include(EFlags.s,AF)
 Else Exclude(EFlags.s,AF);
 SetZFD(R);
 SetSFD(R);
 SetPFD(R);
End;

  { INC 32 bits : Value + 1 (CF n'est pas modifie par INC) }
Function ArithInc32(Value:LongInt):LongInt;
Var
 R:LongInt;
Begin
 R:=Value+1;
  { OF : debordement si $7FFFFFFF + 1 = $80000000 }
 If R=LongInt($80000000)Then Include(EFlags.s,_OF)
 Else Exclude(EFlags.s,_OF);
  { AF }
 If(Value xor 1 xor R)and $10<>0 Then Include(EFlags.s,AF)
 Else Exclude(EFlags.s,AF);
 SetZFD(R);
 SetSFD(R);
 SetPFD(R);
 ArithInc32:=R;
End;

  { DEC 32 bits : Value - 1 (CF n'est pas modifie par DEC) }
Function ArithDec32(Value:LongInt):LongInt;
Var
 R:LongInt;
Begin
 R:=Value-1;
  { OF : debordement si $80000000 - 1 = $7FFFFFFF }
 If Value=LongInt($80000000)Then Include(EFlags.s,_OF)
 Else Exclude(EFlags.s,_OF);
  { AF }
 If(Value xor 1 xor R)and $10<>0 Then Include(EFlags.s,AF)
 Else Exclude(EFlags.s,AF);
 SetZFD(R);
 SetSFD(R);
 SetPFD(R);
 ArithDec32:=R;
End;

  { NEG 32 bits : 0 - Value (negation en complement a deux) }
Function ArithNeg32(Value:LongInt):LongInt;
Var
 R:LongInt;
Begin
 R:=-Value;
  { CF = 1 sauf si Value = 0 }
 If Value<>0 Then Include(EFlags.s,CF)
             Else Exclude(EFlags.s,CF);
  { OF = 1 si Value = $80000000 (le seul cas de debordement) }
 If Value=LongInt($80000000)Then Include(EFlags.s,_OF)
 Else Exclude(EFlags.s,_OF);
  { AF }
 If(Value xor R)and $10<>0 Then Include(EFlags.s,AF)
 Else Exclude(EFlags.s,AF);
 SetZFD(R);
 SetSFD(R);
 SetPFD(R);
 ArithNeg32:=R;
End;

  { MUL 32 bits non signe : EDX:EAX = EAX * Source (non signe) }
Procedure ArithMul32(Source:LongInt);
Var
 A,B,R:QWord;
Begin
 A:=QWord(Regs.EAX)and QWord($FFFFFFFF);
 B:=QWord(Source)and QWord($FFFFFFFF);
 R:=A*B;
 Regs.EAX:=LongInt(R and $FFFFFFFF);
 Regs.EDX:=LongInt((R shr 32)and $FFFFFFFF);
  { CF=OF=1 si la partie haute (EDX) est non nulle }
 If Regs.EDX<>0 Then Begin
  Include(EFlags.s,CF);
  Include(EFlags.s,_OF);
 End Else Begin
  Exclude(EFlags.s,CF);
  Exclude(EFlags.s,_OF);
 End;
 SetZFD(Regs.EAX);
 SetSFD(Regs.EAX);
 SetPFD(Regs.EAX);
End;

  { IMUL 32 bits signe : EDX:EAX = EAX * Source (signe) }
Procedure ArithIMul32(Source:LongInt);
Var
 R:Int64;
Begin
 R:=Int64(Regs.EAX)*Int64(Source);
 Regs.EAX:=LongInt(R and $FFFFFFFF);
 Regs.EDX:=LongInt((R shr 32)and $FFFFFFFF);
  { CF=OF=1 si le resultat 64 bits n'est pas le sign-extend du 32 bits }
 If(R>2147483647)or(R<-2147483648)Then Begin
  Include(EFlags.s,CF);
  Include(EFlags.s,_OF);
 End Else Begin
  Exclude(EFlags.s,CF);
  Exclude(EFlags.s,_OF);
 End;
 SetZFD(Regs.EAX);
 SetSFD(Regs.EAX);
 SetPFD(Regs.EAX);
End;

  { DIV 32 bits non signe : EAX = EDX:EAX div Source,
    EDX = EDX:EAX mod Source (non signe) }
Procedure ArithDiv32(Source:LongInt);
Var
 Dividend,Divisor,Quotient,Remainder:QWord;
Begin
 If Source=0 Then Begin
  WriteLn('Erreur: division par zero');
  Exit;
 End;
 Dividend:=(QWord(Regs.EDX)and QWord($FFFFFFFF))shl 32
           or(QWord(Regs.EAX)and QWord($FFFFFFFF));
 Divisor:=QWord(Source)and QWord($FFFFFFFF);
 Quotient:=Dividend div Divisor;
 Remainder:=Dividend mod Divisor;
 If Quotient>QWord($FFFFFFFF)Then Begin
  WriteLn('Erreur: debordement de quotient (DIV)');
  Exit;
 End;
 Regs.EAX:=LongInt(Quotient and $FFFFFFFF);
 Regs.EDX:=LongInt(Remainder and $FFFFFFFF);
End;

  { IDIV 32 bits signe : EAX = EDX:EAX div Source,
    EDX = EDX:EAX mod Source (signe) }
Procedure ArithIDiv32(Source:LongInt);
Var
 Dividend:Int64;
 Quotient,Remainder:Int64;
Begin
 If Source=0 Then Begin
  WriteLn('Erreur: division par zero');
  Exit;
 End;
 Dividend:=Int64(Regs.EDX)shl 32 or(Int64(Regs.EAX)and $FFFFFFFF);
 Quotient:=Dividend div Int64(Source);
 Remainder:=Dividend mod Int64(Source);
 If(Quotient>2147483647)or(Quotient<-2147483648)Then Begin
  WriteLn('Erreur: debordement de quotient (IDIV)');
  Exit;
 End;
 Regs.EAX:=LongInt(Quotient);
 Regs.EDX:=LongInt(Remainder);
End;

  { TODO 10 : Instructions logiques et de decalage 32 bits :
    AND, OR, XOR, NOT, TEST, SHL, SHR, SAR, ROL, ROR, RCL, RCR
    sur des operandes 32 bits. }

  { AND 32 bits : CF=OF=0, AF indefini, ZF/SF/PF mis a jour }
Function LogicAnd32(Dest,Source:LongInt):LongInt;
Var
 R:LongInt;
Begin
 R:=Dest and Source;
 Exclude(EFlags.s,CF);
 Exclude(EFlags.s,_OF);
 SetZFD(R);
 SetSFD(R);
 SetPFD(R);
 LogicAnd32:=R;
End;

  { OR 32 bits : CF=OF=0, AF indefini, ZF/SF/PF mis a jour }
Function LogicOr32(Dest,Source:LongInt):LongInt;
Var
 R:LongInt;
Begin
 R:=Dest or Source;
 Exclude(EFlags.s,CF);
 Exclude(EFlags.s,_OF);
 SetZFD(R);
 SetSFD(R);
 SetPFD(R);
 LogicOr32:=R;
End;

  { XOR 32 bits : CF=OF=0, AF indefini, ZF/SF/PF mis a jour }
Function LogicXor32(Dest,Source:LongInt):LongInt;
Var
 R:LongInt;
Begin
 R:=Dest xor Source;
 Exclude(EFlags.s,CF);
 Exclude(EFlags.s,_OF);
 SetZFD(R);
 SetSFD(R);
 SetPFD(R);
 LogicXor32:=R;
End;

  { NOT 32 bits : pas de modification des drapeaux }
Function LogicNot32(Value:LongInt):LongInt;
Begin
 LogicNot32:=not Value;
End;

  { TEST 32 bits : identique a AND mais sans stocker le resultat }
Procedure LogicTest32(Dest,Source:LongInt);
Var
 R:LongInt;
Begin
 R:=Dest and Source;
 Exclude(EFlags.s,CF);
 Exclude(EFlags.s,_OF);
 SetZFD(R);
 SetSFD(R);
 SetPFD(R);
End;

  { SHL/SAL 32 bits : decalage a gauche, CF=dernier bit sorti }
Function ShiftShl32(Value:LongInt;Count:Byte):LongInt;
Var
 R:LongInt;
Begin
 Count:=Count and $1F;
 If Count=0 Then Begin ShiftShl32:=Value;Exit;End;
  { CF = bit (32-Count) de la valeur originale, extraction non signee }
 If(LongInt((QWord(Value)and $FFFFFFFF)shr(32-Count)))and 1<>0 Then Include(EFlags.s,CF)
 Else Exclude(EFlags.s,CF);
 R:=Value shl Count;
 If Count=1 Then Begin
   { OF = MSB du resultat XOR CF }
  If(R<0)xor(CF in EFlags.s)Then Include(EFlags.s,_OF)
  Else Exclude(EFlags.s,_OF);
 End;
 SetZFD(R);
 SetSFD(R);
 SetPFD(R);
 ShiftShl32:=R;
End;

  { SHR 32 bits : decalage logique a droite, CF=dernier bit sorti }
Function ShiftShr32(Value:LongInt;Count:Byte):LongInt;
Var
 V:LongInt;
 R:LongInt;
Begin
 Count:=Count and $1F;
 If Count=0 Then Begin ShiftShr32:=Value;Exit;End;
 V:=Value;
  { CF = bit (Count-1) de la valeur originale }
 If(V shr(Count-1))and 1<>0 Then Include(EFlags.s,CF)
 Else Exclude(EFlags.s,CF);
  { Decalage logique (non signe) }
 R:=LongInt((LongInt(V)shr Count)and(LongInt($FFFFFFFF)shr Count));
  { Pour un decalage logique : forcer les bits hauts a 0 }
 If Count<32 Then
  R:=LongInt((QWord(V)and QWord($FFFFFFFF))shr Count)
 Else
  R:=0;
 If Count=1 Then Begin
   { OF = MSB de la valeur originale }
  If V<0 Then Include(EFlags.s,_OF)
  Else Exclude(EFlags.s,_OF);
 End;
 SetZFD(R);
 SetSFD(R);
 SetPFD(R);
 ShiftShr32:=R;
End;

  { SAR 32 bits : decalage arithmetique a droite (sign-extend),
    CF=dernier bit sorti }
Function ShiftSar32(Value:LongInt;Count:Byte):LongInt;
Var
 R:LongInt;
Begin
 Count:=Count and $1F;
 If Count=0 Then Begin ShiftSar32:=Value;Exit;End;
  { CF = bit (Count-1) }
 If(Value shr(Count-1))and 1<>0 Then Include(EFlags.s,CF)
 Else Exclude(EFlags.s,CF);
  { Le SAR en Pascal/FPC sur LongInt est arithmetique (signe propage) }
 R:=SarLongInt(Value,Count);
 If Count=1 Then
  Exclude(EFlags.s,_OF); { OF=0 pour SAR avec count=1 }
 SetZFD(R);
 SetSFD(R);
 SetPFD(R);
 ShiftSar32:=R;
End;

  { ROL 32 bits : rotation a gauche, CF=bit 0 du resultat }
Function ShiftRol32(Value:LongInt;Count:Byte):LongInt;
Var
 R:LongInt;
 C:Byte;
Begin
 C:=Count and $1F;
 If C=0 Then Begin ShiftRol32:=Value;Exit;End;
 R:=LongInt(
  (QWord(Value)and $FFFFFFFF)shl C or
  ((QWord(Value)and $FFFFFFFF)shr(32-C))
 );
  { CF = bit 0 du resultat }
 If R and 1<>0 Then Include(EFlags.s,CF)
 Else Exclude(EFlags.s,CF);
 If Count=1 Then Begin
   { OF = MSB xor CF }
  If(R<0)xor(CF in EFlags.s)Then Include(EFlags.s,_OF)
  Else Exclude(EFlags.s,_OF);
 End;
 ShiftRol32:=R;
End;

  { ROR 32 bits : rotation a droite, CF=MSB du resultat }
Function ShiftRor32(Value:LongInt;Count:Byte):LongInt;
Var
 R:LongInt;
 C:Byte;
Begin
 C:=Count and $1F;
 If C=0 Then Begin ShiftRor32:=Value;Exit;End;
 R:=LongInt(
  ((QWord(Value)and $FFFFFFFF)shr C)or
  ((QWord(Value)and $FFFFFFFF)shl(32-C))
 );
  { CF = MSB du resultat (bit 31) }
 If R<0 Then Include(EFlags.s,CF)
 Else Exclude(EFlags.s,CF);
 If Count=1 Then Begin
   { OF = MSB xor bit 30 du resultat }
  If((R shr 31)xor(R shr 30))and 1<>0 Then Include(EFlags.s,_OF)
  Else Exclude(EFlags.s,_OF);
 End;
 ShiftRor32:=R;
End;

  { RCL 32 bits : rotation a gauche a travers CF (33 bits) }
Function ShiftRcl32(Value:LongInt;Count:Byte):LongInt;
Var
 I:Integer;
 TmpCF:Boolean;
 V:LongInt;
Begin
 Count:=Count mod 33;
 V:=Value;
 For I:=1 to Count do Begin
  TmpCF:=(V<0); { bit 31 }
  V:=LongInt((QWord(V)and $FFFFFFFF)shl 1);
  If CF in EFlags.s Then V:=V or 1;
  If TmpCF Then Include(EFlags.s,CF) Else Exclude(EFlags.s,CF);
 End;
 If Count=1 Then Begin
  If(V<0)xor(CF in EFlags.s)Then Include(EFlags.s,_OF)
  Else Exclude(EFlags.s,_OF);
 End;
 ShiftRcl32:=V;
End;

  { RCR 32 bits : rotation a droite a travers CF (33 bits) }
Function ShiftRcr32(Value:LongInt;Count:Byte):LongInt;
Var
 I:Integer;
 TmpCF:Boolean;
 V:LongInt;
Begin
 Count:=Count mod 33;
 V:=Value;
 If Count=1 Then Begin
   { OF = MSB xor CF avant la rotation }
  If(V<0)xor(CF in EFlags.s)Then Include(EFlags.s,_OF)
  Else Exclude(EFlags.s,_OF);
 End;
 For I:=1 to Count do Begin
  TmpCF:=(V and 1<>0); { bit 0 }
  V:=LongInt((QWord(V)and $FFFFFFFF)shr 1);
  If CF in EFlags.s Then V:=V or LongInt($80000000);
  If TmpCF Then Include(EFlags.s,CF) Else Exclude(EFlags.s,CF);
 End;
 ShiftRcr32:=V;
End;

  { --- Procedures Exec pour les opcodes arithmetiques 32 bits --- }

  { ADD r/m32, reg32 - opcode $01 }
Procedure ExecADD_Rm32_Reg32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RmField,ArithAdd32(GetReg32(RmField),GetReg32(RegField)))
 Else
  WriteDWord(Addr,ArithAdd32(ReadDWord(Addr),GetReg32(RegField)));
End;

  { ADD reg32, r/m32 - opcode $03 }
Procedure ExecADD_Reg32_Rm32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RegField,ArithAdd32(GetReg32(RegField),GetReg32(RmField)))
 Else
  SetReg32(RegField,ArithAdd32(GetReg32(RegField),ReadDWord(Addr)));
End;

  { ADD EAX, imm32 - opcode $05 }
Procedure ExecADD_EAX_Imm32;
Begin
 Regs.EAX:=ArithAdd32(Regs.EAX,FetchDWord);
End;

  { ADC r/m32, reg32 - opcode $11 }
Procedure ExecADC_Rm32_Reg32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RmField,ArithAdc32(GetReg32(RmField),GetReg32(RegField)))
 Else
  WriteDWord(Addr,ArithAdc32(ReadDWord(Addr),GetReg32(RegField)));
End;

  { ADC reg32, r/m32 - opcode $13 }
Procedure ExecADC_Reg32_Rm32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RegField,ArithAdc32(GetReg32(RegField),GetReg32(RmField)))
 Else
  SetReg32(RegField,ArithAdc32(GetReg32(RegField),ReadDWord(Addr)));
End;

  { ADC EAX, imm32 - opcode $15 }
Procedure ExecADC_EAX_Imm32;
Begin
 Regs.EAX:=ArithAdc32(Regs.EAX,FetchDWord);
End;

  { SBB r/m32, reg32 - opcode $19 }
Procedure ExecSBB_Rm32_Reg32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RmField,ArithSbb32(GetReg32(RmField),GetReg32(RegField)))
 Else
  WriteDWord(Addr,ArithSbb32(ReadDWord(Addr),GetReg32(RegField)));
End;

  { SBB reg32, r/m32 - opcode $1B }
Procedure ExecSBB_Reg32_Rm32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RegField,ArithSbb32(GetReg32(RegField),GetReg32(RmField)))
 Else
  SetReg32(RegField,ArithSbb32(GetReg32(RegField),ReadDWord(Addr)));
End;

  { SBB EAX, imm32 - opcode $1D }
Procedure ExecSBB_EAX_Imm32;
Begin
 Regs.EAX:=ArithSbb32(Regs.EAX,FetchDWord);
End;

  { SUB r/m32, reg32 - opcode $29 }
Procedure ExecSUB_Rm32_Reg32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RmField,ArithSub32(GetReg32(RmField),GetReg32(RegField)))
 Else
  WriteDWord(Addr,ArithSub32(ReadDWord(Addr),GetReg32(RegField)));
End;

  { SUB reg32, r/m32 - opcode $2B }
Procedure ExecSUB_Reg32_Rm32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RegField,ArithSub32(GetReg32(RegField),GetReg32(RmField)))
 Else
  SetReg32(RegField,ArithSub32(GetReg32(RegField),ReadDWord(Addr)));
End;

  { SUB EAX, imm32 - opcode $2D }
Procedure ExecSUB_EAX_Imm32;
Begin
 Regs.EAX:=ArithSub32(Regs.EAX,FetchDWord);
End;

  { CMP r/m32, reg32 - opcode $39 }
Procedure ExecCMP_Rm32_Reg32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  ArithCmp32(GetReg32(RmField),GetReg32(RegField))
 Else
  ArithCmp32(ReadDWord(Addr),GetReg32(RegField));
End;

  { CMP reg32, r/m32 - opcode $3B }
Procedure ExecCMP_Reg32_Rm32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  ArithCmp32(GetReg32(RegField),GetReg32(RmField))
 Else
  ArithCmp32(GetReg32(RegField),ReadDWord(Addr));
End;

  { CMP EAX, imm32 - opcode $3D }
Procedure ExecCMP_EAX_Imm32;
Begin
 ArithCmp32(Regs.EAX,FetchDWord);
End;

  { INC reg32 - opcodes $40..$47 }
Procedure ExecINC_Reg32(RegIdx:Byte);
Begin
 SetReg32(RegIdx,ArithInc32(GetReg32(RegIdx)));
End;

  { DEC reg32 - opcodes $48..$4F }
Procedure ExecDEC_Reg32(RegIdx:Byte);
Begin
 SetReg32(RegIdx,ArithDec32(GetReg32(RegIdx)));
End;

  { --- Procedures Exec pour les opcodes logiques 32 bits (TODO 10) --- }

  { OR r/m32, reg32 - opcode $09 }
Procedure ExecOR_Rm32_Reg32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RmField,LogicOr32(GetReg32(RmField),GetReg32(RegField)))
 Else
  WriteDWord(Addr,LogicOr32(ReadDWord(Addr),GetReg32(RegField)));
End;

  { OR reg32, r/m32 - opcode $0B }
Procedure ExecOR_Reg32_Rm32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RegField,LogicOr32(GetReg32(RegField),GetReg32(RmField)))
 Else
  SetReg32(RegField,LogicOr32(GetReg32(RegField),ReadDWord(Addr)));
End;

  { OR EAX, imm32 - opcode $0D }
Procedure ExecOR_EAX_Imm32;
Begin
 Regs.EAX:=LogicOr32(Regs.EAX,FetchDWord);
End;

  { AND r/m32, reg32 - opcode $21 }
Procedure ExecAND_Rm32_Reg32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RmField,LogicAnd32(GetReg32(RmField),GetReg32(RegField)))
 Else
  WriteDWord(Addr,LogicAnd32(ReadDWord(Addr),GetReg32(RegField)));
End;

  { AND reg32, r/m32 - opcode $23 }
Procedure ExecAND_Reg32_Rm32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RegField,LogicAnd32(GetReg32(RegField),GetReg32(RmField)))
 Else
  SetReg32(RegField,LogicAnd32(GetReg32(RegField),ReadDWord(Addr)));
End;

  { AND EAX, imm32 - opcode $25 }
Procedure ExecAND_EAX_Imm32;
Begin
 Regs.EAX:=LogicAnd32(Regs.EAX,FetchDWord);
End;

  { XOR r/m32, reg32 - opcode $31 }
Procedure ExecXOR_Rm32_Reg32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RmField,LogicXor32(GetReg32(RmField),GetReg32(RegField)))
 Else
  WriteDWord(Addr,LogicXor32(ReadDWord(Addr),GetReg32(RegField)));
End;

  { XOR reg32, r/m32 - opcode $33 }
Procedure ExecXOR_Reg32_Rm32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RegField,LogicXor32(GetReg32(RegField),GetReg32(RmField)))
 Else
  SetReg32(RegField,LogicXor32(GetReg32(RegField),ReadDWord(Addr)));
End;

  { XOR EAX, imm32 - opcode $35 }
Procedure ExecXOR_EAX_Imm32;
Begin
 Regs.EAX:=LogicXor32(Regs.EAX,FetchDWord);
End;

  { TEST r/m32, reg32 - opcode $85 }
Procedure ExecTEST_Rm32_Reg32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  LogicTest32(GetReg32(RmField),GetReg32(RegField))
 Else
  LogicTest32(ReadDWord(Addr),GetReg32(RegField));
End;

  { TEST EAX, imm32 - opcode $A9 }
Procedure ExecTEST_EAX_Imm32;
Begin
 LogicTest32(Regs.EAX,FetchDWord);
End;

  { --- Procedures Exec pour les decalages et rotations (TODO 10) --- }

  { Groupe 2 : r/m32, imm8 - opcode $C1
    Le champ reg du ModR/M determine l'operation :
    /0=ROL, /1=ROR, /2=RCL, /3=RCR, /4=SHL, /5=SHR, /7=SAR }
Procedure ExecGrp2_Rm32_Imm8;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
 Val:LongInt;
 Cnt:Byte;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 Cnt:=FetchByte;
 If Addr=-1 Then Val:=GetReg32(RmField)
            Else Val:=ReadDWord(Addr);
 Case RegField of
  0:Val:=ShiftRol32(Val,Cnt);
  1:Val:=ShiftRor32(Val,Cnt);
  2:Val:=ShiftRcl32(Val,Cnt);
  3:Val:=ShiftRcr32(Val,Cnt);
  4:Val:=ShiftShl32(Val,Cnt);
  5:Val:=ShiftShr32(Val,Cnt);
  7:Val:=ShiftSar32(Val,Cnt);
 Else Begin
  WriteLn('Erreur: Grp2/$C1 reg=',RegField,' non implemente');
  Exit;
 End;
 End;
 If Addr=-1 Then SetReg32(RmField,Val)
            Else WriteDWord(Addr,Val);
End;

  { Groupe 2 : r/m32, 1 - opcode $D1
    Decalage/rotation de 1 position }
Procedure ExecGrp2_Rm32_1;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
 Val:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then Val:=GetReg32(RmField)
            Else Val:=ReadDWord(Addr);
 Case RegField of
  0:Val:=ShiftRol32(Val,1);
  1:Val:=ShiftRor32(Val,1);
  2:Val:=ShiftRcl32(Val,1);
  3:Val:=ShiftRcr32(Val,1);
  4:Val:=ShiftShl32(Val,1);
  5:Val:=ShiftShr32(Val,1);
  7:Val:=ShiftSar32(Val,1);
 Else Begin
  WriteLn('Erreur: Grp2/$D1 reg=',RegField,' non implemente');
  Exit;
 End;
 End;
 If Addr=-1 Then SetReg32(RmField,Val)
            Else WriteDWord(Addr,Val);
End;

  { Groupe 2 : r/m32, CL - opcode $D3
    Decalage/rotation de CL positions }
Procedure ExecGrp2_Rm32_CL;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
 Val:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then Val:=GetReg32(RmField)
            Else Val:=ReadDWord(Addr);
 Case RegField of
  0:Val:=ShiftRol32(Val,Regs.CL);
  1:Val:=ShiftRor32(Val,Regs.CL);
  2:Val:=ShiftRcl32(Val,Regs.CL);
  3:Val:=ShiftRcr32(Val,Regs.CL);
  4:Val:=ShiftShl32(Val,Regs.CL);
  5:Val:=ShiftShr32(Val,Regs.CL);
  7:Val:=ShiftSar32(Val,Regs.CL);
 Else Begin
  WriteLn('Erreur: Grp2/$D3 reg=',RegField,' non implemente');
  Exit;
 End;
 End;
 If Addr=-1 Then SetReg32(RmField,Val)
            Else WriteDWord(Addr,Val);
End;

  { Groupe 1 : r/m32, imm32 - opcode $81
    Le champ reg du ModR/M determine l'operation :
    /0=ADD, /1=OR, /2=ADC, /3=SBB,
    /4=AND, /5=SUB, /6=XOR, /7=CMP }
Procedure ExecGrp1_Rm32_Imm32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
 Imm,Val:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 Imm:=FetchDWord;
 If Addr=-1 Then Val:=GetReg32(RmField)
            Else Val:=ReadDWord(Addr);
 Case RegField of
  0:Val:=ArithAdd32(Val,Imm);
  1:Val:=LogicOr32(Val,Imm);
  2:Val:=ArithAdc32(Val,Imm);
  3:Val:=ArithSbb32(Val,Imm);
  4:Val:=LogicAnd32(Val,Imm);
  5:Val:=ArithSub32(Val,Imm);
  6:Val:=LogicXor32(Val,Imm);
  7:Begin ArithCmp32(Val,Imm);Exit;End;
 End;
 If Addr=-1 Then SetReg32(RmField,Val)
            Else WriteDWord(Addr,Val);
End;

  { Groupe 1 : r/m32, imm8 signe-etendu - opcode $83
    Meme schema que $81 mais avec un immediat 8 bits sign-extend }
Procedure ExecGrp1_Rm32_Imm8;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
 Imm,Val:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 Imm:=LongInt(ShortInt(FetchByte));
 If Addr=-1 Then Val:=GetReg32(RmField)
            Else Val:=ReadDWord(Addr);
 Case RegField of
  0:Val:=ArithAdd32(Val,Imm);
  1:Val:=LogicOr32(Val,Imm);
  2:Val:=ArithAdc32(Val,Imm);
  3:Val:=ArithSbb32(Val,Imm);
  4:Val:=LogicAnd32(Val,Imm);
  5:Val:=ArithSub32(Val,Imm);
  6:Val:=LogicXor32(Val,Imm);
  7:Begin ArithCmp32(Val,Imm);Exit;End;
 End;
 If Addr=-1 Then SetReg32(RmField,Val)
            Else WriteDWord(Addr,Val);
End;

  { Groupe 3 : r/m32 - opcode $F7
    Le champ reg du ModR/M determine l'operation :
    /0=TEST, /1=TEST, /2=NOT, /3=NEG,
    /4=MUL, /5=IMUL, /6=DIV, /7=IDIV }
Procedure ExecGrp3_Rm32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
 Val:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then Val:=GetReg32(RmField)
            Else Val:=ReadDWord(Addr);
 Case RegField of
  0,1:LogicTest32(Val,FetchDWord);
  2:Begin
    Val:=LogicNot32(Val);
    If Addr=-1 Then SetReg32(RmField,Val)
               Else WriteDWord(Addr,Val);
   End;
  3:Begin
    Val:=ArithNeg32(Val);
    If Addr=-1 Then SetReg32(RmField,Val)
               Else WriteDWord(Addr,Val);
   End;
  4:ArithMul32(Val);
  5:ArithIMul32(Val);
  6:ArithDiv32(Val);
  7:ArithIDiv32(Val);
 End;
End;

  { TODO 11 : Instructions de chaines 32 bits : MOVSD, STOSD,
    LODSD, CMPSD, SCASD avec le prefixe REP/REPE/REPNE
    utilisant ECX comme compteur.
    DF (Direction Flag) determine le sens : si DF=0, ESI/EDI sont
    incrementes de 4 ; si DF=1, ils sont decrementes de 4. }

  { Calcul du pas de direction pour les instructions de chaine 32 bits }
Function StringStep32:LongInt;
Begin
 If DF in EFlags.s Then StringStep32:=-4
                   Else StringStep32:=4;
End;

  { MOVSD : Copie un DWord de DS:ESI vers ES:EDI, ajuste ESI et EDI }
Procedure ExecMOVSD;
Var
 SrcAddr,DstAddr:LongInt;
 Val:LongInt;
Begin
 SrcAddr:=SelOfsToLinear(Segs.DS,Regs.ESI);
 DstAddr:=SelOfsToLinear(Segs.ES,Regs.EDI);
 Val:=ReadDWord(SrcAddr);
 WriteDWord(DstAddr,Val);
 Regs.ESI:=Regs.ESI+StringStep32;
 Regs.EDI:=Regs.EDI+StringStep32;
End;

  { STOSD : Ecrit EAX dans ES:EDI, ajuste EDI }
Procedure ExecSTOSD;
Var
 DstAddr:LongInt;
Begin
 DstAddr:=SelOfsToLinear(Segs.ES,Regs.EDI);
 WriteDWord(DstAddr,Regs.EAX);
 Regs.EDI:=Regs.EDI+StringStep32;
End;

  { LODSD : Charge un DWord de DS:ESI dans EAX, ajuste ESI }
Procedure ExecLODSD;
Var
 SrcAddr:LongInt;
Begin
 SrcAddr:=SelOfsToLinear(Segs.DS,Regs.ESI);
 Regs.EAX:=ReadDWord(SrcAddr);
 Regs.ESI:=Regs.ESI+StringStep32;
End;

  { CMPSD : Compare le DWord a DS:ESI avec le DWord a ES:EDI
    (comme SUB sans stockage du resultat), ajuste ESI et EDI }
Procedure ExecCMPSD;
Var
 SrcAddr,DstAddr:LongInt;
 SrcVal,DstVal:LongInt;
Begin
 SrcAddr:=SelOfsToLinear(Segs.DS,Regs.ESI);
 DstAddr:=SelOfsToLinear(Segs.ES,Regs.EDI);
 SrcVal:=ReadDWord(SrcAddr);
 DstVal:=ReadDWord(DstAddr);
 ArithCmp32(SrcVal,DstVal);
 Regs.ESI:=Regs.ESI+StringStep32;
 Regs.EDI:=Regs.EDI+StringStep32;
End;

  { SCASD : Compare EAX avec le DWord a ES:EDI
    (comme CMP EAX,[ES:EDI] sans stockage), ajuste EDI }
Procedure ExecSCASD;
Var
 DstAddr:LongInt;
 DstVal:LongInt;
Begin
 DstAddr:=SelOfsToLinear(Segs.ES,Regs.EDI);
 DstVal:=ReadDWord(DstAddr);
 ArithCmp32(Regs.EAX,DstVal);
 Regs.EDI:=Regs.EDI+StringStep32;
End;

  { --- Prefixes REP / REPE / REPNE pour les instructions de chaine --- }

  { REP MOVSD : Repete MOVSD ECX fois }
Procedure ExecREP_MOVSD;
Begin
 While Regs.ECX<>0 do Begin
  ExecMOVSD;
  Dec(Regs.ECX);
 End;
End;

  { REP STOSD : Repete STOSD ECX fois }
Procedure ExecREP_STOSD;
Begin
 While Regs.ECX<>0 do Begin
  ExecSTOSD;
  Dec(Regs.ECX);
 End;
End;

  { REP LODSD : Repete LODSD ECX fois (EAX contient le dernier DWord lu) }
Procedure ExecREP_LODSD;
Begin
 While Regs.ECX<>0 do Begin
  ExecLODSD;
  Dec(Regs.ECX);
 End;
End;

  { REPE/REPZ CMPSD : Repete CMPSD tant que ECX<>0 et ZF=1 }
Procedure ExecREPE_CMPSD;
Begin
 While Regs.ECX<>0 do Begin
  ExecCMPSD;
  Dec(Regs.ECX);
  If Not(ZF in EFlags.s)Then Exit;
 End;
End;

  { REPNE/REPNZ CMPSD : Repete CMPSD tant que ECX<>0 et ZF=0 }
Procedure ExecREPNE_CMPSD;
Begin
 While Regs.ECX<>0 do Begin
  ExecCMPSD;
  Dec(Regs.ECX);
  If ZF in EFlags.s Then Exit;
 End;
End;

  { REPE/REPZ SCASD : Repete SCASD tant que ECX<>0 et ZF=1 }
Procedure ExecREPE_SCASD;
Begin
 While Regs.ECX<>0 do Begin
  ExecSCASD;
  Dec(Regs.ECX);
  If Not(ZF in EFlags.s)Then Exit;
 End;
End;

  { REPNE/REPNZ SCASD : Repete SCASD tant que ECX<>0 et ZF=0 }
Procedure ExecREPNE_SCASD;
Begin
 While Regs.ECX<>0 do Begin
  ExecSCASD;
  Dec(Regs.ECX);
  If ZF in EFlags.s Then Exit;
 End;
End;

  { TODO 12 : Instructions de saut conditionnel 32 bits (Jcc near
    avec deplacement 32 bits, prefixe 0Fh) et sauts inconditionnels
    JMP near/far en mode protege.
    Les 16 conditions x86 sont testees via TestCondition(cc):
      0=O, 1=NO, 2=B/C, 3=NB/NC, 4=E/Z, 5=NE/NZ, 6=BE/NA,
      7=A/NBE, 8=S, 9=NS, A=P/PE, B=NP/PO, C=L/NGE, D=GE/NL,
      E=LE/NG, F=G/NLE. }

  { Teste une condition x86 (cc = 0..15) selon les drapeaux }
Function TestCondition(cc:Byte):Boolean;
Var
 R:Boolean;
Begin
 R:=False;
 Case cc and $0F of
  $0:R:=(_OF in EFlags.s);                    { JO : OF=1 }
  $1:R:=Not(_OF in EFlags.s);                 { JNO : OF=0 }
  $2:R:=(CF in EFlags.s);                     { JB/JC/JNAE : CF=1 }
  $3:R:=Not(CF in EFlags.s);                  { JNB/JNC/JAE : CF=0 }
  $4:R:=(ZF in EFlags.s);                     { JE/JZ : ZF=1 }
  $5:R:=Not(ZF in EFlags.s);                  { JNE/JNZ : ZF=0 }
  $6:R:=(CF in EFlags.s)or(ZF in EFlags.s);   { JBE/JNA : CF=1 ou ZF=1 }
  $7:R:=Not(CF in EFlags.s)and Not(ZF in EFlags.s); { JA/JNBE : CF=0 et ZF=0 }
  $8:R:=(SF in EFlags.s);                     { JS : SF=1 }
  $9:R:=Not(SF in EFlags.s);                  { JNS : SF=0 }
  $A:R:=(PF in EFlags.s);                     { JP/JPE : PF=1 }
  $B:R:=Not(PF in EFlags.s);                  { JNP/JPO : PF=0 }
  $C:R:=(SF in EFlags.s)<>(_OF in EFlags.s);  { JL/JNGE : SF<>OF }
  $D:R:=(SF in EFlags.s)=(_OF in EFlags.s);   { JGE/JNL : SF=OF }
  $E:R:=((SF in EFlags.s)<>(_OF in EFlags.s))or(ZF in EFlags.s); { JLE/JNG : SF<>OF ou ZF=1 }
  $F:R:=((SF in EFlags.s)=(_OF in EFlags.s))and Not(ZF in EFlags.s); { JG/JNLE : SF=OF et ZF=0 }
 End;
 TestCondition:=R;
End;

  { Jcc short (rel8) - opcodes $70..$7F : saut conditionnel court }
Procedure ExecJcc_Short(cc:Byte);
Var
 Rel:ShortInt;
Begin
 Rel:=ShortInt(FetchByte);
 If TestCondition(cc)Then
  EIP:=EIP+Rel;
End;

  { Jcc near (rel32) - opcodes $0F $80..$0F $8F : saut conditionnel
    near avec deplacement 32 bits }
Procedure ExecJcc_Near32(cc:Byte);
Var
 Rel:LongInt;
Begin
 Rel:=FetchDWord;
 If TestCondition(cc)Then
  EIP:=EIP+Rel;
End;

  { JMP short (rel8) - opcode $EB : saut inconditionnel court }
Procedure ExecJMP_Short;
Var
 Rel:ShortInt;
Begin
 Rel:=ShortInt(FetchByte);
 EIP:=EIP+Rel;
End;

  { JMP near (rel32) - opcode $E9 : saut inconditionnel near 32 bits }
Procedure ExecJMP_Near32;
Var
 Rel:LongInt;
Begin
 Rel:=FetchDWord;
 EIP:=EIP+Rel;
End;

  { JMP far (ptr16:32) - opcode $EA : saut inconditionnel far
    en mode protege (charge un nouveau CS et EIP) }
Procedure ExecJMP_Far;
Var
 NewEIP:LongInt;
 NewCS:Word;
Begin
 NewEIP:=FetchDWord;
 NewCS:=FetchWord;
 EIP:=NewEIP;
 Segs.CS:=NewCS;
End;

  { JMP r/m32 - opcode $FF /4 : saut indirect near via registre ou memoire
    JMP m16:32 - opcode $FF /5 : saut indirect far via memoire }
Procedure ExecGrp5_JMP;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 Case RegField of
  4:Begin { JMP r/m32 - near indirect }
     If Addr=-1 Then
      EIP:=GetReg32(RmField)
     Else
      EIP:=ReadDWord(Addr);
    End;
  5:Begin { JMP m16:32 - far indirect }
     If Addr=-1 Then Begin
      WriteLn('Erreur: JMP far indirect ne peut pas utiliser un registre');
      Exit;
     End;
     EIP:=ReadDWord(Addr);
     Segs.CS:=ReadWord(Addr+4);
    End;
  Else
   WriteLn('Erreur: opcode $FF /',RegField,' non gere par ExecGrp5_JMP');
 End;
End;

  { TODO 13 : CALL near/far et RET/RETF en mode protege 32 bits,
    avec empilement/depilement de EIP et CS sur la pile 32 bits. }

  { CALL near (rel32) - opcode $E8 : appel relatif near 32 bits }
Procedure ExecCALL_Near32;
Var
 Rel:LongInt;
Begin
 Rel:=FetchDWord;
 Push32(EIP);
 EIP:=EIP+Rel;
End;

  { CALL far (ptr16:32) - opcode $9A : appel direct far,
    empile CS puis EIP, puis charge le nouveau CS:EIP }
Procedure ExecCALL_Far;
Var
 NewEIP:LongInt;
 NewCS:Word;
Begin
 NewEIP:=FetchDWord;
 NewCS:=FetchWord;
 Push32(LongInt(Segs.CS));
 Push32(EIP);
 EIP:=NewEIP;
 Segs.CS:=NewCS;
End;

  { CALL r/m32 - opcode $FF /2 : appel indirect near via registre ou memoire
    CALL m16:32 - opcode $FF /3 : appel indirect far via memoire }
Procedure ExecGrp5_CALL;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
 NewEIP:LongInt;
 NewCS:Word;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 Case RegField of
  2:Begin { CALL r/m32 - near indirect }
     If Addr=-1 Then
      NewEIP:=GetReg32(RmField)
     Else
      NewEIP:=ReadDWord(Addr);
     Push32(EIP);
     EIP:=NewEIP;
    End;
  3:Begin { CALL m16:32 - far indirect }
     If Addr=-1 Then Begin
      WriteLn('Erreur: CALL far indirect ne peut pas utiliser un registre');
      Exit;
     End;
     NewEIP:=ReadDWord(Addr);
     NewCS:=ReadWord(Addr+4);
     Push32(LongInt(Segs.CS));
     Push32(EIP);
     EIP:=NewEIP;
     Segs.CS:=NewCS;
    End;
  Else
   WriteLn('Erreur: opcode $FF /',RegField,' non gere par ExecGrp5_CALL');
 End;
End;

  { RET near - opcode $C3 : retour near (depile EIP) }
Procedure ExecRET;
Begin
 EIP:=Pop32;
End;

  { RET near imm16 - opcode $C2 : retour near avec liberation de
    parametres sur la pile (depile EIP, puis ESP += imm16) }
Procedure ExecRET_Imm16;
Var
 Imm:Word;
Begin
 Imm:=FetchWord;
 EIP:=Pop32;
 Regs.ESP:=Regs.ESP+Imm;
End;

  { RETF - opcode $CB : retour far (depile EIP puis CS) }
Procedure ExecRETF;
Begin
 EIP:=Pop32;
 Segs.CS:=Word(Pop32);
End;

  { RETF imm16 - opcode $CA : retour far avec liberation de
    parametres sur la pile (depile EIP, depile CS, ESP += imm16) }
Procedure ExecRETF_Imm16;
Var
 Imm:Word;
Begin
 Imm:=FetchWord;
 EIP:=Pop32;
 Segs.CS:=Word(Pop32);
 Regs.ESP:=Regs.ESP+Imm;
End;

  { TODO 15 : INT 31h fonction 0000h - Allocate LDT Descriptors.
    Alloue un nombre contigu de selecteurs dans la LDT.
    Entree : CX = nombre de descripteurs a allouer.
    Sortie : si succes, CF=0 et AX = selecteur de base du premier
             descripteur alloue (bits 15..3 = index LDT, bit 2 = TI=1
             pour LDT, bits 1..0 = RPL=11b).
             si echec, CF=1. }
Function DPMI_AllocLDTDescriptors(Count:Word):LongInt;
Var
 I,J:Word;
 Found:Boolean;
 StartIdx:Word;
Begin
 If Count=0 Then Begin
  DPMI_AllocLDTDescriptors:=-1;
  Exit;
 End;
  { Recherche d'un bloc contigu de 'Count' descripteurs libres.
    On commence a l'index 1 car l'index 0 est le selecteur nul. }
 For I:=1 to LDTSize-Count do Begin
  Found:=True;
  For J:=0 to Count-1 do Begin
   If LDT[I+J].InUse Then Begin
    Found:=False;
    Break;
   End;
  End;
  If Found Then Begin
    { Marquer les descripteurs comme alloues }
   For J:=0 to Count-1 do Begin
    LDT[I+J].InUse:=True;
    LDT[I+J].BaseAddr:=0;
    LDT[I+J].Limit:=$FFFF;
    LDT[I+J].AccessType:=$F2;  { P=1, DPL=3, S=1, Type=2 (Data R/W) }
    LDT[I+J].Granularity:=0;
   End;
    { Construire le selecteur : index*8 + TI(bit2=1) + RPL(bits1:0=11b) }
   StartIdx:=I;
   DPMI_AllocLDTDescriptors:=LongInt(StartIdx shl 3) or $07;  { TI=1 (bit 2) + RPL=3 (bits 1:0) }
   Exit;
  End;
 End;
  { Pas de bloc contigu disponible }
 DPMI_AllocLDTDescriptors:=-1;
End;

  { TODO 16 : INT 31h fonction 0001h - Free LDT Descriptor.
    Libere un selecteur precedemment alloue dans la LDT.
    Entree : BX = selecteur a liberer.
    Sortie : si succes, CF=0.
             si echec (selecteur invalide ou non alloue), CF=1. }
Function DPMI_FreeLDTDescriptor(Selector:Word):Boolean;
Var
 Idx:Word;
Begin
  { Extraire l'index LDT du selecteur (bits 15..3) }
 Idx:=Selector shr 3;
  { Verifier que l'index est valide et que le descripteur est alloue }
 If(Idx>=1)and(Idx<LDTSize)and(LDT[Idx].InUse)Then Begin
  LDT[Idx].InUse:=False;
  LDT[Idx].BaseAddr:=0;
  LDT[Idx].Limit:=0;
  LDT[Idx].AccessType:=0;
  LDT[Idx].Granularity:=0;
  DPMI_FreeLDTDescriptor:=True;
 End Else
  DPMI_FreeLDTDescriptor:=False;
End;

  { TODO 17 : INT 31h fonction 0007h - Set Segment Base Address.
    Modifie l'adresse de base d'un descripteur dans la LDT.
    Entree : BX = selecteur, CX:DX = adresse de base 32 bits (CX = mot haut, DX = mot bas).
    Sortie : si succes, CF=0.
             si echec (selecteur invalide ou non alloue), CF=1. }
Function DPMI_SetSegmentBaseAddress(Selector:Word;BaseHi,BaseLo:Word):Boolean;
Var
 Idx:Word;
Begin
 Idx:=Selector shr 3;
 If(Idx>=1)and(Idx<LDTSize)and(LDT[Idx].InUse)Then Begin
  LDT[Idx].BaseAddr:=LongInt(BaseHi) shl 16 + BaseLo;
  DPMI_SetSegmentBaseAddress:=True;
 End Else
  DPMI_SetSegmentBaseAddress:=False;
End;

  { TODO 17 : INT 31h fonction 0008h - Get Segment Base Address.
    Lit l'adresse de base d'un descripteur dans la LDT.
    Entree : BX = selecteur.
    Sortie : si succes, CF=0 et CX:DX = adresse de base 32 bits.
             si echec (selecteur invalide ou non alloue), CF=1. }
Function DPMI_GetSegmentBaseAddress(Selector:Word;Var BaseHi,BaseLo:Word):Boolean;
Var
 Idx:Word;
Begin
 Idx:=Selector shr 3;
 If(Idx>=1)and(Idx<LDTSize)and(LDT[Idx].InUse)Then Begin
  BaseHi:=Word(LDT[Idx].BaseAddr shr 16);
  BaseLo:=Word(LDT[Idx].BaseAddr and $FFFF);
  DPMI_GetSegmentBaseAddress:=True;
 End Else
  DPMI_GetSegmentBaseAddress:=False;
End;

  { TODO 18 : INT 31h fonction 0009h - Set Segment Limit and Descriptor Access Rights.
    Modifie la limite du segment, les droits d'acces et la granularite d'un descripteur.
    Entree : BX = selecteur, CX:DX = limite 32 bits (CX = mot haut, DX = mot bas),
             SI = droits d'acces (octet bas = AccessType, octet haut = Granularity).
    Sortie : si succes, CF=0.
             si echec (selecteur invalide ou non alloue), CF=1. }
Function DPMI_SetSegmentLimitAndRights(Selector:Word;LimitHi,LimitLo,Rights:Word):Boolean;
Var
 Idx:Word;
Begin
 Idx:=Selector shr 3;
 If(Idx>=1)and(Idx<LDTSize)and(LDT[Idx].InUse)Then Begin
  LDT[Idx].Limit:=LongInt(LimitHi) shl 16 + LimitLo;
  LDT[Idx].AccessType:=Lo(Rights);
  LDT[Idx].Granularity:=Hi(Rights);
  DPMI_SetSegmentLimitAndRights:=True;
 End Else
  DPMI_SetSegmentLimitAndRights:=False;
End;

  { TODO 18 : INT 31h fonction 000Ah - Get Segment Limit and Descriptor Access Rights.
    Lit la limite du segment, les droits d'acces et la granularite d'un descripteur.
    Entree : BX = selecteur.
    Sortie : si succes, CF=0, CX:DX = limite 32 bits, SI = droits d'acces
             (octet bas = AccessType, octet haut = Granularity).
             si echec (selecteur invalide ou non alloue), CF=1. }
Function DPMI_GetSegmentLimitAndRights(Selector:Word;Var LimitHi,LimitLo,Rights:Word):Boolean;
Var
 Idx:Word;
Begin
 Idx:=Selector shr 3;
 If(Idx>=1)and(Idx<LDTSize)and(LDT[Idx].InUse)Then Begin
  LimitHi:=Word(LDT[Idx].Limit shr 16);
  LimitLo:=Word(LDT[Idx].Limit and $FFFF);
  Rights:=Word(LDT[Idx].AccessType) or (Word(LDT[Idx].Granularity) shl 8);
  DPMI_GetSegmentLimitAndRights:=True;
 End Else
  DPMI_GetSegmentLimitAndRights:=False;
End;

  { TODO 19 : INT 31h fonction 0501h - Allocate Memory Block.
    Alloue un bloc de memoire lineaire dans l'espace de 16 Mo.
    Entree : BX:CX = taille du bloc en octets (BX = mot haut, CX = mot bas).
    Sortie : si succes, CF=0, BX:CX = adresse lineaire du bloc,
             SI:DI = handle du bloc.
             si echec (plus de memoire ou plus d'entrees libres), CF=1. }
Function DPMI_AllocMemoryBlock(SizeHi,SizeLo:Word;Var AddrHi,AddrLo,HandleHi,HandleLo:Word):Boolean;
Var
 BlockSize,Addr:LongInt;
 I:Integer;
Begin
 BlockSize:=LongInt(SizeHi) shl 16 + SizeLo;
 If BlockSize<=0 Then Begin
  DPMI_AllocMemoryBlock:=False;
  Exit;
 End;
  { Aligner NextLinearAddr sur 4 Ko avant l'allocation }
 If(NextLinearAddr and $FFF)<>0 Then
  NextLinearAddr:=(NextLinearAddr or $FFF)+1;
  { Verifier qu'il reste assez de memoire lineaire }
 If NextLinearAddr+BlockSize>MemorySize Then Begin
  DPMI_AllocMemoryBlock:=False;
  Exit;
 End;
  { Chercher une entree libre dans la table des blocs }
 For I:=0 to MaxMemBlocks-1 do Begin
  If Not MemBlocks[I].InUse Then Begin
   Addr:=NextLinearAddr;
   MemBlocks[I].BaseAddr:=Addr;
   MemBlocks[I].Size:=BlockSize;
   MemBlocks[I].Handle:=NextHandle;
   MemBlocks[I].InUse:=True;
   NextLinearAddr:=NextLinearAddr+BlockSize;
   AddrHi:=Word(Addr shr 16);
   AddrLo:=Word(Addr and $FFFF);
   HandleHi:=Word(NextHandle shr 16);
   HandleLo:=Word(NextHandle and $FFFF);
   Inc(NextHandle);
   DPMI_AllocMemoryBlock:=True;
   Exit;
  End;
 End;
 DPMI_AllocMemoryBlock:=False;
End;

  { TODO 20 : INT 31h fonction 0502h - Free Memory Block.
    Libere un bloc de memoire alloue par la fonction 0501h.
    Entree : SI:DI = handle du bloc a liberer.
    Sortie : si succes, CF=0. Si handle invalide, CF=1. }
Function DPMI_FreeMemoryBlock(HandleHi,HandleLo:Word):Boolean;
Var
 Handle:LongInt;
 I:Integer;
Begin
 Handle:=LongInt(HandleHi) shl 16 + HandleLo;
 For I:=0 to MaxMemBlocks-1 do Begin
  If MemBlocks[I].InUse and(MemBlocks[I].Handle=Handle)Then Begin
   MemBlocks[I].InUse:=False;
   DPMI_FreeMemoryBlock:=True;
   Exit;
  End;
 End;
 DPMI_FreeMemoryBlock:=False;
End;

  { TODO 20 : INT 31h fonction 0503h - Resize Memory Block.
    Redimensionne un bloc de memoire existant.
    Entree : BX:CX = nouvelle taille en octets,
             SI:DI = handle du bloc a redimensionner.
    Sortie : si succes, CF=0, BX:CX = nouvelle adresse lineaire,
             SI:DI = nouveau handle du bloc.
             si echec, CF=1. }
Function DPMI_ResizeMemoryBlock(NewSizeHi,NewSizeLo,HandleHi,HandleLo:Word;
                                Var AddrHi,AddrLo,NewHandleHi,NewHandleLo:Word):Boolean;
Var
 Handle,NewSize,NewAddr:LongInt;
 I:Integer;
Begin
 Handle:=LongInt(HandleHi) shl 16 + HandleLo;
 NewSize:=LongInt(NewSizeHi) shl 16 + NewSizeLo;
 If NewSize<=0 Then Begin
  DPMI_ResizeMemoryBlock:=False;
  Exit;
 End;
 For I:=0 to MaxMemBlocks-1 do Begin
  If MemBlocks[I].InUse and(MemBlocks[I].Handle=Handle)Then Begin
    { Si la nouvelle taille tient dans l'ancien bloc, ajuster sur place }
   If NewSize<=MemBlocks[I].Size Then Begin
    MemBlocks[I].Size:=NewSize;
    AddrHi:=Word(MemBlocks[I].BaseAddr shr 16);
    AddrLo:=Word(MemBlocks[I].BaseAddr and $FFFF);
    NewHandleHi:=HandleHi;
    NewHandleLo:=HandleLo;
    DPMI_ResizeMemoryBlock:=True;
    Exit;
   End;
    { Sinon, allouer un nouveau bloc et liberer l'ancien }
   If(NextLinearAddr and $FFF)<>0 Then
    NextLinearAddr:=(NextLinearAddr or $FFF)+1;
   If NextLinearAddr+NewSize>MemorySize Then Begin
    DPMI_ResizeMemoryBlock:=False;
    Exit;
   End;
   NewAddr:=NextLinearAddr;
   NextLinearAddr:=NextLinearAddr+NewSize;
    { Copier l'ancien contenu via le fichier d'echange }
   CopySwapBlock(MemBlocks[I].BaseAddr,NewAddr,MemBlocks[I].Size);
    { Mettre a jour l'entree du bloc }
   MemBlocks[I].BaseAddr:=NewAddr;
   MemBlocks[I].Size:=NewSize;
   MemBlocks[I].Handle:=NextHandle;
   AddrHi:=Word(NewAddr shr 16);
   AddrLo:=Word(NewAddr and $FFFF);
   NewHandleHi:=Word(NextHandle shr 16);
   NewHandleLo:=Word(NextHandle and $FFFF);
   Inc(NextHandle);
   DPMI_ResizeMemoryBlock:=True;
   Exit;
  End;
 End;
 DPMI_ResizeMemoryBlock:=False;
End;

  { TODO 21 : Gestionnaire INT 21h (services DOS) en mode protege DPMI.
    AH contient le numero de service DOS.
    Les adresses selecteur:offset sont traduites en adresses lineaires
    pour l'acces aux tampons memoire via le fichier d'echange.
    Services geres : $02 (afficher caractere), $09 (afficher chaine $),
    $3C (creer fichier), $3D (ouvrir fichier), $3E (fermer fichier),
    $3F (lire fichier), $40 (ecrire fichier), $4C (terminer programme). }
Procedure ExecINT21h;
Var
 Func:Byte;
 Addr:LongInt;
 B:Byte;
 I:Integer;
 FileName:String;
 Handle:Word;
 Count:Word;
 BytesTransferred:Word;
 IOBuffer:Array[0..1023]of Byte;
 ChunkSize:Word;
 Remaining:Word;
Begin
 Func:=Regs.AH;
 Case Func of
  $02:Begin { Display Character - DL = character }
    Write(Chr(Regs.DL));
    Regs.AL:=Regs.DL;
    Exclude(EFlags.s,CF);
   End;
  $09:Begin { Display String - DS:EDX -> '$'-terminated string }
    Addr:=SelOfsToLinear(Segs.DS,Regs.EDX);
    If Addr>=0 Then Begin
     Repeat
      B:=ReadByte(Addr);
      If B<>Ord('$') Then Begin
       Write(Chr(B));
       Inc(Addr);
      End;
     Until B=Ord('$');
     Regs.AL:=Ord('$');
     Exclude(EFlags.s,CF);
    End Else
     Include(EFlags.s,CF);
   End;
  $3C:Begin { Create File - DS:EDX -> ASCIIZ filename, CX = attributes }
      { TODO 24 : Interdire la creation de fichier en mode /READONLY }
     If ReadOnlyMode Then Begin
      WriteLn('INT 21h/$3C: ecriture refusee (mode /READONLY)');
      Regs.AX:=5;  { Acces refuse }
      Include(EFlags.s,CF);
     End Else Begin
      { Lire le nom de fichier ASCIIZ depuis la memoire lineaire }
     Addr:=SelOfsToLinear(Segs.DS,Regs.EDX);
    FileName:='';
    If Addr>=0 Then Begin
     B:=ReadByte(Addr);
     While (B<>0)and(Length(FileName)<255) do Begin
      FileName:=FileName+Chr(B);
      Inc(Addr);
      B:=ReadByte(Addr);
     End;
      { Trouver un slot libre dans la table des fichiers }
     Handle:=$FFFF;
     For I:=5 to MaxDosFiles-1 do Begin  { 0-4 reservees (stdin/out/err/aux/prn) }
      If not DosFiles[I].InUse Then Begin
       Handle:=I;
       Break;
      End;
     End;
     If Handle<>$FFFF Then Begin
      {$I-}Assign(DosFiles[Handle].F,FileName);
      Rewrite(DosFiles[Handle].F,1);{$I+}
      If IOResult=0 Then Begin
       DosFiles[Handle].InUse:=True;
       Regs.AX:=Handle;
       Exclude(EFlags.s,CF);
      End Else Begin
       Regs.AX:=5;  { Acces refuse }
       Include(EFlags.s,CF);
      End;
     End Else Begin
      Regs.AX:=4;  { Trop de fichiers ouverts }
      Include(EFlags.s,CF);
     End;
    End Else Begin
     Regs.AX:=2;  { Fichier non trouve }
     Include(EFlags.s,CF);
    End;
     End; { Else ReadOnlyMode }
   End;
  $3D:Begin { Open File - DS:EDX -> ASCIIZ filename, AL = mode }
    Addr:=SelOfsToLinear(Segs.DS,Regs.EDX);
    FileName:='';
    If Addr>=0 Then Begin
     B:=ReadByte(Addr);
     While (B<>0)and(Length(FileName)<255) do Begin
      FileName:=FileName+Chr(B);
      Inc(Addr);
      B:=ReadByte(Addr);
     End;
     Handle:=$FFFF;
     For I:=5 to MaxDosFiles-1 do Begin
      If not DosFiles[I].InUse Then Begin
       Handle:=I;
       Break;
      End;
     End;
     If Handle<>$FFFF Then Begin
      {$I-}Assign(DosFiles[Handle].F,FileName);
      Reset(DosFiles[Handle].F,1);{$I+}
      If IOResult=0 Then Begin
       DosFiles[Handle].InUse:=True;
       Regs.AX:=Handle;
       Exclude(EFlags.s,CF);
      End Else Begin
       Regs.AX:=2;  { Fichier non trouve }
       Include(EFlags.s,CF);
      End;
     End Else Begin
      Regs.AX:=4;  { Trop de fichiers ouverts }
      Include(EFlags.s,CF);
     End;
    End Else Begin
     Regs.AX:=2;
     Include(EFlags.s,CF);
    End;
   End;
  $3E:Begin { Close File - BX = handle }
    Handle:=Regs.BX;
    If (Handle>=5)and(Handle<MaxDosFiles)and DosFiles[Handle].InUse Then Begin
     {$I-}Close(DosFiles[Handle].F);{$I+}
     If IOResult=0 Then Begin End;  { Ignorer erreur de fermeture }
     DosFiles[Handle].InUse:=False;
     Exclude(EFlags.s,CF);
    End Else Begin
     Regs.AX:=6;  { Handle invalide }
     Include(EFlags.s,CF);
    End;
   End;
  $3F:Begin { Read File - BX = handle, CX = count, DS:EDX -> buffer }
    Handle:=Regs.BX;
    Count:=Regs.CX;
    Addr:=SelOfsToLinear(Segs.DS,Regs.EDX);
    If (Handle>=5)and(Handle<MaxDosFiles)and DosFiles[Handle].InUse
       and(Addr>=0) Then Begin
     Remaining:=Count;
     Regs.AX:=0;
     Exclude(EFlags.s,CF);
     While Remaining>0 do Begin
      If Remaining>SizeOf(IOBuffer) Then
       ChunkSize:=SizeOf(IOBuffer)
      Else
       ChunkSize:=Remaining;
      {$I-}BlockRead(DosFiles[Handle].F,IOBuffer,ChunkSize,BytesTransferred);{$I+}
      If IOResult<>0 Then Begin
       Regs.AX:=5;  { Erreur de lecture }
       Include(EFlags.s,CF);
       Break;
      End;
      For I:=0 to BytesTransferred-1 do
       WriteByte(Addr+I,IOBuffer[I]);
      Addr:=Addr+BytesTransferred;
      Regs.AX:=Regs.AX+BytesTransferred;
      Dec(Remaining,BytesTransferred);
      If BytesTransferred<ChunkSize Then Break;  { Fin de fichier }
     End;
    End Else Begin
     Regs.AX:=6;  { Handle invalide }
     Include(EFlags.s,CF);
    End;
   End;
  $40:Begin { Write File - BX = handle, CX = count, DS:EDX -> buffer }
    Handle:=Regs.BX;
     { TODO 24 : Interdire les ecritures sur fichier en mode /READONLY
       (les handles 1 et 2 = stdout/stderr restent autorises) }
    If ReadOnlyMode and(Handle>=5) Then Begin
     WriteLn('INT 21h/$40: ecriture refusee (mode /READONLY)');
     Regs.AX:=5;  { Acces refuse }
     Include(EFlags.s,CF);
    End Else Begin
    Count:=Regs.CX;
    Addr:=SelOfsToLinear(Segs.DS,Regs.EDX);
    If (Addr>=0)and(
       ((Handle=1)or(Handle=2))or
       ((Handle>=5)and(Handle<MaxDosFiles)and DosFiles[Handle].InUse)
       ) Then Begin
     Remaining:=Count;
     Regs.AX:=0;
     Exclude(EFlags.s,CF);
     While Remaining>0 do Begin
      If Remaining>SizeOf(IOBuffer) Then
       ChunkSize:=SizeOf(IOBuffer)
      Else
       ChunkSize:=Remaining;
      For I:=0 to ChunkSize-1 do
       IOBuffer[I]:=ReadByte(Addr+I);
      If (Handle=1)or(Handle=2) Then Begin  { stdout/stderr -> ecrire sur console }
       For I:=0 to ChunkSize-1 do Write(Chr(IOBuffer[I]));
       BytesTransferred:=ChunkSize;
      End Else Begin
       {$I-}BlockWrite(DosFiles[Handle].F,IOBuffer,ChunkSize,BytesTransferred);{$I+}
       If IOResult<>0 Then Begin
        Regs.AX:=5;  { Erreur d'ecriture }
        Include(EFlags.s,CF);
        Break;
       End;
      End;
      Addr:=Addr+BytesTransferred;
      Regs.AX:=Regs.AX+BytesTransferred;
      Dec(Remaining,BytesTransferred);
      If BytesTransferred<ChunkSize Then Break;
     End;
    End Else Begin
     Regs.AX:=6;  { Handle invalide }
     Include(EFlags.s,CF);
    End;
    End; { Else ReadOnlyMode }
   End;
  $4C:Begin { Terminate Program - AL = exit code }
    DosExitCode:=Regs.AL;
    Terminated:=True;
   End;
  Else Begin
   WriteLn('INT 21h: service $',HexStr(Func,2),' non implemente');
   Include(EFlags.s,CF);
  End;
 End;
End;

  { TODO 15-20 : Gestionnaire INT 31h (DPMI) - dispatch par numero de fonction.
    AX contient le numero de fonction DPMI.
    Fonctions gerees : 0000h (Allocate LDT), 0001h (Free LDT), 0007h (Set Base),
    0008h (Get Base), 0009h (Set Limit+Rights), 000Ah (Get Limit+Rights),
    0501h (Allocate Memory Block), 0502h (Free Memory Block),
    0503h (Resize Memory Block). }
Procedure ExecINT31h;
Var
 Func:Word;
 Res:LongInt;
 TmpAddrHi,TmpAddrLo,TmpHandleHi,TmpHandleLo:Word;
Begin
 Func:=Regs.AX;
 Case Func of
  $0000:Begin { Allocate LDT Descriptors }
    Res:=DPMI_AllocLDTDescriptors(Regs.CX);
    If Res>=0 Then Begin
      { Succes : CF=0, AX = selecteur de base }
     Exclude(EFlags.s,CF);
     Regs.AX:=Word(Res);
    End Else Begin
      { Echec : CF=1 }
     Include(EFlags.s,CF);
    End;
   End;
  $0001:Begin { Free LDT Descriptor }
    If DPMI_FreeLDTDescriptor(Regs.BX) Then
     Exclude(EFlags.s,CF)
    Else
     Include(EFlags.s,CF);
   End;
  $0007:Begin { Set Segment Base Address }
    If DPMI_SetSegmentBaseAddress(Regs.BX,Regs.CX,Regs.DX) Then
     Exclude(EFlags.s,CF)
    Else
     Include(EFlags.s,CF);
   End;
  $0008:Begin { Get Segment Base Address }
    If DPMI_GetSegmentBaseAddress(Regs.BX,Regs.CX,Regs.DX) Then
     Exclude(EFlags.s,CF)
    Else
     Include(EFlags.s,CF);
   End;
  $0009:Begin { Set Segment Limit and Descriptor Access Rights }
    If DPMI_SetSegmentLimitAndRights(Regs.BX,Regs.CX,Regs.DX,Regs.SI) Then
     Exclude(EFlags.s,CF)
    Else
     Include(EFlags.s,CF);
   End;
  $000A:Begin { Get Segment Limit and Descriptor Access Rights }
    If DPMI_GetSegmentLimitAndRights(Regs.BX,Regs.CX,Regs.DX,Regs.SI) Then
     Exclude(EFlags.s,CF)
    Else
     Include(EFlags.s,CF);
   End;
  $0501:Begin { Allocate Memory Block }
    If DPMI_AllocMemoryBlock(Regs.BX,Regs.CX,TmpAddrHi,TmpAddrLo,TmpHandleHi,TmpHandleLo) Then Begin
     Regs.BX:=TmpAddrHi;
     Regs.CX:=TmpAddrLo;
     Regs.SI:=TmpHandleHi;
     Regs.DI:=TmpHandleLo;
     Exclude(EFlags.s,CF);
    End Else
     Include(EFlags.s,CF);
   End;
  $0502:Begin { Free Memory Block }
    If DPMI_FreeMemoryBlock(Regs.SI,Regs.DI) Then
     Exclude(EFlags.s,CF)
    Else
     Include(EFlags.s,CF);
   End;
  $0503:Begin { Resize Memory Block }
    If DPMI_ResizeMemoryBlock(Regs.BX,Regs.CX,Regs.SI,Regs.DI,TmpAddrHi,TmpAddrLo,TmpHandleHi,TmpHandleLo) Then Begin
     Regs.BX:=TmpAddrHi;
     Regs.CX:=TmpAddrLo;
     Regs.SI:=TmpHandleHi;
     Regs.DI:=TmpHandleLo;
     Exclude(EFlags.s,CF);
    End Else
     Include(EFlags.s,CF);
   End;
  Else Begin
   WriteLn('INT 31h: fonction $',HexStr(Func,4),' non implementee');
   Include(EFlags.s,CF);
  End;
 End;
End;

  { TODO 22 : Chargeur de programme binaire plat (flat binary).
    Charge un fichier executable dans la memoire lineaire a l'adresse
    de base FlatLoadBase, initialise quatre selecteurs CS, DS, ES, SS avec
    des descripteurs couvrant tout l'espace de 16 Mo (base=0, limite=
    $FFFFFF, granularite page 4 Ko), initialise la pile (ESP pointe en
    haut de la memoire lineaire) et fixe EIP au point d'entree.
    Retourne True si le chargement a reussi, False sinon. }
Function LoadFlatBinary(FileName:String):Boolean;
Const
  StackTop=MemorySize; { Sommet de pile : 16 Mo }
  LoadBufSize=4096;    { Taille du tampon de lecture }
Var
 F:File;
 FileLen,Pos:LongInt;
 LoadBuf:Array[0..LoadBufSize-1]of Byte;
 BytesRead:Word;
 SelCode,SelData:LongInt;
 IdxCode,IdxData:Word;
Begin
 LoadFlatBinary:=False;
  { Ouvrir le fichier binaire }
 {$I-}Assign(F,FileName);
 Reset(F,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('LoadFlatBinary: impossible d''ouvrir "',FileName,'"');
  Exit;
 End;
  { Taille du fichier }
 FileLen:=FileSize(F);
 If FileLen<=0 Then Begin
  WriteLn('LoadFlatBinary: fichier vide');
  Close(F);
  Exit;
 End;
 If FileLen>LongInt(MemorySize)-FlatLoadBase Then Begin
  WriteLn('LoadFlatBinary: fichier trop grand (',FileLen,' octets)');
  Close(F);
  Exit;
 End;
  { Charger le fichier en memoire lineaire a l'adresse FlatLoadBase }
 Pos:=FlatLoadBase;
 While Not Eof(F) do Begin
  {$I-}BlockRead(F,LoadBuf,LoadBufSize,BytesRead);{$I+}
  If IOResult<>0 Then Begin
   WriteLn('LoadFlatBinary: erreur de lecture');
   Close(F);
   Exit;
  End;
  If BytesRead>0 Then Begin
   Seek(Memory,Pos);
   BlockWrite(Memory,LoadBuf,BytesRead);
   Pos:=Pos+LongInt(BytesRead);
  End;
 End;
 Close(F);
 WriteLn('LoadFlatBinary: ',FileLen,' octets charges a l''adresse $',HexStr(FlatLoadBase,8));
  { Allouer un selecteur pour le segment de code (CS) }
 SelCode:=DPMI_AllocLDTDescriptors(1);
 If SelCode<0 Then Begin
  WriteLn('LoadFlatBinary: impossible d''allouer un selecteur CS');
  Exit;
 End;
 IdxCode:=Word(SelCode) shr 3;
  { Configurer le descripteur de code : base=0, limite=16 Mo, granularite
    page 4 Ko (G=1), segment 32 bits (D=1), code execute/read }
 LDT[IdxCode].BaseAddr:=0;
 LDT[IdxCode].Limit:=$FFFFFF;       { Limite brute en valeur de page : couvre tout l'espace }
 LDT[IdxCode].AccessType:=$FA;      { P=1, DPL=3, S=1, Type=$A (code exec/read) }
 LDT[IdxCode].Granularity:=$C0;     { G=1 (bit7), D=1 (bit6) = segment 32 bits avec granularite 4 Ko }
  { Allouer un selecteur pour les segments de donnees (DS/ES/SS) }
 SelData:=DPMI_AllocLDTDescriptors(1);
 If SelData<0 Then Begin
  WriteLn('LoadFlatBinary: impossible d''allouer un selecteur DS');
  Exit;
 End;
 IdxData:=Word(SelData) shr 3;
  { Configurer le descripteur de donnees : base=0, limite=16 Mo,
    granularite page 4 Ko (G=1), segment 32 bits (B=1), data read/write }
 LDT[IdxData].BaseAddr:=0;
 LDT[IdxData].Limit:=$FFFFFF;
 LDT[IdxData].AccessType:=$F2;      { P=1, DPL=3, S=1, Type=$2 (data read/write) }
 LDT[IdxData].Granularity:=$C0;     { G=1, B=1 }
  { Initialiser les registres de segment }
 Segs.CS:=Word(SelCode);
 Segs.DS:=Word(SelData);
 Segs.ES:=Word(SelData);
 Segs.SS:=Word(SelData);
 Segs.FS:=Word(SelData);
 Segs.GS:=Word(SelData);
  { Initialiser les registres generaux }
 FillChar(Regs,SizeOf(Regs),0);
 Regs.ESP:=StackTop;  { Pile en haut de la memoire lineaire }
  { Initialiser le pointeur d'instruction au point d'entree }
 EIP:=FlatLoadBase;
  { Initialiser les drapeaux }
 EFlags.Abs:=0;
 Include(EFlags.s,bit1);  { Bit 1 toujours a 1 en x86 }
 Include(EFlags.s,_IF);   { Interruptions activees }
  { Reinitialiser l'etat d'execution }
 Terminated:=False;
 DosExitCode:=0;
 ResetPrefixes;
 WriteLn('LoadFlatBinary: CS=$',HexStr(Word(SelCode),4),
         ' DS=ES=SS=$',HexStr(Word(SelData),4),
         ' EIP=$',HexStr(FlatLoadBase,8),
         ' ESP=$',HexStr(StackTop,8));
 LoadFlatBinary:=True;
End;

  { TODO 24 : Affichage de l'etat des registres pour le mode debogage.
    Appele a chaque instruction quand /DEBUG est active. }
Procedure DumpRegisters;
Begin
 WriteLn('  EAX=$',HexStr(Regs.EAX,8),
         ' EBX=$',HexStr(Regs.EBX,8),
         ' ECX=$',HexStr(Regs.ECX,8),
         ' EDX=$',HexStr(Regs.EDX,8));
 WriteLn('  ESI=$',HexStr(Regs.ESI,8),
         ' EDI=$',HexStr(Regs.EDI,8),
         ' EBP=$',HexStr(Regs.EBP,8),
         ' ESP=$',HexStr(Regs.ESP,8));
 WriteLn('  CS=$',HexStr(Segs.CS,4),
         ' DS=$',HexStr(Segs.DS,4),
         ' ES=$',HexStr(Segs.ES,4),
         ' SS=$',HexStr(Segs.SS,4),
         ' FS=$',HexStr(Segs.FS,4),
         ' GS=$',HexStr(Segs.GS,4),
         ' EIP=$',HexStr(EIP,8),
         ' FL=$',HexStr(EFlags.Base,4));
End;

  { TODO 24 : Analyse des options de ligne de commande.
    Reconnait /DEBUG, /VERBOSE et /READONLY (insensible a la casse).
    Les options sont separees du nom de fichier programme. }
Procedure ParseCommandLine;
Var
 I,J:Integer;
 S:String;
Begin
 DebugMode:=False;
 VerboseMode:=False;
 ReadOnlyMode:=False;
 For I:=1 to ParamCount do Begin
  S:=ParamStr(I);
   { Convertir en majuscules pour comparaison insensible a la casse }
  For J:=1 to Length(S) do S[J]:=UpCase(S[J]);
  If S='/DEBUG' Then
   DebugMode:=True
  Else If S='/VERBOSE' Then
   VerboseMode:=True
  Else If S='/READONLY' Then
   ReadOnlyMode:=True;
 End;
End;

  { TODO 23 : Boucle principale d'execution (Procedure Run).
    Decode le flux d'instructions depuis CS:EIP, gere les prefixes
    (66h, 67h, segments, REP/REPE/REPNE), et dispatche vers les
    procedures d'emulation de chaque opcode.
    La boucle s'arrete quand Terminated est mis a True (par INT 21h/4Ch)
    ou quand un opcode non gere est rencontre. }
Procedure Run;
Var
 Op,Op2:Byte;
 HasRep:Boolean;
 RepType:Byte;
 RegF,RmF:Byte;
 Addr:LongInt;
 Val:LongInt;
 SavedEIP:LongInt;
Begin
 While Not Terminated do Begin
  ResetPrefixes;
  HasRep:=False;
  RepType:=0;
   { TODO 24 : Sauvegarder EIP avant le decodage pour l'affichage debug }
  SavedEIP:=EIP;
   { Phase 1 : Decodage des prefixes }
  Repeat
   Op:=FetchByte;
   Case Op of
    $26:SegOverride:=LongInt(Segs.ES);  { ES: }
    $2E:SegOverride:=LongInt(Segs.CS);  { CS: }
    $36:SegOverride:=LongInt(Segs.SS);  { SS: }
    $3E:SegOverride:=LongInt(Segs.DS);  { DS: }
    $64:SegOverride:=LongInt(Segs.FS);  { FS: }
    $65:SegOverride:=LongInt(Segs.GS);  { GS: }
    $66:;  { Prefixe de taille d'operande (16 bits dans mode 32 bits) -
             reconnu mais pas encore exploite pour le dispatch 16 bits }
    $67:AddrSizeOverride:=True;
    $F2:Begin HasRep:=True;RepType:=$F2;End;  { REPNE/REPNZ }
    $F3:Begin HasRep:=True;RepType:=$F3;End;  { REP/REPE/REPZ }
   Else
    Break;
   End;
  Until False;
   { TODO 24 : Affichage debug de l'opcode et des registres }
  If DebugMode Then Begin
   WriteLn('[DEBUG] CS:EIP=$',HexStr(Segs.CS,4),':$',HexStr(SavedEIP,8),
           ' Op=$',HexStr(Op,2));
   DumpRegisters;
  End;
   { Phase 2 : Dispatch de l'opcode }
  Case Op of
    { --- Arithmetique : ADD --- }
   $01:ExecADD_Rm32_Reg32;
   $03:ExecADD_Reg32_Rm32;
   $05:ExecADD_EAX_Imm32;
    { --- Logique : OR --- }
   $09:ExecOR_Rm32_Reg32;
   $0B:ExecOR_Reg32_Rm32;
   $0D:ExecOR_EAX_Imm32;
    { --- Opcodes a deux octets (prefixe $0F) --- }
   $0F:Begin
     Op2:=FetchByte;
     Case Op2 of
      $80..$8F:ExecJcc_Near32(Op2-$80);  { Jcc near rel32 }
     Else Begin
      WriteLn('Opcode 2 octets non gere: $0F $',HexStr(Op2,2),
              ' a EIP=$',HexStr(EIP,8));
      Terminated:=True;
     End;
     End;
    End;
    { --- Arithmetique : ADC --- }
   $11:ExecADC_Rm32_Reg32;
   $13:ExecADC_Reg32_Rm32;
   $15:ExecADC_EAX_Imm32;
    { --- Arithmetique : SBB --- }
   $19:ExecSBB_Rm32_Reg32;
   $1B:ExecSBB_Reg32_Rm32;
   $1D:ExecSBB_EAX_Imm32;
    { --- Logique : AND --- }
   $21:ExecAND_Rm32_Reg32;
   $23:ExecAND_Reg32_Rm32;
   $25:ExecAND_EAX_Imm32;
    { --- Arithmetique : SUB --- }
   $29:ExecSUB_Rm32_Reg32;
   $2B:ExecSUB_Reg32_Rm32;
   $2D:ExecSUB_EAX_Imm32;
    { --- Logique : XOR --- }
   $31:ExecXOR_Rm32_Reg32;
   $33:ExecXOR_Reg32_Rm32;
   $35:ExecXOR_EAX_Imm32;
    { --- Arithmetique : CMP --- }
   $39:ExecCMP_Rm32_Reg32;
   $3B:ExecCMP_Reg32_Rm32;
   $3D:ExecCMP_EAX_Imm32;
    { --- INC reg32 ($40..$47) / DEC reg32 ($48..$4F) --- }
   $40..$47:ExecINC_Reg32(Op-$40);
   $48..$4F:ExecDEC_Reg32(Op-$48);
    { --- PUSH reg32 ($50..$57) / POP reg32 ($58..$5F) --- }
   $50..$57:Push32(GetReg32(Op-$50));
   $58..$5F:SetReg32(Op-$58,Pop32);
    { --- PUSH imm32 / PUSH imm8 --- }
   $68:Push32(FetchDWord);
   $6A:Push32(LongInt(ShortInt(FetchByte)));
    { --- Jcc short rel8 ($70..$7F) --- }
   $70..$7F:ExecJcc_Short(Op-$70);
    { --- Grp1 r/m32 --- }
   $81:ExecGrp1_Rm32_Imm32;
   $83:ExecGrp1_Rm32_Imm8;
    { --- TEST r/m32, reg32 --- }
   $85:ExecTEST_Rm32_Reg32;
    { --- XCHG r/m32, reg32 --- }
   $87:Begin
     Addr:=DecodeModRM32(RegF,RmF);
     If Addr=-1 Then Begin
      Val:=GetReg32(RmF);
      SetReg32(RmF,GetReg32(RegF));
      SetReg32(RegF,Val);
     End Else Begin
      Val:=ReadDWord(Addr);
      WriteDWord(Addr,GetReg32(RegF));
      SetReg32(RegF,Val);
     End;
    End;
    { --- MOV --- }
   $89:ExecMOV_Rm32_Reg32;
   $8B:ExecMOV_Reg32_Rm32;
    { --- LEA reg32, m --- }
   $8D:Begin
     Addr:=DecodeModRM32(RegF,RmF);
     If Addr<>-1 Then
      SetReg32(RegF,Addr)
     Else
      SetReg32(RegF,GetReg32(RmF));
    End;
    { --- NOP / XCHG EAX, reg32 --- }
   $90:; { NOP }
   $91..$97:Begin
     Val:=Regs.EAX;
     Regs.EAX:=GetReg32(Op-$90);
     SetReg32(Op-$90,Val);
    End;
    { --- CDQ : sign-extend EAX into EDX:EAX --- }
   $99:Begin
     If Regs.EAX<0 Then Regs.EDX:=LongInt(-1)
     Else Regs.EDX:=0;
    End;
    { --- CALL far ptr16:32 --- }
   $9A:ExecCALL_Far;
    { --- MOV EAX, moffs32 --- }
   $A1:Begin
     Addr:=SelOfsToLinear(GetEffectiveSeg(Segs.DS),FetchDWord);
     Regs.EAX:=ReadDWord(Addr);
    End;
    { --- MOV moffs32, EAX --- }
   $A3:Begin
     Addr:=SelOfsToLinear(GetEffectiveSeg(Segs.DS),FetchDWord);
     WriteDWord(Addr,Regs.EAX);
    End;
    { --- MOVSD (avec REP optionnel) --- }
   $A5:Begin
     If HasRep and(RepType=$F3)Then ExecREP_MOVSD
     Else ExecMOVSD;
    End;
    { --- CMPSD (avec REPE/REPNE optionnel) --- }
   $A7:Begin
     If HasRep Then Begin
      If RepType=$F3 Then ExecREPE_CMPSD
      Else ExecREPNE_CMPSD;
     End Else ExecCMPSD;
    End;
    { --- TEST EAX, imm32 --- }
   $A9:ExecTEST_EAX_Imm32;
    { --- STOSD (avec REP optionnel) --- }
   $AB:Begin
     If HasRep and(RepType=$F3)Then ExecREP_STOSD
     Else ExecSTOSD;
    End;
    { --- LODSD (avec REP optionnel) --- }
   $AD:Begin
     If HasRep and(RepType=$F3)Then ExecREP_LODSD
     Else ExecLODSD;
    End;
    { --- SCASD (avec REPE/REPNE optionnel) --- }
   $AF:Begin
     If HasRep Then Begin
      If RepType=$F3 Then ExecREPE_SCASD
      Else ExecREPNE_SCASD;
     End Else ExecSCASD;
    End;
    { --- MOV reg32, imm32 ($B8..$BF) --- }
   $B8..$BF:ExecMOV_Reg32_Imm32(Op-$B8);
    { --- Grp2 : decalages/rotations r/m32, imm8 --- }
   $C1:ExecGrp2_Rm32_Imm8;
    { --- RET near imm16 / RET near --- }
   $C2:ExecRET_Imm16;
   $C3:ExecRET;
    { --- MOV r/m32, imm32 --- }
   $C7:ExecMOV_Rm32_Imm32;
    { --- LEAVE --- }
   $C9:Begin
     Regs.ESP:=Regs.EBP;
     Regs.EBP:=Pop32;
    End;
    { --- RETF imm16 / RETF --- }
   $CA:ExecRETF_Imm16;
   $CB:ExecRETF;
    { --- INT 3 (breakpoint) --- }
   $CC:Begin
     WriteLn('INT 3 (breakpoint) a EIP=$',HexStr(EIP,8));
     Terminated:=True;
    End;
    { --- INT nn --- }
   $CD:Begin
     Op2:=FetchByte;
     Case Op2 of
      $21:ExecINT21h;
      $31:ExecINT31h;
     Else Begin
      WriteLn('INT $',HexStr(Op2,2),' non geree a EIP=$',HexStr(EIP,8));
      Terminated:=True;
     End;
     End;
    End;
    { --- Grp2 : decalages/rotations r/m32, 1 --- }
   $D1:ExecGrp2_Rm32_1;
    { --- Grp2 : decalages/rotations r/m32, CL --- }
   $D3:ExecGrp2_Rm32_CL;
    { --- CALL near rel32 --- }
   $E8:ExecCALL_Near32;
    { --- JMP near rel32 --- }
   $E9:ExecJMP_Near32;
    { --- JMP far ptr16:32 --- }
   $EA:ExecJMP_Far;
    { --- JMP short rel8 --- }
   $EB:ExecJMP_Short;
    { --- CMC : complement carry flag --- }
   $F5:Begin
     If CF in EFlags.s Then Exclude(EFlags.s,CF)
     Else Include(EFlags.s,CF);
    End;
    { --- Grp3 : TEST/NOT/NEG/MUL/IMUL/DIV/IDIV r/m32 --- }
   $F7:ExecGrp3_Rm32;
    { --- CLC / STC / CLI / STI / CLD / STD --- }
   $F8:Exclude(EFlags.s,CF);  { CLC }
   $F9:Include(EFlags.s,CF);  { STC }
   $FA:Exclude(EFlags.s,_IF); { CLI }
   $FB:Include(EFlags.s,_IF); { STI }
   $FC:Exclude(EFlags.s,DF);  { CLD }
   $FD:Include(EFlags.s,DF);  { STD }
    { --- Grp5 : INC/DEC/CALL/JMP/PUSH r/m32 ($FF) --- }
   $FF:Begin
     Addr:=DecodeModRM32(RegF,RmF);
     Case RegF of
      0:Begin { INC r/m32 }
        If Addr=-1 Then SetReg32(RmF,ArithInc32(GetReg32(RmF)))
        Else WriteDWord(Addr,ArithInc32(ReadDWord(Addr)));
       End;
      1:Begin { DEC r/m32 }
        If Addr=-1 Then SetReg32(RmF,ArithDec32(GetReg32(RmF)))
        Else WriteDWord(Addr,ArithDec32(ReadDWord(Addr)));
       End;
      2:Begin { CALL r/m32 - near indirect }
        If Addr=-1 Then Val:=GetReg32(RmF)
        Else Val:=ReadDWord(Addr);
        Push32(EIP);
        EIP:=Val;
       End;
      3:Begin { CALL m16:32 - far indirect }
        If Addr=-1 Then
         WriteLn('Erreur: CALL far indirect requiert un operande memoire')
        Else Begin
         Val:=ReadDWord(Addr);
         Push32(LongInt(Segs.CS));
         Push32(EIP);
         EIP:=Val;
         Segs.CS:=ReadWord(Addr+4);
        End;
       End;
      4:Begin { JMP r/m32 - near indirect }
        If Addr=-1 Then EIP:=GetReg32(RmF)
        Else EIP:=ReadDWord(Addr);
       End;
      5:Begin { JMP m16:32 - far indirect }
        If Addr=-1 Then
         WriteLn('Erreur: JMP far indirect requiert un operande memoire')
        Else Begin
         EIP:=ReadDWord(Addr);
         Segs.CS:=ReadWord(Addr+4);
        End;
       End;
      6:Begin { PUSH r/m32 }
        If Addr=-1 Then Push32(GetReg32(RmF))
        Else Push32(ReadDWord(Addr));
       End;
     Else Begin
      WriteLn('Opcode $FF /',RegF,
              ' non gere a EIP=$',HexStr(EIP,8));
      Terminated:=True;
     End;
     End;
    End;
  Else Begin
   WriteLn('Opcode non gere: $',HexStr(Op,2),' a EIP=$',HexStr(EIP,8));
   Terminated:=True;
  End;
  End; { Case Op }
 End; { While Not Terminated }
End;

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
 If VerboseMode Then
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
 If VerboseMode Then
  WriteLn('Fichier d''echange de 16 Mo cree avec succes.');
  { TODO 4 : Initialisation de la LDT (tous les descripteurs libres) }
 FillChar(LDT,SizeOf(LDT),0);
 If VerboseMode Then
  WriteLn('LDT initialisee (',LDTSize,' descripteurs).');
  { TODO 19 : Initialisation du gestionnaire de blocs memoire }
 FillChar(MemBlocks,SizeOf(MemBlocks),0);
 NextLinearAddr:=$100000;  { Debut de l'allocation a 1 Mo }
 NextHandle:=1;
 If VerboseMode Then
  WriteLn('Gestionnaire memoire initialise (',MaxMemBlocks,' blocs max).');
  { TODO 21 : Initialisation de la table des fichiers DOS }
 FillChar(DosFiles,SizeOf(DosFiles),0);
  { Handles 0-4 reserves (stdin/stdout/stderr/aux/prn) }
 For J:=0 to 4 do DosFiles[J].InUse:=True;
 DosExitCode:=0;
 Terminated:=False;
 If VerboseMode Then
  WriteLn('Table fichiers DOS initialisee (',MaxDosFiles,' handles max).');
  { TODO 9 : Initialisation de la table de parite }
 InitParityTable;
  { TODO 14 : Initialisation des prefixes }
 ResetPrefixes;
End;

  { TODO 25 : Procedure de nettoyage. Ferme et supprime le fichier
    d'echange de 16 Mo, et libere toutes les ressources (handles de
    fichiers ouverts, descripteurs LDT, blocs memoire). }
Procedure Done;
Var
 I:Integer;
 ClosedFiles:Integer;
 FreedDesc:Integer;
 FreedBlocks:Integer;
Begin
  { Etape 1 : Fermer tous les fichiers DOS ouverts (handles 5+) }
 ClosedFiles:=0;
 For I:=5 to MaxDosFiles-1 do Begin
  If DosFiles[I].InUse Then Begin
   {$I-}Close(DosFiles[I].F);{$I+}
   If IOResult<>0 Then Begin End; { Consommer IOResult pour eviter erreur sur la prochaine operation I/O }
   DosFiles[I].InUse:=False;
   Inc(ClosedFiles);
  End;
 End;
 If VerboseMode and(ClosedFiles>0)Then
  WriteLn('EMUDPMI : ',ClosedFiles,' fichier(s) DOS ferme(s).');
  { Etape 2 : Liberer tous les descripteurs LDT alloues }
 FreedDesc:=0;
 For I:=0 to LDTSize-1 do Begin
  If LDT[I].InUse Then Begin
   LDT[I].InUse:=False;
   LDT[I].BaseAddr:=0;
   LDT[I].Limit:=0;
   LDT[I].AccessType:=0;
   LDT[I].Granularity:=0;
   Inc(FreedDesc);
  End;
 End;
 If VerboseMode and(FreedDesc>0)Then
  WriteLn('EMUDPMI : ',FreedDesc,' descripteur(s) LDT libere(s).');
  { Etape 3 : Liberer tous les blocs memoire alloues }
 FreedBlocks:=0;
 For I:=0 to MaxMemBlocks-1 do Begin
  If MemBlocks[I].InUse Then Begin
   MemBlocks[I].InUse:=False;
   MemBlocks[I].BaseAddr:=0;
   MemBlocks[I].Size:=0;
   MemBlocks[I].Handle:=0;
   Inc(FreedBlocks);
  End;
 End;
 If VerboseMode and(FreedBlocks>0)Then
  WriteLn('EMUDPMI : ',FreedBlocks,' bloc(s) memoire libere(s).');
  { Etape 4 : Fermer le fichier d'echange }
 {$I-}Close(Memory);{$I+}
 If IOResult<>0 Then
  WriteLn('EMUDPMI : Avertissement - erreur lors de la fermeture du fichier d''echange.');
  { Etape 5 : Supprimer le fichier d'echange }
 {$I-}Assign(Memory,SwapFileMemory);
 Erase(Memory);{$I+}
 If IOResult<>0 Then
  WriteLn('EMUDPMI : Avertissement - impossible de supprimer le fichier d''echange.');
End;

BEGIN
  { TODO 24 : Analyser les options de ligne de commande en premier }
 ParseCommandLine;
 Init;
 If VerboseMode Then
  WriteLn('EMUDPMI : Memoire lineaire de 16 Mo initialisee.');
 If DebugMode Then
  WriteLn('EMUDPMI : Mode debogage active.');
 If VerboseMode Then
  WriteLn('EMUDPMI : Mode verbeux active.');
 If ReadOnlyMode Then
  WriteLn('EMUDPMI : Mode lecture seule active.');
  { TODO 22 : Charger un programme binaire plat si un nom de fichier
    est passe en parametre de la ligne de commande.
    TODO 24 : Ignorer les parametres commencant par '/' (options). }
 If ParamCount>=1 Then Begin
  ProgramFile:='';
  For ParamIdx:=1 to ParamCount do Begin
   If ParamStr(ParamIdx)[1]<>'/' Then Begin
    ProgramFile:=ParamStr(ParamIdx);
    Break;
   End;
  End;
  If ProgramFile<>'' Then Begin
   If LoadFlatBinary(ProgramFile) Then Begin
    If VerboseMode Then
     WriteLn('EMUDPMI : Programme charge avec succes.');
     { TODO 23 : Executer le programme charge }
    Run;
    WriteLn('EMUDPMI : Execution terminee (code de sortie: ',DosExitCode,').');
   End Else
    WriteLn('EMUDPMI : Erreur de chargement du programme.');
  End;
 End;
 Done;
 If VerboseMode Then
  WriteLn('EMUDPMI : Fichier d''echange supprime.');
END.
