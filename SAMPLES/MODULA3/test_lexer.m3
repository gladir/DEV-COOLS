MODULE TestLexer;

(* Commentaire simple *)
(* Commentaire (* imbrique *) fin *)

IMPORT Wr;

CONST
  MaxVal = 100;
  HexVal = 16_FF;
  OctVal = 8_77;
  BinVal = 2_1010;
  Pi     = 3.14159;
  Msg    = "Hello, Modula-3!\n";

TYPE
  Color = {Red, Green, Blue};

VAR
  x : INTEGER;
  y : CARDINAL;
  name : TEXT;
  ch   : CHAR;

PROCEDURE Factorial(n : INTEGER) : INTEGER =
BEGIN
  IF n <= 1 THEN
    RETURN 1;
  ELSE
    RETURN n * Factorial(n - 1);
  END;
END Factorial;

BEGIN
  x := 42;
  y := 16_CAFE;
  name := "World";
  ch := 'A';
  Wr.PutText("Result: ");
  Wr.PutInt(Factorial(10));
  Wr.Nl();
  FOR i := 1 TO MaxVal BY 2 DO
    x := x + i;
  END;
  WHILE x > 0 DO
    x := x DIV 2;
  END;
  REPEAT
    y := y - 1;
  UNTIL y = 0;
  CASE x OF
  | 0 => Wr.PutText("zero");
  | 1..9 => Wr.PutText("petit");
  ELSE
    Wr.PutText("grand");
  END;
END TestLexer.
