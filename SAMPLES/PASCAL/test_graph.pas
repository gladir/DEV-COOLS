program test_graph;
uses Graph;
var
  gd, gm: Integer;
  i: Integer;
begin
  gd := Detect;
  InitGraph(gd, gm, '');

  if GraphResult <> grOk then
  begin
    WriteLn('Erreur graphique: ', GraphErrorMsg(GraphResult));
    Halt(1);
  end;

  WriteLn('MaxX = ', GetMaxX);
  WriteLn('MaxY = ', GetMaxY);
  WriteLn('MaxColor = ', GetMaxColor);

  { Test dessin }
  SetColor(White);
  Line(0, 0, 100, 100);
  Rectangle(10, 10, 200, 150);
  Circle(320, 240, 50);

  { Test remplissage }
  SetFillStyle(SolidFill, Red);
  Bar(250, 50, 350, 100);
  FillEllipse(400, 200, 60, 40);

  { Test texte }
  SetTextStyle(DefaultFont, HorizDir, 1);
  OutTextXY(10, 300, 'Hello Graph!');

  { Test couleurs }
  for i := 0 to 15 do
    PutPixel(i * 10, 400, i);

  { Test deplacement }
  MoveTo(100, 100);
  LineTo(200, 200);
  LineRel(50, -30);

  { Test constantes }
  WriteLn('Detect = ', Detect);
  WriteLn('VGA = ', VGA);
  WriteLn('VGAHi = ', VGAHi);
  WriteLn('SolidFill = ', SolidFill);
  WriteLn('SolidLn = ', SolidLn);
  WriteLn('NormalPut = ', NormalPut);
  WriteLn('grOk = ', grOk);

  { Test arc et secteur }
  Arc(300, 300, 0, 180, 80);
  PieSlice(400, 300, 0, 90, 60);

  { Test 3D }
  Bar3D(50, 350, 120, 400, 10, true);

  { Test stubs }
  SetWriteMode(XORPut);
  SetLineStyle(DottedLn, 0, NormWidth);
  ClearDevice;

  CloseGraph;
  WriteLn('=== Fin test Graph ===');
end.
