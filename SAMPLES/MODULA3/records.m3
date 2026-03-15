(* records.m3 - Exemple de RECORD et WITH (TODO 25)                     *)
(* Demontre : TYPE T = RECORD ... END, acces champs lecture/ecriture,  *)
(* variables globales et locales de type RECORD, WITH aliasing,        *)
(* constructeurs de record, multiple types RECORD.                     *)

MODULE RecordExample;

IMPORT Wr;

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

  Person = RECORD
    age    : INTEGER;
    height : INTEGER;
  END;

VAR
  origin : Point;
  red    : Color;

(* ---- Affectation et lecture de champs ---- *)
PROCEDURE TestFields() =
VAR
  p : Point;
  c : Color;
BEGIN
  p.x := 10;
  p.y := 20;

  Wr.PutText("Point : (");
  Wr.PutInt(p.x);
  Wr.PutText(", ");
  Wr.PutInt(p.y);
  Wr.PutText(")");
  Wr.Nl();

  c.r := 255;
  c.g := 128;
  c.b := 0;

  Wr.PutText("Color : (");
  Wr.PutInt(c.r);
  Wr.PutText(", ");
  Wr.PutInt(c.g);
  Wr.PutText(", ");
  Wr.PutInt(c.b);
  Wr.PutText(")");
  Wr.Nl();
END TestFields;

(* ---- Variables globales de type RECORD ---- *)
PROCEDURE TestGlobal() =
BEGIN
  origin.x := 0;
  origin.y := 0;

  red.r := 255;
  red.g := 0;
  red.b := 0;

  Wr.PutText("Origin.x = ");
  Wr.PutInt(origin.x);
  Wr.Nl();

  Wr.PutText("Red.r = ");
  Wr.PutInt(red.r);
  Wr.Nl();
END TestGlobal;

(* ---- WITH statement ---- *)
PROCEDURE TestWith() =
VAR
  val : INTEGER;
BEGIN
  val := 42;
  WITH alias = val DO
    Wr.PutText("WITH alias = ");
    Wr.PutInt(alias);
    Wr.Nl();
  END;
END TestWith;

(* ---- Multiple records ---- *)
PROCEDURE TestMultiple() =
VAR
  alice : Person;
  bob   : Person;
BEGIN
  alice.age    := 30;
  alice.height := 165;
  bob.age      := 25;
  bob.height   := 180;

  Wr.PutText("Alice age = ");
  Wr.PutInt(alice.age);
  Wr.Nl();

  Wr.PutText("Bob height = ");
  Wr.PutInt(bob.height);
  Wr.Nl();
END TestMultiple;

(* ---- Programme principal ---- *)
BEGIN
  Wr.PutText("=== Champs ==="); Wr.Nl();
  TestFields();

  Wr.PutText("=== Globals ==="); Wr.Nl();
  TestGlobal();

  Wr.PutText("=== WITH ==="); Wr.Nl();
  TestWith();

  Wr.PutText("=== Multiple ==="); Wr.Nl();
  TestMultiple();

  Wr.PutText("Termine.");
  Wr.Nl();
END RecordExample.
