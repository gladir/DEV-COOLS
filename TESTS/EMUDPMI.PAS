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

  { Pointeur d'instruction 32 bits }
 EIP:LongInt;

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

  { Decodage du ModR/M en mode 32 bits. Retourne l'adresse effective
    lineaire si Mod<>11b, ou -1 si l'operande est un registre (Mod=11b).
    RegField recoit le champ reg (bits 5..3).
    RmField recoit le champ r/m (bits 2..0). }
Function DecodeModRM32(Var RegField,RmField:Byte):LongInt;
Var
 ModRM,_Mod,SIB,Base,Index,Scale:Byte;
 Addr:LongInt;
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
 If RmField=4 Then Begin
   { SIB byte present }
  SIB:=FetchByte;
  Base:=SIB and 7;
  Index:=(SIB shr 3) and 7;
  Scale:=(SIB shr 6) and 3;
   { Adresse de base }
  If(Base=5)and(_Mod=0)Then
   Addr:=FetchDWord  { [disp32+scaled index] }
  Else
   Addr:=GetReg32(Base);
   { Index echelonne (sauf si index=4 => pas d'index) }
  If Index<>4 Then
   Addr:=Addr+(GetReg32(Index) shl Scale);
 End Else If(RmField=5)and(_Mod=0)Then
  Addr:=FetchDWord  { [disp32] direct }
 Else
  Addr:=GetReg32(RmField);
  { Deplacement }
 Case _Mod of
  1:Addr:=Addr+ShortInt(FetchByte);  { disp8 signe }
  2:Addr:=Addr+FetchDWord;            { disp32 }
 End;
  { Conversion en adresse lineaire via DS par defaut }
 DecodeModRM32:=SelOfsToLinear(Segs.DS,Addr);
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

  { Groupe 1 : r/m32, imm32 - opcode $81
    Le champ reg du ModR/M determine l'operation :
    /0=ADD, /1=OR(TODO10), /2=ADC, /3=SBB,
    /4=AND(TODO10), /5=SUB, /6=XOR(TODO10), /7=CMP }
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
  2:Val:=ArithAdc32(Val,Imm);
  3:Val:=ArithSbb32(Val,Imm);
  5:Val:=ArithSub32(Val,Imm);
  7:Begin ArithCmp32(Val,Imm);Exit;End;
 Else Begin
  WriteLn('Erreur: Grp1/$81 reg=',RegField,' non implemente (TODO 10)');
  Exit;
 End;
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
  2:Val:=ArithAdc32(Val,Imm);
  3:Val:=ArithSbb32(Val,Imm);
  5:Val:=ArithSub32(Val,Imm);
  7:Begin ArithCmp32(Val,Imm);Exit;End;
 Else Begin
  WriteLn('Erreur: Grp1/$83 reg=',RegField,' non implemente (TODO 10)');
  Exit;
 End;
 End;
 If Addr=-1 Then SetReg32(RmField,Val)
            Else WriteDWord(Addr,Val);
End;

  { Groupe 3 : r/m32 - opcode $F7
    Le champ reg du ModR/M determine l'operation :
    /0=TEST(TODO10), /1=TEST(TODO10), /2=NOT(TODO10), /3=NEG,
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
  3:Begin
    Val:=ArithNeg32(Val);
    If Addr=-1 Then SetReg32(RmField,Val)
               Else WriteDWord(Addr,Val);
   End;
  4:ArithMul32(Val);
  5:ArithIMul32(Val);
  6:ArithDiv32(Val);
  7:ArithIDiv32(Val);
 Else
  WriteLn('Erreur: Grp3/$F7 reg=',RegField,' non implemente (TODO 10)');
 End;
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
  { TODO 4 : Initialisation de la LDT (tous les descripteurs libres) }
 FillChar(LDT,SizeOf(LDT),0);
 WriteLn('LDT initialisee (',LDTSize,' descripteurs).');
  { TODO 9 : Initialisation de la table de parite }
 InitParityTable;
End;

Procedure Done;Begin
 Close(Memory);
 {$I-}Assign(Memory,SwapFileMemory);
 Erase(Memory);{$I+}
End;

BEGIN
 Init;
 WriteLn('EMUDPMI : Memoire lineaire de 16 Mo initialisee.');
 Done;
 WriteLn('EMUDPMI : Fichier d''echange supprime.');
END.
