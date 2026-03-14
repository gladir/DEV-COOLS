{ test_converge.pas - Programme complet : toutes fonctionnalites }
program test_converge(input, output);

{ Constantes }
const
  MAX     = 10;
  TITLE   = 'Test Convergence';
  VERSION = 1;

{ Types }
type
  Color    = (Red, Green, Blue);
  SmallArr = array [1..MAX] of integer;
  PointRec = record
    x, y : integer;
  end;

{ Condition utilisateur }
condition test_condition value 500;

{ Variables }
var
  arr     : SmallArr;
  p       : PointRec;
  colors  : set of Color;
  i, sum  : integer;
  s       : varying [80] of char;
  ok      : boolean;
  ptr     : ^integer;

{ Fonction recursive }
function fib(n : integer) : integer;
begin
  if n <= 1 then
    fib := n
  else
    fib := fib(n - 1) + fib(n - 2);
end;

{ Procedure avec STATIC }
procedure tick;
static var count : integer := 0;
begin
  count := count + 1;
  writeln('tick #', count);
end;

{ Programme principal }
begin
  writeln(TITLE);
  writeln('Version ', VERSION);

  { Boucle FOR avec tableau }
  sum := 0;
  for i := 1 to MAX do
  begin
    arr[i] := i * i;
    sum := sum + arr[i];
  end;
  writeln('Sum of squares 1..', MAX, ' = ', sum);

  { Record }
  p.x := 10;
  p.y := 20;
  writeln('Point : (', p.x, ', ', p.y, ')');

  { Sets }
  colors := [Red, Blue];
  if Green in colors then
    writeln('Green present')
  else
    writeln('Green absent');
  writeln('Card = ', card(colors));

  { Strings / VARYING }
  s := 'Hello' || ' ' || 'World';
  writeln('s = ', s);
  writeln('length = ', length(s));

  { Fibonacci }
  writeln('fib(10) = ', fib(10));

  { Static procedure }
  for i := 1 to 3 do
    tick;

  { Pointeur }
  new(ptr);
  ptr^ := 999;
  writeln('ptr^ = ', ptr^);
  dispose(ptr);

  { Boolean }
  ok := (sum > 100) and (p.x = 10);
  writeln('ok = ', ok);

  { Exception handling }
  begin
    signal(test_condition);
  exception
    on test_condition do
      writeln('test_condition intercepte');
    anyother
      writeln('Erreur inattendue');
  end;

  { WHILE }
  i := 1;
  while i <= 5 do
  begin
    write(i, ' ');
    i := i + 1;
  end;
  writeln;

  { REPEAT }
  i := 5;
  repeat
    write(i, ' ');
    i := i - 1;
  until i = 0;
  writeln;

  writeln('Tous les tests convergent. OK.');
end.
