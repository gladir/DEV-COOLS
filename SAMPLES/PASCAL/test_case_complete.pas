program test_case_complete;
var
  choice: integer;
begin
  choice := 2;
  writeln('Choix:', choice);
  
  case choice of
    1: begin
         writeln('Premier cas');
         writeln('Action 1');
       end;
    2: writeln('Deuxième cas');
    3: writeln('Troisième cas');
  else
    writeln('Cas par défaut');
  end;
  
  writeln('Fin du test CASE');
end.
