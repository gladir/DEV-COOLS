program TestFunctionBasic;

function GetFive: Integer;
begin
  GetFive := 5;
end;

var
  result: Integer;

begin
  result := GetFive;
  WriteLn('Result: ', result);
end.
