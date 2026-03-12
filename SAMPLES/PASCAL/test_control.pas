program test_control;

var
  i, j, n, somme: integer;

begin
  WriteLn('=== Test structures de controle (TODO 13) ===');

  { --- IF THEN ELSE --- }
  n := 10;
  if n > 5 then
    WriteLn('IF simple: n > 5');

  if n > 20 then
    WriteLn('ERREUR: ne devrait pas afficher')
  else
    WriteLn('IF ELSE: n <= 20');

  if n > 100 then
    WriteLn('ERREUR')
  else if n > 50 then
    WriteLn('ERREUR')
  else
    WriteLn('IF ELSE IF: n <= 50');

  if n > 5 then
  begin
    WriteLn('IF BEGIN END: bloc 1');
    WriteLn('IF BEGIN END: bloc 2');
  end;

  { --- WHILE DO --- }
  i := 1;
  while i <= 3 do
  begin
    Write('WHILE: i=');
    WriteLn(i);
    i := i + 1;
  end;

  { --- REPEAT UNTIL --- }
  i := 1;
  repeat
    Write('REPEAT: i=');
    WriteLn(i);
    i := i + 1;
  until i > 3;

  { --- FOR TO DO --- }
  for i := 1 to 3 do
  begin
    Write('FOR: i=');
    WriteLn(i);
  end;

  { --- FOR DOWNTO DO --- }
  for i := 3 downto 1 do
  begin
    Write('DOWNTO: i=');
    WriteLn(i);
  end;

  { --- CASE OF --- }
  n := 2;
  case n of
    1: WriteLn('CASE: un');
    2: WriteLn('CASE: deux');
    3: WriteLn('CASE: trois');
  else
    WriteLn('CASE: autre');
  end;

  { --- CASE avec BEGIN END --- }
  n := 1;
  case n of
    1: begin
         WriteLn('CASE BEGIN: premier');
         WriteLn('CASE BEGIN: suite');
       end;
    2: WriteLn('CASE: deuxieme');
  end;

  { --- Boucles imbriquees --- }
  for i := 1 to 2 do
    for j := 1 to 2 do
    begin
      Write('IMBRIQUE: i=');
      Write(i);
      Write(' j=');
      WriteLn(j);
    end;

  { --- Somme avec FOR --- }
  somme := 0;
  for i := 1 to 10 do
    somme := somme + i;
  Write('SOMME 1..10 = ');
  WriteLn(somme);

  WriteLn('=== Fin des tests ===');
end.
