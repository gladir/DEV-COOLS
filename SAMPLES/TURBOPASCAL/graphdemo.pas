{ graphdemo.pas - uses Graph: InitGraph, Line, Circle, Bar (TODO 25) }
program GraphDemo;

uses Graph;

var
  Gd, Gm: Integer;
  I: Integer;

begin
  { Initialisation du mode graphique }
  Gd := Detect;
  Gm := 0;
  InitGraph(Gd, Gm, '');

  if GraphResult <> GrOK then
  begin
    WriteLn('Erreur graphique: ', GraphErrorMsg(GraphResult));
    Halt(1);
  end;

  { Dessiner des lignes }
  SetColor(White);
  Line(0, 0, GetMaxX, GetMaxY);
  Line(0, GetMaxY, GetMaxX, 0);

  { Dessiner un rectangle }
  SetColor(Yellow);
  Rectangle(50, 50, 200, 150);

  { Dessiner un cercle }
  SetColor(Cyan);
  Circle(GetMaxX div 2, GetMaxY div 2, 80);

  { Dessiner une barre pleine }
  SetFillStyle(SolidFill, Red);
  Bar(250, 50, 350, 150);

  { Dessiner un arc }
  SetColor(Green);
  Arc(400, 100, 0, 180, 50);

  { Texte graphique }
  SetColor(White);
  OutTextXY(10, GetMaxY - 30, 'Appuyez sur une touche...');

  { Attendre une touche }
  ReadLn;

  { Fermer le mode graphique }
  CloseGraph;
  WriteLn('Done.');
end.
