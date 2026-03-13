program TestGetEnv;
var
  S: String;
begin
  WriteLn('Before GetEnv');
  S := GetEnv('PATH');
  WriteLn('After GetEnv');
  WriteLn('S=[', S, ']');
end.
