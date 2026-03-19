program TestWinMin;
uses Graph;
var
  Gd, Gm: Integer;
begin
  Gd := Detect;
  InitGraph(Gd, Gm, '');
  SetColor(15);
  OutTextXY(10, 10, 'Window open - will close in 3 seconds');
  Delay(3000);
  CloseGraph;
end.
