(* test_exprs.m3 - Test des expressions primaires (TODO 10)        *)
(* Verifie ParsePrimary, ParseExpr, ParseBody, ParseStmt.          *)
(* Le compilateur doit generer du code ASM 8086 pour :             *)
(*   - affectations (variable := expr)                             *)
(*   - expressions arithmetiques (+, -, *, DIV, MOD)               *)
(*   - expressions de comparaison (=, #, <, <=, >, >=)            *)
(*   - expressions logiques (AND, OR, NOT)                         *)
(*   - appels de builtins (ABS, MAX, MIN, INC, DEC, ORD)          *)
(*   - appels de modules (Wr.PutText, Wr.PutInt, Wr.Nl)           *)
(*   - structures de controle (IF, WHILE, FOR, LOOP, REPEAT)      *)
(*   - litteraux (entiers, chaines, caracteres, TRUE, FALSE, NIL)  *)
(*   - RETURN dans les fonctions                                   *)

MODULE TestExprs;

IMPORT Wr, Rd, Fmt, Text;

CONST
  Limit = 100;

VAR
  counter : INTEGER;
  result  : INTEGER;
  flag    : BOOLEAN;
  name    : TEXT;
  ch      : CHAR;

PROCEDURE SimpleAssign();
VAR
  a : INTEGER;
  b : INTEGER;
  c : BOOLEAN;
BEGIN
  a := 42;
  b := a;
  c := TRUE;
  b := 0;
  c := FALSE;
END SimpleAssign;

PROCEDURE Arithmetic(x : INTEGER; y : INTEGER) : INTEGER;
VAR
  sum  : INTEGER;
  diff : INTEGER;
  prod : INTEGER;
  quot : INTEGER;
  rem  : INTEGER;
BEGIN
  sum  := x + y;
  diff := x - y;
  prod := x * y;
  quot := x DIV y;
  rem  := x MOD y;
  RETURN sum + diff;
END Arithmetic;

PROCEDURE Comparison(a : INTEGER; b : INTEGER) : BOOLEAN;
VAR
  r : BOOLEAN;
BEGIN
  r := (a = b);
  r := (a # b);
  r := (a < b);
  r := (a <= b);
  r := (a > b);
  r := (a >= b);
  RETURN r;
END Comparison;

PROCEDURE Logic(p : BOOLEAN; q : BOOLEAN) : BOOLEAN;
VAR
  r : BOOLEAN;
BEGIN
  r := p AND q;
  r := p OR q;
  r := NOT p;
  RETURN r;
END Logic;

PROCEDURE Builtins();
VAR
  n : INTEGER;
  m : INTEGER;
BEGIN
  n := ABS(-5);
  m := MAX(10, 20);
  m := MIN(10, 20);
  n := ORD('A');
  INC(n);
  DEC(n);
  INC(n, 5);
  DEC(n, 3);
END Builtins;

PROCEDURE OutputTest();
BEGIN
  Wr.PutText("Hello, Modula-3!");
  Wr.Nl();
  Wr.PutInt(42);
  Wr.Nl();
  Wr.PutChar('X');
END OutputTest;

PROCEDURE ControlFlow();
VAR
  i : INTEGER;
  s : INTEGER;
BEGIN
  (* IF / ELSIF / ELSE *)
  i := 10;
  IF i > 0 THEN
    s := 1;
  ELSIF i = 0 THEN
    s := 0;
  ELSE
    s := -1;
  END;

  (* WHILE loop *)
  i := 0;
  WHILE i < 10 DO
    i := i + 1;
  END;

  (* FOR loop *)
  s := 0;
  FOR i := 1 TO 10 DO
    s := s + i;
  END;

  (* LOOP / EXIT *)
  i := 0;
  LOOP
    i := i + 1;
    IF i >= 5 THEN
      EXIT;
    END;
  END;

  (* REPEAT / UNTIL *)
  i := 0;
  REPEAT
    i := i + 1;
  UNTIL i >= 10;
END ControlFlow;

PROCEDURE ReturnTest(n : INTEGER) : INTEGER;
BEGIN
  IF n <= 0 THEN
    RETURN 0;
  END;
  RETURN n + 1;
END ReturnTest;

PROCEDURE StringTest();
VAR
  t : TEXT;
  n : INTEGER;
BEGIN
  t := "world";
  n := Text.Length(t);
  Wr.PutText("Length = ");
  Wr.PutInt(n);
  Wr.Nl();
END StringTest;

PROCEDURE ParenTest() : INTEGER;
VAR
  a : INTEGER;
BEGIN
  a := (2 + 3) * 4;
  RETURN a;
END ParenTest;

BEGIN
  counter := 0;
  result  := 0;
  flag    := TRUE;
  name    := "test";
END TestExprs.
