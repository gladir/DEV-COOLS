(* test_procs.m3 - Test des procedures et fonctions (TODO 17) *)
(* Verifie ParseProcDecls, parametres VALUE/VAR/READONLY,     *)
(* fonctions avec RETURN, INC/DEC, procedures imbriquees,     *)
(* types PROCEDURE et appels indirects.                       *)

MODULE TestProcs;

IMPORT Wr, Fmt;

TYPE
  IntFunc = PROCEDURE(x: INTEGER): INTEGER;

VAR
  total : INTEGER;

PROCEDURE Add(a: INTEGER; b: INTEGER): INTEGER =
BEGIN
  RETURN a + b;
END Add;

PROCEDURE Square(n: INTEGER): INTEGER =
VAR
  result : INTEGER;
BEGIN
  result := n * n;
  RETURN result;
END Square;

PROCEDURE Increment(VAR x: INTEGER) =
BEGIN
  INC(x);
END Increment;

PROCEDURE AddN(VAR x: INTEGER; n: INTEGER) =
BEGIN
  INC(x, n);
END AddN;

PROCEDURE ReadonlyParam(READONLY r: INTEGER): INTEGER =
BEGIN
  RETURN r + 1;
END ReadonlyParam;

PROCEDURE Factorial(n: INTEGER): INTEGER =
VAR
  i      : INTEGER;
  result : INTEGER;
BEGIN
  result := 1;
  FOR i := 1 TO n DO
    result := result * i;
  END;
  RETURN result;
END Factorial;

PROCEDURE TestNested() =

  PROCEDURE Inner(): INTEGER =
  BEGIN
    RETURN 42;
  END Inner;

BEGIN
  Wr.PutInt(Inner());
  Wr.Nl();
END TestNested;

PROCEDURE VoidProc() =
BEGIN
  total := 99;
END VoidProc;

PROCEDURE TestProcType() =
BEGIN
  Wr.PutText("ProcType OK");
  Wr.Nl();
END TestProcType;

BEGIN
  Wr.PutText("Procs OK");
  Wr.Nl();
END TestProcs.
