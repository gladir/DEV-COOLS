{ test_unitdemo.pas - Programme utilisant une unite (TODO 23) }
program UnitDemo;

uses
  MathUtils;

var
  A, B, Sum, Prod: Integer;

begin
  A := 5;
  B := 3;
  Sum := Add(A, B);
  Prod := Multiply(A, B);
  WriteLn('A = ', A);
  WriteLn('B = ', B);
  WriteLn('Sum = ', Sum);
  WriteLn('Prod = ', Prod);
  SetLastResult(Sum);
  WriteLn('LastResult = ', LastResult);
  WriteLn('PI = ', PI_VALUE);
end.
