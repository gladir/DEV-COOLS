{ test_static.pas - STATIC VAR, persistance, VOLATILE }
program test_static;

procedure counter;
static var count : integer := 0;
begin
  count := count + 1;
  writeln('Appel #', count);
end;

var
  i : integer;
  [volatile] flag : integer;
begin
  for i := 1 to 5 do
    counter;

  flag := 1;
  writeln('flag = ', flag);
end.
