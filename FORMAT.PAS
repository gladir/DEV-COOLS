{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2022
  @website(https://www.gladir.com/corail)
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program Format;

{$A-,F-,O-}

Uses DOS;

Const
 MaxFormatFATBytes=4608;
 DOS_MSDOS=0;DOS_PCDOS=1;DOS_DRDOS=2;DOS_FREEDOS=3;DOS_RXDOS=4;
 DOS_WIN95=5;DOS_PTSDOS=6;DOS_OS2=7;DOS_WINNT=8;
 {Adresse d'assembleur pour le micro-processeur Intel (Cpu Intel)}
 ciBXnSI=$00;{"[BX+SI]",88+}
 ciBXnDI=$01;{"[BX+DI]",88+}
 ciBPnSI=$02;{"[BP+SI]",88+}
 ciBPnDI=$03;{"[BP+DI]",88+}
 ciSI=$04;{"[SI]",88+}
 ciDI=$05;{"[DI]",88+}
 ciBP=$06;{"[BP]",88+}
 ciBX=$07;{"[BX]",88+}
 {Instruction d'assembleur pour le micro-processeur Intel (Cpu Intel)}
 ciAAA=$37;{"AAA",88+}
 ciAAD_=$D5;{"AAD",88+}
 ciAAM_=$D4;{"AAM",88+}
 ciAAS=$3F;{"AAS",88+}
 ciAdcAL_=$14;{"ADC AL,??h",286+}
 ciAdcAX_=$15;{"ADC AX,????h",286+}
 ciAddAL_=$04;{"ADD AL,??h",286+}
 ciAddAX_=$05;{"ADD AX,????h",286+}
 ciAndAL_=$24;{"AND AL,??h",286+}
 ciAndAX_=$25;{"AND AX,????h",286+}
 ciCallFarAbs=$9A;{"CALL FAR ????h:????h",88+}
 ciCBW=$98;{"CBW",88+}
 ciCC=$CC;{"INT 03h"(Code Special CCh),88+}
 ciCLC=$F8;{"CLC",88+}
 ciCLD=$FC;{"CLD",88+}
 ciCLI=$FA;{"CLI",88+}
 ciCMC=$F5;{"CMC",88+}
 ciCmpAL_=$3C;{"CMP AL,??h",286+}
 ciCmpAX_=$3D;{"CMP AX,????h",286+}
 ciCmpSB=$A6;{"CMPSB",88+}
 ciCmpSW=$A7;{"CMPSW",88+}
 ciCS=$2E;{"CS",88+}
 ciCWD=$99;{"CWD",88+}
 ciDAA=$27;{"DAA",88+}
 ciDAS=$2F;{"DAS",88+}
 ciDecAX=$48;{"DEC AX",88+}
 ciDecBP=$4D;{"DEC BP",88+}
 ciDecBX=$4B;{"DEC BX",88+}
 ciDecCX=$49;{"DEC CX",88+}
 ciDecDI=$4F;{"DEC DI",88+}
 ciDecDX=$4A;{"DEC DX",88+}
 ciDecSI=$4E;{"DEC SI",88+}
 ciDecSP=$4C;{"DEC SP",88+}
 ciDS=$3E;{"DS",88+}
 ciES=$26;{"ES",88+}
 ciFS=$64;{"FS",386+}
 ciGS=$65;{"GS",386+}
 ciHLT=$F4;{"HLT",88+}
 ciIncAX=$40;{"INC AX",88+}
 ciIncBP=$45;{"INC BP",88+}
 ciIncBX=$43;{"INC BX",88+}
 ciIncCX=$41;{"INC CX",88+}
 ciIncDI=$47;{"INC DI",88+}
 ciIncDX=$42;{"INC DX",88+}
 ciIncSI=$46;{"INC SI",88+}
 ciIncSP=$44;{"INC SP",88+}
 ciInsB=$6C;{"INSB",88+}
 ciInsW=$6D;{"INSW",88+}
 ciInt=$CD;{"INT ??h",88+}
 ciIntO=$CE;{"INTO",88+}
 ciIRet=$CF;{"IRET",88+}
 ciJBE=$76;{"JBE ?",88+}
 ciJC=$72;{"JC ?",88+}
 ciJG=$7E;{"JG ?",88+}
 ciJL=$7C;{"JL ?",88+}
 ciJMP_Word=$E9;{"JMP ????",88+}
 ciJNBE=$77;{"JNBE ?",88+}
 ciJNC=$73;{"JNC ?",88+}
 ciJNG=$7F;{"JNG ?",88+}
 ciJNL=$7D;{"JNL ?",88+}
 ciJNO=$71;{"JNO ?",88+}
 ciJNP=$7B;{"JNP ?",88+}
 ciJNS=$79;{"JNS ?",88+}
 ciJNZ=$75;{"JNZ ?",88+}
 ciJO=$70;{"JO ?",88+}
 ciJP=$7A;{"JP ?",88+}
 ciJS=$78;{"JS ?",88+}
 ciJZ=$74;{"JZ ?",88+}
 ciLAHF=$9F;{"LAHF",88+}
 ciLAR=$020F;{"LAR",386+}
 ciLeave=$C9;{"LEAVE",286+}
 ciLDS=$C5;{"LDS reg,mem",88+}
 ciLES=$C4;{"LES reg,mem",88+}
 ciLFS=$B40F;{"LFS reg,mem",386+}
 ciLGS=$B50F;{"LGS reg,mem",386+}
 ciLock=$F0;{"LOCK ?",88+}
 ciLODSB=$AC;{"LODSB",88+}
 ciLODSD=$AD66;{"LODSD",386+}
 ciLODSW=$AD;{"LODSW",88+}
 ciLSL=$030F;{"LSL ?",386+}
 ciLSS=$B20F;{"LSS reg,mem",386+}
 ciMovAL_=$A0;{"MOV AL,[addr]",286+}
 ciMovAL_Byte=$B0;{"MOV AL,??",88+}
 ciMovAX_=$A1;{"MOV AX,[addr]",286+}
 ciMovAX_Word=$B8;{"MOV AX,????", 88+}
 ciMovAH_AL=$E08A;{"MOV AH,AL",88+}
 ciMovBP_SP=$EC8B;{"MOV BP,SP",88+}
 ciMovBX_CX=$D98B;{"MOV BX,CX",88+}
 ciMovCX_BX=$CB8B;{"MOV CX,BX",88+}
 ciMovDX_Word=$BA;{"MOV DX,????",88+}
 ciMovEAX_ES_DI=$058B6626;{"MOV EAX,ES:[DI]",386+}
 ciMovES_DI_EAX=$05896626;{"MOV ES:[DI],EAX",386+}
 ciMovSB=$A4;{"MOVSB",88+}
 ciMovSD=$A566;{"MOVSD",386+}
 ciMovSW=$A5;{"MOVSW",88+}
 ciNOP=$90;{"NOP"»,88+}
 ciOutDX_AL=$EE;{"OUT DX,AL",88+}
 ciOutDX_AX=$EF;{"OUT DX,AX",88+}
 ciOutSB=$6E;{"OUTSB",286+}
 ciOutSD=$6F66;{"OUTSD",386+}
 ciOutSW=$6F;{┬«OUTSW┬»,286+}
 ciPopAX=$58;{┬«POP AX┬»,88+}
 ciPopBP=$5D;{┬«POP BP┬»,88+}
 ciPopBX=$5B;{┬«POP BX┬»,88+}
 ciPopCX=$59;{┬«POP CX┬»,88+}
 ciPopDX=$5A;{┬«POP DX┬»,88+}
 ciPopDI=$5F;{┬«POP DI┬»,88+}
 ciPopDS=$1F;{┬«POP DS┬»,88+}
 ciPopEAX=$5866;{┬«POP EAX┬»,386+}
 ciPopEBX=$5B66;{┬«POP EBX┬»,386+}
 ciPopECX=$5966;{┬«POP ECX┬»,386+}
 ciPopEDI=$66+(ciPopDI shl 8);{┬«PUSH EDI┬»,386+}
 ciPopEDX=$5A66;{┬«POP EDX┬»,386+}
 ciPopFS=$A10F;{┬«PUSH FS┬»,386+}
 ciPopGS=$A90F;{┬«PUSH GS┬»,386+}
 ciPopES=$07;{┬«POP ES┬»,88+}
 ciPopSI=$5E;{┬«POP SI┬»,88+}
 ciPopSP=$5C;{┬«POP SP┬»,88+}
 ciPopSS=$17;{┬«POP SS┬»,88+}
 ciPopA=$61;{┬«POPA┬»,286+}
 ciPopF=$9D;{┬«POPF┬»,88+}
 ciPushA=$60;{┬«PUSHA┬»,286+}
 ciPushAX=$50;{┬«PUSH AX┬»,88+}
 ciPushBP=$55;{┬«PUSH BP┬»,88+}
 ciPushBX=$53;{┬«PUSH BX┬»,88+}
 ciPushCS=$0E;{┬«PUSH CS┬»,88+}
 ciPushCX=$51;{┬«PUSH CX┬»,88+}
 ciPushDI=$57;{┬«PUSH DI┬»,88+}
 ciPushDS=$1E;{┬«PUSH DS┬»,88+}
 ciPushDX=$52;{┬«PUSH DX┬»,88+}
 ciPushEAX=$5066;{┬«PUSH EAX┬»,386+}
 ciPushEBX=$5366;{┬«PUSH EBX┬»,386+}
 ciPushECX=$5166;{┬«PUSH ECX┬»,386+}
 ciPushEDX=$5266;{┬«PUSH EDX┬»,386+}
 ciPushEDI=$66+(ciPushDI shl 8);{┬«PUSH EDI┬»,386+}
 ciPushES=$06;{┬«PUSH ES┬»,88+}
 ciPushFS=$A00F;{┬«PUSH FS┬»,386+}
 ciPushGS=$A80F;{┬«PUSH GS┬», 386+}
 ciPushMemB=$6A;{┬«PUSH ??┬», 286+}
 ciPushSI=$56;{┬«PUSH SI┬»,88+}
 ciPushSP=$54;{┬«PUSH SP┬»,88+}
 ciPushSS=$16;{┬«PUSH SS┬»,88+}
 ciPushF=$9C;{┬«PUSHF┬»,88+}
 ciRepNZ=$F2;{┬«REPNZ ?┬»,88+}
 ciRep=$F3;{┬«REP ?┬»,88+}
 ciRetF=$CB;{┬«RETF┬»,88+}
 ciRetN=$C3;{┬«RETN┬»,88+}
 ciRet=ciRetN;{┬«RETN┬»ou┬«RETF┬»,88+}
 ciSAHF=$9E;{┬«SAHF┬»,88+}
 ciSbbAL_=$1C;{┬«SBB AL,??h┬»,286+}
 ciSbbAX_=$1D;{┬«SBB AX,????h┬»,286+}
 ciSCASB=$AE;{┬«SCASB┬»,88+}
 ciSCASD=$AF66;{┬«SCASS┬»,386+}
 ciSCASW=$AF;{┬«SCASW┬»,88+}
 ciSHR_AX_=$E8C1;{┬«SHR AX,?┬»,88+}
 ciSHR_CX_=$E9C1;{┬«SHR CX,?┬»,88+}
 ciSubAL_=$2C;{ ┬«SUB AL,??h┬»,286+}
 ciSubAX_=$2D;{┬«SUB AX,????h┬»,286+}
 ciSS=$36;{┬«SS┬»,88+}
 ciSTC=$F9;{┬«STC┬»,88+}
 ciSTD=$FD;{┬«STD┬»,88+}
 ciSTI=$FB;{┬«STI┬»,88+}
 ciSTOSB=$AA;{┬«STOSB┬»,88+}
 ciSTOSD=$AB66;{┬«STOSD┬»,386+}
 ciSTOSW=$AB;{┬«STOSW┬»,88+}
 ciXchgAXnBP=$95;{┬«XCHG AX,BP┬»,88+}
 ciXchgAXnBX=$93;{┬«XCHG AX,BX┬»,88+}
 ciXchgAXnCX=$91;{┬«XCHG AX,CX┬»,88+}
 ciXchgAXnDI=$97;{┬«XCHG AX,DI┬»,88+}
 ciXchgAXnDX=$92;{┬«XCHG AX,DX┬»,88+}
 ciXchgAXnSI=$96;{┬«XCHG AX,SI┬»,88+}
 ciXchgAXnSP=$94;{┬«XCHG AX,SP┬»,88+}
 ciXchgEAX_DS_SI=$048B663E;{┬«XCHG EAX,DS:[SI]┬»,386+}
 ciXlat=$D7;{┬«XLAT┬»,88+}
 ciXOR_=$81;{┬«XOR ?,?┬»,88+}
 ciXOR_AL_=$34;{┬«XOR AL,??h┬»,286+}
 ciXOR_AX_=$35;{┬«XOR AX,????h┬»,286+}

Const
 {Constante de type de disque (Interruption 13h)}
 dtNoDrive=0;{Lecteur introuvable}
 dtDD525=1;{Lecteur: 5,25" Double DensitΓÇÜ}
 dtHD525=2;{Lecteur: 5,25" Haute DensitΓÇÜ}
 dtDD35=3;{Lecteur: 3,5" Double DensitΓÇÜ}
 dtHD35=4;{Lecteur: 3,5" Haute DensitΓÇÜ}

 {Officieusement...}
 dTryMax=5;{Nombre d'essais maximal}

Type
 {Structure pour une piste double densitΓÇÜ}
 DdptType=Array[0..10]of Byte;
 DdptPtr=^DdptType;
 {Param┼átres physiques de formatage}
 PhysDataType=Record
  Faces,        {Nombre de faces demandΓÇÜ}
  Tracks,       {Nombre Pistes par Face}
  Sec:Byte;     {Secteurs par Piste}
  DDPT:DdptPtr; {Pointeur sur table param┼átres du lecteur de disquette}
 End;

Type
 {Param┼átres de formatage DOS}
 LogDataType=Record
  Media,Cluster,{Octet de support/Nombre Secteurs par Cluster}
  FAT,RootSize:Byte;{Nombre Secteurs pour la FAT/EntrΓÇÜes dans le rΓÇÜpertoire racine}
 End;

 {Structure d'un tampon d'une piste logique de format DOS}
 TrackBufType=Array[1..36,0..511]of Byte;{Tampon par piste}
 TFatBuffer=Array[0..MaxFormatFATBytes-1]of Byte;
 PFatBuffer=^TFatBuffer;
 TSectorBuffer=Array[0..511]of Byte;

 (*Fonctions et Procedures:*)
{$IFDEF FPC}
 Procedure DskReset;Begin
 End;
{$ELSE}
 Procedure DskReset;Assembler;ASM
  MOV AH,00h
  MOV DL,0
  INT 13h
 END;
{$ENDIF}

{$IFDEF FPC}
 Function GetDrvType(Drive:Byte):Byte;Begin
 End;
{$ELSE}
 Function GetDrvType(Drive:Byte):Byte;Assembler;ASM
  MOV AH,08h
  MOV DL,Drive
  INT 13h
  JNC @Ok
  MOV BL,dtDD525
@Ok:
  XCHG AX,BX
 END;
{$ENDIF}

Const
  fCarry=$0001;
  fParity=$0004;
  fAuxiliary=$0010;
  fZero=$0040;
  fSign=$0080;
  fOverflow=$0800;

Const

  MaskBoot:Array[1..102]of Byte=
   ($EB,$35,                { 0000   JMP 0037        }
    ciNOP,                  { 0002   NOP             }
  {-- Donnees des BPB --------------------------------}
    $50,$43,$2D,$4D,$41,$4C,$54,$45,
    $00,$00,$00,$01,$00,$00,$00,$00,
    $00,$00,$00,$00,$00,$00,$00,$00,
    $00,$00,$00,$00,$00,$00,$00,$00,
    $00,$00,$00,$00,$00,$00,$00,$00,
    $00,$00,$00,$00,$00,$00,$00,$00,
    $00,$00,$00,$00,
  {-- Programme de chargement ----------------------}
    ciCLI,                 { 0037   CLI             }
    $B8,$30,$00,           { 0038   MOV     AX,0030 }
    $8E,$D0,               { 003B   MOV     SS,AX   }
    $BC,$FC,$00,           { 003D   MOV     SP,00FC }
    ciSTI,                 { 0040   STI             }
    ciPushCS,              { 0041   PUSH    CS      }
    ciPopDS,               { 0042   POP     DS      }
    $BE,$66,$7C,           { 0043   MOV     SI,7C66 }
    $B4,$0E,               { 0046   MOV     AH,0E   }
    ciCLD,                 { 0048   CLD             }
    ciLODSB,               { 0049   LODSB           }
    $0A,$C0,               { 004A   OR      AL,AL   }
    $74,$04,               { 004C   JZ      0052    }
    ciInt,$10,             { 004E   INT     10      }
    $EB,$F7,               { 0050   JMP     0049    }
    $B4,$01,               { 0052   MOV     AH,01   }
    ciInt,$16,             { 0054   INT     16      }
    $74,$06,               { 0056   JZ      005E    }
    $B4,$00,               { 0058   MOV     AH,00   }
    ciInt,$16,             { 005A   INT     16      }
    $EB,$F4,               { 005C   JMP     0052    }
    $B4,$00,               { 005E   MOV     AH,00   }
    ciInt,$16,             { 0060   INT     16      }
    $33,$D2,               { 0062   XOR     DX,DX   }
    ciInt,$19);            { 0064   INT     19      }

 BootMsg:String=#13#10'FORMAT - corail'#13#10+
       #13#10'Disquette non systeme ou defectueuse!'#13#10+
       'Veuillez changer de disquette et taper une touche'#13#10;

 DDPT360:DdptType=($DF,$02,$25,$02,$09,$2A,$FF,$50,$F6,$0F,$08);
 DDPT160:DdptType=($DF,$02,$25,$02,$08,$2A,$FF,$50,$F6,$0F,$08);
 DDPT180:DdptType=($DF,$02,$25,$02,$09,$2A,$FF,$50,$F6,$0F,$08);
 DDPT320:DdptType=($DF,$02,$25,$02,$08,$2A,$FF,$50,$F6,$0F,$08);
 DDPT1200:DdptType=($DF,$02,$25,$02,$0F,$1B,$FF,$54,$F6,$0F,$08);
 DDPT720:DdptType=($DF,$02,$25,$02,$09,$2A,$FF,$50,$F6,$0F,$08);
 DDPT1440:DdptType=($DF,$02,$25,$02,$12,$1B,$FF,$6C,$F6,$0F,$08);
 DDPT2880:DdptType=($DF,$02,$25,$02,$24,$1B,$FF,$54,$F6,$0F,$08);
 LOG160:LogDataType=(Media:$FE;Cluster:1;FAT:1;RootSize:$40);
 LOG180:LogDataType=(Media:$FC;Cluster:1;FAT:2;RootSize:$40);
 LOG320:LogDataType=(Media:$FF;Cluster:2;FAT:1;RootSize:$70);
 LOG360:LogDataType=(Media:$FD;Cluster:2;FAT:2;RootSize:$70);
 LOG1200:LogDataType=(Media:$F9;Cluster:1;FAT:7;RootSize:$E0);
 LOG720:LogDataType=(Media:$F9;Cluster:2;FAT:3;RootSize:$70);
 LOG1440:LogDataType=(Media:$F0;Cluster:1;FAT:9;RootSize:$E0);
 LOG2880:LogDataType=(Media:$F0;Cluster:2;FAT:9;RootSize:$E0);
 PHYS160:PhysDataType=(Faces:1;Tracks:40;Sec:8;DDPT:@DDPT160);
 PHYS180:PhysDataType=(Faces:1;Tracks:40;Sec:9;DDPT:@DDPT180);
 PHYS320:PhysDataType=(Faces:2;Tracks:40;Sec:8;DDPT:@DDPT320);
 PHYS360:PhysDataType=(Faces:2;Tracks:40;Sec:9;DDPT:@DDPT360);
 PHYS1200:PhysDataType=(Faces:2;Tracks:80;Sec:15; DDPT:@DDPT1200);
 PHYS1440:PhysDataType=(Faces:2;Tracks:80;Sec:18; DDPT:@DDPT1440);
 PHYS720:PhysDataType=(Faces:2;Tracks:80;Sec:9;DDPT:@DDPT720);
 PHYS2880:PhysDataType=(Faces:2;Tracks:80;Sec:36;DDPT:@DDPT2880);

Var
 Language:(_French,_English,_Germany,_Italian,_Spain);
 TmpLanguage:String;
 AktDrv:Byte;       { Numero de l'unite de disque a formater 0, 1 }
 AktDrvType:Byte;   { Type du lecteur de disquettes courant }
 PData:PhysDataType;{ Informations physiques de formatage }
 LData:LogDataType; { Informations logiques de formatage }
 AncDDPT:Pointer;   { Pointeur sur ancien DDPT }
 Ok:Boolean;        { Drapeau pour execution du programme }
 EndCode:Word;      { Valeur retournee au process appele }
 Param:String;      { pour evaluation de la ligne de commande }
 ImageName:String;
 FileImg:File;
 InFile:Boolean;
 KS:Word;
 VolumeLabel:String;
 ForceFormat,NoVerify,UnconditionalFormat,QuickFormat,TracksSpecified,SectorsSpecified:Boolean;
 RequestedTracks,RequestedSectors:Byte;
 SystemTransfer:Boolean;
 ExistingQuickImage:Boolean;
 DosFamily,SysFileCount:Byte;
 SysFiles:Array[1..3]of String;

Function StrToUpper(S:String):String;
Var
 I:Byte;
 SLen:Byte Absolute S;
Begin
 For I:=1to(SLen)do S[I]:=UpCase(S[I]);
 StrToUpper:=S;
End;

Function SetVolumeLabel(S:String):Boolean;
Var I:Byte;
Begin
 SetVolumeLabel:=False;
 If Length(S)>11Then Begin
  WriteLn('Le nom de volume ne peut pas depasser 11 caracteres.');Exit
 End;
 If S=''Then Begin WriteLn('Le nom de volume ne peut pas etre vide.');Exit End;
 For I:=1to Length(S)do Begin
  If(Ord(S[I])<32)or(S[I]in['"','*','+',',','.','/',':',';','<','=','>','?','[','\',']','|'])Then Begin
   WriteLn('Caractere interdit dans le nom de volume: ',S[I]);Exit
  End;
  S[I]:=UpCase(S[I])
 End;
 While Length(S)<11do S:=S+' ';
 VolumeLabel:=S;SetVolumeLabel:=True
End;

Procedure SetupSystemFamily(Family:Byte);
Begin
 DosFamily:=Family;SysFiles[1]:='';SysFiles[2]:='';SysFiles[3]:='';
 Case Family of
  DOS_MSDOS,DOS_WIN95:Begin
   SysFiles[1]:='IO.SYS';SysFiles[2]:='MSDOS.SYS';SysFiles[3]:='COMMAND.COM';SysFileCount:=3
  End;
  DOS_PCDOS,DOS_DRDOS:Begin
   SysFiles[1]:='IBMBIO.COM';SysFiles[2]:='IBMDOS.COM';SysFiles[3]:='COMMAND.COM';SysFileCount:=3
  End;
  DOS_FREEDOS:Begin SysFiles[1]:='KERNEL.SYS';SysFiles[2]:='COMMAND.COM';SysFileCount:=2 End;
  DOS_RXDOS:Begin
   SysFiles[1]:='RXDOSBIO.SYS';SysFiles[2]:='RXDOS.SYS';SysFiles[3]:='COMMAND.COM';SysFileCount:=3
  End;
  DOS_PTSDOS:Begin
   SysFiles[1]:='PTSBIO.SYS';SysFiles[2]:='PTSDOS.SYS';SysFiles[3]:='COMMAND.COM';SysFileCount:=3
  End;
  DOS_OS2:Begin SysFiles[1]:='OS2BOOT';SysFiles[2]:='OS2LDR';SysFiles[3]:='OS2KRNL';SysFileCount:=3 End;
  DOS_WINNT:Begin
   SysFiles[1]:='NTLDR';SysFiles[2]:='NTDETECT.COM';SysFiles[3]:='BOOT.INI';SysFileCount:=3
  End
 End
End;

Function ParseSystemFamily(S:String):Boolean;
Var U:String;
Begin
 U:=StrToUpper(S);ParseSystemFamily:=True;
 If(U='MS-DOS')or(U='MSDOS')or(U='MS')Then SetupSystemFamily(DOS_MSDOS)
 Else If(U='PC-DOS')or(U='PCDOS')or(U='PC')or(U='IBM')Then SetupSystemFamily(DOS_PCDOS)
 Else If(U='DR-DOS')or(U='DRDOS')or(U='DR')Then SetupSystemFamily(DOS_DRDOS)
 Else If(U='FREEDOS')or(U='FREE')or(U='FDOS')Then SetupSystemFamily(DOS_FREEDOS)
 Else If(U='RXDOS')or(U='RX')Then SetupSystemFamily(DOS_RXDOS)
 Else If(U='WIN95')or(U='WIN9X')or(U='W95')or(U='MSDOS7')or(U='MS-DOS7')Then
  SetupSystemFamily(DOS_WIN95)
 Else If(U='PTS-DOS')or(U='PTSDOS')or(U='PTS')Then SetupSystemFamily(DOS_PTSDOS)
 Else If(U='OS/2')or(U='OS2')or(U='IBMOS2')Then SetupSystemFamily(DOS_OS2)
 Else If(U='NT')or(U='WINNT')or(U='WIN-NT')or(U='WIN2K')or(U='W2K')or
  (U='WINXP')or(U='XP')or(U='WIN2000')Then SetupSystemFamily(DOS_WINNT)
 Else ParseSystemFamily:=False
End;

Function SystemFamilyName:String;
Begin
 Case DosFamily of
  DOS_MSDOS:SystemFamilyName:='MS-DOS';DOS_PCDOS:SystemFamilyName:='PC-DOS';
  DOS_DRDOS:SystemFamilyName:='DR-DOS';DOS_FREEDOS:SystemFamilyName:='FreeDOS';
  DOS_RXDOS:SystemFamilyName:='RxDOS';DOS_WIN95:SystemFamilyName:='Win95';
  DOS_PTSDOS:SystemFamilyName:='PTS-DOS';DOS_OS2:SystemFamilyName:='OS/2';
  DOS_WINNT:SystemFamilyName:='WinNT';Else SystemFamilyName:='?'
 End
End;

Function ParseOptions(First:Integer;Var FormatSize:String):Boolean;
Var I,Code,NumericValue:Integer;S,U,N:String;
Begin
 ParseOptions:=False;FormatSize:='';ForceFormat:=False;NoVerify:=False;VolumeLabel:='';
 UnconditionalFormat:=False;QuickFormat:=False;TracksSpecified:=False;RequestedTracks:=0;
 SectorsSpecified:=False;RequestedSectors:=0;SystemTransfer:=False;
 SetupSystemFamily(DOS_MSDOS);
 For I:=First to ParamCount do Begin
  S:=ParamStr(I);U:=StrToUpper(S);
  If Copy(U,1,3)='/V:'Then Begin
   If not SetVolumeLabel(Copy(S,4,255))Then Exit
  End Else If Copy(U,1,3)='/T:'Then Begin
   N:=Copy(S,4,255);Val(N,NumericValue,Code);
   If(Code<>0)or(NumericValue<1)or(NumericValue>255)Then Begin
    WriteLn('Le nombre de pistes doit etre compris entre 1 et 255.');Exit
   End;
   If TracksSpecified Then Begin WriteLn('Le nombre de pistes est indique plusieurs fois.');Exit End;
   TracksSpecified:=True;RequestedTracks:=NumericValue
  End Else If Copy(U,1,3)='/N:'Then Begin
   N:=Copy(S,4,255);Val(N,NumericValue,Code);
   If(Code<>0)or(NumericValue<1)or(NumericValue>36)Then Begin
    WriteLn('Le nombre de secteurs par piste doit etre compris entre 1 et 36.');Exit
   End;
   If SectorsSpecified Then Begin WriteLn('Le nombre de secteurs est indique plusieurs fois.');Exit End;
   SectorsSpecified:=True;RequestedSectors:=NumericValue
  End Else If U='/U'Then UnconditionalFormat:=True
  Else If U='/Q'Then QuickFormat:=True
  Else If Copy(U,1,3)='/S:'Then Begin
   If not ParseSystemFamily(Copy(S,4,255))Then Begin
    WriteLn('Famille de systeme inconnue: ',Copy(S,4,255));Exit
   End;SystemTransfer:=True
  End Else If U='/S'Then SystemTransfer:=True
  Else If Copy(U,1,3)='/F:'Then Begin
   If InFile Then Begin WriteLn('/F:taille est reserve aux unites de disquette.');Exit End;
   N:=Copy(U,4,255);
   If not((N='160')or(N='180')or(N='320')or(N='360')or(N='720')or
    (N='1200')or(N='1440')or(N='2880'))Then Begin WriteLn('Taille /F inconnue: ',N);Exit End;
   If FormatSize<>''Then Begin WriteLn('Le format est indique plusieurs fois.');Exit End;
   FormatSize:=N;ForceFormat:=True
  End
  Else If U='/F'Then ForceFormat:=True
  Else If U='NV'Then NoVerify:=True
  Else If(U='160')or(U='180')or(U='320')or(U='360')or(U='720')or
   (U='1200')or(U='1440')or(U='2880')Then Begin
   If FormatSize<>''Then Begin WriteLn('Le format est indique plusieurs fois.');Exit End;
   FormatSize:=U
  End Else Begin WriteLn('Parametre inconnu: ',S);Exit End
 End;
 If QuickFormat and UnconditionalFormat Then Begin
  WriteLn('Les options /Q et /U sont incompatibles.');Exit
 End;
 ParseOptions:=True
End;

Function ApplyTrackOption(Var PData:PhysDataType;LData:LogDataType):Boolean;
Var TotalSectors,RootSectors,DataSectors,Clusters,FatEntries:LongInt;
Begin
 ApplyTrackOption:=False;
 If TracksSpecified Then PData.Tracks:=RequestedTracks;
 If SectorsSpecified Then Begin PData.Sec:=RequestedSectors;PData.DDPT^[4]:=RequestedSectors End;
 TotalSectors:=LongInt(PData.Tracks)*PData.Faces*PData.Sec;
 RootSectors:=(LongInt(LData.RootSize)*32+511)div 512;
 DataSectors:=TotalSectors-1-LongInt(LData.FAT)*2-RootSectors;
 If DataSectors<1Then Begin
  WriteLn('Le nombre de pistes ne laisse aucune zone de donnees.');Exit
 End;
 Clusters:=(DataSectors+LData.Cluster-1)div LData.Cluster;
 FatEntries:=(LongInt(LData.FAT)*512*2)div 3-2;
 If Clusters>FatEntries Then Begin
  WriteLn('Le nombre de pistes depasse la capacite de la FAT12 de ce format.');Exit
 End;
 If TotalSectors>65535Then Begin WriteLn('Le disque depasse 65535 secteurs.');Exit End;
 ApplyTrackOption:=True
End;

Function Get4matParam(S:String;DrvType:Byte;Var PData:PhysDataType;Var LData:LogDataType):Boolean;
Begin
 Get4matParam:=true;
 If S='160'Then
  If(DrvType=dtHD525)or(DrvType=dtDD525)or ForceFormat Then Begin PData:=PHYS160;LData:=LOG160 End
  Else Get4matParam:=False
 Else If S='180'Then
  If(DrvType=dtHD525)or(DrvType=dtDD525)or ForceFormat Then Begin PData:=PHYS180;LData:=LOG180 End
  Else Get4matParam:=False
 Else If S='320'Then
  If(DrvType=dtHD525)or(DrvType=dtDD525)or ForceFormat Then Begin PData:=PHYS320;LData:=LOG320 End
  Else Get4matParam:=False
 Else If S='1200'Then
  If(DrvType=dtHD525)Then Begin PData:=PHYS1200;LData:=LOG1200;End
  Else If ForceFormat Then Begin PData:=PHYS1200;LData:=LOG1200 End Else Get4matParam:=false
  Else
 If S='360'Then
  If(DrvType=dtHD525)or(DrvType=dtDD525)or ForceFormat Then Begin PData:=PHYS360; LData:=LOG360; End
					Else Get4matParam:=false
  Else
 If S='1440'Then
  If(DrvType=dtHD35)or ForceFormat Then Begin
   PData:=PHYS1440;
   LData:=LOG1440;
  End
   Else
  Get4matParam:=false
  Else
 If S='720'Then
 Begin
  If ForceFormat Then Begin
   PData:=PHYS720;
   LData:=LOG720;
  End
   Else
  If(DrvType=dtHD35)or(DrvType=dtDD35)Then Begin
   PData:=PHYS720;
   LData:=LOG720;
  End
   Else
  Get4matParam:=False
 End
  Else
 If S='2880'Then
  If(DrvType=dtHD35)or ForceFormat Then Begin PData:=PHYS2880;LData:=LOG2880 End
  Else Get4matParam:=False
  Else
 Get4matParam:=false;
End;

Procedure InitDsk(Drive:Byte;PData:PhysDataType);
Var
 _CH,_CL:Byte;
Begin
 {$IFDEF FPC}
 {$ELSE}
  _CH:=PData.Tracks-1; _CL:=PData.Sec;
  ASM
   MOV AH,$18;
   MOV CL,_CL;
   MOV CH,_CH;
   MOV DL,Drive;
   INT $13;
  END;
 {$ENDIF}
End;

Function FormatTrack(Drv,Face,Track,Nm:Byte):Byte;
Type
 FormatTyp=Record
  DTrack,DFace,DI,DLen:Byte;
 End;
Var
 Regs:Registers;
 AreaData:Array[1..36]of FormatTyp;
 I,Try:Byte;
Begin
 For I:=1to(Nm)do With AreaData[I]do Begin
  DTrack:=Track;DFace:=Face;DI:=I;DLen:=2;
 End;
 Try:=dTryMax;
 Repeat
  With Regs do Begin
   ah:=5;
   al:=Nm;
   es:=Seg(AreaData);
   bx:=Ofs(AreaData);
   dh:=Face;
   dl:=Drv;
   ch:=Track;
  End;
  Intr($13,Regs);
  If Regs.flags and fcarry=1Then DskReset;
  Dec(Try);
 Until(Regs.flags and fcarry=0)or(Try=0);
 Formattrack:=Regs.ah;
End;

Function VerifyTrack(Lecteur,Face,Piste,Secteurs:Byte):Byte;
Var
 Try:Byte;
 Regs:Registers;
 TamponPiste:TrackBufType;
Begin
 Try:=dTryMax;
 Repeat
  With Regs do Begin
   ah:=$04;              { Numero de fonction pour appel interruption }
   al:=Secteurs;         { Nombre Secteurs par Piste }
   ch:=Piste;            { Numero de Piste }
   cl:=1;                { Commencer par le secteur 1 }
   dl:=Lecteur;          { Numero de lecteur }
   dh:=Face;             { Numero de la face }
   es:=Seg(TamponPiste); { Adresse du tampon }
   bx:=Ofs(TamponPiste);
  End;
  Intr($13,Regs);
  If Regs.flags and fcarry=1Then DskReset;
  Dec(Try);
 Until(Regs.flags and fcarry=0)or(Try=0);
 VerifyTrack:=Regs.ah;
End;

Function WriteTrack(Lecteur,Face,Piste,Start,Nombre:Byte;Var Buffer):Byte;
Var
 Essais:Byte;
 Regs:Registers;
Begin
 essais:=dTryMax;
 Repeat
  With Regs do Begin
   ah:=$03;        { Numero de fonction pour appel interruption }
   al:=Nombre;     { Nombre Secteurs par Piste }
   ch:=Piste;      { Numero de Piste }
   cl:=Start;      { Commencer par le secteur 1 }
   dl:=Lecteur;    { Numero de lecteur }
   dh:=Face;       { Numero de la face }
   es:=Seg(Buffer);{ Adresse pour tampon }
   bx:=Ofs(Buffer);
  End;
  Intr($13,Regs);
  If Regs.flags and fcarry=1Then DskReset;
  Dec(essais);
 Until(Regs.flags and fcarry=0)or(Essais=0);
 WriteTrack:=Regs.ah;
End;

Function WriteVolumeLabel(PData:PhysDataType;LData:LogDataType):Boolean;
Var
 RootSector,Remaining:Word;
 Track,Face,Sector,I,Status:Byte;
 Buffer:Array[0..511]of Byte;
 Written:Word;
Begin
 If VolumeLabel=''Then Begin WriteVolumeLabel:=True;Exit End;
 FillChar(Buffer,SizeOf(Buffer),0);
 For I:=1to 11do Buffer[I-1]:=Ord(VolumeLabel[I]);
 Buffer[11]:=$08; { Entree de repertoire FAT: attribut volume. }
 RootSector:=1+2*LData.FAT;
 If InFile Then Begin
  Seek(FileImg,LongInt(RootSector)*512);
  If IOResult<>0Then Begin WriteVolumeLabel:=False;Exit End;
  BlockWrite(FileImg,Buffer,32,Written);
  WriteVolumeLabel:=(Written=32)and(IOResult=0)
 End Else Begin
  Track:=RootSector div(Word(PData.Sec)*PData.Faces);
  Remaining:=RootSector mod(Word(PData.Sec)*PData.Faces);
  Face:=Remaining div PData.Sec;Sector:=Remaining mod PData.Sec+1;
  Status:=WriteTrack(AktDrv,Face,Track,Sector,1,Buffer);
  WriteVolumeLabel:=Status=0
 End
End;

Function WriteLogicalSector(PData:PhysDataType;SectorNumber:LongInt;Var Buffer):Boolean;
Var Remaining:LongInt;Track,Face,Sector,Status:Byte;Written:Word;
Begin
 If InFile Then Begin
  Seek(FileImg,SectorNumber*512);
  If IOResult<>0Then Begin WriteLogicalSector:=False;Exit End;
  BlockWrite(FileImg,Buffer,512,Written);
  WriteLogicalSector:=(Written=512)and(IOResult=0)
 End Else Begin
  Track:=SectorNumber div(LongInt(PData.Sec)*PData.Faces);
  Remaining:=SectorNumber mod(LongInt(PData.Sec)*PData.Faces);
  Face:=Remaining div PData.Sec;Sector:=Remaining mod PData.Sec+1;
  Status:=WriteTrack(AktDrv,Face,Track,Sector,1,Buffer);
  WriteLogicalSector:=Status=0
 End
End;

Procedure SetFAT12Entry(FAT:PFatBuffer;Cluster,Value:Word);
Var Offset:Word;V:Word;
Begin
 Offset:=Cluster+(Cluster div 2);
 V:=FAT^[Offset]or(Word(FAT^[Offset+1])shl 8);
 If(Cluster and 1)=0Then V:=(V and $F000)or(Value and $0FFF)
 Else V:=(V and $000F)or((Value and $0FFF)shl 4);
 FAT^[Offset]:=Lo(V);FAT^[Offset+1]:=Hi(V)
End;

Procedure PutDirectoryName(Var Entry;Const Name:String);
Var P:^Byte;I,Dot:Byte;Base,Ext:String;
Begin
 P:=@Entry;For I:=0to 10do Begin P^:=Ord(' ');Inc(P)End;
 Dot:=Pos('.',Name);If Dot=0Then Begin Base:=Name;Ext:=''End
 Else Begin Base:=Copy(Name,1,Dot-1);Ext:=Copy(Name,Dot+1,3)End;
 P:=@Entry;For I:=1to Length(Base)do If I<=8Then Begin P^:=Ord(UpCase(Base[I]));Inc(P)End;
 P:=@Entry;Inc(P,8);For I:=1to Length(Ext)do If I<=3Then Begin P^:=Ord(UpCase(Ext[I]));Inc(P)End
End;

Function SystemFilesAvailable:Boolean;
Var F:File;I:Byte;
Begin
 SystemFilesAvailable:=False;
 For I:=1to SysFileCount do Begin
  Assign(F,SysFiles[I]);Reset(F,1);
  If IOResult<>0Then Begin WriteLn('Fichier de demarrage introuvable: ',SysFiles[I]);Exit End;
  Close(F);If IOResult<>0Then Begin WriteLn('Erreur de lecture: ',SysFiles[I]);Exit End
 End;
 SystemFilesAvailable:=True
End;

Function TransferSystemFiles(PData:PhysDataType;LData:LogDataType):Boolean;
Var
 FAT:PFatBuffer;Root,Buffer:TSectorBuffer;Src:File;
 I,J,K,CopyNumber:Integer;Got:Word;FileSizeValue,Remaining,ClusterBytes:LongInt;
 RootSectors,DataStart,SectorNumber,TotalSectors,MaximumClusters:LongInt;ClustersNeeded:Word;
 FirstCluster,CurrentCluster,NextCluster:Word;EntryOffset:Word;
 Y,Mo,D,Dow,H,Mi,Se,S100,DirDate,DirTime:Word;Attr:Byte;
Begin
 TransferSystemFiles:=False;
 If not SystemFilesAvailable Then Exit;
 WriteLn('Transfert du systeme ',SystemFamilyName,'.');
 GetMem(FAT,MaxFormatFATBytes);If FAT=Nil Then Begin WriteLn('Memoire insuffisante pour la FAT.');Exit End;
 FillChar(FAT^,MaxFormatFATBytes,0);FillChar(Root,SizeOf(Root),0);
 FAT^[0]:=LData.Media;FAT^[1]:=$FF;FAT^[2]:=$FF;
 If VolumeLabel<>''Then Begin
  For I:=1to 11do Root[I-1]:=Ord(VolumeLabel[I]);Root[11]:=$08;K:=1
 End Else K:=0;
 GetDate(Y,Mo,D,Dow);GetTime(H,Mi,Se,S100);
 If Y<1980Then Y:=1980;
 DirDate:=((Y-1980)shl 9)or(Mo shl 5)or D;
 DirTime:=(H shl 11)or(Mi shl 5)or(Se div 2);
 RootSectors:=(LongInt(LData.RootSize)*32+511)div 512;
 DataStart:=1+LongInt(LData.FAT)*2+RootSectors;
 TotalSectors:=LongInt(PData.Tracks)*PData.Faces*PData.Sec;
 MaximumClusters:=(TotalSectors-DataStart)div LData.Cluster;
 ClusterBytes:=LongInt(LData.Cluster)*512;NextCluster:=2;
 For I:=1to SysFileCount do Begin
  Assign(Src,SysFiles[I]);Reset(Src,1);
  If IOResult<>0Then Begin FreeMem(FAT,MaxFormatFATBytes);Exit End;
  FileSizeValue:=FileSize(Src);ClustersNeeded:=(FileSizeValue+ClusterBytes-1)div ClusterBytes;
  If(LongInt(NextCluster)+ClustersNeeded>4085)or
   (LongInt(NextCluster-2)+ClustersNeeded>MaximumClusters)Then Begin
   Close(Src);FreeMem(FAT,MaxFormatFATBytes);WriteLn('Espace FAT12 insuffisant pour ',SysFiles[I]);Exit
  End;
  If ClustersNeeded=0 Then FirstCluster:=0 Else FirstCluster:=NextCluster;
  Remaining:=FileSizeValue;
  For J:=0to ClustersNeeded-1do Begin
   CurrentCluster:=NextCluster;Inc(NextCluster);
   If J=ClustersNeeded-1Then SetFAT12Entry(FAT,CurrentCluster,$FFF)
   Else SetFAT12Entry(FAT,CurrentCluster,NextCluster);
   For CopyNumber:=0to LData.Cluster-1do Begin
    FillChar(Buffer,SizeOf(Buffer),0);Got:=0;
    If Remaining>0Then Begin BlockRead(Src,Buffer,512,Got);If IOResult<>0Then Got:=0 End;
    If(Got=0)and(Remaining>0)Then Begin
     Close(Src);FreeMem(FAT,MaxFormatFATBytes);WriteLn('Erreur de lecture: ',SysFiles[I]);Exit
    End;
    SectorNumber:=DataStart+LongInt(CurrentCluster-2)*LData.Cluster+CopyNumber;
    If not WriteLogicalSector(PData,SectorNumber,Buffer)Then Begin
     Close(Src);FreeMem(FAT,MaxFormatFATBytes);WriteLn('Erreur d''ecriture de ',SysFiles[I]);Exit
    End;
    Dec(Remaining,Got)
   End
  End;
  Close(Src);If IOResult<>0Then Begin FreeMem(FAT,MaxFormatFATBytes);Exit End;
  EntryOffset:=K*32;PutDirectoryName(Root[EntryOffset],SysFiles[I]);
  If StrToUpper(SysFiles[I])='COMMAND.COM'Then Attr:=$20 Else Attr:=$27;
  Root[EntryOffset+11]:=Attr;
  Root[EntryOffset+22]:=Lo(DirTime);Root[EntryOffset+23]:=Hi(DirTime);
  Root[EntryOffset+24]:=Lo(DirDate);Root[EntryOffset+25]:=Hi(DirDate);
  Root[EntryOffset+26]:=Lo(FirstCluster);Root[EntryOffset+27]:=Hi(FirstCluster);
  Root[EntryOffset+28]:=Byte(FileSizeValue);Root[EntryOffset+29]:=Byte(FileSizeValue shr 8);
  Root[EntryOffset+30]:=Byte(FileSizeValue shr 16);Root[EntryOffset+31]:=Byte(FileSizeValue shr 24);
  Inc(K)
 End;
 For CopyNumber:=0to 1do For I:=0to LData.FAT-1do Begin
  SectorNumber:=1+LongInt(CopyNumber)*LData.FAT+I;
  If not WriteLogicalSector(PData,SectorNumber,FAT^[I*512])Then Begin
   FreeMem(FAT,MaxFormatFATBytes);WriteLn('Erreur d''ecriture de la FAT.');Exit
  End
 End;
 If not WriteLogicalSector(PData,1+LongInt(LData.FAT)*2,Root)Then Begin
  FreeMem(FAT,MaxFormatFATBytes);WriteLn('Erreur d''ecriture du repertoire racine.');Exit
 End;
 FreeMem(FAT,MaxFormatFATBytes);TransferSystemFiles:=True
End;

Function Phys4mat(Drv:Byte;PData:PhysDataType;Verify:Boolean):Boolean;
Var
 Try,T,F,Status:Byte;
Begin
 For T:=0to PData.Tracks-1do For F:=0to PData.Faces-1do Begin
  Write(#13'Piste : ',T:2,'  Face : ',F:2);
  Try:=dTryMax;
  Repeat
   Status:=FormatTrack(Drv,F,T,PData.Sec);
   If Status=3Then Begin
    Phys4mat:=false;
    WriteLn;
    WriteLn('Disquette protegee contre l''ecriture');
    Exit;
   End;
   If(Status=0)and Verify Then Status:=VerifyTrack(Drv,F,T,PData.Sec);
   Dec(Try);
   If Status>0Then DskReset;
  Until(Status=0)or(Try=0);
  If Status>0Then Begin
   Phys4mat:=false;
   WriteLn;
   WriteLn('Erreur de piste ?');
   Exit;
  End;
 End;
 Phys4mat:=true;
End;

Function Logical4mat(Drive:Byte;PData:PhysDataType;LData:LogDataType):Boolean;
Var
 Status:Byte;
 NmSec:Word;
 I,AktSec,AktSide,AktTrack:Byte;
 Nm:Integer;
 TrackBuf:TrackBufType;
 ByteWrited:Word;
Begin
 FillChar(TrackBuf,Word(PData.Sec)*512,0); { Vide tampon }
  { Secteur de demarrage: Partie fixe }
 System.Move(Maskboot,TrackBuf,102);
 System.Move(BootMsg[1],TrackBuf[1,103],Byte(BootMsg[0]));
 TrackBuf[1,511]:=$55;
 TrackBuf[2,0]:=$AA;
 TrackBuf[1,510]:=$55;
 TrackBuf[1,511]:=$AA;
  { Secteur de demarrage: Partie variable }
 NmSec:=PData.Tracks;NmSec:=NmSec*PData.Sec;NmSec:=NmSec*Pdata.Faces;
 TrackBuf[1,12]:=Lo(512);
 TrackBuf[1,13]:=Hi(512);
 TrackBuf[1,14]:=LData.Cluster;  { Longueur de l'unite d'allocation }
 TrackBuf[1,18]:=LData.RootSize; { Nombre Entrees dans r├⌐pertoires }
 TrackBuf[1,20]:=lo(NmSec);      { Nombre total de secteur }
 TrackBuf[1,21]:=hi(NmSec);      { sur la disquette }
 TrackBuf[1,22]:=LData.Media;    { Descripteur support }
 TrackBuf[1,23]:=LData.FAT;      { Longueur des FAT }
 TrackBuf[1,25]:=PData.Sec;      { Secteurs par piste }
 TrackBuf[1,27]:=PData.Faces;    { Nombre de faces }
 { Reecriture du BPB aux offsets DOS reels (0-based). }
 TrackBuf[1,11]:=Lo(512);TrackBuf[1,12]:=Hi(512);
 TrackBuf[1,13]:=LData.Cluster;
 TrackBuf[1,14]:=1;TrackBuf[1,15]:=0;TrackBuf[1,16]:=2;
 TrackBuf[1,17]:=LData.RootSize;TrackBuf[1,18]:=0;
 TrackBuf[1,19]:=Lo(NmSec);TrackBuf[1,20]:=Hi(NmSec);
 TrackBuf[1,21]:=LData.Media;
 TrackBuf[1,22]:=LData.FAT;TrackBuf[1,23]:=0;
 TrackBuf[1,24]:=PData.Sec;TrackBuf[1,25]:=0;
 TrackBuf[1,26]:=PData.Faces;TrackBuf[1,27]:=0;
  { Creer FAT et sa copie (contient 00) }
 TrackBuf[2,1]:=LData.Media;
 TrackBuf[2,2]:=$FF;
 TrackBuf[2,3]:=$FF;
 TrackBuf[LData.FAT+2,1]:=LData.Media;
 TrackBuf[LData.FAT+2,2]:=$FF;
 TrackBuf[LData.FAT+2,3]:=$FF;
 If(InFile)Then Begin
  Seek(FileImg,0);
  BlockWrite(FileImg,TrackBuf,Word(PData.Sec)*512,ByteWrited);
  If ByteWrited=(Word(PData.Sec)*512)Then Status:=0
                                     Else Status:=1;
 End
  Else
 Status:=WriteTrack(Drive,0,0,1,PData.Sec,TrackBuf);
 If Status<>0Then Logical4mat:=false
  else
 Begin
  FillChar(TrackBuf,512,0);
  AktSec:=PData.Sec; AktTrack:=0; AktSide:=0;
  Nm:=LData.FAT*2+(LData.Rootsize*32div 512)+1-PData.Sec; I:=1;
  Repeat
   Inc(AktSec);
   If(AktSec>PData.Sec)Then Begin
    AktSec:=1; Inc(AktSide);
    If(AktSide=PData.Faces)Then Begin
     AktSide:=0;
     Inc(AktTrack);
    End;
   End;
   If(InFile)Then Begin
    BlockWrite(FileImg,TrackBuf,512,ByteWrited);
    If ByteWrited=512 Then Status:=0
                      Else Status:=1;
   End
    Else
   Status:=WriteTrack(Drive,AktSide,AktTrack,AktSec,1,TrackBuf);
   Inc(i);
  Until(i>Nm)or(Status<>0);
  If Status=0Then Logical4mat:=WriteVolumeLabel(PData,LData)
              Else Logical4mat:=False;
 End;
End;

BEGIN
 Language:=_French;
 TmpLanguage:=GetEnv('LANGUAGE');
 If TmpLanguage<>''Then Begin
  If TmpLanguage[1]='"'Then TmpLanguage:=Copy(TmpLanguage,2,255);
  If StrToUpper(Copy(TmpLanguage,1,2))='EN'Then Language:=_English Else
  If StrToUpper(Copy(TmpLanguage,1,2))='GR'Then Language:=_Germany Else
  If StrToUpper(Copy(TmpLanguage,1,2))='IT'Then Language:=_Italian Else
  If StrToUpper(Copy(TmpLanguage,1,2))='SP'Then Language:=_Spain;
 End;
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  Case Language of
   _Germany:Begin
    WriteLn('Formate un disque pour une utilisation sous DOS.');
    WriteLn;
    WriteLn('FORMAT [A:|B:] [format] [NV] [/F:Groesse] [/V:Name] [/T:n] [/N:n] [/Q] [/U] [/S]');
    WriteLn('FORMAT Dateiname [360|720|1200|1440] [/V:Name] [/T:n] [/N:n] [/Q] [/U] [/S]');
   End;
   _English:Begin
    WriteLn('Formats a disk for use with DOS.');
    WriteLn;
    WriteLn('Syntax: FORMAT [A:|B:] [format] [NV] [/F:size] [/V:label] [/T:n] [/N:n] [/Q] [/U] [/S]');
    WriteLn('        FORMAT file [360|720|1200|1440] [/V:label] [/T:n] [/N:n] [/Q] [/U] [/S]');
    WriteLn('  /V:label  Specifies the volume label (11 characters maximum).');
    WriteLn('  /F:size   Selects floppy size: 160, 180, 320, 360, 720,');
    WriteLn('             1200, 1440 or 2880 KB (floppy drives only).');
    WriteLn('  /T:n      Specifies the number of tracks.');
    WriteLn('  /N:n      Specifies the number of sectors per track.');
    WriteLn('  /Q        Performs a quick format of filesystem tables only.');
    WriteLn('  /U        Performs an unconditional full format.');
    WriteLn('  /S        Copies IO.SYS, MSDOS.SYS and COMMAND.COM.');
    WriteLn('  /S:family Selects MS-DOS, PC-DOS, DR-DOS, FreeDOS, RxDOS,');
    WriteLn('             Win95, PTS-DOS, OS/2 or WinNT.');
   End;
   Else Begin
    WriteLn('FORMAT - Cette commande permet de formater un unit'+#130+' de disquette.');
    WriteLn;
    WriteLn('Syntaxe: FORMAT [A:|B:] [format] [NV] [/F:taille] [/V:nom] [/T:n] [/N:n] [/Q] [/U] [/S]');
    WriteLn('         FORMAT fichier [360|720|1200|1440] [/V:nom] [/T:n] [/N:n] [/Q] [/U] [/S]');
    WriteLn;
    WriteLn('fichier  Utiliser le fichier sp'+#130+'cifi'+#130+' comme disquette');
    WriteLn('     NV  Pas de v'+#130+'rification');
    WriteLn('     /F  Force a utiliser ce format');
    WriteLn(' /F:taille  Format de disquette: 160, 180, 320, 360, 720,');
    WriteLn('            1200, 1440 ou 2880 Ko (lecteur seulement)');
    WriteLn(' /V:nom  Indique le nom du volume (11 caracteres maximum)');
    WriteLn('    /T:n  Indique le nombre de pistes du disque');
    WriteLn('    /N:n  Indique le nombre de secteurs par piste');
    WriteLn('      /Q  Reinitialise rapidement le secteur de demarrage, les FAT');
    WriteLn('          et le repertoire racine sans parcourir toutes les pistes');
    WriteLn('      /U  Effectue un formatage complet et inconditionnel');
    WriteLn('      /S  Copie IO.SYS, MSDOS.SYS et COMMAND.COM');
    WriteLn(' /S:famille  Selectionne la famille DOS (defaut: MS-DOS) :');
    WriteLn('   MS-DOS   -> IO.SYS, MSDOS.SYS, COMMAND.COM');
    WriteLn('   PC-DOS   -> IBMBIO.COM, IBMDOS.COM, COMMAND.COM');
    WriteLn('   DR-DOS   -> IBMBIO.COM, IBMDOS.COM, COMMAND.COM');
    WriteLn('   FreeDOS  -> KERNEL.SYS, COMMAND.COM');
    WriteLn('   RxDOS    -> RXDOSBIO.SYS, RXDOS.SYS, COMMAND.COM');
    WriteLn('   Win95    -> IO.SYS, MSDOS.SYS, COMMAND.COM');
    WriteLn('   PTS-DOS  -> PTSBIO.SYS, PTSDOS.SYS, COMMAND.COM');
    WriteLn('   OS/2     -> OS2BOOT, OS2LDR, OS2KRNL');
    WriteLn('   WinNT    -> NTLDR, NTDETECT.COM, BOOT.INI');
   End;
  End;
 End
  Else
 If ParamCount>=1Then Begin
  InFile:=False;
  Param:=ParamStr(1);
  If(Length(Param)=2)and(Param[2]=':')Then Begin
   AktDrv:=Byte(UpCase(Param[1]))-65;
   AktDrvType:=GetDrvType(AktDrv);
   If AktDrvType>0Then Begin
    If not ParseOptions(2,Param)Then Halt(4);
    If Param=''Then Case AktDrvType of
     dtDD525:Param:='360';dtHD525:Param:='1200';dtDD35:Param:='720';dtHD35:Param:='1440'
    End;
    If Get4matParam(Param,AktDrvType,PData,LData)and ApplyTrackOption(PData,LData)Then Begin
     If SystemTransfer and not SystemFilesAvailable Then Halt(6);
     If UnconditionalFormat Then WriteLn('Formatage complet et inconditionnel.');
     InitDsk(AktDrv,PData);
     GetIntVec($1E,AncDDPT);
     SetIntVec($1E,PData.DDPT);
     If QuickFormat Then Begin WriteLn('Formatage rapide des tables du disque.');Ok:=True End
     Else Ok:=Phys4mat(AktDrv,PData,not NoVerify);
     If(Ok)Then Begin
      WriteLn;
      Writeln('Ecriture du secteur de demarrage et des FAT ');
      Ok:=Logical4mat(AktDrv,PData,LData);
      If Ok and SystemTransfer Then Ok:=TransferSystemFiles(PData,LData)
     End;
     If(Ok)Then Begin
      WriteLn;
      WriteLn('Formatage S.V.P.');
     End
      else
     Begin
      WriteLn;
      WriteLn('Une erreur a interrompu le formatage');
      Halt(1);
     End;
     SetIntVec($1E,AncDDPT);
    End
     else
    Begin
     WriteLn('Le format demande ne peut etre utilise sur cette unite de disque !');
     Halt(2);
    End;
   End
    Else
   Begin
    WriteLn('Le lecteur de disquettes demande n''existe pas');
    Halt(3);
   End
  End
   Else
  Begin
   InFile:=True;
   KS:=1440;
   ImageName:=Param;
   If not ParseOptions(2,Param)Then Halt(4);
   If SystemTransfer and not SystemFilesAvailable Then Halt(6);
   WriteLn('Formatage du fichier d''image : ',ImageName);
   ExistingQuickImage:=False;
   {$I-}Assign(FileImg,ImageName);
   If QuickFormat Then Begin
    FileMode:=2;Reset(FileImg,1);
    If IOResult=0Then ExistingQuickImage:=True Else Rewrite(FileImg,1)
   End Else Rewrite(FileImg,1);{$I+}
   If IOResult<>0Then Begin WriteLn('Impossible de creer le fichier image.');Halt(5)End;
   PData:=PHYS1440;
   LData:=LOG1440;
   If Param<>''Then Begin
    If Param='160'Then Begin PData:=PHYS160;LData:=LOG160;KS:=160 End
    Else If Param='180'Then Begin PData:=PHYS180;LData:=LOG180;KS:=180 End
    Else If Param='320'Then Begin PData:=PHYS320;LData:=LOG320;KS:=320 End
    Else If Param='360'Then Begin
     PData:=PHYS360;
     LData:=LOG360;
     KS:=360;
    End
     Else
    If Param='720'Then Begin
     PData:=PHYS720;
     LData:=LOG720;
     KS:=720;
    End
     Else
    If Param='1200'Then Begin
     PData:=PHYS1200;
     LData:=LOG1200;
     KS:=1200;
    End
     Else
    If Param='1440'Then Begin
     PData:=PHYS1440;
     LData:=LOG1440;
     KS:=1440;
    End
     Else
    If Param='2880'Then Begin
     PData:=PHYS2880;LData:=LOG2880;KS:=2880;
    End
   End;
   If not ApplyTrackOption(PData,LData)Then Begin Close(FileImg);Halt(4)End;
   KS:=LongInt(PData.Tracks)*PData.Faces*PData.Sec div 2;
   If ExistingQuickImage and(FileSize(FileImg)<>LongInt(KS)*1024)Then Begin
    WriteLn('La taille de l''image existante ne correspond pas a la geometrie /T et /N.');
    Close(FileImg);Halt(4)
   End;
   If QuickFormat Then WriteLn('Formatage rapide des tables de l''image.');
   If UnconditionalFormat Then WriteLn('Formatage complet et inconditionnel.');
   Seek(FileImg,0);
   WriteLn('Ecriture du secteur de d'+#130+'marrage et des FAT');
   Ok:=Logical4mat(AktDrv,PData,LData);
   If Ok and SystemTransfer Then Ok:=TransferSystemFiles(PData,LData);
   Seek(FileImg,KS*1024);
   Truncate(FileImg);
   Close(FileImg);
   If not Ok Then Begin WriteLn('Une erreur a interrompu le formatage ou le transfert systeme.');Halt(1)End;
  End;
 End
  Else
 WriteLn('Parametre requis !')
END.
