program test_control;
{ Test TODO 13 : IF / CASE / GOTO }

label
  Debut, Fin;

var
  n: integer;
  c: char;

begin
  { Test IF / ELSE IF / ELSE }
  n := 3;
  if n = 1 then
    writeln('Un')
  else if n = 2 then
    writeln('Deux')
  else if n = 3 then
    writeln('Trois')
  else
    writeln('Autre');

  { Test IF simple }
  if n > 0 then
    writeln('Positif');

  { Test IF avec BEGIN END }
  if n < 10 then
  begin
    writeln('Petit nombre');
    writeln('n = ', n);
  end
  else
    writeln('Grand nombre');

  { Test CASE simple }
  n := 2;
  case n of
    1: writeln('Un');
    2: writeln('Deux');
    3: writeln('Trois');
  else
    writeln('Autre');
  end;

  { Test CASE avec valeurs multiples }
  c := 'B';
  case c of
    'A', 'E', 'I', 'O', 'U': writeln('Voyelle');
  else
    writeln('Consonne');
  end;

  { Test CASE avec intervalles }
  n := 5;
  case n of
    1, 2: writeln('Un ou Deux');
    3..5: writeln('Trois a Cinq');
    6..10: writeln('Six a Dix');
  else
    writeln('Hors plage');
  end;

  { Test CASE sans ELSE }
  case n of
    1: writeln('Premier');
    5: writeln('Cinquieme');
  end;

  { Test GOTO }
  goto Fin;

Debut:
  writeln('Debut');

Fin:
  writeln('Programme termine');
end.
