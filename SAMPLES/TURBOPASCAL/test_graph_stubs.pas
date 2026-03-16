{ test_graph_stubs.pas - Test Graph stub functions }
program test_graph_stubs;
uses Graph;
begin
  { Test RegisterBGIdriver - stub returns 0 }
  WriteLn('RegisterBGIdriver = ', RegisterBGIdriver(nil));

  { Test RegisterBGIfont - stub returns 0 }
  WriteLn('RegisterBGIfont = ', RegisterBGIfont(nil));

  { Test InstallUserDriver - stub returns 0 }
  WriteLn('InstallUserDriver = ', InstallUserDriver('test.bgi', nil));

  { Test InstallUserFont - stub returns 0 }
  WriteLn('InstallUserFont = ', InstallUserFont('test.chr'));

  { Test SetGraphBufSize - stub }
  SetGraphBufSize(4096);
  WriteLn('SetGraphBufSize done');

  { Test DrawPoly - stub }
  DrawPoly(0, 0);
  WriteLn('DrawPoly done');

  { Test FillPoly - stub }
  FillPoly(0, 0);
  WriteLn('FillPoly done');

  { Test GetViewSettings - stub }
  GetViewSettings(0);
  WriteLn('GetViewSettings done');

  { Test GetLineSettings - stub }
  GetLineSettings(0);
  WriteLn('GetLineSettings done');

  { Test GetFillSettings - stub }
  GetFillSettings(0);
  WriteLn('GetFillSettings done');

  { Test GetFillPattern - stub }
  GetFillPattern(0);
  WriteLn('GetFillPattern done');

  { Test GetTextSettings - stub }
  GetTextSettings(0);
  WriteLn('GetTextSettings done');

  { Test GetArcCoords - stub }
  GetArcCoords(0);
  WriteLn('GetArcCoords done');

  WriteLn('OK');
end.
