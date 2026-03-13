{ unitdemo.pas - UNIT + PROGRAM utilisant l'unite (TODO 25) }
{ Ce fichier est le PROGRAM qui utilise l'unite MathUnit    }
program UnitDemo;

uses
  MathUnit;

var
  A, B, R: Integer;
  X: Real;

begin
  A := 10;
  B := 3;

  R := MathAdd(A, B);
  WriteLn('MathAdd(', A, ', ', B, ') = ', R);

  R := MathSub(A, B);
  WriteLn('MathSub(', A, ', ', B, ') = ', R);

  R := MathMul(A, B);
  WriteLn('MathMul(', A, ', ', B, ') = ', R);

  R := MathMax(A, B);
  WriteLn('MathMax(', A, ', ', B, ') = ', R);

  R := MathMin(A, B);
  WriteLn('MathMin(', A, ', ', B, ') = ', R);

  X := MathAvg(A, B);
  WriteLn('MathAvg(', A, ', ', B, ') = ', X:6:2);

  WriteLn('MathPI = ', MathPI:10:8);

  WriteLn('Done.');
end.
