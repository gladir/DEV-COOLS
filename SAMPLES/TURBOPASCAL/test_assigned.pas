{ test_assigned.pas - Test de Assigned, Addr, MaxAvail, MemAvail }
program TestAssigned;
var
  P: Pointer;
  X: LongInt;
  M: LongInt;
begin
  WriteLn('=== Test Assigned/Addr/MaxAvail/MemAvail ===');

  { Test Assigned }
  P := nil;
  If Not Assigned(P) Then
    WriteLn('Assigned(nil) = False: OK')
  Else
    WriteLn('Assigned(nil) = True: FAIL');

  { Allouer un pointeur }
  New(P);
  If Assigned(P) Then
    WriteLn('Assigned(P) = True: OK')
  Else
    WriteLn('Assigned(P) = False: FAIL');
  Dispose(P);

  { Test Addr }
  X := 42;
  P := Addr(X);
  If Assigned(P) Then
    WriteLn('Addr(X) not nil: OK')
  Else
    WriteLn('Addr(X) is nil: FAIL');

  { Test MaxAvail }
  M := MaxAvail;
  If M > 0 Then
    WriteLn('MaxAvail > 0: OK')
  Else
    WriteLn('MaxAvail <= 0: FAIL');

  { Test MemAvail }
  M := MemAvail;
  If M > 0 Then
    WriteLn('MemAvail > 0: OK')
  Else
    WriteLn('MemAvail <= 0: FAIL');

  WriteLn('Done.');
end.
