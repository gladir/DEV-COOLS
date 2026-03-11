{ test_system.pas - Test de l'unite System implicite (TODO 18) }
program TestSystem;

var
  X, Y, Code: Integer;
  R: Real;
  S, S2: String;
  B: Boolean;

begin
  { Fonctions mathematiques }
  WriteLn('=== Fonctions mathematiques ===');
  WriteLn('Abs(-5) = ', Abs(-5));
  WriteLn('Sqr(4) = ', Sqr(4));
  WriteLn('Sqrt(16) = ', Sqrt(16):0:2);
  WriteLn('Sin(0) = ', Sin(0):0:2);
  WriteLn('Cos(0) = ', Cos(0):0:2);
  WriteLn('ArcTan(1) = ', ArcTan(1):0:4);
  WriteLn('Exp(0) = ', Exp(0):0:2);
  WriteLn('Ln(1) = ', Ln(1):0:2);
  WriteLn('Int(3.7) = ', Int(3.7):0:2);
  WriteLn('Frac(3.7) = ', Frac(3.7):0:2);
  WriteLn('Round(3.5) = ', Round(3.5));
  WriteLn('Trunc(3.9) = ', Trunc(3.9));
  WriteLn('Pi = ', Pi:0:5);

  { Fonctions ordinales }
  WriteLn;
  WriteLn('=== Fonctions ordinales ===');
  WriteLn('Ord(A) = ', Ord('A'));
  WriteLn('Chr(65) = ', Chr(65));
  WriteLn('Succ(5) = ', Succ(5));
  WriteLn('Pred(5) = ', Pred(5));
  X := 10;
  Inc(X);
  WriteLn('Inc(10) = ', X);
  Dec(X);
  WriteLn('Dec(11) = ', X);
  X := 100;
  Inc(X, 5);
  WriteLn('Inc(100, 5) = ', X);
  Dec(X, 3);
  WriteLn('Dec(105, 3) = ', X);
  WriteLn('Lo(258) = ', Lo(258));
  WriteLn('Hi(258) = ', Hi(258));
  WriteLn('Swap(258) = ', Swap(258));
  WriteLn('Odd(3) = ', Odd(3));
  WriteLn('Odd(4) = ', Odd(4));

  { Fonctions de chaine }
  WriteLn;
  WriteLn('=== Fonctions de chaine ===');
  S := 'Hello World';
  WriteLn('Length = ', Length(S));
  WriteLn('Copy(S, 7, 5) = ', Copy(S, 7, 5));
  WriteLn('Pos(World, S) = ', Pos('World', S));
  WriteLn('Concat(A, B, C) = ', Concat('A', 'B', 'C'));
  WriteLn('UpCase(a) = ', UpCase('a'));

  { Delete }
  S := 'Hello World';
  Delete(S, 6, 6);
  WriteLn('Delete(Hello World, 6, 6) = ', S);

  { Insert }
  S := 'Hello';
  Insert(' World', S, 6);
  WriteLn('Insert( World, Hello, 6) = ', S);

  { Str et Val }
  X := 42;
  Str(X, S);
  WriteLn('Str(42) = ', S);
  Val('123', X, Code);
  WriteLn('Val(123) -> X=', X, ' Code=', Code);

  { Random et Randomize }
  WriteLn;
  WriteLn('=== Random ===');
  Randomize;
  X := Random(100);
  WriteLn('Random(100) = ', X);
  R := Random;
  WriteLn('Random = ', R:0:4);

  { Autres fonctions System }
  WriteLn;
  WriteLn('=== Autres ===');
  WriteLn('SizeOf(Integer) = ', SizeOf(Integer));
  B := Assigned(nil);
  WriteLn('Assigned(nil) = ', B);
  WriteLn('High(S) = ', High(S));
  WriteLn('Low(S) = ', Low(S));

  WriteLn;
  WriteLn('Test System done');
end.
