Program TestRecordWrite;

Uses MsGraph;

Var
 VC: _VideoConfig;

BEGIN
 VC.NumXPixels := 999;
 VC.NumColors := 42;
 WriteLn('NumXPixels = ', VC.NumXPixels);
 WriteLn('NumColors  = ', VC.NumColors);
END.
