program TestProcedure;

procedure SayHello;
begin
  WriteLn('Hello from procedure!');
end;

var
  x: Integer;

begin
  x := 42;
  WriteLn('x = ', x);
  SayHello;
  WriteLn('Done!');
end.
