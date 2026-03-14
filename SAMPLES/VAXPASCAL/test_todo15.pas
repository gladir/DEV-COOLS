PROGRAM test_todo15(OUTPUT);

{ Test TODO 15 - TABLEAUX ET TABLEAUX CONFORMANTS :
  - Tableaux multi-dimensionnels ARRAY[lo..hi, lo2..hi2] OF T
  - PACKED ARRAY
  - Verification de bornes (CheckEnabled)
  - Acces arr[i,j] en lecture et ecriture }

VAR
  { Tableau multi-dimensionnel 3x4 }
  mat : ARRAY[1..3, 1..4] OF INTEGER;
  { Tableau simple pour verifier non-regression }
  a : ARRAY[1..5] OF INTEGER;
  { PACKED ARRAY OF CHAR }
  name : PACKED ARRAY[1..10] OF CHAR;
  { PACKED ARRAY OF INTEGER }
  pk : PACKED ARRAY[0..3] OF INTEGER;
  i, j : INTEGER;
  sum : INTEGER;

BEGIN
  { Test 1: Tableau simple (non-regression) }
  FOR i := 1 TO 5 DO
    a[i] := i * 10;
  WriteLn('a[1] = ', a[1]);
  WriteLn('a[3] = ', a[3]);
  WriteLn('a[5] = ', a[5]);

  { Test 2: Tableau multi-dimensionnel - ecriture }
  FOR i := 1 TO 3 DO
    FOR j := 1 TO 4 DO
      mat[i, j] := i * 10 + j;

  { Test 3: Tableau multi-dimensionnel - lecture }
  WriteLn('mat[1,1] = ', mat[1, 1]);
  WriteLn('mat[1,4] = ', mat[1, 4]);
  WriteLn('mat[2,3] = ', mat[2, 3]);
  WriteLn('mat[3,4] = ', mat[3, 4]);

  { Test 4: Somme de tous les elements }
  sum := 0;
  FOR i := 1 TO 3 DO
    FOR j := 1 TO 4 DO
      sum := sum + mat[i, j];
  WriteLn('sum = ', sum);

  { Test 5: PACKED ARRAY }
  pk[0] := 100;
  pk[1] := 200;
  pk[2] := 300;
  pk[3] := 400;
  WriteLn('pk[0] = ', pk[0]);
  WriteLn('pk[3] = ', pk[3]);

  WriteLn('TODO 15 test OK');
END.
