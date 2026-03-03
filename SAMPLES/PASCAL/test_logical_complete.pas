program TestLogicalComplete;
var
  num1, num2: integer;
begin
  writeln('Test des operateurs logiques');
  
  { Test avec 15 (1111) et 7 (0111) }
  num1 := 15;
  num2 := 7;
  writeln('num1 = 15, num2 = 7');
  
  writeln('AND: ');
  writeln(num1 and num2);  { Devrait afficher 7 }
  
  writeln('OR: ');
  writeln(num1 or num2);   { Devrait afficher 15 }
  
  writeln('XOR: ');
  writeln(num1 xor num2);  { Devrait afficher 8 }
  
  { Test avec constantes }
  writeln('Test avec constantes:');
  writeln('12 AND 10 = ');
  writeln(12 and 10);      { Devrait afficher 8 }
  
  writeln('12 OR 10 = '); 
  writeln(12 or 10);       { Devrait afficher 14 }
  
  writeln('12 XOR 10 = ');
  writeln(12 xor 10);      { Devrait afficher 6 }
end.
