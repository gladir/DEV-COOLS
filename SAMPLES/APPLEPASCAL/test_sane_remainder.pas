program test_sane_remainder;
{ Test de Remainder et RandomX de l unite SANE }
Uses SANE;
Var R, Q, X: Integer;
Begin
  WriteLn('--- Remainder ---');
  R := Remainder(17, 5, Q);
  WriteLn('Remainder(17,5): R=', R, ' Q=', Q);
  R := Remainder(100, 7, Q);
  WriteLn('Remainder(100,7): R=', R, ' Q=', Q);
  R := Remainder(10, 3, Q);
  WriteLn('Remainder(10,3): R=', R, ' Q=', Q);
  R := Remainder(25, 5, Q);
  WriteLn('Remainder(25,5): R=', R, ' Q=', Q);

  WriteLn('--- RandomX ---');
  X := 12345;
  WriteLn('Seed = ', X);
  R := RandomX(X);
  WriteLn('RandomX = ', R, ' Seed = ', X);
  R := RandomX(X);
  WriteLn('RandomX = ', R, ' Seed = ', X);
  R := RandomX(X);
  WriteLn('RandomX = ', R, ' Seed = ', X);
End.
