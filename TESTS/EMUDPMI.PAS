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

  { TODO 9 : Instructions arithmetiques 32 bits : ADD, SUB, ADC, SBB,
    CMP, INC, DEC, NEG, MUL, IMUL, DIV, IDIV sur des operandes 32 bits
    avec mise a jour correcte des drapeaux (CF, ZF, SF, OF, AF, PF). }

  { Calcul de la parite : True si le nombre de bits a 1 dans
    l'octet est pair (PF doit etre mis a 1) }
Function CalcParity(B:Byte):Boolean;
Var
 V:Byte;
Begin
 V:=B xor(B shr 4);
 V:=V xor(V shr 2);
 V:=V xor(V shr 1);
 CalcParity:=(V and 1)=0;
End;

  { Mise a jour des drapeaux ZF, SF, PF d'apres un resultat 32 bits }
Procedure SetFlagsZSP32(Res:LongInt);
Begin
 If Res=0 Then Include(EFlags.s,ZF)
 Else Exclude(EFlags.s,ZF);
 If Res<0 Then Include(EFlags.s,SF)
 Else Exclude(EFlags.s,SF);
 If CalcParity(Byte(Res and $FF))Then Include(EFlags.s,PF)
 Else Exclude(EFlags.s,PF);
End;

  { ADD 32 bits avec mise a jour complete des drapeaux }
Function DoAdd32(A,B:LongInt):LongInt;
Var
 Res:LongInt;
Begin
 Res:=A+B;
  { CF : report du bit 31 }
 If((A and B)or((A xor B)and not Res))<0 Then Include(EFlags.s,CF)
 Else Exclude(EFlags.s,CF);
  { OF : depassement signe }
 If((not(A xor B))and(A xor Res))<0 Then Include(EFlags.s,_OF)
 Else Exclude(EFlags.s,_OF);
  { AF : report du bit 3 }
 If((A xor B xor Res)and $10)<>0 Then Include(EFlags.s,AF)
 Else Exclude(EFlags.s,AF);
 SetFlagsZSP32(Res);
 DoAdd32:=Res;
End;

  { SUB 32 bits avec mise a jour complete des drapeaux }
Function DoSub32(A,B:LongInt):LongInt;
Var
 Res:LongInt;
Begin
 Res:=A-B;
  { CF : emprunt (unsigned A < unsigned B) }
 If((not A and B)or((not(A xor B))and Res))<0 Then Include(EFlags.s,CF)
 Else Exclude(EFlags.s,CF);
  { OF : depassement signe }
 If((A xor B)and(A xor Res))<0 Then Include(EFlags.s,_OF)
 Else Exclude(EFlags.s,_OF);
  { AF : emprunt du bit 3 }
 If((A xor B xor Res)and $10)<>0 Then Include(EFlags.s,AF)
 Else Exclude(EFlags.s,AF);
 SetFlagsZSP32(Res);
 DoSub32:=Res;
End;

  { ADC 32 bits : A + B + CF }
Function DoAdc32(A,B:LongInt):LongInt;
Var
 CarryIn:LongInt;
 Res1,Res:LongInt;
 CF1:Boolean;
Begin
 If CF in EFlags.s Then CarryIn:=1 Else CarryIn:=0;
 Res1:=A+B;
 CF1:=((A and B)or((A xor B)and not Res1))<0;
 Res:=Res1+CarryIn;
 If CF1 or((CarryIn=1)and(Res1=-1))Then Include(EFlags.s,CF)
 Else Exclude(EFlags.s,CF);
 If((not(A xor B))and(A xor Res))<0 Then Include(EFlags.s,_OF)
 Else Exclude(EFlags.s,_OF);
 If((A xor B xor Res)and $10)<>0 Then Include(EFlags.s,AF)
 Else Exclude(EFlags.s,AF);
 SetFlagsZSP32(Res);
 DoAdc32:=Res;
End;

  { SBB 32 bits : A - B - CF }
Function DoSbb32(A,B:LongInt):LongInt;
Var
 BorrowIn:LongInt;
 Res1,Res:LongInt;
 CF1:Boolean;
Begin
 If CF in EFlags.s Then BorrowIn:=1 Else BorrowIn:=0;
 Res1:=A-B;
 CF1:=((not A and B)or((not(A xor B))and Res1))<0;
 Res:=Res1-BorrowIn;
 If CF1 or((BorrowIn=1)and(Res1=0))Then Include(EFlags.s,CF)
 Else Exclude(EFlags.s,CF);
 If((A xor B)and(A xor Res))<0 Then Include(EFlags.s,_OF)
 Else Exclude(EFlags.s,_OF);
 If((A xor B xor Res)and $10)<>0 Then Include(EFlags.s,AF)
 Else Exclude(EFlags.s,AF);
 SetFlagsZSP32(Res);
 DoSbb32:=Res;
End;

  { ADD r/m32, reg32 - opcode $01 }
Procedure ExecADD_Rm32_Reg32;
Var
 RegField,RmField:Byte;
 Addr,Val:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RmField,DoAdd32(GetReg32(RmField),GetReg32(RegField)))
 Else Begin
  Val:=ReadDWord(Addr);
  WriteDWord(Addr,DoAdd32(Val,GetReg32(RegField)));
 End;
End;

  { ADD reg32, r/m32 - opcode $03 }
Procedure ExecADD_Reg32_Rm32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RegField,DoAdd32(GetReg32(RegField),GetReg32(RmField)))
 Else
  SetReg32(RegField,DoAdd32(GetReg32(RegField),ReadDWord(Addr)));
