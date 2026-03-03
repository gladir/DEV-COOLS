program TestProcedureSimple;

procedure ShowMessage;
begin
  WriteLn('Message from procedure');
end;

begin
  WriteLn('Before procedure call');
  ShowMessage;
  WriteLn('After procedure call');
end.
