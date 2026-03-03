program TestOperateurs;
var
  a, b: integer;

begin
  a := 10;
  b := 10;
  
  WriteLn('=== Test des opérateurs de comparaison ===');
  
  { Test égalité }
  if a = b then
    WriteLn('a = b : VRAI')
  else
    WriteLn('a = b : FAUX');
    
  { Test différence }  
  if a <> 5 then
    WriteLn('a <> 5 : VRAI')
  else
    WriteLn('a <> 5 : FAUX');
    
  { Test inférieur }
  if a < 15 then
    WriteLn('a < 15 : VRAI')
  else
    WriteLn('a < 15 : FAUX');
    
  { Test supérieur ou égal }
  if a >= 10 then
    WriteLn('a >= 10 : VRAI')
  else
    WriteLn('a >= 10 : FAUX');
    
  { Test inférieur ou égal }
  if b <= 10 then
    WriteLn('b <= 10 : VRAI')
  else
    WriteLn('b <= 10 : FAUX');
    
  WriteLn('Tous les tests terminés !');
end.
