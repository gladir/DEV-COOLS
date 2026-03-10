{ test_emit.pas - Test de l emetteur JS (TODO 07) }
program TestEmit;
const
  VERSION = '1.0';
  MAX = 100;
var
  X: Integer;
  S: String;
begin
  X := 42;
  S := 'Hello World';
  WriteLn(S);
  WriteLn('X = ', X);
end.
