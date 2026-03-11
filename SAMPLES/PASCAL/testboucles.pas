program TestBoucles;
var
  i, j: integer;

begin
  WriteLn('=== Comparaison WHILE vs REPEAT ===');
  
  { Test WHILE - condition testée au début }
  WriteLn('WHILE (condition testée AVANT):');
  i := 5;
  while i < 5 do
  begin
    WriteLn('Cette ligne ne sera jamais affichée');
    i := i + 1;
  end;
  WriteLn('WHILE terminé (aucune itération)');
  
  { Test REPEAT - condition testée à la fin }  
  WriteLn('REPEAT (condition testée APRÈS):');
  j := 5;
  repeat
    WriteLn('Cette ligne sera affichée une fois');
    j := j + 1;
  until j >= 5;
  WriteLn('REPEAT terminé (une itération)');
  
  WriteLn('Fin de la démonstration');
end.
