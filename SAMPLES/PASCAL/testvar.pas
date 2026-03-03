program TestVar;
var
  nombre: integer;
  lettre: char;
  mot: string;
  flag: boolean;
  octet: byte;
begin
  nombre := 42;
  lettre := 'A';
  flag := 1;
  octet := 255;
  
  writeln('Nombre: ', nombre);
  writeln('Lettre: ', lettre);
  writeln('Flag: ', flag);
  writeln('Octet: ', octet);
  writeln('Test des variables termine');
end.
