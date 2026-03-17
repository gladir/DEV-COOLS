Program _ArcSamples;
 
Uses MsGraph;
 
Var
 I:Byte;
 VC:_VideoConfig;
 
BEGIN
 If(_SetVideoMode(_VRes16Color) > 0)Then Begin
  _GetVideoConfig(VC);
  For I := 1 to 100 do Begin
   _SetColor(Random(VC.NumColors)+1);
   _Arc(-I*3,-I*3,I*3,I*3,0,I*3,I*3,0);
  End;
  Readln;
  If(_SetVideoMode(_DefaultMode) = 0)Then;
 End
  Else
 WriteLn('Impossible de changer de mode video');
END.