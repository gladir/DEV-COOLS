{ test_var.pas - Declarations de variables, types de base }
program test_var;
var
  a, b    : integer;
  c       : unsigned;
  d       : boolean;
  ch      : char;
  name    : varying [80] of char;
  ptr     : ^integer;
  w       : [word] integer;
begin
  a := 10;
  b := -5;
  c := 42;
  d := true;
  ch := 'A';
  name := 'VAX Pascal';
  w := 255;
  writeln('a = ', a);
  writeln('b = ', b);
  writeln('c = ', c);
  writeln('d = ', d);
  writeln('ch = ', ch);
  writeln('name = ', name);
end.
