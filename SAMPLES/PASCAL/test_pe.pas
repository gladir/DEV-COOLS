{ test_pe.pas - Test generation PE/COFF/DOS16 (TODO 24) }
program TestPE;
const
  AppName = 'TestPE';
  Version = 1;
var
  X: Integer;
  S: String;
begin
  X := 42;
  S := 'Hello PE';
  WriteLn(S, ' ', X);
end.
