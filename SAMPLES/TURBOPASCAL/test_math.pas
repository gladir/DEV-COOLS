{ test_math.pas - Test des fonctions mathematiques }
program TestMath;
var
  N: Integer;
  B: Boolean;
begin
  { Abs }
  N := Abs(-42);
  WriteLn('Abs(-42) = ', N);
  N := Abs(7);
  WriteLn('Abs(7) = ', N);

  { Sqr }
  N := Sqr(5);
  WriteLn('Sqr(5) = ', N);
  N := Sqr(-3);
  WriteLn('Sqr(-3) = ', N);

  { Sqrt }
  N := Sqrt(25);
  WriteLn('Sqrt(25) = ', N);
  N := Sqrt(100);
  WriteLn('Sqrt(100) = ', N);
  N := Sqrt(0);
  WriteLn('Sqrt(0) = ', N);
  N := Sqrt(1);
  WriteLn('Sqrt(1) = ', N);

  { Round/Trunc (integer stubs) }
  N := Round(7);
  WriteLn('Round(7) = ', N);
  N := Trunc(9);
  WriteLn('Trunc(9) = ', N);

  { Odd }
  B := Odd(7);
  WriteLn('Odd(7) = ', B);
  B := Odd(4);
  WriteLn('Odd(4) = ', B);

  { Int (integer mode: identity) }
  N := Int(42);
  WriteLn('Int(42) = ', N);

  { Frac (integer mode: returns 0) }
  N := Frac(42);
  WriteLn('Frac(42) = ', N);

  WriteLn('Done.');
end.
