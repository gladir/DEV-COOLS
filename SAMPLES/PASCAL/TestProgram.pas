program TestProgram;

uses TestUnit;

var
  result: Integer;

begin
  ShowMessage;
  result := AddNumbers(5, 3);
  writeln('Result: ', result);
  GlobalValue := 42;
  writeln('Global value: ', GlobalValue);
end.