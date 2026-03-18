program test_sane_const;
{ Test des constantes de l unite SANE (Apple Pascal) }
Uses SANE;
Begin
  WriteLn('DecStrLen = ', DecStrLen);
  WriteLn('SigDigLen = ', SigDigLen);
  WriteLn('Invalid   = ', Invalid);
  WriteLn('Underflow = ', Underflow);
  WriteLn('Overflow  = ', Overflow);
  WriteLn('DivByZero = ', DivByZero);
  WriteLn('Inexact   = ', Inexact);
End.
