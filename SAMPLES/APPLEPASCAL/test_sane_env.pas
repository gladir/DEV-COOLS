program test_sane_env;
{ Test des routines d acces environnement et procedures SANE }
Uses SANE;
Var
  E: Integer;
  S: String;
Begin
  WriteLn('--- Routines d environnement ---');

  SetException(Invalid, True);
  WriteLn('SetException(Invalid,True) ok');
  SetException(Overflow, False);
  WriteLn('SetException(Overflow,False) ok');

  WriteLn('TestException(Invalid) = ', TestException(Invalid));
  WriteLn('TestHalt(Underflow) = ', TestHalt(Underflow));

  SetHalt(Invalid, True);
  WriteLn('SetHalt(Invalid,True) ok');

  SetRound(0);
  WriteLn('SetRound(ToNearest) ok');
  WriteLn('GetRound = ', GetRound);

  SetPrecision(0);
  WriteLn('SetPrecision(ExtPrecision) ok');
  WriteLn('GetPrecision = ', GetPrecision);

  E := 99;
  SetEnvironment(E);
  WriteLn('SetEnvironment(99) ok');

  E := 99;
  GetEnvironment(E);
  WriteLn('GetEnvironment: E = ', E);

  E := 99;
  ProcEntry(E);
  WriteLn('ProcEntry: E = ', E);

  ProcExit(0);
  WriteLn('ProcExit(0) ok');

  WriteLn('GetHaltVector = ', GetHaltVector);

  SetHaltVector(0);
  WriteLn('SetHaltVector(0) ok');

  WriteLn('--- Num2Str ---');
  Num2Str(0, 42, S);
  WriteLn('Num2Str(0,42): S = ', S);
  Num2Str(0, -7, S);
  WriteLn('Num2Str(0,-7): S = ', S);
  Num2Str(0, 0, S);
  WriteLn('Num2Str(0,0): S = ', S);
  Num2Str(0, 12345, S);
  WriteLn('Num2Str(0,12345): S = ', S);

  WriteLn('--- Stub procedures ---');
  Num2Dec(0, 42, E);
  WriteLn('Num2Dec ok');
  Str2Dec('123', E, E, True);
  WriteLn('Str2Dec ok');
  Dec2Str(0, 0, S);
  WriteLn('Dec2Str ok');
End.
