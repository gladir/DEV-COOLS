program TestVarComplete;
var
  x, y, z: integer;
  a, b: char;
  actif: boolean;
begin
  x := 10;
  y := 20;
  z := x + y;
  
  a := 'H';
  b := 'i';
  actif := 1;
  
  writeln('x = ', x);
  writeln('y = ', y); 
  writeln('z = x + y = ', z);
  writeln('Message: ', a, b);
  writeln('Actif: ', actif);
end.
