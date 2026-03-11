program test_dos;
uses Dos;
var
  Y, M, D, DOW: Word;
  H, Mi, S, S100: Word;
  Env: String;
  EC: Integer;
begin
  WriteLn('=== Test DOS Unit ===');

  { Test constantes attributs fichier }
  WriteLn('ReadOnly = ', ReadOnly);
  WriteLn('Hidden = ', Hidden);
  WriteLn('SysFile = ', SysFile);
  WriteLn('VolumeID = ', VolumeID);
  WriteLn('Directory = ', Directory);
  WriteLn('Archive = ', Archive);
  WriteLn('AnyFile = ', AnyFile);

  { Test GetDate }
  GetDate(Y, M, D, DOW);
  WriteLn('Year: ', Y);
  WriteLn('Month: ', M);
  WriteLn('Day: ', D);
  WriteLn('DayOfWeek: ', DOW);

  { Test GetTime }
  GetTime(H, Mi, S, S100);
  WriteLn('Hour: ', H);
  WriteLn('Min: ', Mi);
  WriteLn('Sec: ', S);

  { Test GetEnv }
  Env := GetEnv('PATH');
  WriteLn('PATH length: ', Length(Env));

  { Test EnvCount }
  WriteLn('EnvCount: ', EnvCount);

  { Test DosVersion }
  WriteLn('DosVersion: ', DosVersion);

  { Test DosExitCode }
  EC := DosExitCode;
  WriteLn('DosExitCode: ', EC);

  { Test stubs }
  SwapVectors;
  DiskFree(0);
  DiskSize(0);

  WriteLn('=== Fin test DOS ===');
end.
