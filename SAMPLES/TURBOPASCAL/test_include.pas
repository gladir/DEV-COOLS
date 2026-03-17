{ test_include.pas - Test de Include et Exclude }
program TestInclude;
type
  TCharSet = set of Char;
var
  S: TCharSet;
begin
  WriteLn('=== Test Include/Exclude ===');
  S := [];
  Include(S, 'A');
  If 'A' in S Then
    WriteLn('Include A : OK')
  Else
    WriteLn('Include A : FAIL');

  Include(S, 'B');
  Include(S, 'C');
  If ('B' in S) And ('C' in S) Then
    WriteLn('Include B,C : OK')
  Else
    WriteLn('Include B,C : FAIL');

  Exclude(S, 'B');
  If Not ('B' in S) Then
    WriteLn('Exclude B : OK')
  Else
    WriteLn('Exclude B : FAIL');

  If 'A' in S Then
    WriteLn('A still in set : OK')
  Else
    WriteLn('A still in set : FAIL');

  WriteLn('Done.');
end.
