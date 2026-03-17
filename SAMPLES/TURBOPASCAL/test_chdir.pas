{ test_chdir.pas - Test de ChDir et GetDir }
program TestChDir;
var
  OldDir, CurDir: String;
begin
  WriteLn('=== Test ChDir/GetDir ===');
  GetDir(0, OldDir);
  WriteLn('Repertoire initial : ', OldDir);
  MkDir('_TPCTEST');
  ChDir('_TPCTEST');
  GetDir(0, CurDir);
  WriteLn('Apres ChDir : ', CurDir);
  ChDir('..');
  RmDir('_TPCTEST');
  GetDir(0, CurDir);
  WriteLn('Retour : ', CurDir);
  If CurDir = OldDir Then
    WriteLn('OK - repertoire restaure')
  Else
    WriteLn('ERREUR - repertoire different');
  WriteLn('Done.');
end.
