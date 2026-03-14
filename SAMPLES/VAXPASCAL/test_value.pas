{ test_value.pas - VALUE section, initialisations }
program test_value;

var
  counter : integer;
  name    : varying [20] of char;
  flag    : boolean;

value
  counter := 0;
  name    := 'init';
  flag    := true;

begin
  writeln('counter = ', counter);
  writeln('name    = ', name);
  writeln('flag    = ', flag);

  counter := counter + 1;
  writeln('counter apres +1 = ', counter);
end.
