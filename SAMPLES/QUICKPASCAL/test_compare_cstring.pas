{ test_compare_cstring.pas - Test CString comparisons (= and <>) }
{ Compile avec : TPCW32 --quickpascal test_compare_cstring.pas    }
{ Verifie que les comparaisons de CString fonctionnent             }
{ correctement avec = et <> pour tous les cas importants.          }

program test_compare_cstring;

uses MSGraph;

var
  C1, C2, C3 : CString;
begin
  C1 := 'Hello';
  C2 := 'Hello';
  C3 := 'World';

  { Test 1 : deux CString egaux }
  if C1 = C2 then WriteLn('T1:OK')
  else WriteLn('T1:FAIL');

  { Test 2 : deux CString differents }
  if C1 <> C3 then WriteLn('T2:OK')
  else WriteLn('T2:FAIL');

  { Test 3 : CString = literal }
  if C1 = 'Hello' then WriteLn('T3:OK')
  else WriteLn('T3:FAIL');

  { Test 4 : CString <> literal }
  if C1 <> 'Bye' then WriteLn('T4:OK')
  else WriteLn('T4:FAIL');

  { Test 5 : CString = literal (pas egaux) -> false }
  if C1 = 'World' then WriteLn('T5:FAIL')
  else WriteLn('T5:OK');

  { Test 6 : CString <> CString (egaux) -> false }
  if C1 <> C2 then WriteLn('T6:FAIL')
  else WriteLn('T6:OK');

  { Test 7 : sensibilite a la casse }
  C2 := 'hello';
  if C1 <> C2 then WriteLn('T7:OK')
  else WriteLn('T7:FAIL');

  WriteLn('OK');
end.
