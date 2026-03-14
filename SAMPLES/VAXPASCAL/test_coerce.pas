{ test_coerce.pas - Coercitions, UNSAFE, SPECIAL(COERCIONS) }
program test_coerce;
var
  i : integer;
  u : unsigned;
  c : char;
  b : boolean;
  p : ^integer;
begin
  i := -1;
  u := i::unsigned;
  writeln('i::unsigned = ', u);

  i := 65;
  c := chr(i);
  writeln('chr(65) = ', c);

  i := ord('Z');
  writeln('ord(Z) = ', i);

  b := true;
  i := ord(b);
  writeln('ord(true) = ', i);

  { Conversion pointeur }
  i := 42;
  p := address(i);
  writeln('address(i) -> p^ = ', p^);

  writeln('Test coercitions termine.');
end.
