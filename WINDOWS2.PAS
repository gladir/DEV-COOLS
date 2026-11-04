{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2
  @description: Clone de l'application WINDOWS2 (Microsoft Windows 2.03)

  Environnement graphique complet en un seul fichier : ecran d'accueil,
  bureau, MS-DOS Executive, fenetres superposees, menus deroulants, boites
  de dialogue et les applications de bureau (Calculator, Calendar, Cardfile,
  Clipboard, Clock, Control Panel, Notepad, Paint, PIF Editor, Reversi,
  Spooler, Terminal, Write, MS-DOS Prompt).

  Les programmes .COM/.EXE (DOS) et .EXE Windows 2.x (format NE) sont
  executes dans un emulateur 8086 integre (Free Pascal) avec les services
  DOS/BIOS/Windows emules.

  Langue : variable d'environnement LANGUAGE (EN = anglais, GR/DE =
  allemand, sinon francais).
  Syntaxe : WINDOWS2 [options] [fichier]   (WINDOWS2 /? pour l'aide)
}

Program WINDOWS2;

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
 VERSION_TEXT = '2.03';

 { Couleurs VGA }
 cBlk = 0;  cBlu = 1;  cGrn = 2;  cCyn = 3;  cRed = 4;  cMag = 5;
 cBrn = 6;  cLGr = 7;  cDGr = 8;  cLBl = 9;  cLGn = 10; cLCy = 11;
 cLRd = 12; cLMg = 13; cYel = 14; cWht = 15;

 { Geometrie des fenetres (style Windows 2) }
 TITLE_H  = 17;     { hauteur de la barre de titre }
 MENU_H   = 16;     { hauteur de la barre de menus }
 SB       = 16;     { largeur des barres de defilement }
 ICON_W   = 64;     { largeur d'une icone du bureau }
 ICON_H   = 52;

 MAXWIN   = 32;
 MAXMENU  = 8;
 MAXITEM  = 26;
 MAXCTL   = 56;

 { Codes de touches : caractere = ord ; etendue = 256 + code }
 K_ESC    = 27;
 K_ENTER  = 13;
 K_BKSP   = 8;
 K_TAB    = 9;
 K_SPACE  = 32;
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
 K_ALTF4  = 363;
 K_ALTBS  = 270;
 K_SHTAB  = 271;
 K_CTRLINS= 402;
 K_SHDEL  = 0;

 { Genres d'evenements }
 EV_NONE = 0;
 EV_KEY  = 1;
 EV_DOWN = 2;
 EV_UP   = 3;
 EV_MOVE = 4;
 EV_RDOWN= 5;

 { Applications integrees }
 A_EXEC  = 1;   A_CALC  = 2;   A_CALEN = 3;   A_CARD  = 4;
 A_CLIP  = 5;   A_CLOCK = 6;   A_CTRL  = 7;   A_NOTE  = 8;
 A_PAINT = 9;   A_PIF   = 10;  A_REV   = 11;  A_SPOOL = 12;
 A_TERM  = 13;  A_WRITE = 14;  A_DOSBOX= 15;  A_W16   = 16;
 A_ABOUT = 17;
 NAPPS   = 15;

 { Commandes communes du menu Control }
 CM_NONE = 0;  CM_RESTORE = 1; CM_MOVE = 2; CM_SIZE = 3; CM_MINIMIZE = 4;
 CM_MAXIMIZE = 5; CM_CLOSE = 6;

 { Boutons standard des boites de dialogue }
 ID_OK = 1; ID_CANCEL = 2; ID_YES = 3; ID_NO = 4;

 { Genres de controles de dialogue }
 C_TEXT = 1; C_EDIT = 2; C_BUTTON = 3; C_RADIO = 4; C_CHECK = 5;
 C_LIST = 6; C_SLIDER = 7; C_BOX = 8; C_CUSTOM = 9; C_ICON = 10; C_BAR = 11;

 DOSBUF = 1048576;

{ ====================================================================== }
{                                TYPES                                   }
{ ====================================================================== }

Type
 TComSet = Record Baud,Bits,Par,Stop,Hs: Integer; End;
 TEvent = Record
  Kind : Byte;
  Key  : Word;
  X,Y,B: LongInt;
  Dbl  : Boolean;
 End;

 TMenuItem = Record
  Txt  : String[48];      { 'EN~FR~DE' ; '-' = separateur ; & = souligne }
  Cmd  : Integer;
  Flag : Byte;            { 1 desactive, 2 coche }
  Key  : String[14];      { aide-memoire de raccourci }
 End;

 TMenuDef = Record
  Title : String[40];     { 'EN~FR~DE' }
  N     : Integer;
  It    : Array[1..MAXITEM] Of TMenuItem;
 End;

 PWindow = ^TWindow;
 TWindow = Record
  Id,App   : Integer;
  X,Y,W,H  : Integer;      { rectangle exterieur }
  UX,UY,UW,UH : Integer;   { rectangle normal (avant agrandissement) }
  State    : Byte;         { 0 normal, 1 icone, 2 agrandi }
  Title    : String[64];
  Sizable  : Boolean;
  Zoomable : Boolean;
  NMenu    : Integer;
  Menus    : Array[1..MAXMENU] Of TMenuDef;
  HasVS,HasHS : Boolean;
  VTot,VPage,VPos : LongInt;
  HTot,HPage,HPos : LongInt;
  Body     : Integer;      { couleur de fond du client }
  IconX,IconY : Integer;
  IconFixed : Boolean;     { icone deplacee par l'utilisateur }
  Data     : Pointer;      { donnees de l'application }
  Param    : LongInt;
 End;

 TSave = Record
  P : Pointer;
  Sz: LongInt;
  X,Y: Integer;
 End;

 PByteArr_ = ^TByteArr_;
 {$IFDEF FPC}
 TByteArr_ = Array[0..2147483646] Of Byte;
 {$ELSE}
 TByteArr_ = Array[0..65519] Of Byte;
 {$ENDIF}
 PStrList = ^TStrList;
 TStrList = Record
  N : Integer;
  S : Array[1..400] Of String[44];
 End;

 TCtl = Record
  Kind : Byte;
  Id   : Integer;
  X,Y,W,H : Integer;
  Txt  : String[160];
  Val  : Integer;          { etat / valeur / selection }
  Grp  : Integer;          { groupe radio, longueur max d'un champ }
  Mn,Mx: Integer;          { bornes d'un curseur }
  Top  : Integer;          { premier element visible d'une liste }
  Enabled : Boolean;
  Lst  : PStrList;
 End;

 PDlg = ^TDlg;
 TDlg = Record
  Title: String[40];
  W,H  : Integer;
  X,Y  : Integer;
  N    : Integer;
  C    : Array[1..MAXCTL] Of TCtl;
  Focus: Integer;
  Def  : Integer;
  Frame: Boolean;
  Sel1,Sel2 : Integer;     { selection d'un champ de saisie }
 End;

 TDlgHook = Procedure(Var D: TDlg; Ev: Integer; Ct: Integer);

{ ====================================================================== }
{                       VARIABLES GLOBALES                               }
{ ====================================================================== }

Var
 SCR_W,SCR_H : Integer;
 Lang        : Integer;     { 0 anglais, 1 francais, 2 allemand }
 QuitFlag    : Boolean;
 GfxOn       : Boolean;
 MX,MY,MB,LastB   : LongInt;
 PrevMX,PrevMY    : LongInt;
 LastClickCs      : LongInt;
 LastClickX,LastClickY: LongInt;
 LastActCs   : LongInt;
 BaseDir,HomeDir,RootDir : String;
 StartTicks  : LongInt;
 Dirty       : Boolean;
 DblCs       : LongInt;
 Beeping     : Boolean;
 BlinkHalf   : LongInt;
 BorderW     : Integer;     { largeur de bordure des fenetres }
 LeftHand    : Boolean;
 MouseSpeed  : Integer;
 { Couleurs de l'ecran (Control Panel > Screen Colors) }
 ColDesk,ColActive,ColInactive,ColWinBg,ColWinText,ColMenuBg,ColMenuText,
 ColBorder   : Integer;
 NoSplash    : Boolean;
 DosMode     : Boolean;     { emulateur DOS disponible }

 Wins        : Array[1..MAXWIN] Of PWindow;
 NWins       : Integer;
 NextId      : Integer;
 NewWinCount : Integer;
 Capture     : PWindow;

 { Presse-papiers (texte) }
 ClipText    : String;
 ClipBmp     : Pointer;
 ClipBmpW,ClipBmpH : Integer;
 ClipKind    : Integer;      { 0 vide, 1 texte, 2 bitmap }

 { Imprimante / Spooler (simules) }
 PrinterName : String;
 PrintPort   : String;
 SpoolN      : Integer;
 StepLeft    : LongInt;
 TrCS1       : Word;
 TrCSn       : LongInt;
 TrWin       : Boolean;
 TrK         : Integer;
 TrMF        : File;
 TrSnap      : Integer;
 TrWatch     : Word;
 TrGN        : Integer;
 TrPos       : LongInt;
 TrZero      : Boolean;
 TrW2        : Word;
 TrB5        : Byte;
 TrGRet      : Array[1..8] Of LongInt;
 TrR         : Array[0..13] Of Word;
 Ring        : Array[0..1023] Of LongInt;
 RingP       : Integer;
 TraceOn     : Boolean;
 TraceF      : Text;
 TrApi       : LongInt;
 DosV3       : Boolean;
 SelIcon     : Pointer;     { icone selectionnee }
 IniFile     : String;
 SpoolT0     : LongInt;
 NPrn        : Integer;
 SpoolNames  : Array[1..8] Of String[40];
 SpoolPaused : Boolean;
 SpoolPrio   : Integer;

 { Reglages Pays }
 DateFmt     : Integer;      { 0 M/J/A, 1 J/M/A, 2 A/M/J }
 DateSep     : String[1];
 Clock24     : Boolean;
 TimeSep     : String[1];
 CurSym      : String[4];
 DecSep      : String[1];
 ThouSep     : String[1];
 S1159,S2359 : String[8];
 ListSep     : String[1];
 CurFmt,NumDigits : Integer;
 LeadZero    : Boolean;
 MouseAcc    : Integer;       { 0 aucune, 1 moyenne, 2 haute }
 PrnFileName : String[40];
 PrnOrient,PrnPaper,DevTimeout,TxTimeout : Integer;
 ComSet      : Array[1..2] Of TComSet;
 SpoolPort   : Array[1..8] Of String[40];
 SpoolPrn    : Array[1..8] Of String[30];
 SpoolSrc    : Array[1..8] Of String[80];
 SpoolSrcNext: String[80];

Const
 PaperNames: Array[0..3] Of String[8]=('Letter','Legal','A4','B5');

{ ====================================================================== }
{                  LANGUE / UTILITAIRES GENERAUX                         }
{ ====================================================================== }

Const
 {$IFDEF UNIX}
 DirSep = '/';
 {$ELSE}
 DirSep = '\';
 {$ENDIF}

Function T3(Const En,Fr,De: String): String;
Begin
 Case Lang Of
  0: T3:=En;
  2: T3:=De;
 Else T3:=Fr;
 End;
End;

{ 'EN~FR~DE' : extrait la partie correspondant a la langue }
Function Part3(Const S: String; N: Integer): String;
Var I,K: Integer; R: String;
Begin
 R:='';K:=0;
 For I:=1 To Length(S) Do
  If S[I]='~' Then Inc(K) Else If K=N Then R:=R+S[I];
 If (R='') And (N<>0) Then Part3:=Part3(S,0) Else Part3:=R;
End;

Function TL(Const S: String): String;
Begin
 If Pos('~',S)=0 Then TL:=S Else TL:=Part3(S,Lang);
End;

{ retire le marqueur de souligne '&' }
Function NoAmp(Const S: String): String;
Var I: Integer; R: String;
Begin
 R:='';
 For I:=1 To Length(S) Do
  If S[I]<>'&' Then R:=R+S[I];
 NoAmp:=R;
End;

{ lettre soulignee (majuscule) ou #0 }
Function MnemoOf(Const S: String): Char;
Var P: Integer;
Begin
 P:=Pos('&',S);
 If (P>0) And (P<Length(S)) Then MnemoOf:=UpCase(S[P+1]) Else MnemoOf:=#0;
End;

Function IntStr(N: LongInt): String;
Var S: String;
Begin
 Str(N,S);
 IntStr:=S;
End;

Function Pad2(N: LongInt): String;
Var S: String;
Begin
 Str(N,S);
 If Length(S)<2 Then S:='0'+S;
 Pad2:=S;
End;

Function PadL(Const S: String; N: Integer): String;
Var R: String;
Begin
 R:=S;
 While Length(R)<N Do R:=' '+R;
 PadL:=R;
End;

Function PadR(Const S: String; N: Integer): String;
Var R: String;
Begin
 R:=S;
 While Length(R)<N Do R:=R+' ';
 PadR:=R;
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

Function Clamp(V,Lo,Hi: LongInt): LongInt;
Begin
 If V<Lo Then V:=Lo;
 If V>Hi Then V:=Hi;
 Clamp:=V;
End;

Function IfThenI(C: Boolean; A,B: Integer): Integer;
Begin
 If C Then IfThenI:=A Else IfThenI:=B;
End;

Function StrVal(Const S: String; Def: LongInt): LongInt;
Var V: LongInt; C: Integer; T: String;
Begin
 T:=S;
 While (Length(T)>0) And (T[1]=' ') Do Delete(T,1,1);
 While (Length(T)>0) And (T[Length(T)]=' ') Do Delete(T,Length(T),1);
 Val(T,V,C);
 If C<>0 Then StrVal:=Def Else StrVal:=V;
End;

Function HexStr(V: LongInt; N: Integer): String;
Const H: String[16] = '0123456789ABCDEF';
Var R: String; I: Integer;
Begin
 R:='';
 For I:=N-1 DownTo 0 Do R:=R+H[((V Shr (I*4)) And 15)+1];
 HexStr:=R;
End;

Function Trim(S: String): String;
Begin
 While (Length(S)>0) And (S[1]=' ') Do Delete(S,1,1);
 While (Length(S)>0) And (S[Length(S)]=' ') Do Delete(S,Length(S),1);
 Trim:=S;
End;

Function FileExists(Const Name: String): Boolean;
Var F: File; A: Word;
Begin
 Assign(F,Name);
 GetFAttr(F,A);
 FileExists:=(DosError=0) And ((A And Directory)=0);
End;

Function DirExists(Const Name: String): Boolean;
Var F: File; A: Word;
Begin
 If Name='' Then Begin DirExists:=False;Exit;End;
 Assign(F,Name);
 GetFAttr(F,A);
 DirExists:=(DosError=0) And ((A And Directory)<>0);
End;

Function DirOf(Const P: String): String;
Var I: Integer;
Begin
 I:=Length(P);
 While (I>0) And (P[I]<>'\') And (P[I]<>'/') Do Dec(I);
 If I=0 Then DirOf:='' Else DirOf:=Copy(P,1,I-1);
End;

Function BaseName(Const P: String): String;
Var I: Integer;
Begin
 I:=Length(P);
 While (I>0) And (P[I]<>'\') And (P[I]<>'/') And (P[I]<>':') Do Dec(I);
 BaseName:=Copy(P,I+1,255);
End;

Function ExtOf(Const P: String): String;
Var I: Integer; B: String;
Begin
 B:=BaseName(P);
 I:=Length(B);
 While (I>0) And (B[I]<>'.') Do Dec(I);
 If I=0 Then ExtOf:='' Else ExtOf:=Upper(Copy(B,I,10));
End;

Function JoinPath(Const A,B: String): String;
Begin
 If A='' Then JoinPath:=B
 Else If (A[Length(A)]='\') Or (A[Length(A)]='/') Or (A[Length(A)]=':') Then
  JoinPath:=A+B
 Else JoinPath:=A+DirSep+B;
End;

Function NowCs: LongInt;
Var H,M,S,C: Word;
Begin
 GetTime(H,M,S,C);
 NowCs:=((LongInt(H)*60+M)*60+S)*100+C;
End;

Function FreeMemory: LongInt;
Begin
 {$IFDEF FPC}
 FreeMemory:=GetFPCHeapStatus.CurrHeapFree;
 {$ELSE}
 FreeMemory:=MemAvail;
 {$ENDIF}
End;

Function InBox(X,Y,X1,Y1,X2,Y2: LongInt): Boolean;
Begin
 InBox:=(X>=X1) And (X<=X2) And (Y>=Y1) And (Y<=Y2);
End;

{ Dates ----------------------------------------------------------------- }

Function IsLeap(Y: Integer): Boolean;
Begin
 IsLeap:=((Y Mod 4=0) And (Y Mod 100<>0)) Or (Y Mod 400=0);
End;

Function DaysInMonth(Y,M: Integer): Integer;
Begin
 Case M Of
  1,3,5,7,8,10,12: DaysInMonth:=31;
  4,6,9,11: DaysInMonth:=30;
 Else If IsLeap(Y) Then DaysInMonth:=29 Else DaysInMonth:=28;
 End;
End;

{ jour de la semaine : 0 dimanche .. 6 samedi }
Function DayOfWeek(Y,M,D: Integer): Integer;
Var A,YY,MM: Integer;
Begin
 A:=(14-M) Div 12;
 YY:=Y-A;
 MM:=M+12*A-2;
 DayOfWeek:=(D+YY+YY Div 4-YY Div 100+YY Div 400+(31*MM) Div 12) Mod 7;
End;

Function MonthName(M: Integer): String;
Begin
 Case M Of
  1: MonthName:=T3('January','Janvier','Januar');
  2: MonthName:=T3('February','F'#130'vrier','Februar');
  3: MonthName:=T3('March','Mars','M'#132'rz');
  4: MonthName:=T3('April','Avril','April');
  5: MonthName:=T3('May','Mai','Mai');
  6: MonthName:=T3('June','Juin','Juni');
  7: MonthName:=T3('July','Juillet','Juli');
  8: MonthName:=T3('August','Ao'#150't','August');
  9: MonthName:=T3('September','Septembre','September');
  10: MonthName:=T3('October','Octobre','Oktober');
  11: MonthName:=T3('November','Novembre','November');
 Else MonthName:=T3('December','D'#130'cembre','Dezember');
 End;
End;

Function DayName(D: Integer): String;
Begin
 Case D Of
  0: DayName:=T3('Sunday','Dimanche','Sonntag');
  1: DayName:=T3('Monday','Lundi','Montag');
  2: DayName:=T3('Tuesday','Mardi','Dienstag');
  3: DayName:=T3('Wednesday','Mercredi','Mittwoch');
  4: DayName:=T3('Thursday','Jeudi','Donnerstag');
  5: DayName:=T3('Friday','Vendredi','Freitag');
 Else DayName:=T3('Saturday','Samedi','Samstag');
 End;
End;

Function DayShort(D: Integer): String;
Begin
 Case Lang Of
  0: Case D Of 0:DayShort:='Su';1:DayShort:='Mo';2:DayShort:='Tu';
      3:DayShort:='We';4:DayShort:='Th';5:DayShort:='Fr';Else DayShort:='Sa';End;
  2: Case D Of 0:DayShort:='So';1:DayShort:='Mo';2:DayShort:='Di';
      3:DayShort:='Mi';4:DayShort:='Do';5:DayShort:='Fr';Else DayShort:='Sa';End;
 Else Case D Of 0:DayShort:='Di';1:DayShort:='Lu';2:DayShort:='Ma';
      3:DayShort:='Me';4:DayShort:='Je';5:DayShort:='Ve';Else DayShort:='Sa';End;
 End;
End;

Function DateStr(Y,M,D: Integer): String;
Begin
 Case DateFmt Of
  0: DateStr:=Pad2(M)+DateSep+Pad2(D)+DateSep+IntStr(Y);
  1: DateStr:=Pad2(D)+DateSep+Pad2(M)+DateSep+IntStr(Y);
 Else DateStr:=IntStr(Y)+DateSep+Pad2(M)+DateSep+Pad2(D);
 End;
End;

Function TimeStr(H,M: Integer; Sec: Integer): String;
Var S: String; Suf: String;
Begin
 Suf:='';
 If Not Clock24 Then Begin
  If H>=12 Then Suf:=' '+S2359 Else Suf:=' '+S1159;
  H:=H Mod 12;
  If H=0 Then H:=12;
 End;
 If LeadZero Then S:=Pad2(H)+TimeSep+Pad2(M) Else S:=IntStr(H)+TimeSep+Pad2(M);
 If Sec>=0 Then S:=S+TimeSep+Pad2(Sec);
 TimeStr:=S+Suf;
End;

Procedure GetToday(Var Y,M,D: Integer);
Var YY,MM,DD,DW: Word;
Begin
 GetDate(YY,MM,DD,DW);
 Y:=YY;M:=MM;D:=DD;
End;

Procedure GetNow(Var H,M,S: Integer);
Var HH,MM,SS,CC: Word;
Begin
 GetTime(HH,MM,SS,CC);
 H:=HH;M:=MM;S:=SS;
End;

Function ImgSize(X1,Y1,X2,Y2: Integer): LongInt;
Begin
 ImgSize:=ImageSize(X1,Y1,X2,Y2);
End;

Function IfThen_(C: Boolean; A,B: LongInt): LongInt;
Begin
 If C Then IfThen_:=A Else IfThen_:=B;
End;

{ Filtre generique avec * et ? (insensible a la casse) }
Function WildMatch(Const Pat,Name: String): Boolean;
Var P,N: String;
 Function M(I,J: Integer): Boolean;
 Begin
  While I<=Length(P) Do Begin
   If P[I]='*' Then Begin
    While J<=Length(N)+1 Do Begin
     If M(I+1,J) Then Begin M:=True;Exit;End;
     Inc(J);
    End;
    M:=False;Exit;
   End Else If J>Length(N) Then Begin M:=False;Exit;End
   Else If (P[I]<>'?') And (P[I]<>N[J]) Then Begin M:=False;Exit;End;
   Inc(I);Inc(J);
  End;
  M:=J>Length(N);
 End;
Begin
 P:=Upper(Pat);N:=Upper(Name);
 If P='' Then Begin WildMatch:=True;Exit;End;
 { semantique DOS : un nom sans extension equivaut a NOM. }
 If Pos('.',N)=0 Then N:=N+'.';
 If Pos('.',P)=0 Then Begin If P[Length(P)]='*' Then P:=P+'.*' Else P:=P+'.';End;
 WildMatch:=M(1,1);
End;

Function IfThenS(C: Boolean; Const A,B: String): String;
Begin
 If C Then IfThenS:=A Else IfThenS:=B;
End;

{ ====================================================================== }
{                  GRAPHIQUE / SOURIS                                    }
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
  SCR_W:=GetMaxX+1;SCR_H:=GetMaxY+1;
  GfxOn:=True;
 End
  Else
 Begin
  WriteLn('Erreur graphique : ',GraphErrorMsg(ErrCode));
  Halt;
 End;
End;

{$IFNDEF FPC}
 Function MouseDriverFound: Boolean;
 Var
  Regs: Registers;
 Begin
  Regs.AX := 0;
  Intr($33, Regs);
  MouseDriverFound := Regs.AX = $FFFF;
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
 Function MouseDriverFound: Boolean;
 Begin
  MouseDriverFound := True;
 End;
{$ENDIF}

{ Curseur logiciel (fleche Windows 2 : blanc cerne de noir) }
Const
 CUR_W = 12;
 CUR_H = 17;
 CurShape : Array[0..CUR_H-1] Of String[CUR_W] = (
  '.           ',
  '..          ',
  '.#.         ',
  '.##.        ',
  '.###.       ',
  '.####.      ',
  '.#####.     ',
  '.######.    ',
  '.#######.   ',
  '.########.  ',
  '.#####.....',
  '.##.##.     ',
  '.#. .##.    ',
  '..  .##.    ',
  '.    .##.   ',
  '     .##.   ',
  '      ..    ');

Var
 VX,VY  : Integer;                 { origine du viewport courant }
 CX1,CY1,CX2,CY2 : Integer;        { rectangle de clip courant (absolu) }
 CurSaved,CurShown : Boolean;
 CurBuf : Pointer;
 CurSz  : LongInt;
 CurX,CurY : LongInt;

Procedure SetClip(X1,Y1,X2,Y2: Integer);
Begin
 If X1<0 Then X1:=0;
 If Y1<0 Then Y1:=0;
 If X2>SCR_W-1 Then X2:=SCR_W-1;
 If Y2>SCR_H-1 Then Y2:=SCR_H-1;
 CX1:=X1;CY1:=Y1;CX2:=X2;CY2:=Y2;
 VX:=X1;VY:=Y1;
 If (X2>=X1) And (Y2>=Y1) Then SetViewPort(X1,Y1,X2,Y2,True);
End;

Procedure ClipFull;
Begin
 SetClip(0,0,SCR_W-1,SCR_H-1);
End;

Procedure CursorErase;
Begin
 If CurSaved Then Begin
  ClipFull;
  PutImage(CurX,CurY,CurBuf^,NormalPut);
  CurSaved:=False;
 End;
End;

Var
 CurCur : Array[0..CUR_H-1] Of String[CUR_W];
 CurKind: Integer;
 CurHx,CurHy: Integer;

{ forme du pointeur : 0 fleche, 1 I (texte), 2 <-> , 3 vertical, 4 diagonale \, 5 diagonale /, 6 quatre fleches }
Procedure SetCurKind(K: Integer);
Var Px: Array[0..CUR_H-1,0..CUR_W-1] Of Byte; I,J,A,B,Cx,Cy: Integer;
 Procedure P(X,Y: Integer);
 Begin
  If (X>=0) And (X<CUR_W) And (Y>=0) And (Y<CUR_H) Then Px[Y,X]:=1;
 End;
Begin
 If K=CurKind Then Exit;
 CurKind:=K;
 If K=0 Then Begin
  For J:=0 To CUR_H-1 Do CurCur[J]:=CurShape[J];
  CurHx:=0;CurHy:=0;Exit;
 End;
 FillChar(Px,SizeOf(Px),0);
 Cx:=5;Cy:=8;CurHx:=5;CurHy:=8;
 Case K Of
  1: Begin For J:=2 To 14 Do P(5,J);For I:=3 To 7 Do Begin P(I,1);P(I,15);End;End;
  2: Begin For I:=1 To 10 Do P(I,Cy);
      For A:=1 To 3 Do Begin P(A,Cy-A);P(A,Cy+A);P(11-A,Cy-A);P(11-A,Cy+A);End;End;
  3: Begin For J:=1 To 15 Do P(Cx,J);
      For A:=1 To 3 Do Begin P(Cx-A,A+1);P(Cx+A,A+1);P(Cx-A,15-A);P(Cx+A,15-A);End;End;
  4: Begin For A:=1 To 9 Do P(A,A+2);
      For A:=0 To 3 Do Begin P(1+A,2);P(1,2+A);P(10-A,12);P(10,12-A);End;End;
  5: Begin For A:=1 To 9 Do P(A,14-A);
      For A:=0 To 3 Do Begin P(1+A,14);P(1,14-A);P(10-A,4);P(10,4+A);End;End;
  6: Begin For I:=1 To 10 Do P(I,Cy);For J:=1 To 15 Do P(Cx,J);
      For A:=1 To 2 Do Begin P(A,Cy-A);P(A,Cy+A);P(11-A,Cy-A);P(11-A,Cy+A);
       P(Cx-A,A+1);P(Cx+A,A+1);P(Cx-A,15-A);P(Cx+A,15-A);End;End;
 End;
 For J:=0 To CUR_H-1 Do Begin
  CurCur[J]:='';
  For I:=0 To CUR_W-1 Do Begin
   If Px[J,I]=1 Then CurCur[J]:=CurCur[J]+'#'
   Else Begin
    B:=0;
    For A:=-1 To 1 Do For Cx:=-1 To 1 Do
     If (I+Cx>=0) And (I+Cx<CUR_W) And (J+A>=0) And (J+A<CUR_H) Then If Px[J+A,I+Cx]=1 Then B:=1;
    If B=1 Then CurCur[J]:=CurCur[J]+'.' Else CurCur[J]:=CurCur[J]+' ';
   End;
  End;
 End;
End;

Procedure CursorDraw(X,Y: LongInt);
Var I,J: Integer; C: Char;
Begin
 X:=X-CurHx;Y:=Y-CurHy;
 If X>SCR_W-CUR_W Then X:=SCR_W-CUR_W;
 If Y>SCR_H-CUR_H Then Y:=SCR_H-CUR_H;
 If X<0 Then X:=0;
 If Y<0 Then Y:=0;
 CursorErase;
 ClipFull;
 GetImage(X,Y,X+CUR_W-1,Y+CUR_H-1,CurBuf^);
 CurX:=X;CurY:=Y;CurSaved:=True;
 For J:=0 To CUR_H-1 Do
  For I:=1 To CUR_W Do Begin
   C:=CurCur[J][I];
   If C='#' Then PutPixel(X+I-1,Y+J,cWht)
   Else If C='.' Then PutPixel(X+I-1,Y+J,cBlk);
  End;
End;

Procedure ShowMouse;
Begin
 CurShown:=True;
 CursorDraw(MX,MY);
End;

Procedure HideMouse;
Begin
 CursorErase;
 CurShown:=False;
End;

Procedure InitCursor;
Begin
 CurSz:=ImageSize(0,0,CUR_W-1,CUR_H-1);
 GetMem(CurBuf,CurSz);
 CurSaved:=False;CurShown:=False;CurKind:=-1;SetCurKind(0);
End;

{ ====================================================================== }
{              PRIMITIVES GRAPHIQUES AVEC ECRETAGE (CLIP)                }
{ ====================================================================== }

Function Vis(X1,Y1,X2,Y2: Integer): Boolean;
Begin
 Vis:=(X2>=CX1) And (X1<=CX2) And (Y2>=CY1) And (Y1<=CY2);
End;

Procedure GBar(X1,Y1,X2,Y2,C: Integer);
Begin
 If (X2<X1) Or (Y2<Y1) Then Exit;
 If Not Vis(X1,Y1,X2,Y2) Then Exit;
 SetFillStyle(SolidFill,C);
 Bar(X1-VX,Y1-VY,X2-VX,Y2-VY);
End;

Procedure GPix(X,Y,C: Integer);
Begin
 If (X<CX1) Or (X>CX2) Or (Y<CY1) Or (Y>CY2) Then Exit;
 PutPixel(X-VX,Y-VY,C);
End;

Function GGetPix(X,Y: Integer): Integer;
Begin
 If (X<CX1) Or (X>CX2) Or (Y<CY1) Or (Y>CY2) Then GGetPix:=0
 Else GGetPix:=GetPixel(X-VX,Y-VY);
End;

Procedure GHLine(X1,X2,Y,C: Integer);
Begin
 If X2<X1 Then Exit;
 If (Y<CY1) Or (Y>CY2) Or (X2<CX1) Or (X1>CX2) Then Exit;
 SetFillStyle(SolidFill,C);
 Bar(X1-VX,Y-VY,X2-VX,Y-VY);
End;

Procedure GVLine(X,Y1,Y2,C: Integer);
Begin
 If Y2<Y1 Then Exit;
 If (X<CX1) Or (X>CX2) Or (Y2<CY1) Or (Y1>CY2) Then Exit;
 SetFillStyle(SolidFill,C);
 Bar(X-VX,Y1-VY,X-VX,Y2-VY);
End;

Procedure GLine(X1,Y1,X2,Y2,C: Integer);
Begin
 SetColor(C);
 SetLineStyle(SolidLn,0,1);
 Line(X1-VX,Y1-VY,X2-VX,Y2-VY);
End;

Procedure GRect(X1,Y1,X2,Y2,C: Integer);
Begin
 If (X2<X1) Or (Y2<Y1) Then Exit;
 If Not Vis(X1,Y1,X2,Y2) Then Exit;
 GHLine(X1,X2,Y1,C);GHLine(X1,X2,Y2,C);
 GVLine(X1,Y1,Y2,C);GVLine(X2,Y1,Y2,C);
End;

Procedure GDotRect(X1,Y1,X2,Y2,C: Integer);
Var I: Integer;
Begin
 I:=X1;
 While I<=X2 Do Begin GPix(I,Y1,C);GPix(I,Y2,C);Inc(I,2);End;
 I:=Y1;
 While I<=Y2 Do Begin GPix(X1,I,C);GPix(X2,I,C);Inc(I,2);End;
End;

Procedure GEllipse(CX,CY,RX,RY,C: Integer);
Begin
 SetColor(C);
 SetLineStyle(SolidLn,0,1);
 Ellipse(CX-VX,CY-VY,0,360,RX,RY);
End;

Procedure GFillEllipse(CX,CY,RX,RY,C: Integer);
Begin
 SetFillStyle(SolidFill,C);
 SetColor(C);
 FillEllipse(CX-VX,CY-VY,RX,RY);
End;

{ Damier fin (2 couleurs) }
Procedure GDither(X1,Y1,X2,Y2,C1,C2: Integer);
Var X,Y: Integer;
Begin
 If (X2<X1) Or (Y2<Y1) Then Exit;
 If Not Vis(X1,Y1,X2,Y2) Then Exit;
 GBar(X1,Y1,X2,Y2,C2);
 For Y:=Y1 To Y2 Do Begin
  X:=X1+((Y1+Y+X1) And 1);
  While X<=X2 Do Begin
   GPix(X,Y,C1);
   Inc(X,2);
  End;
 End;
End;

{ Rectangle a coins arrondis (boutons Windows 2) }
Procedure GRound(X1,Y1,X2,Y2,C: Integer);
Begin
 GHLine(X1+2,X2-2,Y1,C);GHLine(X1+2,X2-2,Y2,C);
 GVLine(X1,Y1+2,Y2-2,C);GVLine(X2,Y1+2,Y2-2,C);
 GPix(X1+1,Y1+1,C);GPix(X2-1,Y1+1,C);GPix(X1+1,Y2-1,C);GPix(X2-1,Y2-1,C);
End;

Procedure GRoundFill(X1,Y1,X2,Y2,C,Bg: Integer);
Begin
 GBar(X1+1,Y1+1,X2-1,Y2-1,Bg);
 GRound(X1,Y1,X2,Y2,C);
End;

{ ---------------------------------------------------------------------- }
{ Texte (police BGI 8x8)                                                  }
{ ---------------------------------------------------------------------- }

Function TextW(Const S: String): Integer;
Var I,N: Integer;
Begin
 N:=0;
 For I:=1 To Length(S) Do If S[I]<>'&' Then Inc(N);
 TextW:=N*8;
End;

Procedure GText(X,Y: Integer; Const S: String; C: Integer);
Var T: String; I: Integer;
Begin
 If S='' Then Exit;
 If (Y>CY2) Or (Y+8<CY1) Or (X>CX2) Or (X+Length(S)*8<CX1) Then Exit;
 T:=S;
 For I:=1 To Length(T) Do If T[I]=#136 Then T[I]:='e';
 SetColor(C);
 SetTextStyle(DefaultFont,HorizDir,1);
 OutTextXY(X-VX,Y-VY,T);
End;

Procedure GTextB(X,Y: Integer; Const S: String; C: Integer);
Begin
 GText(X,Y,S,C);
 GText(X+1,Y,S,C);
End;

{ texte avec lettre soulignee (&) }
Procedure GTextU(X,Y: Integer; Const S: String; C: Integer);
Var P: Integer; A,B: String;
Begin
 P:=Pos('&',S);
 If (P=0) Or (P=Length(S)) Then Begin GText(X,Y,NoAmp(S),C);Exit;End;
 A:=Copy(S,1,P-1);
 GText(X,Y,A+S[P+1]+Copy(S,P+2,255),C);
 GHLine(X+Length(A)*8,X+Length(A)*8+7,Y+9,C);
 B:=A;
End;

Procedure GTextCtr(X1,X2,Y: Integer; Const S: String; C: Integer);
Begin
 GText((X1+X2+1-TextW(S)) Div 2,Y,NoAmp(S),C);
End;

Procedure GTextBig(X,Y: Integer; Const S: String; Size,C: Integer);
Begin
 If S='' Then Exit;
 SetColor(C);
 SetTextStyle(DefaultFont,HorizDir,Size);
 OutTextXY(X-VX,Y-VY,S);
 SetTextStyle(DefaultFont,HorizDir,1);
End;

Procedure GTextGrey(X,Y: Integer; Const S: String);
Var I,J: Integer;
Begin
 GText(X,Y,NoAmp(S),cDGr);
End;

{ ---------------------------------------------------------------------- }
{ Sauvegarde / restauration de l'arriere-plan                             }
{ ---------------------------------------------------------------------- }

Procedure SaveBack(Var S: TSave; X1,Y1,X2,Y2: Integer);
Begin
 If X1<0 Then X1:=0;
 If Y1<0 Then Y1:=0;
 If X2>SCR_W-1 Then X2:=SCR_W-1;
 If Y2>SCR_H-1 Then Y2:=SCR_H-1;
 S.X:=X1;S.Y:=Y1;
 ClipFull;
 S.Sz:=ImageSize(X1,Y1,X2,Y2);
 GetMem(S.P,S.Sz);
 GetImage(X1,Y1,X2,Y2,S.P^);
End;

Procedure RestoreBack(Var S: TSave);
Begin
 If S.P<>Nil Then Begin
  ClipFull;
  PutImage(S.X,S.Y,S.P^,NormalPut);
  FreeMem(S.P,S.Sz);
  S.P:=Nil;
 End;
End;

{ Sauvegarde d'ecran par bandes (l'image complete depasse 64 Ko) }
Const
 NBANDS = 8;
Type
 TScreenSave = Record
  B : Array[0..NBANDS-1] Of TSave;
 End;

Procedure SaveScreen(Var S: TScreenSave);
Var I,H: Integer;
Begin
 H:=SCR_H Div NBANDS;
 For I:=0 To NBANDS-1 Do Begin
  S.B[I].P:=Nil;
  SaveBack(S.B[I],0,I*H,SCR_W-1,I*H+H-1);
 End;
End;

Procedure PutScreen(Var S: TScreenSave);
Var I: Integer;
Begin
 ClipFull;
 For I:=0 To NBANDS-1 Do
  If S.B[I].P<>Nil Then PutImage(S.B[I].X,S.B[I].Y,S.B[I].P^,NormalPut);
End;

Procedure FreeScreen(Var S: TScreenSave);
Var I: Integer;
Begin
 For I:=0 To NBANDS-1 Do
  If S.B[I].P<>Nil Then Begin
   FreeMem(S.B[I].P,S.B[I].Sz);
   S.B[I].P:=Nil;
  End;
End;

{ ---------------------------------------------------------------------- }
{ Logo "Microsoft" (italique gras) de l'ecran d'accueil                    }
{ ---------------------------------------------------------------------- }

Procedure DrawLogoText(TX,TY: Integer; Const S: String; Size,C,Bg: Integer);
Var X,Y,W,H,Sh,YY: Integer; Buf: Pointer; Sz: LongInt;
Begin
 W:=Length(S)*8*Size+2;H:=8*Size+1;
 ClipFull;
 { zone de travail au bas de l'ecran, redessinee ensuite }
 SetColor(C);
 SetTextStyle(DefaultFont,HorizDir,Size);
 OutTextXY(2,SCR_H-H-2,S);
 OutTextXY(3,SCR_H-H-2,S);
 OutTextXY(4,SCR_H-H-2,S);
 For Y:=0 To H-1 Do Begin
  Sh:=((H-Y)*3) Div 10;
  For X:=0 To W+2 Do
   If GetPixel(2+X,SCR_H-H-2+Y)=C Then Begin
    YY:=TY+(Y*5) Div 4;
    PutPixel(TX+X+Sh,YY,C);
    If (Y Mod 4)=3 Then PutPixel(TX+X+Sh,YY+1,C);
   End;
 End;
 SetFillStyle(SolidFill,Bg);
 Bar(0,SCR_H-H-4,SCR_W-1,SCR_H-1);
 SetTextStyle(DefaultFont,HorizDir,1);
End;

{ ====================================================================== }
{                   EVENEMENTS (clavier / souris)                        }
{ ====================================================================== }

Procedure Beep;
Begin
 If Not Beeping Then Exit;
 Sound(880);Delay(35);NoSound;
End;

Procedure PollEvent(Var E: TEvent);
Var Ch: Char; K: Word; Nw: LongInt; Dx,Dy,Mt: LongInt;
Begin
 E.Kind:=EV_NONE;E.Key:=0;E.X:=MX;E.Y:=MY;E.B:=MB;E.Dbl:=False;
 If KeyPressed Then Begin
  Ch:=ReadKey;LastActCs:=NowCs;
  If Ch=#0 Then K:=256+Ord(ReadKey) Else K:=Ord(Ch);
  E.Kind:=EV_KEY;E.Key:=K;
  Exit;
 End;
 PrevMX:=MX;PrevMY:=MY;LastB:=MB;
 GetMouseState(MX,MY,MB);
 If MouseAcc>0 Then Begin
  Dx:=MX-PrevMX;Dy:=MY-PrevMY;
  If (Abs(Dx)<=40) And (Abs(Dy)<=40) And ((Abs(Dx)+Abs(Dy))>=IfThenI(MouseAcc=2,2,4)) Then Begin
   Mt:=1+MouseAcc;
   MX:=Clamp(PrevMX+Dx*Mt,0,SCR_W-1);MY:=Clamp(PrevMY+Dy*Mt,0,SCR_H-1);
   SetMousePos(MX,MY);
  End;
 End;
 If LeftHand Then MB:=(MB And 4) Or ((MB And 1) Shl 1) Or ((MB And 2) Shr 1);
 If (MX<>PrevMX) Or (MY<>PrevMY) Or (MB<>LastB) Then LastActCs:=NowCs;
 If MX<0 Then MX:=0;
 If MY<0 Then MY:=0;
 If MX>SCR_W-1 Then MX:=SCR_W-1;
 If MY>SCR_H-1 Then MY:=SCR_H-1;
 E.X:=MX;E.Y:=MY;E.B:=MB;
 If ((MB And 1)<>0) And ((LastB And 1)=0) Then Begin
  E.Kind:=EV_DOWN;
  Nw:=NowCs;
  If (Nw>=LastClickCs) And (Nw-LastClickCs<DblCs) And (Abs(MX-LastClickX)<6)
   And (Abs(MY-LastClickY)<6) Then Begin
   E.Dbl:=True;
   LastClickCs:=-1000;
  End Else Begin
   LastClickCs:=Nw;LastClickX:=MX;LastClickY:=MY;
  End;
 End
 Else If ((MB And 2)<>0) And ((LastB And 2)=0) Then E.Kind:=EV_RDOWN
 Else If ((MB And 3)=0) And ((LastB And 3)<>0) Then E.Kind:=EV_UP
 Else If (MX<>PrevMX) Or (MY<>PrevMY) Then E.Kind:=EV_MOVE;
 If (E.Kind<>EV_NONE) And CurShown And ((MX<>CurX) Or (MY<>CurY)) Then
  CursorDraw(MX,MY);
 If E.Kind=EV_NONE Then Delay(3);
End;

{ Lettre associee a une touche Alt+lettre (code etendu), ou #0 }
Function AltLetter(K: Word): Char;
Const R1: String[10]='QWERTYUIOP'; R2: String[9]='ASDFGHJKL';
      R3: String[7]='ZXCVBNM';
Var S: Integer;
Begin
 AltLetter:=#0;
 If K<256 Then Exit;
 S:=K-256;
 If (S>=16) And (S<=25) Then AltLetter:=R1[S-15]
 Else If (S>=30) And (S<=38) Then AltLetter:=R2[S-29]
 Else If (S>=44) And (S<=50) Then AltLetter:=R3[S-43];
End;

{ ====================================================================== }
{                  FENETRES : OBJET DE BASE ET GESTIONNAIRE              }
{ ====================================================================== }

Const
 HT_NONE=0; HT_TITLE=1; HT_SYS=2; HT_MIN=3; HT_MAX=4; HT_MENU=5; HT_CLIENT=6;
 HT_VSB=7; HT_HSB=8; HT_SIZE=9; HT_ICON=10;
 { identifiants de cadres pour Screen Colors }
 NSCOL = 10;

Var
 ScrCol : Array[0..NSCOL-1] Of Integer;
 SysDef : TMenuDef;
 IconStrip : Integer;

{ Appels vers les applications (definis plus loin) }
Procedure AppDraw(W: PWindow); Forward;
Procedure AppMouse(W: PWindow; Var E: TEvent); Forward;
Procedure AppKey(W: PWindow; K: Word); Forward;
Procedure AppMenu(W: PWindow; Cmd: Integer); Forward;
Procedure AppClose(W: PWindow); Forward;
Procedure AppTimer(W: PWindow); Forward;
Procedure AppPrepare(W: PWindow); Forward;
Procedure AppResize(W: PWindow); Forward;
Procedure AppDrawIcon(W: PWindow; X,Y: Integer); Forward;
Function  AppCanClose(W: PWindow): Boolean; Forward;
Procedure AppScroll(W: PWindow; Vert: Boolean; Part: Integer; Pos: LongInt); Forward;
Procedure AppSysItems(W: PWindow); Forward;
Procedure AppSysCmd(W: PWindow; Cmd: Integer); Forward;

Procedure ApplyScreenColors;
Begin
 ColDesk:=ScrCol[0];
 ColWinBg:=ScrCol[2];
 ColWinText:=ScrCol[3];
 ColMenuBg:=ScrCol[4];
 ColMenuText:=ScrCol[5];
 ColActive:=ScrCol[6];
 ColInactive:=ScrCol[7];
 ColBorder:=ScrCol[9];
End;

Procedure DefaultScreenColors;
Begin
 ScrCol[0]:=cLCy;ScrCol[1]:=cLCy;ScrCol[2]:=cWht;ScrCol[3]:=cBlk;
 ScrCol[4]:=cLCy;ScrCol[5]:=cBlk;ScrCol[6]:=cLBl;ScrCol[7]:=cLCy;
 ScrCol[8]:=cWht;ScrCol[9]:=cBlk;
 ApplyScreenColors;
End;

Function Bdr: Integer;
Begin
 Bdr:=BorderW;
End;

Function WinTop(W: PWindow): Integer;
Begin
 WinTop:=W^.Y+Bdr+TITLE_H;
End;

Function MenuBarY(W: PWindow): Integer;
Begin
 MenuBarY:=WinTop(W);
End;

{ zone client complete (sans les barres de defilement) }
Procedure WinClient(W: PWindow; Var X1,Y1,X2,Y2: Integer);
Begin
 X1:=W^.X+Bdr;
 Y1:=W^.Y+Bdr+TITLE_H;
 If W^.NMenu>0 Then Inc(Y1,MENU_H+1);
 X2:=W^.X+W^.W-Bdr-1;
 Y2:=W^.Y+W^.H-Bdr-1;
 If W^.HasVS Then Dec(X2,SB);
 If W^.HasHS Then Dec(Y2,SB);
End;

Procedure WinPrepare(W: PWindow);
Begin
 AppPrepare(W);
End;

{ ---------------------------------------------------------------------- }
{ Construction des menus                                                  }
{ ---------------------------------------------------------------------- }

Procedure WinAddMenu(W: PWindow; Const Title: String);
Begin
 If W^.NMenu>=MAXMENU Then Exit;
 Inc(W^.NMenu);
 W^.Menus[W^.NMenu].Title:=Title;
 W^.Menus[W^.NMenu].N:=0;
End;

Procedure WinAddItem(W: PWindow; Const Txt: String; Cmd: Integer; Const Key: String);
Begin
 If W^.NMenu=0 Then Exit;
 With W^.Menus[W^.NMenu] Do Begin
  If N>=MAXITEM Then Exit;
  Inc(N);
  It[N].Txt:=Txt;It[N].Cmd:=Cmd;It[N].Flag:=0;It[N].Key:=Key;
 End;
End;

Procedure WinAddSep(W: PWindow);
Begin
 WinAddItem(W,'-',0,'');
End;

{ Active/desactive, coche/decoche un element par son code de commande }
Procedure MenuFlag(W: PWindow; Cmd: Integer; Bit: Byte; On: Boolean);
Var M,I: Integer;
Begin
 For M:=1 To W^.NMenu Do
  For I:=1 To W^.Menus[M].N Do
   If W^.Menus[M].It[I].Cmd=Cmd Then Begin
    If On Then W^.Menus[M].It[I].Flag:=W^.Menus[M].It[I].Flag Or Bit
    Else W^.Menus[M].It[I].Flag:=W^.Menus[M].It[I].Flag And (255-Bit);
   End;
End;

Procedure MenuDisable(W: PWindow; Cmd: Integer; Off: Boolean);
Begin
 MenuFlag(W,Cmd,1,Off);
End;

Procedure MenuCheck(W: PWindow; Cmd: Integer; On: Boolean);
Begin
 MenuFlag(W,Cmd,2,On);
End;

{ ---------------------------------------------------------------------- }
{ Gestionnaire de fenetres                                                }
{ ---------------------------------------------------------------------- }

Function ActiveWin: PWindow;
Var I: Integer;
Begin
 ActiveWin:=Nil;
 For I:=NWins DownTo 1 Do
  If Wins[I]^.State<>1 Then Begin ActiveWin:=Wins[I];Exit;End;
End;

Function WinIndex(W: PWindow): Integer;
Var I: Integer;
Begin
 WinIndex:=0;
 For I:=1 To NWins Do If Wins[I]=W Then WinIndex:=I;
End;

Function FindApp(App: Integer): PWindow;
Var I: Integer;
Begin
 FindApp:=Nil;
 For I:=1 To NWins Do If Wins[I]^.App=App Then Begin FindApp:=Wins[I];Exit;End;
End;

Function CountApp(App: Integer): Integer;
Var I,N: Integer;
Begin
 N:=0;
 For I:=1 To NWins Do If Wins[I]^.App=App Then Inc(N);
 CountApp:=N;
End;

Procedure CalcIconStrip;
Var I,N: Integer;
Begin
 N:=0;
 For I:=1 To NWins Do If Wins[I]^.State=1 Then Inc(N);
 If N>0 Then IconStrip:=ICON_H+8 Else IconStrip:=0;
End;

Procedure LayoutIcons;
Var I,N: Integer;
Begin
 N:=0;
 For I:=1 To NWins Do
  If (Wins[I]^.State=1) And Not Wins[I]^.IconFixed Then Begin
   Wins[I]^.IconX:=4+(N Mod 9)*ICON_W;
   Wins[I]^.IconY:=SCR_H-ICON_H-4-(N Div 9)*(ICON_H+6);
   Inc(N);
  End;
 CalcIconStrip;
End;

Procedure MaxRect(Var X,Y,W,H: Integer);
Begin
 X:=0;Y:=0;W:=SCR_W;H:=SCR_H-IconStrip;
End;

Procedure BringToFront(W: PWindow);
Var I,K: Integer;
Begin
 K:=WinIndex(W);
 If (K=0) Or (K=NWins) Then Exit;
 For I:=K To NWins-1 Do Wins[I]:=Wins[I+1];
 Wins[NWins]:=W;
 Dirty:=True;
End;

Procedure SendToBack(W: PWindow);
Var I,K: Integer;
Begin
 K:=WinIndex(W);
 If (K=0) Or (K=1) Then Exit;
 For I:=K DownTo 2 Do Wins[I]:=Wins[I-1];
 Wins[1]:=W;
 Dirty:=True;
End;

{ Cree une fenetre. X<0 : positionnement en cascade }
Function NewWindow(App: Integer; Const Title: String; X,Y,W,H: Integer;
    Sizable: Boolean): PWindow;
Var P: PWindow;
Begin
 NewWindow:=Nil;
 If NWins>=MAXWIN Then Exit;
 New(P);
 FillChar(P^,SizeOf(TWindow),0);
 P^.Id:=NextId;Inc(NextId);
 P^.App:=App;P^.Title:=Title;
 If X<0 Then Begin
  X:=30+(NewWinCount Mod 8)*22;
  Y:=22+(NewWinCount Mod 8)*22;
  Inc(NewWinCount);
 End;
 If X+W>SCR_W Then X:=SCR_W-W;
 If Y+H>SCR_H-30 Then Y:=SCR_H-30-H;
 If X<0 Then X:=0;
 If Y<0 Then Y:=0;
 P^.X:=X;P^.Y:=Y;P^.W:=W;P^.H:=H;
 P^.UX:=X;P^.UY:=Y;P^.UW:=W;P^.UH:=H;
 P^.Sizable:=Sizable;P^.Zoomable:=Sizable;
 P^.State:=0;P^.Body:=-1;
 P^.Data:=Nil;
 Inc(NWins);
 Wins[NWins]:=P;
 Dirty:=True;
 NewWindow:=P;
End;

Procedure RemoveWindow(W: PWindow);
Var I,K: Integer;
Begin
 K:=WinIndex(W);
 If K=0 Then Exit;
 AppClose(W);
 If Capture=W Then Capture:=Nil;
 For I:=K To NWins-1 Do Wins[I]:=Wins[I+1];
 Dec(NWins);
 Dispose(W);
 LayoutIcons;
 Dirty:=True;
End;

Procedure RestoreWin(W: PWindow);
Begin
 If W^.State=1 Then Begin
  W^.State:=0;
  W^.X:=W^.UX;W^.Y:=W^.UY;W^.W:=W^.UW;W^.H:=W^.UH;
  LayoutIcons;
 End Else If W^.State=2 Then Begin
  W^.State:=0;
  W^.X:=W^.UX;W^.Y:=W^.UY;W^.W:=W^.UW;W^.H:=W^.UH;
 End;
 BringToFront(W);
 AppResize(W);
 Dirty:=True;
End;

Procedure MinimizeWin(W: PWindow);
Begin
 If W^.State=0 Then Begin
  W^.UX:=W^.X;W^.UY:=W^.Y;W^.UW:=W^.W;W^.UH:=W^.H;
 End;
 W^.State:=1;
 LayoutIcons;
 Dirty:=True;
End;

Procedure MaximizeWin(W: PWindow);
Var X,Y,WW,HH: Integer;
Begin
 If Not W^.Sizable Then Exit;
 If W^.State=0 Then Begin
  W^.UX:=W^.X;W^.UY:=W^.Y;W^.UW:=W^.W;W^.UH:=W^.H;
 End;
 If W^.State=1 Then Begin W^.State:=0;LayoutIcons;End;
 MaxRect(X,Y,WW,HH);
 If W^.App=A_DOSBOX Then Begin X:=-Bdr;WW:=SCR_W+2*Bdr;End;
 W^.X:=X;W^.Y:=Y;W^.W:=WW;W^.H:=HH;
 W^.State:=2;
 BringToFront(W);
 AppResize(W);
 Dirty:=True;
End;

{ ---------------------------------------------------------------------- }
{ Dessin du cadre d'une fenetre                                           }
{ ---------------------------------------------------------------------- }

Procedure BoxFrame(X1,Y1,X2,Y2,Fill: Integer);
Begin
 GBar(X1,Y1,X2,Y2,Fill);
 GRect(X1,Y1,X2,Y2,cBlk);
End;

Procedure DrawIconArrow(CX,CY: Integer; Up,Both: Boolean);
Var I: Integer;
Begin
 If Both Then Begin
  For I:=0 To 3 Do GHLine(CX-I,CX+I,CY-5+I,cBlk);
  For I:=0 To 3 Do GHLine(CX-I,CX+I,CY+5-I,cBlk);
  GVLine(CX,CY-2,CY+2,cBlk);
 End Else If Up Then Begin
  For I:=0 To 4 Do GHLine(CX-I,CX+I,CY-3+I,cBlk);
  GBar(CX-1,CY+2,CX+1,CY+4,cBlk);
 End Else Begin
  For I:=0 To 4 Do GHLine(CX-I,CX+I,CY+3-I,cBlk);
  GBar(CX-1,CY-4,CX+1,CY-2,cBlk);
 End;
End;

Procedure WinTitleGeom(W: PWindow; Var SX1,SX2,MnX1,MnX2,MxX1,MxX2: Integer);
Var X1,X2: Integer;
Begin
 X1:=W^.X+Bdr;X2:=W^.X+W^.W-Bdr-1;
 SX1:=X1;SX2:=X1+TITLE_H-1;
 MxX2:=X2;MxX1:=X2-TITLE_H+1;
 If W^.Sizable Then Begin MnX2:=MxX1-1;MnX1:=MnX2-TITLE_H+1;End
 Else Begin MnX2:=X2;MnX1:=MnX2-TITLE_H+1;MxX1:=1;MxX2:=0;End;
End;

Procedure DrawWinFrame(W: PWindow; Active: Boolean);
Var X1,Y1,X2,Y2,TY,SX1,SX2,MnX1,MnX2,MxX1,MxX2,I,TW,LX,BarC: Integer;
    T: String;
Begin
 X1:=W^.X;Y1:=W^.Y;X2:=W^.X+W^.W-1;Y2:=W^.Y+W^.H-1;
 { cadre exterieur }
 GBar(X1,Y1,X2,Y2,ScrCol[1]);
 GRect(X1,Y1,X2,Y2,ColBorder);
 If Bdr>=3 Then GRect(X1+Bdr-1,Y1+Bdr-1,X2-Bdr+1,Y2-Bdr+1,ColBorder);
 { bordure de taille : coins }
 If W^.Sizable And (Bdr>=3) Then Begin
  GVLine(X1+Bdr+TITLE_H-1,Y1,Y1+Bdr-1,ColBorder);
  GVLine(X2-Bdr-TITLE_H+1,Y1,Y1+Bdr-1,ColBorder);
  GVLine(X1+Bdr+TITLE_H-1,Y2-Bdr+1,Y2,ColBorder);
  GVLine(X2-Bdr-TITLE_H+1,Y2-Bdr+1,Y2,ColBorder);
  GHLine(X1,X1+Bdr-1,Y1+Bdr+TITLE_H-1,ColBorder);
  GHLine(X2-Bdr+1,X2,Y1+Bdr+TITLE_H-1,ColBorder);
  GHLine(X1,X1+Bdr-1,Y2-Bdr-TITLE_H+1,ColBorder);
  GHLine(X2-Bdr+1,X2,Y2-Bdr-TITLE_H+1,ColBorder);
 End;
 { barre de titre }
 TY:=Y1+Bdr;
 If Active Then BarC:=ColActive Else BarC:=ColInactive;
 GBar(X1+Bdr,TY,X2-Bdr,TY+TITLE_H-1,BarC);
 GHLine(X1+Bdr,X2-Bdr,TY+TITLE_H-1,ColBorder);
 WinTitleGeom(W,SX1,SX2,MnX1,MnX2,MxX1,MxX2);
 { boite du menu systeme }
 BoxFrame(SX1,TY,SX2,TY+TITLE_H-2,ColWinBg);
 GBar(SX1+3,TY+6,SX2-3,TY+9,cBlk);
 GBar(SX1+4,TY+7,SX2-4,TY+8,cWht);
 { boutons reduire / agrandir }
 BoxFrame(MnX1,TY,MnX2,TY+TITLE_H-2,ColWinBg);
 DrawIconArrow((MnX1+MnX2) Div 2,TY+TITLE_H Div 2-1,False,False);
 If W^.Sizable Then Begin
  BoxFrame(MxX1,TY,MxX2,TY+TITLE_H-2,ColWinBg);
  If W^.State=2 Then DrawIconArrow((MxX1+MxX2) Div 2,TY+TITLE_H Div 2-1,True,True)
  Else DrawIconArrow((MxX1+MxX2) Div 2,TY+TITLE_H Div 2-1,True,False);
 End;
 { titre centre (video inverse) }
 T:=W^.Title;
 LX:=MnX1-SX2-1;
 TW:=Length(T)*8+16;
 While (TW>LX-4) And (Length(T)>1) Do Begin Delete(T,Length(T),1);TW:=Length(T)*8+16;End;
 I:=SX2+1+(LX-TW) Div 2;
 GBar(I,TY,I+TW-1,TY+TITLE_H-2,cBlk);
 GText(I+8,TY+5,T,ScrCol[8]);
End;

Procedure DrawMenuBar(W: PWindow; Hi: Integer);
Var Y,X,I,TW: Integer; T: String;
Begin
 If W^.NMenu=0 Then Exit;
 Y:=WinTop(W);
 GBar(W^.X+Bdr,Y,W^.X+W^.W-Bdr-1,Y+MENU_H-1,ColMenuBg);
 GHLine(W^.X+Bdr,W^.X+W^.W-Bdr-1,Y+MENU_H,ColBorder);
 X:=W^.X+Bdr+8;
 For I:=1 To W^.NMenu Do Begin
  T:=TL(W^.Menus[I].Title);
  TW:=TextW(T);
  If I=Hi Then Begin
   GBar(X-6,Y+1,X+TW+5,Y+MENU_H-2,cBlk);
   GTextU(X,Y+4,T,cWht);
  End Else GTextU(X,Y+4,T,ColMenuText);
  Inc(X,TW+16);
 End;
End;

Function MenuTitleX(W: PWindow; M: Integer): Integer;
Var X,I: Integer;
Begin
 X:=W^.X+Bdr+8;
 For I:=1 To M-1 Do Inc(X,TextW(TL(W^.Menus[I].Title))+16);
 MenuTitleX:=X;
End;

Function MenuTitleW(W: PWindow; M: Integer): Integer;
Begin
 MenuTitleW:=TextW(TL(W^.Menus[M].Title))+12;
End;

{ ---------------------------------------------------------------------- }
{ Barres de defilement (style Windows 2 : damier + boite pouce)           }
{ ---------------------------------------------------------------------- }

Procedure ScrollThumb(A1,A2: Integer; Total,Page,Pos: LongInt; Var T1,
    T2: Integer);
Var Len,Tl,Rng: Integer;
Begin
 Len:=A2-A1+1;
 If (Total<=Page) Or (Total<=0) Then Begin T1:=A1;T2:=A1+Len-1;Exit;End;
 Tl:=(Len*Page) Div Total;
 If Tl<12 Then Tl:=12;
 If Tl>Len Then Tl:=Len;
 Rng:=Len-Tl;
 If Pos<0 Then Pos:=0;
 If Pos>Total-Page Then Pos:=Total-Page;
 T1:=A1+(Rng*Pos) Div (Total-Page);
 T2:=T1+Tl-1;
End;

Procedure GArrow(CX,CY,Dir,C: Integer);
Var I: Integer;
Begin
 Case Dir Of
  1: For I:=0 To 3 Do GHLine(CX-I,CX+I,CY-3+I,C);
  2: For I:=0 To 3 Do GHLine(CX-I,CX+I,CY+3-I,C);
  3: For I:=0 To 3 Do GVLine(CX-3+I,CY-I,CY+I,C);
  4: For I:=0 To 3 Do GVLine(CX+3-I,CY-I,CY+I,C);
 End;
End;

Procedure DrawScroll(Vert: Boolean; X1,Y1,X2,Y2: Integer; Total,Page,Pos: LongInt);
Var T1,T2: Integer;
Begin
 If Vert Then Begin
  GDither(X1,Y1+SB,X2,Y2-SB,cBlk,cWht);
  BoxFrame(X1,Y1,X2,Y1+SB-1,cWht);
  BoxFrame(X1,Y2-SB+1,X2,Y2,cWht);
  GArrow((X1+X2) Div 2,Y1+SB Div 2,1,cBlk);
  GArrow((X1+X2) Div 2,Y2-SB Div 2,2,cBlk);
  GVLine(X1,Y1,Y2,cBlk);
  If Total>Page Then Begin
   ScrollThumb(Y1+SB,Y2-SB,Total,Page,Pos,T1,T2);
   BoxFrame(X1,T1,X2,T2,cWht);
  End;
 End Else Begin
  GDither(X1+SB,Y1,X2-SB,Y2,cBlk,cWht);
  BoxFrame(X1,Y1,X1+SB-1,Y2,cWht);
  BoxFrame(X2-SB+1,Y1,X2,Y2,cWht);
  GArrow(X1+SB Div 2,(Y1+Y2) Div 2,3,cBlk);
  GArrow(X2-SB Div 2,(Y1+Y2) Div 2,4,cBlk);
  GHLine(X1,X2,Y1,cBlk);
  If Total>Page Then Begin
   ScrollThumb(X1+SB,X2-SB,Total,Page,Pos,T1,T2);
   BoxFrame(T1,Y1,T2,Y2,cWht);
  End;
 End;
End;

{ 1 fleche -, 2 fleche +, 3 page -, 4 page +, 5 pouce, 0 hors barre }
Function ScrollPart(Vert: Boolean; X1,Y1,X2,Y2: Integer; Total,Page,Pos: LongInt;
                    PX,PY: LongInt): Integer;
Var T1,T2,A,A1,A2: Integer;
Begin
 ScrollPart:=0;
 If Not InBox(PX,PY,X1,Y1,X2,Y2) Then Exit;
 If Vert Then Begin A:=PY;A1:=Y1;A2:=Y2;End Else Begin A:=PX;A1:=X1;A2:=X2;End;
 If A<A1+SB Then Begin ScrollPart:=1;Exit;End;
 If A>A2-SB Then Begin ScrollPart:=2;Exit;End;
 If Total<=Page Then Exit;
 ScrollThumb(A1+SB,A2-SB,Total,Page,Pos,T1,T2);
 If A<T1 Then ScrollPart:=3
 Else If A>T2 Then ScrollPart:=4
 Else ScrollPart:=5;
End;

Function ScrollDrag(Vert: Boolean; X1,Y1,X2,Y2: Integer; Total,Page: LongInt;
                    A,Grab: LongInt): LongInt;
Var A1,A2,Len,Tl,Rng: LongInt; R: LongInt;
Begin
 If Vert Then Begin A1:=Y1+SB;A2:=Y2-SB;End Else Begin A1:=X1+SB;A2:=X2-SB;End;
 Len:=A2-A1+1;
 Tl:=(Len*Page) Div Total;
 If Tl<12 Then Tl:=12;
 Rng:=Len-Tl;
 If Rng<=0 Then Begin ScrollDrag:=0;Exit;End;
 R:=((A-Grab-A1)*(Total-Page)) Div Rng;
 ScrollDrag:=Clamp(R,0,Total-Page);
End;

Procedure WinScrollRects(W: PWindow; Var VX1,VY1,VX2,VY2,HX1,HY1,HX2,HY2: Integer);
Var CX1_,CY1_,CX2_,CY2_: Integer;
Begin
 WinClient(W,CX1_,CY1_,CX2_,CY2_);
 VX1:=CX2_+1;VX2:=VX1+SB-1;VY1:=CY1_;VY2:=CY2_;
 HX1:=CX1_;HX2:=CX2_;HY1:=CY2_+1;HY2:=HY1+SB-1;
End;

{ ---------------------------------------------------------------------- }
{ Dessin d'une fenetre complete                                           }
{ ---------------------------------------------------------------------- }

Procedure DrawWindow(W: PWindow; Active: Boolean);
Var X1,Y1,X2,Y2,A1,B1,A2,B2,C1,D1,C2,D2: Integer;
Begin
 ClipFull;
 SetClip(W^.X,W^.Y,W^.X+W^.W-1,W^.Y+W^.H-1);
 DrawWinFrame(W,Active);
 DrawMenuBar(W,0);
 WinClient(W,X1,Y1,X2,Y2);
 { client }
 SetClip(X1,Y1,X2,Y2);
 If W^.Body<0 Then GBar(X1,Y1,X2,Y2,ColWinBg) Else GBar(X1,Y1,X2,Y2,W^.Body);
 AppDraw(W);
 SetClip(W^.X,W^.Y,W^.X+W^.W-1,W^.Y+W^.H-1);
 If W^.HasVS Or W^.HasHS Then Begin
  WinScrollRects(W,A1,B1,A2,B2,C1,D1,C2,D2);
  If W^.HasVS Then DrawScroll(True,A1,B1,A2,B2+0,W^.VTot,W^.VPage,W^.VPos);
  If W^.HasHS Then DrawScroll(False,C1,D1,C2,D2,W^.HTot,W^.HPage,W^.HPos);
  If W^.HasVS And W^.HasHS Then GBar(A1,D1,A2,D2,ScrCol[1]);
 End;
 ClipFull;
End;

Procedure DrawIconFloppy(X,Y: Integer);
Begin
 GBar(X,Y,X+31,Y+31,cBlk);
 GBar(X+7,Y,X+24,Y+11,cWht);
 GBar(X+13,Y+2,X+17,Y+9,cBlk);
 GBar(X+5,Y+16,X+26,Y+31,cWht);
 GBar(X+9,Y+19,X+22,Y+22,cLGr);
 GBar(X+9,Y+24,X+22,Y+27,cLGr);
End;

Procedure DrawWinIcon(W: PWindow);
Var T: String; X,Y: Integer;
Begin
 X:=W^.IconX;Y:=W^.IconY;
 SetClip(X-4,Y-2,X+ICON_W-4,Y+ICON_H+2);
 GBar(X-4,Y-2,X+ICON_W-4,Y+ICON_H,ColDesk);
 AppDrawIcon(W,X+(ICON_W-32) Div 2-4,Y);
 T:=W^.Title;
 If Length(T)>8 Then T:=Copy(T,1,8);
 If SelIcon=W Then Begin
  { icone selectionnee : titre complet sur fond blanc, contour }
  T:=W^.Title;
  If Length(T)>(ICON_W Div 8) Then T:=Copy(T,1,ICON_W Div 8);
  GBar(X-4,Y+34,X+ICON_W-4,Y+ICON_H,cBlk);
  GText(X+(ICON_W-Length(T)*8) Div 2-4,Y+36,T,cWht);
  GRect(X-4,Y-2,X+ICON_W-4,Y+ICON_H,cWht);
 End Else
  GText(X+(ICON_W-Length(T)*8) Div 2-4,Y+36,T,cBlk);
 ClipFull;
End;

Procedure DrawDesktop;
Var I: Integer; A: PWindow;
Begin
 ClipFull;
 GBar(0,0,SCR_W-1,SCR_H-1,ColDesk);
 A:=ActiveWin;
 For I:=1 To NWins Do
  If Wins[I]^.State<>1 Then DrawWindow(Wins[I],Wins[I]=A);
 For I:=1 To NWins Do
  If Wins[I]^.State=1 Then DrawWinIcon(Wins[I]);
End;

Procedure RedrawAll;
Begin
 HideMouse;
 DrawDesktop;
 ShowMouse;
 Dirty:=False;
End;

{ ---------------------------------------------------------------------- }
{ Detection de la zone sous la souris                                     }
{ ---------------------------------------------------------------------- }

Function HitWindow(W: PWindow; PX,PY: Integer; Var Part: Integer): Boolean;
Var SX1,SX2,MnX1,MnX2,MxX1,MxX2,TY,CX1_,CY1_,CX2_,CY2_,
    A1,B1,A2,B2,C1,D1,C2,D2: Integer;
Begin
 Part:=HT_NONE;
 HitWindow:=False;
 If W^.State=1 Then Begin
  If InBox(PX,PY,W^.IconX-4,W^.IconY-2,W^.IconX+ICON_W-4,W^.IconY+ICON_H) Then Begin
   Part:=HT_ICON;HitWindow:=True;
  End;
  Exit;
 End;
 If Not InBox(PX,PY,W^.X,W^.Y,W^.X+W^.W-1,W^.Y+W^.H-1) Then Exit;
 HitWindow:=True;
 TY:=W^.Y+Bdr;
 WinTitleGeom(W,SX1,SX2,MnX1,MnX2,MxX1,MxX2);
 If (PY<TY) Or (PY>=W^.Y+W^.H-Bdr) Or (PX<W^.X+Bdr) Or (PX>=W^.X+W^.W-Bdr) Then Begin
  If W^.Sizable And (W^.State<>2) Then Part:=HT_SIZE Else Part:=HT_TITLE;
  Exit;
 End;
 If PY<TY+TITLE_H Then Begin
  If InBox(PX,PY,SX1,TY,SX2,TY+TITLE_H-1) Then Part:=HT_SYS
  Else If InBox(PX,PY,MnX1,TY,MnX2,TY+TITLE_H-1) Then Part:=HT_MIN
  Else If W^.Sizable And InBox(PX,PY,MxX1,TY,MxX2,TY+TITLE_H-1) Then Part:=HT_MAX
  Else Part:=HT_TITLE;
  Exit;
 End;
 If (W^.NMenu>0) And (PY<=WinTop(W)+MENU_H) Then Begin Part:=HT_MENU;Exit;End;
 WinClient(W,CX1_,CY1_,CX2_,CY2_);
 If W^.HasVS Or W^.HasHS Then Begin
  WinScrollRects(W,A1,B1,A2,B2,C1,D1,C2,D2);
  If W^.HasVS And InBox(PX,PY,A1,B1,A2,B2) Then Begin Part:=HT_VSB;Exit;End;
  If W^.HasHS And InBox(PX,PY,C1,D1,C2,D2) Then Begin Part:=HT_HSB;Exit;End;
 End;
 Part:=HT_CLIENT;
End;

Function WinAt(PX,PY: Integer; Var Part: Integer): PWindow;
Var I: Integer;
Begin
 WinAt:=Nil;Part:=HT_NONE;
 { les fenetres normales sont devant les icones }
 For I:=NWins DownTo 1 Do
  If Wins[I]^.State<>1 Then
   If HitWindow(Wins[I],PX,PY,Part) Then Begin WinAt:=Wins[I];Exit;End;
 For I:=NWins DownTo 1 Do
  If Wins[I]^.State=1 Then
   If HitWindow(Wins[I],PX,PY,Part) Then Begin WinAt:=Wins[I];Exit;End;
End;

{ ====================================================================== }
{                        MENUS DEROULANTS                                }
{ ====================================================================== }

Function ItemH(Const It: TMenuItem): Integer;
Begin
 If It.Txt='-' Then ItemH:=6 Else ItemH:=14;
End;

Procedure DropGeom(Const MD: TMenuDef; AX,AY: Integer; Var X1,Y1,X2,Y2: Integer);
Var I,L,K,WL,WK,H: Integer;
Begin
 WL:=0;WK:=0;H:=4;
 For I:=1 To MD.N Do Begin
  L:=TextW(TL(MD.It[I].Txt));
  If L>WL Then WL:=L;
  K:=TextW(MD.It[I].Key);
  If K>WK Then WK:=K;
  H:=H+ItemH(MD.It[I]);
 End;
 X1:=AX;Y1:=AY;
 X2:=X1+22+WL+8;
 If WK>0 Then X2:=X2+WK+16;
 Y2:=Y1+H-1;
 If X2>SCR_W-5 Then Begin X1:=X1-(X2-(SCR_W-5));X2:=SCR_W-5;End;
 If Y2>SCR_H-5 Then Begin Y1:=Y1-(Y2-(SCR_H-5));Y2:=SCR_H-5;End;
End;

Function DropItemY(Const MD: TMenuDef; Y1,I: Integer): Integer;
Var K,Y: Integer;
Begin
 Y:=Y1+2;
 For K:=1 To I-1 Do Y:=Y+ItemH(MD.It[K]);
 DropItemY:=Y;
End;

Function DropHit(Const MD: TMenuDef; X1,Y1,X2,Y2: Integer; PX,PY: LongInt): Integer;
Var I,Y: Integer;
Begin
 DropHit:=0;
 If Not InBox(PX,PY,X1,Y1,X2,Y2) Then Exit;
 For I:=1 To MD.N Do Begin
  Y:=DropItemY(MD,Y1,I);
  If (PY>=Y) And (PY<Y+ItemH(MD.It[I])) Then DropHit:=I;
 End;
End;

Procedure DrawCheck(X,Y,C: Integer);
Begin
 GLine(X,Y+4,X+2,Y+6,C);
 GLine(X+2,Y+6,X+7,Y,C);
 GLine(X,Y+5,X+2,Y+7,C);
 GLine(X+2,Y+7,X+7,Y+1,C);
End;

Procedure DrawDrop(Const MD: TMenuDef; X1,Y1,X2,Y2,Hi: Integer);
Var I,Y: Integer; S: String; En,Sel: Boolean;
Begin
 ClipFull;
 GBar(X1,Y1,X2,Y2,cWht);
 GRect(X1,Y1,X2,Y2,cBlk);
 For I:=1 To MD.N Do Begin
  Y:=DropItemY(MD,Y1,I);
  S:=TL(MD.It[I].Txt);
  If MD.It[I].Txt='-' Then Begin
   GHLine(X1+1,X2-1,Y+2,cBlk);
  End Else Begin
   En:=(MD.It[I].Flag And 1)=0;
   Sel:=(I=Hi) And En;
   If Sel Then GBar(X1+1,Y,X2-1,Y+13,cBlk);
   If (MD.It[I].Flag And 2)<>0 Then Begin
    If Sel Then DrawCheck(X1+6,Y+3,cWht) Else DrawCheck(X1+6,Y+3,cBlk);
   End;
   If Not En Then GTextU(X1+20,Y+3,S,cDGr)
   Else If Sel Then GTextU(X1+20,Y+3,S,cWht)
   Else GTextU(X1+20,Y+3,S,cBlk);
   If MD.It[I].Key<>'' Then Begin
    If Not En Then GText(X2-8-TextW(MD.It[I].Key),Y+3,MD.It[I].Key,cDGr)
    Else If Sel Then GText(X2-8-TextW(MD.It[I].Key),Y+3,MD.It[I].Key,cWht)
    Else GText(X2-8-TextW(MD.It[I].Key),Y+3,MD.It[I].Key,cBlk);
   End;
  End;
 End;
End;

Function NextItem(Const MD: TMenuDef; From,Dir: Integer): Integer;
Var I,N,K: Integer;
Begin
 N:=MD.N;I:=From;
 For K:=1 To N Do Begin
  I:=I+Dir;
  If I<1 Then I:=N;
  If I>N Then I:=1;
  If (MD.It[I].Txt<>'-') And ((MD.It[I].Flag And 1)=0) Then Begin NextItem:=I;Exit;End;
 End;
 NextItem:=From;
End;

Procedure SetSysItem(Idx: Integer; Const Txt: String; Cmd: Integer; Dis: Boolean;
    Const Key: String);
Begin
 SysDef.It[Idx].Txt:=Txt;SysDef.It[Idx].Cmd:=Cmd;SysDef.It[Idx].Key:=Key;
 If Dis Then SysDef.It[Idx].Flag:=1 Else SysDef.It[Idx].Flag:=0;
End;

Procedure BuildSysMenu(W: PWindow);
Begin
 SysDef.N:=0;SysDef.Title:='';
 Inc(SysDef.N);SetSysItem(SysDef.N,'&Restore~&Restaurer~&Wiederherstellen',CM_RESTORE,
  W^.State=0,'Alt+F5');
 Inc(SysDef.N);SetSysItem(SysDef.N,'&Move~&D'#130'placer~&Verschieben',CM_MOVE,
  W^.State=2,'Alt+F7');
 Inc(SysDef.N);SetSysItem(SysDef.N,'&Size~&Taille~&Gr'#148#225'e',CM_SIZE,
  (Not W^.Sizable) Or (W^.State<>0),'Alt+F8');
 Inc(SysDef.N);SetSysItem(SysDef.N,'Mi&nimize~R'#130'&duire~&Minimieren',CM_MINIMIZE,
  W^.State=1,'Alt+F9');
 Inc(SysDef.N);SetSysItem(SysDef.N,'Ma&ximize~&Agrandir~Ma&ximieren',CM_MAXIMIZE,
  (Not W^.Sizable) Or (W^.State=2),'Alt+F10');
 Inc(SysDef.N);SetSysItem(SysDef.N,'-',0,False,'');
 Inc(SysDef.N);SetSysItem(SysDef.N,'&Close~&Fermer~S&chlie'#225'en',CM_CLOSE,False,
  'Alt+F4');
 AppSysItems(W);
End;

{ Boucle de menu : Sys = menu systeme (boite de gauche de la barre de titre) }
Var
 MenuKbd: Boolean;          { menu ouvert au clavier : pre-selectionne la premiere commande }

Const
 CM_OPENSYS = 30000;        { demande d'ouverture du menu Systeme depuis la barre (ESPACE) }

{ mnemonique : 0 aucun, 1 unique (choisi), 2 doublon (surbrillance deplacee) }
Function PickMnemo(Const MD: TMenuDef; Ch: Char; Var Hi: Integer): Integer;
Var K,C,F,Nx: Integer;
Begin
 C:=0;F:=0;Nx:=0;
 For K:=1 To MD.N Do
  If (MD.It[K].Txt<>'-') And ((MD.It[K].Flag And 1)=0) And (MnemoOf(TL(MD.It[K].Txt))=Ch) Then Begin
   Inc(C);If F=0 Then F:=K;
   If (K>Hi) And (Nx=0) Then Nx:=K;
  End;
 If C=0 Then Begin PickMnemo:=0;Exit;End;
 If C=1 Then Begin Hi:=F;PickMnemo:=1;Exit;End;
 If Nx=0 Then Nx:=F;
 Hi:=Nx;PickMnemo:=2;
End;

Function RunMenus(W: PWindow; StartM: Integer; Sys: Boolean): Integer;
Var M,Hi,H,T,DX1,DY1,DX2,DY2,I: Integer; E: TEvent; Done,Pick,Entered: Boolean;
    Sv: TSave; Res: Integer; BarY,TX: Integer; PX,PY: LongInt; Ch: Char; SwSys: Boolean; Pm: Integer;

 Procedure Place;
 Begin
  If Sys Then Begin
   DX1:=W^.X+Bdr;DY1:=W^.Y+Bdr+TITLE_H;
   DropGeom(SysDef,DX1,DY1,DX1,DY1,DX2,DY2);
  End Else Begin
   TX:=MenuTitleX(W,M)-6;
   DropGeom(W^.Menus[M],TX,BarY+MENU_H,DX1,DY1,DX2,DY2);
  End;
 End;

 Procedure Show(NewHi: Integer);
 Begin
  HideMouse;
  If Sv.P<>Nil Then RestoreBack(Sv);
  Hi:=NewHi;
  Place;
  SaveBack(Sv,Min2(DX1,TX)-2,BarY,DX2+4,DY2+4);
  ClipFull;
  If Not Sys Then DrawMenuBar(W,M);
  GBar(DX1+3,DY2+1,DX2+3,DY2+3,cBlk);
  GBar(DX2+1,DY1+3,DX2+3,DY2+3,cBlk);
  If Sys Then DrawDrop(SysDef,DX1,DY1,DX2,DY2,Hi)
  Else DrawDrop(W^.Menus[M],DX1,DY1,DX2,DY2,Hi);
  ShowMouse;
 End;

 Function ItemOf(Ch: Char): Integer;
 Var K: Integer;
 Begin
  ItemOf:=0;
  For K:=1 To W^.Menus[M].N Do
   If (MnemoOf(TL(W^.Menus[M].It[K].Txt))=Ch) And
      ((W^.Menus[M].It[K].Flag And 1)=0) Then ItemOf:=K;
 End;

Begin
 Res:=0;
 Sv.P:=Nil;
 BarY:=WinTop(W);
 If Sys Then BuildSysMenu(W) Else WinPrepare(W);
 M:=StartM;
 If Sys Then M:=1;
 TX:=0;
 Hi:=0;SwSys:=False;
 If MenuKbd Then Begin
  If Sys Then Begin Show(0);Show(NextItem(SysDef,0,1));End Else Begin Show(0);Show(NextItem(W^.Menus[M],0,1));End;
  MenuKbd:=False;
 End Else Show(0);
 Done:=False;Pick:=False;Entered:=False;
 Repeat
  PollEvent(E);
  Case E.Kind Of
   EV_MOVE,EV_DOWN,EV_UP: Begin
     PX:=E.X;PY:=E.Y;
     T:=0;
     If Not Sys Then
      For I:=1 To W^.NMenu Do
       If InBox(PX,PY,MenuTitleX(W,I)-6,BarY,MenuTitleX(W,I)+MenuTitleW(W,I)-7,
           BarY+MENU_H-1) Then T:=I;
     If Sys Then H:=DropHit(SysDef,DX1,DY1,DX2,DY2,PX,PY)
     Else H:=DropHit(W^.Menus[M],DX1,DY1,DX2,DY2,PX,PY);
     If H<>0 Then Begin
      If Sys Then Begin
       If (SysDef.It[H].Txt='-') Or ((SysDef.It[H].Flag And 1)<>0) Then H:=0;
      End Else Begin
       If (W^.Menus[M].It[H].Txt='-') Or ((W^.Menus[M].It[H].Flag And 1)<>0) Then H:=0;
      End;
     End;
     If (E.Kind=EV_MOVE) Or (E.Kind=EV_DOWN) Then Begin
      If (T>0) And (T<>M) Then Begin M:=T;Show(0);Entered:=False;End
      Else If H<>Hi Then Show(H);
      If H<>0 Then Entered:=True;
     End;
     If E.Kind=EV_DOWN Then Begin
      If H<>0 Then Begin Pick:=True;Done:=True;End
      Else If (T=0) Or (T=M) Then Done:=True;
     End;
     If E.Kind=EV_UP Then Begin
      If (H<>0) And Entered Then Begin Hi:=H;Pick:=True;Done:=True;End;
     End;
    End;
   EV_KEY: Begin
     Ch:=UpCase(Chr(E.Key And 255));
     If Sys Then Begin
      Case E.Key Of
       K_ESC: Done:=True;
       K_UP: Show(NextItem(SysDef,Hi,-1));
       K_DOWN: Show(NextItem(SysDef,Hi,1));
       K_ENTER: If Hi<>0 Then Begin Pick:=True;Done:=True;End;
      Else If (E.Key<256) And (E.Key>32) Then Begin
        Pm:=PickMnemo(SysDef,Ch,Hi);
        If Pm=1 Then Begin Pick:=True;Done:=True;End Else If Pm=2 Then Show(Hi);
       End;
      End;
     End Else Begin
      Case E.Key Of
       K_ESC: Done:=True;
       K_LEFT: Begin Dec(M);If M<1 Then M:=W^.NMenu;
               Show(NextItem(W^.Menus[M],0,1));End;
       K_RIGHT: Begin Inc(M);If M>W^.NMenu Then M:=1;
               Show(NextItem(W^.Menus[M],0,1));End;
       K_UP: Show(NextItem(W^.Menus[M],Hi,-1));
       K_DOWN: Show(NextItem(W^.Menus[M],Hi,1));
       K_ENTER: If Hi<>0 Then Begin Pick:=True;Done:=True;End;
      Else If E.Key=32 Then Begin SwSys:=True;Done:=True;End
      Else If (E.Key<256) And (E.Key>32) Then Begin
        Pm:=PickMnemo(W^.Menus[M],Ch,Hi);
        If Pm=1 Then Begin Pick:=True;Done:=True;End Else If Pm=2 Then Show(Hi);
       End Else Begin
        Ch:=AltLetter(E.Key);
        If Ch<>#0 Then Begin
         For I:=1 To W^.NMenu Do
          If MnemoOf(TL(W^.Menus[I].Title))=Ch Then Begin M:=I;Show(0);End;
        End;
       End;
      End;
     End;
    End;
  End;
 Until Done;
 HideMouse;
 RestoreBack(Sv);
 ShowMouse;
 If Pick And (Hi>0) Then Begin
  If Sys Then Res:=SysDef.It[Hi].Cmd Else Res:=W^.Menus[M].It[Hi].Cmd;
 End;
 If SwSys Then Res:=CM_OPENSYS;
 RunMenus:=Res;
End;

{ ====================================================================== }
{                 SYSTEME DE FICHIERS VIRTUEL (C:\ ...)                  }
{ ====================================================================== }

{ Chemin DOS 'C:\DIR\FILE' -> chemin reel. Sous UNIX, la racine du lecteur C:
  est RootDir et la casse est ignoree. }
Function FindCI(Const Dir,Name: String): String;
Var SR: SearchRec; U: String;
Begin
 FindCI:=Name;
 U:=Upper(Name);
 FindFirst(JoinPath(Dir,'*'),AnyFile,SR);
 While DosError=0 Do Begin
  If Upper(SR.Name)=U Then Begin FindCI:=SR.Name;Break;End;
  FindNext(SR);
 End;
 {$IFDEF FPC}FindClose(SR);{$ENDIF}
End;

Function V2R(Const V: String): String;
{$IFDEF UNIX}
Var R,Rest,Part: String; P: Integer;
Begin
 Rest:=V;
 If (Length(Rest)>=2) And (Rest[2]=':') Then Delete(Rest,1,2);
 R:=RootDir;
 While Length(Rest)>0 Do Begin
  While (Length(Rest)>0) And ((Rest[1]='\') Or (Rest[1]='/')) Do Delete(Rest,1,1);
  If Rest='' Then Break;
  P:=1;
  While (P<=Length(Rest)) And (Rest[P]<>'\') And (Rest[P]<>'/') Do Inc(P);
  Part:=Copy(Rest,1,P-1);
  Delete(Rest,1,P-1);
  If Part='.' Then Continue;
  If Part='..' Then Begin R:=DirOf(R);If R='' Then R:='/';Continue;End;
  R:=JoinPath(R,FindCI(R,Part));
 End;
 V2R:=R;
End;
{$ELSE}
Begin
 V2R:=V;
End;
{$ENDIF}

{ chemin reel -> 'C:\...' (UNIX : relatif a RootDir) }
Function R2V(Const R: String): String;
{$IFDEF UNIX}
Var S: String; I: Integer;
Begin
 S:=R;
 If Copy(S,1,Length(RootDir))=RootDir Then Delete(S,1,Length(RootDir));
 For I:=1 To Length(S) Do If S[I]='/' Then S[I]:='\';
 If (S='') Or (S[1]<>'\') Then S:='\'+S;
 R2V:='C:'+Upper(S);
End;
{$ELSE}
Begin
 R2V:=Upper(R);
End;
{$ENDIF}

Function VDirExists(Const V: String): Boolean;
Var U: String;
Begin
 U:=Upper(V);
 If (U='C:\WINDOWS') Or (U='C:\WINDOWS\') Then Begin VDirExists:=True;Exit;End;
 VDirExists:=DirExists(V2R(V));
End;

{ Parent d'un chemin virtuel }
Function VParent(Const V: String): String;
Var I: Integer; S: String;
Begin
 S:=V;
 If (Length(S)>3) And (S[Length(S)]='\') Then Delete(S,Length(S),1);
 I:=Length(S);
 While (I>0) And (S[I]<>'\') Do Dec(I);
 If I<=3 Then VParent:=Copy(S,1,3) Else VParent:=Copy(S,1,I-1);
End;

Function VJoin(Const D,N: String): String;
Begin
 If D[Length(D)]='\' Then VJoin:=D+N Else VJoin:=D+'\'+N;
End;

{ ====================================================================== }
{                      BOITES DE DIALOGUE MODALES                        }
{ ====================================================================== }

Const
 FR = 7;         { epaisseur du cadre de dialogue }
 { evenements envoyes a la fonction de rappel }
 DE_BUTTON = 1; DE_CHANGE = 2; DE_DBL = 3; DE_DRAW = 4; DE_CLICK = 5; DE_INIT = 6;

Type
 TDlgHookF = Function(Var D: TDlg; Ev, Ct: Integer): Boolean;

Function NoHook(Var D: TDlg; Ev, Ct: Integer): Boolean;
Begin
 NoHook:=False;
End;

Procedure DlgInit(Var D: TDlg; Const Title: String; W,H: Integer);
Begin
 FillChar(D,SizeOf(D),0);
 D.Title:=Title;D.W:=W+2*FR;D.H:=H+2*FR;D.N:=0;D.Focus:=0;D.Def:=0;
 D.X:=(SCR_W-D.W) Div 2;D.Y:=(SCR_H-D.H) Div 2-10;
 If D.Y<2 Then D.Y:=2;
End;

Function DlgAdd(Var D: TDlg; Kind: Byte; Id,X,Y,W,H: Integer; Const Txt: String): Integer;
Begin
 If D.N>=MAXCTL Then Begin DlgAdd:=MAXCTL;Exit;End;
 Inc(D.N);
 FillChar(D.C[D.N],SizeOf(TCtl),0);
 D.C[D.N].Kind:=Kind;D.C[D.N].Id:=Id;D.C[D.N].X:=X;D.C[D.N].Y:=Y;
 D.C[D.N].W:=W;D.C[D.N].H:=H;D.C[D.N].Txt:=Txt;D.C[D.N].Enabled:=True;
 DlgAdd:=D.N;
End;

Function DlgText(Var D: TDlg; X,Y: Integer; Const Txt: String): Integer;
Begin
 DlgText:=DlgAdd(D,C_TEXT,0,X,Y,Length(Txt)*8,12,Txt);
End;

Function DlgEdit(Var D: TDlg; Id,X,Y,W: Integer; Const Txt: String; MaxLen: Integer): Integer;
Var I: Integer;
Begin
 I:=DlgAdd(D,C_EDIT,Id,X,Y,W,16,Txt);
 D.C[I].Grp:=MaxLen;D.C[I].Val:=Length(Txt);
 DlgEdit:=I;
End;

Function DlgButton(Var D: TDlg; Id,X,Y,W: Integer; Const Txt: String; IsDef: Boolean): Integer;
Var I: Integer;
Begin
 I:=DlgAdd(D,C_BUTTON,Id,X,Y,W,20,Txt);
 If IsDef Then Begin D.Def:=I;If D.Focus=0 Then D.Focus:=I;End;
 DlgButton:=I;
End;

Function DlgRadio(Var D: TDlg; Id,X,Y,Grp: Integer; Const Txt: String; On: Boolean): Integer;
Var I: Integer;
Begin
 I:=DlgAdd(D,C_RADIO,Id,X,Y,TextW(Txt)+18,12,Txt);
 D.C[I].Grp:=Grp;
 If On Then D.C[I].Val:=1;
 DlgRadio:=I;
End;

Function DlgCheck(Var D: TDlg; Id,X,Y: Integer; Const Txt: String; On: Boolean): Integer;
Var I: Integer;
Begin
 I:=DlgAdd(D,C_CHECK,Id,X,Y,TextW(Txt)+18,12,Txt);
 If On Then D.C[I].Val:=1;
 DlgCheck:=I;
End;

Function DlgList(Var D: TDlg; Id,X,Y,W,H: Integer; L: PStrList; Sel: Integer): Integer;
Var I: Integer;
Begin
 I:=DlgAdd(D,C_LIST,Id,X,Y,W,H,'');
 D.C[I].Lst:=L;D.C[I].Val:=Sel;D.C[I].Top:=0;
 DlgList:=I;
End;

Function DlgSlider(Var D: TDlg; Id,X,Y,W: Integer; Mn,Mx,V: Integer): Integer;
Var I: Integer;
Begin
 I:=DlgAdd(D,C_SLIDER,Id,X,Y,W,SB,'');
 D.C[I].Mn:=Mn;D.C[I].Mx:=Mx;D.C[I].Val:=V;
 DlgSlider:=I;
End;

Function DlgBox(Var D: TDlg; X,Y,W,H: Integer; Const Txt: String): Integer;
Begin
 DlgBox:=DlgAdd(D,C_BOX,0,X,Y,W,H,Txt);
End;

Function DlgCustom(Var D: TDlg; Id,X,Y,W,H: Integer): Integer;
Begin
 DlgCustom:=DlgAdd(D,C_CUSTOM,Id,X,Y,W,H,'');
End;

Function DlgIcon(Var D: TDlg; X,Y,Kind: Integer): Integer;
Var I: Integer;
Begin
 I:=DlgAdd(D,C_ICON,0,X,Y,32,32,'');
 D.C[I].Val:=Kind;
 DlgIcon:=I;
End;

Function DlgFind(Var D: TDlg; Id: Integer): Integer;
Var I: Integer;
Begin
 DlgFind:=0;
 For I:=1 To D.N Do If D.C[I].Id=Id Then Begin DlgFind:=I;Exit;End;
End;

Function DlgGetText(Var D: TDlg; Id: Integer): String;
Var I: Integer;
Begin
 I:=DlgFind(D,Id);
 If I=0 Then DlgGetText:='' Else DlgGetText:=D.C[I].Txt;
End;

Function DlgGetVal(Var D: TDlg; Id: Integer): Integer;
Var I: Integer;
Begin
 I:=DlgFind(D,Id);
 If I=0 Then DlgGetVal:=0 Else DlgGetVal:=D.C[I].Val;
End;

Procedure DlgSetVal(Var D: TDlg; Id,V: Integer);
Var I: Integer;
Begin
 I:=DlgFind(D,Id);
 If I<>0 Then D.C[I].Val:=V;
End;

Procedure DlgSetText(Var D: TDlg; Id: Integer; Const S: String);
Var I: Integer;
Begin
 I:=DlgFind(D,Id);
 If I<>0 Then Begin D.C[I].Txt:=S;If D.C[I].Kind=C_EDIT Then D.C[I].Val:=Length(S);End;
End;

{ Origine absolue d'un controle }
Function CtlX(Var D: TDlg; I: Integer): Integer;
Begin
 CtlX:=D.X+FR+D.C[I].X;
End;

Function CtlY(Var D: TDlg; I: Integer): Integer;
Begin
 CtlY:=D.Y+FR+D.C[I].Y;
End;

Var
 DlgForceClose: Boolean;
 ExtIconOn: Boolean;
 ExtIconDraw: Procedure(S,X,Y,Sz: Integer);

Procedure DrawDlgIcon(X,Y,Kind: Integer);
Begin
 Case Kind Of
  1: Begin
      GFillEllipse(X+16,Y+16,15,15,cBlk);
      GFillEllipse(X+16,Y+16,13,13,cWht);
      GBar(X+14,Y+7,X+17,Y+20,cBlk);
      GBar(X+14,Y+23,X+17,Y+26,cBlk);
     End;
  2: Begin
      GFillEllipse(X+16,Y+16,15,15,cBlk);
      GFillEllipse(X+16,Y+16,13,13,cWht);
      GTextBig(X+10,Y+9,'?',2,cBlk);
     End;
  3: Begin
      GFillEllipse(X+16,Y+16,15,15,cBlk);
      GFillEllipse(X+16,Y+16,13,13,cLRd);
      GBar(X+7,Y+13,X+25,Y+18,cWht);
     End;
  4: DrawIconFloppy(X,Y);
 Else Begin
      GBar(X+2,Y+2,X+29,Y+29,cBlk);GBar(X+4,Y+4,X+27,Y+27,cWht);
      GText(X+12,Y+12,'!',cBlk);
     End;
 End;
End;

Procedure DrawEditText(Var D: TDlg; I: Integer);
Var X,Y,MaxC,Off,Cur: Integer; S,V: String; Foc: Boolean;
Begin
 X:=CtlX(D,I);Y:=CtlY(D,I);
 Foc:=(D.Focus=I);
 GBar(X,Y,X+D.C[I].W-1,Y+15,cWht);
 GRect(X,Y,X+D.C[I].W-1,Y+15,cBlk);
 S:=D.C[I].Txt;
 MaxC:=(D.C[I].W-8) Div 8;
 Cur:=D.C[I].Val;
 Off:=0;
 If Cur>MaxC-1 Then Off:=Cur-(MaxC-1);
 V:=Copy(S,Off+1,MaxC);
 If Foc And (D.Sel1=1) And (S<>'') Then Begin
  GBar(X+3,Y+3,X+3+Length(V)*8,Y+12,cBlk);
  GText(X+4,Y+4,V,cWht);
 End Else Begin
  GText(X+4,Y+4,V,cBlk);
  If Foc Then GVLine(X+4+(Cur-Off)*8,Y+3,Y+12,cBlk);
 End;
End;

Procedure DrawListCtl(Var D: TDlg; I: Integer);
Var X,Y,W,H,Vis_,K,Idx: Integer; L: PStrList; T: String;
Begin
 X:=CtlX(D,I);Y:=CtlY(D,I);W:=D.C[I].W;H:=D.C[I].H;
 GBar(X,Y,X+W-1,Y+H-1,cWht);
 GRect(X,Y,X+W-1,Y+H-1,cBlk);
 L:=D.C[I].Lst;
 If L=Nil Then Exit;
 Vis_:=(H-4) Div 12;
 SetClip(X+1,Y+1,X+W-SB-1,Y+H-2);
 For K:=0 To Vis_-1 Do Begin
  Idx:=D.C[I].Top+K+1;
  If Idx>L^.N Then Break;
  T:=L^.S[Idx];
  If Idx=D.C[I].Val Then Begin
   GBar(X+2,Y+2+K*12,X+W-SB-2,Y+2+K*12+11,cBlk);
   GText(X+4,Y+4+K*12,T,cWht);
  End Else GText(X+4,Y+4+K*12,T,cBlk);
 End;
 ClipFull;
 DrawScroll(True,X+W-SB,Y,X+W-1,Y+H-1,L^.N,Vis_,D.C[I].Top);
End;

Procedure DrawButtonCtl(Var D: TDlg; I: Integer; Down: Boolean);
Var X,Y,W,H,TX: Integer; Bg,Fg: Integer; Foc: Boolean; T: String;
Begin
 X:=CtlX(D,I);Y:=CtlY(D,I);W:=D.C[I].W;H:=D.C[I].H;
 Foc:=(D.Focus=I) Or (D.Def=I);
 If Down Then Begin Bg:=cBlk;Fg:=cWht;End Else Begin Bg:=cWht;Fg:=cBlk;End;
 GBar(X-1,Y-1,X+W,Y+H,cWht);
 GRoundFill(X,Y,X+W-1,Y+H-1,cBlk,Bg);
 If Foc Then GRound(X+1,Y+1,X+W-2,Y+H-2,cBlk);
 If Foc And (D.Focus=I) Then Begin
  GRound(X+1,Y+1,X+W-2,Y+H-2,cBlk);
 End;
 T:=TL(D.C[I].Txt);
 TX:=X+(W-TextW(T)) Div 2;
 If D.C[I].Enabled Then GTextU(TX,Y+(H-8) Div 2,T,Fg)
 Else GText(TX,Y+(H-8) Div 2,NoAmp(T),cDGr);
End;

Procedure DrawCtl(Var D: TDlg; I: Integer);
Var X,Y,K,P,L: Integer; S,Ln: String; Foc: Boolean;
Begin
 X:=CtlX(D,I);Y:=CtlY(D,I);
 Foc:=(D.Focus=I);
 Case D.C[I].Kind Of
  C_TEXT: Begin
    S:=TL(D.C[I].Txt);K:=0;
    While S<>'' Do Begin
     P:=Pos('|',S);
     If P=0 Then Begin Ln:=S;S:='';End Else Begin Ln:=Copy(S,1,P-1);Delete(S,1,P);End;
     If D.C[I].Grp=1 Then GText(X+(D.C[I].W-Length(NoAmp(Ln))*8) Div 2,Y+K*12,NoAmp(Ln),cBlk)
     Else If D.C[I].Grp=2 Then GText(X+D.C[I].W-Length(NoAmp(Ln))*8,Y+K*12,NoAmp(Ln),cBlk)
     Else If Pos('&',Ln)>0 Then GTextU(X,Y+K*12,Ln,cBlk)
     Else GText(X,Y+K*12,NoAmp(Ln),cBlk);
     Inc(K);
    End;
   End;
  C_EDIT: DrawEditText(D,I);
  C_BUTTON: DrawButtonCtl(D,I,False);
  C_RADIO: Begin
    GFillEllipse(X+5,Y+5,5,5,cWht);
    GEllipse(X+5,Y+5,5,5,cBlk);
    If D.C[I].Val=1 Then GFillEllipse(X+5,Y+5,2,2,cBlk);
    GTextU(X+16,Y+1,TL(D.C[I].Txt),cBlk);
    If Foc Then GDotRect(X+13,Y-1,X+16+TextW(TL(D.C[I].Txt)),Y+10,cBlk);
   End;
  C_CHECK: Begin
    GBar(X,Y,X+10,Y+10,cWht);
    GRect(X,Y,X+10,Y+10,cBlk);
    If D.C[I].Val=1 Then Begin GLine(X+2,Y+2,X+8,Y+8,cBlk);GLine(X+8,Y+2,X+2,Y+8,cBlk);End;
    GTextU(X+16,Y+1,TL(D.C[I].Txt),cBlk);
    If Foc Then GDotRect(X+13,Y-1,X+16+TextW(TL(D.C[I].Txt)),Y+10,cBlk);
   End;
  C_LIST: DrawListCtl(D,I);
  C_SLIDER: DrawScroll(False,X,Y,X+D.C[I].W-1,Y+SB-1,D.C[I].Mx-D.C[I].Mn+1+
     (D.C[I].Mx-D.C[I].Mn) Div 8+1,(D.C[I].Mx-D.C[I].Mn) Div 8+1,D.C[I].Val-D.C[I].Mn);
  C_BOX: Begin
    GRect(X,Y+4,X+D.C[I].W-1,Y+D.C[I].H-1,cBlk);
    If D.C[I].Txt<>'' Then Begin
     L:=TextW(TL(D.C[I].Txt));
     GBar(X+6,Y,X+10+L,Y+8,cWht);
     GTextU(X+8,Y,TL(D.C[I].Txt),cBlk);
    End;
   End;
  C_ICON: If (D.C[I].Val>=1000) And ExtIconOn Then ExtIconDraw(D.C[I].Val,X,Y,32) Else DrawDlgIcon(X,Y,D.C[I].Val);
  C_BAR: GBar(X,Y,X+D.C[I].W-1,Y+Max2(1,D.C[I].H)-1,cBlk);
 End;
End;

Var DlgHk: TDlgHookF;

Procedure DrawDlgFrame(Var D: TDlg);
Var X1,Y1,X2,Y2: Integer;
Begin
 X1:=D.X;Y1:=D.Y;X2:=D.X+D.W-1;Y2:=D.Y+D.H-1;
 GBar(X1,Y1,X2,Y2,cWht);
 GRect(X1,Y1,X2,Y2,cBlk);
 GBar(X1+1,Y1+1,X2-1,Y1+FR-3,cLBl);GBar(X1+1,Y2-FR+3,X2-1,Y2-1,cLBl);
 GBar(X1+1,Y1+1,X1+FR-3,Y2-1,cLBl);GBar(X2-FR+3,Y1+1,X2-1,Y2-1,cLBl);
 GRect(X1+FR-2,Y1+FR-2,X2-FR+2,Y2-FR+2,cBlk);
End;

Procedure DrawDlg(Var D: TDlg);
Var I: Integer;
Begin
 HideMouse;
 ClipFull;
 DrawDlgFrame(D);
 SetClip(D.X+1,D.Y+1,D.X+D.W-2,D.Y+D.H-2);
 For I:=1 To D.N Do Begin
  ClipFull;
  If D.C[I].Kind=C_CUSTOM Then DlgHk(D,DE_DRAW,I) Else DrawCtl(D,I);
 End;
 ClipFull;
 ShowMouse;
End;

Procedure DrawOne(Var D: TDlg; I: Integer);
Begin
 HideMouse;
 ClipFull;
 If D.C[I].Kind=C_CUSTOM Then DlgHk(D,DE_DRAW,I) Else DrawCtl(D,I);
 ClipFull;
 ShowMouse;
End;

Function Focusable(Var D: TDlg; I: Integer): Boolean;
Begin
 Focusable:=(D.C[I].Kind In [C_EDIT,C_BUTTON,C_RADIO,C_CHECK,C_LIST,C_SLIDER]) And
            D.C[I].Enabled;
End;

Procedure NextFocus(Var D: TDlg; Dir: Integer);
Var K,I: Integer;
Begin
 If D.N=0 Then Exit;
 I:=D.Focus;
 For K:=1 To D.N Do Begin
  I:=I+Dir;
  If I<1 Then I:=D.N;
  If I>D.N Then I:=1;
  If Focusable(D,I) Then Begin
   D.Focus:=I;
   If D.C[I].Kind=C_EDIT Then D.Sel1:=1 Else D.Sel1:=0;
   Exit;
  End;
 End;
End;

Procedure SelectRadio(Var D: TDlg; I: Integer);
Var K: Integer;
Begin
 For K:=1 To D.N Do
  If (D.C[K].Kind=C_RADIO) And (D.C[K].Grp=D.C[I].Grp) Then D.C[K].Val:=0;
 D.C[I].Val:=1;
End;

Function RadioGroupVal(Var D: TDlg; Grp: Integer): Integer;
Var K,N: Integer;
Begin
 N:=0;RadioGroupVal:=-1;
 For K:=1 To D.N Do
  If (D.C[K].Kind=C_RADIO) And (D.C[K].Grp=Grp) Then Begin
   If D.C[K].Val=1 Then RadioGroupVal:=N;
   Inc(N);
  End;
End;

Procedure ListEnsure(Var D: TDlg; I: Integer);
Var Vis_: Integer;
Begin
 Vis_:=(D.C[I].H-4) Div 12;
 If D.C[I].Lst=Nil Then Exit;
 If D.C[I].Val<1 Then Exit;
 If D.C[I].Val-1<D.C[I].Top Then D.C[I].Top:=D.C[I].Val-1;
 If D.C[I].Val>D.C[I].Top+Vis_ Then D.C[I].Top:=D.C[I].Val-Vis_;
 If D.C[I].Top<0 Then D.C[I].Top:=0;
End;

Procedure EditKey(Var D: TDlg; I: Integer; K: Word);
Var C: Integer; S: String;
Begin
 S:=D.C[I].Txt;C:=D.C[I].Val;
 If (K>=32) And (K<256) Then Begin
  If D.Sel1=1 Then Begin S:='';C:=0;D.Sel1:=0;End;
  If Length(S)<D.C[I].Grp Then Begin Insert(Chr(K),S,C+1);Inc(C);End;
 End Else Case K Of
  K_BKSP: Begin
    If D.Sel1=1 Then Begin S:='';C:=0;D.Sel1:=0;End
    Else If C>0 Then Begin Delete(S,C,1);Dec(C);End;
   End;
  K_DEL: Begin
    If D.Sel1=1 Then Begin S:='';C:=0;D.Sel1:=0;End
    Else If C<Length(S) Then Delete(S,C+1,1);
   End;
  K_LEFT: Begin D.Sel1:=0;If C>0 Then Dec(C);End;
  K_RIGHT: Begin D.Sel1:=0;If C<Length(S) Then Inc(C);End;
  K_HOME: Begin D.Sel1:=0;C:=0;End;
  K_END: Begin D.Sel1:=0;C:=Length(S);End;
 End;
 D.C[I].Txt:=S;D.C[I].Val:=C;
End;

Function RunDialog(Var D: TDlg; Hook: TDlgHookF): Integer;
Var E: TEvent; Sc: TScreenSave; Res,I,K,J,Vis_: Integer; Done: Boolean;
    Ch: Char; Hit: Integer; Inside,Hd: Boolean; X,Y: Integer; Tr: LongInt;

 Procedure Press(B: Integer);
 Var Dn: Boolean; Ev2: TEvent; Ins: Boolean;
 Begin
  Dn:=True;
  D.Focus:=B;
  HideMouse;DrawDlg(D);DrawButtonCtl(D,B,True);ShowMouse;
  Repeat
   PollEvent(Ev2);
   Ins:=InBox(MX,MY,CtlX(D,B),CtlY(D,B),CtlX(D,B)+D.C[B].W-1,CtlY(D,B)+D.C[B].H-1);
   If Ins<>Dn Then Begin
    Dn:=Ins;
    HideMouse;
    DrawButtonCtl(D,B,Dn);
    ShowMouse;
   End;
  Until (MB And 1)=0;
  HideMouse;DrawButtonCtl(D,B,False);ShowMouse;
  If Dn Then Begin
   If Not Hook(D,DE_BUTTON,B) Then Begin Res:=D.C[B].Id;Done:=True;End
   Else DrawDlg(D);
  End;
 End;

 Procedure ActivateCtl(B: Integer);
 Begin
  If D.C[B].Kind=C_BUTTON Then Begin
   HideMouse;DrawButtonCtl(D,B,True);ShowMouse;
   Delay(80);
   HideMouse;DrawButtonCtl(D,B,False);ShowMouse;
   If Not Hook(D,DE_BUTTON,B) Then Begin Res:=D.C[B].Id;Done:=True;End
   Else DrawDlg(D);
  End;
 End;

Begin
 DlgHk:=Hook;
 Res:=ID_CANCEL;Done:=False;
 HideMouse;
 SaveScreen(Sc);
 If D.Focus=0 Then NextFocus(D,1);
 If (D.Focus<>0) And (D.C[D.Focus].Kind=C_EDIT) Then D.Sel1:=1;
 Hook(D,DE_INIT,0);
 DrawDlg(D);
 ShowMouse;
 Repeat
  PollEvent(E);
  If DlgForceClose Then Begin DlgForceClose:=False;Done:=True;End;
  Case E.Kind Of
   EV_DOWN: Begin
     Hit:=0;
     For I:=D.N DownTo 1 Do
      If D.C[I].Enabled And (D.C[I].Kind<>C_TEXT) And (D.C[I].Kind<>C_BOX) And
         (D.C[I].Kind<>C_ICON) And (D.C[I].Kind<>C_BAR) Then Begin
       X:=CtlX(D,I);Y:=CtlY(D,I);
       If InBox(E.X,E.Y,X,Y,X+D.C[I].W-1,Y+D.C[I].H-1) Then Begin Hit:=I;Break;End;
      End;
     If Hit<>0 Then Begin
      X:=CtlX(D,Hit);Y:=CtlY(D,Hit);
      Case D.C[Hit].Kind Of
       C_BUTTON: Press(Hit);
       C_EDIT: Begin
         D.Focus:=Hit;D.Sel1:=0;
         K:=(E.X-X-4+4) Div 8;
         Vis_:=(D.C[Hit].W-8) Div 8;
         If D.C[Hit].Val>Vis_-1 Then K:=K+(D.C[Hit].Val-(Vis_-1));
         D.C[Hit].Val:=Clamp(K,0,Length(D.C[Hit].Txt));
         DrawDlg(D);
        End;
       C_RADIO: Begin D.Focus:=Hit;SelectRadio(D,Hit);Hook(D,DE_CHANGE,Hit);DrawDlg(D);End;
       C_CHECK: Begin
         D.Focus:=Hit;D.C[Hit].Val:=1-D.C[Hit].Val;
         Hook(D,DE_CHANGE,Hit);DrawDlg(D);
        End;
       C_LIST: Begin
         D.Focus:=Hit;
         Vis_:=(D.C[Hit].H-4) Div 12;
         If D.C[Hit].Lst<>Nil Then Begin
          If E.X>=X+D.C[Hit].W-SB Then Begin
           { barre de defilement de la liste }
           K:=ScrollPart(True,X+D.C[Hit].W-SB,Y,X+D.C[Hit].W-1,Y+D.C[Hit].H-1,
              D.C[Hit].Lst^.N,Vis_,D.C[Hit].Top,E.X,E.Y);
           Case K Of
            1: Dec(D.C[Hit].Top);
            2: Inc(D.C[Hit].Top);
            3: Dec(D.C[Hit].Top,Vis_);
            4: Inc(D.C[Hit].Top,Vis_);
           End;
           If D.C[Hit].Top>D.C[Hit].Lst^.N-Vis_ Then D.C[Hit].Top:=D.C[Hit].Lst^.N-Vis_;
           If D.C[Hit].Top<0 Then D.C[Hit].Top:=0;
          End Else Begin
           K:=D.C[Hit].Top+(E.Y-Y-2) Div 12+1;
           If (K>=1) And (K<=D.C[Hit].Lst^.N) Then Begin
            D.C[Hit].Val:=K;
            Hook(D,DE_CHANGE,Hit);
            If E.Dbl Then Begin
             If Not Hook(D,DE_DBL,Hit) Then Begin
              If D.Def<>0 Then Begin Res:=D.C[D.Def].Id;Done:=True;End;
             End;
            End;
           End;
          End;
         End;
         DrawDlg(D);
        End;
       C_SLIDER: Begin
         D.Focus:=Hit;
         Repeat
          J:=D.C[Hit].Mx-D.C[Hit].Mn;
          K:=ScrollPart(False,X,Y,X+D.C[Hit].W-1,Y+SB-1,J+J Div 8+2,J Div 8+1,
             D.C[Hit].Val-D.C[Hit].Mn,MX,MY);
          Case K Of
           1: Dec(D.C[Hit].Val);
           2: Inc(D.C[Hit].Val);
           3: Dec(D.C[Hit].Val,J Div 8+1);
           4: Inc(D.C[Hit].Val,J Div 8+1);
           5: Begin
              D.C[Hit].Val:=D.C[Hit].Mn+ScrollDrag(False,X,Y,X+D.C[Hit].W-1,Y+SB-1,
                J+J Div 8+2,J Div 8+1,MX,(X+SB+((D.C[Hit].Val-D.C[Hit].Mn)*
                (D.C[Hit].W-3*SB)) Div (J+1))+6);
             End;
          End;
          D.C[Hit].Val:=Clamp(D.C[Hit].Val,D.C[Hit].Mn,D.C[Hit].Mx);
          Hook(D,DE_CHANGE,Hit);
          DrawDlg(D);
          Delay(25);
          PollEvent(E);
         Until (MB And 1)=0;
        End;
       C_CUSTOM: Begin
         If Hook(D,DE_CLICK,Hit) Then DrawDlg(D);
        End;
      End;
     End;
    End;
   EV_KEY: Begin
     Case E.Key Of
      K_ESC: Begin
        Res:=ID_CANCEL;Done:=True;
        For I:=1 To D.N Do
         If (D.C[I].Kind=C_BUTTON) And (D.C[I].Id=ID_CANCEL) Then Begin
          If Hook(D,DE_BUTTON,I) Then Done:=False;
         End;
       End;
      K_ENTER: Begin
        If (D.Focus<>0) And (D.C[D.Focus].Kind=C_BUTTON) Then ActivateCtl(D.Focus)
        Else If D.Def<>0 Then ActivateCtl(D.Def)
        Else Begin Res:=ID_OK;Done:=True;End;
       End;
      K_TAB: Begin NextFocus(D,1);DrawDlg(D);End;
      K_SHTAB: Begin NextFocus(D,-1);DrawDlg(D);End;
     Else Begin
       If (D.Focus<>0) And (D.C[D.Focus].Kind=C_EDIT) And
          ((E.Key<256) Or (E.Key=K_LEFT) Or (E.Key=K_RIGHT) Or (E.Key=K_HOME) Or
           (E.Key=K_END) Or (E.Key=K_DEL)) Then Begin
        EditKey(D,D.Focus,E.Key);Hook(D,DE_CHANGE,D.Focus);DrawDlg(D);
       End Else If (D.Focus<>0) And (D.C[D.Focus].Kind=C_LIST) And (D.C[D.Focus].Lst<>Nil) Then Begin
        I:=D.Focus;
        Vis_:=(D.C[I].H-4) Div 12;
        Case E.Key Of
         K_UP: If D.C[I].Val>1 Then Dec(D.C[I].Val);
         K_DOWN: If D.C[I].Val<D.C[I].Lst^.N Then Inc(D.C[I].Val);
         K_PGUP: D.C[I].Val:=Max2(1,D.C[I].Val-Vis_);
         K_PGDN: D.C[I].Val:=Min2(D.C[I].Lst^.N,D.C[I].Val+Vis_);
         K_HOME: D.C[I].Val:=1;
         K_END: D.C[I].Val:=D.C[I].Lst^.N;
        End;
        ListEnsure(D,I);
        Hook(D,DE_CHANGE,I);DrawDlg(D);
       End Else If (D.Focus<>0) And (D.C[D.Focus].Kind=C_SLIDER) Then Begin
        I:=D.Focus;
        Case E.Key Of
         K_LEFT: Dec(D.C[I].Val);
         K_RIGHT: Inc(D.C[I].Val);
        End;
        D.C[I].Val:=Clamp(D.C[I].Val,D.C[I].Mn,D.C[I].Mx);
        Hook(D,DE_CHANGE,I);DrawDlg(D);
       End Else If (E.Key=K_SPACE) And (D.Focus<>0) Then Begin
        I:=D.Focus;
        Case D.C[I].Kind Of
         C_CHECK: Begin D.C[I].Val:=1-D.C[I].Val;Hook(D,DE_CHANGE,I);DrawDlg(D);End;
         C_RADIO: Begin SelectRadio(D,I);Hook(D,DE_CHANGE,I);DrawDlg(D);End;
         C_BUTTON: ActivateCtl(I);
        End;
       End Else If ((E.Key=K_UP) Or (E.Key=K_DOWN)) And (D.Focus<>0) And
          (D.C[D.Focus].Kind=C_RADIO) Then Begin
        { fleches : change de bouton radio dans le groupe }
        I:=D.Focus;K:=I;
        Repeat
         If E.Key=K_UP Then Dec(K) Else Inc(K);
         If K<1 Then K:=D.N;
         If K>D.N Then K:=1;
        Until ((D.C[K].Kind=C_RADIO) And (D.C[K].Grp=D.C[I].Grp)) Or (K=I);
        D.Focus:=K;SelectRadio(D,K);Hook(D,DE_CHANGE,K);DrawDlg(D);
       End Else Begin
        { mnemoniques Alt+lettre / lettre souligne }
        Ch:=AltLetter(E.Key);
        If Ch<>#0 Then
         For I:=1 To D.N Do
          If D.C[I].Enabled And (MnemoOf(TL(D.C[I].Txt))=Ch) Then Begin
           Case D.C[I].Kind Of
            C_BUTTON: ActivateCtl(I);
            C_RADIO: Begin D.Focus:=I;SelectRadio(D,I);Hook(D,DE_CHANGE,I);DrawDlg(D);End;
            C_CHECK: Begin D.Focus:=I;D.C[I].Val:=1-D.C[I].Val;Hook(D,DE_CHANGE,I);DrawDlg(D);End;
            C_TEXT: Begin
              { etiquette : place le focus sur la zone de texte / liste qui suit }
              For K:=I+1 To D.N Do
               If D.C[K].Enabled And ((D.C[K].Kind=C_EDIT) Or (D.C[K].Kind=C_LIST) Or (D.C[K].Kind=C_SLIDER)) Then Begin
                D.Focus:=K;DrawDlg(D);Break;
               End;
             End;
           End;
           Break;
          End;
       End;
      End;
     End;
    End;
  End;
  If Not Done Then Begin
   { demande de rafraichissement par la fonction de rappel }
   Hd:=Hook(D,DE_INIT,-1);
   If Hd Then DrawDlg(D);
  End;
 Until Done;
 HideMouse;
 PutScreen(Sc);
 FreeScreen(Sc);
 ShowMouse;
 Dirty:=False;
 RunDialog:=Res;
End;

{ ---------------------------------------------------------------------- }
{ Boites standard                                                         }
{ ---------------------------------------------------------------------- }

{ Flags : 0 OK ; 1 OK/Annuler ; 2 Oui/Non ; 3 Oui/Non/Annuler ; Ico : icone }
Function MsgBox(Const Txt: String; Flags,Ico: Integer): Integer;
Var D: TDlg; Lines,MaxL,L,P,W,H,I,BX: Integer; S,Ln: String; NB: Integer;
Begin
 S:=TL(Txt);Lines:=0;MaxL:=0;
 While S<>'' Do Begin
  P:=Pos('|',S);
  If P=0 Then Begin Ln:=S;S:='';End Else Begin Ln:=Copy(S,1,P-1);Delete(S,1,P);End;
  Inc(Lines);
  L:=Length(Ln)*8;
  If L>MaxL Then MaxL:=L;
 End;
 Case Flags Of 0: NB:=1;1,2: NB:=2;Else NB:=3;End;
 W:=MaxL+40;
 If Ico<>0 Then W:=W+44;
 If W<NB*90+20 Then W:=NB*90+20;
 H:=Lines*12+32+24;
 If (Ico<>0) And (H<32+50) Then H:=32+50;
 DlgInit(D,'',W,H);
 If Ico<>0 Then DlgIcon(D,10,8,Ico);
 DlgText(D,10+Ord(Ico<>0)*44,10,Txt);
 BX:=(W-(NB*80+(NB-1)*10)) Div 2;
 Case Flags Of
  0: DlgButton(D,ID_OK,BX,H-30,80,'OK',True);
  1: Begin DlgButton(D,ID_OK,BX,H-30,80,'OK',True);
       DlgButton(D,ID_CANCEL,BX+90,H-30,80,T3('Cancel','Annuler','Abbrechen'),False);End;
  2: Begin DlgButton(D,ID_YES,BX,H-30,80,T3('&Yes','&Oui','&Ja'),True);
       DlgButton(D,ID_NO,BX+90,H-30,80,T3('&No','&Non','&Nein'),False);End;
 Else Begin
       DlgButton(D,ID_YES,BX,H-30,80,T3('&Yes','&Oui','&Ja'),True);
       DlgButton(D,ID_NO,BX+90,H-30,80,T3('&No','&Non','&Nein'),False);
       DlgButton(D,ID_CANCEL,BX+180,H-30,80,T3('Cancel','Annuler','Abbrechen'),False);End;
 End;
 I:=RunDialog(D,@NoHook);
 If (Flags=2) And (I=ID_CANCEL) Then I:=ID_NO;
 MsgBox:=I;
End;

Procedure InfoBox(Const Txt: String);
Var R: Integer;
Begin
 R:=MsgBox(Txt,0,1);
End;

Function InputBox(Const Prompt: String; Var S: String; MaxLen,W: Integer): Boolean;
Var D: TDlg; I: Integer;
Begin
 DlgInit(D,'',W,86);
 DlgText(D,10,10,Prompt);
 DlgEdit(D,10,10,28,W-20,S,MaxLen);
 DlgButton(D,ID_OK,W Div 2-85,54,80,'OK',True);
 DlgButton(D,ID_CANCEL,W Div 2+5,54,80,T3('Cancel','Annuler','Abbrechen'),False);
 I:=RunDialog(D,@NoHook);
 If I=ID_OK Then Begin S:=DlgGetText(D,10);InputBox:=True;End Else InputBox:=False;
End;

Procedure AboutBox(Const AppName: String; Ico: Integer; Extra: String);
Var D: TDlg; L: Integer; M: String;
Begin
 M:=TL(AppName);
 DlgInit(D,'',280,150);
 DlgIcon(D,12,14,Ico);
 DlgText(D,60,12,'Microsoft Windows|'+M+'|'+T3('Version ','Version ','Version ')+VERSION_TEXT);
 DlgText(D,60,56,'Copyright '#184' 1987 Microsoft Corp.');
 If Extra<>'' Then DlgText(D,60,76,Extra);
 DlgButton(D,ID_OK,100,112,80,'OK',True);
 L:=RunDialog(D,@NoHook);
End;

{ ====================================================================== }
{          OPERATIONS SUR LES FENETRES : DEPLACEMENT, TAILLE, ...        }
{ ====================================================================== }

Var
 DirtyTop : Boolean;
 LaunchHook : Procedure(App: Integer; Const Arg: String);

Procedure Invalidate(W: PWindow);
Begin
 If Dirty Then Exit;
 If W=ActiveWin Then DirtyTop:=True Else Dirty:=True;
End;

Procedure DrawOutline(X,Y,W,H: Integer);
Begin
 ClipFull;
 GRect(X,Y,X+W-1,Y+H-1,cBlk);
 GRect(X+1,Y+1,X+W-2,Y+H-2,cWht);
 GRect(X+2,Y+2,X+W-3,Y+H-3,cBlk);
 GDotRect(X+3,Y+3,X+W-4,Y+H-4,cWht);
End;

{ Deplacement ou changement de taille par contour. Mode 0 : deplacement ;
  1..8 : bords (1 gauche 2 droite 4 haut 8 bas, combinables) ;
  Kb : pilotage au clavier }
Procedure OutlineOp(W: PWindow; Mode: Integer; Kb: Boolean);
Var Sc: TScreenSave; E: TEvent; X,Y,WW,HH,GX,GY,OX,OY,OW,OH: Integer; Done,Ok: Boolean;
    MinW,MinH,Step,SaveCursorKind: Integer;
Begin
 MinW:=120;MinH:=70;
 OX:=W^.X;OY:=W^.Y;OW:=W^.W;OH:=W^.H;
 X:=OX;Y:=OY;WW:=OW;HH:=OH;
 HideMouse;
 SaveCursorKind:=CurKind;SetCurKind(6);
 SaveScreen(Sc);
 GX:=MX-X;GY:=MY-Y;
 If Kb Then Begin MX:=X+WW Div 2;MY:=Y+HH Div 2;End;
 DrawOutline(X,Y,WW,HH);
 ShowMouse;
 Done:=False;Ok:=False;
 Repeat
  PollEvent(E);
  If E.Kind=EV_MOVE Then Begin
   If Mode=0 Then Begin X:=E.X-GX;Y:=E.Y-GY;End
   Else If Mode<0 Then Begin End
   Else Begin
    If (Mode And 1)<>0 Then Begin X:=Min2(E.X,OX+OW-MinW);WW:=OX+OW-X;End;
    If (Mode And 2)<>0 Then WW:=Max2(MinW,E.X-OX+1);
    If (Mode And 4)<>0 Then Begin Y:=Min2(E.Y,OY+OH-MinH);HH:=OY+OH-Y;End;
    If (Mode And 8)<>0 Then HH:=Max2(MinH,E.Y-OY+1);
   End;
   HideMouse;PutScreen(Sc);DrawOutline(X,Y,WW,HH);ShowMouse;
  End;
  If E.Kind=EV_KEY Then Begin
   Step:=8;
   If (Mode=-1) Or (Mode>0) And Kb Then Begin
    { redimensionnement clavier : la premiere fleche choisit le bord, la seconde (perpendiculaire) le coin }
    Case E.Key Of
     K_ESC: Done:=True;
     K_ENTER: Begin Done:=True;Ok:=True;End;
     K_LEFT: Begin
       If Mode<=0 Then Mode:=1
       Else If (Mode And 3)=0 Then Mode:=Mode Or 1;
       If (Mode And 1)<>0 Then Begin If WW<OW+400 Then Begin Dec(X,Step);Inc(WW,Step);End;End
       Else If (Mode And 2)<>0 Then Begin If WW>MinW Then Dec(WW,Step);End;
      End;
     K_RIGHT: Begin
       If Mode<=0 Then Mode:=2
       Else If (Mode And 3)=0 Then Mode:=Mode Or 2;
       If (Mode And 2)<>0 Then Inc(WW,Step)
       Else If (Mode And 1)<>0 Then Begin If WW>MinW Then Begin Inc(X,Step);Dec(WW,Step);End;End;
      End;
     K_UP: Begin
       If Mode<=0 Then Mode:=4
       Else If (Mode And 12)=0 Then Mode:=Mode Or 4;
       If (Mode And 4)<>0 Then Begin If HH<OH+400 Then Begin Dec(Y,Step);Inc(HH,Step);End;End
       Else If (Mode And 8)<>0 Then Begin If HH>MinH Then Dec(HH,Step);End;
      End;
     K_DOWN: Begin
       If Mode<=0 Then Mode:=8
       Else If (Mode And 12)=0 Then Mode:=Mode Or 8;
       If (Mode And 8)<>0 Then Inc(HH,Step)
       Else If (Mode And 4)<>0 Then Begin If HH>MinH Then Begin Inc(Y,Step);Dec(HH,Step);End;End;
      End;
    End;
   End Else
   Case E.Key Of
    K_ESC: Done:=True;
    K_ENTER: Begin Done:=True;Ok:=True;End;
    K_LEFT: If Mode=0 Then Dec(X,Step) Else If WW>MinW Then Dec(WW,Step);
    K_RIGHT: If Mode=0 Then Inc(X,Step) Else Inc(WW,Step);
    K_UP: If Mode=0 Then Dec(Y,Step) Else If HH>MinH Then Dec(HH,Step);
    K_DOWN: If Mode=0 Then Inc(Y,Step) Else Inc(HH,Step);
   End;
   If Not Done Then Begin HideMouse;PutScreen(Sc);DrawOutline(X,Y,WW,HH);ShowMouse;End;
  End;
  If (Not Kb) And (E.Kind=EV_UP) Then Begin Done:=True;Ok:=True;End;
 Until Done;
 HideMouse;
 PutScreen(Sc);
 FreeScreen(Sc);
 SetCurKind(SaveCursorKind);
 ShowMouse;
 If Ok Then Begin
  W^.X:=X;W^.Y:=Y;
  If (WW<>OW) Or (HH<>OH) Then Begin W^.W:=WW;W^.H:=HH;AppResize(W);End;
  W^.UX:=W^.X;W^.UY:=W^.Y;W^.UW:=W^.W;W^.UH:=W^.H;
 End;
 Dirty:=True;
End;

Procedure CloseWindow(W: PWindow);
Begin
 If AppCanClose(W) Then RemoveWindow(W);
 Dirty:=True;
End;

Procedure IconDrag(W: PWindow); Forward;

Procedure DoSysCmd(W: PWindow; Cmd: Integer);
Begin
 Case Cmd Of
  CM_RESTORE: RestoreWin(W);
  CM_MOVE: If W^.State=0 Then OutlineOp(W,0,True) Else If W^.State=1 Then Begin MX:=W^.IconX+ICON_W Div 2;MY:=W^.IconY+ICON_H Div 2;IconDrag(W);End;
  CM_SIZE: If W^.Sizable And (W^.State=0) Then OutlineOp(W,-1,True);
  CM_MINIMIZE: MinimizeWin(W);
  CM_MAXIMIZE: MaximizeWin(W);
  CM_CLOSE: CloseWindow(W);
 Else If Cmd>=1000 Then AppSysCmd(W,Cmd);
 End;
End;

Function SizeMode(W: PWindow; PX,PY: Integer): Integer;
Var M: Integer;
Begin
 M:=0;
 If PX<W^.X+Bdr+TITLE_H Then M:=M Or 1;
 If PX>W^.X+W^.W-Bdr-TITLE_H-1 Then M:=M Or 2;
 If PY<W^.Y+Bdr+TITLE_H Then M:=M Or 4;
 If PY>W^.Y+W^.H-Bdr-TITLE_H-1 Then M:=M Or 8;
 { au milieu d'un bord : un seul sens }
 If (PX>=W^.X+Bdr) And (PX<W^.X+W^.W-Bdr) Then M:=M And (4+8);
 If (PY>=W^.Y+Bdr) And (PY<W^.Y+W^.H-Bdr) Then M:=M And (1+2);
 If (PX<W^.X+Bdr) And (PY>=W^.Y+Bdr+TITLE_H) And (PY<W^.Y+W^.H-Bdr-TITLE_H) Then M:=1;
 If (PX>=W^.X+W^.W-Bdr) And (PY>=W^.Y+Bdr+TITLE_H) And (PY<W^.Y+W^.H-Bdr-TITLE_H) Then M:=2;
 If (PY<W^.Y+Bdr) And (PX>=W^.X+Bdr+TITLE_H) And (PX<W^.X+W^.W-Bdr-TITLE_H) Then M:=4;
 If (PY>=W^.Y+W^.H-Bdr) And (PX>=W^.X+Bdr+TITLE_H) And (PX<W^.X+W^.W-Bdr-TITLE_H) Then M:=8;
 If M=0 Then M:=10;
 SizeMode:=M;
End;

{ Defilement : retourne True si la position a change }
Procedure ScrollClick(W: PWindow; Vert: Boolean);
Var A1,B1,A2,B2,C1,D1,C2,D2,X1,Y1,X2,Y2: Integer; Part: Integer; E: TEvent;
    Tot,Pg,Pos: LongInt; Grab: LongInt; T1,T2: Integer; Dragging: Boolean;
    LastT: LongInt;
Begin
 WinScrollRects(W,A1,B1,A2,B2,C1,D1,C2,D2);
 If Vert Then Begin X1:=A1;Y1:=B1;X2:=A2;Y2:=B2;Tot:=W^.VTot;Pg:=W^.VPage;Pos:=W^.VPos;End
 Else Begin X1:=C1;Y1:=D1;X2:=C2;Y2:=D2;Tot:=W^.HTot;Pg:=W^.HPage;Pos:=W^.HPos;End;
 Dragging:=False;Grab:=0;LastT:=0;
 Repeat
  If Vert Then Pos:=W^.VPos Else Pos:=W^.HPos;
  If Not Dragging Then Begin
   Part:=ScrollPart(Vert,X1,Y1,X2,Y2,Tot,Pg,Pos,MX,MY);
   Case Part Of
    1: Dec(Pos);
    2: Inc(Pos);
    3: Dec(Pos,Pg-1);
    4: Inc(Pos,Pg-1);
    5: Begin
        ScrollThumb(IfThen_(Vert,Y1,X1)+SB,IfThen_(Vert,Y2,X2)-SB,Tot,Pg,Pos,T1,T2);
        If Vert Then Grab:=MY-T1 Else Grab:=MX-T1;
        Dragging:=True;
       End;
   End;
  End Else Begin
   If Vert Then Pos:=ScrollDrag(True,X1,Y1,X2,Y2,Tot,Pg,MY,Grab)
   Else Pos:=ScrollDrag(False,X1,Y1,X2,Y2,Tot,Pg,MX,Grab);
  End;
  If Pos>Tot-Pg Then Pos:=Tot-Pg;
  If Pos<0 Then Pos:=0;
  AppScroll(W,Vert,Part,Pos);
  RedrawAll;
  If Not Dragging Then Delay(60);
  PollEvent(E);
 Until (MB And 1)=0;
End;

Procedure MenuClick(W: PWindow; PX: Integer);
Var I,M,Cmd: Integer;
Begin
 M:=0;
 For I:=1 To W^.NMenu Do
  If (PX>=MenuTitleX(W,I)-6) And (PX<MenuTitleX(W,I)+MenuTitleW(W,I)-6) Then M:=I;
 If M=0 Then Exit;
 Cmd:=RunMenus(W,M,False);
 Dirty:=True;
 If Cmd<>0 Then AppMenu(W,Cmd);
End;

{ deplacement d'une icone a la souris }
Procedure IconDrag(W: PWindow);
Var Sc: TScreenSave; E: TEvent; X,Y,GX,GY: Integer; Done,Ok: Boolean;
Begin
 GX:=MX-W^.IconX;GY:=MY-W^.IconY;X:=W^.IconX;Y:=W^.IconY;
 HideMouse;SaveScreen(Sc);DrawOutline(X-4,Y-2,ICON_W+1,ICON_H+3);ShowMouse;
 Done:=False;Ok:=False;
 Repeat
  PollEvent(E);
  If E.Kind=EV_MOVE Then Begin
   X:=Clamp(E.X-GX,4,SCR_W-ICON_W);Y:=Clamp(E.Y-GY,40,SCR_H-ICON_H-2);
   HideMouse;PutScreen(Sc);DrawOutline(X-4,Y-2,ICON_W+1,ICON_H+3);ShowMouse;
  End;
  If E.Kind=EV_KEY Then Begin
   Case E.Key Of
    K_ESC: Done:=True;
    K_ENTER: Begin Done:=True;Ok:=True;End;
    K_LEFT: Dec(X,8);K_RIGHT: Inc(X,8);K_UP: Dec(Y,8);K_DOWN: Inc(Y,8);
   End;
   If Not Done Then Begin HideMouse;PutScreen(Sc);DrawOutline(X-4,Y-2,ICON_W+1,ICON_H+3);ShowMouse;End;
  End;
  If E.Kind=EV_UP Then Begin Done:=True;Ok:=True;End;
 Until Done;
 HideMouse;PutScreen(Sc);FreeScreen(Sc);ShowMouse;
 If Ok Then Begin W^.IconX:=Clamp(X,4,SCR_W-ICON_W);W^.IconY:=Clamp(Y,40,SCR_H-ICON_H-2);W^.IconFixed:=True;End;
 Dirty:=True;
End;

Procedure HandleDown(Var E: TEvent);
Var W,A: PWindow; Part,Cmd: Integer; Md: Integer; X0,Y0,SX,SY,SW,SH: Integer; Mv: Boolean; E2: TEvent;
Begin
 W:=WinAt(E.X,E.Y,Part);
 If W=Nil Then Exit;
 A:=ActiveWin;
 If Part=HT_ICON Then Begin
  If E.Dbl Then Begin SelIcon:=Nil;RestoreWin(W);RedrawAll;End
  Else Begin
   SelIcon:=W;Dirty:=True;RedrawAll;
   { clic simple : menu Systeme de l'icone ; glissement : deplacement }
   X0:=E.X;Y0:=E.Y;Mv:=False;
   Repeat
    PollEvent(E2);
    If (E2.Kind=EV_MOVE) And ((Abs(E2.X-X0)>3) Or (Abs(E2.Y-Y0)>3)) Then Mv:=True;
   Until (E2.Kind=EV_UP) Or Mv;
   If Mv Then Begin MX:=X0;MY:=Y0;IconDrag(W);End
   Else Begin
    SX:=W^.X;SY:=W^.Y;SW:=W^.W;SH:=W^.H;
    W^.X:=W^.IconX-4;W^.Y:=Max2(20,W^.IconY-118);
    Cmd:=RunMenus(W,1,True);
    W^.X:=SX;W^.Y:=SY;W^.W:=SW;W^.H:=SH;
    If Cmd<>0 Then DoSysCmd(W,Cmd);
   End;
  End;
  Dirty:=True;
  Exit;
 End;
 If W<>A Then Begin BringToFront(W);RedrawAll;End;
 Case Part Of
  HT_TITLE: Begin
    If E.Dbl And W^.Sizable Then Begin
     If W^.State=2 Then RestoreWin(W) Else MaximizeWin(W);
    End Else If W^.State=0 Then OutlineOp(W,0,False);
   End;
  HT_SYS: Begin
    If E.Dbl Then CloseWindow(W)
    Else Begin
     Cmd:=RunMenus(W,1,True);
     If Cmd<>0 Then DoSysCmd(W,Cmd);
    End;
   End;
  HT_MIN: MinimizeWin(W);
  HT_MAX: If W^.State=2 Then RestoreWin(W) Else MaximizeWin(W);
  HT_MENU: MenuClick(W,E.X);
  HT_VSB: ScrollClick(W,True);
  HT_HSB: ScrollClick(W,False);
  HT_SIZE: Begin
    Md:=SizeMode(W,E.X,E.Y);
    OutlineOp(W,Md,False);
   End;
  HT_CLIENT: AppMouse(W,E);
 End;
 Dirty:=True;
End;

Procedure CycleWindows;
Var I: Integer; W: PWindow;
Begin
 If NWins<2 Then Exit;
 W:=Wins[1];
 For I:=1 To NWins Do
  If Wins[I]^.State<>1 Then Begin W:=Wins[I];Break;End;
 BringToFront(W);
 If W^.State=1 Then RestoreWin(W);
 Dirty:=True;
End;

Procedure HandleKey(K: Word);
Var W: PWindow; Ch: Char; I: Integer; Cmd: Integer;
Begin
 W:=ActiveWin;;
 If K=K_ALTF4 Then Begin If W<>Nil Then CloseWindow(W);Exit;End;
 If K=366 Then Begin If W<>Nil Then DoSysCmd(W,CM_MOVE);Exit;End;   { Alt+F7 }
 If K=367 Then Begin If W<>Nil Then DoSysCmd(W,CM_SIZE);Exit;End;   { Alt+F8 }
 If K=364 Then Begin If W<>Nil Then DoSysCmd(W,CM_RESTORE);Exit;End;   { Alt+F5 }
 If K=365 Then Begin CycleWindows;Exit;End;                              { Alt+F6 : fenetre suivante }
 If K=368 Then Begin If W<>Nil Then DoSysCmd(W,CM_MINIMIZE);Exit;End; { Alt+F9 }
 If K=369 Then Begin If W<>Nil Then DoSysCmd(W,CM_MAXIMIZE);Exit;End; { Alt+F10 }
 If (K=K_F6) Or (K=421) Or (K=420) Then Begin CycleWindows;Exit;End;
 If W=Nil Then Exit;
 If (K=K_F10) And (W^.NMenu>0) Then Begin
  MenuKbd:=True;
  Cmd:=RunMenus(W,1,False);Dirty:=True;
  If Cmd=CM_OPENSYS Then Begin MenuKbd:=True;Cmd:=RunMenus(W,1,True);Dirty:=True;If Cmd<>0 Then DoSysCmd(W,Cmd);Exit;End;
  If Cmd<>0 Then AppMenu(W,Cmd);
  Exit;
 End;
 Ch:=AltLetter(K);
 If (Ch<>#0) And (W^.NMenu>0) Then Begin
  For I:=1 To W^.NMenu Do
   If MnemoOf(TL(W^.Menus[I].Title))=Ch Then Begin
    MenuKbd:=True;
    Cmd:=RunMenus(W,I,False);Dirty:=True;
    If Cmd=CM_OPENSYS Then Begin MenuKbd:=True;Cmd:=RunMenus(W,1,True);Dirty:=True;If Cmd<>0 Then DoSysCmd(W,Cmd);Exit;End;
    If Cmd<>0 Then AppMenu(W,Cmd);
    Exit;
   End;
 End;
 AppKey(W,K);
End;

{ ====================================================================== }
{                         BOUCLE PRINCIPALE                              }
{ ====================================================================== }

Var LastTimer: LongInt;

Procedure W16Pump; Forward;

Procedure DesktopTick;
Var I,N: Integer; Snap: Array[1..MAXWIN] Of PWindow;
Begin
 N:=NWins;
 For I:=1 To N Do Snap[I]:=Wins[I];
 For I:=N DownTo 1 Do
  If WinIndex(Snap[I])>0 Then AppTimer(Snap[I]);
 W16Pump;
End;

{ forme du pointeur selon la zone survolee }
Procedure UpdateCursorKind;
Var W: PWindow; Part,Md,K: Integer;
Begin
 K:=0;
 W:=WinAt(MX,MY,Part);
 If (W<>Nil) And (Capture=Nil) Then Begin
  Case Part Of
   HT_SIZE: Begin
     Md:=SizeMode(W,MX,MY);
     If ((Md And 3)<>0) And ((Md And 12)=0) Then K:=2
     Else If ((Md And 12)<>0) And ((Md And 3)=0) Then K:=3
     Else If ((Md=5) Or (Md=10)) Then K:=4
     Else K:=5;
    End;
   HT_CLIENT: If (W^.App=A_NOTE) Or (W^.App=A_WRITE) Or (W^.App=A_TERM) Then K:=1;
  End;
 End;
 If K<>CurKind Then Begin
  SetCurKind(K);
  If CurSaved Then CursorDraw(MX,MY);
 End;
End;

Procedure DesktopLoop;
Var E: TEvent; HitW: PWindow; HitP: Integer;
Begin
 Dirty:=True;DirtyTop:=False;
 Repeat
  If Dirty Then Begin RedrawAll;DirtyTop:=False;End
  Else If DirtyTop Then Begin
   HideMouse;
   If ActiveWin<>Nil Then DrawWindow(ActiveWin,True);
   ShowMouse;
   DirtyTop:=False;
  End;
  PollEvent(E);
  UpdateCursorKind;
  DesktopTick;
  Case E.Kind Of
   EV_DOWN: HandleDown(E);
   EV_RDOWN: Begin
      HitW:=WinAt(E.X,E.Y,HitP);
      If (HitW<>Nil) And (HitP=HT_CLIENT) Then Begin
       If HitW<>ActiveWin Then BringToFront(HitW);
       AppMouse(HitW,E);Dirty:=True;
      End;
     End;
   EV_MOVE,EV_UP: If Capture<>Nil Then Begin
      AppMouse(Capture,E);
      If E.Kind=EV_UP Then Capture:=Nil;
     End;
   EV_KEY: HandleKey(E.Key);
  End;
  If (E.Kind=EV_UP) And (Capture<>Nil) Then Capture:=Nil;
 Until QuitFlag Or (NWins=0);
End;

{ ====================================================================== }
{          MS-DOS EXECUTIVE : GESTIONNAIRE DE FICHIERS                   }
{ ====================================================================== }

Const
 CM_X_RUN=101; CM_X_LOAD=102; CM_X_COPY=103; CM_X_INFO=104; CM_X_DEL=105;
 CM_X_PRINT=106; CM_X_REN=107; CM_X_EXIT=108; CM_X_ABOUT=109;
 CM_X_SHORT=111; CM_X_LONG=112; CM_X_ALL=113; CM_X_PART=114; CM_X_PROG=115;
 CM_X_BYNAME=116; CM_X_BYDATE=117; CM_X_BYSIZE=118; CM_X_BYKIND=119;
 CM_X_ENDSES=121; CM_X_MKDIR=122; CM_X_CHDIR=123; CM_X_FORMAT=124;
 CM_X_SYSDISK=125; CM_X_VOLNAME=126;
 MAXF = 400;

Type
 TFileEnt = Record
  Name : String[40];      { nom reel }
  Disp : String[40];      { nom affiche }
  Size : LongInt;
  Time : LongInt;
  IsDir: Boolean;
  Virt : Boolean;
  Mark : Boolean;         { selection etendue }
 End;
 PFileArr = ^TFileArr;
 TFileArr = Array[1..MAXF] Of TFileEnt;

 PExec = ^TExec;
 TExec = Record
  Dir   : String[100];
  N     : Integer;
  F     : PFileArr;
  Sel   : Integer;
  Long_ : Boolean;
  Filter: Integer;         { 0 tous, 1 partiel, 2 programmes }
  Sort  : Integer;         { 0 nom, 1 date, 2 taille, 3 type }
  Mask  : String[20];
  Rows  : Integer;
  ColW  : Integer;
  Cols  : Integer;
  Ext   : Boolean;         { mode extension de selection (F8) }
  Anc   : Integer;         { ancre de la selection par bloc }
  Nof   : Boolean;         { aucune selection (Espace) }
 End;

Var
 VolNames : Array['A'..'D'] Of String[12];

Const
 NBUILTIN = 17;
 BuiltName : Array[1..NBUILTIN] Of String[12] = (
  'CALC.EXE','CALENDAR.EXE','CARDFILE.EXE','CLIPBRD.EXE','CLOCK.EXE',
  'CONTROL.EXE','MSDOS.EXE','NOTEPAD.EXE','PAINT.EXE','PIFEDIT.EXE',
  'REVERSI.EXE','SPOOLER.EXE','TERMINAL.EXE','WRITE.EXE','WIN.COM','WINOLDAP.GRB','COMMAND.COM');
 BuiltApp : Array[1..NBUILTIN] Of Integer = (
  A_CALC,A_CALEN,A_CARD,A_CLIP,A_CLOCK,A_CTRL,A_EXEC,A_NOTE,A_PAINT,A_PIF,
  A_REV,A_SPOOL,A_TERM,A_WRITE,0,0,A_DOSBOX);
 BuiltSize : Array[1..NBUILTIN] Of LongInt = (
  16784,59872,41360,6416,10640,64864,3584,32592,168672,39744,42240,
  11760,67040,162272,3696,25360,25308);

Procedure IniWrite(Const Fn,Sec,Key,Val_: String); Forward;
Function Launch(App: Integer; Const Arg: String): PWindow; Forward;
Procedure RunFile(Const Path,Args: String; AsIcon: Boolean); Forward;
Procedure ShowAboutMs(Const AppName: String; Ico: Integer; Free: Boolean); Forward;


{ ajoute un travail a la file d'attente ; lance le Spooler (en icone) s'il n'est pas actif }
Function SpoolAdd(Const Job: String): Boolean;
Var W: PWindow; Fn: String;
Begin
 SpoolAdd:=False;
 If NPrn=0 Then Begin
  InfoBox(T3('Cannot print.|No printer is installed.','Impression impossible.|Aucune imprimante install'#130'e.','Drucken nicht m'#148'glich.|Kein Drucker installiert.'));
  Exit;
 End;
 If SpoolN>=8 Then Begin
  InfoBox(T3('Cannot print.|The print queue is full.','Impression impossible.|La file d''attente est pleine.','Drucken nicht m'#148'glich.|Warteschlange voll.'));
  Exit;
 End;
 Fn:=PrintPort;
 If Fn='FILE' Then Begin
  Fn:=PrnFileName;If Fn='' Then Fn:='OUTPUT.PRN';
  If Not InputBox(T3('Print to file (name):','Imprimer dans le fichier (nom) :','In Datei drucken (Name):'),Fn,40,320) Then Begin SpoolSrcNext:='';Exit;End;
  If Trim(Fn)='' Then Begin SpoolSrcNext:='';Exit;End;
  PrnFileName:=Trim(Fn);Fn:=PrnFileName;
 End;
 Inc(SpoolN);SpoolNames[SpoolN]:=Copy(Job,1,40);
 SpoolPort[SpoolN]:=Fn;SpoolPrn[SpoolN]:=PrinterName;SpoolSrc[SpoolN]:=SpoolSrcNext;SpoolSrcNext:='';
 If SpoolN=1 Then SpoolT0:=NowCs;
 If CountApp(A_SPOOL)=0 Then Begin
  W:=Launch(A_SPOOL,'');
  If W<>Nil Then MinimizeWin(W);
 End;
 SpoolAdd:=True;
End;

Function IsProgExt(Const E: String): Boolean;
Begin
 IsProgExt:=(E='.EXE') Or (E='.COM') Or (E='.BAT');
End;

Function BuiltIndex(Const Nm: String): Integer;
Var I: Integer; U: String;
Begin
 U:=Upper(BaseName(Nm));
 BuiltIndex:=0;
 For I:=1 To NBUILTIN Do If BuiltName[I]=U Then BuiltIndex:=I;
End;

Function DosDateOf(T: LongInt): String;
Var DT: DateTime;
Begin
 UnpackTime(T,DT);
 DosDateOf:=DateStr(DT.Year,DT.Month,DT.Day);
End;

Function DosTimeOf(T: LongInt): String;
Var DT: DateTime;
Begin
 UnpackTime(T,DT);
 DosTimeOf:=TimeStr(DT.Hour,DT.Min,-1);
End;

Function SortKey(Const A,B: TFileEnt; Mode: Integer): Boolean; { A avant B ? }
Var EA,EB: String;
Begin
 If A.IsDir<>B.IsDir Then Begin SortKey:=A.IsDir;Exit;End;
 Case Mode Of
  1: If A.Time<>B.Time Then Begin SortKey:=A.Time>B.Time;Exit;End;
  2: If A.Size<>B.Size Then Begin SortKey:=A.Size>B.Size;Exit;End;
  3: Begin
      EA:=ExtOf(A.Disp);EB:=ExtOf(B.Disp);
      If EA<>EB Then Begin SortKey:=EA<EB;Exit;End;
     End;
 End;
 SortKey:=A.Disp<=B.Disp;
End;

Procedure ExecSort(X: PExec);
Var I,J: Integer; T: TFileEnt;
Begin
 For I:=2 To X^.N Do Begin
  T:=X^.F^[I];J:=I-1;
  While (J>=1) And (Not SortKey(X^.F^[J],T,X^.Sort)) Do Begin
   X^.F^[J+1]:=X^.F^[J];Dec(J);
  End;
  X^.F^[J+1]:=T;
 End;
End;

Procedure AddEnt(X: PExec; Const Nm: String; Sz,Tm: LongInt; IsD,Vt: Boolean);
Var K: Integer; U: String;
Begin
 If X^.N>=MAXF Then Exit;
 U:=Upper(Nm);
 If Not IsD Then Begin
  If (X^.Filter=1) And Not WildMatch(X^.Mask,U) Then Exit;
  If (X^.Filter=2) And Not IsProgExt(ExtOf(U)) Then Exit;
 End;
 For K:=1 To X^.N Do If X^.F^[K].Disp=U Then Exit;
 Inc(X^.N);
 X^.F^[X^.N].Name:=Nm;X^.F^[X^.N].Disp:=U;X^.F^[X^.N].Size:=Sz;
 X^.F^[X^.N].Time:=Tm;X^.F^[X^.N].IsDir:=IsD;X^.F^[X^.N].Virt:=Vt;X^.F^[X^.N].Mark:=False;
End;

Procedure ExecRead(W: PWindow);
Var X: PExec; SR: SearchRec; I: Integer; Tm: LongInt; DT: DateTime; H,Mi,S,Cs,Y,Mo,D,Dw: Word;
Begin
 X:=W^.Data;
 X^.N:=0;
 FindFirst(JoinPath(V2R(X^.Dir),'*'),AnyFile,SR);
 While DosError=0 Do Begin
  If (SR.Name<>'.') And (SR.Name<>'..') And (SR.Name[1]<>'.') Then Begin
   If (SR.Attr And Directory)<>0 Then AddEnt(X,SR.Name,0,SR.Time,True,False)
   Else If (SR.Attr And (VolumeID))=0 Then AddEnt(X,SR.Name,SR.Size,SR.Time,False,False);
  End;
  FindNext(SR);
 End;
 {$IFDEF FPC}FindClose(SR);{$ENDIF}
 If Upper(X^.Dir)='C:\WINDOWS' Then Begin
  GetDate(Y,Mo,D,Dw);
  DT.Year:=1987;DT.Month:=11;DT.Day:=10;DT.Hour:=12;DT.Min:=0;DT.Sec:=0;
  PackTime(DT,Tm);
  For I:=1 To NBUILTIN Do AddEnt(X,BuiltName[I],BuiltSize[I],Tm,False,True);
  AddEnt(X,'PIF',0,Tm,True,True);
 End;
 ExecSort(X);
 If X^.Sel>X^.N Then X^.Sel:=X^.N;
 If (X^.Sel<1) And (X^.N>0) Then X^.Sel:=1;
End;

Procedure ExecLayout(W: PWindow);
Var X: PExec; X1,Y1,X2,Y2,I,L,MaxL,AW,AH: Integer;
Begin
 X:=W^.Data;
 W^.HasVS:=False;W^.HasHS:=False;
 WinClient(W,X1,Y1,X2,Y2);
 AW:=X2-X1+1;AH:=Y2-Y1+1-26;
 If X^.Long_ Then Begin
  W^.HasVS:=True;
  WinClient(W,X1,Y1,X2,Y2);
  AH:=Y2-Y1+1-26;
  X^.Rows:=Max2(1,AH Div 12);
  W^.VTot:=X^.N;W^.VPage:=X^.Rows;
  If W^.VPos>W^.VTot-W^.VPage Then W^.VPos:=Max2(0,W^.VTot-W^.VPage);
 End Else Begin
  MaxL:=8;
  For I:=1 To X^.N Do Begin L:=Length(X^.F^[I].Disp);If L>MaxL Then MaxL:=L;End;
  X^.ColW:=(MaxL+2)*8;
  X^.Rows:=Max2(1,AH Div 12);
  X^.Cols:=(X^.N+X^.Rows-1) Div X^.Rows;
  If X^.Cols*X^.ColW>AW Then Begin
   W^.HasHS:=True;
   WinClient(W,X1,Y1,X2,Y2);
   AH:=Y2-Y1+1-26;AW:=X2-X1+1;
   X^.Rows:=Max2(1,AH Div 12);
   X^.Cols:=(X^.N+X^.Rows-1) Div X^.Rows;
   W^.HTot:=X^.Cols;
   W^.HPage:=Max2(1,AW Div X^.ColW);
   If W^.HPos>W^.HTot-W^.HPage Then W^.HPos:=Max2(0,W^.HTot-W^.HPage);
  End Else W^.HPos:=0;
 End;
End;

Procedure ExecRefresh(W: PWindow);
Begin
 ExecRead(W);
 ExecLayout(W);
 Dirty:=True;
End;

Procedure ExecEnsure(W: PWindow);
Var X: PExec; C,R: Integer;
Begin
 X:=W^.Data;
 If X^.Sel<1 Then Exit;
 If X^.Long_ Then Begin
  If X^.Sel-1<W^.VPos Then W^.VPos:=X^.Sel-1;
  If X^.Sel>W^.VPos+X^.Rows Then W^.VPos:=X^.Sel-X^.Rows;
 End Else If W^.HasHS Then Begin
  C:=(X^.Sel-1) Div X^.Rows;
  If C<W^.HPos Then W^.HPos:=C;
  If C>=W^.HPos+W^.HPage Then W^.HPos:=C-W^.HPage+1;
 End;
End;

Procedure ExecDrives(W: PWindow; Var DX: Array Of Integer);
Begin
End;


{ ---- selection multiple ---- }
Function ExecMarks(X: PExec): Integer;
Var I,C: Integer;
Begin
 C:=0;
 For I:=1 To X^.N Do If X^.F^[I].Mark Then Inc(C);
 ExecMarks:=C;
End;

Function ExecIsSel(X: PExec; I: Integer): Boolean;
Begin
 If ExecMarks(X)>0 Then ExecIsSel:=X^.F^[I].Mark
 Else ExecIsSel:=(I=X^.Sel) And Not X^.Nof;
End;

Procedure ExecClearMarks(X: PExec);
Var I: Integer;
Begin
 For I:=1 To X^.N Do X^.F^[I].Mark:=False;
 X^.Ext:=False;X^.Nof:=False;
End;

{ liste des indices selectionnes }
Function ExecSelected(X: PExec; Var Idx: Array Of Integer): Integer;
Var I,C: Integer;
Begin
 C:=0;
 For I:=1 To X^.N Do If ExecIsSel(X,I) And (C<=High(Idx)) Then Begin Idx[C]:=I;Inc(C);End;
 ExecSelected:=C;
End;

Procedure ExecMarkRange(X: PExec);
Var I,A,B: Integer;
Begin
 For I:=1 To X^.N Do X^.F^[I].Mark:=False;
 A:=Min2(X^.Anc,X^.Sel);B:=Max2(X^.Anc,X^.Sel);
 For I:=A To B Do X^.F^[I].Mark:=True;
End;

Procedure ExecBold(X,Y: Integer; Const T: String; Bold,Inv: Boolean);
Begin
 GText(X,Y,T,IfThen_(Inv,cWht,cBlk));
 If Bold Then GText(X+1,Y,T,IfThen_(Inv,cWht,cBlk));
End;

Procedure ExecDraw(W: PWindow);
Var X: PExec; X1,Y1,X2,Y2,I,J,Cc,Rr,PX,PY,Idx,TX,P: Integer; L: Char; T,Ln,Bs,Ex: String;
    Sel: Boolean; Cur: Char; Vn: String; Sx: Integer;
Begin
 X:=W^.Data;
 WinClient(W,X1,Y1,X2,Y2);
 { rangee des lecteurs }
 Cur:=UpCase(X^.Dir[1]);
 TX:=X1+6;
 For L:='A' To 'C' Do Begin
  GText(TX,Y1+8,L,cBlk);
  If L=Cur Then Begin
   GRoundFill(TX+12,Y1+4,TX+12+36,Y1+18,cBlk,cBlk);
   GBar(TX+17,Y1+10,TX+43,Y1+12,cWht);
  End Else Begin
   GRoundFill(TX+12,Y1+4,TX+12+36,Y1+18,cBlk,cWht);
   GBar(TX+17,Y1+10,TX+43,Y1+12,cBlk);
  End;
  Inc(TX,64);
 End;
 { chemin : lecteur, nom de volume, repertoire }
 T:=X^.Dir;
 Vn:='';
 If (Cur>='A') And (Cur<='D') Then Vn:=VolNames[Cur];
 If (Length(T)>=2) And (T[2]=':') Then T:=Copy(T,1,2)+Vn+' '+Copy(T,3,200);
 GText(TX,Y1+8,T,cBlk);
 GHLine(X1,X2,Y1+23,cBlk);
 PY:=Y1+26;
 If X^.Long_ Then Begin
  For I:=0 To X^.Rows-1 Do Begin
   Idx:=W^.VPos+I+1;
   If Idx>X^.N Then Break;
   Sel:=ExecIsSel(X,Idx);
   If Sel Then GBar(X1+2,PY+I*12-1,X2-2,PY+I*12+9,cBlk);
   With X^.F^[Idx] Do Begin
    P:=Pos('.',Disp);
    If P>0 Then Begin Bs:=Copy(Disp,1,P-1);Ex:=Copy(Disp,P+1,3);End Else Begin Bs:=Disp;Ex:='';End;
    Sx:=X1+4;
    ExecBold(Sx,PY+I*12,Bs,((X^.Sort=0) Or IsDir) And True,Sel);
    ExecBold(Sx+80,PY+I*12,Ex,X^.Sort=3,Sel);
    If IsDir Then ExecBold(Sx+128,PY+I*12,'    <DIR>',False,Sel)
    Else ExecBold(Sx+128,PY+I*12,PadL(IntStr(Size),9),X^.Sort=2,Sel);
    ExecBold(Sx+216,PY+I*12,DosDateOf(Time),X^.Sort=1,Sel);
    ExecBold(Sx+312,PY+I*12,DosTimeOf(Time),X^.Sort=1,Sel);
   End;
   If (Idx=X^.Sel) And (ExecMarks(X)>0) Then Begin
    For J:=X1+2 To X2-2 Do If (J And 1)=0 Then Begin GPix(J,PY+I*12-1,cWht);GPix(J,PY+I*12+9,cWht);End;
   End;
  End;
 End Else Begin
  For I:=1 To X^.N Do Begin
   Cc:=(I-1) Div X^.Rows-W^.HPos;Rr:=(I-1) Mod X^.Rows;
   If (Cc<0) Then Continue;
   PX:=X1+6+Cc*X^.ColW;
   If PX>X2 Then Break;
   Sel:=ExecIsSel(X,I);
   T:=X^.F^[I].Disp;
   If Sel Then GBar(PX-2,PY+Rr*12-1,PX+Length(T)*8+1,PY+Rr*12+9,cBlk);
   If Sel Then GText(PX,PY+Rr*12,T,cWht) Else GText(PX,PY+Rr*12,T,cBlk);
   If X^.F^[I].IsDir And Not Sel Then GText(PX+1,PY+Rr*12,T,cBlk);
   If (I=X^.Sel) And (ExecMarks(X)>0) Then Begin
    For J:=PX-2 To PX+Length(T)*8+1 Do If (J And 1)=0 Then Begin GPix(J,PY+Rr*12-1,cBlk);GPix(J,PY+Rr*12+9,cBlk);End;
    For J:=PY+Rr*12-1 To PY+Rr*12+9 Do If (J And 1)=0 Then Begin GPix(PX-2,J,cBlk);GPix(PX+Length(T)*8+1,J,cBlk);End;
   End;
  End;
 End;
End;

Procedure ExecPrepare(W: PWindow);
Var X: PExec;
Begin
 X:=W^.Data;
 MenuCheck(W,CM_X_SHORT,Not X^.Long_);MenuCheck(W,CM_X_LONG,X^.Long_);
 MenuCheck(W,CM_X_ALL,X^.Filter=0);MenuCheck(W,CM_X_PART,X^.Filter=1);
 MenuCheck(W,CM_X_PROG,X^.Filter=2);
 MenuCheck(W,CM_X_BYNAME,X^.Sort=0);MenuCheck(W,CM_X_BYDATE,X^.Sort=1);
 MenuCheck(W,CM_X_BYSIZE,X^.Sort=2);MenuCheck(W,CM_X_BYKIND,X^.Sort=3);
End;

Function ExecSelPath(W: PWindow): String;
Var X: PExec;
Begin
 X:=W^.Data;
 ExecSelPath:='';
 If (X^.Sel>=1) And (X^.Sel<=X^.N) Then ExecSelPath:=VJoin(X^.Dir,X^.F^[X^.Sel].Disp);
End;

Procedure ExecChangeDir(W: PWindow; Const NewDir: String);
Var X: PExec;
Begin
 X:=W^.Data;
 If Not VDirExists(NewDir) Then Begin
  InfoBox(T3('Invalid directory.','R'#130'pertoire invalide.','Ung'#129'ltiges Verzeichnis.'));
  Exit;
 End;
 X^.Dir:=Upper(NewDir);
 X^.Sel:=1;W^.HPos:=0;W^.VPos:=0;
 W^.Title:='MS-DOS Executive';
 ExecRefresh(W);
End;

Procedure ExecChangeDrive(W: PWindow; L: Char);
Var X: PExec;
Begin
 X:=W^.Data;
 If L='C' Then Begin
  If UpCase(X^.Dir[1])<>'C' Then ExecChangeDir(W,'C:\');
  Exit;
 End;
 {$IFDEF UNIX}
 InfoBox(T3('Drive '+L+': is not ready.','Le lecteur '+L+': n''est pas pr'#136't.',
   'Laufwerk '+L+': ist nicht bereit.'));
 {$ELSE}
 If DiskFree(Ord(L)-64)<0 Then
  InfoBox(T3('Drive '+L+': is not ready.','Le lecteur '+L+': n''est pas pr'#136't.',
   'Laufwerk '+L+': ist nicht bereit.'))
 Else ExecChangeDir(W,L+':\');
 {$ENDIF}
End;

Procedure ExecActivate(W: PWindow; AsIcon: Boolean);
Var X: PExec; P: String; E: String;
Begin
 X:=W^.Data;
 If (X^.Sel<1) Or (X^.Sel>X^.N) Then Exit;
 If X^.F^[X^.Sel].IsDir Then Begin
  ExecChangeDir(W,VJoin(X^.Dir,X^.F^[X^.Sel].Disp));
  Exit;
 End;
 RunFile(ExecSelPath(W),'',AsIcon);
End;

Procedure ExecGoUp(W: PWindow);
Var X: PExec;
Begin
 X:=W^.Data;
 If Length(X^.Dir)>3 Then ExecChangeDir(W,VParent(X^.Dir));
End;

{ Copie d'un fichier reel }
Function CopyFileReal(Const Src,Dst: String): Boolean;
Var F,G: File; Buf: Pointer; N,M: Word; Ok: Boolean;
Begin
 CopyFileReal:=False;
 {$I-}
 Assign(F,Src);Reset(F,1);
 If IOResult<>0 Then Exit;
 Assign(G,Dst);Rewrite(G,1);
 If IOResult<>0 Then Begin Close(F);Exit;End;
 GetMem(Buf,32768);
 Ok:=True;
 Repeat
  BlockRead(F,Buf^,32768,N);
  If N>0 Then Begin BlockWrite(G,Buf^,N,M);If M<>N Then Ok:=False;End;
 Until (N=0) Or (Not Ok);
 FreeMem(Buf,32768);
 Close(F);Close(G);
 {$I+}
 CopyFileReal:=Ok;
End;

Function ExecNames(X: PExec; Const Idx: Array Of Integer; N: Integer): String;
Var I: Integer; R: String;
Begin
 R:='';
 For I:=0 To N-1 Do Begin
  If I>0 Then R:=R+', ';
  R:=R+X^.F^[Idx[I]].Disp;
  If Length(R)>110 Then Begin R:=R+' ...';Break;End;
 End;
 ExecNames:=R;
End;

Function SameFile(Const A,B: String): Boolean;
Begin
 SameFile:=Upper(A)=Upper(B);
End;

Procedure ExecCopy(W: PWindow);
Var X: PExec; S,Dest,Src,D1: String; I,N,K,Ok: Integer; Idx: Array[0..MAXF-1] Of Integer; Lst: Array[0..MAXF-1] Of Integer;
Begin
 X:=W^.Data;
 N:=ExecSelected(X,Idx);
 K:=0;
 For I:=0 To N-1 Do If Not X^.F^[Idx[I]].IsDir And Not X^.F^[Idx[I]].Virt Then Begin Lst[K]:=Idx[I];Inc(K);End;
 If K=0 Then Begin
  InfoBox(T3('Select a file to copy.','S'#130'lectionnez un fichier '#133' copier.',
    'W'#132'hlen Sie eine Datei zum Kopieren.'));Exit;End;
 S:='';
 If Not InputBox(T3('Copy '+ExecNames(X,Lst,K)+'|To:','Copier '+ExecNames(X,Lst,K)+'|Vers :',
    ExecNames(X,Lst,K)+' kopieren|Nach:'),S,70,360) Then Exit;
 S:=Trim(S);
 If S='' Then Exit;
 If (Pos('\',S)=0) And (Pos(':',S)=0) Then Dest:=VJoin(X^.Dir,S) Else Dest:=S;
 If (K>1) And Not VDirExists(Dest) Then Begin
  InfoBox(T3('Cannot copy more than one file|to a single file.','Impossible de copier plusieurs fichiers|vers un seul fichier.',
    'Mehrere Dateien k'#148'nnen nicht in|eine einzelne Datei kopiert werden.'));Exit;
 End;
 Ok:=0;
 For I:=0 To K-1 Do Begin
  Src:=VJoin(X^.Dir,X^.F^[Lst[I]].Disp);
  If VDirExists(Dest) Then D1:=VJoin(Dest,X^.F^[Lst[I]].Disp) Else D1:=Dest;
  If SameFile(V2R(Src),V2R(D1)) Then Begin
   InfoBox(T3('Cannot copy file '+X^.F^[Lst[I]].Disp+' to itself.','Impossible de copier '+X^.F^[Lst[I]].Disp+' sur lui-m'#136'me.',
     X^.F^[Lst[I]].Disp+' kann nicht auf sich selbst kopiert werden.'));
   Continue;
  End;
  If CopyFileReal(V2R(Src),V2R(D1)) Then Inc(Ok)
  Else Begin
   InfoBox(T3('Cannot copy '+X^.F^[Lst[I]].Disp+'.','Impossible de copier '+X^.F^[Lst[I]].Disp+'.',
    X^.F^[Lst[I]].Disp+' kann nicht kopiert werden.'));Break;
  End;
 End;
 ExecRefresh(W);
End;

Procedure ExecInfo(W: PWindow);
Var X: PExec; D: TDlg; R,I,N: Integer; Idx: Array[0..MAXF-1] Of Integer; L: PStrList;
Begin
 X:=W^.Data;
 N:=ExecSelected(X,Idx);
 If N=0 Then Exit;
 New(L);L^.N:=N;
 For I:=0 To N-1 Do With X^.F^[Idx[I]] Do
  L^.S[I+1]:=Copy(PadR(Disp,13)+IfThenS(IsDir,'    <DIR>',PadL(IntStr(Size),9))+' '+DosDateOf(Time)+' '+DosTimeOf(Time),1,44);
 DlgInit(D,T3('Get Info','Informations','Info'),360,150);
 DlgList(D,10,10,10,340,92,L,1);
 DlgButton(D,ID_OK,140,112,80,'OK',True);
 R:=RunDialog(D,@NoHook);
 Dispose(L);
End;

Procedure ExecDelete(W: PWindow);
Var X: PExec; F: File; R,I,N,K: Integer; P: String; Idx: Array[0..MAXF-1] Of Integer; Lst: Array[0..MAXF-1] Of Integer;
Begin
 X:=W^.Data;
 N:=ExecSelected(X,Idx);
 If N=0 Then Exit;
 K:=0;
 For I:=0 To N-1 Do Begin
  If X^.F^[Idx[I]].Virt Then Begin
   InfoBox(T3('This file is part of Windows|and cannot be deleted.',
    'Ce fichier fait partie de Windows|et ne peut '#136'tre supprim'#130'.',
    'Diese Datei ist Teil von Windows|und kann nicht gel'#148'scht werden.'));Exit;
  End;
  Lst[K]:=Idx[I];Inc(K);
 End;
 R:=MsgBox(T3('Delete '+ExecNames(X,Lst,K)+'?','Supprimer '+ExecNames(X,Lst,K)+' ?',
    ExecNames(X,Lst,K)+' l'#148'schen?'),1,2);
 If R<>ID_OK Then Exit;
 For I:=0 To K-1 Do Begin
  P:=V2R(VJoin(X^.Dir,X^.F^[Lst[I]].Disp));
  {$I-}
  If X^.F^[Lst[I]].IsDir Then RmDir(P) Else Begin Assign(F,P);Erase(F);End;
  {$I+}
  If IOResult<>0 Then Begin
   If X^.F^[Lst[I]].IsDir Then
    InfoBox(T3('Directory '+X^.F^[Lst[I]].Disp+' is not empty.','Le r'#130'pertoire '+X^.F^[Lst[I]].Disp+' n''est pas vide.',
      'Verzeichnis '+X^.F^[Lst[I]].Disp+' ist nicht leer.'))
   Else InfoBox(T3('Cannot delete '+X^.F^[Lst[I]].Disp+'.','Impossible de supprimer '+X^.F^[Lst[I]].Disp+'.',
      X^.F^[Lst[I]].Disp+' kann nicht gel'#148'scht werden.'));
   Break;
  End;
 End;
 ExecRefresh(W);
End;

Procedure ExecRename(W: PWindow);
Var X: PExec; F: File; S: String; D: TDlg; R: Integer;
Begin
 X:=W^.Data;
 If (X^.Sel<1) Or X^.F^[X^.Sel].Virt Then Exit;
 S:='';
 DlgInit(D,'',320,100);
 DlgText(D,10,10,T3('Rename ','Renommer ','Umbenennen ')+X^.F^[X^.Sel].Disp);
 DlgText(D,10,32,T3('To:','Vers :','Nach:'));
 DlgEdit(D,10,60,30,240,S,40);
 DlgButton(D,ID_OK,60,66,90,'OK',True);
 DlgButton(D,ID_CANCEL,170,66,90,T3('Cancel','Annuler','Abbrechen'),False);
 R:=RunDialog(D,@NoHook);
 If R<>ID_OK Then Exit;
 S:=Trim(DlgGetText(D,10));
 If S='' Then Exit;
 If FileExists(JoinPath(V2R(X^.Dir),S)) Then Begin
  InfoBox(T3('A file named '+S+' already exists.','Un fichier nomm'#130' '+S+' existe d'#130'j'#133'.','Eine Datei namens '+S+' existiert bereits.'));Exit;
 End;
 {$I-}
 Assign(F,V2R(ExecSelPath(W)));
 Rename(F,JoinPath(V2R(X^.Dir),S));
 {$I+}
 If IOResult<>0 Then InfoBox(T3('Cannot rename.','Renommage impossible.','Umbenennen nicht m'#148'glich.'));
 ExecRefresh(W);
End;

Procedure ExecPrint(W: PWindow);
Var X: PExec; I,N,K: Integer; Idx: Array[0..MAXF-1] Of Integer; Nm: String; R: Integer;
Begin
 X:=W^.Data;
 N:=ExecSelected(X,Idx);
 If N=0 Then Nm:=T3('directory listing '+X^.Dir,'liste du r'#130'pertoire '+X^.Dir,'Verzeichnisliste '+X^.Dir) Else Nm:=ExecNames(X,Idx,N);
 R:=MsgBox(T3('Print '+Nm+'?','Imprimer '+Nm+' ?','Drucken: '+Nm+'?'),1,2);
 If R<>ID_OK Then Exit;
 If N=0 Then SpoolAdd('MS-DOS Executive - '+X^.Dir)
 Else For K:=0 To N-1 Do
  Begin
   If Not X^.F^[Idx[K]].IsDir Then SpoolSrcNext:=Copy(JoinPath(X^.Dir,X^.F^[Idx[K]].Disp),1,80);
   If Not SpoolAdd('MS-DOS Executive - '+X^.F^[Idx[K]].Disp+IfThenS(X^.F^[Idx[K]].IsDir,'\','')) Then Break;
  End;
End;

Procedure ExecRunDlg(W: PWindow; AsIcon: Boolean);
Var X: PExec; S,Prog,Args: String; P: Integer;
Begin
 X:=W^.Data;
 S:='';
 If Not InputBox(IfThenS(AsIcon,T3('Load:','Charger :','Laden:'),T3('Run (file name and parameters):',
    'Ex'#130'cuter (fichier et param'#138'tres) :','Ausf'#129'hren (Datei und Parameter):')),S,70,380) Then Exit;
 S:=Trim(S);
 If S='' Then Exit;
 P:=Pos(' ',S);
 If P>0 Then Begin Prog:=Copy(S,1,P-1);Args:=Trim(Copy(S,P+1,200));End Else Begin Prog:=S;Args:='';End;
 If (Pos('\',Prog)=0) And (Pos(':',Prog)=0) Then Prog:=VJoin(X^.Dir,Prog);
 If (Args<>'') And (Args[1]<>'/') And (Pos('\',Args)=0) And (Pos(':',Args)=0) And ((BuiltIndex(Prog)>0) Or Not IsProgExt(ExtOf(Prog))) Then Args:=VJoin(X^.Dir,Args);
 RunFile(Prog,Args,AsIcon);
End;

Procedure ExecMkDir(W: PWindow);
Var X: PExec; S: String;
Begin
 X:=W^.Data;
 S:='';
 If Not InputBox(T3('Create directory:','Cr'#130'er le r'#130'pertoire :','Verzeichnis erstellen:'),S,40,300) Then Exit;
 {$I-}
 MkDir(JoinPath(V2R(X^.Dir),S));
 {$I+}
 If IOResult<>0 Then InfoBox(T3('Cannot create directory.','Cr'#130'ation impossible.','Erstellen nicht m'#148'glich.'));
 ExecRefresh(W);
End;

Procedure ExecChDirDlg(W: PWindow);
Var X: PExec; S: String;
Begin
 X:=W^.Data;
 S:=X^.Dir;
 If Not InputBox(T3('Change to directory:','Aller au r'#130'pertoire :','Wechseln zu Verzeichnis:'),S,70,360) Then Exit;
 If (Length(S)<2) Or (S[2]<>':') Then Begin
  If S[1]='\' Then S:=Copy(X^.Dir,1,2)+S Else S:=VJoin(X^.Dir,S);
 End;
 ExecChangeDir(W,S);
End;

Procedure ExecPartial(W: PWindow);
Var X: PExec; S: String;
Begin
 X:=W^.Data;
 S:=X^.Mask;If S='' Then S:='*.*';
 If InputBox(T3('Show files matching:','Afficher les fichiers :','Dateien anzeigen:'),S,20,300) Then Begin
  X^.Mask:=S;X^.Filter:=1;ExecRefresh(W);
 End;
End;

{ Format Data Disk / Make System Disk : choix du lecteur puis confirmation }
Procedure ExecDiskTool(SysDisk: Boolean);
Var D: TDlg; R: Integer; Dr: Char;
Begin
 DlgInit(D,IfThenS(SysDisk,T3('Make System Disk','Disquette syst'#138'me','Systemdiskette'),T3('Format Data Disk','Formater une disquette','Datendiskette formatieren')),260,130);
 DlgText(D,10,8,T3('Select drive to '+IfThenS(SysDisk,'make system disk:','format:'),
   'Choisissez le lecteur '#133' '+IfThenS(SysDisk,'rendre amor'#135'able :','formater :'),'Laufwerk w'#132'hlen:'));
 DlgRadio(D,10,20,30,1,'A:',True);
 DlgRadio(D,11,70,30,1,'B:',False);
 DlgButton(D,ID_OK,40,90,80,'OK',True);
 DlgButton(D,ID_CANCEL,140,90,80,T3('Cancel','Annuler','Abbrechen'),False);
 R:=RunDialog(D,@NoHook);
 If R<>ID_OK Then Exit;
 If DlgGetVal(D,11)=1 Then Dr:='B' Else Dr:='A';
 If MsgBox(T3('This will '+IfThenS(SysDisk,'put the DOS system on','erase all data on')+' drive '+Dr+':.|Insert the diskette and choose OK.',
    IfThenS(SysDisk,'Le syst'#138'me DOS va '#136'tre copi'#130' sur','Toutes les donn'#130'es du lecteur')+' '+Dr+': '+IfThenS(SysDisk,'.','vont '#136'tre effac'#130'es.')+'|Ins'#130'rez la disquette puis choisissez OK.',
    IfThenS(SysDisk,'DOS wird auf Laufwerk ','Alle Daten auf Laufwerk ')+Dr+IfThenS(SysDisk,': kopiert.',': werden gel'#148'scht.')+'|Diskette einlegen und OK w'#132'hlen.'),1,2)<>ID_OK Then Exit;
 { aucun lecteur de disquette physique accessible }
 InfoBox(IfThenS(SysDisk,T3('Cannot put DOS system on the diskette.','Impossible de copier le syst'#138'me DOS sur la disquette.','DOS kann nicht auf die Diskette kopiert werden.'),
   T3('Cannot format diskette in drive '+Dr+':.','Impossible de formater la disquette du lecteur '+Dr+': .','Diskette in Laufwerk '+Dr+': kann nicht formatiert werden.')));
End;

Procedure ExecEndSession; Forward;

Procedure ExecMenu(W: PWindow; Cmd: Integer);
Var X: PExec; S: String; R: Integer;
Begin
 X:=W^.Data;
 Case Cmd Of
  CM_X_RUN: ExecRunDlg(W,False);
  CM_X_LOAD: ExecRunDlg(W,True);
  CM_X_COPY: ExecCopy(W);
  CM_X_INFO: ExecInfo(W);
  CM_X_DEL: ExecDelete(W);
  CM_X_PRINT: ExecPrint(W);
  CM_X_REN: ExecRename(W);
  CM_X_ENDSES: ExecEndSession;
  CM_X_EXIT: If CountApp(A_EXEC)>1 Then CloseWindow(W) Else ExecEndSession;
  CM_X_ABOUT: ShowAboutMs('MS-DOS Executive',4,True);
  CM_X_SHORT: Begin X^.Long_:=False;W^.VPos:=0;ExecRefresh(W);End;
  CM_X_LONG: Begin X^.Long_:=True;W^.HPos:=0;ExecRefresh(W);End;
  CM_X_ALL: Begin X^.Filter:=0;ExecRefresh(W);End;
  CM_X_PART: ExecPartial(W);
  CM_X_PROG: Begin X^.Filter:=2;ExecRefresh(W);End;
  CM_X_BYNAME: Begin X^.Sort:=0;ExecRefresh(W);End;
  CM_X_BYDATE: Begin X^.Sort:=1;ExecRefresh(W);End;
  CM_X_BYSIZE: Begin X^.Sort:=2;ExecRefresh(W);End;
  CM_X_BYKIND: Begin X^.Sort:=3;ExecRefresh(W);End;
  CM_X_MKDIR: ExecMkDir(W);
  CM_X_CHDIR: ExecChDirDlg(W);
  CM_X_FORMAT,CM_X_SYSDISK: ExecDiskTool(Cmd=CM_X_SYSDISK);
  CM_X_VOLNAME: Begin
    S:=VolNames[UpCase(X^.Dir[1])];
    If InputBox(T3('Volume name for drive '+X^.Dir[1]+':','Nom du volume du lecteur '+X^.Dir[1]+': ',
      'Datentr'#132'germame f'#129'r Laufwerk '+X^.Dir[1]+':'),S,11,320) Then Begin
     VolNames[UpCase(X^.Dir[1])]:=S;IniWrite(IniFile,'volumes',UpCase(X^.Dir[1]),S);Dirty:=True;
    End;
   End;
 End;
End;

{ cible d'un clic sur le chemin affiche }
Function ExecPathTarget(X: PExec; PxClick,TX: Integer): String;
Var Vn: String; Ci,Di,I: Integer; Cur: Char;
Begin
 Cur:=UpCase(X^.Dir[1]);Vn:='';
 If (Cur>='A') And (Cur<='D') Then Vn:=VolNames[Cur];
 Ci:=(PxClick-TX) Div 8+1;
 ExecPathTarget:='';
 If Ci<1 Then Exit;
 Di:=Ci-Length(Vn)-1;
 If Ci<=2 Then Di:=1;
 If Di<=2 Then Begin ExecPathTarget:=Copy(X^.Dir,1,2)+'\';Exit;End;
 I:=Di;
 While (I<=Length(X^.Dir)) And (X^.Dir[I]<>'\') Do Inc(I);
 ExecPathTarget:=Copy(X^.Dir,1,I-1);
End;

Procedure ExecMouse(W: PWindow; Var E: TEvent);
Var X: PExec; X1,Y1,X2,Y2,I,Idx,Cc,Rr,TX,PY: Integer; L: Char; T,S: String;
Begin
 X:=W^.Data;
 If (E.Kind<>EV_DOWN) And (E.Kind<>EV_RDOWN) Then Exit;
 WinClient(W,X1,Y1,X2,Y2);
 { lecteurs }
 If (E.Y>=Y1+3) And (E.Y<=Y1+19) Then Begin
  TX:=X1+6;
  For L:='A' To 'C' Do Begin
   If InBox(E.X,E.Y,TX,Y1+3,TX+50,Y1+19) Then Begin ExecChangeDrive(W,L);Exit;End;
   Inc(TX,64);
  End;
  { chemin : clic = boite Change Directory, double-clic = changement direct }
  If E.X>=TX Then Begin
   T:=ExecPathTarget(X,E.X,TX);
   If (T<>'') And (Upper(T)<>Upper(X^.Dir)) And (Upper(T)<>Upper(Copy(X^.Dir,1,2)+'\')+'') Then Begin
    If E.Dbl Then ExecChangeDir(W,T)
    Else Begin
     S:=T;
     If InputBox(T3('Change to directory:','Aller au r'#130'pertoire :','Wechseln zu Verzeichnis:'),S,70,360) Then Begin
      If (Length(S)<2) Or (S[2]<>':') Then Begin
       If S[1]='\' Then S:=Copy(X^.Dir,1,2)+S Else S:=VJoin(X^.Dir,S);
      End;
      ExecChangeDir(W,S);
     End;
    End;
   End Else If (T<>'') And (Length(T)=3) And (Upper(X^.Dir)<>Upper(T)) Then ExecChangeDir(W,T);
  End;
  Exit;
 End;
 PY:=Y1+26;
 If E.Y<PY Then Exit;
 Idx:=0;
 If X^.Long_ Then Begin
  Rr:=(E.Y-PY) Div 12;
  If (Rr>=0) And (Rr<X^.Rows) Then Idx:=W^.VPos+Rr+1;
 End Else Begin
  Cc:=(E.X-X1-4) Div X^.ColW+W^.HPos;
  Rr:=(E.Y-PY) Div 12;
  If (Rr>=0) And (Rr<X^.Rows) And (Cc>=0) Then Idx:=Cc*X^.Rows+Rr+1;
 End;
 If (Idx>=1) And (Idx<=X^.N) Then Begin
  If E.Kind=EV_RDOWN Then Begin
   { bouton droit = SHIFT+clic : ajoute / retire de la selection }
   If (ExecMarks(X)=0) And (X^.Sel>=1) And Not X^.Nof Then X^.F^[X^.Sel].Mark:=True;
   X^.F^[Idx].Mark:=Not X^.F^[Idx].Mark;X^.Sel:=Idx;X^.Nof:=False;
  End Else Begin
   If (ExecMarks(X)>0) Or X^.Nof Then ExecClearMarks(X);
   X^.Sel:=Idx;
   If E.Dbl Then Begin ExecActivate(W,False);Exit;End;
  End;
  Dirty:=True;
 End;
End;

Procedure ExecKey(W: PWindow; K: Word);
Var X: PExec; I,N,O: Integer; Ch: Char; Mv: Boolean;
Begin
 X:=W^.Data;
 If (K>=1) And (K<=3) Then Begin ExecChangeDrive(W,Chr(64+K));Exit;End;   { CONTROL+A/B/C }
 If X^.N=0 Then Begin If K=K_BKSP Then ExecGoUp(W);Exit;End;
 N:=X^.Sel;O:=N;Mv:=False;
 Case K Of
  K_UP: Begin Dec(N);Mv:=True;End;
  K_DOWN: Begin Inc(N);Mv:=True;End;
  K_LEFT: If Not X^.Long_ Then Begin Dec(N,X^.Rows);Mv:=True;End;
  K_RIGHT: If Not X^.Long_ Then Begin Inc(N,X^.Rows);Mv:=True;End;
  K_HOME: Begin N:=1;Mv:=True;End;
  K_END: Begin N:=X^.N;Mv:=True;End;
  K_PGUP: Begin Dec(N,X^.Rows);Mv:=True;End;
  K_PGDN: Begin Inc(N,X^.Rows);Mv:=True;End;
  371: Begin Dec(N);X^.Sel:=Clamp(N,1,X^.N);ExecEnsure(W);Dirty:=True;Exit;End;   { CTRL+gauche : deplace le cadre }
  372: Begin Inc(N);X^.Sel:=Clamp(N,1,X^.N);ExecEnsure(W);Dirty:=True;Exit;End;   { CTRL+droite }
  32: Begin                                     { ESPACE : selectionne / deselectionne }
       If ExecMarks(X)>0 Then X^.F^[X^.Sel].Mark:=Not X^.F^[X^.Sel].Mark
       Else X^.Nof:=Not X^.Nof;
       Dirty:=True;Exit;End;
  322: Begin                                    { F8 : mode extension (equivalent de MAJ+fleches) }
       X^.Ext:=Not X^.Ext;X^.Anc:=X^.Sel;
       If X^.Ext Then X^.F^[X^.Sel].Mark:=True Else ;
       Dirty:=True;Exit;End;
  10: Begin ExecActivate(W,True);Exit;End;       { CTRL+ENTREE = MAJ+ENTREE : demarrer en icone }
  K_ENTER: Begin ExecActivate(W,False);Exit;End;
  K_BKSP: Begin ExecGoUp(W);Exit;End;
  K_DEL: Begin ExecDelete(W);Exit;End;
 Else If (K>32) And (K<127) Then Begin
   Ch:=UpCase(Chr(K));
   For I:=X^.Sel+1 To X^.N Do
    If X^.F^[I].Disp[1]=Ch Then Begin N:=I;Break;End;
   If N=X^.Sel Then
    For I:=1 To X^.Sel-1 Do If X^.F^[I].Disp[1]=Ch Then Begin N:=I;Break;End;
   Mv:=True;
  End;
 End;
 If Mv Then Begin
  If Not X^.Ext Then ExecClearMarks(X);
  X^.Sel:=Clamp(N,1,X^.N);
  If X^.Ext Then ExecMarkRange(X);
 End;
 ExecEnsure(W);
 Dirty:=True;
End;

Procedure ExecResize(W: PWindow);
Begin
 ExecLayout(W);
End;

Procedure ExecInitMenus(W: PWindow);
Begin
 WinAddMenu(W,'&File~&Fichier~&Datei');
 WinAddItem(W,'&Run...~&Ex'#130'cuter...~&Ausf'#129'hren...',CM_X_RUN,'');
 WinAddItem(W,'&Load...~&Charger...~&Laden...',CM_X_LOAD,'');
 WinAddItem(W,'&Copy...~Co&pier...~&Kopieren...',CM_X_COPY,'');
 WinAddItem(W,'&Get Info~&Informations~&Info',CM_X_INFO,'');
 WinAddItem(W,'&Delete...~&Supprimer...~&L'#148'schen...',CM_X_DEL,'');
 WinAddItem(W,'P&rint...~Im&primer...~&Drucken...',CM_X_PRINT,'');
 WinAddItem(W,'Re&name~&Renommer~&Umbenennen',CM_X_REN,'');
 WinAddItem(W,'E&xit~&Quitter~&Beenden',CM_X_EXIT,'');
 WinAddItem(W,'A&bout MS-DOS Exec...~&'#133' propos de MS-DOS Exec...~'#154'&ber MS-DOS Exec...',CM_X_ABOUT,'');
 WinAddMenu(W,'&View~&Affichage~&Ansicht');
 WinAddItem(W,'S&hort~Co&urt~&Kurz',CM_X_SHORT,'');
 WinAddItem(W,'&Long~&Long~&Lang',CM_X_LONG,'');
 WinAddSep(W);
 WinAddItem(W,'&All~&Tous~&Alle',CM_X_ALL,'');
 WinAddItem(W,'Par&tial...~&Partiel...~&Teilweise...',CM_X_PART,'');
 WinAddItem(W,'Pro&grams~Pro&grammes~Pro&gramme',CM_X_PROG,'');
 WinAddSep(W);
 WinAddItem(W,'By &Name~Par &nom~Nach &Name',CM_X_BYNAME,'');
 WinAddItem(W,'By &Date~Par &date~Nach &Datum',CM_X_BYDATE,'');
 WinAddItem(W,'By &Size~Par t&aille~Nach &Gr'#148#225'e',CM_X_BYSIZE,'');
 WinAddItem(W,'By &Kind~Par t&ype~Nach &Typ',CM_X_BYKIND,'');
 WinAddMenu(W,'&Special~&Sp'#130'cial~&Spezial');
 WinAddItem(W,'&End Session~&Fin de session~Sitzung &beenden',CM_X_ENDSES,'');
 WinAddItem(W,'&Create Directory...~&Cr'#130'er un r'#130'pertoire...~Verzeichnis &erstellen...',CM_X_MKDIR,'');
 WinAddItem(W,'C&hange Directory...~C&hanger de r'#130'pertoire...~Verzeichnis &wechseln...',CM_X_CHDIR,'');
 WinAddItem(W,'&Format Data Disk...~&Formater une disquette...~Datendiskette &formatieren...',CM_X_FORMAT,'');
 WinAddItem(W,'&Make System Disk...~Disquette &syst'#138'me...~&Systemdiskette erstellen...',CM_X_SYSDISK,'');
 WinAddItem(W,'Set &Volume Name...~&Nom du volume...~&Datentr'#132'gername...',CM_X_VOLNAME,'');
End;

Function ExecCreate(Const Dir: String): PWindow;
Var W: PWindow; X: PExec;
Begin
 W:=NewWindow(A_EXEC,'MS-DOS Executive',-1,-1,520,330,True);
 If W=Nil Then Begin ExecCreate:=Nil;Exit;End;
 New(X);FillChar(X^,SizeOf(TExec),0);
 New(X^.F);
 X^.Dir:=Dir;X^.Sel:=1;X^.Mask:='*.*';
 W^.Data:=X;
 ExecInitMenus(W);
 ExecRefresh(W);
 ExecCreate:=W;
End;

Procedure ExecClose(W: PWindow);
Var X: PExec;
Begin
 X:=W^.Data;
 If X<>Nil Then Begin Dispose(X^.F);Dispose(X);End;
End;

{ ====================================================================== }
{              PRESSE-PAPIERS, FICHIERS, DIALOGUE OUVRIR/ENREGISTRER     }
{ ====================================================================== }

Const
 CLIPMAX = 32000;

Var
 ClipTxt : Array[0..CLIPMAX] Of Char;
 ClipLen : Integer;
 LastDir : String;
 FDDir   : String;
 FDMask  : String;
 FDMode  : Integer;
 FDList  : PStrList;

Procedure ClipClear;
Begin
 ClipLen:=0;ClipKind:=0;
 If ClipBmp<>Nil Then Begin FreeMem(ClipBmp,LongInt(ClipBmpW)*ClipBmpH);ClipBmp:=Nil;End;
 Dirty:=True;
End;

Procedure ClipSetText(Const P; Len: Integer);
Begin
 If Len>CLIPMAX Then Len:=CLIPMAX;
 ClipClear;
 Move(P,ClipTxt[0],Len);
 ClipLen:=Len;
 If Len>0 Then ClipKind:=1;
End;

Procedure ListDirTo(L: PStrList; Const Dir,Mask: String; Dirs: Boolean);
Var SR: SearchRec; Tmp: Array[1..400] Of String[44]; N,I,J: Integer; S: String[44];
    NamesD: Array[1..150] Of String[44]; ND: Integer; A: Char;
Begin
 L^.N:=0;ND:=0;N:=0;
 FindFirst(JoinPath(V2R(Dir),'*'),AnyFile,SR);
 While DosError=0 Do Begin
  If (SR.Name<>'.') And (SR.Name<>'..') And (SR.Name[1]<>'.') Then Begin
   If (SR.Attr And Directory)<>0 Then Begin
    If Dirs And (ND<150) Then Begin Inc(ND);NamesD[ND]:='['+Upper(SR.Name)+']';End;
   End Else If WildMatch(Mask,SR.Name) And (N<400) Then Begin
    Inc(N);Tmp[N]:=Upper(SR.Name);
   End;
  End;
  FindNext(SR);
 End;
 {$IFDEF FPC}FindClose(SR);{$ENDIF}
 For I:=2 To N Do Begin
  S:=Tmp[I];J:=I-1;
  While (J>=1) And (Tmp[J]>S) Do Begin Tmp[J+1]:=Tmp[J];Dec(J);End;
  Tmp[J+1]:=S;
 End;
 For I:=2 To ND Do Begin
  S:=NamesD[I];J:=I-1;
  While (J>=1) And (NamesD[J]>S) Do Begin NamesD[J+1]:=NamesD[J];Dec(J);End;
  NamesD[J+1]:=S;
 End;
 If Dirs Then Begin
  If Length(Dir)>3 Then Begin Inc(L^.N);L^.S[L^.N]:='[..]';End;
  For I:=1 To ND Do If L^.N<400 Then Begin Inc(L^.N);L^.S[L^.N]:=NamesD[I];End;
 End;
 For I:=1 To N Do If L^.N<400 Then Begin Inc(L^.N);L^.S[L^.N]:=Tmp[I];End;
End;

Function FDHook(Var D: TDlg; Ev,Ct: Integer): Boolean;
Var S,Nm: String; I,L: Integer; F: Integer;
 Procedure Refresh;
 Begin
  ListDirTo(FDList,FDDir,FDMask,True);
  F:=DlgFind(D,11);
  D.C[F].Val:=0;D.C[F].Top:=0;
  DlgSetText(D,12,T3('Files in ','Fichiers de ','Dateien in ')+FDDir);
  DlgSetText(D,10,FDMask);
 End;
Begin
 FDHook:=False;
 Case Ev Of
  DE_INIT: If Ct=0 Then Begin Refresh;FDHook:=False;End;
  DE_CHANGE: If D.C[Ct].Id=11 Then Begin
    F:=Ct;
    If (D.C[F].Val>=1) And (D.C[F].Val<=FDList^.N) Then Begin
     S:=FDList^.S[D.C[F].Val];
     If S[1]<>'[' Then DlgSetText(D,10,S);
    End;
   End;
  DE_DBL: Begin
    S:=FDList^.S[D.C[Ct].Val];
    If S[1]='[' Then Begin
     Nm:=Copy(S,2,Length(S)-2);
     If Nm='..' Then FDDir:=VParent(FDDir) Else FDDir:=VJoin(FDDir,Nm);
     Refresh;FDHook:=True;
    End Else Begin DlgSetText(D,10,S);FDHook:=False;End;
   End;
  DE_BUTTON: If D.C[Ct].Id=ID_OK Then Begin
    S:=Trim(DlgGetText(D,10));
    If (Pos('*',S)>0) Or (Pos('?',S)>0) Then Begin FDMask:=S;Refresh;FDHook:=True;End
    Else Begin
     If (Pos('\',S)=0) And (Pos(':',S)=0) Then Nm:=VJoin(FDDir,S) Else Nm:=S;
     If VDirExists(Nm) And Not FileExists(V2R(Nm)) Then Begin
      FDDir:=Upper(Nm);Refresh;FDHook:=True;
     End Else If (FDMode=0) And Not FileExists(V2R(Nm)) Then Begin
      InfoBox(T3('File not found.','Fichier introuvable.','Datei nicht gefunden.'));
      FDHook:=True;
     End;
    End;
   End;
 End;
End;

{ Mode 0 : ouvrir ; 1 : enregistrer sous. Path : chemin virtuel (entree/sortie) }
Function FileDialog(Mode: Integer; Const Prompt,DefMask: String; Var Path: String): Boolean;
Var D: TDlg; R: Integer; S: String;
Begin
 FileDialog:=False;
 New(FDList);FDList^.N:=0;
 FDMode:=Mode;
 If LastDir='' Then LastDir:='C:\';
 FDDir:=LastDir;
 If Path<>'' Then Begin
  If Pos('\',Path)>0 Then FDDir:=VParent(Path);
 End;
 FDMask:=DefMask;
 DlgInit(D,'',320,246);
 DlgText(D,10,8,Prompt);
 DlgEdit(D,10,10,24,300,IfThenS(Mode=1,BaseName(Path),DefMask),64);
 DlgText(D,10,50,'');
 D.C[D.N].Id:=12;D.C[D.N].Txt:=FDDir;D.C[D.N].W:=300;
 DlgList(D,11,10,66,300,126,FDList,0);
 DlgButton(D,ID_OK,50,204,90,'OK',True);
 DlgButton(D,ID_CANCEL,180,204,90,T3('Cancel','Annuler','Abbrechen'),False);
 R:=RunDialog(D,@FDHook);
 If R=ID_OK Then Begin
  S:=Trim(DlgGetText(D,10));
  If S<>'' Then Begin
   If (Pos('\',S)=0) And (Pos(':',S)=0) Then S:=VJoin(FDDir,S);
   If (Mode=1) And (ExtOf(S)='') And (Copy(DefMask,1,2)='*.') Then S:=S+Copy(DefMask,2,5);
   Path:=Upper(S);
   LastDir:=FDDir;
   FileDialog:=True;
  End;
 End;
 Dispose(FDList);
End;

{ Chargement/enregistrement de texte brut (CR/LF -> #13) }
Function LoadTextFile(Const VPath: String; Var Buf; MaxLen: LongInt; Var Len: LongInt): Boolean;
Var F: File; P: ^Byte; Tmp: Pointer; N,I,Sz: LongInt; B: Byte; Cnt: Word; Out_: LongInt;
    Dst: ^Byte;
Begin
 LoadTextFile:=False;Len:=0;
 {$I-}
 Assign(F,V2R(VPath));
 Reset(F,1);
 If IOResult<>0 Then Exit;
 Sz:=FileSize(F);
 If Sz>MaxLen*2 Then Sz:=MaxLen*2;
 GetMem(Tmp,Sz+1);
 BlockRead(F,Tmp^,Sz,Cnt);
 Close(F);
 {$I+}
 Dst:=@Buf;Out_:=0;
 For I:=0 To Cnt-1 Do Begin
  B:=PByteArr_(Tmp)^[I];
  If B=10 Then Begin
   If (I=0) Or (PByteArr_(Tmp)^[I-1]<>13) Then Begin
    If Out_<MaxLen Then Begin PByteArr_(@Buf)^[Out_]:=13;Inc(Out_);End;
   End;
  End Else If B=9 Then Begin
   For N:=1 To 4 Do If Out_<MaxLen Then Begin PByteArr_(@Buf)^[Out_]:=32;Inc(Out_);End;
  End Else If B=26 Then
  Else If Out_<MaxLen Then Begin PByteArr_(@Buf)^[Out_]:=B;Inc(Out_);End;
 End;
 FreeMem(Tmp,Sz+1);
 Len:=Out_;
 LoadTextFile:=True;
End;

Function SaveTextFile(Const VPath: String; Var Buf; Len: LongInt): Boolean;
Var F: Text; I: LongInt; B: Byte;
Begin
 SaveTextFile:=False;
 {$I-}
 Assign(F,V2R(VPath));
 Rewrite(F);
 If IOResult<>0 Then Exit;
 For I:=0 To Len-1 Do Begin
  B:=PByteArr_(@Buf)^[I];
  If B=13 Then Write(F,#13#10) Else Write(F,Chr(B));
 End;
 Close(F);
 {$I+}
 SaveTextFile:=IOResult=0;
End;

{ ====================================================================== }
{       MOTEUR D'EDITION DE TEXTE (Notepad, Write, Cardfile, Terminal)   }
{ ====================================================================== }

Const
 EMAX  = 32000;
 MAXVL = 6000;
 AT_BOLD=1; AT_ITAL=2; AT_UNDER=4; AT_SUP=8; AT_SUB=16;
 PA_LEFT=0; PA_CENTER=1; PA_RIGHT=2; PA_JUST=3;
 MAXPARA = 2000;

Type
 PEd = ^TEd;
 TEd = Record
  Buf   : PByteArr_;
  At    : PByteArr_;           { attributs de caractere (Write) ou Nil }
  PA    : PByteArr_;           { attributs de paragraphe (Write) ou Nil }
  Len   : Integer;
  Cur,Anc : Integer;           { Anc = -1 : pas de selection }
  NV    : Integer;
  VL    : Array[0..MAXVL] Of Integer;
  VA    : Array[0..MAXVL] Of Byte;
  Cols  : Integer;
  Rows  : Integer;
  Wrap  : Boolean;
  Modified : Boolean;
  UBuf,UAt : PByteArr_;
  ULen,UCur : Integer;
  HasUndo : Boolean;
  FileName : String[80];
  FindStr  : String[40];
  MatchCase: Boolean;
  Cur_At : Byte;               { attributs du texte tape }
  WantCol: Integer;
  X0,Y0,PW,PH : Integer;       { zone d'affichage }
  Max   : Integer;
  Hdr,Ftr : String[60];
  Ruler : Boolean;
  LM,RM,TM,BM : Integer;
  FontName : String[16];
  FontSize : Integer;
 End;

Function EdNew(Rich: Boolean): PEd;
Var E: PEd;
Begin
 New(E);
 FillChar(E^,SizeOf(TEd),0);
 GetMem(E^.Buf,EMAX+2);
 FillChar(E^.Buf^,EMAX+2,0);
 If Rich Then Begin
  GetMem(E^.At,EMAX+2);FillChar(E^.At^,EMAX+2,0);
  GetMem(E^.PA,MAXPARA+2);FillChar(E^.PA^,MAXPARA+2,0);
 End;
 E^.Anc:=-1;E^.Wrap:=True;E^.Cols:=60;E^.Rows:=20;E^.Max:=EMAX;
 EdNew:=E;
End;

Procedure EdFree(E: PEd);
Begin
 If E=Nil Then Exit;
 FreeMem(E^.Buf,EMAX+2);
 If E^.At<>Nil Then FreeMem(E^.At,EMAX+2);
 If E^.PA<>Nil Then FreeMem(E^.PA,MAXPARA+2);
 If E^.UBuf<>Nil Then FreeMem(E^.UBuf,EMAX+2);
 If E^.UAt<>Nil Then FreeMem(E^.UAt,EMAX+2);
 Dispose(E);
End;

Function ParaOf(E: PEd; Off: Integer): Integer;
Var I,N: Integer;
Begin
 N:=0;
 For I:=0 To Off-1 Do If E^.Buf^[I]=13 Then Inc(N);
 If N>MAXPARA Then N:=MAXPARA;
 ParaOf:=N;
End;

Procedure EdLayout(E: PEd);
Var I,S,J,LastSp,Pn: Integer; Done: Boolean;
Begin
 E^.NV:=0;S:=0;Pn:=0;
 Repeat
  If E^.NV>=MAXVL Then Break;
  E^.VL[E^.NV]:=S;
  If E^.PA<>Nil Then E^.VA[E^.NV]:=E^.PA^[Pn] Else E^.VA[E^.NV]:=0;
  Inc(E^.NV);
  J:=S;LastSp:=-1;
  While (J<E^.Len) And (E^.Buf^[J]<>13) And (Not (E^.Wrap And (J-S>=E^.Cols))) Do Begin
   If E^.Buf^[J]=32 Then LastSp:=J;
   Inc(J);
  End;
  If J>=E^.Len Then Break;
  If E^.Buf^[J]=13 Then Begin S:=J+1;Inc(Pn);End
  Else Begin
   If LastSp>S Then S:=LastSp+1 Else S:=J;
  End;
 Until False;
 If E^.NV=0 Then Begin E^.NV:=1;E^.VL[0]:=0;End;
End;

{ ligne visuelle contenant l'offset (en fin de ligne souple : la suivante) }
Function EdVLine(E: PEd; Off: Integer): Integer;
Var Lo,Hi,M: Integer;
Begin
 Lo:=0;Hi:=E^.NV-1;
 While Lo<Hi Do Begin
  M:=(Lo+Hi+1) Div 2;
  If E^.VL[M]<=Off Then Lo:=M Else Hi:=M-1;
 End;
 EdVLine:=Lo;
End;

Function VLineEnd(E: PEd; V: Integer): Integer;  { offset de fin (exclu #13) }
Var Nx: Integer;
Begin
 If V+1<E^.NV Then Begin
  Nx:=E^.VL[V+1];
  If (Nx>0) And (E^.Buf^[Nx-1]=13) Then VLineEnd:=Nx-1 Else VLineEnd:=Nx;
 End Else VLineEnd:=E^.Len;
End;

Procedure EdPushUndo(E: PEd);
Begin
 If E^.UBuf=Nil Then Begin
  GetMem(E^.UBuf,EMAX+2);
  If E^.At<>Nil Then GetMem(E^.UAt,EMAX+2);
 End;
 Move(E^.Buf^,E^.UBuf^,E^.Len);
 If E^.At<>Nil Then Move(E^.At^,E^.UAt^,E^.Len);
 E^.ULen:=E^.Len;E^.UCur:=E^.Cur;E^.HasUndo:=True;
End;

Procedure EdUndo(E: PEd);
Var TB,TA: PByteArr_; TL_,TC: Integer;
Begin
 If Not E^.HasUndo Then Exit;
 GetMem(TB,EMAX+2);Move(E^.Buf^,TB^,E^.Len);TL_:=E^.Len;TC:=E^.Cur;
 If E^.At<>Nil Then Begin GetMem(TA,EMAX+2);Move(E^.At^,TA^,E^.Len);End;
 Move(E^.UBuf^,E^.Buf^,E^.ULen);
 If E^.At<>Nil Then Move(E^.UAt^,E^.At^,E^.ULen);
 E^.Len:=E^.ULen;E^.Cur:=E^.UCur;E^.Anc:=-1;
 Move(TB^,E^.UBuf^,TL_);E^.ULen:=TL_;E^.UCur:=TC;
 If E^.At<>Nil Then Begin Move(TA^,E^.UAt^,TL_);FreeMem(TA,EMAX+2);End;
 FreeMem(TB,EMAX+2);
 E^.Modified:=True;
 EdLayout(E);
End;

Procedure EdSelRange(E: PEd; Var A,B: Integer);
Begin
 If E^.Anc<0 Then Begin A:=E^.Cur;B:=E^.Cur;End
 Else If E^.Anc<E^.Cur Then Begin A:=E^.Anc;B:=E^.Cur;End
 Else Begin A:=E^.Cur;B:=E^.Anc;End;
End;

Function EdHasSel(E: PEd): Boolean;
Begin
 EdHasSel:=(E^.Anc>=0) And (E^.Anc<>E^.Cur);
End;

{ Gestion des attributs de paragraphe lors de l'insertion/suppression de #13 }
Procedure PAInsert(E: PEd; Off: Integer);
Var P,I: Integer;
Begin
 If E^.PA=Nil Then Exit;
 P:=ParaOf(E,Off);
 For I:=MAXPARA-1 DownTo P+1 Do E^.PA^[I]:=E^.PA^[I-1];
End;

Procedure PADelete(E: PEd; Off: Integer);
Var P,I: Integer;
Begin
 If E^.PA=Nil Then Exit;
 P:=ParaOf(E,Off);
 For I:=P+1 To MAXPARA-1 Do E^.PA^[I]:=E^.PA^[I+1];
End;

Procedure EdDeleteRange(E: PEd; A,B: Integer);
Var I,N: Integer;
Begin
 If B<=A Then Exit;
 For I:=A To B-1 Do If E^.Buf^[I]=13 Then PADelete(E,A+1);
 N:=B-A;
 Move(E^.Buf^[B],E^.Buf^[A],E^.Len-B);
 If E^.At<>Nil Then Move(E^.At^[B],E^.At^[A],E^.Len-B);
 Dec(E^.Len,N);
 E^.Cur:=A;E^.Anc:=-1;E^.Modified:=True;
End;

Procedure EdInsertChar(E: PEd; Ch: Byte);
Var A,B: Integer;
Begin
 If EdHasSel(E) Then Begin EdSelRange(E,A,B);EdDeleteRange(E,A,B);End;
 If E^.Len>=E^.Max-1 Then Exit;
 If Ch=13 Then PAInsert(E,E^.Cur+1);
 Move(E^.Buf^[E^.Cur],E^.Buf^[E^.Cur+1],E^.Len-E^.Cur);
 If E^.At<>Nil Then Move(E^.At^[E^.Cur],E^.At^[E^.Cur+1],E^.Len-E^.Cur);
 E^.Buf^[E^.Cur]:=Ch;
 If E^.At<>Nil Then E^.At^[E^.Cur]:=E^.Cur_At;
 Inc(E^.Len);Inc(E^.Cur);E^.Anc:=-1;E^.Modified:=True;
End;

Procedure EdInsertBlock(E: PEd; Const P; N: Integer);
Var I: Integer;
Begin
 For I:=0 To N-1 Do EdInsertChar(E,PByteArr_(@P)^[I]);
End;

Procedure EdCopy(E: PEd);
Var A,B: Integer;
Begin
 If Not EdHasSel(E) Then Exit;
 EdSelRange(E,A,B);
 ClipSetText(E^.Buf^[A],B-A);
End;

Procedure EdCut(E: PEd);
Var A,B: Integer;
Begin
 If Not EdHasSel(E) Then Exit;
 EdPushUndo(E);
 EdCopy(E);
 EdSelRange(E,A,B);
 EdDeleteRange(E,A,B);
End;

Procedure EdPaste(E: PEd);
Var I: Integer;
Begin
 If ClipKind<>1 Then Exit;
 EdPushUndo(E);
 For I:=0 To ClipLen-1 Do Begin
  If (Ord(ClipTxt[I])=10) Then Continue;
  EdInsertChar(E,Ord(ClipTxt[I]));
 End;
End;

Procedure EdSetText(E: PEd; Const S: String);
Var I: Integer;
Begin
 E^.Len:=0;E^.Cur:=0;E^.Anc:=-1;
 For I:=1 To Length(S) Do EdInsertChar(E,Ord(S[I]));
 E^.Cur:=0;E^.Modified:=False;
 EdLayout(E);
End;

Function EdGetLine(E: PEd; V: Integer): String;
Var S: String; I,A,B: Integer;
Begin
 S:='';
 A:=E^.VL[V];B:=VLineEnd(E,V);
 For I:=A To B-1 Do If Length(S)<255 Then S:=S+Chr(E^.Buf^[I]);
 EdGetLine:=S;
End;

Procedure EdClear(E: PEd);
Begin
 E^.Len:=0;E^.Cur:=0;E^.Anc:=-1;E^.Modified:=False;E^.HasUndo:=False;
 If E^.PA<>Nil Then FillChar(E^.PA^,MAXPARA+2,0);
 EdLayout(E);
End;

{ Deplacement du curseur }
Procedure EdMoveV(E: PEd; Delta: Integer);
Var V,Col,NvL: Integer;
Begin
 V:=EdVLine(E,E^.Cur);
 If (E^.WantCol<0) Then E^.WantCol:=E^.Cur-E^.VL[V];
 NvL:=V+Delta;
 If NvL<0 Then Begin E^.Cur:=0;Exit;End;
 If NvL>=E^.NV Then Begin E^.Cur:=E^.Len;Exit;End;
 Col:=E^.WantCol;
 If E^.VL[NvL]+Col>VLineEnd(E,NvL) Then E^.Cur:=VLineEnd(E,NvL) Else E^.Cur:=E^.VL[NvL]+Col;
End;

Function IsWordCh(B: Byte): Boolean;
Begin
 IsWordCh:=((B>=48) And (B<=57)) Or ((B>=65) And (B<=90)) Or ((B>=97) And (B<=122)) Or (B>=128);
End;

Procedure EdWordAt(E: PEd; Off: Integer; Var A,B: Integer);
Begin
 A:=Off;B:=Off;
 If (Off<E^.Len) And IsWordCh(E^.Buf^[Off]) Then Begin
  While (A>0) And IsWordCh(E^.Buf^[A-1]) Do Dec(A);
  While (B<E^.Len) And IsWordCh(E^.Buf^[B]) Do Inc(B);
 End Else If Off<E^.Len Then B:=Off+1;
End;

{ Traitement d'une touche d'edition. Retourne True si le texte est modifie }
Function EdKey(E: PEd; K: Word): Boolean;
Var V,A,B: Integer;
Begin
 EdKey:=False;
 If (K<>K_UP) And (K<>K_DOWN) And (K<>K_PGUP) And (K<>K_PGDN) Then E^.WantCol:=-1;
 Case K Of
  K_LEFT: Begin If EdHasSel(E) Then Begin EdSelRange(E,A,B);E^.Cur:=A;End Else If E^.Cur>0 Then Dec(E^.Cur);E^.Anc:=-1;End;
  K_RIGHT: Begin If EdHasSel(E) Then Begin EdSelRange(E,A,B);E^.Cur:=B;End Else If E^.Cur<E^.Len Then Inc(E^.Cur);E^.Anc:=-1;End;
  K_UP: Begin E^.Anc:=-1;EdMoveV(E,-1);End;
  K_DOWN: Begin E^.Anc:=-1;EdMoveV(E,1);End;
  K_PGUP: Begin E^.Anc:=-1;EdMoveV(E,-E^.Rows);End;
  K_PGDN: Begin E^.Anc:=-1;EdMoveV(E,E^.Rows);End;
  K_HOME: Begin E^.Anc:=-1;V:=EdVLine(E,E^.Cur);E^.Cur:=E^.VL[V];End;
  K_END: Begin E^.Anc:=-1;V:=EdVLine(E,E^.Cur);E^.Cur:=VLineEnd(E,V);End;
  K_BKSP: Begin
    If EdHasSel(E) Or (E^.Cur>0) Then Begin
     EdPushUndo(E);
     If EdHasSel(E) Then Begin EdSelRange(E,A,B);EdDeleteRange(E,A,B);End
     Else EdDeleteRange(E,E^.Cur-1,E^.Cur);
     EdKey:=True;
    End;
   End;
  K_DEL: Begin
    If EdHasSel(E) Or (E^.Cur<E^.Len) Then Begin
     EdPushUndo(E);
     If EdHasSel(E) Then Begin EdSelRange(E,A,B);EdDeleteRange(E,A,B);End
     Else EdDeleteRange(E,E^.Cur,E^.Cur+1);
     EdKey:=True;
    End;
   End;
  K_ENTER: Begin EdPushUndo(E);EdInsertChar(E,13);EdKey:=True;End;
 Else If (K>=32) And (K<256) Then Begin
   EdPushUndo(E);
   EdInsertChar(E,K);EdKey:=True;
  End;
 End;
 EdLayout(E);
End;

{ Recherche : retourne True si trouve (selection placee) }
Function EdFind(E: PEd; Const S: String; Case_: Boolean; From: Integer): Boolean;
Var I,J,N: Integer; Ok: Boolean; C1,C2: Char; T: String;
Begin
 EdFind:=False;
 If S='' Then Exit;
 T:=S;
 If Not Case_ Then T:=Upper(T);
 N:=Length(T);
 For I:=From To E^.Len-N Do Begin
  Ok:=True;
  For J:=1 To N Do Begin
   C1:=Chr(E^.Buf^[I+J-1]);
   If Not Case_ Then C1:=UpCase(C1);
   If C1<>T[J] Then Begin Ok:=False;Break;End;
  End;
  If Ok Then Begin
   E^.Anc:=I;E^.Cur:=I+N;
   EdFind:=True;Exit;
  End;
 End;
End;

{ Dessin du texte dans la zone (X0,Y0)-(X0+PW,Y0+PH). Top = premiere ligne visuelle }
Procedure EdDraw(E: PEd; Top: Integer; Focus: Boolean);
Var V,Y,A,B,I,X,LH,Sa,Sb,Col,XO,LnLen: Integer; At_,Pa: Byte; Ch: Char; Sel: Boolean;
    S: String; Bl: Boolean;
Begin
 EdSelRange(E,Sa,Sb);
 If E^.Anc<0 Then Begin Sa:=-1;Sb:=-1;End;
 Y:=E^.Y0;
 V:=Top;
 While (V<E^.NV) And (Y<E^.Y0+E^.PH) Do Begin
  A:=E^.VL[V];B:=VLineEnd(E,V);
  Pa:=E^.VA[V];
  LH:=12;
  Case (Pa Shr 4) And 3 Of 1: LH:=18;2: LH:=24;End;
  XO:=0;LnLen:=B-A;
  Case Pa And 3 Of
   PA_CENTER: XO:=(E^.PW-LnLen*8) Div 2;
   PA_RIGHT: XO:=E^.PW-LnLen*8-4;
  End;
  If XO<0 Then XO:=0;
  For I:=A To B-1 Do Begin
   X:=E^.X0+4+XO+(I-A)*8;
   Ch:=Chr(E^.Buf^[I]);
   Sel:=(I>=Sa) And (I<Sb);
   At_:=0;If E^.At<>Nil Then At_:=E^.At^[I];
   If Sel Then GBar(X,Y,X+7,Y+LH-2,cBlk);
   Bl:=(At_ And AT_SUP)<>0;
   If Sel Then Begin
    GText(X,Y+2,Ch,cWht);
    If (At_ And AT_BOLD)<>0 Then GText(X+1,Y+2,Ch,cWht);
    If (At_ And AT_UNDER)<>0 Then GHLine(X,X+7,Y+LH-4,cWht);
   End Else Begin
    Col:=cBlk;
    If (At_ And AT_ITAL)<>0 Then Begin
     SetClip(Max2(X-1,CX1),Y,Min2(X+9,CX2),Y+5);
     GText(X+1,Y+2,Ch,Col);
     If (At_ And AT_BOLD)<>0 Then GText(X+2,Y+2,Ch,Col);
     SetClip(Max2(X-1,CX1),Y+6,Min2(X+9,CX2),Y+LH);
     GText(X,Y+2,Ch,Col);
     If (At_ And AT_BOLD)<>0 Then GText(X+1,Y+2,Ch,Col);
     SetClip(E^.X0,E^.Y0,E^.X0+E^.PW-1,E^.Y0+E^.PH-1);
    End Else Begin
     If (At_ And AT_SUP)<>0 Then GText(X,Y,Ch,Col)
     Else If (At_ And AT_SUB)<>0 Then GText(X,Y+4,Ch,Col)
     Else GText(X,Y+2,Ch,Col);
     If (At_ And AT_BOLD)<>0 Then Begin
      If (At_ And AT_SUP)<>0 Then GText(X+1,Y,Ch,Col)
      Else If (At_ And AT_SUB)<>0 Then GText(X+1,Y+4,Ch,Col)
      Else GText(X+1,Y+2,Ch,Col);
     End;
    End;
    If (At_ And AT_UNDER)<>0 Then GHLine(X,X+7,Y+LH-4,Col);
   End;
  End;
  { curseur }
  If Focus And (E^.Cur>=A) And (E^.Cur<=B) And (EdVLine(E,E^.Cur)=V) Then Begin
   X:=E^.X0+4+XO+(E^.Cur-A)*8;
   If (NowCs Div BlinkHalf) Mod 2=0 Then GVLine(X,Y,Y+LH-3,cBlk);
  End;
  Inc(Y,LH);
  Inc(V);
 End;
End;

{ Hauteur d'une ligne visuelle }
Function VLineH(E: PEd; V: Integer): Integer;
Begin
 Case (E^.VA[V] Shr 4) And 3 Of 1: VLineH:=18;2: VLineH:=24;Else VLineH:=12;End;
End;

{ Offset sous le point (PX,PY) }
Function EdHit(E: PEd; Top,PX,PY: Integer): Integer;
Var V,Y,Col,A,B,LH,XO: Integer;
Begin
 V:=Top;Y:=E^.Y0;
 While (V<E^.NV-1) And (PY>=Y+VLineH(E,V)) Do Begin Inc(Y,VLineH(E,V));Inc(V);End;
 A:=E^.VL[V];B:=VLineEnd(E,V);
 XO:=0;
 Case E^.VA[V] And 3 Of
  PA_CENTER: XO:=(E^.PW-(B-A)*8) Div 2;
  PA_RIGHT: XO:=E^.PW-(B-A)*8-4;
 End;
 If XO<0 Then XO:=0;
 Col:=(PX-E^.X0-4-XO+4) Div 8;
 If Col<0 Then Col:=0;
 If A+Col>B Then EdHit:=B Else EdHit:=A+Col;
End;

{ Visibilite du curseur : ajuste la position de defilement }
Procedure EdScrollTo(E: PEd; Var Top: Integer);
Var V,Y,I: Integer;
Begin
 V:=EdVLine(E,E^.Cur);
 If V<Top Then Top:=V;
 Repeat
  Y:=0;I:=Top;
  While I<=V Do Begin Inc(Y,VLineH(E,I));Inc(I);End;
  If (Y>E^.PH-2) And (Top<V) Then Inc(Top) Else Break;
 Until False;
 If Top<0 Then Top:=0;
End;

{ ====================================================================== }
{              NOTEPAD ET WRITE (fenetres d'edition de texte)            }
{ ====================================================================== }

Const
 CM_N_NEW=201; CM_N_OPEN=202; CM_N_SAVE=203; CM_N_SAVEAS=204; CM_N_PRINT=205;
 CM_N_EXIT=206; CM_N_ABOUT=207;
 CM_N_UNDO=211; CM_N_CUT=212; CM_N_COPY=213; CM_N_PASTE=214; CM_N_CLEAR=215;
 CM_N_TIME=216; CM_N_ALL=217;
 CM_N_FIND=221; CM_N_FINDNEXT=222; CM_N_REPLACE=223; CM_N_GOTO=224;
 CM_W_NORMAL=231; CM_W_BOLD=232; CM_W_ITAL=233; CM_W_UNDER=234; CM_W_SUP=235;
 CM_W_SUB=236; CM_W_FONTS=237;
 CM_W_LEFT=241; CM_W_CENTER=242; CM_W_RIGHT=243; CM_W_JUST=244;
 CM_W_SINGLE=245; CM_W_ONEHALF=246; CM_W_DOUBLE=247; CM_W_PNORMAL=248;
 CM_W_HEADER=251; CM_W_FOOTER=252; CM_W_RULER=253; CM_W_LAYOUT=254;
 CM_W_REPAG=255; CM_W_PRSETUP=256;

Var
 RepEd : PEd;
 RepWin: PWindow;
 RepFind,RepWith: String;
 LastBlink: LongInt;

Function EdWinTitle(W: PWindow): String;
Var E: PEd; N: String;
Begin
 E:=W^.Data;
 If E^.FileName='' Then N:=T3('(Untitled)','(Sans titre)','(Unbenannt)') Else N:=BaseName(E^.FileName);
 If W^.App=A_WRITE Then EdWinTitle:='Write - '+N Else EdWinTitle:='Notepad - '+N;
End;

Function EdAskSave(W: PWindow): Boolean;   { True = on peut continuer }
Var E: PEd; R: Integer;
Begin
 EdAskSave:=True;
 E:=W^.Data;
 If Not E^.Modified Then Exit;
 R:=MsgBox(T3('Save changes to ','Enregistrer les modifications de ','Anderungen speichern in ')+
   IfThenS(E^.FileName='',T3('(untitled)','(sans titre)','(unbenannt)'),BaseName(E^.FileName))+'?',3,2);
 If R=ID_CANCEL Then Begin EdAskSave:=False;Exit;End;
 If R=ID_YES Then Begin
  AppMenu(W,CM_N_SAVE);
  If E^.Modified Then EdAskSave:=False;
 End;
End;

{ ---- En-tete .WRI minimal (128 octets) pour Write ---- }
Function WriLoad(E: PEd; Const P: String): Boolean;
Var F: File; Hdr: Array[0..127] Of Byte; N: Word; Fc: LongInt; Tmp: PByteArr_; I: LongInt;
    Cnt: Word;
Begin
 WriLoad:=False;
 {$I-}
 Assign(F,V2R(P));Reset(F,1);
 If IOResult<>0 Then Exit;
 BlockRead(F,Hdr,128,N);
 Close(F);
 {$I+}
 If (N=128) And (Hdr[0]=$31) And (Hdr[1]=$BE) Then Begin
  { lecture du texte pur : offset 128 a fcMac }
  Fc:=Hdr[14]+Hdr[15]*256+LongInt(Hdr[16])*65536;
  GetMem(Tmp,EMAX+130);
  Assign(F,V2R(P));Reset(F,1);Seek(F,128);
  BlockRead(F,Tmp^,Min2(EMAX,Fc-128),Cnt);
  Close(F);
  E^.Len:=0;E^.Cur:=0;
  For I:=0 To Cnt-1 Do Begin
   If Tmp^[I]=10 Then Continue;
   If Tmp^[I]=13 Then Begin
    If (I+1<Cnt) And (Tmp^[I+1]=10) Then Begin E^.Buf^[E^.Len]:=13;Inc(E^.Len);End
    Else Begin E^.Buf^[E^.Len]:=13;Inc(E^.Len);End;
   End Else If E^.Len<EMAX-1 Then Begin E^.Buf^[E^.Len]:=Tmp^[I];Inc(E^.Len);End;
  End;
  FreeMem(Tmp,EMAX+130);
  WriLoad:=True;
 End Else Begin
  If LoadTextFile(P,E^.Buf^,EMAX-1,Fc) Then Begin E^.Len:=Fc;WriLoad:=True;End;
 End;
End;

Function WriSave(E: PEd; Const P: String): Boolean;
Var F: File; Hdr: Array[0..127] Of Byte; Fc: LongInt; I: Integer; Pg: Word;
Begin
 WriSave:=False;
 FillChar(Hdr,128,0);
 Hdr[0]:=$31;Hdr[1]:=$BE;Hdr[4]:=$00;Hdr[5]:=$AB;
 Fc:=128+E^.Len;
 Hdr[14]:=Fc And 255;Hdr[15]:=(Fc Shr 8) And 255;Hdr[16]:=(Fc Shr 16) And 255;
 Pg:=(Fc+127) Div 128;
 Hdr[18]:=Pg And 255;Hdr[19]:=Pg Shr 8;
 {$I-}
 Assign(F,V2R(P));Rewrite(F,1);
 If IOResult<>0 Then Exit;
 BlockWrite(F,Hdr,128);
 BlockWrite(F,E^.Buf^,E^.Len);
 Close(F);
 {$I+}
 WriSave:=IOResult=0;
End;

Procedure EdWinLoad(W: PWindow; Const P: String);
Var E: PEd; Ln: LongInt;
Begin
 E:=W^.Data;
 E^.Len:=0;E^.Cur:=0;E^.Anc:=-1;
 If W^.App=A_WRITE Then Begin
  If Not WriLoad(E,P) Then Begin
   InfoBox(T3('Cannot open ','Impossible d''ouvrir ','Kann nicht ge'#148'ffnet werden: ')+BaseName(P));Exit;
  End;
  FillChar(E^.At^,EMAX+2,0);
 End Else Begin
  If Not LoadTextFile(P,E^.Buf^,EMAX-1,Ln) Then Begin
   InfoBox(T3('Cannot open ','Impossible d''ouvrir ','Kann nicht ge'#148'ffnet werden: ')+BaseName(P));Exit;
  End;
  E^.Len:=Ln;
 End;
 E^.FileName:=P;E^.Modified:=False;E^.HasUndo:=False;
 EdLayout(E);
 W^.VPos:=0;
 W^.Title:=EdWinTitle(W);
 Dirty:=True;
End;

Function EdWinSave(W: PWindow; Const P: String): Boolean;
Var E: PEd; Ok: Boolean;
Begin
 E:=W^.Data;
 If W^.App=A_WRITE Then Ok:=WriSave(E,P) Else Ok:=SaveTextFile(P,E^.Buf^,E^.Len);
 If Ok Then Begin E^.FileName:=P;E^.Modified:=False;W^.Title:=EdWinTitle(W);End
 Else InfoBox(T3('Cannot save the file.','Impossible d''enregistrer le fichier.','Datei kann nicht gespeichert werden.'));
 EdWinSave:=Ok;
End;

Procedure EdFindDlg(W: PWindow; Replace: Boolean);
Var E: PEd; D: TDlg; R: Integer;
Begin
 E:=W^.Data;
 DlgInit(D,'',300,100);
 DlgText(D,10,10,T3('Fi&nd What:','&Rechercher :','&Suchen nach:'));
 DlgEdit(D,10,100,6,190,E^.FindStr,40);
 DlgCheck(D,11,10,34,T3('Match &Case','&Respecter la casse','&Gro'#225'/Klein beachten'),E^.MatchCase);
 DlgButton(D,ID_OK,50,64,90,T3('&Find Next','&Suivant','&Weitersuchen'),True);
 DlgButton(D,ID_CANCEL,160,64,90,T3('Cancel','Annuler','Abbrechen'),False);
 R:=RunDialog(D,@NoHook);
 If R=ID_OK Then Begin
  E^.FindStr:=DlgGetText(D,10);
  E^.MatchCase:=DlgGetVal(D,11)=1;
  If Not EdFind(E,E^.FindStr,E^.MatchCase,E^.Cur) Then
   InfoBox(T3('Cannot find "','Impossible de trouver "','Kann nicht finden: "')+E^.FindStr+'"');
 End;
End;

Function RepHook(Var D: TDlg; Ev,Ct: Integer): Boolean;
Var A,B: Integer; Cnt: Integer; S: String;
Begin
 RepHook:=False;
 If Ev<>DE_BUTTON Then Exit;
 RepFind:=DlgGetText(D,10);RepWith:=DlgGetText(D,12);
 RepEd^.FindStr:=RepFind;RepEd^.MatchCase:=DlgGetVal(D,11)=1;
 Case D.C[Ct].Id Of
  20: Begin
    If Not EdFind(RepEd,RepFind,RepEd^.MatchCase,RepEd^.Cur) Then
     InfoBox(T3('Cannot find "','Impossible de trouver "','Kann nicht finden: "')+RepFind+'"');
    EdLayout(RepEd);RepHook:=True;
   End;
  21: Begin
    If EdHasSel(RepEd) Then Begin
     EdPushUndo(RepEd);EdSelRange(RepEd,A,B);EdDeleteRange(RepEd,A,B);
     For A:=1 To Length(RepWith) Do EdInsertChar(RepEd,Ord(RepWith[A]));
    End;
    If Not EdFind(RepEd,RepFind,RepEd^.MatchCase,RepEd^.Cur) Then Beep;
    EdLayout(RepEd);RepHook:=True;
   End;
  22: Begin
    Cnt:=0;
    EdPushUndo(RepEd);
    RepEd^.Cur:=0;
    While EdFind(RepEd,RepFind,RepEd^.MatchCase,RepEd^.Cur) And (Cnt<2000) Do Begin
     EdSelRange(RepEd,A,B);EdDeleteRange(RepEd,A,B);
     For A:=1 To Length(RepWith) Do EdInsertChar(RepEd,Ord(RepWith[A]));
     Inc(Cnt);
    End;
    EdLayout(RepEd);
    InfoBox(IntStr(Cnt)+' '+T3('replacements made.','remplacements effectu'#130's.','Ersetzungen vorgenommen.'));
    RepHook:=True;
   End;
 End;
End;

Procedure EdReplaceDlg(W: PWindow);
Var E: PEd; D: TDlg; R: Integer;
Begin
 E:=W^.Data;RepEd:=E;RepWin:=W;
 DlgInit(D,'',330,150);
 DlgText(D,10,10,T3('Fi&nd What:','&Rechercher :','&Suchen nach:'));
 DlgEdit(D,10,110,6,210,E^.FindStr,40);
 DlgText(D,10,38,T3('Change &To:','Rem&placer par :','&Ersetzen durch:'));
 DlgEdit(D,12,110,34,210,RepWith,40);
 DlgCheck(D,11,10,62,T3('Match &Case','&Respecter la casse','&Gro'#225'/Klein beachten'),E^.MatchCase);
 DlgButton(D,20,10,90,96,T3('&Find Next','&Suivant','&Weiter'),True);
 DlgButton(D,21,114,90,96,T3('&Change','&Remplacer','&Ersetzen'),False);
 DlgButton(D,22,218,90,100,T3('Change &All','&Tout remplacer','&Alle ersetzen'),False);
 DlgButton(D,ID_CANCEL,114,118,96,T3('Close','Fermer','Schlie'#225'en'),False);
 R:=RunDialog(D,@RepHook);
 W^.Param:=0;
End;

Procedure EdPrint(W: PWindow);
Var E: PEd; R: Integer; N: String;
Begin
 E:=W^.Data;
 N:=IfThenS(E^.FileName='',T3('(Untitled)','(Sans titre)','(Unbenannt)'),BaseName(E^.FileName));
 R:=MsgBox(T3('Print "'+N+'" on '+PrinterName+' ('+PrintPort+':)?','Imprimer "'+N+'" sur '+PrinterName+
   ' ('+PrintPort+':) ?','"'+N+'" auf '+PrinterName+' ('+PrintPort+':) drucken?'),1,2);
 If R=ID_OK Then Begin
  SpoolAdd(IfThenS(W^.App=A_WRITE,'Write','Notepad')+' - '+N);
 End;
End;

Procedure EdInsertDate(E: PEd);
Var H,M,S,Y,Mo,D: Integer; T: String; I: Integer;
Begin
 GetNow(H,M,S);GetToday(Y,Mo,D);
 T:=TimeStr(H,M,-1)+' '+DateStr(Y,Mo,D);
 EdPushUndo(E);
 For I:=1 To Length(T) Do EdInsertChar(E,Ord(T[I]));
End;

Procedure EdApplyAttr(W: PWindow; Bit: Byte; Mode: Integer);   { Mode 0 bascule, 1 efface tout }
Var E: PEd; A,B,I: Integer; On: Boolean;
Begin
 E:=W^.Data;
 If E^.At=Nil Then Exit;
 If EdHasSel(E) Then Begin
  EdSelRange(E,A,B);
  EdPushUndo(E);
  If Mode=1 Then Begin For I:=A To B-1 Do E^.At^[I]:=0;End
  Else Begin
   On:=(E^.At^[A] And Bit)=0;
   For I:=A To B-1 Do If On Then E^.At^[I]:=E^.At^[I] Or Bit Else E^.At^[I]:=E^.At^[I] And (255-Bit);
  End;
  E^.Modified:=True;
 End Else Begin
  If Mode=1 Then E^.Cur_At:=0 Else E^.Cur_At:=E^.Cur_At Xor Bit;
 End;
End;

Procedure EdParaAttr(W: PWindow; Mask,Val: Byte);
Var E: PEd; A,B,P1,P2,I: Integer;
Begin
 E:=W^.Data;
 If E^.PA=Nil Then Exit;
 EdSelRange(E,A,B);
 P1:=ParaOf(E,A);P2:=ParaOf(E,B);
 For I:=P1 To P2 Do E^.PA^[I]:=(E^.PA^[I] And (255-Mask)) Or Val;
 E^.Modified:=True;
 EdLayout(E);
End;

Procedure WriteHdrFtr(W: PWindow; Foot: Boolean);
Var E: PEd; S: String;
Begin
 E:=W^.Data;
 If Foot Then S:=E^.Ftr Else S:=E^.Hdr;
 If InputBox(IfThenS(Foot,T3('Footer text:','Texte du pied de page :','Fu'#225'zeilentext:'),
   T3('Header text:','Texte de l''en-t'#136'te :','Kopfzeilentext:')),S,60,360) Then Begin
  If Foot Then E^.Ftr:=S Else E^.Hdr:=S;
  E^.Modified:=True;
 End;
End;

Procedure WriteLayoutDlg(W: PWindow);
Var E: PEd; D: TDlg; R: Integer;
Begin
 E:=W^.Data;
 DlgInit(D,'',280,150);
 DlgText(D,10,10,T3('Margins (1/10 inch):','Marges (1/10 pouce) :','R'#132'nder (1/10 Zoll):'));
 DlgText(D,10,34,T3('&Left:','&Gauche :','&Links:'));DlgEdit(D,10,90,30,50,IntStr(E^.LM),3);
 DlgText(D,150,34,T3('&Right:','&Droite :','&Rechts:'));DlgEdit(D,11,210,30,50,IntStr(E^.RM),3);
 DlgText(D,10,60,T3('&Top:','&Haut :','&Oben:'));DlgEdit(D,12,90,56,50,IntStr(E^.TM),3);
 DlgText(D,150,60,T3('&Bottom:','&Bas :','&Unten:'));DlgEdit(D,13,210,56,50,IntStr(E^.BM),3);
 DlgButton(D,ID_OK,50,100,80,'OK',True);
 DlgButton(D,ID_CANCEL,150,100,80,T3('Cancel','Annuler','Abbrechen'),False);
 R:=RunDialog(D,@NoHook);
 If R=ID_OK Then Begin
  E^.LM:=Clamp(StrVal(DlgGetText(D,10),10),0,50);E^.RM:=Clamp(StrVal(DlgGetText(D,11),10),0,50);
  E^.TM:=Clamp(StrVal(DlgGetText(D,12),10),0,50);E^.BM:=Clamp(StrVal(DlgGetText(D,13),10),0,50);
 End;
End;

Var FontLst,SizeLst: PStrList;

Procedure WriteFontsDlg(W: PWindow);
Var E: PEd; D: TDlg; R,I: Integer;
Begin
 E:=W^.Data;
 New(FontLst);New(SizeLst);
 FontLst^.N:=5;FontLst^.S[1]:='Courier';FontLst^.S[2]:='Helv';FontLst^.S[3]:='Tms Rmn';
 FontLst^.S[4]:='Modern';FontLst^.S[5]:='Roman';
 SizeLst^.N:=9;
 For I:=1 To 9 Do SizeLst^.S[I]:=IntStr(6+I*2);
 DlgInit(D,'',300,170);
 DlgText(D,10,8,T3('&Fonts:','&Polices :','&Schriften:'));
 DlgText(D,160,8,T3('&Sizes:','&Tailles :','&Gr'#148#225'en:'));
 DlgList(D,10,10,22,130,90,FontLst,2);
 DlgList(D,11,160,22,120,90,SizeLst,3);
 DlgText(D,10,118,T3('Used for printing; the screen uses|the system font.',
   'Utilis'#130'e pour l''impression ; l''|'#130'cran utilise la police syst'#138'me.',
   'F'#129'r den Druck; der Bildschirm|verwendet die Systemschrift.'));
 DlgButton(D,ID_OK,50,140,80,'OK',True);
 DlgButton(D,ID_CANCEL,170,140,80,T3('Cancel','Annuler','Abbrechen'),False);
 R:=RunDialog(D,@NoHook);
 If R=ID_OK Then Begin
  I:=DlgGetVal(D,10);If I>0 Then E^.FontName:=FontLst^.S[I];
  I:=DlgGetVal(D,11);If I>0 Then E^.FontSize:=StrVal(SizeLst^.S[I],10);
  E^.Modified:=True;
 End;
 Dispose(FontLst);Dispose(SizeLst);
End;

Procedure GotoPageDlg(W: PWindow);
Var E: PEd; S: String; P,V: Integer;
Begin
 E:=W^.Data;
 S:='1';
 If InputBox(T3('Go to page:','Aller '#133' la page :','Gehe zu Seite:'),S,5,260) Then Begin
  P:=StrVal(S,1);
  V:=Clamp((P-1)*55,0,E^.NV-1);
  E^.Cur:=E^.VL[V];E^.Anc:=-1;
  W^.VPos:=V;
  Dirty:=True;
 End;
End;

Function EdWinMenu(W: PWindow; Cmd: Integer): Boolean;
Var E: PEd; P: String; R: Integer; V: Integer;
Begin
 EdWinMenu:=True;
 E:=W^.Data;
 Case Cmd Of
  CM_N_NEW: If EdAskSave(W) Then Begin EdClear(E);E^.FileName:='';W^.Title:=EdWinTitle(W);W^.VPos:=0;End;
  CM_N_OPEN: If EdAskSave(W) Then Begin
    P:='';
    If FileDialog(0,T3('Open File Name:','Ouvrir le fichier :','Datei '#148'ffnen:'),
      IfThenS(W^.App=A_WRITE,'*.WRI','*.TXT'),P) Then EdWinLoad(W,P);
   End;
  CM_N_SAVE: Begin
    If E^.FileName='' Then AppMenu(W,CM_N_SAVEAS) Else R:=Ord(EdWinSave(W,E^.FileName));
   End;
  CM_N_SAVEAS: Begin
    P:=E^.FileName;
    If FileDialog(1,T3('Save File Name As:','Enregistrer sous :','Speichern unter:'),
      IfThenS(W^.App=A_WRITE,'*.WRI','*.TXT'),P) Then R:=Ord(EdWinSave(W,P));
   End;
  CM_N_PRINT: EdPrint(W);
  CM_N_EXIT: CloseWindow(W);
  CM_N_ABOUT: If W^.App=A_WRITE Then ShowAboutMs('Write',4,False) Else ShowAboutMs('Notepad',4,False);
  CM_N_UNDO: EdUndo(E);
  CM_N_CUT: EdCut(E);
  CM_N_COPY: EdCopy(E);
  CM_N_PASTE: EdPaste(E);
  CM_N_CLEAR: If EdHasSel(E) Then Begin EdPushUndo(E);EdSelRange(E,V,R);EdDeleteRange(E,V,R);End;
  CM_N_TIME: EdInsertDate(E);
  CM_N_ALL: Begin E^.Anc:=0;E^.Cur:=E^.Len;End;
  CM_N_FIND: EdFindDlg(W,False);
  CM_N_FINDNEXT: If E^.FindStr='' Then EdFindDlg(W,False)
    Else If Not EdFind(E,E^.FindStr,E^.MatchCase,E^.Cur) Then
     InfoBox(T3('Cannot find "','Impossible de trouver "','Kann nicht finden: "')+E^.FindStr+'"');
  CM_N_REPLACE: EdReplaceDlg(W);
  CM_N_GOTO: GotoPageDlg(W);
  CM_W_NORMAL: Begin EdApplyAttr(W,0,1);End;
  CM_W_BOLD: EdApplyAttr(W,AT_BOLD,0);
  CM_W_ITAL: EdApplyAttr(W,AT_ITAL,0);
  CM_W_UNDER: EdApplyAttr(W,AT_UNDER,0);
  CM_W_SUP: Begin EdApplyAttr(W,AT_SUP,0);If (E^.Cur_At And AT_SUP)<>0 Then E^.Cur_At:=E^.Cur_At And (255-AT_SUB);End;
  CM_W_SUB: Begin EdApplyAttr(W,AT_SUB,0);If (E^.Cur_At And AT_SUB)<>0 Then E^.Cur_At:=E^.Cur_At And (255-AT_SUP);End;
  CM_W_FONTS: WriteFontsDlg(W);
  CM_W_LEFT: EdParaAttr(W,3,PA_LEFT);
  CM_W_CENTER: EdParaAttr(W,3,PA_CENTER);
  CM_W_RIGHT: EdParaAttr(W,3,PA_RIGHT);
  CM_W_JUST: EdParaAttr(W,3,PA_JUST);
  CM_W_SINGLE: EdParaAttr(W,$30,0);
  CM_W_ONEHALF: EdParaAttr(W,$30,$10);
  CM_W_DOUBLE: EdParaAttr(W,$30,$20);
  CM_W_PNORMAL: EdParaAttr(W,$33,0);
  CM_W_HEADER: WriteHdrFtr(W,False);
  CM_W_FOOTER: WriteHdrFtr(W,True);
  CM_W_RULER: E^.Ruler:=Not E^.Ruler;
  CM_W_LAYOUT: WriteLayoutDlg(W);
  CM_W_REPAG: InfoBox(T3('Document repaginated: ','Document repagin'#130': ','Dokument neu umbrochen: ')+
     IntStr(E^.NV Div 55+1)+' '+T3('page(s).','page(s).','Seite(n).'));
  CM_W_PRSETUP: InfoBox(T3('Printer: ','Imprimante : ','Drucker: ')+PrinterName+' ('+PrintPort+')');
 Else EdWinMenu:=False;
 End;
 EdLayout(E);
 V:=W^.VPos;
 EdScrollTo(E,V);
 W^.VPos:=V;
End;

Procedure EdWinDraw(W: PWindow);
Var E: PEd; X1,Y1,X2,Y2,I,Rl: Integer; A,B: Integer;
Begin
 E:=W^.Data;
 WinClient(W,X1,Y1,X2,Y2);
 Rl:=0;
 If E^.Ruler Then Begin
  Rl:=14;
  GHLine(X1,X2,Y1+Rl-1,cBlk);
  For I:=0 To (X2-X1) Div 8 Do Begin
   If I Mod 10=0 Then GVLine(X1+4+I*8,Y1+2,Y1+Rl-3,cBlk)
   Else If I Mod 5=0 Then GVLine(X1+4+I*8,Y1+4,Y1+Rl-3,cBlk)
   Else GVLine(X1+4+I*8,Y1+7,Y1+Rl-3,cBlk);
  End;
  GText(X1+6,Y1+3,'',cBlk);
 End;
 E^.X0:=X1;E^.Y0:=Y1+Rl;E^.PW:=X2-X1+1;E^.PH:=Y2-Y1+1-Rl;
 E^.Cols:=(E^.PW-8) Div 8;E^.Rows:=Max2(1,E^.PH Div 12);
 EdLayout(E);
 W^.HasVS:=True;
 W^.VTot:=E^.NV;W^.VPage:=E^.Rows;
 If W^.VPos>E^.NV-1 Then W^.VPos:=Max2(0,E^.NV-1);
 { barre du bas de Write : numero de page }
 EdDraw(E,W^.VPos,W=ActiveWin);
 If W^.App=A_WRITE Then Begin
  { le pied indique la page courante dans la barre de titre }
 End;
End;

Procedure EdWinMouse(W: PWindow; Var E2: TEvent);
Var E: PEd; Off,A,B: Integer;
Begin
 E:=W^.Data;
 Case E2.Kind Of
  EV_DOWN: Begin
    Off:=EdHit(E,W^.VPos,E2.X,E2.Y);
    If E2.Dbl Then Begin
     EdWordAt(E,Off,A,B);E^.Anc:=A;E^.Cur:=B;
    End Else Begin
     E^.Cur:=Off;E^.Anc:=-1;W^.Param:=Off+1;
     Capture:=W;
    End;
    E^.WantCol:=-1;
    If E^.At<>Nil Then Begin
     If (Off>0) And (Off<=E^.Len) Then E^.Cur_At:=E^.At^[Off-1];
    End;
    Invalidate(W);
   End;
  EV_MOVE: If Capture=W Then Begin
    Off:=EdHit(E,W^.VPos,E2.X,E2.Y);
    If E2.Y<E^.Y0 Then Begin If W^.VPos>0 Then Dec(W^.VPos);End;
    If E2.Y>E^.Y0+E^.PH Then Begin If W^.VPos<E^.NV-1 Then Inc(W^.VPos);End;
    If Off<>E^.Cur Then Begin
     If E^.Anc<0 Then E^.Anc:=W^.Param-1;
     E^.Cur:=Off;
     Invalidate(W);
    End;
   End;
 End;
End;

Procedure EdWinKey(W: PWindow; K: Word);
Var E: PEd; V: Integer;
Begin
 E:=W^.Data;
 Case K Of
  K_ALTBS: EdUndo(E);
  K_CTRLINS: EdCopy(E);
  3: EdCopy(E);
  24: EdCut(E);
  22: EdPaste(E);
  1: Begin E^.Anc:=0;E^.Cur:=E^.Len;End;
  K_F3: AppMenu(W,CM_N_FINDNEXT);
  K_F5: If W^.App=A_NOTE Then EdInsertDate(E);
  K_F6: If W^.App=A_WRITE Then AppMenu(W,CM_W_BOLD);
  K_F7: If W^.App=A_WRITE Then AppMenu(W,CM_W_ITAL);
  K_F8: If W^.App=A_WRITE Then AppMenu(W,CM_W_UNDER);
 Else If K<>K_ESC Then EdKey(E,K);
 End;
 EdLayout(E);
 V:=W^.VPos;
 EdScrollTo(E,V);
 W^.VPos:=V;
 If (E^.At<>Nil) And (E^.Cur>0) And (E^.Cur<=E^.Len) And (K=K_LEFT) Then E^.Cur_At:=E^.At^[E^.Cur-1];
 Invalidate(W);
End;

Procedure EdWinPrepare(W: PWindow);
Var E: PEd; At_: Byte; P: Byte; A,B: Integer;
Begin
 E:=W^.Data;
 MenuDisable(W,CM_N_UNDO,Not E^.HasUndo);
 MenuDisable(W,CM_N_CUT,Not EdHasSel(E));
 MenuDisable(W,CM_N_COPY,Not EdHasSel(E));
 MenuDisable(W,CM_N_CLEAR,Not EdHasSel(E));
 MenuDisable(W,CM_N_PASTE,ClipKind<>1);
 If W^.App=A_WRITE Then Begin
  At_:=E^.Cur_At;
  If EdHasSel(E) Then Begin EdSelRange(E,A,B);At_:=E^.At^[A];End;
  MenuCheck(W,CM_W_BOLD,(At_ And AT_BOLD)<>0);MenuCheck(W,CM_W_ITAL,(At_ And AT_ITAL)<>0);
  MenuCheck(W,CM_W_UNDER,(At_ And AT_UNDER)<>0);MenuCheck(W,CM_W_SUP,(At_ And AT_SUP)<>0);
  MenuCheck(W,CM_W_SUB,(At_ And AT_SUB)<>0);MenuCheck(W,CM_W_NORMAL,At_=0);
  P:=E^.PA^[ParaOf(E,E^.Cur)];
  MenuCheck(W,CM_W_LEFT,(P And 3)=0);MenuCheck(W,CM_W_CENTER,(P And 3)=1);
  MenuCheck(W,CM_W_RIGHT,(P And 3)=2);MenuCheck(W,CM_W_JUST,(P And 3)=3);
  MenuCheck(W,CM_W_SINGLE,((P Shr 4) And 3)=0);MenuCheck(W,CM_W_ONEHALF,((P Shr 4) And 3)=1);
  MenuCheck(W,CM_W_DOUBLE,((P Shr 4) And 3)=2);
  MenuCheck(W,CM_W_RULER,E^.Ruler);
 End;
End;

Procedure EdAddEditMenu(W: PWindow);
Begin
 WinAddMenu(W,'&Edit~&'#144'dition~&Bearbeiten');
 WinAddItem(W,'&Undo~&Annuler~&R'#129'ckg'#132'ngig',CM_N_UNDO,'Alt+BkSp');
 WinAddSep(W);
 WinAddItem(W,'Cu&t~Co&uper~&Ausschneiden',CM_N_CUT,'Ctrl+X');
 WinAddItem(W,'&Copy~&Copier~&Kopieren',CM_N_COPY,'Ctrl+Ins');
 WinAddItem(W,'&Paste~Co&ller~&Einf'#129'gen',CM_N_PASTE,'Ctrl+V');
 WinAddItem(W,'C&lear~E&facer~&L'#148'schen',CM_N_CLEAR,'Del');
End;

Function NotepadCreate(Const Path: String): PWindow;
Var W: PWindow; E: PEd;
Begin
 W:=NewWindow(A_NOTE,'Notepad',-1,-1,440,300,True);
 If W=Nil Then Begin NotepadCreate:=Nil;Exit;End;
 E:=EdNew(False);W^.Data:=E;W^.HasVS:=True;
 WinAddMenu(W,'&File~&Fichier~&Datei');
 WinAddItem(W,'&New~&Nouveau~&Neu',CM_N_NEW,'');
 WinAddItem(W,'&Open...~&Ouvrir...~'#142'&ffnen...',CM_N_OPEN,'');
 WinAddItem(W,'&Save~&Enregistrer~&Speichern',CM_N_SAVE,'');
 WinAddItem(W,'Save &As...~Enregistrer &sous...~Speichern &unter...',CM_N_SAVEAS,'');
 WinAddItem(W,'&Print~&Imprimer~&Drucken',CM_N_PRINT,'');
 WinAddItem(W,'E&xit~&Quitter~&Beenden',CM_N_EXIT,'');
 WinAddItem(W,'A&bout Notepad...~&'#133' propos de Notepad...~'#154'&ber Notepad...',CM_N_ABOUT,'');
 EdAddEditMenu(W);
 WinAddItem(W,'Time/&Date~Heure/&Date~Zeit/&Datum',CM_N_TIME,'F5');
 WinAddMenu(W,'&Search~&Recherche~&Suchen');
 WinAddItem(W,'&Find...~&Rechercher...~&Suchen...',CM_N_FIND,'');
 WinAddItem(W,'Find &Next~&Suivant~&Weitersuchen',CM_N_FINDNEXT,'F3');
 EdLayout(E);
 W^.Title:=EdWinTitle(W);
 If Path<>'' Then EdWinLoad(W,Path);
 NotepadCreate:=W;
End;

Function WriteCreate(Const Path: String): PWindow;
Var W: PWindow; E: PEd;
Begin
 W:=NewWindow(A_WRITE,'Write',-1,-1,520,330,True);
 If W=Nil Then Begin WriteCreate:=Nil;Exit;End;
 E:=EdNew(True);W^.Data:=E;W^.HasVS:=True;
 E^.LM:=12;E^.RM:=12;E^.TM:=10;E^.BM:=10;E^.FontName:='Courier';E^.FontSize:=10;
 WinAddMenu(W,'&File~&Fichier~&Datei');
 WinAddItem(W,'&New~&Nouveau~&Neu',CM_N_NEW,'');
 WinAddItem(W,'&Open...~&Ouvrir...~'#142'&ffnen...',CM_N_OPEN,'');
 WinAddItem(W,'&Save~&Enregistrer~&Speichern',CM_N_SAVE,'');
 WinAddItem(W,'Save &As...~Enregistrer &sous...~Speichern &unter...',CM_N_SAVEAS,'');
 WinAddItem(W,'&Print...~&Imprimer...~&Drucken...',CM_N_PRINT,'');
 WinAddItem(W,'Printer Set&up...~Configuration de l''&imprimante...~Druckere&inrichtung...',CM_W_PRSETUP,'');
 WinAddItem(W,'&Repaginate...~Re&paginer...~&Neu umbrechen...',CM_W_REPAG,'');
 WinAddItem(W,'E&xit~&Quitter~&Beenden',CM_N_EXIT,'');
 WinAddItem(W,'A&bout Write...~&'#133' propos de Write...~'#154'&ber Write...',CM_N_ABOUT,'');
 EdAddEditMenu(W);
 WinAddMenu(W,'&Search~&Recherche~&Suchen');
 WinAddItem(W,'&Find...~&Rechercher...~&Suchen...',CM_N_FIND,'');
 WinAddItem(W,'&Repeat Last Find~R'#130'&p'#130'ter la recherche~&Wiederholen',CM_N_FINDNEXT,'F3');
 WinAddItem(W,'Re&place...~Rem&placer...~&Ersetzen...',CM_N_REPLACE,'');
 WinAddItem(W,'&Go To Page...~&Atteindre la page...~&Gehe zu Seite...',CM_N_GOTO,'');
 WinAddMenu(W,'&Character~&Caract'#138're~&Zeichen');
 WinAddItem(W,'&Normal~&Normal~&Normal',CM_W_NORMAL,'');
 WinAddItem(W,'&Bold~&Gras~&Fett',CM_W_BOLD,'F6');
 WinAddItem(W,'&Italic~&Italique~&Kursiv',CM_W_ITAL,'F7');
 WinAddItem(W,'&Underline~&Soulign'#130'~&Unterstrichen',CM_W_UNDER,'F8');
 WinAddSep(W);
 WinAddItem(W,'Su&perscript~Ex&posant~&Hochgestellt',CM_W_SUP,'');
 WinAddItem(W,'Su&bscript~&Indice~&Tiefgestellt',CM_W_SUB,'');
 WinAddSep(W);
 WinAddItem(W,'&Fonts...~&Polices...~&Schriften...',CM_W_FONTS,'');
 WinAddMenu(W,'&Paragraph~Pa&ragraphe~&Absatz');
 WinAddItem(W,'&Normal~&Normal~&Normal',CM_W_PNORMAL,'');
 WinAddItem(W,'&Left~&Gauche~&Links',CM_W_LEFT,'');
 WinAddItem(W,'&Centered~&Centr'#130'~&Zentriert',CM_W_CENTER,'');
 WinAddItem(W,'&Right~&Droite~&Rechts',CM_W_RIGHT,'');
 WinAddItem(W,'&Justified~&Justifi'#130'~&Blocksatz',CM_W_JUST,'');
 WinAddSep(W);
 WinAddItem(W,'&Single Space~&Interligne simple~&Einfach',CM_W_SINGLE,'');
 WinAddItem(W,'1&1/2 Space~Interligne 1&,5~1,&5-fach',CM_W_ONEHALF,'');
 WinAddItem(W,'&Double Space~Interligne &double~&Doppelt',CM_W_DOUBLE,'');
 WinAddMenu(W,'&Document~&Document~&Dokument');
 WinAddItem(W,'&Header...~&En-t'#136'te...~&Kopfzeile...',CM_W_HEADER,'');
 WinAddItem(W,'&Footer...~&Pied de page...~&Fu'#225'zeile...',CM_W_FOOTER,'');
 WinAddItem(W,'&Ruler On/Off~&R'#133'gle~&Lineal',CM_W_RULER,'');
 WinAddItem(W,'&Page Layout...~&Mise en page...~&Seitenlayout...',CM_W_LAYOUT,'');
 EdLayout(E);
 W^.Title:=EdWinTitle(W);
 If Path<>'' Then EdWinLoad(W,Path);
 WriteCreate:=W;
End;

Procedure EdWinClose(W: PWindow);
Begin
 EdFree(W^.Data);
 W^.Data:=Nil;
End;

Procedure EdWinTimer(W: PWindow);
Begin
 If (W=ActiveWin) And (NowCs Div BlinkHalf<>LastBlink) Then Begin
  LastBlink:=NowCs Div BlinkHalf;
  Invalidate(W);
 End;
End;

{ ====================================================================== }
{          CALCULATOR, CLOCK, CLIPBOARD, SPOOLER                         }
{ ====================================================================== }

Const
 CM_C_COPY=301; CM_C_PASTE=302; CM_C_ABOUT=303;
 CM_K_ANALOG=311; CM_K_DIGITAL=312; CM_K_ABOUT=313;
 CM_B_DEL=321; CM_B_EXIT=322; CM_B_ABOUT=323;
 CM_S_LOW=331; CM_S_HIGH=332; CM_S_EXIT=333; CM_S_ABOUT=334;
 CM_S_PAUSE=341; CM_S_RESUME=342; CM_S_TERM=343;

Type
 PCalc = ^TCalc;
 TCalc = Record
  Disp  : String[24];
  Acc,Mem : Double;
  Op    : Char;
  NewEnt: Boolean;
  Err   : Boolean;
  Pressed: Integer;
 End;

Const
 CalcKeys : Array[0..23] Of String[2] = (
  'MC','7','8','9','/','Q',
  'MR','4','5','6','*','%',
  'M+','1','2','3','-','C',
  'M-','0','.','~','+','=');
 CALC_BW = 36; CALC_BH = 26; CALC_GX = 8; CALC_GY = 10;

Function CalcFmt(V: Double): String;
Var S: String; N: Integer;
Begin
 If (Abs(V)>=1E13) Then Begin CalcFmt:='E';Exit;End;
 Str(V:0:9,S);
 While (Length(S)>0) And (S[Length(S)]='0') Do Delete(S,Length(S),1);
 If (S<>'') And (S[Length(S)]='.') Then ;
 If Pos('.',S)=0 Then S:=S+'.';
 If Length(S)>14 Then S:=Copy(S,1,14);
 If (S='-0.') Then S:='0.';
 CalcFmt:=S;
End;

Function CalcVal(C: PCalc): Double;
Var V: Double; E: Integer; S: String;
Begin
 S:=C^.Disp;
 If (S<>'') And (S[Length(S)]='.') Then Delete(S,Length(S),1);
 Val(S,V,E);
 If E<>0 Then V:=0;
 CalcVal:=V;
End;

Procedure CalcClear(C: PCalc);
Begin
 C^.Disp:='0.';C^.Acc:=0;C^.Op:=#0;C^.NewEnt:=True;C^.Err:=False;
End;

Procedure CalcApply(C: PCalc);
Var V: Double;
Begin
 V:=CalcVal(C);
 Case C^.Op Of
  '+': C^.Acc:=C^.Acc+V;
  '-': C^.Acc:=C^.Acc-V;
  '*': C^.Acc:=C^.Acc*V;
  '/': If V=0 Then C^.Err:=True Else C^.Acc:=C^.Acc/V;
 Else C^.Acc:=V;
 End;
 If C^.Err Or (Abs(C^.Acc)>=1E13) Then Begin C^.Err:=True;C^.Disp:='E';End
 Else C^.Disp:=CalcFmt(C^.Acc);
End;

Procedure CalcPress(C: PCalc; K: String);
Var V: Double; Ch: Char; S: String;
Begin
 If C^.Err And (K<>'C') Then Exit;
 Ch:=K[1];
 If (Length(K)=1) And (Ch>='0') And (Ch<='9') Then Begin
  If C^.NewEnt Then Begin C^.Disp:=Ch;C^.NewEnt:=False;End
  Else If Length(C^.Disp)<12 Then Begin
   If C^.Disp='0' Then C^.Disp:=Ch Else C^.Disp:=C^.Disp+Ch;
  End;
  Exit;
 End;
 If (K='.') Then Begin
  If C^.NewEnt Then Begin C^.Disp:='0.';C^.NewEnt:=False;
  End Else If Pos('.',C^.Disp)=0 Then C^.Disp:=C^.Disp+'.';
  Exit;
 End;
 If (K='+') Or (K='-') Or (K='*') Or (K='/') Or (K='=') Then Begin
  If Not C^.NewEnt Or (C^.Op=#0) Then CalcApply(C);
  C^.Op:=Ch;
  If K='=' Then C^.Op:=#0;
  C^.NewEnt:=True;
  Exit;
 End;
 If K='C' Then Begin CalcClear(C);Exit;End;
 If K='~' Then Begin
  If C^.Disp<>'0.' Then Begin
   If C^.Disp[1]='-' Then Delete(C^.Disp,1,1) Else C^.Disp:='-'+C^.Disp;
  End;
  Exit;
 End;
 If K='Q' Then Begin
  V:=CalcVal(C);
  If V<0 Then Begin C^.Err:=True;C^.Disp:='E';End
  Else Begin C^.Disp:=CalcFmt(Sqrt(V));C^.NewEnt:=True;End;
  Exit;
 End;
 If K='%' Then Begin
  V:=CalcVal(C);
  C^.Disp:=CalcFmt(C^.Acc*V/100);C^.NewEnt:=False;
  Exit;
 End;
 If K='MC' Then Begin C^.Mem:=0;Exit;End;
 If K='MR' Then Begin C^.Disp:=CalcFmt(C^.Mem);C^.NewEnt:=True;Exit;End;
 If K='M+' Then Begin C^.Mem:=C^.Mem+CalcVal(C);C^.NewEnt:=True;Exit;End;
 If K='M-' Then Begin C^.Mem:=C^.Mem-CalcVal(C);C^.NewEnt:=True;Exit;End;
End;

Function CalcBtnRect(W: PWindow; I: Integer; Var X1,Y1,X2,Y2: Integer): Boolean;
Var CX1_,CY1_,CX2_,CY2_,R,Cc: Integer;
Begin
 WinClient(W,CX1_,CY1_,CX2_,CY2_);
 R:=I Div 6;Cc:=I Mod 6;
 X1:=CX1_+12+Cc*(CALC_BW+CALC_GX);
 Y1:=CY1_+50+R*(CALC_BH+CALC_GY);
 X2:=X1+CALC_BW-1;Y2:=Y1+CALC_BH-1;
 CalcBtnRect:=True;
End;

Procedure CalcDraw(W: PWindow);
Var C: PCalc; X1,Y1,X2,Y2,I,A,B,CC,DD: Integer; T: String; Bn: Boolean;
Begin
 C:=W^.Data;
 WinClient(W,X1,Y1,X2,Y2);
 GDither(X1,Y1,X2,Y2,cLBl,cWht);
 GRoundFill(X1+36,Y1+10,X2-12,Y1+36,cBlk,cWht);
 T:=C^.Disp;
 GText(X2-20-Length(T)*8,Y1+19,T,cBlk);
 If C^.Mem<>0 Then GText(X1+44,Y1+19,'M',cBlk);
 For I:=0 To 23 Do Begin
  CalcBtnRect(W,I,A,B,CC,DD);
  Bn:=(C^.Pressed=I+1);
  If Bn Then GRoundFill(A,B,CC,DD,cBlk,cBlk) Else GRoundFill(A,B,CC,DD,cBlk,cWht);
  T:=CalcKeys[I];
  If T='Q' Then Begin
   GText(A+6,B+9,#251,IfThen_(Bn,cWht,cBlk));GHLine(A+14,A+25,B+7,IfThen_(Bn,cWht,cBlk));
  End Else Begin
   If T='~' Then T:=#241;
   GText(A+(CALC_BW-Length(T)*8) Div 2,B+9,T,IfThen_(Bn,cWht,cBlk));
  End;
 End;
End;

Procedure CalcMouse(W: PWindow; Var E: TEvent);
Var C: PCalc; I,A,B,CC,DD: Integer; K: String;
Begin
 C:=W^.Data;
 If E.Kind=EV_DOWN Then Begin
  For I:=0 To 23 Do Begin
   CalcBtnRect(W,I,A,B,CC,DD);
   If InBox(E.X,E.Y,A,B,CC,DD) Then Begin C^.Pressed:=I+1;Capture:=W;Invalidate(W);End;
  End;
 End Else If E.Kind=EV_UP Then Begin
  If C^.Pressed>0 Then Begin
   I:=C^.Pressed-1;
   CalcBtnRect(W,I,A,B,CC,DD);
   If InBox(E.X,E.Y,A,B,CC,DD) Then CalcPress(C,CalcKeys[I]);
   C^.Pressed:=0;Invalidate(W);
  End;
 End;
End;

Procedure CalcKey(W: PWindow; K: Word);
Var C: PCalc; S: String;
Begin
 C:=W^.Data;
 S:='';
 If (K>=48) And (K<=57) Then S:=Chr(K)
 Else Case K Of
  43: S:='+'; 45: S:='-'; 42: S:='*'; 47: S:='/'; 46,44: S:='.'; 61,K_ENTER: S:='=';
  37: S:='%'; 99,67,K_ESC: S:='C';
  K_BKSP: If (Length(C^.Disp)>1) And Not C^.NewEnt Then Begin
     Delete(C^.Disp,Length(C^.Disp),1);
     If (C^.Disp='') Or (C^.Disp='-') Then C^.Disp:='0';
    End;
  3: Begin AppMenu(W,CM_C_COPY);End;
  22: Begin AppMenu(W,CM_C_PASTE);End;
 End;
 If S<>'' Then CalcPress(C,S);
 Invalidate(W);
End;

Procedure CalcMenu(W: PWindow; Cmd: Integer);
Var C: PCalc; S: String; I: Integer; V: Double; E: Integer;
Begin
 C:=W^.Data;
 Case Cmd Of
  CM_C_COPY: Begin S:=C^.Disp;ClipSetText(S[1],Length(S));End;
  CM_C_PASTE: If (ClipKind=1) And (ClipLen>0) Then Begin
    S:='';
    For I:=0 To Min2(ClipLen,20)-1 Do
     If ClipTxt[I] In ['0'..'9','.','-'] Then S:=S+ClipTxt[I];
    Val(S,V,E);
    If (E=0) And (S<>'') Then Begin C^.Disp:=CalcFmt(V);C^.NewEnt:=False;End;
   End;
  CM_C_ABOUT: ShowAboutMs('Calculator',1,False);
 End;
End;

Function CalcCreate: PWindow;
Var W: PWindow; C: PCalc;
Begin
 W:=NewWindow(A_CALC,'Calculator',-1,-1,6*CALC_BW+5*CALC_GX+24+2*3+0,50+4*(CALC_BH+CALC_GY)+17+17+8,False);
 If W=Nil Then Begin CalcCreate:=Nil;Exit;End;
 New(C);FillChar(C^,SizeOf(TCalc),0);CalcClear(C);
 W^.Data:=C;
 WinAddMenu(W,'&Edit~&'#144'dition~&Bearbeiten');
 WinAddItem(W,'&Copy~&Copier~&Kopieren',CM_C_COPY,'Ctrl+Ins');
 WinAddItem(W,'&Paste~Co&ller~&Einf'#129'gen',CM_C_PASTE,'Shift+Ins');
 WinAddItem(W,'&About Calculator...~&'#133' propos de Calculator...~'#154'&ber Calculator...',CM_C_ABOUT,'');
 CalcCreate:=W;
End;

{ ---------------- CLOCK ---------------- }

Type
 PClock = ^TClock;
 TClock = Record
  Digital : Boolean;
  LastSec : Integer;
 End;

Procedure DrawClockFace(CXp,CYp,R: Integer; H,M,S: Integer; Mini: Boolean);
Var I,X1,Y1,X2,Y2: Integer; A: Double;
Begin
 GFillEllipse(CXp,CYp,R,R,cWht);
 GEllipse(CXp,CYp,R,R,cBlk);
 If Not Mini Then GEllipse(CXp,CYp,R-1,R-1,cBlk);
 For I:=0 To 11 Do Begin
  A:=I*Pi/6;
  X1:=CXp+Round(Sin(A)*(R-3));Y1:=CYp-Round(Cos(A)*(R-3));
  If Mini Then Begin If I Mod 3=0 Then GPix(X1,Y1,cBlk);End
  Else Begin
   X2:=CXp+Round(Sin(A)*(R-IfThen_(I Mod 3=0,10,6)));
   Y2:=CYp-Round(Cos(A)*(R-IfThen_(I Mod 3=0,10,6)));
   GLine(X1,Y1,X2,Y2,cBlk);
  End;
 End;
 A:=((H Mod 12)*60+M)*Pi/360;
 GLine(CXp,CYp,CXp+Round(Sin(A)*R*0.5),CYp-Round(Cos(A)*R*0.5),cBlk);
 If Not Mini Then GLine(CXp+1,CYp,CXp+1+Round(Sin(A)*R*0.5),CYp-Round(Cos(A)*R*0.5),cBlk);
 A:=(M*60+S)*Pi/1800;
 GLine(CXp,CYp,CXp+Round(Sin(A)*R*0.8),CYp-Round(Cos(A)*R*0.8),cBlk);
 If Not Mini Then Begin
  A:=S*Pi/30;
  GLine(CXp,CYp,CXp+Round(Sin(A)*(R-4)),CYp-Round(Cos(A)*(R-4)),cDGr);
 End;
End;

Procedure ClockDraw(W: PWindow);
Var C: PClock; X1,Y1,X2,Y2,H,M,S,R,Y,Mo,D: Integer; T: String;
Begin
 C:=W^.Data;
 WinClient(W,X1,Y1,X2,Y2);
 GetNow(H,M,S);GetToday(Y,Mo,D);
 If C^.Digital Then Begin
  T:=TimeStr(H,M,S);
  GTextBig((X1+X2) Div 2-Length(T)*8,(Y1+Y2) Div 2-14,T,2,cBlk);
  T:=DayName(DayOfWeek(Y,Mo,D))+' '+DateStr(Y,Mo,D);
  GText((X1+X2) Div 2-Length(T)*4,(Y1+Y2) Div 2+14,T,cBlk);
 End Else Begin
  R:=Min2(X2-X1,Y2-Y1) Div 2-6;
  DrawClockFace((X1+X2) Div 2,(Y1+Y2) Div 2,R,H,M,S,False);
 End;
End;

Procedure ClockTimer(W: PWindow);
Var C: PClock; H,M,S: Integer;
Begin
 C:=W^.Data;
 GetNow(H,M,S);
 If S<>C^.LastSec Then Begin
  C^.LastSec:=S;
  If W^.State=1 Then Dirty:=True Else Invalidate(W);
 End;
End;

Procedure ClockMenu(W: PWindow; Cmd: Integer);
Var C: PClock;
Begin
 C:=W^.Data;
 Case Cmd Of
  CM_K_ANALOG: C^.Digital:=False;
  CM_K_DIGITAL: C^.Digital:=True;
  CM_K_ABOUT: ShowAboutMs('Clock',4,False);
 End;
 Dirty:=True;
End;

Function ClockCreate: PWindow;
Var W: PWindow; C: PClock;
Begin
 W:=NewWindow(A_CLOCK,'Clock',-1,-1,200,240,True);
 If W=Nil Then Begin ClockCreate:=Nil;Exit;End;
 New(C);FillChar(C^,SizeOf(TClock),0);
 W^.Data:=C;
 WinAddMenu(W,'&Settings~&Param'#138'tres~&Einstellungen');
 WinAddItem(W,'&Analog~&Analogique~&Analog',CM_K_ANALOG,'');
 WinAddItem(W,'&Digital~&Num'#130'rique~&Digital',CM_K_DIGITAL,'');
 WinAddSep(W);
 WinAddItem(W,'A&bout Clock...~&'#133' propos de Clock...~'#154'&ber Clock...',CM_K_ABOUT,'');
 ClockCreate:=W;
End;

{ ---------------- CLIPBOARD ---------------- }

{ dimensions du contenu : lignes, colonnes (texte) ou pixels (bitmap) }
Procedure ClipExtent(Var Lines,Cols: Integer);
Var I,Col: Integer;
Begin
 Lines:=0;Cols:=0;
 If ClipKind=1 Then Begin
  Lines:=1;Col:=0;
  For I:=0 To ClipLen-1 Do
   If ClipTxt[I]=#13 Then Begin Inc(Lines);Col:=0;End
   Else If ClipTxt[I]<>#10 Then Begin Inc(Col);If Col>Cols Then Cols:=Col;End;
 End Else If (ClipKind=2) And (ClipBmp<>Nil) Then Begin
  Lines:=(ClipBmpH+9) Div 10;Cols:=(ClipBmpW+7) Div 8;
 End;
End;

Procedure ClipDraw(W: PWindow);
Var X1,Y1,X2,Y2,I,Row,Col,L,C,Pg,Pw: Integer; Ch: Char; P: PByteArr_; X,Y: Integer; Lab: String;
Begin
 ClipExtent(L,C);
 { barres de defilement selon le contenu }
 WinClient(W,X1,Y1,X2,Y2);
 W^.HasVS:=L*10>(Y2-Y1-18);
 W^.HasHS:=C*8>(X2-X1-8);
 WinClient(W,X1,Y1,X2,Y2);
 W^.HasVS:=L*10>(Y2-Y1-18);
 W^.HasHS:=C*8>(X2-X1-8);
 WinClient(W,X1,Y1,X2,Y2);
 Pg:=Max2(1,(Y2-Y1-18) Div 10);Pw:=Max2(1,(X2-X1-8) Div 8);
 W^.VTot:=Max2(L,1);W^.VPage:=Pg;W^.HTot:=Max2(C,1);W^.HPage:=Pw;
 If W^.VPos>W^.VTot-W^.VPage Then W^.VPos:=Max2(0,W^.VTot-W^.VPage);
 If W^.HPos>W^.HTot-W^.HPage Then W^.HPos:=Max2(0,W^.HTot-W^.HPage);
 { barre indiquant le type de contenu }
 Case ClipKind Of
  1: Lab:='Text';
  2: Lab:=T3('Bitmap','Bitmap','Bitmap');
 Else Lab:='';
 End;
 If ClipKind=1 Then Lab:=T3('Text','Texte','Text');
 GText(X1+4,Y1+3,Lab,cBlk);
 GHLine(X1,X2,Y1+13,cBlk);
 If ClipKind=1 Then Begin
  Row:=0;Col:=0;
  For I:=0 To ClipLen-1 Do Begin
   Ch:=ClipTxt[I];
   If Ch=#13 Then Begin Inc(Row);Col:=0;End
   Else If Ch<>#10 Then Begin
    If (Row>=W^.VPos) And (Col>=W^.HPos) And (X1+4+(Col-W^.HPos)*8<=X2-8) And (Y1+16+(Row-W^.VPos)*10<=Y2-8) Then
     GText(X1+4+(Col-W^.HPos)*8,Y1+16+(Row-W^.VPos)*10,Ch,cBlk);
    Inc(Col);
   End;
  End;
 End Else If (ClipKind=2) And (ClipBmp<>Nil) Then Begin
  P:=ClipBmp;
  For Y:=W^.VPos*10 To Min2(ClipBmpH-1,W^.VPos*10+Y2-Y1-20) Do
   For X:=W^.HPos*8 To Min2(ClipBmpW-1,W^.HPos*8+X2-X1-8) Do
    If P^[Y*ClipBmpW+X]<>0 Then GPix(X1+2+X-W^.HPos*8,Y1+16+Y-W^.VPos*10,cBlk);
 End;
End;

Procedure ClipMenu(W: PWindow; Cmd: Integer);
Begin
 Case Cmd of
  CM_B_DEL: Begin ClipClear;End;
  CM_B_EXIT: CloseWindow(W);
  CM_B_ABOUT: ShowAboutMs('Clipboard',4,False);
 End;
 Dirty:=True;
End;


Function ClipCreate: PWindow;
Var W: PWindow;
Begin
 W:=NewWindow(A_CLIP,'Clipboard',-1,-1,320,200,True);
 If W=Nil Then Begin ClipCreate:=Nil;Exit;End;
 WinAddMenu(W,'&File~&Fichier~&Datei');
 WinAddItem(W,'E&xit~&Quitter~&Beenden',CM_B_EXIT,'');
 WinAddItem(W,'A&bout Clipboard...~&'#133' propos de Clipboard...~'#154'&ber Clipboard...',CM_B_ABOUT,'');
 WinAddMenu(W,'&Edit~&'#144'dition~&Bearbeiten');
 WinAddItem(W,'&Delete~&Supprimer~&L'#148'schen',CM_B_DEL,'');
 ClipCreate:=W;
End;

{ ---------------- SPOOLER ---------------- }

Var
 SpoolSel : Integer;
 SpoolJobTime: LongInt;

Procedure SpoolDraw(W: PWindow);
Var X1,Y1,X2,Y2,I: Integer; T: String;
Begin
 WinClient(W,X1,Y1,X2,Y2);
 { ligne d'etat du port : LPT1: Printing Epson FX-80 }
 T:=PadR(PrintPort+':',6);
 If SpoolN=0 Then T:=T+T3('Idle ','Libre ','Frei ')
 Else If SpoolPaused Then T:=T+T3('Paused ','En pause ','Angehalten ')
 Else T:=T+T3('Printing ','Impression ','Druckt ');
 GText(X1+6,Y1+4,T+PrinterName,cBlk);
 GHLine(X1,X2,Y1+16,cBlk);
 If SpoolN=0 Then GText(X1+6,Y1+24,T3('(No jobs in queue)','(Aucun travail en attente)','(Keine Auftr'#132'ge)'),cDGr);
 For I:=1 To SpoolN Do Begin
  T:=SpoolNames[I];
  If I=1 Then Begin
   If SpoolPaused Then T:=T+'  ['+T3('paused','en pause','angehalten')+']'
   Else T:=T+'  ['+IntStr(Clamp((NowCs-SpoolT0)*100 Div Max2(1,SpoolJobTime),0,99))+'%]';
  End;
  If I=SpoolSel Then Begin GBar(X1+4,Y1+22+(I-1)*12,X1+8+Length(T)*8,Y1+32+(I-1)*12,cBlk);
   GText(X1+6,Y1+24+(I-1)*12,T,cWht);End
  Else GText(X1+6,Y1+24+(I-1)*12,T,cBlk);
 End;
End;

Procedure SpoolKey(W: PWindow; K: Word);
Begin
 If SpoolN=0 Then Exit;
 If SpoolSel<1 Then SpoolSel:=1;
 If K=K_UP Then Dec(SpoolSel);
 If K=K_DOWN Then Inc(SpoolSel);
 SpoolSel:=Clamp(SpoolSel,1,SpoolN);
 Dirty:=True;
End;

Procedure SpoolMouse(W: PWindow; Var E: TEvent);
Var X1,Y1,X2,Y2,I: Integer;
Begin
 If E.Kind<>EV_DOWN Then Exit;
 WinClient(W,X1,Y1,X2,Y2);
 I:=(E.Y-Y1-22) Div 12+1;
 If (I>=1) And (I<=SpoolN) Then Begin SpoolSel:=I;Dirty:=True;End;
End;

{ envoie le travail vers le port (fichier LPT1.PRN, COM1.PRN... ou fichier choisi) }
Procedure SpoolDeliver(I: Integer);
Var F,G: Text; Fn,L: String; N: Integer;
Begin
 If (I<1) Or (I>SpoolN) Then Exit;
 Fn:=SpoolPort[I];
 If (Fn='LPT1') Or (Fn='LPT2') Or (Fn='COM1') Or (Fn='COM2') Then Fn:=Fn+'.PRN';
 If Fn='' Then Exit;
 {$I-}
 Assign(F,JoinPath(V2R('C:\'),Fn));
 If FileExists(JoinPath(V2R('C:\'),Fn)) Then Append(F) Else Rewrite(F);
 If IOResult=0 Then Begin
  WriteLn(F,'*** ',SpoolPrn[I],' (',SpoolPort[I],') - ',SpoolNames[I],' - ',
   IfThenS(PrnOrient=0,'Portrait','Landscape'),', ',PaperNames[PrnPaper],' ***');
  If SpoolSrc[I]<>'' Then Begin
   Assign(G,V2R(SpoolSrc[I]));Reset(G);
   If IOResult=0 Then Begin
    N:=0;
    While (Not Eof(G)) And (N<5000) Do Begin ReadLn(G,L);WriteLn(F,L);Inc(N);End;
    Close(G);
   End;
  End;
  WriteLn(F,#12);
  Close(F);
 End;
 {$I+}
 If IOResult<>0 Then ;
End;

Procedure SpoolRemove(I: Integer);
Var K: Integer;
Begin
 If (I<1) Or (I>SpoolN) Then Exit;
 For K:=I To SpoolN-1 Do Begin
  SpoolNames[K]:=SpoolNames[K+1];SpoolPort[K]:=SpoolPort[K+1];SpoolPrn[K]:=SpoolPrn[K+1];SpoolSrc[K]:=SpoolSrc[K+1];
 End;
 Dec(SpoolN);
 If I=1 Then SpoolT0:=NowCs;
 If SpoolSel>SpoolN Then SpoolSel:=SpoolN;
End;

Procedure SpoolTimer(W: PWindow);
Begin
 If SpoolN>0 Then Begin
  If SpoolPaused Then SpoolT0:=NowCs+0
  Else If NowCs-SpoolT0>=SpoolJobTime Then Begin SpoolDeliver(1);SpoolRemove(1);End
  Else If (NowCs Div 25) Mod 2=0 Then Invalidate(W);
 End;
End;

Procedure SpoolMenu(W: PWindow; Cmd: Integer);
Begin
 Case Cmd Of
  CM_S_LOW: Begin SpoolPrio:=0;SpoolJobTime:=800;End;
  CM_S_HIGH: Begin SpoolPrio:=1;SpoolJobTime:=300;End;
  CM_S_EXIT: Begin
    If (SpoolN=0) Or (MsgBox(T3('Print jobs in the queue will be terminated.',
     'Les travaux d''impression en attente seront annul'#130's.',
     'Die Druckauftr'#132'ge in der Warteschlange werden beendet.'),1,2)=ID_OK) Then Begin
     SpoolN:=0;CloseWindow(W);End;
   End;
  CM_S_ABOUT: ShowAboutMs('Spooler',4,False);
  CM_S_PAUSE: SpoolPaused:=True;
  CM_S_RESUME: Begin SpoolPaused:=False;SpoolT0:=NowCs;End;
  CM_S_TERM: If (SpoolN>0) And (MsgBox(T3('Terminate '+SpoolNames[Max2(1,SpoolSel)]+'?','Annuler '+SpoolNames[Max2(1,SpoolSel)]+' ?',
     SpoolNames[Max2(1,SpoolSel)]+' abbrechen?'),1,2)=ID_OK) Then SpoolRemove(Max2(1,SpoolSel));
 End;
 Dirty:=True;
End;

Procedure SpoolPrepare(W: PWindow);
Begin
 MenuCheck(W,CM_S_LOW,SpoolPrio=0);MenuCheck(W,CM_S_HIGH,SpoolPrio=1);
 MenuDisable(W,CM_S_PAUSE,SpoolPaused Or (SpoolN=0));
 MenuDisable(W,CM_S_RESUME,Not SpoolPaused);
 MenuDisable(W,CM_S_TERM,SpoolN=0);
End;

Function SpoolCreate: PWindow;
Var W: PWindow;
Begin
 W:=NewWindow(A_SPOOL,'Spooler',-1,-1,420,170,True);
 If W=Nil Then Begin SpoolCreate:=Nil;Exit;End;
 If SpoolJobTime=0 Then SpoolJobTime:=800;
 SpoolT0:=NowCs;
 WinAddMenu(W,'&Priority~&Priorit'#130'~&Priorit'#132't');
 WinAddItem(W,'&Low~&Basse~&Niedrig',CM_S_LOW,'');
 WinAddItem(W,'&High~&Haute~&Hoch',CM_S_HIGH,'');
 WinAddSep(W);
 WinAddItem(W,'E&xit~&Quitter~&Beenden',CM_S_EXIT,'');
 WinAddItem(W,'A&bout Spooler...~&'#133' propos de Spooler...~'#154'&ber Spooler...',CM_S_ABOUT,'');
 WinAddMenu(W,'&Queue~&File d''attente~&Warteschlange');
 WinAddItem(W,'&Pause~&Pause~&Anhalten',CM_S_PAUSE,'');
 WinAddItem(W,'&Resume~&Reprendre~&Fortsetzen',CM_S_RESUME,'');
 WinAddItem(W,'&Terminate~&Annuler~&Abbrechen',CM_S_TERM,'');
 SpoolCreate:=W;
End;

{ ====================================================================== }
{                              REVERSI                                   }
{ ====================================================================== }

Const
 CM_R_NEW=351; CM_R_HINT=352; CM_R_PASS=353; CM_R_ABOUT=354;
 CM_R_BEG=361; CM_R_NOV=362; CM_R_MAS=363; CM_R_EXP=364;
 RWeight : Array[0..7,0..7] Of Integer = (
  (100,-20,10,5,5,10,-20,100),(-20,-50,-2,-2,-2,-2,-50,-20),
  (10,-2,1,1,1,1,-2,10),(5,-2,1,0,0,1,-2,5),(5,-2,1,0,0,1,-2,5),
  (10,-2,1,1,1,1,-2,10),(-20,-50,-2,-2,-2,-2,-50,-20),(100,-20,10,5,5,10,-20,100));

Type
 TBoard = Array[0..7,0..7] Of ShortInt;
 PRev = ^TRev;
 TRev = Record
  B : TBoard;
  Turn : Integer;        { 1 humain (rouge), 2 ordinateur (bleu) }
  Skill: Integer;
  Over : Boolean;
  Msg  : String[60];
  Think: Boolean;
  Hint : Integer;        { case suggeree x*8+y ou -1 }
  NodeCnt: LongInt;
 End;

Function RevFlips(Var B: TBoard; Pl,X,Y: Integer; Apply: Boolean): Integer;
Var DX,DY,K,NX,NY,Cnt,Tot: Integer;
Begin
 Tot:=0;
 If B[X,Y]<>0 Then Begin RevFlips:=0;Exit;End;
 For DX:=-1 To 1 Do
  For DY:=-1 To 1 Do Begin
   If (DX=0) And (DY=0) Then Continue;
   Cnt:=0;NX:=X+DX;NY:=Y+DY;
   While (NX>=0) And (NX<8) And (NY>=0) And (NY<8) And (B[NX,NY]=3-Pl) Do Begin
    Inc(Cnt);NX:=NX+DX;NY:=NY+DY;
   End;
   If (Cnt>0) And (NX>=0) And (NX<8) And (NY>=0) And (NY<8) And (B[NX,NY]=Pl) Then Begin
    Tot:=Tot+Cnt;
    If Apply Then Begin
     NX:=X+DX;NY:=Y+DY;
     For K:=1 To Cnt Do Begin B[NX,NY]:=Pl;NX:=NX+DX;NY:=NY+DY;End;
    End;
   End;
  End;
 If Apply And (Tot>0) Then B[X,Y]:=Pl;
 RevFlips:=Tot;
End;

Function RevMoves(Var B: TBoard; Pl: Integer): Integer;
Var X,Y,N: Integer;
Begin
 N:=0;
 For X:=0 To 7 Do For Y:=0 To 7 Do If RevFlips(B,Pl,X,Y,False)>0 Then Inc(N);
 RevMoves:=N;
End;

Function RevEval(Var B: TBoard; Pl: Integer): Integer;
Var X,Y,S,Cnt: Integer;
Begin
 S:=0;Cnt:=0;
 For X:=0 To 7 Do For Y:=0 To 7 Do Begin
  If B[X,Y]=Pl Then S:=S+RWeight[X,Y] Else If B[X,Y]=3-Pl Then S:=S-RWeight[X,Y];
  If B[X,Y]<>0 Then Inc(Cnt);
 End;
 S:=S+(RevMoves(B,Pl)-RevMoves(B,3-Pl))*4;
 RevEval:=S;
End;

Function RevSearch(Var B: TBoard; Pl,Me,Depth,Alpha,Beta: Integer; Var NC: LongInt): Integer;
Var X,Y,V,Best: Integer; NB: TBoard; Any: Boolean;
Begin
 Inc(NC);
 If Depth=0 Then Begin RevSearch:=RevEval(B,Me);Exit;End;
 Any:=False;
 If Pl=Me Then Best:=-30000 Else Best:=30000;
 For X:=0 To 7 Do For Y:=0 To 7 Do Begin
  If RevFlips(B,Pl,X,Y,False)=0 Then Continue;
  Any:=True;
  NB:=B;RevFlips(NB,Pl,X,Y,True);
  V:=RevSearch(NB,3-Pl,Me,Depth-1,Alpha,Beta,NC);
  If Pl=Me Then Begin
   If V>Best Then Best:=V;
   If Best>Alpha Then Alpha:=Best;
  End Else Begin
   If V<Best Then Best:=V;
   If Best<Beta Then Beta:=Best;
  End;
  If Alpha>=Beta Then Begin RevSearch:=Best;Exit;End;
 End;
 If Not Any Then Begin
  If RevMoves(B,3-Pl)=0 Then Begin RevSearch:=RevEval(B,Me);Exit;End;
  RevSearch:=RevSearch(B,3-Pl,Me,Depth-1,Alpha,Beta,NC);Exit;
 End;
 RevSearch:=Best;
End;

Function RevBest(R: PRev; Pl,Depth: Integer): Integer;  { x*8+y ou -1 }
Var X,Y,V,Best,BM: Integer; NB: TBoard;
Begin
 Best:=-30000;BM:=-1;
 R^.NodeCnt:=0;
 For X:=0 To 7 Do For Y:=0 To 7 Do Begin
  If RevFlips(R^.B,Pl,X,Y,False)=0 Then Continue;
  NB:=R^.B;RevFlips(NB,Pl,X,Y,True);
  V:=RevSearch(NB,3-Pl,Pl,Depth-1,-30000,30000,R^.NodeCnt)+Random(3);
  If V>Best Then Begin Best:=V;BM:=X*8+Y;End;
 End;
 RevBest:=BM;
End;

Procedure RevCount(R: PRev; Var Red,Blue: Integer);
Var X,Y: Integer;
Begin
 Red:=0;Blue:=0;
 For X:=0 To 7 Do For Y:=0 To 7 Do Begin
  If R^.B[X,Y]=1 Then Inc(Red) Else If R^.B[X,Y]=2 Then Inc(Blue);
 End;
End;

Procedure RevNew(R: PRev);
Begin
 FillChar(R^.B,SizeOf(R^.B),0);
 R^.B[3,3]:=2;R^.B[4,4]:=2;R^.B[3,4]:=1;R^.B[4,3]:=1;
 R^.Turn:=1;R^.Over:=False;R^.Hint:=-1;R^.Think:=False;
 R^.Msg:=T3('Your move (red).','A vous (rouge).','Sie sind dran (rot).');
End;

Procedure RevCheckEnd(R: PRev);
Var Red,Blue: Integer;
Begin
 If (RevMoves(R^.B,1)=0) And (RevMoves(R^.B,2)=0) Then Begin
  R^.Over:=True;
  RevCount(R,Red,Blue);
  If Red>Blue Then R^.Msg:=T3('You win!','Vous gagnez !','Sie gewinnen!')
  Else If Blue>Red Then R^.Msg:=T3('The computer wins.','L''ordinateur gagne.','Der Computer gewinnt.')
  Else R^.Msg:=T3('Draw.','Match nul.','Unentschieden.');
 End Else If RevMoves(R^.B,R^.Turn)=0 Then Begin
  If R^.Turn=1 Then R^.Msg:=T3('You must pass.','Vous devez passer.','Sie m'#129'ssen passen.');
  R^.Turn:=3-R^.Turn;
  If R^.Turn=2 Then R^.Think:=True;
 End;
End;

Procedure RevGeom(W: PWindow; Var X0,Y0,Cs: Integer);
Var X1,Y1,X2,Y2: Integer;
Begin
 WinClient(W,X1,Y1,X2,Y2);
 Cs:=Min2((X2-X1-16) Div 8,(Y2-Y1-30) Div 8);
 If Cs<10 Then Cs:=10;
 X0:=X1+(X2-X1+1-Cs*8) Div 2;Y0:=Y1+8;
End;

Procedure RevDraw(W: PWindow);
Var R: PRev; X1,Y1,X2,Y2,X0,Y0,Cs,I,J,CC: Integer; Red,Blue: Integer; T: String;
Begin
 R:=W^.Data;
 WinClient(W,X1,Y1,X2,Y2);
 GBar(X1,Y1,X2,Y2,cLGn);
 RevGeom(W,X0,Y0,Cs);
 GDither(X0,Y0,X0+Cs*8,Y0+Cs*8,cBlk,cLGr);
 For I:=0 To 8 Do Begin GHLine(X0,X0+Cs*8,Y0+I*Cs,cBlk);GVLine(X0+I*Cs,Y0,Y0+Cs*8,cBlk);End;
 GBar(X0+Cs*8+1,Y0+4,X0+Cs*8+4,Y0+Cs*8+4,cBlk);
 GBar(X0+4,Y0+Cs*8+1,X0+Cs*8+4,Y0+Cs*8+4,cBlk);
 For I:=0 To 7 Do For J:=0 To 7 Do Begin
  If R^.B[I,J]<>0 Then Begin
   If R^.B[I,J]=1 Then CC:=cLRd Else CC:=cLBl;
   GFillEllipse(X0+I*Cs+Cs Div 2,Y0+J*Cs+Cs Div 2,Cs Div 2-3,Cs Div 2-3,CC);
   GEllipse(X0+I*Cs+Cs Div 2,Y0+J*Cs+Cs Div 2,Cs Div 2-3,Cs Div 2-3,cBlk);
  End;
 End;
 If R^.Hint>=0 Then Begin
  I:=R^.Hint Div 8;J:=R^.Hint Mod 8;
  GEllipse(X0+I*Cs+Cs Div 2,Y0+J*Cs+Cs Div 2,Cs Div 2-6,Cs Div 2-6,cWht);
  GEllipse(X0+I*Cs+Cs Div 2,Y0+J*Cs+Cs Div 2,Cs Div 2-7,Cs Div 2-7,cBlk);
 End;
 RevCount(R,Red,Blue);
 T:=T3('Red ','Rouge ','Rot ')+IntStr(Red)+'  '+T3('Blue ','Bleu ','Blau ')+IntStr(Blue)+'   '+R^.Msg;
 GBar(X1,Y2-14,X2,Y2,cWht);
 GText(X1+4,Y2-11,T,cBlk);
End;

Procedure RevPlay(R: PRev; Pl,X,Y: Integer);
Begin
 RevFlips(R^.B,Pl,X,Y,True);
 R^.Hint:=-1;
 R^.Turn:=3-Pl;
 If R^.Turn=2 Then R^.Msg:=T3('Computer thinking...','L''ordinateur r'#130'fl'#130'chit...','Computer denkt...')
 Else R^.Msg:=T3('Your move (red).','A vous (rouge).','Sie sind dran (rot).');
 If Pl=1 Then R^.Think:=True;
 RevCheckEnd(R);
End;

Procedure RevMouse(W: PWindow; Var E: TEvent);
Var R: PRev; X0,Y0,Cs,I,J: Integer;
Begin
 R:=W^.Data;
 If (E.Kind<>EV_DOWN) Or R^.Over Or (R^.Turn<>1) Then Exit;
 RevGeom(W,X0,Y0,Cs);
 I:=(E.X-X0) Div Cs;J:=(E.Y-Y0) Div Cs;
 If (E.X<X0) Or (E.Y<Y0) Or (I<0) Or (I>7) Or (J<0) Or (J>7) Then Exit;
 If RevFlips(R^.B,1,I,J,False)>0 Then Begin RevPlay(R,1,I,J);Dirty:=True;End
 Else Beep;
End;

Procedure RevTimer(W: PWindow);
Var R: PRev; M: Integer; D: Integer;
Begin
 R:=W^.Data;
 If Not R^.Think Then Exit;
 If (R^.Turn<>2) Or R^.Over Then Begin R^.Think:=False;Exit;End;
 R^.Think:=False;
 D:=1;
 Case R^.Skill Of 0: D:=1;1: D:=2;2: D:=4;3: D:=6;End;
 M:=RevBest(R,2,D);
 If M>=0 Then RevPlay(R,2,M Div 8,M Mod 8);
 Dirty:=True;
End;

Procedure RevMenu(W: PWindow; Cmd: Integer);
Var R: PRev; M: Integer;
Begin
 R:=W^.Data;
 Case Cmd Of
  CM_R_NEW: RevNew(R);
  CM_R_HINT: If (R^.Turn=1) And Not R^.Over Then R^.Hint:=RevBest(R,1,3);
  CM_R_PASS: If (R^.Turn=1) And Not R^.Over Then Begin
    If RevMoves(R^.B,1)>0 Then InfoBox(T3('You have a legal move.','Vous avez un coup possible.','Sie haben einen m'#148'glichen Zug.'))
    Else Begin R^.Turn:=2;R^.Think:=True;End;
   End;
  CM_R_ABOUT: ShowAboutMs('Reversi',1,False);
  CM_R_BEG: R^.Skill:=0;
  CM_R_NOV: R^.Skill:=1;
  CM_R_MAS: R^.Skill:=2;
  CM_R_EXP: R^.Skill:=3;
 End;
 Dirty:=True;
End;

Procedure RevPrepare(W: PWindow);
Var R: PRev;
Begin
 R:=W^.Data;
 MenuCheck(W,CM_R_BEG,R^.Skill=0);MenuCheck(W,CM_R_NOV,R^.Skill=1);
 MenuCheck(W,CM_R_MAS,R^.Skill=2);MenuCheck(W,CM_R_EXP,R^.Skill=3);
End;

Function RevCreate: PWindow;
Var W: PWindow; R: PRev;
Begin
 W:=NewWindow(A_REV,'Reversi',-1,-1,340,330,True);
 If W=Nil Then Begin RevCreate:=Nil;Exit;End;
 New(R);FillChar(R^,SizeOf(TRev),0);R^.Skill:=1;RevNew(R);
 W^.Data:=R;
 WinAddMenu(W,'&Game~&Jeu~&Spiel');
 WinAddItem(W,'&New~&Nouvelle partie~&Neu',CM_R_NEW,'');
 WinAddItem(W,'&Hint~&Conseil~&Hinweis',CM_R_HINT,'');
 WinAddItem(W,'&Pass~&Passer~&Passen',CM_R_PASS,'');
 WinAddItem(W,'&About Reversi...~&'#133' propos de Reversi...~'#154'&ber Reversi...',CM_R_ABOUT,'');
 WinAddMenu(W,'&Skill~&Niveau~&Stufe');
 WinAddItem(W,'&Beginner~&D'#130'butant~&Anf'#132'nger',CM_R_BEG,'');
 WinAddItem(W,'&Novice~&Novice~&Fortgeschritten',CM_R_NOV,'');
 WinAddItem(W,'&Master~&Ma'#140'tre~&Meister',CM_R_MAS,'');
 WinAddItem(W,'&Expert~&Expert~&Experte',CM_R_EXP,'');
 RevCreate:=W;
End;

{ ====================================================================== }
{                          CONTROL PANEL                                 }
{ ====================================================================== }

Const
 CM_P_ADDPRN=401; CM_P_DELPRN=402; CM_P_ADDFONT=403; CM_P_DELFONT=404;
 CM_P_EXIT=405; CM_P_ABOUT=406;
 CM_P_CONN=411; CM_P_PRINTER=412; CM_P_COMM=413;
 CM_P_COLORS=421; CM_P_BORDER=422; CM_P_BEEP=423; CM_P_MOUSE=424; CM_P_COUNTRY=425;
 MAXPRN = 10;

Type
 TPrnList = Array[1..MAXPRN] Of String[30];

Var
 PrnInst : TPrnList;
 PrnPort : Array[1..MAXPRN] Of String[6];
 FontInst: Array[1..12] Of String[34]; FontFile: Array[1..12] Of String[12]; NFont: Integer;
 CommPort: String[5];
 CommBaud,CommBits,CommStop: Integer;
 CommParity: Char;
 CountryName: String[24];

Const
 NKNOWNP = 9;
 KnownPrn : Array[1..NKNOWNP] Of String[26] = (
  'Epson FX-80','Epson LQ-1500','HP LaserJet','IBM Graphics Printer','Okidata Microline 92',
  'PostScript Printer','Apple LaserWriter','Toshiba P1351','Text Only');
 NKNOWNF = 9;
 KnownFnt : Array[1..NKNOWNF] Of String[48] = (
  'COURA.FON|Courier 8,10,12 (Set #1)','COURB.FON|Courier 8,10,12 (Set #2)',
  'HELVA.FON|Helv 8,10,12,14,18,24 (Set #1)','HELVB.FON|Helv 8,10,12,14,18,24 (Set #2)',
  'TMSRA.FON|Tms Rmn 8,10,12,14,18,24 (Set #1)','TMSRB.FON|Tms Rmn 8,10,12,14,18,24 (Set #2)',
  'MODERN.FON|Modern (Vector)','ROMAN.FON|Roman (Vector)','SCRIPT.FON|Script (Vector)');

{ ---------------- profil WIN.INI (lecture/ecriture d'une cle) ---------------- }

Function IniRead(Const Fn,Sec,Key: String; Var Val_: String): Boolean;
Var F: Text; L,S,K: String; In_: Boolean; P: Integer;
Begin
 IniRead:=False;
 {$I-}
 Assign(F,Fn);Reset(F);
 If IOResult<>0 Then Exit;
 In_:=False;
 While Not Eof(F) Do Begin
  ReadLn(F,L);L:=Trim(L);
  If (L<>'') And (L[1]='[') Then Begin In_:=Upper(Copy(L,2,Length(L)-2))=Upper(Sec);Continue;End;
  If In_ Then Begin
   P:=Pos('=',L);
   If (P>0) And (Upper(Trim(Copy(L,1,P-1)))=Upper(Key)) Then Begin Val_:=Trim(Copy(L,P+1,200));IniRead:=True;Break;End;
  End;
 End;
 Close(F);
 {$I+}
 If IOResult<>0 Then ;
End;

Procedure IniWrite(Const Fn,Sec,Key,Val_: String);
Var F,G: Text; L: String; In_,Done,SecSeen,Had: Boolean; P: Integer; Tmp: String;
Begin
 Tmp:=Fn+'.TMP';
 {$I-}
 Assign(G,Tmp);Rewrite(G);
 If IOResult<>0 Then Exit;
 Done:=False;SecSeen:=False;In_:=False;
 Assign(F,Fn);Reset(F);
 Had:=IOResult=0;
 If Had Then Begin
  While Not Eof(F) Do Begin
   ReadLn(F,L);
   If (Trim(L)<>'') And (Trim(L)[1]='[') Then Begin
    If In_ And Not Done Then Begin WriteLn(G,Key,'=',Val_);Done:=True;End;
    In_:=Upper(Copy(Trim(L),2,Length(Trim(L))-2))=Upper(Sec);
    If In_ Then SecSeen:=True;
    WriteLn(G,L);Continue;
   End;
   If In_ Then Begin
    P:=Pos('=',L);
    If (P>0) And (Upper(Trim(Copy(L,1,P-1)))=Upper(Key)) Then Begin
     If Not Done Then WriteLn(G,Key,'=',Val_);Done:=True;Continue;
    End;
   End;
   WriteLn(G,L);
  End;
  Close(F);
 End;
 If Not Done Then Begin
  If Not SecSeen Then WriteLn(G,'[',Sec,']');
  WriteLn(G,Key,'=',Val_);
 End;
 Close(G);
 If IOResult<>0 Then ;
 If Had Then Begin Erase(F);If IOResult<>0 Then ;End;
 Rename(G,Fn);
 {$I+}
 If IOResult<>0 Then ;
End;


{ ---------- supprime une cle d'une section de WIN.INI ---------- }
Procedure IniDel(Const Fn,Sec,Key: String);
Var F,G: Text; L: String; In_: Boolean; P: Integer; Tmp: String;
Begin
 Tmp:=Fn+'.TMP';
 {$I-}
 Assign(F,Fn);Reset(F);
 If IOResult<>0 Then Exit;
 Assign(G,Tmp);Rewrite(G);
 If IOResult<>0 Then Begin Close(F);Exit;End;
 In_:=False;
 While Not Eof(F) Do Begin
  ReadLn(F,L);
  If (Trim(L)<>'') And (Trim(L)[1]='[') Then In_:=Upper(Copy(Trim(L),2,Length(Trim(L))-2))=Upper(Sec)
  Else If In_ Then Begin
   P:=Pos('=',L);
   If (P>0) And (Upper(Trim(Copy(L,1,P-1)))=Upper(Key)) Then Continue;
  End;
  WriteLn(G,L);
 End;
 Close(F);Close(G);
 Erase(F);Rename(G,Fn);
 {$I+}
 If IOResult<>0 Then ;
End;

{ enumere les cles d'une section (Idx a partir de 1) }
Function IniEnum(Const Fn,Sec: String; Idx: Integer; Var Key,Val_: String): Boolean;
Var F: Text; L: String; In_: Boolean; P,N: Integer;
Begin
 IniEnum:=False;N:=0;
 {$I-}
 Assign(F,Fn);Reset(F);
 If IOResult<>0 Then Exit;
 In_:=False;
 While Not Eof(F) Do Begin
  ReadLn(F,L);L:=Trim(L);
  If (L<>'') And (L[1]='[') Then Begin In_:=Upper(Copy(L,2,Length(L)-2))=Upper(Sec);Continue;End;
  If In_ And (L<>'') And (L[1]<>';') Then Begin
   P:=Pos('=',L);
   If P>1 Then Begin
    Inc(N);
    If N=Idx Then Begin Key:=Trim(Copy(L,1,P-1));Val_:=Trim(Copy(L,P+1,200));IniEnum:=True;Break;End;
   End;
  End;
 End;
 Close(F);
 {$I+}
 If IOResult<>0 Then ;
End;



Const
 VgaRGB : Array[0..15,0..2] Of Integer = (
  (0,0,0),(0,0,170),(0,170,0),(0,170,170),(170,0,0),(170,0,170),(170,85,0),(170,170,170),
  (85,85,85),(85,85,255),(85,255,85),(85,255,255),(255,85,85),(255,85,255),(255,255,85),(255,255,255));

Function NearestVga(R,G,B: Integer): Integer;
Var I,Best: Integer; D,BD: LongInt;
Begin
 Best:=0;BD:=1000000;
 For I:=0 To 15 Do Begin
  D:=Sqr(R-VgaRGB[I,0])+Sqr(G-VgaRGB[I,1])+Sqr(B-VgaRGB[I,2]);
  If D<BD Then Begin BD:=D;Best:=I;End;
 End;
 NearestVga:=Best;
End;

Var
 BlinkMs : LongInt;       { CursorBlinkRate (ms) }

Const
 IniColNames : Array[0..9] Of String[14] = ('Background','AppWorkspace','Window','WindowText',
   'Menu','MenuText','ActiveTitle','InactiveTitle','TitleText','WindowFrame');

Function YesNo(B: Boolean): String;
Begin
 If B Then YesNo:='yes' Else YesNo:='no';
End;

Function PrnDriver(Const Nm: String): String;
Var I: Integer; R: String;
Begin
 R:='';
 For I:=1 To Length(Nm) Do If (UpCase(Nm[I]) In ['A'..'Z','0'..'9']) And (Length(R)<8) Then R:=R+UpCase(Nm[I]);
 PrnDriver:=R;
End;

Function ComStr(K: Integer): String;
Const ParL: Array[0..4] Of Char=('n','o','e','m','s');
Var St: String;
Begin
 Case ComSet[K].Stop Of 1: St:='1.5';2: St:='2';Else St:='1';End;
 ComStr:=IntStr(ComSet[K].Baud)+','+ParL[ComSet[K].Par]+','+IntStr(ComSet[K].Bits)+','+St+
  IfThenS(ComSet[K].Hs=0,',p',IfThenS(ComSet[K].Hs=1,',x',''));
End;

Procedure IniSave;
Var I: Integer; Sg: String;
Begin
 IniWrite(IniFile,'windows','DoubleClickSpeed',IntStr(DblCs*10));
 IniWrite(IniFile,'windows','CursorBlinkRate',IntStr(BlinkMs));
 IniWrite(IniFile,'windows','beep',YesNo(Beeping));
 IniWrite(IniFile,'windows','Border Width',IntStr(BorderW));
 IniWrite(IniFile,'windows','SwapMouseButtons',YesNo(LeftHand));
 IniWrite(IniFile,'windows','MouseSpeed',IntStr(MouseAcc));
 If NPrn>0 Then IniWrite(IniFile,'windows','device',PrinterName+','+PrnDriver(PrinterName)+','+PrintPort+':');
 For I:=1 To NPrn Do IniWrite(IniFile,'devices',PrnInst[I],PrnDriver(PrnInst[I])+','+PrnPort[I]+':');
 For I:=0 To 9 Do
  IniWrite(IniFile,'colors',IniColNames[I],IntStr(VgaRGB[ScrCol[I],0])+' '+IntStr(VgaRGB[ScrCol[I],1])+' '+IntStr(VgaRGB[ScrCol[I],2]));
 IniWrite(IniFile,'intl','sCountry',CountryName);
 IniWrite(IniFile,'intl','iDate',IntStr(DateFmt));
 IniWrite(IniFile,'intl','iTime',IntStr(Ord(Clock24)));
 IniWrite(IniFile,'intl','sDate',DateSep);
 IniWrite(IniFile,'intl','sTime',TimeSep);
 IniWrite(IniFile,'intl','sCurrency',CurSym);
 IniWrite(IniFile,'intl','sDecimal',DecSep);
 IniWrite(IniFile,'intl','sThousand',ThouSep);
 IniWrite(IniFile,'intl','iCurrency',IntStr(CurFmt));
 IniWrite(IniFile,'intl','iDigits',IntStr(NumDigits));
 IniWrite(IniFile,'intl','iLzero',IntStr(Ord(LeadZero)));
 IniWrite(IniFile,'intl','s1159',S1159);
 IniWrite(IniFile,'intl','s2359',S2359);
 IniWrite(IniFile,'intl','sList',ListSep);
 IniWrite(IniFile,'windows','DeviceNotSelectedTimeout',IntStr(DevTimeout));
 IniWrite(IniFile,'windows','TransmissionRetryTimeout',IntStr(TxTimeout));
 IniWrite(IniFile,'windows','PrinterOrientation',IntStr(PrnOrient));
 IniWrite(IniFile,'windows','PaperSize',IntStr(PrnPaper));
 For I:=1 To 2 Do Begin
  Sg:=ComStr(I);
  IniWrite(IniFile,'ports','COM'+IntStr(I)+':',Sg);
 End;
 If PrnFileName<>'' Then IniWrite(IniFile,'ports','FILE:',PrnFileName);
 For I:=1 To NFont Do IniWrite(IniFile,'fonts',FontInst[I],FontFile[I]);
End;

Procedure CommMirror; Forward;

Procedure IniLoad;
Var V,K1: String; I,P,R,G,B: Integer;
Begin
 If IniRead(IniFile,'windows','DoubleClickSpeed',V) Then DblCs:=Clamp(StrVal(V,450) Div 10,5,100);
 If IniRead(IniFile,'windows','CursorBlinkRate',V) Then BlinkMs:=Clamp(StrVal(V,530),100,2000);
 BlinkHalf:=Max2(5,BlinkMs Div 20);
 If IniRead(IniFile,'windows','beep',V) Then Beeping:=Upper(V)<>'NO';
 If IniRead(IniFile,'windows','Border Width',V) Then BorderW:=Clamp(StrVal(V,3),3,12);
 If IniRead(IniFile,'windows','SwapMouseButtons',V) Then LeftHand:=Upper(V)='YES';
 If IniRead(IniFile,'windows','MouseSpeed',V) Then MouseAcc:=Clamp(StrVal(V,1),0,2);
 If IniRead(IniFile,'windows','device',V) Then Begin
  P:=Pos(',',V);
  If P>1 Then Begin
   PrinterName:=Copy(V,1,P-1);
   P:=0;For I:=Length(V) Downto 1 Do If V[I]=',' Then Begin P:=I;Break;End;
   If P>0 Then Begin PrintPort:=Copy(V,P+1,10);If (PrintPort<>'') And (PrintPort[Length(PrintPort)]=':') Then Delete(PrintPort,Length(PrintPort),1);End;
  End;
 End;
 For I:=0 To 9 Do
  If IniRead(IniFile,'colors',IniColNames[I],V) Then Begin
   R:=0;G:=0;B:=0;
   P:=Pos(' ',V);If P>0 Then Begin R:=StrVal(Copy(V,1,P-1),0);Delete(V,1,P);V:=Trim(V);End;
   P:=Pos(' ',V);If P>0 Then Begin G:=StrVal(Copy(V,1,P-1),0);Delete(V,1,P);V:=Trim(V);B:=StrVal(V,0);End;
   ScrCol[I]:=NearestVga(R,G,B);
  End;
 If IniRead(IniFile,'intl','sCountry',V) Then CountryName:=V;
 If IniRead(IniFile,'intl','iDate',V) Then DateFmt:=Clamp(StrVal(V,0),0,2);
 If IniRead(IniFile,'intl','iTime',V) Then Clock24:=V='1';
 If IniRead(IniFile,'intl','sDate',V) Then DateSep:=Copy(V,1,1);
 If IniRead(IniFile,'intl','sTime',V) Then TimeSep:=Copy(V,1,1);
 If IniRead(IniFile,'intl','sCurrency',V) Then CurSym:=Copy(V,1,4);
 If IniRead(IniFile,'intl','sDecimal',V) Then DecSep:=Copy(V,1,1);
 If IniRead(IniFile,'intl','sThousand',V) Then ThouSep:=Copy(V,1,1);
 For I:=1 To 2 Do
  If IniRead(IniFile,'ports','COM'+IntStr(I)+':',V) Then Begin
   P:=Pos(',',V);If P>0 Then Begin ComSet[I].Baud:=StrVal(Copy(V,1,P-1),ComSet[I].Baud);Delete(V,1,P);End;
   P:=Pos(',',V);If P>0 Then Begin
    Case UpCase(V[1]) Of 'O': ComSet[I].Par:=1;'E': ComSet[I].Par:=2;'M': ComSet[I].Par:=3;'S': ComSet[I].Par:=4;Else ComSet[I].Par:=0;End;
    Delete(V,1,P);End;
   P:=Pos(',',V);If P>0 Then Begin ComSet[I].Bits:=Clamp(StrVal(Copy(V,1,P-1),8),4,8);Delete(V,1,P);End;
   P:=Pos(',',V);If P=0 Then P:=Length(V)+1;
   If Copy(V,1,P-1)='1.5' Then ComSet[I].Stop:=1 Else If Copy(V,1,P-1)='2' Then ComSet[I].Stop:=2 Else ComSet[I].Stop:=0;
   Delete(V,1,P);
   If V='p' Then ComSet[I].Hs:=0 Else If V='x' Then ComSet[I].Hs:=1 Else ComSet[I].Hs:=2;
  End;
 CommMirror;
 If IniRead(IniFile,'ports','FILE:',V) Then PrnFileName:=Copy(V,1,40);
 If IniRead(IniFile,'intl','iCurrency',V) Then CurFmt:=Clamp(StrVal(V,0),0,3);
 If IniRead(IniFile,'intl','iDigits',V) Then NumDigits:=Clamp(StrVal(V,2),0,9);
 If IniRead(IniFile,'intl','iLzero',V) Then LeadZero:=V='1';
 If IniRead(IniFile,'intl','s1159',V) Then S1159:=Copy(V,1,8);
 If IniRead(IniFile,'intl','s2359',V) Then S2359:=Copy(V,1,8);
 If IniRead(IniFile,'intl','sList',V) Then ListSep:=Copy(V,1,1);
 If IniRead(IniFile,'windows','DeviceNotSelectedTimeout',V) Then DevTimeout:=Clamp(StrVal(V,15),1,999);
 If IniRead(IniFile,'windows','TransmissionRetryTimeout',V) Then TxTimeout:=Clamp(StrVal(V,45),1,999);
 If IniRead(IniFile,'windows','PrinterOrientation',V) Then PrnOrient:=Clamp(StrVal(V,0),0,1);
 If IniRead(IniFile,'windows','PaperSize',V) Then PrnPaper:=Clamp(StrVal(V,0),0,3);
 { imprimantes et polices installees }
 If IniRead(IniFile,'intl','iLzero',V) Then Begin
  NPrn:=0;I:=1;
  While (NPrn<MAXPRN) And IniEnum(IniFile,'devices',I,K1,V) Do Begin
   Inc(NPrn);PrnInst[NPrn]:=Copy(K1,1,30);PrnPort[NPrn]:='LPT1';
   P:=0;For R:=Length(V) Downto 1 Do If V[R]=',' Then Begin P:=R;Break;End;
   If P>0 Then Begin PrnPort[NPrn]:=Copy(V,P+1,6);If PrnPort[NPrn][Length(PrnPort[NPrn])]=':' Then Dec(PrnPort[NPrn][0]);End;
   Inc(I);
  End;
 End;
 If IniRead(IniFile,'intl','iLzero',V) Then Begin
  NFont:=0;I:=1;
  While (NFont<12) And IniEnum(IniFile,'fonts',I,K1,V) Do Begin
   Inc(NFont);FontInst[NFont]:=Copy(K1,1,34);FontFile[NFont]:=Copy(V,1,12);Inc(I);
  End;
 End;
 If NPrn=0 Then Begin PrinterName:='';PrintPort:='LPT1';End
 Else Begin
  P:=0;For I:=1 To NPrn Do If PrnInst[I]=PrinterName Then P:=I;
  If P=0 Then Begin PrinterName:=PrnInst[1];PrintPort:=PrnPort[1];End Else PrintPort:=PrnPort[P];
 End;
 For P:=0 To 3 Do If IniRead(IniFile,'volumes',Chr(65+P),V) Then VolNames[Chr(65+P)]:=Copy(V,1,11);
 ApplyScreenColors;
End;

{ liste de choix generique }
Function PickList(Const Prompt: String; L: PStrList; Var Sel: Integer): Boolean;
Var D: TDlg; R: Integer;
Begin
 DlgInit(D,'',300,196);
 DlgText(D,10,8,Prompt);
 DlgList(D,10,10,26,280,110,L,Sel);
 DlgButton(D,ID_OK,50,150,90,'OK',True);
 DlgButton(D,ID_CANCEL,160,150,90,T3('Cancel','Annuler','Abbrechen'),False);
 R:=RunDialog(D,@NoHook);
 If R=ID_OK Then Begin Sel:=DlgGetVal(D,10);PickList:=Sel>0;End Else PickList:=False;
End;

{ ================== imprimantes et polices : ajout / suppression ================== }

Const
 ID_RESET = 9;




Var
 DrvDest: String[40];

{ cree un fichier "pilote" (marqueur W2DRV) dans le repertoire de destination }
Function DrvPut(Const Dest,Fn,Desc: String): Boolean;
Var F: Text; P: String;
Begin
 DrvPut:=False;
 P:=JoinPath(V2R(Dest),Fn);
 {$I-}
 Assign(F,P);Rewrite(F);
 If IOResult<>0 Then Exit;
 WriteLn(F,'W2DRV ',Fn);
 WriteLn(F,Desc);
 Close(F);
 {$I+}
 DrvPut:=IOResult=0;
End;

{ supprime le fichier pilote s'il porte notre marqueur }
Procedure DrvKill(Const Dest,Fn: String);
Var F: Text; P,L: String;
Begin
 P:=JoinPath(V2R(Dest),Fn);
 {$I-}
 Assign(F,P);Reset(F);
 If IOResult<>0 Then Exit;
 ReadLn(F,L);Close(F);
 If Copy(L,1,5)='W2DRV' Then Begin Assign(F,P);Erase(F);End;
 {$I+}
 If IOResult<>0 Then ;
End;

{ liste + repertoire de destination ; Sel est le choix }
Function ListDirDlg(Const Prompt: String; L: PStrList; Var Sel: Integer; Var Dir: String; WithDir: Boolean): Boolean;
Var D: TDlg; R: Integer;
Begin
 DlgInit(D,'',320,IfThenI(WithDir,226,196));
 DlgText(D,10,8,Prompt);
 DlgList(D,10,10,26,300,110,L,Sel);
 If WithDir Then Begin
  DlgText(D,10,144,T3('&Drive/directory:','&Unit'#130'/r'#130'pertoire :','&Laufwerk/Verzeichnis:'));
  DlgEdit(D,11,10,158,300,Dir,36);
 End;
 DlgButton(D,ID_OK,60,IfThenI(WithDir,190,150),90,'OK',True);
 DlgButton(D,ID_CANCEL,170,IfThenI(WithDir,190,150),90,T3('Cancel','Annuler','Abbrechen'),False);
 R:=RunDialog(D,@NoHook);
 If R=ID_OK Then Begin
  Sel:=DlgGetVal(D,10);
  If WithDir Then Dir:=Trim(DlgGetText(D,11));
  ListDirDlg:=Sel>0;
 End Else ListDirDlg:=False;
End;

Procedure CpAddPrinter;
Var L: PStrList; I,S: Integer; Dir: String; Nm: String;
Begin
 If NPrn>=MAXPRN Then Begin
  InfoBox(T3('Cannot add a printer.|The printer list is full.','Ajout impossible.|La liste des imprimantes est pleine.','Hinzuf'#129'gen nicht m'#148'glich.|Druckerliste voll.'));Exit;
 End;
 New(L);L^.N:=NKNOWNP;
 For I:=1 To NKNOWNP Do L^.S[I]:=KnownPrn[I]+'  ('+PrnDriver(KnownPrn[I])+'.DRV)';
 S:=1;Dir:=DrvDest;
 If ListDirDlg(T3('Select a &printer to add:','Choisissez une &imprimante '#133' ajouter :','&Drucker zum Hinzuf'#129'gen w'#132'hlen:'),L,S,Dir,True) Then Begin
  Nm:=KnownPrn[S];
  For I:=1 To NPrn Do If PrnInst[I]=Nm Then Begin
   InfoBox(T3('This printer is already installed.','Cette imprimante est d'#130'j'#133' install'#130'e.','Dieser Drucker ist bereits installiert.'));
   Dispose(L);Exit;
  End;
  If Dir='' Then Dir:='C:\';
  If Not DrvPut(Dir,PrnDriver(Nm)+'.DRV','Printer driver: '+Nm) Then Begin
   InfoBox(T3('Cannot copy the printer driver to '+Dir,'Impossible de copier le pilote vers '+Dir,'Treiber kann nicht nach '+Dir+' kopiert werden'));
   Dispose(L);Exit;
  End;
  DrvDest:=Dir;
  Inc(NPrn);PrnInst[NPrn]:=Nm;PrnPort[NPrn]:='LPT1';
  If NPrn=1 Then Begin PrinterName:=Nm;PrintPort:='LPT1';End;
  IniSave;
  InfoBox(T3('Printer '+Nm+' installed.|Use Connections to choose its port.','Imprimante '+Nm+' install'#130'e.|Utilisez Connexions pour choisir son port.','Drucker '+Nm+' installiert.|Anschl'#129'sse w'#132'hlen Sie unter Verbindungen.'));
 End;
 Dispose(L);
End;

Procedure CpDelPrinter;
Var L: PStrList; I,S,K: Integer; Dir: String; Nm: String;
Begin
 If NPrn=0 Then Begin InfoBox(T3('No printer is installed.','Aucune imprimante install'#130'e.','Kein Drucker installiert.'));Exit;End;
 New(L);L^.N:=NPrn;
 For I:=1 To NPrn Do L^.S[I]:=PrnInst[I]+'  ('+PrnPort[I]+')';
 S:=1;Dir:='';
 If ListDirDlg(T3('Select the &printer to delete:','Choisissez l''&imprimante '#133' supprimer :','Zu l'#148'schenden &Drucker w'#132'hlen:'),L,S,Dir,False) Then Begin
  Nm:=PrnInst[S];
  If MsgBox(T3('Delete '+Nm+' from the printer list?','Supprimer '+Nm+' de la liste des imprimantes ?','L'#148'schen: '+Nm+'?'),1,2)=ID_OK Then Begin
   For K:=S To NPrn-1 Do Begin PrnInst[K]:=PrnInst[K+1];PrnPort[K]:=PrnPort[K+1];End;
   Dec(NPrn);
   IniDel(IniFile,'devices',Nm);
   DrvKill(DrvDest,PrnDriver(Nm)+'.DRV');
   If PrinterName=Nm Then Begin
    If NPrn>0 Then Begin PrinterName:=PrnInst[1];PrintPort:=PrnPort[1];End
    Else Begin PrinterName:='';IniDel(IniFile,'windows','device');End;
   End;
   IniSave;
  End;
 End;
 Dispose(L);
End;

Procedure CpAddFont;
Var L: PStrList; I,S: Integer; Dir,Fn,Ds: String; P: Integer;
Begin
 If NFont>=12 Then Begin
  InfoBox(T3('Cannot add a font.|The font list is full.','Ajout impossible.|La liste des polices est pleine.','Hinzuf'#129'gen nicht m'#148'glich.|Schriftliste voll.'));Exit;
 End;
 New(L);L^.N:=NKNOWNF;
 For I:=1 To NKNOWNF Do Begin
  P:=Pos('|',KnownFnt[I]);
  L^.S[I]:=Copy(KnownFnt[I],P+1,60);
 End;
 S:=1;Dir:=DrvDest;
 If ListDirDlg(T3('Select a &font to add:','Choisissez une &police '#133' ajouter :','&Schrift zum Hinzuf'#129'gen w'#132'hlen:'),L,S,Dir,True) Then Begin
  P:=Pos('|',KnownFnt[S]);Fn:=Copy(KnownFnt[S],1,P-1);Ds:=Copy(KnownFnt[S],P+1,60);
  For I:=1 To NFont Do If FontInst[I]=Ds Then Begin
   InfoBox(T3('This font is already installed.','Cette police est d'#130'j'#133' install'#130'e.','Diese Schrift ist bereits installiert.'));
   Dispose(L);Exit;
  End;
  If Dir='' Then Dir:='C:\';
  If Not DrvPut(Dir,Fn,'Font: '+Ds) Then Begin
   InfoBox(T3('Cannot copy the font file to '+Dir,'Impossible de copier la police vers '+Dir,'Schrift kann nicht nach '+Dir+' kopiert werden'));
   Dispose(L);Exit;
  End;
  DrvDest:=Dir;
  Inc(NFont);FontInst[NFont]:=Ds;FontFile[NFont]:=Fn;
  IniWrite(IniFile,'fonts',Ds,Fn);
 End;
 Dispose(L);
End;

Procedure CpDelFont;
Var L: PStrList; I,S,K: Integer; Dir: String;
Begin
 If NFont=0 Then Begin InfoBox(T3('No font is installed.','Aucune police install'#130'e.','Keine Schrift installiert.'));Exit;End;
 New(L);L^.N:=NFont;
 For I:=1 To NFont Do L^.S[I]:=FontInst[I];
 S:=1;Dir:='';
 If ListDirDlg(T3('Select the &font to delete:','Choisissez la &police '#133' supprimer :','Zu l'#148'schende &Schrift w'#132'hlen:'),L,S,Dir,False) Then Begin
  If MsgBox(T3('Delete '+FontInst[S]+'?','Supprimer '+FontInst[S]+' ?','L'#148'schen: '+FontInst[S]+'?'),1,2)=ID_OK Then Begin
   IniDel(IniFile,'fonts',FontInst[S]);
   DrvKill(DrvDest,FontFile[S]);
   For K:=S To NFont-1 Do Begin FontInst[K]:=FontInst[K+1];FontFile[K]:=FontFile[K+1];End;
   Dec(NFont);
  End;
 End;
 Dispose(L);
End;

{ ================== connexions des imprimantes ================== }
Const
 PortNames: Array[0..4] Of String[5]=('LPT1','LPT2','COM1','COM2','FILE');

Var
 CnnPort: Array[1..MAXPRN] Of String[6];

Function CnnHook(Var D: TDlg; Ev,Ct: Integer): Boolean;
Var S,I,P: Integer;
Begin
 CnnHook:=False;
 If (Ev<>DE_CHANGE) And (Ev<>DE_INIT) Then Exit;
 If (Ev=DE_CHANGE) And (D.C[Ct].Id>=20) And (D.C[Ct].Id<=24) Then Begin
  S:=DlgGetVal(D,10);
  If (S>=1) And (S<=NPrn) Then CnnPort[S]:=PortNames[D.C[Ct].Id-20];
 End Else If (Ev=DE_CHANGE) And (D.C[Ct].Id=10) Then Begin
  S:=D.C[Ct].Val;
  If (S>=1) And (S<=NPrn) Then
   For I:=0 To 4 Do If PortNames[I]=CnnPort[S] Then SelectRadio(D,DlgFind(D,20+I));
 End;
End;

Procedure CpConnections;
Var D: TDlg; R,I,P: Integer; L: PStrList; Sel: Integer; Fn: String;
Begin
 If NPrn=0 Then Begin InfoBox(T3('No printer is installed.','Aucune imprimante install'#130'e.','Kein Drucker installiert.'));Exit;End;
 New(L);L^.N:=NPrn;
 For I:=1 To NPrn Do Begin L^.S[I]:=PrnInst[I];CnnPort[I]:=PrnPort[I];End;
 Sel:=1;
 For I:=1 To NPrn Do If PrnInst[I]=PrinterName Then Sel:=I;
 DlgInit(D,'',350,176);
 DlgText(D,10,8,T3('&Printers:','&Imprimantes :','&Drucker:'));
 DlgList(D,10,10,24,190,100,L,Sel);
 DlgBox(D,210,8,130,118,T3('Connection','Connexion','Anschlu'#225));
 For I:=0 To 4 Do DlgRadio(D,20+I,220,26+I*16,1,PortNames[I],CnnPort[Sel]=PortNames[I]);
 DlgButton(D,ID_OK,70,140,100,'OK',True);
 DlgButton(D,ID_CANCEL,190,140,100,T3('Cancel','Annuler','Abbrechen'),False);
 R:=RunDialog(D,@CnnHook);
 If R=ID_OK Then Begin
  Sel:=DlgGetVal(D,10);If Sel<1 Then Sel:=1;
  For I:=1 To NPrn Do PrnPort[I]:=CnnPort[I];
  P:=0;For I:=1 To NPrn Do If PrnPort[I]='FILE' Then P:=1;
  If P=1 Then Begin
   Fn:=PrnFileName;If Fn='' Then Fn:='OUTPUT.PRN';
   If InputBox(T3('Print to &file (name):','Imprimer dans le &fichier (nom) :','In &Datei drucken (Name):'),Fn,40,320) And (Trim(Fn)<>'') Then PrnFileName:=Trim(Fn)
   Else If PrnFileName='' Then PrnFileName:='OUTPUT.PRN';
  End;
  PrinterName:=PrnInst[Sel];PrintPort:=PrnPort[Sel];
  IniSave;
 End;
 Dispose(L);
End;

{ ================== imprimante par defaut + delais ================== }
Procedure CpPrinter;
Var D: TDlg; R,I,S: Integer; L: PStrList;
Begin
 If NPrn=0 Then Begin InfoBox(T3('No printer is installed.','Aucune imprimante install'#130'e.','Kein Drucker installiert.'));Exit;End;
 New(L);L^.N:=NPrn;S:=1;
 For I:=1 To NPrn Do Begin L^.S[I]:=PrnInst[I]+' ('+PrnPort[I]+')';If PrnInst[I]=PrinterName Then S:=I;End;
 DlgInit(D,'',380,226);
 DlgText(D,10,6,T3('&Default printer:','Imprimante par &d'#130'faut :','&Standarddrucker:'));
 DlgList(D,10,10,20,196,86,L,S);
 DlgBox(D,214,4,158,60,T3('Orientation','Orientation','Ausrichtung'));
 DlgRadio(D,20,224,22,1,T3('&Portrait','&Portrait','&Hochformat'),PrnOrient=0);
 DlgRadio(D,21,224,38,1,T3('&Landscape','Pa&ysage','&Querformat'),PrnOrient=1);
 DlgBox(D,214,68,158,54,T3('Paper','Papier','Papier'));
 For I:=0 To 3 Do DlgRadio(D,30+I,224+(I Mod 2)*72,84+(I Div 2)*16,2,PaperNames[I],PrnPaper=I);
 DlgText(D,10,128,T3('Device not &selected (s):','P'#130'riph'#130'rique non &s'#130'lectionn'#130' (s) :','Ger'#132't nicht &bereit (s):'));
 DlgEdit(D,40,300,124,50,IntStr(DevTimeout),3);
 DlgText(D,10,150,T3('&Transmission retry (s):','Nouvel essai de &transmission (s) :','&Sendewiederholung (s):'));
 DlgEdit(D,41,300,146,50,IntStr(TxTimeout),3);
 DlgButton(D,ID_OK,100,184,90,'OK',True);
 DlgButton(D,ID_CANCEL,200,184,90,T3('Cancel','Annuler','Abbrechen'),False);
 R:=RunDialog(D,@NoHook);
 If R=ID_OK Then Begin
  S:=DlgGetVal(D,10);
  If (S>=1) And (S<=NPrn) Then Begin PrinterName:=PrnInst[S];PrintPort:=PrnPort[S];End;
  PrnOrient:=Max2(0,RadioGroupVal(D,1));
  PrnPaper:=Max2(0,RadioGroupVal(D,2));
  DevTimeout:=Clamp(StrVal(DlgGetText(D,40),15),1,999);
  TxTimeout:=Clamp(StrVal(DlgGetText(D,41),45),1,999);
  IniSave;
 End;
 Dispose(L);
End;

{ ================== ports serie (reglages par port) ================== }
Const
 Bauds: Array[0..6] Of Integer=(110,300,1200,2400,4800,9600,19200);
 ParCh: Array[0..4] Of Char=('N','O','E','M','S');

Var
 CommCur: Integer;

Function BaudIdx(B: Integer): Integer;
Var I,R: Integer;
Begin
 R:=2;For I:=0 To 6 Do If Bauds[I]=B Then R:=I;
 BaudIdx:=R;
End;

Procedure CommMirror;
Var K: Integer;
Begin
 K:=1;If CommPort='COM2' Then K:=2;
 CommBaud:=ComSet[K].Baud;CommBits:=ComSet[K].Bits;CommParity:=ParCh[ComSet[K].Par];
 CommStop:=IfThenI(ComSet[K].Stop=2,2,1);
End;

Procedure CommFromDlg(Var D: TDlg; K: Integer);
Begin
 ComSet[K].Baud:=Bauds[Max2(0,RadioGroupVal(D,2))];
 ComSet[K].Bits:=4+Max2(0,RadioGroupVal(D,3));
 ComSet[K].Par:=Max2(0,RadioGroupVal(D,4));
 ComSet[K].Stop:=Max2(0,RadioGroupVal(D,5));
 ComSet[K].Hs:=Max2(0,RadioGroupVal(D,6));
End;

Procedure CommToDlg(Var D: TDlg; K: Integer);
Begin
 SelectRadio(D,DlgFind(D,20+BaudIdx(ComSet[K].Baud)));
 SelectRadio(D,DlgFind(D,30+Clamp(ComSet[K].Bits-4,0,4)));
 SelectRadio(D,DlgFind(D,40+ComSet[K].Par));
 SelectRadio(D,DlgFind(D,50+ComSet[K].Stop));
 SelectRadio(D,DlgFind(D,60+ComSet[K].Hs));
End;

Function CommHook(Var D: TDlg; Ev,Ct: Integer): Boolean;
Var K: Integer;
Begin
 CommHook:=False;
 If (Ev=DE_CHANGE) And ((D.C[Ct].Id=10) Or (D.C[Ct].Id=11)) Then Begin
  K:=D.C[Ct].Id-9;
  If K<>CommCur Then Begin
   CommFromDlg(D,CommCur);
   CommCur:=K;
   CommToDlg(D,K);
  End;
 End;
End;

Procedure CpComm;
Var D: TDlg; R,I: Integer; Sv: Array[1..2] Of TComSet;
Begin
 Sv:=ComSet;
 CommCur:=1;If CommPort='COM2' Then CommCur:=2;
 DlgInit(D,'',402,222);
 DlgBox(D,8,4,92,50,T3('Port','Port','Anschlu'#225));
 DlgRadio(D,10,18,22,1,'COM&1',CommCur=1);DlgRadio(D,11,18,36,1,'COM&2',CommCur=2);
 DlgBox(D,108,4,100,124,T3('Baud Rate','Vitesse','Baudrate'));
 For I:=0 To 6 Do DlgRadio(D,20+I,118,22+I*14,2,IntStr(Bauds[I]),False);
 DlgBox(D,8,58,92,70,T3('Stop Bits','Arr'#136't','Stopbits'));
 DlgRadio(D,50,18,76,5,'1',False);DlgRadio(D,51,18,90,5,'1.5',False);DlgRadio(D,52,18,104,5,'2',False);
 DlgBox(D,216,4,178,40,T3('Word Length','Longueur des mots','Wortl'#132'nge'));
 For I:=0 To 4 Do DlgRadio(D,30+I,224+I*34,22,3,IntStr(4+I),False);
 DlgBox(D,216,48,178,64,T3('Parity','Parit'#130,'Parit'#132't'));
 DlgRadio(D,40,224,64,4,T3('None','Aucune','Keine'),False);
 DlgRadio(D,41,224,78,4,T3('Odd','Impaire','Ungerade'),False);
 DlgRadio(D,42,224,92,4,T3('Even','Paire','Gerade'),False);
 DlgRadio(D,43,312,64,4,T3('Mark','Marque','Mark'),False);
 DlgRadio(D,44,312,78,4,T3('Space','Espace','Space'),False);
 DlgBox(D,216,116,178,62,T3('Handshake','Contr'#147'le de flux','Handshake'));
 DlgRadio(D,60,224,134,6,T3('&Hardware','&Mat'#130'riel','&Hardware'),False);
 DlgRadio(D,61,224,148,6,'XON/&XOFF',False);
 DlgRadio(D,62,224,162,6,T3('N&one','Aucu&n','Ke&in'),False);
 CommToDlg(D,CommCur);
 DlgButton(D,ID_OK,100,188,90,'OK',True);
 DlgButton(D,ID_CANCEL,210,188,90,T3('Cancel','Annuler','Abbrechen'),False);
 R:=RunDialog(D,@CommHook);
 If R=ID_OK Then Begin
  CommFromDlg(D,CommCur);
  If CommCur=2 Then CommPort:='COM2' Else CommPort:='COM1';
  CommMirror;
  IniSave;
 End Else ComSet:=Sv;
End;

Procedure CpBorder;
Var S: String;
Begin
 S:=IntStr(BorderW);
 If InputBox(T3('Border Width (3-12):','Largeur de bordure (3-12) :','Rahmenbreite (3-12):'),S,2,300) Then Begin
  BorderW:=Clamp(StrVal(S,3),3,12);
  IniSave;Dirty:=True;
 End;
End;

{ ================== souris ================== }
Procedure CpMouse;
Var D: TDlg; R: Integer;
Begin
 DlgInit(D,'',340,206);
 DlgCheck(D,10,10,10,T3('&Swap Left/Right Buttons','&Inverser les boutons gauche/droit','Linke/rechte Taste &vertauschen'),LeftHand);
 DlgText(D,10,36,T3('&Double-click speed:','Vitesse du &double-clic :','&Doppelklick-Geschwindigkeit:'));
 DlgSlider(D,11,10,52,310,15,100,115-DblCs);
 DlgText(D,10,76,T3('Slow','Lent','Langsam'));DlgText(D,270,76,T3('Fast','Rapide','Schnell'));
 DlgBox(D,10,94,320,56,T3('Mouse Acceleration','Acc'#130'l'#130'ration de la souris','Maus-Beschleunigung'));
 DlgRadio(D,20,22,112,1,T3('&None','&Aucune','&Keine'),MouseAcc=0);
 DlgRadio(D,21,120,112,1,T3('&Medium','&Moyenne','&Mittel'),MouseAcc=1);
 DlgRadio(D,22,230,112,1,T3('&High','&Haute','&Hoch'),MouseAcc=2);
 DlgButton(D,ID_OK,70,164,90,'OK',True);
 DlgButton(D,ID_CANCEL,180,164,90,T3('Cancel','Annuler','Abbrechen'),False);
 R:=RunDialog(D,@NoHook);
 If R=ID_OK Then Begin
  LeftHand:=DlgGetVal(D,10)=1;
  DblCs:=Clamp(115-DlgGetVal(D,11),15,100);
  MouseAcc:=Clamp(RadioGroupVal(D,1),0,2);
  IniSave;
 End;
End;

{ ================== parametres regionaux complets ================== }
Type
 TCntry = Record
  N: String[24]; Df: Integer; Ds: String[1]; C24: Boolean; Ts: String[1];
  Am,Pm: String[8]; Cs: String[4]; Cf,Dg: Integer; Dc,Th,Ls: String[1]; Lz: Boolean;
 End;

Const
 NCNTRY = 19;
 Cntry : Array[1..NCNTRY] Of TCntry = (
  (N:'United States';Df:0;Ds:'/';C24:False;Ts:':';Am:'AM';Pm:'PM';Cs:'$';Cf:0;Dg:2;Dc:'.';Th:',';Ls:',';Lz:False),
  (N:'Australia';Df:1;Ds:'/';C24:False;Ts:':';Am:'am';Pm:'pm';Cs:'$';Cf:0;Dg:2;Dc:'.';Th:',';Ls:',';Lz:False),
  (N:'Belgium';Df:1;Ds:'/';C24:True;Ts:':';Am:'';Pm:'';Cs:'BF';Cf:3;Dg:2;Dc:',';Th:'.';Ls:';';Lz:True),
  (N:'Canada (English)';Df:0;Ds:'/';C24:False;Ts:':';Am:'AM';Pm:'PM';Cs:'$';Cf:0;Dg:2;Dc:'.';Th:',';Ls:',';Lz:False),
  (N:'Canada (French)';Df:2;Ds:'-';C24:True;Ts:':';Am:'';Pm:'';Cs:'$';Cf:3;Dg:2;Dc:',';Th:' ';Ls:';';Lz:True),
  (N:'Denmark';Df:1;Ds:'-';C24:True;Ts:'.';Am:'';Pm:'';Cs:'kr';Cf:2;Dg:2;Dc:',';Th:'.';Ls:';';Lz:True),
  (N:'Finland';Df:1;Ds:'.';C24:True;Ts:'.';Am:'';Pm:'';Cs:'mk';Cf:3;Dg:2;Dc:',';Th:' ';Ls:';';Lz:True),
  (N:'France';Df:1;Ds:'/';C24:True;Ts:':';Am:'';Pm:'';Cs:'F';Cf:3;Dg:2;Dc:',';Th:' ';Ls:';';Lz:True),
  (N:'Germany';Df:1;Ds:'.';C24:True;Ts:':';Am:'';Pm:'';Cs:'DM';Cf:3;Dg:2;Dc:',';Th:'.';Ls:';';Lz:True),
  (N:'Italy';Df:1;Ds:'/';C24:True;Ts:'.';Am:'';Pm:'';Cs:'L.';Cf:2;Dg:0;Dc:',';Th:'.';Ls:';';Lz:True),
  (N:'Japan';Df:2;Ds:'/';C24:True;Ts:':';Am:'';Pm:'';Cs:#157;Cf:0;Dg:0;Dc:'.';Th:',';Ls:',';Lz:True),
  (N:'Netherlands';Df:1;Ds:'-';C24:True;Ts:':';Am:'';Pm:'';Cs:'f';Cf:2;Dg:2;Dc:',';Th:'.';Ls:';';Lz:True),
  (N:'Norway';Df:1;Ds:'.';C24:True;Ts:':';Am:'';Pm:'';Cs:'kr';Cf:2;Dg:2;Dc:',';Th:'.';Ls:';';Lz:True),
  (N:'Portugal';Df:1;Ds:'-';C24:True;Ts:':';Am:'';Pm:'';Cs:'Esc.';Cf:3;Dg:0;Dc:',';Th:'.';Ls:';';Lz:True),
  (N:'Spain';Df:1;Ds:'/';C24:True;Ts:':';Am:'';Pm:'';Cs:'Pts';Cf:3;Dg:0;Dc:',';Th:'.';Ls:';';Lz:True),
  (N:'Sweden';Df:2;Ds:'-';C24:True;Ts:'.';Am:'';Pm:'';Cs:'kr';Cf:3;Dg:2;Dc:',';Th:' ';Ls:';';Lz:True),
  (N:'Switzerland';Df:1;Ds:'.';C24:True;Ts:'.';Am:'';Pm:'';Cs:'SFr.';Cf:2;Dg:2;Dc:'.';Th:#39;Ls:';';Lz:True),
  (N:'United Kingdom';Df:1;Ds:'/';C24:True;Ts:':';Am:'';Pm:'';Cs:#156;Cf:0;Dg:2;Dc:'.';Th:',';Ls:',';Lz:True),
  (N:'Other Country';Df:0;Ds:'/';C24:False;Ts:':';Am:'AM';Pm:'PM';Cs:'$';Cf:0;Dg:2;Dc:'.';Th:',';Ls:',';Lz:False));

Var CtryList: PStrList;

{ charge les reglages d'un pays dans les controles }
Procedure CtryToDlg(Var D: TDlg; S: Integer);
Begin
 If (S<1) Or (S>NCNTRY) Then Exit;
 SelectRadio(D,DlgFind(D,20+Cntry[S].Df));
 SelectRadio(D,DlgFind(D,30+Ord(Cntry[S].C24)));
 SelectRadio(D,DlgFind(D,50+Cntry[S].Cf));
 DlgSetText(D,40,Cntry[S].Ds);DlgSetText(D,41,Cntry[S].Ts);
 DlgSetText(D,42,Cntry[S].Am);DlgSetText(D,43,Cntry[S].Pm);
 DlgSetText(D,44,Cntry[S].Cs);DlgSetText(D,45,IntStr(Cntry[S].Dg));
 DlgSetText(D,46,Cntry[S].Dc);DlgSetText(D,47,Cntry[S].Th);DlgSetText(D,48,Cntry[S].Ls);
 DlgSetVal(D,49,Ord(Cntry[S].Lz));
End;

{ exemple formate d'apres les controles }
Function CtrySample(Var D: TDlg): String;
Var Df,Cf,Dg,I: Integer; Ds,Ts,Am,Pm,Cs,Dc,Th,Nm,Ti,Da,Cu: String; C24,Lz: Boolean;
Begin
 Df:=Max2(0,RadioGroupVal(D,1));C24:=RadioGroupVal(D,2)=1;Cf:=Max2(0,RadioGroupVal(D,3));
 Ds:=DlgGetText(D,40);Ts:=DlgGetText(D,41);Am:=DlgGetText(D,42);Pm:=DlgGetText(D,43);
 Cs:=DlgGetText(D,44);Dg:=Clamp(StrVal(DlgGetText(D,45),2),0,3);
 Dc:=DlgGetText(D,46);Th:=DlgGetText(D,47);Lz:=DlgGetVal(D,49)=1;
 Nm:='1'+Th+'234';
 If Dg>0 Then Nm:=Nm+Dc+Copy('567',1,Dg);
 Case Cf Of
  0: Cu:=Cs+Nm;
  1: Cu:=Nm+Cs;
  2: Cu:=Cs+' '+Nm;
  Else Cu:=Nm+' '+Cs;
 End;
 If C24 Then Ti:='13'+Ts+'05'
 Else Ti:=IfThenS(Lz,'01','1')+Ts+'05 '+Pm;
 Case Df Of
  0: Da:='11'+Ds+'04'+Ds+'2026';
  1: Da:='04'+Ds+'11'+Ds+'2026';
  Else Da:='2026'+Ds+'11'+Ds+'04';
 End;
 CtrySample:=Da+'   '+Ti+'   '+Cu;
End;

Function CtryHook(Var D: TDlg; Ev,Ct: Integer): Boolean;
Begin
 CtryHook:=False;
 If Ev=DE_BUTTON Then Begin
  If D.C[Ct].Id=ID_RESET Then Begin
   CtryToDlg(D,DlgGetVal(D,10));DlgSetText(D,60,CtrySample(D));CtryHook:=True;
  End;
 End Else If (Ev=DE_CHANGE) Then Begin
  If D.C[Ct].Id=10 Then CtryToDlg(D,D.C[Ct].Val);
  If D.C[Ct].Id<>60 Then DlgSetText(D,60,CtrySample(D));
 End;
End;

Procedure CpCountry;
Var D: TDlg; R,I,Sel: Integer;
Begin
 New(CtryList);CtryList^.N:=NCNTRY;Sel:=NCNTRY;
 For I:=1 To NCNTRY Do Begin CtryList^.S[I]:=Cntry[I].N;If Cntry[I].N=CountryName Then Sel:=I;End;
 DlgInit(D,'',476,304);
 DlgText(D,10,6,T3('&Country:','&Pays :','&Land:'));
 DlgList(D,10,10,20,166,176,CtryList,Sel);
 DlgBox(D,184,4,134,92,T3('Date','Date','Datum'));
 DlgRadio(D,20,192,22,1,'M/D/Y',DateFmt=0);DlgRadio(D,21,192,36,1,'D/M/Y',DateFmt=1);DlgRadio(D,22,192,50,1,'Y/M/D',DateFmt=2);
 DlgText(D,192,70,T3('Se&p.:','S'#130'&p. :','&Trenn.:'));DlgEdit(D,40,256,66,40,DateSep,1);
 DlgBox(D,184,100,134,114,T3('Time','Heure','Zeit'));
 DlgRadio(D,30,192,118,2,T3('12 &hours','&12 heures','&12 Std.'),Not Clock24);DlgRadio(D,31,192,132,2,T3('24 h&ours','24 h&eures','24 S&td.'),Clock24);
 DlgText(D,192,150,T3('Sep&arator:','&S'#130'p. :','Trennzei&chen:'));DlgEdit(D,41,264,146,32,TimeSep,1);
 DlgText(D,192,168,T3('&AM:','&AM :','&AM:'));DlgEdit(D,42,232,164,72,S1159,8);
 DlgText(D,192,186,T3('P&M:','P&M :','P&M:'));DlgEdit(D,43,232,182,72,S2359,8);
 DlgBox(D,326,4,142,106,T3('Currency','Devise','W'#132'hrung'));
 DlgText(D,334,22,T3('Sym&bol:','Sym&bole :','Sym&bol:'));DlgEdit(D,44,398,18,56,CurSym,4);
 DlgRadio(D,50,334,38,3,'$1',CurFmt=0);DlgRadio(D,51,334,52,3,'1$',CurFmt=1);
 DlgRadio(D,52,334,66,3,'$ 1',CurFmt=2);DlgRadio(D,53,334,80,3,'1 $',CurFmt=3);
 DlgBox(D,326,114,142,100,T3('Numbers','Nombres','Zahlen'));
 DlgText(D,334,130,T3('Dig&its:','&Chiffres :','&Stellen:'));DlgEdit(D,45,430,126,24,IntStr(NumDigits),1);
 DlgText(D,334,148,T3('Dec&imal:','D'#130'c&imal :','Dez&imal:'));DlgEdit(D,46,430,144,24,DecSep,1);
 DlgText(D,334,166,T3('T&housands:','&Milliers :','&Tausend:'));DlgEdit(D,47,430,162,24,ThouSep,1);
 DlgText(D,334,184,T3('&List sep.:','&Liste :','Listen&trenn.:'));DlgEdit(D,48,430,180,24,ListSep,1);
 DlgCheck(D,49,10,222,T3('Leading &zero for hours','&Z'#130'ro initial pour les heures','F'#129'hrende N&ull bei Stunden'),LeadZero);
 DlgText(D,10,246,T3('Sample:','Exemple :','Beispiel:'));
 I:=DlgText(D,90,246,'');D.C[I].Id:=60;
 DlgButton(D,ID_OK,150,272,90,'OK',True);
 DlgButton(D,ID_CANCEL,250,272,90,T3('Cancel','Annuler','Abbrechen'),False);
 DlgButton(D,ID_RESET,350,272,90,T3('&Reset','R'#130'&init.','&Zur'#129'ck'),False);
 DlgSetText(D,60,CtrySample(D));
 R:=RunDialog(D,@CtryHook);
 If R=ID_OK Then Begin
  I:=DlgGetVal(D,10);If I>0 Then CountryName:=Cntry[I].N;
  DateFmt:=Max2(0,RadioGroupVal(D,1));
  Clock24:=RadioGroupVal(D,2)=1;
  CurFmt:=Max2(0,RadioGroupVal(D,3));
  DateSep:=DlgGetText(D,40);If DateSep='' Then DateSep:='/';
  TimeSep:=DlgGetText(D,41);If TimeSep='' Then TimeSep:=':';
  S1159:=DlgGetText(D,42);S2359:=DlgGetText(D,43);
  CurSym:=DlgGetText(D,44);
  NumDigits:=Clamp(StrVal(DlgGetText(D,45),2),0,9);
  DecSep:=DlgGetText(D,46);If DecSep='' Then DecSep:='.';
  ThouSep:=DlgGetText(D,47);
  ListSep:=DlgGetText(D,48);If ListSep='' Then ListSep:=',';
  LeadZero:=DlgGetVal(D,49)=1;
  IniSave;
 End;
 Dispose(CtryList);
End;

{ ---- Screen Colors ---- }

Const
 ScrNames : Array[0..NSCOL-1] Of String[60] = (
  'Screen Background~Fond de l''ecran~Bildschirmhintergrund',
  'Application Workspace~Espace de travail~Arbeitsbereich',
  'Window Background~Fond de fenetre~Fensterhintergrund',
  'Window Text~Texte de fenetre~Fenstertext',
  'Menu Bar~Barre de menus~Menueleiste',
  'Menu Text~Texte de menu~Menuetext',
  'Title Bar~Barre de titre~Titelleiste',
  'Inactive Title Bar~Titre inactif~Inaktive Titelleiste',
  'Title Text~Texte du titre~Titeltext',
  'Window Frame~Cadre de fenetre~Fensterrahmen');

Var
 TmpCol : Array[0..NSCOL-1] Of Integer;
 ScrLst : PStrList;
 ScrSel : Integer;

Procedure HsvToRgb(H,S,V: Integer; Var R,G,B: Integer);   { H 0..255, S,V 0..255 }
Var Hi,F,P,Q,T: Integer;
Begin
 Hi:=(H*6) Div 256;
 F:=(H*6) Mod 256;
 P:=V*(255-S) Div 255;
 Q:=V*(255-(S*F) Div 255) Div 255;
 T:=V*(255-(S*(255-F)) Div 255) Div 255;
 Case Hi Of
  0: Begin R:=V;G:=T;B:=P;End;
  1: Begin R:=Q;G:=V;B:=P;End;
  2: Begin R:=P;G:=V;B:=T;End;
  3: Begin R:=P;G:=Q;B:=V;End;
  4: Begin R:=T;G:=P;B:=V;End;
 Else Begin R:=V;G:=P;B:=Q;End;
 End;
End;

Procedure RgbToHsv(R,G,B: Integer; Var H,S,V: Integer);
Var Mx,Mn,D: Integer; Hh: Double;
Begin
 Mx:=R;If G>Mx Then Mx:=G;If B>Mx Then Mx:=B;
 Mn:=R;If G<Mn Then Mn:=G;If B<Mn Then Mn:=B;
 V:=Mx;D:=Mx-Mn;
 If Mx=0 Then S:=0 Else S:=D*255 Div Mx;
 If D=0 Then Begin H:=0;Exit;End;
 If Mx=R Then Hh:=(G-B)/D Else If Mx=G Then Hh:=2+(B-R)/D Else Hh:=4+(R-G)/D;
 If Hh<0 Then Hh:=Hh+6;
 H:=Round(Hh*256/6) Mod 256;
End;

Procedure ScrLoadSliders(Var D: TDlg);
Var H,S,V,C: Integer;
Begin
 C:=TmpCol[ScrSel-1];
 RgbToHsv(VgaRGB[C,0],VgaRGB[C,1],VgaRGB[C,2],H,S,V);
 DlgSetVal(D,21,H);DlgSetVal(D,22,V);DlgSetVal(D,23,S);
End;

Function ScrHook(Var D: TDlg; Ev,Ct: Integer): Boolean;
Var I,R,G,B,X,Y,W,H,K,C: Integer; Fr: Integer;
Begin
 ScrHook:=False;
 Case Ev Of
  DE_INIT: If Ct=0 Then Begin ScrSel:=1;DlgSetVal(D,10,1);ScrLoadSliders(D);End;
  DE_CHANGE: Begin
    If D.C[Ct].Id=10 Then Begin
     If D.C[Ct].Val>0 Then Begin ScrSel:=D.C[Ct].Val;ScrLoadSliders(D);End;
    End Else If (D.C[Ct].Id>=21) And (D.C[Ct].Id<=23) Then Begin
     HsvToRgb(DlgGetVal(D,21),DlgGetVal(D,23),Max2(40,DlgGetVal(D,22)),R,G,B);
     If DlgGetVal(D,22)<40 Then Begin R:=0;G:=0;B:=0;End;
     TmpCol[ScrSel-1]:=NearestVga(R,G,B);
    End;
   End;
  DE_DRAW: Begin
    X:=CtlX(D,Ct);Y:=CtlY(D,Ct);W:=D.C[Ct].W;H:=D.C[Ct].H;
    Case D.C[Ct].Id Of
     30: Begin  { echantillon }
       GBar(X,Y,X+W-1,Y+H-1,TmpCol[1]);
       GRect(X,Y,X+W-1,Y+H-1,TmpCol[9]);
       GBar(X+2,Y+2,X+W-3,Y+17,TmpCol[6]);
       GBar(X+W Div 2-26,Y+2,X+W Div 2+26,Y+16,cBlk);
       GText(X+W Div 2-24,Y+6,'Active',TmpCol[8]);
       GBar(X+2,Y+18,X+W-3,Y+33,TmpCol[4]);
       GText(X+8,Y+22,'File  Edit',TmpCol[5]);
       GHLine(X+2,X+W-3,Y+34,TmpCol[9]);
       GBar(X+8,Y+40,X+W-20,Y+H-8,TmpCol[1]);
       GBar(X+22,Y+48,X+W-34,Y+H-16,TmpCol[2]);
       GRect(X+22,Y+48,X+W-34,Y+H-16,cBlk);
       GText(X+W Div 2-40,Y+H Div 2+10,'Window Text',TmpCol[3]);
       GDither(X+W-18,Y+40,X+W-4,Y+H-8,cBlk,cWht);
      End;
     31: For I:=0 To W-1 Do Begin  { bande de teinte }
       HsvToRgb(I*255 Div W,255,255,R,G,B);GVLine(X+I,Y,Y+H-1,NearestVga(R,G,B));End;
     32: For I:=0 To W-1 Do Begin
       K:=I*255 Div W;If K<40 Then C:=0 Else Begin
        HsvToRgb(DlgGetVal(D,21),DlgGetVal(D,23),K,R,G,B);C:=NearestVga(R,G,B);End;
       GVLine(X+I,Y,Y+H-1,C);End;
     33: For I:=0 To W-1 Do Begin
       HsvToRgb(DlgGetVal(D,21),I*255 Div W,Max2(DlgGetVal(D,22),60),R,G,B);GVLine(X+I,Y,Y+H-1,NearestVga(R,G,B));End;
    End;
    GRect(X,Y,X+W-1,Y+H-1,cBlk);
   End;
  DE_BUTTON: If D.C[Ct].Id=24 Then Begin
    For I:=0 To NSCOL-1 Do TmpCol[I]:=ScrCol[I];
    ScrLoadSliders(D);ScrHook:=True;
   End;
 End;
End;

Procedure CpColors;
Var D: TDlg; R,I: Integer;
Begin
 For I:=0 To NSCOL-1 Do TmpCol[I]:=ScrCol[I];
 New(ScrLst);ScrLst^.N:=NSCOL;ScrSel:=1;
 For I:=0 To NSCOL-1 Do ScrLst^.S[I+1]:=TL(ScrNames[I]);
 DlgInit(D,'',545,285);
 DlgText(D,8,6,T3('&Screen Colors','&Couleurs de l''ecran','&Bildschirmfarben'));
 DlgText(D,330,6,T3('Sample','Echantillon','Beispiel'));
 DlgList(D,10,10,22,230,80,ScrLst,1);
 DlgText(D,10,114,T3('&Hue','&Teinte','&Farbton'));
 DlgCustom(D,31,100,108,130,10);DlgSlider(D,21,100,120,130,0,255,0);
 DlgText(D,10,152,T3('&Bright','&Luminosite','&Helligkeit'));
 DlgCustom(D,32,100,146,130,10);DlgSlider(D,22,100,158,130,0,255,255);
 DlgText(D,10,190,T3('&Color','&Couleur','&Sattigung'));
 DlgCustom(D,33,100,184,130,10);DlgSlider(D,23,100,196,130,0,255,255);
 DlgCustom(D,30,330,22,200,180);
 DlgButton(D,ID_OK,10,240,90,'OK',True);
 DlgButton(D,24,120,240,90,T3('Reset','Annuler tout','Zur'#129'ck'),False);
 DlgButton(D,ID_CANCEL,230,240,90,T3('Cancel','Annuler','Abbrechen'),False);
 R:=RunDialog(D,@ScrHook);
 If R=ID_OK Then Begin
  For I:=0 To NSCOL-1 Do ScrCol[I]:=TmpCol[I];
  ApplyScreenColors;IniSave;
 End;
 Dispose(ScrLst);
 Dirty:=True;
End;

Var
 CpSec,CpTF,CpDF: Integer;    { section active, champ heure, champ date }
 CpTest: Boolean; CpTestT: LongInt; CpDrag: Integer;

Procedure CpArrowBox(X,Y: Integer; Up: Boolean);
Begin
 GBar(X,Y,X+15,Y+11,cWht);GRect(X,Y,X+15,Y+11,cBlk);
 GArrow(X+8,Y+6,IfThen_(Up,1,2),cBlk);
End;

Procedure CpGetDate(Var Y,M,D: Integer);
Var Yy,Mm,Dd,Dw: Word;
Begin
 GetDate(Yy,Mm,Dd,Dw);Y:=Yy;M:=Mm;D:=Dd;
End;

Procedure CpAdjTime(Delta: Integer);
Var H,M,S,C: Word; Hh,Mi,Se: Integer;
Begin
 GetTime(H,M,S,C);Hh:=H;Mi:=M;Se:=S;
 Case CpTF Of
  0: Hh:=(Hh+Delta+24) Mod 24;
  1: Mi:=(Mi+Delta+60) Mod 60;
  2: Se:=(Se+Delta+60) Mod 60;
 End;
 {$I-}SetTime(Hh,Mi,Se,0);{$I+}
 If IOResult<>0 Then ;
End;

Procedure CpAdjDate(Delta: Integer);
Var Y,M,D: Integer; Dim: Integer;
Begin
 CpGetDate(Y,M,D);
 Case DateFmt Of
  0: Case CpDF Of 0: M:=M+Delta;1: D:=D+Delta;Else Y:=Y+Delta;End;
  1: Case CpDF Of 0: D:=D+Delta;1: M:=M+Delta;Else Y:=Y+Delta;End;
 Else Case CpDF Of 0: Y:=Y+Delta;1: M:=M+Delta;Else D:=D+Delta;End;
 End;
 If M<1 Then M:=12;If M>12 Then M:=1;
 Dim:=31;
 If (M=4) Or (M=6) Or (M=9) Or (M=11) Then Dim:=30 Else If M=2 Then Dim:=28+Ord(((Y Mod 4)=0) And ((Y Mod 100)<>0));
 If D<1 Then D:=Dim;If D>Dim Then D:=1;
 Y:=Clamp(Y,1980,2099);
 {$I-}SetDate(Y,M,D);{$I+}
 If IOResult<>0 Then ;
End;

Function CpBlinkPos: Integer;
Begin
 CpBlinkPos:=Clamp((1200-BlinkMs) Div 10,0,100);
End;

Procedure CpDraw(W: PWindow);
Var X1,Y1,X2,Y2,I: Integer; Hh,Mi,Se,Cc: Word; Y,M,D: Integer; Fl: Array[0..2] Of String; Ord_: Array[0..2] Of Integer;
    Bx,By: Integer;
Begin
 WinClient(W,X1,Y1,X2,Y2);
 GText(X1+14,Y1+8,T3('Time','Heure','Zeit'),cBlk);
 GetTime(Hh,Mi,Se,Cc);
 Fl[0]:=Pad2(Hh);Fl[1]:=Pad2(Mi);Fl[2]:=Pad2(Se);
 If Not Clock24 Then Begin
  I:=Hh Mod 12;If I=0 Then I:=12;Fl[0]:=IntStr(I);If Length(Fl[0])<2 Then Fl[0]:=' '+Fl[0];
 End;
 For I:=0 To 2 Do Begin
  Bx:=X1+14+I*24;By:=Y1+26;
  If (CpSec=0) And (CpTF=I) Then Begin GBar(Bx-1,By-2,Bx+16,By+10,cBlk);GText(Bx,By,Fl[I],cWht);End
  Else GText(Bx,By,Fl[I],cBlk);
  If I<2 Then GText(Bx+16,By,TimeSep,cBlk);
 End;
 If Not Clock24 Then GText(X1+14+72,Y1+26,IfThenS(Hh>=12,'PM','AM'),cBlk);
 CpArrowBox(X1+112,Y1+20,True);CpArrowBox(X1+112,Y1+34,False);
 GText(X1+220,Y1+8,T3('Date','Date','Datum'),cBlk);
 CpGetDate(Y,M,D);
 Case DateFmt Of
  0: Begin Fl[0]:=Pad2(M);Fl[1]:=Pad2(D);Fl[2]:=Copy(IntStr(Y),3,2);End;
  1: Begin Fl[0]:=Pad2(D);Fl[1]:=Pad2(M);Fl[2]:=Copy(IntStr(Y),3,2);End;
 Else Begin Fl[0]:=Copy(IntStr(Y),3,2);Fl[1]:=Pad2(M);Fl[2]:=Pad2(D);End;
 End;
 For I:=0 To 2 Do Begin
  Bx:=X1+220+I*24;By:=Y1+26;
  If (CpSec=1) And (CpDF=I) Then Begin GBar(Bx-1,By-2,Bx+16,By+10,cBlk);GText(Bx,By,Fl[I],cWht);End
  Else GText(Bx,By,Fl[I],cBlk);
  If I<2 Then GText(Bx+16,By,DateSep,cBlk);
 End;
 CpArrowBox(X1+316,Y1+20,True);CpArrowBox(X1+316,Y1+34,False);
 { cadences }
 GText(X1+14,Y1+66,T3('Cursor Blink','Clignotement','Cursor-Blinken'),cBlk);
 GText(X1+14,Y1+78,T3('slow','lent','langsam'),cBlk);GText(X1+14+110,Y1+78,T3('fast','rapide','schnell'),cBlk);
 DrawScroll(False,X1+14,Y1+90,X1+14+150,Y1+106,101,1,CpBlinkPos);
 GRect(X1+174,Y1+84,X1+206,Y1+108,cBlk);
 If (NowCs Div BlinkHalf) Mod 2=0 Then GVLine(X1+190,Y1+88,Y1+104,cBlk);
 GText(X1+220,Y1+66,T3('Double Click','Double-clic','Doppelklick'),cBlk);
 GText(X1+220,Y1+78,T3('slow','lent','langsam'),cBlk);GText(X1+220+100,Y1+78,T3('fast','rapide','schnell'),cBlk);
 DrawScroll(False,X1+220,Y1+90,X1+220+140,Y1+106,86,1,100-DblCs);
 If CpTest Then Begin GBar(X1+370,Y1+84,X1+412,Y1+108,cBlk);GText(X1+378,Y1+92,'TEST',cWht);End
 Else Begin GRect(X1+370,Y1+84,X1+412,Y1+108,cBlk);GText(X1+378,Y1+92,'TEST',cBlk);End;
 { section active : cadre pointille }
 Case CpSec Of
  0: Bx:=X1+8;1: Bx:=X1+214;2: Bx:=X1+8;Else Bx:=X1+214;
 End;
 By:=IfThen_(CpSec<2,Y1+4,Y1+62);
 For I:=0 To 100 Do If (I And 1)=0 Then Begin GPix(Bx+I,By,cBlk);GPix(Bx+I,By+46,cBlk);End;
End;

Var CpLastTick: LongInt;

Procedure CpTimerMain(W: PWindow);
Var Tk: LongInt;
Begin
 If (CpTest) And (NowCs-CpTestT>80) Then Begin CpTest:=False;Dirty:=True;End;
 Tk:=(NowCs Div BlinkHalf)*7+(NowCs Div 100);
 If Tk<>CpLastTick Then Begin CpLastTick:=Tk;Dirty:=True;End;
End;

Procedure CpMouseMain(W: PWindow; Var E: TEvent);
Var X1,Y1,X2,Y2,Pt,T: Integer;
Begin
 WinClient(W,X1,Y1,X2,Y2);
 If E.Kind=EV_UP Then Begin CpDrag:=0;Exit;End;
 If (E.Kind=EV_MOVE) And (CpDrag<>0) Then Begin
  If CpDrag=1 Then Begin
   T:=ScrollDrag(False,X1+14,Y1+90,X1+14+150,Y1+106,101,1,E.X,0);
   BlinkMs:=Clamp(1200-T*10,200,1200);BlinkHalf:=Max2(5,BlinkMs Div 20);
  End Else Begin
   T:=ScrollDrag(False,X1+220,Y1+90,X1+220+140,Y1+106,86,1,E.X,0);
   DblCs:=Clamp(100-T,15,100);
  End;
  Dirty:=True;Exit;
 End;
 If E.Kind<>EV_DOWN Then Exit;
 { heure }
 If InBox(E.X,E.Y,X1+10,Y1+22,X1+90,Y1+40) Then Begin CpSec:=0;CpTF:=Clamp((E.X-X1-10) Div 24,0,2);End
 Else If InBox(E.X,E.Y,X1+112,Y1+20,X1+128,Y1+31) Then Begin CpSec:=0;CpAdjTime(1);End
 Else If InBox(E.X,E.Y,X1+112,Y1+34,X1+128,Y1+45) Then Begin CpSec:=0;CpAdjTime(-1);End
 { date }
 Else If InBox(E.X,E.Y,X1+216,Y1+22,X1+300,Y1+40) Then Begin CpSec:=1;CpDF:=Clamp((E.X-X1-216) Div 24,0,2);End
 Else If InBox(E.X,E.Y,X1+316,Y1+20,X1+332,Y1+31) Then Begin CpSec:=1;CpAdjDate(1);End
 Else If InBox(E.X,E.Y,X1+316,Y1+34,X1+332,Y1+45) Then Begin CpSec:=1;CpAdjDate(-1);End
 { clignotement }
 Else If InBox(E.X,E.Y,X1+14,Y1+90,X1+164,Y1+106) Then Begin
  CpSec:=2;
  Pt:=ScrollPart(False,X1+14,Y1+90,X1+164,Y1+106,101,1,CpBlinkPos,E.X,E.Y);
  Case Pt Of
   1: T:=CpBlinkPos-5;2: T:=CpBlinkPos+5;3: T:=CpBlinkPos-20;4: T:=CpBlinkPos+20;Else T:=CpBlinkPos;
  End;
  If Pt=5 Then CpDrag:=1;
  BlinkMs:=Clamp(1200-Clamp(T,0,100)*10,200,1200);BlinkHalf:=Max2(5,BlinkMs Div 20);
  Capture:=W;
 End
 { double-clic }
 Else If InBox(E.X,E.Y,X1+220,Y1+90,X1+360,Y1+106) Then Begin
  CpSec:=3;
  Pt:=ScrollPart(False,X1+220,Y1+90,X1+360,Y1+106,86,1,100-DblCs,E.X,E.Y);
  T:=100-DblCs;
  Case Pt Of
   1: Dec(T,3);2: Inc(T,3);3: Dec(T,12);4: Inc(T,12);
  End;
  If Pt=5 Then CpDrag:=2;
  DblCs:=Clamp(100-Clamp(T,0,85),15,100);
  Capture:=W;
 End
 Else If InBox(E.X,E.Y,X1+370,Y1+84,X1+412,Y1+108) Then Begin
  If E.Dbl Then Begin CpTest:=True;CpTestT:=NowCs;End;
 End;
 IniSave;
 Dirty:=True;
End;

Procedure CpKeyMain(W: PWindow; K: Word);
Begin
 Case K Of
  K_TAB: CpSec:=(CpSec+1) Mod 4;
  K_UP: Case CpSec Of 0: CpAdjTime(1);1: CpAdjDate(1);End;
  K_DOWN: Case CpSec Of 0: CpAdjTime(-1);1: CpAdjDate(-1);End;
  K_LEFT: Case CpSec Of 0: CpTF:=(CpTF+2) Mod 3;1: CpDF:=(CpDF+2) Mod 3;
    2: Begin BlinkMs:=Clamp(BlinkMs+50,200,1200);BlinkHalf:=Max2(5,BlinkMs Div 20);IniSave;End;
    3: Begin DblCs:=Clamp(DblCs+3,15,100);IniSave;End;End;
  K_RIGHT: Case CpSec Of 0: CpTF:=(CpTF+1) Mod 3;1: CpDF:=(CpDF+1) Mod 3;
    2: Begin BlinkMs:=Clamp(BlinkMs-50,200,1200);BlinkHalf:=Max2(5,BlinkMs Div 20);IniSave;End;
    3: Begin DblCs:=Clamp(DblCs-3,15,100);IniSave;End;End;
 End;
 Dirty:=True;
End;

Procedure CpMenu(W: PWindow; Cmd: Integer);
Begin
 Case Cmd Of
  CM_P_ADDPRN: CpAddPrinter;
  CM_P_DELPRN: CpDelPrinter;
  CM_P_ADDFONT: CpAddFont;
  CM_P_DELFONT: CpDelFont;
  CM_P_EXIT: CloseWindow(W);
  CM_P_ABOUT: ShowAboutMs('Control Panel',4,False);
  CM_P_CONN: CpConnections;
  CM_P_PRINTER: CpPrinter;
  CM_P_COMM: CpComm;
  CM_P_COLORS: CpColors;
  CM_P_BORDER: CpBorder;
  CM_P_BEEP: Begin Beeping:=Not Beeping;IniSave;End;
  CM_P_MOUSE: CpMouse;
  CM_P_COUNTRY: CpCountry;
 End;
 Dirty:=True;
End;

Procedure CpPrepare(W: PWindow);
Begin
 MenuCheck(W,CM_P_BEEP,Beeping);
End;


Function CtrlCreate: PWindow;
Var W: PWindow;
Begin
 W:=NewWindow(A_CTRL,'Control Panel',-1,-1,440,196,False);
 If W=Nil Then Begin CtrlCreate:=Nil;Exit;End;
 WinAddMenu(W,'&Installation~&Installation~&Installation');
 WinAddItem(W,'Add New &Printer...~Ajouter une &imprimante...~&Drucker hinzuf'#129'gen...',CM_P_ADDPRN,'');
 WinAddItem(W,'&Delete Printer...~&Supprimer une imprimante...~Drucker &l'#148'schen...',CM_P_DELPRN,'');
 WinAddItem(W,'Add New &Font...~Ajouter une &police...~Schrift &hinzuf'#129'gen...',CM_P_ADDFONT,'');
 WinAddItem(W,'Delete F&ont...~Supprimer une p&olice...~Schrift l'#148'&schen...',CM_P_DELFONT,'');
 WinAddSep(W);
 WinAddItem(W,'E&xit~&Quitter~&Beenden',CM_P_EXIT,'');
 WinAddItem(W,'A&bout Control Panel...~&'#133' propos de Control Panel...~'#154'&ber Control Panel...',CM_P_ABOUT,'');
 WinAddMenu(W,'&Setup~&Configuration~&Einrichten');
 WinAddItem(W,'&Connections...~&Connexions...~&Anschl'#129'sse...',CM_P_CONN,'');
 WinAddItem(W,'&Printer...~&Imprimante...~&Drucker...',CM_P_PRINTER,'');
 WinAddItem(W,'C&ommunications Port...~Port de c&ommunication...~&Schnittstelle...',CM_P_COMM,'');
 WinAddMenu(W,'&Preferences~&Pr'#130'f'#130'rences~&Voreinstellungen');
 WinAddItem(W,'&Screen Colors...~&Couleurs de l''ecran...~&Bildschirmfarben...',CM_P_COLORS,'');
 WinAddItem(W,'&Border Width...~&Largeur de bordure...~&Rahmenbreite...',CM_P_BORDER,'');
 WinAddItem(W,'&Warning Beep~&Bip d''alerte~&Warnton',CM_P_BEEP,'');
 WinAddItem(W,'&Mouse...~&Souris...~&Maus...',CM_P_MOUSE,'');
 WinAddItem(W,'Countr&y Settings...~Param'#138'tres r'#130'&gionaux...~&L'#132'ndereinstellungen...',CM_P_COUNTRY,'');
 CtrlCreate:=W;
End;

{ ====================================================================== }
{                             PIF EDITOR                                 }
{ ====================================================================== }

Const
 CM_F_NEW=501; CM_F_OPEN=502; CM_F_SAVE=503; CM_F_SAVEAS=504; CM_F_EXIT=505; CM_F_ABOUT=506;

Type
 PPif = ^TPif;
 TPif = Record
  Prog,Title,Params,Dir : String[63];
  MemReq,MemDes : Integer;
  ModCom1,ModCom2,ModKbd : Boolean;
  Switch : Integer;        { 0 aucun, 1 texte, 2 graphique }
  NoSwitch,NoExch,CloseExit : Boolean;
  FileName: String[80];
  Modified: Boolean;
 End;

Procedure PifClear(P: PPif);
Begin
 P^.Prog:='';P^.Title:='';P^.Params:='';P^.Dir:='';
 P^.MemReq:=128;P^.MemDes:=640;
 P^.ModCom1:=False;P^.ModCom2:=False;P^.ModKbd:=False;P^.Switch:=0;
 P^.NoSwitch:=False;P^.NoExch:=False;P^.CloseExit:=True;
 P^.FileName:='';P^.Modified:=False;
End;

Procedure PutStr(Var B: Array Of Byte; Ofs,Len: Integer; Const S: String);
Var I: Integer;
Begin
 For I:=0 To Len-1 Do
  If I<Length(S) Then B[Ofs+I]:=Ord(S[I+1]) Else B[Ofs+I]:=0;
End;

Function GetStr(Var B: Array Of Byte; Ofs,Len: Integer): String;
Var I: Integer; S: String;
Begin
 S:='';
 For I:=0 To Len-1 Do Begin
  If B[Ofs+I]=0 Then Break;
  S:=S+Chr(B[Ofs+I]);
 End;
 GetStr:=Trim(S);
End;

{ Fichier .PIF : 369 octets (disposition Windows 2.x) }
Function PifSave(P: PPif; Const Path: String): Boolean;
Var B: Array[0..368] Of Byte; F: File; I,Ck: Integer;
Begin
 FillChar(B,SizeOf(B),0);
 PutStr(B,2,30,P^.Title);
 B[$20]:=P^.MemDes And 255;B[$21]:=P^.MemDes Shr 8;
 B[$22]:=P^.MemReq And 255;B[$23]:=P^.MemReq Shr 8;
 PutStr(B,$24,63,P^.Prog);
 B[$63]:=Ord(P^.ModCom1) Or (Ord(P^.ModCom2) Shl 1) Or (Ord(P^.ModKbd) Shl 2) Or
  (Ord(P^.NoExch) Shl 3) Or (Ord(P^.NoSwitch) Shl 4) Or (Ord(P^.CloseExit) Shl 5);
 PutStr(B,$65,64,P^.Dir);
 PutStr(B,$A5,64,P^.Params);
 B[$E5]:=P^.Switch;
 Ck:=0;For I:=2 To 368 Do Ck:=Ck+B[I];
 B[1]:=(256-(Ck And 255)) And 255;
 {$I-}
 Assign(F,V2R(Path));Rewrite(F,1);
 BlockWrite(F,B,369);Close(F);
 {$I+}
 PifSave:=IOResult=0;
End;

Function PifLoad(P: PPif; Const Path: String): Boolean;
Var B: Array[0..368] Of Byte; F: File; N: Word;
Begin
 PifLoad:=False;
 {$I-}
 Assign(F,V2R(Path));Reset(F,1);
 If IOResult<>0 Then Exit;
 BlockRead(F,B,369,N);Close(F);
 {$I+}
 If N<369 Then Exit;
 P^.Title:=GetStr(B,2,30);
 P^.MemDes:=B[$20]+B[$21]*256;P^.MemReq:=B[$22]+B[$23]*256;
 P^.Prog:=GetStr(B,$24,63);
 P^.ModCom1:=(B[$63] And 1)<>0;P^.ModCom2:=(B[$63] And 2)<>0;P^.ModKbd:=(B[$63] And 4)<>0;
 P^.NoExch:=(B[$63] And 8)<>0;P^.NoSwitch:=(B[$63] And 16)<>0;P^.CloseExit:=(B[$63] And 32)<>0;
 P^.Dir:=GetStr(B,$65,64);P^.Params:=GetStr(B,$A5,64);P^.Switch:=B[$E5];
 P^.FileName:=Path;P^.Modified:=False;
 PifLoad:=True;
End;

Const
 PifRows = 11;

Function PifRowY(W: PWindow; I: Integer): Integer;
Var X1,Y1,X2,Y2: Integer;
Begin
 WinClient(W,X1,Y1,X2,Y2);
 PifRowY:=Y1+10+I*24;
End;

Procedure PifDraw(W: PWindow);
Var P: PPif; X1,Y1,X2,Y2,Y: Integer;
 Procedure Fld(I: Integer; Const Cap,Val_: String);
 Begin
  Y:=PifRowY(W,I);
  GText(X1+8,Y+4,Cap,cBlk);
  GBar(X1+190,Y,X2-8,Y+16,cWht);GRect(X1+190,Y,X2-8,Y+16,cBlk);
  GText(X1+194,Y+4,Copy(Val_,1,((X2-X1-210) Div 8)),cBlk);
 End;
 Procedure Chk(X,Yy: Integer; On: Boolean; Const Cap: String);
 Begin
  GBar(X,Yy,X+10,Yy+10,cWht);GRect(X,Yy,X+10,Yy+10,cBlk);
  If On Then Begin GLine(X+2,Yy+2,X+8,Yy+8,cBlk);GLine(X+8,Yy+2,X+2,Yy+8,cBlk);End;
  GText(X+16,Yy+1,Cap,cBlk);
 End;
 Procedure Rad(X,Yy: Integer; On: Boolean; Const Cap: String);
 Begin
  GFillEllipse(X+5,Yy+5,5,5,cWht);GEllipse(X+5,Yy+5,5,5,cBlk);
  If On Then GFillEllipse(X+5,Yy+5,2,2,cBlk);
  GText(X+16,Yy+1,Cap,cBlk);
 End;
Begin
 P:=W^.Data;
 WinClient(W,X1,Y1,X2,Y2);
 Fld(0,T3('Program Name:','Nom du programme :','Programmname:'),P^.Prog);
 Fld(1,T3('Window Title:','Titre de la fen'#136'tre :','Fenstertitel:'),P^.Title);
 Fld(2,T3('Optional Parameters:','Param'#138'tres :','Parameter:'),P^.Params);
 Fld(3,T3('Start-up Directory:','R'#130'pertoire de d'#130'part :','Startverzeichnis:'),P^.Dir);
 Fld(4,T3('Memory Required (KB):','M'#130'moire requise (Ko) :','Speicher ben'#148'tigt (KB):'),IntStr(P^.MemReq));
 Fld(5,T3('Memory Desired (KB):','M'#130'moire souhait'#130'e (Ko) :','Speicher gew'#129'nscht (KB):'),IntStr(P^.MemDes));
 Y:=PifRowY(W,6);
 GText(X1+8,Y+1,T3('Directly Modifies:','Modifie directement :','Direkt '#132'ndert:'),cBlk);
 Chk(X1+190,Y,P^.ModCom1,'COM1');Chk(X1+260,Y,P^.ModCom2,'COM2');Chk(X1+330,Y,P^.ModKbd,T3('Keyboard','Clavier','Tastatur'));
 Y:=PifRowY(W,7);
 GText(X1+8,Y+1,T3('Screen Exchange:','Echange d''ecran :','Bildschirmaustausch:'),cBlk);
 Rad(X1+190,Y,P^.Switch=0,T3('None','Aucun','Keiner'));Rad(X1+260,Y,P^.Switch=1,'Text');Rad(X1+330,Y,P^.Switch=2,T3('Graphics','Graphique','Grafik'));
 Chk(X1+190,PifRowY(W,8),P^.NoSwitch,T3('Prevent Program Switch','Interdire le changement','Programmwechsel verhindern'));
 Chk(X1+190,PifRowY(W,9),P^.NoExch,T3('No Screen Exchange','Pas d''echange d''ecran','Kein Bildschirmaustausch'));
 Chk(X1+190,PifRowY(W,10),P^.CloseExit,T3('Close Window on Exit','Fermer '#133' la fin','Fenster beim Beenden schlie'#225'en'));
End;

Procedure PifEditField(W: PWindow; I: Integer);
Var P: PPif; S: String;
Begin
 P:=W^.Data;
 Case I Of
  0: S:=P^.Prog; 1: S:=P^.Title; 2: S:=P^.Params; 3: S:=P^.Dir;
  4: S:=IntStr(P^.MemReq); 5: S:=IntStr(P^.MemDes);
 Else Exit;
 End;
 If Not InputBox(T3('Enter new value:','Entrez la nouvelle valeur :','Neuen Wert eingeben:'),S,63,380) Then Exit;
 Case I Of
  0: P^.Prog:=S; 1: P^.Title:=Copy(S,1,30); 2: P^.Params:=S; 3: P^.Dir:=S;
  4: P^.MemReq:=Clamp(StrVal(S,128),1,640); 5: P^.MemDes:=Clamp(StrVal(S,640),1,640);
 End;
 P^.Modified:=True;
End;

Procedure PifMouse(W: PWindow; Var E: TEvent);
Var P: PPif; X1,Y1,X2,Y2,I,Y: Integer;
Begin
 If E.Kind<>EV_DOWN Then Exit;
 P:=W^.Data;
 WinClient(W,X1,Y1,X2,Y2);
 For I:=0 To 5 Do Begin
  Y:=PifRowY(W,I);
  If InBox(E.X,E.Y,X1+190,Y,X2-8,Y+16) Then Begin PifEditField(W,I);Dirty:=True;Exit;End;
 End;
 Y:=PifRowY(W,6);
 If InBox(E.X,E.Y,X1+190,Y,X1+250,Y+12) Then P^.ModCom1:=Not P^.ModCom1;
 If InBox(E.X,E.Y,X1+260,Y,X1+320,Y+12) Then P^.ModCom2:=Not P^.ModCom2;
 If InBox(E.X,E.Y,X1+330,Y,X1+420,Y+12) Then P^.ModKbd:=Not P^.ModKbd;
 Y:=PifRowY(W,7);
 If InBox(E.X,E.Y,X1+190,Y,X1+250,Y+12) Then P^.Switch:=0;
 If InBox(E.X,E.Y,X1+260,Y,X1+320,Y+12) Then P^.Switch:=1;
 If InBox(E.X,E.Y,X1+330,Y,X1+420,Y+12) Then P^.Switch:=2;
 If InBox(E.X,E.Y,X1+190,PifRowY(W,8),X1+400,PifRowY(W,8)+12) Then P^.NoSwitch:=Not P^.NoSwitch;
 If InBox(E.X,E.Y,X1+190,PifRowY(W,9),X1+400,PifRowY(W,9)+12) Then P^.NoExch:=Not P^.NoExch;
 If InBox(E.X,E.Y,X1+190,PifRowY(W,10),X1+400,PifRowY(W,10)+12) Then P^.CloseExit:=Not P^.CloseExit;
 P^.Modified:=True;
 Dirty:=True;
End;

Procedure PifTitle(W: PWindow);
Var P: PPif;
Begin
 P:=W^.Data;
 W^.Title:='PIF Editor - '+IfThenS(P^.FileName='',T3('(Untitled)','(Sans titre)','(Unbenannt)'),BaseName(P^.FileName));
End;

Procedure PifMenu(W: PWindow; Cmd: Integer);
Var P: PPif; S: String;
Begin
 P:=W^.Data;
 Case Cmd Of
  CM_F_NEW: Begin PifClear(P);PifTitle(W);End;
  CM_F_OPEN: Begin S:='';If FileDialog(0,T3('Open PIF:','Ouvrir le PIF :','PIF '#148'ffnen:'),'*.PIF',S) Then
     If PifLoad(P,S) Then PifTitle(W) Else InfoBox(T3('Invalid PIF file.','Fichier PIF invalide.','Ung'#129'ltige PIF-Datei.'));End;
  CM_F_SAVE,CM_F_SAVEAS: Begin
    S:=P^.FileName;
    If (Cmd=CM_F_SAVEAS) Or (S='') Then Begin
     If Not FileDialog(1,T3('Save PIF As:','Enregistrer le PIF sous :','PIF speichern unter:'),'*.PIF',S) Then Exit;
    End;
    If PifSave(P,S) Then Begin P^.FileName:=S;P^.Modified:=False;PifTitle(W);End
    Else InfoBox(T3('Cannot save the file.','Impossible d''enregistrer.','Speichern nicht m'#148'glich.'));
   End;
  CM_F_EXIT: CloseWindow(W);
  CM_F_ABOUT: ShowAboutMs('PIF Editor',4,False);
 End;
 Dirty:=True;
End;

Function PifCreate(Const Path: String): PWindow;
Var W: PWindow; P: PPif;
Begin
 W:=NewWindow(A_PIF,'PIF Editor',-1,-1,480,PifRows*24+60,True);
 If W=Nil Then Begin PifCreate:=Nil;Exit;End;
 New(P);FillChar(P^,SizeOf(TPif),0);PifClear(P);
 W^.Data:=P;
 WinAddMenu(W,'&File~&Fichier~&Datei');
 WinAddItem(W,'&New~&Nouveau~&Neu',CM_F_NEW,'');
 WinAddItem(W,'&Open...~&Ouvrir...~'#142'&ffnen...',CM_F_OPEN,'');
 WinAddItem(W,'&Save~&Enregistrer~&Speichern',CM_F_SAVE,'');
 WinAddItem(W,'Save &As...~Enregistrer &sous...~Speichern &unter...',CM_F_SAVEAS,'');
 WinAddSep(W);
 WinAddItem(W,'E&xit~&Quitter~&Beenden',CM_F_EXIT,'');
 WinAddItem(W,'A&bout PIF Editor...~&'#133' propos de PIF Editor...~'#154'&ber PIF Editor...',CM_F_ABOUT,'');
 If (Path<>'') Then PifLoad(P,Path);
 PifTitle(W);
 PifCreate:=W;
End;

{ ====================================================================== }
{                              TERMINAL                                  }
{ ====================================================================== }

Const
 CM_T_NEW=601; CM_T_OPEN=602; CM_T_SAVE=603; CM_T_SAVEAS=604; CM_T_PRINT=605;
 CM_T_EXIT=606; CM_T_ABOUT=607;
 CM_T_COPY=611; CM_T_PASTE=612; CM_T_CLEAR=613;
 CM_T_CONNECT=621; CM_T_DISC=622; CM_T_CAPTURE=623; CM_T_PAUSE=624; CM_T_BREAK=625;
 CM_T_SETTERM=631; CM_T_SETCOMM=632; CM_T_SETPHONE=633;
 TROWS = 200; TCOLS = 80;

Type
 PTerm = ^TTerm;
 TTerm = Record
  Scr   : Array[0..TROWS-1] Of String[TCOLS];
  CR,CC : Integer;
  Connected,Dialing,LocalEcho,Wrap,Pause,Capture : Boolean;
  TType : Integer;
  Phone : String[30];
  Tone  : Boolean;
  T0    : LongInt;
  Line  : String[80];
  Esc   : String[20];
  InEsc : Boolean;
  FileName: String[80];
  Cap   : Pointer;
  Pend  : String[250];       { sortie differee de l'hote simule }
  LastCs: LongInt;
 End;

Procedure TermScroll(T: PTerm);
Var I: Integer;
Begin
 For I:=0 To TROWS-2 Do T^.Scr[I]:=T^.Scr[I+1];
 T^.Scr[TROWS-1]:='';
 If T^.CR>0 Then Dec(T^.CR);
End;

Procedure TermPut(T: PTerm; C: Char);
Var N,P,V: Integer; S: String;
Begin
 If T^.InEsc Then Begin
  T^.Esc:=T^.Esc+C;
  If (C>='@') And (C<='~') And (C<>'[') Then Begin
   T^.InEsc:=False;
   S:=Copy(T^.Esc,2,Length(T^.Esc)-2);
   Case C Of
    'J': Begin If Pos('2',S)>0 Then Begin For N:=0 To TROWS-1 Do T^.Scr[N]:='';T^.CR:=0;T^.CC:=0;End;End;
    'K': Begin T^.Scr[T^.CR]:=Copy(T^.Scr[T^.CR],1,T^.CC);End;
    'H','f': Begin
      P:=Pos(';',S);
      If P=0 Then Begin T^.CR:=0;T^.CC:=0;End
      Else Begin T^.CR:=Clamp(StrVal(Copy(S,1,P-1),1)-1,0,TROWS-1);T^.CC:=Clamp(StrVal(Copy(S,P+1,5),1)-1,0,TCOLS-1);End;
     End;
    'A': If T^.CR>0 Then Dec(T^.CR);
    'B': If T^.CR<TROWS-1 Then Inc(T^.CR);
    'C': If T^.CC<TCOLS-1 Then Inc(T^.CC);
    'D': If T^.CC>0 Then Dec(T^.CC);
   End;
  End;
  If Length(T^.Esc)>18 Then T^.InEsc:=False;
  Exit;
 End;
 Case C Of
  #27: Begin If T^.TType=2 Then Begin T^.InEsc:=True;T^.Esc:='';End;End;
  #13: T^.CC:=0;
  #10: Begin Inc(T^.CR);If T^.CR>=TROWS Then Begin Dec(T^.CR);TermScroll(T);End;End;
  #8: If T^.CC>0 Then Begin Dec(T^.CC);Delete(T^.Scr[T^.CR],T^.CC+1,1);End;
  #7: Beep;
 Else If C>=' ' Then Begin
   While Length(T^.Scr[T^.CR])<T^.CC Do T^.Scr[T^.CR]:=T^.Scr[T^.CR]+' ';
   If T^.CC<Length(T^.Scr[T^.CR]) Then T^.Scr[T^.CR][T^.CC+1]:=C
   Else T^.Scr[T^.CR]:=T^.Scr[T^.CR]+C;
   Inc(T^.CC);
   If T^.CC>=TCOLS Then Begin
    If T^.Wrap Then Begin T^.CC:=0;Inc(T^.CR);If T^.CR>=TROWS Then Begin Dec(T^.CR);TermScroll(T);End;End
    Else T^.CC:=TCOLS-1;
   End;
  End;
 End;
End;

Procedure TermStr(T: PTerm; Const S: String);
Var I: Integer;
Begin
 For I:=1 To Length(S) Do TermPut(T,S[I]);
End;

Procedure TermHost(T: PTerm; Const Cmd: String);
Var U: String; H,M,S,Y,Mo,D: Integer;
Begin
 U:=Upper(Trim(Cmd));
 GetNow(H,M,S);GetToday(Y,Mo,D);
 If U='HELP' Then T^.Pend:=T^.Pend+#13#10'HELP TIME DATE VER ECHO <text> CLS BYE'#13#10
 Else If U='TIME' Then T^.Pend:=T^.Pend+#13#10+TimeStr(H,M,S)+#13#10
 Else If U='DATE' Then T^.Pend:=T^.Pend+#13#10+DayName(DayOfWeek(Y,Mo,D))+' '+DateStr(Y,Mo,D)+#13#10
 Else If U='VER' Then T^.Pend:=T^.Pend+#13#10'WINDOWS2 Terminal simulated host 2.03'#13#10
 Else If Copy(U,1,5)='ECHO ' Then T^.Pend:=T^.Pend+#13#10+Copy(Trim(Cmd),6,100)+#13#10
 Else If U='CLS' Then T^.Pend:=T^.Pend+#27'[2J'#27'[H'
 Else If U='BYE' Then T^.Pend:=T^.Pend+#13#10'Goodbye!'#13#10#1
 Else If U<>'' Then T^.Pend:=T^.Pend+#13#10'?'#13#10;
 If U<>'BYE' Then T^.Pend:=T^.Pend+'> ';
End;

Procedure TermDisc(T: PTerm);
Begin
 If T^.Connected Or T^.Dialing Then Begin
  T^.Connected:=False;T^.Dialing:=False;
  TermStr(T,#13#10'NO CARRIER'#13#10);
 End;
End;

Procedure TermTimer(W: PWindow);
Var T: PTerm; N: Integer; C: Char;
Begin
 T:=W^.Data;
 If T^.Dialing And (NowCs-T^.T0>150) Then Begin
  T^.Dialing:=False;T^.Connected:=True;
  TermStr(T,'CONNECT '+IntStr(CommBaud)+#13#10);
  T^.Pend:=#13#10'Welcome to the WINDOWS2 simulated host.'#13#10'Type HELP for the list of commands.'#13#10'> ';
  Invalidate(W);
 End;
 If (T^.Pend<>'') And (NowCs<>T^.LastCs) And Not T^.Pause Then Begin
  T^.LastCs:=NowCs;
  For N:=1 To Min2(6,Length(T^.Pend)) Do Begin
   C:=T^.Pend[1];Delete(T^.Pend,1,1);
   If C=#1 Then TermDisc(T) Else TermPut(T,C);
  End;
  Invalidate(W);
 End;
End;

Procedure TermDraw(W: PWindow);
Var T: PTerm; X1,Y1,X2,Y2,R,Rows,I: Integer; Last: Integer;
Begin
 T:=W^.Data;
 WinClient(W,X1,Y1,X2,Y2);
 Rows:=(Y2-Y1+1) Div 10;
 Last:=0;
 For I:=0 To TROWS-1 Do If (T^.Scr[I]<>'') Or (I<=T^.CR) Then Last:=I;
 W^.HasVS:=True;W^.VTot:=Last+1;W^.VPage:=Rows;
 If W^.VPos>Max2(0,W^.VTot-Rows) Then W^.VPos:=Max2(0,W^.VTot-Rows);
 For R:=0 To Rows-1 Do Begin
  I:=W^.VPos+R;
  If I>=TROWS Then Break;
  GText(X1+4,Y1+2+R*10,Copy(T^.Scr[I],1,(X2-X1-8) Div 8),cBlk);
 End;
 If (T^.CR>=W^.VPos) And (T^.CR<W^.VPos+Rows) And ((NowCs Div BlinkHalf) Mod 2=0) Then
  GBar(X1+4+T^.CC*8,Y1+10+(T^.CR-W^.VPos)*10,X1+11+T^.CC*8,Y1+11+(T^.CR-W^.VPos)*10,cBlk);
 If T^.Connected Then GText(X2-90,Y1+2,'[ON LINE]',cDGr)
 Else If T^.Dialing Then GText(X2-90,Y1+2,'[DIALING]',cDGr);
End;

Procedure TermKey(W: PWindow; K: Word);
Var T: PTerm; Ch: Char;
Begin
 T:=W^.Data;
 If K=22 Then Begin AppMenu(W,CM_T_PASTE);Exit;End;
 If K=3 Then Begin AppMenu(W,CM_T_COPY);Exit;End;
 If K=K_PGUP Then Begin If W^.VPos>0 Then Dec(W^.VPos,5);Dirty:=True;Exit;End;
 If K=K_PGDN Then Begin Inc(W^.VPos,5);Dirty:=True;Exit;End;
 If K>255 Then Exit;
 Ch:=Chr(K);
 W^.VPos:=Max2(0,T^.CR-5);
 If T^.Connected Then Begin
  If K=K_ENTER Then Begin
   If T^.LocalEcho Then TermStr(T,#13#10);
   TermHost(T,T^.Line);T^.Line:='';
  End Else Begin
   If (K=K_BKSP) Then Begin If T^.Line<>'' Then Begin Delete(T^.Line,Length(T^.Line),1);End;End
   Else If Length(T^.Line)<78 Then T^.Line:=T^.Line+Ch;
   If T^.LocalEcho Then TermPut(T,Ch)
   Else If (K<>K_BKSP) Then T^.Pend:=T^.Pend+Ch Else T^.Pend:=T^.Pend+#8;
  End;
 End Else Begin
  If K=K_ENTER Then TermStr(T,#13#10) Else TermPut(T,Ch);
 End;
 Invalidate(W);
End;

Procedure TermSettings(W: PWindow);
Var T: PTerm; D: TDlg; R: Integer;
Begin
 T:=W^.Data;
 DlgInit(D,'',330,160);
 DlgBox(D,8,4,150,76,T3('Terminal Emulation','Emulation de terminal','Terminal-Emulation'));
 DlgRadio(D,10,18,22,1,'&ASCII (TTY)',T^.TType=0);
 DlgRadio(D,11,18,38,1,'DEC VT-&52',T^.TType=1);
 DlgRadio(D,12,18,54,1,'ANSI (VT-&100)',T^.TType=2);
 DlgCheck(D,20,180,12,T3('&Local Echo','&Echo local','&Lokales Echo'),T^.LocalEcho);
 DlgCheck(D,21,180,32,T3('&Wrap Around','&Retour '#133' la ligne','&Zeilenumbruch'),T^.Wrap);
 DlgButton(D,ID_OK,50,116,90,'OK',True);
 DlgButton(D,ID_CANCEL,180,116,90,T3('Cancel','Annuler','Abbrechen'),False);
 R:=RunDialog(D,@NoHook);
 If R=ID_OK Then Begin
  T^.TType:=Max2(0,RadioGroupVal(D,1));
  T^.LocalEcho:=DlgGetVal(D,20)=1;T^.Wrap:=DlgGetVal(D,21)=1;
 End;
End;

Procedure TermPhone(W: PWindow);
Var T: PTerm; D: TDlg; R: Integer;
Begin
 T:=W^.Data;
 DlgInit(D,'',320,140);
 DlgText(D,10,10,T3('Phone Number:','Num'#130'ro de t'#130'l'#130'phone :','Telefonnummer:'));
 DlgEdit(D,10,10,26,300,T^.Phone,30);
 DlgRadio(D,11,10,54,1,T3('&Tone','&Tonalit'#130,'&Ton'),T^.Tone);
 DlgRadio(D,12,100,54,1,T3('&Pulse','&Impulsions','&Impuls'),Not T^.Tone);
 DlgButton(D,ID_OK,50,92,90,'OK',True);
 DlgButton(D,ID_CANCEL,170,92,90,T3('Cancel','Annuler','Abbrechen'),False);
 R:=RunDialog(D,@NoHook);
 If R=ID_OK Then Begin T^.Phone:=DlgGetText(D,10);T^.Tone:=RadioGroupVal(D,1)=0;End;
End;

Procedure TermMenu(W: PWindow; Cmd: Integer);
Var T: PTerm; P: String; I,N: Integer; S: String; F: Text;
Begin
 T:=W^.Data;
 Case Cmd Of
  CM_T_NEW: Begin For I:=0 To TROWS-1 Do T^.Scr[I]:='';T^.CR:=0;T^.CC:=0;T^.FileName:='';End;
  CM_T_OPEN: Begin P:='';If FileDialog(0,T3('Open File Name:','Ouvrir :','Datei '#148'ffnen:'),'*.TRM',P) Then Begin
     N:=0;
     {$I-}
     Assign(F,V2R(P));Reset(F);
     If IOResult=0 Then Begin
      For I:=0 To TROWS-1 Do T^.Scr[I]:='';
      While Not Eof(F) And (N<TROWS) Do Begin ReadLn(F,S);T^.Scr[N]:=Copy(S,1,TCOLS);Inc(N);End;
      Close(F);
     End;
     {$I+}
     T^.CR:=Min2(N,TROWS-1);T^.CC:=0;T^.FileName:=P;
    End;End;
  CM_T_SAVE,CM_T_SAVEAS: Begin
    P:=T^.FileName;
    If (Cmd=CM_T_SAVEAS) Or (P='') Then If Not FileDialog(1,T3('Save File Name As:','Enregistrer sous :','Speichern unter:'),'*.TRM',P) Then Exit;
    {$I-}
    Assign(F,V2R(P));Rewrite(F);
    If IOResult=0 Then Begin
     N:=0;For I:=0 To TROWS-1 Do If T^.Scr[I]<>'' Then N:=I;
     For I:=0 To N Do WriteLn(F,T^.Scr[I]);
     Close(F);T^.FileName:=P;
    End;
    {$I+}
   End;
  CM_T_PRINT: SpoolAdd('Terminal - '+IfThenS(T^.FileName='',T3('(untitled)','(sans titre)','(unbenannt)'),BaseName(T^.FileName)));
  CM_T_EXIT: CloseWindow(W);
  CM_T_ABOUT: ShowAboutMs('Terminal',4,False);
  CM_T_COPY: Begin
    S:='';
    For I:=0 To TROWS-1 Do If T^.Scr[I]<>'' Then S:=S+T^.Scr[I]+#13;
    If Length(S)>0 Then ClipSetText(S[1],Length(S));
   End;
  CM_T_PASTE: If ClipKind=1 Then Begin
    For I:=0 To Min2(ClipLen,250)-1 Do Begin
     If T^.Connected Then T^.Pend:=T^.Pend+ClipTxt[I] Else TermPut(T,ClipTxt[I]);
    End;
   End;
  CM_T_CLEAR: Begin For I:=0 To TROWS-1 Do T^.Scr[I]:='';T^.CR:=0;T^.CC:=0;End;
  CM_T_CONNECT: Begin
    If T^.Phone='' Then TermPhone(W);
    If (T^.Phone<>'') And Not T^.Connected Then Begin
     TermStr(T,'ATD'+IfThenS(T^.Tone,'T','P')+T^.Phone+#13#10);
     T^.Dialing:=True;T^.T0:=NowCs;
    End;
   End;
  CM_T_DISC: TermDisc(T);
  CM_T_CAPTURE: T^.Capture:=Not T^.Capture;
  CM_T_PAUSE: T^.Pause:=Not T^.Pause;
  CM_T_BREAK: If T^.Connected Then T^.Pend:=T^.Pend+'^C'#13#10'> ';
  CM_T_SETTERM: TermSettings(W);
  CM_T_SETCOMM: CpComm;
  CM_T_SETPHONE: TermPhone(W);
 End;
 Dirty:=True;
End;

Procedure TermPrepare(W: PWindow);
Var T: PTerm;
Begin
 T:=W^.Data;
 MenuDisable(W,CM_T_CONNECT,T^.Connected Or T^.Dialing);
 MenuDisable(W,CM_T_DISC,Not (T^.Connected Or T^.Dialing));
 MenuCheck(W,CM_T_CAPTURE,T^.Capture);MenuCheck(W,CM_T_PAUSE,T^.Pause);
End;

Function TermCreate: PWindow;
Var W: PWindow; T: PTerm;
Begin
 W:=NewWindow(A_TERM,'Terminal - (Untitled)',-1,-1,540,320,True);
 If W=Nil Then Begin TermCreate:=Nil;Exit;End;
 New(T);FillChar(T^,SizeOf(TTerm),0);
 T^.Wrap:=True;T^.TType:=2;T^.Tone:=True;T^.Phone:='';
 W^.Data:=T;W^.HasVS:=True;
 WinAddMenu(W,'&File~&Fichier~&Datei');
 WinAddItem(W,'&New~&Nouveau~&Neu',CM_T_NEW,'');
 WinAddItem(W,'&Open...~&Ouvrir...~'#142'&ffnen...',CM_T_OPEN,'');
 WinAddItem(W,'&Save~&Enregistrer~&Speichern',CM_T_SAVE,'');
 WinAddItem(W,'Save &As...~Enregistrer &sous...~Speichern &unter...',CM_T_SAVEAS,'');
 WinAddItem(W,'&Print~&Imprimer~&Drucken',CM_T_PRINT,'');
 WinAddItem(W,'E&xit~&Quitter~&Beenden',CM_T_EXIT,'');
 WinAddItem(W,'A&bout Terminal...~&'#133' propos de Terminal...~'#154'&ber Terminal...',CM_T_ABOUT,'');
 WinAddMenu(W,'&Edit~&'#144'dition~&Bearbeiten');
 WinAddItem(W,'&Copy~&Copier~&Kopieren',CM_T_COPY,'Ctrl+Ins');
 WinAddItem(W,'&Paste~Co&ller~&Einf'#129'gen',CM_T_PASTE,'Shift+Ins');
 WinAddItem(W,'C&lear~E&facer~&L'#148'schen',CM_T_CLEAR,'');
 WinAddMenu(W,'&Session~&Session~&Sitzung');
 WinAddItem(W,'&Connect~&Connecter~&Verbinden',CM_T_CONNECT,'Ctrl+F3');
 WinAddItem(W,'&Disconnect~&D'#130'connecter~&Trennen',CM_T_DISC,'');
 WinAddItem(W,'Ca&pture~&Capturer~&Aufzeichnen',CM_T_CAPTURE,'Ctrl+F5');
 WinAddItem(W,'P&ause~&Pause~&Pause',CM_T_PAUSE,'Ctrl+F6');
 WinAddItem(W,'&Break~&Interrompre~&Unterbrechen',CM_T_BREAK,'Ctrl+F7');
 WinAddMenu(W,'C&onfigure~C&onfigurer~&Konfigurieren');
 WinAddItem(W,'&Terminal...~&Terminal...~&Terminal...',CM_T_SETTERM,'');
 WinAddItem(W,'&Communications...~&Communications...~&Kommunikation...',CM_T_SETCOMM,'');
 WinAddItem(W,'&Phone...~&T'#130'l'#130'phone...~T&elefon...',CM_T_SETPHONE,'');
 TermStr(T,'Microsoft Windows Terminal 2.03'#13#10);
 TermCreate:=W;
End;

{ ====================================================================== }
{                              CARDFILE                                  }
{ ====================================================================== }

Const
 CM_D_NEW=701; CM_D_OPEN=702; CM_D_SAVE=703; CM_D_SAVEAS=704; CM_D_PRINT=705;
 CM_D_PRINTALL=706; CM_D_EXIT=707; CM_D_ABOUT=708;
 CM_D_UNDO=711; CM_D_CUT=712; CM_D_COPY=713; CM_D_PASTE=714; CM_D_INDEX=715;
 CM_D_CARD=721; CM_D_LIST=722;
 CM_D_ADD=731; CM_D_DEL=732; CM_D_DUP=733; CM_D_AUTODIAL=734;
 CM_D_GOTO=741; CM_D_FIND=742; CM_D_FINDNEXT=743;
 MAXCARD = 300;

Type
 TCard = Record
  Idx : String[40];
  Txt : String[255];
 End;
 PCardArr = ^TCardArr;
 TCardArr = Array[1..MAXCARD] Of TCard;
 PCardF = ^TCardF;
 TCardF = Record
  C : PCardArr;
  N,Cur : Integer;
  ListView : Boolean;
  Ed : PEd;
  FileName : String[80];
  Modified : Boolean;
  FindStr  : String[40];
 End;

Procedure CardLoadEd(F: PCardF);
Var I: Integer; S: String;
Begin
 EdClear(F^.Ed);
 If (F^.Cur>=1) And (F^.Cur<=F^.N) Then Begin
  S:=F^.C^[F^.Cur].Txt;
  For I:=1 To Length(S) Do EdInsertChar(F^.Ed,Ord(S[I]));
 End;
 F^.Ed^.Cur:=0;F^.Ed^.Modified:=False;F^.Ed^.HasUndo:=False;
 EdLayout(F^.Ed);
End;

Procedure CardSync(F: PCardF);
Var I: Integer; S: String;
Begin
 If (F^.Cur<1) Or (F^.Cur>F^.N) Then Exit;
 S:='';
 For I:=0 To F^.Ed^.Len-1 Do If Length(S)<255 Then S:=S+Chr(F^.Ed^.Buf^[I]);
 If S<>F^.C^[F^.Cur].Txt Then Begin F^.C^[F^.Cur].Txt:=S;F^.Modified:=True;End;
End;

Procedure CardGoto(F: PCardF; N: Integer);
Begin
 If (N<1) Or (N>F^.N) Then Exit;
 CardSync(F);
 F^.Cur:=N;
 CardLoadEd(F);
End;

Function CardInsert(F: PCardF; Const Idx,Txt: String): Integer;
Var I,P: Integer;
Begin
 CardInsert:=0;
 If F^.N>=MAXCARD Then Exit;
 P:=1;
 While (P<=F^.N) And (Upper(F^.C^[P].Idx)<=Upper(Idx)) Do Inc(P);
 For I:=F^.N DownTo P Do F^.C^[I+1]:=F^.C^[I];
 F^.C^[P].Idx:=Idx;F^.C^[P].Txt:=Txt;
 Inc(F^.N);F^.Modified:=True;
 CardInsert:=P;
End;

Procedure CardNew(F: PCardF);
Begin
 F^.N:=0;F^.Cur:=0;
 CardInsert(F,'','');F^.Cur:=1;
 CardLoadEd(F);
 F^.FileName:='';F^.Modified:=False;
End;

Procedure CardTitle(W: PWindow);
Var F: PCardF;
Begin
 F:=W^.Data;
 W^.Title:='Cardfile - '+IfThenS(F^.FileName='',T3('(Untitled)','(Sans titre)','(Unbenannt)'),BaseName(F^.FileName));
End;

Function CardSave(F: PCardF; Const P: String): Boolean;
Var T: Text; I,K: Integer; S: String;
Begin
 CardSync(F);
 CardSave:=False;
 {$I-}
 Assign(T,V2R(P));Rewrite(T);
 If IOResult<>0 Then Exit;
 WriteLn(T,'WIN2CARDFILE');
 For I:=1 To F^.N Do Begin
  S:=F^.C^[I].Txt;
  For K:=1 To Length(S) Do If S[K]=#13 Then S[K]:=#2;
  WriteLn(T,F^.C^[I].Idx+#1+S);
 End;
 Close(T);
 {$I+}
 If IOResult=0 Then Begin F^.FileName:=P;F^.Modified:=False;CardSave:=True;End;
End;

Function CardLoad(F: PCardF; Const P: String): Boolean;
Var T: Text; L: String; K,Q: Integer;
Begin
 CardLoad:=False;
 {$I-}
 Assign(T,V2R(P));Reset(T);
 If IOResult<>0 Then Exit;
 ReadLn(T,L);
 If L<>'WIN2CARDFILE' Then Begin Close(T);Exit;End;
 F^.N:=0;
 While (Not Eof(T)) And (F^.N<MAXCARD) Do Begin
  ReadLn(T,L);
  Q:=Pos(#1,L);
  If Q=0 Then Continue;
  Inc(F^.N);
  F^.C^[F^.N].Idx:=Copy(L,1,Q-1);
  F^.C^[F^.N].Txt:=Copy(L,Q+1,255);
  For K:=1 To Length(F^.C^[F^.N].Txt) Do If F^.C^[F^.N].Txt[K]=#2 Then F^.C^[F^.N].Txt[K]:=#13;
 End;
 Close(T);
 {$I+}
 If F^.N=0 Then CardNew(F) Else Begin F^.Cur:=1;CardLoadEd(F);End;
 F^.FileName:=P;F^.Modified:=False;
 CardLoad:=True;
End;

Procedure CardGeom(W: PWindow; Var CX,CY,CW,CH,K: Integer);
Var F: PCardF; X1,Y1,X2,Y2: Integer;
Begin
 F:=W^.Data;
 WinClient(W,X1,Y1,X2,Y2);
 K:=Min2(F^.Cur,Max2(1,(Y2-Y1-90) Div 14));
 If K>7 Then K:=7;
 CW:=Min2(X2-X1-24,330);
 CH:=Y2-Y1-16-(K-1)*14;
 If CH<70 Then CH:=70;
 CX:=X1+8;CY:=Y1+8;
End;

Procedure CardDraw(W: PWindow);
Var F: PCardF; X1,Y1,X2,Y2,CX,CY,CW,CH,K,I,Y,First,L: Integer; S: String;
Begin
 F:=W^.Data;
 WinClient(W,X1,Y1,X2,Y2);
 If F^.ListView Then Begin
  For I:=1 To F^.N Do Begin
   Y:=Y1+4+(I-1)*12-W^.VPos*12;
   If (Y<Y1) Or (Y>Y2-8) Then Continue;
   S:=F^.C^[I].Idx;If S='' Then S:=T3('(no index)','(sans index)','(kein Index)');
   If I=F^.Cur Then Begin GBar(X1+4,Y-1,X1+8+Length(S)*8,Y+9,cBlk);GText(X1+6,Y,S,cWht);End
   Else GText(X1+6,Y,S,cBlk);
  End;
  W^.HasVS:=True;W^.VTot:=F^.N;W^.VPage:=Max2(1,(Y2-Y1) Div 12);
  Exit;
 End;
 W^.HasVS:=False;
 CardGeom(W,CX,CY,CW,CH,K);
 First:=F^.Cur-K+1;
 For I:=0 To K-1 Do Begin
  Y:=CY+I*14;
  GBar(CX,Y,CX+CW-1,CY+(K-1)*14+CH-1,cWht);
  GRect(CX,Y,CX+CW-1,CY+(K-1)*14+CH-1,cBlk);
  GHLine(CX,CX+CW-1,Y+13,cBlk);
  S:=F^.C^[First+I].Idx;
  GText(CX+6,Y+3,S,cBlk);
 End;
 { carte de devant : zone de texte }
 F^.Ed^.X0:=CX+2;F^.Ed^.Y0:=CY+(K-1)*14+16;F^.Ed^.PW:=CW-4;F^.Ed^.PH:=CH-20;
 F^.Ed^.Cols:=(F^.Ed^.PW-8) Div 8;F^.Ed^.Rows:=Max2(1,F^.Ed^.PH Div 12);
 EdLayout(F^.Ed);
 SetClip(F^.Ed^.X0,F^.Ed^.Y0,F^.Ed^.X0+F^.Ed^.PW-1,F^.Ed^.Y0+F^.Ed^.PH-1);
 EdDraw(F^.Ed,0,W=ActiveWin);
 WinClient(W,X1,Y1,X2,Y2);
 SetClip(X1,Y1,X2,Y2);
End;

Procedure CardMouse(W: PWindow; Var E: TEvent);
Var F: PCardF; CX,CY,CW,CH,K,I,Y,N,X1,Y1,X2,Y2,A,B: Integer; S: String;
Begin
 F:=W^.Data;
 If E.Kind=EV_MOVE Then Begin
  If (Capture=W) And Not F^.ListView Then Begin
   N:=EdHit(F^.Ed,0,E.X,E.Y);
   If N<>F^.Ed^.Cur Then Begin
    If F^.Ed^.Anc<0 Then F^.Ed^.Anc:=W^.Param-1;
    F^.Ed^.Cur:=N;Invalidate(W);
   End;
  End;
  Exit;
 End;
 If E.Kind<>EV_DOWN Then Exit;
 WinClient(W,X1,Y1,X2,Y2);
 If F^.ListView Then Begin
  I:=(E.Y-Y1-4) Div 12+1+W^.VPos;
  If (I>=1) And (I<=F^.N) Then Begin
   CardGoto(F,I);
   If E.Dbl Then F^.ListView:=False;
   Dirty:=True;
  End;
  Exit;
 End;
 CardGeom(W,CX,CY,CW,CH,K);
 For I:=0 To K-1 Do Begin
  Y:=CY+I*14;
  If (E.Y>=Y) And (E.Y<Y+14) And (E.X>=CX) And (E.X<CX+CW) Then Begin
   If I=K-1 Then Begin
    If E.Dbl Then AppMenu(W,CM_D_INDEX);
   End Else Begin CardGoto(F,F^.Cur-K+1+I);Dirty:=True;End;
   Exit;
  End;
 End;
 N:=EdHit(F^.Ed,0,E.X,E.Y);
 If E.Dbl Then Begin EdWordAt(F^.Ed,N,A,B);F^.Ed^.Anc:=A;F^.Ed^.Cur:=B;End
 Else Begin F^.Ed^.Cur:=N;F^.Ed^.Anc:=-1;W^.Param:=N+1;Capture:=W;End;
 Invalidate(W);
End;

Procedure CardKey(W: PWindow; K: Word);
Var F: PCardF;
Begin
 F:=W^.Data;
 Case K Of
  K_F7: Begin AppMenu(W,CM_D_ADD);Exit;End;
  K_F6: Begin AppMenu(W,CM_D_INDEX);Exit;End;
  K_F4: Begin AppMenu(W,CM_D_GOTO);Exit;End;
  K_F3: Begin AppMenu(W,CM_D_FINDNEXT);Exit;End;
  K_F5: Begin AppMenu(W,CM_D_AUTODIAL);Exit;End;
  K_PGUP: Begin CardGoto(F,F^.Cur-1);Dirty:=True;Exit;End;
  K_PGDN: Begin CardGoto(F,F^.Cur+1);Dirty:=True;Exit;End;
  K_ALTBS: Begin EdUndo(F^.Ed);Dirty:=True;Exit;End;
  3: Begin EdCopy(F^.Ed);Exit;End;
  24: Begin EdCut(F^.Ed);Dirty:=True;Exit;End;
  22: Begin EdPaste(F^.Ed);Dirty:=True;Exit;End;
 End;
 If F^.ListView Then Begin
  If K=K_UP Then CardGoto(F,F^.Cur-1) Else If K=K_DOWN Then CardGoto(F,F^.Cur+1)
  Else If K=K_ENTER Then F^.ListView:=False;
  Dirty:=True;Exit;
 End;
 F^.Ed^.Max:=255;
 If (K<>K_ESC) Then EdKey(F^.Ed,K);
 CardSync(F);
 Invalidate(W);
End;

Procedure CardDoAdd(W: PWindow);
Var F: PCardF; S: String; P: Integer;
Begin
 F:=W^.Data;
 S:='';
 If InputBox(T3('Add (index line):','Ajouter (ligne d''index) :','Hinzuf'#129'gen (Indexzeile):'),S,40,360) Then Begin
  CardSync(F);
  P:=CardInsert(F,S,'');
  If P>0 Then Begin F^.Cur:=P;CardLoadEd(F);End;
 End;
End;

Procedure CardMenu(W: PWindow; Cmd: Integer);
Var F: PCardF; S,P: String; I,N,Pg: Integer; Fnd: Boolean;
Begin
 F:=W^.Data;
 Case Cmd Of
  CM_D_NEW: If (Not F^.Modified) Or (MsgBox(T3('Discard current cards?','Abandonner les fiches actuelles ?','Aktuelle Karten verwerfen?'),1,2)=ID_OK) Then Begin CardNew(F);CardTitle(W);End;
  CM_D_OPEN: Begin P:='';If FileDialog(0,T3('Open File Name:','Ouvrir :','Datei '#148'ffnen:'),'*.CRD',P) Then Begin
     If CardLoad(F,P) Then CardTitle(W) Else InfoBox(T3('Invalid Cardfile.','Fichier Cardfile invalide.','Ung'#129'ltige Cardfile.'));End;End;
  CM_D_SAVE,CM_D_SAVEAS: Begin
    P:=F^.FileName;
    If (Cmd=CM_D_SAVEAS) Or (P='') Then If Not FileDialog(1,T3('Save File Name As:','Enregistrer sous :','Speichern unter:'),'*.CRD',P) Then Exit;
    If CardSave(F,P) Then CardTitle(W) Else InfoBox(T3('Cannot save the file.','Impossible d''enregistrer.','Speichern nicht m'#148'glich.'));
   End;
  CM_D_PRINT,CM_D_PRINTALL: SpoolAdd('Cardfile - '+T3('(untitled)','(sans titre)','(unbenannt)'));
  CM_D_EXIT: CloseWindow(W);
  CM_D_ABOUT: ShowAboutMs('Cardfile',4,False);
  CM_D_UNDO: EdUndo(F^.Ed);
  CM_D_CUT: EdCut(F^.Ed);
  CM_D_COPY: EdCopy(F^.Ed);
  CM_D_PASTE: EdPaste(F^.Ed);
  CM_D_INDEX: Begin
    S:=F^.C^[F^.Cur].Idx;
    If InputBox(T3('Index line:','Ligne d''index :','Indexzeile:'),S,40,360) Then Begin
     CardSync(F);
     S:=S;
     { reinsere la carte pour conserver l'ordre alphabetique }
     P:=F^.C^[F^.Cur].Txt;
     For I:=F^.Cur To F^.N-1 Do F^.C^[I]:=F^.C^[I+1];
     Dec(F^.N);
     F^.Cur:=CardInsert(F,S,P);
     CardLoadEd(F);
    End;
   End;
  CM_D_CARD: F^.ListView:=False;
  CM_D_LIST: F^.ListView:=True;
  CM_D_ADD: CardDoAdd(W);
  CM_D_DEL: If F^.N>0 Then Begin
    If MsgBox(T3('Delete "'+F^.C^[F^.Cur].Idx+'"?','Supprimer "'+F^.C^[F^.Cur].Idx+'" ?','"'+F^.C^[F^.Cur].Idx+'" l'#148'schen?'),1,2)=ID_OK Then Begin
     For I:=F^.Cur To F^.N-1 Do F^.C^[I]:=F^.C^[I+1];
     Dec(F^.N);F^.Modified:=True;
     If F^.N=0 Then CardInsert(F,'','');
     If F^.Cur>F^.N Then F^.Cur:=F^.N;
     CardLoadEd(F);
    End;
   End;
  CM_D_DUP: Begin
    CardSync(F);
    I:=CardInsert(F,F^.C^[F^.Cur].Idx,F^.C^[F^.Cur].Txt);
    If I>0 Then Begin F^.Cur:=I;CardLoadEd(F);End;
   End;
  CM_D_AUTODIAL: Begin
    S:='';
    For I:=1 To Length(F^.C^[F^.Cur].Txt) Do If F^.C^[F^.Cur].Txt[I] In ['0'..'9','-','(',')',' '] Then S:=S+F^.C^[F^.Cur].Txt[I];
    S:=Trim(S);
    If S='' Then S:=Trim(F^.C^[F^.Cur].Idx);
    If InputBox(T3('Number to dial:','Num'#130'ro '#133' composer :','Zu w'#132'hlende Nummer:'),S,30,320) Then
     InfoBox(T3('No modem answered.|Dialed: ','Aucun modem n''a r'#130'pondu.|Num'#130'ro : ','Kein Modem antwortet.|Nummer: ')+S);
   End;
  CM_D_GOTO: Begin S:='';If InputBox(T3('Go to:','Aller '#133' :','Gehe zu:'),S,40,300) Then Begin
     Fnd:=False;
     For I:=1 To F^.N Do If (Not Fnd) And (Copy(Upper(F^.C^[I].Idx),1,Length(S))=Upper(S)) Then Begin Fnd:=True;CardGoto(F,I);End;
     If Not Fnd Then InfoBox(T3('Card not found.','Fiche introuvable.','Karte nicht gefunden.'));
    End;End;
  CM_D_FIND: Begin S:=F^.FindStr;If InputBox(T3('Find What:','Rechercher :','Suchen nach:'),S,40,300) Then Begin F^.FindStr:=S;CardMenu(W,CM_D_FINDNEXT);End;End;
  CM_D_FINDNEXT: Begin
    If F^.FindStr='' Then Begin CardMenu(W,CM_D_FIND);Exit;End;
    Fnd:=False;CardSync(F);
    For N:=1 To F^.N Do Begin
     I:=((F^.Cur-1+N) Mod F^.N)+1;
     If (Pos(Upper(F^.FindStr),Upper(F^.C^[I].Idx))>0) Or (Pos(Upper(F^.FindStr),Upper(F^.C^[I].Txt))>0) Then Begin
      CardGoto(F,I);Fnd:=True;Break;End;
    End;
    If Not Fnd Then InfoBox(T3('Cannot find "','Impossible de trouver "','Kann nicht finden: "')+F^.FindStr+'"');
   End;
 End;
 Dirty:=True;
End;

Procedure CardPrepare(W: PWindow);
Var F: PCardF;
Begin
 F:=W^.Data;
 MenuCheck(W,CM_D_CARD,Not F^.ListView);MenuCheck(W,CM_D_LIST,F^.ListView);
 MenuDisable(W,CM_D_UNDO,Not F^.Ed^.HasUndo);
 MenuDisable(W,CM_D_CUT,Not EdHasSel(F^.Ed));MenuDisable(W,CM_D_COPY,Not EdHasSel(F^.Ed));
 MenuDisable(W,CM_D_PASTE,ClipKind<>1);
End;

Procedure CardClose(W: PWindow);
Var F: PCardF;
Begin
 F:=W^.Data;
 EdFree(F^.Ed);Dispose(F^.C);Dispose(F);
End;

Function CardCreate(Const Path: String): PWindow;
Var W: PWindow; F: PCardF;
Begin
 W:=NewWindow(A_CARD,'Cardfile',-1,-1,420,300,True);
 If W=Nil Then Begin CardCreate:=Nil;Exit;End;
 New(F);FillChar(F^,SizeOf(TCardF),0);New(F^.C);
 F^.Ed:=EdNew(False);F^.Ed^.Max:=255;
 W^.Data:=F;
 CardNew(F);
 WinAddMenu(W,'&File~&Fichier~&Datei');
 WinAddItem(W,'&New~&Nouveau~&Neu',CM_D_NEW,'');
 WinAddItem(W,'&Open...~&Ouvrir...~'#142'&ffnen...',CM_D_OPEN,'');
 WinAddItem(W,'&Save~&Enregistrer~&Speichern',CM_D_SAVE,'');
 WinAddItem(W,'Save &As...~Enregistrer &sous...~Speichern &unter...',CM_D_SAVEAS,'');
 WinAddItem(W,'&Print~&Imprimer~&Drucken',CM_D_PRINT,'');
 WinAddItem(W,'Print A&ll~Imprimer &tout~&Alles drucken',CM_D_PRINTALL,'');
 WinAddItem(W,'E&xit~&Quitter~&Beenden',CM_D_EXIT,'');
 WinAddItem(W,'A&bout Cardfile...~&'#133' propos de Cardfile...~'#154'&ber Cardfile...',CM_D_ABOUT,'');
 WinAddMenu(W,'&Edit~&'#144'dition~&Bearbeiten');
 WinAddItem(W,'&Undo~&Annuler~&R'#129'ckg'#132'ngig',CM_D_UNDO,'Alt+BkSp');
 WinAddSep(W);
 WinAddItem(W,'Cu&t~Co&uper~&Ausschneiden',CM_D_CUT,'Ctrl+X');
 WinAddItem(W,'&Copy~&Copier~&Kopieren',CM_D_COPY,'Ctrl+Ins');
 WinAddItem(W,'&Paste~Co&ller~&Einf'#129'gen',CM_D_PASTE,'Ctrl+V');
 WinAddSep(W);
 WinAddItem(W,'&Index...~&Index...~&Index...',CM_D_INDEX,'F6');
 WinAddMenu(W,'&View~&Affichage~&Ansicht');
 WinAddItem(W,'&Card~&Fiche~&Karte',CM_D_CARD,'');
 WinAddItem(W,'&List~&Liste~&Liste',CM_D_LIST,'');
 WinAddMenu(W,'&Card~&Fiche~&Karte');
 WinAddItem(W,'&Add...~&Ajouter...~&Hinzuf'#129'gen...',CM_D_ADD,'F7');
 WinAddItem(W,'&Delete~&Supprimer~&L'#148'schen',CM_D_DEL,'');
 WinAddItem(W,'D&uplicate~D&upliquer~&Duplizieren',CM_D_DUP,'');
 WinAddItem(W,'Auto&dial...~&Composer...~Auto&w'#132'hlen...',CM_D_AUTODIAL,'F5');
 WinAddMenu(W,'&Search~&Recherche~&Suchen');
 WinAddItem(W,'&Go To...~&Atteindre...~&Gehe zu...',CM_D_GOTO,'F4');
 WinAddItem(W,'&Find...~&Rechercher...~&Suchen...',CM_D_FIND,'');
 WinAddItem(W,'Find &Next~&Suivant~&Weitersuchen',CM_D_FINDNEXT,'F3');
 CardTitle(W);
 If Path<>'' Then If CardLoad(F,Path) Then CardTitle(W);
 CardCreate:=W;
End;

{ ====================================================================== }
{                              CALENDAR                                  }
{ ====================================================================== }

Const
 CM_L_NEW=801; CM_L_OPEN=802; CM_L_SAVE=803; CM_L_SAVEAS=804; CM_L_PRINT=805;
 CM_L_REMOVE=806; CM_L_EXIT=807; CM_L_ABOUT=808;
 CM_L_CUT=811; CM_L_COPY=812; CM_L_PASTE=813;
 CM_L_DAY=821; CM_L_MONTH=822;
 CM_L_PREV=831; CM_L_NEXT=832; CM_L_TODAY=833; CM_L_DATE=834;
 CM_L_ALARM=841; CM_L_CONTROLS=842;
 CM_L_MARK=851; CM_L_SPECIAL=852; CM_L_DAYSET=853;
 MAXAP = 500; MAXMK = 200;

Type
 TAppt = Record
  Y,M,D : Integer;
  T     : Integer;        { minutes depuis minuit }
  Txt   : String[40];
  Alarm,Special,Fired : Boolean;
 End;
 TMark = Record Y,M,D,Sym: Integer; End;
 PCal = ^TCal;
 TCal = Record
  A  : Array[1..MAXAP] Of TAppt;
  NA : Integer;
  Mk : Array[1..MAXMK] Of TMark;
  NM : Integer;
  Y,M,D : Integer;
  Month : Boolean;
  Interval,DayStart : Integer;
  H24   : Boolean;
  Sel   : Integer;           { ligne selectionnee en vue jour (minutes) }
  AlarmEarly: Integer;
  AlarmSound: Boolean;
  FileName: String[80];
  Modified: Boolean;
  LastChk : LongInt;
  CopyBuf : String[40];
  Rows    : Integer;
  RowT    : Array[0..99] Of Integer;
 End;

Function CalFind(C: PCal; Y,M,D,T: Integer): Integer;
Var I: Integer;
Begin
 CalFind:=0;
 For I:=1 To C^.NA Do
  If (C^.A[I].Y=Y) And (C^.A[I].M=M) And (C^.A[I].D=D) And (C^.A[I].T=T) Then Begin CalFind:=I;Exit;End;
End;

Procedure CalSetText(C: PCal; Y,M,D,T: Integer; Const S: String; Special: Boolean);
Var I,K: Integer;
Begin
 I:=CalFind(C,Y,M,D,T);
 If (S='') And Not Special Then Begin
  If I>0 Then Begin For K:=I To C^.NA-1 Do C^.A[K]:=C^.A[K+1];Dec(C^.NA);C^.Modified:=True;End;
  Exit;
 End;
 If I=0 Then Begin
  If C^.NA>=MAXAP Then Exit;
  Inc(C^.NA);I:=C^.NA;
  C^.A[I].Y:=Y;C^.A[I].M:=M;C^.A[I].D:=D;C^.A[I].T:=T;C^.A[I].Alarm:=False;C^.A[I].Fired:=False;
  C^.A[I].Special:=Special;
 End;
 C^.A[I].Txt:=S;C^.Modified:=True;
End;

Function CalTimeStr(C: PCal; T: Integer): String;
Begin
 If C^.H24 Then CalTimeStr:=Pad2(T Div 60)+':'+Pad2(T Mod 60)
 Else Begin
  If T Div 60=0 Then CalTimeStr:='12:'+Pad2(T Mod 60)+' AM'
  Else If T Div 60<12 Then CalTimeStr:=IntStr(T Div 60)+':'+Pad2(T Mod 60)+' AM'
  Else If T Div 60=12 Then CalTimeStr:='12:'+Pad2(T Mod 60)+' PM'
  Else CalTimeStr:=IntStr(T Div 60-12)+':'+Pad2(T Mod 60)+' PM';
 End;
End;

{ lignes de la vue jour : creneaux reguliers + heures speciales }
Procedure CalRows(C: PCal);
Var T,I,K,J,V: Integer; Has: Boolean;
Begin
 C^.Rows:=0;
 T:=C^.DayStart;
 While (T<24*60) And (C^.Rows<90) Do Begin C^.RowT[C^.Rows]:=T;Inc(C^.Rows);Inc(T,C^.Interval);End;
 For I:=1 To C^.NA Do
  If (C^.A[I].Y=C^.Y) And (C^.A[I].M=C^.M) And (C^.A[I].D=C^.D) Then Begin
   Has:=False;
   For K:=0 To C^.Rows-1 Do If C^.RowT[K]=C^.A[I].T Then Has:=True;
   If (Not Has) And (C^.Rows<99) Then Begin
    K:=C^.Rows;
    While (K>0) And (C^.RowT[K-1]>C^.A[I].T) Do Begin C^.RowT[K]:=C^.RowT[K-1];Dec(K);End;
    C^.RowT[K]:=C^.A[I].T;Inc(C^.Rows);
   End;
  End;
End;

Function CalMarkAt(C: PCal; Y,M,D: Integer): Integer;
Var I: Integer;
Begin
 CalMarkAt:=0;
 For I:=1 To C^.NM Do If (C^.Mk[I].Y=Y) And (C^.Mk[I].M=M) And (C^.Mk[I].D=D) Then CalMarkAt:=C^.Mk[I].Sym;
End;

Procedure CalNew(C: PCal);
Var Y,M,D: Integer;
Begin
 C^.NA:=0;C^.NM:=0;
 GetToday(Y,M,D);C^.Y:=Y;C^.M:=M;C^.D:=D;
 C^.Sel:=-1;C^.FileName:='';C^.Modified:=False;
End;

Procedure CalTitle(W: PWindow);
Var C: PCal;
Begin
 C:=W^.Data;
 W^.Title:='Calendar - '+IfThenS(C^.FileName='',T3('(Untitled)','(Sans titre)','(Unbenannt)'),BaseName(C^.FileName));
End;

Function CalSave(C: PCal; Const P: String): Boolean;
Var T: Text; I: Integer;
Begin
 CalSave:=False;
 {$I-}
 Assign(T,V2R(P));Rewrite(T);
 If IOResult<>0 Then Exit;
 WriteLn(T,'WIN2CAL');
 For I:=1 To C^.NA Do WriteLn(T,'A ',C^.A[I].Y,' ',C^.A[I].M,' ',C^.A[I].D,' ',C^.A[I].T,' ',
   Ord(C^.A[I].Alarm),' ',Ord(C^.A[I].Special),' ',C^.A[I].Txt);
 For I:=1 To C^.NM Do WriteLn(T,'M ',C^.Mk[I].Y,' ',C^.Mk[I].M,' ',C^.Mk[I].D,' ',C^.Mk[I].Sym);
 Close(T);
 {$I+}
 If IOResult=0 Then Begin C^.FileName:=P;C^.Modified:=False;CalSave:=True;End;
End;

Function CalLoad(C: PCal; Const P: String): Boolean;
Var T: Text; L: String; N: Array[1..6] Of Integer; K,Q,I: Integer;
Begin
 CalLoad:=False;
 {$I-}
 Assign(T,V2R(P));Reset(T);
 If IOResult<>0 Then Exit;
 ReadLn(T,L);
 If L<>'WIN2CAL' Then Begin Close(T);Exit;End;
 C^.NA:=0;C^.NM:=0;
 While Not Eof(T) Do Begin
  ReadLn(T,L);
  If (L='') Or ((L[1]<>'A') And (L[1]<>'M')) Then Continue;
  Delete(L,1,2);
  K:=0;
  For I:=1 To 6 Do Begin
   If (L[1]='M') Then Break;
   Q:=Pos(' ',L);If Q=0 Then Break;
   N[I]:=StrVal(Copy(L,1,Q-1),0);Delete(L,1,Q);
  End;
  If (C^.NA<MAXAP) Then Begin
   Inc(C^.NA);
   C^.A[C^.NA].Y:=N[1];C^.A[C^.NA].M:=N[2];C^.A[C^.NA].D:=N[3];C^.A[C^.NA].T:=N[4];
   C^.A[C^.NA].Alarm:=N[5]=1;C^.A[C^.NA].Special:=N[6]=1;C^.A[C^.NA].Txt:=L;C^.A[C^.NA].Fired:=False;
  End;
 End;
 Close(T);
 {$I+}
 CalLoad:=True;
 C^.FileName:=P;C^.Modified:=False;
End;

Procedure CalShift(C: PCal; Delta: Integer);
Var Dm: Integer;
Begin
 If C^.Month Then Begin
  Inc(C^.M,Delta);
  If C^.M>12 Then Begin C^.M:=1;Inc(C^.Y);End;
  If C^.M<1 Then Begin C^.M:=12;Dec(C^.Y);End;
  Dm:=DaysInMonth(C^.Y,C^.M);If C^.D>Dm Then C^.D:=Dm;
 End Else Begin
  Inc(C^.D,Delta);
  If C^.D>DaysInMonth(C^.Y,C^.M) Then Begin C^.D:=1;Inc(C^.M);If C^.M>12 Then Begin C^.M:=1;Inc(C^.Y);End;End;
  If C^.D<1 Then Begin Dec(C^.M);If C^.M<1 Then Begin C^.M:=12;Dec(C^.Y);End;C^.D:=DaysInMonth(C^.Y,C^.M);End;
 End;
 C^.Sel:=-1;
End;

Procedure CalDraw(W: PWindow);
Var C: PCal; X1,Y1,X2,Y2,I,R,Dd,Cw,Ch,Dw,Wk,X,Y,Ix,Sym: Integer; S: String; T: Integer;
Begin
 C:=W^.Data;
 WinClient(W,X1,Y1,X2,Y2);
 If C^.Month Then Begin
  W^.HasVS:=False;
  S:=MonthName(C^.M)+' '+IntStr(C^.Y);
  GTextCtr(X1,X2,Y1+6,S,cBlk);
  Cw:=(X2-X1-8) Div 7;Ch:=(Y2-Y1-50) Div 6;
  For I:=0 To 6 Do GText(X1+4+I*Cw+Cw Div 2-8,Y1+24,DayShort(I),cBlk);
  GHLine(X1,X2,Y1+36,cBlk);
  Dw:=DayOfWeek(C^.Y,C^.M,1);
  For Dd:=1 To DaysInMonth(C^.Y,C^.M) Do Begin
   Wk:=(Dd-1+Dw) Div 7;I:=(Dd-1+Dw) Mod 7;
   X:=X1+4+I*Cw;Y:=Y1+40+Wk*Ch;
   If Dd=C^.D Then Begin GBar(X+2,Y+1,X+Cw-2,Y+Ch-2,cBlk);GText(X+Cw Div 2-8,Y+Ch Div 2-4,Pad2(Dd),cWht);End
   Else GText(X+Cw Div 2-8,Y+Ch Div 2-4,Pad2(Dd),cBlk);
   Sym:=CalMarkAt(C,C^.Y,C^.M,Dd);
   If Sym>0 Then Begin
    Case Sym Of
     1: GEllipse(X+Cw Div 2,Y+Ch Div 2,12,8,IfThen_(Dd=C^.D,cWht,cBlk));
     2: GRect(X+Cw Div 2-12,Y+Ch Div 2-9,X+Cw Div 2+12,Y+Ch Div 2+9,IfThen_(Dd=C^.D,cWht,cBlk));
    Else GText(X+Cw Div 2+8,Y+2,'*',IfThen_(Dd=C^.D,cWht,cBlk));
    End;
   End;
  End;
 End Else Begin
  CalRows(C);
  W^.HasVS:=True;
  W^.VPage:=Max2(1,(Y2-Y1-24) Div 14);W^.VTot:=C^.Rows;
  If Lang=0 Then GText(X1+8,Y1+4,DayName(DayOfWeek(C^.Y,C^.M,C^.D))+', '+MonthName(C^.M)+' '+IntStr(C^.D)+', '+IntStr(C^.Y),cBlk)
  Else GText(X1+8,Y1+4,DayName(DayOfWeek(C^.Y,C^.M,C^.D))+' '+IntStr(C^.D)+IfThenS(Lang=2,'. ',' ')+MonthName(C^.M)+' '+IntStr(C^.Y),cBlk);
  GHLine(X1,X2,Y1+16,cBlk);
  For R:=0 To W^.VPage-1 Do Begin
   Ix:=W^.VPos+R;
   If Ix>=C^.Rows Then Break;
   T:=C^.RowT[Ix];
   Y:=Y1+20+R*14;
   S:=PadL(CalTimeStr(C,T),8);
   If T=C^.Sel Then GBar(X1+2,Y-1,X2-2,Y+11,cLCy);
   GText(X1+6,Y+2,S,cBlk);
   Dd:=CalFind(C,C^.Y,C^.M,C^.D,T);
   If Dd>0 Then Begin
    GText(X1+90,Y+2,C^.A[Dd].Txt,cBlk);
    If C^.A[Dd].Alarm Then GText(X1+74,Y+2,#14,cBlk);
   End;
   If T=C^.Sel Then GVLine(X1+90+Length(IfThenS(Dd>0,C^.A[Dd].Txt,''))*8,Y,Y+10,cBlk);
   If (T Mod 60=0) Then GHLine(X1+2,X2-2,Y+12,cDGr);
  End;
 End;
End;

Procedure CalMouse(W: PWindow; Var E: TEvent);
Var C: PCal; X1,Y1,X2,Y2,Cw,Ch,I,Wk,Dd,Dw,R: Integer;
Begin
 C:=W^.Data;
 If E.Kind<>EV_DOWN Then Exit;
 WinClient(W,X1,Y1,X2,Y2);
 If C^.Month Then Begin
  Cw:=(X2-X1-8) Div 7;Ch:=(Y2-Y1-50) Div 6;
  If (E.Y<Y1+40) Or (Cw<=0) Or (Ch<=0) Then Exit;
  I:=(E.X-X1-4) Div Cw;Wk:=(E.Y-Y1-40) Div Ch;
  Dw:=DayOfWeek(C^.Y,C^.M,1);
  Dd:=Wk*7+I-Dw+1;
  If (Dd>=1) And (Dd<=DaysInMonth(C^.Y,C^.M)) And (I>=0) And (I<7) Then Begin
   C^.D:=Dd;
   If E.Dbl Then C^.Month:=False;
   Dirty:=True;
  End;
 End Else Begin
  R:=(E.Y-Y1-20) Div 14+W^.VPos;
  If (R>=0) And (R<C^.Rows) And (E.Y>=Y1+20) Then Begin C^.Sel:=C^.RowT[R];Dirty:=True;End;
 End;
End;

Procedure CalKey(W: PWindow; K: Word);
Var C: PCal; I: Integer; S: String; Ix,R: Integer;
Begin
 C:=W^.Data;
 Case K Of
  K_F4: Begin AppMenu(W,CM_L_TODAY);Exit;End;
  K_F5: Begin AppMenu(W,CM_L_ALARM);Exit;End;
  K_F6: Begin AppMenu(W,CM_L_MARK);Exit;End;
  K_F7: Begin AppMenu(W,CM_L_SPECIAL);Exit;End;
  3: Begin AppMenu(W,CM_L_COPY);Exit;End;
  24: Begin AppMenu(W,CM_L_CUT);Exit;End;
  22: Begin AppMenu(W,CM_L_PASTE);Exit;End;
 End;
 If C^.Month Then Begin
  Case K Of
   K_LEFT: Dec(C^.D);
   K_RIGHT: Inc(C^.D);
   K_UP: Dec(C^.D,7);
   K_DOWN: Inc(C^.D,7);
   K_PGUP: CalShift(C,-1);
   K_PGDN: CalShift(C,1);
   K_ENTER: C^.Month:=False;
  End;
  If C^.D<1 Then C^.D:=1;
  If C^.D>DaysInMonth(C^.Y,C^.M) Then C^.D:=DaysInMonth(C^.Y,C^.M);
  Dirty:=True;Exit;
 End;
 CalRows(C);
 Ix:=-1;
 For R:=0 To C^.Rows-1 Do If C^.RowT[R]=C^.Sel Then Ix:=R;
 I:=CalFind(C,C^.Y,C^.M,C^.D,C^.Sel);
 If I>0 Then S:=C^.A[I].Txt Else S:='';
 If (K>=32) And (K<256) And (C^.Sel>=0) Then Begin
  If Length(S)<40 Then Begin S:=S+Chr(K);CalSetText(C,C^.Y,C^.M,C^.D,C^.Sel,S,False);End;
 End Else Case K Of
  K_BKSP: If (C^.Sel>=0) And (S<>'') Then Begin Delete(S,Length(S),1);CalSetText(C,C^.Y,C^.M,C^.D,C^.Sel,S,False);End;
  K_UP: If Ix>0 Then Begin C^.Sel:=C^.RowT[Ix-1];If Ix-1<W^.VPos Then W^.VPos:=Ix-1;End;
  K_DOWN,K_ENTER: Begin
    If Ix<0 Then C^.Sel:=C^.RowT[0] Else If Ix<C^.Rows-1 Then Begin C^.Sel:=C^.RowT[Ix+1];
     If Ix+1>=W^.VPos+W^.VPage Then Inc(W^.VPos);End;
   End;
  K_PGUP: If K=K_PGUP Then CalShift(C,-1);
  K_PGDN: CalShift(C,1);
  K_DEL: If C^.Sel>=0 Then CalSetText(C,C^.Y,C^.M,C^.D,C^.Sel,'',False);
 End;
 Dirty:=True;
End;

Procedure CalMarkDlg(C: PCal);
Var D: TDlg; R,I,K: Integer;
Begin
 DlgInit(D,'',260,130);
 DlgText(D,10,8,T3('Mark date with symbol:','Marquer la date :','Datum markieren mit:'));
 DlgRadio(D,10,20,30,1,T3('Circle','Cercle','Kreis'),True);
 DlgRadio(D,11,20,46,1,T3('Box','Cadre','Rahmen'),False);
 DlgRadio(D,12,20,62,1,T3('Asterisk','Ast'#130'risque','Stern'),False);
 DlgRadio(D,13,20,78,1,T3('None (clear)','Aucun (effacer)','Keines (l'#148'schen)'),False);
 DlgButton(D,ID_OK,20,100,90,'OK',True);
 DlgButton(D,ID_CANCEL,140,100,90,T3('Cancel','Annuler','Abbrechen'),False);
 R:=RunDialog(D,@NoHook);
 If R<>ID_OK Then Exit;
 K:=RadioGroupVal(D,1);
 For I:=C^.NM DownTo 1 Do
  If (C^.Mk[I].Y=C^.Y) And (C^.Mk[I].M=C^.M) And (C^.Mk[I].D=C^.D) Then Begin
   C^.Mk[I]:=C^.Mk[C^.NM];Dec(C^.NM);
  End;
 If (K<3) And (C^.NM<MAXMK) Then Begin
  Inc(C^.NM);C^.Mk[C^.NM].Y:=C^.Y;C^.Mk[C^.NM].M:=C^.M;C^.Mk[C^.NM].D:=C^.D;C^.Mk[C^.NM].Sym:=K+1;
 End;
 C^.Modified:=True;
End;

Procedure CalMenu(W: PWindow; Cmd: Integer);
Var C: PCal; P,S: String; D: TDlg; R,I,T,Y,M,Dd: Integer;
Begin
 C:=W^.Data;
 Case Cmd Of
  CM_L_NEW: Begin CalNew(C);CalTitle(W);End;
  CM_L_OPEN: Begin P:='';If FileDialog(0,T3('Open File Name:','Ouvrir :','Datei '#148'ffnen:'),'*.CAL',P) Then Begin
     If CalLoad(C,P) Then CalTitle(W) Else InfoBox(T3('Invalid calendar file.','Fichier calendrier invalide.','Ung'#129'ltige Kalenderdatei.'));End;End;
  CM_L_SAVE,CM_L_SAVEAS: Begin
    P:=C^.FileName;
    If (Cmd=CM_L_SAVEAS) Or (P='') Then If Not FileDialog(1,T3('Save File Name As:','Enregistrer sous :','Speichern unter:'),'*.CAL',P) Then Exit;
    If CalSave(C,P) Then CalTitle(W) Else InfoBox(T3('Cannot save the file.','Impossible d''enregistrer.','Speichern nicht m'#148'glich.'));
   End;
  CM_L_PRINT: SpoolAdd('Calendar - '+T3('(untitled)','(sans titre)','(unbenannt)'));
  CM_L_REMOVE: Begin
    S:=DateStr(C^.Y,C^.M,C^.D);
    If InputBox(T3('Remove appointments before:','Supprimer les rendez-vous avant :','Termine entfernen vor:'),S,10,330) Then Begin
     { suppression des rendez-vous anterieurs a la date courante }
     For I:=C^.NA DownTo 1 Do
      If (C^.A[I].Y*10000+C^.A[I].M*100+C^.A[I].D)<(C^.Y*10000+C^.M*100+C^.D) Then Begin C^.A[I]:=C^.A[C^.NA];Dec(C^.NA);End;
     C^.Modified:=True;
    End;
   End;
  CM_L_EXIT: CloseWindow(W);
  CM_L_ABOUT: ShowAboutMs('Calendar',4,False);
  CM_L_CUT,CM_L_COPY: Begin
    I:=CalFind(C,C^.Y,C^.M,C^.D,C^.Sel);
    If I>0 Then Begin S:=C^.A[I].Txt;If Length(S)>0 Then ClipSetText(S[1],Length(S));
     If Cmd=CM_L_CUT Then CalSetText(C,C^.Y,C^.M,C^.D,C^.Sel,'',False);End;
   End;
  CM_L_PASTE: If (ClipKind=1) And (C^.Sel>=0) Then Begin
    S:='';For I:=0 To Min2(ClipLen,40)-1 Do If ClipTxt[I]>=' ' Then S:=S+ClipTxt[I];
    CalSetText(C,C^.Y,C^.M,C^.D,C^.Sel,S,False);
   End;
  CM_L_DAY: C^.Month:=False;
  CM_L_MONTH: C^.Month:=True;
  CM_L_PREV: CalShift(C,-1);
  CM_L_NEXT: CalShift(C,1);
  CM_L_TODAY: Begin GetToday(Y,M,Dd);C^.Y:=Y;C^.M:=M;C^.D:=Dd;End;
  CM_L_DATE: Begin
    S:=DateStr(C^.Y,C^.M,C^.D);
    If InputBox(T3('Show date (month/day/year):','Afficher la date :','Datum anzeigen:'),S,10,330) Then Begin
     I:=0;Y:=0;M:=0;Dd:=0;
     R:=Pos(DateSep,S);
     If R>0 Then Begin
      Case DateFmt Of
       0: Begin M:=StrVal(Copy(S,1,R-1),0);Delete(S,1,R);R:=Pos(DateSep,S);Dd:=StrVal(Copy(S,1,R-1),0);Y:=StrVal(Copy(S,R+1,6),0);End;
       1: Begin Dd:=StrVal(Copy(S,1,R-1),0);Delete(S,1,R);R:=Pos(DateSep,S);M:=StrVal(Copy(S,1,R-1),0);Y:=StrVal(Copy(S,R+1,6),0);End;
      Else Begin Y:=StrVal(Copy(S,1,R-1),0);Delete(S,1,R);R:=Pos(DateSep,S);M:=StrVal(Copy(S,1,R-1),0);Dd:=StrVal(Copy(S,R+1,6),0);End;
      End;
      If (M>=1) And (M<=12) And (Y>=1) And (Dd>=1) And (Dd<=DaysInMonth(Y,M)) Then Begin C^.Y:=Y;C^.M:=M;C^.D:=Dd;End
      Else InfoBox(T3('Invalid date.','Date invalide.','Ung'#129'ltiges Datum.'));
     End;
    End;
   End;
  CM_L_ALARM: Begin
    I:=CalFind(C,C^.Y,C^.M,C^.D,C^.Sel);
    If I>0 Then Begin C^.A[I].Alarm:=Not C^.A[I].Alarm;C^.A[I].Fired:=False;C^.Modified:=True;End
    Else InfoBox(T3('Select a time with an appointment.','S'#130'lectionnez une heure avec un rendez-vous.','Zeit mit Termin w'#132'hlen.'));
   End;
  CM_L_CONTROLS: Begin
    DlgInit(D,'',280,110);
    DlgText(D,10,12,T3('&Early ring (minutes):','Sonnerie &anticip'#130'e (minutes) :','&Fr'#129'her klingeln (Min.):'));
    DlgEdit(D,10,200,8,60,IntStr(C^.AlarmEarly),2);
    DlgCheck(D,11,10,40,T3('&Sound','&Son','&Ton'),C^.AlarmSound);
    DlgButton(D,ID_OK,30,72,90,'OK',True);
    DlgButton(D,ID_CANCEL,150,72,90,T3('Cancel','Annuler','Abbrechen'),False);
    If RunDialog(D,@NoHook)=ID_OK Then Begin
     C^.AlarmEarly:=Clamp(StrVal(DlgGetText(D,10),0),0,60);C^.AlarmSound:=DlgGetVal(D,11)=1;End;
   End;
  CM_L_MARK: CalMarkDlg(C);
  CM_L_SPECIAL: Begin
    S:='12:00';
    If InputBox(T3('Special time (hh:mm):','Heure sp'#130'ciale (hh:mm) :','Sonderzeit (hh:mm):'),S,5,330) Then Begin
     R:=Pos(':',S);
     If R>0 Then Begin
      T:=Clamp(StrVal(Copy(S,1,R-1),0),0,23)*60+Clamp(StrVal(Copy(S,R+1,2),0),0,59);
      CalSetText(C,C^.Y,C^.M,C^.D,T,'',True);C^.Sel:=T;C^.Month:=False;
     End;
    End;
   End;
  CM_L_DAYSET: Begin
    DlgInit(D,'',300,140);
    DlgBox(D,8,4,130,66,T3('Interval','Intervalle','Intervall'));
    DlgRadio(D,10,18,22,1,'15',C^.Interval=15);DlgRadio(D,11,18,38,1,'30',C^.Interval=30);DlgRadio(D,12,18,54,1,'60',C^.Interval=60);
    DlgBox(D,150,4,140,50,T3('Hour Format','Format','Format'));
    DlgRadio(D,20,160,22,2,'12 h',Not C^.H24);DlgRadio(D,21,160,38,2,'24 h',C^.H24);
    DlgText(D,150,62,T3('&Day starts:','&D'#130'but :','&Beginn:'));DlgEdit(D,30,230,58,40,IntStr(C^.DayStart Div 60),2);
    DlgButton(D,ID_OK,50,100,90,'OK',True);
    DlgButton(D,ID_CANCEL,160,100,90,T3('Cancel','Annuler','Abbrechen'),False);
    If RunDialog(D,@NoHook)=ID_OK Then Begin
     Case RadioGroupVal(D,1) Of 0: C^.Interval:=15;1: C^.Interval:=30;Else C^.Interval:=60;End;
     C^.H24:=RadioGroupVal(D,2)=1;
     C^.DayStart:=Clamp(StrVal(DlgGetText(D,30),7),0,23)*60;
    End;
   End;
 End;
 Dirty:=True;
End;

Procedure CalTimer(W: PWindow);
Var C: PCal; I,Y,M,D,H,Mi,S,Nw: Integer; R: Integer;
Begin
 C:=W^.Data;
 If NowCs-C^.LastChk<500 Then Exit;
 C^.LastChk:=NowCs;
 GetToday(Y,M,D);GetNow(H,Mi,S);
 Nw:=H*60+Mi;
 For I:=1 To C^.NA Do
  If C^.A[I].Alarm And Not C^.A[I].Fired And (C^.A[I].Y=Y) And (C^.A[I].M=M) And (C^.A[I].D=D) And
     (Nw>=C^.A[I].T-C^.AlarmEarly) And (Nw<=C^.A[I].T+1) Then Begin
   C^.A[I].Fired:=True;
   If W^.State=1 Then RestoreWin(W);
   R:=MsgBox('Calendar ALARM|'+CalTimeStr(C,C^.A[I].T)+'  '+C^.A[I].Txt,0,1);
  End;
End;

Procedure CalPrepare(W: PWindow);
Var C: PCal; I: Integer;
Begin
 C:=W^.Data;
 MenuCheck(W,CM_L_DAY,Not C^.Month);MenuCheck(W,CM_L_MONTH,C^.Month);
 I:=CalFind(C,C^.Y,C^.M,C^.D,C^.Sel);
 MenuCheck(W,CM_L_ALARM,(I>0) And C^.A[I].Alarm);
End;

Function CalCreate(Const Path: String): PWindow;
Var W: PWindow; C: PCal;
Begin
 W:=NewWindow(A_CALEN,'Calendar',-1,-1,420,330,True);
 If W=Nil Then Begin CalCreate:=Nil;Exit;End;
 New(C);FillChar(C^,SizeOf(TCal),0);
 C^.Interval:=60;C^.DayStart:=7*60;C^.H24:=Clock24;C^.AlarmSound:=True;C^.AlarmEarly:=0;
 CalNew(C);
 W^.Data:=C;
 WinAddMenu(W,'&File~&Fichier~&Datei');
 WinAddItem(W,'&New~&Nouveau~&Neu',CM_L_NEW,'');
 WinAddItem(W,'&Open...~&Ouvrir...~'#142'&ffnen...',CM_L_OPEN,'');
 WinAddItem(W,'&Save~&Enregistrer~&Speichern',CM_L_SAVE,'');
 WinAddItem(W,'Save &As...~Enregistrer &sous...~Speichern &unter...',CM_L_SAVEAS,'');
 WinAddItem(W,'&Print...~&Imprimer...~&Drucken...',CM_L_PRINT,'');
 WinAddItem(W,'&Remove...~S&upprimer...~&Entfernen...',CM_L_REMOVE,'');
 WinAddItem(W,'E&xit~&Quitter~&Beenden',CM_L_EXIT,'');
 WinAddItem(W,'A&bout Calendar...~&'#133' propos de Calendar...~'#154'&ber Calendar...',CM_L_ABOUT,'');
 WinAddMenu(W,'&Edit~&'#144'dition~&Bearbeiten');
 WinAddItem(W,'Cu&t~Co&uper~&Ausschneiden',CM_L_CUT,'Ctrl+X');
 WinAddItem(W,'&Copy~&Copier~&Kopieren',CM_L_COPY,'Ctrl+Ins');
 WinAddItem(W,'&Paste~Co&ller~&Einf'#129'gen',CM_L_PASTE,'Ctrl+V');
 WinAddMenu(W,'&View~&Affichage~&Ansicht');
 WinAddItem(W,'&Day~&Jour~&Tag',CM_L_DAY,'');
 WinAddItem(W,'&Month~&Mois~&Monat',CM_L_MONTH,'');
 WinAddMenu(W,'S&how~A&fficher~&Zeigen');
 WinAddItem(W,'&Previous~&Pr'#130'c'#130'dent~&Vorheriger',CM_L_PREV,'Ctrl+PgUp');
 WinAddItem(W,'&Next~&Suivant~&N'#132'chster',CM_L_NEXT,'Ctrl+PgDn');
 WinAddItem(W,'&Today~&Aujourd''hui~&Heute',CM_L_TODAY,'F4');
 WinAddItem(W,'&Date...~&Date...~&Datum...',CM_L_DATE,'');
 WinAddMenu(W,'&Alarm~&Alarme~&Alarm');
 WinAddItem(W,'&Set~&D'#130'finir~&Setzen',CM_L_ALARM,'F5');
 WinAddItem(W,'&Controls...~&Contr'#148'les...~&Steuerung...',CM_L_CONTROLS,'');
 WinAddMenu(W,'&Options~&Options~&Optionen');
 WinAddItem(W,'&Mark...~&Marquer...~&Markieren...',CM_L_MARK,'F6');
 WinAddItem(W,'&Special Time...~&Heure sp'#130'ciale...~&Sonderzeit...',CM_L_SPECIAL,'F7');
 WinAddItem(W,'&Day Settings...~&R'#130'glages du jour...~Tag&eseinstellungen...',CM_L_DAYSET,'');
 CalTitle(W);
 If Path<>'' Then If CalLoad(C,Path) Then CalTitle(W);
 CalCreate:=W;
End;

{ ====================================================================== }
{                                PAINT                                   }
{ ====================================================================== }

Const
 CM_G_NEW=901; CM_G_OPEN=902; CM_G_SAVE=903; CM_G_SAVEAS=904; CM_G_PRINT=905;
 CM_G_EXIT=906; CM_G_ABOUT=907;
 CM_G_UNDO=911; CM_G_CUT=912; CM_G_COPY=913; CM_G_PASTE=914; CM_G_CLEAR=915;
 CM_G_INVERT=916; CM_G_FLIPH=917; CM_G_FLIPV=918; CM_G_ALL=919;
 CM_G_FONT=920;   { 920..923 }
 CM_G_SIZE=930;   { 930..935 }
 CM_G_PLAIN=941; CM_G_BOLD=942; CM_G_ITAL=943; CM_G_UNDER=944;
 CM_G_PAT=950;    { 950..965 }
 CM_G_LW=970;     { 970..975 }
 CM_G_GRID=980;
 PCW = 640; PCH = 400; PCSZ = 256000;
 NTOOLS = 13; NPATS = 14; TBH = 54;

 PatData : Array[0..NPATS-1,0..7] Of Byte = (
  ($FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF),
  ($EE,$BB,$EE,$BB,$EE,$BB,$EE,$BB),
  ($AA,$55,$AA,$55,$AA,$55,$AA,$55),
  ($88,$22,$88,$22,$88,$22,$88,$22),
  ($80,$00,$08,$00,$80,$00,$08,$00),
  ($00,$00,$00,$00,$00,$00,$00,$00),
  ($FF,$00,$00,$00,$FF,$00,$00,$00),
  ($88,$88,$88,$88,$88,$88,$88,$88),
  ($80,$40,$20,$10,$08,$04,$02,$01),
  ($01,$02,$04,$08,$10,$20,$40,$80),
  ($FF,$88,$88,$88,$FF,$22,$22,$22),
  ($F0,$F0,$F0,$F0,$0F,$0F,$0F,$0F),
  ($81,$42,$24,$18,$18,$24,$42,$81),
  ($77,$77,$77,$00,$DD,$DD,$DD,$00));

 PatNames : Array[0..NPATS-1] Of String[40] = (
  'Black~Noir~Schwarz','Dark Gray~Gris fonce~Dunkelgrau','Gray~Gris~Grau','Light Gray~Gris clair~Hellgrau',
  'Dots~Points~Punkte','White~Blanc~Wei'#225,'Horizontal~Horizontal~Waagerecht','Vertical~Vertical~Senkrecht',
  'Diagonal \~Diagonale \~Diagonal \','Diagonal /~Diagonale /~Diagonal /','Brick~Briques~Ziegel',
  'Checks~Damier~Karo','Diamond~Losange~Raute','Weave~Tissage~Gewebe');

Type
 PPaint = ^TPaint;
 TPaint = Record
  Cv,Un : PByteArr_;
  Tool,Pat,LW : Integer;
  FStyle,FSize : Integer;
  FName : Integer;
  Drag  : Boolean;
  SX,SY,LX,LY : Integer;
  SelOn : Boolean;
  SX1,SY1,SX2,SY2 : Integer;
  Float : PByteArr_;
  FW,FH,FX,FY : Integer;
  HasFloat,MoveFl : Boolean;
  GDX,GDY : Integer;
  FileName : String[80];
  Modified : Boolean;
  Erasing : Boolean;
  Grid : Boolean;
 End;

Var PtErase: Boolean;

Function Array4(I: Integer): Integer;
Begin
 Case I Of 0: Array4:=1;1: Array4:=2;2: Array4:=3;Else Array4:=5;End;
End;

Function PatPix(P,X,Y: Integer): Boolean;
Begin
 PatPix:=((PatData[P,Y And 7] Shr (7-(X And 7))) And 1)=1;
End;

Procedure PtPlot(P: PPaint; X,Y: Integer; Black: Boolean);
Begin
 If (X<0) Or (Y<0) Or (X>=PCW) Or (Y>=PCH) Then Exit;
 If PtErase Then P^.Cv^[Y*PCW+X]:=0 Else P^.Cv^[Y*PCW+X]:=Ord(Black);
End;

Procedure PtStamp(P: PPaint; X,Y: Integer; UsePat,Opaque: Boolean);
Var I,J,R: Integer; B: Boolean;
Begin
 R:=P^.LW Div 2;
 For I:=-R To P^.LW-1-R Do
  For J:=-R To P^.LW-1-R Do Begin
   If UsePat Then B:=PatPix(P^.Pat,X+I,Y+J) Else B:=True;
   If B Then PtPlot(P,X+I,Y+J,True) Else If Opaque Then PtPlot(P,X+I,Y+J,False);
  End;
End;

Procedure PtLine(P: PPaint; X1,Y1,X2,Y2: Integer; UsePat: Boolean);
Var DX,DY,SX,SY,E,E2: Integer;
Begin
 DX:=Abs(X2-X1);DY:=-Abs(Y2-Y1);
 If X1<X2 Then SX:=1 Else SX:=-1;
 If Y1<Y2 Then SY:=1 Else SY:=-1;
 E:=DX+DY;
 While True Do Begin
  PtStamp(P,X1,Y1,UsePat,False);
  If (X1=X2) And (Y1=Y2) Then Break;
  E2:=2*E;
  If E2>=DY Then Begin E:=E+DY;X1:=X1+SX;End;
  If E2<=DX Then Begin E:=E+DX;Y1:=Y1+SY;End;
 End;
End;

Procedure PtSpan(P: PPaint; X1,X2,Y: Integer);   { remplissage avec le motif }
Var X: Integer;
Begin
 If X1>X2 Then Begin X:=X1;X1:=X2;X2:=X;End;
 For X:=X1 To X2 Do PtPlot(P,X,Y,PatPix(P^.Pat,X,Y));
End;

Procedure PtRect(P: PPaint; X1,Y1,X2,Y2: Integer; Filled: Boolean);
Var T,Y: Integer;
Begin
 If X1>X2 Then Begin T:=X1;X1:=X2;X2:=T;End;
 If Y1>Y2 Then Begin T:=Y1;Y1:=Y2;Y2:=T;End;
 If Filled Then For Y:=Y1 To Y2 Do PtSpan(P,X1,X2,Y);
 PtLine(P,X1,Y1,X2,Y1,False);PtLine(P,X2,Y1,X2,Y2,False);
 PtLine(P,X2,Y2,X1,Y2,False);PtLine(P,X1,Y2,X1,Y1,False);
End;

Procedure PtEllipse(P: PPaint; X1,Y1,X2,Y2: Integer; Filled,Round_: Boolean);
Var T,Y,RX,RY,CX,CY,N,I,XW,XR: Integer; A,Hx: Double; Rr: Integer;
Begin
 If X1>X2 Then Begin T:=X1;X1:=X2;X2:=T;End;
 If Y1>Y2 Then Begin T:=Y1;Y1:=Y2;Y2:=T;End;
 RX:=(X2-X1) Div 2;RY:=(Y2-Y1) Div 2;CX:=(X1+X2) Div 2;CY:=(Y1+Y2) Div 2;
 If Round_ Then Begin
  Rr:=Min2(10,Min2(RX,RY));
  If Filled Then
   For Y:=Y1 To Y2 Do Begin
    XW:=0;
    If Y<Y1+Rr Then Begin XW:=Rr-Round(Sqrt(Max2(0,Sqr(LongInt(Rr))-Sqr(LongInt(Y1+Rr-Y)))));End
    Else If Y>Y2-Rr Then XW:=Rr-Round(Sqrt(Max2(0,Sqr(LongInt(Rr))-Sqr(LongInt(Y-(Y2-Rr))))));
    PtSpan(P,X1+XW,X2-XW,Y);
   End;
  PtLine(P,X1+Rr,Y1,X2-Rr,Y1,False);PtLine(P,X1+Rr,Y2,X2-Rr,Y2,False);
  PtLine(P,X1,Y1+Rr,X1,Y2-Rr,False);PtLine(P,X2,Y1+Rr,X2,Y2-Rr,False);
  N:=Rr*3+2;
  For I:=0 To N Do Begin
   A:=I*(Pi/2)/N;
   PtStamp(P,X1+Rr-Round(Cos(A)*Rr),Y1+Rr-Round(Sin(A)*Rr),False,False);
   PtStamp(P,X2-Rr+Round(Cos(A)*Rr),Y1+Rr-Round(Sin(A)*Rr),False,False);
   PtStamp(P,X1+Rr-Round(Cos(A)*Rr),Y2-Rr+Round(Sin(A)*Rr),False,False);
   PtStamp(P,X2-Rr+Round(Cos(A)*Rr),Y2-Rr+Round(Sin(A)*Rr),False,False);
  End;
  Exit;
 End;
 If (RX=0) Or (RY=0) Then Begin PtLine(P,X1,Y1,X2,Y2,False);Exit;End;
 If Filled Then
  For Y:=-RY To RY Do Begin
   Hx:=RX*Sqrt(1-Sqr(Y/RY));
   PtSpan(P,CX-Round(Hx),CX+Round(Hx),CY+Y);
  End;
 N:=(RX+RY)*4;
 For I:=0 To N-1 Do Begin
  A:=I*2*Pi/N;
  PtStamp(P,CX+Round(Cos(A)*RX),CY+Round(Sin(A)*RY),False,False);
 End;
End;

Procedure PtFill(P: PPaint; X,Y: Integer);
Type TStk = Array[0..8191] Of Integer;
Var Stk: ^TStk; Sp,L,R,XX,YY,Dy: Integer; Done: PByteArr_;
Begin
 If (X<0) Or (Y<0) Or (X>=PCW) Or (Y>=PCH) Then Exit;
 If P^.Cv^[Y*PCW+X]<>0 Then Exit;
 GetMem(Done,PCSZ);FillChar(Done^,PCSZ,0);
 New(Stk);Sp:=0;
 Stk^[Sp]:=X;Stk^[Sp+1]:=Y;Inc(Sp,2);
 While Sp>0 Do Begin
  Dec(Sp,2);XX:=Stk^[Sp];YY:=Stk^[Sp+1];
  If (YY<0) Or (YY>=PCH) Or (P^.Cv^[YY*PCW+XX]<>0) Or (Done^[YY*PCW+XX]<>0) Then Continue;
  L:=XX;R:=XX;
  While (L>0) And (P^.Cv^[YY*PCW+L-1]=0) And (Done^[YY*PCW+L-1]=0) Do Dec(L);
  While (R<PCW-1) And (P^.Cv^[YY*PCW+R+1]=0) And (Done^[YY*PCW+R+1]=0) Do Inc(R);
  For XX:=L To R Do Done^[YY*PCW+XX]:=1;
  For Dy:=-1 To 1 Do Begin
   If Dy=0 Then Continue;
   If (YY+Dy<0) Or (YY+Dy>=PCH) Then Continue;
   XX:=L;
   While XX<=R Do Begin
    If (P^.Cv^[(YY+Dy)*PCW+XX]=0) And (Done^[(YY+Dy)*PCW+XX]=0) And (Sp<8190) Then Begin
     Stk^[Sp]:=XX;Stk^[Sp+1]:=YY+Dy;Inc(Sp,2);
     While (XX<=R) And (P^.Cv^[(YY+Dy)*PCW+XX]=0) Do Inc(XX);
    End Else Inc(XX);
   End;
  End;
 End;
 For YY:=0 To PCH-1 Do
  For XX:=0 To PCW-1 Do
   If Done^[YY*PCW+XX]<>0 Then P^.Cv^[YY*PCW+XX]:=Ord(PatPix(P^.Pat,XX,YY));
 Dispose(Stk);FreeMem(Done,PCSZ);
End;

Procedure PtBackup(P: PPaint);
Begin
 Move(P^.Cv^,P^.Un^,PCSZ);
End;

Procedure PtUndoSwap(P: PPaint);
Var T: PByteArr_;
Begin
 GetMem(T,PCSZ);
 Move(P^.Cv^,T^,PCSZ);Move(P^.Un^,P^.Cv^,PCSZ);Move(T^,P^.Un^,PCSZ);
 FreeMem(T,PCSZ);
End;

{ Rendu de texte : on dessine a l'ecran dans une zone temporaire puis on lit les pixels }
Procedure PtText(P: PPaint; X,Y: Integer; Const S: String);
Var Sv: TSave; Sz,I,J,W_,H_,Sc: Integer; Sh: Integer;
Begin
 If S='' Then Exit;
 Sc:=1;
 If P^.FSize>=3 Then Sc:=2;
 If P^.FSize>=5 Then Sc:=3;
 W_:=Min2(Length(S)*8*Sc+3,PCW-X);H_:=8*Sc+2;
 If W_<=0 Then Exit;
 HideMouse;
 ClipFull;
 SaveBack(Sv,0,SCR_H-H_-2,W_+4,SCR_H-1);
 SetFillStyle(SolidFill,cWht);Bar(0,SCR_H-H_-2,W_+4,SCR_H-1);
 SetColor(cBlk);SetTextStyle(DefaultFont,HorizDir,Sc);
 OutTextXY(1,SCR_H-H_-1,S);
 If (P^.FStyle And 1)<>0 Then OutTextXY(2,SCR_H-H_-1,S);
 SetTextStyle(DefaultFont,HorizDir,1);
 For J:=0 To H_-1 Do Begin
  Sh:=0;
  If (P^.FStyle And 2)<>0 Then Sh:=(H_-J) Div 4;
  For I:=0 To W_-1 Do
   If GetPixel(1+I,SCR_H-H_-1+J)=cBlk Then PtPlot(P,X+I+Sh,Y+J,True);
 End;
 If (P^.FStyle And 4)<>0 Then PtLine(P,X,Y+H_-1,X+W_,Y+H_-1,False);
 RestoreBack(Sv);
 ShowMouse;
End;

Procedure PtClearSel(P: PPaint);
Begin
 If P^.Float<>Nil Then Begin FreeMem(P^.Float,P^.FW*P^.FH);P^.Float:=Nil;End;
 P^.HasFloat:=False;P^.SelOn:=False;P^.MoveFl:=False;
End;

Procedure PtCommitFloat(P: PPaint);
Var I,J: Integer;
Begin
 If Not P^.HasFloat Then Exit;
 For J:=0 To P^.FH-1 Do For I:=0 To P^.FW-1 Do
  PtPlot(P,P^.FX+I,P^.FY+J,P^.Float^[J*P^.FW+I]<>0);
 PtClearSel(P);
End;

Procedure PtSelCopy(P: PPaint; Cut: Boolean);
Var X1,Y1,X2,Y2,I,J: Integer; B: PByteArr_; W_,H_: Integer;
Begin
 If P^.HasFloat Then Begin
  W_:=P^.FW;H_:=P^.FH;GetMem(B,W_*H_);Move(P^.Float^,B^,W_*H_);
  If Cut Then PtClearSel(P);
 End Else If P^.SelOn Then Begin
  X1:=Min2(P^.SX1,P^.SX2);X2:=Max2(P^.SX1,P^.SX2);Y1:=Min2(P^.SY1,P^.SY2);Y2:=Max2(P^.SY1,P^.SY2);
  W_:=X2-X1+1;H_:=Y2-Y1+1;GetMem(B,W_*H_);
  For J:=0 To H_-1 Do For I:=0 To W_-1 Do B^[J*W_+I]:=P^.Cv^[(Y1+J)*PCW+X1+I];
  If Cut Then Begin
   PtBackup(P);
   For J:=Y1 To Y2 Do For I:=X1 To X2 Do P^.Cv^[J*PCW+I]:=0;
   P^.SelOn:=False;
  End;
 End Else Exit;
 ClipClear;
 ClipBmp:=B;ClipBmpW:=W_;ClipBmpH:=H_;ClipKind:=2;
 P^.Modified:=True;
End;

Procedure PtPaste(P: PPaint);
Begin
 If (ClipKind<>2) Or (ClipBmp=Nil) Then Begin
  InfoBox(T3('The Clipboard does not contain a bitmap.','Le Presse-papiers ne contient pas de bitmap.','Die Zwischenablage enth'#132'lt keine Bitmap.'));Exit;
 End;
 PtCommitFloat(P);
 PtBackup(P);
 GetMem(P^.Float,ClipBmpW*ClipBmpH);
 Move(ClipBmp^,P^.Float^,ClipBmpW*ClipBmpH);
 P^.FW:=ClipBmpW;P^.FH:=ClipBmpH;P^.FX:=0;P^.FY:=0;
 P^.HasFloat:=True;P^.SelOn:=True;
 P^.SX1:=0;P^.SY1:=0;P^.SX2:=P^.FW-1;P^.SY2:=P^.FH-1;
 P^.Modified:=True;
End;

Procedure PaintGeom(W: PWindow; Var OX,OY,VW,VH: Integer);
Var P: PPaint; X1,Y1,X2,Y2: Integer;
Begin
 P:=W^.Data;
 WinClient(W,X1,Y1,X2,Y2);
 OX:=X1-W^.HPos;OY:=Y1+TBH-W^.VPos;
 VW:=X2-X1+1;VH:=Y2-Y1+1-TBH;
End;

Procedure ToolGlyph(T,X,Y,C: Integer);
Begin
 Case T Of
  0: GDotRect(X+4,Y+4,X+21,Y+15,C);
  1: Begin GText(X+9,Y+6,'T',C);GText(X+10,Y+6,'T',C);End;
  2: Begin GLine(X+5,Y+16,X+19,Y+4,C);GLine(X+6,Y+16,X+20,Y+4,C);GPix(X+4,Y+17,C);End;
  3: Begin GFillEllipse(X+13,Y+10,5,4,C);GLine(X+16,Y+6,X+21,Y+2,C);End;
  4: GLine(X+4,Y+16,X+21,Y+4,C);
  5: Begin GRect(X+6,Y+5,X+17,Y+14,C);GBar(X+8,Y+10,X+15,Y+13,C);GLine(X+17,Y+8,X+21,Y+16,C);End;
  6: Begin GPix(X+6,Y+6,C);GPix(X+10,Y+4,C);GPix(X+14,Y+8,C);GPix(X+18,Y+5,C);GPix(X+8,Y+12,C);GPix(X+13,Y+14,C);GPix(X+19,Y+13,C);GPix(X+11,Y+9,C);End;
  7: GRect(X+4,Y+4,X+21,Y+15,C);
  8: GBar(X+4,Y+4,X+21,Y+15,C);
  9: Begin GRound(X+4,Y+4,X+21,Y+15,C);End;
  10: GEllipse(X+13,Y+10,9,6,C);
  11: GFillEllipse(X+13,Y+10,9,6,C);
  12: Begin GRect(X+6,Y+5,X+19,Y+14,C);GBar(X+6,Y+9,X+19,Y+14,C);End;
 End;
End;

Procedure PaintDraw(W: PWindow);
Var P: PPaint; X1,Y1,X2,Y2,I,J,OX,OY,VW,VH,Sx,Sy,Run,Xs: Integer; BG: Integer; T: Integer;
    Vx1,Vy1,Vx2,Vy2: Integer;
Begin
 P:=W^.Data;
 WinClient(W,X1,Y1,X2,Y2);
 PaintGeom(W,OX,OY,VW,VH);
 { barre d'outils }
 GBar(X1,Y1,X2,Y1+TBH-1,cWht);GHLine(X1,X2,Y1+TBH-1,cBlk);
 For I:=0 To NTOOLS-1 Do Begin
  Sx:=X1+4+(I Mod 13)*27;Sy:=Y1+3;
  If P^.Tool=I Then Begin GBar(Sx,Sy,Sx+25,Sy+21,cBlk);ToolGlyph(I,Sx,Sy,cWht);End
  Else Begin GRect(Sx,Sy,Sx+25,Sy+21,cBlk);ToolGlyph(I,Sx,Sy,cBlk);End;
 End;
 For I:=0 To NPATS-1 Do Begin
  Sx:=X1+4+I*25;Sy:=Y1+28;
  GBar(Sx,Sy,Sx+22,Sy+20,cWht);
  For J:=0 To 20 Do For T:=0 To 22 Do If PatPix(I,T,J) Then GPix(Sx+T,Sy+J,cBlk);
  GRect(Sx,Sy,Sx+22,Sy+20,cBlk);
  If P^.Pat=I Then GRect(Sx-2,Sy-2,Sx+24,Sy+22,cBlk);
 End;
 For I:=0 To 3 Do Begin
  Sx:=X2-120+I*28;Sy:=Y1+28;
  GRect(Sx,Sy,Sx+25,Sy+20,cBlk);
  T:=Array4(I);
  GBar(Sx+4,Sy+10-T Div 2,Sx+21,Sy+10-T Div 2+T-1,cBlk);
  If P^.LW=T Then GRect(Sx+1,Sy+1,Sx+24,Sy+19,cBlk);
 End;
 { zone de dessin }
 SetClip(X1,Y1+TBH,X2,Y2);
 GBar(X1,Y1+TBH,X2,Y2,cWht);
 Vx1:=Max2(0,X1-OX);Vx2:=Min2(PCW-1,X2-OX);
 Vy1:=Max2(0,Y1+TBH-OY);Vy2:=Min2(PCH-1,Y2-OY);
 For J:=Vy1 To Vy2 Do Begin
  I:=Vx1;
  While I<=Vx2 Do Begin
   If P^.Cv^[J*PCW+I]<>0 Then Begin
    Xs:=I;
    While (I<Vx2) And (P^.Cv^[J*PCW+I+1]<>0) Do Inc(I);
    GHLine(OX+Xs,OX+I,OY+J,cBlk);
   End;
   Inc(I);
  End;
 End;
 If P^.HasFloat Then Begin
  For J:=0 To P^.FH-1 Do For I:=0 To P^.FW-1 Do
   If P^.Float^[J*P^.FW+I]<>0 Then GPix(OX+P^.FX+I,OY+P^.FY+J,cBlk) Else GPix(OX+P^.FX+I,OY+P^.FY+J,cWht);
  GDotRect(OX+P^.FX-1,OY+P^.FY-1,OX+P^.FX+P^.FW,OY+P^.FY+P^.FH,cBlk);
 End Else If P^.SelOn Then
  GDotRect(OX+Min2(P^.SX1,P^.SX2),OY+Min2(P^.SY1,P^.SY2),OX+Max2(P^.SX1,P^.SX2),OY+Max2(P^.SY1,P^.SY2),cBlk);
 W^.HasVS:=True;W^.HasHS:=True;
 W^.VTot:=PCH;W^.VPage:=VH;W^.HTot:=PCW;W^.HPage:=VW;
 If W^.VPos>PCH-VH Then W^.VPos:=Max2(0,PCH-VH);
 If W^.HPos>PCW-VW Then W^.HPos:=Max2(0,PCW-VW);
End;

Procedure PaintMouse(W: PWindow; Var E: TEvent);
Var P: PPaint; X1,Y1,X2,Y2,OX,OY,VW,VH,I,CX,CY,T,Sx,Sy,A,B: Integer; S: String; Sv: Integer;
Begin
 P:=W^.Data;
 WinClient(W,X1,Y1,X2,Y2);
 PaintGeom(W,OX,OY,VW,VH);
 CX:=E.X-OX;CY:=E.Y-OY;
 PtErase:=False;
 If E.Kind=EV_DOWN Then Begin
  If E.Y<Y1+TBH Then Begin
   For I:=0 To NTOOLS-1 Do Begin
    Sx:=X1+4+(I Mod 13)*27;Sy:=Y1+3;
    If InBox(E.X,E.Y,Sx,Sy,Sx+25,Sy+21) Then Begin PtCommitFloat(P);P^.SelOn:=False;P^.Tool:=I;Dirty:=True;End;
   End;
   For I:=0 To NPATS-1 Do Begin
    Sx:=X1+4+I*25;Sy:=Y1+28;
    If InBox(E.X,E.Y,Sx,Sy,Sx+22,Sy+20) Then Begin P^.Pat:=I;Dirty:=True;End;
   End;
   For I:=0 To 3 Do Begin
    Sx:=X2-120+I*28;Sy:=Y1+28;
    If InBox(E.X,E.Y,Sx,Sy,Sx+25,Sy+20) Then Begin P^.LW:=Array4(I);Dirty:=True;End;
   End;
   Exit;
  End;
  If (CX<0) Or (CY<0) Or (CX>=PCW) Or (CY>=PCH) Then Exit;
  Capture:=W;P^.Drag:=True;
  P^.SX:=CX;P^.SY:=CY;P^.LX:=CX;P^.LY:=CY;
  P^.Modified:=True;
  If P^.HasFloat Then Begin
   If InBox(CX,CY,P^.FX,P^.FY,P^.FX+P^.FW-1,P^.FY+P^.FH-1) Then Begin
    P^.MoveFl:=True;P^.GDX:=CX-P^.FX;P^.GDY:=CY-P^.FY;Exit;
   End Else PtCommitFloat(P);
  End;
  If P^.Tool=0 Then Begin
   If P^.SelOn And InBox(CX,CY,Min2(P^.SX1,P^.SX2),Min2(P^.SY1,P^.SY2),Max2(P^.SX1,P^.SX2),Max2(P^.SY1,P^.SY2)) Then Begin
    PtBackup(P);
    A:=Min2(P^.SX1,P^.SX2);B:=Min2(P^.SY1,P^.SY2);
    P^.FW:=Abs(P^.SX2-P^.SX1)+1;P^.FH:=Abs(P^.SY2-P^.SY1)+1;
    GetMem(P^.Float,P^.FW*P^.FH);
    For T:=0 To P^.FH-1 Do For I:=0 To P^.FW-1 Do Begin
     P^.Float^[T*P^.FW+I]:=P^.Cv^[(B+T)*PCW+A+I];P^.Cv^[(B+T)*PCW+A+I]:=0;End;
    P^.FX:=A;P^.FY:=B;P^.HasFloat:=True;P^.MoveFl:=True;P^.GDX:=CX-A;P^.GDY:=CY-B;
   End Else Begin P^.SelOn:=True;P^.SX1:=CX;P^.SY1:=CY;P^.SX2:=CX;P^.SY2:=CY;End;
   Exit;
  End;
  PtBackup(P);
  Case P^.Tool Of
   1: Begin P^.Drag:=False;Capture:=Nil;
       S:='';
       If InputBox(T3('Text:','Texte :','Text:'),S,60,420) Then Begin PtBackup(P);PtText(P,CX,CY,S);End;
      End;
   2: Begin P^.Erasing:=P^.Cv^[CY*PCW+CX]<>0;PtErase:=P^.Erasing;PtStamp(P,CX,CY,False,False);PtErase:=False;End;
   3: PtStamp(P,CX,CY,True,False);
   5: Begin PtFill(P,CX,CY);P^.Drag:=False;Capture:=Nil;End;
   6: For I:=1 To 12 Do PtPlot(P,CX+Random(15)-7,CY+Random(15)-7,True);
   12: Begin Sv:=P^.LW;P^.LW:=P^.LW*4+2;PtErase:=True;PtStamp(P,CX,CY,False,False);PtErase:=False;P^.LW:=Sv;End;
  End;
  Dirty:=True;
  Exit;
 End;
 If (E.Kind=EV_MOVE) And P^.Drag Then Begin
  If CX<0 Then CX:=0;
  If CY<0 Then CY:=0;
  If CX>=PCW Then CX:=PCW-1;
  If CY>=PCH Then CY:=PCH-1;
  If P^.MoveFl Then Begin P^.FX:=CX-P^.GDX;P^.FY:=CY-P^.GDY;Invalidate(W);Exit;End;
  Case P^.Tool Of
   0: Begin P^.SX2:=CX;P^.SY2:=CY;End;
   2: Begin PtErase:=P^.Erasing;PtLine(P,P^.LX,P^.LY,CX,CY,False);PtErase:=False;P^.LX:=CX;P^.LY:=CY;End;
   3: Begin PtLine(P,P^.LX,P^.LY,CX,CY,True);P^.LX:=CX;P^.LY:=CY;End;
   6: For I:=1 To 14 Do PtPlot(P,CX+Random(17)-8,CY+Random(17)-8,True);
   12: Begin Sv:=P^.LW;P^.LW:=P^.LW*4+2;PtErase:=True;PtLine(P,P^.LX,P^.LY,CX,CY,False);PtErase:=False;
        P^.LW:=Sv;P^.LX:=CX;P^.LY:=CY;End;
   4,7,8,9,10,11: Begin
       Move(P^.Un^,P^.Cv^,PCSZ);
       Case P^.Tool Of
        4: PtLine(P,P^.SX,P^.SY,CX,CY,True);
        7: PtRect(P,P^.SX,P^.SY,CX,CY,False);
        8: PtRect(P,P^.SX,P^.SY,CX,CY,True);
        9: PtEllipse(P,P^.SX,P^.SY,CX,CY,False,True);
        10: PtEllipse(P,P^.SX,P^.SY,CX,CY,False,False);
        11: PtEllipse(P,P^.SX,P^.SY,CX,CY,True,False);
       End;
      End;
  End;
  Invalidate(W);
 End;
 If E.Kind=EV_UP Then Begin
  P^.Drag:=False;P^.MoveFl:=False;
  Dirty:=True;
 End;
End;

Procedure PaintTitle(W: PWindow);
Var P: PPaint;
Begin
 P:=W^.Data;
 W^.Title:='Paint - '+IfThenS(P^.FileName='',T3('(untitled)','(sans titre)','(unbenannt)'),BaseName(P^.FileName));
End;

Procedure PaintNew(P: PPaint);
Begin
 FillChar(P^.Cv^,PCSZ,0);FillChar(P^.Un^,PCSZ,0);
 PtClearSel(P);P^.FileName:='';P^.Modified:=False;
End;

{ Fichier .MSP (Microsoft Paint v1 'DanM', non compresse) }
Function PaintSaveMsp(P: PPaint; Const Path: String): Boolean;
Var F: File; H: Array[0..31] Of Byte; Row: Array[0..127] Of Byte; Y,X,Ck,I: Integer;
Begin
 PaintSaveMsp:=False;
 PtCommitFloat(P);
 FillChar(H,32,0);
 H[0]:=Ord('D');H[1]:=Ord('a');H[2]:=Ord('n');H[3]:=Ord('M');
 H[4]:=PCW And 255;H[5]:=PCW Shr 8;H[6]:=PCH And 255;H[7]:=PCH Shr 8;
 H[8]:=1;H[10]:=1;H[12]:=1;H[14]:=1;
 H[16]:=PCW And 255;H[17]:=PCW Shr 8;H[18]:=PCH And 255;H[19]:=PCH Shr 8;
 Ck:=0;
 For I:=0 To 11 Do Ck:=Ck Xor (H[I*2]+H[I*2+1]*256);
 H[24]:=Ck And 255;H[25]:=(Ck Shr 8) And 255;
 {$I-}
 Assign(F,V2R(Path));Rewrite(F,1);
 If IOResult<>0 Then Exit;
 BlockWrite(F,H,32);
 For Y:=0 To PCH-1 Do Begin
  FillChar(Row,SizeOf(Row),0);
  For X:=0 To PCW-1 Do If P^.Cv^[Y*PCW+X]=0 Then Row[X Shr 3]:=Row[X Shr 3] Or (128 Shr (X And 7));
  BlockWrite(F,Row,(PCW+7) Div 8);
 End;
 Close(F);
 {$I+}
 PaintSaveMsp:=IOResult=0;
End;

Function PaintLoadMsp(P: PPaint; Const Path: String): Boolean;
Var F: File; H: Array[0..31] Of Byte; Row: Array[0..127] Of Byte; Y,X,W_,H_,N: Integer; Cnt: Word;
Begin
 PaintLoadMsp:=False;
 {$I-}
 Assign(F,V2R(Path));Reset(F,1);
 If IOResult<>0 Then Exit;
 BlockRead(F,H,32,Cnt);
 If (Cnt<32) Or (H[0]<>Ord('D')) Or (H[1]<>Ord('a')) Or (H[2]<>Ord('n')) Or (H[3]<>Ord('M')) Then Begin Close(F);Exit;End;
 W_:=H[4]+H[5]*256;H_:=H[6]+H[7]*256;
 FillChar(P^.Cv^,PCSZ,0);
 N:=(W_+7) Div 8;
 If N>128 Then N:=128;
 For Y:=0 To H_-1 Do Begin
  BlockRead(F,Row,N,Cnt);
  If Y<PCH Then
   For X:=0 To Min2(W_,PCW)-1 Do P^.Cv^[Y*PCW+X]:=Ord((Row[X Shr 3] And (128 Shr (X And 7)))=0);
 End;
 Close(F);
 {$I+}
 PaintLoadMsp:=True;
End;

Procedure PaintMenu(W: PWindow; Cmd: Integer);
Var P: PPaint; S,Pth: String; X,Y: Integer; T: LongInt;
Begin
 P:=W^.Data;
 Case Cmd Of
  CM_G_NEW: If (Not P^.Modified) Or (MsgBox(T3('Discard the current picture?','Abandonner l''image courante ?','Aktuelles Bild verwerfen?'),1,2)=ID_OK) Then Begin PaintNew(P);PaintTitle(W);End;
  CM_G_OPEN: Begin Pth:='';If FileDialog(0,T3('Open File Name:','Ouvrir :','Datei '#148'ffnen:'),'*.MSP',Pth) Then Begin
     If PaintLoadMsp(P,Pth) Then Begin P^.FileName:=Pth;P^.Modified:=False;PaintTitle(W);End
     Else InfoBox(T3('Not a valid Paint file.','Fichier Paint invalide.','Keine g'#129'ltige Paint-Datei.'));End;End;
  CM_G_SAVE,CM_G_SAVEAS: Begin
    Pth:=P^.FileName;
    If (Cmd=CM_G_SAVEAS) Or (Pth='') Then If Not FileDialog(1,T3('Save File Name As:','Enregistrer sous :','Speichern unter:'),'*.MSP',Pth) Then Exit;
    If PaintSaveMsp(P,Pth) Then Begin P^.FileName:=Pth;P^.Modified:=False;PaintTitle(W);End
    Else InfoBox(T3('Cannot save the file.','Impossible d''enregistrer.','Speichern nicht m'#148'glich.'));
   End;
  CM_G_PRINT: SpoolAdd('Paint - '+IfThenS(P^.FileName='',T3('(untitled)','(sans titre)','(unbenannt)'),BaseName(P^.FileName)));
  CM_G_EXIT: CloseWindow(W);
  CM_G_ABOUT: ShowAboutMs('Paint',4,False);
  CM_G_UNDO: Begin PtClearSel(P);PtUndoSwap(P);End;
  CM_G_CUT: PtSelCopy(P,True);
  CM_G_COPY: PtSelCopy(P,False);
  CM_G_PASTE: PtPaste(P);
  CM_G_CLEAR: Begin PtBackup(P);
     If P^.SelOn And Not P^.HasFloat Then Begin
      For Y:=Min2(P^.SY1,P^.SY2) To Max2(P^.SY1,P^.SY2) Do For X:=Min2(P^.SX1,P^.SX2) To Max2(P^.SX1,P^.SX2) Do P^.Cv^[Y*PCW+X]:=0;
     End Else If P^.HasFloat Then PtClearSel(P)
     Else FillChar(P^.Cv^,PCSZ,0);
     P^.Modified:=True;End;
  CM_G_ALL: Begin PtCommitFloat(P);P^.Tool:=0;P^.SelOn:=True;P^.SX1:=0;P^.SY1:=0;P^.SX2:=PCW-1;P^.SY2:=PCH-1;End;
  CM_G_INVERT: Begin PtBackup(P);For T:=0 To PCSZ-1 Do P^.Cv^[T]:=1-P^.Cv^[T];P^.Modified:=True;End;
  CM_G_FLIPH: Begin PtBackup(P);For Y:=0 To PCH-1 Do For X:=0 To PCW-1 Do P^.Cv^[Y*PCW+X]:=P^.Un^[Y*PCW+(PCW-1-X)];P^.Modified:=True;End;
  CM_G_FLIPV: Begin PtBackup(P);For Y:=0 To PCH-1 Do For X:=0 To PCW-1 Do P^.Cv^[Y*PCW+X]:=P^.Un^[(PCH-1-Y)*PCW+X];P^.Modified:=True;End;
  CM_G_PLAIN: P^.FStyle:=0;
  CM_G_BOLD: P^.FStyle:=P^.FStyle Xor 1;
  CM_G_ITAL: P^.FStyle:=P^.FStyle Xor 2;
  CM_G_UNDER: P^.FStyle:=P^.FStyle Xor 4;
  CM_G_GRID: P^.Grid:=Not P^.Grid;
 Else
  If (Cmd>=CM_G_FONT) And (Cmd<CM_G_FONT+4) Then P^.FName:=Cmd-CM_G_FONT
  Else If (Cmd>=CM_G_SIZE) And (Cmd<CM_G_SIZE+6) Then P^.FSize:=Cmd-CM_G_SIZE
  Else If (Cmd>=CM_G_PAT) And (Cmd<CM_G_PAT+NPATS) Then P^.Pat:=Cmd-CM_G_PAT
  Else If (Cmd>=CM_G_LW) And (Cmd<CM_G_LW+4) Then P^.LW:=Array4(Cmd-CM_G_LW);
 End;
 Dirty:=True;
End;

Procedure PaintPrepare(W: PWindow);
Var P: PPaint; I: Integer;
Begin
 P:=W^.Data;
 For I:=0 To 3 Do MenuCheck(W,CM_G_FONT+I,P^.FName=I);
 For I:=0 To 5 Do MenuCheck(W,CM_G_SIZE+I,P^.FSize=I);
 MenuCheck(W,CM_G_PLAIN,P^.FStyle=0);MenuCheck(W,CM_G_BOLD,(P^.FStyle And 1)<>0);
 MenuCheck(W,CM_G_ITAL,(P^.FStyle And 2)<>0);MenuCheck(W,CM_G_UNDER,(P^.FStyle And 4)<>0);
 For I:=0 To NPATS-1 Do MenuCheck(W,CM_G_PAT+I,P^.Pat=I);
 For I:=0 To 3 Do MenuCheck(W,CM_G_LW+I,P^.LW=Array4(I));
 MenuDisable(W,CM_G_CUT,Not (P^.SelOn Or P^.HasFloat));MenuDisable(W,CM_G_COPY,Not (P^.SelOn Or P^.HasFloat));
End;

Procedure PaintKey(W: PWindow; K: Word);
Var P: PPaint;
Begin
 P:=W^.Data;
 Case K Of
  K_ALTBS: PaintMenu(W,CM_G_UNDO);
  K_DEL: PaintMenu(W,CM_G_CLEAR);
  3: PaintMenu(W,CM_G_COPY);
  24: PaintMenu(W,CM_G_CUT);
  22: PaintMenu(W,CM_G_PASTE);
  K_ESC: Begin PtCommitFloat(P);P^.SelOn:=False;Dirty:=True;End;
 End;
End;

Procedure PaintClose(W: PWindow);
Var P: PPaint;
Begin
 P:=W^.Data;
 PtClearSel(P);
 FreeMem(P^.Cv,PCSZ);FreeMem(P^.Un,PCSZ);
 Dispose(P);
End;

Function PaintCreate(Const Path: String): PWindow;
Var W: PWindow; P: PPaint; I: Integer;
Const Fonts: Array[0..3] Of String[10]=('Courier','Helv','Tms Rmn','Modern');
      Sizes: Array[0..5] Of String[3]=('8','10','12','14','18','24');
Begin
 W:=NewWindow(A_PAINT,'Paint - (untitled)',-1,-1,540,360,True);
 If W=Nil Then Begin PaintCreate:=Nil;Exit;End;
 New(P);FillChar(P^,SizeOf(TPaint),0);
 GetMem(P^.Cv,PCSZ);GetMem(P^.Un,PCSZ);
 P^.Tool:=2;P^.Pat:=0;P^.LW:=1;P^.FSize:=1;
 PaintNew(P);
 W^.Data:=P;W^.HasVS:=True;W^.HasHS:=True;
 WinAddMenu(W,'&File~&Fichier~&Datei');
 WinAddItem(W,'&New~&Nouveau~&Neu',CM_G_NEW,'');
 WinAddItem(W,'&Open...~&Ouvrir...~'#142'&ffnen...',CM_G_OPEN,'');
 WinAddItem(W,'&Save~&Enregistrer~&Speichern',CM_G_SAVE,'');
 WinAddItem(W,'Save &As...~Enregistrer &sous...~Speichern &unter...',CM_G_SAVEAS,'');
 WinAddItem(W,'&Print...~&Imprimer...~&Drucken...',CM_G_PRINT,'');
 WinAddItem(W,'E&xit~&Quitter~&Beenden',CM_G_EXIT,'');
 WinAddItem(W,'A&bout Paint...~&'#133' propos de Paint...~'#154'&ber Paint...',CM_G_ABOUT,'');
 WinAddMenu(W,'&Edit~&'#144'dition~&Bearbeiten');
 WinAddItem(W,'&Undo~&Annuler~&R'#129'ckg'#132'ngig',CM_G_UNDO,'Alt+BkSp');
 WinAddSep(W);
 WinAddItem(W,'Cu&t~Co&uper~&Ausschneiden',CM_G_CUT,'Ctrl+X');
 WinAddItem(W,'&Copy~&Copier~&Kopieren',CM_G_COPY,'Ctrl+Ins');
 WinAddItem(W,'&Paste~Co&ller~&Einf'#129'gen',CM_G_PASTE,'Ctrl+V');
 WinAddItem(W,'C&lear~E&facer~&L'#148'schen',CM_G_CLEAR,'Del');
 WinAddItem(W,'Select &All~&Tout s'#130'lectionner~&Alles ausw'#132'hlen',CM_G_ALL,'');
 WinAddSep(W);
 WinAddItem(W,'&Invert~&Inverser~&Invertieren',CM_G_INVERT,'');
 WinAddItem(W,'Flip &Horizontal~Retourner &horizontalement~&Horizontal spiegeln',CM_G_FLIPH,'');
 WinAddItem(W,'Flip &Vertical~Retourner &verticalement~&Vertikal spiegeln',CM_G_FLIPV,'');
 WinAddMenu(W,'&Character~&Caract'#138're~&Zeichen');
 For I:=0 To 3 Do WinAddItem(W,Fonts[I],CM_G_FONT+I,'');
 WinAddSep(W);
 WinAddItem(W,'&Plain~&Normal~&Normal',CM_G_PLAIN,'');
 WinAddItem(W,'&Bold~&Gras~&Fett',CM_G_BOLD,'');
 WinAddItem(W,'&Italic~&Italique~&Kursiv',CM_G_ITAL,'');
 WinAddItem(W,'&Underline~&Soulign'#130'~&Unterstrichen',CM_G_UNDER,'');
 WinAddMenu(W,'&Size~&Taille~&Gr'#148#225'e');
 For I:=0 To 5 Do WinAddItem(W,Sizes[I],CM_G_SIZE+I,'');
 WinAddMenu(W,'S&tyle~&Style~&Stil');
 For I:=0 To 3 Do WinAddItem(W,IntStr(Array4(I))+' pixel',CM_G_LW+I,'');
 WinAddMenu(W,'&Palette~&Palette~&Palette');
 For I:=0 To NPATS-1 Do WinAddItem(W,PatNames[I],CM_G_PAT+I,'');
 PaintTitle(W);
 If Path<>'' Then If PaintLoadMsp(P,Path) Then Begin P^.FileName:=Path;PaintTitle(W);End;
 PaintCreate:=W;
End;

{ ====================================================================== }
{          EMULATEUR 8086/80186 (Free Pascal) : COEUR DU PROCESSEUR      }
{ ====================================================================== }

{$IFDEF FPC}

Const
 SG_ES=0; SG_CS=1; SG_SS=2; SG_DS=3;
 R_AX=0; R_CX=1; R_DX=2; R_BX=3; R_SP=4; R_BP=5; R_SI=6; R_DI=7;
 ROMSEG = $F000;
 EMSSEG = $F100;

Var
 Mem   : PByteArr_;
 Rg    : Array[0..7] Of Word;
 Sg    : Array[0..3] Of Word;
 IPr   : Word;
 fCF,fPF,fAF,fZF,fSF,fOF,fDF,fIF,fTF : Boolean;
 Par   : Array[0..255] Of Boolean;
 SegOv : Integer;
 RepP  : Integer;
 EAddr : LongInt;
 EOff  : Word;
 ModReg: Integer;
 IsRegOp: Boolean;
 RMr   : Integer;
 CpuHalt,CpuBlock : Boolean;
 CpuErr: String[60];
 InstCnt: LongInt;
 PortRetrace: Integer;

Function Lin(S,O: Word): LongInt;
Begin
 Lin:=((LongInt(S) Shl 4)+O) And $FFFFF;
End;

Function RdB(A: LongInt): Byte;
Begin
 RdB:=Mem^[A And $FFFFF];
End;

Function RdW(A: LongInt): Word;
Begin
 RdW:=Mem^[A And $FFFFF] Or (Word(Mem^[(A+1) And $FFFFF]) Shl 8);
End;

Procedure WrB(A: LongInt; V: Byte);
Begin
 Mem^[A And $FFFFF]:=V;
End;

Procedure WrW(A: LongInt; V: Word);
Begin
 Mem^[A And $FFFFF]:=V And 255;
 Mem^[(A+1) And $FFFFF]:=V Shr 8;
End;

Function FetchB: Byte;
Begin
 FetchB:=Mem^[((LongInt(Sg[SG_CS]) Shl 4)+IPr) And $FFFFF];
 Inc(IPr);
End;

Function FetchW: Word;
Var L,H: Byte;
Begin
 L:=FetchB;H:=FetchB;
 FetchW:=L Or (Word(H) Shl 8);
End;

Procedure Push(V: Word);
Begin
 Dec(Rg[R_SP],2);
 WrW(Lin(Sg[SG_SS],Rg[R_SP]),V);
End;

Function Pop: Word;
Begin
 Pop:=RdW(Lin(Sg[SG_SS],Rg[R_SP]));
 Inc(Rg[R_SP],2);
End;

Function GetFlags: Word;
Begin
 GetFlags:=2 Or Ord(fCF) Or (Ord(fPF) Shl 2) Or (Ord(fAF) Shl 4) Or (Ord(fZF) Shl 6) Or
  (Ord(fSF) Shl 7) Or (Ord(fTF) Shl 8) Or (Ord(fIF) Shl 9) Or (Ord(fDF) Shl 10) Or (Ord(fOF) Shl 11);
End;

Procedure SetFlags(W: Word);
Begin
 fCF:=(W And 1)<>0;fPF:=(W And 4)<>0;fAF:=(W And 16)<>0;fZF:=(W And 64)<>0;
 fSF:=(W And 128)<>0;fTF:=(W And 256)<>0;fIF:=(W And 512)<>0;fDF:=(W And 1024)<>0;
 fOF:=(W And 2048)<>0;
End;

Function GetR8(I: Integer): Byte;
Begin
 If I<4 Then GetR8:=Rg[I] And 255 Else GetR8:=Rg[I-4] Shr 8;
End;

Procedure SetR8(I: Integer; V: Byte);
Begin
 If I<4 Then Rg[I]:=(Rg[I] And $FF00) Or V
 Else Rg[I-4]:=(Rg[I-4] And $00FF) Or (Word(V) Shl 8);
End;

{ ---------------- ModRM ---------------- }

Procedure DecodeModRM;
Var M,Md,Rm: Byte; Off: LongInt; Sgi: Integer; Disp: Integer;
Begin
 M:=FetchB;
 Md:=M Shr 6;ModReg:=(M Shr 3) And 7;Rm:=M And 7;RMr:=Rm;
 If Md=3 Then Begin IsRegOp:=True;Exit;End;
 IsRegOp:=False;
 Sgi:=SG_DS;
 Case Rm Of
  0: Off:=Rg[R_BX]+Rg[R_SI];
  1: Off:=Rg[R_BX]+Rg[R_DI];
  2: Begin Off:=Rg[R_BP]+Rg[R_SI];Sgi:=SG_SS;End;
  3: Begin Off:=Rg[R_BP]+Rg[R_DI];Sgi:=SG_SS;End;
  4: Off:=Rg[R_SI];
  5: Off:=Rg[R_DI];
  6: Begin Off:=Rg[R_BP];Sgi:=SG_SS;End;
 Else Off:=Rg[R_BX];
 End;
 If (Md=0) And (Rm=6) Then Begin Off:=FetchW;Sgi:=SG_DS;End
 Else If Md=1 Then Begin Disp:=ShortInt(FetchB);Off:=Off+Disp;End
 Else If Md=2 Then Begin Disp:=SmallInt(FetchW);Off:=Off+Disp;End;
 If SegOv>=0 Then Sgi:=SegOv;
 EOff:=Word(Off);
 EAddr:=Lin(Sg[Sgi],Word(Off));
End;

Function RdRM8: Byte;
Begin
 If IsRegOp Then RdRM8:=GetR8(RMr) Else RdRM8:=RdB(EAddr);
End;

Function RdRM16: Word;
Begin
 If IsRegOp Then RdRM16:=Rg[RMr] Else RdRM16:=RdW(EAddr);
End;

Procedure WrRM8(V: Byte);
Begin
 If IsRegOp Then SetR8(RMr,V) Else WrB(EAddr,V);
End;

Procedure WrRM16(V: Word);
Begin
 If IsRegOp Then Rg[RMr]:=V Else WrW(EAddr,V);
End;

{ ---------------- ALU ---------------- }

Function AluOp(Op: Integer; A,B: LongInt; Wide: Boolean): LongInt;
Var Mask,Sign,Rs,C: LongInt;
Begin
 If Wide Then Begin Mask:=$FFFF;Sign:=$8000;End Else Begin Mask:=$FF;Sign:=$80;End;
 Rs:=0;
 Case Op Of
  0,2: Begin
    C:=0;If (Op=2) And fCF Then C:=1;
    Rs:=A+B+C;fCF:=Rs>Mask;Rs:=Rs And Mask;
    fAF:=((A Xor B Xor Rs) And $10)<>0;
    fOF:=((A Xor Rs) And (B Xor Rs) And Sign)<>0;
   End;
  3,5,7: Begin
    C:=0;If (Op=3) And fCF Then C:=1;
    Rs:=A-B-C;fCF:=Rs<0;Rs:=Rs And Mask;
    fAF:=((A Xor B Xor Rs) And $10)<>0;
    fOF:=((A Xor B) And (A Xor Rs) And Sign)<>0;
   End;
  1: Begin Rs:=A Or B;fCF:=False;fOF:=False;fAF:=False;End;
  4: Begin Rs:=A And B;fCF:=False;fOF:=False;fAF:=False;End;
  6: Begin Rs:=A Xor B;fCF:=False;fOF:=False;fAF:=False;End;
 End;
 fZF:=(Rs And Mask)=0;fSF:=(Rs And Sign)<>0;fPF:=Par[Rs And $FF];
 AluOp:=Rs;
End;

Function IncDec(V: LongInt; Dec_,Wide: Boolean): LongInt;
Var Sv: Boolean;
Begin
 Sv:=fCF;
 If Dec_ Then IncDec:=AluOp(5,V,1,Wide) Else IncDec:=AluOp(0,V,1,Wide);
 fCF:=Sv;
End;

Function ShiftOp(Op: Integer; V: LongInt; Cnt: Integer; Wide: Boolean): LongInt;
Var Mask,Sign: LongInt; I: Integer; C,Old: Boolean; Cin: Integer;
Begin
 If Cnt=0 Then Begin ShiftOp:=V;Exit;End;
 If Wide Then Begin Mask:=$FFFF;Sign:=$8000;End Else Begin Mask:=$FF;Sign:=$80;End;
 Old:=(V And Sign)<>0;
 For I:=1 To Cnt Do Begin
  Case Op Of
   0: Begin C:=(V And Sign)<>0;V:=((V Shl 1) Or Ord(C)) And Mask;fCF:=C;End;
   1: Begin C:=(V And 1)<>0;V:=(V Shr 1);If C Then V:=V Or Sign;fCF:=C;End;
   2: Begin C:=(V And Sign)<>0;Cin:=Ord(fCF);V:=((V Shl 1) Or Cin) And Mask;fCF:=C;End;
   3: Begin C:=(V And 1)<>0;Cin:=Ord(fCF);V:=V Shr 1;If Cin=1 Then V:=V Or Sign;fCF:=C;End;
   4,6: Begin fCF:=(V And Sign)<>0;V:=(V Shl 1) And Mask;End;
   5: Begin fCF:=(V And 1)<>0;V:=V Shr 1;End;
  Else Begin fCF:=(V And 1)<>0;V:=(V Shr 1) Or (V And Sign);End;
  End;
 End;
 Case Op Of
  0,2: fOF:=((V And Sign)<>0)<>fCF;
  1,3: fOF:=((V And Sign)<>0)<>((V And (Sign Shr 1))<>0);
  4,6: fOF:=((V And Sign)<>0)<>fCF;
  5: fOF:=Old;
 Else fOF:=False;
 End;
 If Op>=4 Then Begin fZF:=(V And Mask)=0;fSF:=(V And Sign)<>0;fPF:=Par[V And $FF];End;
 ShiftOp:=V And Mask;
End;

Function Cond(C: Integer): Boolean;
Var R: Boolean;
Begin
 Case C Shr 1 Of
  0: R:=fOF;
  1: R:=fCF;
  2: R:=fZF;
  3: R:=fCF Or fZF;
  4: R:=fSF;
  5: R:=fPF;
  6: R:=fSF<>fOF;
 Else R:=fZF Or (fSF<>fOF);
 End;
 If (C And 1)<>0 Then R:=Not R;
 Cond:=R;
End;

Procedure HleInt(N: Integer); Forward;
Procedure HleW16(N: Integer); Forward;
Function PortIn(P: Word; Wide: Boolean): Word; Forward;
Procedure PortOut(P: Word; V: Word; Wide: Boolean); Forward;

{ Interruption logicielle ou materielle }
Var ErrF: File; ErrI: Integer;

Procedure DoInterrupt(N: Integer);
Var Vo,Vs: Word;
Begin
 Vo:=RdW(N*4);Vs:=RdW(N*4+2);
 If (Vs=ROMSEG) And (Vo<1024) Then Begin HleInt(Vo Div 4);Exit;End;
 If (Vs=EMSSEG) And (Vo=0) Then Begin HleInt($67);Exit;End;
 Push(GetFlags);Push(Sg[SG_CS]);Push(IPr);
 fIF:=False;fTF:=False;
 IPr:=Vo;Sg[SG_CS]:=Vs;
End;

Procedure DivError;
Begin
 DoInterrupt(0);
End;

Procedure MulDiv8(Op: Integer; V: LongInt);
Var A,Q,R: LongInt; S: LongInt;
Begin
 Case Op Of
  4: Begin A:=(Rg[R_AX] And 255)*V;Rg[R_AX]:=A;fCF:=(A Shr 8)<>0;fOF:=fCF;End;
  5: Begin A:=ShortInt(Rg[R_AX] And 255)*ShortInt(V);Rg[R_AX]:=Word(A);
      fCF:=(A<-128) Or (A>127);fOF:=fCF;End;
  6: Begin
      If V=0 Then Begin DivError;Exit;End;
      A:=Rg[R_AX];Q:=A Div V;R:=A Mod V;
      If Q>255 Then Begin DivError;Exit;End;
      Rg[R_AX]:=Q Or (R Shl 8);
     End;
  7: Begin
      If V=0 Then Begin DivError;Exit;End;
      A:=SmallInt(Rg[R_AX]);S:=ShortInt(V);
      Q:=A Div S;R:=A Mod S;
      If (Q>127) Or (Q<-128) Then Begin DivError;Exit;End;
      Rg[R_AX]:=(Q And 255) Or ((R And 255) Shl 8);
     End;
 End;
End;

Procedure MulDiv16(Op: Integer; V: LongInt);
Var A,Q,R,S: LongInt; D: Int64;
Begin
 Case Op Of
  4: Begin A:=LongInt(Rg[R_AX])*V;Rg[R_AX]:=A And $FFFF;Rg[R_DX]:=(A Shr 16) And $FFFF;
      fCF:=Rg[R_DX]<>0;fOF:=fCF;End;
  5: Begin A:=LongInt(SmallInt(Rg[R_AX]))*SmallInt(V);
      Rg[R_AX]:=A And $FFFF;Rg[R_DX]:=(A Shr 16) And $FFFF;
      fCF:=(A<-32768) Or (A>32767);fOF:=fCF;End;
  6: Begin
      If V=0 Then Begin DivError;Exit;End;
      D:=(Int64(Rg[R_DX]) Shl 16) Or Rg[R_AX];
      Q:=D Div V;R:=D Mod V;
      If D Div V>65535 Then Begin DivError;Exit;End;
      Rg[R_AX]:=Q;Rg[R_DX]:=R;
     End;
  7: Begin
      If V=0 Then Begin DivError;Exit;End;
      D:=LongInt((LongWord(Rg[R_DX]) Shl 16) Or Rg[R_AX]);
      S:=SmallInt(V);
      Q:=D Div S;R:=D Mod S;
      If (D Div S>32767) Or (D Div S<-32768) Then Begin DivError;Exit;End;
      Rg[R_AX]:=Q And $FFFF;Rg[R_DX]:=R And $FFFF;
     End;
 End;
End;

Function SrcSeg: Word;
Begin
 If SegOv>=0 Then SrcSeg:=Sg[SegOv] Else SrcSeg:=Sg[SG_DS];
End;

{ Instruction chaine : Kind 0 MOVS 1 CMPS 2 STOS 3 LODS 4 SCAS }
Procedure StringOp(Kind: Integer; Wide: Boolean);
Var Delta: Integer; A,B: LongInt; Cnt: LongInt; Zf: Boolean; Done: Boolean;
Begin
 If Wide Then Delta:=2 Else Delta:=1;
 If fDF Then Delta:=-Delta;
 Done:=False;
 Repeat
  If RepP<>0 Then Begin
   If Rg[R_CX]=0 Then Break;
  End;
  Case Kind Of
   0: Begin
       If Wide Then WrW(Lin(Sg[SG_ES],Rg[R_DI]),RdW(Lin(SrcSeg,Rg[R_SI])))
       Else WrB(Lin(Sg[SG_ES],Rg[R_DI]),RdB(Lin(SrcSeg,Rg[R_SI])));
       Inc(Rg[R_SI],Delta);Inc(Rg[R_DI],Delta);
      End;
   1: Begin
       If Wide Then Begin A:=RdW(Lin(SrcSeg,Rg[R_SI]));B:=RdW(Lin(Sg[SG_ES],Rg[R_DI]));End
       Else Begin A:=RdB(Lin(SrcSeg,Rg[R_SI]));B:=RdB(Lin(Sg[SG_ES],Rg[R_DI]));End;
       AluOp(7,A,B,Wide);
       Inc(Rg[R_SI],Delta);Inc(Rg[R_DI],Delta);
      End;
   2: Begin
       If Wide Then WrW(Lin(Sg[SG_ES],Rg[R_DI]),Rg[R_AX]) Else WrB(Lin(Sg[SG_ES],Rg[R_DI]),Rg[R_AX] And 255);
       Inc(Rg[R_DI],Delta);
      End;
   3: Begin
       If Wide Then Rg[R_AX]:=RdW(Lin(SrcSeg,Rg[R_SI]))
       Else Rg[R_AX]:=(Rg[R_AX] And $FF00) Or RdB(Lin(SrcSeg,Rg[R_SI]));
       Inc(Rg[R_SI],Delta);
      End;
   4: Begin
       If Wide Then Begin A:=Rg[R_AX];B:=RdW(Lin(Sg[SG_ES],Rg[R_DI]));End
       Else Begin A:=Rg[R_AX] And 255;B:=RdB(Lin(Sg[SG_ES],Rg[R_DI]));End;
       AluOp(7,A,B,Wide);
       Inc(Rg[R_DI],Delta);
      End;
  End;
  If RepP=0 Then Break;
  Dec(Rg[R_CX]);
  If (Kind=1) Or (Kind=4) Then Begin
   If (RepP=1) And Not fZF Then Break;
   If (RepP=2) And fZF Then Break;
  End;
 Until False;
End;

{ ---------------- instruction ---------------- }

Procedure CpuStep;
Var Op,B1: Byte; W1,W2: Word; L1,L2: LongInt; I: Integer; T: Boolean;
    StartIP: Word; Pref: Boolean;
Begin
 If Sg[SG_CS]=ROMSEG Then Begin
  If IPr<1024 Then Begin
   { appel d'un gestionnaire ROM : emulation puis retour }
   I:=IPr Div 4;
   HleInt(I);
   If Not CpuBlock Then Begin IPr:=Pop;Sg[SG_CS]:=Pop;W1:=Pop;End;
   Exit;
  End Else If (IPr>=$400) And (IPr<$1800) Then Begin
   { appel d'une fonction KERNEL/USER/GDI de Windows 2.x (RETF n) }
   HleW16(IPr-$400);
   Exit;
  End;
 End;
 SegOv:=-1;RepP:=0;
 StartIP:=IPr;
 Repeat
  Pref:=True;
  Op:=FetchB;
  Case Op Of
   $26: SegOv:=SG_ES;
   $2E: SegOv:=SG_CS;
   $36: SegOv:=SG_SS;
   $3E: SegOv:=SG_DS;
   $F0: ;
   $F2: RepP:=2;
   $F3: RepP:=1;
  Else Pref:=False;
  End;
 Until Not Pref;
 Case Op Of
  $00..$3F: Begin
    I:=Op And 7;
    If I<6 Then Begin
     B1:=(Op Shr 3) And 7;
     Case I Of
      0: Begin DecodeModRM;L1:=AluOp(B1,RdRM8,GetR8(ModReg),False);If B1<>7 Then WrRM8(L1);End;
      1: Begin DecodeModRM;L1:=AluOp(B1,RdRM16,Rg[ModReg],True);If B1<>7 Then WrRM16(L1);End;
      2: Begin DecodeModRM;L1:=AluOp(B1,GetR8(ModReg),RdRM8,False);If B1<>7 Then SetR8(ModReg,L1);End;
      3: Begin DecodeModRM;L1:=AluOp(B1,Rg[ModReg],RdRM16,True);If B1<>7 Then Rg[ModReg]:=L1;End;
      4: Begin L1:=AluOp(B1,Rg[R_AX] And 255,FetchB,False);If B1<>7 Then SetR8(0,L1);End;
      5: Begin W1:=FetchW;L1:=AluOp(B1,Rg[R_AX],W1,True);If B1<>7 Then Rg[R_AX]:=L1;End;
     End;
    End Else Case Op Of
     $06: Push(Sg[SG_ES]); $0E: Push(Sg[SG_CS]); $16: Push(Sg[SG_SS]); $1E: Push(Sg[SG_DS]);
     $07: Sg[SG_ES]:=Pop; $17: Sg[SG_SS]:=Pop; $1F: Sg[SG_DS]:=Pop;
     $0F: Begin
       B1:=FetchB;
       Case B1 Of
        $80..$8F: Begin W1:=FetchW;If Cond(B1-$80) Then IPr:=IPr+W1;End;
        $90..$9F: Begin DecodeModRM;WrRM8(Ord(Cond(B1-$90)));End;
        $AF: Begin DecodeModRM;L2:=LongInt(SmallInt(Rg[ModReg]))*SmallInt(RdRM16);Rg[ModReg]:=L2 And $FFFF;
              fCF:=(L2<-32768) Or (L2>32767);fOF:=fCF;End;
        $B6: Begin DecodeModRM;Rg[ModReg]:=RdRM8;End;
        $BE: Begin DecodeModRM;Rg[ModReg]:=Word(SmallInt(ShortInt(RdRM8)));End;
       Else Begin
         CpuHalt:=True;
         CpuErr:='Invalid opcode 0F '+HexStr(B1,2)+' at '+HexStr(Sg[SG_CS],4)+':'+HexStr(StartIP,4);
        End;
       End;
      End;
     $27: Begin { DAA }
       B1:=Rg[R_AX] And 255;T:=fCF;
       If ((B1 And $F)>9) Or fAF Then Begin B1:=B1+6;fAF:=True;End Else fAF:=False;
       If (Rg[R_AX] And 255>$99) Or T Then Begin B1:=B1+$60;fCF:=True;End Else fCF:=False;
       SetR8(0,B1);fZF:=B1=0;fSF:=(B1 And $80)<>0;fPF:=Par[B1];
      End;
     $2F: Begin { DAS }
       B1:=Rg[R_AX] And 255;T:=fCF;
       If ((B1 And $F)>9) Or fAF Then Begin B1:=B1-6;fAF:=True;End Else fAF:=False;
       If (Rg[R_AX] And 255>$99) Or T Then Begin B1:=B1-$60;fCF:=True;End Else fCF:=False;
       SetR8(0,B1);fZF:=B1=0;fSF:=(B1 And $80)<>0;fPF:=Par[B1];
      End;
     $37: Begin { AAA }
       If ((Rg[R_AX] And $F)>9) Or fAF Then Begin Rg[R_AX]:=Rg[R_AX]+$106;fAF:=True;fCF:=True;End Else Begin fAF:=False;fCF:=False;End;
       Rg[R_AX]:=Rg[R_AX] And $FF0F;
      End;
     $3F: Begin { AAS }
       If ((Rg[R_AX] And $F)>9) Or fAF Then Begin Rg[R_AX]:=Rg[R_AX]-6;Rg[R_AX]:=Rg[R_AX]-$100;fAF:=True;fCF:=True;End Else Begin fAF:=False;fCF:=False;End;
       Rg[R_AX]:=Rg[R_AX] And $FF0F;
      End;
    End;
   End;
  $40..$47: Rg[Op-$40]:=IncDec(Rg[Op-$40],False,True);
  $48..$4F: Rg[Op-$48]:=IncDec(Rg[Op-$48],True,True);
  $50..$57: Begin If Op=$54 Then Begin Dec(Rg[R_SP],2);WrW(Lin(Sg[SG_SS],Rg[R_SP]),Rg[R_SP]);End Else Push(Rg[Op-$50]);End;
  $58..$5F: Begin W1:=Pop;Rg[Op-$58]:=W1;End;
  $60: Begin W1:=Rg[R_SP];Push(Rg[R_AX]);Push(Rg[R_CX]);Push(Rg[R_DX]);Push(Rg[R_BX]);Push(W1);Push(Rg[R_BP]);Push(Rg[R_SI]);Push(Rg[R_DI]);End;
  $61: Begin Rg[R_DI]:=Pop;Rg[R_SI]:=Pop;Rg[R_BP]:=Pop;W1:=Pop;Rg[R_BX]:=Pop;Rg[R_DX]:=Pop;Rg[R_CX]:=Pop;Rg[R_AX]:=Pop;End;
  $62: Begin DecodeModRM;End;
  $68: Push(FetchW);
  $69,$6B: Begin
    DecodeModRM;W1:=RdRM16;
    If Op=$69 Then L1:=SmallInt(FetchW) Else L1:=ShortInt(FetchB);
    L2:=LongInt(SmallInt(W1))*L1;Rg[ModReg]:=L2 And $FFFF;
    fCF:=(L2<-32768) Or (L2>32767);fOF:=fCF;
   End;
  $6A: Push(Word(SmallInt(ShortInt(FetchB))));
  $6C..$6F: Begin
    If RepP=0 Then I:=1 Else I:=Rg[R_CX];
    If RepP<>0 Then Rg[R_CX]:=0;
    While I>0 Do Begin
     Case Op Of
      $6C: Begin WrB(Lin(Sg[SG_ES],Rg[R_DI]),PortIn(Rg[R_DX],False) And 255);Inc(Rg[R_DI]);End;
      $6D: Begin WrW(Lin(Sg[SG_ES],Rg[R_DI]),PortIn(Rg[R_DX],True));Inc(Rg[R_DI],2);End;
      $6E: Begin PortOut(Rg[R_DX],RdB(Lin(SrcSeg,Rg[R_SI])),False);Inc(Rg[R_SI]);End;
      $6F: Begin PortOut(Rg[R_DX],RdW(Lin(SrcSeg,Rg[R_SI])),True);Inc(Rg[R_SI],2);End;
     End;
     Dec(I);
    End;
   End;
  $70..$7F: Begin
    B1:=FetchB;
    If Cond(Op-$70) Then IPr:=IPr+ShortInt(B1);
   End;
  $80..$83: Begin
    DecodeModRM;
    If Op=$80 Then Begin L1:=RdRM8;L2:=FetchB;L1:=AluOp(ModReg,L1,L2,False);If ModReg<>7 Then WrRM8(L1);End
    Else Begin
     L1:=RdRM16;
     If Op=$81 Then L2:=FetchW Else L2:=Word(SmallInt(ShortInt(FetchB)));
     L1:=AluOp(ModReg,L1,L2,True);If ModReg<>7 Then WrRM16(L1);
    End;
   End;
  $84: Begin DecodeModRM;AluOp(4,RdRM8,GetR8(ModReg),False);End;
  $85: Begin DecodeModRM;AluOp(4,RdRM16,Rg[ModReg],True);End;
  $86: Begin DecodeModRM;B1:=RdRM8;WrRM8(GetR8(ModReg));SetR8(ModReg,B1);End;
  $87: Begin DecodeModRM;W1:=RdRM16;WrRM16(Rg[ModReg]);Rg[ModReg]:=W1;End;
  $88: Begin DecodeModRM;WrRM8(GetR8(ModReg));End;
  $89: Begin DecodeModRM;WrRM16(Rg[ModReg]);End;
  $8A: Begin DecodeModRM;SetR8(ModReg,RdRM8);End;
  $8B: Begin DecodeModRM;Rg[ModReg]:=RdRM16;End;
  $8C: Begin DecodeModRM;WrRM16(Sg[ModReg And 3]);End;
  $8D: Begin DecodeModRM;If Not IsRegOp Then Rg[ModReg]:=EOff;End;
  $8E: Begin DecodeModRM;Sg[ModReg And 3]:=RdRM16;End;
  $8F: Begin DecodeModRM;W1:=Pop;WrRM16(W1);End;
  $90: ;
  $91..$97: Begin W1:=Rg[R_AX];Rg[R_AX]:=Rg[Op-$90];Rg[Op-$90]:=W1;End;
  $98: If (Rg[R_AX] And $80)<>0 Then Rg[R_AX]:=Rg[R_AX] Or $FF00 Else Rg[R_AX]:=Rg[R_AX] And $FF;
  $99: If (Rg[R_AX] And $8000)<>0 Then Rg[R_DX]:=$FFFF Else Rg[R_DX]:=0;
  $9A: Begin W1:=FetchW;W2:=FetchW;Push(Sg[SG_CS]);Push(IPr);IPr:=W1;Sg[SG_CS]:=W2;End;
  $9B: ;
  $9C: Push(GetFlags);
  $9D: SetFlags(Pop);
  $9E: Begin W1:=(GetFlags And $FF00) Or (Rg[R_AX] Shr 8);SetFlags(W1);End;
  $9F: Rg[R_AX]:=(Rg[R_AX] And $FF) Or (Word(GetFlags And $FF) Shl 8);
  $A0: Begin W1:=FetchW;SetR8(0,RdB(Lin(SrcSeg,W1)));End;
  $A1: Begin W1:=FetchW;Rg[R_AX]:=RdW(Lin(SrcSeg,W1));End;
  $A2: Begin W1:=FetchW;WrB(Lin(SrcSeg,W1),Rg[R_AX] And 255);End;
  $A3: Begin W1:=FetchW;WrW(Lin(SrcSeg,W1),Rg[R_AX]);End;
  $A4: StringOp(0,False); $A5: StringOp(0,True);
  $A6: StringOp(1,False); $A7: StringOp(1,True);
  $A8: AluOp(4,Rg[R_AX] And 255,FetchB,False);
  $A9: AluOp(4,Rg[R_AX],FetchW,True);
  $AA: StringOp(2,False); $AB: StringOp(2,True);
  $AC: StringOp(3,False); $AD: StringOp(3,True);
  $AE: StringOp(4,False); $AF: StringOp(4,True);
  $B0..$B7: SetR8(Op-$B0,FetchB);
  $B8..$BF: Rg[Op-$B8]:=FetchW;
  $C0,$C1,$D0..$D3: Begin
    DecodeModRM;
    If (Op=$C0) Or (Op=$C1) Then I:=FetchB
    Else If (Op=$D0) Or (Op=$D1) Then I:=1 Else I:=Rg[R_CX] And 255;
    If Odd(Op) Then WrRM16(ShiftOp(ModReg,RdRM16,I,True))
    Else WrRM8(ShiftOp(ModReg,RdRM8,I,False));
   End;
  $C2: Begin W1:=FetchW;IPr:=Pop;Inc(Rg[R_SP],W1);End;
  $C3: IPr:=Pop;
  $C4,$C5: Begin
    DecodeModRM;
    If Not IsRegOp Then Begin
     Rg[ModReg]:=RdW(EAddr);
     If Op=$C4 Then Sg[SG_ES]:=RdW(EAddr+2) Else Sg[SG_DS]:=RdW(EAddr+2);
    End;
   End;
  $C6: Begin DecodeModRM;WrRM8(FetchB);End;
  $C7: Begin DecodeModRM;WrRM16(FetchW);End;
  $C8: Begin
    W1:=FetchW;B1:=FetchB;
    Push(Rg[R_BP]);L1:=Rg[R_SP];
    If B1>0 Then For I:=1 To B1-1 Do Begin Dec(Rg[R_BP],2);Push(RdW(Lin(Sg[SG_SS],Rg[R_BP])));End;
    If B1>0 Then Push(L1);
    Rg[R_BP]:=L1;Rg[R_SP]:=Rg[R_SP]-W1;
   End;
  $C9: Begin Rg[R_SP]:=Rg[R_BP];Rg[R_BP]:=Pop;End;
  $CA: Begin W1:=FetchW;IPr:=Pop;Sg[SG_CS]:=Pop;Inc(Rg[R_SP],W1);End;
  $CB: Begin IPr:=Pop;Sg[SG_CS]:=Pop;End;
  $CC: DoInterrupt(3);
  $CD: Begin
    B1:=FetchB;
    DoInterrupt(B1);
    If CpuBlock Then Begin IPr:=StartIP;End;
   End;
  $CE: If fOF Then DoInterrupt(4);
  $CF: Begin IPr:=Pop;Sg[SG_CS]:=Pop;SetFlags(Pop);End;
  $D4: Begin B1:=FetchB;If B1=0 Then DivError Else Begin I:=Rg[R_AX] And 255;Rg[R_AX]:=(I Div B1) Shl 8 Or (I Mod B1);
     fZF:=(Rg[R_AX] And 255)=0;fSF:=(Rg[R_AX] And $80)<>0;fPF:=Par[Rg[R_AX] And 255];End;End;
  $D5: Begin B1:=FetchB;I:=((Rg[R_AX] Shr 8)*B1+(Rg[R_AX] And 255)) And 255;Rg[R_AX]:=I;
     fZF:=I=0;fSF:=(I And $80)<>0;fPF:=Par[I];End;
  $D6: Begin If fCF Then SetR8(0,$FF) Else SetR8(0,0);End;
  $D7: SetR8(0,RdB(Lin(SrcSeg,Word(Rg[R_BX]+(Rg[R_AX] And 255)))));
  $D8..$DF: Begin DecodeModRM;End;
  $E0: Begin B1:=FetchB;Dec(Rg[R_CX]);If (Rg[R_CX]<>0) And Not fZF Then IPr:=IPr+ShortInt(B1);End;
  $E1: Begin B1:=FetchB;Dec(Rg[R_CX]);If (Rg[R_CX]<>0) And fZF Then IPr:=IPr+ShortInt(B1);End;
  $E2: Begin B1:=FetchB;Dec(Rg[R_CX]);If Rg[R_CX]<>0 Then IPr:=IPr+ShortInt(B1);End;
  $E3: Begin B1:=FetchB;If Rg[R_CX]=0 Then IPr:=IPr+ShortInt(B1);End;
  $E4: Begin B1:=FetchB;SetR8(0,PortIn(B1,False));End;
  $E5: Begin B1:=FetchB;Rg[R_AX]:=PortIn(B1,True);End;
  $E6: Begin B1:=FetchB;PortOut(B1,Rg[R_AX] And 255,False);End;
  $E7: Begin B1:=FetchB;PortOut(B1,Rg[R_AX],True);End;
  $E8: Begin W1:=FetchW;Push(IPr);IPr:=IPr+W1;End;
  $E9: Begin W1:=FetchW;IPr:=IPr+W1;End;
  $EA: Begin W1:=FetchW;W2:=FetchW;IPr:=W1;Sg[SG_CS]:=W2;End;
  $EB: Begin B1:=FetchB;IPr:=IPr+ShortInt(B1);End;
  $EC: SetR8(0,PortIn(Rg[R_DX],False));
  $ED: Rg[R_AX]:=PortIn(Rg[R_DX],True);
  $EE: PortOut(Rg[R_DX],Rg[R_AX] And 255,False);
  $EF: PortOut(Rg[R_DX],Rg[R_AX],True);
  $F4: Begin CpuBlock:=True;IPr:=StartIP;End;   { HLT : attend }
  $F5: fCF:=Not fCF;
  $F6,$F7: Begin
    DecodeModRM;
    Case ModReg Of
     0,1: If Op=$F6 Then AluOp(4,RdRM8,FetchB,False) Else AluOp(4,RdRM16,FetchW,True);
     2: If Op=$F6 Then WrRM8(Not RdRM8) Else WrRM16(Not RdRM16);
     3: If Op=$F6 Then Begin L1:=AluOp(5,0,RdRM8,False);WrRM8(L1);fCF:=L1<>0;End
        Else Begin L1:=AluOp(5,0,RdRM16,True);WrRM16(L1);fCF:=L1<>0;End;
    Else If Op=$F6 Then MulDiv8(ModReg,RdRM8) Else MulDiv16(ModReg,RdRM16);
    End;
   End;
  $F8: fCF:=False; $F9: fCF:=True; $FA: fIF:=False; $FB: fIF:=True;
  $FC: fDF:=False; $FD: fDF:=True;
  $FE: Begin
    DecodeModRM;
    If ModReg=0 Then WrRM8(IncDec(RdRM8,False,False)) Else If ModReg=1 Then WrRM8(IncDec(RdRM8,True,False));
   End;
  $FF: Begin
    DecodeModRM;
    Case ModReg Of
     0: WrRM16(IncDec(RdRM16,False,True));
     1: WrRM16(IncDec(RdRM16,True,True));
     2: Begin W1:=RdRM16;Push(IPr);IPr:=W1;End;
     3: If Not IsRegOp Then Begin W1:=RdW(EAddr);W2:=RdW(EAddr+2);Push(Sg[SG_CS]);Push(IPr);IPr:=W1;Sg[SG_CS]:=W2;End;
     4: IPr:=RdRM16;
     5: If Not IsRegOp Then Begin W1:=RdW(EAddr);W2:=RdW(EAddr+2);IPr:=W1;Sg[SG_CS]:=W2;End;
     6: Begin W1:=RdRM16;Push(W1);End;
    End;
   End;
 Else Begin
   CpuHalt:=True;
   CpuErr:='Invalid opcode '+HexStr(Op,2)+' at '+HexStr(Sg[SG_CS],4)+':'+HexStr(StartIP,4);
   If TraceOn Then Begin For ErrI:=1023 Downto 0 Do WriteLn(TraceF,'ERRRING ',HexStr(Ring[(RingP-ErrI) And 1023] Shr 16,4),':',HexStr(Ring[(RingP-ErrI) And 1023] And $FFFF,4));WriteLn(TraceF,'ERRSTACK ',HexStr(Sg[SG_SS],4),':',HexStr(Rg[R_SP],4),' BP=',HexStr(Rg[R_BP],4));For ErrI:=0 To 31 Do Write(TraceF,' ',HexStr(RdW(Lin(Sg[SG_SS],Rg[R_SP]+ErrI*2)),4));WriteLn(TraceF);Flush(TraceF);End;
   If GetEnv('W2TRACE')<>'' Then Begin Assign(ErrF,GetEnv('W2TRACE')+'.err');Rewrite(ErrF,1);BlockWrite(ErrF,Mem^[0],$A0000);Close(ErrF);End;
  End;
 End;
End;

Procedure InitParity;
Var I,N,K: Integer;
Begin
 For I:=0 To 255 Do Begin
  N:=0;
  For K:=0 To 7 Do If (I Shr K) And 1=1 Then Inc(N);
  Par[I]:=(N And 1)=0;
 End;
End;

{$ENDIF}

{ ====================================================================== }
{          EMULATEUR DOS : MACHINE VIRTUELLE, BIOS ET INT 21h            }
{ ====================================================================== }

{$IFDEF FPC}

Const
 MAXFH = 20;
 MAXBLK = 40;
 MAXCTX = 6;
 VGA_BASE = $A0000;
 TXT_BASE = $B8000;

Type
 TDosFile = Record
  Used  : Boolean;
  Dev   : Byte;           { 0 fichier, 1 console, 2 NUL, 3 imprimante }
  F     : File;
  Name  : String[100];
  Owner : Word;
  Pos0  : LongInt;
 End;

 TFindRec = Record
  Used : Boolean;
  SR   : SearchRec;
  Pat  : String[14];
  Attr : Byte;
 End;

 TBlk = Record
  Seg,Size : Word;       { Size en paragraphes ; Owner=0 : libre }
  Owner    : Word;
 End;

 TCtx = Record
  Rg : Array[0..7] Of Word;
  Sg : Array[0..3] Of Word;
  IP : Word;
  Fl : Word;
  PSP: Word;
  DTA: LongInt;
 End;

 PVM = ^TVM;
 TVM = Record
  Mem  : PByteArr_;
  Rg   : Array[0..7] Of Word;
  Sg   : Array[0..3] Of Word;
  IP   : Word;
  Fl   : Word;
  Running : Boolean;
  Dead : Boolean;
  LastExit : Word;
  CurDir : String[100];
  DTA  : LongInt;
  PSP  : Word;
  Files: Array[0..MAXFH-1] Of TDosFile;
  Finds: Array[0..7] Of TFindRec;
  Blk  : Array[1..MAXBLK] Of TBlk;
  NBlk : Integer;
  Ctx  : Array[1..MAXCTX] Of TCtx;
  NCtx : Integer;
  KQ   : Array[0..63] Of Word;
  KH,KT: Integer;
  Mode : Byte;
  GfxFull : Boolean;
  Pal  : Array[0..255,0..2] Of Byte;
  Lut  : Array[0..255] Of Byte;
  DacW,DacR,DacPh,DacPhR : Integer;
  PalDirty : Boolean;
  Pix  : PByteArr_;
  MouseX,MouseY,MouseB : Integer;
  ScanLast : Byte;
  LastTick : LongInt;
  CrtcIdx : Byte;
  Crtc : Array[0..31] Of Byte;
  { INT 21h/0Ah et stdin }
  LnBuf : String[255];
  LnActive : Boolean;
  LnMax : Integer;
  StdinLn : String[255];
  StdinPos : Integer;
  { shell }
  ShLine : String[126];
  ShPos  : Integer;
  Hist   : Array[1..16] Of String[126];
  NHist,HistPos : Integer;
  Echo   : Boolean;
  EnvVars: Array[1..32] Of String[120];
  NEnv   : Integer;
  Batch  : Array[1..60] Of String[120];
  NBatch,BatchPos : Integer;
  BatchArgs : Array[0..9] Of String[60];
  InBatch: Boolean;
  Pause  : Boolean;
  Wnd    : PWindow;
  Title  : String[40];
  ExitClose : Boolean;
  InstTot: Int64;
  IdleSince: LongInt;
  NeedPrompt: Boolean;
  Ticks0: LongInt;
  W16 : Pointer;
 End;

Var
 CV : PVM;
 VgaRGB8 : Array[0..15,0..2] Of Byte;

{ ---------------- palette ---------------- }

Procedure VMDefaultPalette(V: PVM);
Var I,K,G,H: Integer; R,Gg,B: Integer;
Begin
 For I:=0 To 15 Do Begin
  V^.Pal[I,0]:=VgaRGB[I,0] Div 4;V^.Pal[I,1]:=VgaRGB[I,1] Div 4;V^.Pal[I,2]:=VgaRGB[I,2] Div 4;
 End;
 { EGA : la palette 6..14 de BIOS differe : on garde la palette VGA ci-dessus }
 For I:=16 To 31 Do Begin K:=(I-16)*63 Div 15;V^.Pal[I,0]:=K;V^.Pal[I,1]:=K;V^.Pal[I,2]:=K;End;
 For I:=32 To 247 Do Begin
  K:=I-32;G:=K Div 24;H:=K Mod 24;
  HsvToRgb(H*255 Div 24,IfThen_(G<3,255,IfThen_(G<6,160,90)),IfThen_(G Mod 3=0,255,IfThen_(G Mod 3=1,190,120)),R,Gg,B);
  V^.Pal[I,0]:=R Div 4;V^.Pal[I,1]:=Gg Div 4;V^.Pal[I,2]:=B Div 4;
 End;
 For I:=248 To 255 Do Begin V^.Pal[I,0]:=0;V^.Pal[I,1]:=0;V^.Pal[I,2]:=0;End;
 V^.PalDirty:=True;
End;

Procedure VMBuildLut(V: PVM);
Var I: Integer;
Begin
 For I:=0 To 255 Do
  V^.Lut[I]:=NearestVga(V^.Pal[I,0]*4+2,V^.Pal[I,1]*4+2,V^.Pal[I,2]*4+2);
 V^.PalDirty:=False;
End;

{ ---------------- contexte processeur ---------------- }

Procedure VMEnter(V: PVM);
Begin
 CV:=V;Mem:=V^.Mem;
 Move(V^.Rg,Rg,SizeOf(Rg));Move(V^.Sg,Sg,SizeOf(Sg));
 IPr:=V^.IP;SetFlags(V^.Fl);
 CpuHalt:=False;CpuBlock:=False;
End;

Procedure VMLeave(V: PVM);
Begin
 Move(Rg,V^.Rg,SizeOf(Rg));Move(Sg,V^.Sg,SizeOf(Sg));
 V^.IP:=IPr;V^.Fl:=GetFlags;
End;

{ ---------------- clavier ---------------- }

Function ScanOfChar(C: Char): Byte;
Const R1: String[10]='QWERTYUIOP'; R2: String[9]='ASDFGHJKL'; R3: String[7]='ZXCVBNM';
Var I: Integer; U: Char;
Begin
 U:=UpCase(C);ScanOfChar:=0;
 For I:=1 To 10 Do If R1[I]=U Then ScanOfChar:=15+I;
 For I:=1 To 9 Do If R2[I]=U Then ScanOfChar:=29+I;
 For I:=1 To 7 Do If R3[I]=U Then ScanOfChar:=43+I;
 If (C>='1') And (C<='9') Then ScanOfChar:=Ord(C)-48+1;
 If C='0' Then ScanOfChar:=11;
 Case C Of
  #27: ScanOfChar:=1; #8: ScanOfChar:=14; #9: ScanOfChar:=15; #13: ScanOfChar:=28;
  ' ': ScanOfChar:=57; '-': ScanOfChar:=12; '=': ScanOfChar:=13; '[': ScanOfChar:=26;
  ']': ScanOfChar:=27; ';': ScanOfChar:=39; '''': ScanOfChar:=40; ',': ScanOfChar:=51;
  '.': ScanOfChar:=52; '/': ScanOfChar:=53; '\': ScanOfChar:=43; '`': ScanOfChar:=41;
 End;
End;

Function KeyToBios(K: Word): Word;
Var A: Char;
Begin
 If K<256 Then Begin
  If K<32 Then Begin
   If K=3 Then KeyToBios:=$2E03
   Else If (K>=1) And (K<=26) And (K<>8) And (K<>9) And (K<>13) Then KeyToBios:=(Word(ScanOfChar(Chr(K+64))) Shl 8) Or K
   Else KeyToBios:=(Word(ScanOfChar(Chr(K))) Shl 8) Or K;
  End Else KeyToBios:=(Word(ScanOfChar(Chr(K))) Shl 8) Or K;
 End Else Begin
  A:=AltLetter(K);
  If A<>#0 Then KeyToBios:=Word(K-256) Shl 8
  Else KeyToBios:=Word(K-256) Shl 8;
 End;
End;

Procedure VMKeyPut(V: PVM; Bk: Word);
Var N: Integer;
Begin
 N:=(V^.KT+1) And 63;
 If N<>V^.KH Then Begin V^.KQ[V^.KT]:=Bk;V^.KT:=N;End;
 V^.ScanLast:=Bk Shr 8;
End;

Function KqHas: Boolean;
Begin
 KqHas:=CV^.KH<>CV^.KT;
End;

Function KqPeek: Word;
Begin
 KqPeek:=CV^.KQ[CV^.KH];
End;

Function KqGet: Word;
Begin
 KqGet:=CV^.KQ[CV^.KH];
 CV^.KH:=(CV^.KH+1) And 63;
End;

{ ---------------- console texte ---------------- }

Function BdaB(O: Integer): Byte;
Begin
 BdaB:=Mem^[$400+O];
End;

Procedure ScrClear;
Var I: Integer;
Begin
 For I:=0 To 1999 Do Begin Mem^[TXT_BASE+I*2]:=32;Mem^[TXT_BASE+I*2+1]:=7;End;
 Mem^[$450]:=0;Mem^[$451]:=0;
End;

Procedure ScrScroll(Top,Left,Bot,Right: Integer; Lines: Integer; Attr: Byte);
Var Y,X,N: Integer;
Begin
 If (Lines=0) Or (Lines>Bot-Top+1) Then Begin
  For Y:=Top To Bot Do For X:=Left To Right Do Begin Mem^[TXT_BASE+(Y*80+X)*2]:=32;Mem^[TXT_BASE+(Y*80+X)*2+1]:=Attr;End;
  Exit;
 End;
 If Lines>0 Then Begin
  For Y:=Top To Bot-Lines Do For X:=Left To Right Do Begin
   Mem^[TXT_BASE+(Y*80+X)*2]:=Mem^[TXT_BASE+((Y+Lines)*80+X)*2];
   Mem^[TXT_BASE+(Y*80+X)*2+1]:=Mem^[TXT_BASE+((Y+Lines)*80+X)*2+1];
  End;
  For Y:=Bot-Lines+1 To Bot Do For X:=Left To Right Do Begin Mem^[TXT_BASE+(Y*80+X)*2]:=32;Mem^[TXT_BASE+(Y*80+X)*2+1]:=Attr;End;
 End Else Begin
  N:=-Lines;
  For Y:=Bot DownTo Top+N Do For X:=Left To Right Do Begin
   Mem^[TXT_BASE+(Y*80+X)*2]:=Mem^[TXT_BASE+((Y-N)*80+X)*2];
   Mem^[TXT_BASE+(Y*80+X)*2+1]:=Mem^[TXT_BASE+((Y-N)*80+X)*2+1];
  End;
  For Y:=Top To Top+N-1 Do For X:=Left To Right Do Begin Mem^[TXT_BASE+(Y*80+X)*2]:=32;Mem^[TXT_BASE+(Y*80+X)*2+1]:=Attr;End;
 End;
End;

Procedure ConPut(C: Byte);
Var X,Y: Integer;
Begin
 X:=Mem^[$450];Y:=Mem^[$451];
 Case C Of
  7: Beep;
  8: If X>0 Then Dec(X);
  9: X:=(X+8) And $F8;
  10: Inc(Y);
  13: X:=0;
 Else Begin
   Mem^[TXT_BASE+(Y*80+X)*2]:=C;
   Inc(X);
  End;
 End;
 If X>=80 Then Begin X:=0;Inc(Y);End;
 If Y>=25 Then Begin ScrScroll(0,0,24,79,1,7);Y:=24;End;
 Mem^[$450]:=X;Mem^[$451]:=Y;
End;

Procedure ConStr(Const S: String);
Var I: Integer;
Begin
 For I:=1 To Length(S) Do ConPut(Ord(S[I]));
End;

Procedure ConLn;
Begin
 ConPut(13);ConPut(10);
End;

{ ---------------- memoire DOS ---------------- }

Procedure ArenaInit(V: PVM);
Begin
 V^.NBlk:=1;V^.Blk[1].Seg:=$0600;V^.Blk[1].Size:=$A000-$0600;V^.Blk[1].Owner:=0;
End;

Function ArenaLargest(V: PVM): Word;
Var I: Integer; M: Word;
Begin
 M:=0;
 For I:=1 To V^.NBlk Do If (V^.Blk[I].Owner=0) And (V^.Blk[I].Size>M) Then M:=V^.Blk[I].Size;
 ArenaLargest:=M;
End;

Function ArenaAlloc(V: PVM; Size: Word; Owner: Word): Word;
Var I,J: Integer;
Begin
 ArenaAlloc:=0;
 For I:=1 To V^.NBlk Do
  If (V^.Blk[I].Owner=0) And (V^.Blk[I].Size>=Size) Then Begin
   If (V^.Blk[I].Size>Size) And (V^.NBlk<MAXBLK) Then Begin
    For J:=V^.NBlk DownTo I+1 Do V^.Blk[J+1]:=V^.Blk[J];
    Inc(V^.NBlk);
    V^.Blk[I+1].Seg:=V^.Blk[I].Seg+Size;V^.Blk[I+1].Size:=V^.Blk[I].Size-Size;V^.Blk[I+1].Owner:=0;
    V^.Blk[I].Size:=Size;
   End;
   V^.Blk[I].Owner:=Owner;
   ArenaAlloc:=V^.Blk[I].Seg;Exit;
  End;
End;

Procedure ArenaMerge(V: PVM);
Var I,J: Integer;
Begin
 I:=1;
 While I<V^.NBlk Do Begin
  If (V^.Blk[I].Owner=0) And (V^.Blk[I+1].Owner=0) Then Begin
   V^.Blk[I].Size:=V^.Blk[I].Size+V^.Blk[I+1].Size;
   For J:=I+1 To V^.NBlk-1 Do V^.Blk[J]:=V^.Blk[J+1];
   Dec(V^.NBlk);
  End Else Inc(I);
 End;
End;

Function ArenaFree(V: PVM; Seg: Word): Boolean;
Var I: Integer;
Begin
 ArenaFree:=False;
 For I:=1 To V^.NBlk Do If V^.Blk[I].Seg=Seg Then Begin V^.Blk[I].Owner:=0;ArenaFree:=True;End;
 ArenaMerge(V);
End;

Procedure ArenaFreeOwner(V: PVM; Owner: Word);
Var I: Integer;
Begin
 For I:=1 To V^.NBlk Do If V^.Blk[I].Owner=Owner Then V^.Blk[I].Owner:=0;
 ArenaMerge(V);
End;

{ redimensionne : retourne la taille maximale possible en Mx }
Function ArenaResize(V: PVM; Seg,NewSize: Word; Var Mx: Word): Boolean;
Var I,J: Integer; Avail: LongInt;
Begin
 ArenaResize:=False;Mx:=0;
 For I:=1 To V^.NBlk Do If V^.Blk[I].Seg=Seg Then Begin
  Avail:=V^.Blk[I].Size;
  If (I<V^.NBlk) And (V^.Blk[I+1].Owner=0) Then Avail:=Avail+V^.Blk[I+1].Size;
  Mx:=Avail;
  If NewSize>Avail Then Exit;
  If NewSize<V^.Blk[I].Size Then Begin
   If (I<V^.NBlk) And (V^.Blk[I+1].Owner=0) Then Begin
    V^.Blk[I+1].Seg:=Seg+NewSize;V^.Blk[I+1].Size:=Avail-NewSize;V^.Blk[I].Size:=NewSize;
   End Else If V^.NBlk<MAXBLK Then Begin
    For J:=V^.NBlk DownTo I+1 Do V^.Blk[J+1]:=V^.Blk[J];
    Inc(V^.NBlk);
    V^.Blk[I+1].Seg:=Seg+NewSize;V^.Blk[I+1].Size:=V^.Blk[I].Size-NewSize;V^.Blk[I+1].Owner:=0;
    V^.Blk[I].Size:=NewSize;
   End;
  End Else If NewSize>V^.Blk[I].Size Then Begin
   { absorbe le bloc libre suivant }
   V^.Blk[I+1].Seg:=Seg+NewSize;V^.Blk[I+1].Size:=Avail-NewSize;V^.Blk[I].Size:=NewSize;
   If V^.Blk[I+1].Size=0 Then Begin
    For J:=I+1 To V^.NBlk-1 Do V^.Blk[J]:=V^.Blk[J+1];Dec(V^.NBlk);
   End;
  End;
  ArenaResize:=True;Exit;
 End;
End;

{ ---------------- chemins DOS ---------------- }

Function DosPath(V: PVM; Const S: String): String;
Var R,Part: String; P,I: Integer; Drv: String; Segs: Array[1..20] Of String[14]; N: Integer; T: String;
Begin
 T:=S;
 For I:=1 To Length(T) Do If T[I]='/' Then T[I]:='\';
 If (Length(T)>=2) And (T[2]=':') Then Begin Drv:=Upper(Copy(T,1,2));Delete(T,1,2);End
 Else Drv:=Copy(V^.CurDir,1,2);
 N:=0;
 If (T<>'') And (T[1]='\') Then Delete(T,1,1)
 Else Begin
  If UpCase(V^.CurDir[1])=UpCase(Drv[1]) Then R:=Copy(V^.CurDir,4,200) Else R:='';
  T:=R+'\'+T;
  If (T<>'') And (T[1]='\') Then Delete(T,1,1);
 End;
 While T<>'' Do Begin
  P:=Pos('\',T);
  If P=0 Then Begin Part:=T;T:='';End Else Begin Part:=Copy(T,1,P-1);Delete(T,1,P);End;
  If (Part='') Or (Part='.') Then Continue;
  If Part='..' Then Begin If N>0 Then Dec(N);Continue;End;
  If N<20 Then Begin Inc(N);Segs[N]:=Upper(Part);End;
 End;
 R:=Drv+'\';
 For I:=1 To N Do Begin If I>1 Then R:=R+'\';R:=R+Segs[I];End;
 DosPath:=R;
End;

Function RdZ(Seg,Off: Word): String;
Var S: String; B: Byte; N: Integer;
Begin
 S:='';N:=0;
 Repeat
  B:=RdB(Lin(Seg,Off+N));
  If B<>0 Then S:=S+Chr(B);
  Inc(N);
 Until (B=0) Or (N>250);
 RdZ:=S;
End;

Procedure WrZ(Seg,Off: Word; Const S: String);
Var I: Integer;
Begin
 For I:=1 To Length(S) Do WrB(Lin(Seg,Off+I-1),Ord(S[I]));
 WrB(Lin(Seg,Off+Length(S)),0);
End;

{ ---------------- gestion des handles ---------------- }

Function FhAlloc(V: PVM): Integer;
Var I: Integer;
Begin
 FhAlloc:=-1;
 For I:=5 To MAXFH-1 Do If Not V^.Files[I].Used Then Begin FhAlloc:=I;Exit;End;
End;

Procedure FhClose(V: PVM; H: Integer);
Begin
 If (H<0) Or (H>=MAXFH) Or Not V^.Files[H].Used Then Exit;
 If (V^.Files[H].Dev=0) And (H>=5) Then Begin
  {$I-}Close(V^.Files[H].F);{$I+}
  If IOResult<>0 Then ;
 End;
 If H>=5 Then V^.Files[H].Used:=False;
End;

Procedure DosSetErr(Code: Word);
Begin
 Rg[R_AX]:=Code;fCF:=True;
End;

Function Short83(Const N: String): Boolean;
Var P,I: Integer; B,E: String;
Begin
 P:=Pos('.',N);
 If P=0 Then Begin B:=N;E:='';End Else Begin B:=Copy(N,1,P-1);E:=Copy(N,P+1,20);End;
 Short83:=(Length(B)<=8) And (Length(E)<=3) And (Pos(' ',N)=0) And (B<>'');
End;

{ ---------------- recherche de fichiers ---------------- }

Procedure FindFill(V: PVM; Slot: Integer);
Var D: LongInt; S: String; I: Integer; A: Byte; Tm: LongInt;
Begin
 D:=V^.DTA;
 A:=V^.Finds[Slot].SR.Attr And $3F;
 WrB(D,Slot+1);
 WrB(D+$15,A);
 Tm:=V^.Finds[Slot].SR.Time;
 WrW(D+$16,Tm And $FFFF);WrW(D+$18,(Tm Shr 16) And $FFFF);
 WrW(D+$1A,V^.Finds[Slot].SR.Size And $FFFF);WrW(D+$1C,(V^.Finds[Slot].SR.Size Shr 16) And $FFFF);
 S:=Upper(V^.Finds[Slot].SR.Name);
 For I:=1 To 13 Do WrB(D+$1D+I,0);
 For I:=1 To Length(S) Do If I<=12 Then WrB(D+$1D+I,Ord(S[I]));
End;

Function FindNextMatch(V: PVM; Slot: Integer; First: Boolean; Const Dir: String): Boolean;
Var Ok: Boolean; Pat: String;
Begin
 FindNextMatch:=False;
 Pat:=V^.Finds[Slot].Pat;
 If Pat='*.*' Then Pat:='*';
 While DosError=0 Do Begin
  With V^.Finds[Slot] Do Begin
   Ok:=(SR.Name<>'.') And (SR.Name<>'..') And (SR.Name[1]<>'.') And Short83(Upper(SR.Name)) And WildMatch(Pat,SR.Name);
   If Ok And ((SR.Attr And Directory)<>0) And ((Attr And $10)=0) Then Ok:=False;
   If Ok And ((SR.Attr And VolumeID)<>0) Then Ok:=False;
  End;
  If Ok Then Begin FindNextMatch:=True;FindFill(V,Slot);Exit;End;
  FindNext(V^.Finds[Slot].SR);
 End;
End;

{ ---------------- processus ---------------- }

Procedure ProcExit(V: PVM; Code: Word);
Var I: Integer; N: Integer;
Begin
 ArenaFreeOwner(V,V^.PSP);
 For I:=5 To MAXFH-1 Do If V^.Files[I].Used And (V^.Files[I].Owner=V^.PSP) Then FhClose(V,I);
 V^.LastExit:=Code;
 If V^.NCtx>0 Then Begin
  N:=V^.NCtx;
  Move(V^.Ctx[N].Rg,Rg,SizeOf(Rg));Move(V^.Ctx[N].Sg,Sg,SizeOf(Sg));
  IPr:=V^.Ctx[N].IP;SetFlags(V^.Ctx[N].Fl);V^.PSP:=V^.Ctx[N].PSP;V^.DTA:=V^.Ctx[N].DTA;
  Dec(V^.NCtx);
  fCF:=False;
 End Else Begin
  V^.Running:=False;V^.NeedPrompt:=True;CpuBlock:=True;
 End;
End;

{ ---------------- chargement d'un programme ---------------- }

Const
 LD_OK=0; LD_NOFILE=2; LD_BADFMT=11; LD_NOMEM=8; LD_WIN16=100;

Function BuildEnv(V: PVM; Seg: Word; Const Prog: String): Integer;
Var I,Off,L: Integer; S: String;
Begin
 Off:=0;
 For I:=1 To V^.NEnv Do Begin
  S:=V^.EnvVars[I];
  If (Off+Length(S)+1<500) Then Begin WrZ(Seg,Off,S);Inc(Off,Length(S)+1);End;
 End;
 WrB(Lin(Seg,Off),0);Inc(Off);
 WrW(Lin(Seg,Off),1);Inc(Off,2);
 WrZ(Seg,Off,Prog);
 BuildEnv:=Off;
End;

Procedure BuildPsp(V: PVM; PspSeg,EnvSeg,Par,TopSeg: Word; Const Tail: String);
Var A: LongInt; I: Integer;
Begin
 A:=Lin(PspSeg,0);
 For I:=0 To 255 Do Mem^[A+I]:=0;
 Mem^[A]:=$CD;Mem^[A+1]:=$20;
 WrW(A+2,TopSeg);
 Mem^[A+5]:=$9A;
 WrW(A+$16,Par);
 For I:=0 To 19 Do Mem^[A+$18+I]:=$FF;
 Mem^[A+$18]:=0;Mem^[A+$19]:=1;Mem^[A+$1A]:=2;Mem^[A+$1B]:=3;Mem^[A+$1C]:=4;
 WrW(A+$2C,EnvSeg);
 WrW(A+$32,20);WrW(A+$34,$18);WrW(A+$36,PspSeg);
 Mem^[A+$50]:=$CD;Mem^[A+$51]:=$21;Mem^[A+$52]:=$CB;
 Mem^[A+$5C]:=0;
 If Length(Tail)>126 Then Mem^[A+$80]:=126 Else Mem^[A+$80]:=Length(Tail);
 For I:=1 To Min2(126,Length(Tail)) Do Mem^[A+$80+I]:=Ord(Tail[I]);
 Mem^[A+$81+Min2(126,Length(Tail))]:=13;
End;

{ Charge un .COM ou .EXE ; Nouveau processus enfant de V^.PSP }
Procedure WriteMcb(S,Size: Word);
Var A: LongInt;
Begin
 A:=LongInt(S-1)*16;
 If LongInt(S)+Size>=$A000 Then Mem^[A]:=$5A Else Mem^[A]:=$4D;
 WrW(A+1,S);WrW(A+3,Size);
End;

Procedure EmsEnable(V: PVM); Forward;

Function LoadProgram(V: PVM; Const VPath,Tail: String): Integer;
Var F: File; Sz,Nb: LongInt; Cnt: Word; Real_: String; IsExe: Boolean; Sig: Word;
    LastPg,Pages,HdrPar,MinA,MaxA,Reloc,RelOfs,InitSS,InitSP,InitIP,InitCS,Need: LongInt;
    EnvSeg,PspSeg,TopFree,Load,Mx: Word; I: Integer; Buf: PByteArr_; N: Word; Ofs,Sgm: Word;
    Total: LongInt; Par: Word; Blocks: LongInt; Img: LongInt; FSize: LongInt; Mz: Array[0..63] Of Byte;
    Parent: Word; Big: LongInt; Mz2: Word; ProgName: String;
Begin
 LoadProgram:=LD_NOFILE;
 Real_:=V2R(VPath);
 If Not FileExists(Real_) Then Exit;
 {$I-}
 FileMode:=0;
 Assign(F,Real_);Reset(F,1);
 FSize:=FileSize(F);
 BlockRead(F,Mz,64,N);
 {$I+}
 If IOResult<>0 Then Begin LoadProgram:=LD_NOFILE;Exit;End;
 IsExe:=(N>=2) And (((Mz[0]=$4D) And (Mz[1]=$5A)) Or ((Mz[0]=$5A) And (Mz[1]=$4D)));
 If IsExe And (N>=64) Then Begin
  { NE ? }
  Ofs:=Mz[$3C]+Mz[$3D]*256;
  If (Mz[$18]>=$40) And (Ofs>0) Then Begin
   Seek(F,Ofs);BlockRead(F,Sig,2,N);
   If Sig=$454E Then Begin Close(F);LoadProgram:=LD_WIN16;Exit;End;
  End;
 End;
 Parent:=V^.PSP;
 ProgName:=VPath;
 DosV3:=(Pos('EXCEL',Upper(BaseName(VPath)))=1) Or (Upper(BaseName(VPath))='WIN.COM') Or (Upper(BaseName(VPath))='WIN200.BIN');
 If DosV3 Then EmsEnable(V);
 EnvSeg:=ArenaAlloc(V,32,$FFFE);
 If EnvSeg=0 Then Begin Close(F);LoadProgram:=LD_NOMEM;Exit;End;
 BuildEnv(V,EnvSeg,ProgName);
 If Not IsExe Then Begin
  Need:=(FSize+$100+15) Div 16+16;
  Mx:=ArenaLargest(V);
  If (Need>Mx) Or (FSize>65280) Then Begin ArenaFree(V,EnvSeg);Close(F);LoadProgram:=LD_NOMEM;Exit;End;
  PspSeg:=ArenaAlloc(V,Mx,$FFFF);
  If PspSeg=0 Then Begin ArenaFree(V,EnvSeg);Close(F);LoadProgram:=LD_NOMEM;Exit;End;
  For I:=1 To V^.NBlk Do If V^.Blk[I].Seg=PspSeg Then V^.Blk[I].Owner:=PspSeg;
  For I:=1 To V^.NBlk Do If V^.Blk[I].Seg=EnvSeg Then V^.Blk[I].Owner:=PspSeg;
  BuildPsp(V,PspSeg,EnvSeg,Parent,PspSeg+Mx,Tail);If DosV3 Then WriteMcb(PspSeg,Mx);
  Seek(F,0);
  BlockRead(F,Mem^[Lin(PspSeg,$100)],FSize,N);
  Close(F);
  V^.PSP:=PspSeg;V^.DTA:=Lin(PspSeg,$80);
  Sg[SG_CS]:=PspSeg;Sg[SG_DS]:=PspSeg;Sg[SG_ES]:=PspSeg;Sg[SG_SS]:=PspSeg;
  For I:=0 To 7 Do Rg[I]:=0;
  Rg[R_SP]:=$FFFE;WrW(Lin(PspSeg,$FFFE),0);
  IPr:=$100;
  Rg[R_AX]:=0;
  LoadProgram:=LD_OK;
  Exit;
 End;
 { EXE MZ }
 LastPg:=Mz[2]+Mz[3]*256;Pages:=Mz[4]+Mz[5]*256;
 Reloc:=Mz[6]+Mz[7]*256;HdrPar:=Mz[8]+Mz[9]*256;
 MinA:=Mz[10]+Mz[11]*256;MaxA:=Mz[12]+Mz[13]*256;
 InitSS:=Mz[14]+Mz[15]*256;InitSP:=Mz[16]+Mz[17]*256;
 InitIP:=Mz[20]+Mz[21]*256;InitCS:=Mz[22]+Mz[23]*256;RelOfs:=Mz[24]+Mz[25]*256;
 If LastPg=0 Then Img:=Pages*512-HdrPar*16 Else Img:=(Pages-1)*512+LastPg-HdrPar*16;
 If Img<0 Then Img:=0;
 Need:=(Img+15) Div 16+MinA+16;
 Mx:=ArenaLargest(V);
 If Need>Mx Then Begin ArenaFree(V,EnvSeg);Close(F);LoadProgram:=LD_NOMEM;Exit;End;
 If MaxA=$FFFF Then Blocks:=Mx Else Begin Blocks:=(Img+15) Div 16+16+MaxA;If Blocks>Mx Then Blocks:=Mx;If Blocks<Need Then Blocks:=Need;End;
 PspSeg:=ArenaAlloc(V,Blocks,$FFFF);
 For I:=1 To V^.NBlk Do If V^.Blk[I].Seg=PspSeg Then V^.Blk[I].Owner:=PspSeg;
 For I:=1 To V^.NBlk Do If V^.Blk[I].Seg=EnvSeg Then V^.Blk[I].Owner:=PspSeg;
 BuildPsp(V,PspSeg,EnvSeg,Parent,PspSeg+Blocks,Tail);If DosV3 Then WriteMcb(PspSeg,Blocks);
 Load:=PspSeg+16;
 {$I-}
 Seek(F,HdrPar*16);
 BlockRead(F,Mem^[Lin(Load,0)],Img,N);
 { relocations }
 For I:=0 To Reloc-1 Do Begin
  Seek(F,RelOfs+I*4);
  BlockRead(F,Mz,4,N);
  Ofs:=Mz[0]+Mz[1]*256;Sgm:=Mz[2]+Mz[3]*256;
  WrW(Lin(Load+Sgm,Ofs),Word(RdW(Lin(Load+Sgm,Ofs))+Load));
 End;
 Close(F);
 {$I+}
 V^.PSP:=PspSeg;V^.DTA:=Lin(PspSeg,$80);
 Sg[SG_CS]:=Load+InitCS;IPr:=InitIP;
 Sg[SG_SS]:=Load+InitSS;Rg[R_SP]:=InitSP;
 Sg[SG_DS]:=PspSeg;Sg[SG_ES]:=PspSeg;
 For I:=0 To 7 Do If I<>R_SP Then Rg[I]:=0;
 LoadProgram:=LD_OK;
End;

{ ---------------- ports d'entree/sortie ---------------- }

Function PortIn(P: Word; Wide: Boolean): Word;
Var R: Word;
Begin
 R:=0;
 Case P Of
  $60: R:=CV^.ScanLast;
  $64: R:=Ord(CV^.KH<>CV^.KT);
  $61: R:=$20;
  $3DA: Begin Inc(PortRetrace);If (PortRetrace And 3)=0 Then R:=9 Else If (PortRetrace And 3)=1 Then R:=1 Else R:=0;End;
  $40: R:=(InstCnt Shr 2) And 255;
  $3C9: Begin
     R:=CV^.Pal[CV^.DacR And 255,CV^.DacPhR];
     Inc(CV^.DacPhR);If CV^.DacPhR>2 Then Begin CV^.DacPhR:=0;Inc(CV^.DacR);End;
    End;
  $3C7: R:=0;
  $3D4: R:=CV^.CrtcIdx;
  $3D5: R:=CV^.Crtc[CV^.CrtcIdx And 31];
  $21,$A1: R:=0;
 End;
 PortIn:=R;
End;

Procedure PortOut(P: Word; V: Word; Wide: Boolean);
Var X,Y: Integer;
Begin
 Case P Of
  $3C8: Begin CV^.DacW:=V And 255;CV^.DacPh:=0;End;
  $3C7: Begin CV^.DacR:=V And 255;CV^.DacPhR:=0;End;
  $3C9: Begin
     CV^.Pal[CV^.DacW And 255,CV^.DacPh]:=V And 63;
     Inc(CV^.DacPh);If CV^.DacPh>2 Then Begin CV^.DacPh:=0;Inc(CV^.DacW);End;
     CV^.PalDirty:=True;
    End;
  $3D4: CV^.CrtcIdx:=V And 255;
  $3D5: Begin
     CV^.Crtc[CV^.CrtcIdx And 31]:=V And 255;
     If (CV^.CrtcIdx=$0E) Or (CV^.CrtcIdx=$0F) Then Begin
      X:=(CV^.Crtc[$0E] Shl 8) Or CV^.Crtc[$0F];
      If (X<2000) Then Begin Mem^[$450]:=X Mod 80;Mem^[$451]:=X Div 80;End;
     End;
    End;
 End;
End;

{$ENDIF}
{ ====================================================================== }
{          EMULATEUR DOS : INTERRUPTIONS BIOS ET DOS (INT 10h-33h)       }
{ ====================================================================== }

{$IFDEF FPC}

Procedure VMSetMode(V: PVM; M: Byte; NoClear: Boolean);
Var I: LongInt;
Begin
 V^.Mode:=M;
 Mem^[$449]:=M;
 Case M Of
  0,1,2,3,7: Begin
     V^.GfxFull:=False;
     If Not NoClear Then ScrClear;
     Mem^[$44A]:=80;Mem^[$484]:=24;
    End;
 Else Begin
   V^.GfxFull:=True;
   If Not NoClear Then Begin
    If M=$13 Then For I:=0 To 63999 Do Mem^[VGA_BASE+I]:=0
    Else If (M=4) Or (M=5) Or (M=6) Then For I:=0 To 16383 Do Mem^[TXT_BASE+I]:=0
    Else If V^.Pix<>Nil Then FillChar(V^.Pix^,640*480,0);
   End;
   If M=$13 Then Begin VMDefaultPalette(V);End;
  End;
 End;
End;

Function PixAddr(V: PVM; X,Y: Integer): LongInt;
Begin
 PixAddr:=0;
 Case V^.Mode Of
  $13: PixAddr:=VGA_BASE+Y*320+X;
  4,5: PixAddr:=TXT_BASE+(Y And 1)*$2000+(Y Shr 1)*80+(X Shr 2);
  6: PixAddr:=TXT_BASE+(Y And 1)*$2000+(Y Shr 1)*80+(X Shr 3);
 End;
End;

Procedure VMPixel(V: PVM; X,Y: Integer; C: Byte);
Var A: LongInt; Sh,Mk: Integer;
Begin
 If (X<0) Or (Y<0) Then Exit;
 Case V^.Mode Of
  $13: If (X<320) And (Y<200) Then Begin
     A:=PixAddr(V,X,Y);
     If (C And $80)<>0 Then Mem^[A]:=Mem^[A] Xor C Else Mem^[A]:=C;
    End;
  4,5: If (X<320) And (Y<200) Then Begin
     A:=PixAddr(V,X,Y);Sh:=6-2*(X And 3);Mk:=3 Shl Sh;
     If (C And $80)<>0 Then Mem^[A]:=Mem^[A] Xor ((C And 3) Shl Sh)
     Else Mem^[A]:=(Mem^[A] And (255-Mk)) Or ((C And 3) Shl Sh);
    End;
  6: If (X<640) And (Y<200) Then Begin
     A:=PixAddr(V,X,Y);Sh:=7-(X And 7);
     Mem^[A]:=(Mem^[A] And (255-(1 Shl Sh))) Or ((C And 1) Shl Sh);
    End;
 Else If (V^.Pix<>Nil) And (X<640) And (Y<480) Then V^.Pix^[Y*640+X]:=C And 15;
 End;
End;

Function VMGetPixel(V: PVM; X,Y: Integer): Byte;
Var A: LongInt;
Begin
 VMGetPixel:=0;
 If (X<0) Or (Y<0) Then Exit;
 Case V^.Mode Of
  $13: If (X<320) And (Y<200) Then VMGetPixel:=Mem^[PixAddr(V,X,Y)];
  4,5: If (X<320) And (Y<200) Then VMGetPixel:=(Mem^[PixAddr(V,X,Y)] Shr (6-2*(X And 3))) And 3;
  6: If (X<640) And (Y<200) Then VMGetPixel:=(Mem^[PixAddr(V,X,Y)] Shr (7-(X And 7))) And 1;
 Else If (V^.Pix<>Nil) And (X<640) And (Y<480) Then VMGetPixel:=V^.Pix^[Y*640+X];
 End;
End;

Procedure Int10;
Var AH,AL,Att: Byte; I,X,Y,Cnt: Integer; A: LongInt; S: String;
Begin
 AH:=Rg[R_AX] Shr 8;AL:=Rg[R_AX] And 255;
 Case AH Of
  $00: VMSetMode(CV,AL And $7F,(AL And $80)<>0);
  $01: Begin Mem^[$460]:=Rg[R_CX] And 255;Mem^[$461]:=Rg[R_CX] Shr 8;End;
  $02: Begin Mem^[$450]:=Rg[R_DX] And 255;Mem^[$451]:=Rg[R_DX] Shr 8;End;
  $03: Begin Rg[R_DX]:=Mem^[$450] Or (Word(Mem^[$451]) Shl 8);Rg[R_CX]:=Mem^[$460] Or (Word(Mem^[$461]) Shl 8);End;
  $05: ;
  $06,$07: Begin
     Att:=Rg[R_BX] Shr 8;
     If AH=6 Then ScrScroll(Rg[R_CX] Shr 8,Rg[R_CX] And 255,Min2(24,Rg[R_DX] Shr 8),Min2(79,Rg[R_DX] And 255),AL,Att)
     Else ScrScroll(Rg[R_CX] Shr 8,Rg[R_CX] And 255,Min2(24,Rg[R_DX] Shr 8),Min2(79,Rg[R_DX] And 255),-AL,Att);
    End;
  $08: Begin
     A:=TXT_BASE+(Mem^[$451]*80+Mem^[$450])*2;
     Rg[R_AX]:=Mem^[A] Or (Word(Mem^[A+1]) Shl 8);
    End;
  $09,$0A: Begin
     Cnt:=Rg[R_CX];Att:=Rg[R_BX] And 255;
     X:=Mem^[$450];Y:=Mem^[$451];
     For I:=1 To Cnt Do Begin
      If (X<80) And (Y<25) Then Begin
       A:=TXT_BASE+(Y*80+X)*2;Mem^[A]:=AL;
       If AH=9 Then Mem^[A+1]:=Att;
      End;
      Inc(X);If X>=80 Then Break;
     End;
    End;
  $0B: ;
  $0C: VMPixel(CV,Rg[R_CX],Rg[R_DX],AL);
  $0D: SetR8(0,VMGetPixel(CV,Rg[R_CX],Rg[R_DX]));
  $0E: ConPut(AL);
  $0F: Rg[R_AX]:=Mem^[$449] Or ($5000);
  $10: Case AL Of
     $00,$01,$02,$03: ;
     $10: Begin CV^.Pal[Rg[R_BX] And 255,0]:=Rg[R_DX] Shr 8;CV^.Pal[Rg[R_BX] And 255,1]:=Rg[R_CX] Shr 8;
          CV^.Pal[Rg[R_BX] And 255,2]:=Rg[R_CX] And 255;CV^.PalDirty:=True;End;
     $12: Begin
          A:=Lin(Sg[SG_ES],Rg[R_DX]);
          For I:=0 To Rg[R_CX]-1 Do Begin
           If (Rg[R_BX]+I)<256 Then Begin
            CV^.Pal[(Rg[R_BX]+I) And 255,0]:=Mem^[A+I*3];CV^.Pal[(Rg[R_BX]+I) And 255,1]:=Mem^[A+I*3+1];
            CV^.Pal[(Rg[R_BX]+I) And 255,2]:=Mem^[A+I*3+2];
           End;
          End;
          CV^.PalDirty:=True;
         End;
     $15: Begin
          Rg[R_DX]:=(Rg[R_DX] And $00FF) Or (Word(CV^.Pal[Rg[R_BX] And 255,0]) Shl 8);
          Rg[R_CX]:=(Word(CV^.Pal[Rg[R_BX] And 255,1]) Shl 8) Or CV^.Pal[Rg[R_BX] And 255,2];
         End;
     $17: Begin
          A:=Lin(Sg[SG_ES],Rg[R_DX]);
          For I:=0 To Rg[R_CX]-1 Do Begin
           Mem^[A+I*3]:=CV^.Pal[(Rg[R_BX]+I) And 255,0];Mem^[A+I*3+1]:=CV^.Pal[(Rg[R_BX]+I) And 255,1];
           Mem^[A+I*3+2]:=CV^.Pal[(Rg[R_BX]+I) And 255,2];
          End;
         End;
    End;
  $11: ;
  $12: If (Rg[R_BX] And 255)=$10 Then Begin Rg[R_BX]:=$0003;Rg[R_CX]:=$0009;End;
  $13: Begin
     A:=Lin(Sg[SG_ES],Rg[R_BP]);
     X:=Rg[R_DX] And 255;Y:=Rg[R_DX] Shr 8;
     Att:=Rg[R_BX] And 255;
     Mem^[$450]:=X;Mem^[$451]:=Y;
     For I:=0 To Rg[R_CX]-1 Do Begin
      If (AL And 2)<>0 Then Begin
       ConPut(Mem^[A+I*2]);
      End Else ConPut(Mem^[A+I]);
     End;
     If (AL And 1)=0 Then Begin Mem^[$450]:=X;Mem^[$451]:=Y;End;
    End;
  $1A: Begin Rg[R_AX]:=$1A1A;Rg[R_BX]:=$0008;End;
  $1B: ;
  $4F: Rg[R_AX]:=$014F;
 End;
End;

Function ReadKeyBlock(Var K: Word; Peek: Boolean): Boolean;
Begin
 If KqHas Then Begin
  If Peek Then K:=KqPeek Else K:=KqGet;
  ReadKeyBlock:=True;
 End Else Begin ReadKeyBlock:=False;End;
End;

Procedure Int16;
Var AH: Byte; K: Word;
Begin
 AH:=Rg[R_AX] Shr 8;
 Case AH Of
  $00,$10: If ReadKeyBlock(K,False) Then Rg[R_AX]:=K Else CpuBlock:=True;
  $01,$11: If ReadKeyBlock(K,True) Then Begin Rg[R_AX]:=K;fZF:=False;End Else fZF:=True;
  $02,$12: Rg[R_AX]:=(Rg[R_AX] And $FF00) Or Mem^[$417];
  $05: Begin VMKeyPut(CV,Rg[R_CX]);Rg[R_AX]:=Rg[R_AX] And $FF;End;
 End;
End;

Function ToBcd(N: Integer): Byte;
Begin
 ToBcd:=((N Div 10) Shl 4) Or (N Mod 10);
End;

Procedure Int1A;
Var AH: Byte; H,M,S,Y,Mo,D: Integer; T: Int64;
Begin
 AH:=Rg[R_AX] Shr 8;
 Case AH Of
  0: Begin
      T:=(Int64(NowCs)*182065) Div 1000000;
      Rg[R_CX]:=(T Shr 16) And $FFFF;Rg[R_DX]:=T And $FFFF;Rg[R_AX]:=Rg[R_AX] And $FF00;
     End;
  1: ;
  2: Begin GetNow(H,M,S);Rg[R_CX]:=(Word(ToBcd(H)) Shl 8) Or ToBcd(M);Rg[R_DX]:=Word(ToBcd(S)) Shl 8;fCF:=False;End;
  4: Begin GetToday(Y,Mo,D);Rg[R_CX]:=(Word(ToBcd(Y Div 100)) Shl 8) Or ToBcd(Y Mod 100);
      Rg[R_DX]:=(Word(ToBcd(Mo)) Shl 8) Or ToBcd(D);fCF:=False;End;
 End;
End;

Var M14Mask,M14Seg,M14Off,TmpW: Word;

Procedure Int33;
Begin
 Case Rg[R_AX] Of
  0: If GetEnv('W2NOMOUSE')<>'' Then Rg[R_AX]:=0 Else Begin Rg[R_AX]:=$FFFF;Rg[R_BX]:=2;End;
  1,2: ;
  3: Begin Rg[R_BX]:=CV^.MouseB;Rg[R_CX]:=CV^.MouseX;Rg[R_DX]:=CV^.MouseY;End;
  4: Begin CV^.MouseX:=Rg[R_CX];CV^.MouseY:=Rg[R_DX];End;
  5,6: Begin Rg[R_BX]:=0;Rg[R_AX]:=CV^.MouseB;End;
  $B: Begin Rg[R_CX]:=0;Rg[R_DX]:=0;End;
  $24: Begin Rg[R_BX]:=$0805;Rg[R_CX]:=$0400;End;
  $14: Begin
    TmpW:=Rg[R_CX];Rg[R_CX]:=M14Mask;M14Mask:=TmpW;
    TmpW:=Sg[SG_ES];Sg[SG_ES]:=M14Seg;M14Seg:=TmpW;
    TmpW:=Rg[R_DX];Rg[R_DX]:=M14Off;M14Off:=TmpW;
   End;
 End;
End;

{ ---------------- INT 21h ---------------- }

Procedure DosTerminate(Code: Word);
Begin
 ProcExit(CV,Code);
End;

Procedure ConEcho(C: Byte);
Begin
 ConPut(C);
End;

Function GetCh(Echo_: Boolean; Var Ch: Byte): Boolean;   { False : bloque }
Var K: Word;
Begin
 GetCh:=False;
 If Not KqHas Then Begin CpuBlock:=True;Exit;End;
 K:=KqGet;
 Ch:=K And 255;
 If (K And 255)=0 Then Begin KqGet;End;
 If Ch=3 Then Begin ConStr('^C');ConLn;DosTerminate($FF);CpuBlock:=True;Exit;End;
 If Echo_ And (Ch<>0) Then ConEcho(Ch);
 GetCh:=True;
End;

Function ReadLineStd(Max: Integer): Boolean;   { saisie de ligne pour AH=0Ah / STDIN ; False : bloque }
Var K: Word; C: Byte;
Begin
 ReadLineStd:=False;
 If Not CV^.LnActive Then Begin CV^.LnActive:=True;CV^.LnBuf:='';End;
 While KqHas Do Begin
  K:=KqGet;C:=K And 255;
  If C=0 Then Continue;
  If C=3 Then Begin ConStr('^C');ConLn;CV^.LnActive:=False;DosTerminate($FF);CpuBlock:=True;Exit;End;
  If C=13 Then Begin ConLn;CV^.LnActive:=False;ReadLineStd:=True;Exit;End;
  If C=8 Then Begin
   If Length(CV^.LnBuf)>0 Then Begin Delete(CV^.LnBuf,Length(CV^.LnBuf),1);ConPut(8);ConPut(32);ConPut(8);End;
  End Else If (C>=32) And (Length(CV^.LnBuf)<Max-1) Then Begin CV^.LnBuf:=CV^.LnBuf+Chr(C);ConEcho(C);End
  Else If C>=32 Then Beep;
 End;
 CpuBlock:=True;
End;

Function DosOpenFile(Const VP: String; Mode: Byte; Create: Boolean; Var H: Integer): Word;
Var R: String; Fi: Integer; U: String;
Begin
 DosOpenFile:=0;
 U:=Upper(VP);
 Fi:=FhAlloc(CV);
 If Fi<0 Then Begin DosOpenFile:=4;Exit;End;
 If (U='NUL') Or (Copy(U,Length(U)-3,4)='\NUL') Then Begin
  CV^.Files[Fi].Used:=True;CV^.Files[Fi].Dev:=2;CV^.Files[Fi].Owner:=CV^.PSP;H:=Fi;Exit;
 End;
 If (U='CON') Or (Copy(U,Length(U)-3,4)='\CON') Then Begin
  CV^.Files[Fi].Used:=True;CV^.Files[Fi].Dev:=1;CV^.Files[Fi].Owner:=CV^.PSP;H:=Fi;Exit;
 End;
 If (U='PRN') Or (U='LPT1') Then Begin CV^.Files[Fi].Used:=True;CV^.Files[Fi].Dev:=3;CV^.Files[Fi].Owner:=CV^.PSP;H:=Fi;Exit;End;
 R:=V2R(VP);
 {$I-}
 Assign(CV^.Files[Fi].F,R);
 If Create Then Begin FileMode:=2;Rewrite(CV^.Files[Fi].F,1);End
 Else Begin
  If Not FileExists(R) Then Begin
   If DirExists(R) Then DosOpenFile:=5 Else DosOpenFile:=2;Exit;
  End;
  Case Mode And 7 Of 0: FileMode:=0;1: FileMode:=1;Else FileMode:=2;End;
  Reset(CV^.Files[Fi].F,1);
  If IOResult<>0 Then Begin FileMode:=0;Reset(CV^.Files[Fi].F,1);End;
 End;
 {$I+}
 If IOResult<>0 Then Begin DosOpenFile:=IfThen_(Create,5,2);Exit;End;
 CV^.Files[Fi].Used:=True;CV^.Files[Fi].Dev:=0;CV^.Files[Fi].Name:=VP;CV^.Files[Fi].Owner:=CV^.PSP;
 H:=Fi;
End;

Procedure DosWriteH(H: Integer; Seg,Off: Word; N: Word);
Var I: Integer; Got: Word; A: LongInt;
Begin
 If (H<0) Or (H>=MAXFH) Or Not CV^.Files[H].Used Then Begin DosSetErr(6);Exit;End;
 If (CV^.Files[H].Dev=1) Or (H=1) Or (H=2) Then Begin
  For I:=0 To N-1 Do ConPut(RdB(Lin(Seg,Off+I)));
  Rg[R_AX]:=N;Exit;
 End;
 If CV^.Files[H].Dev<>0 Then Begin Rg[R_AX]:=N;Exit;End;
 If H<5 Then Begin Rg[R_AX]:=N;Exit;End;
 A:=Lin(Seg,Off);
 If A+N>$100000 Then N:=$100000-A;
 If N=0 Then Begin
  {$I-}Truncate(CV^.Files[H].F);{$I+}
  Rg[R_AX]:=0;Exit;
 End;
 {$I-}
 BlockWrite(CV^.Files[H].F,Mem^[A],N,Got);
 {$I+}
 If IOResult<>0 Then Begin DosSetErr(5);Exit;End;
 Rg[R_AX]:=Got;
End;

Procedure DosReadH(H: Integer; Seg,Off: Word; N: Word);
Var Got: Word; A: LongInt; I,K: Integer;
Begin
 If (H<0) Or (H>=MAXFH) Or Not CV^.Files[H].Used Then Begin DosSetErr(6);Exit;End;
 If (CV^.Files[H].Dev=1) Or (H=0) Then Begin
  { entree standard : lecture de ligne }
  If CV^.StdinPos>=Length(CV^.StdinLn) Then Begin
   If Not ReadLineStd(120) Then Exit;
   CV^.StdinLn:=CV^.LnBuf+#13#10;CV^.StdinPos:=0;
  End;
  K:=0;
  While (K<N) And (CV^.StdinPos<Length(CV^.StdinLn)) Do Begin
   WrB(Lin(Seg,Off+K),Ord(CV^.StdinLn[CV^.StdinPos+1]));Inc(K);Inc(CV^.StdinPos);
  End;
  Rg[R_AX]:=K;Exit;
 End;
 If CV^.Files[H].Dev<>0 Then Begin Rg[R_AX]:=0;Exit;End;
 A:=Lin(Seg,Off);
 If A+N>$100000 Then N:=$100000-A;
 {$I-}
 BlockRead(CV^.Files[H].F,Mem^[A],N,Got);
 {$I+}
 If IOResult<>0 Then Begin DosSetErr(5);Exit;End;
 Rg[R_AX]:=Got;
End;

Procedure DosExec(Const Path,Tail: String; Seg,Off: Word);
Var Res: Integer; N: Integer; VP: String; Cand: String; K: Integer; Ok: Boolean;
Begin
 VP:=DosPath(CV,Path);
 If ExtOf(VP)='' Then Begin
  Ok:=False;
  For K:=1 To 3 Do Begin
   Case K Of 1: Cand:=VP+'.COM';2: Cand:=VP+'.EXE';Else Cand:=VP+'.BAT';End;
   If FileExists(V2R(Cand)) Then Begin VP:=Cand;Ok:=True;Break;End;
  End;
 End;
 If CV^.NCtx>=MAXCTX Then Begin DosSetErr(8);Exit;End;
 N:=CV^.NCtx+1;
 Move(Rg,CV^.Ctx[N].Rg,SizeOf(Rg));Move(Sg,CV^.Ctx[N].Sg,SizeOf(Sg));
 CV^.Ctx[N].IP:=IPr;CV^.Ctx[N].Fl:=GetFlags;CV^.Ctx[N].PSP:=CV^.PSP;CV^.Ctx[N].DTA:=CV^.DTA;
 Res:=LoadProgram(CV,VP,Tail);
 If Res<>LD_OK Then Begin
  If Res=LD_WIN16 Then Res:=11;
  Move(CV^.Ctx[N].Rg,Rg,SizeOf(Rg));Move(CV^.Ctx[N].Sg,Sg,SizeOf(Sg));
  IPr:=CV^.Ctx[N].IP;CV^.PSP:=CV^.Ctx[N].PSP;
  DosSetErr(Res);Exit;
 End;
 CV^.NCtx:=N;
 fCF:=False;
End;

Procedure Int21;
Var AH,AL,B: Byte; K: Word; S: String; H,I,Slot: Integer; Cnt: Word; A: LongInt; Err: Word; Mx: Word;
    Y,M,D,Dw: Word; Hh,Mm,Ss,Cs: Word; Df: LongInt; Sg_: Word; Pth,Dir,Pat: String; Tail: String;
    P: Integer; Pos_: LongInt; Fs: LongInt; Ent: Boolean; Tm: LongInt; Dt: DateTime; B2: LongInt;
Begin
 AH:=Rg[R_AX] Shr 8;AL:=Rg[R_AX] And 255;
 fCF:=False;
 Case AH Of
  $00: DosTerminate(0);
  $01: If GetCh(True,B) Then SetR8(0,B);
  $02: Begin ConPut(Rg[R_DX] And 255);SetR8(0,Rg[R_DX] And 255);End;
  $03,$04,$05: ;
  $06: Begin
     If (Rg[R_DX] And 255)=$FF Then Begin
      If KqHas Then Begin K:=KqGet;SetR8(0,K And 255);fZF:=False;End Else Begin fZF:=True;SetR8(0,0);End;
     End Else ConPut(Rg[R_DX] And 255);
    End;
  $07,$08: If GetCh(False,B) Then SetR8(0,B);
  $09: Begin
     A:=Lin(Sg[SG_DS],Rg[R_DX]);I:=0;
     While (Mem^[(A+I) And $FFFFF]<>$24) And (I<65000) Do Begin ConPut(Mem^[(A+I) And $FFFFF]);Inc(I);End;
     SetR8(0,$24);
    End;
  $0A: Begin
     A:=Lin(Sg[SG_DS],Rg[R_DX]);
     If ReadLineStd(Mem^[A]) Then Begin
      Mem^[A+1]:=Length(CV^.LnBuf);
      For I:=1 To Length(CV^.LnBuf) Do Mem^[A+1+I]:=Ord(CV^.LnBuf[I]);
      Mem^[A+2+Length(CV^.LnBuf)]:=13;
     End;
    End;
  $0B: If KqHas Then SetR8(0,$FF) Else SetR8(0,0);
  $0C: Begin
     CV^.KH:=CV^.KT;
     Case AL Of
      1: If GetCh(True,B) Then SetR8(0,B);
      6: Begin If (Rg[R_DX] And 255)<>$FF Then ConPut(Rg[R_DX] And 255);End;
      7,8: If GetCh(False,B) Then SetR8(0,B);
      $A: Begin
          A:=Lin(Sg[SG_DS],Rg[R_DX]);
          If ReadLineStd(Mem^[A]) Then Begin
           Mem^[A+1]:=Length(CV^.LnBuf);
           For I:=1 To Length(CV^.LnBuf) Do Mem^[A+1+I]:=Ord(CV^.LnBuf[I]);
           Mem^[A+2+Length(CV^.LnBuf)]:=13;
          End;
         End;
     End;
    End;
  $0D: ;
  $0E: SetR8(0,26);
  $19: SetR8(0,Ord(UpCase(CV^.CurDir[1]))-65);
  $1A: CV^.DTA:=Lin(Sg[SG_DS],Rg[R_DX]);
  $1B: Begin SetR8(0,4);Rg[R_CX]:=512;Rg[R_DX]:=32000;Sg[SG_DS]:=$F000;Rg[R_BX]:=$0400;End;
  $1C: Begin SetR8(0,4);Rg[R_CX]:=512;Rg[R_DX]:=32000;Sg[SG_DS]:=$F000;Rg[R_BX]:=$0400;End;
  $25: Begin WrW(AL*4,Rg[R_DX]);WrW(AL*4+2,Sg[SG_DS]);End;
  $2A: Begin
     GetDate(Y,M,D,Dw);Rg[R_CX]:=Y;Rg[R_DX]:=(M Shl 8) Or D;SetR8(0,Dw);
    End;
  $2B: SetR8(0,0);
  $2C: Begin GetTime(Hh,Mm,Ss,Cs);Rg[R_CX]:=(Hh Shl 8) Or Mm;Rg[R_DX]:=(Ss Shl 8) Or Cs;End;
  $2D: SetR8(0,0);
  $2E: ;
  $2F: Begin Sg[SG_ES]:=CV^.DTA Shr 4;Rg[R_BX]:=CV^.DTA And $F;End;
  $30: Begin If DosV3 Then Rg[R_AX]:=$0A03 Else Rg[R_AX]:=$0005;Rg[R_BX]:=$FF00;Rg[R_CX]:=0;End;
  $31: Begin DosTerminate(AL);End;
  $33: Case AL Of
     0: Rg[R_DX]:=Rg[R_DX] And $FF00;
     1: ;
     5: Rg[R_DX]:=(Rg[R_DX] And $FF00) Or 3;
     6: Begin Rg[R_BX]:=$0005;Rg[R_DX]:=0;End;
    End;
  $34: Begin Sg[SG_ES]:=$0050;Rg[R_BX]:=$0000;End;
  $35: Begin Rg[R_BX]:=RdW(AL*4);Sg[SG_ES]:=RdW(AL*4+2);End;
  $36: Begin Rg[R_AX]:=4;Rg[R_BX]:=Min2(60000,DiskFree(0) Div 2048);If Rg[R_BX]=0 Then Rg[R_BX]:=20000;Rg[R_CX]:=512;Rg[R_DX]:=60000;End;
  $38: Begin
     If AL=0 Then Begin
      A:=Lin(Sg[SG_DS],Rg[R_DX]);
      WrW(A,Ord(DateFmt));Mem^[A+2]:=Ord(CurSym[1]);Mem^[A+3]:=0;
      Mem^[A+7]:=Ord(ThouSep[1]);Mem^[A+8]:=0;Mem^[A+9]:=Ord(DecSep[1]);Mem^[A+10]:=0;
      Mem^[A+11]:=Ord(DateSep[1]);Mem^[A+12]:=0;Mem^[A+13]:=Ord(TimeSep[1]);Mem^[A+14]:=0;
      Mem^[A+17]:=Ord(Clock24)*1;
      Rg[R_BX]:=1;
     End;
    End;
  $39: Begin Pth:=DosPath(CV,RdZ(Sg[SG_DS],Rg[R_DX]));{$I-}MkDir(V2R(Pth));{$I+}If IOResult<>0 Then DosSetErr(3);End;
  $3A: Begin Pth:=DosPath(CV,RdZ(Sg[SG_DS],Rg[R_DX]));{$I-}RmDir(V2R(Pth));{$I+}If IOResult<>0 Then DosSetErr(5);End;
  $3B: Begin
     Pth:=DosPath(CV,RdZ(Sg[SG_DS],Rg[R_DX]));
     If VDirExists(Pth) Then CV^.CurDir:=Pth Else DosSetErr(3);
    End;
  $3C: Begin
     Pth:=DosPath(CV,RdZ(Sg[SG_DS],Rg[R_DX]));
     Err:=DosOpenFile(Pth,2,True,H);
     If Err<>0 Then DosSetErr(Err) Else Rg[R_AX]:=H;
    End;
  $3D: Begin
     Pth:=DosPath(CV,RdZ(Sg[SG_DS],Rg[R_DX]));
     Err:=DosOpenFile(Pth,AL,False,H);
     If Err<>0 Then DosSetErr(Err) Else Rg[R_AX]:=H;
    End;
  $3E: Begin
     H:=Rg[R_BX];
     If (H<0) Or (H>=MAXFH) Or Not CV^.Files[H].Used Then DosSetErr(6) Else FhClose(CV,H);
    End;
  $3F: DosReadH(Rg[R_BX],Sg[SG_DS],Rg[R_DX],Rg[R_CX]);
  $40: DosWriteH(Rg[R_BX],Sg[SG_DS],Rg[R_DX],Rg[R_CX]);
  $41: Begin
     Pth:=V2R(DosPath(CV,RdZ(Sg[SG_DS],Rg[R_DX])));
     If Not FileExists(Pth) Then DosSetErr(2) Else Begin
      {$I-}Assign(CV^.Files[0].F,Pth);Erase(CV^.Files[0].F);{$I+}
      If IOResult<>0 Then DosSetErr(5);
     End;
    End;
  $42: Begin
     H:=Rg[R_BX];
     If (H<5) Or (H>=MAXFH) Or Not CV^.Files[H].Used Or (CV^.Files[H].Dev<>0) Then DosSetErr(6)
     Else Begin
      Pos_:=LongInt((LongWord(Rg[R_CX]) Shl 16) Or Rg[R_DX]);
      {$I-}
      Case AL Of
       0: ;
       1: Pos_:=FilePos(CV^.Files[H].F)+Pos_;
       2: Pos_:=FileSize(CV^.Files[H].F)+Pos_;
      End;
      If Pos_<0 Then Pos_:=0;
      Seek(CV^.Files[H].F,Pos_);
      {$I+}
      If IOResult<>0 Then DosSetErr(1) Else Begin Rg[R_DX]:=(Pos_ Shr 16) And $FFFF;Rg[R_AX]:=Pos_ And $FFFF;End;
     End;
    End;
  $43: Begin
     Pth:=V2R(DosPath(CV,RdZ(Sg[SG_DS],Rg[R_DX])));
     If AL=0 Then Begin
      If DirExists(Pth) Then Rg[R_CX]:=$10 Else If FileExists(Pth) Then Rg[R_CX]:=$20 Else DosSetErr(2);
     End;
    End;
  $44: Begin
     H:=Rg[R_BX];
     Case AL Of
      0: Begin
          If (H<0) Or (H>=MAXFH) Or Not CV^.Files[H].Used Then DosSetErr(6)
          Else If (H<=2) Or (CV^.Files[H].Dev=1) Then Rg[R_DX]:=$80D3
          Else If CV^.Files[H].Dev=0 Then Rg[R_DX]:=$0002 Else Rg[R_DX]:=$80C0;
         End;
      1: ;
      6: SetR8(0,$FF);
      7: SetR8(0,$FF);
      8: Rg[R_AX]:=1;
      $B: ;
     Else DosSetErr(1);
     End;
    End;
  $45: Begin
     H:=Rg[R_BX];I:=FhAlloc(CV);
     If (I<0) Or (H<0) Or (H>=MAXFH) Or Not CV^.Files[H].Used Then DosSetErr(6)
     Else Begin
      CV^.Files[I].Used:=True;CV^.Files[I].Dev:=CV^.Files[H].Dev;CV^.Files[I].Owner:=CV^.PSP;
      If CV^.Files[H].Dev=0 Then Begin CV^.Files[I].Dev:=1;End;
      Rg[R_AX]:=I;
     End;
    End;
  $46: Begin Rg[R_AX]:=Rg[R_AX];End;
  $47: Begin
     Pth:=Copy(CV^.CurDir,4,200);
     WrZ(Sg[SG_DS],Rg[R_SI],Pth);Rg[R_AX]:=$0100;
    End;
  $48: Begin
     Cnt:=ArenaAlloc(CV,Rg[R_BX],CV^.PSP);
     If Cnt=0 Then Begin Rg[R_BX]:=ArenaLargest(CV);DosSetErr(8);End Else Rg[R_AX]:=Cnt;
    End;
  $49: If Not ArenaFree(CV,Sg[SG_ES]) Then DosSetErr(9);
  $4A: Begin
     If Not ArenaResize(CV,Sg[SG_ES],Rg[R_BX],Mx) Then Begin Rg[R_BX]:=Mx;DosSetErr(8);End;
    End;
  $4B: Begin
     Pth:=RdZ(Sg[SG_DS],Rg[R_DX]);
     A:=Lin(Sg[SG_ES],Rg[R_BX]);
     Sg_:=RdW(A+4);Cnt:=RdW(A+2);
     Tail:='';
     If Sg_<>0 Then Begin
      I:=RdB(Lin(Sg_,Cnt));
      For P:=1 To I Do Tail:=Tail+Chr(RdB(Lin(Sg_,Cnt+P)));
     End;
     If AL=0 Then DosExec(Pth,Tail,Sg[SG_ES],Rg[R_BX]) Else DosSetErr(1);
    End;
  $4C: DosTerminate(AL);
  $4D: Begin Rg[R_AX]:=CV^.LastExit And $FF;End;
  $4E: Begin
     Pth:=DosPath(CV,RdZ(Sg[SG_DS],Rg[R_DX]));
     P:=Length(Pth);While (P>0) And (Pth[P]<>'\') Do Dec(P);
     Dir:=Copy(Pth,1,P-1);If Length(Dir)<3 Then Dir:=Copy(Pth,1,3);Pat:=Copy(Pth,P+1,14);
     Slot:=-1;
     For I:=0 To 7 Do If Not CV^.Finds[I].Used Then Begin Slot:=I;Break;End;
     If Slot<0 Then Slot:=0;
     CV^.Finds[Slot].Used:=True;CV^.Finds[Slot].Pat:=Pat;CV^.Finds[Slot].Attr:=Rg[R_CX] And $FF;
     FindFirst(JoinPath(V2R(Dir),'*'),AnyFile,CV^.Finds[Slot].SR);
     If Not FindNextMatch(CV,Slot,True,Dir) Then Begin DosSetErr(18);CV^.Finds[Slot].Used:=False;End;
    End;
  $4F: Begin
     Slot:=RdB(CV^.DTA)-1;
     If (Slot<0) Or (Slot>7) Or Not CV^.Finds[Slot].Used Then DosSetErr(18)
     Else Begin
      FindNext(CV^.Finds[Slot].SR);
      If Not FindNextMatch(CV,Slot,False,'') Then Begin DosSetErr(18);CV^.Finds[Slot].Used:=False;End;
     End;
    End;
  $52: Begin   { liste des listes (SYSVARS) simulee dans la ROM }
      If TraceOn Then StepLeft:=3000;
      A:=Lin(ROMSEG,$0F02);                    { A = ES:BX }
      For I:=-2 To $50 Do WrB(A+I,0);
      WrW(A-2,CV^.Blk[1].Seg-1);               { premier MCB }
      WrW(A,$FFFF);WrW(A+2,$FFFF);             { DPB : aucun }
      WrW(A+4,$4000);WrW(A+6,ROMSEG);          { SFT }
      B2:=Lin(ROMSEG,$4000);
      For I:=0 To 64*$35+6 Do WrB(B2+I,0);
      WrW(B2,$FFFF);WrW(B2+2,$FFFF);WrW(B2+4,64);
      WrW(A+$10,512);                          { taille de secteur max }
      WrW(A+$12,$FFFF);WrW(A+$14,$FFFF);       { tampons }
      WrW(A+$16,$FFFF);WrW(A+$18,$FFFF);       { CDS }
      WrW(A+$1A,$FFFF);WrW(A+$1C,$FFFF);       { FCB }
      WrB(A+$20,3);WrB(A+$21,5);               { unites, LASTDRIVE }
      WrW(A+$22,$FFFF);WrW(A+$24,$FFFF);       { en-tete NUL : suivant }
      WrW(A+$26,$8004);
      For I:=0 To 7 Do WrB(A+$2A+I,Ord('NUL     '[I+1]));
      Sg[SG_ES]:=ROMSEG;Rg[R_BX]:=$0F02;
     End;
  $50: CV^.PSP:=Rg[R_BX];
  $51,$62: Rg[R_BX]:=CV^.PSP;
  $54: SetR8(0,0);
  $56: Begin
     Pth:=V2R(DosPath(CV,RdZ(Sg[SG_DS],Rg[R_DX])));
     Dir:=V2R(DosPath(CV,RdZ(Sg[SG_ES],Rg[R_DI])));
     {$I-}Assign(CV^.Files[0].F,Pth);Rename(CV^.Files[0].F,Dir);{$I+}
     If IOResult<>0 Then DosSetErr(5);
    End;
  $57: Begin
     H:=Rg[R_BX];
     If (H<5) Or (H>=MAXFH) Or Not CV^.Files[H].Used Or (CV^.Files[H].Dev<>0) Then DosSetErr(6)
     Else If AL=0 Then Begin
      {$I-}GetFTime(CV^.Files[H].F,Tm);{$I+}
      Rg[R_CX]:=Tm And $FFFF;Rg[R_DX]:=(Tm Shr 16) And $FFFF;
     End;
    End;
  $58: If AL=0 Then Rg[R_AX]:=0;
  $5A: Begin
     Pth:='C:\TMP'+IntStr(Random(9999))+'.TMP';
     Err:=DosOpenFile(Pth,2,True,H);
     If Err<>0 Then DosSetErr(Err) Else Begin Rg[R_AX]:=H;WrZ(Sg[SG_DS],Rg[R_DX]+Length(RdZ(Sg[SG_DS],Rg[R_DX])),'TMP.TMP');End;
    End;
  $5D,$5E,$5F: DosSetErr(1);
  $60: Begin
     Pth:=DosPath(CV,RdZ(Sg[SG_DS],Rg[R_SI]));WrZ(Sg[SG_ES],Rg[R_DI],Pth);
    End;
  $63: DosSetErr(1);
  $65: DosSetErr(1);
  $66: Begin Rg[R_BX]:=437;Rg[R_DX]:=437;End;
  $67: ;
  $68,$6A: ;
  $6C: Begin
     Pth:=DosPath(CV,RdZ(Sg[SG_DS],Rg[R_SI]));
     Err:=DosOpenFile(Pth,Rg[R_BX] And 7,(Rg[R_DX] And $10)<>0,H);
     If (Err=2) And ((Rg[R_DX] And $10)<>0) Then Err:=DosOpenFile(Pth,Rg[R_BX] And 7,True,H);
     If Err<>0 Then DosSetErr(Err) Else Begin Rg[R_AX]:=H;Rg[R_CX]:=1;End;
    End;
 Else DosSetErr(1);
 End;
End;

{ ---------------- repartition des interruptions ---------------- }


Var RingDumped: Boolean; MemF: File;

{ ---------------- EMS 4.0 (LIM) : INT 67h + EMMXXXX0 ---------------- }
Var EmsOnFlag: Boolean;

Const
 EMS_SEG   = $F100;
 EMS_FRAME = $E000;
 EMS_PGSZ  = 16384;
 EMS_TOTAL = 1024;      { 16 Mo }
 EMS_NPHYS = 24;        { 4 pages cadre E000 + 20 pages mappables en memoire conventionnelle (EEMS) }
 EMS_CONV0 = $5000;

Type
 TEmsH = Record
  Used : Boolean;
  N    : Integer;
  Pg   : Array Of Pointer;
  Name : String[8];
  SvOk : Boolean;
  SvH,SvL : Array[0..EMS_NPHYS-1] Of Integer;
 End;

Var
 EmsH    : Array[0..255] Of TEmsH;
 EmsUsed : Integer;
 EmsMapH,EmsMapL : Array[0..EMS_NPHYS-1] Of Integer;
 EmsShadow : Array[0..EMS_NPHYS-1] Of Pointer;
 EmsCur : Integer;
 EmsAltH,EmsAltL : Array[1..7,0..EMS_NPHYS-1] Of Integer;
 EmsAltUsed : Array[1..7] Of Boolean;
 EmsLastArea : LongInt;
 EmsInit : Boolean;

Procedure EmsReset;
Var I,J: Integer;
Begin
 For I:=0 To 255 Do Begin
  If EmsInit Then For J:=0 To High(EmsH[I].Pg) Do If EmsH[I].Pg[J]<>Nil Then FreeMem(EmsH[I].Pg[J]);
  SetLength(EmsH[I].Pg,0);EmsH[I].Used:=False;EmsH[I].N:=0;EmsH[I].Name:='';EmsH[I].SvOk:=False;
 End;
 EmsH[0].Used:=True;
 For I:=0 To EMS_NPHYS-1 Do Begin
  If EmsInit And (EmsShadow[I]<>Nil) Then FreeMem(EmsShadow[I]);
  EmsShadow[I]:=Nil;EmsMapH[I]:=-1;EmsMapL[I]:=0;
 End;
 EmsUsed:=0;EmsInit:=True;EmsCur:=0;EmsLastArea:=0;
 For I:=1 To 7 Do EmsAltUsed[I]:=False;
End;

Function EmsPhysSeg(P: Integer): Word;
Begin
 If P<4 Then EmsPhysSeg:=EMS_FRAME+P*$400 Else EmsPhysSeg:=EMS_CONV0+(P-4)*$400;
End;

Function EmsSegToPhys(Sg_: Word): Integer;
Var I: Integer;
Begin
 EmsSegToPhys:=-1;
 For I:=0 To EMS_NPHYS-1 Do If EmsPhysSeg(I)=Sg_ Then EmsSegToPhys:=I;
End;

Function EmsWin(P: Integer): LongInt;
Begin
 EmsWin:=LongInt(EmsPhysSeg(P))*16;
End;

Procedure EmsFlush(P: Integer);
Begin
 If EmsMapH[P]>=0 Then Move(Mem^[EmsWin(P)],EmsH[EmsMapH[P]].Pg[EmsMapL[P]]^,EMS_PGSZ);
End;

Procedure EmsLoadWin(P: Integer);
Begin
 If EmsMapH[P]>=0 Then Move(EmsH[EmsMapH[P]].Pg[EmsMapL[P]]^,Mem^[EmsWin(P)],EMS_PGSZ);
End;

Function EmsMapPage(P,H,L: Integer): Integer;
Begin
 EmsMapPage:=0;
 If (P<0) Or (P>=EMS_NPHYS) Then Begin EmsMapPage:=$8B;Exit;End;
 If L=-1 Then Begin
  EmsFlush(P);
  If (EmsMapH[P]>=0) And (EmsShadow[P]<>Nil) Then Move(EmsShadow[P]^,Mem^[EmsWin(P)],EMS_PGSZ);
  EmsMapH[P]:=-1;Exit;
 End;
 If (H<0) Or (H>255) Or Not EmsH[H].Used Then Begin EmsMapPage:=$83;Exit;End;
 If (L<0) Or (L>=EmsH[H].N) Then Begin EmsMapPage:=$8A;Exit;End;
 EmsFlush(P);
 If (P>=4) And (EmsMapH[P]<0) Then Begin
  If EmsShadow[P]=Nil Then GetMem(EmsShadow[P],EMS_PGSZ);
  Move(Mem^[EmsWin(P)],EmsShadow[P]^,EMS_PGSZ);
 End;
 EmsMapH[P]:=H;EmsMapL[P]:=L;EmsLoadWin(P);
End;

Procedure EmsFlushAll;
Var P: Integer;
Begin
 For P:=0 To EMS_NPHYS-1 Do EmsFlush(P);
End;

Procedure EmsLoadAll;
Var P: Integer;
Begin
 For P:=0 To EMS_NPHYS-1 Do EmsLoadWin(P);
End;

Function EmsAlloc(H,N: Integer): Boolean;
Var I: Integer;
Begin
 EmsAlloc:=False;
 SetLength(EmsH[H].Pg,N);
 For I:=0 To N-1 Do Begin GetMem(EmsH[H].Pg[I],EMS_PGSZ);FillChar(EmsH[H].Pg[I]^,EMS_PGSZ,0);End;
 EmsH[H].N:=N;EmsH[H].Used:=True;Inc(EmsUsed,N);
 EmsAlloc:=True;
End;

Procedure EmsFree(H: Integer);
Var I,P: Integer;
Begin
 For P:=0 To EMS_NPHYS-1 Do If EmsMapH[P]=H Then Begin EmsMapH[P]:=-1;End;
 For I:=0 To EmsH[H].N-1 Do If EmsH[H].Pg[I]<>Nil Then FreeMem(EmsH[H].Pg[I]);
 SetLength(EmsH[H].Pg,0);Dec(EmsUsed,EmsH[H].N);EmsH[H].N:=0;
 If H>0 Then EmsH[H].Used:=False;
 EmsH[H].Name:='';
End;

Function EmsByte(Typ,H: Integer; Idx: LongInt; Var Ok: Boolean): PByte;
Var L,O: Integer;
Begin
 Ok:=True;EmsByte:=Nil;
 If Typ=0 Then Begin EmsByte:=@Mem^[Idx And $FFFFF];Exit;End;
 L:=Idx Div EMS_PGSZ;O:=Idx Mod EMS_PGSZ;
 If (H<0) Or (H>255) Or Not EmsH[H].Used Or (L>=EmsH[H].N) Then Begin Ok:=False;Exit;End;
 EmsByte:=PByte(PtrUInt(EmsH[H].Pg[L])+O);
End;

Procedure EmsSaveCtx(A: LongInt);
Var P: Integer;
Begin
 For P:=0 To EMS_NPHYS-1 Do Begin WrW(A+P*4,Word(SmallInt(EmsMapH[P])));WrW(A+P*4+2,EmsMapL[P]);End;
End;

Procedure EmsRestoreCtx(A: LongInt);
Var P,H: Integer;
Begin
 For P:=0 To EMS_NPHYS-1 Do Begin
  H:=SmallInt(RdW(A+P*4));
  If H<0 Then EmsMapPage(P,0,-1) Else EmsMapPage(P,H,RdW(A+P*4+2));
 End;
End;

Procedure EmsSwitchSet(N: Integer; Area: LongInt);
Var P,K: Integer;
Begin
 If N=EmsCur Then Exit;
 EmsFlushAll;
 { sauvegarde du jeu courant }
 If EmsCur=0 Then Begin EmsSaveCtx(Area);EmsLastArea:=Area;End
 Else For P:=0 To EMS_NPHYS-1 Do Begin EmsAltH[EmsCur,P]:=EmsMapH[P];EmsAltL[EmsCur,P]:=EmsMapL[P];End;
 { activation du nouveau jeu }
 If N=0 Then EmsRestoreCtx(Area)
 Else For P:=0 To EMS_NPHYS-1 Do Begin
  K:=EmsAltH[N,P];
  If K<0 Then EmsMapPage(P,0,-1) Else EmsMapPage(P,K,EmsAltL[N,P]);
 End;
 EmsCur:=N;
End;

Procedure Ems67;
Var AH,AL: Byte; I,H,P,L,Cnt: Integer; A,A2: LongInt; Sv,Dv: Integer; Len: LongInt;
    St,Dt,Sh,Dh: Integer; So,Do_: LongInt; Ok1,Ok2: Boolean; B1,B2: PByte; Tmp: Byte; S: String;
 Procedure Err(E: Integer);
 Begin
  Rg[R_AX]:=(Rg[R_AX] And $FF) Or (E Shl 8);
 End;
 Procedure Okay;
 Begin
  Rg[R_AX]:=Rg[R_AX] And $FF;
 End;
Begin
 AH:=Rg[R_AX] Shr 8;AL:=Rg[R_AX] And 255;
 Okay;
 Case AH Of
  $40: ;
  $41: Rg[R_BX]:=EMS_FRAME;
  $42: Begin Rg[R_BX]:=EMS_TOTAL-EmsUsed;Rg[R_DX]:=EMS_TOTAL;End;
  $43,$5A: Begin
     Cnt:=Rg[R_BX];
     If (AH=$5A) And (AL>1) Then Begin Err($8F);Exit;End;
     If (Cnt=0) And (AH=$43) Then Begin Err($89);Exit;End;
     If Cnt>EMS_TOTAL Then Begin Err($87);Exit;End;
     If Cnt>EMS_TOTAL-EmsUsed Then Begin Err($88);Exit;End;
     H:=1;While (H<=255) And EmsH[H].Used Do Inc(H);
     If H>255 Then Begin Err($85);Exit;End;
     EmsAlloc(H,Cnt);Rg[R_DX]:=H;
    End;
  $44: Begin
     L:=SmallInt(Rg[R_BX]);
     I:=EmsMapPage(AL,Rg[R_DX],L);
     If I<>0 Then Err(I);
    End;
  $45: Begin
     H:=Rg[R_DX];
     If (H>255) Or Not EmsH[H].Used Then Begin Err($83);Exit;End;
     EmsFree(H);
    End;
  $46: Rg[R_AX]:=$0040;
  $47: Begin
     H:=Rg[R_DX];
     If (H>255) Or Not EmsH[H].Used Then Begin Err($83);Exit;End;
     For P:=0 To EMS_NPHYS-1 Do Begin EmsH[H].SvH[P]:=EmsMapH[P];EmsH[H].SvL[P]:=EmsMapL[P];End;
     EmsH[H].SvOk:=True;
    End;
  $48: Begin
     H:=Rg[R_DX];
     If (H>255) Or Not EmsH[H].Used Then Begin Err($83);Exit;End;
     If Not EmsH[H].SvOk Then Begin Err($8E);Exit;End;
     For P:=0 To EMS_NPHYS-1 Do
      If EmsH[H].SvH[P]<0 Then EmsMapPage(P,0,-1) Else EmsMapPage(P,EmsH[H].SvH[P],EmsH[H].SvL[P]);
    End;
  $4B: Begin
     Cnt:=0;For I:=0 To 255 Do If EmsH[I].Used Then Inc(Cnt);
     Rg[R_BX]:=Cnt;
    End;
  $4C: Begin
     H:=Rg[R_DX];
     If (H>255) Or Not EmsH[H].Used Then Begin Err($83);Exit;End;
     Rg[R_BX]:=EmsH[H].N;
    End;
  $4D: Begin
     A:=Lin(Sg[SG_ES],Rg[R_DI]);Cnt:=0;
     For I:=0 To 255 Do If EmsH[I].Used Then Begin WrW(A,I);WrW(A+2,EmsH[I].N);Inc(A,4);Inc(Cnt);End;
     Rg[R_BX]:=Cnt;
    End;
  $4E: Case AL Of
     0: Begin
         A:=Lin(Sg[SG_ES],Rg[R_DI]);
         For P:=0 To EMS_NPHYS-1 Do Begin WrW(A+P*4,Word(SmallInt(EmsMapH[P])));WrW(A+P*4+2,EmsMapL[P]);End;
        End;
     1: Begin
         A:=Lin(Sg[SG_DS],Rg[R_SI]);
         For P:=0 To EMS_NPHYS-1 Do Begin
          H:=SmallInt(RdW(A+P*4));
          If H<0 Then EmsMapPage(P,0,-1) Else EmsMapPage(P,H,RdW(A+P*4+2));
         End;
        End;
     2: Begin
         A:=Lin(Sg[SG_ES],Rg[R_DI]);
         For P:=0 To EMS_NPHYS-1 Do Begin WrW(A+P*4,Word(SmallInt(EmsMapH[P])));WrW(A+P*4+2,EmsMapL[P]);End;
         A:=Lin(Sg[SG_DS],Rg[R_SI]);
         For P:=0 To EMS_NPHYS-1 Do Begin
          H:=SmallInt(RdW(A+P*4));
          If H<0 Then EmsMapPage(P,0,-1) Else EmsMapPage(P,H,RdW(A+P*4+2));
         End;
        End;
     3: Rg[R_AX]:=(Rg[R_AX] And $FF00) Or (EMS_NPHYS*4);
    Else Err($8F);
    End;
  $4F: Case AL Of
     0: Begin
         A2:=Lin(Sg[SG_DS],Rg[R_SI]);A:=Lin(Sg[SG_ES],Rg[R_DI]);
         Cnt:=RdW(A2);WrW(A,Cnt);
         For I:=0 To Cnt-1 Do Begin
          P:=EmsSegToPhys(RdW(A2+2+I*2));If P<0 Then P:=0;
          WrW(A+2+I*6,RdW(A2+2+I*2));WrW(A+4+I*6,Word(SmallInt(EmsMapH[P])));WrW(A+6+I*6,EmsMapL[P]);
         End;
        End;
     1: Begin
         A:=Lin(Sg[SG_DS],Rg[R_SI]);Cnt:=RdW(A);
         For I:=0 To Cnt-1 Do Begin
          P:=EmsSegToPhys(RdW(A+2+I*6));If P<0 Then P:=0;
          H:=SmallInt(RdW(A+4+I*6));
          If H<0 Then EmsMapPage(P,0,-1) Else EmsMapPage(P,H,RdW(A+6+I*6));
         End;
        End;
     2: Rg[R_AX]:=(Rg[R_AX] And $FF00) Or ((2+Rg[R_BX]*6) And 255);
    Else Err($8F);
    End;
  $50: Begin
     H:=Rg[R_DX];A:=Lin(Sg[SG_DS],Rg[R_SI]);
     If (H>255) Or Not EmsH[H].Used Then Begin Err($83);Exit;End;
     For I:=0 To Rg[R_CX]-1 Do Begin
      L:=SmallInt(RdW(A+I*4));
      If AL=0 Then P:=RdW(A+I*4+2) Else P:=EmsSegToPhys(RdW(A+I*4+2));
      If (P<0) Or (P>=EMS_NPHYS) Then Begin Err($8B);Exit;End;
      Sv:=EmsMapPage(P,H,L);
      If Sv<>0 Then Begin Err(Sv);Exit;End;
     End;
    End;
  $51: Begin
     H:=Rg[R_DX];Cnt:=Rg[R_BX];
     If (H>255) Or Not EmsH[H].Used Then Begin Err($83);Exit;End;
     If Cnt>EmsH[H].N Then Begin
      If Cnt-EmsH[H].N>EMS_TOTAL-EmsUsed Then Begin Err($88);Exit;End;
      SetLength(EmsH[H].Pg,Cnt);
      For I:=EmsH[H].N To Cnt-1 Do Begin GetMem(EmsH[H].Pg[I],EMS_PGSZ);FillChar(EmsH[H].Pg[I]^,EMS_PGSZ,0);End;
      Inc(EmsUsed,Cnt-EmsH[H].N);
     End Else If Cnt<EmsH[H].N Then Begin
      For P:=0 To EMS_NPHYS-1 Do If (EmsMapH[P]=H) And (EmsMapL[P]>=Cnt) Then EmsMapH[P]:=-1;
      For I:=Cnt To EmsH[H].N-1 Do FreeMem(EmsH[H].Pg[I]);
      Dec(EmsUsed,EmsH[H].N-Cnt);SetLength(EmsH[H].Pg,Cnt);
     End;
     EmsH[H].N:=Cnt;
    End;
  $52: Case AL Of
     0: Rg[R_AX]:=Rg[R_AX] And $FF00;
     1: ;
     2: Rg[R_AX]:=Rg[R_AX] And $FF00;
    Else Err($8F);
    End;
  $53: Begin
     H:=Rg[R_DX];
     If (H>255) Or Not EmsH[H].Used Then Begin Err($83);Exit;End;
     If AL=0 Then Begin
      A:=Lin(Sg[SG_ES],Rg[R_DI]);
      For I:=1 To 8 Do If I<=Length(EmsH[H].Name) Then Mem^[A+I-1]:=Ord(EmsH[H].Name[I]) Else Mem^[A+I-1]:=0;
     End Else If AL=1 Then Begin
      A:=Lin(Sg[SG_DS],Rg[R_SI]);S:='';
      For I:=0 To 7 Do If Mem^[A+I]<>0 Then S:=S+Chr(Mem^[A+I]);
      EmsH[H].Name:=S;
     End Else Err($8F);
    End;
  $54: Case AL Of
     0: Begin
         A:=Lin(Sg[SG_ES],Rg[R_DI]);Cnt:=0;
         For I:=0 To 255 Do If EmsH[I].Used Then Begin
          WrW(A,I);
          For P:=1 To 8 Do If P<=Length(EmsH[I].Name) Then Mem^[A+2+P-1]:=Ord(EmsH[I].Name[P]) Else Mem^[A+2+P-1]:=0;
          Inc(A,10);Inc(Cnt);
         End;
         Rg[R_AX]:=Cnt And $FF;
        End;
     1: Err($A0);
     2: Rg[R_BX]:=255;
    Else Err($8F);
    End;
  $57: Begin
     A:=Lin(Sg[SG_DS],Rg[R_SI]);
     Len:=LongInt(RdW(A))+LongInt(RdW(A+2)) Shl 16;
     St:=Mem^[A+4];Sh:=RdW(A+5);So:=RdW(A+7);
     If St=0 Then Sv:=RdW(A+9) Else Sv:=RdW(A+9);
     Dt:=Mem^[A+11];Dh:=RdW(A+12);Do_:=RdW(A+14);Dv:=RdW(A+16);
     EmsFlushAll;
     If St=0 Then So:=LongInt(Sv)*16+So Else So:=LongInt(Sv)*EMS_PGSZ+So;
     If Dt=0 Then Do_:=LongInt(Dv)*16+Do_ Else Do_:=LongInt(Dv)*EMS_PGSZ+Do_;
     If AL=0 Then Begin
      { deplacement (gere le chevauchement) }
      If (St=0) And (Dt=0) And (Do_>So) Then Begin
       For A2:=Len-1 Downto 0 Do Mem^[(Do_+A2) And $FFFFF]:=Mem^[(So+A2) And $FFFFF];
      End Else
       For A2:=0 To Len-1 Do Begin
        B1:=EmsByte(St,Sh,So+A2,Ok1);B2:=EmsByte(Dt,Dh,Do_+A2,Ok2);
        If Not (Ok1 And Ok2) Then Begin Err($8A);Break;End;
        B2^:=B1^;
       End;
     End Else If AL=1 Then Begin
      For A2:=0 To Len-1 Do Begin
       B1:=EmsByte(St,Sh,So+A2,Ok1);B2:=EmsByte(Dt,Dh,Do_+A2,Ok2);
       If Not (Ok1 And Ok2) Then Begin Err($8A);Break;End;
       Tmp:=B1^;B1^:=B2^;B2^:=Tmp;
      End;
     End Else Err($8F);
     EmsLoadAll;
    End;
  $58: Case AL Of
     0: Begin
         A:=Lin(Sg[SG_ES],Rg[R_DI]);
         For P:=0 To EMS_NPHYS-1 Do Begin WrW(A+P*4,EmsPhysSeg(P));WrW(A+P*4+2,P);End;
         Rg[R_CX]:=EMS_NPHYS;
        End;
     1: Rg[R_CX]:=EMS_NPHYS;
    Else Err($8F);
    End;
  $59: Case AL Of
     0: Begin
         A:=Lin(Sg[SG_ES],Rg[R_DI]);
         WrW(A,$400);WrW(A+2,0);WrW(A+4,EMS_NPHYS*4);WrW(A+6,0);WrW(A+8,0);
        End;
     1: Begin Rg[R_BX]:=EMS_TOTAL-EmsUsed;Rg[R_DX]:=EMS_TOTAL;End;
    Else Err($8F);
    End;
  $5B: Case AL Of
     0: Begin
         Rg[R_BX]:=(Rg[R_BX] And $FF00) Or EmsCur;
         If EmsCur=0 Then Begin Sg[SG_ES]:=EmsLastArea Shr 4;Rg[R_DI]:=EmsLastArea And 15;End;
        End;
     1: Begin
         I:=Rg[R_BX] And 255;
         If (I>7) Or ((I>0) And Not EmsAltUsed[I]) Then Begin Err($8F);Exit;End;
         EmsSwitchSet(I,Lin(Sg[SG_ES],Rg[R_DI]));
        End;
     2: Rg[R_DX]:=EMS_NPHYS*4;
     3: Begin
         I:=1;While (I<=7) And EmsAltUsed[I] Do Inc(I);
         If I>7 Then Rg[R_BX]:=Rg[R_BX] And $FF00 Else Begin
          EmsAltUsed[I]:=True;
          For P:=0 To EMS_NPHYS-1 Do Begin EmsAltH[I,P]:=-1;EmsAltL[I,P]:=0;End;
          Rg[R_BX]:=(Rg[R_BX] And $FF00) Or I;
         End;
        End;
     4: Begin
         I:=Rg[R_BX] And 255;
         If (I>=1) And (I<=7) Then Begin
          If EmsCur=I Then Err($8F) Else EmsAltUsed[I]:=False;
         End;
        End;
     5..8: Err($91);
    Else Err($8F);
    End;
 Else Err($84);
 End;
End;

Procedure EmsEnable(V: PVM);
Var I: Integer;
Begin
 If GetEnv('W2NOEMS')<>'' Then Exit;
 Mem:=V^.Mem;EmsReset;EmsOnFlag:=True;
 V^.Mem^[$67*4]:=0;V^.Mem^[$67*4+1]:=0;V^.Mem^[$67*4+2]:=0;V^.Mem^[$67*4+3]:=$F1;
 V^.Mem^[$F1000]:=$CF;
 For I:=1 To 8 Do V^.Mem^[$F1000+$A+I-1]:=Ord('EMMXXXX0'[I]);
 { table de configuration BIOS (INT 15h AH=C0h) : PC AT }
 V^.Mem^[$FE000]:=8;V^.Mem^[$FE001]:=0;V^.Mem^[$FE002]:=$FC;V^.Mem^[$FE003]:=1;V^.Mem^[$FE004]:=0;V^.Mem^[$FE005]:=$70;
End;

Procedure HleInt(N: Integer);
Var Cnt: Integer;
Begin
 If TraceOn And (N<>$21) Then Begin WriteLn(TraceF,'INT',HexStr(N,2),' AX=',HexStr(Rg[R_AX],4),' BX=',HexStr(Rg[R_BX],4),' CX=',HexStr(Rg[R_CX],4),' DX=',HexStr(Rg[R_DX],4),' CS:IP=',HexStr(Sg[SG_CS],4),':',HexStr(IPr,4));Flush(TraceF);End;
 Case N Of
  $08,$09,$1C,$23,$24,$1B,$28,$2A: ;
  $10: Int10;
  $11: Rg[R_AX]:=$0021;
  $12: Rg[R_AX]:=640;
  $13: Begin Rg[R_AX]:=(Rg[R_AX] And $FF) Or $0100;fCF:=True;End;
  $14: Rg[R_AX]:=$0000;
  $15: Begin
      Case Rg[R_AX] Shr 8 Of
       $88: Rg[R_AX]:=0;
       $C0: If EmsOnFlag Then Begin Rg[R_AX]:=0;Sg[SG_ES]:=$F000;Rg[R_BX]:=$E000;fCF:=False;End Else Begin Rg[R_AX]:=(Rg[R_AX] And $FF) Or $8600;fCF:=True;End;
       $4F: Begin fCF:=True;End;
       $86: fCF:=False;
      Else Begin Rg[R_AX]:=(Rg[R_AX] And $FF) Or $8600;fCF:=True;End;
      End;
     End;
  $16: Int16;
  $17: Rg[R_AX]:=(Rg[R_AX] And $FF) Or $9000;
  $1A: Int1A;
  $20: DosTerminate(0);
  $21: Begin
      If TraceOn Then Begin
       Write(TraceF,'INT21 AX=',HexStr(Rg[R_AX],4),' BX=',HexStr(Rg[R_BX],4),' CX=',HexStr(Rg[R_CX],4),
         ' DX=',HexStr(Rg[R_DX],4),' DS=',HexStr(Sg[SG_DS],4));
       If (Rg[R_AX] Shr 8) In [$39,$3A,$3B,$3C,$3D,$41,$43,$4B,$4E,$56,$5B] Then Write(TraceF,' [',RdZ(Sg[SG_DS],Rg[R_DX]),']');
      End;
      If TraceOn And ((Rg[R_AX] Shr 8)=$40) And (Rg[R_BX]=1) And Not RingDumped Then Begin
       RingDumped:=True;
       Assign(MemF,GetEnv('W2TRACE')+'.mem');Rewrite(MemF,1);BlockWrite(MemF,Mem^[0],$A0000);Close(MemF);
       For Cnt:=0 To $17F Do Begin
        If (Cnt And 15)=0 Then Write(TraceF,'MEM2B00 ',HexStr(Cnt,4),': ');
        Write(TraceF,HexStr(Mem^[Lin($0671,$8E00+Cnt)],2),' ');
        If (Cnt And 15)=15 Then WriteLn(TraceF);
       End;
       For Cnt:=0 To $7F Do Begin
        If (Cnt And 15)=0 Then Write(TraceF,'MEM6300 ',HexStr(Cnt,4),': ');
        Write(TraceF,HexStr(Mem^[Lin($0671,$6300+Cnt)],2),' ');
        If (Cnt And 15)=15 Then WriteLn(TraceF);
       End;
       Write(TraceF,'STACK ',HexStr(Sg[SG_SS],4),':',HexStr(Rg[R_SP],4),' BP=',HexStr(Rg[R_BP],4),' :');
       For Cnt:=0 To 47 Do Write(TraceF,' ',HexStr(RdW(Lin(Sg[SG_SS],Rg[R_SP]+Cnt*2)),4));
       WriteLn(TraceF);
       For Cnt:=1023 Downto 0 Do WriteLn(TraceF,'RING ',HexStr(Ring[(RingP-Cnt) And 1023] Shr 16,4),':',HexStr(Ring[(RingP-Cnt) And 1023] And $FFFF,4));
      End;
      Int21;
      If TraceOn Then Begin WriteLn(TraceF,' -> AX=',HexStr(Rg[R_AX],4),' CF=',Ord(fCF));Flush(TraceF);End;
     End;
  $27: DosTerminate(0);
  $29: ConPut(Rg[R_AX] And 255);
  $2F: Begin
      If Rg[R_AX]=$1680 Then Rg[R_AX]:=Rg[R_AX] And $FF00;
     End;
  $33: Int33;
  $67: Ems67;
 End;
End;

{$ENDIF}
{ ====================================================================== }
{          MS-DOS PROMPT : INTERPRETEUR DE COMMANDES ET FENETRE          }
{ ====================================================================== }

{$IFDEF FPC}

Const
 CM_M_CLOSE=1101; CM_M_COPY=1102; CM_M_PASTE=1103; CM_M_CLS=1104; CM_M_ABOUT=1105;
 CM_M_RESET=1106; CM_M_FULL=1107; CM_M_MARK=1108; CM_M_SCROLL=1109;
 COLW = 8; ROWH = 9;

Var LastCpuErr: String[80];

Procedure Win16Start(Const VPath,Tail: String); Forward;
Function DosCreate(Const Cmd: String; MaximizeIt: Boolean): PWindow; Forward;

Function EnvGet(V: PVM; Const Nm: String): String;
Var I,P: Integer; U: String;
Begin
 EnvGet:='';U:=Upper(Nm)+'=';
 For I:=1 To V^.NEnv Do
  If Copy(Upper(V^.EnvVars[I]),1,Length(U))=U Then Begin EnvGet:=Copy(V^.EnvVars[I],Length(U)+1,200);Exit;End;
End;

Procedure EnvSet(V: PVM; Const Nm,Val_: String);
Var I,K: Integer; U: String;
Begin
 U:=Upper(Nm)+'=';
 For I:=1 To V^.NEnv Do
  If Copy(Upper(V^.EnvVars[I]),1,Length(U))=U Then Begin
   If Val_='' Then Begin
    For K:=I To V^.NEnv-1 Do V^.EnvVars[K]:=V^.EnvVars[K+1];
    Dec(V^.NEnv);
   End Else V^.EnvVars[I]:=Upper(Nm)+'='+Val_;
   Exit;
  End;
 If (Val_<>'') And (V^.NEnv<32) Then Begin Inc(V^.NEnv);V^.EnvVars[V^.NEnv]:=Upper(Nm)+'='+Val_;End;
End;

Procedure ShellPrompt(V: PVM);
Var P: String; I: Integer; S: String; H,M,Sec,Y,Mo,D: Integer;
Begin
 If Not V^.Echo Then Exit;
 P:=EnvGet(V,'PROMPT');
 If P='' Then P:='$P$G';
 I:=1;
 While I<=Length(P) Do Begin
  If (P[I]='$') And (I<Length(P)) Then Begin
   Inc(I);
   Case UpCase(P[I]) Of
    'P': ConStr(V^.CurDir);
    'G': ConStr('>');
    'L': ConStr('<');
    'N': ConStr(Copy(V^.CurDir,1,1));
    'B': ConStr('|');
    'Q': ConStr('=');
    'E': ConPut(27);
    'H': ConPut(8);
    '_': ConLn;
    '$': ConStr('$');
    'D': Begin GetToday(Y,Mo,D);ConStr(DayShort(DayOfWeek(Y,Mo,D))+' '+DateStr(Y,Mo,D));End;
    'T': Begin GetNow(H,M,Sec);ConStr(TimeStr(H,M,Sec));End;
    'V': ConStr('MS-DOS 5.00');
   End;
  End Else ConPut(Ord(P[I]));
  Inc(I);
 End;
 V^.ShLine:='';V^.ShPos:=0;
End;

Function ShFindProg(V: PVM; Const Nm: String): String;
Var Cand: String; K,I: Integer; Dirs,D: String; P: Integer; Base: String;
 Function Try_(Const B: String): String;
 Var J: Integer; C: String;
 Begin
  Try_:='';
  If ExtOf(B)<>'' Then Begin If FileExists(V2R(B)) Then Try_:=B;Exit;End;
  For J:=1 To 3 Do Begin
   Case J Of 1: C:=B+'.COM';2: C:=B+'.EXE';Else C:=B+'.BAT';End;
   If FileExists(V2R(C)) Then Begin Try_:=C;Exit;End;
  End;
 End;
Begin
 ShFindProg:='';
 Base:=DosPath(V,Nm);
 Cand:=Try_(Base);
 If Cand<>'' Then Begin ShFindProg:=Cand;Exit;End;
 If (Pos('\',Nm)>0) Or (Pos(':',Nm)>0) Then Exit;
 Dirs:=EnvGet(V,'PATH');
 While Dirs<>'' Do Begin
  P:=Pos(';',Dirs);
  If P=0 Then Begin D:=Dirs;Dirs:='';End Else Begin D:=Copy(Dirs,1,P-1);Delete(Dirs,1,P);End;
  If D='' Then Continue;
  Cand:=Try_(DosPath(V,D+'\'+Nm));
  If Cand<>'' Then Begin ShFindProg:=Cand;Exit;End;
 End;
End;

Procedure ShDir(V: PVM; Const Arg: String);
Var SR: SearchRec; Dir,Pat,A: String; Wide,Bare: Boolean; NF,ND: Integer; Tot: LongInt; Ln: String;
    DT: DateTime; Nm,Ex: String; P,Col: Integer; Items: Array[1..300] Of String[14]; Cnt: Integer; Sz: Array[1..300] Of LongInt;
    IsD: Array[1..300] Of Boolean; Tms: Array[1..300] Of LongInt; I,J: Integer; T: String[14]; T2: LongInt; B2: Boolean; T3_: LongInt;
Begin
 Wide:=Pos('/W',Upper(Arg))>0;Bare:=Pos('/B',Upper(Arg))>0;
 A:=Trim(Arg);
 While (A<>'') And (A[1]='/') Do Begin P:=Pos(' ',A);If P=0 Then A:='' Else A:=Trim(Copy(A,P+1,200));End;
 P:=Pos(' /',A);If P>0 Then A:=Trim(Copy(A,1,P-1));
 If A='' Then A:='*';
 If VDirExists(DosPath(V,A)) Then Begin Dir:=DosPath(V,A);Pat:='*';End
 Else Begin
  Dir:=DosPath(V,A);P:=Length(Dir);While (P>0) And (Dir[P]<>'\') Do Dec(P);
  Pat:=Copy(Dir,P+1,14);Dir:=Copy(Dir,1,P-1);If Length(Dir)<3 Then Dir:=Copy(Dir,1,2)+'\';
  If Not VDirExists(Dir) Then Begin ConStr('File not found');ConLn;Exit;End;
 End;
 If Pat='*.*' Then Pat:='*';
 If Not Bare Then Begin
  ConLn;
  ConStr(' Volume in drive '+Dir[1]+' is '+IfThenS(VolNames[UpCase(Dir[1])]='','(none)',VolNames[UpCase(Dir[1])]));ConLn;
  ConStr(' Directory of '+Dir);ConLn;ConLn;
 End;
 Cnt:=0;
 FindFirst(JoinPath(V2R(Dir),'*'),AnyFile,SR);
 While (DosError=0) And (Cnt<300) Do Begin
  If (SR.Name[1]<>'.') And Short83(Upper(SR.Name)) And WildMatch(Pat,SR.Name) And ((SR.Attr And VolumeID)=0) Then Begin
   Inc(Cnt);Items[Cnt]:=Upper(SR.Name);Sz[Cnt]:=SR.Size;IsD[Cnt]:=(SR.Attr And Directory)<>0;Tms[Cnt]:=SR.Time;
  End;
  FindNext(SR);
 End;
 {$IFDEF FPC}FindClose(SR);{$ENDIF}
 For I:=2 To Cnt Do Begin
  T:=Items[I];T2:=Sz[I];B2:=IsD[I];T3_:=Tms[I];J:=I-1;
  While (J>=1) And ((IsD[J]<B2) Or ((IsD[J]=B2) And (Items[J]>T))) Do Begin
   Items[J+1]:=Items[J];Sz[J+1]:=Sz[J];IsD[J+1]:=IsD[J];Tms[J+1]:=Tms[J];Dec(J);
  End;
  Items[J+1]:=T;Sz[J+1]:=T2;IsD[J+1]:=B2;Tms[J+1]:=T3_;
 End;
 NF:=0;ND:=0;Tot:=0;Col:=0;
 For I:=1 To Cnt Do Begin
  Nm:=Items[I];
  If Bare Then Begin ConStr(Nm);ConLn;Continue;End;
  P:=Pos('.',Nm);
  If P=0 Then Begin Ex:='';End Else Begin Ex:=Copy(Nm,P+1,3);Nm:=Copy(Nm,1,P-1);End;
  If IsD[I] Then Inc(ND) Else Begin Inc(NF);Tot:=Tot+Sz[I];End;
  If Wide Then Begin
   ConStr(PadR(Items[I]+IfThenS(IsD[I],'\',''),16));Inc(Col);
   If Col=5 Then Begin ConLn;Col:=0;End;
  End Else Begin
   UnpackTime(Tms[I],DT);
   Ln:=PadR(Nm,9)+PadR(Ex,4);
   If IsD[I] Then Ln:=Ln+'<DIR>        ' Else Ln:=Ln+PadL(IntStr(Sz[I]),13);
   Ln:=Ln+' '+DateStr(DT.Year,DT.Month,DT.Day)+'  '+TimeStr(DT.Hour,DT.Min,-1);
   ConStr(Ln);ConLn;
  End;
 End;
 If Wide And (Col>0) Then ConLn;
 If Not Bare Then Begin
  ConStr(PadL(IntStr(NF),10)+' file(s) '+PadL(IntStr(Tot),12)+' bytes');ConLn;
  ConStr(PadL(IntStr(ND),10)+' dir(s)  '+PadL(IntStr(DiskFree(0)),12)+' bytes free');ConLn;
 End;
End;

Procedure ShType(V: PVM; Const Arg: String);
Var F: File; Buf: Array[0..511] Of Byte; N: Word; I: Integer; Pth: String;
Begin
 Pth:=V2R(DosPath(V,Trim(Arg)));
 If Not FileExists(Pth) Then Begin ConStr('File not found - '+Trim(Arg));ConLn;Exit;End;
 {$I-}
 FileMode:=0;Assign(F,Pth);Reset(F,1);
 Repeat
  BlockRead(F,Buf,512,N);
  For I:=0 To N-1 Do If Buf[I]<>26 Then ConPut(Buf[I]);
 Until N=0;
 Close(F);
 {$I+}
 If IOResult<>0 Then ;
End;

Procedure ShCopy(V: PVM; Const Arg: String);
Var A,B,Src,Dst,Pat,Dir: String; P: Integer; SR: SearchRec; N: Integer; Cnt: Integer;
Begin
 A:=Trim(Arg);P:=Pos(' ',A);
 If P=0 Then Begin ConStr('Required parameter missing');ConLn;Exit;End;
 B:=Trim(Copy(A,P+1,200));A:=Copy(A,1,P-1);
 Src:=DosPath(V,A);Dst:=DosPath(V,B);
 If (Pos('*',Src)>0) Or (Pos('?',Src)>0) Then Begin
  P:=Length(Src);While (P>0) And (Src[P]<>'\') Do Dec(P);
  Dir:=Copy(Src,1,P-1);Pat:=Copy(Src,P+1,14);Cnt:=0;
  If Pat='*.*' Then Pat:='*';
  FindFirst(JoinPath(V2R(Dir),'*'),AnyFile,SR);
  While DosError=0 Do Begin
   If ((SR.Attr And Directory)=0) And WildMatch(Pat,SR.Name) And (SR.Name[1]<>'.') Then Begin
    If CopyFileReal(JoinPath(V2R(Dir),SR.Name),JoinPath(V2R(Dst),SR.Name)) Then Begin Inc(Cnt);ConStr(Upper(SR.Name));ConLn;End;
   End;
   FindNext(SR);
  End;
  {$IFDEF FPC}FindClose(SR);{$ENDIF}
  ConStr(PadL(IntStr(Cnt),10)+' file(s) copied');ConLn;Exit;
 End;
 If VDirExists(Dst) Then Dst:=VJoin(Dst,BaseName(Src));
 If Not FileExists(V2R(Src)) Then Begin ConStr('File not found - '+A);ConLn;Exit;End;
 If CopyFileReal(V2R(Src),V2R(Dst)) Then Begin ConStr('        1 file(s) copied');ConLn;End
 Else Begin ConStr('Unable to copy');ConLn;End;
End;

Procedure ShDel(V: PVM; Const Arg: String);
Var Src,Dir,Pat: String; P: Integer; SR: SearchRec; F: File; Cnt: Integer;
Begin
 Src:=DosPath(V,Trim(Arg));
 P:=Length(Src);While (P>0) And (Src[P]<>'\') Do Dec(P);
 Dir:=Copy(Src,1,P-1);Pat:=Copy(Src,P+1,14);Cnt:=0;
 If Length(Dir)<3 Then Dir:=Copy(Src,1,3);
 If Pat='*.*' Then Pat:='*';
 FindFirst(JoinPath(V2R(Dir),'*'),AnyFile,SR);
 While DosError=0 Do Begin
  If ((SR.Attr And Directory)=0) And WildMatch(Pat,SR.Name) And (SR.Name[1]<>'.') Then Begin
   {$I-}Assign(F,JoinPath(V2R(Dir),SR.Name));Erase(F);{$I+}
   If IOResult=0 Then Inc(Cnt);
  End;
  FindNext(SR);
 End;
 {$IFDEF FPC}FindClose(SR);{$ENDIF}
 If Cnt=0 Then Begin ConStr('File not found');ConLn;End;
End;

Procedure ShRun(V: PVM; Const Prog,Tail: String); Forward;

Procedure ShBatchStart(V: PVM; Const VP,Tail: String);
Var T: Text; L: String; I,P: Integer; A: String;
Begin
 V^.NBatch:=0;V^.BatchPos:=1;
 {$I-}
 Assign(T,V2R(VP));Reset(T);
 If IOResult<>0 Then Begin ConStr('Batch file not found');ConLn;Exit;End;
 While (Not Eof(T)) And (V^.NBatch<60) Do Begin ReadLn(T,L);Inc(V^.NBatch);V^.Batch[V^.NBatch]:=Copy(L,1,119);End;
 Close(T);
 {$I+}
 V^.BatchArgs[0]:=VP;
 A:=Trim(Tail);
 For I:=1 To 9 Do Begin
  P:=Pos(' ',A);
  If P=0 Then Begin V^.BatchArgs[I]:=A;A:='';End Else Begin V^.BatchArgs[I]:=Copy(A,1,P-1);A:=Trim(Copy(A,P+1,200));End;
 End;
 V^.InBatch:=True;
End;

Function BatchSubst(V: PVM; Const L: String): String;
Var R: String; I,P: Integer; Nm: String;
Begin
 R:='';I:=1;
 While I<=Length(L) Do Begin
  If (L[I]='%') And (I<Length(L)) Then Begin
   If L[I+1] In ['0'..'9'] Then Begin R:=R+V^.BatchArgs[Ord(L[I+1])-48];Inc(I,2);Continue;End;
   If L[I+1]='%' Then Begin R:=R+'%';Inc(I,2);Continue;End;
   P:=I+1;While (P<=Length(L)) And (L[P]<>'%') Do Inc(P);
   If P<=Length(L) Then Begin Nm:=Copy(L,I+1,P-I-1);R:=R+EnvGet(V,Nm);I:=P+1;Continue;End;
  End;
  R:=R+L[I];Inc(I);
 End;
 BatchSubst:=R;
End;

Procedure ShExec(V: PVM; Line: String);
Var Cmd,Arg,U,Tok: String; P,I: Integer; Silent: Boolean; Prog: String; H,M,S,Y,Mo,D: Integer;
Begin
 Line:=Trim(Line);
 If Line='' Then Exit;
 Silent:=False;
 If Line[1]='@' Then Begin Silent:=True;Delete(Line,1,1);Line:=Trim(Line);End;
 If Line='' Then Exit;
 If Line[1]=':' Then Exit;
 P:=1;
 While (P<=Length(Line)) And Not (Line[P] In [' ','/','\','.',':','+','=']) Do Inc(P);
 If (P<=Length(Line)) And (Line[P]='.') And (Upper(Copy(Line,1,P-1))<>'ECHO') And (Upper(Copy(Line,1,P-1))<>'CD') And
    (Upper(Copy(Line,1,P-1))<>'CHDIR') Then Begin
  While (P<=Length(Line)) And Not (Line[P] In [' ','/','\',':','+','=']) Do Inc(P);
 End;
 Cmd:=Upper(Copy(Line,1,P-1));Arg:=Copy(Line,P,250);
 If (Arg<>'') And (Arg[1]=' ') Then Arg:=Trim(Arg);
 If (Cmd='ECHO') And (Arg<>'') And (Arg[1]='.') Then Begin ConLn;Exit;End;
 If (Length(Line)=2) And (Line[2]=':') Then Begin
  If UpCase(Line[1])='C' Then V^.CurDir:='C:\' Else Begin ConStr('Invalid drive specification');ConLn;End;
  Exit;
 End;
 If Cmd='REM' Then Exit
 Else If Cmd='ECHO' Then Begin
  If Upper(Arg)='OFF' Then V^.Echo:=False
  Else If Upper(Arg)='ON' Then V^.Echo:=True
  Else If Arg='' Then Begin ConStr('ECHO is '+IfThenS(V^.Echo,'on','off'));ConLn;End
  Else Begin ConStr(Arg);ConLn;End;
 End
 Else If Cmd='CLS' Then ScrClear
 Else If Cmd='VER' Then Begin ConLn;ConStr('MS-DOS Version 5.00 (WINDOWS2 emulation)');ConLn;End
 Else If (Cmd='CD') Or (Cmd='CHDIR') Then Begin
  If Arg='' Then Begin ConStr(V^.CurDir);ConLn;End
  Else Begin
   If VDirExists(DosPath(V,Arg)) Then V^.CurDir:=DosPath(V,Arg) Else Begin ConStr('Invalid directory');ConLn;End;
  End;
 End
 Else If (Cmd='MD') Or (Cmd='MKDIR') Then Begin {$I-}MkDir(V2R(DosPath(V,Arg)));{$I+}If IOResult<>0 Then Begin ConStr('Unable to create directory');ConLn;End;End
 Else If (Cmd='RD') Or (Cmd='RMDIR') Then Begin {$I-}RmDir(V2R(DosPath(V,Arg)));{$I+}If IOResult<>0 Then Begin ConStr('Invalid path, not directory, or directory not empty');ConLn;End;End
 Else If Cmd='DIR' Then ShDir(V,Arg)
 Else If Cmd='TYPE' Then ShType(V,Arg)
 Else If Cmd='COPY' Then ShCopy(V,Arg)
 Else If (Cmd='DEL') Or (Cmd='ERASE') Then ShDel(V,Arg)
 Else If (Cmd='REN') Or (Cmd='RENAME') Then Begin
  P:=Pos(' ',Arg);
  If P=0 Then Begin ConStr('Required parameter missing');ConLn;End
  Else Begin
   {$I-}Assign(V^.Files[0].F,V2R(DosPath(V,Copy(Arg,1,P-1))));
   Rename(V^.Files[0].F,JoinPath(DirOf(V2R(DosPath(V,Copy(Arg,1,P-1)))),Trim(Copy(Arg,P+1,100))));{$I+}
   If IOResult<>0 Then Begin ConStr('Duplicate file name or file not found');ConLn;End;
  End;
 End
 Else If Cmd='SET' Then Begin
  If Arg='' Then Begin For I:=1 To V^.NEnv Do Begin ConStr(V^.EnvVars[I]);ConLn;End;End
  Else Begin P:=Pos('=',Arg);If P>0 Then EnvSet(V,Copy(Arg,1,P-1),Copy(Arg,P+1,200));End;
 End
 Else If Cmd='PATH' Then Begin
  If Arg='' Then Begin ConStr('PATH='+EnvGet(V,'PATH'));ConLn;End Else EnvSet(V,'PATH',Arg);
 End
 Else If Cmd='PROMPT' Then EnvSet(V,'PROMPT',Arg)
 Else If Cmd='DATE' Then Begin GetToday(Y,Mo,D);ConStr('Current date is '+DayShort(DayOfWeek(Y,Mo,D))+' '+DateStr(Y,Mo,D));ConLn;End
 Else If Cmd='TIME' Then Begin GetNow(H,M,S);ConStr('Current time is '+TimeStr(H,M,S));ConLn;End
 Else If Cmd='VOL' Then Begin ConStr(' Volume in drive '+V^.CurDir[1]+' is '+IfThenS(VolNames[UpCase(V^.CurDir[1])]='','(none)',VolNames[UpCase(V^.CurDir[1])]));ConLn;End
 Else If Cmd='MEM' Then Begin
  ConLn;ConStr('    655360 bytes total conventional memory');ConLn;
  ConStr('    '+PadL(IntStr(LongInt(ArenaLargest(V))*16),6)+' bytes available to MS-DOS');ConLn;
 End
 Else If Cmd='PAUSE' Then Begin ConStr('Press any key to continue . . .');V^.Pause:=True;End
 Else If (Cmd='EXIT') Then Begin V^.ExitClose:=True;End
 Else If Cmd='CALL' Then Begin
  Arg:=Trim(Arg);P:=Pos(' ',Arg);
  If P=0 Then Begin Prog:=Arg;Tok:='';End Else Begin Prog:=Copy(Arg,1,P-1);Tok:=Trim(Copy(Arg,P+1,200));End;
  ShRun(V,Prog,Tok);
 End
 Else If Cmd='GOTO' Then Begin
  Arg:=Upper(Trim(Arg));If (Arg<>'') And (Arg[1]=':') Then Delete(Arg,1,1);
  For I:=1 To V^.NBatch Do
   If (Trim(V^.Batch[I])<>'') And (Trim(V^.Batch[I])[1]=':') And (Upper(Copy(Trim(V^.Batch[I]),2,40))=Arg) Then V^.BatchPos:=I+1;
 End
 Else If Cmd='IF' Then Begin
  U:=Upper(Arg);
  If Copy(U,1,6)='EXIST ' Then Begin
   Arg:=Trim(Copy(Arg,7,250));P:=Pos(' ',Arg);
   If (FileExists(V2R(DosPath(V,Copy(Arg,1,P-1)))) Or VDirExists(DosPath(V,Copy(Arg,1,P-1)))) Then ShExec(V,Copy(Arg,P+1,200));
  End Else If Copy(U,1,10)='NOT EXIST ' Then Begin
   Arg:=Trim(Copy(Arg,11,250));P:=Pos(' ',Arg);
   If Not (FileExists(V2R(DosPath(V,Copy(Arg,1,P-1)))) Or VDirExists(DosPath(V,Copy(Arg,1,P-1)))) Then ShExec(V,Copy(Arg,P+1,200));
  End Else If Copy(U,1,11)='ERRORLEVEL ' Then Begin
   Arg:=Trim(Copy(Arg,12,250));P:=Pos(' ',Arg);
   If V^.LastExit>=StrVal(Copy(Arg,1,P-1),0) Then ShExec(V,Copy(Arg,P+1,200));
  End Else Begin
   P:=Pos('==',Arg);
   If P>0 Then Begin
    Tok:=Trim(Copy(Arg,1,P-1));Prog:=Trim(Copy(Arg,P+2,250));
    I:=Pos(' ',Prog);
    If I>0 Then Begin
     If Upper(Tok)=Upper(Copy(Prog,1,I-1)) Then ShExec(V,Copy(Prog,I+1,200));
    End;
   End;
  End;
 End
 Else If (Cmd='HELP') Or (Cmd='?') Then Begin
  ConStr('Commands: CD CLS COPY DATE DEL DIR ECHO EXIT MD MEM PATH PAUSE');ConLn;
  ConStr('  PROMPT RD REM REN SET TIME TYPE VER VOL, batch: CALL GOTO IF');ConLn;
  ConStr('Programs (.COM .EXE .BAT) run in the built-in 8086 emulator.');ConLn;
 End
 Else Begin
  Arg:=Trim(Copy(Line,Length(Cmd)+1,250));
  P:=Pos(' ',Line);
  If P=0 Then Begin Tok:=Line;Arg:='';End Else Begin Tok:=Copy(Line,1,P-1);Arg:=Trim(Copy(Line,P+1,250));End;
  ShRun(V,Tok,Arg);
 End;
End;

Procedure ShRun(V: PVM; Const Prog,Tail: String);
Var Path: String; Res: Integer; T: String;
Begin
 Path:=ShFindProg(V,Prog);
 If Path='' Then Begin ConStr('Bad command or file name');ConLn;Exit;End;
 If ExtOf(Path)='.BAT' Then Begin ShBatchStart(V,Path,Tail);Exit;End;
 T:=IfThenS(Tail='','',' '+Tail);
 Res:=LoadProgram(V,Path,T);
 If Res=LD_WIN16 Then Begin Win16Start(Path,Tail);Exit;End;
 If Res<>LD_OK Then Begin
  Case Res Of LD_NOMEM: ConStr('Insufficient memory');LD_BADFMT: ConStr('Bad EXE format');Else ConStr('Cannot load program');End;
  ConLn;Exit;
 End;
 V^.Running:=True;
 V^.Title:=BaseName(Path);
 { le processeur courant devient celui du programme }
 VMLeave(V);
End;

Procedure ShellEnter(V: PVM);
Var L: String;
Begin
 L:=V^.ShLine;
 ConLn;
 If L<>'' Then Begin
  If (V^.NHist=0) Or (V^.Hist[V^.NHist]<>L) Then Begin
   If V^.NHist<16 Then Inc(V^.NHist) Else Move(V^.Hist[2],V^.Hist[1],SizeOf(V^.Hist[1])*15);
   V^.Hist[V^.NHist]:=L;
  End;
 End;
 V^.HistPos:=V^.NHist+1;
 V^.ShLine:='';
 VMEnter(V);
 ShExec(V,L);
 VMLeave(V);
 If Not V^.Running Then ShellPrompt(V);
End;

Procedure ShellKey(V: PVM; K: Word);
Var I: Integer;
Begin
 If V^.Pause Then Begin V^.Pause:=False;ConLn;Exit;End;
 VMEnter(V);
 Case K Of
  K_ENTER: Begin VMLeave(V);ShellEnter(V);Exit;End;
  K_BKSP: If Length(V^.ShLine)>0 Then Begin Delete(V^.ShLine,Length(V^.ShLine),1);ConPut(8);ConPut(32);ConPut(8);End;
  K_ESC: Begin While Length(V^.ShLine)>0 Do Begin Delete(V^.ShLine,Length(V^.ShLine),1);ConPut(8);ConPut(32);ConPut(8);End;End;
  K_UP,K_DOWN: Begin
     If K=K_UP Then Begin If V^.HistPos>1 Then Dec(V^.HistPos);End Else Begin If V^.HistPos<=V^.NHist Then Inc(V^.HistPos);End;
     While Length(V^.ShLine)>0 Do Begin Delete(V^.ShLine,Length(V^.ShLine),1);ConPut(8);ConPut(32);ConPut(8);End;
     If (V^.HistPos>=1) And (V^.HistPos<=V^.NHist) Then Begin V^.ShLine:=V^.Hist[V^.HistPos];ConStr(V^.ShLine);End;
    End;
  3: Begin ConStr('^C');ConLn;V^.InBatch:=False;V^.ShLine:='';ShellPrompt(V);End;
 Else If (K>=32) And (K<256) And (Length(V^.ShLine)<120) Then Begin V^.ShLine:=V^.ShLine+Chr(K);ConPut(K);End;
 End;
 VMLeave(V);
End;

{ ---------------- creation / destruction ---------------- }

Procedure VMInitMemory(V: PVM);
Var I: Integer;
Begin
 GetMem(V^.Mem,$100000+4096);
 EmsOnFlag:=False;
 FillChar(V^.Mem^,$100000+4096,0);
 For I:=0 To 255 Do Begin
  V^.Mem^[I*4]:=(I*4) And 255;V^.Mem^[I*4+1]:=(I*4) Shr 8;V^.Mem^[I*4+2]:=0;V^.Mem^[I*4+3]:=$F0;
 End;
 V^.Mem^[$F0000]:=$CF;
 For I:=0 To 1023 Do V^.Mem^[$F0000+I]:=$CF;
 { donnees BIOS }
 V^.Mem^[$410]:=$21;V^.Mem^[$413]:=$80;V^.Mem^[$414]:=$02;
 V^.Mem^[$449]:=3;V^.Mem^[$44A]:=80;V^.Mem^[$44C]:=$A0;V^.Mem^[$44D]:=$0F;
 V^.Mem^[$460]:=7;V^.Mem^[$461]:=6;V^.Mem^[$463]:=$D4;V^.Mem^[$464]:=$03;
 V^.Mem^[$484]:=24;V^.Mem^[$485]:=16;
 For I:=0 To 1999 Do Begin V^.Mem^[TXT_BASE+I*2]:=32;V^.Mem^[TXT_BASE+I*2+1]:=7;End;
 V^.Mem^[$F000E]:=0;
End;

Function VMCreate(W: PWindow): PVM;
Var V: PVM; I: Integer;
Begin
 New(V);FillChar(V^,SizeOf(TVM),0);
 VMInitMemory(V);
 GetMem(V^.Pix,640*480);FillChar(V^.Pix^,640*480,0);
 ArenaInit(V);
 V^.CurDir:='C:\';
 For I:=0 To 4 Do Begin V^.Files[I].Used:=True;V^.Files[I].Dev:=1;End;
 V^.Echo:=True;V^.Wnd:=W;V^.PSP:=$0600;
 V^.DTA:=Lin($0600,$80);
 V^.Mode:=3;
 VMDefaultPalette(V);VMBuildLut(V);
 EnvSet(V,'COMSPEC','C:\COMMAND.COM');EnvSet(V,'PATH','C:\;C:\WINDOWS;C:\DOS');EnvSet(V,'PROMPT','$P$G');
 V^.LastTick:=-1;V^.HistPos:=1;
 V^.Title:='MS-DOS Prompt';
 VMCreate:=V;
End;

Procedure VMDestroy(V: PVM);
Var I: Integer;
Begin
 For I:=5 To MAXFH-1 Do If V^.Files[I].Used Then FhClose(V,I);
 FreeMem(V^.Mem,$100000+4096);
 FreeMem(V^.Pix,640*480);
 Dispose(V);
End;

{ ---------------- execution ---------------- }

Procedure VMTicks(V: PVM);
Var T: Int64; Old: LongInt;
Begin
 T:=(Int64(NowCs)*182065) Div 1000000;
 V^.Mem^[$46C]:=T And 255;V^.Mem^[$46D]:=(T Shr 8) And 255;V^.Mem^[$46E]:=(T Shr 16) And 255;V^.Mem^[$46F]:=(T Shr 24) And 255;
End;

Procedure VMRun(V: PVM; Steps: LongInt);
Var Vo,Vs: Word; T: LongInt; N: LongInt;
Begin
 VMEnter(V);
 VMTicks(V);
 T:=Int64(NowCs)*182065 Div 1000000;
 If (T<>V^.LastTick) And fIF Then Begin
  V^.LastTick:=T;
  { INT 08h materielle si un gestionnaire utilisateur est installe }
  Vo:=RdW(8*4);Vs:=RdW(8*4+2);
  If Not ((Vs=ROMSEG) And (Vo<1024)) Then DoInterrupt(8)
  Else Begin
   Vo:=RdW($1C*4);Vs:=RdW($1C*4+2);
   If Not ((Vs=ROMSEG) And (Vo<1024)) Then DoInterrupt($1C);
  End;
 End;
 N:=Steps;
 While N>0 Do Begin
  CpuBlock:=False;
  If TraceOn And (Sg[SG_CS]=$0671) And (IPr=$8E5E) Then WriteLn(TraceF,'WATCH 8E5E AX=',HexStr(Rg[R_AX],4),' BX=',HexStr(Rg[R_BX],4),' CX=',HexStr(Rg[R_CX],4),' DX=',HexStr(Rg[R_DX],4));
  If TraceOn And (Sg[SG_CS]=$0671) And (IPr=$5CAF) And (TrGN<8) Then Begin
   Inc(TrGN);TrGRet[TrGN]:=LongInt(RdW(Lin(Sg[SG_SS],Rg[R_SP]+2)))*65536+RdW(Lin(Sg[SG_SS],Rg[R_SP]));
   WriteLn(TraceF,'GALLOC from ',HexStr(RdW(Lin(Sg[SG_SS],Rg[R_SP]+2)),4),':',HexStr(RdW(Lin(Sg[SG_SS],Rg[R_SP])),4),' arg=',HexStr(RdW(Lin(Sg[SG_SS],Rg[R_SP]+4)),4),' size=',HexStr(RdW(Lin(Sg[SG_SS],Rg[R_SP]+6)),4),' flags=',HexStr(RdW(Lin(Sg[SG_SS],Rg[R_SP]+8)),4));
  End;
  If TraceOn And (Sg[SG_CS]=0) And Not TrZero Then Begin
   TrZero:=True;
   WriteLn(TraceF,'CS0 ENTERED IP=',HexStr(IPr,4),' AX=',HexStr(Rg[R_AX],4),' BX=',HexStr(Rg[R_BX],4),' CX=',HexStr(Rg[R_CX],4),' DX=',HexStr(Rg[R_DX],4),' SI=',HexStr(Rg[R_SI],4),' DI=',HexStr(Rg[R_DI],4),' BP=',HexStr(Rg[R_BP],4),' SP=',HexStr(Rg[R_SP],4),' SS=',HexStr(Sg[SG_SS],4),' DS=',HexStr(Sg[SG_DS],4),' ES=',HexStr(Sg[SG_ES],4));
   For TrK:=1023 Downto 1 Do WriteLn(TraceF,'Z0RING ',HexStr(Ring[(RingP-TrK) And 1023] Shr 16,4),':',HexStr(Ring[(RingP-TrK) And 1023] And $FFFF,4));
   Write(TraceF,'Z0STACK');For TrK:=0 To 31 Do Write(TraceF,' ',HexStr(RdW(Lin(Sg[SG_SS],Rg[R_SP]+TrK*2)),4));WriteLn(TraceF);Flush(TraceF);
  End;
  If TraceOn Then Begin Inc(TrPos);If (TrPos And $3FFFFF)=0 Then Begin WriteLn(TraceF,'POS ',HexStr(Sg[SG_CS],4),':',HexStr(IPr,4),' AX=',HexStr(Rg[R_AX],4),' BX=',HexStr(Rg[R_BX],4),' CX=',HexStr(Rg[R_CX],4),' DX=',HexStr(Rg[R_DX],4),' SI=',HexStr(Rg[R_SI],4),' DI=',HexStr(Rg[R_DI],4),' DS=',HexStr(Sg[SG_DS],4),' ES=',HexStr(Sg[SG_ES],4));Flush(TraceF);End;End;
  If TraceOn And ((RdW($8CB01)<>TrW2) Or (Mem^[$8CB05]<>TrB5)) Then Begin
   WriteLn(TraceF,'WATCHCUR owner ',HexStr(TrW2,4),'->',HexStr(RdW($8CB01),4),' f5 ',HexStr(TrB5,2),'->',HexStr(Mem^[$8CB05],2),' at ',HexStr(Sg[SG_CS],4),':',HexStr(IPr,4),' AX=',HexStr(Rg[R_AX],4),' SP=',HexStr(Rg[R_SP],4),' ST:');For TrK:=0 To 15 Do Write(TraceF,' ',HexStr(RdW(Lin(Sg[SG_SS],Rg[R_SP]+TrK*2)),4));WriteLn(TraceF);
   TrW2:=RdW($8CB01);TrB5:=Mem^[$8CB05];
  End;
  If TraceOn And (TrCSn>0) Then Begin
   If (Sg[SG_CS]=$0633) And (IPr=$011D) Then TrWin:=True;
   If (Sg[SG_CS]=$0671) And (IPr=$8E6E) Then TrWin:=False;
   If TrWin And (Sg[SG_CS]=$0671) And (IPr=$5148) And (Rg[R_CX]=1) And (Rg[R_BX]=6) And (Rg[R_SI]=$26CD) Then Begin Assign(TrMF,GetEnv('W2TRACE')+'.mem2');Rewrite(TrMF,1);BlockWrite(TrMF,Mem^[0],$A0000);Close(TrMF);WriteLn(TraceF,'DUMP2 ES=',HexStr(Sg[SG_ES],4),' DS=',HexStr(Sg[SG_DS],4));End;
   If TrWin And (Sg[SG_CS]=$0671) And (IPr=$0248) Then Begin
    Inc(TrSnap);
    If TrSnap=2 Then Begin
     Assign(TrMF,GetEnv('W2TRACE')+'.snap');Rewrite(TrMF,1);
     TrR[0]:=Rg[0];TrR[1]:=Rg[1];TrR[2]:=Rg[2];TrR[3]:=Rg[3];TrR[4]:=Rg[4];TrR[5]:=Rg[5];TrR[6]:=Rg[6];TrR[7]:=Rg[7];
     TrR[8]:=Sg[0];TrR[9]:=Sg[1];TrR[10]:=Sg[2];TrR[11]:=Sg[3];TrR[12]:=IPr;TrR[13]:=GetFlags;
     BlockWrite(TrMF,TrR,28);BlockWrite(TrMF,Mem^[0],$A0000);Close(TrMF);
    End;
   End;
   If TrWin And (Sg[SG_CS]=$0671) And ((IPr=$0248) Or (IPr=$0BF2) Or (IPr=$0012)) Then Begin Write(TraceF,'ARGS ',HexStr(IPr,4),':');For TrK:=0 To 9 Do Write(TraceF,' ',HexStr(RdW(Lin(Sg[SG_SS],Rg[R_SP]+TrK*2)),4));WriteLn(TraceF);End;
   If TrWin Then Begin Dec(TrCSn);WriteLn(TraceF,'L ',HexStr(Sg[SG_CS],4),':',HexStr(IPr,4),' ',HexStr(Mem^[Lin(Sg[SG_CS],IPr)],2),' ',HexStr(Rg[R_AX],4),' ',HexStr(Rg[R_BX],4),' ',HexStr(Rg[R_CX],4),' ',HexStr(Rg[R_DX],4),' ',HexStr(Rg[R_SI],4),' ',HexStr(Rg[R_DI],4),' ',HexStr(Rg[R_BP],4),' ',HexStr(Rg[R_SP],4),' ',HexStr(Sg[SG_DS],4),' ',HexStr(Sg[SG_ES],4));End;
  End;
  If TraceOn Then Begin RingP:=(RingP+1) And 1023;Ring[RingP]:=LongInt(Sg[SG_CS])*65536+IPr;End;
  If TraceOn And (StepLeft>0) Then Begin Dec(StepLeft);WriteLn(TraceF,'STEP ',HexStr(Sg[SG_CS],4),':',HexStr(IPr,4),' op=',HexStr(Mem^[Lin(Sg[SG_CS],IPr)],2),' AX=',HexStr(Rg[R_AX],4),' BX=',HexStr(Rg[R_BX],4),' CX=',HexStr(Rg[R_CX],4),' DX=',HexStr(Rg[R_DX],4),' DS=',HexStr(Sg[SG_DS],4),' SP=',HexStr(Rg[R_SP],4));End;
  If TraceOn And (TrApi>=-5) And (TrApi<=-5) Then WriteLn(TraceF,'STEP ',HexStr(Sg[SG_CS],4),':',HexStr(IPr,4),' op=',HexStr(Mem^[Lin(Sg[SG_CS],IPr)],2),' SP=',HexStr(Rg[R_SP],4));
  CpuStep;
  Inc(InstCnt);
  If CpuHalt Then Begin
   LastCpuErr:=CpuErr;
   ConStr(CpuErr);ConLn;
   V^.NCtx:=0;ProcExit(V,255);CpuHalt:=False;
   Break;
  End;
  If CpuBlock Then Break;
  If Not V^.Running Then Break;
  Dec(N);
 End;
 VMLeave(V);
End;

{ ---------------- graphiques plein ecran ---------------- }

Procedure VMGfxDims(V: PVM; Var VW,VH,SX,SY: Integer);
Begin
 Case V^.Mode Of
  $13: Begin VW:=320;VH:=200;SX:=2;SY:=2;End;
  4,5: Begin VW:=320;VH:=200;SX:=2;SY:=2;End;
  6: Begin VW:=640;VH:=200;SX:=1;SY:=2;End;
  $0D: Begin VW:=320;VH:=200;SX:=2;SY:=2;End;
  $0E: Begin VW:=640;VH:=200;SX:=1;SY:=2;End;
  $0F,$10: Begin VW:=640;VH:=350;SX:=1;SY:=1;End;
 Else Begin VW:=640;VH:=480;SX:=1;SY:=1;End;
 End;
End;

Function GfxColorAt(V: PVM; X,Y: Integer): Byte;
Var C: Byte;
Const CgaPal: Array[0..3] Of Byte=(0,11,13,15);
Begin
 C:=VMGetPixel(V,X,Y);
 Case V^.Mode Of
  $13: GfxColorAt:=V^.Lut[C];
  4,5: GfxColorAt:=CgaPal[C And 3];
  6: GfxColorAt:=IfThen_(C<>0,15,0);
 Else GfxColorAt:=C And 15;
 End;
End;

Procedure GfxPresent(V: PVM; Shown: PByteArr_; Force: Boolean);
Var VW,VH,SX,SY,X,Y,OX,OY,X0: Integer; C,C2: Byte;
Begin
 VMGfxDims(V,VW,VH,SX,SY);
 OX:=(SCR_W-VW*SX) Div 2;OY:=(SCR_H-VH*SY) Div 2;
 If V^.PalDirty Then Begin VMBuildLut(V);Force:=True;End;
 ClipFull;
 For Y:=0 To VH-1 Do Begin
  X:=0;
  While X<VW Do Begin
   C:=GfxColorAt(V,X,Y);
   If Force Or (Shown^[Y*640+X]<>C) Then Begin
    X0:=X;Shown^[Y*640+X]:=C;
    While (X+1<VW) And (GfxColorAt(V,X+1,Y)=C) And (Force Or (Shown^[Y*640+X+1]<>C)) Do Begin Inc(X);Shown^[Y*640+X]:=C;End;
    SetFillStyle(SolidFill,C);
    Bar(OX+X0*SX,OY+Y*SY,OX+X*SX+SX-1,OY+Y*SY+SY-1);
   End;
   Inc(X);
  End;
 End;
End;

Procedure GfxSession(W: PWindow);
Var V: PVM; E: TEvent; Shown: PByteArr_; Last: LongInt; Force: Boolean; VW,VH,SX,SY: Integer; Quit: Boolean; Bk: Word;
Begin
 V:=W^.Data;
 GetMem(Shown,640*480);FillChar(Shown^,640*480,255);
 HideMouse;
 ClipFull;
 SetFillStyle(SolidFill,cBlk);Bar(0,0,SCR_W-1,SCR_H-1);
 Force:=True;Last:=0;Quit:=False;
 While V^.GfxFull And V^.Running And Not Quit Do Begin
  VMRun(V,60000);
  PollEvent(E);
  VMGfxDims(V,VW,VH,SX,SY);
  If E.Kind=EV_KEY Then Begin
   If E.Key=K_ALTF4 Then Quit:=True
   Else Begin Bk:=KeyToBios(E.Key);VMKeyPut(V,Bk);End;
  End;
  V^.MouseX:=E.X;V^.MouseY:=(E.Y-(SCR_H-VH*SY) Div 2) Div SY;
  If SX=2 Then V^.MouseX:=E.X;
  V^.MouseB:=E.B And 3;
  If NowCs-Last>=3 Then Begin GfxPresent(V,Shown,Force);Force:=False;Last:=NowCs;End;
 End;
 FreeMem(Shown,640*480);
 If Quit Then Begin VMEnter(V);V^.NCtx:=0;ProcExit(V,255);VMLeave(V);End;
 ClipFull;
 V^.GfxFull:=False;
 ShowMouse;
 Dirty:=True;
End;

{ ---------------- fenetre ---------------- }

Var
 MkOn,MkScr,MkExt: Boolean;      { Mark / Scroll (menu Systeme des fenetres DOS) }
 MkAR,MkAC,MkR,MkC: Integer;
 MkWin: PWindow;
 DosInitDir: String;             { repertoire initial (PIF) }
 DosCloseExit: Boolean;          { fermer la fenetre a la fin du programme (PIF) }

Procedure MkRect(Var R1,C1,R2,C2: Integer);
Begin
 R1:=Min2(MkAR,MkR);R2:=Max2(MkAR,MkR);C1:=Min2(MkAC,MkC);C2:=Max2(MkAC,MkC);
End;

Function MkCopyText(V: PVM): String;
Var R,C,R1,C1,R2,C2,N: Integer; S,Ln: String;
Begin
 MkRect(R1,C1,R2,C2);
 S:='';
 For R:=R1 To R2 Do Begin
  Ln:='';
  For C:=C1 To C2 Do Begin
   N:=V^.Mem^[TXT_BASE+(R*80+C)*2];If N<32 Then N:=32;Ln:=Ln+Chr(N);
  End;
  While (Length(Ln)>0) And (Ln[Length(Ln)]=' ') Do Delete(Ln,Length(Ln),1);
  If R>R1 Then S:=S+#13#10;
  S:=S+Ln;
 End;
 MkCopyText:=S;
End;

Procedure DosPrepareView(W: PWindow);
Var V: PVM; X1,Y1,X2,Y2: Integer;
Begin
 V:=W^.Data;
 WinClient(W,X1,Y1,X2,Y2);
 W^.HasVS:=(Y2-Y1+1)<25*ROWH;
 W^.HasHS:=(X2-X1+1)<80*COLW;
 WinClient(W,X1,Y1,X2,Y2);
 W^.VTot:=25;W^.VPage:=Max2(1,(Y2-Y1+1) Div ROWH);
 W^.HTot:=80;W^.HPage:=Max2(1,(X2-X1+1) Div COLW);
 If W^.VPos>W^.VTot-W^.VPage Then W^.VPos:=Max2(0,W^.VTot-W^.VPage);
 If W^.HPos>W^.HTot-W^.HPage Then W^.HPos:=Max2(0,W^.HTot-W^.HPage);
End;

Procedure DosDraw(W: PWindow);
Var V: PVM; X1,Y1,X2,Y2,R,C,Att,PrevAtt,Run0,N: Integer; A: LongInt; Ch: Byte; S: String; CurX,CurY: Integer;
    Fg,Bg: Integer; Cols,Rows: Integer;
Begin
 V:=W^.Data;
 DosPrepareView(W);
 WinClient(W,X1,Y1,X2,Y2);
 GBar(X1,Y1,X2,Y2,cBlk);
 If V^.Mem=Nil Then Exit;
 Cols:=Min2(80,(X2-X1+1) Div COLW+1);Rows:=Min2(25,(Y2-Y1+1) Div ROWH+1);
 For R:=0 To Rows-1 Do Begin
  If R+W^.VPos>=25 Then Break;
  C:=0;
  While C<Cols Do Begin
   If C+W^.HPos>=80 Then Break;
   A:=TXT_BASE+((R+W^.VPos)*80+C+W^.HPos)*2;
   Att:=V^.Mem^[A+1];
   Run0:=C;S:='';
   While (C<Cols) And (C+W^.HPos<80) And (V^.Mem^[TXT_BASE+((R+W^.VPos)*80+C+W^.HPos)*2+1]=Att) Do Begin
    Ch:=V^.Mem^[TXT_BASE+((R+W^.VPos)*80+C+W^.HPos)*2];
    If Ch<32 Then Ch:=32;
    S:=S+Chr(Ch);Inc(C);
   End;
   Fg:=Att And 15;Bg:=(Att Shr 4) And 15;
   If Bg<>0 Then GBar(X1+Run0*COLW,Y1+R*ROWH,X1+C*COLW-1,Y1+R*ROWH+ROWH-1,Bg);
   If Fg<>Bg Then GText(X1+Run0*COLW,Y1+R*ROWH+1,S,Fg);
  End;
 End;
 If MkOn And (MkWin=W) Then Begin
  MkRect(R,C,Att,Run0);   { R1,C1,R2,C2 }
  For N:=R To Att Do
   For Fg:=C To Run0 Do
    If (N-W^.VPos>=0) And (Fg-W^.HPos>=0) And (X1+(Fg-W^.HPos)*COLW<=X2) And (Y1+(N-W^.VPos)*ROWH<=Y2) Then Begin
     GBar(X1+(Fg-W^.HPos)*COLW,Y1+(N-W^.VPos)*ROWH,X1+(Fg-W^.HPos)*COLW+COLW-1,Y1+(N-W^.VPos)*ROWH+ROWH-1,cLGr);
     Ch:=V^.Mem^[TXT_BASE+(N*80+Fg)*2];If Ch<32 Then Ch:=32;
     GText(X1+(Fg-W^.HPos)*COLW,Y1+(N-W^.VPos)*ROWH+1,Chr(Ch),cBlk);
    End;
 End;
 CurX:=V^.Mem^[$450]-W^.HPos;CurY:=V^.Mem^[$451]-W^.VPos;
 If (CurX>=0) And (CurY>=0) And ((NowCs Div BlinkHalf) Mod 2=0) And (V^.Mode<4) And (W=ActiveWin) Then
  GBar(X1+CurX*COLW,Y1+CurY*ROWH+ROWH-2,X1+CurX*COLW+COLW-1,Y1+CurY*ROWH+ROWH-1,cLGr);
End;

Var PasteN,PastePos: Integer; PasteWin: PWindow;

Procedure DosMenu(W: PWindow; Cmd: Integer); Forward;

Procedure DosKey(W: PWindow; K: Word);
Var V: PVM; Dr,Dc: Integer;
Begin
 V:=W^.Data;
 { mode Marquer : les fleches deplacent le curseur (F8 = etendre, equivalent de MAJ+fleches) }
 If MkOn And (MkWin=W) Then Begin
  Dr:=0;Dc:=0;
  Case K Of
   K_UP: Dr:=-1;K_DOWN: Dr:=1;K_LEFT: Dc:=-1;K_RIGHT: Dc:=1;
   K_HOME: Dc:=-80;K_END: Dc:=80;K_PGUP: Dr:=-25;K_PGDN: Dr:=25;
   322: Begin MkExt:=Not MkExt;If Not MkExt Then Begin MkAR:=MkR;MkAC:=MkC;End;End;
   K_ENTER: Begin DosMenu(W,CM_M_COPY);Exit;End;
   K_ESC: Begin MkOn:=False;Dirty:=True;Exit;End;
  End;
  If (Dr<>0) Or (Dc<>0) Then Begin
   MkR:=Clamp(MkR+Dr,0,24);MkC:=Clamp(MkC+Dc,0,79);
   If Not MkExt Then Begin MkAR:=MkR;MkAC:=MkC;End;
  End;
  Dirty:=True;Exit;
 End;
 { mode Defilement }
 If MkScr Then Begin
  Case K Of
   K_UP: If W^.VPos>0 Then Dec(W^.VPos);
   K_DOWN: Inc(W^.VPos);
   K_LEFT: If W^.HPos>0 Then Dec(W^.HPos);
   K_RIGHT: Inc(W^.HPos);
   K_PGUP: W^.VPos:=Max2(0,W^.VPos-W^.VPage);
   K_PGDN: Inc(W^.VPos,W^.VPage);
   K_HOME: Begin W^.VPos:=0;W^.HPos:=0;End;
   K_END: W^.VPos:=25;
   K_ESC,K_ENTER: MkScr:=False;
  End;
  Dirty:=True;Exit;
 End;
 If V^.Running Then VMKeyPut(V,KeyToBios(K))
 Else If K=K_PGUP Then Begin If W^.VPos>0 Then Dec(W^.VPos);Dirty:=True;End
 Else If K=K_PGDN Then Begin Inc(W^.VPos);Dirty:=True;End
 Else ShellKey(V,K);
 Invalidate(W);
End;

Procedure DosMouse(W: PWindow; Var E: TEvent);
Var V: PVM; X1,Y1,X2,Y2: Integer;
Begin
 V:=W^.Data;
 WinClient(W,X1,Y1,X2,Y2);
 If MkOn And (MkWin=W) Then Begin
  If (E.Kind=EV_DOWN) Or ((E.Kind=EV_MOVE) And ((E.B And 1)<>0)) Then Begin
   MkR:=Clamp((E.Y-Y1) Div ROWH+W^.VPos,0,24);MkC:=Clamp((E.X-X1) Div COLW+W^.HPos,0,79);
   If E.Kind=EV_DOWN Then Begin MkAR:=MkR;MkAC:=MkC;MkExt:=False;Capture:=W;End;
   Dirty:=True;
  End;
  Exit;
 End;
 V^.MouseX:=(E.X-X1+W^.HPos*COLW);
 V^.MouseY:=((E.Y-Y1) Div ROWH+W^.VPos)*8;
 V^.MouseB:=E.B And 3;
 If E.Kind=EV_DOWN Then Capture:=W;
End;

Procedure DosTimer(W: PWindow);
Var V: PVM; Sum,I: LongInt; Blink: Integer;
Begin
 V:=W^.Data;
 If V=Nil Then Exit;
 If V^.ExitClose Then Begin V^.ExitClose:=False;V^.Dead:=True;CloseWindow(W);Exit;End;
 { collage progressif (evite la perte de caracteres) }
 If (PasteWin=W) And (PastePos<PasteN) Then Begin
  For I:=1 To 8 Do If PastePos<PasteN Then Begin
   If V^.Running Then Begin
    If Not ((ClipTxt[PastePos]=#10) And (PastePos>0) And (ClipTxt[PastePos-1]=#13)) Then VMKeyPut(V,KeyToBios(Ord(ClipTxt[PastePos])));
   End Else If ClipTxt[PastePos]<>#10 Then ShellKey(V,Ord(ClipTxt[PastePos]));
   Inc(PastePos);
  End;
 End;
 If V^.Dead Then Exit;
 If V^.Running Then Begin
  VMRun(V,70000);
  If V^.GfxFull And V^.Running Then GfxSession(W);
  W^.Title:=V^.Title;
 End Else Begin
  If V^.NeedPrompt And (W^.Param>=1) Then Begin
   V^.NeedPrompt:=False;
   If W^.Param=3 Then Begin V^.Dead:=True;CloseWindow(W);Exit;End;
   W^.Param:=2;W^.Title:='('+W^.Title+')';V^.Title:=W^.Title;
  End;
  If V^.NeedPrompt Then Begin
   V^.NeedPrompt:=False;V^.Title:='MS-DOS Prompt';W^.Title:='MS-DOS Prompt';
   VMEnter(V);
   If V^.Mode<>3 Then VMSetMode(V,3,False);
   If V^.InBatch Then Else ShellPrompt(V);
   VMLeave(V);
  End;
  If V^.InBatch Then Begin
   VMEnter(V);
   If V^.BatchPos>V^.NBatch Then Begin V^.InBatch:=False;ShellPrompt(V);End
   Else Begin
    I:=V^.BatchPos;Inc(V^.BatchPos);
    If V^.Echo And (Copy(Trim(V^.Batch[I]),1,1)<>'@') And (Copy(Trim(V^.Batch[I]),1,1)<>':') Then Begin ShellPrompt(V);ConStr(V^.Batch[I]);ConLn;End;
    ShExec(V,BatchSubst(V,V^.Batch[I]));
   End;
   VMLeave(V);
  End;
 End;
 { detecte les changements de l'ecran }
 Sum:=0;
 For I:=0 To 3999 Do Sum:=Sum+V^.Mem^[TXT_BASE+I]*((I And 15)+1);
 Sum:=Sum+V^.Mem^[$450]*7+V^.Mem^[$451]*13+((NowCs Div BlinkHalf) And 1)*5;
 If Sum<>V^.Ticks0 Then Begin V^.Ticks0:=Sum;Invalidate(W);End;
End;

Procedure DosMenu(W: PWindow; Cmd: Integer);
Var V: PVM; I: Integer; S: String;
Begin
 V:=W^.Data;
 Case Cmd Of
  CM_M_CLOSE: Begin V^.Dead:=True;CloseWindow(W);Exit;End;
  CM_M_CLS: Begin VMEnter(V);ScrClear;If Not V^.Running Then ShellPrompt(V);VMLeave(V);End;
  CM_M_MARK: Begin
     MkOn:=True;MkScr:=False;MkExt:=False;MkWin:=W;
     MkAR:=Clamp(V^.Mem^[$451],0,24);MkAC:=Clamp(V^.Mem^[$450],0,79);MkR:=MkAR;MkC:=MkAC;
    End;
  CM_M_SCROLL: Begin MkScr:=True;MkOn:=False;End;
  CM_M_COPY: Begin
     If MkOn And (MkWin=W) Then Begin
      S:=MkCopyText(V);
      If S<>'' Then ClipSetText(S[1],Length(S)) Else Beep;
      MkOn:=False;
     End Else Beep;
    End;
  CM_M_PASTE: If ClipKind=1 Then Begin
     PasteN:=ClipLen;PastePos:=0;PasteWin:=W;
    End;
  CM_M_ABOUT: ShowAboutMs('MS-DOS Prompt',4,False);
  CM_M_RESET: If V^.Running Then Begin VMEnter(V);V^.NCtx:=0;ProcExit(V,255);VMLeave(V);End;
  CM_M_FULL: Begin If W^.State=2 Then RestoreWin(W) Else MaximizeWin(W);End;
 End;
 Dirty:=True;
End;

Procedure DosClose(W: PWindow);
Var V: PVM;
Begin
 V:=W^.Data;
 If V<>Nil Then VMDestroy(V);
 W^.Data:=Nil;
End;

Function DosCreate(Const Cmd: String; MaximizeIt: Boolean): PWindow;
Var W: PWindow; V: PVM;
Begin
 W:=NewWindow(A_DOSBOX,'MS-DOS Prompt',-1,-1,420,250,True);
 If W=Nil Then Begin DosCreate:=Nil;Exit;End;
 V:=VMCreate(W);
 W^.Data:=V;
 If Cmd<>'' Then Begin W^.Param:=IfThen_(DosCloseExit,3,1);W^.Title:=BaseName(Cmd);End;
 If DosInitDir<>'' Then V^.CurDir:=DosInitDir;
 WinAddMenu(W,'&Control~&Contr'#147'le~&Steuerung');
 WinAddItem(W,'&Full Screen~&Plein '#130'cran~&Vollbild',CM_M_FULL,'');
 WinAddItem(W,'&Mark~&Marquer~&Markieren',CM_M_MARK,'');
 WinAddItem(W,'C&opy~Cop&ier~&Kopieren',CM_M_COPY,'');
 WinAddItem(W,'&Paste~Co&ller~&Einf'#129'gen',CM_M_PASTE,'');
 WinAddItem(W,'&Scroll~&D'#130'filer~&Rollen',CM_M_SCROLL,'');
 WinAddItem(W,'&Clear Screen~&Effacer l''ecran~&L'#148'schen',CM_M_CLS,'');
 WinAddItem(W,'&Terminate Program~&Arr'#136'ter le programme~&Programm beenden',CM_M_RESET,'');
 WinAddItem(W,'&Exit~&Quitter~&Beenden',CM_M_CLOSE,'');
 WinAddItem(W,'A&bout MS-DOS Prompt...~&'#133' propos de MS-DOS Prompt...~'#154'&ber MS-DOS Prompt...',CM_M_ABOUT,'');
 VMEnter(V);
 ConStr('Microsoft Windows 2.03 - MS-DOS Prompt');ConLn;
 ConStr('(c) Microsoft Corp. 1987 - '+T3('emulated 8086, MS-DOS 5.00','8086 '#130'mul'#130', MS-DOS 5.00','emulierter 8086, MS-DOS 5.00'));ConLn;ConLn;
 If Cmd<>'' Then Begin
  VMLeave(V);
  ShellPrompt(V);
  ConStr(Cmd);ConLn;
  VMEnter(V);ShExec(V,Cmd);VMLeave(V);
  If Not V^.Running Then Begin VMEnter(V);ShellPrompt(V);VMLeave(V);End;
 End Else Begin ShellPrompt(V);VMLeave(V);End;
 If MaximizeIt Then MaximizeWin(W);
 DosCreate:=W;
End;

{$ENDIF}

{ ====================================================================== }
{    PROGRAMMES WINDOWS 2.x (FORMAT NE) : CHARGEUR ET API KERNEL/USER/GDI }
{ ====================================================================== }

{$IFDEF FPC}

Const
 MAXW16W = 48; MAXW16C = 16; MAXW16Q = 96; MAXW16T = 8; MAXW16O = 200; MAXW16D = 20;
 MAXW16R = 120; MAXW16MT = 12; MAXW16SYS = 8;
 W16_TRAP_RET = $3FC;
 HDL_EDITPROC = 4090; HDL_DEFPROC = 4091;
 WM_CREATE=$0001; WM_DESTROY=$0002; WM_MOVE=$0003; WM_SIZE=$0005; WM_ACTIVATE=$0006; WM_SETFOCUS=$0007;
 WM_KILLFOCUS=$0008; WM_ENABLE=$000A; WM_SETTEXT=$000C; WM_GETTEXT=$000D; WM_GETTEXTLENGTH=$000E;
 WM_PAINT=$000F; WM_CLOSE=$0010; WM_QUIT=$0012; WM_ERASEBKGND=$0014; WM_SHOWWINDOW=$0018;
 WM_KEYDOWN=$0100; WM_KEYUP=$0101; WM_CHAR=$0102; WM_INITDIALOG=$0110; WM_COMMAND=$0111;
 WM_SYSCOMMAND=$0112; WM_TIMER=$0113; WM_HSCROLL=$0114; WM_VSCROLL=$0115; WM_INITMENU=$0116;
 WM_INITMENUPOPUP=$0117; WM_MOUSEMOVE=$0200; WM_LBUTTONDOWN=$0201; WM_LBUTTONUP=$0202;
 WM_LBUTTONDBLCLK=$0203; WM_RBUTTONDOWN=$0204; WM_RBUTTONUP=$0205; WM_CUT=$0300; WM_COPY=$0301;
 WM_PASTE=$0302; WM_CLEAR=$0303; WM_UNDO=$0304;
 K_W16SYS = 1000;
 WK_TOP=0; WK_EDIT=1; WK_OTHER=2; WK_DLG=3; WK_STATIC=4; WK_BUTTON=5; WK_SCROLL=6;

Type
 TMsg16 = Record Hw,Msg,Wp: Word; Lp: LongInt; Tm: LongInt; Px,Py: Integer; End;
 TW16Win = Record
  Used : Boolean;
  Kind : Byte;
  Cls  : Integer;
  Parent : Word;
  X,Y,W,H : Integer;
  Style : LongInt;
  Id    : Word;
  Title : String[64];
  Host : PWindow;
  PSeg,POfs : Word;
  Extra : Array[0..7] Of LongInt;
  Destroyed,Enabled,Vis,Shown : Boolean;
  Ed : PEd;
  VMin,VMax,VPos,HMin,HMax,HPos : Integer;
  Dlg : Pointer;
 End;
 TW16Cls = Record
  Used : Boolean;
  Name : String[40];
  PSeg,POfs : Word;
  Style,Brush : Word;
  MenuId : Word; MenuName: String[24];
  Builtin : Boolean;
 End;
 TW16Timer = Record Used: Boolean; Hw,Id: Word; Ms: LongInt; Last: LongInt; PSeg,POfs: Word; End;
 TBrush = Record Kind: Byte; Col: Integer; Pat: Array[0..7] Of Byte; End;
 TW16Obj = Record
  Used : Boolean;
  Kind : Byte;               { 1 pinceau, 2 stylo, 3 police, 4 bitmap }
  Color: LongInt;
  Style,Width: Integer;
  Pat  : Array[0..7] Of Byte;
  Bmp  : PByteArr_;
  BW,BH: Integer;
  Mono : Boolean;
 End;
 TW16Dc = Record
  Used : Boolean;
  Kind : Byte;               { 1 fenetre, 2 memoire, 3 IC }
  Hw   : Word;
  Bmp  : Word;
  Pen,Brush : Word;
  TextCol,BkCol : LongInt;
  BkMode,Rop2 : Integer;
  PenX,PenY : Integer;
  Paint,Active : Boolean;
  ClipOn : Boolean;
  CX1,CY1,CX2,CY2 : Integer;
  OrgX,OrgY : Integer;
  WOx,WOy,VOx,VOy : Integer;
  SvPen,SvBrush : Word;
  SvText,SvBk : LongInt;
 End;
 TW16Res = Record
  Typ  : Word;               { type : $8000+n ou offset de nom }
  Id   : Word;
  TypName,Name : String[20];
  Ofs,Len : LongInt;
  Seg  : Word;               { segment charge ou 0 }
 End;
 TW16MenuTpl = Record
  NMenu : Integer;
  Menus : Array[1..MAXMENU] Of TMenuDef;
 End;
 PW16MenuTpl = ^TW16MenuTpl;
 TW16Sys = Record Id: Integer; Txt: String[30]; Sep,Chk: Boolean; End;
 PW16 = ^TW16;
 TW16 = Record
  V : PVM;
  Wn : Array[1..MAXW16W] Of TW16Win;
  Cl : Array[1..MAXW16C] Of TW16Cls;
  Q  : Array[0..MAXW16Q-1] Of TMsg16;
  QH,QT : Integer;
  Tm : Array[1..MAXW16T] Of TW16Timer;
  Ob : Array[1..MAXW16O] Of TW16Obj;
  Dc : Array[1..MAXW16D] Of TW16Dc;
  Rs : Array[1..MAXW16R] Of TW16Res;
  NRs : Integer;
  MTpl : Array[1..MAXW16MT] Of PW16MenuTpl;
  SysAdd : Array[1..MAXW16SYS] Of TW16Sys;
  NSys : Integer;
  AutoSeg : Word;
  HeapStart,HeapEnd : Word;
  MoveH : Array[1..256] Of Word;
  NMoveH : Integer;
  Exe : String[100];
  FilePath : String[120];
  RsrcOfs : LongInt;
  SegBase : Array[1..128] Of Word;
  SegCnt : Integer;
  Entries : Array[0..255] Of Word;
  Done : Boolean;
  Err : String[100];
  NoRet : Boolean;
  ArgBytes : Integer;
  AO : Array[1..14] Of Integer;
  Painting : Boolean;
  CaretHw : Word; CaretX,CaretY,CaretW,CaretH: Integer; CaretOn: Boolean;
  Focus : Word;
  Ctrl,Shift : Boolean;
  ClipOpen : Boolean;
  ViewHw : Word; ClipSig : LongInt; CapHw : Word;
  CsSeg,CsOfs : Word;
  ModalDepth : Integer;
  NCmdShow : Word;
  LastTick : LongInt;
 End;

Var
 W16List : Array[1..4] Of PW16;
 NW16 : Integer;
 CurW16 : PW16;
 AT : PW16;

Function W16Str(T: PW16; Seg,Ofs: Word; Max: Integer): String;
Var S: String; I: Integer; B: Byte;
Begin
 S:='';
 For I:=0 To Max-1 Do Begin
  B:=RdB(Lin(Seg,Ofs+I));
  If B=0 Then Break;
  S:=S+Chr(B);
 End;
 W16Str:=S;
End;

Procedure W16PutStr(Seg,Ofs: Word; Const S: String; Max: Integer);
Var I,N: Integer;
Begin
 N:=Length(S);
 If N>Max-1 Then N:=Max-1;
 If N<0 Then N:=0;
 For I:=1 To N Do WrB(Lin(Seg,Ofs+I-1),Ord(S[I]));
 If Max>0 Then WrB(Lin(Seg,Ofs+N),0);
End;

{ ---------------- format NE ---------------- }

Function IsNEFile(Const RealPath: String): Boolean;
Var F: File; H: Array[0..63] Of Byte; N: Word; Ofs: LongInt; Sig: Word;
Begin
 IsNEFile:=False;
 {$I-}
 FileMode:=0;
 Assign(F,RealPath);Reset(F,1);
 If IOResult<>0 Then Exit;
 BlockRead(F,H,64,N);
 If (N=64) And (H[0]=$4D) And (H[1]=$5A) And (H[$18]>=$40) Then Begin
  Ofs:=H[$3C]+H[$3D]*256+LongInt(H[$3E])*65536;
  If Ofs>0 Then Begin Seek(F,Ofs);BlockRead(F,Sig,2,N);IsNEFile:=(N=2) And (Sig=$454E);End;
 End;
 Close(F);
 {$I+}
End;

Procedure W16Fail(T: PW16; Const Msg: String);
Begin
 If T^.Err='' Then T^.Err:=Msg;
 T^.Done:=True;
End;

{ lecture de la table des ressources NE }
Procedure W16ReadResources(T: PW16; Var F: File; NeOfs: LongInt; RsrcRel,ResNameRel: Word);
Var Sh,Ty,Cnt,I: Word; P: LongInt; Rec: Array[0..11] Of Byte; Hdr: Array[0..7] Of Byte; N: Word;
    Off,Len,Id: Word; Nm: String; L: Byte; Ch: Array[0..30] Of Byte; K: Integer; TN: String;
 Function NameAt(O: Word): String;
 Var Q: String; J: Integer;
 Begin
  {$I-}Seek(F,NeOfs+RsrcRel+O);BlockRead(F,L,1,N);{$I+}
  Q:='';
  If L>20 Then L:=20;
  For J:=1 To L Do Begin BlockRead(F,Rec,1,N);Q:=Q+Chr(Rec[0]);End;
  NameAt:=Upper(Q);
 End;
Begin
 T^.NRs:=0;
 If RsrcRel=ResNameRel Then Exit;
 {$I-}
 P:=NeOfs+RsrcRel;
 Seek(F,P);BlockRead(F,Sh,2,N);Inc(P,2);
 While True Do Begin
  Seek(F,P);BlockRead(F,Hdr,8,N);
  Ty:=Hdr[0]+Hdr[1]*256;Cnt:=Hdr[2]+Hdr[3]*256;
  If (Ty=0) Or (N<8) Then Break;
  Inc(P,8);
  TN:='';
  For I:=1 To Cnt Do Begin
   Seek(F,P);BlockRead(F,Rec,12,N);Inc(P,12);
   Off:=Rec[0]+Rec[1]*256;Len:=Rec[2]+Rec[3]*256;Id:=Rec[6]+Rec[7]*256;
   If T^.NRs<MAXW16R Then Begin
    Inc(T^.NRs);
    T^.Rs[T^.NRs].Typ:=Ty;T^.Rs[T^.NRs].Id:=Id;
    T^.Rs[T^.NRs].Ofs:=LongInt(Off) Shl Sh;T^.Rs[T^.NRs].Len:=LongInt(Len) Shl Sh;
    T^.Rs[T^.NRs].Seg:=0;T^.Rs[T^.NRs].TypName:='';T^.Rs[T^.NRs].Name:='';
    If (Ty And $8000)=0 Then T^.Rs[T^.NRs].TypName:=NameAt(Ty);
    If (Id And $8000)=0 Then T^.Rs[T^.NRs].Name:=NameAt(Id);
   End;
  End;
 End;
 {$I+}
End;

{ Charge le programme NE ; retourne '' ou un message d'erreur }
Function W16Load(T: PW16; Const VPath: String): String;
Var F: File; Hd: Array[0..63] Of Byte; NeOfs: LongInt; N: Word;
    Ne: Array[0..63] Of Byte;
    SegTab: Array[1..128,0..7] Of Byte; SegOfs,SegLen,SegFl,SegMin: Array[1..128] Of LongInt;
    NSeg,I,J,K,Shift,AutoIdx,CsIdx,SsIdx: Integer; NextSeg,NextUmb: Word; EntTab,ModTab,ImpTab: LongInt;
    NMod,EntLen: Integer; Ip,Sp,StackSz,HeapSz: Word; Len: LongInt;
    Ent: Array[0..16383] Of Byte; ModNames: Array[1..16] Of String[16]; ModOfs: Word; Lg: Byte;
    Pth: String; Cnt: Word; Rec: Array[0..7] Of Byte;
    Ofs,Nx,Tw: Word; Ty,Fl,TgtT: Byte; Mod_,Ord_: Word; Add_: Boolean;
    EntIdx: Integer; Es,Eo: Word; Segn: Byte; V: PVM; DgLen: LongInt; DataEnd: LongInt;
 Function EntryOf(OrdN: Integer; Var S: Word; Var O: Word): Boolean;
 Var P,B,Nn,K2,Cur: Integer;
 Begin
  EntryOf:=False;
  P:=0;Cur:=1;
  While P<EntLen Do Begin
   Nn:=Ent[P];B:=Ent[P+1];
   If Nn=0 Then Break;
   Inc(P,2);
   If B=0 Then Begin Inc(Cur,Nn);Continue;End;
   For K2:=1 To Nn Do Begin
    If B=$FF Then Begin
     If Cur=OrdN Then Begin S:=T^.SegBase[Ent[P+3]];O:=Ent[P+4]+Ent[P+5]*256;EntryOf:=True;Exit;End;
     Inc(P,6);
    End Else Begin
     If Cur=OrdN Then Begin S:=T^.SegBase[B];O:=Ent[P+1]+Ent[P+2]*256;EntryOf:=True;Exit;End;
     Inc(P,3);
    End;
    Inc(Cur);
   End;
  End;
 End;
Begin
 W16Load:='';
 V:=T^.V;
 Pth:=V2R(VPath);
 T^.FilePath:=Pth;
 {$I-}
 FileMode:=0;
 Assign(F,Pth);Reset(F,1);
 If IOResult<>0 Then Begin W16Load:='File not found';Exit;End;
 BlockRead(F,Hd,64,N);
 NeOfs:=Hd[$3C]+Hd[$3D]*256+LongInt(Hd[$3E])*65536;
 Seek(F,NeOfs);BlockRead(F,Ne,64,N);
 {$I+}
 If (N<64) Or (Ne[0]<>$4E) Or (Ne[1]<>$45) Then Begin Close(F);W16Load:='Not a NE executable';Exit;End;
 EntTab:=Ne[4]+Ne[5]*256;EntLen:=Ne[6]+Ne[7]*256;
 AutoIdx:=Ne[$0E]+Ne[$0F]*256;HeapSz:=Ne[$10]+Ne[$11]*256;StackSz:=Ne[$12]+Ne[$13]*256;
 Ip:=Ne[$14]+Ne[$15]*256;CsIdx:=Ne[$16]+Ne[$17]*256;Sp:=Ne[$18]+Ne[$19]*256;SsIdx:=Ne[$1A]+Ne[$1B]*256;
 NSeg:=Ne[$1C]+Ne[$1D]*256;NMod:=Ne[$1E]+Ne[$1F]*256;
 Shift:=Ne[$32]+Ne[$33]*256;If Shift=0 Then Shift:=9;
 ModTab:=Ne[$28]+Ne[$29]*256;ImpTab:=Ne[$2A]+Ne[$2B]*256;
 If NSeg>128 Then Begin Close(F);W16Load:='Too many segments';Exit;End;
 {$I-}
 Seek(F,NeOfs+Ne[$22]+Ne[$23]*256);
 For I:=1 To NSeg Do Begin
  BlockRead(F,SegTab[I],8,N);
  SegOfs[I]:=(SegTab[I,0]+SegTab[I,1]*256) Shl Shift;
  SegLen[I]:=SegTab[I,2]+SegTab[I,3]*256;If SegLen[I]=0 Then SegLen[I]:=65536;
  If (SegTab[I,0]+SegTab[I,1]*256)=0 Then SegLen[I]:=0;
  SegFl[I]:=SegTab[I,4]+SegTab[I,5]*256;
  SegMin[I]:=SegTab[I,6]+SegTab[I,7]*256;If SegMin[I]=0 Then SegMin[I]:=65536;
 End;
 If EntLen>16384 Then EntLen:=16384;
 Seek(F,NeOfs+EntTab);If EntLen>16384 Then EntLen:=16384;BlockRead(F,Ent,EntLen,N);
 For I:=1 To Min2(NMod,16) Do Begin
  Seek(F,NeOfs+ModTab+(I-1)*2);BlockRead(F,ModOfs,2,N);
  Seek(F,NeOfs+ImpTab+ModOfs);BlockRead(F,Lg,1,N);
  ModNames[I]:='';
  For J:=1 To Lg Do Begin BlockRead(F,Rec,1,N);ModNames[I]:=ModNames[I]+Chr(Rec[0]);End;
  ModNames[I]:=Upper(ModNames[I]);
 End;
 {$I+}
 W16ReadResources(T,F,NeOfs,Ne[$24]+Ne[$25]*256,Ne[$26]+Ne[$27]*256);
 ArenaInit(V);
 T^.AutoSeg:=0;
 NextSeg:=$0900;NextUmb:=$C000;
 DgLen:=0;
 For I:=1 To NSeg Do Begin
  Len:=SegMin[I];If Len<SegLen[I] Then Len:=SegLen[I];
  If (I=AutoIdx) Then Begin
   DataEnd:=SegMin[I];
   If DataEnd<SegLen[I] Then DataEnd:=SegLen[I];
   Len:=DataEnd+StackSz+Max2(HeapSz,$3000);
   If Len<SegMin[I] Then Len:=SegMin[I];
   If Len>65520 Then Len:=65520;
   DgLen:=Len;
  End;
  { les segments de code vont d'abord en memoire haute (C000-EFFF), le reste en memoire basse }
  If (I<>AutoIdx) And ((SegFl[I] And 1)=0) And (LongInt(NextUmb)+((Len+15) Div 16)<=$F000) Then Begin
   T^.SegBase[I]:=NextUmb;
   NextUmb:=NextUmb+((Len+15) Div 16);
  End Else Begin
   T^.SegBase[I]:=NextSeg;
   NextSeg:=NextSeg+((Len+15) Div 16);
   If NextSeg>$9C00 Then Begin Close(F);W16Load:='Not enough memory';Exit;End;
  End;
  SegMin[I]:=Len;
  If SegOfs[I]>0 Then Begin
   {$I-}
   Seek(F,SegOfs[I]);
   BlockRead(F,Mem^[Lin(T^.SegBase[I],0)],Min2(SegLen[I],Len),N);
   {$I+}
  End;
 End;
 T^.SegCnt:=NSeg;
 If V^.NBlk>0 Then Begin V^.Blk[1].Seg:=NextSeg;V^.Blk[1].Size:=$A000-NextSeg;V^.Blk[1].Owner:=0;End;
 BuildPsp(V,$0800,0,$0800,$A000,'');
 V^.PSP:=$0800;V^.DTA:=Lin($0800,$80);
 { relogement }
 For I:=1 To NSeg Do Begin
  If ((SegFl[I] And $100)=0) Or (SegOfs[I]=0) Then Continue;
  {$I-}
  Seek(F,SegOfs[I]+SegLen[I]);
  BlockRead(F,Cnt,2,N);
  For J:=1 To Cnt Do Begin
   BlockRead(F,Rec,8,N);
   Ty:=Rec[0] And 15;Fl:=Rec[1];Ofs:=Rec[2]+Rec[3]*256;
   TgtT:=Fl And 3;Add_:=(Fl And 4)<>0;
   Es:=0;Eo:=0;
   If TgtT=0 Then Begin
    Segn:=Rec[4];
    If Segn=$FF Then Begin
     EntIdx:=Rec[6]+Rec[7]*256;
     If Not EntryOf(EntIdx,Es,Eo) Then Begin Es:=0;Eo:=0;End;
    End Else Begin Es:=T^.SegBase[Segn];Eo:=Rec[6]+Rec[7]*256;End;
   End Else If TgtT=1 Then Begin
    Mod_:=Rec[4]+Rec[5]*256;Ord_:=Rec[6]+Rec[7]*256;
    K:=0;
    If Mod_<=16 Then Begin
     If ModNames[Mod_]='KERNEL' Then K:=1 Else If ModNames[Mod_]='GDI' Then K:=2
     Else If ModNames[Mod_]='USER' Then K:=3 Else If ModNames[Mod_]='KEYBOARD' Then K:=4;
    End;
    Es:=ROMSEG;
    If (K=0) Or (Ord_>=1000) Then Eo:=$400+4095 Else Eo:=$400+(K-1)*1024+(Ord_ And 1023);
   End Else Begin
    Es:=ROMSEG;Eo:=$400+4095;
   End;
   If Add_ Then Begin
    Case Ty Of
     0: Mem^[Lin(T^.SegBase[I],Ofs)]:=Mem^[Lin(T^.SegBase[I],Ofs)]+Eo;
     2: WrW(Lin(T^.SegBase[I],Ofs),Es);
     3: Begin WrW(Lin(T^.SegBase[I],Ofs),Eo+RdW(Lin(T^.SegBase[I],Ofs)));WrW(Lin(T^.SegBase[I],Ofs+2),Es);End;
     5: WrW(Lin(T^.SegBase[I],Ofs),Word(RdW(Lin(T^.SegBase[I],Ofs))+Eo));
    End;
   End Else Begin
    Nx:=Ofs;K:=0;
    While (Nx<>$FFFF) And (K<4000) Do Begin
     Tw:=RdW(Lin(T^.SegBase[I],Nx));
     Case Ty Of
      0: Mem^[Lin(T^.SegBase[I],Nx)]:=Eo And 255;
      2: WrW(Lin(T^.SegBase[I],Nx),Es);
      3: Begin WrW(Lin(T^.SegBase[I],Nx),Eo);WrW(Lin(T^.SegBase[I],Nx+2),Es);End;
      5: WrW(Lin(T^.SegBase[I],Nx),Eo);
     End;
     Nx:=Tw;Inc(K);
    End;
   End;
  End;
  {$I+}
 End;
 Close(F);
 If TraceOn Then For I:=1 To NSeg Do WriteLn(TraceF,'SEGMAP ',I,' ',HexStr(T^.SegBase[I],4));
 If AutoIdx>0 Then T^.AutoSeg:=T^.SegBase[AutoIdx];
 If (CsIdx<1) Or (CsIdx>NSeg) Then Begin W16Load:='Invalid entry point';Exit;End;
 For I:=0 To 7 Do Rg[I]:=0;
 Rg[R_AX]:=0;Rg[R_BX]:=StackSz;Rg[R_CX]:=HeapSz;Rg[R_DI]:=T^.AutoSeg;Rg[R_SI]:=0;
 Sg[SG_DS]:=T^.AutoSeg;
 If (SsIdx>0) And (SsIdx<=NSeg) Then Sg[SG_SS]:=T^.SegBase[SsIdx] Else Sg[SG_SS]:=T^.AutoSeg;
 If Sp=0 Then Rg[R_SP]:=Word(DataEnd+StackSz) Else Rg[R_SP]:=Sp;
 If Rg[R_SP]=0 Then Rg[R_SP]:=$FFFE;
 { en-tete du segment de donnees : limites de la pile (verification de pile du compilateur C) }
 If Sg[SG_SS]=T^.AutoSeg Then Begin
  WrW(Lin(T^.AutoSeg,$0A),Word(DataEnd+8));WrW(Lin(T^.AutoSeg,$0C),Rg[R_SP]);WrW(Lin(T^.AutoSeg,$0E),Rg[R_SP]);
 End;
 Sg[SG_ES]:=0;
 Sg[SG_CS]:=T^.SegBase[CsIdx];IPr:=Ip;
 { tas local : apres la pile }
 T^.HeapStart:=Word(DataEnd+StackSz+16);
 T^.HeapEnd:=Word(Min2(65520,DgLen-2));
 If T^.HeapStart>=T^.HeapEnd Then T^.HeapStart:=Word(DataEnd+16);
 { bloc libre initial }
 WrW(Lin(T^.AutoSeg,T^.HeapStart),(T^.HeapEnd-T^.HeapStart-2) And $FFFE);
 T^.CsSeg:=$0800;T^.CsOfs:=$00F0;
 T^.NCmdShow:=1;
 W16Load:='';
End;

{ ---------------- tas local de DGROUP (blocs : mot taille, bit 0 = occupe) ---------------- }

Function HpRd(T: PW16; O: Word): Word;
Begin
 HpRd:=RdW(Lin(T^.AutoSeg,O));
End;

Procedure HpWr(T: PW16; O,V: Word);
Begin
 WrW(Lin(T^.AutoSeg,O),V);
End;

Function W16HeapAlloc(T: PW16; Sz: Word; Zero: Boolean): Word;
Var P,S,Nx: Word; Guard: Integer;
Begin
 W16HeapAlloc:=0;
 Sz:=(Sz+1) And $FFFE;
 If Sz<4 Then Sz:=4;
 P:=T^.HeapStart;Guard:=0;
 While (P<T^.HeapEnd) And (Guard<5000) Do Begin
  S:=HpRd(T,P);
  If (S And 1)=0 Then Begin
   { fusion avec les blocs libres suivants }
   Nx:=P+2+S;
   While (Nx<T^.HeapEnd) And ((HpRd(T,Nx) And 1)=0) And (LongInt(S)+2+HpRd(T,Nx)<65000) Do Begin
    S:=S+2+HpRd(T,Nx);Nx:=P+2+S;
   End;
   HpWr(T,P,S);
   If S>=Sz Then Begin
    If S>=Sz+6 Then Begin HpWr(T,P+2+Sz,S-Sz-2);S:=Sz;End;
    HpWr(T,P,S Or 1);
    If Zero Then FillChar(Mem^[Lin(T^.AutoSeg,P+2)],S,0);
    W16HeapAlloc:=P+2;Exit;
   End;
  End;
  P:=P+2+(S And $FFFE);
  Inc(Guard);
 End;
End;

Procedure W16HeapFree(T: PW16; Ptr: Word);
Begin
 If (Ptr<T^.HeapStart+2) Or (Ptr>=T^.HeapEnd) Then Exit;
 HpWr(T,Ptr-2,HpRd(T,Ptr-2) And $FFFE);
End;

Function W16HeapSize(T: PW16; Ptr: Word): Word;
Begin
 If (Ptr<T^.HeapStart+2) Or (Ptr>=T^.HeapEnd) Then W16HeapSize:=0
 Else W16HeapSize:=HpRd(T,Ptr-2) And $FFFE;
End;

Function W16HeapFreeBytes(T: PW16): LongInt;
Var P,S: Word; Tot: LongInt;
Begin
 Tot:=0;P:=T^.HeapStart;
 While P<T^.HeapEnd Do Begin
  S:=HpRd(T,P);
  If (S And 1)=0 Then Tot:=Tot+S;
  P:=P+2+(S And $FFFE);
  If (S And $FFFE)=0 Then Break;
 End;
 W16HeapFreeBytes:=Tot;
End;

Function MoveIdx(T: PW16; H: Word): Integer;
Var I: Integer;
Begin
 MoveIdx:=0;
 For I:=1 To T^.NMoveH Do If T^.MoveH[I]=H Then Begin MoveIdx:=I;Exit;End;
End;

Function W16LocalAlloc(T: PW16; Fl,Sz: Word): Word;
Var P,C: Word; I: Integer;
Begin
 W16LocalAlloc:=0;
 P:=W16HeapAlloc(T,Sz,(Fl And $40)<>0);
 If P=0 Then Exit;
 If (Fl And 2)<>0 Then Begin
  C:=W16HeapAlloc(T,2,True);
  If C=0 Then Begin W16HeapFree(T,P);Exit;End;
  HpWr(T,C,P);
  If T^.NMoveH<256 Then Begin Inc(T^.NMoveH);T^.MoveH[T^.NMoveH]:=C;End;
  W16LocalAlloc:=C;
 End Else W16LocalAlloc:=P;
End;

Function W16LocalPtr(T: PW16; H: Word): Word;
Begin
 If MoveIdx(T,H)>0 Then W16LocalPtr:=HpRd(T,H) Else W16LocalPtr:=H;
End;

Procedure W16LocalFree(T: PW16; H: Word);
Var I,K: Integer;
Begin
 I:=MoveIdx(T,H);
 If I>0 Then Begin
  W16HeapFree(T,HpRd(T,H));W16HeapFree(T,H);
  For K:=I To T^.NMoveH-1 Do T^.MoveH[K]:=T^.MoveH[K+1];
  Dec(T^.NMoveH);
 End Else W16HeapFree(T,H);
End;

Function W16LocalRealloc(T: PW16; H,Sz,Fl: Word): Word;
Var P,NP,Old: Word; I: Integer;
Begin
 W16LocalRealloc:=0;
 I:=MoveIdx(T,H);
 P:=W16LocalPtr(T,H);
 Old:=W16HeapSize(T,P);
 If Sz<=Old Then Begin W16LocalRealloc:=H;Exit;End;
 NP:=W16HeapAlloc(T,Sz,(Fl And $40)<>0);
 If NP=0 Then Exit;
 Move(Mem^[Lin(T^.AutoSeg,P)],Mem^[Lin(T^.AutoSeg,NP)],Old);
 W16HeapFree(T,P);
 If I>0 Then Begin HpWr(T,H,NP);W16LocalRealloc:=H;End Else W16LocalRealloc:=NP;
End;

{ ---------------- ressources ---------------- }

Function W16FindRes(T: PW16; NameS,NameO,TypS,TypO: Word): Integer;
Var I: Integer; Nm,Ty: String; Id,Tp: Word; ByName,TByName: Boolean;
Begin
 W16FindRes:=0;
 ByName:=NameS<>0;TByName:=TypS<>0;
 If ByName Then Nm:=Upper(W16Str(Nil,NameS,NameO,24)) Else Id:=NameO;
 If TByName Then Ty:=Upper(W16Str(Nil,TypS,TypO,24)) Else Tp:=TypO;
 If ByName And (Length(Nm)>1) And (Nm[1]='#') Then Begin ByName:=False;Id:=StrVal(Copy(Nm,2,6),0);End;
 For I:=1 To T^.NRs Do Begin
  If TByName Then Begin
   If T^.Rs[I].TypName<>Ty Then Continue;
  End Else Begin
   If T^.Rs[I].Typ<>(Tp Or $8000) Then Continue;
  End;
  If ByName Then Begin
   If (T^.Rs[I].Id And $8000)<>0 Then Continue;
   If T^.Rs[I].Name<>Nm Then Continue;
  End Else Begin
   If T^.Rs[I].Id<>(Id Or $8000) Then Continue;
  End;
  W16FindRes:=I;Exit;
 End;
End;

Function W16FindResById(T: PW16; Typ,Id: Word): Integer;
Var I: Integer;
Begin
 W16FindResById:=0;
 For I:=1 To T^.NRs Do
  If (T^.Rs[I].Typ=(Typ Or $8000)) And (T^.Rs[I].Id=(Id Or $8000)) Then Begin W16FindResById:=I;Exit;End;
End;

{ charge une ressource en memoire (retourne le segment) }
Function W16LoadRes(T: PW16; I: Integer): Word;
Var F: File; Par: Word; N: Word;
Begin
 W16LoadRes:=0;
 If (I<1) Or (I>T^.NRs) Then Exit;
 If T^.Rs[I].Seg<>0 Then Begin W16LoadRes:=T^.Rs[I].Seg;Exit;End;
 Par:=(T^.Rs[I].Len+15) Div 16+1;
 T^.Rs[I].Seg:=ArenaAlloc(T^.V,Par,T^.V^.PSP);
 If T^.Rs[I].Seg=0 Then Exit;
 FillChar(Mem^[Lin(T^.Rs[I].Seg,0)],Par*16,0);
 {$I-}
 FileMode:=0;
 Assign(F,T^.FilePath);Reset(F,1);Seek(F,T^.Rs[I].Ofs);
 BlockRead(F,Mem^[Lin(T^.Rs[I].Seg,0)],T^.Rs[I].Len,N);Close(F);
 {$I+}
 W16LoadRes:=T^.Rs[I].Seg;
End;

Function W16ResOfSeg(T: PW16; Seg: Word): Integer;
Var I: Integer;
Begin
 W16ResOfSeg:=0;
 For I:=1 To T^.NRs Do If T^.Rs[I].Seg=Seg Then W16ResOfSeg:=I;
End;

Function W16LoadStr(T: PW16; Id: Word; Var S: String): Boolean;
Var R: Integer; Sg_: Word; I: Integer; P: Word; L: Byte; N: Integer;
Begin
 W16LoadStr:=False;S:='';
 R:=W16FindResById(T,6,(Id Shr 4)+1);
 If R=0 Then Exit;
 Sg_:=W16LoadRes(T,R);
 If Sg_=0 Then Exit;
 P:=0;
 For I:=0 To (Id And 15)-1 Do Begin L:=RdB(Lin(Sg_,P));Inc(P,L+1);End;
 L:=RdB(Lin(Sg_,P));
 For N:=1 To L Do S:=S+Chr(RdB(Lin(Sg_,P+N)));
 W16LoadStr:=True;
End;

{ ---------------- arguments Pascal (l'appele depile) ---------------- }

Procedure SetSig(Const S: String);
Var I,Tot,P: Integer;
Begin
 Tot:=0;
 For I:=1 To Length(S) Do If S[I]='w' Then Inc(Tot,2) Else Inc(Tot,4);
 AT^.ArgBytes:=Tot;
 P:=Tot;
 For I:=1 To Length(S) Do Begin
  If S[I]='w' Then Dec(P,2) Else Dec(P,4);
  AT^.AO[I]:=P;
 End;
End;

Function GW(I: Integer): Word;
Begin
 GW:=RdW(Lin(Sg[SG_SS],Rg[R_SP])+4+AT^.AO[I]);
End;

Function GI(I: Integer): Integer;
Begin
 GI:=SmallInt(GW(I));
End;

Function GL(I: Integer): LongInt;
Begin
 GL:=LongInt(RdW(Lin(Sg[SG_SS],Rg[R_SP])+4+AT^.AO[I]))+(LongInt(RdW(Lin(Sg[SG_SS],Rg[R_SP])+6+AT^.AO[I])) Shl 16);
End;

Function GPO(I: Integer): Word;
Begin
 GPO:=RdW(Lin(Sg[SG_SS],Rg[R_SP])+4+AT^.AO[I]);
End;

Function GPS(I: Integer): Word;
Begin
 GPS:=RdW(Lin(Sg[SG_SS],Rg[R_SP])+6+AT^.AO[I]);
End;

Function GStr(I: Integer): String;
Begin
 If GPS(I)=0 Then GStr:='' Else GStr:=W16Str(AT,GPS(I),GPO(I),255);
End;

Procedure RetW(V: Word);
Begin
 Rg[R_AX]:=V;
End;

Procedure RetL(V: LongInt);
Begin
 Rg[R_AX]:=V And $FFFF;Rg[R_DX]:=(V Shr 16) And $FFFF;
End;

Function RdI(Seg,Ofs: Word): Integer;
Begin
 RdI:=SmallInt(RdW(Lin(Seg,Ofs)));
End;

Procedure W16ReturnFar(Nb: Integer);
Begin
 IPr:=Pop;Sg[SG_CS]:=Pop;
 Inc(Rg[R_SP],Nb);
End;

{ ---------------- appel d'une fonction Pascal emulee ---------------- }

Function W16CallFar(Seg,Ofs: Word; Const Args: Array Of Word; N: Integer): LongInt;
Var SvR: Array[0..7] Of Word; SvS: Array[0..3] Of Word; SvIP: Word; SvF: Word; I: Integer; Guard: LongInt;
    SvBlock,SvNoRet: Boolean; SvRet: LongInt; T: PW16; SvAO: Array[1..14] Of Integer; SvAB: Integer;
Begin
 T:=AT;
 If TraceOn Then WriteLn(TraceF,'  CALLFAR ',HexStr(Seg,4),':',HexStr(Ofs,4),' n=',N);
 Move(Rg,SvR,SizeOf(Rg));Move(Sg,SvS,SizeOf(Sg));SvIP:=IPr;SvF:=GetFlags;SvBlock:=CpuBlock;
 If T<>Nil Then Begin SvNoRet:=T^.NoRet;SvAB:=T^.ArgBytes;Move(T^.AO,SvAO,SizeOf(SvAO));End;
 If T<>Nil Then Begin Sg[SG_DS]:=T^.AutoSeg;Rg[R_AX]:=T^.AutoSeg;End;
 For I:=0 To N-1 Do Push(Args[I]);
 Push(ROMSEG);Push(W16_TRAP_RET);
 Sg[SG_CS]:=Seg;IPr:=Ofs;
 Guard:=0;
 While Not ((Sg[SG_CS]=ROMSEG) And (IPr=W16_TRAP_RET)) And (Guard<4000000) And Not CpuHalt Do Begin
  CpuBlock:=False;
  If T<>Nil Then If T^.Done Then Break;
  If TraceOn And (TrApi>=-5) And (TrApi<=-5) Then WriteLn(TraceF,'STEP ',HexStr(Sg[SG_CS],4),':',HexStr(IPr,4),' op=',HexStr(Mem^[Lin(Sg[SG_CS],IPr)],2),' AX=',HexStr(Rg[R_AX],4),' SP=',HexStr(Rg[R_SP],4));
  CpuStep;
  Inc(Guard);
  If CpuBlock And Not ((Sg[SG_CS]=ROMSEG) And (IPr=W16_TRAP_RET)) Then Break;
 End;
 SvRet:=LongInt(Rg[R_AX])+(LongInt(Rg[R_DX]) Shl 16);
 Move(SvR,Rg,SizeOf(Rg));Move(SvS,Sg,SizeOf(Sg));IPr:=SvIP;SetFlags(SvF);CpuBlock:=SvBlock;
 If T<>Nil Then Begin
  T^.NoRet:=SvNoRet;T^.ArgBytes:=SvAB;Move(SvAO,T^.AO,SizeOf(SvAO));
  If Guard>=4000000 Then W16Fail(T,'Runaway window procedure');
  If CpuHalt Then Begin W16Fail(T,CpuErr);CpuHalt:=False;End;
 End;
 W16CallFar:=SvRet;
End;

{ fenetres hotes }

Function W16HostOf(T: PW16; Hw: Word): PWindow;
Begin
 W16HostOf:=Nil;
 If (Hw>=1) And (Hw<=MAXW16W) And T^.Wn[Hw].Used Then Begin
  If T^.Wn[Hw].Host<>Nil Then Begin W16HostOf:=T^.Wn[Hw].Host;Exit;End;
  If T^.Wn[Hw].Parent<>0 Then W16HostOf:=W16HostOf(T,T^.Wn[Hw].Parent);
 End;
End;

Function W16WndProc(T: PW16; Hw: Word; Msg,Wp: Word; Lp: LongInt): LongInt;
Var A: Array[0..4] Of Word; PS,PO: Word;
Begin
 W16WndProc:=0;
 If (Hw<1) Or (Hw>MAXW16W) Or Not T^.Wn[Hw].Used Then Exit;
 PS:=T^.Wn[Hw].PSeg;PO:=T^.Wn[Hw].POfs;
 If PS=0 Then Exit;
 A[0]:=Hw;A[1]:=Msg;A[2]:=Wp;A[3]:=(Lp Shr 16) And $FFFF;A[4]:=Lp And $FFFF;
 AT:=T;
 If TraceOn Then WriteLn(TraceF,'MSG hw=',Hw,' msg=',HexStr(Msg,4),' wp=',HexStr(Wp,4),' lp=',HexStr(Lp,8),' SP=',HexStr(Rg[R_SP],4));
 W16WndProc:=W16CallFar(PS,PO,A,5);
 AT:=T;
End;

Procedure W16Post(T: PW16; Hw,Msg,Wp: Word; Lp: LongInt);
Var N: Integer;
Begin
 N:=(T^.QT+1) Mod MAXW16Q;
 If N=T^.QH Then Exit;
 T^.Q[T^.QT].Hw:=Hw;T^.Q[T^.QT].Msg:=Msg;T^.Q[T^.QT].Wp:=Wp;T^.Q[T^.QT].Lp:=Lp;
 T^.Q[T^.QT].Tm:=NowCs*10;T^.Q[T^.QT].Px:=0;T^.Q[T^.QT].Py:=0;
 T^.QT:=N;
End;

{ ---------------- couleurs, objets GDI ---------------- }

Function W16Col(C: LongInt): Integer;
Begin
 If C<0 Then Begin W16Col:=cBlk;Exit;End;
 W16Col:=NearestVga(C And 255,(C Shr 8) And 255,(C Shr 16) And 255);
End;

Function W16ObjNew(T: PW16; Kind: Byte; Color: LongInt; Style,Width: Integer): Word;
Var I: Integer;
Begin
 W16ObjNew:=0;
 For I:=1 To MAXW16O Do If Not T^.Ob[I].Used Then Begin
  FillChar(T^.Ob[I],SizeOf(TW16Obj),0);
  T^.Ob[I].Used:=True;T^.Ob[I].Kind:=Kind;T^.Ob[I].Color:=Color;T^.Ob[I].Style:=Style;T^.Ob[I].Width:=Width;
  W16ObjNew:=$100+I;Exit;
 End;
End;

Function ObjOf(T: PW16; H: Word): Integer;
Begin
 If (H>$100) And (H<=$100+MAXW16O) And T^.Ob[H-$100].Used Then ObjOf:=H-$100 Else ObjOf:=0;
End;

Procedure W16ObjFree(T: PW16; H: Word);
Var I: Integer;
Begin
 I:=ObjOf(T,H);
 If I=0 Then Exit;
 If (T^.Ob[I].Kind=4) And (T^.Ob[I].Bmp<>Nil) Then FreeMem(T^.Ob[I].Bmp,T^.Ob[I].BW*T^.Ob[I].BH);
 T^.Ob[I].Bmp:=Nil;T^.Ob[I].Used:=False;
End;

Function W16BmpNew(T: PW16; W,H: Integer; Mono: Boolean): Word;
Var Hn: Word; I: Integer;
Begin
 W16BmpNew:=0;
 If (W<=0) Or (H<=0) Or (LongInt(W)*H>400000) Then Exit;
 Hn:=W16ObjNew(T,4,0,0,0);
 If Hn=0 Then Exit;
 I:=Hn-$100;
 GetMem(T^.Ob[I].Bmp,LongInt(W)*H);
 FillChar(T^.Ob[I].Bmp^,LongInt(W)*H,IfThen_(Mono,1,15));
 T^.Ob[I].BW:=W;T^.Ob[I].BH:=H;T^.Ob[I].Mono:=Mono;
 W16BmpNew:=Hn;
End;

{ ---------------- contextes de peripherique ---------------- }

Function W16DcNew(T: PW16; Kind: Byte; Hw: Word): Word;
Var I: Integer;
Begin
 W16DcNew:=0;
 For I:=1 To MAXW16D Do If Not T^.Dc[I].Used Then Begin
  FillChar(T^.Dc[I],SizeOf(TW16Dc),0);
  T^.Dc[I].Used:=True;T^.Dc[I].Kind:=Kind;T^.Dc[I].Hw:=Hw;
  T^.Dc[I].Pen:=$27;T^.Dc[I].Brush:=$20;
  T^.Dc[I].TextCol:=0;T^.Dc[I].BkCol:=$FFFFFF;T^.Dc[I].BkMode:=2;T^.Dc[I].Rop2:=13;
  W16DcNew:=$4000+I;Exit;
 End;
End;

Function DcIdx(T: PW16; H: Word): Integer;
Begin
 If (H>$4000) And (H<=$4000+MAXW16D) And T^.Dc[H-$4000].Used Then DcIdx:=H-$4000 Else DcIdx:=0;
End;

Var Glyph: Array[0..255,0..7] Of Byte; GlyphOk: Boolean;

Procedure BuildGlyphs;
Var Sv: TSave; C,Row,Col,Y,K,P: Integer; S: String;
Begin
 If GlyphOk Then Exit;
 HideMouse;
 ClipFull;
 SaveBack(Sv,0,SCR_H-10,SCR_W-1,SCR_H-1);
 For P:=0 To 3 Do Begin
  SetFillStyle(SolidFill,cWht);Bar(0,SCR_H-10,SCR_W-1,SCR_H-1);
  S:='';
  For K:=0 To 63 Do Begin
   C:=P*64+K;
   If (C<32) Or (C=136) Then S:=S+' ' Else S:=S+Chr(C);
  End;
  SetColor(cBlk);SetTextStyle(DefaultFont,HorizDir,1);
  OutTextXY(0,SCR_H-9,S);
  For K:=0 To 63 Do
   For Row:=0 To 7 Do Begin
    Y:=0;
    For Col:=0 To 7 Do If GetPixel(K*8+Col,SCR_H-9+Row)=cBlk Then Y:=Y Or (128 Shr Col);
    Glyph[P*64+K,Row]:=Y;
   End;
 End;
 RestoreBack(Sv);
 ShowMouse;
 GlyphOk:=True;
End;

{ preparation d'un DC avant dessin ; retourne False si rien a faire }


Var AtomTab: Array[1..64] Of String[40];
    PropTab: Array[1..32] Of Record Hw: Word; Nm: String[30]; V: Word; End;

Function AtomFind(Const S: String; Add: Boolean): Word;
Var I: Integer;
Begin
 AtomFind:=0;
 For I:=1 To 64 Do If (AtomTab[I]<>'') And (Upper(AtomTab[I])=Upper(S)) Then Begin AtomFind:=$C000+I;Exit;End;
 If Add Then For I:=1 To 64 Do If AtomTab[I]='' Then Begin AtomTab[I]:=Copy(S,1,40);AtomFind:=$C000+I;Exit;End;
End;

{ origine absolue (ecran) du client d'une fenetre (haute ou enfant) et rectangle de clip absolu }
Function W16ClientOrg(T: PW16; Hw: Word; Var Ox,Oy,X1,Y1,X2,Y2: Integer): Boolean;
Var W: PWindow; Px,Py,A1,B1,A2,B2,Bd: Integer;
Begin
 W16ClientOrg:=False;
 If (Hw<1) Or (Hw>MAXW16W) Or Not T^.Wn[Hw].Used Then Exit;
 If T^.Wn[Hw].Parent=0 Then Begin
  W:=W16HostOf(T,Hw);
  If W=Nil Then Exit;
  WinClient(W,X1,Y1,X2,Y2);Ox:=X1;Oy:=Y1;
  W16ClientOrg:=True;Exit;
 End;
 If Not W16ClientOrg(T,T^.Wn[Hw].Parent,Px,Py,A1,B1,A2,B2) Then Exit;
 Bd:=IfThen_((T^.Wn[Hw].Style And $00800000)<>0,1,0);
 Ox:=Px+T^.Wn[Hw].X+Bd;Oy:=Py+T^.Wn[Hw].Y+Bd;
 X1:=Max2(A1,Ox);Y1:=Max2(B1,Oy);
 X2:=Min2(A2,Px+T^.Wn[Hw].X+T^.Wn[Hw].W-1-Bd-IfThen_((T^.Wn[Hw].Style And $00200000)<>0,SB,0));
 Y2:=Min2(B2,Py+T^.Wn[Hw].Y+T^.Wn[Hw].H-1-Bd-IfThen_((T^.Wn[Hw].Style And $00100000)<>0,SB,0));
 W16ClientOrg:=True;
End;

Function W16IsDesc(T: PW16; Hw,Anc: Word): Boolean;
Var N: Integer;
Begin
 W16IsDesc:=False;N:=0;
 While (Hw<>0) And (N<20) Do Begin
  Hw:=T^.Wn[Hw].Parent;Inc(N);
  If Hw=Anc Then Begin W16IsDesc:=True;Exit;End;
 End;
End;

Procedure W16GetClient(T: PW16; Hw: Word; Var X1,Y1,X2,Y2: Integer);
Var W: PWindow;
Begin
 X1:=0;Y1:=0;X2:=0;Y2:=0;
 If (Hw>=1) And (Hw<=MAXW16W) And T^.Wn[Hw].Used And (T^.Wn[Hw].Parent<>0) Then Begin
  X2:=T^.Wn[Hw].W-1;Y2:=T^.Wn[Hw].H-1;
  If (T^.Wn[Hw].Style And $00800000)<>0 Then Begin Dec(X2,2);Dec(Y2,2);End;
  If (T^.Wn[Hw].Style And $00200000)<>0 Then Dec(X2,SB);
  If (T^.Wn[Hw].Style And $00100000)<>0 Then Dec(Y2,SB);
  Exit;
 End;
 W:=W16HostOf(T,Hw);
 If W<>Nil Then Begin WinClient(W,X1,Y1,X2,Y2);X2:=X2-X1;Y2:=Y2-Y1;X1:=0;Y1:=0;End;
End;

Function DcBegin(T: PW16; D: Integer): Boolean;
Var W: PWindow; X1,Y1,X2,Y2: Integer;
Begin
 DcBegin:=False;
 With T^.Dc[D] Do Begin
  Case Kind Of
   2: Begin DcBegin:=ObjOf(T,Bmp)>0;Exit;End;
   1: Begin
       W:=W16HostOf(T,Hw);
       If (W=Nil) Or (W^.State=1) Then Exit;
       If Not W16ClientOrg(T,Hw,OrgX,OrgY,X1,Y1,X2,Y2) Then Exit;
       OrgX:=OrgX+VOx-WOx;OrgY:=OrgY+VOy-WOy;
       If Not Paint Then Begin
        If W<>ActiveWin Then Exit;
        If Not Active Then Begin HideMouse;Active:=True;End;
       End;
       If ClipOn Then SetClip(Max2(X1,OrgX+CX1),Max2(Y1,OrgY+CY1),Min2(X2,OrgX+CX2-1),Min2(Y2,OrgY+CY2-1))
       Else SetClip(X1,Y1,X2,Y2);
       DcBegin:=True;
      End;
  End;
 End;
End;

Procedure DcEnd(T: PW16; D: Integer);
Begin
 If T^.Dc[D].Active Then Begin ClipFull;ShowMouse;T^.Dc[D].Active:=False;End;
End;

Function MonoOf(C: Integer): Byte;
Begin
 If C>=7 Then MonoOf:=1 Else MonoOf:=0;
End;

Procedure DcPix(T: PW16; D: Integer; X,Y,C: Integer);
Var O: Integer;
Begin
 With T^.Dc[D] Do
  If Kind=2 Then Begin
   O:=ObjOf(T,Bmp);
   If (O>0) And (X>=0) And (Y>=0) And (X<T^.Ob[O].BW) And (Y<T^.Ob[O].BH) Then
    If T^.Ob[O].Mono Then T^.Ob[O].Bmp^[Y*T^.Ob[O].BW+X]:=MonoOf(C) Else T^.Ob[O].Bmp^[Y*T^.Ob[O].BW+X]:=C;
  End Else GPix(OrgX+X,OrgY+Y,C);
End;

Function DcGet(T: PW16; D: Integer; X,Y: Integer; Var IsMono: Boolean): Integer;
Var O: Integer;
Begin
 IsMono:=False;DcGet:=0;
 With T^.Dc[D] Do
  If Kind=2 Then Begin
   O:=ObjOf(T,Bmp);
   If (O>0) And (X>=0) And (Y>=0) And (X<T^.Ob[O].BW) And (Y<T^.Ob[O].BH) Then Begin
    DcGet:=T^.Ob[O].Bmp^[Y*T^.Ob[O].BW+X];IsMono:=T^.Ob[O].Mono;
   End;
  End Else DcGet:=GGetPix(OrgX+X,OrgY+Y);
End;

Procedure DcBar(T: PW16; D: Integer; X1,Y1,X2,Y2,C: Integer);
Var X,Y: Integer;
Begin
 If (X2<X1) Or (Y2<Y1) Then Exit;
 If T^.Dc[D].Kind=2 Then Begin
  For Y:=Y1 To Y2 Do For X:=X1 To X2 Do DcPix(T,D,X,Y,C);
 End Else GBar(T^.Dc[D].OrgX+X1,T^.Dc[D].OrgY+Y1,T^.Dc[D].OrgX+X2,T^.Dc[D].OrgY+Y2,C);
End;

Procedure DcLine(T: PW16; D: Integer; X1,Y1,X2,Y2,C: Integer);
Var DX,DY,SX,SY,E,E2: Integer; Xr: Boolean;
Begin
 Xr:=(T^.Dc[D].Rop2=7) Or (T^.Dc[D].Rop2=6);
 If Xr And (T^.Dc[D].Rop2=6) Then C:=15;
 If T^.Dc[D].Kind<>2 Then Begin
  If Xr Then SetWriteMode(XORPut);
  GLine(T^.Dc[D].OrgX+X1,T^.Dc[D].OrgY+Y1,T^.Dc[D].OrgX+X2,T^.Dc[D].OrgY+Y2,C);
  If Xr Then SetWriteMode(NormalPut);
  Exit;
 End;
 DX:=Abs(X2-X1);DY:=-Abs(Y2-Y1);
 If X1<X2 Then SX:=1 Else SX:=-1;
 If Y1<Y2 Then SY:=1 Else SY:=-1;
 E:=DX+DY;
 While True Do Begin
  DcPix(T,D,X1,Y1,C);
  If (X1=X2) And (Y1=Y2) Then Break;
  E2:=2*E;
  If E2>=DY Then Begin E:=E+DY;X1:=X1+SX;End;
  If E2<=DX Then Begin E:=E+DX;Y1:=Y1+SY;End;
 End;
End;

{ couleur de pinceau a un point : -1 = creux }
Function BrushPix(T: PW16; D: Integer; X,Y: Integer): Integer;
Var H: Word; O: Integer; B: Byte;
Begin
 H:=T^.Dc[D].Brush;
 BrushPix:=-1;
 If H<$100 Then Begin
  Case H-$20 Of
   0: BrushPix:=cWht; 1: BrushPix:=cLGr; 2: BrushPix:=cDGr; 3: BrushPix:=cDGr; 4: BrushPix:=cBlk;
  Else BrushPix:=-1;
  End;
  If H=$21 Then BrushPix:=cLGr;
  If H=$22 Then BrushPix:=IfThen_(((X+Y) And 1)=0,cBlk,cWht);
  If H=$23 Then BrushPix:=cDGr;
  Exit;
 End;
 O:=ObjOf(T,H);
 If O=0 Then Exit;
 If T^.Ob[O].Style=3 Then Begin
  B:=(T^.Ob[O].Pat[Y And 7] Shr (7-(X And 7))) And 1;
  If B=1 Then BrushPix:=W16Col(T^.Dc[D].BkCol) Else BrushPix:=W16Col(T^.Dc[D].TextCol);
 End Else If T^.Ob[O].Style=1 Then BrushPix:=-1
 Else BrushPix:=W16Col(T^.Ob[O].Color);
End;

Procedure DcFillBrush(T: PW16; D: Integer; X1,Y1,X2,Y2: Integer);
Var X,Y,C,C0: Integer; Solid: Boolean;
Begin
 If (X2<X1) Or (Y2<Y1) Then Exit;
 C0:=BrushPix(T,D,0,0);
 Solid:=True;
 If (T^.Dc[D].Brush>=$100) And (ObjOf(T,T^.Dc[D].Brush)>0) Then
  If T^.Ob[ObjOf(T,T^.Dc[D].Brush)].Style=3 Then Solid:=False;
 If (T^.Dc[D].Brush=$22) Then Solid:=False;
 If Solid Then Begin If C0>=0 Then DcBar(T,D,X1,Y1,X2,Y2,C0);Exit;End;
 For Y:=Y1 To Y2 Do For X:=X1 To X2 Do Begin
  C:=BrushPix(T,D,X,Y);
  If C>=0 Then DcPix(T,D,X,Y,C);
 End;
End;

Function PenCol(T: PW16; D: Integer; Var Null: Boolean): Integer;
Var O: Integer;
Begin
 Null:=False;
 PenCol:=cBlk;
 If T^.Dc[D].Pen<$100 Then Begin
  Case T^.Dc[D].Pen-$20 Of
   6: PenCol:=cWht; 7: PenCol:=cBlk; 8: Null:=True;
  End;
  Exit;
 End;
 O:=ObjOf(T,T^.Dc[D].Pen);
 If O=0 Then Exit;
 If T^.Ob[O].Style=5 Then Null:=True;
 PenCol:=W16Col(T^.Ob[O].Color);
End;

Function PenWidth(T: PW16; D: Integer): Integer;
Var O: Integer;
Begin
 PenWidth:=1;
 O:=ObjOf(T,T^.Dc[D].Pen);
 If (O>0) And (T^.Ob[O].Width>1) Then PenWidth:=Min2(T^.Ob[O].Width,8);
End;

Procedure DcPenLine(T: PW16; D: Integer; X1,Y1,X2,Y2: Integer);
Var C,W,I: Integer; Nl: Boolean;
Begin
 C:=PenCol(T,D,Nl);
 If Nl Then Exit;
 W:=PenWidth(T,D);
 DcLine(T,D,X1,Y1,X2,Y2,C);
 For I:=1 To W-1 Do Begin
  If Abs(X2-X1)>=Abs(Y2-Y1) Then DcLine(T,D,X1,Y1+I,X2,Y2+I,C) Else DcLine(T,D,X1+I,Y1,X2+I,Y2,C);
 End;
End;

Procedure DcRectangle(T: PW16; D: Integer; X1,Y1,X2,Y2: Integer);
Var C: Integer; Nl: Boolean;
Begin
 If X2<X1 Then Exit;
 DcFillBrush(T,D,X1,Y1,X2-1,Y2-1);
 C:=PenCol(T,D,Nl);
 If Not Nl Then Begin
  DcLine(T,D,X1,Y1,X2-1,Y1,C);DcLine(T,D,X2-1,Y1,X2-1,Y2-1,C);
  DcLine(T,D,X2-1,Y2-1,X1,Y2-1,C);DcLine(T,D,X1,Y2-1,X1,Y1,C);
 End;
End;

Procedure DcEllipse(T: PW16; D: Integer; X1,Y1,X2,Y2: Integer);
Var CX,CY,RX,RY,Y,N,I,Hx: Integer; A: Double; C,C2: Integer; Nl: Boolean;
Begin
 CX:=(X1+X2) Div 2;CY:=(Y1+Y2) Div 2;RX:=Abs(X2-X1) Div 2;RY:=Abs(Y2-Y1) Div 2;
 If (RX=0) Or (RY=0) Then Exit;
 For Y:=-RY To RY Do Begin
  Hx:=Round(RX*Sqrt(1-Sqr(Y/RY)));
  DcFillBrush(T,D,CX-Hx,CY+Y,CX+Hx,CY+Y);
 End;
 C:=PenCol(T,D,Nl);
 If Nl Then Exit;
 N:=(RX+RY)*4;
 For I:=0 To N-1 Do Begin
  A:=I*2*Pi/N;
  DcPix(T,D,CX+Round(Cos(A)*RX),CY+Round(Sin(A)*RY),C);
 End;
End;

Procedure DcText(T: PW16; D: Integer; X,Y: Integer; Const S: String);
Var I,Row,Col,Ch: Integer; Fg,Bg: Integer; Bits: Byte;
Begin
 Fg:=W16Col(T^.Dc[D].TextCol);Bg:=W16Col(T^.Dc[D].BkCol);
 If T^.Dc[D].Kind=2 Then Begin
  BuildGlyphs;
  For I:=1 To Length(S) Do Begin
   Ch:=Ord(S[I]);
   For Row:=0 To 7 Do Begin
    Bits:=Glyph[Ch,Row];
    For Col:=0 To 7 Do
     If (Bits And (128 Shr Col))<>0 Then DcPix(T,D,X+(I-1)*8+Col,Y+Row,Fg)
     Else If T^.Dc[D].BkMode=2 Then DcPix(T,D,X+(I-1)*8+Col,Y+Row,Bg);
   End;
  End;
 End Else Begin
  If T^.Dc[D].BkMode=2 Then GBar(T^.Dc[D].OrgX+X,T^.Dc[D].OrgY+Y,T^.Dc[D].OrgX+X+Length(S)*8-1,T^.Dc[D].OrgY+Y+8,Bg);
  GText(T^.Dc[D].OrgX+X,T^.Dc[D].OrgY+Y,S,Fg);
 End;
End;

{ operation raster sur un pixel }
Function RopPix(Rop: LongInt; S,Dd: Integer): Integer;
Begin
 Case Rop And $FFFFFF Of
  $CC0020: RopPix:=S;
  $330008: RopPix:=S Xor 15;
  $8800C6: RopPix:=S And Dd;
  $EE0086: RopPix:=S Or Dd;
  $660046: RopPix:=S Xor Dd;
  $440328: RopPix:=S And (Dd Xor 15);
  $220326: RopPix:=(S Xor 15) And Dd;
  $550009: RopPix:=Dd Xor 15;
  $000042: RopPix:=0;
  $FF0062: RopPix:=15;
 Else RopPix:=S;
 End;
End;

Function RopPatOnly(Rop: LongInt): Boolean;
Begin
 Rop:=Rop And $FFFFFF;
 RopPatOnly:=(Rop=$42) Or (Rop=$FF0062) Or (Rop=$550009) Or (Rop=$F00021) Or (Rop=$5A0049);
End;

Procedure W16BitBlt(T: PW16; Dd: Integer; DX,DY,Wd,Ht: Integer; Sd: Integer; SX,SY,SW,SH: Integer; Rop: LongInt);
Var X,Y,S,Dp,Sx_,Sy_,Rs: Integer; M,DstMono: Boolean; Pat: Boolean;
Begin
 If (Wd<=0) Or (Ht<=0) Then Exit;
 For Y:=0 To Ht-1 Do
  For X:=0 To Wd-1 Do Begin
   Case Rop And $FFFFFF Of
    $F00021: Begin Rs:=BrushPix(T,Dd,DX+X,DY+Y);If Rs>=0 Then DcPix(T,Dd,DX+X,DY+Y,Rs);End;
    $5A0049: Begin Rs:=BrushPix(T,Dd,DX+X,DY+Y);Dp:=DcGet(T,Dd,DX+X,DY+Y,DstMono);If Rs>=0 Then DcPix(T,Dd,DX+X,DY+Y,Dp Xor Rs);End;
    $000042: DcPix(T,Dd,DX+X,DY+Y,0);
    $FF0062: DcPix(T,Dd,DX+X,DY+Y,15);
    $550009: Begin Dp:=DcGet(T,Dd,DX+X,DY+Y,DstMono);DcPix(T,Dd,DX+X,DY+Y,Dp Xor 15);End;
   Else Begin
     If SW=Wd Then Sx_:=SX+X Else Sx_:=SX+(X*SW) Div Wd;
     If SH=Ht Then Sy_:=SY+Y Else Sy_:=SY+(Y*SH) Div Ht;
     S:=DcGet(T,Sd,Sx_,Sy_,M);
     If M Then Begin
      { bitmap monochrome : 1 -> couleur de fond, 0 -> couleur du texte }
      If S=1 Then S:=W16Col(T^.Dc[Dd].BkCol) Else S:=W16Col(T^.Dc[Dd].TextCol);
     End;
     Dp:=DcGet(T,Dd,DX+X,DY+Y,DstMono);
     DcPix(T,Dd,DX+X,DY+Y,RopPix(Rop,S,Dp));
    End;
   End;
  End;
End;

{ bitmap monochrome / couleur depuis les bits de l'application (lignes alignees sur un mot) }
Procedure W16BmpFromBits(T: PW16; H: Word; Seg,Ofs: Word; WB: Integer; Planes,Bpp: Integer);
Var O,X,Y,P: Integer; B,Bit: Byte; A: LongInt;
Begin
 O:=ObjOf(T,H);
 If O=0 Then Exit;
 For Y:=0 To T^.Ob[O].BH-1 Do
  For X:=0 To T^.Ob[O].BW-1 Do Begin
   If T^.Ob[O].Mono Then Begin
    B:=RdB(Lin(Seg,Ofs+Y*WB+(X Shr 3)));
    T^.Ob[O].Bmp^[Y*T^.Ob[O].BW+X]:=(B Shr (7-(X And 7))) And 1;
   End Else Begin
    Bit:=0;
    For P:=0 To Planes-1 Do Begin
     B:=RdB(Lin(Seg,Ofs+(Y*Planes+P)*WB+(X Shr 3)));
     Bit:=Bit Or (((B Shr (7-(X And 7))) And 1) Shl P);
    End;
    T^.Ob[O].Bmp^[Y*T^.Ob[O].BW+X]:=Bit;
   End;
  End;
End;


{ bitmaps systeme OEM (OBM_*) : fleches 16x16 monochromes }
Function W16SysBitmap(T: PW16; Id: Word): Word;
Var Hn: Word; O,X,Y,D: Integer;
Begin
 W16SysBitmap:=0;
 Hn:=W16BmpNew(T,16,16,True);
 If Hn=0 Then Exit;
 O:=Hn-$100;
 For X:=0 To 15 Do Begin
  T^.Ob[O].Bmp^[X]:=0;T^.Ob[O].Bmp^[15*16+X]:=0;
  T^.Ob[O].Bmp^[X*16]:=0;T^.Ob[O].Bmp^[X*16+15]:=0;
 End;
 For Y:=0 To 15 Do For X:=0 To 15 Do Begin
  D:=-1;
  Case Id Of
   32762,32750: If (X>=4) And (X<=10) And (Abs(Y-7)<=X-4) Then D:=0;
   32763,32751: If (X>=5) And (X<=11) And (Abs(Y-7)<=11-X) Then D:=0;
   32765,32753: If (Y>=4) And (Y<=10) And (Abs(X-7)<=Y-4) Then D:=0;
   32764,32752: If (Y>=5) And (Y<=11) And (Abs(X-7)<=11-Y) Then D:=0;
   32760: If (Y>=3) And (Y<=12) And ((X=Y-2) Or (X=13-Y+3)) Then D:=0;
  End;
  If D=0 Then T^.Ob[O].Bmp^[Y*16+X]:=0;
 End;
 W16SysBitmap:=Hn;
End;

{ ressource bitmap (en-tete 16 octets : type, ?, largeur, hauteur, octets/ligne, plans, bits/pixel) }
Function W16LoadBitmapRes(T: PW16; R: Integer): Word;
Var Sg_: Word; W,H,WB,Pl,Bp: Integer; Hn: Word;
Begin
 W16LoadBitmapRes:=0;
 Sg_:=W16LoadRes(T,R);
 If Sg_=0 Then Exit;
 W:=RdW(Lin(Sg_,4));H:=RdW(Lin(Sg_,6));WB:=RdW(Lin(Sg_,8));Pl:=RdB(Lin(Sg_,10));Bp:=RdB(Lin(Sg_,11));
 If (W<=0) Or (H<=0) Or (W>1000) Or (H>1000) Then Exit;
 Hn:=W16BmpNew(T,W,H,(Pl*Bp)=1);
 If Hn=0 Then Exit;
 W16BmpFromBits(T,Hn,Sg_,16,WB,Pl,Bp);
 W16LoadBitmapRes:=Hn;
End;

{ icone 64x64 monochrome (masque AND puis XOR) vers un DC ecran }
Procedure W16DrawIconRes(T: PW16; Seg_: Word; X,Y,Sz: Integer);
Var I,J,Sx,Sy,Step,Bx,By,Nb,Nw: Integer; A,Xr: Byte; BaseA,BaseX: LongInt; Wd: Integer;
Begin
 Wd:=RdW(Lin(Seg_,6));
 If (Wd<8) Or (Wd>64) Then Exit;
 BaseA:=16;BaseX:=16+LongInt(Wd)*Wd Div 8;
 Step:=Wd Div Sz;If Step<1 Then Step:=1;
 For J:=0 To Sz-1 Do
  For I:=0 To Sz-1 Do Begin
   Nb:=0;Nw:=0;
   For By:=0 To Step-1 Do
    For Bx:=0 To Step-1 Do Begin
     Sx:=I*Step+Bx;Sy:=J*Step+By;
     A:=(RdB(Lin(Seg_,BaseA+Sy*(Wd Div 8)+(Sx Shr 3))) Shr (7-(Sx And 7))) And 1;
     Xr:=(RdB(Lin(Seg_,BaseX+Sy*(Wd Div 8)+(Sx Shr 3))) Shr (7-(Sx And 7))) And 1;
     If A=0 Then Begin If Xr=1 Then Inc(Nw) Else Inc(Nb);End
     Else If Xr=1 Then Inc(Nb);
    End;
   If Nb>0 Then GPix(X+I,Y+J,cBlk) Else If Nw>0 Then GPix(X+I,Y+J,cWht);
  End;
End;

{ ---------------- menus ---------------- }

Type
 TMenuArr = Array[1..MAXMENU] Of TMenuDef;
 PMenuArr = ^TMenuArr;
 PIntP = ^Integer;

Function MenuSetOf(T: PW16; H: Word; Var Ms: PMenuArr; Var Nm: PIntP; Var Pop: Integer; Var Hw: Word): Boolean;
Var W: PWindow; K: Integer;
Begin
 MenuSetOf:=False;Pop:=0;Hw:=0;
 If (H>=$7C00) And (H<$7C00+MAXW16MT) Then Begin
  K:=H-$7C00;
  If T^.MTpl[K]=Nil Then Exit;
  Ms:=@T^.MTpl[K]^.Menus;Nm:=@T^.MTpl[K]^.NMenu;MenuSetOf:=True;Exit;
 End;
 If (H>=$7000) And (H<$7000+MAXW16W*32) Then Begin
  Hw:=(H-$7000) Div 32;Pop:=(H-$7000) Mod 32;
  W:=W16HostOf(T,Hw);
  If W=Nil Then Exit;
  Ms:=@W^.Menus;Nm:=@W^.NMenu;MenuSetOf:=True;
 End;
End;

Procedure MnuAddPopup(Ms: PMenuArr; Nm: PIntP; Const Title: String);
Begin
 If Nm^>=MAXMENU Then Exit;
 Inc(Nm^);Ms^[Nm^].Title:=Title;Ms^[Nm^].N:=0;
End;

Procedure MnuAddItem(Ms: PMenuArr; Pop: Integer; Const Txt0: String; Id: Integer; Fl: Integer);
Var Txt,Key: String; P: Integer;
Begin
 If (Pop<1) Or (Pop>MAXMENU) Or (Ms^[Pop].N>=MAXITEM) Then Exit;
 P:=Pos(#9,Txt0);
 If P>0 Then Begin Txt:=Copy(Txt0,1,P-1);Key:=Copy(Txt0,P+1,14);End Else Begin Txt:=Txt0;Key:='';End;
 If (Txt='') And (Id=0) Then Txt:='-';
 Inc(Ms^[Pop].N);
 Ms^[Pop].It[Ms^[Pop].N].Txt:=Copy(Txt,1,48);Ms^[Pop].It[Ms^[Pop].N].Cmd:=Id;Ms^[Pop].It[Ms^[Pop].N].Key:=Key;
 Ms^[Pop].It[Ms^[Pop].N].Flag:=0;
 If (Fl And 3)<>0 Then Ms^[Pop].It[Ms^[Pop].N].Flag:=1;
 If (Fl And 8)<>0 Then Ms^[Pop].It[Ms^[Pop].N].Flag:=Ms^[Pop].It[Ms^[Pop].N].Flag Or 2;
End;

Procedure MnuParse(Seg: Word; Ms: PMenuArr; Nm: PIntP);
Var P: Word; Guard: Integer;
 Procedure Level(Top: Boolean; Pop: Integer);
 Var F: Byte; Id: Word; S: String; B: Byte; NewPop: Integer;
 Begin
  Repeat
   F:=RdB(Lin(Seg,P));Inc(P);
   If (F And $10)<>0 Then Begin
    S:='';
    Repeat B:=RdB(Lin(Seg,P));Inc(P);If B<>0 Then S:=S+Chr(B);Until (B=0) Or (Length(S)>60);
    If Top Then Begin MnuAddPopup(Ms,Nm,S);Level(False,Nm^);End
    Else Begin MnuAddItem(Ms,Pop,S,0,1);Level(False,Pop);End;
   End Else Begin
    Id:=RdW(Lin(Seg,P));Inc(P,2);
    S:='';
    Repeat B:=RdB(Lin(Seg,P));Inc(P);If B<>0 Then S:=S+Chr(B);Until (B=0) Or (Length(S)>60);
    If Top Then Begin MnuAddPopup(Ms,Nm,S);MnuAddItem(Ms,Nm^,S,Id,F);End
    Else MnuAddItem(Ms,Pop,S,Id,F);
   End;
   Inc(Guard);
  Until ((F And $80)<>0) Or (Guard>400);
 End;
Begin
 P:=0;Guard:=0;Nm^:=0;
 Level(True,0);
End;

Function W16MenuLoadIdx(T: PW16; R: Integer): Word;
Var K: Integer; Sg_: Word; Fnd: Integer;
Begin
 W16MenuLoadIdx:=0;
 If R=0 Then Exit;
 Sg_:=W16LoadRes(T,R);
 If Sg_=0 Then Exit;
 Fnd:=0;
 For K:=1 To MAXW16MT Do If T^.MTpl[K]=Nil Then Begin Fnd:=K;Break;End;
 If Fnd=0 Then Exit;
 New(T^.MTpl[Fnd]);FillChar(T^.MTpl[Fnd]^,SizeOf(TW16MenuTpl),0);
 MnuParse(Sg_,@T^.MTpl[Fnd]^.Menus,@T^.MTpl[Fnd]^.NMenu);
 W16MenuLoadIdx:=$7C00+Fnd;
End;

Function W16MenuLoad(T: PW16; NameS,NameO: Word): Word;
Begin
 W16MenuLoad:=W16MenuLoadIdx(T,W16FindRes(T,NameS,NameO,0,4));
End;

Procedure W16ApplyMenu(T: PW16; Hw: Word; Tpl: Word);
Var W: PWindow; K,I: Integer;
Begin
 W:=W16HostOf(T,Hw);
 If (W=Nil) Or (Tpl<$7C00) Or (Tpl>=$7C00+MAXW16MT) Then Exit;
 K:=Tpl-$7C00;
 If T^.MTpl[K]=Nil Then Exit;
 W^.NMenu:=T^.MTpl[K]^.NMenu;
 For I:=1 To W^.NMenu Do W^.Menus[I]:=T^.MTpl[K]^.Menus[I];
 Dirty:=True;
End;

Procedure MnuFlagsById(Ms: PMenuArr; Nm: PIntP; Id: Integer; ByPos: Boolean; Pop: Integer; Bit: Byte; On: Boolean; Var Prev: Integer);
Var M,I: Integer;
Begin
 Prev:=-1;
 If ByPos Then Begin
  If (Pop>=1) And (Pop<=Nm^) And (Id>=0) And (Id<Ms^[Pop].N) Then Begin
   I:=Id+1;
   Prev:=Ms^[Pop].It[I].Flag;
   If On Then Ms^[Pop].It[I].Flag:=Ms^[Pop].It[I].Flag Or Bit Else Ms^[Pop].It[I].Flag:=Ms^[Pop].It[I].Flag And (255-Bit);
  End;
  Exit;
 End;
 For M:=1 To Nm^ Do
  For I:=1 To Ms^[M].N Do
   If (Ms^[M].It[I].Cmd=Id) And (Ms^[M].It[I].Txt<>'-') Then Begin
    Prev:=Ms^[M].It[I].Flag;
    If On Then Ms^[M].It[I].Flag:=Ms^[M].It[I].Flag Or Bit Else Ms^[M].It[I].Flag:=Ms^[M].It[I].Flag And (255-Bit);
   End;
End;

Procedure W16ChangeMenu(T: PW16; H: Word; Id: Integer; Ns,No: Word; NewId: Integer; Fl: Word);
Var Ms: PMenuArr; Nm: PIntP; Pop: Integer; Hw: Word; S: String; I,K: Integer; Sys: Boolean;
Begin
 Sys:=(H>=$7000) And (H<$7000+MAXW16W*32) And (((H-$7000) Mod 32)=31);
 If (Fl And $800)<>0 Then S:='-' Else If Ns<>0 Then S:=W16Str(T,Ns,No,60) Else S:='';
 If Sys Then Begin
  If ((Fl And $100)<>0) Or (Fl=0) Or ((Fl And $400)<>0) Then Begin
   If T^.NSys<MAXW16SYS Then Begin
    Inc(T^.NSys);T^.SysAdd[T^.NSys].Id:=NewId;T^.SysAdd[T^.NSys].Txt:=Copy(S,1,30);
    T^.SysAdd[T^.NSys].Sep:=(Fl And $800)<>0;T^.SysAdd[T^.NSys].Chk:=(Fl And 8)<>0;
   End;
  End Else If (Fl And $1200)<>0 Then Begin
   For I:=1 To T^.NSys Do If T^.SysAdd[I].Id=Id Then Begin
    For K:=I To T^.NSys-1 Do T^.SysAdd[K]:=T^.SysAdd[K+1];
    Dec(T^.NSys);Break;
   End;
  End Else If (Fl And $80)<>0 Then Begin
   For I:=1 To T^.NSys Do If T^.SysAdd[I].Id=Id Then Begin
    T^.SysAdd[I].Id:=NewId;T^.SysAdd[I].Txt:=Copy(S,1,30);T^.SysAdd[I].Chk:=(Fl And 8)<>0;End;
  End;
  Exit;
 End;
 If Not MenuSetOf(T,H,Ms,Nm,Pop,Hw) Then Exit;
 If Pop=0 Then Pop:=1;
 If Pop>Nm^ Then Exit;
 If (Fl And $200)<>0 Then Begin
  For I:=1 To Ms^[Pop].N Do If Ms^[Pop].It[I].Cmd=Id Then Begin
   For K:=I To Ms^[Pop].N-1 Do Ms^[Pop].It[K]:=Ms^[Pop].It[K+1];
   Dec(Ms^[Pop].N);Break;
  End;
 End Else If ((Fl And $10)<>0) And (NewId>=$7C00) And (NewId<$7C00+MAXW16MT) And (T^.MTpl[NewId-$7C00]<>Nil) And (H>=$7000) And (H<$7C00) Then Begin
  { sous-menu cree par CreateMenu : ajoute un menu deroulant a la barre }
  MnuAddPopup(Ms,Nm,S);
  For I:=1 To T^.MTpl[NewId-$7C00]^.Menus[1].N Do Begin
   Inc(Ms^[Nm^].N);Ms^[Nm^].It[Ms^[Nm^].N]:=T^.MTpl[NewId-$7C00]^.Menus[1].It[I];
  End;
 End
 Else If (Fl And $100)<>0 Then MnuAddItem(Ms,Pop,S,NewId,Fl)
 Else MnuAddItem(Ms,Pop,S,NewId,Fl);
 Dirty:=True;
End;

Procedure W16AddSysItems(W: PWindow);
Var T: PW16; Hw: Word; I: Integer;
Begin
 T:=W^.Data;
 If T=Nil Then Exit;
 For I:=1 To T^.NSys Do Begin
  If SysDef.N>=MAXITEM Then Break;
  Inc(SysDef.N);
  If T^.SysAdd[I].Sep Then Begin SysDef.It[SysDef.N].Txt:='-';SysDef.It[SysDef.N].Cmd:=0;SysDef.It[SysDef.N].Flag:=0;SysDef.It[SysDef.N].Key:='';End
  Else Begin
   SysDef.It[SysDef.N].Txt:=T^.SysAdd[I].Txt;SysDef.It[SysDef.N].Cmd:=K_W16SYS+I;
   SysDef.It[SysDef.N].Flag:=IfThen_(T^.SysAdd[I].Chk,2,0);SysDef.It[SysDef.N].Key:='';
  End;
 End;
End;

Procedure W16SysCommand(W: PWindow; Cmd: Integer);
Var T: PW16; Hw: Word; I: Integer;
Begin
 T:=W^.Data;
 If T=Nil Then Exit;
 Hw:=W^.Param;
 I:=Cmd-K_W16SYS;
 If (I>=1) And (I<=T^.NSys) Then W16Post(T,Hw,WM_SYSCOMMAND,T^.SysAdd[I].Id,0);
End;

{ ---------------- gestion des fenetres ---------------- }

Function W16Register(T: PW16; Seg,Ofs: Word): Word;
Var A: LongInt; I: Integer; Nm: String; Ns,No,Ms,Mo: Word;
Begin
 W16Register:=0;
 A:=Lin(Seg,Ofs);
 No:=RdW(A+$16);Ns:=RdW(A+$18);
 If Ns=0 Then Nm:='#'+IntStr(No) Else Nm:=W16Str(T,Ns,No,40);
 For I:=1 To MAXW16C Do If Not T^.Cl[I].Used Then Begin
  FillChar(T^.Cl[I],SizeOf(TW16Cls),0);
  T^.Cl[I].Used:=True;T^.Cl[I].Name:=Upper(Nm);
  T^.Cl[I].Style:=RdW(A);T^.Cl[I].POfs:=RdW(A+2);T^.Cl[I].PSeg:=RdW(A+4);
  T^.Cl[I].Brush:=RdW(A+$10);
  Mo:=RdW(A+$12);Ms:=RdW(A+$14);
  If Ms=0 Then T^.Cl[I].MenuId:=Mo Else Begin T^.Cl[I].MenuId:=0;T^.Cl[I].MenuName:=Upper(W16Str(T,Ms,Mo,24));End;
  If (Ms=0) And (Mo=0) Then Begin T^.Cl[I].MenuId:=0;T^.Cl[I].MenuName:='';End;
  W16Register:=$C000+I;Exit;
 End;
End;

Function W16FindClass(T: PW16; Const Nm: String): Integer;
Var I: Integer;
Begin
 W16FindClass:=0;
 For I:=1 To MAXW16C Do If T^.Cl[I].Used And (T^.Cl[I].Name=Upper(Nm)) Then W16FindClass:=I;
End;

Function W16EditProc(T: PW16; Hw,Msg,Wp: Word; Lp: LongInt): LongInt; Forward;

Procedure W16RegBuiltins(T: PW16);
Const Nm: Array[1..6] Of String[10]=('EDIT','BUTTON','STATIC','LISTBOX','SCROLLBAR','COMBOBOX');
Var I: Integer;
Begin
 For I:=1 To 6 Do Begin
  FillChar(T^.Cl[MAXW16C-I+1],SizeOf(TW16Cls),0);
  T^.Cl[MAXW16C-I+1].Used:=True;T^.Cl[MAXW16C-I+1].Name:=Nm[I];T^.Cl[MAXW16C-I+1].Builtin:=True;
  T^.Cl[MAXW16C-I+1].PSeg:=ROMSEG;T^.Cl[MAXW16C-I+1].POfs:=$400+HDL_EDITPROC;
 End;
End;

Procedure W16DestroyWin(T: PW16; Hw: Word); Forward;

Function W16CreateWin(T: PW16; Const Cls,Title: String; Style: LongInt; X,Y,Wd,Ht: Integer;
   Parent,Menu: Word; Inst: Word; PrmS,PrmO: Word): Word;
Var I,C,R,K: Integer; Hw: Word; W: PWindow; Sz: Boolean; A: LongInt; Child: Boolean; Mt: Word; Tpl: Word;
Begin
 W16CreateWin:=0;
 C:=W16FindClass(T,Cls);
 If C=0 Then Begin W16Fail(T,'Unregistered window class: '+Cls);Exit;End;
 Hw:=0;
 For I:=1 To MAXW16W Do If Not T^.Wn[I].Used Then Begin Hw:=I;Break;End;
 If Hw=0 Then Exit;
 FillChar(T^.Wn[Hw],SizeOf(TW16Win),0);
 Child:=((Style And $40000000)<>0) And (Parent<>0);
 T^.Wn[Hw].Used:=True;T^.Wn[Hw].Cls:=C;T^.Wn[Hw].Parent:=IfThen_(Child,Parent,0);
 T^.Wn[Hw].PSeg:=T^.Cl[C].PSeg;T^.Wn[Hw].POfs:=T^.Cl[C].POfs;
 T^.Wn[Hw].Style:=Style;T^.Wn[Hw].Title:=Copy(Title,1,64);T^.Wn[Hw].Enabled:=True;T^.Wn[Hw].Vis:=True;
 T^.Wn[Hw].Id:=IfThen_(Child,Menu,0);
 T^.Wn[Hw].X:=X;T^.Wn[Hw].Y:=Y;T^.Wn[Hw].W:=Wd;T^.Wn[Hw].H:=Ht;
 T^.Wn[Hw].VMax:=100;T^.Wn[Hw].HMax:=100;
 If Child Then Begin
  If T^.Cl[C].Name='EDIT' Then Begin
   T^.Wn[Hw].Kind:=WK_EDIT;T^.Wn[Hw].Ed:=EdNew(False);T^.Wn[Hw].Ed^.Max:=30000;
   T^.Wn[Hw].Ed^.Wrap:=(Style And $0004)<>0;
   EdSetText(T^.Wn[Hw].Ed,Title);
  End Else If T^.Cl[C].Name='STATIC' Then T^.Wn[Hw].Kind:=WK_STATIC
  Else If T^.Cl[C].Name='BUTTON' Then T^.Wn[Hw].Kind:=WK_BUTTON
  Else If T^.Cl[C].Name='SCROLLBAR' Then Begin T^.Wn[Hw].Kind:=WK_SCROLL;T^.Wn[Hw].VMin:=0;T^.Wn[Hw].VMax:=0;End
  Else T^.Wn[Hw].Kind:=WK_OTHER;
 End Else Begin
  If (X=-32768) Then X:=-1;
  If (Wd<=0) Then Wd:=560;
  If (Ht<=0) Then Ht:=380;
  If Wd<120 Then Wd:=120;If Ht<80 Then Ht:=80;
  Sz:=(Style And $00040000)<>0;
  W:=NewWindow(A_W16,Title,X,Y,Wd,Ht,Sz);
  If W=Nil Then Begin T^.Wn[Hw].Used:=False;Exit;End;
  W^.Data:=T;W^.Param:=Hw;
  W^.HasVS:=(Style And $00200000)<>0;W^.HasHS:=(Style And $00100000)<>0;
  T^.Wn[Hw].Host:=W;T^.Wn[Hw].Kind:=WK_TOP;
  T^.Wn[Hw].X:=W^.X;T^.Wn[Hw].Y:=W^.Y;T^.Wn[Hw].W:=W^.W;T^.Wn[Hw].H:=W^.H;
  { menu : parametre, puis menu de la classe }
  Tpl:=0;
  If (Menu>=$7C00) And (Menu<$7C00+MAXW16MT) Then Tpl:=Menu
  Else If T^.Cl[C].MenuId<>0 Then Tpl:=W16MenuLoad(T,0,T^.Cl[C].MenuId)
  Else If T^.Cl[C].MenuName<>'' Then Begin
   For K:=1 To T^.NRs Do If (T^.Rs[K].Typ=$8004) And (Upper(T^.Rs[K].Name)=T^.Cl[C].MenuName) Then Begin
    Tpl:=W16MenuLoadIdx(T,K);Break;
   End;
  End;
  If Tpl<>0 Then W16ApplyMenu(T,Hw,Tpl);
  BringToFront(W);
 End;
 { structure CREATESTRUCT }
 A:=Lin(T^.CsSeg,T^.CsOfs);
 WrW(A,PrmO);WrW(A+2,PrmS);WrW(A+4,Inst);WrW(A+6,Menu);WrW(A+8,Parent);
 WrW(A+10,Ht);WrW(A+12,Wd);WrW(A+14,Y);WrW(A+16,X);WrW(A+18,Style And $FFFF);WrW(A+20,(Style Shr 16) And $FFFF);
 W16CreateWin:=Hw;
End;

Procedure W16DestroyWin(T: PW16; Hw: Word);
Var W: PWindow; I: Integer;
Begin
 If (Hw<1) Or (Hw>MAXW16W) Or Not T^.Wn[Hw].Used Then Exit;
 If T^.Wn[Hw].Destroyed Then Exit;
 T^.Wn[Hw].Destroyed:=True;
 For I:=1 To MAXW16W Do If T^.Wn[I].Used And (T^.Wn[I].Parent=Hw) Then W16DestroyWin(T,I);
 W16WndProc(T,Hw,WM_DESTROY,0,0);
 T^.Wn[Hw].Used:=False;
 If T^.Wn[Hw].Ed<>Nil Then Begin EdFree(T^.Wn[Hw].Ed);T^.Wn[Hw].Ed:=Nil;End;
 W:=T^.Wn[Hw].Host;
 If W<>Nil Then Begin W^.Data:=Nil;RemoveWindow(W);End;
 For I:=1 To MAXW16T Do If T^.Tm[I].Used And (T^.Tm[I].Hw=Hw) Then T^.Tm[I].Used:=False;
 If T^.Focus=Hw Then T^.Focus:=0;
 Dirty:=True;
End;

Procedure W16Terminate(T: PW16);
Var I: Integer;
Begin
 For I:=1 To MAXW16W Do If T^.Wn[I].Used Then Begin
  T^.Wn[I].Used:=False;
  If T^.Wn[I].Ed<>Nil Then Begin EdFree(T^.Wn[I].Ed);T^.Wn[I].Ed:=Nil;End;
  If T^.Wn[I].Host<>Nil Then Begin T^.Wn[I].Host^.Data:=Nil;RemoveWindow(T^.Wn[I].Host);End;
 End;
 For I:=1 To MAXW16O Do If T^.Ob[I].Used Then W16ObjFree(T,$100+I);
 For I:=1 To MAXW16MT Do If T^.MTpl[I]<>Nil Then Begin Dispose(T^.MTpl[I]);T^.MTpl[I]:=Nil;End;
End;

{ ---------------- contrôle EDIT ---------------- }

Procedure EditNotify(T: PW16; Hw: Word; Code: Word);
Begin
 If T^.Wn[Hw].Parent<>0 Then
  W16Post(T,T^.Wn[Hw].Parent,WM_COMMAND,T^.Wn[Hw].Id,LongInt(Hw) Or (LongInt(Code) Shl 16));
End;

Function W16EditProc(T: PW16; Hw,Msg,Wp: Word; Lp: LongInt): LongInt;
Var E: PEd; S: String; I,A,B,N: Integer; Sg_,Of_: Word; Ch: Word;
Begin
 W16EditProc:=0;
 If (Hw<1) Or (Hw>MAXW16W) Or (T^.Wn[Hw].Ed=Nil) Then Exit;
 E:=T^.Wn[Hw].Ed;
 Sg_:=(Lp Shr 16) And $FFFF;Of_:=Lp And $FFFF;
 Case Msg Of
  WM_SETTEXT: Begin S:=W16Str(T,Sg_,Of_,250);EdSetText(E,S);E^.Modified:=False;Dirty:=True;EditNotify(T,Hw,$300);End;
  WM_GETTEXT: Begin
     N:=Min2(E^.Len,Wp-1);If N<0 Then N:=0;
     For I:=0 To N-1 Do WrB(Lin(Sg_,Of_+I),E^.Buf^[I]);
     If Wp>0 Then WrB(Lin(Sg_,Of_+N),0);
     W16EditProc:=N;
    End;
  WM_GETTEXTLENGTH: W16EditProc:=E^.Len;
  WM_CHAR: Begin
     Ch:=Wp And $FF;
     If Ch=8 Then Begin EdPushUndo(E);If EdKey(E,K_BKSP) Then EditNotify(T,Hw,$300);End
     Else If Ch=13 Then Begin If (T^.Wn[Hw].Style And 4)<>0 Then Begin EdPushUndo(E);EdKey(E,K_ENTER);EditNotify(T,Hw,$300);End;End
     Else If (Ch>=32) And (T^.Wn[Hw].Id<>0) Or (Ch>=32) Then Begin
      If E^.Len<E^.Max Then Begin EdPushUndo(E);EdKey(E,Ch);EditNotify(T,Hw,$300);End;
     End;
     Dirty:=True;
    End;
  WM_KEYDOWN: Begin
     Case Wp Of
      $25: EdKey(E,K_LEFT); $27: EdKey(E,K_RIGHT); $26: EdKey(E,K_UP); $28: EdKey(E,K_DOWN);
      $24: EdKey(E,K_HOME); $23: EdKey(E,K_END); $21: EdKey(E,K_PGUP); $22: EdKey(E,K_PGDN);
      $2E: Begin EdKey(E,K_DEL);EditNotify(T,Hw,$300);End;
     End;
     Dirty:=True;
    End;
  WM_LBUTTONDOWN: Begin
     E^.Cur:=EdHit(E,0,E^.X0+SmallInt(Lp And $FFFF),E^.Y0+SmallInt((Lp Shr 16) And $FFFF));
     E^.Anc:=E^.Cur;T^.Focus:=Hw;Dirty:=True;
    End;
  WM_MOUSEMOVE: If (Wp And 1)<>0 Then Begin
     E^.Cur:=EdHit(E,0,E^.X0+SmallInt(Lp And $FFFF),E^.Y0+SmallInt((Lp Shr 16) And $FFFF));
     If E^.Anc=E^.Cur Then Begin End;
     Dirty:=True;
    End;
  WM_SETFOCUS: T^.Focus:=Hw;
  WM_CUT: Begin EdCut(E);EditNotify(T,Hw,$300);Dirty:=True;End;
  WM_COPY: EdCopy(E);
  WM_PASTE: Begin EdPaste(E);EditNotify(T,Hw,$300);Dirty:=True;End;
  WM_CLEAR: Begin If EdHasSel(E) Then Begin EdSelRange(E,A,B);EdPushUndo(E);EdDeleteRange(E,A,B);EdLayout(E);EditNotify(T,Hw,$300);End;Dirty:=True;End;
  WM_UNDO,$417: Begin EdUndo(E);Dirty:=True;End;
  $400: Begin EdSelRange(E,A,B);W16EditProc:=LongInt(A And $FFFF) Or (LongInt(B And $FFFF) Shl 16);End;
  $401: Begin
     A:=Lp And $FFFF;B:=(Lp Shr 16) And $FFFF;
     If B>E^.Len Then B:=E^.Len;If A>B Then A:=B;
     E^.Anc:=A;E^.Cur:=B;If A=B Then E^.Anc:=-1;
     Dirty:=True;
    End;
  $408: W16EditProc:=Ord(E^.Modified);
  $409: E^.Modified:=Wp<>0;
  $40A: W16EditProc:=E^.NV;
  $412: Begin
     S:=W16Str(T,Sg_,Of_,250);
     EdPushUndo(E);
     For I:=1 To Length(S) Do EdInsertChar(E,Ord(S[I]));
     EdLayout(E);EditNotify(T,Hw,$300);Dirty:=True;
    End;
  $415: If Wp<>0 Then E^.Max:=Min2(Wp,30000) Else E^.Max:=30000;
 End;
 EdLayout(E);
End;

{ envoi d'un message a une fenetre (controles integres ou procedure de l'application) }
Function W16Send(T: PW16; Hw,Msg,Wp: Word; Lp: LongInt): LongInt;
Begin
 W16Send:=0;
 If (Hw<1) Or (Hw>MAXW16W) Or Not T^.Wn[Hw].Used Then Exit;
 If (T^.Wn[Hw].PSeg=ROMSEG) Then Begin
  If T^.Wn[Hw].Kind=WK_EDIT Then W16Send:=W16EditProc(T,Hw,Msg,Wp,Lp);
  Exit;
 End;
 W16Send:=W16WndProc(T,Hw,Msg,Wp,Lp);
End;

Function W16DefProc(T: PW16; Hw,Msg,Wp: Word; Lp: LongInt): LongInt;
Begin
 W16DefProc:=0;
 Case Msg Of
  WM_CLOSE: W16DestroyWin(T,Hw);
  WM_ERASEBKGND: W16DefProc:=1;
  $0081: W16DefProc:=1;
  WM_SETTEXT: If (Hw>=1) And (Hw<=MAXW16W) And T^.Wn[Hw].Used Then Begin
     T^.Wn[Hw].Title:=Copy(W16Str(T,(Lp Shr 16) And $FFFF,Lp And $FFFF,64),1,64);
     If T^.Wn[Hw].Host<>Nil Then T^.Wn[Hw].Host^.Title:=T^.Wn[Hw].Title;
     Dirty:=True;
    End;
  WM_GETTEXT: If (Hw>=1) And (Hw<=MAXW16W) Then Begin
     W16PutStr((Lp Shr 16) And $FFFF,Lp And $FFFF,T^.Wn[Hw].Title,Wp);
     W16DefProc:=Min2(Length(T^.Wn[Hw].Title),Wp-1);
    End;
  WM_GETTEXTLENGTH: If (Hw>=1) And (Hw<=MAXW16W) Then W16DefProc:=Length(T^.Wn[Hw].Title);
 End;
End;

{ ---------------- boites de dialogue (gabarits de ressources) ---------------- }

Type
 PDlgRt = ^TDlgRt;
 TDlgRt = Record
  T : PW16;
  HwDlg : Word;
  D : TDlg;
  Ended,Redraw : Boolean;
  Res : Integer;
  Lists : Array[1..MAXCTL] Of PStrList;
  Caption : String[40];
  DirSpec : String[40];
 End;

Var CurDlg: PDlgRt;

Function W16BuildDlg(T: PW16; R: Integer; Rt: PDlgRt): Boolean;
Var Sg_,P: Word; Cdit,I: Integer; X,Y,Cx,Cy,Id: Integer; St: LongInt; Cl: Byte; Txt: String; B: Byte;
    Ix: Integer; Ex: Byte; Grp: Integer; W,H: Integer; Cap: String; Fl: Word;
 Function SzAt(Var Pp: Word): String;
 Var Q: String; Bb: Byte;
 Begin
  Q:='';
  Repeat Bb:=RdB(Lin(Sg_,Pp));Inc(Pp);If Bb<>0 Then Q:=Q+Chr(Bb);Until (Bb=0) Or (Length(Q)>150);
  SzAt:=Q;
 End;
Begin
 W16BuildDlg:=False;
 Sg_:=W16LoadRes(T,R);
 If Sg_=0 Then Exit;
 Cdit:=RdB(Lin(Sg_,4));
 Cx:=RdW(Lin(Sg_,9));Cy:=RdW(Lin(Sg_,11));
 P:=13;
 B:=RdB(Lin(Sg_,P));
 If B=$FF Then Inc(P,3) Else SzAt(P);
 SzAt(P);
 Cap:=SzAt(P);
 Rt^.Caption:=Copy(Cap,1,40);
 W:=Cx*2+12;H:=Cy*2+12;
 DlgInit(Rt^.D,'',W,H);
 Grp:=0;
 For I:=1 To Cdit Do Begin
  X:=RdW(Lin(Sg_,P));Y:=RdW(Lin(Sg_,P+2));Cx:=RdW(Lin(Sg_,P+4));Cy:=RdW(Lin(Sg_,P+6));
  Id:=RdW(Lin(Sg_,P+8));St:=LongInt(RdW(Lin(Sg_,P+10)))+(LongInt(RdW(Lin(Sg_,P+12))) Shl 16);
  Inc(P,14);
  Cl:=RdB(Lin(Sg_,P));
  If Cl>=$80 Then Inc(P) Else SzAt(P);
  If RdB(Lin(Sg_,P))=$FF Then Begin Txt:='#'+IntStr(RdW(Lin(Sg_,P+1)));Inc(P,3);End Else Txt:=SzAt(P);
  Ex:=RdB(Lin(Sg_,P));Inc(P,1+Ex);
  Fl:=St And $FFFF;
  X:=X*2+6;Y:=Y*2+6;Cx:=Cx*2;Cy:=Cy*2;
  Ix:=0;
  Case Cl Of
   $82: Begin
     Case Fl And 15 Of
      0,1,2: Begin
        Ix:=DlgAdd(Rt^.D,C_TEXT,Id,X,Y+(Cy-8) Div 2,Cx,Cy,Txt);Rt^.D.C[Ix].Grp:=Fl And 3;
        If (Fl And 15)=3 Then ;
       End;
      3: Begin
        Ix:=DlgAdd(Rt^.D,C_ICON,Id,X,Y,32,32,'');
        Rt^.D.C[Ix].Val:=-1;
        If (Length(Txt)>1) And (Txt[1]='#') Then Begin
         If W16FindResById(T,3,StrVal(Copy(Txt,2,6),0))>0 Then Rt^.D.C[Ix].Val:=W16LoadRes(T,W16FindResById(T,3,StrVal(Copy(Txt,2,6),0)));
        End Else Begin
         For B:=1 To T^.NRs Do If (T^.Rs[B].Typ=$8003) And (T^.Rs[B].Name=Upper(Txt)) And (Txt<>'') Then Rt^.D.C[Ix].Val:=W16LoadRes(T,B);
        End;
        If Rt^.D.C[Ix].Val<1000 Then Rt^.D.C[Ix].Val:=4;
       End;
      4,5,7,8: Begin Ix:=DlgAdd(Rt^.D,C_BAR,Id,X,Y,Cx,Max2(2,Cy),'');End;
     Else Ix:=DlgAdd(Rt^.D,C_TEXT,Id,X,Y,Cx,Cy,Txt);
     End;
    End;
   $80: Begin
     Case Fl And 15 Of
      0,1: Begin
        Ix:=DlgAdd(Rt^.D,C_BUTTON,Id,X,Y,Cx,Cy,Txt);
        If (Fl And 15)=1 Then Begin Rt^.D.Def:=Ix;If Rt^.D.Focus=0 Then Rt^.D.Focus:=Ix;End;
       End;
      2,3,5: Ix:=DlgAdd(Rt^.D,C_CHECK,Id,X,Y+2,Cx,Cy,Txt);
      4,9: Begin
        If (St And $20000)<>0 Then Inc(Grp);
        Ix:=DlgAdd(Rt^.D,C_RADIO,Id,X,Y+2,Cx,Cy,Txt);Rt^.D.C[Ix].Grp:=Grp+1;
       End;
      7: Ix:=DlgAdd(Rt^.D,C_BOX,Id,X,Y,Cx,Cy,Txt);
     Else Ix:=DlgAdd(Rt^.D,C_BUTTON,Id,X,Y,Cx,Cy,Txt);
     End;
    End;
   $81: Begin Ix:=DlgAdd(Rt^.D,C_EDIT,Id,X,Y,Cx,16,Txt);Rt^.D.C[Ix].Grp:=250;Rt^.D.C[Ix].Val:=Length(Txt);End;
   $83: Begin
     Ix:=DlgAdd(Rt^.D,C_LIST,Id,X,Y,Cx,Cy,'');
     New(Rt^.Lists[Ix]);Rt^.Lists[Ix]^.N:=0;Rt^.D.C[Ix].Lst:=Rt^.Lists[Ix];Rt^.D.C[Ix].Val:=0;
    End;
  Else Ix:=0;
  End;
 End;
 If (Rt^.D.Focus=0) Then Begin
  For I:=1 To Rt^.D.N Do If Focusable(Rt^.D,I) Then Begin Rt^.D.Focus:=I;Break;End;
 End;
 W16BuildDlg:=True;
End;

Function DlgCtlIdx(Rt: PDlgRt; Id: Integer): Integer;
Var I: Integer;
Begin
 DlgCtlIdx:=0;
 For I:=1 To Rt^.D.N Do If Rt^.D.C[I].Id=Id Then Begin DlgCtlIdx:=I;Exit;End;
End;

Function W16CtlMsg(T: PW16; Rt: PDlgRt; I: Integer; Msg,Wp: Word; Lp: LongInt): LongInt;
Var S: String; N,K: Integer; Sg_,Of_: Word; L: PStrList; A,B: Integer;
Begin
 W16CtlMsg:=0;
 If (I<1) Or (I>Rt^.D.N) Then Exit;
 Sg_:=(Lp Shr 16) And $FFFF;Of_:=Lp And $FFFF;
 Rt^.Redraw:=True;
 Case Rt^.D.C[I].Kind Of
  C_EDIT: Case Msg Of
     WM_SETTEXT: Begin DlgSetText(Rt^.D,Rt^.D.C[I].Id,W16Str(T,Sg_,Of_,250));Rt^.D.Sel1:=0;End;
     WM_GETTEXT: Begin W16PutStr(Sg_,Of_,Rt^.D.C[I].Txt,Wp);W16CtlMsg:=Min2(Length(Rt^.D.C[I].Txt),Wp-1);End;
     WM_GETTEXTLENGTH: W16CtlMsg:=Length(Rt^.D.C[I].Txt);
     $415: Rt^.D.C[I].Grp:=IfThen_(Wp=0,250,Wp);
     $401: Begin
        A:=Lp And $FFFF;B:=(Lp Shr 16) And $FFFF;
        If (A=0) And (B>=Length(Rt^.D.C[I].Txt)) Then Begin Rt^.D.Focus:=I;Rt^.D.Sel1:=1;End
        Else Rt^.D.C[I].Val:=Clamp(B,0,Length(Rt^.D.C[I].Txt));
       End;
    End;
  C_LIST: Begin
     L:=Rt^.D.C[I].Lst;
     If L<>Nil Then Case Msg Of
      $401: If L^.N<400 Then Begin Inc(L^.N);L^.S[L^.N]:=W16Str(T,Sg_,Of_,44);W16CtlMsg:=L^.N-1;End;
      $402: If L^.N<400 Then Begin
         A:=Wp+1;If (Wp=$FFFF) Or (A>L^.N+1) Then A:=L^.N+1;
         For K:=L^.N DownTo A Do L^.S[K+1]:=L^.S[K];
         L^.S[A]:=W16Str(T,Sg_,Of_,44);Inc(L^.N);W16CtlMsg:=A-1;
        End;
      $403: If (Wp<L^.N) Then Begin
         For K:=Wp+1 To L^.N-1 Do L^.S[K]:=L^.S[K+1];Dec(L^.N);W16CtlMsg:=L^.N;End;
      $405: Begin L^.N:=0;Rt^.D.C[I].Val:=0;Rt^.D.C[I].Top:=0;End;
      $407: Begin If SmallInt(Wp)<0 Then Rt^.D.C[I].Val:=0 Else Rt^.D.C[I].Val:=Wp+1;ListEnsure(Rt^.D,I);End;
      $409: W16CtlMsg:=LongInt(Rt^.D.C[I].Val)-1;
      $40A: If Wp<L^.N Then Begin W16PutStr(Sg_,Of_,L^.S[Wp+1],255);W16CtlMsg:=Length(L^.S[Wp+1]);End;
      $40B: If Wp<L^.N Then W16CtlMsg:=Length(L^.S[Wp+1]);
      $40C: W16CtlMsg:=L^.N;
      $40D,$410: Begin
         S:=Upper(W16Str(T,Sg_,Of_,44));W16CtlMsg:=-1;
         For K:=1 To L^.N Do If Copy(Upper(L^.S[K]),1,Length(S))=S Then Begin
          W16CtlMsg:=K-1;If Msg=$40D Then Begin Rt^.D.C[I].Val:=K;ListEnsure(Rt^.D,I);End;Break;End;
        End;
     End;
    End;
  C_CHECK,C_RADIO,C_BUTTON: Case Msg Of
     $400: W16CtlMsg:=Rt^.D.C[I].Val;
     $401: Begin If Rt^.D.C[I].Kind=C_RADIO Then Begin If Wp<>0 Then SelectRadio(Rt^.D,I) Else Rt^.D.C[I].Val:=0;End
            Else Rt^.D.C[I].Val:=IfThen_(Wp<>0,1,0);End;
    End;
  C_TEXT: If Msg=WM_SETTEXT Then Rt^.D.C[I].Txt:=W16Str(T,Sg_,Of_,150);
 End;
End;

Function W16DlgHook(Var D: TDlg; Ev,Ct: Integer): Boolean;
Var Rt: PDlgRt; T: PW16; Id: Integer; Lp: LongInt; R: LongInt;
Begin
 W16DlgHook:=False;
 Rt:=CurDlg;
 If Rt=Nil Then Exit;
 T:=Rt^.T;AT:=T;
 Case Ev Of
  DE_INIT: Begin
    If Ct=0 Then Begin
     R:=W16WndProc(T,Rt^.HwDlg,WM_INITDIALOG,$8000+Max2(1,D.Focus),0);
     AT:=T;
     If Rt^.Ended Then DlgForceClose:=True;
    End Else Begin
     If Rt^.Ended Then DlgForceClose:=True;
     W16DlgHook:=Rt^.Redraw;Rt^.Redraw:=False;
    End;
   End;
  DE_BUTTON: Begin
    Id:=D.C[Ct].Id;
    W16WndProc(T,Rt^.HwDlg,WM_COMMAND,Id,LongInt($8000+Ct));AT:=T;
    W16DlgHook:=Not Rt^.Ended;
    If Rt^.Ended Then DlgForceClose:=True;
    W16DlgHook:=True;
   End;
  DE_CHANGE: Begin
    Id:=D.C[Ct].Id;
    Case D.C[Ct].Kind Of
     C_RADIO,C_CHECK: W16WndProc(T,Rt^.HwDlg,WM_COMMAND,Id,LongInt($8000+Ct));
     C_LIST: W16WndProc(T,Rt^.HwDlg,WM_COMMAND,Id,LongInt($8000+Ct) Or (LongInt(1) Shl 16));
    End;
    AT:=T;
    If Rt^.Ended Then DlgForceClose:=True;
   End;
  DE_DBL: Begin
    W16WndProc(T,Rt^.HwDlg,WM_COMMAND,D.C[Ct].Id,LongInt($8000+Ct) Or (LongInt(2) Shl 16));AT:=T;
    If Rt^.Ended Then DlgForceClose:=True;
    W16DlgHook:=True;
   End;
 End;
End;

Function W16DlgSlot(T: PW16; Rt: PDlgRt; PS,PO: Word): Word;
Var I: Integer;
Begin
 W16DlgSlot:=0;
 For I:=1 To MAXW16W Do If Not T^.Wn[I].Used Then Begin
  FillChar(T^.Wn[I],SizeOf(TW16Win),0);
  T^.Wn[I].Used:=True;T^.Wn[I].Kind:=WK_DLG;T^.Wn[I].PSeg:=PS;T^.Wn[I].POfs:=PO;T^.Wn[I].Dlg:=Rt;
  T^.Wn[I].Enabled:=True;T^.Wn[I].Vis:=True;
  W16DlgSlot:=I;Exit;
 End;
End;

Function W16DialogBox(T: PW16; R: Integer; PS,PO: Word): Integer;
Var Rt,Old: PDlgRt; Hw: Word; I: Integer;
Begin
 W16DialogBox:=-1;
 New(Rt);FillChar(Rt^,SizeOf(TDlgRt),0);Rt^.T:=T;
 If Not W16BuildDlg(T,R,Rt) Then Begin Dispose(Rt);Exit;End;
 Hw:=W16DlgSlot(T,Rt,PS,PO);
 If Hw=0 Then Begin Dispose(Rt);Exit;End;
 Rt^.HwDlg:=Hw;
 Old:=CurDlg;CurDlg:=Rt;
 DlgForceClose:=False;
 RunDialog(Rt^.D,@W16DlgHook);
 DlgForceClose:=False;
 AT:=T;
 CurDlg:=Old;
 For I:=1 To MAXCTL Do If Rt^.Lists[I]<>Nil Then Dispose(Rt^.Lists[I]);
 T^.Wn[Hw].Used:=False;
 W16DialogBox:=Rt^.Res;
 Dispose(Rt);
 Dirty:=True;
End;

Function DlgOf(T: PW16; Hd: Word; Var Rt: PDlgRt): Boolean;
Begin
 DlgOf:=False;
 If (Hd>=1) And (Hd<=MAXW16W) And T^.Wn[Hd].Used And (T^.Wn[Hd].Kind=WK_DLG) And (T^.Wn[Hd].Dlg<>Nil) Then Begin
  Rt:=PDlgRt(T^.Wn[Hd].Dlg);DlgOf:=True;
 End;
End;

{ modeless : fenetre hote }
Function W16CreateDialog(T: PW16; R: Integer; PS,PO: Word): Word;
Var Rt: PDlgRt; Hw: Word; W: PWindow;
Begin
 W16CreateDialog:=0;
 New(Rt);FillChar(Rt^,SizeOf(TDlgRt),0);Rt^.T:=T;
 If Not W16BuildDlg(T,R,Rt) Then Begin Dispose(Rt);Exit;End;
 Hw:=W16DlgSlot(T,Rt,PS,PO);
 If Hw=0 Then Begin Dispose(Rt);Exit;End;
 Rt^.HwDlg:=Hw;
 W:=NewWindow(A_W16,Rt^.Caption,-1,-1,Rt^.D.W+2*(Bdr)+2,Rt^.D.H+2*Bdr+TITLE_H,False);
 If W=Nil Then Begin T^.Wn[Hw].Used:=False;Dispose(Rt);Exit;End;
 W^.Data:=T;W^.Param:=Hw;T^.Wn[Hw].Host:=W;
 BringToFront(W);
 CurDlg:=Rt;
 W16WndProc(T,Hw,WM_INITDIALOG,0,0);
 AT:=T;
 W16CreateDialog:=Hw;
End;

Function W16DlgEnd(T: PW16; Hd: Word; Res: Integer): Boolean;
Var Rt: PDlgRt;
Begin
 W16DlgEnd:=False;
 If Not DlgOf(T,Hd,Rt) Then Exit;
 Rt^.Ended:=True;Rt^.Res:=Res;
 If CurDlg=Rt Then DlgForceClose:=True;
 If T^.Wn[Hd].Host<>Nil Then Begin
  T^.Wn[Hd].Host^.Data:=Nil;RemoveWindow(T^.Wn[Hd].Host);T^.Wn[Hd].Host:=Nil;T^.Wn[Hd].Used:=False;
  Dispose(Rt);
 End;
 W16DlgEnd:=True;
End;

{ liste de fichiers pour DlgDirList (retourne le nom court du motif) }
Procedure W16DirList(T: PW16; Rt: PDlgRt; PS,PO: Word; IdList,IdStat,WType: Word);
Var Sp,Dir,Pat: String; P,I,K: Integer; L: PStrList; Ix: Integer; Dd: String;
Begin
 Sp:=Upper(W16Str(T,PS,PO,60));
 Dir:=CV^.CurDir;Pat:='*.*';
 If Sp<>'' Then Begin
  P:=Length(Sp);While (P>0) And (Sp[P]<>'\') And (Sp[P]<>':') Do Dec(P);
  If P>0 Then Begin
   Dd:=Copy(Sp,1,P);Pat:=Copy(Sp,P+1,20);
   If Dd[Length(Dd)]='\' Then Delete(Dd,Length(Dd),1);
   If Dd='' Then Dd:='\';
   If VDirExists(DosPath(CV,Dd)) Then Dir:=DosPath(CV,Dd);
   CV^.CurDir:=Dir;
  End Else Pat:=Sp;
 End;
 If Pat='' Then Pat:='*.*';
 Ix:=DlgCtlIdx(Rt,IdList);
 If Ix>0 Then Begin
  L:=Rt^.D.C[Ix].Lst;
  If L<>Nil Then Begin
   ListDirTo(L,Dir,Pat,(WType And $10)<>0);
   If ((WType And $4000)<>0) And (L^.N<400) Then Begin Inc(L^.N);L^.S[L^.N]:='[-C-]';End;
   Rt^.D.C[Ix].Val:=0;Rt^.D.C[Ix].Top:=0;
  End;
 End;
 Ix:=DlgCtlIdx(Rt,IdStat);
 If (Ix>0) And (IdStat<>0) Then Rt^.D.C[Ix].Txt:=Copy(Dir,1,78);
 If Sp<>'' Then W16PutStr(PS,PO,Pat,20);
 Rt^.Redraw:=True;
End;

{ ---------------- accelerateurs ---------------- }

Function W16Accel(T: PW16; Hw,Hacc: Word; MS,MO: Word): Word;
Var P: Word; F: Byte; K,Cmd: Word; Msg,Wp: Word; Mods: Word; Ok: Boolean; Ch: Word; Last: Boolean;
Begin
 W16Accel:=0;
 If Hacc=0 Then Exit;
 Msg:=RdW(Lin(MS,MO+2));Wp:=RdW(Lin(MS,MO+4));Mods:=RdW(Lin(MS,MO+16));
 If (Msg<>WM_KEYDOWN) And (Msg<>WM_CHAR) Then Exit;
 P:=0;
 Repeat
  F:=RdB(Lin(Hacc,P));K:=RdW(Lin(Hacc,P+1));Cmd:=RdW(Lin(Hacc,P+3));Inc(P,5);
  Last:=(F And $80)<>0;
  If (F And 1)<>0 Then Begin
   If Msg=WM_KEYDOWN Then Begin
    Ok:=K=Wp;
    If Ok Then Begin
     If ((F And 8)<>0)<>((Mods And 2)<>0) Then Ok:=False;
     If ((F And 4)<>0)<>((Mods And 1)<>0) Then Ok:=False;
    End;
    If Ok Then Begin W16Post(T,Hw,WM_COMMAND,Cmd,0);W16Accel:=1;Exit;End;
   End;
  End Else If Msg=WM_CHAR Then Begin
   If K=Wp Then Begin W16Post(T,Hw,WM_COMMAND,Cmd,0);W16Accel:=1;Exit;End;
  End;
 Until Last Or (P>400);
End;

{ ---------------- fichiers (KERNEL) ---------------- }

Procedure W16SelectDos(T: PW16);
Begin
 CV:=T^.V;
End;

Function W16OpenF(T: PW16; Const Nm: String; Mode: Byte; Create: Boolean): Integer;
Var H: Integer; Err: Word; P: String;
Begin
 W16SelectDos(T);
 P:=DosPath(CV,Nm);
 Err:=DosOpenFile(P,Mode,Create,H);
 If Err<>0 Then W16OpenF:=-1 Else W16OpenF:=H;
End;

{ ---------------- API : KERNEL ---------------- }

Procedure W16Trap(T: PW16; Module,Ord_: Integer);
Var Nm: String;
Begin
 Case Module Of 1: Nm:='KERNEL';2: Nm:='GDI';3: Nm:='USER';4: Nm:='KEYBOARD';Else Nm:='?';End;
 W16Fail(T,'Unsupported API '+Nm+'.'+IntStr(Ord_));
End;

Procedure W16Kernel(T: PW16; O: Integer);
Var S,S2: String; I,N,K: Integer; A: Word; L: LongInt; Sz: LongInt; Par: Word; B: LongInt; H: Integer; Got: Word;
    Ad: LongInt; P1,P2: Word; Ms: Word; V: String; Ok: Boolean;
Begin
 Case O Of
  1: Begin SetSig('w');W16Fail(T,'FatalExit: '+IntStr(GW(1)));End;
  3: Begin SetSig('');RetL($00050302);End;
  5: Begin SetSig('ww');RetW(W16LocalAlloc(T,GW(1),GW(2)));End;
  6: Begin SetSig('www');RetW(W16LocalRealloc(T,GW(1),GW(2),GW(3)));End;
  7: Begin SetSig('w');W16LocalFree(T,GW(1));RetW(0);End;
  8: Begin SetSig('w');RetW(W16LocalPtr(T,GW(1)));End;
  9: Begin SetSig('w');RetW(0);End;
  10: Begin SetSig('w');RetW(W16HeapSize(T,W16LocalPtr(T,GW(1))));End;
  13: Begin SetSig('w');L:=W16HeapFreeBytes(T);If L>65000 Then L:=65000;RetW(L);End;
  15: Begin SetSig('wl');
     Sz:=GL(2);If Sz>600000 Then Sz:=600000;
     Par:=(Sz+15) Div 16;If Par=0 Then Par:=1;
     A:=ArenaAlloc(T^.V,Par,T^.V^.PSP);
     If (A<>0) And ((GW(1) And $40)<>0) Then FillChar(Mem^[Lin(A,0)],Longint(Par)*16,0);
     RetW(A);
    End;
  16: Begin SetSig('wlw');                                { GlobalReAlloc }
     Sz:=GL(2);Par:=(Sz+15) Div 16;If Par=0 Then Par:=1;
     If ArenaResize(T^.V,GW(1),Par,Ms) Then RetW(GW(1))
     Else Begin
      A:=ArenaAlloc(T^.V,Par,T^.V^.PSP);
      If A<>0 Then Begin
       For I:=1 To T^.V^.NBlk Do If T^.V^.Blk[I].Seg=GW(1) Then Begin
        Move(Mem^[Lin(GW(1),0)],Mem^[Lin(A,0)],Min2(LongInt(T^.V^.Blk[I].Size)*16,Sz));Break;End;
       ArenaFree(T^.V,GW(1));
      End;
      RetW(A);
     End;
    End;
  17: Begin SetSig('w');ArenaFree(T^.V,GW(1));RetW(0);End;
  18: Begin SetSig('w');Rg[R_AX]:=0;Rg[R_DX]:=GW(1);End;
  19: Begin SetSig('w');RetW(0);End;
  20: Begin SetSig('w');L:=0;
     For I:=1 To T^.V^.NBlk Do If T^.V^.Blk[I].Seg=GW(1) Then L:=LongInt(T^.V^.Blk[I].Size)*16;
     RetL(L);End;
  21: Begin SetSig('l');RetL(GL(1) And $FFFF0000);End;
  23,24: Begin SetSig('w');RetW(0);End;
  29: Begin SetSig('');RetW(0);End;
  30: Begin SetSig('w');RetW(0);End;
  36: Begin SetSig('');RetW(T^.AutoSeg);End;
  47: Begin SetSig('p');RetW(T^.AutoSeg);End;
  48: Begin SetSig('w');RetW(1);End;
  49: Begin SetSig('wpw');
     W16PutStr(GPS(2),GPO(2),Upper(T^.Exe),GW(3));RetW(Min2(GW(3)-1,Length(T^.Exe)));End;
  51: Begin SetSig('pw');Rg[R_AX]:=GPO(1);Rg[R_DX]:=GPS(1);End;
  52: Begin SetSig('p');RetW(0);End;
  54: Begin SetSig('www');RetW(GW(3));End;
  55: Begin SetSig('p');                                   { Catch }
     Ad:=Lin(GPS(1),GPO(1));
     WrW(Ad,RdW(Lin(Sg[SG_SS],Rg[R_SP])));WrW(Ad+2,RdW(Lin(Sg[SG_SS],Rg[R_SP])+2));
     WrW(Ad+4,Rg[R_SP]+4+4);WrW(Ad+6,Rg[R_BP]);WrW(Ad+8,Rg[R_SI]);WrW(Ad+10,Rg[R_DI]);
     WrW(Ad+12,Sg[SG_DS]);WrW(Ad+14,Sg[SG_SS]);
     RetW(0);
    End;
  56: Begin SetSig('pw');                                  { Throw }
     Ad:=Lin(GPS(1),GPO(1));
     A:=GW(2);
     IPr:=RdW(Ad);Sg[SG_CS]:=RdW(Ad+2);Rg[R_SP]:=RdW(Ad+4);Rg[R_BP]:=RdW(Ad+6);Rg[R_SI]:=RdW(Ad+8);
     Rg[R_DI]:=RdW(Ad+10);Sg[SG_DS]:=RdW(Ad+12);Sg[SG_SS]:=RdW(Ad+14);
     Rg[R_AX]:=A;T^.NoRet:=True;
    End;
  57: Begin SetSig('ppw');                                 { GetProfileInt }
     If IniRead(IniFile,GStr(1),GStr(2),V) Then RetW(StrVal(V,GW(3))) Else RetW(GW(3));End;
  58: Begin SetSig('ppppw');                               { GetProfileString }
     If Not IniRead(IniFile,GStr(1),GStr(2),V) Then V:=GStr(3);
     W16PutStr(GPS(4),GPO(4),V,GW(5));RetW(Min2(Length(V),GW(5)-1));End;
  59: Begin SetSig('ppp');IniWrite(IniFile,GStr(1),GStr(2),GStr(3));RetW(1);End;
  60: Begin SetSig('wpp');RetW(W16FindRes(T,GPS(2),GPO(2),GPS(3),GPO(3)));End;
  61: Begin SetSig('ww');RetW(W16LoadRes(T,GW(2)));End;
  62: Begin SetSig('w');Rg[R_AX]:=0;Rg[R_DX]:=GW(1);End;
  63: Begin SetSig('w');RetW(0);End;
  74: Begin SetSig('ppw');                                 { OpenFile }
     S:=GStr(1);K:=GW(3);
     If (K And $8000)<>0 Then S:=W16Str(T,GPS(2),GPO(2)+8,127);
     W16SelectDos(T);
     S2:=DosPath(CV,S);
     If TraceOn Then WriteLn(TraceF,'OPENFILE ',S,' -> ',S2,' style=',HexStr(K,4));
     W16PutStr(GPS(2),GPO(2)+8,S2,127);WrB(Lin(GPS(2),GPO(2)),136);WrW(Lin(GPS(2),GPO(2))+2,0);
     If (K And $100)<>0 Then Begin RetW(0);End
     Else If (K And $200)<>0 Then Begin
      If FileExists(V2R(S2)) Then Begin {$I-}Assign(CV^.Files[0].F,V2R(S2));Erase(CV^.Files[0].F);{$I+}If IOResult<>0 Then ;RetW(1);End Else RetW($FFFF);
     End Else If (K And $4000)<>0 Then Begin If FileExists(V2R(S2)) Then RetW(1) Else Begin WrW(Lin(GPS(2),GPO(2))+2,2);RetW($FFFF);End;End
     Else Begin
      H:=W16OpenF(T,S,K And 3,(K And $1000)<>0);
      If H<0 Then Begin WrW(Lin(GPS(2),GPO(2))+2,2);RetW($FFFF);End Else RetW(H);
     End;
    End;
  77: Begin SetSig('p');I:=GPO(1);If RdB(Lin(GPS(1),I))<>0 Then Inc(I);Rg[R_AX]:=I;Rg[R_DX]:=GPS(1);End;
  78: Begin SetSig('pp');I:=GPO(2);If I>GPO(1) Then Dec(I);Rg[R_AX]:=I;Rg[R_DX]:=GPS(2);End;
  79,80: Begin SetSig('p');
     If GPS(1)=0 Then Begin
      If O=79 Then RetW(Ord(UpCase(Chr(GPO(1) And 255)))) Else RetW(Ord(LowerStr(Chr(GPO(1) And 255))[1]));
     End Else Begin
      I:=GPO(1);
      While RdB(Lin(GPS(1),I))<>0 Do Begin
       B:=RdB(Lin(GPS(1),I));
       If O=79 Then Begin If (B>=97) And (B<=122) Then WrB(Lin(GPS(1),I),B-32);End
       Else If (B>=65) And (B<=90) Then WrB(Lin(GPS(1),I),B+32);
       Inc(I);
      End;
      Rg[R_AX]:=GPO(1);Rg[R_DX]:=GPS(1);
     End;
    End;
  81: Begin SetSig('w');W16SelectDos(T);FhClose(CV,GW(1));RetW(0);End;
  82: Begin SetSig('wpw');W16SelectDos(T);H:=GW(1);
     If (H>=5) And (H<MAXFH) And CV^.Files[H].Used And (CV^.Files[H].Dev=0) Then Begin
      {$I-}BlockRead(CV^.Files[H].F,Mem^[Lin(GPS(2),GPO(2))],GW(3),Got);{$I+}
      If IOResult<>0 Then RetW($FFFF) Else RetW(Got);
     End Else RetW($FFFF);End;
  83: Begin SetSig('pw');H:=W16OpenF(T,GStr(1),2,True);RetW(IfThen_(H<0,$FFFF,H));End;
  84: Begin SetSig('wlw');W16SelectDos(T);H:=GW(1);
     If (H>=5) And (H<MAXFH) And CV^.Files[H].Used And (CV^.Files[H].Dev=0) Then Begin
      L:=GL(2);
      {$I-}
      Case GW(3) Of 1: L:=L+FilePos(CV^.Files[H].F);2: L:=L+FileSize(CV^.Files[H].F);End;
      If L<0 Then L:=0;
      Seek(CV^.Files[H].F,L);
      {$I+}
      If IOResult<>0 Then RetL(-1) Else RetL(L);
     End Else RetL(-1);End;
  85: Begin SetSig('pw');H:=W16OpenF(T,GStr(1),GW(2) And 3,False);RetW(IfThen_(H<0,$FFFF,H));End;
  86: Begin SetSig('wpw');W16SelectDos(T);H:=GW(1);
     If (H>=5) And (H<MAXFH) And CV^.Files[H].Used And (CV^.Files[H].Dev=0) Then Begin
      {$I-}BlockWrite(CV^.Files[H].F,Mem^[Lin(GPS(2),GPO(2))],GW(3),Got);{$I+}
      If IOResult<>0 Then RetW($FFFF) Else RetW(Got);
     End Else If (H=1) Or (H=2) Then RetW(GW(3)) Else RetW($FFFF);End;
  87: Begin SetSig('pp');S:=GStr(1);S2:=GStr(2);
     If S<S2 Then RetW($FFFF) Else If S>S2 Then RetW(1) Else RetW(0);End;
  88: Begin SetSig('pp');S:=GStr(2);W16PutStr(GPS(1),GPO(1),S,255);Rg[R_AX]:=GPO(1);Rg[R_DX]:=GPS(1);End;
  89: Begin SetSig('pp');S:=GStr(1);N:=Length(S);S2:=GStr(2);
     W16PutStr(GPS(1),GPO(1)+N,S2,255);Rg[R_AX]:=GPO(1);Rg[R_DX]:=GPS(1);End;
  90: Begin SetSig('p');RetW(Length(GStr(1)));End;
  91: Begin SetSig('');                                    { InitTask }
     Rg[R_AX]:=1;Rg[R_CX]:=$0400;Rg[R_DX]:=T^.NCmdShow;Rg[R_SI]:=0;Rg[R_DI]:=T^.AutoSeg;
     Sg[SG_ES]:=$0800;Rg[R_BX]:=$0081;
     WrB(Lin($0800,$81+RdB(Lin($0800,$80))),0);
    End;
  97: Begin SetSig('wpwp');                                { GetTempFileName }
     W16SelectDos(T);S:=Copy(Upper(GStr(2)),1,3);L:=GW(3);
     If L=0 Then L:=(NowCs And $FFF)+1;
     S2:='C:\~'+S+HexStr(L,4)+'.TMP';
     If (GetEnv('TEMP')<>'') And VDirExists(Upper(GetEnv('TEMP'))) Then S2:=Upper(GetEnv('TEMP'))+'\~'+S+HexStr(L,4)+'.TMP';
     If GW(3)=0 Then Begin
      {$I-}Assign(CV^.Files[0].F,V2R(S2));Rewrite(CV^.Files[0].F,1);Close(CV^.Files[0].F);{$I+}
      If IOResult<>0 Then ;
     End;
     W16PutStr(GPS(4),GPO(4),S2,60);RetW(L);
    End;
  25: Begin SetSig('l');RetL($100000);End;                  { GlobalCompact }
  50: Begin SetSig('wp');RetL(0);End;                      { GetProcAddress }
  69: Begin SetSig('p');RetW(AtomFind(GStr(1),False));End; { FindAtom }
  70: Begin SetSig('p');RetW(AtomFind(GStr(1),True));End;  { AddAtom }
  71: Begin SetSig('w');RetW(0);End;                       { DeleteAtom }
  72: Begin SetSig('wpw');I:=GW(1)-$C000;                  { GetAtomName }
     If (I>=1) And (I<=64) Then Begin W16PutStr(GPS(2),GPO(2),AtomTab[I],GW(3));RetW(Min2(Length(AtomTab[I]),GW(3)-1));End Else RetW(0);End;
  95: Begin SetSig('p');RetW(2);End;                       { LoadLibrary : introuvable }
  96: Begin SetSig('w');RetW(0);End;                       { FreeLibrary }
 Else W16Trap(T,1,O);
 End;
End;

{ remplissage par germe jusqu'a une couleur de bord }
Procedure FloodRun(T: PW16; D: Integer; X0,Y0,Border,Fc: Integer);
Const MAXSTK=12000;
Var W,H,X1,Y1,X2,Y2,Ob,Sp,X,Y,Xl,Xr,Nx,I: Integer; Vis: PByteArr_; Stk: Array[0..MAXSTK] Of LongInt; Sx,Sy: Integer;
    Mono: Boolean; Cn,Cf: Integer;
 Function Fillable(Px,Py: Integer): Boolean;
 Var M: Boolean; Cc: Integer;
 Begin
  Fillable:=False;
  If (Px<0) Or (Py<0) Or (Px>=W) Or (Py>=H) Then Exit;
  If Vis^[Py*W+Px]<>0 Then Exit;
  Cc:=DcGet(T,D,Px,Py,M);
  If M Then Cc:=IfThen_(Cc=0,0,15);
  Fillable:=Cc<>Border;
 End;
Begin
 If T^.Dc[D].Kind=2 Then Begin
  Ob:=ObjOf(T,T^.Dc[D].Bmp);If Ob=0 Then Exit;
  W:=T^.Ob[Ob].BW;H:=T^.Ob[Ob].BH;
 End Else Begin
  W16GetClient(T,T^.Dc[D].Hw,X1,Y1,X2,Y2);W:=X2+1;H:=Y2+1;
 End;
 If (W<=0) Or (H<=0) Or (LongInt(W)*H>400000) Then Exit;
 GetMem(Vis,LongInt(W)*H);FillChar(Vis^,LongInt(W)*H,0);
 Sp:=0;Stk[0]:=LongInt(X0)*4096+Y0;Sp:=1;
 While Sp>0 Do Begin
  Dec(Sp);X:=Stk[Sp] Div 4096;Y:=Stk[Sp] Mod 4096;
  If Not Fillable(X,Y) Then Continue;
  Xl:=X;While Fillable(Xl-1,Y) Do Dec(Xl);
  Xr:=X;While Fillable(Xr+1,Y) Do Inc(Xr);
  For X:=Xl To Xr Do Begin
   Vis^[Y*W+X]:=1;
   Cf:=Fc;If Cf<0 Then Cf:=cWht;
   DcPix(T,D,X,Y,Cf);
  End;
  For Sy:=-1 To 1 Do If Sy<>0 Then Begin
   Nx:=0;
   For X:=Xl To Xr Do Begin
    If Fillable(X,Y+Sy) Then Begin
     If Nx=0 Then Begin If Sp<MAXSTK Then Begin Stk[Sp]:=LongInt(X)*4096+Y+Sy;Inc(Sp);End;Nx:=1;End;
    End Else Nx:=0;
   End;
  End;
 End;
 FreeMem(Vis,LongInt(W)*H);
End;

{ enumeration de polices : trois familles, tailles 8/10/12 }
Procedure W16EnumFonts(T: PW16; NmS,NmO,CbS,CbO,DaS,DaO: Word);
Const Faces: Array[1..3] Of String[8]=('Courier','Helv','Tms Rmn');
Var Buf,Fi,Sz,I,Hh: Integer; Seg_: Word; A,Lf,Tm: LongInt; Nm: String; Ar: Array[0..6] Of Word; R: LongInt; Stop: Boolean;
Begin
 Seg_:=ArenaAlloc(T^.V,8,T^.V^.PSP);
 If Seg_=0 Then Begin RetW(0);Exit;End;
 Lf:=Lin(Seg_,0);Tm:=Lin(Seg_,64);
 If (NmS<>0) Or (NmO<>0) Then Nm:=Upper(W16Str(T,NmS,NmO,30)) Else Nm:='';
 R:=1;Stop:=False;
 For Fi:=1 To 3 Do Begin
  If (Nm<>'') And (Upper(Faces[Fi])<>Nm) Then Continue;
  For Sz:=0 To IfThen_(Nm='',0,2) Do Begin
   If Stop Then Break;
   Hh:=8+Sz*2;
   For I:=0 To 49 Do WrB(Lf+I,0);
   WrW(Lf,Hh);WrW(Lf+4,0);WrW(Lf+6,0);WrW(Lf+8,400);
   WrB(Lf+13,255);WrB(Lf+17,IfThen_(Fi=1,$31,$22));
   For I:=1 To Length(Faces[Fi]) Do WrB(Lf+18+I-1,Ord(Faces[Fi][I]));
   For I:=0 To 30 Do WrB(Tm+I,0);
   WrW(Tm,Hh);WrW(Tm+2,Hh-1);WrW(Tm+4,1);WrW(Tm+10,8);WrW(Tm+12,8);WrW(Tm+14,400);
   WrB(Tm+20,255);WrB(Tm+21,32);WrB(Tm+22,32);WrW(Tm+27,36);WrW(Tm+29,36);
   Ar[0]:=Seg_;Ar[1]:=0;Ar[2]:=Seg_;Ar[3]:=64;Ar[4]:=1;Ar[5]:=DaS;Ar[6]:=DaO;
   AT:=T;
   R:=W16CallFar(CbS,CbO,Ar,7);
   AT:=T;
   If (R And $FFFF)=0 Then Stop:=True;
  End;
  If Stop Then Break;
 End;
 RetW(R And $FFFF);
End;

{ ---------------- API : GDI ---------------- }

Procedure W16Gdi(T: PW16; O: Integer);
Var Ok_: Boolean; D,D2,I,X,Y,X2,Y2,N,C: Integer; H: Word; L: LongInt; S: String; Nl: Boolean; Pts: Array[1..64] Of Integer;
    Ob: Integer; Pat: Integer; Old: Word; A: LongInt; W_,H_: Integer; Hd: Word; Ad_: LongInt; BrushRow,X1_,Y1_: Integer;
 Function Dc1: Integer;
 Begin
  Dc1:=DcIdx(T,GW(1));
 End;
Begin
 Case O Of
  1: Begin SetSig('wl');D:=Dc1;If D>0 Then Begin L:=T^.Dc[D].BkCol;T^.Dc[D].BkCol:=GL(2);RetL(L);End Else RetL(0);End;
  2: Begin SetSig('ww');D:=Dc1;If D>0 Then Begin RetW(T^.Dc[D].BkMode);T^.Dc[D].BkMode:=GW(2);End Else RetW(0);End;
  3: Begin SetSig('ww');RetW(1);End;
  4: Begin SetSig('ww');If TraceOn Then WriteLn(TraceF,'   ROP2=',GW(2));D:=Dc1;If D>0 Then Begin RetW(T^.Dc[D].Rop2);T^.Dc[D].Rop2:=GW(2);End Else RetW(0);End;
  9: Begin SetSig('wl');D:=Dc1;If D>0 Then Begin L:=T^.Dc[D].TextCol;T^.Dc[D].TextCol:=GL(2);RetL(L);End Else RetL(0);End;
  12,14: Begin SetSig('www');RetL(0);End;
  13: Begin SetSig('www');D:=Dc1;
     If D>0 Then Begin RetL(LongInt(T^.Dc[D].VOx And $FFFF)+(LongInt(T^.Dc[D].VOy And $FFFF) Shl 16));T^.Dc[D].VOx:=GI(2);T^.Dc[D].VOy:=GI(3);End Else RetL(0);End;
  19: Begin SetSig('www');D:=Dc1;                                   { LineTo }
     If (D>0) And DcBegin(T,D) Then Begin DcPenLine(T,D,T^.Dc[D].PenX,T^.Dc[D].PenY,GI(2),GI(3));DcEnd(T,D);End;
     If D>0 Then Begin T^.Dc[D].PenX:=GI(2);T^.Dc[D].PenY:=GI(3);End;RetW(1);End;
  20: Begin SetSig('www');D:=Dc1;                                   { MoveTo }
     If D>0 Then Begin RetL(LongInt(T^.Dc[D].PenX And $FFFF)+(LongInt(T^.Dc[D].PenY And $FFFF) Shl 16));
      T^.Dc[D].PenX:=GI(2);T^.Dc[D].PenY:=GI(3);End Else RetL(0);End;
  22: Begin SetSig('wwwww');D:=Dc1;                                  { IntersectClipRect }
     If TraceOn Then WriteLn(TraceF,'ICLIP ',GI(2),',',GI(3),',',GI(4),',',GI(5));
     If D>0 Then Begin
      If Not T^.Dc[D].ClipOn Then Begin T^.Dc[D].CX1:=GI(2);T^.Dc[D].CY1:=GI(3);T^.Dc[D].CX2:=GI(4);T^.Dc[D].CY2:=GI(5);End
      Else Begin T^.Dc[D].CX1:=Max2(T^.Dc[D].CX1,GI(2));T^.Dc[D].CY1:=Max2(T^.Dc[D].CY1,GI(3));
       T^.Dc[D].CX2:=Min2(T^.Dc[D].CX2,GI(4));T^.Dc[D].CY2:=Min2(T^.Dc[D].CY2,GI(5));End;
      T^.Dc[D].ClipOn:=True;
     End;RetW(2);End;
  24: Begin SetSig('wwwww');D:=Dc1;
     If (D>0) And DcBegin(T,D) Then Begin DcEllipse(T,D,GI(2),GI(3),GI(4),GI(5));DcEnd(T,D);End;RetW(1);End;
  27: Begin SetSig('wwwww');D:=Dc1;
     If (D>0) And DcBegin(T,D) Then Begin DcRectangle(T,D,GI(2),GI(3),GI(4),GI(5));DcEnd(T,D);End;RetW(1);End;
  28: Begin SetSig('wwwwwww');D:=Dc1;
     If (D>0) And DcBegin(T,D) Then Begin DcRectangle(T,D,GI(2),GI(3),GI(4),GI(5));DcEnd(T,D);End;RetW(1);End;
  29: Begin SetSig('wwwwwl');D:=Dc1;                                 { PatBlt }
     If TraceOn Then WriteLn(TraceF,'PATBLT ',GI(2),',',GI(3),' ',GI(4),'x',GI(5),' rop=',HexStr(GL(6),8),' dc=',D,' clip=',Ord(T^.Dc[D].ClipOn),' ',T^.Dc[D].CX1,',',T^.Dc[D].CY1,',',T^.Dc[D].CX2,',',T^.Dc[D].CY2);
     If (D>0) And DcBegin(T,D) Then Begin W16BitBlt(T,D,GI(2),GI(3),GI(4),GI(5),D,0,0,GI(4),GI(5),GL(6));DcEnd(T,D);End;RetW(1);End;
  30: Begin SetSig('w');D:=Dc1;
     If D>0 Then Begin T^.Dc[D].SvPen:=T^.Dc[D].Pen;T^.Dc[D].SvBrush:=T^.Dc[D].Brush;T^.Dc[D].SvText:=T^.Dc[D].TextCol;
      T^.Dc[D].SvBk:=T^.Dc[D].BkCol;End;RetW(1);End;
  31: Begin SetSig('wwwl');D:=Dc1;
     If (D>0) And DcBegin(T,D) Then Begin DcPix(T,D,GI(2),GI(3),W16Col(GL(4)));DcEnd(T,D);End;RetL(GL(4));End;
  33: Begin SetSig('wwwpw');D:=Dc1;N:=GW(5);                         { TextOut }
     S:='';For I:=0 To Min2(N,255)-1 Do S:=S+Chr(RdB(Lin(GPS(4),GPO(4)+I)));
     If TraceOn Then WriteLn(TraceF,'TEXTOUT ',GI(2),',',GI(3),' [',S,'] dc=',D,' col=',HexStr(T^.Dc[D].TextCol,6),' bk=',T^.Dc[D].BkMode);
     If (D>0) And DcBegin(T,D) Then Begin If TraceOn Then WriteLn(TraceF,'  ORG ',T^.Dc[D].OrgX,',',T^.Dc[D].OrgY,' hw=',T^.Dc[D].Hw,' kind=',T^.Dc[D].Kind);DcText(T,D,GI(2),GI(3),S);DcEnd(T,D);End;RetW(1);End;
  34: Begin SetSig('wwwwwwwwl');D:=Dc1;D2:=DcIdx(T,GW(6));           { BitBlt }
     If TraceOn Then WriteLn(TraceF,'BITBLT0 dst=',HexStr(GW(1),4),' D=',D,' src=',HexStr(GW(6),4),' D2=',D2,' ',GI(2),',',GI(3),' ',GI(4),'x',GI(5));
     If (D>0) And (D2>0) Then Begin
      Ok_:=DcBegin(T,D);
      If TraceOn Then WriteLn(TraceF,'BITBLT dst(kind=',T^.Dc[D].Kind,' hw=',T^.Dc[D].Hw,' org=',T^.Dc[D].OrgX,',',T^.Dc[D].OrgY,') ',GI(2),',',GI(3),' ',GI(4),'x',GI(5),' src(kind=',T^.Dc[D2].Kind,') ',GI(7),',',GI(8),' rop=',HexStr(GL(9),8),' ok=',Ord(Ok_));
      If Ok_ Then Begin
       If (T^.Dc[D2].Kind=1) And (D2<>D) Then DcBegin(T,D2);
       W16BitBlt(T,D,GI(2),GI(3),GI(4),GI(5),D2,GI(7),GI(8),GI(4),GI(5),GL(9));
       If T^.Dc[D].Kind=1 Then DcEnd(T,D);
      End;
     End Else If (D>0) And RopPatOnly(GL(9)) Then Begin
      If DcBegin(T,D) Then Begin W16BitBlt(T,D,GI(2),GI(3),GI(4),GI(5),D,0,0,GI(4),GI(5),GL(9));DcEnd(T,D);End;
     End;
     RetW(1);End;
  35: Begin SetSig('wwwwwwwwwwl');D:=Dc1;D2:=DcIdx(T,GW(6));         { StretchBlt }
     If (D>0) And (D2>0) Then Begin
      If DcBegin(T,D) Then Begin
       If (T^.Dc[D2].Kind=1) And (D2<>D) Then DcBegin(T,D2);
       W16BitBlt(T,D,GI(2),GI(3),GI(4),GI(5),D2,GI(7),GI(8),GI(9),GI(10),GL(11));
       If T^.Dc[D].Kind=1 Then DcEnd(T,D);
      End;
     End;
     RetW(1);End;
  36,37: Begin SetSig('wpw');D:=Dc1;N:=Min2(GW(3),32);                  { Polygon / Polyline }
     For I:=1 To N Do Begin Pts[I*2-1]:=RdI(GPS(2),GPO(2)+(I-1)*4);Pts[I*2]:=RdI(GPS(2),GPO(2)+(I-1)*4+2);End;
     If (D>0) And DcBegin(T,D) And (N>1) Then Begin
      If O=36 Then Begin
       { remplissage par balayage (pair/impair) }
       Y2:=Pts[2];Y:=Pts[2];
       For I:=1 To N Do Begin If Pts[I*2]<Y Then Y:=Pts[I*2];If Pts[I*2]>Y2 Then Y2:=Pts[I*2];End;
       Pat:=BrushPix(T,D,0,0);
       If Pat>=-1 Then
        For C:=Y To Y2 Do Begin
         X:=32767;X2:=-32768;
         For I:=1 To N Do Begin
          Ob:=I+1;If Ob>N Then Ob:=1;
          If ((Pts[I*2]<=C) And (Pts[Ob*2]>C)) Or ((Pts[Ob*2]<=C) And (Pts[I*2]>C)) Then Begin
           H_:=Pts[I*2-1]+(LongInt(C-Pts[I*2])*(Pts[Ob*2-1]-Pts[I*2-1])) Div (Pts[Ob*2]-Pts[I*2]);
           If H_<X Then X:=H_;If H_>X2 Then X2:=H_;
          End;
         End;
         If X2>=X Then DcFillBrush(T,D,X,C,X2,C);
        End;
      End;
      For I:=1 To N-1 Do DcPenLine(T,D,Pts[I*2-1],Pts[I*2],Pts[I*2+1],Pts[I*2+2]);
      If O=36 Then DcPenLine(T,D,Pts[N*2-1],Pts[N*2],Pts[1],Pts[2]);
      DcEnd(T,D);
     End;
     RetW(1);End;
  38: Begin SetSig('wwwpp');RetW(0);End;
  39: Begin SetSig('ww');D:=Dc1;
     If D>0 Then Begin T^.Dc[D].Pen:=T^.Dc[D].SvPen;T^.Dc[D].Brush:=T^.Dc[D].SvBrush;T^.Dc[D].TextCol:=T^.Dc[D].SvText;
      T^.Dc[D].BkCol:=T^.Dc[D].SvBk;End;RetW(1);End;
  45: Begin SetSig('ww');D:=Dc1;H:=GW(2);Old:=0;                     { SelectObject }
     If D>0 Then Begin
      Ob:=ObjOf(T,H);
      If Ob>0 Then Begin
       Case T^.Ob[Ob].Kind Of
        2: Begin Old:=T^.Dc[D].Pen;T^.Dc[D].Pen:=H;End;
        1: Begin Old:=T^.Dc[D].Brush;T^.Dc[D].Brush:=H;End;
        4: Begin Old:=T^.Dc[D].Bmp;If Old=0 Then Old:=$29;T^.Dc[D].Bmp:=H;End;
        3: Old:=$2D;
       End;
      End Else Begin
       If H=$29 Then Begin Old:=T^.Dc[D].Bmp;If Old=0 Then Old:=$29;T^.Dc[D].Bmp:=0;End
       Else If (H>=$20) And (H<=$28) Then Begin
        If H>=$26 Then Begin Old:=T^.Dc[D].Pen;T^.Dc[D].Pen:=H;End Else Begin Old:=T^.Dc[D].Brush;T^.Dc[D].Brush:=H;End;
       End Else Old:=$2D;
      End;
     End;
     RetW(Old);End;
  48: Begin SetSig('wwwwp');                                          { CreateBitmap }
     Hd:=W16BmpNew(T,GI(1),GI(2),(GW(3)*GW(4))=1);
     If (Hd<>0) And (GPS(5)<>0) Then W16BmpFromBits(T,Hd,GPS(5),GPO(5),((GI(1)*GW(4)+15) Div 16)*2,GW(3),GW(4));
     RetW(Hd);End;
  50: Begin SetSig('p');Hd:=W16ObjNew(T,1,RdW(Lin(GPS(1),GPO(1)+2))+(LongInt(RdW(Lin(GPS(1),GPO(1)+4))) Shl 16),RdW(Lin(GPS(1),GPO(1))),0);
     If (Hd<>0) And (RdW(Lin(GPS(1),GPO(1)))=1) Then T^.Ob[Hd-$100].Style:=1;
     RetW(Hd);End;
  51: Begin SetSig('www');RetW(W16BmpNew(T,GI(2),GI(3),False));End;
  52: Begin SetSig('w');RetW(W16DcNew(T,2,0));If TraceOn Then WriteLn(TraceF,'CCDC -> ',HexStr(Rg[R_AX],4));End;
  53: Begin SetSig('pppp');RetW(0);End;
  153: Begin SetSig('pppp');RetW(W16DcNew(T,3,0));End;
  58: Begin SetSig('wl');RetW(W16ObjNew(T,1,GL(2),0,0));End;
  60: Begin SetSig('w');                                              { CreatePatternBrush }
     Ob:=ObjOf(T,GW(1));Hd:=W16ObjNew(T,1,0,3,0);
     If (Hd<>0) And (Ob>0) Then Begin
      For Y:=0 To 7 Do Begin
       A:=0;
       For X:=0 To 7 Do If T^.Ob[Ob].Bmp^[(Y Mod T^.Ob[Ob].BH)*T^.Ob[Ob].BW+(X Mod T^.Ob[Ob].BW)]<>0 Then A:=A Or (128 Shr X);
       T^.Ob[Hd-$100].Pat[Y]:=A;
      End;
     End;
     RetW(Hd);End;
  61: Begin SetSig('wwl');RetW(W16ObjNew(T,2,GL(3),GW(1),GW(2)));End;
  66: Begin SetSig('l');RetW(W16ObjNew(T,1,GL(1),0,0));End;
  67: Begin SetSig('wpw');RetW(1);End;
  68: Begin SetSig('w');D:=Dc1;If TraceOn Then WriteLn(TraceF,'DELDC ',HexStr(GW(1),4),' D=',D);If D>0 Then T^.Dc[D].Used:=False;RetW(1);End;
  69: Begin SetSig('w');W16ObjFree(T,GW(1));RetW(1);End;
  74: Begin SetSig('wlp');RetL(0);End;
  80: Begin SetSig('ww');
     Case GW(2) Of
      0: RetW($0100);2: RetW(1);4: RetW(180);6: RetW(135);8: RetW(SCR_W);10: RetW(SCR_H);12: RetW(1);14: RetW(4);
      16: RetW(8);18: RetW(8);22: RetW(2);24: RetW(16);26: RetW(0);28: RetW(0);30: RetW($7F);32: RetW($FF);34: RetW($7);
      36: RetW(1);38: RetW($1C1);40: RetW(36);42: RetW(36);44: RetW(51);88: RetW(96);90: RetW(96);
     Else RetW(0);
     End;
    End;
  82: Begin SetSig('wwp');Ob:=ObjOf(T,GW(1));                          { GetObject }
     If (Ob>0) And (T^.Ob[Ob].Kind=4) And (GW(2)>=14) Then Begin
      WrW(Lin(GPS(3),GPO(3)),0);WrW(Lin(GPS(3),GPO(3)+2),T^.Ob[Ob].BW);WrW(Lin(GPS(3),GPO(3)+4),T^.Ob[Ob].BH);
      WrW(Lin(GPS(3),GPO(3)+6),(T^.Ob[Ob].BW+15) Div 16*2);
      WrB(Lin(GPS(3),GPO(3)+8),1);WrB(Lin(GPS(3),GPO(3)+9),IfThen_(T^.Ob[Ob].Mono,1,4));
      WrW(Lin(GPS(3),GPO(3)+10),0);WrW(Lin(GPS(3),GPO(3)+12),0);
      RetW(14);
     End Else RetW(0);End;
  87: Begin SetSig('w');RetW($20+GW(1));End;
  91: Begin SetSig('wpw');RetL(LongInt(GW(3))*8+(LongInt(8) Shl 16));End;
  93: Begin SetSig('wp');                                              { GetTextMetrics }
     A:=Lin(GPS(2),GPO(2));
     For I:=0 To 30 Do WrB(A+I,0);
     WrW(A,8);WrW(A+2,7);WrW(A+4,1);WrW(A+6,0);WrW(A+8,2);WrW(A+10,8);WrW(A+12,8);WrW(A+14,400);
     WrB(A+19,0);WrB(A+20,255);WrB(A+21,32);WrB(A+22,32);WrB(A+23,$00);WrW(A+25,0);WrW(A+27,36);WrW(A+29,36);
     RetW(1);End;
  123: Begin SetSig('wp');RetW(1);End;
  148: Begin SetSig('www');RetL(0);End;
  150: Begin SetSig('w');RetW(1);End;
  7: Begin SetSig('ww');RetW(1);End;                       { SetStretchBltMode }
  10: Begin SetSig('www');RetW(1);End;                     { SetTextJustification }
  11: Begin SetSig('www');D:=Dc1;                          { SetWindowOrg }
     If D>0 Then Begin RetL(LongInt(T^.Dc[D].WOx And $FFFF)+(LongInt(T^.Dc[D].WOy And $FFFF) Shl 16));T^.Dc[D].WOx:=GI(2);T^.Dc[D].WOy:=GI(3);End Else RetL(0);End;
  25: Begin SetSig('wwwl');D:=Dc1;                         { FloodFill (jusqu'a la couleur de bord) }
     If (D>0) And DcBegin(T,D) Then Begin
      C:=W16Col(GL(4));X:=GI(2);Y:=GI(3);
      BrushRow:=BrushPix(T,D,0,0);
      FloodRun(T,D,X,Y,C,BrushRow);
      DcEnd(T,D);
     End;RetW(1);End;
  44: Begin SetSig('ww');RetW(2);End;                      { SelectClipRgn }
  49: Begin SetSig('p');Ad_:=Lin(GPS(1),GPO(1));           { CreateBitmapIndirect }
     W_:=RdW(Ad_+2);H_:=RdW(Ad_+4);
     RetW(W16BmpNew(T,W_,H_,(RdB(Ad_+9)*RdB(Ad_+8))=1));End;
  57: Begin SetSig('p');RetW(W16ObjNew(T,3,0,0,0));End;    { CreateFontIndirect }
  70: Begin SetSig('wppp');W16EnumFonts(T,GPS(2),GPO(2),GPS(3),GPO(3),GPS(4),GPO(4));End; { EnumFonts }
  76: Begin SetSig('w');D:=Dc1;If D>0 Then RetW(T^.Dc[D].BkMode) Else RetW(0);End;
  77: Begin SetSig('wp');D:=Dc1;Ad_:=Lin(GPS(2),GPO(2));  { GetClipBox }
     W16GetClient(T,T^.Dc[D].Hw,X,Y,X2,Y2);
     WrW(Ad_,0);WrW(Ad_+2,0);WrW(Ad_+4,X2+1);WrW(Ad_+6,Y2+1);RetW(2);End;
  79: Begin SetSig('w');D:=Dc1;                            { GetDCOrg }
     If (D>0) And W16ClientOrg(T,T^.Dc[D].Hw,X,Y,X2,Y2,N,C) Then RetL(LongInt(X And $FFFF)+(LongInt(Y And $FFFF) Shl 16)) Else RetL(0);End;
  83: Begin SetSig('www');D:=Dc1;L:=0;                     { GetPixel }
     If (D>0) And DcBegin(T,D) Then Begin
      C:=DcGet(T,D,GI(2),GI(3),Nl);
      If Nl Then Begin If C=0 Then L:=0 Else L:=$FFFFFF;End
      Else L:=VgaRGB[C And 15,0]+VgaRGB[C And 15,1]*256+LongInt(VgaRGB[C And 15,2])*65536;
      DcEnd(T,D);
     End;RetL(L);End;
  90: Begin SetSig('w');D:=Dc1;If D>0 Then RetL(T^.Dc[D].TextCol) Else RetL(0);End;
  92: Begin SetSig('wwp');W16PutStr(GPS(3),GPO(3),'System',GW(2));RetW(6);End;   { GetTextFace }
  106: Begin SetSig('wlp');RetL(0);End;                    { SetBitmapBits }
  128: Begin SetSig('www');If GW(3)=0 Then RetW($7FFF) Else RetW(Word((LongInt(SmallInt(GW(1)))*SmallInt(GW(2))+SmallInt(GW(3)) Div 2) Div SmallInt(GW(3))));End;
  135: Begin SetSig('wwwlw');D:=Dc1;                       { ScanLR }
     L:=$FFFF;
     If (D>0) And DcBegin(T,D) Then Begin
      X:=GI(2);Y:=GI(3);C:=W16Col(GL(4));N:=GW(5);
      W16GetClient(T,T^.Dc[D].Hw,X1_,Y1_,X2,Y2);
      If T^.Dc[D].Kind=2 Then Begin Ob:=ObjOf(T,T^.Dc[D].Bmp);If Ob>0 Then X2:=T^.Ob[Ob].BW-1;End;
      While (X>=0) And (X<=X2) Do Begin
       Nl:=False;I:=DcGet(T,D,X,Y,Nl);
       If Nl Then I:=IfThen_(I=0,0,15);
       If ((N And 2)=0) = (I=C) Then Begin L:=X;Break;End;
       If (N And 1)<>0 Then Dec(X) Else Inc(X);
      End;
      DcEnd(T,D);
     End;RetW(L);End;
  154: Begin SetSig('l');RetL(GL(1));End;                  { GetNearestColor }
  156: Begin SetSig('www');RetW(W16BmpNew(T,GI(2),GI(3),False));End;
  162: Begin SetSig('w');RetL(0);End;                      { GetBitmapDimension }
  163: Begin SetSig('wwwp');RetL(0);End;                   { SetBitmapDimension }
  350: Begin SetSig('wwwp');Ad_:=Lin(GPS(4),GPO(4));       { GetCharWidth }
     For I:=GW(2) To GW(3) Do WrW(Ad_+(I-GW(2))*2,8);RetW(1);End;
  351: Begin SetSig('wwwwppwp');D:=Dc1;N:=GW(7);           { ExtTextOut }
     S:='';For I:=0 To Min2(N,255)-1 Do S:=S+Chr(RdB(Lin(GPS(6),GPO(6)+I)));
     If TraceOn Then Begin Write(TraceF,'EXTTEXTOUT ',GI(2),',',GI(3),' opt=',GW(4),' n=',N,' dc=',D,' rect=');If (GPS(5)<>0) Or (GPO(5)<>0) Then Begin Ad_:=Lin(GPS(5),GPO(5));Write(TraceF,SmallInt(RdW(Ad_)),',',SmallInt(RdW(Ad_+2)),',',SmallInt(RdW(Ad_+4)),',',SmallInt(RdW(Ad_+6)));End;For I:=1 To Length(S) Do Write(TraceF,' ',HexStr(Ord(S[I]),2));WriteLn(TraceF);End;
     If (D>0) And DcBegin(T,D) Then Begin
      If ((GW(4) And 2)<>0) And ((GPS(5)<>0) Or (GPO(5)<>0)) Then Begin
       Ad_:=Lin(GPS(5),GPO(5));
       DcBar(T,D,SmallInt(RdW(Ad_)),SmallInt(RdW(Ad_+2)),SmallInt(RdW(Ad_+4))-1,SmallInt(RdW(Ad_+6))-1,W16Col(T^.Dc[D].BkCol));
      End;
      If TraceOn Then WriteLn(TraceF,'  ORG ',T^.Dc[D].OrgX,',',T^.Dc[D].OrgY,' WO=',T^.Dc[D].WOx,',',T^.Dc[D].WOy,' VO=',T^.Dc[D].VOx,',',T^.Dc[D].VOy,' hw=',T^.Dc[D].Hw,' kind=',T^.Dc[D].Kind,' paint=',Ord(T^.Dc[D].Paint));
      DcText(T,D,GI(2),GI(3),S);DcEnd(T,D);
     End;RetW(1);End;
 Else W16Trap(T,2,O);
 End;
End;

{ ---------------- API : USER ---------------- }

Function W16TaskTick: LongInt;
Begin
 W16TaskTick:=NowCs*10;
End;

Function W16NextMsg(T: PW16; Var M: TMsg16; Remove: Boolean): Boolean;
Var K: Integer; Nw: LongInt;
Begin
 W16NextMsg:=False;
 Nw:=W16TaskTick;
 For K:=1 To MAXW16T Do
  If T^.Tm[K].Used And (Nw-T^.Tm[K].Last>=T^.Tm[K].Ms) Then Begin
   T^.Tm[K].Last:=Nw;
   W16Post(T,T^.Tm[K].Hw,WM_TIMER,T^.Tm[K].Id,LongInt(T^.Tm[K].PSeg) Shl 16 Or T^.Tm[K].POfs);
  End;
 If T^.QH<>T^.QT Then Begin
  M:=T^.Q[T^.QH];
  If Remove Then T^.QH:=(T^.QH+1) Mod MAXW16Q;
  W16NextMsg:=True;
 End;
End;

Procedure W16FillMsg(T: PW16; Const M: TMsg16; Ps,Po: Word);
Var Ad: LongInt;
Begin
 Ad:=Lin(Ps,Po);
 WrW(Ad,M.Hw);WrW(Ad+2,M.Msg);WrW(Ad+4,M.Wp);WrW(Ad+6,M.Lp And $FFFF);WrW(Ad+8,(M.Lp Shr 16) And $FFFF);
 WrW(Ad+10,M.Tm And $FFFF);WrW(Ad+12,(M.Tm Shr 16) And $FFFF);WrW(Ad+14,M.Px);WrW(Ad+16,M.Py);
 If (M.Msg=WM_KEYDOWN) Or (M.Msg=WM_KEYUP) Then Begin T^.Ctrl:=(M.Py And 2)<>0;T^.Shift:=(M.Py And 1)<>0;End;
End;

Function W16ClipSig: LongInt;
Var I: Integer; H: LongInt;
Begin
 H:=ClipKind*7919+ClipLen*31+ClipBmpW*13+ClipBmpH;
 For I:=0 To Min2(ClipLen,200)-1 Do H:=(H*33+Ord(ClipTxt[I])) And $7FFFFFF;
 W16ClipSig:=H;
End;

Procedure W16User(T: PW16; O: Integer);
Var Msg_: TMsg16; Ps_,Po_: Word; Old_: Word; Ms_: PMenuArr; Nm_: PIntP; Pop_: Integer; Hw0_: Word; Par: Word;
    S,S2: String; I,N,K,X,Y,X2,Y2,D: Integer; Hw: Word; W: PWindow; X1,Y1,Rx2,Ry2: Integer; A: LongInt; L: LongInt;
    R: Integer; C: Integer; Rt: PDlgRt; H: Word; Ob: Integer; Nl: Boolean; Fmt: Word; Wr: Boolean; Lm: String; Ln: String;
    Ys: Integer; P: Integer; Ar5: Array[0..4] Of Word;
 Function SendTo(Hw0,Msg,Wp: Word; Lp: LongInt): LongInt;
 Var Rt2: PDlgRt;
 Begin
  If Hw0>=$8000 Then Begin
   If CurDlg<>Nil Then SendTo:=W16CtlMsg(T,CurDlg,Hw0-$8000,Msg,Wp,Lp) Else SendTo:=0;
  End Else If DlgOf(T,Hw0,Rt2) And (Hw0<>0) And (T^.Wn[Hw0].PSeg=0) Then SendTo:=0
  Else SendTo:=W16Send(T,Hw0,Msg,Wp,Lp);
 End;
Begin
 Case O Of
  1: Begin SetSig('wppw');
     R:=MsgBox(GStr(2)+'|'+GStr(3),IfThen_((GW(4) And 7)=1,1,IfThen_((GW(4) And 7)=4,2,IfThen_((GW(4) And 7)=3,3,0))),
        IfThen_((GW(4) And $70)=$10,3,IfThen_((GW(4) And $70)=$20,2,IfThen_((GW(4) And $70)=$40,1,0))));
     AT:=T;
     RetW(R);
    End;
  5: Begin SetSig('w');RetW(1);End;
  6: Begin SetSig('w');W16Post(T,0,WM_QUIT,GW(1),0);RetW(0);End;
  7: Begin SetSig('lw');W16Post(T,0,WM_QUIT,0,0);RetW(1);End;
  10: Begin SetSig('wwwp');
     For I:=1 To MAXW16T Do If Not T^.Tm[I].Used Then Begin
      T^.Tm[I].Used:=True;T^.Tm[I].Hw:=GW(1);T^.Tm[I].Id:=GW(2);T^.Tm[I].Ms:=Max2(30,GW(3));
      T^.Tm[I].Last:=W16TaskTick;T^.Tm[I].PSeg:=GPS(4);T^.Tm[I].POfs:=GPO(4);
      RetW(IfThen_(GW(2)=0,1,GW(2)));Exit;
     End;
     RetW(0);
    End;
  12: Begin SetSig('ww');For I:=1 To MAXW16T Do If T^.Tm[I].Used And (T^.Tm[I].Hw=GW(1)) And (T^.Tm[I].Id=GW(2)) Then T^.Tm[I].Used:=False;RetW(1);End;
  13,15: Begin SetSig('');RetL(W16TaskTick);End;
  17: Begin SetSig('p');WrW(Lin(GPS(1),GPO(1)),MX);WrW(Lin(GPS(1),GPO(1)+2),MY);RetW(0);End;
  18: Begin SetSig('w');W:=W16HostOf(T,GW(1));If W<>Nil Then Capture:=W;RetW(0);End;
  19: Begin SetSig('');Capture:=Nil;RetW(0);End;
  22: Begin SetSig('w');RetW(T^.Focus);T^.Focus:=GW(1);
     If (CurDlg<>Nil) And (GW(1)>=$8000) Then CurDlg^.D.Focus:=GW(1)-$8000;End;
  23: Begin SetSig('');RetW(T^.Focus);End;
  28: Begin SetSig('wp');W:=W16HostOf(T,GW(1));                       { ClientToScreen }
     If (W<>Nil) And W16ClientOrg(T,GW(1),X1,Y1,Rx2,Ry2,X,Y) Then Begin
      WrW(Lin(GPS(2),GPO(2)),RdI(GPS(2),GPO(2))+X1);WrW(Lin(GPS(2),GPO(2)+2),RdI(GPS(2),GPO(2)+2)+Y1);End;
     RetW(1);End;
  31: Begin SetSig('w');W:=W16HostOf(T,GW(1));RetW(Ord((W<>Nil) And (W^.State=1)));End;
  32: Begin SetSig('wp');W:=W16HostOf(T,GW(1));
     If W<>Nil Then Begin WrW(Lin(GPS(2),GPO(2)),W^.X);WrW(Lin(GPS(2),GPO(2)+2),W^.Y);
      WrW(Lin(GPS(2),GPO(2)+4),W^.X+W^.W);WrW(Lin(GPS(2),GPO(2)+6),W^.Y+W^.H);End;
     RetW(1);End;
  33: Begin SetSig('wp');W16GetClient(T,GW(1),X1,Y1,X2,Y2);
     WrW(Lin(GPS(2),GPO(2)),0);WrW(Lin(GPS(2),GPO(2)+2),0);WrW(Lin(GPS(2),GPO(2)+4),X2+1);WrW(Lin(GPS(2),GPO(2)+6),Y2+1);RetW(1);End;
  34: Begin SetSig('ww');Hw:=GW(1);
     If Hw>=$8000 Then Begin If CurDlg<>Nil Then CurDlg^.D.C[Hw-$8000].Enabled:=GW(2)<>0;CurDlg^.Redraw:=True;End
     Else If (Hw>=1) And (Hw<=MAXW16W) Then T^.Wn[Hw].Enabled:=GW(2)<>0;RetW(0);End;
  35: Begin SetSig('w');Hw:=GW(1);
     If Hw>=$8000 Then RetW(Ord((CurDlg<>Nil) And CurDlg^.D.C[Hw-$8000].Enabled))
     Else If (Hw>=1) And (Hw<=MAXW16W) Then RetW(Ord(T^.Wn[Hw].Enabled)) Else RetW(0);End;
  36: Begin SetSig('wpw');Hw:=GW(1);
     If Hw>=$8000 Then RetW(W16CtlMsg(T,CurDlg,Hw-$8000,WM_GETTEXT,GW(3),LongInt(GPS(2)) Shl 16 Or GPO(2)))
     Else If (Hw>=1) And (Hw<=MAXW16W) Then Begin
      If T^.Wn[Hw].Kind=WK_EDIT Then RetW(W16EditProc(T,Hw,WM_GETTEXT,GW(3),LongInt(GPS(2)) Shl 16 Or GPO(2)))
      Else Begin W16PutStr(GPS(2),GPO(2),T^.Wn[Hw].Title,GW(3));RetW(Min2(Length(T^.Wn[Hw].Title),GW(3)-1));End;
     End Else RetW(0);End;
  37: Begin SetSig('wp');Hw:=GW(1);S:=GStr(2);
     If Hw>=$8000 Then W16CtlMsg(T,CurDlg,Hw-$8000,WM_SETTEXT,0,LongInt(GPS(2)) Shl 16 Or GPO(2))
     Else If (Hw>=1) And (Hw<=MAXW16W) And T^.Wn[Hw].Used Then Begin
      If T^.Wn[Hw].Kind=WK_EDIT Then W16EditProc(T,Hw,WM_SETTEXT,0,LongInt(GPS(2)) Shl 16 Or GPO(2))
      Else Begin T^.Wn[Hw].Title:=Copy(S,1,64);If T^.Wn[Hw].Host<>Nil Then T^.Wn[Hw].Host^.Title:=T^.Wn[Hw].Title;End;
     End;
     Dirty:=True;RetW(0);End;
  38: Begin SetSig('w');Hw:=GW(1);
     If Hw>=$8000 Then RetW(W16CtlMsg(T,CurDlg,Hw-$8000,WM_GETTEXTLENGTH,0,0))
     Else If (Hw>=1) And (Hw<=MAXW16W) And (T^.Wn[Hw].Kind=WK_EDIT) Then RetW(T^.Wn[Hw].Ed^.Len)
     Else If (Hw>=1) And (Hw<=MAXW16W) Then RetW(Length(T^.Wn[Hw].Title)) Else RetW(0);End;
  39: Begin SetSig('wp');Hw:=GW(1);                                    { BeginPaint }
     H:=W16DcNew(T,1,Hw);D:=DcIdx(T,H);
     If D>0 Then T^.Dc[D].Paint:=T^.Painting;
     A:=Lin(GPS(2),GPO(2));
     WrW(A,H);WrW(A+2,1);
     W16GetClient(T,Hw,X1,Y1,X2,Y2);
     WrW(A+4,0);WrW(A+6,0);WrW(A+8,X2+1);WrW(A+10,Y2+1);
     RetW(H);End;
  40: Begin SetSig('wp');D:=DcIdx(T,RdW(Lin(GPS(2),GPO(2))));
     If D>0 Then Begin DcEnd(T,D);T^.Dc[D].Used:=False;End;RetW(1);End;
  41: Begin SetSig('pplwwwwwwwp');                                     { CreateWindow }
     If TraceOn Then WriteLn(TraceF,'CREATEWIN cls=',GStr(1),' title=',GStr(2),' style=',HexStr(GL(3),8),' x=',GI(4),' y=',GI(5),' w=',GI(6),' h=',GI(7),' par=',GW(8),' id=',GW(10));
     RetW(W16CreateWin(T,GStr(1),GStr(2),GL(3),SmallInt(GW(4)),SmallInt(GW(5)),SmallInt(GW(6)),SmallInt(GW(7)),GW(8),GW(9),GW(10),GPS(11),GPO(11)));
     Hw:=Rg[R_AX];
     If Hw<>0 Then Begin
      W16WndProc(T,Hw,WM_CREATE,0,LongInt(T^.CsSeg) Shl 16 Or T^.CsOfs);
      If (GL(3) And $10000000)<>0 Then Begin
       T^.Wn[Hw].Shown:=True;
       W16GetClient(T,Hw,X1,Y1,X2,Y2);
       W16WndProc(T,Hw,WM_SIZE,0,LongInt(X2+1) Or (LongInt(Y2+1) Shl 16));
      End;
     End;
    End;
  42: Begin SetSig('ww');Hw:=GW(1);W:=W16HostOf(T,Hw);
     If (W<>Nil) And (T^.Wn[Hw].Host=W) Then Begin
      Case GW(2) Of
       2,6,7: MinimizeWin(W);
       3: MaximizeWin(W);
       1,4,5,9,10: If W^.State=1 Then RestoreWin(W);
      End;
      Dirty:=True;
     End;
     If (Hw>=1) And (Hw<=MAXW16W) And T^.Wn[Hw].Used And (GW(2)<>0) And Not T^.Wn[Hw].Shown Then Begin
      T^.Wn[Hw].Shown:=True;
      W16GetClient(T,Hw,X1,Y1,X2,Y2);
      W16WndProc(T,Hw,WM_SIZE,0,LongInt(X2+1) Or (LongInt(Y2+1) Shl 16));
     End;
     RetW(1);End;
  47: Begin SetSig('w');Hw:=GW(1);RetW(Ord((Hw>=1) And (Hw<=MAXW16W) And T^.Wn[Hw].Used));End;
  51: Begin SetSig('w');RetW(0);End;
  52: Begin SetSig('');RetW(0);End;
  53: Begin SetSig('w');W16DestroyWin(T,GW(1));RetW(1);End;
  56: Begin SetSig('wwwwww');Hw:=GW(1);W:=W16HostOf(T,Hw);If TraceOn Then WriteLn(TraceF,'MOVEWIN hw=',Hw,' ',GI(2),',',GI(3),' ',GI(4),'x',GI(5));
     If (W<>Nil) And (T^.Wn[Hw].Host=W) Then Begin W^.X:=GI(2);W^.Y:=GI(3);W^.W:=Max2(80,GI(4));W^.H:=Max2(60,GI(5));Dirty:=True;End
     Else If (Hw>=1) And (Hw<=MAXW16W) Then Begin
      Nl:=(T^.Wn[Hw].W<>GI(4)) Or (T^.Wn[Hw].H<>GI(5));
      Wr:=(T^.Wn[Hw].X<>GI(2)) Or (T^.Wn[Hw].Y<>GI(3));
      T^.Wn[Hw].X:=GI(2);T^.Wn[Hw].Y:=GI(3);T^.Wn[Hw].W:=GI(4);T^.Wn[Hw].H:=GI(5);Dirty:=True;
      If T^.Wn[Hw].Vis And (T^.Wn[Hw].PSeg<>0) And (T^.Wn[Hw].Kind=WK_OTHER) Then Begin
       If Wr Then W16WndProc(T,Hw,WM_MOVE,0,LongInt(GI(2) And $FFFF) Or (LongInt(GI(3) And $FFFF) Shl 16));
       If Nl Then Begin
        W16GetClient(T,Hw,X1,Y1,X2,Y2);
        W16WndProc(T,Hw,WM_SIZE,0,LongInt(X2+1) Or (LongInt(Y2+1) Shl 16));
       End;
      End;
     End;
     RetW(1);End;
  57: Begin SetSig('p');RetW(W16Register(T,GPS(1),GPO(1)));End;
  60: Begin SetSig('');W:=ActiveWin;If (W<>Nil) And (W^.App=A_W16) And (W^.Data=T) Then RetW(W^.Param) Else RetW(0);End;
  61: Begin SetSig('wwwpp');Dirty:=True;RetW(1);End;
  62: Begin SetSig('wwww');Hw:=GW(1);W:=W16HostOf(T,Hw);                  { SetScrollPos }
     If (Hw>=1) And (Hw<=MAXW16W) And (T^.Wn[Hw].Parent<>0) Then Begin
      If (GW(2)=1) Or (T^.Wn[Hw].Kind=WK_SCROLL) Then Begin RetW(T^.Wn[Hw].VPos);T^.Wn[Hw].VPos:=GI(3);End Else Begin RetW(T^.Wn[Hw].HPos);T^.Wn[Hw].HPos:=GI(3);End;
      If GW(4)<>0 Then Dirty:=True;
     End Else If (W<>Nil) Then Begin
      If GW(2)=1 Then Begin RetW(T^.Wn[Hw].VPos);T^.Wn[Hw].VPos:=GI(3);W^.VPos:=Clamp(GI(3)-T^.Wn[Hw].VMin,0,Max2(0,W^.VTot-W^.VPage));End
      Else Begin RetW(T^.Wn[Hw].HPos);T^.Wn[Hw].HPos:=GI(3);W^.HPos:=Clamp(GI(3)-T^.Wn[Hw].HMin,0,Max2(0,W^.HTot-W^.HPage));End;
      If GW(4)<>0 Then Dirty:=True;
     End Else RetW(0);End;
  63: Begin SetSig('ww');Hw:=GW(1);If (Hw>=1) And (Hw<=MAXW16W) Then Begin If (GW(2)=1) Or (T^.Wn[Hw].Kind=WK_SCROLL) Then RetW(T^.Wn[Hw].VPos) Else RetW(T^.Wn[Hw].HPos);End Else RetW(0);End;
  64: Begin SetSig('wwwww');Hw:=GW(1);W:=W16HostOf(T,Hw);               { SetScrollRange }
     If (Hw>=1) And (Hw<=MAXW16W) And (T^.Wn[Hw].Parent<>0) Then Begin
      If (GW(2)=1) Or (T^.Wn[Hw].Kind=WK_SCROLL) Then Begin T^.Wn[Hw].VMin:=GI(3);T^.Wn[Hw].VMax:=GI(4);End Else Begin T^.Wn[Hw].HMin:=GI(3);T^.Wn[Hw].HMax:=GI(4);End;
      Dirty:=True;
     End Else If W<>Nil Then Begin
      If GW(2)=1 Then Begin T^.Wn[Hw].VMin:=GI(3);T^.Wn[Hw].VMax:=GI(4);
       W^.VTot:=Max2(1,GI(4)-GI(3)+1);W^.VPage:=1;W^.VPos:=Clamp(T^.Wn[Hw].VPos-GI(3),0,Max2(0,W^.VTot-1));W^.HasVS:=(GI(4)>GI(3)) Or W^.HasVS;End
      Else Begin T^.Wn[Hw].HMin:=GI(3);T^.Wn[Hw].HMax:=GI(4);
       W^.HTot:=Max2(1,GI(4)-GI(3)+1);W^.HPage:=1;W^.HPos:=Clamp(T^.Wn[Hw].HPos-GI(3),0,Max2(0,W^.HTot-1));W^.HasHS:=(GI(4)>GI(3)) Or W^.HasHS;End;
      Dirty:=True;
     End;
     RetW(1);End;
  65: Begin SetSig('wwpp');Hw:=GW(1);
     If (Hw>=1) And (Hw<=MAXW16W) Then Begin
      If (GW(2)=1) Or (T^.Wn[Hw].Kind=WK_SCROLL) Then Begin WrW(Lin(GPS(3),GPO(3)),T^.Wn[Hw].VMin);WrW(Lin(GPS(4),GPO(4)),T^.Wn[Hw].VMax);End
      Else Begin WrW(Lin(GPS(3),GPO(3)),T^.Wn[Hw].HMin);WrW(Lin(GPS(4),GPO(4)),T^.Wn[Hw].HMax);End;
     End;RetW(0);End;
  66,67: Begin SetSig('w');Hw:=GW(1);H:=W16DcNew(T,1,Hw);D:=DcIdx(T,H);
     If D>0 Then T^.Dc[D].Paint:=T^.Painting;RetW(H);End;
  68: Begin SetSig('ww');D:=DcIdx(T,GW(2));If D>0 Then Begin DcEnd(T,D);T^.Dc[D].Used:=False;End;RetW(1);End;
  69: Begin SetSig('w');RetW(0);End;
  71: Begin SetSig('w');RetW(1);End;
  72: Begin SetSig('pwwww');A:=Lin(GPS(1),GPO(1));WrW(A,GW(2));WrW(A+2,GW(3));WrW(A+4,GW(4));WrW(A+6,GW(5));RetW(1);End;
  74: Begin SetSig('pp');For I:=0 To 7 Do WrB(Lin(GPS(1),GPO(1)+I),RdB(Lin(GPS(2),GPO(2)+I)));RetW(1);End;
  75: Begin SetSig('p');A:=Lin(GPS(1),GPO(1));RetW(Ord((RdI(GPS(1),GPO(1)+4)<=RdI(GPS(1),GPO(1))) Or (RdI(GPS(1),GPO(1)+6)<=RdI(GPS(1),GPO(1)+2))));End;
  76: Begin SetSig('pl');A:=Lin(GPS(1),GPO(1));L:=GL(2);
     X:=SmallInt(L And $FFFF);Y:=SmallInt((L Shr 16) And $FFFF);
     RetW(Ord((X>=RdI(GPS(1),GPO(1))) And (X<RdI(GPS(1),GPO(1)+4)) And (Y>=RdI(GPS(1),GPO(1)+2)) And (Y<RdI(GPS(1),GPO(1)+6))));End;
  77: Begin SetSig('pww');A:=Lin(GPS(1),GPO(1));
     WrW(A,RdW(A)+GW(2));WrW(A+2,RdW(A+2)+GW(3));WrW(A+4,RdW(A+4)+GW(2));WrW(A+6,RdW(A+6)+GW(3));RetW(1);End;
  78: Begin SetSig('pww');A:=Lin(GPS(1),GPO(1));
     WrW(A,RdW(A)-GW(2));WrW(A+2,RdW(A+2)-GW(3));WrW(A+4,RdW(A+4)+GW(2));WrW(A+6,RdW(A+6)+GW(3));RetW(1);End;
  79: Begin SetSig('ppp');                                             { IntersectRect }
     X:=Max2(RdI(GPS(2),GPO(2)),RdI(GPS(3),GPO(3)));Y:=Max2(RdI(GPS(2),GPO(2)+2),RdI(GPS(3),GPO(3)+2));
     X2:=Min2(RdI(GPS(2),GPO(2)+4),RdI(GPS(3),GPO(3)+4));Y2:=Min2(RdI(GPS(2),GPO(2)+6),RdI(GPS(3),GPO(3)+6));
     If (X2>X) And (Y2>Y) Then Begin A:=Lin(GPS(1),GPO(1));WrW(A,X);WrW(A+2,Y);WrW(A+4,X2);WrW(A+6,Y2);RetW(1);End
     Else Begin A:=Lin(GPS(1),GPO(1));WrW(A,0);WrW(A+2,0);WrW(A+4,0);WrW(A+6,0);RetW(0);End;End;
  81: Begin SetSig('wpw');D:=DcIdx(T,GW(1));                           { FillRect }
     If (D>0) And DcBegin(T,D) Then Begin
      Old_:=T^.Dc[D].Brush;
      If GW(3)<$20 Then T^.Dc[D].Brush:=$20+0 Else T^.Dc[D].Brush:=GW(3);
      If (GW(3)>=1) And (GW(3)<=30) Then Begin
       Case GW(3)-1 Of 0: T^.Dc[D].Brush:=$21;4,5: T^.Dc[D].Brush:=$20;1: T^.Dc[D].Brush:=$20+2;Else T^.Dc[D].Brush:=$20;End;
      End;
      DcFillBrush(T,D,RdI(GPS(2),GPO(2)),RdI(GPS(2),GPO(2)+2),RdI(GPS(2),GPO(2)+4)-1,RdI(GPS(2),GPO(2)+6)-1);
      T^.Dc[D].Brush:=Old_;DcEnd(T,D);
     End;
     RetW(1);End;
  82: Begin SetSig('wp');D:=DcIdx(T,GW(1));                            { InvertRect }
     If (D>0) And DcBegin(T,D) Then Begin
      Old_:=T^.Dc[D].Rop2;
      For Y:=RdI(GPS(2),GPO(2)+2) To RdI(GPS(2),GPO(2)+6)-1 Do
       For X:=RdI(GPS(2),GPO(2)) To RdI(GPS(2),GPO(2)+4)-1 Do Begin
        C:=DcGet(T,D,X,Y,Nl);DcPix(T,D,X,Y,C Xor 15);
       End;
      DcEnd(T,D);
     End;RetW(1);End;
  83: Begin SetSig('wpw');D:=DcIdx(T,GW(1));                           { FrameRect }
     If (D>0) And DcBegin(T,D) Then Begin
      C:=cBlk;
      DcLine(T,D,RdI(GPS(2),GPO(2)),RdI(GPS(2),GPO(2)+2),RdI(GPS(2),GPO(2)+4)-1,RdI(GPS(2),GPO(2)+2),C);
      DcLine(T,D,RdI(GPS(2),GPO(2)+4)-1,RdI(GPS(2),GPO(2)+2),RdI(GPS(2),GPO(2)+4)-1,RdI(GPS(2),GPO(2)+6)-1,C);
      DcLine(T,D,RdI(GPS(2),GPO(2)+4)-1,RdI(GPS(2),GPO(2)+6)-1,RdI(GPS(2),GPO(2)),RdI(GPS(2),GPO(2)+6)-1,C);
      DcLine(T,D,RdI(GPS(2),GPO(2)),RdI(GPS(2),GPO(2)+6)-1,RdI(GPS(2),GPO(2)),RdI(GPS(2),GPO(2)+2),C);
      DcEnd(T,D);
     End;RetW(1);End;
  85: Begin SetSig('wpwpw');D:=DcIdx(T,GW(1));                          { DrawText }
     S:='';N:=GI(3);
     If N<0 Then S:=GStr(2) Else For I:=0 To N-1 Do S:=S+Chr(RdB(Lin(GPS(2),GPO(2)+I)));
     X:=RdI(GPS(4),GPO(4));Y:=RdI(GPS(4),GPO(4)+2);X2:=RdI(GPS(4),GPO(4)+4);Y2:=RdI(GPS(4),GPO(4)+6);
     Fmt:=GW(5);Ys:=Y;
     { decoupage en lignes }
     Lm:=S;
     If ((Fmt And $20)<>0) Or (Pos(#13,S)=0) And ((Fmt And $10)=0) Then Begin
      If (D>0) And ((Fmt And $400)=0) And DcBegin(T,D) Then Begin
       If (Fmt And 1)<>0 Then X:=(X+X2-Length(S)*8) Div 2;
       If (Fmt And 2)<>0 Then X:=X2-Length(S)*8;
       If (Fmt And 4)<>0 Then Ys:=(Y+Y2-8) Div 2;
       If (Fmt And 8)<>0 Then Ys:=Y2-9;
       DcText(T,D,X,Ys,S);DcEnd(T,D);
      End;
      RetW(9);
     End Else Begin
      N:=0;
      While Lm<>'' Do Begin
       P:=Pos(#13,Lm);
       If P>0 Then Begin Ln:=Copy(Lm,1,P-1);Delete(Lm,1,P);If (Lm<>'') And (Lm[1]=#10) Then Delete(Lm,1,1);End Else Begin Ln:=Lm;Lm:='';End;
       While (Ln<>'') Do Begin
        K:=(X2-X) Div 8;If (K<1) Or ((Fmt And $10)=0) Then K:=Length(Ln);
        If Length(Ln)>K Then Begin
         P:=K;While (P>1) And (Ln[P]<>' ') Do Dec(P);
         If P<=1 Then P:=K;
         S:=Copy(Ln,1,P);Delete(Ln,1,P);While (Ln<>'') And (Ln[1]=' ') Do Delete(Ln,1,1);
        End Else Begin S:=Ln;Ln:='';End;
        If (D>0) And ((Fmt And $400)=0) And DcBegin(T,D) Then Begin
         DcText(T,D,IfThen_((Fmt And 1)<>0,(X+X2-Length(S)*8) Div 2,X),Y+N*10,S);DcEnd(T,D);
        End;
        Inc(N);
       End;
      End;
      RetW(N*10);
     End;
    End;
  87: Begin SetSig('wpwp');                                              { DialogBox }
     K:=W16FindRes(T,GPS(2),GPO(2),0,5);
     If K=0 Then RetW($FFFF) Else RetW(W16DialogBox(T,K,GPS(4),GPO(4)));
     AT:=T;
    End;
  88: Begin SetSig('ww');RetW(Ord(W16DlgEnd(T,GW(1),GI(2))));End;
  89: Begin SetSig('wpwp');K:=W16FindRes(T,GPS(2),GPO(2),0,5);
     If K=0 Then RetW(0) Else RetW(W16CreateDialog(T,K,GPS(4),GPO(4)));AT:=T;End;
  90: Begin SetSig('wp');RetW(0);End;
  91: Begin SetSig('ww');RetW(0);
     If DlgOf(T,GW(1),Rt) Then Begin K:=DlgCtlIdx(Rt,GW(2));If K>0 Then RetW($8000+K);End;End;
  92: Begin SetSig('wwp');
     If DlgOf(T,GW(1),Rt) Then Begin K:=DlgCtlIdx(Rt,GW(2));
      If K>0 Then Begin W16CtlMsg(T,Rt,K,WM_SETTEXT,0,LongInt(GPS(3)) Shl 16 Or GPO(3));End;End;RetW(0);End;
  93: Begin SetSig('wwpw');RetW(0);
     If DlgOf(T,GW(1),Rt) Then Begin K:=DlgCtlIdx(Rt,GW(2));
      If K>0 Then Begin W16PutStr(GPS(3),GPO(3),Rt^.D.C[K].Txt,GW(4));RetW(Min2(GW(4)-1,Length(Rt^.D.C[K].Txt)));End;End;End;
  94: Begin SetSig('wwww');
     If DlgOf(T,GW(1),Rt) Then Begin K:=DlgCtlIdx(Rt,GW(2));
      If K>0 Then Begin If GW(4)<>0 Then Rt^.D.C[K].Txt:=IntStr(GI(3)) Else Rt^.D.C[K].Txt:=IntStr(GW(3));
       Rt^.D.C[K].Val:=Length(Rt^.D.C[K].Txt);Rt^.Redraw:=True;End;End;RetW(0);End;
  95: Begin SetSig('wwpw');RetW(0);
     If DlgOf(T,GW(1),Rt) Then Begin K:=DlgCtlIdx(Rt,GW(2));
      If K>0 Then Begin L:=StrVal(Rt^.D.C[K].Txt,0);
       If GPS(3)<>0 Then WrW(Lin(GPS(3),GPO(3)),Ord(Trim(Rt^.D.C[K].Txt)<>''));RetW(L And $FFFF);End;End;End;
  96: Begin SetSig('wwww');
     If DlgOf(T,GW(1),Rt) Then Begin
      For K:=1 To Rt^.D.N Do If (Rt^.D.C[K].Kind=C_RADIO) And (Rt^.D.C[K].Id>=GW(2)) And (Rt^.D.C[K].Id<=GW(3)) Then
       Rt^.D.C[K].Val:=Ord(Rt^.D.C[K].Id=GW(4));
      Rt^.Redraw:=True;End;RetW(0);End;
  97: Begin SetSig('www');
     If DlgOf(T,GW(1),Rt) Then Begin K:=DlgCtlIdx(Rt,GW(2));If K>0 Then Begin Rt^.D.C[K].Val:=IfThen_(GW(3)<>0,1,0);Rt^.Redraw:=True;End;End;RetW(0);End;
  98: Begin SetSig('ww');RetW(0);
     If DlgOf(T,GW(1),Rt) Then Begin K:=DlgCtlIdx(Rt,GW(2));If K>0 Then RetW(Rt^.D.C[K].Val);End;End;
  99: Begin SetSig('wpw');RetW(0);                                        { DlgDirSelect }
     If DlgOf(T,GW(1),Rt) Then Begin K:=DlgCtlIdx(Rt,GW(3));
      If (K>0) And (Rt^.D.C[K].Lst<>Nil) And (Rt^.D.C[K].Val>0) Then Begin
       S:=Rt^.D.C[K].Lst^.S[Rt^.D.C[K].Val];
       If (Length(S)>1) And (S[1]='[') Then Begin
        S:=Copy(S,2,Length(S)-2);
        If (Length(S)=3) And (S[1]='-') Then S:=S[2]+':' Else S:=S+'\';
        RetW(1);
       End;
       W16PutStr(GPS(2),GPO(2),S,40);
      End;End;End;
  100: Begin SetSig('wpwww');                                               { DlgDirList }
     If DlgOf(T,GW(1),Rt) Then W16DirList(T,Rt,GPS(2),GPO(2),GW(3),GW(4),GW(5));RetW(1);End;
  101: Begin SetSig('wwwwl');RetL(0);                                        { SendDlgItemMessage }
     If DlgOf(T,GW(1),Rt) Then Begin K:=DlgCtlIdx(Rt,GW(2));If K>0 Then RetL(W16CtlMsg(T,Rt,K,GW(3),GW(4),GL(5)));End;End;
  104: Begin SetSig('w');Beep;RetW(0);End;
  105: Begin SetSig('ww');RetW(0);End;
  106: Begin SetSig('w');
     Case GW(1) Of $10: RetW(IfThen_(T^.Shift,$8000,0));$11: RetW(IfThen_(T^.Ctrl,$8000,0));Else RetW(0);End;End;
  107: Begin SetSig('wwwl');RetL(W16DefProc(T,GW(1),GW(2),GW(3),GL(4)));End;
  108: Begin SetSig('pwww');                                                { GetMessage }
     If W16NextMsg(T,Msg_,True) Then Begin
      W16FillMsg(T,Msg_,GPS(1),GPO(1));
      If Msg_.Msg=WM_QUIT Then RetW(0) Else RetW(1);
     End Else CpuBlock:=True;
    End;
  109: Begin SetSig('pwwww');
     If W16NextMsg(T,Msg_,(GW(5) And 1)<>0) Then Begin W16FillMsg(T,Msg_,GPS(1),GPO(1));RetW(1);End Else RetW(0);End;
  110: Begin SetSig('wwwl');W16Post(T,GW(1),GW(2),GW(3),GL(4));RetW(1);End;
  111: Begin SetSig('wwwl');
     If (GW(1)>=$8000) Or ((GW(1)>=1) And (GW(1)<=MAXW16W)) Then RetL(SendTo(GW(1),GW(2),GW(3),GL(4))) Else RetL(0);
    End;
  113: Begin SetSig('p');                                                   { TranslateMessage }
     A:=Lin(GPS(1),GPO(1));
     If RdW(A+2)=WM_KEYDOWN Then Begin
      N:=RdW(A+14);
      If (N>=1) And (N<256) Then Begin
       Msg_.Hw:=RdW(A);
       W16Post(T,RdW(A),WM_CHAR,N,0);
      End;
     End;
     RetW(1);End;
  114: Begin SetSig('p');                                                   { DispatchMessage }
     A:=Lin(GPS(1),GPO(1));Hw:=RdW(A);
     L:=LongInt(RdW(A+6))+(LongInt(RdW(A+8)) Shl 16);
     If (RdW(A+2)=WM_TIMER) And (L<>0) Then Begin
      Ps_:=(L Shr 16) And $FFFF;Po_:=L And $FFFF;
      RetL(W16CallFar(Ps_,Po_,[Hw,WM_TIMER,RdW(A+4),0,0],5));
     End Else If (Hw>=1) And (Hw<=MAXW16W) Then RetL(SendTo(Hw,RdW(A+2),RdW(A+4),L)) Else RetL(0);
    End;
  122: Begin SetSig('pwwwl');                                               { CallWindowProc }
     If (GPS(1)=ROMSEG) And (GPO(1)=$400+HDL_EDITPROC) Then RetL(W16EditProc(T,GW(2),GW(3),GW(4),GL(5)))
     Else If (GPS(1)=ROMSEG) Then RetL(W16DefProc(T,GW(2),GW(3),GW(4),GL(5)))
     Else RetL(W16CallFar(GPS(1),GPO(1),[GW(2),GW(3),GW(4),(GL(5) Shr 16) And $FFFF,GL(5) And $FFFF],5));
     AT:=T;
    End;
  124: Begin SetSig('w');Dirty:=True;RetW(1);End;
  125: Begin SetSig('wpw');Dirty:=True;RetW(1);End;
  127: Begin SetSig('wp');RetW(1);End;
  133: Begin SetSig('ww');Hw:=GW(1);N:=GI(2);
     If (Hw>=1) And (Hw<=MAXW16W) And (N>=0) And (N<32) Then RetW(T^.Wn[Hw].Extra[N Div 4] And $FFFF) Else RetW(0);End;
  134: Begin SetSig('www');Hw:=GW(1);N:=GI(2);
     If (Hw>=1) And (Hw<=MAXW16W) And (N>=0) And (N<32) Then T^.Wn[Hw].Extra[N Div 4]:=GW(3);RetW(0);End;
  135: Begin SetSig('ww');Hw:=GW(1);N:=GI(2);
     If (Hw>=1) And (Hw<=MAXW16W) Then Begin
      If N=-4 Then Begin
       If T^.Wn[Hw].PSeg=ROMSEG Then RetL(LongInt(ROMSEG) Shl 16 Or (T^.Wn[Hw].POfs))
       Else RetL(LongInt(T^.Wn[Hw].PSeg) Shl 16 Or T^.Wn[Hw].POfs);
      End Else If N=-12 Then RetL(T^.Wn[Hw].Id)
      Else If (N>=0) And (N<32) Then RetL(T^.Wn[Hw].Extra[N Div 4]) Else RetL(0);
     End Else RetL(0);End;
  136: Begin SetSig('wwl');Hw:=GW(1);N:=GI(2);
     If (Hw>=1) And (Hw<=MAXW16W) Then Begin
      If N=-4 Then Begin
       RetL(LongInt(T^.Wn[Hw].PSeg) Shl 16 Or T^.Wn[Hw].POfs);
       T^.Wn[Hw].PSeg:=(GL(3) Shr 16) And $FFFF;T^.Wn[Hw].POfs:=GL(3) And $FFFF;
      End Else If (N>=0) And (N<32) Then Begin RetL(T^.Wn[Hw].Extra[N Div 4]);T^.Wn[Hw].Extra[N Div 4]:=GL(3);End
      Else RetL(0);
     End Else RetL(0);End;
  137: Begin SetSig('w');T^.ClipOpen:=True;RetW(1);End;
  138: Begin SetSig('');T^.ClipOpen:=False;RetW(1);End;
  139: Begin SetSig('');ClipClear;RetW(1);End;
  140: Begin SetSig('');RetW(0);End;
  141: Begin SetSig('ww');Fmt:=GW(1);H:=GW(2);                                 { SetClipboardData }
     If Fmt=1 Then Begin
      I:=0;While (I<CLIPMAX-1) And (RdB(Lin(H,I))<>0) Do Begin ClipTxt[I]:=Chr(RdB(Lin(H,I)));Inc(I);End;
      ClipLen:=I;ClipKind:=1;
     End Else If Fmt=2 Then Begin
      Ob:=ObjOf(T,H);
      If Ob>0 Then Begin
       If ClipBmp<>Nil Then FreeMem(ClipBmp,LongInt(ClipBmpW)*ClipBmpH);
       ClipBmpW:=T^.Ob[Ob].BW;ClipBmpH:=T^.Ob[Ob].BH;
       GetMem(ClipBmp,LongInt(ClipBmpW)*ClipBmpH);
       For I:=0 To ClipBmpW*ClipBmpH-1 Do
        If T^.Ob[Ob].Mono Then PByteArr_(ClipBmp)^[I]:=1-T^.Ob[Ob].Bmp^[I] Else PByteArr_(ClipBmp)^[I]:=Ord(T^.Ob[Ob].Bmp^[I]<>15);
       ClipKind:=2;
      End;
     End;
     RetW(H);End;
  142: Begin SetSig('w');Fmt:=GW(1);H:=0;                                      { GetClipboardData }
     If (Fmt=1) And (ClipKind=1) Then Begin
      Par:=(ClipLen+17) Div 16;H:=ArenaAlloc(T^.V,Par,T^.V^.PSP);
      If H<>0 Then Begin For I:=0 To ClipLen-1 Do WrB(Lin(H,I),Ord(ClipTxt[I]));WrB(Lin(H,ClipLen),0);End;
     End Else If (Fmt=2) And (ClipKind=2) And (ClipBmp<>Nil) Then Begin
      H:=W16BmpNew(T,ClipBmpW,ClipBmpH,True);
      If H<>0 Then For I:=0 To ClipBmpW*ClipBmpH-1 Do T^.Ob[H-$100].Bmp^[I]:=1-PByteArr_(ClipBmp)^[I];
     End;
     RetW(H);End;
  143: Begin SetSig('');RetW(IfThen_(ClipKind<>0,1,0));End;
  144: Begin SetSig('w');If (GW(1)=0) And (ClipKind<>0) Then RetW(ClipKind) Else RetW(0);End;
  146: Begin SetSig('wpw');RetW(0);End;
  147: Begin SetSig('w');RetW(T^.ViewHw);T^.ViewHw:=GW(1);T^.ClipSig:=W16ClipSig;End;
  148: Begin SetSig('');RetW(T^.ViewHw);End;
  149: Begin SetSig('ww');If T^.ViewHw=GW(1) Then T^.ViewHw:=0;RetW(0);End;
  150: Begin SetSig('wp');RetW(W16MenuLoad(T,GPS(2),GPO(2)));End;
  153: Begin SetSig('wwpww');W16ChangeMenu(T,GW(1),GI(2),GPS(3),GPO(3),GI(4),GW(5));RetW(1);End;
  154,155: Begin SetSig('www');                                                { Check/EnableMenuItem }
     If MenuSetOf(T,GW(1),Ms_,Nm_,Pop_,Hw0_) Then Begin
      If O=154 Then MnuFlagsById(Ms_,Nm_,GI(2),(GW(3) And $400)<>0,Pop_,2,(GW(3) And 8)<>0,R)
      Else MnuFlagsById(Ms_,Nm_,GI(2),(GW(3) And $400)<>0,Pop_,1,(GW(3) And 3)<>0,R);
      RetW(R);
     End Else RetW($FFFF);
     Dirty:=True;
    End;
  156: Begin SetSig('ww');If GW(2)=0 Then RetW($7000+GW(1)*32+31) Else RetW(0);End;
  157: Begin SetSig('w');If W16HostOf(T,GW(1))<>Nil Then RetW($7000+GW(1)*32) Else RetW(0);End;
  158: Begin SetSig('ww');W16ApplyMenu(T,GW(1),GW(2));RetW(1);End;
  160: Begin SetSig('w');Dirty:=True;RetW(1);End;
  162: Begin SetSig('wwww');RetW(1);End;
  163: Begin SetSig('wwww');T^.CaretHw:=GW(1);T^.CaretW:=GI(3);T^.CaretH:=GI(4);T^.CaretOn:=False;RetW(1);End;
  164: Begin SetSig('');T^.CaretHw:=0;T^.CaretOn:=False;RetW(1);End;
  165: Begin SetSig('ww');T^.CaretX:=GI(1);T^.CaretY:=GI(2);RetW(1);End;
  166: Begin SetSig('w');T^.CaretOn:=False;RetW(1);End;
  167: Begin SetSig('w');T^.CaretOn:=True;RetW(1);End;
  173,174: Begin SetSig('wp');RetW($200+O);End;
  175: Begin SetSig('wp');
     If (GPS(2)=0) And (GPO(2)>=$7F00) Then Begin RetW(W16SysBitmap(T,GPO(2)));Exit;End;
     K:=W16FindRes(T,GPS(2),GPO(2),0,2);
     If K=0 Then RetW(0) Else RetW(W16LoadBitmapRes(T,K));End;
  176: Begin SetSig('wwpw');If TraceOn Then WriteLn(TraceF,'LOADSTRING id=',GW(2),' buf=',HexStr(GPS(3),4),':',HexStr(GPO(3),4),' max=',GW(4),' SS=',HexStr(Sg[SG_SS],4),' SP=',HexStr(Rg[R_SP],4));If W16LoadStr(T,GW(2),S) Then Begin W16PutStr(GPS(3),GPO(3),S,GW(4));RetW(Min2(Length(S),GW(4)-1));End
     Else Begin If GW(4)>0 Then WrB(Lin(GPS(3),GPO(3)),0);RetW(0);End;End;
  177: Begin SetSig('wp');K:=W16FindRes(T,GPS(2),GPO(2),0,9);If K=0 Then RetW(0) Else RetW(W16LoadRes(T,K));End;
  178: Begin SetSig('wwp');RetW(W16Accel(T,GW(1),GW(2),GPS(3),GPO(3)));End;
  179: Begin SetSig('w');
     Case GW(1) Of
      0,16: RetW(SCR_W);1: RetW(SCR_H);17: RetW(SCR_H-TITLE_H-MENU_H);2,3,20,21: RetW(16);4: RetW(TITLE_H);5,6: RetW(1);7,8: RetW(4);
      9,10: RetW(16);11,12,13,14: RetW(32);15: RetW(MENU_H);19: RetW(1);28,29: RetW(80);32,33: RetW(BorderW);
     Else RetW(0);End;
    End;
  180: Begin SetSig('w');
     Case GW(1) Of
      0: C:=cLGr;1: C:=ColDesk;2: C:=ColActive;3: C:=ColInactive;4: C:=ColMenuBg;5: C:=ColWinBg;6: C:=ColBorder;
      7: C:=ColMenuText;8: C:=ColWinText;9: C:=cWht;Else C:=cLGr;End;
     RetL(VgaRGB[C,0]+VgaRGB[C,1]*256+LongInt(VgaRGB[C,2])*65536);
    End;
  190: Begin SetSig('wpw');W16GetClient(T,GW(1),X1,Y1,X2,Y2);
     If GPS(2)<>0 Then Begin WrW(Lin(GPS(2),GPO(2)),0);WrW(Lin(GPS(2),GPO(2)+2),0);WrW(Lin(GPS(2),GPO(2)+4),X2+1);WrW(Lin(GPS(2),GPO(2)+6),Y2+1);End;
     RetW(1);End;
  193: Begin SetSig('w');RetW(Ord(((GW(1)=1) And (ClipKind=1)) Or ((GW(1)=2) And (ClipKind=2))));End;
  200: Begin SetSig('pww');RetW($FFFE);End;
  201: Begin SetSig('p');RetW($FFFF);End;
  202: Begin SetSig('wp');RetW($FFFF);End;
  203: Begin SetSig('wp');RetW(0);End;
  205: Begin SetSig('wpw');RetW($FFFF);End;
  207: Begin SetSig('w');RetW(0);End;
  215: Begin SetSig('ww');RetW(0);End;
  14: Begin SetSig('');RetL(55000);End;                    { GetTimerResolution }
  24,25: Begin SetSig('wp');S:=GStr(2);                    { RemoveProp / GetProp }
     If (GPS(2)=0) Then S:='#'+IntStr(GPO(2));
     R:=0;
     For I:=1 To 32 Do If (PropTab[I].Nm<>'') And (PropTab[I].Hw=GW(1)) And (PropTab[I].Nm=S) Then Begin
      R:=PropTab[I].V;If O=24 Then PropTab[I].Nm:='';Break;End;
     RetW(R);End;
  26: Begin SetSig('wpw');S:=GStr(2);                      { SetProp }
     If (GPS(2)=0) Then S:='#'+IntStr(GPO(2));
     K:=0;
     For I:=1 To 32 Do If (PropTab[I].Nm=S) And (PropTab[I].Hw=GW(1)) Then K:=I;
     If K=0 Then For I:=1 To 32 Do If PropTab[I].Nm='' Then Begin K:=I;Break;End;
     If K>0 Then Begin PropTab[K].Hw:=GW(1);PropTab[K].Nm:=Copy(S,1,30);PropTab[K].V:=GW(3);End;
     RetW(1);End;
  29: Begin SetSig('wp');                                  { ScreenToClient }
     If W16ClientOrg(T,GW(1),X1,Y1,Rx2,Ry2,X,Y) Then Begin
      WrW(Lin(GPS(2),GPO(2)),RdI(GPS(2),GPO(2))-X1);WrW(Lin(GPS(2),GPO(2)+2),RdI(GPS(2),GPO(2)+2)-Y1);End;
     RetW(1);End;
  43: Begin SetSig('w');W:=W16HostOf(T,GW(1));If W<>Nil Then Begin MinimizeWin(W);Dirty:=True;End;RetW(1);End;
  44: Begin SetSig('w');W:=W16HostOf(T,GW(1));If W<>Nil Then Begin RestoreWin(W);Dirty:=True;End;RetW(1);End;
  45: Begin SetSig('w');W:=W16HostOf(T,GW(1));If W<>Nil Then Begin BringToFront(W);Dirty:=True;End;RetW(1);End;
  46: Begin SetSig('w');Hw:=GW(1);If (Hw>=1) And (Hw<=MAXW16W) Then RetW(T^.Wn[Hw].Parent) Else RetW(0);End;
  48: Begin SetSig('ww');RetW(Ord(W16IsDesc(T,GW(2),GW(1))));End;
  49: Begin SetSig('w');Hw:=GW(1);RetW(Ord((Hw>=1) And (Hw<=MAXW16W) And T^.Wn[Hw].Used And T^.Wn[Hw].Vis));End;
  50: Begin SetSig('pp');S:=Upper(GStr(1));S2:=GStr(2);R:=0; { FindWindow }
     For I:=1 To MAXW16W Do If T^.Wn[I].Used And (T^.Wn[I].Parent=0) Then
      If ((GPS(1)=0) Or (T^.Cl[T^.Wn[I].Cls].Name=S)) And ((GPS(2)=0) Or (T^.Wn[I].Title=S2)) Then Begin R:=I;Break;End;
     RetW(R);End;
  54,55: Begin                                              { EnumWindows / EnumChildWindows }
     If O=54 Then Begin SetSig('pl');Par:=0;Ps_:=GPS(1);Po_:=GPO(1);L:=GL(2);End
     Else Begin SetSig('wpl');Par:=GW(1);Ps_:=GPS(2);Po_:=GPO(2);L:=GL(3);End;
     R:=1;
     For I:=1 To MAXW16W Do
      If T^.Wn[I].Used And ((O=54) And (T^.Wn[I].Parent=0) Or (O=55) And W16IsDesc(T,I,Par)) Then Begin
       Ar5[0]:=I;Ar5[1]:=(L Shr 16) And $FFFF;Ar5[2]:=L And $FFFF;
       AT:=T;
       If (W16CallFar(Ps_,Po_,Ar5,3) And $FFFF)=0 Then Begin R:=0;Break;End;
       AT:=T;
      End;
     RetW(R);End;
  58: Begin SetSig('wpw');Hw:=GW(1);                       { GetClassName }
     If (Hw>=1) And (Hw<=MAXW16W) And T^.Wn[Hw].Used Then Begin
      S:=T^.Cl[T^.Wn[Hw].Cls].Name;W16PutStr(GPS(2),GPO(2),S,GW(3));RetW(Min2(Length(S),GW(3)-1));End Else RetW(0);End;
  59: Begin SetSig('w');W:=W16HostOf(T,GW(1));If W<>Nil Then Begin BringToFront(W);Dirty:=True;End;RetW(0);End;
  70: Begin SetSig('ww');MX:=GI(1);MY:=GI(2);RetW(0);End;
  73: Begin SetSig('p');A:=Lin(GPS(1),GPO(1));WrW(A,0);WrW(A+2,0);WrW(A+4,0);WrW(A+6,0);RetW(1);End;
  80: Begin SetSig('ppp');A:=Lin(GPS(1),GPO(1));            { UnionRect }
     X:=RdI(GPS(2),GPO(2));Y:=RdI(GPS(2),GPO(2)+2);X2:=RdI(GPS(2),GPO(2)+4);Y2:=RdI(GPS(2),GPO(2)+6);
     X1:=RdI(GPS(3),GPO(3));Y1:=RdI(GPS(3),GPO(3)+2);Rx2:=RdI(GPS(3),GPO(3)+4);Ry2:=RdI(GPS(3),GPO(3)+6);
     If (X2<=X) Or (Y2<=Y) Then Begin X:=X1;Y:=Y1;X2:=Rx2;Y2:=Ry2;End
     Else If (Rx2>X1) And (Ry2>Y1) Then Begin X:=Min2(X,X1);Y:=Min2(Y,Y1);X2:=Max2(X2,Rx2);Y2:=Max2(Y2,Ry2);End;
     WrW(A,X);WrW(A+2,Y);WrW(A+4,X2);WrW(A+6,Y2);RetW(Ord((X2>X) And (Y2>Y)));End;
  84: Begin SetSig('wwww');RetW(1);End;                    { DrawIcon }
  86: Begin SetSig('');RetL($00200020);End;                { IconSize }
  151: Begin SetSig('');                                   { CreateMenu }
     K:=0;For I:=1 To MAXW16MT Do If T^.MTpl[I]=Nil Then Begin K:=I;Break;End;
     If K=0 Then RetW(0) Else Begin
      New(T^.MTpl[K]);FillChar(T^.MTpl[K]^,SizeOf(TW16MenuTpl),0);
      MnuAddPopup(@T^.MTpl[K]^.Menus,@T^.MTpl[K]^.NMenu,'');
      RetW($7C00+K);End;End;
  152: Begin SetSig('w');K:=GW(1)-$7C00;                   { DestroyMenu }
     If (K>=1) And (K<=MAXW16MT) And (T^.MTpl[K]<>Nil) Then Begin Dispose(T^.MTpl[K]);T^.MTpl[K]:=Nil;End;RetW(1);End;
  159: Begin SetSig('ww');H:=GW(1);                        { GetSubMenu }
     If (H>=$7000) And (H<$7C00) Then RetW($7000+((H-$7000) Div 32)*32+GW(2)+1) Else RetW(H);End;
  161: Begin SetSig('wwpww');                              { GetMenuString }
     R:=0;
     If MenuSetOf(T,GW(1),Ms_,Nm_,Pop_,Hw0_) Then Begin
      If Pop_=0 Then Pop_:=1;
      For I:=1 To Ms_^[Pop_].N Do If Ms_^[Pop_].It[I].Cmd=GI(2) Then Begin
       S:=Ms_^[Pop_].It[I].Txt;While Pos('&',S)>0 Do Delete(S,Pos('&',S),1);W16PutStr(GPS(3),GPO(3),S,GW(4));R:=Min2(Length(S),GW(4)-1);Break;End;
     End;
     RetW(R);End;
  168: Begin SetSig('w');RetW(1);End;                      { SetCaretBlinkTime }
  169: Begin SetSig('');RetW(500);End;                     { GetCaretBlinkTime }
  181: Begin SetSig('wpp');RetW(1);End;                    { SetSysColors }
  191: Begin SetSig('wl');RetW(GW(1));End;                 { ChildWindowFromPoint }
  192: Begin SetSig('');RetW(0);End;                        { InSendMessage }
  204: Begin SetSig('wpw');RetW(0);End;                    { ReadComm }
  206: Begin SetSig('ww');RetW(0);End;
  208: Begin SetSig('ww');RetL(0);End;
  209: Begin SetSig('ww');RetW(0);End;
  210,211: Begin SetSig('w');RetW(0);End;
  212: Begin SetSig('ww');RetW(0);End;
  213: Begin SetSig('pp');RetW(0);End;
  214: Begin SetSig('ww');RetL(0);End;
 Else W16Trap(T,3,O);
 End;
End;

{ ---------------- API : KEYBOARD ---------------- }

Procedure W16Kbd(T: PW16; O: Integer);
Var S: String;
Begin
 Case O Of
  5,6: Begin SetSig('pp');S:=GStr(1);W16PutStr(GPS(2),GPO(2),S,255);RetW(Length(S));End;
 Else W16Trap(T,4,O);
 End;
End;

{ Point d'entree des appels importes : N = offset-$400 }
Procedure HleW16(N: Integer);
Var Md,O: Integer; T: PW16;
Begin
 T:=CurW16;
 AT:=T;
 If T=Nil Then Begin CpuHalt:=True;CpuErr:='Windows API call without a Windows task';Exit;End;
 T^.NoRet:=False;
 If N=HDL_EDITPROC Then Begin
  SetSig('wwwl');RetL(W16EditProc(T,GW(1),GW(2),GW(3),GL(4)));
  W16ReturnFar(T^.ArgBytes);Exit;
 End;
 If N=HDL_DEFPROC Then Begin
  SetSig('wwwl');RetL(W16DefProc(T,GW(1),GW(2),GW(3),GL(4)));
  W16ReturnFar(T^.ArgBytes);Exit;
 End;
 If N>=4095 Then Begin W16Trap(T,0,0);CpuBlock:=True;Exit;End;
 Md:=N Div 1024+1;O:=N Mod 1024;
 SetSig('');Inc(TrApi);
 If TraceOn Then WriteLn(TraceF,'W16 mod=',Md,' ord=',O,' SP=',HexStr(Rg[R_SP],4),' ret=',HexStr(RdW(Lin(Sg[SG_SS],Rg[R_SP]+2)),4),':',HexStr(RdW(Lin(Sg[SG_SS],Rg[R_SP])),4),' args=',HexStr(RdW(Lin(Sg[SG_SS],Rg[R_SP]+4)),4),' ',HexStr(RdW(Lin(Sg[SG_SS],Rg[R_SP]+6)),4),' ',HexStr(RdW(Lin(Sg[SG_SS],Rg[R_SP]+8)),4),' ',HexStr(RdW(Lin(Sg[SG_SS],Rg[R_SP]+10)),4));
 Case Md Of
  1: W16Kernel(T,O);
  2: W16Gdi(T,O);
  3: W16User(T,O);
  4: W16Kbd(T,O);
 End;
 If TraceOn Then Begin WriteLn(TraceF,'   -> AX=',HexStr(Rg[R_AX],4),' DX=',HexStr(Rg[R_DX],4),' blk=',Ord(CpuBlock));Flush(TraceF);End;
 If T^.Done Then Begin CpuBlock:=True;Exit;End;
 If T^.NoRet Then Begin T^.NoRet:=False;Exit;End;
 If Not CpuBlock Then W16ReturnFar(T^.ArgBytes);
End;

{ ---------------- gestion de la tache ---------------- }

Procedure W16Pump;
Var I: Integer; T: PW16; V: PVM; Msg: String; K: Integer;
Begin
 I:=1;
 While I<=NW16 Do Begin
  T:=W16List[I];V:=T^.V;
  CurW16:=T;AT:=T;
  If (Not T^.Done) And V^.Running Then Begin
   VMRun(V,60000);
   AT:=T;
  End;
  If T^.Done Or Not V^.Running Then Begin
   If (T^.Err='') And (LastCpuErr<>'') Then Begin T^.Err:=LastCpuErr;LastCpuErr:='';End;
   Msg:=BaseName(T^.Exe);
   If T^.Err<>'' Then Msg:=Msg+'|'+T^.Err;
   W16Terminate(T);
   VMDestroy(V);
   Dispose(T);
   For K:=I To NW16-1 Do W16List[K]:=W16List[K+1];
   Dec(NW16);
   Dirty:=True;
   If Pos('|',Msg)>0 Then InfoBox(Msg);
  End Else Begin
   If (T^.ViewHw<>0) And (W16ClipSig<>T^.ClipSig) Then Begin T^.ClipSig:=W16ClipSig;W16Post(T,T^.ViewHw,$308,0,0);End;
   If T^.CaretOn And ((NowCs Div BlinkHalf)<>T^.LastTick) Then Begin T^.LastTick:=NowCs Div BlinkHalf;Dirty:=True;End;
   Inc(I);
  End;
 End;
End;

Procedure W16DrawIconProc(S,X,Y,Sz: Integer);
Begin
 W16DrawIconRes(CurW16,S,X,Y,Sz);
End;

Procedure Win16Start(Const VPath,Tail: String);
Var T: PW16; V: PVM; Err: String;
Begin
 If NW16>=4 Then Begin InfoBox(T3('Too many Windows tasks.','Trop de t'#226'ches Windows.','Zu viele Windows-Tasks.'));Exit;End;
 New(T);FillChar(T^,SizeOf(TW16),0);
 V:=VMCreate(Nil);T^.V:=V;V^.W16:=T;T^.Exe:=VPath;
 VMEnter(V);
 CurW16:=T;AT:=T;
 W16RegBuiltins(T);
 Err:=W16Load(T,VPath);
 If Err<>'' Then Begin
  VMLeave(V);VMDestroy(V);Dispose(T);
  InfoBox(BaseName(VPath)+'|'+Err);Exit;
 End;
 If Tail<>'' Then Begin
  WrB(Lin($0800,$80),Min2(Length(Tail)+1,126));WrB(Lin($0800,$81),32);
  W16PutStr($0800,$82,Tail,125);
  WrB(Lin($0800,$82+Length(Tail)),13);
 End;
 ExtIconOn:=True;ExtIconDraw:=@W16DrawIconProc;
 V^.Running:=True;
 VMLeave(V);
 Inc(NW16);W16List[NW16]:=T;
End;

{ ---------------- fenetres hotes (A_W16) ---------------- }

Procedure W16HostCall(T: PW16; Hw,Msg,Wp: Word; Lp: LongInt);
Var Sv,SvAT: PW16; V: PVM;
Begin
 V:=T^.V;
 If Not V^.Running Then Exit;
 Sv:=CurW16;SvAT:=AT;
 VMEnter(V);
 CurW16:=T;AT:=T;
 W16Send(T,Hw,Msg,Wp,Lp);
 VMLeave(V);
 CurW16:=Sv;AT:=SvAT;
End;

Procedure W16FillBk(T: PW16; Cl: Integer; X1,Y1,X2,Y2: Integer);
Var C,K,I,Cy: Integer;
Begin
 C:=T^.Cl[Cl].Brush;
 If C=0 Then Exit;
 If C<=30 Then Begin
  Case C-1 Of 0: GBar(X1,Y1,X2,Y2,cLGr);1: GBar(X1,Y1,X2,Y2,ColDesk);Else GBar(X1,Y1,X2,Y2,cWht);End;
 End Else Begin
  K:=ObjOf(T,C);
  If K>0 Then Begin
   If T^.Ob[K].Style=3 Then Begin
    For I:=Y1 To Y2 Do For Cy:=X1 To X2 Do
     If ((T^.Ob[K].Pat[I And 7] Shr (7-(Cy And 7))) And 1)=1 Then GPix(Cy,I,cWht) Else GPix(Cy,I,cBlk);
   End Else If T^.Ob[K].Style<>1 Then GBar(X1,Y1,X2,Y2,W16Col(T^.Ob[K].Color));
  End Else If (C>=$20) And (C<=$24) Then GBar(X1,Y1,X2,Y2,IfThen_(C=$24,cBlk,IfThen_(C=$20,cWht,cLGr)));
 End;
End;

{ rectangle externe absolu d'une fenetre enfant }
Function W16OuterRect(T: PW16; Hw: Word; Var X1,Y1,X2,Y2: Integer): Boolean;
Var Px,Py,A1,B1,A2,B2: Integer;
Begin
 W16OuterRect:=False;
 If T^.Wn[Hw].Parent=0 Then Exit;
 If Not W16ClientOrg(T,T^.Wn[Hw].Parent,Px,Py,A1,B1,A2,B2) Then Exit;
 X1:=Px+T^.Wn[Hw].X;Y1:=Py+T^.Wn[Hw].Y;
 X2:=X1+T^.Wn[Hw].W-1;Y2:=Y1+T^.Wn[Hw].H-1;
 W16OuterRect:=True;
End;

Procedure W16HostDraw(W: PWindow);
Var T: PW16; Hw: Word; V: PVM; X1,Y1,X2,Y2: Integer; C,I,K: Integer; Sv: PW16; Rt: PDlgRt; E: PEd;
    Cx,Cy,Ox,Oy,Q1,Q2,Q3,Q4: Integer; Bd: Boolean;
Begin
 T:=W^.Data;
 If T=Nil Then Exit;
 Hw:=W^.Param;
 If (Hw<1) Or (Hw>MAXW16W) Or Not T^.Wn[Hw].Used Then Exit;
 V:=T^.V;
 WinClient(W,X1,Y1,X2,Y2);
 { fenetre de dialogue sans modale }
 If (T^.Wn[Hw].Kind=WK_DLG) And (T^.Wn[Hw].Dlg<>Nil) Then Begin
  Rt:=PDlgRt(T^.Wn[Hw].Dlg);
  Rt^.D.X:=X1-FR+2;Rt^.D.Y:=Y1-FR+2;
  GBar(X1,Y1,X2,Y2,cWht);
  For I:=1 To Rt^.D.N Do If Rt^.D.C[I].Kind<>C_CUSTOM Then DrawCtl(Rt^.D,I);
  Exit;
 End;
 W16FillBk(T,T^.Wn[Hw].Cls,X1,Y1,X2,Y2);
 If Not V^.Running Then Exit;
 Sv:=CurW16;
 VMEnter(V);
 CurW16:=T;AT:=T;
 T^.Painting:=True;
 W16WndProc(T,Hw,WM_PAINT,0,0);
 { fenetres enfants personnalisees (ordre de creation) }
 For I:=1 To MAXW16W Do
  If T^.Wn[I].Used And T^.Wn[I].Vis And (T^.Wn[I].Parent<>0) And (T^.Wn[I].Kind=WK_OTHER) And
     (T^.Wn[I].PSeg<>0) And W16IsDesc(T,I,Hw) And W16OuterRect(T,I,Q1,Q2,Q3,Q4) And W16ClientOrg(T,I,Ox,Oy,Cx,Cy,K,C) Then Begin
   SetClip(Max2(X1,Q1),Max2(Y1,Q2),Min2(X2,Q3),Min2(Y2,Q4));
   Bd:=(T^.Wn[I].Style And $00800000)<>0;
   If Bd Then GRect(Q1,Q2,Q3,Q4,cBlk);
   If (T^.Wn[I].Style And $00200000)<>0 Then
    DrawScroll(True,Q3-SB-IfThen_(Bd,1,0)+1,Q2+IfThen_(Bd,1,0),Q3-IfThen_(Bd,1,0),Q4-IfThen_(Bd,1,0),
      Max2(1,T^.Wn[I].VMax-T^.Wn[I].VMin+1),1,Clamp(T^.Wn[I].VPos-T^.Wn[I].VMin,0,Max2(0,T^.Wn[I].VMax-T^.Wn[I].VMin)));
   If (T^.Wn[I].Style And $00100000)<>0 Then
    DrawScroll(False,Q1+IfThen_(Bd,1,0),Q4-SB-IfThen_(Bd,1,0)+1,Q3-IfThen_(Bd,1,0)-IfThen_((T^.Wn[I].Style And $00200000)<>0,SB,0),Q4-IfThen_(Bd,1,0),
      Max2(1,T^.Wn[I].HMax-T^.Wn[I].HMin+1),1,Clamp(T^.Wn[I].HPos-T^.Wn[I].HMin,0,Max2(0,T^.Wn[I].HMax-T^.Wn[I].HMin)));
   SetClip(Cx,Cy,K,C);
   W16FillBk(T,T^.Wn[I].Cls,Cx,Cy,K,C);
   W16WndProc(T,I,WM_PAINT,0,0);
  End;
 { barres de defilement (controles) }
 For I:=1 To MAXW16W Do
  If T^.Wn[I].Used And T^.Wn[I].Vis And (T^.Wn[I].Kind=WK_SCROLL) And W16IsDesc(T,I,Hw) And W16OuterRect(T,I,Q1,Q2,Q3,Q4) And
     (Q3>Q1) And (Q4>Q2) Then Begin
   SetClip(Max2(X1,Q1),Max2(Y1,Q2),Min2(X2,Q3),Min2(Y2,Q4));
   If (T^.Wn[I].Style And 8)<>0 Then GBar(Q1,Q2,Q3,Q4,cLGr)
   Else DrawScroll((T^.Wn[I].Style And 1)<>0,Q1,Q2,Q3,Q4,Max2(1,T^.Wn[I].VMax-T^.Wn[I].VMin+1),1,Clamp(T^.Wn[I].VPos-T^.Wn[I].VMin,0,Max2(0,T^.Wn[I].VMax-T^.Wn[I].VMin)));
  End;
 T^.Painting:=False;
 VMLeave(V);
 CurW16:=Sv;
 SetClip(X1,Y1,X2,Y2);
 { controles EDIT enfants }
 For I:=1 To MAXW16W Do
  If T^.Wn[I].Used And T^.Wn[I].Vis And (T^.Wn[I].Kind=WK_EDIT) And (T^.Wn[I].Ed<>Nil) And W16IsDesc(T,I,Hw) And
     W16OuterRect(T,I,Q1,Q2,Q3,Q4) And W16ClientOrg(T,T^.Wn[I].Parent,Ox,Oy,Cx,Cy,K,C) Then Begin
   E:=T^.Wn[I].Ed;
   SetClip(Max2(X1,Cx),Max2(Y1,Cy),Min2(X2,K),Min2(Y2,C));
   If (Q3>=Q1) And (Q4>=Q2) Then Begin
    GBar(Q1,Q2,Q3,Q4,cWht);
    GRect(Q1,Q2,Q3,Q4,cBlk);
    E^.X0:=Q1+1;E^.Y0:=Q2+1;E^.PW:=T^.Wn[I].W-2;E^.PH:=T^.Wn[I].H-2;
    E^.Cols:=Max2(1,(E^.PW-8) Div 8);E^.Rows:=Max2(1,E^.PH Div 12);
    EdLayout(E);
    SetClip(Max2(Max2(X1,Cx),Q1+1),Max2(Max2(Y1,Cy),Q2+1),Min2(Min2(X2,K),Q3-1),Min2(Min2(Y2,C),Q4-1));
    EdDraw(E,0,T^.Focus=I);
   End;
   SetClip(X1,Y1,X2,Y2);
  End;
 { curseur de texte }
 If T^.CaretOn And (T^.CaretHw=Hw) And ((NowCs Div BlinkHalf) Mod 2=0) Then
  GBar(X1+T^.CaretX,Y1+T^.CaretY,X1+T^.CaretX+Max2(1,T^.CaretW)-1,Y1+T^.CaretY+Max2(1,T^.CaretH)-1,cBlk);
End;

Procedure W16HostMouse(W: PWindow; Var E: TEvent);
Var T: PW16; Hw,Tg: Word; X1,Y1,X2,Y2: Integer; Msg: Word; Lp: LongInt; I: Integer; Rt: PDlgRt; Cx,Cy: Integer;
    Q1,Q2,Q3,Q4,Bd,Ox,Oy,Tt,Pt: Integer; Vt: Boolean;
Begin
 T:=W^.Data;
 If TraceOn Then WriteLn(TraceF,'HOSTMOUSE kind=',Ord(E.Kind),' x=',E.X,' y=',E.Y);
 If T=Nil Then Exit;
 Hw:=W^.Param;
 WinClient(W,X1,Y1,X2,Y2);
 { dialogue sans modale }
 If (T^.Wn[Hw].Kind=WK_DLG) And (T^.Wn[Hw].Dlg<>Nil) Then Begin
  If E.Kind=EV_DOWN Then Begin
   Rt:=PDlgRt(T^.Wn[Hw].Dlg);
   For I:=1 To Rt^.D.N Do
    If (Rt^.D.C[I].Kind=C_BUTTON) And InBox(E.X,E.Y,CtlX(Rt^.D,I),CtlY(Rt^.D,I),CtlX(Rt^.D,I)+Rt^.D.C[I].W,CtlY(Rt^.D,I)+Rt^.D.C[I].H) Then
     W16Post(T,Hw,WM_COMMAND,Rt^.D.C[I].Id,0);
  End;
  Exit;
 End;
 Tg:=Hw;Cx:=E.X-X1;Cy:=E.Y-Y1;
 For I:=1 To MAXW16W Do
  If T^.Wn[I].Used And T^.Wn[I].Vis And (T^.Wn[I].Parent<>0) And ((T^.Wn[I].Kind=WK_EDIT) Or (T^.Wn[I].Kind=WK_OTHER) Or (T^.Wn[I].Kind=WK_SCROLL)) And
     W16IsDesc(T,I,Hw) And W16OuterRect(T,I,Q1,Q2,Q3,Q4) And InBox(E.X,E.Y,Q1,Q2,Q3,Q4) Then Begin
   Bd:=IfThen_((T^.Wn[I].Style And $00800000)<>0,1,0);
   { barre de defilement verticale d'un enfant }
   If ((T^.Wn[I].Style And $00200000)<>0) And (E.X>=Q3-SB-Bd+1) Then Begin
    If E.Kind=EV_DOWN Then Begin
     Tt:=Max2(1,T^.Wn[I].VMax-T^.Wn[I].VMin+1);
     Pt:=ScrollPart(True,Q3-SB-Bd+1,Q2+Bd,Q3-Bd,Q4-Bd,Tt,1,Clamp(T^.Wn[I].VPos-T^.Wn[I].VMin,0,Tt-1),E.X,E.Y);
     Case Pt Of
      1: W16Post(T,I,WM_VSCROLL,0,0);
      2: W16Post(T,I,WM_VSCROLL,1,0);
      3: W16Post(T,I,WM_VSCROLL,2,0);
      4: W16Post(T,I,WM_VSCROLL,3,0);
      5,0: Begin
       Pt:=ScrollDrag(True,Q3-SB-Bd+1,Q2+Bd,Q3-Bd,Q4-Bd,Tt,1,E.Y,0);
       W16Post(T,I,WM_VSCROLL,4,T^.Wn[I].VMin+Pt);
      End;
     End;
     Dirty:=True;
    End;
    Exit;
   End;
   If T^.Wn[I].Kind=WK_SCROLL Then Begin
    If E.Kind=EV_DOWN Then Begin
     Vt:=(T^.Wn[I].Style And 1)<>0;
     Tt:=Max2(1,T^.Wn[I].VMax-T^.Wn[I].VMin+1);
     Pt:=ScrollPart(Vt,Q1,Q2,Q3,Q4,Tt,1,Clamp(T^.Wn[I].VPos-T^.Wn[I].VMin,0,Tt-1),E.X,E.Y);
     Msg:=IfThen_(Vt,WM_VSCROLL,WM_HSCROLL);
     Lp:=LongInt(I) Shl 16;
     Case Pt Of
      1: W16Post(T,T^.Wn[I].Parent,Msg,0,Lp);
      2: W16Post(T,T^.Wn[I].Parent,Msg,1,Lp);
      3: W16Post(T,T^.Wn[I].Parent,Msg,2,Lp);
      4: W16Post(T,T^.Wn[I].Parent,Msg,3,Lp);
      5,0: Begin Pt:=ScrollDrag(Vt,Q1,Q2,Q3,Q4,Tt,1,IfThen_(Vt,E.Y,E.X),0);
       W16Post(T,T^.Wn[I].Parent,Msg,4,Lp Or (T^.Wn[I].VMin+Pt));End;
     End;
     Dirty:=True;
    End;
    Exit;
   End;
   If T^.Wn[I].Kind=WK_EDIT Then Begin Tg:=I;Cx:=E.X-Q1;Cy:=E.Y-Q2;End
   Else If W16ClientOrg(T,I,Ox,Oy,Q1,Q2,Q3,Q4) Then Begin Tg:=I;Cx:=E.X-Ox;Cy:=E.Y-Oy;End;
  End;
 If (E.Kind=EV_MOVE) Or (E.Kind=EV_UP) Then Begin
  If (T^.CapHw<>0) And T^.Wn[T^.CapHw].Used And (T^.Wn[T^.CapHw].Kind=WK_EDIT) And ((E.B And 1)<>0) Then Begin
   Tg:=T^.CapHw;
   If W16OuterRect(T,Tg,Q1,Q2,Q3,Q4) Then Begin Cx:=E.X-Q1;Cy:=E.Y-Q2;End;
  End;
  If E.Kind=EV_UP Then T^.CapHw:=0;
 End;
 If (E.Kind=EV_DOWN) And (T^.Wn[Tg].Kind=WK_EDIT) Then T^.CapHw:=Tg;
 Lp:=LongInt(Cx And $FFFF) Or (LongInt(Cy And $FFFF) Shl 16);
 Case E.Kind Of
  EV_DOWN: Begin Msg:=IfThen_(E.Dbl,WM_LBUTTONDBLCLK,WM_LBUTTONDOWN);Capture:=W;
     If (Tg<>Hw) And (T^.Wn[Tg].Kind=WK_EDIT) Then T^.Focus:=Tg;End;
  EV_UP: Msg:=WM_LBUTTONUP;
  EV_RDOWN: Msg:=WM_RBUTTONDOWN;
  EV_MOVE: Msg:=WM_MOUSEMOVE;
 Else Exit;
 End;
 W16Post(T,Tg,Msg,IfThen_((E.B And 1)<>0,1,0),Lp);
 Dirty:=True;
End;

Procedure W16HostKey(W: PWindow; K: Word);
Var T: PW16; Hw,Tg: Word; Vk,Ch,Md: Word; N: Integer;
Begin
 T:=W^.Data;
 If T=Nil Then Exit;
 Hw:=W^.Param;
 Tg:=Hw;
 If (T^.Focus<>0) And (T^.Wn[T^.Focus].Used) And W16IsDesc(T,T^.Focus,Hw) Then Tg:=T^.Focus;
 Vk:=K;Ch:=0;Md:=0;
 If (K>=1) And (K<=26) And (K<>8) And (K<>9) And (K<>13) Then Begin
  { Ctrl+lettre : C/V/X -> Ctrl+Inser / Maj+Inser / Maj+Suppr }
  Md:=2;Vk:=64+K;
  Case K Of 3: Begin Vk:=$2D;End;22: Begin Vk:=$2D;Md:=1;End;24: Begin Vk:=$2E;Md:=1;End;End;
 End Else If (K>=32) And (K<256) Then Begin
  Ch:=K;Vk:=K;
  If (K>=97) And (K<=122) Then Vk:=K-32;
 End Else Begin
  Case K Of
   K_LEFT: Vk:=$25; K_UP: Vk:=$26; K_RIGHT: Vk:=$27; K_DOWN: Vk:=$28;
   K_HOME: Vk:=$24; K_END: Vk:=$23; K_PGUP: Vk:=$21; K_PGDN: Vk:=$22;
   K_INS: Vk:=$2D; K_DEL: Vk:=$2E; K_ENTER: Begin Vk:=$0D;Ch:=13;End;
   K_ESC: Begin Vk:=$1B;Ch:=27;End; K_BKSP: Begin Vk:=8;Ch:=8;End; K_TAB: Begin Vk:=9;Ch:=9;End;
   402: Begin Vk:=$2D;Md:=2;End;
  Else If K>=256 Then Vk:=K-256-59+$70;
  End;
 End;
 N:=(T^.QT+1) Mod MAXW16Q;
 If N<>T^.QH Then Begin
  T^.Q[T^.QT].Hw:=Tg;T^.Q[T^.QT].Msg:=WM_KEYDOWN;T^.Q[T^.QT].Wp:=Vk;T^.Q[T^.QT].Lp:=0;
  T^.Q[T^.QT].Tm:=NowCs*10;T^.Q[T^.QT].Px:=Ch;T^.Q[T^.QT].Py:=Md;
  T^.QT:=N;
 End;
 W16Post(T,Tg,WM_KEYUP,Vk,0);
End;

Function W16HostCanClose(W: PWindow): Boolean;
Var T: PW16; Hw: Word;
Begin
 T:=W^.Data;
 W16HostCanClose:=T=Nil;
 If T=Nil Then Exit;
 Hw:=W^.Param;
 If T^.Wn[Hw].Kind=WK_DLG Then W16Post(T,Hw,WM_COMMAND,2,0) Else W16Post(T,Hw,WM_CLOSE,0,0);
End;

Procedure W16HostClose(W: PWindow);
Begin
 W^.Data:=Nil;
End;

Procedure W16HostResize(W: PWindow);
Var T: PW16; Hw: Word; X1,Y1,X2,Y2: Integer;
Begin
 T:=W^.Data;
 If T=Nil Then Exit;
 Hw:=W^.Param;
 WinClient(W,X1,Y1,X2,Y2);
 W16Post(T,Hw,WM_SIZE,IfThen_(W^.State=2,2,IfThen_(W^.State=1,1,0)),LongInt(X2-X1+1) Or (LongInt(Y2-Y1+1) Shl 16));
End;

Procedure W16HostMenu(W: PWindow; Cmd: Integer);
Var T: PW16;
Begin
 T:=W^.Data;
 If T=Nil Then Exit;
 W16Post(T,W^.Param,WM_COMMAND,Word(Cmd),0);
End;

Procedure W16HostPrepare(W: PWindow);
Var T: PW16;
Begin
 T:=W^.Data;
 If T=Nil Then Exit;
 W16HostCall(T,W^.Param,WM_INITMENU,$7000+W^.Param*32,0);
End;

Procedure W16HostScroll(W: PWindow; Vert: Boolean; Part: Integer; Pos: LongInt);
Var T: PW16; Code: Word; Hw: Word; Mn: Integer;
Begin
 T:=W^.Data;
 If T=Nil Then Exit;
 Hw:=W^.Param;
 Case Part Of 1: Code:=0;2: Code:=1;3: Code:=2;4: Code:=3;Else Code:=4;End;
 If Vert Then Mn:=T^.Wn[Hw].VMin Else Mn:=T^.Wn[Hw].HMin;
 W16Post(T,Hw,IfThen_(Vert,WM_VSCROLL,WM_HSCROLL),Code,LongInt((Pos+Mn) And $FFFF));
End;

{$ELSE}

Procedure W16Pump;
Begin
End;

{$ENDIF}

{ ====================================================================== }
{                 REPARTITION DES TRAITEMENTS PAR APPLICATION            }
{ ====================================================================== }

Procedure AppDraw(W: PWindow);
Begin
 Case W^.App Of
  A_EXEC: ExecDraw(W);
  A_NOTE,A_WRITE: EdWinDraw(W);
  A_CALC: CalcDraw(W);
  A_CLOCK: ClockDraw(W);
  A_CLIP: ClipDraw(W);
  A_SPOOL: SpoolDraw(W);
  A_REV: RevDraw(W);
  A_CTRL: CpDraw(W);
  A_PIF: PifDraw(W);
  A_TERM: TermDraw(W);
  A_CARD: CardDraw(W);
  A_CALEN: CalDraw(W);
  A_PAINT: PaintDraw(W);
  {$IFDEF FPC}A_DOSBOX: DosDraw(W);{$ENDIF}
  {$IFDEF FPC}A_W16: W16HostDraw(W);{$ENDIF}
 End;
End;

Procedure AppMouse(W: PWindow; Var E: TEvent);
Begin
 Case W^.App Of
  A_EXEC: ExecMouse(W,E);
  A_NOTE,A_WRITE: EdWinMouse(W,E);
  A_CALC: CalcMouse(W,E);
  A_SPOOL: SpoolMouse(W,E);
  A_CTRL: CpMouseMain(W,E);
  A_REV: RevMouse(W,E);
  A_PIF: PifMouse(W,E);
  A_CARD: CardMouse(W,E);
  A_CALEN: CalMouse(W,E);
  A_PAINT: PaintMouse(W,E);
  {$IFDEF FPC}A_DOSBOX: DosMouse(W,E);{$ENDIF}
  {$IFDEF FPC}A_W16: W16HostMouse(W,E);{$ENDIF}
 End;
End;

Procedure AppKey(W: PWindow; K: Word);
Begin
 Case W^.App Of
  A_EXEC: ExecKey(W,K);
  A_NOTE,A_WRITE: EdWinKey(W,K);
  A_CALC: CalcKey(W,K);
  A_TERM: TermKey(W,K);
  A_CTRL: CpKeyMain(W,K);
  A_SPOOL: SpoolKey(W,K);
  A_CARD: CardKey(W,K);
  A_CALEN: CalKey(W,K);
  A_PAINT: PaintKey(W,K);
  {$IFDEF FPC}A_DOSBOX: DosKey(W,K);{$ENDIF}
  {$IFDEF FPC}A_W16: W16HostKey(W,K);{$ENDIF}
 End;
End;

Procedure AppMenu(W: PWindow; Cmd: Integer);
Var R: Integer;
Begin
 Case W^.App Of
  A_EXEC: ExecMenu(W,Cmd);
  A_NOTE,A_WRITE: R:=Ord(EdWinMenu(W,Cmd));
  A_CALC: CalcMenu(W,Cmd);
  A_CLOCK: ClockMenu(W,Cmd);
  A_CLIP: ClipMenu(W,Cmd);
  A_SPOOL: SpoolMenu(W,Cmd);
  A_REV: RevMenu(W,Cmd);
  A_CTRL: CpMenu(W,Cmd);
  A_PIF: PifMenu(W,Cmd);
  A_TERM: TermMenu(W,Cmd);
  A_CARD: CardMenu(W,Cmd);
  A_CALEN: CalMenu(W,Cmd);
  A_PAINT: PaintMenu(W,Cmd);
  {$IFDEF FPC}A_DOSBOX: DosMenu(W,Cmd);{$ENDIF}
  {$IFDEF FPC}A_W16: W16HostMenu(W,Cmd);{$ENDIF}
 End;
End;

Procedure AppClose(W: PWindow);
Begin
 Case W^.App Of
  A_EXEC: ExecClose(W);
  A_NOTE,A_WRITE: EdWinClose(W);
  A_CALC: Dispose(PCalc(W^.Data));
  A_CLOCK: Dispose(PClock(W^.Data));
  A_REV: Dispose(PRev(W^.Data));
  A_PIF: Dispose(PPif(W^.Data));
  A_TERM: Dispose(PTerm(W^.Data));
  A_CARD: CardClose(W);
  A_CALEN: Dispose(PCal(W^.Data));
  A_PAINT: PaintClose(W);
  {$IFDEF FPC}A_DOSBOX: DosClose(W);{$ENDIF}
  {$IFDEF FPC}A_W16: W16HostClose(W);{$ENDIF}
 End;
End;

Procedure AppTimer(W: PWindow);
Begin
 Case W^.App Of
  A_NOTE,A_WRITE: EdWinTimer(W);
  A_CLOCK: ClockTimer(W);
  A_SPOOL: SpoolTimer(W);
  A_CTRL: CpTimerMain(W);
  A_REV: RevTimer(W);
  A_TERM: TermTimer(W);
  A_CALEN: CalTimer(W);
  {$IFDEF FPC}A_DOSBOX: DosTimer(W);{$ENDIF}
 End;
End;

Procedure AppPrepare(W: PWindow);
Begin
 Case W^.App Of
  A_EXEC: ExecPrepare(W);
  A_NOTE,A_WRITE: EdWinPrepare(W);
  A_SPOOL: SpoolPrepare(W);
  A_REV: RevPrepare(W);
  A_CTRL: CpPrepare(W);
  A_TERM: TermPrepare(W);
  A_CARD: CardPrepare(W);
  A_CALEN: CalPrepare(W);
  A_PAINT: PaintPrepare(W);
  {$IFDEF FPC}A_W16: W16HostPrepare(W);{$ENDIF}
 End;
End;

Procedure AppResize(W: PWindow);
Begin
 Case W^.App Of
  A_EXEC: ExecResize(W);
  {$IFDEF FPC}A_W16: W16HostResize(W);{$ENDIF}
 End;
End;

Procedure AppDrawIcon(W: PWindow; X,Y: Integer);
Var H,M,S: Integer;
Begin
 Case W^.App Of
  A_CLOCK: Begin GetNow(H,M,S);DrawClockFace(X+16,Y+16,15,H,M,S,True);End;
  A_NOTE: Begin GBar(X+4,Y,X+27,Y+31,cWht);GRect(X+4,Y,X+27,Y+31,cBlk);
     GHLine(X+8,X+23,Y+6,cBlk);GHLine(X+8,X+23,Y+12,cBlk);GHLine(X+8,X+23,Y+18,cBlk);End;
  A_CALC: Begin GBar(X+4,Y,X+27,Y+31,cLBl);GRect(X+4,Y,X+27,Y+31,cBlk);GBar(X+7,Y+3,X+24,Y+9,cWht);
     GBar(X+8,Y+13,X+12,Y+17,cWht);GBar(X+14,Y+13,X+18,Y+17,cWht);GBar(X+20,Y+13,X+24,Y+17,cWht);
     GBar(X+8,Y+21,X+12,Y+25,cWht);GBar(X+14,Y+21,X+18,Y+25,cWht);GBar(X+20,Y+21,X+24,Y+25,cWht);End;
  A_REV: Begin GBar(X,Y,X+31,Y+31,cLGn);GRect(X,Y,X+31,Y+31,cBlk);
     GFillEllipse(X+10,Y+10,6,6,cLRd);GFillEllipse(X+22,Y+22,6,6,cLBl);End;
  A_WRITE: Begin GBar(X+4,Y,X+27,Y+31,cWht);GRect(X+4,Y,X+27,Y+31,cBlk);
     GText(X+10,Y+10,'W',cBlk);End;
  A_SPOOL: Begin GBar(X+2,Y+8,X+29,Y+24,cLGr);GRect(X+2,Y+8,X+29,Y+24,cBlk);GBar(X+8,Y,X+23,Y+10,cWht);GRect(X+8,Y,X+23,Y+10,cBlk);End;
 Else DrawIconFloppy(X,Y);
 End;
End;

Procedure AppScroll(W: PWindow; Vert: Boolean; Part: Integer; Pos: LongInt);
Begin
 {$IFDEF FPC}
 If W^.App=A_W16 Then Begin W16HostScroll(W,Vert,Part,Pos);Exit;End;
 {$ENDIF}
 If Vert Then W^.VPos:=Pos Else W^.HPos:=Pos;
End;

Procedure AppSysItems(W: PWindow);
Procedure AddIt(Const T: String; C: Integer);
Begin
 If SysDef.N>=MAXITEM Then Exit;
 Inc(SysDef.N);SysDef.It[SysDef.N].Txt:=T;SysDef.It[SysDef.N].Cmd:=C;SysDef.It[SysDef.N].Flag:=0;SysDef.It[SysDef.N].Key:='';
End;
Begin
 {$IFDEF FPC}
 If W^.App=A_DOSBOX Then Begin
  AddIt('-',0);
  AddIt('Mar&k~Mar&quer~Mar&kieren',CM_M_MARK);
  AddIt('Cop&y~Cop&ier~&Kopieren',CM_M_COPY);
  AddIt('Pa&ste~Co&ller~&Einf'#129'gen',CM_M_PASTE);
  AddIt('Scro&ll~D'#130'fi&ler~&Rollen',CM_M_SCROLL);
 End;
 If W^.App=A_W16 Then W16AddSysItems(W);
 {$ENDIF}
End;

Procedure AppSysCmd(W: PWindow; Cmd: Integer);
Begin
 {$IFDEF FPC}
 If W^.App=A_W16 Then W16SysCommand(W,Cmd);
 If W^.App=A_DOSBOX Then DosMenu(W,Cmd);
 {$ENDIF}
End;

Function AskSaveGeneric(W: PWindow; Modified: Boolean; Const FN: String; SaveCmd: Integer): Boolean;
Var R: Integer;
Begin
 AskSaveGeneric:=True;
 If Not Modified Then Exit;
 R:=MsgBox(T3('Save changes to ','Enregistrer les modifications de ','Anderungen speichern in ')+
   IfThenS(FN='',T3('(untitled)','(sans titre)','(unbenannt)'),BaseName(FN))+'?',3,2);
 If R=ID_CANCEL Then Begin AskSaveGeneric:=False;Exit;End;
 If R=ID_YES Then Begin
  AppMenu(W,SaveCmd);
 End;
End;

Function AppCanClose(W: PWindow): Boolean;
Begin
 AppCanClose:=True;
 Case W^.App Of
  A_NOTE,A_WRITE: AppCanClose:=EdAskSave(W);
  A_CARD: AppCanClose:=AskSaveGeneric(W,PCardF(W^.Data)^.Modified,PCardF(W^.Data)^.FileName,CM_D_SAVE);
  A_CALEN: AppCanClose:=AskSaveGeneric(W,PCal(W^.Data)^.Modified,PCal(W^.Data)^.FileName,CM_L_SAVE);
  A_PAINT: AppCanClose:=AskSaveGeneric(W,PPaint(W^.Data)^.Modified,PPaint(W^.Data)^.FileName,CM_G_SAVE);
  A_PIF: AppCanClose:=AskSaveGeneric(W,PPif(W^.Data)^.Modified,PPif(W^.Data)^.FileName,CM_F_SAVE);
  A_EXEC: If CountApp(A_EXEC)<=1 Then Begin AppCanClose:=False;ExecEndSession;End;
  {$IFDEF FPC}A_W16: AppCanClose:=W16HostCanClose(W);{$ENDIF}
 End;
End;

{ ====================================================================== }
{                 LANCEMENT DES APPLICATIONS ET DES FICHIERS             }
{ ====================================================================== }

Procedure DelTmpIn(Const Dir: String);
Var SR: SearchRec; F: File;
Begin
 {$I-}
 FindFirst(JoinPath(Dir,'~*.TMP'),AnyFile,SR);
 While DosError=0 Do Begin
  Assign(F,JoinPath(Dir,SR.Name));Erase(F);
  If IOResult<>0 Then ;
  FindNext(SR);
 End;
 {$IFDEF FPC}FindClose(SR);{$ENDIF}
 {$I+}
End;

Procedure ExecEndSession;
Var R,I: Integer; Tp: String; Ok: Boolean;
Begin
 R:=MsgBox(T3('This will end your Windows session.',
   'Ceci va terminer votre session Windows.',
   'Dadurch wird Ihre Windows-Sitzung beendet.'),1,2);
 If R=ID_OK Then Begin
  { propose d'enregistrer les fichiers ouverts }
  Ok:=True;
  For I:=NWins Downto 1 Do
   If (Wins[I]^.App<>A_EXEC) And (Wins[I]^.App<>A_W16) Then
    If Not AppCanClose(Wins[I]) Then Begin Ok:=False;Break;End;
  If Not Ok Then Begin Dirty:=True;Exit;End;
  QuitFlag:=True;
  { l'arret de la session supprime les fichiers temporaires }
  DelTmpIn(V2R('C:\'));
  Tp:=GetEnv('TEMP');
  If Tp<>'' Then DelTmpIn(Tp);
 End;
End;

Function Launch(App: Integer; Const Arg: String): PWindow;
Var W: PWindow;
Begin
 W:=Nil;
 Case App Of
  A_EXEC: W:=ExecCreate('C:\WINDOWS');
  A_NOTE: W:=NotepadCreate(Arg);
  A_WRITE: W:=WriteCreate(Arg);
  A_CALC: W:=CalcCreate;
  A_CLOCK: W:=ClockCreate;
  A_CLIP: W:=ClipCreate;
  A_SPOOL: W:=SpoolCreate;
  A_REV: W:=RevCreate;
  A_CTRL: W:=CtrlCreate;
  A_PIF: W:=PifCreate(Arg);
  A_TERM: W:=TermCreate;
  A_CARD: W:=CardCreate(Arg);
  A_CALEN: W:=CalCreate(Arg);
  A_PAINT: W:=PaintCreate(Arg);
  {$IFDEF FPC}
  A_DOSBOX: W:=DosCreate(Arg,True);
  {$ELSE}
  A_DOSBOX: InfoBox(T3('The DOS emulator requires the Free Pascal version.','L''emulateur DOS necessite la version Free Pascal.','Der DOS-Emulator ben'#148'tigt die Free-Pascal-Version.'));
  {$ENDIF}
 End;
 If W<>Nil Then BringToFront(W);
 Dirty:=True;
 Launch:=W;
End;

{ execution d'un fichier PIF }
Procedure RunPif(Const Path: String);
Var P: PPif; Cmd: String; W: PWindow; Pr: String;
Begin
 {$IFDEF FPC}
 New(P);FillChar(P^,SizeOf(TPif),0);PifClear(P);
 If Not PifLoad(P,Path) Then Begin
  InfoBox(T3('Cannot open '+BaseName(Path)+'.','Impossible d''ouvrir '+BaseName(Path)+'.','Kann '+BaseName(Path)+' nicht '#148'ffnen.'));
  Dispose(P);Exit;
 End;
 Pr:=Trim(P^.Prog);
 If Pr='' Then Begin InfoBox(T3('Cannot run '+BaseName(Path)+'.|No program specified.','Impossible d''ex'#130'cuter '+BaseName(Path)+'.|Aucun programme indiqu'#130'.','Kann '+BaseName(Path)+' nicht ausf'#129'hren.|Kein Programm angegeben.'));Dispose(P);Exit;End;
 If (P^.Dir<>'') And Not VDirExists(Upper(P^.Dir)) Then Begin
  InfoBox(T3('Initial directory not found.','R'#130'pertoire initial introuvable.','Anfangsverzeichnis nicht gefunden.'));Dispose(P);Exit;End;
 If P^.MemReq>600 Then Begin
  InfoBox(T3('Not enough memory to run '+BaseName(Pr)+'.','M'#130'moire insuffisante pour ex'#130'cuter '+BaseName(Pr)+'.','Nicht genug Speicher zum Ausf'#129'hren von '+BaseName(Pr)+'.'));Dispose(P);Exit;End;
 Cmd:=Pr;
 If Trim(P^.Params)<>'' Then Cmd:=Cmd+' '+Trim(P^.Params);
 DosInitDir:=Upper(P^.Dir);DosCloseExit:=P^.CloseExit;
 W:=Launch(A_DOSBOX,Cmd);
 DosInitDir:='';DosCloseExit:=False;
 If (W<>Nil) And (P^.Title<>'') Then Begin W^.Title:=P^.Title;End;
 Dispose(P);
 {$ENDIF}
End;

Procedure RunFile(Const Path,Args: String; AsIcon: Boolean);
Var I: Integer; W: PWindow;
Begin
 {$IFDEF FPC}
 If (ExtOf(Path)='.EXE') And FileExists(V2R(Path)) Then
  If IsNEFile(V2R(Path)) Then Begin Win16Start(Path,Args);Exit;End;
 {$ENDIF}
 I:=BuiltIndex(Path);
 If (I>0) And (BuiltApp[I]>0) Then Begin
  W:=Launch(BuiltApp[I],IfThenS((BuiltApp[I]=A_NOTE) Or (BuiltApp[I]=A_WRITE) Or (BuiltApp[I]=A_CARD) Or (BuiltApp[I]=A_CALEN)
     Or (BuiltApp[I]=A_PAINT) Or (BuiltApp[I]=A_PIF),Args,''));
  If (W<>Nil) And AsIcon Then MinimizeWin(W);
  Exit;
 End;
 If ExtOf(Path)='.TXT' Then Begin W:=Launch(A_NOTE,Path);If (W<>Nil) And AsIcon Then MinimizeWin(W);Exit;End;
 If ExtOf(Path)='.WRI' Then Begin W:=Launch(A_WRITE,Path);If (W<>Nil) And AsIcon Then MinimizeWin(W);Exit;End;
 If ExtOf(Path)='.PIF' Then Begin RunPif(Path);Exit;End;
 If ExtOf(Path)='.CRD' Then Begin W:=Launch(A_CARD,Path);If (W<>Nil) And AsIcon Then MinimizeWin(W);Exit;End;
 If ExtOf(Path)='.CAL' Then Begin W:=Launch(A_CALEN,Path);If (W<>Nil) And AsIcon Then MinimizeWin(W);Exit;End;
 If ExtOf(Path)='.MSP' Then Begin W:=Launch(A_PAINT,Path);If (W<>Nil) And AsIcon Then MinimizeWin(W);Exit;End;
 {$IFDEF FPC}
 If (ExtOf(Path)='.EXE') And IsNEFile(V2R(Path)) Then Begin Win16Start(Path,Args);Exit;End;
 {$ENDIF}
 If (IsProgExt(ExtOf(Path)) Or (ExtOf(Path)='.TXT') Or (ExtOf(Path)='.WRI')) And Not FileExists(V2R(Path)) And (BuiltIndex(Path)=0) Then Begin
  InfoBox(T3('Cannot find '+BaseName(Path)+'.','Impossible de trouver '+BaseName(Path)+'.',BaseName(Path)+' kann nicht gefunden werden.'));
  Exit;
 End;
 If IsProgExt(ExtOf(Path)) Then Begin
  { un fichier .PIF de meme nom regit le lancement }
  If FileExists(V2R(Copy(Path,1,Length(Path)-Length(ExtOf(Path)))+'.PIF')) Then Begin RunPif(Copy(Path,1,Length(Path)-Length(ExtOf(Path)))+'.PIF');Exit;End;
  W:=Launch(A_DOSBOX,Path+IfThenS(Args='','',' '+Args));
  If (W<>Nil) And AsIcon Then MinimizeWin(W);
  Exit;
 End;
 InfoBox(T3('This file is not an application.','Ce fichier n''est pas une application.','Diese Datei ist keine Anwendung.'));
End;

Procedure ShowAboutMs(Const AppName: String; Ico: Integer; Free: Boolean);
Var D: TDlg; R: Integer;
Begin
 DlgInit(D,'',390,IfThen_(Free,160,120));
 DlgIcon(D,22,14,Ico);
 DlgText(D,86,10,'Microsoft Windows|'+AppName+'||Version '+VERSION_TEXT+'|Copyright (c) 1987 Microsoft Corp.');
 DlgButton(D,ID_OK,155,84,80,'OK',True);
 If Free Then Begin
  DlgBox(D,0,108,390,6,'');
  DlgText(D,86,122,T3('Disk Space Free: ','Espace disque libre : ','Freier Speicherplatz: ')+
    IntStr(DiskFree(0) Div 1024)+'K');
  DlgText(D,86,136,T3('Memory Free:     ','M'#130'moire libre :     ','Freier Speicher:    ')+
    IntStr(Max2(64,426-6*NWins))+'K');
 End;
 R:=RunDialog(D,@NoHook);
End;

{ ====================================================================== }
{                      ECRAN D'ACCUEIL (SPLASH)                          }
{ ====================================================================== }

Procedure Splash;
Var T0: LongInt; E: TEvent;
Begin
 HideMouse;
 ClipFull;
 SetFillStyle(SolidFill,cBlu);
 Bar(0,0,SCR_W-1,SCR_H-1);
 DrawLogoText(96,66,'Microsoft',6,cWht,cBlu);
 { symbole marque deposee }
 GEllipse(522,100,8,8,cWht);
 GText(519,97,'R',cWht);
 GTextCtr(0,SCR_W-1,270,'Microsoft Windows',cWht);
 GTextCtr(0,SCR_W-1,284,'Version '+VERSION_TEXT,cWht);
 GTextCtr(0,SCR_W-1,440,'Copyright (c) Microsoft Corporation, 1987.  All Rights Reserved.',cWht);
 GTextCtr(0,SCR_W-1,452,'Microsoft is a registered trademark of Microsoft Corp.',cWht);
 T0:=NowCs;
 Repeat
  PollEvent(E);
 Until (E.Kind=EV_KEY) Or (E.Kind=EV_DOWN) Or (Abs(NowCs-T0)>200);
 ShowMouse;
End;

{ ====================================================================== }
{                           PROGRAMME PRINCIPAL                          }
{ ====================================================================== }

Procedure ShowHelp;
Begin
 WriteLn('WINDOWS2 - Clone de Microsoft Windows 2.03 (environnement graphique)');
 WriteLn('Version ',VERSION_TEXT);
 WriteLn;
 WriteLn('Syntaxe : WINDOWS2 [options] [fichier [parametres]]');
 WriteLn;
 WriteLn('  /?, -?, /H, --help   Affiche cette aide');
 WriteLn('  /L:langue            Force la langue (EN, FR ou GR/DE)');
 WriteLn('  /ROOT:repertoire     Repertoire correspondant a C:\ (UNIX uniquement ;');
 WriteLn('                       par defaut : le repertoire courant)');
 WriteLn('  /NOSPLASH            Pas d''ecran d''accueil (logo Microsoft)');
 WriteLn('  /R:application       Lance une application au demarrage (repetable) :');
 WriteLn('                       CALC, CALENDAR, CARDFILE, CLIPBOARD, CLOCK, CONTROL,');
 WriteLn('                       NOTEPAD, PAINT, PIFEDIT, REVERSI, SPOOLER, TERMINAL,');
 WriteLn('                       WRITE, MSDOS');
 WriteLn('  fichier              Fichier a ouvrir ou a executer :');
 WriteLn('                       .EXE/.COM/.BAT  emulateur DOS 8086 (MS-DOS Prompt)');
 WriteLn('                                       ou chargeur Windows 2.x (format NE)');
 WriteLn('                       .TXT Notepad, .WRI Write, .CRD Cardfile, .CAL Calendar,');
 WriteLn('                       .MSP Paint, .PIF PIF Editor');
 WriteLn;
 WriteLn('Variable d''environnement LANGUAGE : EN = anglais, GR (ou DE) = allemand,');
 WriteLn('toute autre valeur = francais.');
 WriteLn;
 WriteLn('Raccourcis : F10 ou Alt+lettre = menus, Alt+F4 = fermer, Alt+F7 = deplacer,');
 WriteLn('Alt+F8 = taille, Alt+F9 = reduire, Alt+F10 = agrandir, F6 = fenetre suivante,');
 WriteLn('Echap = annuler un menu ou un dialogue.');
 WriteLn;
 WriteLn('Les reglages de Control Panel sont enregistres dans le fichier WIN.INI.');
 WriteLn('Emulateur DOS et chargeur Windows 2.x : version Free Pascal seulement.');
End;

Function DetectLanguage: Integer;
Var S: String;
Begin
 S:=Upper(GetEnv('LANGUAGE'));
 If (S='EN') Or (Copy(S,1,3)='EN_') Or (Copy(S,1,3)='EN.') Then DetectLanguage:=0
 Else If (S='GR') Or (S='DE') Or (Copy(S,1,3)='DE_') Then DetectLanguage:=2
 Else DetectLanguage:=1;
End;

Var
 I,RunApp,NRun: Integer; RunList: Array[1..8] Of Integer;
 Arg,StartFile: String;
 W: PWindow;

BEGIN
 SCR_W:=640;SCR_H:=480;
 Lang:=DetectLanguage;
 StartFile:='';RunApp:=0;NRun:=0;NoSplash:=False;
 GetDir(0,HomeDir);
 BaseDir:=DirOf(ParamStr(0));
 RootDir:=HomeDir;
 {$IFNDEF UNIX}RootDir:='';{$ENDIF}
 For I:=1 To ParamCount Do Begin
  Arg:=ParamStr(I);
  If (Arg='/?') Or (Arg='-?') Or (Upper(Arg)='/H') Or (Upper(Arg)='-H') Or
     (Upper(Arg)='--HELP') Or (Upper(Arg)='/HELP') Then Begin
   ShowHelp;
   Halt(0);
  End Else If Upper(Copy(Arg,1,3))='/L:' Then Begin
   Arg:=Upper(Copy(Arg,4,10));
   If Arg='EN' Then Lang:=0 Else If (Arg='GR') Or (Arg='DE') Then Lang:=2 Else Lang:=1;
  End Else If Upper(Copy(Arg,1,6))='/ROOT:' Then Begin
   RootDir:=Copy(Arg,7,200);
   While (Length(RootDir)>1) And (RootDir[Length(RootDir)]=DirSep) Do Delete(RootDir,Length(RootDir),1);
  End Else If Upper(Arg)='/NOSPLASH' Then NoSplash:=True
  Else If Upper(Copy(Arg,1,3))='/R:' Then Begin
   Arg:=Upper(Copy(Arg,4,30));
   RunApp:=0;
   If Arg='CALC' Then RunApp:=A_CALC;
   If Arg='CALENDAR' Then RunApp:=A_CALEN;
   If Arg='CARDFILE' Then RunApp:=A_CARD;
   If (Arg='CLIPBOARD') Or (Arg='CLIPBRD') Then RunApp:=A_CLIP;
   If Arg='CLOCK' Then RunApp:=A_CLOCK;
   If (Arg='CONTROL') Or (Arg='CONTROLPANEL') Then RunApp:=A_CTRL;
   If Arg='NOTEPAD' Then RunApp:=A_NOTE;
   If Arg='PAINT' Then RunApp:=A_PAINT;
   If Arg='PIFEDIT' Then RunApp:=A_PIF;
   If Arg='REVERSI' Then RunApp:=A_REV;
   If Arg='SPOOLER' Then RunApp:=A_SPOOL;
   If Arg='TERMINAL' Then RunApp:=A_TERM;
   If Arg='WRITE' Then RunApp:=A_WRITE;
   If (Arg='MSDOS') Or (Arg='EXEC') Then RunApp:=A_EXEC;
   If (Arg='DOS') Or (Arg='COMMAND') Then RunApp:=A_DOSBOX;
   If (RunApp<>0) And (NRun<8) Then Begin Inc(NRun);RunList[NRun]:=RunApp;End;
  End Else If Arg[1]<>'/' Then StartFile:=Arg;
 End;
 BorderW:=3;DblCs:=45;LeftHand:=False;
 S1159:='AM';S2359:='PM';ListSep:=',';CurFmt:=0;NumDigits:=2;LeadZero:=False;PrnFileName:='';PrnOrient:=0;PrnPaper:=0;DevTimeout:=15;TxTimeout:=45;SpoolSrcNext:='';DrvDest:='C:\';
 DateFmt:=0;DateSep:='/';Clock24:=False;TimeSep:=':';CurSym:='$';DecSep:='.';ThouSep:=',';
 If Lang<>0 Then Begin S1159:='';S2359:='';CurFmt:=3;ListSep:=';';LeadZero:=True;DateFmt:=1;Clock24:=True;TimeSep:=':';DecSep:=',';ThouSep:=' ';CurSym:='F';End;
 If Lang=2 Then Begin DateSep:='.';CurSym:='DM';End;
 PrinterName:='Epson FX-80';PrintPort:='LPT1';
 VolNames['A']:='';VolNames['B']:='';VolNames['C']:='';VolNames['D']:='';
 NWins:=0;NextId:=1;NewWinCount:=0;Capture:=Nil;QuitFlag:=False;
 DefaultScreenColors;
 BlinkMs:=530;BlinkHalf:=26;MouseAcc:=0;Beeping:=True;NPrn:=1;PrnInst[1]:='Epson FX-80';PrnPort[1]:='LPT1';NFont:=3;
 FontInst[1]:='Courier 8,10,12 (Set #1)';FontFile[1]:='COURA.FON';FontInst[2]:='Helv 8,10,12,14,18,24 (Set #1)';FontFile[2]:='HELVA.FON';FontInst[3]:='Tms Rmn 8,10,12,14,18,24 (Set #1)';FontFile[3]:='TMSRA.FON';
 CommPort:='COM1';CommBaud:=1200;CommBits:=8;CommStop:=1;CommParity:='N';
 For I:=1 To 2 Do Begin ComSet[I].Baud:=1200;ComSet[I].Bits:=8;ComSet[I].Par:=0;ComSet[I].Stop:=0;ComSet[I].Hs:=2;End;
 CountryName:=IfThenS(Lang=0,'United States',IfThenS(Lang=2,'Germany','France'));Beeping:=True;
 IniFile:=JoinPath(IfThenS(DirExists(V2R('C:\WINDOWS')),V2R('C:\WINDOWS'),HomeDir),'WIN.INI');
 IniLoad;
 If Not MouseDriverFound Then Begin
  WriteLn('Pilote de souris non trouve.');
  Halt(1);
 End;
 {$IFDEF FPC}
 TraceOn:=GetEnv('W2TRACE')<>'';
 TrCSn:=0;If GetEnv('W2TRCS')<>'' Then Begin TrCS1:=StrVal('$'+GetEnv('W2TRCS'),0);TrCSn:=4000000;TrWin:=False;TrSnap:=0;TrGN:=0;TrWatch:=0;TrZero:=False;End;
 If TraceOn Then Begin Assign(TraceF,GetEnv('W2TRACE'));Rewrite(TraceF);End;
 {$ENDIF}
 InitializeGraphics;
 InitCursor;
 MX:=SCR_W Div 2;MY:=SCR_H Div 2;
 ShowMouse;
 If Not NoSplash Then Splash;
 W:=Launch(A_EXEC,'');
 For I:=1 To NRun Do W:=Launch(RunList[I],'');
 If StartFile<>'' Then RunFile(StartFile,'',False);
 DesktopLoop;
 While NWins>0 Do RemoveWindow(Wins[NWins]);
 HideMouse;
 CloseGraph;
 WriteLn('Microsoft Windows 2.03 (clone) - '+T3('Thank you!','Merci !','Danke!'));
END.
