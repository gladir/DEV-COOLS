Program TestVCSimple;

Uses MsGraph;

Var
 VC: _VideoConfig;
 N: Integer;

BEGIN
 N := _SetVideoMode(_VRes16Color);
 WriteLn('SetVideoMode returned: ', N);
 _GetVideoConfig(VC);
 N := VC.NumXPixels;
 WriteLn('NumXPixels = ', N);
 N := VC.NumColors;
 WriteLn('NumColors = ', N);
 _SetVideoMode(_DefaultMode);
END.
