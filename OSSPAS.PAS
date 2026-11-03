{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2
  @description: Clone de l'application OSS Personal Pascal (OSSPAS.PAS)

  Compilateur Pascal (dialecte Personal Pascal 2.05) generant du code 68000
  natif (fichiers .O puis programmes .PRG GEMDOS), editeur de liens, editeur
  plein ecran et emulateur Atari ST (68000 + TOS) integre pour executer les
  programmes. Aucun fichier d'inclusion ni appel EXEC externe : tout le code
  est contenu dans ce fichier.

  Langue : variable d'environnement LANGUAGE=EN (anglais), LANGUAGE=GR
  (allemand), sinon francais.
}

Program OSSPersonalPascal;

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
 VERSION_TEXT = '2.05';
 CLONE_VERSION = '1.00';
 SCR_W        = 640;
 SCR_H        = 480;
 MENU_H       = 18;
 TITLE_H      = 18;
 SB           = 16;        { largeur des barres de defilement }
 INK          = 0;
 PAPER        = 15;

 { Ecran de l'Atari ST (haute resolution monochrome) }
 OUT_W     = 640;
 OUT_H     = 400;
 OUT_RB    = 80;            { octets par ligne }
 OUT_BYTES = 32000;
 OUT_COLS  = 80;
 OUT_ROWS  = 24;
 OFS_Y     = 40;            { decalage vertical de l'ecran ST }

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
 K_ENDKEY= 335;
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
 K_SF1    = 340;
 K_SF2    = 341;
 K_SF3    = 342;
 K_SF4    = 343;
 K_CTRLC  = 3;
 K_CTRLG  = 7;
 K_CTRLN  = 14;
 K_CTRLL  = 12;

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

 PByteArr = ^TByteArr;
 TByteArr = Array[0..32000] Of Byte;

{ ====================================================================== }
{                       LANGUE / UTILITAIRES                             }
{ ====================================================================== }

Var
 Lang     : Integer;       { 0 anglais, 1 francais, 2 allemand }
 Headless : Boolean;       { mode sans interface graphique (batch) }
 BreakReq : Boolean;       { Ctrl+C ou Ctrl+G demande }
 QuitReq  : Boolean;
 KeyQ     : String;        { file d'attente du clavier }
 LastRunMsg : String;

Procedure InitLanguage;
Var S: String; I: Integer;
Begin
 S:=GetEnv('LANGUAGE');
 For I:=1 To Length(S) Do S[I]:=UpCase(S[I]);
 Lang:=1;
 If (S='EN') Or (Copy(S,1,3)='ENG') Then Lang:=0
 Else If (S='GR') Or (S='DE') Or (Copy(S,1,3)='GER') Or (Copy(S,1,3)='DEU') Then Lang:=2;
End;

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
Var
 CurKind,CurHx,CurHy : Integer;
 CurMask,CurData : Array[0..15] Of Word;

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
 Var Pt: Array[1..7] Of PointType; I,J: Integer; BX,BY: LongInt;
 Begin
  If X>SCR_W-20 Then X:=SCR_W-20;
  If Y>SCR_H-20 Then Y:=SCR_H-20;
  If X<0 Then X:=0;
  If Y<0 Then Y:=0;
  CursorErase;
  BX:=X-CurHx;BY:=Y-CurHy;
  If BX<0 Then BX:=0;
  If BY<0 Then BY:=0;
  CurSz:=ImageSize(BX,BY,BX+19,BY+19);
  GetMem(CurBuf,CurSz);
  GetImage(BX,BY,BX+19,BY+19,CurBuf^);
  CurX:=BX;CurY:=BY;CurSaved:=True;
  Case CurKind Of
   1: For J:=0 To 15 Do For I:=0 To 15 Do Begin
       If (CurMask[J] And ($8000 Shr I))<>0 Then PutPixel(BX+I,BY+J,15);
       If (CurData[J] And ($8000 Shr I))<>0 Then PutPixel(BX+I,BY+J,0);
      End;
   2: Begin
       SetColor(0);
       Line(BX+8,BY+2,BX+8,BY+16);Line(BX+5,BY+2,BX+11,BY+2);Line(BX+5,BY+16,BX+11,BY+16);
      End;
   3: Begin
       SetColor(0);
       Line(BX+8,BY+1,BX+8,BY+17);Line(BX+1,BY+9,BX+15,BY+9);
      End;
   4: Begin
       SetColor(0);
       Rectangle(BX+3,BY+1,BX+13,BY+17);Line(BX+3,BY+1,BX+13,BY+17);Line(BX+13,BY+1,BX+3,BY+17);
      End;
  Else
   Pt[1].X:=BX;    Pt[1].Y:=BY;
   Pt[2].X:=BX;    Pt[2].Y:=BY+14;
   Pt[3].X:=BX+4;  Pt[3].Y:=BY+11;
   Pt[4].X:=BX+7;  Pt[4].Y:=BY+16;
   Pt[5].X:=BX+9;  Pt[5].Y:=BY+15;
   Pt[6].X:=BX+6;  Pt[6].Y:=BY+10;
   Pt[7].X:=BX+10; Pt[7].Y:=BY+10;
   SetFillStyle(SolidFill,Black);
   SetColor(White);
   FillPoly(7,Pt);
  End;
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
{      ECRAN DE L'ATARI ST : TAMPON MONOCHROME ET PRIMITIVES VDI         }
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

Var
 OrigBuf,DispBuf : PByteArr;
 ScrLog,ScrPhys  : LongInt;
 ScrCustom       : Boolean;
 ClipOn          : Boolean;
 ScrDirty        : Boolean;     { tampon ecran modifie par le VDI / l'AES : a recopier en memoire }
 ClipX1,ClipY1,ClipX2,ClipY2 : LongInt;

Procedure OBlitRect(BX1,BY1,BX2,BY2: LongInt);
{ recopie une zone du tampon (coordonnees ST) vers l'ecran }
Var Y,X,A,SX,SY: LongInt; InRun: Boolean; B: Byte;
Begin
 If Headless Or (Not OutLive) Then Exit;
 If BX1<0 Then BX1:=0;
 If BY1<0 Then BY1:=0;
 If BX2>OUT_W-1 Then BX2:=OUT_W-1;
 If BY2>OUT_H-1 Then BY2:=OUT_H-1;
 If (BX1>BX2) Or (BY1>BY2) Then Exit;
 HideMouse;
 SetFillStyle(SolidFill,PAPER);
 Bar(BX1,OFS_Y+BY1,BX2,OFS_Y+BY2);
 SetColor(INK);
 SetLineStyle(SolidLn,0,1);
 For Y:=BY1 To BY2 Do Begin
  SY:=OFS_Y+Y;
  InRun:=False;A:=0;
  X:=BX1;
  While X<=BX2 Do Begin
   B:=DispBuf^[Y*OUT_RB+(X Shr 3)];
   If (B=0) And ((X And 7)=0) And (X+7<=BX2) And (Not InRun) Then Inc(X,8)
   Else Begin
    If (B And (128 Shr (X And 7)))<>0 Then Begin
     If Not InRun Then Begin InRun:=True;A:=X;End;
    End Else If InRun Then Begin
     InRun:=False;
     If A=X-1 Then PutPixel(A,SY,INK) Else Line(A,SY,X-1,SY);
    End;
    Inc(X);
   End;
  End;
  If InRun Then Begin
   If A=BX2 Then PutPixel(A,SY,INK) Else Line(A,SY,BX2,SY);
  End;
 End;
End;

Procedure OutFlush(Force: Boolean);
Begin
 If Not OutPending Then Exit;
 If Force Or (NowCs-OutFlushCs>=10) Or (NowCs<OutFlushCs) Then Begin
  OutPending:=False;
  OutFlushCs:=NowCs;
  If OutLive Then OBlitRect(0,0,OUT_W-1,OUT_H-1);
 End;
End;

Var
 OXor : Boolean;
 DrawModeV,TxtColV : Integer;

Procedure OPlot(X,Y: LongInt; C: Byte);
Var Idx: LongInt; M: Byte;
Begin
 If (X<0) Or (X>=OUT_W) Or (Y<0) Or (Y>=OUT_H) Then Exit;
 If ClipOn And ((X<ClipX1) Or (X>ClipX2) Or (Y<ClipY1) Or (Y>ClipY2)) Then Exit;
 Idx:=Y*OUT_RB+(X Shr 3);
 M:=128 Shr (X And 7);
 If OXor Then Begin
  If (OutBuf^[Idx] And M)<>0 Then C:=0 Else C:=1;
 End;
 If C<>0 Then OutBuf^[Idx]:=OutBuf^[Idx] Or M
 Else OutBuf^[Idx]:=OutBuf^[Idx] And (Not M);
 If OutLive And (Not OutPending) And (Not Headless) And (OutBuf=DispBuf) Then Begin
  If C<>0 Then PutPixel(X,OFS_Y+Y,INK) Else PutPixel(X,OFS_Y+Y,PAPER);
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
  If TxtCol<>0 Then B:=Font8[Ord(Ch),Y Shr 1];
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

{ ====================================================================== }
{                  MEMOIRE VIRTUELLE ET CLAVIER DU PROGRAMME             }
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

Procedure KeyQAdd(K: Integer);
Begin
 If Length(KeyQ)<60 Then Begin
  If K>=256 Then KeyQ:=KeyQ+#0+Chr(K-256) Else KeyQ:=KeyQ+Chr(K);
 End;
End;

Procedure PollKeys;
Var K: Integer;
Begin
 If Headless Then Exit;
 While KeyPressed Do Begin
  K:=Ord(ReadKey);
  If K=0 Then KeyQAdd(256+Ord(ReadKey))
  Else If K=K_CTRLC Then Begin BreakReq:=True;LastRunMsg:='STOP';End
  Else If K=K_CTRLG Then BreakReq:=True
  Else KeyQAdd(K);
 End;
End;

Procedure RunPoll;
Begin
 GetMouseState(MX,MY,MB);
End;

Function GetKeyWait: Integer;
{ retourne un code (>=256 touche etendue) ; attend }
Var K: Integer; Ch: Char;
Begin
 If Headless Then Begin
  { entree standard }
  If Eof(Input) Then GetKeyWait:=K_ESC
  Else Begin Read(Ch);If Ch=#10 Then Ch:=#13;GetKeyWait:=Ord(Ch);End;
  Exit;
 End;
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

Function ResolveFile(Const N: String): String;
{ cherche un fichier sans tenir compte de la casse (comme TOS) }
Var Dir,Base,D2: String; I,P: Integer; SR: SearchRec; Found: Boolean;
Begin
 If FileExists(N) Then Begin ResolveFile:=N;Exit;End;
 If FileExists(Upper(N)) Then Begin ResolveFile:=Upper(N);Exit;End;
 If FileExists(LowerStr(N)) Then Begin ResolveFile:=LowerStr(N);Exit;End;
 P:=0;
 For I:=1 To Length(N) Do If N[I]='/' Then P:=I;
 If P>0 Then Begin Dir:=Copy(N,1,P);Base:=Copy(N,P+1,255);D2:=Copy(N,1,P-1);End
 Else Begin Dir:='';Base:=N;D2:='';End;
 If (Base='') Or (Base='.') Or (Base='..') Then Begin ResolveFile:=N;Exit;End;
 If (D2<>'') And (D2<>N) Then Begin
  { composant de repertoire : resolution recursive }
  D2:=ResolveFile(D2);
  Dir:=D2+'/';
 End;
 Found:=False;
 {$I-}
 FindFirst(Dir+'*',AnyFile,SR);
 While DosError=0 Do Begin
  If Upper(SR.Name)=Upper(Base) Then Begin Found:=True;Base:=SR.Name;Break;End;
  FindNext(SR);
 End;
 FindClose(SR);
 {$I+}
 If Found Then ResolveFile:=Dir+Base Else ResolveFile:=N;
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
 If A<VMEM_SIZE Then RB:=VMem[A] Else If A=$FF8260 Then RB:=2 Else RB:=0;
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
{ l'ecran logique de l'ST est la memoire emulee elle-meme : il n'y a rien a recopier,
  on demande seulement le rafraichissement de l'affichage }
Begin
 OutPending:=True;
End;

Procedure MemToOut;
{ detecte les modifications que le programme a faites directement dans la memoire ecran }
Var I: Integer; Chg: Boolean; P: PByteArr;
Begin
 Chg:=False;
 P:=PByteArr(@VMem[M_SCREEN]);
 For I:=0 To 31999 Do
  If P^[I]<>ScrShadow[I] Then Begin ScrShadow[I]:=P^[I];Chg:=True;End;
 If Chg Then Begin OutPending:=True;OutFlush(True);End;
End;


{ Sortie texte VT52 }

Var
 VtSX,VtSY : Integer;

Procedure VtInsLine(R: Integer);
Begin
 If (R<0) Or (R>=OUT_ROWS) Then Exit;
 If R<OUT_ROWS-1 Then
  Move(OutBuf^[LongInt(R)*16*OUT_RB],OutBuf^[LongInt(R+1)*16*OUT_RB],LongInt(OUT_ROWS-1-R)*16*OUT_RB);
 FillChar(OutBuf^[LongInt(R)*16*OUT_RB],16*OUT_RB,0);
 If OutLive Then OutPending:=True;
End;

Procedure VtDelLine(R: Integer);
Begin
 If (R<0) Or (R>=OUT_ROWS) Then Exit;
 If R<OUT_ROWS-1 Then
  Move(OutBuf^[LongInt(R+1)*16*OUT_RB],OutBuf^[LongInt(R)*16*OUT_RB],LongInt(OUT_ROWS-1-R)*16*OUT_RB);
 FillChar(OutBuf^[LongInt(OUT_ROWS-1)*16*OUT_RB],16*OUT_RB,0);
 If OutLive Then OutPending:=True;
End;

Procedure VtInvert(Col,Row: Integer);
Var Y: Integer; Base: LongInt;
Begin
 If (Col<0) Or (Col>=OUT_COLS) Or (Row<0) Or (Row>=OUT_ROWS) Then Exit;
 Base:=LongInt(Row)*16*OUT_RB+Col;
 For Y:=0 To 15 Do OutBuf^[Base+LongInt(Y)*OUT_RB]:=OutBuf^[Base+LongInt(Y)*OUT_RB] Xor $FF;
 If OutLive Then OutPending:=True;
End;

Procedure VtOut(Ch: Char);
Var C: Integer;
Begin
 If Headless Then Begin
  Case VtState Of
   0: Begin
       If Ch=#27 Then VtState:=1
       Else If Ch=#10 Then WriteLn
       Else If Ch<>#13 Then Write(Ch);
      End;
   1: Begin
       If Ch='Y' Then VtState:=2
       Else If (Ch='b') Or (Ch='c') Then VtState:=5
       Else VtState:=0;
      End;
   2: VtState:=3;
  Else VtState:=0;
  End;
  Exit;
 End;
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
       'I': If OCY>0 Then Dec(OCY) Else VtInsLine(0);
       'J': Begin
             For C:=OCX To OUT_COLS-1 Do OGlyph(C,OCY,' ');
             For C:=OCY+1 To OUT_ROWS-1 Do Begin
              FillChar(OutBuf^[LongInt(C)*16*OUT_RB],16*OUT_RB,0);
             End;
             If OutLive Then OutPending:=True;
            End;
       'K': For C:=OCX To OUT_COLS-1 Do OGlyph(C,OCY,' ');
       'L': Begin VtInsLine(OCY);OCX:=0;End;
       'M': Begin VtDelLine(OCY);OCX:=0;End;
       'Y': VtState:=2;
       'd': Begin
             For C:=0 To OCY-1 Do FillChar(OutBuf^[LongInt(C)*16*OUT_RB],16*OUT_RB,0);
             For C:=0 To OCX Do OGlyph(C,OCY,' ');
             If OutLive Then OutPending:=True;
            End;
       'j': Begin VtSX:=OCX;VtSY:=OCY;End;
       'k': OutGotoXY(VtSX,VtSY);
       'l': Begin For C:=0 To OUT_COLS-1 Do OGlyph(C,OCY,' ');OCX:=0;End;
       'o': For C:=0 To OCX Do OGlyph(C,OCY,' ');
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
  Else If VtRev And (Ch>=' ') Then Begin
   If OCX>=OutWidth Then OutNewLine;
   C:=OCX;
   OutCh(Ch);
   VtInvert(C,OCY);
  End Else OutCh(Ch);
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
 WW(D+22,Word(SR.Time And $FFFF));
 WW(D+24,Word((SR.Time Shr 16) And $FFFF));
 WL(D+26,SR.Size);
 Nm:=Upper(SR.Name);
 PutStr(D+30,Copy(Nm,1,13));
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
  10: RD[0]:=5;
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

{ texte 8x16 (lignes de la police 8x8 doublees) sur l'ecran hote }
Procedure AText16(X,Y: Integer; Const S: String; Col: Integer);
Var I,X2,Y2: Integer;
Begin
 For I:=1 To Length(S) Do
  For Y2:=0 To 15 Do
   For X2:=0 To 7 Do
    If (Font8[Ord(S[I]),Y2 Shr 1] And (128 Shr X2))<>0 Then
     PutPixel(X+(I-1)*8+X2,Y+Y2,Col);
End;

{ icone de form_alert : 1 = triangle !, 2 = cercle ?, 3 = octogone X (comme sur l'ST) }
Procedure AlertIcon(X,Y,Ic: Integer);
Var I: Integer;
Begin
 SetColor(INK);
 Case Ic Of
  1: Begin
      For I:=0 To 2 Do Begin
       Line(X+16,Y+2+I,X+2,Y+30+I);Line(X+16,Y+2+I,X+30,Y+30+I);
      End;
      Line(X+2,Y+30,X+30,Y+30);Line(X+2,Y+31,X+30,Y+31);
      AText16(X+12,Y+12,'!',INK);
     End;
  2: Begin
      Circle(X+16,Y+16,15);Circle(X+16,Y+16,14);
      AText16(X+12,Y+8,'?',INK);
     End;
  3: Begin
      For I:=0 To 32 Do Begin
       If I<10 Then Line(X+10-I,Y+I,X+22+I,Y+I)
       Else If I>22 Then Line(X+I-22,Y+I,X+54-I,Y+I)
       Else Line(X,Y+I,X+32,Y+I);
      End;
      AText16(X+12,Y+8,'X',PAPER);
     End;
 End;
End;

{ form_alert : [icone][lignes|...][boutons|...], texte 8x16, icone a gauche }
Function AesAlertBox(Ic: Integer; Const Txt,Btns: String; Def: Integer): Integer;
Var Lines: Array[1..8] Of String[60]; BT: Array[1..4] Of String[16];
    N,NB,I,W,H,X0,Y0,TX,BW,BX0,BY,P,R: Integer; S: String; E: TEvent; Done: Boolean; Sv: TSave;
Begin
 N:=0;S:=Txt;
 While (S<>'') And (N<8) Do Begin
  P:=Pos('|',S);Inc(N);
  If P=0 Then Begin Lines[N]:=Copy(S,1,60);S:='';End Else Begin Lines[N]:=Copy(S,1,P-1);Delete(S,1,P);End;
 End;
 NB:=0;S:=Btns;
 While (S<>'') And (NB<4) Do Begin
  P:=Pos('|',S);Inc(NB);
  If P=0 Then Begin BT[NB]:=Copy(S,1,16);S:='';End Else Begin BT[NB]:=Copy(S,1,P-1);Delete(S,1,P);End;
 End;
 If NB=0 Then Begin NB:=1;BT[1]:='OK';End;
 BW:=0;
 For I:=1 To NB Do If Length(BT[I])*8+16>BW Then BW:=Length(BT[I])*8+16;
 W:=0;
 For I:=1 To N Do If Length(Lines[I])*8>W Then W:=Length(Lines[I])*8;
 If Ic>0 Then TX:=64 Else TX:=16;
 W:=TX+W+16;
 If NB*(BW+16)+16>W Then W:=NB*(BW+16)+16;
 H:=N*16+16+8+24+24;
 If N*16<32 Then H:=32+16+8+24+24;
 X0:=(SCR_W-W) Div 2;Y0:=(SCR_H-H) Div 2;
 HideMouse;
 SaveBack(Sv,X0-2,Y0-2,X0+W+6,Y0+H+6);
 Box(X0+4,Y0+4,X0+W+3,Y0+H+3,INK);
 Box(X0,Y0,X0+W-1,Y0+H-1,PAPER);
 Frame(X0,Y0,X0+W-1,Y0+H-1);Frame(X0+1,Y0+1,X0+W-2,Y0+H-2);Frame(X0+2,Y0+2,X0+W-3,Y0+H-3);
 Frame(X0+4,Y0+4,X0+W-5,Y0+H-5);
 If Ic>0 Then AlertIcon(X0+16,Y0+16,Ic);
 For I:=1 To N Do AText16(X0+TX,Y0+16+(I-1)*16,Lines[I],INK);
 BX0:=X0+(W-NB*(BW+16)+16) Div 2;
 BY:=Y0+H-40;
 For I:=1 To NB Do Begin
  Frame(BX0+(I-1)*(BW+16),BY,BX0+(I-1)*(BW+16)+BW-1,BY+21);
  If I=Def Then Begin
   Frame(BX0+(I-1)*(BW+16)-1,BY-1,BX0+(I-1)*(BW+16)+BW,BY+22);
   Frame(BX0+(I-1)*(BW+16)-2,BY-2,BX0+(I-1)*(BW+16)+BW+1,BY+23);
  End;
  AText16(BX0+(I-1)*(BW+16)+(BW-Length(BT[I])*8) Div 2,BY+3,BT[I],INK);
 End;
 ShowMouse;
 Done:=False;R:=Def;
 If (R<1) Or (R>NB) Then R:=1;
 Repeat
  PollEvent(E);
  If E.Kind=1 Then Begin
   If E.Key=K_ENTER Then Begin R:=Def;If (R<1) Or (R>NB) Then R:=1;Done:=True;End;
  End Else If E.Kind=2 Then Begin
   For I:=1 To NB Do
    If InBox(E.X,E.Y,BX0+(I-1)*(BW+16),BY,BX0+(I-1)*(BW+16)+BW,BY+21) Then Begin R:=I;Done:=True;End;
  End;
 Until Done;
 HideMouse;
 RestoreBack(Sv);
 ShowMouse;
 AesAlertBox:=R;
End;

Function AesAlert(Const S: String; Def: Integer): Integer;
Var P1,P2: Integer; Lines,Btns,T: String; R,Ic: Integer;
Begin
 { format : [icone][ligne|ligne][bouton|bouton] }
 Lines:='';Btns:='';Ic:=0;
 If (Length(S)>=2) And (S[1]='[') And (S[2]>='0') And (S[2]<='9') Then Ic:=Ord(S[2])-48;
 P1:=Pos('][',S);
 If P1>0 Then Begin
  T:=Copy(S,P1+2,255);
  P2:=Pos('][',T);
  If P2>0 Then Begin Lines:=Copy(T,1,P2-1);Btns:=Copy(T,P2+2,255);End;
  If (Btns<>'') And (Btns[Length(Btns)]=']') Then Delete(Btns,Length(Btns),1);
 End;
 If Btns='' Then Btns:='OK';
 If Headless Then Begin
  { mode batch : l'alerte est affichee en texte, le bouton par defaut est choisi }
  R:=Def;
  If (R<1) Or (R>3) Then R:=1;
  WriteLn('[ALERT] ',Lines,' [',Btns,'] -> ',R);
 End Else R:=AesAlertBox(Ic,Lines,Btns,Def);
 AesAlert:=R;
End;

{ ====================================================================== }
{     BIBLIOTHEQUE D'EXECUTION PASCAL (PASLIB / PASGEM) : TRAP #6        }
{ ====================================================================== }
{ Les programmes generes appellent la bibliotheque par TRAP #6 : le numero
  du service est dans D0.W, les arguments sont empiles de gauche a droite
  (longs de 4 octets ; reels de 8 octets, mot fort au sommet) et depiles
  par le service. Resultat dans D0 (reels : D0 = mot fort, D1 = mot faible). }

Const
 S_MULL=1;   S_DIVL=2;   S_MODL=3;   S_ERR=4;    S_HALT=5;
 S_RADD=10;  S_RSUB=11;  S_RMUL=12;  S_RDIV=13;  S_RNEG=14;  S_RCMP=15;
 S_ITOR=16;  S_RTRUNC=17;S_RROUND=18;S_RABS=19;  S_RSQR=20;  S_RSQRT=21;
 S_RSIN=22;  S_RCOS=23;  S_RATAN=24; S_RLN=25;   S_REXP=26;  S_RPWR=27;
 S_SCAT=30;  S_SCMP=31;  S_SASG=32;  S_C2S=33;   S_SPOS=34;  S_SCOPY=35;
 S_SDEL=36;  S_SINS=37;  S_SUPPER=38;S_STRVAL=39;
 S_SETNEW=40;S_SETADD=41;S_SETRNG=42;S_SETUNI=43;S_SETDIF=44;S_SETINT=45;
 S_SETEQ=46; S_SETSUB=47;S_SETIN=48;
 S_NEW=50;   S_MARK=51;  S_RELEASE=52;S_RANDOM=53;S_TICKS=54;
 S_SELOUT=60;S_WRI=61;   S_WRC=62;   S_WRB=63;   S_WRS=64;   S_WRR=65;
 S_WRLN=66;  S_SELIN=67; S_RDI=68;   S_RDC=69;   S_RDS=70;   S_RDR=71;
 S_RDLN=72;  S_EOF=73;   S_EOLN=74;  S_FRESET=75;S_FCLOSE=76;S_FREAD=77;
 S_FWRITE=78;S_FSEEK=79; S_FPAGE=80; S_FERASE=81;
 S_PEEKB=90; S_PEEKW=91; S_PEEKL=92; S_POKEB=93; S_POKEW=94; S_POKEL=95;
 S_MOVEB=96;
 S_INITGEM=100;S_EXITGEM=101;S_ALERT=102;S_LINE=103;S_MOVETO=104;
 S_LINETO=105;S_PLOT=106;S_PRECT=107;S_FRECT=108;S_DRAWSTR=109;
 S_LINECOL=110;S_PAINTCOL=111;S_TEXTCOL=112;S_POVAL=113;S_FOVAL=114;
 S_PSTYLE=115;S_SHOWM=116;S_HIDEM=117;S_DMODE=118;S_LSTYLE=119;
 S_CLRSCR=120;S_PARC=121;S_FARC=122;S_PRRECT=123;S_FRRECT=124;
 S_GETKEY=125;S_KEYPRESS=126;S_PAINTOUT=127;S_SETCOLOR=128;S_TEXTHT=129;
 S_TEXTSTY=130;S_DELAY=131;S_GETMOUSE=132;S_SETCLIP=133;S_SETMOUSE=134;
 S_PACK=200;S_UNPACK=201;S_PWRTEN=202;S_FRENAME=203;S_FERASEF=204;S_CHAIN=205;S_BASEPAGE=206;
 S_OPTION=207;S_CMDARGS=208;S_CMDGETARG=209;S_FILENAME=210;S_HANDLE=211;S_IDENT=212;
 S_GETDATE=213;S_GETTIME=214;S_SETDATE=215;S_SETTIME=216;S_C2P=217;S_P2C=218;
 S_SAVESCR=219;S_RESTSCR=220;S_READSCR=221;S_WRITESCR=222;S_IOSTATE=223;S_IORESULT=224;S_IOCHECK=225;
 S_CARRASG=230;S_ARR2S=231;S_GOTOXY=226;S_TCOLOR=227;S_TBACK=228;S_CLOCK=229;
 S_VT0=240;  { 240..258 : sequences VT52 d'AUXSUBS }
 S_NOEXT=139;S_MOVEW=97;S_MOVEL=98;S_WRIH=99;S_FBUF=82;S_GET=83;S_PUT=84;S_SYSFONT=135;S_INSUPER=136;S_NOP1=137;

 M_STMP = $E1000;     { 16 chaines temporaires de 258 octets }
 M_SETT = $E3000;     { 16 ensembles temporaires de 32 octets }
 M_FBUF = $E4000;    { tampons des fichiers types (256 octets par fichier) }
 M_DBG  = $500;       { numero de ligne courant (mode debug) }
 M_DBGP = $502;       { reserve }
 M_HEAPLIM = $506;    { limite basse de la pile : sommet du tas + marge ($T) }

 MAXFILES = 16;

Type
 TPFile = Record
  Used   : Boolean;
  IsText : Boolean;
  Writing: Boolean;
  Name   : String[80];
  T      : Text;
  F      : File;
  ESize  : LongInt;
  EofV   : Boolean;
  Pk     : Integer;     { caractere de prelecture (-2 : aucun, -1 : fin) }
  GH     : Integer;     { handle GEMDOS associe (HANDLE), 0 : aucun }
 End;

Var
 PFiles   : Array[1..MAXFILES] Of TPFile;
 OutSel   : Integer;          { fichier de sortie courant (0 : console) }
 InSel    : Integer;          { fichier d'entree courant (0 : console) }
 ConBuf   : String;
 ConPos   : Integer;
 TmpIdx   : Integer;
 SetIdx   : Integer;
 PenX,PenY: LongInt;
 GemMode  : Boolean;
 GemUsed  : Boolean;
 TxtSize  : Integer;
 RtSeed   : LongInt;
 PrgDebug : Boolean;
 DbgNames : Array[1..400] Of String[12];
 DbgAddrs : Array[1..400] Of LongInt;
 DbgCount : Integer;
 PrgLoad  : LongInt;
 PrgText  : LongInt;
 RtTrace  : Boolean;
 Psg      : Array[0..15] Of Byte;
 IoCheckOn: Boolean;          { IO_Check : erreurs d'E/S fatales }
 IoRes    : Integer;          { IO_Result }
 ClockAdj : LongInt;          { Set_Date / Set_Time : decalage en secondes }
 ChainReq : String;           { CHAIN : ligne de commande du programme suivant }

Function RtErrText(C: Integer): String;
Begin
 Case C Of
  1: RtErrText:=T3('Range error','Erreur d''intervalle','Bereichsfehler');
  2: RtErrText:=T3('Division by zero','Division par z'#130'ro','Division durch Null');
  3: RtErrText:=T3('Pointer error','Erreur de pointeur','Zeigerfehler');
  4: RtErrText:=T3('String overflow','D'#130'passement de cha'#140'ne','Stringueberlauf');
  5: RtErrText:=T3('Stack overflow','D'#130'passement de pile','Stapelueberlauf');
  6: RtErrText:=T3('File error','Erreur de fichier','Dateifehler');
  7: RtErrText:=T3('Out of memory','M'#130'moire insuffisante','Speicher erschoepft');
  8: RtErrText:=T3('Bad input value','Valeur d''entr'#130'e incorrecte','Falsche Eingabe');
  9: RtErrText:=T3('Set overflow','D'#130'passement d''ensemble','Mengenueberlauf');
 10: RtErrText:=T3('Real overflow','D'#130'passement de r'#130'el','Real-Ueberlauf');
 Else RtErrText:=T3('Run-time error ','Erreur d''ex'#130'cution ','Laufzeitfehler ')+IntStr(C);
 End;
End;

Function ProcNameAt(A: LongInt): String;
Var I,B: Integer;
Begin
 B:=0;
 For I:=1 To DbgCount Do
  If (DbgAddrs[I]<=A) And ((B=0) Or (DbgAddrs[I]>DbgAddrs[B])) Then B:=I;
 If B=0 Then ProcNameAt:='UNKNOWN' Else ProcNameAt:=DbgNames[B];
End;

Procedure RtFail(C: Integer);
Var S: String;
Begin
 S:=RtErrText(C);
 If PrgDebug Then
  S:=S+' - '+T3('Subprogram ','Sous-programme ','Unterprogramm ')+ProcNameAt(EmuOpPC-PrgLoad)+
     ', '+T3('line ','ligne ','Zeile ')+IntStr(RW(M_DBG))+
     ', PC=$'+HexStr(EmuOpPC,16);
 EmuMsg:=S;
 EmuHalt:=True;EmuCode:=C;
End;

Procedure IoFail(Pas,Tos: Integer);
{ erreur d'entree/sortie : fatale seulement si IO_Check(TRUE) }
Begin
 If Tos<>0 Then IoRes:=Tos Else IoRes:=Pas;
 If IoCheckOn Then RtFail(6);
End;

{ ------------------------ chaines Pascal en memoire ------------------- }

Function GetPS(A: LongInt): String;
Var S: String; N,I: Integer;
Begin
 N:=RB(A);
 S[0]:=Chr(N);
 For I:=1 To N Do S[I]:=Chr(RB(A+I));
 GetPS:=S;
End;

Procedure PutPS(A: LongInt; Const S: String; Max: Integer);
Var N,I: Integer;
Begin
 N:=Length(S);
 If N>Max Then N:=Max;
 If N>255 Then N:=255;
 WB(A,N);
 For I:=1 To N Do WB(A+I,Ord(S[I]));
End;

Function NewTmpStr: LongInt;
Begin
 TmpIdx:=(TmpIdx+1) And 15;
 NewTmpStr:=M_STMP+TmpIdx*258;
End;

Function NewTmpSet: LongInt;
Begin
 SetIdx:=(SetIdx+1) And 15;
 NewTmpSet:=M_SETT+SetIdx*32;
 FillChar(VMem[M_SETT+SetIdx*32],32,0);
End;

{ ------------------------------ reels ---------------------------------- }
{ Real de Personal Pascal : flottant DECIMAL (BCD), mantisse de 11 chiffres,
  exposant -38..38. Format memoire sur 8 octets (poids fort d'abord) :
    octets 0-3 : chiffres 1 a 8 (BCD)         -> D0.L
    octet  4   : chiffres 9 et 10 (BCD)       -> D1.W, octet fort
    octet  5   : chiffre 11 (quartet fort) et signe (8 = negatif)
    octets 6-7 : facteur d'echelle, entier signe 16 bits
  valeur = d1.d2d3...d11 x 10^echelle ; une mantisse nulle vaut 0.
  Les calculs sont faits en flottant binaire hote puis arrondis a 11 chiffres
  decimaux a chaque stockage : 0.1+0.2 vaut exactement 0.3. }

Const
 REAL_MAXM = 100000000000;    (* 10^11 *)
 REAL_MINM = 10000000000;     (* 10^10 *)

Var
 Pw10   : Array[-100..100] Of Extended;
 Pw10Ok : Boolean;

Procedure InitPw10;
Var K: Integer;
Begin
 Pw10[0]:=1;
 For K:=1 To 100 Do Pw10[K]:=Pw10[K-1]*10;
 For K:=1 To 100 Do Pw10[-K]:=1/Pw10[K];
 Pw10Ok:=True;
End;

{ chiffres decimaux de X : X = (+/-) M x 10^(E-10), 10^10 <= M < 10^11.
  Retourne False si X vaut 0 (ou sous 1e-39 : sous-passement). E peut depasser
  38 : debordement, a tester par l'appelant. }
Function DecDigits(X: Double; Var Neg: Boolean; Var M: Int64; Var E: Integer): Boolean;
Var Ax,T: Extended; K: Integer;
Begin
 If Not Pw10Ok Then InitPw10;
 DecDigits:=False;M:=0;E:=0;Neg:=(X<0);
 Ax:=Abs(X);
 If Ax<1E-40 Then Exit;
 If Ax>=1E+60 Then Begin M:=REAL_MINM;E:=60;DecDigits:=True;Exit;End;
 E:=Round(Ln(Ax)/2.302585092994046);
 If E>59 Then E:=59;
 If E<-39 Then E:=-39;
 For K:=1 To 4 Do Begin
  T:=Ax/Pw10[E-10];
  M:=Round(T);
  If M>=REAL_MAXM Then Inc(E)
  Else If M<REAL_MINM Then Dec(E)
  Else Break;
 End;
 If M>=REAL_MAXM Then Begin M:=REAL_MINM;Inc(E);End;
 If M<REAL_MINM Then M:=REAL_MINM;
 DecDigits:=True;
End;

Function BcdOf(V: LongInt; N: Integer): Int64;
{ N chiffres decimaux de V en BCD }
Var R: Int64; I: Integer;
Begin
 R:=0;
 For I:=0 To N-1 Do Begin R:=R Or (Int64(V Mod 10) Shl (4*I));V:=V Div 10;End;
 BcdOf:=R;
End;

{ 0 : ok ; 1 : debordement (|X| > 1e38) ; sous-passement : 0 }
Function EncodeReal(X: Double; Var Bits: Int64): Integer;
Var Neg: Boolean; M: Int64; E: Integer; Hi8,Lo3: LongInt; Sg: Int64;
Begin
 Bits:=0;EncodeReal:=0;
 If Not DecDigits(X,Neg,M,E) Then Exit;
 If E>38 Then Begin EncodeReal:=1;Exit;End;
 If E<-38 Then Exit;
 Hi8:=M Div 1000;Lo3:=M Mod 1000;
 If Neg Then Sg:=8 Else Sg:=0;
 Bits:=(BcdOf(Hi8,8) Shl 32) Or (BcdOf(Lo3 Div 10,2) Shl 24) Or (Int64(Lo3 Mod 10) Shl 20)
       Or (Sg Shl 16) Or Int64(E And $FFFF);
End;

Function DecodeReal(Bits: Int64): Double;
Var I,E: Integer; M: Int64; Nb: Int64; V: Extended;
Begin
 If Not Pw10Ok Then InitPw10;
 M:=0;
 For I:=15 DownTo 8 Do Begin
  Nb:=(Bits Shr (4*I)) And 15;
  If Nb>9 Then Nb:=9;
  M:=M*10+Nb;
 End;
 For I:=7 DownTo 6 Do Begin
  Nb:=(Bits Shr (4*I)) And 15;
  If Nb>9 Then Nb:=9;
  M:=M*10+Nb;
 End;
 Nb:=(Bits Shr 20) And 15;
 If Nb>9 Then Nb:=9;
 M:=M*10+Nb;                          { M : 11 chiffres }
 If M=0 Then Begin DecodeReal:=0;Exit;End;
 E:=SmallInt(Bits And $FFFF);
 If E>60 Then E:=60;
 If E<-60 Then E:=-60;
 V:=Extended(M)*Pw10[E-10];
 If ((Bits Shr 16) And 8)<>0 Then V:=-V;
 DecodeReal:=V;
End;

Function PopR: Double;
Var Hi,Lo: LongInt; I: Int64;
Begin
 Hi:=Pop32;Lo:=Pop32;
 I:=(Int64(Hi) Shl 32) Or Int64(Cardinal(Lo));
 PopR:=DecodeReal(I);
End;

Procedure RetR(D: Double);
Var I: Int64;
Begin
 If EncodeReal(D,I)<>0 Then Begin RtFail(10);I:=0;End;
 RD[0]:=LongInt(Cardinal(I Shr 32));
 RD[1]:=LongInt(Cardinal(I And $FFFFFFFF));
End;

Function ReadRealMem(A: LongInt): Double;
Var Hi,Lo: LongInt; I: Int64;
Begin
 Hi:=RL(A);Lo:=RL(A+4);
 I:=(Int64(Hi) Shl 32) Or Int64(Cardinal(Lo));
 ReadRealMem:=DecodeReal(I);
End;

Procedure WriteRealMem(A: LongInt; D: Double);
Var I: Int64;
Begin
 If EncodeReal(D,I)<>0 Then Begin RtFail(10);I:=0;End;
 WL(A,LongInt(Cardinal(I Shr 32)));
 WL(A+4,LongInt(Cardinal(I And $FFFFFFFF)));
End;

Function IncDecStr(Const S: String): String;
{ ajoute 1 a une chaine de chiffres decimaux }
Var R: String; I: Integer;
Begin
 R:=S;I:=Length(R);
 While I>=1 Do Begin
  If R[I]='9' Then Begin R[I]:='0';Dec(I);End
  Else Begin R[I]:=Chr(Ord(R[I])+1);IncDecStr:=R;Exit;End;
 End;
 IncDecStr:='1'+R;
End;

Function FmtReal(X: Double; W,D: LongInt): String;
{ D>=0 : format fixe W:D ; D<0 : notation E (7.33124E+06) }
Var S,Dg,Ip,Fp,Z: String; Neg,Nz: Boolean; M: Int64; E,I: Integer;
Begin
 If DecDigits(X,Neg,M,E) Then Str(M,Dg) Else Begin Dg:='00000000000';E:=0;Neg:=False;End;
 If D>=0 Then Begin
  If D>20 Then D:=20;
  If W<0 Then W:=0;
  If E>=0 Then Begin
   Ip:=Copy(Dg,1,E+1);Fp:=Copy(Dg,E+2,40);
   While Length(Ip)<E+1 Do Ip:=Ip+'0';
  End Else Begin
   Ip:='0';Z:='';
   For I:=1 To -E-1 Do Z:=Z+'0';
   Fp:=Z+Dg;
  End;
  { arrondi decimal a D chiffres (demi vers le haut) }
  If Length(Fp)>D Then Begin
   Nz:=(Fp[D+1]>='5');
   Fp:=Copy(Fp,1,D);
  End Else Begin
   Nz:=False;
   While Length(Fp)<D Do Fp:=Fp+'0';
  End;
  If Nz Then Begin
   Z:=IncDecStr(Ip+Fp);
   If D>0 Then Begin Ip:=Copy(Z,1,Length(Z)-D);Fp:=Copy(Z,Length(Z)-D+1,D);End
   Else Begin Ip:=Z;Fp:='';End;
  End;
  S:=Ip;
  If D>0 Then S:=S+'.'+Fp;
  Nz:=False;
  For I:=1 To Length(Ip) Do If Ip[I]<>'0' Then Nz:=True;
  For I:=1 To Length(Fp) Do If Fp[I]<>'0' Then Nz:=True;
  If Neg And Nz Then S:='-'+S;
  While Length(S)<W Do S:=' '+S;
 End Else Begin
  { notation E par defaut : 7.33124E+06 (6 chiffres significatifs) }
  If Dg='00000000000' Then S:='0.00000E+00'
  Else Begin
   Fp:=Copy(Dg,1,6);
   If Dg[7]>='5' Then Begin
    Fp:=IncDecStr(Fp);
    If Length(Fp)>6 Then Begin Fp:=Copy(Fp,1,6);Inc(E);End;
   End;
   S:=Fp[1]+'.'+Copy(Fp,2,5);
   If E<0 Then S:=S+'E-' Else S:=S+'E+';
   If Abs(E)<10 Then S:=S+'0';
   S:=S+IntStr(Abs(E));
   If Neg Then S:='-'+S;
  End;
  While Length(S)<W Do S:=' '+S;
 End;
 FmtReal:=S;
End;

{ --------------------------- entrees / sorties ------------------------ }

Procedure PutCh(Ch: Char);
Begin
 If OutSel=0 Then VtOut(Ch)
 Else If (OutSel<=MAXFILES) And PFiles[OutSel].Used And PFiles[OutSel].IsText Then Begin
  {$I-}
  If Ch=#10 Then WriteLn(PFiles[OutSel].T) Else Write(PFiles[OutSel].T,Ch);
  {$I+}
  If IOResult<>0 Then RtFail(6);
 End;
End;

Procedure PutStrOut(Const S: String);
Var I: Integer;
Begin
 For I:=1 To Length(S) Do PutCh(S[I]);
End;

Procedure PadOut(Const S: String; W: LongInt);
Var I: Integer;
Begin
 For I:=Length(S)+1 To W Do PutCh(' ');
 PutStrOut(S);
End;

Function FileOf(A: LongInt): Integer;
Var H: LongInt;
Begin
 If A=0 Then FileOf:=0
 Else Begin
  H:=RL(A);
  If (H<1) Or (H>MAXFILES) Then FileOf:=-1
  Else If Not PFiles[H].Used Then FileOf:=-1
  Else FileOf:=H;
 End;
End;

Procedure ConFetch;
Var S: String;
Begin
 OutFlush(True);
 If Headless Then Begin
  If Eof(Input) Then Begin ConBuf:=#13;ConPos:=1;Exit;End;
  ReadLn(S);
 End Else Begin
  If Not ReadOutLine(S,250,False) Then Begin EmuBrk:=True;S:='';End;
 End;
 ConBuf:=S+#13;ConPos:=1;
End;

Function SrcPeek: Integer;
Var Ch: Char; H: Integer;
Begin
 If InSel=0 Then Begin
  If ConPos>Length(ConBuf) Then ConFetch;
  SrcPeek:=Ord(ConBuf[ConPos]);
  Exit;
 End;
 H:=InSel;
 If (H<1) Or (H>MAXFILES) Or (Not PFiles[H].Used) Then Begin SrcPeek:=-1;Exit;End;
 If PFiles[H].Pk=-2 Then Begin
  If PFiles[H].IsText Then Begin
   {$I-}
   Repeat
    If Eof(PFiles[H].T) Then Begin PFiles[H].Pk:=-1;Break;End;
    Read(PFiles[H].T,Ch);
    If Ch=#10 Then Begin PFiles[H].Pk:=13;Break;End;
    If Ch<>#13 Then Begin PFiles[H].Pk:=Ord(Ch);Break;End;
   Until False;
   {$I+}
   If IOResult<>0 Then PFiles[H].Pk:=-1;
  End Else PFiles[H].Pk:=-1;
 End;
 SrcPeek:=PFiles[H].Pk;
End;

Procedure SrcSkip;
Begin
 If InSel=0 Then Begin
  If ConPos<=Length(ConBuf) Then Inc(ConPos);
 End Else If (InSel>=1) And (InSel<=MAXFILES) Then PFiles[InSel].Pk:=-2;
End;

Function SrcEof: Boolean;
Begin
 If InSel=0 Then SrcEof:=False Else SrcEof:=(SrcPeek=-1);
End;

Procedure RdSkipBlanks;
Var C: Integer;
Begin
 Repeat
  C:=SrcPeek;
  If (C>=0) And (C<=32) Then SrcSkip Else Break;
 Until False;
End;

Function RdNumberStr(Real: Boolean): String;
Var S: String; C: Integer;
Begin
 S:='';
 RdSkipBlanks;
 C:=SrcPeek;
 If (C=Ord('-')) Or (C=Ord('+')) Then Begin S:=S+Chr(C);SrcSkip;End;
 Repeat
  C:=SrcPeek;
  If (C>=Ord('0')) And (C<=Ord('9')) Then Begin S:=S+Chr(C);SrcSkip;End
  Else If Real And ((C=Ord('.')) Or (C=Ord('E')) Or (C=Ord('e')) Or
          (((C=Ord('-')) Or (C=Ord('+'))) And (S<>'') And (UpCase(S[Length(S)])='E'))) Then Begin
   S:=S+Chr(C);SrcSkip;
  End Else Break;
 Until False;
 RdNumberStr:=S;
End;

Procedure StoreSized(A,V: LongInt; Sz: Integer);
Begin
 Case Sz Of
  1: WB(A,V And $FF);
  2: WW(A,V And $FFFF);
 Else WL(A,V);
 End;
End;

{ ------------------------------ fichiers ------------------------------ }

Procedure FileClose(H: Integer);
Begin
 If (H<1) Or (H>MAXFILES) Then Exit;
 If Not PFiles[H].Used Then Exit;
 If PFiles[H].GH>0 Then Begin
  If EmuFUsed[PFiles[H].GH] Then Begin {$I-}Close(EmuFile[PFiles[H].GH]);{$I+}If IOResult<>0 Then ;EmuFUsed[PFiles[H].GH]:=False;End;
  PFiles[H].GH:=0;
 End;
 {$I-}
 If PFiles[H].IsText Then Close(PFiles[H].T) Else Close(PFiles[H].F);
 {$I+}
 If IOResult<>0 Then ;
 PFiles[H].Used:=False;
End;

Procedure CloseAllPFiles;
Var I: Integer;
Begin
 For I:=1 To MAXFILES Do FileClose(I);
End;

Procedure FetchFile(H: Integer);
Var N: LongInt;
Begin
 N:=0;
 If PFiles[H].ESize>256 Then Begin PFiles[H].EofV:=True;Exit;End;
 {$I-}BlockRead(PFiles[H].F,VMem[M_FBUF+H*256],PFiles[H].ESize,N);{$I+}
 If IOResult<>0 Then N:=0;
 PFiles[H].EofV:=(N<PFiles[H].ESize);
End;

Function FileOpen(FA,NA: LongInt; ESz,Mode: LongInt): Boolean;
Var H,K: Integer; Nm: String;
Begin
 FileOpen:=False;
 K:=FileOf(FA);
 If K>0 Then FileClose(K);
 H:=0;
 For K:=1 To MAXFILES Do If (H=0) And (Not PFiles[K].Used) Then H:=K;
 IoRes:=0;
 If H=0 Then Begin IoFail(0,-35);Exit;End;
 Nm:=GetPS(NA);
 If Mode=0 Then Nm:=ResolveFile(Nm);
 PFiles[H].IsText:=(ESz=0);
 PFiles[H].ESize:=ESz;
 PFiles[H].Pk:=-2;
 PFiles[H].GH:=0;
 PFiles[H].Name:=Nm;
 PFiles[H].Writing:=(Mode<>0);
 {$I-}
 If ESz=0 Then Begin
  Assign(PFiles[H].T,Nm);
  If Mode=0 Then Reset(PFiles[H].T) Else Rewrite(PFiles[H].T);
 End Else Begin
  Assign(PFiles[H].F,Nm);
  If Mode=0 Then Reset(PFiles[H].F,1) Else Rewrite(PFiles[H].F,1);
 End;
 {$I+}
 If IOResult<>0 Then Begin
  WL(FA,0);
  If Mode=0 Then IoFail(0,-33) Else IoFail(0,-36);
  Exit;
 End;
 PFiles[H].Used:=True;
 PFiles[H].EofV:=True;
 WL(FA,H);
 If (ESz<>0) And (Mode=0) Then FetchFile(H);
 FileOpen:=True;
End;

{ ------------------------------ graphique ----------------------------- }

Procedure GfxPrep;
Begin
 OXor:=(DrawModeV=3);
End;

Procedure GRect(X,Y,W,H: LongInt; Fill: Boolean);
Begin
 If Fill Then Begin
  PX[0]:=X;PY[0]:=Y;PX[1]:=X+W;PY[1]:=Y;PX[2]:=X+W;PY[2]:=Y+H;PX[3]:=X;PY[3]:=Y+H;
  OFillPoly(4);
 End Else Begin
  OLine(X,Y,X+W-1,Y,LineInk);OLine(X+W-1,Y,X+W-1,Y+H-1,LineInk);
  OLine(X+W-1,Y+H-1,X,Y+H-1,LineInk);OLine(X,Y+H-1,X,Y,LineInk);
 End;
End;

Procedure GText(X,Y: LongInt; Const S: String);
Var I,X2,Y2: Integer;
Begin
 For I:=1 To Length(S) Do
  For Y2:=0 To 7 Do
   For X2:=0 To 7 Do
    If (Font8[Ord(S[I]),Y2] And (128 Shr X2))<>0 Then
     OPlot(X+(I-1)*8+X2,Y-8+Y2+1,TxtColV);
End;


{ ====================================================================== }
{    AES / PASGEM INTEGRE : MENUS, FENETRES, DIALOGUES, EVENEMENTS       }
{ ====================================================================== }

Const
 S_NEWMENU=140;S_DELMENU=141;S_ADDMTITLE=142;S_ADDMITEM=143;S_DRAWMENU=144;
 S_ERASEMENU=145;S_MENUHI=146;S_MENUNORMAL=147;S_MENUCHECK=148;S_MENUENABLE=149;
 S_MENUDISABLE=150;S_MENUTEXT=151;S_MENUREG=152;
 S_NEWWIN=153;S_OPENWIN=154;S_CLOSEWIN=155;S_DELWIN=156;S_SETWSIZE=157;
 S_SETWNAME=158;S_SETWINFO=159;S_BORDERRECT=160;S_WORKRECT=161;S_FIRSTRECT=162;
 S_NEXTRECT=163;S_RECTINT=164;S_FRONTWIN=165;S_BRINGFRONT=166;S_SETWINDOW=167;
 S_GETWINDOW=168;S_WINDGET=169;S_WINDSET=170;S_GETEVENT=171;
 S_NEWDLG=172;S_DELDLG=173;S_ADDDITEM=174;S_DCOLOR=175;S_SETDTEXT=176;
 S_SETDEDIT=177;S_OBJSETSTATE=178;S_OBJSTATE=179;S_OBJSETFLAGS=180;S_OBJFLAGS=181;
 S_CENTERDLG=182;S_DODLG=183;S_GETDEDIT=184;S_REDODLG=185;S_ENDDLG=186;
 S_SHOWDLG=187;S_GETINFILE=188;S_GETOUTFILE=189;S_SETMFORM=190;S_SETMOUSE2=191;
 S_SHOWMOUSE=192;S_HIDEMOUSE=193;S_LOADRSC=194;S_FINDMENU=195;S_FINDDLG=196;S_FINDALERT=197;S_FREERSC=198;

 GM_BAR  = 19;
 MAXMT   = 10;
 MAXMI   = 20;
 MAXGW   = 7;
 MAXGMN  = 4;
 MAXGD   = 4;
 MAXGO   = 64;
 WM_REDRAW_ = 20;

Type
 TGWin = Record
  Used,Open : Boolean;
  Kind      : Integer;
  Title,Info: String[80];
  MX,MY,MW,MH : Integer;       { limites }
  X,Y,W,H   : Integer;         { rectangle de bordure }
  PX,PY,PW,PH : Integer;
  HS,VS,HSz,VSz : Integer;
 End;

 TGMenu = Record
  Used,Drawn : Boolean;
  NT   : Integer;
  TT   : Array[1..MAXMT] Of String[30];
  TX   : Array[1..MAXMT] Of Integer;
  TOb  : Array[1..MAXMT] Of Integer;   { numero d'objet du titre (menus AES) }
  NI   : Array[1..MAXMT] Of Integer;
  IT   : Array[1..MAXMT,1..MAXMI] Of String[40];
  IDn  : Array[1..MAXMT,1..MAXMI] Of Integer;
  IC,ID: Array[1..MAXMT,1..MAXMI] Of Boolean;
  Hi   : Integer;
 End;

 TGObj = Record
  Typ,Flags,State : Integer;
  X,Y,W,H,Border,Color : Integer;
  Txt : String[60];
  Templ,Valid : String[40];
  Just : Integer;
  PXo,PYo,PWo,PHo : Integer;
  Parent : Integer;
  Hidden : Boolean;
  ImgOff,MaskOff : LongInt;
  ImgWB,ImgH,ImgX,ImgY : Integer;
  IcX,IcY,IcW,IcH,TxX,TxY,TxW,TxH,IcCh : Integer;
 End;

 TGDlg = Record
  Used,Shown : Boolean;
  N  : Integer;
  Ob : Array[0..MAXGO] Of TGObj;
  PX,PY : Integer;
  Sv : TSave;
 End;

 TRct = Record X,Y,W,H: Integer; End;

Var
 ImgPool : Array[0..65535] Of Byte;
 PoolN   : LongInt;
 GW      : Array[0..MAXGW] Of TGWin;
 ZW      : Array[1..MAXGW] Of Integer;
 ZN      : Integer;
 GMn     : Array[1..MAXGMN] Of TGMenu;
 GDl     : Array[1..MAXGD] Of TGDlg;
 MsgQ    : Array[1..16,0..7] Of Integer;
 MsgN    : Integer;
 CurWin  : Integer;
 OrgX,OrgY : Integer;
 RectL   : Array[1..80] Of TRct;
 RectN,RectI : Integer;
 ProgMouse : Boolean;
 ActMenu : Integer;
 LastClkCs : LongInt;
 ClkCnt  : Integer;
 NextItemId : Integer;

Var LastKbd: Integer;          { etat Maj(1,2) Ctrl(4) Alt(8) deduit de la derniere touche }
Var AesKeyScan: Boolean;      { programme AES reel : touches avec code de balayage }
Function KeyToAes(K: Integer): LongInt; Forward;

Function KbdOfKey(K: Integer): Integer;
{ les touches modificatrices ne sont pas visibles directement : on les deduit du code reçu
  (Ctrl+lettre donne 1..26, Alt+lettre donne un code etendu de lettre, etc.) }
Var Sc: Integer;
Begin
 KbdOfKey:=0;
 If K<256 Then Begin
  If (K>=1) And (K<=26) And (K<>8) And (K<>9) And (K<>10) And (K<>13) Then KbdOfKey:=4
  Else If (K>=65) And (K<=90) Then KbdOfKey:=1;
 End Else Begin
  Sc:=K-256;
  If ((Sc>=16) And (Sc<=25)) Or ((Sc>=30) And (Sc<=38)) Or ((Sc>=44) And (Sc<=50)) Or
     ((Sc>=120) And (Sc<=131)) Or ((Sc>=104) And (Sc<=113)) Then KbdOfKey:=8
  Else If (Sc>=84) And (Sc<=93) Then KbdOfKey:=1
  Else If ((Sc>=94) And (Sc<=103)) Or ((Sc>=115) And (Sc<=119)) Then KbdOfKey:=4;
 End;
End;

Procedure GemCur(OnFlag: Boolean);
Begin
 ProgMouse:=OnFlag;
 If Headless Then Exit;
 If OnFlag Then Begin MouseLock:=0;ShowMouse;End
 Else Begin HideMouse;MouseLock:=1;End;
End;

Procedure PutW(A: LongInt; V: LongInt);
Begin
 WW(A,Word(V And $FFFF));
End;

Function GetW(A: LongInt): LongInt;
Begin
 GetW:=SmallInt(RW(A));
End;

Function Max3(A,B: LongInt): LongInt;
Begin
 If A>B Then Max3:=A Else Max3:=B;
End;

Function Min3(A,B: LongInt): LongInt;
Begin
 If A<B Then Min3:=A Else Min3:=B;
End;

{ ------------------------- primitives sur l'ecran ST ------------------- }

Var
 SvClip : Boolean;
 SvCX1,SvCY1,SvCX2,SvCY2 : LongInt;

Procedure GBegin(CX,CY,CW,CH: Integer; UseClip: Boolean);
Begin
 SvClip:=ClipOn;SvCX1:=ClipX1;SvCY1:=ClipY1;SvCX2:=ClipX2;SvCY2:=ClipY2;
 OXor:=False;
 ClipOn:=UseClip;
 If UseClip Then Begin ClipX1:=CX;ClipY1:=CY;ClipX2:=CX+CW-1;ClipY2:=CY+CH-1;End;
 OutPending:=True;
End;

Procedure GEnd;
Begin
 ClipOn:=SvClip;ClipX1:=SvCX1;ClipY1:=SvCY1;ClipX2:=SvCX2;ClipY2:=SvCY2;
 OutPending:=True;
End;

Procedure GFill(X,Y,W,H: Integer; C: Byte);
Var I,J: Integer;
Begin
 For J:=Y To Y+H-1 Do
  For I:=X To X+W-1 Do OPlot(I,J,C);
End;

Procedure GHatch(X,Y,W,H: Integer);
Var I,J: Integer;
Begin
 For J:=Y To Y+H-1 Do
  For I:=X To X+W-1 Do OPlot(I,J,(I+J) And 1);
End;

Procedure GBox(X,Y,W,H: Integer);
Var I: Integer;
Begin
 For I:=X To X+W-1 Do Begin OPlot(I,Y,1);OPlot(I,Y+H-1,1);End;
 For I:=Y To Y+H-1 Do Begin OPlot(X,I,1);OPlot(X+W-1,I,1);End;
End;

{ texte 8x16 (lignes de la police 8x8 doublees) dans le tampon de l'ecran, haut du glyphe en Y }
Procedure GText16(X,Y: LongInt; Const S: String; Col: Integer);
Var I,X2,Y2: Integer;
Begin
 For I:=1 To Length(S) Do
  For Y2:=0 To 15 Do
   For X2:=0 To 7 Do
    If (Font8[Ord(S[I]),Y2 Shr 1] And (128 Shr X2))<>0 Then
     OPlot(X+(I-1)*8+X2,Y+Y2,Col);
End;

Procedure GTextC(X,Y: Integer; Const S: String; Inv: Boolean);
{ texte 8x16 centre sur la meme ligne qu'un texte 8x8 dont le haut serait en Y }
Begin
 If Inv Then GText16(X,Y-4,S,0) Else GText16(X,Y-4,S,1);
End;

{ memes textes 8x16 sur l'ecran hote (menus deroulants, objets de la bibliotheque hote) }
Procedure HText16(X,Y: Integer; Const S: String; Col: Integer);
Var I,X2,Y2: Integer;
Begin
 For I:=1 To Length(S) Do
  For Y2:=0 To 15 Do
   For X2:=0 To 7 Do
    If (Font8[Ord(S[I]),Y2 Shr 1] And (128 Shr X2))<>0 Then
     PutPixel(X+(I-1)*8+X2,Y+Y2,Col);
End;

Procedure PText16(X,Y: Integer; Const S: String);
Begin HText16(X,Y,S,INK); End;

Procedure WText16(X,Y: Integer; Const S: String);
Begin HText16(X,Y,S,PAPER); End;

Procedure GreyText16(X,Y: Integer; Const S: String);
Var I,J,W: Integer;
Begin
 PText16(X,Y,S);
 W:=Length(S)*8;
 For J:=0 To 15 Do
  For I:=0 To W-1 Do
   If Odd(I+J) Then
    If GetPixel(X+I,Y+J)=INK Then PutPixel(X+I,Y+J,PAPER);
End;

Procedure GFlush;
Begin
 OutPending:=True;
 OutFlush(True);
 If ProgMouse And (Not Headless) Then Begin MouseLock:=0;ShowMouse;End;
End;

{ ------------------------------ fenetres ------------------------------- }

Function HasV(K: Integer): Boolean;
Begin
 HasV:=(K And ($1C0 Or $20))<>0;
End;

Function HasH(K: Integer): Boolean;
Begin
 HasH:=(K And ($E00 Or $20))<>0;
End;

Function HasTitle(I: Integer): Boolean;
Begin
 HasTitle:=(GW[I].Kind And $E)<>0;
End;

Procedure WinWork(I: Integer; Var X,Y,W,H: Integer);
Begin
 X:=GW[I].X+1;Y:=GW[I].Y+1;
 If (GW[I].Kind And $E)<>0 Then Y:=Y+19;
 If (GW[I].Kind And $10)<>0 Then Y:=Y+19;
 W:=GW[I].W-2;
 H:=GW[I].H-(Y-GW[I].Y)-1;
 If HasV(GW[I].Kind) Then W:=W-18;
 If HasH(GW[I].Kind) Then H:=H-18;
 If W<0 Then W:=0;
 If H<0 Then H:=0;
End;

Procedure DeskRect(Var X,Y,W,H: Integer);
Begin
 X:=0;Y:=GM_BAR;W:=640;H:=400-GM_BAR;
End;

Function Isect(A,B: TRct; Var R: TRct): Boolean;
Var X1,Y1,X2,Y2: Integer;
Begin
 X1:=Max3(A.X,B.X);Y1:=Max3(A.Y,B.Y);
 X2:=Min3(A.X+A.W,B.X+B.W);Y2:=Min3(A.Y+A.H,B.Y+B.H);
 R.X:=X1;R.Y:=Y1;R.W:=X2-X1;R.H:=Y2-Y1;
 Isect:=(R.W>0) And (R.H>0);
End;

Function WinBorder(I: Integer): TRct;
Var R: TRct;
Begin
 R.X:=GW[I].X;R.Y:=GW[I].Y;R.W:=GW[I].W;R.H:=GW[I].H;
 WinBorder:=R;
End;

Function TopWin: Integer;
Begin
 If ZN>0 Then TopWin:=ZW[ZN] Else TopWin:=-1;
End;

Procedure PushMsg(T,H,A,B,C,D: Integer);
Begin
 If MsgN>=16 Then Exit;
 Inc(MsgN);
 MsgQ[MsgN,0]:=T;MsgQ[MsgN,1]:=1;MsgQ[MsgN,2]:=0;MsgQ[MsgN,3]:=H;
 MsgQ[MsgN,4]:=A;MsgQ[MsgN,5]:=B;MsgQ[MsgN,6]:=C;MsgQ[MsgN,7]:=D;
End;

Procedure DrawWinFrame(I: Integer);
Var X,Y,W,H,WX,WY,WW2,WH,TX,K,TL,TH: Integer; Top: Boolean; S: String;
Begin
 X:=GW[I].X;Y:=GW[I].Y;W:=GW[I].W;H:=GW[I].H;
 Top:=(TopWin=I);
 GFill(X,Y,W,H,0);
 GBox(X,Y,W,H);
 K:=GW[I].Kind;
 If (K And $E)<>0 Then Begin
  For TX:=X To X+W-1 Do OPlot(TX,Y+19,1);
  If Top Then
   For TX:=Y+3 To Y+15 Do
    If Odd(TX) Then For WX:=X+20 To X+W-21 Do OPlot(WX,TX,1);
  S:=GW[I].Title;
  If Length(S)*8+8>W-40 Then S:=Copy(S,1,(W-48) Div 8);
  WX:=X+(W-Length(S)*8) Div 2;
  GFill(WX-4,Y+2,Length(S)*8+8,16,0);
  GTextC(WX,Y+6,S,False);
  If (K And 2)<>0 Then Begin
   GFill(X+1,Y+1,18,18,0);GBox(X+1,Y+1,18,18);GBox(X+5,Y+5,10,10);
  End;
  If (K And 4)<>0 Then Begin
   GFill(X+W-19,Y+1,18,18,0);GBox(X+W-19,Y+1,18,18);GBox(X+W-15,Y+5,10,10);GBox(X+W-12,Y+8,4,4);
  End;
 End;
 If (K And $10)<>0 Then Begin
  WY:=Y+1;If (K And $E)<>0 Then WY:=WY+19;
  For TX:=X To X+W-1 Do OPlot(TX,WY+18,1);
  GTextC(X+6,WY+6,Copy(GW[I].Info,1,(W-12) Div 8),False);
 End;
 WinWork(I,WX,WY,WW2,WH);
 If HasV(K) Then Begin
  { barre verticale }
  TX:=X+W-19;
  For TL:=WY-1 To WY+WH+Ord(HasH(K))*18 Do OPlot(TX,TL,1);
  If (K And $40)<>0 Then Begin GBox(TX,WY,19,18);GTextC(TX+5,WY+5,#24,False);End;
  If (K And $80)<>0 Then Begin GBox(TX,WY+WH-18,19,18);GTextC(TX+5,WY+WH-13,#25,False);End;
  If (K And $100)<>0 Then Begin
   TL:=WY+18;TH:=WH-36;
   If TH>8 Then Begin
    GHatch(TX+1,TL,17,TH);
    If GW[I].VSz<=0 Then GW[I].VSz:=1000;
    K:=Max3(8,TH*GW[I].VSz Div 1000);
    GFill(TX+1,TL+(TH-K)*GW[I].VS Div 1000,17,K,0);
    GBox(TX+1,TL+(TH-K)*GW[I].VS Div 1000,17,K);
   End;
  End;
  K:=GW[I].Kind;
 End;
 If HasH(K) Then Begin
  TL:=WY+WH;
  For TX:=WX To WX+WW2+Ord(HasV(K))*18 Do OPlot(TX,TL,1);
  If (K And $200)<>0 Then Begin GBox(WX,TL,18,19);GTextC(WX+5,TL+6,#27,False);End;
  If (K And $400)<>0 Then Begin GBox(WX+WW2-18,TL,18,19);GTextC(WX+WW2-13,TL+6,#26,False);End;
  If (K And $800)<>0 Then Begin
   TH:=WW2-36;
   If TH>8 Then Begin
    GHatch(WX+18,TL+1,TH,17);
    If GW[I].HSz<=0 Then GW[I].HSz:=1000;
    K:=Max3(8,TH*GW[I].HSz Div 1000);
    GFill(WX+18+(TH-K)*GW[I].HS Div 1000,TL+1,K,17,0);
    GBox(WX+18+(TH-K)*GW[I].HS Div 1000,TL+1,K,17);
   End;
  End;
  K:=GW[I].Kind;
 End;
 If (K And $20)<>0 Then Begin
  GFill(X+W-19,Y+H-19,18,18,0);GBox(X+W-19,Y+H-19,19,19);GBox(X+W-14,Y+H-14,9,9);
 End;
 { zone de travail blanche }
 GFill(WX,WY,WW2,WH,0);
End;

Function TitleObjOf(H,K: Integer): Integer;
Begin
 If GMn[H].TOb[K]>0 Then TitleObjOf:=GMn[H].TOb[K] Else TitleObjOf:=K+2;
End;

Procedure GemRefresh(RX,RY,RW,RH: Integer; Msgs: Boolean);
{ redessine le bureau, la barre de menus et les fenetres dans le rectangle donne }
Var I,K: Integer; D,R,Q,S: TRct; DX,DY,DW,DH: Integer;
Begin
 D.X:=RX;D.Y:=RY;D.W:=RW;D.H:=RH;
 S.X:=0;S.Y:=0;S.W:=640;S.H:=400;
 If Not Isect(D,S,R) Then Exit;
 GBegin(R.X,R.Y,R.W,R.H,True);
 DeskRect(DX,DY,DW,DH);
 GHatch(R.X,Max3(R.Y,GM_BAR),R.W,Max3(0,R.Y+R.H-Max3(R.Y,GM_BAR)));
 { barre de menus }
 If R.Y<GM_BAR Then Begin
  GFill(0,0,640,GM_BAR-1,0);
  For I:=0 To 639 Do OPlot(I,GM_BAR-1,1);
  If (ActMenu>0) And GMn[ActMenu].Drawn Then Begin
   For K:=1 To GMn[ActMenu].NT Do Begin
    If GMn[ActMenu].Hi=TitleObjOf(ActMenu,K) Then Begin
     GFill(GMn[ActMenu].TX[K],0,Length(GMn[ActMenu].TT[K])*8,GM_BAR-1,1);
     GTextC(GMn[ActMenu].TX[K],5,GMn[ActMenu].TT[K],True);
    End Else GTextC(GMn[ActMenu].TX[K],5,GMn[ActMenu].TT[K],False);
   End;
  End;
 End;
 For K:=1 To ZN Do Begin
  I:=ZW[K];
  If GW[I].Open Then Begin
   Q:=WinBorder(I);
   If Isect(R,Q,S) Then Begin
    DrawWinFrame(I);
    If Msgs Then PushMsg(WM_REDRAW_,I,S.X,S.Y,S.W,S.H);
   End;
  End;
 End;
 GEnd;
 GFlush;
End;

Procedure GemBarRedraw;
Begin
 GemRefresh(0,0,640,GM_BAR,False);
End;

Function NewGWin: Integer;
Var I: Integer;
Begin
 NewGWin:=-1;
 For I:=1 To MAXGW Do If Not GW[I].Used Then Begin
  FillChar(GW[I],SizeOf(TGWin),0);
  GW[I].Used:=True;
  NewGWin:=I;Exit;
 End;
End;

Procedure ZRemove(I: Integer);
Var J,K: Integer;
Begin
 K:=0;
 For J:=1 To ZN Do If ZW[J]=I Then K:=J;
 If K=0 Then Exit;
 For J:=K To ZN-1 Do ZW[J]:=ZW[J+1];
 Dec(ZN);
End;

Procedure ZToTop(I: Integer);
Begin
 ZRemove(I);
 If ZN<MAXGW Then Begin Inc(ZN);ZW[ZN]:=I;End;
End;

Procedure WinOpen(I,X,Y,W,H: Integer);
Var DX,DY,DW,DH: Integer;
Begin
 DeskRect(DX,DY,DW,DH);
 If (W<=0) Or (H<=0) Then Begin
  GW[I].X:=0;GW[I].Y:=DY;GW[I].W:=DW;GW[I].H:=DH;
 End Else Begin
  GW[I].X:=X;GW[I].Y:=Y;GW[I].W:=W;GW[I].H:=H;
 End;
 GW[I].PX:=GW[I].X;GW[I].PY:=GW[I].Y;GW[I].PW:=GW[I].W;GW[I].PH:=GW[I].H;
 GW[I].Open:=True;
 ZToTop(I);
 GemRefresh(GW[I].X,GW[I].Y,GW[I].W+2,GW[I].H+2,True);
End;

Procedure WinClose(I: Integer);
Var Q: TRct;
Begin
 If Not GW[I].Open Then Exit;
 Q:=WinBorder(I);
 GW[I].Open:=False;
 ZRemove(I);
 If CurWin=I Then Begin CurWin:=0;OrgX:=0;OrgY:=0;End;
 GemRefresh(Q.X,Q.Y,Q.W+2,Q.H+2,True);
End;

Procedure WinSetSize(I,X,Y,W,H: Integer);
Var Q,N: TRct; U: TRct;
Begin
 If Not GW[I].Open Then Exit;
 Q:=WinBorder(I);
 GW[I].PX:=Q.X;GW[I].PY:=Q.Y;GW[I].PW:=Q.W;GW[I].PH:=Q.H;
 If W<60 Then W:=60;
 If H<40 Then H:=40;
 GW[I].X:=X;GW[I].Y:=Y;GW[I].W:=W;GW[I].H:=H;
 N:=WinBorder(I);
 U.X:=Min3(Q.X,N.X);U.Y:=Min3(Q.Y,N.Y);
 U.W:=Max3(Q.X+Q.W,N.X+N.W)-U.X+2;U.H:=Max3(Q.Y+Q.H,N.Y+N.H)-U.Y+2;
 GemRefresh(U.X,U.Y,U.W,U.H,True);
End;

Procedure WinToFront(I: Integer);
Begin
 If Not GW[I].Open Then Exit;
 If TopWin=I Then Exit;
 ZToTop(I);
 GemRefresh(GW[I].X,GW[I].Y,GW[I].W+2,GW[I].H+2,True);
End;

{ liste des rectangles visibles de la zone de travail }
Procedure RectSub(Var N: Integer; B: TRct);
Var Old: Array[1..80] Of TRct; M,I: Integer; A,R: TRct; T: TRct;
Begin
 M:=N;N:=0;
 For I:=1 To M Do Old[I]:=RectL[I];
 For I:=1 To M Do Begin
  A:=Old[I];
  If Not Isect(A,B,R) Then Begin
   If N<80 Then Begin Inc(N);RectL[N]:=A;End;
  End Else Begin
   If R.Y>A.Y Then Begin T.X:=A.X;T.Y:=A.Y;T.W:=A.W;T.H:=R.Y-A.Y;If N<80 Then Begin Inc(N);RectL[N]:=T;End;End;
   If R.Y+R.H<A.Y+A.H Then Begin T.X:=A.X;T.Y:=R.Y+R.H;T.W:=A.W;T.H:=A.Y+A.H-R.Y-R.H;If N<80 Then Begin Inc(N);RectL[N]:=T;End;End;
   If R.X>A.X Then Begin T.X:=A.X;T.Y:=R.Y;T.W:=R.X-A.X;T.H:=R.H;If N<80 Then Begin Inc(N);RectL[N]:=T;End;End;
   If R.X+R.W<A.X+A.W Then Begin T.X:=R.X+R.W;T.Y:=R.Y;T.W:=A.X+A.W-R.X-R.W;T.H:=R.H;If N<80 Then Begin Inc(N);RectL[N]:=T;End;End;
  End;
 End;
End;

Procedure BuildRects(I: Integer);
Var X,Y,W,H,K,J: Integer; D,S,R: TRct; Found: Boolean;
Begin
 RectN:=0;RectI:=0;
 If I<=0 Then Begin
  DeskRect(X,Y,W,H);
 End Else Begin
  If Not GW[I].Open Then Exit;
  WinWork(I,X,Y,W,H);
 End;
 D.X:=X;D.Y:=Y;D.W:=W;D.H:=H;
 S.X:=0;S.Y:=GM_BAR;S.W:=640;S.H:=400-GM_BAR;
 If Not Isect(D,S,R) Then Exit;
 RectN:=1;RectL[1]:=R;
 Found:=(I<=0);
 For K:=1 To ZN Do Begin
  J:=ZW[K];
  If J=I Then Found:=True
  Else If Found And GW[J].Open Then RectSub(RectN,WinBorder(J));
 End;
End;

Procedure RectOut(A1,A2,A3,A4: LongInt);
Begin
 If RectI<RectN Then Begin
  Inc(RectI);
  PutW(A1,RectL[RectI].X);PutW(A2,RectL[RectI].Y);PutW(A3,RectL[RectI].W);PutW(A4,RectL[RectI].H);
 End Else Begin
  PutW(A1,0);PutW(A2,0);PutW(A3,0);PutW(A4,0);
 End;
End;

{ ------------------------------- menus --------------------------------- }

Procedure MenuLayout(H: Integer);
Var K,X: Integer;
Begin
 X:=8;
 For K:=1 To GMn[H].NT Do Begin
  GMn[H].TX[K]:=X;
  X:=X+Length(GMn[H].TT[K])*8;
 End;
End;

Function MenuTitleAt(H,MXp: Integer): Integer;
Var K: Integer;
Begin
 MenuTitleAt:=0;
 For K:=1 To GMn[H].NT Do
  If (MXp>=GMn[H].TX[K]) And (MXp<GMn[H].TX[K]+Length(GMn[H].TT[K])*8) Then MenuTitleAt:=K;
End;

Function DropWidth(H,T: Integer): Integer;
Var I,W: Integer;
Begin
 W:=0;
 For I:=1 To GMn[H].NI[T] Do If Length(GMn[H].IT[T,I])>W Then W:=Length(GMn[H].IT[T,I]);
 DropWidth:=W*8+24;
End;

Function Trim2(Const S: String): String;
Begin
 Trim2:=TrimStr(S);
End;

Procedure DrawDrop(H,T,Hi: Integer);
Var X1,Y1,X2,Y2,I,Y: Integer; S: String;
Begin
 X1:=GMn[H].TX[T];
 If X1+DropWidth(H,T)>636 Then X1:=636-DropWidth(H,T);
 Y1:=OFS_Y+GM_BAR-1;X2:=X1+DropWidth(H,T);Y2:=Y1+GMn[H].NI[T]*16+4;
 HideMouse;
 Box(X1+3,Y1+3,X2+3,Y2+3,INK);
 Box(X1,Y1,X2,Y2,PAPER);Frame(X1,Y1,X2,Y2);
 For I:=1 To GMn[H].NI[T] Do Begin
  Y:=Y1+2+(I-1)*16;
  S:=GMn[H].IT[T,I];
  If (S<>'') And (Trim2(S)='-') Then Begin
   SetLineStyle(UserBitLn,$AAAA,1);SetColor(INK);Line(X1+2,Y+8,X2-2,Y+8);SetLineStyle(SolidLn,0,1);
  End Else Begin
   If (I=Hi) And (Not GMn[H].ID[T,I]) Then Begin
    Box(X1+1,Y,X2-1,Y+15,INK);WText16(X1+16,Y,S);
    If GMn[H].IC[T,I] Then WText16(X1+4,Y,#251);
   End Else Begin
    If GMn[H].ID[T,I] Then GreyText16(X1+16,Y,S) Else PText16(X1+16,Y,S);
    If GMn[H].IC[T,I] Then PText16(X1+4,Y,#251);
   End;
  End;
 End;
 ShowMouse;
End;

{ menu deroulant modal ; retourne True si un article est choisi }
Function GemMenuModal(H: Integer; Var RT,RI: Integer): Boolean;
Var Sv: TSave; E: TEvent; T,CT,I,Hi,MXp,MYp,X1,Y1,X2,Y2: Integer; Done,Pick: Boolean; Moved: Boolean;
Begin
 GemMenuModal:=False;RT:=0;RI:=0;
 OutFlush(True);
 HideMouse;
 SaveBack(Sv,0,OFS_Y,639,Min3(SCR_H-1,OFS_Y+GM_BAR+MAXMI*16+10));
 ShowMouse;
 CT:=0;Hi:=0;Done:=False;Pick:=False;
 Repeat
  PollEvent(E);
  MXp:=E.X;MYp:=E.Y-OFS_Y;
  T:=0;
  If (MYp>=0) And (MYp<GM_BAR) Then T:=MenuTitleAt(H,MXp);
  If (T<>0) And (T<>CT) Then Begin
   HideMouse;RestoreBack(Sv);SaveBack(Sv,0,OFS_Y,639,Min3(SCR_H-1,OFS_Y+GM_BAR+MAXMI*16+10));
   CT:=T;Hi:=0;
   Box(GMn[H].TX[T],OFS_Y,GMn[H].TX[T]+Length(GMn[H].TT[T])*8-1,OFS_Y+GM_BAR-2,INK);
   WText16(GMn[H].TX[T],OFS_Y+1,GMn[H].TT[T]);
   DrawDrop(H,T,0);
  End;
  If CT<>0 Then Begin
   X1:=GMn[H].TX[CT];
   If X1+DropWidth(H,CT)>636 Then X1:=636-DropWidth(H,CT);
   X2:=X1+DropWidth(H,CT);Y1:=GM_BAR-1;Y2:=Y1+GMn[H].NI[CT]*16+4;
   I:=0;
   If (MXp>=X1) And (MXp<=X2) And (MYp>=Y1+2) And (MYp<Y2-2) Then I:=(MYp-Y1-2) Div 16+1;
   If (I>GMn[H].NI[CT]) Then I:=0;
   If (I<>0) And (GMn[H].ID[CT,I] Or (Trim2(GMn[H].IT[CT,I])='-')) Then I:=0;
   If I<>Hi Then Begin Hi:=I;DrawDrop(H,CT,Hi);End;
   If (E.Kind=2) Or (E.Kind=3) Then Begin
    If Hi<>0 Then Begin Pick:=True;Done:=True;End
    Else If (T=0) And (E.Kind=2) Then Done:=True;
   End;
   If (T=0) And (Hi=0) And (E.Kind=4) Then
    If Not ((MXp>=X1-4) And (MXp<=X2+4) And (MYp>=0) And (MYp<=Y2+4)) Then Done:=True;
  End Else If (E.Kind=2) Or ((E.Kind=4) And ((MYp>=GM_BAR))) Then Done:=True;
 Until Done;
 HideMouse;RestoreBack(Sv);ShowMouse;
 If Pick Then Begin
  RT:=TitleObjOf(H,CT);RI:=GMn[H].IDn[CT,Hi];
  GemMenuModal:=True;
 End;
End;

{ ------------------------------ dialogues ------------------------------ }

Function DlgRect(D,I: Integer; Var X,Y,W,H: Integer): Boolean;
Begin
 X:=GDl[D].PX+GDl[D].Ob[I].PXo;Y:=GDl[D].PY+GDl[D].Ob[I].PYo;
 W:=GDl[D].Ob[I].PWo;H:=GDl[D].Ob[I].PHo;
 If I=0 Then Begin X:=GDl[D].PX;Y:=GDl[D].PY;End;
 DlgRect:=True;
End;

Procedure PaintObj(D,I: Integer);
Var X,Y,W,H,TX,B,K,J: Integer; S,T: String; Inv: Boolean; O: TGObj;
Begin
 O:=GDl[D].Ob[I];
 If O.Hidden Then Exit;
 DlgRect(D,I,X,Y,W,H);
 Y:=Y+OFS_Y;
 Inv:=(O.State And 1)<>0;
 S:=O.Txt;
 If ((O.Typ=29) Or (O.Typ=30)) And (O.Templ<>'') Then Begin
  T:='';K:=0;
  For B:=1 To Length(O.Templ) Do
   If O.Templ[B]='_' Then Begin
    Inc(K);
    If K<=Length(O.Txt) Then T:=T+O.Txt[K] Else T:='' + T + '_';
   End Else T:=T+O.Templ[B];
  S:=T;
 End;
 HideMouse;
 Case O.Typ Of
  20,22,25,26,30,29,21: Begin
    If (O.Typ=21) Or (O.Typ=29) Then Box(X,Y,X+W-1,Y+H-1,PAPER);
    If (O.Typ=20) Or (O.Typ=22) Or (O.Typ=25) Or (O.Typ=26) Or (O.Typ=30) Then Begin
     If O.Typ<>25 Then Begin
      If Inv Then Box(X,Y,X+W-1,Y+H-1,INK)
      Else If (O.Typ=20) And (O.Color<>0) And (((O.Color Shr 4) And 7)=7) And ((O.Color And 15)<>0) Then Box(X,Y,X+W-1,Y+H-1,INK)
      Else Box(X,Y,X+W-1,Y+H-1,PAPER);
     End;
     If (O.Typ=20) And (O.Border=0) And (I=0) Then Begin End;
     If O.Typ=26 Then Begin
      Frame(X,Y,X+W-1,Y+H-1);
      If (O.Flags And 2)<>0 Then Begin Frame(X-1,Y-1,X+W,Y+H);Frame(X-2,Y-2,X+W+1,Y+H+1);End;
      If (O.Border>1) Or (O.Border<-1) Then Frame(X+1,Y+1,X+W-2,Y+H-2);
     End Else If O.Border<>0 Then Begin
      B:=Abs(O.Border);
      For K:=0 To B-1 Do
       If O.Border>0 Then Frame(X+K,Y+K,X+W-1-K,Y+H-1-K) Else Frame(X-1-K,Y-1-K,X+W+K,Y+H+K);
     End;
    End;
    If S<>'' Then Begin
     TX:=X+2;
     If (O.Just=2) Or (O.Typ=26) Then TX:=X+(W-Length(S)*8) Div 2
     Else If O.Just=1 Then TX:=X+W-Length(S)*8-2;
     If Inv Then WText16(TX,Y+(H-16) Div 2,S)
     Else If (O.State And 8)<>0 Then GreyText16(TX,Y+(H-16) Div 2,S)
     Else PText16(TX,Y+(H-16) Div 2,S);
    End;
   End;
  23: Begin
    If Inv Then Box(X,Y,X+W-1,Y+H-1,INK);
    For K:=0 To O.ImgH-1 Do
     For B:=0 To O.ImgWB*8-1 Do
      If (ImgPool[O.ImgOff+K*O.ImgWB+(B Shr 3)] And (128 Shr (B And 7)))<>0 Then
       If (B+O.ImgX<W) And (K+O.ImgY<H) Then PutPixel(X+O.ImgX+B,Y+O.ImgY+K,Ord(Not Inv)*INK+Ord(Inv)*PAPER);
   End;
  31: Begin
    { icone : masque (fond blanc), donnees (noir), texte dessous }
    Box(X,Y,X+W-1,Y+H-1,PAPER);
    If Inv Then Box(X+O.IcX,Y+O.IcY,X+O.IcX+O.IcW-1,Y+O.IcY+O.IcH-1,INK);
    B:=((O.IcW+15) Div 16)*2;
    For K:=0 To O.IcH-1 Do
     For J:=0 To O.IcW-1 Do Begin
      If (ImgPool[O.MaskOff+K*B+(J Shr 3)] And (128 Shr (J And 7)))<>0 Then
       PutPixel(X+O.IcX+J,Y+O.IcY+K,PAPER*Ord(Not Inv)+INK*Ord(Inv));
      If (ImgPool[O.ImgOff+K*B+(J Shr 3)] And (128 Shr (J And 7)))<>0 Then
       PutPixel(X+O.IcX+J,Y+O.IcY+K,INK*Ord(Not Inv)+PAPER*Ord(Inv));
     End;
    If S<>'' Then Begin
     If Inv Then Box(X+O.TxX,Y+O.TxY,X+O.TxX+O.TxW-1,Y+O.TxY+O.TxH-1,INK);
     TX:=X+O.TxX+(O.TxW-Length(S)*8) Div 2;
     If Inv Then WText16(TX,Y+O.TxY+(O.TxH-16) Div 2,S) Else PText16(TX,Y+O.TxY+(O.TxH-16) Div 2,S);
    End;
   End;
  28: Begin
    If Inv Then Begin Box(X,Y,X+Length(S)*8,Y+15,INK);WText16(X,Y,S);End
    Else PText16(X,Y,S);
   End;
 End;
 If ((O.State And 4)<>0) And (O.Typ<>28) Then Begin
  SetColor(Ord(Inv));
  Line(X+1,Y+8,X+5,Y+13);Line(X+2,Y+8,X+5,Y+12);Line(X+5,Y+13,X+13,Y+1);Line(X+5,Y+12,X+12,Y+1);
 End;
 ShowMouse;
End;

Procedure PaintKids(D,P: Integer);
Var J: Integer;
Begin
 For J:=1 To GDl[D].N Do
  If (GDl[D].Ob[J].Parent=P) And (J<>P) Then Begin
   PaintObj(D,J);
   PaintKids(D,J);
  End;
End;

Procedure PaintDlg(D: Integer);
Var X,Y,W,H: Integer;
Begin
 DlgRect(D,0,X,Y,W,H);
 HideMouse;
 Box(X+4,Y+OFS_Y+4,X+W+4,Y+OFS_Y+H+4,INK);
 Box(X,Y+OFS_Y,X+W-1,Y+OFS_Y+H-1,PAPER);
 Frame(X,Y+OFS_Y,X+W-1,Y+OFS_Y+H-1);
 Frame(X+1,Y+OFS_Y+1,X+W-2,Y+OFS_Y+H-2);
 ShowMouse;
 PaintKids(D,0);
End;

Procedure RecalcHidden(D: Integer);
Var I,J,G: Integer;
Begin
 For I:=1 To GDl[D].N Do Begin
  GDl[D].Ob[I].Hidden:=False;
  J:=I;G:=0;
  While (J>0) And (G<=GDl[D].N) Do Begin
   If (GDl[D].Ob[J].Flags And $80)<>0 Then GDl[D].Ob[I].Hidden:=True;
   J:=GDl[D].Ob[J].Parent;Inc(G);
  End;
 End;
End;

Function ValidCh(V: Char; C: Char): Boolean;
Begin
 Case V Of
  '9': ValidCh:=(C>='0') And (C<='9');
  'A': ValidCh:=((C>='A') And (C<='Z')) Or (C=' ');
  'a': ValidCh:=((C>='A') And (C<='Z')) Or ((C>='a') And (C<='z')) Or (C=' ');
  'N': ValidCh:=((C>='0') And (C<='9')) Or ((C>='A') And (C<='Z')) Or (C=' ');
  'n': ValidCh:=((C>='0') And (C<='9')) Or ((C>='A') And (C<='Z')) Or ((C>='a') And (C<='z')) Or (C=' ');
 Else ValidCh:=C>=' ';
 End;
End;

Function DlgRun(D,Start: Integer): Integer;
Var E: TEvent; Done: Boolean; Fc,I,J,Hit,X,Y,W,H,R,Dbl: Integer; Sv: TSave; Own: Boolean; Ch: Char;
    Prev: Integer;
 Function NextEdit(From,Dir: Integer): Integer;
 Var K,N: Integer;
 Begin
  NextEdit:=From;K:=From;
  For N:=1 To GDl[D].N Do Begin
   K:=K+Dir;
   If K>GDl[D].N Then K:=1;
   If K<1 Then K:=GDl[D].N;
   If (GDl[D].Ob[K].Flags And 8)<>0 Then Begin NextEdit:=K;Exit;End;
  End;
 End;
Begin
 If Headless Then Begin
  { mode batch : on valide le bouton par defaut (sinon le premier bouton de sortie) }
  Hit:=0;
  For I:=1 To GDl[D].N Do If (Hit=0) And ((GDl[D].Ob[I].Flags And 6)=6) Then Hit:=I;
  For I:=1 To GDl[D].N Do If (Hit=0) And ((GDl[D].Ob[I].Flags And 4)<>0) Then Hit:=I;
  WriteLn('[DIALOG] -> ',Hit);
  DlgRun:=Hit;Exit;
 End;
 OutFlush(True);
 GemCur(True);
 Own:=Not GDl[D].Shown;
 DlgRect(D,0,X,Y,W,H);
 If Own Then Begin
  HideMouse;
  SaveBack(GDl[D].Sv,X,Y+OFS_Y,X+W+5,Y+OFS_Y+H+5);
  ShowMouse;
  GDl[D].Shown:=True;
  PaintDlg(D);
 End;
 Fc:=0;
 If (Start>0) And (Start<=GDl[D].N) And ((GDl[D].Ob[Start].Flags And 8)<>0) Then Fc:=Start
 Else Fc:=NextEdit(0,1);
 If Fc>0 Then Begin
  If (GDl[D].Ob[Fc].Txt='') And (Start=Fc) Then Begin End;
 End;
 Done:=False;R:=0;Dbl:=0;
 Repeat
  PollEvent(E);
  If E.Kind=1 Then Begin
   Case E.Key Of
    K_ENTER: Begin
      For I:=1 To GDl[D].N Do If ((GDl[D].Ob[I].Flags And 2)<>0) And (R=0) Then R:=I;
      If R<>0 Then Begin GDl[D].Ob[R].State:=GDl[D].Ob[R].State Or 1;PaintObj(D,R);Done:=True;End;
     End;
    K_TAB,K_DOWN: If Fc>0 Then Fc:=NextEdit(Fc,1);
    K_UP: If Fc>0 Then Fc:=NextEdit(Fc,-1);
    K_BKSP: If (Fc>0) And (Length(GDl[D].Ob[Fc].Txt)>0) Then Begin
      GDl[D].Ob[Fc].Txt[0]:=Chr(Length(GDl[D].Ob[Fc].Txt)-1);PaintObj(D,Fc);
     End;
   Else
    If (Fc>0) And (E.Key>=32) And (E.Key<256) Then Begin
     Ch:=Chr(E.Key);
     J:=0;
     For I:=1 To Length(GDl[D].Ob[Fc].Templ) Do If GDl[D].Ob[Fc].Templ[I]='_' Then Inc(J);
     If J=0 Then J:=GDl[D].Ob[Fc].W;
     I:=Length(GDl[D].Ob[Fc].Txt)+1;
     If (I<=J) And ((GDl[D].Ob[Fc].Valid='') Or (I>Length(GDl[D].Ob[Fc].Valid)) Or ValidCh(GDl[D].Ob[Fc].Valid[I],Ch)) Then Begin
      GDl[D].Ob[Fc].Txt:=GDl[D].Ob[Fc].Txt+Ch;PaintObj(D,Fc);
     End;
    End;
   End;
  End Else If E.Kind=2 Then Begin
   Hit:=0;
   For I:=1 To GDl[D].N Do Begin
    DlgRect(D,I,X,Y,W,H);
    If GDl[D].Ob[I].Typ=28 Then W:=Length(GDl[D].Ob[I].Txt)*8;
    If GDl[D].Ob[I].Typ=28 Then H:=16;
    If (Not GDl[D].Ob[I].Hidden) And InBox(E.X,E.Y-OFS_Y,X,Y,X+W-1,Y+H-1) Then Hit:=I;
   End;
   If Hit<>0 Then Begin
    I:=Hit;
    If (GDl[D].Ob[I].Flags And 8)<>0 Then Begin Fc:=I;End;
    If ((GDl[D].Ob[I].Flags And 1)<>0) And ((GDl[D].Ob[I].State And 8)=0) Then Begin
     If (GDl[D].Ob[I].Flags And $10)<>0 Then Begin
      For J:=1 To GDl[D].N Do
       If ((GDl[D].Ob[J].Flags And $10)<>0) And ((GDl[D].Ob[J].State And 1)<>0) And
          (GDl[D].Ob[J].Parent=GDl[D].Ob[I].Parent) Then Begin
        GDl[D].Ob[J].State:=GDl[D].Ob[J].State And (Not 1);PaintObj(D,J);
       End;
      GDl[D].Ob[I].State:=GDl[D].Ob[I].State Or 1;PaintObj(D,I);
     End Else If (GDl[D].Ob[I].Flags And 4)=0 Then Begin
      GDl[D].Ob[I].State:=GDl[D].Ob[I].State Xor 1;PaintObj(D,I);
     End Else Begin
      GDl[D].Ob[I].State:=GDl[D].Ob[I].State Or 1;PaintObj(D,I);
     End;
    End;
    If (GDl[D].Ob[I].Flags And ($4 Or $40))<>0 Then Begin
     { double clic ? }
     If NowCs-LastClkCs<40 Then Dbl:=$8000 Else Dbl:=0;
     LastClkCs:=NowCs;
     R:=I;Done:=True;
     Repeat GetMouseState(MX,MY,MB);Delay(5);Until (MB And 3)=0;
    End;
   End;
  End;
 Until Done Or QuitReq;
 If Own Then Begin
  HideMouse;RestoreBack(GDl[D].Sv);ShowMouse;GDl[D].Shown:=False;
 End;
 DlgRun:=R Or Dbl;
End;

{ ------------------------------ evenements ----------------------------- }

Function HitWin(MXp,MYp: Integer): Integer;
Var K: Integer;
Begin
 HitWin:=0;
 For K:=ZN DownTo 1 Do
  If GW[ZW[K]].Open Then
   If InBox(MXp,MYp,GW[ZW[K]].X,GW[ZW[K]].Y,GW[ZW[K]].X+GW[ZW[K]].W-1,GW[ZW[K]].Y+GW[ZW[K]].H-1) Then Begin
    HitWin:=ZW[K];Exit;
   End;
End;

Procedure RubberXor(X,Y,W,H: Integer);
Var I: Integer;
Begin
 OXor:=True;
 For I:=X To X+W-1 Do Begin OPlot(I,Y,1);OPlot(I,Y+H-1,1);End;
 For I:=Y+1 To Y+H-2 Do Begin OPlot(X,I,1);OPlot(X+W-1,I,1);End;
 OXor:=False;
End;

{ glisse un rectangle : Mode 0 deplacement, 1 changement de taille }
Procedure RubberDrag(I,Mode: Integer; Var NX,NY,NW,NH: Integer);
Var X0,Y0,CX,CY,DX,DY: Integer; Mx0,My0: LongInt;
Begin
 GetMouseState(MX,MY,MB);
 Mx0:=MX;My0:=MY;
 NX:=GW[I].X;NY:=GW[I].Y;NW:=GW[I].W;NH:=GW[I].H;
 X0:=NX;Y0:=NY;
 GBegin(0,0,640,400,False);
 RubberXor(NX,NY,NW,NH);GFlush;
 While (MB And 3)<>0 Do Begin
  GetMouseState(MX,MY,MB);
  DX:=MX-Mx0;DY:=MY-My0;
  CX:=NX;CY:=NY;
  If Mode=0 Then Begin
   NX:=X0+DX;NY:=Y0+DY;
   If NY<GM_BAR Then NY:=GM_BAR;
  End Else Begin
   NW:=GW[I].W+DX;NH:=GW[I].H+DY;
   If NW<60 Then NW:=60;
   If NH<40 Then NH:=40;
   If NW>GW[I].MW Then NW:=GW[I].MW;
   If NH>GW[I].MH Then NH:=GW[I].MH;
  End;
  If (CX<>NX) Or (CY<>NY) Or (Mode=1) Then Begin
   GBegin(0,0,640,400,False);
   RubberXor(CX,CY,GW[I].W+DX*Mode,GW[I].H+DY*Mode);
   RubberXor(NX,NY,NW,NH);
   GEnd;GFlush;
  End;
  Delay(15);
 End;
 GBegin(0,0,640,400,False);
 RubberXor(NX,NY,NW,NH);
 GEnd;
 GFlush;
End;

Function WinClick(MXp,MYp: Integer): Boolean;
{ gere un clic dans une fenetre ; True si le clic a ete consomme }
Var H,K,X,Y,W,Hh,WX,WY,WW2,WH,NX,NY,NW,NH,Pos,TL,TH: Integer; Kd: Integer;
Begin
 WinClick:=False;
 H:=HitWin(MXp,MYp);
 If H=0 Then Exit;
 If TopWin<>H Then Begin PushMsg(21,H,0,0,0,0);WinClick:=True;Exit;End;
 Kd:=GW[H].Kind;
 X:=GW[H].X;Y:=GW[H].Y;W:=GW[H].W;Hh:=GW[H].H;
 WinWork(H,WX,WY,WW2,WH);
 If InBox(MXp,MYp,WX,WY,WX+WW2-1,WY+WH-1) Then Exit;    { zone de travail : evenement bouton }
 WinClick:=True;
 If (Kd And $E)<>0 Then
  If (MYp>=Y) And (MYp<Y+19) Then Begin
   If ((Kd And 2)<>0) And (MXp<X+19) Then Begin
    Repeat GetMouseState(MX,MY,MB);Delay(5);Until (MB And 3)=0;
    PushMsg(22,H,0,0,0,0);Exit;
   End;
   If ((Kd And 4)<>0) And (MXp>=X+W-19) Then Begin
    Repeat GetMouseState(MX,MY,MB);Delay(5);Until (MB And 3)=0;
    PushMsg(23,H,0,0,0,0);Exit;
   End;
   If (Kd And 8)<>0 Then Begin
    RubberDrag(H,0,NX,NY,NW,NH);
    PushMsg(28,H,NX,NY,NW,NH);
   End;
   Exit;
  End;
 If ((Kd And $20)<>0) And (MXp>=X+W-19) And (MYp>=Y+Hh-19) Then Begin
  RubberDrag(H,1,NX,NY,NW,NH);
  PushMsg(27,H,NX,NY,NW,NH);
  Exit;
 End;
 { barre verticale }
 If HasV(Kd) And (MXp>=X+W-19) Then Begin
  If ((Kd And $40)<>0) And (MYp<WY+18) Then PushMsg(24,H,2,0,0,0)
  Else If ((Kd And $80)<>0) And (MYp>=WY+WH-18) And (MYp<WY+WH) Then PushMsg(24,H,3,0,0,0)
  Else If (Kd And $100)<>0 Then Begin
   TL:=WY+18;TH:=WH-36;
   Pos:=1;
   If TH>0 Then Pos:=Max3(1,Min3(1000,(MYp-TL)*1000 Div TH));
   PushMsg(26,H,Pos,0,0,0);
  End;
  Repeat GetMouseState(MX,MY,MB);Delay(5);Until (MB And 3)=0;
  Exit;
 End;
 If HasH(Kd) And (MYp>=WY+WH) Then Begin
  If ((Kd And $200)<>0) And (MXp<WX+18) Then PushMsg(24,H,6,0,0,0)
  Else If ((Kd And $400)<>0) And (MXp>=WX+WW2-18) Then PushMsg(24,H,7,0,0,0)
  Else If (Kd And $800)<>0 Then Begin
   TL:=WX+18;TH:=WW2-36;Pos:=1;
   If TH>0 Then Pos:=Max3(1,Min3(1000,(MXp-TL)*1000 Div TH));
   PushMsg(25,H,Pos,0,0,0);
  End;
  Repeat GetMouseState(MX,MY,MB);Delay(5);Until (MB And 3)=0;
 End;
End;

Var HeadIdle: LongInt;

Function GemEvent(Mask,BMask,BState,NClk: LongInt; Ticks: LongInt; R1f: Boolean; R1x,R1y,R1w,R1h: LongInt;
                  R2f: Boolean; R2x,R2y,R2w,R2h: LongInt;
                  PMsg,PKey,PBst,PBcnt,PMx,PMy,PKbd: LongInt): LongInt;
Var Ret,I,Cnt,T,Ti: Integer; E: TEvent; T0: LongInt; Kc: LongInt; MXp,MYp: LongInt; Ins1,Ins2: Boolean;
    LastIn1,LastIn2: Boolean; Picked: Boolean; RT,RI: Integer; Bs: LongInt;
Begin
 Ret:=0;T0:=NowCs;Cnt:=0;LastKbd:=0;
 If Headless Then Begin
  { mode batch : pas de souris ni de clavier ; seuls les messages en attente et le
    minuteur peuvent reveiller le programme }
  For I:=0 To 7 Do PutW(PMsg+I*2,0);
  PutW(PKey,0);PutW(PBst,0);PutW(PBcnt,0);PutW(PMx,0);PutW(PMy,0);PutW(PKbd,0);
  If ((Mask And 16)<>0) And (MsgN>0) Then Begin
   For I:=0 To 7 Do PutW(PMsg+I*2,MsgQ[1,I]);
   For I:=2 To MsgN Do MsgQ[I-1]:=MsgQ[I];
   Dec(MsgN);
   GemEvent:=16;Exit;
  End;
  Inc(HeadIdle);
  If ((Mask And 32)<>0) And (HeadIdle<20000) Then Begin GemEvent:=32;Exit;End;
  EmuMsg:=T3('Batch mode: the program waits for a mouse or keyboard event',
             'Mode batch : le programme attend un '#130'v'#130'nement souris ou clavier',
             'Batch-Modus: das Programm wartet auf ein Maus- oder Tastaturereignis');
  EmuHalt:=True;EmuCode:=-1;
  GemEvent:=0;Exit;
 End;
 GemCur(True);
 GetMouseState(MX,MY,MB);
 LastIn1:=R1f;LastIn2:=R2f;    { evenement immediat si la condition est deja vraie }
 Bs:=MB And 3;
 Repeat
  If ((Mask And 16)<>0) And (MsgN>0) Then Begin
   For I:=0 To 7 Do PutW(PMsg+I*2,MsgQ[1,I]);
   For I:=2 To MsgN Do MsgQ[I-1]:=MsgQ[I];
   Dec(MsgN);
   Ret:=Ret Or 16;
  End;
  PollEvent(E);
  MXp:=E.X;MYp:=E.Y-OFS_Y;
  Case E.Kind Of
   1: If (Mask And 1)<>0 Then Begin
       If E.Key>=256 Then Kc:=(LongInt(E.Key-256) Shl 8) Else Kc:=E.Key;
       If (E.Key<256) And (E.Key>=32) Then Kc:=E.Key;
       If E.Key=K_ENTER Then Kc:=$1C0D;
       If E.Key=K_BKSP Then Kc:=$0E08;
       If E.Key=K_ESC Then Kc:=$011B;
       If AesKeyScan Then Kc:=KeyToAes(E.Key);
       LastKbd:=KbdOfKey(E.Key);
       PutW(PKey,Kc);Ret:=Ret Or 1;
      End;
   2: Begin
       If (MYp>=0) And (MYp<GM_BAR) And (ActMenu>0) And GMn[ActMenu].Drawn Then Begin
        If GemMenuModal(ActMenu,RT,RI) Then Begin
         If RI>=9999 Then Begin EmuBrk:=True;BreakReq:=True;End
         Else If RI>=1000 Then PushMsg(40,0,RI,0,0,0)
         Else Begin GMn[ActMenu].Hi:=RT;GemBarRedraw;PushMsg(10,RT,RI,0,0,0);End;
        End;
       End Else If Not WinClick(MXp,MYp) Then Begin
        If (Mask And 2)<>0 Then Begin
         If NowCs-LastClkCs<40 Then Inc(Cnt) Else Cnt:=1;
         LastClkCs:=NowCs;
         If ((BState And BMask And 3)<>0) And (Cnt>=NClk) Then Begin
          Ret:=Ret Or 2;Bs:=E.B And 3;
         End;
        End;
       End;
      End;
   3: If ((Mask And 2)<>0) And ((BState And BMask And 3)=0) And ((BMask And 3)<>0) Then Begin
       Ret:=Ret Or 2;Bs:=0;Cnt:=1;
      End;
   4: If (MYp>=0) And (MYp<GM_BAR) And (ActMenu>0) And GMn[ActMenu].Drawn And ((E.B And 3)=0) Then Begin
       If MenuTitleAt(ActMenu,MXp)<>0 Then Begin
        If GemMenuModal(ActMenu,RT,RI) Then Begin
         If RI>=9999 Then Begin EmuBrk:=True;BreakReq:=True;End
         Else If RI>=1000 Then PushMsg(40,0,RI,0,0,0)
         Else Begin GMn[ActMenu].Hi:=RT;GemBarRedraw;PushMsg(10,RT,RI,0,0,0);End;
        End;
       End;
      End;
  End;
  If ((Mask And 4)<>0) Then Begin
   Ins1:=InBox(MXp,MYp,R1x,R1y,R1x+R1w-1,R1y+R1h-1);
   If (Ins1<>LastIn1) And (Ins1<>R1f) Then Ret:=Ret Or 4;
   LastIn1:=Ins1;
  End;
  If ((Mask And 8)<>0) Then Begin
   Ins2:=InBox(MXp,MYp,R2x,R2y,R2x+R2w-1,R2y+R2h-1);
   If (Ins2<>LastIn2) And (Ins2<>R2f) Then Ret:=Ret Or 8;
   LastIn2:=Ins2;
  End;
  If (Mask And 32)<>0 Then
   If (NowCs-T0)*10>=Ticks Then Ret:=Ret Or 32;
  If MsgN>0 Then OutFlush(False);
  If (Ret=0) And (E.Kind=0) Then Begin OutFlush(False);Delay(3);End;
 Until (Ret<>0) Or QuitReq Or BreakReq;
 GetMouseState(MX,MY,MB);
 PutW(PBst,MB And 3);PutW(PBcnt,Cnt);PutW(PMx,MX);PutW(PMy,MY-OFS_Y);
 PutW(PKbd,LastKbd);
 If (Mask And 1)=0 Then PutW(PKey,0);
 GemEvent:=Ret;
End;


{ ------------------- ressources GEM (.RSC) et accessoires --------------- }

Const MAXACC = 6;

Var
 RscBuf  : PByteArr;
 RscSize : LongInt;
 RscOk   : Boolean;
 AccN    : Integer;
 AccName : Array[1..MAXACC] Of String[40];

Function RscW(O: LongInt): LongInt;
Begin
 If (O<0) Or (O+1>=RscSize) Then RscW:=0 Else RscW:=(LongInt(RscBuf^[O]) Shl 8) Or RscBuf^[O+1];
End;

Function RscSW(O: LongInt): LongInt;
Var V: LongInt;
Begin
 V:=RscW(O);
 If V>32767 Then V:=V-65536;
 RscSW:=V;
End;

Function RscL(O: LongInt): LongInt;
Begin
 RscL:=(RscW(O) Shl 16) Or RscW(O+2);
End;

Function RscStr(O: LongInt): String;
Var S: String;
Begin
 S:='';
 If (O>0) And (O<RscSize) Then
  While (O<RscSize) And (RscBuf^[O]<>0) And (Length(S)<200) Do Begin S:=S+Chr(RscBuf^[O]);Inc(O);End;
 RscStr:=S;
End;

Function RscFix(V: LongInt; Cell: Integer): Integer;
Var Hi: Integer;
Begin
 Hi:=(V Shr 8) And 255;
 If Hi>127 Then Hi:=Hi-256;
 RscFix:=(V And 255)*Cell+Hi;
End;

Function LoadRsc(Const Nm: String): Boolean;
Var F: File; N: Word; Fn: String;
Begin
 LoadRsc:=False;RscOk:=False;
 Fn:=ResolveFile(Nm);
 If Not FileExists(Fn) Then Exit;
 Assign(F,Fn);
 {$I-}Reset(F,1);{$I+}
 If IOResult<>0 Then Exit;
 If FileSize(F)>65500 Then Begin Close(F);Exit;End;
 If RscBuf=Nil Then GetMem(RscBuf,65536);
 BlockRead(F,RscBuf^,65500,N);
 Close(F);
 RscSize:=N;
 If RscSize<36 Then Exit;
 RscOk:=True;LoadRsc:=True;PoolN:=0;
End;

Function RscTreeOff(T: Integer): LongInt;
Begin
 If (Not RscOk) Or (T<0) Or (T>=RscW(22)) Then RscTreeOff:=0
 Else RscTreeOff:=RscL(RscW(18)+4*T);
End;

Function RscTreeCount(T: Integer): Integer;
Var TO_,Lim,O: LongInt; I: Integer;
Begin
 TO_:=RscTreeOff(T);
 Lim:=RscW(4);
 If Lim<=TO_ Then Lim:=RscSize;
 For I:=0 To RscW(22)-1 Do Begin
  O:=RscL(RscW(18)+4*I);
  If (O>TO_) And (O<Lim) Then Lim:=O;
 End;
 If (RscW(10)>TO_) And (RscW(10)<Lim) Then Lim:=RscW(10);
 RscTreeCount:=Min3(MAXGO+1,(Lim-TO_) Div 24);
End;

Function RscDialog(T: Integer): Integer;
Var D,I,J,G,N,C: Integer; TO_,Off: LongInt; Nx,Hd,Par: Array[0..MAXGO] Of Integer; Fl: LongInt;
    Reach: Array[0..MAXGO] Of Boolean; Q: Array[0..MAXGO] Of Integer; QH,QT: Integer;
    AX,AY: Integer; Ted: LongInt; S: String; K: Integer; Spec: LongInt;
Begin
 RscDialog:=0;
 TO_:=RscTreeOff(T);
 If TO_=0 Then Exit;
 D:=0;
 For I:=1 To MAXGD Do If (Not GDl[I].Used) And (D=0) Then D:=I;
 If D=0 Then Exit;
 N:=RscTreeCount(T);
 If N<1 Then Exit;
 For I:=0 To N-1 Do Begin
  Off:=TO_+24*I;
  Nx[I]:=RscSW(Off);Hd[I]:=RscSW(Off+2);Par[I]:=-1;Reach[I]:=False;
 End;
 FillChar(GDl[D],SizeOf(TGDlg),0);
 GDl[D].Used:=True;
 QH:=0;QT:=1;Q[0]:=0;Reach[0]:=True;
 While QH<QT Do Begin
  I:=Q[QH];Inc(QH);
  If Hd[I]>=0 Then Begin
   C:=Hd[I];G:=0;
   While (C>=0) And (C<N) And (C<>I) And (G<=N) Do Begin
    If Not Reach[C] Then Begin Reach[C]:=True;Par[C]:=I;If QT<=MAXGO Then Begin Q[QT]:=C;Inc(QT);End;End;
    C:=Nx[C];Inc(G);
   End;
  End;
 End;
 GDl[D].N:=N-1;
 For I:=0 To N-1 Do Begin
  Off:=TO_+24*I;
  Spec:=RscL(Off+12);
  GDl[D].Ob[I].Typ:=RscW(Off+6) And 255;
  GDl[D].Ob[I].Flags:=RscW(Off+8);
  GDl[D].Ob[I].State:=RscW(Off+10);
  AX:=0;AY:=0;J:=I;G:=0;
  While (J>0) And (G<=N) Do Begin
   AX:=AX+RscFix(RscW(TO_+24*J+16),8);AY:=AY+RscFix(RscW(TO_+24*J+18),16);
   J:=Par[J];Inc(G);
  End;
  GDl[D].Ob[I].PXo:=AX;GDl[D].Ob[I].PYo:=AY;
  GDl[D].Ob[I].PWo:=RscFix(RscW(Off+20),8);GDl[D].Ob[I].PHo:=RscFix(RscW(Off+22),16);
  If Par[I]>=0 Then GDl[D].Ob[I].Parent:=Par[I] Else GDl[D].Ob[I].Parent:=0;
  If Not Reach[I] Then GDl[D].Ob[I].Hidden:=True;
  J:=I;G:=0;
  While (J>=0) And (G<=N) Do Begin
   If (RscW(TO_+24*J+8) And $80)<>0 Then GDl[D].Ob[I].Hidden:=True;
   J:=Par[J];Inc(G);
  End;
  Case GDl[D].Ob[I].Typ Of
   20,25,27: Begin
     GDl[D].Ob[I].Border:=ShortInt((Spec Shr 16) And 255);
     GDl[D].Ob[I].Color:=Spec And $FFFF;
     If GDl[D].Ob[I].Typ=27 Then GDl[D].Ob[I].Txt:=Chr((Spec Shr 24) And 255);
    End;
   21,22,29,30: Begin
     Ted:=Spec;
     S:=RscStr(RscL(Ted));
     K:=0;
     For J:=1 To Length(S) Do If (S[J]<>'_') And (S[J]<>'@') Then K:=1;
     If (GDl[D].Ob[I].Flags And 8)<>0 Then Begin If K=0 Then S:='';End
     Else If S='@' Then S:='';
     GDl[D].Ob[I].Txt:=Copy(S,1,60);
     GDl[D].Ob[I].Templ:=Copy(RscStr(RscL(Ted+4)),1,40);
     GDl[D].Ob[I].Valid:=Copy(RscStr(RscL(Ted+8)),1,40);
     GDl[D].Ob[I].Just:=RscW(Ted+18);
     If GDl[D].Ob[I].Just>2 Then GDl[D].Ob[I].Just:=0;
     GDl[D].Ob[I].Border:=RscSW(Ted+24);
     GDl[D].Ob[I].Color:=RscW(Ted+20);
    End;
   26,28,32: GDl[D].Ob[I].Txt:=Copy(RscStr(Spec),1,60);
   23: Begin
     K:=RscW(Spec+4)*RscW(Spec+6);
     If (K>0) And (PoolN+K<65000) Then Begin
      GDl[D].Ob[I].ImgOff:=PoolN;GDl[D].Ob[I].ImgWB:=RscW(Spec+4);GDl[D].Ob[I].ImgH:=RscW(Spec+6);
      GDl[D].Ob[I].ImgX:=RscW(Spec+8);GDl[D].Ob[I].ImgY:=RscW(Spec+10);
      For J:=0 To K-1 Do ImgPool[PoolN+J]:=RscBuf^[RscL(Spec)+J];
      PoolN:=PoolN+K;
     End Else GDl[D].Ob[I].Hidden:=True;
    End;
   31: Begin
     GDl[D].Ob[I].IcX:=RscW(Spec+18);GDl[D].Ob[I].IcY:=RscW(Spec+20);
     GDl[D].Ob[I].IcW:=RscW(Spec+22);GDl[D].Ob[I].IcH:=RscW(Spec+24);
     GDl[D].Ob[I].TxX:=RscW(Spec+26);GDl[D].Ob[I].TxY:=RscW(Spec+28);
     GDl[D].Ob[I].TxW:=RscW(Spec+30);GDl[D].Ob[I].TxH:=RscW(Spec+32);
     GDl[D].Ob[I].Txt:=Copy(RscStr(RscL(Spec+8)),1,60);
     K:=((GDl[D].Ob[I].IcW+15) Div 16)*2*GDl[D].Ob[I].IcH;
     If (K>0) And (PoolN+2*K<65000) Then Begin
      GDl[D].Ob[I].MaskOff:=PoolN;
      For J:=0 To K-1 Do ImgPool[PoolN+J]:=RscBuf^[RscL(Spec)+J];
      PoolN:=PoolN+K;
      GDl[D].Ob[I].ImgOff:=PoolN;
      For J:=0 To K-1 Do ImgPool[PoolN+J]:=RscBuf^[RscL(Spec+4)+J];
      PoolN:=PoolN+K;
     End Else GDl[D].Ob[I].Hidden:=True;
    End;
  End;
 End;
 GDl[D].PX:=GDl[D].Ob[0].PXo;GDl[D].PY:=GDl[D].Ob[0].PYo;
 GDl[D].Ob[0].PXo:=0;GDl[D].Ob[0].PYo:=0;
 RscDialog:=D;
End;

Procedure SyncAcc(H: Integer);
Var NI,K: Integer;
Begin
 NI:=GMn[H].NI[1];
 While (NI>0) And ((GMn[H].IDn[1,NI]>=1000) Or (GMn[H].IDn[1,NI]=8998) Or (GMn[H].IDn[1,NI]=8999)) Do Dec(NI);
 If (AccN>0) And (NI<12) Then Begin
  Inc(NI);GMn[H].IT[1,NI]:='-';GMn[H].IDn[1,NI]:=8999;GMn[H].ID[1,NI]:=True;GMn[H].IC[1,NI]:=False;
  For K:=1 To AccN Do If NI<MAXMI Then Begin
   Inc(NI);GMn[H].IT[1,NI]:=AccName[K];GMn[H].IDn[1,NI]:=1000+K;GMn[H].ID[1,NI]:=False;GMn[H].IC[1,NI]:=False;
  End;
 End;
 If (H=MAXGMN) And (NI<12) Then Begin
  Inc(NI);GMn[H].IT[1,NI]:='-';GMn[H].IDn[1,NI]:=8998;GMn[H].ID[1,NI]:=True;GMn[H].IC[1,NI]:=False;
  Inc(NI);GMn[H].IT[1,NI]:=T3('  Quit emulation','  Quitter l''emulation','  Emulation beenden');
  GMn[H].IDn[1,NI]:=9999;GMn[H].ID[1,NI]:=False;GMn[H].IC[1,NI]:=False;
 End;
 GMn[H].NI[1]:=NI;
End;

Procedure SysMenuOn;
Var H: Integer;
Begin
 H:=MAXGMN;
 FillChar(GMn[H],SizeOf(TGMenu),0);
 GMn[H].Used:=True;GMn[H].NT:=1;GMn[H].TT[1]:=' Desk ';
 GMn[H].NI[1]:=1;GMn[H].IT[1,1]:=T3('  Atari ST desktop','  Bureau Atari ST','  Atari-ST-Desktop');
 GMn[H].IDn[1,1]:=10;GMn[H].ID[1,1]:=True;
 SyncAcc(H);
 MenuLayout(H);
 GMn[H].Drawn:=True;ActMenu:=H;
 GemBarRedraw;
End;

Procedure MenuBackToSys;
Begin
 ActMenu:=0;
 If AccN>0 Then SysMenuOn Else GemBarRedraw;
End;

Function RscMenu(T: Integer): Integer;
Var H,I,K,Bar,Tit,Scr,B,C,G,It: Integer; TO_,Off: LongInt; S: String;
 Function Nx(O: Integer): Integer;
 Begin Nx:=RscSW(TO_+24*O); End;
 Function Hd(O: Integer): Integer;
 Begin Hd:=RscSW(TO_+24*O+2); End;
Begin
 RscMenu:=0;
 TO_:=RscTreeOff(T);
 If TO_=0 Then Exit;
 H:=0;
 For I:=1 To MAXGMN-1 Do If (Not GMn[I].Used) And (H=0) Then H:=I;
 If H=0 Then Exit;
 FillChar(GMn[H],SizeOf(TGMenu),0);
 GMn[H].Used:=True;
 Bar:=Hd(0);Tit:=Hd(Bar);Scr:=Nx(Bar);
 { titres }
 C:=Hd(Tit);G:=0;
 While (C>=0) And (C<>Tit) And (G<MAXMT) Do Begin
  Inc(G);
  GMn[H].TT[G]:=Copy(RscStr(RscL(TO_+24*C+12)),1,30);
  C:=Nx(C);
 End;
 GMn[H].NT:=G;
 { menus deroulants }
 B:=Hd(Scr);K:=0;
 While (B>=0) And (B<>Scr) And (K<G) Do Begin
  Inc(K);
  It:=Hd(B);
  While (It>=0) And (It<>B) And (GMn[H].NI[K]<MAXMI) Do Begin
   S:=RscStr(RscL(TO_+24*It+12));
   If Pos('Desk Accessory',S)=0 Then Begin
    Inc(GMn[H].NI[K]);
    If (RscW(TO_+24*It+10) And 8)<>0 Then Begin
     If (S<>'') And (S[1]='-') Then GMn[H].IT[K,GMn[H].NI[K]]:='-'
     Else Begin GMn[H].IT[K,GMn[H].NI[K]]:=Copy(S,1,40);GMn[H].ID[K,GMn[H].NI[K]]:=True;End;
    End Else GMn[H].IT[K,GMn[H].NI[K]]:=Copy(S,1,40);
    If (RscW(TO_+24*It+10) And 4)<>0 Then GMn[H].IC[K,GMn[H].NI[K]]:=True;
    GMn[H].IDn[K,GMn[H].NI[K]]:=It;
   End;
   It:=Nx(It);
  End;
  B:=Nx(B);
 End;
 RscMenu:=H;
End;

{ ------------------------- point d'entree des services ----------------- }

Function CopyPStr(A: LongInt): String;
Begin
 CopyPStr:=GetPS(A);
End;

Procedure ClearGem;
Var I: Integer;
Begin
 FillChar(GW,SizeOf(GW),0);
 FillChar(GMn,SizeOf(GMn),0);
 For I:=1 To MAXGD Do GDl[I].Used:=False;
 AccN:=0;ZN:=0;MsgN:=0;CurWin:=0;OrgX:=0;OrgY:=0;ActMenu:=0;NextItemId:=20;
 RectN:=0;RectI:=0;LastClkCs:=0;
End;

Function GemService(Sv: Integer): Boolean;
Var A,B,C,D,E,F,G,H,I,J,K: LongInt; S: String; Ok: Boolean; RT,RI: Integer; Av: Array[1..22] Of LongInt;
    X1,Y1,W1,H1: Integer; R1,R2,R3: TRct; PS,PN: String;
Begin
 GemService:=True;
 Case Sv Of
  S_NEWMENU: Begin
    B:=Pop32;A:=Pop32;
    I:=0;
    For J:=1 To MAXGMN-1 Do If (Not GMn[J].Used) And (I=0) Then I:=J;
    If I=0 Then RD[0]:=0 Else Begin
     FillChar(GMn[I],SizeOf(TGMenu),0);
     GMn[I].Used:=True;GMn[I].NT:=1;GMn[I].TT[1]:=' Desk ';GMn[I].Hi:=0;
     GMn[I].NI[1]:=1;GMn[I].IT[1,1]:=GetPS(B);GMn[I].IDn[1,1]:=10;
     RD[0]:=I;
    End;
   End;
  S_DELMENU: Begin A:=Pop32;If (A>=1) And (A<MAXGMN) Then Begin GMn[A].Used:=False;If ActMenu=A Then MenuBackToSys;End;End;
  S_ADDMTITLE: Begin
    B:=Pop32;A:=Pop32;
    If (A>=1) And (A<=MAXGMN) And (GMn[A].NT<MAXMT) Then Begin
     Inc(GMn[A].NT);GMn[A].TT[GMn[A].NT]:=GetPS(B);RD[0]:=GMn[A].NT+2;
    End Else RD[0]:=-1;
   End;
  S_ADDMITEM: Begin
    C:=Pop32;B:=Pop32;A:=Pop32;
    If (A>=1) And (A<=MAXGMN) And (B>=3) And (B-2<=GMn[A].NT) And (GMn[A].NI[B-2]<MAXMI) Then Begin
     Inc(GMn[A].NI[B-2]);
     GMn[A].IT[B-2,GMn[A].NI[B-2]]:=GetPS(C);
     GMn[A].IDn[B-2,GMn[A].NI[B-2]]:=NextItemId;
     RD[0]:=NextItemId;Inc(NextItemId);
    End Else RD[0]:=-1;
   End;
  S_DRAWMENU: Begin
    A:=Pop32;
    If (A>=1) And (A<=MAXGMN) Then Begin
     SyncAcc(A);MenuLayout(A);GMn[A].Drawn:=True;ActMenu:=A;
     GemBarRedraw;
    End;
   End;
  S_ERASEMENU: Begin
    A:=Pop32;
    If (A>=1) And (A<MAXGMN) Then Begin GMn[A].Drawn:=False;If ActMenu=A Then MenuBackToSys Else GemBarRedraw;End;
   End;
  S_MENUHI,S_MENUNORMAL: Begin
    B:=Pop32;A:=Pop32;
    If (A>=1) And (A<=MAXGMN) Then Begin
     If Sv=S_MENUHI Then GMn[A].Hi:=B Else GMn[A].Hi:=0;
     GemBarRedraw;
    End;
   End;
  S_MENUCHECK: Begin
    C:=Pop32;B:=Pop32;A:=Pop32;
    If (A>=1) And (A<=MAXGMN) Then
     For I:=1 To GMn[A].NT Do For J:=1 To GMn[A].NI[I] Do If GMn[A].IDn[I,J]=B Then GMn[A].IC[I,J]:=(C<>0);
   End;
  S_MENUENABLE,S_MENUDISABLE: Begin
    B:=Pop32;A:=Pop32;
    If (A>=1) And (A<=MAXGMN) Then
     For I:=1 To GMn[A].NT Do For J:=1 To GMn[A].NI[I] Do If GMn[A].IDn[I,J]=B Then GMn[A].ID[I,J]:=(Sv=S_MENUDISABLE);
   End;
  S_MENUTEXT: Begin
    C:=Pop32;B:=Pop32;A:=Pop32;
    If (A>=1) And (A<=MAXGMN) Then
     For I:=1 To GMn[A].NT Do For J:=1 To GMn[A].NI[I] Do If GMn[A].IDn[I,J]=B Then GMn[A].IT[I,J]:=GetPS(C);
   End;
  S_MENUREG: Begin
    B:=Pop32;A:=Pop32;
    If AccN<MAXACC Then Begin
     Inc(AccN);AccName[AccN]:=Copy(GetPS(B),1,40);RD[0]:=1000+AccN;
     If ActMenu=0 Then SysMenuOn
     Else Begin SyncAcc(ActMenu);MenuLayout(ActMenu);GemBarRedraw;End;
    End Else RD[0]:=-1;
   End;
  S_LOADRSC: Begin A:=Pop32;If LoadRsc(GetPS(A)) Then RD[0]:=1 Else RD[0]:=0;End;
  S_FREERSC: RscOk:=False;
  S_FINDMENU: Begin B:=Pop32;A:=Pop32;WL(B,RscMenu(A));End;
  S_FINDDLG: Begin B:=Pop32;A:=Pop32;WL(B,RscDialog(A));End;
  S_FINDALERT: Begin
    B:=Pop32;A:=Pop32;
    If RscOk And (A>=0) And (A<RscW(30)) Then PutPS(B,RscStr(RscL(RscW(10)+4*A)),255) Else PutPS(B,'',255);
   End;
  S_NEWWIN: Begin
    H:=Pop32;G:=Pop32;F:=Pop32;E:=Pop32;B:=Pop32;A:=Pop32;
    I:=NewGWin;
    If I<0 Then RD[0]:=-1 Else Begin
     GW[I].Kind:=A;GW[I].Title:=GetPS(B);
     DeskRect(X1,Y1,W1,H1);
     If (G<=0) Or (H<=0) Then Begin GW[I].MX:=0;GW[I].MY:=Y1;GW[I].MW:=W1;GW[I].MH:=H1;End
     Else Begin GW[I].MX:=E;GW[I].MY:=F;GW[I].MW:=G;GW[I].MH:=H;End;
     GW[I].HS:=0;GW[I].VS:=0;GW[I].HSz:=1000;GW[I].VSz:=1000;
     RD[0]:=I;
    End;
   End;
  S_OPENWIN: Begin
    E:=Pop32;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    If (A>=1) And (A<=MAXGW) And GW[A].Used Then Begin
     If (D<=0) Or (E<=0) Then Begin
      If GW[A].MW<640 Then Begin B:=GW[A].MX+20;C:=GW[A].MY+10;D:=GW[A].MW-40;E:=GW[A].MH-20;End
      Else Begin B:=0;C:=0;D:=0;E:=0;End;
     End;
     WinOpen(A,B,C,D,E);
    End;
   End;
  S_CLOSEWIN: Begin A:=Pop32;If (A>=1) And (A<=MAXGW) Then WinClose(A);End;
  S_DELWIN: Begin A:=Pop32;If (A>=1) And (A<=MAXGW) Then Begin If GW[A].Open Then WinClose(A);GW[A].Used:=False;End;End;
  S_SETWSIZE: Begin
    E:=Pop32;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    If (A>=1) And (A<=MAXGW) Then WinSetSize(A,B,C,D,E);
   End;
  S_SETWNAME: Begin
    B:=Pop32;A:=Pop32;
    If (A>=1) And (A<=MAXGW) And GW[A].Used Then Begin
     GW[A].Title:=GetPS(B);
     If GW[A].Open Then GemRefresh(GW[A].X,GW[A].Y,GW[A].W,20,False);
    End;
   End;
  S_SETWINFO: Begin
    B:=Pop32;A:=Pop32;
    If (A>=1) And (A<=MAXGW) And GW[A].Used Then Begin
     GW[A].Info:=GetPS(B);
     If GW[A].Open Then GemRefresh(GW[A].X,GW[A].Y,GW[A].W,GW[A].H,False);
    End;
   End;
  S_BORDERRECT,S_WORKRECT: Begin
    E:=Pop32;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    If (A<=0) Or (A>MAXGW) Then Begin
     DeskRect(X1,Y1,W1,H1);
     If Sv=S_BORDERRECT Then Begin X1:=0;Y1:=0;W1:=640;H1:=400;End;
    End Else If Sv=S_BORDERRECT Then Begin X1:=GW[A].X;Y1:=GW[A].Y;W1:=GW[A].W;H1:=GW[A].H;End
    Else WinWork(A,X1,Y1,W1,H1);
    PutW(B,X1);PutW(C,Y1);PutW(D,W1);PutW(E,H1);
   End;
  S_FIRSTRECT: Begin
    E:=Pop32;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    BuildRects(A);RectOut(B,C,D,E);
   End;
  S_NEXTRECT: Begin
    E:=Pop32;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    RectOut(B,C,D,E);
   End;
  S_RECTINT: Begin
    H:=Pop32;G:=Pop32;F:=Pop32;E:=Pop32;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    R1.X:=A;R1.Y:=B;R1.W:=C;R1.H:=D;
    R2.X:=GetW(E);R2.Y:=GetW(F);R2.W:=GetW(G);R2.H:=GetW(H);
    If Isect(R1,R2,R3) Then Begin
     PutW(E,R3.X);PutW(F,R3.Y);PutW(G,R3.W);PutW(H,R3.H);RD[0]:=1;
    End Else Begin
     PutW(E,R3.X);PutW(F,R3.Y);PutW(G,0);PutW(H,0);RD[0]:=0;
    End;
   End;
  S_FRONTWIN: RD[0]:=TopWin;
  S_BRINGFRONT: Begin A:=Pop32;If (A>=1) And (A<=MAXGW) Then WinToFront(A);End;
  S_SETWINDOW: Begin
    A:=Pop32;
    If (A>=1) And (A<=MAXGW) And GW[A].Used Then Begin
     CurWin:=A;WinWork(A,X1,Y1,W1,H1);OrgX:=X1;OrgY:=Y1;
    End Else Begin CurWin:=0;OrgX:=0;OrgY:=0;End;
   End;
  S_GETWINDOW: RD[0]:=CurWin;
  S_WINDGET: Begin
    G:=Pop32;F:=Pop32;E:=Pop32;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    X1:=0;Y1:=0;W1:=0;H1:=0;
    If (A>=1) And (A<=MAXGW) And GW[A].Used Then Begin
     Case B Of
      4: WinWork(A,X1,Y1,W1,H1);
      5: Begin X1:=GW[A].X;Y1:=GW[A].Y;W1:=GW[A].W;H1:=GW[A].H;End;
      6: Begin X1:=GW[A].PX;Y1:=GW[A].PY;W1:=GW[A].PW;H1:=GW[A].PH;End;
      7: Begin X1:=GW[A].MX;Y1:=GW[A].MY;W1:=GW[A].MW;H1:=GW[A].MH;End;
      8: X1:=GW[A].HS;
      9: X1:=GW[A].VS;
      15: X1:=GW[A].HSz;
      16: X1:=GW[A].VSz;
      10: X1:=TopWin;
     End;
    End Else If B=4 Then DeskRect(X1,Y1,W1,H1);
    PutW(C,X1);PutW(D,Y1);PutW(E,W1);PutW(F,H1);
   End;
  S_WINDSET: Begin
    G:=Pop32;F:=Pop32;E:=Pop32;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    If (A>=1) And (A<=MAXGW) And GW[A].Used Then Begin
     Case B Of
      5: WinSetSize(A,C,D,E,F);
      8: Begin GW[A].HS:=C;If GW[A].Open Then GemRefresh(GW[A].X,GW[A].Y,GW[A].W,GW[A].H,False);End;
      9: Begin GW[A].VS:=C;If GW[A].Open Then GemRefresh(GW[A].X,GW[A].Y,GW[A].W,GW[A].H,False);End;
      15: Begin GW[A].HSz:=C;If GW[A].Open Then GemRefresh(GW[A].X,GW[A].Y,GW[A].W,GW[A].H,False);End;
      16: Begin GW[A].VSz:=C;If GW[A].Open Then GemRefresh(GW[A].X,GW[A].Y,GW[A].W,GW[A].H,False);End;
      10: WinToFront(A);
     End;
    End;
   End;
  S_GETEVENT: Begin
    For I:=22 DownTo 1 Do Av[I]:=Pop32;
    RD[0]:=GemEvent(Av[1],Av[2],Av[3],Av[4],Av[5],Av[6]<>0,Av[7],Av[8],Av[9],Av[10],
                    Av[11]<>0,Av[12],Av[13],Av[14],Av[15],Av[16],Av[17],Av[18],Av[19],Av[20],Av[21],Av[22]);
   End;
  S_NEWDLG: Begin
    E:=Pop32;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    I:=0;
    For J:=1 To MAXGD Do If (Not GDl[J].Used) And (I=0) Then I:=J;
    If I=0 Then RD[0]:=0 Else Begin
     FillChar(GDl[I],SizeOf(TGDlg),0);
     GDl[I].Used:=True;GDl[I].N:=0;
     GDl[I].Ob[0].Typ:=20;GDl[I].Ob[0].X:=B;GDl[I].Ob[0].Y:=C;GDl[I].Ob[0].W:=D;GDl[I].Ob[0].H:=E;
     GDl[I].Ob[0].PWo:=D*8;GDl[I].Ob[0].PHo:=E*16;
     GDl[I].PX:=B*8;GDl[I].PY:=C*16;
     RD[0]:=I;
    End;
   End;
  S_DELDLG,S_ENDDLG: Begin
    A:=Pop32;
    If (A>=1) And (A<=MAXGD) Then Begin
     If GDl[A].Shown Then Begin HideMouse;RestoreBack(GDl[A].Sv);ShowMouse;GDl[A].Shown:=False;End;
     If Sv=S_DELDLG Then GDl[A].Used:=False;
    End;
   End;
  S_ADDDITEM: Begin
    I:=Pop32;H:=Pop32;G:=Pop32;F:=Pop32;E:=Pop32;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    { dlg,type,flags,x,y,w,h,border,color : A..I dans l'ordre inverse }
    If (A>=1) And (A<=MAXGD) And (GDl[A].N<MAXGO) Then Begin
     Inc(GDl[A].N);
     J:=GDl[A].N;
     FillChar(GDl[A].Ob[J],SizeOf(TGObj),0);
     GDl[A].Ob[J].Typ:=B;GDl[A].Ob[J].Flags:=C;GDl[A].Ob[J].X:=D;GDl[A].Ob[J].Y:=E;
     GDl[A].Ob[J].W:=F;GDl[A].Ob[J].H:=G;GDl[A].Ob[J].Border:=SmallInt(H);GDl[A].Ob[J].Color:=I;
     If (B=26) And (GDl[A].Ob[J].H=0) Then GDl[A].Ob[J].H:=1;
     GDl[A].Ob[J].PXo:=D*8;GDl[A].Ob[J].PYo:=E*16;GDl[A].Ob[J].PWo:=F*8;GDl[A].Ob[J].PHo:=G*16;
     GDl[A].Ob[J].Parent:=0;
     RD[0]:=J;
    End Else RD[0]:=-1;
   End;
  S_DCOLOR: Begin
    E:=Pop32;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    If C<>0 Then C:=1;
    RD[0]:=((A And 15) Shl 12) Or ((B And 15) Shl 8) Or (C Shl 7) Or ((D And 7) Shl 4) Or (E And 15);
   End;
  S_SETDTEXT: Begin
    E:=Pop32;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    If (A>=1) And (A<=MAXGD) And (B>=0) And (B<=GDl[A].N) Then Begin
     GDl[A].Ob[B].Txt:=GetPS(C);GDl[A].Ob[B].Just:=E;
    End;
   End;
  S_SETDEDIT: Begin
    G:=Pop32;F:=Pop32;E:=Pop32;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    { dlg,item,template,valid,initial,font,just }
    If (A>=1) And (A<=MAXGD) And (B>=0) And (B<=GDl[A].N) Then Begin
     GDl[A].Ob[B].Templ:=GetPS(C);GDl[A].Ob[B].Valid:=GetPS(D);GDl[A].Ob[B].Txt:=GetPS(E);
     GDl[A].Ob[B].Just:=G;
     GDl[A].Ob[B].Flags:=GDl[A].Ob[B].Flags Or 8;
    End;
   End;
  S_OBJSETSTATE: Begin
    D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    If (A>=1) And (A<=MAXGD) And (B>=0) And (B<=GDl[A].N) Then Begin
     GDl[A].Ob[B].State:=C;
     If (D<>0) And GDl[A].Shown And (B>0) Then PaintObj(A,B);
    End;
   End;
  S_OBJSTATE: Begin
    B:=Pop32;A:=Pop32;
    If (A>=1) And (A<=MAXGD) And (B>=0) And (B<=GDl[A].N) Then RD[0]:=GDl[A].Ob[B].State Else RD[0]:=0;
   End;
  S_OBJSETFLAGS: Begin
    C:=Pop32;B:=Pop32;A:=Pop32;
    If (A>=1) And (A<=MAXGD) And (B>=0) And (B<=GDl[A].N) Then Begin GDl[A].Ob[B].Flags:=C;RecalcHidden(A);End;
   End;
  S_OBJFLAGS: Begin
    B:=Pop32;A:=Pop32;
    If (A>=1) And (A<=MAXGD) And (B>=0) And (B<=GDl[A].N) Then RD[0]:=GDl[A].Ob[B].Flags Else RD[0]:=0;
   End;
  S_CENTERDLG: Begin
    A:=Pop32;
    If (A>=1) And (A<=MAXGD) Then Begin
     GDl[A].PX:=(640-GDl[A].Ob[0].PWo) Div 2;GDl[A].PY:=(400-GDl[A].Ob[0].PHo) Div 2;
    End;
   End;
  S_DODLG,S_REDODLG: Begin
    B:=Pop32;A:=Pop32;
    If (A>=1) And (A<=MAXGD) Then RD[0]:=DlgRun(A,B) Else RD[0]:=0;
   End;
  S_GETDEDIT: Begin
    C:=Pop32;B:=Pop32;A:=Pop32;
    If (A>=1) And (A<=MAXGD) And (B>=0) And (B<=GDl[A].N) Then PutPS(C,GDl[A].Ob[B].Txt,255) Else PutPS(C,'',255);
   End;
  S_SHOWDLG: Begin
    B:=Pop32;A:=Pop32;
    If Headless Then Begin End
    Else If (A>=1) And (A<=MAXGD) Then Begin
     If B<=0 Then Begin
      If Not GDl[A].Shown Then Begin
       OutFlush(True);
       HideMouse;SaveBack(GDl[A].Sv,GDl[A].PX,GDl[A].PY+OFS_Y,GDl[A].PX+GDl[A].Ob[0].PWo+5,GDl[A].PY+OFS_Y+GDl[A].Ob[0].PHo+5);ShowMouse;
       GDl[A].Shown:=True;
      End;
      PaintDlg(A);
     End Else If GDl[A].Shown Then Begin PaintObj(A,B);PaintKids(A,B);End;
    End;
   End;
  S_GETINFILE,S_GETOUTFILE: Begin
    B:=Pop32;A:=Pop32;
    OutFlush(True);GemCur(True);
    If Sv=S_GETINFILE Then PN:=GetPS(B) Else PN:=GetPS(B);
    If Headless Then Begin
     WriteLn('[FILE SELECTOR] cancelled in batch mode');Ok:=False;
    End Else
    Ok:=FileSelect(T3('Select file','Choisir fichier','Datei waehlen'),'*.*',PN);
    If Ok Then Begin
     If Sv=S_GETINFILE Then Begin
      PS:=Copy(PN,1,Length(PN)-Length(ShortName(PN)));
      PutPS(A,PS,80);PutPS(B,ShortName(PN),80);
     End Else PutPS(B,PN,80);
     RD[0]:=1;
    End Else RD[0]:=0;
   End;
  S_SETMFORM: Begin
    A:=Pop32;
    CurHx:=GetW(A);CurHy:=GetW(A+2);CurKind:=1;
    For I:=0 To 15 Do Begin CurMask[I]:=RW(A+10+I*2);CurData[I]:=RW(A+42+I*2);End;
    If ProgMouse And (Not Headless) Then Begin HideMouse;ShowMouse;End;
   End;
  S_SETMOUSE2: Begin
    A:=Pop32;
    CurHx:=0;CurHy:=0;
    Case A Of
     1: Begin CurKind:=2;CurHx:=8;CurHy:=9;End;
     2: Begin CurKind:=4;CurHx:=8;CurHy:=9;End;
     5,6,7: Begin CurKind:=3;CurHx:=8;CurHy:=9;End;
    Else CurKind:=0;
    End;
    If ProgMouse And (Not Headless) Then Begin HideMouse;ShowMouse;End;
   End;
  S_SHOWMOUSE: GemCur(True);
  S_HIDEMOUSE: GemCur(False);
 Else
  GemService:=False;
 End;
End;
{ ------------------------------ services ------------------------------ }

Procedure DoChain(Const Cmd0: String); Forward;
Procedure GemDos; Forward;
Procedure LineA(Op: Word); Forward;
Function BiosEx: Boolean; Forward;
Function XBiosEx: Boolean; Forward;
Function TosToHost(Const S0: String): String; Forward;
Procedure AesReset; Forward;
Procedure AesSave; Forward;
Procedure AesRestore; Forward;
Procedure VdiCall(PB: LongInt); Forward;
Procedure AesCall(PB: LongInt); Forward;

{ ---------------- aides pour les services divers (CHAIN, OPTION...) ---------------- }

Function CmdTail: String;
Begin
 CmdTail:=GetPS(M_BASEPAGE+$80);
End;

Function CmdArgCount: Integer;
Var T: String; I,N: Integer; InW: Boolean;
Begin
 T:=CmdTail;N:=0;InW:=False;
 For I:=1 To Length(T) Do Begin
  If T[I]>' ' Then Begin If Not InW Then Begin Inc(N);InW:=True;End;End
  Else InW:=False;
 End;
 CmdArgCount:=N;
End;

Function CmdArg(K: Integer): String;
Var T,W: String; I,N: Integer; InW: Boolean;
Begin
 T:=CmdTail;N:=0;InW:=False;W:='';CmdArg:='';
 For I:=1 To Length(T)+1 Do Begin
  If (I<=Length(T)) And (T[I]>' ') Then Begin
   If Not InW Then Begin Inc(N);InW:=True;W:='';End;
   If N=K Then W:=W+T[I];
  End Else Begin
   If InW And (N=K) Then Begin CmdArg:=W;Exit;End;
   InW:=False;
  End;
 End;
End;

Function ValidTosName(Const S0: String): Boolean;
{ nom de fichier TOS valide : [X:][chemin\]nom[.ext] }
Var S,Part: String; Ok: Boolean;
 Function GoodChar(C: Char): Boolean;
 Begin
  GoodChar:=((C>='A') And (C<='Z')) Or ((C>='a') And (C<='z')) Or ((C>='0') And (C<='9')) Or
            (Pos(C,'_$#@!%''-~(){}^&+=,;`')>0);
 End;
 Function GoodPart(Const P: String; Last: Boolean): Boolean;
 Var Q,Nm,Ex: String; J,Dp: Integer;
 Begin
  GoodPart:=False;
  If (P='.') Or (P='..') Then Begin GoodPart:=Not Last;Exit;End;
  Dp:=Pos('.',P);
  If Dp=0 Then Begin Nm:=P;Ex:='';End
  Else Begin Nm:=Copy(P,1,Dp-1);Ex:=Copy(P,Dp+1,100);End;
  If (Nm='') Or (Length(Nm)>8) Or (Length(Ex)>3) Or (Pos('.',Ex)>0) Then Exit;
  Q:=Nm+Ex;
  For J:=1 To Length(Q) Do If Not GoodChar(Q[J]) Then Exit;
  GoodPart:=True;
 End;
Begin
 S:=S0;
 While (Length(S)>0) And (S[Length(S)]=' ') Do Delete(S,Length(S),1);
 ValidTosName:=False;
 If S='' Then Exit;
 If (Length(S)>=2) And (S[2]=':') Then Begin
  If Not (UpCase(S[1]) In ['A'..'Z']) Then Exit;
  Delete(S,1,2);
 End;
 If S='' Then Exit;
 Ok:=True;
 While Ok And (Pos('\',S)>0) Do Begin
  Part:=Copy(S,1,Pos('\',S)-1);
  Delete(S,1,Pos('\',S));
  If Part<>'' Then Ok:=GoodPart(Part,False);
 End;
 If Not Ok Then Exit;
 ValidTosName:=GoodPart(S,True);
End;

Function DaysFromCivil(Y,M,D: LongInt): LongInt;
Var Era,Yoe,Doy,Doe: LongInt;
Begin
 If M<=2 Then Y:=Y-1;
 If Y>=0 Then Era:=Y Div 400 Else Era:=(Y-399) Div 400;
 Yoe:=Y-Era*400;
 If M>2 Then Doy:=(153*(M-3)+2) Div 5+D-1 Else Doy:=(153*(M+9)+2) Div 5+D-1;
 Doe:=Yoe*365+Yoe Div 4-Yoe Div 100+Doy;
 DaysFromCivil:=Era*146097+Doe-719468;
End;

Procedure CivilFromDays(Z: LongInt; Var Y,M,D: LongInt);
Var Era,Doe,Yoe,Doy,Mp: LongInt;
Begin
 Z:=Z+719468;
 If Z>=0 Then Era:=Z Div 146097 Else Era:=(Z-146096) Div 146097;
 Doe:=Z-Era*146097;
 Yoe:=(Doe-Doe Div 1460+Doe Div 36524-Doe Div 146096) Div 365;
 Y:=Yoe+Era*400;
 Doy:=Doe-(365*Yoe+Yoe Div 4-Yoe Div 100);
 Mp:=(5*Doy+2) Div 153;
 D:=Doy-(153*Mp+2) Div 5+1;
 If Mp<10 Then M:=Mp+3 Else M:=Mp-9;
 If M<=2 Then Y:=Y+1;
End;

Function HostNowSecs: Int64;
{ secondes depuis 1970 (heure locale de l'hote) }
Var Y,Mo,D,Dw,H,Mi,Sc,S100: Word;
Begin
 GetDate(Y,Mo,D,Dw);GetTime(H,Mi,Sc,S100);
 HostNowSecs:=Int64(DaysFromCivil(Y,Mo,D))*86400+H*3600+Mi*60+Sc;
End;

Function StNowSecs: Int64;
Begin
 StNowSecs:=HostNowSecs+ClockAdj;
End;

Const
 VT_SEQ = 'KE  MLpqABCDHIJef';

Procedure RtService;
Var Sv: Word; A,B,C,D,E,F: LongInt; X,Y: Double; S,S2: String; I: Integer; M: Int64;
    R: Integer; FH: File; Yy,Mm,Dd,G: LongInt; Ss: Int64;
 Function Cmp3(V: Integer): LongInt;
 Begin
  If V<0 Then Cmp3:=-1 Else If V>0 Then Cmp3:=1 Else Cmp3:=0;
 End;
Begin
 Sv:=RD[0] And $FFFF;
 If RtTrace Then Begin WriteLn(ErrOutput,'SVC ',Sv,' SP=',HexStr(RA[7],16),' [',HexStr(RL(RA[7]),16),',',HexStr(RL(RA[7]+4),16),']');Flush(ErrOutput);End;
 Case Sv Of
  S_MULL: Begin B:=Pop32;A:=Pop32;M:=Int64(A)*Int64(B);RD[0]:=LongInt(M And $FFFFFFFF);End;
  S_DIVL: Begin B:=Pop32;A:=Pop32;If B=0 Then RtFail(2) Else RD[0]:=A Div B;End;
  S_MODL: Begin B:=Pop32;A:=Pop32;If B=0 Then RtFail(2) Else RD[0]:=A Mod B;End;
  S_ERR: Begin A:=Pop32;RtFail(A);End;
  S_HALT: Begin A:=Pop32;EmuHalt:=True;EmuCode:=A;End;
  S_RADD: Begin Y:=PopR;X:=PopR;RetR(X+Y);End;
  S_RSUB: Begin Y:=PopR;X:=PopR;RetR(X-Y);End;
  S_RMUL: Begin Y:=PopR;X:=PopR;RetR(X*Y);End;
  S_RDIV: Begin Y:=PopR;X:=PopR;If Y=0 Then Begin RtFail(2);RetR(0);End Else RetR(X/Y);End;
  S_RNEG: Begin X:=PopR;RetR(-X);End;
  S_RCMP: Begin Y:=PopR;X:=PopR;If X<Y Then RD[0]:=-1 Else If X>Y Then RD[0]:=1 Else RD[0]:=0;End;
  S_ITOR: Begin A:=Pop32;RetR(A);End;
  S_RTRUNC: Begin X:=PopR;If Abs(X)>2147483647.0 Then Begin RtFail(1);RD[0]:=0;End Else RD[0]:=Trunc(X);End;
  S_RROUND: Begin X:=PopR;If Abs(X)>2147483647.0 Then Begin RtFail(1);RD[0]:=0;End Else If X>=0 Then RD[0]:=Trunc(X+0.5) Else RD[0]:=-Trunc(-X+0.5);End;
  S_RABS: Begin X:=PopR;RetR(Abs(X));End;
  S_RSQR: Begin X:=PopR;RetR(X*X);End;
  S_RSQRT: Begin X:=PopR;If X<0 Then Begin RtFail(1);RetR(0);End Else RetR(Sqrt(X));End;
  S_RSIN: Begin X:=PopR;RetR(Sin(X));End;
  S_RCOS: Begin X:=PopR;RetR(Cos(X));End;
  S_RATAN: Begin X:=PopR;RetR(ArcTan(X));End;
  S_RLN: Begin X:=PopR;If X<=0 Then Begin RtFail(1);RetR(0);End Else RetR(Ln(X));End;
  S_REXP: Begin X:=PopR;RetR(Exp(X));End;
  S_RPWR: Begin Y:=PopR;X:=PopR;RetR(Exp(Y*Ln(X)));End;
  S_SCAT: Begin
    B:=Pop32;A:=Pop32;
    S:=GetPS(A)+GetPS(B);
    C:=NewTmpStr;PutPS(C,S,255);RD[0]:=C;
   End;
  S_SCMP: Begin
    B:=Pop32;A:=Pop32;
    S:=GetPS(A);S2:=GetPS(B);
    If S<S2 Then RD[0]:=-1 Else If S>S2 Then RD[0]:=1 Else RD[0]:=0;
   End;
  S_SASG: Begin
    C:=Pop32;B:=Pop32;A:=Pop32;   { dest, src, max }
    S:=GetPS(B);
    If Length(S)>C Then S:=Copy(S,1,C);
    PutPS(A,S,255);
   End;
  S_C2S: Begin A:=Pop32;C:=NewTmpStr;WB(C,1);WB(C+1,A And $FF);RD[0]:=C;End;
  S_SPOS: Begin B:=Pop32;A:=Pop32;RD[0]:=Pos(GetPS(A),GetPS(B));End;
  S_SCOPY: Begin
    C:=Pop32;B:=Pop32;A:=Pop32;
    S:=GetPS(A);
    If (B<1) Or (C<0) Then Begin RtFail(1);S:='';End Else S:=Copy(S,B,C);
    D:=NewTmpStr;PutPS(D,S,255);RD[0]:=D;
   End;
  S_SDEL: Begin
    C:=Pop32;B:=Pop32;A:=Pop32;
    S:=GetPS(A);Delete(S,B,C);PutPS(A,S,255);
   End;
  S_SINS: Begin
    D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;   { src, dest, pos, max }
    S:=GetPS(B);Insert(GetPS(A),S,C);
    If Length(S)>D Then S:=Copy(S,1,D);
    PutPS(B,S,255);
   End;
  S_SUPPER: Begin
    A:=Pop32;S:=GetPS(A);
    For I:=1 To Length(S) Do S[I]:=UpCase(S[I]);
    C:=NewTmpStr;PutPS(C,S,255);RD[0]:=C;
   End;
  S_SETNEW: RD[0]:=NewTmpSet;
  S_SETADD: Begin
    B:=Pop32;A:=Pop32;
    If (B<0) Or (B>255) Then RtFail(9) Else WB(A+(B Shr 3),RB(A+(B Shr 3)) Or (1 Shl (B And 7)));
    RD[0]:=A;
   End;
  S_SETRNG: Begin
    C:=Pop32;B:=Pop32;A:=Pop32;
    If (B<0) Or (C>255) Then RtFail(9)
    Else For I:=B To C Do WB(A+(I Shr 3),RB(A+(I Shr 3)) Or (1 Shl (I And 7)));
    RD[0]:=A;
   End;
  S_SETUNI,S_SETDIF,S_SETINT: Begin
    B:=Pop32;A:=Pop32;C:=NewTmpSet;
    For I:=0 To 31 Do
     Case Sv Of
      S_SETUNI: WB(C+I,RB(A+I) Or RB(B+I));
      S_SETDIF: WB(C+I,RB(A+I) And (Not RB(B+I)));
     Else WB(C+I,RB(A+I) And RB(B+I));
     End;
    RD[0]:=C;
   End;
  S_SETEQ: Begin
    B:=Pop32;A:=Pop32;RD[0]:=1;
    For I:=0 To 31 Do If RB(A+I)<>RB(B+I) Then RD[0]:=0;
   End;
  S_SETSUB: Begin
    B:=Pop32;A:=Pop32;RD[0]:=1;
    For I:=0 To 31 Do If (RB(A+I) And (Not RB(B+I)))<>0 Then RD[0]:=0;
   End;
  S_SETIN: Begin
    B:=Pop32;A:=Pop32;
    If (A<0) Or (A>255) Then RD[0]:=0
    Else If (RB(B+(A Shr 3)) And (1 Shl (A And 7)))<>0 Then RD[0]:=1 Else RD[0]:=0;
   End;
  S_NEW: Begin
    A:=Pop32;A:=(A+3) And (Not 3);
    If EmuHeap+A+512>RA[7] Then Begin RtFail(7);RD[0]:=0;End
    Else Begin RD[0]:=EmuHeap;FillChar(VMem[EmuHeap],A,0);EmuHeap:=EmuHeap+A;End;
   End;
  S_MARK: RD[0]:=EmuHeap;
  S_RELEASE: Begin A:=Pop32;If (A>0) And (A<=EmuHeap) Then EmuHeap:=A;End;
  S_RANDOM: Begin
    A:=Pop32;
    RtSeed:=RtSeed*1103515245+12345;
    If A<=0 Then RD[0]:=0 Else RD[0]:=((RtSeed Shr 8) And $7FFFFF) Mod A;
   End;
  S_TICKS: RD[0]:=NowCs;
  S_SELOUT: Begin A:=Pop32;R:=FileOf(A);If R<0 Then Begin RtFail(6);R:=0;End;OutSel:=R;End;
  S_WRI: Begin B:=Pop32;A:=Pop32;Str(A,S);PadOut(S,B);End;
  S_WRC: Begin B:=Pop32;A:=Pop32;PadOut(Chr(A And $FF),B);End;
  S_WRB: Begin B:=Pop32;A:=Pop32;If A<>0 Then S:='true' Else S:='false';If (B>0) And (Length(S)>B) Then S:=Copy(S,1,B);PadOut(S,B);End;
  S_WRS: Begin B:=Pop32;A:=Pop32;S:=GetPS(A);If (B>0) And (Length(S)>B) Then S:=Copy(S,1,B);PadOut(S,B);End;
  S_WRR: Begin C:=Pop32;B:=Pop32;X:=PopR;PadOut(FmtReal(X,B,C),0);End;
  S_WRLN: Begin PutCh(#10);If OutSel=0 Then OutFlush(False);End;
  S_SELIN: Begin A:=Pop32;R:=FileOf(A);If R<0 Then Begin RtFail(6);R:=0;End;InSel:=R;End;
  S_RDI: Begin
    B:=Pop32;A:=Pop32;                  { adresse, taille }
    S:=RdNumberStr(False);
    Val(S,D,I);
    If (I<>0) Or (S='') Then Begin IoRes:=7;If IoCheckOn Then RtFail(8);D:=0;End Else IoRes:=0;
    StoreSized(A,D,B);
   End;
  S_RDC: Begin
    A:=Pop32;
    If (InSel=0) And (ConPos>Length(ConBuf)) And (Headless=False) And (KeyPressed Or (KeyQ<>'')) Then Begin
     I:=GetKeyWait;
     If I>=256 Then I:=0;
     WB(A,I And $FF);
    End Else Begin
    I:=SrcPeek;
    If I<0 Then WB(A,32)
    Else If I=13 Then Begin WB(A,32);SrcSkip;End
    Else Begin WB(A,I);SrcSkip;End;
    End;
   End;
  S_RDS: Begin
    B:=Pop32;A:=Pop32;
    S:='';
    Repeat
     I:=SrcPeek;
     If (I<0) Or (I=13) Then Break;
     If Length(S)<B Then S:=S+Chr(I);
     SrcSkip;
    Until False;
    PutPS(A,S,255);
   End;
  S_RDR: Begin
    A:=Pop32;
    S:=RdNumberStr(True);
    Val(S,X,I);
    If (I<>0) Or (S='') Then Begin IoRes:=10;If IoCheckOn Then RtFail(8);X:=0;End Else IoRes:=0;
    WriteRealMem(A,X);
   End;
  S_RDLN: Begin
    If InSel=0 Then Begin
     If ConPos>Length(ConBuf) Then ConFetch
     Else ConPos:=Length(ConBuf)+1;
    End Else Begin
     Repeat
      I:=SrcPeek;
      If I<0 Then Break;
      SrcSkip;
      If I=13 Then Break;
     Until False;
    End;
   End;
  S_EOF: Begin
    A:=Pop32;R:=FileOf(A);
    If R<=0 Then RD[0]:=0
    Else If PFiles[R].IsText Then Begin
     InSel:=R;
     If SrcPeek=-1 Then RD[0]:=1 Else RD[0]:=0;
    End Else Begin
     If PFiles[R].Writing Or PFiles[R].EofV Then RD[0]:=1 Else RD[0]:=0;
    End;
   End;
  S_EOLN: Begin
    A:=Pop32;R:=FileOf(A);
    If R<0 Then R:=0;
    I:=InSel;InSel:=R;
    C:=SrcPeek;
    InSel:=I;
    If (C=13) Or (C<0) Then RD[0]:=1 Else RD[0]:=0;
   End;
  S_FRESET: Begin
    IoRes:=0;
    D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;   { f, nom, taille, mode }
    FileOpen(A,B,C,D);
   End;
  S_FCLOSE: Begin IoRes:=0;A:=Pop32;R:=FileOf(A);If R>0 Then Begin FileClose(R);WL(A,0);End;End;
  S_FREAD: Begin
    C:=Pop32;B:=Pop32;A:=Pop32;R:=FileOf(A);IoRes:=0;
    If R<=0 Then IoFail(2,0)
    Else Begin
     If PFiles[R].EofV Then IoFail(1,0)
     Else Begin
      If C>256 Then C:=256;
      Move(VMem[M_FBUF+R*256],VMem[B],C);
      FetchFile(R);
     End;
    End;
   End;
  S_FWRITE: Begin
    C:=Pop32;B:=Pop32;A:=Pop32;R:=FileOf(A);IoRes:=0;
    If R<=0 Then IoFail(3,0)
    Else Begin
     D:=0;
     {$I-}BlockWrite(PFiles[R].F,VMem[B],C,D);{$I+}
     If (IOResult<>0) Or (D<C) Then IoFail(0,-12);
    End;
   End;
  S_FSEEK: Begin
    B:=Pop32;A:=Pop32;R:=FileOf(A);IoRes:=0;
    If R<=0 Then IoFail(6,0)
    Else If B<0 Then IoFail(5,0)
    Else Begin
     {$I-}Seek(PFiles[R].F,B*PFiles[R].ESize);{$I+}
     If IOResult<>0 Then IoFail(0,-6) Else If Not PFiles[R].Writing Then FetchFile(R);
    End;
   End;
  S_FBUF: Begin A:=Pop32;R:=FileOf(A);If R<=0 Then Begin RtFail(6);RD[0]:=M_FBUF;End Else RD[0]:=M_FBUF+R*256;End;
  S_GET: Begin A:=Pop32;R:=FileOf(A);IoRes:=0;If R<=0 Then IoFail(2,0) Else FetchFile(R);End;
  S_PUT: Begin
    A:=Pop32;R:=FileOf(A);IoRes:=0;
    If R<=0 Then IoFail(3,0)
    Else Begin
     D:=0;
     {$I-}BlockWrite(PFiles[R].F,VMem[M_FBUF+R*256],PFiles[R].ESize,D);{$I+}
     If (IOResult<>0) Or (D<PFiles[R].ESize) Then IoFail(0,-12);
    End;
   End;
  S_WRIH: Begin
    B:=Pop32;A:=Pop32;
    S:=HexStr(A,16);
    While Length(S)<B Do S:='0'+S;
    PutStrOut(S);
   End;
  S_FPAGE: Begin A:=Pop32;R:=FileOf(A);If R<0 Then R:=0;I:=OutSel;OutSel:=R;PutCh(#12);OutSel:=I;End;
  S_FERASE: Begin
    A:=Pop32;S:=ResolveFile(GetPS(A));
    If FileExists(S) Then Begin
     Assign(PFiles[1].F,S);
     {$I-}Erase(PFiles[1].F);{$I+}
     If IOResult<>0 Then RtFail(6);
    End;
   End;
  S_PEEKB: Begin A:=Pop32;RD[0]:=RB(A);End;
  S_PEEKW: Begin A:=Pop32;RD[0]:=SmallInt(RW(A));End;
  S_PEEKL: Begin A:=Pop32;RD[0]:=RL(A);End;
  S_POKEB: Begin B:=Pop32;A:=Pop32;WB(A,B And $FF);End;
  S_POKEW: Begin B:=Pop32;A:=Pop32;WW(A,B And $FFFF);End;
  S_POKEL: Begin B:=Pop32;A:=Pop32;WL(A,B);End;
  S_MOVEB: Begin
    C:=Pop32;B:=Pop32;A:=Pop32;         { source, destination, nombre }
    If (A>=0) And (B>=0) And (C>0) And (A+C<=VMEM_SIZE) And (B+C<=VMEM_SIZE) Then
     Move(VMem[A],VMem[B],C);
   End;
  S_INITGEM: Begin
    GemMode:=True;GemUsed:=True;
    ClearGem;
    OutClear;OutToMem;
    FilCol:=1;FilSty:=1;FilIdx:=1;LinCol:=1;TxtColV:=1;DrawModeV:=1;
    PenX:=0;PenY:=0;
    GemRefresh(0,0,640,400,False);
    RD[0]:=1;
   End;
  S_EXITGEM: GemMode:=False;
  S_ALERT: Begin
    B:=Pop32;A:=Pop32;
    OutFlush(True);
    GemCur(True);
    RD[0]:=AesAlert(GetPS(A),B);
    GemCur(ProgMouse);
   End;
  S_LINE: Begin
    GfxPrep;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    A:=A+OrgX;B:=B+OrgY;C:=C+OrgX;D:=D+OrgY;OLine(A,B,C,D,LineInk);OXor:=False;PenX:=C;PenY:=D;
    OutPending:=True;
   End;
  S_MOVETO: Begin PenY:=Pop32+OrgY;PenX:=Pop32+OrgX;End;
  S_LINETO: Begin
    GfxPrep;B:=Pop32+OrgY;A:=Pop32+OrgX;
    OLine(PenX,PenY,A,B,LineInk);OXor:=False;PenX:=A;PenY:=B;
    OutPending:=True;
   End;
  S_PLOT: Begin GfxPrep;B:=Pop32+OrgY;A:=Pop32+OrgX;OPlot(A,B,LineInk);OXor:=False;PenX:=A;PenY:=B;End;
  S_PRECT: Begin GfxPrep;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;A:=A+OrgX;B:=B+OrgY;GRect(A,B,C,D,True);OXor:=False;OutPending:=True;End;
  S_FRECT: Begin GfxPrep;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;A:=A+OrgX;B:=B+OrgY;GRect(A,B,C,D,False);OXor:=False;OutPending:=True;End;
  S_PRRECT: Begin GfxPrep;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;A:=A+OrgX;B:=B+OrgY;GRect(A,B,C,D,True);OXor:=False;OutPending:=True;End;
  S_FRRECT: Begin GfxPrep;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;A:=A+OrgX;B:=B+OrgY;GRect(A,B,C,D,False);OXor:=False;OutPending:=True;End;
  S_DRAWSTR: Begin GfxPrep;C:=Pop32;B:=Pop32;A:=Pop32;A:=A+OrgX;B:=B+OrgY;GText(A,B,GetPS(C));OXor:=False;OutPending:=True;End;
  S_LINECOL: Begin A:=Pop32;LinCol:=A;End;
  S_PAINTCOL: Begin A:=Pop32;FilCol:=A;End;
  S_TEXTCOL: Begin A:=Pop32;If A=0 Then TxtColV:=0 Else TxtColV:=1;End;
  S_POVAL: Begin
    GfxPrep;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    A:=A+OrgX;B:=B+OrgY;OPie(A,B,C,D,0,3600);OXor:=False;OutPending:=True;
   End;
  S_FOVAL: Begin
    GfxPrep;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    A:=A+OrgX;B:=B+OrgY;OArc(A,B,C,D,0,3600);OXor:=False;OutPending:=True;
   End;
  S_PARC: Begin
    GfxPrep;F:=Pop32;E:=Pop32;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    A:=A+OrgX;B:=B+OrgY;OPie(A,B,C,D,E,F);OXor:=False;OutPending:=True;
   End;
  S_FARC: Begin
    GfxPrep;F:=Pop32;E:=Pop32;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    A:=A+OrgX;B:=B+OrgY;OArc(A,B,C,D,E,F);OXor:=False;OutPending:=True;
   End;
  S_PSTYLE: Begin A:=Pop32;If A<=0 Then FilSty:=0 Else Begin FilSty:=1;End;End;
  S_PAINTOUT: Begin A:=Pop32;End;
  S_SHOWM,S_HIDEM: ;
  S_DMODE: Begin A:=Pop32;DrawModeV:=A;End;
  S_LSTYLE: Begin A:=Pop32;End;
  S_SETCOLOR: Begin D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;End;
  S_SETCLIP: Begin
    D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    ClipX1:=A;ClipY1:=B;ClipX2:=A+C-1;ClipY2:=B+D-1;ClipOn:=True;
   End;
  S_SETMOUSE,S_NOP1: A:=Pop32;
  S_NOEXT: Begin
    A:=Pop32;
    EmuMsg:=T3('Library routine not implemented: ','Routine de biblioth'#138'que non impl'#130'ment'#130'e : ','Bibliotheksroutine fehlt: ')+GetPS(A);
    EmuHalt:=True;EmuCode:=-2;
   End;
  S_INSUPER: If EmuSuper Then RD[0]:=1 Else RD[0]:=0;
  S_SYSFONT: Begin
    D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;
    WW(A,8);WW(B,16);WW(C,8);WW(D,16);
   End;
  S_MOVEW,S_MOVEL: Begin
    C:=Pop32;B:=Pop32;A:=Pop32;
    If Sv=S_MOVEW Then C:=C*2 Else C:=C*4;
    If (A>=0) And (B>=0) And (C>0) And (A+C<=VMEM_SIZE) And (B+C<=VMEM_SIZE) Then Move(VMem[A],VMem[B],C);
   End;
  S_TEXTHT: Begin A:=Pop32;TxtSize:=A;End;
  S_TEXTSTY: Begin A:=Pop32;End;
  S_CLRSCR: Begin OutClear;OutPending:=True;End;
  S_GETKEY: Begin RD[0]:=GetKeyWait;End;
  S_KEYPRESS: Begin
    PollKeys;
    If (KeyQ<>'') Or (Not Headless And KeyPressed) Then RD[0]:=1 Else RD[0]:=0;
   End;
  S_DELAY: Begin A:=Pop32;OutFlush(True);If Not Headless Then Delay(A);End;
  S_GETMOUSE: Begin
    A:=Pop32;
    GetMouseState(MX,MY,MB);
    WW(A,MX And $FFFF);WW(A+2,(MY-OFS_Y) And $FFFF);WW(A+4,MB And 3);
   End;
  S_PACK: Begin
    { pack(src,debut,pk) : src, debut, bas, nbSrc, dst, nbDst, pas }
    F:=Pop32;E:=Pop32;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;G:=Pop32;
    { G=src, A=debut, B=bas, C=nbSrc, D=dst, E=nbDst, F=pas }
    M:=C-(A-B);
    If (A<B) Or (M<0) Or (M>E) Then RtFail(1)
    Else If M>0 Then Move(VMem[G+(A-B)*F],VMem[D],M*F);
   End;
  S_UNPACK: Begin
    { unpack(pk,dst,debut) : pk, nbPk, dst, debut, bas, nbDst, pas }
    F:=Pop32;E:=Pop32;D:=Pop32;C:=Pop32;B:=Pop32;A:=Pop32;G:=Pop32;
    { G=pk, A=nbPk, B=dst, C=debut, D=bas, E=nbDst, F=pas }
    M:=(C-D)+A;
    If (C<D) Or (M>E) Then RtFail(1)
    Else If A>0 Then Move(VMem[G],VMem[B+(C-D)*F],A*F);
   End;
  S_PWRTEN: Begin
    A:=Pop32;
    If (A<0) Or (A>38) Then Begin RtFail(1);X:=1;End
    Else Begin X:=1;For I:=1 To A Do X:=X*10;End;
    RetR(X);
   End;
  S_FRENAME: Begin
    B:=Pop32;A:=Pop32;
    IoRes:=0;
    C:=FileOf(A);D:=FileOf(B);
    If (C<=0) Or (D<=0) Then IoFail(2,0)
    Else Begin
     S:=PFiles[C].Name;S2:=PFiles[D].Name;
     FileClose(C);FileClose(D);WL(A,0);WL(B,0);
     {$I-}
     If FileExists(S2) Then Begin Assign(FH,S2);Erase(FH);End;
     If IOResult<>0 Then ;
     Assign(FH,S);Rename(FH,S2);
     {$I+}
     If IOResult<>0 Then IoFail(0,-36);
    End;
   End;
  S_FERASEF: Begin
    A:=Pop32;
    IoRes:=0;
    C:=FileOf(A);
    If C<=0 Then IoFail(2,0)
    Else Begin
     S:=PFiles[C].Name;
     FileClose(C);WL(A,0);
     {$I-}Assign(FH,S);Erase(FH);{$I+}
     If IOResult<>0 Then IoFail(0,-33);
    End;
   End;
  S_CHAIN: Begin
    A:=Pop32;
    DoChain(GetPS(A));
   End;
  S_BASEPAGE: Begin A:=Pop32;WL(A,M_BASEPAGE);End;
  S_OPTION: Begin
    A:=Pop32;S:=Upper(GetPS(A));RD[0]:=0;
    For I:=1 To CmdArgCount Do If Upper(CmdArg(I))=S Then RD[0]:=1;
   End;
  S_CMDARGS: RD[0]:=CmdArgCount;
  S_CMDGETARG: Begin
    B:=Pop32;A:=Pop32;
    If (A<1) Or (A>CmdArgCount) Then WB(B,0) Else PutPS(B,CmdArg(A),255);
   End;
  S_FILENAME: Begin A:=Pop32;If ValidTosName(GetPS(A)) Then RD[0]:=1 Else RD[0]:=0;End;
  S_HANDLE: Begin
    A:=Pop32;R:=FileOf(A);RD[0]:=0;
    If R<=0 Then IoFail(2,0)
    Else Begin
     If PFiles[R].GH=0 Then Begin
      C:=0;
      For I:=6 To 25 Do If (C=0) And (Not EmuFUsed[I]) Then C:=I;
      If C=0 Then IoFail(0,-35)
      Else Begin
       {$I-}
       Assign(EmuFile[C],PFiles[R].Name);
       Reset(EmuFile[C],1);
       If (IOResult=0) And (Not PFiles[R].IsText) Then Begin
        If PFiles[R].Writing Then Seek(EmuFile[C],FileSize(EmuFile[C]))
        Else Begin
         D:=FilePos(PFiles[R].F);
         If Not PFiles[R].EofV Then D:=D-PFiles[R].ESize;
         If D<0 Then D:=0;
         Seek(EmuFile[C],D);
        End;
       End;
       {$I+}
       If IOResult<>0 Then IoFail(0,-33)
       Else Begin EmuFUsed[C]:=True;PFiles[R].GH:=C;End;
      End;
     End;
     RD[0]:=PFiles[R].GH;
    End;
   End;
  S_IDENT: Begin A:=Pop32;RD[0]:=A;End;
  S_CARRASG: Begin
    C:=Pop32;B:=Pop32;A:=Pop32;         { tableau, chaine, taille }
    S:=GetPS(B);
    For I:=1 To C Do If I<=Length(S) Then WB(A+I-1,Ord(S[I])) Else WB(A+I-1,32);
   End;
  S_ARR2S: Begin
    B:=Pop32;A:=Pop32;                  { adresse, taille }
    S:='';
    If B>255 Then B:=255;
    For I:=1 To B Do S:=S+Chr(RB(A+I-1));
    C:=NewTmpStr;PutPS(C,S,255);RD[0]:=C;
   End;
  S_GETDATE: Begin
    C:=Pop32;B:=Pop32;A:=Pop32;
    Ss:=StNowSecs;CivilFromDays(Ss Div 86400,Yy,Mm,Dd);
    WW(A,Mm);WW(B,Dd);WW(C,Yy);
   End;
  S_GETTIME: Begin
    C:=Pop32;B:=Pop32;A:=Pop32;
    Ss:=StNowSecs Mod 86400;
    WW(A,Ss Div 3600);WW(B,(Ss Div 60) Mod 60);WW(C,(Ss And (Not 1)) Mod 60);
   End;
  S_SETDATE: Begin
    C:=Pop32;B:=Pop32;A:=Pop32;     { mois, jour, annee }
    If (A<1) Or (A>12) Or (B<1) Or (B>31) Then IoFail(0,-32)
    Else Begin
     If C<80 Then C:=C+2000 Else If C<100 Then C:=C+1900;
     Ss:=StNowSecs Mod 86400;
     ClockAdj:=Int64(DaysFromCivil(C,A,B))*86400+Ss-HostNowSecs;
    End;
   End;
  S_SETTIME: Begin
    C:=Pop32;B:=Pop32;A:=Pop32;     { heure, minute, seconde }
    If (A<0) Or (A>23) Or (B<0) Or (B>59) Or (C<0) Or (C>59) Then IoFail(0,-32)
    Else Begin
     Ss:=(StNowSecs Div 86400)*86400+A*3600+B*60+(C And (Not 1));
     ClockAdj:=Ss-HostNowSecs;
    End;
   End;
  S_CLOCK: RD[0]:=(StNowSecs Mod 86400) And (Not 1);
  S_C2P: Begin
    B:=Pop32;A:=Pop32;S:='';
    While (Length(S)<255) And (RB(A+Length(S))<>0) Do S:=S+Chr(RB(A+Length(S)));
    PutPS(B,S,255);
   End;
  S_P2C: Begin
    B:=Pop32;A:=Pop32;S:=GetPS(A);
    For I:=1 To Length(S) Do WB(B+I-1,Ord(S[I]));
    WB(B+Length(S),0);
   End;
  S_SAVESCR: Begin
    A:=Pop32;
    If Not ScrCustom Then MemToOut;
    WW(A,2);
    WW(A+2,$FFF);
    For I:=1 To 15 Do WW(A+2+I*2,0);
    If ScrCustom Then Move(VMem[ScrPhys],VMem[A+34],32000)
    Else Move(OutBuf^,VMem[A+34],32000);
   End;
  S_RESTSCR: Begin
    A:=Pop32;
    If ScrCustom Then Move(VMem[A+34],VMem[ScrPhys],32000)
    Else Begin
     Move(VMem[A+34],VMem[M_SCREEN],32000);
     MemToOut;
    End;
    OutPending:=True;
   End;
  S_READSCR: Begin
    B:=Pop32;A:=Pop32;
    RD[0]:=0;
    S:=ResolveFile(GetPS(A));
    {$I-}
    Assign(FH,S);Reset(FH,1);
    If IOResult<>0 Then RD[0]:=-33
    Else Begin
     C:=0;
     BlockRead(FH,VMem[B],32034,C);
     If C<32034 Then RD[0]:=-11;
     Close(FH);
    End;
    {$I+}
    If IOResult<>0 Then ;
    IoRes:=RD[0];
    If (RD[0]<>0) And IoCheckOn Then RtFail(6);
   End;
  S_WRITESCR: Begin
    B:=Pop32;A:=Pop32;
    RD[0]:=0;
    S:=GetPS(A);
    {$I-}
    Assign(FH,S);Rewrite(FH,1);
    If IOResult<>0 Then RD[0]:=-36
    Else Begin
     C:=0;
     BlockWrite(FH,VMem[B],32034,C);
     If C<32034 Then RD[0]:=-10;
     Close(FH);
    End;
    {$I+}
    If IOResult<>0 Then ;
    IoRes:=RD[0];
    If (RD[0]<>0) And IoCheckOn Then RtFail(6);
   End;
  S_IOSTATE: If IoCheckOn Then RD[0]:=1 Else RD[0]:=0;
  S_IORESULT: RD[0]:=IoRes;
  S_IOCHECK: Begin A:=Pop32;IoCheckOn:=(A<>0);End;
  S_GOTOXY: Begin
    B:=Pop32;A:=Pop32;                    { x, y }
    VtOut(#27);VtOut('Y');VtOut(Chr((32+B) And $FF));VtOut(Chr((32+A) And $FF));
   End;
  S_TCOLOR,S_TBACK: Begin
    A:=Pop32;
    VtOut(#27);If Sv=S_TCOLOR Then VtOut('b') Else VtOut('c');VtOut(Chr((32+A) And $FF));
   End;
  S_VT0..S_VT0+16: Begin
    I:=Sv-S_VT0;
    If VT_SEQ[I+1]<>' ' Then Begin VtOut(#27);VtOut(VT_SEQ[I+1]);End;
    OutPending:=True;
   End;
 Else
  If Not GemService(Sv) Then RtFail(100+Sv);
 End;
End;

Function ErrText(C: Integer): String;
Begin
 ErrText:=RtErrText(2);
End;

{ -------------------------------- TRAP --------------------------------- }

Procedure PsgUpdate;
Var Per: LongInt; F: LongInt;
Begin
 If Headless Then Exit;
 Per:=Psg[0]+(Psg[1] And 15)*256;
 If (Per>0) And ((Psg[8] And 15)>0) And ((Psg[7] And 1)=0) Then Begin
  F:=125000 Div Per;
  If F<20 Then F:=20;
  If F>10000 Then F:=10000;
  Sound(F);
 End Else NoSound;
End;

Procedure SetScreenCmd(L,P: LongInt);
Begin
 If (L>0) And (L<VMEM_SIZE-32000) Then ScrLog:=L;
 If (P>0) And (P<VMEM_SIZE-32000) Then ScrPhys:=P;
 OutBuf:=PByteArr(@VMem[ScrLog]);
 DispBuf:=PByteArr(@VMem[ScrPhys]);
 ScrCustom:=(ScrLog<>M_SCREEN) Or (ScrPhys<>M_SCREEN);
 OutPending:=True;
End;

Procedure DoTrapN(N: Integer);
Begin
 If RtTrace And ((N=13) Or (N=14)) Then Begin WriteLn(ErrOutput,'TRAP #',N,' fn=',RW(RA[7]));Flush(ErrOutput);End;
 If N=14 Then Begin
  Case RW(RA[7]) Of
   2: Begin RD[0]:=ScrPhys;Exit;End;
   3: Begin RD[0]:=ScrLog;Exit;End;
   5: Begin SetScreenCmd(RL(RA[7]+2),RL(RA[7]+6));RD[0]:=0;Exit;End;
   28: Begin
        { giaccess(data,reg) : generateur sonore YM2149 }
        If (RW(RA[7]+4) And $80)<>0 Then Begin
         Psg[RW(RA[7]+4) And 15]:=RW(RA[7]+2) And $FF;
         PsgUpdate;
         RD[0]:=Psg[RW(RA[7]+4) And 15];
        End Else RD[0]:=Psg[RW(RA[7]+4) And 15];
        Exit;
       End;
  End;
 End;
 Case N Of
  1: GemDos;
  2: Begin
      If (RD[0] And $FFFF)=$73 Then VdiCall(RD[1])
      Else If (RD[0] And $FFFF)=$C8 Then AesCall(RD[1]);
     End;
  6: RtService;
  13: If Not BiosEx Then Bios;
  14: If Not XBiosEx Then XBios;
 Else
  EmuHalt:=True;EmuMsg:='TRAP #'+IntStr(N);
 End;
 WL(M_HEAPLIM,EmuHeap+512);
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
  { ligne A : variables, polices et primitives }
  LineA(Op);
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


Var
 HeadIdleA : LongInt;           { mode batch : attentes d'evenements AES }
 CurPrgName : String;           { nom du programme en cours (shel_read) }
 PendExec,PendTail : String;    { shel_write : programme a lancer a la fin }
 BatchT0,BatchMax : LongInt;     { mode batch : limite de duree d'execution (centiemes de s) }
 ChainDepth : Integer;        { imbrication des Chain en cours }
 ProgStackHigh : LongInt;      { sommet de la zone pile+tas du programme ($S/$U) }
 PhysShadow : Array[0..31999] Of Byte;
 RunMsg   : String;
 RunCodeV : Integer;
 RunAborted : Boolean;

Procedure EmuLoop;
Var I: Integer;
Begin
 EmuSteps:=0;
 If ChainDepth=0 Then Begin
  BatchT0:=NowCs;BatchMax:=6000;
  If GetEnv('OSSTIMEOUT')<>'' Then Begin Val(GetEnv('OSSTIMEOUT'),BatchMax,I);BatchMax:=BatchMax*100;End;
 End;
 While (Not EmuHalt) And (Not EmuBrk) And (Not QuitReq) Do Begin
  If RtTrace And (GetEnv('OSSSTEP')<>'') Then Begin WriteLn(ErrOutput,'PC=',HexStr(RPC-PrgLoad,16),' OP=',HexStr(RW(RPC),16),' D0=',HexStr(RD[0],16),' D1=',HexStr(RD[1],16),' SP=',HexStr(RA[7],16));Flush(ErrOutput);End;
  Step;
  Inc(EmuSteps);
  If (EmuSteps And $3FFF)=0 Then Begin
   If EmuScreen And (Not ScrCustom) Then MemToOut;
   If ScrCustom Then Begin
    For I:=0 To 31999 Do If DispBuf^[I]<>PhysShadow[I] Then Begin
     Move(DispBuf^,PhysShadow,32000);OutPending:=True;Break;
    End;
   End;
   PollKeys;
   OutFlush(False);
   If BreakReq Then EmuBrk:=True;
   If Headless And (BatchMax>0) And (NowCs-BatchT0>BatchMax) And (NowCs>=BatchT0) Then Begin
    EmuMsg:=T3('Batch mode: time limit reached (OSSTIMEOUT)','Mode batch : dur'#130'e maximale atteinte (OSSTIMEOUT)','Batch-Modus: Zeitlimit erreicht (OSSTIMEOUT)');
    EmuHalt:=True;EmuCode:=-1;
   End;
  End;
 End;
 If EmuScreen And (Not ScrCustom) Then MemToOut;
End;

{ mise au point : OSSDUMPSCR=fichier ecrit l'ecran (32000 octets) a la fin du programme,
  OSSDUMP=adresse_hex:longueur:fichier ecrit une zone de memoire }
Procedure DumpMem(Addr,Len: LongInt; Const Fn: String);
Var F: File;
Begin
 If (Addr<0) Or (Len<=0) Or (Addr+Len>VMEM_SIZE) Then Exit;
 Assign(F,Fn);
 {$I-}Rewrite(F,1);{$I+}
 If IOResult<>0 Then Exit;
 BlockWrite(F,VMem[Addr],Len);
 Close(F);
End;

Procedure DebugDumps;
Var S,A,L,Fn: String; P1,P2,Ad,Ln,Cd: LongInt;
Begin
 S:=GetEnv('OSSDUMPSCR');
 If S<>'' Then DumpMem(M_SCREEN,32000,S);
 S:=GetEnv('OSSDUMP');
 If S<>'' Then Begin
  P1:=Pos(':',S);
  If P1>0 Then Begin
   A:=Copy(S,1,P1-1);Fn:=Copy(S,P1+1,200);
   P2:=Pos(':',Fn);
   If P2>0 Then Begin
    L:=Copy(Fn,1,P2-1);Fn:=Copy(Fn,P2+1,200);
    Ad:=0;
    For Cd:=1 To Length(A) Do Ad:=Ad*16+Pos(UpCase(A[Cd]),'0123456789ABCDEF')-1;
    Val(L,Ln,Cd);
    DumpMem(Ad,Ln,Fn);
   End;
  End;
 End;
End;

{ charge et execute un programme GEMDOS dans l'emulateur ; retourne False
  si le fichier ne peut pas etre charge }
Function RunCore(Const Name: String; Const Tail: String): Boolean;
Var F: File; Hd: Array[0..27] Of Byte; N: Word; Tl,Dl,Sl,Fx: LongInt; I: Integer;
    Ent: Array[0..13] Of Byte; Nm: String; Ad: LongInt; SKb,UKb,SH,OldSP: LongInt; Nx: String;
Begin
 RunCore:=False;
 RunMsg:='';RunCodeV:=0;
 PrgDebug:=False;DbgCount:=0;
 Assign(F,ResolveFile(Name));
 {$I-}Reset(F,1);{$I+}
 If IOResult<>0 Then Exit;
 BlockRead(F,Hd,28,N);
 If (N<28) Or (Hd[0]<>$60) Or (Hd[1]<>$1A) Then Begin Close(F);Exit;End;
 Tl:=(LongInt(Hd[2]) Shl 24) Or (LongInt(Hd[3]) Shl 16) Or (LongInt(Hd[4]) Shl 8) Or Hd[5];
 Dl:=(LongInt(Hd[6]) Shl 24) Or (LongInt(Hd[7]) Shl 16) Or (LongInt(Hd[8]) Shl 8) Or Hd[9];
 Sl:=(LongInt(Hd[14]) Shl 24) Or (LongInt(Hd[15]) Shl 16) Or (LongInt(Hd[16]) Shl 8) Or Hd[17];
 PrgDebug:=(Hd[22+2] And 1)<>0;
 If Hd[23]<>0 Then PrgDebug:=True;
 PrgText:=Tl;
 { symboles (mode debug) }
 If (Sl>0) And (Sl<=14*400) Then Begin
  Seek(F,28+Tl+Dl);
  For I:=1 To Sl Div 14 Do Begin
   BlockRead(F,Ent,14,N);
   If N<14 Then Break;
   Nm:='';
   For Fx:=0 To 7 Do If Ent[Fx]<>0 Then Nm:=Nm+Chr(Ent[Fx]);
   Ad:=(LongInt(Ent[10]) Shl 24) Or (LongInt(Ent[11]) Shl 16) Or (LongInt(Ent[12]) Shl 8) Or Ent[13];
   DbgCount:=I;DbgNames[I]:=Nm;DbgAddrs[I]:=Ad;
  End;
 End;
 Close(F);
 If Not LoadPRG(Name,Tail) Then Exit;
 PrgLoad:=RPC;
 { $S / $U : zone pile+tas du programme (champ reserve de l'en-tete) }
 SKb:=(Hd[18] Shl 8) Or Hd[19];UKb:=(Hd[20] Shl 8) Or Hd[21];
 If (SKb>0) Or (UKb>0) Or (Hd[18]+Hd[19]+Hd[20]+Hd[21]>0) Then Begin
  If SKb>0 Then SH:=EmuHeap+SKb*1024 Else SH:=M_TOP-UKb*1024;
  If SH>M_TOP Then SH:=M_TOP;
  If SH<EmuHeap+1024 Then SH:=EmuHeap+1024;
  SH:=SH And (Not 3);
 End Else SH:=M_TOP;
 OldSP:=RA[7];
 RA[7]:=SH-$40;
 Push32(RL(OldSP+4));Push32(RL(OldSP));
 WL(M_BASEPAGE+4,SH);
 WL(M_HEAPLIM,EmuHeap+512);
 ProgStackHigh:=SH;
 RunCore:=True;
 EmuHalt:=False;EmuBrk:=False;EmuCode:=0;EmuMsg:='';EmuSuper:=False;
 EmuSeed:=NowCs;RtSeed:=NowCs;VtState:=0;VtRev:=False;AesNext:=0;IoCheckOn:=True;IoRes:=0;ChainReq:='';RtTrace:=(GetEnv('OSSTRACE')<>'');
 AesReset;CurPrgName:=ShortName(Name);If ChainDepth=0 Then PendExec:='';
 For I:=6 To 25 Do EmuFUsed[I]:=False;
 OutSel:=0;InSel:=0;ConBuf:='';ConPos:=1;TmpIdx:=0;SetIdx:=0;GemMode:=False;GemUsed:=False;
 OXor:=False;DrawModeV:=1;TxtColV:=1;FilCol:=1;FilSty:=1;FilIdx:=1;LinCol:=1;
 FillChar(VMem[M_LINEA],256,0);
 WW(M_LINEA+2,2);WW(M_LINEA+12,80);WW(M_LINEA-12,640);WW(M_LINEA-4,400);
 WW(M_DBG,0);
 ScrLog:=M_SCREEN;ScrPhys:=M_SCREEN;ScrCustom:=False;ClipOn:=False;
 OutBuf:=OrigBuf;DispBuf:=OrigBuf;
 If ChainDepth=0 Then OutClear;     { un programme enchaine garde l'ecran }
 { l'ecran logique devient la memoire video emulee }
 Move(OrigBuf^,VMem[M_SCREEN],32000);
 Move(OrigBuf^,ScrShadow,32000);
 OutBuf:=PByteArr(@VMem[M_SCREEN]);DispBuf:=OutBuf;
 OutPending:=True;
 EmuScreen:=Not Headless;EmuActive:=True;
 BreakReq:=False;
 EmuLoop;
 EmuScreen:=False;
 If ChainDepth=0 Then DebugDumps;
 If ScrLog<>M_SCREEN Then Move(VMem[ScrLog],VMem[M_SCREEN],32000);
 Move(VMem[M_SCREEN],OrigBuf^,32000);
 ScrLog:=M_SCREEN;ScrPhys:=M_SCREEN;ScrCustom:=False;OutBuf:=OrigBuf;DispBuf:=OrigBuf;ClipOn:=False;
 OutPending:=True;
 CloseAllPFiles;
 For I:=6 To 25 Do If EmuFUsed[I] Then Begin {$I-}Close(EmuFile[I]);{$I+}If IOResult<>0 Then ;EmuFUsed[I]:=False;End;
 OutFlush(True);
 EmuActive:=False;
 RunMsg:=EmuMsg;RunCodeV:=EmuCode;RunAborted:=EmuBrk;
 If Headless Then WriteLn;
 { shel_write : programme a lancer apres la fin de celui-ci }
 If (PendExec<>'') And (ChainDepth=0) And (Not EmuBrk) And (EmuMsg='') Then Begin
  Nx:=PendExec;PendExec:='';
  If Pos('.',ShortName(Nx))=0 Then Nx:=Nx+'.PRG';
  If FileExists(ResolveFile(TosToHost(Nx))) Then RunCore(TosToHost(Nx),PendTail);
 End;
End;

{ CHAIN : execute le programme de la ligne de commande puis REPREND le programme
  appelant la ou il en etait (l'etat complet de l'emulateur est sauvegarde :
  memoire, registres, fichiers ouverts, curseur...). Comme sur TOS, l'ecran
  n'est pas restaure et le programme fils ne dispose que de la memoire laissee
  libre par les directives S et U du programme appelant. }
{ execute un programme enfant dans l'emulateur puis restaure completement l'etat du
  programme appelant (CHAIN, Pexec) ; retourne False si le fichier est illisible ;
  Code = code de sortie, Mess = message d'erreur d'execution eventuel }
Function NestedRun(Const Nm,Tl: String; Var Code: Integer; Var Mess: String): Boolean;
Var I: Integer;
    SvMem: PByteArr;
    SvRD,SvRA: Array[0..7] Of LongInt;
    SvPC,SvUSP,SvHeap,SvDta,SvSeed,SvStk,SvLog,SvPhys,SvPenX,SvPenY,SvLoad,SvText: LongInt;
    SvSR: Word;
    SvSuper,SvCustom,SvClip,SvGem,SvGemUsed,SvScreen,SvActive,SvIoChk,SvXor,SvRev: Boolean;
    SvOut,SvIn,SvCPos,SvIoRes,SvDbgN,SvTmp,SvSet,SvDm,SvTc,SvFc,SvFs,SvFi,SvLc,SvTs,SvVt: Integer;
    SvCon: String;
    SvCx1,SvCy1,SvCx2,SvCy2: LongInt;
    SvPF: Array[1..MAXFILES] Of TPFile;
    SvEF: Array[6..25] Of File;
    SvEFU: Array[6..25] Of Boolean;
    SvDbgNm: Array[1..400] Of String[12];
    SvDbgAd: Array[1..400] Of LongInt;
    SvDebug: Boolean;
    SvMsg: String; SvCode: Integer;
    Ok,Aborted: Boolean;
Begin
 { sauvegarde de l'etat du programme appelant }
 GetMem(SvMem,VMEM_SIZE);
 Move(VMem[0],SvMem^,VMEM_SIZE);
 SvRD:=RD;SvRA:=RA;SvPC:=RPC;SvSR:=RSR;SvUSP:=RUSP;SvHeap:=EmuHeap;SvDta:=EmuDta;
 SvSuper:=EmuSuper;SvSeed:=EmuSeed;SvStk:=ProgStackHigh;SvLog:=ScrLog;SvPhys:=ScrPhys;
 SvCustom:=ScrCustom;SvClip:=ClipOn;SvCx1:=ClipX1;SvCy1:=ClipY1;SvCx2:=ClipX2;SvCy2:=ClipY2;
 SvGem:=GemMode;SvGemUsed:=GemUsed;SvScreen:=EmuScreen;SvActive:=EmuActive;SvIoChk:=IoCheckOn;
 SvXor:=OXor;SvRev:=VtRev;SvPenX:=PenX;SvPenY:=PenY;SvLoad:=PrgLoad;SvText:=PrgText;
 SvOut:=OutSel;SvIn:=InSel;SvCon:=ConBuf;SvCPos:=ConPos;SvIoRes:=IoRes;SvDbgN:=DbgCount;
 SvTmp:=TmpIdx;SvSet:=SetIdx;SvDm:=DrawModeV;SvTc:=TxtColV;SvFc:=FilCol;SvFs:=FilSty;
 SvFi:=FilIdx;SvLc:=LinCol;SvTs:=TxtSize;SvVt:=VtState;
 SvDbgNm:=DbgNames;SvDbgAd:=DbgAddrs;SvDebug:=PrgDebug;SvMsg:=EmuMsg;SvCode:=EmuCode;
 SvPF:=PFiles;SvEF:=EmuFile;SvEFU:=EmuFUsed;
 { le programme fils part sans fichier ouvert (ceux du parent restent ouverts) }
 For I:=1 To MAXFILES Do PFiles[I].Used:=False;
 For I:=6 To 25 Do EmuFUsed[I]:=False;
 AesSave;
 Inc(ChainDepth);
 Ok:=RunCore(Nm,Tl);
 Dec(ChainDepth);
 AesRestore;
 Aborted:=RunAborted;
 Code:=RunCodeV;
 If Ok Then Mess:=RunMsg Else Mess:=T3('Cannot chain to ','Impossible d''encha'#140'ner vers ','Verkettung nicht moeglich: ')+Nm;
 { l'ecran reste tel que le fils l'a laisse (comme sur TOS) }
 If Mess<>'' Then Begin
  For I:=1 To Length(Mess) Do VtOut(Mess[I]);
  VtOut(#13);VtOut(#10);
 End;
 OutFlush(True);
 { restauration du programme appelant }
 Move(SvMem^,VMem[0],VMEM_SIZE);
 FreeMem(SvMem,VMEM_SIZE);
 { l'ecran reste celui du fils : on le remet dans la memoire video }
 Move(OrigBuf^,VMem[M_SCREEN],32000);
 RD:=SvRD;RA:=SvRA;RPC:=SvPC;RSR:=SvSR;RUSP:=SvUSP;EmuHeap:=SvHeap;EmuDta:=SvDta;
 EmuSuper:=SvSuper;EmuSeed:=SvSeed;ProgStackHigh:=SvStk;
 ClipOn:=SvClip;ClipX1:=SvCx1;ClipY1:=SvCy1;ClipX2:=SvCx2;ClipY2:=SvCy2;
 GemMode:=SvGem;GemUsed:=SvGemUsed;EmuScreen:=SvScreen;EmuActive:=SvActive;IoCheckOn:=SvIoChk;
 OXor:=SvXor;VtRev:=SvRev;PenX:=SvPenX;PenY:=SvPenY;PrgLoad:=SvLoad;PrgText:=SvText;
 OutSel:=SvOut;InSel:=SvIn;ConBuf:=SvCon;ConPos:=SvCPos;DbgCount:=SvDbgN;
 TmpIdx:=SvTmp;SetIdx:=SvSet;DrawModeV:=SvDm;TxtColV:=SvTc;FilCol:=SvFc;FilSty:=SvFs;
 FilIdx:=SvFi;LinCol:=SvLc;TxtSize:=SvTs;VtState:=SvVt;
 DbgNames:=SvDbgNm;DbgAddrs:=SvDbgAd;PrgDebug:=SvDebug;
 { fichiers du fils : refermes ; fichiers du parent : retablis }
 CloseAllPFiles;
 For I:=6 To 25 Do If EmuFUsed[I] Then Begin {$I-}Close(EmuFile[I]);{$I+}If IOResult<>0 Then ;End;
 PFiles:=SvPF;EmuFile:=SvEF;EmuFUsed:=SvEFU;
 EmuMsg:=SvMsg;EmuCode:=SvCode;EmuHalt:=False;EmuBrk:=Aborted;
 { ecran : on garde l'image laissee par le fils }
 SetScreenCmd(SvLog,SvPhys);
 If Not SvCustom Then Move(VMem[M_SCREEN],ScrShadow,32000);
 OutPending:=True;
 BreakReq:=False;
 IoRes:=SvIoRes;
 NestedRun:=Ok;
End;

{ CHAIN : execute le programme de la ligne de commande puis REPREND le programme
  appelant la ou il en etait. Comme sur TOS, l'ecran n'est pas restaure et le
  programme fils ne dispose que de la memoire laissee libre par {$S} / {$U}. }
Procedure DoChain(Const Cmd0: String);
Var Cm,Nm,Tl,Mess: String; I,Code: Integer; F: File; Hd: Array[0..27] Of Byte; N: Word;
    Need,Left,SK: LongInt;
Begin
 IoRes:=0;
 Cm:=TrimStr(Cmd0);
 I:=Pos(' ',Cm);
 If I=0 Then Begin Nm:=Cm;Tl:='';End Else Begin Nm:=Copy(Cm,1,I-1);Tl:=TrimStr(Copy(Cm,I+1,255));End;
 If Tl<>'' Then Tl:=' '+Tl;
 If Nm='' Then Begin IoFail(0,-33);Exit;End;
 If Pos('.',ShortName(Nm))=0 Then Begin
  If FileExists(ResolveFile(Nm+'.PRG')) Then Nm:=Nm+'.PRG' Else Nm:=Nm+'.TOS';
 End;
 If (Not FileExists(ResolveFile(Nm))) Or (ChainDepth>=6) Then Begin IoFail(0,-33);Exit;End;
 { memoire necessaire au programme fils / memoire laissee par le parent }
 Assign(F,ResolveFile(Nm));
 {$I-}Reset(F,1);{$I+}
 If IOResult<>0 Then Begin IoFail(0,-33);Exit;End;
 BlockRead(F,Hd,28,N);
 Close(F);
 If (N<28) Or (Hd[0]<>$60) Or (Hd[1]<>$1A) Then Begin IoFail(0,-66);Exit;End;
 SK:=(LongInt(Hd[18]) Shl 8) Or Hd[19];
 Need:=((LongInt(Hd[2]) Shl 24) Or (LongInt(Hd[3]) Shl 16) Or (LongInt(Hd[4]) Shl 8) Or Hd[5])
      +((LongInt(Hd[6]) Shl 24) Or (LongInt(Hd[7]) Shl 16) Or (LongInt(Hd[8]) Shl 8) Or Hd[9])
      +((LongInt(Hd[10]) Shl 24) Or (LongInt(Hd[11]) Shl 16) Or (LongInt(Hd[12]) Shl 8) Or Hd[13])+$100;
 If SK>0 Then Need:=Need+SK*1024 Else Need:=Need+16384;
 Left:=M_TOP-ProgStackHigh;
 If Left<Need Then Begin
  IoRes:=-39;
  If IoCheckOn Then Begin
   RtFail(7);
   EmuMsg:=T3('Chain: not enough memory left for the chained program (use {$S} or {$U})',
              'Chain : pas assez de m'#130'moire pour le programme encha'#140'n'#130' (utiliser {$S} ou {$U})',
              'Chain: zu wenig Speicher fuer das Programm ({$S} oder {$U} verwenden)');
  End;
  Exit;
 End;
 NestedRun(Nm,Tl,Code,Mess);
End;

{$ELSE}

Function RunCore(Const Name: String; Const Tail: String): Boolean;
Begin
 RunCore:=False;
End;

{$ENDIF}
{$IFDEF FPC}
{ ====================================================================== }
{                  GEMDOS EMULE (fichiers, memoire, Pexec)               }
{ ====================================================================== }

Var
 Redir    : Array[0..5] Of Integer;     { handle standard -> handle fichier (>=6), -1 console }
 EmuCwd   : String;
 SfDir    : String;
 SfPat    : String;
 SfAttr   : Integer;
 Allocs   : Array[1..32] Of Record A,S: LongInt; End;
 AllocN   : Integer;

{ nom TOS -> nom de fichier hote : lettre de lecteur retiree, \ devient /, la racine
  du lecteur est le repertoire de travail }
Function TosToHost(Const S0: String): String;
Var S: String; I: Integer;
Begin
 S:=S0;
 While (Length(S)>0) And (S[Length(S)]=' ') Do Delete(S,Length(S),1);
 While (Length(S)>0) And (S[1]=' ') Do Delete(S,1,1);
 If (Length(S)>=2) And (S[2]=':') And (UpCase(S[1]) In ['A'..'Z']) Then Delete(S,1,2);
 For I:=1 To Length(S) Do If S[I]='\' Then S[I]:='/';
 While (Length(S)>0) And (S[1]='/') Do Delete(S,1,1);
 If S='' Then S:='.';
 TosToHost:=S;
End;

{ nom de fichier a creer : repertoire resolu sans tenir compte de la casse, nom en
  majuscules comme sur TOS (sauf si le fichier existe deja) }
Function CreateName(Const S0: String): String;
Var S,Dir,Base: String; I,P: Integer;
Begin
 S:=TosToHost(S0);
 P:=0;
 For I:=1 To Length(S) Do If S[I]='/' Then P:=I;
 If P>0 Then Begin Dir:=Copy(S,1,P);Base:=Copy(S,P+1,100);End Else Begin Dir:='';Base:=S;End;
 If FileExists(ResolveFile(S)) Then CreateName:=ResolveFile(S)
 Else If Dir<>'' Then CreateName:=ResolveFile(Copy(Dir,1,Length(Dir)-1))+'/'+Upper(Base)
 Else CreateName:=Upper(Base);
End;

Function TosMatch(Const Pat,Nm: String): Boolean;
 Function M(P,N: Integer): Boolean;
 Begin
  While P<=Length(Pat) Do Begin
   If Pat[P]='*' Then Begin
    While P<=Length(Pat) Do Begin
     If Pat[P]<>'*' Then Break;
     Inc(P);
    End;
    If P>Length(Pat) Then Begin M:=True;Exit;End;
    While N<=Length(Nm)+1 Do Begin
     If M(P,N) Then Begin M:=True;Exit;End;
     Inc(N);
    End;
    M:=False;Exit;
   End Else If N>Length(Nm) Then Begin M:=False;Exit;End
   Else If (Pat[P]<>'?') And (Pat[P]<>Nm[N]) Then Begin M:=False;Exit;End;
   Inc(P);Inc(N);
  End;
  M:=(N>Length(Nm));
 End;
Begin
 If Pat='*.*' Then Begin TosMatch:=True;Exit;End;
 TosMatch:=M(1,1);
End;

Function NextMatch(First: Boolean): Boolean;
Begin
 NextMatch:=False;
 If First Then Begin
  {$I-}FindFirst(SfDir+'*',AnyFile,EmuSF);{$I+}
 End Else Begin
  {$I-}FindNext(EmuSF);{$I+}
 End;
 While DosError=0 Do Begin
  If TosMatch(SfPat,Upper(EmuSF.Name)) And
     (((EmuSF.Attr And Directory)=0) Or ((SfAttr And $10)<>0)) And (EmuSF.Name<>'.') And (EmuSF.Name<>'..') Then Begin
   NextMatch:=True;Exit;
  End;
  {$I-}FindNext(EmuSF);{$I+}
 End;
End;

Procedure StdIn(A,Cnt: LongInt;Var Got: LongInt);
Var Ch: Integer;
Begin
 Got:=0;
 If ConPos>Length(ConBuf) Then ConFetch;
 While (Got<Cnt) And (ConPos<=Length(ConBuf)) Do Begin
  WB(A+Got,Ord(ConBuf[ConPos]));Inc(Got);
  If ConBuf[ConPos]=#13 Then Begin
   If Got<Cnt Then Begin WB(A+Got,10);Inc(Got);End;
  End;
  Inc(ConPos);
 End;
 Ch:=0;
End;

Procedure PutDtaName(Const S: String);
Begin
 PutStr(EmuDta+30,Copy(Upper(S),1,13));
End;

Procedure GemDos;
Var Fn: Word; SP: LongInt; H,R,I,Code: Integer; S,S2,Mess,Tl: String; A,Cnt,Len,Pos2,Done: LongInt; Mode: Integer;
    FH: File; At: Word; T: LongInt; Y,Mo,D,Dw,Hh,Mi,Sc,S100: Word; Ss: Int64; Yy,Mm,Dd: LongInt;
 Procedure Cons(A,Cnt: LongInt);
 Var K: LongInt;
 Begin
  For K:=0 To Cnt-1 Do VtOut(Chr(RB(A+K)));
  OutToMem;
 End;
 Function OpenFile(Const Nm: String; Md: Integer): Integer;
 Var HH: Integer; Sx: String;
 Begin
  HH:=HandleFile;
  If HH<0 Then Begin OpenFile:=-35;Exit;End;
  Sx:=ResolveFile(TosToHost(Nm));
  If Not FileExists(Sx) Then Begin OpenFile:=-33;Exit;End;
  Assign(EmuFile[HH],Sx);
  If Md=0 Then FileMode:=0 Else FileMode:=2;
  {$I-}Reset(EmuFile[HH],1);{$I+}
  FileMode:=2;
  If IOResult<>0 Then Begin OpenFile:=-36;Exit;End;
  EmuFUsed[HH]:=True;OpenFile:=HH;
 End;
Begin
 SP:=RA[7];
 Fn:=RW(SP);
 If RtTrace Then Begin WriteLn(ErrOutput,'GEMDOS ',Fn);Flush(ErrOutput);End;
 Case Fn Of
  0: Begin EmuHalt:=True;EmuCode:=0;End;
  1: RD[0]:=EmuKey;
  2: Begin VtOut(Chr(RW(SP+2) And $FF));OutToMem;End;
  3: RD[0]:=0;
  4,5: RD[0]:=0;
  6: If RW(SP+2)=$FF Then Begin
      If KeyPressed Or (KeyQ<>'') Then RD[0]:=EmuKey Else RD[0]:=0;
     End Else Begin VtOut(Chr(RW(SP+2) And $FF));OutToMem;RD[0]:=0;End;
  7,8: RD[0]:=EmuKey;
  9: Begin
      S:=EmuStr(RL(SP+2));
      VtStr(S);OutToMem;
      RD[0]:=0;
     End;
  10: Begin
       A:=RL(SP+2);
       If Headless Then Begin
        If ConPos>Length(ConBuf) Then ConFetch;
        S:=Copy(ConBuf,ConPos,Length(ConBuf)-ConPos);ConPos:=Length(ConBuf)+1;
        S:=Copy(S,1,RB(A));
        WB(A+1,Length(S));PutStr(A+2,S);RD[0]:=Length(S);
       End Else If ReadOutLine(S,Min2(RB(A),250),False) Then Begin
        WB(A+1,Length(S));
        PutStr(A+2,S);
        RD[0]:=Length(S);
       End Else EmuBrk:=True;
      End;
  11: If KeyPressed Or (KeyQ<>'') Then RD[0]:=-1 Else RD[0]:=0;
  14: RD[0]:=4;
  16,19: RD[0]:=-1;
  17: RD[0]:=-1;
  18: RD[0]:=0;
  25: RD[0]:=2;
  26: EmuDta:=RL(SP+2);
  32: Begin
       A:=RL(SP+2);
       If A=1 Then Begin If EmuSuper Then RD[0]:=-1 Else RD[0]:=0;End
       Else Begin EmuSuper:=Not EmuSuper;RD[0]:=RA[7];End;
      End;
  42: Begin
       Ss:=StNowSecs;CivilFromDays(Ss Div 86400,Yy,Mm,Dd);
       RD[0]:=((Yy-1980) Shl 9) Or (Mm Shl 5) Or Dd;
      End;
  43: Begin
       T:=RW(SP+2);
       Yy:=1980+(T Shr 9);Mm:=(T Shr 5) And 15;Dd:=T And 31;
       If (Mm<1) Or (Mm>12) Or (Dd<1) Then RD[0]:=-13
       Else Begin
        ClockAdj:=Int64(DaysFromCivil(Yy,Mm,Dd))*86400+(StNowSecs Mod 86400)-HostNowSecs;
        RD[0]:=0;
       End;
      End;
  44: Begin
       Ss:=StNowSecs Mod 86400;
       RD[0]:=((Ss Div 3600) Shl 11) Or (((Ss Div 60) Mod 60) Shl 5) Or ((Ss Mod 60) Div 2);
      End;
  45: Begin
       T:=RW(SP+2);
       Ss:=(StNowSecs Div 86400)*86400+(T Shr 11)*3600+((T Shr 5) And 63)*60+(T And 31)*2;
       ClockAdj:=Ss-HostNowSecs;
       RD[0]:=0;
      End;
  47: RD[0]:=EmuDta;
  48: RD[0]:=$1500;
  49: Begin EmuHalt:=True;EmuCode:=SmallInt(RW(SP+2));End;
  54: Begin
       A:=RL(SP+2);
       WL(A,20000);WL(A+4,40000);WL(A+8,512);WL(A+12,2);RD[0]:=0;
      End;
  57: Begin
       {$I-}MkDir(CreateName(EmuStr(RL(SP+2))));{$I+}
       If IOResult<>0 Then RD[0]:=-36 Else RD[0]:=0;
      End;
  58: Begin
       {$I-}RmDir(ResolveFile(TosToHost(EmuStr(RL(SP+2)))));{$I+}
       If IOResult<>0 Then RD[0]:=-36 Else RD[0]:=0;
      End;
  59: Begin EmuCwd:=EmuStr(RL(SP+2));RD[0]:=0;End;
  60: Begin
       S:=EmuStr(RL(SP+2));
       H:=HandleFile;
       If H<0 Then RD[0]:=-35
       Else Begin
        Assign(EmuFile[H],CreateName(S));
        {$I-}Rewrite(EmuFile[H],1);{$I+}
        If IOResult<>0 Then RD[0]:=-36 Else Begin EmuFUsed[H]:=True;RD[0]:=H;End;
       End;
      End;
  61: RD[0]:=OpenFile(EmuStr(RL(SP+2)),RW(SP+6) And 3);
  62: Begin
       H:=RW(SP+2);
       If (H>=6) And (H<=25) And EmuFUsed[H] Then Begin
        {$I-}Close(EmuFile[H]);{$I+}
        If IOResult<>0 Then ;
        EmuFUsed[H]:=False;RD[0]:=0;
        For I:=0 To 5 Do If Redir[I]=H Then Redir[I]:=-1;
       End Else If H<6 Then RD[0]:=0 Else RD[0]:=-37;
      End;
  63: Begin
       H:=SmallInt(RW(SP+2));Cnt:=RL(SP+4);A:=RL(SP+8);
       If (H>=0) And (H<=5) And (Redir[H]>=6) Then H:=Redir[H];
       If (H>=6) And (H<=25) And EmuFUsed[H] Then Begin
        If Cnt>VMEM_SIZE-A Then Cnt:=VMEM_SIZE-A;
        If Cnt<0 Then Cnt:=0;
        Done:=0;
        {$I-}BlockRead(EmuFile[H],VMem[A],Cnt,Done);{$I+}
        If IOResult<>0 Then RD[0]:=-12 Else RD[0]:=Done;
       End Else If H=0 Then Begin StdIn(A,Cnt,Done);RD[0]:=Done;End
       Else RD[0]:=-37;
      End;
  64: Begin
       H:=SmallInt(RW(SP+2));Cnt:=RL(SP+4);A:=RL(SP+8);
       If (H>=0) And (H<=5) And (Redir[H]>=6) Then H:=Redir[H];
       If (H>=6) And (H<=25) And EmuFUsed[H] Then Begin
        Done:=0;
        {$I-}BlockWrite(EmuFile[H],VMem[A],Cnt,Done);{$I+}
        If IOResult<>0 Then RD[0]:=-12 Else RD[0]:=Done;
       End Else If (H=1) Or (H=2) Or (H<0) Then Begin
        Cons(A,Cnt);RD[0]:=Cnt;
       End Else If (H=3) Or (H=4) Or (H=5) Then RD[0]:=Cnt
       Else RD[0]:=-37;
      End;
  65: Begin
       S:=ResolveFile(TosToHost(EmuStr(RL(SP+2))));
       If Not FileExists(S) Then RD[0]:=-33
       Else Begin Assign(FH,S);{$I-}Erase(FH);{$I+}If IOResult<>0 Then RD[0]:=-36 Else RD[0]:=0;End;
      End;
  66: Begin
       Pos2:=RL(SP+2);Mode:=RW(SP+8);H:=RW(SP+6);
       If (H>=6) And (H<=25) And EmuFUsed[H] Then Begin
        If Mode=1 Then Pos2:=Pos2+FilePos(EmuFile[H])
        Else If Mode=2 Then Pos2:=Pos2+FileSize(EmuFile[H]);
        If Pos2<0 Then Pos2:=0;
        {$I-}Seek(EmuFile[H],Pos2);{$I+}
        If IOResult<>0 Then RD[0]:=-64 Else RD[0]:=Pos2;
       End Else RD[0]:=-37;
      End;
  67: Begin
       S:=ResolveFile(TosToHost(EmuStr(RL(SP+2))));
       If Not FileExists(S) Then Begin
        {$I-}FindFirst(S,Directory,EmuSF);{$I+}
        If DosError=0 Then RD[0]:=$10 Else RD[0]:=-33;
       End Else Begin
        Assign(FH,S);At:=0;
        {$I-}GetFAttr(FH,At);{$I+}
        If IOResult<>0 Then At:=0;
        RD[0]:=At And $27;
       End;
      End;
  69: Begin
       H:=RW(SP+2);
       If H<=5 Then RD[0]:=100+H Else RD[0]:=H;
      End;
  70: Begin
       { Fforce(standard, remplacant) : redirection des entrees/sorties }
       H:=RW(SP+2);I:=RW(SP+4);
       If (H>=0) And (H<=5) Then Begin
        If I>=100 Then Redir[H]:=-1 Else If I>=6 Then Redir[H]:=I Else Redir[H]:=-1;
       End;
       RD[0]:=0;
      End;
  71: Begin PutStr(RL(SP+2),EmuCwd);RD[0]:=0;End;
  72: Begin
       { Malloc : memoire libre au dessus du bloc du programme, sous la pile du systeme }
       Cnt:=RL(SP+2);
       If Cnt=-1 Then RD[0]:=M_TOP-$4000-EmuHeap
       Else Begin
        Cnt:=(Cnt+3) And (Not 3);
        If (Cnt<0) Or (EmuHeap+Cnt>M_TOP-$4000) Then RD[0]:=0
        Else Begin
         RD[0]:=EmuHeap;FillChar(VMem[EmuHeap],Cnt,0);
         If AllocN<32 Then Begin Inc(AllocN);Allocs[AllocN].A:=EmuHeap;Allocs[AllocN].S:=Cnt;End;
         EmuHeap:=EmuHeap+Cnt;
        End;
       End;
       If RtTrace Then Begin WriteLn(ErrOutput,'Malloc(',RL(SP+2),') -> ',RD[0],' heap=',EmuHeap);Flush(ErrOutput);End;
      End;
  73: Begin
       A:=RL(SP+2);
       If (AllocN>0) And (Allocs[AllocN].A=A) Then Begin EmuHeap:=A;Dec(AllocN);End;
       RD[0]:=0;
      End;
  74: Begin
       { Mshrink(0, bloc, taille) : la memoire au dela du bloc conserve devient disponible pour Malloc }
       A:=RL(SP+4)+RL(SP+8);
       If (RL(SP+4)=M_BASEPAGE) And (A>EmuHeap) And (A<M_TOP) Then EmuHeap:=(A+3) And (Not 3);
       RD[0]:=0;
      End;
  75: Begin
       { Pexec : seul le mode 0 (charger et lancer) est gere }
       Mode:=RW(SP+2);
       If Mode=0 Then Begin
        S:=TosToHost(EmuStr(RL(SP+4)));
        A:=RL(SP+8);
        Tl:='';
        For I:=1 To RB(A) Do If I<=125 Then Tl:=Tl+Chr(RB(A+I));
        If RtTrace Then Begin WriteLn(ErrOutput,'Pexec "',S,'" tail="',Tl,'"');Flush(ErrOutput);End;
        If ChainDepth>=6 Then RD[0]:=-39
        Else If NestedRun(S,Tl,Code,Mess) Then Begin
         RD[0]:=Code;
         If RtTrace Then Begin WriteLn(ErrOutput,'Pexec termine code=',Code,' msg=',Mess);Flush(ErrOutput);End;
        End Else RD[0]:=-33;
       End Else RD[0]:=-32;
      End;
  76: Begin EmuHalt:=True;EmuCode:=SmallInt(RW(SP+2));End;
  78: Begin
       S:=TosToHost(EmuStr(RL(SP+2)));
       SfAttr:=RW(SP+6);
       I:=0;
       For H:=1 To Length(S) Do If S[H]='/' Then I:=H;
       If I>0 Then Begin SfDir:=ResolveFile(Copy(S,1,I-1))+'/';SfPat:=Upper(Copy(S,I+1,100));End
       Else Begin SfDir:='';SfPat:=Upper(S);End;
       If NextMatch(True) Then Begin FillDta(EmuSF);RD[0]:=0;End Else RD[0]:=-33;
      End;
  79: Begin
       { Fsnext : ENMFIL (-49) quand il n'y a plus de fichier }
       If NextMatch(False) Then Begin FillDta(EmuSF);RD[0]:=0;End Else RD[0]:=-49;
      End;
  86: Begin
       S:=ResolveFile(TosToHost(EmuStr(RL(SP+4))));
       S2:=CreateName(EmuStr(RL(SP+8)));
       If Not FileExists(S) Then RD[0]:=-33
       Else Begin
        Assign(FH,S);
        {$I-}Rename(FH,S2);{$I+}
        If IOResult<>0 Then RD[0]:=-36 Else RD[0]:=0;
       End;
      End;
  87: Begin
       A:=RL(SP+2);H:=RW(SP+6);
       If (RW(SP+8)=0) And (H>=6) And (H<=25) And EmuFUsed[H] Then Begin
        T:=0;
        {$I-}GetFTime(EmuFile[H],T);{$I+}
        If IOResult<>0 Then T:=0;
        WW(A,T And $FFFF);WW(A+2,(T Shr 16) And $FFFF);
       End;
       RD[0]:=0;
      End;
 Else
  If RtTrace Then Begin WriteLn(ErrOutput,'GEMDOS non implemente : ',Fn);Flush(ErrOutput);End;
  RD[0]:=-32;
 End;
End;


{$ENDIF}
{$IFDEF FPC}
{ ====================================================================== }
{          VDI EMULE : POSTES DE TRAVAIL, PRIMITIVES, TEXTE, RASTERS      }
{ ====================================================================== }
{ Le VDI dessine dans le tampon ecran logique (OutBuf) en monochrome haute
  resolution 640x400 : l'indice de couleur 0 est le blanc, tout autre indice
  est le noir. Chaque poste de travail (v_opnvwk) a ses propres attributs. }

Const
 VD_MAX = 8;
 V_BIG_ASC = 13;               { ligne de base dans la cellule 8x16 }
 V_SML_ASC = 7;                { ligne de base dans la cellule 8x8 }

Type
 TVdi = Record
  Used  : Boolean;
  Wr    : Integer;             { mode d'ecriture 1..4 }
  LnT,LnW,LnC,LnB,LnE : Integer;
  UdLn  : Word;
  MkT,MkH,MkC : Integer;
  TxF,TxC,TxH,TxEff,TxRot,TxHA,TxVA : Integer;
  FlI,FlS,FlC,FlP : Integer;
  UdPat : Array[0..15] Of Word;
  ClipOn : Boolean;
  CX1,CY1,CX2,CY2 : Integer;
 End;

Var
 Vd     : Array[0..VD_MAX] Of TVdi;     { 0 : etat interne de l'AES }
 VdCur  : Integer;
 VIn,VPts,VOut,VPOut,VCtl : LongInt;   { tableaux du bloc de parametres VDI }

Procedure VdDefaults(H: Integer);
Var I: Integer;
Begin
 FillChar(Vd[H],SizeOf(TVdi),0);
 With Vd[H] Do Begin
  Used:=True;Wr:=1;LnT:=1;LnW:=1;LnC:=1;LnB:=0;LnE:=0;UdLn:=$FFFF;
  MkT:=3;MkH:=11;MkC:=1;TxF:=1;TxC:=1;TxH:=13;TxEff:=0;TxRot:=0;TxHA:=0;TxVA:=0;
  FlI:=0;FlS:=1;FlC:=1;FlP:=1;
  For I:=0 To 15 Do UdPat[I]:=$AAAA;
  ClipOn:=False;CX1:=0;CY1:=0;CX2:=639;CY2:=399;
 End;
End;

Function VW(I: Integer): Integer;       { mot I de intin }
Begin VW:=SmallInt(RW(VIn+I*2)); End;

Function VP(I: Integer): Integer;       { coordonnee I de ptsin }
Begin VP:=SmallInt(RW(VPts+I*2)); End;

Procedure VSetOut(I,V: Integer);
Begin WW(VOut+I*2,Word(V)); End;

Procedure VSetPts(I,V: Integer);
Begin WW(VPOut+I*2,Word(V)); End;

Function VInk(C: Integer): Integer;
Begin If C<>0 Then VInk:=1 Else VInk:=0; End;

{ point : Fg indique si le pixel fait partie de la forme (motif a 1) }
Procedure VPix(X,Y: LongInt; Fg: Boolean; Ink: Integer);
Var I: Byte;
Begin
 If Ink<>0 Then I:=1 Else I:=0;
 Case Vd[VdCur].Wr Of
  2: If Fg Then OPlot(X,Y,I);
  3: If Fg And (I<>0) Then Begin OXor:=True;OPlot(X,Y,1);OXor:=False;End;
  4: If Not Fg Then OPlot(X,Y,I);
 Else
  If Fg Then OPlot(X,Y,I) Else OPlot(X,Y,0);
 End;
End;

{ ------------------------------ lignes -------------------------------- }

Function VLinePat: Word;
Begin
 With Vd[VdCur] Do
  Case LnT Of
   2: VLinePat:=$FFF0;
   3: VLinePat:=$C0C0;
   4: VLinePat:=$FF18;
   5: VLinePat:=$FF00;
   6: VLinePat:=$F191;
   7: VLinePat:=UdLn;
  Else VLinePat:=$FFFF;
  End;
End;

Procedure VSeg(X1,Y1,X2,Y2: LongInt; Pat: Word; Var Phase: Integer; Ink: Integer);
Var DX,DY,SX,SY,Err,E2: LongInt; Bit: Boolean;
Begin
 DX:=Abs(X2-X1);DY:=Abs(Y2-Y1);
 If X1<X2 Then SX:=1 Else SX:=-1;
 If Y1<Y2 Then SY:=1 Else SY:=-1;
 Err:=DX-DY;
 Repeat
  Bit:=((Pat Shr (15-(Phase And 15))) And 1)<>0;
  Inc(Phase);
  VPix(X1,Y1,Bit,Ink);
  If (X1=X2) And (Y1=Y2) Then Break;
  E2:=2*Err;
  If E2>-DY Then Begin Err:=Err-DY;X1:=X1+SX;End;
  If E2<DX Then Begin Err:=Err+DX;Y1:=Y1+SY;End;
 Until False;
End;

{ segment avec epaisseur et motif ; Phase continue le motif d'un segment a l'autre }
Procedure VLine2(X1,Y1,X2,Y2: LongInt; Var Phase: Integer);
Var W,K,Ph0: Integer; Pat: Word; Ink: Integer;
Begin
 W:=Vd[VdCur].LnW;
 If W<1 Then W:=1;
 Pat:=VLinePat;Ink:=Vd[VdCur].LnC;
 Ph0:=Phase;
 For K:=-((W-1) Div 2) To W Div 2 Do Begin
  Phase:=Ph0;
  If Abs(X2-X1)>=Abs(Y2-Y1) Then VSeg(X1,Y1+K,X2,Y2+K,Pat,Phase,Ink)
  Else VSeg(X1+K,Y1,X2+K,Y2,Pat,Phase,Ink);
 End;
End;

Procedure VPolyline(N: Integer);       { points dans ptsin }
Var I,Ph: Integer;
Begin
 Ph:=0;
 If N=1 Then VLine2(VP(0),VP(1),VP(0),VP(1),Ph);
 For I:=0 To N-2 Do VLine2(VP(I*2),VP(I*2+1),VP(I*2+2),VP(I*2+3),Ph);
End;

{ polygone PX/PY (N points) trace comme contour ferme en trait plein }
Procedure VOutline(N: Integer; Ink: Integer; Closed: Boolean);
Var I,J,Ph: Integer;
Begin
 Ph:=0;
 For I:=0 To N-1 Do Begin
  J:=I+1;
  If J>=N Then Begin If Closed Then J:=0 Else Break;End;
  VSeg(PX[I],PY[I],PX[J],PY[J],$FFFF,Ph,Ink);
 End;
End;

{ ----------------------------- remplissages ---------------------------- }

Function VFillBit(X,Y: LongInt): Boolean;
Var P,T: Integer; Bk: Boolean;
Begin
 With Vd[VdCur] Do
  Case FlI Of
   0: VFillBit:=False;
   1: VFillBit:=True;
   2: Begin
       If FlS<=0 Then VFillBit:=False
       Else If FlS>=24 Then VFillBit:=True
       Else VFillBit:=BayerM[Y And 7,X And 7]<(LongInt(FlS)*64 Div 25);
      End;
   3: Begin
       If FlS<=6 Then P:=4 Else P:=8;
       T:=(FlS-1) Mod 6;
       If T<0 Then T:=0;
       Bk:=False;
       Case T Of
        0: Bk:=(Y Mod P)=0;
        1: Bk:=(X Mod P)=0;
        2: Bk:=((X+Y) Mod P)=0;
        3: Bk:=((X-Y+1024) Mod P)=0;
        4: Bk:=((X Mod P)=0) Or ((Y Mod P)=0);
        5: Bk:=(((X+Y) Mod P)=0) Or (((X-Y+1024) Mod P)=0);
       End;
       VFillBit:=Bk;
      End;
   4: VFillBit:=((UdPat[Y And 15] Shr (15-(X And 15))) And 1)<>0;
  Else VFillBit:=True;
  End;
End;

Procedure VFillRect(X1,Y1,X2,Y2: LongInt);
Var X,Y,T: LongInt;
Begin
 If X1>X2 Then Begin T:=X1;X1:=X2;X2:=T;End;
 If Y1>Y2 Then Begin T:=Y1;Y1:=Y2;Y2:=T;End;
 If X1<0 Then X1:=0;
 If Y1<0 Then Y1:=0;
 If X2>OUT_W-1 Then X2:=OUT_W-1;
 If Y2>OUT_H-1 Then Y2:=OUT_H-1;
 If Vd[VdCur].ClipOn Then Begin
  If X1<Vd[VdCur].CX1 Then X1:=Vd[VdCur].CX1;
  If Y1<Vd[VdCur].CY1 Then Y1:=Vd[VdCur].CY1;
  If X2>Vd[VdCur].CX2 Then X2:=Vd[VdCur].CX2;
  If Y2>Vd[VdCur].CY2 Then Y2:=Vd[VdCur].CY2;
 End;
 For Y:=Y1 To Y2 Do
  For X:=X1 To X2 Do VPix(X,Y,VFillBit(X,Y),Vd[VdCur].FlC);
End;

Procedure VFillPoly(N: Integer);
Var YMin,YMax,Y,I,J,K,CntX,T: Integer; X1,Y1,X2,Y2,Xa,Xb,X: Integer;
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
    If CntX<799 Then Begin
     IXS[CntX]:=Round(X1+(Y-Y1)*(X2-X1)/(Y2-Y1));
     Inc(CntX);
    End;
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
   If Xa<0 Then Xa:=0;
   If Xb>OUT_W-1 Then Xb:=OUT_W-1;
   For X:=Xa To Xb Do VPix(X,Y,VFillBit(X,Y),Vd[VdCur].FlC);
   Inc(I,2);
  End;
 End;
End;

{ forme PX/PY remplie puis cerclee si le perimetre est actif }
Procedure VShape(N: Integer; Fill: Boolean);
Begin
 If Fill Then VFillPoly(N);
 If Vd[VdCur].FlP<>0 Then VOutline(N,Vd[VdCur].FlC,True);
End;

Procedure VArcPoly(CX,CY,RX,RY,A1,A2: LongInt; Pie: Boolean; Fill: Boolean);
Var N: Integer;
Begin
 If RX<1 Then RX:=1;
 If RY<1 Then RY:=1;
 N:=ArcPoints(CX,CY,RX,RY,A1,A2);
 If Pie Then Begin
  If ((A2-A1)<3600) And ((A2-A1)>0) Then Begin PX[N]:=CX;PY[N]:=CY;Inc(N);End;
  VShape(N,Fill);
 End Else Begin
  VOutline(N,Vd[VdCur].LnC,False);
 End;
End;

Procedure VRoundRect(X1,Y1,X2,Y2: LongInt; Fill: Boolean);
Var N,K,R,W,H: Integer; A: Real; CX,CY,SX,SY: Integer; T: LongInt;
Begin
 If X1>X2 Then Begin T:=X1;X1:=X2;X2:=T;End;
 If Y1>Y2 Then Begin T:=Y1;Y1:=Y2;Y2:=T;End;
 W:=X2-X1;H:=Y2-Y1;
 R:=W;If H<R Then R:=H;
 R:=R Div 4;
 If R<2 Then R:=2;
 If R>12 Then R:=12;
 N:=0;
 For K:=0 To 3 Do Begin
  Case K Of
   0: Begin CX:=X2-R;CY:=Y1+R;End;
   1: Begin CX:=X1+R;CY:=Y1+R;End;
   2: Begin CX:=X1+R;CY:=Y2-R;End;
  Else Begin CX:=X2-R;CY:=Y2-R;End;
  End;
  For SX:=0 To 6 Do Begin
   A:=(K*90+SX*15)*Pi/180;
   PX[N]:=CX+Round(R*Cos(A));PY[N]:=CY-Round(R*Sin(A));Inc(N);
  End;
 End;
 If Fill Then Begin VFillPoly(N);If Vd[VdCur].FlP<>0 Then VOutline(N,Vd[VdCur].FlC,True);End
 Else VOutline(N,Vd[VdCur].LnC,True);
 SY:=0;
End;

{ ------------------------------ marqueurs ------------------------------ }

Procedure VMarker(X,Y: LongInt);
Var R,Ph: Integer; C: Integer;
Begin
 R:=Vd[VdCur].MkH Div 4;
 If R<1 Then R:=1;
 C:=Vd[VdCur].MkC;
 Ph:=0;
 Case Vd[VdCur].MkT Of
  1: Begin VPix(X,Y,True,C);VPix(X+1,Y,True,C);VPix(X,Y+1,True,C);VPix(X+1,Y+1,True,C);End;
  2: Begin VSeg(X-R,Y,X+R,Y,$FFFF,Ph,C);VSeg(X,Y-R,X,Y+R,$FFFF,Ph,C);End;
  4: Begin
      VSeg(X-R,Y-R,X+R,Y-R,$FFFF,Ph,C);VSeg(X+R,Y-R,X+R,Y+R,$FFFF,Ph,C);
      VSeg(X+R,Y+R,X-R,Y+R,$FFFF,Ph,C);VSeg(X-R,Y+R,X-R,Y-R,$FFFF,Ph,C);
     End;
  5: Begin VSeg(X-R,Y-R,X+R,Y+R,$FFFF,Ph,C);VSeg(X-R,Y+R,X+R,Y-R,$FFFF,Ph,C);End;
  6: Begin
      VSeg(X,Y-R,X+R,Y,$FFFF,Ph,C);VSeg(X+R,Y,X,Y+R,$FFFF,Ph,C);
      VSeg(X,Y+R,X-R,Y,$FFFF,Ph,C);VSeg(X-R,Y,X,Y-R,$FFFF,Ph,C);
     End;
 Else
  { 3 : asterisque (et types inconnus) }
  VSeg(X-R,Y,X+R,Y,$FFFF,Ph,C);VSeg(X,Y-R,X,Y+R,$FFFF,Ph,C);
  VSeg(X-R,Y-R,X+R,Y+R,$FFFF,Ph,C);VSeg(X-R,Y+R,X+R,Y-R,$FFFF,Ph,C);
 End;
End;

{ ------------------------------- texte --------------------------------- }

Function VBig: Boolean;
Begin VBig:=Vd[VdCur].TxH>=11; End;

Function GlyphBit(Ch: Byte; R,X: Integer; Big: Boolean; Eff: Integer): Boolean;
{ pixel (X,R) de la cellule du caractere avec les effets du texte }
 Function Raw(XX,RR: Integer): Boolean;
 Var G: Integer;
 Begin
  Raw:=False;
  If (XX<0) Or (XX>7) Then Exit;
  If RR<0 Then Exit;
  If Big Then G:=RR Div 2 Else G:=RR;      { 8x16 : lignes de la police 8x8 doublees }
  If (G<0) Or (G>7) Then Exit;
  Raw:=((Font8[Ch,G] Shr (7-XX)) And 1)<>0;
 End;
Var Sh,B: Integer; V: Boolean;
Begin
 If Big Then B:=V_BIG_ASC Else B:=V_SML_ASC;
 Sh:=0;
 If (Eff And 4)<>0 Then Sh:=(B-R) Div 4;
 V:=Raw(X-Sh,R);
 If (Eff And 1)<>0 Then V:=V Or Raw(X-Sh-1,R);
 If (Eff And 16)<>0 Then Begin
  { contour : bord du glyphe }
  If V Then Begin
   V:=Not (Raw(X-Sh-1,R) And Raw(X-Sh+1,R) And Raw(X-Sh,R-1) And Raw(X-Sh,R+1));
  End;
 End;
 If (Eff And 2)<>0 Then V:=V And (((X+R) And 1)=0);
 If ((Eff And 8)<>0) And (R=B+1) Then V:=True;
 GlyphBit:=V;
End;

{ trace la chaine S, coin haut-gauche de la cellule en (X,Y) }
Procedure VCell(X,Y: LongInt; Const S: String; Big: Boolean; Eff,Ink: Integer; Bg: Boolean);
Var I,R,CX,CH,Ex: Integer; V: Boolean;
Begin
 If Big Then CH:=16 Else CH:=8;
 For I:=1 To Length(S) Do Begin
  For R:=0 To CH-1 Do
   For CX:=0 To 8 Do Begin
    If (CX=8) And ((Eff And (1 Or 4))=0) Then Continue;
    V:=GlyphBit(Ord(S[I]),R,CX,Big,Eff);
    If (Eff And 32)<>0 Then
     If (Not V) And (CX>0) And (R>0) Then V:=GlyphBit(Ord(S[I]),R-1,CX-1,Big,Eff And (Not 32));
    If (CX=8) And (Not V) Then Continue;
    VPix(X+(I-1)*8+CX,Y+R,V,Ink);
   End;
 End;
 Ex:=0;
End;

Procedure VAlignOrigin(X,Y: LongInt; Len: Integer; Big: Boolean; Var CX,CY: LongInt);
Var CH,B: Integer;
Begin
 If Big Then Begin CH:=16;B:=V_BIG_ASC;End Else Begin CH:=8;B:=V_SML_ASC;End;
 CX:=X;
 Case Vd[VdCur].TxHA Of
  1: CX:=X-(Len*8) Div 2;
  2: CX:=X-Len*8;
 End;
 Case Vd[VdCur].TxVA Of
  0: CY:=Y-B;
  1: CY:=Y-(B Div 2);
  2: If Big Then CY:=Y-4 Else CY:=Y;
  3: CY:=Y-(CH-1);
  4: CY:=Y-B-3;
 Else CY:=Y;
 End;
End;

Procedure VGText(X,Y: LongInt; Const S: String);
Var CX,CY: LongInt;
Begin
 VAlignOrigin(X,Y,Length(S),VBig,CX,CY);
 VCell(CX,CY,S,VBig,Vd[VdCur].TxEff,Vd[VdCur].TxC,True);
End;

Function VStrIn(N: Integer; From: Integer): String;
Var S: String; I: Integer;
Begin
 S:='';
 For I:=From To N-1 Do If Length(S)<250 Then S:=S+Chr(VW(I) And $FF);
 VStrIn:=S;
End;

{ ------------------------------- rasters ------------------------------- }

Function VRop(M,S,D: Integer): Integer;
Begin
 Case M Of
  0: VRop:=0;
  1: VRop:=S And D;
  2: VRop:=S And (1-D);
  3: VRop:=S;
  4: VRop:=(1-S) And D;
  5: VRop:=D;
  6: VRop:=S Xor D;
  7: VRop:=S Or D;
  8: VRop:=1-(S Or D);
  9: VRop:=1-(S Xor D);
  10: VRop:=1-D;
  11: VRop:=S Or (1-D);
  12: VRop:=1-S;
  13: VRop:=(1-S) Or D;
  14: VRop:=1-(S And D);
 Else VRop:=1;
 End;
End;

{ lit un pixel d'un MFDB (0 : ecran logique) }
Function VGetPx(Mf: LongInt; X,Y: LongInt): Integer;
Var A,Wd,Wh: LongInt;
Begin
 VGetPx:=0;
 If Mf=0 Then Begin VGetPx:=OGet(X,Y);Exit;End;
 A:=RL(Mf);
 If A=0 Then Begin VGetPx:=OGet(X,Y);Exit;End;
 Wd:=SmallInt(RW(Mf+4));Wh:=SmallInt(RW(Mf+6));
 If (X<0) Or (Y<0) Or (X>=Wd) Or (Y>=Wh) Then Exit;
 If (RB(A+Y*SmallInt(RW(Mf+8))*2+(X Shr 3)) And (128 Shr (X And 7)))<>0 Then VGetPx:=1;
End;

Procedure VPutPx(Mf: LongInt; X,Y: LongInt; V: Integer);
Var A,Wd,Wh,Ix: LongInt; M: Byte;
Begin
 If (Mf=0) Or (RL(Mf)=0) Then Begin
  If (X<0) Or (Y<0) Or (X>=OUT_W) Or (Y>=OUT_H) Then Exit;
  If Vd[VdCur].ClipOn Then
   If (X<Vd[VdCur].CX1) Or (X>Vd[VdCur].CX2) Or (Y<Vd[VdCur].CY1) Or (Y>Vd[VdCur].CY2) Then Exit;
  OPlot(X,Y,V);Exit;
 End;
 A:=RL(Mf);
 Wd:=SmallInt(RW(Mf+4));Wh:=SmallInt(RW(Mf+6));
 If (X<0) Or (Y<0) Or (X>=Wd) Or (Y>=Wh) Then Exit;
 Ix:=A+Y*SmallInt(RW(Mf+8))*2+(X Shr 3);
 M:=128 Shr (X And 7);
 If V<>0 Then WB(Ix,RB(Ix) Or M) Else WB(Ix,RB(Ix) And (Not M));
End;

{ vro_cpyfm : copie raster avec operation logique }
Procedure VCpyFm(Mode: Integer; SMf,DMf: LongInt; SX1,SY1,SX2,SY2,DX1,DY1: LongInt);
Var W,H,X,Y,XS,YS,XD,YD,SXd,SYd: LongInt; S,D: Integer; Dir: Integer;
Begin
 If SX2<SX1 Then Begin W:=SX1;SX1:=SX2;SX2:=W;End;
 If SY2<SY1 Then Begin W:=SY1;SY1:=SY2;SY2:=W;End;
 W:=SX2-SX1+1;H:=SY2-SY1+1;
 { sens de copie : eviter l'ecrasement en cas de recouvrement }
 If (DY1>SY1) Or ((DY1=SY1) And (DX1>SX1)) Then Begin
  For Y:=H-1 DownTo 0 Do
   For X:=W-1 DownTo 0 Do Begin
    S:=VGetPx(SMf,SX1+X,SY1+Y);D:=VGetPx(DMf,DX1+X,DY1+Y);
    VPutPx(DMf,DX1+X,DY1+Y,VRop(Mode,S,D));
   End;
 End Else Begin
  For Y:=0 To H-1 Do
   For X:=0 To W-1 Do Begin
    S:=VGetPx(SMf,SX1+X,SY1+Y);D:=VGetPx(DMf,DX1+X,DY1+Y);
    VPutPx(DMf,DX1+X,DY1+Y,VRop(Mode,S,D));
   End;
 End;
 Dir:=0;XS:=0;YS:=0;XD:=0;YD:=0;SXd:=0;SYd:=0;
End;

{ vrt_cpyfm : monochrome vers couleur (masque expanse) }
Procedure VCpyFmT(Mode: Integer; SMf,DMf: LongInt; SX1,SY1,SX2,SY2,DX1,DY1: LongInt; Fg,Bg: Integer);
Var W,H,X,Y: LongInt; S: Integer;
Begin
 W:=SX2-SX1+1;H:=SY2-SY1+1;
 For Y:=0 To H-1 Do
  For X:=0 To W-1 Do Begin
   S:=VGetPx(SMf,SX1+X,SY1+Y);
   Case Mode Of
    2: If S<>0 Then VPutPx(DMf,DX1+X,DY1+Y,VInk(Fg));
    3: If S<>0 Then Begin
        If VInk(Fg)<>0 Then VPutPx(DMf,DX1+X,DY1+Y,1-VGetPx(DMf,DX1+X,DY1+Y));
       End;
    4: If S=0 Then VPutPx(DMf,DX1+X,DY1+Y,VInk(Fg));
   Else
    If S<>0 Then VPutPx(DMf,DX1+X,DY1+Y,VInk(Fg)) Else VPutPx(DMf,DX1+X,DY1+Y,VInk(Bg));
   End;
  End;
End;

{ ------------------------- sequences d'echappement --------------------- }

Procedure VEscSeq(Const Seq: String);
Var I: Integer;
Begin
 For I:=1 To Length(Seq) Do VtOut(Seq[I]);
End;

{ ------------------------- appel VDI principal ------------------------- }

Procedure VdiDeviceInfo;
Var I: Integer;
Begin
 For I:=0 To 44 Do VSetOut(I,0);
 VSetOut(0,639);VSetOut(1,399);VSetOut(2,0);VSetOut(3,372);VSetOut(4,372);
 VSetOut(5,3);VSetOut(6,7);VSetOut(7,0);VSetOut(8,6);VSetOut(9,8);VSetOut(10,1);
 VSetOut(11,24);VSetOut(12,12);VSetOut(13,2);VSetOut(14,10);
 For I:=0 To 9 Do VSetOut(15+I,I+1);
 VSetOut(25,3);VSetOut(26,3);VSetOut(27,3);VSetOut(28,3);
 VSetOut(35,0);VSetOut(36,1);VSetOut(37,1);VSetOut(38,0);VSetOut(39,2);
 For I:=0 To 11 Do VSetPts(I,0);
 VSetPts(0,4);VSetPts(1,4);VSetPts(2,8);VSetPts(3,13);VSetPts(4,1);VSetPts(6,40);
 VSetPts(8,8);VSetPts(9,8);VSetPts(10,40);VSetPts(11,40);
End;

Procedure VdiCall(PB: LongInt);
Var Op,Sub,N,NI,H,I,J,K: Integer; X1,Y1,X2,Y2,X3,Y3: LongInt; S: String; Mf1,Mf2: LongInt;
    Ph: Integer; Own: Boolean;
Begin
 VCtl:=RL(PB);VIn:=RL(PB+4);VPts:=RL(PB+8);VOut:=RL(PB+12);VPOut:=RL(PB+16);
 Op:=SmallInt(RW(VCtl));N:=SmallInt(RW(VCtl+2));NI:=SmallInt(RW(VCtl+6));
 Sub:=SmallInt(RW(VCtl+10));H:=SmallInt(RW(VCtl+12));
 If RtTrace Then Begin WriteLn(ErrOutput,'VDI ',Op,' sub=',Sub,' h=',H,' nin=',N,' nint=',NI);Flush(ErrOutput);End;
 { poste de travail }
 If (H<1) Or (H>VD_MAX) Then H:=1;
 If Op=100 Then Begin
  H:=0;
  For I:=2 To VD_MAX Do If (H=0) And (Not Vd[I].Used) Then H:=I;
  If H=0 Then H:=2;
 End;
 If Op=1 Then H:=1;
 If Not Vd[H].Used Then VdDefaults(H);
 VdCur:=H;
 WW(VCtl+8,0);WW(VCtl+4,0);
 ClipOn:=Vd[H].ClipOn;ClipX1:=Vd[H].CX1;ClipY1:=Vd[H].CY1;ClipX2:=Vd[H].CX2;ClipY2:=Vd[H].CY2;
 OXor:=False;
 Case Op Of
  1,100: Begin
          VdDefaults(H);
          If NI>=10 Then With Vd[H] Do Begin
           LnT:=VW(1);LnC:=VW(2);MkT:=VW(3);MkC:=VW(4);TxF:=VW(5);TxC:=VW(6);
           FlI:=VW(7);FlS:=VW(8);FlC:=VW(9);
           If (LnT<1) Or (LnT>7) Then LnT:=1;
          End;
          VdiDeviceInfo;
          WW(VCtl+12,H);
          WW(VCtl+4,6);WW(VCtl+8,45);
         End;
  2,101: Begin Vd[H].Used:=False;End;
  3: Begin FillChar(OutBuf^,OUT_BYTES,0);OutPending:=True;End;
  4: ;
  5: Begin
      Case Sub Of
       1: Begin VSetOut(0,25);VSetOut(1,80);WW(VCtl+8,2);End;
       2,3: Begin VtOut(#27);VtOut('E');End;
       4: VEscSeq(#27'A');
       5: VEscSeq(#27'B');
       6: VEscSeq(#27'C');
       7: VEscSeq(#27'D');
       8: VEscSeq(#27'H');
       9: VEscSeq(#27'J');
       10: VEscSeq(#27'K');
       11: Begin VtOut(#27);VtOut('Y');VtOut(Chr(31+VW(0)));VtOut(Chr(31+VW(1)));End;
       12: Begin S:=VStrIn(NI,0);VEscSeq(S);End;
       13: VEscSeq(#27'p');
       14: VEscSeq(#27'q');
       15: Begin VSetOut(0,OCY+1);VSetOut(1,OCX+1);WW(VCtl+8,2);End;
       16: Begin VSetOut(0,1);WW(VCtl+8,1);End;
      End;
      OutPending:=True;
     End;
  6: VPolyline(N);
  7: Begin
      For I:=0 To N-1 Do VMarker(VP(I*2),VP(I*2+1));
     End;
  8: Begin
      S:=VStrIn(NI,0);
      VGText(VP(0),VP(1),S);
     End;
  9: Begin
      For I:=0 To N-1 Do Begin PX[I]:=VP(I*2);PY[I]:=VP(I*2+1);End;
      VShape(N,True);
     End;
  11: Begin
       X1:=VP(0);Y1:=VP(1);X2:=VP(2);Y2:=VP(3);
       Case Sub Of
        1: Begin
            VFillRect(X1,Y1,X2,Y2);
            If Vd[H].FlP<>0 Then Begin
             PX[0]:=X1;PY[0]:=Y1;PX[1]:=X2;PY[1]:=Y1;PX[2]:=X2;PY[2]:=Y2;PX[3]:=X1;PY[3]:=Y2;
             VOutline(4,Vd[H].FlC,True);
            End;
           End;
        2: VArcPoly(X1,Y1,VP(6),VP(6),VW(0),VW(1),False,False);
        3: VArcPoly(X1,Y1,VP(6),VP(6),VW(0),VW(1),True,True);
        4: VArcPoly(X1,Y1,VP(4),VP(4),0,3600,True,True);
        5: VArcPoly(X1,Y1,VP(2),VP(3),0,3600,True,True);
        6: VArcPoly(X1,Y1,VP(2),VP(3),VW(0),VW(1),False,False);
        7: VArcPoly(X1,Y1,VP(2),VP(3),VW(0),VW(1),True,True);
        8: VRoundRect(X1,Y1,X2,Y2,False);
        9: VRoundRect(X1,Y1,X2,Y2,True);
        10: Begin
             { texte justifie : longueur imposee }
             S:=VStrIn(NI,2);
             VAlignOrigin(X1,Y1,Length(S),VBig,X3,Y3);
             If (Length(S)>1) And (VP(2)>Length(S)*8) Then Begin
              K:=VP(2)-Length(S)*8;
              J:=0;
              For I:=1 To Length(S) Do If S[I]=' ' Then Inc(J);
              If (VW(0)<>0) And (J>0) Then Begin
               For I:=1 To Length(S) Do Begin
                VCell(X3,Y3,Copy(S,I,1),VBig,Vd[H].TxEff,Vd[H].TxC,True);
                X3:=X3+8;
                If S[I]=' ' Then Begin X3:=X3+K Div J;End;
               End;
              End Else If VW(1)<>0 Then Begin
               For I:=1 To Length(S) Do Begin
                VCell(X3,Y3,Copy(S,I,1),VBig,Vd[H].TxEff,Vd[H].TxC,True);
                X3:=X3+8+K Div (Length(S)-1);
               End;
              End Else VCell(X3,Y3,S,VBig,Vd[H].TxEff,Vd[H].TxC,True);
             End Else VCell(X3,Y3,S,VBig,Vd[H].TxEff,Vd[H].TxC,True);
            End;
       End;
      End;
  12: Begin
       { vst_height : hauteur du caractere en pixels }
       Vd[H].TxH:=VP(1);
       If VBig Then Begin VSetPts(0,8);VSetPts(1,13);VSetPts(2,8);VSetPts(3,16);End
       Else Begin VSetPts(0,8);VSetPts(1,7);VSetPts(2,8);VSetPts(3,8);End;
       WW(VCtl+4,2);
      End;
  13: Begin Vd[H].TxRot:=VW(0);VSetOut(0,VW(0));WW(VCtl+8,1);End;
  14: ;
  15: Begin
       Vd[H].LnT:=VW(0);If (Vd[H].LnT<1) Or (Vd[H].LnT>7) Then Vd[H].LnT:=1;
       VSetOut(0,Vd[H].LnT);WW(VCtl+8,1);
      End;
  16: Begin Vd[H].LnW:=VP(0);If Vd[H].LnW<1 Then Vd[H].LnW:=1;VSetPts(0,Vd[H].LnW);VSetPts(1,0);WW(VCtl+4,1);End;
  17: Begin Vd[H].LnC:=VW(0);VSetOut(0,VW(0));WW(VCtl+8,1);End;
  18: Begin Vd[H].MkT:=VW(0);VSetOut(0,VW(0));WW(VCtl+8,1);End;
  19: Begin Vd[H].MkH:=VP(1);If Vd[H].MkH<1 Then Vd[H].MkH:=1;VSetPts(0,Vd[H].MkH);VSetPts(1,Vd[H].MkH);WW(VCtl+4,1);End;
  20: Begin Vd[H].MkC:=VW(0);VSetOut(0,VW(0));WW(VCtl+8,1);End;
  21: Begin Vd[H].TxF:=VW(0);VSetOut(0,1);WW(VCtl+8,1);End;
  22: Begin Vd[H].TxC:=VW(0);VSetOut(0,VW(0));WW(VCtl+8,1);End;
  23: Begin Vd[H].FlI:=VW(0);VSetOut(0,VW(0));WW(VCtl+8,1);End;
  24: Begin Vd[H].FlS:=VW(0);VSetOut(0,VW(0));WW(VCtl+8,1);End;
  25: Begin Vd[H].FlC:=VW(0);VSetOut(0,VW(0));WW(VCtl+8,1);End;
  26: Begin
       I:=VW(0);
       VSetOut(0,I);
       If I=0 Then Begin VSetOut(1,1000);VSetOut(2,1000);VSetOut(3,1000);End
       Else Begin VSetOut(1,0);VSetOut(2,0);VSetOut(3,0);End;
       WW(VCtl+8,4);
      End;
  32: Begin
       I:=VW(0);If (I<1) Or (I>4) Then I:=1;
       Vd[H].Wr:=I;VSetOut(0,I);WW(VCtl+8,1);
      End;
  33: Begin VSetOut(0,VW(1));WW(VCtl+8,1);End;
  35: Begin
       VSetOut(0,Vd[H].LnT);VSetOut(1,Vd[H].LnC);VSetOut(2,Vd[H].Wr);VSetOut(3,Vd[H].LnB);VSetOut(4,Vd[H].LnE);
       VSetPts(0,Vd[H].LnW);VSetPts(1,0);WW(VCtl+8,5);WW(VCtl+4,1);
      End;
  36: Begin
       VSetOut(0,Vd[H].MkT);VSetOut(1,Vd[H].MkC);VSetOut(2,Vd[H].Wr);
       VSetPts(0,Vd[H].MkH);VSetPts(1,Vd[H].MkH);WW(VCtl+8,3);WW(VCtl+4,1);
      End;
  37: Begin
       VSetOut(0,Vd[H].FlI);VSetOut(1,Vd[H].FlC);VSetOut(2,Vd[H].FlS);VSetOut(3,Vd[H].Wr);VSetOut(4,Vd[H].FlP);
       WW(VCtl+8,5);
      End;
  38: Begin
       VSetOut(0,Vd[H].TxF);VSetOut(1,Vd[H].TxC);VSetOut(2,Vd[H].TxRot);VSetOut(3,Vd[H].TxHA);
       VSetOut(4,Vd[H].TxVA);VSetOut(5,Vd[H].Wr);
       If VBig Then Begin VSetPts(0,8);VSetPts(1,13);VSetPts(2,8);VSetPts(3,16);End
       Else Begin VSetPts(0,8);VSetPts(1,7);VSetPts(2,8);VSetPts(3,8);End;
       WW(VCtl+8,6);WW(VCtl+4,2);
      End;
  39: Begin
       Vd[H].TxHA:=VW(0);Vd[H].TxVA:=VW(1);
       VSetOut(0,VW(0));VSetOut(1,VW(1));WW(VCtl+8,2);
      End;
  102: Begin
        VdiDeviceInfo;
        If VW(0)<>0 Then Begin
         VSetOut(0,0);VSetOut(1,2);VSetOut(2,1);VSetOut(3,0);VSetOut(4,1);VSetOut(5,0);
         VSetOut(6,0);VSetOut(7,1);
        End;
        WW(VCtl+8,45);WW(VCtl+4,6);
       End;
  103: Begin
        { remplissage de contour : germe (x,y) }
        FilSty:=Vd[H].FlI;FilIdx:=Vd[H].FlS;FilCol:=Vd[H].FlC;
        If Vd[H].FlI=2 Then FilSty:=2;
        If Vd[H].FlI=1 Then Begin FilSty:=1;FilCol:=Vd[H].FlC;End;
        If Vd[H].FlI=0 Then Begin FilSty:=0;End;
        OFlood(VP(0),VP(1));
       End;
  104: Begin Vd[H].FlP:=VW(0);VSetOut(0,VW(0));WW(VCtl+8,1);End;
  105: Begin
        VSetOut(0,OGet(VP(0),VP(1)));VSetOut(1,OGet(VP(0),VP(1)));WW(VCtl+8,2);
       End;
  106: Begin Vd[H].TxEff:=VW(0);VSetOut(0,VW(0));WW(VCtl+8,1);End;
  107: Begin
        I:=VW(0);
        If I>=10 Then Vd[H].TxH:=13 Else Vd[H].TxH:=7;
        VSetOut(0,I);
        If VBig Then Begin VSetPts(0,8);VSetPts(1,13);VSetPts(2,8);VSetPts(3,16);End
        Else Begin VSetPts(0,8);VSetPts(1,7);VSetPts(2,8);VSetPts(3,8);End;
        WW(VCtl+4,2);WW(VCtl+8,1);
       End;
  108: Begin Vd[H].LnB:=VW(0);Vd[H].LnE:=VW(1);End;
  109: Begin
        Mf1:=RL(VCtl+14);Mf2:=RL(VCtl+18);
        If RtTrace Then Begin
         WriteLn(ErrOutput,'  vro_cpyfm mode=',VW(0),' src=',Mf1,' dst=',Mf2,' rect ',VP(0),',',VP(1),',',VP(2),',',VP(3),' -> ',VP(4),',',VP(5),',',VP(6),',',VP(7));
         If Mf1<>0 Then WriteLn(ErrOutput,'   srcMFDB addr=',RL(Mf1),' w=',SmallInt(RW(Mf1+4)),' h=',SmallInt(RW(Mf1+6)),' wdw=',SmallInt(RW(Mf1+8)),' planes=',SmallInt(RW(Mf1+12)));
         If Mf2<>0 Then WriteLn(ErrOutput,'   dstMFDB addr=',RL(Mf2),' w=',SmallInt(RW(Mf2+4)),' h=',SmallInt(RW(Mf2+6)),' wdw=',SmallInt(RW(Mf2+8)),' planes=',SmallInt(RW(Mf2+12)));
         Flush(ErrOutput);
        End;
        VCpyFm(VW(0),Mf1,Mf2,VP(0),VP(1),VP(2),VP(3),VP(4),VP(5));
       End;
  110: Begin
        { vr_trnfm : un seul plan, format identique }
        Mf1:=RL(VCtl+14);Mf2:=RL(VCtl+18);
        If (Mf1<>0) And (Mf2<>0) Then Begin
         I:=SmallInt(RW(Mf1+8))*2*SmallInt(RW(Mf1+6));
         If (I>0) And (RL(Mf1)<>0) And (RL(Mf2)<>0) Then Move(VMem[RL(Mf1)],VMem[RL(Mf2)],I);
         WW(Mf2+4,RW(Mf1+4));WW(Mf2+6,RW(Mf1+6));WW(Mf2+8,RW(Mf1+8));WW(Mf2+10,1);WW(Mf2+12,1);
        End;
       End;
  111: Begin
        CurHx:=VW(0);CurHy:=VW(1);CurKind:=1;
        For I:=0 To 15 Do Begin CurMask[I]:=RW(VIn+10+I*2);CurData[I]:=RW(VIn+42+I*2);End;
        If ProgMouse And (Not Headless) Then Begin HideMouse;ShowMouse;End;
       End;
  112: Begin For I:=0 To 15 Do Vd[H].UdPat[I]:=RW(VIn+I*2);End;
  113: Vd[H].UdLn:=RW(VIn);
  114: VFillRect(VP(0),VP(1),VP(2),VP(3));
  115: Begin VSetOut(0,1);WW(VCtl+8,1);End;
  116: Begin
        S:=VStrIn(NI,0);
        K:=Length(S)*8;
        If VBig Then I:=16 Else I:=8;
        VSetPts(0,0);VSetPts(1,I);VSetPts(2,K);VSetPts(3,I);VSetPts(4,K);VSetPts(5,0);VSetPts(6,0);VSetPts(7,0);
        WW(VCtl+4,4);
       End;
  117: Begin
        VSetPts(0,8);VSetPts(1,0);VSetPts(2,0);VSetPts(3,0);VSetPts(4,0);VSetPts(5,0);
        VSetOut(0,VW(0));WW(VCtl+4,3);WW(VCtl+8,3);VSetOut(1,0);VSetOut(2,0);
       End;
  118,125,126,127: Begin
        { vecteurs d'interruption : non emules, l'ancien vecteur est nul }
        WL(VCtl+14,0);WL(VCtl+18,0);
        If Op=118 Then VSetOut(0,50);
       End;
  119: Begin VSetOut(0,0);WW(VCtl+8,1);End;
  120: ;
  121: Begin
        Mf1:=RL(VCtl+14);Mf2:=RL(VCtl+18);
        VCpyFmT(VW(0),Mf1,Mf2,VP(0),VP(1),VP(2),VP(3),VP(4),VP(5),VW(1),VW(2));
       End;
  122: Begin GemCur(True);End;
  123: Begin GemCur(False);End;
  124: Begin
        GetMouseState(MX,MY,MB);
        VSetOut(0,MB And 3);VSetPts(0,MX);VSetPts(1,MY-OFS_Y);WW(VCtl+4,1);WW(VCtl+8,1);
       End;
  128: Begin VSetOut(0,0);WW(VCtl+8,1);End;
  129: Begin
        Vd[H].ClipOn:=(VW(0)<>0);
        If Vd[H].ClipOn Then Begin
         Vd[H].CX1:=VP(0);Vd[H].CY1:=VP(1);Vd[H].CX2:=VP(2);Vd[H].CY2:=VP(3);
        End Else Begin Vd[H].CX1:=0;Vd[H].CY1:=0;Vd[H].CX2:=639;Vd[H].CY2:=399;End;
       End;
  130: Begin
        VSetOut(0,1);
        S:='System font';
        For I:=1 To 32 Do If I<=Length(S) Then VSetOut(I,Ord(S[I])) Else VSetOut(I,0);
        WW(VCtl+8,33);
       End;
  131: Begin
        VSetOut(0,32);VSetOut(1,255);
        VSetPts(0,8);VSetPts(1,3);VSetPts(2,8);VSetPts(3,0);VSetPts(4,8);VSetPts(5,12);VSetPts(6,8);VSetPts(7,0);
        VSetPts(8,0);VSetPts(9,13);
        WW(VCtl+4,5);WW(VCtl+8,2);
       End;
 Else
  If RtTrace Then Begin WriteLn(ErrOutput,'VDI non implemente : ',Op);Flush(ErrOutput);End;
 End;
 ClipOn:=False;OXor:=False;
 ScrDirty:=True;
 OutPending:=True;
 Own:=False;Ph:=0;Y2:=0;
End;
{$ENDIF}
{$IFDEF FPC}
{ ====================================================================== }
{     AES EMULE : RESSOURCES ET ARBRES D'OBJETS EN MEMOIRE (OBJC_*)      }
{ ====================================================================== }
{ Les arbres d'objets vivent dans la memoire de l'ST emule : OBJECT de 24 octets
  (suivant, premier, dernier, type, drapeaux, etat, spec, x, y, l, h), TEDINFO,
  ICONBLK et BITBLK. Les ressources sont chargees dans un pool AES place au
  dessus de la zone des programmes. }

Const
 AES_POOL     = $E8000;
 AES_POOL_END = $F7F00;
 AES_SCR      = $F7F00;       { 128 octets de travail pour les evenements }
 MAXRSC       = 4;

Type
 TRscInfo = Record
  Used : Boolean;
  Base,Size : LongInt;
  ObjO,TedO,IcoO,BitO,FrStr,StrO,ImgO,FrImg,TrIdx : LongInt;
  NObs,NTree,NTed,NIco,NBit,NStr,NImg,NFrS : LongInt;
 End;

Var
 AesPoolTop : LongInt;
 Rsc        : Array[1..MAXRSC] Of TRscInfo;
 RscCur     : Integer;
 EdIdx      : Integer;                  { position du curseur d'edition }

Function AesAlloc(Sz: LongInt): LongInt;
Begin
 Sz:=(Sz+3) And (Not 3);
 If AesPoolTop+Sz>AES_POOL_END Then AesAlloc:=0
 Else Begin
  AesAlloc:=AesPoolTop;
  FillChar(VMem[AesPoolTop],Sz,0);
  AesPoolTop:=AesPoolTop+Sz;
 End;
End;

{ appel d'un sous-programme 68000 du programme depuis l'AES (G_PROGDEF) : l'argument
  est empile, la routine est executee jusqu'a son RTS, les registres sont restaures }
Const
 RET_ADDR = $412;      { adresse de retour fictive (jamais executee) }

Function CallEmu(Addr,Arg: LongInt): LongInt;
Var SvRD,SvRA: Array[0..7] Of LongInt; SvPC: LongInt; SvSR: Word; SvOpc: Word; SvOpPC,SvSteps: LongInt;
    SvHalt: Boolean; N: LongInt;
Begin
 SvRD:=RD;SvRA:=RA;SvPC:=RPC;SvSR:=RSR;SvOpc:=EmuOpc;SvOpPC:=EmuOpPC;SvSteps:=EmuSteps;SvHalt:=EmuHalt;
 Push32(Arg);Push32(RET_ADDR);
 RPC:=Addr;
 N:=0;
 While (RPC<>RET_ADDR) And (Not EmuHalt) And (Not EmuBrk) And (N<20000000) Do Begin
  Step;Inc(N);
 End;
 CallEmu:=SmallInt(RD[0] And $FFFF);
 RD:=SvRD;RA:=SvRA;RPC:=SvPC;RSR:=SvSR;EmuOpc:=SvOpc;EmuOpPC:=SvOpPC;EmuSteps:=SvSteps;
 If EmuHalt And Not SvHalt Then ;
End;

{ ------------------------------ acces objets --------------------------- }

Function OAd(T,I: LongInt): LongInt;
Begin OAd:=T+I*24; End;

Function ONext(T,I: LongInt): Integer;
Begin ONext:=SmallInt(RW(OAd(T,I))); End;

Function OHead(T,I: LongInt): Integer;
Begin OHead:=SmallInt(RW(OAd(T,I)+2)); End;

Function OTail(T,I: LongInt): Integer;
Begin OTail:=SmallInt(RW(OAd(T,I)+4)); End;

Function OTyp(T,I: LongInt): Integer;
Begin OTyp:=RW(OAd(T,I)+6) And $FF; End;

Function OFlg(T,I: LongInt): Integer;
Begin OFlg:=RW(OAd(T,I)+8); End;

Function OSta(T,I: LongInt): Integer;
Begin OSta:=RW(OAd(T,I)+10); End;

Function OSpc(T,I: LongInt): LongInt;
Begin
 OSpc:=RL(OAd(T,I)+12);
 If (OFlg(T,I) And 256)<>0 Then OSpc:=RL(RL(OAd(T,I)+12));
End;

Function OX(T,I: LongInt): Integer;
Begin OX:=SmallInt(RW(OAd(T,I)+16)); End;
Function OY(T,I: LongInt): Integer;
Begin OY:=SmallInt(RW(OAd(T,I)+18)); End;
Function OW(T,I: LongInt): Integer;
Begin OW:=SmallInt(RW(OAd(T,I)+20)); End;
Function OH(T,I: LongInt): Integer;
Begin OH:=SmallInt(RW(OAd(T,I)+22)); End;

Procedure OSetSta(T,I: LongInt; V: Integer);
Begin WW(OAd(T,I)+10,Word(V)); End;

Function CStrAt(A: LongInt): String;
{ chaine C terminee par un zero }
Var S: String;
Begin
 S:='';
 If A<=0 Then Begin CStrAt:='';Exit;End;
 While (RB(A)<>0) And (Length(S)<250) Do Begin S:=S+Chr(RB(A));Inc(A);End;
 CStrAt:=S;
End;

{ position absolue (a l'ecran) d'un objet : parcours depuis la racine }
Function ObjOffset(T,Target: LongInt; Var AX,AY: Integer): Boolean;
 Function Rec(N: Integer; PX0,PY0: Integer; Depth: Integer): Boolean;
 Var C,Cx,Cy: Integer; Guard: Integer;
 Begin
  Rec:=False;
  If Depth>40 Then Exit;
  Cx:=PX0+OX(T,N);Cy:=PY0+OY(T,N);
  If N=Target Then Begin AX:=Cx;AY:=Cy;Rec:=True;Exit;End;
  C:=OHead(T,N);Guard:=0;
  While (C>=0) And (C<>N) And (Guard<2000) Do Begin
   If Rec(C,Cx,Cy,Depth+1) Then Begin Rec:=True;Exit;End;
   C:=ONext(T,C);Inc(Guard);
  End;
 End;
Begin
 AX:=0;AY:=0;
 ObjOffset:=Rec(0,0,0,0);
End;

Function ObjParent(T,Target: LongInt): Integer;
Var N,C,Guard: Integer; Found: Integer;
 Procedure Walk(Nd: Integer; Depth: Integer);
 Var Cc,G2: Integer;
 Begin
  If (Found>=0) Or (Depth>40) Then Exit;
  Cc:=OHead(T,Nd);G2:=0;
  While (Cc>=0) And (Cc<>Nd) And (G2<2000) Do Begin
   If Cc=Target Then Begin Found:=Nd;Exit;End;
   Walk(Cc,Depth+1);
   Cc:=ONext(T,Cc);Inc(G2);
  End;
 End;
Begin
 Found:=-1;N:=0;C:=0;Guard:=0;
 Walk(0,0);
 ObjParent:=Found;
End;

{ ------------------------- chargement des ressources ------------------- }

Procedure ObFix(O: LongInt);
Var I,V,Lo: Integer;
Begin
 For I:=0 To 3 Do Begin
  V:=SmallInt(RW(O+16+I*2));
  Lo:=V And $FF;
  If (I And 1)=0 Then Lo:=Lo*8 Else Lo:=Lo*16;
  Lo:=Lo+(V Shr 8);
  WW(O+16+I*2,Word(Lo));
 End;
End;

Function RscFixMem(A,Sz: LongInt): Integer;
{ relocalise en place une ressource deja presente en memoire (rsrc_load, rsrc_rcfix) ;
  retourne l'indice du bloc ou 0 }
Var B,O: LongInt; I,K,T: Integer;
 Function HW(Ix: Integer): LongInt;
 Begin HW:=RW(B+Ix*2); End;
Begin
 RscFixMem:=0;
 K:=0;
 For I:=1 To MAXRSC Do If (K=0) And (Not Rsc[I].Used) Then K:=I;
 If K=0 Then Exit;
 B:=A;
 FillChar(Rsc[K],SizeOf(TRscInfo),0);
 With Rsc[K] Do Begin
  Used:=True;Base:=A;Size:=Sz;
  ObjO:=A+HW(1);TedO:=A+HW(2);IcoO:=A+HW(3);BitO:=A+HW(4);FrStr:=A+HW(5);StrO:=A+HW(6);
  ImgO:=A+HW(7);FrImg:=A+HW(8);TrIdx:=A+HW(9);
  NObs:=HW(10);NTree:=HW(11);NTed:=HW(12);NIco:=HW(13);NBit:=HW(14);NStr:=HW(15);NImg:=HW(16);
  If FrImg>FrStr Then NFrS:=(FrImg-FrStr) Div 4 Else NFrS:=0;
  If NFrS>NStr Then NFrS:=NStr;
  { arbres }
  For I:=0 To NTree-1 Do WL(TrIdx+I*4,RL(TrIdx+I*4)+A);
  For I:=0 To NFrS-1 Do WL(FrStr+I*4,RL(FrStr+I*4)+A);
  { TEDINFO }
  For I:=0 To NTed-1 Do Begin
   O:=TedO+I*28;
   WL(O,RL(O)+A);WL(O+4,RL(O+4)+A);WL(O+8,RL(O+8)+A);
  End;
  { ICONBLK }
  For I:=0 To NIco-1 Do Begin
   O:=IcoO+I*34;
   WL(O,RL(O)+A);WL(O+4,RL(O+4)+A);WL(O+8,RL(O+8)+A);
  End;
  { BITBLK }
  For I:=0 To NBit-1 Do Begin
   O:=BitO+I*14;
   WL(O+0,RL(O)+A);
  End;
  { objets }
  For I:=0 To NObs-1 Do Begin
   O:=ObjO+I*24;
   T:=RW(O+6) And $FF;
   Case T Of
    21,22,29,30,23,26,28,31,32: WL(O+12,RL(O+12)+A);
   End;
   ObFix(O);
  End;
 End;
 RscFixMem:=K;
End;

Function RscRead(Const Nm: String): Integer;
{ charge un fichier .RSC dans le pool ; retourne l'indice du bloc ou 0 }
Var F: File; Sz,N: LongInt; A: LongInt; Fn: String;
Begin
 RscRead:=0;
 Fn:=ResolveFile(TosToHost(Nm));
 If Not FileExists(Fn) Then Exit;
 Assign(F,Fn);
 {$I-}Reset(F,1);{$I+}
 If IOResult<>0 Then Exit;
 Sz:=FileSize(F);
 A:=AesAlloc(Sz+4);
 If A=0 Then Begin Close(F);Exit;End;
 N:=0;
 BlockRead(F,VMem[A],Sz,N);
 Close(F);
 If N<36 Then Exit;
 RscRead:=RscFixMem(A,Sz);
End;

Function RscTree(Ix: LongInt): LongInt;
Begin
 RscTree:=0;
 If (RscCur>=1) And Rsc[RscCur].Used And (Ix>=0) And (Ix<Rsc[RscCur].NTree) Then
  RscTree:=RL(Rsc[RscCur].TrIdx+Ix*4);
End;

{ adresse d'un element de ressource (rsrc_gaddr) ; 0 si inexistant }
Function RscGAddr(Typ,Ix: LongInt): LongInt;
Var R: TRscInfo; O: LongInt;
Begin
 RscGAddr:=0;
 If (RscCur<1) Or (Not Rsc[RscCur].Used) Then Exit;
 R:=Rsc[RscCur];
 Case Typ Of
  0: RscGAddr:=RscTree(Ix);
  1: If (Ix>=0) And (Ix<R.NObs) Then RscGAddr:=R.ObjO+Ix*24;
  2: If (Ix>=0) And (Ix<R.NTed) Then RscGAddr:=R.TedO+Ix*28;
  3: If (Ix>=0) And (Ix<R.NIco) Then RscGAddr:=R.IcoO+Ix*34;
  4: If (Ix>=0) And (Ix<R.NBit) Then RscGAddr:=R.BitO+Ix*14;
  5,15: If (Ix>=0) And (Ix<R.NFrS) Then RscGAddr:=RL(R.FrStr+Ix*4);
  6: RscGAddr:=R.ImgO;
  7: If (Ix>=0) And (Ix<R.NObs) Then RscGAddr:=R.ObjO+Ix*24+12;
  8: If (Ix>=0) And (Ix<R.NTed) Then RscGAddr:=R.TedO+Ix*28;
  9: If (Ix>=0) And (Ix<R.NTed) Then RscGAddr:=R.TedO+Ix*28+4;
  10: If (Ix>=0) And (Ix<R.NTed) Then RscGAddr:=R.TedO+Ix*28+8;
  11: If (Ix>=0) And (Ix<R.NIco) Then RscGAddr:=R.IcoO+Ix*34;
  12: If (Ix>=0) And (Ix<R.NIco) Then RscGAddr:=R.IcoO+Ix*34+4;
  13: If (Ix>=0) And (Ix<R.NIco) Then RscGAddr:=R.IcoO+Ix*34+8;
  14: If (Ix>=0) And (Ix<R.NBit) Then RscGAddr:=R.BitO+Ix*14;
  16: RscGAddr:=R.FrImg;
 End;
 O:=0;
End;

{ ------------------------------ dessin AES ----------------------------- }

Procedure ADensInit;
Begin End;

Function ADens(P: Integer): Integer;
Begin
 Case P Of
  1: ADens:=8;
  2: ADens:=16;
  3: ADens:=24;
  4: ADens:=32;
  5: ADens:=44;
  6: ADens:=52;
 Else ADens:=0;
 End;
End;

Procedure AFill(X1,Y1,X2,Y2: Integer; Pat,Col: Integer);
Var X,Y: Integer; V: Byte;
Begin
 If X1<0 Then X1:=0;
 If Y1<0 Then Y1:=0;
 If X2>OUT_W-1 Then X2:=OUT_W-1;
 If Y2>OUT_H-1 Then Y2:=OUT_H-1;
 For Y:=Y1 To Y2 Do
  For X:=X1 To X2 Do Begin
   If Col=0 Then V:=0
   Else If Pat>=7 Then V:=1
   Else If Pat<=0 Then V:=0
   Else If BayerM[Y And 7,X And 7]<ADens(Pat) Then V:=1 Else V:=0;
   OPlot(X,Y,V);
  End;
End;

Procedure AFrame(X,Y,W,H,T: Integer; Ink: Byte);
Var K,A,B: Integer; X1,Y1,X2,Y2: Integer;
Begin
 If W<1 Then Exit;
 If H<1 Then Exit;
 If T>0 Then Begin
  For K:=0 To T-1 Do Begin
   X1:=X+K;Y1:=Y+K;X2:=X+W-1-K;Y2:=Y+H-1-K;
   If (X2<X1) Or (Y2<Y1) Then Break;
   For A:=X1 To X2 Do Begin OPlot(A,Y1,Ink);OPlot(A,Y2,Ink);End;
   For B:=Y1 To Y2 Do Begin OPlot(X1,B,Ink);OPlot(X2,B,Ink);End;
  End;
 End Else If T<0 Then Begin
  For K:=1 To -T Do Begin
   X1:=X-K;Y1:=Y-K;X2:=X+W-1+K;Y2:=Y+H-1+K;
   For A:=X1 To X2 Do Begin OPlot(A,Y1,Ink);OPlot(A,Y2,Ink);End;
   For B:=Y1 To Y2 Do Begin OPlot(X1,B,Ink);OPlot(X2,B,Ink);End;
  End;
 End;
End;

Procedure AInvert(X1,Y1,X2,Y2: Integer);
Var X,Y: Integer;
Begin
 OXor:=True;
 For Y:=Y1 To Y2 Do
  For X:=X1 To X2 Do OPlot(X,Y,1);
 OXor:=False;
End;

{ texte AES : le coin haut-gauche de la cellule est en (X,Y) }
Procedure AText(X,Y: Integer; Const S: String; Big: Boolean; Ink: Integer; Transp: Boolean);
Var Sv,SvW: Integer;
Begin
 Sv:=VdCur;VdCur:=0;
 SvW:=Vd[0].Wr;
 If Transp Then Vd[0].Wr:=2 Else Vd[0].Wr:=1;
 VCell(X,Y,S,Big,0,Ink,True);
 Vd[0].Wr:=SvW;
 VdCur:=Sv;
End;

Procedure ACrossOut(X,Y,W,H: Integer);
Var Ph: Integer; Sv: Integer;
Begin
 Sv:=VdCur;VdCur:=0;Ph:=0;
 VSeg(X,Y,X+W-1,Y+H-1,$FFFF,Ph,1);Ph:=0;
 VSeg(X,Y+H-1,X+W-1,Y,$FFFF,Ph,1);
 VdCur:=Sv;
End;

{ chaine affichee d'un champ de texte (modele '_' pour les champs editables) }
Function FieldText(TedA: LongInt; Editable: Boolean): String;
Var Txt,Tm,R: String; I,K: Integer;
Begin
 Txt:=CStrAt(RL(TedA));
 If Not Editable Then Begin FieldText:=Txt;Exit;End;
 Tm:=CStrAt(RL(TedA+4));
 R:='';K:=1;
 For I:=1 To Length(Tm) Do Begin
  If Tm[I]='_' Then Begin
   If K<=Length(Txt) Then R:=R+Txt[K] Else R:=R+'_';
   Inc(K);
  End Else R:=R+Tm[I];
 End;
 FieldText:=R;
End;

{ dessine un objet isole en (X,Y) (coin haut-gauche absolu) }
Procedure DrawOne(T,N: LongInt; X,Y: Integer);
Var Typ,Fl,St,W,H,Thick,FCol,TCol,Pat,ICol,Just,Font: Integer; Spec,Ted,Ic: LongInt; Col: LongInt;
    S: String; Ch: Char; Big,Opaq: Boolean; Sh,I,J,TX,TY,Wi,Hi,Wb: Integer; Ink: Integer;
    MaskA,DataA: LongInt; Bm,Bd: Integer; XI,YI,WT,HT: Integer;
Begin
 Typ:=OTyp(T,N);Fl:=OFlg(T,N);St:=OSta(T,N);W:=OW(T,N);H:=OH(T,N);
 Spec:=OSpc(T,N);
 Thick:=0;FCol:=1;TCol:=1;Pat:=0;ICol:=0;Opaq:=True;Just:=0;Font:=3;Ted:=0;
 Case Typ Of
  20,25,27: Begin
    Thick:=ShortInt((Spec Shr 16) And $FF);
    FCol:=(Spec Shr 12) And 15;TCol:=(Spec Shr 8) And 15;
    Opaq:=((Spec Shr 7) And 1)<>0;Pat:=(Spec Shr 4) And 7;ICol:=Spec And 15;
   End;
  21,22,29,30: Begin
    Ted:=Spec;
    Col:=RW(Ted+18);Thick:=SmallInt(RW(Ted+22));Just:=RW(Ted+16);Font:=RW(Ted+12);
    If Thick>128 Then Thick:=Thick-256;       { epaisseur negative codee sur un octet }
    FCol:=(Col Shr 12) And 15;TCol:=(Col Shr 8) And 15;
    Opaq:=((Col Shr 7) And 1)<>0;Pat:=(Col Shr 4) And 7;ICol:=Col And 15;
   End;
  26: Begin
    If (Fl And 2)<>0 Then Thick:=-3 Else If (Fl And 4)<>0 Then Thick:=-2 Else Thick:=-1;
    Pat:=0;ICol:=0;
   End;
 End;
 Big:=Font<>5;
 { objet defini par le programme : APPLBLK (code, parametre) ; la routine recoit un PARMBLK }
 If Typ=24 Then Begin
  Ic:=AES_SCR+$40;
  WL(Ic,T);WW(Ic+4,N);WW(Ic+6,St);WW(Ic+8,St);
  WW(Ic+10,X);WW(Ic+12,Y);WW(Ic+14,W);WW(Ic+16,H);
  If ClipOn Then Begin WW(Ic+18,ClipX1);WW(Ic+20,ClipY1);WW(Ic+22,ClipX2-ClipX1+1);WW(Ic+24,ClipY2-ClipY1+1);End
  Else Begin WW(Ic+18,0);WW(Ic+20,0);WW(Ic+22,640);WW(Ic+24,400);End;
  WL(Ic+26,RL(Spec+4));
  If RL(Spec)<>0 Then St:=CallEmu(RL(Spec),Ic);
  ScrDirty:=True;
 End;
 { ombre }
 If (St And 32)<>0 Then Begin
  Sh:=Abs(Thick)*2;If Sh<3 Then Sh:=3;
  AFill(X+Sh,Y+Sh,X+W-1+Sh,Y+H-1+Sh,7,1);
 End;
 { fond }
 Case Typ Of
  20,22,27,30,26: Begin
    If Thick<0 Then AFill(X,Y,X+W-1,Y+H-1,Pat,ICol)
    Else AFill(X,Y,X+W-1,Y+H-1,Pat,ICol);
   End;
  21,29: If Opaq Then AFill(X,Y,X+W-1,Y+H-1,Pat,ICol);
  28,32: ;
 End;
 { cadre }
 If (Typ<>28) And (Typ<>32) And (Typ<>23) And (Typ<>31) And (Thick<>0) Then Begin
  If FCol<>0 Then AFrame(X,Y,W,H,Thick,1) Else AFrame(X,Y,W,H,Thick,0);
 End;
 { contenu }
 Case Typ Of
  22,21,29,30: Begin
    S:=FieldText(Ted,(Typ=29) Or (Typ=30));
    If Big Then Hi:=16 Else Hi:=8;
    Wi:=Length(S)*8;
    Case Just Of
     1: TX:=X+W-Wi;
     2: TX:=X+(W-Wi) Div 2;
    Else TX:=X;
    End;
    If Wi>W Then TX:=X;      { texte plus large que la boite : cadre a gauche }
    TY:=Y+(H-Hi) Div 2;
    If (Typ=22) Or (Typ=30) Then If Thick<0 Then Begin End;
    AText(TX,TY,S,Big,TCol,True);
   End;
  26: Begin
    S:=CStrAt(Spec);
    Wi:=Length(S)*8;
    AText(X+(W-Wi) Div 2,Y+(H-16) Div 2,S,True,1,True);
   End;
  28,32: Begin
    S:=CStrAt(Spec);
    AText(X,Y+(H-16) Div 2,S,True,1,True);
   End;
  27: Begin
    S:=Chr((Spec Shr 24) And $FF);
    AText(X+(W-8) Div 2,Y+(H-16) Div 2,S,True,TCol,True);
   End;
  23: Begin
    { BITBLK }
    Ic:=Spec;
    DataA:=RL(Ic);Wb:=SmallInt(RW(Ic+4));Hi:=SmallInt(RW(Ic+6));
    XI:=SmallInt(RW(Ic+8));YI:=SmallInt(RW(Ic+10));
    For J:=0 To Hi-1 Do
     For I:=0 To Wb*8-1 Do
      If (RB(DataA+J*Wb+(I Shr 3)) And (128 Shr (I And 7)))<>0 Then OPlot(X+XI+I,Y+YI+J,1);
   End;
  31: Begin
    { ICONBLK }
    Ic:=Spec;
    MaskA:=RL(Ic);DataA:=RL(Ic+4);
    Wi:=SmallInt(RW(Ic+22));Hi:=SmallInt(RW(Ic+24));
    XI:=SmallInt(RW(Ic+18));YI:=SmallInt(RW(Ic+20));
    Wb:=(Wi+7) Div 8;
    For J:=0 To Hi-1 Do
     For I:=0 To Wi-1 Do Begin
      Bm:=Ord((RB(MaskA+J*Wb+(I Shr 3)) And (128 Shr (I And 7)))<>0);
      Bd:=Ord((RB(DataA+J*Wb+(I Shr 3)) And (128 Shr (I And 7)))<>0);
      If Bm<>0 Then Begin
       If (St And 1)<>0 Then Bd:=1-Bd;
       OPlot(X+XI+I,Y+J+YI,Bd);
      End;
     End;
    S:=CStrAt(RL(Ic+8));
    TX:=SmallInt(RW(Ic+26));TY:=SmallInt(RW(Ic+28));WT:=SmallInt(RW(Ic+30));HT:=SmallInt(RW(Ic+32));
    If WT>0 Then Begin
     AFill(X+TX,Y+TY,X+TX+WT-1,Y+TY+HT-1,0,0);
     AText(X+TX+(WT-Length(S)*8) Div 2,Y+TY+(HT-8) Div 2,S,False,1,True);
     If (St And 1)<>0 Then AInvert(X+TX,Y+TY,X+TX+WT-1,Y+TY+HT-1);
    End;
    Ch:=Chr(RW(Ic+12) And $FF);
    If Ch<>#0 Then Begin
     XI:=SmallInt(RW(Ic+14));YI:=SmallInt(RW(Ic+16));
     AText(X+XI,Y+YI,Ch,False,1,True);
    End;
   End;
 End;
 { etats }
 If (St And 4)<>0 Then AText(X+2,Y,#251,True,1,True);
 If (St And 2)<>0 Then ACrossOut(X,Y,W,H);
 If ((St And 1)<>0) And (Typ<>31) And (Typ<>25) Then Begin
  If Typ=28 Then AInvert(X,Y,X+W-1,Y+H-1)
  Else If Thick>0 Then AInvert(X+Thick,Y+Thick,X+W-1-Thick,Y+H-1-Thick)
  Else AInvert(X,Y,X+W-1,Y+H-1);
 End;
 If (St And 8)<>0 Then Begin
  For J:=Y To Y+H-1 Do
   For I:=X To X+W-1 Do If ((I+J) And 1)<>0 Then OPlot(I,J,0);
 End;
 If (St And 16)<>0 Then Begin
  AFill(X-2,Y-2,X+W+1,Y-1,0,0);AFill(X-2,Y+H,X+W+1,Y+H+1,0,0);
  AFill(X-2,Y,X-1,Y+H-1,0,0);AFill(X+W,Y,X+W+1,Y+H-1,0,0);
  AFrame(X-2,Y-2,W+4,H+4,-1,1);
 End;
End;
{$ENDIF}
{$IFDEF FPC}
{ ====================================================================== }
{       AES EMULE : OBJC_*, EDITION DE TEXTE ET FORMULAIRES (FORM_*)     }
{ ====================================================================== }

{ ------------------------------ dessin d'un arbre ---------------------- }

Procedure ObjDraw(T: LongInt; Start,Depth: Integer; CX,CY,CW,CH: Integer);
Var SvC: Boolean; S1,S2,S3,S4: LongInt; AX,AY: Integer;
 Procedure Rec(N: Integer; X,Y: Integer; D: Integer);
 Var C,G: Integer;
 Begin
  If (OFlg(T,N) And 128)<>0 Then Exit;
  DrawOne(T,N,X,Y);
  If D>0 Then Begin
   C:=OHead(T,N);G:=0;
   While (C>=0) And (C<>N) And (G<2000) Do Begin
    Rec(C,X+OX(T,C),Y+OY(T,C),D-1);
    C:=ONext(T,C);Inc(G);
   End;
  End;
 End;
Begin
 SvC:=ClipOn;S1:=ClipX1;S2:=ClipY1;S3:=ClipX2;S4:=ClipY2;
 ClipOn:=True;ClipX1:=CX;ClipY1:=CY;ClipX2:=CX+CW-1;ClipY2:=CY+CH-1;
 OXor:=False;
 If Not ObjOffset(T,Start,AX,AY) Then Begin AX:=OX(T,Start);AY:=OY(T,Start);End;
 Rec(Start,AX,AY,Depth);
 ClipOn:=SvC;ClipX1:=S1;ClipY1:=S2;ClipX2:=S3;ClipY2:=S4;
 ScrDirty:=True;
 OutPending:=True;
 OutFlush(True);
End;

Function ObjFind(T: LongInt; Start,Depth: Integer; MX0,MY0: Integer): Integer;
Var AX,AY: Integer;
 Function Rec(N: Integer; X,Y: Integer; D: Integer): Integer;
 Var C,G,R,Best: Integer;
 Begin
  Rec:=-1;
  If (OFlg(T,N) And 128)<>0 Then Exit;
  Best:=-1;
  If (MX0>=X) And (MX0<X+OW(T,N)) And (MY0>=Y) And (MY0<Y+OH(T,N)) Then Best:=N;
  If D>0 Then Begin
   C:=OHead(T,N);G:=0;
   While (C>=0) And (C<>N) And (G<2000) Do Begin
    R:=Rec(C,X+OX(T,C),Y+OY(T,C),D-1);
    If R>=0 Then Best:=R;
    C:=ONext(T,C);Inc(G);
   End;
  End;
  Rec:=Best;
 End;
Begin
 If Not ObjOffset(T,Start,AX,AY) Then Begin AX:=OX(T,Start);AY:=OY(T,Start);End;
 ObjFind:=Rec(Start,AX,AY,Depth);
End;

Procedure ObjChange(T: LongInt; N: Integer; CX,CY,CW,CH: Integer; NewState: Integer; Redraw: Boolean);
Var AX,AY: Integer; R: Boolean;
Begin
 OSetSta(T,N,NewState);
 If Redraw Then Begin
  R:=ObjOffset(T,N,AX,AY);
  If R Then Begin
   { zone de l'objet augmentee pour l'ombre et le contour }
   If (CW<=0) Or (CH<=0) Then Begin CX:=AX-4;CY:=AY-4;CW:=OW(T,N)+10;CH:=OH(T,N)+10;End;
   ObjDraw(T,N,3,Max3(CX,AX-4),Max3(CY,AY-4),Min3(CX+CW,AX+OW(T,N)+8)-Max3(CX,AX-4),Min3(CY+CH,AY+OH(T,N)+8)-Max3(CY,AY-4));
  End;
 End;
End;

Procedure ObjAdd(T: LongInt; Par,Ch: Integer);
Var Tl: Integer;
Begin
 Tl:=OTail(T,Par);
 WW(OAd(T,Ch),Word(Par));
 If Tl<0 Then Begin
  WW(OAd(T,Par)+2,Word(Ch));WW(OAd(T,Par)+4,Word(Ch));
 End Else Begin
  WW(OAd(T,Tl),Word(Ch));
  WW(OAd(T,Par)+4,Word(Ch));
 End;
End;

Procedure ObjDelete(T: LongInt; N: Integer);
Var Par,C,Prev,G: Integer;
Begin
 Par:=ObjParent(T,N);
 If Par<0 Then Exit;
 C:=OHead(T,Par);Prev:=-1;G:=0;
 While (C>=0) And (C<>Par) And (G<2000) Do Begin
  If C=N Then Break;
  Prev:=C;C:=ONext(T,C);Inc(G);
 End;
 If C<>N Then Exit;
 If (OHead(T,Par)=N) And (OTail(T,Par)=N) Then Begin
  WW(OAd(T,Par)+2,$FFFF);WW(OAd(T,Par)+4,$FFFF);
 End Else If OHead(T,Par)=N Then
  WW(OAd(T,Par)+2,Word(ONext(T,N)))
 Else Begin
  WW(OAd(T,Prev),Word(ONext(T,N)));
  If OTail(T,Par)=N Then WW(OAd(T,Par)+4,Word(Prev));
 End;
 WW(OAd(T,N),$FFFF);
End;

Procedure ObjOrder(T: LongInt; N: Integer; Pos: Integer);
Var Par,C,K,G: Integer; Ids: Array[0..99] Of Integer; Cnt,I,P: Integer;
Begin
 Par:=ObjParent(T,N);
 If Par<0 Then Exit;
 Cnt:=0;C:=OHead(T,Par);G:=0;
 While (C>=0) And (C<>Par) And (G<100) Do Begin
  If C<>N Then Begin Ids[Cnt]:=C;Inc(Cnt);End;
  C:=ONext(T,C);Inc(G);
 End;
 { Pos : -1 = dernier (devant), 0 = premier, n = apres n objets }
 If (Pos<0) Or (Pos>Cnt) Then P:=Cnt Else P:=Pos;
 For I:=Cnt DownTo P+1 Do Ids[I]:=Ids[I-1];
 Ids[P]:=N;Inc(Cnt);
 For I:=0 To Cnt-1 Do Begin
  If I<Cnt-1 Then WW(OAd(T,Ids[I]),Word(Ids[I+1])) Else WW(OAd(T,Ids[I]),Word(Par));
 End;
 WW(OAd(T,Par)+2,Word(Ids[0]));WW(OAd(T,Par)+4,Word(Ids[Cnt-1]));
 K:=0;
End;

{ ---------------------------- edition de texte ------------------------- }

Function EdSlots(Ted: LongInt): Integer;
Var Tm: String; I,K: Integer;
Begin
 Tm:=CStrAt(RL(Ted+4));K:=0;
 For I:=1 To Length(Tm) Do If Tm[I]='_' Then Inc(K);
 EdSlots:=K;
End;

Function EdValidCh(Ted: LongInt; Slot: Integer; Var C: Char): Boolean;
Var V: String; Cls: Char;
Begin
 EdValidCh:=False;
 V:=CStrAt(RL(Ted+8));
 If Slot<Length(V) Then Cls:=V[Slot+1] Else If V<>'' Then Cls:=V[Length(V)] Else Cls:='X';
 Case Cls Of
  '9': EdValidCh:=(C>='0') And (C<='9');
  'A': Begin
        If (C>='a') And (C<='z') Then C:=UpCase(C);
        EdValidCh:=((C>='A') And (C<='Z')) Or (C=' ');
       End;
  'a': EdValidCh:=((C>='A') And (C<='Z')) Or ((C>='a') And (C<='z')) Or (C=' ');
  'N': Begin
        If (C>='a') And (C<='z') Then C:=UpCase(C);
        EdValidCh:=((C>='A') And (C<='Z')) Or ((C>='0') And (C<='9')) Or (C=' ');
       End;
  'n': EdValidCh:=((C>='A') And (C<='Z')) Or ((C>='a') And (C<='z')) Or ((C>='0') And (C<='9')) Or (C=' ');
  'F': Begin
        If (C>='a') And (C<='z') Then C:=UpCase(C);
        EdValidCh:=((C>='A') And (C<='Z')) Or ((C>='0') And (C<='9')) Or (C In ['_','?','*',':','.','$','-','#','@','~']);
       End;
  'f': EdValidCh:=((C>='A') And (C<='Z')) Or ((C>='0') And (C<='9')) Or ((C>='a') And (C<='z')) Or (C In ['_','?','*',':','.','$','-']);
  'P': Begin
        If (C>='a') And (C<='z') Then C:=UpCase(C);
        EdValidCh:=((C>='A') And (C<='Z')) Or ((C>='0') And (C<='9')) Or (C In ['_','?','*',':','.','\','$','-']);
       End;
  'p': EdValidCh:=((C>='A') And (C<='Z')) Or ((C>='0') And (C<='9')) Or ((C>='a') And (C<='z')) Or (C In ['_','?','*',':','.','\','$','-']);
 Else EdValidCh:=C>=' ';
 End;
End;

{ position (x,y) du curseur d'edition a l'ecran }
Procedure EdCursorXY(T: LongInt; N: Integer; Idx: Integer; Var CX,CY: Integer);
Var AX,AY,Slot,I,P,Just,TX,Wi,H: Integer; Ted: LongInt; Tm: String;
Begin
 ObjOffset(T,N,AX,AY);
 Ted:=OSpc(T,N);
 Tm:=CStrAt(RL(Ted+4));
 Just:=RW(Ted+16);
 Wi:=Length(Tm)*8;
 Case Just Of
  1: TX:=AX+OW(T,N)-Wi;
  2: TX:=AX+(OW(T,N)-Wi) Div 2;
 Else TX:=AX;
 End;
 If Wi>OW(T,N) Then TX:=AX;
 { position du (Idx+1)-ieme '_' }
 Slot:=0;P:=Length(Tm);
 For I:=1 To Length(Tm) Do
  If Tm[I]='_' Then Begin
   If Slot=Idx Then Begin P:=I-1;Break;End;
   Inc(Slot);
  End;
 CX:=TX+P*8;
 H:=OH(T,N);
 CY:=AY+(H-16) Div 2;
End;

Procedure EdDrawCursor(T: LongInt; N: Integer; Idx: Integer);
Var CX,CY: Integer; SvC: Boolean;
Begin
 EdCursorXY(T,N,Idx,CX,CY);
 SvC:=ClipOn;ClipOn:=False;
 AInvert(CX,CY,CX+1,CY+15);
 ClipOn:=SvC;
 ScrDirty:=True;OutPending:=True;OutFlush(True);
End;

Procedure EdRedraw(T: LongInt; N: Integer);
Var AX,AY: Integer;
Begin
 If ObjOffset(T,N,AX,AY) Then ObjDraw(T,N,0,AX-3,AY-3,OW(T,N)+8,OH(T,N)+8);
End;

{ touche d'edition (code de balayage << 8 | ascii) ; retourne True si traitee }
Function EdKey(T: LongInt; N: Integer; Key: LongInt; Var Idx: Integer): Boolean;
Var Ted,Pt: LongInt; S: String; Ch: Char; Mx,I: Integer; Sc,As_: Integer;
Begin
 EdKey:=False;
 Ted:=OSpc(T,N);
 Pt:=RL(Ted);
 S:=CStrAt(Pt);
 Mx:=EdSlots(Ted);
 I:=SmallInt(RW(Ted+24));
 If (I>0) And (I-1<Mx) Then Mx:=I-1;
 Sc:=(Key Shr 8) And $FF;As_:=Key And $FF;
 If Idx>Length(S) Then Idx:=Length(S);
 If Idx<0 Then Idx:=0;
 If (Sc=$4B) And (As_=0) Then Begin If Idx>0 Then Dec(Idx);EdKey:=True;End
 Else If (Sc=$4D) And (As_=0) Then Begin If Idx<Length(S) Then Inc(Idx);EdKey:=True;End
 Else If (Sc=$47) And (As_=0) Then Begin Idx:=0;EdKey:=True;End
 Else If (Sc=$4F) And (As_=0) Then Begin Idx:=Length(S);EdKey:=True;End
 Else If As_=8 Then Begin
  If Idx>0 Then Begin Delete(S,Idx,1);Dec(Idx);End;
  EdKey:=True;
 End Else If As_=127 Then Begin
  If Idx<Length(S) Then Delete(S,Idx+1,1);
  EdKey:=True;
 End Else If (As_>=32) And (As_<>127) Then Begin
  Ch:=Chr(As_);
  If (Length(S)<Mx) And EdValidCh(Ted,Idx,Ch) Then Begin
   Insert(Ch,S,Idx+1);Inc(Idx);
  End;
  EdKey:=True;
 End;
 For I:=1 To Length(S) Do WB(Pt+I-1,Ord(S[I]));
 WB(Pt+Length(S),0);
End;

{ ------------------------------- formulaires --------------------------- }

Var
 AesDblClk  : Boolean;

Function HeadlessDefault(T: LongInt): Integer;
{ mode batch : bouton par defaut ou premier bouton de sortie }
Var I,G,R: Integer;
Begin
 R:=0;I:=0;G:=0;
 While G<500 Do Begin
  If (OFlg(T,I) And 6)=6 Then Begin R:=I;Break;End;
  If (OFlg(T,I) And 32)<>0 Then Break;
  Inc(I);Inc(G);
 End;
 If R=0 Then Begin
  I:=0;G:=0;
  While G<500 Do Begin
   If (OFlg(T,I) And 4)<>0 Then Begin R:=I;Break;End;
   If (OFlg(T,I) And 32)<>0 Then Break;
   Inc(I);Inc(G);
  End;
 End;
 HeadlessDefault:=R;
End;

Function FirstEditable(T: LongInt; From: Integer; Dir: Integer): Integer;
Var I,G: Integer;
Begin
 FirstEditable:=0;
 I:=From;G:=0;
 While (I>=0) And (G<500) Do Begin
  If ((OFlg(T,I) And 8)<>0) And ((OFlg(T,I) And 128)=0) And ((OSta(T,I) And 8)=0) Then Begin FirstEditable:=I;Exit;End;
  If Dir>0 Then Begin If (OFlg(T,I) And 32)<>0 Then Break;End;
  I:=I+Dir;Inc(G);
 End;
End;

Function NextEditable(T: LongInt; Cur: Integer; Dir: Integer): Integer;
Var R: Integer;
Begin
 If Dir>0 Then R:=FirstEditable(T,Cur+1,1) Else R:=FirstEditable(T,Cur-1,-1);
 If R=0 Then Begin
  If Dir>0 Then R:=FirstEditable(T,0,1)
  Else Begin
   R:=0;
   While True Do Begin
    If FirstEditable(T,R+1,1)=0 Then Break;
    R:=FirstEditable(T,R+1,1);
   End;
  End;
 End;
 NextEditable:=R;
End;

{ convertit un evenement hote en code AES (balayage << 8 | ascii) }
Function KeyToAes(K: Integer): LongInt;
Var Sc: Integer; C: Char;
Begin
 If K>=256 Then Begin KeyToAes:=LongInt(K-256) Shl 8;Exit;End;
 Sc:=0;C:=UpCase(Chr(K));
 If (K>=1) And (K<=26) And (K<>8) And (K<>9) And (K<>13) Then C:=Chr(64+K);
 Case K Of
  13: Begin KeyToAes:=$1C0D;Exit;End;
  8: Begin KeyToAes:=$0E08;Exit;End;
  9: Begin KeyToAes:=$0F09;Exit;End;
  27: Begin KeyToAes:=$011B;Exit;End;
  32: Begin KeyToAes:=$3920;Exit;End;
 End;
 If (C>='1') And (C<='9') Then Sc:=2+Ord(C)-49
 Else If C='0' Then Sc:=11
 Else Begin
  Case C Of
   'Q': Sc:=16;'W': Sc:=17;'E': Sc:=18;'R': Sc:=19;'T': Sc:=20;'Y': Sc:=21;'U': Sc:=22;'I': Sc:=23;'O': Sc:=24;'P': Sc:=25;
   'A': Sc:=30;'S': Sc:=31;'D': Sc:=32;'F': Sc:=33;'G': Sc:=34;'H': Sc:=35;'J': Sc:=36;'K': Sc:=37;'L': Sc:=38;
   'Z': Sc:=44;'X': Sc:=45;'C': Sc:=46;'V': Sc:=47;'B': Sc:=48;'N': Sc:=49;'M': Sc:=50;
   '-': Sc:=12;'=': Sc:=13;'[': Sc:=26;']': Sc:=27;';': Sc:=39;'''': Sc:=40;'`': Sc:=41;
   '\': Sc:=43;',': Sc:=51;'.': Sc:=52;'/': Sc:=53;
  End;
 End;
 KeyToAes:=(LongInt(Sc) Shl 8) Or K;
End;

{ clic sur un objet : retourne True si c'est une sortie du formulaire }
Function FormClick(T: LongInt; N: Integer; Dbl: Boolean; Var Redo: Boolean): Boolean;
Var Par,C,G,J: Integer; Fl,St: Integer; E: TEvent; Inside: Boolean; AX,AY: Integer; Sel0: Boolean;
Begin
 FormClick:=False;Redo:=False;
 Fl:=OFlg(T,N);St:=OSta(T,N);
 If (St And 8)<>0 Then Exit;
 If (Fl And 1)<>0 Then Begin
  Sel0:=(St And 1)<>0;
  If (Fl And $10)<>0 Then Begin
   { bouton radio : desactive les freres }
   Par:=ObjParent(T,N);
   If Par>=0 Then Begin
    C:=OHead(T,Par);G:=0;
    While (C>=0) And (C<>Par) And (G<500) Do Begin
     If (C<>N) And ((OFlg(T,C) And $10)<>0) And ((OSta(T,C) And 1)<>0) Then
      ObjChange(T,C,0,0,0,0,OSta(T,C) And (Not 1),True);
     C:=ONext(T,C);Inc(G);
    End;
   End;
   If Not Sel0 Then ObjChange(T,N,0,0,0,0,St Or 1,True);
  End Else If (Fl And ($4 Or $40))=0 Then Begin
   ObjChange(T,N,0,0,0,0,St Xor 1,True);
  End Else Begin
   ObjChange(T,N,0,0,0,0,St Or 1,True);
  End;
 End;
 If (Fl And $40)<>0 Then Begin
  { sortie immediate (touch exit) }
  FormClick:=True;Exit;
 End;
 If (Fl And 4)<>0 Then Begin
  { bouton de sortie : suit la souris jusqu'au relachement }
  ObjOffset(T,N,AX,AY);
  Repeat
   PollEvent(E);
   Inside:=(E.X>=AX) And (E.X<AX+OW(T,N)) And (E.Y-OFS_Y>=AY) And (E.Y-OFS_Y<AY+OH(T,N));
   If (E.Kind=4) Or (E.Kind=0) Then Begin
    If Inside And ((OSta(T,N) And 1)=0) And ((OFlg(T,N) And 1)<>0) Then ObjChange(T,N,0,0,0,0,OSta(T,N) Or 1,True);
    If (Not Inside) And ((OSta(T,N) And 1)<>0) And ((OFlg(T,N) And 1)<>0) Then ObjChange(T,N,0,0,0,0,OSta(T,N) And (Not 1),True);
   End;
  Until (E.Kind=3) Or ((E.B And 3)=0) Or QuitReq Or BreakReq;
  If Inside Then FormClick:=True
  Else Begin
   If (OFlg(T,N) And 1)=0 Then ;
   Redo:=True;
  End;
 End Else If (Fl And 1)<>0 Then Begin
  Repeat PollEvent(E);Until (E.Kind=3) Or ((E.B And 3)=0) Or QuitReq Or BreakReq;
 End;
 J:=0;
End;

Function FormDo(T: LongInt; Start: Integer): Integer;
Var E: TEvent; Cur,Hit,Ed,I,Idx: Integer; K: LongInt; Done,Redo,Dbl: Boolean; Res: Integer;
    AX,AY,CX,CY: Integer; Moved: Boolean;
Begin
 If Headless Then Begin
  Res:=HeadlessDefault(T);
  WriteLn('[DIALOG] -> ',Res);
  FormDo:=Res;Exit;
 End;
 OutFlush(True);
 GemCur(True);
 Cur:=0;
 If (Start>0) And ((OFlg(T,Start) And 8)<>0) Then Cur:=Start Else Cur:=FirstEditable(T,0,1);
 Idx:=0;
 If Cur>0 Then Begin
  Idx:=Length(CStrAt(RL(OSpc(T,Cur))));
  EdDrawCursor(T,Cur,Idx);
 End;
 Res:=0;Done:=False;AesDblClk:=False;
 Repeat
  PollEvent(E);
  If E.Kind=1 Then Begin
   K:=KeyToAes(E.Key);
   If ((K Shr 8)=$1C) Or ((K Shr 8)=$72) Then Begin
    { Retour : bouton par defaut }
    Hit:=0;I:=0;
    While I<500 Do Begin
     If ((OFlg(T,I) And 2)<>0) And ((OSta(T,I) And 8)=0) Then Begin Hit:=I;Break;End;
     If (OFlg(T,I) And 32)<>0 Then Break;
     Inc(I);
    End;
    If Hit>0 Then Begin
     If Cur>0 Then EdDrawCursor(T,Cur,Idx);
     If (OFlg(T,Hit) And 1)<>0 Then ObjChange(T,Hit,0,0,0,0,OSta(T,Hit) Or 1,True);
     Res:=Hit;Done:=True;Cur:=0;
    End;
   End Else If (Cur>0) And (((K Shr 8)=$0F) Or ((K Shr 8)=$50)) Then Begin
    EdDrawCursor(T,Cur,Idx);Cur:=NextEditable(T,Cur,1);Idx:=Length(CStrAt(RL(OSpc(T,Cur))));EdDrawCursor(T,Cur,Idx);
   End Else If (Cur>0) And ((K Shr 8)=$48) Then Begin
    EdDrawCursor(T,Cur,Idx);Cur:=NextEditable(T,Cur,-1);Idx:=Length(CStrAt(RL(OSpc(T,Cur))));EdDrawCursor(T,Cur,Idx);
   End Else If Cur>0 Then Begin
    EdDrawCursor(T,Cur,Idx);
    If EdKey(T,Cur,K,Idx) Then EdRedraw(T,Cur);
    EdDrawCursor(T,Cur,Idx);
   End;
  End Else If E.Kind=2 Then Begin
   Hit:=ObjFind(T,0,10,E.X,E.Y-OFS_Y);
   If Hit>=0 Then Begin
    Dbl:=(NowCs-LastClkCs<40);LastClkCs:=NowCs;
    If ((OFlg(T,Hit) And 8)<>0) And ((OSta(T,Hit) And 8)=0) Then Begin
     If Cur>0 Then EdDrawCursor(T,Cur,Idx);
     Cur:=Hit;
     ObjOffset(T,Hit,AX,AY);
     EdCursorXY(T,Hit,0,CX,CY);
     Idx:=(E.X-CX+4) Div 8;
     If Idx<0 Then Idx:=0;
     If Idx>Length(CStrAt(RL(OSpc(T,Hit)))) Then Idx:=Length(CStrAt(RL(OSpc(T,Hit))));
     EdDrawCursor(T,Hit,Idx);
    End;
    If FormClick(T,Hit,Dbl,Redo) Then Begin
     Res:=Hit;Done:=True;AesDblClk:=Dbl;
     If Cur>0 Then Begin EdDrawCursor(T,Cur,Idx);Cur:=0;End;
    End;
   End;
  End;
 Until Done Or QuitReq Or BreakReq;
 If Res=0 Then Res:=0;
 If AesDblClk Then Res:=Res Or $8000;
 FormDo:=Res;
 Moved:=False;
End;

Procedure FormCenter(T: LongInt; Var X,Y,W,H: Integer);
Var Wd,Ht: Integer;
Begin
 Wd:=OW(T,0);Ht:=OH(T,0);
 WW(OAd(T,0)+16,Word((640-Wd) Div 2));
 WW(OAd(T,0)+18,Word((400-Ht) Div 2));
 X:=OX(T,0)-4;Y:=OY(T,0)-4;W:=Wd+8;H:=Ht+8;
End;
{$ENDIF}
{$IFDEF FPC}
{ ====================================================================== }
{          AES EMULE : REPARTITEUR (APPL, MENU, EVNT, WIND, GRAF...)     }
{ ====================================================================== }

Type
 TAesSave = Record
  Pool    : LongInt;
  Rs      : Array[1..MAXRSC] Of TRscInfo;
  RsCur   : Integer;
  VdS     : Array[0..VD_MAX] Of TVdi;
  VdC     : Integer;
  KeyScan : Boolean;
  MenuT   : LongInt;
 End;

Var
 AesMenuTree : LongInt;
 AesSaves    : Array[1..6] Of TAesSave;
 AesSaveN    : Integer;

Procedure AesReset;
Var I: Integer;
Begin
 AesPoolTop:=AES_POOL;
 FillChar(Rsc,SizeOf(Rsc),0);
 RscCur:=0;
 For I:=0 To VD_MAX Do Vd[I].Used:=False;
 VdDefaults(0);
 VdCur:=1;
 AesKeyScan:=False;
 AesMenuTree:=0;
 HeadIdleA:=0;
 ScrDirty:=False;
End;

Procedure AesSave;
Begin
 If AesSaveN>=6 Then Exit;
 Inc(AesSaveN);
 AesSaves[AesSaveN].Pool:=AesPoolTop;AesSaves[AesSaveN].Rs:=Rsc;AesSaves[AesSaveN].RsCur:=RscCur;
 AesSaves[AesSaveN].VdS:=Vd;AesSaves[AesSaveN].VdC:=VdCur;AesSaves[AesSaveN].KeyScan:=AesKeyScan;
 AesSaves[AesSaveN].MenuT:=AesMenuTree;
End;

Procedure AesRestore;
Begin
 If AesSaveN<1 Then Exit;
 AesPoolTop:=AesSaves[AesSaveN].Pool;Rsc:=AesSaves[AesSaveN].Rs;RscCur:=AesSaves[AesSaveN].RsCur;
 Vd:=AesSaves[AesSaveN].VdS;VdCur:=AesSaves[AesSaveN].VdC;AesKeyScan:=AesSaves[AesSaveN].KeyScan;
 AesMenuTree:=AesSaves[AesSaveN].MenuT;
 Dec(AesSaveN);
End;

{ ------------------------------- menus --------------------------------- }

Function MenuFromTree(T: LongInt): Integer;
Var H,Bar,Tit,Scr,C,B,It,G,K: Integer; S: String;
Begin
 MenuFromTree:=0;
 H:=1;
 FillChar(GMn[H],SizeOf(TGMenu),0);
 GMn[H].Used:=True;
 Bar:=OHead(T,0);
 If Bar<0 Then Exit;
 Tit:=OHead(T,Bar);Scr:=ONext(T,Bar);
 C:=OHead(T,Tit);G:=0;
 While (C>=0) And (C<>Tit) And (G<MAXMT) Do Begin
  Inc(G);
  GMn[H].TT[G]:=Copy(CStrAt(OSpc(T,C)),1,30);
  GMn[H].TOb[G]:=C;
  C:=ONext(T,C);
 End;
 GMn[H].NT:=G;
 B:=OHead(T,Scr);K:=0;
 While (B>=0) And (B<>Scr) And (K<G) Do Begin
  Inc(K);
  It:=OHead(T,B);
  While (It>=0) And (It<>B) And (GMn[H].NI[K]<MAXMI) Do Begin
   S:=CStrAt(OSpc(T,It));
   If Pos('Desk Accessory',S)=0 Then Begin
    Inc(GMn[H].NI[K]);
    If (S<>'') And (S[1]='-') Then GMn[H].IT[K,GMn[H].NI[K]]:='-'
    Else GMn[H].IT[K,GMn[H].NI[K]]:=Copy(S,1,40);
    If (OSta(T,It) And 8)<>0 Then GMn[H].ID[K,GMn[H].NI[K]]:=True;
    If (OSta(T,It) And 4)<>0 Then GMn[H].IC[K,GMn[H].NI[K]]:=True;
    GMn[H].IDn[K,GMn[H].NI[K]]:=It;
   End;
   It:=ONext(T,It);
  End;
  B:=ONext(T,B);
 End;
 MenuFromTree:=H;
End;

Procedure MenuItemFind(Obj: Integer; Var Tt,It: Integer);
Var I,J: Integer;
Begin
 Tt:=0;It:=0;
 If ActMenu<1 Then Exit;
 For I:=1 To GMn[ActMenu].NT Do
  For J:=1 To GMn[ActMenu].NI[I] Do
   If GMn[ActMenu].IDn[I,J]=Obj Then Begin Tt:=I;It:=J;End;
End;

{ ------------------------------- graf ---------------------------------- }

Procedure XorRect(X,Y,W,H: Integer);
Var SvC: Boolean;
Begin
 SvC:=ClipOn;ClipOn:=False;
 OXor:=True;
 If (W>0) And (H>0) Then Begin
  AInvert(X,Y,X+W-1,Y);
  If H>1 Then AInvert(X,Y+H-1,X+W-1,Y+H-1);
  If H>2 Then Begin AInvert(X,Y+1,X,Y+H-2);If W>1 Then AInvert(X+W-1,Y+1,X+W-1,Y+H-2);End;
 End;
 OXor:=False;
 ClipOn:=SvC;
 ScrDirty:=True;OutPending:=True;OutFlush(True);
End;

{ ------------------------------ appel AES ------------------------------ }

Procedure AesMouseForm(N: Integer; Addr: LongInt);
Var I: Integer;
Begin
 CurHx:=0;CurHy:=0;
 Case N Of
  0,4: CurKind:=0;
  1: Begin CurKind:=2;CurHx:=8;CurHy:=9;End;
  2: Begin CurKind:=4;CurHx:=8;CurHy:=9;End;
  3: CurKind:=0;
  5,6,7: Begin CurKind:=3;CurHx:=8;CurHy:=9;End;
  255: Begin
        CurHx:=SmallInt(RW(Addr));CurHy:=SmallInt(RW(Addr+2));CurKind:=1;
        For I:=0 To 15 Do Begin CurMask[I]:=RW(Addr+10+I*2);CurData[I]:=RW(Addr+42+I*2);End;
       End;
  256: Begin GemCur(False);Exit;End;
  257: Begin GemCur(True);Exit;End;
 Else CurKind:=0;
 End;
 If ProgMouse And (Not Headless) Then Begin HideMouse;ShowMouse;End;
End;

Var
 ScrapPath: String;                       { presse-papiers (scrp_read / scrp_write) }
 ShelDefCmd,ShelDefDir: String;           { shel_rdef / shel_wdef }
 ObjSysV: Array[1..6,0..1] Of Integer;    { objc_sysvar }
 AesSearchPos: Integer;
 BvDisk,BvHard: LongInt;

{ menu_popup : menu contextuel a partir d'un arbre ; retourne l'objet choisi ou -1 }
Function AesPopup(Tr: LongInt; Mn,X0,Y0: Integer): Integer;
Var Items: Array[1..40] Of Integer; N,I,J,W,H,X,Y,Sel: Integer; S: String; Sv: TSave; E: TEvent; Done: Boolean;
    Tp,Sp: LongInt;
 Function ItemText(O: Integer): String;
 Begin
  Tp:=OTyp(Tr,O);Sp:=OSpc(Tr,O);
  If (Tp=28) Or (Tp=26) Then ItemText:=CStrAt(Sp)
  Else If (Tp=21) Or (Tp=22) Or (Tp=29) Or (Tp=30) Then ItemText:=CStrAt(RL(Sp))
  Else ItemText:='';
 End;
Begin
 AesPopup:=-1;
 N:=0;
 I:=OHead(Tr,Mn);
 While (I>0) And (I<>Mn) And (N<40) Do Begin Inc(N);Items[N]:=I;I:=ONext(Tr,I);End;
 If N=0 Then Exit;
 W:=OW(Tr,Mn);
 For I:=1 To N Do If Length(ItemText(Items[I]))*8+8>W Then W:=Length(ItemText(Items[I]))*8+8;
 H:=N*16;
 X:=X0;Y:=Y0+OFS_Y;
 If X+W+2>638 Then X:=638-W-2;
 If X<0 Then X:=0;
 If Y+H+2>SCR_H-2 Then Y:=SCR_H-2-H-2;
 OutFlush(True);
 HideMouse;
 SaveBack(Sv,X-1,Y-1,X+W+4,Y+H+4);
 Box(X+3,Y+3,X+W+3,Y+H+3,INK);
 Box(X,Y,X+W,Y+H,PAPER);Frame(X,Y,X+W,Y+H);
 For I:=1 To N Do Begin
  S:=ItemText(Items[I]);
  If (OSta(Tr,Items[I]) And 8)<>0 Then GreyText16(X+4,Y+(I-1)*16,S) Else PText16(X+4,Y+(I-1)*16,S);
 End;
 ShowMouse;
 Done:=False;Sel:=-1;
 Repeat
  PollEvent(E);
  If E.Kind=2 Then Begin
   Done:=True;
   If (E.X>=X) And (E.X<=X+W) And (E.Y>=Y) And (E.Y<Y+H) Then Begin
    J:=(E.Y-Y) Div 16+1;
    If (J>=1) And (J<=N) And ((OSta(Tr,Items[J]) And 8)=0) Then Sel:=Items[J];
   End;
  End Else If (E.Kind=1) And (E.Key=K_ESC) Then Done:=True;
 Until Done Or QuitReq Or BreakReq;
 HideMouse;RestoreBack(Sv);ShowMouse;
 AesPopup:=Sel;
End;

Procedure AesCall(PB: LongInt);
Var Ctl,Glob,IntIn,IntOut,AddrIn,AddrOut: LongInt; Op,I,J,K,H: Integer;
    A,B: LongInt; T: LongInt; S,S2,Mask,Dir,Nm: String; X1,Y1,W1,H1: Integer; R1,R2,R3: TRct; Ev: LongInt;
    E: TEvent; SvC: Boolean; Ok: Boolean; Mxx,Myy: LongInt;
 Procedure IO(Ix: Integer; V: LongInt);
 Begin WW(IntOut+Ix*2,Word(V And $FFFF)); End;
 Function IW(Ix: Integer): Integer;
 Begin IW:=SmallInt(RW(IntIn+Ix*2)); End;
 Function AA(Ix: Integer): LongInt;
 Begin AA:=RL(AddrIn+Ix*4); End;
 Procedure HeadlessWait(Mask: Integer);
 Begin
  Inc(HeadIdleA);
  If ((Mask And 32)<>0) And (HeadIdleA<20000) Then Begin
   IO(0,32);IO(1,0);IO(2,0);IO(3,0);IO(4,0);IO(5,0);IO(6,0);Exit;
  End;
  EmuMsg:=T3('Batch mode: the program waits for a mouse or keyboard event',
             'Mode batch : le programme attend un '#130'v'#130'nement souris ou clavier',
             'Batch-Modus: das Programm wartet auf ein Maus- oder Tastaturereignis');
  EmuHalt:=True;EmuCode:=-1;
 End;
 Function Multi(Msk,BM,BS,NC,Ticks: LongInt; R1f: Boolean; X1_,Y1_,W1_,H1_: LongInt; R2f: Boolean;
                X2_,Y2_,W2_,H2_: LongInt; PMsg: LongInt): LongInt;
 Begin
  If Headless Then Begin
   HeadlessWait(Msk);
   Multi:=RW(IntOut) And $FFFF;
   Exit;
  End;
  Multi:=GemEvent(Msk,BM,BS,NC,Ticks,R1f,X1_,Y1_,W1_,H1_,R2f,X2_,Y2_,W2_,H2_,PMsg,IntOut+10,IntOut+6,IntOut+12,IntOut+2,IntOut+4,IntOut+8);
 End;
Begin
 Ctl:=RL(PB);Glob:=RL(PB+4);IntIn:=RL(PB+8);IntOut:=RL(PB+12);AddrIn:=RL(PB+16);AddrOut:=RL(PB+20);
 Op:=SmallInt(RW(Ctl));
 If RtTrace Then Begin
  Write(ErrOutput,'AES ',Op,' in:');
  For I:=0 To Min3(SmallInt(RW(Ctl+2)),10)-1 Do Write(ErrOutput,' ',SmallInt(RW(IntIn+I*2)));
  WriteLn(ErrOutput);Flush(ErrOutput);
 End;
 IO(0,1);
 VdCur:=0;
 Case Op Of
  { ---------------- appl ---------------- }
  10: Begin
       Inc(AesNext);
       If AesNext=1 Then Begin
        ClearGem;GemMode:=True;GemUsed:=True;AesKeyScan:=True;
        ClipOn:=False;
        GemRefresh(0,0,640,400,False);
       End;
       IO(0,AesNext);
       WW(Glob,$0120);WW(Glob+2,1);WW(Glob+4,AesNext);
       If RscCur>0 Then Begin WL(Glob+10,RscGAddr(0,0));WL(Glob+14,Rsc[RscCur].Base);End;
      End;
  11,12,14,15: IO(0,0);
  13: IO(0,-1);
  19: IO(0,1);
  { ---------------- evnt ---------------- }
  20: Begin
       IO(0,0);
       If Headless Then HeadlessWait(1)
       Else Begin
        Multi(1,0,0,0,0,False,0,0,0,0,False,0,0,0,0,AES_SCR);
        IO(0,RW(IntOut+10));
       End;
      End;
  21: Begin
       { evnt_button : clics, masque, etat }
       If Headless Then HeadlessWait(2)
       Else Begin
        Ev:=Multi(2,IW(1),IW(2),IW(0),0,False,0,0,0,0,False,0,0,0,0,AES_SCR);
        I:=RW(IntOut+12);
        IO(0,I);IO(1,RW(IntOut+2));IO(2,RW(IntOut+4));IO(3,RW(IntOut+6));IO(4,RW(IntOut+8));
       End;
      End;
  22: Begin
       { evnt_mouse : drapeau, rectangle }
       If Headless Then HeadlessWait(4)
       Else Begin
        Ev:=Multi(4,0,0,0,0,IW(0)<>0,IW(1),IW(2),IW(3),IW(4),False,0,0,0,0,AES_SCR);
        IO(0,1);
       End;
      End;
  23: Begin
       If Headless Then HeadlessWait(16)
       Else Begin
        Ev:=Multi(16,0,0,0,0,False,0,0,0,0,False,0,0,0,0,AA(0));
        IO(0,1);
       End;
      End;
  24: Begin
       If Headless Then HeadlessWait(32)
       Else Begin
        Ev:=Multi(32,0,0,0,(IW(0) And $FFFF)+LongInt(IW(1)) Shl 16,False,0,0,0,0,False,0,0,0,0,AES_SCR);
        IO(0,1);
       End;
      End;
  25: Begin
       Ev:=IW(0);
       If Headless Then HeadlessWait(Ev)
       Else Begin
        Ev:=Multi(Ev And $3F,IW(2),IW(3),IW(1),(LongInt(IW(14)) And $FFFF)+LongInt(IW(15)) Shl 16,IW(4)<>0,IW(5),IW(6),IW(7),IW(8),
                  IW(9)<>0,IW(10),IW(11),IW(12),IW(13),AA(0));
        IO(0,Ev);
        If RtTrace Then Begin WriteLn(ErrOutput,'   evnt_multi ->',Ev,' key=$',HexStr(RW(IntOut+10),16),' kbd=',SmallInt(RW(IntOut+8)));Flush(ErrOutput);End;
       End;
      End;
  26: IO(0,1);
  { ---------------- menu ---------------- }
  30: Begin
       T:=AA(0);
       If IW(0)<>0 Then Begin
        I:=MenuFromTree(T);
        If I>0 Then Begin
         AesMenuTree:=T;
         SyncAcc(I);MenuLayout(I);GMn[I].Drawn:=True;ActMenu:=I;
         GemBarRedraw;
        End;
       End Else Begin
        If ActMenu>0 Then GMn[ActMenu].Drawn:=False;
        MenuBackToSys;
        AesMenuTree:=0;
       End;
      End;
  31: Begin
       T:=AA(0);I:=IW(0);
       If IW(1)<>0 Then OSetSta(T,I,OSta(T,I) Or 4) Else OSetSta(T,I,OSta(T,I) And (Not 4));
       MenuItemFind(I,J,K);
       If J>0 Then GMn[ActMenu].IC[J,K]:=(IW(1)<>0);
      End;
  32: Begin
       T:=AA(0);I:=IW(0);
       If IW(1)<>0 Then OSetSta(T,I,OSta(T,I) And (Not 8)) Else OSetSta(T,I,OSta(T,I) Or 8);
       MenuItemFind(I,J,K);
       If J>0 Then GMn[ActMenu].ID[J,K]:=(IW(1)=0);
      End;
  33: Begin
       If ActMenu>0 Then Begin
        If IW(1)<>0 Then GMn[ActMenu].Hi:=0 Else GMn[ActMenu].Hi:=IW(0);
        GemBarRedraw;
       End;
      End;
  34: Begin
       T:=AA(0);I:=IW(0);
       S:=CStrAt(AA(1));
       A:=OSpc(T,I);
       For J:=1 To Length(S) Do WB(A+J-1,Ord(S[J]));
       WB(A+Length(S),0);
       MenuItemFind(I,J,K);
       If J>0 Then GMn[ActMenu].IT[J,K]:=Copy(S,1,40);
      End;
  35: Begin
       S:=CStrAt(AA(0));
       If AccN<MAXACC Then Begin
        Inc(AccN);AccName[AccN]:=Copy(S,1,40);IO(0,AccN-1);
        If ActMenu=0 Then SysMenuOn
        Else Begin SyncAcc(ActMenu);MenuLayout(ActMenu);GemBarRedraw;End;
       End Else IO(0,-1);
      End;
  { ---------------- objc ---------------- }
  40: Begin ObjAdd(AA(0),IW(0),IW(1));IO(0,1);End;
  41: Begin ObjDelete(AA(0),IW(0));IO(0,1);End;
  42: Begin
       T:=AA(0);
       ObjDraw(T,IW(0),IW(1),IW(2),IW(3),IW(4),IW(5));
       IO(0,1);
      End;
  43: IO(0,ObjFind(AA(0),IW(0),IW(1),IW(2),IW(3)));
  44: Begin
       If ObjOffset(AA(0),IW(0),X1,Y1) Then Begin IO(0,1);IO(1,X1);IO(2,Y1);End
       Else Begin IO(0,0);IO(1,0);IO(2,0);End;
      End;
  45: Begin ObjOrder(AA(0),IW(0),IW(1));IO(0,1);End;
  46: Begin
       T:=AA(0);I:=IW(0);K:=IW(2);
       Case IW(3) Of
        0: IO(0,1);
        1: Begin
            K:=Length(CStrAt(RL(OSpc(T,I))));
            If Not Headless Then EdDrawCursor(T,I,K);
            IO(0,1);IO(1,K);
           End;
        2: Begin
            If Not Headless Then EdDrawCursor(T,I,K);
            If EdKey(T,I,IW(1) And $FFFF,K) Then Begin If Not Headless Then EdRedraw(T,I);End;
            If Not Headless Then EdDrawCursor(T,I,K);
            IO(0,1);IO(1,K);
           End;
        3: Begin
            If Not Headless Then EdDrawCursor(T,I,K);
            IO(0,1);IO(1,K);
           End;
       Else IO(0,0);
       End;
      End;
  47: Begin
       ObjChange(AA(0),IW(0),IW(2),IW(3),IW(4),IW(5),IW(6),IW(7)<>0);
       IO(0,1);
      End;
  { ---------------- form ---------------- }
  50: Begin
       If RtTrace Then Begin
        T:=AA(0);
        WriteLn(ErrOutput,'form_do tree=$',HexStr(T,8));
        I:=0;
        Repeat
         WriteLn(ErrOutput,' ob ',I,' nx=',ONext(T,I),' hd=',OHead(T,I),' tl=',OTail(T,I),' typ=',OTyp(T,I),' fl=$',HexStr(OFlg(T,I),4),
                 ' st=$',HexStr(OSta(T,I),4),' spec=$',HexStr(OSpc(T,I),16),' x=',OX(T,I),' y=',OY(T,I),' w=',OW(T,I),' h=',OH(T,I));
         If OTyp(T,I) In [21,22,29,30] Then
          WriteLn(ErrOutput,'    TED thick=',SmallInt(RW(OSpc(T,I)+22)),' just=',RW(OSpc(T,I)+16),' font=',RW(OSpc(T,I)+12),' col=$',HexStr(RW(OSpc(T,I)+18),16),
                  ' txt="',CStrAt(RL(OSpc(T,I))),'" tmpl="',CStrAt(RL(OSpc(T,I)+4)),'"');
         Inc(I);
        Until (OFlg(T,I-1) And 32<>0) Or (I>40);
        Flush(ErrOutput);
       End;
       IO(0,FormDo(AA(0),IW(0)));
      End;
  51: Begin
       { form_dial : 0 debut, 1 agrandissement, 2 reduction, 3 fin }
       If IW(0)=3 Then GemRefresh(IW(5),IW(6),IW(7)+8,IW(8)+8,True);
       IO(0,1);
      End;
  52: Begin
       S:=CStrAt(AA(0));
       If Not Headless Then OutFlush(True);
       IO(0,AesAlert(S,IW(0)));
      End;
  53: Begin
       IO(0,AesAlert('[3][TOS error '+IntStr(IW(0))+'][ OK ]',1));
      End;
  54: Begin
       FormCenter(AA(0),X1,Y1,W1,H1);
       IO(1,X1);IO(2,Y1);IO(3,W1);IO(4,H1);
      End;
  55: Begin
       IO(0,1);IO(1,IW(1));IO(2,IW(2));
      End;
  56: Begin
       Ok:=False;
       T:=AA(0);
       I:=IW(0);
       IO(0,0);
       If FormClick(T,I,IW(1)>1,Ok) Then IO(0,0) Else IO(0,1);
       IO(1,I);
      End;
  { ---------------- graf ---------------- }
  70: Begin
       { graf_rubberbox : x, y, largeur min, hauteur min }
       X1:=IW(0);Y1:=IW(1);W1:=IW(2);H1:=IW(3);
       If Headless Then Begin IO(1,W1);IO(2,H1);End
       Else Begin
        GemCur(True);
        R1.W:=0;R1.H:=0;
        Repeat
         PollEvent(E);
         Mxx:=E.X;Myy:=E.Y-OFS_Y;
         R2.W:=Mxx-X1+1;R2.H:=Myy-Y1+1;
         If R2.W<IW(2) Then R2.W:=IW(2);
         If R2.H<IW(3) Then R2.H:=IW(3);
         If (R2.W<>R1.W) Or (R2.H<>R1.H) Then Begin
          If R1.W>0 Then XorRect(X1,Y1,R1.W,R1.H);
          XorRect(X1,Y1,R2.W,R2.H);R1:=R2;
         End;
        Until ((E.B And 3)=0) Or QuitReq Or BreakReq;
        If R1.W>0 Then XorRect(X1,Y1,R1.W,R1.H);
        IO(1,R1.W);IO(2,R1.H);
       End;
      End;
  71: Begin
       { graf_dragbox : l, h, x depart, y depart, rectangle limite }
       W1:=IW(0);H1:=IW(1);X1:=IW(2);Y1:=IW(3);
       If Headless Then Begin IO(1,X1);IO(2,Y1);End
       Else Begin
        GemCur(True);
        GetMouseState(MX,MY,MB);
        A:=MX-X1;B:=MY-OFS_Y-Y1;
        R1.X:=X1;R1.Y:=Y1;
        XorRect(R1.X,R1.Y,W1,H1);
        Repeat
         PollEvent(E);
         R2.X:=E.X-A;R2.Y:=E.Y-OFS_Y-B;
         If R2.X<IW(4) Then R2.X:=IW(4);
         If R2.Y<IW(5) Then R2.Y:=IW(5);
         If R2.X+W1>IW(4)+IW(6) Then R2.X:=IW(4)+IW(6)-W1;
         If R2.Y+H1>IW(5)+IW(7) Then R2.Y:=IW(5)+IW(7)-H1;
         If (R2.X<>R1.X) Or (R2.Y<>R1.Y) Then Begin
          XorRect(R1.X,R1.Y,W1,H1);XorRect(R2.X,R2.Y,W1,H1);R1:=R2;
         End;
        Until ((E.B And 3)=0) Or QuitReq Or BreakReq;
        XorRect(R1.X,R1.Y,W1,H1);
        IO(1,R1.X);IO(2,R1.Y);
       End;
      End;
  72,73,74: IO(0,1);
  75: Begin
       { graf_watchbox : arbre, objet, etat dedans, etat dehors }
       T:=AA(0);I:=IW(1);
       If Headless Then IO(0,1)
       Else Begin
        ObjOffset(T,I,X1,Y1);
        Ok:=False;
        Repeat
         PollEvent(E);
         Ok:=(E.X>=X1) And (E.X<X1+OW(T,I)) And (E.Y-OFS_Y>=Y1) And (E.Y-OFS_Y<Y1+OH(T,I));
         If Ok And (OSta(T,I)<>IW(2)) Then ObjChange(T,I,0,0,0,0,IW(2),True)
         Else If (Not Ok) And (OSta(T,I)<>IW(3)) Then ObjChange(T,I,0,0,0,0,IW(3),True);
        Until ((E.B And 3)=0) Or QuitReq Or BreakReq;
        If Ok Then IO(0,1) Else IO(0,0);
       End;
      End;
  76: Begin
       { graf_slidebox : arbre, parent, objet, horizontal/vertical }
       T:=AA(0);I:=IW(0);J:=IW(1);K:=IW(2);
       If Headless Then IO(0,0)
       Else Begin
        ObjOffset(T,I,X1,Y1);
        GetMouseState(MX,MY,MB);
        A:=MX;B:=MY-OFS_Y;
        Repeat
         PollEvent(E);
         If K=0 Then Begin
          H1:=OW(T,I)-OW(T,J);
          If H1<=0 Then H1:=1;
          W1:=OX(T,J)+(E.X-A);
          If W1<0 Then W1:=0;
          If W1>H1 Then W1:=H1;
          If W1<>OX(T,J) Then Begin
           WW(OAd(T,J)+16,Word(W1));
           ObjDraw(T,I,3,X1,Y1,OW(T,I),OH(T,I));
          End;
          A:=E.X;
         End Else Begin
          H1:=OH(T,I)-OH(T,J);
          If H1<=0 Then H1:=1;
          W1:=OY(T,J)+((E.Y-OFS_Y)-B);
          If W1<0 Then W1:=0;
          If W1>H1 Then W1:=H1;
          If W1<>OY(T,J) Then Begin
           WW(OAd(T,J)+18,Word(W1));
           ObjDraw(T,I,3,X1,Y1,OW(T,I),OH(T,I));
          End;
          B:=E.Y-OFS_Y;
         End;
        Until ((E.B And 3)=0) Or QuitReq Or BreakReq;
        If K=0 Then Begin H1:=OW(T,I)-OW(T,J);W1:=OX(T,J);End Else Begin H1:=OH(T,I)-OH(T,J);W1:=OY(T,J);End;
        If H1<=0 Then IO(0,0) Else IO(0,W1*1000 Div H1);
       End;
      End;
  77: Begin IO(0,1);IO(1,8);IO(2,16);IO(3,8);IO(4,16);End;
  78: AesMouseForm(IW(0),AA(0));
  79: Begin
       If Headless Then Begin IO(1,0);IO(2,0);IO(3,0);IO(4,0);End
       Else Begin
        GetMouseState(MX,MY,MB);
        IO(1,MX);IO(2,MY-OFS_Y);IO(3,MB And 3);IO(4,LastKbd);
       End;
      End;
  { ---------------- scrp / fsel ---------------- }
  80: Begin
       S:=ScrapPath;
       For I:=1 To Length(S) Do WB(AA(0)+I-1,Ord(S[I]));
       WB(AA(0)+Length(S),0);IO(0,1);
      End;
  81: Begin ScrapPath:=CStrAt(AA(0));IO(0,1);End;
  90,91: Begin
       S:=CStrAt(AA(0));S2:=CStrAt(AA(1));
       If Headless Then Begin
        WriteLn('[FILE SELECTOR] cancelled in batch mode');
        IO(1,0);
       End Else Begin
        J:=0;
        For I:=1 To Length(S) Do If (S[I]='\') Or (S[I]='/') Then J:=I;
        Dir:=Copy(S,1,J);Mask:=Copy(S,J+1,100);
        If Mask='' Then Mask:='*.*';
        Nm:='';
        OutFlush(True);GemCur(True);
        If FileSelect(T3('Select file','Choisir fichier','Datei waehlen'),Mask,Nm) Then Begin
         For I:=1 To Length(Nm) Do If Nm[I]='/' Then Nm[I]:='\';
         J:=0;
         For I:=1 To Length(Nm) Do If Nm[I]='\' Then J:=I;
         S:=Copy(Nm,1,J);
         If S<>'' Then Dir:=S;
         S2:=Copy(Nm,J+1,100);
         S:=Dir+Mask;
         For I:=1 To Length(S) Do WB(AA(0)+I-1,Ord(S[I]));WB(AA(0)+Length(S),0);
         For I:=1 To Length(S2) Do WB(AA(1)+I-1,Ord(S2[I]));WB(AA(1)+Length(S2),0);
         IO(1,1);
        End Else IO(1,0);
        GemRefresh(0,0,640,400,True);
       End;
      End;
  { ---------------- wind ---------------- }
  100: Begin
        I:=NewGWin;
        If I<0 Then IO(0,-1) Else Begin
         GW[I].Kind:=IW(0);GW[I].Title:='';GW[I].Info:='';
         DeskRect(X1,Y1,W1,H1);
         GW[I].MX:=IW(1);GW[I].MY:=IW(2);GW[I].MW:=IW(3);GW[I].MH:=IW(4);
         If (GW[I].MW<=0) Or (GW[I].MH<=0) Then Begin GW[I].MX:=0;GW[I].MY:=Y1;GW[I].MW:=W1;GW[I].MH:=H1;End;
         GW[I].HS:=0;GW[I].VS:=0;GW[I].HSz:=1000;GW[I].VSz:=1000;
         IO(0,I);
        End;
       End;
  101: Begin
        I:=IW(0);
        If (I>=1) And (I<=MAXGW) And GW[I].Used Then Begin
         WinOpen(I,IW(1),IW(2),IW(3),IW(4));IO(0,1);
        End Else IO(0,0);
       End;
  102: Begin I:=IW(0);If (I>=1) And (I<=MAXGW) And GW[I].Used Then WinClose(I);End;
  103: Begin
        I:=IW(0);
        If (I>=1) And (I<=MAXGW) And GW[I].Used Then Begin
         If GW[I].Open Then WinClose(I);
         GW[I].Used:=False;
        End;
       End;
  104: Begin
        I:=IW(0);J:=IW(1);
        X1:=0;Y1:=0;W1:=0;H1:=0;
        If (I>=1) And (I<=MAXGW) And GW[I].Used Then Begin
         Case J Of
          4: WinWork(I,X1,Y1,W1,H1);
          5: Begin X1:=GW[I].X;Y1:=GW[I].Y;W1:=GW[I].W;H1:=GW[I].H;End;
          6: Begin X1:=GW[I].PX;Y1:=GW[I].PY;W1:=GW[I].PW;H1:=GW[I].PH;End;
          7: Begin X1:=GW[I].MX;Y1:=GW[I].MY;W1:=GW[I].MW;H1:=GW[I].MH;End;
          8: X1:=GW[I].HS;
          9: X1:=GW[I].VS;
          10: Begin X1:=TopWin;If X1<0 Then X1:=0;End;
          11: Begin
               BuildRects(I);
               RectOut(IntOut+2,IntOut+4,IntOut+6,IntOut+8);
               X1:=GetW(IntOut+2);Y1:=GetW(IntOut+4);W1:=GetW(IntOut+6);H1:=GetW(IntOut+8);
              End;
          12: Begin
               RectOut(IntOut+2,IntOut+4,IntOut+6,IntOut+8);
               X1:=GetW(IntOut+2);Y1:=GetW(IntOut+4);W1:=GetW(IntOut+6);H1:=GetW(IntOut+8);
              End;
          15: X1:=GW[I].HSz;
          16: X1:=GW[I].VSz;
          1: X1:=GW[I].Kind;
         End;
        End Else Begin
         If J=4 Then DeskRect(X1,Y1,W1,H1)
         Else If J=7 Then Begin X1:=0;Y1:=0;W1:=640;H1:=400;End
         Else If J=10 Then Begin X1:=TopWin;If X1<0 Then X1:=0;End
         Else If J=11 Then Begin
          DeskRect(X1,Y1,W1,H1);
         End;
         If (J=11) Or (J=12) Then Begin If J=12 Then Begin W1:=0;H1:=0;End;End;
        End;
        IO(1,X1);IO(2,Y1);IO(3,W1);IO(4,H1);
        If RtTrace Then Begin WriteLn(ErrOutput,'   wind_get(',I,',',J,') ->',X1,',',Y1,',',W1,',',H1);Flush(ErrOutput);End;
       End;
  105: Begin
        I:=IW(0);J:=IW(1);
        If (I>=1) And (I<=MAXGW) And GW[I].Used Then Begin
         Case J Of
          2: Begin
              A:=(LongInt(IW(2)) And $FFFF) Shl 16 Or (LongInt(IW(3)) And $FFFF);
              GW[I].Title:=Copy(CStrAt(A),1,80);
              If GW[I].Open Then GemRefresh(GW[I].X,GW[I].Y,GW[I].W,20,False);
             End;
          3: Begin
              A:=(LongInt(IW(2)) And $FFFF) Shl 16 Or (LongInt(IW(3)) And $FFFF);
              GW[I].Info:=Copy(CStrAt(A),1,80);
              If GW[I].Open Then GemRefresh(GW[I].X,GW[I].Y,GW[I].W,GW[I].H,False);
             End;
          5: WinSetSize(I,IW(2),IW(3),IW(4),IW(5));
          8: Begin GW[I].HS:=IW(2);If GW[I].Open Then GemRefresh(GW[I].X,GW[I].Y,GW[I].W,GW[I].H,False);End;
          9: Begin GW[I].VS:=IW(2);If GW[I].Open Then GemRefresh(GW[I].X,GW[I].Y,GW[I].W,GW[I].H,False);End;
          10: WinToFront(I);
          15: Begin GW[I].HSz:=IW(2);If GW[I].Open Then GemRefresh(GW[I].X,GW[I].Y,GW[I].W,GW[I].H,False);End;
          16: Begin GW[I].VSz:=IW(2);If GW[I].Open Then GemRefresh(GW[I].X,GW[I].Y,GW[I].W,GW[I].H,False);End;
         End;
        End;
        IO(0,1);
       End;
  106: Begin
        H:=HitWin(IW(0),IW(1));
        If H<0 Then H:=0;
        IO(0,H);
       End;
  107: IO(0,1);
  108: Begin
        { wind_calc : type, genre, x, y, l, h }
        K:=IW(1);X1:=IW(2);Y1:=IW(3);W1:=IW(4);H1:=IW(5);
        R1.X:=0;R1.Y:=0;
        If IW(0)=0 Then Begin
         { de la zone de travail vers la bordure }
         W1:=W1+2;H1:=H1+2;X1:=X1-1;Y1:=Y1-1;
         If (K And $E)<>0 Then Begin H1:=H1+19;Y1:=Y1-19;End;
         If (K And $10)<>0 Then Begin H1:=H1+19;Y1:=Y1-19;End;
         If HasV(K) Then W1:=W1+18;
         If HasH(K) Then H1:=H1+18;
        End Else Begin
         W1:=W1-2;H1:=H1-2;X1:=X1+1;Y1:=Y1+1;
         If (K And $E)<>0 Then Begin H1:=H1-19;Y1:=Y1+19;End;
         If (K And $10)<>0 Then Begin H1:=H1-19;Y1:=Y1+19;End;
         If HasV(K) Then W1:=W1-18;
         If HasH(K) Then H1:=H1-18;
         If W1<0 Then W1:=0;
         If H1<0 Then H1:=0;
        End;
        IO(1,X1);IO(2,Y1);IO(3,W1);IO(4,H1);
       End;
  { ---------------- rsrc ---------------- }
  110: Begin
        S:=CStrAt(AA(0));
        I:=RscRead(S);
        If I>0 Then Begin RscCur:=I;IO(0,1);End Else IO(0,0);
       End;
  111: Begin
        If RscCur>0 Then Begin Rsc[RscCur].Used:=False;RscCur:=0;End;
        IO(0,1);
       End;
  112: Begin
        A:=RscGAddr(IW(0),IW(1));
        WL(AddrOut,A);
        If A<>0 Then IO(0,1) Else IO(0,0);
       End;
  113: Begin IO(0,1);End;
  114: Begin ObFix(OAd(AA(0),IW(0)));IO(0,1);End;
  { ---------------- shel ---------------- }
  120: Begin
        S:=CurPrgName;
        For I:=1 To Length(S) Do WB(AA(0)+I-1,Ord(S[I]));WB(AA(0)+Length(S),0);
        A:=RB(M_BASEPAGE+$80);
        For I:=0 To A Do WB(AA(1)+I,RB(M_BASEPAGE+$80+I));
        WB(AA(1)+A+1,0);
        IO(0,1);
       End;
  121: Begin
        If IW(0)<>0 Then Begin
         PendExec:=CStrAt(AA(0));
         PendTail:='';
         A:=RB(AA(1));
         For I:=1 To A Do PendTail:=PendTail+Chr(RB(AA(1)+I));
        End;
        IO(0,1);
       End;
  { ---------------- appl (suite) ---------------- }
  16: Begin
       { appl_bvset : unites disponibles pour le selecteur de fichiers }
       BvDisk:=RW(IntIn) Or (LongInt(RW(IntIn+2)) Shl 16);
       BvHard:=RW(IntIn+4) Or (LongInt(RW(IntIn+6)) Shl 16);
       IO(0,1);
      End;
  17: IO(0,1);
  18: Begin
       { appl_search(mode,nom,type,id) : cette seule application }
       If IW(0)=2 Then IO(0,0)
       Else Begin
        If IW(0)=0 Then AesSearchPos:=0;
        If AesSearchPos=0 Then Begin
         S:=CurPrgName;
         If Pos('.',S)>0 Then S:=Copy(S,1,Pos('.',S)-1);
         While Length(S)<8 Do S:=S+' ';
         For I:=1 To 8 Do WB(AA(0)+I-1,Ord(S[I]));WB(AA(0)+8,0);
         IO(0,1);IO(1,2);IO(2,0);AesSearchPos:=1;
        End Else IO(0,0);
       End;
      End;
  36: Begin
       { menu_popup(me_menu,xpos,ypos,me_mdata) }
       A:=AA(0);B:=AA(1);
       I:=AesPopup(RL(A),SmallInt(RW(A+4)),IW(0),IW(1));
       If RtTrace Then Begin WriteLn(ErrOutput,'popup A=$',HexStr(A,16),' B=$',HexStr(B,16),' res=',I);Flush(ErrOutput);End;
       If I>=0 Then Begin
        WL(B,RL(A));WW(B+4,RW(A+4));WW(B+6,Word(I));WW(B+8,0);WW(B+10,0);
        IO(0,1);
       End Else IO(0,0);
      End;
  37,38: IO(0,1);
  39: IO(0,1);
  48: Begin
       { objc_sysvar(mode,quoi,val1,val2) }
       K:=IW(1);
       If (K<1) Or (K>6) Then IO(0,0)
       Else Begin
        If IW(0)=1 Then Begin ObjSysV[K,0]:=IW(2);ObjSysV[K,1]:=IW(3);End;
        IO(0,1);IO(1,ObjSysV[K,0]);IO(2,ObjSysV[K,1]);
       End;
      End;
  82: Begin ScrapPath:='';IO(0,1);End;
  109: Begin
        { wind_new : ferme et detruit toutes les fenetres }
        For I:=1 To MAXGW Do
         If GW[I].Used Then Begin
          If GW[I].Open Then WinClose(I);
          GW[I].Used:=False;
         End;
        IO(0,1);
       End;
  115: Begin
        { rsrc_rcfix : ressource deja en memoire }
        A:=AA(0);
        If A=0 Then IO(0,0)
        Else Begin
         K:=RscFixMem(A,RW(A+34));
         If K=0 Then IO(0,0) Else Begin RscCur:=K;IO(0,1);End;
        End;
       End;
  126: Begin
        S:=ShelDefCmd;For I:=1 To Length(S) Do WB(AA(0)+I-1,Ord(S[I]));WB(AA(0)+Length(S),0);
        S:=ShelDefDir;For I:=1 To Length(S) Do WB(AA(1)+I-1,Ord(S[I]));WB(AA(1)+Length(S),0);
        IO(0,1);
       End;
  127: Begin ShelDefCmd:=CStrAt(AA(0));ShelDefDir:=CStrAt(AA(1));IO(0,1);End;
  130: Begin
        { appl_getinfo(type) : renseignements sur l'AES }
        IO(0,1);IO(1,0);IO(2,0);IO(3,0);IO(4,0);
        Case IW(0) Of
         0: Begin IO(1,10);IO(2,1);IO(3,0);End;
         1: Begin IO(1,8);IO(2,1);IO(3,0);End;
         2: IO(1,2);
         3: IO(1,2);
         4: Begin IO(2,1);IO(3,1);IO(4,1);End;
         5: IO(4,1);
         6: IO(1,13);
         7: IO(1,1);
         8: Begin IO(1,1);IO(2,1);IO(3,1);IO(4,1);End;
         10,11: IO(1,$FFF);
         9,12,13: ;
        Else IO(0,0);
        End;
       End;
  122,123: IO(0,1);
  124: Begin
        S:=CStrAt(AA(0));
        If FileExists(ResolveFile(TosToHost(S))) Then IO(0,1) Else IO(0,0);
       End;
  125: Begin WL(AA(0),0);IO(0,1);End;
 Else
  If RtTrace Then Begin WriteLn(ErrOutput,'AES non implemente : ',Op);Flush(ErrOutput);End;
  IO(0,0);
 End;
 SvC:=False;Dir:='';Nm:='';R3.X:=0;
End;
{$ENDIF}
{$IFDEF FPC}

{ ====================================================================== }
{              LIGNE A : VARIABLES, POLICES SYSTEME, PRIMITIVES          }
{ ====================================================================== }

Const
 LA_HDR   = $19000;       { 3 en-tetes de police de 88 octets }
 LA_OFF   = $19200;       { tables des decalages }
 LA_DAT16 = $19800;       { police 8x16 : 16 lignes de 256 octets }
 LA_DAT8  = $1A800;       { police 8x8 : 8 lignes de 256 octets }
 LA_PTRS  = $1B800;       { tableau des pointeurs de polices }
 LA_FUNC  = $1B840;       { tableau des routines (pointent sur un RTS) }
 LA_RTS   = $1B8C0;

Var
 LaInit : Boolean;

Procedure LaFontHeader(Hd: LongInt; Id,Pt,Hei,Asc,Half,Desc: Integer; Off,Dat: LongInt; Name: String);
Var I: Integer;
Begin
 FillChar(VMem[Hd],88,0);
 WW(Hd,Id);WW(Hd+2,Pt);
 For I:=1 To Length(Name) Do WB(Hd+3+I-1+1,Ord(Name[I]));
 WW(Hd+36,0);WW(Hd+38,255);
 WW(Hd+40,Asc);WW(Hd+42,Asc);WW(Hd+44,Half);WW(Hd+46,Desc);WW(Hd+48,Desc);
 WW(Hd+50,8);WW(Hd+52,8);WW(Hd+54,0);WW(Hd+56,0);
 WW(Hd+58,1);WW(Hd+60,1);WW(Hd+62,$5555);WW(Hd+64,$5555);WW(Hd+66,13);
 WL(Hd+68,0);WL(Hd+72,Off);WL(Hd+76,Dat);
 WW(Hd+80,256);WW(Hd+82,Hei);WL(Hd+84,0);
End;

Procedure LaSetup;
Var C,R,I: Integer;
Begin
 LaInit:=True;
 { donnees des polices (lignes de 256 octets : un octet par caractere) }
 For C:=0 To 255 Do Begin
  For R:=0 To 15 Do WB(LA_DAT16+R*256+C,Font8[C,R Div 2]);
  For R:=0 To 7 Do WB(LA_DAT8+R*256+C,Font8[C,R]);
 End;
 { table des decalages commune aux trois polices : 257 mots, le caractere c commence a la colonne 8*c }
 For I:=0 To 256 Do WW(LA_OFF+I*2,I*8);
 LaFontHeader(LA_HDR,1,10,16,12,8,3,LA_OFF,LA_DAT16,'System font');
 LaFontHeader(LA_HDR+88,1,9,8,6,4,1,LA_OFF,LA_DAT8,'System font');
 LaFontHeader(LA_HDR+176,1,8,8,6,4,1,LA_OFF,LA_DAT8,'System font');
 WL(LA_PTRS,LA_HDR+176);WL(LA_PTRS+4,LA_HDR+88);WL(LA_PTRS+8,LA_HDR);WL(LA_PTRS+12,0);
 WW(LA_RTS,$4E75);
 For I:=0 To 15 Do WL(LA_FUNC+I*4,LA_RTS);
 { variables : positives puis negatives par rapport a A0 }
 FillChar(VMem[M_LINEA-$300],$400,0);
 WW(M_LINEA,1);WW(M_LINEA+2,80);
 WW(M_LINEA+36,1);
 WW(M_LINEA+56,0);WW(M_LINEA+58,0);WW(M_LINEA+60,639);WW(M_LINEA+62,399);
 WL(M_LINEA+84,LA_HDR);WW(M_LINEA+88,256);
 WW(M_LINEA+106,1);WW(M_LINEA+114,0);
 WW(M_LINEA-$2E,16);WW(M_LINEA-$2C,79);WW(M_LINEA-$2A,24);WW(M_LINEA-$28,1280);
 WW(M_LINEA-$26,0);WW(M_LINEA-$24,1);WL(M_LINEA-$22,M_SCREEN);
 WL(M_LINEA-$16,LA_DAT16);WW(M_LINEA-$12,255);WW(M_LINEA-$10,0);WW(M_LINEA-$E,256);
 WW(M_LINEA-$C,640);WL(M_LINEA-$A,LA_OFF);WW(M_LINEA-4,400);WW(M_LINEA-2,80);
End;

{ ------------------------- primitives de la ligne A -------------------- }

Function LaW(Off: Integer): Integer;
Begin LaW:=SmallInt(RW(M_LINEA+Off)); End;

Function LaClip(X,Y: LongInt): Boolean;
{ True si le point est visible (rectangle d'ecran et fenetre de clipping) }
Begin
 LaClip:=False;
 If (X<0) Or (Y<0) Or (X>639) Or (Y>399) Then Exit;
 If LaW(54)<>0 Then
  If (X<LaW(56)) Or (Y<LaW(58)) Or (X>LaW(60)) Or (Y>LaW(62)) Then Exit;
 LaClip:=True;
End;

{ pixel selon le mode d'ecriture (0 remplace, 1 transparent, 2 xor, 3 transparent inverse) ;
  Fg : le pixel fait partie du motif ; Col : couleur du premier plan }
Procedure LaPix(X,Y: LongInt; Fg: Boolean; Col: Integer);
Var C: Byte;
Begin
 If Not LaClip(X,Y) Then Exit;
 If (Col And 1)<>0 Then C:=1 Else C:=0;
 Case LaW(36) Of
  1: If Fg Then OPlot(X,Y,C);
  2: If Fg And (C<>0) Then Begin OXor:=True;OPlot(X,Y,1);OXor:=False;End;
  3: If Not Fg Then OPlot(X,Y,C);
 Else
  If Fg Then OPlot(X,Y,C) Else OPlot(X,Y,0);
 End;
End;

Procedure LaPut(X,Y: LongInt; C: Integer);
Begin
 LaPix(X,Y,True,C);
End;

{ bit du motif de remplissage en (X,Y) }
Function LaPat(X,Y: LongInt): Boolean;
Var P: LongInt; W: Word; M: Integer;
Begin
 P:=RL(M_LINEA+46);
 If P=0 Then Begin LaPat:=True;Exit;End;
 M:=LaW(50);
 W:=RW(P+2*(Y And M));
 LaPat:=((W Shr (15-(X And 15))) And 1)<>0;
End;

Procedure LaHLine(X1,X2,Y: LongInt);
Var X,T: LongInt;
Begin
 If X1>X2 Then Begin T:=X1;X1:=X2;X2:=T;End;
 For X:=X1 To X2 Do LaPix(X,Y,LaPat(X,Y),LaW(24));
End;

Procedure LaLine(X1,Y1,X2,Y2: LongInt);
Var DX,DY,SX,SY,Err,E2,N: LongInt; Mask: Word;
Begin
 Mask:=Word(LaW(34));
 DX:=Abs(X2-X1);DY:=Abs(Y2-Y1);
 If X1<X2 Then SX:=1 Else SX:=-1;
 If Y1<Y2 Then SY:=1 Else SY:=-1;
 Err:=DX-DY;N:=0;
 Repeat
  LaPix(X1,Y1,((Mask Shr (15-(N And 15))) And 1)<>0,LaW(24));
  Inc(N);
  If (X1=X2) And (Y1=Y2) Then Break;
  E2:=2*Err;
  If E2>-DY Then Begin Err:=Err-DY;X1:=X1+SX;End;
  If E2<DX Then Begin Err:=Err+DX;Y1:=Y1+SY;End;
 Until False;
End;

Procedure LaSpriteMouse(Form: LongInt);
Var I: Integer;
Begin
 CurHx:=SmallInt(RW(Form));CurHy:=SmallInt(RW(Form+2));CurKind:=1;
 For I:=0 To 15 Do Begin CurMask[I]:=RW(Form+10+I*2);CurData[I]:=RW(Form+42+I*2);End;
 If ProgMouse And (Not Headless) Then Begin HideMouse;ShowMouse;End;
End;

{ TEXTBLT : un caractere de la forme de police vers l'ecran avec tous les effets
  (gras, clair, italique, souligne, contour, ombre), l'echelle et la rotation }
Procedure LaTextBlt;
Const OFSX = 40; MAXC = 160;
Var Fb,Fw: LongInt; SX,SY,DX,DY,W,H,I,J,K,R,C,Sty,Wt,Lm,Sk,Ro,Lo,Fg,Bg,Up,Mode: Integer;
    G1,G2: Array[0..95,0..MAXC-1] Of Byte;       { lignes x colonnes (decalage OFSX) }
    Wn: Integer; Mk: Word; Sh,Cnt,Dir,Yd,Xd,Kx,Ky,Ry: Integer; Inc_,AccX,AccY: LongInt; B: Byte;
    DstW,DstH,ExL,ExR: Integer;
 Function Src(Jj,Ii: Integer): Byte;
 Begin
  If (Ii<0) Or (Ii>=W) Or (Jj<0) Or (Jj>=H) Then Begin Src:=0;Exit;End;
  Src:=Ord((RB(Fb+(SY+Jj)*Fw+((SX+Ii) Shr 3)) And (128 Shr ((SX+Ii) And 7)))<>0);
 End;
 Procedure Emit(Xo,Yo: Integer; V: Byte);
 { ecrit le point (colonne Xo, ligne Yo) du glyphe compose, en tenant compte de la rotation }
 Var PxX,PxY: Integer;
 Begin
  Case LaW(104) Of
   900: Begin PxX:=DX+Yo;PxY:=DY-Xo;End;
   1800: Begin PxX:=DX-Xo;PxY:=DY-Yo;End;
   2700: Begin PxX:=DX-Yo;PxY:=DY+Xo;End;
  Else Begin PxX:=DX+Xo;PxY:=DY+Yo;End;
  End;
  If Not LaClip(PxX,PxY) Then Exit;
  Case LaW(36) Of
   1: If V<>0 Then OPlot(PxX,PxY,Fg And 1);
   2: If (V<>0) And ((Fg And 1)<>0) Then Begin OXor:=True;OPlot(PxX,PxY,1);OXor:=False;End;
   3: If V=0 Then OPlot(PxX,PxY,Fg And 1);
  Else
   If V<>0 Then OPlot(PxX,PxY,Fg And 1) Else OPlot(PxX,PxY,Bg And 1);
  End;
 End;
Begin
 Fb:=RL(M_LINEA+84);Fw:=LaW(88);
 SX:=LaW(72);SY:=LaW(74);DX:=LaW(76);DY:=LaW(78);W:=LaW(80);H:=LaW(82);
 Sty:=LaW(90);Wt:=LaW(96);Lm:=LaW(92);Sk:=LaW(94);Ro:=LaW(98);Lo:=LaW(100);
 Fg:=LaW(106);Bg:=LaW(114);
 If (W<=0) Or (H<=0) Or (W>64) Or (H>64) Then Exit;
 FillChar(G1,SizeOf(G1),0);FillChar(G2,SizeOf(G2),0);
 { etendue de la cellule : -LOFF .. largeur + epaisseur + ROFF (+1 de chaque cote pour le contour, +1 a droite pour l'ombre) }
 If (Sty And 1)=0 Then Wt:=0;
 If Ro<0 Then Ro:=0;
 If Lo<0 Then Lo:=0;
 ExL:=-Lo;ExR:=W+Wt+Ro;
 If (Sty And 16)<>0 Then Begin Dec(ExL);Inc(ExR);End;
 If (Sty And 32)<>0 Then Inc(ExR);
 If ExL<-OFSX+1 Then ExL:=-OFSX+1;
 If ExR>MAXC-OFSX-1 Then ExR:=MAXC-OFSX-1;
 { 1. glyphe source }
 For J:=0 To H-1 Do For I:=0 To W-1 Do G1[J,I+OFSX]:=Src(J,I);
 { 2. gras : chaque point est repete sur Wt colonnes a sa droite }
 If (Sty And 1)<>0 Then Begin
  If Wt<0 Then Wt:=0;
  For J:=0 To H-1 Do
   For I:=0 To MAXC-1 Do
    If G1[J,I]<>0 Then
     For K:=0 To Wt Do If I+K<MAXC Then G2[J,I+K]:=1;
  G1:=G2;FillChar(G2,SizeOf(G2),0);
 End;
 { 3. clair : masque tourne d'un bit a chaque ligne }
 If (Sty And 2)<>0 Then Begin
  Mk:=Word(Lm);
  For J:=0 To H-1 Do Begin
   For I:=0 To MAXC-1 Do
    If ((Mk Shr (15-((I-OFSX+16000) And 15))) And 1)=0 Then G1[J,I]:=0;
   Mk:=Word((Mk Shl 1) Or (Mk Shr 15));
  End;
 End;
 { 4. italique : decalage par ligne, de Ro au sommet vers -Lo en bas }
 If (Sty And 4)<>0 Then Begin
  Mk:=Word(Sk);Sh:=Ro;
  For J:=0 To H-1 Do Begin
   For I:=0 To MAXC-1 Do
    If G1[J,I]<>0 Then Begin
     K:=I+Sh;
     If (K>=0) And (K<MAXC) Then G2[J,K]:=1;
    End;
   If (Mk And $8000)<>0 Then Dec(Sh);
   Mk:=Word((Mk Shl 1) Or (Mk Shr 15));
  End;
  G1:=G2;FillChar(G2,SizeOf(G2),0);
 End;
 { 5. contour : bord du glyphe seulement }
 If (Sty And 16)<>0 Then Begin
  For J:=0 To H-1 Do
   For I:=1 To MAXC-2 Do
    If G1[J,I]=0 Then Begin
     Cnt:=0;
     For R:=-1 To 1 Do For C:=-1 To 1 Do
      If (J+R>=0) And (J+R<H) And (G1[J+R,I+C]<>0) Then Cnt:=1;
     G2[J,I]:=Cnt;
    End;
  G1:=G2;FillChar(G2,SizeOf(G2),0);
 End;
 { 6. ombre : copie decalee d'un point, en trame }
 If (Sty And 32)<>0 Then Begin
  For J:=0 To H-1 Do
   For I:=0 To MAXC-1 Do Begin
    G2[J,I]:=G1[J,I];
    If (J>0) And (I>0) And (G1[J-1,I-1]<>0) And (G1[J,I]=0) And (((I+J) And 1)=0) Then G2[J,I]:=1;
   End;
  G1:=G2;FillChar(G2,SizeOf(G2),0);
 End;
 { 7. souligne : derniere ligne }
 If (Sty And 8)<>0 Then For I:=0 To MAXC-1 Do If (I>=OFSX-Lo) And (I<OFSX+W+Wt+Ro) Then G1[H-1,I]:=1;
 { 8. ecriture avec echelle (accumulateur DDA) }
 DstH:=0;
 If LaW(102)=0 Then Begin
  For J:=0 To H-1 Do
   For I:=ExL To ExR-1 Do Emit(I,J,G1[J,I+OFSX]);
 End Else Begin
  Dir:=LaW(68);Inc_:=LaW(66) And $FFFF;
  Yd:=0;AccY:=LaW(64) And $FFFF;
  For J:=0 To H-1 Do Begin
   AccY:=AccY+Inc_;
   If AccY>65535 Then Begin AccY:=AccY-65536;Ky:=1;End Else Ky:=0;
   If Dir=0 Then Ky:=1+Ky Else Ky:=1-Ky;
   For Ry:=1 To Ky Do Begin
    Xd:=ExL;AccX:=LaW(64) And $FFFF;
    For I:=ExL To ExR-1 Do Begin
     B:=G1[J,I+OFSX];
     AccX:=AccX+Inc_;
     If AccX>65535 Then Begin AccX:=AccX-65536;Kx:=1;End Else Kx:=0;
     If Dir=0 Then Kx:=1+Kx Else Kx:=1-Kx;
     For R:=1 To Kx Do Begin Emit(Xd,Yd,B);Inc(Xd);End;
    End;
    Inc(Yd);
   End;
  End;
 End;
 OutPending:=True;
End;

Procedure LineA(Op: Word);
Var Fn: Integer; X1,Y1,X2,Y2,X,Y,I,J,K,N: LongInt; Pt,Pn,Ct: LongInt; Col: Integer; B: LongInt;
    W,H,SF,DF,SNL,DNL,SNW,DNW,SX,SY,DX,DY,Opr,S,D,R: LongInt; Fg,Bg: Integer;
    XI: Array[0..63] Of LongInt; Cnt: Integer; Mf1,Mf2,Fb,Fw: LongInt; Sv: Integer;
    Sa,Sb,Sl: LongInt; Fm: LongInt; Mk,Dt: Word; PA,PNL,PMK: LongInt;
 Function SrcBit(Frm,Nxw,Nxl,PX,PY: LongInt): Integer;
 Var A: LongInt;
 Begin
  A:=Frm+PY*Nxl+(PX Shr 4)*Nxw+((PX And 15) Shr 3);
  SrcBit:=Ord((RB(A) And (128 Shr (PX And 7)))<>0);
 End;
 Procedure PutBit(Frm,Nxw,Nxl,PX,PY: LongInt; V: Integer);
 Var A: LongInt;
 Begin
  A:=Frm+PY*Nxl+(PX Shr 4)*Nxw+((PX And 15) Shr 3);
  If V<>0 Then WB(A,RB(A) Or (128 Shr (PX And 7))) Else WB(A,RB(A) And (Not (128 Shr (PX And 7))));
 End;
Begin
 If Not LaInit Then LaSetup;
 Fn:=Op And $FFF;
 If RtTrace Then Begin WriteLn(ErrOutput,'LINE-A $A',Fn);Flush(ErrOutput);End;
 Case Fn Of
  0: Begin
      RD[0]:=M_LINEA;RA[0]:=M_LINEA;RA[1]:=LA_PTRS;RA[2]:=LA_FUNC;
     End;
  1: Begin
      Pt:=RL(M_LINEA+12);Pn:=RL(M_LINEA+8);
      LaPix(SmallInt(RW(Pt)),SmallInt(RW(Pt+2)),True,SmallInt(RW(Pn)));
     End;
  2: Begin
      Pt:=RL(M_LINEA+12);
      RD[0]:=OGet(SmallInt(RW(Pt)),SmallInt(RW(Pt+2)));
     End;
  3: LaLine(LaW(38),LaW(40),LaW(42),LaW(44));
  4: LaHLine(LaW(38),LaW(42),LaW(40));
  5: Begin
      Y1:=LaW(40);Y2:=LaW(44);
      If Y1>Y2 Then Begin Y:=Y1;Y1:=Y2;Y2:=Y;End;
      For Y:=Y1 To Y2 Do LaHLine(LaW(38),LaW(42),Y);
     End;
  6: Begin
      { une ligne de balayage (Y1) d'un polygone : points dans PTSIN }
      Ct:=RL(M_LINEA+4);Pt:=RL(M_LINEA+12);
      Cnt:=SmallInt(RW(Ct+2));
      If Cnt>60 Then Cnt:=60;
      Y:=LaW(40);N:=0;
      For I:=0 To Cnt-1 Do Begin
       J:=I+1;If J>=Cnt Then J:=0;
       X1:=SmallInt(RW(Pt+I*4));Y1:=SmallInt(RW(Pt+I*4+2));
       X2:=SmallInt(RW(Pt+J*4));Y2:=SmallInt(RW(Pt+J*4+2));
       If ((Y1<=Y) And (Y2>Y)) Or ((Y2<=Y) And (Y1>Y)) Then Begin
        If N<63 Then Begin XI[N]:=Round(X1+(Y-Y1)*(X2-X1)/(Y2-Y1));Inc(N);End;
       End;
      End;
      For I:=1 To N-1 Do Begin
       K:=XI[I];J:=I-1;
       While (J>=0) And (XI[J]>K) Do Begin XI[J+1]:=XI[J];Dec(J);End;
       XI[J+1]:=K;
      End;
      I:=0;
      While I+1<N Do Begin LaHLine(XI[I],XI[I+1],Y);Inc(I,2);End;
     End;
  7: Begin
      { BITBLT : bloc de parametres en A6 (un plan) }
      B:=RA[6];
      W:=SmallInt(RW(B));H:=SmallInt(RW(B+2));
      Fg:=SmallInt(RW(B+6)) And 1;Bg:=SmallInt(RW(B+8)) And 1;
      SX:=SmallInt(RW(B+14));SY:=SmallInt(RW(B+16));SF:=RL(B+18);SNW:=SmallInt(RW(B+22));SNL:=SmallInt(RW(B+24));
      DX:=SmallInt(RW(B+28));DY:=SmallInt(RW(B+30));DF:=RL(B+32);DNW:=SmallInt(RW(B+36));DNL:=SmallInt(RW(B+38));
      Opr:=RB(B+10+(Fg Shl 1)+Bg);
      { demi-teinte : la source est combinee (ET) au motif }
      PA:=RL(B+42);PNL:=SmallInt(RW(B+46));PMK:=RW(B+50);
      { sens de copie choisi pour que le recouvrement ne detruise pas la source :
        lignes en sens inverse si on descend, colonnes en sens inverse si on va a droite sur la meme ligne }
      For K:=0 To H-1 Do Begin
       If DY>SY Then J:=H-1-K Else J:=K;
       For N:=0 To W-1 Do Begin
        If (DY=SY) And (DX>SX) Then I:=W-1-N Else I:=N;
        S:=SrcBit(SF,SNW,SNL,SX+I,SY+J);D:=SrcBit(DF,DNW,DNL,DX+I,DY+J);
        If PA<>0 Then S:=S And ((RW(PA+PNL*((DY+J) And PMK)) Shr (15-((DX+I) And 15))) And 1);
        PutBit(DF,DNW,DNL,DX+I,DY+J,VRop(Opr,S,D));
       End;
      End;
      OutPending:=True;
     End;
  8: LaTextBlt;
  9: GemCur(True);
  10: GemCur(False);
  11: Begin
       { transformation du curseur de souris : formulaire dans INTIN }
       LaSpriteMouse(RL(M_LINEA+8));
      End;
  12: Begin
       { efface un lutin : tampon en A2 (x, y, nombre de lignes, fond) }
       Sa:=RA[2];
       If RW(Sa+4)<>0 Then Begin
        X:=SmallInt(RW(Sa));Y:=SmallInt(RW(Sa+2));N:=RW(Sa+4);
        For J:=0 To N-1 Do
         For I:=0 To 15 Do
          If LaClip(X+I,Y+J) Then OPlot(X+I,Y+J,(RW(Sa+6+J*2) Shr (15-I)) And 1);
        WW(Sa+4,0);
        OutPending:=True;
       End;
      End;
  13: Begin
       { dessine un lutin : D0=x, D1=y, A0=formulaire, A2=tampon de sauvegarde }
       Fm:=RA[0];Sa:=RA[2];
       X:=SmallInt(RD[0] And $FFFF)-SmallInt(RW(Fm));Y:=SmallInt(RD[1] And $FFFF)-SmallInt(RW(Fm+2));
       { +6 : couleur du masque (fond), +8 : couleur des donnees (premier plan) }
       Bg:=SmallInt(RW(Fm+6)) And 1;Fg:=SmallInt(RW(Fm+8)) And 1;
       WW(Sa,X);WW(Sa+2,Y);WW(Sa+4,16);
       For J:=0 To 15 Do Begin
        Mk:=0;
        For I:=0 To 15 Do If LaClip(X+I,Y+J) Then Mk:=Mk Or (Word(OGet(X+I,Y+J)) Shl (15-I));
        WW(Sa+6+J*2,Mk);
       End;
       For J:=0 To 15 Do Begin
        Mk:=RW(Fm+10+J*4);Dt:=RW(Fm+12+J*4);
        For I:=0 To 15 Do
         If ((Mk Shr (15-I)) And 1)<>0 Then
          If LaClip(X+I,Y+J) Then Begin
           If ((Dt Shr (15-I)) And 1)<>0 Then OPlot(X+I,Y+J,Fg) Else OPlot(X+I,Y+J,Bg);
          End;
       End;
       OutPending:=True;
      End;
  14: Begin
       { copie de formulaire raster (comme vro_cpyfm / vrt_cpyfm) }
       Ct:=RL(M_LINEA+4);Pn:=RL(M_LINEA+8);Pt:=RL(M_LINEA+12);
       Mf1:=RL(Ct+14);Mf2:=RL(Ct+18);
       Sv:=VdCur;VdCur:=0;
       Vd[0].ClipOn:=(LaW(54)<>0);Vd[0].CX1:=LaW(56);Vd[0].CY1:=LaW(58);Vd[0].CX2:=LaW(60);Vd[0].CY2:=LaW(62);
       If LaW(116)<>0 Then
        VCpyFmT(SmallInt(RW(Pn)),Mf1,Mf2,SmallInt(RW(Pt)),SmallInt(RW(Pt+2)),SmallInt(RW(Pt+4)),SmallInt(RW(Pt+6)),
                SmallInt(RW(Pt+8)),SmallInt(RW(Pt+10)),LaW(106),LaW(114))
       Else
        VCpyFm(SmallInt(RW(Pn)),Mf1,Mf2,SmallInt(RW(Pt)),SmallInt(RW(Pt+2)),SmallInt(RW(Pt+4)),SmallInt(RW(Pt+6)),
               SmallInt(RW(Pt+8)),SmallInt(RW(Pt+10)));
       VdCur:=Sv;
       OutPending:=True;
      End;
  15: Begin
       { remplissage par germe : point dans PTSIN }
       Pt:=RL(M_LINEA+12);
       FilSty:=1;FilCol:=LaW(24) And 1;FilIdx:=1;
       If FilCol<>0 Then FilCol:=1;
       OFlood(SmallInt(RW(Pt)),SmallInt(RW(Pt+2)));
       OutPending:=True;
      End;
 End;
End;
{$ENDIF}
{$IFDEF FPC}

{ ====================================================================== }
{   BIOS / XBIOS COMPLEMENTAIRES (appeles avant les fonctions de base)    }
{ ====================================================================== }

Const
 BX_KBDV  = $1C000;        { table des vecteurs du clavier (9 longs) }
 BX_IOREC = $1C040;        { trois structures IOREC de 14 octets (RS232, clavier, MIDI) }
 BX_IOBUF = $1C100;        { tampons des IOREC (3 x 256 octets) }
 BX_KEYT  = $1C400;        { 3 tables de 128 octets (normal, Maj, Verr.Maj) + 1 table vide }

Var
 BxInit: Boolean;
 BxPal: Array[0..15] Of Integer;
 BxGi: Array[0..15] Of Byte;
 BxKbRate: Integer;
 BxPrt: Integer;
 BxRs: LongInt;

Procedure BxSetup;
Const Us1: String = #0#27'1234567890-=' + #8#9 + 'qwertyuiop[]' + #13#0 + 'asdfghjkl;''`' + #0'\' + 'zxcvbnm,./' + #0#0#0' ';
      Us2: String = #0#27'!@#$%^&*()_+' + #8#9 + 'QWERTYUIOP{}' + #13#0 + 'ASDFGHJKL:"~' + #0'|' + 'ZXCVBNM<>?' + #0#0#0' ';
Var I,K: Integer;
Begin
 BxInit:=True;
 FillChar(VMem[BX_KBDV],$40,0);
 For I:=0 To 8 Do WL(BX_KBDV+I*4,LA_RTS);
 FillChar(VMem[BX_IOREC],$C0,0);
 For I:=0 To 2 Do Begin
  WL(BX_IOREC+I*14,BX_IOBUF+I*256);WW(BX_IOREC+I*14+4,256);
  WW(BX_IOREC+I*14+10,64);WW(BX_IOREC+I*14+12,192);
 End;
 FillChar(VMem[BX_KEYT],$200,0);
 For K:=1 To Length(Us1) Do Begin
  WB(BX_KEYT+K,Ord(Us1[K]));WB(BX_KEYT+128+K,Ord(Us2[K]));
  If (Us1[K]>='a') And (Us1[K]<='z') Then WB(BX_KEYT+256+K,Ord(Us2[K])) Else WB(BX_KEYT+256+K,Ord(Us1[K]));
 End;
 WB(BX_KEYT+$39,32);WB(BX_KEYT+128+$39,32);WB(BX_KEYT+256+$39,32);
 For I:=0 To 15 Do BxPal[I]:=0;
 BxPal[0]:=$777;
 FillChar(BxGi,SizeOf(BxGi),0);
 BxGi[7]:=$FF;BxGi[14]:=$FF;
 BxKbRate:=$0F0F;BxPrt:=0;BxRs:=0;
End;

{ retourne True si la fonction BIOS est traitee ici }
Function BiosEx: Boolean;
Var Fn: Word; SP,A: LongInt; N: Word;
Begin
 BiosEx:=True;
 SP:=RA[7];
 Fn:=RW(SP);
 If Not BxInit Then BxSetup;
 Case Fn Of
  0: Begin
      { Getmpb : liste des blocs memoire }
      A:=RL(SP+2);WL(A,0);WL(A+4,0);WL(A+8,0);RD[0]:=0;
     End;
  5: Begin
      { Setexc(vecteur, nouvelle adresse) }
      N:=RW(SP+2);
      A:=RL(SP+4);
      If N<$200 Then Begin
       RD[0]:=RL(N*4);
       If A<>-1 Then WL(N*4,A);
      End Else RD[0]:=0;
     End;
  6: RD[0]:=20;                          { Tickcal : ms par tick }
  8: RD[0]:=-1;                          { Bcostat : toujours pret }
  11: Begin
       { Kbshift : etat des touches Maj, Ctrl, Alt }
       If RW(SP+2)=$FFFF Then RD[0]:=LastKbd And $F Else RD[0]:=LastKbd And $F;
      End;
 Else BiosEx:=False;
 End;
End;

{ retourne True si la fonction XBIOS est traitee ici }
Function XBiosEx: Boolean;
Var Fn: Word; SP,A: LongInt; I,V: Integer; Y,Mo,D,Dw,Hh,Mi,Se,Hs: Word;
Begin
 XBiosEx:=True;
 SP:=RA[7];
 Fn:=RW(SP);
 If Not BxInit Then BxSetup;
 Case Fn Of
  0: RD[0]:=0;                                   { Initmous }
  6: Begin
      { Setpalette }
      A:=RL(SP+2);
      For I:=0 To 15 Do BxPal[I]:=SmallInt(RW(A+I*2));
      RD[0]:=0;
     End;
  7: Begin
      { Setcolor(numero, couleur) : retourne l'ancienne }
      I:=RW(SP+2) And 15;
      RD[0]:=BxPal[I] And $FFFF;
      V:=SmallInt(RW(SP+4));
      If V>=0 Then BxPal[I]:=V And $777;
     End;
  14: Begin
       { Iorec : pointeur sur la structure IOREC du peripherique }
       I:=RW(SP+2);
       If I>2 Then I:=0;
       RD[0]:=BX_IOREC+I*14;
      End;
  15: Begin
       { Rsconf : ancienne configuration (non utilisee) }
       RD[0]:=BxRs;
      End;
  16: RD[0]:=BX_KEYT;                           { Keytbl (renvoie un pointeur sur la structure de 3 tables) }
  22: RD[0]:=0;                                  { Settime }
  23: Begin
       { Gettime : date et heure au format DOS }
       GetDate(Y,Mo,D,Dw);GetTime(Hh,Mi,Se,Hs);
       RD[0]:=((LongInt(Y)-1980) Shl 25) Or (LongInt(Mo) Shl 21) Or (LongInt(D) Shl 16) Or
              (LongInt(Hh) Shl 11) Or (LongInt(Mi) Shl 5) Or (LongInt(Se) Div 2);
      End;
  24: RD[0]:=0;                                  { Bioskeys }
  26,27: RD[0]:=0;                               { Jdisint / Jenabint }
  28: Begin
       { Giaccess(donnee, registre) }
       I:=RW(SP+4);
       If (I And $80)<>0 Then Begin
        BxGi[I And 15]:=RW(SP+2) And $FF;
        RD[0]:=BxGi[I And 15];
       End Else RD[0]:=BxGi[I And 15];
      End;
  29: Begin BxGi[14]:=BxGi[14] And (RW(SP+2) And $FF);RD[0]:=0;End;
  30: Begin BxGi[14]:=BxGi[14] Or (RW(SP+2) And $FF);RD[0]:=0;End;
  31: RD[0]:=0;                                  { Xbtimer }
  32: RD[0]:=0;                                  { Dosound }
  33: Begin
       { Setprt }
       RD[0]:=BxPrt;
       If SmallInt(RW(SP+2))>=0 Then BxPrt:=RW(SP+2);
      End;
  34: RD[0]:=BX_KBDV;                            { Kbdvbase }
  35: Begin
       { Kbrate }
       RD[0]:=BxKbRate;
       If SmallInt(RW(SP+2))>=0 Then BxKbRate:=(RW(SP+2) And $FF) Shl 8 Or (RW(SP+4) And $FF);
      End;
  36: RD[0]:=0;                                  { Prtblk }
 Else XBiosEx:=False;
 End;
End;
{$ENDIF}

{ ====================================================================== }
{       COMPILATEUR PERSONAL PASCAL -> 68000 : ANALYSE LEXICALE          }
{ ====================================================================== }

Const
 { jetons }
 T_EOF=0;  T_ID=1;   T_INT=2;  T_REAL=3; T_STR=4;
 T_PLUS=10;T_MINUS=11;T_STAR=12;T_SLASH=13;T_EQ=14;T_NE=15;T_LT=16;T_GT=17;
 T_LE=18;  T_GE=19;  T_LP=20;  T_RP=21;  T_LB=22; T_RB=23;T_DOT=24;T_COMMA=25;
 T_COLON=26;T_SEMI=27;T_CARET=28;T_ASSIGN=29;T_DOTDOT=30;T_AMP=31;T_BAR=32;
 T_TILDE=33;T_AT=34;
 K_AND=100;K_ARRAY=101;K_BEGIN=102;K_CASE=103;K_CONST=104;K_DIV=105;K_DO=106;
 K_DOWNTO=107;K_ELSE=108;K_END=109;K_FILE=110;K_FOR=111;K_FUNCTION=112;
 K_GOTO=113;K_IF=114;K_IN=115;K_LABEL=116;K_LOOP=117;K_MOD=118;K_NIL=119;
 K_NOT=120;K_OF=121;K_OR=122;K_OTHERWISE=123;K_PACKED=124;K_PROCEDURE=125;
 K_PROGRAM=126;K_RECORD=127;K_REPEAT=128;K_SET=129;K_THEN=130;K_TO=131;
 K_TYPE=132;K_UNTIL=133;K_VAR=134;K_WHILE=135;K_WITH=136;
 NKEY=37;

 MAXSRC = 12000;
 MAXERR = 60;

Type
 TKeyTab = Array[1..NKEY] Of String[10];

Const
 KeyWords : TKeyTab = ('AND','ARRAY','BEGIN','CASE','CONST','DIV','DO','DOWNTO',
  'ELSE','END','FILE','FOR','FUNCTION','GOTO','IF','IN','LABEL','LOOP','MOD',
  'NIL','NOT','OF','OR','OTHERWISE','PACKED','PROCEDURE','PROGRAM','RECORD',
  'REPEAT','SET','THEN','TO','TYPE','UNTIL','VAR','WHILE','WITH');

Type
 TCompOpts = Record
  ProgType  : Integer;      { 0 GEM, 1 TOS, 2 ACC }
  PauseErr  : Boolean;
  ChainLink : Boolean;
  FullDebug : Boolean;
  PrintList : Boolean;
  RangeChk  : Boolean;
  ClearVars : Boolean;
  StackChk  : Boolean;
 End;

 TErrRec = Record
  Line,Col,Num : Integer;
  Msg : String[100];
 End;

Var
 Conf    : TCompOpts;       { options (boite de dialogue) }
 Opt     : TCompOpts;       { options actives pendant la compilation (directives) }
 SpaceS,SpaceU : Integer;     (* directives S et U (Ko), -1 : absente *)
 LongIntOn : Boolean;       (* directive L+ : INTEGER devient LONG_INTEGER *)
 SrcL    : Array[1..MAXSRC] Of PString;
 SrcN    : Integer;
 IncL    : Array[1..3000] Of PString;
 IncN    : Integer;
 InInc   : Boolean;
 IncI    : Integer;
 CurLn   : Integer;         { ligne courante du fichier principal }
 CurTxt  : String;
 CurPos  : Integer;
 CurBase : String;          { nom du fichier source }
 Tok     : Integer;
 TokS    : String;
 TokI    : LongInt;
 TokR    : Double;
 TokLine,TokCol : Integer;
 PrevLine,PrevCol : Integer;
 CErrs   : Array[1..MAXERR] Of TErrRec;
 CErrN   : Integer;
 CHalt   : Boolean;          { compilation interrompue }
 CGoEdit : Boolean;          { l'utilisateur veut aller dans l'editeur }
 ListHook: Boolean;
 SrcFileName : String;
 ModuleMode,ExportOn : Boolean;
 ExpName : Array[1..60] Of String[8];
 ExpLab  : Array[1..60] Of Integer;
 ExpN    : Integer;
 ExtName : Array[1..60] Of String[8];
 ExtFirst,ExtCnt : Array[1..60] Of Integer;
 ExtN    : Integer;
 ExtPos  : Array[1..3000] Of LongInt;
 ExtPosN : Integer;

Function CompilerErrorHook(Line,Col,Num: Integer; Const Msg: String): Integer; Forward;
Procedure CompilerListHook(Ln: Integer; Const S: String); Forward;

Function ErrMsg(N: Integer): String;
Begin
 Case N Of
  1: ErrMsg:=T3('Identifier expected','Identificateur attendu','Bezeichner erwartet');
  3: ErrMsg:=T3('Undefined identifier','Identificateur non d'#130'fini','Unbekannter Bezeichner');
  4: ErrMsg:=T3('Duplicate identifier','Identificateur en double','Bezeichner doppelt');
  5: ErrMsg:=T3('Type mismatch','Types incompatibles','Typen unvertraeglich');
  6: ErrMsg:=T3('Illegal expression','Expression ill'#130'gale','Unerlaubter Ausdruck');
  7: ErrMsg:=T3('Constant expected','Constante attendue','Konstante erwartet');
  8: ErrMsg:=T3('Type expected','Type attendu','Typ erwartet');
  9: ErrMsg:=T3('Ordinal type expected','Type ordinal attendu','Ordinaltyp erwartet');
  10: ErrMsg:=T3('Boolean expression expected','Expression bool'#130'enne attendue','Boolescher Ausdruck erwartet');
  11: ErrMsg:=T3('Integer value expected','Valeur enti'#138're attendue','Ganzzahl erwartet');
  12: ErrMsg:=T3('Variable expected','Variable attendue','Variable erwartet');
  13: ErrMsg:=T3('Wrong number or type of parameters','Nombre ou type de param'#138'tres incorrect','Falsche Parameter');
  14: ErrMsg:=T3('Not a procedure','Ce n''est pas une proc'#130'dure','Keine Prozedur');
  15: ErrMsg:=T3('Unterminated string','Cha'#140'ne non termin'#130'e','String nicht beendet');
  16: ErrMsg:=T3('Unterminated comment','Commentaire non termin'#130,'Kommentar nicht beendet');
  17: ErrMsg:=T3('Illegal character','Caract'#138're ill'#130'gal','Unerlaubtes Zeichen');
  18: ErrMsg:=T3('Number too large','Nombre trop grand','Zahl zu gross');
  19: ErrMsg:=T3('Statement expected','Instruction attendue','Anweisung erwartet');
  20: ErrMsg:=T3('Label not declared','Etiquette non d'#130'clar'#130'e','Marke nicht deklariert');
  21: ErrMsg:=T3('Unexpected end of file','Fin de fichier inattendue','Unerwartetes Dateiende');
  22: ErrMsg:=T3('Unknown record field','Champ d''enregistrement inconnu','Unbekanntes Feld');
  23: ErrMsg:=T3('Not an array or string','Ce n''est pas un tableau','Kein Feld');
  24: ErrMsg:=T3('Not a pointer','Ce n''est pas un pointeur','Kein Zeiger');
  25: ErrMsg:=T3('Not a record','Ce n''est pas un enregistrement','Kein Verbund');
  26: ErrMsg:=T3('Program too large','Programme trop grand','Programm zu gross');
  27: ErrMsg:=T3('Branch too far','Saut trop loin','Sprung zu weit');
  28: ErrMsg:=T3('Include file not found','Fichier d''inclusion introuvable','Include-Datei fehlt');
  29: ErrMsg:=T3('Nested include not allowed','Inclusion imbriqu'#130'e interdite','Verschachteltes Include');
  30: ErrMsg:=T3('Invalid set element','El'#130'ment d''ensemble invalide','Ungueltiges Mengenelement');
  31: ErrMsg:=T3('Invalid string operation','Op'#130'ration de cha'#140'ne invalide','Ungueltige Stringoperation');
  32: ErrMsg:=T3('Invalid case label','Etiquette CASE invalide','Ungueltige CASE-Marke');
  33: ErrMsg:=T3('Forward declaration not resolved','D'#130'claration forward non r'#130'solue','Forward nicht aufgeloest');
  34: ErrMsg:=T3('Too many errors','Trop d''erreurs','Zu viele Fehler');
  35: ErrMsg:=T3('Illegal assignment','Affectation ill'#130'gale','Unerlaubte Zuweisung');
  36: ErrMsg:=T3('Division by zero','Division par z'#130'ro','Division durch Null');
  37: ErrMsg:=T3('Real value not allowed here','Valeur r'#130'elle interdite ici','Real hier nicht erlaubt');
  38: ErrMsg:=T3('Invalid file operation','Op'#130'ration de fichier invalide','Ungueltige Dateioperation');
  39: ErrMsg:=T3('Invalid type size','Taille de type invalide','Ungueltige Typgroesse');
  40: ErrMsg:=T3('Bad directive','Directive incorrecte','Falsche Direktive');
  41: ErrMsg:=T3('Too many symbols','Trop de symboles','Zu viele Symbole');
  42: ErrMsg:=T3('Value out of range','Valeur hors limites','Wert ausser Bereich');
  43: ErrMsg:=T3('Not a function','Ce n''est pas une fonction','Keine Funktion');
  44: ErrMsg:=T3('Illegal use of identifier','Utilisation ill'#130'gale de l''identificateur','Falsche Verwendung');
  45: ErrMsg:=T3('Procedure nesting too deep','Imbrication de proc'#130'dures trop profonde','Verschachtelung zu tief');
 Else ErrMsg:=T3('Syntax error','Erreur de syntaxe','Syntaxfehler');
 End;
End;

Procedure CompError(Num: Integer; Const Msg: String);
Var R: Integer;
Begin
 If CHalt Then Exit;
 If CErrN>=MAXERR Then Begin CHalt:=True;Exit;End;
 Inc(CErrN);
 CErrs[CErrN].Line:=TokLine;CErrs[CErrN].Col:=TokCol;
 CErrs[CErrN].Num:=Num;CErrs[CErrN].Msg:=Copy(Msg,1,100);
 R:=CompilerErrorHook(TokLine,TokCol,Num,Msg);
 If R>=2 Then Begin CHalt:=True;If R=3 Then CGoEdit:=True;End;
End;

Function PPNum(N: Integer): Integer;
{ numero d'erreur de Personal Pascal (fichier ERRORS.TXT) }
Begin
 Case N Of
  1: PPNum:=2;   3: PPNum:=104;  4: PPNum:=101;  5: PPNum:=145;  6: PPNum:=58;
  7: PPNum:=50;  8: PPNum:=10;   9: PPNum:=115;  10: PPNum:=135; 11: PPNum:=15;
  12: PPNum:=59; 13: PPNum:=126; 14: PPNum:=174; 15: PPNum:=202; 16: PPNum:=401;
  17: PPNum:=400; 18: PPNum:=203; 19: PPNum:=6;  20: PPNum:=167; 21: PPNum:=401;
  22: PPNum:=152; 23: PPNum:=138; 24: PPNum:=141; 25: PPNum:=140; 26: PPNum:=253;
  27: PPNum:=253; 28: PPNum:=403; 29: PPNum:=406; 30: PPNum:=136; 31: PPNum:=134;
  32: PPNum:=147; 33: PPNum:=117; 35: PPNum:=150; 36: PPNum:=300; 37: PPNum:=124;
  38: PPNum:=116; 39: PPNum:=398; 40: PPNum:=394; 41: PPNum:=250; 42: PPNum:=303;
  43: PPNum:=174; 44: PPNum:=103; 45: PPNum:=251;
 Else PPNum:=6;
 End;
End;

Function PPText(N: Integer): String;
Begin
 PPText:='';
 Case N Of
  2: PPText:='Identifier expected';
  10: PPText:='Error in type';
  15: PPText:='Integer expected';
  50: PPText:='Error in constant';
  58: PPText:='Error in <factor> (bad expression)';
  59: PPText:='Error in variable';
  101: PPText:='Identifier declared twice';
  103: PPText:='Identifier is not of the appropriate class';
  104: PPText:='Undeclared identifier';
  115: PPText:='Base type must be a scalar or a subrange';
  117: PPText:='Unsatisfied forward reference';
  124: PPText:='F-format for reals only';
  126: PPText:='Number of parameters does not agree with declaration';
  134: PPText:='Illegal type of operand(s)';
  135: PPText:='Type of operand must be boolean';
  136: PPText:='Set element type must be scalar or subrange';
  138: PPText:='Type of variable is not array';
  140: PPText:='Type of variable is not record';
  141: PPText:='Type of variable must be file or pointer';
  145: PPText:='Type conflict';
  147: PPText:='Label type incompatible with selecting expression';
  150: PPText:='Assignment to standard function is not allowed';
  152: PPText:='No such field in this record';
  167: PPText:='Undeclared label';
  174: PPText:='Pascal function or procedure expected';
  202: PPText:='String constant must not exceed source line';
  203: PPText:='Integer constant exceeds range';
  250: PPText:='Too many scopes of nested identifiers';
  251: PPText:='Too many nested procedures or functions';
  253: PPText:='Procedure too long';
  300: PPText:='Division by zero';
  303: PPText:='Value to be assigned is out of bounds';
  394: PPText:='GEMDOS, BIOS, XBIOS, C, EXTERNAL or FORWARD expected';
  398: PPText:='Implementation restriction';
  400: PPText:='Illegal character in text';
  401: PPText:='Unexpected end of input';
  403: PPText:='Error in reading include file';
  406: PPText:='Include file not legal';
 End;
End;

Procedure Err(N: Integer);
Var P: Integer; T: String;
Begin
 P:=PPNum(N);
 T:=ErrMsg(N);
 If (Lang=0) And (PPText(P)<>'') Then T:=PPText(P);
 CompError(P,T);
End;

Procedure ErrExp(Const What: String);
Var P: Integer; T: String;
Begin
 P:=6;
 If What=';' Then P:=14 Else If What=')' Then P:=4 Else If What=':' Then P:=5
 Else If What='OF' Then P:=8 Else If What='(' Then P:=9 Else If What='[' Then P:=11
 Else If What=']' Then P:=12 Else If What='END' Then P:=13 Else If What='=' Then P:=16
 Else If What='BEGIN' Then P:=17 Else If What='.' Then P:=20 Else If What=':=' Then P:=51
 Else If What='THEN' Then P:=52 Else If What='UNTIL' Then P:=53 Else If What='DO' Then P:=54;
 CompError(P,''''+What+''' '+T3('expected','attendu','erwartet'));
End;

{ ------------------------------ sources -------------------------------- }

Function LoadLines(Const Name: String; Include: Boolean): Boolean;
Var F: Text; S: String; Nm: String;
Begin
 LoadLines:=False;
 Nm:=ResolveFile(Name);
 If Not FileExists(Nm) Then Exit;
 Assign(F,Nm);
 {$I-}Reset(F);{$I+}
 If IOResult<>0 Then Exit;
 If Include Then IncN:=0 Else SrcN:=0;
 While Not Eof(F) Do Begin
  {$I-}ReadLn(F,S);{$I+}
  If IOResult<>0 Then Break;
  If Include Then Begin
   If IncN<3000 Then Begin Inc(IncN);IncL[IncN]:=NewStr(S);End;
  End Else Begin
   If SrcN<MAXSRC Then Begin Inc(SrcN);SrcL[SrcN]:=NewStr(S);End;
  End;
 End;
 Close(F);
 LoadLines:=True;
End;

Procedure FreeSource;
Var I: Integer;
Begin
 For I:=1 To SrcN Do FreeStr(SrcL[I]);
 For I:=1 To IncN Do FreeStr(IncL[I]);
 SrcN:=0;IncN:=0;
End;

Function ReadLineRaw(Var S: String): Boolean;
{ ligne suivante (inclusion ou source principal) }
Begin
 ReadLineRaw:=False;
 If InInc Then Begin
  If IncI<IncN Then Begin Inc(IncI);S:=IncL[IncI]^;ReadLineRaw:=True;Exit;End;
  InInc:=False;
 End;
 If CurLn<SrcN Then Begin
  Inc(CurLn);S:=SrcL[CurLn]^;ReadLineRaw:=True;
  If Opt.PrintList And ListHook Then CompilerListHook(CurLn,S);
 End;
End;

Function Peek1: Char;
Begin
 If CurPos<=Length(CurTxt) Then Peek1:=CurTxt[CurPos] Else Peek1:=#0;
End;

Function Peek2: Char;
Begin
 If CurPos+1<=Length(CurTxt) Then Peek2:=CurTxt[CurPos+1] Else Peek2:=#0;
End;

Function NextLineOk: Boolean;
Var S: String;
Begin
 If ReadLineRaw(S) Then Begin CurTxt:=S;CurPos:=1;NextLineOk:=True;End
 Else NextLineOk:=False;
End;

Procedure Directive(Const D: String);
{ D = texte entre {$ et } }
Var C: Char; S: String; I,N: Integer; On: Boolean; Nm,Bn,Dir0: String;
Begin
 S:=D;
 If S='' Then Exit;
 C:=UpCase(S[1]);
 If (C='I') And (Length(S)>1) And (S[2]<>'+') And (S[2]<>'-') Then Begin
  Nm:=TrimStr(Copy(S,2,100));
  If InInc Then Begin Err(29);Exit;End;
  Bn:=ShortName(Nm);
  If Pos('.',Bn)=0 Then Bn:=Bn+'.PAS';
  Dir0:=Copy(SrcFileName,1,Length(SrcFileName)-Length(ShortName(SrcFileName)));
  If LoadLines(Dir0+Bn,True) Or LoadLines(Bn,True) Or LoadLines(Nm,True) Then Begin InInc:=True;IncI:=0;End
  Else If (Upper(Bn)='GEMSUBS.PAS') Or (Upper(Bn)='AUXSUBS.PAS') Or
          (Upper(Bn)='GEMCONST.PAS') Or (Upper(Bn)='GEMTYPE.PAS') Then Begin
   { bibliotheque integree }
  End Else Err(28);
  Exit;
 End;
 I:=1;
 While I<=Length(S) Do Begin
  C:=UpCase(S[I]);
  If (C>='A') And (C<='Z') Then Begin
   On:=True;
   If (I<Length(S)) And (S[I+1]='-') Then On:=False;
   Case C Of
    'R': Opt.RangeChk:=On;
    'P': Opt.StackChk:=On;
    'C': Opt.ClearVars:=On;
    'D': Opt.FullDebug:=On;
    'A': If On Then Opt.ProgType:=2;
    'M': ModuleMode:=On;
    'L': LongIntOn:=On;
    'E': ExportOn:=On;
    'T': Opt.StackChk:=On;
    'S','U': Begin
      N:=0;
      While (I<Length(S)) And (S[I+1]>='0') And (S[I+1]<='9') Do Begin N:=N*10+Ord(S[I+1])-48;Inc(I);End;
      If C='S' Then Begin
       If SpaceU>=0 Then Err(40) Else SpaceS:=N;
      End Else Begin
       If SpaceS>=0 Then Err(40) Else SpaceU:=N;
      End;
     End;
   End;
  End;
  Inc(I);
 End;
End;

Procedure SkipBlanks;
Var C: Char; Dir: String; Depth: Integer; Close1: Char;
Begin
 Repeat
  C:=Peek1;
  If CurPos>Length(CurTxt) Then Begin
   If Not NextLineOk Then Exit;
  End Else If C<=' ' Then Inc(CurPos)
  Else If (C='{') Or ((C='(') And (Peek2='*')) Then Begin
   Dir:='';
   If C='{' Then Begin Close1:='}';Inc(CurPos);End Else Begin Close1:=')';Inc(CurPos,2);End;
   If (Peek1='$') Then Begin
    Inc(CurPos);
    While (CurPos<=Length(CurTxt)) And (CurTxt[CurPos]<>'}') And
          Not ((Close1=')') And (CurTxt[CurPos]='*') And (Peek2=')')) Do Begin
     Dir:=Dir+CurTxt[CurPos];Inc(CurPos);
    End;
   End;
   Depth:=1;
   Repeat
    If CurPos>Length(CurTxt) Then Begin
     If Not NextLineOk Then Begin TokLine:=CurLn;TokCol:=1;Err(16);Exit;End;
    End Else If Close1='}' Then Begin
     If CurTxt[CurPos]='}' Then Begin Dec(Depth);Inc(CurPos);End
     Else If CurTxt[CurPos]='{' Then Begin Inc(Depth);Inc(CurPos);End
     Else Inc(CurPos);
    End Else Begin
     If (CurTxt[CurPos]='*') And (Peek2=')') Then Begin Dec(Depth);Inc(CurPos,2);End
     Else If (CurTxt[CurPos]='(') And (Peek2='*') Then Begin Inc(Depth);Inc(CurPos,2);End
     Else Inc(CurPos);
    End;
   Until Depth=0;
   If Dir<>'' Then Directive(Dir);
  End Else Exit;
 Until False;
End;

Function IsLetter(C: Char): Boolean;
Begin
 IsLetter:=((C>='A') And (C<='Z')) Or ((C>='a') And (C<='z')) Or (C='_');
End;

Function IsDig(C: Char): Boolean;
Begin
 IsDig:=(C>='0') And (C<='9');
End;

Function IsHex(C: Char): Boolean;
Begin
 IsHex:=IsDig(C) Or ((C>='A') And (C<='F')) Or ((C>='a') And (C<='f'));
End;

Procedure NextTok;
Var C: Char; I: Integer; S: String; V: Double; Cd: Integer; L: Int64; Q: Boolean;
Begin
 PrevLine:=TokLine;PrevCol:=TokCol;
 If CHalt Then Begin Tok:=T_EOF;Exit;End;
 SkipBlanks;
 TokLine:=CurLn;TokCol:=CurPos;
 If InInc Then TokLine:=CurLn;
 TokS:='';TokI:=0;
 If CurPos>Length(CurTxt) Then Begin Tok:=T_EOF;Exit;End;
 C:=CurTxt[CurPos];
 If IsLetter(C) Then Begin
  While (CurPos<=Length(CurTxt)) And (IsLetter(CurTxt[CurPos]) Or IsDig(CurTxt[CurPos])) Do Begin
   TokS:=TokS+UpCase(CurTxt[CurPos]);Inc(CurPos);
  End;
  Tok:=T_ID;
  For I:=1 To NKEY Do If KeyWords[I]=TokS Then Tok:=99+I;
  Exit;
 End;
 If IsDig(C) Or ((C='$') And IsHex(Peek2)) Or ((C='"') And IsHex(Peek2)) Then Begin
  If (C='$') Or (C='"') Then Begin
   Inc(CurPos);L:=0;
   While (CurPos<=Length(CurTxt)) And IsHex(CurTxt[CurPos]) Do Begin
    S:=UpCase(CurTxt[CurPos]);
    If S[1]>='A' Then L:=L*16+Ord(S[1])-55 Else L:=L*16+Ord(S[1])-48;
    If L>$FFFFFFFF Then Begin Err(18);L:=0;End;
    Inc(CurPos);
   End;
   If L>$7FFFFFFF Then L:=L-$100000000;
   TokI:=L;Tok:=T_INT;Exit;
  End;
  S:='';
  While (CurPos<=Length(CurTxt)) And IsDig(CurTxt[CurPos]) Do Begin S:=S+CurTxt[CurPos];Inc(CurPos);End;
  Q:=False;
  If (Peek1='.') And IsDig(Peek2) Then Begin
   Q:=True;S:=S+'.';Inc(CurPos);
   While (CurPos<=Length(CurTxt)) And IsDig(CurTxt[CurPos]) Do Begin S:=S+CurTxt[CurPos];Inc(CurPos);End;
  End;
  If (UpCase(Peek1)='E') And (IsDig(Peek2) Or (((Peek2='-') Or (Peek2='+')) And
     (CurPos+2<=Length(CurTxt)) And IsDig(CurTxt[CurPos+2]))) Then Begin
   Q:=True;S:=S+'E';Inc(CurPos);
   If (Peek1='-') Or (Peek1='+') Then Begin S:=S+Peek1;Inc(CurPos);End;
   While (CurPos<=Length(CurTxt)) And IsDig(CurTxt[CurPos]) Do Begin S:=S+CurTxt[CurPos];Inc(CurPos);End;
  End;
  If Q Then Begin
   Val(S,V,Cd);
   If Cd<>0 Then Begin Err(18);V:=0;End;
   TokR:=V;Tok:=T_REAL;
  End Else Begin
   Val(S,L,Cd);
   If (Cd<>0) Or (L>2147483647) Then Begin Err(18);L:=0;End;
   TokI:=L;Tok:=T_INT;
  End;
  Exit;
 End;
 If (C='''') Or (C='#') Then Begin
  S:='';
  Repeat
   If Peek1='''' Then Begin
    Inc(CurPos);
    Repeat
     If CurPos>Length(CurTxt) Then Begin Err(15);Break;End;
     If CurTxt[CurPos]='''' Then Begin
      If Peek2='''' Then Begin S:=S+'''';Inc(CurPos,2);End
      Else Begin Inc(CurPos);Break;End;
     End Else Begin S:=S+CurTxt[CurPos];Inc(CurPos);End;
    Until False;
   End Else If Peek1='#' Then Begin
    Inc(CurPos);L:=0;
    While IsDig(Peek1) Do Begin L:=L*10+Ord(Peek1)-48;Inc(CurPos);End;
    S:=S+Chr(L And 255);
   End Else Break;
  Until False;
  TokS:=S;Tok:=T_STR;
  Exit;
 End;
 Inc(CurPos);
 Case C Of
  '+': Tok:=T_PLUS;
  '-': Tok:=T_MINUS;
  '*': Tok:=T_STAR;
  '/': Tok:=T_SLASH;
  '=': Tok:=T_EQ;
  '<': If Peek1='>' Then Begin Tok:=T_NE;Inc(CurPos);End
       Else If Peek1='=' Then Begin Tok:=T_LE;Inc(CurPos);End
       Else Tok:=T_LT;
  '>': If Peek1='=' Then Begin Tok:=T_GE;Inc(CurPos);End Else Tok:=T_GT;
  '(': Tok:=T_LP;
  ')': Tok:=T_RP;
  '[': Tok:=T_LB;
  ']': Tok:=T_RB;
  '.': If Peek1='.' Then Begin Tok:=T_DOTDOT;Inc(CurPos);End
       Else If Peek1=')' Then Begin Tok:=T_RB;Inc(CurPos);End
       Else Tok:=T_DOT;
  ',': Tok:=T_COMMA;
  ':': If Peek1='=' Then Begin Tok:=T_ASSIGN;Inc(CurPos);End Else Tok:=T_COLON;
  ';': Tok:=T_SEMI;
  '^': Tok:=T_CARET;
  '&': Tok:=T_AMP;
  '|': Tok:=T_BAR;
  '~': Tok:=T_TILDE;
  '@': Tok:=T_CARET;
 Else
  Err(17);Tok:=T_EOF;
  If Not CHalt Then NextTok;
 End;
End;

Procedure LexInit(Const Name: String);
Begin
 CurLn:=0;CurTxt:='';CurPos:=1;InInc:=False;IncI:=0;
 TokLine:=1;TokCol:=1;PrevLine:=1;PrevCol:=1;
 CErrN:=0;CHalt:=False;CGoEdit:=False;
 ModuleMode:=False;ExportOn:=False;ExpN:=0;ExtN:=0;ExtPosN:=0;LongIntOn:=False;SpaceS:=-1;SpaceU:=-1;
 Opt:=Conf;
End;

Procedure Skip(T: Integer);
Begin
 If Tok=T Then NextTok Else Begin
  Case T Of
   T_SEMI: ErrExp(';');
   T_COLON: ErrExp(':');
   T_RP: ErrExp(')');
   T_RB: ErrExp(']');
   T_LP: ErrExp('(');
   T_EQ: ErrExp('=');
   T_ASSIGN: ErrExp(':=');
   T_DOT: ErrExp('.');
   T_COMMA: ErrExp(',');
   K_END: ErrExp('END');
   K_THEN: ErrExp('THEN');
   K_DO: ErrExp('DO');
   K_OF: ErrExp('OF');
   K_UNTIL: ErrExp('UNTIL');
   K_BEGIN: ErrExp('BEGIN');
  Else Err(0);
  End;
 End;
End;


{ ====================================================================== }
{         COMPILATEUR : TYPES, SYMBOLES ET GENERATION DE CODE 68000      }
{ ====================================================================== }

Const
 TK_INT=1;TK_LONG=2;TK_BYTE=3;TK_BOOL=4;TK_CHAR=5;TK_ENUM=6;TK_SUB=7;TK_REAL=8;
 TK_STR=9;TK_ARR=10;TK_REC=11;TK_PTR=12;TK_SET=13;TK_FILE=14;TK_NIL=15;TK_VOID=16;
 TY_INT=1;TY_LONG=2;TY_BYTE=3;TY_BOOL=4;TY_CHAR=5;TY_REAL=6;TY_STR=7;TY_NIL=8;
 TY_TEXT=9;TY_VOID=10;TY_STRLIT=11;TY_SETE=12;

 SK_CONST=1;SK_TYPE=2;SK_VAR=3;SK_PROC=4;SK_FUNC=5;SK_STD=6;SK_STDFILE=7;
 SK_WITH=8;

 MAXTY=1500;MAXSYM=3500;MAXFLD=4000;MAXPARM=2000;MAXND=4000;MAXLAB=9000;
 MAXFIX=12000;MAXREL=12000;MAXLIT=3000;MAXWITH=12;MAXPEND=60;
 CODEMAX=262144;
 G_BIAS=32760;

Type
 TTy = Record
  K    : Byte;
  Size : LongInt;
  Lo,Hi: LongInt;
  Base : Integer;
  Idx  : Integer;
  F1   : Integer;
 End;

 TFld = Record
  Name : String[40];
  Ty   : Integer;
  Off  : LongInt;
  Next : Integer;
 End;

 TParm = Record
  Name : String[40];
  Ty   : Integer;
  Ref  : Boolean;
  Off  : LongInt;       { decalage sur la pile (par rapport a A6) }
  Slot : Integer;
  Proc : Integer;       { > 0 : parametre procedural, symbole modele de la signature }
 End;

 TSym = Record
  Name  : String[40];
  K     : Byte;
  Ty    : Integer;
  Lvl   : Integer;
  Off   : LongInt;
  RVal  : Double;
  SVal  : String[255];
  Ref   : Boolean;
  PFirst: Integer;
  PCnt  : Integer;
  PSize : LongInt;
  Fwd   : Boolean;
  Std   : Integer;
  Dir   : Byte;           { 1 GEMDOS 2 BIOS 3 XBIOS 4 externe }
  DirN  : Integer;
  Lab   : Integer;        { etiquette du point d'entree }
  Res   : Integer;        { variable resultat (fonction) }
  Tpl   : Integer;        { > 0 : parametre procedural, symbole modele }
 End;

 TAddr = Record
  M : Byte;               { 0 globale (A4), 1 locale (A6), 2 relative a A0 }
  D : LongInt;
 End;

 TFix = Record
  Pos : LongInt;
  Lab : Integer;
  Kind: Byte;
 End;

 TLit = Record
  Lab : Integer;
  K   : Byte;             { 0 chaine, 1 reel }
  S   : String[255];
  R   : Double;
 End;

 TWith = Record
  Ty  : Integer;
  Slot: LongInt;
  Lvl : Integer;
 End;

 PCodeBuf = ^TCodeBuf;
 TCodeBuf = Array[0..CODEMAX-1] Of Byte;

Var
 Ty     : Array[1..MAXTY] Of TTy;
 TyN    : Integer;
 Fl     : Array[1..MAXFLD] Of TFld;
 FlN    : Integer;
 Pm     : Array[1..MAXPARM] Of TParm;
 PmN    : Integer;
 Sy     : Array[1..MAXSYM] Of TSym;
 SyN    : Integer;
 Code   : PCodeBuf;
 CP     : LongInt;
 LabPos : Array[1..MAXLAB] Of LongInt;
 LabNm  : Array[1..MAXLAB] Of String[24];
 LabExt : Array[1..MAXLAB] Of Boolean;
 LabN   : Integer;
 Fix    : Array[1..MAXFIX] Of TFix;
 FixN   : Integer;
 Rel    : Array[1..MAXREL] Of LongInt;
 RelN   : Integer;
 Lits   : Array[1..MAXLIT] Of TLit;
 LitN   : Integer;
 Withs  : Array[1..MAXWITH] Of TWith;
 WithN  : Integer;
 CurLvl : Integer;
 LocSize: LongInt;
 GSize  : LongInt;
 CurFunc: Integer;          { symbole de la procedure en cours de compilation }
 ProgName : String;
 PendTy : Array[1..MAXPEND] Of Integer;
 PendNm : Array[1..MAXPEND] Of String[40];
 PendN  : Integer;
 EntryLab,MainLab : Integer;
 SymNames : Array[1..400] Of String[12];
 SymAddrLab : Array[1..400] Of Integer;
 SymCnt : Integer;
 MaxLocal : LongInt;

{ ------------------------------- types -------------------------------- }

Function NewTy(K: Byte; Size: LongInt): Integer;
Begin
 If TyN>=MAXTY Then Begin Err(41);NewTy:=1;Exit;End;
 Inc(TyN);
 Ty[TyN].K:=K;Ty[TyN].Size:=Size;Ty[TyN].Lo:=0;Ty[TyN].Hi:=0;
 Ty[TyN].Base:=0;Ty[TyN].Idx:=0;Ty[TyN].F1:=0;
 NewTy:=TyN;
End;

Procedure InitTypes;
Var T: Integer;
Begin
 TyN:=0;
 T:=NewTy(TK_INT,2);Ty[T].Lo:=-32768;Ty[T].Hi:=32767;
 T:=NewTy(TK_LONG,4);Ty[T].Lo:=-2147483647;Ty[T].Hi:=2147483647;
 T:=NewTy(TK_BYTE,1);Ty[T].Lo:=0;Ty[T].Hi:=255;
 T:=NewTy(TK_BOOL,1);Ty[T].Lo:=0;Ty[T].Hi:=1;
 T:=NewTy(TK_CHAR,1);Ty[T].Lo:=0;Ty[T].Hi:=255;
 T:=NewTy(TK_REAL,8);
 T:=NewTy(TK_STR,82);Ty[T].Hi:=80;
 T:=NewTy(TK_NIL,4);
 T:=NewTy(TK_FILE,4);Ty[T].Base:=0;
 T:=NewTy(TK_VOID,0);
 T:=NewTy(TK_STR,258);Ty[T].Hi:=255;
 T:=NewTy(TK_SET,32);Ty[T].Base:=TY_INT;
End;

Function IsOrd(T: Integer): Boolean;
Begin
 IsOrd:=Ty[T].K In [TK_INT,TK_LONG,TK_BYTE,TK_BOOL,TK_CHAR,TK_ENUM,TK_SUB];
End;

Function Root(T: Integer): Integer;
Begin
 While Ty[T].K=TK_SUB Do T:=Ty[T].Base;
 Root:=T;
End;

Function IsIntLike(T: Integer): Boolean;
Begin
 T:=Root(T);
 IsIntLike:=Ty[T].K In [TK_INT,TK_LONG,TK_BYTE];
End;

Function IsNum(T: Integer): Boolean;
Begin
 IsNum:=IsIntLike(T) Or (Ty[T].K=TK_REAL);
End;

Function IsStrLike(T: Integer): Boolean;
Begin
 IsStrLike:=(Ty[T].K=TK_STR);
End;

Function IsAgg(T: Integer): Boolean;
Begin
 IsAgg:=Ty[T].K In [TK_STR,TK_ARR,TK_REC,TK_SET];
End;

Function OrdSize(Lo,Hi: LongInt): LongInt;
Begin
 If (Lo>=0) And (Hi<=255) Then OrdSize:=1
 Else If (Lo>=-32768) And (Hi<=32767) Then OrdSize:=2
 Else OrdSize:=4;
End;

Function MakeSub(Base: Integer; Lo,Hi: LongInt): Integer;
Var T: Integer;
Begin
 T:=NewTy(TK_SUB,OrdSize(Lo,Hi));
 Ty[T].Base:=Root(Base);Ty[T].Lo:=Lo;Ty[T].Hi:=Hi;
 MakeSub:=T;
End;

Function MakeStr(Max: LongInt): Integer;
Var T: Integer;
Begin
 If (Max<1) Or (Max>255) Then Begin Err(39);Max:=80;End;
 T:=NewTy(TK_STR,(Max+2) And (Not 1));Ty[T].Hi:=Max;
 MakeStr:=T;
End;

Function MakeArr(Idx,Elem: Integer): Integer;
Var T: Integer; N: LongInt; Es: LongInt;
Begin
 T:=NewTy(TK_ARR,0);
 Ty[T].Idx:=Idx;Ty[T].Base:=Elem;
 N:=Ty[Idx].Hi-Ty[Idx].Lo+1;
 If N<1 Then N:=1;
 Es:=Ty[Elem].Size;
 If (Es>1) And Odd(Es) Then Es:=Es+1;
 Ty[T].Size:=N*Es;
 If Odd(Ty[T].Size) Then Ty[T].Size:=Ty[T].Size+1;
 MakeArr:=T;
End;

Function ElemStride(T: Integer): LongInt;
Var Es: LongInt;
Begin
 Es:=Ty[Ty[T].Base].Size;
 If (Es>1) And Odd(Es) Then Es:=Es+1;
 ElemStride:=Es;
End;

Function MakePtr(Target: Integer): Integer;
Var T: Integer;
Begin
 T:=NewTy(TK_PTR,4);Ty[T].Base:=Target;MakePtr:=T;
End;

Function MakeSet(Base: Integer): Integer;
Var T: Integer;
Begin
 T:=NewTy(TK_SET,32);Ty[T].Base:=Base;MakeSet:=T;
End;

Function MakeFile(Elem: Integer): Integer;
Var T: Integer;
Begin
 T:=NewTy(TK_FILE,4);Ty[T].Base:=Elem;MakeFile:=T;
End;

Function FindFld(T: Integer; Const Nm: String): Integer;
Var F: Integer;
Begin
 FindFld:=0;
 F:=Ty[T].F1;
 While F<>0 Do Begin
  If Fl[F].Name=Nm Then Begin FindFld:=F;Exit;End;
  F:=Fl[F].Next;
 End;
End;

{ compatibilite d'affectation de types (sans conversion) }
Function SameTy(A,B: Integer): Boolean;
Begin
 If A=B Then Begin SameTy:=True;Exit;End;
 If IsIntLike(A) And IsIntLike(B) Then Begin SameTy:=True;Exit;End;
 If IsOrd(A) And IsOrd(B) Then Begin SameTy:=(Root(A)=Root(B));Exit;End;
 If (Ty[A].K=TK_STR) And (Ty[B].K=TK_STR) Then Begin SameTy:=True;Exit;End;
 If (Ty[A].K=TK_REAL) And (Ty[B].K=TK_REAL) Then Begin SameTy:=True;Exit;End;
 If (Ty[A].K=TK_PTR) And (Ty[B].K=TK_NIL) Then Begin SameTy:=True;Exit;End;
 If (Ty[A].K=TK_NIL) And (Ty[B].K=TK_PTR) Then Begin SameTy:=True;Exit;End;
 If (Ty[A].K=TK_PTR) And (Ty[B].K=TK_PTR) Then Begin
  SameTy:=(Ty[A].Base=Ty[B].Base) Or (Ty[A].Base=0) Or (Ty[B].Base=0);Exit;
 End;
 If (Ty[A].K=TK_SET) And (Ty[B].K=TK_SET) Then Begin
  SameTy:=(Ty[B].Base=TY_INT) Or (Root(Ty[A].Base)=Root(Ty[B].Base)) Or
          (IsIntLike(Ty[A].Base) And IsIntLike(Ty[B].Base));Exit;
 End;
 If (Ty[A].K=TK_ARR) And (Ty[B].K=TK_ARR) Then Begin
  SameTy:=(Ty[A].Size=Ty[B].Size) And (Ty[A].Base=Ty[B].Base);Exit;
 End;
 SameTy:=False;
End;

{ ------------------------------ symboles ------------------------------- }

Function FindSym(Const Nm: String): Integer;
Var I: Integer;
Begin
 For I:=SyN DownTo 1 Do
  If Sy[I].Name=Nm Then Begin FindSym:=I;Exit;End;
 FindSym:=0;
End;

Function AddSym(Const Nm: String; K: Byte; T: Integer): Integer;
Var I: Integer;
Begin
 If SyN>=MAXSYM Then Begin Err(41);AddSym:=SyN;Exit;End;
 { doublon dans la portee courante ? }
 I:=SyN;
 While (I>0) And (Sy[I].Lvl=CurLvl) Do Begin
  If (Sy[I].Name=Nm) And (Nm<>'') And (Sy[I].K<>SK_WITH) Then Begin
   If Not (Sy[I].Fwd) Then Err(4);
   Break;
  End;
  Dec(I);
 End;
 Inc(SyN);
 FillChar(Sy[SyN],SizeOf(TSym),0);
 Sy[SyN].Name:=Nm;Sy[SyN].K:=K;Sy[SyN].Ty:=T;Sy[SyN].Lvl:=CurLvl;
 AddSym:=SyN;
End;

Procedure DefConst(Const Nm: String; T: Integer; V: LongInt);
Var I: Integer;
Begin
 I:=AddSym(Nm,SK_CONST,T);Sy[I].Off:=V;
End;

Procedure DefType(Const Nm: String; T: Integer);
Var I: Integer;
Begin
 I:=AddSym(Nm,SK_TYPE,T);
End;

{ ------------------------- emission du code --------------------------- }

Procedure E8(B: LongInt);
Begin
 If CP>=CODEMAX-16 Then Begin
  If Not CHalt Then Err(26);
  CHalt:=True;Exit;
 End;
 Code^[CP]:=B And $FF;Inc(CP);
End;

Procedure E16(W: LongInt);
Begin
 E8((W Shr 8) And $FF);E8(W And $FF);
End;

Procedure E32(L: LongInt);
Begin
 E16((L Shr 16) And $FFFF);E16(L And $FFFF);
End;

Procedure Put16(Pos,W: LongInt);
Begin
 If (Pos>=0) And (Pos<CODEMAX-2) Then Begin
  Code^[Pos]:=(W Shr 8) And $FF;Code^[Pos+1]:=W And $FF;
 End;
End;

Procedure Put32(Pos,L: LongInt);
Begin
 Put16(Pos,(L Shr 16) And $FFFF);Put16(Pos+2,L And $FFFF);
End;

Function NewLab: Integer;
Begin
 If LabN>=MAXLAB Then Begin Err(26);NewLab:=1;Exit;End;
 Inc(LabN);LabPos[LabN]:=-1;NewLab:=LabN;
End;

Procedure Place(L: Integer);
Begin
 LabPos[L]:=CP;
End;

Procedure BraLab(CC: Integer; L: Integer);
{ Bcc.W vers une etiquette (CC : 0 BRA, 1 BSR, 6 BNE, 7 BEQ ...) }
Begin
 E16($6000 Or (CC Shl 8));
 If FixN<MAXFIX Then Begin
  Inc(FixN);Fix[FixN].Pos:=CP;Fix[FixN].Lab:=L;Fix[FixN].Kind:=0;
 End Else Err(26);
 E16(0);
End;

Procedure AbsLab(Op: LongInt; L: Integer);
{ instruction avec operande absolu long = adresse d'une etiquette (relogee) }
Begin
 E16(Op);
 If FixN<MAXFIX Then Begin
  Inc(FixN);Fix[FixN].Pos:=CP;Fix[FixN].Lab:=L;Fix[FixN].Kind:=1;
 End Else Err(26);
 If RelN<MAXREL Then Begin Inc(RelN);Rel[RelN]:=CP;End Else Err(26);
 E32(0);
End;

Function BccS(CC: Integer): LongInt;
Begin
 E16($6000 Or (CC Shl 8));
 BccS:=CP-2;
End;

Procedure PatchS(Pos: LongInt);
Var D: LongInt;
Begin
 D:=CP-(Pos+2);
 If (D<0) Or (D>127) Then Err(27)
 Else Code^[Pos+1]:=D;
End;

Function LitStr(Const S: String): Integer;
Begin
 If LitN>=MAXLIT Then Begin Err(26);LitStr:=1;Exit;End;
 Inc(LitN);
 Lits[LitN].Lab:=NewLab;Lits[LitN].K:=0;Lits[LitN].S:=S;
 LitStr:=Lits[LitN].Lab;
End;

Function LitReal(R: Double): Integer;
Begin
 If LitN>=MAXLIT Then Begin Err(26);LitReal:=1;Exit;End;
 Inc(LitN);
 Lits[LitN].Lab:=NewLab;Lits[LitN].K:=1;Lits[LitN].R:=R;
 LitReal:=Lits[LitN].Lab;
End;

{ ---- instructions de base ---- }

Procedure PushD0;  Begin E16($2F00); End;
Procedure PopD1;   Begin E16($221F); End;
Procedure PopD0;   Begin E16($201F); End;
Procedure PushA0;  Begin E16($2F08); End;
Procedure PopA0;   Begin E16($205F); End;

Procedure LoadImm(V: LongInt);
Begin
 If (V>=-128) And (V<=127) Then E16($7000 Or (V And $FF))
 Else Begin E16($203C);E32(V);End;
End;

Procedure PushImm(V: LongInt);
Begin
 E16($2F3C);E32(V);
End;

Procedure Svc(N: Integer);
Begin
 E16($303C);E16(N);E16($4E46);
End;

Procedure ErrStub(C: Integer);
Begin
 PushImm(C);Svc(S_ERR);
End;

Procedure Normalize(Var A: TAddr);
Begin
 Case A.M Of
  0: If (A.D-G_BIAS<-32768) Or (A.D-G_BIAS>32767) Then Begin Err(26);A.D:=G_BIAS;End;
  1: If (A.D<-32768) Or (A.D>32767) Then Begin Err(26);A.D:=0;End;
  2: If (A.D<-32768) Or (A.D>32767) Then Begin
      E16($D1FC);E32(A.D);A.D:=0;
     End;
 End;
End;

Function ARegOf(A: TAddr): Integer;
Begin
 Case A.M Of
  0: ARegOf:=4;
  1: ARegOf:=6;
 Else ARegOf:=0;
 End;
End;

Function ADisp(A: TAddr): LongInt;
Begin
 If A.M=0 Then ADisp:=A.D-G_BIAS Else ADisp:=A.D;
End;

Procedure LeaA0(A: TAddr);
Begin
 Normalize(A);
 Case A.M Of
  0: Begin E16($41EC);E16(ADisp(A));End;
  1: Begin E16($41EE);E16(ADisp(A));End;
 Else If A.D<>0 Then Begin E16($41E8);E16(A.D);End;
 End;
End;

Procedure PeaOf(A: TAddr);
Begin
 Normalize(A);
 Case A.M Of
  0: Begin E16($486C);E16(ADisp(A));End;
  1: Begin E16($486E);E16(ADisp(A));End;
 Else Begin E16($4868);E16(A.D);End;
 End;
End;

{ charge une valeur ordinale (taille Sz) de l'adresse A dans D0 }
Procedure LdOrd(A: TAddr; Sz: LongInt);
Begin
 Normalize(A);
 Case Sz Of
  1: Begin E16($7000);E16($1028 Or ARegOf(A));E16(ADisp(A));End;
  2: Begin E16($3028 Or ARegOf(A));E16(ADisp(A));E16($48C0);End;
 Else Begin E16($2028 Or ARegOf(A));E16(ADisp(A));End;
 End;
End;

{ range D0 dans l'adresse A }
Procedure StOrd(A: TAddr; Sz: LongInt);
Var Base: LongInt;
Begin
 Normalize(A);
 Case Sz Of
  1: Base:=$1000;
  2: Base:=$3000;
 Else Base:=$2000;
 End;
 E16(Base Or (ARegOf(A) Shl 9) Or (5 Shl 6));
 E16(ADisp(A));
End;

{ D0:D1 <- reel a l'adresse A ; reel D0:D1 -> adresse A }
Procedure LdReal(A: TAddr);
Var B: TAddr;
Begin
 Normalize(A);
 E16($2028 Or ARegOf(A));E16(ADisp(A));
 B:=A;B.D:=B.D+4;
 Normalize(B);
 E16($2228 Or ARegOf(B));E16(ADisp(B));
End;

Procedure StReal(A: TAddr);
Var B: TAddr;
Begin
 Normalize(A);
 E16($2000 Or (ARegOf(A) Shl 9) Or (5 Shl 6));E16(ADisp(A));
 B:=A;B.D:=B.D+4;
 Normalize(B);
 E16($2001 Or (ARegOf(B) Shl 9) Or (5 Shl 6));E16(ADisp(B));
End;

Procedure PushReal;
Begin
 E16($2F01);E16($2F00);       { MOVE.L D1,-(A7) ; MOVE.L D0,-(A7) }
End;

Procedure TstD0;
Begin
 E16($4A80);
End;

{ copie de N octets de (A1) vers (A0) }
Procedure BlockCopy(N: LongInt);
Var L: Integer; W: LongInt;
Begin
 W:=(N+1) Div 2;
 If W<=0 Then Exit;
 If W=1 Then Begin E16($30D9);Exit;End;
 If W=2 Then Begin E16($20D9);Exit;End;
 E16($203C);E32(W-1);              { MOVE.L #w-1,D0 }
 L:=CP;
 E16($30D9);                       { MOVE.W (A1)+,(A0)+ }
 E16($51C8);E16(L-(CP));           { DBRA D0,loop }
End;

Procedure BlockClear(N: LongInt);
{ met a zero N octets a partir de (A0) }
Var W: LongInt; L: LongInt;
Begin
 W:=(N+1) Div 2;
 If W<=0 Then Exit;
 E16($203C);E32(W-1);
 L:=CP;
 E16($4258);                       { CLR.W (A0)+ }
 E16($51C8);E16(L-CP);
End;

Procedure AdjSP(N: LongInt);
{ reajuste la pile : LEA N(A7),A7 }
Begin
 If N=0 Then Exit;
 If N<=8 Then Begin E16($508F Or ((N And 7) Shl 9));End
 Else Begin E16($4FEF);E16(N);End;
End;


{ ====================================================================== }
{          COMPILATEUR : EXPRESSIONS (ARBRE) ET GENERATION DE CODE       }
{ ====================================================================== }

Const
 N_INT=1;N_REAL=2;N_STR=3;N_CHR=4;N_NIL=5;N_VAR=6;N_FIELD=7;N_INDEX=8;N_SIDX=9;
 N_DEREF=10;N_FUNC=11;N_STD=12;N_UN=13;N_BIN=14;N_CONV=15;N_SET=16;N_RNG=17;
 N_WITH=18;N_STDFILE=19;N_FBUF=20;N_PROCREF=21;
 B_ADD=1;B_SUB=2;B_MUL=3;B_DIV=4;B_MOD=5;B_RDIV=6;B_AND=7;B_OR=8;B_EQ=9;B_NE=10;
 B_LT=11;B_GT=12;B_LE=13;B_GE=14;B_IN=15;
 F_ABS=1;F_SQR=2;F_SQRT=3;F_SIN=4;F_COS=5;F_ATAN=6;F_LN=7;F_EXP=8;F_TRUNC=9;
 F_ROUND=10;F_ODD=11;F_ORD=12;F_CHR=13;F_SUCC=14;F_PRED=15;F_LENGTH=16;
 F_CONCAT=17;F_COPY=18;F_POS=19;F_EOF=20;F_EOLN=21;F_SIZEOF=22;F_RANDOM=23;
 F_PEEK=24;F_WPEEK=25;F_LPEEK=26;F_ADDR=27;F_STRTRUNC=28;F_UPCASE=29;F_SHL=30;F_SHR=31;F_INT=32;F_PWR=33;
 P_WRITE=40;P_WRITELN=41;P_READ=42;P_READLN=43;P_NEW=44;P_DISPOSE=45;P_MARK=46;
 P_RELEASE=47;P_INSERT=48;P_DELETE=49;P_RESET=50;P_REWRITE=51;P_CLOSE=52;
 P_SEEK=53;P_PAGE=54;P_HALT=55;P_POKE=56;P_WPOKE=57;P_LPOKE=58;P_MOVEB=59;
 P_GET=60;P_PUT=61;P_ERASE=62;P_PACK=63;P_UNPACK=64;
 NHOSTMAX=240;

Type
 TNode = Record
  Op  : Byte;
  Ty  : Integer;
  A,B : Integer;
  Nxt : Integer;
  V   : LongInt;
  R   : Double;
  Sym : Integer;
  Len : Integer;
 End;

Var
 Nd   : Array[1..MAXND] Of TNode;
 NdN  : Integer;
 HSvc : Array[1..NHOSTMAX] Of Integer;
 HSig : Array[1..NHOSTMAX] Of String[8];
 HRes : Array[1..NHOSTMAX] Of Char;
 HNm  : Array[1..NHOSTMAX] Of String[24];
 HostN: Integer;
 GCVia : Integer;        { variable procedurale appelee par le GenCall suivant }

Function NewNd(Op: Byte; T: Integer): Integer;
Begin
 If NdN>=MAXND Then Begin Err(6);NdN:=1;End;
 Inc(NdN);
 FillChar(Nd[NdN],SizeOf(TNode),0);
 Nd[NdN].Op:=Op;Nd[NdN].Ty:=T;
 NewNd:=NdN;
End;

Function MkInt(V: LongInt; T: Integer): Integer;
Var N: Integer;
Begin
 N:=NewNd(N_INT,T);Nd[N].V:=V;MkInt:=N;
End;

Function IntTy(V: LongInt): Integer;
Begin
 If (V>=-32768) And (V<=32767) Then IntTy:=TY_INT Else IntTy:=TY_LONG;
End;

Function IsLval(N: Integer): Boolean;
Begin
 IsLval:=Nd[N].Op In [N_VAR,N_FIELD,N_INDEX,N_SIDX,N_DEREF,N_WITH,N_FBUF];
End;

Function MkStrNode(Const S: String): Integer;
Var N: Integer;
Begin
 N:=NewNd(N_STR,TY_STRLIT);
 Nd[N].V:=LitStr(S);Nd[N].Len:=Length(S);
 Nd[N].R:=0;
 MkStrNode:=N;
End;

Function ToReal(N: Integer): Integer;
Var M: Integer;
Begin
 If Ty[Nd[N].Ty].K=TK_REAL Then Begin ToReal:=N;Exit;End;
 If Nd[N].Op=N_INT Then Begin
  M:=NewNd(N_REAL,TY_REAL);Nd[M].R:=Nd[N].V;ToReal:=M;Exit;
 End;
 M:=NewNd(N_CONV,TY_REAL);Nd[M].A:=N;Nd[M].V:=1;ToReal:=M;
End;

Function IsCharArr(T: Integer): Boolean;
Begin
 IsCharArr:=(Ty[T].K=TK_ARR) And (Ty[Ty[T].Base].K=TK_CHAR);
End;

Function ToStrN(N: Integer): Integer;
Var M: Integer;
Begin
 If Ty[Nd[N].Ty].K=TK_STR Then Begin ToStrN:=N;Exit;End;
 If IsCharArr(Nd[N].Ty) Then Begin
  M:=NewNd(N_CONV,TY_STRLIT);Nd[M].A:=N;Nd[M].V:=3;ToStrN:=M;Exit;
 End;
 If Nd[N].Op=N_CHR Then Begin ToStrN:=MkStrNode(Chr(Nd[N].V And 255));Exit;End;
 M:=NewNd(N_CONV,TY_STRLIT);Nd[M].A:=N;Nd[M].V:=2;ToStrN:=M;
End;

{ force le noeud N a etre de type T (affectation / passage de parametre) }
Function Coerce(N: Integer; T: Integer): Integer;
Var K: Integer; E: Integer;
Begin
 Coerce:=N;
 If CHalt Then Exit;
 K:=Ty[T].K;
 If (K=TK_REAL) And IsIntLike(Nd[N].Ty) Then Begin Coerce:=ToReal(N);Exit;End;
 If (K=TK_STR) And ((Ty[Nd[N].Ty].K=TK_CHAR) Or (Ty[Nd[N].Ty].K=TK_STR) Or IsCharArr(Nd[N].Ty)) Then Begin
  Coerce:=ToStrN(N);Exit;
 End;
 If IsCharArr(T) And (Ty[Nd[N].Ty].K=TK_STR) Then Begin
  { affectation d'une chaine a un tableau de caracteres (ALFA, PACKED ARRAY OF CHAR) }
  If (Nd[N].Op=N_STR) And (Nd[N].Len>Ty[T].Size) Then Err(5);
  Exit;
 End;
 If (K=TK_CHAR) And (Ty[Nd[N].Ty].K=TK_STR) And (Nd[N].Op=N_STR) And (Nd[N].Len=1) Then Begin
  E:=NewNd(N_CHR,TY_CHAR);Nd[E].V:=Ord(' ');Coerce:=E;Err(5);Exit;
 End;
 If (K=TK_SET) And (Nd[N].Op=N_SET) Then Begin Nd[N].Ty:=T;Exit;End;
 If SameTy(T,Nd[N].Ty) Then Exit;
 Err(5);
End;

{ ------------------------- evaluation constante ----------------------- }

Function ConstEval(N: Integer; Var V: LongInt; Var R: Double; Var IsR: Boolean): Boolean;
Var V1,V2: LongInt; R1,R2: Double; I1,I2: Boolean; B: Integer;
Begin
 ConstEval:=False;V:=0;R:=0;IsR:=False;
 Case Nd[N].Op Of
  N_INT,N_CHR: Begin V:=Nd[N].V;ConstEval:=True;End;
  N_REAL: Begin R:=Nd[N].R;IsR:=True;ConstEval:=True;End;
  N_UN: If ConstEval(Nd[N].A,V1,R1,I1) Then Begin
    If Nd[N].V=1 Then Begin
     If I1 Then Begin R:=-R1;IsR:=True;End Else V:=-V1;
     ConstEval:=True;
    End Else If (Nd[N].V=2) And (Not I1) Then Begin
     If Ty[Nd[N].Ty].K=TK_BOOL Then V:=V1 Xor 1 Else V:=Not V1;
     ConstEval:=True;
    End;
   End;
  N_CONV: If (Nd[N].V=1) And ConstEval(Nd[N].A,V1,R1,I1) Then Begin
    R:=V1;IsR:=True;ConstEval:=True;
   End;
  N_BIN: If ConstEval(Nd[N].A,V1,R1,I1) And ConstEval(Nd[N].B,V2,R2,I2) Then Begin
    B:=Nd[N].V;
    If I1 Or I2 Then Begin
     If Not I1 Then R1:=V1;
     If Not I2 Then R2:=V2;
     IsR:=True;ConstEval:=True;
     Case B Of
      B_ADD: R:=R1+R2;
      B_SUB: R:=R1-R2;
      B_MUL: R:=R1*R2;
      B_RDIV: If R2<>0 Then R:=R1/R2 Else Begin Err(36);R:=0;End;
     Else ConstEval:=False;
     End;
    End Else Begin
     ConstEval:=True;
     Case B Of
      B_ADD: V:=V1+V2;
      B_SUB: V:=V1-V2;
      B_MUL: V:=V1*V2;
      B_DIV: If V2<>0 Then V:=V1 Div V2 Else Begin Err(36);V:=0;End;
      B_MOD: If V2<>0 Then V:=V1 Mod V2 Else Begin Err(36);V:=0;End;
      B_AND: V:=V1 And V2;
      B_OR: V:=V1 Or V2;
      B_RDIV: Begin If V2<>0 Then R:=V1/V2 Else R:=0;IsR:=True;End;
     Else ConstEval:=False;
     End;
    End;
   End;
 End;
End;

{ ------------------------- generation : adresses ---------------------- }

Procedure Expr(N: Integer); Forward;
Function GenAddr(N: Integer): TAddr; Forward;
Procedure AddrToA0(N: Integer); Forward;
Procedure GenCall(Sym: Integer; Args: Integer); Forward;
Procedure GenStdFunc(N: Integer); Forward;

{ A0 <- pointeur contenu a l'adresse A }
Procedure PtrToA0(A: TAddr);
Begin
 Normalize(A);
 E16($2040 Or (5 Shl 3) Or ARegOf(A));
 E16(ADisp(A));
End;

Procedure StaticTo(Hops: Integer);
{ A0 <- cadre de l'activation situee Hops niveaux plus haut (Hops>=1) }
Var I: Integer;
Begin
 E16($206E);E16(8);                   { MOVEA.L 8(A6),A0 }
 For I:=2 To Hops Do Begin E16($2068);E16(8);End;
End;

Function VarAddr(S: Integer): TAddr;
Var A: TAddr; Hops: Integer;
Begin
 If Sy[S].Lvl<=1 Then Begin A.M:=0;A.D:=Sy[S].Off;End
 Else If Sy[S].Lvl=CurLvl Then Begin A.M:=1;A.D:=Sy[S].Off;End
 Else Begin
  Hops:=CurLvl-Sy[S].Lvl;
  If Hops<1 Then Hops:=1;
  StaticTo(Hops);
  A.M:=2;A.D:=Sy[S].Off;
 End;
 If Sy[S].Ref Then Begin
  PtrToA0(A);
  A.M:=2;A.D:=0;
 End;
 VarAddr:=A;
End;

Procedure RangeCheck(Lo,Hi: LongInt);
{ D0 dans [Lo,Hi] sinon erreur d'intervalle }
Var P1,P2: LongInt;
Begin
 E16($0C80);E32(Lo);                  { CMPI.L #lo,D0 }
 P1:=BccS(13);                        { BLT.S erreur }
 E16($0C80);E32(Hi);
 P2:=BccS(15);                        { BLE.S ok }
 PatchS(P1);
 ErrStub(1);
 PatchS(P2);
End;

Function GenAddr(N: Integer): TAddr;
Var A,B: TAddr; Lo,St: LongInt; T: Integer; P: LongInt; IsC: Boolean; V: LongInt; R: Double; IsR: Boolean;
Begin
 A.M:=0;A.D:=0;
 Case Nd[N].Op Of
  N_VAR: A:=VarAddr(Nd[N].Sym);
  N_WITH: Begin
    If Nd[N].Sym<=1 Then Begin B.M:=0;B.D:=Nd[N].V;End Else Begin B.M:=1;B.D:=Nd[N].V;End;
    PtrToA0(B);A.M:=2;A.D:=0;
   End;
  N_FIELD: Begin
    A:=GenAddr(Nd[N].A);
    A.D:=A.D+Nd[N].V;
   End;
  N_FBUF: Begin
    AddrToA0(Nd[N].A);PushA0;Svc(S_FBUF);E16($2040);
    A.M:=2;A.D:=0;
   End;
  N_DEREF: Begin
    If IsLval(Nd[N].A) Then Begin B:=GenAddr(Nd[N].A);PtrToA0(B);End
    Else Begin Expr(Nd[N].A);E16($2040);End;
    If Opt.StackChk Then Begin
     E16($2008);P:=BccS(6);ErrStub(3);PatchS(P);
    End;
    A.M:=2;A.D:=0;
   End;
  N_INDEX: Begin
    T:=Nd[Nd[N].A].Ty;
    St:=ElemStride(T);Lo:=Ty[Ty[T].Idx].Lo;
    B:=GenAddr(Nd[N].A);
    If ConstEval(Nd[N].B,V,R,IsR) And (Not IsR) Then Begin
     If (V<Lo) Or (V>Ty[Ty[T].Idx].Hi) Then Begin Err(42);V:=Lo;End;
     B.D:=B.D+(V-Lo)*St;
     A:=B;
    End Else Begin
     LeaA0(B);PushA0;
     Expr(Nd[N].B);
     If Opt.RangeChk Then RangeCheck(Lo,Ty[Ty[T].Idx].Hi);
     If Lo<>0 Then Begin E16($0480);E32(Lo);End;     { SUBI.L #lo,D0 }
     If St<>1 Then Begin
      Case St Of
       2: E16($D080);
       4: Begin E16($D080);E16($D080);End;
       8: Begin E16($D080);E16($D080);E16($D080);End;
      Else Begin E16($C1FC);E16(St);End;                { MULS #st,D0 }
      End;
     End;
     PopA0;
     E16($D1C0);                                         { ADDA.L D0,A0 }
     A.M:=2;A.D:=0;
    End;
   End;
  N_SIDX: Begin
    T:=Nd[Nd[N].A].Ty;
    If IsLval(Nd[N].A) Then Begin B:=GenAddr(Nd[N].A);End
    Else Begin Expr(Nd[N].A);E16($2040);B.M:=2;B.D:=0;End;
    If ConstEval(Nd[N].B,V,R,IsR) And (Not IsR) Then Begin
     B.D:=B.D+V;
     A:=B;
     If Opt.RangeChk And ((V<1) Or (V>Ty[T].Hi)) Then Err(42);
    End Else Begin
     LeaA0(B);PushA0;
     Expr(Nd[N].B);
     If Opt.RangeChk Then RangeCheck(1,Ty[T].Hi);
     PopA0;
     E16($D1C0);
     A.M:=2;A.D:=0;
    End;
   End;
 End;
 GenAddr:=A;
End;

{ adresse (dans A0) d'un noeud de type agrege ou lvalue }
Procedure AddrToA0(N: Integer);
Var A: TAddr;
Begin
 If IsLval(N) Then Begin A:=GenAddr(N);LeaA0(A);End
 Else Begin Expr(N);E16($2040);End;
End;

Procedure PushValue(N: Integer);
{ empile la valeur d'un noeud scalaire (long) ou reel (8 octets) }
Begin
 Expr(N);
 If Ty[Nd[N].Ty].K=TK_REAL Then PushReal Else PushD0;
End;

Procedure LoadNode(N: Integer);
Var A: TAddr; T: Integer;
Begin
 A:=GenAddr(N);
 T:=Nd[N].Ty;
 Case Ty[T].K Of
  TK_REAL: LdReal(A);
  TK_STR,TK_ARR,TK_REC,TK_SET: Begin LeaA0(A);E16($2008);End;
 Else LdOrd(A,Ty[T].Size);
 End;
End;

Procedure CondSet(CC: Integer);
{ D0 <- 1 si la condition CC est vraie }
Begin
 E16($50C0 Or (CC Shl 8));
 E16($0280);E32(1);
End;

Procedure GenBin(N: Integer);
Var Op,TA,TB: Integer; Small: Boolean; CC: Integer;
Begin
 Op:=Nd[N].V;
 TA:=Nd[Nd[N].A].Ty;TB:=Nd[Nd[N].B].Ty;
 { ensembles }
 If Op=B_IN Then Begin
  Expr(Nd[N].A);PushD0;Expr(Nd[N].B);PushD0;Svc(S_SETIN);Exit;
 End;
 If (Ty[TA].K=TK_SET) Then Begin
  Case Op Of
   B_ADD: Begin Expr(Nd[N].A);PushD0;Expr(Nd[N].B);PushD0;Svc(S_SETUNI);End;
   B_SUB: Begin Expr(Nd[N].A);PushD0;Expr(Nd[N].B);PushD0;Svc(S_SETDIF);End;
   B_MUL: Begin Expr(Nd[N].A);PushD0;Expr(Nd[N].B);PushD0;Svc(S_SETINT);End;
   B_EQ,B_NE: Begin
     Expr(Nd[N].A);PushD0;Expr(Nd[N].B);PushD0;Svc(S_SETEQ);
     If Op=B_NE Then Begin E16($0A80);E32(1);End;
    End;
   B_LE: Begin Expr(Nd[N].A);PushD0;Expr(Nd[N].B);PushD0;Svc(S_SETSUB);End;
   B_GE: Begin Expr(Nd[N].B);PushD0;Expr(Nd[N].A);PushD0;Svc(S_SETSUB);End;
  Else Err(5);
  End;
  Exit;
 End;
 { chaines }
 If Ty[TA].K=TK_STR Then Begin
  Expr(Nd[N].A);PushD0;Expr(Nd[N].B);PushD0;
  If Op=B_ADD Then Svc(S_SCAT)
  Else Begin
   Svc(S_SCMP);TstD0;
   Case Op Of
    B_EQ: CC:=7; B_NE: CC:=6; B_LT: CC:=13; B_GT: CC:=14; B_LE: CC:=15;
   Else CC:=12;
   End;
   CondSet(CC);
  End;
  Exit;
 End;
 { reels }
 If (Ty[TA].K=TK_REAL) Or (Ty[TB].K=TK_REAL) Then Begin
  PushValue(Nd[N].A);PushValue(Nd[N].B);
  Case Op Of
   B_ADD: Svc(S_RADD);
   B_SUB: Svc(S_RSUB);
   B_MUL: Svc(S_RMUL);
   B_RDIV: Svc(S_RDIV);
  Else Begin
    Svc(S_RCMP);TstD0;
    Case Op Of
     B_EQ: CC:=7; B_NE: CC:=6; B_LT: CC:=13; B_GT: CC:=14; B_LE: CC:=15;
    Else CC:=12;
    End;
    CondSet(CC);
   End;
  End;
  Exit;
 End;
 { entiers, booleens, caracteres, enumeres, pointeurs }
 Expr(Nd[N].A);PushD0;Expr(Nd[N].B);PopD1;     { D1 = gauche, D0 = droite }
 Small:=(Ty[TA].Size<=2) And (Ty[TB].Size<=2);
 Case Op Of
  B_ADD: E16($D081);
  B_SUB: Begin E16($9280);E16($2001);End;
  B_MUL: If Small Then E16($C1C1)
         Else Begin E16($2F01);E16($2F00);Svc(S_MULL);End;
  B_DIV: If Small Then Begin E16($83C0);E16($48C1);E16($2001);End
         Else Begin E16($2F01);E16($2F00);Svc(S_DIVL);End;
  B_MOD: If Small Then Begin E16($83C0);E16($4841);E16($48C1);E16($2001);End
         Else Begin E16($2F01);E16($2F00);Svc(S_MODL);End;
  B_AND: E16($C081);
  B_OR: E16($8081);
 Else Begin
   E16($B280);                       { CMP.L D0,D1 }
   Case Op Of
    B_EQ: CC:=7; B_NE: CC:=6; B_LT: CC:=13; B_GT: CC:=14; B_LE: CC:=15;
   Else CC:=12;
   End;
   CondSet(CC);
  End;
 End;
End;

Procedure Expr(N: Integer);
Var A: TAddr; T: Integer; I: Integer; E: Integer;
Begin
 If CHalt Then Exit;
 Case Nd[N].Op Of
  N_INT,N_CHR: LoadImm(Nd[N].V);
  N_NIL: LoadImm(0);
  N_STDFILE: LoadImm(0);
  N_REAL: Begin
    AbsLab($41F9,LitReal(Nd[N].R));
    A.M:=2;A.D:=0;LdReal(A);
   End;
  N_STR: Begin AbsLab($41F9,Nd[N].V);E16($2008);End;
  N_VAR,N_FIELD,N_INDEX,N_SIDX,N_DEREF,N_WITH,N_FBUF: LoadNode(N);
  N_FUNC: Begin GCVia:=Nd[N].V;GenCall(Nd[N].Sym,Nd[N].A);End;
  N_STD: GenStdFunc(N);
  N_UN: Begin
    Expr(Nd[N].A);
    If Nd[N].V=3 Then Begin End
    Else If Nd[N].V=1 Then Begin
     If Ty[Nd[N].Ty].K=TK_REAL Then Begin PushReal;Svc(S_RNEG);End Else E16($4480);
    End Else Begin
     If Ty[Nd[N].Ty].K=TK_BOOL Then Begin E16($0A80);E32(1);End Else E16($4680);
    End;
   End;
  N_BIN: GenBin(N);
  N_CONV: Begin
    If Nd[N].V=3 Then Begin
     AddrToA0(Nd[N].A);PushA0;PushImm(Ty[Nd[Nd[N].A].Ty].Size);Svc(S_ARR2S);
    End Else Begin
     Expr(Nd[N].A);
     PushD0;
     If Nd[N].V=1 Then Svc(S_ITOR) Else Svc(S_C2S);
    End;
   End;
  N_SET: Begin
    Svc(S_SETNEW);
    E:=Nd[N].A;
    While E<>0 Do Begin
     PushD0;
     If Nd[E].Op=N_RNG Then Begin
      Expr(Nd[E].A);PushD0;Expr(Nd[E].B);PushD0;Svc(S_SETRNG);
     End Else Begin
      Expr(E);PushD0;Svc(S_SETADD);
     End;
     E:=Nd[E].Nxt;
    End;
   End;
 End;
End;

{ ------------------------- analyse des expressions -------------------- }

Function PExpr: Integer; Forward;

Function MkBin(Op: Integer; A,B: Integer): Integer;
Var TA,TB,RT,N: Integer; V1,V2: LongInt; R1,R2: Double; I1,I2: Boolean;
Begin
 TA:=Nd[A].Ty;TB:=Nd[B].Ty;
 RT:=TY_INT;
 { chaines et caracteres }
 If (Ty[TA].K=TK_STR) Or (Ty[TB].K=TK_STR) Or
    ((Ty[TA].K=TK_CHAR) And (Ty[TB].K=TK_CHAR) And (Op=B_ADD)) Then Begin
  If ((Ty[TA].K=TK_STR) Or (Ty[TA].K=TK_CHAR)) And ((Ty[TB].K=TK_STR) Or (Ty[TB].K=TK_CHAR)) Then Begin
   If (Ty[TA].K=TK_CHAR) And (Ty[TB].K=TK_CHAR) And (Op<>B_ADD) Then Begin
    { comparaison de caracteres }
   End Else Begin
    A:=ToStrN(A);B:=ToStrN(B);
    N:=NewNd(N_BIN,TY_BOOL);
    If Op=B_ADD Then Nd[N].Ty:=TY_STRLIT
    Else If Not (Op In [B_EQ,B_NE,B_LT,B_GT,B_LE,B_GE]) Then Err(31);
    Nd[N].V:=Op;Nd[N].A:=A;Nd[N].B:=B;
    MkBin:=N;Exit;
   End;
  End Else Begin Err(31);MkBin:=A;Exit;End;
 End;
 { ensembles }
 If (Ty[TA].K=TK_SET) Or (Ty[TB].K=TK_SET) Then Begin
  If Op=B_IN Then Begin
   If (Ty[TB].K<>TK_SET) Or (Not IsOrd(TA)) Then Begin Err(5);MkBin:=A;Exit;End;
   N:=NewNd(N_BIN,TY_BOOL);Nd[N].V:=B_IN;Nd[N].A:=A;Nd[N].B:=B;MkBin:=N;Exit;
  End;
  If (Ty[TA].K<>TK_SET) Or (Ty[TB].K<>TK_SET) Then Begin Err(5);MkBin:=A;Exit;End;
  If Op In [B_ADD,B_SUB,B_MUL] Then RT:=TA Else RT:=TY_BOOL;
  If Not (Op In [B_ADD,B_SUB,B_MUL,B_EQ,B_NE,B_LE,B_GE]) Then Err(5);
  If Nd[A].Op=N_SET Then Nd[A].Ty:=TB;
  If Nd[B].Op=N_SET Then Nd[B].Ty:=TA;
  N:=NewNd(N_BIN,RT);Nd[N].V:=Op;Nd[N].A:=A;Nd[N].B:=B;MkBin:=N;Exit;
 End;
 If Op=B_IN Then Begin Err(5);MkBin:=A;Exit;End;
 { numeriques }
 If (Ty[TA].K=TK_REAL) Or (Ty[TB].K=TK_REAL) Or (Op=B_RDIV) Then Begin
  If Not (IsNum(TA) And IsNum(TB)) Then Begin Err(5);MkBin:=A;Exit;End;
  A:=ToReal(A);B:=ToReal(B);
  If Op In [B_DIV,B_MOD,B_AND,B_OR] Then Begin Err(37);MkBin:=A;Exit;End;
  If Op=B_ADD Then RT:=TY_REAL Else If Op=B_SUB Then RT:=TY_REAL Else If Op=B_MUL Then RT:=TY_REAL
  Else If Op=B_RDIV Then RT:=TY_REAL Else RT:=TY_BOOL;
  N:=NewNd(N_BIN,RT);Nd[N].V:=Op;Nd[N].A:=A;Nd[N].B:=B;
  If ConstEval(N,V1,R1,I1) And I1 Then Begin
   N:=NewNd(N_REAL,TY_REAL);Nd[N].R:=R1;
  End;
  MkBin:=N;Exit;
 End;
 { ordinaux }
 If IsOrd(TA) And IsOrd(TB) Then Begin
  If Not SameTy(TA,TB) Then Err(5);
  If Op In [B_ADD,B_SUB,B_MUL,B_DIV,B_MOD] Then Begin
   If Not (IsIntLike(TA) And IsIntLike(TB)) Then Err(5);
   If (Ty[TA].Size<=2) And (Ty[TB].Size<=2) Then RT:=TY_INT Else RT:=TY_LONG;
   If (Op In [B_ADD,B_SUB,B_MUL]) And ((Ty[TA].Size>2) Or (Ty[TB].Size>2)) Then RT:=TY_LONG;
  End Else If Op In [B_AND,B_OR] Then Begin
   If Ty[Root(TA)].K=TK_BOOL Then RT:=TY_BOOL
   Else If IsIntLike(TA) Then Begin
    If (Ty[TA].Size<=2) And (Ty[TB].Size<=2) Then RT:=TY_INT Else RT:=TY_LONG;
   End Else Err(5);
  End Else RT:=TY_BOOL;
  N:=NewNd(N_BIN,RT);Nd[N].V:=Op;Nd[N].A:=A;Nd[N].B:=B;
  If RT<>TY_BOOL Then If ConstEval(N,V1,R1,I1) And (Not I1) Then Begin
   N:=NewNd(N_INT,IntTy(V1));Nd[N].V:=V1;
  End;
  MkBin:=N;Exit;
 End;
 { pointeurs }
 If ((Ty[TA].K=TK_PTR) Or (Ty[TA].K=TK_NIL)) And ((Ty[TB].K=TK_PTR) Or (Ty[TB].K=TK_NIL)) And
    (Op In [B_EQ,B_NE]) Then Begin
  N:=NewNd(N_BIN,TY_BOOL);Nd[N].V:=Op;Nd[N].A:=A;Nd[N].B:=B;MkBin:=N;Exit;
 End;
 Err(5);
 MkBin:=A;
End;

Function PSet: Integer;
Var First,Last,E,Lo,Hi: Integer; T: Integer;
Begin
 { '[' deja consomme }
 First:=0;Last:=0;T:=TY_INT;
 While (Tok<>T_RB) And (Tok<>T_EOF) And (Not CHalt) Do Begin
  E:=PExpr;
  If Not IsOrd(Nd[E].Ty) Then Err(30) Else T:=Nd[E].Ty;
  If Tok=T_DOTDOT Then Begin
   NextTok;
   Hi:=PExpr;
   Lo:=E;
   E:=NewNd(N_RNG,Nd[Lo].Ty);Nd[E].A:=Lo;Nd[E].B:=Hi;
  End;
  If First=0 Then First:=E Else Nd[Last].Nxt:=E;
  Last:=E;
  If Tok=T_COMMA Then NextTok Else Break;
 End;
 Skip(T_RB);
 E:=NewNd(N_SET,MakeSet(T));
 If First=0 Then Ty[Nd[E].Ty].Base:=TY_INT;
 Nd[E].A:=First;
 PSet:=E;
End;

Function PSelectors(N: Integer): Integer;
Var T,F,I,E: Integer;
Begin
 While Not CHalt Do Begin
  T:=Nd[N].Ty;
  If Tok=T_LB Then Begin
   NextTok;
   Repeat
    T:=Nd[N].Ty;
    E:=PExpr;
    If Ty[T].K=TK_ARR Then Begin
     If Not IsOrd(Nd[E].Ty) Then Err(9);
     I:=NewNd(N_INDEX,Ty[T].Base);Nd[I].A:=N;Nd[I].B:=E;N:=I;
    End Else If Ty[T].K=TK_STR Then Begin
     If Not IsIntLike(Nd[E].Ty) Then Err(11);
     I:=NewNd(N_SIDX,TY_CHAR);Nd[I].A:=N;Nd[I].B:=E;N:=I;
    End Else Begin Err(23);End;
    If Tok=T_COMMA Then NextTok Else Break;
   Until CHalt;
   Skip(T_RB);
  End Else If Tok=T_DOT Then Begin
   NextTok;
   If Ty[T].K<>TK_REC Then Begin Err(25);If Tok=T_ID Then NextTok;End
   Else If Tok<>T_ID Then Err(1)
   Else Begin
    F:=FindFld(T,TokS);
    If F=0 Then Err(22)
    Else Begin
     I:=NewNd(N_FIELD,Fl[F].Ty);Nd[I].A:=N;Nd[I].V:=Fl[F].Off;N:=I;
    End;
    NextTok;
   End;
  End Else If Tok=T_CARET Then Begin
   NextTok;
   If (Ty[T].K=TK_FILE) And (Ty[T].Base<>0) Then Begin
    I:=NewNd(N_FBUF,Ty[T].Base);Nd[I].A:=N;N:=I;
   End Else If Ty[T].K<>TK_PTR Then Err(24)
   Else Begin
    I:=NewNd(N_DEREF,Ty[T].Base);Nd[I].A:=N;N:=I;
   End;
  End Else Break;
 End;
 PSelectors:=N;
End;

{ le sous-programme S a-t-il la forme (signature) du modele T ? }
Function SigMatch(T,S: Integer): Boolean;
Var I: Integer; A,B: TParm;
Begin
 SigMatch:=False;
 If Sy[T].K<>Sy[S].K Then Exit;
 If Sy[T].PCnt<>Sy[S].PCnt Then Exit;
 If (Sy[T].K=SK_FUNC) And (Not SameTy(Sy[T].Ty,Sy[S].Ty)) Then Exit;
 For I:=1 To Sy[T].PCnt Do Begin
  A:=Pm[Sy[T].PFirst+I-1];B:=Pm[Sy[S].PFirst+I-1];
  If A.Ref<>B.Ref Then Exit;
  If (A.Proc<>0)<>(B.Proc<>0) Then Exit;
  If (A.Proc=0) And (Not SameTy(A.Ty,B.Ty)) Then Exit;
 End;
 SigMatch:=True;
End;

{ argument effectif pour un parametre procedural : nom d'un sous-programme }
Function PProcArg(Tpl: Integer): Integer;
Var S,N: Integer;
Begin
 N:=NewNd(N_PROCREF,TY_VOID);
 PProcArg:=N;
 If Tok<>T_ID Then Begin Err(1);Exit;End;
 S:=FindSym(TokS);
 If S=0 Then Begin Err(3);NextTok;Exit;End;
 NextTok;
 If ((Sy[S].K=SK_PROC) Or (Sy[S].K=SK_FUNC)) And (Sy[S].Dir In [0,4]) Then Begin
  If Not SigMatch(Tpl,S) Then Err(5);
  Nd[N].Sym:=S;
 End Else If (Sy[S].K=SK_VAR) And (Sy[S].Tpl<>0) Then Begin
  If Not SigMatch(Tpl,Sy[S].Tpl) Then Err(5);
  Nd[N].Sym:=S;
 End Else Err(5);
End;

{ analyse des arguments d'un appel de sous-programme utilisateur }
Function PArgs(S: Integer): Integer;
Var P,First,Last,E,I,Cnt: Integer; Pr: TParm;
Begin
 First:=0;Last:=0;
 Cnt:=Sy[S].PCnt;
 If Cnt>0 Then Begin
  If Tok<>T_LP Then Begin ErrExp('(');PArgs:=0;Exit;End;
  NextTok;
  For I:=1 To Cnt Do Begin
   Pr:=Pm[Sy[S].PFirst+I-1];
   If Pr.Proc<>0 Then E:=PProcArg(Pr.Proc) Else E:=PExpr;
   If Pr.Proc<>0 Then Begin End
   Else If Pr.Ref Then Begin
    If Not IsLval(E) Then Err(12)
    Else If Not (SameTy(Pr.Ty,Nd[E].Ty) Or (Ty[Pr.Ty].K=TK_STR) And (Ty[Nd[E].Ty].K=TK_STR)) Then Err(5)
    Else If (Ty[Pr.Ty].K=TK_ARR) And (Ty[Nd[E].Ty].K<>TK_ARR) Then Err(5);
   End Else E:=Coerce(E,Pr.Ty);
   If First=0 Then First:=E Else Nd[Last].Nxt:=E;
   Last:=E;
   If I<Cnt Then Begin If Tok=T_COMMA Then NextTok Else Begin ErrExp(',');Break;End;End;
  End;
  Skip(T_RP);
 End Else If Tok=T_LP Then Begin
  NextTok;Skip(T_RP);
 End;
 PArgs:=First;
End;

Function PStdFunc(Id: Integer; Const Nm: String): Integer; Forward;

Function PFactorX(Dm: Integer): Integer;
Var S,N,E,F,I,T: Integer; Nm: String; V: LongInt; R: Double; IsR: Boolean;
Begin
 PFactorX:=MkInt(0,TY_INT);
 If CHalt Then Exit;
 Case Tok Of
  T_INT: Begin N:=MkInt(TokI,IntTy(TokI));NextTok;PFactorX:=N;End;
  T_REAL: Begin N:=NewNd(N_REAL,TY_REAL);Nd[N].R:=TokR;NextTok;PFactorX:=N;End;
  T_STR: Begin
    If Length(TokS)=1 Then Begin N:=NewNd(N_CHR,TY_CHAR);Nd[N].V:=Ord(TokS[1]);End
    Else N:=MkStrNode(TokS);
    NextTok;PFactorX:=N;
   End;
  K_NIL: Begin N:=NewNd(N_NIL,TY_NIL);NextTok;PFactorX:=N;End;
  T_LP: Begin
    NextTok;N:=PExpr;Skip(T_RP);PFactorX:=PSelectors(N);
   End;
  T_LB: Begin NextTok;PFactorX:=PSet;End;
  K_NOT,T_TILDE: Begin
    NextTok;N:=PFactorX(0);
    If Ty[Nd[N].Ty].K=TK_BOOL Then Begin
     E:=NewNd(N_UN,TY_BOOL);Nd[E].V:=2;Nd[E].A:=N;PFactorX:=E;
    End Else If IsIntLike(Nd[N].Ty) Then Begin
     E:=NewNd(N_UN,Nd[N].Ty);Nd[E].V:=2;Nd[E].A:=N;PFactorX:=E;
    End Else Begin Err(10);PFactorX:=N;End;
   End;
  T_MINUS: Begin
    NextTok;N:=PFactorX(0);
    If Not IsNum(Nd[N].Ty) Then Err(5);
    E:=NewNd(N_UN,Nd[N].Ty);Nd[E].V:=1;Nd[E].A:=N;
    If ConstEval(E,V,R,IsR) Then Begin
     If IsR Then Begin E:=NewNd(N_REAL,TY_REAL);Nd[E].R:=R;End
     Else Begin E:=MkInt(V,IntTy(V));End;
    End;
    PFactorX:=E;
   End;
  T_PLUS: Begin NextTok;PFactorX:=PFactorX(0);End;
  T_ID: Begin
    Nm:=TokS;
    { champs des enregistrements ouverts par WITH }
    For I:=WithN DownTo 1 Do Begin
     F:=FindFld(Withs[I].Ty,Nm);
     If F<>0 Then Begin
      N:=NewNd(N_WITH,Withs[I].Ty);Nd[N].V:=Withs[I].Slot;Nd[N].Sym:=Withs[I].Lvl;
      E:=NewNd(N_FIELD,Fl[F].Ty);Nd[E].A:=N;Nd[E].V:=Fl[F].Off;
      NextTok;
      PFactorX:=PSelectors(E);
      Exit;
     End;
    End;
    S:=FindSym(Nm);
    If S=0 Then Begin Err(3);NextTok;Exit;End;
    NextTok;
    Case Sy[S].K Of
     SK_CONST: Begin
       T:=Sy[S].Ty;
       If Ty[T].K=TK_REAL Then Begin N:=NewNd(N_REAL,TY_REAL);Nd[N].R:=Sy[S].RVal;End
       Else If Ty[T].K=TK_STR Then Begin
        If Length(Sy[S].SVal)=1 Then Begin N:=NewNd(N_CHR,TY_CHAR);Nd[N].V:=Ord(Sy[S].SVal[1]);End
        Else N:=MkStrNode(Sy[S].SVal);
       End Else N:=MkInt(Sy[S].Off,T);
       PFactorX:=N;
      End;
     SK_VAR: Begin
       If Sy[S].Tpl<>0 Then Begin
        { appel d'une fonction recue en parametre }
        If Sy[Sy[S].Tpl].K<>SK_FUNC Then Begin Err(43);PFactorX:=MkInt(0,TY_INT);Exit;End;
        N:=NewNd(N_FUNC,Sy[Sy[S].Tpl].Ty);Nd[N].Sym:=Sy[S].Tpl;Nd[N].V:=S;Nd[N].A:=PArgs(Sy[S].Tpl);
        PFactorX:=PSelectors(N);
        Exit;
       End;
       N:=NewNd(N_VAR,Sy[S].Ty);Nd[N].Sym:=S;
       PFactorX:=PSelectors(N);
      End;
     SK_STDFILE: Begin
       N:=NewNd(N_STDFILE,TY_TEXT);PFactorX:=N;
      End;
     SK_FUNC: Begin
       N:=NewNd(N_FUNC,Sy[S].Ty);Nd[N].Sym:=S;Nd[N].A:=PArgs(S);
       PFactorX:=PSelectors(N);
      End;
     SK_PROC: Begin Err(43);PFactorX:=MkInt(0,TY_INT);End;
     SK_TYPE: Begin
       { conversion de type : Type(expr) }
       If Tok=T_LP Then Begin
        NextTok;N:=PExpr;Skip(T_RP);
        If (IsOrd(Sy[S].Ty) Or (Ty[Sy[S].Ty].K=TK_PTR)) And (IsOrd(Nd[N].Ty) Or (Ty[Nd[N].Ty].K=TK_PTR)) Then Begin
         If Nd[N].Op=N_INT Then E:=MkInt(Nd[N].V,Sy[S].Ty)
         Else Begin E:=NewNd(N_UN,Sy[S].Ty);Nd[E].V:=3;Nd[E].A:=N;End;
         PFactorX:=E;
        End Else Begin Err(5);PFactorX:=N;End;
       End Else Begin Err(44);End;
      End;
     SK_STD: PFactorX:=PStdFunc(Sy[S].Std,Nm);
    Else Err(44);
    End;
  End;
 Else
  Err(6);
  If (Tok<>T_EOF) And (Tok<>T_SEMI) And (Tok<>K_END) Then NextTok;
 End;
End;

Function PFactor: Integer;
Begin
 PFactor:=PFactorX(0);
End;

Function PTerm: Integer;
Var N,M,Op: Integer;
Begin
 N:=PFactor;
 While (Tok=T_STAR) Or (Tok=T_SLASH) Or (Tok=K_DIV) Or (Tok=K_MOD) Or (Tok=K_AND) Or (Tok=T_AMP) Do Begin
  Case Tok Of
   T_STAR: Op:=B_MUL; T_SLASH: Op:=B_RDIV; K_DIV: Op:=B_DIV; K_MOD: Op:=B_MOD;
  Else Op:=B_AND;
  End;
  NextTok;
  M:=PFactor;
  N:=MkBin(Op,N,M);
 End;
 PTerm:=N;
End;

Function PSimple: Integer;
Var N,M,Op: Integer;
Begin
 N:=PTerm;
 While (Tok=T_PLUS) Or (Tok=T_MINUS) Or (Tok=K_OR) Or (Tok=T_BAR) Do Begin
  Case Tok Of
   T_PLUS: Op:=B_ADD; T_MINUS: Op:=B_SUB;
  Else Op:=B_OR;
  End;
  NextTok;
  M:=PTerm;
  N:=MkBin(Op,N,M);
 End;
 PSimple:=N;
End;

Function PExpr: Integer;
Var N,M,Op: Integer;
Begin
 N:=PSimple;
 Op:=0;
 Case Tok Of
  T_EQ: Op:=B_EQ; T_NE: Op:=B_NE; T_LT: Op:=B_LT; T_GT: Op:=B_GT;
  T_LE: Op:=B_LE; T_GE: Op:=B_GE; K_IN: Op:=B_IN;
 End;
 If Op<>0 Then Begin
  NextTok;
  M:=PSimple;
  N:=MkBin(Op,N,M);
 End;
 PExpr:=N;
End;

Function PBool: Integer;
Var N: Integer;
Begin
 N:=PExpr;
 If Ty[Nd[N].Ty].K<>TK_BOOL Then Err(10);
 PBool:=N;
End;

Function PConstInt(Var V: LongInt): Boolean;
Var N: Integer; R: Double; IsR: Boolean;
Begin
 N:=PExpr;
 PConstInt:=False;V:=0;
 If ConstEval(N,V,R,IsR) And (Not IsR) Then PConstInt:=True Else Err(7);
End;

{ ------------------------- fonctions standard ------------------------- }

Function PStdFunc(Id: Integer; Const Nm: String): Integer;
Var A,B,C,N,I: Integer; V: LongInt; S: Integer; Sig: String; K: Integer; R: Double; IsR: Boolean;
    First,Last: Integer;
 Procedure OneArg;
 Begin
  Skip(T_LP);A:=PExpr;Skip(T_RP);
 End;
Begin
 PStdFunc:=MkInt(0,TY_INT);
 Case Id Of
  F_ABS: Begin
    OneArg;
    If Not IsNum(Nd[A].Ty) Then Err(5);
    N:=NewNd(N_STD,Nd[A].Ty);Nd[N].V:=Id;Nd[N].A:=A;PStdFunc:=N;
   End;
  F_SQR: Begin
    OneArg;
    If Not IsNum(Nd[A].Ty) Then Err(5);
    K:=Nd[A].Ty;
    If IsIntLike(K) Then Begin If Ty[K].Size<=2 Then K:=TY_LONG;End;
    N:=NewNd(N_STD,K);Nd[N].V:=Id;Nd[N].A:=A;PStdFunc:=N;
   End;
  F_SQRT,F_SIN,F_COS,F_ATAN,F_LN,F_EXP: Begin
    OneArg;
    If Not IsNum(Nd[A].Ty) Then Err(5);
    A:=ToReal(A);
    N:=NewNd(N_STD,TY_REAL);Nd[N].V:=Id;Nd[N].A:=A;PStdFunc:=N;
   End;
  F_TRUNC,F_ROUND: Begin
    OneArg;
    A:=ToReal(A);
    { TRUNC / ROUND : Short_Integer, sauf avec la directive L+ }
    If (Nm='SHORT_TRUNC') Or (Nm='SHORT_ROUND') Then K:=TY_INT
    Else If (Nm='LONG_TRUNC') Or (Nm='LONG_ROUND') Then K:=TY_LONG
    Else If LongIntOn Then K:=TY_LONG Else K:=TY_INT;
    N:=NewNd(N_STD,K);Nd[N].V:=Id;Nd[N].A:=A;PStdFunc:=N;
   End;
  F_ODD: Begin
    OneArg;
    If Not IsIntLike(Nd[A].Ty) Then Err(11);
    N:=NewNd(N_STD,TY_BOOL);Nd[N].V:=Id;Nd[N].A:=A;PStdFunc:=N;
   End;
  F_ORD: Begin
    OneArg;
    If Not IsOrd(Nd[A].Ty) Then Err(9);
    If (Nd[A].Op=N_INT) Or (Nd[A].Op=N_CHR) Then PStdFunc:=MkInt(Nd[A].V,TY_INT) Else Begin
     If Ty[Nd[A].Ty].Size>2 Then K:=TY_LONG Else K:=TY_INT;
     N:=NewNd(N_STD,K);Nd[N].V:=Id;Nd[N].A:=A;PStdFunc:=N;
    End;
   End;
  F_CHR: Begin
    OneArg;
    If Not IsIntLike(Nd[A].Ty) Then Err(11);
    N:=NewNd(N_STD,TY_CHAR);Nd[N].V:=Id;Nd[N].A:=A;PStdFunc:=N;
   End;
  F_SUCC,F_PRED: Begin
    OneArg;
    If Not IsOrd(Nd[A].Ty) Then Err(9);
    N:=NewNd(N_STD,Nd[A].Ty);Nd[N].V:=Id;Nd[N].A:=A;PStdFunc:=N;
   End;
  F_LENGTH: Begin
    OneArg;
    If Ty[Nd[A].Ty].K=TK_CHAR Then A:=ToStrN(A);
    If Ty[Nd[A].Ty].K<>TK_STR Then Err(31);
    N:=NewNd(N_STD,TY_INT);Nd[N].V:=Id;Nd[N].A:=A;PStdFunc:=N;
   End;
  F_UPCASE: Begin
    OneArg;
    A:=Coerce(A,TY_CHAR);
    N:=NewNd(N_STD,TY_CHAR);Nd[N].V:=Id;Nd[N].A:=A;PStdFunc:=N;
   End;
  F_CONCAT: Begin
    Skip(T_LP);
    A:=ToStrN(PExpr);
    While (Tok=T_COMMA) And (Not CHalt) Do Begin
     NextTok;
     B:=ToStrN(PExpr);
     A:=MkBin(B_ADD,A,B);
    End;
    Skip(T_RP);
    PStdFunc:=A;
   End;
  F_COPY: Begin
    Skip(T_LP);A:=ToStrN(PExpr);Skip(T_COMMA);B:=PExpr;Skip(T_COMMA);C:=PExpr;Skip(T_RP);
    N:=NewNd(N_STD,TY_STRLIT);Nd[N].V:=Id;Nd[N].A:=A;Nd[A].Nxt:=B;Nd[B].Nxt:=C;PStdFunc:=N;
   End;
  F_POS: Begin
    Skip(T_LP);A:=ToStrN(PExpr);Skip(T_COMMA);B:=ToStrN(PExpr);Skip(T_RP);
    N:=NewNd(N_STD,TY_INT);Nd[N].V:=Id;Nd[N].A:=A;Nd[A].Nxt:=B;PStdFunc:=N;
   End;
  F_EOF,F_EOLN: Begin
    A:=0;
    If Tok=T_LP Then Begin NextTok;A:=PExpr;Skip(T_RP);End;
    N:=NewNd(N_STD,TY_BOOL);Nd[N].V:=Id;Nd[N].A:=A;PStdFunc:=N;
   End;
  F_SIZEOF: Begin
    Skip(T_LP);
    If (Tok=T_ID) And (FindSym(TokS)<>0) And (Sy[FindSym(TokS)].K=SK_TYPE) Then Begin
     V:=Ty[Sy[FindSym(TokS)].Ty].Size;
     If LongIntOn And (TokS='INTEGER') Then V:=4;
     NextTok;
    End Else Begin A:=PExpr;V:=Ty[Nd[A].Ty].Size;End;
    Skip(T_RP);
    PStdFunc:=MkInt(V,IntTy(V));
   End;
  F_SHL,F_SHR: Begin
    Skip(T_LP);A:=PExpr;Skip(T_COMMA);B:=PExpr;Skip(T_RP);
    If Not (IsIntLike(Nd[A].Ty) And IsIntLike(Nd[B].Ty)) Then Err(11);
    N:=NewNd(N_STD,Nd[A].Ty);Nd[N].V:=Id;Nd[N].A:=A;Nd[A].Nxt:=B;PStdFunc:=N;
   End;
  F_INT: Begin
    OneArg;
    If Not IsIntLike(Nd[A].Ty) Then Err(11);
    N:=NewNd(N_STD,TY_INT);Nd[N].V:=Id;Nd[N].A:=A;PStdFunc:=N;
   End;
  F_PWR: Begin
    OneArg;
    If Not IsIntLike(Nd[A].Ty) Then Err(11);
    N:=NewNd(N_STD,TY_REAL);Nd[N].V:=Id;Nd[N].A:=A;PStdFunc:=N;
   End;
  F_RANDOM: Begin
    OneArg;
    N:=NewNd(N_STD,TY_INT);Nd[N].V:=Id;Nd[N].A:=A;PStdFunc:=N;
   End;
  F_PEEK,F_WPEEK,F_LPEEK: Begin
    OneArg;
    If Id=F_LPEEK Then K:=TY_LONG Else K:=TY_INT;
    N:=NewNd(N_STD,K);Nd[N].V:=Id;Nd[N].A:=A;PStdFunc:=N;
   End;
  F_ADDR: Begin
    Skip(T_LP);A:=PExpr;Skip(T_RP);
    If Not IsLval(A) Then Err(12);
    N:=NewNd(N_STD,TY_LONG);Nd[N].V:=Id;Nd[N].A:=A;PStdFunc:=N;
   End;
 Else
  If Id>=1000 Then Begin
   { fonction de la bibliotheque GEM }
   I:=Id-1000;
   Sig:=HSig[I];
   First:=0;Last:=0;
   If Sig<>'' Then Begin
    Skip(T_LP);
    For K:=1 To Length(Sig) Do Begin
     A:=PExpr;
     Case Sig[K] Of
      'I': If Not IsOrd(Nd[A].Ty) Then Err(11);
      'S': A:=Coerce(A,TY_STRLIT);
      'R': A:=Coerce(A,TY_REAL);
      'V': If Not IsLval(A) Then Err(12);
     End;
     If First=0 Then First:=A Else Nd[Last].Nxt:=A;
     Last:=A;
     If K<Length(Sig) Then Skip(T_COMMA);
    End;
    Skip(T_RP);
   End Else If Tok=T_LP Then Begin NextTok;Skip(T_RP);End;
   N:=NewNd(N_STD,TY_INT);Nd[N].V:=Id;Nd[N].A:=First;
   If HRes[I]='B' Then Nd[N].Ty:=TY_BOOL;
   If HRes[I]=' ' Then Err(43);
   PStdFunc:=N;
  End Else Err(43);
 End;
End;

{ ------------------------- appels de sous-programmes ------------------ }

Procedure PushStaticLink(S: Integer);
Var Hops: Integer;
Begin
 Hops:=CurLvl-Sy[S].Lvl;
 If Hops<=0 Then E16($2F0E)
 Else Begin StaticTo(Hops);E16($2F08);End;
End;

{ empile (adresse de code, lien statique) d'un sous-programme passe en parametre }
Procedure PushProcArg(N: Integer);
Var S: Integer; Ad: TAddr;
Begin
 S:=Nd[N].Sym;
 If S=0 Then Begin LoadImm(0);PushD0;PushD0;Exit;End;
 If Sy[S].K=SK_VAR Then Begin
  { transmission d'un parametre procedural a un autre sous-programme }
  Ad:=VarAddr(S);LeaA0(Ad);
  E16($2F28);E16(4);                    { MOVE.L 4(A0),-(A7) : adresse }
  E16($2F10);                           { MOVE.L (A0),-(A7)  : lien statique }
 End Else Begin
  AbsLab($4879,Sy[S].Lab);              { PEA adresse }
  PushStaticLink(S);
 End;
End;

Procedure GenCall(Sym: Integer; Args: Integer);
Var P,I,Cnt: Integer; A: Integer; Pr: TParm; Arr: Array[1..40] Of Integer; Tot: LongInt; Sz: Integer;
    Tp: Integer; Via: Integer; Ad: TAddr;
Begin
 Via:=GCVia;GCVia:=0;
 Cnt:=Sy[Sym].PCnt;
 A:=Args;
 For I:=1 To Cnt Do Begin
  Arr[I]:=A;
  If A<>0 Then A:=Nd[A].Nxt;
 End;
 If Sy[Sym].Dir=5 Then Begin
  { routine de la bibliotheque integree (PASGEM / PASAUX) }
  For I:=1 To Cnt Do Begin
   Pr:=Pm[Sy[Sym].PFirst+I-1];
   If Pr.Ref Or IsAgg(Pr.Ty) Or (Ty[Pr.Ty].K=TK_ARR) Or (Ty[Pr.Ty].K=TK_REC) Then Begin
    AddrToA0(Arr[I]);PushA0;
   End Else If Ty[Pr.Ty].K=TK_REAL Then Begin Expr(Arr[I]);PushReal;End
   Else Begin Expr(Arr[I]);PushD0;End;
  End;
  Svc(HSvc[Sy[Sym].DirN]);
  Exit;
 End;
 If Sy[Sym].Dir In [1,2,3] Then Begin
  { appel systeme : arguments empiles en ordre inverse, tailles naturelles }
  Tot:=0;
  For I:=Cnt DownTo 1 Do Begin
   Pr:=Pm[Sy[Sym].PFirst+I-1];
   If Pr.Ref Then Begin
    AddrToA0(Arr[I]);PushA0;Tot:=Tot+4;
   End Else Begin
    Sz:=Ty[Pr.Ty].Size;
    Expr(Arr[I]);
    If Ty[Pr.Ty].K=TK_REAL Then Begin PushReal;Tot:=Tot+8;End
    Else If Sz<=2 Then Begin E16($3F00);Tot:=Tot+2;End
    Else Begin PushD0;Tot:=Tot+4;End;
   End;
  End;
  E16($3F3C);E16(Sy[Sym].DirN);Tot:=Tot+2;
  Case Sy[Sym].Dir Of
   1: E16($4E41);
   2: E16($4E4D);
  Else E16($4E4E);
  End;
  AdjSP(Tot);
  If (Sy[Sym].K=SK_FUNC) Then Begin
   Tp:=Sy[Sym].Ty;
   If Ty[Tp].Size=2 Then E16($48C0)
   Else If Ty[Tp].Size=1 Then Begin E16($0280);E32($FF);End;
  End;
  Exit;
 End;
 Tot:=0;
 For I:=1 To Cnt Do Begin
  Pr:=Pm[Sy[Sym].PFirst+I-1];
  If Pr.Proc<>0 Then Begin
   PushProcArg(Arr[I]);
  End Else If Pr.Ref Then Begin
   AddrToA0(Arr[I]);PushA0;
  End Else If IsAgg(Pr.Ty) Or (Ty[Pr.Ty].K=TK_ARR) Or (Ty[Pr.Ty].K=TK_REC) Then Begin
   AddrToA0(Arr[I]);PushA0;
  End Else If Ty[Pr.Ty].K=TK_REAL Then Begin
   Expr(Arr[I]);PushReal;
  End Else Begin
   Expr(Arr[I]);PushD0;
  End;
 End;
 If Via<>0 Then Begin
  { appel indirect par une variable procedurale : (lien statique, adresse) }
  Ad:=VarAddr(Via);LeaA0(Ad);
  E16($2F10);                           { MOVE.L (A0),-(A7) : lien statique }
  E16($2068);E16(4);                    { MOVEA.L 4(A0),A0 : adresse }
  E16($4E90);                           { JSR (A0) }
  AdjSP(Sy[Sym].PSize+4);
  Exit;
 End;
 PushStaticLink(Sym);
 AbsLab($4EB9,Sy[Sym].Lab);
 AdjSP(Sy[Sym].PSize+4);
End;

Procedure GenStdFunc(N: Integer);
Var Id,I: Integer; A,B,C: Integer; T: Integer; P: LongInt; Ad: TAddr; K: Integer; Sig: String; E: Integer;
Begin
 Id:=Nd[N].V;A:=Nd[N].A;
 Case Id Of
  F_ABS: Begin
    Expr(A);
    If Ty[Nd[A].Ty].K=TK_REAL Then Begin PushReal;Svc(S_RABS);End
    Else Begin E16($4A80);E16($6A02);E16($4480);End;
   End;
  F_SQR: Begin
    If Ty[Nd[A].Ty].K=TK_REAL Then Begin Expr(A);PushReal;Svc(S_RSQR);End
    Else If Ty[Nd[A].Ty].Size<=2 Then Begin Expr(A);E16($2200);E16($C1C1);End
    Else Begin Expr(A);PushD0;E16($2F00);Svc(S_MULL);End;
   End;
  F_SQRT: Begin Expr(A);PushReal;Svc(S_RSQRT);End;
  F_SIN: Begin Expr(A);PushReal;Svc(S_RSIN);End;
  F_COS: Begin Expr(A);PushReal;Svc(S_RCOS);End;
  F_ATAN: Begin Expr(A);PushReal;Svc(S_RATAN);End;
  F_LN: Begin Expr(A);PushReal;Svc(S_RLN);End;
  F_EXP: Begin Expr(A);PushReal;Svc(S_REXP);End;
  F_TRUNC: Begin Expr(A);PushReal;Svc(S_RTRUNC);End;
  F_ROUND: Begin Expr(A);PushReal;Svc(S_RROUND);End;
  F_ODD: Begin Expr(A);E16($0280);E32(1);End;
  F_ORD,F_CHR: Expr(A);
  F_UPCASE: Begin Expr(A);PushD0;Svc(S_C2S);PushD0;Svc(S_SUPPER);E16($2040);E16($7000);E16($1028);E16(1);End;
  F_SUCC: Begin Expr(A);E16($5280);End;
  F_PRED: Begin Expr(A);E16($5380);End;
  F_LENGTH: Begin Expr(A);E16($2040);E16($7000);E16($1010);End;
  F_COPY: Begin
    B:=Nd[A].Nxt;C:=Nd[B].Nxt;
    Expr(A);PushD0;Expr(B);PushD0;Expr(C);PushD0;Svc(S_SCOPY);
   End;
  F_POS: Begin
    B:=Nd[A].Nxt;
    Expr(A);PushD0;Expr(B);PushD0;Svc(S_SPOS);
   End;
  F_EOF,F_EOLN: Begin
    If (A=0) Or (Nd[A].Op=N_STDFILE) Then LoadImm(0) Else Begin AddrToA0(A);E16($2008);End;
    PushD0;
    If Id=F_EOF Then Svc(S_EOF) Else Svc(S_EOLN);
   End;
  F_SHL,F_SHR: Begin
    B:=Nd[A].Nxt;
    Expr(A);PushD0;Expr(B);E16($2200);PopD0;
    If Id=F_SHL Then E16($E3A8) Else E16($E2A8);
   End;
  F_INT: Begin Expr(A);E16($48C0);End;
  F_PWR: Begin Expr(A);PushD0;Svc(S_PWRTEN);End;
  F_RANDOM: Begin Expr(A);PushD0;Svc(S_RANDOM);End;
  F_PEEK: Begin Expr(A);PushD0;Svc(S_PEEKB);End;
  F_WPEEK: Begin Expr(A);PushD0;Svc(S_PEEKW);End;
  F_LPEEK: Begin Expr(A);PushD0;Svc(S_PEEKL);End;
  F_ADDR: Begin
    Ad:=GenAddr(A);LeaA0(Ad);E16($2008);
   End;
 Else
  If Id>=1000 Then Begin
   I:=Id-1000;Sig:=HSig[I];E:=A;
   For K:=1 To Length(Sig) Do Begin
    Case Sig[K] Of
     'R': Begin Expr(E);PushReal;End;
     'V': Begin AddrToA0(E);PushA0;End;
    Else Begin Expr(E);PushD0;End;
    End;
    E:=Nd[E].Nxt;
   End;
   Svc(HSvc[I]);
  End;
 End;
End;

Procedure AddHostT(Const Nm: String; Sv: Integer; Const Sig: String; Res: Char);
Begin
 If HostN>=NHOSTMAX Then Exit;
 Inc(HostN);
 HSvc[HostN]:=Sv;HSig[HostN]:=Sig;HRes[HostN]:=Res;HNm[HostN]:=Nm;
End;

Procedure AddHost(Const Nm: String; Sv: Integer; Const Sig: String; Res: Char);
Var I: Integer;
Begin
 AddHostT(Nm,Sv,Sig,Res);
 I:=AddSym(Nm,SK_STD,TY_INT);
 Sy[I].Std:=1000+HostN;
End;

Function FindHost(Const Nm: String): Integer;
Var I: Integer;
Begin
 FindHost:=0;
 For I:=1 To HostN Do If HNm[I]=Nm Then Begin FindHost:=I;Exit;End;
End;


{ ====================================================================== }
{       COMPILATEUR : INSTRUCTIONS, DECLARATIONS ET PROGRAMME            }
{ ====================================================================== }

Const
 MAXRLAB = 400;
 MAXLOOP = 40;

Var
 RLabNum : Array[1..MAXRLAB] Of LongInt;
 RLabLab : Array[1..MAXRLAB] Of Integer;
 RLabDef : Array[1..MAXRLAB] Of Boolean;
 RLabN   : Integer;
 RLabBase: Integer;
 LoopExit: Array[1..MAXLOOP] Of Integer;
 LoopN   : Integer;
 FuncStk : Array[1..20] Of Integer;
 CurLine : Integer;

Procedure PStatement; Forward;

Procedure StA0(A: TAddr);
{ MOVE.L A0,d(An) }
Begin
 Normalize(A);
 E16($2008 Or (ARegOf(A) Shl 9) Or (5 Shl 6));E16(ADisp(A));
End;

Function AllocTemp(Size: LongInt): TAddr;
Var A: TAddr;
Begin
 Size:=(Size+1) And (Not 1);
 If CurLvl<=1 Then Begin
  A.M:=0;A.D:=GSize;GSize:=GSize+Size;
  If GSize>65500 Then Begin Err(26);GSize:=0;End;
 End Else Begin
  LocSize:=LocSize+Size;
  A.M:=1;A.D:=-LocSize;
  If LocSize>32000 Then Begin Err(26);LocSize:=2;End;
 End;
 AllocTemp:=A;
End;

Function NeedsD0(N: Integer): Boolean;
Var V: LongInt; R: Double; IsR: Boolean;
Begin
 Case Nd[N].Op Of
  N_VAR,N_WITH: NeedsD0:=False;
  N_FIELD: NeedsD0:=NeedsD0(Nd[N].A);
  N_INDEX,N_SIDX: Begin
    If ConstEval(Nd[N].B,V,R,IsR) And (Not IsR) Then NeedsD0:=NeedsD0(Nd[N].A)
    Else NeedsD0:=True;
   End;
 Else NeedsD0:=True;
 End;
End;

Procedure DebugLine;
Begin
 If Opt.FullDebug Then Begin
  E16($31FC);E16(TokLine And $7FFF);E16(M_DBG);
 End;
End;

Procedure GenAssign(L,R: Integer);
Var A: TAddr; T: Integer; K: Integer;
Begin
 T:=Nd[L].Ty;K:=Ty[T].K;
 Case K Of
  TK_REAL: Begin
    Expr(R);
    If NeedsD0(L) Then Begin
     PushReal;A:=GenAddr(L);E16($201F);E16($221F);StReal(A);
    End Else Begin A:=GenAddr(L);StReal(A);End;
   End;
  TK_STR: Begin
    AddrToA0(L);PushA0;
    Expr(R);PushD0;PushImm(Ty[T].Hi);Svc(S_SASG);
   End;
  TK_ARR,TK_REC,TK_SET: Begin
    If (K=TK_ARR) And (Ty[Nd[R].Ty].K=TK_STR) Then Begin
     AddrToA0(L);PushA0;Expr(R);PushD0;PushImm(Ty[T].Size);Svc(S_CARRASG);
    End Else Begin
     AddrToA0(L);PushA0;
     AddrToA0(R);E16($2248);PopA0;
     BlockCopy(Ty[T].Size);
    End;
   End;
 Else Begin
   Expr(R);
   If Opt.RangeChk And (K In [TK_SUB]) Then RangeCheck(Ty[T].Lo,Ty[T].Hi);
   If NeedsD0(L) Then Begin
    PushD0;A:=GenAddr(L);PopD0;
   End Else A:=GenAddr(L);
   StOrd(A,Ty[T].Size);
  End;
 End;
End;

{ ------------------------- procedures standard ------------------------ }

Function FileArg(N: Integer): Boolean;
Begin
 FileArg:=(Ty[Nd[N].Ty].K=TK_FILE);
End;

Procedure PushFileAddr(N: Integer);
Begin
 If Nd[N].Op=N_STDFILE Then LoadImm(0)
 Else Begin AddrToA0(N);E16($2008);End;
 PushD0;
End;

Procedure WItem(N,W,D: Integer; Hex: Boolean);
Var T,K: Integer;
Begin
 T:=Nd[N].Ty;K:=Ty[T].K;
 If IsCharArr(T) Then Begin N:=ToStrN(N);T:=Nd[N].Ty;K:=Ty[T].K;End;
 If IsIntLike(T) Then Begin
  Expr(N);PushD0;
  If W<>0 Then Expr(W) Else If Hex Then LoadImm(0)
  Else If Ty[T].Size>2 Then LoadImm(11) Else LoadImm(6);
  PushD0;
  If Hex Then Svc(S_WRIH) Else Svc(S_WRI);
 End Else If K=TK_CHAR Then Begin
  Expr(N);PushD0;If W<>0 Then Expr(W) Else LoadImm(0);PushD0;Svc(S_WRC);
 End Else If K=TK_BOOL Then Begin
  Expr(N);PushD0;If W<>0 Then Expr(W) Else LoadImm(0);PushD0;Svc(S_WRB);
 End Else If K=TK_STR Then Begin
  Expr(N);PushD0;If W<>0 Then Expr(W) Else LoadImm(0);PushD0;Svc(S_WRS);
 End Else If K=TK_REAL Then Begin
  PushValue(N);If W<>0 Then Expr(W) Else LoadImm(0);PushD0;
  If D<>0 Then Expr(D) Else LoadImm(-1);PushD0;Svc(S_WRR);
 End Else Err(5);
End;

Procedure PWrite(Ln: Boolean);
Var N,W,D,F: Integer; HasF,Typed,Hex: Boolean; T: Integer;
Begin
 F:=0;HasF:=False;Typed:=False;
 If Tok=T_LP Then Begin
  NextTok;
  N:=PExpr;
  If FileArg(N) Then Begin
   HasF:=True;F:=N;
   Typed:=(Ty[Nd[N].Ty].Base<>0);
   PushFileAddr(F);
   If Not Typed Then Svc(S_SELOUT);
   If Tok=T_COMMA Then NextTok;
   N:=0;
  End Else Begin
   LoadImm(0);PushD0;Svc(S_SELOUT);
  End;
  Repeat
   If N=0 Then Begin
    If (Tok=T_RP) Or (Tok=T_EOF) Then Break;
    N:=PExpr;
   End;
   W:=0;D:=0;Hex:=False;
   If Tok=T_COLON Then Begin
    NextTok;W:=PExpr;
    If Tok=T_COLON Then Begin
     NextTok;
     If (Tok=T_ID) And (TokS='H') Then Begin Hex:=True;NextTok;End Else D:=PExpr;
    End;
   End;
   T:=Nd[N].Ty;
   If Typed Then Begin
    If IsLval(N) Then Begin
     E16($2F17);AddrToA0(N);PushA0;PushImm(Ty[T].Size);Svc(S_FWRITE);
    End Else Err(12);
   End Else WItem(N,W,D,Hex);
   N:=0;
   If Tok=T_COMMA Then NextTok Else Break;
  Until CHalt;
  Skip(T_RP);
  If Typed Then AdjSP(4);
 End Else Begin
  LoadImm(0);PushD0;Svc(S_SELOUT);
 End;
 If Typed Then Begin End
 Else If Ln Then Svc(S_WRLN);
End;

Procedure PRead(Ln: Boolean);
Var N,T,K: Integer; F: Integer; Typed: Boolean;
Begin
 Typed:=False;
 If Tok=T_LP Then Begin
  NextTok;
  N:=PExpr;
  If FileArg(N) Then Begin
   Typed:=(Ty[Nd[N].Ty].Base<>0);
   PushFileAddr(N);
   If Not Typed Then Svc(S_SELIN);
   If Tok=T_COMMA Then NextTok;
  End Else Begin
   LoadImm(0);PushD0;Svc(S_SELIN);
   If Not IsLval(N) Then Err(12) Else Begin
    T:=Nd[N].Ty;K:=Ty[T].K;
    AddrToA0(N);PushA0;
    If IsIntLike(T) Then Begin PushImm(Ty[T].Size);Svc(S_RDI);End
    Else If K=TK_CHAR Then Svc(S_RDC)
    Else If K=TK_STR Then Begin PushImm(Ty[T].Hi);Svc(S_RDS);End
    Else If K=TK_REAL Then Svc(S_RDR)
    Else Err(5);
   End;
   If Tok=T_COMMA Then NextTok;
  End;
  While (Tok<>T_RP) And (Tok<>T_EOF) And (Not CHalt) Do Begin
   N:=PExpr;
   If Not IsLval(N) Then Err(12) Else Begin
    T:=Nd[N].Ty;K:=Ty[T].K;
    If Typed Then Begin
     E16($2F17);AddrToA0(N);PushA0;PushImm(Ty[T].Size);Svc(S_FREAD);
    End Else Begin
     AddrToA0(N);PushA0;
     If IsIntLike(T) Then Begin PushImm(Ty[T].Size);Svc(S_RDI);End
     Else If K=TK_CHAR Then Svc(S_RDC)
     Else If K=TK_STR Then Begin PushImm(Ty[T].Hi);Svc(S_RDS);End
     Else If K=TK_REAL Then Svc(S_RDR)
     Else Err(5);
    End;
   End;
   If Tok=T_COMMA Then NextTok Else Break;
  End;
  Skip(T_RP);
  If Typed Then AdjSP(4);
 End Else Begin
  LoadImm(0);PushD0;Svc(S_SELIN);
 End;
 If Ln And (Not Typed) Then Svc(S_RDLN);
End;

Procedure StoreFromD0(L: Integer);
Var A: TAddr;
Begin
 If NeedsD0(L) Then Begin PushD0;A:=GenAddr(L);PopD0;End
 Else A:=GenAddr(L);
 StOrd(A,4);
End;

Procedure PStdProc(Id: Integer);
Var N,A,B,C,I,K: Integer; T: Integer; Sig: String; First,Last,E: Integer; Es: LongInt;
Begin
 Case Id Of
  P_WRITE: PWrite(False);
  P_WRITELN: PWrite(True);
  P_READ: PRead(False);
  P_READLN: PRead(True);
  P_PAGE: Begin
    If Tok=T_LP Then Begin NextTok;A:=PExpr;Skip(T_RP);PushFileAddr(A);End
    Else Begin LoadImm(0);PushD0;End;
    Svc(S_FPAGE);
   End;
  P_NEW: Begin
    Skip(T_LP);A:=PExpr;Skip(T_RP);
    If (Not IsLval(A)) Or (Ty[Nd[A].Ty].K<>TK_PTR) Then Err(24)
    Else Begin
     PushImm(Ty[Ty[Nd[A].Ty].Base].Size);Svc(S_NEW);
     StoreFromD0(A);
    End;
   End;
  P_DISPOSE: Begin Skip(T_LP);A:=PExpr;Skip(T_RP);End;
  P_MARK: Begin
    Skip(T_LP);A:=PExpr;Skip(T_RP);
    If (Not IsLval(A)) Or (Ty[Nd[A].Ty].K<>TK_PTR) Then Err(24)
    Else Begin Svc(S_MARK);StoreFromD0(A);End;
   End;
  P_RELEASE: Begin
    Skip(T_LP);A:=PExpr;Skip(T_RP);
    Expr(A);PushD0;Svc(S_RELEASE);
   End;
  P_INSERT: Begin
    Skip(T_LP);A:=ToStrN(PExpr);Skip(T_COMMA);B:=PExpr;Skip(T_COMMA);C:=PExpr;Skip(T_RP);
    If (Not IsLval(B)) Or (Ty[Nd[B].Ty].K<>TK_STR) Then Err(31)
    Else Begin
     Expr(A);PushD0;AddrToA0(B);PushA0;Expr(C);PushD0;PushImm(Ty[Nd[B].Ty].Hi);Svc(S_SINS);
    End;
   End;
  P_DELETE: Begin
    Skip(T_LP);A:=PExpr;Skip(T_COMMA);B:=PExpr;Skip(T_COMMA);C:=PExpr;Skip(T_RP);
    If (Not IsLval(A)) Or (Ty[Nd[A].Ty].K<>TK_STR) Then Err(31)
    Else Begin
     AddrToA0(A);PushA0;Expr(B);PushD0;Expr(C);PushD0;Svc(S_SDEL);
    End;
   End;
  P_RESET,P_REWRITE: Begin
    Skip(T_LP);A:=PExpr;Skip(T_COMMA);B:=ToStrN(PExpr);Skip(T_RP);
    If Not FileArg(A) Then Err(38)
    Else Begin
     AddrToA0(A);PushA0;Expr(B);PushD0;
     If Ty[Nd[A].Ty].Base=0 Then PushImm(0)
     Else Begin
      Es:=Ty[Ty[Nd[A].Ty].Base].Size;
      If Es<1 Then Es:=1;
      PushImm(Es);
     End;
     If Id=P_RESET Then PushImm(0) Else PushImm(1);
     Svc(S_FRESET);
    End;
   End;
  P_CLOSE: Begin
    Skip(T_LP);A:=PExpr;Skip(T_RP);
    If Not FileArg(A) Then Err(38) Else Begin AddrToA0(A);PushA0;Svc(S_FCLOSE);End;
   End;
  P_SEEK: Begin
    Skip(T_LP);A:=PExpr;Skip(T_COMMA);B:=PExpr;Skip(T_RP);
    If Not FileArg(A) Then Err(38) Else Begin AddrToA0(A);PushA0;Expr(B);PushD0;Svc(S_FSEEK);End;
   End;
  P_GET,P_PUT: Begin
    Skip(T_LP);A:=PExpr;Skip(T_RP);
    If (Not FileArg(A)) Or (Ty[Nd[A].Ty].Base=0) Then Err(38)
    Else Begin AddrToA0(A);PushA0;If Id=P_GET Then Svc(S_GET) Else Svc(S_PUT);End;
   End;
  P_ERASE: Begin
    Skip(T_LP);A:=PExpr;Skip(T_RP);
    If FileArg(A) Then Begin AddrToA0(A);PushA0;Svc(S_FERASEF);End
    Else Begin A:=ToStrN(A);Expr(A);PushD0;Svc(S_FERASE);End;
   End;
  P_PACK: Begin
    { Pack(vnonpack, debut, vpack) }
    Skip(T_LP);A:=PExpr;Skip(T_COMMA);B:=PExpr;Skip(T_COMMA);C:=PExpr;Skip(T_RP);
    If (Not IsLval(A)) Or (Ty[Nd[A].Ty].K<>TK_ARR) Or (Not IsLval(C)) Or (Ty[Nd[C].Ty].K<>TK_ARR) Then Err(5)
    Else Begin
     AddrToA0(A);PushA0;Expr(B);PushD0;
     PushImm(Ty[Ty[Nd[A].Ty].Idx].Lo);PushImm(Ty[Ty[Nd[A].Ty].Idx].Hi-Ty[Ty[Nd[A].Ty].Idx].Lo+1);
     AddrToA0(C);PushA0;
     PushImm(Ty[Ty[Nd[C].Ty].Idx].Hi-Ty[Ty[Nd[C].Ty].Idx].Lo+1);
     PushImm(ElemStride(Nd[A].Ty));
     Svc(S_PACK);
    End;
   End;
  P_UNPACK: Begin
    { UnPack(vpack, vnonpack, debut) }
    Skip(T_LP);A:=PExpr;Skip(T_COMMA);B:=PExpr;Skip(T_COMMA);C:=PExpr;Skip(T_RP);
    If (Not IsLval(A)) Or (Ty[Nd[A].Ty].K<>TK_ARR) Or (Not IsLval(B)) Or (Ty[Nd[B].Ty].K<>TK_ARR) Then Err(5)
    Else Begin
     AddrToA0(A);PushA0;
     PushImm(Ty[Ty[Nd[A].Ty].Idx].Hi-Ty[Ty[Nd[A].Ty].Idx].Lo+1);
     AddrToA0(B);PushA0;Expr(C);PushD0;
     PushImm(Ty[Ty[Nd[B].Ty].Idx].Lo);PushImm(Ty[Ty[Nd[B].Ty].Idx].Hi-Ty[Ty[Nd[B].Ty].Idx].Lo+1);
     PushImm(ElemStride(Nd[A].Ty));
     Svc(S_UNPACK);
    End;
   End;
  P_HALT: Begin
    If Tok=T_LP Then Begin NextTok;A:=PExpr;Skip(T_RP);Expr(A);End Else LoadImm(0);
    PushD0;Svc(S_HALT);
   End;
  P_POKE,P_WPOKE,P_LPOKE: Begin
    Skip(T_LP);A:=PExpr;Skip(T_COMMA);B:=PExpr;Skip(T_RP);
    Expr(A);PushD0;Expr(B);PushD0;
    If Id=P_POKE Then Svc(S_POKEB) Else If Id=P_WPOKE Then Svc(S_POKEW) Else Svc(S_POKEL);
   End;
  P_MOVEB: Begin
    Skip(T_LP);A:=PExpr;Skip(T_COMMA);B:=PExpr;Skip(T_COMMA);C:=PExpr;Skip(T_RP);
    Expr(A);PushD0;Expr(B);PushD0;Expr(C);PushD0;Svc(S_MOVEB);
   End;
 Else
  If Id>=1000 Then Begin
   I:=Id-1000;Sig:=HSig[I];
   If Sig<>'' Then Begin
    Skip(T_LP);
    For K:=1 To Length(Sig) Do Begin
     A:=PExpr;
     Case Sig[K] Of
      'I': Begin If Not IsOrd(Nd[A].Ty) Then Err(11);Expr(A);PushD0;End;
      'S': Begin A:=Coerce(A,TY_STRLIT);Expr(A);PushD0;End;
      'R': Begin A:=Coerce(A,TY_REAL);Expr(A);PushReal;End;
      'V': Begin If Not IsLval(A) Then Err(12) Else Begin AddrToA0(A);PushA0;End;End;
     End;
     If K<Length(Sig) Then Skip(T_COMMA);
    End;
    Skip(T_RP);
   End Else If Tok=T_LP Then Begin NextTok;Skip(T_RP);End;
   Svc(HSvc[I]);
  End Else Err(14);
 End;
End;

{ ------------------------- instructions ------------------------------- }

Function FindRLab(Num: LongInt): Integer;
Var I: Integer;
Begin
 FindRLab:=0;
 For I:=RLabN DownTo RLabBase+1 Do If RLabNum[I]=Num Then Begin FindRLab:=I;Exit;End;
End;

Function IsFuncName(Const Nm: String): Integer;
Var L: Integer;
Begin
 IsFuncName:=0;
 For L:=CurLvl DownTo 2 Do
  If (FuncStk[L]<>0) And (Sy[FuncStk[L]].K=SK_FUNC) And (Sy[FuncStk[L]].Name=Nm) Then Begin
   IsFuncName:=FuncStk[L];Exit;
  End;
End;

Procedure PCompound(Stop: Integer);
Begin
 While (Tok<>Stop) And (Tok<>T_EOF) And (Not CHalt) Do Begin
  PStatement;
  If Tok=T_SEMI Then NextTok
  Else If (Tok<>Stop) And (Tok<>K_ELSE) Then Begin
   If Tok=K_END Then Break;
   ErrExp(';');
   { resynchronisation }
   While (Tok<>T_SEMI) And (Tok<>Stop) And (Tok<>K_END) And (Tok<>T_EOF) Do NextTok;
   If Tok=T_SEMI Then NextTok;
  End;
 End;
End;

Procedure PIf;
Var C,Lelse,Lend: Integer;
Begin
 NextTok;
 C:=PBool;Expr(C);TstD0;
 Lelse:=NewLab;BraLab(7,Lelse);
 Skip(K_THEN);
 PStatement;
 If Tok=K_ELSE Then Begin
  Lend:=NewLab;BraLab(0,Lend);Place(Lelse);
  NextTok;PStatement;Place(Lend);
 End Else Place(Lelse);
End;

Procedure PWhile;
Var C,Ltop,Lend: Integer;
Begin
 NextTok;
 Ltop:=NewLab;Lend:=NewLab;Place(Ltop);
 C:=PBool;Expr(C);TstD0;BraLab(7,Lend);
 Skip(K_DO);
 PStatement;
 BraLab(0,Ltop);Place(Lend);
End;

Procedure PRepeat;
Var C,Ltop: Integer;
Begin
 NextTok;
 Ltop:=NewLab;Place(Ltop);
 PCompound(K_UNTIL);
 Skip(K_UNTIL);
 NdN:=0;
 C:=PBool;Expr(C);TstD0;BraLab(7,Ltop);
End;

Procedure PLoop;
Var Ltop,Lend: Integer;
Begin
 NextTok;
 Ltop:=NewLab;Lend:=NewLab;Place(Ltop);
 If LoopN<MAXLOOP Then Begin Inc(LoopN);LoopExit[LoopN]:=Lend;End;
 PCompound(K_END);
 Skip(K_END);
 BraLab(0,Ltop);Place(Lend);
 Dec(LoopN);
End;

Procedure PExitIf;
Var C: Integer;
Begin
 NextTok;
 If Tok<>K_IF Then Begin ErrExp('IF');Exit;End;
 NextTok;
 C:=PBool;Expr(C);TstD0;
 If LoopN<1 Then Err(19) Else BraLab(6,LoopExit[LoopN]);
End;


Procedure LdD1(A: TAddr);
Begin
 Normalize(A);
 E16($2228 Or ARegOf(A));E16(ADisp(A));
End;

Procedure PFor;
Var V,A,B: Integer; Down: Boolean; Lt,Lend: Integer; VA,TA: TAddr; Sz: LongInt;
Begin
 NextTok;
 If Tok<>T_ID Then Begin Err(1);Exit;End;
 V:=PFactor;
 If Nd[V].Op<>N_VAR Then Err(12);
 If Not IsOrd(Nd[V].Ty) Then Err(9);
 Skip(T_ASSIGN);
 A:=PExpr;
 If Tok=K_DOWNTO Then Begin Down:=True;NextTok;End
 Else Begin Down:=False;Skip(K_TO);End;
 B:=PExpr;
 Skip(K_DO);
 If CHalt Then Exit;
 Sz:=Ty[Nd[V].Ty].Size;
 TA:=AllocTemp(4);
 VA:=GenAddr(V);
 If VA.M=2 Then Err(44);
 A:=Coerce(A,Nd[V].Ty);
 Expr(A);StOrd(VA,Sz);
 Expr(B);StOrd(TA,4);
 Lt:=NewLab;Lend:=NewLab;
 Place(Lt);
 LdOrd(VA,Sz);LdD1(TA);E16($B081);
 If Down Then BraLab(13,Lend) Else BraLab(14,Lend);
 PStatement;
 LdOrd(VA,Sz);LdD1(TA);E16($B081);BraLab(7,Lend);
 If Down Then E16($5380) Else E16($5280);
 StOrd(VA,Sz);
 BraLab(0,Lt);Place(Lend);
End;

Procedure PCase;
Var S,Lb,Ltests,Lend,Lother,I,N: Integer; V1,V2: LongInt; P: LongInt;
    LV1,LV2: Array[1..160] Of LongInt; LL: Array[1..160] Of Integer;
Begin
 NextTok;
 S:=PExpr;
 If Not IsOrd(Nd[S].Ty) Then Err(9);
 Skip(K_OF);
 Expr(S);
 Ltests:=NewLab;Lend:=NewLab;Lother:=0;N:=0;
 BraLab(0,Ltests);
 While (Tok<>K_END) And (Tok<>K_OTHERWISE) And (Tok<>T_EOF) And (Not CHalt) Do Begin
  Lb:=NewLab;
  Repeat
   NdN:=0;
   If PConstInt(V1) Then Begin End;
   V2:=V1;
   If Tok=T_DOTDOT Then Begin NextTok;PConstInt(V2);End;
   If N<160 Then Begin Inc(N);LV1[N]:=V1;LV2[N]:=V2;LL[N]:=Lb;End Else Err(32);
   If Tok=T_COMMA Then NextTok Else Break;
  Until CHalt;
  Skip(T_COLON);
  Place(Lb);
  PStatement;
  BraLab(0,Lend);
  If Tok=T_SEMI Then NextTok
  Else If (Tok<>K_END) And (Tok<>K_OTHERWISE) Then Begin
   ErrExp(';');
   While (Tok<>T_SEMI) And (Tok<>K_END) And (Tok<>K_OTHERWISE) And (Tok<>T_EOF) Do NextTok;
   If Tok=T_SEMI Then NextTok;
  End;
 End;
 If Tok=K_OTHERWISE Then Begin
  NextTok;
  Lother:=NewLab;Place(Lother);
  PCompound(K_END);
  BraLab(0,Lend);
 End;
 Skip(K_END);
 Place(Ltests);
 For I:=1 To N Do Begin
  If LV1[I]=LV2[I] Then Begin
   E16($0C80);E32(LV1[I]);BraLab(7,LL[I]);
  End Else Begin
   E16($0C80);E32(LV1[I]);P:=BccS(13);
   E16($0C80);E32(LV2[I]);BraLab(15,LL[I]);
   PatchS(P);
  End;
 End;
 If Lother<>0 Then BraLab(0,Lother);
 Place(Lend);
End;

Procedure PWith;
Var N,Cnt: Integer; TA,A: TAddr;
Begin
 NextTok;Cnt:=0;
 Repeat
  N:=PExpr;
  If (Not IsLval(N)) Or (Ty[Nd[N].Ty].K<>TK_REC) Then Err(25)
  Else If WithN<MAXWITH Then Begin
   TA:=AllocTemp(4);
   A:=GenAddr(N);LeaA0(A);StA0(TA);
   Inc(WithN);Inc(Cnt);
   Withs[WithN].Ty:=Nd[N].Ty;Withs[WithN].Slot:=TA.D;Withs[WithN].Lvl:=CurLvl;
  End;
  If Tok=T_COMMA Then NextTok Else Break;
 Until CHalt;
 Skip(K_DO);
 PStatement;
 Dec(WithN,Cnt);
End;

Procedure PGoto;
Var Lb: Integer;
Begin
 NextTok;
 If Tok<>T_INT Then Begin Err(20);Exit;End;
 Lb:=FindRLab(TokI);
 If Lb=0 Then Err(20) Else BraLab(0,RLabLab[Lb]);
 NextTok;
End;

Procedure PAssignOrCall;
Var Nm: String; S,N,R,F,I,Args: Integer; IsWith: Boolean; Tgt: Integer;
Begin
 Nm:=TokS;
 DebugLine;
 IsWith:=False;
 For I:=WithN DownTo 1 Do If FindFld(Withs[I].Ty,Nm)<>0 Then IsWith:=True;
 If Not IsWith Then Begin
  S:=FindSym(Nm);
  If S=0 Then Begin
   Err(3);
   While (Tok<>T_SEMI) And (Tok<>K_END) And (Tok<>T_EOF) And (Tok<>K_ELSE) And (Tok<>K_UNTIL) Do NextTok;
   Exit;
  End;
  Case Sy[S].K Of
   SK_VAR: If Sy[S].Tpl<>0 Then Begin
     { appel d'une procedure/fonction recue en parametre }
     NextTok;
     Args:=PArgs(Sy[S].Tpl);
     GCVia:=S;
     GenCall(Sy[S].Tpl,Args);
     Exit;
    End;
   SK_PROC,SK_FUNC: Begin
     F:=0;
     If Sy[S].K=SK_FUNC Then F:=IsFuncName(Nm);
     NextTok;
     If (F<>0) And (Tok=T_ASSIGN) Then Begin
      NextTok;
      N:=NewNd(N_VAR,Sy[F].Ty);Nd[N].Sym:=Sy[F].Res;
      R:=PExpr;R:=Coerce(R,Sy[F].Ty);
      If (Not IsAgg(Sy[F].Ty)) Or (Ty[Sy[F].Ty].K=TK_STR) Then GenAssign(N,R) Else Err(35);
      Exit;
     End;
     Args:=PArgs(S);
     GenCall(S,Args);
     Exit;
    End;
   SK_STD: Begin NextTok;PStdProc(Sy[S].Std);Exit;End;
   SK_CONST,SK_TYPE: Begin Err(35);NextTok;Exit;End;
  End;
 End;
 N:=PFactor;
 If CHalt Then Exit;
 If Not IsLval(N) Then Begin Err(12);Exit;End;
 Skip(T_ASSIGN);
 R:=PExpr;
 R:=Coerce(R,Nd[N].Ty);
 If Not CHalt Then GenAssign(N,R);
End;

Procedure PStatement;
Var Lb: Integer;
Begin
 NdN:=0;
 If CHalt Then Exit;
 While Tok=T_INT Do Begin
  Lb:=FindRLab(TokI);
  If Lb=0 Then Err(20) Else Begin Place(RLabLab[Lb]);RLabDef[Lb]:=True;End;
  NextTok;Skip(T_COLON);NdN:=0;
 End;
 Case Tok Of
  K_BEGIN: Begin NextTok;PCompound(K_END);Skip(K_END);End;
  K_IF: Begin DebugLine;PIf;End;
  K_WHILE: Begin DebugLine;PWhile;End;
  K_REPEAT: PRepeat;
  K_FOR: Begin DebugLine;PFor;End;
  K_LOOP: PLoop;
  K_CASE: Begin DebugLine;PCase;End;
  K_WITH: PWith;
  K_GOTO: Begin DebugLine;PGoto;End;
  T_ID: Begin
    If (TokS='EXIT') And (FindSym('EXIT')=0) Then Begin DebugLine;PExitIf;End
    Else PAssignOrCall;
   End;
  T_SEMI,K_END,K_ELSE,K_UNTIL,T_EOF: ;
 Else
  Err(19);
  If Tok<>T_EOF Then NextTok;
 End;
End;

{ ------------------------- declarations de types --------------------- }

Procedure PType(Var T: Integer); Forward;

Procedure PSubrangeType(Var T: Integer);
Var N1,N2: Integer; V1,V2: LongInt; R: Double; IsR: Boolean; Base: Integer;
Begin
 N1:=PSimple;
 If Not (ConstEval(N1,V1,R,IsR) And (Not IsR)) Then Begin Err(7);V1:=0;End;
 Base:=Nd[N1].Ty;
 Skip(T_DOTDOT);
 N2:=PSimple;
 If Not (ConstEval(N2,V2,R,IsR) And (Not IsR)) Then Begin Err(7);V2:=0;End;
 If V2<V1 Then Begin Err(42);V2:=V1;End;
 If Not IsOrd(Base) Then Err(9);
 T:=MakeSub(Base,V1,V2);
End;

Procedure PFields(Var Off: LongInt; Var First,Last: Integer);
Var Names: Array[1..24] Of String[40]; NN,I,FT,F: Integer; Base,Mx: LongInt; V: LongInt; Tag: String;
    T2: Integer; SF,SL: Integer;
Begin
 While (Tok=T_ID) And (Not CHalt) Do Begin
  NN:=0;
  Repeat
   If Tok<>T_ID Then Begin Err(1);Break;End;
   If NN<24 Then Begin Inc(NN);Names[NN]:=TokS;End;
   NextTok;
   If Tok=T_COMMA Then NextTok Else Break;
  Until CHalt;
  Skip(T_COLON);
  PType(FT);
  For I:=1 To NN Do Begin
   If FlN>=MAXFLD Then Begin Err(41);Exit;End;
   Inc(FlN);F:=FlN;
   Fl[F].Name:=Names[I];Fl[F].Ty:=FT;Fl[F].Next:=0;
   If (Ty[FT].Size>1) And Odd(Off) Then Inc(Off);
   Fl[F].Off:=Off;
   Off:=Off+Ty[FT].Size;
   If Last=0 Then First:=F Else Fl[Last].Next:=F;
   Last:=F;
  End;
  If Tok=T_SEMI Then NextTok Else Break;
 End;
 If Tok=K_CASE Then Begin
  NextTok;
  If Tok=T_ID Then Begin
   Tag:=TokS;NextTok;
   If Tok=T_COLON Then Begin
    NextTok;PType(FT);
    If FlN<MAXFLD Then Begin
     Inc(FlN);F:=FlN;Fl[F].Name:=Tag;Fl[F].Ty:=FT;Fl[F].Next:=0;
     If (Ty[FT].Size>1) And Odd(Off) Then Inc(Off);
     Fl[F].Off:=Off;Off:=Off+Ty[FT].Size;
     If Last=0 Then First:=F Else Fl[Last].Next:=F;
     Last:=F;
    End;
   End;
  End Else Err(1);
  Skip(K_OF);
  Base:=Off;Mx:=Off;
  While (Tok<>K_END) And (Tok<>T_RP) And (Tok<>T_EOF) And (Not CHalt) Do Begin
   Repeat
    NdN:=0;PConstInt(V);
    If Tok=T_COMMA Then NextTok Else Break;
   Until CHalt;
   Skip(T_COLON);Skip(T_LP);
   Off:=Base;
   PFields(Off,First,Last);
   Skip(T_RP);
   If Off>Mx Then Mx:=Off;
   If Tok=T_SEMI Then NextTok Else Break;
  End;
  Off:=Mx;
 End;
End;

Procedure PType(Var T: Integer);
Var S,I,N: Integer; Idx: Array[1..8] Of Integer; NI: Integer; V: LongInt; E: Integer; Off: LongInt;
    First,Last: Integer; B: Integer; Nm: String;
Begin
 T:=TY_INT;
 Case Tok Of
  K_PACKED: Begin NextTok;PType(T);End;
  T_CARET: Begin
    NextTok;
    If Tok<>T_ID Then Begin Err(1);Exit;End;
    S:=FindSym(TokS);
    If (S<>0) And (Sy[S].K=SK_TYPE) Then T:=MakePtr(Sy[S].Ty)
    Else Begin
     T:=MakePtr(0);
     If PendN<MAXPEND Then Begin Inc(PendN);PendTy[PendN]:=T;PendNm[PendN]:=TokS;End;
    End;
    NextTok;
   End;
  T_LP: Begin
    NextTok;N:=0;
    T:=NewTy(TK_ENUM,1);
    Repeat
     If Tok<>T_ID Then Begin Err(1);Break;End;
     DefConst(TokS,T,N);Inc(N);NextTok;
     If Tok=T_COMMA Then NextTok Else Break;
    Until CHalt;
    Skip(T_RP);
    Ty[T].Lo:=0;Ty[T].Hi:=N-1;
    If N>256 Then Ty[T].Size:=2;
   End;
  K_ARRAY: Begin
    NextTok;Skip(T_LB);NI:=0;
    Repeat
     If NI<8 Then Inc(NI);
     If (Tok=T_ID) And (FindSym(TokS)<>0) And (Sy[FindSym(TokS)].K=SK_TYPE) Then Begin
      Idx[NI]:=Sy[FindSym(TokS)].Ty;NextTok;
      If Not IsOrd(Idx[NI]) Then Err(9);
     End Else PSubrangeType(Idx[NI]);
     If Tok=T_COMMA Then NextTok Else Break;
    Until CHalt;
    Skip(T_RB);Skip(K_OF);
    PType(B);
    For I:=NI DownTo 1 Do B:=MakeArr(Idx[I],B);
    T:=B;
   End;
  K_RECORD: Begin
    NextTok;Off:=0;First:=0;Last:=0;
    PFields(Off,First,Last);
    Skip(K_END);
    T:=NewTy(TK_REC,(Off+1) And (Not 1));
    Ty[T].F1:=First;
   End;
  K_SET: Begin
    NextTok;Skip(K_OF);
    PType(B);
    If Not IsOrd(B) Then Err(9)
    Else If (Ty[B].Lo<0) Or (Ty[B].Hi>255) Then Err(30);
    T:=MakeSet(B);
   End;
  K_FILE: Begin
    NextTok;Skip(K_OF);
    PType(B);
    T:=MakeFile(B);
   End;
  T_ID: Begin
    S:=FindSym(TokS);
    If (S<>0) And (Sy[S].K=SK_TYPE) Then Begin
     T:=Sy[S].Ty;
     Nm:=TokS;
     If LongIntOn And (Nm='INTEGER') Then T:=TY_LONG;
     NextTok;
     If (Nm='STRING') And (Tok=T_LB) Then Begin
      NextTok;PConstInt(V);Skip(T_RB);
      T:=MakeStr(V);
     End;
    End Else If (S<>0) And (Sy[S].K=SK_CONST) Then PSubrangeType(T)
    Else Begin Err(8);NextTok;End;
   End;
  T_INT,T_MINUS,T_PLUS,T_STR: PSubrangeType(T);
 Else
  Err(8);
 End;
End;

Procedure ResolvePending;
Var I,S: Integer;
Begin
 For I:=1 To PendN Do Begin
  S:=FindSym(PendNm[I]);
  If (S=0) Or (Sy[S].K<>SK_TYPE) Then Begin Err(3);Ty[PendTy[I]].Base:=TY_INT;End
  Else Ty[PendTy[I]].Base:=Sy[S].Ty;
 End;
 PendN:=0;
End;

Procedure PConstSection;
Var Nm: String; S,N: Integer; V: LongInt; R: Double; IsR: Boolean;
Begin
 NextTok;
 While (Tok=T_ID) And (Not CHalt) Do Begin
  Nm:=TokS;NextTok;
  Skip(T_EQ);
  NdN:=0;
  If Tok=T_STR Then Begin
   If Length(TokS)=1 Then Begin
    S:=AddSym(Nm,SK_CONST,TY_CHAR);Sy[S].Off:=Ord(TokS[1]);
   End Else Begin
    S:=AddSym(Nm,SK_CONST,TY_STRLIT);Sy[S].SVal:=TokS;
   End;
   NextTok;
  End Else Begin
   N:=PExpr;
   If ConstEval(N,V,R,IsR) Then Begin
    If IsR Then Begin S:=AddSym(Nm,SK_CONST,TY_REAL);Sy[S].RVal:=R;End
    Else Begin
     If Ty[Nd[N].Ty].K=TK_INT Then S:=AddSym(Nm,SK_CONST,IntTy(V))
     Else If Ty[Nd[N].Ty].K=TK_LONG Then S:=AddSym(Nm,SK_CONST,IntTy(V))
     Else S:=AddSym(Nm,SK_CONST,Nd[N].Ty);
     Sy[S].Off:=V;
    End;
   End Else Begin
    Err(7);S:=AddSym(Nm,SK_CONST,TY_INT);
   End;
  End;
  Skip(T_SEMI);
 End;
End;

Procedure PTypeSection;
Var Nm: String; T,S: Integer;
Begin
 NextTok;
 While (Tok=T_ID) And (Not CHalt) Do Begin
  Nm:=TokS;NextTok;
  Skip(T_EQ);
  PType(T);
  S:=AddSym(Nm,SK_TYPE,T);
  Skip(T_SEMI);
 End;
 ResolvePending;
End;

Function AllocVar(Size: LongInt): LongInt;
Begin
 If Odd(Size) Then Inc(Size);
 If CurLvl<=1 Then Begin
  AllocVar:=GSize;GSize:=GSize+Size;
  If GSize>65500 Then Begin Err(26);GSize:=0;End;
 End Else Begin
  LocSize:=LocSize+Size;
  AllocVar:=-LocSize;
  If LocSize>32000 Then Begin Err(26);LocSize:=2;End;
 End;
End;

Procedure PVarSection;
Var Names: Array[1..24] Of String[40]; NN,I,T,S: Integer;
Begin
 NextTok;
 While (Tok=T_ID) And (Not CHalt) Do Begin
  NN:=0;
  Repeat
   If Tok<>T_ID Then Begin Err(1);Break;End;
   If NN<24 Then Begin Inc(NN);Names[NN]:=TokS;End;
   NextTok;
   If Tok=T_COMMA Then NextTok Else Break;
  Until CHalt;
  Skip(T_COLON);
  PType(T);
  For I:=1 To NN Do Begin
   S:=AddSym(Names[I],SK_VAR,T);
   Sy[S].Off:=AllocVar(Ty[T].Size);
  End;
  Skip(T_SEMI);
 End;
 ResolvePending;
End;

Procedure PLabelSection;
Begin
 NextTok;
 Repeat
  If Tok=T_INT Then Begin
   If RLabN<MAXRLAB Then Begin
    Inc(RLabN);RLabNum[RLabN]:=TokI;RLabLab[RLabN]:=NewLab;RLabDef[RLabN]:=False;
   End;
   NextTok;
  End Else Begin Err(11);Break;End;
  If Tok=T_COMMA Then NextTok Else Break;
 Until CHalt;
 Skip(T_SEMI);
End;

{ ------------------------- sous-programmes --------------------------- }

Procedure PDecls; Forward;

Procedure PProcHeader(Var Tpl: Integer; Var PNm: String); Forward;

{ liste de parametres formels "( ... )" : Tok = '(' ; les parametres sont ajoutes
  de facon contigue dans Pm (les modeles des parametres procéduraux d'abord) }
Procedure PParamList(Var First,Cnt: Integer; Var PSz: LongInt);
Var LP: Array[1..40] Of TParm; LN,NN,K,PT,Tpl: Integer; Ref: Boolean;
    Names: Array[1..20] Of String[40]; PNm: String;
Begin
 LN:=0;PSz:=0;
 NextTok;
 While (Tok<>T_RP) And (Tok<>T_EOF) And (Not CHalt) Do Begin
  If (Tok=K_PROCEDURE) Or (Tok=K_FUNCTION) Then Begin
   { parametre procedural ou fonctionnel }
   PProcHeader(Tpl,PNm);
   If LN>=40 Then Begin Err(41);Break;End;
   Inc(LN);
   LP[LN].Name:=PNm;LP[LN].Ty:=TY_VOID;LP[LN].Ref:=False;LP[LN].Slot:=8;LP[LN].Proc:=Tpl;
   LP[LN].Off:=0;
   PSz:=PSz+8;
  End Else Begin
   Ref:=False;
   If Tok=K_VAR Then Begin Ref:=True;NextTok;End;
   NN:=0;
   Repeat
    If Tok<>T_ID Then Begin Err(1);Break;End;
    If NN<20 Then Begin Inc(NN);Names[NN]:=TokS;End;
    NextTok;
    If Tok=T_COMMA Then NextTok Else Break;
   Until CHalt;
   Skip(T_COLON);
   PType(PT);
   For K:=1 To NN Do Begin
    If LN>=40 Then Begin Err(41);Break;End;
    Inc(LN);
    LP[LN].Name:=Names[K];LP[LN].Ty:=PT;LP[LN].Ref:=Ref;LP[LN].Proc:=0;LP[LN].Off:=0;
    If (Not Ref) And (Ty[PT].K=TK_REAL) Then LP[LN].Slot:=8 Else LP[LN].Slot:=4;
    PSz:=PSz+LP[LN].Slot;
   End;
  End;
  If Tok=T_SEMI Then NextTok Else Break;
 End;
 Skip(T_RP);
 { copie contigue dans Pm }
 First:=PmN+1;Cnt:=LN;
 For K:=1 To LN Do Begin
  If PmN>=MAXPARM Then Begin Err(41);Break;End;
  Inc(PmN);Pm[PmN]:=LP[K];
 End;
End;

{ en-tete d'un parametre procedural : PROCEDURE p(...) ou FUNCTION f(...) : type }
Procedure PProcHeader(Var Tpl: Integer; Var PNm: String);
Var IsF: Boolean; S,First,Cnt: Integer; PSz: LongInt; T: Integer;
Begin
 IsF:=(Tok=K_FUNCTION);
 NextTok;
 PNm:='';
 If Tok=T_ID Then Begin PNm:=TokS;NextTok;End Else Err(1);
 If IsF Then S:=AddSym('',SK_FUNC,TY_VOID) Else S:=AddSym('',SK_PROC,TY_VOID);
 Sy[S].Name:='';
 First:=PmN+1;Cnt:=0;PSz:=0;
 If Tok=T_LP Then PParamList(First,Cnt,PSz);
 Sy[S].PFirst:=First;Sy[S].PCnt:=Cnt;Sy[S].PSize:=PSz;
 If IsF Then Begin
  Skip(T_COLON);
  PType(T);
  If IsAgg(T) And (Ty[T].K<>TK_STR) Then Err(35);
  Sy[S].Ty:=T;
 End;
 Tpl:=S;
End;

Procedure PProcDecl;
Var IsF,Ref: Boolean; Nm: String; S,I,K,Cnt,First,NN,T,PT,LinkPos: Integer;
    Names: Array[1..20] Of String[40]; SavedSyN,SavedBase,SavedRN: Integer; OldLoc,PSz,Off,V: LongInt;
    OldWithN,OldLoopN: Integer; Res: Integer;
    CpSlot,CpLoc,CpSize: Array[1..30] Of LongInt; NCp: Integer;
    ClrPos1,ClrPos2: LongInt; P2: LongInt; Ad: TAddr; Ps: Integer; Sl: LongInt; Pr: TParm;
Begin
 IsF:=(Tok=K_FUNCTION);
 NextTok;
 If Tok<>T_ID Then Begin Err(1);Exit;End;
 Nm:=TokS;NextTok;
 S:=0;
 I:=SyN;
 While (I>0) And (Sy[I].Lvl=CurLvl) Do Begin
  If (Sy[I].Name=Nm) And Sy[I].Fwd Then Begin S:=I;Break;End;
  Dec(I);
 End;
 If S=0 Then Begin
  If IsF Then S:=AddSym(Nm,SK_FUNC,TY_VOID) Else S:=AddSym(Nm,SK_PROC,TY_VOID);
  Sy[S].Lab:=NewLab;LabNm[Sy[S].Lab]:=Copy(Nm,1,24);
  First:=PmN+1;Cnt:=0;PSz:=0;
  If Tok=T_LP Then PParamList(First,Cnt,PSz);
  Sy[S].PFirst:=First;Sy[S].PCnt:=Cnt;Sy[S].PSize:=PSz;
  If IsF Then Begin
   Skip(T_COLON);
   PType(T);
   If IsAgg(T) And (Ty[T].K<>TK_STR) Then Err(35);
   Sy[S].Ty:=T;
  End;
 End Else Begin
  Sy[S].Fwd:=False;IsF:=(Sy[S].K=SK_FUNC);
 End;
 Skip(T_SEMI);
 { directives }
 If Tok=T_ID Then Begin
  If TokS='FORWARD' Then Begin Sy[S].Fwd:=True;NextTok;Skip(T_SEMI);Exit;End;
  If (TokS='EXTERNAL') Or (TokS='C') Then Begin
   Sy[S].Dir:=4;LabExt[Sy[S].Lab]:=True;
   K:=FindHost(Nm);
   If K>0 Then Begin Sy[S].Dir:=5;Sy[S].DirN:=K;End;
   NextTok;Skip(T_SEMI);Exit;
  End;
  If (TokS='GEMDOS') Or (TokS='BIOS') Or (TokS='XBIOS') Then Begin
   If TokS='GEMDOS' Then Sy[S].Dir:=1 Else If TokS='BIOS' Then Sy[S].Dir:=2 Else Sy[S].Dir:=3;
   NextTok;Skip(T_LP);PConstInt(V);Skip(T_RP);Sy[S].DirN:=V;Skip(T_SEMI);
   Exit;
  End;
 End;
 { corps }
 SavedSyN:=SyN;SavedBase:=RLabBase;SavedRN:=RLabN;OldLoc:=LocSize;
 OldWithN:=WithN;OldLoopN:=LoopN;
 WithN:=0;LoopN:=0;
 Inc(CurLvl);
 If CurLvl>18 Then Err(45);
 FuncStk[CurLvl]:=S;
 RLabBase:=RLabN;
 LocSize:=0;
 If Opt.ClearVars Then LocSize:=2;
 NCp:=0;
 { symboles des parametres }
 Off:=12+Sy[S].PSize;
 For I:=1 To Sy[S].PCnt Do Begin
  Pr:=Pm[Sy[S].PFirst+I-1];
  Off:=Off-Pr.Slot;
  Ps:=AddSym(Pr.Name,SK_VAR,Pr.Ty);
  Sy[Ps].Off:=Off;
  If Pr.Proc<>0 Then Sy[Ps].Tpl:=Pr.Proc
  Else If Pr.Ref Then Sy[Ps].Ref:=True
  Else If IsAgg(Pr.Ty) Or (Ty[Pr.Ty].K=TK_ARR) Or (Ty[Pr.Ty].K=TK_REC) Then Begin
   Sl:=AllocVar(Ty[Pr.Ty].Size);
   If NCp<30 Then Begin Inc(NCp);CpSlot[NCp]:=Off;CpLoc[NCp]:=Sl;CpSize[NCp]:=Ty[Pr.Ty].Size;End;
   Sy[Ps].Off:=Sl;
  End Else If (Ty[Pr.Ty].K<>TK_REAL) And (Ty[Pr.Ty].Size<4) Then
   Sy[Ps].Off:=Off+(4-Ty[Pr.Ty].Size);
 End;
 Res:=0;
 If IsF Then Begin
  Res:=AddSym('',SK_VAR,Sy[S].Ty);
  Sy[Res].Off:=AllocVar(Ty[Sy[S].Ty].Size);
  Sy[S].Res:=Res;
 End;
 PDecls;
 { prologue }
 Place(Sy[S].Lab);
 If ExportOn And (CurLvl=2) And (ExpN<60) Then Begin Inc(ExpN);ExpName[ExpN]:=Copy(Nm,1,8);ExpLab[ExpN]:=Sy[S].Lab;End;
 If Opt.FullDebug And (SymCnt<400) Then Begin Inc(SymCnt);SymNames[SymCnt]:=Copy(Nm,1,8);SymAddrLab[SymCnt]:=Sy[S].Lab;End;
 E16($4E56);LinkPos:=CP;E16(0);
 If Opt.StackChk Then Begin
  E16($BFF8);E16($0506);P2:=BccS(2);ErrStub(5);PatchS(P2);
 End;
 If Opt.ClearVars Then Begin
  E16($41EE);ClrPos1:=CP;E16(0);          { LEA -n(A6),A0 }
  E16($203C);ClrPos2:=CP;E32(0);          { MOVE.L #cnt,D0 }
  P2:=CP;E16($4258);E16($51C8);E16(P2-CP);
 End Else Begin ClrPos1:=0;ClrPos2:=0;End;
 If IsF And Opt.ClearVars Then Begin End;
 For I:=1 To NCp Do Begin
  E16($226E);E16(CpSlot[I]);              { MOVEA.L slot(A6),A1 }
  E16($41EE);E16(CpLoc[I]);               { LEA loc(A6),A0 }
  BlockCopy(CpSize[I]);
 End;
 Skip(K_BEGIN);
 PCompound(K_END);
 Skip(K_END);
 Skip(T_SEMI);
 { resultat de la fonction }
 If IsF Then Begin
  Ad.M:=1;Ad.D:=Sy[Res].Off;
  Case Ty[Sy[S].Ty].K Of
   TK_REAL: LdReal(Ad);
   TK_STR: Begin
     LeaA0(Ad);PushA0;AbsLab($41F9,LitStr(''));PushA0;Svc(S_SCAT);
    End;
  Else LdOrd(Ad,Ty[Sy[S].Ty].Size);
  End;
 End;
 E16($4E5E);E16($4E75);
 If LocSize And 1=1 Then Inc(LocSize);
 Put16(LinkPos,-LocSize);
 If ClrPos1<>0 Then Begin
  Put16(ClrPos1,-LocSize);
  Put32(ClrPos2,(LocSize Div 2)-1);
 End;
 { fin de portee }
 For I:=SavedRN DownTo RLabBase+1 Do Begin End;
 For I:=RLabBase+1 To RLabN Do
  If (Not RLabDef[I]) And (Not CHalt) Then Begin Err(20);Break;End;
 RLabN:=RLabBase;RLabBase:=SavedBase;
 SyN:=SavedSyN;
 Dec(CurLvl);
 LocSize:=OldLoc;
 WithN:=OldWithN;LoopN:=OldLoopN;
End;

Procedure PDecls;
Begin
 While Not CHalt Do Begin
  Case Tok Of
   K_LABEL: PLabelSection;
   K_CONST: PConstSection;
   K_TYPE: PTypeSection;
   K_VAR: PVarSection;
   K_PROCEDURE,K_FUNCTION: PProcDecl;
   K_BEGIN: Break;
  Else
   If Tok=T_EOF Then Break;
   Err(19);NextTok;
  End;
 End;
End;

{ ------------------------- symboles predefinis ------------------------ }

Procedure InitSymbols;
Var S: Integer;
Begin
 SyN:=0;CurLvl:=0;
 DefType('INTEGER',TY_INT);DefType('SHORT_INTEGER',TY_INT);DefType('LONG_INTEGER',TY_LONG);
 DefType('BYTE',TY_BYTE);DefType('BOOLEAN',TY_BOOL);DefType('CHAR',TY_CHAR);
 DefType('REAL',TY_REAL);DefType('STRING',TY_STR);DefType('TEXT',TY_TEXT);
 DefType('ALFA',MakeArr(MakeSub(TY_INT,1,10),TY_CHAR));
 DefConst('FALSE',TY_BOOL,0);DefConst('TRUE',TY_BOOL,1);
 DefConst('MAXINT',TY_INT,32767);DefConst('LONG_MAXINT',TY_LONG,2147483647);
 S:=AddSym('INPUT',SK_STDFILE,TY_TEXT);S:=AddSym('OUTPUT',SK_STDFILE,TY_TEXT);
 HostN:=0;
 S:=AddSym('ABS',SK_STD,TY_INT);Sy[S].Std:=F_ABS;
 S:=AddSym('SQR',SK_STD,TY_INT);Sy[S].Std:=F_SQR;
 S:=AddSym('SQRT',SK_STD,TY_INT);Sy[S].Std:=F_SQRT;
 S:=AddSym('SIN',SK_STD,TY_INT);Sy[S].Std:=F_SIN;
 S:=AddSym('COS',SK_STD,TY_INT);Sy[S].Std:=F_COS;
 S:=AddSym('ARCTAN',SK_STD,TY_INT);Sy[S].Std:=F_ATAN;
 S:=AddSym('LN',SK_STD,TY_INT);Sy[S].Std:=F_LN;
 S:=AddSym('EXP',SK_STD,TY_INT);Sy[S].Std:=F_EXP;
 S:=AddSym('TRUNC',SK_STD,TY_INT);Sy[S].Std:=F_TRUNC;
 S:=AddSym('LONG_TRUNC',SK_STD,TY_INT);Sy[S].Std:=F_TRUNC;
 S:=AddSym('SHORT_TRUNC',SK_STD,TY_INT);Sy[S].Std:=F_TRUNC;
 S:=AddSym('ROUND',SK_STD,TY_INT);Sy[S].Std:=F_ROUND;
 S:=AddSym('SHORT_ROUND',SK_STD,TY_INT);Sy[S].Std:=F_ROUND;
 S:=AddSym('LONG_ROUND',SK_STD,TY_INT);Sy[S].Std:=F_ROUND;
 S:=AddSym('ODD',SK_STD,TY_INT);Sy[S].Std:=F_ODD;
 S:=AddSym('ORD',SK_STD,TY_INT);Sy[S].Std:=F_ORD;
 S:=AddSym('CHR',SK_STD,TY_INT);Sy[S].Std:=F_CHR;
 S:=AddSym('SUCC',SK_STD,TY_INT);Sy[S].Std:=F_SUCC;
 S:=AddSym('PRED',SK_STD,TY_INT);Sy[S].Std:=F_PRED;
 S:=AddSym('LENGTH',SK_STD,TY_INT);Sy[S].Std:=F_LENGTH;
 S:=AddSym('CONCAT',SK_STD,TY_INT);Sy[S].Std:=F_CONCAT;
 S:=AddSym('COPY',SK_STD,TY_INT);Sy[S].Std:=F_COPY;
 S:=AddSym('POS',SK_STD,TY_INT);Sy[S].Std:=F_POS;
 S:=AddSym('EOF',SK_STD,TY_INT);Sy[S].Std:=F_EOF;
 S:=AddSym('EOLN',SK_STD,TY_INT);Sy[S].Std:=F_EOLN;
 S:=AddSym('SIZEOF',SK_STD,TY_INT);Sy[S].Std:=F_SIZEOF;
 S:=AddSym('RANDOM',SK_STD,TY_INT);Sy[S].Std:=F_RANDOM;
 S:=AddSym('PEEK',SK_STD,TY_INT);Sy[S].Std:=F_PEEK;
 S:=AddSym('WPEEK',SK_STD,TY_INT);Sy[S].Std:=F_WPEEK;
 S:=AddSym('LPEEK',SK_STD,TY_INT);Sy[S].Std:=F_LPEEK;
 S:=AddSym('ADDR',SK_STD,TY_INT);Sy[S].Std:=F_ADDR;
 S:=AddSym('UPCASE',SK_STD,TY_INT);Sy[S].Std:=F_UPCASE;
 S:=AddSym('SHL',SK_STD,TY_INT);Sy[S].Std:=F_SHL;
 S:=AddSym('SHR',SK_STD,TY_INT);Sy[S].Std:=F_SHR;
 S:=AddSym('INT',SK_STD,TY_INT);Sy[S].Std:=F_INT;
 S:=AddSym('PWROFTEN',SK_STD,TY_INT);Sy[S].Std:=F_PWR;
 S:=AddSym('PACK',SK_STD,TY_INT);Sy[S].Std:=P_PACK;
 S:=AddSym('UNPACK',SK_STD,TY_INT);Sy[S].Std:=P_UNPACK;
 S:=AddSym('GET',SK_STD,TY_INT);Sy[S].Std:=P_GET;
 S:=AddSym('PUT',SK_STD,TY_INT);Sy[S].Std:=P_PUT;
 S:=AddSym('WRITE',SK_STD,TY_INT);Sy[S].Std:=P_WRITE;
 S:=AddSym('WRITELN',SK_STD,TY_INT);Sy[S].Std:=P_WRITELN;
 S:=AddSym('READ',SK_STD,TY_INT);Sy[S].Std:=P_READ;
 S:=AddSym('READLN',SK_STD,TY_INT);Sy[S].Std:=P_READLN;
 S:=AddSym('NEW',SK_STD,TY_INT);Sy[S].Std:=P_NEW;
 S:=AddSym('DISPOSE',SK_STD,TY_INT);Sy[S].Std:=P_DISPOSE;
 S:=AddSym('MARK',SK_STD,TY_INT);Sy[S].Std:=P_MARK;
 S:=AddSym('RELEASE',SK_STD,TY_INT);Sy[S].Std:=P_RELEASE;
 S:=AddSym('INSERT',SK_STD,TY_INT);Sy[S].Std:=P_INSERT;
 S:=AddSym('DELETE',SK_STD,TY_INT);Sy[S].Std:=P_DELETE;
 S:=AddSym('RESET',SK_STD,TY_INT);Sy[S].Std:=P_RESET;
 S:=AddSym('REWRITE',SK_STD,TY_INT);Sy[S].Std:=P_REWRITE;
 S:=AddSym('CLOSE',SK_STD,TY_INT);Sy[S].Std:=P_CLOSE;
 S:=AddSym('SEEK',SK_STD,TY_INT);Sy[S].Std:=P_SEEK;
 S:=AddSym('PAGE',SK_STD,TY_INT);Sy[S].Std:=P_PAGE;
 S:=AddSym('HALT',SK_STD,TY_INT);Sy[S].Std:=P_HALT;
 S:=AddSym('ERASE',SK_STD,TY_INT);Sy[S].Std:=P_ERASE;
 S:=AddSym('POKE',SK_STD,TY_INT);Sy[S].Std:=P_POKE;
 S:=AddSym('WPOKE',SK_STD,TY_INT);Sy[S].Std:=P_WPOKE;
 S:=AddSym('LPOKE',SK_STD,TY_INT);Sy[S].Std:=P_LPOKE;
 S:=AddSym('MOVE_BYTE',SK_STD,TY_INT);Sy[S].Std:=P_MOVEB;
 { bibliotheque GEM (PASGEM / GEMSUBS) integree }
 AddHost('INIT_GEM',S_INITGEM,'','I');
 AddHost('EXIT_GEM',S_EXITGEM,'',' ');
 AddHost('DO_ALERT',S_ALERT,'SI','I');
 AddHost('LINE',S_LINE,'IIII',' ');
 AddHost('MOVE_TO',S_MOVETO,'II',' ');
 AddHost('LINE_TO',S_LINETO,'II',' ');
 AddHost('PLOT',S_PLOT,'II',' ');
 AddHost('PAINT_RECT',S_PRECT,'IIII',' ');
 AddHost('FRAME_RECT',S_FRECT,'IIII',' ');
 AddHost('PAINT_ROUND_RECT',S_PRRECT,'IIII',' ');
 AddHost('FRAME_ROUND_RECT',S_FRRECT,'IIII',' ');
 AddHost('PAINT_OVAL',S_POVAL,'IIII',' ');
 AddHost('FRAME_OVAL',S_FOVAL,'IIII',' ');
 AddHost('PAINT_ARC',S_PARC,'IIIIII',' ');
 AddHost('FRAME_ARC',S_FARC,'IIIIII',' ');
 AddHost('DRAW_STRING',S_DRAWSTR,'IIS',' ');
 AddHost('LINE_COLOR',S_LINECOL,'I',' ');
 AddHost('PAINT_COLOR',S_PAINTCOL,'I',' ');
 AddHost('TEXT_COLOR',S_TEXTCOL,'I',' ');
 AddHost('SET_COLOR',S_SETCOLOR,'IIII',' ');
 AddHost('DRAW_MODE',S_DMODE,'I',' ');
 AddHost('PAINT_STYLE',S_PSTYLE,'I',' ');
 AddHost('PAINT_OUTLINE',S_PAINTOUT,'I',' ');
 AddHost('LINE_STYLE',S_LSTYLE,'I',' ');
 AddHost('TEXT_HEIGHT',S_TEXTHT,'I',' ');
 AddHost('TEXT_STYLE',S_TEXTSTY,'I',' ');
 AddHost('SET_CLIP',S_SETCLIP,'IIII',' ');
 AddHost('SET_MOUSE',S_SETMOUSE2,'I',' ');
 AddHost('SHOW_MOUSE',S_SHOWMOUSE,'',' ');
 AddHost('HIDE_MOUSE',S_HIDEMOUSE,'',' ');
 AddHost('INIT_MOUSE',S_SHOWMOUSE,'',' ');
 AddHost('BEGIN_MOUSE',S_SHOWMOUSE,'',' ');
 AddHost('END_MOUSE',S_SHOWM,'',' ');
 AddHost('CLEAR_SCREEN',S_CLRSCR,'',' ');
 AddHost('GET_KEY',S_GETKEY,'','I');
 AddHost('KEY_PRESSED',S_KEYPRESS,'','B');
 AddHost('KEYPRESS',S_KEYPRESS,'','B');
 AddHost('PAUSE',S_DELAY,'I',' ');
 AddHost('TICKS',S_TICKS,'','I');
 AddHostT('SYS_FONT_SIZE',S_SYSFONT,'IIII',' ');
 AddHostT('BEGIN_UPDATE',S_SHOWM,'',' ');
 AddHostT('END_UPDATE',S_SHOWM,'',' ');
 { AES / PASGEM }
 AddHostT('NEW_MENU',S_NEWMENU,'IS','I');AddHostT('DELETE_MENU',S_DELMENU,'I',' ');
 AddHostT('ADD_MTITLE',S_ADDMTITLE,'IS','I');AddHostT('ADD_MITEM',S_ADDMITEM,'IIS','I');
 AddHostT('DRAW_MENU',S_DRAWMENU,'I',' ');AddHostT('ERASE_MENU',S_ERASEMENU,'I',' ');
 AddHostT('MENU_HILIGHT',S_MENUHI,'II',' ');AddHostT('MENU_NORMAL',S_MENUNORMAL,'II',' ');
 AddHostT('MENU_CHECK',S_MENUCHECK,'III',' ');AddHostT('MENU_ENABLE',S_MENUENABLE,'II',' ');
 AddHostT('MENU_DISABLE',S_MENUDISABLE,'II',' ');AddHostT('MENU_TEXT',S_MENUTEXT,'IIS',' ');
 AddHostT('MENU_REGISTER',S_MENUREG,'IS','I');
 AddHostT('NEW_WINDOW',S_NEWWIN,'ISIIII','I');AddHostT('OPEN_WINDOW',S_OPENWIN,'IIIII',' ');
 AddHostT('CLOSE_WINDOW',S_CLOSEWIN,'I',' ');AddHostT('DELETE_WINDOW',S_DELWIN,'I',' ');
 AddHostT('SET_WSIZE',S_SETWSIZE,'IIIII',' ');AddHostT('SET_WNAME',S_SETWNAME,'IS',' ');
 AddHostT('SET_WINFO',S_SETWINFO,'IS',' ');AddHostT('BORDER_RECT',S_BORDERRECT,'IIIII',' ');
 AddHostT('WORK_RECT',S_WORKRECT,'IIIII',' ');AddHostT('FIRST_RECT',S_FIRSTRECT,'IIIII',' ');
 AddHostT('NEXT_RECT',S_NEXTRECT,'IIIII',' ');AddHostT('RECT_INTERSECT',S_RECTINT,'IIIIIIII','B');
 AddHostT('FRONT_WINDOW',S_FRONTWIN,'','I');AddHostT('BRING_TO_FRONT',S_BRINGFRONT,'I',' ');
 AddHostT('SET_WINDOW',S_SETWINDOW,'I',' ');AddHostT('GET_WINDOW',S_GETWINDOW,'','I');
 AddHostT('WIND_GET',S_WINDGET,'IIIIII',' ');AddHostT('WIND_SET',S_WINDSET,'IIIIII',' ');
 AddHostT('GET_EVENT',S_GETEVENT,'IIIIIIIIIIIIIIIIIIIIII','I');
 AddHostT('NEW_DIALOG',S_NEWDLG,'IIIII','I');AddHostT('DELETE_DIALOG',S_DELDLG,'I',' ');
 AddHostT('ADD_DITEM',S_ADDDITEM,'IIIIIIIII','I');AddHostT('D_COLOR',S_DCOLOR,'IIIII','I');
 AddHostT('SET_DTEXT',S_SETDTEXT,'IISII',' ');AddHostT('SET_DEDIT',S_SETDEDIT,'IISSSII',' ');
 AddHostT('OBJ_SETSTATE',S_OBJSETSTATE,'IIII',' ');AddHostT('OBJ_STATE',S_OBJSTATE,'II','I');
 AddHostT('OBJ_SETFLAGS',S_OBJSETFLAGS,'III',' ');AddHostT('OBJ_FLAGS',S_OBJFLAGS,'II','I');
 AddHostT('CENTER_DIALOG',S_CENTERDLG,'I',' ');AddHostT('DO_DIALOG',S_DODLG,'II','I');
 AddHostT('GET_DEDIT',S_GETDEDIT,'IIS',' ');AddHostT('REDO_DIALOG',S_REDODLG,'II','I');
 AddHostT('END_DIALOG',S_ENDDLG,'I',' ');AddHostT('SHOW_DIALOG',S_SHOWDLG,'II',' ');
 AddHostT('GET_IN_FILE',S_GETINFILE,'II','B');AddHostT('GET_OUT_FILE',S_GETOUTFILE,'SI','B');
 AddHostT('SET_MFORM',S_SETMFORM,'I',' ');
 AddHostT('LOAD_RESOURCE',S_LOADRSC,'S','B');AddHostT('FREE_RESOURCE',S_FREERSC,'',' ');
 AddHostT('FIND_MENU',S_FINDMENU,'II',' ');AddHostT('FIND_DIALOG',S_FINDDLG,'II',' ');
 AddHostT('FIND_ALERT',S_FINDALERT,'II',' ');
 { bibliotheque auxiliaire (AUXSUBS.PAS) }
 AddHostT('PEEK',S_PEEKB,'I','I');
 AddHostT('WPEEK',S_PEEKW,'I','I');
 AddHostT('LPEEK',S_PEEKL,'I','I');
 AddHostT('POKE',S_POKEB,'II',' ');
 AddHostT('WPOKE',S_POKEW,'II',' ');
 AddHostT('LPOKE',S_POKEL,'II',' ');
 AddHostT('MOVE_BYTE',S_MOVEB,'III',' ');
 AddHost('MOVE_WORD',S_MOVEW,'III',' ');
 AddHost('MOVE_LONG',S_MOVEL,'III',' ');
 AddHostT('IN_SUPER',S_INSUPER,'','B');
 AddHostT('SUPER',S_NOP1,'I',' ');
 { suite de la bibliotheque auxiliaire (AUXSUBS.PAS) et divers }
 AddHost('GET_DATE',S_GETDATE,'VVV',' ');AddHost('GET_TIME',S_GETTIME,'VVV',' ');
 AddHost('SET_DATE',S_SETDATE,'III',' ');AddHost('SET_TIME',S_SETTIME,'III',' ');
 AddHost('CLOCK',S_CLOCK,'','I');
 AddHost('C_TO_PSTR',S_C2P,'VV',' ');AddHost('P_TO_CSTR',S_P2C,'VV',' ');
 AddHost('SAVE_SCRN',S_SAVESCR,'V',' ');AddHost('RESTR_SCRN',S_RESTSCR,'V',' ');
 AddHost('READ_SCRN',S_READSCR,'SV','I');AddHost('WRITE_SCRN',S_WRITESCR,'SV','I');
 AddHost('IO_STATE',S_IOSTATE,'','B');AddHost('IO_RESULT',S_IORESULT,'','I');
 AddHost('IO_CHECK',S_IOCHECK,'I',' ');
 AddHost('CLREOL',S_VT0,'',' ');AddHost('CLRSCR',S_VT0+1,'',' ');AddHost('CLRSCRN',S_VT0+1,'',' ');
 AddHost('CRTINIT',S_VT0+2,'',' ');AddHost('CRTEXIT',S_VT0+3,'',' ');
 AddHost('DELLINE',S_VT0+4,'',' ');AddHost('INSLINE',S_VT0+5,'',' ');
 AddHost('INVERSEVIDEO',S_VT0+6,'',' ');AddHost('NORMVIDEO',S_VT0+7,'',' ');
 AddHost('CURS_UP',S_VT0+8,'',' ');AddHost('CURS_DOWN',S_VT0+9,'',' ');
 AddHost('CURS_RIGHT',S_VT0+10,'',' ');AddHost('CURS_LEFT',S_VT0+11,'',' ');
 AddHost('CURS_HOME',S_VT0+12,'',' ');AddHost('CURS_UP_2',S_VT0+13,'',' ');
 AddHost('CLREOS',S_VT0+14,'',' ');AddHost('CLR_EOS',S_VT0+14,'',' ');
 AddHost('CURS_ON',S_VT0+15,'',' ');AddHost('CURS_OFF',S_VT0+16,'',' ');
 AddHost('GOTOXY',S_GOTOXY,'II',' ');
 AddHost('TEXTCOLOR',S_TCOLOR,'I',' ');AddHost('TEXTBACKGROUND',S_TBACK,'I',' ');
 AddHost('CMD_ARGS',S_CMDARGS,'','I');AddHost('CMD_GETARG',S_CMDGETARG,'IV',' ');
 AddHost('OPTION',S_OPTION,'S','B');AddHost('FILENAME',S_FILENAME,'S','B');
 AddHost('HANDLE',S_HANDLE,'V','I');AddHost('BASEPAGE',S_BASEPAGE,'V',' ');
 AddHost('CHAIN',S_CHAIN,'S',' ');AddHost('RENAME',S_FRENAME,'VV',' ');
 { Ptr / Addr : declarations EXTERNAL de l'utilisateur }
 AddHostT('PTR',S_IDENT,'I','I');AddHostT('ADDR',S_IDENT,'V','I');
 AddHostT('PTR_BYTE',S_IDENT,'I','I');AddHostT('PTR_CHAR',S_IDENT,'I','I');
 AddHostT('PTR_INTEGER',S_IDENT,'I','I');AddHostT('PTR_LONG_INTEGER',S_IDENT,'I','I');
 AddHostT('PTR_L',S_IDENT,'I','I');
 AddHostT('ADDR_BYTE',S_IDENT,'V','I');AddHostT('ADDR_CHAR',S_IDENT,'V','I');
 AddHostT('ADDR_INTEGER',S_IDENT,'V','I');AddHostT('ADDR_LONG_INTEGER',S_IDENT,'V','I');
End;

{ ------------------------- programme complet -------------------------- }

Procedure ResolveFixes;
Var I,P: Integer; D: LongInt; V: LongInt;
Begin
 For I:=1 To FixN Do Begin
  P:=Fix[I].Lab;
  If Fix[I].Kind=2 Then Continue;
  If LabPos[P]<0 Then Begin
   If Not CHalt Then Begin
    TokLine:=CurLn;
    If LabNm[P]<>'' Then CompError(117,T3('Unsatisfied external or forward: ','Externe ou forward non r'#130'solu : ','Nicht aufgeloest: ')+LabNm[P]) Else Err(33);
   End;
   Continue;
  End;
  If Fix[I].Kind=0 Then Begin
   D:=LabPos[P]-Fix[I].Pos;
   If (D<-32768) Or (D>32767) Then Begin Err(27);D:=0;End;
   Put16(Fix[I].Pos,D);
  End Else Begin
   V:=LabPos[P];
   Put32(Fix[I].Pos,V);
  End;
 End;
End;

Procedure EmitLiterals;
Var I,J: Integer; D: Double; B: Int64; S: String;
Begin
 If Odd(CP) Then E8(0);
 For I:=1 To LitN Do Begin
  Place(Lits[I].Lab);
  If Lits[I].K=0 Then Begin
   S:=Lits[I].S;
   E8(Length(S));
   For J:=1 To Length(S) Do E8(Ord(S[J]));
   If Odd(CP) Then E8(0);
  End Else Begin
   If EncodeReal(Lits[I].R,B)<>0 Then Begin Err(18);B:=0;End;
   E32(LongInt(Cardinal(B Shr 32)));E32(LongInt(Cardinal(B And $FFFFFFFF)));
  End;
 End;
End;

Function ProgramBody: Boolean;
Var S,I: Integer; EndLab: Integer; StartPos: LongInt;
Begin
 ProgramBody:=False;
 NextTok;
 If Tok=K_PROGRAM Then Begin
  NextTok;
  If Tok=T_ID Then Begin ProgName:=TokS;NextTok;End Else Err(1);
  If Tok=T_LP Then Begin
   While (Tok<>T_RP) And (Tok<>T_EOF) Do NextTok;
   Skip(T_RP);
  End;
  Skip(T_SEMI);
 End Else Err(0);
 InitTypes;InitSymbols;
 CurLvl:=1;
 CP:=0;LabN:=0;FixN:=0;FillChar(LabNm,SizeOf(LabNm),0);FillChar(LabExt,SizeOf(LabExt),0);RelN:=0;LitN:=0;WithN:=0;LoopN:=0;
 GSize:=0;LocSize:=0;PendN:=0;SymCnt:=0;RLabN:=0;RLabBase:=0;PmN:=0;FlN:=0;
 FillChar(FuncStk,SizeOf(FuncStk),0);
 MainLab:=NewLab;LabNm[MainLab]:='MAIN';
 { amorcage : A4 <- base des variables globales ; A6 <- 0 ; appel du corps }
 E16($49F9);
 If FixN<MAXFIX Then Begin Inc(FixN);Fix[FixN].Pos:=CP;Fix[FixN].Lab:=0;Fix[FixN].Kind:=2;End;
 If RelN<MAXREL Then Begin Inc(RelN);Rel[RelN]:=CP;End;
 E32(0);
 E16($9DCE);
 AbsLab($4EB9,MainLab);
 E16($4267);E16($4E41);
 PDecls;
 If CHalt Then Exit;
 { corps du programme principal }
 Place(MainLab);
 If Opt.FullDebug And (SymCnt<400) Then Begin Inc(SymCnt);SymNames[SymCnt]:='MAIN';SymAddrLab[SymCnt]:=MainLab;End;
 Skip(K_BEGIN);
 PCompound(K_END);
 Skip(K_END);
 If Tok<>T_DOT Then ErrExp('.') Else NextTok;
 E16($4E75);
 { routines externes non disponibles : appel -> erreur d'execution explicite }
 For S:=1 To LabN Do
  If LabExt[S] And (LabPos[S]<0) Then Begin
   If ExtN<60 Then Begin
    Inc(ExtN);ExtName[ExtN]:=Copy(LabNm[S],1,8);ExtFirst[ExtN]:=ExtPosN+1;ExtCnt[ExtN]:=0;
    For I:=1 To FixN Do
     If (Fix[I].Kind=1) And (Fix[I].Lab=S) And (ExtPosN<3000) Then Begin
      Inc(ExtPosN);ExtPos[ExtPosN]:=Fix[I].Pos;Inc(ExtCnt[ExtN]);
     End;
   End;
   Place(S);
   AbsLab($41F9,LitStr(LabNm[S]));
   PushA0;Svc(S_NOEXT);E16($4E75);
  End;
 EmitLiterals;
 ProgramBody:=Not CHalt;
End;

{ ------------------------- fichier objet (.O) ------------------------- }

Var
 ObjFlags : LongInt;
 OutProgType : Integer;
 OutModule : Boolean;

Procedure PutL(Var F: File; V: LongInt);
Var B: Array[0..3] Of Byte;
Begin
 B[0]:=(V Shr 24) And $FF;B[1]:=(V Shr 16) And $FF;B[2]:=(V Shr 8) And $FF;B[3]:=V And $FF;
 BlockWrite(F,B,4);
End;

Function GetL(Var F: File; Var V: LongInt): Boolean;
Var B: Array[0..3] Of Byte; N: Word;
Begin
 BlockRead(F,B,4,N);
 GetL:=(N=4);
 V:=LongInt((Cardinal(B[0]) Shl 24) Or (Cardinal(B[1]) Shl 16) Or (Cardinal(B[2]) Shl 8) Or B[3]);
End;

Procedure PatchFixKind2;
Var I: Integer;
Begin
 For I:=1 To FixN Do
  If Fix[I].Kind=2 Then Put32(Fix[I].Pos,CP+G_BIAS);
End;

Function WriteObject(Const Name: String): Boolean;
Var F: File; I,J: Integer; Hdr: Array[0..3] Of Char; S: String; Nm: Array[0..7] Of Char; A: LongInt;
Begin
 WriteObject:=False;
 PatchFixKind2;
 ResolveFixes;
 If CHalt Or (CErrN>0) Then Exit;
 ObjFlags:=Opt.ProgType;OutProgType:=Opt.ProgType;OutModule:=ModuleMode;
 If ModuleMode Then ObjFlags:=ObjFlags Or $200;
 If Conf.FullDebug Or Opt.FullDebug Then ObjFlags:=ObjFlags Or $100;
 If SpaceS>=0 Then Begin
  If SpaceS>1022 Then SpaceS:=1022;
  ObjFlags:=ObjFlags Or (LongInt(SpaceS+1) Shl 12);
 End;
 If SpaceU>=0 Then Begin
  If SpaceU>510 Then SpaceU:=510;
  ObjFlags:=ObjFlags Or (LongInt(SpaceU+1) Shl 22);
 End;
 Assign(F,Name);
 {$I-}Rewrite(F,1);{$I+}
 If IOResult<>0 Then Exit;
 Hdr[0]:='P';Hdr[1]:='P';Hdr[2]:='O';Hdr[3]:='2';
 BlockWrite(F,Hdr,4);
 PutL(F,ObjFlags);PutL(F,CP);PutL(F,GSize);PutL(F,RelN);PutL(F,SymCnt);
 BlockWrite(F,Code^,CP);
 For I:=1 To RelN Do PutL(F,Rel[I]);
 For I:=1 To SymCnt Do Begin
  FillChar(Nm,8,0);
  S:=SymNames[I];
  For J:=1 To Length(S) Do If J<=8 Then Nm[J-1]:=S[J];
  BlockWrite(F,Nm,8);
  PutL(F,LabPos[SymAddrLab[I]]);
 End;
 { symboles exportes et references externes (compilation modulaire) }
 PutL(F,ExpN);
 For I:=1 To ExpN Do Begin
  FillChar(Nm,8,0);
  For J:=1 To Length(ExpName[I]) Do If J<=8 Then Nm[J-1]:=ExpName[I][J];
  BlockWrite(F,Nm,8);PutL(F,LabPos[ExpLab[I]]);
 End;
 PutL(F,ExtN);
 For I:=1 To ExtN Do Begin
  FillChar(Nm,8,0);
  For J:=1 To Length(ExtName[I]) Do If J<=8 Then Nm[J-1]:=ExtName[I][J];
  BlockWrite(F,Nm,8);PutL(F,ExtCnt[I]);
  For J:=ExtFirst[I] To ExtFirst[I]+ExtCnt[I]-1 Do PutL(F,ExtPos[J]);
 End;
 Close(F);
 WriteObject:=True;
End;

{ Compile le fichier source Name ; ecrit Name.O ; retourne True si succes }
Function CompileFile(Const Name,ObjName: String): Boolean;
Var Ok: Boolean;
Begin
 CompileFile:=False;
 FreeSource;
 SrcFileName:=Name;
 If Not LoadLines(Name,False) Then Begin
  CErrN:=1;CErrs[1].Line:=0;CErrs[1].Col:=0;CErrs[1].Num:=28;
  CErrs[1].Msg:=T3('File not found: ','Fichier introuvable : ','Datei nicht gefunden: ')+Copy(Name,1,60);
  Exit;
 End;
 If Code=Nil Then GetMem(Code,CODEMAX);
 LexInit(Name);
 Ok:=ProgramBody;
 If Ok Then Ok:=WriteObject(ObjName);
 If CErrN>0 Then Ok:=False;
 FreeSource;
 CompileFile:=Ok;
End;

{ ------------------------- editeur de liens --------------------------- }
{ Lit un ou plusieurs fichiers .O (programme + modules) et produit un
  programme GEMDOS (.PRG / .TOS / .ACC) en y associant la bibliotheque
  d'execution (PASLIB / PASGEM) integree. Les references externes d'un
  fichier sont resolues avec les symboles exportes ({$E+}) des autres. }

Const MAXLO = 5;

Type
 TLObj = Record
  Fl,Tl,Bl : LongInt;
  Buf  : PByteArr;
  NRel : Integer;
  Rl   : Array[1..MAXREL] Of LongInt;
  NSym : Integer;
  SN   : Array[1..400] Of String[8];
  SA   : Array[1..400] Of LongInt;
  NExp : Integer;
  EN   : Array[1..60] Of String[8];
  EO   : Array[1..60] Of LongInt;
  NExt : Integer;
  XN   : Array[1..60] Of String[8];
  XF,XC: Array[1..60] Of Integer;
  XP   : Array[1..3000] Of LongInt;
  Base : LongInt;
 End;

Var
 LO : Array[1..MAXLO] Of TLObj;

Function ReadNm8(Var F: File): String;
Var Nm: Array[0..7] Of Char; N: Word; S: String; I: Integer;
Begin
 BlockRead(F,Nm,8,N);
 S:='';
 For I:=0 To 7 Do If Nm[I]<>#0 Then S:=S+Nm[I];
 ReadNm8:=S;
End;

Function ReadObj(Const Name: String; K: Integer; Var Msg: String): Boolean;
Var F: File; Hdr: Array[0..3] Of Char; N: Word; NR,NS,I,J,C: LongInt; V: LongInt;
Begin
 ReadObj:=False;
 Assign(F,ResolveFile(Name));
 {$I-}Reset(F,1);{$I+}
 If IOResult<>0 Then Begin Msg:=T3('Cannot open ','Impossible d''ouvrir ','Kann nicht oeffnen ')+Name;Exit;End;
 BlockRead(F,Hdr,4,N);
 If (N<4) Or (Hdr[0]<>'P') Or (Hdr[1]<>'P') Or (Hdr[2]<>'O') Then Begin
  Close(F);Msg:=T3('Not an object file: ','Fichier objet invalide : ','Kein Objektfile: ')+Name;Exit;
 End;
 GetL(F,LO[K].Fl);GetL(F,LO[K].Tl);GetL(F,LO[K].Bl);GetL(F,NR);GetL(F,NS);
 If (LO[K].Tl<=0) Or (LO[K].Tl>CODEMAX) Or (NR>MAXREL) Or (NS>400) Then Begin Close(F);Msg:='Bad object';Exit;End;
 GetMem(LO[K].Buf,CODEMAX);
 BlockRead(F,LO[K].Buf^,LO[K].Tl,N);
 LO[K].NRel:=NR;
 For I:=1 To NR Do GetL(F,LO[K].Rl[I]);
 LO[K].NSym:=NS;
 For I:=1 To NS Do Begin LO[K].SN[I]:=ReadNm8(F);GetL(F,LO[K].SA[I]);End;
 LO[K].NExp:=0;LO[K].NExt:=0;
 If GetL(F,C) Then Begin
  LO[K].NExp:=C;
  For I:=1 To C Do Begin LO[K].EN[I]:=ReadNm8(F);GetL(F,LO[K].EO[I]);End;
  GetL(F,C);
  LO[K].NExt:=C;
  J:=0;
  For I:=1 To C Do Begin
   LO[K].XN[I]:=ReadNm8(F);GetL(F,V);
   LO[K].XF[I]:=J+1;LO[K].XC[I]:=V;
   While V>0 Do Begin Inc(J);GetL(F,LO[K].XP[J]);Dec(V);End;
  End;
 End;
 Close(F);
 ReadObj:=True;
End;

Function LinkObject(Const ObjName,PrgName,Extra: String; Var Msg: String): Boolean;
Var G: File; NObj,K,I,J,M,P: Integer; Cat: PByteArr; Tot,BlMax,Last,D,Ad: LongInt; B: Byte; Hd: Array[0..1] Of Byte;
    Stat: Word; Ent: Array[0..13] Of Byte; Nm,L: String; NS: Integer; Bn: String;
    Names: Array[1..MAXLO] Of String[80]; RAll: Array[1..MAXREL] Of LongInt; NR: Integer; Found: Boolean;
    SyN: Array[1..400] Of String[8]; SyA: Array[1..400] Of LongInt; SKb,UKb: LongInt;
 Procedure W32(V: LongInt);
 Begin PutL(G,V);End;
 Function Stem(Const S0: String): String;
 Var T: String; Q: Integer;
 Begin
  T:=Upper(ShortName(S0));
  Q:=Pos('.',T);
  If Q>0 Then T:=Copy(T,1,Q-1);
  Stem:=T;
 End;
Begin
 LinkObject:=False;Msg:='';
 NObj:=1;Names[1]:=ObjName;
 L:=Extra;
 While (L<>'') And (NObj<MAXLO) Do Begin
  P:=Pos(',',L);
  If P=0 Then Begin Nm:=TrimStr(L);L:='';End Else Begin Nm:=TrimStr(Copy(L,1,P-1));L:=Copy(L,P+1,200);End;
  If Nm<>'' Then Begin
   If Pos('.',ShortName(Nm))=0 Then Nm:=Nm+'.O';
   If Stem(Nm)<>Stem(ObjName) Then Begin Inc(NObj);Names[NObj]:=Nm;End;
  End;
 End;
 For K:=1 To NObj Do LO[K].Buf:=Nil;
 For K:=1 To NObj Do
  If Not ReadObj(Names[K],K,Msg) Then Begin
   For I:=1 To NObj Do If LO[I].Buf<>Nil Then FreeMem(LO[I].Buf,CODEMAX);
   Exit;
  End;
 { assemblage }
 GetMem(Cat,CODEMAX);
 Tot:=0;BlMax:=0;
 For K:=1 To NObj Do Begin
  LO[K].Base:=Tot;
  If Tot+LO[K].Tl>CODEMAX Then Begin Msg:=ErrMsg(26);FreeMem(Cat,CODEMAX);Exit;End;
  Move(LO[K].Buf^,Cat^[Tot],LO[K].Tl);
  Tot:=Tot+LO[K].Tl;
  If Odd(Tot) Then Begin Cat^[Tot]:=0;Inc(Tot);End;
  If LO[K].Bl>BlMax Then BlMax:=LO[K].Bl;
 End;
 { decalage des adresses absolues des modules }
 For K:=2 To NObj Do
  For I:=1 To LO[K].NRel Do Begin
   P:=LO[K].Base+LO[K].Rl[I];
   Ad:=(LongInt(Cat^[P]) Shl 24) Or (LongInt(Cat^[P+1]) Shl 16) Or (LongInt(Cat^[P+2]) Shl 8) Or Cat^[P+3];
   Ad:=Ad+LO[K].Base;
   Cat^[P]:=(Ad Shr 24) And $FF;Cat^[P+1]:=(Ad Shr 16) And $FF;Cat^[P+2]:=(Ad Shr 8) And $FF;Cat^[P+3]:=Ad And $FF;
  End;
 { resolution des references externes }
 For K:=1 To NObj Do
  For I:=1 To LO[K].NExt Do Begin
   Found:=False;Ad:=0;
   For M:=1 To NObj Do
    If M<>K Then
     For J:=1 To LO[M].NExp Do
      If (Not Found) And (LO[M].EN[J]=LO[K].XN[I]) Then Begin Found:=True;Ad:=LO[M].Base+LO[M].EO[J];End;
   If Found Then
    For J:=LO[K].XF[I] To LO[K].XF[I]+LO[K].XC[I]-1 Do Begin
     P:=LO[K].Base+LO[K].XP[J];
     Cat^[P]:=(Ad Shr 24) And $FF;Cat^[P+1]:=(Ad Shr 16) And $FF;Cat^[P+2]:=(Ad Shr 8) And $FF;Cat^[P+3]:=Ad And $FF;
    End;
  End;
 NR:=0;
 For K:=1 To NObj Do
  For I:=1 To LO[K].NRel Do If NR<MAXREL Then Begin Inc(NR);RAll[NR]:=LO[K].Base+LO[K].Rl[I];End;
 NS:=0;
 For K:=1 To NObj Do
  For I:=1 To LO[K].NSym Do If NS<400 Then Begin Inc(NS);SyN[NS]:=LO[K].SN[I];SyA[NS]:=LO[K].Base+LO[K].SA[I];End;
 Assign(G,PrgName);
 {$I-}Rewrite(G,1);{$I+}
 If IOResult<>0 Then Begin
  For I:=1 To NObj Do FreeMem(LO[I].Buf,CODEMAX);
  FreeMem(Cat,CODEMAX);
  Msg:=T3('Cannot create ','Impossible de cr'#130'er ','Kann nicht erzeugen ')+PrgName;Exit;
 End;
 Hd[0]:=$60;Hd[1]:=$1A;
 BlockWrite(G,Hd,2);
 W32(Tot);W32(0);W32(BlMax+4096);W32(NS*14);
 { champ reserve : taille pile+tas ($S, Ko) en mot fort, memoire laissee ($U, Ko) en mot faible }
 SKb:=(LO[1].Fl Shr 12) And $3FF;UKb:=(LO[1].Fl Shr 22) And $1FF;
 If SKb>0 Then Begin Dec(SKb);If SKb=0 Then SKb:=1;UKb:=0;End
 Else Begin
  If UKb>0 Then Dec(UKb) Else If (LO[1].Fl And 3)=1 Then UKb:=0 Else UKb:=10;
 End;
 W32((LongInt(SKb) Shl 16) Or UKb);
 W32(LO[1].Fl And $100);
 Stat:=0;BlockWrite(G,Stat,2);
 BlockWrite(G,Cat^,Tot);
 For I:=1 To NS Do Begin
  FillChar(Ent,14,0);
  For J:=1 To Length(SyN[I]) Do Ent[J-1]:=Ord(SyN[I][J]);
  Ent[8]:=$02;Ent[9]:=$00;
  Ent[10]:=(SyA[I] Shr 24) And $FF;Ent[11]:=(SyA[I] Shr 16) And $FF;Ent[12]:=(SyA[I] Shr 8) And $FF;Ent[13]:=SyA[I] And $FF;
  BlockWrite(G,Ent,14);
 End;
 If NR=0 Then W32(0)
 Else Begin
  Last:=RAll[1];W32(Last);
  For I:=2 To NR Do Begin
   D:=RAll[I]-Last;Last:=RAll[I];
   While D>254 Do Begin B:=1;BlockWrite(G,B,1);D:=D-254;End;
   B:=D;BlockWrite(G,B,1);
  End;
  B:=0;BlockWrite(G,B,1);
 End;
 Close(G);
 For I:=1 To NObj Do FreeMem(LO[I].Buf,CODEMAX);
 FreeMem(Cat,CODEMAX);
 LinkObject:=True;
End;

{ ====================================================================== }
{          INTERFACE : ETAT DE L'APPLICATION ET MENUS DEROULANTS         }
{ ====================================================================== }

Const
 C_ABOUT=1;C_EDIT=2;C_COMPILE=3;C_COMPALL=4;C_LINK=5;C_RUN=6;C_QUIT=7;
 C_COPT=10;C_LOPT=11;C_SRC=12;C_LOC=13;C_LOADO=14;C_SAVEO=15;
 C_COPY=20;C_REN=21;C_ERASE=22;C_PRINT=23;C_NONE=99;
 E_NEW=30;E_OPEN=31;E_SAVE=32;E_SAVEAS=33;E_QUIT=34;E_COMPILER=35;E_LINKER=36;
 E_MARK=40;E_ERASE=41;E_PASTE=42;E_HIDE=43;E_LOADB=44;E_SAVEB=45;E_PRINTB=46;
 E_FINDW=50;E_FINDP=51;E_FINDN=52;E_REPN=53;E_REPA=54;
 E_SETM=60;E_GOM=64;E_TOP=68;E_BOT=69;E_GOTO=70;E_TAB=71;E_INS=72;E_AUTO=73;
 E_PRNF=74;E_STAT=75;E_ABOUT=76;

Var
 AppMode   : Integer;      { 0 gestionnaire, 1 editeur }
 NMENU     : Integer;
 MTitle    : Array[1..8] Of String[40];
 MenuN     : Array[1..8] Of Integer;
 MenuItem  : Array[1..8,1..16] Of String[60];
 MenuKey   : Array[1..8,1..16] Of String[12];
 MenuCmd   : Array[1..8,1..16] Of Integer;
 MenuOpen,MenuHi : Integer;
 MenuSave  : TSave;
 MenuSaved : Boolean;
 RunningProg : Boolean;
 UIDirty   : Boolean;
 LastFile  : String[80];
 SrcList   : Array[1..16] Of String[80];
 SrcCnt    : Integer;
 PathNm    : Array[1..6] Of String[80];
 LinkType  : Integer;
 LinkExtra : String[60];
 RunTail  : String[120];     (* /P: arguments passes au programme execute *)
 LinkAsk   : Boolean;
 EdInsert,EdAuto : Boolean;
 EdTab     : Integer;
 DrvLetter : Char;

Procedure AddMenu(M: Integer; Const Item,Key: String; Cmd: Integer);
Begin
 Inc(MenuN[M]);
 MenuItem[M,MenuN[M]]:=Item;MenuKey[M,MenuN[M]]:=Key;MenuCmd[M,MenuN[M]]:=Cmd;
End;

Procedure SetMenus(Mode: Integer);
Var I: Integer;
Begin
 For I:=1 To 8 Do MenuN[I]:=0;
 AppMode:=Mode;
 If Mode=0 Then Begin
  NMENU:=4;
  MTitle[1]:='Desk~Bureau~Schreibtisch';MTitle[2]:='File~Fichier~Datei';
  MTitle[3]:='Options~Options~Optionen';MTitle[4]:='Special~Special~Spezial';
  AddMenu(1,'About Personal Pascal...~A propos de Personal Pascal...~Ueber Personal Pascal...','',C_ABOUT);
  AddMenu(1,'-','',C_NONE);
  AddMenu(1,'Control Panel~Panneau de contr'#147'le~Kontrollfeld','',C_NONE);
  AddMenu(1,'Install Printer~Installer imprimante~Drucker installieren','',C_NONE);
  AddMenu(2,'Edit~Edition~Editieren','E',C_EDIT);
  AddMenu(2,'Compile~Compiler~Compilieren','C',C_COMPILE);
  AddMenu(2,'Compile All~Tout compiler~Alles compilieren','A',C_COMPALL);
  AddMenu(2,'Link~Lier~Linken','L',C_LINK);
  AddMenu(2,'Run Program~Ex'#130'cuter programme~Programm starten','R',C_RUN);
  AddMenu(2,'-','',C_NONE);
  AddMenu(2,'Quit~Quitter~Beenden','Undo',C_QUIT);
  AddMenu(3,'Compiler Options~Options compilateur~Compiler-Optionen','F1',C_COPT);
  AddMenu(3,'Linker Options~Options liaison~Linker-Optionen','F2',C_LOPT);
  AddMenu(3,'Set Source Files~Fichiers sources~Quelldateien','F3',C_SRC);
  AddMenu(3,'Locate Programs~Localiser programmes~Programme suchen','F4',C_LOC);
  AddMenu(3,'-','',C_NONE);
  AddMenu(3,'Load Options~Charger options~Optionen laden','F5',C_LOADO);
  AddMenu(3,'Save Options~Sauver options~Optionen speichern','F6',C_SAVEO);
  AddMenu(4,'Copy~Copier~Kopieren','Sh-F1',C_COPY);
  AddMenu(4,'Rename~Renommer~Umbenennen','Sh-F2',C_REN);
  AddMenu(4,'Erase~Effacer~Loeschen','Sh-F3',C_ERASE);
  AddMenu(4,'Print~Imprimer~Drucken','Sh-F4',C_PRINT);
 End Else Begin
  NMENU:=6;
  MTitle[1]:=#240;MTitle[2]:='File~Fichier~Datei';MTitle[3]:='Block~Bloc~Block';
  MTitle[4]:='Find~Cherche~Suchen';MTitle[5]:='Mark~Marque~Marke';
  MTitle[6]:='Options~Options~Optionen';
  AddMenu(1,'About Editor...~A propos de l''editeur...~Ueber den Editor...','',E_ABOUT);
  AddMenu(2,'New~Nouveau~Neu','^N',E_NEW);
  AddMenu(2,'Open~Ouvrir~Oeffnen','Alt-O',E_OPEN);
  AddMenu(2,'Save File~Sauver fichier~Datei speichern','Alt-S',E_SAVE);
  AddMenu(2,'Save As~Sauver sous~Speichern als','',E_SAVEAS);
  AddMenu(2,'-','',C_NONE);
  AddMenu(2,'Quit~Quitter~Beenden','Alt-Q',E_QUIT);
  AddMenu(2,'-','',C_NONE);
  AddMenu(2,'Compiler~Compilateur~Compiler','',E_COMPILER);
  AddMenu(2,'Linker~Editeur de liens~Linker','',E_LINKER);
  AddMenu(3,'Mark Block~Marquer bloc~Block markieren','Alt-M',E_MARK);
  AddMenu(3,'Erase Block~Effacer bloc~Block loeschen','Alt-E',E_ERASE);
  AddMenu(3,'Paste Block~Coller bloc~Block einfuegen','Alt-P',E_PASTE);
  AddMenu(3,'Hide Block~Cacher bloc~Block verbergen','Alt-H',E_HIDE);
  AddMenu(3,'-','',C_NONE);
  AddMenu(3,'Load Block~Charger bloc~Block laden','Alt-L',E_LOADB);
  AddMenu(3,'Save Block~Sauver bloc~Block speichern','',E_SAVEB);
  AddMenu(3,'Print Block~Imprimer bloc~Block drucken','',E_PRINTB);
  AddMenu(4,'Find What~Chercher quoi~Suchen nach','Alt-F',E_FINDW);
  AddMenu(4,'Find Previous~Chercher pr'#130'c.~Suche rueckwaerts','Alt-U',E_FINDP);
  AddMenu(4,'Find Next~Chercher suivant~Suche vorwaerts','Alt-D',E_FINDN);
  AddMenu(4,'Replace Next~Remplacer suivant~Naechstes ersetzen','Alt-R',E_REPN);
  AddMenu(4,'Replace All~Tout remplacer~Alles ersetzen','',E_REPA);
  For I:=1 To 4 Do AddMenu(5,'Set Mark '+IntStr(I)+'~Poser marque '+IntStr(I)+'~Marke '+IntStr(I)+' setzen','',E_SETM+I-1);
  AddMenu(5,'-','',C_NONE);
  For I:=1 To 4 Do AddMenu(5,'Goto Mark '+IntStr(I)+'~Aller marque '+IntStr(I)+'~Gehe zu Marke '+IntStr(I),'F'+IntStr(I),E_GOM+I-1);
  AddMenu(5,'-','',C_NONE);
  AddMenu(5,'Top~Haut~Anfang','Alt-T',E_TOP);
  AddMenu(5,'Bottom~Bas~Ende','Alt-B',E_BOT);
  AddMenu(6,'Goto Line~Aller '#133' la ligne~Gehe zu Zeile','Alt-G',E_GOTO);
  AddMenu(6,'Tabsize~Taille tabulation~Tabulatorgroesse','',E_TAB);
  AddMenu(6,'Insert~Insertion~Einfuegen','Ins',E_INS);
  AddMenu(6,'Auto Indent~Indentation auto~Auto-Einrueckung','',E_AUTO);
  AddMenu(6,'Print File~Imprimer fichier~Datei drucken','',E_PRNF);
  AddMenu(6,'Statistics~Statistiques~Statistik','',E_STAT);
 End;
End;

Function MCount(M: Integer): Integer;
Begin
 If (M>=1) And (M<=8) Then MCount:=MenuN[M] Else MCount:=0;
End;

Function MLabel(M,I: Integer): String;
Var S,K: String; W: Integer;
Begin
 S:=Part3(MenuItem[M,I],Lang);
 If S='-' Then Begin MLabel:='-';Exit;End;
 K:=MenuKey[M,I];
 If (AppMode=1) And (M=6) And (MenuCmd[M,I]=E_INS) Then Begin
  If EdInsert Then S:=T3('Insert','Insertion','Einfuegen') Else S:=T3('Overwrite','Ecrasement','Ueberschreiben');
 End;
 If K='' Then MLabel:=S+'  '
 Else Begin
  W:=22;
  While Length(S)<W-Length(K) Do S:=S+' ';
  MLabel:=S+K+' ';
 End;
End;

Function MIsSep(M,I: Integer): Boolean;
Begin
 MIsSep:=(MenuItem[M,I]='-');
End;

Function MEnabled(M,I: Integer): Boolean;
Begin
 MEnabled:=(MenuCmd[M,I]<>C_NONE);
End;

Function MChecked(M,I: Integer): Boolean;
Begin
 MChecked:=False;
 If AppMode=1 Then Begin
  If (MenuCmd[M,I]=E_AUTO) Then MChecked:=EdAuto;
 End Else Begin
  If (M=2) And (MenuCmd[M,I]=C_COMPILE) And False Then MChecked:=True;
 End;
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
{              BOITES DE DIALOGUE DU GESTIONNAIRE (style GEM)            }
{ ====================================================================== }

Const
 MAXDI = 28;
 DK_LABEL=0;DK_BUTTON=1;DK_CHECK=2;DK_RADIO=3;DK_EDIT=4;DK_TITLE=5;DK_BOX=6;

Type
 TDItem = Record
  K : Byte;
  X,Y,W,H : Integer;
  S : String[60];
  On,Dis : Boolean;
  Grp : Byte;
 End;

Var
 DI : Array[1..MAXDI] Of TDItem;
 DN,DW,DH,DBord,DDef,DCan,DX0,DY0,DFocus : Integer;

Procedure DlgInit(W,H,Bord: Integer);
Begin
 DN:=0;DW:=W;DH:=H;DBord:=Bord;DDef:=0;DCan:=0;DFocus:=0;
 DX0:=(SCR_W-W) Div 2;DY0:=(SCR_H-H) Div 2;
End;

Function DlgAdd(K,X,Y,W,H: Integer; Const S: String): Integer;
Begin
 If DN<MAXDI Then Inc(DN);
 FillChar(DI[DN],SizeOf(TDItem),0);
 DI[DN].K:=K;DI[DN].X:=X;DI[DN].Y:=Y;DI[DN].W:=W;DI[DN].H:=H;DI[DN].S:=S;
 DlgAdd:=DN;
End;

Procedure DlgFrame(X1,Y1,X2,Y2,Bord: Integer);
Begin
 Box(X1,Y1,X2,Y2,PAPER);
 Frame(X1,Y1,X2,Y2);
 If Bord=2 Then Begin Frame(X1+3,Y1+3,X2-3,Y2-3);End;
End;

Procedure DrawTick(X,Y: Integer);
Begin
 SetColor(INK);
 Line(X+1,Y+8,X+5,Y+13);Line(X+2,Y+8,X+5,Y+12);Line(X+5,Y+13,X+13,Y+1);Line(X+5,Y+12,X+12,Y+1);
End;

Procedure DlgDrawItem(I: Integer);
Var X,Y: Integer; It: TDItem; TX: Integer;
Begin
 It:=DI[I];X:=DX0+It.X;Y:=DY0+It.Y;
 Case It.K Of
  DK_LABEL: PText(X,Y,It.S);
  DK_TITLE: BText(DX0+(DW-TextW(It.S)) Div 2,Y,It.S);
  DK_BOX: Frame(X,Y,X+It.W,Y+It.H);
  DK_BUTTON: Begin
    Box(X,Y,X+It.W,Y+It.H,PAPER);
    Frame(X,Y,X+It.W,Y+It.H);
    If I=DDef Then Begin Frame(X-1,Y-1,X+It.W+1,Y+It.H+1);Frame(X+1,Y+1,X+It.W-1,Y+It.H-1);End;
    TX:=X+(It.W-TextW(It.S)) Div 2;
    If It.Dis Then GreyText(TX,Y+(It.H-7) Div 2,It.S) Else PText(TX,Y+(It.H-7) Div 2,It.S);
   End;
  DK_RADIO: Begin
    If It.On Then Begin
     Box(X,Y,X+It.W,Y+It.H,INK);
     WText(X+(It.W-TextW(It.S)) Div 2,Y+(It.H-7) Div 2,It.S);
    End Else Begin
     Box(X,Y,X+It.W,Y+It.H,PAPER);Frame(X,Y,X+It.W,Y+It.H);
     PText(X+(It.W-TextW(It.S)) Div 2,Y+(It.H-7) Div 2,It.S);
    End;
   End;
  DK_CHECK: Begin
    Box(X,Y,X+14,Y+14,PAPER);
    If It.On Then DrawTick(X,Y) Else Frame(X,Y,X+14,Y+14);
    PText(X+24,Y+4,It.S);
   End;
  DK_EDIT: Begin
    Box(X,Y,X+It.W*8+6,Y+15,PAPER);
    SetColor(INK);Line(X,Y+15,X+It.W*8+6,Y+15);
    PText(X+3,Y+4,It.S);
    If I=DFocus Then Box(X+3+Length(It.S)*8,Y+2,X+10+Length(It.S)*8,Y+13,INK);
   End;
 End;
End;

Procedure DlgDraw;
Var I: Integer;
Begin
 HideMouse;
 DlgFrame(DX0,DY0,DX0+DW,DY0+DH,DBord);
 For I:=1 To DN Do DlgDrawItem(I);
 ShowMouse;
End;

Function DlgHit(X,Y: LongInt): Integer;
Var I,H: Integer; It: TDItem;
Begin
 H:=0;
 For I:=1 To DN Do Begin
  It:=DI[I];
  Case It.K Of
   DK_BUTTON,DK_RADIO,DK_EDIT: If InBox(X,Y,DX0+It.X,DY0+It.Y,DX0+It.X+It.W*(1+7*Ord(It.K=DK_EDIT)),DY0+It.Y+It.H) Then H:=I;
   DK_CHECK: If InBox(X,Y,DX0+It.X,DY0+It.Y,DX0+It.X+24+Length(It.S)*8,DY0+It.Y+15) Then H:=I;
  End;
 End;
 DlgHit:=H;
End;

{ Execute la boite : retourne le numero du bouton choisi (0 : annulation) }
Function RunDlg: Integer;
Var Sv: TSave; E: TEvent; Done: Boolean; R,H,I,J,G: Integer;
Begin
 HideMouse;
 SaveBack(Sv,DX0,DY0,DX0+DW+4,DY0+DH+4);
 Box(DX0+3,DY0+3,DX0+DW+3,DY0+DH+3,INK);
 DFocus:=0;
 For I:=1 To DN Do If (DI[I].K=DK_EDIT) And (DFocus=0) Then DFocus:=I;
 DlgDraw;
 Done:=False;R:=0;
 Repeat
  PollEvent(E);
  If E.Kind=1 Then Begin
   Case E.Key Of
    K_ENTER: Begin R:=DDef;Done:=True;End;
    K_ESC: Begin R:=DCan;Done:=True;End;
    K_TAB: If DFocus<>0 Then Begin
      J:=DFocus;
      Repeat Inc(J);If J>DN Then J:=1;Until (DI[J].K=DK_EDIT) Or (J=DFocus);
      DFocus:=J;DlgDraw;
     End;
    K_BKSP: If (DFocus<>0) And (Length(DI[DFocus].S)>0) Then Begin
      DI[DFocus].S[0]:=Chr(Length(DI[DFocus].S)-1);DlgDraw;
     End;
   Else
    If (DFocus<>0) And (E.Key>=32) And (E.Key<256) And (Length(DI[DFocus].S)<DI[DFocus].W) Then Begin
     DI[DFocus].S:=DI[DFocus].S+Chr(E.Key);DlgDraw;
    End;
   End;
  End Else If E.Kind=2 Then Begin
   H:=DlgHit(E.X,E.Y);
   If H<>0 Then Case DI[H].K Of
    DK_BUTTON: If Not DI[H].Dis Then Begin R:=H;Done:=True;End;
    DK_CHECK: Begin DI[H].On:=Not DI[H].On;DlgDraw;End;
    DK_RADIO: Begin
      G:=DI[H].Grp;
      For I:=1 To DN Do If (DI[I].K=DK_RADIO) And (DI[I].Grp=G) Then DI[I].On:=False;
      DI[H].On:=True;DlgDraw;
     End;
    DK_EDIT: Begin DFocus:=H;DlgDraw;End;
   End;
  End;
 Until Done;
 HideMouse;
 RestoreBack(Sv);
 ShowMouse;
 RunDlg:=R;
End;

Function OkS: String;
Begin
 OkS:='OK';
End;

Function CancelS: String;
Begin
 CancelS:=T3('Cancel','Annuler','Abbruch');
End;

{ ------------------------- boites du gestionnaire --------------------- }

Procedure DlgAbout(Const Title,Line1,Line2: String);
Var I: Integer;
Begin
 DlgInit(280,162,2);
 DlgAdd(DK_TITLE,0,21,0,0,Title);
 DlgAdd(DK_LABEL,16,57,0,0,Line1);
 DlgAdd(DK_LABEL,16,73,0,0,Line2);
 DDef:=DlgAdd(DK_BUTTON,110,110,60,37,'OK');DCan:=DDef;
 I:=RunDlg;
End;

Procedure ShowLoading(Const What: String);
{ boite 'Loading the X... Please wait...' affichee brievement }
Var Sv: TSave; X1,Y1,X2,Y2: Integer;
Begin
 X1:=(SCR_W-320) Div 2;Y1:=(SCR_H-82) Div 2;X2:=X1+320;Y2:=Y1+82;
 HideMouse;
 SaveBack(Sv,X1,Y1,X2+4,Y2+4);
 Box(X1+3,Y1+3,X2+3,Y2+3,INK);
 DlgFrame(X1,Y1,X2,Y2,2);
 PText(X1+68,Y1+22,T3('Loading the ','Chargement de ','Lade ')+What+'...');
 PText(X1+72,Y1+54,T3('Please wait...','Veuillez patienter...','Bitte warten...'));
 If Not Headless Then Delay(450);
 RestoreBack(Sv);
 ShowMouse;
End;

Var
 LinkSv   : TSave;
 LinkShown: Boolean;

Procedure ShowLinker(Const OutName,Lib: String; Show: Boolean);
Var X1,Y1,X2,Y2: Integer;
Begin
 If Not Show Then Begin
  If LinkShown Then Begin HideMouse;RestoreBack(LinkSv);ShowMouse;LinkShown:=False;End;
  Exit;
 End;
 X1:=(SCR_W-344) Div 2;Y1:=(SCR_H-145) Div 2;X2:=X1+344;Y2:=Y1+145;
 HideMouse;
 If Not LinkShown Then SaveBack(LinkSv,X1,Y1,X2+4,Y2+4);
 LinkShown:=True;
 Box(X1+3,Y1+3,X2+3,Y2+3,INK);
 DlgFrame(X1,Y1,X2,Y2,2);
 PText(X1+16,Y1+19,'Personal Pascal Linker --  '+T3('version ','version ','Version ')+VERSION_TEXT);
 PText(X1+32,Y1+35,'Copyright (c) 1989  CCD and ICD, Inc.');
 PText(X1+16,Y1+67,T3('Output file:','Fichier sortie:','Ausgabedatei:')+'  '+OutName);
 PText(X1+16,Y1+99,T3('Linking:    ','Liaison:     ','Linken:      ')+'  '+Lib);
 Button(X1+255,Y1+62,X1+329,Y1+97,CancelS,False,True);
 ShowMouse;
End;

Procedure ProgTypeRadios(Y: Integer; T: Integer);
Var I: Integer;
Begin
 DlgAdd(DK_LABEL,18,Y+6,0,0,T3('Program type:','Type de prog.:','Programmtyp:'));
 I:=DlgAdd(DK_RADIO,146,Y,41,18,'GEM');DI[I].Grp:=1;DI[I].On:=(T=0);
 I:=DlgAdd(DK_RADIO,202,Y,41,18,'TOS');DI[I].Grp:=1;DI[I].On:=(T=1);
 I:=DlgAdd(DK_RADIO,258,Y,41,18,'ACC');DI[I].Grp:=1;DI[I].On:=(T=2);
End;

Function DlgCompilerOptions: Boolean;
Var I,R,Cb: Integer; Ix: Array[1..8] Of Integer;
Begin
 DlgInit(364,293,1);
 DlgAdd(DK_TITLE,0,23,0,0,'Compiler Options');
 ProgTypeRadios(50,Conf.ProgType);
 Ix[1]:=DlgAdd(DK_CHECK,18,83,0,0,T3('Pause After Errors','Pause sur erreur','Pause bei Fehlern'));
 Ix[2]:=DlgAdd(DK_CHECK,202,83,0,0,T3('Chain To Linker','Chainer linker','Linker folgt'));
 DlgAdd(DK_LABEL,18,119,0,0,T3('Debug options:','Options de debogage:','Debug-Optionen:'));
 Ix[3]:=DlgAdd(DK_CHECK,18,147,0,0,T3('Full Debug Mode','Debogage complet','Voll-Debug'));
 Ix[4]:=DlgAdd(DK_CHECK,178,147,0,0,T3('Print Listing','Imprimer listing','Listing drucken'));
 Ix[5]:=DlgAdd(DK_CHECK,18,179,0,0,T3('Range Checking','Controle bornes','Bereichspruefung'));
 Ix[6]:=DlgAdd(DK_CHECK,178,179,0,0,T3('Clear Variables','Effacer variables','Variablen loeschen'));
 Ix[7]:=DlgAdd(DK_CHECK,18,211,0,0,T3('Stack and Pointer Checking','Controle pile/pointeurs','Stapel/Zeigerpruefung'));
 DI[Ix[1]].On:=Conf.PauseErr;DI[Ix[2]].On:=Conf.ChainLink;DI[Ix[3]].On:=Conf.FullDebug;
 DI[Ix[4]].On:=Conf.PrintList;DI[Ix[5]].On:=Conf.RangeChk;DI[Ix[6]].On:=Conf.ClearVars;
 DI[Ix[7]].On:=Conf.StackChk;
 DDef:=DlgAdd(DK_BUTTON,88,241,70,36,'OK');
 DCan:=DlgAdd(DK_BUTTON,208,241,67,36,CancelS);
 R:=RunDlg;
 DlgCompilerOptions:=(R=DDef);
 If R=DDef Then Begin
  Cb:=0;
  For I:=1 To DN Do If DI[I].K=DK_RADIO Then Begin If DI[I].On Then Conf.ProgType:=Cb;Inc(Cb);End;
  Conf.PauseErr:=DI[Ix[1]].On;Conf.ChainLink:=DI[Ix[2]].On;Conf.FullDebug:=DI[Ix[3]].On;
  Conf.PrintList:=DI[Ix[4]].On;Conf.RangeChk:=DI[Ix[5]].On;Conf.ClearVars:=DI[Ix[6]].On;
  Conf.StackChk:=DI[Ix[7]].On;
 End;
End;

Function DlgLinkerOptions: Boolean;
Var I,R,E1,C1: Integer;
Begin
 DlgInit(364,230,1);
 DlgAdd(DK_TITLE,0,23,0,0,'Linker Options');
 ProgTypeRadios(50,LinkType);
 DlgAdd(DK_LABEL,18,92,0,0,T3('Additional link files:','Fichiers a lier en plus:','Zusaetzliche Dateien:'));
 E1:=DlgAdd(DK_EDIT,18,110,40,16,LinkExtra);
 C1:=DlgAdd(DK_CHECK,18,142,0,0,T3('Ask for file to link','Demander fichier a lier','Datei zum Linken fragen'));
 DI[C1].On:=LinkAsk;
 DDef:=DlgAdd(DK_BUTTON,88,176,70,36,'OK');
 DCan:=DlgAdd(DK_BUTTON,208,176,67,36,CancelS);
 R:=RunDlg;
 DlgLinkerOptions:=(R=DDef);
 If R=DDef Then Begin
  R:=0;
  For I:=1 To DN Do If DI[I].K=DK_RADIO Then Begin If DI[I].On Then LinkType:=R;Inc(R);End;
  LinkExtra:=DI[E1].S;LinkAsk:=DI[C1].On;
 End;
End;

Procedure DlgLocatePrograms;
Var R,I: Integer; B: Array[1..6] Of Integer; Sel: String;
Const Nm : Array[1..6] Of String[8] = ('Editor','Compiler','Linker','PASGEM','PASLIB','Printer');
Begin
 Repeat
  DlgInit(296,162,2);
  DlgAdd(DK_TITLE,0,21,0,0,'Locate Program:');
  B[1]:=DlgAdd(DK_BUTTON,14,47,76,21,Nm[1]);
  B[2]:=DlgAdd(DK_BUTTON,111,47,75,21,Nm[2]);
  B[3]:=DlgAdd(DK_BUTTON,206,47,76,21,Nm[3]);
  B[4]:=DlgAdd(DK_BUTTON,14,79,76,20,Nm[4]);
  B[5]:=DlgAdd(DK_BUTTON,111,79,75,20,Nm[5]);
  B[6]:=DlgAdd(DK_BUTTON,206,79,76,20,Nm[6]);
  DDef:=DlgAdd(DK_BUTTON,118,110,60,37,'Exit');DCan:=DDef;
  R:=RunDlg;
  If (R<>0) And (R<>DDef) Then Begin
   For I:=1 To 6 Do If B[I]=R Then Begin
    Sel:=PathNm[I];
    If I=6 Then Begin
     FormLbl[1]:=Nm[I];FormVal[1]:=PathNm[I];FormFW:=40;
     If FormBox('Locate Program',1,'') Then PathNm[I]:=FormVal[1];
    End Else If FileSelect(Nm[I],'*.*',Sel) Then PathNm[I]:=Sel;
   End;
  End;
 Until (R=0) Or (R=DDef);
End;

{ ------------------------- fichier d'options (.INF) ------------------- }

Function BoolStr(B: Boolean): String;
Begin
 If B Then BoolStr:='1' Else BoolStr:='0';
End;

Procedure SaveOptions(Const Name: String);
Var F: Text; I: Integer;
Begin
 Assign(F,Name);
 {$I-}Rewrite(F);{$I+}
 If IOResult<>0 Then Begin MsgBox(T3('Cannot write ','Ecriture impossible : ','Kann nicht schreiben: ')+Name);Exit;End;
 WriteLn(F,'PROGTYPE=',Conf.ProgType);
 WriteLn(F,'PAUSE=',BoolStr(Conf.PauseErr));
 WriteLn(F,'CHAIN=',BoolStr(Conf.ChainLink));
 WriteLn(F,'DEBUG=',BoolStr(Conf.FullDebug));
 WriteLn(F,'LIST=',BoolStr(Conf.PrintList));
 WriteLn(F,'RANGE=',BoolStr(Conf.RangeChk));
 WriteLn(F,'CLEAR=',BoolStr(Conf.ClearVars));
 WriteLn(F,'STACK=',BoolStr(Conf.StackChk));
 WriteLn(F,'LINKTYPE=',LinkType);
 WriteLn(F,'LINKEXTRA=',LinkExtra);
 WriteLn(F,'LINKASK=',BoolStr(LinkAsk));
 For I:=1 To 6 Do WriteLn(F,'PATH',I,'=',PathNm[I]);
 For I:=1 To SrcCnt Do WriteLn(F,'SRC',I,'=',SrcList[I]);
 Close(F);
End;

Function LoadOptions(Const Name: String): Boolean;
Var F: Text; S,K,V: String; P,N,C: Integer;
Begin
 LoadOptions:=False;
 If Not FileExists(Name) Then Exit;
 Assign(F,Name);
 {$I-}Reset(F);{$I+}
 If IOResult<>0 Then Exit;
 SrcCnt:=0;
 While Not Eof(F) Do Begin
  ReadLn(F,S);
  P:=Pos('=',S);
  If P>0 Then Begin
   K:=Upper(Copy(S,1,P-1));V:=Copy(S,P+1,200);
   Val(V,N,C);
   If K='PROGTYPE' Then Conf.ProgType:=N
   Else If K='PAUSE' Then Conf.PauseErr:=(V='1')
   Else If K='CHAIN' Then Conf.ChainLink:=(V='1')
   Else If K='DEBUG' Then Conf.FullDebug:=(V='1')
   Else If K='LIST' Then Conf.PrintList:=(V='1')
   Else If K='RANGE' Then Conf.RangeChk:=(V='1')
   Else If K='CLEAR' Then Conf.ClearVars:=(V='1')
   Else If K='STACK' Then Conf.StackChk:=(V='1')
   Else If K='LINKTYPE' Then LinkType:=N
   Else If K='LINKEXTRA' Then LinkExtra:=V
   Else If K='LINKASK' Then LinkAsk:=(V='1')
   Else If (Copy(K,1,4)='PATH') And (Length(K)=5) And (K[5]>='1') And (K[5]<='6') Then PathNm[Ord(K[5])-48]:=V
   Else If (Copy(K,1,3)='SRC') And (SrcCnt<16) Then Begin Inc(SrcCnt);SrcList[SrcCnt]:=V;End;
  End;
 End;
 Close(F);
 LoadOptions:=True;
End;

Procedure InitConfig;
Begin
 FillChar(Conf,SizeOf(Conf),0);
 Conf.ProgType:=0;Conf.PauseErr:=True;Conf.ChainLink:=True;Conf.FullDebug:=True;
 Conf.RangeChk:=True;Conf.ClearVars:=True;Conf.StackChk:=True;
 LinkType:=0;LinkExtra:='';LinkAsk:=False;SrcCnt:=0;
 PathNm[1]:='EDIT.PRG';PathNm[2]:='COMPILER.PRG';PathNm[3]:='LINKER.PRG';
 PathNm[4]:='PASGEM';PathNm[5]:='PASLIB';PathNm[6]:='PRN';
 EdInsert:=True;EdAuto:=True;EdTab:=8;DrvLetter:='A';
End;

{ ====================================================================== }
{                  EDITEUR PLEIN ECRAN (3 ESPACES FICHIERS)              }
{ ====================================================================== }

Const
 MAXEDL = 4000;
 ED_Y0  = MENU_H+TITLE_H;
 ED_ROWS = 26;
 ED_COLS = 77;

Type
 TEdBuf = Record
  Used  : Boolean;
  Name  : String[80];
  L     : Array[1..MAXEDL] Of PString;
  N     : Integer;
  Row,Col,Top,Left : Integer;
  Dirty : Boolean;
 End;

Var
 Eb      : Array[1..3] Of TEdBuf;
 EbCur   : Integer;
 EdMarks : Array[1..4] Of Integer;
 BlkS,BlkE : Integer;
 BlkBuf  : Array[1..MAXEDL] Of PString;
 BlkN    : Integer;
 FindStr,ReplStr : String[60];
 FindCase: Boolean;
 ReplQuery: Boolean;        (* Replace All : avec confirmation *)
 EdMsg   : String;
 EdQuit  : Boolean;
 EdAction: Integer;
 EdBack  : Boolean;
 PrnF    : Text;

Function AltLetter(K: Integer): Char;
Const Sc : Array[0..25] Of Byte = (30,48,46,32,18,33,34,35,23,36,37,38,50,49,24,25,16,19,31,20,22,47,17,45,21,44);
Var I: Integer;
Begin
 AltLetter:=#0;
 If K<256 Then Exit;
 For I:=0 To 25 Do If Sc[I]=K-256 Then AltLetter:=Chr(65+I);
End;

Procedure EdClearBuf(I: Integer);
Var J: Integer;
Begin
 For J:=1 To Eb[I].N Do FreeStr(Eb[I].L[J]);
 Eb[I].N:=1;Eb[I].L[1]:=NewStr('');
 Eb[I].Row:=1;Eb[I].Col:=1;Eb[I].Top:=1;Eb[I].Left:=0;Eb[I].Dirty:=False;
End;

Procedure EdInitAll;
Var I: Integer;
Begin
 For I:=1 To 3 Do Begin
  Eb[I].Used:=False;Eb[I].N:=0;Eb[I].Name:='';
 End;
 EbCur:=1;BlkS:=0;BlkE:=0;BlkN:=0;
 For I:=1 To 4 Do EdMarks[I]:=0;
 FindStr:='';ReplStr:='';FindCase:=False;ReplQuery:=False;EdMsg:='';
End;

Function ExpandTabs(Const S: String): String;
Var R: String; I: Integer;
Begin
 R:='';
 For I:=1 To Length(S) Do
  If S[I]=#9 Then Begin
   Repeat R:=R+' ';Until (Length(R) Mod 8=0) Or (Length(R)>=250);
  End Else If S[I]<>#13 Then R:=R+S[I];
 ExpandTabs:=Copy(R,1,159);
End;

Function EdLoadFile(I: Integer; Const Name: String): Boolean;
Var F: Text; S: String; Nm: String;
Begin
 EdLoadFile:=False;
 EdClearBuf(I);
 Eb[I].Used:=True;Eb[I].Name:=Name;
 Nm:=ResolveFile(Name);
 If Not FileExists(Nm) Then Exit;
 Assign(F,Nm);
 {$I-}Reset(F);{$I+}
 If IOResult<>0 Then Exit;
 FreeStr(Eb[I].L[1]);Eb[I].N:=0;
 While (Not Eof(F)) And (Eb[I].N<MAXEDL) Do Begin
  {$I-}ReadLn(F,S);{$I+}
  If IOResult<>0 Then Break;
  Inc(Eb[I].N);Eb[I].L[Eb[I].N]:=NewStr(ExpandTabs(S));
 End;
 Close(F);
 If Eb[I].N=0 Then Begin Eb[I].N:=1;Eb[I].L[1]:=NewStr('');End;
 EdLoadFile:=True;
End;

Function EdSaveFile(I: Integer; Const Name: String): Boolean;
Var F: Text; J: Integer;
Begin
 EdSaveFile:=False;
 Assign(F,Name);
 {$I-}Rewrite(F);{$I+}
 If IOResult<>0 Then Exit;
 For J:=1 To Eb[I].N Do WriteLn(F,Eb[I].L[J]^);
 Close(F);
 If Name=Eb[I].Name Then Eb[I].Dirty:=False;
 EdSaveFile:=True;
End;

Procedure EdSetLine(I,Ln: Integer; Const S: String);
Begin
 FreeStr(Eb[I].L[Ln]);
 Eb[I].L[Ln]:=NewStr(Copy(S,1,159));
End;

Procedure EdInsLineAt(I,Ln: Integer; Const S: String);
Var J: Integer;
Begin
 If Eb[I].N>=MAXEDL Then Exit;
 For J:=Eb[I].N DownTo Ln Do Eb[I].L[J+1]:=Eb[I].L[J];
 Inc(Eb[I].N);
 Eb[I].L[Ln]:=NewStr(Copy(S,1,159));
 Eb[I].Dirty:=True;
End;

Procedure EdDelLineAt(I,Ln: Integer);
Var J: Integer;
Begin
 If Eb[I].N<=1 Then Begin EdSetLine(I,1,'');Exit;End;
 FreeStr(Eb[I].L[Ln]);
 For J:=Ln To Eb[I].N-1 Do Eb[I].L[J]:=Eb[I].L[J+1];
 Eb[I].L[Eb[I].N]:=Nil;
 Dec(Eb[I].N);
 Eb[I].Dirty:=True;
End;

Procedure EdKeepVisible;
Var B: ^TEdBuf;
Begin
 B:=@Eb[EbCur];
 If B^.Row<1 Then B^.Row:=1;
 If B^.Row>B^.N Then B^.Row:=B^.N;
 If B^.Col<1 Then B^.Col:=1;
 If B^.Col>159 Then B^.Col:=159;
 If B^.Row<B^.Top Then B^.Top:=B^.Row;
 If B^.Row>B^.Top+ED_ROWS-1 Then B^.Top:=B^.Row-ED_ROWS+1;
 If B^.Col<=B^.Left Then B^.Left:=B^.Col-1;
 If B^.Col>B^.Left+ED_COLS Then B^.Left:=B^.Col-ED_COLS;
 If B^.Left<0 Then B^.Left:=0;
End;

{ ------------------------------ affichage ------------------------------ }

Procedure EdDrawBars;
Var B: ^TEdBuf; X1,Y1,X2,Y2,TL,TH,TP,I: Integer;
Begin
 B:=@Eb[EbCur];
 { barre verticale }
 X1:=SCR_W-SB;Y1:=ED_Y0;Y2:=SCR_H-1-SB;
 Box(X1,Y1,SCR_W-1,Y2,PAPER);Frame(X1,Y1,SCR_W-1,Y2);
 ArrowBox(X1,Y1,SCR_W-1,Y1+SB-1,1);
 ArrowBox(X1,Y2-SB+1,SCR_W-1,Y2,2);
 PatBar(X1+1,Y1+SB,SCR_W-2,Y2-SB,PatChecker);
 TL:=Y2-SB-(Y1+SB)-1;
 If B^.N>ED_ROWS Then Begin
  TH:=TL*ED_ROWS Div B^.N;If TH<8 Then TH:=8;
  TP:=(B^.Top-1)*(TL-TH) Div (B^.N-ED_ROWS);
  If TP<0 Then TP:=0;If TP>TL-TH Then TP:=TL-TH;
  Box(X1+1,Y1+SB+1+TP,SCR_W-2,Y1+SB+TP+TH,PAPER);
  Frame(X1+1,Y1+SB+1+TP,SCR_W-2,Y1+SB+TP+TH);
 End Else Box(X1+1,Y1+SB+1,SCR_W-2,Y2-SB-1,PAPER);
 { barre horizontale }
 Y1:=SCR_H-SB;X2:=SCR_W-1-SB;
 Box(0,Y1,X2,SCR_H-1,PAPER);Frame(0,Y1,X2,SCR_H-1);
 ArrowBox(0,Y1,SB-1,SCR_H-1,3);
 ArrowBox(X2-SB+1,Y1,X2,SCR_H-1,4);
 PatBar(SB,Y1+1,X2-SB,SCR_H-2,PatChecker);
 TL:=X2-SB-SB-1;
 TH:=TL*ED_COLS Div 159;If TH<8 Then TH:=8;
 TP:=B^.Left*(TL-TH) Div (159-ED_COLS);
 If TP<0 Then TP:=0;If TP>TL-TH Then TP:=TL-TH;
 Box(SB+1+TP,Y1+1,SB+TP+TH,SCR_H-2,PAPER);Frame(SB+1+TP,Y1+1,SB+TP+TH,SCR_H-2);
 Box(SCR_W-SB,SCR_H-SB,SCR_W-1,SCR_H-1,PAPER);Frame(SCR_W-SB,SCR_H-SB,SCR_W-1,SCR_H-1);
End;

Procedure EdDrawTitle;
Var B: ^TEdBuf; S: String; I,X: Integer;
Begin
 B:=@Eb[EbCur];
 Box(0,MENU_H,SCR_W-1,ED_Y0-1,PAPER);
 SetColor(INK);Line(0,ED_Y0-1,SCR_W-1,ED_Y0-1);
 Box(2,MENU_H+1,SB,ED_Y0-3,PAPER);Frame(2,MENU_H+1,SB,ED_Y0-3);Frame(6,MENU_H+5,SB-4,ED_Y0-7);
 PText(SB+14,MENU_H+5,'Line: '+IntStr(B^.Row));
 If EdMsg<>'' Then S:=EdMsg
 Else Begin
  S:='Filename: ';
  If B^.Name='' Then S:=S+T3('(new)','(nouveau)','(neu)') Else S:=S+ShortName(B^.Name);
  If B^.Dirty Then S:=S+' *';
 End;
 PText(176,MENU_H+5,Copy(S,1,36));
 { indicateurs 1 2 3 }
 For I:=1 To 3 Do Begin
  X:=SCR_W-SB*6+(I-1)*(SB+2);
  If I=EbCur Then Begin Box(X,MENU_H+2,X+SB,ED_Y0-4,INK);WText(X+4,MENU_H+5,IntStr(I));End
  Else Begin
   Box(X,MENU_H+2,X+SB,ED_Y0-4,PAPER);Frame(X,MENU_H+2,X+SB,ED_Y0-4);
   If Eb[I].Used Then PText(X+4,MENU_H+5,IntStr(I)) Else Frame(X+4,MENU_H+5,X+SB-4,ED_Y0-7);
  End;
 End;
 X:=SCR_W-SB-1;
 Box(X,MENU_H+2,SCR_W-2,ED_Y0-4,PAPER);Frame(X,MENU_H+2,SCR_W-2,ED_Y0-4);Frame(X+4,MENU_H+5,SCR_W-6,ED_Y0-7);
End;

Procedure EdDrawText;
Var B: ^TEdBuf; R,Ln,X,Y: Integer; S: String; InBlk: Boolean; Ch: String;
Begin
 B:=@Eb[EbCur];
 Box(0,ED_Y0,SCR_W-SB-1,SCR_H-SB-1,PAPER);
 For R:=0 To ED_ROWS-1 Do Begin
  Ln:=B^.Top+R;
  If Ln>B^.N Then Break;
  Y:=ED_Y0+R*16+4;
  S:=Copy(B^.L[Ln]^,B^.Left+1,ED_COLS+1);
  InBlk:=(BlkS>0) And (BlkE>0) And (Ln>=BlkS) And (Ln<=BlkE);
  If InBlk Then BText(4,Y,S) Else PText(4,Y,S);
 End;
 { curseur }
 If (B^.Row>=B^.Top) And (B^.Row<=B^.Top+ED_ROWS-1) Then Begin
  X:=4+(B^.Col-1-B^.Left)*8;Y:=ED_Y0+(B^.Row-B^.Top)*16;
  If (X>=0) And (X<SCR_W-SB-8) Then Begin
   Box(X,Y+1,X+7,Y+14,INK);
   If B^.Col<=Length(B^.L[B^.Row]^) Then Begin
    Ch:=B^.L[B^.Row]^[B^.Col];
    WText(X,Y+4,Ch);
   End;
  End;
 End;
End;

Procedure EdDraw;
Begin
 HideMouse;
 SetViewPort(0,0,SCR_W-1,SCR_H-1,True);
 EdKeepVisible;
 EdDrawText;
 EdDrawTitle;
 EdDrawBars;
 DrawMenuBar;
 DrawDropDown;
 ShowMouse;
End;

{ ------------------------- operations d'edition ------------------------ }

Function CurLineStr: String;
Begin
 CurLineStr:=Eb[EbCur].L[Eb[EbCur].Row]^;
End;

Procedure EdTypeChar(Ch: Char);
Var B: ^TEdBuf; S: String;
Begin
 B:=@Eb[EbCur];
 S:=B^.L[B^.Row]^;
 While Length(S)<B^.Col-1 Do S:=S+' ';
 If EdInsert Or (B^.Col>Length(S)) Then Begin
  If Length(S)>=159 Then Exit;
  Insert(Ch,S,B^.Col);
 End Else S[B^.Col]:=Ch;
 EdSetLine(EbCur,B^.Row,S);
 Inc(B^.Col);B^.Dirty:=True;
End;

Procedure EdEnter;
Var B: ^TEdBuf; S,Rest,Ind: String; I: Integer;
Begin
 B:=@Eb[EbCur];
 S:=B^.L[B^.Row]^;
 Rest:=Copy(S,B^.Col,200);
 S:=Copy(S,1,B^.Col-1);
 Ind:='';
 If EdAuto Then Begin
  I:=1;
  While (I<=Length(S)) And (S[I]=' ') Do Begin Ind:=Ind+' ';Inc(I);End;
  If I>Length(S) Then Ind:=Copy(Ind,1,Length(Ind));
 End;
 EdSetLine(EbCur,B^.Row,S);
 EdInsLineAt(EbCur,B^.Row+1,Ind+Rest);
 Inc(B^.Row);B^.Col:=Length(Ind)+1;
End;

Procedure EdBackspace;
Var B: ^TEdBuf; S,P: String;
Begin
 B:=@Eb[EbCur];
 If B^.Col>1 Then Begin
  S:=B^.L[B^.Row]^;
  If B^.Col-1<=Length(S) Then Begin Delete(S,B^.Col-1,1);EdSetLine(EbCur,B^.Row,S);End;
  Dec(B^.Col);B^.Dirty:=True;
 End Else If B^.Row>1 Then Begin
  P:=B^.L[B^.Row-1]^;S:=B^.L[B^.Row]^;
  B^.Col:=Length(P)+1;
  EdSetLine(EbCur,B^.Row-1,P+S);
  EdDelLineAt(EbCur,B^.Row);
  Dec(B^.Row);
 End;
End;

Procedure EdDelete;
Var B: ^TEdBuf; S: String;
Begin
 B:=@Eb[EbCur];
 S:=B^.L[B^.Row]^;
 If B^.Col<=Length(S) Then Begin Delete(S,B^.Col,1);EdSetLine(EbCur,B^.Row,S);B^.Dirty:=True;End
 Else If B^.Row<B^.N Then Begin
  EdSetLine(EbCur,B^.Row,S+B^.L[B^.Row+1]^);
  EdDelLineAt(EbCur,B^.Row+1);
 End;
End;

Procedure EdTabKey;
Var B: ^TEdBuf; N: Integer;
Begin
 B:=@Eb[EbCur];
 N:=EdTab-((B^.Col-1) Mod EdTab);
 If EdInsert Then Begin
  While N>0 Do Begin EdTypeChar(' ');Dec(N);End;
 End Else Inc(B^.Col,N);
End;

Procedure EdGotoLine(Ln: Integer);
Var B: ^TEdBuf;
Begin
 B:=@Eb[EbCur];
 If Ln<1 Then Ln:=1;
 If Ln>B^.N Then Ln:=B^.N;
 B^.Row:=Ln;
 B^.Col:=1;
 B^.Top:=Ln-(ED_ROWS Div 2);
 If B^.Top<1 Then B^.Top:=1;
End;

Function EdPos(Const Pat,S: String; From: Integer): Integer;
Var P: Integer;
Begin
 EdPos:=0;
 If From>Length(S) Then Exit;
 If FindCase Then P:=Pos(Pat,Copy(S,From,255))
 Else P:=Pos(Upper(Pat),Upper(Copy(S,From,255)));
 If P>0 Then EdPos:=P+From-1;
End;

Function EdFind(Fwd: Boolean): Boolean;
Var B: ^TEdBuf; Ln,P,K: Integer; S: String;
Begin
 EdFind:=False;
 If FindStr='' Then Exit;
 B:=@Eb[EbCur];
 If Fwd Then Begin
  Ln:=B^.Row;P:=EdPos(FindStr,B^.L[Ln]^,B^.Col+1);
  While (P=0) And (Ln<B^.N) Do Begin Inc(Ln);P:=EdPos(FindStr,B^.L[Ln]^,1);End;
  If P>0 Then Begin B^.Row:=Ln;B^.Col:=P;EdFind:=True;End;
 End Else Begin
  Ln:=B^.Row;P:=0;
  S:=B^.L[Ln]^;
  K:=EdPos(FindStr,S,1);
  While (K>0) And (K<B^.Col) Do Begin P:=K;K:=EdPos(FindStr,S,K+1);End;
  While (P=0) And (Ln>1) Do Begin
   Dec(Ln);S:=B^.L[Ln]^;K:=EdPos(FindStr,S,1);
   While K>0 Do Begin P:=K;K:=EdPos(FindStr,S,K+1);End;
  End;
  If P>0 Then Begin B^.Row:=Ln;B^.Col:=P;EdFind:=True;End;
 End;
 If Not EdFind Then EdMsg:=T3('Not found','Introuvable','Nicht gefunden');
End;

Procedure EdReplaceHere;
Var B: ^TEdBuf; S: String;
Begin
 B:=@Eb[EbCur];
 S:=B^.L[B^.Row]^;
 If EdPos(FindStr,S,B^.Col)=B^.Col Then Begin
  Delete(S,B^.Col,Length(FindStr));
  Insert(ReplStr,S,B^.Col);
  EdSetLine(EbCur,B^.Row,S);B^.Dirty:=True;
  Inc(B^.Col,Length(ReplStr));
 End;
End;

Function EdQueryReplace(Const Ctx: String): Integer;
{ 1 remplacer, 2 ignorer, 3 tout remplacer, 0 annuler }
Var B1,B2,B3,R: Integer;
Begin
 DlgInit(420,150,2);
 DlgAdd(DK_TITLE,0,14,0,0,T3('Replace?','Remplacer ?','Ersetzen?'));
 DlgAdd(DK_LABEL,18,44,0,0,Copy(Ctx,1,44));
 B1:=DlgAdd(DK_BUTTON,14,90,88,30,T3('Replace','Remplacer','Ersetzen'));
 B2:=DlgAdd(DK_BUTTON,108,90,88,30,T3('Skip','Ignorer','Weiter'));
 B3:=DlgAdd(DK_BUTTON,202,90,88,30,T3('All','Tout','Alle'));
 DCan:=DlgAdd(DK_BUTTON,296,90,100,30,CancelS);DDef:=B1;
 R:=RunDlg;
 If R=B1 Then EdQueryReplace:=1
 Else If R=B2 Then EdQueryReplace:=2
 Else If R=B3 Then EdQueryReplace:=3
 Else EdQueryReplace:=0;
End;

Procedure EdFindWhat;
Var E1,E2,R1,R2,I,R,Q1,Q2: Integer;
Begin
 DlgInit(380,240,1);
 DlgAdd(DK_TITLE,0,14,0,0,T3('Find What','Chercher quoi','Suchen nach'));
 DlgAdd(DK_LABEL,18,40,0,0,T3('Target:','Cible :','Ziel:'));
 E1:=DlgAdd(DK_EDIT,100,36,30,16,FindStr);
 DlgAdd(DK_LABEL,18,68,0,0,T3('Replace:','Remplacer :','Ersetzen:'));
 E2:=DlgAdd(DK_EDIT,100,64,30,16,ReplStr);
 R1:=DlgAdd(DK_RADIO,18,98,110,18,T3('Match case','Respecter casse','Gross/klein'));DI[R1].Grp:=1;DI[R1].On:=FindCase;
 R2:=DlgAdd(DK_RADIO,140,98,110,18,T3('Ignore case','Ignorer casse','Ignorieren'));DI[R2].Grp:=1;DI[R2].On:=Not FindCase;
 Q1:=DlgAdd(DK_RADIO,18,124,200,18,T3('Replace with query','Remplacer avec requete','Mit Rueckfrage'));DI[Q1].Grp:=2;DI[Q1].On:=ReplQuery;
 Q2:=DlgAdd(DK_RADIO,18,148,200,18,T3('Replace without query','Remplacer sans requete','Ohne Rueckfrage'));DI[Q2].Grp:=2;DI[Q2].On:=Not ReplQuery;
 DDef:=DlgAdd(DK_BUTTON,60,190,70,30,'OK');
 DCan:=DlgAdd(DK_BUTTON,200,190,70,30,CancelS);
 R:=RunDlg;
 If R=DDef Then Begin
  FindStr:=DI[E1].S;ReplStr:=DI[E2].S;FindCase:=DI[R1].On;ReplQuery:=DI[Q1].On;
 End;
End;

Procedure EdStatistics;
Var I,R,Dr: Integer; Free: LongInt; S: String; Mem: LongInt;
Begin
 Dr:=Ord(DrvLetter)-64;
 Repeat
  DlgInit(420,225,2);
  DlgAdd(DK_LABEL,22,17,0,0,'Statistics');
  DDef:=DlgAdd(DK_BUTTON,328,14,70,21,'OK');DCan:=DDef;
  DlgAdd(DK_BOX,17,46,386,107,'');
  DlgAdd(DK_BOX,17,159,386,56,'');
  DlgAdd(DK_LABEL,27,62,0,0,'Filename:');
  DlgAdd(DK_LABEL,180,62,0,0,'Length:');
  DlgAdd(DK_LABEL,275,62,0,0,'Free Space:');
  For I:=1 To 3 Do Begin
   If Eb[I].Used Then Begin
    S:=IntStr(I)+'. '+ShortName(Eb[I].Name);
    DlgAdd(DK_LABEL,27,86+(I-1)*16,0,0,Copy(S,1,18));
    Free:=0;For R:=1 To Eb[I].N Do Free:=Free+Length(Eb[I].L[R]^)+2;
    DlgAdd(DK_LABEL,180,86+(I-1)*16,0,0,IntStr(Free));
    DlgAdd(DK_LABEL,275,86+(I-1)*16,0,0,IntStr(25000)+'   Bytes');
   End Else Begin
    DlgAdd(DK_LABEL,27,86+(I-1)*16,0,0,IntStr(I)+'. Unused');
    DlgAdd(DK_LABEL,180,86+(I-1)*16,0,0,'0');
    DlgAdd(DK_LABEL,275,86+(I-1)*16,0,0,'0   Bytes');
   End;
  End;
  {$IFDEF FPC}
  Free:=DiskFree(Dr) Div 1024;
  If (Free<=0) And (Dr=1) Then Free:=DiskFree(0) Div 1024;
  Mem:=GetFPCHeapStatus.CurrHeapFree Div 1024;
  {$ELSE}
  Free:=DiskFree(Dr) Div 1024;
  Mem:=MemAvail Div 1024;
  {$ENDIF}
  If Free<0 Then Free:=0;
  DlgAdd(DK_LABEL,27,183,0,0,'Free Space:    '+IntStr(Free)+' KByte On Drive:');
  DlgAdd(DK_LABEL,27,199,0,0,'Free Memory:   '+IntStr(Mem)+' KByte');
  R:=DlgAdd(DK_BUTTON,326,178,18,16,'<');
  DlgAdd(DK_LABEL,350,183,0,0,Chr(64+Dr)+':');
  I:=DlgAdd(DK_BUTTON,372,178,18,16,'>');
  R:=RunDlg;
  If R=I-1 Then Begin Dec(Dr);If Dr<1 Then Dr:=16;End
  Else If R=I Then Begin Inc(Dr);If Dr>16 Then Dr:=1;End;
  DrvLetter:=Chr(64+Dr);
 Until (R=DDef) Or (R=0);
End;

Procedure EdClearBlockBuf;
Var I: Integer;
Begin
 For I:=1 To BlkN Do FreeStr(BlkBuf[I]);
 BlkN:=0;
End;

Procedure EdMarkBlock;
Var B: ^TEdBuf; I: Integer;
Begin
 B:=@Eb[EbCur];
 If (BlkS=0) Or ((BlkS>0) And (BlkE>0)) Then Begin
  BlkS:=B^.Row;BlkE:=0;
  EdMsg:=T3('Block start marked','D'#130'but de bloc marqu'#130,'Blockanfang markiert');
 End Else Begin
  If B^.Row<BlkS Then Begin BlkE:=BlkS;BlkS:=B^.Row;End Else BlkE:=B^.Row;
  EdClearBlockBuf;
  For I:=BlkS To BlkE Do If BlkN<MAXEDL Then Begin Inc(BlkN);BlkBuf[BlkN]:=NewStr(B^.L[I]^);End;
  EdMsg:='';
 End;
End;

Procedure EdEraseBlock;
Var I: Integer;
Begin
 If (BlkS>0) And (BlkE>0) Then Begin
  For I:=BlkE DownTo BlkS Do EdDelLineAt(EbCur,I);
  Eb[EbCur].Row:=BlkS;If Eb[EbCur].Row>Eb[EbCur].N Then Eb[EbCur].Row:=Eb[EbCur].N;
  BlkS:=0;BlkE:=0;
 End;
End;

Procedure EdPasteBlock;
Var I: Integer;
Begin
 For I:=1 To BlkN Do EdInsLineAt(EbCur,Eb[EbCur].Row+I-1,BlkBuf[I]^);
End;

Function EdFileDlg(Const Title,Mask: String; Var Nm: String): Boolean;
Begin
 EdFileDlg:=FileSelect(Title,Mask,Nm);
End;

Procedure EdOpenFile(Const Nm: String);
Var I: Integer;
Begin
 I:=1;
 While (I<=3) And Eb[I].Used Do Inc(I);
 If I>3 Then Begin MsgBox(T3('No free file space','Plus d''espace fichier libre','Kein freier Dateiplatz'));Exit;End;
 If (Not EdLoadFile(I,Nm)) And FileExists(ResolveFile(Nm)) Then MsgBox(T3('Cannot read ','Lecture impossible : ','Kann nicht lesen: ')+Nm);
 EbCur:=I;
End;

Function EdAskSave(I: Integer): Boolean;
{ True si on peut continuer }
Var R: Integer;
Begin
 EdAskSave:=True;
 If Not Eb[I].Dirty Then Exit;
 R:=AlertBox(T3('Save changes to |','Sauver les modifications de |','Aenderungen sichern: |')+ShortName(Eb[I].Name)+' ?',
             T3('Save|Discard|Cancel','Sauver|Ignorer|Annuler','Sichern|Verwerfen|Abbruch'));
 If R=1 Then Begin
  If Eb[I].Name='' Then EdAskSave:=False Else EdSaveFile(I,Eb[I].Name);
 End Else If R=3 Then EdAskSave:=False;
End;

Procedure EdCommand(Cmd: Integer);
Var B: ^TEdBuf; Nm: String; N,C: Integer; I: Integer; Qa: Boolean; Qr,Sk: Integer;
Begin
 B:=@Eb[EbCur];
 EdMsg:='';
 Case Cmd Of
  E_NEW: Begin If EdAskSave(EbCur) Then Begin EdClearBuf(EbCur);Eb[EbCur].Name:='';End;End;
  E_OPEN: Begin Nm:='';If EdFileDlg(T3('Open','Ouvrir','Oeffnen'),'*.PAS',Nm) Then EdOpenFile(Nm);End;
  E_SAVE: Begin
    If B^.Name='' Then Begin
     Nm:=LastFile;If EdFileDlg(T3('Save as','Sauver sous','Speichern als'),'*.PAS',Nm) Then Begin B^.Name:=Nm;EdSaveFile(EbCur,Nm);End;
    End Else If Not EdSaveFile(EbCur,B^.Name) Then MsgBox(T3('Cannot save ','Sauvegarde impossible : ','Kann nicht sichern: ')+B^.Name);
   End;
  E_SAVEAS: Begin
    Nm:=B^.Name;
    If EdFileDlg(T3('Save as','Sauver sous','Speichern als'),'*.PAS',Nm) Then Begin B^.Name:=Nm;EdSaveFile(EbCur,Nm);End;
   End;
  E_QUIT: Begin
    For I:=1 To 3 Do If Eb[I].Used And (Not EdAskSave(I)) Then Exit;
    EdQuit:=True;EdAction:=0;
   End;
  E_COMPILER,E_LINKER: Begin
    For I:=1 To 3 Do If Eb[I].Used And Eb[I].Dirty And (Eb[I].Name<>'') Then EdSaveFile(I,Eb[I].Name);
    If B^.Name='' Then Begin MsgBox(T3('Save the file first','Sauvez d''abord le fichier','Erst Datei speichern'));Exit;End;
    EdQuit:=True;
    If Cmd=E_COMPILER Then EdAction:=1 Else EdAction:=2;
   End;
  E_MARK: EdMarkBlock;
  E_ERASE: EdEraseBlock;
  E_PASTE: EdPasteBlock;
  E_HIDE: Begin BlkS:=0;BlkE:=0;End;
  E_LOADB: Begin
    Nm:='';
    If EdFileDlg(T3('Load Block','Charger bloc','Block laden'),'*.*',Nm) Then Begin
     I:=1;While (I<=3) And Eb[I].Used Do Inc(I);
     If I<=3 Then Begin
      EdLoadFile(I,Nm);
      EdClearBlockBuf;
      For N:=1 To Eb[I].N Do If BlkN<MAXEDL Then Begin Inc(BlkN);BlkBuf[BlkN]:=NewStr(Eb[I].L[N]^);End;
      Eb[I].Used:=False;EdClearBuf(I);
     End;
    End;
   End;
  E_SAVEB: Begin
    If BlkN=0 Then Exit;
    Nm:='';
    If EdFileDlg(T3('Save Block','Sauver bloc','Block speichern'),'*.*',Nm) Then Begin
     Assign(PrnF,Nm);
     {$I-}Rewrite(PrnF);{$I+}
     If IOResult<>0 Then MsgBox(T3('Cannot save ','Sauvegarde impossible : ','Kann nicht sichern: ')+Nm)
     Else Begin
      For I:=1 To BlkN Do WriteLn(PrnF,BlkBuf[I]^);
      Close(PrnF);
     End;
    End;
   End;
  E_FINDW: EdFindWhat;
  E_FINDN: EdFind(True);
  E_FINDP: EdFind(False);
  E_REPN: Begin EdReplaceHere;EdFind(True);End;
  E_REPA: Begin
    C:=0;Qa:=ReplQuery;Sk:=0;
    B^.Row:=1;B^.Col:=0;
    While EdFind(True) Do Begin
     Qr:=1;
     If Qa Then Begin
      Qr:=EdQueryReplace(Copy(B^.L[B^.Row]^,B^.Col,44));
      If Qr=3 Then Begin Qa:=False;Qr:=1;End;
     End;
     If Qr=0 Then Break;
     If Qr=1 Then Begin
      EdReplaceHere;Inc(C);
      If B^.Col>0 Then Dec(B^.Col);
     End Else Inc(Sk);
     If C+Sk>5000 Then Break;
    End;
    EdMsg:=IntStr(C)+T3(' replaced',' remplacements',' ersetzt');
   End;
  E_SETM..E_SETM+3: EdMarks[Cmd-E_SETM+1]:=B^.Row;
  E_GOM..E_GOM+3: If EdMarks[Cmd-E_GOM+1]>0 Then EdGotoLine(EdMarks[Cmd-E_GOM+1]);
  E_TOP: Begin B^.Row:=1;B^.Col:=1;End;
  E_BOT: Begin B^.Row:=B^.N;B^.Col:=1;End;
  E_GOTO: Begin
    FormLbl[1]:=T3('Line','Ligne','Zeile');FormVal[1]:='';FormFW:=8;
    If FormBox(T3('Goto Line','Aller a la ligne','Gehe zu Zeile'),1,'') Then Begin
     Val(FormVal[1],N,C);If C=0 Then EdGotoLine(N);
    End;
   End;
  E_TAB: Begin
    FormLbl[1]:='Tabsize';FormVal[1]:=IntStr(EdTab);FormFW:=4;
    If FormBox('Tabsize',1,'') Then Begin Val(FormVal[1],N,C);If (C=0) And (N>0) And (N<=16) Then EdTab:=N;End;
   End;
  E_INS: EdInsert:=Not EdInsert;
  E_AUTO: EdAuto:=Not EdAuto;
  E_PRNF,E_PRINTB: Begin
    Assign(PrnF,PathNm[6]);
    {$I-}Rewrite(PrnF);{$I+}
    If IOResult<>0 Then MsgBox(T3('Printer not ready','Imprimante non pr'#136'te','Drucker nicht bereit'))
    Else Begin
     If Cmd=E_PRNF Then Begin For I:=1 To B^.N Do WriteLn(PrnF,B^.L[I]^);End
     Else For I:=1 To BlkN Do WriteLn(PrnF,BlkBuf[I]^);
     Close(PrnF);
    End;
   End;
  E_STAT: EdStatistics;
  E_ABOUT: DlgAbout('Personal Pascal Editor','Version '+VERSION_TEXT+'     March 31, 1989','Copyright 1987,1989 OSS and ICD');
 End;
End;

Procedure EdKey(K: Word);
Var B: ^TEdBuf; A: Char; Cmd: Integer;
Begin
 B:=@Eb[EbCur];
 A:=AltLetter(K);
 If A<>#0 Then Begin
  Cmd:=0;
  Case A Of
   'N': Cmd:=E_NEW; 'O': Cmd:=E_OPEN; 'S': Cmd:=E_SAVE; 'Q': Cmd:=E_QUIT;
   'M': Cmd:=E_MARK; 'E': Cmd:=E_ERASE; 'P': Cmd:=E_PASTE; 'H': Cmd:=E_HIDE;
   'L': Cmd:=E_LOADB; 'F': Cmd:=E_FINDW; 'U': Cmd:=E_FINDP; 'D': Cmd:=E_FINDN;
   'R': Cmd:=E_REPN; 'T': Cmd:=E_TOP; 'B': Cmd:=E_BOT; 'G': Cmd:=E_GOTO;
  End;
  If Cmd<>0 Then EdCommand(Cmd);
  Exit;
 End;
 EdMsg:='';
 Case K Of
  K_UP: Dec(B^.Row);
  K_DOWN: Inc(B^.Row);
  K_LEFT: If B^.Col>1 Then Dec(B^.Col) Else If B^.Row>1 Then Begin Dec(B^.Row);B^.Col:=Length(B^.L[B^.Row]^)+1;End;
  K_RIGHT: Inc(B^.Col);
  K_HOME: Begin B^.Row:=1;B^.Col:=1;End;
  K_ENDKEY: B^.Col:=Length(B^.L[B^.Row]^)+1;
  K_PGUP: Dec(B^.Row,ED_ROWS-1);
  K_PGDN: Inc(B^.Row,ED_ROWS-1);
  K_ENTER: EdEnter;
  K_BKSP: EdBackspace;
  K_DEL: EdDelete;
  K_INS: EdInsert:=Not EdInsert;
  K_TAB: EdTabKey;
  K_F1..K_F4: Begin EdCommand(E_GOM+K-K_F1);End;
  K_F10: EdCommand(E_QUIT);
  19: If B^.Col>1 Then Dec(B^.Col);
  4: Inc(B^.Col);
  5: Dec(B^.Row);
  24: Inc(B^.Row);
  18: Dec(B^.Row,ED_ROWS-1);
  3: Inc(B^.Row,ED_ROWS-1);
  12: EdCommand(E_NEW);
  25: Begin EdDelLineAt(EbCur,B^.Row);If B^.Row>B^.N Then B^.Row:=B^.N;End;
 Else
  If (K>=32) And (K<256) Then EdTypeChar(Chr(K));
 End;
 If B^.Row<1 Then B^.Row:=1;
 If B^.Row>B^.N Then B^.Row:=B^.N;
 If B^.Col<1 Then B^.Col:=1;
End;

Procedure EdMouse(E: TEvent);
Var B: ^TEdBuf; T,I,X: Integer;
Begin
 B:=@Eb[EbCur];
 If E.Y<MENU_H Then Begin
  T:=TitleHit(E.X,E.Y);
  If T>0 Then RunMenu(T,True);
  Exit;
 End;
 If (E.Y>=MENU_H) And (E.Y<ED_Y0) Then Begin
  { indicateurs de fichiers }
  For I:=1 To 3 Do Begin
   X:=SCR_W-SB*6+(I-1)*(SB+2);
   If InBox(E.X,E.Y,X,MENU_H+2,X+SB,ED_Y0-4) And Eb[I].Used Then EbCur:=I;
  End;
  If E.X<=SB+2 Then EdCommand(E_QUIT);
  Exit;
 End;
 If E.X>=SCR_W-SB Then Begin
  If E.Y<ED_Y0+SB Then Dec(B^.Row)
  Else If E.Y>SCR_H-2*SB Then Inc(B^.Row)
  Else If E.Y<ED_Y0+(SCR_H-ED_Y0) Div 2 Then Dec(B^.Row,ED_ROWS-1)
  Else Inc(B^.Row,ED_ROWS-1);
  B^.Top:=B^.Row-(ED_ROWS Div 2);If B^.Top<1 Then B^.Top:=1;
  Exit;
 End;
 If E.Y>=SCR_H-SB Then Begin
  If E.X<SB Then Dec(B^.Col,8) Else If E.X>SCR_W-2*SB Then Inc(B^.Col,8);
  Exit;
 End;
 { clic dans le texte }
 B^.Row:=B^.Top+(E.Y-ED_Y0) Div 16;
 If B^.Row>B^.N Then B^.Row:=B^.N;
 B^.Col:=B^.Left+(E.X-4) Div 8+1;
 If B^.Col<1 Then B^.Col:=1;
 If (E.B And 2)<>0 Then EdMarkBlock;
End;

{ Boucle de l'editeur : retourne 0 (quitter), 1 (compiler), 2 (lier) }
Function EditorMain(Const Name: String; GoLine: Integer; Const Msg: String): Integer;
Var E: TEvent; I: Integer;
Begin
 SetMenus(1);
 MenuOpen:=0;MenuSaved:=False;
 If Not EdBack Then Begin
  If Name<>'' Then EdOpenFile(Name) Else Begin
   Eb[1].Used:=True;EdClearBuf(1);Eb[1].Name:='';EbCur:=1;
  End;
 End Else If (Name<>'') And (Upper(Eb[EbCur].Name)<>Upper(Name)) Then EdOpenFile(Name);
 EdBack:=True;
 If GoLine>0 Then EdGotoLine(GoLine);
 EdMsg:=Msg;
 EdQuit:=False;EdAction:=0;
 EdDraw;
 While Not EdQuit Do Begin
  PollEvent(E);
  Case E.Kind Of
   1: Begin
       EdKey(E.Key);
       If Not EdQuit Then EdDraw;
      End;
   2: Begin EdMouse(E);If Not EdQuit Then EdDraw;End;
  End;
 End;
 If EdAction=0 Then Begin
  For I:=1 To 3 Do If Eb[I].Used Then Begin Eb[I].Used:=False;EdClearBuf(I);End;
  EdBack:=False;
 End;
 LastFile:=Eb[EbCur].Name;
 EditorMain:=EdAction;
 SetMenus(0);
End;

{ ====================================================================== }
{          GESTIONNAIRE : BUREAU, COMPILATION, LIAISON, EXECUTION        }
{ ====================================================================== }

Var
 BatchMode : Boolean;
 ListY     : Integer;
 ListOn    : Boolean;
 ErrFirstLine,ErrFirstCol : Integer;
 ErrFirstMsg : String;
 CmdWantQuit : Boolean;

Procedure DrawDesktop;
Begin
 If Headless Then Exit;
 HideMouse;
 SetViewPort(0,0,SCR_W-1,SCR_H-1,True);
 If AppMode=0 Then Begin
  PatBar(0,MENU_H,SCR_W-1,SCR_H-1,PatChecker);
  DrawMenuBar;
  DrawDropDown;
 End Else EdDraw;
 ShowMouse;
End;

Function ChangeExt(Const N,Ext: String): String;
Var I: Integer; S,E,Old: String; Low: Boolean;
Begin
 S:=N;E:=Ext;
 I:=Length(S);
 While (I>0) And (S[I]<>'.') And (S[I]<>'\') And (S[I]<>'/') And (S[I]<>':') Do Dec(I);
 If (I>0) And (S[I]='.') Then Begin
  Old:=Copy(S,I+1,10);
  Low:=(Old<>'') And (Old=LowerStr(Old));
  If Low Then E:=LowerStr(E);
  S:=Copy(S,1,I-1);
 End;
 ChangeExt:=S+'.'+E;
End;

Function PrgExt(T: Integer): String;
Begin
 Case T Of
  1: PrgExt:='TOS';
  2: PrgExt:='ACC';
 Else PrgExt:='PRG';
 End;
End;

Function SplitMsg(Const S: String): String;
Begin
 SplitMsg:=S;
End;

Function CompilerErrorHook(Line,Col,Num: Integer; Const Msg: String): Integer;
Var R: Integer; T: String;
Begin
 If CErrN=1 Then Begin ErrFirstLine:=Line;ErrFirstCol:=Col;ErrFirstMsg:=Msg;End;
 CompilerErrorHook:=1;
 If Headless Then Begin
  WriteLn(ShortName(SrcFileName),'(',Line,',',Col,') ',T3('Error ','Erreur ','Fehler '),Num,': ',Msg);
  Exit;
 End;
 If Opt.PauseErr Then Begin
  OutFlush(True);
  T:=T3('Error ','Erreur ','Fehler ')+IntStr(Num)+': '+Msg+'|'+T3('Line ','Ligne ','Zeile ')+IntStr(Line);
  R:=AlertBox(T,T3('Continue|Cancel|Edit','Continuer|Annuler|Editer','Weiter|Abbruch|Editor'));
  If R=2 Then CompilerErrorHook:=2
  Else If R=3 Then CompilerErrorHook:=3;
 End;
End;

Procedure CompilerListHook(Ln: Integer; Const S: String);
Var T: String;
Begin
 If Headless Then Begin WriteLn(Ln:5,'  ',S);Exit;End;
 If Not ListOn Then Begin
  HideMouse;
  Box(0,0,SCR_W-1,SCR_H-1,PAPER);
  ListY:=2;ListOn:=True;
 End;
 If ListY>SCR_H-12 Then Begin Box(0,0,SCR_W-1,SCR_H-1,PAPER);ListY:=2;End;
 T:=IntStr(Ln);
 While Length(T)<5 Do T:=' '+T;
 PText(4,ListY,Copy(T+'  '+S,1,78));
 Inc(ListY,10);
End;

Procedure WriteErrFile(Const Src: String);
Var F: Text; I: Integer;
Begin
 Assign(F,ChangeExt(Src,'ERR'));
 {$I-}Rewrite(F);{$I+}
 If IOResult<>0 Then Exit;
 For I:=1 To CErrN Do
  WriteLn(F,IntStr(CErrs[I].Num),' ',CErrs[I].Line,' ',CErrs[I].Col,' ',CErrs[I].Msg);
 Close(F);
End;

Procedure RefreshAll;
Begin
 DrawDesktop;
End;

Function DoLinkObj(Const Obj: String; ProgT: Integer; Quiet: Boolean): Boolean;
Var Prg,Lib,Msg: String; Ok: Boolean;
Begin
 Prg:=ChangeExt(Obj,PrgExt(ProgT));
 If ProgT=1 Then Lib:='PASLIB' Else Lib:='PASGEM';
 If Not Headless Then Begin
  ShowLinker(ShortName(Prg),Lib,True);
  Delay(500);
 End Else If Not Quiet Then WriteLn(T3('Linking ','Liaison de ','Linke ')+Obj+' -> '+Prg);
 Ok:=LinkObject(Obj,Prg,LinkExtra,Msg);
 If Not Headless Then Begin
  ShowLinker('','',False);
  If Not Ok Then MsgBox(Msg);
 End Else If Not Ok Then WriteLn(Msg);
 DoLinkObj:=Ok;
End;

{ Compile un fichier. Retourne : 0 ok, 1 erreurs, 2 aller a l'editeur }
Function DoCompileFile(Const Src: String): Integer;
Var Ok: Boolean; Obj: String; R: Integer;
Begin
 DoCompileFile:=1;
 ErrFirstLine:=0;
 Obj:=ChangeExt(Src,'O');
 If Not Headless Then ShowLoading('COMPILER') Else WriteLn(T3('Compiling ','Compilation de ','Compiliere ')+Src);
 ListOn:=False;
 ListHook:=True;
 Ok:=CompileFile(Src,Obj);
 If ListOn Then Begin
  PText(4,ListY+4,T3('-- press a key --','-- appuyez sur une touche --','-- Taste druecken --'));
  GetKeyWait;ListOn:=False;
 End;
 If CErrN>0 Then WriteErrFile(Src)
 Else If FileExists(ChangeExt(Src,'ERR')) Then Begin
  Assign(PrnF,ChangeExt(Src,'ERR'));{$I-}Erase(PrnF);{$I+}If IOResult<>0 Then ;
 End;
 If Not Headless Then RefreshAll;
 If Ok Then Begin
  DoCompileFile:=0;
  If Conf.ChainLink And (Not OutModule) Then Begin
   If Not DoLinkObj(Obj,OutProgType,False) Then DoCompileFile:=1;
  End;
 End Else Begin
  If Headless Then Begin
   WriteLn(CErrN,T3(' error(s)',' erreur(s)',' Fehler'));
  End Else If CGoEdit Then DoCompileFile:=2
  Else Begin
   R:=AlertBox(IntStr(CErrN)+T3(' error(s) in |',' erreur(s) dans |',' Fehler in |')+ShortName(Src)+'|'+
               T3('See the .ERR file','Voir le fichier .ERR','Siehe .ERR-Datei'),
               T3('OK|Edit','OK|Editer','OK|Editor'));
   If R=2 Then DoCompileFile:=2;
  End;
 End;
End;

Function PickFile(Const Title,Mask: String; Var Nm: String): Boolean;
Begin
 PickFile:=FileSelect(Title,Mask,Nm);
End;

Procedure RunEditorSession(Const Nm: String; GoLine: Integer; Const Msg: String);
Forward;

Procedure CompileFlow(Const Src: String);
Var R: Integer;
Begin
 LastFile:=Src;
 R:=DoCompileFile(Src);
 If R=2 Then Begin
  If ErrFirstLine>0 Then RunEditorSession(Src,ErrFirstLine,ErrFirstMsg)
  Else RunEditorSession(Src,0,'');
 End;
End;

Procedure RunInEmulator(Const Name: String);
Var Ok: Boolean; S: String; P: Integer;
Begin
 {$IFDEF FPC}
 If Headless Then Begin
  Ok:=RunCore(Name,RunTail);
  If Not Ok Then WriteLn(T3('Cannot load ','Chargement impossible : ','Kann nicht laden: ')+Name);
  If RunMsg<>'' Then WriteLn(RunMsg);
  Exit;
 End;
 HideMouse;Inc(MouseLock);
 SetViewPort(0,0,SCR_W-1,SCR_H-1,True);
 Box(0,0,SCR_W-1,SCR_H-1,INK);
 OutLive:=True;OutPending:=True;
 OBlitRect(0,0,OUT_W-1,OUT_H-1);
 Ok:=RunCore(Name,RunTail);
 If Not Ok Then Begin
  OutLive:=False;Dec(MouseLock);
  DrawDesktop;
  MsgBox(T3('Cannot load ','Chargement impossible : ','Kann nicht laden: ')+Name);
  Exit;
 End;
 OutFlush(True);
 If (RunMsg<>'') Then Begin
  Dec(MouseLock);
  S:=RunMsg;
  P:=Pos(' - ',S);
  If P>0 Then S:=Copy(S,1,P-1)+'|'+Copy(S,P+3,200);
  AlertBox('~'+S,'OK');
  Inc(MouseLock);
 End Else If (Not GemUsed) And (Not RunAborted) And (Not QuitReq) Then Begin
  PText(8,OFS_Y+OUT_H-12,T3('Press any key','Appuyez sur une touche','Taste druecken'));
  GetKeyWait;
 End;
 OutLive:=False;
 Dec(MouseLock);
 DrawDesktop;
 {$ELSE}
 MsgBox('Emulator requires Free Pascal');
 {$ENDIF}
End;

{ ------------------------- commandes du gestionnaire ------------------ }

Procedure DoFileOps(Cmd: Integer);
Var Nm,Dst: String; F,G: File; Buf: Array[0..4095] Of Byte; N,M: Word; R: Integer;
Begin
 Nm:='';
 Case Cmd Of
  C_COPY: Begin
    If Not PickFile(T3('Copy','Copier','Kopieren'),'*.*',Nm) Then Exit;
    FormLbl[1]:=T3('To','Vers','Nach');FormVal[1]:=Nm;FormFW:=40;
    If Not FormBox(T3('Copy','Copier','Kopieren'),1,'') Then Exit;
    Dst:=FormVal[1];
    Assign(F,ResolveFile(Nm));Assign(G,Dst);
    {$I-}Reset(F,1);Rewrite(G,1);{$I+}
    If IOResult<>0 Then Begin MsgBox(T3('Copy failed','Copie impossible','Kopieren fehlgeschlagen'));Exit;End;
    Repeat
     BlockRead(F,Buf,SizeOf(Buf),N);
     If N>0 Then BlockWrite(G,Buf,N,M);
    Until N=0;
    Close(F);Close(G);
   End;
  C_REN: Begin
    If Not PickFile(T3('Rename','Renommer','Umbenennen'),'*.*',Nm) Then Exit;
    FormLbl[1]:=T3('New name','Nouveau nom','Neuer Name');FormVal[1]:=Nm;FormFW:=40;
    If Not FormBox(T3('Rename','Renommer','Umbenennen'),1,'') Then Exit;
    Assign(F,ResolveFile(Nm));
    {$I-}Rename(F,FormVal[1]);{$I+}
    If IOResult<>0 Then MsgBox(T3('Rename failed','Renommage impossible','Umbenennen fehlgeschlagen'));
   End;
  C_ERASE: Begin
    If Not PickFile(T3('Erase','Effacer','Loeschen'),'*.*',Nm) Then Exit;
    R:=AlertBox(T3('Erase |','Effacer |','Loeschen |')+ShortName(Nm)+' ?',T3('Erase|Cancel','Effacer|Annuler','Loeschen|Abbruch'));
    If R=1 Then Begin
     Assign(F,ResolveFile(Nm));
     {$I-}Erase(F);{$I+}
     If IOResult<>0 Then MsgBox(T3('Erase failed','Effacement impossible','Loeschen fehlgeschlagen'));
    End;
   End;
  C_PRINT: Begin
    If Not PickFile(T3('Print','Imprimer','Drucken'),'*.*',Nm) Then Exit;
    Assign(F,ResolveFile(Nm));Assign(G,PathNm[6]);
    {$I-}Reset(F,1);Rewrite(G,1);{$I+}
    If IOResult<>0 Then Begin MsgBox(T3('Printer not ready','Imprimante non pr'#136'te','Drucker nicht bereit'));Exit;End;
    Repeat
     BlockRead(F,Buf,SizeOf(Buf),N);
     If N>0 Then BlockWrite(G,Buf,N,M);
    Until N=0;
    Close(F);Close(G);
   End;
 End;
End;

Procedure DlgSourceFiles;
Var R,I,K,Sel: Integer; Rows: Array[1..8] Of Integer; BAdd,BEra,BOk,BCan: Integer; Nm: String; Tmp: Array[1..16] Of String[80]; N: Integer;
Begin
 N:=SrcCnt;For I:=1 To N Do Tmp[I]:=SrcList[I];
 Sel:=0;
 Repeat
  DlgInit(380,250,1);
  DlgAdd(DK_TITLE,0,14,0,0,T3('Set Source Files','Fichiers sources','Quelldateien'));
  DlgAdd(DK_BOX,14,36,350,138,'');
  For I:=1 To 8 Do Begin
   If I<=N Then Rows[I]:=DlgAdd(DK_RADIO,16,38+(I-1)*16,346,15,Copy(Tmp[I],1,40))
   Else Rows[I]:=0;
   If I<=N Then Begin DI[Rows[I]].Grp:=1;DI[Rows[I]].On:=(I=Sel);End;
  End;
  BAdd:=DlgAdd(DK_BUTTON,14,188,76,24,T3('Add','Ajouter','Neu'));
  BEra:=DlgAdd(DK_BUTTON,100,188,76,24,T3('Erase','Effacer','Loeschen'));
  BOk:=DlgAdd(DK_BUTTON,200,188,76,24,'OK');
  BCan:=DlgAdd(DK_BUTTON,288,188,76,24,CancelS);
  DDef:=BOk;DCan:=BCan;
  R:=RunDlg;
  If R=BAdd Then Begin
   Nm:='';
   If (N<16) And PickFile(T3('Add source','Ajouter source','Quelle hinzufuegen'),'*.PAS',Nm) Then Begin Inc(N);Tmp[N]:=Nm;End;
  End Else If R=BEra Then Begin
   If (Sel>=1) And (Sel<=N) Then Begin
    For I:=Sel To N-1 Do Tmp[I]:=Tmp[I+1];
    Dec(N);Sel:=0;
   End Else If N>0 Then Dec(N);
  End Else If (R>0) And (R<>BOk) And (R<>BCan) Then Begin
   For I:=1 To 8 Do If Rows[I]=R Then Sel:=I;
  End;
 Until (R=BOk) Or (R=BCan) Or (R=0);
 If R=BOk Then Begin SrcCnt:=N;For I:=1 To N Do SrcList[I]:=Tmp[I];End;
End;

Procedure ManagerCmd(Cmd: Integer);
Var Nm: String; I,R: Integer;
Begin
 Case Cmd Of
  C_ABOUT: DlgAbout('Personal Pascal','Version '+VERSION_TEXT+'     March 31, 1989','Copyright 1987,1989 OSS and ICD');
  C_EDIT: Begin
    Nm:=LastFile;
    If PickFile(T3('Edit','Editer','Editieren'),'*.PAS',Nm) Then RunEditorSession(Nm,0,'');
   End;
  C_COMPILE: Begin
    Nm:=LastFile;
    If PickFile(T3('Compile','Compiler','Compilieren'),'*.PAS',Nm) Then CompileFlow(Nm);
   End;
  C_COMPALL: Begin
    If SrcCnt=0 Then MsgBox(T3('No source files selected|Use Set Source Files','Aucun fichier source|Utilisez Fichiers sources','Keine Quelldateien|Quelldateien waehlen'))
    Else For I:=1 To SrcCnt Do Begin
     R:=DoCompileFile(SrcList[I]);
     If R<>0 Then Break;
    End;
   End;
  C_LINK: Begin
    Nm:=ChangeExt(LastFile,'O');
    If (LastFile='') Or LinkAsk Or Not FileExists(Nm) Then Begin
     If Not PickFile(T3('Link','Lier','Linken'),'*.O',Nm) Then Exit;
    End;
    DoLinkObj(Nm,LinkType,False);
   End;
  C_RUN: Begin
    Nm:=ChangeExt(LastFile,PrgExt(Conf.ProgType));
    If PickFile(T3('Run Program','Ex'#130'cuter programme','Programm starten'),'*.PRG',Nm) Then Begin
     LastFile:=Nm;RunInEmulator(Nm);
    End;
   End;
  C_QUIT: QuitReq:=True;
  C_COPT: DlgCompilerOptions;
  C_LOPT: DlgLinkerOptions;
  C_SRC: DlgSourceFiles;
  C_LOC: DlgLocatePrograms;
  C_LOADO: Begin
    Nm:='PASCAL.INF';
    If PickFile(T3('Load Options','Charger options','Optionen laden'),'*.INF',Nm) Then
     If Not LoadOptions(Nm) Then MsgBox(T3('Cannot load options','Chargement impossible','Laden fehlgeschlagen'));
   End;
  C_SAVEO: Begin
    Nm:='PASCAL.INF';
    If PickFile(T3('Save Options','Sauver options','Optionen speichern'),'*.INF',Nm) Then SaveOptions(Nm);
   End;
  C_COPY,C_REN,C_ERASE,C_PRINT: DoFileOps(Cmd);
 End;
End;

Procedure DoMenu(M,I: Integer);
Var Cmd: Integer;
Begin
 Cmd:=MenuCmd[M,I];
 If Cmd=C_NONE Then Exit;
 If AppMode=1 Then EdCommand(Cmd) Else Begin
  ManagerCmd(Cmd);
  If Not QuitReq Then RefreshAll;
 End;
End;

Procedure RunEditorSession(Const Nm: String; GoLine: Integer; Const Msg: String);
Var Act: Integer; F: String; G: Integer; M: String;
Begin
 F:=Nm;G:=GoLine;M:=Msg;
 Repeat
  If Not Headless Then ShowLoading('EDITOR');
  Act:=EditorMain(F,G,M);
  F:='';G:=0;M:='';
  RefreshAll;
  If Act=1 Then Begin
   Act:=DoCompileFile(LastFile);
   If Act=2 Then Begin
    F:=LastFile;G:=ErrFirstLine;M:=ErrFirstMsg;Act:=1;
   End Else Act:=0;
   If (Act=1) Then Begin End;
  End Else If Act=2 Then Begin
   DoLinkObj(ChangeExt(LastFile,'O'),LinkType,False);
   Act:=0;
  End;
 Until (Act=0) And (F='');
 SetMenus(0);
 RefreshAll;
End;

Function ManagerKey(K: Word): Boolean;
Var A: Char;
Begin
 ManagerKey:=True;
 A:=AltLetter(K);
 If A=#0 Then Begin
  If (K<256) Then A:=UpCase(Chr(K));
  If (A<>'E') And (A<>'C') And (A<>'A') And (A<>'L') And (A<>'R') Then A:=#0;
 End;
 Case A Of
  'E': ManagerCmd(C_EDIT);
  'C': ManagerCmd(C_COMPILE);
  'A': ManagerCmd(C_COMPALL);
  'L': ManagerCmd(C_LINK);
  'R': ManagerCmd(C_RUN);
  'Q': QuitReq:=True;
 Else
  Case K Of
   K_F1: ManagerCmd(C_COPT);
   K_F2: ManagerCmd(C_LOPT);
   K_F3: ManagerCmd(C_SRC);
   K_F4: ManagerCmd(C_LOC);
   K_F5: ManagerCmd(C_LOADO);
   K_F6: ManagerCmd(C_SAVEO);
   K_SF1: ManagerCmd(C_COPY);
   K_SF2: ManagerCmd(C_REN);
   K_SF3: ManagerCmd(C_ERASE);
   K_SF4: ManagerCmd(C_PRINT);
   K_F10: QuitReq:=True;
  Else ManagerKey:=False;
  End;
 End;
 If ManagerKey And (Not QuitReq) Then RefreshAll;
End;

Procedure ManagerLoop;
Var E: TEvent; T: Integer;
Begin
 RefreshAll;
 Repeat
  PollEvent(E);
  Case E.Kind Of
   1: ManagerKey(E.Key);
   2: Begin
       T:=TitleHit(E.X,E.Y);
       If T>0 Then Begin RunMenu(T,True);If Not QuitReq Then RefreshAll;End;
      End;
  End;
 Until QuitReq;
End;

{ ------------------------- ligne de commande -------------------------- }

Const
 MAXTODO = 24;

Var
 TodoAct  : Array[1..MAXTODO] Of Char;
 TodoFile : Array[1..MAXTODO] Of String[80];
 TodoN    : Integer;

Procedure ShowHelp;
Begin
 WriteLn('Personal Pascal ',VERSION_TEXT,' - OSS Personal Pascal clone ',CLONE_VERSION,' (Atari ST)');
 WriteLn;
 Case Lang Of
  0: Begin
   WriteLn('Usage: OSSPAS [options] [file ...]');
   WriteLn;
   WriteLn('  /?, -h        this help');
   WriteLn('  /E file       edit the source file (default action for a file)');
   WriteLn('  /C file       compile the source file (.PAS -> .O, then .PRG if chained)');
   WriteLn('  /L file       link the object file (.O -> .PRG/.TOS/.ACC)');
   WriteLn('  /R file       run a program (.PRG/.TOS) in the built-in Atari ST emulator');
   WriteLn('  /B            batch mode: no desktop, console messages, exit code 0/1');
   WriteLn('  /GEM /TOS /ACC  program type    /D debug on   /ND debug off');
   WriteLn('  /LIST         print listing     /I:file load options (.INF)');
   WriteLn('  /M:mod1,mod2  additional link files (modules compiled with {$M+,E+})');
   WriteLn('  /P:args       command line passed to the program run with /R');
   WriteLn('  /LANG:EN|FR|GR  language (else environment variable LANGUAGE)');
   WriteLn;
   WriteLn('Example: OSSPAS /GEM /C CUBE.PAS /R CUBE.PRG');
  End;
  2: Begin
   WriteLn('Aufruf: OSSPAS [Optionen] [Datei ...]');
   WriteLn;
   WriteLn('  /?, -h        diese Hilfe');
   WriteLn('  /E Datei      Quelldatei editieren (Standardaktion)');
   WriteLn('  /C Datei      Quelldatei compilieren (.PAS -> .O, dann .PRG)');
   WriteLn('  /L Datei      Objektdatei linken (.O -> .PRG/.TOS/.ACC)');
   WriteLn('  /R Datei      Programm im integrierten Atari-ST-Emulator starten');
   WriteLn('  /B            Batch-Modus: kein Desktop, Konsolenmeldungen');
   WriteLn('  /GEM /TOS /ACC  Programmtyp     /D Debug ein   /ND Debug aus');
   WriteLn('  /LIST         Listing drucken   /I:Datei Optionen laden (.INF)');
   WriteLn('  /P:Args       Kommandozeile fuer das mit /R gestartete Programm');
   WriteLn('  /LANG:EN|FR|GR  Sprache (sonst Umgebungsvariable LANGUAGE)');
   WriteLn;
   WriteLn('Beispiel: OSSPAS /GEM /C CUBE.PAS /R CUBE.PRG');
  End;
 Else
  WriteLn('Usage : OSSPAS [options] [fichier ...]');
  WriteLn;
  WriteLn('  /?, -h        cette aide');
  WriteLn('  /E fichier    editer le fichier source (action par defaut)');
  WriteLn('  /C fichier    compiler le fichier source (.PAS -> .O, puis .PRG si chaine)');
  WriteLn('  /L fichier    lier le fichier objet (.O -> .PRG/.TOS/.ACC)');
  WriteLn('  /R fichier    executer un programme (.PRG/.TOS) dans l''emulateur Atari ST integre');
  WriteLn('  /B            mode batch : sans bureau, messages en console, code retour 0/1');
  WriteLn('  /GEM /TOS /ACC  type de programme   /D debug actif   /ND debug inactif');
  WriteLn('  /LIST         imprimer le listing   /I:fichier charger des options (.INF)');
  WriteLn('  /P:args       ligne de commande transmise au programme lance par /R');
  WriteLn('  /LANG:EN|FR|GR  langue (sinon variable d''environnement LANGUAGE)');
  WriteLn;
  WriteLn('Exemple : OSSPAS /GEM /C CUBE.PAS /R CUBE.PRG');
 End;
 WriteLn;
 WriteLn('LANGUAGE=EN / FR (default) / GR');
End;

Procedure ParseCmdLine;
Var I: Integer; S,U: String; Act: Char;
Begin
 TodoN:=0;Act:='E';
 I:=1;
 While I<=ParamCount Do Begin
  S:=ParamStr(I);U:=Upper(S);
  If (U='/?') Or (U='-?') Or (U='-H') Or (U='/H') Or (U='--HELP') Then Begin
   ShowHelp;
   Halt(0);
  End Else If (U='/E') Or (U='-E') Then Act:='E'
  Else If (U='/C') Or (U='-C') Then Act:='C'
  Else If (U='/L') Or (U='-L') Then Act:='L'
  Else If (U='/R') Or (U='-R') Then Act:='R'
  Else If (U='/A') Or (U='-A') Then Act:='A'
  Else If (U='/B') Or (U='-B') Then BatchMode:=True
  Else If (U='/GEM') Then Conf.ProgType:=0
  Else If (U='/TOS') Then Conf.ProgType:=1
  Else If (U='/ACC') Then Conf.ProgType:=2
  Else If (U='/D') Then Conf.FullDebug:=True
  Else If (U='/ND') Then Conf.FullDebug:=False
  Else If (U='/LIST') Then Conf.PrintList:=True
  Else If (Copy(U,1,3)='/M:') Then LinkExtra:=Copy(S,4,60)
  Else If (Copy(U,1,3)='/P:') Then Begin RunTail:=Copy(S,4,120);If RunTail<>'' Then RunTail:=' '+RunTail;End
  Else If (Copy(U,1,3)='/I:') Then Begin
   If Not LoadOptions(Copy(S,4,80)) Then WriteLn(T3('Cannot load ','Chargement impossible : ','Kann nicht laden: ')+Copy(S,4,80));
  End Else If (Copy(U,1,6)='/LANG:') Then Begin
   U:=Copy(U,7,2);
   If U='EN' Then Lang:=0 Else If (U='GR') Or (U='DE') Then Lang:=2 Else Lang:=1;
  End Else Begin
   If TodoN<MAXTODO Then Begin Inc(TodoN);TodoAct[TodoN]:=Act;TodoFile[TodoN]:=S;End;
  End;
  Inc(I);
 End;
End;

Procedure RunTodo;
Var I,R: Integer; Nm: String;
Begin
 For I:=1 To TodoN Do Begin
  Nm:=TodoFile[I];
  Case TodoAct[I] Of
   'E': If Not BatchMode Then Begin
         If Pos('.',ShortName(Nm))=0 Then Nm:=Nm+'.PAS';
         RunEditorSession(Nm,0,'');
        End;
   'C': Begin
         If Pos('.',ShortName(Nm))=0 Then Nm:=Nm+'.PAS';
         LastFile:=Nm;
         If BatchMode Then Begin
          R:=DoCompileFile(Nm);
          If R<>0 Then ExitCode:=1;
         End Else CompileFlow(Nm);
        End;
   'A': Begin
         If SrcCnt>0 Then ManagerCmd(C_COMPALL);
        End;
   'L': Begin
         If Pos('.',ShortName(Nm))=0 Then Nm:=Nm+'.O';
         If Not DoLinkObj(Nm,Conf.ProgType,False) Then ExitCode:=1;
        End;
   'R': Begin
         If Pos('.',ShortName(Nm))=0 Then Nm:=Nm+'.'+PrgExt(Conf.ProgType);
         LastFile:=Nm;
         RunInEmulator(Nm);
        End;
  End;
  If QuitReq Then Break;
 End;
End;

Procedure InitProgram;
Var I: Integer;
Begin
 InitLanguage;
 RunTail:='';
 InitConfig;
 Headless:=False;BatchMode:=False;QuitReq:=False;BreakReq:=False;
 KeyQ:='';LastFile:='';ListHook:=True;EdBack:=False;
 For I:=1 To 3 Do Begin Eb[I].N:=0;Eb[I].Used:=False;End;
 CErrN:=0;SrcN:=0;IncN:=0;Code:=Nil;
 FillChar(RLabNum,SizeOf(RLabNum),0);
 InitTypes;
 LoadOptions('PASCAL.INF');
End;

BEGIN
 InitProgram;
 ParseCmdLine;
 EdInitAll;
 If BatchMode Then Begin
  Headless:=True;
  {$IFDEF FPC}
  OutInitBuf;OrigBuf:=OutBuf;DispBuf:=OutBuf;
  {$ENDIF}
  RunTodo;
  Halt(ExitCode);
 End;
 InitializeGraphics;
 BuildFont;
 SetMenus(0);
 OutInitBuf;OrigBuf:=OutBuf;DispBuf:=OutBuf;
 If MouseDriverFound Then ShowMouse;
 DrawDesktop;
 If TodoN=0 Then Begin
  ManagerCmd(C_ABOUT);
 End Else RunTodo;
 If Not QuitReq Then ManagerLoop;
 HideMouse;
 CloseGraph;
END.
