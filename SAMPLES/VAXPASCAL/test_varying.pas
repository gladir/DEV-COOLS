{ test_varying.pas - VARYING, .LENGTH, .BODY, concat }
program test_varying;
var
  s1  : varying [40] of char;
  s2  : varying [40] of char;
  s3  : varying [80] of char;
  len : integer;
begin
  s1 := 'Hello';
  s2 := 'World';

  { Concatenation avec || }
  s3 := s1 || ' ' || s2;
  writeln('s3 = ', s3);

  { .LENGTH }
  len := s3.length;
  writeln('s3.length = ', len);

  { Direct length() }
  writeln('length(s1) = ', length(s1));

  { Comparaison }
  if s1 < s2 then
    writeln('s1 < s2')
  else
    writeln('s1 >= s2');

  { Affectation }
  s1 := s3;
  writeln('s1 := s3 -> ', s1);
end.
