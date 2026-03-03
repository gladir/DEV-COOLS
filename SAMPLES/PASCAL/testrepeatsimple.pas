program TestRepeatSimple;
var
  compteur: integer;

begin
  compteur := 1;
  
  WriteLn('=== Test simple REPEAT UNTIL ===');
  
  repeat
    Write('Compteur: ');
    WriteLn(compteur);
    compteur := 5; { Pour sortir de la boucle }
  until compteur > 3;
  
  WriteLn('Boucle terminée');
end.
