MODULE TestExceptions EXPORTS Main;

IMPORT Wr;

EXCEPTION
  NotFound;
  OutOfRange(INTEGER);
  InvalidArg;

VAR
  x: INTEGER;

PROCEDURE TestTryExcept() =
BEGIN
  TRY
    x := 10;
    Wr.PutText("Inside TRY block");
    Wr.Nl();
  EXCEPT
  | NotFound =>
    Wr.PutText("Caught NotFound");
    Wr.Nl();
  | OutOfRange(v) =>
    Wr.PutText("Caught OutOfRange");
    Wr.Nl();
  ELSE
    Wr.PutText("Caught unknown");
    Wr.Nl();
  END;
END TestTryExcept;

PROCEDURE TestTryFinally() =
BEGIN
  TRY
    x := 20;
    Wr.PutText("TRY body");
    Wr.Nl();
  FINALLY
    Wr.PutText("FINALLY block");
    Wr.Nl();
  END;
END TestTryFinally;

PROCEDURE TestRaise() =
BEGIN
  TRY
    RAISE NotFound;
  EXCEPT
  | NotFound =>
    Wr.PutText("Caught raised NotFound");
    Wr.Nl();
  END;
END TestRaise;

PROCEDURE TestRaiseArg() =
BEGIN
  TRY
    RAISE OutOfRange(42);
  EXCEPT
  | OutOfRange(v) =>
    Wr.PutText("Caught OutOfRange with arg");
    Wr.Nl();
  END;
END TestRaiseArg;

BEGIN
  TestTryExcept();
  TestTryFinally();
  TestRaise();
  TestRaiseArg();
END TestExceptions.
