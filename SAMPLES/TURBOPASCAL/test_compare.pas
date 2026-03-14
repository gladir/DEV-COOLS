program test_compare;
var S1, S2: String;
begin
  S1 := 'ABC';
  S2 := 'DEF';
  if S1 = S2 then WriteLn('equal') else WriteLn('not equal');
end.
