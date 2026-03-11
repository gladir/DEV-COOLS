{ test_dos.pas - Test de l unite DOS pour TPCW32 }
Program TestDos;
Uses Dos;
Var
  Y, M, D, DW : Word;
  H, Mi, S, S100 : Word;
  SR : SearchRec;
  EnvPath : String;
Begin
  WriteLn('=== Test unite DOS ===');

  WriteLn('DosVersion = ', DosVersion);

  GetDate(Y, M, D, DW);
  WriteLn('Date : ', Y, '-', M, '-', D, ' (jour ', DW, ')');

  GetTime(H, Mi, S, S100);
  WriteLn('Heure : ', H, ':', Mi, ':', S, '.', S100);

  EnvPath := GetEnv('PATH');
  WriteLn('PATH = ', EnvPath);

  WriteLn('DiskFree(0) = ', DiskFree(0));
  WriteLn('DiskSize(0) = ', DiskSize(0));

  FindFirst('*.pas', $3F, SR);
  If DosError = 0 Then
    WriteLn('Premier fichier : ', SR.Name)
  Else
    WriteLn('Aucun fichier .pas trouve');

  SwapVectors;
  WriteLn('Done.');
End.
