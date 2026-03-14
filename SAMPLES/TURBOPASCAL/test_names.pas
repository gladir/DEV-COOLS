program test_names;
var Names: array[1..3] of String;
begin
  Names[1] := 'Alice';
  WriteLn('After 1: ', Names[1]);
  Names[2] := 'Bob';
  WriteLn('After 2: ', Names[2]);
  Names[3] := 'Charlie';
  WriteLn('After 3: ', Names[3]);
  WriteLn('---');
  WriteLn('1: ', Names[1]);
  WriteLn('2: ', Names[2]);
  WriteLn('3: ', Names[3]);
end.
