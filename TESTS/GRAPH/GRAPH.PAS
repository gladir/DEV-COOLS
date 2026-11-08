Unit Graph;
{$A+,B-,D-,G-,I-,L-,N-,Q-,R-,S-,V-,X+}
{ Unite GRAPH de Turbo Pascal 7.0 (BGI integre) : pilote video CGA, MCGA, EGA et
  VGA par le BIOS et l'acces direct a la memoire video, sans fichier .BGI ni
  .CHR. Police 8x8 de la ROM BIOS (toutes les polices sont tracees avec elle,
  mises a l'echelle). Extension : VGA, mode 3 = 320x200 en 256 couleurs (13h). }
Interface
Const
 grOk=0; grNoInitGraph=-1; grNotDetected=-2; grFileNotFound=-3; grInvalidDriver=-4;
 grNoLoadMem=-5; grNoScanMem=-6; grNoFloodMem=-7; grFontNotFound=-8; grNoFontMem=-9;
 grInvalidMode=-10; grError=-11; grIOerror=-12; grInvalidFont=-13;
 grInvalidFontNum=-14; grInvalidDeviceNum=-15; grInvalidVersion=-18;
 Detect=0; CGA=1; MCGA=2; EGA=3; EGA64=4; EGAMono=5; IBM8514=6; HercMono=7;
 ATT400=8; VGA=9; PC3270=10; CurrentDriver=-128;
 CGAC0=0; CGAC1=1; CGAC2=2; CGAC3=3; CGAHi=4;
 MCGAC0=0; MCGAC1=1; MCGAC2=2; MCGAC3=3; MCGAMed=4; MCGAHi=5;
 EGALo=0; EGAHi=1; EGA64Lo=0; EGA64Hi=1; EGAMonoHi=3; HercMonoHi=0;
 ATT400C0=0; ATT400C1=1; ATT400C2=2; ATT400C3=3; ATT400Med=4; ATT400Hi=5;
 VGALo=0; VGAMed=1; VGAHi=2; VGA256=3; PC3270Hi=0; IBM8514LO=0; IBM8514HI=1;
 MaxColors=15;
 Black=0; Blue=1; Green=2; Cyan=3; Red=4; Magenta=5; Brown=6; LightGray=7;
 DarkGray=8; LightBlue=9; LightGreen=10; LightCyan=11; LightRed=12;
 LightMagenta=13; Yellow=14; White=15;
 EGABlack=0; EGABlue=1; EGAGreen=2; EGACyan=3; EGARed=4; EGAMagenta=5;
 EGABrown=20; EGALightgray=7; EGADarkgray=56; EGALightblue=57;
 EGALightgreen=58; EGALightcyan=59; EGALightred=60; EGALightmagenta=61;
 EGAYellow=62; EGAWhite=63;
 SolidLn=0; DottedLn=1; CenterLn=2; DashedLn=3; UserBitLn=4;
 NormWidth=1; ThickWidth=3;
 CopyPut=0; NormalPut=0; XORPut=1; OrPut=2; AndPut=3; NotPut=4;
 DefaultFont=0; TriplexFont=1; SmallFont=2; SansSerifFont=3; GothicFont=4;
 HorizDir=0; VertDir=1; UserCharSize=0;
 LeftText=0; CenterText=1; RightText=2; BottomText=0; TopText=2;
 ClipOn=True; ClipOff=False; TopOn=True; TopOff=False;
 EmptyFill=0; SolidFill=1; LineFill=2; LtSlashFill=3; SlashFill=4;
 BkSlashFill=5; LtBkSlashFill=6; HatchFill=7; XHatchFill=8; InterleaveFill=9;
 WideDotFill=10; CloseDotFill=11; UserFill=12;
Type
 ArcCoordsType=Record X,Y,XStart,YStart,XEnd,YEnd: Integer End;
 FillPatternType=Array[1..8] Of Byte;
 FillSettingsType=Record Pattern,Color: Word End;
 LineSettingsType=Record LineStyle,Pattern,Thickness: Word End;
 PaletteType=Record Size: Byte; Colors: Array[0..MaxColors] Of ShortInt End;
 PointType=Record X,Y: Integer End;
 TextSettingsType=Record Font,Direction,CharSize,Horiz,Vert: Word End;
 ViewPortType=Record X1,Y1,X2,Y2: Integer; Clip: Boolean End;
Var
 GraphGetMemPtr, GraphFreeMemPtr: Pointer;
Procedure Arc(X,Y: Integer; StAngle,EndAngle,Radius: Word);
Procedure Bar(X1,Y1,X2,Y2: Integer);
Procedure Bar3D(X1,Y1,X2,Y2: Integer; Depth: Word; Top: Boolean);
Procedure Circle(X,Y: Integer; Radius: Word);
Procedure ClearDevice;
Procedure ClearViewPort;
Procedure CloseGraph;
Procedure DetectGraph(Var GraphDriver,GraphMode: Integer);
Procedure DrawPoly(NumPoints: Word; Var PolyPoints);
Procedure Ellipse(X,Y: Integer; StAngle,EndAngle,XRadius,YRadius: Word);
Procedure FillEllipse(X,Y: Integer; XRadius,YRadius: Word);
Procedure FillPoly(NumPoints: Word; Var PolyPoints);
Procedure FloodFill(X,Y: Integer; Border: Word);
Procedure GetArcCoords(Var ArcCoords: ArcCoordsType);
Procedure GetAspectRatio(Var XAsp,YAsp: Word);
Function GetBkColor: Word;
Function GetColor: Word;
Procedure GetDefaultPalette(Var Palette: PaletteType);
Function GetDriverName: String;
Procedure GetFillPattern(Var FillPattern: FillPatternType);
Procedure GetFillSettings(Var FillInfo: FillSettingsType);
Function GetGraphMode: Integer;
Procedure GetImage(X1,Y1,X2,Y2: Integer; Var BitMap);
Procedure GetLineSettings(Var LineInfo: LineSettingsType);
Function GetMaxColor: Word;
Function GetMaxMode: Integer;
Function GetMaxX: Integer;
Function GetMaxY: Integer;
Function GetModeName(ModeNumber: Integer): String;
Procedure GetModeRange(GraphDriver: Integer; Var LoMode,HiMode: Integer);
Procedure GetPalette(Var Palette: PaletteType);
Function GetPaletteSize: Integer;
Function GetPixel(X,Y: Integer): Word;
Procedure GetTextSettings(Var TextInfo: TextSettingsType);
Procedure GetViewSettings(Var ViewPort: ViewPortType);
Function GetX: Integer;
Function GetY: Integer;
Procedure GraphDefaults;
Function GraphErrorMsg(ErrorCode: Integer): String;
Function GraphResult: Integer;
Function ImageSize(X1,Y1,X2,Y2: Integer): Word;
Procedure InitGraph(Var GraphDriver: Integer; Var GraphMode: Integer; PathToDriver: String);
Function InstallUserDriver(DriverFileName: String; AutoDetectPtr: Pointer): Integer;
Function InstallUserFont(FontFileName: String): Integer;
Procedure Line(X1,Y1,X2,Y2: Integer);
Procedure LineRel(Dx,Dy: Integer);
Procedure LineTo(X,Y: Integer);
Procedure MoveRel(Dx,Dy: Integer);
Procedure MoveTo(X,Y: Integer);
Procedure OutText(TextString: String);
Procedure OutTextXY(X,Y: Integer; TextString: String);
Procedure PieSlice(X,Y: Integer; StAngle,EndAngle,Radius: Word);
Procedure PutImage(X,Y: Integer; Var BitMap; BitBlt: Word);
Procedure PutPixel(X,Y: Integer; Pixel: Word);
Procedure Rectangle(X1,Y1,X2,Y2: Integer);
Function RegisterBGIdriver(Driver: Pointer): Integer;
Function RegisterBGIfont(Font: Pointer): Integer;
Procedure RestoreCrtMode;
Procedure Sector(X,Y: Integer; StAngle,EndAngle,XRadius,YRadius: Word);
Procedure SetActivePage(Page: Word);
Procedure SetAllPalette(Var Palette);
Procedure SetAspectRatio(XAsp,YAsp: Word);
Procedure SetBkColor(ColorNum: Word);
Procedure SetColor(Color: Word);
Procedure SetFillPattern(Pattern: FillPatternType; Color: Word);
Procedure SetFillStyle(Pattern: Word; Color: Word);
Function SetGraphBufSize(BufSize: Word): Word;
Procedure SetGraphMode(Mode: Integer);
Procedure SetLineStyle(LineStyle: Word; Pattern: Word; Thickness: Word);
Procedure SetPalette(ColorNum: Word; Color: ShortInt);
Procedure SetRGBPalette(ColorNum,RedValue,GreenValue,BlueValue: Integer);
Procedure SetTextJustify(Horiz,Vert: Word);
Procedure SetTextStyle(Font,Direction: Word; CharSize: Word);
Procedure SetUserCharSize(MultX,DivX,MultY,DivY: Word);
Procedure SetViewPort(X1,Y1,X2,Y2: Integer; Clip: Boolean);
Procedure SetVisualPage(Page: Word);
Procedure SetWriteMode(WriteMode: Integer);
Function TextHeight(TextString: String): Word;
Function TextWidth(TextString: String): Word;
Implementation
Const
 MaxPoly=399;
 DefPal: Array[0..15] Of ShortInt = (0,1,2,3,4,5,20,7,56,57,58,59,60,61,62,63);
 SinTab: Array[0..90] Of Integer = (
  0,286,572,857,1143,1428,1713,1997,2280,2563,2845,3126,3406,3686,3964,4240,
  4516,4790,5063,5334,5604,5872,6138,6402,6664,6924,7182,7438,7692,7943,8192,
  8438,8682,8923,9162,9397,9630,9860,10087,10311,10531,10749,10963,11174,11381,
  11585,11786,11982,12176,12365,12551,12733,12911,13085,13255,13421,13583,13741,
  13894,14044,14189,14330,14466,14598,14726,14849,14968,15082,15191,15296,15396,
  15491,15582,15668,15749,15826,15897,15964,16026,16083,16135,16182,16225,16262,
  16294,16322,16344,16362,16374,16382,16384);
 FillTab: Array[0..95] Of Byte = (
  $00,$00,$00,$00,$00,$00,$00,$00,
  $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,
  $FF,$FF,$00,$00,$FF,$FF,$00,$00,
  $01,$02,$04,$08,$10,$20,$40,$80,
  $E0,$C1,$83,$07,$0E,$1C,$38,$70,
  $F0,$78,$3C,$1E,$0F,$87,$C3,$E1,
  $A5,$D2,$69,$B4,$5A,$2D,$96,$4B,
  $FF,$88,$88,$88,$FF,$88,$88,$88,
  $81,$42,$24,$18,$18,$24,$42,$81,
  $CC,$33,$CC,$33,$CC,$33,$CC,$33,
  $80,$00,$08,$00,$80,$00,$08,$00,
  $88,$00,$22,$00,$88,$00,$22,$00);
Type
 TPts=Array[0..8191] Of PointType;
 PPts=^TPts;
 TBytes=Array[0..65519] Of Byte;
 PBytes=^TBytes;
 TSeed=Record X,Y: Integer End;
 TSeeds=Array[0..4095] Of TSeed;
 PSeeds=^TSeeds;
Var
 Active: Boolean;            { mode graphique en cours }
 Opened: Boolean;            { InitGraph effectue }
 GErr: Integer;
 CurDrv, CurMode: Integer;
 BiosMode, Kind, SavedMode: Byte;
 { Kind : 0 plans EGA/VGA 16 couleurs, 1 CGA 4 couleurs, 2 CGA 2 couleurs,
   3 2 couleurs lineaire (11h), 4 256 couleurs (13h) }
 ScrW, ScrH: Integer;
 MaxCol, PageLen, PageBase, NPages: Word;
 HaveVGA, HaveMCGA, HaveEGA, MonoEGA: Boolean;
 DacDirty: Boolean;
 CX1, CY1, CX2, CY2: Integer;        { rectangle d'ecretage absolu }
 VX1, VY1, VX2, VY2: Integer;
 VClip: Boolean;
 CPX, CPY: Integer;
 CurColor, BkIdx: Word;
 FillPat, UserPat: FillPatternType;
 FillStyle, FillColor: Word;
 LnStyle, LnPat, LnThick: Word;
 TxFont, TxDir, TxSize, TxHoriz, TxVert: Word;
 UMX, UDX, UMY, UDY: Word;
 WMode: Integer;
 AspX, AspY: Word;
 Pal: PaletteType;
 ArcInfo: ArcCoordsType;
 BufSz: Word;
 POp: Byte;
 RA, RB, RC, RD: Word;
 FSeg0, FOfs0, FSeg1, FOfs1: Word;
 PolyBuf: Array[0..MaxPoly] Of PointType;
 FVis: PBytes;
 FW: Integer;

Procedure Int10(A,B,C,D: Word);
Begin
 asm
  mov ax,A
  mov bx,B
  mov cx,C
  mov dx,D
  push bp
  push si
  push di
  int 10h
  pop di
  pop si
  pop bp
  mov RA,ax
  mov RB,bx
  mov RC,cx
  mov RD,dx
 end;
End;

{ ===== Materiel ===== }

Procedure DetectHW;
Begin
 HaveVGA:=False; HaveMCGA:=False; HaveEGA:=False; MonoEGA:=False;
 Int10($1A00,0,0,0);
 If Lo(RA)=$1A Then Begin
  Case Lo(RB) Of
   7,8: HaveVGA:=True;
   $A,$B,$C: HaveMCGA:=True;
  End;
 End;
 Int10($1200,$10,0,0);
 If Lo(RB)<>$10 Then Begin
  HaveEGA:=True; MonoEGA:=Hi(RB)<>0;
 End;
 If HaveVGA Then HaveEGA:=True;
End;

Procedure DetectGraph(Var GraphDriver,GraphMode: Integer);
Begin
 DetectHW;
 If HaveVGA Then Begin GraphDriver:=VGA; GraphMode:=VGAHi End
 Else If HaveMCGA Then Begin GraphDriver:=MCGA; GraphMode:=MCGAHi End
 Else If HaveEGA Then Begin
  If MonoEGA Then Begin GraphDriver:=EGAMono; GraphMode:=EGAMonoHi End
  Else Begin GraphDriver:=EGA; GraphMode:=EGAHi End
 End
 Else If (Mem[$40:$10] And $30)=$30 Then Begin GraphDriver:=HercMono; GraphMode:=HercMonoHi End
 Else Begin GraphDriver:=CGA; GraphMode:=CGAHi End;
End;

Procedure GetModeRange(GraphDriver: Integer; Var LoMode,HiMode: Integer);
Begin
 LoMode:=0;
 Case GraphDriver Of
  CGA: HiMode:=4;
  MCGA,ATT400: HiMode:=5;
  EGA,EGA64,IBM8514: HiMode:=1;
  EGAMono: Begin LoMode:=3; HiMode:=3 End;
  HercMono,PC3270: HiMode:=0;
  VGA: HiMode:=2;
 Else Begin LoMode:=-1; HiMode:=-1 End;
 End;
End;

Function SetModeInfo(D,M: Integer): Boolean;
{ Renseigne les caracteristiques du couple pilote/mode ; Faux si non gere. }
Begin
 SetModeInfo:=True;
 PageLen:=0; NPages:=1;
 If ((D=CGA) Or (D=MCGA)) And (M>=0) And (M<=3) Then Begin
  BiosMode:=4; Kind:=1; ScrW:=320; ScrH:=200; MaxCol:=3; AspX:=8333; AspY:=10000;
 End Else If ((D=CGA) Or (D=MCGA)) And (M=4) Then Begin
  BiosMode:=6; Kind:=2; ScrW:=640; ScrH:=200; MaxCol:=1; AspX:=4167; AspY:=10000;
  If D=CGA Then AspX:=5200;
 End Else If (D=MCGA) And (M=5) Then Begin
  BiosMode:=$11; Kind:=3; ScrW:=640; ScrH:=480; MaxCol:=1; AspX:=10000; AspY:=10000;
 End Else If ((D=EGA) Or (D=VGA)) And (M=0) Then Begin
  BiosMode:=$E; Kind:=0; ScrW:=640; ScrH:=200; MaxCol:=15; AspX:=4400; AspY:=10000;
  NPages:=4; PageLen:=$4000;
 End Else If ((D=EGA) Or (D=VGA)) And (M=1) Then Begin
  BiosMode:=$10; Kind:=0; ScrW:=640; ScrH:=350; MaxCol:=15; AspX:=7750; AspY:=10000;
  NPages:=2; PageLen:=$8000;
 End Else If (D=VGA) And (M=2) Then Begin
  BiosMode:=$12; Kind:=0; ScrW:=640; ScrH:=480; MaxCol:=15; AspX:=10000; AspY:=10000;
 End Else If (D=VGA) And (M=3) Then Begin
  BiosMode:=$13; Kind:=4; ScrW:=320; ScrH:=200; MaxCol:=255; AspX:=8333; AspY:=10000;
 End Else SetModeInfo:=False;
End;

Function GetMaxMode: Integer;
Var L,H: Integer;
Begin
 GetMaxMode:=0;
 If Not Opened Then Begin GErr:=grNoInitGraph; Exit End;
 GetModeRange(CurDrv,L,H);
 GetMaxMode:=H;
End;

Function GetDriverName: String;
Begin
 GetDriverName:='';
 If Not Opened Then Begin GErr:=grNoInitGraph; Exit End;
 Case CurDrv Of
  CGA: GetDriverName:='CGA';
  MCGA: GetDriverName:='MCGA';
  EGA: GetDriverName:='EGA';
  EGA64: GetDriverName:='EGA64';
  EGAMono: GetDriverName:='EGAMONO';
  IBM8514: GetDriverName:='IBM8514';
  HercMono: GetDriverName:='HERCMONO';
  ATT400: GetDriverName:='ATT400';
  VGA: GetDriverName:='VGA';
  PC3270: GetDriverName:='PC3270';
 End;
End;

Function GetModeName(ModeNumber: Integer): String;
Begin
 GetModeName:='';
 If Not Opened Then Begin GErr:=grNoInitGraph; Exit End;
 If (CurDrv=CGA) Or (CurDrv=MCGA) Then Begin
  Case ModeNumber Of
   0: GetModeName:='320 x 200 CGA P0';
   1: GetModeName:='320 x 200 CGA P1';
   2: GetModeName:='320 x 200 CGA P2';
   3: GetModeName:='320 x 200 CGA P3';
   4: GetModeName:='640 x 200 CGA';
   5: If CurDrv=MCGA Then GetModeName:='640 x 480 MCGA';
  End;
 End Else If CurDrv=EGA Then Begin
  If ModeNumber=0 Then GetModeName:='640 x 200 EGA'
  Else If ModeNumber=1 Then GetModeName:='640 x 350 EGA';
 End Else If CurDrv=VGA Then Begin
  Case ModeNumber Of
   0: GetModeName:='640 x 200 VGA';
   1: GetModeName:='640 x 350 VGA';
   2: GetModeName:='640 x 480 VGA';
   3: GetModeName:='320 x 200 VGA256';
  End;
 End;
End;

Function GraphErrorMsg(ErrorCode: Integer): String;
Var S: String;
Begin
 Case ErrorCode Of
  0: S:='No error';
  -1: S:='Graphics not installed (use InitGraph)';
  -2: S:='Graphics hardware not detected';
  -3: S:='Device driver file not found ()';
  -4: S:='Invalid device driver file ()';
  -5: S:='Not enough memory to load driver';
  -6: S:='Out of memory in scan fill';
  -7: S:='Out of memory in flood fill';
  -8: S:='Font file not found ()';
  -9: S:='Not enough memory to load font';
  -10: S:='Invalid graphics mode for selected driver';
  -11: S:='Graphics error';
  -12: S:='Graphics I/O error';
  -13: S:='Invalid font file ()';
  -14: S:='Invalid font number';
  -15: S:='Invalid device number';
  -18: S:='Invalid version of file ()';
 Else Begin Str(ErrorCode,S); S:='Graphics error ('+S+')' End;
 End;
 GraphErrorMsg:=S;
End;

Function GraphResult: Integer;
Begin
 GraphResult:=GErr; GErr:=0;
End;

{ ===== Palette ===== }

Procedure ACSet(Reg,Val: Word);
Begin
 Int10($1000,Val*256+Reg,0,0);
End;

Procedure DacSet(Idx,R,G,B: Word);
Begin
 Int10($1010,Idx,G*256+B,R*256);
End;

Procedure EGAtoRGB(E: Word; Var R,G,B: Word);
Begin
 R:=((E Shr 2) And 1)*$2A+((E Shr 5) And 1)*$15;
 G:=((E Shr 1) And 1)*$2A+((E Shr 4) And 1)*$15;
 B:=(E And 1)*$2A+((E Shr 3) And 1)*$15;
End;

Procedure SetPalette(ColorNum: Word; Color: ShortInt);
Var R,G,B: Word;
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 If (ColorNum>MaxCol) Or (Color<-1) Or (Color>63) Then Begin GErr:=grError; Exit End;
 If Color=-1 Then Exit;
 If ColorNum<16 Then Pal.Colors[ColorNum]:=Color;
 Case Kind Of
  0: ACSet(ColorNum,Color);
  4: Begin EGAtoRGB(Color,R,G,B); DacSet(ColorNum,R,G,B); DacDirty:=True End;
  1,2: If ColorNum=0 Then Int10($0B00,Color And 15,0,0);
 End;
End;

Procedure SetBkColor(ColorNum: Word);
Var R,G,B: Word;
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 If ColorNum>MaxCol Then Begin GErr:=grError; Exit End;
 BkIdx:=ColorNum;
 Case Kind Of
  0: Begin Pal.Colors[0]:=Pal.Colors[ColorNum]; ACSet(0,Pal.Colors[0]) End;
  1,2: Begin Pal.Colors[0]:=ColorNum; Int10($0B00,ColorNum,0,0) End;
  4: Begin
   Int10($1015,ColorNum,0,0);
   R:=Hi(RD); G:=Hi(RC); B:=Lo(RC);
   DacSet(0,R,G,B); DacDirty:=True;
  End;
 End;
End;

Function GetBkColor: Word;
Begin
 GetBkColor:=BkIdx;
End;

Procedure SetRGBPalette(ColorNum,RedValue,GreenValue,BlueValue: Integer);
Var Idx: Word;
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 If Not HaveVGA Then Exit;
 If (ColorNum<0) Or (ColorNum>MaxCol) Then Begin GErr:=grError; Exit End;
 Idx:=ColorNum;
 If Kind=0 Then Begin
  Int10($1007,ColorNum,0,0);   { registre palette -> index DAC }
  Idx:=Hi(RB);
 End Else If Kind<>4 Then Exit;
 DacSet(Idx,(RedValue And 255) Shr 2,(GreenValue And 255) Shr 2,(BlueValue And 255) Shr 2);
 DacDirty:=True;
End;

Procedure SetAllPalette(Var Palette);
Var P: ^PaletteType; I: Word;
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 P:=@Palette;
 If P^.Size>MaxCol+1 Then Begin GErr:=grError; Exit End;
 For I:=0 To P^.Size-1 Do
  If (P^.Colors[I]>=0) And (P^.Colors[I]<=63) Then SetPalette(I,P^.Colors[I]);
End;

Procedure GetPalette(Var Palette: PaletteType);
Begin
 Palette:=Pal;
End;

Procedure GetDefaultPalette(Var Palette: PaletteType);
Var I: Word;
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 Palette.Size:=Pal.Size;
 For I:=0 To 15 Do
  If (Kind=0) Or (Kind=4) Then Palette.Colors[I]:=DefPal[I] Else Palette.Colors[I]:=I;
End;

Function GetPaletteSize: Integer;
Begin
 GetPaletteSize:=MaxCol+1;
End;

Procedure ResetPalette;
Var I,R,G,B: Word;
Begin
 Pal.Size:=16; If MaxCol<15 Then Pal.Size:=MaxCol+1;
 BkIdx:=0;
 For I:=0 To 15 Do Pal.Colors[I]:=I;
 If Kind=0 Then Begin
  For I:=0 To 15 Do Pal.Colors[I]:=DefPal[I];
  For I:=0 To 15 Do ACSet(I,DefPal[I]);
  If HaveVGA And DacDirty Then
   For I:=0 To 15 Do Begin EGAtoRGB(DefPal[I],R,G,B); DacSet(DefPal[I],R,G,B) End;
 End Else If Kind=4 Then Begin
  Pal.Size:=16;
  If DacDirty Then Begin
   For I:=0 To 15 Do Pal.Colors[I]:=DefPal[I];
   For I:=0 To 15 Do Begin EGAtoRGB(DefPal[I],R,G,B); DacSet(I,R,G,B) End;
  End;
 End;
 DacDirty:=False;
End;

{ ===== Primitives de trace ===== }

Function Comb(Old,V,Mask: Byte): Byte;
{ Combine V (deja positionne) dans Old selon POp, sur les bits de Mask. }
Begin
 Case POp Of
  0: Comb:=(Old And (Not Mask)) Or (V And Mask);
  1: Comb:=Old And (V Or (Not Mask));
  2: Comb:=Old Or (V And Mask);
 Else Comb:=Old Xor (V And Mask);
 End;
End;

Procedure PixSetup(Op: Byte);
Begin
 POp:=Op;
 If Kind=0 Then Begin
  Port[$3C4]:=2; Port[$3C5]:=15;
  Port[$3CE]:=1; Port[$3CF]:=0;
  Port[$3CE]:=5; Port[$3CF]:=2;
  Port[$3CE]:=3; Port[$3CF]:=Op Shl 3;
 End Else If Kind=3 Then Begin
  Port[$3CE]:=1; Port[$3CF]:=0;
  Port[$3CE]:=5; Port[$3CF]:=0;
  Port[$3CE]:=3; Port[$3CF]:=0;
  Port[$3CE]:=8; Port[$3CF]:=255;
  Port[$3CE]:=4; Port[$3CF]:=0;
 End;
End;

Procedure PixDone;
Begin
 If (Kind=0) Or (Kind=3) Then Begin
  Port[$3CE]:=5; Port[$3CF]:=0;
  Port[$3CE]:=3; Port[$3CF]:=0;
  Port[$3CE]:=8; Port[$3CF]:=255;
 End;
End;

Procedure PixPlot(X,Y: Integer; C: Word);
{ Trace un pixel en coordonnees ecran (dans l'ecran), selon POp. }
Var Ofs,XW,YW: Word; B,Sh: Byte;
Begin
 XW:=X; YW:=Y;
 Case Kind Of
  0: Begin
   Ofs:=PageBase+YW*80+(XW Shr 3);
   Port[$3CE]:=8; Port[$3CF]:=$80 Shr (XW And 7);
   B:=Mem[$A000:Ofs];
   Mem[$A000:Ofs]:=C;
  End;
  1: Begin
   Ofs:=(YW And 1)*$2000+(YW Shr 1)*80+(XW Shr 2);
   Sh:=6-((XW And 3) Shl 1);
   Mem[$B800:Ofs]:=Comb(Mem[$B800:Ofs],C Shl Sh,3 Shl Sh);
  End;
  2: Begin
   Ofs:=(YW And 1)*$2000+(YW Shr 1)*80+(XW Shr 3);
   Sh:=7-(XW And 7);
   Mem[$B800:Ofs]:=Comb(Mem[$B800:Ofs],C Shl Sh,1 Shl Sh);
  End;
  3: Begin
   Ofs:=YW*80+(XW Shr 3);
   Sh:=7-(XW And 7);
   Mem[$A000:Ofs]:=Comb(Mem[$A000:Ofs],C Shl Sh,1 Shl Sh);
  End;
  4: Begin
   Ofs:=YW*320+XW;
   Mem[$A000:Ofs]:=Comb(Mem[$A000:Ofs],C,255);
  End;
 End;
End;

Function PixGet(X,Y: Integer): Word;
Var Ofs,XW,YW,V: Word; P: Integer;
Begin
 XW:=X; YW:=Y; V:=0;
 Case Kind Of
  0: Begin
   Ofs:=PageBase+YW*80+(XW Shr 3);
   Port[$3CE]:=4;
   For P:=3 DownTo 0 Do Begin
    Port[$3CF]:=P;
    V:=(V Shl 1) Or ((Mem[$A000:Ofs] Shr (7-(XW And 7))) And 1);
   End;
  End;
  1: Begin
   Ofs:=(YW And 1)*$2000+(YW Shr 1)*80+(XW Shr 2);
   V:=(Mem[$B800:Ofs] Shr (6-((XW And 3) Shl 1))) And 3;
  End;
  2: Begin
   Ofs:=(YW And 1)*$2000+(YW Shr 1)*80+(XW Shr 3);
   V:=(Mem[$B800:Ofs] Shr (7-(XW And 7))) And 1;
  End;
  3: Begin
   Port[$3CE]:=4; Port[$3CF]:=0;
   Ofs:=YW*80+(XW Shr 3);
   V:=(Mem[$A000:Ofs] Shr (7-(XW And 7))) And 1;
  End;
  4: V:=Mem[$A000:YW*320+XW];
 End;
 PixGet:=V;
End;

Procedure Plot(X,Y: Integer; C: Word);
Begin
 If (X>=CX1) And (X<=CX2) And (Y>=CY1) And (Y<=CY2) Then PixPlot(X,Y,C);
End;

Procedure ClearBytes(P: PBytes; Count: Longint);
{ Met Count octets a zero (FillChar est limite a 32767 octets). }
Var Off: Longint; N: Word;
Begin
 Off:=0;
 While Off<Count Do Begin
  N:=16384;
  If Count-Off<N Then N:=Count-Off;
  FillChar(P^[Off],N,0);
  Inc(Off,N);
 End;
End;

Function WriteOp: Byte;
Begin
 Case WMode Of
  1: WriteOp:=3;
  2: WriteOp:=2;
  3: WriteOp:=1;
 Else WriteOp:=0;
 End;
End;

Procedure SpanFill(X1,X2,Y: Integer);
{ Remplit [X1,X2] de la ligne Y (ecran, deja ecrete) avec la trame courante.
  Les bits a 0 de la trame prennent la couleur 0. POp doit valoir 0. }
Var PB,M,F,G,B: Byte; XB,XB1,XB2,Ofs,YW: Word; X: Integer;
Begin
 If X1>X2 Then Exit;
 PB:=FillPat[(Y And 7)+1];
 If Kind=0 Then Begin
  XB1:=X1 Shr 3; XB2:=X2 Shr 3;
  YW:=Y;
  Ofs:=PageBase+YW*80;
  For XB:=XB1 To XB2 Do Begin
   M:=255;
   If XB=XB1 Then M:=M And (255 Shr (X1 And 7));
   If XB=XB2 Then M:=M And (255 Shl (7-(X2 And 7)));
   F:=PB And M; G:=(Not PB) And M;
   If F<>0 Then Begin
    Port[$3CE]:=8; Port[$3CF]:=F;
    B:=Mem[$A000:Ofs+XB]; Mem[$A000:Ofs+XB]:=FillColor;
   End;
   If G<>0 Then Begin
    Port[$3CE]:=8; Port[$3CF]:=G;
    B:=Mem[$A000:Ofs+XB]; Mem[$A000:Ofs+XB]:=0;
   End;
  End;
 End Else
  For X:=X1 To X2 Do
   If (PB And ($80 Shr (X And 7)))<>0 Then PixPlot(X,Y,FillColor) Else PixPlot(X,Y,0);
End;

Procedure ClearRect(X1,Y1,X2,Y2: Integer);
{ Efface un rectangle ecran (couleur 0). }
Var Save: FillPatternType; Y: Integer;
Begin
 Save:=FillPat;
 FillChar(FillPat,8,0);
 PixSetup(0);
 For Y:=Y1 To Y2 Do SpanFill(X1,X2,Y);
 PixDone;
 FillPat:=Save;
End;

Procedure LineAbs(X1,Y1,X2,Y2: Integer; Skip1,SkipLast: Boolean);
Var DX,DY,SX,SY,E,E2,X,Y,Cnt: Longint; Mostly: Boolean; Bit: Word; Go: Boolean;
Begin
 If (X1<CX1-1) And (X2<CX1-1) Then Exit;
 If (X1>CX2+1) And (X2>CX2+1) Then Exit;
 If (Y1<CY1-1) And (Y2<CY1-1) Then Exit;
 If (Y1>CY2+1) And (Y2>CY2+1) Then Exit;
 DX:=Abs(Longint(X2)-X1); DY:=Abs(Longint(Y2)-Y1);
 If X1<X2 Then SX:=1 Else SX:=-1;
 If Y1<Y2 Then SY:=1 Else SY:=-1;
 Mostly:=DX>=DY;
 E:=DX-DY; X:=X1; Y:=Y1; Cnt:=0; Go:=True;
 While Go Do Begin
  Bit:=1;
  If LnPat<>$FFFF Then Bit:=LnPat And (Word($8000) Shr (Cnt And 15));
  If (Bit<>0) And ((Cnt>0) Or Not Skip1) And Not (SkipLast And (X=X2) And (Y=Y2)) Then Begin
   Plot(X,Y,CurColor);
   If LnThick>1 Then
    If Mostly Then Begin Plot(X,Y-1,CurColor); Plot(X,Y+1,CurColor) End
    Else Begin Plot(X-1,Y,CurColor); Plot(X+1,Y,CurColor) End;
  End;
  If (X=X2) And (Y=Y2) Then Go:=False Else Begin
   E2:=2*E;
   If E2>-DY Then Begin E:=E-DY; X:=X+SX End;
   If E2<DX Then Begin E:=E+DX; Y:=Y+SY End;
   Inc(Cnt);
  End;
 End;
End;

{ ===== Etat, mode, fenetre ===== }

Procedure SetClip;
Begin
 If VClip Then Begin CX1:=VX1; CY1:=VY1; CX2:=VX2; CY2:=VY2 End
 Else Begin CX1:=0; CY1:=0; CX2:=ScrW-1; CY2:=ScrH-1 End;
End;

Procedure LoadFont;
{ Police 8x8 : moitie basse (BIOS EGA/VGA ou ROM F000:FA6E), moitie haute. }
Begin
 FSeg0:=0; FOfs0:=0; FSeg1:=0; FOfs1:=0;
 If HaveEGA Then Begin
  asm
   push bp
   push si
   push di
   xor bx,bx
   mov es,bx
   xor bp,bp
   mov ax,1130h
   mov bh,3
   int 10h
   mov dx,bp
   mov bx,es
   pop di
   pop si
   pop bp
   mov FOfs0,dx
   mov FSeg0,bx
   push bp
   push si
   push di
   xor bx,bx
   mov es,bx
   xor bp,bp
   mov ax,1130h
   mov bh,4
   int 10h
   mov dx,bp
   mov bx,es
   pop di
   pop si
   pop bp
   mov FOfs1,dx
   mov FSeg1,bx
  end;
 End;
 If FSeg0=0 Then Begin FSeg0:=$F000; FOfs0:=$FA6E End;
 If FSeg1=0 Then Begin FOfs1:=MemW[0:$7C]; FSeg1:=MemW[0:$7E] End;
End;

Procedure GraphDefaultsInt;
Var I: Word;
Begin
 CPX:=0; CPY:=0;
 VX1:=0; VY1:=0; VX2:=ScrW-1; VY2:=ScrH-1; VClip:=True;
 SetClip;
 ResetPalette;
 CurColor:=MaxCol; FillStyle:=SolidFill; FillColor:=MaxCol;
 For I:=1 To 8 Do Begin FillPat[I]:=$FF; UserPat[I]:=$FF End;
 LnStyle:=SolidLn; LnPat:=$FFFF; LnThick:=NormWidth;
 TxFont:=DefaultFont; TxDir:=HorizDir; TxSize:=1; TxHoriz:=LeftText; TxVert:=TopText;
 UMX:=1; UDX:=1; UMY:=1; UDY:=1;
 WMode:=CopyPut;
End;

Procedure GraphDefaults;
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 SetModeInfo(CurDrv,CurMode);
 GraphDefaultsInt;
End;

Procedure EnterMode;
Begin
 Int10(BiosMode,0,0,0);
 PageBase:=0;
 If Kind=1 Then Begin
  { palette CGA : C0 vert/rouge/brun, C1 cyan/magenta/blanc ; C0 et C1 intenses }
  If (CurMode And 1)=0 Then Int10($0B01,0,0,0) Else Int10($0B01,1,0,0);
  If CurMode<2 Then Int10($0B00,$10,0,0) Else Int10($0B00,0,0,0);
 End;
 DacDirty:=False;
 LoadFont;
 Active:=True;
 GraphDefaultsInt;
End;

Procedure InitGraph(Var GraphDriver: Integer; Var GraphMode: Integer; PathToDriver: String);
Var D,M: Integer;
Begin
 Active:=False; GErr:=grOk;
 DetectHW;
 D:=GraphDriver; M:=GraphMode;
 If D=Detect Then Begin
  DetectGraph(D,M);
  GraphMode:=M;
 End;
 If (D<0) Or (D>PC3270) Or (D=EGA64) Or (D=EGAMono) Or (D=IBM8514) Or (D=HercMono) Or
    (D=ATT400) Or (D=PC3270) Then Begin
  GraphDriver:=grInvalidDriver; GErr:=grInvalidDriver; Exit;
 End;
 If ((D=VGA) And Not HaveVGA) Or ((D=EGA) And Not HaveEGA) Or ((D=MCGA) And Not (HaveMCGA Or HaveVGA)) Then Begin
  GraphDriver:=grNotDetected; GErr:=grNotDetected; Exit;
 End;
 If Not SetModeInfo(D,M) Then Begin
  GraphDriver:=grInvalidMode; GErr:=grInvalidMode; Exit;
 End;
 GraphDriver:=D;
 Int10($0F00,0,0,0);
 If Not Opened Then SavedMode:=Lo(RA);
 CurDrv:=D; CurMode:=M; Opened:=True;
 EnterMode;
End;

Procedure SetGraphMode(Mode: Integer);
Begin
 If Not Opened Then Begin GErr:=grNoInitGraph; Exit End;
 If Not SetModeInfo(CurDrv,Mode) Then Begin
  SetModeInfo(CurDrv,CurMode); GErr:=grInvalidMode; Exit;
 End;
 CurMode:=Mode;
 EnterMode;
End;

Function GetGraphMode: Integer;
Begin
 If Not Opened Then Begin GErr:=grNoInitGraph; GetGraphMode:=0; Exit End;
 GetGraphMode:=CurMode;
End;

Procedure RestoreCrtMode;
Begin
 If Not Opened Then Exit;
 Int10(SavedMode,0,0,0);
 Active:=False;
End;

Procedure CloseGraph;
Begin
 If Not Opened Then Exit;
 RestoreCrtMode;
 Opened:=False; Active:=False;
End;

Function GetMaxX: Integer;
Begin
 GetMaxX:=0;
 If Not Opened Then Begin GErr:=grNoInitGraph; Exit End;
 GetMaxX:=ScrW-1;
End;

Function GetMaxY: Integer;
Begin
 GetMaxY:=0;
 If Not Opened Then Begin GErr:=grNoInitGraph; Exit End;
 GetMaxY:=ScrH-1;
End;

Function GetMaxColor: Word;
Begin
 GetMaxColor:=0;
 If Not Opened Then Begin GErr:=grNoInitGraph; Exit End;
 GetMaxColor:=MaxCol;
End;

Procedure SetViewPort(X1,Y1,X2,Y2: Integer; Clip: Boolean);
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 If (X1<0) Or (Y1<0) Or (X2<X1) Or (Y2<Y1) Or (X2>=ScrW) Or (Y2>=ScrH) Then Begin
  GErr:=grError; Exit;
 End;
 VX1:=X1; VY1:=Y1; VX2:=X2; VY2:=Y2; VClip:=Clip;
 SetClip;
 CPX:=0; CPY:=0;
End;

Procedure GetViewSettings(Var ViewPort: ViewPortType);
Begin
 ViewPort.X1:=VX1; ViewPort.Y1:=VY1; ViewPort.X2:=VX2; ViewPort.Y2:=VY2;
 ViewPort.Clip:=VClip;
End;

Procedure ClearDevice;
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 ClearRect(0,0,ScrW-1,ScrH-1);
 CPX:=0; CPY:=0;
End;

Procedure ClearViewPort;
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 ClearRect(VX1,VY1,VX2,VY2);
 CPX:=0; CPY:=0;
End;

Procedure SetActivePage(Page: Word);
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 If Page>=NPages Then Begin GErr:=grError; Exit End;
 PageBase:=Page*PageLen;
End;

Procedure SetVisualPage(Page: Word);
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 If Page>=NPages Then Begin GErr:=grError; Exit End;
 Int10($0500+Page,0,0,0);
End;

Function SetGraphBufSize(BufSize: Word): Word;
Begin
 SetGraphBufSize:=BufSz; BufSz:=BufSize;
End;

Function RegisterBGIdriver(Driver: Pointer): Integer;
Begin
 RegisterBGIdriver:=EGA;
End;

Function RegisterBGIfont(Font: Pointer): Integer;
Begin
 RegisterBGIfont:=TriplexFont;
End;

Function InstallUserDriver(DriverFileName: String; AutoDetectPtr: Pointer): Integer;
Begin
 InstallUserDriver:=grInvalidDriver; GErr:=grError;
End;

Function InstallUserFont(FontFileName: String): Integer;
Begin
 InstallUserFont:=5;
End;

{ ===== Couleur, styles ===== }

Procedure SetColor(Color: Word);
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 CurColor:=Color And MaxCol;
End;

Function GetColor: Word;
Begin
 GetColor:=CurColor;
End;

Procedure SetWriteMode(WriteMode: Integer);
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 If (WriteMode<0) Or (WriteMode>3) Then Exit;
 WMode:=WriteMode;
End;

Procedure SetLineStyle(LineStyle: Word; Pattern: Word; Thickness: Word);
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 If (LineStyle>UserBitLn) Or ((Thickness<>NormWidth) And (Thickness<>ThickWidth)) Then Begin
  GErr:=grError; Exit;
 End;
 LnStyle:=LineStyle; LnThick:=Thickness;
 Case LineStyle Of
  SolidLn: LnPat:=$FFFF;
  DottedLn: LnPat:=$CCCC;
  CenterLn: LnPat:=$FC78;
  DashedLn: LnPat:=$F8F8;
 Else LnPat:=Pattern;
 End;
End;

Procedure GetLineSettings(Var LineInfo: LineSettingsType);
Begin
 LineInfo.LineStyle:=LnStyle; LineInfo.Pattern:=LnPat; LineInfo.Thickness:=LnThick;
End;

Procedure SetFillStyle(Pattern: Word; Color: Word);
Var I: Word;
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 If (Pattern>UserFill) Or (Color>MaxCol) Then Begin GErr:=grError; Exit End;
 FillStyle:=Pattern; FillColor:=Color;
 If Pattern=UserFill Then FillPat:=UserPat
 Else For I:=1 To 8 Do FillPat[I]:=FillTab[Pattern*8+I-1];
End;

Procedure SetFillPattern(Pattern: FillPatternType; Color: Word);
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 If Color>MaxCol Then Begin GErr:=grError; Exit End;
 UserPat:=Pattern; FillPat:=Pattern; FillStyle:=UserFill; FillColor:=Color;
End;

Procedure GetFillPattern(Var FillPattern: FillPatternType);
Begin
 FillPattern:=FillPat;
End;

Procedure GetFillSettings(Var FillInfo: FillSettingsType);
Begin
 FillInfo.Pattern:=FillStyle; FillInfo.Color:=FillColor;
End;

Procedure SetAspectRatio(XAsp,YAsp: Word);
Begin
 If YAsp=0 Then Begin GErr:=grError; Exit End;
 AspX:=XAsp; AspY:=YAsp;
End;

Procedure GetAspectRatio(Var XAsp,YAsp: Word);
Begin
 XAsp:=AspX; YAsp:=AspY;
End;

{ ===== Pixels, lignes, rectangles ===== }

Procedure PutPixel(X,Y: Integer; Pixel: Word);
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 Inc(X,VX1); Inc(Y,VY1);
 PixSetup(0);
 Plot(X,Y,Pixel And MaxCol);
 PixDone;
End;

Function GetPixel(X,Y: Integer): Word;
Begin
 GetPixel:=0;
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 Inc(X,VX1); Inc(Y,VY1);
 If (X>=CX1) And (X<=CX2) And (Y>=CY1) And (Y<=CY2) Then GetPixel:=PixGet(X,Y);
End;

Function GetX: Integer;
Begin
 GetX:=CPX;
End;

Function GetY: Integer;
Begin
 GetY:=CPY;
End;

Procedure MoveTo(X,Y: Integer);
Begin
 CPX:=X; CPY:=Y;
End;

Procedure MoveRel(Dx,Dy: Integer);
Begin
 Inc(CPX,Dx); Inc(CPY,Dy);
End;

Procedure Line(X1,Y1,X2,Y2: Integer);
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 PixSetup(WriteOp);
 LineAbs(X1+VX1,Y1+VY1,X2+VX1,Y2+VY1,False,False);
 PixDone;
End;

Procedure LineTo(X,Y: Integer);
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 PixSetup(WriteOp);
 LineAbs(CPX+VX1,CPY+VY1,X+VX1,Y+VY1,False,False);
 PixDone;
 CPX:=X; CPY:=Y;
End;

Procedure LineRel(Dx,Dy: Integer);
Begin
 LineTo(CPX+Dx,CPY+Dy);
End;

Procedure Rectangle(X1,Y1,X2,Y2: Integer);
Var T: Integer;
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 If X1>X2 Then Begin T:=X1; X1:=X2; X2:=T End;
 If Y1>Y2 Then Begin T:=Y1; Y1:=Y2; Y2:=T End;
 Inc(X1,VX1); Inc(X2,VX1); Inc(Y1,VY1); Inc(Y2,VY1);
 PixSetup(WriteOp);
 If (X1=X2) Or (Y1=Y2) Then LineAbs(X1,Y1,X2,Y2,False,False)
 Else Begin
  LineAbs(X1,Y1,X2,Y1,False,True);
  LineAbs(X2,Y1,X2,Y2,False,True);
  LineAbs(X2,Y2,X1,Y2,False,True);
  LineAbs(X1,Y2,X1,Y1,False,True);
 End;
 PixDone;
End;

Procedure DrawPolyAbs(P: PPts; N: Integer; OX,OY: Integer);
Var I: Integer; Closed: Boolean;
Begin
 If N<1 Then Exit;
 If N=1 Then Begin
  PixSetup(WriteOp); Plot(P^[0].X+OX,P^[0].Y+OY,CurColor); PixDone; Exit;
 End;
 Closed:=(N>2) And (P^[0].X=P^[N-1].X) And (P^[0].Y=P^[N-1].Y);
 PixSetup(WriteOp);
 For I:=1 To N-1 Do
  LineAbs(P^[I-1].X+OX,P^[I-1].Y+OY,P^[I].X+OX,P^[I].Y+OY,I>1,Closed And (I=N-1));
 PixDone;
End;

Procedure DrawPoly(NumPoints: Word; Var PolyPoints);
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 DrawPolyAbs(PPts(@PolyPoints),NumPoints,VX1,VY1);
End;

{ ===== Remplissage ===== }

Procedure Bar(X1,Y1,X2,Y2: Integer);
Var T,Y: Integer;
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 If X1>X2 Then Begin T:=X1; X1:=X2; X2:=T End;
 If Y1>Y2 Then Begin T:=Y1; Y1:=Y2; Y2:=T End;
 Inc(X1,VX1); Inc(X2,VX1); Inc(Y1,VY1); Inc(Y2,VY1);
 If X1<CX1 Then X1:=CX1;
 If X2>CX2 Then X2:=CX2;
 If Y1<CY1 Then Y1:=CY1;
 If Y2>CY2 Then Y2:=CY2;
 PixSetup(0);
 For Y:=Y1 To Y2 Do SpanFill(X1,X2,Y);
 PixDone;
End;

Procedure Bar3D(X1,Y1,X2,Y2: Integer; Depth: Word; Top: Boolean);
Var T: Integer; D: Integer;
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 If X1>X2 Then Begin T:=X1; X1:=X2; X2:=T End;
 If Y1>Y2 Then Begin T:=Y1; Y1:=Y2; Y2:=T End;
 Bar(X1,Y1,X2,Y2);
 Rectangle(X1,Y1,X2,Y2);
 D:=Depth;
 If D>0 Then Begin
  Inc(X1,VX1); Inc(X2,VX1); Inc(Y1,VY1); Inc(Y2,VY1);
  PixSetup(WriteOp);
  LineAbs(X2,Y2,X2+D,Y2-D,False,False);
  LineAbs(X2+D,Y2-D,X2+D,Y1-D,True,False);
  LineAbs(X2+D,Y1-D,X2,Y1,True,False);
  If Top Then Begin
   LineAbs(X2+D,Y1-D,X1+D,Y1-D,False,False);
   LineAbs(X1+D,Y1-D,X1,Y1,True,False);
  End;
  PixDone;
 End;
End;

Procedure ScanFill(P: PPts; N: Integer; OX,OY: Integer);
{ Remplissage pair-impair d'un polygone avec la trame courante. }
Var I,J,K,Cnt,Tmp: Integer;
    Y,YMin,YMax,XA,YA,XB,YB,X,XL,XR,Den: Longint;
    Xs: Array[0..127] Of Integer;
Begin
 If N<3 Then Exit;
 YMin:=P^[0].Y+Longint(OY); YMax:=YMin;
 For I:=1 To N-1 Do Begin
  Y:=P^[I].Y+Longint(OY);
  If Y<YMin Then YMin:=Y;
  If Y>YMax Then YMax:=Y;
 End;
 If YMin<CY1 Then YMin:=CY1;
 If YMax>CY2 Then YMax:=CY2;
 PixSetup(0);
 Y:=YMin;
 While Y<=YMax Do Begin
  Cnt:=0;
  For I:=0 To N-1 Do Begin
   J:=I+1; If J=N Then J:=0;
   XA:=P^[I].X+Longint(OX); YA:=P^[I].Y+Longint(OY);
   XB:=P^[J].X+Longint(OX); YB:=P^[J].Y+Longint(OY);
   If YA>YB Then Begin X:=XA; XA:=XB; XB:=X; X:=YA; YA:=YB; YB:=X End;
   If (YA<>YB) And (Y>=YA) And (Y<YB) Then Begin
    Den:=2*(YB-YA);
    X:=(Y-YA)*(XB-XA)*2+(YB-YA);
    If X>=0 Then X:=X Div Den Else X:=-((-X+Den-1) Div Den);
    Tmp:=XA+X;
    If Cnt<128 Then Begin
     K:=Cnt;
     While (K>0) And (Xs[K-1]>Tmp) Do Begin Xs[K]:=Xs[K-1]; Dec(K) End;
     Xs[K]:=Tmp; Inc(Cnt);
    End Else GErr:=grNoScanMem;
   End;
  End;
  K:=0;
  While K+1<Cnt Do Begin
   XL:=Xs[K]; XR:=Xs[K+1];
   If XL<CX1 Then XL:=CX1;
   If XR>CX2 Then XR:=CX2;
   If XL<=XR Then SpanFill(XL,XR,Y);
   Inc(K,2);
  End;
  Inc(Y);
 End;
 PixDone;
End;

Procedure FillPoly(NumPoints: Word; Var PolyPoints);
Var P: PPts; N: Integer;
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 P:=PPts(@PolyPoints); N:=NumPoints;
 ScanFill(P,N,VX1,VY1);
 DrawPolyAbs(P,N,VX1,VY1);
 If (N>2) And ((P^[0].X<>P^[N-1].X) Or (P^[0].Y<>P^[N-1].Y)) Then Begin
  PixSetup(WriteOp);
  LineAbs(P^[N-1].X+VX1,P^[N-1].Y+VY1,P^[0].X+VX1,P^[0].Y+VY1,True,True);
  PixDone;
 End;
End;

Function Seen(XA,YA: Integer): Boolean;
Var Bit: Longint;
Begin
 Bit:=Longint(YA-CY1)*FW+(XA-CX1);
 Seen:=(FVis^[Bit Shr 3] And (1 Shl (Bit And 7)))<>0;
End;

Procedure MarkSpan(XA,XB,YA: Integer);
Var Bit: Longint; I: Integer;
Begin
 For I:=XA To XB Do Begin
  Bit:=Longint(YA-CY1)*FW+(I-CX1);
  FVis^[Bit Shr 3]:=FVis^[Bit Shr 3] Or (1 Shl (Bit And 7));
 End;
End;

Procedure FloodFill(X,Y: Integer; Border: Word);
Var Seeds: PSeeds; SP,MaxSeeds,H: Integer; Sz: Longint;
    PX,PY,XL,XR,NY,XX: Integer; Dir: Integer; Run: Boolean;
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 Inc(X,VX1); Inc(Y,VY1);
 If (X<CX1) Or (X>CX2) Or (Y<CY1) Or (Y>CY2) Then Exit;
 Border:=Border And MaxCol;
 If PixGet(X,Y)=Border Then Exit;
 FW:=CX2-CX1+1; H:=CY2-CY1+1;
 Sz:=Longint((FW+7) Shr 3)*H;
 MaxSeeds:=4096;
 If MemAvail<Sz+MaxSeeds*4+4096 Then MaxSeeds:=1024;
 If (Sz>65000) Or (MemAvail<Sz+MaxSeeds*4+64) Or (MaxAvail<Sz+64) Then Begin GErr:=grNoFloodMem; Exit End;
 GetMem(FVis,Sz); GetMem(Seeds,MaxSeeds*4);
 ClearBytes(FVis,Sz);
 Seeds^[0].X:=X; Seeds^[0].Y:=Y; SP:=1;
 PixSetup(0);
 While SP>0 Do Begin
  Dec(SP); PX:=Seeds^[SP].X; PY:=Seeds^[SP].Y;
  If Not Seen(PX,PY) And (PixGet(PX,PY)<>Border) Then Begin
   XL:=PX; XR:=PX;
   While (XL>CX1) And Not Seen(XL-1,PY) And (PixGet(XL-1,PY)<>Border) Do Dec(XL);
   While (XR<CX2) And Not Seen(XR+1,PY) And (PixGet(XR+1,PY)<>Border) Do Inc(XR);
   MarkSpan(XL,XR,PY);
   SpanFill(XL,XR,PY);
   For Dir:=-1 To 1 Do If Dir<>0 Then Begin
    NY:=PY+Dir;
    If (NY>=CY1) And (NY<=CY2) Then Begin
     XX:=XL; Run:=False;
     While XX<=XR Do Begin
      If Not Seen(XX,NY) And (PixGet(XX,NY)<>Border) Then Begin
       If Not Run Then Begin
        If SP<MaxSeeds Then Begin Seeds^[SP].X:=XX; Seeds^[SP].Y:=NY; Inc(SP) End
        Else GErr:=grNoFloodMem;
        Run:=True;
       End;
      End Else Run:=False;
      Inc(XX);
     End;
    End;
   End;
  End;
 End;
 PixDone;
 FreeMem(Seeds,MaxSeeds*4); FreeMem(FVis,Sz);
End;

{ ===== Arcs, cercles, ellipses ===== }

Function SinD(A: Integer): Integer;
Begin
 A:=A Mod 360;
 If A<=90 Then SinD:=SinTab[A]
 Else If A<=180 Then SinD:=SinTab[180-A]
 Else If A<=270 Then SinD:=-SinTab[A-180]
 Else SinD:=-SinTab[360-A];
End;

Function CosD(A: Integer): Integer;
Begin
 CosD:=SinD((A+90) Mod 360);
End;

Function ScaleR(R: Word; T: Integer): Integer;
Var V: Longint;
Begin
 V:=Longint(R)*T;
 If V>=0 Then ScaleR:=(V+8192) Div 16384 Else ScaleR:=-((-V+8192) Div 16384);
End;

Function ArcGen(CxA,CyA: Integer; St,En,Rx,Ry: Word): Integer;
{ Remplit PolyBuf avec les points de l'arc (coordonnees ecran, pas de 1 degre) ;
  retourne le nombre de segments. }
Var S,E,I,N,A: Integer;
Begin
 S:=St Mod 360; E:=En;
 If E>360 Then E:=E Mod 360;
 If E<S Then E:=E+360;
 N:=E-S;
 For I:=0 To N Do Begin
  A:=(S+I) Mod 360;
  PolyBuf[I].X:=CxA+ScaleR(Rx,CosD(A));
  PolyBuf[I].Y:=CyA-ScaleR(Ry,SinD(A));
 End;
 ArcInfo.X:=CxA-VX1; ArcInfo.Y:=CyA-VY1;
 ArcInfo.XStart:=PolyBuf[0].X-VX1; ArcInfo.YStart:=PolyBuf[0].Y-VY1;
 ArcInfo.XEnd:=PolyBuf[N].X-VX1; ArcInfo.YEnd:=PolyBuf[N].Y-VY1;
 ArcGen:=N;
End;

Procedure DrawArcPoly(N: Integer);
{ Trace PolyBuf[0..N] sans motif de ligne (seule l'epaisseur compte). }
Var I: Integer; SaveP: Word; Full: Boolean;
Begin
 SaveP:=LnPat; LnPat:=$FFFF;
 Full:=(N>=360) Or ((N>2) And (PolyBuf[0].X=PolyBuf[N].X) And (PolyBuf[0].Y=PolyBuf[N].Y));
 PixSetup(WriteOp);
 If N=0 Then Plot(PolyBuf[0].X,PolyBuf[0].Y,CurColor)
 Else
  For I:=1 To N Do
   If (PolyBuf[I].X<>PolyBuf[I-1].X) Or (PolyBuf[I].Y<>PolyBuf[I-1].Y) Then
    LineAbs(PolyBuf[I-1].X,PolyBuf[I-1].Y,PolyBuf[I].X,PolyBuf[I].Y,I>1,Full And (I=N));
 PixDone;
 LnPat:=SaveP;
End;

Function AspRadius(R: Word): Word;
Begin
 AspRadius:=(Longint(R)*AspX+(AspY Div 2)) Div AspY;
End;

Procedure Ellipse(X,Y: Integer; StAngle,EndAngle,XRadius,YRadius: Word);
Var N: Integer;
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 N:=ArcGen(X+VX1,Y+VY1,StAngle,EndAngle,XRadius,YRadius);
 DrawArcPoly(N);
End;

Procedure Arc(X,Y: Integer; StAngle,EndAngle,Radius: Word);
Var N: Integer;
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 N:=ArcGen(X+VX1,Y+VY1,StAngle,EndAngle,Radius,AspRadius(Radius));
 DrawArcPoly(N);
End;

Procedure Circle(X,Y: Integer; Radius: Word);
Begin
 Arc(X,Y,0,360,Radius);
End;

Procedure FillEllipse(X,Y: Integer; XRadius,YRadius: Word);
Var N: Integer;
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 N:=ArcGen(X+VX1,Y+VY1,0,360,XRadius,YRadius);
 ScanFill(@PolyBuf,N,0,0);
 DrawArcPoly(N);
End;

Procedure PieSector(X,Y: Integer; St,En,Rx,Ry: Word);
Var N: Integer; SaveP: Word; CxA,CyA: Integer;
Begin
 CxA:=X+VX1; CyA:=Y+VY1;
 N:=ArcGen(CxA,CyA,St,En,Rx,Ry);
 PolyBuf[N+1].X:=CxA; PolyBuf[N+1].Y:=CyA;
 ScanFill(@PolyBuf,N+2,0,0);
 SaveP:=LnPat; LnPat:=$FFFF;
 PixSetup(WriteOp);
 LineAbs(CxA,CyA,PolyBuf[0].X,PolyBuf[0].Y,False,False);
 PixDone;
 DrawArcPoly(N);
 PixSetup(WriteOp);
 LineAbs(PolyBuf[N].X,PolyBuf[N].Y,CxA,CyA,True,False);
 PixDone;
 LnPat:=SaveP;
End;

Procedure PieSlice(X,Y: Integer; StAngle,EndAngle,Radius: Word);
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 PieSector(X,Y,StAngle,EndAngle,Radius,AspRadius(Radius));
End;

Procedure Sector(X,Y: Integer; StAngle,EndAngle,XRadius,YRadius: Word);
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 PieSector(X,Y,StAngle,EndAngle,XRadius,YRadius);
End;

Procedure GetArcCoords(Var ArcCoords: ArcCoordsType);
Begin
 ArcCoords:=ArcInfo;
End;

{ ===== Texte ===== }

Function CharW: Word;
Var W: Longint;
Begin
 If TxSize=UserCharSize Then W:=(8*Longint(UMX)) Div UDX Else W:=8*Longint(TxSize);
 If W<1 Then W:=1;
 CharW:=W;
End;

Function CharH: Word;
Var H: Longint;
Begin
 If TxSize=UserCharSize Then H:=(8*Longint(UMY)) Div UDY Else H:=8*Longint(TxSize);
 If H<1 Then H:=1;
 CharH:=H;
End;

Function TextWidth(TextString: String): Word;
Begin
 TextWidth:=Length(TextString)*CharW;
End;

Function TextHeight(TextString: String): Word;
Begin
 TextHeight:=CharH;
End;

Procedure SetTextStyle(Font,Direction: Word; CharSize: Word);
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 If Font>10 Then Begin GErr:=grInvalidFontNum; Exit End;
 If Direction>VertDir Then Direction:=HorizDir;
 If CharSize>10 Then CharSize:=10;
 TxFont:=Font; TxDir:=Direction; TxSize:=CharSize;
End;

Procedure GetTextSettings(Var TextInfo: TextSettingsType);
Begin
 TextInfo.Font:=TxFont; TextInfo.Direction:=TxDir; TextInfo.CharSize:=TxSize;
 TextInfo.Horiz:=TxHoriz; TextInfo.Vert:=TxVert;
End;

Procedure SetTextJustify(Horiz,Vert: Word);
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 If (Horiz>RightText) Or (Vert>TopText) Then Begin GErr:=grError; Exit End;
 TxHoriz:=Horiz; TxVert:=Vert;
End;

Procedure SetUserCharSize(MultX,DivX,MultY,DivY: Word);
Begin
 If (DivX=0) Or (DivY=0) Then Exit;
 UMX:=MultX; UDX:=DivX; UMY:=MultY; UDY:=DivY;
End;

Function GlyphRow(Ch,R: Word): Byte;
Begin
 If Ch<128 Then GlyphRow:=Mem[FSeg0:FOfs0+Ch*8+R]
 Else If FSeg1=0 Then GlyphRow:=0
 Else GlyphRow:=Mem[FSeg1:FOfs1+(Ch-128)*8+R];
End;

Procedure DrawStr(X,Y: Integer; S: String);
{ X,Y : coordonnees ecran du point de justification. }
Var CW,CH,BW,BH,X0,Y0,CI,R,C: Integer; Rows: Array[0..7] Of Byte; I: Word;
Begin
 If Length(S)=0 Then Exit;
 CW:=CharW; CH:=CharH;
 If TxDir=HorizDir Then Begin BW:=Length(S)*CW; BH:=CH End
 Else Begin BW:=CH; BH:=Length(S)*CW End;
 Case TxHoriz Of
  LeftText: X0:=X;
  CenterText: X0:=X-BW Div 2;
 Else X0:=X-BW;
 End;
 Case TxVert Of
  TopText: Y0:=Y;
  CenterText: Y0:=Y-BH Div 2;
 Else Y0:=Y-BH;
 End;
 PixSetup(WriteOp);
 For CI:=0 To Length(S)-1 Do Begin
  For I:=0 To 7 Do Rows[I]:=GlyphRow(Ord(S[CI+1]),I);
  For R:=0 To CH-1 Do
   For C:=0 To CW-1 Do
    If (Rows[(R*8) Div CH] And ($80 Shr ((C*8) Div CW)))<>0 Then Begin
     If TxDir=HorizDir Then Plot(X0+CI*CW+C,Y0+R,CurColor)
     Else Plot(X0+R,Y0+BH-1-(CI*CW+C),CurColor);
    End;
 End;
 PixDone;
End;

Procedure OutTextXY(X,Y: Integer; TextString: String);
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 DrawStr(X+VX1,Y+VY1,TextString);
End;

Procedure OutText(TextString: String);
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 DrawStr(CPX+VX1,CPY+VY1,TextString);
 If (TxDir=HorizDir) And (TxHoriz=LeftText) Then Inc(CPX,TextWidth(TextString));
End;

{ ===== Images ===== }

Function PlanesOf: Word;
Begin
 Case Kind Of
  0: PlanesOf:=4;
  1: PlanesOf:=2;
 Else PlanesOf:=1;
 End;
End;

Function ImgBytes(W,H: Longint): Longint;
Begin
 If Kind=4 Then ImgBytes:=4+W*H
 Else ImgBytes:=4+((W+7) Shr 3)*H*PlanesOf;
End;

Function ImageSize(X1,Y1,X2,Y2: Integer): Word;
Var W,H,N: Longint; T: Integer;
Begin
 ImageSize:=0;
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 If X1>X2 Then Begin T:=X1; X1:=X2; X2:=T End;
 If Y1>Y2 Then Begin T:=Y1; Y1:=Y2; Y2:=T End;
 W:=Longint(X2)-X1+1; H:=Longint(Y2)-Y1+1;
 N:=ImgBytes(W,H);
 If N<=65534 Then ImageSize:=N;
End;

Procedure GetImage(X1,Y1,X2,Y2: Integer; Var BitMap);
Var P: PBytes; W,H,BPR,RB,I,J,T,PL,V: Integer; Idx: Longint;
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 If X1>X2 Then Begin T:=X1; X1:=X2; X2:=T End;
 If Y1>Y2 Then Begin T:=Y1; Y1:=Y2; Y2:=T End;
 P:=PBytes(@BitMap);
 W:=X2-X1+1; H:=Y2-Y1+1;
 If ImgBytes(W,H)>65534 Then Begin GErr:=grError; Exit End;
 BPR:=(W+7) Shr 3;
 If Kind=4 Then RB:=W Else RB:=BPR*PlanesOf;
 ClearBytes(@P^[4],Longint(RB)*H);
 P^[0]:=Lo(W-1); P^[1]:=Hi(W-1); P^[2]:=Lo(H-1); P^[3]:=Hi(H-1);
 Inc(X1,VX1); Inc(Y1,VY1);
 For J:=0 To H-1 Do
  For I:=0 To W-1 Do Begin
   V:=0;
   If (X1+I>=0) And (X1+I<ScrW) And (Y1+J>=0) And (Y1+J<ScrH) Then V:=PixGet(X1+I,Y1+J);
   If Kind=4 Then P^[4+Longint(J)*W+I]:=V
   Else If V<>0 Then
    For PL:=0 To PlanesOf-1 Do
     If ((V Shr PL) And 1)<>0 Then Begin
      Idx:=4+Longint(J)*RB+PL*BPR+(I Shr 3);
      P^[Idx]:=P^[Idx] Or ($80 Shr (I And 7));
     End;
  End;
End;

Procedure PutImage(X,Y: Integer; Var BitMap; BitBlt: Word);
Var P: PBytes; W,H,BPR,RB,I,J,PL,V,Op: Integer; Idx: Longint; Inv: Boolean;
Begin
 If Not Active Then Begin GErr:=grNoInitGraph; Exit End;
 If BitBlt>NotPut Then Begin GErr:=grError; Exit End;
 P:=PBytes(@BitMap);
 W:=(P^[0]+P^[1]*256)+1; H:=(P^[2]+P^[3]*256)+1;
 BPR:=(W+7) Shr 3;
 If Kind=4 Then RB:=W Else RB:=BPR*PlanesOf;
 Inv:=BitBlt=NotPut;
 Case BitBlt Of
  XORPut: Op:=3;
  OrPut: Op:=2;
  AndPut: Op:=1;
 Else Op:=0;
 End;
 Inc(X,VX1); Inc(Y,VY1);
 PixSetup(Op);
 For J:=0 To H-1 Do
  For I:=0 To W-1 Do
   If (X+I>=CX1) And (X+I<=CX2) And (Y+J>=CY1) And (Y+J<=CY2) Then Begin
    If Kind=4 Then V:=P^[4+Longint(J)*W+I]
    Else Begin
     V:=0;
     For PL:=0 To PlanesOf-1 Do Begin
      Idx:=4+Longint(J)*RB+PL*BPR+(I Shr 3);
      If (P^[Idx] And ($80 Shr (I And 7)))<>0 Then V:=V Or (1 Shl PL);
     End;
    End;
    If Inv Then V:=(Not V) And MaxCol;
    PixPlot(X+I,Y+J,V);
   End;
 PixDone;
End;

Begin
 Active:=False; Opened:=False; GErr:=0; BufSz:=4096; DacDirty:=False;
 GraphGetMemPtr:=Nil; GraphFreeMemPtr:=Nil;
 ScrW:=640; ScrH:=480; MaxCol:=15; Kind:=0;
End.
