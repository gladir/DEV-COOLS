{ test_cseg.pas - Test de CSeg, DSeg, SSeg, SPtr }
program TestCSeg;
var
  C, D, SS, SP: Word;
begin
  WriteLn('=== Test CSeg/DSeg/SSeg/SPtr ===');
  C := CSeg;
  D := DSeg;
  SS := SSeg;
  SP := SPtr;
  WriteLn('CSeg = ', C);
  WriteLn('DSeg = ', D);
  WriteLn('SSeg = ', SS);
  WriteLn('SPtr = ', SP);
  { En Win32 flat mode, CSeg/DSeg/SSeg retournent 0 }
  { SPtr retourne une valeur non nulle (pointeur de pile) }
  If SP <> 0 Then
    WriteLn('SPtr non nul : OK')
  Else
    WriteLn('SPtr nul : ATTENTION');
  WriteLn('Done.');
end.
