{ test_assert.pas - ASSERT, $OPTIONS CHECK, verifications }
program test_assert;
var
  x, y : integer;
begin
  x := 10;
  y := 10;

  { Assertion vraie - pas d erreur }
  assert(x = y);
  writeln('Assert x = y : OK');

  assert(x > 0);
  writeln('Assert x > 0 : OK');

  assert(x + y = 20);
  writeln('Assert x + y = 20 : OK');

  writeln('Toutes les assertions passees.');
end.
