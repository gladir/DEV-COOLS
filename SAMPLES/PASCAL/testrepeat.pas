program TestRepeat;
var
  compteur: integer;
  nombre: integer;

begin
  compteur := 1;
  nombre := 5;
  
  WriteLn('=== Test des boucles REPEAT UNTIL ===');
  
  { Test simple REPEAT UNTIL }
  WriteLn('Comptage de 1 à 5:');
  repeat
    Write('Compteur: ');
    WriteLn(compteur);
    compteur := compteur + 1;
  until compteur > nombre;
  
  WriteLn('Fin du comptage');
  
  { Test REPEAT UNTIL avec condition complexe }
  compteur := 10;
  WriteLn('Décompte de 10 à 0:');
  repeat
    Write('Valeur: ');
    WriteLn(compteur);
    compteur := compteur - 1;
  until compteur <= 0;
  
  WriteLn('Tous les tests terminés !');
end.
