{ test_string.pas - STRING, VARYING, double-pipe, SUBSTR }
program test_string;
var
  s1, s2 : varying [80] of char;
  s3     : varying [160] of char;
  pos    : integer;
  len    : integer;
begin
  s1 := 'Hello';
  s2 := 'World';
  s3 := s1 || ', ' || s2 || '!';
  writeln('s3 = ', s3);

  len := length(s3);
  writeln('length(s3) = ', len);

  writeln('substr(s3,1,5) = ', substr(s3, 1, 5));

  pos := index(s3, 'World');
  writeln('index(s3, World) = ', pos);

  writeln('uppercase(s1) = ', uppercase(s1));
  writeln('lowercase(s2) = ', lowercase(s2));

  writeln('trim(s1) = ', trim(s1));
  writeln('pad(s1, 10) = ', pad(s1, 10, ' '));
end.
