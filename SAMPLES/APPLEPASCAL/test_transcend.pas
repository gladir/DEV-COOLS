program test_transcend;
{ Test des fonctions de l unite TRANSCEND (Apple Pascal) }
Uses TRANSCEND;
Var R: Integer;
Begin
  WriteLn('--- Test TRANSCEND unit ---');

  { ATan - arc tangente (equivalent a ArcTan) }
  R := ATan(1);
  WriteLn('ATan(1) = ', R);

  { Cos - cosinus }
  R := Cos(0);
  WriteLn('Cos(0) = ', R);

  { Sin - sinus }
  R := Sin(0);
  WriteLn('Sin(0) = ', R);

  { Sqrt - racine carree }
  R := Sqrt(16);
  WriteLn('Sqrt(16) = ', R);

  R := Sqrt(100);
  WriteLn('Sqrt(100) = ', R);

  R := Sqrt(144);
  WriteLn('Sqrt(144) = ', R);

  { Ln - logarithme neperien }
  R := Ln(1);
  WriteLn('Ln(1) = ', R);

  { Log - logarithme base 10 }
  R := Log(1);
  WriteLn('Log(1) = ', R);

  R := Log(10);
  WriteLn('Log(10) = ', R);

  R := Log(100);
  WriteLn('Log(100) = ', R);

  R := Log(1000);
  WriteLn('Log(1000) = ', R);

  R := Log(9999);
  WriteLn('Log(9999) = ', R);

  { PwrOfTen - puissance de 10 }
  R := PwrOfTen(0);
  WriteLn('PwrOfTen(0) = ', R);

  R := PwrOfTen(1);
  WriteLn('PwrOfTen(1) = ', R);

  R := PwrOfTen(2);
  WriteLn('PwrOfTen(2) = ', R);

  R := PwrOfTen(3);
  WriteLn('PwrOfTen(3) = ', R);

  R := PwrOfTen(5);
  WriteLn('PwrOfTen(5) = ', R);

  WriteLn('Done.');
End.
