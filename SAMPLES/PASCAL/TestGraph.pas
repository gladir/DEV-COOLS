{ TestGraph.pas - Test de l unite Graph pour TPCW32 (TODO 20) }
program TestGraph;
uses Graph;
var
  Gd, Gm: Integer;
begin
  Gd := Detect;
  InitGraph(Gd, Gm, '');
  if GraphResult <> 0 then
  begin
    WriteLn('Erreur graphique');
    Halt(1);
  end;
  SetColor(15);
  PutPixel(100, 100, 14);
  Line(0, 0, 639, 479);
  Rectangle(50, 50, 200, 150);
  Circle(320, 240, 100);
  Bar(400, 300, 500, 400);
  SetFillStyle(1, 12);
  FillEllipse(320, 240, 80, 50);
  OutTextXY(10, 10, 'Hello Graph!');
  MoveTo(0, 0);
  LineTo(100, 100);
  ClearDevice;
  SetBkColor(1);
  CloseGraph;
end.
