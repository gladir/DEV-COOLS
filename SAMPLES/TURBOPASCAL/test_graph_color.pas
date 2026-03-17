{ test_graph_color.pas - Test Graph color functions }
program test_graph_color;
uses Graph;
begin
  { Test GetMaxColor }
  WriteLn('GetMaxColor = ', GetMaxColor);
  if GetMaxColor = 15 then WriteLn('MaxColor OK') else WriteLn('MaxColor FAIL');

  { Test GetColor / SetColor }
  WriteLn('GetColor = ', GetColor);
  SetColor(12);
  WriteLn('After SetColor(12): GetColor = ', GetColor);
  if GetColor = 12 then WriteLn('SetColor OK') else WriteLn('SetColor FAIL');

  { Test GetBkColor / SetBkColor }
  WriteLn('GetBkColor = ', GetBkColor);
  SetBkColor(4);
  WriteLn('After SetBkColor(4): GetBkColor = ', GetBkColor);
  if GetBkColor = 4 then WriteLn('SetBkColor OK') else WriteLn('SetBkColor FAIL');

  { Test color constants }
  WriteLn('Black=', Black);
  WriteLn('White=', White);
  WriteLn('Red=', Red);
  WriteLn('Yellow=', Yellow);

  WriteLn('OK');
end.
