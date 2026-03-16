{ test_dos_env.pas - Test EnvCount/EnvStr/GetEnv/DosVersion/DosExitCode }
program TestDosEnv;

uses Dos;

var
  N : Integer;
  S : String;
  V : Word;

begin
  { Test DosVersion }
  V := DosVersion;
  WriteLn('DosVersion=', V);
  If V > 0 Then WriteLn('DosVersion OK')
  Else WriteLn('DosVersion FAIL');

  { Test EnvCount }
  N := EnvCount;
  WriteLn('EnvCount=', N);
  If N > 0 Then WriteLn('EnvCount OK')
  Else WriteLn('EnvCount FAIL');

  { Test EnvStr(1) - premiere variable d environnement }
  If N > 0 Then
  Begin
    S := EnvStr(1);
    WriteLn('EnvStr1=', S);
    WriteLn('EnvStr OK');
  End;

  { Test GetEnv }
  S := GetEnv('PATH');
  WriteLn('PATH=', S);
  If Length(S) > 0 Then WriteLn('GetEnv OK')
  Else WriteLn('GetEnv empty');

  { Test DosExitCode }
  V := DosExitCode;
  WriteLn('DosExitCode=', V);
  WriteLn('DosExitCode OK');

  WriteLn('OK');
end.
