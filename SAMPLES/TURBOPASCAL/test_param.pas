program TestParam;
var
  S: String;
begin
  WriteLn('ParamCount=', ParamCount);
  if ParamCount > 0 then
  begin
    S := ParamStr(1);
    WriteLn('ParamStr(1)=[', S, ']');
    WriteLn('Length=', Length(S));
    if S = '/?' then
      WriteLn('MATCH /?')
    else
      WriteLn('NO MATCH');
  end;
end.
