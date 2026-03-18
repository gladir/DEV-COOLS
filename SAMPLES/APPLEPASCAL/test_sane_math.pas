program test_sane_math;
{ Test des fonctions arithmetiques et elementaires de l unite SANE }
Uses SANE;
Var R: Integer;
Begin
  WriteLn('--- Fonctions identite (mode entier) ---');
  R := Rint(42);
  WriteLn('Rint(42) = ', R);
  R := Rint(-3);
  WriteLn('Rint(-3) = ', R);

  WriteLn('--- Log2 / Logb ---');
  R := Log2(1);
  WriteLn('Log2(1) = ', R);
  R := Log2(2);
  WriteLn('Log2(2) = ', R);
  R := Log2(16);
  WriteLn('Log2(16) = ', R);
  R := Log2(255);
  WriteLn('Log2(255) = ', R);
  R := Log2(1024);
  WriteLn('Log2(1024) = ', R);
  R := Logb(8);
  WriteLn('Logb(8) = ', R);

  WriteLn('--- Exp2 ---');
  R := Exp2(0);
  WriteLn('Exp2(0) = ', R);
  R := Exp2(1);
  WriteLn('Exp2(1) = ', R);
  R := Exp2(3);
  WriteLn('Exp2(3) = ', R);
  R := Exp2(10);
  WriteLn('Exp2(10) = ', R);
  R := Exp2(20);
  WriteLn('Exp2(20) = ', R);

  WriteLn('--- Scalb ---');
  R := Scalb(0, 42);
  WriteLn('Scalb(0,42) = ', R);
  R := Scalb(3, 5);
  WriteLn('Scalb(3,5) = ', R);
  R := Scalb(-2, 100);
  WriteLn('Scalb(-2,100) = ', R);
  R := Scalb(1, 7);
  WriteLn('Scalb(1,7) = ', R);

  WriteLn('--- XpwrI / XpwrY ---');
  R := XpwrI(2, 0);
  WriteLn('XpwrI(2,0) = ', R);
  R := XpwrI(2, 10);
  WriteLn('XpwrI(2,10) = ', R);
  R := XpwrI(3, 3);
  WriteLn('XpwrI(3,3) = ', R);
  R := XpwrI(5, 4);
  WriteLn('XpwrI(5,4) = ', R);
  R := XpwrY(2, 8);
  WriteLn('XpwrY(2,8) = ', R);

  WriteLn('--- Compound ---');
  R := Compound(1, 3);
  WriteLn('Compound(1,3) = ', R);
  R := Compound(0, 5);
  WriteLn('Compound(0,5) = ', R);
  R := Compound(2, 2);
  WriteLn('Compound(2,2) = ', R);

  WriteLn('--- Stubs (mode entier) ---');
  R := Tan(45);
  WriteLn('Tan(45) = ', R);
  R := Ln1(5);
  WriteLn('Ln1(5) = ', R);
  R := Exp1(3);
  WriteLn('Exp1(3) = ', R);
  R := NAN(1);
  WriteLn('NAN(1) = ', R);
  R := Annuity(1, 5);
  WriteLn('Annuity(1,5) = ', R);
End.
