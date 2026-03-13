program TestArr5;
var
  A: array[1..3] of String;
begin
  A[1] := 'Alice';
  WriteLn('After A1:');
  WriteLn('A1=', A[1]);
  A[2] := 'Bob';
  WriteLn('After A2:');
  WriteLn('A1=', A[1]);
  WriteLn('A2=', A[2]);
  A[3] := 'Charlie';
  WriteLn('After A3:');
  WriteLn('A1=', A[1]);
  WriteLn('A2=', A[2]);
  WriteLn('A3=', A[3]);
end.
