program TestProcFunc;

var
  x: integer;
  y: integer;

procedure Hello;
begin
  WriteLn('Hello from procedure');
end;

procedure PrintVal(n: integer);
begin
  WriteLn(n);
end;

procedure Swap(var a, b: integer);
var
  tmp: integer;
begin
  tmp := a;
  a := b;
  b := tmp;
end;

function Add(a, b: integer): integer;
begin
  Add := a + b;
end;

function Factorial(n: integer): integer;
begin
  if n <= 1 then
    Factorial := 1
  else
    Factorial := n * Factorial(n - 1);
end;

function Max(a, b: integer): integer;
begin
  if a > b then
    Result := a
  else
    Result := b;
end;

procedure Greet(const name: string);
begin
  WriteLn('Hello, ', name, '!');
end;

procedure Inner;
  procedure Sub;
  begin
    WriteLn('Inner sub');
  end;
begin
  Sub;
  WriteLn('Inner done');
end;

begin
  Hello;
  PrintVal(42);
  WriteLn('Add(3,4) = ', Add(3, 4));
  WriteLn('Fact(5) = ', Factorial(5));
  WriteLn('Max(10,20) = ', Max(10, 20));
  Greet('World');
  x := 1;
  y := 2;
  Swap(x, y);
  WriteLn('After swap: x=', x, ' y=', y);
  Inner;
end.
