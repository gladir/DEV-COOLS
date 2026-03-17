{ test_compare_pchar.pas - Test PChar comparisons (= and <>) }
{ Compile avec : TPCW32 test_compare_pchar.pas                }
{ Verifie que les comparaisons de PChar fonctionnent           }
{ correctement avec = et <> pour tous les cas importants.      }

program test_compare_pchar;
var
  P1, P2, P3 : PChar;
begin
  P1 := 'Hello';
  P2 := 'Hello';
  P3 := 'World';

  { Test 1 : deux PChar egaux }
  if P1 = P2 then WriteLn('T1:OK')
  else WriteLn('T1:FAIL');

  { Test 2 : deux PChar differents }
  if P1 <> P3 then WriteLn('T2:OK')
  else WriteLn('T2:FAIL');

  { Test 3 : PChar = literal }
  if P1 = 'Hello' then WriteLn('T3:OK')
  else WriteLn('T3:FAIL');

  { Test 4 : PChar <> literal }
  if P1 <> 'Bye' then WriteLn('T4:OK')
  else WriteLn('T4:FAIL');

  { Test 5 : PChar = literal (pas egaux) -> false }
  if P1 = 'World' then WriteLn('T5:FAIL')
  else WriteLn('T5:OK');

  { Test 6 : PChar <> PChar (egaux) -> false }
  if P1 <> P2 then WriteLn('T6:FAIL')
  else WriteLn('T6:OK');

  { Test 7 : sensibilite a la casse }
  P2 := 'hello';
  if P1 <> P2 then WriteLn('T7:OK')
  else WriteLn('T7:FAIL');

  WriteLn('OK');
end.
