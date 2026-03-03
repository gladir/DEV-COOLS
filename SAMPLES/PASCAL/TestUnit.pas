unit TestUnit;

interface

var
  GlobalValue: Integer;

procedure ShowMessage;
function AddNumbers(a, b: Integer): Integer;

implementation

procedure ShowMessage;
begin
  writeln('Hello from TestUnit!');
end;

function AddNumbers(a, b: Integer): Integer;
begin
  AddNumbers := a + b;
end;

end.