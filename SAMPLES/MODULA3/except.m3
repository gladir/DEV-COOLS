(* except.m3 - Exemple d exceptions (TODO 25)                          *)
(* Demontre : EXCEPTION, TRY/EXCEPT, TRY/FINALLY, RAISE,              *)
(* exceptions avec argument, ELSE catch-all, gestion d erreurs.        *)

MODULE ExceptExample;

IMPORT Wr;

EXCEPTION
  FileNotFound;
  DivByZero;
  RangeError(INTEGER);

VAR
  x : INTEGER;

(* ---- TRY / EXCEPT basique ---- *)
PROCEDURE TestBasic() =
BEGIN
  TRY
    x := 10;
    Wr.PutText("TRY block OK");
    Wr.Nl();
  EXCEPT
  | FileNotFound =>
    Wr.PutText("Caught FileNotFound");
    Wr.Nl();
  | DivByZero =>
    Wr.PutText("Caught DivByZero");
    Wr.Nl();
  ELSE
    Wr.PutText("Caught other");
    Wr.Nl();
  END;
END TestBasic;

(* ---- RAISE et capture ---- *)
PROCEDURE TestRaise() =
BEGIN
  TRY
    Wr.PutText("Avant RAISE");
    Wr.Nl();
    RAISE FileNotFound;
  EXCEPT
  | FileNotFound =>
    Wr.PutText("Capte FileNotFound");
    Wr.Nl();
  END;
END TestRaise;

(* ---- RAISE avec argument ---- *)
PROCEDURE TestRaiseArg() =
BEGIN
  TRY
    RAISE RangeError(42);
  EXCEPT
  | RangeError(v) =>
    Wr.PutText("Capte RangeError");
    Wr.Nl();
  END;
END TestRaiseArg;

(* ---- TRY / FINALLY ---- *)
PROCEDURE TestFinally() =
BEGIN
  TRY
    x := 100;
    Wr.PutText("Corps TRY");
    Wr.Nl();
  FINALLY
    Wr.PutText("FINALLY execute");
    Wr.Nl();
  END;
END TestFinally;

(* ---- ELSE catch-all ---- *)
PROCEDURE TestElse() =
BEGIN
  TRY
    x := 0;
  EXCEPT
  ELSE
    Wr.PutText("ELSE catch-all");
    Wr.Nl();
  END;
END TestElse;

(* ---- Programme principal ---- *)
BEGIN
  Wr.PutText("=== TRY/EXCEPT ==="); Wr.Nl();
  TestBasic();

  Wr.PutText("=== RAISE ==="); Wr.Nl();
  TestRaise();

  Wr.PutText("=== RAISE arg ==="); Wr.Nl();
  TestRaiseArg();

  Wr.PutText("=== TRY/FINALLY ==="); Wr.Nl();
  TestFinally();

  Wr.PutText("=== ELSE catch-all ==="); Wr.Nl();
  TestElse();

  Wr.PutText("Termine.");
  Wr.Nl();
END ExceptExample.
