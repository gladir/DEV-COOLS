(* test_records.m3 - Test des enregistrements RECORD et WITH (TODO 16) *)
(* Verifie ParseRecordTypeFromTokens, RecordFieldFind,                 *)
(* DataAddGlobalRecordVar, acces champ lecture/ecriture,               *)
(* ParseWithStmt, et variables locales de type RECORD.                 *)

MODULE TestRecords;

IMPORT Wr, Fmt;

TYPE
  Point = RECORD
    x : INTEGER;
    y : INTEGER;
  END;

  Color = RECORD
    r : INTEGER;
    g : INTEGER;
    b : INTEGER;
  END;

  Pair = RECORD
    first  : INTEGER;
    second : INTEGER;
  END;

VAR
  origin : Point;
  red    : Color;

PROCEDURE TestFieldAssign() =
VAR
  p : Point;
  c : Color;
BEGIN
  (* Assigner des champs de record *)
  p.x := 10;
  p.y := 20;
  c.r := 255;
  c.g := 0;
  c.b := 0;
END TestFieldAssign;

PROCEDURE TestFieldRead() =
VAR
  p   : Point;
  sum : INTEGER;
BEGIN
  p.x := 3;
  p.y := 4;
  (* Lire des champs de record *)
  sum := p.x;
END TestFieldRead;

PROCEDURE TestGlobalRecord() =
BEGIN
  origin.x := 0;
  origin.y := 0;
  red.r := 255;
  red.g := 0;
  red.b := 0;
END TestGlobalRecord;

PROCEDURE TestWith() =
VAR
  val : INTEGER;
BEGIN
  val := 42;
  WITH tmp = val DO
    Wr.PutInt(tmp);
    Wr.Nl();
  END;
END TestWith;

PROCEDURE TestMultiRecord() =
VAR
  a : Pair;
  b : Pair;
BEGIN
  a.first  := 1;
  a.second := 2;
  b.first  := 3;
  b.second := 4;
END TestMultiRecord;

BEGIN
  Wr.PutText("Records OK");
  Wr.Nl();
END TestRecords.