End;

  { ADD EAX, imm32 - opcode $05 }
Procedure ExecADD_EAX_Imm32;
Begin
 Regs.EAX:=DoAdd32(Regs.EAX,FetchDWord);
End;

  { ADC r/m32, reg32 - opcode $11 }
Procedure ExecADC_Rm32_Reg32;
Var
 RegField,RmField:Byte;
 Addr,Val:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RmField,DoAdc32(GetReg32(RmField),GetReg32(RegField)))
 Else Begin
  Val:=ReadDWord(Addr);
  WriteDWord(Addr,DoAdc32(Val,GetReg32(RegField)));
 End;
End;

  { ADC reg32, r/m32 - opcode $13 }
Procedure ExecADC_Reg32_Rm32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RegField,DoAdc32(GetReg32(RegField),GetReg32(RmField)))
 Else
  SetReg32(RegField,DoAdc32(GetReg32(RegField),ReadDWord(Addr)));
End;

  { ADC EAX, imm32 - opcode $15 }
Procedure ExecADC_EAX_Imm32;
Begin
 Regs.EAX:=DoAdc32(Regs.EAX,FetchDWord);
End;

  { SBB r/m32, reg32 - opcode $19 }
Procedure ExecSBB_Rm32_Reg32;
Var
 RegField,RmField:Byte;
 Addr,Val:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RmField,DoSbb32(GetReg32(RmField),GetReg32(RegField)))
 Else Begin
  Val:=ReadDWord(Addr);
  WriteDWord(Addr,DoSbb32(Val,GetReg32(RegField)));
 End;
End;

  { SBB reg32, r/m32 - opcode $1B }
Procedure ExecSBB_Reg32_Rm32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RegField,DoSbb32(GetReg32(RegField),GetReg32(RmField)))
 Else
  SetReg32(RegField,DoSbb32(GetReg32(RegField),ReadDWord(Addr)));
End;

  { SBB EAX, imm32 - opcode $1D }
Procedure ExecSBB_EAX_Imm32;
Begin
 Regs.EAX:=DoSbb32(Regs.EAX,FetchDWord);
End;

  { SUB r/m32, reg32 - opcode $29 }
Procedure ExecSUB_Rm32_Reg32;
Var
 RegField,RmField:Byte;
 Addr,Val:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RmField,DoSub32(GetReg32(RmField),GetReg32(RegField)))
 Else Begin
  Val:=ReadDWord(Addr);
  WriteDWord(Addr,DoSub32(Val,GetReg32(RegField)));
 End;
End;

  { SUB reg32, r/m32 - opcode $2B }
Procedure ExecSUB_Reg32_Rm32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  SetReg32(RegField,DoSub32(GetReg32(RegField),GetReg32(RmField)))
 Else
  SetReg32(RegField,DoSub32(GetReg32(RegField),ReadDWord(Addr)));
