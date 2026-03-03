program TestString;
var
  msg1: string;
  msg2: string;
  result: string;

begin
  msg1 := 'Hello';
  msg2 := 'World';
  
  writeln('Test des chaînes de caractères:');
  writeln('msg1 = ', msg1);
  writeln('msg2 = ', msg2);
  
  { Test de concaténation }
  result := msg1 + ' ' + msg2;
  writeln('Concaténation: ', result);
  
  { Test de chaîne littérale }
  writeln('Chaîne littérale: ''Bonjour Pascal!''');
end.
