Program TestArcDebug;
Uses MsGraph;
Var
 VC:_VideoConfig;
BEGIN
 If (_SetVideoMode(_VRes16Color) > 0) Then
 Begin
  _GetVideoConfig(VC);
  WriteLn('Mode set OK, numcolors=', VC.NumColors);

  { Test 1: simple line }
  _SetColor(15);
  _MoveTo(10, 10);
  _LineTo(630, 470);
  WriteLn('Line drawn (white diagonal)');

  { Test 2: rectangle }
  _SetColor(14);
  _Rectangle(_GBorder, 50, 50, 590, 430);
  WriteLn('Rectangle drawn (yellow border)');

  { Test 3: arc with positive coords }
  _SetColor(12);
  _Arc(100, 100, 400, 300, 400, 200, 250, 100);
  WriteLn('Arc drawn (red)');

  { Test 4: another arc }
  _SetColor(10);
  _Arc(200, 150, 500, 350, 500, 250, 350, 150);
  WriteLn('Arc drawn (green)');

  WriteLn('Press Enter to quit...');
  Readln;
  If (_SetVideoMode(_DefaultMode) = 0) Then;
 End
 Else
  WriteLn('Cannot set video mode');
END.
