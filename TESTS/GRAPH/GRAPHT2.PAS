{ Test de l'unite Graph integree a TPC (tous les modes, styles, trames, texte, palette, pages).
  Compiler : tpc GRAPHT2.PAS   puis executer sous DOSBox (ex. : mount c <dossier>, GRAPHT2.EXE).
  Resultat : RES.TXT (une ligne "ok ..." ou "ECHEC ..." par controle, puis "Echecs: n"). }
Program GRAPHT2;
Uses Graph;
Var D,M,I,Fails,X,Y,N: Integer; F: Text; P: Pointer; Sz: Word; W1,W2: Word;
    Pal: PaletteType; VP: ViewPortType; FS: FillSettingsType; LS: LineSettingsType;
    TS: TextSettingsType; FP: FillPatternType; Img: File; Row: Array[0..639] of Byte;
Procedure Chk(Name: String; Got, Want: LongInt);
Begin
 If Got<>Want Then Begin Inc(Fails); WriteLn(F,'ECHEC ',Name,' obtenu=',Got,' attendu=',Want) End
 Else WriteLn(F,'ok ',Name);
End;
Procedure ChkB(Name: String; B: Boolean);
Begin
 If Not B Then Begin Inc(Fails); WriteLn(F,'ECHEC ',Name) End Else WriteLn(F,'ok ',Name);
End;
Procedure ChkS(Name,Got,Want: String);
Begin
 If Got<>Want Then Begin Inc(Fails); WriteLn(F,'ECHEC ',Name,' obtenu=',Got,' attendu=',Want) End
 Else WriteLn(F,'ok ',Name);
End;
Function Count(X1,Y1,X2,Y2: Integer; C: Word): LongInt;
Var A,B: Integer; N: LongInt;
Begin
 N:=0;
 For A:=X1 To X2 Do For B:=Y1 To Y2 Do If GetPixel(A,B)=C Then Inc(N);
 Count:=N;
End;
Procedure Dump(Name: String);
Var Y,X: Integer;
Begin
 Assign(Img,Name); Rewrite(Img,1);
 For Y:=0 To GetMaxY Do Begin
  For X:=0 To GetMaxX Do Row[X]:=GetPixel(X,Y);
  BlockWrite(Img,Row,GetMaxX+1);
 End;
 Close(Img);
End;
Procedure Basic(Name: String; DD,MM: Integer);
Var Mx: Word;
Begin
 D:=DD; M:=MM;
 InitGraph(D,M,'');
 Chk(Name+' init',GraphResult,0);
 Mx:=GetMaxColor;
 SetColor(Mx); Line(0,0,GetMaxX,GetMaxY);
 Chk(Name+' diag0',GetPixel(0,0),Mx); Chk(Name+' diagN',GetPixel(GetMaxX,GetMaxY),Mx);
 Chk(Name+' offdiag',GetPixel(0,5),0);
 PutPixel(5,GetMaxY-3,1); Chk(Name+' putpixel',GetPixel(5,GetMaxY-3),1);
 SetColor(1); Rectangle(10,10,40,30);
 Chk(Name+' rect',GetPixel(10,20),1); Chk(Name+' rect in',GetPixel(20,20),0);
 SetFillStyle(SolidFill,Mx); Bar(50,10,70,20); Chk(Name+' bar',GetPixel(60,15),Mx);
 SetFillStyle(SolidFill,1); FloodFill(60,15,Mx); 
 SetColor(1); Circle(100,50,20); Chk(Name+' circ',GetPixel(120,50),1);
 SetFillStyle(SolidFill,Mx); FloodFill(100,50,1); Chk(Name+' floodres',GraphResult,0); Chk(Name+' flood',GetPixel(100,50),Mx);
 Chk(Name+' flood out',GetPixel(130,50),0);
 SetColor(Mx); OutTextXY(150,10,'A');
 Sz:=ImageSize(150,10,157,17);
 GetMem(P,Sz); GetImage(150,10,157,17,P^);
 PutImage(200,10,P^,CopyPut);
 For Y:=0 To 7 Do For X:=0 To 7 Do If GetPixel(150+X,10+Y)<>GetPixel(200+X,10+Y) Then Inc(N);
 Chk(Name+' image copy diff',N,0); N:=0;
 PutImage(200,10,P^,XORPut);
 Chk(Name+' image xor',Count(200,10,207,17,0),64);
 PutImage(200,10,P^,NotPut);
 ChkB(Name+' image not',Count(200,10,207,17,Mx)+Count(200,10,207,17,0)>0);
 FreeMem(P,Sz);
 Dump(Name+'.RAW');
 CloseGraph;
