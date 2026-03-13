{ test_set.pas - Ensembles, IN, operations, CARD }
program test_set;
type
  Color = (Red, Green, Blue, Yellow, Orange);
  ColorSet = set of Color;
var
  s1, s2, s3 : ColorSet;
  total : integer;
begin
  s1 := [Red, Green, Blue];
  s2 := [Green, Yellow, Orange];

  { Union }
  s3 := s1 + s2;
  writeln('Card(s3) = ', card(s3));

  { Intersection }
  s3 := s1 * s2;
  writeln('Card(s1*s2) = ', card(s3));

  { Difference }
  s3 := s1 - s2;
  writeln('Card(s1-s2) = ', card(s3));

  { Test d'appartenance }
  if Red in s1 then
    writeln('Red est dans s1');
  if Yellow in s1 then
    writeln('Yellow est dans s1')
  else
    writeln('Yellow n''est PAS dans s1');

  { Egalite }
  if s1 = s2 then
    writeln('s1 = s2')
  else
    writeln('s1 <> s2');

  { Sous-ensemble }
  if [Green] <= s1 then
    writeln('[Green] <= s1');
end.
