program test_for;
var
  i: integer;
begin
  writeln('Test boucle FOR TO:');
  for i := 1 to 5 do
    writeln(i);
    
  writeln('Test boucle FOR DOWNTO:');
  for i := 5 downto 1 do
    writeln(i);
    
  writeln('Fin du programme');
end.