End;
Begin
 Assign(F,'RES.TXT'); Rewrite(F); Fails:=0;
 Basic('vga0',VGA,VGALo);
 Basic('vga1',VGA,VGAMed);
 Basic('vga2',VGA,VGAHi);
 Basic('vga256',VGA,3);
 Basic('ega0',EGA,EGALo);
 Basic('ega1',EGA,EGAHi);
 Basic('cga0',CGA,0);
 Basic('cga3',CGA,3);
 Basic('cgahi',CGA,CGAHi);
 Basic('mcga5',MCGA,MCGAHi);
 { erreurs }
 D:=HercMono; M:=0; InitGraph(D,M,''); Chk('herc err',GraphResult,grInvalidDriver);
 D:=VGA; M:=7; InitGraph(D,M,''); Chk('mode err',GraphResult,grInvalidMode);
 D:=77; M:=0; InitGraph(D,M,''); Chk('drv err',GraphResult,grInvalidDriver);
 Chk('d after',D,grInvalidDriver);
 SetColor(3); Chk('noinit',GraphResult,grNoInitGraph);
 ChkS('msg0',GraphErrorMsg(0),'No error');
 ChkS('msg-10',GraphErrorMsg(-10),'Invalid graphics mode for selected driver');
 ChkS('msg-99',GraphErrorMsg(-99),'Graphics error (-99)');
 D:=Detect; InitGraph(D,M,'');
 Chk('init ok',GraphResult,0);
 ChkS('drvname',GetDriverName,'VGA'); ChkS('modename',GetModeName(2),'640 x 480 VGA');
 Chk('maxmode',GetMaxMode,2); Chk('graphmode',GetGraphMode,2);
 { restore / set mode }
 RestoreCrtMode; SetGraphMode(1); Chk('setgraphmode',GraphResult,0); Chk('maxy350',GetMaxY,349);
 SetGraphMode(2);
 { viewport }
 SetViewPort(100,100,200,200,ClipOn);
 GetViewSettings(VP); Chk('vp x1',VP.X1,100); Chk('vp clip',Ord(VP.Clip),1);
 SetViewPort(100,100,700,200,ClipOn); Chk('vp bad',GraphResult,grError);
 MoveTo(10,10); MoveRel(5,5); Chk('moveto x',GetX,15); Chk('moveto y',GetY,15);
 LineTo(30,15); Chk('lineto',GetPixel(20,15),15); Chk('lineto abs',GetPixel(10+100,15+100),0);
 LineRel(0,10); Chk('linerel',GetY,25);
 SetViewPort(0,0,GetMaxX,GetMaxY,ClipOn);
 Chk('vp abs',GetPixel(120,115),15);
 ClearDevice; Chk('cleared',Count(0,0,639,479,0),640*480);
 { clipoff }
 SetViewPort(100,100,200,200,ClipOff); PutPixel(150,150,5); Chk('clipoff',GetPixel(250,250),0);
 PutPixel(150,150,5); SetViewPort(0,0,GetMaxX,GetMaxY,ClipOn);
 Chk('clipoff abs',GetPixel(250,250),5);
 ClearViewPort; 
 { write mode xor }
 SetColor(White); SetWriteMode(XORPut); Line(10,10,100,10); Line(10,10,100,10);
 Chk('xor line erase',Count(0,0,639,20,0),640*21);
 Rectangle(300,300,400,350); Rectangle(300,300,400,350);
 Chk('xor rect erase',Count(290,290,410,360,0),121*71);
 Circle(300,300,60); Circle(300,300,60);
 Chk('xor circle erase',Count(200,200,400,400,0),LongInt(201)*201);
 SetWriteMode(CopyPut);
 { epaisseur, styles }
 SetLineStyle(SolidLn,0,ThickWidth); Line(10,100,110,100);
 Chk('thick',GetPixel(50,99),15); Chk('thick2',GetPixel(50,101),15); Chk('thick3',GetPixel(50,102),0);
 GetLineSettings(LS); Chk('ls thick',LS.Thickness,3);
 SetLineStyle(DashedLn,0,NormWidth); Line(10,120,41,120);
 Chk('dash count',Count(10,120,41,120,15),20);
 SetLineStyle(UserBitLn,$8000,NormWidth); Line(10,130,41,130);
 Chk('user bit',Count(10,130,41,130,15),2);
 SetLineStyle(SolidLn,0,NormWidth);
 { trames }
 SetFillStyle(HatchFill,Red); GetFillSettings(FS); Chk('fs pat',FS.Pattern,HatchFill); Chk('fs col',FS.Color,4);
 Bar(400,10,431,17); Chk('hatch row y=12b',Count(400,12,431,12,4),32);
 Chk('hatch row y=8',Count(400,8,431,8,4),0); Chk('hatch row y=10',Count(400,10,431,10,4),8); Chk('hatch row y=12',Count(400,12,431,12,4),32);
 For I:=1 To 8 Do FP[I]:=$AA;
 SetFillPattern(FP,Green); GetFillSettings(FS); Chk('userfill',FS.Pattern,UserFill);
 Bar(500,10,515,10); Chk('userpat',Count(500,10,515,10,2),8); Chk('userpat first',GetPixel(500,10),2);
 FillChar(FP,8,0); GetFillPattern(FP); Chk('getfillpat',FP[1],$AA);
 SetFillStyle(EmptyFill,3); Bar(500,10,515,10); Chk('emptyfill',Count(500,10,515,10,0),16);
 SetFillStyle(14,3); Chk('bad fill',GraphResult,grError);
 { Bar3D }
 SetColor(Yellow); SetFillStyle(SolidFill,Blue); Bar3D(100,100,150,140,20,TopOn);
 Chk('bar3d fill',GetPixel(120,120),1); Chk('bar3d edge',GetPixel(100,100),14);
 Chk('bar3d side',GetPixel(160,110),0);
 Chk('bar3d top',GetPixel(140,90),0);
 Chk('bar3d right',GetPixel(170,100),14); Chk('bar3d topedge',GetPixel(130,80),14);
 { ellipse / pie / sector }
 SetColor(White); SetFillStyle(SolidFill,Red);
 FillEllipse(300,300,40,20);
 Chk('fillell in',GetPixel(300,300),4); Chk('fillell edge',GetPixel(340,300),15); Chk('fillell out',GetPixel(341,300),0);
 Chk('fillell top',GetPixel(300,280),15);
 PieSlice(500,300,0,90,40);
 Chk('pie in',GetPixel(520,280),4); Chk('pie edge',GetPixel(540,300),15); Chk('pie out',GetPixel(480,320),0);
 Sector(500,400,180,270,50,30);
 Chk('sector in',GetPixel(480,410),4); Chk('sector edge',GetPixel(450,400),15);
 Ellipse(100,400,0,360,30,10);
 Chk('ellipse',GetPixel(130,400),15); Chk('ellipse t',GetPixel(100,390),15);
 { aspect }
 SetAspectRatio(10000,5000); GetAspectRatio(W1,W2); Chk('asp',W2,5000);
 SetColor(Cyan); Circle(300,100,20);
 Chk('circle asp',GetPixel(300,140),3); Chk('circle asp in',GetPixel(300,110),0); Chk('circle asp x',GetPixel(320,100),3);
 SetAspectRatio(10000,10000);
 { texte }
 ClearDevice; SetColor(White);
 SetTextStyle(DefaultFont,HorizDir,2); GetTextSettings(TS); Chk('ts size',TS.CharSize,2);
 Chk('tw2',TextWidth('AB'),32); Chk('th2',TextHeight('AB'),16);
 SetTextJustify(CenterText,CenterText);
 OutTextXY(320,240,'H');
 ChkB('center H',Count(312,232,327,247,15)>0); Chk('center out',Count(328,232,340,247,15),0);
 SetTextJustify(RightText,BottomText); OutTextXY(100,100,'H');
 ChkB('right/bottom',Count(84,84,99,99,15)>0); Chk('rb out',Count(100,84,120,120,15),0);
 SetTextJustify(LeftText,TopText); SetTextStyle(DefaultFont,VertDir,1);
 OutTextXY(50,150,'AB');
 Chk('vert width',Count(58,134,70,166,15),0); ChkB('vert area',Count(50,134,57,165,15)>0);
 SetTextStyle(DefaultFont,HorizDir,1);
 MoveTo(10,10); OutText('ABCD'); Chk('outtext cp',GetX,42);
 SetTextStyle(DefaultFont,HorizDir,0); SetUserCharSize(3,1,2,1); Chk('usersize w',TextWidth('A'),24); Chk('usersize h',TextHeight('A'),16);
 Chk('gr clean',GraphResult,0);
 { palette }
 GetPalette(Pal); Chk('pal size',Pal.Size,16); Chk('pal6',Pal.Colors[6],20); Chk('pal15',Pal.Colors[15],63);
 SetPalette(1,4); GetPalette(Pal); Chk('setpal',Pal.Colors[1],4);
 SetPalette(1,70); Chk('setpal bad',GraphResult,grError);
 SetBkColor(9); Chk('bkcolor',GetBkColor,9);
 SetBkColor(0);
 SetRGBPalette(2,252,0,0);
 asm
  mov ax,1015h
  mov bx,2
  int 10h
  mov W1,dx
 end;
 { palette[2]=2 -> DAC 2 apres SetRGBPalette: R=63 }
 Chk('rgbpal',W1 shr 8,63);
 GraphDefaults; GetPalette(Pal); Chk('defaults pal',Pal.Colors[1],1);
 SetAspectRatio(1,1);
 GraphDefaults; GetAspectRatio(W1,W2); Chk('defaults asp',W1,10000);
 { pages EGA }
 CloseGraph;
 D:=EGA; M:=EGAHi; InitGraph(D,M,''); 
 SetActivePage(1); PutPixel(5,5,9); SetActivePage(0); Chk('page0 empty',GetPixel(5,5),0);
 SetActivePage(1); Chk('page1 pix',GetPixel(5,5),9);
 SetActivePage(2); Chk('page bad',GraphResult,grError);
 SetVisualPage(1); SetVisualPage(0);
 CloseGraph;
 Chk('after close',GraphResult,0);
 WriteLn(F,'Echecs: ',Fails);
 Close(F);
End.
