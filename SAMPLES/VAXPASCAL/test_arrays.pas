PROGRAM test_arrays(OUTPUT);

{ Test TODO 16 - TABLEAUX : declarations, acces, constantes,
  fonctions UPPERBOUND/LOWERBOUND/DIMENSION, tailles element }

CONST
  MaxSize = 5;

TYPE
  TIntArray = ARRAY[1..10] OF INTEGER;
  TSmallArr = ARRAY[0..4] OF INTEGER;
  TCharArr  = PACKED ARRAY[1..5] OF CHAR;
  TBigArr   = ARRAY[1..MaxSize] OF INTEGER;

CONST
  Primes : ARRAY[1..5] OF INTEGER = (2, 3, 5, 7, 11);
  Squares : ARRAY[0..3] OF INTEGER = (0, 1, 4, 9);

VAR
  a : TIntArray;
  b : TSmallArr;
  ch : TCharArr;
  i : INTEGER;
  n : INTEGER;
  lo, hi, dim : INTEGER;

BEGIN
  { Affectation simple d elements }
  a[1] := 100;
  a[2] := 200;
  a[3] := 300;
  WriteLn('a[1] = ', a[1]);
  WriteLn('a[2] = ', a[2]);
  WriteLn('a[3] = ', a[3]);

  { Tableau base 0 }
  b[0] := 10;
  b[1] := 20;
  b[2] := 30;
  b[3] := 40;
  b[4] := 50;
  WriteLn('b[0] = ', b[0]);
  WriteLn('b[4] = ', b[4]);

  { Acces via expression }
  i := 2;
  a[i] := 999;
  WriteLn('a[2] apres := ', a[i]);

  { Boucle for sur tableau }
  FOR i := 1 TO 5 DO
    a[i] := i * 10;
  WriteLn('a[1] = ', a[1]);
  WriteLn('a[5] = ', a[5]);

  { Tableau de constantes }
  WriteLn('Primes[1] = ', Primes[1]);
  WriteLn('Primes[3] = ', Primes[3]);
  WriteLn('Primes[5] = ', Primes[5]);
  WriteLn('Squares[0] = ', Squares[0]);
  WriteLn('Squares[3] = ', Squares[3]);

  { UPPERBOUND }
  hi := UPPERBOUND(a, 1);
  WriteLn('UPPERBOUND(a) = ', hi);

  { LOWERBOUND }
  lo := LOWERBOUND(a, 1);
  WriteLn('LOWERBOUND(a) = ', lo);

  { DIMENSION }
  dim := DIMENSION(a, 1);
  WriteLn('DIMENSION(a) = ', dim);

  { LOWERBOUND sur tableau base 0 }
  lo := LOWERBOUND(b, 1);
  WriteLn('LOWERBOUND(b) = ', lo);

  { UPPERBOUND sur tableau base 0 }
  hi := UPPERBOUND(b, 1);
  WriteLn('UPPERBOUND(b) = ', hi);

  { DIMENSION sur petit tableau }
  dim := DIMENSION(b, 1);
  WriteLn('DIMENSION(b) = ', dim);

  WriteLn('Arrays test OK');
END.
