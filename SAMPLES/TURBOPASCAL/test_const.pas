{ test_const.pas - Litteraux et constantes pour TP2JS }
program TestConst;
const
  MaxValue = 100;
  MinValue = 0;
  HexVal = $FF;
  HexWord = $FFFF;
  HexLong = $7FFFFFFF;
  PiVal = 3.14159;
  BigNum = 1.5E10;
  SmallNum = 2.0E-3;
  AppName = 'Hello World';
  Quote = 'l''arbre';
  CRLF = #13#10;
  Tab = #9;
  Bell = ^G;
  Mixed = 'abc'#13#10'def';
  CharA = 'A';
  IsDebug = TRUE;
  IsRelease = FALSE;
  NullPtr = nil;
  Version = 1;
  Combined = 3 + 5;
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
  WriteLn(AppName);
end.
