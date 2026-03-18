Program TestArcPump;
Uses MsGraph;
Var
 VC:_VideoConfig;
 I:Byte;
BEGIN
 If (_SetVideoMode(_VRes16Color) > 0) Then
 Begin
  _GetVideoConfig(VC);
  _SetColor(15);
  _MoveTo(10, 10);
  _LineTo(630, 470);
  _SetColor(14);
  _Rectangle(_GBorder, 50, 50, 590, 430);
  For I := 1 to 50 do Begin
   _SetColor(Random(VC.NumColors)+1);
   _Arc(320-I*3, 240-I*3, 320+I*3, 240+I*3, 320+I*3, 240, 320, 240-I*3);
  End;
  WriteLn('Arcs drawn. Press Enter...');
  Readln;
  If (_SetVideoMode(_DefaultMode) = 0) Then;
 End
 Else
  WriteLn('Cannot set video mode');
END.
