program TestLoops;
var
  i: integer;
  total: integer;
begin
  { Test FOR TO }
  WriteLn('FOR TO:');
  for i := 1 to 5 do
    WriteLn(i);

  { Test FOR DOWNTO }
  WriteLn('FOR DOWNTO:');
  for i := 5 downto 1 do
    WriteLn(i);

  { Test WHILE }
  WriteLn('WHILE:');
  i := 1;
  while i <= 5 do
  begin
    WriteLn(i);
    i := i + 1;
  end;

  { Test REPEAT UNTIL }
  WriteLn('REPEAT:');
  i := 1;
  repeat
    WriteLn(i);
    i := i + 1;
  until i > 5;

  { Test Break }
  WriteLn('BREAK:');
  for i := 1 to 10 do
  begin
    if i = 4 then
      Break;
    WriteLn(i);
  end;

  { Test Continue }
  WriteLn('CONTINUE:');
  for i := 1 to 5 do
  begin
    if i = 3 then
      Continue;
    WriteLn(i);
  end;

  { Test Exit }
  WriteLn('EXIT:');
  Exit;
  WriteLn('NOT REACHED');
end.
