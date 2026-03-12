{ test_unit.pas - Test d'une unite utilisateur (TODO 23) }
unit MathUtils;

interface

const
  PI_VALUE = 3.14159;
  E_VALUE  = 2.71828;

type
  TPoint = record
    X, Y: Integer;
  end;

var
  LastResult: Integer;

function Add(A, B: Integer): Integer;
function Multiply(A, B: Integer): Integer;
procedure SetLastResult(V: Integer);

implementation

function Add(A, B: Integer): Integer;
begin
  Add := A + B;
end;

function Multiply(A, B: Integer): Integer;
begin
  Multiply := A * B;
end;

procedure SetLastResult(V: Integer);
begin
  LastResult := V;
end;

begin
  LastResult := 0;
  WriteLn('MathUtils initialized');
end.
