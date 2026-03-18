program test_sane_numconv;
{ Test des fonctions de conversion numerique de l unite SANE }
Uses SANE;
Var R: Integer;
Begin
  WriteLn('--- Conversion entre types numeriques binaires ---');
  R := Num2Integer(42);
  WriteLn('Num2Integer(42) = ', R);
  R := Num2Integer(-7);
  WriteLn('Num2Integer(-7) = ', R);
  R := Num2Longint(1000);
  WriteLn('Num2Longint(1000) = ', R);
  R := Num2Real(100);
  WriteLn('Num2Real(100) = ', R);
  R := Num2Double(55);
  WriteLn('Num2Double(55) = ', R);
  R := Num2Extended(99);
  WriteLn('Num2Extended(99) = ', R);
  R := Num2Comp(33);
  WriteLn('Num2Comp(33) = ', R);

  WriteLn('--- Conversion chaine/nombre ---');
  R := Str2Num('123');
  WriteLn('Str2Num(123) = ', R);
  R := Str2Num('-42');
  WriteLn('Str2Num(-42) = ', R);
  R := Str2Num('0');
  WriteLn('Str2Num(0) = ', R);
End.
