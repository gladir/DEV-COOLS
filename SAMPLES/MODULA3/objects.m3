(* objects.m3 - Exemple de types objets et methodes (TODO 25)           *)
(* Demontre : OBJECT, METHODS, OVERRIDES, heritage, NEW(T),            *)
(* acces champs objet, appel de methode virtuelle,                      *)
(* ISTYPE, NARROW, TYPECODE.                                            *)

MODULE ObjectExample;

IMPORT Wr;

TYPE
  Shape = OBJECT
    name  : INTEGER;
    color : INTEGER;
  METHODS
    area(): INTEGER;
    draw(): INTEGER;
  END;

TYPE
  Circle = Shape OBJECT
    radius : INTEGER;
  OVERRIDES
    area := CircleArea;
  END;

TYPE
  Rect = Shape OBJECT
    width  : INTEGER;
    height : INTEGER;
  OVERRIDES
    area := RectArea;
  END;

VAR
  s : Shape;
  c : Circle;
  r : Rect;

PROCEDURE CircleArea() =
BEGIN
  Wr.PutText("Circle area");
  Wr.Nl();
END CircleArea;

PROCEDURE RectArea() =
BEGIN
  Wr.PutText("Rect area");
  Wr.Nl();
END RectArea;

(* ---- Creation et champs ---- *)
PROCEDURE TestNew() =
VAR
  obj : Shape;
BEGIN
  obj := NEW(Shape);
  obj.name  := 1;
  obj.color := 255;

  Wr.PutText("Shape.name = ");
  Wr.PutInt(obj.name);
  Wr.Nl();

  Wr.PutText("Shape.color = ");
  Wr.PutInt(obj.color);
  Wr.Nl();
END TestNew;

(* ---- Heritage ---- *)
PROCEDURE TestInherit() =
VAR
  circ : Circle;
BEGIN
  circ := NEW(Circle);
  circ.name   := 2;
  circ.color  := 128;
  circ.radius := 10;

  Wr.PutText("Circle.radius = ");
  Wr.PutInt(circ.radius);
  Wr.Nl();
END TestInherit;

(* ---- ISTYPE et TYPECODE ---- *)
PROCEDURE TestIstype() =
VAR
  d : Circle;
  tc : INTEGER;
BEGIN
  d := NEW(Circle);
  tc := TYPECODE(Circle);
  Wr.PutText("TYPECODE(Circle) = ");
  Wr.PutInt(tc);
  Wr.Nl();

  IF ISTYPE(d, Circle) THEN
    Wr.PutText("ISTYPE: oui");
  ELSE
    Wr.PutText("ISTYPE: non");
  END;
  Wr.Nl();
END TestIstype;

(* ---- Programme principal ---- *)
BEGIN
  Wr.PutText("=== NEW ==="); Wr.Nl();
  TestNew();

  Wr.PutText("=== Heritage ==="); Wr.Nl();
  TestInherit();

  Wr.PutText("=== ISTYPE/TYPECODE ==="); Wr.Nl();
  TestIstype();

  Wr.PutText("Termine.");
  Wr.Nl();
END ObjectExample.
