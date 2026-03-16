{ test_graph_pos.pas - Test Graph position and dimension functions }
program test_graph_pos;
uses Graph;
begin
  { Test GetMaxX / GetMaxY }
  WriteLn('GetMaxX = ', GetMaxX);
  WriteLn('GetMaxY = ', GetMaxY);
  if GetMaxX = 639 then WriteLn('MaxX OK') else WriteLn('MaxX FAIL');
  if GetMaxY = 479 then WriteLn('MaxY OK') else WriteLn('MaxY FAIL');

  { Test GetX / GetY (initially 0) }
  WriteLn('GetX = ', GetX);
  WriteLn('GetY = ', GetY);
  if GetX = 0 then WriteLn('X OK') else WriteLn('X FAIL');
  if GetY = 0 then WriteLn('Y OK') else WriteLn('Y FAIL');

  { Test MoveTo }
  MoveTo(100, 200);
  WriteLn('After MoveTo(100,200): X=', GetX, ' Y=', GetY);
  if (GetX = 100) and (GetY = 200) then WriteLn('MoveTo OK')
  else WriteLn('MoveTo FAIL');

  { Test MoveRel }
  MoveRel(50, -30);
  WriteLn('After MoveRel(50,-30): X=', GetX, ' Y=', GetY);
  if (GetX = 150) and (GetY = 170) then WriteLn('MoveRel OK')
  else WriteLn('MoveRel FAIL');

  WriteLn('OK');
end.
