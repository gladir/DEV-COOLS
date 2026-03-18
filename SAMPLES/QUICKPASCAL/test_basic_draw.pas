Program TestBasicDraw;
Uses MsGraph;
Var VC:_VideoConfig;
BEGIN
 If (_SetVideoMode(_VRes16Color) > 0) Then
 Begin
  _GetVideoConfig(VC);
  _SetColor(15);
  _MoveTo(10,10);
  _LineTo(630,470);
  _SetColor(14);
  _Rectangle(_GBorder, 50, 50, 590, 430);
  _SetColor(12);
  _Arc(100, 100, 540, 380, 540, 240, 320, 100);
  WriteLn('Draw test - press Enter');
  Readln;
  If (_SetVideoMode(_DefaultMode) = 0) Then;
 End
 Else
  WriteLn('Cannot set video mode');
END.
