Program TestConst;

const
  MaxValue = 100;
  MinValue = 0;  
  AppName = 'Test Program';
  IsDebug = TRUE;
  Version = 1;

var
  counter: Integer;
  name: String;

begin
  WriteLn('Testing constants');
  counter := MaxValue;
  WriteLn('Max value is: ', counter);
  counter := MinValue;
  WriteLn('Min value is: ', counter); 
  WriteLn('Version: ', Version);
  if IsDebug then
    WriteLn('Debug mode is enabled');
end.