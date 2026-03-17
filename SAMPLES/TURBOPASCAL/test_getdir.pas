{ test_getdir.pas - Test de GetDir }
program TestGetDir;
var
  S: String;
begin
  WriteLn('=== Test GetDir ===');
  GetDir(0, S);
  WriteLn('Repertoire courant : ', S);
  If Length(S) > 0 Then
    WriteLn('OK - chaine non vide')
  Else
    WriteLn('ERREUR - chaine vide');
  WriteLn('Done.');
end.
