{ test_exclude.pas - Test de Exclude sur ensemble d entiers }
program TestExclude;
type
  TByteSet = set of Byte;
var
  S: TByteSet;
begin
  WriteLn('=== Test Exclude (entiers) ===');
  S := [1, 2, 3, 4, 5];
  Exclude(S, 3);
  If Not (3 in S) Then
    WriteLn('Exclude 3 : OK')
  Else
    WriteLn('Exclude 3 : FAIL');

  If (1 in S) And (2 in S) And (4 in S) And (5 in S) Then
    WriteLn('Autres elements intacts : OK')
  Else
    WriteLn('Autres elements intacts : FAIL');

  Include(S, 3);
  If 3 in S Then
    WriteLn('Re-include 3 : OK')
  Else
    WriteLn('Re-include 3 : FAIL');

  WriteLn('Done.');
end.
