program TestWhileSimple;
var
  i, somme: integer;
begin
  writeln('Test WHILE avec operations arithmetiques');
  i := 1;
  somme := 0;
  while i <= 5 do
  begin
    writeln('i = ');
    writeln(i);
    somme := somme + i;
    writeln('somme = ');
    writeln(somme);
    i := i + 1;
  end;
  writeln('Resultat final: ');
  writeln(somme);
end.
