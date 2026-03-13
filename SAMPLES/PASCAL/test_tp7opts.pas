{ test_tp7opts.pas - Test parametres compatibles TPC 7.0 (TODO 25) }
program TestTP7Opts;
const
  AppName = 'TestTP7Opts';
  Version = 1;
var
  X: Integer;
  S: String;
begin
  X := 42;
  S := 'Hello TP7';
  WriteLn(S, ' ', X);
end.
