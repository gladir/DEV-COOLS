program TestWhileBasic;
var
  i: integer;
begin
  i := 1;
  while i <= 3 do
  begin
    writeln(i);
    i := i + 1;
  end;
end.
