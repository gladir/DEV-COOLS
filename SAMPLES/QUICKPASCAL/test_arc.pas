Program TestArc;

Uses MsGraph;

Var
 VC: _VideoConfig;

BEGIN
 If (_SetVideoMode(_VRes16Color) > 0) Then
 Begin
  _GetVideoConfig(VC);
  _SetColor(15);
  _Arc(100, 100, 400, 400, 400, 250, 250, 100);
  _SetColor(14);
  _Arc(50, 50, 300, 300, 300, 175, 175, 50);
  _SetColor(12);
  _Arc(200, 200, 500, 400, 500, 300, 350, 200);
  WriteLn('Arcs dessines - Appuyez sur Entree');
  Readln;
  If (_SetVideoMode(_DefaultMode) = 0) Then;
 End
 Else
  WriteLn('Impossible de changer de mode video');
END.
