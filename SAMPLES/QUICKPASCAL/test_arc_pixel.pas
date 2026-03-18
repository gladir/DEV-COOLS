Program TestArcPixel;
Uses MsGraph;
Var
 VC:_VideoConfig;
 PxColor: LongInt;
BEGIN
 If (_SetVideoMode(_VRes16Color) > 0) Then
 Begin
  _GetVideoConfig(VC);

  { Draw white pixel at known location }
  _SetColor(15);
  _SetPixel(200, 200);

  { Read it back }
  PxColor := _GetPixel(200, 200);
  WriteLn('Pixel at (200,200) after SetPixel: ', PxColor);

  { Draw white arc centered in window }
  _SetColor(15);
  _Arc(100, 100, 500, 400, 500, 250, 300, 100);

  { The arc bounding rect is (100,100)-(500,400), center at (300,250)
    Start direction: (500,250) = right of center
    End direction: (300,100) = above center
    CCW from right to top: goes through bottom half
    The arc should pass through approximately (400, 350) or similar }

  { Read pixels along expected arc path }
  PxColor := _GetPixel(500, 250);
  WriteLn('Pixel near start of arc (500,250): ', PxColor);
  PxColor := _GetPixel(300, 400);
  WriteLn('Pixel near bottom of arc (300,400): ', PxColor);
  PxColor := _GetPixel(100, 250);
  WriteLn('Pixel near left of arc (100,250): ', PxColor);
  PxColor := _GetPixel(300, 100);
  WriteLn('Pixel near end of arc (300,100): ', PxColor);

  { Also sample the center (should be black/0) }
  PxColor := _GetPixel(300, 250);
  WriteLn('Pixel at center (300,250): ', PxColor);

  { Test a simple line }
  _SetColor(14);
  _MoveTo(10, 10);
  _LineTo(630, 470);
  PxColor := _GetPixel(320, 240);
  WriteLn('Pixel on line (320,240): ', PxColor);

  WriteLn('Done');
  If (_SetVideoMode(_DefaultMode) = 0) Then;
 End
 Else
  WriteLn('Cannot set video mode');
END.
