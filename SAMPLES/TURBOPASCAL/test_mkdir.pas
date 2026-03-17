{ test_mkdir.pas - Test de MkDir et RmDir }
program TestMkDir;
var
  S: String;
begin
  WriteLn('=== Test MkDir/RmDir ===');
  MkDir('_TESTDIR1');
  WriteLn('MkDir _TESTDIR1 ok');
  ChDir('_TESTDIR1');
  GetDir(0, S);
  WriteLn('Inside: ', S);
  ChDir('..');
  RmDir('_TESTDIR1');
  WriteLn('RmDir _TESTDIR1 ok');
  WriteLn('Done.');
end.
