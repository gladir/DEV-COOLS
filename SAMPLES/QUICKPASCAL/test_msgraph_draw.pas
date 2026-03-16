{ test_msgraph_draw.pas - Test MSGraph drawing procedures (QuickPascal mode) }
program test_msgraph_draw;
uses MSGraph;
begin
  { Test _MoveTo }
  _MoveTo(100, 200);
  WriteLn('_MoveTo(100,200) done');

  { Test _LineTo }
  _LineTo(300, 400);
  WriteLn('_LineTo(300,400) done');

  { Test _Rectangle }
  _Rectangle(_GBorder, 10, 10, 200, 100);
  WriteLn('_Rectangle done');

  { Test _Ellipse }
  _Ellipse(_GFillInterior, 50, 50, 150, 100);
  WriteLn('_Ellipse done');

  { Test _ClearScreen }
  _ClearScreen(_GClearScreen);
  WriteLn('_ClearScreen done');

  { Test _SetPixel }
  _SetPixel(50, 50);
  WriteLn('_SetPixel done');

  { Test _FloodFill }
  _FloodFill(100, 100, 15);
  WriteLn('_FloodFill done');

  { Test _SetVideoMode (stub) }
  WriteLn('_SetVideoMode=', _SetVideoMode(_VRes16Color));

  WriteLn('OK');
end.
