{ @author: Sylvain Maltais (support@gladir.com)
 @created: 2026
 @website(https://www.gladir.com/dev-cools)
 @abstract(Target: Turbo Pascal 7 / Free Pascal 3.2)
 @abstract: Emulateur MSP430 / MSP430X avec peripheriques, desassembleur
  et debogueur, compatible Turbo Pascal / Free Pascal.
 @license: MIT

 Modele de composant emule (superset de la famille MSP430G2xx/F2xx):
  - CPU 16 bits (MSP430) ou 20 bits (MSP430X, profil X)
  - Horloges BCS+ (DCO, LFXT1 32768 Hz, VLO), modes LPM0 a LPM4
  - Timer_A3 ($160) et Timer_B3 ($180), WDT+, ports P1/P2/P3
  - USCI_A0 (UART/SPI), USCI_B0 (SPI/I2C), ADC10, Comparator_A+
  - Controleur flash, multiplieur materiel, DMA (3 canaux)
  - RTC_A ($4A0, profil X), LCD (registres + memoire d'affichage)
  Les frequences du DCO sont un modele nominal (non mesure). }

Program MSP430;

{$A-}
{$R-}
{$Q-}
{$N+,E+}

Uses Dos;

Const
 MaxBreak=16;
 MaxWatch=8;
 MaxSym=1024;
 MaxEvent=64;
 MaxBanks=32;

 { Bits du registre d'etat SR (R2) }
 FlagC=$0001;
 FlagZ=$0002;
 FlagN=$0004;
 FlagGIE=$0008;
 FlagCPUOFF=$0010;
 FlagOSCOFF=$0020;
 FlagSCG0=$0040;
 FlagSCG1=$0080;
 FlagV=$0100;

 { Raisons d'arret }
 StopNone=0;
 StopLimit=1;
 StopIllegal=2;
 StopLoop=3;
 StopSleep=4;
 StopBreak=5;
 StopWatch=6;
 StopFetch=7;
 StopUnmapped=8;
 StopReset=9;
 StopQuit=10;
 StopTime=11;

 { Types de memoire }
 MemNone=0;
 MemRam=1;
 MemFlash=2;
 MemInfo=3;
 MemRom=4;
 MemPeriph=5;

 { Registres des peripheriques }
 aIE1=$00;      aIE2=$01;      aIFG1=$02;     aIFG2=$03;
 aP3REN=$10;    aP3IN=$18;     aP3OUT=$19;    aP3DIR=$1A;
 aP3SEL=$1B;
 aP1IN=$20;     aP1OUT=$21;    aP1DIR=$22;    aP1IFG=$23;
 aP1IES=$24;    aP1IE=$25;     aP1SEL=$26;    aP1REN=$27;
 aP2IN=$28;     aP2OUT=$29;    aP2DIR=$2A;    aP2IFG=$2B;
 aP2IES=$2C;    aP2IE=$2D;     aP2SEL=$2E;    aP2REN=$2F;
 aP1SEL2=$41;   aP2SEL2=$42;   aP3SEL2=$43;
 aADCDTC0=$48;  aADCDTC1=$49;  aADCAE0=$4A;   aADCAE1=$4B;
 aBCSCTL3=$53;  aDCOCTL=$56;   aBCSCTL1=$57;  aBCSCTL2=$58;
 aCACTL1=$59;   aCACTL2=$5A;   aCAPD=$5B;
 aUA=$60;       aUB=$68;
 aLCDCTL=$90;   aLCDMEM=$91;
 aUCB0I2COA=$118; aUCB0I2CSA=$11A;
 aTBIV=$11E;    aWDTCTL=$120;  aDMACTL0=$122; aDMACTL1=$124;
 aDMAIV=$126;   aFCTL1=$128;   aFCTL2=$12A;   aFCTL3=$12C;
 aTAIV=$12E;    aMPY=$130;     aMPYS=$132;    aMAC=$134;
 aMACS=$136;    aOP2=$138;     aRESLO=$13A;   aRESHI=$13C;
 aSUMEXT=$13E;  aTA=$160;      aTB=$180;
 aADCCTL0=$1B0; aADCCTL1=$1B2; aADCMEM=$1B4;  aADCSA=$1BC;
 aDMA0=$1D0;    aRTC=$4A0;

 { Vecteurs d'interruption }
 vRTC=$FFDC;    vTB1=$FFE0;    vTB0=$FFE2;    vP1=$FFE4;
 vP2=$FFE6;     vDMA=$FFE8;    vADC=$FFEA;    vTX=$FFEC;
 vRX=$FFEE;     vTA1=$FFF0;    vTA0=$FFF2;    vWDT=$FFF4;
 vCOMP=$FFF6;   vNMI=$FFFC;    vReset=$FFFE;

Type
 TBank=Array[0..32767]Of Byte;
 PBank=^TBank;
 TDevice=Record
  Name:String[10];
  RamLo,RamHi,FlLo,FlHi,Fl2Lo,Fl2Hi:LongInt;
  InLo,InHi,RomLo,RomHi:LongInt;
  X,Rtc:Boolean
 End;
 TSym=Record
  Name:String[23];
  Addr:LongInt
 End;
 TEvent=Record
  Time:Double;
  Kind:Char;
  Idx:Integer;
  Val:LongInt
 End;
 TWatch=Record
  Lo,Hi:LongInt;
  Mode:Byte
 End;
 TTimer=Record
  Base:Word;
  IsB:Boolean;
  Acc:Double;
  Down:Boolean;
  Latch:Array[0..2]Of Word;
  Pend:Array[0..2]Of Boolean;
  OutQ:Array[0..2]Of Boolean;
  CciIn:Array[0..2]Of Byte;
  CciPrev:Array[0..2]Of Byte
 End;
 TUsci=Record
  Base:Word;
  Busy,Full,RxBusy:Boolean;
  Shift,Buf,RxByte:Byte;
  Remain,RxRem:Double;
  St:Byte;           { etat I2C }
  Ptr:Byte;
  Nack:Boolean
 End;
 TDma=Record
  Sa,Da,Sz:LongInt;
  Running:Boolean
 End;
 TCPU=Record
  R:Array[0..15]Of LongInt;
  Bank:Array[0..MaxBanks-1]Of PBank;
  Dev:TDevice;
  Cycles:LongInt;
  Count:LongInt;
  Resets:Integer;
  Stopped:Boolean;
  Reason:Integer;
  Fault:Word;
  FaultPC:LongInt;
  Unmapped:LongInt;
  Strict:Boolean;
  Trace:Boolean;
  { temps et horloges }
  Now,MaxTime:Double;
  FMclk,FSmclk,FAclk:LongInt;
  { peripheriques }
  TA,TB:TTimer;
  WdtAcc:Double;
  WdtCnt:LongInt;
  PDrv,PVal,PPrev:Array[1..3]Of Byte;
  Mpy1:LongInt;
  MpyByte,MpySigned,MpyMac:Boolean;
  U:Array[0..1]Of TUsci;
  MisoByte:Byte;
  I2cDev:Byte;
  I2cMem:Array[0..255]Of Byte;
  Input:String;
  InputPos:Integer;
  OutCount:LongInt;
  LastOut:Byte;
  Capture:Boolean;
  OutBuf:String;
  AdcBusy:Boolean;
  AdcRem:Double;
  AdcCh,AdcIdx:Integer;
  Analog:Array[0..15]Of LongInt;
  CaOut:Boolean;
  Dma:Array[0..2]Of TDma;
  RtcAcc:Double;
  { evenements programmes }
  Ev:Array[1..MaxEvent]Of TEvent;
  NEv,EvPos:Integer;
  { debogage }
  Bp:Array[1..MaxBreak]Of LongInt;
  NBp:Integer;
  Wp:Array[1..MaxWatch]Of TWatch;
  NWp:Integer;
  WatchHit:Boolean;
  WatchAddr:LongInt;
  SkipBreak:Boolean
 End;

Var
 CPU:TCPU;
 Language:Byte;   { 0=FR, 1=EN, 2=GR, 3=SP, 4=IT }
 Sym:Array[1..MaxSym]Of TSym;
 NSym:Integer;
 MaxInstr,MaxResets:LongInt;

Procedure AdvanceTime(Var C:TCPU;Dt:Double);Forward;
Function PeriphRead(Var C:TCPU;A:LongInt):Byte;Forward;
Procedure PeriphWrite(Var C:TCPU;A:LongInt;V:Byte);Forward;
Function PeriphWriteW(Var C:TCPU;A:LongInt;V:Word):Boolean;Forward;
Procedure FlashWrite(Var C:TCPU;A:LongInt;V:Byte;Charge:Boolean);Forward;
Procedure DoPUC(Var C:TCPU;Hard:Boolean);Forward;

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

Function LTrim(Const S:String):String;
Var
 J:Integer;
Begin
 J:=1;
 While(J<=Length(S))And(S[J]In[' ',#9])Do Inc(J);
 LTrim:=Copy(S,J,255)
End;

Function RTrim(Const S:String):String;
Var
 J:Integer;
Begin
 J:=Length(S);
 While(J>0)And(S[J]In[' ',#9,#13,#10])Do Dec(J);
 RTrim:=Copy(S,1,J)
End;

Function Trim(Const S:String):String;Begin
 Trim:=LTrim(RTrim(S))
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

Function Hex5(V:LongInt):String;
Const
 H:String[16]='0123456789ABCDEF';
Begin
 Hex5:=H[((V Shr 16)And 15)+1]+Hex4(Word(V And $FFFF))
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

Function DecValue(Const S:String):LongInt;
Var
 V:LongInt;
 Code:Integer;
Begin
 Val(S,V,Code);
 If Code<>0Then DecValue:=-1 Else DecValue:=V
End;

Procedure InitLanguage;
Var
 L:String;
Begin
 Language:=0;
 L:=GetEnv('LANGUAGE');
 If L<>''Then Begin
  If L[1]='"'Then L:=Copy(L,2,255);
  L:=Upper(Copy(L,1,2));
  If L='EN'Then Language:=1 Else
  If L='GR'Then Language:=2 Else
  If L='SP'Then Language:=3 Else
  If L='IT'Then Language:=4
 End
End;

{ Table des symboles }
Function FindSymAddr(Const Name:String;Var A:LongInt):Boolean;
Var
 J:Integer;
 U:String;
Begin
 U:=Upper(Name);
 For J:=1To NSym Do If Upper(Sym[J].Name)=U Then Begin
  A:=Sym[J].Addr;FindSymAddr:=True;Exit
 End;
 FindSymAddr:=False
End;

Function SymName(A:LongInt):String;
Var
 J:Integer;
Begin
 SymName:='';
 For J:=1To NSym Do If Sym[J].Addr=A Then Begin
  SymName:=Sym[J].Name;Exit
 End
End;

Procedure AddSymbol(Const Name:String;A:LongInt);Begin
 If NSym<MaxSym Then Begin
  Inc(NSym);Sym[NSym].Name:=Name;Sym[NSym].Addr:=A
 End
End;

{ Valeur numerique: hexa (defaut), $xx, 0xNN, symbole }
Function ParseAddr(Const S:String;Var V:LongInt):Boolean;
Var
 U:String;
 R:LongInt;
Begin
 ParseAddr:=True;U:=Trim(S);
 If U=''Then Begin
  ParseAddr:=False;Exit
 End;
 If FindSymAddr(U,R)Then Begin
  V:=R;Exit
 End;
 If U[1]='$'Then Delete(U,1,1)
 Else If Upper(Copy(U,1,2))='0X'Then Delete(U,1,2);
 While(Length(U)>5)And(U[1]='0')Do Delete(U,1,1);
 R:=HexValue(U);
 If(R<0)Or(R>$FFFFF)Then ParseAddr:=False Else V:=R
End;

{ ------------------------------------------------------------------ }
{  Profils de composants et bus memoire                              }
{ ------------------------------------------------------------------ }

Procedure SetDevice(Var D:TDevice;N:Integer);Begin
 FillChar(D,SizeOf(D),0);
 D.Fl2Lo:=1;D.Fl2Hi:=0;
 D.InLo:=$1000;D.InHi:=$10FF;D.RomLo:=$0C00;D.RomHi:=$0FFF;
 Case N Of
  2:Begin
   D.Name:='G2231';D.RamLo:=$200;D.RamHi:=$27F;D.FlLo:=$F800;D.FlHi:=$FFFF
  End;
  3:Begin
   D.Name:='F149';D.RamLo:=$200;D.RamHi:=$9FF;D.FlLo:=$1100;D.FlHi:=$FFFF
  End;
  4:Begin
   D.Name:='X';D.RamLo:=$2400;D.RamHi:=$43FF;D.FlLo:=$4400;D.FlHi:=$FFFF;
   D.Fl2Lo:=$10000;D.Fl2Hi:=$23FFF;D.InLo:=$1800;D.InHi:=$19FF;
   D.RomLo:=$1000;D.RomHi:=$17FF;D.X:=True;D.Rtc:=True
  End;
  Else Begin
   D.Name:='G2553';D.RamLo:=$200;D.RamHi:=$3FF;D.FlLo:=$C000;D.FlHi:=$FFFF
  End
 End
End;

Function DeviceNumber(Const S:String):Integer;
Var
 U:String;
Begin
 U:=Upper(S);DeviceNumber:=0;
 If U='G2553'Then DeviceNumber:=1 Else If U='G2231'Then DeviceNumber:=2
 Else If U='F149'Then DeviceNumber:=3 Else If(U='X')Or(U='MSP430X')Then
 DeviceNumber:=4
End;

Function MemKind(Var C:TCPU;A:LongInt):Byte;Begin
 MemKind:=MemNone;
 If(A<0)Or(A>$FFFFF)Then Exit;
 With C.Dev Do Begin
  If A<$200Then MemKind:=MemPeriph
  Else If Rtc And(A>=aRTC)And(A<=aRTC+$1F)Then MemKind:=MemPeriph
  Else If(A>=RamLo)And(A<=RamHi)Then MemKind:=MemRam
  Else If(A>=FlLo)And(A<=FlHi)Then MemKind:=MemFlash
  Else If(A>=Fl2Lo)And(A<=Fl2Hi)Then MemKind:=MemFlash
  Else If(A>=InLo)And(A<=InHi)Then MemKind:=MemInfo
  Else If(A>=RomLo)And(A<=RomHi)Then MemKind:=MemRom
 End
End;

Function RawGet(Var C:TCPU;A:LongInt):Byte;
Var
 B:PBank;
Begin
 A:=A And $FFFFF;B:=C.Bank[A Shr 15];
 If B=Nil Then RawGet:=$FF Else RawGet:=B^[A And $7FFF]
End;

Procedure RawPut(Var C:TCPU;A:LongInt;V:Byte);
Var
 N:Integer;
Begin
 A:=A And $FFFFF;N:=A Shr 15;
 If C.Bank[N]=Nil Then Begin
  New(C.Bank[N]);FillChar(C.Bank[N]^,SizeOf(TBank),0)
 End;
 C.Bank[N]^[A And $7FFF]:=V
End;

Function RawGetW(Var C:TCPU;A:LongInt):Word;Begin
 RawGetW:=RawGet(C,A)Or(Word(RawGet(C,A+1))Shl 8)
End;

Procedure RawPutW(Var C:TCPU;A:LongInt;V:Word);Begin
 RawPut(C,A,V And $FF);RawPut(C,A+1,V Shr 8)
End;

Procedure SetBits(Var C:TCPU;A:LongInt;M:Byte);Begin
 RawPut(C,A,RawGet(C,A)Or M)
End;

Procedure ClrBits(Var C:TCPU;A:LongInt;M:Byte);Begin
 RawPut(C,A,RawGet(C,A)And Not M)
End;

Procedure FillRange(Var C:TCPU;Lo,Hi:LongInt;V:Byte);
Var
 A:LongInt;
Begin
 A:=Lo;
 While A<=Hi Do Begin
  RawPut(C,A,V);Inc(A)
 End
End;

Procedure FreeMemory(Var C:TCPU);
Var
 J:Integer;
Begin
 For J:=0To MaxBanks-1Do If C.Bank[J]<>Nil Then Begin
  Dispose(C.Bank[J]);C.Bank[J]:=Nil
 End
End;

Procedure StopCPU(Var C:TCPU;Why:Integer);Begin
 If Not C.Stopped Then Begin
  C.Stopped:=True;C.Reason:=Why
 End
End;

Procedure WatchCheck(Var C:TCPU;A:LongInt;M:Byte);
Var
 J:Integer;
Begin
 For J:=1To C.NWp Do With C.Wp[J]Do
  If(A>=Lo)And(A<=Hi)And((Mode And M)<>0)Then Begin
   C.WatchHit:=True;C.WatchAddr:=A
  End
End;

{ Initialise la memoire selon le profil (flash effacee, calibrage DCO) }
Procedure InitMemory(Var C:TCPU);Begin
 With C.Dev Do Begin
  FillRange(C,FlLo,FlHi,$FF);
  If Fl2Hi>Fl2Lo Then FillRange(C,Fl2Lo,Fl2Hi,$FF);
  FillRange(C,InLo,InHi,$FF);
  FillRange(C,RomLo,RomHi,$FF);
  FillRange(C,RamLo,RamHi,0)
 End;
 { Constantes de calibrage du DCO (valeurs nominales du modele) }
 If C.Dev.InHi>=$10FF Then Begin
  RawPut(C,$10F8,$A0);RawPut(C,$10F9,$8F);   { 16 MHz }
  RawPut(C,$10FA,$80);RawPut(C,$10FB,$8E);   { 12 MHz }
  RawPut(C,$10FC,$C0);RawPut(C,$10FD,$8D);   {  8 MHz }
  RawPut(C,$10FE,$C0);RawPut(C,$10FF,$86)    {  1 MHz }
 End
End;

{ Lecture d'un octet par le CPU (avec peripheriques et surveillance) }
Function ReadByte(Var C:TCPU;A:LongInt):Byte;Begin
 A:=A And $FFFFF;
 If C.NWp>0Then WatchCheck(C,A,1);
 Case MemKind(C,A)Of
  MemPeriph:ReadByte:=PeriphRead(C,A);
  MemNone:Begin
   Inc(C.Unmapped);ReadByte:=$FF;
   If C.Strict Then Begin
    C.Fault:=Word(A);StopCPU(C,StopUnmapped)
   End
  End;
  Else ReadByte:=RawGet(C,A)
 End
End;

Function ReadWord(Var C:TCPU;A:LongInt):Word;
Var
 L,H:Byte;
Begin
 A:=A And $FFFFE;L:=ReadByte(C,A);H:=ReadByte(C,A+1);
 ReadWord:=L Or(Word(H)Shl 8)
End;

Procedure WriteByte(Var C:TCPU;A:LongInt;V:Byte);Begin
 A:=A And $FFFFF;
 If C.NWp>0Then WatchCheck(C,A,2);
 Case MemKind(C,A)Of
  MemRam:RawPut(C,A,V);
  MemPeriph:PeriphWrite(C,A,V);
  MemFlash,MemInfo:FlashWrite(C,A,V,True);
  MemRom:;
  Else Begin
   Inc(C.Unmapped);
   If C.Strict Then Begin
    C.Fault:=Word(A);StopCPU(C,StopUnmapped)
   End
  End
 End
End;

Procedure WriteWord(Var C:TCPU;A:LongInt;V:Word);Begin
 A:=A And $FFFFE;
 If C.NWp>0Then WatchCheck(C,A,2);
 Case MemKind(C,A)Of
  MemPeriph:Begin
   If Not PeriphWriteW(C,A,V)Then Begin
    PeriphWrite(C,A,V And $FF);PeriphWrite(C,A+1,V Shr 8)
   End
  End;
  MemFlash,MemInfo:Begin
   FlashWrite(C,A,V And $FF,True);FlashWrite(C,A+1,V Shr 8,False)
  End;
  MemRam:Begin
   RawPut(C,A,V And $FF);RawPut(C,A+1,V Shr 8)
  End;
  MemRom:;
  Else Begin
   Inc(C.Unmapped);
   If C.Strict Then Begin
    C.Fault:=Word(A);StopCPU(C,StopUnmapped)
   End
  End
 End
End;

{ Lecture/ecriture d'une adresse 20 bits (2 mots) }
Function ReadAddr(Var C:TCPU;A:LongInt):LongInt;
Var
 L,H:Word;
Begin
 L:=ReadWord(C,A);H:=ReadWord(C,A+2);
 ReadAddr:=LongInt(L)Or(LongInt(H And 15)Shl 16)
End;

Procedure WriteAddr(Var C:TCPU;A:LongInt;V:LongInt);Begin
 WriteWord(C,A,Word(V And $FFFF));WriteWord(C,A+2,Word((V Shr 16)And 15))
End;

Function PcMask(Var C:TCPU):LongInt;Begin
 If C.Dev.X Then PcMask:=$FFFFE Else PcMask:=$FFFE
End;

Function FetchW(Var C:TCPU):Word;
Var
 K:Byte;
Begin
 K:=MemKind(C,C.R[0]);
 If(K=MemNone)Or(K=MemPeriph)Then Begin
  C.Fault:=Word(C.R[0]);StopCPU(C,StopFetch);FetchW:=$FFFF
 End
  Else
 FetchW:=RawGetW(C,C.R[0]);
 C.R[0]:=(C.R[0]+2)And PcMask(C)
End;

Procedure Push(Var C:TCPU;V:Word);Begin
 C.R[1]:=(C.R[1]-2)And PcMask(C);WriteWord(C,C.R[1],V)
End;

Function Pop(Var C:TCPU):Word;Begin
 Pop:=ReadWord(C,C.R[1]);C.R[1]:=(C.R[1]+2)And PcMask(C)
End;

{ ------------------------------------------------------------------ }
{  Operandes                                                         }
{ ------------------------------------------------------------------ }

Type
 TLoc=Record
  Kind:Byte;      { 0=registre, 1=memoire, 2=constante }
  Num:LongInt;
  Mode:Byte
 End;
 TPrefix=Record
  Act,Form,ZC,AL:Boolean;
  SHi,DHi:LongInt;
  Rpt:Integer
 End;

Function MaskOf(Sz:Integer):LongInt;Begin
 Case Sz Of
  1:MaskOf:=$FF;
  2:MaskOf:=$FFFFF;
  Else MaskOf:=$FFFF
 End
End;

Function SignOf(Sz:Integer):LongInt;Begin
 Case Sz Of
  1:SignOf:=$80;
  2:SignOf:=$80000;
  Else SignOf:=$8000
 End
End;

{ Calcule l'emplacement d'un operande (mode d'adressage As ou Ad) }
Procedure Resolve(Var C:TCPU;Mode,Reg,Sz:Integer;IsSrc:Boolean;Hi:LongInt;
                  Ex:Boolean;Var L:TLoc);
Var
 X:Word;
 ExtAddr,Off,AM,Inc:LongInt;
Begin
 L.Kind:=0;L.Num:=Reg;L.Mode:=Mode;
 If Ex Then AM:=$FFFFF Else AM:=$FFFF;
 If IsSrc Then Begin
  If Reg=3 Then Begin
   L.Kind:=2;
   Case Mode Of
    0:L.Num:=0;
    1:L.Num:=1;
    2:L.Num:=2;
    Else L.Num:=-1
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
   ExtAddr:=C.R[0];X:=FetchW(C);Off:=LongInt(X)Or Hi;L.Kind:=1;
   If Reg=2 Then L.Num:=Off And AM
   Else If Reg=0 Then L.Num:=(ExtAddr+Off)And AM
   Else L.Num:=(C.R[Reg]+Off)And AM
  End;
  2:Begin
   L.Kind:=1;L.Num:=C.R[Reg]And AM
  End;
  3:Begin
   If Reg=0 Then Begin
    L.Kind:=2;L.Num:=LongInt(FetchW(C))Or Hi
   End
    Else
   Begin
    L.Kind:=1;L.Num:=C.R[Reg]And AM;
    If Sz=2 Then Inc:=4 Else If(Sz=1)And(Reg>1)Then Inc:=1 Else Inc:=2;
    C.R[Reg]:=(C.R[Reg]+Inc)And AM
   End
  End
 End
End;

Function ReadLoc(Var C:TCPU;Const L:TLoc;Sz:Integer):LongInt;
Var
 V:LongInt;
Begin
 Case L.Kind Of
  0:If L.Num=3 Then V:=0 Else V:=C.R[L.Num];
  1:Case Sz Of
     1:V:=ReadByte(C,L.Num);
     2:V:=ReadAddr(C,L.Num);
     Else V:=ReadWord(C,L.Num)
    End;
  Else V:=L.Num
 End;
 ReadLoc:=V And MaskOf(Sz)
End;

Procedure WriteLoc(Var C:TCPU;Const L:TLoc;Sz:Integer;V:LongInt);Begin
 V:=V And MaskOf(Sz);
 Case L.Kind Of
  0:Begin
   If L.Num=3 Then Exit;
   If L.Num=0 Then V:=V And PcMask(C)
   Else If L.Num=1 Then V:=V And PcMask(C);
   C.R[L.Num]:=V
  End;
  1:Case Sz Of
     1:WriteByte(C,L.Num,Byte(V));
     2:WriteAddr(C,L.Num,V);
     Else WriteWord(C,L.Num,Word(V))
    End
 End
End;

{ ------------------------------------------------------------------ }
{  Unite arithmetique et logique                                     }
{ ------------------------------------------------------------------ }

Procedure SetFlag(Var C:TCPU;F:Word;On:Boolean);Begin
 If On Then C.R[2]:=C.R[2]Or F Else C.R[2]:=C.R[2]And Not F
End;

Procedure SetNZ(Var C:TCPU;Res:LongInt;Sz:Integer);Begin
 SetFlag(C,FlagZ,Res=0);SetFlag(C,FlagN,(Res And SignOf(Sz))<>0)
End;

Function AluAdd(Var C:TCPU;S,D,Cin:LongInt;Sz:Integer):LongInt;
Var
 Res,Sum:LongInt;
Begin
 Sum:=D+S+Cin;Res:=Sum And MaskOf(Sz);
 SetNZ(C,Res,Sz);
 SetFlag(C,FlagC,Sum>MaskOf(Sz));
 SetFlag(C,FlagV,((S Xor Res)And(D Xor Res)And SignOf(Sz))<>0);
 AluAdd:=Res
End;

Function AluDadd(Var C:TCPU;S,D:LongInt;Sz:Integer):LongInt;
Var
 J,Digits,Carry,Sum,Res:LongInt;
Begin
 Case Sz Of
  1:Digits:=2;
  2:Digits:=5;
  Else Digits:=4
 End;
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
 SetNZ(C,Res,Sz);SetFlag(C,FlagC,Carry<>0);
 AluDadd:=Res
End;

Procedure LogicFlags(Var C:TCPU;Res:LongInt;Sz:Integer);Begin
 SetNZ(C,Res,Sz);SetFlag(C,FlagC,Res<>0);SetFlag(C,FlagV,False)
End;

{ Cycles de l'operande source (format I) }
Function SrcCycles(Const L:TLoc;Reg:Integer):Integer;Begin
 Case L.Kind Of
  0:SrcCycles:=1;
  2:If(Reg=0)And(L.Mode=3)Then SrcCycles:=2 Else SrcCycles:=1;
  Else If L.Mode=1 Then SrcCycles:=3 Else SrcCycles:=2
 End
End;

{ ------------------------------------------------------------------ }
{  Instructions format I (double operande)                           }
{ ------------------------------------------------------------------ }

Procedure ExecF1(Var C:TCPU;W:Word;Const X:TPrefix;Sz:Integer;ZeroC:Boolean);
Var
 Opc,SReg,DReg,Ad,As,Cy:Integer;
 Store:Boolean;
 LS,LD:TLoc;
 S,D,Res,Cin:LongInt;
Begin
 Opc:=W Shr 12;SReg:=(W Shr 8)And 15;DReg:=W And 15;
 Ad:=(W Shr 7)And 1;As:=(W Shr 4)And 3;
 Resolve(C,As,SReg,Sz,True,X.SHi,X.Act,LS);
 S:=ReadLoc(C,LS,Sz);
 Resolve(C,Ad,DReg,Sz,False,X.DHi,X.Act,LD);
 Cy:=SrcCycles(LS,SReg);
 If Ad=1Then Inc(Cy,3)
  Else If(DReg=0)And Not((LS.Kind=1)And((LS.Mode=1)Or(LS.Mode=2)))Then Inc(Cy);
 If Sz=2Then Begin
  If LS.Kind=1Then Inc(Cy);
  If LD.Kind=1Then Inc(Cy)
 End;
 If X.Act Then Inc(Cy);
 Inc(C.Cycles,Cy);
 If ZeroC Then SetFlag(C,FlagC,False);
 D:=0;Res:=0;Store:=True;
 If Opc<>4Then D:=ReadLoc(C,LD,Sz);
 If(C.R[2]And FlagC)<>0Then Cin:=1 Else Cin:=0;
 Case Opc Of
  4:Res:=S;
  5:Res:=AluAdd(C,S,D,0,Sz);
  6:Res:=AluAdd(C,S,D,Cin,Sz);
  7:Res:=AluAdd(C,(Not S)And MaskOf(Sz),D,Cin,Sz);
  8:Res:=AluAdd(C,(Not S)And MaskOf(Sz),D,1,Sz);
  9:Begin
   Res:=AluAdd(C,(Not S)And MaskOf(Sz),D,1,Sz);Store:=False
  End;
  10:Res:=AluDadd(C,S,D,Sz);
  11:Begin
   Res:=S And D;LogicFlags(C,Res,Sz);Store:=False
  End;
  12:Res:=D And Not S;
  13:Res:=D Or S;
  14:Begin
   Res:=S Xor D;LogicFlags(C,Res,Sz);
   SetFlag(C,FlagV,(S And D And SignOf(Sz))<>0)
  End;
  15:Begin
   Res:=S And D;LogicFlags(C,Res,Sz)
  End
 End;
 If Store Then WriteLoc(C,LD,Sz,Res)
End;

{ ------------------------------------------------------------------ }
{  Instructions format II (simple operande)                          }
{ ------------------------------------------------------------------ }

Procedure PushAddr(Var C:TCPU;V:LongInt);Begin
 C.R[1]:=(C.R[1]-4)And PcMask(C);WriteAddr(C,C.R[1],V)
End;

Function PopAddr(Var C:TCPU):LongInt;Begin
 PopAddr:=ReadAddr(C,C.R[1]);C.R[1]:=(C.R[1]+4)And PcMask(C)
End;

Procedure DoRETI(Var C:TCPU);
Var
 Sr,Lo:Word;
Begin
 Sr:=Pop(C);Lo:=Pop(C);
 If C.Dev.X Then Begin
  C.R[2]:=Sr And $0FFF;
  C.R[0]:=(LongInt(Lo)Or(LongInt(Sr Shr 12)Shl 16))And PcMask(C)
 End
  Else
 Begin
  C.R[2]:=Sr;C.R[0]:=Lo And $FFFE
 End;
 Inc(C.Cycles,5)
End;

Procedure ExecF2(Var C:TCPU;W:Word;Const X:TPrefix;Sz:Integer;ZeroC:Boolean);
Var
 Opc,Reg,As,Cy:Integer;
 L:TLoc;
 S,Res,Cin,Sg:LongInt;
Begin
 Opc:=(W Shr 7)And 7;Reg:=W And 15;As:=(W Shr 4)And 3;
 Resolve(C,As,Reg,Sz,True,X.SHi,X.Act,L);
 S:=ReadLoc(C,L,Sz);Sg:=SignOf(Sz);
 Case Opc Of
  0,1,2,3:If L.Kind=0Then Cy:=1 Else If L.Mode=1Then Cy:=4 Else Cy:=3;
  4:If(L.Kind<>1)And(L.Mode<>3)Then Cy:=3 Else If L.Mode=1Then Cy:=5
    Else Cy:=4;
  Else If(L.Kind=0)Or(L.Mode=2)Then Cy:=4 Else Cy:=5
 End;
 If X.Act Then Inc(Cy);
 Inc(C.Cycles,Cy);
 If ZeroC Then SetFlag(C,FlagC,False);
 If(C.R[2]And FlagC)<>0Then Cin:=Sg Else Cin:=0;
 Case Opc Of
  0:Begin
   SetFlag(C,FlagC,(S And 1)<>0);
   Res:=(S Shr 1)Or Cin;SetNZ(C,Res,Sz);SetFlag(C,FlagV,False);
   WriteLoc(C,L,Sz,Res)
  End;
  1:Begin
   Res:=((S And $FF)Shl 8)Or((S Shr 8)And $FF);
   If Sz=2Then Res:=Res Or(S And $F0000);
   WriteLoc(C,L,Sz,Res)
  End;
  2:Begin
   SetFlag(C,FlagC,(S And 1)<>0);
   Res:=(S Shr 1)Or(S And Sg);
   SetNZ(C,Res,Sz);SetFlag(C,FlagV,False);
   WriteLoc(C,L,Sz,Res)
  End;
  3:Begin
   If(S And $80)<>0Then Begin
    If Sz=2Then Res:=(S And $FF)Or $FFF00 Else Res:=(S And $FF)Or $FF00
   End
    Else
   Res:=S And $FF;
   If Sz=1Then Res:=S And $FF;
   LogicFlags(C,Res,Sz);WriteLoc(C,L,Sz,Res)
  End;
  4:Begin
   Case Sz Of
    1:Begin
     C.R[1]:=(C.R[1]-2)And PcMask(C);WriteByte(C,C.R[1],Byte(S))
    End;
    2:PushAddr(C,S);
    Else Push(C,Word(S))
   End
  End;
  5:Begin
   Push(C,Word(C.R[0]));C.R[0]:=S And PcMask(C)
  End
 End
End;

{ ------------------------------------------------------------------ }
{  Sauts, instructions d'adresse MSP430X et dispatcheur              }
{ ------------------------------------------------------------------ }

Procedure Illegal(Var C:TCPU;W:Word);Begin
 C.Fault:=W;StopCPU(C,StopIllegal)
End;

Function SignExt16(X:Word):LongInt;Begin
 If X>=$8000Then SignExt16:=LongInt(X)-$10000 Else SignExt16:=X
End;

Procedure SetReg(Var C:TCPU;N:Integer;V:LongInt);Begin
 V:=V And $FFFFF;
 If N=3Then Exit;
 If N<=1Then V:=V And PcMask(C);
 C.R[N]:=V
End;

Procedure ExecJump(Var C:TCPU;W:Word);
Var
 Cond,Off:Integer;
 Take,Zf,Nf,Cf,Vf:Boolean;
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
 If Take Then C.R[0]:=(C.R[0]+2*Off)And PcMask(C)
End;

{ Instructions MOVA, CMPA, ADDA, SUBA, RRCM, RRAM, RLAM, RRUM }
Procedure ExecAddr(Var C:TCPU;W:Word);
Var
 Src,Op,Dst,Cnt,Which,J:Integer;
 X:Word;
 ExtAddr,A,S,D,Res,Sg,M:LongInt;
 Cf,Vf:Boolean;
Begin
 Src:=(W Shr 8)And 15;Op:=(W Shr 4)And 15;Dst:=W And 15;
 Case Op Of
  0,1:Begin
   S:=ReadAddr(C,C.R[Src]And $FFFFF);
   If Op=1Then C.R[Src]:=(C.R[Src]+4)And $FFFFF;
   SetReg(C,Dst,S);Inc(C.Cycles,3)
  End;
  2:Begin
   X:=FetchW(C);SetReg(C,Dst,ReadAddr(C,LongInt(X)Or(LongInt(Src)Shl 16)));
   Inc(C.Cycles,4)
  End;
  3:Begin
   ExtAddr:=C.R[0];X:=FetchW(C);
   If Src=0Then A:=ExtAddr Else A:=C.R[Src];
   SetReg(C,Dst,ReadAddr(C,(A+SignExt16(X))And $FFFFF));Inc(C.Cycles,4)
  End;
  4,5:Begin
   Cnt:=(Src Shr 2)+1;Which:=Src And 3;
   If Op=4Then Begin
    M:=$FFFFF;Sg:=$80000
   End
    Else
   Begin
    M:=$FFFF;Sg:=$8000
   End;
   D:=C.R[Dst]And M;Vf:=False;Cf:=(C.R[2]And FlagC)<>0;
   For J:=1To Cnt Do Case Which Of
    0:Begin
     A:=D And 1;D:=D Shr 1;
     If Cf Then D:=D Or Sg;
     Cf:=A<>0
    End;
    1:Begin
     Cf:=(D And 1)<>0;D:=(D Shr 1)Or(D And Sg)
    End;
    2:Begin
     Cf:=(D And Sg)<>0;A:=D;D:=(D Shl 1)And M;
     If((A Xor D)And Sg)<>0Then Vf:=True
    End;
    Else Begin
     Cf:=(D And 1)<>0;D:=D Shr 1
    End
   End;
   SetReg(C,Dst,D);SetFlag(C,FlagC,Cf);SetFlag(C,FlagV,Vf);
   SetFlag(C,FlagZ,D=0);SetFlag(C,FlagN,(D And Sg)<>0);
   Inc(C.Cycles,Cnt+1)
  End;
  6:Begin
   X:=FetchW(C);WriteAddr(C,LongInt(X)Or(LongInt(Dst)Shl 16),C.R[Src]);
   Inc(C.Cycles,4)
  End;
  7:Begin
   ExtAddr:=C.R[0];X:=FetchW(C);
   If Dst=0Then A:=ExtAddr Else A:=C.R[Dst];
   WriteAddr(C,(A+SignExt16(X))And $FFFFF,C.R[Src]);Inc(C.Cycles,4)
  End;
  8,9,10,11:Begin
   X:=FetchW(C);S:=LongInt(X)Or(LongInt(Src)Shl 16);Inc(C.Cycles,2);
   If Dst=0Then Inc(C.Cycles);
   D:=C.R[Dst]And $FFFFF;
   Case Op Of
    8:SetReg(C,Dst,S);
    9:Res:=AluAdd(C,(Not S)And $FFFFF,D,1,2);
    10:SetReg(C,Dst,AluAdd(C,S,D,0,2));
    Else SetReg(C,Dst,AluAdd(C,(Not S)And $FFFFF,D,1,2))
   End
  End;
  Else Begin
   S:=C.R[Src]And $FFFFF;D:=C.R[Dst]And $FFFFF;Inc(C.Cycles);
   If Dst=0Then Inc(C.Cycles);
   Case Op Of
    12:SetReg(C,Dst,S);
    13:Res:=AluAdd(C,(Not S)And $FFFFF,D,1,2);
    14:SetReg(C,Dst,AluAdd(C,S,D,0,2));
    Else SetReg(C,Dst,AluAdd(C,(Not S)And $FFFFF,D,1,2))
   End
  End
 End
End;

{ CALLA }
Procedure ExecCalla(Var C:TCPU;W:Word);
Var
 Sub,Reg:Integer;
 X:Word;
 ExtAddr,Target:LongInt;
Begin
 Sub:=(W Shr 4)And 15;Reg:=W And 15;Target:=0;Inc(C.Cycles,5);
 Case Sub Of
  4:Target:=C.R[Reg]And $FFFFF;
  5:Begin
   X:=FetchW(C);
   Target:=ReadAddr(C,(C.R[Reg]+SignExt16(X))And $FFFFF);Inc(C.Cycles)
  End;
  6:Target:=ReadAddr(C,C.R[Reg]And $FFFFF);
  7:Begin
   Target:=ReadAddr(C,C.R[Reg]And $FFFFF);
   C.R[Reg]:=(C.R[Reg]+4)And $FFFFF
  End;
  8:Begin
   X:=FetchW(C);Target:=ReadAddr(C,LongInt(X)Or(LongInt(Reg)Shl 16))
  End;
  9:Begin
   ExtAddr:=C.R[0];X:=FetchW(C);
   Target:=ReadAddr(C,(ExtAddr+SignExt16(X))And $FFFFF)
  End;
  11:Begin
   X:=FetchW(C);Target:=LongInt(X)Or(LongInt(Reg)Shl 16)
  End;
  Else Begin
   Illegal(C,W);Exit
  End
 End;
 PushAddr(C,C.R[0]);C.R[0]:=Target And PcMask(C)
End;

{ PUSHM / POPM }
Procedure ExecPushM(Var C:TCPU;W:Word);
Var
 N,Reg,J:Integer;
 IsA:Boolean;
Begin
 N:=((W Shr 4)And 15)+1;Reg:=W And 15;IsA:=(W And $100)=0;
 Inc(C.Cycles,N+2);
 If((W Shr 9)And 1)=0Then Begin
  For J:=0To N-1Do If Reg-J>=0Then Begin
   If IsA Then PushAddr(C,C.R[Reg-J])Else Push(C,Word(C.R[Reg-J]))
  End
 End
  Else
 Begin
  For J:=0To N-1Do If Reg+J<=15Then Begin
   If IsA Then SetReg(C,Reg+J,PopAddr(C))
          Else SetReg(C,Reg+J,Pop(C))
  End
 End
End;

{ Execute une instruction complete (prefixe d'extension inclus) }
Procedure ExecOne(Var C:TCPU);
Var
 W,ExtW:Word;
 Ex:TPrefix;
 Sz,J,N,As,Ad:Integer;
 Fmt1,Fmt2:Boolean;
 BW:Boolean;
Begin
 W:=FetchW(C);
 If C.Stopped Then Exit;
 FillChar(Ex,SizeOf(Ex),0);ExtW:=0;
 If(W Shr 11)=3Then Begin
  If Not C.Dev.X Then Begin
   Illegal(C,W);Exit
  End;
  ExtW:=W;Ex.Act:=True;W:=FetchW(C);Inc(C.Cycles);
  If C.Stopped Then Exit
 End;
 Fmt1:=(W Shr 12)>=4;Fmt2:=(W Shr 10)=4;
 If(Not Fmt1)And(Not Fmt2)Then Begin
  If Ex.Act Then Begin
   Illegal(C,W);Exit
  End;
  Case W Shr 12 Of
   0:If C.Dev.X Then ExecAddr(C,W)Else Illegal(C,W);
   1:Begin
    If Not C.Dev.X Then Illegal(C,W)
    Else If(W Shr 8)=$13Then ExecCalla(C,W)
    Else If(W Shr 10)=5Then ExecPushM(C,W)
    Else Illegal(C,W)
   End;
   Else ExecJump(C,W)
  End;
  Exit
 End;
 If Fmt2 And((W Shr 8)=$13)And(W<>$1300)Then Begin
  If Not Ex.Act Then Begin
   ExecCalla(C,W);Exit
  End;
  Illegal(C,W);Exit
 End;
 As:=(W Shr 4)And 3;Ad:=(W Shr 7)And 1;
 If Fmt1 Then Ex.Form:=(As=0)And(Ad=0)Else Ex.Form:=As=0;
 N:=1;
 If Ex.Act Then Begin
  Ex.AL:=(ExtW And $40)<>0;
  If Ex.Form Then Begin
   Ex.ZC:=(ExtW And $100)<>0;
   If(ExtW And $80)=0Then N:=(ExtW And 15)+1
    Else N:=(C.R[ExtW And 15]And 15)+1
  End
   Else
  Begin
   Ex.SHi:=LongInt((ExtW Shr 7)And 15)Shl 16;
   Ex.DHi:=LongInt(ExtW And 15)Shl 16
  End
 End;
 BW:=(W And $40)<>0;Sz:=0;
 If Not Ex.Act Then Begin
  If BW Then Sz:=1
 End
  Else
 If Ex.AL Then Begin
  If BW Then Sz:=1
 End
  Else
 If BW Then Sz:=2
  Else
 If Not(Fmt2 And((((W Shr 7)And 7)=1)Or(((W Shr 7)And 7)=3)))Then Begin
  Illegal(C,W);Exit
 End;
 If Fmt1 Then Begin
  For J:=1To N Do ExecF1(C,W,Ex,Sz,Ex.ZC And(J=1))
 End
  Else
 Begin
  If((W Shr 7)And 7)=6Then Begin
   DoRETI(C);Exit
  End;
  If((W Shr 7)And 7)=7Then Begin
   Illegal(C,W);Exit
  End;
  If(Ex.Act)And(((W Shr 7)And 7)=5)Then Begin
   Illegal(C,W);Exit
  End;
  If Ex.Act And((((W Shr 7)And 7)=1)Or(((W Shr 7)And 7)=3))Then
   If Ex.AL Then Sz:=0 Else Sz:=2;
  For J:=1To N Do ExecF2(C,W,Ex,Sz,Ex.ZC And(J=1))
 End
End;

{ ------------------------------------------------------------------ }
{  Horloges (BCS+), ports, WDT+, multiplieur, evenements             }
{ ------------------------------------------------------------------ }

Function DcoHz(Var C:TCPU):LongInt;
Const
 Rsel:Array[0..15]Of LongInt=(104000,146000,204000,286000,401000,561000,
  786000,1100000,1540000,2160000,3020000,4230000,5920000,8290000,
  11600000,16200000);
 Step:Array[0..7]Of Integer=(790,855,925,1000,1080,1165,1260,1360);
Var
 R,D:Integer;
Begin
 R:=RawGet(C,aBCSCTL1)And 15;D:=RawGet(C,aDCOCTL);
 If(R=15)And(D=$A0)Then DcoHz:=16000000
 Else If(R=14)And(D=$80)Then DcoHz:=12000000
 Else If(R=13)And(D=$C0)Then DcoHz:=8000000
 Else If(R=6)And(D=$C0)Then DcoHz:=1000000
 Else DcoHz:=(Rsel[R]Div 1000)*Step[D Shr 5]
End;

Procedure UpdateClocks(Var C:TCPU);
Var
 B1,B2,B3,Lfxt,Dco,Src:LongInt;
Begin
 B1:=RawGet(C,aBCSCTL1);B2:=RawGet(C,aBCSCTL2);B3:=RawGet(C,aBCSCTL3);
 If((B3 Shr 4)And 3)=2Then Lfxt:=12000 Else Lfxt:=32768;
 Dco:=DcoHz(C);
 C.FAclk:=Lfxt Shr((B1 Shr 4)And 3);
 If(C.R[2]And FlagOSCOFF)<>0Then C.FAclk:=0;
 If(B2 Shr 6)<=1Then Src:=Dco Else Src:=Lfxt;
 C.FMclk:=Src Shr((B2 Shr 4)And 3);
 If C.FMclk<1Then C.FMclk:=1;
 If(B2 And 8)=0Then Src:=Dco Else Src:=Lfxt;
 C.FSmclk:=Src Shr((B2 Shr 1)And 3);
 If(C.R[2]And FlagSCG1)<>0Then C.FSmclk:=0;
 If((B2 And 8)<>0)And((C.R[2]And FlagOSCOFF)<>0)Then C.FSmclk:=0
End;

Function PinVal(Var C:TCPU;N:Integer):Byte;Forward;

{ Reinitialisation (PUC / POR) }
Procedure DoPUC(Var C:TCPU;Hard:Boolean);
Var
 J:Integer;
Begin
 For J:=0To 15Do C.R[J]:=0;
 C.R[1]:=(C.Dev.RamHi+1)And $FFFFE;
 For J:=0To $1FF Do If J<>aDMAIV Then RawPut(C,J,0);
 RawPut(C,aBCSCTL1,$87);RawPut(C,aDCOCTL,$60);RawPut(C,aBCSCTL3,$04);
 RawPut(C,aFCTL2,$42);RawPut(C,aFCTL3,$18);
 RawPut(C,aUA+1,1);RawPut(C,aUB+1,1);RawPut(C,aIFG2,$0A);
 With C Do Begin
  TA.Acc:=0;TA.Down:=False;TB.Acc:=0;TB.Down:=False;
  FillChar(TA.OutQ,SizeOf(TA.OutQ),0);FillChar(TB.OutQ,SizeOf(TB.OutQ),0);
  FillChar(TA.Pend,SizeOf(TA.Pend),0);FillChar(TB.Pend,SizeOf(TB.Pend),0);
  WdtAcc:=0;WdtCnt:=0;AdcBusy:=False;CaOut:=False;
  FillChar(Dma,SizeOf(Dma),0);RtcAcc:=0;
  For J:=0To 1Do Begin
   U[J].Busy:=False;U[J].Full:=False;U[J].RxBusy:=False;U[J].St:=0
  End
 End;
 If Hard Then Begin
  If C.Dev.Rtc Then FillRange(C,aRTC,aRTC+$1F,0)
 End;
 For J:=1To 3Do C.PPrev[J]:=PinVal(C,J);
 C.R[0]:=ReadWord(C,vReset)And PcMask(C);
 UpdateClocks(C)
End;

{ ---- Ports ---- }

Function PortAddr(N:Integer):Word;Begin
 Case N Of
  1:PortAddr:=aP1IN;
  2:PortAddr:=aP2IN;
  Else PortAddr:=aP3IN
 End
End;

Function PinVal(Var C:TCPU;N:Integer):Byte;
Var
 B:Word;
 Dir,Out,Ren,Ext,Drv:Byte;
Begin
 B:=PortAddr(N);Dir:=RawGet(C,B+2);Out:=RawGet(C,B+1);
 If N=3Then Ren:=RawGet(C,aP3REN)Else Ren:=RawGet(C,B+7);
 Drv:=C.PDrv[N];Ext:=C.PVal[N]And Drv;
 PinVal:=(Out And Dir)Or(Not Dir And(Ext Or(Ren And Not Drv And Out)))
End;

Procedure PortUpdate(Var C:TCPU;N:Integer);
Var
 B:Word;
 NewV,Ch,Ies:Byte;
Begin
 NewV:=PinVal(C,N);Ch:=NewV Xor C.PPrev[N];
 If(N<=2)And(Ch<>0)Then Begin
  B:=PortAddr(N);Ies:=RawGet(C,B+4);
  SetBits(C,B+3,Byte((Ch And NewV And Not Ies)Or(Ch And Not NewV And Ies)))
 End;
 C.PPrev[N]:=NewV
End;

{ ---- Multiplieur materiel ---- }

Procedure MpyWrite(Var C:TCPU;A:LongInt;IsByte:Boolean);
Var
 V,P,Acc,Hi,Lo:Double;
 W1,W2:LongInt;
 Neg:Boolean;
Begin
 If A<>aOP2 Then Begin
  C.Mpy1:=RawGetW(C,A And Not 1);C.MpyByte:=IsByte;
  If IsByte Then C.Mpy1:=C.Mpy1 And $FF;
  A:=A And Not 1;
  C.MpySigned:=(A=aMPYS)Or(A=aMACS);
  C.MpyMac:=(A=aMAC)Or(A=aMACS);
  Exit
 End;
 W1:=C.Mpy1;W2:=RawGetW(C,aOP2);
 If IsByte Then W2:=W2 And $FF;
 If C.MpySigned Then Begin
  If C.MpyByte Then Begin
   If W1>=$80Then W1:=W1-$100
  End
   Else If W1>=$8000Then W1:=W1-$10000;
  If IsByte Then Begin
   If W2>=$80Then W2:=W2-$100
  End
   Else If W2>=$8000Then W2:=W2-$10000
 End;
 P:=W1;P:=P*W2;
 Acc:=RawGetW(C,aRESHI);Acc:=Acc*65536+RawGetW(C,aRESLO);
 Neg:=False;
 If C.MpySigned Then Begin
  If Acc>=2147483648.0Then Acc:=Acc-4294967296.0;
  If C.MpyMac Then P:=P+Acc;
  If P>=2147483648.0Then Begin
   P:=P-4294967296.0;Neg:=False
  End;
  Neg:=P<0;
  If P<0Then P:=P+4294967296.0;
  RawPutW(C,aSUMEXT,0);
  If Neg Then RawPutW(C,aSUMEXT,$FFFF)
 End
  Else
 Begin
  If C.MpyMac Then P:=P+Acc;
  RawPutW(C,aSUMEXT,0);
  If P>=4294967296.0Then Begin
   P:=P-4294967296.0;RawPutW(C,aSUMEXT,1)
  End
 End;
 Hi:=Int(P/65536.0);Lo:=P-Hi*65536.0;V:=Hi;
 RawPutW(C,aRESHI,Word(Trunc(V)));RawPutW(C,aRESLO,Word(Trunc(Lo)))
End;

{ ---- Watchdog+ ---- }

Procedure WdtAdvance(Var C:TCPU;Dt:Double);
Var
 Ctl,Iv:LongInt;
 F:LongInt;
 N:LongInt;
Begin
 Ctl:=RawGet(C,aWDTCTL);
 If(Ctl And $80)<>0Then Exit;
 If(Ctl And 4)<>0Then F:=C.FAclk Else F:=C.FSmclk;
 If F=0Then Exit;
 Case Ctl And 3 Of
  0:Iv:=32768;
  1:Iv:=8192;
  2:Iv:=512;
  Else Iv:=64
 End;
 C.WdtAcc:=C.WdtAcc+Dt*F;N:=Trunc(C.WdtAcc);C.WdtAcc:=C.WdtAcc-N;
 C.WdtCnt:=C.WdtCnt+N;
 If C.WdtCnt>=Iv Then Begin
  If(Ctl And $10)<>0Then Begin
   C.WdtCnt:=C.WdtCnt Mod Iv;SetBits(C,aIFG1,1)
  End
   Else
  Begin
   DoPUC(C,False);Inc(C.Resets);SetBits(C,aIFG1,1)
  End
 End
End;

{ ---- Evenements programmes (stimuli externes) ---- }

Procedure TimerCapture(Var C:TCPU;Var Tm:TTimer;Ch:Integer);Forward;

Procedure ApplyEvents(Var C:TCPU);
Var
 E:TEvent;
Begin
 While(C.EvPos<=C.NEv)And(C.Ev[C.EvPos].Time<=C.Now)Do Begin
  E:=C.Ev[C.EvPos];Inc(C.EvPos);
  Case E.Kind Of
   'P':If(E.Idx>=1)And(E.Idx<=3)Then Begin
    C.PVal[E.Idx]:=E.Val And $FF;C.PDrv[E.Idx]:=$FF;PortUpdate(C,E.Idx)
   End;
   'N':If(RawGet(C,aWDTCTL)And $20)<>0Then SetBits(C,aIFG1,$10)
       Else Begin
        DoPUC(C,True);Inc(C.Resets)
       End;
   'A':If(E.Idx>=0)And(E.Idx<=15)Then C.Analog[E.Idx]:=E.Val;
   'C':If(E.Idx>=0)And(E.Idx<=5)Then Begin
    If E.Idx<3Then Begin
     C.TA.CciIn[E.Idx]:=E.Val And 1;TimerCapture(C,C.TA,E.Idx)
    End
     Else
    Begin
     C.TB.CciIn[E.Idx-3]:=E.Val And 1;TimerCapture(C,C.TB,E.Idx-3)
    End
   End;
   'U':If Length(C.Input)<250Then C.Input:=C.Input+Chr(E.Val And $FF)
  End
 End
End;

Procedure AddEvent(Var C:TCPU;Tm:Double;K:Char;I:Integer;V:LongInt);
Var
 P:Integer;
Begin
 If C.NEv<MaxEvent Then Begin
  P:=C.NEv+1;
  While(P>C.EvPos)And(C.Ev[P-1].Time>Tm)Do Begin
   C.Ev[P]:=C.Ev[P-1];Dec(P)
  End;
  C.Ev[P].Time:=Tm;C.Ev[P].Kind:=K;C.Ev[P].Idx:=I;C.Ev[P].Val:=V;
  Inc(C.NEv)
 End
End;

{ ------------------------------------------------------------------ }
{  Timer_A3 et Timer_B3                                              }
{ ------------------------------------------------------------------ }

Function TmCtl(Const Tm:TTimer):Word;Begin
 TmCtl:=Tm.Base
End;

Function TmCctl(Const Tm:TTimer;I:Integer):Word;Begin
 TmCctl:=Tm.Base+2+2*I
End;

Function TmCcr(Const Tm:TTimer;I:Integer):Word;Begin
 TmCcr:=Tm.Base+$12+2*I
End;

Function TmMask(Var C:TCPU;Const Tm:TTimer):LongInt;Begin
 TmMask:=$FFFF;
 If Tm.IsB Then Case(RawGetW(C,Tm.Base)Shr 11)And 3 Of
  1:TmMask:=$0FFF;
  2:TmMask:=$03FF;
  3:TmMask:=$00FF
 End
End;

Procedure OutUnit(Var C:TCPU;Var Tm:TTimer;I:Integer;Equ,Equ0:Boolean);
Var
 Cctl:Word;
Begin
 Cctl:=RawGetW(C,TmCctl(Tm,I));
 Case(Cctl Shr 5)And 7 Of
  0:Tm.OutQ[I]:=(Cctl And 4)<>0;
  1:If Equ Then Tm.OutQ[I]:=True;
  2:Begin
   If Equ Then Tm.OutQ[I]:=Not Tm.OutQ[I];
   If Equ0 Then Tm.OutQ[I]:=False
  End;
  3:Begin
   If Equ Then Tm.OutQ[I]:=True;
   If Equ0 Then Tm.OutQ[I]:=False
  End;
  4:If Equ Then Tm.OutQ[I]:=Not Tm.OutQ[I];
  5:If Equ Then Tm.OutQ[I]:=False;
  6:Begin
   If Equ Then Tm.OutQ[I]:=Not Tm.OutQ[I];
   If Equ0 Then Tm.OutQ[I]:=True
  End;
  Else Begin
   If Equ Then Tm.OutQ[I]:=False;
   If Equ0 Then Tm.OutQ[I]:=True
  End
 End
End;

{ Transfert des registres tampons (Timer_B, bits CLLD) }
Procedure LoadLatches(Var C:TCPU;Var Tm:TTimer;AtZero,AtCcr0:Boolean);
Var
 I,Clld:Integer;
Begin
 If Not Tm.IsB Then Exit;
 For I:=0To 2Do If Tm.Pend[I]Then Begin
  Clld:=(RawGetW(C,TmCctl(Tm,I))Shr 9)And 3;
  If((Clld=1)Or(Clld=2))And AtZero Or(Clld=3)And AtCcr0 Then Begin
   RawPutW(C,TmCcr(Tm,I),Tm.Latch[I]);Tm.Pend[I]:=False
  End
 End
End;

Procedure TimerCapture(Var C:TCPU;Var Tm:TTimer;Ch:Integer);
Var
 Cctl:Word;
 Lvl,Cm:Integer;
 Hit:Boolean;
Begin
 Cctl:=RawGetW(C,TmCctl(Tm,Ch));
 If(Cctl And $100)=0Then Exit;
 Case(Cctl Shr 12)And 3 Of
  0,1:Lvl:=Tm.CciIn[Ch];
  2:Lvl:=0;
  Else Lvl:=1
 End;
 If Lvl<>Tm.CciPrev[Ch]Then Begin
  Cm:=(Cctl Shr 14)And 3;
  Hit:=(Cm=3)Or((Cm=1)And(Lvl=1))Or((Cm=2)And(Lvl=0));
  Tm.CciPrev[Ch]:=Lvl;
  If Lvl<>0Then Cctl:=Cctl Or 8 Else Cctl:=Cctl And Not 8;
  If Hit Then Begin
   If(Cctl And 1)<>0Then Cctl:=Cctl Or 2;
   Cctl:=Cctl Or 1;
   RawPutW(C,TmCcr(Tm,Ch),RawGetW(C,Tm.Base+$10)And TmMask(C,Tm))
  End;
  RawPutW(C,TmCctl(Tm,Ch),Cctl)
 End
End;

Procedure TimerTick(Var C:TCPU;Var Tm:TTimer);
Var
 Ctl,Mc,Mask,Tar,Ccr0,Ccr,I:LongInt;
 Roll,Equ0,Equ:Boolean;
 Cctl:Word;
Begin
 Ctl:=RawGetW(C,Tm.Base);Mc:=(Ctl Shr 4)And 3;Mask:=TmMask(C,Tm);
 Tar:=RawGetW(C,Tm.Base+$10)And Mask;Ccr0:=RawGetW(C,TmCcr(Tm,0));
 Roll:=False;
 Case Mc Of
  1:If Tar>=Ccr0 Then Begin
   Tar:=0;Roll:=True
  End
   Else Inc(Tar);
  2:Begin
   Tar:=(Tar+1)And Mask;Roll:=Tar=0
  End;
  Else Begin
   If Tm.Down Then Begin
    If Tar>0Then Dec(Tar);
    If Tar=0Then Begin
     Tm.Down:=False;Roll:=True
    End
   End
    Else
   Begin
    If Tar<Ccr0 Then Inc(Tar);
    If Tar>=Ccr0 Then Tm.Down:=True
   End
  End
 End;
 RawPutW(C,Tm.Base+$10,Word(Tar));
 If Roll Then SetBits(C,Tm.Base,1);
 LoadLatches(C,Tm,Tar=0,Tar=RawGetW(C,TmCcr(Tm,0)));
 Equ0:=False;
 For I:=0To 2Do Begin
  Cctl:=RawGetW(C,TmCctl(Tm,I));
  Equ:=((Cctl And $100)=0)And(Tar=RawGetW(C,TmCcr(Tm,I)));
  If I=0Then Equ0:=Equ;
  If Equ Then SetBits(C,TmCctl(Tm,I),1);
  If(Cctl And $100)=0Then OutUnit(C,Tm,Integer(I),Equ,(I>0)And Equ0)
 End
End;

Procedure TimerAdvance(Var C:TCPU;Var Tm:TTimer;Dt:Double);
Var
 Ctl:Word;
 F,Divisor,N:LongInt;
Begin
 Ctl:=RawGetW(C,Tm.Base);
 If((Ctl Shr 4)And 3)=0Then Exit;
 Case(Ctl Shr 8)And 3 Of
  1:F:=C.FAclk;
  2:F:=C.FSmclk;
  Else F:=0
 End;
 If F=0Then Exit;
 Divisor:=1 Shl((Ctl Shr 6)And 3);
 Tm.Acc:=Tm.Acc+Dt*F/Divisor;N:=Trunc(Tm.Acc);Tm.Acc:=Tm.Acc-N;
 While N>0Do Begin
  Dec(N);TimerTick(C,Tm)
 End
End;

{ Interruption du canal 0 en attente }
Function TimerPend0(Var C:TCPU;Const Tm:TTimer):Boolean;Begin
 TimerPend0:=(RawGet(C,TmCctl(Tm,0))And $11)=$11
End;

{ Valeur du registre TxIV (sans effacer): 0 si rien en attente }
Function TimerIv(Var C:TCPU;Const Tm:TTimer;Clear:Boolean):Word;
Var
 V:Word;
 Flag:Boolean;
Begin
 V:=0;
 If(RawGet(C,TmCctl(Tm,1))And $11)=$11Then Begin
  V:=2;If Clear Then ClrBits(C,TmCctl(Tm,1),1)
 End
 Else If(RawGet(C,TmCctl(Tm,2))And $11)=$11Then Begin
  V:=4;If Clear Then ClrBits(C,TmCctl(Tm,2),1)
 End
 Else Begin
  Flag:=(RawGet(C,Tm.Base)And 3)=3;
  If Flag Then Begin
   If Tm.IsB Then V:=14 Else V:=10;
   If Clear Then ClrBits(C,Tm.Base,1)
  End
 End;
 TimerIv:=V
End;

{ Ecriture des registres du timer (apres stockage de l'octet) }
Procedure TimerWriteHook(Var C:TCPU;Var Tm:TTimer;A:LongInt);
Var
 I:Integer;
Begin
 If A=Tm.Base Then Begin
  If(RawGet(C,A)And 4)<>0Then Begin
   RawPutW(C,Tm.Base+$10,0);Tm.Acc:=0;Tm.Down:=False;ClrBits(C,A,4)
  End
 End
  Else
 For I:=0To 2Do If(A>=TmCctl(Tm,I))And(A<=TmCctl(Tm,I)+1)Then Begin
  TimerCapture(C,Tm,I);
  If(RawGetW(C,TmCctl(Tm,I))And $100)=0Then
   OutUnit(C,Tm,I,False,False)
 End
End;

{ ------------------------------------------------------------------ }
{  USCI_A0 (UART/SPI) et USCI_B0 (SPI/I2C)                           }
{ ------------------------------------------------------------------ }

Function UBase(J:Integer):Word;Begin
 If J=0Then UBase:=aUA Else UBase:=aUB
End;

Function RxFlag(J:Integer):Byte;Begin
 RxFlag:=1 Shl(2*J)
End;

Function TxFlag(J:Integer):Byte;Begin
 TxFlag:=2 Shl(2*J)
End;

Function IsI2C(Var C:TCPU;J:Integer):Boolean;Begin
 IsI2C:=(J=1)And((RawGet(C,aUB)And 7)=7)
End;

Function IsSync(Var C:TCPU;J:Integer):Boolean;Begin
 IsSync:=(RawGet(C,UBase(J))And 1)<>0
End;

Function InReset(Var C:TCPU;J:Integer):Boolean;Begin
 InReset:=(RawGet(C,UBase(J)+1)And 1)<>0
End;

{ Duree d'un bit en secondes (0 si pas d'horloge) }
Function BitTime(Var C:TCPU;J:Integer):Double;
Var
 B:Word;
 Br,F:LongInt;
Begin
 B:=UBase(J);Br:=RawGet(C,B+2)+LongInt(RawGet(C,B+3))*256;
 If Br=0Then Br:=1;
 Case(RawGet(C,B+1)Shr 6)And 3 Of
  1:F:=C.FAclk;
  2,3:F:=C.FSmclk;
  Else F:=0
 End;
 If F=0Then Begin
  BitTime:=0;Exit
 End;
 If(J=0)And Not IsSync(C,J)And((RawGet(C,B+4)And 1)<>0)Then Br:=Br*16;
 BitTime:=Br/F
End;

Function FrameTime(Var C:TCPU;J:Integer):Double;
Var
 B:Word;
 Nb:Integer;
Begin
 B:=UBase(J);
 If IsI2C(C,J)Then Begin
  FrameTime:=9*BitTime(C,J);Exit
 End;
 If IsSync(C,J)Then Begin
  FrameTime:=8*BitTime(C,J);Exit
 End;
 Nb:=1;
 If(RawGet(C,B)And $10)<>0Then Inc(Nb,7)Else Inc(Nb,8);
 If(RawGet(C,B)And $80)<>0Then Inc(Nb);
 If(RawGet(C,B)And 8)<>0Then Inc(Nb,2)Else Inc(Nb);
 FrameTime:=Nb*BitTime(C,J)
End;

Procedure UsciReset(Var C:TCPU;J:Integer);Begin
 With C.U[J]Do Begin
  Busy:=False;Full:=False;RxBusy:=False;St:=0;Nack:=False
 End;
 ClrBits(C,aIFG2,RxFlag(J));SetBits(C,aIFG2,TxFlag(J));
 If J=1Then ClrBits(C,aUB+5,$1F)
End;

Procedure I2cStop(Var C:TCPU;J:Integer);Begin
 C.U[J].St:=0;C.U[J].Busy:=False;C.U[J].Full:=False;C.U[J].RxBusy:=False;
 ClrBits(C,aUB+5,$10);ClrBits(C,aUB+1,$06)
End;

{ Octet envoye par le maitre I2C au composant virtuel }
Procedure I2cDeviceWrite(Var C:TCPU;J:Integer;V:Byte);Begin
 With C.U[J]Do Begin
  If St=2Then Begin
   If Nack Then Begin
    Ptr:=V;Nack:=False
   End
    Else
   Begin
    C.I2cMem[Ptr]:=V;Ptr:=Ptr+1
   End
  End
 End
End;

{ Fin de la transmission d'un octet / trame }
Procedure TxDone(Var C:TCPU;J:Integer);
Var
 Ch:Byte;
Begin
 With C.U[J]Do Begin
  If IsI2C(C,J)Then Begin
   If St=1Then Begin
    { phase adresse: le composant virtuel repond-il ? }
    If(C.I2cDev<>0)And((RawGetW(C,aUCB0I2CSA)And $7F)=C.I2cDev)Then Begin
     ClrBits(C,aUB+1,2);Nack:=True;   { Nack=True: prochain octet = pointeur }
     If(RawGet(C,aUB+1)And $10)<>0Then Begin
      If Full Then Begin
       Shift:=Buf;Full:=False;St:=2;Remain:=FrameTime(C,J)
      End
       Else
      Begin
       St:=5;Busy:=False;
       If(RawGet(C,aUB+1)And 4)<>0Then I2cStop(C,J)
      End;
      SetBits(C,aIFG2,TxFlag(J))
     End
      Else
     Begin
      St:=3;Busy:=False;RxBusy:=True;RxRem:=FrameTime(C,J);Nack:=False
     End
    End
     Else
    Begin
     SetBits(C,aUB+5,8);ClrBits(C,aUB+1,2);Busy:=False;St:=0;
     If(RawGet(C,aUB+1)And 4)<>0Then I2cStop(C,J)
    End
   End
    Else
   Begin
    I2cDeviceWrite(C,J,Shift);
    If Full Then Begin
     Shift:=Buf;Full:=False;Remain:=Remain+FrameTime(C,J);
     SetBits(C,aIFG2,TxFlag(J))
    End
     Else
    Begin
     Busy:=False;St:=5;
     If(RawGet(C,aUB+1)And 4)<>0Then I2cStop(C,J)
    End
   End;
   Exit
  End;
  { UART ou SPI }
  If J=0Then Begin
   If Not IsSync(C,J)Then Begin
    Ch:=Shift;
    If(RawGet(C,aUA)And $10)<>0Then Ch:=Ch And $7F;
    If C.Capture Then Begin
     If Length(C.OutBuf)<250Then C.OutBuf:=C.OutBuf+Chr(Ch)
    End
     Else Write(Chr(Ch));
    C.LastOut:=Ch;Inc(C.OutCount)
   End
  End;
  If IsSync(C,J)Then Begin
   If(RawGet(C,UBase(J)+5)And $80)<>0Then RxByte:=Shift Else RxByte:=C.MisoByte;
   RawPut(C,UBase(J)+6,RxByte);SetBits(C,aIFG2,RxFlag(J))
  End;
  If Full Then Begin
   Shift:=Buf;Full:=False;Remain:=Remain+FrameTime(C,J);
   SetBits(C,aIFG2,TxFlag(J))
  End
   Else
  Busy:=False
 End
End;

Procedure RxDone(Var C:TCPU;J:Integer);Begin
 With C.U[J]Do Begin
  If IsI2C(C,J)Then Begin
   RawPut(C,aUB+6,C.I2cMem[Ptr]);Ptr:=Ptr+1;RxBusy:=False;
   SetBits(C,aIFG2,RxFlag(J));
   If(RawGet(C,aUB+1)And 4)<>0Then I2cStop(C,J)Else St:=6
  End
   Else
  Begin
   RawPut(C,UBase(J)+6,RxByte);SetBits(C,aIFG2,RxFlag(J));RxBusy:=False
  End
 End
End;

Procedure UsciAdvance(Var C:TCPU;J:Integer;Dt:Double);
Var
 Guard:Integer;
Begin
 If InReset(C,J)Then Exit;
 With C.U[J]Do Begin
  Guard:=0;
  If Busy Then Begin
   Remain:=Remain-Dt;
   While Busy And(Remain<=0)And(Guard<64)Do Begin
    Inc(Guard);TxDone(C,J)
   End
  End;
  If RxBusy Then Begin
   RxRem:=RxRem-Dt;
   If RxRem<=0Then RxDone(C,J)
  End
   Else
  Begin
   { UART: reception des caracteres fournis (-I, evenements) }
   If(J=0)And Not IsSync(C,J)And(C.InputPos<=Length(C.Input))And
    ((RawGet(C,aIFG2)And RxFlag(0))=0)Then Begin
    RxByte:=Ord(C.Input[C.InputPos]);Inc(C.InputPos);RxBusy:=True;
    RxRem:=FrameTime(C,J)
   End
    Else
   { I2C: reception de l'octet suivant une fois RXBUF lu }
   If(J=1)And(St=6)And((RawGet(C,aIFG2)And RxFlag(1))=0)Then Begin
    St:=3;RxBusy:=True;RxRem:=FrameTime(C,J)
   End
  End
 End
End;

Procedure UsciWriteTx(Var C:TCPU;J:Integer;V:Byte);Begin
 If InReset(C,J)Then Exit;
 With C.U[J]Do Begin
  If IsI2C(C,J)Then Begin
   If St=1Then Begin
    Buf:=V;Full:=True;ClrBits(C,aIFG2,TxFlag(J));Exit
   End;
   If St<>5Then If St<>2Then Exit
  End;
  ClrBits(C,aIFG2,TxFlag(J));
  If Busy Then Begin
   Buf:=V;Full:=True
  End
   Else
  Begin
   If IsI2C(C,J)Then St:=2;
   Shift:=V;Busy:=True;Remain:=FrameTime(C,J);SetBits(C,aIFG2,TxFlag(J))
  End
 End
End;

Procedure UsciCtl1Write(Var C:TCPU;J:Integer);
Var
 Ctl:Byte;
Begin
 Ctl:=RawGet(C,UBase(J)+1);
 If(Ctl And 1)<>0Then Begin
  UsciReset(C,J);Exit
 End;
 If(J=1)And IsI2C(C,J)And((RawGet(C,aUB)And 8)<>0)Then With C.U[J]Do Begin
  If((Ctl And 2)<>0)And(St=0)Then Begin
   St:=1;Busy:=True;Remain:=FrameTime(C,J);SetBits(C,aUB+5,$10)
  End;
  If((Ctl And 4)<>0)And(St<>1)Then Begin
   If(St=5)Or(St=6)Or(St=0)Then I2cStop(C,J)
  End
 End
End;

{ Lecture de RXBUF: efface l'indicateur de reception }
Function UsciReadRx(Var C:TCPU;J:Integer):Byte;Begin
 ClrBits(C,aIFG2,RxFlag(J));
 UsciReadRx:=RawGet(C,UBase(J)+6)
End;

Function UsciStat(Var C:TCPU;J:Integer):Byte;
Var
 V:Byte;
Begin
 V:=RawGet(C,UBase(J)+5);
 If J=0Then Begin
  V:=V And $FE;
  If C.U[0].Busy Or C.U[0].RxBusy Then V:=V Or 1
 End
  Else
 If Not IsI2C(C,1)Then Begin
  V:=V And $FE;
  If C.U[1].Busy Then V:=V Or 1
 End;
 UsciStat:=V
End;

{ ------------------------------------------------------------------ }
{  ADC10, Comparator_A+, controleur flash, DMA, RTC_A                }
{ ------------------------------------------------------------------ }

Function AdcClock(Var C:TCPU;Ctl1:Word):LongInt;Begin
 Case(Ctl1 Shr 3)And 3 Of
  0:AdcClock:=5000000;
  1:AdcClock:=C.FAclk;
  Else AdcClock:=C.FSmclk
 End;
 If((Ctl1 Shr 3)And 3)=2Then AdcClock:=C.FMclk
End;

Function AdcSample(Var C:TCPU;Ch:Integer):LongInt;
Var
 Ctl0:Word;
 Vp,Mv,V:LongInt;
Begin
 Ctl0:=RawGetW(C,aADCCTL0);
 Case(Ctl0 Shr 13)And 7 Of
  1,5:If(Ctl0 And $40)<>0Then Vp:=2500 Else Vp:=1500;
  Else Vp:=3300
 End;
 Case Ch Of
  11:Mv:=1650;
  8,9:Mv:=3300;
  Else Mv:=C.Analog[Ch And 15]
 End;
 V:=(Mv*1024)Div Vp;
 If V>1023Then V:=1023;
 If V<0Then V:=0;
 AdcSample:=V
End;

Procedure AdcStart(Var C:TCPU);
Var
 Ctl0,Ctl1:Word;
 Sht,Dv,F:LongInt;
 Dur:Double;
Begin
 Ctl0:=RawGetW(C,aADCCTL0);Ctl1:=RawGetW(C,aADCCTL1);
 If C.AdcBusy Then Exit;
 C.AdcBusy:=True;C.AdcCh:=Ctl1 Shr 12;
 Case(Ctl0 Shr 11)And 3 Of
  0:Sht:=4;
  1:Sht:=8;
  2:Sht:=16;
  Else Sht:=64
 End;
 Dv:=((Ctl1 Shr 5)And 7)+1;F:=AdcClock(C,Ctl1);
 If F=0Then Dur:=0 Else Dur:=(Sht+13)*Dv/F;
 C.AdcRem:=Dur;
 RawPutW(C,aADCCTL1,Ctl1 Or 1);RawPutW(C,aADCCTL0,Ctl0 And Not 1)
End;

Procedure AdcFinish(Var C:TCPU);
Var
 Ctl0,Ctl1:Word;
 Cs,Cnt:Integer;
 V:LongInt;
 Again:Boolean;
Begin
 Ctl0:=RawGetW(C,aADCCTL0);Ctl1:=RawGetW(C,aADCCTL1);
 V:=AdcSample(C,C.AdcCh);RawPutW(C,aADCMEM,Word(V));
 Cnt:=RawGet(C,aADCDTC1);Cs:=(Ctl1 Shr 1)And 3;
 If Cnt>0Then Begin
  WriteWord(C,RawGetW(C,aADCSA)+2*C.AdcIdx,Word(V));Inc(C.AdcIdx);
  If C.AdcIdx>=Cnt Then Begin
   C.AdcIdx:=0;SetBits(C,aADCCTL0,4)
  End
 End
  Else
 SetBits(C,aADCCTL0,4);
 C.AdcBusy:=False;Again:=False;
 If(Cs=1)Or(Cs=3)Then Begin
  If C.AdcCh>0Then Begin
   Dec(C.AdcCh);RawPutW(C,aADCCTL1,(Ctl1 And $0FFF)Or(Word(C.AdcCh)Shl 12));
   Again:=True
  End
   Else
  Begin
   RawPutW(C,aADCCTL1,(Ctl1 And $0FFF)Or(Word(Ctl1 Shr 12)Shl 12));
   If(Cs=3)And((Ctl0 And $80)<>0)Then Again:=True
  End
 End
  Else
 If(Cs=2)And((Ctl0 And $80)<>0)Then Again:=True;
 If Again And((Ctl0 And 2)<>0)Then AdcStart(C)
  Else RawPutW(C,aADCCTL1,RawGetW(C,aADCCTL1)And Not 1)
End;

Procedure AdcAdvance(Var C:TCPU;Dt:Double);Begin
 If C.AdcBusy Then Begin
  C.AdcRem:=C.AdcRem-Dt;
  If C.AdcRem<=0Then AdcFinish(C)
 End
End;

Procedure AdcCtl0Hook(Var C:TCPU);
Var
 Ctl0:Word;
Begin
 Ctl0:=RawGetW(C,aADCCTL0);
 If((Ctl0 And 3)=3)And((Ctl0 And $10)<>0)Then AdcStart(C)
End;

{ ---- Comparator_A+ ---- }

Procedure CompUpdate(Var C:TCPU);
Var
 C1,C2:Byte;
 Sig,Ref,Vcc:LongInt;
 Out:Boolean;
Begin
 C1:=RawGet(C,aCACTL1);C2:=RawGet(C,aCACTL2);Vcc:=3300;
 If(C1 And 8)=0Then Begin
  Out:=False
 End
  Else
 Begin
  If(C2 And 8)<>0Then Sig:=C.Analog[0]
  Else If(C2 And $10)<>0Then Sig:=C.Analog[1]
  Else If(C2 And $20)<>0Then Sig:=C.Analog[2]
  Else If(C2 And $40)<>0Then Sig:=C.Analog[3]
  Else Sig:=0;
  Case(C1 Shr 4)And 3 Of
   1:Ref:=Vcc Div 4;
   2:Ref:=Vcc Div 2;
   3:Ref:=550;
   Else If(C2 And $10)<>0Then Ref:=C.Analog[1]Else Ref:=0
  End;
  If(C1 And $40)=0Then Out:=Sig>Ref Else Out:=Ref>Sig
 End;
 If Out<>C.CaOut Then Begin
  If(Out And((C1 And 4)=0))Or(Not Out And((C1 And 4)<>0))Then
   SetBits(C,aCACTL1,1);
  C.CaOut:=Out
 End;
 If Out Then SetBits(C,aCACTL2,1)Else ClrBits(C,aCACTL2,1)
End;

{ ---- Controleur flash ---- }

Procedure Stall(Var C:TCPU;Secs:Double);Begin
 C.Cycles:=C.Cycles+Trunc(Secs*C.FMclk)
End;

Procedure EraseRange(Var C:TCPU;Lo,Hi:LongInt);Begin
 FillRange(C,Lo,Hi,$FF)
End;

Procedure FlashWrite(Var C:TCPU;A:LongInt;V:Byte;Charge:Boolean);
Var
 F1,F3:Byte;
 Info:Boolean;
 Lo:LongInt;
Begin
 F1:=RawGet(C,aFCTL1);F3:=RawGet(C,aFCTL3);
 Info:=MemKind(C,A)=MemInfo;
 If((F3 And $10)<>0)Or((F1 And $C6)=0)Or
  (Info And((F3 And $40)<>0)And(A>=C.Dev.InHi-63))Then Begin
  SetBits(C,aFCTL3,4);Exit
 End;
 If(F1 And 6)<>0Then Begin
  If(F1 And 4)<>0Then Begin
   EraseRange(C,C.Dev.FlLo,C.Dev.FlHi);
   If C.Dev.Fl2Hi>C.Dev.Fl2Lo Then EraseRange(C,C.Dev.Fl2Lo,C.Dev.Fl2Hi);
   If(F1 And 2)<>0Then EraseRange(C,C.Dev.InLo,C.Dev.InHi);
   If Charge Then Stall(C,10593/350000.0)
  End
   Else
  Begin
   If Info Then Lo:=A And Not 63 Else Lo:=A And Not 511;
   If Info Then EraseRange(C,Lo,Lo+63)Else EraseRange(C,Lo,Lo+511);
   If Charge Then Stall(C,4819/350000.0)
  End
 End
  Else
 Begin
  RawPut(C,A,RawGet(C,A)And V);
  If Charge Then Begin
   If(F1 And $80)<>0Then Stall(C,21/350000.0)Else Stall(C,30/350000.0)
  End
 End
End;

{ Ecriture mot d'un registre FCTLx (mot de passe $A5) }
Procedure FctlWrite(Var C:TCPU;A:LongInt;V:Word);
Var
 Old:Byte;
Begin
 If(V Shr 8)<>$A5Then Begin
  SetBits(C,aFCTL3,2);DoPUC(C,False);Inc(C.Resets);Exit
 End;
 Case A Of
  aFCTL1:RawPut(C,A,V And $C6);
  aFCTL2:RawPut(C,A,V And $FF);
  Else Begin
   Old:=RawGet(C,aFCTL3);
   V:=V And $FF;
   If(V And $40)<>0Then V:=(V And Not $40)Or((Old And $40)Xor $40)
    Else V:=V And Not $40;
   RawPut(C,aFCTL3,(V And $76)Or $08)
  End
 End
End;

{ ---- DMA ---- }

Function DmaReg(I:Integer;Off:Integer):Word;Begin
 DmaReg:=aDMA0+8*I+Off
End;

Function DmaTrigger(Var C:TCPU;Sel:Integer):Boolean;
Var
 Hit:Boolean;
Begin
 Hit:=False;
 Case Sel Of
  1:If(RawGet(C,aTA+6)And 1)<>0Then Begin
   Hit:=True;ClrBits(C,aTA+6,1)
  End;
  2:If(RawGet(C,aTB+6)And 1)<>0Then Begin
   Hit:=True;ClrBits(C,aTB+6,1)
  End;
  3:Hit:=(RawGet(C,aIFG2)And 1)<>0;
  4:Hit:=(RawGet(C,aIFG2)And 2)<>0;
  5:Hit:=(RawGet(C,aIFG2)And 4)<>0;
  6:Hit:=(RawGet(C,aIFG2)And 8)<>0;
  7:If(RawGet(C,aADCCTL0)And 4)<>0Then Begin
   Hit:=True;ClrBits(C,aADCCTL0,4)
  End;
  8:If(RawGet(C,aTA+2)And 1)<>0Then Begin
   Hit:=True;ClrBits(C,aTA+2,1)
  End;
  9:If(RawGet(C,aTB+2)And 1)<>0Then Begin
   Hit:=True;ClrBits(C,aTB+2,1)
  End
 End;
 DmaTrigger:=Hit
End;

Procedure DmaLoad(Var C:TCPU;I:Integer);Begin
 C.Dma[I].Sa:=RawGetW(C,DmaReg(I,2));C.Dma[I].Da:=RawGetW(C,DmaReg(I,4));
 C.Dma[I].Sz:=RawGetW(C,DmaReg(I,6))
End;

Procedure DmaTransfer(Var C:TCPU;I:Integer);
Var
 Ctl:Word;
 SB,DB:Boolean;
 V:Word;
 Si,Di:Integer;
Begin
 Ctl:=RawGetW(C,DmaReg(I,0));SB:=(Ctl And $40)<>0;DB:=(Ctl And $80)<>0;
 If SB Then V:=ReadByte(C,C.Dma[I].Sa)Else V:=ReadWord(C,C.Dma[I].Sa);
 If DB Then WriteByte(C,C.Dma[I].Da,Byte(V))Else WriteWord(C,C.Dma[I].Da,V);
 If SB Then Si:=1 Else Si:=2;
 If DB Then Di:=1 Else Di:=2;
 Case(Ctl Shr 8)And 3 Of
  2:C.Dma[I].Sa:=(C.Dma[I].Sa-Si)And $FFFF;
  3:C.Dma[I].Sa:=(C.Dma[I].Sa+Si)And $FFFF
 End;
 Case(Ctl Shr 10)And 3 Of
  2:C.Dma[I].Da:=(C.Dma[I].Da-Di)And $FFFF;
  3:C.Dma[I].Da:=(C.Dma[I].Da+Di)And $FFFF
 End;
 Dec(C.Dma[I].Sz);Inc(C.Cycles,2)
End;

Procedure DmaPoll(Var C:TCPU);
Var
 I,Sel,Dt,N:Integer;
 Ctl:Word;
 Trig:Boolean;
Begin
 For I:=0To 2Do Begin
  Ctl:=RawGetW(C,DmaReg(I,0));
  If(Ctl And $10)<>0Then Begin
   If Not C.Dma[I].Running Then Begin
    DmaLoad(C,I);C.Dma[I].Running:=True
   End;
   Sel:=(RawGetW(C,aDMACTL0)Shr(4*I))And 15;
   Trig:=(Ctl And 1)<>0;
   If Trig Then ClrBits(C,DmaReg(I,0),1)Else Trig:=DmaTrigger(C,Sel);
   If Trig Then Begin
    Dt:=(Ctl Shr 12)And 7;
    If(Dt And 3)=0Then N:=1 Else N:=C.Dma[I].Sz;
    If N>C.Dma[I].Sz Then N:=C.Dma[I].Sz;
    While N>0Do Begin
     DmaTransfer(C,I);Dec(N)
    End;
    If C.Dma[I].Sz<=0Then Begin
     SetBits(C,DmaReg(I,0),8);
     If Dt>=4Then DmaLoad(C,I)
      Else Begin
       ClrBits(C,DmaReg(I,0),$10);C.Dma[I].Running:=False
      End
    End
   End
  End
   Else
  C.Dma[I].Running:=False
 End
End;

Function DmaPending(Var C:TCPU):Boolean;
Var
 I:Integer;
Begin
 DmaPending:=False;
 For I:=0To 2Do If(RawGet(C,DmaReg(I,0))And $0C)=$0C Then DmaPending:=True
End;

Function DmaIv(Var C:TCPU):Word;
Var
 I:Integer;
Begin
 DmaIv:=0;
 For I:=0To 2Do If(RawGet(C,DmaReg(I,0))And $0C)=$0C Then Begin
  ClrBits(C,DmaReg(I,0),8);DmaIv:=2*(I+1);Exit
 End
End;

{ ---- RTC_A (profil X) ---- }

Function RtcGet(Var C:TCPU;Off:Integer):Integer;
Var
 V:Integer;
Begin
 V:=RawGet(C,aRTC+$10+Off)And $7F;
 If(RawGet(C,aRTC+1)And $80)<>0Then V:=(V Shr 4)*10+(V And 15);
 RtcGet:=V
End;

Procedure RtcSet(Var C:TCPU;Off,V:Integer);Begin
 If(RawGet(C,aRTC+1)And $80)<>0Then V:=(V Div 10)*16+(V Mod 10);
 RawPut(C,aRTC+$10+Off,V)
End;

Function DaysIn(Mon,Year:Integer):Integer;Begin
 Case Mon Of
  2:If((Year Mod 4=0)And(Year Mod 100<>0))Or(Year Mod 400=0)Then DaysIn:=29
    Else DaysIn:=28;
  4,6,9,11:DaysIn:=30;
  Else DaysIn:=31
 End
End;

Procedure RtcTick(Var C:TCPU);
Var
 Sec,Mn,Hr,Dow,Day,Mon,Yr,Tev,Cnt,Al:Integer;
 Bcd:Boolean;
 N:LongInt;
 Ev:Boolean;
Begin
 SetBits(C,aRTC,1);Ev:=False;Tev:=RawGet(C,aRTC+1)And 3;
 If(RawGet(C,aRTC+1)And $20)=0Then Begin
  N:=RawGet(C,aRTC+$10)Or(LongInt(RawGet(C,aRTC+$11))Shl 8)Or
   (LongInt(RawGet(C,aRTC+$12))Shl 16)Or(LongInt(RawGet(C,aRTC+$13))Shl 24);
  Inc(N);
  Cnt:=8*(Tev+1);
  If Cnt<32Then Ev:=(N And((LongInt(1)Shl Cnt)-1))=0 Else Ev:=N=0;
  RawPut(C,aRTC+$10,N And $FF);RawPut(C,aRTC+$11,(N Shr 8)And $FF);
  RawPut(C,aRTC+$12,(N Shr 16)And $FF);RawPut(C,aRTC+$13,(N Shr 24)And $FF)
 End
  Else
 Begin
  Bcd:=(RawGet(C,aRTC+1)And $80)<>0;
  Sec:=RtcGet(C,0);Mn:=RtcGet(C,1);Hr:=RtcGet(C,2);Dow:=RtcGet(C,3);
  Day:=RtcGet(C,4);Mon:=RtcGet(C,5);Yr:=RawGetW(C,aRTC+$16);
  If Bcd Then Yr:=((Yr Shr 12)And 15)*1000+((Yr Shr 8)And 15)*100+
   ((Yr Shr 4)And 15)*10+(Yr And 15);
  Inc(Sec);
  If Sec>=60Then Begin
   Sec:=0;Inc(Mn);
   If Mn>=60Then Begin
    Mn:=0;Inc(Hr);
    If(Tev=1)Then Ev:=True;
    If Hr>=24Then Begin
     Hr:=0;Inc(Dow);Dow:=Dow Mod 7;Inc(Day);
     If Day>DaysIn(Mon,Yr)Then Begin
      Day:=1;Inc(Mon);
      If Mon>12Then Begin
       Mon:=1;Inc(Yr)
      End
     End;
     If Tev=2Then Ev:=True
    End
     Else
    If(Tev=3)And(Hr=12)Then Ev:=True
   End;
   If Tev=0Then Ev:=True
  End;
  RtcSet(C,0,Sec);RtcSet(C,1,Mn);RtcSet(C,2,Hr);RtcSet(C,3,Dow);
  RtcSet(C,4,Day);RtcSet(C,5,Mon);
  If Bcd Then RawPutW(C,aRTC+$16,((Yr Div 1000)Shl 12)Or
   (((Yr Div 100)Mod 10)Shl 8)Or(((Yr Div 10)Mod 10)Shl 4)Or(Yr Mod 10))
   Else RawPutW(C,aRTC+$16,Yr);
  If Sec=0Then Begin
   Cnt:=0;
   For Al:=0To 3Do If(RawGet(C,aRTC+$18+Al)And $80)<>0Then Begin
    If Cnt>=0Then Inc(Cnt);
    If(RawGet(C,aRTC+$18+Al)And $7F)<>(RawGet(C,aRTC+$11+Al)And $7F)Then
     Cnt:=-100
   End;
   If Cnt>0Then SetBits(C,aRTC,2)
  End
 End;
 If Ev Then SetBits(C,aRTC,4)
End;

Procedure RtcAdvance(Var C:TCPU;Dt:Double);Begin
 If Not C.Dev.Rtc Then Exit;
 If(RawGet(C,aRTC+1)And $40)<>0Then Exit;
 C.RtcAcc:=C.RtcAcc+Dt;
 While C.RtcAcc>=1.0Do Begin
  C.RtcAcc:=C.RtcAcc-1.0;RtcTick(C)
 End
End;

Function RtcPending(Var C:TCPU):Boolean;Begin
 RtcPending:=C.Dev.Rtc And(((RawGet(C,aRTC)Shr 4)And RawGet(C,aRTC))<>0)
End;

Function RtcIv(Var C:TCPU):Word;
Var
 F:Byte;
Begin
 F:=RawGet(C,aRTC);RtcIv:=0;
 If(F And 8)<>0Then Begin
  RtcIv:=2;ClrBits(C,aRTC,8)
 End
 Else If(F And 1)<>0Then Begin
  RtcIv:=4;ClrBits(C,aRTC,1)
 End
 Else If(F And 4)<>0Then Begin
  RtcIv:=6;ClrBits(C,aRTC,4)
 End
 Else If(F And 2)<>0Then Begin
  RtcIv:=8;ClrBits(C,aRTC,2)
 End
End;

{ ------------------------------------------------------------------ }
{  Acces aux registres des peripheriques                             }
{ ------------------------------------------------------------------ }

Function PeriphRead(Var C:TCPU;A:LongInt):Byte;
Var
 V:Byte;
Begin
 V:=0;
 Case A Of
  aP1IN:V:=PinVal(C,1);
  aP2IN:V:=PinVal(C,2);
  aP3IN:V:=PinVal(C,3);
  aUA+5:V:=UsciStat(C,0);
  aUB+5:V:=UsciStat(C,1);
  aUA+6:V:=UsciReadRx(C,0);
  aUB+6:V:=UsciReadRx(C,1);
  aWDTCTL+1:V:=$69;
  aFCTL1+1,aFCTL2+1,aFCTL3+1:V:=$96;
  aTAIV:V:=Byte(TimerIv(C,C.TA,True));
  aTBIV:V:=Byte(TimerIv(C,C.TB,True));
  aDMAIV:V:=Byte(DmaIv(C));
  aRTC+$E:V:=Byte(RtcIv(C));
  Else V:=RawGet(C,A)
 End;
 PeriphRead:=V
End;

Procedure PeriphWrite(Var C:TCPU;A:LongInt;V:Byte);
Var
 Old,Pin,Ch:Byte;
 I:Integer;
Begin
 Case A Of
  aP1IN,aP2IN,aP3IN:;
  aP1OUT,aP1DIR,aP1REN:Begin
   RawPut(C,A,V);PortUpdate(C,1)
  End;
  aP2OUT,aP2DIR,aP2REN:Begin
   RawPut(C,A,V);PortUpdate(C,2)
  End;
  aP3OUT,aP3DIR,aP3REN:Begin
   RawPut(C,A,V);PortUpdate(C,3)
  End;
  aP1IES,aP2IES:Begin
   Old:=RawGet(C,A);RawPut(C,A,V);Ch:=Old Xor V;
   If A=aP1IES Then I:=1 Else I:=2;
   Pin:=PinVal(C,I);
   SetBits(C,A-1,Byte((Ch And V And Pin)Or(Ch And Not V And Not Pin)))
  End;
  aUA+7:UsciWriteTx(C,0,V);
  aUB+7:UsciWriteTx(C,1,V);
  aUA+6,aUB+6:;
  aUA+1:Begin
   RawPut(C,A,V);UsciCtl1Write(C,0)
  End;
  aUB+1:Begin
   RawPut(C,A,V);UsciCtl1Write(C,1)
  End;
  aWDTCTL,aWDTCTL+1:Begin
   DoPUC(C,False);Inc(C.Resets)
  End;
  aFCTL1,aFCTL2,aFCTL3:FctlWrite(C,A,V);
  aBCSCTL1,aBCSCTL2,aBCSCTL3,aDCOCTL:Begin
   RawPut(C,A,V);UpdateClocks(C)
  End;
  aCACTL1,aCACTL2:Begin
   RawPut(C,A,V);CompUpdate(C)
  End;
  aDMAIV,aDMAIV+1:;
  aTAIV,aTAIV+1,aTBIV,aTBIV+1:;
  Else Begin
   If(A>=aMPY)And(A<=aOP2+1)Then Begin
    RawPut(C,A,V);MpyWrite(C,A,True)
   End
   Else If(A>=aTA)And(A<=aTA+$17)Then Begin
    RawPut(C,A,V);TimerWriteHook(C,C.TA,A)
   End
   Else If(A>=aTB)And(A<=aTB+$17)Then Begin
    I:=(A-aTB-$12)Shr 1;
    If(A>=aTB+$12)And(I<=2)And(((RawGetW(C,aTB+2+2*I)Shr 9)And 3)<>0)And
     ((RawGetW(C,aTB+2+2*I)And $100)=0)Then Begin
     If(A And 1)=0Then C.TB.Latch[I]:=(C.TB.Latch[I]And $FF00)Or V
      Else C.TB.Latch[I]:=(C.TB.Latch[I]And $FF)Or(Word(V)Shl 8);
     C.TB.Pend[I]:=True
    End
     Else
    Begin
     RawPut(C,A,V);TimerWriteHook(C,C.TB,A)
    End
   End
   Else RawPut(C,A,V)
  End
 End
End;

{ Ecritures de mots necessitant l'acces simultane aux deux octets }
Function PeriphWriteW(Var C:TCPU;A:LongInt;V:Word):Boolean;Begin
 PeriphWriteW:=True;
 Case A Of
  aWDTCTL:Begin
   If(V Shr 8)<>$5AThen Begin
    DoPUC(C,False);Inc(C.Resets)
   End
    Else
   Begin
    If(V And 8)<>0Then Begin
     C.WdtCnt:=0;C.WdtAcc:=0
    End;
    RawPut(C,A,V And $F7)
   End
  End;
  aFCTL1,aFCTL2,aFCTL3:FctlWrite(C,A,V);
  aMPY,aMPYS,aMAC,aMACS,aOP2:Begin
   RawPutW(C,A,V);MpyWrite(C,A,False)
  End;
  aADCCTL0:Begin
   RawPutW(C,A,V And $FFFB Or(RawGetW(C,A)And 4));AdcCtl0Hook(C)
  End;
  aADCCTL1:RawPutW(C,A,(V And $FFFE)Or(RawGetW(C,A)And 1));
  Else PeriphWriteW:=False
 End
End;

{ ------------------------------------------------------------------ }
{  Interruptions, temps et boucle d'execution                        }
{ ------------------------------------------------------------------ }

Function NmiPending(Var C:TCPU):Boolean;
Var
 Ie,If1:Byte;
Begin
 Ie:=RawGet(C,aIE1);If1:=RawGet(C,aIFG1);
 NmiPending:=((Ie And If1 And $12)<>0)Or
  (((Ie And $20)<>0)And((RawGet(C,aFCTL3)And 4)<>0))
End;

{ Retourne l'adresse du vecteur de l'interruption masquable la plus
  prioritaire en attente (0 si aucune) }
Function PendingVector(Var C:TCPU):LongInt;
Var
 Ie2,If2:Byte;
Begin
 PendingVector:=0;
 Ie2:=RawGet(C,aIE2);If2:=RawGet(C,aIFG2);
 If((RawGet(C,aCACTL1)And $0B)=$0B)Then PendingVector:=vCOMP
 Else If((RawGet(C,aIE1)And RawGet(C,aIFG1)And 1)<>0)And
  ((RawGet(C,aWDTCTL)And $10)<>0)Then PendingVector:=vWDT
 Else If TimerPend0(C,C.TA)Then PendingVector:=vTA0
 Else If TimerIv(C,C.TA,False)<>0Then PendingVector:=vTA1
 Else If((Ie2 And If2 And $05)<>0)Or((RawGet(C,aUB+5)And RawGet(C,aUB+4)And
  $0F)<>0)And IsI2C(C,1)Then PendingVector:=vRX
 Else If(Ie2 And If2 And $0A)<>0Then PendingVector:=vTX
 Else If(RawGetW(C,aADCCTL0)And $0C)=$0C Then PendingVector:=vADC
 Else If DmaPending(C)Then PendingVector:=vDMA
 Else If(RawGet(C,aP2IFG)And RawGet(C,aP2IE))<>0Then PendingVector:=vP2
 Else If(RawGet(C,aP1IFG)And RawGet(C,aP1IE))<>0Then PendingVector:=vP1
 Else If TimerPend0(C,C.TB)Then PendingVector:=vTB0
 Else If TimerIv(C,C.TB,False)<>0Then PendingVector:=vTB1
 Else If RtcPending(C)Then PendingVector:=vRTC
End;

Procedure ServiceInterrupt(Var C:TCPU;Vec:LongInt;IsNmi:Boolean);Begin
 Push(C,Word(C.R[0]And $FFFF));
 If C.Dev.X Then Push(C,Word((C.R[2]And $0FFF)Or(((C.R[0]Shr 16)And 15)Shl 12)))
  Else Push(C,Word(C.R[2]));
 C.R[2]:=0;C.R[0]:=ReadWord(C,Vec)And PcMask(C);
 If IsNmi Then ClrBits(C,aIE1,$32)
 Else Case Vec Of
  vTA0:ClrBits(C,aTA+2,1);
  vTB0:ClrBits(C,aTB+2,1);
  vWDT:ClrBits(C,aIFG1,1);
  vADC:ClrBits(C,aADCCTL0,4);
  vCOMP:ClrBits(C,aCACTL1,1)
 End;
 Inc(C.Cycles,6);Inc(C.Count)
End;

{ Vrai si une source d'interruption ou de reinitialisation peut encore
  se produire (utilise pour detecter les boucles mortes) }
Function Armed(Var C:TCPU;NeedGie:Boolean):Boolean;
Var
 Gie,A:Boolean;
 Ctl:Word;
 Ie1,Ie2:Byte;
 I:Integer;
 Function TimerArmed(Const Tm:TTimer):Boolean;
 Var
  Cl:Word;
  F:LongInt;
 Begin
  Cl:=RawGetW(C,Tm.Base);TimerArmed:=False;
  If((Cl Shr 4)And 3)=0Then Exit;
  Case(Cl Shr 8)And 3 Of
   1:F:=C.FAclk;
   2:F:=C.FSmclk;
   Else F:=0
  End;
  If F=0Then Exit;
  TimerArmed:=((Cl And 2)<>0)Or((RawGet(C,Tm.Base+2)And $10)<>0)Or
   ((RawGet(C,Tm.Base+4)And $10)<>0)Or((RawGet(C,Tm.Base+6)And $10)<>0)
 End;
Begin
 Gie:=(C.R[2]And FlagGIE)<>0;
 Ie1:=RawGet(C,aIE1);Ie2:=RawGet(C,aIE2);Ctl:=RawGet(C,aWDTCTL);
 { reinitialisation par le chien de garde }
 If((Ctl And $80)=0)And((Ctl And $10)=0)And((C.FSmclk>0)Or(C.FAclk>0))Then
 Begin
  Armed:=True;Exit
 End;
 If(C.EvPos<=C.NEv)And(((Ctl And $20)<>0)Or((Ie1 And $10)<>0))Then Begin
  Armed:=True;Exit
 End;
 Armed:=False;
 If NeedGie And Not Gie Then Exit;
 A:=TimerArmed(C.TA)Or TimerArmed(C.TB);
 If((Ctl And $80)=0)And((Ctl And $10)<>0)And((Ie1 And 1)<>0)Then A:=True;
 If(C.U[0].Busy Or C.U[0].RxBusy Or(C.InputPos<=Length(C.Input)))And
  ((Ie2 And 3)<>0)Then A:=True;
 If(C.U[1].Busy Or C.U[1].RxBusy)And((Ie2 And $0C)<>0)Then A:=True;
 If C.AdcBusy And((RawGetW(C,aADCCTL0)And 8)<>0)Then A:=True;
 If C.Dev.Rtc And((RawGet(C,aRTC+1)And $40)=0)And((RawGet(C,aRTC)And $F0)<>0)
 Then A:=True;
 If C.EvPos<=C.NEv Then Begin
  If(RawGet(C,aP1IE)Or RawGet(C,aP2IE))<>0Then A:=True;
  If(RawGet(C,aCACTL1)And 2)<>0Then A:=True;
  For I:=0To 2Do If(RawGet(C,aDMA0+8*I)And $14)=$14Then A:=True
 End;
 For I:=0To 2Do If(RawGet(C,aDMA0+8*I)And $10)<>0Then A:=True;
 Armed:=A
End;

{ Avance le temps simule de Dt secondes et met a jour les peripheriques }
Procedure AdvanceTime(Var C:TCPU;Dt:Double);Begin
 C.Now:=C.Now+Dt;
 UpdateClocks(C);
 If C.EvPos<=C.NEv Then ApplyEvents(C);
 TimerAdvance(C,C.TA,Dt);TimerAdvance(C,C.TB,Dt);
 WdtAdvance(C,Dt);
 UsciAdvance(C,0,Dt);UsciAdvance(C,1,Dt);
 AdcAdvance(C,Dt);
 CompUpdate(C);
 RtcAdvance(C,Dt);
 DmaPoll(C)
End;

Procedure TraceLine(Var C:TCPU;PC:LongInt;W:Word);
Var
 J:Integer;
Begin
 Write(Hex5(PC),' ',Hex4(W),' SP=',Hex4(C.R[1]),' SR=',Hex4(C.R[2]),' ');
 If(C.R[2]And FlagV)<>0Then Write('V')Else Write('-');
 If(C.R[2]And FlagN)<>0Then Write('N')Else Write('-');
 If(C.R[2]And FlagZ)<>0Then Write('Z')Else Write('-');
 If(C.R[2]And FlagC)<>0Then Write('C')Else Write('-');
 For J:=4To 15Do Write(' R',J,'=',Hex4(C.R[J]));
 WriteLn
End;

{ Execute une instruction et fait avancer le temps }
Procedure Step(Var C:TCPU);
Var
 Start:LongInt;
 Before:LongInt;
 W:Word;
Begin
 Start:=C.R[0];Before:=C.Cycles;
 W:=RawGetW(C,Start);
 ExecOne(C);
 If C.Stopped And(C.Reason=StopIllegal)Then Begin
  C.FaultPC:=Start;C.R[0]:=Start
 End
  Else
 If Not C.Stopped Then Begin
  Inc(C.Count);
  AdvanceTime(C,(C.Cycles-Before)/C.FMclk);
  If C.Trace Then TraceLine(C,Start,W)
 End
End;

{ Laisse s'ecouler le temps pendant que le processeur dort }
Procedure SleepStep(Var C:TCPU);
Var
 Dt:Double;
Begin
 If C.FSmclk>0Then Dt:=1.0/C.FSmclk
 Else If C.FAclk>0Then Dt:=1.0/C.FAclk
 Else If C.EvPos<=C.NEv Then Dt:=C.Ev[C.EvPos].Time-C.Now+1E-9
 Else Dt:=0;
 If(C.FAclk>0)And(C.FSmclk>C.FAclk*8)And Not(
  ((RawGetW(C,aTA)Shr 8)And 3=2)Or((RawGetW(C,aTB)Shr 8)And 3=2)Or
  C.AdcBusy Or C.U[0].Busy Or C.U[1].Busy)Then Dt:=1.0/C.FAclk;
 If Dt<=0Then Begin
  StopCPU(C,StopSleep);Exit
 End;
 AdvanceTime(C,Dt)
End;

{ Attend la fin des trames UART en cours (affichage des caracteres) }
Procedure Drain(Var C:TCPU);
Var
 G:Integer;
Begin
 G:=0;
 While(C.U[0].Busy)And(G<64)Do Begin
  Inc(G);AdvanceTime(C,C.U[0].Remain+1E-12)
 End
End;

Function BpAt(Var C:TCPU;A:LongInt):Boolean;
Var
 J:Integer;
Begin
 BpAt:=False;
 For J:=1To C.NBp Do If C.Bp[J]=A Then BpAt:=True
End;

Procedure Run(Var C:TCPU;Limit:LongInt);
Var
 Vec:LongInt;
 First:Boolean;
Begin
 First:=True;
 While Not C.Stopped Do Begin
  If C.Count>=Limit Then StopCPU(C,StopLimit)
  Else If C.Now>C.MaxTime Then StopCPU(C,StopTime)
  Else If(C.NBp>0)And Not(First And C.SkipBreak)And BpAt(C,C.R[0])Then
   StopCPU(C,StopBreak)
  Else Begin
   First:=False;
   If NmiPending(C)Then ServiceInterrupt(C,vNMI,True)
   Else Begin
    Vec:=PendingVector(C);
    If((C.R[2]And FlagGIE)<>0)And(Vec<>0)Then ServiceInterrupt(C,Vec,False)
    Else If(C.R[2]And FlagCPUOFF)<>0Then Begin
     If Armed(C,True)Then SleepStep(C)
      Else Begin
       Drain(C);StopCPU(C,StopSleep)
      End
    End
     Else
    Begin
     Step(C)
    End
   End
  End;
  If Not C.Stopped Then Begin
   If C.WatchHit Then Begin
    C.WatchHit:=False;StopCPU(C,StopWatch)
   End
   Else If C.Resets>MaxResets Then StopCPU(C,StopReset)
   Else Begin
    { boucle morte: JMP $ sans reveil possible }
    If(RawGetW(C,C.R[0])=$3FFF)And(MemKind(C,C.R[0])<>MemPeriph)Then
     If Not Armed(C,True)Then Begin
      Drain(C);StopCPU(C,StopLoop)
     End
   End
  End
 End;
 C.SkipBreak:=False
End;

{ ------------------------------------------------------------------ }
{  Chargement de programmes et de symboles                           }
{ ------------------------------------------------------------------ }

Var
 LoadLo,LoadHi:LongInt;

Function FileThere(Const Name:String):Boolean;
Var
 SR:SearchRec;
Begin
 FindFirst(Name,AnyFile,SR);
 FileThere:=DosError=0
End;

Procedure NoteLoaded(A:LongInt);Begin
 If(LoadLo<0)Or(A<LoadLo)Then LoadLo:=A;
 If A>LoadHi Then LoadHi:=A
End;

Function LoadBin(Var C:TCPU;Const Name:String;Addr:LongInt):Boolean;
Var
 F:File;
 Buf:Array[0..511]Of Byte;
 Got:Word;
 J:Word;
 Total:LongInt;
Begin
 LoadBin:=False;
 If Not FileThere(Name)Then Begin
  WriteLn(T('Impossible d''ouvrir ','Cannot open ','Kann nicht oeffnen: ',
   'No se puede abrir ','Impossibile aprire '),Name);
  Exit
 End;
 Assign(F,Name);Reset(F,1);
 Total:=Addr;
 Repeat
  BlockRead(F,Buf,SizeOf(Buf),Got);
  J:=0;
  While J<Got Do Begin
   If Total>$FFFFFThen Begin
    WriteLn(T('Programme trop grand pour la memoire',
     'Program too large for the memory',
     'Programm zu gross fuer den Speicher',
     'Programa demasiado grande para la memoria',
     'Programma troppo grande per la memoria'));
    Close(F);Exit
   End;
   RawPut(C,Total,Buf[J]);Inc(Total);Inc(J)
  End
 Until Got=0;
 If Total>Addr Then Begin
  NoteLoaded(Addr);NoteLoaded(Total-1)
 End;
 Close(F);LoadBin:=True
End;

Function LoadHexFile(Var C:TCPU;Const Name:String):Boolean;
Var
 F:Text;
 L:String;
 N,Typ,J,Sum,Base,V:LongInt;
 Addr:LongInt;
 Line:Integer;
Function HexByte(P:Integer):LongInt;Begin
 HexByte:=HexValue(Copy(L,P,2))
End;
Begin
 LoadHexFile:=False;
 If Not FileThere(Name)Then Begin
  WriteLn(T('Impossible d''ouvrir ','Cannot open ','Kann nicht oeffnen: ',
   'No se puede abrir ','Impossibile aprire '),Name);
  Exit
 End;
 Assign(F,Name);Reset(F);
 Base:=0;Line:=0;
 While Not Eof(F)Do Begin
  ReadLn(F,L);Inc(Line);L:=Trim(L);
  If(L<>'')And(L[1]=':')Then Begin
   N:=HexByte(2);Typ:=HexByte(8);Addr:=(HexByte(4)Shl 8)Or HexByte(6);
   Sum:=0;
   For J:=0To N+4Do Sum:=Sum+HexByte(2+2*J);
   If(Sum And $FF)<>0Then Begin
    WriteLn(T('Somme de controle invalide, ligne ',
     'Invalid checksum, line ','Ungueltige Pruefsumme, Zeile ',
     'Suma de control invalida, linea ','Checksum non valida, riga '),Line);
    Close(F);Exit
   End;
   Case Typ Of
    0:For J:=0To N-1Do Begin
     V:=HexByte(10+2*J);RawPut(C,Base+Addr+J,Byte(V));NoteLoaded(Base+Addr+J)
    End;
    2:Base:=((HexByte(10)Shl 8)Or HexByte(12))Shl 4;
    4:Base:=((HexByte(10)Shl 8)Or HexByte(12))Shl 16;
    1:Break
   End
  End
 End;
 Close(F);LoadHexFile:=True
End;

Function LoadTiTxt(Var C:TCPU;Const Name:String):Boolean;
Var
 F:Text;
 L,Tok:String;
 A,V:LongInt;
 P:Integer;
Begin
 LoadTiTxt:=False;
 If Not FileThere(Name)Then Begin
  WriteLn(T('Impossible d''ouvrir ','Cannot open ','Kann nicht oeffnen: ',
   'No se puede abrir ','Impossibile aprire '),Name);
  Exit
 End;
 Assign(F,Name);Reset(F);
 A:=0;
 While Not Eof(F)Do Begin
  ReadLn(F,L);L:=Trim(L);
  If L<>''Then Begin
   If L[1]='@'Then A:=HexValue(Copy(L,2,10))
   Else If(L[1]='q')Or(L[1]='Q')Then Break
   Else Begin
    While L<>''Do Begin
     P:=Pos(' ',L);
     If P=0Then Begin
      Tok:=L;L:=''
     End
      Else
     Begin
      Tok:=Copy(L,1,P-1);L:=LTrim(Copy(L,P+1,255))
     End;
     V:=HexValue(Tok);
     If V>=0Then Begin
      RawPut(C,A,Byte(V));NoteLoaded(A);Inc(A)
     End
    End
   End
  End
 End;
 Close(F);LoadTiTxt:=True
End;

{ Fichier de symboles: "nom adresse", "nom=adresse", "adresse T nom" (nm) }
Function LoadSymbols(Const Name:String):Boolean;
Var
 F:Text;
 L,T1,T2,T3:String;
 A:LongInt;
 P:Integer;
Function NextTok(Var S:String):String;
Var
 K:Integer;
Begin
 S:=LTrim(S);K:=1;
 While(K<=Length(S))And Not(S[K]In[' ',#9,'='])Do Inc(K);
 NextTok:=Copy(S,1,K-1);S:=LTrim(Copy(S,K,255));
 If(S<>'')And(S[1]='=')Then S:=LTrim(Copy(S,2,255))
End;
Begin
 LoadSymbols:=False;
 If Not FileThere(Name)Then Exit;
 Assign(F,Name);Reset(F);
 While Not Eof(F)Do Begin
  ReadLn(F,L);P:=Pos(';',L);
  If P>0Then L:=Copy(L,1,P-1);
  T1:=NextTok(L);T2:=NextTok(L);T3:=NextTok(L);
  If Upper(T2)='EQU'Then Begin
   T2:=T3
  End;
  If(T3<>'')And(Length(T2)=1)And ParseAddr(T1,A)Then AddSymbol(T3,A)
  Else If(T1<>'')And(T2<>'')And ParseAddr(T2,A)Then AddSymbol(T1,A)
 End;
 Close(F);LoadSymbols:=True
End;

Function LoadProgram(Var C:TCPU;Const Name:String;Addr:LongInt):Boolean;
Var
 U:String;
 P:Integer;
Begin
 U:=Upper(Name);P:=Length(U);
 While(P>0)And(U[P]<>'.')Do Dec(P);
 U:=Copy(U,P,10);
 If(U='.HEX')Or(U='.IHX')Or(U='.A43')Or(U='.H43')Then
  LoadProgram:=LoadHexFile(C,Name)
 Else If(U='.TXT')Or(U='.TI')Then LoadProgram:=LoadTiTxt(C,Name)
 Else LoadProgram:=LoadBin(C,Name,Addr)
End;

{ ------------------------------------------------------------------ }
{  Desassembleur                                                     }
{ ------------------------------------------------------------------ }

Type
 TDOp=Record
  Txt:String[40];
  Kind:Byte;       { 0=registre, 1=memoire, 2=constante }
  Num:LongInt;
  Mode:Byte
 End;

Var
 DisEmu:Boolean;

Function RegName(N:Integer):String;Begin
 Case N Of
  0:RegName:='PC';
  1:RegName:='SP';
  2:RegName:='SR';
  Else Begin
   If N<10Then RegName:='R'+Chr(48+N)Else RegName:='R1'+Chr(48+N-10)
  End
 End
End;

Function AddrText(A:LongInt;Wide:Boolean):String;
Var
 S:String;
Begin
 S:=SymName(A);
 If S<>''Then AddrText:=S
 Else If Wide Then AddrText:='0x'+Hex5(A)
 Else AddrText:='0x'+Hex4(Word(A))
End;

Function WordAt(Var C:TCPU;Var P:LongInt):Word;Begin
 WordAt:=RawGetW(C,P);P:=(P+2)And $FFFFF
End;

Function SignedText(V:LongInt):String;
Var
 S:String;
Begin
 Str(V,S);SignedText:=S
End;

{ Decode un operande; P pointe sur le prochain mot d'extension }
Procedure DisOperand(Var C:TCPU;Mode,Reg,Sz:Integer;IsSrc:Boolean;
                     Hi:LongInt;Ex:Boolean;Var P:LongInt;Var O:TDOp);
Var
 X:Word;
 ExtAddr,Off,V:LongInt;
 Wide:Boolean;
Begin
 O.Kind:=0;O.Num:=Reg;O.Mode:=Mode;Wide:=Ex;
 If IsSrc Then Begin
  If Reg=3Then Begin
   O.Kind:=2;
   Case Mode Of
    0:O.Num:=0;
    1:O.Num:=1;
    2:O.Num:=2;
    Else O.Num:=-1
   End;
   O.Txt:='#'+SignedText(O.Num);Exit
  End;
  If(Reg=2)And(Mode>=2)Then Begin
   O.Kind:=2;
   If Mode=2Then O.Num:=4 Else O.Num:=8;
   O.Txt:='#'+SignedText(O.Num);Exit
  End
 End;
 Case Mode Of
  0:O.Txt:=RegName(Reg);
  1:Begin
   ExtAddr:=P;X:=WordAt(C,P);Off:=LongInt(X)Or Hi;O.Kind:=1;
   If Reg=2Then Begin
    O.Num:=Off;O.Txt:='&'+AddrText(Off And $FFFFF,Wide)
   End
   Else If Reg=0Then Begin
    O.Num:=(ExtAddr+Off)And $FFFFF;O.Txt:=AddrText(O.Num,Wide)
   End
   Else Begin
    If Wide Then O.Txt:='0x'+Hex5(Off)+'('+RegName(Reg)+')'
     Else O.Txt:='0x'+Hex4(X)+'('+RegName(Reg)+')'
   End
  End;
  2:Begin
   O.Kind:=1;O.Txt:='@'+RegName(Reg)
  End;
  Else Begin
   If Reg=0Then Begin
    X:=WordAt(C,P);V:=LongInt(X)Or Hi;O.Kind:=2;O.Num:=V;
    If Sz=1Then V:=V And $FF
    Else If Sz=0Then V:=V And $FFFF;
    O.Num:=V;
    If SymName(V)<>''Then O.Txt:='#'+SymName(V)
    Else If Sz=1Then O.Txt:='#0x'+Hex2(Byte(V))
    Else If Wide Then O.Txt:='#0x'+Hex5(V)
    Else O.Txt:='#0x'+Hex4(Word(V))
   End
    Else
   Begin
    O.Kind:=1;O.Txt:='@'+RegName(Reg)+'+'
   End
  End
 End
End;

Function JumpName(Cond:Integer):String;Begin
 Case Cond Of
  0:JumpName:='JNE';
  1:JumpName:='JEQ';
  2:JumpName:='JNC';
  3:JumpName:='JC';
  4:JumpName:='JN';
  5:JumpName:='JGE';
  6:JumpName:='JL';
  Else JumpName:='JMP'
 End
End;

Function Suffix(Sz:Integer;Ex:Boolean):String;Begin
 If Ex Then Begin
  Case Sz Of
   1:Suffix:='X.B';
   2:Suffix:='X.A';
   Else Suffix:='X.W'
  End
 End
  Else If Sz=1Then Suffix:='.B'
  Else Suffix:=''
End;

{ Mnemoniques emules (instructions synthetiques) }
Function EmuName(Opc:Integer;Const S,D:TDOp;As,Ad:Integer;
                 Var NoSrc:Boolean):String;
Var
 Sv:LongInt;
Begin
 EmuName:='';NoSrc:=True;
 Sv:=S.Num;
 Case Opc Of
  4:Begin
   If(S.Kind=2)And(Sv=0)And(D.Kind=0)And(D.Num=3)Then EmuName:='NOP'
   Else If(As=3)And(S.Kind=1)And(S.Txt='@SP+')And(D.Kind=0)Then Begin
    If D.Num=0Then EmuName:='RET'Else EmuName:='POP'
   End
   Else If(Ad=0)And(D.Kind=0)And(D.Num=0)Then Begin
    EmuName:='BR';NoSrc:=False
   End
   Else If(S.Kind=2)And(Sv=0)Then EmuName:='CLR'
  End;
  5:Begin
   If(S.Kind=2)And(Sv=1)Then EmuName:='INC'
   Else If(S.Kind=2)And(Sv=2)Then EmuName:='INCD'
   Else If(S.Kind=0)And(D.Kind=0)And(S.Num=D.Num)Then EmuName:='RLA'
  End;
  6:Begin
   If(S.Kind=2)And(Sv=0)Then EmuName:='ADC'
   Else If(S.Kind=0)And(D.Kind=0)And(S.Num=D.Num)Then EmuName:='RLC'
  End;
  7:If(S.Kind=2)And(Sv=0)Then EmuName:='SBC';
  8:Begin
   If(S.Kind=2)And(Sv=1)Then EmuName:='DEC'
   Else If(S.Kind=2)And(Sv=2)Then EmuName:='DECD'
  End;
  9:If(S.Kind=2)And(Sv=0)Then EmuName:='TST';
  12,13:If(D.Kind=0)And(D.Num=2)And(S.Kind=2)Then Begin
   Case Sv Of
    1:If Opc=12Then EmuName:='CLRC'Else EmuName:='SETC';
    2:If Opc=12Then EmuName:='CLRZ'Else EmuName:='SETZ';
    4:If Opc=12Then EmuName:='CLRN'Else EmuName:='SETN';
    8:If Opc=12Then EmuName:='DINT'Else EmuName:='EINT'
   End
  End;
  14:If(S.Kind=2)And((Sv=-1)Or(Sv=$FFFF)Or(Sv=$FF))Then EmuName:='INV'
 End
End;

{ Desassemble l'instruction a l'adresse A; Len = longueur en octets }
Function Disasm(Var C:TCPU;A:LongInt;Var Len:Integer):String;
Const
 F1:Array[4..15]Of String[5]=('MOV','ADD','ADDC','SUBC','SUB','CMP','DADD',
  'BIT','BIC','BIS','XOR','AND');
 F2:Array[0..5]Of String[5]=('RRC','SWPB','RRA','SXT','PUSH','CALL');
Var
 P:LongInt;
 W,ExtW:Word;
 Ex,Fmt1,Fmt2,Form,BW,AL,NoSrc:Boolean;
 Sz,As,Ad,Opc,SReg,DReg,N,Cond,Off,Src,Op,Dst,Cnt:Integer;
 SHi,DHi,Target:LongInt;
 S,D:TDOp;
 Nm,Res,Pre:String;
 X:Word;
Begin
 P:=A And $FFFFF;W:=WordAt(C,P);Ex:=False;ExtW:=0;Pre:='';
 If(W Shr 11)=3Then Begin
  If Not C.Dev.X Then Begin
   Len:=2;Disasm:='DW 0x'+Hex4(W);Exit
  End;
  ExtW:=W;Ex:=True;W:=WordAt(C,P)
 End;
 Fmt1:=(W Shr 12)>=4;Fmt2:=(W Shr 10)=4;
 If C.Dev.X And Not Ex And((W Shr 8)=$13)And(W>=$1340)Then Fmt2:=False;
 If Not Fmt1 And Not Fmt2 Then Begin
  Case W Shr 12 Of
   0:If C.Dev.X And Not Ex Then Begin
    Src:=(W Shr 8)And 15;Op:=(W Shr 4)And 15;Dst:=W And 15;
    Case Op Of
     0:Res:='MOVA @'+RegName(Src)+','+RegName(Dst);
     1:Res:='MOVA @'+RegName(Src)+'+,'+RegName(Dst);
     2:Begin
      X:=WordAt(C,P);
      Res:='MOVA &'+AddrText(LongInt(X)Or(LongInt(Src)Shl 16),True)+','+
       RegName(Dst)
     End;
     3:Begin
      X:=WordAt(C,P);Res:='MOVA 0x'+Hex4(X)+'('+RegName(Src)+'),'+RegName(Dst)
     End;
     4,5:Begin
      Cnt:=(Src Shr 2)+1;
      Case Src And 3 Of
       0:Nm:='RRCM';
       1:Nm:='RRAM';
       2:Nm:='RLAM';
       Else Nm:='RRUM'
      End;
      If Op=4Then Nm:=Nm+'.A'Else Nm:=Nm+'.W';
      Res:=Nm+' #'+SignedText(Cnt)+','+RegName(Dst)
     End;
     6:Begin
      X:=WordAt(C,P);
      Res:='MOVA '+RegName(Src)+',&'+AddrText(LongInt(X)Or(LongInt(Dst)Shl 16),
       True)
     End;
     7:Begin
      X:=WordAt(C,P);
      Res:='MOVA '+RegName(Src)+',0x'+Hex4(X)+'('+RegName(Dst)+')'
     End;
     8,9,10,11:Begin
      X:=WordAt(C,P);
      Case Op Of
       8:Nm:='MOVA';
       9:Nm:='CMPA';
       10:Nm:='ADDA';
       Else Nm:='SUBA'
      End;
      Res:=Nm+' #0x'+Hex5(LongInt(X)Or(LongInt(Src)Shl 16))+','+RegName(Dst)
     End;
     12,13,14,15:Begin
      Case Op Of
       12:Nm:='MOVA';
       13:Nm:='CMPA';
       14:Nm:='ADDA';
       Else Nm:='SUBA'
      End;
      Res:=Nm+' '+RegName(Src)+','+RegName(Dst)
     End
     Else Res:='DW 0x'+Hex4(W)
    End
   End
   Else Res:='DW 0x'+Hex4(W);
   1:If C.Dev.X And Not Ex And((W Shr 8)=$13)Then Begin
    Src:=(W Shr 4)And 15;Dst:=W And 15;
    Case Src Of
     4:Res:='CALLA '+RegName(Dst);
     5:Begin
      X:=WordAt(C,P);Res:='CALLA 0x'+Hex4(X)+'('+RegName(Dst)+')'
     End;
     6:Res:='CALLA @'+RegName(Dst);
     7:Res:='CALLA @'+RegName(Dst)+'+';
     8:Begin
      X:=WordAt(C,P);
      Res:='CALLA &'+AddrText(LongInt(X)Or(LongInt(Dst)Shl 16),True)
     End;
     9:Begin
      Off:=P;X:=WordAt(C,P);
      Res:='CALLA '+AddrText((Off+SignExt16(X))And $FFFFF,True)
     End;
     11:Begin
      X:=WordAt(C,P);
      Res:='CALLA #'+AddrText(LongInt(X)Or(LongInt(Dst)Shl 16),True)
     End;
     Else Res:='DW 0x'+Hex4(W)
    End
   End
   Else If C.Dev.X And Not Ex And((W Shr 10)=5)Then Begin
    N:=((W Shr 4)And 15)+1;Dst:=W And 15;
    If((W Shr 9)And 1)=0Then Nm:='PUSHM'Else Nm:='POPM';
    If(W And $100)=0Then Nm:=Nm+'.A'Else Nm:=Nm+'.W';
    If((W Shr 9)And 1)=0Then Res:=Nm+' #'+SignedText(N)+','+RegName(Dst)
     Else Res:=Nm+' #'+SignedText(N)+','+RegName(Dst+N-1)
   End
   Else Res:='DW 0x'+Hex4(W);
   Else Begin
    Cond:=(W Shr 10)And 7;Off:=W And $3FF;
    If Off>=512Then Off:=Off-1024;
    Target:=(P+2*Off)And $FFFFF;
    Res:=JumpName(Cond)+' '+AddrText(Target,C.Dev.X)
   End
  End;
  Len:=Integer((P-A)And $FFFFF);Disasm:=Res;Exit
 End;
 As:=(W Shr 4)And 3;Ad:=(W Shr 7)And 1;BW:=(W And $40)<>0;
 If Fmt1 Then Form:=(As=0)And(Ad=0)Else Form:=As=0;
 SHi:=0;DHi:=0;AL:=(ExtW And $40)<>0;N:=1;
 If Ex Then Begin
  If Form Then Begin
   If(ExtW And $100)<>0Then Pre:='ZC ';
   If(ExtW And $80)=0Then Begin
    If((ExtW And 15)<>0)Or((ExtW And $100)<>0)Then
     Pre:='RPT #'+SignedText((ExtW And 15)+1)+' { '+Pre
   End
    Else Pre:='RPT '+RegName(ExtW And 15)+' { '+Pre
  End
   Else
  Begin
   SHi:=LongInt((ExtW Shr 7)And 15)Shl 16;DHi:=LongInt(ExtW And 15)Shl 16
  End
 End;
 Sz:=0;
 If Not Ex Then Begin
  If BW Then Sz:=1
 End
  Else
 If AL Then Begin
  If BW Then Sz:=1
 End
  Else Sz:=2;
 If Fmt1 Then Begin
  Opc:=W Shr 12;SReg:=(W Shr 8)And 15;DReg:=W And 15;
  DisOperand(C,As,SReg,Sz,True,SHi,Ex,P,S);
  DisOperand(C,Ad,DReg,Sz,False,DHi,Ex,P,D);
  Nm:=EmuName(Opc,S,D,As,Ad,NoSrc);
  If(Nm<>'')And DisEmu And Not Ex And((Opc<>12)And(Opc<>13)Or Not BW)Then Begin
   If(Nm='NOP')Or(Nm='RET')Or(Nm='CLRC')Or(Nm='SETC')Or(Nm='CLRZ')Or
    (Nm='SETZ')Or(Nm='CLRN')Or(Nm='SETN')Or(Nm='DINT')Or(Nm='EINT')Then
    Res:=Nm
   Else If Nm='BR'Then Res:=Nm+' '+S.Txt
   Else Res:=Nm+Suffix(Sz,False)+' '+D.Txt
  End
   Else
  Res:=F1[Opc]+Suffix(Sz,Ex)+' '+S.Txt+','+D.Txt
 End
  Else
 Begin
  Opc:=(W Shr 7)And 7;DReg:=W And 15;
  If Opc=6Then Begin
   If(W<$1340)Or Not C.Dev.X Then Res:='RETI'Else Res:='DW 0x'+Hex4(W)
  End
  Else If BW And Not Ex And((Opc=1)Or(Opc=3)Or(Opc=5))Then
   Res:='DW 0x'+Hex4(W)
  Else If Opc=7Then Res:='DW 0x'+Hex4(W)
  Else Begin
   If Ex And((Opc=1)Or(Opc=3))Then Begin
    If AL Then Sz:=0 Else Sz:=2
   End;
   DisOperand(C,As,DReg,Sz,True,SHi,Ex,P,S);
   Res:=F2[Opc]+Suffix(Sz,Ex)+' '+S.Txt
  End
 End;
 Len:=Integer((P-A)And $FFFFF);Disasm:=Pre+Res
End;

{ Liste le code desassemble de Lo a Hi }
Procedure DisList(Var C:TCPU;Lo,Hi:LongInt);
Var
 A:LongInt;
 L,J:Integer;
 Txt,Bytes:String;
Begin
 A:=Lo;
 While A<=Hi Do Begin
  Txt:=Disasm(C,A,L);Bytes:='';
  For J:=0To L-1Do If J<8Then Bytes:=Bytes+Hex2(RawGet(C,A+J))+' ';
  While Length(Bytes)<25Do Bytes:=Bytes+' ';
  If SymName(A)<>''Then WriteLn(SymName(A),':');
  WriteLn(Hex5(A),': ',Bytes,Txt);
  A:=A+L
 End
End;

{ ------------------------------------------------------------------ }
{  Ligne de commande et programme principal                          }
{ ------------------------------------------------------------------ }

Procedure Monitor(Var C:TCPU);Forward;
Procedure SelfTest;Forward;

Var
 FileName,SymName2:String;
 LoadAddr,StartAddr,DumpFrom,DumpTo,DevNum:LongInt;
 Quiet,DoDump,DoMon,DoTest,AddrGiven,DoDis:Boolean;
 DisFrom,DisTo:LongInt;
 RegSet:Array[0..15]Of LongInt;
 TmpStr:String;
 K:Integer;

Procedure Usage;Begin
 WriteLn(T('MSP430 - Cet emulateur permet d''executer un programme MSP430.',
  'MSP430 - This emulator runs an MSP430 / MSP430X program.',
  'MSP430 - Dieser Emulator fuehrt ein MSP430-Programm aus.',
  'MSP430 - Este emulador ejecuta un programa MSP430.',
  'MSP430 - Questo emulatore esegue un programma MSP430.'));
 WriteLn;
 WriteLn(T('Syntaxe: MSP430 fichier[.BIN|.HEX|.TXT] [options]',
  'Syntax: MSP430 file[.BIN|.HEX|.TXT] [options]',
  'Syntax: MSP430 datei[.BIN|.HEX|.TXT] [optionen]',
  'Sintaxis: MSP430 fichero[.BIN|.HEX|.TXT] [opciones]',
  'Sintassi: MSP430 file[.BIN|.HEX|.TXT] [opzioni]'));
 WriteLn;
 WriteLn(T(' -D=modele  G2553 (defaut), G2231, F149 ou X (MSP430X 20 bits)',
  ' -D=model  G2553 (default), G2231, F149 or X (20-bit MSP430X)',
  ' -D=modell G2553 (Standard), G2231, F149 oder X (20-Bit MSP430X)',
  ' -D=modelo G2553 (defecto), G2231, F149 o X (MSP430X de 20 bits)',
  ' -D=modello G2553 (default), G2231, F149 o X (MSP430X a 20 bit)'));
 WriteLn(T(' -A=adr  adresse de chargement du .BIN en hexa (defaut: flash)',
  ' -A=adr  load address of the .BIN in hex (default: flash start)',
  ' -A=adr  Ladeadresse der .BIN in Hex (Standard: Flash-Anfang)',
  ' -A=dir  direccion de carga del .BIN en hexa (defecto: flash)',
  ' -A=ind  indirizzo di caricamento del .BIN in esa (default: flash)'));
 WriteLn(T(' -S=adr  adresse de depart (defaut: vecteur RESET)',
  ' -S=adr  start address (default: RESET vector)',
  ' -S=adr  Startadresse (Standard: RESET-Vektor)',
  ' -S=dir  direccion de inicio (defecto: vector RESET)',
  ' -S=ind  indirizzo di avvio (default: vettore RESET)'));
 WriteLn(T(' -N=nb   nombre maximal d''instructions (defaut 10000000)',
  ' -N=n    maximum number of instructions (default 10000000)',
  ' -N=n    maximale Anzahl Befehle (Standard 10000000)',
  ' -N=n    numero maximo de instrucciones (defecto 10000000)',
  ' -N=n    numero massimo di istruzioni (default 10000000)'));
 WriteLn(T(' -Y=sec  duree maximale simulee en secondes (defaut 600)',
  ' -Y=sec  maximum simulated time in seconds (default 600)',
  ' -Y=sek  maximale simulierte Zeit in Sekunden (Standard 600)',
  ' -Y=seg  tiempo simulado maximo en segundos (defecto 600)',
  ' -Y=sec  tempo simulato massimo in secondi (default 600)'));
 WriteLn(T(' -X=d-f  desassemble de d a f (hexa) et quitte; -F: generique',
  ' -X=f-t  disassemble from f to t (hex) and exit  -F: generic forms',
  ' -X=v-b  disassembliert von v bis b (Hex) und endet  -F: generisch',
  ' -X=d-h  desensambla de d a h (hexa) y sale  -F: formas genericas',
  ' -X=d-a  disassembla da d ad a (esa) ed esce  -F: forme generiche'));
 WriteLn(T(' -T      trace chaque instruction',
  ' -T      trace every instruction',
  ' -T      jeden Befehl protokollieren',
  ' -T      traza cada instruccion',
  ' -T      traccia ogni istruzione'));
 WriteLn(T(' -G      lance le moniteur interactif (debogueur)',
  ' -G      start the interactive monitor (debugger)',
  ' -G      interaktiven Monitor (Debugger) starten',
  ' -G      inicia el monitor interactivo (depurador)',
  ' -G      avvia il monitor interattivo (debugger)'));
 WriteLn(T(' -B=adr  point d''arret (repetable)  -W=d[-f][:r|w|rw] surveill.',
  ' -B=adr  breakpoint (repeatable)  -W=f[-t][:r|w|rw] watchpoint',
  ' -B=adr  Haltepunkt (wiederholbar)  -W=v[-b][:r|w|rw] Ueberwachung',
  ' -B=dir  punto de parada (repetible)  -W=d[-h][:r|w|rw] vigilancia',
  ' -B=ind  punto di arresto (ripetibile)  -W=d[-a][:r|w|rw] controllo'));
 WriteLn(T(' -L=fic  fichier de symboles (nom adresse, nom=adresse, nm)',
  ' -L=file symbol file (name addr, name=addr, nm output)',
  ' -L=dat  Symboldatei (Name Adr, Name=Adr, nm-Ausgabe)',
  ' -L=fic  fichero de simbolos (nombre dir, nombre=dir, nm)',
  ' -L=file file dei simboli (nome ind, nome=ind, nm)'));
 WriteLn(T(' -M=d-f  affiche la memoire de d a f (hexa) a la fin',
  ' -M=f-t  dump memory from f to t (hex) at the end',
  ' -M=v-b  Speicher von v bis b (Hex) am Ende ausgeben',
  ' -M=d-h  muestra la memoria de d a h (hexa) al final',
  ' -M=d-a  mostra la memoria da d ad a (esa) alla fine'));
 WriteLn(T(' -Rn=hh  valeur initiale du registre Rn (hexa), ex: -R4=1234',
  ' -Rn=hh  initial value of register Rn (hex), e.g. -R4=1234',
  ' -Rn=hh  Anfangswert des Registers Rn (Hex), z.B. -R4=1234',
  ' -Rn=hh  valor inicial del registro Rn (hexa), ej: -R4=1234',
  ' -Rn=hh  valore iniziale del registro Rn (esa), es: -R4=1234'));
 WriteLn(T(' -I=txt  texte recu par l''UART (UCA0RXBUF)',
  ' -I=txt  text received by the UART (UCA0RXBUF)',
  ' -I=txt  von der UART empfangener Text (UCA0RXBUF)',
  ' -I=txt  texto recibido por la UART (UCA0RXBUF)',
  ' -I=txt  testo ricevuto dalla UART (UCA0RXBUF)'));
 WriteLn(T(' -P=hh   valeur lue sur P1IN (hexa)',
  ' -P=hh   value read on P1IN (hex)',
  ' -P=hh   an P1IN gelesener Wert (Hex)',
  ' -P=hh   valor leido en P1IN (hexa)',
  ' -P=hh   valore letto su P1IN (esa)'));
 WriteLn(T(' -V=ca:mV  tension analogique sur le canal ca (ADC10/comparateur)',
  ' -V=ch:mV analog voltage on channel ch (ADC10/comparator)',
  ' -V=ka:mV Analogspannung am Kanal ka (ADC10/Komparator)',
  ' -V=ca:mV tension analogica en el canal ca (ADC10/comparador)',
  ' -V=ca:mV tensione analogica sul canale ca (ADC10/comparatore)'));
 WriteLn(T(' -E=us:type[:val] evenement externe a l''instant us (microsec.):',
  ' -E=us:type[:val] external event at time us (microseconds):',
  ' -E=us:typ[:wert] externes Ereignis zur Zeit us (Mikrosek.):',
  ' -E=us:tipo[:val] evento externo en el instante us (microseg.):',
  ' -E=us:tipo[:val] evento esterno al tempo us (microsecondi):'));
 WriteLn(T('        P1|P2|P3:hh  entree de port   An:mV  analogique',
  '        P1|P2|P3:hh  port input   An:mV  analog',
  '        P1|P2|P3:hh  Porteingang  An:mV  analog',
  '        P1|P2|P3:hh  entrada de puerto  An:mV  analogica',
  '        P1|P2|P3:hh  ingresso porta  An:mV  analogico'));
 WriteLn(T('        N  broche NMI   U:hh  octet UART   Cn:0|1  capture timer',
  '        N  NMI pin   U:hh  UART byte   Cn:0|1  timer capture input',
  '        N  NMI-Pin   U:hh  UART-Byte   Cn:0|1  Timer-Capture',
  '        N  pin NMI   U:hh  byte UART   Cn:0|1  captura del timer',
  '        N  pin NMI   U:hh  byte UART   Cn:0|1  cattura del timer'));
 WriteLn(T(' -J=hh   octet lu sur MISO en SPI (defaut FF)  -K=hh adresse I2C',
  ' -J=hh   byte read on MISO in SPI (default FF)  -K=hh I2C address',
  ' -J=hh   MISO-Byte im SPI (Standard FF)  -K=hh I2C-Adresse',
  ' -J=hh   byte leido en MISO en SPI (defecto FF)  -K=hh direccion I2C',
  ' -J=hh   byte letto su MISO in SPI (default FF)  -K=hh indirizzo I2C'));
 WriteLn(T('         du composant virtuel (EEPROM 256 o, defaut 50, 0=aucun)',
  '         of the virtual device (256-byte EEPROM, default 50, 0=none)',
  '         des virtuellen Bausteins (256-Byte-EEPROM, Std. 50, 0=keiner)',
  '         del dispositivo virtual (EEPROM de 256 bytes, defecto 50, 0=no)',
  '         del dispositivo virtuale (EEPROM 256 byte, default 50, 0=no)'));
 WriteLn(T(' -U      arret sur acces a une memoire inexistante',
  ' -U      stop on access to unmapped memory',
  ' -U      Stopp bei Zugriff auf nicht vorhandenen Speicher',
  ' -U      detener en acceso a memoria inexistente',
  ' -U      ferma su accesso a memoria inesistente'));
 WriteLn(T(' -Z=n    arret apres n reinitialisations (defaut 16)',
  ' -Z=n    stop after n resets (default 16)',
  ' -Z=n    Stopp nach n Resets (Standard 16)',
  ' -Z=n    detener tras n reinicios (defecto 16)',
  ' -Z=n    ferma dopo n reset (default 16)'));
 WriteLn(T(' -Q      pas de resume des registres a la fin',
  ' -Q      no register summary at the end',
  ' -Q      keine Registerzusammenfassung am Ende',
  ' -Q      sin resumen de registros al final',
  ' -Q      nessun riepilogo dei registri alla fine'));
 WriteLn(T(' --test  execute les auto-tests integres',
  ' --test  run the built-in self tests',
  ' --test  fuehrt die integrierten Selbsttests aus',
  ' --test  ejecuta las autopruebas integradas',
  ' --test  esegue gli autotest integrati'))
End;

Procedure ShowFlags(V:Word);Begin
 If(V And FlagV)<>0Then Write('V')Else Write('-');
 If(V And FlagN)<>0Then Write('N')Else Write('-');
 If(V And FlagZ)<>0Then Write('Z')Else Write('-');
 If(V And FlagC)<>0Then Write('C')Else Write('-');
 If(V And FlagGIE)<>0Then Write('I')Else Write('-');
 If(V And FlagCPUOFF)<>0Then Write('O')Else Write('-');
 If(V And FlagOSCOFF)<>0Then Write('X')Else Write('-');
 If(V And FlagSCG0)<>0Then Write('0')Else Write('-');
 If(V And FlagSCG1)<>0Then Write('1')Else Write('-')
End;

Procedure ShowReason(Var C:TCPU);Begin
 Case C.Reason Of
  StopLimit:WriteLn(T('Arret: limite d''instructions atteinte',
   'Stopped: instruction limit reached',
   'Angehalten: Befehlsgrenze erreicht',
   'Detenido: limite de instrucciones alcanzado',
   'Fermato: limite di istruzioni raggiunto'));
  StopTime:WriteLn(T('Arret: duree simulee maximale atteinte',
   'Stopped: maximum simulated time reached',
   'Angehalten: maximale simulierte Zeit erreicht',
   'Detenido: tiempo simulado maximo alcanzado',
   'Fermato: tempo simulato massimo raggiunto'));
  StopIllegal:WriteLn(T('Arret: instruction illegale ',
   'Stopped: illegal instruction ',
   'Angehalten: unzulaessiger Befehl ',
   'Detenido: instruccion ilegal ',
   'Fermato: istruzione illegale '),Hex4(C.Fault),' @',Hex5(C.FaultPC));
  StopLoop:WriteLn(T('Arret: boucle infinie detectee (JMP $)',
   'Stopped: endless loop detected (JMP $)',
   'Angehalten: Endlosschleife erkannt (JMP $)',
   'Detenido: bucle infinito detectado (JMP $)',
   'Fermato: ciclo infinito rilevato (JMP $)'));
  StopSleep:WriteLn(T('Arret: mode basse consommation sans reveil possible',
   'Stopped: low power mode with no possible wake-up',
   'Angehalten: Energiesparmodus ohne Aufwecken',
   'Detenido: modo de bajo consumo sin posible despertar',
   'Fermato: modalita a basso consumo senza risveglio'));
  StopBreak:WriteLn(T('Arret: point d''arret @','Stopped: breakpoint @',
   'Angehalten: Haltepunkt @','Detenido: punto de parada @',
   'Fermato: punto di arresto @'),Hex5(C.R[0]));
  StopWatch:WriteLn(T('Arret: surveillance memoire @',
   'Stopped: memory watchpoint @','Angehalten: Speicherueberwachung @',
   'Detenido: vigilancia de memoria @','Fermato: controllo memoria @'),
   Hex5(C.WatchAddr));
  StopFetch:WriteLn(T('Arret: execution hors memoire @',
   'Stopped: execution outside memory @',
   'Angehalten: Ausfuehrung ausserhalb des Speichers @',
   'Detenido: ejecucion fuera de memoria @',
   'Fermato: esecuzione fuori dalla memoria @'),Hex5(C.Fault));
  StopUnmapped:WriteLn(T('Arret: acces a une memoire inexistante @',
   'Stopped: access to unmapped memory @',
   'Angehalten: Zugriff auf nicht vorhandenen Speicher @',
   'Detenido: acceso a memoria inexistente @',
   'Fermato: accesso a memoria inesistente @'),Hex4(C.Fault));
  StopReset:WriteLn(T('Arret: trop de reinitialisations',
   'Stopped: too many resets','Angehalten: zu viele Resets',
   'Detenido: demasiados reinicios','Fermato: troppi reset'))
 End
End;

Procedure ShowSummary(Var C:TCPU;Short:Boolean);
Var
 J:Integer;
Begin
 WriteLn;ShowReason(C);
 If Short Then Exit;
 WriteLn(T('Instructions: ','Instructions: ','Befehle: ',
  'Instrucciones: ','Istruzioni: '),C.Count,'  ',
  T('Cycles: ','Cycles: ','Zyklen: ','Ciclos: ','Cicli: '),C.Cycles,'  ',
  T('Temps: ','Time: ','Zeit: ','Tiempo: ','Tempo: '),C.Now*1000:0:6,' ms');
 Write('PC=',Hex5(C.R[0]),' SP=',Hex5(C.R[1]),' SR=',Hex4(C.R[2]),' [');
 ShowFlags(C.R[2]);WriteLn(']  MCLK=',C.FMclk,' SMCLK=',C.FSmclk,
  ' ACLK=',C.FAclk,' Hz');
 For J:=4To 15Do Begin
  Write('R',J,'=':Ord(J<10)+1,Hex5(C.R[J]));
  If(J And 3)=3Then WriteLn Else Write('  ')
 End;
 WriteLn('P1OUT=',Hex2(RawGet(C,aP1OUT)),' P1DIR=',Hex2(RawGet(C,aP1DIR)),
  ' P2OUT=',Hex2(RawGet(C,aP2OUT)),' P2DIR=',Hex2(RawGet(C,aP2DIR)),
  ' P3OUT=',Hex2(RawGet(C,aP3OUT)),' P3DIR=',Hex2(RawGet(C,aP3DIR)));
 If C.Resets>0Then WriteLn(T('Reinitialisations: ','Resets: ','Resets: ',
  'Reinicios: ','Reset: '),C.Resets);
 If C.Unmapped>0Then WriteLn(T('Acces memoire inexistante: ',
  'Unmapped accesses: ','Zugriffe auf fehlenden Speicher: ',
  'Accesos a memoria inexistente: ','Accessi a memoria inesistente: '),
  C.Unmapped)
End;

Procedure DumpMemory(Var C:TCPU;First,Last:LongInt);
Var
 A,J:LongInt;
 B:Byte;
Begin
 A:=First And Not 15;
 While A<=Last Do Begin
  Write(Hex5(A),': ');
  For J:=0To 15Do Write(Hex2(RawGet(C,A+J)),' ');
  Write(' ');
  For J:=0To 15Do Begin
   B:=RawGet(C,A+J);
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

{ Convertit "us:type[:val]" en evenement }
Procedure ParseEvent(Var C:TCPU;Const S:String);
Var
 P1,P2:Integer;
 Us,Kind,Rest:String;
 Tm:Double;
 V,N:LongInt;
Begin
 P1:=Pos(':',S);
 If P1=0Then BadOption('-E='+S);
 Us:=Copy(S,1,P1-1);Rest:=Copy(S,P1+1,255);N:=DecValue(Us);
 If N<0Then BadOption('-E='+S);
 Tm:=N/1000000.0;
 P2:=Pos(':',Rest);V:=0;
 If P2>0Then Begin
  Kind:=Upper(Copy(Rest,1,P2-1));Rest:=Copy(Rest,P2+1,255)
 End
  Else
 Begin
  Kind:=Upper(Rest);Rest:=''
 End;
 If(Kind='P1')Or(Kind='P2')Or(Kind='P3')Then Begin
  V:=HexValue(Rest);
  If V<0Then BadOption('-E='+S);
  AddEvent(C,Tm,'P',Ord(Kind[2])-48,V)
 End
 Else If Kind='N'Then AddEvent(C,Tm,'N',0,0)
 Else If Kind='U'Then Begin
  V:=HexValue(Rest);
  If V<0Then BadOption('-E='+S);
  AddEvent(C,Tm,'U',0,V)
 End
 Else If(Length(Kind)>=2)And(Kind[1]='A')Then Begin
  N:=DecValue(Copy(Kind,2,5));V:=DecValue(Rest);
  If(N<0)Or(V<0)Then BadOption('-E='+S);
  AddEvent(C,Tm,'A',N,V)
 End
 Else If(Length(Kind)>=2)And(Kind[1]='C')Then Begin
  N:=DecValue(Copy(Kind,2,5));V:=DecValue(Rest);
  If(N<0)Or(V<0)Then BadOption('-E='+S);
  AddEvent(C,Tm,'C',N,V)
 End
 Else BadOption('-E='+S)
End;

Procedure AddWatch(Var C:TCPU;Const S:String);
Var
 P:Integer;
 Spec,Mode:String;
 Lo,Hi:LongInt;
Begin
 P:=Pos(':',S);Mode:='RW';Spec:=S;
 If P>0Then Begin
  Mode:=Upper(Copy(S,P+1,5));Spec:=Copy(S,1,P-1)
 End;
 P:=Pos('-',Spec);
 If P>0Then Begin
  If Not ParseAddr(Copy(Spec,1,P-1),Lo)Then BadOption('-W='+S);
  If Not ParseAddr(Copy(Spec,P+1,20),Hi)Then BadOption('-W='+S)
 End
  Else
 Begin
  If Not ParseAddr(Spec,Lo)Then BadOption('-W='+S);
  Hi:=Lo
 End;
 If C.NWp<MaxWatch Then Begin
  Inc(C.NWp);C.Wp[C.NWp].Lo:=Lo;C.Wp[C.NWp].Hi:=Hi;
  If Mode='R'Then C.Wp[C.NWp].Mode:=1
  Else If Mode='W'Then C.Wp[C.NWp].Mode:=2
  Else C.Wp[C.NWp].Mode:=3
 End
End;

Procedure ParseCommandLine(Var C:TCPU);
Var
 J,P:Integer;
 A,U:String;
 V,V2:LongInt;
 Code:Integer;
Begin
 FileName:='';LoadAddr:=-1;StartAddr:=-1;MaxInstr:=10000000;MaxResets:=16;
 Quiet:=False;DoDump:=False;DoMon:=False;DoTest:=False;DevNum:=1;DoDis:=False;
 SymName2:='';
 For J:=1To 15Do RegSet[J]:=-1;
 RegSet[0]:=-1;
 { 1ere passe: modele de composant }
 For J:=1To ParamCount Do Begin
  A:=ParamStr(J);U:=Upper(A);
  If Copy(U,1,3)='-D='Then Begin
   DevNum:=DeviceNumber(Copy(A,4,20));
   If DevNum=0Then BadOption(A)
  End
 End;
 SetDevice(C.Dev,DevNum);
 For J:=1To ParamCount Do Begin
  A:=ParamStr(J);U:=Upper(A);
  If(A='/?')Or(U='-H')Or(U='--HELP')Then Begin
   Usage;Halt
  End
  Else If U='--TEST'Then DoTest:=True
  Else If Copy(U,1,3)='-D='Then
  Else If U='-T'Then C.Trace:=True
  Else If U='-Q'Then Quiet:=True
  Else If U='-G'Then DoMon:=True
  Else If U='-F'Then DisEmu:=False
  Else If Copy(U,1,3)='-X='Then Begin
   P:=Pos('-',Copy(A,4,255));
   If P=0Then BadOption(A);
   If Not ParseAddr(Copy(A,4,P-1),DisFrom)Then BadOption(A);
   If Not ParseAddr(Copy(A,4+P,255),DisTo)Then BadOption(A);
   DoDis:=True
  End
  Else If U='-U'Then C.Strict:=True
  Else If Copy(U,1,3)='-A='Then Begin
   If Not ParseAddr(Copy(A,4,255),LoadAddr)Then BadOption(A)
  End
  Else If Copy(U,1,3)='-S='Then Begin
   If Not ParseAddr(Copy(A,4,255),StartAddr)Then BadOption(A)
  End
  Else If Copy(U,1,3)='-N='Then Begin
   V:=DecValue(Copy(A,4,255));
   If V<1Then BadOption(A);
   MaxInstr:=V
  End
  Else If Copy(U,1,3)='-Y='Then Begin
   Val(Copy(A,4,255),V2,Code);
   If(Code<>0)Or(V2<1)Then BadOption(A);
   C.MaxTime:=V2
  End
  Else If Copy(U,1,3)='-Z='Then Begin
   V:=DecValue(Copy(A,4,255));
   If V<0Then BadOption(A);
   MaxResets:=V
  End
  Else If Copy(U,1,3)='-P='Then Begin
   V:=HexValue(Copy(A,4,255));
   If(V<0)Or(V>255)Then BadOption(A);
   C.PVal[1]:=Byte(V);C.PDrv[1]:=$FF
  End
  Else If Copy(U,1,3)='-J='Then Begin
   V:=HexValue(Copy(A,4,255));
   If(V<0)Or(V>255)Then BadOption(A);
   C.MisoByte:=Byte(V)
  End
  Else If Copy(U,1,3)='-K='Then Begin
   V:=HexValue(Copy(A,4,255));
   If(V<0)Or(V>127)Then BadOption(A);
   C.I2cDev:=Byte(V)
  End
  Else If Copy(U,1,3)='-I='Then C.Input:=Copy(A,4,250)
  Else If Copy(U,1,3)='-L='Then SymName2:=Copy(A,4,255)
  Else If Copy(U,1,3)='-E='Then ParseEvent(C,Copy(A,4,255))
  Else If Copy(U,1,3)='-W='Then AddWatch(C,Copy(A,4,255))
  Else If Copy(U,1,3)='-B='Then Begin
   If Not ParseAddr(Copy(A,4,255),V)Then BadOption(A);
   If C.NBp<MaxBreak Then Begin
    Inc(C.NBp);C.Bp[C.NBp]:=V
   End
  End
  Else If Copy(U,1,3)='-V='Then Begin
   P:=Pos(':',A);
   If P=0Then BadOption(A);
   V:=DecValue(Copy(A,4,P-4));V2:=DecValue(Copy(A,P+1,10));
   If(V<0)Or(V>15)Or(V2<0)Then BadOption(A);
   C.Analog[V]:=V2
  End
  Else If Copy(U,1,3)='-M='Then Begin
   P:=Pos('-',Copy(A,4,255));
   If P=0Then BadOption(A);
   V:=HexValue(Copy(A,4,P-1));V2:=HexValue(Copy(A,4+P,255));
   If(V<0)Or(V2<V)Then BadOption(A);
   DumpFrom:=V;DumpTo:=V2;DoDump:=True
  End
  Else If(Copy(U,1,2)='-R')And(Pos('=',U)>3)Then Begin
   V:=DecValue(Copy(A,3,Pos('=',A)-3));
   V2:=HexValue(Copy(A,Pos('=',A)+1,20));
   If(V<0)Or(V>15)Or(V2<0)Then BadOption(A);
   RegSet[V]:=V2
  End
  Else If Copy(A,1,1)='-'Then BadOption(A)
  Else If FileName=''Then FileName:=A
  Else BadOption(A)
 End;
 If(FileName='')And Not DoTest Then Begin
  Usage;Halt(1)
 End
End;

Procedure InitCPU(Var C:TCPU);
Var
 J:Integer;
Begin
 FillChar(C,SizeOf(C),0);
 C.MaxTime:=600;C.MisoByte:=$FF;C.I2cDev:=$50;C.InputPos:=1;
 C.LastOut:=10;C.Analog[10]:=986;
 C.TA.Base:=aTA;C.TB.Base:=aTB;C.TB.IsB:=True;
 C.EvPos:=1;
 For J:=0To 255Do C.I2cMem[J]:=J
End;


{ ------------------------------------------------------------------ }
{  Moniteur interactif (debogueur)                                   }
{ ------------------------------------------------------------------ }

Procedure MonHelp;Begin
 WriteLn(T('Commandes du moniteur:',
  'Monitor commands:','Monitor-Befehle:','Comandos del monitor:',
  'Comandi del monitor:'));
 WriteLn(T('  r [Rn val]       registres / modifie un registre (ex: r r4 1234)',
  '  r [Rn val]       registers / set a register (e.g. r r4 1234)',
  '  r [Rn wert]      Register / Register setzen (z.B. r r4 1234)',
  '  r [Rn val]       registros / modifica un registro (ej: r r4 1234)',
  '  r [Rn val]       registri / modifica un registro (es: r r4 1234)'));
 WriteLn(T('  m adr [n]        affiche n octets de memoire (sans effet)',
  '  m adr [n]        dump n bytes of memory (no side effects)',
  '  m adr [n]        n Bytes Speicher anzeigen (ohne Nebeneffekt)',
  '  m adr [n]        muestra n bytes de memoria (sin efectos)',
  '  m adr [n]        mostra n byte di memoria (senza effetti)'));
 WriteLn(T('  w adr oct...     ecrit des octets    ww adr mot... des mots',
  '  w adr byte...    write bytes         ww adr word... write words',
  '  w adr byte...    Bytes schreiben     ww adr wort... Worte schreiben',
  '  w adr byte...    escribe bytes       ww adr pal...  escribe palabras',
  '  w adr byte...    scrive byte         ww adr par...  scrive parole'));
 WriteLn(T('  d [adr [n]]      desassemble n instructions (defaut 10 a PC)',
  '  d [adr [n]]      disassemble n instructions (default 10 at PC)',
  '  d [adr [n]]      n Befehle disassemblieren (Standard 10 ab PC)',
  '  d [adr [n]]      desensambla n instrucciones (defecto 10 en PC)',
  '  d [adr [n]]      disassembla n istruzioni (default 10 da PC)'));
 WriteLn(T('  s [n]            execute n instructions (defaut 1)',
  '  s [n]            step n instructions (default 1)',
  '  s [n]            n Befehle ausfuehren (Standard 1)',
  '  s [n]            ejecuta n instrucciones (defecto 1)',
  '  s [n]            esegue n istruzioni (default 1)'));
 WriteLn(T('  g                continue jusqu''a un arret',
  '  g                run until a stop condition',
  '  g                bis zu einer Stoppbedingung ausfuehren',
  '  g                ejecuta hasta una condicion de parada',
  '  g                esegue fino a una condizione di arresto'));
 WriteLn(T('  b adr | bl | bc [adr]   point d''arret: ajoute, liste, efface',
  '  b adr | bl | bc [adr]   breakpoint: add, list, clear',
  '  b adr | bl | bc [adr]   Haltepunkt: setzen, Liste, loeschen',
  '  b adr | bl | bc [adr]   punto de parada: anade, lista, borra',
  '  b adr | bl | bc [adr]   punto di arresto: aggiunge, elenca, cancella'));
 WriteLn(T('  wp d[-f] [r|w|rw] | wl | wc   surveillance memoire',
  '  wp f[-t] [r|w|rw] | wl | wc   memory watchpoint',
  '  wp v[-b] [r|w|rw] | wl | wc   Speicherueberwachung',
  '  wp d[-h] [r|w|rw] | wl | wc   vigilancia de memoria',
  '  wp d[-a] [r|w|rw] | wl | wc   controllo memoria'));
 WriteLn(T('  t                bascule la trace    i  etat des peripheriques',
  '  t                toggle trace        i  peripheral state',
  '  t                Trace umschalten    i  Peripheriezustand',
  '  t                activa la traza     i  estado de perifericos',
  '  t                attiva la traccia   i  stato periferiche'));
 WriteLn(T('  ev us type [val] evenement externe (+us=relatif)  in texte: UART',
  '  ev us type [val] external event (+us = relative)  in text: UART',
  '  ev us typ [wert] externes Ereignis (+us = relativ)  in text: UART',
  '  ev us tipo [val] evento externo (+us = relativo)  in texto: UART',
  '  ev us tipo [val] evento esterno (+us = relativo)  in testo: UART'));
 WriteLn(T('  sym [nom adr]    symboles    lcd  afficheur   rs  reset',
  '  sym [name adr]   symbols     lcd  show the LCD memory    rs  reset',
  '  sym [name adr]   Symbole     lcd  LCD-Speicher zeigen    rs  Reset',
  '  sym [nom dir]    simbolos    lcd  muestra la memoria LCD rs  reinicio',
  '  sym [nome ind]   simboli     lcd  mostra la memoria LCD  rs  reset'));
 WriteLn(T('  q                quitte le moniteur',
  '  q                quit the monitor','  q                Monitor verlassen',
  '  q                sale del monitor','  q                esce dal monitor'))
End;

Function RegIndex(Const S:String):Integer;
Var
 U:String;
 V:LongInt;
Begin
 U:=Upper(S);RegIndex:=-1;
 If U='PC'Then RegIndex:=0
 Else If U='SP'Then RegIndex:=1
 Else If U='SR'Then RegIndex:=2
 Else If(Length(U)>=2)And(U[1]='R')Then Begin
  V:=DecValue(Copy(U,2,3));
  If(V>=0)And(V<=15)Then RegIndex:=V
 End
End;

Function NextWord(Var S:String):String;
Var
 P:Integer;
Begin
 S:=LTrim(S);P:=Pos(' ',S);
 If P=0Then Begin
  NextWord:=S;S:=''
 End
  Else
 Begin
  NextWord:=Copy(S,1,P-1);S:=LTrim(Copy(S,P+1,255))
 End
End;

Procedure ShowRegs(Var C:TCPU);
Var
 J:Integer;
 L:Integer;
Begin
 Write('PC=',Hex5(C.R[0]),' SP=',Hex5(C.R[1]),' SR=',Hex4(C.R[2]),' [');
 ShowFlags(C.R[2]);WriteLn(']');
 For J:=4To 15Do Begin
  Write('R',J,'=':Ord(J<10)+1,Hex5(C.R[J]));
  If(J And 3)=3Then WriteLn Else Write('  ')
 End;
 WriteLn(Hex5(C.R[0]),': ',Disasm(C,C.R[0],L))
End;

Procedure ShowLcd(Var C:TCPU);
Var
 J:Integer;
Begin
 Write('LCDCTL=',Hex2(RawGet(C,aLCDCTL)),' ');
 If(RawGet(C,aLCDCTL)And 1)<>0Then Write('ON')Else Write('OFF');
 WriteLn;
 Write('LCDMEM:');
 For J:=0To 19Do Write(' ',Hex2(RawGet(C,aLCDMEM+J)));
 WriteLn
End;

Procedure ShowInfo(Var C:TCPU);
Var
 J:Integer;
 Procedure Timer(Const Nm:String;Const Tm:TTimer);
 Var
  I:Integer;
 Begin
  Write(Nm,' CTL=',Hex4(RawGetW(C,Tm.Base)),' R=',Hex4(RawGetW(C,Tm.Base+$10)));
  For I:=0To 2Do Begin
   Write(' CC',I,'=',Hex4(RawGetW(C,Tm.Base+$12+2*I)),'/',
    Hex4(RawGetW(C,Tm.Base+2+2*I)));
   If Tm.OutQ[I]Then Write('*')
  End;
  WriteLn
 End;
 Procedure Port(N:Integer);
 Var
  B:Word;
 Begin
  B:=PortAddr(N);
  Write('P',N,' IN=',Hex2(PinVal(C,N)),' OUT=',Hex2(RawGet(C,B+1)),
   ' DIR=',Hex2(RawGet(C,B+2)));
  If N<=2Then Write(' IFG=',Hex2(RawGet(C,B+3)),' IES=',Hex2(RawGet(C,B+4)),
   ' IE=',Hex2(RawGet(C,B+5)),' SEL=',Hex2(RawGet(C,B+6)),
   ' REN=',Hex2(RawGet(C,B+7)));
  WriteLn
 End;
Begin
 WriteLn(T('Temps: ','Time: ','Zeit: ','Tiempo: ','Tempo: '),C.Now*1000:0:6,
  ' ms  MCLK=',C.FMclk,' SMCLK=',C.FSmclk,' ACLK=',C.FAclk,' Hz');
 WriteLn('IE1=',Hex2(RawGet(C,aIE1)),' IE2=',Hex2(RawGet(C,aIE2)),
  ' IFG1=',Hex2(RawGet(C,aIFG1)),' IFG2=',Hex2(RawGet(C,aIFG2)),
  ' WDTCTL=',Hex2(RawGet(C,aWDTCTL)),' cnt=',C.WdtCnt,
  ' BCSCTL1=',Hex2(RawGet(C,aBCSCTL1)),' DCOCTL=',Hex2(RawGet(C,aDCOCTL)),
  ' BCSCTL2=',Hex2(RawGet(C,aBCSCTL2)),' BCSCTL3=',Hex2(RawGet(C,aBCSCTL3)));
 Timer('TA',C.TA);Timer('TB',C.TB);
 For J:=1To 3Do Port(J);
 For J:=0To 1Do Begin
  Write('UC',Chr(65+J),'0 CTL0=',Hex2(RawGet(C,UBase(J))),' CTL1=',
   Hex2(RawGet(C,UBase(J)+1)),' BR=',Hex4(RawGetW(C,UBase(J)+2)),
   ' STAT=',Hex2(UsciStat(C,J)),' RX=',Hex2(RawGet(C,UBase(J)+6)));
  If C.U[J].Busy Then Write(' TXBUSY');
  If C.U[J].RxBusy Then Write(' RXBUSY');
  WriteLn
 End;
 WriteLn('ADC10 CTL0=',Hex4(RawGetW(C,aADCCTL0)),' CTL1=',
  Hex4(RawGetW(C,aADCCTL1)),' MEM=',Hex4(RawGetW(C,aADCMEM)),
  ' CACTL1=',Hex2(RawGet(C,aCACTL1)),' CACTL2=',Hex2(RawGet(C,aCACTL2)),
  ' FCTL1..3=',Hex2(RawGet(C,aFCTL1)),'/',Hex2(RawGet(C,aFCTL2)),'/',
  Hex2(RawGet(C,aFCTL3)));
 WriteLn('MPY RES=',Hex4(RawGetW(C,aRESHI)),Hex4(RawGetW(C,aRESLO)),
  ' SUMEXT=',Hex4(RawGetW(C,aSUMEXT)),'  DMA0CTL=',Hex4(RawGetW(C,aDMA0)),
  ' DMA1CTL=',Hex4(RawGetW(C,aDMA0+8)),' DMA2CTL=',Hex4(RawGetW(C,aDMA0+16)));
 If C.Dev.Rtc Then WriteLn('RTC CTL=',Hex4(RawGetW(C,aRTC)),' ',
  Hex2(RawGet(C,aRTC+$12)),':',Hex2(RawGet(C,aRTC+$11)),':',
  Hex2(RawGet(C,aRTC+$10)))
End;

Procedure MonStop(Var C:TCPU);
Var
 L:Integer;
Begin
 If C.Stopped Then Begin
  ShowReason(C);
  If C.Reason In[StopBreak,StopWatch,StopLimit,StopTime]Then Begin
   C.Stopped:=False;C.Reason:=StopNone
  End
 End;
 WriteLn(Hex5(C.R[0]),': ',Disasm(C,C.R[0],L))
End;

Procedure Monitor(Var C:TCPU);
Var
 Line,Cmd,A1,A2:String;
 Quit:Boolean;
 V,V2,J,N:LongInt;
 L:Integer;
 Rg:Integer;
 Tm:Double;
 Mode:Byte;
Begin
 Quit:=False;
 WriteLn(T('Moniteur MSP430 - tapez ? pour l''aide',
  'MSP430 monitor - type ? for help','MSP430-Monitor - ? fuer Hilfe',
  'Monitor MSP430 - escriba ? para ayuda',
  'Monitor MSP430 - digitare ? per aiuto'));
 MonStop(C);
 While Not Quit Do Begin
  Write('msp430> ');
  If Eof(Input)Then Break;
  ReadLn(Line);Line:=Trim(Line);
  If Line<>''Then Begin
   Cmd:=Upper(NextWord(Line));A1:=NextWord(Line);A2:=NextWord(Line);
   If(Cmd='Q')Or(Cmd='QUIT')Then Quit:=True
   Else If(Cmd='?')Or(Cmd='H')Or(Cmd='HELP')Then MonHelp
   Else If Cmd='R'Then Begin
    If A1=''Then ShowRegs(C)
    Else Begin
     Rg:=RegIndex(A1);
     If(Rg<0)Or Not ParseAddr(A2,V)Then WriteLn('?')
     Else Begin
      If Rg=0Then C.R[0]:=V And PcMask(C)Else C.R[Rg]:=V And $FFFFF;
      ShowRegs(C)
     End
    End
   End
   Else If Cmd='M'Then Begin
    If Not ParseAddr(A1,V)Then WriteLn('?')
    Else Begin
     N:=64;
     If A2<>''Then N:=DecValue(A2);
     If N<1Then N:=16;
     DumpMemory(C,V,V+N-1)
    End
   End
   Else If(Cmd='W')Or(Cmd='WW')Then Begin
    If Not ParseAddr(A1,V)Then WriteLn('?')
    Else Begin
     A1:=A2;
     While A1<>''Do Begin
      If Not ParseAddr(A1,V2)Then Begin
       WriteLn('?');Break
      End;
      If Cmd='W'Then Begin
       RawPut(C,V,Byte(V2));Inc(V)
      End
       Else
      Begin
       RawPutW(C,V,Word(V2));Inc(V,2)
      End;
      A1:=NextWord(Line)
     End
    End
   End
   Else If Cmd='D'Then Begin
    If A1=''Then V:=C.R[0]
    Else If Not ParseAddr(A1,V)Then V:=-1;
    If V<0Then WriteLn('?')
    Else Begin
     N:=10;
     If A2<>''Then N:=DecValue(A2);
     For J:=1To N Do Begin
      WriteLn(Hex5(V),': ',Disasm(C,V,L));V:=V+L
     End
    End
   End
   Else If(Cmd='S')Or(Cmd='G')Or(Cmd='C')Then Begin
    N:=1;
    If(Cmd='S')And(A1<>'')Then N:=DecValue(A1);
    If N<1Then N:=1;
    C.Stopped:=False;C.Reason:=StopNone;C.SkipBreak:=True;
    If Cmd='S'Then Run(C,C.Count+N)Else Run(C,C.Count+MaxInstr);
    If Not C.Stopped Then C.Reason:=StopNone;
    MonStop(C)
   End
   Else If Cmd='B'Then Begin
    If Not ParseAddr(A1,V)Then WriteLn('?')
    Else If C.NBp<MaxBreak Then Begin
     Inc(C.NBp);C.Bp[C.NBp]:=V
    End
   End
   Else If Cmd='BL'Then Begin
    For J:=1To C.NBp Do WriteLn(J,': ',Hex5(C.Bp[J]),' ',SymName(C.Bp[J]))
   End
   Else If Cmd='BC'Then Begin
    If(A1='')Or Not ParseAddr(A1,V)Then C.NBp:=0
    Else Begin
     N:=0;
     For J:=1To C.NBp Do If C.Bp[J]<>V Then Begin
      Inc(N);C.Bp[N]:=C.Bp[J]
     End;
     C.NBp:=N
    End
   End
   Else If Cmd='WP'Then Begin
    N:=Pos('-',A1);
    If N>0Then Begin
     If Not ParseAddr(Copy(A1,1,N-1),V)Or Not ParseAddr(Copy(A1,N+1,20),V2)Then
      V:=-1
    End
     Else
    Begin
     If Not ParseAddr(A1,V)Then V:=-1;
     V2:=V
    End;
    If(V<0)Or(C.NWp>=MaxWatch)Then WriteLn('?')
    Else Begin
     Mode:=3;A2:=Upper(A2);
     If A2='R'Then Mode:=1 Else If A2='W'Then Mode:=2;
     Inc(C.NWp);C.Wp[C.NWp].Lo:=V;C.Wp[C.NWp].Hi:=V2;C.Wp[C.NWp].Mode:=Mode
    End
   End
   Else If Cmd='WL'Then Begin
    For J:=1To C.NWp Do WriteLn(J,': ',Hex5(C.Wp[J].Lo),'-',Hex5(C.Wp[J].Hi),
     ' mode=',C.Wp[J].Mode)
   End
   Else If Cmd='WC'Then C.NWp:=0
   Else If Cmd='T'Then Begin
    C.Trace:=Not C.Trace;WriteLn('trace=',C.Trace)
   End
   Else If Cmd='I'Then ShowInfo(C)
   Else If Cmd='LCD'Then ShowLcd(C)
   Else If Cmd='RS'Then Begin
    DoPUC(C,True);ShowRegs(C)
   End
   Else If Cmd='IN'Then Begin
    C.Input:=C.Input+A1;
    If A2<>''Then C.Input:=C.Input+' '+A2+Line
   End
   Else If Cmd='EV'Then Begin
    Tm:=0;
    If(A1<>'')And(A1[1]='+')Then Begin
     Tm:=C.Now;A1:=Copy(A1,2,20)
    End;
    V:=DecValue(A1);
    If V<0Then WriteLn('?')
    Else Begin
     V:=V+Trunc(Tm*1000000.0);
     Str(V,A1);
     If Line<>''Then A2:=A2+':'+Line;
     ParseEvent(C,A1+':'+A2)
    End
   End
   Else If Cmd='SYM'Then Begin
    If A1=''Then Begin
     For J:=1To NSym Do WriteLn(Hex5(Sym[J].Addr),' ',Sym[J].Name)
    End
    Else If ParseAddr(A2,V)Then AddSymbol(A1,V)Else WriteLn('?')
   End
   Else WriteLn('?')
  End
 End
End;

{ ------------------------------------------------------------------ }
{  Auto-tests integres (programmes assembles avec gas, valeurs        }
{  attendues verifiees contre mspdebug ou calculees a la main)        }
{ ------------------------------------------------------------------ }

Var
 TC:TCPU;
 TName,TSpec:String;
 TDev:Integer;
 TAddr:LongInt;
 TPass,TFail:Integer;
 TStarted:Boolean;

Function HexNib(C:Char):Integer;Begin
 If C In['0'..'9']Then HexNib:=Ord(C)-48
 Else If C In['A'..'F']Then HexNib:=Ord(C)-55
 Else HexNib:=Ord(C)-87
End;

Procedure BeginCase(Const Name:String;Dev:Integer);Begin
 TName:=Name;TDev:=Dev;TSpec:='';TStarted:=False;
 InitCPU(TC);SetDevice(TC.Dev,Dev);InitMemory(TC);TC.Capture:=True;
 TAddr:=TC.Dev.FlLo
End;

Procedure Code(Const Hex:String);
Var
 J:Integer;
Begin
 J:=1;
 While J<Length(Hex)Do Begin
  RawPut(TC,TAddr,HexNib(Hex[J])*16+HexNib(Hex[J+1]));Inc(TAddr);Inc(J,2)
 End
End;

Procedure Spec(Const S:String);Begin
 If TSpec<>''Then TSpec:=TSpec+';';
 TSpec:=TSpec+S
End;

Function NextItem(Var S:String):String;
Var
 P:Integer;
Begin
 P:=Pos(';',S);
 If P=0Then Begin
  NextItem:=S;S:=''
 End
  Else
 Begin
  NextItem:=Copy(S,1,P-1);S:=Copy(S,P+1,255)
 End
End;

Function ValOf(Var C:TCPU;Const Name:String):LongInt;
Var
 N:LongInt;
Begin
 ValOf:=-1;
 If Name='CYC'Then ValOf:=C.Cycles
 Else If Name='STOP'Then ValOf:=C.Reason
 Else If Name='RST'Then ValOf:=C.Resets
 Else If Name='OUT'Then ValOf:=C.OutCount
 Else If Name='TB1'Then ValOf:=Ord(C.TB.OutQ[1])
 Else If Name='TB2'Then ValOf:=Ord(C.TB.OutQ[2])
 Else If Name='TA1'Then ValOf:=Ord(C.TA.OutQ[1])
 Else If Name='TA2'Then ValOf:=Ord(C.TA.OutQ[2])
 Else If Name='SR'Then ValOf:=C.R[2]
 Else If Name='PC'Then ValOf:=C.R[0]
 Else If Name='SP'Then ValOf:=C.R[1]
 Else If(Name[1]='R')And(Length(Name)<=3)Then Begin
  N:=DecValue(Copy(Name,2,2));
  If(N>=0)And(N<=15)Then ValOf:=C.R[N]
 End
 Else If(Name[1]='M')And(Length(Name)<=6)Then
  ValOf:=RawGetW(C,HexValue(Copy(Name,2,5)))
 Else If(Name[1]='B')And(Length(Name)<=6)Then
  ValOf:=RawGet(C,HexValue(Copy(Name,2,5)))
End;

Function IsCfg(Const Nm:String):Boolean;Begin
 IsCfg:=(Nm='N')Or(Nm='Y')Or(Nm='inp')Or(Nm='miso')Or(Nm='ev')Or(Nm='P1')Or
  (Nm[1]='i')Or(Nm[1]='v')Or((Nm[1]='V')And(Length(Nm)>1)And(Nm[2]In['0'..'9']))
End;

Procedure EndCase;
Var
 S,Item,Nm,Vs:String;
 P,Op:Integer;
 V,Want,Got,Lim:LongInt;
 Ok:Boolean;
 Ms,Tw:Double;
 Code2:Integer;
 Fails:Integer;
Begin
 { 1ere passe: initialisations }
 S:=TSpec;MaxInstr:=100000;MaxResets:=16;TC.MaxTime:=20;
 DoPUC(TC,True);TC.Resets:=0;
 TC.R[0]:=TC.Dev.FlLo;
 While S<>''Do Begin
  Item:=NextItem(S);P:=Pos('=',Item);
  If P>0Then Begin
   Nm:=Copy(Item,1,P-1);Vs:=Copy(Item,P+1,255)
  End
   Else Begin
    Nm:=Item;Vs:=''
   End;
  If Nm='inp'Then TC.Input:=Vs
  Else If Nm='i2c'Then TC.I2cDev:=HexValue(Vs)
  Else If(Nm[1]='i')And(Length(Nm)>1)Then Begin
   V:=HexValue(Vs);
   Case Nm[2]Of
    'R':TC.R[DecValue(Copy(Nm,3,2))]:=V;
    'M':RawPutW(TC,HexValue(Copy(Nm,3,5)),Word(V));
    'B':RawPut(TC,HexValue(Copy(Nm,3,5)),Byte(V))
   End
  End
  Else If(Nm[1]='v')And(Length(Nm)>1)Then
   RawPutW(TC,HexValue(Copy(Nm,2,5)),Word(HexValue(Vs)))
  Else If Nm='N'Then MaxInstr:=DecValue(Vs)
  Else If Nm='Y'Then TC.MaxTime:=DecValue(Vs)
  Else If Nm='miso'Then TC.MisoByte:=HexValue(Vs)
  Else If Nm='ev'Then ParseEvent(TC,Vs)
  Else If Nm='P1'Then Begin
   TC.PVal[1]:=HexValue(Vs);TC.PDrv[1]:=$FF
  End
  Else If(Nm[1]='V')And(Length(Nm)>1)Then
   TC.Analog[DecValue(Copy(Nm,2,2))]:=DecValue(Vs)
 End;
 For P:=1To 3Do TC.PPrev[P]:=PinVal(TC,P);
 UpdateClocks(TC);
 TC.Cycles:=0;TC.Now:=0;
 Run(TC,MaxInstr);
 { 2eme passe: verifications }
 S:=TSpec;Fails:=0;
 While S<>''Do Begin
  Item:=NextItem(S);Op:=0;
  For P:=1To Length(Item)Do If(Op=0)And(Item[P]In['=','>','<'])Then Op:=P;
  If Op>0Then Begin
   Nm:=Copy(Item,1,Op-1);Vs:=Copy(Item,Op+1,255);Ok:=True;
   If(Nm='TMS')Or(Nm='TMAX')Or(Nm='TMIN')Then Begin
    Val(Vs,Ms,Code2);Tw:=TC.Now*1000;
    If Nm='TMIN'Then Ok:=Tw>=Ms Else If Nm='TMAX'Then Ok:=Tw<=Ms
     Else Ok:=Abs(Tw-Ms)<0.01;
    If Not Ok Then Begin
     WriteLn('  ',Nm,' ',Ms:0:4,' obtenu ',Tw:0:4);Inc(Fails)
    End
   End
   Else If Nm='TXT'Then Begin
    If Copy(TC.OutBuf,1,Length(Vs))<>Vs Then Begin
     WriteLn('  TXT attendu "',Vs,'" obtenu "',TC.OutBuf,'"');Inc(Fails)
    End
   End
   Else If Not IsCfg(Nm)Then Begin
    If(Nm='CYC')Or(Nm='STOP')Or(Nm='RST')Or(Nm='OUT')Or(Nm='TB1')Or
     (Nm='TB2')Or(Nm='TA1')Or(Nm='TA2')Then Want:=DecValue(Vs)
    Else Want:=HexValue(Vs);
    Got:=ValOf(TC,Nm);
    Case Item[Op]Of
     '=':Ok:=Got=Want;
     '>':Ok:=Got>=Want;
     Else Ok:=Got<=Want
    End;
    If Not Ok Then Begin
     WriteLn('  ',Nm,' ',Item[Op],' ',Want,' (hex ',Hex5(Want),
      ') obtenu ',Got,' (hex ',Hex5(Got),')');
     Inc(Fails)
    End
   End
  End
 End;
 If Fails=0Then Begin
  Inc(TPass);WriteLn('ok    ',TName)
 End
  Else Begin
   Inc(TFail);WriteLn('ECHEC ',TName)
  End;
 FreeMemory(TC)
End;


Procedure SelfTest;Begin
 TPass:=0;TFail:=0;
 BeginCase('cyc mov r5, r6',1);
 Code('0645');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=1');
 EndCase;
 BeginCase('cyc mov r5, pc',1);
 Code('0045');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=2');
 EndCase;
 BeginCase('cyc mov r5, 2(r6)',1);
 Code('86450200');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=4');
 EndCase;
 BeginCase('cyc mov r5, &0x0210',1);
 Code('82451002');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=4');
 EndCase;
 BeginCase('cyc mov @r5, r6',1);
 Code('2645');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=2');
 EndCase;
 BeginCase('cyc mov @r5, pc',1);
 Code('2045');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=2');
 EndCase;
 BeginCase('cyc mov @r5, 2(r6)',1);
 Code('A6450200');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=5');
 EndCase;
 BeginCase('cyc mov @r5, &0x0210',1);
 Code('A2451002');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=5');
 EndCase;
 BeginCase('cyc mov @r5+, r6',1);
 Code('3645');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=2');
 EndCase;
 BeginCase('cyc mov @r5+, pc',1);
 Code('3045');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=3');
 EndCase;
 BeginCase('cyc mov @r5+, 2(r6)',1);
 Code('B6450200');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=5');
 EndCase;
 BeginCase('cyc mov #0x1234, r6',1);
 Code('36403412');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=2');
 EndCase;
 BeginCase('cyc mov #0x1234, pc',1);
 Code('30403412');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=3');
 EndCase;
 BeginCase('cyc mov #0x1234, 2(r6)',1);
 Code('B64034120200');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=5');
 EndCase;
 BeginCase('cyc mov #0x1234, &0x0210',1);
 Code('B24034121002');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=5');
 EndCase;
 BeginCase('cyc mov 2(r5), r6',1);
 Code('16450200');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=3');
 EndCase;
 BeginCase('cyc mov 2(r5), pc',1);
 Code('10450200');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=3');
 EndCase;
 BeginCase('cyc mov 2(r5), 2(r6)',1);
 Code('964502000200');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=6');
 EndCase;
 BeginCase('cyc mov &0x0200, r6',1);
 Code('16420002');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=3');
 EndCase;
 BeginCase('cyc mov &0x0200, &0x0210',1);
 Code('924200021002');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=6');
 EndCase;
 BeginCase('cyc mov #1, r6',1);
 Code('1643');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=1');
 EndCase;
 BeginCase('cyc mov #8, 2(r6)',1);
 Code('B6420200');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=4');
 EndCase;
 BeginCase('cyc add r5, r6',1);
 Code('0655');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=1');
 EndCase;
 BeginCase('cyc add @r5, r6',1);
 Code('2655');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=2');
 EndCase;
 BeginCase('cyc cmp #0x1234, r6',1);
 Code('36903412');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=2');
 EndCase;
 BeginCase('cyc bit &0x0200, r6',1);
 Code('16B20002');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=3');
 EndCase;
 BeginCase('cyc rrc r5',1);
 Code('0510');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=1');
 EndCase;
 BeginCase('cyc rrc @r5',1);
 Code('2510');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=3');
 EndCase;
 BeginCase('cyc rrc @r5+',1);
 Code('3510');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=3');
 EndCase;
 BeginCase('cyc rrc 2(r5)',1);
 Code('15100200');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=4');
 EndCase;
 BeginCase('cyc rrc &0x0200',1);
 Code('12100002');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=4');
 EndCase;
 BeginCase('cyc swpb r5',1);
 Code('8510');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=1');
 EndCase;
 BeginCase('cyc sxt r5',1);
 Code('8511');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=1');
 EndCase;
 BeginCase('cyc rra 2(r5)',1);
 Code('15110200');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=4');
 EndCase;
 BeginCase('cyc push r5',1);
 Code('0512');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=3');
 EndCase;
 BeginCase('cyc push @r5',1);
 Code('2512');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=4');
 EndCase;
 BeginCase('cyc push @r5+',1);
 Code('3512');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=4');
 EndCase;
 BeginCase('cyc push #0x1234',1);
 Code('30123412');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=4');
 EndCase;
 BeginCase('cyc push 2(r5)',1);
 Code('15120200');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=5');
 EndCase;
 BeginCase('cyc push &0x0200',1);
 Code('12120002');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=5');
 EndCase;
 BeginCase('cyc call r5',1);
 Code('8512');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=4');
 EndCase;
 BeginCase('cyc call @r5',1);
 Code('A512');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=4');
 EndCase;
 BeginCase('cyc call @r5+',1);
 Code('B512');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=5');
 EndCase;
 BeginCase('cyc call #0x1234',1);
 Code('B0123412');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=5');
 EndCase;
 BeginCase('cyc call 2(r5)',1);
 Code('95120200');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=5');
 EndCase;
 BeginCase('cyc call &0x0200',1);
 Code('92120002');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=5');
 EndCase;
 BeginCase('cyc jmp .+4',1);
 Code('013C');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=2');
 EndCase;
 BeginCase('cyc jne .+4',1);
 Code('0120');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=2');
 EndCase;
 BeginCase('cyc reti',1);
 Code('0013');
 Spec('iR5=0200;iR6=0210;iM0200=0230;N=1;CYC=5');
 EndCase;
 BeginCase('cpu oracle 0',1);
 Code('B2F35C0222C2065822C2049312D375B234E005D7B2623C020B6B8D7B');
 Code('08000B9322C38D860E00547F0F0012D3365D0895013C2A53544D0200');
 Code('39E3AC9D04003A62481015BD06004953FF3F');
 Spec('N=59;iR2=0000;iR1=0380;iR4=3CFD;iR5=A393;iR6=348C');
 Spec('iR7=7252;iR8=D75A;iR9=FB57;iR10=E1D7;iR11=7AD8;iR12=0230');
 Spec('iR13=023A;iR14=023E;iR15=0254;PC=C048;SP=0380;SR=0004');
 Spec('R4=0000;R5=A393;R6=0BE6;R7=7252;R8=002D;R9=00A8;R10=E1DF');
 Spec('R11=F5B0;R12=0230;R13=023C;R14=023E;R15=0254;M023C=0009');
 Spec('M0242=0A4F;M0248=F41A');
 EndCase;
 BeginCase('cpu oracle 1',1);
 Code('8A1007F48CF704004A1106D819C25402DDC253020600265D09960134');
 Code('285CACED04008A1175F0FF0074924B790A11927D02005002799E645E');
 Code('861184112693FF3F');
 Spec('N=55;iR2=0005;iR1=0380;iR4=9B7A;iR5=E678;iR6=A6EF');
 Spec('iR7=3E24;iR8=FEC1;iR9=EEE3;iR10=576A;iR11=4ECA;iR12=024A');
 Spec('iR13=0266;iR14=025A;iR15=026A;PC=C03E;SP=0380;SR=0005');
 Spec('R4=007A;R5=0078;R6=FFEF;R7=1A20;R8=FEC1;R9=EEE3;R10=0015');
 Spec('R11=00E7;R12=024A;R13=0266;R14=025B;R15=026A');
 EndCase;
 BeginCase('cpu oracle 2',1);
 Code('928C0A003A0222D38DD30600B273620207734B893ACD9C4264020400');
 Code('82D5320246EA06950124385D08E8FFBE0F0056DE0500BC530A00297C');
 Code('2B5C55D322D276F0A500FFCF0B00FF3F');
 Spec('N=55;iR2=0001;iR1=0380;iR4=B641;iR5=D4A1;iR6=C4A9');
 Spec('iR7=C11E;iR8=7A86;iR9=D78B;iR10=706A;iR11=401B;iR12=0246');
 Spec('iR13=0232;iR14=0262;iR15=0250;PC=C046;SP=0380;SR=0005');
 Spec('R4=B641;R5=00A1;R6=0081;R7=C11D;R8=0000;R9=D78A;R10=706A');
 Spec('R11=0090;R12=0246;R13=0236;R14=0263;R15=0251;M0232=D4A1');
 Spec('M0250=FFFF;M0262=0001');
 EndCase;
 BeginCase('cpu oracle 3',1);
 Code('FE8208008CF90A00275378F3EF8F0F00274D2883057307750896022C');
 Code('8C5A0400E2BD6C0209631BED0A003AC3D2EE02003B0222D3ECC30C00');
 Code('0B94012C065A398C26FCFF3F');
 Spec('N=57;iR2=0002;iR1=0380;iR4=C364;iR5=6CFE;iR6=4F0A');
 Spec('iR7=E222;iR8=4152;iR9=DCD2;iR10=8906;iR11=A86F;iR12=023E');
 Spec('iR13=0258;iR14=0252;iR15=0268;PC=C042;SP=0380;SR=0002');
 Spec('R4=C364;R5=6CFE;R6=0000;R7=9302;R8=0050;R9=DCD2;R10=0000');
 Spec('R11=A86F;R12=0240;R13=0258;R14=0252;R15=0268;M0242=8906');
 Spec('M025A=00F8');
 EndCase;
 BeginCase('cpu oracle 4',1);
 Code('461129ED034349B3C2873B025BB24E0239630B930795023CBC5C0A00');
 Code('067A38E3045492C26E023C0219838DE9020015DD02009D5D02000E00');
 Code('0665CE8503000B93FF3F');
 Spec('N=54;iR2=0001;iR1=0380;iR4=49B7;iR5=4334;iR6=1F45');
 Spec('iR7=11AD;iR8=8F8C;iR9=9943;iR10=5BA4;iR11=4743;iR12=0252');
 Spec('iR13=025C;iR14=0240;iR15=026A;PC=C040;SP=0380;SR=0001');
 Spec('R4=936E;R5=DB75;R6=7FF2;R7=11AD;R8=7073;R9=9941;R10=5BA4');
 Spec('R11=4743;R12=0252;R13=025C;R14=0240;R15=026A;M023A=5300');
 Spec('M0242=8B00;M025E=9941;M026A=9941');
 EndCase;
 BeginCase('cpu oracle 5',1);
 Code('2A53064456D2330207990124255C22D2079402388D58040006980124');
 Code('055322D30B7322D307112453086364DD1A7C060007C735938C570E00');
 Code('0663D2523B026F020963FF3F');
 Spec('N=61;iR2=0004;iR1=0380;iR4=7BE8;iR5=A4FE;iR6=EFF5');
 Spec('iR7=7C2D;iR8=CCD1;iR9=7A13;iR10=A00F;iR11=D675;iR12=0234');
 Spec('iR13=026E;iR14=024E;iR15=0246;PC=C042;SP=0380;SR=0000');
 Spec('R4=00EA;R5=A4FE;R6=00E8;R7=0000;R8=CCD1;R9=7A13;R10=A010');
 Spec('R11=D674;R12=0234;R13=026E;R14=024E;R15=0246;M0272=CCD1');
 EndCase;
 BeginCase('cpu oracle 6',1);
 Code('87114B11D26F040032021983AD5208009CE3000019826202CD590C00');
 Code('0A930B737ADE4B100894013C3A5D39F212D32783A2DD4E0237BC17E3');
 Code('4BD7FF3F');
 Spec('N=54;iR2=0002;iR1=0380;iR4=2A9B;iR5=0AC2;iR6=812C');
 Spec('iR7=79DA;iR8=3B2D;iR9=C125;iR10=7D50;iR11=9B83;iR12=0246');
 Spec('iR13=0256;iR14=0230;iR15=0232;PC=C03A;SP=0380;SR=0005');
 Spec('R4=2A9B;R5=0AC2;R6=812C;R7=FFD9;R8=3B2D;R9=0000;R10=0050');
 Spec('R11=00F9;R12=0248;R13=0256;R14=0231;R15=0232;M0232=0001');
 Spec('M0246=0001;M025E=0004;M0262=0024');
 EndCase;
 BeginCase('cpu oracle 7',1);
 Code('065BDC9F030004002BC2175C0C008D9608000565057358F2510218EC');
 Code('08002B83C2D35B028911A2BC660209437A90800079EE77B3C2596A02');
 Code('25EC12C3925238026002ADCC08000497033C9D5D040004008B10FF3F');
 Spec('N=58;iR2=0108;iR1=0380;iR4=B1AB;iR5=326A;iR6=D52D');
 Spec('iR7=7852;iR8=A473;iR9=9F07;iR10=01C2;iR11=3184;iR12=0238');
 Spec('iR13=025A;iR14=0242;iR15=026A;PC=C052;SP=0380;SR=0109');
 Spec('R4=B1AB;R5=64D3;R6=06B1;R7=7852;R8=0000;R9=0000;R10=01C2');
 Spec('R11=7E31;R12=0238;R13=025A;R14=0243;R15=026A');
 EndCase;
 BeginCase('cpu oracle 8',1);
 Code('B26C48020553DE730E0046104BD826720493089701342B5D495AB26C');
 Code('5402871004100994022C825B6402148319FD0E0012C39D8C0C000000');
 Code('6BFF2AF34B74FF3F');
 Spec('N=57;iR2=0005;iR1=0380;iR4=D33E;iR5=F4BB;iR6=E1D6');
 Spec('iR7=4B3A;iR8=006D;iR9=9329;iR10=3065;iR11=41EF;iR12=0266');
 Spec('iR13=0248;iR14=0252;iR15=026A;PC=C03E;SP=0380;SR=0000');
 Spec('R4=699E;R5=F4BB;R6=0066;R7=3A4B;R8=006D;R9=0000;R10=0000');
 Spec('R11=0061;R12=026A;R13=0248;R14=0252;R15=026A;M0248=0001');
 Spec('M0260=00FE;M0264=00F0');
 EndCase;
 BeginCase('cpu oracle 9',1);
 Code('BDB20600077B0B9B023882585402081122D23952A252580204980130');
 Code('385C3BE3089602241A526202049A0134345C06990120045B075645CB');
 Code('22C2165347D87940E20004970128045619526802461154D322C38A11');
 Code('FF3F');
 Spec('N=73;iR2=0005;iR1=0380;iR4=B3C5;iR5=5868;iR6=C99A');
 Spec('iR7=43B8;iR8=65D9;iR9=9A65;iR10=5BD5;iR11=9D91;iR12=0266');
 Spec('iR13=0254;iR14=0266;iR15=0266;PC=C054;SP=0380;SR=0005');
 Spec('R4=0061;R5=0000;R6=00CD;R7=00EC;R8=32EC;R9=00E2;R10=FFD5');
 Spec('R11=626E;R12=0268;R13=0254;R14=0266;R15=0266;M0254=65D9');
 Spec('M0258=0004');
 EndCase;
 BeginCase('dadd bcd',1);
 Code('12C334409919154304A53640990012C356A307423840999912D308A3');
 Code('0942FF3F');
 Spec('N=20;R4=2000;R5=0001;R6=0000;R8=0000;R7=0003;R9=0003');
 EndCase;
 BeginCase('uart tx 9600 bd',1);
 Code('31400004B240805A2001F24081006100F24068006200C2436300E243');
 Code('6400D2C3610035403AC0764546930624E2B30300FD27C2466700F73F');
 Code('FF3F48656C6C6F2055415254210A00');
 Spec('OUT=12;STOP=3;TMIN=11.3;TMAX=11.5;TXT=Hello UART!');
 EndCase;
 BeginCase('uart tx 1MHz exact',1);
 Code('31400004B240805A2001D242FF105700D242FE105600F24081006100');
 Code('F24068006200C2436300D2C36100B0124AC0F24041006700B0124AC0');
 Code('F24042006700B0124AC0F24043006700FF3FE2B30300FD273041');
 Spec('OUT=3;STOP=3;TXT=ABC;TMIN=3.15;TMAX=3.2');
 EndCase;
 BeginCase('uart rx -I',1);
 Code('31400004B240805A2001D242FF105700D242FE105600F24081006100');
 Code('F24068006200C2436300D2C36100D2B30300FD2754426600D2B30300');
 Code('FD2755426600FF3F');
 Spec('inp=AB;R4=0041;R5=0042;STOP=3;TMIN=2.0;TMAX=2.2');
 EndCase;
 BeginCase('lpm3 timer 3 s',1);
 Code('31400004B240805A20010443B240FF7F7201B24010006201B2401001');
 Code('600132D0D8003540EFBEFF3F1453349003000520B1C0F00000008243');
 Code('60010013');
 Spec('vFFF2=C028;R4=0003;R5=BEEF;STOP=3;TMIN=3000.0');
 Spec('TMAX=3000.1;CYC<200');
 EndCase;
 BeginCase('port irq LPM4',1);
 Code('31400004B240805A2001F2D22400F2D22500F2C22300044332D0F800');
 Code('3540FECAFF3F1453F2C22300B1C0F00000000013');
 Spec('vFFE4=C022;P1=08;ev=2000:P1:00;R4=0001;R5=CAFE;STOP=3');
 Spec('TMIN=2.0;TMAX=2.05');
 EndCase;
 BeginCase('hw multiplier',1);
 Code('31400004B240805A2001B24034123001B2405600380114423A011542');
 Code('3C01B240FDFF3201B2400500380116423A0117423C0118423E018243');
 Code('300182433801B2433401B243380119423A011A423C01B2433401B243');
 Code('38011B423A011C423C011D423E01B2409CFF3601B2409CFF38011E42');
 Code('3A011F423C01FF3F');
 Spec('R4=1D78;R5=0006;R6=FFF1;R7=FFFF;R8=FFFF;R9=0001;R10=FFFE');
 Spec('R11=0002;R12=FFFC;R13=0001;STOP=3');
 EndCase;
 BeginCase('adc10 irq lpm0',1);
 Code('31400004B240805A2001B2400030B201B2401810B001B2D00300B001');
 Code('32D018001442B401FF3FB1C0100000000013');
 Spec('vFFEA=C026;V3=1650;R4=0200;STOP=3');
 EndCase;
 BeginCase('adc10 vcc ref 1 sample',1);
 Code('31400004B240805A2001B2400060B201B2401010B001B2D00300B001');
 Code('92B3B201FD231442B401FF3F');
 Spec('V6=3300;R4=03FF;STOP=3');
 EndCase;
 BeginCase('adc10 internal 1.5V ref',1);
 Code('31400004B240805A2001B2400010B201B2403020B001B2D00300B001');
 Code('92B3B201FD231442B401FF3F');
 Spec('V1=750;R4=0200;STOP=3');
 EndCase;
 BeginCase('i2c eeprom write/read',1);
 Code('31400004B240805A2001F24081006900F2400F006800F2400A006A00');
 Code('C2436B00B24050001A01D2C36900F2D012006900B012B6C0F2401000');
 Code('6F00B012B6C0F240AA006F00B012B6C0F240BB006F00B012B6C0E2D2');
 Code('6900B012C6C0F2D012006900B012B6C0F24010006F00B012B6C0E2D2');
 Code('6900B012C6C0F2C010006900E2D36900B012BEC054426E00E2D26900');
 Code('B012BEC055426E00B012C6C0B24033001A01F2D012006900B012CEC0');
 Code('56426D00E2D26900B012C6C0FF3FF2B20300FD273041E2B20300FD27');
 Code('3041E2B26900FD233041E2B36900FD233041');
 Spec('R4=00AA;R5=00BB;R6=0018;STOP=3');
 EndCase;
 BeginCase('spi loopback + miso',1);
 Code('31400004B240805A2001F24081006100F24069006000F2426200C243');
 Code('6300F2D080006500D2C36100F24055006700D2B30300FD2754426600');
 Code('F2C080006500F24012006700D2B30300FD2755426600FF3F');
 Spec('miso=A7;R4=0055;R5=00A7;STOP=3');
 EndCase;
 BeginCase('dma block transfer',1);
 Code('31400004B240805A2001B24011110002B24022220202B24033330402');
 Code('B2404444060282432201B2400002D201B2402002D401A242D601B240');
 Code('111FD00114422002154226021642D001FF3F');
 Spec('R4=1111;R5=4444;R6=1F08;M0224=3333;STOP=3');
 EndCase;
 BeginCase('flash erase/program/lock',1);
 Code('31400004B240805A2001B24042A52A01B24000A52C01B24002A52801');
 Code('824300E0144200E0B24040A52801B240341200E0B240FF0002E01542');
 Code('00E0B2400F0F00E0164200E0B24000A52801B24010A52C01B2405555');
 Code('04E017422C01184204E0194202E0FF3F');
 Spec('R4=FFFF;R5=1234;R6=0204;R7=961C;R8=FFFF;R9=00FF;STOP=3');
 Spec('TMIN=13.7;TMAX=14.2');
 EndCase;
 BeginCase('wdt reset x2',1);
 Code('3140000492530002B290030000020420B240805A2001FF3FFF3F');
 Spec('vFFFE=C000;M0200=0003;RST=2;STOP=3;TMIN=59.0;TMAX=60.0');
 EndCase;
 BeginCase('wdt interval 0.25s x4',1);
 Code('314000040443B2401D5A2001D2D3000032D0D80035400DD0FF3F1453');
 Code('24920620B240805A2001B1C0F00000000013');
 Spec('vFFF4=C01A;R4=0004;R5=D00D;STOP=3;TMIN=1000.0');
 Spec('TMAX=1000.1');
 EndCase;
 BeginCase('timer A TAIV dispatch',1);
 Code('31400004B240805A2001D242FF105700D242FE10560005430643B240');
 Code('00807401B24010006401B2402202600132D236900300FD2382436001');
 Code('32C2FF3F10522E010013043C053C00130013033C1553001300131653');
 Code('0013');
 Spec('vFFF0=C03C;R5=0003;R6=0003;STOP=3;TMIN=196.6;TMAX=196.7');
 EndCase;
 BeginCase('timer A up mode 1 kHz x5',1);
 Code('31400004B240805A2001D242FF105700D242FE1056000443B240E703');
 Code('7201B24010006201B2401002600132D018003540AAAAFF3F14533490');
 Code('0500052082436001B1C0100000000013');
 Spec('vFFF2=C034;R4=0005;R5=AAAA;STOP=3;TMIN=5.000;TMAX=5.1');
 EndCase;
 BeginCase('timer A pwm outmod7 state',1);
 Code('31400004B240805A2001D242FF105700D242FE105600B24009007201');
 Code('B24003007401B240E0006401B240100260010343034303430343FF3F');
 Spec('TA1=1;STOP=3');
 EndCase;
 BeginCase('timer A capture event',1);
 Code('31400004B240805A2001D242FF105700D242FE105600B24000416401');
 Code('B240200260013440D0071483FE23FF3F');
 Spec('ev=1234:C1:1;M0174>04B0;M0174<04D0;STOP=3');
 EndCase;
 BeginCase('timer B up mode 1 kHz x5',1);
 Code('31400004B240805A2001D242FF105700D242FE1056000443B240E703');
 Code('9201B24010008201B2401002800132D018003540BBBBFF3F14533490');
 Code('0500052082438001B1C0100000000013');
 Spec('vFFE2=C034;R4=0005;R5=BBBB;STOP=3;TMIN=5.000;TMAX=5.1');
 EndCase;
 BeginCase('timer B up/down TBIFG',1);
 Code('31400004B240805A2001D242FF105700D242FE1056000443B240F401');
 Code('9201B2403202800132D234900300FD2382438001FF3F10521E010013');
 Code('00130013001300130013001314530013');
 Spec('vFFE0=C032;R4=0003;STOP=3;TMIN=2.9;TMAX=3.1');
 EndCase;
 BeginCase('timer B CLLD latch',1);
 Code('31400004B240805A2001D242FF105700D242FE105600B24063009201');
 Code('B24064009401B24000028401B24010028001B240C800940117429401');
 Code('92B38001FD2718429401FF3F');
 Spec('R7=0064;R8=00C8;STOP=3');
 EndCase;
 BeginCase('comparator falling irq',1);
 Code('31400004B240805A20010443F2425A00F2402E00590032D018003540');
 Code('FECAFF3F1453B1C0100000000013');
 Spec('vFFF6=C020;V0=2000;ev=500:A0:800;R4=0001;R5=CAFE');
 Spec('B005A>=00;STOP=3');
 EndCase;
 BeginCase('nmi pin event',1);
 Code('31400004B240A05A20010443F2D01000000032D0F8003540CEFAFF3F');
 Code('1453F2C010000200B1C0F00000000013');
 Spec('vFFFC=C01C;ev=300:N;R4=0001;R5=FACE;STOP=3;TMIN=0.3');
 Spec('TMAX=0.35');
 EndCase;
 BeginCase('port IO + REN',1);
 Code('31400004B240805A2001F2400F002200F2400500210054422000F240');
 Code('F0002700F240A000210055422000FF3F');
 Spec('R4=0005;R5=00A0;STOP=3');
 EndCase;
 BeginCase('dco 8MHz timing',1);
 Code('31400004B240805A2001D242FD105700D242FC1056003440690A1483');
 Code('FE23FF3F');
 Spec('STOP=3;TMIN=0.999;TMAX=1.02');
 EndCase;
 BeginCase('X movx/mova/adda/suba/pushm',4);
 Code('3140FE43B240805A200180187540452386025634A6001000F6056006');
 Code('002427000024161405430643151618434318085880187A4045230019');
 Code('4A100B42B0134C448C0FFFFFAC0001000D42FF3F394077001001');
 Spec('R5=12345;R6=11121;R7=11121;R8=0010;R9=0077;R10=091A2');
 Spec('R11=0001;R12=00000;R13=0003;M2400=1121;M2402=0001;STOP=3');
 EndCase;
 BeginCase('X rpt rrcx + swpbx sxtx',4);
 Code('3140FE43B240805A2001001D7540DEBC0018851000187640F0000018');
 Code('8611001C77400000001847113840018041180810FF3F');
 Spec('R5=ADEBC;R6=FFFF0;R7=C0000;R8=A000;STOP=3');
 EndCase;
 BeginCase('X rram/rlam/rrcm',4);
 Code('3140FE43B240805A2001001C744001004405001875400300450A0018');
 Code('764001F056000018774001F0470FFF3F');
 Spec('R4=E0000;R5=00018;R6=07800;R7=00F00;STOP=3');
 EndCase;
 BeginCase('X timer irq 20-bit frame',4);
 Code('3140FE43B240805A2001D242FF105700D242FE1056000443B2406300');
 Code('7201B24010006201B2401002600132D018003540EDFEFF3F14533490');
 Code('0300052082436001B1C0100000000013');
 Spec('vFFF2=4434;R4=0003;R5=FEED;STOP=3;TMIN=0.299;TMAX=0.36');
 EndCase;
 BeginCase('X calla/reta indirect',4);
 Code('3140FE43B240805A2001840024446413541304003840AAAAFF3F1953');
 Code('100139500A0010011A4400001E440000');
 Spec('R9=000B;R8=AAAA;STOP=3');
 EndCase;
 BeginCase('RTC calendar 3 s',4);
 Code('3140FE43B240805A2001F2402000A104F2403A00B004F2403B00B104');
 Code('F2401700B204D243B304F2401C00B404E243B504B240E707B6040443');
 Code('F2401000A004F2C04000A10432D0D8005542B0045642B1045742B204');
 Code('5842B4045942B504FF3F1052AE0400130013003C1453349003000820');
 Code('F2D04000A104C243A004B1C0F00000000013');
 Spec('vFFDC=445E;R4=0003;R5=0001;R6=0000;R7=0000;R8=0001');
 Spec('R9=0003;STOP=3;TMIN=3000.0;TMAX=3000.2');
 EndCase;
 BeginCase('RTC alarm',4);
 Code('3140FE43B240805A2001F2402000A104F2403B00B004F2400A00B104');
 Code('F242B204F2408B00B804F2402000A004F2C04000A10432D0D8005542');
 Code('B104FF3FC243A0041453B1C0F00000000013');
 Spec('vFFDC=443C;R4=0001;R5=000B;STOP=3;TMIN=1000.0');
 Spec('TMAX=1000.2');
 EndCase;
 BeginCase('LCD registers',1);
 Code('31400004B240805A2001F24041009000F240AB009100F240CD00A400');
 Code('544291005542A400FF3F');
 Spec('R4=00AB;R5=00CD;B0090=41;STOP=3');
 EndCase;
 BeginCase('memory map: unmapped + rom',1);
 Code('31400004B240805A200114420008B240341200081542000CB2402143');
 Code('000CB240555500C116422C01FF3F');
 Spec('R4=FFFF;R5=FFFF;R6=961C;STOP=3');
 EndCase;
 BeginCase('adc10 sequence + DTC',1);
 Code('31400004B240805A2001F24003004900B2400002BC01B2400220B201');
 Code('B2409000B001B2D00300B001A2B2B001FD27FF3F');
 Spec('V0=500;V1=1000;V2=1500;M0200=01D1;M0202=0136;M0204=009B');
 Spec('STOP=3');
 EndCase;
 BeginCase('dma uart tx streaming',1);
 Code('31400004B240805A2001D242FF105700D242FE105600F24081006100');
 Code('F24068006200C2436300D2C36100A2422201B24048C0D201B2406700');
 Code('D401B2400300D601B240D003D001FF3F486921');
 Spec('OUT=3;TXT=Hi!;STOP=3;TMIN=3.1;TMAX=3.2');
 EndCase;
 WriteLn;
 WriteLn(T('Tests reussis: ','Tests passed: ','Bestandene Tests: ',
  'Pruebas superadas: ','Test superati: '),TPass,
  T('  echecs: ','  failures: ','  Fehler: ','  fallos: ','  falliti: '),TFail);
 If TFail>0Then Halt(1)
End;
BEGIN
 InitLanguage;DisEmu:=True;
 InitCPU(CPU);NSym:=0;LoadLo:=-1;LoadHi:=-1;
 ParseCommandLine(CPU);
 If DoTest Then Begin
  SelfTest;Halt
 End;
 InitMemory(CPU);
 If LoadAddr<0Then LoadAddr:=CPU.Dev.FlLo;
 If Pos('.',FileName)=0Then FileName:=FileName+'.BIN';
 If Not LoadProgram(CPU,FileName,LoadAddr)Then Halt(1);
 If SymName2<>''Then
  If Not LoadSymbols(SymName2)Then
   WriteLn(T('Fichier de symboles introuvable: ','Symbol file not found: ',
    'Symboldatei nicht gefunden: ','Fichero de simbolos no encontrado: ',
    'File dei simboli non trovato: '),SymName2);
 DoPUC(CPU,True);CPU.Resets:=0;CPU.Cycles:=0;CPU.Now:=0;CPU.WatchHit:=False;
 If StartAddr>=0Then CPU.R[0]:=StartAddr And PcMask(CPU)
 Else If(CPU.R[0]=0)Or(CPU.R[0]>$FFFFE)Or
  (MemKind(CPU,CPU.R[0])In[MemNone,MemPeriph])Or
  ((RawGetW(CPU,CPU.R[0])=$FFFF))Then CPU.R[0]:=LoadLo And PcMask(CPU);
 If CPU.R[0]=0Then CPU.R[0]:=LoadAddr;
 For K:=0To 15Do If RegSet[K]>=0Then CPU.R[K]:=RegSet[K];
 UpdateClocks(CPU);
 If DoDis Then Begin
  DisList(CPU,DisFrom,DisTo);FreeMemory(CPU);Halt
 End;
 If DoMon Then Monitor(CPU)
  Else Begin
   Run(CPU,MaxInstr);
   If(CPU.OutCount>0)And(CPU.LastOut<>10)Then WriteLn;
   ShowSummary(CPU,Quiet)
  End;
 If DoDump Then Begin
  WriteLn;DumpMemory(CPU,DumpFrom,DumpTo)
 End;
 FreeMemory(CPU);
 If CPU.Reason=StopIllegal Then Halt(2)
END.
