{ test_procvar.pas - Types proceduraux, pointeurs de fonctions }
program test_procvar;
type
  IntFunc = function(x : integer) : integer;

function double_it(x : integer) : integer;
begin
  double_it := x * 2;
end;

function triple_it(x : integer) : integer;
begin
  triple_it := x * 3;
end;

procedure apply(f : IntFunc; val : integer);
var
  result : integer;
begin
  result := f(val);
  writeln('apply(f, ', val, ') = ', result);
end;

begin
  apply(double_it, 5);
  apply(triple_it, 5);
  writeln('Test proc var termine.');
end.
