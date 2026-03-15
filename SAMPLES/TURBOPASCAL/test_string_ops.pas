program test_string_ops;
var S1, S2, S3: String;
begin
  S1 := 'Hello';
  S2 := ' World';
  S3 := S1 + S2;
  WriteLn('S3=', S3);
  WriteLn('Length(S3)=', Length(S3));
  WriteLn('S3[0]=', Ord(S3[0]));
  if S1 = 'Hello' then WriteLn('S1=Hello: OK');
  if S1 <> S2 then WriteLn('S1<>S2: OK');
end.
