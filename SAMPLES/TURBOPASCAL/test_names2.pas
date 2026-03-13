program test_names2;
var Names: array[1..3] of String;
begin
  Names[1] := 'Alice';
  Names[2] := 'Bob';
  Names[3] := 'Charlie';
  WriteLn(Names[1]);
  WriteLn(Names[2]);
  WriteLn(Names[3]);
  WriteLn('---Rewrite 1---');
  Names[1] := 'REPLACED';
  WriteLn(Names[1]);
  WriteLn(Names[2]);
  WriteLn(Names[3]);
end.
