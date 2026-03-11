Program PercentTest(Output);

{ Test %DESCR, %REF, %STDESCR, %IMMED as tokens }
Var
  Chan : Integer;
  Stat : Integer;

Begin
  { Simulated VMS system call with % passing mechanisms }
  Stat := SYS$CREMBX(%IMMED 0, Chan, %IMMED 256, %IMMED 256);
  WriteLn('Status=', Stat);
  WriteLn(%DESCR 'Hello');
End.
