{ test_expr.pas - Test des operateurs et expressions VAX Pascal (TODO 08) }
{ Verifie les precedences, ||, **, ANDIF, ORIF, NOT, comparaisons }

PROGRAM TestExpr(Output);

CONST
  X = 2 + 3 * 4;     { doit plier en 14 }
  Y = 10 - 2;         { doit plier en 8 }
  Z = 3 ** 4;          { doit plier en 81 }
  B1 = 5 = 5;          { doit plier en True }
  B2 = 3 <> 4;         { doit plier en True }

VAR
  a, b, c : Integer;
  s1, s2  : String;
  ok      : Boolean;

BEGIN
  a := 10;
  b := 3;

  { Arithmetique }
  c := a + b;
  c := a - b;
  c := a * b;
  c := a DIV b;
  c := a MOD b;

  { Concatenation || }
  s1 := 'Hello';
  s2 := s1 || ' World';

  { Exponentiation ** }
  c := 2 ** 8;

  { Comparaisons }
  ok := a = 10;
  ok := a <> b;
  ok := a > b;
  ok := a < 20;
  ok := a >= 10;
  ok := a <= 10;

  { Logique }
  ok := (a > 0) AND (b > 0);
  ok := (a > 0) OR (b < 0);
  ok := NOT ok;

  { Court-circuit }
  ok := (a > 0) ANDIF (b > 0);
  ok := (a < 0) ORIF (b > 0);

  { Bits }
  c := a AND 255;
  c := a OR 15;
  c := a XOR b;
  c := a SHL 2;
  c := a SHR 1;

  { Unaire }
  c := -a;
  c := +b;

  WriteLn('Expressions VAX Pascal OK');
END.
