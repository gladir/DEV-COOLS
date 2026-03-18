program test_sane_compare;
{ Test des fonctions de comparaison, signe et classification SANE }
Uses SANE;
Var R: Integer;
Begin
  WriteLn('--- SignNum ---');
  R := SignNum(-100);
  WriteLn('SignNum(-100) = ', R);
  R := SignNum(0);
  WriteLn('SignNum(0) = ', R);
  R := SignNum(50);
  WriteLn('SignNum(50) = ', R);

  WriteLn('--- CopySign ---');
  R := CopySign(5, -3);
  WriteLn('CopySign(5,-3) = ', R);
  R := CopySign(-5, 3);
  WriteLn('CopySign(-5,3) = ', R);
  R := CopySign(5, 3);
  WriteLn('CopySign(5,3) = ', R);

  WriteLn('--- NextReal / NextDouble / NextExtended ---');
  R := NextReal(5, 10);
  WriteLn('NextReal(5,10) = ', R);
  R := NextReal(5, 1);
  WriteLn('NextReal(5,1) = ', R);
  R := NextReal(5, 5);
  WriteLn('NextReal(5,5) = ', R);
  R := NextDouble(10, 20);
  WriteLn('NextDouble(10,20) = ', R);
  R := NextExtended(10, 5);
  WriteLn('NextExtended(10,5) = ', R);

  WriteLn('--- Relation ---');
  R := Relation(10, 5);
  WriteLn('Relation(10,5) = ', R);
  R := Relation(5, 10);
  WriteLn('Relation(5,10) = ', R);
  R := Relation(7, 7);
  WriteLn('Relation(7,7) = ', R);

  WriteLn('--- ClassReal / ClassDouble / ClassComp / ClassExtended ---');
  R := ClassReal(0);
  WriteLn('ClassReal(0) = ', R);
  R := ClassReal(42);
  WriteLn('ClassReal(42) = ', R);
  R := ClassDouble(0);
  WriteLn('ClassDouble(0) = ', R);
  R := ClassComp(99);
  WriteLn('ClassComp(99) = ', R);
  R := ClassExtended(0);
  WriteLn('ClassExtended(0) = ', R);
  R := ClassExtended(-1);
  WriteLn('ClassExtended(-1) = ', R);
End.
