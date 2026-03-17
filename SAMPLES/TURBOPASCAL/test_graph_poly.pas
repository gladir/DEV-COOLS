{ test_graph_poly.pas - Test des polygones DrawPoly et FillPoly              }
{ Compile : TPCW32 test_graph_poly.pas                                        }

Program TestGraphPoly;

Uses Graph;

Type
  TPoint = Record X, Y : Integer; End;

Var
  Gd, Gm : Integer;
  T0, T1, T2 : TPoint;          { Triangle }
  Q0, Q1, Q2, Q3 : TPoint;      { Carre }
  D0, D1, D2, D3, D4 : TPoint;  { Pentagone }

Begin
  Gd := Detect;
  Gm := 0;
  InitGraph(Gd, Gm, '');
  If GraphResult <> grOk Then
  Begin
    WriteLn('ERREUR InitGraph: ', GraphErrorMsg(GraphResult));
    Halt(1);
  End;

  { --- Triangle en contour blanc --- }
  SetColor(White);
  T0.X := 320;  T0.Y :=  30;
  T1.X :=  80;  T1.Y := 200;
  T2.X := 560;  T2.Y := 200;
  DrawPoly(3, T0);
  WriteLn('DrawPoly triangle OK');

  { --- Carre rempli jaune --- }
  SetFillStyle(SolidFill, Yellow);
  SetColor(Yellow);
  Q0.X := 50;   Q0.Y := 250;
  Q1.X := 200;  Q1.Y := 250;
  Q2.X := 200;  Q2.Y := 420;
  Q3.X :=  50;  Q3.Y := 420;
  FillPoly(4, Q0);
  WriteLn('FillPoly carre OK');

  { --- Pentagone en contour cyan --- }
  SetColor(Cyan);
  D0.X := 440;  D0.Y := 230;
  D1.X := 560;  D1.Y := 300;
  D2.X := 520;  D2.Y := 430;
  D3.X := 360;  D3.Y := 430;
  D4.X := 320;  D4.Y := 300;
  DrawPoly(5, D0);
  WriteLn('DrawPoly pentagone OK');

  { --- Pentagone rempli rouge --- }
  SetFillStyle(SolidFill, Red);
  SetColor(Red);
  D0.X := 440 + 20;  D0.Y := 240;
  D1.X := 560 + 20;  D1.Y := 310;
  D2.X := 520 + 20;  D2.Y := 440;
  D3.X := 360 + 20;  D3.Y := 440;
  D4.X := 320 + 20;  D4.Y := 310;
  FillPoly(5, D0);
  WriteLn('FillPoly pentagone OK');

  CloseGraph;
  WriteLn('OK');
End.
