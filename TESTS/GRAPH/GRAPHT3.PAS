{ Test de l'unite Graph integree a TPC (remplissage, polygones, images,
  limites).
  Compiler : tpc GRAPHT3.PAS   puis executer sous DOSBox (ex. : mount c
    <dossier>, GRAPHT3.EXE).
  Resultat : RES.TXT (une ligne "ok ..." ou "ECHEC ..." par controle,
    puis "Echecs: n"). }
Program GRAPHT3;
Uses Graph;
Var D,M,I,J,Fails: Integer; F: Text; P: Pointer; Sz: Word;
  Pts: Array[0..9] of PointType;
    Img: File; Row: Array[0..639] of Byte; X,Y: Integer; N: LongInt;
      Pat: FillPatternType; B: Byte;
Procedure Chk(Name: String; Got, Want: LongInt);
Begin
 If Got<>Want Then Begin Inc(Fails); WriteLn(F,'ECHEC ',Name,' obtenu=',Got,
   ' attendu=',Want) End
 Else WriteLn(F,'ok ',Name);
End;
Function Count(X1,Y1,X2,Y2: Integer; C: Word): LongInt;
Var A,B: Integer; N: LongInt;
Begin
 N:=0;
 For A:=X1 To X2 Do For B:=Y1 To Y2 Do If GetPixel(A,B)=C Then Inc(N);
 Count:=N;
End;
Begin
 Assign(F,'RES.TXT'); Rewrite(F); Fails:=0;
 D:=Detect; InitGraph(D,M,'');
 { serpentin : murs verticaux tous les 4 pixels,
   ouverts alternativement en haut/bas }
 SetColor(Red);
 Rectangle(0,0,639,479);
 I:=4;
 While I<636 Do Begin
  If (I Div 4) And 1=0 Then Line(I,1,I,470) Else Line(I,8,I,478);
  Inc(I,4);
 End;
 SetFillStyle(SolidFill,Green);
 FloodFill(2,2,Red);
 Chk('serpent flood res',GraphResult,0);
 N:=Count(1,1,638,478,0);
 Chk('serpent no black left',N,0);
 { peigne : dents horizontales + FloodFill de gauche a droite (beaucoup de
   graines) }
 ClearDevice; SetColor(Blue);
 Rectangle(0,0,639,479);
 For I:=0 To 99 Do Line(2+I*6,100,2+I*6,400);
 SetFillStyle(SolidFill,Yellow); FloodFill(10,50,Blue);
 Chk('comb res',GraphResult,0);
 Chk('comb filled',GetPixel(5,300),14); Chk('comb tooth',GetPixel(8,300),Blue);
 Chk('comb tooth2',GetPixel(2+50*6,300),Blue);
 { etoile : pair-impair }
 ClearDevice; SetColor(White);
 Pts[0].X:=320; Pts[0].Y:=50; Pts[1].X:=380; Pts[1].Y:=230; Pts[2].X:=230;
   Pts[2].Y:=120;
 Pts[3].X:=410; Pts[3].Y:=120; Pts[4].X:=260; Pts[4].Y:=230;
 SetFillStyle(SolidFill,Red); FillPoly(5,Pts);
 Chk('star tip',GetPixel(320,60),4); Chk('star apex',GetPixel(320,50),15);
 Chk('star arm',GetPixel(250,120),15); Chk('star arm in',GetPixel(250,122),4);
 Chk('star center',GetPixel(320,130),0);
 { DrawPoly ouvert }
 ClearDevice; SetColor(Green);
 Pts[0].X:=10; Pts[0].Y:=10; Pts[1].X:=100; Pts[1].Y:=10; Pts[2].X:=100;
   Pts[2].Y:=100;
 DrawPoly(3,Pts);
 Chk('poly open',GetPixel(50,10),2); Chk('poly open2',GetPixel(100,50),2);
   Chk('poly noclose',GetPixel(50,55),0);
 { cercle epais }
 SetColor(White); SetLineStyle(SolidLn,0,ThickWidth); Circle(300,300,50);
 SetLineStyle(SolidLn,0,NormWidth);
 Chk('thick circ',GetPixel(349,300),15); Chk('thick circ2',GetPixel(350,300),
   15); Chk('thick circ3',GetPixel(351,300),15);
 { texte clippe }
 ClearDevice; SetViewPort(100,100,120,120,ClipOn);
 SetColor(White); SetTextStyle(DefaultFont,HorizDir,3); OutTextXY(0,0,'WWWW');
 SetViewPort(0,0,639,479,ClipOn);
 Chk('text clip out',Count(121,100,300,200,15),0); Chk('text clip below',
   Count(100,121,300,200,15),0);
 If Count(100,100,120,120,15)>0 Then Chk('text clip in',1,
   1) Else Chk('text clip in',0,1);
 { image 13h plein ecran en VGA 16 couleurs : grande image 200x150 }
 ClearDevice; SetFillStyle(SolidFill,LightMagenta); SetColor(Yellow);
 Bar(10,10,209,159); Rectangle(10,10,209,159); Line(10,10,209,159);
 Sz:=ImageSize(10,10,209,159); Chk('bigimg size',Sz,4+25*150*4);
 GetMem(P,Sz); GetImage(10,10,209,159,P^);
 PutImage(300,200,P^,CopyPut);
 N:=0; For Y:=0 To 149 Do For X:=0 To 199 Do If GetPixel(10+X,
   10+Y)<>GetPixel(300+X,200+Y) Then Inc(N);
 Chk('bigimg diff',N,0);
 PutImage(300,200,P^,XORPut);
 Chk('bigimg xor',Count(300,200,499,349,0),30000);
 PutImage(300,200,P^,NotPut);
 Chk('notput',GetPixel(310,300),(Not LightMagenta) And 15);
 PutImage(300,200,P^,OrPut);
 FreeMem(P,Sz);
 { limite taille image }
 Chk('imagesize too big',ImageSize(0,0,639,479),0);
 { GetPixel hors ecran }
 Chk('getpixel off',GetPixel(-5,10),0); Chk('getpixel off2',GetPixel(700,10),0);
 PutPixel(700,10,5); PutPixel(-1,-1,5); Chk('put off ok',GraphResult,0);
 { grande ligne hors ecran }
 SetColor(White); Line(-30000,-20000,30000,20000);
 Chk('huge line',GetPixel(320,213),15);
 Chk('end',GraphResult,0);
 CloseGraph;
 WriteLn(F,'Echecs: ',Fails);
 Close(F);
End.
