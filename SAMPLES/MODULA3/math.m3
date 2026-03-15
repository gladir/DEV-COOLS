(* math.m3 - Exemple de procedures et fonctions (TODO 25)               *)
(* Demontre : PROCEDURE, fonctions avec RETURN, parametres VALUE/VAR,   *)
(* READONLY, recursion (factorielle), procedures imbriquees,            *)
(* INC/DEC, types PROCEDURE.                                            *)

MODULE MathExample;

IMPORT Wr, Fmt;

VAR
  result : INTEGER;

(* ---- Fonction simple avec RETURN ---- *)
PROCEDURE Add(a: INTEGER; b: INTEGER): INTEGER =
BEGIN
  RETURN a + b;
END Add;

(* ---- Fonction avec variable locale ---- *)
PROCEDURE Square(n: INTEGER): INTEGER =
VAR
  r : INTEGER;
BEGIN
  r := n * n;
  RETURN r;
END Square;

(* ---- Parametre VAR (passage par reference) ---- *)
PROCEDURE Swap(VAR x: INTEGER; VAR y: INTEGER) =
VAR
  tmp : INTEGER;
BEGIN
  tmp := x;
  x := y;
  y := tmp;
END Swap;

(* ---- Parametre READONLY ---- *)
PROCEDURE Double(READONLY n: INTEGER): INTEGER =
BEGIN
  RETURN n + n;
END Double;

(* ---- Recursion : factorielle ---- *)
PROCEDURE Factorial(n: INTEGER): INTEGER =
BEGIN
  IF n <= 1 THEN
    RETURN 1;
  ELSE
    RETURN n * Factorial(n - 1);
  END;
END Factorial;

(* ---- Recursion : Fibonacci ---- *)
PROCEDURE Fibonacci(n: INTEGER): INTEGER =
BEGIN
  IF n <= 0 THEN
    RETURN 0;
  ELSIF n = 1 THEN
    RETURN 1;
  ELSE
    RETURN Fibonacci(n - 1) + Fibonacci(n - 2);
  END;
END Fibonacci;

(* ---- Procedure avec INC/DEC ---- *)
PROCEDURE TestIncDec() =
VAR
  counter : INTEGER;
BEGIN
  counter := 10;
  INC(counter);
  Wr.PutText("Apres INC : ");
  Wr.PutInt(counter);
  Wr.Nl();

  INC(counter, 5);
  Wr.PutText("Apres INC(5) : ");
  Wr.PutInt(counter);
  Wr.Nl();

  DEC(counter);
  Wr.PutText("Apres DEC : ");
  Wr.PutInt(counter);
  Wr.Nl();
END TestIncDec;

(* ---- Procedure imbriquee ---- *)
PROCEDURE TestNested() =

  PROCEDURE Inner(): INTEGER =
  BEGIN
    RETURN 99;
  END Inner;

BEGIN
  Wr.PutText("Inner = ");
  Wr.PutInt(Inner());
  Wr.Nl();
END TestNested;

(* ---- Programme principal ---- *)
BEGIN
  Wr.PutText("=== Fonctions simples ===");
  Wr.Nl();

  result := Add(3, 7);
  Wr.PutText("Add(3,7) = ");
  Wr.PutInt(result);
  Wr.Nl();

  result := Square(6);
  Wr.PutText("Square(6) = ");
  Wr.PutInt(result);
  Wr.Nl();

  result := Double(21);
  Wr.PutText("Double(21) = ");
  Wr.PutInt(result);
  Wr.Nl();

  Wr.PutText("=== Recursion ===");
  Wr.Nl();

  result := Factorial(5);
  Wr.PutText("Factorial(5) = ");
  Wr.PutInt(result);
  Wr.Nl();

  result := Fibonacci(7);
  Wr.PutText("Fibonacci(7) = ");
  Wr.PutInt(result);
  Wr.Nl();

  Wr.PutText("=== INC / DEC ===");
  Wr.Nl();
  TestIncDec();

  Wr.PutText("=== Procedure imbriquee ===");
  Wr.Nl();
  TestNested();

  Wr.PutText("Termine.");
  Wr.Nl();
END MathExample.
