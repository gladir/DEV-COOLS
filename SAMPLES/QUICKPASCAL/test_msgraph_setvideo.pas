{ test_msgraph_setvideo.pas - Exemple _SetVideoMode avec cercles et pixels }
{ Compile avec : TPCW32 --quickpascal test_msgraph_setvideo.pas            }
{ Teste : _SetVideoMode, _SetColor, _Ellipse, _Rectangle, _SetPixel,       }
{         _MoveTo, _LineTo, _ClearScreen, _DefaultMode                      }

Program TestMSGraphSetVideo;

Uses MSGraph;

Var
  Res : Integer;
  I   : Integer;

Begin
  { Ouvrir la fenetre graphique en mode VGA 640x480 }
  Res := _SetVideoMode(_VRes16Color);
  If Res = 0 Then
  Begin
    WriteLn('ERREUR: _SetVideoMode(_VRes16Color) a echoue');
    Halt(1);
  End;
  WriteLn('_SetVideoMode OK (', Res, ' lignes)');

  { Dessiner des cercles (ellipses) de differentes couleurs }
  _SetColor(_Green);
  _Ellipse(_GBorder, 100, 100, 300, 250);
  WriteLn('_Ellipse verte dessinee');

  _SetColor(_Red);
  _Ellipse(_GFillInterior, 320, 150, 520, 350);
  WriteLn('_Ellipse rouge remplie dessinee');

  _SetColor(_LightBlue);
  _Ellipse(_GBorder, 50, 350, 250, 450);
  WriteLn('_Ellipse bleue dessinee');

  { Dessiner un rectangle }
  _SetColor(_Yellow);
  _Rectangle(_GBorder, 350, 300, 600, 450);
  WriteLn('_Rectangle jaune dessine');

  { Dessiner des pixels en diagonale }
  _SetColor(_White);
  For I := 0 To 99 Do
  Begin
    _SetPixel(I * 6, I * 4);
  End;
  WriteLn('100 pixels blancs dessines');

  { Dessiner une ligne }
  _SetColor(_Magenta);
  _MoveTo(0, 0);
  _LineTo(639, 479);
  WriteLn('_LineTo dessinee');

  { Attendre brievement puis fermer }
  _ClearScreen(_GClearScreen);
  WriteLn('_ClearScreen effectue');

  { Fermer la fenetre graphique }
  Res := _SetVideoMode(_DefaultMode);
  WriteLn('_SetVideoMode(_DefaultMode) OK');

  WriteLn('OK');
End.
