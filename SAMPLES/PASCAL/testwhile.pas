program TestWhile;
var
  i: integer;
begin
  i := 1;
  writeln('Debut de la boucle WHILE');
  while i <= 5 do
  begin
    writeln('Iteration: ', i);
    i := i + 1;
  end;
  writeln('Fin de la boucle WHILE');
end.
