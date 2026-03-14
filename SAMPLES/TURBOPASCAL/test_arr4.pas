program TestArr4;
var
  A: array[1..3] of Integer;
begin
  A[1] := 111;
  A[2] := 222;
  A[3] := 333;
  WriteLn('A1=', A[1]);
  WriteLn('A2=', A[2]);
  WriteLn('A3=', A[3]);
end.
