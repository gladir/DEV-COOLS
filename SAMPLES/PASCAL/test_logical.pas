program TestLogical;
var
  a, b, result: integer;
begin
  { Test des opérateurs logiques }
  a := 15;   { 1111 en binaire }
  b := 7;    { 0111 en binaire }
  
  { Test AND : 1111 AND 0111 = 0111 = 7 }
  result := a and b;
  writeln('a AND b = ', result);
  
  { Test OR : 1111 OR 0111 = 1111 = 15 }
  result := a or b;
  writeln('a OR b = ', result);
  
  { Test XOR : 1111 XOR 0111 = 1000 = 8 }
  result := a xor b;
  writeln('a XOR b = ', result);
  
  writeln('Test termine');
end.