End;

  { SUB EAX, imm32 - opcode $2D }
Procedure ExecSUB_EAX_Imm32;
Begin
 Regs.EAX:=DoSub32(Regs.EAX,FetchDWord);
End;

  { CMP r/m32, reg32 - opcode $39 }
Procedure ExecCMP_Rm32_Reg32;
Var
 RegField,RmField:Byte;
 Addr,Val:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  DoSub32(GetReg32(RmField),GetReg32(RegField))
 Else Begin
  Val:=ReadDWord(Addr);
  DoSub32(Val,GetReg32(RegField));
 End;
End;

  { CMP reg32, r/m32 - opcode $3B }
Procedure ExecCMP_Reg32_Rm32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 If Addr=-1 Then
  DoSub32(GetReg32(RegField),GetReg32(RmField))
 Else
  DoSub32(GetReg32(RegField),ReadDWord(Addr));
End;

  { CMP EAX, imm32 - opcode $3D }
Procedure ExecCMP_EAX_Imm32;
Begin
 DoSub32(Regs.EAX,FetchDWord);
End;

  { INC reg32 - opcodes $40..$47 (ne modifie pas CF) }
Procedure ExecINC_Reg32(RegIdx:Byte);
Var
 OldCF:Boolean;
Begin
 OldCF:=CF in EFlags.s;
 SetReg32(RegIdx,DoAdd32(GetReg32(RegIdx),1));
 If OldCF Then Include(EFlags.s,CF)
 Else Exclude(EFlags.s,CF);
End;

  { DEC reg32 - opcodes $48..$4F (ne modifie pas CF) }
Procedure ExecDEC_Reg32(RegIdx:Byte);
Var
 OldCF:Boolean;
Begin
 OldCF:=CF in EFlags.s;
 SetReg32(RegIdx,DoSub32(GetReg32(RegIdx),1));
 If OldCF Then Include(EFlags.s,CF)
 Else Exclude(EFlags.s,CF);
End;

  { NEG r/m32 : 0 - operande, CF=1 si operande<>0 }
Procedure ExecNEG_Rm32(RmField:Byte;Addr:LongInt);
Var
 Val,Res:LongInt;
Begin
 If Addr=-1 Then Val:=GetReg32(RmField)
 Else Val:=ReadDWord(Addr);
 Res:=DoSub32(0,Val);
 If Val<>0 Then Include(EFlags.s,CF)
 Else Exclude(EFlags.s,CF);
 If Addr=-1 Then SetReg32(RmField,Res)
 Else WriteDWord(Addr,Res);
End;

  { Multiplication non signee 32x32 -> 64 bits (HiPart:LoPart) }
Procedure UMul32x32(A,B:LongInt;Var HiPart,LoPart:LongInt);
Var
 AL_,AH_,BL_,BH_:LongInt;
 P0,P1,P2,P3:LongInt;
 Col0,Col1,Col2,Col3:LongInt;
Begin
 AL_:=A and $FFFF;
 AH_:=(A shr 16) and $FFFF;
 BL_:=B and $FFFF;
 BH_:=(B shr 16) and $FFFF;
 P0:=AL_*BL_;
 P1:=AL_*BH_;
 P2:=AH_*BL_;
 P3:=AH_*BH_;
 Col0:=P0 and $FFFF;
 Col1:=((P0 shr 16) and $FFFF)+(P1 and $FFFF)+(P2 and $FFFF);
 Col2:=((Col1 shr 16) and $FFFF)+((P1 shr 16) and $FFFF)+
       ((P2 shr 16) and $FFFF)+(P3 and $FFFF);
 Col3:=((Col2 shr 16) and $FFFF)+((P3 shr 16) and $FFFF);
 LoPart:=Col0 or((Col1 and $FFFF) shl 16);
 HiPart:=(Col2 and $FFFF)or((Col3 and $FFFF) shl 16);
