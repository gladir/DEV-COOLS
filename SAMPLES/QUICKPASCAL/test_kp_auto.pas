program TestKPAuto;
uses Graph, Crt;
var
  Gd, Gm: Integer;
begin
  Gd := Detect;
  InitGraph(Gd, Gm, '');
  WriteLn('InitGraph OK');

  { Test KeyPressed sans touche - ne doit pas bloquer, retourne False }
  if KeyPressed then
    WriteLn('ECHEC: KeyPressed=True sans touche')
  else
    WriteLn('OK: KeyPressed=False');

  Delay(500);
  WriteLn('Delay OK');

  CloseGraph;
  WriteLn('CloseGraph OK');
end.
