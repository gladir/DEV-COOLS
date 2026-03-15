{ test_uses_ver.pas - Test Uses avec restriction version TP4+ (TODO 27) }
program TestUsesVer;
uses Crt;
var
  X: Integer;
begin
  X := 10;
  WriteLn('Test Uses version check - X = ', X);
end.
