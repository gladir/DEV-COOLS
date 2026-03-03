program TestProgram(Input, Output);
uses
  DOS, CRT;

var
  message: string;
  count: integer;

begin
  writeln('Programme de test complet');
  writeln('Support de PROGRAM avec paramètres');
  writeln('Support de USES');
  count := 42;
  writeln('Nombre: ', count);
end.
