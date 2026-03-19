program TestWinKey;
uses Graph;
var
  Gd, Gm: Integer;
  Ch: Char;
begin
  Gd := Detect;
  InitGraph(Gd, Gm, '');

  SetColor(15);
  OutTextXY(10, 10, 'Fenetre graphique ouverte.');
  OutTextXY(10, 30, 'Appuyez sur une touche...');

  { Test ReadKey depuis la fenetre }
  Ch := ReadKey;

  OutTextXY(10, 50, 'Touche recue! Appuyez Enter pour quitter.');

  { Test ReadLn depuis la fenetre }
  ReadLn;

  CloseGraph;
end.
