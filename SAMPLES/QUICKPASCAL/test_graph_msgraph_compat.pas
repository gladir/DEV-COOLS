{ test_graph_msgraph_compat.pas - Test interoperabilite Graph + MSGraph      }
{ Verifie que les deux unites utilisent la meme fenetre et peuvent se         }
{ melanger librement : InitGraph affecte _SetVideoMode et vice-versa.         }
{ Compile : TPCW32 --quickpascal test_graph_msgraph_compat.pas                }

Program TestGraphMSGraphCompat;

Uses Graph, MSGraph;

Var
  Gd, Gm, Res : Integer;

Begin
  { --- Cas 1 : InitGraph ouvre, _SetVideoMode utilise la meme fenetre --- }
  Gd := Detect;
  Gm := 0;
  InitGraph(Gd, Gm, '');
  If GraphResult <> grOk Then
  Begin
    WriteLn('ERREUR: InitGraph a echoue (GraphResult=', GraphResult, ')');
    Halt(1);
  End;
  WriteLn('InitGraph OK (Gd=', Gd, ', Gm=', Gm, ')');

  { _SetVideoMode doit voir GR_ACTIVE=1 et retourner 25 sans ouvrir de nouveau }
  Res := _SetVideoMode(_VRes16Color);
  If Res <> 25 Then
  Begin
    WriteLn('ERREUR: _SetVideoMode apres InitGraph doit retourner 25, recu ', Res);
    Halt(1);
  End;
  WriteLn('_SetVideoMode apres InitGraph OK (Res=', Res, ')');

  { Dessiner avec Graph BGI }
  SetColor(White);
  Circle(200, 200, 80);
  WriteLn('Circle (Graph) OK');

  { Dessiner avec MSGraph sur la meme fenetre }
  _SetColor(_Green);
  _Ellipse(_GBorder, 350, 100, 550, 300);
  WriteLn('_Ellipse (MSGraph) OK');

  { Dessiner un rectangle avec Graph, puis une ellipse avec MSGraph }
  SetColor(Yellow);
  Rectangle(50, 50, 150, 120);
  _SetColor(_Cyan);
  _Rectangle(_GBorder, 400, 320, 580, 420);
  WriteLn('Mix Rectangle+_Rectangle OK');

  { CloseGraph ferme la fenetre pour les deux unites }
  CloseGraph;
  WriteLn('CloseGraph OK');

  { Verifier que GR_ACTIVE=0 apres CloseGraph : _SetVideoMode doit rouvrir }
  Res := _SetVideoMode(_VRes16Color);
  If Res <> 25 Then
  Begin
    WriteLn('ERREUR: _SetVideoMode apres CloseGraph = ', Res);
    Halt(1);
  End;
  WriteLn('_SetVideoMode apres CloseGraph OK (Res=', Res, ')');

  { Dessiner avec MSGraph }
  _SetColor(_Red);
  _Ellipse(_GFillInterior, 200, 150, 440, 330);
  WriteLn('_Ellipse remplie (MSGraph) OK');

  { InitGraph doit reserver la meme fenetre : GR_ACTIVE=1 }
  Gd := Detect;
  Gm := 0;
  InitGraph(Gd, Gm, '');
  If GraphResult <> grOk Then
  Begin
    WriteLn('ERREUR: InitGraph apres _SetVideoMode echoue');
    Halt(1);
  End;
  WriteLn('InitGraph apres _SetVideoMode OK');

  { Utiliser SetColor et tracer un cercle }
  SetColor(Cyan);
  Circle(320, 240, 120);
  WriteLn('Circle apres InitGraph(re-use) OK');

  { Fermer avec _SetVideoMode(_DefaultMode) }
  Res := _SetVideoMode(_DefaultMode);
  WriteLn('_SetVideoMode(_DefaultMode) OK (Res=', Res, ')');

  WriteLn('OK');
End.
