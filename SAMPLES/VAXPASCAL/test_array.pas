{ test_array.pas - Tableaux, DIMENSION, UPPERBOUND }
program test_array;
var
  a : array [1..10] of integer;
  i : integer;
  sum : integer;
begin
  { Remplir le tableau }
  for i := 1 to 10 do
    a[i] := i * i;

  writeln('Tableau a :');
  sum := 0;
  for i := 1 to 10 do
  begin
    write(a[i], ' ');
    sum := sum + a[i];
  end;
  writeln;
  writeln('Sum = ', sum);

  writeln('lowerbound = 1');
  writeln('upperbound = 10');
  writeln('Test tableaux termine.');
end.
