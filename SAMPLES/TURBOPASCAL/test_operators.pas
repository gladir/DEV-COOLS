{ test_operators.pas - Operateurs et precedence pour TP2JS }
program TestOperators;
const
  Sum = 3 + 5;
  Diff = 10 - 4;
  Prod = 6 * 7;
  Quot = 100 / 3;
  IntDiv = 17 div 3;
  Modulo = 17 mod 5;
  ShiftL = 1 shl 4;
  ShiftR = 256 shr 2;
  LogAnd = true and false;
  LogOr = true or false;
  LogNot = not true;
  BitXor = 255 xor 128;
  Prec1 = 2 + 3 * 4;
  Prec2 = (2 + 3) * 4;
  Compare1 = 10 = 10;
  Compare2 = 10 <> 5;
  Compare3 = 3 < 5;
  Compare4 = 10 > 5;
  Compare5 = 3 <= 3;
  Compare6 = 5 >= 5;
  Neg = -42;
  Complex = (10 + 5) * 2 - 3 div 2;
var
  X: Integer;
  Y: Integer;
  B: Boolean;
begin
  X := 10 + 5;
  Y := X * 2 - 3;
  B := X > Y;
  X := 100 div 7;
  Y := 100 mod 7;
  X := X shl 1;
  Y := Y shr 1;
  B := (X > 0) and (Y < 100);
  B := (X = 0) or (Y <> 0);
  B := not B;
  X := X xor Y;
  WriteLn('Test operators done');
end.
