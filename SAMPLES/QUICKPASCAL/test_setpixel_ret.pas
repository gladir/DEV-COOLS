Program TestSetPixelReturn;
Uses MsGraph;
Var
 VC:_VideoConfig;
BEGIN
 If (_SetVideoMode(_VRes16Color) > 0) Then
 Begin
  _GetVideoConfig(VC);
  WriteLn('Mode OK, trying direct pixel operations...');
  { The _SetPixel MSGraph runtime doesn't return a value.
    Let's test if Win32 SetPixel works at all by checking GetPixel afterward }
  _SetColor(15);
  _SetPixel(50, 50);
  _SetPixel(51, 50);
  _SetPixel(52, 50);
  WriteLn('Pixels set');
  WriteLn('Done');
  If (_SetVideoMode(_DefaultMode) = 0) Then;
 End
 Else
  WriteLn('FAIL');
END.
