program test_expr;
const
  MAX = 100;
  PI_APPROX = 3;
var
  x, y, z: integer;
  c: char;
  b: boolean;
  s: string;
begin
  { Affectation d'entier }
  x := 42;
  y := 0;
  z := -1;

  { Affectation depuis constante }
  x := MAX;

  { Affectation depuis variable }
  y := x;

  { Affectation de caractere }
  c := Chr(65);

  { Booleen }
  b := True;
  b := False;

  { Chaine }
  s := 'Hello World';

  { SizeOf }
  x := SizeOf(Integer);

  { Ord / Chr }
  x := Ord('A');
  c := Chr(66);

  { Succ / Pred }
  x := Succ(5);
  y := Pred(10);

  { Abs / Sqr }
  x := Abs(-7);
  y := Sqr(3);

  { Odd }
  b := Odd(5);

  { Lo / Hi }
  x := Lo(256);
  y := Hi(256);

  { Inc / Dec }
  x := 10;
  Inc(x);
  Dec(x);
  Inc(x, 5);
  Dec(x, 3);

  { Appel de procedure sans args }
  WriteLn;

  { Appel de procedure avec args }
  Write(42);
  WriteLn(x);
  Write('Test');

  { Exit }
  { Exit; }
end.
