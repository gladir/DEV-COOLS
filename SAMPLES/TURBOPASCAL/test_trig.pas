{ test_trig.pas - Test des fonctions trigonometriques et transcendantes }
program TestTrig;
var
  N: Integer;
begin
  { Sin (stub: retourne 0 en mode entier) }
  N := Sin(1);
  WriteLn('Sin(1) = ', N);

  { Cos (stub: retourne 1 en mode entier) }
  N := Cos(0);
  WriteLn('Cos(0) = ', N);

  { ArcTan (stub: retourne 0) }
  N := ArcTan(1);
  WriteLn('ArcTan(1) = ', N);

  { Exp (stub: retourne 1) }
  N := Exp(1);
  WriteLn('Exp(1) = ', N);

  { Ln (stub: retourne 0) }
  N := Ln(1);
  WriteLn('Ln(1) = ', N);

  WriteLn('Done.');
end.
