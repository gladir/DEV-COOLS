{ Test de l'unite Graph integree a TPC (primitives de base en VGA 640x480).
  Compiler : tpc GRAPHT1.PAS   puis executer sous DOSBox (ex. : mount c
    <dossier>, GRAPHT1.EXE).
  Resultat : RES.TXT (une ligne "ok ..." ou "ECHEC ..." par controle,
    puis "Echecs: n"). }
Program GRAPHT1;
Uses Graph;
Var D,M,I,Fails: Integer; F: Text; P: Pointer; Sz: Word;
  S: Array[0..99] of Byte;
    Img: File; Row: Array[0..639] of Byte; X,Y: Integer; Old: Word;
    A: ArcCoordsType; Pts: Array[0..3] of PointType;
Procedure Chk(Name: String; Got, Want: LongInt);
Begin
 If Got<>Want Then Begin Inc(Fails); WriteLn(F,'ECHEC ',Name,' obtenu=',Got,
   ' attendu=',Want) End
 Else WriteLn(F,'ok ',Name);
End;
Begin
 Assign(F,'RES.TXT'); Rewrite(F); Fails:=0;
 D:=Detect;
 InitGraph(D,M,'');
 Chk('initgraph',GraphResult,0);
 Chk('driver',D,VGA); Chk('mode',M,VGAHi);
 Chk('maxx',GetMaxX,639); Chk('maxy',GetMaxY,479); Chk('maxcolor',GetMaxColor,
   15);
 Chk('getcolor',GetColor,15);
 Chk('palsize',GetPaletteSize,16);
 SetColor(Red);
 Line(0,0,100,100);
 Chk('line mid',GetPixel(50,50),4); Chk('line start',GetPixel(0,0),4);
   Chk('line end',GetPixel(100,100),4);
 Chk('line off',GetPixel(51,50),0);
 PutPixel(200,10,9); Chk('putpixel',GetPixel(200,10),9);
 SetColor(Yellow);
 Rectangle(10,300,60,350);
 Chk('rect tl',GetPixel(10,300),14); Chk('rect br',GetPixel(60,350),14);
 Chk('rect in',GetPixel(30,320),0); Chk('rect top',GetPixel(35,300),14);
 SetColor(LightGreen);
 Circle(300,200,50);
 Chk('circ r',GetPixel(350,200),10); Chk('circ l',GetPixel(250,200),10);
 Chk('circ t',GetPixel(300,150),10); Chk('circ b',GetPixel(300,250),10);
 Chk('circ in',GetPixel(300,200),0);
 SetFillStyle(SolidFill,Blue);
 FloodFill(300,200,LightGreen);
 Chk('flood in',GetPixel(300,200),1); Chk('flood in2',GetPixel(320,230),1);
 Chk('flood border',GetPixel(350,200),10); Chk('flood out',GetPixel(360,200),0);
 SetFillStyle(SolidFill,Magenta);
 Bar(400,100,450,150);
 Chk('bar in',GetPixel(425,125),5); Chk('bar edge',GetPixel(400,100),5);
   Chk('bar edge2',GetPixel(450,150),5);
 Chk('bar out',GetPixel(451,150),0);
 SetFillStyle(LineFill,Cyan);
 Bar(500,100,527,115);
 Chk('linefill r0',GetPixel(501,100),3); Chk('linefill r2',GetPixel(501,102),0);
 { texte }
 SetColor(White);
 OutTextXY(10,400,'HELLO');
 Chk('textwidth',TextWidth('HELLO'),40); Chk('textheight',TextHeight('H'),8);
 { 'H' = $C6,$C6,$C6,$FE,... ligne 0 : bits 7,6,2,1 }
 Chk('text H p0',GetPixel(10,400),15); Chk('text H p2',GetPixel(12,400),0);
 Chk('text H row3',GetPixel(13,403),15);
 { image }
 Sz:=ImageSize(0,0,19,19);
 Chk('imagesize',Sz,4+3*20*4);
 GetMem(P,Sz);
 GetImage(0,0,19,19,P^);
 Old:=GetPixel(10,10);
 PutImage(100,400,P^,CopyPut);
 Chk('putimage',GetPixel(110,410),Old);
 Chk('putimage2',GetPixel(100,400),4);
 PutImage(100,400,P^,XORPut);
 Chk('xor erase',GetPixel(110,410),0);
 { viewport }
 SetViewPort(200,300,300,400,ClipOn);
 PutPixel(0,0,12); Chk('vp pix',GetPixel(0,0),12);
 SetColor(Cyan); Line(-50,-30,150,170);
 Chk('vp clip out',GetPixel(-5,-5),0);
 SetViewPort(0,0,GetMaxX,GetMaxY,ClipOn);
 Chk('vp abs',GetPixel(200,300),12); Chk('vp line',GetPixel(250,370),3);
 Chk('vp abs2',GetPixel(199,299),0);
 { arc coords }
 Arc(300,200,0,90,50);
 GetArcCoords(A);
 Chk('arc x',A.X,300); Chk('arc xs',A.XStart,350); Chk('arc ys',A.YStart,200);
   Chk('arc xe',A.XEnd,300); Chk('arc ye',A.YEnd,150);
 { polygone }
 Pts[0].X:=500; Pts[0].Y:=300; Pts[1].X:=600; Pts[1].Y:=300; Pts[2].X:=550;
   Pts[2].Y:=400; Pts[3].X:=500; Pts[3].Y:=300;
 SetFillStyle(SolidFill,Red); SetColor(White);
 FillPoly(4,Pts);
 Chk('poly in',GetPixel(550,320),4); Chk('poly edge',GetPixel(500,300),15);
 Chk('result',GraphResult,0);
 SetLineStyle(9,0,1); Chk('bad linestyle',GraphResult,grError);
 { dump ecran }
 Assign(Img,'SCREEN.RAW'); Rewrite(Img,1);
 For Y:=0 To 479 Do Begin
  For X:=0 To 639 Do Row[X]:=GetPixel(X,Y);
  BlockWrite(Img,Row,640);
 End;
 Close(Img);
 CloseGraph;
 WriteLn(F,'Echecs: ',Fails);
 Close(F);
End.
