{ test_dos_datetime.pas - Test DosVersion }
program TestDosDateTime;

uses Dos;

var
  V : Word;

begin
  { Test DosVersion }
  V := DosVersion;
  WriteLn('DosVersion=', V);
  If V > 0 Then WriteLn('DosVersion OK')
  Else WriteLn('DosVersion FAIL');

  WriteLn('OK');
end.
