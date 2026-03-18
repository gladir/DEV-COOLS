Program TestIfCmp;

Uses MsGraph;

Var
 N: Integer;

BEGIN
 N := _SetVideoMode(_VRes16Color);
 WriteLn('N = ', N);
 If (N > 0) Then
   WriteLn('OK: mode video change')
 Else
   WriteLn('ERREUR: retourne 0');

 WriteLn('Test comparaison simple:');
 N := 30;
 If (N > 0) Then
   WriteLn('30 > 0 : OK')
 Else
   WriteLn('30 > 0 : ERREUR');

 If (N < 100) Then
   WriteLn('30 < 100 : OK')
 Else
   WriteLn('30 < 100 : ERREUR');

 _SetVideoMode(_DefaultMode);
END.
