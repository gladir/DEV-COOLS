{ @author: Sylvain Maltais (support@gladir.com)
 @created: 2026
 @website(https://www.gladir.com/dev-cools)
 @abstract(Target: Turbo Pascal 7 / Free Pascal 3.2)
 @abstract: Emulateur MSP430 (CPU 16 bits, sans extension 20 bits),
  compatible Turbo Pascal / Free Pascal.
 @license: MIT }

Program MSP430;

{$A-}
{$R-}
{$Q-}

Uses Dos;

Const
 { Bits du registre d'etat SR (R2) }
 FlagC=$0001;
 FlagZ=$0002;
 FlagN=$0004;
 FlagGIE=$0008;
 FlagCPUOFF=$0010;
 FlagV=$0100;

 { Registres des peripheriques emules (famille MSP430G2xx) }
 AddrIFG2=$0003;
 AddrP1IN=$0020;
 AddrP1OUT=$0021;
 AddrP1DIR=$0022;
 AddrP2IN=$0028;
 AddrP2OUT=$0029;
 AddrP2DIR=$002A;
 AddrRXBUF=$0066;
 AddrTXBUF=$0067;
 AddrTAIV=$012E;
 AddrWDTCTL=$0120;
 AddrTACTL=$0160;
 AddrTACCTL0=$0162;
 AddrTAR=$0170;
 AddrTACCR0=$0172;

 { Vecteurs d'interruption }
 VectTimerA1=$FFF0;
 VectTimerA0=$FFF2;
 VectReset=$FFFE;

 { Raisons d'arret de l'emulation }
 StopNone=0;
 StopLimit=1;
 StopIllegal=2;
 StopLoop=3;
 StopSleep=4;

Type
 TBank=Array[0..32767]Of Byte;
 PBank=^TBank;
 TCPU=Record
  R:Array[0..15]Of Word;
  Bank:Array[0..1]Of PBank;
  Cycles:LongInt;
  Count:LongInt;
  Stopped:Boolean;
  Reason:Integer;
  Fault:Word;
  FaultPC:Word;
  TimerAcc:LongInt;
  TimerDown:Boolean;
  P1In:Byte;
  Input:String;
  InputPos:Integer;
  OutCount:LongInt;
  LastOut:Byte;
  Trace:Boolean
 End;
 TLoc=Record
  Kind:Byte;      { 0=registre, 1=memoire, 2=constante }
  Num:LongInt;    { numero de registre, adresse ou valeur }
  Mode:Byte       { mode d'adressage d'origine }
 End;

Var
 CPU:TCPU;
 Language:Byte;   { 0=FR, 1=EN, 2=GR, 3=SP, 4=IT }
 TmpLanguage:String;
 FileName:String;
 LoadAddr,StartAddr,DumpFrom,DumpTo:LongInt;
 MaxInstr:LongInt;
 Quiet,DoDump:Boolean;

{ ------------------------------------------------------------------ }
{  Utilitaires et messages multilingues                              }
{ ------------------------------------------------------------------ }

Function Upper(Const S:String):String;
Var
 R:String;
 J:Integer;
Begin
 R:=S;
 For J:=1To Length(R)Do R[J]:=UpCase(R[J]);
 Upper:=R
End;

Function T(Const F,E,G,S,I:String):String;Begin
 Case Language Of
  1:T:=E;
  2:T:=G;
  3:T:=S;
  4:T:=I;
  Else T:=F
 End
End;

Function Hex2(V:Byte):String;
Const
 H:String[16]='0123456789ABCDEF';
Begin
 Hex2:=H[(V Shr 4)+1]+H[(V And 15)+1]
End;

Function Hex4(V:Word):String;Begin
 Hex4:=Hex2(V Shr 8)+Hex2(V And $FF)
End;

Function HexValue(Const S:String):LongInt;
Var
 J:Integer;
 V:LongInt;
 C:Char;
Begin
 HexValue:=-1;
 If(S='')Or(Length(S)>6)Then Exit;
 V:=0;
 For J:=1To Length(S)Do Begin
  C:=UpCase(S[J]);
  If C In['0'..'9']Then V:=V*16+Ord(C)-48
  Else If C In['A'..'F']Then V:=V*16+Ord(C)-55
  Else Exit
 End;
 HexValue:=V
End;

Procedure InitLanguage;Begin
 Language:=0;
 TmpLanguage:=GetEnv('LANGUAGE');
 If TmpLanguage<>''Then Begin
  If TmpLanguage[1]='"'Then TmpLanguage:=Copy(TmpLanguage,2,255);
  TmpLanguage:=Upper(Copy(TmpLanguage,1,2));
  If TmpLanguage='EN'Then Language:=1 Else
  If TmpLanguage='GR'Then Language:=2 Else
  If TmpLanguage='SP'Then Language:=3 Else
  If TmpLanguage='IT'Then Language:=4
 End
End;

{ ------------------------------------------------------------------ }
{  Memoire (deux banques de 32 Ko pour rester compatible Turbo Pascal) }
{ ------------------------------------------------------------------ }

Function RawGet(Var C:TCPU;A:Word):Byte;Begin
 RawGet:=C.Bank[A Shr 15]^[A And $7FFF]
End;

Procedure RawPut(Var C:TCPU;A:Word;V:Byte);Begin
 C.Bank[A Shr 15]^[A And $7FFF]:=V
End;

Function RawGetW(Var C:TCPU;A:Word):Word;Begin
 RawGetW:=RawGet(C,A)Or(Word(RawGet(C,A+1))Shl 8)
End;

Procedure RawPutW(Var C:TCPU;A:Word;V:Word);Begin
 RawPut(C,A,V And $FF);RawPut(C,A+1,V Shr 8)
End;

Procedure SetBits(Var C:TCPU;A:Word;M:Byte);Begin
 RawPut(C,A,RawGet(C,A)Or M)
End;

Function AllocMemory(Var C:TCPU):Boolean;Begin
 AllocMemory:=False;
 C.Bank[0]:=Nil;C.Bank[1]:=Nil;
 New(C.Bank[0]);New(C.Bank[1]);
 FillChar(C.Bank[0]^,SizeOf(TBank),0);
 FillChar(C.Bank[1]^,SizeOf(TBank),0);
 AllocMemory:=True
End;

Function PortRead(Var C:TCPU;InAddr:Word;Value:Byte):Byte;
Var
 Dir:Byte;
Begin
 Dir:=RawGet(C,InAddr+2);
 PortRead:=(Value And Not Dir)Or(RawGet(C,InAddr+1)And Dir)
End;

{ Lecture d'un octet avec gestion des peripheriques }
Function ReadByte(Var C:TCPU;A:Word):Byte;
Var
 V:Byte;
Begin
 Case A Of
  AddrP1IN:ReadByte:=PortRead(C,A,C.P1In);
  AddrP2IN:ReadByte:=PortRead(C,A,0);
  AddrIFG2:Begin
   V:=2;
   If C.InputPos<=Length(C.Input)Then V:=V Or 1;
   ReadByte:=V
  End;
  AddrRXBUF:Begin
   If C.InputPos<=Length(C.Input)Then Begin
    ReadByte:=Ord(C.Input[C.InputPos]);Inc(C.InputPos)
   End
    Else
   ReadByte:=0
  End;
  AddrWDTCTL+1:ReadByte:=$69;
  AddrTAIV:Begin
   If(RawGet(C,AddrTACTL)And 1)<>0Then Begin
    RawPut(C,AddrTACTL,RawGet(C,AddrTACTL)And $FE);ReadByte:=$0A
   End
    Else
   ReadByte:=0
  End;
  Else ReadByte:=RawGet(C,A)
 End
End;

Function ReadWord(Var C:TCPU;A:Word):Word;Begin
 A:=A And $FFFE;
 ReadWord:=ReadByte(C,A)Or(Word(ReadByte(C,A+1))Shl 8)
End;

{ Ecriture d'un octet avec gestion des peripheriques }
Procedure WriteByte(Var C:TCPU;A:Word;V:Byte);Begin
 Case A Of
  AddrP1IN,AddrP2IN:;
  AddrTXBUF:Begin
   Write(Chr(V));C.LastOut:=V;Inc(C.OutCount)
  End;
  AddrTACTL:Begin
   If(V And 4)<>0Then Begin
    RawPutW(C,AddrTAR,0);C.TimerAcc:=0;C.TimerDown:=False;V:=V And $FB
   End;
   RawPut(C,A,V)
  End;
  Else RawPut(C,A,V)
 End
End;

Procedure CPUReset(Var C:TCPU);Begin
 FillChar(C.R,SizeOf(C.R),0);
 C.R[1]:=$0400;
 C.R[0]:=RawGetW(C,VectReset)And $FFFE
End;

Procedure WriteWord(Var C:TCPU;A:Word;V:Word);Begin
 A:=A And $FFFE;
 If A=AddrWDTCTL Then Begin
  { Mot de passe invalide: reinitialisation (PUC) }
  If(V Shr 8)<>$5A Then CPUReset(C)Else RawPutW(C,A,V And $FF);
  Exit
 End;
 WriteByte(C,A,V And $FF);WriteByte(C,A+1,V Shr 8)
End;

Function Fetch(Var C:TCPU):Word;Begin
 Fetch:=ReadWord(C,C.R[0]);C.R[0]:=C.R[0]+2
End;

Procedure Push(Var C:TCPU;V:Word);Begin
 C.R[1]:=(C.R[1]-2)And $FFFE;WriteWord(C,C.R[1],V)
End;

Function Pop(Var C:TCPU):Word;Begin
 Pop:=ReadWord(C,C.R[1]);C.R[1]:=(C.R[1]+2)And $FFFE
End;

{ ------------------------------------------------------------------ }
{  Operandes                                                         }
{ ------------------------------------------------------------------ }

{ Calcule l'emplacement d'un operande (mode d'adressage As ou Ad) }
Procedure Resolve(Var C:TCPU;Mode,Reg:Integer;ByteOp,IsSrc:Boolean;
                  Var L:TLoc);
Var
 X,ExtAddr:Word;
Begin
 L.Kind:=0;L.Num:=Reg;L.Mode:=Mode;
 If IsSrc Then Begin
  { Generateurs de constantes: R3 (0,1,2,-1) et R2 (4,8) }
  If Reg=3 Then Begin
   L.Kind:=2;
   Case Mode Of
    0:L.Num:=0;
    1:L.Num:=1;
    2:L.Num:=2;
    Else L.Num:=$FFFF
   End;
   Exit
  End;
  If(Reg=2)And(Mode>=2)Then Begin
   L.Kind:=2;
   If Mode=2 Then L.Num:=4 Else L.Num:=8;
   Exit
  End
 End;
 Case Mode Of
  1:Begin
   ExtAddr:=C.R[0];X:=Fetch(C);L.Kind:=1;
   If Reg=2 Then L.Num:=X                      { absolu &ADDR }
   Else If Reg=0 Then L.Num:=Word(ExtAddr+X)   { symbolique ADDR }
   Else L.Num:=Word(C.R[Reg]+X)                { indexe X(Rn) }
  End;
  2:Begin
   L.Kind:=1;L.Num:=C.R[Reg]
  End;
  3:Begin
   If Reg=0 Then Begin
    L.Kind:=2;L.Num:=Fetch(C)                  { immediat #N }
   End
    Else
   Begin
    L.Kind:=1;L.Num:=C.R[Reg];
    If ByteOp And(Reg>1)Then C.R[Reg]:=C.R[Reg]+1
                        Else C.R[Reg]:=C.R[Reg]+2
   End
  End
 End
End;

Function ReadLoc(Var C:TCPU;Const L:TLoc;ByteOp:Boolean):LongInt;
Var
 V:LongInt;
Begin
 Case L.Kind Of
  0:If L.Num=3 Then V:=0 Else V:=C.R[L.Num];
  1:If ByteOp Then V:=ReadByte(C,Word(L.Num))
              Else V:=ReadWord(C,Word(L.Num));
  Else V:=L.Num
 End;
 If ByteOp Then V:=V And $FF Else V:=V And $FFFF;
 ReadLoc:=V
End;

Procedure WriteLoc(Var C:TCPU;Const L:TLoc;ByteOp:Boolean;V:LongInt);Begin
 Case L.Kind Of
  0:Begin
   If L.Num=3 Then Exit;
   If ByteOp Then V:=V And $FF Else V:=V And $FFFF;
   If L.Num<=1 Then V:=V And $FFFE;
   C.R[L.Num]:=Word(V)
  End;
  1:If ByteOp Then WriteByte(C,Word(L.Num),Byte(V And $FF))
              Else WriteWord(C,Word(L.Num),Word(V And $FFFF))
 End
End;

{ ------------------------------------------------------------------ }
{  Unite arithmetique et logique                                     }
{ ------------------------------------------------------------------ }

Procedure SetFlag(Var C:TCPU;F:Word;On:Boolean);Begin
 If On Then C.R[2]:=C.R[2]Or F Else C.R[2]:=C.R[2]And Not F
End;

Function MaskOf(ByteOp:Boolean):LongInt;Begin
 If ByteOp Then MaskOf:=$FF Else MaskOf:=$FFFF
End;

Function SignOf(ByteOp:Boolean):LongInt;Begin
 If ByteOp Then SignOf:=$80 Else SignOf:=$8000
End;

Procedure SetNZ(Var C:TCPU;Res:LongInt;ByteOp:Boolean);Begin
 SetFlag(C,FlagZ,Res=0);
 SetFlag(C,FlagN,(Res And SignOf(ByteOp))<>0)
End;

{ Addition D+S+Cin avec calcul des indicateurs C,Z,N,V }
Function AluAdd(Var C:TCPU;S,D,Cin:LongInt;ByteOp:Boolean):LongInt;
Var
 Res,Sum:LongInt;
Begin
 Sum:=D+S+Cin;Res:=Sum And MaskOf(ByteOp);
 SetNZ(C,Res,ByteOp);
 SetFlag(C,FlagC,Sum>MaskOf(ByteOp));
 SetFlag(C,FlagV,((S Xor Res)And(D Xor Res)And SignOf(ByteOp))<>0);
 AluAdd:=Res
End;

{ Addition decimale (BCD) }
Function AluDadd(Var C:TCPU;S,D:LongInt;ByteOp:Boolean):LongInt;
Var
 J,Digits,Carry,Sum,Res:LongInt;
Begin
 If ByteOp Then Digits:=2 Else Digits:=4;
 If(C.R[2]And FlagC)<>0Then Carry:=1 Else Carry:=0;
 Res:=0;
 For J:=0To Digits-1Do Begin
  Sum:=((S Shr(4*J))And 15)+((D Shr(4*J))And 15)+Carry;
  If Sum>9Then Begin
   Sum:=Sum-10;Carry:=1
  End
   Else
  Carry:=0;
  Res:=Res Or(Sum Shl(4*J))
 End;
 SetNZ(C,Res,ByteOp);SetFlag(C,FlagC,Carry<>0);
 AluDadd:=Res
End;

Procedure LogicFlags(Var C:TCPU;Res:LongInt;ByteOp:Boolean);Begin
 SetNZ(C,Res,ByteOp);SetFlag(C,FlagC,Res<>0);SetFlag(C,FlagV,False)
End;

{ ------------------------------------------------------------------ }
{  Peripheriques: Timer_A et interruptions                           }
{ ------------------------------------------------------------------ }

Procedure TimerTick(Var C:TCPU;N:LongInt);
Var
 Ctl,Mc,Divisor,Tar,Ccr0:LongInt;
Begin
 Ctl:=RawGetW(C,AddrTACTL);Mc:=(Ctl Shr 4)And 3;
 If Mc=0Then Exit;
 Divisor:=1 Shl((Ctl Shr 6)And 3);
 C.TimerAcc:=C.TimerAcc+N;
 While C.TimerAcc>=Divisor Do Begin
  Dec(C.TimerAcc,Divisor);
  Tar:=RawGetW(C,AddrTAR);Ccr0:=RawGetW(C,AddrTACCR0);
  Case Mc Of
   1:Begin
    If Tar>=Ccr0 Then Begin
     Tar:=0;SetBits(C,AddrTACTL,1)
    End
     Else
    Inc(Tar)
   End;
   2:Begin
    Tar:=(Tar+1)And $FFFF;
    If Tar=0Then SetBits(C,AddrTACTL,1)
   End;
   Else Begin
    If C.TimerDown Then Begin
     If Tar>0Then Dec(Tar);
     If Tar=0Then Begin
      C.TimerDown:=False;SetBits(C,AddrTACTL,1)
     End
    End
     Else
    Begin
     If Tar<Ccr0 Then Inc(Tar);
     If Tar>=Ccr0 Then C.TimerDown:=True
    End
   End
  End;
  If Tar=Ccr0 Then SetBits(C,AddrTACCTL0,1);
  RawPutW(C,AddrTAR,Word(Tar))
 End
End;

{ Retourne le vecteur de l'interruption en attente (0 = aucune) }
Function PendingVector(Var C:TCPU):Word;Begin
 PendingVector:=0;
 If(RawGet(C,AddrTACCTL0)And $11)=$11Then PendingVector:=VectTimerA0 Else
 If(RawGet(C,AddrTACTL)And 3)=3Then PendingVector:=VectTimerA1
End;

{ Vrai si une interruption peut encore reveiller le processeur }
Function CanWake(Var C:TCPU):Boolean;
Var
 Ctl:Word;
Begin
 Ctl:=RawGetW(C,AddrTACTL);
 CanWake:=((C.R[2]And FlagGIE)<>0)And(((Ctl Shr 4)And 3)<>0)And
  (((RawGet(C,AddrTACCTL0)And $10)<>0)Or((Ctl And 2)<>0))
End;

Procedure ServiceInterrupt(Var C:TCPU;Vec:Word);Begin
 Push(C,C.R[0]);Push(C,C.R[2]);C.R[2]:=0;
 C.R[0]:=ReadWord(C,Vec)And $FFFE;
 If Vec=VectTimerA0 Then RawPut(C,AddrTACCTL0,RawGet(C,AddrTACCTL0)And $FE);
 Inc(C.Cycles,6);Inc(C.Count);TimerTick(C,6)
End;

{ ------------------------------------------------------------------ }
{  Execution des instructions                                        }
{ ------------------------------------------------------------------ }

Procedure StopCPU(Var C:TCPU;Why:Integer);Begin
 C.Stopped:=True;C.Reason:=Why
End;

Function SrcCycles(Const L:TLoc;Reg:Integer):Integer;Begin
 Case L.Kind Of
  0:SrcCycles:=1;
  2:If(Reg=0)And(L.Mode=3)Then SrcCycles:=2 Else SrcCycles:=1;
  Else If L.Mode=1 Then SrcCycles:=3 Else SrcCycles:=2
 End
End;

Procedure ExecFormat1(Var C:TCPU;W:Word);
Var
 Opc,SReg,DReg,Ad,As:Integer;
 ByteOp,Store:Boolean;
 LS,LD:TLoc;
 S,D,Res:LongInt;
 Cy:Integer;
Begin
 Opc:=W Shr 12;SReg:=(W Shr 8)And 15;DReg:=W And 15;
 Ad:=(W Shr 7)And 1;As:=(W Shr 4)And 3;ByteOp:=(W And $40)<>0;
 Resolve(C,As,SReg,ByteOp,True,LS);
 S:=ReadLoc(C,LS,ByteOp);
 Resolve(C,Ad,DReg,ByteOp,False,LD);
 Cy:=SrcCycles(LS,SReg);
 If Ad=1Then Inc(Cy,3)
  Else If(DReg=0)And Not((LS.Kind=1)And(LS.Mode=1))Then Inc(Cy);
 Inc(C.Cycles,Cy);
 D:=0;Res:=0;Store:=True;
 If Opc<>4Then D:=ReadLoc(C,LD,ByteOp);
 Case Opc Of
  4:Res:=S;
  5:Res:=AluAdd(C,S,D,0,ByteOp);
  6:Res:=AluAdd(C,S,D,C.R[2]And FlagC,ByteOp);
  7:Res:=AluAdd(C,(Not S)And MaskOf(ByteOp),D,C.R[2]And FlagC,ByteOp);
  8:Res:=AluAdd(C,(Not S)And MaskOf(ByteOp),D,1,ByteOp);
  9:Begin
   Res:=AluAdd(C,(Not S)And MaskOf(ByteOp),D,1,ByteOp);Store:=False
  End;
  10:Res:=AluDadd(C,S,D,ByteOp);
  11:Begin
   Res:=S And D;LogicFlags(C,Res,ByteOp);Store:=False
  End;
  12:Res:=D And Not S;
  13:Res:=D Or S;
  14:Begin
   Res:=S Xor D;LogicFlags(C,Res,ByteOp);
   SetFlag(C,FlagV,((S And D And SignOf(ByteOp)))<>0)
  End;
  15:Begin
   Res:=S And D;LogicFlags(C,Res,ByteOp)
  End
 End;
 If Store Then WriteLoc(C,LD,ByteOp,Res)
End;

Procedure ExecFormat2(Var C:TCPU;W:Word);
Var
 Opc,Reg,As:Integer;
 ByteOp:Boolean;
 L:TLoc;
 S,Res,Cin:LongInt;
 Cy:Integer;
Begin
 Opc:=(W Shr 7)And 7;Reg:=W And 15;As:=(W Shr 4)And 3;
 ByteOp:=(W And $40)<>0;
 If(Opc=1)Or(Opc=3)Or(Opc=5)Then ByteOp:=False;
 If Opc=7Then Begin
  C.Fault:=W;StopCPU(C,StopIllegal);Exit
 End;
 If Opc=6Then Begin
  C.R[2]:=Pop(C);C.R[0]:=Pop(C)And $FFFE;Inc(C.Cycles,5);Exit
 End;
 Resolve(C,As,Reg,ByteOp,True,L);
 S:=ReadLoc(C,L,ByteOp);
 Case Opc Of
  0,1,2,3:If L.Kind=0Then Cy:=1 Else If L.Mode=1Then Cy:=4 Else Cy:=3;
  4:If(L.Kind<>1)And(L.Mode<>3)Then Cy:=3 Else If L.Mode=1Then Cy:=5
    Else Cy:=4;
  Else If(L.Kind=0)Or(L.Mode=2)Then Cy:=4 Else Cy:=5
 End;
 Inc(C.Cycles,Cy);
 Case Opc Of
  0:Begin
   If(C.R[2]And FlagC)<>0Then Cin:=SignOf(ByteOp)Else Cin:=0;
   SetFlag(C,FlagC,(S And 1)<>0);
   Res:=(S Shr 1)Or Cin;SetNZ(C,Res,ByteOp);SetFlag(C,FlagV,False);
   WriteLoc(C,L,ByteOp,Res)
  End;
  1:WriteLoc(C,L,False,((S And $FF)Shl 8)Or(S Shr 8));
  2:Begin
   SetFlag(C,FlagC,(S And 1)<>0);
   Res:=(S Shr 1)Or(S And SignOf(ByteOp));
   SetNZ(C,Res,ByteOp);SetFlag(C,FlagV,False);
   WriteLoc(C,L,ByteOp,Res)
  End;
  3:Begin
   If(S And $80)<>0Then Res:=(S And $FF)Or $FF00 Else Res:=S And $FF;
   LogicFlags(C,Res,False);WriteLoc(C,L,False,Res)
  End;
  4:Begin
   C.R[1]:=(C.R[1]-2)And $FFFE;
   If ByteOp Then WriteByte(C,C.R[1],Byte(S))
             Else WriteWord(C,C.R[1],Word(S))
  End;
  5:Begin
   Push(C,C.R[0]);C.R[0]:=Word(S)And $FFFE
  End
 End
End;

Procedure ExecJump(Var C:TCPU;W:Word);
Var
 Cond,Off:Integer;
 Take:Boolean;
 Zf,Nf,Cf,Vf:Boolean;
Begin
 Cond:=(W Shr 10)And 7;Off:=W And $3FF;
 If Off>=512Then Off:=Off-1024;
 Zf:=(C.R[2]And FlagZ)<>0;Nf:=(C.R[2]And FlagN)<>0;
 Cf:=(C.R[2]And FlagC)<>0;Vf:=(C.R[2]And FlagV)<>0;
 Case Cond Of
  0:Take:=Not Zf;
  1:Take:=Zf;
  2:Take:=Not Cf;
  3:Take:=Cf;
  4:Take:=Nf;
  5:Take:=Nf=Vf;
  6:Take:=Nf<>Vf;
  Else Take:=True
 End;
 Inc(C.Cycles,2);
 If Take Then Begin
  C.R[0]:=Word(C.R[0]+2*Off);
  If(Cond=7)And(Off=-1)And Not CanWake(C)Then StopCPU(C,StopLoop)
 End
End;

Procedure TraceLine(Var C:TCPU;PC,W:Word);
Var
 J:Integer;
Begin
 Write(Hex4(PC),' ',Hex4(W),' SP=',Hex4(C.R[1]),' SR=',Hex4(C.R[2]),' ');
 If(C.R[2]And FlagV)<>0Then Write('V')Else Write('-');
 If(C.R[2]And FlagN)<>0Then Write('N')Else Write('-');
 If(C.R[2]And FlagZ)<>0Then Write('Z')Else Write('-');
 If(C.R[2]And FlagC)<>0Then Write('C')Else Write('-');
 For J:=4To 15Do Write(' R',J,'=',Hex4(C.R[J]));
 WriteLn
End;

{ Execute une instruction }
Procedure Step(Var C:TCPU);
Var
 W,Start:Word;
 Before:LongInt;
Begin
 Start:=C.R[0];Before:=C.Cycles;W:=Fetch(C);
 Case W Shr 12 Of
  0:Begin
   C.Fault:=W;StopCPU(C,StopIllegal)
  End;
  1:If(W Shr 10)<>4Then Begin
   C.Fault:=W;StopCPU(C,StopIllegal)
  End
   Else
  ExecFormat2(C,W);
  2,3:ExecJump(C,W);
  Else ExecFormat1(C,W)
 End;
 If C.Stopped And(C.Reason=StopIllegal)Then Begin
  C.FaultPC:=Start;C.R[0]:=Start
 End
  Else
 Begin
  Inc(C.Count);TimerTick(C,C.Cycles-Before);
  If C.Trace Then TraceLine(C,Start,W)
 End
End;

Procedure Run(Var C:TCPU;Limit:LongInt);
Var
 Vec:Word;
Begin
 While Not C.Stopped Do Begin
  If C.Count>=Limit Then StopCPU(C,StopLimit)
  Else Begin
   Vec:=PendingVector(C);
   If((C.R[2]And FlagGIE)<>0)And(Vec<>0)Then ServiceInterrupt(C,Vec)
   Else If(C.R[2]And FlagCPUOFF)<>0Then Begin
    If CanWake(C)Then Begin
     Inc(C.Cycles);TimerTick(C,1)
    End
     Else
    StopCPU(C,StopSleep)
   End
    Else
   Step(C)
  End
 End
End;

{ ------------------------------------------------------------------ }
{  Chargement, affichage et ligne de commande                        }
{ ------------------------------------------------------------------ }

Procedure Usage;Begin
 WriteLn(T('MSP430 - Cet emulateur permet d''executer un programme binaire '+
  'MSP430.',
  'MSP430 - This emulator runs an MSP430 binary program.',
  'MSP430 - Dieser Emulator fuehrt ein MSP430-Binaerprogramm aus.',
  'MSP430 - Este emulador ejecuta un programa binario MSP430.',
  'MSP430 - Questo emulatore esegue un programma binario MSP430.'));
 WriteLn;
 WriteLn(T('Syntaxe: MSP430 fichier[.BIN] [options]',
  'Syntax: MSP430 file[.BIN] [options]',
  'Syntax: MSP430 datei[.BIN] [optionen]',
  'Sintaxis: MSP430 fichero[.BIN] [opciones]',
  'Sintassi: MSP430 file[.BIN] [opzioni]'));
 WriteLn;
 WriteLn(T(' -A=adr  adresse de chargement en hexa (defaut C000)',
  ' -A=adr  load address in hex (default C000)',
  ' -A=adr  Ladeadresse in Hex (Standard C000)',
  ' -A=dir  direccion de carga en hexa (por defecto C000)',
  ' -A=ind  indirizzo di caricamento in esa (default C000)'));
 WriteLn(T(' -S=adr  adresse de depart (defaut: vecteur RESET en FFFE)',
  ' -S=adr  start address (default: RESET vector at FFFE)',
  ' -S=adr  Startadresse (Standard: RESET-Vektor bei FFFE)',
  ' -S=dir  direccion de inicio (por defecto: vector RESET en FFFE)',
  ' -S=ind  indirizzo di avvio (default: vettore RESET in FFFE)'));
 WriteLn(T(' -N=nb   nombre maximal d''instructions (defaut 1000000)',
  ' -N=n    maximum number of instructions (default 1000000)',
  ' -N=n    maximale Anzahl Befehle (Standard 1000000)',
  ' -N=n    numero maximo de instrucciones (por defecto 1000000)',
  ' -N=n    numero massimo di istruzioni (default 1000000)'));
 WriteLn(T(' -T      trace chaque instruction',
  ' -T      trace every instruction',
  ' -T      jeden Befehl protokollieren',
  ' -T      traza cada instruccion',
  ' -T      traccia ogni istruzione'));
 WriteLn(T(' -M=d-f  affiche la memoire de d a f (hexa) a la fin',
  ' -M=f-t  dump memory from f to t (hex) at the end',
  ' -M=v-b  Speicher von v bis b (Hex) am Ende ausgeben',
  ' -M=d-h  muestra la memoria de d a h (hexa) al final',
  ' -M=d-a  mostra la memoria da d ad a (esa) alla fine'));
 WriteLn(T(' -I=txt  texte fourni au port serie (UCA0RXBUF)',
  ' -I=txt  text fed to the serial port (UCA0RXBUF)',
  ' -I=txt  Text fuer die serielle Schnittstelle (UCA0RXBUF)',
  ' -I=txt  texto enviado al puerto serie (UCA0RXBUF)',
  ' -I=txt  testo fornito alla porta seriale (UCA0RXBUF)'));
 WriteLn(T(' -P=hh   valeur lue sur P1IN (hexa)',
  ' -P=hh   value read on P1IN (hex)',
  ' -P=hh   an P1IN gelesener Wert (Hex)',
  ' -P=hh   valor leido en P1IN (hexa)',
  ' -P=hh   valore letto su P1IN (esa)'));
 WriteLn(T(' -Q      pas de resume des registres a la fin',
  ' -Q      no register summary at the end',
  ' -Q      keine Registerzusammenfassung am Ende',
  ' -Q      sin resumen de registros al final',
  ' -Q      nessun riepilogo dei registri alla fine'));
 WriteLn;
 WriteLn(T('Peripheriques: P1/P2, UART (UCA0TXBUF=0067), Timer_A, WDT',
  'Peripherals: P1/P2, UART (UCA0TXBUF=0067), Timer_A, WDT',
  'Peripherie: P1/P2, UART (UCA0TXBUF=0067), Timer_A, WDT',
  'Perifericos: P1/P2, UART (UCA0TXBUF=0067), Timer_A, WDT',
  'Periferiche: P1/P2, UART (UCA0TXBUF=0067), Timer_A, WDT'))
End;

Function LoadProgram(Var C:TCPU;Const Name:String;Addr:LongInt):Boolean;
Var
 F:File;
 Buf:Array[0..511]Of Byte;
 Got,J:Word;
 Total:LongInt;
Begin
 LoadProgram:=False;
 Assign(F,Name);
 {$I-}
 Reset(F,1);
 {$I+}
 If IOResult<>0Then Begin
  WriteLn(T('Impossible d''ouvrir ','Cannot open ','Kann nicht oeffnen: ',
   'No se puede abrir ','Impossibile aprire '),Name);
  Exit
 End;
 Total:=Addr;
 Repeat
  BlockRead(F,Buf,SizeOf(Buf),Got);
  J:=0;
  While J<Got Do Begin
   If Total>$FFFFThen Begin
    WriteLn(T('Programme trop grand pour la memoire de 64 Ko',
     'Program too large for the 64 KB memory',
     'Programm zu gross fuer den 64-KB-Speicher',
     'Programa demasiado grande para la memoria de 64 KB',
     'Programma troppo grande per la memoria da 64 KB'));
    Close(F);Exit
   End;
   RawPut(C,Word(Total),Buf[J]);Inc(Total);Inc(J)
  End
 Until Got=0;
 Close(F);LoadProgram:=True
End;

Procedure ShowFlags(V:Word);Begin
 If(V And FlagV)<>0Then Write('V')Else Write('-');
 If(V And FlagN)<>0Then Write('N')Else Write('-');
 If(V And FlagZ)<>0Then Write('Z')Else Write('-');
 If(V And FlagC)<>0Then Write('C')Else Write('-');
 If(V And FlagGIE)<>0Then Write('I')Else Write('-');
 If(V And FlagCPUOFF)<>0Then Write('O')Else Write('-')
End;

Procedure ShowSummary(Var C:TCPU;Short:Boolean);
Var
 J:Integer;
Begin
 WriteLn;
 Case C.Reason Of
  StopLimit:WriteLn(T('Arret: limite d''instructions atteinte',
   'Stopped: instruction limit reached',
   'Angehalten: Befehlsgrenze erreicht',
   'Detenido: limite de instrucciones alcanzado',
   'Fermato: limite di istruzioni raggiunto'));
  StopIllegal:WriteLn(T('Arret: instruction illegale ',
   'Stopped: illegal instruction ',
   'Angehalten: unzulaessiger Befehl ',
   'Detenido: instruccion ilegal ',
   'Fermato: istruzione illegale '),Hex4(C.Fault),' @',Hex4(C.FaultPC));
  StopLoop:WriteLn(T('Arret: boucle infinie detectee (JMP $)',
   'Stopped: endless loop detected (JMP $)',
   'Angehalten: Endlosschleife erkannt (JMP $)',
   'Detenido: bucle infinito detectado (JMP $)',
   'Fermato: ciclo infinito rilevato (JMP $)'));
  StopSleep:WriteLn(T('Arret: mode basse consommation sans reveil possible',
   'Stopped: low power mode with no possible wake-up',
   'Angehalten: Energiesparmodus ohne Aufwecken',
   'Detenido: modo de bajo consumo sin posible despertar',
   'Fermato: modalita a basso consumo senza risveglio'))
 End;
 If Short Then Exit;
 WriteLn(T('Instructions: ','Instructions: ','Befehle: ',
  'Instrucciones: ','Istruzioni: '),C.Count,'  ',
  T('Cycles: ','Cycles: ','Zyklen: ','Ciclos: ','Cicli: '),C.Cycles);
 Write('PC=',Hex4(C.R[0]),' SP=',Hex4(C.R[1]),' SR=',Hex4(C.R[2]),' [');
 ShowFlags(C.R[2]);WriteLn(']');
 For J:=4To 15Do Begin
  Write('R',J,'=':Ord(J<10)+1,Hex4(C.R[J]));
  If(J And 3)=3Then WriteLn Else Write('  ')
 End;
 WriteLn('P1OUT=',Hex2(RawGet(C,AddrP1OUT)),' P1DIR=',
  Hex2(RawGet(C,AddrP1DIR)),' P2OUT=',Hex2(RawGet(C,AddrP2OUT)),
  ' P2DIR=',Hex2(RawGet(C,AddrP2DIR)))
End;

Procedure DumpMemory(Var C:TCPU;First,Last:LongInt);
Var
 A,J:LongInt;
 B:Byte;
Begin
 A:=First And Not 15;
 While A<=Last Do Begin
  Write(Hex4(Word(A)),': ');
  For J:=0To 15Do Write(Hex2(RawGet(C,Word(A+J))),' ');
  Write(' ');
  For J:=0To 15Do Begin
   B:=RawGet(C,Word(A+J));
   If(B>=32)And(B<127)Then Write(Chr(B))Else Write('.')
  End;
  WriteLn;A:=A+16
 End
End;

Procedure BadOption(Const S:String);Begin
 WriteLn(T('Option invalide: ','Invalid option: ','Ungueltige Option: ',
  'Opcion invalida: ','Opzione non valida: '),S);
 Halt(1)
End;

Procedure ParseCommandLine;
Var
 J,P:Integer;
 A,U:String;
 V,V2:LongInt;
 Code:Integer;
Begin
 FileName:='';LoadAddr:=$C000;StartAddr:=-1;MaxInstr:=1000000;
 Quiet:=False;DoDump:=False;CPU.Trace:=False;CPU.Input:='';CPU.P1In:=0;
 For J:=1To ParamCount Do Begin
  A:=ParamStr(J);U:=Upper(A);
  If(A='/?')Or(U='-H')Or(U='--HELP')Then Begin
   Usage;Halt
  End
  Else If U='-T'Then CPU.Trace:=True
  Else If U='-Q'Then Quiet:=True
  Else If Copy(U,1,3)='-A='Then Begin
   LoadAddr:=HexValue(Copy(A,4,255));
   If(LoadAddr<0)Or(LoadAddr>$FFFF)Then BadOption(A)
  End
  Else If Copy(U,1,3)='-S='Then Begin
   StartAddr:=HexValue(Copy(A,4,255));
   If(StartAddr<0)Or(StartAddr>$FFFF)Then BadOption(A)
  End
  Else If Copy(U,1,3)='-N='Then Begin
   Val(Copy(A,4,255),V,Code);
   If(Code<>0)Or(V<1)Then BadOption(A);
   MaxInstr:=V
  End
  Else If Copy(U,1,3)='-P='Then Begin
   V:=HexValue(Copy(A,4,255));
   If(V<0)Or(V>255)Then BadOption(A);
   CPU.P1In:=Byte(V)
  End
  Else If Copy(U,1,3)='-I='Then CPU.Input:=Copy(A,4,255)
  Else If Copy(U,1,3)='-M='Then Begin
   P:=Pos('-',Copy(A,4,255));
   If P=0Then BadOption(A);
   V:=HexValue(Copy(A,4,P-1));V2:=HexValue(Copy(A,4+P,255));
   If(V<0)Or(V2<V)Or(V2>$FFFF)Then BadOption(A);
   DumpFrom:=V;DumpTo:=V2;DoDump:=True
  End
  Else If Copy(A,1,1)='-'Then BadOption(A)
  Else If FileName=''Then FileName:=A
  Else BadOption(A)
 End;
 If FileName=''Then Begin
  Usage;Halt(1)
 End;
 If Pos('.',FileName)=0Then FileName:=FileName+'.BIN'
End;

BEGIN
 InitLanguage;
 ParseCommandLine;
 If Not AllocMemory(CPU)Then Begin
  WriteLn(T('Memoire insuffisante','Not enough memory',
   'Nicht genug Speicher','Memoria insuficiente','Memoria insufficiente'));
  Halt(1)
 End;
 CPU.Cycles:=0;CPU.Count:=0;CPU.Stopped:=False;CPU.Reason:=StopNone;
 CPU.TimerAcc:=0;CPU.TimerDown:=False;CPU.InputPos:=1;CPU.OutCount:=0;
 CPU.LastOut:=10;CPU.Fault:=0;CPU.FaultPC:=0;
 If Not LoadProgram(CPU,FileName,LoadAddr)Then Halt(1);
 CPUReset(CPU);
 If StartAddr>=0Then CPU.R[0]:=Word(StartAddr)And $FFFE
  Else If(CPU.R[0]=0)Or(CPU.R[0]=$FFFE)Then CPU.R[0]:=Word(LoadAddr);
 Run(CPU,MaxInstr);
 If(CPU.OutCount>0)And(CPU.LastOut<>10)Then WriteLn;
 ShowSummary(CPU,Quiet);
 If DoDump Then Begin
  WriteLn;DumpMemory(CPU,DumpFrom,DumpTo)
 End;
 Dispose(CPU.Bank[0]);Dispose(CPU.Bank[1]);
 If CPU.Reason=StopIllegal Then Halt(2)
END.
