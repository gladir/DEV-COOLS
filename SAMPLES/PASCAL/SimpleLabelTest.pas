Program SimpleLabel;

label
  MyLabel;

begin
  WriteLn('Before label');
MyLabel:
  WriteLn('At label');
  WriteLn('After label');
end.