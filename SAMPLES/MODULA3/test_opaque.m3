(* test_opaque.m3 - Test des types opaques et REVEAL (TODO 20)        *)
(* Verifie le code genere pour :                                       *)
(*   - TYPE T <: SuperType : declaration opaque                        *)
(*   - REVEAL T = SuperType OBJECT ... END : revelation                *)
(*   - REVEAL T = SuperType BRANDED OBJECT ... END : revelation BRANDED*)
(*   - REVEAL T = ExistingType : revelation simple                     *)

MODULE TestOpaque;

IMPORT Wr;

TYPE
  (* Type opaque : les clients ne voient que ROOT *)
  Handle <: ROOT;

TYPE
  (* Type opaque avec supertype nomme *)
  Shape <: ROOT;

(* Revelation complete de Handle *)
REVEAL Handle = ROOT BRANDED OBJECT
  id    : INTEGER;
  state : INTEGER;
METHODS
  getID(): INTEGER;
END;

(* Revelation de Shape sans BRANDED *)
REVEAL Shape = ROOT OBJECT
  x : INTEGER;
  y : INTEGER;
METHODS
  area(): INTEGER;
END;

VAR
  h : Handle;
  s : Shape;
  result : INTEGER;

PROCEDURE GetHandleID() =
BEGIN
  Wr.PutInt(99);
END GetHandleID;

PROCEDURE GetArea() =
BEGIN
  Wr.PutInt(100);
END GetArea;

PROCEDURE TestHandle() =
VAR
  hh : Handle;
BEGIN
  hh := NEW(Handle);
  hh.id := 42;
  hh.state := 1;
  Wr.PutInt(hh.id);
END TestHandle;

PROCEDURE TestShape() =
VAR
  ss : Shape;
BEGIN
  ss := NEW(Shape);
  ss.x := 10;
  ss.y := 20;
  Wr.PutInt(ss.x);
END TestShape;

BEGIN
  TestHandle();
  TestShape();
END TestOpaque.
