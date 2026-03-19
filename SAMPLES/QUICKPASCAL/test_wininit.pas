program TestWinInit;
uses Graph;
var
  Gd, Gm: Integer;
begin
  WriteLn('Before InitGraph');
  Gd := Detect;
  InitGraph(Gd, Gm, '');
  WriteLn('After InitGraph');
  CloseGraph;
  WriteLn('After CloseGraph');
end.
