program TestLogicalWorking;
var
  num1, num2, result: integer;
begin
  writeln('Test des operateurs logiques');
  
  num1 := 15;
  num2 := 7;
  writeln('Nombres: 15 et 7');
  
  { Test AND }
  result := num1 and num2;
  writeln('AND result:');
  writeln(result);
  
  { Test OR }
  result := num1 or num2;
  writeln('OR result:');
  writeln(result);
  
  { Test XOR }
  result := num1 xor num2;
  writeln('XOR result:');
  writeln(result);
  
  { Test avec constantes }
  result := 12 and 10;
  writeln('12 AND 10:');
  writeln(result);
  
  result := 12 or 10;
  writeln('12 OR 10:');
  writeln(result);
  
  result := 12 xor 10;
  writeln('12 XOR 10:');
  writeln(result);
end.
