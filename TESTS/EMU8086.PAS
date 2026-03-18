{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2024
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program EMU8086;

{$A-}

Uses Strings,Crt,DOS;

Const
 SwapFileMemory='EMU8086.$$$';

  {Code de retour de session}
 sfNone=0;         { Aucune faute }
 sfInvalidCode=1;  { Code machine invalide }
 sfHLT=2;          { Instruction machine HLT }
 sfHotBoot=3;      { DÇmarrage Ö chaud }
 sfColdBoot=4;     { DÇmarrage Ö froid }
 sfInvalidIntr=5;  { Interruption invalide }
 sfEndProgram=6;   { Fin de programme de l'interruption 20h }
 sfBreakPoint=7;   { Point d'arràt }
 sfDivision0=8;    { Division par 0 }

 { Les diffÇrents micro-ordinateurs Ö Çmuler }
 mcIBMPC=0;
 mcPC_XT=1;
 mcPCJunior=2;
 mcPC_AT=3;
 mcOlivettiM24=84;
 mcContermMax=85;
 mcWang=87;
 mcAmdekSystem88=88;

 { Les diffÇrents Micro-Processeur (CPU) }
 cpu8088=0;                { Intel 8088 }
 cpu8086=1;                { Intel 8086 }
 cpuV20=2;                 { NEC V20 }
 cpuV30=3;                 { NEC V30 }
 cpu80188=4;               { Intel 80188 }
 cpu80186=5;               { Intel 80186 }
 cpu80286=6;               { Intel 80286 }
 cpui386=7;                { Intel 80386 }
 cpui486=8;                { Intel 80486 }
 cpuCyrix5x86=9;           { Cyrix 5x86 }
 cpuCyrix6x86=10;          { Cyrix 6x86 }
 cpuPentium=11;            { Pentium }
 cpuPentiumMMX=12;         { Pentium-MMX }
 cpuPentiumII=13;          { Pentium II }

  {Les diffÇrents fabricants du CPU}
 cvIntel=0;                { Intel, par dÇfaut }
 cvCyrix=1;                { Cyrix }
 cvIBM=2;                  { IBM }
 cvAMD=3;                  { AMD }

 opMov=0;
 opAdc=1;
 opAdd=2;
 opAnd=3;
 opCmp=4;
 opOr=5;
 opSub=6;
 opSbb=7;
 opXor=8;
 opInc=9;
 opDec=10;
 opMul=11;
 opDiv=12;
 opXChg=$86;

Type
  {Structure de fichier .EXE}
 HeaderEXE=Record
  Sign:Array[0..1]of Char; {  0 - Signature 'MZ' }
  LenN511:Word;            {  2 - Longueur Module 512 (Et binaire 511) }
  LenShr9:Word;            {  4 - Longueur Diviser 512 (Shift Right 9) }
  NmSeg:Word;              {  6 - Nombre de segment Ö adapter }
  SizeOfHeader:Word;       {  8 - Taille de l'entàte en paragraphe }
  MinParagraph:Word;       { 10 - Nombre minimal de paragraphe }
  MaxParagraph:Word;       { 12 - Nombre maximal de paragraphe }
  OfsLoadStack:Word;       { 14 - DÇplacement de chargement de module dans la pile }
  SizeOfStack:Word;        { 16 - Taille de la pile (SP) }
  CheckSum:Word;           { 18 - VÇrificateur de l'entàte du fichier ex,cutable }
  IP:Word;                 { 20 - Point d'entrÇe d'instruction }
  OfsLoad:Word;            { 22 - DÇplacement de chargement de module dans le code }
  AdrExeTable:Word;        { 24 - Adresse de la table de relogement du programme EXE }
  NmOvr:Word;              { 26 - NumÇro de recouvrement (0 pour le programme principal) }
 End;

 PSPRecord=Record Case Byte of
  0:(Buffer:Array[Byte]of Byte);
  1:(Int20h:Word;
     EndSegPrg:Word;
     ReservedA:Byte;
     CallDOS:Array[0..4]of Byte;
     Int22h:Pointer;
     Int23h:Pointer;
     Int24h:Pointer;
     ParentSeg:Word;
     Handle:Array[0..19]of Byte;
     EnvSeg:Word;
     ReservedB:LongInt;
     LenHandle:Word;
     HandlePtrOfs,HandlePtrSeg:Word;
     ReservedC:Array[0..22]of Byte;
     Int21h:Word;
     RetF:Byte
     );
 End;

 LongRec=Record
  Lo,Hi:Word;
 End;
 TByte=Array[0..65000]of Byte;

Var
 I:Integer;
 Verbose,Debug,ReadOnlyMachine:Boolean;
 FileName,S:String;
 Memory:File;
 ModelComputer:Word;
 Option:Set of (soMath,      { Coprocesseur mathÇmatique activÇ? }
                soWaitState, { DÇlai entre les instructions? }
                soMMX,       { Instruction MMX supportÇ? }
                soCPUID,     { Instruction ÆCPUIDØ supportÇ? }
                soSETALC);   { Instruction ÆSETALCØ supportÇ? }
 CPUVendor:Byte; { Fabricant du microprocesseur }
 Segs:Record Case Byte of
  0:(ES,CS,SS,DS:Word);
  1:(Abs:Array[0..3]of Word);
 End;
 IP,FS,GS:Word;
 Regs:Record Case Byte of
  0:(EAX,ECX,EDX,EBX,ESP,EBP,ESI,EDI:LongInt);
  1:(AX,EAH,CX,ECH,DX,EDH,BX,EBH,SP,SPH,BP,BPH,SI,SIH,DI,DIH:Word);
  2:(AL,AH,HAL,HAH,CL,CH,HCL,HCH,DL,DH,HDL,HDH,BL,BH,HBL,HBH:Byte);
  3:(Abs:Array[0..7]of LongInt);
  4:(AbsWord:Array[0..7]of LongRec);
  5:(Chr:Array[0..15]of Char);
 End;
 OldFlags,Flags:Record Case Byte of
  0:(s:Set of(CF,bit1,PF,bit3,AF,bit5,ZF,SF,TF,_IF,DF,_OF));
  2:(Base:Word);
  3:(Abs:LongInt);
  4:(DataByte:Byte);
 End;
 CPU,Fault:Word;
 NextRawKey:Byte;{ Un code de touche en attente }
 CmosPos:Byte;   { Position dans le CMOS }
 CurrSeg:Byte;   { Segment courant (CS: DS:,..)}
 OldCSeg:Word;   { Ancien segment de code }
 CodeBrk:Integer;     { Code machine de point d'arràt }
 PSP:Word;       { PSP de l'application }
 CurrFilesHandles:Integer;
 FilesHandles:Array[10..25]of File;
 FilesHandlesUsed:Array[10..25]of Boolean;
 ParityTable:Array[0..255]of Boolean;
 Buffer:Array[0..255]of Byte;

Function StrToUpper(S:String):String;
Var
 I:Byte;
Begin
 For I:=1 to Length(S)do Begin
  If S[I] in['a'..'z']Then S[I]:=Chr(Ord(S[I])-32);
 End;
 StrToUpper:=S;
End;

Function ByteHex2Str(value:Byte):String;
Const
 matrix:Array[0..15]of Char = ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');
Begin
 ByteHex2Str:=matrix[(value shr 4) and $0F]+matrix[value and $F];
End;

Function HexWord2Str(value:Word):String;Begin
 HexWord2Str:=ByteHex2Str(Hi(value))+ByteHex2Str(Lo(value));
End;

Procedure SwapWord(Var A,B:Word);
Var
 T:Word;
Begin
 T:=A;
 A:=B;
 B:=T;
End;

Function Path2Ext(S:String):String;
Var
 D:DirStr;
 N:NameStr;
 E:ExtStr;
Begin
 FSplit(S,D,N,E);
 Path2Ext:=E;
End;

Function GetCurrentDisk:Char;
Var
 CurrentDir:String;
Begin
 GetDir(0,CurrentDir);
 GetCurrentDisk:=CurrentDir[1];
End;

Function AddrExt2Conv(Seg,Ofs:Word):LongInt;Begin
 AddrExt2Conv:=LongInt(Seg)shl 4+Ofs;
End;

Procedure SetZFB(X:Byte);Begin
 If X=0 Then Include(Flags.s,ZF)
        Else Exclude(Flags.s,ZF);
End;

Procedure SetZFW(X:Word);Begin
 If X=0 Then Include(Flags.s,ZF)
        Else Exclude(Flags.s,ZF);
End;

Procedure SetPF(X:Byte);Begin
 If ParityTable[X] Then Include(Flags.s,PF)
                   Else Exclude(Flags.s,PF);
End;

Procedure SetSFW(X:Word);Begin
 If X and $8000<>0 Then Include(Flags.s,SF)
                   Else Exclude(Flags.s,SF);
End;

Procedure SetSFB(X:Byte);Begin
 If X and $80<>0 Then Include(Flags.s,SF)
                 Else Exclude(Flags.s,SF);
End;

Procedure DivisionException;Begin
 Fault:=sfDivision0;
End;

Procedure IncCode(Num:Integer);Begin
 Inc(IP,Num);
End;

Procedure SetReg8bits(Num,Value:Byte);Begin
 Case(Num)and$7of
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

Function GetReg8Bits(Num:Byte):Byte;Begin
 Case(Num)and$7of
  0:GetReg8Bits:=Regs.AL;
  1:GetReg8Bits:=Regs.CL;
  2:GetReg8Bits:=Regs.DL;
  3:GetReg8Bits:=Regs.BL;
  4:GetReg8Bits:=Regs.AH;
  5:GetReg8Bits:=Regs.CH;
  6:GetReg8Bits:=Regs.DH;
  7:GetReg8Bits:=Regs.BH;
 End;
End;

Procedure MakeIntrAddr;
Var
 I:Byte;
 ByteWrited:Word;
 Tbl:Array[0..255]of LongInt;
Begin
 For I:=0to 255do Tbl[I]:=I+1;
 Seek(Memory,0);
 BlockWrite(Memory,Tbl,SizeOf(Tbl),ByteWrited);
End;

Procedure ReadAbsBlock(Addr:LongInt;Var Buffer;SizeOf:Word);
Var
 ByteReaded:Word;
Begin
 Seek(Memory,Addr);
 BlockRead(Memory,Buffer,SizeOf,ByteReaded);
End;

Procedure ReadBlock(Seg,Ofs:Word;Var Buffer;SizeOf:Word);
Var
 Addr:LongInt;
 ByteReaded:Word;
Begin
 Addr:=AddrExt2Conv(Seg,Ofs);
 Seek(Memory,Addr);
 BlockRead(Memory,Buffer,SizeOf,ByteReaded);
End;

Function ReadWord(Seg,Ofs:Word):Word;
Var
 X:Word;
Begin
 ReadBlock(Seg,Ofs,X,SizeOf(X));
 ReadWord:=X;
End;

Procedure WriteAbsBlock(Addr:LongInt;Var Buffer;SizeOf:Word);
Var
 ByteWrited:Word;
 PBuffer:^TByte Absolute Buffer;
Begin
 Seek(Memory,Addr);
 BlockWrite(Memory,Buffer,SizeOf,ByteWrited);
End;

Procedure WriteBlock(Seg,Ofs:Word;Var Buffer;SizeOf:Word);
Var
 Addr:LongInt;
 ByteWrited:Word;
 PBuffer:^TByte Absolute Buffer;
Begin
 Addr:=AddrExt2Conv(Seg,Ofs);
{ If((Addr shr 4)and$FFFFF800=GetVideoSeg)Then Begin
  Move(Buffer,Mem[Seg:Ofs],SizeOf);
  End;}
{ If SizeOf>$8000Then Begin
  XSetAbsRec(Q.Memory,AddrExt2Conv(Ptr(Seg,Ofs+$8000)),SizeOf-$8000,PBuffer^[$8000]);
 End;}
 Seek(Memory,Addr);
 BlockWrite(Memory,Buffer,SizeOf,ByteWrited);
End;

Procedure WriteByte(Seg,Ofs:Word;X:Byte);Begin
 WriteBlock(Seg,Ofs,X,SizeOf(X));
End;

Procedure WriteWord(Seg,Ofs,X:Word);Begin
 WriteBlock(Seg,Ofs,X,SizeOf(X));
End;

Procedure InitComputer;
Var
 J:Word;
 ByteWrited,ByteReaded:Word;
 ClrBuffer:Array[0..1023]of Byte;
 S:String;
Begin
 CodeBrk:=-1;
 FillChar(ParityTable,SizeOf(ParityTable),0);
 {$I-}Assign(Memory,SwapFileMemory);
 Rewrite(Memory,1);{$I+}
 If IOResult<>0 Then Begin
  WriteLn('Impossible de crÇer un fichier temporaire pour la mÇmoire');
  Halt(1);
 End;
 FillChar(ClrBuffer,SizeOf(ClrBuffer),0);
 For J:=0to 1023do Begin
  Seek(Memory,LongInt(J) shl 10);
  BlockWrite(Memory,ClrBuffer,SizeOf(ClrBuffer),ByteWrited);
 End;
  { Configure le matÇriel }
 Case ModelComputer of
  mcIBMPC:Begin
   Include(Option,soSETALC);
   WriteWord(0,$0413,640);
  End;
  mcPC_XT:Begin
   Include(Option,soSETALC);
   WriteWord(0,$0413,640);
  End;
  mcPCJunior:Begin
   Include(Option,soSETALC);
   WriteWord(0,$0413,256);
  End;
  mcOlivettiM24:Begin
   CPU:=cpu8086;
   WriteWord(0,$0413,640);
  End;
  mcAmdekSystem88:Begin
   CPU:=cpu8088;
   WriteWord(0,$0413,640);
  End;
  mcContermMax:Begin
   CPU:=cpu8088;
   WriteWord(0,$0413,512);
  End;
  mcPC_AT:Begin
   CPU:=cpu80286;
   Include(Option,soSETALC);
   WriteWord(0,$0413,640);
  End;
  Else Begin
   WriteWord(0,$0413,640);
  End;
 End;
 MakeIntrAddr;
  { Fabrique la ROM }
 Case ModelComputer of
  mcIBMPC:Begin
   S:='IBM';
   WriteBlock($FE00,$0E,S,Length(S));
   S:=#$FF;
   WriteBlock($FFFF,$0E,S,Length(S));
  End;
  mcPC_XT:Begin
   S:='IBM';
   WriteBlock($FE00,$0E,S,Length(S));
   S:=#$FE;
   WriteBlock($FFFF,$0E,S,Length(S));
  End;
  mcPCJunior:Begin
   S:='IBM';
   WriteBlock($FE00,$0E,S,Length(S));
   S:=#$FD;
   WriteBlock($FFFF,$0D,S,Length(S));
  End;
  mcPC_AT:Begin
   S:='IBM';
   WriteBlock($FE00,$0E,S,Length(S));
   S:=#$FC;
   WriteBlock($FFFF,$0E,S,Length(S));
  End;
  mcOlivettiM24:Begin
   S:=#$FE;
   WriteBlock($FFFF,$0E,S,Length(S));
  End;
  mcContermMax:Begin
   S:=#$55;
   WriteBlock($FFFF,$0E,S,Length(S));
  End;
  mcWang:Begin
   S:='WANG';
   WriteBlock($FFFC,$02,S,Length(S));
   S:=#$FF;
   WriteBlock($FFFF,$0E,S,Length(S));
  End;
  mcAmdekSystem88:Begin
   S:='Copyright 1984,1985 Phoenix Software Associates Ltd.';
   WriteBlock($F000,$05,S,Length(S));
   S:='WYSE COPR. IBM Compatible';
   WriteBlock($F200,$04,S,Length(S));
   S:='Real Time Clock Battery Problem Detected';
   WriteBlock($F072,$03,S,Length(S));
   S:=#$FE;
   WriteBlock($FFFF,$0E,S,Length(S));
  End;
 End;
End;

Procedure S86MoveLeft(DS,SI,ES,DI,CX:Word);
Var
 Ptr:Pointer;
Begin
 GetMem(Ptr,CX);
 If(Ptr<>NIL)Then Begin
  If(DF)in(Flags.s)Then Begin { Sens inverse? }
   ReadBlock(DS,SI-CX,Ptr^,CX);
   WriteBlock(ES,DI-CX,Ptr^,CX);
  End
   Else
  Begin
   ReadBlock(DS,SI,Ptr^,CX);
   WriteBlock(ES,DI,Ptr^,CX);
  End;
  FreeMem(Ptr,CX);
 End;
End;

Procedure S86FillChar(ES,DI,CX:Word;AL:Byte);
Var
 Ptr:Pointer;
Begin
 If CX<>0 Then Begin
  GetMem(Ptr,CX);
  If(Ptr<>NIL)Then Begin
   FillChar(Ptr^,CX,AL);
   If(DF)in(Flags.s)Then Begin { Sens inverse? }
    WriteBlock(ES,DI-CX,Ptr^,CX);
   End
    Else
   Begin
   WriteBlock(ES,DI,Ptr^,CX);
   End;
   FreeMem(Ptr,CX);
  End;
 End;
End;

Procedure S86FillWord(ES,DI,CX,AX:Word);
Type
 TWord=Array[0..32000]of Word;
Var
 Ptr:^TWord;
 I:Integer;
Begin
 If CX<>0 Then Begin
  GetMem(Ptr,CX);
  If(Ptr<>NIL)Then Begin
   For I:=0 to(CX shr 1)-1do Begin
    Ptr^[I]:=AX;
   End;
   If(DF)in(Flags.s)Then Begin { Sens inverse? }
    WriteBlock(ES,DI-CX,Ptr^,CX);
   End
    Else
   Begin
    WriteBlock(ES,DI,Ptr^,CX);
   End;
   FreeMem(Ptr,CX);
  End;
 End;
End;

Procedure S86CompareByte(DS,SI,ES,DI,CX:Word);
Type
 TByte=Array[0..65520]of Byte;
Var
 Tmp:Byte;
 PtrSource,PtrDest:^TByte;
Begin
 GetMem(PtrSource,CX);
 If(PtrSource<>NIL)Then Begin
  GetMem(PtrDest,CX);
  If(PtrDest<>NIL)Then Begin
   If(DF)in(Flags.s)Then Begin { Sens inverse? }
    ReadBlock(DS,SI-CX,PtrSource^,CX);
    ReadBlock(ES,DI-CX,PtrDest^,CX);
   End
    Else
   Begin
    ReadBlock(DS,SI,PtrSource^,CX);
    ReadBlock(ES,DI,PtrDest^,CX);
   End;
   For I:=0 to CX-1 do Begin
    Tmp:=PtrDest^[I]-PtrSource^[I];
    If(Tmp and $100)=$100 Then Include(Flags.s,CF)
                          Else Exclude(Flags.s,CF);
    If(PtrDest^[I] xor PtrSource^[I])and(PtrDest^[I] xor Tmp) and $80<>0 Then Include(Flags.s,_OF)
                                                                         Else Exclude(Flags.s,_OF);
    If(Tmp xor PtrSource^[I] xor PtrDest^[I]) and $10<>0 Then Include(Flags.s,AF)
                                                         Else Exclude(Flags.s,AF);
    SetZFB(Byte(Tmp));
    SetSFB(Byte(Tmp));
    SetPF(Byte(Tmp));
   End;
   FreeMem(PtrDest,CX);
  End;
  FreeMem(PtrSource,CX);
 End;
End;


Procedure PushWordStack(Value:Word);
Var
 ByteReaded:Word;
Begin
 Dec(Regs.SP,SizeOf(Value));
 Seek(Memory,AddrExt2Conv(Segs.SS,Regs.SP));
 BlockWrite(Memory,Value,SizeOf(Value),ByteReaded);
End;

Procedure S86AdcByte(Var Source:Byte;Dest:Byte);
Var
 R:Integer;
Begin
 R:=Dest+Source;
 If(CF in Flags.s)Then Inc(R);
 If(R and $FF00<>0)Then Include(Flags.s,CF)
                   Else Exclude(Flags.s,CF);
 If(((dest xor source) and (dest xor R)) and $80)<>0 Then Include(Flags.s,_OF)
                                                     Else Exclude(Flags.s,_OF);
 If((dest xor source xor R) and $10)<>0 Then Include(Flags.s,AF)
                                        Else Exclude(Flags.s,AF);
 SetZFB(Byte(R));
 SetSFB(Byte(R));
 SetPF(Byte(R));
 Source:=Byte(R);
End;

Function S86AdcByteF(Source,Dest:Byte):Byte;
Var
 R:Integer;
Begin
 R:=Dest+Source;
 If(CF in Flags.s)Then Inc(R);
 If(R and $FF00<>0)Then Include(Flags.s,CF)
                   Else Exclude(Flags.s,CF);
 If(((dest xor source) and (dest xor R)) and $80)<>0 Then Include(Flags.s,_OF)
                                                     Else Exclude(Flags.s,_OF);
 If((dest xor source xor R) and $10)<>0 Then Include(Flags.s,AF)
                                        Else Exclude(Flags.s,AF);
 SetZFB(Byte(R));
 SetSFB(Byte(R));
 SetPF(Byte(R));
 S86AdcByteF:=Byte(R);
End;

Procedure S86AdcWord(Var Source:Word;Dest:Word);
Var
 R:LongInt;
Begin
 R:=Dest+Source;
 If(CF in Flags.s)Then Inc(R);
 If(R and $FFFF0000<>0)Then Include(Flags.s,CF)
                       Else Exclude(Flags.s,CF);
 If(((Dest xor Source) and (Dest xor R)) and $8000)<>0 Then Include(Flags.s,_OF)
                                                       Else Exclude(Flags.s,_OF);
 If((Dest xor Source xor R) and $10)<>0 Then Include(Flags.s,AF)
                                        Else Exclude(Flags.s,AF);
 SetZFW(Word(R));
 SetSFW(Word(R));
 SetPF(Byte(R));
 Source:=Word(R);
End;

Function S86AdcWordF(Source,Dest:Word):Word;
Var
 R:LongInt;
Begin
 R:=Dest+Source;
 If(CF in Flags.s)Then Inc(R);
 If(R and $FFFF0000<>0)Then Include(Flags.s,CF)
                       Else Exclude(Flags.s,CF);
 If(((Dest xor Source) and (Dest xor R)) and $8000)<>0 Then Include(Flags.s,_OF)
                                                       Else Exclude(Flags.s,_OF);
 If((Dest xor Source xor R) and $10)<>0 Then Include(Flags.s,AF)
                                        Else Exclude(Flags.s,AF);
 SetZFW(Word(R));
 SetSFW(Word(R));
 SetPF(Byte(R));
 S86AdcWordF:=Word(R);
End;

Procedure S86AddByte(Var Source:Byte;Dest:Byte);
Var
 R:Integer;
Begin
 R:=Dest+Source;
 If(R and $FF00<>0)Then Include(Flags.s,CF)
                   Else Exclude(Flags.s,CF);
 If(((dest xor source) and (dest xor R)) and $80)<>0 Then Include(Flags.s,_OF)
                                                     Else Exclude(Flags.s,_OF);
 If((dest xor source xor R) and $10)<>0 Then Include(Flags.s,AF)
                                        Else Exclude(Flags.s,AF);
 SetZFB(Byte(R));
 SetSFB(Byte(R));
 SetPF(Byte(R));
 Source:=Byte(R);
End;

Function S86AddByteF(Source,Dest:Byte):Byte;
Var
 R:Integer;
Begin
 R:=Dest+Source;
 If(R and $FF00<>0)Then Include(Flags.s,CF)
                   Else Exclude(Flags.s,CF);
 If(((dest xor source) and (dest xor R)) and $80)<>0 Then Include(Flags.s,_OF)
                                                     Else Exclude(Flags.s,_OF);
 If((dest xor source xor R) and $10)<>0 Then Include(Flags.s,AF)
                                        Else Exclude(Flags.s,AF);
 SetZFB(Byte(R));
 SetSFB(Byte(R));
 SetPF(Byte(R));
 S86AddByteF:=Byte(R);
End;

Procedure S86AddWord(Var Source:Word;Dest:Word);
Var
 R:LongInt;
Begin
 R:=Dest+Source;
 If(R and $FFFF0000<>0)Then Include(Flags.s,CF)
                       Else Exclude(Flags.s,CF);
 If(((dest xor source) and (dest xor R)) and $8000)<>0 Then Include(Flags.s,_OF)
                                                       Else Exclude(Flags.s,_OF);
 If((dest xor source xor R) and $10) <> 0 Then Include(Flags.s,AF)
                                          Else Exclude(Flags.s,AF);
 SetZFW(Word(R));
 SetSFW(Word(R));
 SetPF(Byte(R));
 Source:=Word(R);
End;

Function S86AddWordF(Source,Dest:Word):Word;
Var
 R:LongInt;
Begin
 R:=Dest+Source;
 If(R and $FFFF0000<>0)Then Include(Flags.s,CF)
                       Else Exclude(Flags.s,CF);
 If(((dest xor source) and (dest xor R)) and $8000)<>0 Then Include(Flags.s,_OF)
                                                       Else Exclude(Flags.s,_OF);
 If((dest xor source xor R) and $10) <> 0 Then Include(Flags.s,AF)
                                          Else Exclude(Flags.s,AF);
 SetZFW(Word(R));
 SetSFW(Word(R));
 SetPF(Byte(R));
 S86AddWordF:=Word(R);
End;

Procedure S86AndByte(Var Source:Byte;Dest:Byte);Begin
 Dest:=Dest and Source;
 Exclude(Flags.s,CF);
 Exclude(Flags.s,_OF);
 Exclude(Flags.s,AF);
 SetZFB(Byte(Dest));
 SetSFB(Byte(Dest));
 SetPF(Byte(Dest));
 Source:=Dest;
End;

Function S86AndByteF(Source,Dest:Byte):Byte;Begin
 Dest:=Dest and Source;
 Exclude(Flags.s,CF);
 Exclude(Flags.s,_OF);
 Exclude(Flags.s,AF);
 SetZFB(Byte(Dest));
 SetSFB(Byte(Dest));
 SetPF(Byte(Dest));
 S86AndByteF:=Dest;
End;

Procedure S86AndWord(Var Source:Word;Dest:Word);Begin
 Dest:=Dest and Source;
 Exclude(Flags.s,CF);
 Exclude(Flags.s,_OF);
 Exclude(Flags.s,AF);
 SetZFW(Word(Dest));
 SetSFW(Word(Dest));
 SetPF(Byte(Dest));
 Source:=Dest;
End;

Function S86AndWordF(Source,Dest:Word):Word;Begin
 Dest:=Dest and Source;
 Exclude(Flags.s,CF);
 Exclude(Flags.s,_OF);
 Exclude(Flags.s,AF);
 SetZFW(Word(Dest));
 SetSFW(Word(Dest));
 SetPF(Byte(Dest));
 S86AndWordF:=Dest;
End;

Procedure S86BSWAP(Var Source:LongInt);
Var
 Tmp:Record
  T1,T2,T3,T4:Byte;
 End;
 SourceByte:Record
  A1,A2,A3,A4:Byte;
 End Absolute Source;
Begin
 Tmp.T1:=SourceByte.A1;
 Tmp.T2:=SourceByte.A2;
 Tmp.T3:=SourceByte.A3;
 Tmp.T4:=SourceByte.A4;
 SourceByte.A1:=Tmp.T4;
 SourceByte.A2:=Tmp.T3;
 SourceByte.A3:=Tmp.T2;
 SourceByte.A4:=Tmp.T1;
End;

Procedure S86CmpByte(Var Source:Byte;Dest:Byte);
Var
 Tmp:Word;
Begin
 Tmp:=Dest-Source;
 If(Tmp and $100)=$100 Then Include(Flags.s,CF)
                       Else Exclude(Flags.s,CF);
 If(Dest xor Source)and(Dest xor Tmp) and $80<>0 Then Include(Flags.s,_OF)
                                                 Else Exclude(Flags.s,_OF);
 If(Tmp xor Source xor Dest) and $10<>0 Then Include(Flags.s,AF)
                                        Else Exclude(Flags.s,AF);
 SetZFB(Byte(Tmp));
 SetSFB(Byte(Tmp));
 SetPF(Byte(Tmp));
End;

Function S86CmpByteF(Source,Dest:Byte):Byte;
Var
 Tmp:Word;
Begin
 Tmp:=Dest-Source;
 If(Tmp and $100)=$100 Then Include(Flags.s,CF)
                       Else Exclude(Flags.s,CF);
 If(Dest xor Source)and(Dest xor Tmp) and $80<>0 Then Include(Flags.s,_OF)
                                                 Else Exclude(Flags.s,_OF);
 If(Tmp xor Source xor Dest) and $10<>0 Then Include(Flags.s,AF)
                                        Else Exclude(Flags.s,AF);
 SetZFB(Byte(Tmp));
 SetSFB(Byte(Tmp));
 SetPF(Byte(Tmp));
 S86CmpByteF:=Source;
End;

Procedure S86CmpWord(Var Source:Word;Dest:Word);
Var
 Tmp:LongInt;
Begin
 Tmp:=Dest-Source;
 If(Tmp and $10000)=$10000 Then Include(Flags.s,CF)
                           Else Exclude(Flags.s,CF);
 If(Dest xor Source)and(Dest and Tmp) and $8000<>0 Then Include(Flags.s,_OF)
                                                   Else Exclude(Flags.s,_OF);
 If(Tmp xor Source xor Dest) and $10<>0 Then Include(Flags.s,AF)
                                        Else Include(Flags.s,AF);
 SetZFW(Word(Tmp));
 SetSFW(Word(Tmp));
 SetPF(Tmp);
End;

Function S86CmpWordF(Source,Dest:Word):Word;
Var
 Tmp:LongInt;
Begin
 Tmp:=Dest-Source;
 If(Tmp and $10000)=$10000 Then Include(Flags.s,CF)
                           Else Exclude(Flags.s,CF);
 If(Dest xor Source)and(Dest and Tmp) and $8000<>0 Then Include(Flags.s,_OF)
                                                   Else Exclude(Flags.s,_OF);
 If(Tmp xor Source xor Dest) and $10<>0 Then Include(Flags.s,AF)
                                        Else Include(Flags.s,AF);
 SetZFW(Word(Tmp));
 SetSFW(Word(Tmp));
 SetPF(Tmp);
 S86CmpWordF:=Source;
End;

Procedure S86DecByte(Var Source:Byte);
Var
 R:Integer;
Begin
 R:=Source-1;
 If(R and $FF00<>0)Then Include(Flags.s,CF)
                   Else Exclude(Flags.s,CF);
 If(R=$80)Then Include(Flags.s,_OF)
          Else Exclude(Flags.s,_OF);
 If(R xor ((R-1)) and $10)<>0 Then Include(Flags.s,AF)
                              Else Exclude(Flags.s,AF);
 SetZFB(Byte(R));
 SetSFB(Byte(R));
 SetPF(Byte(R));
 Source:=Byte(R);
End;

Function S86DecByteF(Source:Byte):Byte;
Var
 R:Integer;
Begin
 R:=Source-1;
 If(R and $FF00<>0)Then Include(Flags.s,CF)
                   Else Exclude(Flags.s,CF);
 If(R=$80)Then Include(Flags.s,_OF)
          Else Exclude(Flags.s,_OF);
 If(R xor ((R-1)) and $10)<>0 Then Include(Flags.s,AF)
                              Else Exclude(Flags.s,AF);
 SetZFB(Byte(R));
 SetSFB(Byte(R));
 SetPF(Byte(R));
 S86DecByteF:=Byte(R);
End;

Procedure S86DecWord(Var Source:Word);
Var
 R:LongInt;
Begin
 R:=Source-1;
 If(R and $FFFF0000<>0)Then Include(Flags.s,CF)
                       Else Exclude(Flags.s,CF);
 If(R=$7FFF)Then Include(Flags.s,_OF)
            Else Exclude(Flags.s,_OF);
 If(R xor ((R-1)) and $10)<>0 Then Include(Flags.s,AF)
                              Else Exclude(Flags.s,AF);
 SetZFW(Word(R));
 SetSFW(Word(R));
 SetPF(Byte(R));
 Source:=Word(R);
End;

Function S86DecWordF(Source:Word):Word;
Var
 R:LongInt;
Begin
 R:=Source-1;
 If(R and $FFFF0000<>0)Then Include(Flags.s,CF)
                       Else Exclude(Flags.s,CF);
 If(R=$7FFF)Then Include(Flags.s,_OF)
            Else Exclude(Flags.s,_OF);
 If(R xor ((R-1)) and $10)<>0 Then Include(Flags.s,AF)
                              Else Exclude(Flags.s,AF);
 SetZFW(Word(R));
 SetSFW(Word(R));
 SetPF(Byte(R));
 S86DecWordF:=Word(R);
End;

Procedure S86DivByte(Source:Byte);
Var
 Dividend,Quotient,Remainder:Integer;
Begin
 If Source=0 Then Begin
  DivisionException;
  Exit;
 End;
 Dividend:=Regs.AX;
 Quotient:=Dividend div Source;
 Remainder:=Dividend mod Source;
 If(Quotient>$FF)Then DivisionException;
 Regs.AH:=Remainder;
 Regs.AL:=Quotient;
End;

Procedure S86DivWord(Source:Word);
Var
 Dividend,Quotient,Remainder:LongInt;
Begin
 If Source=0 Then Begin
  DivisionException;
  Exit;
 End;
 Dividend:=(Regs.DX shl 16) or Regs.AX;
 Quotient:=Dividend div Source;
 Remainder:=Dividend mod Source;
 If(Quotient>$FFFF)Then DivisionException;
 Regs.DX:=Remainder;
 Regs.AX:=Quotient;
End;

Procedure S86IDivByte(Source:Byte);
Var
 Dividend,Quotient,Remainder:Integer;
Begin
 If Source=0 Then Begin
  DivisionException;
  Exit;
 End;
 Dividend:=Regs.AX;
 Quotient:=Dividend div Source;
 Remainder:=Dividend mod Source;
 If(Quotient>$7F)or(Quotient<-$7F)Then DivisionException;
 Regs.AH:=Remainder;
 Regs.AL:=Quotient;
End;

Procedure S86IDivWord(Source:Word);
Var
 Dividend,Quotient,Remainder:LongInt;
Begin
 If Source=0 Then Begin
  DivisionException;
  Exit;
 End;
 Dividend:=(Regs.DX shl 16) or Regs.AX;
 Quotient:=Dividend div Source;
 Remainder:=Dividend mod Source;
 If(Quotient>$7FFF)or(Quotient<-$7FFF)Then DivisionException;
 Regs.DX:=Remainder;
 Regs.AX:=Quotient;
End;

Procedure S86IMulByte(Source:Byte);
Var
 R:Integer;
Begin
 R:=(Source*Regs.AL) and $FFFF;
 SetSFB(Byte(R));
 SetPF(R);
 SetZFB(Byte(R));
 If((R and $FF80)<>$FF80)and((R and $FF80)<>$0000)Then Begin
  Include(Flags.s,CF);
  Include(Flags.s,_OF);
 End
  Else
 Begin
  Exclude(Flags.s,CF);
  Exclude(Flags.s,_OF);
 End;
 If(R=0)Then Include(Flags.s,ZF)
        Else Exclude(Flags.s,ZF);
 Regs.AH:=Hi(R);
 Regs.AL:=Lo(R);
End;

Procedure S86IMulWord(Source:Word);
Var
 R:LongInt;
Begin
 R:=Source*Regs.AX;
 SetSFB(Byte(R));
 SetPF(R);
 SetZFW(Word(R));
 If((R and $FFFF8000)<>$FFFF8000)and((R and $FFFF8000)<>$00000000)Then Begin
  Include(Flags.s,CF);
  Include(Flags.s,_OF);
 End
  Else
 Begin
  Exclude(Flags.s,CF);
  Exclude(Flags.s,_OF);
 End;
 If(R=0)Then Include(Flags.s,ZF)
        Else Exclude(Flags.s,ZF);
 Regs.DX:=LongRec(R).Hi;
 Regs.AX:=LongRec(R).Lo;
End;

Procedure S86IncByte(Var Source:Byte);
Var
 R:Integer;
Begin
 R:=Source+1;
 If(R and $FF00<>0)Then Include(Flags.s,CF)
                   Else Exclude(Flags.s,CF);
 If(R=$80)Then Include(Flags.s,_OF)
          Else Exclude(Flags.s,_OF);
 If(R xor ((R-1)) and $10)<>0 Then Include(Flags.s,AF)
                              Else Exclude(Flags.s,AF);
 SetZFB(Byte(R));
 SetSFB(Byte(R));
 SetPF(Byte(R));
 Source:=Byte(R);
End;

Function S86IncByteF(Source:Byte):Byte;
Var
 R:Integer;
Begin
 R:=Source+1;
 If(R and $FF00<>0)Then Include(Flags.s,CF)
                   Else Exclude(Flags.s,CF);
 If(R=$80)Then Include(Flags.s,_OF)
          Else Exclude(Flags.s,_OF);
 If(R xor ((R-1)) and $10)<>0 Then Include(Flags.s,AF)
                              Else Exclude(Flags.s,AF);
 SetZFB(Byte(R));
 SetSFB(Byte(R));
 SetPF(Byte(R));
 S86IncByteF:=Byte(R);
End;

Procedure S86IncWord(Var Source:Word);
Var
 R:LongInt;
Begin
 R:=Source+1;
 If(R and $FFFF0000<>0)Then Include(Flags.s,CF)
                       Else Exclude(Flags.s,CF);
 If(R=$8000)Then Include(Flags.s,_OF)
            Else Exclude(Flags.s,_OF);
 If(R xor ((R-1)) and $10)<>0 Then Include(Flags.s,AF)
                              Else Exclude(Flags.s,AF);
 SetZFW(Word(R));
 SetSFW(Word(R));
 SetPF(Byte(R));
 Source:=Word(R);
End;

Function S86IncWordF(Source:Word):Word;
Var
 R:LongInt;
Begin
 R:=Source+1;
 If(R and $FFFF0000<>0)Then Include(Flags.s,CF)
                       Else Exclude(Flags.s,CF);
 If(R=$8000)Then Include(Flags.s,_OF)
            Else Exclude(Flags.s,_OF);
 If(R xor ((R-1)) and $10)<>0 Then Include(Flags.s,AF)
                              Else Exclude(Flags.s,AF);
 SetZFW(Word(R));
 SetSFW(Word(R));
 SetPF(Byte(R));
 S86IncWordF:=Word(R);
End;

Procedure S86Int(Num:Byte);
Var
 L,PB:LongInt;
 Size:Integer;
 Tampon:Array[0..511]of Byte;
 TamponChr:Array[0..511]of Char Absolute Tampon;
 TamponStr:String Absolute Tampon;
 Ptr:Pointer;
 I:Word;
 Month,WDay,Hour,Minute,Second,Sec100,THandle:Word;
 BoolValue:Boolean;
 ByteReaded:Word;
Begin
 Seek(Memory,Num shl 2);
 BlockRead(Memory,L,SizeOf(L),ByteReaded);
 If(L=Num+1)Then Begin
  If(Debug)Then WriteLn('Interruption ',ByteHex2Str(Num),'h statique');
  Case(Num)of
   $10:Begin { Emulation de l'interruption vidÇo }
    Case(Regs.AH)of
     $02:Begin
      GotoXY(Regs.DL+1,Regs.DH+1);
     End;
     $03:Begin
      Regs.DL:=WhereX;
      Regs.DH:=WhereY;
     End;
     $06:Begin
      {WEScrollDn(Q.AppW,Q.Reg.CL,Q.Reg.CH,Q.Reg.DL,Q.Reg.DH);
      WESetKr(Q.AppW,Q.Reg.BH);
      WEBarSpcHor(Q.AppW,Q.Reg.CL,Q.Reg.CH,Q.Reg.DL);}
     End;
     $07:Begin
      {WEScrollUp(Q.AppW,Q.Reg.CL,Q.Reg.CH,Q.Reg.DL,Q.Reg.DH);
      WESetKr(Q.AppW,Q.Reg.BH);
      WEBarSpcHor(Q.AppW,Q.Reg.CH,Q.Reg.CH,Q.Reg.DL);}
     End;
     $08:Begin
      {Q.Reg.AX:=GetCube(WEGetRX1(Q.AppW)+Q.AppW.X,WEGetRY1(Q.AppW)+Q.AppW.Y);}
     End;
     $09:Begin
      {WESetKr(Q.AppW,Q.Reg.BL);
      WEBarTxtHor(Q.AppW,Q.AppW.X,Q.AppW.Y,Q.AppW.X+Q.Reg.CX,Chr(Q.Reg.AL));}
     End;
     $0A:Begin
      {BarChrHor(WEGetRX1(Q.AppW)+Q.AppW.X,WEGetRY1(Q.AppW)+Q.AppW.Y,
                WEGetRX1(Q.AppW)+Q.AppW.X+Q.Reg.CX,Chr(Q.Reg.AL));}
     End;
     $0C:Begin
      {SetPixel((WEGetRX1(Q.AppW)shl 3)+Q.Reg.CX,
               GetRawY(WEGetRX1(Q.AppW))+Q.Reg.DX,Q.Reg.AL);}
     End;
     $0D:Begin
      {Q.Reg.AL:=GetPixel((WEGetRX1(Q.AppW)shl 3)+Q.Reg.CX,
                         GetRawY(WEGetRX1(Q.AppW))+Q.Reg.DX);}
     End;
     $0E:Begin
      Case(Regs.AL)of
       $0D:WriteLn;
       $0A:;
       Else Begin
        TextBackground(Regs.BL shr 4);
        TextColor(Regs.BL and $F);
        Write(Chr(Regs.AL));
       End;
      End;
     End;
     $0F:Begin
      Regs.AL:=3;  { NumÇro de mode vidÇo }
      Regs.AH:=80; { Nombre de colonne }
      Regs.BH:=0;  { NumÇro de page courant }
     End;
     $1A:If Regs.AL=0Then Begin
{      Case(GetVideoCardCat)of
       cvnMDA,cvnHGC:Q.Reg.BL:=1;
       cvnCGA:Q.Reg.BL:=2;
       cvnEGA:If(ColorFound)Then Q.Reg.BL:=4
                            Else Q.Reg.BL:=5;
       cvnVGA,cvnSvga,cvnVESA:If(ColorFound)Then Q.Reg.BL:=8 Else Q.Reg.BL:=7;
      End;}
      Regs.BH:=0;
      Regs.AL:=$1A;
     End;
    End;
   End;
   $13:Case(Regs.AH)of { Emulation de l'interruption vidÇo }
    $02..$05,$07,$0A..$0B:Begin
     If(Regs.AH)in[3,5,7,$B]Then ReadBlock(Segs.ES,Regs.BX,Tampon,512);
     If(Regs.AH)in[2,4,$A]Then WriteBlock(Segs.ES,Regs.BX,Tampon,512);
    End;
   End;
   $19:Fault:=sfHotBoot;
   $18,$1B,$1C:;
   $1D..$1F:Fault:=sfInvalidIntr;
   $20:Fault:=sfEndProgram;
   $21:Case(Regs.AH)of
    $00:Fault:=sfEndProgram;
    $01:Begin
     Regs.AL:=Byte(ReadKey);
     Write(Char(Regs.AL));
    End;
    $02:Write(Chr(Regs.DL));
    $07,$08:Regs.AL:=Byte(ReadKey);
    $09:Begin
     ReadBlock(Segs.DS,Regs.DX,Tampon,512);
     For I:=0to 511do Begin
      Case TamponChr[I]of
       '$':Break;
       #13:WriteLn;
       #10:;
       Else Write(TamponChr[I]);
      End;
     End;
    End;
    $0A:Begin
     ReadLn(TamponStr);
     ReadBlock(Segs.DS,Regs.DX+1,ByteReaded,1);
     If ByteReaded<Length(TamponStr)Then TamponStr[0]:=Char(ByteReaded);
     WriteBlock(Segs.DS,Regs.DX+1,TamponStr,Length(TamponStr)+1);
    End;
    $0B:Begin { Demande l'Çtat de la console }
     If(Keypressed)Then Regs.AL:=255
                   Else Regs.AL:=0;
    End;
    $0C:Begin
     While(Keypressed)do ReadKey;
     Case Regs.AL of
      $01:Begin
       Regs.AL:=Byte(ReadKey);
       Write(Char(Regs.AL));
      End;
      $02:Write(Chr(Regs.DL));
      $07,$08:Regs.AL:=Byte(ReadKey);
      $0A:Begin
       ReadLn(TamponStr);
       ReadBlock(Segs.DS,Regs.DX+1,ByteReaded,1);
       If ByteReaded<Length(TamponStr)Then TamponStr[0]:=Char(ByteReaded);
       WriteBlock(Segs.DS,Regs.DX+1,TamponStr,Length(TamponStr)+1);
      End;
     End;
    End;
    $0E:Begin { SÇlectionne un disque (Select Disk) }
     {$I-}ChDir(Chr(Regs.DL+65)+':');{$I+}
     If IoResult<>0Then Regs.AL:=$FF
                   Else Regs.AL:=0;
    End;
    $19:Begin
     Regs.AL:=Ord(GetCurrentDisk)-Ord('A');
    End;
    $25:Begin { Fixe une adresse d'interruption }
     LongRec(L).Hi:=Segs.DS;
     LongRec(L).Lo:=Regs.DX;
     WriteBlock(0,Regs.AL shl 2,L,4);
    End;
    $2A:Begin
     GetDate(Regs.CX,Month,Regs.DX,WDay);
     Regs.DH:=Month;
     Regs.AL:=WDay;
    End;
    $2C:Begin
     GetTime(Hour,Minute,Second,Sec100);
     Regs.CH:=Hour;
     Regs.CL:=Minute;
     Regs.DH:=Second;
     Regs.DL:=Sec100;
    End;
    $2E:If Not(ReadOnlyMachine)Then SetVerify(Boolean(Regs.AL));
    $30:Begin { Demande la version DOS }
     Regs.AX:=DOSVersion;
     Regs.BH:=0 {OEMVersion};
    End;
    $33:Case(Regs.AL)of
     $00:Begin
      GetCBreak(BoolValue);
      Regs.DL:=Byte(BoolValue);
     End;
     $01:If Not(ReadOnlyMachine)Then SetCBreak(Boolean(Regs.DL));
     $05:Regs.DX:=0 {UnitÇ de dÇmarrage};
     $06:Begin
      Regs.AL:=$FF;
      Regs.BX:=DOSVersion;
      Regs.DL:=0;
      Regs.DH:=(1 shl 3); { DOS en ROM }
     End;
    End;
    $35:Begin { Demande une adresse d'interruption }
     ReadBlock(0,Regs.AL shl 2,L,4);
     Segs.ES:=LongRec(L).Hi;
     Regs.DI:=LongRec(L).Lo;
    End;
    $36:Begin
     Regs.AX:=4;
     Regs.CX:=512;
     Regs.BX:=Word(DiskFree(Regs.DL) shr 11);
     Regs.DX:=Word(DiskSize(Regs.DL) shr 11);
    End;
    $37:Case Regs.AL of
     $00:Regs.DL:=Ord('/');
    End;
    $38:Case Regs.AL of
     $00:Begin
      WriteWord(Segs.DS,Regs.DX,2); { AnnÇe-Mois-Jour }
      WriteWord(Segs.DS,Regs.DX+$02,Byte('$'));
      WriteWord(Segs.DS,Regs.DX+$07,Byte(' '));
      WriteWord(Segs.DS,Regs.DX+$09,Byte(','));
      WriteWord(Segs.DS,Regs.DX+$0B,Byte('-'));
      WriteWord(Segs.DS,Regs.DX+$0D,Byte(':'));
      WriteByte(Segs.DS,Regs.DX+$0B,(1 shl 0)+(1 shl 1));
      WriteWord(Segs.DS,Regs.DX+$10,2);
      WriteWord(Segs.DS,Regs.DX+$11,1);
      WriteWord(Segs.DS,Regs.DX+$12,0); { Base NIL }
      WriteWord(Segs.DS,Regs.DX+$14,0); { Segment NIL }
      WriteWord(Segs.DS,Regs.DX+$16,Byte(','));
     End;
    End;
    $39:Begin
     If(ReadOnlyMachine)Then Begin
      Include(Flags.s,CF);
      Regs.AX:=5;
     End
      Else
     Begin
      ReadBlock(Segs.DS,Regs.DX,Tampon,256);
      {$I-}MkDir(StrPas(TamponChr));{$I+}
      Regs.AX:=IOResult;
      If Regs.AX=0 Then Exclude(Flags.s,CF)
                   Else Include(Flags.s,CF);
     End;
    End;
    $3A:Begin
     If(ReadOnlyMachine)Then Begin
      Include(Flags.s,CF);
      Regs.AX:=5;
     End
      Else
     Begin
      ReadBlock(Segs.DS,Regs.DX,Tampon,256);
      {$I-}RmDir(StrPas(TamponChr));{$I+}
      Regs.AX:=IOResult;
      If Regs.AX=0 Then Exclude(Flags.s,CF)
                   Else Include(Flags.s,CF);
     End;
    End;
    $3B:Begin
     ReadBlock(Segs.DS,Regs.DX,Tampon,256);
     {$I-}ChDir(StrPas(TamponChr));{$I+}
     Regs.AX:=IOResult;
     If Regs.AX=0 Then Exclude(Flags.s,CF)
      Else
     Begin
      Include(Flags.s,CF);
      Regs.AX:=2;
     End;
    End;
    $3C:Begin { CrÇe un fichier }
     If(ReadOnlyMachine)Then Begin
      Include(Flags.s,CF);
      Regs.AX:=5;
     End
      Else
     Begin
      If CurrFilesHandles>=High(FilesHandles)Then Begin
       BoolValue:=False;
       For I:=Low(FilesHandlesUsed) to High(FilesHandlesUsed)do Begin
        If Not FilesHandlesUsed[I]Then Begin
         BoolValue:=True;
         THandle:=I;
         Break;
        End;
       End;
       If Not(BoolValue)Then Begin
        Include(Flags.s,CF);
        Exit;
       End;
      End
       Else
      Begin
       THandle:=CurrFilesHandles;
       Inc(CurrFilesHandles);
      End;
      ReadBlock(Segs.DS,Regs.DX,Tampon,256);
      {$I-}Assign(FilesHandles[THandle],StrPas(TamponChr));
      Rewrite(FilesHandles[THandle],1);{$I+}
      Regs.AX:=IOResult;
      If Regs.AX=0 Then Begin
       Exclude(Flags.s,CF);
       Regs.AX:=THandle;
       FilesHandlesUsed[THandle]:=True;
      End
       Else
      Begin
       Include(Flags.s,CF);
      End;
     End;
    End;
    $3D:Begin { Ouvre un fichier }
     If CurrFilesHandles>=High(FilesHandles)Then Begin
      BoolValue:=False;
      For I:=Low(FilesHandlesUsed) to High(FilesHandlesUsed)do Begin
       If Not FilesHandlesUsed[I]Then Begin
        BoolValue:=True;
        THandle:=I;
        Break;
       End;
      End;
      If Not(BoolValue)Then Begin
       Include(Flags.s,CF);
       Exit;
      End;
     End
      Else
     Begin
      THandle:=CurrFilesHandles;
      Inc(CurrFilesHandles);
     End;
     ReadBlock(Segs.DS,Regs.DX,Tampon,256);
     {$I-}Assign(FilesHandles[THandle],StrPas(TamponChr));
     Reset(FilesHandles[THandle],1);{$I+}
     Regs.AX:=IOResult;
     If Regs.AX=0 Then Begin
      Exclude(Flags.s,CF);
      Regs.AX:=THandle;
      FilesHandlesUsed[THandle]:=True;
     End
      Else
     Begin
      Include(Flags.s,CF);
     End;
    End;
    $3E:Begin { Ferme le fichier }
     If Regs.BX in [10..25]Then Begin
      {$I-}Close(FilesHandles[Regs.BX]);{$I+}
      FilesHandlesUsed[Regs.BX]:=False;
      Regs.AX:=IOResult;
      If Regs.AX=0 Then Exclude(Flags.s,CF)
                   Else Include(Flags.s,CF);
      If Regs.BX+1=CurrFilesHandles Then Dec(CurrFilesHandles);
     End
      ELse
     Begin
      Include(Flags.s,CF);
      Regs.AX:=6;
     End;
    End;
    $3F:Begin { Lecture d'un bloc }
     L:=Regs.CX;
     PB:=Regs.DX;
     Regs.AX:=0;
     While L>0 do Begin
      If L-SizeOf(Tampon)>0 Then Begin
       Size:=SizeOf(Tampon);
       L:=L-SizeOf(Tampon);
      End
       Else
      Begin
       Size:=L;
       L:=0;
      End;
      BlockRead(FilesHandles[Regs.BX],Tampon,Size,ByteReaded);
      WriteBlock(Segs.DS,PB,Tampon,ByteReaded);
      Inc(PB,ByteReaded);
      Regs.AX:=Regs.AX+ByteReaded;
     End;
    End;
    $40:If(ReadOnlyMachine)Then Begin
     Include(Flags.s,CF);
     Regs.AX:=5;
    End
     Else
    Begin { êcriture d'un bloc }
     L:=Regs.CX;
     PB:=Regs.DX;
     Regs.AX:=0;
     While L>0 do Begin
      If L-SizeOf(Tampon)>0 Then Begin
       Size:=SizeOf(Tampon);
       L:=L-SizeOf(Tampon);
      End
       Else
      Begin
       Size:=L;
       L:=0;
      End;
      ReadBlock(Segs.DS,PB,Tampon,Size);
      BlockWrite(FilesHandles[Regs.BX],Tampon,Size,ByteReaded);
      Inc(PB,ByteReaded);
      Regs.AX:=Regs.AX+ByteReaded;
     End;
    End;
    $4C:Begin
     Fault:=sfEndProgram;
    End;
    $50:Begin { DÇfinir PSP actif }
     PSP:=Regs.BX;
     Regs.AX:=0;
     Exclude(Flags.s,CF);
    End;
   End;
   $29:Write(Regs.AL); { Interruption 29h }
   $2E:Begin { Interrupiton 2Eh }
    ReadBlock(Segs.DS,Regs.SI,TamponStr,256);
    Exec(TamponStr,'');
   End;
   $33:Case(Regs.AX)of { Interruption 33h }
    1:{__ShowMousePtr};
    2:{__HideMousePtr};
   End;
  End;
 End
  Else
 Begin
  Include(Flags.s,_IF);
  PushWordStack(Segs.CS);
  PushWordStack(IP);
  Segs.CS:=LongRec(L).Hi;
  IP:=LongRec(L).Lo;
 End;
End;

Procedure S86MulByte(Source:Byte);
Var
 R:Integer;
Begin
 R:=(Source*Regs.AL) and $FFFF;
 SetSFB(Byte(R));
 SetPF(R);
 SetZFB(Byte(R));
 If(R and $FF00) <> 0 Then Begin
  Include(Flags.s,CF);
  Include(Flags.s,_OF);
 End
  Else
 Begin
  Exclude(Flags.s,CF);
  Exclude(Flags.s,_OF);
 End;
 If R=0 Then Include(Flags.s,ZF)
        Else Exclude(Flags.s,ZF);
 Regs.AH:=Hi(R);
 Regs.AL:=Lo(R);
End;

Procedure S86MulWord(Source:Word);
Var
 R:LongInt;
Begin
 R:=Source*Regs.AX;
 SetSFB(Byte(R));
 SetPF(R);
 SetZFW(Word(R));
 If(((R and $FFFF8000)<>$FFFF8000)and((R and $FFFF8000)<>$00000000))Then Begin
  Include(Flags.s,CF);
  Include(Flags.s,_OF);
 End
  Else
 Begin
  Exclude(Flags.s,CF);
  Exclude(Flags.s,_OF);
 End;
 If R=0 Then Include(Flags.s,ZF)
        Else Exclude(Flags.s,ZF);
 Regs.DX:=LongRec(R).Lo;
 Regs.AX:=Word(R);
End;

Procedure S86NegByte(Var Source:Byte);
Var
 R:Integer;
Begin
 R:=(0-Source)and $FF;
 SetZFB(Source);
 SetSFB(Source);
 SetPF(Source);
 If Source<>0 Then Include(Flags.s,CF)
              Else Exclude(Flags.s,CF);
 If R=$80 Then Include(Flags.s,_OF)
          Else Exclude(Flags.s,_OF);
 If(R and $0F)<>0 Then Include(Flags.s,AF)
                  Else Exclude(Flags.s,AF);
End;

Procedure S86NegWord(Var Source:Word);
Var
 R:LongInt;
Begin
 R:=(0-Source) and $FFFF;
 SetZFW(Source);
 SetSFW(Source);
 SetPF(Source);
 If Source<>0 Then Include(Flags.s,CF)
              Else Exclude(Flags.s,CF);
 If R=$8000 Then Include(Flags.s,_OF)
            Else Exclude(Flags.s,_OF);
 If R and $0F<>0 Then Include(Flags.s,AF)
                 Else Exclude(Flags.s,AF);
End;

Procedure S86NotByte(Var Source:Byte);Begin
 Source:=Not Source;
End;

Procedure S86NotWord(Var Source:Word);Begin
 Source:=Not Source;
End;

Procedure S86OrByte(Var Source:Byte;Dest:Byte);Begin
 Dest:=Dest or Source;
 Exclude(Flags.s,CF);
 Exclude(Flags.s,_OF);
 Exclude(Flags.s,AF);
 SetZFB(Dest);
 SetSFB(Dest);
 SetPF(Dest);
End;

Function S86OrByteF(Source,Dest:Byte):Byte;Begin
 Dest:=Dest or Source;
 Exclude(Flags.s,CF);
 Exclude(Flags.s,_OF);
 Exclude(Flags.s,AF);
 SetZFB(Dest);
 SetSFB(Dest);
 SetPF(Dest);
 S86OrByteF:=Dest;
End;

Procedure S86OrWord(Var Source:Word;Dest:Word);Begin
 Dest:=Dest or Source;
 Exclude(Flags.s,CF);
 Exclude(Flags.s,_OF);
 Exclude(Flags.s,AF);
 SetZFW(Dest);
 SetSFW(Dest);
 SetPF(Dest);
End;

Function S86OrWordF(Source,Dest:Word):Word;Begin
 Dest:=Dest or Source;
 Exclude(Flags.s,CF);
 Exclude(Flags.s,_OF);
 Exclude(Flags.s,AF);
 SetZFW(Dest);
 SetSFW(Dest);
 SetPF(Dest);
 S86OrWordF:=Dest;
End;

Procedure S86RolByte(Var Source:Byte;Count:Byte);
Var
 CFValue:Byte;
 Test1,Test2:Boolean;
Begin
 While Count>0 do Begin
  If(Source and $80)<>0 Then Begin
   Include(Flags.s,CF);
   CFValue:=1;
  End
   Else
  Begin
   Exclude(Flags.s,CF);
   CFValue:=0;
  End;
  Source:=(Source shl 1)or CFValue;
  Dec(count);
 End;
 Test1:=((Source and $80) = 0);
 Test2:=CF in Flags.s;
 If Test1<>Test2 Then Include(Flags.s,_OF)
                 Else Exclude(Flags.s,_OF);
End;

Procedure S86RolWord(Var Source:Word;Count:Byte);
Var
 CFValue:Word;
 Test1,Test2:Boolean;
Begin
 While Count>0 do Begin
  If(Source and $8000)<>0 Then Begin
   Include(Flags.s,CF);
   CFValue:=1;
  End
   Else
  Begin
   Exclude(Flags.s,CF);
   CFValue:=0;
  End;
  Source:=(Source shl 1) or CFValue;
  Dec(Count);
 End;
 Test1:=((Source and $8000)=0);
 Test2:=CF in Flags.s;
 If Test1<>Test2 Then Include(Flags.s,_OF)
                 Else Exclude(Flags.s,_OF);
End;

Procedure S86RorByte(Var Source:Byte;Count:Byte);
Var
 CFValue:Byte;
 Test1,Test2:Boolean;
Begin
 While Count>0 do Begin
  If (Source and $01)<>0 Then Begin
   Include(Flags.s,CF);
   CFValue:=1;
  End
   Else
  Begin
   Exclude(Flags.s,CF);
   CFValue:=0;
  End;
  Source:=(Source shr 1) or (CFValue shl 7);
  Dec(count);
 End;
 Test1:=(Source and $40)=0;
 Test2:=(Source and $80)=0;
 If Test1<>Test2 Then Include(Flags.s,_OF)
                 Else Exclude(Flags.s,_OF);
End;

Procedure S86RorWord(Var Source:Word;Count:Byte);
Var
 CFValue:Word;
 Test1,Test2:Boolean;
Begin
 While Count>0 do Begin
  If(Source and $01)<>0 Then Begin
   Include(Flags.s,CF);
   CFValue:=1;
  End
   Else
  Begin
   Exclude(Flags.s,CF);
   CFValue:=0;
  End;
  Source:=(Source shr 1)or(CFValue shl 15);
  Dec(Count);
 End;
 Test1:=(Source and $4000)=0;
 Test2:=(Source and $8000)=0;
 If Test1<>Test2 Then Include(Flags.s,_OF)
                 Else Exclude(Flags.s,_OF);
End;

Procedure S86SarByte(Var Source:Byte;Count:Byte);Begin
 If(((Source shr (Count-1)) and $01)<>0)Then Include(Flags.s,CF)
                                        Else Exclude(Flags.s,CF);
 While Count>0 do Begin
  Source:=(Source shr 1)or(Source and $80);
  Dec(count);
 End;
 SetSFB(Source);
 SetPF(Source);
 SetZFB(Source);
End;

Procedure S86SarWord(Var Source:Word;Count:Byte);Begin
 If(((Source shr (Count-1)) and $01)<>0)Then Include(Flags.s,CF)
                                        Else Exclude(Flags.s,CF);
 While Count>0 do Begin
  Source:=(Source shr 1)or(Source and $8000);
  Dec(Count);
 end;
 SetSFW(Source);
 SetZFW(Source);
 SetPF(Byte(Source));
End;

Procedure S86SbbByte(Var Source:Byte;Dest:Byte);
Var
 R:Integer;
Begin
 If(CF in Flags.s)Then Inc(Source);
 R:=Dest-Source;
 If(R and $FF00<>0)Then Include(Flags.s,CF)
                   Else Exclude(Flags.s,CF);
 If(((Dest xor Source) and (Dest xor R)) and $80)<>0 Then Include(Flags.s,_OF)
                                                     Else Exclude(Flags.s,_OF);
 If((Dest xor Source xor R) and $10)<>0 Then Include(Flags.s,AF)
                                        Else Exclude(Flags.s,AF);
 SetZFB(Byte(R));
 SetSFB(Byte(R));
 SetPF(Byte(R));
 Source:=Byte(R);
End;

Function S86SbbByteF(Source,Dest:Byte):Byte;
Var
 R:Integer;
Begin
 If(CF in Flags.s)Then Inc(Source);
 R:=Dest-Source;
 If(R and $FF00<>0)Then Include(Flags.s,CF)
                   Else Exclude(Flags.s,CF);
 If(((Dest xor Source) and (Dest xor R)) and $80)<>0 Then Include(Flags.s,_OF)
                                                     Else Exclude(Flags.s,_OF);
 If((Dest xor Source xor R) and $10)<>0 Then Include(Flags.s,AF)
                                        Else Exclude(Flags.s,AF);
 SetZFB(Byte(R));
 SetSFB(Byte(R));
 SetPF(Byte(R));
 S86SbbByteF:=Byte(R);
End;

Procedure S86SbbWord(Var Source:Word;Dest:Word);
Var
 R:LongInt;
Begin
 If(CF in Flags.s)Then Inc(Source);
 R:=Dest-Source;
 If(R and $FFFF0000<>0)Then Include(Flags.s,CF)
                       Else Exclude(Flags.s,CF);
 If(((dest xor source) and (dest xor R)) and $8000)<>0 Then Include(Flags.s,_OF)
                                                        Else Exclude(Flags.s,_OF);
 If((dest xor source xor R) and $10)<>0 Then Include(Flags.s,AF)
                                        Else Exclude(Flags.s,AF);
 SetZFW(Word(R));
 SetSFW(Word(R));
 SetPF(Byte(R));
 Source:=Word(R);
End;

Function S86SbbWordF(Source,Dest:Word):Word;
Var
 R:LongInt;
Begin
 If(CF in Flags.s)Then Inc(Source);
 R:=Dest-Source;
 If(R and $FFFF0000<>0)Then Include(Flags.s,CF)
                       Else Exclude(Flags.s,CF);
 If(((dest xor source) and (dest xor R)) and $8000)<>0 Then Include(Flags.s,_OF)
                                                        Else Exclude(Flags.s,_OF);
 If((dest xor source xor R) and $10)<>0 Then Include(Flags.s,AF)
                                        Else Exclude(Flags.s,AF);
 SetZFW(Word(R));
 SetSFW(Word(R));
 SetPF(Byte(R));
 S86SbbWordF:=Word(R);
End;

Procedure S86ShlByte(Var Source:Byte;Count:Byte);
Var
 CFValue:Boolean;
Begin
 If(Count>=9)Then Begin
  Exclude(Flags.s,CF);
  Source:=0;
 End
  Else
 Begin
  If(Source and ($100 shr Count))<>0 Then Include(Flags.s,CF)
                                     Else Exclude(Flags.s,CF);
  Source:=Source shl Count;
 End;
 If Not(CF in Flags.s)Then CFValue:=True
                      Else CFValue:=False;
 If(Not(Source and $80=$80))<>CFValue Then Include(Flags.s,_OF)
                                      Else Exclude(Flags.s,_OF);
 SetZFB(Source);
 SetSFB(Source);
 SetPF(Byte(Source));
End;

Procedure S86ShlWord(Var Source:Word;Count:Byte);
Var
 CFValue:Boolean;
Begin
 If Count>16 Then Begin
  Exclude(Flags.s,CF);
  Source:=0;
 End
  Else
 Begin
  If(Source and ($10000 shr Count))<>0 Then Include(Flags.s,CF)
                                       Else Exclude(Flags.s,CF);
  Source:=Source shl Count;
 End;
 If Not(CF in Flags.s)Then CFValue:=True
                      Else CFValue:=False;
 If(Not(Source and $8000=$8000))<>CFValue Then Include(Flags.s,_OF)
                                          Else Exclude(Flags.s,_OF);
 SetZFW(Source);
 SetSFW(Source);
 SetPF(Byte(Source));
End;

Procedure S86ShrByte(Var Source:Byte;Count:Byte);Begin
 If(Count>=9)Then Begin
  Exclude(Flags.s,CF);
  Source:=0;
 End
  Else
 Begin
  If((Source shr(Count-1))and $1)<>0 Then Include(Flags.s,CF)
                                     Else Exclude(Flags.s,CF);
  Source:=Source shr Count;
 End;
 SetSFB(Source);
 SetPF(Source);
 SetZFB(Byte(Source));
End;


Procedure S86ShrWord(Var Source:Word;Count:Byte);Begin
 If(Count>16)Then Begin
  Exclude(Flags.s,CF);
  Source:=0;
 End
  Else
 Begin
  If((Source shr(Count-1))and $1)<>0 Then Include(Flags.s,CF)
                                     Else Exclude(Flags.s,CF);
  Source:=Source shr Count;
 End;
 SetSFW(Source);
 SetZFW(Source);
 SetPF(Byte(Source));
End;

Procedure S86SubByte(Var Source:Byte;Dest:Byte);
Var
 R:Integer;
Begin
 R:=Dest-Source;
 If(R and $FF00<>0)Then Include(Flags.s,CF)
                   Else Exclude(Flags.s,CF);
 If(((dest xor source) and (dest xor R)) and $80)<>0 Then Include(Flags.s,_OF)
                                                     Else Exclude(Flags.s,_OF);
 If((dest xor source xor R) and $10)<>0 Then Include(Flags.s,AF)
                                        Else Exclude(Flags.s,AF);
 SetZFB(Byte(R));
 SetSFB(Byte(R));
 SetPF(Byte(R));
 Source:=Byte(R);
End;

Function S86SubByteF(Source,Dest:Byte):Byte;
Var
 R:Integer;
Begin
 R:=Dest-Source;
 If(R and $FF00<>0)Then Include(Flags.s,CF)
                   Else Exclude(Flags.s,CF);
 If(((dest xor source) and (dest xor R)) and $80)<>0 Then Include(Flags.s,_OF)
                                                     Else Exclude(Flags.s,_OF);
 If((dest xor source xor R) and $10)<>0 Then Include(Flags.s,AF)
                                        Else Exclude(Flags.s,AF);
 SetZFB(Byte(R));
 SetSFB(Byte(R));
 SetPF(Byte(R));
 S86SubByteF:=Byte(R);
End;

Procedure S86SubWord(Var Source:Word;Dest:Word);
Var
 R:LongInt;
Begin
 R:=Dest-Source;
 If(R and $FFFF0000<>0)Then Include(Flags.s,CF)
                       Else Exclude(Flags.s,CF);
 If(((dest xor source) and (dest xor R)) and $8000)<>0 Then Include(Flags.s,_OF)
                                                        Else Exclude(Flags.s,_OF);
 If((dest xor source xor R) and $10)<>0 Then Include(Flags.s,AF)
                                        Else Exclude(Flags.s,AF);
 SetZFW(Word(R));
 SetSFW(Word(R));
 SetPF(Byte(R));
 Source:=Word(R);
End;

Function S86SubWordF(Source,Dest:Word):Word;
Var
 R:LongInt;
Begin
 R:=Dest-Source;
 If(R and $FFFF0000<>0)Then Include(Flags.s,CF)
                       Else Exclude(Flags.s,CF);
 If(((dest xor source) and (dest xor R)) and $8000)<>0 Then Include(Flags.s,_OF)
                                                        Else Exclude(Flags.s,_OF);
 If((dest xor source xor R) and $10)<>0 Then Include(Flags.s,AF)
                                        Else Exclude(Flags.s,AF);
 SetZFW(Word(R));
 SetSFW(Word(R));
 SetPF(Byte(R));
 S86SubWordF:=Word(R);
End;

Procedure S86TestByte(Source,Dest:Byte);Begin
 Source:=Source and Dest;
 Exclude(Flags.s,CF);
 Exclude(Flags.s,_OF);
 Exclude(Flags.s,AF);
 SetZFB(Source);
 SetSFB(Source);
 SetPF(Source);
End;

Procedure S86TestWord(Source,Dest:Word);Begin
 Source:=Source and Dest;
 Exclude(Flags.s,CF);
 Exclude(Flags.s,_OF);
 Exclude(Flags.s,AF);
 SetZFW(Source);
 SetSFW(Source);
 SetPF(Source);
End;

Procedure S86XorByte(Var Source:Byte;Dest:Byte);Begin
 Dest:=Dest xor Source;
 Exclude(Flags.s,CF);
 Exclude(Flags.s,_OF);
 Exclude(Flags.s,AF);
 SetZFB(Dest);
 SetSFB(Dest);
 SetPF(Dest);
End;

Function S86XorByteF(Source,Dest:Byte):Byte;Begin
 Dest:=Dest xor Source;
 Exclude(Flags.s,CF);
 Exclude(Flags.s,_OF);
 Exclude(Flags.s,AF);
 SetZFB(Dest);
 SetSFB(Dest);
 SetPF(Dest);
 S86XorByteF:=Dest;
End;

Procedure S86XorWord(Var Source:Word;Dest:Word);Begin
 Dest:=Dest xor Source;
 Exclude(Flags.s,CF);
 Exclude(Flags.s,_OF);
 Exclude(Flags.s,AF);
 SetZFW(Dest);
 SetSFW(Dest);
 SetPF(Dest);
End;

Function S86XorWordF(Source,Dest:Word):Word;Begin
 Dest:=Dest xor Source;
 Exclude(Flags.s,CF);
 Exclude(Flags.s,_OF);
 Exclude(Flags.s,AF);
 SetZFW(Dest);
 SetSFW(Dest);
 SetPF(Dest);
 S86XorWordF:=Dest;
End;

Procedure S86IncCountString(Source,Dest:Boolean);Begin
 If(DF)in(Flags.s)Then Begin
  If(Source)Then S86DecWord(Regs.SI);
  If(Dest)Then S86DecWord(Regs.DI);
 End
  Else
 Begin
  If(Source)Then S86IncWord(Regs.SI);
  If(Dest)Then S86IncWord(Regs.DI);
 End;
End;

Procedure S86AddCountString(Step:Byte;Source,Dest:Boolean);Begin
 If(DF)in(Flags.s)Then Begin
  If(Source)Then S86SubWord(Regs.SI,Step);
  If(Dest)Then S86SubWord(Regs.DI,Step);
 End
  Else
 Begin
  If(Source)Then S86AddWord(Regs.SI,Step);
  If(Dest)Then S86AddWord(Regs.DI,Step);
 End;
End;

Procedure PushDWordStack(Value:LongInt);
Var
 ByteReaded:Word;
Begin
 Dec(Regs.SP,SizeOf(Value));
 Seek(Memory,AddrExt2Conv(Segs.SS,Regs.SP));
 BlockWrite(Memory,Value,SizeOf(Value),ByteReaded);
End;

Function PopWordStack:Word;
Var
 Value:Word;
 ByteReaded:Word;
Begin
 Seek(Memory,AddrExt2Conv(Segs.SS,Regs.SP));
 BlockRead(Memory,Value,SizeOf(Value),ByteReaded);
 Inc(Regs.SP,SizeOf(Value));
 PopWordStack:=Value;
End;

Procedure PopWordFlags;Begin
 Flags.Base:=PopWordStack;
  {Effacer les bits appropriÇ...}
End;

Procedure PushLongStack(Value:LongInt);
Var
 ByteWrited:Word;
Begin
 Dec(Regs.SP,SizeOf(Value));
 Seek(Memory,AddrExt2Conv(Segs.SS,Regs.SP));
 BlockWrite(Memory,Value,SizeOf(Value),ByteWrited);
End;

Function PopLongStack:LongInt;
Var
 Value:LongInt;
 ByteReaded:Word;
Begin
 Seek(Memory,AddrExt2Conv(Segs.SS,Regs.SP));
 BlockRead(Memory,Value,SizeOf(Value),ByteReaded);
 Inc(Regs.SP,SizeOf(Value));
 PopLongStack:=Value;
End;

Function ReadWordOfs(Ofs:Word):LongInt;
Var
 Seg:Word;
 Value,AbsAddr:LongInt;
 ByteReaded:Word;
Begin
 Case(CurrSeg)of
  0..3:Seg:=Segs.Abs[CurrSeg];
  4:Seg:=FS;
  5:Seg:=GS;
  Else Seg:=Segs.DS;
 End;
 AbsAddr:=AddrExt2Conv(Seg,Ofs);
{ If(Q.FullScreen)and(AbsAddr shr 4=GetVideoSeg)Then ReadWordOfs:=Mem[Seg:Ofs]
  Else
 Begin}
  Seek(Memory,AbsAddr);
  BlockRead(Memory,Value,SizeOf(Value),ByteReaded);
  ReadWordOfs:=Value;
{ End;}
End;

Procedure WriteByteOfs(Value:Byte;Ofs:Word);
Var
 Seg:Word;
 AbsAddr:LongInt;
 ByteWrited:Word;
Begin
 Case(CurrSeg)of
  0..3:Seg:=Segs.Abs[CurrSeg];
  4:Seg:=FS;
  5:Seg:=GS;
 End;
 AbsAddr:=AddrExt2Conv(Seg,Ofs);
 {If(Q.FullScreen)and(AbsAddr shr 4=GetVideoSeg)Then Mem[Seg:Ofs]:=Value
 Else }Begin
  Seek(Memory,AbsAddr);
  BlockWrite(Memory,Value,SizeOf(Value),ByteWrited);
 End;
End;

Procedure WriteWordOfs(Value:Word;Ofs:Word);
Var
 Seg:Word;
 ByteWrited:Word;
Begin
 Case(CurrSeg)of
  0..3:Seg:=Segs.Abs[CurrSeg];
  4:Seg:=FS;
  5:Seg:=GS;
 End;
 Seek(Memory,AddrExt2Conv(Segs.SS,Ofs));
 BlockWrite(Memory,Value,SizeOf(Value),ByteWrited);
End;


Function S86GetCode(Pos:Byte):Byte;Begin
 S86GetCode:=Buffer[(IP and$F)+Pos];
End;

Function GetReg8BitsPtr(Num:Byte):Pointer;Begin
 Num:=Num and 7;
 Case Num of
  0:GetReg8BitsPtr:=@Regs.AL;
  1:GetReg8BitsPtr:=@Regs.CL;
  2:GetReg8BitsPtr:=@Regs.DL;
  3:GetReg8BitsPtr:=@Regs.BL;
  4:GetReg8BitsPtr:=@Regs.AH;
  5:GetReg8BitsPtr:=@Regs.CH;
  6:GetReg8BitsPtr:=@Regs.DH;
  7:GetReg8BitsPtr:=@Regs.BH;
 End;
End;

Function GetCodeWord(Pos:Byte):Word;Begin
 GetCodeWord:=S86GetCode(Pos)+(S86GetCode(Pos+1)shl 8);
End;

Function GetCodeLong(Pos:Byte):LongInt;Begin
 GetCodeLong:=GetCodeWord(Pos)+(GetCodeWord(Pos+2)shl 16);
End;

Procedure CallNear(Ofs,Step:Word);Begin
 PushWordStack(IP+Step);
 IP:=Ofs;
End;

Procedure CallFar(Ofs,Seg,Step:Word);Begin
 PushWordStack(Segs.CS);
 PushWordStack(IP+Step);
 IP:=Ofs;
 Segs.CS:=Seg;
End;

Function EstimateSizeOpCodeAddr(HeadLen:Byte):Byte;Begin
 Case S86GetCode(HeadLen)of
  $06,$0E,$16,$1E,$26,$2E,$36,$3E,$80..$BF:EstimateSizeOpCodeAddr:=3+HeadLen;
  $40..$7F:EstimateSizeOpCodeAddr:=2+HeadLen;
  Else EstimateSizeOpCodeAddr:=1+HeadLen;
 End;
End;

Procedure WriteValue(Value:Word;HeadLen:Byte;IsWord:Boolean;Operand:Byte);
Var
 Int:LongInt;
 NextCode:Byte;
 Ofs:Word;
 IC:Byte;
 OldNextCode:Byte;
 OldValue:Word; { Anciennes valeurs pour les Çchanges }
Begin
 NextCode:=S86GetCode(HeadLen);
 OldNextCode:=NextCode;
 IC:=0;
 Case(NextCode)of
  $06,$0E,$16,$1E,$26,$2E,$36,$3E:Begin
   Ofs:=GetCodeWord(1+HeadLen);
   IC:=3+HeadLen;
  End;
  $40..$7F:Begin
   Case(NextCode)and 7of
    0:Int:=Regs.BX+Regs.SI;
    1:Int:=Regs.BX+Regs.DI;
    2:Int:=Regs.BP+Regs.SI;
    3:Int:=Regs.BP+Regs.DI;
    4:Int:=Regs.SI;
    5:Int:=Regs.DI;
    6:Int:=Regs.BP;
    7:Int:=Regs.BX;
   End;
   Ofs:=Int+ShortInt(GetCodeWord(1+HeadLen));
   IC:=2+HeadLen;
  End;
  $80..$BF:Begin
   Case(NextCode)and 7of
    0:Int:=Regs.BX+Regs.SI;
    1:Int:=Regs.BX+Regs.DI;
    2:Int:=Regs.BP+Regs.SI;
    3:Int:=Regs.BP+Regs.DI;
    4:Int:=Regs.SI;
    5:Int:=Regs.DI;
    6:Int:=Regs.BP;
    7:Int:=Regs.BX;
   End;
   Ofs:=Int+Integer(GetCodeWord(1+HeadLen));
   IC:=3+HeadLen;
  End;
  $C0..$FF:Begin
   OldNextCode:=(NextCode-$C0)shr 3;
   NextCode:=NextCode and 7;
   Case(Operand)of
    opAdc:If(IsWord)Then S86AdcWord(Regs.AbsWord[NextCode].Lo,Value)
                    Else S86AdcByte(Byte(GetReg8BitsPtr(NextCode)^),Value);
    opAdd:If(IsWord)Then S86AddWord(Regs.AbsWord[NextCode].Lo,Value)
                    Else S86AddByte(Byte(GetReg8BitsPtr(NextCode)^),Value);
    opAnd:If(IsWord)Then S86AndWord(Regs.AbsWord[NextCode].Lo,Value)
                    Else S86AndByte(Byte(GetReg8BitsPtr(NextCode)^),Value);
    opCmp:If(IsWord)Then S86CmpWord(Regs.AbsWord[NextCode].Lo,Value)
                    Else S86CmpByte(Byte(GetReg8BitsPtr(NextCode)^),Value);
    opDec:If(IsWord)Then S86DecWord(Regs.AbsWord[NextCode].Lo)
                    Else S86DecByte(Byte(GetReg8BitsPtr(NextCode)^));
    opDiv:If(IsWord)Then S86DivWord(Regs.AbsWord[NextCode].Lo)
                    Else S86DivByte(Byte(GetReg8BitsPtr(NextCode)^));
    opInc:If(IsWord)Then S86IncWord(Regs.AbsWord[NextCode].Lo)
                    Else S86IncByte(Byte(GetReg8BitsPtr(NextCode)^));
    opMul:If(IsWord)Then S86MulWord(Regs.AbsWord[NextCode].Lo)
                    Else S86MulByte(Byte(GetReg8BitsPtr(NextCode)^));
    opOr: If(IsWord)Then S86OrWord(Regs.AbsWord[NextCode].Lo,Value)
                    Else S86OrByte(Byte(GetReg8BitsPtr(NextCode)^),Value);
    opSub:If(IsWord)Then S86SubWord(Regs.AbsWord[NextCode].Lo,Value)
                    Else S86SubByte(Byte(GetReg8BitsPtr(NextCode)^),Value);
    opSbb:If(IsWord)Then S86SbbWord(Regs.AbsWord[NextCode].Lo,Value)
                    Else S86SbbByte(Byte(GetReg8BitsPtr(NextCode)^),Value);
    opXor:If(IsWord)Then S86XorWord(Regs.AbsWord[NextCode].Lo,Value)
                    Else S86XorByte(Byte(GetReg8BitsPtr(NextCode)^),Value);
    opXChg:Begin
     If(IsWord)Then Regs.AbsWord[NextCode].Lo:=Value
      Else
     Begin
      OldValue:=GetReg8Bits(NextCode);
      SetReg8Bits(NextCode,GetReg8Bits(OldNextCode));
      SetReg8Bits(OldNextCode,OldValue);
     End;
    End;
    Else If(IsWord)Then Regs.AbsWord[NextCode].Lo:=Value
                   Else SetReg8Bits(NextCode,Value);
   End;
   IncCode(1+HeadLen);
   Exit;
  End;
  Else Begin
   Case(NextCode)and 7of
    0:Int:=Regs.BX+Regs.SI;
    1:Int:=Regs.BX+Regs.DI;
    2:Int:=Regs.BP+Regs.SI;
    3:Int:=Regs.BP+Regs.DI;
    4:Int:=Regs.SI;
    5:Int:=Regs.DI;
    6:Int:=0;
    7:Int:=Regs.BX;
   End;
   Ofs:=Int;
   IC:=1+HeadLen;
  End;
 End;
 Case(Operand)of
  opAdc:If(IsWord)Then Value:=S86AdcWordF(ReadWordOfs(Ofs),Value)
                  Else Value:=S86AdcByteF(ReadWordOfs(Ofs),Value);
  opAdd:If(IsWord)Then Value:=S86AddWordF(ReadWordOfs(Ofs),Value)
                  Else Value:=S86AddByteF(ReadWordOfs(Ofs),Value);
  opAnd:If(IsWord)Then Value:=S86AndWordF(ReadWordOfs(Ofs),Value)
                 Else Value:=S86AndByteF(ReadWordOfs(Ofs),Value);
  opCmp:If(IsWord)Then Value:=S86CmpWordF(ReadWordOfs(Ofs),Value)
                 Else Value:=S86CmpByteF(ReadWordOfs(Ofs),Value);
  opDec:If(IsWord)Then Value:=S86DecWordF(ReadWordOfs(Ofs))
                  Else Value:=S86DecByteF(ReadWordOfs(Ofs));
  opDiv:If(IsWord)Then S86DivWord(ReadWordOfs(Ofs))
                  Else S86DivByte(ReadWordOfs(Ofs));
  opInc:If(IsWord)Then Value:=S86IncWordF(ReadWordOfs(Ofs))
                  Else Value:=S86IncByteF(ReadWordOfs(Ofs));
  opMul:If(IsWord)Then S86MulWord(ReadWordOfs(Ofs))
                  Else S86MulByte(ReadWordOfs(Ofs));
  opOr: If(IsWord)Then Value:=S86OrWordF(ReadWordOfs(Ofs),Value)
                   Else Value:=S86OrByteF(ReadWordOfs(Ofs),Value);
  opSub:If(IsWord)Then Value:=S86SubWordF(ReadWordOfs(Ofs),Value)
                  Else Value:=S86SubByteF(ReadWordOfs(Ofs),Value);
  opSbb:If(IsWord)Then Value:=S86SbbWordF(ReadWordOfs(Ofs),Value)
                  Else Value:=S86SbbByteF(ReadWordOfs(Ofs),Value);
  opXor:If(IsWord)Then Value:=S86XorWordF(ReadWordOfs(Ofs),Value)
                  Else Value:=S86XorByteF(ReadWordOfs(Ofs),Value);
  opXChg:Begin
  End;
 End;
 If Not(Operand In[opDiv,opMul])Then Begin
  If(IsWord)Then WriteWordOfs(Value,Ofs)
            Else WriteByteOfs(Value,Ofs);
 End;
 IncCode(IC);
End;

Procedure WriteWordValue(Value:Word;HeadLen:Byte);Begin
 WriteValue(Value,HeadLen,True,opMov);
End;

Procedure WriteByteValue(Value:Byte;HeadLen:Byte);Begin
 WriteValue(Value,HeadLen,False,opMov);
End;

Procedure OutPortByte(Addr:Word;Value:Byte);Begin
 { Port d'entrÇe/sortie };
 Case Addr of
  $E0:If ModelComputer=mcAmdekSystem88 Then Begin { CMOS }
   CmosPos:=Value;
  End;
 End;
End;

Procedure OutPortWord(Addr:Word;Value:Word);Begin
 OutPortByte(Addr,Lo(Value));
 OutPortByte(Addr+1,Hi(Value));
End;

Function InPortByte(Addr:Word):Byte;
Const
 CharToRawKey:Array[#0..#127]of Byte=(
  {  0}$00,{  1}$00,{  2}$00,{  3}$00,{  4}$00,{  5}$00,{  6}$00,{  7}$00,
  {  8}$0E,{  9}$0F,{ 10}$00,{ 11}$00,{ 12}$00,{ 13}$1C,{ 14}$00,{ 15}$00,
  { 16}$00,{ 17}$00,{ 18}$00,{ 19}$00,{ 20}$00,{ 21}$00,{ 22}$00,{ 23}$00,
  { 24}$00,{ 25}$00,{ 26}$00,{ 27}$01,{ 28}$00,{ 29}$00,{ 30}$00,{ 31}$00,
  { 32}$39,{ 33}$02,{ 34}$28,{ 35}$04,{ 36}$05,{ 37}$06,{ 38}$08,{ 39}$28,
  { 40}$0A,{ 41}$0B,{ 42}$09,{ 43}$0D,{ 44}$33,{ 45}$0C,{ 46}$34,{ 47}$35,
  { 48}$0B,{ 49}$02,{ 50}$03,{ 51}$04,{ 52}$05,{ 53}$06,{ 54}$07,{ 55}$08,
  { 56}$09,{ 57}$0A,{ 58}$27,{ 59}$27,{ 60}$33,{ 61}$0D,{ 62}$34,{ 63}$35,
  { 64}$03,{ 65}$1E,{ 66}$30,{ 67}$2E,{ 68}$20,{ 69}$12,{ 70}$21,{ 71}$22,
  { 72}$23,{ 73}$17,{ 74}$24,{ 75}$25,{ 76}$26,{ 77}$32,{ 78}$31,{ 79}$18,
  { 80}$19,{ 81}$10,{ 82}$13,{ 83}$1F,{ 84}$14,{ 85}$16,{ 86}$2F,{ 87}$11,
  { 88}$2D,{ 89}$15,{ 90}$2C,{ 91}$1A,{ 92}$2B,{ 93}$1B,{ 94}$07,{ 95}$0C,
  { 96}$29,{ 97}$1E,{ 98}$30,{ 99}$2E,{100}$20,{101}$12,{102}$21,{103}$22,
  {104}$23,{105}$17,{106}$24,{107}$25,{108}$26,{109}$32,{110}$31,{111}$18,
  {112}$19,{113}$10,{114}$13,{115}$1F,{116}$14,{117}$16,{118}$2F,{119}$11,
  {120}$2D,{121}$15,{122}$2C,{123}$1A,{124}$2B,{125}$1B,{126}$29,{127}$53
 );
Var
 C:Char;
 Year,Month,Day,DOW:Word;
Begin
 If ModelComputer=mcOlivettiM24 Then InPortByte:=$FF
                                Else InPortByte:=0;
 Case Addr of
  $60:Begin
    If NextRawKey<>0 Then Begin
     InPortByte:=NextRawKey;
     NextRawKey:=0;
    End
     Else
    If(Keypressed)Then Begin
    C:=ReadKey;
    If(CharToRawKey[Char(Byte(C)and $7F)]=0)or(C>=#128)Then Begin
     InPortByte:=$6C;
     NextRawKey:=Byte(C);
    End
     Else
    InPortByte:=CharToRawKey[Char(Byte(C) and $7F)];
   End;
  End;
  $66:If ModelComputer=mcOlivettiM24 Then InPortByte:=0;
  $67:If ModelComputer=mcOlivettiM24 Then InPortByte:=$20 or $40 or $0C;
  $E1:If ModelComputer=mcAmdekSystem88 Then Begin { CMOS }
   GetDate(Year,Month,Day,DOW);
   Case CmosPos of
    $06:InPortByte:=DOW+1;
    $07:InPortByte:=Day;
    $08:InPortByte:=Month;
    $09:InPortByte:=Year-1980;
    $0A:InPortByte:=$80;
    $12:InPortByte:=$FE; { Type de disque dur}
    $14:InPortByte:=1 shl 5;
    $15:InPortByte:=Lo(640);
    $16:InPortByte:=Hi(640);
   End;
  End;
 End;
End;

Function InPortWord(Addr:Word):Word;Begin
 InPortWord:=InPortByte(Addr)+(InPortByte(Addr+1)shl 8);
End;

Function ReadValue(HeadLen:Byte;IsWord:Byte):LongInt;
Var
  Int:Integer;
  NextCode:Byte;
 Begin
  NextCode:=S86GetCode(HeadLen);
  Case(NextCode)of
   $06,$0E,$16,$1E,$26,$2E,$36,$3E:Begin
    ReadValue:=ReadWordOfs(GetCodeWord(1+HeadLen));
    IncCode(3+HeadLen);
   End;
   $40..$7F:Begin
    Case(NextCode)and 7of
     0:Int:=Regs.BX+Regs.SI;
     1:Int:=Regs.BX+Regs.DI;
     2:Int:=Regs.BP+Regs.SI;
     3:Int:=Regs.BP+Regs.DI;
     4:Int:=Regs.SI;
     5:Int:=Regs.DI;
     6:Int:=Regs.BP;
     7:Int:=Regs.BX;
    End;
    ReadValue:=ReadWordOfs(Int+ShortInt(GetCodeWord(1+HeadLen)));
    IncCode(2+HeadLen);
   End;
   $80..$BF:Begin
    Case(NextCode)and 7of
     0:Int:=Regs.BX+Regs.SI;
     1:Int:=Regs.BX+Regs.DI;
     2:Int:=Regs.BP+Regs.SI;
     3:Int:=Regs.BP+Regs.DI;
     4:Int:=Regs.SI;
     5:Int:=Regs.DI;
     6:Int:=Regs.BP;
     7:Int:=Regs.BX;
    End;
    ReadValue:=ReadWordOfs(Int+Integer(GetCodeWord(1+HeadLen)));
    IncCode(3+HeadLen);
   End;
   $C0..$FF:Begin
    Case(IsWord)of
     2,1:ReadValue:=Regs.Abs[NextCode and 7];
     Else ReadValue:=GetReg8Bits(NextCode);
    End;
    IncCode(1+HeadLen);
   End;
   Else Begin
    Case(NextCode)and 7of
     0:ReadValue:=ReadWordOfs(Regs.BX+Regs.SI);
     1:ReadValue:=ReadWordOfs(Regs.BX+Regs.DI);
     2:ReadValue:=ReadWordOfs(Regs.BP+Regs.SI);
     3:ReadValue:=ReadWordOfs(Regs.BP+Regs.DI);
     4:ReadValue:=ReadWordOfs(Regs.SI);
     5:ReadValue:=ReadWordOfs(Regs.DI);
     7:ReadValue:=ReadWordOfs(Regs.BX);
    End;
    IncCode(1+HeadLen);
   End;
  End;
 End;

Function ReadDWordValue(HeadLen:Byte):LongInt;Begin
 ReadDWordValue:=ReadValue(HeadLen,2);
End;

Function ReadWordValue(HeadLen:Byte):Word;Begin
 ReadWordValue:=ReadValue(HeadLen,1);
End;

Function ReadByteValue(HeadLen:Byte):Byte;Begin
 ReadByteValue:=ReadValue(HeadLen,0);
End;

Function CurrCode:Byte;
Var
 Addr,Seg:LongInt;
 ByteReaded:Word;
Begin
 Addr:=AddrExt2Conv(Segs.CS,IP);
 Seg:=Addr shr 4;
 If(OldCSeg<>Seg)Then Begin
  Seek(Memory,Addr and$FFFFFFF0);
  BlockRead(Memory,Buffer,SizeOf(Buffer),ByteReaded);
  OldCSeg:=Seg;
 End;
 CurrCode:=Buffer[IP and$F];
End;

Procedure NearJmp(Jmp:Boolean;Size:Byte);Begin
 If(Jmp)Then Begin
{  Q.IP:=$FFFD-Q.IP+GetCodeWord(Size-2);}
  IP:=IP+GetCodeWord(Size-2)+Size;
 End
  Else
 IncCode(Size);
End;

Procedure ShortJmp(Jmp:Boolean;Size:Byte);Begin
 If(Jmp)Then Begin
  IncCode(Size+ShortInt(S86GetCode(1)))
 End
  Else
 IncCode(Size);
End;

Function LoadAddr(Size:Byte):Word;
Var
 NC:Byte;
 TL:LongInt;
Begin
 NC:=(S86GetCode(Size)and$3F)shr 3;
 TL:=ReadDWordValue(Size);
 Regs.AbsWord[NC].Lo:=TL and $FFFF;
 LoadAddr:=LongRec(TL).Hi;
End;

Procedure Run;
Label
 Restart,InvalidOpcode;
Var
 NC:Byte;
 TW:Word;        { Traåtement temporaire 16 bits }
 TL:LongInt;     { Traåtement temporaire 32 bits }
 Code:Byte;
Begin
 CurrSeg:=$FF;
Restart:
 Code:=CurrCode;
 If(Debug)Then Begin
  Write('INLINE(');
  For I:=0 to 15 do Begin
   Write(ByteHex2Str(Buffer[(IP and$F)+I]));
  End;
  WriteLn(')');
  WriteLn('CS:IP=',HexWord2Str(Segs.CS),':',HexWord2Str(IP));
  WriteLn('AX=',HexWord2Str(Regs.AX),', ',
          'BX=',HexWord2Str(Regs.BX),', ',
          'CX=',HexWord2Str(Regs.CX),', ',
          'DX=',HexWord2Str(Regs.DX),', ',
          'SP=',HexWord2Str(Regs.SP),', ',
          'BP=',HexWord2Str(Regs.BP),', ',
          'SI=',HexWord2Str(Regs.SI),', ',
          'DI=',HexWord2Str(Regs.DI));
  WriteLn('DS=',HexWord2Str(Segs.DS),', ',
          'ES=',HexWord2Str(Segs.ES),', ',
          'SS=',HexWord2Str(Segs.SS));
  Write('Flags=(');
  If(CF in Flags.s)Then Write('CF ');
  If(PF in Flags.s)Then Write('PF ');
  If(AF in Flags.s)Then Write('AF ');
  If(ZF in Flags.s)Then Write('ZF ');
  If(SF in Flags.s)Then Write('SF ');
  If(TF in Flags.s)Then Write('TF ');
  If(_IF in Flags.s)Then Write('IF ');
  If(DF in Flags.s)Then Write('DF ');
  If(_OF in Flags.s)Then Write('OF ');
  WriteLn(')');
 End;
 Case(Code)of
  $00:Begin { ADD registre 8 bits,registre 8 bits}
   WriteValue(GetReg8Bits((S86GetCode(1)and$3F)shr 3),1,False,opAdd);
  End;
  $01:Begin { ADD registre 16 bits,registre 16 bits}
   WriteValue(Regs.Abs[(S86GetCode(1)and$3F)shr 3],1,True,opAdd);
  End;
  $02:Begin { ADD registre 8 bits,registre 8 bits}
   NC:=(S86GetCode(1)and$3F)shr 3;
   S86AddByte(Byte(GetReg8BitsPtr(NC)^),ReadByteValue(1));
  End;
  $03:Begin { ADD registre 16 bits,registre 16 bits}
   NC:=(S86GetCode(1)and$3F)shr 3;
   S86AddWord(Regs.AbsWord[NC].Lo,ReadWordValue(1));
  End;
  $04:Begin { ADD AL,xxh }
   S86AddByte(Regs.AL,S86GetCode(1));
   IncCode(2);
  End;
  { removed orphan else }
  { removed orphan goto }
  $05:Begin { ADD AX,xxyyh }
   S86AddWord(Regs.AX,GetCodeWord(1));
   IncCode(3);
  End;
  { removed orphan else }
  { removed orphan goto }
  $06:Begin { PUSH ES }
   PushWordStack(Segs.ES);
   IncCode(1);
  End;
  $07:Begin { POP ES }
   Segs.ES:=PopWordStack;
   IncCode(1);
  End;
  $08:Begin { OR registre 8 bits,registre 8 bits}
   WriteValue(GetReg8Bits((S86GetCode(1)and$3F)shr 3),1,False,opOr);
  End;
  $09:Begin { OR registre 16 bits,registre 16 bits}
   WriteValue(Regs.Abs[(S86GetCode(1)and$3F)shr 3],1,True,opOr);
  End;
  $0A:Begin { OR registre 8 bits,registre 8 bits}
   NC:=(S86GetCode(1)and$3F)shr 3;
   S86OrByte(Byte(GetReg8BitsPtr(NC)^),ReadByteValue(1));
  End;
  $0B:Begin { OR registre 16 bits,registre 16 bits}
   NC:=(S86GetCode(1)and$3F)shr 3;
   S86OrWord(Regs.AbsWord[NC].Lo,ReadWordValue(1));
  End;
  $0C:Begin { OR AL,xxh }
   S86OrByte(Regs.AL,S86GetCode(1));
   IncCode(2);
  End;
  { removed orphan else }
  { removed orphan goto }
  $0D:Begin { OR AX,xxyyh }
   S86OrWord(Regs.AX,GetCodeWord(1));
   IncCode(3);
  End;
  { removed orphan else }
  { removed orphan goto }
  $0E:Begin { PUSH CS }
   PushWordStack(Segs.CS);
   IncCode(1);
  End;
  $0F:Case S86GetCode(1)of
   $06:If(CPU>=cpu80286)Then Begin { CLTS }
{    Exclude(Control.s,TS);}
    IncCode(2);
   End;
  { removed orphan else }
  { removed orphan goto }
   $80:If(CPU>=cpui386)Then NearJmp((_OF)in(Flags.s),4) { JO near }
                       Else Goto InvalidOpCode;
   $81:If(CPU>=cpui386)Then NearJmp(Not((_OF)in(Flags.s)),4) { JNO near }
                       Else Goto InvalidOpCode;
   $82:If(CPU>=cpui386)Then NearJmp((CF)in(Flags.s),4) { JC near }
                       Else Goto InvalidOpCode;
   $83:If(CPU>=cpui386)Then NearJmp(Not((CF)in(Flags.s)),4) { JNC near }
                       Else Goto InvalidOpCode;
   $84:If(CPU>=cpui386)Then NearJmp((ZF)in(Flags.s),4) { JZ near }
                       Else Goto InvalidOpCode;
   $85:If(CPU>=cpui386)Then NearJmp(Not((ZF)in(Flags.s)),4) { JNZ near }
                       Else Goto InvalidOpCode;
   $86:If(CPU>=cpui386)Then NearJmp(Not((AF)in(Flags.s)),4) { JNA near }
                       Else Goto InvalidOpCode;
   $87:If(CPU>=cpui386)Then NearJmp((AF)in(Flags.s),4) { JA near }
                       Else Goto InvalidOpCode;
   $88:If(CPU>=cpui386)Then NearJmp((SF)in(Flags.s),4) { JS near }
                       Else Goto InvalidOpCode;
   $89:If(CPU>=cpui386)Then NearJmp(Not((SF)in(Flags.s)),4) { JNS near }
                       Else Goto InvalidOpCode;
   $8A:If(CPU>=cpui386)Then NearJmp((PF)in(Flags.s),4) { JP near }
                       Else Goto InvalidOpCode;
   $8B:If(CPU>=cpui386)Then NearJmp(Not((PF)in(Flags.s)),4) { JNP near }
                       Else Goto InvalidOpCode;
   $8C:If(CPU>=cpui386)Then NearJmp(((SF)in(Flags.s))<>((_OF)in(Flags.s)),4) { JL near }
                       Else Goto InvalidOpCode;
   $8D:If(CPU>=cpui386)Then NearJmp(((SF)in(Flags.s))=((_OF)in(Flags.s)),4) { JNL near }
                       Else Goto InvalidOpCode;
   $8E:If(CPU>=cpui386)Then NearJmp((((SF)in(Flags.s))<>((_OF)in(Flags.s)))or((ZF)in(Flags.s)),4) { JLE near }
                         Else Goto InvalidOpCode;
   $8F:If(CPU>=cpui386)Then NearJmp((((SF)in(Flags.s))=((_OF)in(Flags.s)))or(Not((ZF)in(Flags.s))),4) { JNLE near }
                       Else Goto InvalidOpCode;
   $A0:If(CPU>=cpui386)Then Begin { PUSH FS }
    PushWordStack(FS);
    IncCode(2);
   End;
  { removed orphan else }
  { removed orphan goto }
   $A1:If(CPU>=cpui386)Then Begin { POP FS }
    FS:=PopWordStack;
    IncCode(2);
   End;
  { removed orphan else }
  { removed orphan goto }
   $A2:If(soCPUID)in(Option)Then Begin { CPUID }
    Case(Regs.EAX)of
     0:Case(CPUVendor)of
      cvCyrix:Begin{EAX ECX EDX EBX}
       Regs.Chr:='????teadxInsCyri';
      End;
      cvAmd:Begin {EAX ECX EDX EBX }
       Regs.Chr:='????cAMDentiAuth';
      End;
      Else Begin  {EAX ECX EDX EBX }
       Regs.Chr:='????ntelineIGenu';
      End;
     End;
     1:Begin
      Regs.EAX:=0; { DonnÇes divers Ö complÇter...}
      Regs.EBX:=0;
      Regs.ECX:=0;
     End;
    End;
    IncCode(2);
   End;
  { removed orphan else }
  { removed orphan goto }
   $A8:If(CPU>=cpui386)Then Begin { PUSH GS }
    PushWordStack(GS);
    IncCode(2);
   End;
  { removed orphan else }
  { removed orphan goto }
   $A9:If(CPU>=cpui386)Then Begin { POP GS }
    GS:=PopWordStack;
    IncCode(2);
   End;
  { removed orphan else }
  { removed orphan goto }
   $B2:If(CPU>=cpui386)Then Segs.SS:=LoadAddr(2) { LSS }
                       Else Goto InvalidOpCode;
   $B4:If(CPU>=cpui386)Then FS:=LoadAddr(2) { LFS }
                       Else Goto InvalidOpCode;
   $B5:If(CPU>=cpui386)Then GS:=LoadAddr(2) { LGS }
                       Else Goto InvalidOpCode;
   $C8..$CF:If(CPU>=cpui486)Then Begin { BSWAP }
    S86BSWAP(Regs.Abs[S86GetCode(1)and 7]);
    IncCode(2);
   End;
  { removed orphan else }
  { removed orphan goto }
   Else Goto InvalidOpCode;
  End;
  $10:Begin { ADC registre 8 bits,registre 8 bits}
   WriteValue(GetReg8Bits((S86GetCode(1)and$3F)shr 3),1,False,opADC);
  End;
  $11:Begin { ADC registre 16 bits,registre 16 bits}
   WriteValue(Regs.Abs[(S86GetCode(1)and$3F)shr 3],1,True,opADC);
  End;
  $12:Begin { ADC registre 8 bits,registre 8 bits}
   NC:=(S86GetCode(1)and$3F)shr 3;
   S86AdcByte(Byte(GetReg8BitsPtr(NC)^),ReadByteValue(1));
  End;
  $13:Begin { ADC registre 16 bits,registre 16 bits}
   NC:=(S86GetCode(1)and$3F)shr 3;
   S86AdcWord(Regs.AbsWord[NC].Lo,ReadWordValue(1));
  End;
  $14:Begin { ADC AL,xxh }
   S86AdcByte(Regs.AL,S86GetCode(1));
   IncCode(2);
  End;
  { removed orphan else }
  { removed orphan goto }
  $15:Begin { ADC AX,xxyyh }
   S86AdcWord(Regs.AX,GetCodeWord(1));
   IncCode(3);
  End;
  { removed orphan else }
  { removed orphan goto }
  $16:Begin { PUSH SS }
   PushWordStack(Segs.SS);
   IncCode(1);
  End;
  $17:Begin { POP SS }
   Segs.SS:=PopWordStack;
   IncCode(1);
  End;
  $18:Begin { SBB registre 8 bits,registre 8 bits}
   WriteValue(GetReg8Bits((S86GetCode(1)and$3F)shr 3),1,False,opSBB);
  End;
  $19:Begin { SBB registre 16 bits,registre 16 bits}
   WriteValue(Regs.Abs[(S86GetCode(1)and$3F)shr 3],1,True,opSBB);
  End;
  $1A:Begin { SBB registre 8 bits,registre 8 bits}
   NC:=(S86GetCode(1)and$3F)shr 3;
   S86SbbByte(Byte(GetReg8BitsPtr(NC)^),ReadByteValue(1));
  End;
  $1B:Begin { SBB registre 16 bits,registre 16 bits}
   NC:=(S86GetCode(1)and$3F)shr 3;
   S86SbbWord(Regs.AbsWord[NC].Lo,ReadWordValue(1));
  End;
  $1C:Begin { SBB AL,xxh }
   S86SbbByte(Regs.AL,S86GetCode(1));
   IncCode(2);
  End;
  { removed orphan else }
  { removed orphan goto }
  $1D:Begin { SBB AX,xxyyh }
   S86SbbWord(Regs.AX,GetCodeWord(1));
   IncCode(3);
  End;
  { removed orphan else }
  { removed orphan goto }
  $1E:Begin { PUSH DS }
   PushWordStack(Segs.DS);
   IncCode(1);
  End;
  $1F:Begin { POP DS }
   Segs.DS:=PopWordStack;
   IncCode(1);
  End;
  $20:Begin { AND registre 8 bits,registre 8 bits}
   WriteValue(GetReg8Bits((S86GetCode(1)and$3F)shr 3),1,False,opAnd);
  End;
  $21:Begin { AND registre 16 bits,registre 16 bits}
   WriteValue(Regs.Abs[(S86GetCode(1)and$3F)shr 3],1,True,opAnd);
  End;
  $22:Begin { AND registre 8 bits,registre 8 bits}
   NC:=(S86GetCode(1)and$3F)shr 3;
   S86AndByte(Byte(GetReg8BitsPtr(NC)^),ReadByteValue(1));
  End;
  $23:Begin { AND registre 16 bits,registre 16 bits}
   NC:=(S86GetCode(1)and$3F)shr 3;
   S86AndWord(Regs.AbsWord[NC].Lo,ReadWordValue(1));
  End;
  $24:Begin { AND AL,xxh }
   S86AndByte(Regs.AL,S86GetCode(1));
   IncCode(2);
  End;
  { removed orphan else }
  { removed orphan goto }
  $25:Begin { AND AX,xxyyh }
   S86AndWord(Regs.AX,GetCodeWord(1));
   IncCode(3);
  End;
  { removed orphan else }
  { removed orphan goto }
  $26:Begin { ES: }
   If CurrSeg<>$FFThen Exit;
   CurrSeg:=0;
   IncCode(1);
   Goto Restart;
  End;
  $27:Begin { DAA }
   If((AF in Flags.s)or((Regs.AL and $0F) > 9))Then Begin
    Regs.AL:=Regs.AL+6;
    Include(Flags.s,AF);
   End
    Else
   Exclude(Flags.s,AF);
   If((CF in Flags.s)or(Regs.AL>$9F))Then Begin
    Regs.AL:=Regs.AL+$60;
    Exclude(Flags.s,CF);
   End
    Else
   Exclude(Flags.s,CF);
   SetPF(Regs.AL);
   SetSFB(Regs.AL);
   SetZFB(Regs.AL);
   IncCode(1);
  End;
  $28:Begin { SUB registre 8 bits,registre 8 bits}
   WriteValue(GetReg8Bits((S86GetCode(1)and$3F)shr 3),1,False,opSub);
  End;
  $29:Begin { SUB registre 16 bits,registre 16 bits}
   WriteValue(Regs.AbsWord[(S86GetCode(1)and$3F)shr 3].Lo,1,True,opSub);
  End;
  $2A:Begin { SUB registre 8 bits,registre 8 bits}
   NC:=(S86GetCode(1)and$3F)shr 3;
   S86SubByte(Byte(GetReg8BitsPtr(NC)^),ReadByteValue(1));
  End;
  $2B:Begin { SUB registre 16 bits,registre 16 bits}
   NC:=(S86GetCode(1)and$3F)shr 3;
   S86SubWord(Regs.AbsWord[NC].Lo,ReadWordValue(1));
  End;
  $2C:Begin { SUB AL,xxh }
   S86SubByte(Regs.AL,S86GetCode(1));
   IncCode(2);
  End;
  { removed orphan else }
  { removed orphan goto }
  $2D:Begin { SUB AX,xxyyh }
   S86SubWord(Regs.AX,GetCodeWord(1));
   IncCode(3);
  End;
  { removed orphan else }
  { removed orphan goto }
  $2E:Begin { CS: }
   If CurrSeg<>$FFThen Exit;
   CurrSeg:=1;
   IncCode(1);
   Goto Restart;
  End;
  $2F:Begin { DAS }
   NC:=Regs.AL;
   OldFlags:=Flags;
   If(((Regs.AL and $0F) > $09)or(AF in Flags.s))Then Begin
    Regs.AL:=Regs.AL-$06;
    Include(Flags.s,AF);
    If (Regs.AL and $FF00)<>0 Then Include(Flags.s,CF);
   End
    Else
   Exclude(Flags.s,AF);
   If((NC>$99)or(CF in OldFlags.s))Then Begin
    Regs.AL:=Regs.AL-$60;
    Include(Flags.s,CF);
   End;
   SetZFB(Regs.AL);
   SetPF(Regs.AL);
   SetSFB(Regs.AL);
   IncCode(1);
  End;
  $30:Begin { XOR registre 8 bits, registre 8 bits }
   WriteValue(GetReg8Bits((S86GetCode(1)and$3F)shr 3),1,False,opXor);
  End;
  $31:Begin { XOR registre 16 bits,registre 16 bits}
   WriteValue(Regs.Abs[(S86GetCode(1)and$3F)shr 3],1,True,opXor);
  End;
  $32:Begin { XOR registre 8 bits,registre 8 bits}
   NC:=(S86GetCode(1)and$3F)shr 3;
   S86XorByte(Byte(GetReg8BitsPtr(NC)^),ReadByteValue(1));
  End;
  $33:Begin { XOR registre 16 bits,registre 16 bits}
   NC:=(S86GetCode(1)and$3F)shr 3;
   S86XorWord(Regs.AbsWord[NC].Lo,ReadWordValue(1));
  End;
  $34:Begin { XOR AL,xxh }
   S86XorByte(Regs.AL,S86GetCode(1));
   IncCode(2);
  End;
  { removed orphan else }
  { removed orphan goto }
  $35:Begin { XOR AX,xxyyh }
   S86XorWord(Regs.AX,GetCodeWord(1));
   IncCode(3);
  End;
  { removed orphan else }
  { removed orphan goto }
  $36:Begin { SS: }
   If CurrSeg<>$FFThen Exit;
   CurrSeg:=2;
   IncCode(1);
   Goto Restart;
  End;
  $37:Begin { AAA }
   If(((Regs.AL and $0F)>$09)or(AF in Flags.s))Then Begin
    Regs.AL:=Regs.AL+$06;
    Regs.AH:=Regs.AH+$01;
    Include(Flags.s,CF);
    Include(Flags.s,AF);
   End
    Else
   Begin
    Exclude(Flags.s,CF);
    Exclude(Flags.s,AF);
   End;
   Regs.AL:=Regs.AL and $0F;
   IncCode(1);
  End;
  $38:Begin { CMP registre 8 bits, registre 8 bits }
   WriteValue(GetReg8Bits((S86GetCode(1)and$3F)shr 3),1,False,opCmp);
  End;
  $39:Begin { CMP registre 16 bits,registre 16 bits}
   WriteValue(Regs.Abs[(S86GetCode(1)and$3F)shr 3],1,True,opCmp);
  End;
  $3A:Begin { CMP registre 8 bits,registre 8 bits}
   NC:=(S86GetCode(1)and$3F)shr 3;
   S86CmpByte(Byte(GetReg8BitsPtr(NC)^),ReadByteValue(1));
  End;
  $3B:Begin { CMP registre 16 bits,registre 16 bits}
   NC:=(S86GetCode(1)and$3F)shr 3;
   S86CmpWord(Regs.AbsWord[NC].Lo,ReadWordValue(1));
  End;
  $3C:Begin { CMP AL,xxh }
   S86CmpByte(Regs.AL,S86GetCode(1));
   IncCode(2);
  End;
  { removed orphan else }
  { removed orphan goto }
  $3D:Begin { CMP AX,xxyyh }
   S86CmpWord(Regs.AX,GetCodeWord(1));
   IncCode(3);
  End;
  { removed orphan else }
  { removed orphan goto }
  $3E:Begin { DS: }
   If CurrSeg<>$FFThen Exit;
   CurrSeg:=3;
   IncCode(1);
   Goto Restart;
  End;
  $3F:Begin { AAS }
   If(((Regs.AL and $0F)>$09)or(AF in Flags.s))Then Begin
    Regs.AL:=Regs.AL-$06;
    Regs.AH:=Regs.AH-$01;
    Include(Flags.s,CF);
    Include(Flags.s,AF);
   End
    Else
   Begin
    Exclude(Flags.s,CF);
    Exclude(Flags.s,AF);
   End;
   Regs.AL:=Regs.AL and $0F;
   IncCode(1);
  End;
  $40..$47:Begin { INC registre 16 bits }
   S86IncWord(Regs.AbsWord[CurrCode and 7].Lo);
   IncCode(1);
  End;
  $48..$4F:Begin { DEC registre 16 bits }
   S86DecWord(Regs.AbsWord[CurrCode and 7].Lo);
   IncCode(1);
  End;
  $50..$57:Begin { PUSH registre 16 bits }
   PushWordStack(Regs.Abs[CurrCode and 7]);
   IncCode(1);
  End;
  $58..$5F:Begin { POP registre 16 bits }
   Regs.AbsWord[CurrCode and 7].Lo:=PopWordStack;
   IncCode(1);
  End;
  $60:If(CPU>=cpu80286)Then Begin { PUSHA }
   TW:=Regs.SP;
   PushWordStack(Regs.DI);
   PushWordStack(Regs.SI);
   PushWordStack(Regs.BP);
   PushWordStack(TW);
   PushWordStack(Regs.BX);
   PushWordStack(Regs.DX);
   PushWordStack(Regs.CX);
   PushWordStack(Regs.AX);
   IncCode(1);
  End;
  { removed orphan else }
  { removed orphan goto }
  $61:If(CPU>=cpu80286)Then Begin { POPA }
   Regs.AX:=PopWordStack;
   Regs.CX:=PopWordStack;
   Regs.DX:=PopWordStack;
   Regs.BX:=PopWordStack;
   {Q.Reg.SP}TW:=PopWordStack;
   Regs.BP:=PopWordStack;
   Regs.SI:=PopWordStack;
   Regs.DI:=PopWordStack;
   IncCode(1);
  End;
  { removed orphan else }
  { removed orphan goto }
  $64:If(CPU>=cpui386)Then Begin { FS: }
   If CurrSeg<>$FFThen Exit;
   CurrSeg:=4;
   IncCode(1);
   Goto Restart;
  End;
  { removed orphan else }
  { removed orphan goto }
  $65:If(CPU>=cpui386)Then Begin { GS: }
   If CurrSeg<>$FFThen Exit;
   CurrSeg:=5;
   IncCode(1);
   Goto Restart;
  End;
  { removed orphan else }
  { removed orphan goto }
  $66:If(CPU>=cpui386)Then Case S86GetCode(1)of
   $50..$57:Begin { PUSH registre 32 bits }
    PushLongStack(Regs.Abs[CurrCode and 7]);
    IncCode(2);
   End;
   $58..$5F:Begin { POP registre 32 bits }
    Regs.Abs[CurrCode and 7]:=PopLongStack;
    IncCode(2);
   End;
   $6A:Begin { PUSH DWord (Byte) }
    NC:=S86GetCode(2);
    If NC>=$80Then TL:=LongInt($FFFFFF00)+NC
              Else TL:=NC;
    PushLongStack(TL);
    IncCode(3);
   End;
   $9C:Begin { PUSHFD }
    PushLongStack(Flags.Abs);
    IncCode(3);
   End;
   $A5:Begin { MOVSD }
    S86MoveLeft(Segs.DS,Regs.SI,Segs.ES,Regs.DI,4);
    S86AddCountString(4,True,True);
   End;
   $AB:Begin { STOSD }
    WriteBlock(Segs.ES,Regs.DI,Regs.AX,SizeOf(LongInt));
    S86AddCountString(4,False,True);
    IncCode(2);
   End;
   $B8..$BF:Begin { MOV registre 32 bits,xxxxyyyyh }
    Regs.Abs[CurrCode and 7]:=GetCodeLong(2);
    IncCode(6);
   End;
   $E3:Begin { JECXZ }
    If Regs.ECX=0Then IncCode(3+ShortInt(S86GetCode(1)))
                 Else IncCode(3);
   End;
   Else Goto InvalidOpcode;
  End;
  { removed orphan else }
  { removed orphan goto }
  $67:Goto InvalidOpCode;
  $68:If(CPU>=cpu80286)Then Begin { PUSH nombre immÇdiat 16 bits }
   PushWordStack(GetCodeWord(1));
   IncCode(3);
  End;
  { removed orphan else }
  { removed orphan goto }
  $6A:If(CPU>=cpu80286)Then Begin { PUSH nombre immÇdiat 8 bits en 16 bits}
   NC:=S86GetCode(1);
   If NC>=$80Then PushWordStack($FF00+NC)
             Else PushWordStack(NC);
   IncCode(2);
  End;
  { removed orphan else }
  { removed orphan goto }
  $70:ShortJmp((_OF)in(Flags.s),2); { JO short }
  $71:ShortJmp(Not((_OF)in(Flags.s)),2); { JNO short }
  $72:ShortJmp((CF)in(Flags.s),2); { JC short }
  $73:ShortJmp(Not((CF)in(Flags.s)),2); { JNC short }
  $74:ShortJmp((ZF)in(Flags.s),2); { JZ short }
  $75:ShortJmp(Not((ZF)in(Flags.s)),2); { JNZ short }
  $76:ShortJmp((AF)in(Flags.s),2); { JA short }
  $77:ShortJmp(Not((AF)in(Flags.s)),2); { JNA short }
  $78:ShortJmp((SF)in(Flags.s),2); { JS short }
  $79:ShortJmp(Not((SF)in(Flags.s)),2); { JNS short }
  $7A:ShortJmp((PF)in(Flags.s),2); { JP short }
  $7B:ShortJmp(Not((PF)in(Flags.s)),2); { JNP short }
  $7C:ShortJmp(((SF)in(Flags.s))<>((_OF)in(Flags.s)),2); { JL short }
  $7D:ShortJmp(((SF)in(Flags.s))=((_OF)in(Flags.s)),2); { JNL short }
  $7E:ShortJmp((((SF)in(Flags.s))<>((_OF)in(Flags.s)))or((ZF)in(Flags.s)),2); { JLE short }
  $7F:ShortJmp((((SF)in(Flags.s))=((_OF)in(Flags.s)))or(Not((ZF)in(Flags.s))),2); { JNLE short }
  $80:Begin
   NC:=S86GetCode(1);
   Case NC shr 3 of
    7,15:Begin{ CMP byte ptr }
     WriteValue(S86GetCode(EstimateSizeOpCodeAddr(1)),1,False,opCmp);
     IncCode(1);
    End;
    $18:Begin { ADD registre 8 bits,valeur }
     S86AddByte(Regs.AbsByte[NC and$07],S86GetCode(2));
     IncCode(3);
    End;
    $19:Begin { OR registre 8 bits,valeur }
     S86OrByte(Regs.AbsByte[NC and$07],S86GetCode(2));
     IncCode(3);
    End;
    $1A:Begin { ADC registre 8 bits,valeur }
     S86AdcByte(Regs.AbsByte[NC and$07],S86GetCode(2));
     IncCode(3);
    End;
    $1B:Begin { SBB registre 8 bits,valeur }
     S86SbbByte(Regs.AbsByte[NC and$07],S86GetCode(2));
     IncCode(3);
    End;
    $1C:Begin { AND registre 8 bits,valeur }
     S86AndByte(Regs.AbsByte[NC and$07],S86GetCode(2));
     IncCode(3);
    End;
    $1D:Begin { SUB registre 8 bits,valeur }
     S86SubByte(Regs.AbsByte[NC and$07],S86GetCode(2));
     IncCode(3);
    End;
    $1E:Begin { XOR registre 8 bits,valeur }
     S86XorByte(Regs.AbsByte[NC and$07],S86GetCode(2));
     IncCode(3);
    End;
    $1F:Begin { CMP registre 8 bits,valeur }
     S86CmpByte(Regs.AbsByte[NC and$07],S86GetCode(2));
     IncCode(3);
    End;
    Else Goto InvalidOpCode;
   End;
  End;
  $81:Begin
   NC:=S86GetCode(1);
   Case NC shr 3of
    $18:Begin { ADD registre 16 bits,valeur }
     S86AddWord(Regs.AbsWord[NC and$07].Lo,GetCodeWord(2));
     IncCode(4);
    End;
    $19:Begin { OR registre 16 bits,valeur }
     S86OrWord(Regs.AbsWord[NC and$07].Lo,GetCodeWord(2));
     IncCode(4);
    End;
    $1A:Begin { ADC registre 16 bits,valeur }
     S86AdcWord(Regs.AbsWord[NC and$07].Lo,GetCodeWord(2));
     IncCode(4);
    End;
    $1B:Begin { SBB registre 16 bits,valeur }
     S86SbbWord(Regs.AbsWord[NC and$07].Lo,GetCodeWord(2));
     IncCode(4);
    End;
    $1C:Begin { AND registre 16 bits,valeur }
     S86AndWord(Regs.AbsWord[NC and$07].Lo,GetCodeWord(2));
     IncCode(4);
    End;
    $1D:Begin { SUB registre 16 bits,valeur }
     S86SubWord(Regs.AbsWord[NC and$07].Lo,GetCodeWord(2));
     IncCode(4);
    End;
    $1E:Begin { XOR registre 16 bits,valeur }
     S86XorWord(Regs.AbsWord[NC and$07].Lo,GetCodeWord(2));
     IncCode(4);
    End;
    $1F:Begin { CMP registre 16 bits,valeur }
     S86CmpWord(Regs.AbsWord[NC and$07].Lo,GetCodeWord(2));
     IncCode(4);
    End;
    Else Goto InvalidOpCode;
   End;
  End;
  $82:Goto InvalidOpCode;
  $83:Begin
   NC:=S86GetCode(1);
   Case NC shr 3of
    $02:Begin
      {???Pas certain...}
     {WriteValue(S86GetCode(Q,EstimateSizeOpCodeAddr(1)),1,True,opADC);}
     WriteValue(GetCodeWord(EstimateSizeOpCodeAddr(1)),1,True,opADC);
     {S86AdcWord(Q,ReadValue(EstimateSizeOpCodeAddr(1),1),GetCodeWord(2));}
    End;
  (*  $0F:Begin
      {???Pas certain...}
     WriteValue(S86GetCode(Q,EstimateSizeOpCodeAddr(2)),2,True,opCmp);
    End;*)
    $18:Begin { ADD registre 16 bits,valeur sign-ext }
     S86AddWord(Regs.AbsWord[NC and$07].Lo,S86GetCode(2));
     IncCode(3);
    End;
    $19:Begin { OR registre 16 bits,valeur sign-ext }
     S86OrWord(Regs.AbsWord[NC and$07].Lo,S86GetCode(2));
     IncCode(3);
    End;
    $1A:Begin { ADC registre 16 bits,valeur sign-ext }
     S86AdcWord(Regs.AbsWord[NC and$07].Lo,S86GetCode(2));
     IncCode(3);
    End;
    $1B:Begin { SBB registre 16 bits,valeur sign-ext }
     S86SbbWord(Regs.AbsWord[NC and$07].Lo,S86GetCode(2));
     IncCode(3);
    End;
    $1C:Begin { AND registre 16 bits,valeur sign-ext }
     S86AndWord(Regs.AbsWord[NC and$07].Lo,S86GetCode(2));
     IncCode(3);
    End;
    $1D:Begin { SUB registre 16 bits,valeur sign-ext }
     S86SubWord(Regs.AbsWord[NC and$07].Lo,S86GetCode(2));
     IncCode(3);
    End;
    $1E:Begin { XOR registre 16 bits,valeur sign-ext }
     S86XorWord(Regs.AbsWord[NC and$07].Lo,S86GetCode(2));
     IncCode(3);
    End;
    $1F:Begin { CMP registre 16 bits,valeur sign-ext }
     S86CmpWord(Regs.AbsWord[NC and$07].Lo,S86GetCode(2));
     IncCode(3);
    End;
    Else Goto InvalidOpCode;
   End;
  End;
  $86:Begin { XCHG registre 8 bits,registre 8 bits}
   NC:=(S86GetCode(1) and $3F)shr 3;
   WriteValue(GetReg8Bits(NC),1,False,opXChg);
  End;
  $87:Begin { XCHG registre 16 bits,registre 16 bits}
   NC:=(S86GetCode(1) and $3F)shr 3;
   WriteValue(Regs.AbsWord[NC and$07].Lo,1,True,opXChg);
  End;
  $88:Begin { MOV registre 8 bits,registre 8 bits}
   NC:=(S86GetCode(1) and $3F)shr 3;
   WriteByteValue(GetReg8Bits(NC),1);
  End;
  $89:Begin { MOV }
   NC:=(S86GetCode(1)and $3F)shr 3;
   WriteWordValue(Regs.Abs[NC],1);
  End;
  $8A:Begin { MOV }
   NC:=(S86GetCode(1)and$3F)shr 3;
   SetReg8bits(NC,ReadByteValue(1));
  End;
  $8B:Begin { MOV }
   NC:=(S86GetCode(1)and$3F)shr 3;
   Regs.AbsWord[NC].Lo:=ReadWordValue(1);
  End;
  $8C:Begin { MOV }
   NC:=(S86GetCode(1)and$3F)shr 3;
   WriteWordValue(Segs.Abs[NC],1);
  End;
  $8D:Begin { LEA }
   NC:=S86GetCode(1);
   If NC>=$C0 Then Goto InvalidOpcode;
   Case(NC and $C7)of
    $00:TW:=Regs.BX+Regs.SI;
    $01:TW:=Regs.BX+Regs.DI;
    $02:TW:=Regs.BP+Regs.SI;
    $03:TW:=Regs.BP+Regs.DI;
    $04:TW:=Regs.SI;
    $05:TW:=Regs.DI;
    $06:TW:=S86GetCode(2);
    $07:TW:=Regs.BX;
    $40:TW:=Regs.BX+Regs.SI+S86GetCode(2);
    $41:TW:=Regs.BX+Regs.DI+S86GetCode(2);
    $42:TW:=Regs.BP+Regs.SI+S86GetCode(2);
    $43:TW:=Regs.BP+Regs.DI+S86GetCode(2);
    $44:TW:=Regs.SI+S86GetCode(2);
    $45:TW:=Regs.DI+S86GetCode(2);
    $46:TW:=Regs.BP+S86GetCode(2);
    $47:TW:=Regs.BX+S86GetCode(2);
    $80:TW:=S86GetCode(2)+Regs.BX+Regs.SI;
    $81:TW:=S86GetCode(2)+Regs.BX+Regs.DI;
    $82:TW:=S86GetCode(2)+Regs.BP+Regs.SI;
    $83:TW:=S86GetCode(2)+Regs.BP+Regs.DI;
    $84:TW:=S86GetCode(2)+Regs.SI;
    $85:TW:=S86GetCode(2)+Regs.DI;
    $86:TW:=S86GetCode(2)+Regs.BP;
    $87:TW:=S86GetCode(2)+Regs.BX;
    Else TW:=0;
   End;
   Regs.AbsWord[(NC and$38)shr 3].Lo:=TW;
  End;
  $8E:Begin { MOV Seg,registre 16 bits}
   NC:=((S86GetCode(1)and$3F)shr 3)and 3;
   Segs.Abs[NC]:=ReadWordValue(1);
  End;
  $90:IncCode(1); { NOP }
  $91..$97:Begin { XCHG AX,? }
   SwapWord(Regs.AX,Regs.AbsWord[CurrCode and 7].Lo);
   IncCode(1);
  End;
  $98:Begin { CBW }
   If Regs.AL and $80>0 Then Begin
    Regs.AH:=$80;
    Regs.AL:=Regs.AL and $7F;
   End
    Else
   Regs.AH:=0;
   IncCode(1);
  End;
  $99:Begin { CWD }
    If((Regs.AX and $8000)<>0)Then Regs.DX:=$FFFF
                              Else Regs.DX:=$0000;
   IncCode(1);
  End;
  $9A:Begin { CALL FAR xxyyh:xxyyh }
   CallFar(GetCodeWord(1),GetCodeWord(3),5);
  End;
  $9B:Begin { WAIT }
{   If((MP)in(Q.Control.s))and
     ((TS)in(Q.Control.s))Then S86CallInt(7);}
   IncCode(1);
  End;
  $9C:Begin { PUSHF }
   PushWordStack(Flags.Abs);
   IncCode(1);
  End;
  $9D:PopWordFlags; { POPF }
  $9E:Begin { SAHF }
   Flags.DataByte:=Regs.AH;
   IncCode(1);
  End;
  $9F:Begin { LAHF }
   Regs.AH:=Flags.Abs;
   IncCode(1);
  End;
  $A0:Begin { MOV AL,? }
   Regs.AL:=ReadWordOfs(GetCodeWord(1));
   IncCode(3);
  End;
  { removed orphan else }
  { removed orphan goto }
  $A1:Begin { MOV AX,? }
   Regs.AX:=ReadWordOfs(GetCodeWord(1));
   IncCode(3);
  End;
  { removed orphan else }
  { removed orphan goto }
  $A2:Begin { MOV ?,AL }
   WriteByteOfs(Regs.AL,GetCodeWord(1));
   IncCode(3);
  End;
  { removed orphan else }
  { removed orphan goto }
  $A3:Begin { MOV ?,AX }
   WriteWordOfs(Regs.AX,GetCodeWord(1));
   IncCode(3);
  End;
  { removed orphan else }
  { removed orphan goto }
  $A4:Begin { MOVSB }
   S86MoveLeft(Segs.DS,Regs.SI,Segs.ES,Regs.DI,1);
   S86IncCountString(True,True);
   IncCode(1);
  End;
  $A5:Begin { MOVSW }
   S86MoveLeft(Segs.DS,Regs.SI,Segs.ES,Regs.DI,2);
   S86AddCountString(2,True,True);
   IncCode(1);
  End;
  $A8:Begin { TEST AL,xxh }
   S86TestByte(Regs.AL,S86GetCode(1));
   IncCode(2);
  End;
  { removed orphan else }
  { removed orphan goto }
  $A9:Begin { TEST AX,xxyyh }
   S86TestByte(Regs.AX,GetCodeWord(1));
   IncCode(3);
  End;
  { removed orphan else }
  { removed orphan goto }
  $AA:Begin { STOSB }
   WriteBlock(Segs.ES,Regs.DI,Regs.AL,SizeOf(Byte));
   S86IncCountString(False,True);
   IncCode(1);
  End;
  $AB:Begin { STOSW }
   WriteBlock(Segs.ES,Regs.DI,Regs.AX,SizeOf(Word));
   S86AddCountString(2,False,True);
   IncCode(1);
  End;
  $AC:Begin { LODSB }
   Regs.AL:=ReadWord(Segs.DS,Regs.SI);
   S86IncCountString(True,False);
   IncCode(1);
  End;
  $AD:Begin { LODSW }
   Regs.AX:=ReadWord(Segs.DS,Regs.SI);
   S86AddCountString(2,True,False);
   IncCode(1);
  End;
  $B0..$B7:Begin { MOV registre 8 bits,xxh }
   SetReg8Bits(CurrCode,S86GetCode(1));
   IncCode(2);
  End;
  $B8..$BF:Begin { MOV registre 16 bits,xxxxh }
   Regs.AbsWord[CurrCode and 7].Lo:=GetCodeWord(1);
   IncCode(3);
  End;
  $C0:If(CPU>=cpu80286)Then Begin
   Case S86GetCode(1)of
    $C0..$C7:Begin { ROL registre 8 bits,xxh }
     S86RolByte(Byte(GetReg8BitsPtr(S86GetCode(1))^),S86GetCode(2));
     IncCode(3);
    End;
    $C8..$CF:Begin { ROR registre 8 bits,xxh }
     S86RorByte(Byte(GetReg8BitsPtr(S86GetCode(1))^),S86GetCode(2));
     IncCode(3);
    End;
   End;
  End;
  { removed orphan else }
  { removed orphan goto }
  $C2,$C3:Begin { RETN ???? }
   NC:=CurrCode;
   IP:=PopWordStack;
   If NC=$C2Then Begin
    Inc(Regs.SP,GetCodeWord(1));
   End;
  End;
  $C4:Segs.ES:=LoadAddr(1); { LES }
  $C5:Segs.DS:=LoadAddr(1); { LDS }
  $C6:Begin
   WriteValue(S86GetCode(EstimateSizeOpCodeAddr(1)),1,False,opMov);
   IncCode(1); { Saute les donnÇes immÇdiate }
  End;
  $C7:Begin { MOV adresse,immÇdiat16 }
   WriteValue(S86GetCode(EstimateSizeOpCodeAddr(1)),1,True,opMov);
   IncCode(2); { Saute les donnÇes immÇdiate }
  End;
  $C9:If(CPU>=cpu80286)Then Begin { LEAVE }
   Regs.SP:=Regs.BP;
   Regs.BP:=PopWordStack;
   IncCode(1); { Saute les donnÇes immÇdiate }
  End
   Else
  Goto InvalidOpcode;
  $CA,$CB:Begin { RETF ???? }
   If CurrCode=$CAThen Inc(Regs.SP,GetCodeWord(1));
   IP:=PopWordStack;
   Segs.CS:=PopWordStack;
  End;
  $CC:Begin { INT/3}
   S86Int(3);
   IncCode(1);
  End;
  $CD:Begin { INT }
   S86Int(S86GetCode(1));
   IncCode(2);
  End;
  $CE:Begin { INTO }
   S86Int(4);
   IncCode(1);
  End;
  $D0:Begin
   Case S86GetCode(1)shr 3of
{C0}$18:S86RolByte(Byte(GetReg8BitsPtr(S86GetCode(1))^),1);      {ROL reg8,1}
{C8}$19:S86RorByte(Byte(GetReg8BitsPtr(S86GetCode(1))^),1);      {ROR reg8,1}
{E0}$1C:S86ShlByte(Byte(GetReg8BitsPtr(S86GetCode(1))^),1);      {SHL reg8,1}
{E8}$1D:S86ShrByte(Byte(GetReg8BitsPtr(S86GetCode(1))^),1);      {SHR reg8,1}
{F0}$1E:S86ShlByte(Byte(GetReg8BitsPtr(S86GetCode(1))^),1);      {SAL reg8,1}
{F8}$1F:S86SarByte(Byte(GetReg8BitsPtr(S86GetCode(1))^),1);      {SAR reg8,1}
    Else Goto InvalidOpcode;
   End;
   IncCode(2);
  End;
  $D1:Begin
   Case S86GetCode(1)shr 3of
{C0}$18:S86RolWord(Regs.AbsWord[S86GetCode(1)and 7].Lo,1);       {ROL reg16,1}
{C8}$19:S86RorWord(Regs.AbsWord[S86GetCode(1)and 7].Lo,1);       {ROR reg16,1}
{E0}$1C:S86ShlWord(Regs.AbsWord[S86GetCode(1)and 7].Lo,1);       {SHL reg16,1}
{E8}$1D:S86ShrWord(Regs.AbsWord[S86GetCode(1)and 7].Lo,1);       {SHR reg16,1}
{F0}$1E:S86ShlWord(Regs.AbsWord[S86GetCode(1)and 7].Lo,1);       {SAL reg16,1}
{F8}$1F:S86SarWord(Regs.AbsWord[S86GetCode(1)and 7].Lo,1);       {SAR reg16,1}
    Else Goto InvalidOpcode;
   End;
   IncCode(2);
  End;
  $D2:Begin
   Case S86GetCode(1)shr 3of
{C0}$18:S86RolByte(Byte(GetReg8BitsPtr(S86GetCode(1))^),Regs.CL);{ROL reg8,CL}
{C8}$19:S86RorByte(Byte(GetReg8BitsPtr(S86GetCode(1))^),Regs.CL);{ROR reg8,CL}
{E0}$1C:S86ShlByte(Byte(GetReg8BitsPtr(S86GetCode(1))^),Regs.CL);{SHL reg8,CL}
{E8}$1D:S86ShrByte(Byte(GetReg8BitsPtr(S86GetCode(1))^),Regs.CL);{SHR reg8,CL}
{F0}$1E:S86ShlByte(Byte(GetReg8BitsPtr(S86GetCode(1))^),Regs.CL);{SAL reg8,CL}
{F8}$1F:S86SarByte(Byte(GetReg8BitsPtr(S86GetCode(1))^),Regs.CL);{SAR reg8,CL}
    Else Goto InvalidOpcode;
   End;
   IncCode(2);
  End;
  $D3:Begin
   Case S86GetCode(1)shr 3of
{C0}$18:S86RolWord(Regs.AbsWord[S86GetCode(1)and 7].Lo,Regs.CL); {ROL reg16,CL}
{C8}$19:S86RorWord(Regs.AbsWord[S86GetCode(1)and 7].Lo,Regs.CL); {ROR reg16,CL}
{E0}$1C:S86ShlWord(Regs.AbsWord[S86GetCode(1)and 7].Lo,Regs.CL); {SHL reg16,CL}
{E8}$1D:S86ShrWord(Regs.AbsWord[S86GetCode(1)and 7].Lo,Regs.CL); {SHR reg16,CL}
{F0}$1E:S86ShlWord(Regs.AbsWord[S86GetCode(1)and 7].Lo,Regs.CL); {SAL reg16,CL}
{F8}$1F:S86SarWord(Regs.AbsWord[S86GetCode(1)and 7].Lo,Regs.CL); {SAR reg16,CL}
    Else Goto InvalidOpcode;
   End;
   IncCode(2);
  End;
  $D4:If S86GetCode(1)=$0AThen Begin { AAM }
   Regs.AH:=Regs.AL div S86GetCode(1);
   Regs.AL:=Regs.AL mod S86GetCode(1);
   IncCode(1);
  End;
  { removed orphan else }
  { removed orphan goto }
  $D5:If S86GetCode(1)=$0AThen Begin { AAD }
   Regs.AX:=(Regs.AL+(Regs.AH*S86GetCode(1)))and $FF;
   IncCode(1);
  End;
  { removed orphan else }
  { removed orphan goto }
  $D6:If(soSETALC)in(Option)Then Begin { SETALC }
   Regs.AL:=Byte((CF)in(Flags.s));
   IncCode(1);
  End;
  { removed orphan else }
  { removed orphan goto }
  $D7:Begin { XLAT }
   CurrSeg:=3;
   Regs.AL:=ReadWordOfs(Regs.BX+Regs.AL);
   IncCode(1);
  End;
  $E0:Begin { LOOPNE/LOOPNZ }
   Dec(Regs.CX);
   If(Regs.CX<>0)and(Not((ZF)in(Flags.s)))Then
    IncCode(2+ShortInt(S86GetCode(1)))
   Else
    IncCode(2);
  End;
  $E1:Begin { LOOPE/LOOPZ }
   Dec(Regs.CX);
   If(Regs.CX<>0)and((ZF)in(Flags.s))Then
    IncCode(2+ShortInt(S86GetCode(1)))
   Else
    IncCode(2);
  End;
  $E2:Begin { LOOP }
   Dec(Regs.CX);
   If Regs.CX=0Then IncCode(2)
               Else IncCode(2+ShortInt(S86GetCode(1)));
  End;
  $E3:Begin { JCXZ }
   If Regs.CX=0Then IncCode(2+ShortInt(S86GetCode(1)))
               Else IncCode(2);
  End;
  $E4:Begin { IN AL,? }
   Regs.AL:=InPortByte(S86GetCode(1));
   IncCode(2);
  End;
  $E5:Begin { IN AX,? }
   Regs.AX:=InPortWord(S86GetCode(1));
   IncCode(2);
  End;
  $E6:Begin { OUT ?,AL }
   OutPortByte(S86GetCode(1),Regs.AL);
   IncCode(2);
  End;
  $E7:Begin { OUT ?,AX }
   OutPortWord(S86GetCode(1),Regs.AX);
   IncCode(2);
  End;
  $E8:Begin { CALL Near }
   CallNear(IP+GetCodeWord(1)+3{ $FFFD-Q.IP+GetCodeWord(1)},3);
  End;
  $E9:Begin { JMP Near ????h }
   NearJmp(True,3);
  End;
  $EA:Begin { JMP Far ????h:????h }
   IP:=GetCodeWord(1);
   Segs.CS:=GetCodeWord(3);
  End;
  $EB:Begin { JMP short }
   IncCode(2+ShortInt(S86GetCode(1)));
  End;
  $EC:Begin { IN AL,DX }
   Regs.AL:=InPortByte(Regs.DX);
   IncCode(1);
  End;
  $ED:Begin { IN AX,DX }
   Regs.AX:=InPortWord(Regs.DX);
   IncCode(1);
  End;
  $EE:Begin { OUT DX,AL }
   OutPortByte(Regs.DX,Regs.AL);
   IncCode(1);
  End;
  $EF:Begin { OUT DX,AX }
   OutPortWord(Regs.DX,Regs.AX);
   IncCode(1);
  End;
  $F3:Case S86GetCode(1)of
   $66:Case S86GetCode(2)of
    $A5:Begin { REP MOVSD }
     S86MoveLeft(Segs.DS,Regs.SI,Segs.ES,Regs.DI,Regs.CX shl 2);
     S86AddCountString(Regs.CX shl 2,True,True);
     Regs.CX:=0;
     IncCode(3);
    End;
    Else IncCode(2);
   End;
   $A4:Begin { REP MOVSB }
    S86MoveLeft(Segs.DS,Regs.SI,Segs.ES,Regs.DI,Regs.CX);
    S86AddCountString(Regs.CX,True,True);
    Regs.CX:=0;
    IncCode(2);
   End;
   $A5:Begin { REP MOVSW }
    S86MoveLeft(Segs.DS,Regs.SI,Segs.ES,Regs.DI,Regs.CX shl 1);
    S86AddCountString(Regs.CX shl 1,True,True);
    Regs.CX:=0;
    IncCode(2);
   End;
   $A6:Begin { REP CMPSB }
    S86CompareByte(Segs.DS,Regs.SI,Segs.ES,Regs.DI,Regs.CX);
    S86AddCountString(Regs.CX,False,True);
    Regs.CX:=0;
    IncCode(2);
   End;
   $AA:Begin { REP STOSB }
    S86FillChar(Segs.ES,Regs.DI,Regs.CX,Regs.AL);
    S86AddCountString(Regs.CX,False,True);
    Regs.CX:=0;
    IncCode(2);
   End;
   $AB:Begin { REP STOSW }
    S86FillWord(Segs.ES,Regs.DI,Regs.CX shl 1,Regs.AX);
    S86AddCountString(Regs.CX shl 1,False,True);
    Regs.CX:=0;
    IncCode(2);
   End;
   Else IncCode(1);
  End;
  $F4:Begin { HLT }
   Fault:=sfHLT;
   IncCode(1);
  End;
  $F5:Begin { CMC }
   If(CF)in(Flags.s)Then Exclude(Flags.s,CF)
                    Else Include(Flags.s,CF);
   IncCode(1);
  End;
  $F6:Begin
   NC:=S86GetCode(1);
   Case(NC)of
    $C0..$C7:Begin { TEST registre 8 bits,immÇdiat }
     S86TestByte(Byte(GetReg8BitsPtr(S86GetCode(1))^),GetCodeWord(2));
     IncCode(4);
    End;
    $D0..$D7:Begin
     SetReg8Bits(NC,Not GetReg8Bits(NC));
     IncCode(2);
    End;
    $D8..$DF:Begin
     SetReg8Bits(NC,-GetReg8Bits(NC));
     IncCode(2);
    End;
    $E0..$E7:Begin
     S86MulByte(GetReg8Bits(NC));
     IncCode(2);
    End;
    $E8..$EF:Begin
     S86IMulByte(GetReg8Bits(NC));
     IncCode(2);
    End;
    $F0..$F7:Begin
     S86DivByte(GetReg8Bits(NC));
     IncCode(2);
    End;
    $F8..$FF:Begin
     S86IDivByte(GetReg8Bits(NC));
     IncCode(2);
    End;
    Else Goto InvalidOpcode;
   End;
  End;
  $F7:Begin
   NC:=S86GetCode(1);
   Case(NC)of
    $20..$27:Begin
     WriteValue(S86GetCode(EstimateSizeOpCodeAddr(1)),1,True,opMul);
    End;
    $30..$37:Begin
     S86DivWord(ReadValue(1,1));
     Dec(IP,2);
    End;
    $60..$67:Begin
     S86MulWord(ReadValue(1,1));
    End;
    $68..$6F:Begin
     S86IMulWord(ReadValue(1,1));
    End;
    $70..$77:Begin
     S86DivWord(ReadValue(1,1));
    End;
    $78..$7F:Begin
     S86IDivWord(ReadValue(1,1));
    End;
    $C0..$C7:Begin
     S86TestWord(Regs.AbsWord[NC and 7].Lo,GetCodeWord(2));
     IncCode(4);
    End;
    $D0..$D7:Begin
     S86NotWord(Regs.AbsWord[NC and 7].Lo);
     IncCode(2);
    End;
    $D8..$DF:Begin
     S86NegWord(Regs.AbsWord[NC and 7].Lo);
     IncCode(2);
    End;
    $E0..$E7:Begin
     S86MulWord(Regs.AbsWord[NC and 7].Lo);
     IncCode(2);
    End;
    $E8..$EF:Begin
     S86IMulWord(Regs.AbsWord[NC and 7].Lo);
     IncCode(2);
    End;
    $F0..$F7:Begin
     S86DivWord(Regs.AbsWord[NC and 7].Lo);
     IncCode(2);
    End;
    $F8..$FF:Begin
     S86IDivWord(Regs.AbsWord[NC and 7].Lo);
     IncCode(2);
    End;
    Else Goto InvalidOpcode;
   End;
  End;
  $F8:Begin { CLC }
   Exclude(Flags.s,CF);
   IncCode(1);
  End;
  $F9:Begin { STC }
   Include(Flags.s,CF);
   IncCode(1);
  End;
  $FA:Begin { CLI }
   Exclude(Flags.s,_IF);
   IncCode(1);
  End;
  $FB:Begin { STI }
   Include(Flags.s,_IF);
   IncCode(1);
  End;
  $FC:Begin { CLD }
   Exclude(Flags.s,DF);
   IncCode(1);
  End;
  $FD:Begin { STD }
   Include(Flags.s,DF);
   IncCode(1);
  End;
  $FE:Begin
   NC:=S86GetCode(1);
   Case(NC)of
    $00..$07:Begin { INC registre 8 bits }
     WriteValue(0{InutilisÇ},1,True,opInc);
    End;
    $08..$0F:Begin { DEC registre 8 bits }
     WriteValue(0{InutilisÇ},1,True,opDec);
    End;
    $C0..$C7:Begin { INC }
     S86IncByte(Byte(GetReg8BitsPtr(NC)^));
     IncCode(2);
    End;
    $C8..$CF:Begin { DEC }
     S86DecByte(Byte(GetReg8BitsPtr(NC)^));
     IncCode(2);
    End;
    Else Goto InvalidOpcode;
   End;
  End;
  $FF:Begin
   NC:=S86GetCode(1);
   Case(NC)of
    $1E:Begin { CALL Far Ptr [yyxxh] }
     Case(CurrSeg)of
      0..3:TW:=Segs.Abs[CurrSeg];
      4:TW:=FS;
      5:TW:=GS;
      Else TW:=Segs.DS;
     End;
     CallFar(ReadWordOfs(GetCodeWord(2)),TW,4);
    End;
    $D0..$D7:Begin { CALL registre 16 bits }
     CallNear(Word(Regs.Abs[NC and 7]),2);
    End;
    Else Goto InvalidOpcode;
   End;
  End;
  Else Begin
   InvalidOpCode:WriteLn('Code machine invalide! CS:IP='+
                          HexWord2Str(Segs.CS)+'h:'+
                          HexWord2Str(IP)+'h Code Data '+
                          ByteHex2Str(CurrCode)+' '+
                          ByteHex2Str(S86GetCode(1))+' '+
                          ByteHex2Str(S86GetCode(2)));
   Fault:=sfInvalidCode;
  End;
 End;
End;

Procedure Done;Begin
 Close(Memory);
 {$I-}Assign(Memory,SwapFileMemory);
 Erase(Memory);{$I+}
End;

Procedure S86LoadCom(Const FileName:String);
Var
 PSP:PSPRecord;
 Buffer:Pointer;
 Handle:File;
 Size:LongInt;
 X,Y,MX:Byte;
 ByteWrited,ByteReaded:Word;
Begin
 {$I-}Assign(Handle,FileName);
 Reset(Handle,1);{$I+}
 If(IoResult=0)Then Begin
  {DOSVersion:=$0005;} { Version 5.0 }
  Segs.CS:=$0060;
  Segs.DS:=Segs.CS;
  Segs.ES:=Segs.CS;
  Segs.SS:=Segs.CS;
  Regs.SP:=$FFFE;
  Regs.BP:=$091C;
  IP:=$100;
   { êcriture des donnÇes du PSP }
  FillChar(PSP,SizeOf(PSP),0);
  PSP.Int20h:=$20CD;
  PSP.EndSegPrg:=$9FFF;
  PSP.ParentSeg:=$52;
  PSP.EnvSeg:=$51;
  PSP.LenHandle:=20;
  PSP.HandlePtrOfs:=$18;
  PSP.HandlePtrSeg:=Segs.CS;
  PSP.Int21h:=$21CD;
  PSP.RETF:=$CB;
  WriteBlock(Segs.CS,0,PSP.Buffer,$100);
  Size:=FileSize(Handle);
  GetMem(Buffer,Size);
  If(Buffer<>NIL)Then Begin
   Seek(Handle,0);
   BlockRead(Handle,Buffer^,Size,ByteReaded);
   WriteBlock(Segs.CS,IP,Buffer^,Size);
   If(Verbose)Then WriteLn('Fichier chargÇ en mÇmoire');
  End
   Else
  If(Verbose)Then WriteLn('Manque de mÇmoire pour charger le programme.');
  FreeMem(Buffer,Size);
  Close(Handle);
 End;
End;

Procedure S86LoadExe(Const FileName:String);
Var
 HeadSize,Addr,Pos,I,LoadSeg:LongInt;
 N:LongInt;
 PSPSeg,ROff,RSeg:Word;
 PSP:PSPRecord;
 Handle:File;
 ByteReaded:Word;
 Exe:HeaderEXE;
 Buffer:Array[0..255]of Byte;
 Reloc:Array[0..1]of Word;
Begin
{$I-}Assign(Handle,FileName);
 Reset(Handle,1);{$I+}
 If(IoResult=0)Then Begin
  Seek(Handle,0);
  BlockRead(Handle,Exe,SizeOf(Exe),ByteReaded);
  If Not((Exe.Sign[0]='M')and(Exe.Sign[1]='Z'))Then Begin
   WriteLn('Format d''exÇcutable invalide !');
   Halt(10);
  End;
  HeadSize:=Exe.SizeOfHeader*16;
  PSPSeg:=$0060;
  LoadSeg:=PSPSeg+17;
  IP:=Exe.IP;
  Segs.CS:=LoadSeg+Exe.OfsLoad;
  Segs.DS:=PSPSeg+1;
  Segs.ES:=PSPSeg+1;
  Segs.SS:=LoadSeg+Exe.OfsLoadStack;
  Regs.SP:=Exe.SizeOfStack;
  Regs.BP:=$091C;
   { êcriture des donnÇes du PSP }
  FillChar(PSP,SizeOf(PSP),0);
  PSP.Int20h:=$20CD;
  PSP.EndSegPrg:=$9FFF;
  PSP.ParentSeg:=$52;
  PSP.EnvSeg:=$51;
  PSP.LenHandle:=20;
  PSP.HandlePtrOfs:=$18;
  PSP.HandlePtrSeg:=Segs.CS;
  PSP.Int21h:=$21CD;
  PSP.RETF:=$CB;
  WriteBlock(PSPSeg,0,PSP.Buffer,$100);
  Addr:=(Segs.CS shl 4)+Exe.IP;
  Seek(Handle,HeadSize+Exe.IP);
  While Not EOF(Handle)do Begin
   BlockRead(Handle,Buffer,SizeOf(Buffer),ByteReaded);
   WriteAbsBlock(Addr,Buffer,ByteReaded);
   Inc(Addr,ByteReaded);
  End;
   { Relogement des donnÇes}
  Seek(Handle,Exe.AdrExeTable);
  For I:=1 to Exe.NmSeg do Begin
   BlockRead(Handle,Reloc,SizeOf(Reloc),ByteReaded);
   If ByteReaded<>SizeOf(Reloc) Then Break;
   ROff:=Reloc[0];
   RSeg:=LoadSeg+Reloc[1];
   Pos:=ROff+16*RSeg;
   ReadAbsBlock(Pos,N,2);
   N:=N+LoadSeg;
   WriteAbsBlock(Pos,N,2);
  End;
  Close(Handle);
 End;
End;

BEGIN
 {$IFDEF FPC}
  {$IFDEF WINDOWS}
   SetUseACP(False);
  {$ENDIF}
 {$ENDIF}
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('RUNIBMPC : Cette commande permet d''exÇcuter du code pour IBM PC (microprocesseur 8086).');
  WriteLn;
  WriteLn('Syntaxe : RUNIBMPC [option] [nomdufichier]');
  WriteLn;
  WriteLn(' nomduficher           Nom du fichier de format COM');
  WriteLn(' /AMDEKSYSTEM88        Simulation du micro-ordinateur Amdek System/88');
  WriteLn(' /CONTERMMAX           Simulation du micro-ordinateur Conterm Max');
  WriteLn(' /CPU:model            Modäle du microprocesseur : 8086, 8088,...');
  WriteLn(' /CPUID                Active le support de l''instruction CPUID');
  WriteLn(' /CPUVENDOR:fabricant  Fabricant du microprocesseur : AMD, IBM, INTEL, CYRIX');
  WriteLn(' /IBMPC                Simulation du micro-ordinateur IBM PC original');
  WriteLn(' /OLIVETTIM24          Simulation du micro-ordinateur Olivetti M24');
  WriteLn(' /PCAT                 Simulation du micro-ordinateur PC AT');
  WriteLn(' /PCJR                 Simulation du micro-ordinateur PC Junior');
  WriteLn(' /PCXT                 Simulation du micro-ordinateur PC XT');
  WriteLn(' /READONLY             Interdit la modification des donnÇes sur disque');
  WriteLn(' /SETALC               Active le support de l''instruction SETALC');
  WriteLn(' /WANG                 Simulation du micro-ordinateur WANG');
 End
  Else
 If ParamCount>0 Then Begin
  FillChar(FilesHandlesUsed,SizeOf(FilesHandlesUsed),0);
  CurrFilesHandles:=Low(FilesHandles);
  Option:=[];
  Debug:=False;
  Verbose:=False;
  ReadOnlyMachine:=False;
  CmosPos:=0;
  NextRawKey:=0;
  FileName:='';
  ModelComputer:=mcIBMPC;
  CPU:=cpu8086;
  For I:=1 to ParamCount do Begin
   If StrToUpper(ParamStr(I))='/AMDEKSYSTEM88'Then ModelComputer:=mcAmdekSystem88 Else
   If StrToUpper(ParamStr(I))='/CONTERMMAX'Then ModelComputer:=mcContermMax Else
   If Copy(ParamStr(I),1,Length('/CPU:'))='/CPU:'Then Begin
    S:=Copy(ParamStr(I),Length('/CPU:')+1,255);
    If(S='86')or(S='8086')Then CPU:=cpu8086 Else
    If(S='88')or(S='8088')Then CPU:=cpu8088 Else
    If(S='186')or(S='80186')Then CPU:=cpu80186 Else
    If(S='188')or(S='80188')Then CPU:=cpu80188 Else
    If(S='286')or(S='80286')Then CPU:=cpu80286 Else
    If(S='386')or(S='i386')or(S='80386')Then CPU:=cpui386 Else
    If(S='486')or(S='i486')or(S='80486')Then CPU:=cpui486 Else
    If(S='NECV20')or(S='V20')Then CPU:=cpuV20 Else
    If(S='NECV30')or(S='V30')Then CPU:=cpuV30 Else
    If(S='PENTIUM')Then Begin
     CPU:=cpuPentium;
     Include(Option,soCPUID);
    End
     Else
    Begin
     WriteLn('Microprocesseur non reconnu');
     Halt(5);
    End;
   End
    Else
   If StrToUpper(ParamStr(I))='/CPUID'Then Include(Option,soCPUID) Else
   If Copy(ParamStr(I),1,Length('/CPUVENDOR:'))='/CPUVENDOR:'Then Begin
    S:=Copy(ParamStr(I),Length('/CPUVENDOR:')+1,255);
    If S='AMD'Then CPUVendor:=cvAMD Else
    If S='CYRIX'Then CPUVendor:=cvCYRIX Else
    If S='IBM'Then CPUVendor:=cvIBM Else
    If S='INTEL'Then CPUVendor:=cvINTEL
     Else
    Begin
     WriteLn('Fabricant de microprocesseur non reconnu');
     Halt(6);
    End;
   End
    Else
   If StrToUpper(ParamStr(I))='/DEBUG'Then Debug:=True Else
   If StrToUpper(ParamStr(I))='/IBMPC'Then ModelComputer:=mcIBMPC Else
   If StrToUpper(ParamStr(I))='/OLIVETTIM24'Then ModelComputer:=mcOlivettiM24 Else
   If StrToUpper(ParamStr(I))='/PCAT'Then ModelComputer:=mcPC_AT Else
   If(StrToUpper(ParamStr(I))='/PCJR')or
     (StrToUpper(ParamStr(I))='/PCJUNIOR')Then ModelComputer:=mcPCJunior Else
   If StrToUpper(ParamStr(I))='/PCXT'Then ModelComputer:=mcPC_XT Else
   If StrToUpper(ParamStr(I))='/READONLY'Then ReadOnlyMachine:=True Else
   If StrToUpper(ParamStr(I))='/SETALC'Then Include(Option,soSETALC) Else
   If StrToUpper(ParamStr(I))='/VERBOSE'Then Verbose:=True Else
   If StrToUpper(ParamStr(I))='/WANG'Then ModelComputer:=mcWang
                                     Else FileName:=ParamStr(I);
  End;
  If FileName<>''Then Begin
   InitComputer;
   If StrToUpper(Path2Ext(FileName))='.COM'Then Begin
    If(Verbose)Then WriteLn('Chargement du fichier COM Æ',FileName,'Ø');
    S86LoadCom(FileName);
   End
    Else
   Begin
    If(Verbose)Then WriteLn('Chargement du fichier EXE Æ',FileName,'Ø');
    S86LoadExe(FileName);
   End;
   If(Verbose)Then WriteLn('ExÇcution du code');
   Repeat
    Run;
   Until Fault<>0;
   If(Verbose)Then WriteLn('ExÇcution terminÇ : ',Fault);
   Done;
   If(Verbose)Then WriteLn('Resource libÇrÇ');
  End;
 End
  Else
 WriteLn('Paramätre requis !');
END.
