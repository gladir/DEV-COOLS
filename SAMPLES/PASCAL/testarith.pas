program TestArithmetic;
var
  compteur: integer;
  resultat: integer;

begin
  compteur := 1;
  
  WriteLn('=== Test des opérations arithmétiques ===');
  
  { Test addition }
  resultat := compteur + 5;
  Write('1 + 5 = ');
  WriteLn(resultat);
  
  { Test soustraction }
  resultat := resultat - 3;
  Write('6 - 3 = ');
  WriteLn(resultat);
  
  WriteLn('Fin des tests arithmétiques');
end.
