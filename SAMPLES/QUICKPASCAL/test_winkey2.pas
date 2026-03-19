program TestWinKey2;
uses Graph;
var
  Gd, Gm: Integer;
  Ch: Char;
  K: Boolean;
begin
  Gd := Detect;
  InitGraph(Gd, Gm, '');

  SetColor(15);
  OutTextXY(10, 10, 'Test clavier fenetre graphique');
  OutTextXY(10, 30, '1) KeyPressed retourne False (pas de touche):');

  { Test KeyPressed sans touche pressee - ne doit pas bloquer }
  K := KeyPressed;
  if K then
    OutTextXY(10, 50, '   ECHEC (True inattendu)')
  else
    OutTextXY(10, 50, '   OK (False)');

  OutTextXY(10, 80, '2) Appuyez une touche pour ReadKey...');
  Ch := ReadKey;
  OutTextXY(10, 100, '   Touche recue par ReadKey!');

  OutTextXY(10, 130, '3) Appuyez Enter pour ReadLn...');
  ReadLn;
  OutTextXY(10, 150, '   ReadLn termine!');

  OutTextXY(10, 180, 'Tous les tests OK. Appuyez une touche pour quitter.');
  Ch := ReadKey;

  CloseGraph;
end.
