program TestCondition;
var
  nombre: integer;
  age: integer;

begin
  nombre := 15;
  age := 25;
  
  WriteLn('=== Test des conditions IF THEN ELSE ===');
  
  { Test simple IF THEN }
  if nombre > 10 then
    WriteLn('Le nombre est supérieur à 10');
  
  { Test IF THEN ELSE }
  if age >= 18 then
    WriteLn('Vous êtes majeur')
  else
    WriteLn('Vous êtes mineur');
    
  { Test imbriqué }
  if nombre < 20 then
  begin
    WriteLn('Nombre inférieur à 20');
    if nombre > 5 then
      WriteLn('Et supérieur à 5')
    else
      WriteLn('Et inférieur ou égal à 5');
  end
  else
    WriteLn('Nombre supérieur ou égal à 20');
    
  WriteLn('Fin des tests');
end.
