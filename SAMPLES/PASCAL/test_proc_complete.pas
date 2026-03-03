program TestProcedureComplete;

var
  counter: Integer;

procedure IncrementCounter;
begin
  counter := counter + 1;
end;

procedure ShowCounter;
begin
  WriteLn('Counter = ', counter);
end;

begin
  counter := 0;
  ShowCounter;
  IncrementCounter;
  ShowCounter;
  IncrementCounter;
  ShowCounter;
end.
