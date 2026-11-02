{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2
  @description: Clone de l'application ST BASIC
}

Program STBASIC;

{$IFNDEF FPC}
 {$M 65520,0,655360}
{$ENDIF}

Uses {$IFDEF FPC}
      {$IFDEF UNIX}cthreads,{$ENDIF}
      DOS,Crt,PtcGraph,PtcCrt,PtcMouse
     {$ELSE}
      DOS,Crt,Graph
     {$ENDIF};

{ ====================================================================== }
{                              CONSTANTES                                }
{ ====================================================================== }

Const
 VERSION_TEXT = '1.00';
 SCR_W        = 640;
 SCR_H        = 480;
 MENU_H       = 18;
 TITLE_H      = 18;
 SB           = 16;        { largeur des barres de defilement }
 INK          = 0;
 PAPER        = 15;

 { Fenetre OUTPUT : tampon graphique monochrome (32000 octets) }
 OUT_W     = 640;
 OUT_H     = 400;
 OUT_RB    = 80;            { octets par ligne }
 OUT_BYTES = 32000;
 OUT_COLS  = 80;
 OUT_ROWS  = 24;

 MAXL   = 2000;     { lignes de programme }
 MAXCON = 300;      { lignes de la fenetre COMMAND }
 MAXLST = 2000;     { lignes de la fenetre LIST }
 MAXED  = 1000;     { lignes de la fenetre EDIT }

 { Codes de touches : caractere = ord ; etendue = 256 + code }
 K_ESC    = 27;
 K_ENTER  = 13;
 K_BKSP   = 8;
 K_TAB    = 9;
 K_UP     = 328;
 K_DOWN   = 336;
 K_LEFT   = 331;
 K_RIGHT  = 333;
 K_HOME   = 327;
 K_END    = 335;
 K_PGUP   = 329;
 K_PGDN   = 337;
 K_INS    = 338;
 K_DEL    = 339;
 K_F1     = 315;
 K_F2     = 316;
 K_F3     = 317;
 K_F4     = 318;
 K_F5     = 319;
 K_F6     = 320;
 K_F7     = 321;
 K_F8     = 322;
 K_F9     = 323;
 K_F10    = 324;
 K_CTRLC  = 3;
 K_CTRLG  = 7;

 { Fenetres }
 W_EDIT = 0;
 W_LIST = 1;
 W_OUT  = 2;
 W_CMD  = 3;

{ ====================================================================== }
{                                TYPES                                   }
{ ====================================================================== }

Type
 PString = ^String;

 TEvent = Record
  { 0 rien, 1 touche, 2 bouton bas, 3 bouton haut, 4 mouvement }
  Kind : Byte;
  Key  : Word;
  X,Y,B: LongInt;
 End;

 TWin = Record
  X,Y,W,H     : Integer;
  NX,NY,NW,NH : Integer;
  Open,Full   : Boolean;
  Title       : String[70];
  ScrX,ScrY   : LongInt;
 End;

 PByteArr = ^TByteArr;
 TByteArr = Array[0..32000] Of Byte;

{ ====================================================================== }
{                       LANGUE / UTILITAIRES                             }
{ ====================================================================== }

Var
 Lang : Integer;       { 0 anglais, 1 francais, 2 allemand }

Function T3(Const En,Fr,De: String): String;
Begin
 Case Lang Of
  0: T3:=En;
  2: T3:=De;
 Else T3:=Fr;
 End;
End;

{ 'EN~FR~DE' : extrait la partie N }
Function Part3(Const S: String; N: Integer): String;
Var I,K: Integer; R: String;
Begin
 R:='';K:=0;
 For I:=1 To Length(S) Do
  If S[I]='~' Then Inc(K) Else If K=N Then R:=R+S[I];
 If (R='') And (N<>0) Then Part3:=Part3(S,0) Else Part3:=R;
End;

Function IntStr(N: LongInt): String;
Var S: String;
Begin
 Str(N,S);
 IntStr:=S;
End;

Function Upper(S: String): String;
Var I: Integer;
Begin
 For I:=1 To Length(S) Do S[I]:=UpCase(S[I]);
 Upper:=S;
End;

Function LowerStr(S: String): String;
Var I: Integer;
Begin
 For I:=1 To Length(S) Do
  If (S[I]>='A') And (S[I]<='Z') Then S[I]:=Chr(Ord(S[I])+32);
 LowerStr:=S;
End;

Function Min2(A,B: LongInt): LongInt;
Begin
 If A<B Then Min2:=A Else Min2:=B;
End;

Function Max2(A,B: LongInt): LongInt;
Begin
 If A>B Then Max2:=A Else Max2:=B;
End;

Function Clamp(V,A,B: LongInt): LongInt;
Begin
 If V<A Then V:=A;
 If V>B Then V:=B;
 Clamp:=V;
End;

Function TrimStr(Const S: String): String;
Var A,B: Integer;
Begin
 A:=1;B:=Length(S);
 While (A<=B) And (S[A]<=' ') Do Inc(A);
 While (B>=A) And (S[B]<=' ') Do Dec(B);
 TrimStr:=Copy(S,A,B-A+1);
End;

Function FileExists(Const N: String): Boolean;
Var F: File;
Begin
 {$I-}
 Assign(F,N);
 Reset(F,1);
 {$I+}
 If IOResult=0 Then Begin Close(F);FileExists:=True;End Else FileExists:=False;
End;

Function ShortName(Const N: String): String;
Var I: Integer;
Begin
 I:=Length(N);
 While (I>0) And (N[I]<>'\') And (N[I]<>'/') And (N[I]<>':') Do Dec(I);
 ShortName:=Copy(N,I+1,255);
End;

Function AddExt(Const N,Ext: String): String;
Var S: String;
Begin
 S:=N;
 If Pos('.',ShortName(S))=0 Then S:=S+'.'+Ext;
 AddExt:=S;
End;

Function NowCs: LongInt;
Var H,M,S,C: Word;
Begin
 GetTime(H,M,S,C);
 NowCs:=((LongInt(H)*60+M)*60+S)*100+C;
End;

Function NumStr(R: Real): String;
{ Format ST BASIC : 6 chiffres significatifs, pas de zero devant la virgule }
Var A: Real; E,I,P,Cd: Integer; L: LongInt; S,Dg,Fr: String; Neg: Boolean;
Begin
 If R=0 Then Begin NumStr:='0';Exit;End;
 Neg:=R<0;A:=Abs(R);
 If A>1.7E38 Then Begin NumStr:='Overflow';Exit;End;
 If (A<1E7) And (A=Int(A)) Then Begin
  Str(A:0:0,S);
  If Neg Then S:='-'+S;
  NumStr:=S;Exit;
 End;
 Str(A:22,S);
 P:=Pos('E',S);
 E:=0;
 If P>0 Then Val(Copy(S,P+1,10),E,Cd) Else P:=Length(S)+1;
 Dg:='';
 For I:=1 To P-1 Do If (S[I]>='0') And (S[I]<='9') Then Dg:=Dg+S[I];
 While Length(Dg)<8 Do Dg:=Dg+'0';
 Val(Copy(Dg,1,6),L,Cd);
 If Dg[7]>='5' Then Inc(L);
 If L>=1000000 Then Begin L:=100000;Inc(E);End;
 Dg:=IntStr(L);
 If (E>=-3) And (E<=5) Then Begin
  If E>=0 Then Begin
   S:=Copy(Dg,1,E+1);
   Fr:=Copy(Dg,E+2,6);
  End Else Begin
   S:='';
   Fr:='';
   For I:=1 To -E-1 Do Fr:=Fr+'0';
   Fr:=Fr+Dg;
  End;
  While (Fr<>'') And (Fr[Length(Fr)]='0') Do Delete(Fr,Length(Fr),1);
  If Fr<>'' Then S:=S+'.'+Fr;
  If S='' Then S:='0';
 End Else Begin
  Fr:=Copy(Dg,2,5);
  While (Fr<>'') And (Fr[Length(Fr)]='0') Do Delete(Fr,Length(Fr),1);
  S:=Dg[1];
  If Fr<>'' Then S:=S+'.'+Fr;
  If E<0 Then S:=S+'E-' Else S:=S+'E+';
  If Abs(E)<10 Then S:=S+'0';
  S:=S+IntStr(Abs(E));
 End;
 If Neg Then S:='-'+S;
 NumStr:=S;
End;

{ ====================================================================== }
{                  GRAPHIQUE / SOURIS (squelette)                        }
{ ====================================================================== }

Procedure InitializeGraphics;
Var
 Driver, Mode: Integer;
 ErrCode: Integer;
Begin
 {$IFDEF FPC}
  Driver:=VGA;
  Mode:=VGAHi;
 {$ELSE}
  Driver:=Detect;
  Mode:=VGAHi;
 {$ENDIF}
 InitGraph(Driver,Mode,'');
 ErrCode:=GraphResult;
 If ErrCode=grOk Then Begin
  SetColor(White);
  SetLineStyle(0,0,1);
 End
  Else
 Begin
  WriteLn('Erreur graphique : ',GraphErrorMsg(ErrCode));
  Halt;
 End;
End;

Var
 MX,MY,MB,LastB : LongInt;
 PrevMX,PrevMY  : LongInt;
 MouseLock      : Integer;     { > 0 : curseur garde cache (programme en cours) }

{$IFNDEF FPC}
 Function MouseDriverFound: Boolean;
 Var
  Regs: Registers;
 Begin
  Regs.AX := 0;
  Intr($33, Regs);
  MouseDriverFound := Regs.AX = $FFFF;
 End;

 Procedure ShowMouse;
 Var
  Regs: Registers;
 Begin
  If MouseLock>0 Then Exit;
  Regs.AX := $0001;
  Intr($33, Regs);
 End;

 Procedure HideMouse;
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0002;
  Intr($33, Regs);
 End;

 Procedure GetMouseState(Var X, Y, Button: LongInt);
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0003;
  Intr($33, Regs);
  Button := Regs.BX;
  X := Regs.CX;
  Y := Regs.DX;
 End;
{$ELSE}
 { Sous PtcMouse le curseur est invisible : fleche logicielle avec
   sauvegarde de l'arriere-plan }
 Var
  CurSaved,CurShown : Boolean;
  CurBuf : Pointer;
  CurSz  : LongInt;
  CurX,CurY : LongInt;

 Function MouseDriverFound: Boolean;
 Begin
  MouseDriverFound := True;
 End;

 Procedure CursorErase;
 Begin
  If CurSaved Then Begin
   PutImage(CurX,CurY,CurBuf^,NormalPut);
   FreeMem(CurBuf,CurSz);
   CurSaved:=False;
  End;
 End;

 Procedure CursorDraw(X,Y: LongInt);
 Var Pt: Array[1..7] Of PointType;
 Begin
  If X>SCR_W-12 Then X:=SCR_W-12;
  If Y>SCR_H-18 Then Y:=SCR_H-18;
  If X<0 Then X:=0;
  If Y<0 Then Y:=0;
  CursorErase;
  CurSz:=ImageSize(X,Y,X+11,Y+17);
  GetMem(CurBuf,CurSz);
  GetImage(X,Y,X+11,Y+17,CurBuf^);
  CurX:=X;CurY:=Y;CurSaved:=True;
  Pt[1].X:=X;    Pt[1].Y:=Y;
  Pt[2].X:=X;    Pt[2].Y:=Y+14;
  Pt[3].X:=X+4;  Pt[3].Y:=Y+11;
  Pt[4].X:=X+7;  Pt[4].Y:=Y+16;
  Pt[5].X:=X+9;  Pt[5].Y:=Y+15;
  Pt[6].X:=X+6;  Pt[6].Y:=Y+10;
  Pt[7].X:=X+10; Pt[7].Y:=Y+10;
  SetFillStyle(SolidFill,Black);
  SetColor(White);
  FillPoly(7,Pt);
 End;

 Procedure ShowMouse;
 Begin
  If MouseLock>0 Then Exit;
  CurShown:=True;
  CursorDraw(MX,MY);
 End;

 Procedure HideMouse;
 Begin
  CursorErase;
  CurShown:=False;
 End;
{$ENDIF}

{ ====================================================================== }
{                       PRIMITIVES GRAPHIQUES                            }
{ ====================================================================== }

Const
 PatChecker : FillPatternType = ($AA,$55,$AA,$55,$AA,$55,$AA,$55);
 PatStripe  : FillPatternType = ($FF,$00,$FF,$00,$FF,$00,$FF,$00);
 PatLight   : FillPatternType = ($88,$22,$88,$22,$88,$22,$88,$22);

Procedure Box(X1,Y1,X2,Y2,C: Integer);
Begin
 SetFillStyle(SolidFill,C);
 Bar(X1,Y1,X2,Y2);
End;

Procedure Frame(X1,Y1,X2,Y2: Integer);
Begin
 SetColor(INK);
 SetLineStyle(SolidLn,0,1);
 Rectangle(X1,Y1,X2,Y2);
End;

{ Le BGI peint les bits a 1 avec la couleur et les bits a 0 avec la couleur 0 :
  on inverse donc le motif et on le peint en blanc pour obtenir noir sur blanc }
Procedure PatBar(X1,Y1,X2,Y2: Integer; Const Pat: FillPatternType);
Var Q: FillPatternType; I: Integer;
Begin
 For I:=1 To 8 Do Q[I]:=Not Pat[I];
 SetFillPattern(Q,PAPER);
 Bar(X1,Y1,X2,Y2);
End;

Procedure PText(X,Y: Integer; Const S: String);
Begin
 SetColor(INK);
 OutTextXY(X,Y,S);
End;

Procedure BText(X,Y: Integer; Const S: String);
Begin
 SetColor(INK);
 OutTextXY(X,Y,S);
 OutTextXY(X+1,Y,S);
End;

Procedure WText(X,Y: Integer; Const S: String);
Begin
 SetColor(PAPER);
 OutTextXY(X,Y,S);
End;

Procedure GreyText(X,Y: Integer; Const S: String);
Var I,J,W: Integer;
Begin
 PText(X,Y,S);
 W:=Length(S)*8;
 For J:=0 To 7 Do
  For I:=0 To W-1 Do
   If Odd(I+J) Then
    If GetPixel(X+I,Y+J)=INK Then PutPixel(X+I,Y+J,PAPER);
End;

Function TextW(Const S: String): Integer;
Begin
 TextW:=Length(S)*8;
End;

Function InBox(X,Y,X1,Y1,X2,Y2: LongInt): Boolean;
Begin
 InBox:=(X>=X1) And (X<=X2) And (Y>=Y1) And (Y<=Y2);
End;

Procedure ArrowBox(X1,Y1,X2,Y2,Dir: Integer);
{ Dir : 1 haut, 2 bas, 3 gauche, 4 droite }
Var Pt: Array[1..3] Of PointType; CX,CY: Integer;
Begin
 Box(X1,Y1,X2,Y2,PAPER);
 Frame(X1,Y1,X2,Y2);
 CX:=(X1+X2) Div 2;CY:=(Y1+Y2) Div 2;
 Case Dir Of
  1: Begin
    Pt[1].X:=CX;Pt[1].Y:=CY-3;Pt[2].X:=CX-4;Pt[2].Y:=CY+3;Pt[3].X:=CX+4;
    Pt[3].Y:=CY+3;End;
  2: Begin
    Pt[1].X:=CX;Pt[1].Y:=CY+3;Pt[2].X:=CX-4;Pt[2].Y:=CY-3;Pt[3].X:=CX+4;
    Pt[3].Y:=CY-3;End;
  3: Begin
    Pt[1].X:=CX-3;Pt[1].Y:=CY;Pt[2].X:=CX+3;Pt[2].Y:=CY-4;Pt[3].X:=CX+3;
    Pt[3].Y:=CY+4;End;
  4: Begin
    Pt[1].X:=CX+3;Pt[1].Y:=CY;Pt[2].X:=CX-3;Pt[2].Y:=CY-4;Pt[3].X:=CX-3;
    Pt[3].Y:=CY+4;End;
 End;
 SetFillStyle(SolidFill,INK);
 SetColor(INK);
 FillPoly(3,Pt);
End;

Procedure Button(X1,Y1,X2,Y2: Integer; Const S: String; Hot,Enabled: Boolean);
{ Hot : bouton par defaut (bordure epaisse comme GEM) }
Var TX: Integer;
Begin
 Box(X1,Y1,X2,Y2,PAPER);
 Frame(X1,Y1,X2,Y2);
 If Hot Then Begin
  Frame(X1+1,Y1+1,X2-1,Y2-1);
  Frame(X1-1,Y1-1,X2+1,Y2+1);
 End;
 TX:=(X1+X2+1-TextW(S)) Div 2;
 If Enabled Then PText(TX,(Y1+Y2-6) Div 2,S)
 Else GreyText(TX,(Y1+Y2-6) Div 2,S);
End;

{ ====================================================================== }
{       POLICE 8x8 (relevee de la police BGI) POUR LE TAMPON OUTPUT      }
{ ====================================================================== }

Var
 Font8 : Array[0..255,0..7] Of Byte;

Procedure BuildFont;
Var C,X,Y: Integer; B: Byte;
Begin
 SetViewPort(0,0,SCR_W-1,SCR_H-1,True);
 For C:=0 To 255 Do Begin
  Box(0,0,15,15,0);
  SetColor(15);
  OutTextXY(0,0,Chr(C));
  For Y:=0 To 7 Do Begin
   B:=0;
   For X:=0 To 7 Do
    If GetPixel(X,Y)<>0 Then B:=B Or (128 Shr X);
   Font8[C,Y]:=B;
  End;
 End;
 Box(0,0,15,15,0);
End;

{ ====================================================================== }
{          MAGASINS DE TEXTE : fenetres COMMAND et LIST                  }
{ ====================================================================== }

Var
 ConL  : Array[1..MAXCON] Of PString;
 ConN  : Integer;
 LstL  : Array[1..MAXLST] Of PString;
 LstN  : Integer;
 LstName : String[80];

Function NewStr(Const S: String): PString;
Var P: PString;
Begin
 GetMem(P,Length(S)+1);
 P^:=S;
 NewStr:=P;
End;

Procedure FreeStr(Var P: PString);
Begin
 If P<>Nil Then FreeMem(P,Length(P^)+1);
 P:=Nil;
End;

Procedure ConAdd(Const S: String);
Var I: Integer;
Begin
 If ConN>=MAXCON Then Begin
  FreeStr(ConL[1]);
  For I:=1 To ConN-1 Do ConL[I]:=ConL[I+1];
  ConL[ConN]:=Nil;
  Dec(ConN);
 End;
 Inc(ConN);
 ConL[ConN]:=NewStr(Copy(S,1,200));
End;

Procedure ConClear;
Var I: Integer;
Begin
 For I:=1 To ConN Do FreeStr(ConL[I]);
 ConN:=0;
End;

Procedure LstAdd(Const S: String);
Begin
 If LstN>=MAXLST Then Exit;
 Inc(LstN);
 LstL[LstN]:=NewStr(Copy(S,1,250));
End;

Procedure LstClear;
Var I: Integer;
Begin
 For I:=1 To LstN Do FreeStr(LstL[I]);
 LstN:=0;
End;

{ ====================================================================== }
{                       FENETRES (bureau GEM)                            }
{ ====================================================================== }

Var
 Win     : Array[0..3] Of TWin;
 ZOrd    : Array[0..3] Of Integer;   { ZOrd[3] = fenetre du dessus }
 NeedDraw: Boolean;
 EditMode: Boolean;
 BufGfx  : Boolean;

Procedure DrawListContent(X1,Y1,X2,Y2: Integer); Forward;
Procedure DrawOutContent(X1,Y1,X2,Y2: Integer); Forward;
Procedure DrawCmdContent(X1,Y1,X2,Y2: Integer); Forward;
Procedure DrawEditContent(X1,Y1,X2,Y2: Integer); Forward;
Procedure ScrollInfo(N: Integer; Var VT,VV,VP,HT,HV,HP: LongInt); Forward;
Procedure AfterDesktop; Forward;

Function TopWin: Integer;
Begin
 TopWin:=ZOrd[3];
End;

Procedure WinClient(N: Integer; Var X1,Y1,X2,Y2: Integer);
Begin
 X1:=Win[N].X+1;
 Y1:=Win[N].Y+TITLE_H;
 X2:=Win[N].X+Win[N].W-2-SB;
 Y2:=Win[N].Y+Win[N].H-2-SB;
End;

Procedure BringToFront(N: Integer);
Var I,K: Integer;
Begin
 K:=3;
 For I:=0 To 3 Do If ZOrd[I]=N Then K:=I;
 For I:=K To 2 Do ZOrd[I]:=ZOrd[I+1];
 ZOrd[3]:=N;
End;

Procedure SendToBack(N: Integer);
Var I,K: Integer;
Begin
 K:=0;
 For I:=0 To 3 Do If ZOrd[I]=N Then K:=I;
 For I:=K DownTo 1 Do ZOrd[I]:=ZOrd[I-1];
 ZOrd[0]:=N;
End;

Procedure SetWin(N,X,Y,W,H: Integer; Const T: String);
Begin
 Win[N].X:=X;Win[N].Y:=Y;Win[N].W:=W;Win[N].H:=H;
 Win[N].NX:=X;Win[N].NY:=Y;Win[N].NW:=W;Win[N].NH:=H;
 Win[N].Title:=T;Win[N].Open:=True;Win[N].Full:=False;
 Win[N].ScrX:=0;Win[N].ScrY:=0;
End;

Function WinTitleStr(N: Integer): String;
Begin
 Case N Of
  W_EDIT: WinTitleStr:='EDIT';
  W_LIST: Begin
   If LstName<>'' Then WinTitleStr:=T3('List of ','Liste de ','Liste von ')+LstName
   Else WinTitleStr:='LIST';
  End;
  W_OUT: WinTitleStr:='OUTPUT';
 Else WinTitleStr:='COMMAND';
 End;
End;

Procedure InitWindows;
Begin
 SetWin(W_EDIT,64,64,512,330,'EDIT');
 SetWin(W_LIST,0,MENU_H+1,318,264,'LIST');
 SetWin(W_OUT,320,MENU_H+1,318,264,'OUTPUT');
 SetWin(W_CMD,0,298,638,181,'COMMAND');
 Win[W_EDIT].Open:=False;
 ZOrd[0]:=W_EDIT;ZOrd[1]:=W_LIST;ZOrd[2]:=W_OUT;ZOrd[3]:=W_CMD;
End;

Procedure ToggleFull(N: Integer);
Begin
 If Win[N].Full Then Begin
  Win[N].X:=Win[N].NX;Win[N].Y:=Win[N].NY;
  Win[N].W:=Win[N].NW;Win[N].H:=Win[N].NH;
  Win[N].Full:=False;
 End Else Begin
  Win[N].NX:=Win[N].X;Win[N].NY:=Win[N].Y;
  Win[N].NW:=Win[N].W;Win[N].NH:=Win[N].H;
  Win[N].X:=0;Win[N].Y:=MENU_H;
  Win[N].W:=SCR_W;Win[N].H:=SCR_H-MENU_H;
  Win[N].Full:=True;
 End;
End;

Procedure DrawScrollBars(N: Integer; Active: Boolean);
Var X1,Y1,X2,Y2,VT,VV,VP,HT,HV,HP: LongInt; TL,TH,TP,TS: LongInt;
    BX,BY: Integer;
Begin
 ScrollInfo(N,VT,VV,VP,HT,HV,HP);
 { barre verticale }
 BX:=Win[N].X+Win[N].W-1-SB;
 Y1:=Win[N].Y+TITLE_H;
 Y2:=Win[N].Y+Win[N].H-2-SB;
 Box(BX,Y1,BX+SB-1,Y2,PAPER);
 Frame(BX,Y1-1,BX+SB,Y2+1);
 ArrowBox(BX,Y1,BX+SB-1,Y1+SB-1,1);
 ArrowBox(BX,Y2-SB+1,BX+SB-1,Y2,2);
 If Active Then Begin
  PatBar(BX+1,Y1+SB,BX+SB-2,Y2-SB,PatChecker);
  TL:=Y2-SB-(Y1+SB)-1;
  If (VT>VV) And (TL>8) Then Begin
   TH:=TL*VV Div VT;
   If TH<8 Then TH:=8;
   TP:=VP*(TL-TH) Div (VT-VV);
   If TP<0 Then TP:=0;
   If TP>TL-TH Then TP:=TL-TH;
   TS:=Y1+SB+1+TP;
   Box(BX+1,TS,BX+SB-2,TS+TH-1,PAPER);
   Frame(BX+1,TS,BX+SB-2,TS+TH-1);
  End Else Begin
   Box(BX+1,Y1+SB+1,BX+SB-2,Y2-SB-1,PAPER);
  End;
 End;
 { barre horizontale }
 BY:=Win[N].Y+Win[N].H-1-SB;
 X1:=Win[N].X+1;
 X2:=Win[N].X+Win[N].W-2-SB;
 Box(X1,BY,X2,BY+SB-1,PAPER);
 Frame(X1-1,BY,X2+1,BY+SB);
 ArrowBox(X1,BY,X1+SB-1,BY+SB-1,3);
 ArrowBox(X2-SB+1,BY,X2,BY+SB-1,4);
 If Active Then Begin
  PatBar(X1+SB,BY+1,X2-SB,BY+SB-2,PatChecker);
  TL:=X2-SB-(X1+SB)-1;
  If (HT>HV) And (TL>8) Then Begin
   TH:=TL*HV Div HT;
   If TH<8 Then TH:=8;
   TP:=HP*(TL-TH) Div (HT-HV);
   If TP<0 Then TP:=0;
   If TP>TL-TH Then TP:=TL-TH;
   TS:=X1+SB+1+TP;
   Box(TS,BY+1,TS+TH-1,BY+SB-2,PAPER);
   Frame(TS,BY+1,TS+TH-1,BY+SB-2);
  End Else Begin
   Box(X1+SB+1,BY+1,X2-SB-1,BY+SB-2,PAPER);
  End;
 End;
 { boite de taille }
 Box(BX,BY,BX+SB-1,BY+SB-1,PAPER);
 Frame(BX,BY,BX+SB,BY+SB);
 If Not Win[N].Full Then Begin
  Frame(BX+4,BY+4,BX+SB-4,BY+SB-4);
  Line(BX+4,BY+SB-4,BX+SB-4,BY+4);
 End;
End;

Procedure DrawWindow(N: Integer);
Var X1,Y1,X2,Y2,TX: Integer; Active: Boolean; S: String;
Begin
 If Not Win[N].Open Then Exit;
 Active:=(ZOrd[3]=N);
 Box(Win[N].X,Win[N].Y,Win[N].X+Win[N].W-1,Win[N].Y+Win[N].H-1,PAPER);
 Frame(Win[N].X,Win[N].Y,Win[N].X+Win[N].W-1,Win[N].Y+Win[N].H-1);
 { barre de titre }
 SetColor(INK);
 Line(Win[N].X,Win[N].Y+TITLE_H-1,Win[N].X+Win[N].W-1,Win[N].Y+TITLE_H-1);
 If Active Then
  PatBar(Win[N].X+SB+2,Win[N].Y+3,Win[N].X+Win[N].W-SB-3,Win[N].Y+TITLE_H-4,
         PatStripe);
 S:=WinTitleStr(N);
 TX:=Win[N].X+(Win[N].W-TextW(S)) Div 2;
 Box(TX-8,Win[N].Y+2,TX+TextW(S)+7,Win[N].Y+TITLE_H-3,PAPER);
 BText(TX,Win[N].Y+5,S);
 { case de fermeture et de plein ecran }
 Box(Win[N].X+1,Win[N].Y+1,Win[N].X+SB,Win[N].Y+TITLE_H-2,PAPER);
 Frame(Win[N].X+1,Win[N].Y+1,Win[N].X+SB,Win[N].Y+TITLE_H-2);
 Frame(Win[N].X+5,Win[N].Y+5,Win[N].X+SB-4,Win[N].Y+TITLE_H-6);
 Box(Win[N].X+Win[N].W-SB-1,Win[N].Y+1,Win[N].X+Win[N].W-2,Win[N].Y+TITLE_H-2,PAPER);
 Frame(Win[N].X+Win[N].W-SB-1,Win[N].Y+1,Win[N].X+Win[N].W-2,Win[N].Y+TITLE_H-2);
 Frame(Win[N].X+Win[N].W-SB+3,Win[N].Y+5,Win[N].X+Win[N].W-6,Win[N].Y+TITLE_H-6);
 Box(Win[N].X+Win[N].W-SB+4,Win[N].Y+6,Win[N].X+Win[N].W-9,Win[N].Y+TITLE_H-9,INK);
 DrawScrollBars(N,Active);
 { contenu }
 WinClient(N,X1,Y1,X2,Y2);
 Case N Of
  W_EDIT: DrawEditContent(X1,Y1,X2,Y2);
  W_LIST: DrawListContent(X1,Y1,X2,Y2);
  W_OUT:  DrawOutContent(X1,Y1,X2,Y2);
  W_CMD:  DrawCmdContent(X1,Y1,X2,Y2);
 End;
 SetViewPort(0,0,SCR_W-1,SCR_H-1,True);
End;

Procedure DrawMenuBar; Forward;
Procedure DrawDropDown; Forward;

Procedure DrawDesktop;
Var I: Integer;
Begin
 HideMouse;
 SetViewPort(0,0,SCR_W-1,SCR_H-1,True);
 PatBar(0,MENU_H,SCR_W-1,SCR_H-1,PatChecker);
 For I:=0 To 3 Do DrawWindow(ZOrd[I]);
 DrawMenuBar;
 DrawDropDown;
 AfterDesktop;
 ShowMouse;
 NeedDraw:=False;
End;

{ Redessine une seule fenetre (si elle est au dessus) ou tout le bureau }
Procedure RedrawWin(N: Integer);
Begin
 If (ZOrd[3]=N) And Win[N].Open Then Begin
  HideMouse;
  DrawWindow(N);
  ShowMouse;
 End Else DrawDesktop;
End;

{ Redessine uniquement le contenu (sans les barres) de la fenetre du dessus }
Procedure RedrawContent(N: Integer);
Var X1,Y1,X2,Y2: Integer;
Begin
 If (ZOrd[3]<>N) Or (Not Win[N].Open) Then Begin DrawDesktop;Exit;End;
 HideMouse;
 WinClient(N,X1,Y1,X2,Y2);
 Case N Of
  W_EDIT: DrawEditContent(X1,Y1,X2,Y2);
  W_LIST: DrawListContent(X1,Y1,X2,Y2);
  W_OUT:  DrawOutContent(X1,Y1,X2,Y2);
  W_CMD:  DrawCmdContent(X1,Y1,X2,Y2);
 End;
 SetViewPort(0,0,SCR_W-1,SCR_H-1,True);
 DrawScrollBars(N,True);
 ShowMouse;
End;

{ ====================================================================== }
{                   EVENEMENTS (clavier / souris)                        }
{ ====================================================================== }

Procedure PollEvent(Var E: TEvent);
Var Ch: Char; K: Word;
Begin
 E.Kind:=0;E.Key:=0;E.X:=MX;E.Y:=MY;E.B:=MB;
 If KeyPressed Then Begin
  Ch:=ReadKey;
  If Ch=#0 Then K:=256+Ord(ReadKey) Else K:=Ord(Ch);
  E.Kind:=1;E.Key:=K;
  Exit;
 End;
 PrevMX:=MX;PrevMY:=MY;LastB:=MB;
 GetMouseState(MX,MY,MB);
 E.X:=MX;E.Y:=MY;E.B:=MB;
 If ((MB And 3)<>0) And ((LastB And 3)=0) Then E.Kind:=2
 Else If ((MB And 3)=0) And ((LastB And 3)<>0) Then E.Kind:=3
 Else If (MX<>PrevMX) Or (MY<>PrevMY) Then E.Kind:=4;
 {$IFDEF FPC}
 If (E.Kind<>0) And CurShown And ((MX<>CurX) Or (MY<>CurY)) Then
  CursorDraw(MX,MY);
 {$ENDIF}
 If E.Kind=0 Then Delay(3);
End;

{ ====================================================================== }
{                       BOITES DE DIALOGUE (GEM)                         }
{ ====================================================================== }

Procedure GemBox(X1,Y1,X2,Y2: Integer);
Begin
 Box(X1+3,Y1+3,X2+3,Y2+3,INK);
 Box(X1,Y1,X2,Y2,PAPER);
 Frame(X1,Y1,X2,Y2);
 Frame(X1+3,Y1+3,X2-3,Y2-3);
 Frame(X1+4,Y1+4,X2-4,Y2-4);
End;

{ Sauvegarde / restauration de l'arriere-plan d'une boite }
Type
 TSave = Record
  P : Pointer;
  Sz: LongInt;
  X,Y: Integer;
 End;

Procedure SaveBack(Var S: TSave; X1,Y1,X2,Y2: Integer);
Begin
 If X2>SCR_W-1 Then X2:=SCR_W-1;
 If Y2>SCR_H-1 Then Y2:=SCR_H-1;
 S.X:=X1;S.Y:=Y1;
 S.Sz:=ImageSize(X1,Y1,X2,Y2);
 GetMem(S.P,S.Sz);
 GetImage(X1,Y1,X2,Y2,S.P^);
End;

Procedure RestoreBack(Var S: TSave);
Begin
 If S.P<>Nil Then Begin
  PutImage(S.X,S.Y,S.P^,NormalPut);
  FreeMem(S.P,S.Sz);
  S.P:=Nil;
 End;
End;

{ Boite d'alerte : lignes separees par '|' ; boutons separes par '|' ;
  retourne le numero du bouton choisi (le premier est le bouton par defaut) }
Function AlertBox(Const Txt,Btns: String): Integer;
Var Lines: Array[1..12] Of String[60]; BT: Array[1..4] Of String[16];
    N,NB,I,W,H,X1,Y1,X2,Y2,P,BW,BX0,BY: Integer; S: String; E: TEvent;
    Done: Boolean; Sv: TSave; R: Integer; Left: Boolean;
Begin
 N:=0;S:=Txt;
 Left:=(S<>'') And (S[1]='~');
 If Left Then Delete(S,1,1);
 While (S<>'') And (N<12) Do Begin
  P:=Pos('|',S);
  Inc(N);
  If P=0 Then Begin Lines[N]:=Copy(S,1,60);S:='';End
  Else Begin Lines[N]:=Copy(S,1,P-1);Delete(S,1,P);End;
 End;
 NB:=0;S:=Btns;
 While (S<>'') And (NB<4) Do Begin
  P:=Pos('|',S);
  Inc(NB);
  If P=0 Then Begin BT[NB]:=Copy(S,1,16);S:='';End
  Else Begin BT[NB]:=Copy(S,1,P-1);Delete(S,1,P);End;
 End;
 If NB=0 Then Begin NB:=1;BT[1]:='OK';End;
 W:=NB*88+24;
 For I:=1 To N Do If TextW(Lines[I])+48>W Then W:=TextW(Lines[I])+48;
 If W<200 Then W:=200;
 H:=N*16+84;
 X1:=(SCR_W-W) Div 2;X2:=X1+W;
 Y1:=(SCR_H-H) Div 2;Y2:=Y1+H;
 HideMouse;
 SaveBack(Sv,X1,Y1,X2+4,Y2+4);
 GemBox(X1,Y1,X2,Y2);
 For I:=1 To N Do
  If Left Then PText(X1+24,Y1+22+(I-1)*16,Lines[I])
  Else PText((X1+X2-TextW(Lines[I])) Div 2,Y1+22+(I-1)*16,Lines[I]);
 BW:=72;
 BX0:=(X1+X2-(NB*BW+(NB-1)*16)) Div 2;
 BY:=Y2-40;
 For I:=1 To NB Do
  Button(BX0+(I-1)*(BW+16),BY,BX0+(I-1)*(BW+16)+BW,BY+22,BT[I],I=1,True);
 ShowMouse;
 Done:=False;R:=1;
 Repeat
  PollEvent(E);
  If E.Kind=1 Then Begin
   If E.Key=K_ENTER Then Begin R:=1;Done:=True;End;
   If E.Key=K_ESC Then Begin R:=NB;Done:=True;End;
  End Else If E.Kind=2 Then Begin
   For I:=1 To NB Do
    If InBox(E.X,E.Y,BX0+(I-1)*(BW+16),BY,BX0+(I-1)*(BW+16)+BW,BY+22) Then Begin
     R:=I;Done:=True;
    End;
  End;
 Until Done;
 HideMouse;
 RestoreBack(Sv);
 ShowMouse;
 AlertBox:=R;
End;

Procedure MsgBox(Const Txt: String);
Var R: Integer;
Begin
 R:=AlertBox(Txt,'OK');
End;

{ Formulaire a N champs de saisie ; retourne True si OK }
Var
 FormLbl : Array[1..4] Of String[24];
 FormVal : Array[1..4] Of String[70];
 FormFW  : Integer;

Function FormBox(Const Title: String; N: Integer; Const Info: String): Boolean;
Var W,H,X1,Y1,X2,Y2,I,F,LW,FX: Integer; E: TEvent; Done,Ok,Fresh: Boolean;
    Sv: TSave; Ch: Char; OkS,CaS: String; BY: Integer;
Begin
 OkS:='OK';CaS:=T3('Cancel','Annuler','Abbruch');
 LW:=0;
 For I:=1 To N Do If Length(FormLbl[I])>LW Then LW:=Length(FormLbl[I]);
 LW:=LW*8+8;
 W:=LW+FormFW*8+40;
 If W<TextW(Title)+60 Then W:=TextW(Title)+60;
 If W<260 Then W:=260;
 H:=N*28+110;
 If Info<>'' Then H:=H+18;
 X1:=(SCR_W-W) Div 2;X2:=X1+W;Y1:=(SCR_H-H) Div 2;Y2:=Y1+H;
 FX:=X1+20+LW;
 F:=1;Fresh:=True;Done:=False;Ok:=False;
 HideMouse;
 SaveBack(Sv,X1,Y1,X2+4,Y2+4);
 Repeat
  HideMouse;
  GemBox(X1,Y1,X2,Y2);
  BText((X1+X2-TextW(Title)) Div 2,Y1+14,Title);
  If Info<>'' Then PText(X1+20,Y1+32,Info);
  BY:=Y1+36;
  If Info<>'' Then Inc(BY,18);
  For I:=1 To N Do Begin
   PText(X1+20,BY+(I-1)*28+5,FormLbl[I]);
   Box(FX,BY+(I-1)*28,FX+FormFW*8+4,BY+(I-1)*28+17,PAPER);
   SetColor(INK);
   Line(FX,BY+(I-1)*28+17,FX+FormFW*8+4,BY+(I-1)*28+17);
   PText(FX+2,BY+(I-1)*28+5,FormVal[I]);
   If I=F Then Begin
    Box(FX+2+Length(FormVal[I])*8,BY+(I-1)*28+3,
        FX+2+Length(FormVal[I])*8+7,BY+(I-1)*28+15,INK);
   End;
  End;
  Button(X1+20,Y2-40,X1+20+80,Y2-18,OkS,True,True);
  Button(X2-20-90,Y2-40,X2-20,Y2-18,CaS,False,True);
  ShowMouse;
  Repeat
   PollEvent(E);
   If E.Kind=1 Then Begin
    Case E.Key Of
     K_ENTER: Begin Ok:=True;Done:=True;End;
     K_ESC: Done:=True;
     K_TAB,K_DOWN: Begin Inc(F);If F>N Then F:=1;Fresh:=True;End;
     K_UP: Begin Dec(F);If F<1 Then F:=N;Fresh:=True;End;
     K_BKSP: If Length(FormVal[F])>0 Then
       FormVal[F][0]:=Chr(Length(FormVal[F])-1);
    Else
     If (E.Key>=32) And (E.Key<256) Then Begin
      If Fresh Then FormVal[F]:='';
      If Length(FormVal[F])<FormFW Then FormVal[F]:=FormVal[F]+Chr(E.Key);
     End;
    End;
    If (E.Key<>K_TAB) And (E.Key<>K_DOWN) And (E.Key<>K_UP) Then Fresh:=False;
   End Else If E.Kind=2 Then Begin
    If InBox(E.X,E.Y,X1+20,Y2-40,X1+20+80,Y2-18) Then Begin Ok:=True;Done:=True;End
    Else If InBox(E.X,E.Y,X2-20-90,Y2-40,X2-20,Y2-18) Then Done:=True
    Else
     For I:=1 To N Do
      If InBox(E.X,E.Y,FX,BY+(I-1)*28,FX+FormFW*8+4,BY+(I-1)*28+17) Then
       Begin F:=I;Fresh:=False;E.Kind:=1;End;
   End;
  Until Done Or (E.Kind=1);
 Until Done;
 HideMouse;
 RestoreBack(Sv);
 ShowMouse;
 FormBox:=Ok;
End;

{ ------------------------- selecteur d'elements ------------------------ }

Var
 FsItem  : Array[1..300] Of String[14];
 FsDir   : Array[1..300] Of Boolean;
 FsN     : Integer;

Procedure FsScan(Const Dir,Mask: String);
Var SR: SearchRec; I,J: Integer; T: String[14]; TD: Boolean;
Begin
 FsN:=0;
 If Length(Dir)>1 Then Begin FsN:=1;FsItem[1]:='..';FsDir[1]:=True;End;
 FindFirst(Dir+'*',Directory,SR);
 While (DosError=0) And (FsN<299) Do Begin
  If ((SR.Attr And Directory)<>0) And (SR.Name<>'.') And (SR.Name<>'..') Then Begin
   Inc(FsN);FsItem[FsN]:=Copy(SR.Name,1,14);FsDir[FsN]:=True;
  End;
  FindNext(SR);
 End;
 {$IFDEF FPC}
 FindClose(SR);
 {$ENDIF}
 FindFirst(Dir+Mask,AnyFile-Directory,SR);
 While (DosError=0) And (FsN<299) Do Begin
  If (SR.Attr And Directory)=0 Then Begin
   Inc(FsN);FsItem[FsN]:=Copy(SR.Name,1,14);FsDir[FsN]:=False;
  End;
  FindNext(SR);
 End;
 {$IFDEF FPC}
 FindClose(SR);
 {$ENDIF}
 For I:=1 To FsN-1 Do
  For J:=I+1 To FsN Do
   If (FsDir[J] And Not FsDir[I]) Or
      ((FsDir[J]=FsDir[I]) And (Upper(FsItem[J])<Upper(FsItem[I]))) Then Begin
    T:=FsItem[I];FsItem[I]:=FsItem[J];FsItem[J]:=T;
    TD:=FsDir[I];FsDir[I]:=FsDir[J];FsDir[J]:=TD;
   End;
End;

Function CurDirStr: String;
Var S: String;
Begin
 GetDir(0,S);
 If (S<>'') And (S[Length(S)]<>'\') And (S[Length(S)]<>'/') Then
  S:=S+{$IFDEF MSWINDOWS}'\'{$ELSE}'/'{$ENDIF};
 CurDirStr:=S;
End;

{ Selecteur d'elements GEM : Dir = repertoire, Mask = masque, Sel = nom }
Function FileSelect(Const Title,Mask: String; Var Sel: String): Boolean;
Const ROWS = 9;
Var X1,Y1,X2,Y2,I,Top,Cur,LX,LY,LW: Integer; E: TEvent; Done,Ok,Redraw: Boolean;
    Dir,Msk,S: String; Sv: TSave; LastClk: LongInt; LastIdx,Fld: Integer;
    SelS: String;
 Procedure Rescan;
 Begin
  FsScan(Dir,Msk);
  Top:=1;Cur:=0;
 End;
Begin
 Dir:=CurDirStr;Msk:=Mask;SelS:=Sel;
 Rescan;
 X1:=(SCR_W-360) Div 2;X2:=X1+360;Y1:=(SCR_H-262) Div 2;Y2:=Y1+262;
 LX:=X1+24;LY:=Y1+86;LW:=240;
 Done:=False;Ok:=False;Redraw:=True;LastClk:=0;LastIdx:=0;Fld:=2;
 HideMouse;
 SaveBack(Sv,X1,Y1,X2+4,Y2+4);
 Repeat
  If Redraw Then Begin
   HideMouse;
   GemBox(X1,Y1,X2,Y2);
   BText((X1+X2-TextW('ITEM SELECTOR')) Div 2,Y1+12,'ITEM SELECTOR');
   PText(X1+20,Y1+30,'Directory:');
   Box(X1+20,Y1+42,X2-20,Y1+58,PAPER);
   SetColor(INK);Line(X1+20,Y1+58,X2-20,Y1+58);
   PText(X1+22,Y1+46,Copy(Dir+Msk,Length(Dir+Msk)-Min2(Length(Dir+Msk),42)+1,43));
   PText(X1+20,Y1+66,'Selection:');
   Box(X1+110,Y1+62,X2-20,Y1+78,PAPER);
   Line(X1+110,Y1+78,X2-20,Y1+78);
   PText(X1+112,Y1+66,Copy(SelS,1,28));
   If Fld=2 Then Box(X1+112+Length(Copy(SelS,1,28))*8,Y1+64,
                     X1+119+Length(Copy(SelS,1,28))*8,Y1+76,INK);
   Frame(LX,LY,LX+LW,LY+ROWS*16+2);
   For I:=0 To ROWS-1 Do
    If Top+I<=FsN Then Begin
     If Top+I=Cur Then Begin
      Box(LX+1,LY+1+I*16,LX+LW-1,LY+16+I*16,INK);
      If FsDir[Top+I] Then WText(LX+8,LY+5+I*16,'\'+FsItem[Top+I])
      Else WText(LX+8,LY+5+I*16,FsItem[Top+I]);
     End Else Begin
      If FsDir[Top+I] Then PText(LX+8,LY+5+I*16,'\'+FsItem[Top+I])
      Else PText(LX+8,LY+5+I*16,FsItem[Top+I]);
     End;
    End;
   { barre de defilement }
   ArrowBox(LX+LW+1,LY,LX+LW+SB,LY+SB-1,1);
   ArrowBox(LX+LW+1,LY+ROWS*16+2-SB+1,LX+LW+SB,LY+ROWS*16+2,2);
   PatBar(LX+LW+2,LY+SB,LX+LW+SB-1,LY+ROWS*16+2-SB,PatChecker);
   Button(X2-100,Y1+100,X2-20,Y1+124,'OK',True,True);
   Button(X2-100,Y1+136,X2-20,Y1+160,T3('Cancel','Annuler','Abbruch'),False,True);
   ShowMouse;
   Redraw:=False;
  End;
  PollEvent(E);
  If E.Kind=1 Then Begin
   Case E.Key Of
    K_ENTER: Begin
      If SelS<>'' Then Begin Ok:=True;Done:=True;End
      Else If (Cur>0) And (Not FsDir[Cur]) Then Begin SelS:=FsItem[Cur];Ok:=True;Done:=True;End;
     End;
    K_ESC: Done:=True;
    K_UP: If Cur>1 Then Begin Dec(Cur);If Cur<Top Then Top:=Cur;
          If Not FsDir[Cur] Then SelS:=FsItem[Cur];Redraw:=True;End;
    K_DOWN: If Cur<FsN Then Begin Inc(Cur);If Cur>Top+ROWS-1 Then Top:=Cur-ROWS+1;
          If Not FsDir[Cur] Then SelS:=FsItem[Cur];Redraw:=True;End;
    K_BKSP: If Length(SelS)>0 Then Begin SelS[0]:=Chr(Length(SelS)-1);Redraw:=True;End;
   Else
    If (E.Key>=32) And (E.Key<256) And (Length(SelS)<28) Then Begin
     SelS:=SelS+Chr(E.Key);Redraw:=True;
    End;
   End;
  End Else If E.Kind=2 Then Begin
   If InBox(E.X,E.Y,X2-100,Y1+100,X2-20,Y1+124) Then Begin
    If SelS<>'' Then Begin Ok:=True;Done:=True;End;
   End Else If InBox(E.X,E.Y,X2-100,Y1+136,X2-20,Y1+160) Then Done:=True
   Else If InBox(E.X,E.Y,LX+LW+1,LY,LX+LW+SB,LY+SB-1) Then Begin
    If Top>1 Then Dec(Top);Redraw:=True;
   End Else If InBox(E.X,E.Y,LX+LW+1,LY+ROWS*16+2-SB+1,LX+LW+SB,LY+ROWS*16+2) Then Begin
    If Top+ROWS-1<FsN Then Inc(Top);Redraw:=True;
   End Else If InBox(E.X,E.Y,LX,LY,LX+LW,LY+ROWS*16+2) Then Begin
    I:=Top+(E.Y-LY-1) Div 16;
    If (I>=1) And (I<=FsN) Then Begin
     If (I=LastIdx) And (NowCs-LastClk<60) Then Begin
      If FsDir[I] Then Begin
       { changement de repertoire }
       If FsItem[I]='..' Then Begin
        S:=Dir;
        If (S<>'') Then Delete(S,Length(S),1);
        While (S<>'') And (S[Length(S)]<>'\') And (S[Length(S)]<>'/') Do
         Delete(S,Length(S),1);
        Dir:=S;
       End Else Dir:=Dir+FsItem[I]+{$IFDEF MSWINDOWS}'\'{$ELSE}'/'{$ENDIF};
       If Dir='' Then Dir:={$IFDEF MSWINDOWS}'\'{$ELSE}'/'{$ENDIF};
       Rescan;
      End Else Begin SelS:=FsItem[I];Ok:=True;Done:=True;End;
     End Else Begin
      Cur:=I;
      If Not FsDir[I] Then SelS:=FsItem[I];
     End;
     LastIdx:=I;LastClk:=NowCs;
     Redraw:=True;
    End;
   End Else If InBox(E.X,E.Y,X1+20,Y1+42,X2-20,Y1+58) Then Begin
    { edition du masque / repertoire }
    FormLbl[1]:='Directory';FormVal[1]:=Dir+Msk;FormFW:=40;
    HideMouse;RestoreBack(Sv);ShowMouse;
    If FormBox(Title,1,'') Then Begin
     S:=FormVal[1];
     I:=Length(S);
     While (I>0) And (S[I]<>'\') And (S[I]<>'/') Do Dec(I);
     Dir:=Copy(S,1,I);Msk:=Copy(S,I+1,60);
     If Msk='' Then Msk:=Mask;
     If Dir='' Then Dir:=CurDirStr;
     Rescan;
    End;
    HideMouse;
    SaveBack(Sv,X1,Y1,X2+4,Y2+4);
    Redraw:=True;
   End;
  End;
 Until Done;
 HideMouse;
 RestoreBack(Sv);
 ShowMouse;
 If Ok Then Begin
  If Dir<>CurDirStr Then Sel:=Dir+SelS Else Sel:=SelS;
 End;
 FileSelect:=Ok;
End;

{ ====================================================================== }
{                         MENUS DEROULANTS                               }
{ ====================================================================== }

Const
 NMENU = 5;
 MTitle : Array[1..NMENU] Of String[40] =
  ('Desk~Bureau~Desk','File~Fichier~Datei','Run~Ex'#130'cute~Start',
   'Edit~Edite~Bearb.','Debug~Debug~Debug');

Var
 MenuOpen,MenuHi : Integer;
 RunningProg,BrokenProg,CanCont : Boolean;
 MenuSave : TSave;
 MenuSaved: Boolean;

Function MCount(M: Integer): Integer;
Begin
 Case M Of
  1: MCount:=6;
  2: MCount:=5;
  3: MCount:=6;
  4: MCount:=15;
  5: MCount:=4;
 Else MCount:=0;
 End;
End;

Function MLabel(M,I: Integer): String;
Begin
 MLabel:='';
 Case M Of
  1: Case I Of
      1: MLabel:=T3('About ST BASIC...','A propos de ST BASIC...','Ueber ST BASIC...');
      2: MLabel:='-';
      3: MLabel:='VT52 Emulator';
      4: MLabel:='Control Panel';
      5: MLabel:='Set RS232 Config.';
      6: MLabel:='Install Printer';
     End;
  2: Case I Of
      1: MLabel:=T3('Load','Charger','Laden');
      2: MLabel:=T3('Save As','Sauver sous','Speichern als');
      3: MLabel:=T3('Delete File','Supprimer fichier','Datei loeschen');
      4: MLabel:=T3('Merge','Fusionner','Mischen');
      5: MLabel:=T3('Quit','Quitter','Beenden');
     End;
  3: Case I Of
      1: MLabel:=T3('Run','Ex'#130'cuter','Starten');
      2: MLabel:=T3('Break','Arr'#136'ter','Unterbrechen');
      3: MLabel:=T3('Stop','Stop','Stop');
      4: MLabel:=T3('Continue','Continuer','Fortsetzen');
      5: MLabel:=T3('Step','Pas '#133' pas','Einzelschritt');
      6: MLabel:=T3('Buf Graphics','Tampon graph.','Grafikpuffer');
     End;
  4: Case I Of
      1: MLabel:=T3('Start Edit','D'#130'but '#130'dition','Edit starten');
      2: MLabel:=T3('Exit Edit','Quitter '#130'dition','Edit beenden');
      3: MLabel:=T3('Help Edit','Aide '#130'dition','Edit-Hilfe');
      4: MLabel:=T3('Goto Line ..','Aller '#133' ligne ..','Gehe zu Zeile ..');
      5: MLabel:=T3('Delete Lines ..','Suppr. lignes ..','Zeilen loesch. ..');
      6: MLabel:=T3('Insert Space','Ins'#130'rer espace','Leerzeichen einf.');
      7: MLabel:=T3('Delete Char','Suppr. caract.','Zeichen loeschen');
      8: MLabel:=T3('Insert Line','Ins'#130'rer ligne','Zeile einfuegen');
      9: MLabel:=T3('Remove Line','Retirer ligne','Zeile entfernen');
     10: MLabel:=T3('Page Up','Page pr'#130'c.','Seite hoch');
     11: MLabel:=T3('Page Down','Page suiv.','Seite runter');
     12: MLabel:=T3('Load Text','Charger texte','Text laden');
     13: MLabel:=T3('Save Text','Sauver texte','Text speichern');
     14: MLabel:=T3('New Buffer','Nouveau tampon','Neuer Puffer');
     15: MLabel:=T3('List','Liste','Liste');
     End;
  5: Case I Of
      1: MLabel:='Tron';
      2: MLabel:='Troff';
      3: MLabel:='Trace';
      4: MLabel:='Untrace';
     End;
 End;
End;

Function MIsSep(M,I: Integer): Boolean;
Begin
 MIsSep:=(MLabel(M,I)='-');
End;

Function MEnabled(M,I: Integer): Boolean;
Begin
 MEnabled:=True;
 If RunningProg And (MouseLock>0) Then Begin
  MEnabled:=((M=3) And ((I=2) Or (I=3))) Or ((M=2) And (I=5));
  Exit;
 End;
 Case M Of
  1: If I>=3 Then MEnabled:=False;
  3: Case I Of
      2: MEnabled:=RunningProg Or EditMode;
      3: MEnabled:=BrokenProg;
      4: MEnabled:=CanCont;
     End;
  4: If (I=2) Or ((I>=4) And (I<=14)) Then MEnabled:=EditMode;
 End;
End;

Function MChecked(M,I: Integer): Boolean;
Begin
 MChecked:=(M=3) And (I=6) And BufGfx;
End;

Function MT(I: Integer): String;
Begin
 MT:=Part3(MTitle[I],Lang);
End;

Function MenuX(M: Integer): Integer;
Var I,X: Integer;
Begin
 X:=24;
 For I:=1 To M-1 Do X:=X+(Length(MT(I))+2)*8;
 MenuX:=X;
End;

Function ItemH(M,I: Integer): Integer;
Begin
 If MIsSep(M,I) Then ItemH:=8 Else ItemH:=16;
End;

Procedure DropRect(M: Integer; Var X1,Y1,X2,Y2: Integer);
Var I,W,L: Integer; S: String;
Begin
 W:=0;Y2:=MENU_H+2;
 For I:=1 To MCount(M) Do Begin
  S:=MLabel(M,I);
  L:=Length(S)*8;
  If L>W Then W:=L;
  Y2:=Y2+ItemH(M,I);
 End;
 X1:=MenuX(M)-8;
 X2:=X1+W+32;
 If X2>SCR_W-4 Then Begin X1:=X1-(X2-(SCR_W-4));X2:=SCR_W-4;End;
 Y1:=MENU_H;
 Y2:=Y2+1;
End;

Function ItemY(M,I: Integer): Integer;
Var K,Y: Integer;
Begin
 Y:=MENU_H+2;
 For K:=1 To I-1 Do Y:=Y+ItemH(M,K);
 ItemY:=Y;
End;

Function DropHit(M: Integer; X,Y: LongInt): Integer;
Var X1,Y1,X2,Y2,I: Integer;
Begin
 DropHit:=0;
 DropRect(M,X1,Y1,X2,Y2);
 If Not InBox(X,Y,X1,Y1,X2,Y2) Then Exit;
 For I:=1 To MCount(M) Do
  If (Y>=ItemY(M,I)) And (Y<ItemY(M,I)+ItemH(M,I)) Then DropHit:=I;
End;

Function TitleHit(X,Y: LongInt): Integer;
Var M: Integer;
Begin
 TitleHit:=0;
 If (Y<0) Or (Y>=MENU_H) Then Exit;
 For M:=1 To NMENU Do
  If (X>=MenuX(M)-8) And (X<=MenuX(M)+Length(MT(M))*8+7) Then TitleHit:=M;
End;

Procedure DrawMenuBar;
Var M: Integer;
Begin
 Box(0,0,SCR_W-1,MENU_H-1,PAPER);
 SetColor(INK);
 SetLineStyle(SolidLn,0,1);
 Line(0,MENU_H-1,SCR_W-1,MENU_H-1);
 For M:=1 To NMENU Do Begin
  If M=MenuOpen Then Begin
   Box(MenuX(M)-8,0,MenuX(M)+Length(MT(M))*8+7,MENU_H-2,INK);
   WText(MenuX(M),5,MT(M));
  End Else PText(MenuX(M),5,MT(M));
 End;
End;

Procedure DrawDropDown;
Var X1,Y1,X2,Y2,I,Y: Integer; S: String; Hi: Boolean;
Begin
 If MenuOpen=0 Then Exit;
 DropRect(MenuOpen,X1,Y1,X2,Y2);
 Box(X1+3,Y1+3,X2+3,Y2+3,INK);
 Box(X1,Y1,X2,Y2,PAPER);
 Frame(X1,Y1,X2,Y2);
 For I:=1 To MCount(MenuOpen) Do Begin
  S:=MLabel(MenuOpen,I);
  Y:=ItemY(MenuOpen,I);
  If S='-' Then Begin
   SetLineStyle(UserBitLn,$AAAA,1);
   SetColor(INK);
   Line(X1+2,Y+3,X2-2,Y+3);
   SetLineStyle(SolidLn,0,1);
  End Else Begin
   Hi:=(I=MenuHi) And MEnabled(MenuOpen,I);
   If Hi Then Box(X1+1,Y,X2-1,Y+15,INK);
   If MChecked(MenuOpen,I) Then Begin
    If Hi Then WText(X1+4,Y+4,#251) Else PText(X1+4,Y+4,#251);
   End;
   If Not MEnabled(MenuOpen,I) Then GreyText(X1+16,Y+4,S)
   Else If Hi Then WText(X1+16,Y+4,S)
   Else PText(X1+16,Y+4,S);
  End;
 End;
End;

Procedure DoMenu(M,I: Integer); Forward;

Function NextItem(M,From,Dir: Integer): Integer;
Var I,N,K: Integer;
Begin
 N:=MCount(M);
 I:=From;
 For K:=1 To N Do Begin
  I:=I+Dir;
  If I<1 Then I:=N;
  If I>N Then I:=1;
  If (Not MIsSep(M,I)) And MEnabled(M,I) Then Begin NextItem:=I;Exit;End;
 End;
 NextItem:=From;
End;

Procedure ShowDrop(M,Hi: Integer);
Var X1,Y1,X2,Y2: Integer;
Begin
 HideMouse;
 If MenuSaved Then RestoreBack(MenuSave);
 MenuSaved:=False;
 MenuOpen:=M;MenuHi:=Hi;
 DrawMenuBar;
 If M>0 Then Begin
  DropRect(M,X1,Y1,X2,Y2);
  SaveBack(MenuSave,X1,Y1,X2+4,Y2+4);
  MenuSaved:=True;
  DrawDropDown;
 End;
 ShowMouse;
End;

{ Gestion du menu : ouvert par survol du titre (comme le GEM) }
Procedure RunMenu(StartM: Integer; ByMouse: Boolean);
Var M,Hi,H,T,X1,Y1,X2,Y2: Integer; E: TEvent; Done,Pick: Boolean;
Begin
 M:=StartM;Hi:=0;
 If Not ByMouse Then Hi:=NextItem(M,0,1);
 MenuSaved:=False;
 ShowDrop(M,Hi);
 Done:=False;Pick:=False;
 Repeat
  PollEvent(E);
  Case E.Kind Of
   4,2: Begin
         T:=TitleHit(E.X,E.Y);
         If (T>0) And (T<>M) Then Begin M:=T;Hi:=0;ShowDrop(M,Hi);End
         Else Begin
          H:=DropHit(M,E.X,E.Y);
          If (H<>0) And (MIsSep(M,H) Or Not MEnabled(M,H)) Then H:=0;
          If H<>Hi Then Begin Hi:=H;ShowDrop(M,Hi);End;
          If E.Kind=2 Then Begin
           If H<>0 Then Begin Pick:=True;Done:=True;End
           Else If T=0 Then Done:=True;
          End;
          If (E.Kind=4) And (T=0) Then Begin
           DropRect(M,X1,Y1,X2,Y2);
           If Not InBox(E.X,E.Y,X1-4,Y1,X2+4,Y2+4) Then Done:=True;
          End;
         End;
        End;
   3: Begin
       H:=DropHit(M,E.X,E.Y);
       If (H<>0) And (Hi=H) And (NowCs>0) Then Begin Pick:=True;Done:=True;End;
      End;
   1: Case E.Key Of
       K_ESC: Done:=True;
       K_LEFT: Begin Dec(M);If M<1 Then M:=NMENU;Hi:=NextItem(M,0,1);ShowDrop(M,Hi);End;
       K_RIGHT: Begin Inc(M);If M>NMENU Then M:=1;Hi:=NextItem(M,0,1);ShowDrop(M,Hi);End;
       K_UP: Begin Hi:=NextItem(M,Hi,-1);ShowDrop(M,Hi);End;
       K_DOWN: Begin Hi:=NextItem(M,Hi,1);ShowDrop(M,Hi);End;
       K_ENTER: If Hi<>0 Then Begin Pick:=True;Done:=True;End;
      End;
  End;
 Until Done;
 ShowDrop(0,0);
 If Pick And (Hi>0) Then DoMenu(M,Hi);
End;

{ ====================================================================== }
{        FENETRE OUTPUT : TAMPON MONOCHROME ET PRIMITIVES GRAPHIQUES      }
{ ====================================================================== }

Const
 BayerM : Array[0..7,0..7] Of Byte = (
  ( 0,32, 8,40, 2,34,10,42),
  (48,16,56,24,50,18,58,26),
  (12,44, 4,36,14,46, 6,38),
  (60,28,52,20,62,30,54,22),
  ( 3,35,11,43, 1,33, 9,41),
  (51,19,59,27,49,17,57,25),
  (15,47, 7,39,13,45, 5,37),
  (63,31,55,23,61,29,53,21));
 { densite de noir (0..64) de chaque couleur de la palette ST }
 ColDens : Array[0..15] Of Byte =
  (0,64,24,34,20,12,28,24,32,44,36,40,44,24,8,28);

Var
 OutBuf,OutMask : PByteArr;
 OCX,OCY        : Integer;         { curseur texte : colonne, ligne }
 OutWidth       : Integer;         { WIDTH : 72 par defaut }
 TxtCol,FilCol,LinCol,FilIdx,FilSty : Integer;
 OutLive,OutPending : Boolean;
 OutFlushCs     : LongInt;
 OGX1,OGY1,OGX2,OGY2 : Integer;    { zone client ecran de la fenetre OUTPUT }
 PX,PY          : Array[0..800] Of Integer;
 IXS            : Array[0..800] Of Integer;

Procedure OutInitBuf;
Begin
 GetMem(OutBuf,OUT_BYTES);
 GetMem(OutMask,OUT_BYTES);
 FillChar(OutBuf^,OUT_BYTES,0);
 OCX:=0;OCY:=0;OutWidth:=72;
 TxtCol:=1;FilCol:=0;LinCol:=1;FilIdx:=1;FilSty:=1;
 OutLive:=False;OutPending:=False;
End;

Procedure OutGeom;
Begin
 WinClient(W_OUT,OGX1,OGY1,OGX2,OGY2);
End;

Procedure OutUpdateLive;
Var I,K,N: Integer; AX1,AY1,AX2,AY2: Integer;
Begin
 OutLive:=False;
 OutGeom;
 If Not Win[W_OUT].Open Then Exit;
 K:=3;
 For I:=0 To 3 Do If ZOrd[I]=W_OUT Then K:=I;
 AX1:=Win[W_OUT].X;AY1:=Win[W_OUT].Y;
 AX2:=AX1+Win[W_OUT].W-1;AY2:=AY1+Win[W_OUT].H-1;
 For I:=K+1 To 3 Do Begin
  N:=ZOrd[I];
  If Win[N].Open Then
   If (Win[N].X<=AX2) And (Win[N].X+Win[N].W-1>=AX1) And
      (Win[N].Y<=AY2) And (Win[N].Y+Win[N].H-1>=AY1) Then Exit;
 End;
 OutLive:=True;
End;

{ Recopie une zone du tampon vers l'ecran (coordonnees du tampon) }
Procedure OBlitRect(BX1,BY1,BX2,BY2: LongInt);
Var LX1,LY1,LX2,LY2,Y,X,A: LongInt; SX,SY: LongInt; InRun: Boolean;
    Row: LongInt; B: Byte;
Begin
 OutGeom;
 LX1:=BX1;If LX1<Win[W_OUT].ScrX Then LX1:=Win[W_OUT].ScrX;
 LY1:=BY1;If LY1<Win[W_OUT].ScrY Then LY1:=Win[W_OUT].ScrY;
 LX2:=BX2;If LX2>Win[W_OUT].ScrX+(OGX2-OGX1) Then LX2:=Win[W_OUT].ScrX+(OGX2-OGX1);
 LY2:=BY2;If LY2>Win[W_OUT].ScrY+(OGY2-OGY1) Then LY2:=Win[W_OUT].ScrY+(OGY2-OGY1);
 If (LX1>LX2) Or (LY1>LY2) Then Exit;
 SetFillStyle(SolidFill,PAPER);
 Bar(OGX1+LX1-Win[W_OUT].ScrX,OGY1+LY1-Win[W_OUT].ScrY,
     OGX1+LX2-Win[W_OUT].ScrX,OGY1+LY2-Win[W_OUT].ScrY);
 SetColor(INK);
 SetLineStyle(SolidLn,0,1);
 If LX2>OUT_W-1 Then LX2:=OUT_W-1;
 If LY2>OUT_H-1 Then LY2:=OUT_H-1;
 For Y:=LY1 To LY2 Do Begin
  Row:=Y*OUT_RB;
  SY:=OGY1+Y-Win[W_OUT].ScrY;
  InRun:=False;A:=0;
  X:=LX1;
  While X<=LX2 Do Begin
   B:=OutBuf^[Row+(X Shr 3)];
   If (B=0) And ((X And 7)=0) And (X+7<=LX2) And (Not InRun) Then Inc(X,8)
   Else Begin
    If (B And (128 Shr (X And 7)))<>0 Then Begin
     If Not InRun Then Begin InRun:=True;A:=X;End;
    End Else If InRun Then Begin
     InRun:=False;
     SX:=OGX1+A-Win[W_OUT].ScrX;
     If A=X-1 Then PutPixel(SX,SY,INK) Else Line(SX,SY,OGX1+X-1-Win[W_OUT].ScrX,SY);
    End;
    Inc(X);
   End;
  End;
  If InRun Then Begin
   SX:=OGX1+A-Win[W_OUT].ScrX;
   If A=LX2 Then PutPixel(SX,SY,INK) Else Line(SX,SY,OGX1+LX2-Win[W_OUT].ScrX,SY);
  End;
 End;
End;

Procedure AfterDesktop;
Begin
 OutUpdateLive;
End;

Procedure OutFlush(Force: Boolean);
Begin
 If Not OutPending Then Exit;
 If Force Or (NowCs-OutFlushCs>=10) Or (NowCs<OutFlushCs) Then Begin
  OutPending:=False;
  OutFlushCs:=NowCs;
  If OutLive Then Begin
   OutGeom;
   OBlitRect(Win[W_OUT].ScrX,Win[W_OUT].ScrY,
             Win[W_OUT].ScrX+(OGX2-OGX1),Win[W_OUT].ScrY+(OGY2-OGY1));
  End;
 End;
End;

Procedure OPlot(X,Y: LongInt; C: Byte);
Var Idx: LongInt; M: Byte; SX,SY: LongInt;
Begin
 If (X<0) Or (X>=OUT_W) Or (Y<0) Or (Y>=OUT_H) Then Exit;
 Idx:=Y*OUT_RB+(X Shr 3);
 M:=128 Shr (X And 7);
 If C<>0 Then OutBuf^[Idx]:=OutBuf^[Idx] Or M
 Else OutBuf^[Idx]:=OutBuf^[Idx] And (Not M);
 If OutLive And (Not OutPending) Then Begin
  SX:=OGX1+X-Win[W_OUT].ScrX;SY:=OGY1+Y-Win[W_OUT].ScrY;
  If (SX>=OGX1) And (SX<=OGX2) And (SY>=OGY1) And (SY<=OGY2) Then Begin
   If C<>0 Then PutPixel(SX,SY,INK) Else PutPixel(SX,SY,PAPER);
  End;
 End;
End;

Function OGet(X,Y: LongInt): Byte;
Begin
 If (X<0) Or (X>=OUT_W) Or (Y<0) Or (Y>=OUT_H) Then Begin OGet:=0;Exit;End;
 If (OutBuf^[Y*OUT_RB+(X Shr 3)] And (128 Shr (X And 7)))<>0 Then OGet:=1
 Else OGet:=0;
End;

Procedure OutClear;
Begin
 FillChar(OutBuf^,OUT_BYTES,0);
 OCX:=0;OCY:=0;
 If OutLive Then Begin OutPending:=True;OutFlush(True);End;
End;

Procedure OutScrollUp;
Begin
 Move(OutBuf^[16*OUT_RB],OutBuf^[0],(OUT_ROWS-1)*16*OUT_RB);
 FillChar(OutBuf^[(OUT_ROWS-1)*16*OUT_RB],16*OUT_RB,0);
 If OutLive Then OutPending:=True;
End;

Procedure OGlyph(Col,Row: Integer; Ch: Char);
Var Y: Integer; B: Byte; Base: LongInt;
Begin
 If (Col<0) Or (Col>=OUT_COLS) Or (Row<0) Or (Row>=OUT_ROWS) Then Exit;
 Base:=LongInt(Row)*16*OUT_RB+Col;
 For Y:=0 To 15 Do Begin
  B:=0;
  If (Y>=4) And (Y<12) And (TxtCol<>0) Then B:=Font8[Ord(Ch),Y-4];
  OutBuf^[Base+LongInt(Y)*OUT_RB]:=B;
 End;
 If OutLive And (Not OutPending) Then
  OBlitRect(Col*8,Row*16,Col*8+7,Row*16+15);
End;

Procedure OutNewLine;
Begin
 OCX:=0;
 Inc(OCY);
 If OCY>=OUT_ROWS Then Begin
  OutScrollUp;
  OCY:=OUT_ROWS-1;
 End;
End;

Procedure OutCh(Ch: Char);
Begin
 Case Ch Of
  #13: OCX:=0;
  #10: OutNewLine;
  #8: If OCX>0 Then Dec(OCX);
  #7: ;
  #9: Begin
    Repeat OGlyph(OCX,OCY,' ');Inc(OCX);Until (OCX Mod 8=0) Or (OCX>=OutWidth);
    If OCX>=OutWidth Then Begin OCX:=OutWidth-1;End;
   End;
 Else
  If OCX>=OutWidth Then OutNewLine;
  OGlyph(OCX,OCY,Ch);
  Inc(OCX);
 End;
End;

Procedure OutStr(Const S: String);
Var I: Integer;
Begin
 For I:=1 To Length(S) Do OutCh(S[I]);
End;

Procedure OutLn(Const S: String);
Begin
 OutStr(S);
 OutNewLine;
End;

Procedure OutGotoXY(C,R: Integer);
Begin
 If C<0 Then C:=0;
 If C>=OUT_COLS Then C:=OUT_COLS-1;
 If R<0 Then R:=0;
 If R>=OUT_ROWS Then R:=OUT_ROWS-1;
 OCX:=C;OCY:=R;
End;

{ ------------------------- motifs de remplissage ----------------------- }

Function FillBit(X,Y: LongInt): Boolean;
Var P,T: Integer; Bk: Boolean;
Begin
 FillBit:=False;
 If FilSty=0 Then Exit;
 If FilCol=0 Then Exit;
 Case FilSty Of
  1: FillBit:=BayerM[Y And 7,X And 7]<ColDens[FilCol And 15];
  3: Begin
      If FilIdx<=6 Then P:=4 Else P:=8;
      T:=(FilIdx-1) Mod 6;
      Bk:=False;
      Case T Of
       0: Bk:=(Y Mod P)=0;
       1: Bk:=(X Mod P)=0;
       2: Bk:=((X+Y) Mod P)=0;
       3: Bk:=((X-Y+1024) Mod P)=0;
       4: Bk:=((X Mod P)=0) Or ((Y Mod P)=0);
       5: Bk:=(((X+Y) Mod P)=0) Or (((X-Y+1024) Mod P)=0);
      End;
      FillBit:=Bk;
     End;
 Else
  FillBit:=BayerM[Y And 7,X And 7]<(LongInt(FilIdx)*64 Div 25);
 End;
End;

{ ------------------------- primitives graphiques ----------------------- }

Function LineInk: Byte;
Begin
 If LinCol=0 Then LineInk:=0 Else LineInk:=1;
End;

Procedure OLine(X1,Y1,X2,Y2: LongInt; C: Byte);
Var DX,DY,SX,SY,Err,E2: LongInt; Fin: Boolean;
Begin
 DX:=Abs(X2-X1);DY:=Abs(Y2-Y1);
 If X1<X2 Then SX:=1 Else SX:=-1;
 If Y1<Y2 Then SY:=1 Else SY:=-1;
 Err:=DX-DY;
 Fin:=False;
 Repeat
  OPlot(X1,Y1,C);
  If (X1=X2) And (Y1=Y2) Then Fin:=True
  Else Begin
   E2:=2*Err;
   If E2>-DY Then Begin Err:=Err-DY;X1:=X1+SX;End;
   If E2<DX Then Begin Err:=Err+DX;Y1:=Y1+SY;End;
  End;
 Until Fin;
End;

{ Remplit PX/PY avec les points d'un arc d'ellipse (angles en 1/10 degre) }
Function ArcPoints(CX,CY,RX,RY,A1,A2: LongInt): Integer;
Var N,I: Integer; A,Span: Real;
Begin
 If A2<=A1 Then A2:=A2+3600;
 Span:=(A2-A1)/10;
 N:=Trunc(Span/360*Pi*(RX+RY)/2.2);
 If N<12 Then N:=12;
 If N>700 Then N:=700;
 For I:=0 To N Do Begin
  A:=(A1/10+Span*I/N)*Pi/180;
  PX[I]:=CX+Round(RX*Cos(A));
  PY[I]:=CY-Round(RY*Sin(A));
 End;
 ArcPoints:=N+1;
End;

Procedure OArc(CX,CY,RX,RY,A1,A2: LongInt);
Var N,I: Integer;
Begin
 N:=ArcPoints(CX,CY,RX,RY,A1,A2);
 For I:=0 To N-2 Do OLine(PX[I],PY[I],PX[I+1],PY[I+1],LineInk);
End;

Procedure OFillPoly(N: Integer);
Var YMin,YMax,Y,I,J,K,CntX,T: Integer; X1,Y1,X2,Y2: Integer; XV: Real; Xa,Xb,X: Integer;
Begin
 If N<3 Then Exit;
 YMin:=PY[0];YMax:=PY[0];
 For I:=1 To N-1 Do Begin
  If PY[I]<YMin Then YMin:=PY[I];
  If PY[I]>YMax Then YMax:=PY[I];
 End;
 If YMin<0 Then YMin:=0;
 If YMax>OUT_H-1 Then YMax:=OUT_H-1;
 For Y:=YMin To YMax Do Begin
  CntX:=0;
  For I:=0 To N-1 Do Begin
   J:=I+1;If J>=N Then J:=0;
   X1:=PX[I];Y1:=PY[I];X2:=PX[J];Y2:=PY[J];
   If ((Y1<=Y) And (Y2>Y)) Or ((Y2<=Y) And (Y1>Y)) Then Begin
    XV:=X1+(Y-Y1)*(X2-X1)/(Y2-Y1);
    If CntX<799 Then Begin IXS[CntX]:=Round(XV);Inc(CntX);End;
   End;
  End;
  For I:=1 To CntX-1 Do Begin
   T:=IXS[I];K:=I-1;
   While (K>=0) And (IXS[K]>T) Do Begin IXS[K+1]:=IXS[K];Dec(K);End;
   IXS[K+1]:=T;
  End;
  I:=0;
  While I+1<CntX Do Begin
   Xa:=IXS[I];Xb:=IXS[I+1];
   For X:=Xa To Xb Do
    If FillBit(X,Y) Then OPlot(X,Y,1) Else OPlot(X,Y,0);
   Inc(I,2);
  End;
 End;
End;

Procedure OPie(CX,CY,RX,RY,A1,A2: LongInt);
Var N: Integer;
Begin
 N:=ArcPoints(CX,CY,RX,RY,A1,A2);
 If ((A2-A1)<3600) And ((A2-A1)>0) Then Begin
  PX[N]:=CX;PY[N]:=CY;Inc(N);
 End;
 OFillPoly(N);
End;

Type
 TSpan = Record X,Y: Integer; End;
Var
 Stk : Array[1..1200] Of TSpan;

Procedure OFlood(X0,Y0: LongInt);
Var Seed: Byte; SP: Integer; X,Y,XL,XR,MinX,MaxX,MinY,MaxY,I: LongInt;
    Add: Boolean;
 Function Masked(X,Y: LongInt): Boolean;
 Begin
  Masked:=(OutMask^[Y*OUT_RB+(X Shr 3)] And (128 Shr (X And 7)))<>0;
 End;
 Procedure SetMask(X,Y: LongInt);
 Begin
  OutMask^[Y*OUT_RB+(X Shr 3)]:=OutMask^[Y*OUT_RB+(X Shr 3)] Or (128 Shr (X And 7));
 End;
 Procedure Push(X,Y: Integer);
 Begin
  If SP<1200 Then Begin Inc(SP);Stk[SP].X:=X;Stk[SP].Y:=Y;End;
 End;
Begin
 If (X0<0) Or (X0>=OUT_W) Or (Y0<0) Or (Y0>=OUT_H) Then Exit;
 Seed:=OGet(X0,Y0);
 FillChar(OutMask^,OUT_BYTES,0);
 SP:=0;Push(X0,Y0);
 MinX:=X0;MaxX:=X0;MinY:=Y0;MaxY:=Y0;
 While SP>0 Do Begin
  X:=Stk[SP].X;Y:=Stk[SP].Y;Dec(SP);
  If (Not Masked(X,Y)) And (OGet(X,Y)=Seed) Then Begin
   XL:=X;
   While (XL>0) And (OGet(XL-1,Y)=Seed) And (Not Masked(XL-1,Y)) Do Dec(XL);
   XR:=X;
   While (XR<OUT_W-1) And (OGet(XR+1,Y)=Seed) And (Not Masked(XR+1,Y)) Do Inc(XR);
   For I:=XL To XR Do SetMask(I,Y);
   If XL<MinX Then MinX:=XL;
   If XR>MaxX Then MaxX:=XR;
   If Y<MinY Then MinY:=Y;
   If Y>MaxY Then MaxY:=Y;
   If Y>0 Then Begin
    Add:=True;
    For I:=XL To XR Do Begin
     If (OGet(I,Y-1)=Seed) And (Not Masked(I,Y-1)) Then Begin
      If Add Then Begin Push(I,Y-1);Add:=False;End;
     End Else Add:=True;
    End;
   End;
   If Y<OUT_H-1 Then Begin
    Add:=True;
    For I:=XL To XR Do Begin
     If (OGet(I,Y+1)=Seed) And (Not Masked(I,Y+1)) Then Begin
      If Add Then Begin Push(I,Y+1);Add:=False;End;
     End Else Add:=True;
    End;
   End;
  End;
 End;
 For Y:=MinY To MaxY Do
  For X:=MinX To MaxX Do
   If Masked(X,Y) Then
    If FillBit(X,Y) Then OPlot(X,Y,1) Else OPlot(X,Y,0);
End;

{ ------------------------------- son ----------------------------------- }

Procedure SoundNote(Voice,Vol,Note,Oct,Dur: Integer);
Var F: Real;
Begin
 If (Vol<=0) Or (Note<=0) Then Begin
  NoSound;
  If Dur>0 Then Delay(Dur*20);
  Exit;
 End;
 F:=440*Exp(Ln(2)*(((Oct-4)*12+Note-10)/12));
 If F<30 Then F:=30;
 If F>10000 Then F:=10000;
 Sound(Round(F));
 If Dur>0 Then Delay(Dur*20);
End;

{ ====================================================================== }
{              MEMOIRE VIRTUELLE ATARI ST (PEEK / POKE / BLOAD)          }
{ ====================================================================== }

{$IFDEF FPC}
Const VMEM_SIZE = $100000;
{$ELSE}
Const VMEM_SIZE = $F000;
{$ENDIF}

Var
 VMem : Array[0..VMEM_SIZE-1] Of Byte;

Function VMemRead(A: LongInt): Byte;
Begin
 If (A>=0) And (A<VMEM_SIZE) Then VMemRead:=VMem[A] Else VMemRead:=0;
End;

Procedure VMemWrite(A: LongInt; B: Byte);
Begin
 If (A>=0) And (A<VMEM_SIZE) Then VMem[A]:=B;
End;


{ Tables ST BASIC en memoire virtuelle (GB, CONTRL, INTIN, PTSIN, SYSTAB...) }
Const
 BAS_BASE   = {$IFDEF FPC}$1E000{$ELSE}$E000{$ENDIF};
 GB_ADDR    = BAS_BASE;
 AES_CTRL   = BAS_BASE+$40;
 AES_GLOBAL = BAS_BASE+$80;
 AES_GINTIN = BAS_BASE+$C0;
 AES_GINTOUT= BAS_BASE+$140;
 AES_ADDRIN = BAS_BASE+$1C0;
 AES_ADDROUT= BAS_BASE+$200;
 VDI_CONTRL = BAS_BASE+$300;
 VDI_INTIN  = BAS_BASE+$340;
 VDI_PTSIN  = BAS_BASE+$440;
 VDI_INTOUT = BAS_BASE+$540;
 VDI_PTSOUT = BAS_BASE+$640;
 VDI_PB     = BAS_BASE+$740;
 SYS_ADDR   = BAS_BASE+$780;
 CALL_ARR   = BAS_BASE+$800;
 CALL_STR   = BAS_BASE+$880;
 GFX_BUF    = {$IFDEF FPC}$F8000{$ELSE}$4000{$ENDIF};

Var
 DefSegV : LongInt;

Function VMemReadW(A: LongInt): LongInt;
Var V: LongInt;
Begin
 V:=(LongInt(VMemRead(A)) Shl 8) Or VMemRead(A+1);
 If V>32767 Then V:=V-65536;
 VMemReadW:=V;
End;

Function VMemReadL(A: LongInt): LongInt;
Begin
 VMemReadL:=(LongInt(VMemRead(A)) Shl 24) Or (LongInt(VMemRead(A+1)) Shl 16) Or
            (LongInt(VMemRead(A+2)) Shl 8) Or VMemRead(A+3);
End;

Procedure VMemWriteW(A,V: LongInt);
Begin
 VMemWrite(A,(V Shr 8) And 255);VMemWrite(A+1,V And 255);
End;

Procedure VMemWriteL(A,V: LongInt);
Begin
 VMemWrite(A,(V Shr 24) And 255);VMemWrite(A+1,(V Shr 16) And 255);
 VMemWrite(A+2,(V Shr 8) And 255);VMemWrite(A+3,V And 255);
End;

Procedure InitBasMem;
Begin
 FillChar(VMem[BAS_BASE],$1000,0);
 VMemWriteL(GB_ADDR,AES_CTRL);VMemWriteL(GB_ADDR+4,AES_GLOBAL);
 VMemWriteL(GB_ADDR+8,AES_GINTIN);VMemWriteL(GB_ADDR+12,AES_GINTOUT);
 VMemWriteL(GB_ADDR+16,AES_ADDRIN);VMemWriteL(GB_ADDR+20,AES_ADDROUT);
 VMemWriteL(VDI_PB,VDI_CONTRL);VMemWriteL(VDI_PB+4,VDI_INTIN);
 VMemWriteL(VDI_PB+8,VDI_PTSIN);VMemWriteL(VDI_PB+12,VDI_INTOUT);
 VMemWriteL(VDI_PB+16,VDI_PTSOUT);
 VMemWriteW(SYS_ADDR,1);
 VMemWriteW(SYS_ADDR+2,1);
 DefSegV:=0;
End;
{ ====================================================================== }
{                    INTERPRETEUR : MEMOIRE PROGRAMME                    }
{ ====================================================================== }

Var
 LNum  : Array[1..MAXL] Of LongInt;
 LTxt  : Array[1..MAXL] Of PString;
 LCnt  : Integer;
 ProgName : String[80];
 LabDirty : Boolean;
 OptBase  : Integer;

Function FindLineIdx(N: LongInt): Integer;
{ index de la premiere ligne dont le numero est >= N (LCnt+1 si aucune) }
Var A,B,M: Integer;
Begin
 A:=1;B:=LCnt+1;
 While A<B Do Begin
  M:=(A+B) Div 2;
  If LNum[M]<N Then A:=M+1 Else B:=M;
 End;
 FindLineIdx:=A;
End;

Function LineIdxExact(N: LongInt): Integer;
Var I: Integer;
Begin
 I:=FindLineIdx(N);
 If (I<=LCnt) And (LNum[I]=N) Then LineIdxExact:=I Else LineIdxExact:=0;
End;

Procedure ProgChanged;
Begin
 LabDirty:=True;
 CanCont:=False;
End;

Procedure SetProgLine(N: LongInt; Const T: String);
Var I,K: Integer;
Begin
 I:=FindLineIdx(N);
 If (I<=LCnt) And (LNum[I]=N) Then Begin
  If TrimStr(T)='' Then Begin
   FreeStr(LTxt[I]);
   For K:=I To LCnt-1 Do Begin LNum[K]:=LNum[K+1];LTxt[K]:=LTxt[K+1];End;
   LTxt[LCnt]:=Nil;
   Dec(LCnt);
  End Else Begin
   FreeStr(LTxt[I]);
   LTxt[I]:=NewStr(TrimStr(T));
  End;
 End Else If TrimStr(T)<>'' Then Begin
  If LCnt>=MAXL Then Exit;
  For K:=LCnt DownTo I Do Begin LNum[K+1]:=LNum[K];LTxt[K+1]:=LTxt[K];End;
  LNum[I]:=N;
  LTxt[I]:=NewStr(TrimStr(T));
  Inc(LCnt);
 End;
 ProgChanged;
End;

Procedure DeleteLines(A,B: LongInt);
Var I: Integer;
Begin
 I:=LCnt;
 While I>=1 Do Begin
  If (LNum[I]>=A) And (LNum[I]<=B) Then SetProgLine(LNum[I],'');
  Dec(I);
 End;
End;

Procedure NewProgram;
Var I: Integer;
Begin
 For I:=1 To LCnt Do FreeStr(LTxt[I]);
 LCnt:=0;
 ProgName:='';
 ProgChanged;
End;

Function LineStr(I: Integer): String;
Begin
 LineStr:=IntStr(LNum[I])+' '+LTxt[I]^;
End;

{ ====================================================================== }
{                              ERREURS                                   }
{ ====================================================================== }

Var
 Src : String;            { texte de l'instruction en cours d'analyse }
 P   : Integer;           { position courante dans Src (base 1) }
 ErrCode  : Integer;      { 0 = pas d'erreur }
 ErrPosP  : Integer;
 ErrLine  : Integer;      { index de ligne ou 0 }
 ErrNum   : Integer;      { ERR visible par le programme }
 ErrLNum  : LongInt;      { ERL }
 InErrH   : Boolean;
 BreakReq : Boolean;      { Ctrl+G ou Ctrl+C demande }

Function ErrEN(C: Integer): String;
Begin
 Case C Of
  2: ErrEN:='Something is wrong';
  3: ErrEN:='RETURN statement needs matching GOSUB';
  4: ErrEN:='READ statement ran out of data';
  5: ErrEN:='Function call not allowed';
  6: ErrEN:='Number too large';
  7: ErrEN:='Not enough memory';
  8: ErrEN:='A statement or a command refers to a nonexistent line';
  9: ErrEN:='Subscript refers to element outside the array';
  10: ErrEN:='You defined an array more than once';
  11: ErrEN:='You cannot divide by zero';
  12: ErrEN:='Statement is illegal in direct mode';
  13: ErrEN:='Types of values do not match';
  15: ErrEN:='Strings cannot be over 255 characters long';
  16: ErrEN:='Expression is too long or too complex';
  17: ErrEN:='CONT works only in Break mode';
  18: ErrEN:='Function needs prior definition with DEF FN';
  20: ErrEN:='RESUME statement found before error routine entered';
  22: ErrEN:='Expression has operator with no following operand';
  23: ErrEN:='Program line too long';
  30: ErrEN:='Window number invalid';
  31: ErrEN:='Argument out of range';
  32: ErrEN:='Command cannot be executed from the editor';
  33: ErrEN:='Line is too complex';
  50: ErrEN:='FIELD statement caused overflow';
  51: ErrEN:='Device number invalid';
  52: ErrEN:='File number or filename invalid';
  53: ErrEN:='File not found on disk drive specified';
  54: ErrEN:='File mode is not valid';
  55: ErrEN:='You cannot OPEN or KILL a file already open';
  57: ErrEN:='Disk input/output error';
  58: ErrEN:='File exists';
  61: ErrEN:='Disk is full';
  62: ErrEN:='You have reached end-of-file';
  63: ErrEN:='The record number in PUT or GET is more than 32767 or zero';
  64: ErrEN:='Invalid filename';
  65: ErrEN:='Invalid character in program file';
  66: ErrEN:='Program file has statement with no line number';
  99: ErrEN:='-- Break --';
  101: ErrEN:='Program has too many lines';
  102: ErrEN:='ON statement is out of range';
  103: ErrEN:='Invalid line number';
  104: ErrEN:='A variable is required';
  106: ErrEN:='Line number does not exist';
  107: ErrEN:='Number too large for an integer';
  108: ErrEN:='Input data is not valid, restart input from first item';
  109: ErrEN:='Stop';
  110: ErrEN:='You have nested subroutine calls too deep';
  111: ErrEN:='Invalid BLOAD file';
  202: ErrEN:='Command not allowed here';
  203: ErrEN:='Line number is required';
  204: ErrEN:='FOR statement needs a NEXT or WHILE statement needs a WEND';
  205: ErrEN:='NEXT statement needs a FOR or WEND statement needs a WHILE';
  206: ErrEN:='A comma is expected';
  207: ErrEN:='A parenthesis is expected';
  208: ErrEN:='Option Base must be 0 or 1';
  209: ErrEN:='Statement end is expected';
  210: ErrEN:='Too many arguments in your list';
  212: ErrEN:='Cannot redefine variable(s)';
  213: ErrEN:='Function defined more than once';
  214: ErrEN:='You are trying to jump into a loop';
  221: ErrEN:='System error #X, please restart';
  222: ErrEN:='Program not run';
  223: ErrEN:='Too many FOR loops';
 Else ErrEN:='Undefined error';
 End;
End;

Function ErrFR(C: Integer): String;
Begin
 Case C Of
  2: ErrFR:='Quelque chose cloche';
  3: ErrFR:='RETURN n'#130'cessite un GOSUB correspondant';
  4: ErrFR:='READ a manqu'#130' de donn'#130'es';
  5: ErrFR:='Appel de fonction non permis';
  6: ErrFR:='Nombre trop grand';
  7: ErrFR:='M'#130'moire insuffisante';
  8: ErrFR:='Une instruction ou une commande r'#130'f'#130'rence une ligne inexistante';
  9: ErrFR:='L''indice d'#130'signe un '#130'l'#130'ment hors du tableau';
  10: ErrFR:='Vous avez d'#130'fini un tableau plus d''une fois';
  11: ErrFR:='Division par z'#130'ro impossible';
  12: ErrFR:='Instruction ill'#130'gale en mode direct';
  13: ErrFR:='Les types de valeurs ne correspondent pas';
  14: ErrFR:='Erreur ind'#130'finie';
  15: ErrFR:='Les cha'#140'nes ne peuvent d'#130'passer 255 caract'#138'res';
  16: ErrFR:='Expression trop longue ou trop complexe';
  17: ErrFR:='CONT ne fonctionne qu''en mode Break';
  18: ErrFR:='La fonction n'#130'cessite une d'#130'finition pr'#130'alable avec DEF FN';
  19: ErrFR:='Erreur ind'#130'finie';
  20: ErrFR:='RESUME trouv'#130' avant l''entr'#130'e dans la routine d''erreur';
  21: ErrFR:='Erreur ind'#130'finie';
  22: ErrFR:='L''expression a un op'#130'rateur sans op'#130'rande suivant';
  23: ErrFR:='Ligne de programme trop longue';
  30: ErrFR:='Num'#130'ro de fen'#136'tre invalide';
  31: ErrFR:='Argument hors limites';
  32: ErrFR:='Commande non ex'#130'cutable depuis l'''#130'diteur';
  33: ErrFR:='La ligne est trop complexe';
  50: ErrFR:='L''instruction FIELD a caus'#130' un d'#130'passement';
  51: ErrFR:='Num'#130'ro de p'#130'riph'#130'rique invalide';
  52: ErrFR:='Num'#130'ro de fichier ou nom de fichier invalide';
  53: ErrFR:='Fichier introuvable sur l''unit'#130' sp'#130'cifi'#130'e';
  54: ErrFR:='Mode de fichier invalide';
  55: ErrFR:='Vous ne pouvez pas faire OPEN ou KILL sur un fichier ouvert';
  56: ErrFR:='Erreur ind'#130'finie';
  57: ErrFR:='Erreur d''entr'#130'e/sortie disque';
  58: ErrFR:='Le fichier existe';
  61: ErrFR:='Disque plein';
  62: ErrFR:='Vous avez atteint la fin du fichier';
  63: ErrFR:='Le num'#130'ro d''enregistrement de PUT ou GET d'#130'passe 32767 ou vaut z'#130'ro';
  64: ErrFR:='Nom de fichier invalide';
  65: ErrFR:='Caract'#138're invalide dans le fichier programme';
  66: ErrFR:='Le fichier programme contient une instruction sans num'#130'ro de ligne';
  99: ErrFR:='-- Break --';
  100: ErrFR:='Erreur ind'#130'finie';
  101: ErrFR:='Le programme a trop de lignes';
  102: ErrFR:='L''instruction ON est hors limites';
  103: ErrFR:='Num'#130'ro de ligne invalide';
  104: ErrFR:='Une variable est requise';
  105: ErrFR:='Erreur ind'#130'finie';
  106: ErrFR:='Le num'#130'ro de ligne n''existe pas';
  107: ErrFR:='Nombre trop grand pour un entier';
  108: ErrFR:='Donn'#130'es d''entr'#130'e invalides, recommencez la saisie depuis le premier '#130'l'#130'ment';
  109: ErrFR:='Stop';
  110: ErrFR:='Appels de sous-programmes imbriqu'#130's trop profond'#130'ment';
  111: ErrFR:='Fichier BLOAD invalide';
  202: ErrFR:='Commande non permise ici';
  203: ErrFR:='Un num'#130'ro de ligne est requis';
  204: ErrFR:='FOR n'#130'cessite un NEXT ou un WHILE correspondant';
  205: ErrFR:='NEXT n'#130'cessite un FOR ou un WEND correspondant';
  206: ErrFR:='Une virgule est attendue';
  207: ErrFR:='Une parenth'#138'se est attendue';
  208: ErrFR:='Option Base doit valoir 0 ou 1';
  209: ErrFR:='Une fin d''instruction est attendue';
  210: ErrFR:='Trop d''arguments dans la liste';
  211: ErrFR:='Non utilis'#130;
  212: ErrFR:='Impossible de red'#130'finir la ou les variables';
  213: ErrFR:='Fonction d'#130'finie plus d''une fois';
  214: ErrFR:='Vous essayez de sauter dans une boucle';
  221: ErrFR:='Erreur syst'#138'me #X, veuillez red'#130'marrer';
  222: ErrFR:='Programme non lanc'#130;
  223: ErrFR:='Trop de boucles FOR';
 Else ErrFR:=ErrEN(C);
 End;
End;

Function ErrDE(C: Integer): String;
Begin
 Case C Of
  2: ErrDE:='Etwas stimmt nicht';
  3: ErrDE:='RETURN braucht ein passendes GOSUB';
  4: ErrDE:='READ hat keine Daten mehr';
  5: ErrDE:='Funktionsaufruf nicht erlaubt';
  6: ErrDE:='Zahl zu gross';
  7: ErrDE:='Nicht genug Speicher';
  8: ErrDE:='Ein Befehl bezieht sich auf eine nicht vorhandene Zeile';
  9: ErrDE:='Index verweist auf ein Element ausserhalb des Feldes';
  10: ErrDE:='Ein Feld wurde mehrfach dimensioniert';
  11: ErrDE:='Division durch Null ist nicht moeglich';
  12: ErrDE:='Anweisung im Direktmodus nicht erlaubt';
  13: ErrDE:='Wertetypen passen nicht zusammen';
  14: ErrDE:='Undefinierter Fehler';
  15: ErrDE:='Zeichenketten duerfen nicht laenger als 255 Zeichen sein';
  16: ErrDE:='Ausdruck ist zu lang oder zu komplex';
  17: ErrDE:='CONT funktioniert nur im Break-Modus';
  18: ErrDE:='Funktion braucht vorher eine Definition mit DEF FN';
  19: ErrDE:='Undefinierter Fehler';
  20: ErrDE:='RESUME vor Betreten der Fehlerroutine gefunden';
  21: ErrDE:='Undefinierter Fehler';
  22: ErrDE:='Ausdruck hat einen Operator ohne folgenden Operanden';
  23: ErrDE:='Programmzeile ist zu lang';
  30: ErrDE:='Fensternummer ungueltig';
  31: ErrDE:='Argument ausserhalb des Bereichs';
  32: ErrDE:='Befehl kann nicht aus dem Editor ausgefuehrt werden';
  33: ErrDE:='Zeile ist zu komplex';
  50: ErrDE:='FIELD-Anweisung verursachte einen Ueberlauf';
  51: ErrDE:='Geraetenummer ungueltig';
  52: ErrDE:='Dateinummer oder Dateiname ungueltig';
  53: ErrDE:='Datei auf dem angegebenen Laufwerk nicht gefunden';
  54: ErrDE:='Dateimodus ist ungueltig';
  55: ErrDE:='Eine offene Datei kann nicht mit OPEN oder KILL bearbeitet werden';
  56: ErrDE:='Undefinierter Fehler';
  57: ErrDE:='Ein-/Ausgabefehler auf der Diskette';
  58: ErrDE:='Datei existiert';
  61: ErrDE:='Diskette ist voll';
  62: ErrDE:='Dateiende erreicht';
  63: ErrDE:='Satznummer bei PUT oder GET ist groesser als 32767 oder Null';
  64: ErrDE:='Ungueltiger Dateiname';
  65: ErrDE:='Ungueltiges Zeichen in der Programmdatei';
  66: ErrDE:='Programmdatei enthaelt eine Anweisung ohne Zeilennummer';
  99: ErrDE:='-- Break --';
  100: ErrDE:='Undefinierter Fehler';
  101: ErrDE:='Programm hat zu viele Zeilen';
  102: ErrDE:='ON-Anweisung ausserhalb des Bereichs';
  103: ErrDE:='Ungueltige Zeilennummer';
  104: ErrDE:='Eine Variable ist erforderlich';
  105: ErrDE:='Undefinierter Fehler';
  106: ErrDE:='Zeilennummer existiert nicht';
  107: ErrDE:='Zahl zu gross fuer eine Ganzzahl';
  108: ErrDE:='Eingabedaten ungueltig, Eingabe ab dem ersten Element wiederholen';
  109: ErrDE:='Stop';
  110: ErrDE:='Unterprogrammaufrufe sind zu tief verschachtelt';
  111: ErrDE:='Ungueltige BLOAD-Datei';
  202: ErrDE:='Befehl hier nicht erlaubt';
  203: ErrDE:='Zeilennummer erforderlich';
  204: ErrDE:='FOR braucht ein passendes NEXT oder WHILE';
  205: ErrDE:='NEXT braucht ein passendes FOR oder WEND';
  206: ErrDE:='Ein Komma wird erwartet';
  207: ErrDE:='Eine Klammer wird erwartet';
  208: ErrDE:='Option Base muss 0 oder 1 sein';
  209: ErrDE:='Ende der Anweisung wird erwartet';
  210: ErrDE:='Zu viele Argumente in der Liste';
  211: ErrDE:='Nicht benutzt';
  212: ErrDE:='Variable(n) koennen nicht neu definiert werden';
  213: ErrDE:='Funktion mehrfach definiert';
  214: ErrDE:='Sprung in eine Schleife nicht moeglich';
  221: ErrDE:='Systemfehler #X, bitte neu starten';
  222: ErrDE:='Programm nicht gestartet';
  223: ErrDE:='Zu viele FOR-Schleifen';
 Else ErrDE:=ErrEN(C);
 End;
End;

Function ErrText(C: Integer): String;
Begin
 Case Lang Of
  0: ErrText:=ErrEN(C);
  2: ErrText:=ErrDE(C);
 Else ErrText:=ErrFR(C);
 End;
End;

Procedure Fail(C: Integer);
Begin
 If ErrCode=0 Then Begin ErrCode:=C;ErrPosP:=P;End;
End;


Procedure BasicVdisys; Forward;
Procedure BasicGemsys(Op: Integer); Forward;
{ ====================================================================== }
{                  FICHIERS DU PROGRAMME BASIC                           }
{ ====================================================================== }

Type
 TFileRec = Record
  Used   : Boolean;
  Mode   : Char;           { I O A R }
  Name   : String[80];
  T      : Text;
  F      : File;
  RecLen : Integer;
  Buf    : PByteArr;
  Rec    : LongInt;
  Pb     : Integer;        { caractere de retour arriere (-1 : aucun) }
  Col    : Integer;
 End;

Var
 FT : Array[1..15] Of TFileRec;

{ ====================================================================== }
{                       ANALYSE LEXICALE                                 }
{ ====================================================================== }

Function Cur: Char;
Begin
 If P<=Length(Src) Then Cur:=Src[P] Else Cur:=#0;
End;

Procedure SkipSp;
Begin
 While (P<=Length(Src)) And ((Src[P]=' ') Or (Src[P]=#9)) Do Inc(P);
End;

Function IsAlpha(C: Char): Boolean;
Begin
 IsAlpha:=((C>='A') And (C<='Z')) Or ((C>='a') And (C<='z'));
End;

Function IsDigit(C: Char): Boolean;
Begin
 IsDigit:=(C>='0') And (C<='9');
End;

Function IsIdCh(C: Char): Boolean;
Begin
 IsIdCh:=IsAlpha(C) Or IsDigit(C) Or (C='.') Or (C='_');
End;

Function ReadWord: String;
Var S: String;
Begin
 SkipSp;
 S:='';
 If IsAlpha(Cur) Then Begin
  While (P<=Length(Src)) And IsIdCh(Src[P]) Do Begin
   S:=S+UpCase(Src[P]);Inc(P);
  End;
  If (Cur='$') Or (Cur='%') Or (Cur='!') Then Begin S:=S+Cur;Inc(P);End;
 End;
 ReadWord:=S;
End;

Function PeekWord: String;
Var S: Integer; W: String;
Begin
 S:=P;W:=ReadWord;P:=S;
 PeekWord:=W;
End;

Function AcceptWord(Const W: String): Boolean;
Var S: Integer; X: String;
Begin
 S:=P;X:=ReadWord;
 If X=W Then AcceptWord:=True Else Begin P:=S;AcceptWord:=False;End;
End;

Function Accept(C: Char): Boolean;
Begin
 SkipSp;
 If Cur=C Then Begin Inc(P);Accept:=True;End Else Accept:=False;
End;

Procedure Expect(C: Char);
Begin
 If Not Accept(C) Then Begin
  If C=')' Then Fail(207) Else If C=',' Then Fail(206) Else Fail(2);
 End;
End;

Function AtStmtEnd: Boolean;
Begin
 SkipSp;
 AtStmtEnd:=(P>Length(Src)) Or (Cur=':') Or (Cur='''') Or (PeekWord='ELSE');
End;

Function HexVal(C: Char): Integer;
Begin
 C:=UpCase(C);
 If (C>='0') And (C<='9') Then HexVal:=Ord(C)-48
 Else If (C>='A') And (C<='F') Then HexVal:=Ord(C)-55
 Else HexVal:=-1;
End;

Function ReadNumber: Real;
Var S: String; V: Real; C: Integer; H: LongInt;
Begin
 ReadNumber:=0;
 If Cur='&' Then Begin
  Inc(P);
  H:=0;
  If UpCase(Cur)='H' Then Begin
   Inc(P);
   While HexVal(Cur)>=0 Do Begin H:=H*16+HexVal(Cur);Inc(P);End;
  End Else Begin
   If UpCase(Cur)='O' Then Inc(P);
   While (Cur>='0') And (Cur<='7') Do Begin H:=H*8+Ord(Cur)-48;Inc(P);End;
  End;
  If H>32767 Then If H<65536 Then H:=H-65536;
  ReadNumber:=H;
  Exit;
 End;
 S:='';
 While IsDigit(Cur) Do Begin S:=S+Cur;Inc(P);End;
 If Cur='.' Then Begin
  S:=S+'.';Inc(P);
  While IsDigit(Cur) Do Begin S:=S+Cur;Inc(P);End;
 End;
 If (UpCase(Cur)='E') Or (UpCase(Cur)='D') Then Begin
  If IsDigit(Src[P+1]) Or (((Src[P+1]='-') Or (Src[P+1]='+')) And IsDigit(Src[P+2])) Then Begin
   S:=S+'E';Inc(P);
   If (Cur='-') Or (Cur='+') Then Begin S:=S+Cur;Inc(P);End;
   While IsDigit(Cur) Do Begin S:=S+Cur;Inc(P);End;
  End;
 End;
 If (S<>'') And (S[1]='.') Then S:='0'+S;
 If Pos('.E',S)>0 Then Insert('0',S,Pos('.E',S)+1);
 If (S<>'') And (S[Length(S)]='.') Then S:=S+'0';
 Val(S,V,C);
 If C<>0 Then Begin Fail(2);V:=0;End;
 ReadNumber:=V;
End;

{ ====================================================================== }
{                     VARIABLES ET TABLEAUX                              }
{ ====================================================================== }

Type
 PVar = ^TVar;
 TIdx = Array[1..8] Of LongInt;
 TVar = Record
  Name  : String[34];
  Next  : PVar;
  Typ   : Byte;            { 0 reel, 1 entier, 2 chaine }
  IsArr : Boolean;
  N     : Real;
  S     : PString;
  NDim  : Byte;
  Dim   : Array[1..8] Of Integer;
  Cnt   : LongInt;
  Data  : Pointer;
  FFile,FOff,FWid : Integer;
 End;
 TRealArr = Array[0..8000] Of Real;
 PRealArr = ^TRealArr;
 TPtrArr  = Array[0..8000] Of PString;
 PPtrArr  = ^TPtrArr;
 TVal = Record
  IsStr : Boolean;
  N     : Real;
  S     : String;
 End;
 TArgs = Array[1..5] Of TVal;

Var
 HashT  : Array[0..127] Of PVar;
 DefTyp : Array[0..25] Of Byte;
 RndLast: Real;

Function VarTypeOf(Const Id: String): Byte;
Var C: Char;
Begin
 C:=Id[Length(Id)];
 Case C Of
  '$': VarTypeOf:=2;
  '%': VarTypeOf:=1;
  '!': VarTypeOf:=0;
 Else VarTypeOf:=DefTyp[Ord(Id[1])-65];
 End;
End;

Function HashOf(Const S: String): Integer;
Var I: Integer; H: LongInt;
Begin
 H:=0;
 For I:=1 To Length(S) Do H:=(H*31+Ord(S[I])) And $7FFFFF;
 HashOf:=H Mod 128;
End;

Function FindVar(Const Id: String; Make: Boolean): PVar;
Var V: PVar; H: Integer; Key: String; L: Integer;
Begin
 Key:=Id;
 L:=Length(Key);
 If L>32 Then Begin
  If (Key[L]='$') Or (Key[L]='%') Or (Key[L]='!') Then
   Key:=Copy(Key,1,31)+Key[L]
  Else Key:=Copy(Key,1,32);
 End;
 H:=HashOf(Key);
 V:=HashT[H];
 While V<>Nil Do Begin
  If V^.Name=Key Then Begin FindVar:=V;Exit;End;
  V:=V^.Next;
 End;
 FindVar:=Nil;
 If Not Make Then Exit;
 New(V);
 FillChar(V^,SizeOf(TVar),0);
 V^.Name:=Key;
 V^.Typ:=VarTypeOf(Key);
 V^.Next:=HashT[H];
 HashT[H]:=V;
 FindVar:=V;
End;

Procedure FreeVarData(V: PVar);
Var I: LongInt;
Begin
 If V^.IsArr Then Begin
  If V^.Data<>Nil Then Begin
   If V^.Typ=2 Then Begin
    For I:=0 To V^.Cnt-1 Do FreeStr(PPtrArr(V^.Data)^[I]);
    FreeMem(V^.Data,V^.Cnt*SizeOf(PString));
   End Else FreeMem(V^.Data,V^.Cnt*SizeOf(Real));
  End;
  V^.Data:=Nil;V^.IsArr:=False;V^.Cnt:=0;V^.NDim:=0;
 End Else If V^.S<>Nil Then FreeStr(V^.S);
End;

Procedure ClearVars;
Var I: Integer; V,W: PVar;
Begin
 For I:=0 To 127 Do Begin
  V:=HashT[I];
  While V<>Nil Do Begin
   W:=V^.Next;
   FreeVarData(V);
   Dispose(V);
   V:=W;
  End;
  HashT[I]:=Nil;
 End;
End;

Procedure DimArray(V: PVar; ND: Integer; Var B: TIdx);
Var I: Integer; C: LongInt; Lo: Integer;
Begin
 If V^.IsArr Then Begin Fail(10);Exit;End;
 If V^.S<>Nil Then FreeStr(V^.S);
 C:=1;
 For I:=1 To ND Do Begin
  Lo:=OptBase;
  If B[I]<Lo Then B[I]:=Lo;
  If B[I]>32000 Then Begin Fail(7);Exit;End;
  C:=C*(B[I]-Lo+1);
  If C>8000 Then Begin Fail(7);Exit;End;
  V^.Dim[I]:=B[I];
 End;
 V^.NDim:=ND;V^.Cnt:=C;V^.IsArr:=True;
 If V^.Typ=2 Then Begin
  GetMem(V^.Data,C*SizeOf(PString));
  FillChar(V^.Data^,C*SizeOf(PString),0);
 End Else Begin
  GetMem(V^.Data,C*SizeOf(Real));
  FillChar(V^.Data^,C*SizeOf(Real),0);
 End;
End;

Function ElemIdx(V: PVar; Var Ix: TIdx; N: Integer): LongInt;
Var I: Integer; F: LongInt; Lo: Integer;
Begin
 ElemIdx:=0;
 If Not V^.IsArr Then Begin
  { dimensionnement automatique : 10 par dimension }
  If N>8 Then Begin Fail(9);Exit;End;
  Lo:=OptBase;
  F:=1;
  For I:=1 To N Do Begin
   V^.Dim[I]:=10;
   F:=F*(10-Lo+1);
  End;
  If F>8000 Then Begin Fail(7);Exit;End;
  V^.NDim:=N;V^.Cnt:=F;V^.IsArr:=True;
  If V^.Typ=2 Then Begin
   GetMem(V^.Data,F*SizeOf(PString));
   FillChar(V^.Data^,F*SizeOf(PString),0);
  End Else Begin
   GetMem(V^.Data,F*SizeOf(Real));
   FillChar(V^.Data^,F*SizeOf(Real),0);
  End;
 End;
 If N<>V^.NDim Then Begin Fail(9);Exit;End;
 Lo:=OptBase;
 F:=0;
 For I:=1 To N Do Begin
  If (Ix[I]<Lo) Or (Ix[I]>V^.Dim[I]) Then Begin Fail(9);Exit;End;
  F:=F*(V^.Dim[I]-Lo+1)+(Ix[I]-Lo);
 End;
 ElemIdx:=F;
End;

{ ====================================================================== }
{                         EXPRESSIONS                                    }
{ ====================================================================== }

Function EvalExpr: TVal; Forward;
Function EvalLevel(L: Integer): TVal; Forward;

Function NumOf(Var V: TVal): Real;
Begin
 If V.IsStr Then Begin Fail(13);NumOf:=0;End Else NumOf:=V.N;
End;

Function StrOf(Var V: TVal): String;
Begin
 If Not V.IsStr Then Begin Fail(13);StrOf:='';End Else StrOf:=V.S;
End;

Function ToLong(R: Real): LongInt;
Begin
 If R>2147483000.0 Then Begin Fail(6);ToLong:=0;Exit;End;
 If R<-2147483000.0 Then Begin Fail(6);ToLong:=0;Exit;End;
 ToLong:=Round(R);
End;

Procedure MkNum(Var V: TVal; R: Real);
Begin
 V.IsStr:=False;V.N:=R;V.S:='';
End;

Procedure MkStr(Var V: TVal; Const S: String);
Begin
 V.IsStr:=True;V.N:=0;V.S:=S;
End;

Function GetVarVal(V: PVar; Flat: LongInt): TVal;
Var R: TVal; I: Integer;
Begin
 R.IsStr:=(V^.Typ=2);R.N:=0;R.S:='';
 If V^.IsArr Then Begin
  If V^.Typ=2 Then Begin
   If PPtrArr(V^.Data)^[Flat]<>Nil Then R.S:=PPtrArr(V^.Data)^[Flat]^;
  End Else R.N:=PRealArr(V^.Data)^[Flat];
 End Else If V^.Typ=2 Then Begin
  If V^.FFile>0 Then Begin
   If FT[V^.FFile].Used And (FT[V^.FFile].Buf<>Nil) Then Begin
    R.S:='';
    For I:=0 To V^.FWid-1 Do R.S:=R.S+Chr(FT[V^.FFile].Buf^[V^.FOff+I]);
   End;
  End Else If V^.S<>Nil Then R.S:=V^.S^;
 End Else R.N:=V^.N;
 GetVarVal:=R;
End;

Procedure FieldSet(V: PVar; Const S: String; Right: Boolean);
Var I,L,Off: Integer;
Begin
 If (V^.FFile<=0) Or (Not FT[V^.FFile].Used) Or (FT[V^.FFile].Buf=Nil) Then Exit;
 L:=Length(S);
 If L>V^.FWid Then L:=V^.FWid;
 For I:=0 To V^.FWid-1 Do FT[V^.FFile].Buf^[V^.FOff+I]:=32;
 If Right Then Off:=V^.FWid-L Else Off:=0;
 For I:=1 To L Do FT[V^.FFile].Buf^[V^.FOff+Off+I-1]:=Ord(S[I]);
End;

Procedure SetVarVal(V: PVar; Flat: LongInt; Var X: TVal);
Var R: Real;
Begin
 If (V^.Typ=2) <> X.IsStr Then Begin Fail(13);Exit;End;
 If V^.Typ=2 Then Begin
  If V^.IsArr Then Begin
   FreeStr(PPtrArr(V^.Data)^[Flat]);
   PPtrArr(V^.Data)^[Flat]:=NewStr(X.S);
  End Else If V^.FFile>0 Then FieldSet(V,X.S,False)
  Else Begin
   If V^.S<>Nil Then FreeStr(V^.S);
   V^.S:=NewStr(X.S);
  End;
  Exit;
 End;
 R:=X.N;
 If V^.Typ=1 Then Begin
  R:=Int(R+0.5*(1-2*Ord(R<0)));
  If (R>32767) Or (R<-32768) Then Begin Fail(107);Exit;End;
 End;
 If V^.IsArr Then PRealArr(V^.Data)^[Flat]:=R Else V^.N:=R;
End;

{ ---------------- fonctions definies par DEF FN ------------------------ }

Var
 FnName : Array[1..20] Of String[34];
 FnPar  : Array[1..20,1..4] Of String[34];
 FnNPar : Array[1..20] Of Integer;
 FnBody : Array[1..20] Of PString;
 FnLn   : Array[1..20] Of Integer;
 FnCnt  : Integer;

Function FindFn(Const W: String): Integer;
Var I: Integer;
Begin
 FindFn:=0;
 For I:=1 To FnCnt Do If FnName[I]=W Then FindFn:=I;
End;

{ ---------------------- fonctions predefinies --------------------------- }

Const
 NFUNC = 61;
 FuncNames : Array[1..NFUNC] Of String[8] = (
  'ABS','ASC','ATN','CDBL','CHR$','CINT','COS','CSNG','CVD','CVI','CVS','EOF',
  'EXP','FIX','FLOAT','FRE','HEX$','INP','INPUT$','INSTR','INT','LEFT$','LEN',
  'LOC','LOF','LOG','LOG10','LPOS','MID$','MKD$','MKI$','MKS$','OCT$','PEEK',
  'POS','RIGHT$','RND','SGN','SIN','SPACE$','SPC','SQR','STR$','STRING$','TAB',
  'TAN','VAL','VARPTR','ERR','ERL','GB','SYSTAB','INKEY$',
  'FRE','CONTRL','INTIN','INTOUT','PTSIN','PTSOUT','VDISYS','GEMSYS');

Function IsFunc(Const W: String): Boolean;
Var I: Integer;
Begin
 IsFunc:=False;
 For I:=1 To NFUNC Do If FuncNames[I]=W Then Begin IsFunc:=True;Exit;End;
End;

Function IsNoArgFunc(Const W: String): Boolean;
Begin
 IsNoArgFunc:=(W='RND') Or (W='INKEY$') Or (W='ERR') Or (W='ERL')
  Or (W='FRE') Or (W='GB') Or (W='SYSTAB') Or (W='CONTRL') Or (W='INTIN') Or (W='INTOUT')
  Or (W='PTSIN') Or (W='PTSOUT');
End;

Procedure ParseArgs(Var A: TArgs; Var N: Integer);
Begin
 N:=0;
 SkipSp;
 If Cur<>'(' Then Exit;
 Inc(P);
 SkipSp;
 If Cur=')' Then Begin Inc(P);Exit;End;
 Repeat
  SkipSp;
  If Cur='#' Then Inc(P);
  Inc(N);
  If N>5 Then Begin Fail(2);Exit;End;
  A[N]:=EvalExpr;
 Until (ErrCode<>0) Or (Not Accept(','));
 Expect(')');
End;

Function ArgIsDbl(Q: Integer): Boolean;
{ vrai si l'argument commencant en Q est une variable de type DEFDBL }
Var W: String;
Begin
 ArgIsDbl:=False;
 While (Q<=Length(Src)) And (Src[Q]=' ') Do Inc(Q);
 If (Q>Length(Src)) Or (Not IsAlpha(Src[Q])) Then Exit;
 W:='';
 While (Q<=Length(Src)) And IsIdCh(Src[Q]) Do Begin W:=W+UpCase(Src[Q]);Inc(Q);End;
 If (Q<=Length(Src)) And ((Src[Q]='$') Or (Src[Q]='%') Or (Src[Q]='!')) Then Begin W:=W+Src[Q];Inc(Q);End;
 While (Q<=Length(Src)) And (Src[Q]=' ') Do Inc(Q);
 If (Q<=Length(Src)) And ((Src[Q]=')') Or (Src[Q]=',')) Then ArgIsDbl:=(VarTypeOf(W)=3);
End;

Procedure SysTabSync;
Var I: Integer;
Begin
 VMemWriteW(SYS_ADDR,1);
 For I:=0 To 3 Do VMemWriteW(SYS_ADDR+12+I*2,Ord(Win[I].Open));
 VMemWriteL(SYS_ADDR+20,GFX_BUF);
End;

Function PeekMode(L: LongInt; Dbl: Boolean): LongInt;
Begin
 SysTabSync;
 If DefSegV>0 Then PeekMode:=VMemRead(DefSegV+L)
 Else If Dbl Or ((L>=GB_ADDR) And (L<GB_ADDR+24)) Then PeekMode:=VMemReadL(L)
 Else PeekMode:=VMemReadW(L);
End;

Procedure PokeMode(L,V: LongInt; Dbl: Boolean);
Begin
 If DefSegV>0 Then VMemWrite(DefSegV+L,V And 255)
 Else If Dbl Then VMemWriteL(L,V)
 Else VMemWriteW(L,V And $FFFF);
End;

Function HexStr(L: LongInt; Base: Integer): String;
Var S: String; U: LongInt;
Begin
 If L=0 Then Begin HexStr:='0';Exit;End;
 If (L<0) And (L>=-32768) Then L:=L And $FFFF;
 S:='';U:=L;
 If U<0 Then Begin
  { complement a deux sur 32 bits }
  U:=U And $7FFFFFFF;
  While U>0 Do Begin S:=Copy('0123456789ABCDEF',(U Mod Base)+1,1)+S;U:=U Div Base;End;
  HexStr:=S;Exit;
 End;
 While U>0 Do Begin S:=Copy('0123456789ABCDEF',(U Mod Base)+1,1)+S;U:=U Div Base;End;
 HexStr:=S;
End;

Function ValStr(Const S0: String): Real;
Var S: String; I,K: Integer; V: Real; C: Integer; H: LongInt;
Begin
 S:=TrimStr(S0);
 ValStr:=0;
 If S='' Then Exit;
 If (S[1]='&') And (Length(S)>1) Then Begin
  H:=0;
  If UpCase(S[2])='H' Then Begin
   I:=3;
   While (I<=Length(S)) And (HexVal(S[I])>=0) Do Begin H:=H*16+HexVal(S[I]);Inc(I);End;
  End Else Begin
   I:=2;If UpCase(S[2])='O' Then I:=3;
   While (I<=Length(S)) And (S[I]>='0') And (S[I]<='7') Do Begin H:=H*8+Ord(S[I])-48;Inc(I);End;
  End;
  ValStr:=H;Exit;
 End;
 I:=1;
 If (S[I]='-') Or (S[I]='+') Then Inc(I);
 K:=I;
 While (K<=Length(S)) And IsDigit(S[K]) Do Inc(K);
 If (K<=Length(S)) And (S[K]='.') Then Begin
  Inc(K);
  While (K<=Length(S)) And IsDigit(S[K]) Do Inc(K);
 End;
 If (K<=Length(S)) And ((UpCase(S[K])='E') Or (UpCase(S[K])='D')) Then Begin
  If (K<Length(S)) And (IsDigit(S[K+1]) Or (((S[K+1]='-') Or (S[K+1]='+')) And
     (K+1<Length(S)) And IsDigit(S[K+2]))) Then Begin
   S[K]:='E';
   Inc(K,2);
   While (K<=Length(S)) And IsDigit(S[K]) Do Inc(K);
  End;
 End;
 S:=Copy(S,1,K-1);
 If (S='') Or (S='-') Or (S='+') Or (S='.') Then Exit;
 If S[Length(S)]='.' Then S:=S+'0';
 If (S[1]='.') Then S:='0'+S;
 If (S[1]='-') And (S[2]='.') Then Insert('0',S,2);
 Val(S,V,C);
 If C=0 Then Begin
  If (V>1.7E38) Or (V<-1.7E38) Then Fail(6) Else ValStr:=V;
 End;
End;

Var
 KeyQ : String;     { file d'attente du clavier (touches pour INKEY$/INPUT) }

Procedure KeyQAdd(K: Integer);
Begin
 If Length(KeyQ)<60 Then Begin
  If K>=256 Then KeyQ:=KeyQ+#0+Chr(K-256) Else KeyQ:=KeyQ+Chr(K);
 End;
End;

Function EvalFunc(Const W: String): TVal;
Var A: TArgs; N,I,K: Integer; R: TVal; X,Y: Real; S,S2: String; L: LongInt; P0: Integer; Dbl0: Boolean;
    H,Mi,Sc,Cs: Word; Yr,Mo,Dy,Dw: Word; D8: {$IFDEF FPC}Double{$ELSE}Real{$ENDIF};
    S4: {$IFDEF FPC}Single{$ELSE}LongInt{$ENDIF};
 Procedure Need(M: Integer);
 Begin
  If N<M Then Fail(31);
 End;
Begin
 P0:=P;
 Dbl0:=ArgIsDbl(P0+1);
 ParseArgs(A,N);
 MkNum(R,0);
 If ErrCode<>0 Then Begin EvalFunc:=R;Exit;End;
 If W='ABS' Then Begin Need(1);R.N:=Abs(NumOf(A[1]));End
 Else If W='ASC' Then Begin
  Need(1);S:=StrOf(A[1]);
  If S='' Then Fail(31) Else R.N:=Ord(S[1]);
 End
 Else If W='ATN' Then Begin Need(1);R.N:=ArcTan(NumOf(A[1]));End
 Else If (W='CDBL') Or (W='CSNG') Or (W='FLOAT') Then Begin Need(1);R.N:=NumOf(A[1]);End
 Else If W='CHR$' Then Begin
  Need(1);L:=ToLong(NumOf(A[1]));
  MkStr(R,Chr(L And 255));
 End
 Else If W='CINT' Then Begin
  Need(1);X:=NumOf(A[1]);
  If (X>32767.5) Or (X<-32768.5) Then Fail(107) Else R.N:=Int(X+0.5*(1-2*Ord(X<0)));
 End
 Else If W='COS' Then Begin Need(1);R.N:=Cos(NumOf(A[1]));End
 Else If W='CVI' Then Begin
  Need(1);S:=StrOf(A[1]);
  If Length(S)<2 Then Fail(31)
  Else Begin
   L:=Ord(S[1])+Ord(S[2])*256;
   If L>32767 Then L:=L-65536;
   R.N:=L;
  End;
 End
 Else If W='CVS' Then Begin
  Need(1);S:=StrOf(A[1]);
  If Length(S)<4 Then Fail(31)
  Else Begin
   Move(S[1],S4,4);
   R.N:=S4/{$IFDEF FPC}1{$ELSE}100{$ENDIF};
  End;
 End
 Else If W='CVD' Then Begin
  Need(1);S:=StrOf(A[1]);
  If Length(S)<8 Then Fail(31)
  Else Begin Move(S[1],D8,SizeOf(D8));R.N:=D8;End;
 End
 Else If W='EOF' Then Begin
  Need(1);L:=ToLong(NumOf(A[1]));
  If (L<1) Or (L>15) Or (Not FT[L].Used) Then Fail(52)
  Else Begin
   If FT[L].Mode='R' Then
    R.N:=-Ord(LongInt(FT[L].Rec)*FT[L].RecLen>=FileSize(FT[L].F))
   Else Begin
    If FT[L].Pb>=0 Then R.N:=0 Else R.N:=-Ord(Eof(FT[L].T));
   End;
  End;
 End
 Else If W='EXP' Then Begin
  Need(1);X:=NumOf(A[1]);
  If X>88 Then Fail(6) Else If X<-88 Then R.N:=0 Else R.N:=Exp(X);
 End
 Else If W='FIX' Then Begin Need(1);R.N:=Int(NumOf(A[1]));End
 Else If W='FRE' Then Begin
  R.N:=400000-LCnt*40;
  If BufGfx Then R.N:=R.N-32000;
 End
 Else If W='HEX$' Then Begin Need(1);MkStr(R,HexStr(ToLong(NumOf(A[1])),16));End
 Else If W='OCT$' Then Begin Need(1);MkStr(R,HexStr(ToLong(NumOf(A[1])),8));End
 Else If W='GB' Then R.N:=GB_ADDR
 Else If W='SYSTAB' Then R.N:=SYS_ADDR
 Else If W='CONTRL' Then R.N:=VDI_CONTRL
 Else If W='INTIN' Then R.N:=VDI_INTIN
 Else If W='INTOUT' Then R.N:=VDI_INTOUT
 Else If W='PTSIN' Then R.N:=VDI_PTSIN
 Else If W='PTSOUT' Then R.N:=VDI_PTSOUT
 Else If W='VDISYS' Then Begin BasicVdisys;R.N:=0;End
 Else If W='GEMSYS' Then Begin
  Need(1);BasicGemsys(ToLong(NumOf(A[1])));R.N:=0;
 End
 Else If W='LPOS' Then R.N:=0
 Else If W='INP' Then Begin
  Need(1);L:=ToLong(NumOf(A[1]));
  If L<0 Then Begin If KeyPressed Or (KeyQ<>'') Then R.N:=-1 Else R.N:=0;End
  Else If L=2 Then Begin
   I:=Ord(ReadKey);If I=0 Then I:=Ord(ReadKey);
   R.N:=I;
  End Else R.N:=0;
 End
 Else If W='INKEY$' Then Begin
  S:='';
  While KeyPressed And (Length(KeyQ)<4) Do Begin
   I:=Ord(ReadKey);
   If I=0 Then KeyQAdd(256+Ord(ReadKey)) Else KeyQAdd(I);
  End;
  If KeyQ<>'' Then Begin
   If (KeyQ[1]=#0) And (Length(KeyQ)>1) Then Begin S:=Copy(KeyQ,1,2);Delete(KeyQ,1,2);End
   Else Begin S:=KeyQ[1];Delete(KeyQ,1,1);End;
  End;
  MkStr(R,S);
 End
 Else If W='INPUT$' Then Begin
  Need(1);L:=ToLong(NumOf(A[1]));S:='';
  If (N>=2) And (ToLong(NumOf(A[2]))>=1) Then Begin
   K:=ToLong(NumOf(A[2]));
   If (K<=15) And FT[K].Used And (FT[K].Mode<>'R') Then
    While (L>0) And (Not Eof(FT[K].T)) Do Begin
     Read(FT[K].T,S2);L:=L-1;
    End;
  End Else Begin
   While Length(S)<L Do Begin
    If KeyPressed Then Begin
     I:=Ord(ReadKey);If I=0 Then I:=Ord(ReadKey);
     If (I=3) Or (I=7) Then Begin BreakReq:=True;L:=Length(S);End
     Else S:=S+Chr(I And 255);
    End Else Delay(5);
   End;
  End;
  MkStr(R,S);
 End
 Else If W='INSTR' Then Begin
  Need(2);
  If A[1].IsStr Then Begin
   S:=StrOf(A[1]);S2:=StrOf(A[2]);K:=1;
  End Else Begin
   Need(3);K:=ToLong(NumOf(A[1]));S:=StrOf(A[2]);S2:=StrOf(A[3]);
  End;
  If (K<1) Or (K>255) Then Fail(31)
  Else Begin
   If K>Length(S) Then R.N:=0
   Else Begin
    I:=Pos(S2,Copy(S,K,255));
    If I=0 Then R.N:=0 Else R.N:=I+K-1;
    If S2='' Then R.N:=0;
   End;
  End;
 End
 Else If W='INT' Then Begin
  Need(1);X:=NumOf(A[1]);Y:=Int(X);
  If (X<0) And (Y<>X) Then Y:=Y-1;
  R.N:=Y;
 End
 Else If W='LEFT$' Then Begin
  Need(2);S:=StrOf(A[1]);L:=ToLong(NumOf(A[2]));
  If L<0 Then Fail(31) Else MkStr(R,Copy(S,1,L));
 End
 Else If W='RIGHT$' Then Begin
  Need(2);S:=StrOf(A[1]);L:=ToLong(NumOf(A[2]));
  If L<0 Then Fail(31)
  Else If L>=Length(S) Then MkStr(R,S)
  Else MkStr(R,Copy(S,Length(S)-L+1,L));
 End
 Else If W='MID$' Then Begin
  Need(2);S:=StrOf(A[1]);L:=ToLong(NumOf(A[2]));
  If L<1 Then Fail(31)
  Else If N>=3 Then Begin
   K:=ToLong(NumOf(A[3]));
   If K<0 Then Fail(31) Else MkStr(R,Copy(S,L,K));
  End Else MkStr(R,Copy(S,L,255));
 End
 Else If W='LEN' Then Begin Need(1);R.N:=Length(StrOf(A[1]));End
 Else If (W='LOC') Or (W='LOF') Then Begin
  Need(1);L:=ToLong(NumOf(A[1]));
  If (L<1) Or (L>15) Or (Not FT[L].Used) Then Fail(52)
  Else If W='LOF' Then Begin
   If FT[L].Mode='R' Then R.N:=FileSize(FT[L].F) Else R.N:=0;
  End Else Begin
   If FT[L].Mode='R' Then R.N:=FT[L].Rec Else R.N:=FilePos(FT[L].F);
  End;
 End
 Else If W='LOG' Then Begin
  Need(1);X:=NumOf(A[1]);
  If X<=0 Then Fail(31) Else R.N:=Ln(X);
 End
 Else If W='LOG10' Then Begin
  Need(1);X:=NumOf(A[1]);
  If X<=0 Then Fail(31) Else R.N:=Ln(X)/Ln(10);
 End
 Else If W='MKI$' Then Begin
  Need(1);L:=ToLong(NumOf(A[1]));
  If (L>32767) Or (L<-32768) Then Fail(107)
  Else Begin L:=L And $FFFF;MkStr(R,Chr(L And 255)+Chr(L Shr 8));End;
 End
 Else If W='MKS$' Then Begin
  Need(1);
  {$IFDEF FPC}S4:=NumOf(A[1]);{$ELSE}S4:=Round(NumOf(A[1])*100);{$ENDIF}
  S[0]:=#4;Move(S4,S[1],4);MkStr(R,S);
 End
 Else If W='MKD$' Then Begin
  Need(1);D8:=NumOf(A[1]);
  S[0]:=#8;FillChar(S[1],8,0);Move(D8,S[1],SizeOf(D8));MkStr(R,S);
 End
 Else If W='PEEK' Then Begin
  Need(1);L:=ToLong(NumOf(A[1]));
  R.N:=PeekMode(L,Dbl0);
 End
 Else If W='POS' Then R.N:=OCX
 Else If W='RND' Then Begin
  If N>=1 Then Begin
   X:=NumOf(A[1]);
   If X<0 Then Begin RandSeed:=Round(-X*1000)+12345;RndLast:=Random;End
   Else If X>0 Then RndLast:=Random;
  End Else RndLast:=Random;
  R.N:=RndLast;
 End
 Else If W='SGN' Then Begin
  Need(1);X:=NumOf(A[1]);
  If X>0 Then R.N:=1 Else If X<0 Then R.N:=-1 Else R.N:=0;
 End
 Else If W='SIN' Then Begin Need(1);R.N:=Sin(NumOf(A[1]));End
 Else If W='SPACE$' Then Begin
  Need(1);L:=ToLong(NumOf(A[1]));
  If (L<0) Or (L>255) Then Fail(31) Else Begin S:='';For I:=1 To L Do S:=S+' ';MkStr(R,S);End;
 End
 Else If W='SPC' Then Begin
  Need(1);L:=ToLong(NumOf(A[1]));
  If (L<0) Or (L>255) Then Fail(31) Else Begin S:='';For I:=1 To L Do S:=S+' ';MkStr(R,S);End;
 End
 Else If W='TAB' Then Begin
  Need(1);L:=ToLong(NumOf(A[1]));
  S:='';
  For I:=OCX+1 To L-1 Do S:=S+' ';
  MkStr(R,S);
 End
 Else If W='SQR' Then Begin
  Need(1);X:=NumOf(A[1]);
  If X<0 Then Fail(31) Else R.N:=Sqrt(X);
 End
 Else If W='STR$' Then Begin
  Need(1);X:=NumOf(A[1]);S:=NumStr(X);
  If X>=0 Then S:=' '+S;
  MkStr(R,S);
 End
 Else If W='STRING$' Then Begin
  Need(2);L:=ToLong(NumOf(A[1]));
  If A[2].IsStr Then Begin
   S:=StrOf(A[2]);
   If S='' Then Fail(31) Else S2:=S[1];
  End Else Begin
   K:=ToLong(NumOf(A[2]));
   S2:=Chr(K And 255);
  End;
  If (L<0) Or (L>255) Then Fail(31)
  Else Begin S:='';For I:=1 To L Do S:=S+S2;MkStr(R,S);End;
 End
 Else If W='TAN' Then Begin
  Need(1);X:=NumOf(A[1]);
  If Abs(Cos(X))<1E-12 Then Fail(6) Else R.N:=Sin(X)/Cos(X);
 End
 Else If W='VAL' Then Begin Need(1);R.N:=ValStr(StrOf(A[1]));End
 Else If W='VARPTR' Then R.N:=$1000+HashOf(IntStr(N))
 Else If W='ERR' Then R.N:=ErrNum
 Else If W='ERL' Then R.N:=ErrLNum
 Else If W='TIMER' Then Begin
  GetTime(H,Mi,Sc,Cs);
  R.N:=(LongInt(H)*60+Mi)*60+Sc+Cs/100;
 End
 Else If W='DATE$' Then Begin
  GetDate(Yr,Mo,Dy,Dw);
  S:=IntStr(Mo);If Length(S)<2 Then S:='0'+S;
  S2:=IntStr(Dy);If Length(S2)<2 Then S2:='0'+S2;
  MkStr(R,S+'-'+S2+'-'+IntStr(Yr));
 End
 Else If W='TIME$' Then Begin
  GetTime(H,Mi,Sc,Cs);
  S:=IntStr(H);If Length(S)<2 Then S:='0'+S;
  MkStr(R,S);
  S:=IntStr(Mi);If Length(S)<2 Then S:='0'+S;
  R.S:=R.S+':'+S;
  S:=IntStr(Sc);If Length(S)<2 Then S:='0'+S;
  R.S:=R.S+':'+S;
 End
 Else Fail(2);
 EvalFunc:=R;
End;

{ ---------------------- operateurs ------------------------------------ }

Function PowerOf(X,Y: Real): Real;
Var I,N: Integer; R: Real;
Begin
 PowerOf:=0;
 If Y=0 Then Begin PowerOf:=1;Exit;End;
 If X=0 Then Begin
  If Y<0 Then Fail(11) Else PowerOf:=0;
  Exit;
 End;
 If (Y=Int(Y)) And (Abs(Y)<=64) Then Begin
  N:=Abs(Round(Y));R:=1;
  For I:=1 To N Do Begin
   If Abs(R)>1E30 Then Begin Fail(6);Exit;End;
   R:=R*X;
  End;
  If Y<0 Then Begin
   If R=0 Then Fail(11) Else PowerOf:=1/R;
  End Else PowerOf:=R;
  Exit;
 End;
 If X<0 Then Begin Fail(31);Exit;End;
 If Y*Ln(X)>87 Then Begin Fail(6);Exit;End;
 If Y*Ln(X)<-87 Then Begin PowerOf:=0;Exit;End;
 PowerOf:=Exp(Y*Ln(X));
End;

Function Compare(Var A,B: TVal): Integer;
Begin
 Compare:=0;
 If A.IsStr<>B.IsStr Then Begin Fail(13);Exit;End;
 If A.IsStr Then Begin
  If A.S<B.S Then Compare:=-1 Else If A.S>B.S Then Compare:=1;
 End Else Begin
  If A.N<B.N Then Compare:=-1 Else If A.N>B.N Then Compare:=1;
 End;
End;

Function EvalPrimary: TVal;
Var R,V: TVal; W: String; S0,I,N,K: Integer; Q: PVar; Ix: TIdx; Flat: LongInt;
    St: String; Sp: Integer; F: Integer; Saved: Array[1..4] Of TVal; PV: Array[1..4] Of PVar;
    Args: TArgs; NA: Integer; Stop: Boolean;
Begin
 MkNum(R,0);
 SkipSp;
 If ErrCode<>0 Then Begin EvalPrimary:=R;Exit;End;
 If IsDigit(Cur) Or (Cur='.') Or (Cur='&') Then Begin
  MkNum(R,ReadNumber);
 End Else If Cur='"' Then Begin
  Inc(P);
  St:='';
  While (P<=Length(Src)) And (Src[P]<>'"') Do Begin St:=St+Src[P];Inc(P);End;
  If P<=Length(Src) Then Inc(P);
  MkStr(R,St);
 End Else If Cur='(' Then Begin
  Inc(P);
  R:=EvalExpr;
  Expect(')');
 End Else If IsAlpha(Cur) Then Begin
  S0:=P;
  W:=ReadWord;
  SkipSp;
  If (Copy(W,1,2)='FN') And (FindFn(W)>0) Then Begin
   F:=FindFn(W);
   NA:=0;
   ParseArgs(Args,NA);
   If NA<>FnNPar[F] Then Begin Fail(31);EvalPrimary:=R;Exit;End;
   For I:=1 To NA Do Begin
    PV[I]:=FindVar(FnPar[F,I],True);
    Saved[I]:=GetVarVal(PV[I],0);
   End;
   For I:=1 To NA Do If PV[I]^.Typ=2 Then Begin
     If Not Args[I].IsStr Then Fail(13) Else SetVarVal(PV[I],0,Args[I]);
    End Else Begin
     If Args[I].IsStr Then Fail(13) Else SetVarVal(PV[I],0,Args[I]);
    End;
   St:=Src;Sp:=P;
   Src:=FnBody[F]^;P:=1;
   R:=EvalExpr;
   Src:=St;P:=Sp;
   For I:=1 To NA Do SetVarVal(PV[I],0,Saved[I]);
  End Else If (Copy(W,1,2)='FN') And (Length(W)>2) And (FindFn(W)=0) And (Not IsFunc(W))
     And (Not IsNoArgFunc(W)) And (W[3]<>'$') And (W[3]<>'%') And (W[3]<>'!') Then Begin
   Fail(18);
  End Else If (Cur='(') And IsFunc(W) Then Begin
   R:=EvalFunc(W);
  End Else If (Cur<>'(') And IsNoArgFunc(W) Then Begin
   R:=EvalFunc(W);
  End Else Begin
   Q:=FindVar(W,True);
   If Cur='(' Then Begin
    Inc(P);N:=0;
    Repeat
     Inc(N);
     If N>8 Then Begin Fail(9);Stop:=True;End Else Begin
      V:=EvalExpr;
      Ix[N]:=ToLong(NumOf(V));
     End;
    Until (ErrCode<>0) Or (Not Accept(','));
    Expect(')');
    If ErrCode=0 Then Begin
     Flat:=ElemIdx(Q,Ix,N);
     If ErrCode=0 Then R:=GetVarVal(Q,Flat);
    End;
   End Else Begin
    If Q^.IsArr Then Fail(13) Else R:=GetVarVal(Q,0);
   End;
  End;
 End Else Begin
  If (P>Length(Src)) Or (Cur=':') Or (Cur=')') Or (Cur=',') Or (Cur=';') Or (Cur='''')
   Then Fail(22) Else Fail(2);
 End;
 EvalPrimary:=R;
End;

Function LogOp(L: Integer; Var A,B: TVal): TVal;
Var R: TVal; X,Y: LongInt;
Begin
 MkNum(R,0);
 X:=ToLong(NumOf(A));Y:=ToLong(NumOf(B));
 Case L Of
  1: R.N:=Not (X Xor Y);
  2: R.N:=(Not X) Or Y;
  3: R.N:=X Xor Y;
  4: R.N:=X Or Y;
  5: R.N:=X And Y;
 End;
 LogOp:=R;
End;

Function EvalLevel(L: Integer): TVal;
Var A,B: TVal; S: Integer; W: String; Done: Boolean; Op: Integer; C,C2: Char;
    X,Y: Real; LX,LY: LongInt; T: String;
Begin
 MkNum(A,0);
 If ErrCode<>0 Then Begin EvalLevel:=A;Exit;End;
 Case L Of
  1..5: Begin
    A:=EvalLevel(L+1);
    Done:=False;
    Repeat
     S:=P;W:=ReadWord;
     If ((L=1) And (W='EQV')) Or ((L=2) And (W='IMP')) Or ((L=3) And (W='XOR'))
        Or ((L=4) And (W='OR')) Or ((L=5) And (W='AND')) Then Begin
      B:=EvalLevel(L+1);
      A:=LogOp(L,A,B);
     End Else Begin P:=S;Done:=True;End;
    Until Done Or (ErrCode<>0);
   End;
  6: Begin
    S:=P;W:=ReadWord;
    If W='NOT' Then Begin
     A:=EvalLevel(6);
     LX:=ToLong(NumOf(A));
     MkNum(A,Not LX);
    End Else Begin P:=S;A:=EvalLevel(7);End;
   End;
  7: Begin
    A:=EvalLevel(8);
    Done:=False;
    Repeat
     SkipSp;C:=Cur;Op:=0;
     If (C='=') Or (C='<') Or (C='>') Then Begin
      C2:=#0;
      If P<Length(Src) Then C2:=Src[P+1];
      If C='=' Then Begin
       If C2='<' Then Begin Op:=4;Inc(P,2);End
       Else If C2='>' Then Begin Op:=5;Inc(P,2);End
       Else Begin Op:=1;Inc(P);End;
      End Else If C='<' Then Begin
       If C2='>' Then Begin Op:=2;Inc(P,2);End
       Else If C2='=' Then Begin Op:=4;Inc(P,2);End
       Else Begin Op:=3;Inc(P);End;
      End Else Begin
       If C2='<' Then Begin Op:=2;Inc(P,2);End
       Else If C2='=' Then Begin Op:=5;Inc(P,2);End
       Else Begin Op:=6;Inc(P);End;
      End;
     End;
     If Op=0 Then Done:=True
     Else Begin
      B:=EvalLevel(8);
      LX:=Compare(A,B);
      Case Op Of
       1: X:=-Ord(LX=0);
       2: X:=-Ord(LX<>0);
       3: X:=-Ord(LX<0);
       4: X:=-Ord(LX<=0);
       5: X:=-Ord(LX>=0);
      Else X:=-Ord(LX>0);
      End;
      MkNum(A,X);
     End;
    Until Done Or (ErrCode<>0);
   End;
  8: Begin
    A:=EvalLevel(9);
    Done:=False;
    Repeat
     SkipSp;C:=Cur;
     If (C='+') Or (C='-') Then Begin
      Inc(P);
      B:=EvalLevel(9);
      If C='+' Then Begin
       If A.IsStr And B.IsStr Then Begin
        If Length(A.S)+Length(B.S)>255 Then Begin Fail(15);T:=A.S;End
        Else T:=A.S+B.S;
        MkStr(A,T);
       End Else Begin
        X:=NumOf(A)+NumOf(B);
        MkNum(A,X);
       End;
      End Else Begin
       X:=NumOf(A)-NumOf(B);
       MkNum(A,X);
      End;
     End Else Done:=True;
    Until Done Or (ErrCode<>0);
   End;
  9: Begin
    A:=EvalLevel(10);
    Done:=False;
    Repeat
     S:=P;W:=ReadWord;
     If W='MOD' Then Begin
      B:=EvalLevel(10);
      LX:=ToLong(NumOf(A));LY:=ToLong(NumOf(B));
      If ErrCode=0 Then Begin
       If LY=0 Then Fail(11) Else MkNum(A,LX Mod LY);
      End;
     End Else Begin P:=S;Done:=True;End;
    Until Done Or (ErrCode<>0);
   End;
  10: Begin
    A:=EvalLevel(11);
    Done:=False;
    Repeat
     SkipSp;C:=Cur;
     If (C='*') Or (C='/') Or (C='\') Then Begin
      Inc(P);
      B:=EvalLevel(11);
      X:=NumOf(A);Y:=NumOf(B);
      If ErrCode=0 Then Begin
       If C='*' Then Begin
        If (Abs(X)>1) And (Abs(Y)>1) And (Ln(Abs(X))+Ln(Abs(Y))>87) Then Fail(6)
        Else MkNum(A,X*Y);
       End Else If Y=0 Then Fail(11)
       Else If C='/' Then MkNum(A,X/Y)
       Else Begin
        LX:=ToLong(X);LY:=ToLong(Y);
        If LY=0 Then Fail(11) Else MkNum(A,LX Div LY);
       End;
      End;
     End Else Done:=True;
    Until Done Or (ErrCode<>0);
   End;
  11: Begin
    SkipSp;
    If Cur='-' Then Begin
     Inc(P);A:=EvalLevel(11);X:=-NumOf(A);MkNum(A,X);
    End Else If Cur='+' Then Begin
     Inc(P);A:=EvalLevel(11);
    End Else A:=EvalLevel(12);
   End;
  12: Begin
    A:=EvalLevel(13);
    Done:=False;
    Repeat
     SkipSp;
     If Cur='^' Then Begin
      Inc(P);
      B:=EvalLevel(11);
      X:=PowerOf(NumOf(A),NumOf(B));
      MkNum(A,X);
     End Else Done:=True;
    Until Done Or (ErrCode<>0);
   End;
 Else
  A:=EvalPrimary;
 End;
 EvalLevel:=A;
End;

Function EvalExpr: TVal;
Begin
 EvalExpr:=EvalLevel(1);
End;

{ ====================================================================== }
{                  INTERPRETEUR : ETAT D'EXECUTION                       }
{ ====================================================================== }

Const
 NRES = 189;
 Reserved : Array[1..NRES] Of String[9] = (
  'ABS','ALL','AND','AS','ASC','ATN','AUTO','BASE','BLOAD','BREAK','BSAVE','CALL',
  'CDBL','CHAIN','CHR$','CINT','CIRCLE','CLEAR','CLEARW','CLOSE','CLOSEW','COLOR',
  'COMMON','CONT','CONTRL','COS','CSNG','CVD','CVI','CVS','DATA','DEF','DEFDBL',
  'DEFINT','DEFSEG','DEFSNG','DEFSTR','DELETE','DIM','DIR','DO','EDIT','ELLIPSE',
  'ELSE','END','EOF','ERA','ERASE','ERL','ERR','ERROR','EQV','EXP','FIELD',
  'FILL','FIX','FLOAT','FN','FOLLOW','FOR','FRE','FULLW','GB','GEMSYS','GET','GO',
  'GOSUB','GOTO','GOTOXY','HEX$','IF','IMP','INKEY$','INP','INPUT','INPUT$','INSTR',
  'INT','INTIN','INTOUT','KILL','LEFT$','LEN','LET','LINE','LINEF','LIST','LLIST',
  'LOAD','LOC','LOF','LOG','LOG10','LPOS','LPRINT','LSET','MERGE','MID$','MKD$',
  'MKI$','MKS$','MOD','NAME','NEW','NEXT','NOT','OCT$','OLD','ON','OPEN','OPENW',
  'OPTION','OR','OUT','PCIRCLE','PEEK','PELLIPSE','POKE','POS','PRINT','PTSIN',
  'PTSOUT','PUT','QUIT','RANDOMIZE','READ','REM','RENUM','REPLACE','RESET','RESTORE',
  'RESUME','RETURN','RIGHT$','RND','RSET','RUN','SAVE','SEG','SGN','SIN','SOUND',
  'SPACE$','SPC','SQR','STEP','STOP','STR$','STRING$','SWAP','SYSDBG','SYSTAB',
  'SYSTEM','TAB','TAN','THEN','TO','TRACE','TROFF','TRON','UNBREAK','UNFOLLOW',
  'UNTRACE','USING','VAL','VARPTR','VDISYS','WAIT','WAVE','WEND','WHILE','WIDTH',
  'WRITE','XOR','TO','THEN','ELSE','ERASE',
  'DIM','DEF','FN','ALL','AS','BASE','LINE','USING','STEP','SEG','DO');

Type
 TForRec = Record V: PVar; Lim,Stp: Real; Ln,Ps: Integer; End;
 TPos    = Record Ln,Ps: Integer; End;

Var
 PrnWidth     : Integer;
 PCLine,PCPos  : Integer;     { position d'execution (ligne 0 = direct) }
 JumpF         : Boolean;
 JLine,JPos    : Integer;
 EndF          : Boolean;
 Running       : Boolean;
 StmtStart     : Integer;
 ResLine,ResPos: Integer;     { reprise pour CONT }
 FS            : Array[1..32] Of TForRec;
 FSP           : Integer;
 GS            : Array[1..64] Of TPos;
 GSP           : Integer;
 WS            : Array[1..32] Of TPos;
 WSP           : Integer;
 DatLine,DatScan,DatPos : Integer;
 OnErrLine,OnErrPos : Integer;
 ErrStmtLn,ErrStmtPos : Integer;
 StmtCount     : LongInt;
 StepMode,TronOn,TraceOn : Boolean;
 TrLo,TrHi     : LongInt;
 QuitReq,EditReq : Boolean;
 AutoOn        : Boolean;
 AutoNum,AutoStep : LongInt;
 LastRunMsg    : String;
 PrnOpen       : Boolean;
 PrnF          : Text;
 PrnCol        : Integer;
 ChainKeep     : Array[1..20] Of String[34];
 ChainKeepN    : Integer;

Const
 MAXLAB = 300;
Var
 LabName : Array[1..MAXLAB] Of String[32];
 LabLine,LabPos : Array[1..MAXLAB] Of Integer;
 LabN    : Integer;

{ ------- crochets vers l'interface (definis plus loin) ------------------ }
Procedure RunPoll; Forward;
Procedure StepWait(Ln: Integer; Pre: Char); Forward;
Procedure ShowRunError(Ln: Integer); Forward;
Procedure RunFrom(Ln,Ps: Integer); Forward;
Procedure ExecDirect(Const S: String); Forward;
Procedure EmuCallAddr(Addr: LongInt; N: Integer; Var Args: TArgs); Forward;
Function EmuRunPRG(Const Name: String): Boolean; Forward;

Function IsReserved(Const W: String): Boolean;
Var I: Integer;
Begin
 IsReserved:=False;
 For I:=1 To NRES Do If Reserved[I]=W Then Begin IsReserved:=True;Exit;End;
End;

Procedure BuildLabels;
Var I,Q: Integer; T,W: String;
Begin
 LabN:=0;
 For I:=1 To LCnt Do Begin
  T:=LTxt[I]^;Q:=1;
  While (Q<=Length(T)) And (T[Q]=' ') Do Inc(Q);
  W:='';
  While (Q<=Length(T)) And IsIdCh(T[Q]) Do Begin W:=W+UpCase(T[Q]);Inc(Q);End;
  If (W<>'') And IsAlpha(W[1]) And (Q<=Length(T)) And (T[Q]=':') And
     (Not IsReserved(W)) And (LabN<MAXLAB) Then Begin
   Inc(LabN);LabName[LabN]:=W;LabLine[LabN]:=I;LabPos[LabN]:=Q+1;
  End;
 End;
 LabDirty:=False;
End;

Function FindLabel(Const W: String): Integer;
Var I: Integer;
Begin
 If LabDirty Then BuildLabels;
 FindLabel:=0;
 For I:=1 To LabN Do If LabName[I]=W Then FindLabel:=I;
End;

{ Lit une cible de saut : numero de ligne ou etiquette }
Function ParseTarget(Var Ln,Ps: Integer): Boolean;
Var W: String; N: Real; I: Integer;
Begin
 ParseTarget:=False;
 SkipSp;
 If IsDigit(Cur) Then Begin
  N:=ReadNumber;
  I:=LineIdxExact(Round(N));
  If I=0 Then Begin Fail(8);Exit;End;
  Ln:=I;Ps:=1;ParseTarget:=True;
 End Else If IsAlpha(Cur) Then Begin
  W:=ReadWord;
  I:=FindLabel(W);
  If I=0 Then Begin Fail(8);Exit;End;
  Ln:=LabLine[I];Ps:=LabPos[I];ParseTarget:=True;
 End Else Fail(2);
End;

Procedure SkipToStmtEnd;
Var Q: Boolean;
Begin
 Q:=False;
 While P<=Length(Src) Do Begin
  If Src[P]='"' Then Q:=Not Q
  Else If (Not Q) And (Src[P]=':') Then Exit;
  Inc(P);
 End;
End;

{ position apres l'instruction commencant en S (jusqu'a ':' hors guillemets) }
Function StmtEndPos(Const T: String; S: Integer): Integer;
Var Q: Boolean;
Begin
 Q:=False;
 While S<=Length(T) Do Begin
  If T[S]='"' Then Q:=Not Q
  Else If (Not Q) And (T[S]=':') Then Begin StmtEndPos:=S;Exit;End;
  Inc(S);
 End;
 StmtEndPos:=S;
End;

{ ------------------------ sortie PRINT --------------------------------- }

Function PrCol(Dest: Integer): Integer;
Begin
 If Dest=0 Then PrCol:=OCX
 Else If Dest>0 Then PrCol:=FT[Dest].Col
 Else PrCol:=PrnCol;
End;

Procedure PrStr(Dest: Integer; Const S: String);
Var I: Integer;
Begin
 If Dest=0 Then Begin OutStr(S);Exit;End;
 If Dest>0 Then Begin
  {$I-}
  Write(FT[Dest].T,S);
  {$I+}
  If IOResult<>0 Then Fail(57);
  For I:=1 To Length(S) Do If S[I]=#10 Then FT[Dest].Col:=0 Else Inc(FT[Dest].Col);
  Exit;
 End;
 If Not PrnOpen Then Begin
  Assign(PrnF,'ST.PRN');
  {$I-}
  Append(PrnF);
  If IOResult<>0 Then Rewrite(PrnF);
  {$I+}
  PrnOpen:=True;
 End;
 Write(PrnF,S);
 PrnCol:=PrnCol+Length(S);
End;

Procedure PrNL(Dest: Integer);
Begin
 If Dest=0 Then Begin OutNewLine;Exit;End;
 If Dest>0 Then Begin
  {$I-}
  WriteLn(FT[Dest].T);
  {$I+}
  If IOResult<>0 Then Fail(57);
  FT[Dest].Col:=0;
  Exit;
 End;
 If PrnOpen Then WriteLn(PrnF);
 PrnCol:=0;
End;

Function UsingFormat(Const Fmt: String; Var V: TVal; Var FP: Integer): String;
{ formate un element selon le gabarit Fmt a partir de FP ; litteraux copies }
Var R: String; C: Char; I,Pre,Dcm,W: Integer; Pt,Comma,Plus,Trail: Boolean; S: String;
    X: Real; Wrapped: Boolean;
Begin
 R:='';Wrapped:=False;
 While (FP<=Length(Fmt)) Or (Not Wrapped) Do Begin
  If FP>Length(Fmt) Then Begin FP:=1;Wrapped:=True;End;
  C:=Fmt[FP];
  If (C='!') Or (C='&') Or (C='\') Or (C='#') Or ((C='+') And (FP<Length(Fmt)) And
     ((Fmt[FP+1]='#') Or (Fmt[FP+1]='.'))) Or (C='.') Then Begin
   If C='!' Then Begin
    Inc(FP);S:=StrOf(V);If S='' Then S:=' ';
    UsingFormat:=R+S[1];Exit;
   End;
   If C='&' Then Begin Inc(FP);UsingFormat:=R+StrOf(V);Exit;End;
   If C='\' Then Begin
    W:=1;Inc(FP);
    While (FP<=Length(Fmt)) And (Fmt[FP]<>'\') Do Begin Inc(W);Inc(FP);End;
    Inc(FP);Inc(W);
    S:=StrOf(V);
    While Length(S)<W Do S:=S+' ';
    UsingFormat:=R+Copy(S,1,W);Exit;
   End;
   { champ numerique }
   Plus:=False;Pre:=0;Dcm:=0;Pt:=False;Comma:=False;Trail:=False;
   If C='+' Then Begin Plus:=True;Inc(FP);End;
   While (FP<=Length(Fmt)) And ((Fmt[FP]='#') Or (Fmt[FP]=',') Or ((Fmt[FP]='.') And Not Pt)) Do Begin
    If Fmt[FP]='.' Then Pt:=True
    Else If Fmt[FP]=',' Then Comma:=True
    Else If Pt Then Inc(Dcm) Else Inc(Pre);
    Inc(FP);
   End;
   If (FP<=Length(Fmt)) And (Fmt[FP]='-') Then Begin Trail:=True;Inc(FP);End;
   X:=NumOf(V);
   Str(Abs(X):0:Dcm,S);
   If Comma Then Begin
    I:=Pos('.',S);If I=0 Then I:=Length(S)+1;
    I:=I-3;
    While I>1 Do Begin Insert(',',S,I);I:=I-3;End;
   End;
   If X<0 Then Begin If Trail Then S:=S+'-' Else S:='-'+S;End
   Else If Plus Then S:='+'+S
   Else If Trail Then S:=S+' ';
   W:=Pre+Dcm;If Pt Then Inc(W);
   If Comma Then W:=W+(Pre-1) Div 3;
   If Plus Or (X<0) Then Inc(W);
   While Length(S)<W Do S:=' '+S;
   If Length(S)>W Then S:='%'+S;
   UsingFormat:=R+S;Exit;
  End Else Begin
   If (C='_') And (FP<Length(Fmt)) Then Begin Inc(FP);C:=Fmt[FP];End;
   R:=R+C;Inc(FP);
  End;
 End;
 UsingFormat:=R+'?';
End;

Procedure DoPrint(Dest: Integer);
Var NL: Boolean; V: TVal; S,W: String; Col,I,Wd,N: Integer; Fmt: String; FP: Integer;
Begin
 NL:=True;
 If Dest=0 Then Wd:=OutWidth Else If Dest<0 Then Wd:=PrnWidth Else Wd:=255;
 SkipSp;
 If AcceptWord('USING') Then Begin
  V:=EvalExpr;Fmt:=StrOf(V);
  Expect(';');
  FP:=1;
  While (ErrCode=0) And (Not AtStmtEnd) Do Begin
   SkipSp;
   If (Cur=';') Or (Cur=',') Then Begin Inc(P);NL:=False;End
   Else Begin
    V:=EvalExpr;
    If ErrCode<>0 Then Exit;
    If FP>Length(Fmt) Then FP:=1;
    PrStr(Dest,UsingFormat(Fmt,V,FP));
    NL:=True;
   End;
  End;
  If FP<=Length(Fmt) Then Begin
   If (Fmt[FP]<>'#') And (Fmt[FP]<>'\') And (Fmt[FP]<>'!') And (Fmt[FP]<>'&') Then
    PrStr(Dest,Copy(Fmt,FP,255));
  End;
  If NL Then PrNL(Dest);
  Exit;
 End;
 While (ErrCode=0) And (Not AtStmtEnd) Do Begin
  SkipSp;
  If Cur=';' Then Begin Inc(P);NL:=False;End
  Else If Cur=',' Then Begin
   Inc(P);NL:=False;
   Col:=PrCol(Dest);
   I:=((Col Div 14)+1)*14-Col;
   S:='';
   While I>0 Do Begin S:=S+' ';Dec(I);End;
   If Col+Length(S)>=Wd Then Begin PrNL(Dest);End Else PrStr(Dest,S);
  End Else Begin
   W:=PeekWord;
   If (W='TAB') Or (W='SPC') Then Begin
    AcceptWord(W);Expect('(');V:=EvalExpr;Expect(')');
    N:=ToLong(NumOf(V));
    If ErrCode<>0 Then Exit;
    Col:=PrCol(Dest);
    If W='SPC' Then Begin
     If N<0 Then N:=0;
     If N>255 Then N:=N Mod 255;
     If (N>=Wd) And (Wd>0) Then N:=N Mod Wd;
     S:='';
     For I:=1 To N Do S:=S+' ';
     PrStr(Dest,S);
    End Else Begin
     If N>255 Then N:=N Mod 256;
     If (N>=Wd) And (Wd>0) Then N:=N Mod Wd;
     If N<1 Then N:=1;
     If Col+1>N Then PrNL(Dest);
     Col:=PrCol(Dest);
     S:='';
     For I:=Col+1 To N-1 Do S:=S+' ';
     PrStr(Dest,S);
    End;
    NL:=True;
   End Else Begin
    V:=EvalExpr;
    If ErrCode<>0 Then Exit;
    If V.IsStr Then PrStr(Dest,V.S)
    Else Begin
     S:=NumStr(V.N);
     If V.N>=0 Then S:=' '+S;
     PrStr(Dest,S);
    End;
    NL:=True;
   End;
  End;
 End;
 If NL Then PrNL(Dest);
 If Dest=0 Then OutFlush(False);
End;

{ ------------------------ lecture clavier ------------------------------ }

Function GetKeyWait: Integer;
{ retourne un code (>=256 touche etendue) ; attend }
Var K: Integer; Ch: Char;
Begin
 Repeat
  If KeyQ<>'' Then Begin
   If (KeyQ[1]=#0) And (Length(KeyQ)>1) Then Begin
    K:=256+Ord(KeyQ[2]);Delete(KeyQ,1,2);
   End Else Begin K:=Ord(KeyQ[1]);Delete(KeyQ,1,1);End;
   GetKeyWait:=K;Exit;
  End;
  If KeyPressed Then Begin
   Ch:=ReadKey;
   If Ch=#0 Then GetKeyWait:=256+Ord(ReadKey) Else GetKeyWait:=Ord(Ch);
   Exit;
  End;
  OutFlush(False);
  RunPoll;
  Delay(4);
 Until QuitReq;
 GetKeyWait:=K_ESC;
End;

Procedure OutCursor;
{ inverse la cellule du curseur dans le tampon OUTPUT }
Var Y: Integer; Base: LongInt;
Begin
 If (OCX<0) Or (OCX>=OUT_COLS) Or (OCY<0) Or (OCY>=OUT_ROWS) Then Exit;
 Base:=LongInt(OCY)*16*OUT_RB+OCX;
 For Y:=2 To 13 Do
  OutBuf^[Base+LongInt(Y)*OUT_RB]:=OutBuf^[Base+LongInt(Y)*OUT_RB] Xor $FF;
 If OutLive And (Not OutPending) Then OBlitRect(OCX*8,OCY*16,OCX*8+7,OCY*16+15);
End;

Function ReadOutLine(Var S: String; MaxLen: Integer; NoNL: Boolean): Boolean;
Var K: Integer; Done: Boolean; StartX,StartY: Integer;
Begin
 S:='';Done:=False;ReadOutLine:=True;
 OutFlush(True);
 StartX:=OCX;StartY:=OCY;
 OutCursor;
 Repeat
  K:=GetKeyWait;
  OutCursor;
  If (K=K_CTRLC) Or (K=K_CTRLG) Then Begin
   BreakReq:=True;ReadOutLine:=False;Done:=True;
   If K=K_CTRLC Then LastRunMsg:='STOP';
  End Else If K=K_ENTER Then Begin
   Done:=True;
  End Else If K=K_BKSP Then Begin
   If Length(S)>0 Then Begin
    S[0]:=Chr(Length(S)-1);
    If OCX>0 Then Dec(OCX) Else If OCY>StartY Then Begin Dec(OCY);OCX:=OutWidth-1;End;
    OGlyph(OCX,OCY,' ');
   End;
  End Else If (K>=32) And (K<256) And (Length(S)<MaxLen) Then Begin
   S:=S+Chr(K);
   OutCh(Chr(K));
  End;
  If Not Done Then OutCursor;
 Until Done;
 If Not NoNL Then OutNewLine;
 OutFlush(True);
End;

{ ----------------------- LValue (variable ou element) ------------------- }

Function ParseLValue(Var Q: PVar; Var Flat: LongInt): Boolean;
Var W: String; Ix: TIdx; N: Integer; V: TVal;
Begin
 ParseLValue:=False;
 SkipSp;
 If Not IsAlpha(Cur) Then Begin
  If IsDigit(Cur) Or (Cur='"') Or (Cur='.') Then Fail(104) Else Fail(2);
  Exit;
 End;
 W:=ReadWord;
 Q:=FindVar(W,True);
 Flat:=0;
 SkipSp;
 If Cur='(' Then Begin
  Inc(P);N:=0;
  Repeat
   Inc(N);
   If N>8 Then Begin Fail(9);Exit;End;
   V:=EvalExpr;
   Ix[N]:=ToLong(NumOf(V));
  Until (ErrCode<>0) Or (Not Accept(','));
  Expect(')');
  If ErrCode<>0 Then Exit;
  Flat:=ElemIdx(Q,Ix,N);
 End Else If Q^.IsArr Then Begin Fail(13);Exit;End;
 ParseLValue:=ErrCode=0;
End;

Function ReadFileToken(N: Integer; WantStr: Boolean; Var Tok: String): Boolean;
Var C: Integer; Ch: Char; Q: Boolean;
 Function NextCh: Integer;
 Begin
  If FT[N].Pb>=0 Then Begin NextCh:=FT[N].Pb;FT[N].Pb:=-1;End
  Else If Eof(FT[N].T) Then NextCh:=-1
  Else Begin Read(FT[N].T,Ch);NextCh:=Ord(Ch);End;
 End;
Begin
 Tok:='';
 ReadFileToken:=True;
 C:=NextCh;
 While (C=32) Or (C=9) Or (C=13) Or (C=10) Or ((C=44) And Not WantStr) Do C:=NextCh;
 If C<0 Then Begin ReadFileToken:=False;Exit;End;
 If C=34 Then Begin
  C:=NextCh;
  While (C>=0) And (C<>34) Do Begin Tok:=Tok+Chr(C);C:=NextCh;End;
  C:=NextCh;
  While (C=32) Do C:=NextCh;
  If (C<>44) And (C>=0) Then FT[N].Pb:=C;
  Exit;
 End;
 While (C>=0) And (C<>44) And (C<>13) And (C<>10) Do Begin Tok:=Tok+Chr(C);C:=NextCh;End;
 If C=13 Then Begin
  C:=NextCh;
  If C<>10 Then FT[N].Pb:=C;
 End;
 Tok:=TrimStr(Tok);
End;

Procedure DoInput(LineMode: Boolean);
Var Prompt: String; ShowQ,NoNL: Boolean; V: TVal; Q: Array[1..15] Of PVar; Fl: Array[1..15] Of LongInt;
    NT,I,FN: Integer; Txt,Item: String; Ok,Again: Boolean; Pos1: Integer; X: TVal;
    Fields: Array[1..16] Of String; NF: Integer; InQ: Boolean;
Begin
 FN:=0;NoNL:=False;
 SkipSp;
 If Cur=';' Then Begin Inc(P);NoNL:=True;SkipSp;End;
 If Cur='#' Then Begin
  Inc(P);
  V:=EvalExpr;FN:=ToLong(NumOf(V));
  If (FN<1) Or (FN>15) Or (Not FT[FN].Used) Then Begin Fail(52);Exit;End;
  If FT[FN].Mode In ['O','A'] Then Begin Fail(54);Exit;End;
  Expect(',');
 End;
 Prompt:='';ShowQ:=True;
 If (FN=0) Then Begin
  SkipSp;
  If Cur='"' Then Begin
   V:=EvalPrimary;Prompt:=V.S;
   SkipSp;
   If Cur=';' Then Begin Inc(P);ShowQ:=True;End
   Else If Cur=',' Then Begin Inc(P);ShowQ:=False;End
   Else ShowQ:=True;
  End;
  If LineMode Then ShowQ:=False;
 End;
 NT:=0;
 Repeat
  Inc(NT);
  If NT>15 Then Begin Fail(210);Exit;End;
  If Not ParseLValue(Q[NT],Fl[NT]) Then Exit;
 Until (ErrCode<>0) Or (Not Accept(','));
 If ErrCode<>0 Then Exit;
 If FN>0 Then Begin
  For I:=1 To NT Do Begin
   If LineMode Then Begin
    If Eof(FT[FN].T) Then Begin Fail(62);Exit;End;
    {$I-}ReadLn(FT[FN].T,Item);{$I+}
    If IOResult<>0 Then Begin Fail(57);Exit;End;
   End Else Begin
    If Not ReadFileToken(FN,Q[I]^.Typ=2,Item) Then Begin Fail(62);Exit;End;
   End;
   If Q[I]^.Typ=2 Then MkStr(X,Item) Else MkNum(X,ValStr(Item));
   SetVarVal(Q[I],Fl[I],X);
  End;
  Exit;
 End;
 Win[W_OUT].Open:=True;
 Repeat
  Again:=False;
  If Prompt<>'' Then OutStr(Prompt);
  If ShowQ Then OutStr('? ');
  If Not ReadOutLine(Txt,255,NoNL) Then Exit;
  If LineMode Then Begin
   MkStr(X,Txt);SetVarVal(Q[1],Fl[1],X);
  End Else Begin
   NF:=0;Item:='';Ok:=True;Pos1:=1;InQ:=False;
   While Pos1<=Length(Txt) Do Begin
    If Txt[Pos1]='"' Then InQ:=Not InQ;
    If (Txt[Pos1]=',') And (Not InQ) Then Begin
     Inc(NF);If NF<=15 Then Fields[NF]:=TrimStr(Item);Item:='';
    End Else Item:=Item+Txt[Pos1];
    Inc(Pos1);
   End;
   Inc(NF);If NF<=15 Then Fields[NF]:=TrimStr(Item);
   If NF<>NT Then Ok:=False;
   If Ok Then
    For I:=1 To NT Do Begin
     Item:=Fields[I];
     If (Length(Item)>=2) And (Item[1]='"') And (Item[Length(Item)]='"') Then
      Item:=Copy(Item,2,Length(Item)-2);
     If Q[I]^.Typ=2 Then MkStr(X,Item)
     Else Begin
      If (Item='') Or ((Not IsDigit(Item[1])) And (Item[1]<>'-') And (Item[1]<>'+')
         And (Item[1]<>'.') And (Item[1]<>'&')) Then Ok:=False;
      MkNum(X,ValStr(Item));
     End;
     If Ok Then Begin SetVarVal(Q[I],Fl[I],X);If ErrCode<>0 Then Exit;End;
    End;
   If Not Ok Then Begin
    OutLn(ErrText(108));
    Again:=True;
   End;
  End;
 Until Not Again;
End;

{ -------------------------- DATA / READ -------------------------------- }

Function NextData(Var Item: String): Boolean;
Var T: String; Q,K: Integer; Quoted: Boolean; Found: Boolean; W: String;
Begin
 NextData:=False;
 Repeat
  If DatPos>0 Then Begin
   T:=LTxt[DatLine]^;
   Q:=DatPos;
   While (Q<=Length(T)) And (T[Q]=' ') Do Inc(Q);
   If (Q>Length(T)) Or (T[Q]=':') Then Begin
    DatScan:=Q;If Q<=Length(T) Then Inc(DatScan);
    DatPos:=0;
   End Else Begin
    Item:='';Quoted:=False;
    If T[Q]='"' Then Begin
     Quoted:=True;Inc(Q);
     While (Q<=Length(T)) And (T[Q]<>'"') Do Begin Item:=Item+T[Q];Inc(Q);End;
     If Q<=Length(T) Then Inc(Q);
     While (Q<=Length(T)) And (T[Q]=' ') Do Inc(Q);
    End Else Begin
     While (Q<=Length(T)) And (T[Q]<>',') And (T[Q]<>':') Do Begin Item:=Item+T[Q];Inc(Q);End;
     Item:=TrimStr(Item);
    End;
    If (Q<=Length(T)) And (T[Q]=',') Then DatPos:=Q+1 Else DatPos:=Q;
    NextData:=True;Exit;
   End;
  End Else Begin
   If DatLine>LCnt Then Exit;
   T:=LTxt[DatLine]^;
   Q:=DatScan;Found:=False;
   While (Not Found) And (Q<=Length(T)) Do Begin
    While (Q<=Length(T)) And (T[Q]=' ') Do Inc(Q);
    If Q>Length(T) Then Q:=Length(T)+1
    Else If T[Q]='''' Then Q:=Length(T)+1
    Else Begin
     W:='';K:=Q;
     While (K<=Length(T)) And IsIdCh(T[K]) Do Begin W:=W+UpCase(T[K]);Inc(K);End;
     If W='DATA' Then Begin Found:=True;DatPos:=K;End
     Else If W='REM' Then Q:=Length(T)+1
     Else Q:=StmtEndPos(T,Q)+1;
    End;
   End;
   If Not Found Then Begin Inc(DatLine);DatScan:=1;DatPos:=0;End;
  End;
 Until False;
End;

Procedure DoRead;
Var Q: PVar; Fl: LongInt; Item: String; X: TVal;
Begin
 Repeat
  If Not ParseLValue(Q,Fl) Then Exit;
  If Not NextData(Item) Then Begin Fail(4);Exit;End;
  If Q^.Typ=2 Then MkStr(X,Item)
  Else Begin
   If (Item<>'') And (Not IsDigit(Item[1])) And (Item[1]<>'-') And (Item[1]<>'+')
      And (Item[1]<>'.') And (Item[1]<>'&') Then Begin Fail(13);Exit;End;
   MkNum(X,ValStr(Item));
  End;
  SetVarVal(Q,Fl,X);
 Until (ErrCode<>0) Or (Not Accept(','));
End;

{ -------------------------- FICHIERS ----------------------------------- }

Function ResolveFile(Const N: String): String;
Begin
 If FileExists(N) Then ResolveFile:=N
 Else If FileExists(Upper(N)) Then ResolveFile:=Upper(N)
 Else If FileExists(LowerStr(N)) Then ResolveFile:=LowerStr(N)
 Else ResolveFile:=N;
End;

Procedure CloseFile(N: Integer);
Begin
 If (N<1) Or (N>15) Or (Not FT[N].Used) Then Exit;
 {$I-}
 If FT[N].Mode='R' Then Close(FT[N].F) Else Close(FT[N].T);
 {$I+}
 If IOResult<>0 Then ;
 If FT[N].Buf<>Nil Then Begin FreeMem(FT[N].Buf,FT[N].RecLen);FT[N].Buf:=Nil;End;
 FT[N].Used:=False;
End;

Procedure CloseAllFiles;
Var I: Integer;
Begin
 For I:=1 To 15 Do CloseFile(I);
 If PrnOpen Then Begin {$I-}Close(PrnF);{$I+}If IOResult<>0 Then ;PrnOpen:=False;End;
End;

Procedure OpenFile(N: Integer; Mode: Char; Const Name: String; RecLen: Integer);
Var R: Integer; Nm: String;
Begin
 If (N<1) Or (N>15) Then Begin Fail(52);Exit;End;
 If FT[N].Used Then Begin Fail(55);Exit;End;
 If Not (Mode In ['I','O','A','R']) Then Begin Fail(54);Exit;End;
 If Name='' Then Begin Fail(64);Exit;End;
 Nm:=Name;
 If (Mode='I') Or (Mode='R') Or (Mode='A') Then Nm:=ResolveFile(Name);
 FT[N].Mode:=Mode;FT[N].Name:=Nm;FT[N].Pb:=-1;FT[N].Col:=0;FT[N].Rec:=0;
 FT[N].Buf:=Nil;FT[N].RecLen:=128;
 {$I-}
 Case Mode Of
  'I': Begin
        If Not FileExists(Nm) Then Begin Fail(53);Exit;End;
        Assign(FT[N].T,Nm);Reset(FT[N].T);
       End;
  'O': Begin Assign(FT[N].T,Nm);Rewrite(FT[N].T);End;
  'A': Begin
        Assign(FT[N].T,Nm);
        If FileExists(Nm) Then Append(FT[N].T) Else Rewrite(FT[N].T);
       End;
  'R': Begin
        If RecLen>0 Then FT[N].RecLen:=RecLen;
        If FT[N].RecLen>4096 Then FT[N].RecLen:=4096;
        Assign(FT[N].F,Nm);
        If FileExists(Nm) Then Reset(FT[N].F,1) Else Rewrite(FT[N].F,1);
        GetMem(FT[N].Buf,FT[N].RecLen);
        FillChar(FT[N].Buf^,FT[N].RecLen,32);
       End;
 End;
 {$I+}
 R:=IOResult;
 If R<>0 Then Begin
  If R=2 Then Fail(53) Else If R=3 Then Fail(53) Else Fail(57);
  Exit;
 End;
 FT[N].Used:=True;
End;

Function FileArg: Integer;
{ lit #n ou n }
Var V: TVal; N: Integer;
Begin
 SkipSp;
 If Cur='#' Then Inc(P);
 V:=EvalExpr;
 N:=ToLong(NumOf(V));
 If (N<1) Or (N>15) Or (Not FT[N].Used) Then Begin Fail(52);N:=0;End;
 FileArg:=N;
End;

Procedure DoOpen;
Var V,V2: TVal; Mode: Char; N: Integer; Nm: String; RL: Integer; M: String;
Begin
 SkipSp;
 V:=EvalExpr;
 If ErrCode<>0 Then Exit;
 V2:=V;
 SkipSp;
 If PeekWord='FOR' Then Begin
  { OPEN "nom" FOR INPUT|OUTPUT|APPEND|RANDOM AS #n [LEN=n] }
  Nm:=StrOf(V);
  AcceptWord('FOR');
  M:=ReadWord;
  If M='INPUT' Then Mode:='I' Else If M='OUTPUT' Then Mode:='O'
  Else If M='APPEND' Then Mode:='A' Else If M='RANDOM' Then Mode:='R' Else Begin Fail(54);Exit;End;
  If Not AcceptWord('AS') Then Begin Fail(2);Exit;End;
  N:=0;
  SkipSp;If Cur='#' Then Inc(P);
  V:=EvalExpr;N:=ToLong(NumOf(V));
  RL:=128;
  If AcceptWord('LEN') Then Begin Expect('=');V:=EvalExpr;RL:=ToLong(NumOf(V));End;
  If ErrCode=0 Then OpenFile(N,Mode,Nm,RL);
  Exit;
 End;
 M:=StrOf(V);
 If M='' Then Begin Fail(54);Exit;End;
 Mode:=M[1];
 If Not (Mode In ['I','O','R']) Then Begin Fail(54);Exit;End;
 Expect(',');
 SkipSp;If Cur='#' Then Inc(P);
 V:=EvalExpr;N:=ToLong(NumOf(V));
 Expect(',');
 SkipSp;
 If Cur=',' Then Inc(P);
 V:=EvalExpr;Nm:=StrOf(V);
 RL:=128;
 If Accept(',') Then Begin V:=EvalExpr;RL:=ToLong(NumOf(V));End;
 If ErrCode=0 Then OpenFile(N,Mode,Nm,RL);
End;

Procedure DoField;
Var N,W,Off: Integer; V: TVal; Q: PVar; Fl: LongInt;
Begin
 N:=FileArg;
 If N=0 Then Exit;
 If FT[N].Mode<>'R' Then Begin Fail(54);Exit;End;
 Off:=0;
 While Accept(',') Do Begin
  V:=EvalExpr;W:=ToLong(NumOf(V));
  If Not AcceptWord('AS') Then Begin Fail(2);Exit;End;
  If Not ParseLValue(Q,Fl) Then Exit;
  If (Q^.Typ<>2) Or Q^.IsArr Then Begin Fail(13);Exit;End;
  If Off+W>FT[N].RecLen Then Begin Fail(31);Exit;End;
  If Q^.S<>Nil Then FreeStr(Q^.S);
  Q^.FFile:=N;Q^.FOff:=Off;Q^.FWid:=W;
  Inc(Off,W);
 End;
End;

Procedure DoLset(Right: Boolean);
Var Q: PVar; Fl: LongInt; V: TVal; S: String; L: Integer;
Begin
 If Not ParseLValue(Q,Fl) Then Exit;
 If Q^.Typ<>2 Then Begin Fail(13);Exit;End;
 Expect('=');
 V:=EvalExpr;S:=StrOf(V);
 If ErrCode<>0 Then Exit;
 If (Not Q^.IsArr) And (Q^.FFile>0) Then FieldSet(Q,S,Right)
 Else Begin
  V:=GetVarVal(Q,Fl);L:=Length(V.S);
  If L=0 Then L:=Length(S);
  If Length(S)>L Then S:=Copy(S,1,L);
  While Length(S)<L Do If Right Then S:=' '+S Else S:=S+' ';
  MkStr(V,S);
  SetVarVal(Q,Fl,V);
 End;
End;

Procedure DoGetPut(IsPut: Boolean);
Var N: Integer; V: TVal; R: LongInt; Cnt: Word;
Begin
 N:=FileArg;
 If N=0 Then Exit;
 If FT[N].Mode<>'R' Then Begin Fail(54);Exit;End;
 R:=FT[N].Rec+1;
 If Accept(',') Then Begin V:=EvalExpr;R:=ToLong(NumOf(V));End;
 If R<1 Then Begin Fail(63);Exit;End;
 {$I-}
 Seek(FT[N].F,(R-1)*FT[N].RecLen);
 If IsPut Then BlockWrite(FT[N].F,FT[N].Buf^,FT[N].RecLen)
 Else Begin
  FillChar(FT[N].Buf^,FT[N].RecLen,32);
  If (R-1)*FT[N].RecLen<FileSize(FT[N].F) Then
   BlockRead(FT[N].F,FT[N].Buf^,FT[N].RecLen,Cnt);
 End;
 {$I+}
 If IOResult<>0 Then Begin Fail(57);Exit;End;
 FT[N].Rec:=R;
End;

Procedure DoWrite;
Var N: Integer; V: TVal; First: Boolean;
Begin
 N:=0;
 SkipSp;
 If Cur='#' Then Begin N:=FileArg;If N=0 Then Exit;Expect(',');End;
 First:=True;
 While (ErrCode=0) And (Not AtStmtEnd) Do Begin
  V:=EvalExpr;
  If ErrCode<>0 Then Exit;
  If Not First Then PrStr(N,',');
  First:=False;
  If V.IsStr Then PrStr(N,'"'+V.S+'"') Else PrStr(N,NumStr(V.N));
  If Not Accept(',') Then Begin
   SkipSp;
   If Cur=';' Then Inc(P);
  End;
 End;
 PrNL(N);
End;

{ ====================================================================== }
{              INTERPRETEUR : FICHIERS PROGRAMME ET COMMANDES            }
{ ====================================================================== }

Type
 PVarF = PVar;
 TLSet = Array[0..8191] Of Byte;
Var
 TronSet,TraceSet,BreakSet : TLSet;
 BreakOn,StopMsg,GfxSaved  : Boolean;
 LLA,LLB  : Array[1..32] Of LongInt;
 LLN      : Integer;
 FollowName : Array[1..8] Of String[34];
 FollowVal  : Array[1..8] Of String[44];
 FollowN    : Integer;
 LastLn     : Integer;
 EditLineReq: LongInt;
 UIDirty : Boolean;     { l'affichage doit etre rafraichi }
 IfCont  : Boolean;     { IF vient de positionner P sur l'instruction a executer }
 GA      : Array[1..8] Of LongInt;
 GH      : Array[1..8] Of Boolean;
 GN      : Integer;

Function GetFileSpec(Const Ext: String): String;
Var V: TVal; S: String;
Begin
 SkipSp;
 If Cur='"' Then Begin V:=EvalPrimary;S:=V.S;End
 Else Begin
  S:='';
  While (P<=Length(Src)) And (Src[P]<>':') And (Src[P]<>',') Do Begin S:=S+Src[P];Inc(P);End;
  S:=TrimStr(S);
 End;
 If S='' Then Begin Fail(64);GetFileSpec:='';Exit;End;
 If Ext<>'' Then S:=AddExt(S,Ext);
 GetFileSpec:=S;
End;

Procedure SetProgTitle(Const Nm: String);
Begin
 ProgName:=Nm;
 If Nm='' Then LstName:='' Else LstName:='\'+Upper(ShortName(Nm));
 UIDirty:=True;
End;

Function LoadProgFile(Const Name: String; Merge: Boolean): Boolean;
{ Les fichiers .BAS de ST BASIC sont du texte ASCII : une ligne numerotee par
  ligne. Erreur 65 : caractere de controle ; erreur 66 : ligne sans numero. }
Var T: Text; Line: String; I: Integer; N: LongInt; Nm: String; Bad: Integer;
Begin
 LoadProgFile:=False;
 Nm:=ResolveFile(Name);
 If Not FileExists(Nm) Then Begin Fail(53);Exit;End;
 {$I-}
 Assign(T,Nm);Reset(T);
 {$I+}
 If IOResult<>0 Then Begin Fail(53);Exit;End;
 If Not Merge Then Begin NewProgram;ClearVars;CloseAllFiles;End;
 Bad:=0;
 While (Not Eof(T)) And (Bad=0) Do Begin
  {$I-}ReadLn(T,Line);{$I+}
  If IOResult<>0 Then Begin Bad:=57;Line:='';End;
  While (Length(Line)>0) And ((Line[Length(Line)]=#13) Or (Line[Length(Line)]=#26)) Do
   Delete(Line,Length(Line),1);
  For I:=1 To Length(Line) Do
   If (Line[I]<' ') And (Line[I]<>#9) And (Bad=0) Then Bad:=65;
  If (Bad=0) And (TrimStr(Line)<>'') Then Begin
   I:=1;
   While (I<=Length(Line)) And ((Line[I]=' ') Or (Line[I]=#9)) Do Inc(I);
   If IsDigit(Line[I]) Then Begin
    N:=0;
    While (I<=Length(Line)) And IsDigit(Line[I]) Do Begin
     If N<65000 Then N:=N*10+Ord(Line[I])-48;
     Inc(I);
    End;
    If TrimStr(Copy(Line,I,255))<>'' Then SetProgLine(N,Copy(Line,I,255));
   End Else Bad:=66;
  End;
 End;
 Close(T);
 If Bad<>0 Then Begin Fail(Bad);Exit;End;
 If Not Merge Then SetProgTitle(Nm);
 LabDirty:=True;
 LoadProgFile:=True;
End;

Function InLList(N: LongInt): Boolean; Forward;

Function SaveProgFile(Const Name: String; Replace: Boolean): Boolean;
Var T: Text; I: Integer;
Begin
 SaveProgFile:=False;
 If (Not Replace) And FileExists(Name) Then Begin Fail(58);Exit;End;
 {$I-}
 Assign(T,Name);Rewrite(T);
 {$I+}
 If IOResult<>0 Then Begin Fail(57);Exit;End;
 For I:=1 To LCnt Do If InLList(LNum[I]) Then WriteLn(T,LineStr(I));
 Close(T);
 SetProgTitle(Name);
 SaveProgFile:=True;
End;

{ ------------------------- plages de lignes ---------------------------- }

Procedure ParseLList;
{ liste de descripteurs de lignes : n, n-m, -m, n- ; separes par des virgules }
Begin
 LLN:=0;
 SkipSp;
 If AtStmtEnd Then Exit;
 Repeat
  SkipSp;
  If LLN>=32 Then Begin Fail(210);Exit;End;
  Inc(LLN);LLA[LLN]:=0;LLB[LLN]:=65535;
  If IsDigit(Cur) Then Begin LLA[LLN]:=Round(ReadNumber);LLB[LLN]:=LLA[LLN];End;
  SkipSp;
  If Cur='-' Then Begin
   Inc(P);LLB[LLN]:=65535;SkipSp;
   If IsDigit(Cur) Then LLB[LLN]:=Round(ReadNumber);
  End;
 Until (ErrCode<>0) Or (Not Accept(','));
End;

Function InLList(N: LongInt): Boolean;
Var I: Integer;
Begin
 If LLN=0 Then Begin InLList:=True;Exit;End;
 InLList:=False;
 For I:=1 To LLN Do If (N>=LLA[I]) And (N<=LLB[I]) Then InLList:=True;
End;

Procedure LSFill(Var S: TLSet; A,B: LongInt; On: Boolean);
Var I: LongInt;
Begin
 If A<0 Then A:=0;
 If B>65535 Then B:=65535;
 For I:=A To B Do
  If On Then S[I Shr 3]:=S[I Shr 3] Or (1 Shl (I And 7))
  Else S[I Shr 3]:=S[I Shr 3] And (Not (1 Shl (I And 7)));
End;

Function LSHas(Var S: TLSet; N: LongInt): Boolean;
Begin
 If (N<0) Or (N>65535) Then LSHas:=False
 Else LSHas:=(S[N Shr 3] And (1 Shl (N And 7)))<>0;
End;

Function LSEmpty(Var S: TLSet): Boolean;
Var I: Integer;
Begin
 LSEmpty:=True;
 For I:=0 To 8191 Do If S[I]<>0 Then LSEmpty:=False;
End;

Function FollowRepr(Q: PVar): String; Forward;

Procedure DoSetCmd(Var S: TLSet; Var Flag: Boolean; On: Boolean);
Var I: Integer;
Begin
 ParseLList;
 If ErrCode<>0 Then Exit;
 If LLN=0 Then LSFill(S,0,65535,On)
 Else For I:=1 To LLN Do LSFill(S,LLA[I],LLB[I],On);
 Flag:=Not LSEmpty(S);
End;

Procedure DoList(ToPrn: Boolean);
Var I: Integer;
Begin
 ParseLList;
 If ErrCode<>0 Then Exit;
 If Not ToPrn Then LstClear;
 For I:=1 To LCnt Do
  If InLList(LNum[I]) Then Begin
   If ToPrn Then Begin PrStr(-1,LineStr(I));PrNL(-1);End
   Else LstAdd(LineStr(I));
  End;
 If Not ToPrn Then Begin
  Win[W_LIST].ScrX:=0;Win[W_LIST].ScrY:=0;
  Win[W_LIST].Open:=True;
  UIDirty:=True;
 End;
End;

{ ------------------------------ RENUM ---------------------------------- }

Var
 RnMap : Array[1..MAXL] Of LongInt;

Function RnLookup(N: LongInt): LongInt;
Var I: Integer;
Begin
 I:=LineIdxExact(N);
 If I=0 Then RnLookup:=N Else RnLookup:=RnMap[I];
End;

Function RenumText(Const T: String): String;
Var R,W: String; I,K: Integer; N: LongInt; Q: Boolean; More: Boolean;
Begin
 R:='';I:=1;Q:=False;
 While I<=Length(T) Do Begin
  If T[I]='"' Then Begin Q:=Not Q;R:=R+T[I];Inc(I);End
  Else If Q Then Begin R:=R+T[I];Inc(I);End
  Else If T[I]='''' Then Begin R:=R+Copy(T,I,255);I:=Length(T)+1;End
  Else If IsAlpha(T[I]) And ((I=1) Or (Not IsIdCh(T[I-1]))) Then Begin
   W:='';K:=I;
   While (K<=Length(T)) And IsIdCh(T[K]) Do Begin W:=W+UpCase(T[K]);Inc(K);End;
   R:=R+Copy(T,I,K-I);I:=K;
   If (W='REM') Then Begin R:=R+Copy(T,I,255);I:=Length(T)+1;End
   Else If W='DATA' Then Begin
    While (I<=Length(T)) And (T[I]<>':') Do Begin R:=R+T[I];Inc(I);End;
   End Else If (W='GOTO') Or (W='GOSUB') Or (W='THEN') Or (W='ELSE') Or (W='RESTORE')
      Or (W='RESUME') Or (W='RUN') Or (W='LIST') Then Begin
    More:=True;
    While More Do Begin
     While (I<=Length(T)) And (T[I]=' ') Do Begin R:=R+' ';Inc(I);End;
     If (I<=Length(T)) And IsDigit(T[I]) Then Begin
      N:=0;
      While (I<=Length(T)) And IsDigit(T[I]) Do Begin N:=N*10+Ord(T[I])-48;Inc(I);End;
      R:=R+IntStr(RnLookup(N));
      While (I<=Length(T)) And (T[I]=' ') Do Begin R:=R+' ';Inc(I);End;
      If ((W='GOTO') Or (W='GOSUB')) And (I<=Length(T)) And (T[I]=',') Then Begin
       R:=R+',';Inc(I);
      End Else More:=False;
     End Else More:=False;
    End;
   End;
  End Else Begin R:=R+T[I];Inc(I);End;
 End;
 RenumText:=R;
End;

Procedure DoRenum;
Var NewS,OldS,Inc2: LongInt; V: TVal; I,K: Integer; Cur2: LongInt; S: String;
Begin
 NewS:=10;OldS:=0;Inc2:=10;
 SkipSp;
 If Not AtStmtEnd Then Begin
  V:=EvalExpr;NewS:=ToLong(NumOf(V));
  If Accept(',') Then Begin V:=EvalExpr;OldS:=ToLong(NumOf(V));End;
  If Accept(',') Then Begin V:=EvalExpr;Inc2:=ToLong(NumOf(V));End;
 End;
 If (ErrCode<>0) Or (Inc2<1) Or (NewS<0) Then Begin If ErrCode=0 Then Fail(31);Exit;End;
 Cur2:=NewS;K:=0;
 For I:=1 To LCnt Do Begin
  If LNum[I]>=OldS Then Begin RnMap[I]:=Cur2;Inc(Cur2,Inc2);Inc(K);End
  Else RnMap[I]:=LNum[I];
  If RnMap[I]>65529 Then Begin Fail(31);Exit;End;
 End;
 For I:=1 To LCnt Do Begin
  S:=RenumText(LTxt[I]^);
  FreeStr(LTxt[I]);
  LTxt[I]:=NewStr(S);
 End;
 For I:=1 To LCnt Do LNum[I]:=RnMap[I];
 ProgChanged;
 { copie du programme renumerote }
 LLN:=0;
 If Not SaveProgFile('BASIC.WRK',True) Then ErrCode:=0;
End;

{ ------------------------- recherche de WEND --------------------------- }

Function ScanFwd(Ln0,Ps0: Integer; Const Open1,Close1: String; Var RL,RP: Integer): Boolean;
Var L,Q,K,Depth: Integer; T,W: String; InQ: Boolean;
Begin
 ScanFwd:=False;
 Depth:=0;
 For L:=Ln0 To LCnt Do Begin
  T:=LTxt[L]^;
  If L=Ln0 Then Q:=Ps0 Else Q:=1;
  InQ:=False;
  While Q<=Length(T) Do Begin
   If T[Q]='"' Then Begin InQ:=Not InQ;Inc(Q);End
   Else If InQ Then Inc(Q)
   Else If T[Q]='''' Then Q:=Length(T)+1
   Else If IsAlpha(T[Q]) And ((Q=1) Or (Not IsIdCh(T[Q-1]))) Then Begin
    W:='';K:=Q;
    While (K<=Length(T)) And IsIdCh(T[K]) Do Begin W:=W+UpCase(T[K]);Inc(K);End;
    If W='REM' Then K:=Length(T)+1
    Else If W=Open1 Then Inc(Depth)
    Else If W=Close1 Then Begin
     If Depth=0 Then Begin RL:=L;RP:=K;ScanFwd:=True;Exit;End;
     Dec(Depth);
    End;
    Q:=K;
   End Else Inc(Q);
  End;
 End;
End;

Function FindElse: Boolean;
{ P apres THEN : cherche le ELSE correspondant dans Src }
Var Q,K,Depth: Integer; W: String; InQ: Boolean;
Begin
 FindElse:=False;
 Depth:=0;InQ:=False;Q:=P;
 While Q<=Length(Src) Do Begin
  If Src[Q]='"' Then Begin InQ:=Not InQ;Inc(Q);End
  Else If InQ Then Inc(Q)
  Else If Src[Q]='''' Then Q:=Length(Src)+1
  Else If IsAlpha(Src[Q]) And ((Q=1) Or (Not IsIdCh(Src[Q-1]))) Then Begin
   W:='';K:=Q;
   While (K<=Length(Src)) And IsIdCh(Src[K]) Do Begin W:=W+UpCase(Src[K]);Inc(K);End;
   If W='REM' Then K:=Length(Src)+1
   Else If W='IF' Then Inc(Depth)
   Else If W='ELSE' Then Begin
    If Depth=0 Then Begin P:=K;FindElse:=True;Exit;End;
    Dec(Depth);
   End;
   Q:=K;
  End Else Inc(Q);
 End;
 P:=Length(Src)+1;
End;

{ cherche dans Src (a partir de P) le mot Close1 correspondant ; P est place apres }
Function ScanSrc(Const Open1,Close1: String): Boolean;
Var Q,K,Depth: Integer; W: String; InQ: Boolean;
Begin
 ScanSrc:=False;
 Depth:=0;InQ:=False;Q:=P;
 While Q<=Length(Src) Do Begin
  If Src[Q]='"' Then Begin InQ:=Not InQ;Inc(Q);End
  Else If InQ Then Inc(Q)
  Else If IsAlpha(Src[Q]) And ((Q=1) Or (Not IsIdCh(Src[Q-1]))) Then Begin
   W:='';K:=Q;
   While (K<=Length(Src)) And IsIdCh(Src[K]) Do Begin W:=W+UpCase(Src[K]);Inc(K);End;
   If W=Open1 Then Inc(Depth)
   Else If W=Close1 Then Begin
    If Depth=0 Then Begin P:=K;ScanSrc:=True;Exit;End;
    Dec(Depth);
   End;
   Q:=K;
  End Else Inc(Q);
 End;
End;

{ ------------------------ instructions de flux ------------------------- }

Procedure DoGoto(IsSub: Boolean);
Var Ln,Ps: Integer;
Begin
 If Not ParseTarget(Ln,Ps) Then Exit;
 If IsSub Then Begin
  If GSP>=16 Then Begin Fail(110);Exit;End;
  Inc(GSP);GS[GSP].Ln:=PCLine;GS[GSP].Ps:=P;
 End;
 JumpF:=True;JLine:=Ln;JPos:=Ps;
End;

Procedure DoOn;
Var V: TVal; N,K,I: Integer; IsSub: Boolean; W: String; Ln,Ps,TLn,TPs: Integer; Found: Boolean;
Begin
 SkipSp;
 If PeekWord='ERROR' Then Begin
  AcceptWord('ERROR');
  If Not AcceptWord('GOTO') Then Begin Fail(2);Exit;End;
  SkipSp;
  If IsDigit(Cur) Then Begin
   Ps:=P;
   If ReadNumber=0 Then Begin
    OnErrLine:=0;
    If InErrH Then Begin InErrH:=False;ErrCode:=ErrNum;End;
    Exit;
   End;
   P:=Ps;
  End;
  If ParseTarget(Ln,Ps) Then Begin OnErrLine:=Ln;OnErrPos:=Ps;End;
  Exit;
 End;
 V:=EvalExpr;
 N:=ToLong(NumOf(V));
 If (ErrCode=0) And ((N<0) Or (N>255)) Then Begin Fail(102);Exit;End;
 W:=ReadWord;
 If W='GOTO' Then IsSub:=False Else If W='GOSUB' Then IsSub:=True
 Else Begin Fail(2);Exit;End;
 K:=0;Found:=False;TLn:=0;TPs:=0;
 Repeat
  Inc(K);
  If Not ParseTarget(Ln,Ps) Then Exit;
  If K=N Then Begin Found:=True;TLn:=Ln;TPs:=Ps;End;
 Until Not Accept(',');
 If Found Then Begin
  If IsSub Then Begin
   If GSP>=16 Then Begin Fail(110);Exit;End;
   Inc(GSP);GS[GSP].Ln:=PCLine;GS[GSP].Ps:=P;
  End;
  JumpF:=True;JLine:=TLn;JPos:=TPs;
 End;
End;

Function FindClosing: Boolean;
{ P apres THEN (condition fausse, sans ELSE) : cherche le NEXT/WEND qui ferme
  la boucle englobant le IF ; P est place sur ce mot }
Var Q,K,DF,DW: Integer; W: String; InQ: Boolean;
Begin
 FindClosing:=False;
 DF:=0;DW:=0;InQ:=False;Q:=P;
 While Q<=Length(Src) Do Begin
  If Src[Q]='"' Then Begin InQ:=Not InQ;Inc(Q);End
  Else If InQ Then Inc(Q)
  Else If Src[Q]='''' Then Q:=Length(Src)+1
  Else If IsAlpha(Src[Q]) And ((Q=1) Or (Not IsIdCh(Src[Q-1]))) Then Begin
   W:='';K:=Q;
   While (K<=Length(Src)) And IsIdCh(Src[K]) Do Begin W:=W+UpCase(Src[K]);Inc(K);End;
   If W='REM' Then K:=Length(Src)+1
   Else If W='FOR' Then Inc(DF)
   Else If W='WHILE' Then Inc(DW)
   Else If W='NEXT' Then Begin
    If DF=0 Then Begin P:=Q;FindClosing:=True;Exit;End;
    Dec(DF);
   End Else If W='WEND' Then Begin
    If DW=0 Then Begin P:=Q;FindClosing:=True;Exit;End;
    Dec(DW);
   End;
   Q:=K;
  End Else Inc(Q);
 End;
End;

Procedure DoIf;
Var V: TVal; W: String; Ln,Ps,P0: Integer; Cond: Boolean;
Begin
 V:=EvalExpr;
 If ErrCode<>0 Then Exit;
 If V.IsStr Then Begin Fail(13);Exit;End;
 Cond:=(V.N<>0);
 W:=ReadWord;
 If (W<>'THEN') And (W<>'GOTO') Then Begin Fail(2);Exit;End;
 P0:=P;
 If Not Cond Then Begin
  If Not FindElse Then Begin
   P:=P0;
   If Not FindClosing Then P:=Length(Src)+1;
   IfCont:=True;
   Exit;
  End;
 End;
 IfCont:=True;
 SkipSp;
 If (W='GOTO') And Cond Then Begin
  If ParseTarget(Ln,Ps) Then Begin JumpF:=True;JLine:=Ln;JPos:=Ps;End;
  Exit;
 End;
 If IsDigit(Cur) Then Begin
  If ParseTarget(Ln,Ps) Then Begin JumpF:=True;JLine:=Ln;JPos:=Ps;End;
 End;
End;

Procedure DoFor;
Var W: String; Q: PVar; Start,Lim,Stp: TVal; I,K: Integer; X: TVal;
Begin
 W:=ReadWord;
 If W='' Then Begin Fail(2);Exit;End;
 Q:=FindVar(W,True);
 If (Q^.Typ=2) Or Q^.IsArr Then Begin Fail(13);Exit;End;
 Expect('=');
 Start:=EvalExpr;
 If Not AcceptWord('TO') Then Begin Fail(2);Exit;End;
 Lim:=EvalExpr;
 MkNum(Stp,1);
 If AcceptWord('STEP') Then Stp:=EvalExpr;
 If ErrCode<>0 Then Exit;
 SetVarVal(Q,0,Start);
 If ErrCode<>0 Then Exit;
 K:=0;
 For I:=1 To FSP Do If FS[I].V=Q Then K:=I;
 If K>0 Then FSP:=K-1;
 If FSP>=16 Then Begin Fail(223);Exit;End;
 Inc(FSP);
 FS[FSP].V:=Q;FS[FSP].Lim:=NumOf(Lim);FS[FSP].Stp:=NumOf(Stp);
 FS[FSP].Ln:=PCLine;FS[FSP].Ps:=P;
End;

Procedure DoNext;
Var W: String; Q: PVar; I,K: Integer; X: TVal; Done,Again: Boolean; Val1: Real;
Begin
 Repeat
  Done:=False;Again:=False;
  SkipSp;W:='';
  If IsAlpha(Cur) And (PeekWord<>'ELSE') Then W:=ReadWord;
  If FSP=0 Then Begin Fail(205);Exit;End;
  If W<>'' Then Begin
   Q:=FindVar(W,False);K:=0;
   For I:=FSP DownTo 1 Do If (K=0) And (FS[I].V=Q) Then K:=I;
   If K=0 Then Begin Fail(205);Exit;End;
   FSP:=K;
  End;
  Q:=FS[FSP].V;
  Val1:=Q^.N+FS[FSP].Stp;
  MkNum(X,Val1);
  SetVarVal(Q,0,X);
  If ErrCode<>0 Then Exit;
  If ((FS[FSP].Stp>=0) And (Q^.N<=FS[FSP].Lim)) Or
     ((FS[FSP].Stp<0) And (Q^.N>=FS[FSP].Lim)) Then Begin
   If FS[FSP].Ln=0 Then Begin P:=FS[FSP].Ps;IfCont:=True;End
   Else Begin JumpF:=True;JLine:=FS[FSP].Ln;JPos:=FS[FSP].Ps;End;
   Exit;
  End;
  Dec(FSP);
  If Accept(',') Then Again:=True;
 Until Not Again;
End;

Procedure DoWhile;
Var V: TVal; RL,RP: Integer;
Begin
 V:=EvalExpr;
 If ErrCode<>0 Then Exit;
 If V.IsStr Then Begin Fail(13);Exit;End;
 If V.N<>0 Then Begin
  If (WSP>0) And (WS[WSP].Ln=PCLine) And (WS[WSP].Ps=StmtStart) Then Exit;
  If WSP>=32 Then Begin Fail(7);Exit;End;
  Inc(WSP);WS[WSP].Ln:=PCLine;WS[WSP].Ps:=StmtStart;
 End Else Begin
  If (WSP>0) And (WS[WSP].Ln=PCLine) And (WS[WSP].Ps=StmtStart) Then Dec(WSP);
  If PCLine=0 Then Begin
   If Not ScanSrc('WHILE','WEND') Then Fail(204);
   Exit;
  End;
  If ScanFwd(PCLine,P,'WHILE','WEND',RL,RP) Then Begin
   JumpF:=True;JLine:=RL;JPos:=RP;
  End Else Fail(204);
 End;
End;

Procedure DoReturn;
Begin
 If GSP=0 Then Begin Fail(3);Exit;End;
 If GS[GSP].Ln=0 Then Begin EndF:=True;Dec(GSP);Exit;End;
 JumpF:=True;JLine:=GS[GSP].Ln;JPos:=GS[GSP].Ps;
 Dec(GSP);
End;

Procedure ResetRunState;
Begin
 FSP:=0;GSP:=0;WSP:=0;
 DatLine:=1;DatScan:=1;DatPos:=0;
 OnErrLine:=0;InErrH:=False;
End;

Procedure DoResume;
Var Ln,Ps: Integer; W: String;
Begin
 If Not InErrH Then Begin Fail(20);Exit;End;
 SkipSp;
 If IsDigit(Cur) Then Begin
  If ParseTarget(Ln,Ps) Then Begin JumpF:=True;JLine:=Ln;JPos:=Ps;End;
 End Else If PeekWord='NEXT' Then Begin
  AcceptWord('NEXT');
  JumpF:=True;JLine:=ErrStmtLn;
  JPos:=StmtEndPos(LTxt[ErrStmtLn]^,ErrStmtPos);
  If JPos<=Length(LTxt[ErrStmtLn]^) Then Inc(JPos);
 End Else Begin
  JumpF:=True;JLine:=ErrStmtLn;JPos:=ErrStmtPos;
 End;
 If ErrCode=0 Then InErrH:=False;
End;

{ --------------------------- instructions graphiques ------------------- }

Procedure ParseNums(Max: Integer);
Var I: Integer; V: TVal;
Begin
 GN:=0;
 For I:=1 To 8 Do GH[I]:=False;
 SkipSp;
 If AtStmtEnd Then Exit;
 Repeat
  Inc(GN);
  If GN>Max Then Begin Fail(2);Exit;End;
  SkipSp;
  If (Cur<>',') Then Begin
   V:=EvalExpr;
   If ErrCode<>0 Then Exit;
   GA[GN]:=ToLong(NumOf(V));GH[GN]:=True;
  End;
 Until (ErrCode<>0) Or (Not Accept(','));
End;

Procedure WinRedraw;
Begin
 OutUpdateLive;
 DrawDesktop;
End;

Procedure DoWinCmd(Const W: String);
Var N: Integer;
Begin
 ParseNums(1);
 If ErrCode<>0 Then Exit;
 If (GN<1) Or (Not GH[1]) Then Begin Fail(31);Exit;End;
 If (GA[1]<0) Or (GA[1]>3) Then Begin Fail(30);Exit;End;
 N:=GA[1];
 If W='CLEARW' Then Begin
  Case N Of
   0: EditReq:=EditReq;
   1: Begin LstClear;LstName:='';End;
   2: OutClear;
   3: ConClear;
  End;
  If N=0 Then UIDirty:=True Else If N<>2 Then UIDirty:=True;
 End Else If W='FULLW' Then Begin
  If N=0 Then Exit;
  Win[N].Open:=True;
  If Not Win[N].Full Then ToggleFull(N);
  BringToFront(N);
  WinRedraw;
 End Else If W='OPENW' Then Begin
  Win[N].Open:=True;
  BringToFront(N);
  If (N=W_OUT) And GfxSaved Then Move(VMem[GFX_BUF],OutBuf^,OUT_BYTES);
  WinRedraw;
 End Else Begin
  If N<>W_CMD Then Win[N].Open:=False;
  WinRedraw;
 End;
End;

Procedure DoGraphics(Const W: String);
Var I: Integer; A1,A2: LongInt;
Begin
 If W='COLOR' Then Begin
  ParseNums(5);
  If ErrCode<>0 Then Exit;
  If GH[1] Then TxtCol:=Clamp(GA[1],0,15);
  If GH[2] Then FilCol:=Clamp(GA[2],0,15);
  If GH[3] Then LinCol:=Clamp(GA[3],0,15);
  If GH[4] Then FilIdx:=Clamp(GA[4],1,24);
  If GH[5] Then FilSty:=Clamp(GA[5],0,4);
 End Else If W='FILL' Then Begin
  ParseNums(3);
  If ErrCode<>0 Then Exit;
  If GN<2 Then Begin Fail(2);Exit;End;
  OFlood(GA[1],GA[2]);
 End Else If W='LINEF' Then Begin
  ParseNums(4);
  If ErrCode<>0 Then Exit;
  If GN<4 Then Begin Fail(2);Exit;End;
  OLine(GA[1],GA[2],GA[3],GA[4],LineInk);
 End Else If (W='CIRCLE') Or (W='PCIRCLE') Then Begin
  ParseNums(5);
  If ErrCode<>0 Then Exit;
  If GN<3 Then Begin Fail(2);Exit;End;
  A1:=0;A2:=3600;
  If GH[4] Then A1:=GA[4];
  If GH[5] Then A2:=GA[5];
  If W='CIRCLE' Then OArc(GA[1],GA[2],GA[3],GA[3],A1,A2)
  Else OPie(GA[1],GA[2],GA[3],GA[3],A1,A2);
 End Else Begin
  ParseNums(6);
  If ErrCode<>0 Then Exit;
  If GN<4 Then Begin Fail(2);Exit;End;
  A1:=0;A2:=3600;
  If GH[5] Then A1:=GA[5];
  If GH[6] Then A2:=GA[6];
  If W='ELLIPSE' Then OArc(GA[1],GA[2],GA[3],GA[4],A1,A2)
  Else OPie(GA[1],GA[2],GA[3],GA[4],A1,A2);
 End;
 If OutLive Then OutFlush(False);
End;

{ ------------------------ declarations de type ------------------------- }

Procedure DoDefType(T: Byte);
Var C1,C2: Char; I: Integer;
Begin
 Repeat
  SkipSp;
  If Not IsAlpha(Cur) Then Begin Fail(2);Exit;End;
  C1:=UpCase(Cur);Inc(P);C2:=C1;
  If Accept('-') Then Begin
   SkipSp;
   If Not IsAlpha(Cur) Then Begin Fail(2);Exit;End;
   C2:=UpCase(Cur);Inc(P);
  End;
  For I:=Ord(C1)-65 To Ord(C2)-65 Do DefTyp[I]:=T;
 Until Not Accept(',');
End;

Procedure DoDim;
Var W: String; Q: PVar; B: TIdx; N: Integer; V: TVal;
Begin
 Repeat
  W:=ReadWord;
  If W='' Then Begin Fail(2);Exit;End;
  Q:=FindVar(W,True);
  Expect('(');
  N:=0;
  Repeat
   Inc(N);
   If N>8 Then Begin Fail(9);Exit;End;
   V:=EvalExpr;B[N]:=ToLong(NumOf(V));
  Until (ErrCode<>0) Or (Not Accept(','));
  Expect(')');
  If ErrCode<>0 Then Exit;
  DimArray(Q,N,B);
 Until (ErrCode<>0) Or (Not Accept(','));
End;

Procedure DoDefFn;
Var W: String; I,F,E: Integer; V: TVal;
Begin
 W:=ReadWord;
 If W='SEG' Then Begin
  SkipSp;
  If AtStmtEnd Then DefSegV:=0
  Else Begin Accept('=');V:=EvalExpr;DefSegV:=ToLong(NumOf(V));End;
  Exit;
 End;
 If Copy(W,1,2)<>'FN' Then Begin Fail(2);Exit;End;
 F:=FindFn(W);
 If F=0 Then Begin
  If FnCnt>=20 Then Begin Fail(7);Exit;End;
  Inc(FnCnt);F:=FnCnt;
 End Else Begin
  If (PCLine<>0) And (FnLn[F]<>PCLine) Then Begin Fail(213);Exit;End;
  FreeStr(FnBody[F]);
 End;
 FnLn[F]:=PCLine;
 FnName[F]:=W;FnNPar[F]:=0;
 SkipSp;
 If Cur='(' Then Begin
  Inc(P);
  Repeat
   SkipSp;
   If FnNPar[F]>=4 Then Begin Fail(2);Exit;End;
   Inc(FnNPar[F]);
   FnPar[F,FnNPar[F]]:=ReadWord;
   If FnPar[F,FnNPar[F]]='' Then Begin Fail(2);Exit;End;
  Until Not Accept(',');
  Expect(')');
 End;
 Expect('=');
 If ErrCode<>0 Then Exit;
 E:=StmtEndPos(Src,P);
 FnBody[F]:=NewStr(Copy(Src,P,E-P));
 P:=E;
End;

Procedure DoSwap;
Var Q1,Q2: PVar; F1,F2: LongInt; A,B: TVal;
Begin
 If Not ParseLValue(Q1,F1) Then Exit;
 Expect(',');
 If Not ParseLValue(Q2,F2) Then Exit;
 If ErrCode<>0 Then Exit;
 A:=GetVarVal(Q1,F1);B:=GetVarVal(Q2,F2);
 SetVarVal(Q1,F1,B);SetVarVal(Q2,F2,A);
End;

Procedure DoMidAssign;
Var Q: PVar; Fl: LongInt; V,X: TVal; S,R: String; St,Ln: LongInt;
Begin
 Expect('(');
 If Not ParseLValue(Q,Fl) Then Exit;
 If Q^.Typ<>2 Then Begin Fail(13);Exit;End;
 Expect(',');
 V:=EvalExpr;St:=ToLong(NumOf(V));
 Ln:=255;
 If Accept(',') Then Begin V:=EvalExpr;Ln:=ToLong(NumOf(V));End;
 Expect(')');Expect('=');
 V:=EvalExpr;R:=StrOf(V);
 If ErrCode<>0 Then Exit;
 X:=GetVarVal(Q,Fl);S:=X.S;
 If (St<1) Or (St>Length(S)) Then Begin Fail(31);Exit;End;
 If Ln>Length(R) Then Ln:=Length(R);
 If St+Ln-1>Length(S) Then Ln:=Length(S)-St+1;
 Move(R[1],S[St],Ln);
 MkStr(X,S);
 SetVarVal(Q,Fl,X);
End;

Procedure DoChain;
Var Merge,KeepAll: Boolean; Nm: String; V: TVal; Ln: LongInt; I,DN: Integer;
    Q: PVar; Saved: Array[1..20] Of TVal; Have: Array[1..20] Of Boolean;
    DA,DB: Array[1..32] Of LongInt;
Begin
 Merge:=AcceptWord('MERGE');
 Nm:=GetFileSpec('BAS');
 If ErrCode<>0 Then Exit;
 Ln:=0;KeepAll:=False;DN:=0;
 While (ErrCode=0) And Accept(',') Do Begin
  SkipSp;
  If AcceptWord('ALL') Then KeepAll:=True
  Else If AcceptWord('DELETE') Then Begin
   ParseLList;
   DN:=LLN;
   For I:=1 To DN Do Begin DA[I]:=LLA[I];DB[I]:=LLB[I];End;
  End Else If Cur<>',' Then Begin V:=EvalExpr;Ln:=ToLong(NumOf(V));End;
 End;
 If ErrCode<>0 Then Exit;
 For I:=1 To ChainKeepN Do Begin
  Q:=FindVar(ChainKeep[I],False);
  Have[I]:=(Q<>Nil) And (Not Q^.IsArr);
  If Have[I] Then Saved[I]:=GetVarVal(Q,0);
 End;
 If Merge Then Begin
  For I:=1 To DN Do DeleteLines(DA[I],DB[I]);
  If Not LoadProgFile(Nm,True) Then Exit;
 End Else Begin
  If Not LoadProgFile(Nm,False) Then Exit;
  If Not KeepAll Then ClearVars;
 End;
 For I:=1 To ChainKeepN Do If Have[I] Then Begin
  Q:=FindVar(ChainKeep[I],True);SetVarVal(Q,0,Saved[I]);
 End;
 FSP:=0;GSP:=0;WSP:=0;
 DatLine:=1;DatScan:=1;DatPos:=0;
 If LCnt=0 Then Begin EndF:=True;Exit;End;
 If Ln>0 Then Begin
  I:=LineIdxExact(Ln);If I=0 Then Begin Fail(8);Exit;End;
 End Else I:=1;
 JumpF:=True;JLine:=I;JPos:=1;
End;

Procedure DoCall;
Var W: String; Q: PVar; V: TVal; A: TArgs; N: Integer; Addr: LongInt;
Begin
 W:=ReadWord;
 Q:=FindVar(W,True);
 V:=GetVarVal(Q,0);
 Addr:=ToLong(NumOf(V));
 ParseArgs(A,N);
 If ErrCode<>0 Then Exit;
 EmuCallAddr(Addr,N,A);
End;

Procedure DoDir;
Var SR: SearchRec; Mask: String; N: Integer;
Begin
 SkipSp;
 If AtStmtEnd Then Mask:={$IFDEF MSWINDOWS}'*.*'{$ELSE}'*'{$ENDIF} Else Mask:=GetFileSpec('');
 If ErrCode<>0 Then Exit;
 If (Length(Mask)>=2) And (Mask[2]=':') Then Delete(Mask,1,2);
 If Mask='' Then Mask:={$IFDEF MSWINDOWS}'*.*'{$ELSE}'*'{$ENDIF};
 N:=0;
 FindFirst(Mask,AnyFile-Directory,SR);
 While DosError=0 Do Begin
  OutStr(SR.Name);
  While OCX Mod 16<>0 Do OutCh(' ');
  If OCX>=OUT_COLS-16 Then OutNewLine;
  Inc(N);
  FindNext(SR);
 End;
 {$IFDEF FPC}FindClose(SR);{$ENDIF}
 If OCX<>0 Then OutNewLine;
 OutLn(IntStr(N)+T3(' file(s)',' fichier(s)',' Datei(en)'));
End;

Procedure DoTraceUnused;
Begin
End;

Function ProgRunnable: Boolean;
Begin
 ProgRunnable:=LCnt>0;
End;

Function ParseRunArgs(Var Ln: Integer): Boolean;
{ [fichier] [,ligne] ; retourne True si un argument a ete donne }
Var Nm: String; N: LongInt;
Begin
 ParseRunArgs:=False;
 Ln:=1;
 SkipSp;
 If (Not AtStmtEnd) And (Cur<>',') Then Begin
  ParseRunArgs:=True;
  If IsDigit(Cur) Then Begin
   Ln:=LineIdxExact(Round(ReadNumber));
   If Ln=0 Then Begin Fail(8);Exit;End;
   Exit;
  End;
  Nm:=GetFileSpec('BAS');
  If ErrCode<>0 Then Exit;
  If Pos('.PRG',Upper(Nm))>0 Then Begin
   If Not EmuRunPRG(Nm) Then Fail(53);
   Ln:=0;
   Exit;
  End;
  If Not LoadProgFile(Nm,False) Then Exit;
 End;
 If Accept(',') Then Begin
  ParseRunArgs:=True;
  SkipSp;
  If Not IsDigit(Cur) Then Begin Fail(203);Exit;End;
  N:=Round(ReadNumber);
  Ln:=LineIdxExact(N);
  If Ln=0 Then Fail(8);
 End;
End;

Procedure FollowReset;
Var I: Integer; Q: PVar;
Begin
 For I:=1 To FollowN Do Begin
  Q:=FindVar(FollowName[I],False);
  If (Q<>Nil) And (Q^.Typ=2) Then FollowVal[I]:='""' Else FollowVal[I]:='0';
 End;
End;

Procedure DoRunCmd;
Var Ln: Integer;
Begin
 ParseRunArgs(Ln);
 If (ErrCode<>0) Or (Ln=0) Then Exit;
 If LCnt=0 Then Exit;
 ClearVars;CloseAllFiles;ResetRunState;
 FnCnt:=0;FollowReset;
 JumpF:=True;JLine:=Ln;JPos:=1;
End;

{ ---------------------------- dispatcheur ------------------------------ }

Var
 FSR : SearchRec;

Procedure ExecOne;
Var W: String; S0: Integer; V: TVal; Q: PVar; Fl: LongInt; Nm: String; N: Integer;
    A,B: LongInt; Ix: TIdx; Ln,Ps: Integer; X: TVal; Mode: Char; Ok: Boolean;
    Hd: Array[0..8] Of Byte; Cnt: Word; Have,Lp: Boolean; Txt: String; S1,I: Integer;
Begin
 SkipSp;
 If Cur='''' Then Begin P:=Length(Src)+1;Exit;End;
 If Cur='?' Then Begin Inc(P);DoPrint(0);Exit;End;
 If IsDigit(Cur) Then Begin
  If ParseTarget(Ln,Ps) Then Begin JumpF:=True;JLine:=Ln;JPos:=Ps;End;
  Exit;
 End;
 S0:=P;
 W:=ReadWord;
 If W='' Then Begin Fail(2);Exit;End;
 { etiquette }
 If (P<=Length(Src)) And (Src[P]=':') And (Not IsReserved(W)) Then Begin
  Inc(P);IfCont:=True;Exit;
 End;
 { affectation simple }
 If Cur=' ' Then Begin SkipSp;End;
 If (Cur='=') And (Not IsReserved(W)) Then Begin
  Q:=FindVar(W,True);
  If Q^.IsArr Then Begin Fail(13);Exit;End;
  Inc(P);
  V:=EvalExpr;
  If ErrCode=0 Then SetVarVal(Q,0,V);
  Exit;
 End;
 If W='PRINT' Then Begin
  SkipSp;
  If Cur='#' Then Begin
   N:=FileArg;If N=0 Then Exit;
   Expect(',');
   DoPrint(N);
  End Else DoPrint(0);
 End
 Else If W='IF' Then DoIf
 Else If W='FOR' Then DoFor
 Else If W='NEXT' Then DoNext
 Else If W='GOTO' Then DoGoto(False)
 Else If W='GOSUB' Then DoGoto(True)
 Else If W='RETURN' Then DoReturn
 Else If W='WHILE' Then DoWhile
 Else If W='WEND' Then Begin
  If WSP=0 Then Fail(205)
  Else If WS[WSP].Ln=0 Then Begin P:=WS[WSP].Ps;IfCont:=True;End
  Else Begin JumpF:=True;JLine:=WS[WSP].Ln;JPos:=WS[WSP].Ps;End;
 End
 Else If W='LET' Then Begin
  If Not ParseLValue(Q,Fl) Then Exit;
  Expect('=');
  V:=EvalExpr;
  If ErrCode=0 Then SetVarVal(Q,Fl,V);
 End
 Else If W='REM' Then P:=Length(Src)+1
 Else If W='DATA' Then SkipToStmtEnd
 Else If W='END' Then Begin
  EndF:=True;CloseAllFiles;
  If PCLine=0 Then Begin BrokenProg:=False;CanCont:=False;StepMode:=False;End;
 End
 Else If W='STOP' Then Begin
  If PCLine=0 Then Begin
   BrokenProg:=False;CanCont:=False;StepMode:=False;
  End Else Begin BreakReq:=True;StopMsg:=True;End;
 End
 Else If W='INPUT' Then DoInput(False)
 Else If W='LINE' Then Begin
  If Not AcceptWord('INPUT') Then Begin Fail(2);Exit;End;
  DoInput(True);
 End
 Else If W='READ' Then DoRead
 Else If W='RESTORE' Then Begin
  DatLine:=1;DatScan:=1;DatPos:=0;
  SkipSp;
  If Not AtStmtEnd Then Begin
   If IsDigit(Cur) Then Begin
    DatLine:=FindLineIdx(Round(ReadNumber));DatScan:=1;
   End Else If ParseTarget(Ln,Ps) Then Begin DatLine:=Ln;DatScan:=1;End;
  End;
 End
 Else If W='DIM' Then DoDim
 Else If W='ON' Then DoOn
 Else If W='DEF' Then DoDefFn
 Else If W='SWAP' Then DoSwap
 Else If (W='CLEARW') Or (W='FULLW') Or (W='OPENW') Or (W='CLOSEW') Then DoWinCmd(W)
 Else If (W='COLOR') Or (W='FILL') Or (W='LINEF') Or (W='CIRCLE') Or (W='PCIRCLE')
  Or (W='ELLIPSE') Or (W='PELLIPSE') Then DoGraphics(W)
 Else If W='GOTOXY' Then Begin
  ParseNums(2);
  If (ErrCode=0) And (GN>=2) Then OutGotoXY(GA[1],GA[2]) Else If ErrCode=0 Then Fail(2);
 End
 Else If W='SOUND' Then Begin
  ParseNums(5);
  If ErrCode<>0 Then Exit;
  If (GN<=2) Then SoundNote(1,0,0,4,0)
  Else Begin
   If Not GH[5] Then GA[5]:=0;
   If Not GH[4] Then GA[4]:=4;
   SoundNote(GA[1],GA[2],GA[3],GA[4],GA[5]);
  End;
 End
 Else If W='WAVE' Then SkipToStmtEnd
 Else If W='DEFINT' Then DoDefType(1)
 Else If W='DEFSNG' Then DoDefType(0)
 Else If W='DEFDBL' Then DoDefType(3)
 Else If W='DEFSTR' Then DoDefType(2)
 Else If W='OPTION' Then Begin
  If Not AcceptWord('BASE') Then Begin Fail(2);Exit;End;
  V:=EvalExpr;N:=ToLong(NumOf(V));
  If (N<>0) And (N<>1) Then Fail(208) Else OptBase:=N;
 End
 Else If W='CLEAR' Then Begin ClearVars;FnCnt:=0;ResetRunState;End
 Else If W='ERASE' Then Begin
  Repeat
   W:=ReadWord;Q:=FindVar(W,False);
   If (Q<>Nil) And Q^.IsArr Then FreeVarData(Q);
  Until Not Accept(',');
 End
 Else If W='RANDOMIZE' Then Begin
  SkipSp;
  If AtStmtEnd Then Begin
   Win[W_OUT].Open:=True;
   OutStr(T3('Random number seed (-32768 to +32767)? ','Valeur initiale (-32768 '#133' +32767) ? ',
             'Startwert (-32768 bis +32767) ? '));
   If ReadOutLine(Txt,255,False) Then RandSeed:=Round(ValStr(Txt))*7919+1;
  End Else Begin V:=EvalExpr;RandSeed:=ToLong(NumOf(V))*7919+1;End;
 End
 Else If W='OPEN' Then DoOpen
 Else If W='CLOSE' Then Begin
  SkipSp;
  If AtStmtEnd Then CloseAllFiles
  Else Repeat
   N:=FileArg;
   If ErrCode=0 Then CloseFile(N);
  Until (ErrCode<>0) Or (Not Accept(','));
 End
 Else If W='WRITE' Then DoWrite
 Else If W='FIELD' Then DoField
 Else If W='LSET' Then DoLset(False)
 Else If W='RSET' Then DoLset(True)
 Else If W='GET' Then DoGetPut(False)
 Else If W='PUT' Then DoGetPut(True)
 Else If W='LPRINT' Then DoPrint(-1)
 Else If W='POKE' Then Begin
  S1:=P;
  ParseNums(2);
  If (ErrCode=0) And (GN>=2) Then PokeMode(GA[1],GA[2],ArgIsDbl(S1));
 End
 Else If W='CALL' Then DoCall
 Else If W='BLOAD' Then Begin
  Nm:=GetFileSpec('');
  Have:=False;A:=0;
  If Accept(',') Then Begin V:=EvalExpr;A:=ToLong(NumOf(V));Have:=True;End;
  If ErrCode<>0 Then Exit;
  Nm:=ResolveFile(Nm);
  If Not FileExists(Nm) Then Begin Fail(53);Exit;End;
  Assign(FT[15].F,Nm);{$I-}Reset(FT[15].F,1);{$I+}
  If IOResult<>0 Then Begin Fail(57);Exit;End;
  BlockRead(FT[15].F,Hd,9,Cnt);
  If (Cnt<9) Or (Hd[0]<>$FD) Then Begin Close(FT[15].F);Fail(111);Exit;End;
  B:=(LongInt(Hd[5]) Shl 24) Or (LongInt(Hd[6]) Shl 16) Or (LongInt(Hd[7]) Shl 8) Or Hd[8];
  If Not Have Then
   A:=(LongInt(Hd[1]) Shl 24) Or (LongInt(Hd[2]) Shl 16) Or (LongInt(Hd[3]) Shl 8) Or Hd[4];
  If (A<0) Or (B<0) Or (A+B>VMEM_SIZE) Then Begin Close(FT[15].F);Fail(111);Exit;End;
  If B>0 Then BlockRead(FT[15].F,VMem[A],B,Cnt);
  Close(FT[15].F);
  If (A<=GFX_BUF) And (A+B>GFX_BUF) Then GfxSaved:=True;
 End
 Else If W='BSAVE' Then Begin
  Nm:=GetFileSpec('');
  A:=0;B:=0;
  If Accept(',') Then Begin V:=EvalExpr;A:=ToLong(NumOf(V));End;
  If Accept(',') Then Begin V:=EvalExpr;B:=ToLong(NumOf(V));End;
  If ErrCode<>0 Then Exit;
  If (A<0) Or (B<0) Or (A+B>VMEM_SIZE) Then Begin Fail(31);Exit;End;
  Assign(FT[15].F,Nm);{$I-}Rewrite(FT[15].F,1);{$I+}
  If IOResult<>0 Then Begin Fail(57);Exit;End;
  Hd[0]:=$FD;
  Hd[1]:=(A Shr 24) And 255;Hd[2]:=(A Shr 16) And 255;Hd[3]:=(A Shr 8) And 255;Hd[4]:=A And 255;
  Hd[5]:=(B Shr 24) And 255;Hd[6]:=(B Shr 16) And 255;Hd[7]:=(B Shr 8) And 255;Hd[8]:=B And 255;
  BlockWrite(FT[15].F,Hd,9);
  If B>0 Then BlockWrite(FT[15].F,VMem[A],B);
  Close(FT[15].F);
 End
 Else If W='CHAIN' Then DoChain
 Else If W='COMMON' Then Begin
  Repeat
   W:=ReadWord;
   If (W<>'') And (ChainKeepN<20) Then Begin Inc(ChainKeepN);ChainKeep[ChainKeepN]:=W;End;
  Until Not Accept(',');
 End
 Else If W='RESUME' Then DoResume
 Else If W='ERROR' Then Begin
  V:=EvalExpr;N:=ToLong(NumOf(V));
  If ErrCode=0 Then Begin
   If (N<1) Or (N>255) Then Fail(31) Else Fail(N);
  End;
 End
 Else If (W='KILL') Or (W='ERA') Then Begin
  Nm:=GetFileSpec('');
  If ErrCode<>0 Then Exit;
  If (Length(Nm)>=2) And (Nm[2]=':') Then Delete(Nm,1,2);
  Nm:=ResolveFile(Nm);
  For I:=1 To 15 Do
   If FT[I].Used And (Upper(FT[I].Name)=Upper(Nm)) Then Begin Fail(55);Exit;End;
  If (Pos('*',Nm)>0) Or (Pos('?',Nm)>0) Then Begin
   FindFirst(Nm,AnyFile-Directory,FSR);
   Cnt:=0;
   While DosError=0 Do Begin
    Assign(FT[15].F,FSR.Name);{$I-}Erase(FT[15].F);{$I+}
    If IOResult=0 Then Inc(Cnt);
    FindNext(FSR);
   End;
   {$IFDEF FPC}FindClose(FSR);{$ENDIF}
   If Cnt=0 Then Fail(53);
  End Else Begin
   If Not FileExists(Nm) Then Begin Fail(53);Exit;End;
   Assign(FT[15].F,Nm);{$I-}Erase(FT[15].F);{$I+}
   If IOResult<>0 Then Fail(57);
  End;
 End
 Else If W='NAME' Then Begin
  Nm:=GetFileSpec('');
  If Not AcceptWord('AS') Then Begin Fail(2);Exit;End;
  If ErrCode<>0 Then Exit;
  V:=EvalExpr;
  If ErrCode<>0 Then Exit;
  Nm:=ResolveFile(Nm);
  If Not FileExists(Nm) Then Begin Fail(53);Exit;End;
  Assign(FT[15].F,Nm);{$I-}Rename(FT[15].F,StrOf(V));{$I+}
  If IOResult<>0 Then Fail(57);
 End
 Else If W='WIDTH' Then Begin
  Lp:=AcceptWord('LPRINT');
  V:=EvalExpr;N:=ToLong(NumOf(V));
  If ErrCode=0 Then Begin
   If (N<14) Or (N>255) Then Fail(31)
   Else If Lp Then PrnWidth:=N Else OutWidth:=N;
  End;
 End
 Else If W='FOLLOW' Then Begin
  Repeat
   W:=ReadWord;
   If W='' Then Begin Fail(104);Exit;End;
   Q:=FindVar(W,True);
   If FollowN<8 Then Begin
    Inc(FollowN);FollowName[FollowN]:=Q^.Name;FollowVal[FollowN]:=FollowRepr(Q);
   End;
  Until (ErrCode<>0) Or (Not Accept(','));
 End
 Else If W='UNFOLLOW' Then Begin
  SkipSp;
  If AtStmtEnd Then FollowN:=0
  Else Repeat
   W:=ReadWord;
   Q:=FindVar(W,False);
   If Q<>Nil Then
    For I:=FollowN DownTo 1 Do If FollowName[I]=Q^.Name Then Begin
     FollowName[I]:=FollowName[FollowN];FollowVal[I]:=FollowVal[FollowN];Dec(FollowN);
    End;
  Until (ErrCode<>0) Or (Not Accept(','));
 End
 Else If W='BREAK' Then DoSetCmd(BreakSet,BreakOn,True)
 Else If W='UNBREAK' Then DoSetCmd(BreakSet,BreakOn,False)
 Else If (W='GEMSYS') Or (W='VDISYS') Then Begin
  Expect('(');V:=EvalExpr;Expect(')');
  If ErrCode=0 Then Begin
   If W='VDISYS' Then BasicVdisys Else BasicGemsys(ToLong(NumOf(V)));
  End;
 End
 Else If W='OUT' Then Begin
  ParseNums(2);
  If (ErrCode=0) And (GN>=2) Then Begin
   If GA[1]=0 Then PrStr(-1,Chr(GA[2] And 255))
   Else If GA[1]=2 Then OutCh(Chr(GA[2] And 255));
  End;
 End
 Else If (W='WAIT') Or (W='SYSDBG') Or (W='SEG') Then SkipToStmtEnd
 Else If W='RESET' Then Begin
  Move(OutBuf^,VMem[GFX_BUF],OUT_BYTES);
  GfxSaved:=True;
 End
 Else If W='TRON' Then DoSetCmd(TronSet,TronOn,True)
 Else If W='TRACE' Then DoSetCmd(TraceSet,TraceOn,True)
 Else If W='TROFF' Then DoSetCmd(TronSet,TronOn,False)
 Else If W='UNTRACE' Then DoSetCmd(TraceSet,TraceOn,False)
 Else If W='ELSE' Then P:=Length(Src)+1
 { --------- commandes (mode direct) --------- }
 Else If W='RUN' Then DoRunCmd
 Else If (W='LIST') Or (W='LLIST') Then DoList(W='LLIST')
 Else If (W='QUIT') Or (W='SYSTEM') Then QuitReq:=True
 Else If (W='EDIT') Or (W='ED') Then Begin
  EditLineReq:=0;
  SkipSp;
  If IsDigit(Cur) Then EditLineReq:=Round(ReadNumber);
  EditReq:=True;
 End
 Else If W='NEW' Then Begin
  If PCLine<>0 Then Begin Fail(202);Exit;End;
  NewProgram;ClearVars;CloseAllFiles;ResetRunState;FnCnt:=0;
  LstClear;LstName:='';BrokenProg:=False;CanCont:=False;
  SkipSp;
  If Not AtStmtEnd Then Begin Nm:=GetFileSpec('BAS');If ErrCode=0 Then SetProgTitle(Nm);End;
  UIDirty:=True;
 End
 Else If (W='LOAD') Or (W='OLD') Then Begin
  If PCLine<>0 Then Begin Fail(202);Exit;End;
  Nm:=GetFileSpec('BAS');
  If ErrCode=0 Then Ok:=LoadProgFile(Nm,False);
  ResetRunState;FnCnt:=0;
 End
 Else If W='MERGE' Then Begin
  If PCLine<>0 Then Begin Fail(202);Exit;End;
  Nm:=GetFileSpec('BAS');
  If ErrCode=0 Then Ok:=LoadProgFile(Nm,True);
 End
 Else If (W='SAVE') Or (W='REPLACE') Then Begin
  If PCLine<>0 Then Begin Fail(202);Exit;End;
  SkipSp;
  If AtStmtEnd Or (Cur=',') Then Nm:=ProgName Else Nm:=GetFileSpec('BAS');
  If (ErrCode=0) And (Nm='') Then Fail(64);
  LLN:=0;
  If (ErrCode=0) And Accept(',') Then ParseLList;
  If ErrCode=0 Then Ok:=SaveProgFile(Nm,W='REPLACE');
  LLN:=0;
 End
 Else If W='DELETE' Then Begin
  If PCLine<>0 Then Begin Fail(202);Exit;End;
  ParseLList;
  If (ErrCode=0) Then Begin
   If LLN=0 Then Fail(2)
   Else For I:=1 To LLN Do DeleteLines(LLA[I],LLB[I]);
   UIDirty:=True;
  End;
 End
 Else If W='RENUM' Then Begin
  If PCLine<>0 Then Begin Fail(202);Exit;End;
  DoRenum;UIDirty:=True;
 End
 Else If W='AUTO' Then Begin
  AutoNum:=10;
  SkipSp;
  If (Not AtStmtEnd) And (Cur<>',') Then Begin V:=EvalExpr;AutoNum:=ToLong(NumOf(V));End;
  If Accept(',') Then Begin V:=EvalExpr;AutoStep:=ToLong(NumOf(V));End;
  If (ErrCode=0) And ((AutoStep<1) Or (AutoNum<0) Or (AutoNum>65535)) Then Fail(31);
  AutoOn:=True;
 End
 Else If W='CONT' Then Begin
  If Not CanCont Then Fail(17)
  Else Begin JumpF:=True;JLine:=ResLine;JPos:=ResPos;End;
 End
 Else If W='STEP' Then Begin
  StepMode:=True;
  Have:=ParseRunArgs(Ln);
  If ErrCode<>0 Then Exit;
  If CanCont And (Not Have) Then Begin JumpF:=True;JLine:=ResLine;JPos:=ResPos;End
  Else If LCnt>0 Then Begin
   ClearVars;CloseAllFiles;ResetRunState;FnCnt:=0;FollowReset;
   JumpF:=True;JLine:=Ln;JPos:=1;
  End;
 End
 Else If (W='DIR') Or (W='FILES') Then DoDir
 Else Begin
  { affectation a un element de tableau / MID$ }
  If (W='MID$') And (Cur='(') Then Begin DoMidAssign;Exit;End;
  If (Not IsReserved(W)) And (Cur='(') Then Begin
   P:=S0;
   If Not ParseLValue(Q,Fl) Then Exit;
   Expect('=');
   V:=EvalExpr;
   If ErrCode=0 Then SetVarVal(Q,Fl,V);
   Exit;
  End;
  Fail(2);
 End;
End;

Procedure PollKeys;
Var K: Integer;
Begin
 While KeyPressed Do Begin
  K:=Ord(ReadKey);
  If K=0 Then KeyQAdd(256+Ord(ReadKey))
  Else If K=K_CTRLC Then Begin BreakReq:=True;LastRunMsg:='STOP';End
  Else If K=K_CTRLG Then BreakReq:=True
  Else KeyQAdd(K);
 End;
End;

Procedure ExecStmts;
Var Done: Boolean;
Begin
 Done:=False;
 Repeat
  SkipSp;
  While (P<=Length(Src)) And (Src[P]=':') Do Begin Inc(P);SkipSp;End;
  If P>Length(Src) Then Done:=True
  Else Begin
   StmtStart:=P;
   ExecOne;
   Inc(StmtCount);
   If (StmtCount And 15)=0 Then Begin PollKeys;RunPoll;End;
   If (ErrCode<>0) Or JumpF Or EndF Or BreakReq Or QuitReq Then Done:=True
   Else If IfCont Then IfCont:=False
   Else Begin
    SkipSp;
    If P>Length(Src) Then Done:=True
    Else If Cur=':' Then Inc(P)
    Else If Cur='''' Then Done:=True
    Else If PeekWord='ELSE' Then Begin P:=Length(Src)+1;Done:=True;End
    Else Begin
     If IsDigit(Cur) Or IsAlpha(Cur) Or (Cur='"') Or (Cur='.') Then Fail(209) Else Fail(2);
     Done:=True;
    End;
   End;
  End;
 Until Done;
End;

{ ---------------------- affichage des erreurs -------------------------- }

Procedure ShowRunError(Ln: Integer);
Var M,S: String; I,C: Integer;
Begin
 M:=ErrText(ErrCode);
 If Ln>0 Then M:=M+T3(' at line ',' '#133' la ligne ',' in Zeile ')+IntStr(LNum[Ln]);
 ConAdd(M);
 If (ErrCode=2) Or (ErrCode=22) Or (ErrCode=104) Or ((ErrCode>=206) And (ErrCode<=209)) Then Begin
  If Ln>0 Then S:=LineStr(Ln)
  Else S:=Src;
  If Ln>0 Then ConAdd(S) Else ConAdd(S);
  C:=ErrPosP-1;
  If C<1 Then C:=1;
  If Ln>0 Then C:=C+Length(IntStr(LNum[Ln]))+1;
  M:='';
  For I:=2 To C Do M:=M+' ';
  ConAdd(M+'^');
 End;
 UIDirty:=True;
End;

{ ------------------------- boucle d'execution -------------------------- }

Var
 TronIdx : Integer;

Function FollowRepr(Q: PVar): String;
Var V: TVal;
Begin
 V:=GetVarVal(Q,0);
 If V.IsStr Then FollowRepr:='"'+V.S+'"' Else FollowRepr:=NumStr(V.N);
End;

Procedure FollowCheck(Ln: Integer);
Var I: Integer; Q: PVar; R,D: String;
Begin
 If (Ln<1) Or (Ln>LCnt) Then Exit;
 For I:=1 To FollowN Do Begin
  Q:=FindVar(FollowName[I],False);
  If (Q<>Nil) And (Not Q^.IsArr) Then Begin
   R:=FollowRepr(Q);
   If R<>FollowVal[I] Then Begin
    FollowVal[I]:=R;
    D:=Q^.Name;
    If Not (D[Length(D)] In ['$','%','!']) Then Case Q^.Typ Of
     0: D:=D+'!';
     1: D:=D+'%';
     2: D:=D+'$';
    End;
    ConAdd(D+' = '+R+T3(' at line ',' ligne ',' Zeile ')+IntStr(LNum[Ln]));
    UIDirty:=True;
   End;
  End;
 End;
End;

Procedure LineStartHook(Ln: Integer);
Var N: LongInt;
Begin
 If (Ln>=1) And (Ln<=LCnt) Then Begin
  If FollowN>0 Then FollowCheck(LastLn);
  LastLn:=Ln;
  N:=LNum[Ln];
  If TronOn And LSHas(TronSet,N) Then Begin
   ConAdd('['+IntStr(N)+']');UIDirty:=True;
  End;
  If TraceOn And LSHas(TraceSet,N) Then Begin
   ConAdd('T '+LineStr(Ln));UIDirty:=True;
  End;
  If StepMode Then StepWait(Ln,'S')
  Else If BreakOn And LSHas(BreakSet,N) Then StepWait(Ln,'B');
 End;
End;

Procedure RunLoop;
Var NextLn: Integer;
Begin
 Repeat
  If (PCLine<1) Or (PCLine>LCnt) Then EndF:=True
  Else Begin
   If PCPos=1 Then LineStartHook(PCLine);
   If BreakReq Then Begin ResLine:=PCLine;ResPos:=PCPos;End
   Else If Not QuitReq Then Begin
    Src:=LTxt[PCLine]^;P:=PCPos;
    NextLn:=PCLine+1;
    JumpF:=False;
    ExecStmts;
    If ErrCode<>0 Then Begin
     ErrNum:=ErrCode;ErrLNum:=LNum[PCLine];
     If (OnErrLine>0) And (Not InErrH) Then Begin
      InErrH:=True;ErrStmtLn:=PCLine;ErrStmtPos:=StmtStart;
      ErrCode:=0;
      PCLine:=OnErrLine;PCPos:=OnErrPos;
     End Else Begin
      ShowRunError(PCLine);
      EndF:=True;
     End;
    End Else If JumpF Then Begin
     JumpF:=False;
     PCLine:=JLine;PCPos:=JPos;
     If PCLine=0 Then EndF:=True;
    End Else If BreakReq Then Begin
     ResLine:=PCLine;ResPos:=P;
    End Else Begin
     PCLine:=NextLn;PCPos:=1;
    End;
   End;
  End;
 Until EndF Or BreakReq Or QuitReq;
End;

Procedure RunFrom(Ln,Ps: Integer);
Var Msg: String;
Begin
 If LabDirty Then BuildLabels;
 Running:=True;RunningProg:=True;BrokenProg:=False;CanCont:=False;
 EndF:=False;BreakReq:=False;ErrCode:=0;JumpF:=False;LastRunMsg:='';
 PCLine:=Ln;PCPos:=Ps;
 HideMouse;
 Inc(MouseLock);
 Win[W_OUT].Open:=True;
 OutUpdateLive;
 StmtCount:=0;
 RunLoop;
 Dec(MouseLock);
 NoSound;
 OutFlush(True);
 Running:=False;RunningProg:=False;
 If BreakReq Then Begin
  If LastRunMsg='STOP' Then Begin
   CanCont:=False;
  End Else Begin
   BrokenProg:=True;CanCont:=True;
   If StopMsg Then
    ConAdd(T3('Stop at line ','Stop '#133' la ligne ','Stop in Zeile ')+IntStr(LNum[PCLine]))
   Else
    ConAdd(T3('-- Break -- at line ','-- Break -- '#133' la ligne ','-- Break -- in Zeile ')+
           IntStr(LNum[PCLine]));
  End;
  StopMsg:=False;
  BreakReq:=False;
 End;
 StepMode:=StepMode And BrokenProg;
 If EndF Then StepMode:=False;
 If EditMode Then BringToFront(W_EDIT) Else BringToFront(W_CMD);
 UIDirty:=True;
 DrawDesktop;
End;

Procedure ExecDirect(Const S: String);
Var T: String; I: Integer; N: LongInt;
Begin
 T:=TrimStr(S);
 If T='' Then Exit;
 ErrCode:=0;
 If IsDigit(T[1]) Then Begin
  I:=1;N:=0;
  While (I<=Length(T)) And IsDigit(T[I]) Do Begin
   If N<70000 Then N:=N*10+Ord(T[I])-48;
   Inc(I);
  End;
  If N>65529 Then Begin Src:=T;P:=1;Fail(2);ShowRunError(0);Exit;End;
  SetProgLine(N,Copy(T,I,255));
  UIDirty:=True;
  Exit;
 End;
 Src:=T;P:=1;
 PCLine:=0;PCPos:=1;JumpF:=False;EndF:=False;BreakReq:=False;LastRunMsg:='';
 StmtStart:=1;
 HideMouse;Inc(MouseLock);
 ExecStmts;
 Dec(MouseLock);ShowMouse;
 If ErrCode<>0 Then Begin ShowRunError(0);ErrCode:=0;StepMode:=False;End
 Else If JumpF Then Begin
  JumpF:=False;
  If JLine>0 Then RunFrom(JLine,JPos);
 End;
 UIDirty:=True;
End;

{ ====================================================================== }
{          EMULATEUR ATARI ST INTEGRE : MOTOROLA 68000 + TOS             }
{ ====================================================================== }

{$IFDEF FPC}

Const
 M_BASEPAGE = $20000;
 M_TOP      = $E0000;
 M_SCREEN   = $F8000;
 M_STUB     = $400;
 M_ENV      = $2F000;
 M_LINEA    = $1F000;
 FLG_X = 16;
 FLG_N = 8;
 FLG_Z = 4;
 FLG_V = 2;
 FLG_C = 1;

Type
 TEA = Record
  Kind : Byte;      { 0 Dn, 1 An, 2 memoire, 3 immediat }
  N    : LongInt;
 End;

Var
 RD,RA   : Array[0..7] Of LongInt;
 RPC     : LongInt;
 RSR     : Word;
 RUSP    : LongInt;
 EmuHalt : Boolean;
 EmuCode : Integer;
 EmuMsg  : String;
 EmuBrk  : Boolean;
 EmuHeap : LongInt;
 EmuDta  : LongInt;
 EmuOpc  : Word;
 EmuOpPC : LongInt;
 EmuSteps: LongInt;
 EmuSuper: Boolean;
 EmuSeed : LongInt;
 EmuTrapDepth : Integer;
 ScrShadow : Array[0..31999] Of Byte;
 VtState : Integer;
 VtRow   : Integer;
 VtRev   : Boolean;
 EmuFile : Array[6..25] Of File;
 EmuFUsed: Array[6..25] Of Boolean;
 EmuSF   : SearchRec;
 EmuSFOk : Boolean;
 VdiTxtCol : Integer;
 EmuScreen,EmuActive : Boolean;
 AesNext : Integer;

{ -------------------------- acces memoire ------------------------------ }

Function RB(A: LongInt): Byte;
Begin
 A:=A And $FFFFFF;
 If A<VMEM_SIZE Then RB:=VMem[A] Else RB:=0;
End;

Function RW(A: LongInt): Word;
Begin
 RW:=(Word(RB(A)) Shl 8) Or RB(A+1);
End;

Function RL(A: LongInt): LongInt;
Begin
 RL:=LongInt((Cardinal(RW(A)) Shl 16) Or RW(A+2));
End;

Procedure WB(A: LongInt; V: Byte);
Begin
 A:=A And $FFFFFF;
 If A<VMEM_SIZE Then VMem[A]:=V;
End;

Procedure WW(A: LongInt; V: Word);
Begin
 WB(A,V Shr 8);WB(A+1,V And $FF);
End;

Procedure WL(A: LongInt; V: LongInt);
Begin
 WW(A,Word(Cardinal(V) Shr 16));WW(A+2,Word(V And $FFFF));
End;

Function SzMask(Sz: Integer): Int64;
Begin
 Case Sz Of
  1: SzMask:=$FF;
  2: SzMask:=$FFFF;
 Else SzMask:=$FFFFFFFF;
 End;
End;

Function SzMsb(Sz: Integer): Int64;
Begin
 Case Sz Of
  1: SzMsb:=$80;
  2: SzMsb:=$8000;
 Else SzMsb:=$80000000;
 End;
End;

Function SxV(V: LongInt; Sz: Integer): LongInt;
Begin
 Case Sz Of
  1: SxV:=ShortInt(V And $FF);
  2: SxV:=SmallInt(V And $FFFF);
 Else SxV:=V;
 End;
End;

Function MskV(V: LongInt; Sz: Integer): LongInt;
Begin
 Case Sz Of
  1: MskV:=V And $FF;
  2: MskV:=V And $FFFF;
 Else MskV:=V;
 End;
End;

Procedure SetF(M: Word; C: Boolean);
Begin
 If C Then RSR:=RSR Or M Else RSR:=RSR And (Not M);
End;

Function GetF(M: Word): Boolean;
Begin
 GetF:=(RSR And M)<>0;
End;

Function Fetch16: LongInt;
Begin
 Fetch16:=SmallInt(RW(RPC));
 RPC:=RPC+2;
End;

Function Fetch32: LongInt;
Begin
 Fetch32:=RL(RPC);
 RPC:=RPC+4;
End;

Procedure Push32(V: LongInt);
Begin
 RA[7]:=RA[7]-4;WL(RA[7],V);
End;

Procedure Push16(V: Word);
Begin
 RA[7]:=RA[7]-2;WW(RA[7],V);
End;

Function Pop32: LongInt;
Begin
 Pop32:=RL(RA[7]);RA[7]:=RA[7]+4;
End;

Function Pop16: Word;
Begin
 Pop16:=RW(RA[7]);RA[7]:=RA[7]+2;
End;

{ ------------------------- adresses effectives -------------------------- }

Procedure GetEA(Mode,Reg,Sz: Integer; Var E: TEA);
Var Ext: LongInt; Ix: LongInt; Base: LongInt; Inc2: Integer;
 Function IndexVal(B: LongInt; X: LongInt): LongInt;
 Var R: LongInt; D8: LongInt;
 Begin
  If (X And $8000)<>0 Then R:=RA[(X Shr 12) And 7] Else R:=RD[(X Shr 12) And 7];
  If (X And $800)=0 Then R:=SmallInt(R And $FFFF);
  D8:=ShortInt(X And $FF);
  IndexVal:=B+R+D8;
 End;
Begin
 E.N:=0;E.Kind:=2;
 Case Mode Of
  0: Begin E.Kind:=0;E.N:=Reg;End;
  1: Begin E.Kind:=1;E.N:=Reg;End;
  2: E.N:=RA[Reg];
  3: Begin
      E.N:=RA[Reg];
      Inc2:=Sz;
      If (Reg=7) And (Sz=1) Then Inc2:=2;
      RA[Reg]:=RA[Reg]+Inc2;
     End;
  4: Begin
      Inc2:=Sz;
      If (Reg=7) And (Sz=1) Then Inc2:=2;
      RA[Reg]:=RA[Reg]-Inc2;
      E.N:=RA[Reg];
     End;
  5: Begin Ext:=Fetch16;E.N:=RA[Reg]+Ext;End;
  6: Begin Ext:=Fetch16;E.N:=IndexVal(RA[Reg],Ext);End;
  7: Case Reg Of
      0: Begin E.N:=Fetch16;End;
      1: Begin E.N:=Fetch32;End;
      2: Begin Base:=RPC;Ext:=Fetch16;E.N:=Base+Ext;End;
      3: Begin Base:=RPC;Ext:=Fetch16;E.N:=IndexVal(Base,Ext);End;
      4: Begin
          E.Kind:=3;
          If Sz=4 Then E.N:=Fetch32
          Else Begin E.N:=Fetch16;If Sz=1 Then E.N:=E.N And $FF;End;
         End;
     Else EmuHalt:=True;
     End;
 End;
End;

Function LdEA(Var E: TEA; Sz: Integer): LongInt;
Begin
 Case E.Kind Of
  0: LdEA:=MskV(RD[E.N],Sz);
  1: LdEA:=MskV(RA[E.N],Sz);
  2: Case Sz Of
      1: LdEA:=RB(E.N);
      2: LdEA:=RW(E.N);
     Else LdEA:=RL(E.N);
     End;
 Else LdEA:=MskV(E.N,Sz);
 End;
End;

Procedure StEA(Var E: TEA; Sz: Integer; V: LongInt);
Begin
 Case E.Kind Of
  0: Case Sz Of
      1: RD[E.N]:=(RD[E.N] And LongInt($FFFFFF00)) Or (V And $FF);
      2: RD[E.N]:=(RD[E.N] And LongInt($FFFF0000)) Or (V And $FFFF);
     Else RD[E.N]:=V;
     End;
  1: RA[E.N]:=V;
  2: Case Sz Of
      1: WB(E.N,V And $FF);
      2: WW(E.N,V And $FFFF);
     Else WL(E.N,V);
     End;
 End;
End;

{ ------------------------------- ALU ----------------------------------- }

Procedure FlagsNZ(R: LongInt; Sz: Integer);
Begin
 SetF(FLG_N,(Int64(R) And SzMsb(Sz))<>0);
 SetF(FLG_Z,(Int64(R) And SzMask(Sz))=0);
 SetF(FLG_V,False);SetF(FLG_C,False);
End;

Function AluAdd(S,Dd: LongInt; Sz: Integer; Cin: Integer; Chain,SetX: Boolean): LongInt;
Var M,Mb,Ss,Dm,R,Res: Int64;
Begin
 M:=SzMask(Sz);Mb:=SzMsb(Sz);
 Ss:=Int64(S) And M;Dm:=Int64(Dd) And M;
 R:=Ss+Dm+Cin;Res:=R And M;
 SetF(FLG_C,R>M);
 If SetX Then SetF(FLG_X,R>M);
 SetF(FLG_N,(Res And Mb)<>0);
 If Chain Then Begin If Res<>0 Then SetF(FLG_Z,False);End Else SetF(FLG_Z,Res=0);
 SetF(FLG_V,((Not (Ss Xor Dm)) And (Dm Xor Res) And Mb)<>0);
 AluAdd:=LongInt(Res And $FFFFFFFF);
End;

Function AluSub(S,Dd: LongInt; Sz: Integer; Cin: Integer; Chain,SetX: Boolean): LongInt;
Var M,Mb,Ss,Dm,R,Res: Int64;
Begin
 M:=SzMask(Sz);Mb:=SzMsb(Sz);
 Ss:=Int64(S) And M;Dm:=Int64(Dd) And M;
 R:=Dm-Ss-Cin;Res:=R And M;
 SetF(FLG_C,R<0);
 If SetX Then SetF(FLG_X,R<0);
 SetF(FLG_N,(Res And Mb)<>0);
 If Chain Then Begin If Res<>0 Then SetF(FLG_Z,False);End Else SetF(FLG_Z,Res=0);
 SetF(FLG_V,((Ss Xor Dm) And (Dm Xor Res) And Mb)<>0);
 AluSub:=LongInt(Res And $FFFFFFFF);
End;

Function CondOk(CC: Integer): Boolean;
Var N,Z,V,C: Boolean;
Begin
 N:=GetF(FLG_N);Z:=GetF(FLG_Z);V:=GetF(FLG_V);C:=GetF(FLG_C);
 Case CC Of
  0: CondOk:=True;
  1: CondOk:=False;
  2: CondOk:=(Not C) And (Not Z);
  3: CondOk:=C Or Z;
  4: CondOk:=Not C;
  5: CondOk:=C;
  6: CondOk:=Not Z;
  7: CondOk:=Z;
  8: CondOk:=Not V;
  9: CondOk:=V;
  10: CondOk:=Not N;
  11: CondOk:=N;
  12: CondOk:=N=V;
  13: CondOk:=N<>V;
  14: CondOk:=(Not Z) And (N=V);
 Else CondOk:=Z Or (N<>V);
 End;
End;

Procedure SetSR(V: Word);
Var Was: Boolean;
Begin
 Was:=(RSR And $2000)<>0;
 RSR:=V And $F71F;
 If Was And ((RSR And $2000)=0) Then Begin RUSP:=RUSP;End;
End;

{ ------------------------------ ecran --------------------------------- }

Procedure OutToMem;
{ recopie le tampon OUTPUT dans la memoire ecran de l'ST }
Var I: Integer;
Begin
 For I:=0 To 31999 Do Begin
  VMem[M_SCREEN+I]:=OutBuf^[I];
  ScrShadow[I]:=OutBuf^[I];
 End;
End;

Procedure MemToOut;
Var I: Integer; Chg: Boolean;
Begin
 Chg:=False;
 For I:=0 To 31999 Do
  If VMem[M_SCREEN+I]<>ScrShadow[I] Then Begin
   ScrShadow[I]:=VMem[M_SCREEN+I];
   OutBuf^[I]:=ScrShadow[I];
   Chg:=True;
  End;
 If Chg Then Begin OutPending:=True;OutFlush(True);End;
End;

{ Sortie texte VT52 }
Procedure VtOut(Ch: Char);
Var C: Integer;
Begin
 Case VtState Of
  1: Begin
      VtState:=0;
      Case Ch Of
       'E': Begin OutClear;End;
       'H': OutGotoXY(0,0);
       'A': If OCY>0 Then Dec(OCY);
       'B': If OCY<OUT_ROWS-1 Then Inc(OCY);
       'C': If OCX<OUT_COLS-1 Then Inc(OCX);
       'D': If OCX>0 Then Dec(OCX);
       'J': Begin
             For C:=OCX To OUT_COLS-1 Do OGlyph(C,OCY,' ');
             For C:=OCY+1 To OUT_ROWS-1 Do Begin
              FillChar(OutBuf^[LongInt(C)*16*OUT_RB],16*OUT_RB,0);
             End;
             If OutLive Then OutPending:=True;
            End;
       'K': For C:=OCX To OUT_COLS-1 Do OGlyph(C,OCY,' ');
       'L': ;
       'M': ;
       'Y': VtState:=2;
       'p': VtRev:=True;
       'q': VtRev:=False;
       'e','f','v','w': ;
       'b','c': VtState:=5;
      End;
     End;
  2: Begin VtRow:=Ord(Ch)-32;VtState:=3;End;
  3: Begin OutGotoXY(Ord(Ch)-32,VtRow);VtState:=0;End;
  5: VtState:=0;
 Else
  If Ch=#27 Then VtState:=1
  Else OutCh(Ch);
 End;
End;

Procedure VtStr(Const S: String);
Var I: Integer;
Begin
 For I:=1 To Length(S) Do VtOut(S[I]);
End;

{ ------------------------------ GEMDOS --------------------------------- }

Function EmuStr(A: LongInt): String;
Var S: String; C: Byte;
Begin
 S:='';
 C:=RB(A);
 While (C<>0) And (Length(S)<250) Do Begin S:=S+Chr(C);Inc(A);C:=RB(A);End;
 EmuStr:=S;
End;

Procedure PutStr(A: LongInt; Const S: String);
Var I: Integer;
Begin
 For I:=1 To Length(S) Do WB(A+I-1,Ord(S[I]));
 WB(A+Length(S),0);
End;

Function EmuKey: LongInt;
Var K: Integer;
Begin
 K:=GetKeyWait;
 If BreakReq Then Begin EmuBrk:=True;EmuKey:=0;Exit;End;
 If K>=256 Then EmuKey:=(LongInt(K-256) Shl 16)
 Else EmuKey:=(LongInt(K) Shl 16) Or K;
 If K=K_ENTER Then EmuKey:=($1C Shl 16) Or 13;
End;

Function HandleFile: Integer;
Var I: Integer;
Begin
 HandleFile:=-1;
 For I:=6 To 25 Do If Not EmuFUsed[I] Then Begin HandleFile:=I;Exit;End;
End;

Procedure FillDta(Const SR: SearchRec);
Var D: LongInt; Nm: String;
Begin
 D:=EmuDta;
 FillChar(VMem[D],44,0);
 WB(D+21,SR.Attr And $FF);
 WL(D+26,SR.Size);
 Nm:=Upper(SR.Name);
 PutStr(D+30,Copy(Nm,1,13));
End;

Procedure GemDos;
Var Fn: Word; SP: LongInt; H,R: Integer; S: String; A,Cnt,Len: LongInt; Buf: Pointer;
    Mode: Integer; Done: Longint; Pos2: LongInt;
Begin
 SP:=RA[7];
 If (RSR And $2000)=0 Then SP:=RA[7] Else SP:=RA[7];
 Fn:=RW(SP);
 Case Fn Of
  0: Begin EmuHalt:=True;EmuCode:=0;End;
  1: RD[0]:=EmuKey;
  2: Begin VtOut(Chr(RW(SP+2) And $FF));OutToMem;End;
  3,4,5: RD[0]:=0;
  6: If RW(SP+2)=$FF Then Begin
      If KeyPressed Or (KeyQ<>'') Then RD[0]:=EmuKey Else RD[0]:=0;
     End Else Begin VtOut(Chr(RW(SP+2) And $FF));RD[0]:=0;End;
  7,8: RD[0]:=EmuKey;
  9: Begin
      S:=EmuStr(RL(SP+2));
      VtStr(S);OutToMem;
      RD[0]:=0;
     End;
  10: Begin
       A:=RL(SP+2);
       If ReadOutLine(S,Min2(RB(A),250),False) Then Begin
        WB(A+1,Length(S));
        PutStr(A+2,S);
        RD[0]:=Length(S);
       End Else EmuBrk:=True;
      End;
  11: If KeyPressed Or (KeyQ<>'') Then RD[0]:=-1 Else RD[0]:=0;
  14: RD[0]:=2;
  25: RD[0]:=2;
  32: Begin
       { Super : bascule en superviseur }
       A:=RL(SP+2);
       If A=1 Then Begin If EmuSuper Then RD[0]:=-1 Else RD[0]:=0;End
       Else Begin EmuSuper:=Not EmuSuper;RD[0]:=RA[7];End;
      End;
  26: Begin EmuDta:=RL(SP+2);End;
  47: RD[0]:=EmuDta;
  42: RD[0]:=(2026-1980) Shl 9 Or (11 Shl 5) Or 2;
  44: RD[0]:=(12 Shl 11);
  72: Begin
       Cnt:=RL(SP+2);
       If Cnt=-1 Then RD[0]:=M_TOP-$10000-EmuHeap
       Else Begin
        Cnt:=(Cnt+3) And (Not 3);
        If EmuHeap+Cnt>M_TOP-$10000 Then RD[0]:=0
        Else Begin RD[0]:=EmuHeap;FillChar(VMem[EmuHeap],Cnt,0);EmuHeap:=EmuHeap+Cnt;End;
       End;
      End;
  73: RD[0]:=0;
  74: RD[0]:=0;
  71: Begin PutStr(RL(SP+4),'\');RD[0]:=0;End;
  60: Begin
       S:=EmuStr(RL(SP+2));
       H:=HandleFile;
       If H<0 Then RD[0]:=-35
       Else Begin
        Assign(EmuFile[H],S);
        {$I-}Rewrite(EmuFile[H],1);{$I+}
        If IOResult<>0 Then RD[0]:=-36 Else Begin EmuFUsed[H]:=True;RD[0]:=H;End;
       End;
      End;
  61: Begin
       S:=ResolveFile(EmuStr(RL(SP+2)));
       Mode:=RW(SP+6);
       H:=HandleFile;
       If H<0 Then RD[0]:=-35
       Else If Not FileExists(S) Then RD[0]:=-33
       Else Begin
        Assign(EmuFile[H],S);
        {$I-}Reset(EmuFile[H],1);{$I+}
        If IOResult<>0 Then RD[0]:=-36 Else Begin EmuFUsed[H]:=True;RD[0]:=H;End;
       End;
      End;
  62: Begin
       H:=RW(SP+2);
       If (H>=6) And (H<=25) And EmuFUsed[H] Then Begin
        {$I-}Close(EmuFile[H]);{$I+}
        If IOResult<>0 Then ;
        EmuFUsed[H]:=False;RD[0]:=0;
       End Else RD[0]:=-37;
      End;
  63: Begin
       H:=RW(SP+2);Cnt:=RL(SP+4);A:=RL(SP+8);
       If (H>=6) And (H<=25) And EmuFUsed[H] Then Begin
        If Cnt>VMEM_SIZE-A Then Cnt:=VMEM_SIZE-A;
        If Cnt<0 Then Cnt:=0;
        Done:=0;
        {$I-}BlockRead(EmuFile[H],VMem[A],Cnt,Done);{$I+}
        If IOResult<>0 Then RD[0]:=-12 Else RD[0]:=Done;
       End Else If H=0 Then RD[0]:=0 Else RD[0]:=-37;
      End;
  64: Begin
       H:=RW(SP+2);Cnt:=RL(SP+4);A:=RL(SP+8);
       If (H>=6) And (H<=25) And EmuFUsed[H] Then Begin
        Done:=0;
        {$I-}BlockWrite(EmuFile[H],VMem[A],Cnt,Done);{$I+}
        If IOResult<>0 Then RD[0]:=-12 Else RD[0]:=Done;
       End Else If (H=1) Or (H=2) Then Begin
        For Len:=0 To Cnt-1 Do VtOut(Chr(RB(A+Len)));
        OutToMem;RD[0]:=Cnt;
       End Else RD[0]:=-37;
      End;
  65: Begin
       S:=ResolveFile(EmuStr(RL(SP+2)));
       If Not FileExists(S) Then RD[0]:=-33
       Else Begin Assign(EmuFile[25],S);{$I-}Erase(EmuFile[25]);{$I+}If IOResult<>0 Then RD[0]:=-36 Else RD[0]:=0;End;
      End;
  66: Begin
       Pos2:=RL(SP+2);Mode:=RW(SP+8);H:=RW(SP+6);
       If (H>=6) And (H<=25) And EmuFUsed[H] Then Begin
        If Mode=1 Then Pos2:=Pos2+FilePos(EmuFile[H])
        Else If Mode=2 Then Pos2:=Pos2+FileSize(EmuFile[H]);
        {$I-}Seek(EmuFile[H],Pos2);{$I+}
        If IOResult<>0 Then RD[0]:=-64 Else RD[0]:=Pos2;
       End Else RD[0]:=-37;
      End;
  78: Begin
       S:=EmuStr(RL(SP+2));
       {$I-}FindFirst(S,AnyFile-Directory,EmuSF);{$I+}
       If DosError=0 Then Begin FillDta(EmuSF);RD[0]:=0;End Else RD[0]:=-33;
      End;
  79: Begin
       FindNext(EmuSF);
       If DosError=0 Then Begin FillDta(EmuSF);RD[0]:=0;End Else RD[0]:=-33;
      End;
  76: Begin EmuHalt:=True;EmuCode:=SmallInt(RW(SP+2));End;
  49: Begin EmuHalt:=True;EmuCode:=SmallInt(RW(SP+6));End;
  48: RD[0]:=$1500;
  45: RD[0]:=0;
 Else
  RD[0]:=-32;
 End;
End;

Procedure Bios;
Var Fn: Word; SP: LongInt;
Begin
 SP:=RA[7];
 Fn:=RW(SP);
 Case Fn Of
  0: RD[0]:=0;
  1: If KeyPressed Or (KeyQ<>'') Then RD[0]:=-1 Else RD[0]:=0;
  2: RD[0]:=EmuKey;
  3: Begin
      If RW(SP+2)=2 Then Begin VtOut(Chr(RW(SP+4) And $FF));OutToMem;End;
      RD[0]:=0;
     End;
  4: RD[0]:=0;
  5: RD[0]:=0;
  8: RD[0]:=0;
  11: RD[0]:=0;
  10: RD[0]:=0;
  9: RD[0]:=0;
  7: RD[0]:=0;
 Else RD[0]:=0;
 End;
End;

Procedure XBios;
Var Fn: Word; SP: LongInt;
Begin
 SP:=RA[7];
 Fn:=RW(SP);
 Case Fn Of
  2,3: RD[0]:=M_SCREEN;
  4: RD[0]:=2;
  5: RD[0]:=0;
  14: RD[0]:=0;
  17: Begin
       EmuSeed:=EmuSeed*1103515245+12345;
       RD[0]:=(EmuSeed Shr 8) And $FFFFFF;
      End;
  21: RD[0]:=0;
  23: RD[0]:=(2026-1980) Shl 25 Or (11 Shl 21) Or (2 Shl 16);
  25: RD[0]:=0;
  37: Delay(10);
  38: Begin
       { Supexec }
       Push32(RPC);RPC:=RL(SP+2);
       RD[0]:=0;
      End;
  64: RD[0]:=0;
 Else RD[0]:=0;
 End;
End;

{ ---------------------------- VDI et AES -------------------------------- }

Procedure VdiCall(PB: LongInt);
Var Contrl,Intin,Ptsin,Intout,Ptsout: LongInt; Op,N,I,Sub: Integer; X1,Y1,X2,Y2,R: Integer; S: String;
    SavC,SavS: Integer;
 Procedure IO(I: Integer; V: Integer);
 Begin WW(Intout+I*2,Word(V));End;
Begin
 Contrl:=RL(PB);Intin:=RL(PB+4);Ptsin:=RL(PB+8);Intout:=RL(PB+12);Ptsout:=RL(PB+16);
 Op:=SmallInt(RW(Contrl));N:=SmallInt(RW(Contrl+2));
 Sub:=SmallInt(RW(Contrl+10));
 WW(Contrl+8,0);
 SavC:=FilCol;SavS:=FilSty;
 Case Op Of
  1,100: Begin
          For I:=0 To 44 Do IO(I,0);
          IO(0,639);IO(1,399);IO(2,1);IO(3,372);IO(4,372);IO(13,2);IO(35,1);
          WW(Contrl+12,1);
         End;
  2,101: ;
  3: Begin OutClear;OutToMem;End;
  6: Begin
      For I:=0 To N-2 Do
       OLine(SmallInt(RW(Ptsin+I*4)),SmallInt(RW(Ptsin+I*4+2)),
             SmallInt(RW(Ptsin+I*4+4)),SmallInt(RW(Ptsin+I*4+6)),LineInk);
     End;
  7: For I:=0 To N-1 Do OPlot(SmallInt(RW(Ptsin+I*4)),SmallInt(RW(Ptsin+I*4+2)),1);
  8: Begin
      X1:=SmallInt(RW(Ptsin));Y1:=SmallInt(RW(Ptsin+2));
      For I:=0 To N-1 Do Begin
       { texte graphique : cellule de 8x8 alignee sur la ligne de base }
       For Y2:=0 To 7 Do
        For X2:=0 To 7 Do
         If (Font8[RW(Intin+I*2) And $FF,Y2] And (128 Shr X2))<>0 Then
          OPlot(X1+I*8+X2,Y1-8+Y2+1,1);
      End;
     End;
  9: Begin
      For I:=0 To N-1 Do Begin PX[I]:=SmallInt(RW(Ptsin+I*4));PY[I]:=SmallInt(RW(Ptsin+I*4+2));End;

      OFillPoly(N);
      FilCol:=SavC;FilSty:=SavS;
     End;
  11: Begin
       X1:=SmallInt(RW(Ptsin));Y1:=SmallInt(RW(Ptsin+2));
       X2:=SmallInt(RW(Ptsin+4));Y2:=SmallInt(RW(Ptsin+6));

       Case Sub Of
        1: Begin
            PX[0]:=X1;PY[0]:=Y1;PX[1]:=X2+1;PY[1]:=Y1;PX[2]:=X2+1;PY[2]:=Y2+1;PX[3]:=X1;PY[3]:=Y2+1;
            OFillPoly(4);
           End;
        4: OPie(X1,Y1,SmallInt(RW(Ptsin+8)),SmallInt(RW(Ptsin+8)),0,3600);
        5: OPie(X1,Y1,SmallInt(RW(Ptsin+4)),SmallInt(RW(Ptsin+6)),0,3600);
        2: OArc(X1,Y1,SmallInt(RW(Ptsin+12)),SmallInt(RW(Ptsin+12)),SmallInt(RW(Intin)),SmallInt(RW(Intin+2)));
        3: OPie(X1,Y1,SmallInt(RW(Ptsin+12)),SmallInt(RW(Ptsin+12)),SmallInt(RW(Intin)),SmallInt(RW(Intin+2)));
       End;
       FilCol:=SavC;FilSty:=SavS;
      End;
  23: Begin
       FilSty:=SmallInt(RW(Intin));IO(0,FilSty);
       If FilSty=0 Then FilSty:=0;
      End;
  24: Begin FilIdx:=SmallInt(RW(Intin));IO(0,FilIdx);End;
  25: Begin FilCol:=SmallInt(RW(Intin));IO(0,FilCol);End;
  17: Begin LinCol:=SmallInt(RW(Intin));LinCol:=LinCol;IO(0,LinCol);End;
  22: Begin VdiTxtCol:=SmallInt(RW(Intin));IO(0,VdiTxtCol);End;
  124: Begin IO(0,0);WW(Ptsout,MX And $FFFF);WW(Ptsout+2,MY And $FFFF);End;
 Else
  IO(0,0);
 End;
 If EmuActive Then OutToMem;
End;

Function AesAlert(Const S: String; Def: Integer): Integer;
Var P1,P2,P3: Integer; Lines,Btns,T: String; R: Integer;
Begin
 { format : [icone][ligne|ligne][bouton|bouton] }
 Lines:='';Btns:='';
 P1:=Pos('][',S);
 If P1>0 Then Begin
  T:=Copy(S,P1+2,255);
  P2:=Pos('][',T);
  If P2>0 Then Begin Lines:=Copy(T,1,P2-1);Btns:=Copy(T,P2+2,255);End;
  If (Btns<>'') And (Btns[Length(Btns)]=']') Then Delete(Btns,Length(Btns),1);
 End;
 If Btns='' Then Btns:='OK';
 R:=AlertBox(Lines,Btns);
 AesAlert:=R;
End;

Procedure AesCall(PB: LongInt);
Var Ctl,Glob,IntIn,IntOut,AddrIn,AddrOut: LongInt; Op: Integer;
 Procedure IO(I: Integer; V: Integer);
 Begin WW(IntOut+I*2,Word(V));End;
Begin
 Ctl:=RL(PB);Glob:=RL(PB+4);IntIn:=RL(PB+8);IntOut:=RL(PB+12);AddrIn:=RL(PB+16);AddrOut:=RL(PB+20);
 Op:=SmallInt(RW(Ctl));
 IO(0,1);
 Case Op Of
  10: Begin
       Inc(AesNext);
       IO(0,AesNext);
       WW(Glob,$0120);WW(Glob+2,1);WW(Glob+4,AesNext);
      End;
  19: IO(0,1);
  77: Begin IO(0,1);IO(1,8);IO(2,16);IO(3,8);IO(4,16);End;
  78: IO(0,1);
  107: IO(0,1);
  52: IO(0,AesAlert(EmuStr(RL(AddrIn)),SmallInt(RW(IntIn))));
  20: Begin
       IO(0,0);
       { evnt_keybd }
       RD[0]:=0;
       IO(0,Integer(EmuKey And $FFFF));
      End;
  21: Begin
       { evnt_button : attend un clic }
       While (MB And 3)=0 Do Begin
        GetMouseState(MX,MY,MB);
        If KeyPressed Then Begin PollKeys;End;
        If BreakReq Then Begin EmuBrk:=True;MB:=1;End;
        Delay(5);
       End;
       IO(0,1);IO(1,1);IO(2,MX);IO(3,MY);IO(4,0);
      End;
  23,24: Begin Delay(20);IO(0,1);End;
  25: Begin
       GetMouseState(MX,MY,MB);
       IO(0,32);IO(1,MX);IO(2,MY);IO(3,0);IO(4,0);IO(5,0);IO(6,0);
       Delay(20);
      End;
  30: IO(0,1);
  100: IO(0,1);
  101,102,103,105: IO(0,1);
  104: Begin IO(0,1);IO(1,0);IO(2,MENU_H);IO(3,640);IO(4,400);End;
  79: Begin
       GetMouseState(MX,MY,MB);
       IO(0,1);IO(1,MX);IO(2,MY);IO(3,MB And 3);IO(4,0);
      End;
  110: IO(0,0);
 Else IO(0,0);
 End;
End;

Procedure BasicVdisys;
Begin
 VdiCall(VDI_PB);
End;

Procedure BasicGemsys(Op: Integer);
Begin
 VMemWriteW(AES_CTRL,Op);
 AesCall(GB_ADDR);
End;

{ -------------------------------- TRAP --------------------------------- }

Procedure DoTrapN(N: Integer);
Begin
 Case N Of
  1: Begin
      GemDos;
     End;
  2: Begin
      If (RD[0] And $FFFF)=$73 Then VdiCall(RD[1])
      Else If (RD[0] And $FFFF)=$C8 Then AesCall(RD[1]);
     End;
  13: Bios;
  14: XBios;
 Else
  EmuHalt:=True;EmuMsg:='TRAP #'+IntStr(N);
 End;
End;

{ ------------------------- decodage des instructions --------------------- }

Procedure IllegalOp;
Begin
 If EmuMsg='' Then EmuMsg:=T3('Illegal instruction at $','Instruction ill'#130'gale '#133' $','Unerlaubter Befehl bei $')+
   HexStr(EmuOpPC,16)+' ('+HexStr(EmuOpc,16)+')';
 EmuHalt:=True;EmuCode:=-1;
End;

Function ShiftOp(Kind: Integer; Left: Boolean; V: LongInt; Cnt: Integer; Sz: Integer): LongInt;
{ Kind : 0 AS, 1 LS, 2 ROX, 3 RO }
Var M,Mb,X,Val1,Cc,Prev: Int64; I: Integer; Cy,Xc: Boolean; Sgn: Boolean;
Begin
 M:=SzMask(Sz);Mb:=SzMsb(Sz);
 Val1:=Int64(V) And M;
 Cy:=False;Xc:=GetF(FLG_X);
 SetF(FLG_V,False);
 For I:=1 To Cnt Do Begin
  If Left Then Begin
   Cy:=(Val1 And Mb)<>0;
   Case Kind Of
    0: Begin
        If (((Val1 Shl 1) Xor Val1) And Mb)<>0 Then SetF(FLG_V,True);
        Val1:=(Val1 Shl 1) And M;
       End;
    1: Val1:=(Val1 Shl 1) And M;
    2: Begin
        Val1:=((Val1 Shl 1) And M) Or Ord(Xc);Xc:=Cy;
       End;
    3: Val1:=((Val1 Shl 1) And M) Or Ord(Cy);
   End;
   If Kind<>3 Then Xc:=Xc And (Kind=2) Or (Kind<>2) And Cy;
  End Else Begin
   Cy:=(Val1 And 1)<>0;
   Case Kind Of
    0: Begin Sgn:=(Val1 And Mb)<>0;Val1:=Val1 Shr 1;If Sgn Then Val1:=Val1 Or Mb;End;
    1: Val1:=Val1 Shr 1;
    2: Begin Val1:=(Val1 Shr 1) Or (Ord(Xc)*Mb);Xc:=Cy;End;
    3: Val1:=(Val1 Shr 1) Or (Ord(Cy)*Mb);
   End;
   If Kind<>3 Then Xc:=Xc And (Kind=2) Or (Kind<>2) And Cy;
  End;
 End;
 If Cnt>0 Then Begin
  SetF(FLG_C,Cy);
  If Kind<>3 Then SetF(FLG_X,Xc);
  If Kind=2 Then SetF(FLG_C,Xc);
 End Else Begin
  SetF(FLG_C,False);
  If Kind=2 Then SetF(FLG_C,GetF(FLG_X));
 End;
 SetF(FLG_N,(Val1 And Mb)<>0);
 SetF(FLG_Z,Val1=0);
 ShiftOp:=LongInt(Val1 And $FFFFFFFF);
End;

Procedure ExecMovem(Op: Word);
Var Mask: Word; Sz,Mode,Reg,I: Integer; E: TEA; A: LongInt; ToReg: Boolean;
    V: LongInt;
Begin
 ToReg:=(Op And $400)<>0;
 If (Op And $40)<>0 Then Sz:=4 Else Sz:=2;
 Mode:=(Op Shr 3) And 7;Reg:=Op And 7;
 Mask:=Word(Fetch16);
 If (Mode=4) And (Not ToReg) Then Begin
  A:=RA[Reg];
  For I:=0 To 15 Do
   If (Mask And (1 Shl I))<>0 Then Begin
    A:=A-Sz;
    If I<8 Then V:=RA[7-I] Else V:=RD[15-I];
    If Sz=4 Then WL(A,V) Else WW(A,V And $FFFF);
   End;
  RA[Reg]:=A;
  Exit;
 End;
 GetEA(Mode,Reg,Sz,E);
 If (Mode=3) Then A:=RA[Reg]-Sz Else A:=E.N;
 If Mode=3 Then A:=E.N;
 If ToReg Then Begin
  For I:=0 To 15 Do
   If (Mask And (1 Shl I))<>0 Then Begin
    If Sz=4 Then V:=RL(A) Else V:=SmallInt(RW(A));
    If I<8 Then RD[I]:=V Else RA[I-8]:=V;
    A:=A+Sz;
   End;
  If Mode=3 Then RA[Reg]:=A;
 End Else Begin
  For I:=0 To 15 Do
   If (Mask And (1 Shl I))<>0 Then Begin
    If I<8 Then V:=RD[I] Else V:=RA[I-8];
    If Sz=4 Then WL(A,V) Else WW(A,V And $FFFF);
    A:=A+Sz;
   End;
 End;
End;

Procedure ExecBit(Op: Word; Dyn: Boolean);
Var Bit,Mode,Reg,Sz,Kind: Integer; E: TEA; V,M: LongInt;
Begin
 Mode:=(Op Shr 3) And 7;Reg:=Op And 7;
 Kind:=(Op Shr 6) And 3;
 If Dyn Then Bit:=RD[(Op Shr 9) And 7] Else Bit:=Fetch16 And $FF;
 GetEA(Mode,Reg,1,E);
 If E.Kind=0 Then Begin Sz:=4;Bit:=Bit And 31;End Else Begin Sz:=1;Bit:=Bit And 7;End;
 V:=LdEA(E,Sz);
 If E.Kind=0 Then V:=RD[E.N];
 M:=LongInt(Cardinal(1) Shl Bit);
 SetF(FLG_Z,(V And M)=0);
 Case Kind Of
  1: V:=V Xor M;
  2: V:=V And (Not M);
  3: V:=V Or M;
 End;
 If Kind<>0 Then StEA(E,Sz,V);
End;

Procedure Step;
Var Op: Word; Grp,Mode,Reg,Sz,Dn,I,K: Integer; E,E2: TEA; S,Dv,R: LongInt;
    Ext: LongInt; A: LongInt; Cond: Boolean; Cnt: Integer; Q,Rm: Int64; DDiv: Int64;
    Dd: Int64;
Begin
 EmuOpPC:=RPC;
 Op:=RW(RPC);EmuOpc:=Op;
 RPC:=RPC+2;
 Grp:=Op Shr 12;
 Mode:=(Op Shr 3) And 7;Reg:=Op And 7;Dn:=(Op Shr 9) And 7;
 Case Grp Of
  0: Begin
      If (Op And $138)=$108 Then Begin
       { MOVEP }
       Ext:=Fetch16;A:=RA[Reg]+Ext;
       If (Op And $80)<>0 Then Begin
        If (Op And $40)<>0 Then Begin
         WB(A,(RD[Dn] Shr 24) And $FF);WB(A+2,(RD[Dn] Shr 16) And $FF);
         WB(A+4,(RD[Dn] Shr 8) And $FF);WB(A+6,RD[Dn] And $FF);
        End Else Begin WB(A,(RD[Dn] Shr 8) And $FF);WB(A+2,RD[Dn] And $FF);End;
       End Else Begin
        If (Op And $40)<>0 Then
         RD[Dn]:=(RB(A) Shl 24) Or (RB(A+2) Shl 16) Or (RB(A+4) Shl 8) Or RB(A+6)
        Else RD[Dn]:=(RD[Dn] And LongInt($FFFF0000)) Or (RB(A) Shl 8) Or RB(A+2);
       End;
      End Else If (Op And $100)<>0 Then ExecBit(Op,True)
      Else Case (Op Shr 9) And 7 Of
       4: ExecBit(Op,False);
       0,1,2,3,5,6: Begin
           Sz:=1 Shl ((Op Shr 6) And 3);
           If Sz>4 Then Begin IllegalOp;Exit;End;
           { ORI/ANDI/SUBI/ADDI/EORI/CMPI }
           If (Mode=7) And (Reg=4) Then Begin
            { vers CCR / SR }
            Ext:=Fetch16;
            Case (Op Shr 9) And 7 Of
             0: If Sz=1 Then RSR:=RSR Or (Ext And $1F) Else RSR:=RSR Or (Ext And $F71F);
             1: If Sz=1 Then RSR:=RSR And (Word(Ext) Or $FF00) Else RSR:=RSR And Word(Ext);
             5: If Sz=1 Then RSR:=RSR Xor (Ext And $1F) Else RSR:=RSR Xor (Ext And $F71F);
            End;
           End Else Begin
            If Sz=4 Then S:=Fetch32 Else Begin S:=Fetch16;S:=MskV(S,Sz);End;
            GetEA(Mode,Reg,Sz,E);
            Dv:=LdEA(E,Sz);
            Case (Op Shr 9) And 7 Of
             0: Begin R:=Dv Or S;FlagsNZ(R,Sz);StEA(E,Sz,R);End;
             1: Begin R:=Dv And S;FlagsNZ(R,Sz);StEA(E,Sz,R);End;
             2: Begin R:=AluSub(S,Dv,Sz,0,False,True);StEA(E,Sz,R);End;
             3: Begin R:=AluAdd(S,Dv,Sz,0,False,True);StEA(E,Sz,R);End;
             5: Begin R:=Dv Xor S;FlagsNZ(R,Sz);StEA(E,Sz,R);End;
             6: R:=AluSub(S,Dv,Sz,0,False,False);
            End;
           End;
          End;
      Else IllegalOp;
      End;
     End;
  1,2,3: Begin
      Case Grp Of 1: Sz:=1; 2: Sz:=4; Else Sz:=2; End;
      GetEA(Mode,Reg,Sz,E);
      S:=LdEA(E,Sz);
      If ((Op Shr 6) And 7)=1 Then Begin
       { MOVEA }
       If Sz=2 Then S:=SmallInt(S And $FFFF);
       RA[Dn]:=S;
      End Else Begin
       GetEA((Op Shr 6) And 7,Dn,Sz,E2);
       StEA(E2,Sz,S);
       FlagsNZ(S,Sz);
      End;
     End;
  4: Begin
      If (Op And $FF00)=$4E00 Then Begin
       Case Op Of
        $4E70: ;
        $4E71: ;
        $4E72: Begin Ext:=Fetch16;EmuHalt:=True;EmuCode:=0;End;
        $4E73: Begin RSR:=Pop16;RPC:=Pop32;End;
        $4E75: RPC:=Pop32;
        $4E77: Begin RSR:=(RSR And $FFE0) Or (Pop16 And $1F);RPC:=Pop32;End;
        $4E76: If GetF(FLG_V) Then IllegalOp;
       Else
        If (Op And $FFF0)=$4E40 Then DoTrapN(Op And 15)
        Else If (Op And $FFF8)=$4E50 Then Begin
         { LINK }
         Ext:=Fetch16;
         Push32(RA[Reg]);RA[Reg]:=RA[7];RA[7]:=RA[7]+Ext;
        End Else If (Op And $FFF8)=$4E58 Then Begin
         RA[7]:=RA[Reg];RA[Reg]:=Pop32;
        End Else If (Op And $FFF8)=$4E60 Then RUSP:=RA[Reg]
        Else If (Op And $FFF8)=$4E68 Then RA[Reg]:=RUSP
        Else If (Op And $FFC0)=$4E80 Then Begin
         GetEA(Mode,Reg,4,E);Push32(RPC);RPC:=E.N;
        End Else If (Op And $FFC0)=$4EC0 Then Begin
         GetEA(Mode,Reg,4,E);RPC:=E.N;
        End Else IllegalOp;
       End;
      End Else If (Op And $F1C0)=$41C0 Then Begin
       GetEA(Mode,Reg,4,E);RA[Dn]:=E.N;
      End Else If (Op And $F1C0)=$4180 Then Begin
       GetEA(Mode,Reg,2,E);
       S:=SmallInt(LdEA(E,2));Dv:=SmallInt(RD[Dn] And $FFFF);
       If Dv<0 Then Begin SetF(FLG_N,True);EmuHalt:=True;EmuMsg:='CHK';End
       Else If Dv>S Then Begin SetF(FLG_N,False);EmuHalt:=True;EmuMsg:='CHK';End;
      End Else If (Op And $FB80)=$4880 Then Begin
       If Mode=0 Then Begin
        { EXT }
        If (Op And $40)<>0 Then Begin RD[Reg]:=SmallInt(RD[Reg] And $FFFF);FlagsNZ(RD[Reg],4);End
        Else Begin
         RD[Reg]:=(RD[Reg] And LongInt($FFFF0000)) Or (Word(ShortInt(RD[Reg] And $FF)));
         FlagsNZ(RD[Reg],2);
        End;
       End Else ExecMovem(Op);
      End Else If (Op And $FF00)=$4800 Then Begin
       { MOVEM / PEA / SWAP / NBCD }
       If (Op And $FFF8)=$4840 Then Begin
        RD[Reg]:=LongInt((Cardinal(RD[Reg]) Shl 16) Or (Cardinal(RD[Reg]) Shr 16));
        FlagsNZ(RD[Reg],4);
       End Else If (Op And $FFC0)=$4840 Then Begin
        GetEA(Mode,Reg,4,E);Push32(E.N);
       End Else If (Op And $FFC0)=$4800 Then Begin
        { NBCD }
        GetEA(Mode,Reg,1,E);S:=LdEA(E,1);
        R:=0-S-Ord(GetF(FLG_X));
        If ((0-(S And $F)-Ord(GetF(FLG_X))) And $10)<>0 Then R:=R-6;
        SetF(FLG_C,(S<>0) Or GetF(FLG_X));SetF(FLG_X,GetF(FLG_C));
        R:=R And $FF;If R<>0 Then SetF(FLG_Z,False);
        StEA(E,1,R);
       End Else IllegalOp;
      End Else If (Op And $FF00)=$4A00 Then Begin
       If (Op And $FFC0)=$4AC0 Then Begin
        { TAS }
        GetEA(Mode,Reg,1,E);S:=LdEA(E,1);FlagsNZ(S,1);StEA(E,1,S Or $80);
       End Else Begin
        Sz:=1 Shl ((Op Shr 6) And 3);GetEA(Mode,Reg,Sz,E);S:=LdEA(E,Sz);FlagsNZ(S,Sz);
       End;
      End Else If ((Op Shr 8) And $F) In [0,2,4,6] Then Begin
       Case (Op Shr 8) And $F Of
        0: Begin
            Sz:=1 Shl ((Op Shr 6) And 3);
            If Sz>4 Then Begin
             { MOVE from SR }
             GetEA(Mode,Reg,2,E);StEA(E,2,RSR);
            End Else Begin
             GetEA(Mode,Reg,Sz,E);S:=LdEA(E,Sz);
             R:=AluSub(S,0,Sz,Ord(GetF(FLG_X)),True,True);StEA(E,Sz,R);
            End;
           End;
        2: Begin
            Sz:=1 Shl ((Op Shr 6) And 3);
            If Sz>4 Then Begin
             { MOVE from CCR }
             GetEA(Mode,Reg,2,E);StEA(E,2,RSR And $1F);
            End Else Begin
             GetEA(Mode,Reg,Sz,E);LdEA(E,Sz);StEA(E,Sz,0);
             SetF(FLG_N,False);SetF(FLG_Z,True);SetF(FLG_V,False);SetF(FLG_C,False);
            End;
           End;
        4: Begin
            Sz:=1 Shl ((Op Shr 6) And 3);
            If Sz>4 Then Begin
             { MOVE to CCR }
             GetEA(Mode,Reg,2,E);S:=LdEA(E,2);RSR:=(RSR And $FF00) Or (S And $1F);
            End Else Begin
             GetEA(Mode,Reg,Sz,E);S:=LdEA(E,Sz);
             R:=AluSub(S,0,Sz,0,False,True);StEA(E,Sz,R);
            End;
           End;
        6: Begin
            Sz:=1 Shl ((Op Shr 6) And 3);
            If Sz>4 Then Begin
             GetEA(Mode,Reg,2,E);S:=LdEA(E,2);RSR:=S And $F71F;
            End Else Begin
             GetEA(Mode,Reg,Sz,E);S:=LdEA(E,Sz);R:=Not S;FlagsNZ(R,Sz);StEA(E,Sz,R);
            End;
           End;
       Else IllegalOp;
       End;
      End Else IllegalOp;
     End;
  5: Begin
      If ((Op Shr 6) And 3)=3 Then Begin
       If Mode=1 Then Begin
        { DBcc }
        Ext:=Fetch16;
        If Not CondOk((Op Shr 8) And $F) Then Begin
         I:=SmallInt((RD[Reg] And $FFFF)-1);
         RD[Reg]:=(RD[Reg] And LongInt($FFFF0000)) Or (I And $FFFF);
         If I<>-1 Then RPC:=EmuOpPC+2+Ext;
        End;
       End Else Begin
        { Scc }
        GetEA(Mode,Reg,1,E);
        If CondOk((Op Shr 8) And $F) Then StEA(E,1,$FF) Else StEA(E,1,0);
       End;
      End Else Begin
       Sz:=1 Shl ((Op Shr 6) And 3);
       K:=Dn;If K=0 Then K:=8;
       GetEA(Mode,Reg,Sz,E);
       If E.Kind=1 Then Begin
        If (Op And $100)<>0 Then RA[E.N]:=RA[E.N]-K Else RA[E.N]:=RA[E.N]+K;
       End Else Begin
        S:=LdEA(E,Sz);
        If (Op And $100)<>0 Then R:=AluSub(K,S,Sz,0,False,True)
        Else R:=AluAdd(K,S,Sz,0,False,True);
        StEA(E,Sz,R);
       End;
      End;
     End;
  6: Begin
      Cond:=False;
      Ext:=ShortInt(Op And $FF);
      If (Op And $FF)=0 Then Ext:=Fetch16
      Else If (Op And $FF)=$FF Then Ext:=Fetch32;
      K:=(Op Shr 8) And $F;
      If K=1 Then Begin Push32(RPC);RPC:=EmuOpPC+2+Ext;End
      Else If CondOk(K) Then RPC:=EmuOpPC+2+Ext;
     End;
  7: Begin
      If (Op And $100)<>0 Then IllegalOp
      Else Begin RD[Dn]:=ShortInt(Op And $FF);FlagsNZ(RD[Dn],4);End;
     End;
  8: Begin
      If ((Op Shr 6) And 7)=3 Then Begin
       { DIVU }
       GetEA(Mode,Reg,2,E);S:=LdEA(E,2) And $FFFF;
       If S=0 Then Begin EmuHalt:=True;EmuMsg:=ErrText(11);EmuCode:=-1;End
       Else Begin
        Dd:=Int64(RD[Dn]) And $FFFFFFFF;
        Q:=Dd Div S;Rm:=Dd Mod S;
        If Q>$FFFF Then Begin SetF(FLG_V,True);SetF(FLG_C,False);End
        Else Begin
         RD[Dn]:=LongInt((Rm Shl 16) Or Q);
         SetF(FLG_N,(Q And $8000)<>0);SetF(FLG_Z,Q=0);SetF(FLG_V,False);SetF(FLG_C,False);
        End;
       End;
      End Else If ((Op Shr 6) And 7)=7 Then Begin
       { DIVS }
       GetEA(Mode,Reg,2,E);S:=SmallInt(LdEA(E,2));
       If S=0 Then Begin EmuHalt:=True;EmuMsg:=ErrText(11);EmuCode:=-1;End
       Else Begin
        Dd:=RD[Dn];
        Q:=Dd Div S;Rm:=Dd Mod S;
        If (Q>32767) Or (Q<-32768) Then Begin SetF(FLG_V,True);SetF(FLG_C,False);End
        Else Begin
         RD[Dn]:=LongInt(((Rm And $FFFF) Shl 16) Or (Q And $FFFF));
         SetF(FLG_N,Q<0);SetF(FLG_Z,Q=0);SetF(FLG_V,False);SetF(FLG_C,False);
        End;
       End;
      End Else If (Op And $1F0)=$100 Then Begin
       { SBCD }
       If (Op And 8)<>0 Then Begin
        RA[Reg]:=RA[Reg]-1;RA[Dn]:=RA[Dn]-1;S:=RB(RA[Reg]);Dv:=RB(RA[Dn]);
       End Else Begin S:=RD[Reg] And $FF;Dv:=RD[Dn] And $FF;End;
       R:=(Dv And $F)-(S And $F)-Ord(GetF(FLG_X));
       If R<0 Then R:=R-6;
       R:=R+(Dv And $F0)-(S And $F0);
       SetF(FLG_C,R<0);If R<0 Then R:=R-$60;
       SetF(FLG_X,GetF(FLG_C));R:=R And $FF;If R<>0 Then SetF(FLG_Z,False);
       If (Op And 8)<>0 Then WB(RA[Dn],R) Else RD[Dn]:=(RD[Dn] And LongInt($FFFFFF00)) Or R;
      End Else Begin
       Sz:=1 Shl ((Op Shr 6) And 3);
       GetEA(Mode,Reg,Sz,E);
       If (Op And $100)<>0 Then Begin
        S:=RD[Dn];Dv:=LdEA(E,Sz);R:=Dv Or S;FlagsNZ(R,Sz);StEA(E,Sz,R);
       End Else Begin
        S:=LdEA(E,Sz);Dv:=RD[Dn];R:=Dv Or S;FlagsNZ(R,Sz);
        E2.Kind:=0;E2.N:=Dn;StEA(E2,Sz,R);
       End;
      End;
     End;
  9,13: Begin
      { SUB / ADD }
      If ((Op Shr 6) And 3)=3 Then Begin
       { SUBA / ADDA }
       If (Op And $100)<>0 Then Sz:=4 Else Sz:=2;
       GetEA(Mode,Reg,Sz,E);S:=LdEA(E,Sz);
       If Sz=2 Then S:=SmallInt(S And $FFFF);
       If Grp=9 Then RA[Dn]:=RA[Dn]-S Else RA[Dn]:=RA[Dn]+S;
      End Else Begin
       Sz:=1 Shl ((Op Shr 6) And 3);
       If ((Op And $130)=$100) Then Begin
        { SUBX / ADDX }
        If (Op And 8)<>0 Then Begin
         RA[Reg]:=RA[Reg]-Sz;RA[Dn]:=RA[Dn]-Sz;
         E.Kind:=2;E.N:=RA[Reg];E2.Kind:=2;E2.N:=RA[Dn];
        End Else Begin E.Kind:=0;E.N:=Reg;E2.Kind:=0;E2.N:=Dn;End;
        S:=LdEA(E,Sz);Dv:=LdEA(E2,Sz);
        If Grp=9 Then R:=AluSub(S,Dv,Sz,Ord(GetF(FLG_X)),True,True)
        Else R:=AluAdd(S,Dv,Sz,Ord(GetF(FLG_X)),True,True);
        StEA(E2,Sz,R);
       End Else Begin
        GetEA(Mode,Reg,Sz,E);
        If (Op And $100)<>0 Then Begin
         S:=RD[Dn];Dv:=LdEA(E,Sz);
         If Grp=9 Then R:=AluSub(S,Dv,Sz,0,False,True) Else R:=AluAdd(S,Dv,Sz,0,False,True);
         StEA(E,Sz,R);
        End Else Begin
         S:=LdEA(E,Sz);Dv:=MskV(RD[Dn],Sz);
         If Grp=9 Then R:=AluSub(S,Dv,Sz,0,False,True) Else R:=AluAdd(S,Dv,Sz,0,False,True);
         E2.Kind:=0;E2.N:=Dn;StEA(E2,Sz,R);
        End;
       End;
      End;
     End;
  10: Begin
      { ligne A : on ignore (retour des pointeurs LineA pour $A000) }
      If Op=$A000 Then Begin RD[0]:=M_LINEA;RA[0]:=M_LINEA;End;
     End;
  11: Begin
      If ((Op Shr 6) And 3)=3 Then Begin
       If (Op And $100)<>0 Then Sz:=4 Else Sz:=2;
       GetEA(Mode,Reg,Sz,E);S:=LdEA(E,Sz);
       If Sz=2 Then S:=SmallInt(S And $FFFF);
       R:=AluSub(S,RA[Dn],4,0,False,False);
      End Else Begin
       Sz:=1 Shl ((Op Shr 6) And 3);
       If ((Op And $138)=$108) Then Begin
        { CMPM }
        GetEA(3,Reg,Sz,E);GetEA(3,Dn,Sz,E2);
        S:=LdEA(E,Sz);Dv:=LdEA(E2,Sz);
        R:=AluSub(S,Dv,Sz,0,False,False);
       End Else If (Op And $100)<>0 Then Begin
        { EOR }
        GetEA(Mode,Reg,Sz,E);S:=RD[Dn];Dv:=LdEA(E,Sz);
        R:=Dv Xor S;FlagsNZ(R,Sz);StEA(E,Sz,R);
       End Else Begin
        GetEA(Mode,Reg,Sz,E);S:=LdEA(E,Sz);Dv:=MskV(RD[Dn],Sz);
        R:=AluSub(S,Dv,Sz,0,False,False);
       End;
      End;
     End;
  12: Begin
      If ((Op Shr 6) And 7)=3 Then Begin
       GetEA(Mode,Reg,2,E);S:=LdEA(E,2) And $FFFF;
       RD[Dn]:=LongInt((Cardinal(RD[Dn]) And $FFFF)*Cardinal(S));
       FlagsNZ(RD[Dn],4);
      End Else If ((Op Shr 6) And 7)=7 Then Begin
       GetEA(Mode,Reg,2,E);S:=SmallInt(LdEA(E,2));
       RD[Dn]:=SmallInt(RD[Dn] And $FFFF)*S;
       FlagsNZ(RD[Dn],4);
      End Else If (Op And $1F0)=$100 Then Begin
       { ABCD }
       If (Op And 8)<>0 Then Begin
        RA[Reg]:=RA[Reg]-1;RA[Dn]:=RA[Dn]-1;S:=RB(RA[Reg]);Dv:=RB(RA[Dn]);
       End Else Begin S:=RD[Reg] And $FF;Dv:=RD[Dn] And $FF;End;
       R:=(Dv And $F)+(S And $F)+Ord(GetF(FLG_X));
       If R>9 Then R:=R+6;
       R:=R+(Dv And $F0)+(S And $F0);
       SetF(FLG_C,R>$99);If R>$99 Then R:=R+$60;
       SetF(FLG_X,GetF(FLG_C));R:=R And $FF;If R<>0 Then SetF(FLG_Z,False);
       If (Op And 8)<>0 Then WB(RA[Dn],R) Else RD[Dn]:=(RD[Dn] And LongInt($FFFFFF00)) Or R;
      End Else If (Op And $130)=$100 Then Begin
       { EXG }
       Case (Op Shr 3) And $1F Of
        8: Begin S:=RD[Dn];RD[Dn]:=RD[Reg];RD[Reg]:=S;End;
        9: Begin S:=RA[Dn];RA[Dn]:=RA[Reg];RA[Reg]:=S;End;
        17: Begin S:=RD[Dn];RD[Dn]:=RA[Reg];RA[Reg]:=S;End;
       Else IllegalOp;
       End;
      End Else Begin
       Sz:=1 Shl ((Op Shr 6) And 3);
       GetEA(Mode,Reg,Sz,E);
       If (Op And $100)<>0 Then Begin
        S:=RD[Dn];Dv:=LdEA(E,Sz);R:=Dv And S;FlagsNZ(R,Sz);StEA(E,Sz,R);
       End Else Begin
        S:=LdEA(E,Sz);Dv:=RD[Dn];R:=Dv And S;FlagsNZ(R,Sz);
        E2.Kind:=0;E2.N:=Dn;StEA(E2,Sz,R);
       End;
      End;
     End;
  14: Begin
      If ((Op Shr 6) And 3)=3 Then Begin
       { decalage memoire d'un bit }
       GetEA(Mode,Reg,2,E);S:=LdEA(E,2);
       R:=ShiftOp((Op Shr 9) And 3,(Op And $100)<>0,S,1,2);
       StEA(E,2,R);
      End Else Begin
       Sz:=1 Shl ((Op Shr 6) And 3);
       If (Op And $20)<>0 Then Cnt:=RD[Dn] And 63 Else Begin Cnt:=Dn;If Cnt=0 Then Cnt:=8;End;
       K:=(Op Shr 3) And 3;
       E.Kind:=0;E.N:=Reg;
       S:=LdEA(E,Sz);
       R:=ShiftOp(K,(Op And $100)<>0,S,Cnt,Sz);
       StEA(E,Sz,R);
      End;
     End;
 Else IllegalOp;
 End;
End;

{ ----------------------------- chargeur PRG ----------------------------- }

Function LoadPRG(Const Name: String; Const Tail: String): Boolean;
Var F: File; Hdr: Array[0..27] Of Byte; Tl,Dl,Bl,Sl: LongInt; Base,Load,I,Off: LongInt;
    Buf: Array[0..4095] Of Byte; N: Word; Got: LongInt; Cmd: String; B: Byte; Fx: LongInt;
    Rd2: LongInt;
 Function HL(O: Integer): LongInt;
 Begin
  HL:=LongInt((Cardinal(Hdr[O]) Shl 24) Or (Cardinal(Hdr[O+1]) Shl 16) Or
              (Cardinal(Hdr[O+2]) Shl 8) Or Hdr[O+3]);
 End;
Begin
 LoadPRG:=False;
 Cmd:=ResolveFile(Name);
 If Not FileExists(Cmd) Then Exit;
 Assign(F,Cmd);
 {$I-}Reset(F,1);{$I+}
 If IOResult<>0 Then Exit;
 BlockRead(F,Hdr,28,N);
 If (N<28) Or (Hdr[0]<>$60) Or (Hdr[1]<>$1A) Then Begin Close(F);Exit;End;
 Tl:=HL(2);Dl:=HL(6);Bl:=HL(10);Sl:=HL(14);
 Base:=M_BASEPAGE;Load:=Base+$100;
 If Load+Tl+Dl+Bl>M_TOP-$20000 Then Begin Close(F);Exit;End;
 FillChar(VMem[Base],$100,0);
 FillChar(VMem[Load],Tl+Dl+Bl,0);
 { texte + donnees }
 Got:=0;
 While Got<Tl+Dl Do Begin
  I:=Tl+Dl-Got;If I>4096 Then I:=4096;
  BlockRead(F,Buf,I,N);
  If N=0 Then Begin Got:=Tl+Dl;End
  Else Begin Move(Buf[0],VMem[Load+Got],N);Got:=Got+N;End;
 End;
 { relocation }
 Seek(F,28+Tl+Dl+Sl);
 BlockRead(F,Hdr,4,N);
 If N=4 Then Begin
  Fx:=HL(0);
  If Fx<>0 Then Begin
   Off:=Fx;
   WL(Load+Off,RL(Load+Off)+Load);
   Repeat
    BlockRead(F,B,1,N);
    If N=0 Then B:=0;
    If B=1 Then Off:=Off+254
    Else If B<>0 Then Begin Off:=Off+B;WL(Load+Off,RL(Load+Off)+Load);End;
   Until B=0;
  End;
 End;
 Close(F);
 { page de base }
 WL(Base+0,Base);WL(Base+4,M_TOP);
 WL(Base+8,Load);WL(Base+12,Tl);
 WL(Base+16,Load+Tl);WL(Base+20,Dl);
 WL(Base+24,Load+Tl+Dl);WL(Base+28,Bl);
 WL(Base+32,Base+$80);WL(Base+44,M_ENV);
 WB(M_ENV,0);WB(M_ENV+1,0);
 WB(Base+$80,Length(Tail));
 For I:=1 To Length(Tail) Do WB(Base+$80+I,Ord(Tail[I]));
 WB(Base+$80+Length(Tail)+1,0);
 EmuDta:=Base+$80;
 EmuHeap:=Load+Tl+Dl+Bl+$1000;
 EmuHeap:=(EmuHeap+3) And (Not 3);
 { code de terminaison : move.w #0,-(sp) ; trap #1 }
 WW(M_STUB,$3F3C);WW(M_STUB+2,0);WW(M_STUB+4,$4E41);
 For I:=0 To 7 Do Begin RD[I]:=0;RA[I]:=0;End;
 RA[7]:=M_TOP-$100;
 Push32(Base);
 Push32(M_STUB);
 RA[0]:=0;
 RPC:=Load;
 RSR:=$0000;
 LoadPRG:=True;
End;

Procedure EmuLoop;
Var K: Integer;
Begin
 EmuSteps:=0;
 While (Not EmuHalt) And (Not EmuBrk) And (Not QuitReq) Do Begin
  Step;
  Inc(EmuSteps);
  If (EmuSteps And $3FFF)=0 Then Begin
   If EmuScreen Then MemToOut;
   PollKeys;
   RunPoll;
   If BreakReq Then EmuBrk:=True;
  End;
 End;
 If EmuScreen Then MemToOut;
End;

Procedure EmuPrepare(ForPrg: Boolean);
Var I: Integer;
Begin
 EmuHalt:=False;EmuBrk:=False;EmuCode:=0;EmuMsg:='';EmuSuper:=False;
 EmuSeed:=NowCs;VtState:=0;VtRev:=False;AesNext:=0;
 For I:=6 To 25 Do EmuFUsed[I]:=False;
 EmuScreen:=ForPrg;EmuActive:=True;
 If ForPrg Then Begin
  FilCol:=1;FilSty:=0;FilIdx:=1;LinCol:=1;VdiTxtCol:=1;
  FillChar(VMem[M_LINEA],256,0);
  WW(M_LINEA+2,2);WW(M_LINEA+12,80);WW(M_LINEA-12,640);WW(M_LINEA-4,400);
  Win[W_OUT].Open:=True;
  If Not Win[W_OUT].Full Then ToggleFull(W_OUT);
  BringToFront(W_OUT);
  OutClear;
  OutToMem;
 End;
End;

Procedure EmuFinish;
Var I: Integer;
Begin
 For I:=6 To 25 Do If EmuFUsed[I] Then Begin {$I-}Close(EmuFile[I]);{$I+}If IOResult<>0 Then ;EmuFUsed[I]:=False;End;
 OutFlush(True);
End;

Function EmuRunPRG(Const Name: String): Boolean;
Var Tail: String; I: Integer;
Begin
 EmuRunPRG:=False;
 Tail:='';
 If Not LoadPRG(Name,Tail) Then Exit;
 EmuRunPRG:=True;
 HideMouse;Inc(MouseLock);
 RunningProg:=True;BreakReq:=False;
 EmuPrepare(True);
 OutUpdateLive;
 DrawDesktop;
 EmuLoop;
 EmuFinish;
 EmuActive:=False;
 Dec(MouseLock);
 RunningProg:=False;
 NoSound;
 If EmuMsg<>'' Then ConAdd(EmuMsg)
 Else If EmuBrk Then ConAdd(T3('- Break -','- Break -','- Break -'))
 Else ConAdd(ShortName(Name)+T3(' ended, code ',' termin'#130', code ',' beendet, Code ')+IntStr(EmuCode));
 BreakReq:=False;
 BringToFront(W_CMD);
 UIDirty:=True;
 DrawDesktop;
End;

Procedure EmuCallAddr(Addr: LongInt; N: Integer; Var Args: TArgs);
{ Convention d'appel ST BASIC (annexe F) : la pile contient (apres l'adresse de
  retour) un entier de 2 octets = nombre de parametres, puis un pointeur de 4
  octets vers un tableau de parametres de 8 octets chacun (pointeur pour les
  chaines). }
Var I,J: Integer; Str0: LongInt; D8: Double; B8: Array[0..7] Of Byte;
Begin
 If (Addr<=0) Or (Addr>=VMEM_SIZE) Then Begin Fail(31);Exit;End;
 EmuPrepare(False);
 For I:=0 To 7 Do Begin RD[I]:=0;RA[I]:=0;End;
 RA[7]:=M_TOP-$100;
 Str0:=CALL_STR;
 For I:=1 To N Do Begin
  FillChar(VMem[CALL_ARR+(I-1)*8],8,0);
  If Args[I].IsStr Then Begin
   PutStr(Str0,Args[I].S);
   WL(CALL_ARR+(I-1)*8,Str0);
   Str0:=Str0+Length(Args[I].S)+1;
  End Else If (Args[I].N=Int(Args[I].N)) And (Abs(Args[I].N)<2147483000.0) Then
   WL(CALL_ARR+(I-1)*8,Round(Args[I].N))
  Else Begin
   D8:=Args[I].N;
   Move(D8,B8,8);
   For J:=0 To 7 Do VMem[CALL_ARR+(I-1)*8+J]:=B8[7-J];
  End;
 End;
 WW(M_STUB,$4E72);WW(M_STUB+2,0);
 Push32(CALL_ARR);
 Push16(N);
 Push32(M_STUB);
 RPC:=Addr;RSR:=0;
 HideMouse;Inc(MouseLock);
 EmuLoop;
 EmuFinish;
 EmuActive:=False;
 Dec(MouseLock);
 If EmuMsg<>'' Then Begin ConAdd(EmuMsg);Fail(31);End;
 Win[W_OUT].Open:=True;
End;

{$ELSE}

Procedure BasicVdisys;
Begin
End;

Procedure BasicGemsys(Op: Integer);
Begin
End;

Procedure EmuCallAddr(Addr: LongInt; N: Integer; Var Args: TArgs);
Begin
 Fail(31);
End;

Function EmuRunPRG(Const Name: String): Boolean;
Begin
 EmuRunPRG:=False;
End;

{$ENDIF}

{ ====================================================================== }
{          INTERFACE : CONTENU DES FENETRES, EDITEUR, COMMANDES          }
{ ====================================================================== }

Var
 InBuf     : String;
 InPos     : Integer;
 ConPrompt : String[8];
 ConFollow : Boolean;
 ConTop    : Integer;
 HistL     : Array[1..20] Of String[100];
 HistN,HistI : Integer;
 EdL       : Array[1..MAXED] Of PString;
 EdSt      : Array[1..MAXED] Of Byte;   { 0 normal, 1 modifie, 2 retire }
 EdN,EdRow,EdCol,EdTop : Integer;
 LastUICs  : LongInt;
 MenuCool  : Boolean;
 LastDlgCs : LongInt;

Procedure GhostText(X,Y: Integer; Const S: String);
Var I,J,W: Integer;
Begin
 PText(X,Y,S);
 W:=Length(S)*8;
 For J:=0 To 7 Do
  For I:=0 To W-1 Do
   If Odd(I+J) Then
    If GetPixel(X+I,Y+J)=INK Then PutPixel(X+I,Y+J,PAPER);
End;

Function WinRows(N: Integer): Integer;
Var X1,Y1,X2,Y2: Integer;
Begin
 WinClient(N,X1,Y1,X2,Y2);
 WinRows:=(Y2-Y1+1) Div 16;
End;

Function WinCols(N: Integer): Integer;
Var X1,Y1,X2,Y2: Integer;
Begin
 WinClient(N,X1,Y1,X2,Y2);
 WinCols:=(X2-X1+1) Div 8;
End;

{ ----------------------------- LIST ------------------------------------ }

Procedure DrawListContent(X1,Y1,X2,Y2: Integer);
Var R,Rows,Cols,Idx: Integer; S: String;
Begin
 SetViewPort(X1,Y1,X2,Y2,True);
 Box(0,0,X2-X1,Y2-Y1,PAPER);
 Rows:=(Y2-Y1+1) Div 16;Cols:=(X2-X1+1) Div 8;
 For R:=0 To Rows Do Begin
  Idx:=Win[W_LIST].ScrY+R+1;
  If (Idx>=1) And (Idx<=LstN) Then Begin
   S:=Copy(LstL[Idx]^,Win[W_LIST].ScrX+1,Cols+1);
   PText(2,R*16+4,S);
  End;
 End;
End;

{ ----------------------------- OUTPUT ---------------------------------- }

Procedure DrawOutContent(X1,Y1,X2,Y2: Integer);
Begin
 SetViewPort(0,0,SCR_W-1,SCR_H-1,True);
 Box(X1,Y1,X2,Y2,PAPER);
 OutGeom;
 OBlitRect(Win[W_OUT].ScrX,Win[W_OUT].ScrY,
           Win[W_OUT].ScrX+(OGX2-OGX1),Win[W_OUT].ScrY+(OGY2-OGY1));
End;

{ ----------------------------- COMMAND --------------------------------- }

Procedure DrawCmdContent(X1,Y1,X2,Y2: Integer);
Var R,Rows,Cols,Idx,Total,CC: Integer; S: String;
Begin
 SetViewPort(X1,Y1,X2,Y2,True);
 Box(0,0,X2-X1,Y2-Y1,PAPER);
 Rows:=(Y2-Y1+1) Div 16;Cols:=(X2-X1+1) Div 8;
 Total:=ConN+1;
 If ConFollow Then ConTop:=Total-Rows+1;
 If ConTop>Total-Rows+1 Then ConTop:=Total-Rows+1;
 If ConTop<1 Then ConTop:=1;
 CC:=Length(ConPrompt)+InPos;
 If ConFollow Then Begin
  If CC-Win[W_CMD].ScrX>=Cols Then Win[W_CMD].ScrX:=CC-Cols+1;
  If CC<Win[W_CMD].ScrX Then Win[W_CMD].ScrX:=CC;
  If Win[W_CMD].ScrX<0 Then Win[W_CMD].ScrX:=0;
 End;
 For R:=0 To Rows-1 Do Begin
  Idx:=ConTop+R;
  S:='';
  If Idx<=ConN Then S:=ConL[Idx]^
  Else If Idx=Total Then S:=ConPrompt+InBuf;
  If Idx<=Total Then Begin
   PText(0,R*16+4,Copy(S,Win[W_CMD].ScrX+1,Cols+1));
   If (Idx=Total) And (Not EditMode) And (Not RunningProg) Then
    Box((CC-Win[W_CMD].ScrX)*8,R*16+2,(CC-Win[W_CMD].ScrX)*8+7,R*16+14,INK);
   If (Idx=Total) And (CC<Length(S)) And (Not EditMode) And (Not RunningProg) Then
    WText((CC-Win[W_CMD].ScrX)*8,R*16+4,S[CC+1]);
  End;
 End;
End;

{ ------------------------------ EDIT ----------------------------------- }

Procedure EdFree;
Var I: Integer;
Begin
 For I:=1 To EdN Do FreeStr(EdL[I]);
 EdN:=0;
End;

Procedure EdAppend(Const S: String; St: Byte);
Begin
 If EdN>=MAXED Then Exit;
 Inc(EdN);
 EdL[EdN]:=NewStr(S);
 EdSt[EdN]:=St;
End;

Procedure EdSetLine(I: Integer; Const S: String);
Begin
 FreeStr(EdL[I]);
 EdL[I]:=NewStr(Copy(S,1,79));
End;

Procedure EdKeepVisible;
Var Rows,Cols: Integer;
Begin
 Rows:=WinRows(W_EDIT);Cols:=WinCols(W_EDIT);
 If Rows<1 Then Rows:=1;
 If EdRow<1 Then EdRow:=1;
 If EdRow>EdN Then EdRow:=EdN;
 If EdRow<EdTop Then EdTop:=EdRow;
 If EdRow>=EdTop+Rows Then EdTop:=EdRow-Rows+1;
 If EdTop<1 Then EdTop:=1;
 If EdCol<1 Then EdCol:=1;
 If EdCol>79 Then EdCol:=79;
 If EdCol-1<Win[W_EDIT].ScrX Then Win[W_EDIT].ScrX:=EdCol-1;
 If EdCol-1>=Win[W_EDIT].ScrX+Cols Then Win[W_EDIT].ScrX:=EdCol-Cols;
 If Win[W_EDIT].ScrX<0 Then Win[W_EDIT].ScrX:=0;
End;

Procedure DrawEditContent(X1,Y1,X2,Y2: Integer);
Var R,Rows,Cols,Idx,CX: Integer; S: String;
Begin
 SetViewPort(X1,Y1,X2,Y2,True);
 Box(0,0,X2-X1,Y2-Y1,PAPER);
 If Not EditMode Then Exit;
 Rows:=(Y2-Y1+1) Div 16;Cols:=(X2-X1+1) Div 8;
 For R:=0 To Rows-1 Do Begin
  Idx:=EdTop+R;
  If Idx<=EdN Then Begin
   S:=Copy(EdL[Idx]^,Win[W_EDIT].ScrX+1,Cols+1);
   If EdSt[Idx]=0 Then PText(0,R*16+4,S) Else GhostText(0,R*16+4,S);
   If Idx=EdRow Then Begin
    CX:=(EdCol-1-Win[W_EDIT].ScrX)*8;
    Box(CX,R*16+2,CX+7,R*16+14,INK);
    If EdCol<=Length(EdL[Idx]^) Then WText(CX,R*16+4,EdL[Idx]^[EdCol]);
   End;
  End;
 End;
End;

{ ------------------------- barres de defilement ------------------------ }

Procedure ScrollInfo(N: Integer; Var VT,VV,VP,HT,HV,HP: LongInt);
Var X1,Y1,X2,Y2: Integer;
Begin
 WinClient(N,X1,Y1,X2,Y2);
 VV:=(Y2-Y1+1) Div 16;HV:=(X2-X1+1) Div 8;
 Case N Of
  W_LIST: Begin VT:=LstN;VP:=Win[N].ScrY;HT:=90;HP:=Win[N].ScrX;End;
  W_OUT:  Begin VT:=OUT_H Div 16;VP:=Win[N].ScrY Div 16;HT:=OUT_COLS;HP:=Win[N].ScrX Div 8;End;
  W_CMD:  Begin VT:=ConN+1;VP:=ConTop-1;HT:=120;HP:=Win[N].ScrX;End;
 Else
  VT:=EdN+VV;VP:=EdTop-1;HT:=90;HP:=Win[N].ScrX;
 End;
 If VT<VV Then VT:=VV;
End;

Procedure SetScroll(N: Integer; VP,HP: LongInt);
Var VT,VV,VP0,HT,HV,HP0: LongInt;
Begin
 ScrollInfo(N,VT,VV,VP0,HT,HV,HP0);
 If VP>VT-VV Then VP:=VT-VV;
 If VP<0 Then VP:=0;
 If HP>HT-HV Then HP:=HT-HV;
 If HP<0 Then HP:=0;
 Case N Of
  W_LIST: Begin Win[N].ScrY:=VP;Win[N].ScrX:=HP;End;
  W_OUT:  Begin Win[N].ScrY:=VP*16;Win[N].ScrX:=HP*8;End;
  W_CMD:  Begin ConTop:=VP+1;Win[N].ScrX:=HP;ConFollow:=(VP+VV>=VT);End;
 Else Begin EdTop:=VP+1;Win[N].ScrX:=HP;End;
 End;
 If (N=W_OUT) Then OutUpdateLive;
 RedrawWin(N);
End;

{ ----------------------------------------------------------------------- }
{                      FENETRE COMMAND : saisie                            }
{ ----------------------------------------------------------------------- }

Procedure StartEdit; Forward;
Procedure ExitEdit; Forward;

Procedure SetPrompt;
Begin
 If AutoOn Then Begin
  If LineIdxExact(AutoNum)>0 Then ConPrompt:='**' Else ConPrompt:='';
  InBuf:=IntStr(AutoNum)+' ';
  InPos:=Length(InBuf);
 End Else Begin
  If BrokenProg Or CanCont Then ConPrompt:='Br ' Else ConPrompt:='Ok ';
  InBuf:='';InPos:=0;
 End;
End;

Procedure ConRefresh;
Begin
 ConFollow:=True;
 If (ZOrd[3]=W_CMD) And Win[W_CMD].Open Then RedrawContent(W_CMD) Else NeedDraw:=True;
End;

Procedure SubmitCommand;
Var S: String; I,P1: Integer; Body: String;
Begin
 S:=InBuf;
 ConAdd(ConPrompt+S);
 If AutoOn Then Begin
  P1:=1;
  While (P1<=Length(S)) And IsDigit(S[P1]) Do Inc(P1);
  Body:=TrimStr(Copy(S,P1,255));
  If Body<>'' Then ExecDirect(S);
  Inc(AutoNum,AutoStep);
  If AutoNum>65529 Then AutoOn:=False;
  InBuf:='';
 End Else Begin
  If (TrimStr(S)='') And CanCont Then ExecDirect('CONT')
  Else If TrimStr(S)<>'' Then Begin
   If HistN<20 Then Inc(HistN) Else For I:=1 To 19 Do HistL[I]:=HistL[I+1];
   HistL[HistN]:=Copy(S,1,100);
   ExecDirect(S);
  End;
 End;
 HistI:=HistN+1;
 Win[W_CMD].ScrX:=0;
 If EditReq Then Begin EditReq:=False;StartEdit;End;
 SetPrompt;
 ConRefresh;
 NeedDraw:=True;
End;

Procedure CmdKey(K: Word);
Var I: Integer;
Begin
 Case K Of
  K_ENTER: Begin SubmitCommand;Exit;End;
  K_BKSP: If InPos>0 Then Begin Delete(InBuf,InPos,1);Dec(InPos);End;
  K_DEL: If InPos<Length(InBuf) Then Delete(InBuf,InPos+1,1);
  K_LEFT: If InPos>0 Then Dec(InPos);
  K_RIGHT: If InPos<Length(InBuf) Then Inc(InPos);
  K_HOME: InPos:=0;
  K_END: InPos:=Length(InBuf);
  K_UP: If (HistI>1) And (Not AutoOn) Then Begin
         Dec(HistI);InBuf:=HistL[HistI];InPos:=Length(InBuf);
        End;
  K_DOWN: If (HistI<=HistN) And (Not AutoOn) Then Begin
           Inc(HistI);
           If HistI<=HistN Then InBuf:=HistL[HistI] Else InBuf:='';
           InPos:=Length(InBuf);
          End;
  K_CTRLG,K_CTRLC: If AutoOn Then Begin
          AutoOn:=False;ConAdd(ConPrompt+InBuf);SetPrompt;
         End;
  K_ESC: If Not AutoOn Then Begin InBuf:='';InPos:=0;End;
 Else
  If (K>=32) And (K<256) And (Length(InBuf)<150) Then Begin
   Insert(Chr(K),InBuf,InPos+1);Inc(InPos);
  End;
 End;
 ConRefresh;
End;

{ ----------------------------------------------------------------------- }
{                           MODE EDITION                                   }
{ ----------------------------------------------------------------------- }

Procedure EdNewBuffer;
Var I: Integer;
Begin
 EdFree;
 For I:=1 To LCnt Do EdAppend(LineStr(I),0);
 EdAppend('',0);
 EdRow:=1;EdCol:=1;EdTop:=1;
 Win[W_EDIT].ScrX:=0;
End;

Procedure StartEdit;
Var K: Integer;
Begin
 If EditMode Then Exit;
 EditMode:=True;
 Win[W_EDIT].Open:=True;
 BringToFront(W_EDIT);
 EdNewBuffer;
 If EditLineReq>0 Then Begin
  K:=1;
  While K<=EdN Do Begin
   If (EdL[K]^<>'') And (Round(ValStr(EdL[K]^))>=EditLineReq) Then Begin EdRow:=K;K:=EdN;End;
   Inc(K);
  End;
  EditLineReq:=0;
 End;
 NeedDraw:=True;
End;

Procedure ExitEdit;
Begin
 If Not EditMode Then Exit;
 EditMode:=False;
 Win[W_EDIT].Open:=False;
 BringToFront(W_CMD);
 NeedDraw:=True;
End;

Procedure EdRefresh;
Begin
 EdKeepVisible;
 If (ZOrd[3]=W_EDIT) Then RedrawWin(W_EDIT) Else DrawDesktop;
End;

Procedure EdMark(I: Integer);
Begin
 If EdSt[I]=0 Then EdSt[I]:=1;
 If EdSt[I]=2 Then EdSt[I]:=1;
End;

Procedure EdCommit;
Var S: String; Cmd: Boolean;
Begin
 S:=EdL[EdRow]^;
 While (Length(S)>0) And (S[Length(S)]=' ') Do Delete(S,Length(S),1);
 Cmd:=(S<>'') And (Not IsDigit(TrimStr(S)[1]));
 EdSt[EdRow]:=0;
 If S<>'' Then Begin
  If Cmd Then Begin ConAdd(ConPrompt+S);EdSetLine(EdRow,'');End;
  ExecDirect(S);
  If QuitReq Then Exit;
  If EditReq Then EditReq:=False;
  If Not EditMode Then Exit;
 End;
 If EdRow>=EdN Then EdAppend('',0);
 Inc(EdRow);EdCol:=1;
 NeedDraw:=True;
End;

Procedure EdInsSpace;
Var S: String;
Begin
 S:=EdL[EdRow]^;
 While Length(S)<EdCol-1 Do S:=S+' ';
 Insert(' ',S,EdCol);
 EdSetLine(EdRow,S);EdMark(EdRow);
End;

Procedure EdDelChar;
Var S: String;
Begin
 S:=EdL[EdRow]^;
 If EdCol<=Length(S) Then Begin Delete(S,EdCol,1);EdSetLine(EdRow,S);EdMark(EdRow);End;
End;

Procedure EdInsLine;
Var I: Integer;
Begin
 If EdN>=MAXED Then Exit;
 Inc(EdN);
 For I:=EdN DownTo EdRow+1 Do Begin EdL[I]:=EdL[I-1];EdSt[I]:=EdSt[I-1];End;
 EdL[EdRow]:=NewStr('');EdSt[EdRow]:=0;
 EdCol:=1;
End;

Procedure EdRemLine;
Var S: String; N: LongInt; I,K: Integer; C: Integer;
Begin
 If EdSt[EdRow]=2 Then Begin
  { second appui : on supprime aussi de la fenetre }
  FreeStr(EdL[EdRow]);
  For I:=EdRow To EdN-1 Do Begin EdL[I]:=EdL[I+1];EdSt[I]:=EdSt[I+1];End;
  EdL[EdN]:=Nil;Dec(EdN);
  If EdN<1 Then EdAppend('',0);
  Exit;
 End;
 S:=TrimStr(EdL[EdRow]^);
 If (S<>'') And IsDigit(S[1]) Then Begin
  N:=0;K:=1;
  While (K<=Length(S)) And IsDigit(S[K]) Do Begin If N<70000 Then N:=N*10+Ord(S[K])-48;Inc(K);End;
  SetProgLine(N,'');
  EdSt[EdRow]:=2;
 End Else Begin
  FreeStr(EdL[EdRow]);
  For I:=EdRow To EdN-1 Do Begin EdL[I]:=EdL[I+1];EdSt[I]:=EdSt[I+1];End;
  EdL[EdN]:=Nil;Dec(EdN);
  If EdN<1 Then EdAppend('',0);
 End;
End;

Procedure EdLoadText;
Var T: Text; S: String; I: Integer;
Begin
 If Not FileExists('BASIC.BUF') Then Begin
  AlertBox(T3('File not found','Fichier introuvable','Datei nicht gefunden')+': BASIC.BUF','OK');
  Exit;
 End;
 {$I-}
 Assign(T,'BASIC.BUF');Reset(T);
 {$I+}
 If IOResult<>0 Then Exit;
 EdFree;
 While (Not Eof(T)) And (EdN<MAXED) Do Begin
  ReadLn(T,S);
  EdAppend(Copy(S,1,79),1);
 End;
 Close(T);
 EdAppend('',0);
 EdRow:=1;EdCol:=1;EdTop:=1;
End;

Procedure EdSaveText;
Var T: Text; I,N: Integer;
Begin
 {$I-}
 Assign(T,'BASIC.BUF');Rewrite(T);
 {$I+}
 If IOResult<>0 Then Begin MsgBox(ErrText(57));Exit;End;
 N:=EdN;If N>24 Then N:=24;
 For I:=1 To N Do WriteLn(T,EdL[I]^);
 Close(T);
End;

Procedure EdGoto;
Var I: Integer; N: LongInt; S: String; K: Integer;
Begin
 FormLbl[1]:=T3('Line','Ligne','Zeile');FormVal[1]:='';FormFW:=8;
 If Not FormBox(T3('Display basic line number:','Afficher la ligne BASIC :','BASIC-Zeilennummer anzeigen:'),1,'') Then Exit;
 N:=0;
 For K:=1 To Length(FormVal[1]) Do If IsDigit(FormVal[1][K]) Then N:=N*10+Ord(FormVal[1][K])-48;
 For I:=1 To EdN Do Begin
  S:=TrimStr(EdL[I]^);
  K:=1;
  While (K<=Length(S)) And IsDigit(S[K]) Do Inc(K);
  If (K>1) And (ValStr(Copy(S,1,K-1))=N) Then Begin EdRow:=I;EdCol:=1;Exit;End;
 End;
End;

Procedure EdDelLines;
Var A,B: LongInt; K,I,J: Integer; S: String; N: LongInt;
Begin
 FormLbl[1]:=T3('From line:','De la ligne:','Ab Zeile:');FormVal[1]:='';
 FormLbl[2]:=T3('To line:',''#133' la ligne:','Bis Zeile:');FormVal[2]:='';
 FormFW:=8;
 If Not FormBox(T3('Delete program lines','Supprimer des lignes','Programmzeilen loeschen'),2,'') Then Exit;
 A:=Round(ValStr(FormVal[1]));B:=Round(ValStr(FormVal[2]));
 If B=0 Then B:=A;
 DeleteLines(A,B);
 I:=1;
 While I<=EdN Do Begin
  S:=TrimStr(EdL[I]^);K:=1;N:=-1;
  While (K<=Length(S)) And IsDigit(S[K]) Do Inc(K);
  If K>1 Then N:=Round(ValStr(Copy(S,1,K-1)));
  If (N>=A) And (N<=B) And (EdN>1) Then Begin
   FreeStr(EdL[I]);
   For J:=I To EdN-1 Do Begin EdL[J]:=EdL[J+1];EdSt[J]:=EdSt[J+1];End;
   EdL[EdN]:=Nil;Dec(EdN);
  End Else Inc(I);
 End;
 If EdRow>EdN Then EdRow:=EdN;
End;

Procedure EdHelp;
Begin
 AlertBox('~HELP EDIT:|'+
  T3('Insert Space - F1','Ins'#130'rer espace - F1','Leerzeichen    - F1')+'|'+
  T3('Delete Char  - F2','Suppr. caract. - F2','Zeichen loesch. - F2')+'|'+
  T3('Insert Line  - F3','Ins'#130'rer ligne  - F3','Zeile einfuegen- F3')+'|'+
  T3('Delete Line  - F4','Suppr. ligne   - F4','Zeile loeschen - F4')+'|'+
  T3('Page Up      - F5','Page pr'#130'c.    - F5','Seite hoch      - F5')+'|'+
  T3('Page Down    - F6','Page suiv.     - F6','Seite runter    - F6')+'|'+
  T3('Load Text    - F7','Charger texte  - F7','Text laden      - F7')+'|'+
  T3('Save Text    - F8','Sauver texte   - F8','Text speichern  - F8')+'|'+
  T3('New Buffer   - F9','Nouveau tampon - F9','Neuer Puffer    - F9')+'|'+
  T3('Exit Edit    - F10','Quitter '#130'dit. - F10','Edit beenden   - F10'),'OK');
End;

Procedure EdKey(K: Word);
Var S: String; Rows: Integer;
Begin
 Rows:=WinRows(W_EDIT);
 If EdN<1 Then EdAppend('',0);
 Case K Of
  K_ENTER: EdCommit;
  K_UP: If EdRow>1 Then Dec(EdRow);
  K_DOWN: If EdRow<EdN Then Inc(EdRow);
  K_LEFT: If EdCol>1 Then Dec(EdCol);
  K_RIGHT: If EdCol<79 Then Inc(EdCol);
  K_HOME: EdCol:=1;
  K_END: EdCol:=Length(EdL[EdRow]^)+1;
  K_BKSP: If EdCol>1 Then Begin Dec(EdCol);EdDelChar;End;
  K_DEL,K_F2: EdDelChar;
  K_INS,K_F1: EdInsSpace;
  K_F3: EdInsLine;
  K_F4: EdRemLine;
  K_PGUP,K_F5: Begin EdRow:=EdRow-Rows;If EdRow<1 Then EdRow:=1;EdTop:=EdTop-Rows;End;
  K_PGDN,K_F6: Begin EdRow:=EdRow+Rows;If EdRow>EdN Then EdRow:=EdN;EdTop:=EdTop+Rows;End;
  K_F7: EdLoadText;
  K_F8: EdSaveText;
  K_F9: EdNewBuffer;
  K_F10: Begin ExitEdit;Exit;End;
  K_CTRLC: ;
 Else
  If (K>=32) And (K<256) Then Begin
   S:=EdL[EdRow]^;
   While Length(S)<EdCol-1 Do S:=S+' ';
   If EdCol<=Length(S) Then S[EdCol]:=Chr(K) Else S:=S+Chr(K);
   EdSetLine(EdRow,S);EdMark(EdRow);
   If EdCol<79 Then Inc(EdCol);
  End;
 End;
 If EditMode Then EdRefresh;
End;

{ ----------------------------------------------------------------------- }
{                    SURVEILLANCE PENDANT L'EXECUTION                      }
{ ----------------------------------------------------------------------- }

Procedure RunMenuInRun;
Var T: Integer;
Begin
 T:=TitleHit(MX,MY);
 If T=0 Then Exit;
 Dec(MouseLock);
 ShowMouse;
 RunMenu(T,True);
 HideMouse;
 Inc(MouseLock);
 MenuCool:=True;
End;

Procedure RunPoll;
Var OX,OY,OB: LongInt;
Begin
 If MouseLock>0 Then Begin
  OX:=MX;OY:=MY;
  GetMouseState(MX,MY,MB);
  If MY>=MENU_H Then MenuCool:=False;
  If (MY<MENU_H) And (Not MenuCool) And ((MX<>OX) Or (MY<>OY)) Then RunMenuInRun;
 End;
 If UIDirty And (NowCs-LastUICs>=12) Then Begin
  LastUICs:=NowCs;
  UIDirty:=False;
  DrawDesktop;
 End;
End;

Procedure StepWait(Ln: Integer; Pre: Char);
Var K: Integer; Done: Boolean; Cmd,Old: String;
Begin
 ConAdd(Pre+' '+LineStr(Ln));
 BringToFront(W_CMD);
 UIDirty:=False;
 ConFollow:=True;
 Old:=ConPrompt;ConPrompt:='Br ';InBuf:='';InPos:=0;
 DrawDesktop;
 Done:=False;Cmd:='';
 Repeat
  K:=GetKeyWait;
  If K=K_ENTER Then Begin
   Cmd:=Upper(TrimStr(InBuf));
   InBuf:='';InPos:=0;
   If Cmd='' Then Done:=True
   Else If Cmd='CONT' Then Begin StepMode:=False;Done:=True;End
   Else If (Cmd='END') Or (Cmd='STOP') Then Begin EndF:=True;StepMode:=False;Done:=True;End;
  End Else If (K=K_CTRLG) Or (K=K_CTRLC) Then Begin
   BreakReq:=True;StepMode:=False;Done:=True;
   If K=K_CTRLC Then LastRunMsg:='STOP';
  End Else If K=K_BKSP Then Begin
   If InPos>0 Then Begin Delete(InBuf,InPos,1);Dec(InPos);End;
  End Else If (K>=32) And (K<256) And (Length(InBuf)<40) Then Begin
   Insert(Chr(K),InBuf,InPos+1);Inc(InPos);
  End;
  If Not Done Then Begin
   ConFollow:=True;
   If (ZOrd[3]=W_CMD) Then Begin HideMouse;RedrawContent(W_CMD);End;
  End;
 Until Done Or QuitReq;
 ConPrompt:=Old;InBuf:='';InPos:=0;
End;

{ ----------------------------------------------------------------------- }
{                            ACTIONS DES MENUS                             }
{ ----------------------------------------------------------------------- }

Procedure DirectCmd(Const S: String);
Begin
 ConAdd(ConPrompt+S);
 ExecDirect(S);
 If EditReq Then Begin EditReq:=False;StartEdit;End;
 SetPrompt;
 ConFollow:=True;
 NeedDraw:=True;
End;

Procedure About;
Begin
 AlertBox('Atari ST Basic|Version clone de 1985|'+
  '|'+T3('(clone by Sylvain Maltais, 2026)',
  '(clone de Sylvain Maltais, 2026)',
  '(Klon von Sylvain Maltais, 2026)'),'OK');
End;

Procedure TraceDlg(Kind: Integer);
{ Kind : 1 Tron, 2 Troff, 3 Trace, 4 Untrace }
Var Cmd,Ti: String;
Begin
 FormLbl[1]:=T3('Lines Entered','Lignes saisies','Eingegebene Zeilen');FormVal[1]:='';FormFW:=24;
 Case Kind Of
  1: Begin Cmd:='TRON';Ti:='TRON:';End;
  2: Begin Cmd:='TROFF';Ti:='TROFF:';End;
  3: Begin Cmd:='TRACE';Ti:='TRACE:';End;
 Else Begin Cmd:='UNTRACE';Ti:='UNTRACE:';End;
 End;
 If Kind In [1,3] Then
  Ti:=Ti+T3('  Debugging on lines...','  D'#130'bogage sur les lignes...','  Debugging der Zeilen...')
 Else Ti:=Ti+T3('  Disable on lines...','  D'#130'sactiver sur les lignes...','  Abschalten fuer Zeilen...');
 If FormBox(Ti,1,'') Then DirectCmd(Cmd+' '+FormVal[1]);
End;

Procedure DoMenu(M,I: Integer);
Var Sel: String; R: Integer;
Begin
 Case M Of
  1: If I=1 Then About;
  2: Case I Of
      1: Begin
          Sel:='';
          If FileSelect('Load','*.BAS',Sel) Then DirectCmd('LOAD "'+Sel+'"');
         End;
      2: Begin
          Sel:=ShortName(ProgName);
          If FileSelect('Save As','*.BAS',Sel) Then DirectCmd('REPLACE "'+Sel+'"');
         End;
      3: Begin
          Sel:='';
          If FileSelect('Delete File','*.*',Sel) Then Begin
           If AlertBox(Sel+'|'+T3('will be deleted.','sera supprim'#130'.','wird geloescht.'),
              'OK|'+T3('Cancel','Annuler','Abbruch'))=1 Then DirectCmd('ERA "'+Sel+'"');
          End;
         End;
      4: Begin
          Sel:='';
          If FileSelect('Merge','*.BAS',Sel) Then DirectCmd('MERGE "'+Sel+'"');
         End;
      5: QuitReq:=True;
     End;
  3: Case I Of
      1: DirectCmd('RUN');
      2: If RunningProg Then BreakReq:=True
         Else If EditMode Then Begin ExitEdit;ConAdd(ConPrompt);End;
      3: If BrokenProg Then DirectCmd('STOP');
      4: If CanCont Then DirectCmd('CONT');
      5: Begin
          R:=AlertBox(T3('Hit <RET> to Execute','Appuyez sur <RET> pour ex'#130'cuter',
             '<RET> druecken zum Ausfuehren')+'|'+T3('each line.','chaque ligne.','jeder Zeile.'),'OK');
          DirectCmd('STEP');
         End;
      6: Begin
          If AlertBox(T3('NEW operation will','L''op'#130'ration NEW sera',
             'Die Operation NEW wird')+'|'+
             T3('be executed.','ex'#130'cut'#130'e.','ausgefuehrt.'),
             'OK|'+T3('Cancel','Annuler','Abbruch'))=1 Then Begin
           BufGfx:=Not BufGfx;
           DirectCmd('NEW');
          End;
         End;
     End;
  4: Case I Of
      1: StartEdit;
      2: ExitEdit;
      3: EdHelp;
      4: If EditMode Then Begin EdGoto;EdRefresh;End;
      5: If EditMode Then Begin EdDelLines;EdRefresh;End;
      6: If EditMode Then Begin EdInsSpace;EdRefresh;End;
      7: If EditMode Then Begin EdDelChar;EdRefresh;End;
      8: If EditMode Then Begin EdInsLine;EdRefresh;End;
      9: If EditMode Then Begin EdRemLine;EdRefresh;End;
      10: If EditMode Then Begin EdKey(K_F5);End;
      11: If EditMode Then Begin EdKey(K_F6);End;
      12: If EditMode Then Begin EdLoadText;EdRefresh;End;
      13: If EditMode Then EdSaveText;
      14: If EditMode Then Begin EdNewBuffer;EdRefresh;End;
      15: DirectCmd('LIST');
     End;
  5: TraceDlg(I);
 End;
 NeedDraw:=True;
End;

{ ----------------------------------------------------------------------- }
{                  SOURIS : MANIPULATION DES FENETRES                      }
{ ----------------------------------------------------------------------- }

Procedure XorRect(X1,Y1,X2,Y2: Integer);
Begin
 SetWriteMode(XORPut);
 SetColor(PAPER);
 SetLineStyle(SolidLn,0,1);
 Rectangle(X1,Y1,X2,Y2);
 Rectangle(X1+1,Y1+1,X2-1,Y2-1);
 SetWriteMode(NormalPut);
End;

Procedure DragWin(N: Integer; MX0,MY0: LongInt);
Var E: TEvent; NX,NY,OX,OY: Integer; Done: Boolean;
Begin
 HideMouse;
 OX:=Win[N].X;OY:=Win[N].Y;NX:=OX;NY:=OY;
 XorRect(NX,NY,NX+Win[N].W-1,NY+Win[N].H-1);
 Done:=False;
 Repeat
  PollEvent(E);
  If (E.Kind=4) Or (E.Kind=3) Then Begin
   XorRect(NX,NY,NX+Win[N].W-1,NY+Win[N].H-1);
   NX:=OX+(E.X-MX0);NY:=OY+(E.Y-MY0);
   If NY<MENU_H Then NY:=MENU_H;
   If NY>SCR_H-24 Then NY:=SCR_H-24;
   If NX<-Win[N].W+40 Then NX:=-Win[N].W+40;
   If NX>SCR_W-40 Then NX:=SCR_W-40;
   XorRect(NX,NY,NX+Win[N].W-1,NY+Win[N].H-1);
   If E.Kind=3 Then Done:=True;
  End;
 Until Done;
 XorRect(NX,NY,NX+Win[N].W-1,NY+Win[N].H-1);
 Win[N].X:=NX;Win[N].Y:=NY;
 Win[N].Full:=False;
 ShowMouse;
 DrawDesktop;
End;

Procedure SizeWin(N: Integer; MX0,MY0: LongInt);
Var E: TEvent; NW,NH,OW,OH: Integer; Done: Boolean;
Begin
 HideMouse;
 OW:=Win[N].W;OH:=Win[N].H;NW:=OW;NH:=OH;
 XorRect(Win[N].X,Win[N].Y,Win[N].X+NW-1,Win[N].Y+NH-1);
 Done:=False;
 Repeat
  PollEvent(E);
  If (E.Kind=4) Or (E.Kind=3) Then Begin
   XorRect(Win[N].X,Win[N].Y,Win[N].X+NW-1,Win[N].Y+NH-1);
   NW:=OW+(E.X-MX0);NH:=OH+(E.Y-MY0);
   If NW<120 Then NW:=120;
   If NH<80 Then NH:=80;
   If Win[N].X+NW>SCR_W Then NW:=SCR_W-Win[N].X;
   If Win[N].Y+NH>SCR_H Then NH:=SCR_H-Win[N].Y;
   XorRect(Win[N].X,Win[N].Y,Win[N].X+NW-1,Win[N].Y+NH-1);
   If E.Kind=3 Then Done:=True;
  End;
 Until Done;
 XorRect(Win[N].X,Win[N].Y,Win[N].X+NW-1,Win[N].Y+NH-1);
 Win[N].W:=NW;Win[N].H:=NH;
 Win[N].NW:=NW;Win[N].NH:=NH;Win[N].NX:=Win[N].X;Win[N].NY:=Win[N].Y;
 Win[N].Full:=False;
 ShowMouse;
 DrawDesktop;
End;

Procedure ThumbDrag(N: Integer; Vert: Boolean);
Var E: TEvent; VT,VV,VP,HT,HV,HP: LongInt; X1,Y1,X2,Y2: Integer; TL,Pos: LongInt; Done: Boolean;
Begin
 Done:=False;
 Repeat
  PollEvent(E);
  If (E.Kind=4) Or (E.Kind=3) Then Begin
   ScrollInfo(N,VT,VV,VP,HT,HV,HP);
   If Vert Then Begin
    TL:=Win[N].H-TITLE_H-2-SB*3-2;
    If TL<1 Then TL:=1;
    Pos:=(E.Y-(Win[N].Y+TITLE_H+SB))*(VT-VV) Div TL;
    SetScroll(N,Pos,HP);
   End Else Begin
    TL:=Win[N].W-2-SB*3-2;
    If TL<1 Then TL:=1;
    Pos:=(E.X-(Win[N].X+1+SB))*(HT-HV) Div TL;
    SetScroll(N,VP,Pos);
   End;
   If E.Kind=3 Then Done:=True;
  End;
 Until Done;
End;

Procedure WinClick(N: Integer; E: TEvent);
Var VT,VV,VP,HT,HV,HP: LongInt; BX,BY,X1,Y1,X2,Y2: Integer; Rel: LongInt; I: Integer; S: String;
Begin
 BX:=Win[N].X+Win[N].W-1-SB;
 BY:=Win[N].Y+Win[N].H-1-SB;
 { case de fermeture }
 If InBox(E.X,E.Y,Win[N].X+1,Win[N].Y+1,Win[N].X+SB,Win[N].Y+TITLE_H-2) Then Begin
  If N=W_EDIT Then ExitEdit
  Else If N<>W_CMD Then Begin Win[N].Open:=False;BringToFront(W_CMD);End;
  NeedDraw:=True;Exit;
 End;
 { case de plein ecran }
 If InBox(E.X,E.Y,Win[N].X+Win[N].W-SB-1,Win[N].Y+1,Win[N].X+Win[N].W-2,Win[N].Y+TITLE_H-2) Then Begin
  ToggleFull(N);NeedDraw:=True;Exit;
 End;
 { barre de titre : deplacement }
 If InBox(E.X,E.Y,Win[N].X,Win[N].Y,Win[N].X+Win[N].W-1,Win[N].Y+TITLE_H-1) Then Begin
  DragWin(N,E.X,E.Y);Exit;
 End;
 { boite de taille }
 If InBox(E.X,E.Y,BX,BY,BX+SB,BY+SB) Then Begin
  If Not Win[N].Full Then SizeWin(N,E.X,E.Y);Exit;
 End;
 ScrollInfo(N,VT,VV,VP,HT,HV,HP);
 { barre verticale }
 If InBox(E.X,E.Y,BX,Win[N].Y+TITLE_H,BX+SB,BY-1) Then Begin
  If E.Y<Win[N].Y+TITLE_H+SB Then SetScroll(N,VP-1,HP)
  Else If E.Y>BY-SB Then SetScroll(N,VP+1,HP)
  Else Begin
   Rel:=E.Y-(Win[N].Y+TITLE_H+SB);
   If (VT>VV) Then Begin
    If Rel*(VT-VV) Div (BY-SB-(Win[N].Y+TITLE_H+SB)-1) < VP Then SetScroll(N,VP-VV,HP)
    Else SetScroll(N,VP+VV,HP);
   End;
  End;
  Exit;
 End;
 { barre horizontale }
 If InBox(E.X,E.Y,Win[N].X+1,BY,BX-1,BY+SB) Then Begin
  If E.X<Win[N].X+1+SB Then SetScroll(N,VP,HP-1)
  Else If E.X>BX-SB Then SetScroll(N,VP,HP+1)
  Else Begin
   Rel:=E.X-(Win[N].X+1+SB);
   If (HT>HV) Then Begin
    If Rel*(HT-HV) Div (BX-SB-(Win[N].X+1+SB)-1) < HP Then SetScroll(N,VP,HP-HV)
    Else SetScroll(N,VP,HP+HV);
   End;
  End;
  Exit;
 End;
 { zone client }
 WinClient(N,X1,Y1,X2,Y2);
 If (N=W_EDIT) And EditMode And InBox(E.X,E.Y,X1,Y1,X2,Y2) Then Begin
  I:=EdTop+(E.Y-Y1) Div 16;
  If (I>=1) And (I<=EdN) Then Begin EdRow:=I;EdCol:=Win[W_EDIT].ScrX+(E.X-X1) Div 8+1;EdRefresh;End;
 End;
End;

Procedure MouseDown(E: TEvent);
Var I,N: Integer; BX,BY: Integer;
Begin
 If E.Y<MENU_H Then Begin
  I:=TitleHit(E.X,E.Y);
  If I>0 Then RunMenu(I,True);
  Exit;
 End;
 N:=-1;
 For I:=3 DownTo 0 Do
  If (N<0) And Win[ZOrd[I]].Open Then
   If InBox(E.X,E.Y,Win[ZOrd[I]].X,Win[ZOrd[I]].Y,Win[ZOrd[I]].X+Win[ZOrd[I]].W-1,
            Win[ZOrd[I]].Y+Win[ZOrd[I]].H-1) Then N:=ZOrd[I];
 If N<0 Then Exit;
 If N<>ZOrd[3] Then Begin
  BringToFront(N);
  DrawDesktop;
  { un clic sur les poignees agit aussi }
  If InBox(E.X,E.Y,Win[N].X,Win[N].Y,Win[N].X+Win[N].W-1,Win[N].Y+TITLE_H-1) Then WinClick(N,E);
  Exit;
 End;
 WinClick(N,E);
End;

{ ----------------------------------------------------------------------- }
{                  VERIFICATION DE SYNTAXE ("COMPILATION")                  }
{ ----------------------------------------------------------------------- }

Const
 NSTMT = 81;
 StmtWords : Array[1..NSTMT] Of String[9] = (
  'PRINT','IF','FOR','NEXT','GOTO','GOSUB','RETURN','WHILE','WEND','LET','REM','DATA',
  'END','STOP','INPUT','LINE','READ','RESTORE','DIM','ON','DEF','SWAP','CLEARW','FULLW',
  'OPENW','CLOSEW','COLOR','FILL','LINEF','CIRCLE','PCIRCLE','ELLIPSE','PELLIPSE',
  'GOTOXY','SOUND','WAVE','DEFINT','DEFSNG','DEFDBL','DEFSTR','OPTION','CLEAR','ERASE',
  'RANDOMIZE','OPEN','CLOSE','WRITE','FIELD','LSET','RSET','GET','PUT','LPRINT','POKE',
  'CALL','BLOAD','BSAVE','CHAIN','COMMON','RESUME','ERROR','KILL','ERA','NAME','WIDTH',
  'FOLLOW','UNFOLLOW','BREAK','UNBREAK','GEMSYS','VDISYS','SYSDBG','OUT','WAIT','RESET',
  'BEEP','TRON','TROFF','TRACE','UNTRACE','ELSE');

Function CheckProgram: Integer;
Var I,Q,K,Errs,Depth: Integer; T,W,Prev: String; InQ: Boolean; Par: Integer;
    Fors,Whiles: Integer; StmtStartQ: Boolean; N: Real; J: Integer; Ok: Boolean;
    Known: Boolean;
 Procedure Bad(Const M: String);
 Begin
  ConAdd(T3('Line ','Ligne ','Zeile ')+IntStr(LNum[I])+': '+M);
  Inc(Errs);
 End;
 Function TargetOk(Var Pos: Integer): Boolean;
 Var W2: String; N2: LongInt; Pos0: Integer;
 Begin
  TargetOk:=True;
  While (Pos<=Length(T)) And (T[Pos]=' ') Do Inc(Pos);
  If (Pos<=Length(T)) And IsDigit(T[Pos]) Then Begin
   N2:=0;
   While (Pos<=Length(T)) And IsDigit(T[Pos]) Do Begin
    If N2<70000 Then N2:=N2*10+Ord(T[Pos])-48;
    Inc(Pos);
   End;
   If LineIdxExact(N2)=0 Then Begin TargetOk:=False;Bad(ErrText(8)+' '+IntStr(N2));End;
  End Else If (Pos<=Length(T)) And IsAlpha(T[Pos]) Then Begin
   W2:='';Pos0:=Pos;
   While (Pos<=Length(T)) And IsIdCh(T[Pos]) Do Begin W2:=W2+UpCase(T[Pos]);Inc(Pos);End;
   If (Pos<=Length(T)) And ((T[Pos]='$') Or (T[Pos]='%') Or (T[Pos]='!')) Then Inc(Pos);
   If IsReserved(W2) Then Pos:=Pos0
   Else If FindLabel(W2)=0 Then Begin TargetOk:=False;Bad(ErrText(8)+' '+W2);End;
  End;
 End;
Begin
 Errs:=0;FORS:=0;Whiles:=0;
 If LabDirty Then BuildLabels;
 For I:=1 To LCnt Do Begin
  T:=LTxt[I]^;
  Q:=1;InQ:=False;Par:=0;StmtStartQ:=True;
  While Q<=Length(T) Do Begin
   If T[Q]='"' Then Begin InQ:=Not InQ;Inc(Q);StmtStartQ:=False;End
   Else If InQ Then Inc(Q)
   Else If T[Q]='''' Then Q:=Length(T)+1
   Else If T[Q]=':' Then Begin StmtStartQ:=True;Inc(Q);End
   Else If T[Q]='(' Then Begin Inc(Par);Inc(Q);StmtStartQ:=False;End
   Else If T[Q]=')' Then Begin Dec(Par);Inc(Q);StmtStartQ:=False;
    If Par<0 Then Begin Bad(ErrText(2));Par:=0;End;End
   Else If IsAlpha(T[Q]) Then Begin
    W:='';K:=Q;
    While (K<=Length(T)) And IsIdCh(T[K]) Do Begin W:=W+UpCase(T[K]);Inc(K);End;
    If (K<=Length(T)) And ((T[K]='$') Or (T[K]='%') Or (T[K]='!')) Then Begin W:=W+T[K];Inc(K);End;
    If StmtStartQ Then Begin
     Known:=False;
     J:=K;
     While (J<=Length(T)) And (T[J]=' ') Do Inc(J);
     If (J<=Length(T)) And (T[J]=':') And (Not IsReserved(W)) Then Known:=True
     Else If (J<=Length(T)) And ((T[J]='=') Or (T[J]='(')) And (Not IsReserved(W)) Then Known:=True
     Else If W='MID$' Then Known:=True
     Else Begin
      For J:=1 To NSTMT Do If StmtWords[J]=W Then Known:=True;
      If (W='CLEAR') Or (W='NEW') Or (W='LIST') Or (W='LLIST') Or (W='RUN') Or (W='SAVE')
         Or (W='LOAD') Or (W='MERGE') Or (W='DIR') Or (W='FILES') Or (W='CONT') Or (W='SYSTEM')
         Or (W='QUIT') Or (W='EDIT') Or (W='STEP') Or (W='RENUM') Or (W='DELETE') Or
         (W='AUTO') Or (W='REPLACE') Or (W='OLD') Or (W='ED') Or (W='LLIST') Then Known:=True;
     End;
     If Not Known Then Bad(ErrText(2)+': '+W);
     StmtStartQ:=False;
    End;
    If W='FOR' Then Inc(FORS) Else If W='NEXT' Then Dec(FORS);
    If W='WHILE' Then Inc(Whiles) Else If W='WEND' Then Dec(Whiles);
    If W='REM' Then K:=Length(T)+1;
    If (W='GOTO') Or (W='GOSUB') Or (W='THEN') Or (W='ELSE') Or (W='RESTORE') Then Begin
     Ok:=TargetOk(K);
     While (K<=Length(T)) And (T[K]=',') And ((W='GOTO') Or (W='GOSUB')) Do Begin
      Inc(K);Ok:=TargetOk(K);
     End;
    End;
    If W='DATA' Then Begin
     While (K<=Length(T)) And (T[K]<>':') Do Inc(K);
     StmtStartQ:=False;
    End;
    Q:=K;
   End Else Begin
    If T[Q]<>' ' Then StmtStartQ:=False;
    Inc(Q);
   End;
  End;
  If InQ Then Bad(ErrText(2)+' ("")');
  If Par<>0 Then Bad(ErrText(2)+' ()');
 End;
 If FORS>0 Then Begin ConAdd(ErrText(204));Inc(Errs);End;
 If FORS<0 Then Begin ConAdd(ErrText(205));Inc(Errs);End;
 If Whiles>0 Then Begin ConAdd(ErrText(204));Inc(Errs);End;
 If Whiles<0 Then Begin ConAdd(ErrText(205));Inc(Errs);End;
 CheckProgram:=Errs;
End;

{ ----------------------------------------------------------------------- }
{                  AIDE EN LIGNE DE COMMANDE ET INITIALISATION              }
{ ----------------------------------------------------------------------- }

Procedure ShowHelpLine;
Var H: Text;
Begin
 Assign(H,'');Rewrite(H);
 If Lang=0 Then Begin
  WriteLn(H,'STBASIC - Graphical clone of the Atari ST BASIC desktop and interpreter.');
  WriteLn(H);
  WriteLn(H,'Usage : STBASIC [file.BAS ...] [/E] [/R] [/C] [/X file.PRG] [/Q] [/?]');
  WriteLn(H);
  WriteLn(H,'  file.BAS   Program to load (the following ones are merged, like MERGE).');
  WriteLn(H,'  /E         Open the program in the editor (Start Edit) immediately.');
  WriteLn(H,'  /R         Run the program immediately (RUN).');
  WriteLn(H,'  /C         "Compile": check the syntax, GOTO/GOSUB targets and FOR/WHILE');
  WriteLn(H,'             nesting of the program; the program is run only when it is clean');
  WriteLn(H,'             and /R is also given.');
  WriteLn(H,'  /X file    Run an Atari ST program (.PRG) in the integrated 68000 emulator.');
  WriteLn(H,'  /Q         Quit when the /R, /C or /X work is finished.');
  WriteLn(H,'  /?         Show this help.');
  WriteLn(H);
  WriteLn(H,'In the desktop : Control+G breaks a program, Control+C stops it, the');
  WriteLn(H,'menus open when the mouse points to their title (Desk File Run Edit Debug).');
  WriteLn(H);
  WriteLn(H,'Language : French by default, LANGUAGE=EN for English,');
  WriteLn(H,'LANGUAGE=GR for German.');
 End Else If Lang=2 Then Begin
  WriteLn(H,'STBASIC - Grafischer Klon der Atari ST BASIC Oberflaeche und des Interpreters.');
  WriteLn(H);
  WriteLn(H,'Aufruf : STBASIC [Datei.BAS ...] [/E] [/R] [/C] [/X Datei.PRG] [/Q] [/?]');
  WriteLn(H);
  WriteLn(H,'  Datei.BAS  Zu ladendes Programm (weitere werden wie MERGE angefuegt).');
  WriteLn(H,'  /E         Programm sofort im Editor oeffnen.');
  WriteLn(H,'  /R         Programm sofort starten (RUN).');
  WriteLn(H,'  /C         "Kompilieren": Syntax, Sprungziele und FOR/WHILE pruefen;');
  WriteLn(H,'             gestartet wird nur bei /R und fehlerfreiem Programm.');
  WriteLn(H,'  /X Datei   Atari ST Programm (.PRG) im 68000 Emulator ausfuehren.');
  WriteLn(H,'  /Q         Nach /R, /C oder /X beenden.');
  WriteLn(H,'  /?         Diese Hilfe anzeigen.');
  WriteLn(H);
  WriteLn(H,'Sprache : Franz'#148'sisch als Standard, LANGUAGE=EN f'#129'r Englisch,');
  WriteLn(H,'LANGUAGE=GR f'#129'r Deutsch.');
 End Else Begin
  WriteLn(H,'STBASIC - Cette commande permet de lancer le clone graphique du bureau et de');
  WriteLn(H,'l''interpr'#130'teur Atari ST BASIC.');
  WriteLn(H);
  WriteLn(H,'Syntaxe : STBASIC [fichier.BAS ...] [/E] [/R] [/C] [/X fichier.PRG] [/Q] [/?]');
  WriteLn(H);
  WriteLn(H,'  fichier.BAS  Programme '#133' charger (les suivants sont fusionn'#130's, comme MERGE).');
  WriteLn(H,'  /E           Ouvre imm'#130'diatement le programme dans l'#39#130'diteur (Start Edit).');
  WriteLn(H,'  /R           Ex'#130'cute imm'#130'diatement le programme (RUN).');
  WriteLn(H,'  /C           "Compile" : v'#130'rifie la syntaxe, les cibles GOTO/GOSUB et');
  WriteLn(H,'               l''imbrication FOR/WHILE; le programme n''est ex'#130'cut'#130' que s''il');
  WriteLn(H,'               est correct et que /R est aussi donn'#130'.');
  WriteLn(H,'  /X fichier   Ex'#130'cute un programme Atari ST (.PRG) dans l'#39#130'mulateur 68000 int'#130'gr'#130'.');
  WriteLn(H,'  /Q           Quitte quand le travail de /R, /C ou /X est termin'#130'.');
  WriteLn(H,'  /?           Affiche cette aide.');
  WriteLn(H);
  WriteLn(H,'Dans le bureau : Control+G interrompt un programme, Control+C l''arr'#136'te,');
  WriteLn(H,'les menus s''ouvrent quand la souris pointe leur titre (Desk File Run Edit Debug).');
  WriteLn(H);
  WriteLn(H,'Langue : fran'#135'ais par d'#130'faut, LANGUAGE=EN pour l''anglais,');
  WriteLn(H,'LANGUAGE=GR pour l''allemand.');
 End;
 Close(H);
End;

Procedure InitData;
Var S: String; I: Integer;
Begin
 S:=Upper(Copy(GetEnv('LANGUAGE'),1,2));
 If S='EN' Then Lang:=0
 Else If (S='GR') Or (S='DE') Then Lang:=2
 Else Lang:=1;
 FillChar(HashT,SizeOf(HashT),0);
 FillChar(DefTyp,SizeOf(DefTyp),0);
 FillChar(FT,SizeOf(FT),0);
 For I:=1 To MAXCON Do ConL[I]:=Nil;
 For I:=1 To MAXLST Do LstL[I]:=Nil;
 For I:=1 To MAXL Do LTxt[I]:=Nil;
 For I:=1 To MAXED Do EdL[I]:=Nil;
 For I:=1 To 20 Do FnBody[I]:=Nil;
 ConN:=0;LstN:=0;LCnt:=0;EdN:=0;FnCnt:=0;
 LstName:='';ProgName:='';
 OptBase:=0;
 NeedDraw:=True;EditMode:=False;BufGfx:=True;
 RunningProg:=False;BrokenProg:=False;CanCont:=False;
 MenuOpen:=0;MenuHi:=0;MenuSaved:=False;MouseLock:=0;MenuCool:=False;
 MX:=0;MY:=0;MB:=0;LastB:=0;
 {$IFDEF FPC}
 CurSaved:=False;CurShown:=False;
 {$ENDIF}
 ConPrompt:='Ok ';InBuf:='';InPos:=0;ConFollow:=True;ConTop:=1;
 HistN:=0;HistI:=1;
 QuitReq:=False;EditReq:=False;AutoOn:=False;
 StepMode:=False;TronOn:=False;TraceOn:=False;TrLo:=0;TrHi:=65535;
 AutoStep:=10;
 ErrCode:=0;ErrNum:=0;ErrLNum:=0;InErrH:=False;BreakReq:=False;
 KeyQ:='';ChainKeepN:=0;UIDirty:=False;LastUICs:=0;
 Running:=False;PrnOpen:=False;
 LabDirty:=True;LabN:=0;
 ResetRunState;
 RndLast:=0;
 PrnWidth:=72;EditLineReq:=0;
 FillChar(TronSet,SizeOf(TronSet),0);
 FillChar(TraceSet,SizeOf(TraceSet),0);
 FillChar(BreakSet,SizeOf(BreakSet),0);
 BreakOn:=False;StopMsg:=False;GfxSaved:=False;FollowN:=0;LastLn:=0;
 InitBasMem;
End;

Var
 CmdE,CmdR,CmdC,CmdQ : Boolean;
 CmdX : String;
 CmdFiles : Array[1..8] Of String[100];
 CmdNF : Integer;

Procedure ParseCommandLine;
Var I: Integer; A,U: String;
Begin
 CmdE:=False;CmdR:=False;CmdC:=False;CmdQ:=False;CmdX:='';CmdNF:=0;
 I:=1;
 While I<=ParamCount Do Begin
  A:=ParamStr(I);U:=Upper(A);
  If (Length(U)>=2) And ((U[1]='/') Or (U[1]='-')) And (Not ((U[1]='/') And (Pos('.',U)>0)))
     And (Not (Pos('/',Copy(U,2,255))>0)) Then Begin
   Case U[2] Of
    'E': Begin CmdE:=True;
          If Length(A)>2 Then Begin Inc(CmdNF);If CmdNF<=8 Then CmdFiles[CmdNF]:=Copy(A,3,100);End;
         End;
    'R': CmdR:=True;
    'C': CmdC:=True;
    'Q': CmdQ:=True;
    'X': Begin
          If Length(A)>2 Then CmdX:=Copy(A,3,100)
          Else If I<ParamCount Then Begin Inc(I);CmdX:=ParamStr(I);End;
         End;
   End;
  End Else Begin
   Inc(CmdNF);
   If CmdNF<=8 Then CmdFiles[CmdNF]:=A;
  End;
  Inc(I);
 End;
End;

Procedure ApplyCommandLine;
Var I: Integer; Errs: Integer; Merge: Boolean;
Begin
 For I:=1 To CmdNF Do Begin
  If Pos('.PRG',Upper(CmdFiles[I]))>0 Then CmdX:=CmdFiles[I]
  Else Begin
   If Not LoadProgFile(AddExt(CmdFiles[I],'BAS'),I>1) Then Begin
    ShowRunError(0);ErrCode:=0;
   End;
  End;
 End;
 If CmdC Then Begin
  Errs:=CheckProgram;
  ConAdd(IntStr(Errs)+T3(' error(s) found.',' erreur(s) trouv'#130'e(s).',' Fehler gefunden.'));
  If (Errs>0) Then CmdR:=False;
 End;
 DrawDesktop;
 If CmdX<>'' Then Begin
  If Not EmuRunPRG(CmdX) Then Begin
   ConAdd(CmdX+': '+ErrText(53));
  End;
  DrawDesktop;
 End;
 If CmdE Then Begin StartEdit;DrawDesktop;End;
 If CmdR And (LCnt>0) Then Begin
  ClearVars;ResetRunState;
  RunFrom(1,1);
 End;
 If CmdQ Then QuitReq:=True;
End;

Procedure MainLoop;
Var E: TEvent; T: Integer;
Begin
 Repeat
  If (Not AutoOn) And (Not RunningProg) Then Begin
   If CanCont Or BrokenProg Then ConPrompt:='Br ' Else ConPrompt:='Ok ';
  End;
  If NeedDraw Or UIDirty Then Begin NeedDraw:=False;UIDirty:=False;DrawDesktop;End;
  PollEvent(E);
  Case E.Kind Of
   1: Begin
       If EditMode And (ZOrd[3]=W_EDIT) Then EdKey(E.Key)
       Else Begin
        If EditMode And (E.Key<>K_ENTER) And (ZOrd[3]<>W_EDIT) And (E.Key<>K_F10) Then Begin
         BringToFront(W_EDIT);NeedDraw:=True;
        End;
        If EditMode Then EdKey(E.Key) Else CmdKey(E.Key);
       End;
      End;
   2: MouseDown(E);
   4: Begin
       If E.Y>=MENU_H Then MenuCool:=False
       Else If Not MenuCool Then Begin
        T:=TitleHit(E.X,E.Y);
        If T>0 Then Begin RunMenu(T,True);MenuCool:=True;End;
       End;
      End;
  End;
  If EditReq Then Begin EditReq:=False;StartEdit;End;
 Until QuitReq;
End;

BEGIN
 If (ParamCount>=1) And ((ParamStr(1)='/?') Or (ParamStr(1)='-h') Or (ParamStr(1)='-?')
     Or (ParamStr(1)='--help') Or (ParamStr(1)='-H')) Then Begin
  Lang:=1;
  If Upper(Copy(GetEnv('LANGUAGE'),1,2))='EN' Then Lang:=0;
  If (Upper(Copy(GetEnv('LANGUAGE'),1,2))='GR') Or
     (Upper(Copy(GetEnv('LANGUAGE'),1,2))='DE') Then Lang:=2;
  ShowHelpLine;
  Halt(0);
 End;
 InitData;
 ParseCommandLine;
 InitializeGraphics;
 BuildFont;
 If MouseDriverFound Then ShowMouse;
 InitWindows;
 OutInitBuf;
 OutUpdateLive;
 DrawDesktop;
 If Not (CmdR Or CmdC Or (CmdX<>'')) Then About;
 ApplyCommandLine;
 If Not QuitReq Then Begin
  NeedDraw:=True;
  MainLoop;
 End;
 NoSound;
 CloseAllFiles;
 HideMouse;
 CloseGraph;
END.
