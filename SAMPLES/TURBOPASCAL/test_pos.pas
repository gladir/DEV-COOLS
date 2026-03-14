program test_pos;
var S: String;
begin
  S := 'Hello, World!';
  WriteLn('S=', S);
  WriteLn('Pos=', Pos('World', S));
  WriteLn('Pos2=', Pos('Hello', S));
  WriteLn('Pos3=', Pos('!', S));
end.
