{ Demonstration de l'unite Graph integree : ecrit GRAPHDEM.RAW (indices de
  couleur 640x480). }
Program GRAPHDEM;
Uses Graph;
Var D,M: Integer; Img: File; Row: Array[0..639] of Byte; X,Y: Integer;
Begin
 D:=Detect; InitGraph(D,M,'');
 SetColor(White);
 OutTextXY(10,10,'Hello, Graph 123');
 SetTextStyle(DefaultFont,HorizDir,3);
 OutTextXY(10,30,'Big text');
 SetTextStyle(DefaultFont,VertDir,2);
 OutTextXY(300,200,'Vertical');
 SetColor(LightRed);
 Line(300,195,300,205); Line(295,200,305,200);
 SetTextStyle(DefaultFont,HorizDir,1);
 SetTextJustify(CenterText,CenterText);
 SetColor(Yellow);
 Line(400,100,400,120); Line(390,110,410,110);
 OutTextXY(400,110,'CENTER');
 SetTextJustify(RightText,BottomText);
 SetColor(LightCyan);
 Line(500,300,500,320); Line(490,310,510,310);
 OutTextXY(500,310,'RIGHTBOTTOM');
 SetTextJustify(LeftText,TopText);
 SetTextStyle(DefaultFont,HorizDir,1);
 SetColor(LightGreen); SetFillStyle(XHatchFill,Blue); Bar3D(100,300,200,380,30,
   TopOn);
 SetFillStyle(InterleaveFill,LightMagenta); PieSlice(300,400,30,300,50);
 SetFillStyle(WideDotFill,Yellow); Sector(450,400,0,200,60,30);
 SetFillStyle(SlashFill,Cyan); FillEllipse(550,400,50,40);
 SetLineStyle(DashedLn,0,NormWidth); SetColor(White); Rectangle(20,120,120,180);
 SetLineStyle(DottedLn,0,ThickWidth); Line(20,200,120,260);
 SetLineStyle(CenterLn,0,NormWidth); Circle(200,200,40);
 SetLineStyle(SolidLn,0,NormWidth); SetColor(LightBlue); Arc(400,200,45,225,50);
   Ellipse(400,200,200,360,70,30);
 Assign(Img,'GRAPHDEM.RAW'); Rewrite(Img,1);
 For Y:=0 To 479 Do Begin
  For X:=0 To 639 Do Row[X]:=GetPixel(X,Y);
  BlockWrite(Img,Row,640);
 End;
 Close(Img);
 CloseGraph;
End.
