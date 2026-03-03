program TestFunctionSimple;

function Double(x: Integer): Integer;
begin
  Double := x * 2;
end;

begin
  WriteLn('Test: ', Double(5));
end.
