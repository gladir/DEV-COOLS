Program TestSetPixelDiag;
Uses MsGraph;
Var
 VC:_VideoConfig;
BEGIN
 If (_SetVideoMode(_VRes16Color) > 0) Then
 Begin
  _GetVideoConfig(VC);
  WriteLn('SETVIDEOMODE OK');

  { Try to set a pixel and verify }
  _SetColor(15);
  _SetPixel(50, 50);

  { The problem might be that _SetPixel uses GR_COLOR palette lookup wrong
    or the GDI coordinates are clipped. Let's also test on other routines }
  _MoveTo(10, 10);
  _LineTo(100, 100);

  _SetColor(14);
  _Rectangle(_GBorder, 20, 20, 200, 200);

  WriteLn('Done');
  If (_SetVideoMode(_DefaultMode) = 0) Then;
 End
 Else
  WriteLn('FAIL');
END.
