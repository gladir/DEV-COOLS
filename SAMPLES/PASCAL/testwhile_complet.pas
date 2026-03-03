program TestWhileComplet;
var
  i, somme, limite: integer;
begin
  { Test 1: Boucle WHILE simple avec compteur }
  writeln('=== Test 1: Compteur simple ===');
  i := 1;
  while i <= 3 do
  begin
    writeln('i = ', i);
    i := i + 1;
  end;
  
  { Test 2: Boucle WHILE avec calcul }
  writeln('=== Test 2: Calcul de somme ===');
  i := 1;
  somme := 0;
  limite := 5;
  while i <= limite do
  begin
    somme := somme + i;
    writeln('i = ', i, ', somme = ', somme);
    i := i + 1;
  end;
  writeln('Somme finale: ', somme);
  
  { Test 3: Boucle WHILE avec condition complexe }
  writeln('=== Test 3: Condition complexe ===');
  i := 10;
  while i > 5 do
  begin
    writeln('Decompte: ', i);
    i := i - 2;
  end;
  writeln('Fini! i = ', i);
end.
