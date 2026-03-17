{ test_compare_dirstr.pas - Test DirStr/PathStr comparison (= and <>) }
{ Compile avec : TPCW32 test_compare_dirstr.pas                       }
{ Verifie que les comparaisons de DirStr et PathStr fonctionnent       }
{ correctement avec = et <> (bug corrige par TypeIsString).            }

program test_compare_dirstr;
var
  D1, D2 : DirStr;
  P1, P2 : PathStr;
begin
  { DirStr = String[67] }
  D1 := 'C:\TOOLS';
  D2 := 'C:\TOOLS';

  if D1 = D2 then WriteLn('T1:OK')
  else WriteLn('T1:FAIL');

  D2 := 'D:\OTHER';
  if D1 <> D2 then WriteLn('T2:OK')
  else WriteLn('T2:FAIL');

  if D1 = 'C:\TOOLS' then WriteLn('T3:OK')
  else WriteLn('T3:FAIL');

  { PathStr = String[79] }
  P1 := 'C:\TOOLS\FILE.EXE';
  P2 := 'C:\TOOLS\FILE.EXE';

  if P1 = P2 then WriteLn('T4:OK')
  else WriteLn('T4:FAIL');

  P2 := 'D:\OTHER\FILE.COM';
  if P1 <> P2 then WriteLn('T5:OK')
  else WriteLn('T5:FAIL');

  if P1 = 'C:\TOOLS\FILE.EXE' then WriteLn('T6:OK')
  else WriteLn('T6:FAIL');

  WriteLn('OK');
end.
