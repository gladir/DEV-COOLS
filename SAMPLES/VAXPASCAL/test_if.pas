{ test_if.pas - IF/THEN/ELSE, CASE/OTHERS }
program test_if;
var
  x     : integer;
  grade : char;
begin
  x := 42;

  if x > 0 then
    writeln('x est positif')
  else if x = 0 then
    writeln('x est zero')
  else
    writeln('x est negatif');

  grade := 'B';
  case grade of
    'A' : writeln('Excellent');
    'B' : writeln('Bien');
    'C' : writeln('Moyen');
    'D', 'F' : writeln('Insuffisant');
    otherwise writeln('Note inconnue');
  end;

  { Cas avec plage }
  case x of
    1..10    : writeln('petit');
    11..50   : writeln('moyen');
    51..100  : writeln('grand');
    others   : writeln('hors plage');
  end;
end.
