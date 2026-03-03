program TestSimpleIF;
var
  nombre: integer;

begin
  nombre := 15;
  
  if nombre > 10 then
    WriteLn('Supérieur à 10')
  else
    WriteLn('Inférieur ou égal à 10');
end.
