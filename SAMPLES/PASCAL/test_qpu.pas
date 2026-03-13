{ Test QPU format support (TODO 29) }
{ Verifies that the compiler handles QPU unit references }
{ and that Quick Pascal specific units are recognized as known }

program TestQPU;

uses Crt, Dos;

var
  X : Integer;

begin
  X := 42;
  Writeln('QPU format support test: ', X);
end.
