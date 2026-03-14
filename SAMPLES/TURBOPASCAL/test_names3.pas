program TestNames3;
var
  Names: array[1..3] of String;
begin
  Names[1] := 'Alice';
  Names[2] := 'Bob';
  Names[3] := 'Charlie';
  WriteLn('N1=', Names[1]);
  WriteLn('N2=', Names[2]);
  WriteLn('N3=', Names[3]);
end.
