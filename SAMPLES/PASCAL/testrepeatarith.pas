program TestRepeatArith;
var
  compteur: integer;

begin
  compteur := 0;
  
  WriteLn('=== Test REPEAT UNTIL avec arithmétique ===');
  WriteLn('Comptage de 0 à 4:');
  
  repeat
    Write('Compteur: ');
    WriteLn(compteur);
    compteur := compteur + 1;
  until compteur > 4;
  
  WriteLn('Boucle terminée !');
end.
