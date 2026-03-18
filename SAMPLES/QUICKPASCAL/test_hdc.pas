Program TestHDC;
Uses MsGraph;
Var
 VC:_VideoConfig;
 HDCVal: LongInt;
 HwndVal: LongInt;
BEGIN
 If (_SetVideoMode(_VRes16Color) > 0) Then
 Begin
  _GetVideoConfig(VC);
  WriteLn('Mode set OK');
  WriteLn('numcolors=', VC.NumColors);

  { Try to read GR_HDC and GR_HWND values }
  { These are global variables - we need inline ASM or some way to read them }
  { Use SetPixel and check return: if SetPixel returns CLR_INVALID (-1), DC is invalid }
  _SetColor(15);
  _SetPixel(100, 100);
  _SetPixel(101, 100);
  _SetPixel(102, 100);
  _SetPixel(100, 101);
  _SetPixel(101, 101);

  { Test with Graph unit SetPixel which calls Win32 SetPixel directly }
  { Also test LineTo }
  _MoveTo(0, 0);
  _LineTo(639, 479);

  WriteLn('Drawing done. Waiting 5 seconds...');
  Delay(5000);
  WriteLn('Done');
  If (_SetVideoMode(_DefaultMode) = 0) Then;
 End
 Else
  WriteLn('SetVideoMode FAILED');
END.
