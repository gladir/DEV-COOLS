Program TestArcSleep;
Uses Crt, MsGraph;
Var
 VC:_VideoConfig;
BEGIN
 If (_SetVideoMode(_VRes16Color) > 0) Then
 Begin
  _GetVideoConfig(VC);

  { Draw a big white filled pixel area for visibility }
  _SetColor(15);
  _SetPixel(320, 240);
  _SetPixel(321, 240);
  _SetPixel(322, 240);
  _SetPixel(320, 241);
  _SetPixel(321, 241);

  { Draw line }
  _MoveTo(10, 10);
  _LineTo(630, 470);

  { Draw rectangle }
  _SetColor(14);
  _Rectangle(_GBorder, 50, 50, 590, 430);

  { Draw arc }
  _SetColor(12);
  _Arc(100, 100, 400, 300, 400, 200, 250, 100);

  { Wait 10 seconds so we can see the window }
  Delay(10000);

  If (_SetVideoMode(_DefaultMode) = 0) Then;
 End;
END.
