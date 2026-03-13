(* test_types.m3 - Test du systeme de types Modula-3 (TODO 06) *)
(* Verifie TypeInit, TypeAdd, TypeSizeof, TypeFindByName,       *)
(* TypeIsOrdinal, TypeIsNumeric, TypeIsPointer, TypeCompatible. *)

MODULE TestTypes;

IMPORT Wr, Fmt;

CONST
  MaxItems = 100;
  Pi       = 3;
  Msg      = "Hello";
  Yes      = TRUE;

TYPE
  Color   = {Red, Green, Blue};
  IntRange = [0..255];
  CharArray = ARRAY [0..9] OF CHAR;
  Point   = RECORD
    x : INTEGER;
    y : INTEGER;
  END;
  PointRef = REF Point;
  Callback = PROCEDURE (n : INTEGER) : INTEGER;

VAR
  i     : INTEGER;
  c     : CARDINAL;
  ok    : BOOLEAN;
  ch    : CHAR;
  r     : REAL;
  lr    : LONGREAL;
  name  : TEXT;
  col   : Color;
  sub   : IntRange;
  buf   : CharArray;
  pt    : Point;
  pRef  : PointRef;
  cb    : Callback;

PROCEDURE Square(n : INTEGER) : INTEGER =
BEGIN
  RETURN n * n;
END Square;

PROCEDURE TestAssign() =
VAR
  a : INTEGER;
  b : CARDINAL;
  x : REAL;
BEGIN
  (* INTEGER <-> CARDINAL *)
  a := 42;
  b := a;
  a := b;

  (* CHAR -> INTEGER (ORD) *)
  a := ORD('A');

  (* BOOLEAN -> INTEGER *)
  a := ORD(TRUE);

  (* REAL <-> INTEGER *)
  x := 3;
  a := TRUNC(x);

  (* NIL -> REF *)
  pRef := NIL;
  name := NIL;
END TestAssign;

BEGIN
  i := 10;
  c := 20;
  ok := TRUE;
  ch := 'A';
  r := 3;
  lr := 6;
  name := Msg;
  col := Color.Red;
  sub := 128;
  pt.x := 1;
  pt.y := 2;
  pRef := NIL;
  cb := Square;
  i := Square(i);
  Wr.PutText("Types OK");
  Wr.Nl();
END TestTypes.
