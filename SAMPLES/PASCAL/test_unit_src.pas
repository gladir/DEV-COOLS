{ test_unit_src.pas - Test compilation d'une unite (TODO 27) }
unit TestUnitSrc;

interface

procedure HelloUnit;

implementation

procedure HelloUnit;
var
  Msg: Integer;
begin
  Msg := 42;
  WriteLn('Hello from unit - Msg = ', Msg);
end;

end.
