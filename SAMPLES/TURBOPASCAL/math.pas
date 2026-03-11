{ math.pas - fonctions mathematiques, expressions, Real (TODO 25) }
program MathDemo;

var
  A, B, C: Integer;
  X, Y: Real;
  R: Real;

begin
  A := 10;
  B := 3;
  C := A + B * 2;
  WriteLn('A = ', A);
  WriteLn('B = ', B);
  WriteLn('C = A + B * 2 = ', C);

  WriteLn('A div B = ', A div B);
  WriteLn('A mod B = ', A mod B);

  X := 2.5;
  Y := 1.5;
  R := X + Y;
  WriteLn('X + Y = ', R:6:2);
  R := X * Y;
  WriteLn('X * Y = ', R:6:2);
  R := X - Y;
  WriteLn('X - Y = ', R:6:2);

  WriteLn('Abs(-5) = ', Abs(-5));
  WriteLn('Sqr(4) = ', Sqr(4));
  WriteLn('Odd(7) = ', Odd(7));

  WriteLn('Done.');
end.
