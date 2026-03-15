{ test_tpu.pas - Test lecture TPU et clause Uses (TODO 26) }
program TestTPU;
uses Crt, Dos;
var
  X: Integer;
begin
  X := 42;
  WriteLn('Test Uses Crt, Dos - X = ', X);
end.
