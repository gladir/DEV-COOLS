{ test_compare_string.pas - Test String comparisons (= and <>) }
{ Compile avec : TPCW32 test_compare_string.pas                 }
{ Verifie que les comparaisons de String fonctionnent            }
{ correctement avec = et <> pour tous les cas importants.        }

program test_compare_string;
var
  S1, S2, S3, S4 : String;
begin
  S1 := 'Hello';
  S2 := 'Hello';
  S3 := 'World';
  S4 := '';

  { Test 1 : deux variables egales }
  if S1 = S2 then WriteLn('T1:OK')
  else WriteLn('T1:FAIL');

  { Test 2 : deux variables differentes }
  if S1 <> S3 then WriteLn('T2:OK')
  else WriteLn('T2:FAIL');

  { Test 3 : variable = literal (egaux) }
  if S1 = 'Hello' then WriteLn('T3:OK')
  else WriteLn('T3:FAIL');

  { Test 4 : variable <> literal (differents) }
  if S1 <> 'Bye' then WriteLn('T4:OK')
  else WriteLn('T4:FAIL');

  { Test 5 : variable = literal (pas egaux) -> false }
  if S1 = 'World' then WriteLn('T5:FAIL')
  else WriteLn('T5:OK');

  { Test 6 : variable <> variable (egaux) -> false }
  if S1 <> S2 then WriteLn('T6:FAIL')
  else WriteLn('T6:OK');

  { Test 7 : chaine vide = chaine vide }
  if S4 = '' then WriteLn('T7:OK')
  else WriteLn('T7:FAIL');

  { Test 8 : chaine vide <> chaine non-vide }
  if S4 <> S1 then WriteLn('T8:OK')
  else WriteLn('T8:FAIL');

  { Test 9 : chaine non-vide <> chaine vide }
  if S1 <> '' then WriteLn('T9:OK')
  else WriteLn('T9:FAIL');

  { Test 10 : sensibilite a la casse }
  S2 := 'hello';
  if S1 <> S2 then WriteLn('T10:OK')
  else WriteLn('T10:FAIL');

  WriteLn('OK');
end.
