program TestParam2;
var
  S: String;
begin
  WriteLn('ParamCount=', ParamCount);
  S := ParamStr(1);
  WriteLn('ParamStr(1)=[', S, ']');
  WriteLn('Len=', Length(S));
  if (ParamStr(1) = '/?') or (ParamStr(1) = '--help') then
    WriteLn('GOT HELP')
  else
    WriteLn('NO HELP');
  if ParamCount > 0 then
    WriteLn('HAS PARAMS')
  else
    WriteLn('NO PARAMS');
end.
