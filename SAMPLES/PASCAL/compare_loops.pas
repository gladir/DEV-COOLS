program ComparaisonWhileRepeat;
var
  i: integer;
begin
  writeln('=== Test WHILE ===');
  i := 10;
  while i < 10 do
  begin
    writeln('Ceci ne devrait pas s afficher');
    i := i + 1;
  end;
  writeln('WHILE termine, i = 10');
  
  writeln('=== Test REPEAT ===');  
  i := 10;
  repeat
    writeln('Ceci s affiche au moins une fois');
    i := i + 1;
  until i >= 11;
  writeln('REPEAT termine');
end.
