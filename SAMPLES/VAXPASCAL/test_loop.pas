{ test_loop.pas - FOR, WHILE, REPEAT, LOOP..END, BY }
program test_loop;
var
  i, sum : integer;
begin
  { FOR classique }
  sum := 0;
  for i := 1 to 10 do
    sum := sum + i;
  writeln('Sum 1..10 = ', sum);

  { FOR avec BY (pas de 2) }
  writeln('Nombres impairs :');
  for i := 1 to 20 by 2 do
    write(i, ' ');
  writeln;

  { FOR DOWNTO }
  writeln('Decompte :');
  for i := 5 downto 1 do
    write(i, ' ');
  writeln;

  { WHILE }
  i := 1;
  sum := 0;
  while i <= 100 do
  begin
    sum := sum + i;
    i := i + 1;
  end;
  writeln('Sum 1..100 = ', sum);

  { REPEAT..UNTIL }
  i := 10;
  repeat
    write(i, ' ');
    i := i - 1;
  until i = 0;
  writeln;

  { LOOP..EXIT..END }
  i := 0;
  loop
    i := i + 1;
    if i > 5 then
      exit;
    write(i, ' ');
  end;
  writeln;
end.
