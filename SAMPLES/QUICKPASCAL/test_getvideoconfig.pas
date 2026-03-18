Program TestGetVideoConfig;

Uses MsGraph;

Var
 VC: _VideoConfig;

BEGIN
 If (_SetVideoMode(_VRes16Color) > 0) Then Begin
   _GetVideoConfig(VC);
   WriteLn('numxpixels  = ', VC.NumXPixels);
   WriteLn('numypixels  = ', VC.NumYPixels);
   WriteLn('numtextcols = ', VC.NumTextCols);
   WriteLn('numtextrows = ', VC.NumTextRows);
   WriteLn('numcolors   = ', VC.NumColors);
   WriteLn('bitsperpixel= ', VC.BitsPerPixel);
   WriteLn('numvideopages=', VC.NumVideoPages);
   WriteLn('mode        = ', VC.Mode);
   WriteLn('adapter     = ', VC.Adapter);
   WriteLn('monitor     = ', VC.Monitor);
   WriteLn('memory      = ', VC.Memory);
   _SetVideoMode(_DefaultMode);
 End
 Else
   WriteLn('Impossible de changer de mode video');
END.
