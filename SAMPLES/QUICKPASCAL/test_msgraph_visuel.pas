{ test_msgraph_visuel.pas - Test visuel complet MSGraph                      }
{ Verifie que toutes les fonctions de dessin utilisent la meme fenetre        }
{ que _SetVideoMode. Dessine : cercles, ellipses, rectangles, lignes, pixels. }
{ Compile : TPCW32 --quickpascal test_msgraph_visuel.pas                      }

Program TestMSGraphVisuel;

Uses MSGraph;

Var
  Res : Integer;
  I   : Integer;

Begin
  { Ouvrir la fenetre graphique }
  Res := _SetVideoMode(_VRes16Color);
  If Res = 0 Then
  Begin
    WriteLn('ERREUR: _SetVideoMode a echoue');
    Halt(1);
  End;
  WriteLn('Fenetre ouverte (', Res, ' lignes)');

  { --- Ellipses avec bordure (_GBorder=2) --- }
  _SetColor(_Green);
  _Ellipse(_GBorder, 10, 10, 200, 150);
  WriteLn('Ellipse verte bordure OK');

  { --- Ellipse remplie (_GFillInterior=3) --- }
  _SetColor(_Red);
  _Ellipse(_GFillInterior, 220, 10, 420, 150);
  WriteLn('Ellipse rouge remplie OK');

  { --- Cercle approche (boite carree) --- }
  _SetColor(_Cyan);
  _Ellipse(_GBorder, 440, 10, 620, 190);
  WriteLn('Cercle cyan bordure OK');

  { --- Rectangles --- }
  _SetColor(_Yellow);
  _Rectangle(_GBorder, 10, 170, 200, 290);
  WriteLn('Rectangle jaune bordure OK');

  _SetColor(_Magenta);
  _Rectangle(_GFillInterior, 220, 170, 420, 290);
  WriteLn('Rectangle magenta rempli OK');

  { --- Lignes --- }
  _SetColor(_LightBlue);
  _MoveTo(10, 310);
  _LineTo(630, 310);
  WriteLn('Ligne horizontale bleue OK');

  _SetColor(_LightRed);
  _MoveTo(10, 320);
  _LineTo(630, 460);
  WriteLn('Ligne diagonale rouge OK');

  { --- Pixels --- }
  _SetColor(_White);
  For I := 0 To 59 Do
  Begin
    _SetPixel(I * 10 + 5, 470);
  End;
  WriteLn('60 pixels blancs OK');

  { --- Effacer l ecran --- }
  _ClearScreen(_GClearScreen);
  WriteLn('_ClearScreen OK');

  { --- Redessiner apres clear --- }
  _SetColor(_Green);
  _Ellipse(_GFillInterior, 200, 100, 440, 380);
  WriteLn('Ellipse verte apres clear OK');

  _SetColor(_Yellow);
  _Rectangle(_GBorder, 150, 50, 490, 430);
  WriteLn('Rectangle jaune apres clear OK');

  { --- Fermer --- }
  Res := _SetVideoMode(_DefaultMode);
  If Res <> 0 Then
    WriteLn('ERREUR: _SetVideoMode(_DefaultMode) a retourne ', Res)
  Else
    WriteLn('Fenetre fermee OK');

  WriteLn('OK');
End.
