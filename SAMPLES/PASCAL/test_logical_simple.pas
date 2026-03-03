program TestLogicalSimple;
var
  val1, val2, res: integer;
begin
  val1 := 15;
  val2 := 7;
  
  res := val1 and val2;
  writeln('AND result: ', res);
  
  res := val1 or val2;
  writeln('OR result: ', res);
  
  res := val1 xor val2;
  writeln('XOR result: ', res);
end.
