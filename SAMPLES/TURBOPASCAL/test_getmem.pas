{ test_getmem.pas - Test de GetMem/FreeMem }
program TestGetMem;
var
  P: Pointer;
begin
  WriteLn('=== Test GetMem/FreeMem ===');
  GetMem(P, 256);
  WriteLn('GetMem(P, 256) ok');
  If P <> nil Then
    WriteLn('P is not nil: OK')
  Else
    WriteLn('P is nil: FAIL');
  FreeMem(P, 256);
  WriteLn('FreeMem(P, 256) ok');
  WriteLn('Done.');
end.
