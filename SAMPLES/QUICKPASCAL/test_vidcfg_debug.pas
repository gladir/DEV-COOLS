Program TestVidCfgDebug;

Uses MsGraph;

Var
 VC: _VideoConfig;
 N: Integer;

BEGIN
 { Appeler SetVideoMode }
 N := _SetVideoMode(_VRes16Color);
 WriteLn('SetVideoMode returned: ', N);

 { Lire chaque champ un par un }
 _GetVideoConfig(VC);

 WriteLn('NumXPixels   = ', VC.NumXPixels);
 WriteLn('NumYPixels   = ', VC.NumYPixels);
 WriteLn('NumTextCols  = ', VC.NumTextCols);
 WriteLn('NumTextRows  = ', VC.NumTextRows);
 WriteLn('NumColors    = ', VC.NumColors);
 WriteLn('BitsPerPixel = ', VC.BitsPerPixel);
 WriteLn('NumVideoPages= ', VC.NumVideoPages);
 WriteLn('Mode         = ', VC.Mode);
 WriteLn('Adapter      = ', VC.Adapter);
 WriteLn('Monitor      = ', VC.Monitor);
 WriteLn('Memory       = ', VC.Memory);

 { Fermer le mode graphique }
 _SetVideoMode(_DefaultMode);
END.
