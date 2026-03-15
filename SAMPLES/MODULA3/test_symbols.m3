(* test_symbols.m3 - Test de la table des symboles Modula-3 (TODO 05) *)
(* Verifie SymAdd, SymFind, SymMangle, SymEnterScope, SymLeaveScope   *)
(* et les symboles predeclares (types, constantes, procedures).       *)

MODULE TestSymbols;

IMPORT Wr, Fmt, Text;

CONST
  Pi    = 3;
  Max   = 100;
  Msg   = "Hello";

TYPE
  Color = {Red, Green, Blue};

VAR
  x : INTEGER;
  y : CARDINAL;
  ok : BOOLEAN;
  ch : CHAR;
  name : TEXT;

PROCEDURE Add(a : INTEGER; b : INTEGER) : INTEGER =
VAR
  result : INTEGER;
BEGIN
  result := a + b;
  RETURN result;
END Add;

PROCEDURE Greet(name : TEXT) =
BEGIN
  Wr.PutText("Hello, ");
  Wr.PutText(name);
  Wr.Nl();
END Greet;

EXCEPTION BadValue;

BEGIN
  x := 42;
  y := MAX(x, Max);
  ok := TRUE;
  ch := 'A';
  name := Msg;
  x := Add(10, 20);
  x := ABS(x);
  INC(x);
  DEC(y);
  Greet(name);
END TestSymbols.
