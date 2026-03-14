program TestFind2;
var
  TmpLanguage: String;
begin
  WriteLn('ParamCount=', ParamCount);
  WriteLn('P1=[', ParamStr(1), ']');
  TmpLanguage := GetEnv('LANGUAGE');
  WriteLn('LANG=[', TmpLanguage, ']');
  if (ParamStr(1) = '/?') or (ParamStr(1) = '--help') or
     (ParamStr(1) = '-h') or (ParamStr(1) = '/h') or
     (ParamStr(1) = '/H') then
    WriteLn('HELP MODE')
  else if ParamCount > 0 then
    WriteLn('WORK MODE')
  else
    WriteLn('NO PARAMS');
end.