End;

  { Negation d'un nombre 64 bits (HiPart:LoPart) }
Procedure Negate64(Var HiPart,LoPart:LongInt);
Var
 OldLo:LongInt;
Begin
 OldLo:=LoPart;
 LoPart:=(not LoPart)+1;
 If OldLo=0 Then HiPart:=(not HiPart)+1
 Else HiPart:=not HiPart;
End;

  { MUL r/m32 - opcode $F7 /4 : EDX:EAX = EAX * r/m32 (non signe) }
Procedure ExecMUL_Rm32(RmField:Byte;Addr:LongInt);
Var
 Val,HiPart,LoPart:LongInt;
Begin
 If Addr=-1 Then Val:=GetReg32(RmField)
 Else Val:=ReadDWord(Addr);
 UMul32x32(Regs.EAX,Val,HiPart,LoPart);
 Regs.EAX:=LoPart;
 Regs.EDX:=HiPart;
 If HiPart<>0 Then Begin
  Include(EFlags.s,CF);Include(EFlags.s,_OF);
 End Else Begin
  Exclude(EFlags.s,CF);Exclude(EFlags.s,_OF);
 End;
 SetFlagsZSP32(LoPart);
End;

  { IMUL r/m32 - opcode $F7 /5 : EDX:EAX = EAX * r/m32 (signe) }
Procedure ExecIMUL_Rm32(RmField:Byte;Addr:LongInt);
Var
 Val,HiPart,LoPart:LongInt;
 NegResult:Boolean;
 A,B:LongInt;
Begin
 If Addr=-1 Then Val:=GetReg32(RmField)
 Else Val:=ReadDWord(Addr);
 A:=Regs.EAX;
 B:=Val;
 NegResult:=False;
 If A<0 Then Begin A:=-A;NegResult:=not NegResult;End;
 If B<0 Then Begin B:=-B;NegResult:=not NegResult;End;
 UMul32x32(A,B,HiPart,LoPart);
 If NegResult Then Negate64(HiPart,LoPart);
 Regs.EAX:=LoPart;
 Regs.EDX:=HiPart;
  { CF=OF=1 si le resultat ne tient pas dans 32 bits signes }
 If((LoPart>=0)and(HiPart<>0))or
   ((LoPart<0)and(HiPart<>-1))Then Begin
  Include(EFlags.s,CF);Include(EFlags.s,_OF);
 End Else Begin
  Exclude(EFlags.s,CF);Exclude(EFlags.s,_OF);
 End;
 SetFlagsZSP32(LoPart);
End;

  { Division non signee 64 / 32 bits.
    Algorithme de division binaire restaurante bit a bit. }
Procedure UDiv64x32(DivHi,DivLo,Divisor:LongInt;
                    Var Quotient,Remainder:LongInt);
Var
 I:Integer;
 R:LongInt;
 RHigh:Boolean;
Begin
 If Divisor=0 Then Begin
  WriteLn('Erreur: division par zero');
  Quotient:=0;Remainder:=0;
  Exit;
 End;
 R:=0;RHigh:=False;
 Quotient:=0;
 For I:=63 downto 0 do Begin
   { Decaler le reste a gauche de 1 bit }
  RHigh:=R<0;
  R:=R shl 1;
   { Injecter le prochain bit du dividende }
  If I>=32 Then Begin
   If(DivHi and(LongInt(1) shl(I-32)))<>0 Then R:=R or 1;
  End Else Begin
   If(DivLo and(LongInt(1) shl I))<>0 Then R:=R or 1;
  End;
   { Si reste >= diviseur (comparaison non signee via XOR $80000000
     qui convertit la comparaison signee en non signee), soustraire }
  If RHigh or(((R xor LongInt($80000000))>=(Divisor xor LongInt($80000000))))Then Begin
   R:=R-Divisor;
   RHigh:=False;
   If I<32 Then Quotient:=Quotient or(LongInt(1) shl I);
  End;
 End;
 Remainder:=R;
End;

  { DIV r/m32 - opcode $F7 /6 :
    EAX = EDX:EAX / r/m32 (quotient),
    EDX = EDX:EAX mod r/m32 (reste) }
Procedure ExecDIV_Rm32(RmField:Byte;Addr:LongInt);
Var
 Val,Quot,Rem:LongInt;
Begin
 If Addr=-1 Then Val:=GetReg32(RmField)
 Else Val:=ReadDWord(Addr);
 If Val=0 Then Begin
  WriteLn('Erreur: division par zero (DIV)');
  Exit;
 End;
 UDiv64x32(Regs.EDX,Regs.EAX,Val,Quot,Rem);
 Regs.EAX:=Quot;
 Regs.EDX:=Rem;
End;

  { IDIV r/m32 - opcode $F7 /7 :
    EAX = EDX:EAX / r/m32 (quotient signe),
    EDX = EDX:EAX mod r/m32 (reste, signe du dividende) }
Procedure ExecIDIV_Rm32(RmField:Byte;Addr:LongInt);
Var
 Val,Quot,Rem:LongInt;
 DivHi,DivLo:LongInt;
 NegQuot,NegRem:Boolean;
Begin
 If Addr=-1 Then Val:=GetReg32(RmField)
 Else Val:=ReadDWord(Addr);
 If Val=0 Then Begin
  WriteLn('Erreur: division par zero (IDIV)');
  Exit;
 End;
 DivHi:=Regs.EDX;DivLo:=Regs.EAX;
 NegQuot:=False;NegRem:=False;
 If DivHi<0 Then Begin
  NegQuot:=not NegQuot;NegRem:=True;
  Negate64(DivHi,DivLo);
 End;
 If Val<0 Then Begin
  NegQuot:=not NegQuot;
  Val:=-Val;
 End;
 UDiv64x32(DivHi,DivLo,Val,Quot,Rem);
 If NegQuot Then Quot:=-Quot;
 If NegRem Then Rem:=-Rem;
 Regs.EAX:=Quot;
 Regs.EDX:=Rem;
End;

  { Groupe $F7 : NEG/MUL/IMUL/DIV/IDIV r/m32 }
Procedure ExecGrp3_32;
Var
 RegField,RmField:Byte;
 Addr:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 Case RegField of
  3:ExecNEG_Rm32(RmField,Addr);
  4:ExecMUL_Rm32(RmField,Addr);
  5:ExecIMUL_Rm32(RmField,Addr);
  6:ExecDIV_Rm32(RmField,Addr);
  7:ExecIDIV_Rm32(RmField,Addr);
 Else
  WriteLn('Erreur: opcode $F7 /',RegField,' non implemente');
 End;
End;

  { Groupe $81 : ADD/ADC/SBB/SUB/CMP r/m32, imm32 }
Procedure ExecGrp1_Rm32_Imm32;
Var
 RegField,RmField:Byte;
 Addr,Val,Imm:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 Imm:=FetchDWord;
 If Addr=-1 Then Val:=GetReg32(RmField)
 Else Val:=ReadDWord(Addr);
 Case RegField of
  0:Val:=DoAdd32(Val,Imm);
  2:Val:=DoAdc32(Val,Imm);
  3:Val:=DoSbb32(Val,Imm);
  5:Val:=DoSub32(Val,Imm);
  7:Begin DoSub32(Val,Imm);Exit;End;
 Else Begin
  WriteLn('Erreur: opcode $81 /',RegField,' non implemente');
  Exit;
 End;
 End;
 If Addr=-1 Then SetReg32(RmField,Val)
 Else WriteDWord(Addr,Val);
End;

  { Groupe $83 : ADD/ADC/SBB/SUB/CMP r/m32, imm8 (signe etendu) }
Procedure ExecGrp1_Rm32_Imm8;
Var
 RegField,RmField:Byte;
 Addr,Val,Imm:LongInt;
Begin
 Addr:=DecodeModRM32(RegField,RmField);
 Imm:=ShortInt(FetchByte);
 If Addr=-1 Then Val:=GetReg32(RmField)
 Else Val:=ReadDWord(Addr);
 Case RegField of
  0:Val:=DoAdd32(Val,Imm);
  2:Val:=DoAdc32(Val,Imm);
  3:Val:=DoSbb32(Val,Imm);
  5:Val:=DoSub32(Val,Imm);
  7:Begin DoSub32(Val,Imm);Exit;End;
 Else Begin
  WriteLn('Erreur: opcode $83 /',RegField,' non implemente');
  Exit;
 End;
 End;
 If Addr=-1 Then SetReg32(RmField,Val)
 Else WriteDWord(Addr,Val);
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
