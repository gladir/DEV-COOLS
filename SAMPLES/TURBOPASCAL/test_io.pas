{ test_io.pas - Test des entrees/sorties (TODO 12) }
program TestIO;

var
  X: Integer;
  R: Real;
  S: String;
  Code: Integer;

begin
  { WriteLn simple }
  WriteLn('Hello World');

  { WriteLn sans arguments (ligne vide) }
  WriteLn;

  { WriteLn avec multiples arguments }
  WriteLn('X = ', 42);
  WriteLn('Sum = ', 10 + 20);
  WriteLn('A', 'B', 'C');

  { Write sans saut de ligne }
  Write('Enter: ');

  { Write sans arguments }
  Write;

  { Formatage avec largeur }
  X := 42;
  WriteLn(X:10);
  WriteLn(X:5);

  { Formatage reel avec decimales }
  R := 3.14159;
  WriteLn(R:10:2);
  WriteLn(R:8:4);

  { Mix d arguments avec et sans formatage }
  WriteLn('Value: ', X:5, ' pi=', R:8:3);

  { Str : conversion nombre vers chaine }
  Str(X, S);
  WriteLn('Str(X) = ', S);

  { Str avec formatage }
  Str(R:10:2, S);
  WriteLn('Str(R:10:2) = ', S);

  { Val : conversion chaine vers nombre }
  Val('123', X, Code);
  WriteLn('Val 123: X=', X, ' Code=', Code);

  Val('abc', X, Code);
  WriteLn('Val abc: X=', X, ' Code=', Code);

  { ReadLn avec variable }
  ReadLn(X);
  WriteLn('Lu: ', X);

  { ReadLn avec chaine }
  ReadLn(S);
  WriteLn('Lu: ', S);

  { Read avec reel }
  Read(R);

  { ReadLn sans argument }
  ReadLn;

  WriteLn('Test IO done');
end.
