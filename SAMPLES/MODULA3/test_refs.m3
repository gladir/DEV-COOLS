(* test_refs.m3 - Test des types reference (TODO 22)                   *)
(* Verifie le code genere pour :                                       *)
(*   - TYPE T = REF U : declaration de type reference                  *)
(*   - TYPE T = BRANDED REF U : reference nominalement unique          *)
(*   - TYPE T = BRANDED "tag" REF U : avec etiquette                   *)
(*   - TYPE T = UNTRACED REF U : reference non tracee                  *)
(*   - VAR v : REF T : variable de type reference anonyme              *)
(*   - VAR r : REFANY : variable reference generique                   *)
(*   - NEW(IntRef) : allocation sur le heap via _M3RT_NEW              *)
(*   - ptr^ : dereferencement de pointeur                              *)
(*   - ptr^ := val : affectation a travers un pointeur                 *)
(*   - NIL : valeur nulle pour toute reference                         *)
(*   - DISPOSE(ptr) : liberation (stub)                                *)

MODULE TestRefs;

IMPORT Wr;

TYPE
  IntRef     = REF INTEGER;
  BrandedRef = BRANDED REF INTEGER;
  TaggedRef  = BRANDED "myTag" REF INTEGER;
  UntracedRef = UNTRACED REF INTEGER;

VAR
  p  : IntRef;
  q  : REF INTEGER;
  r  : REFANY;
  n  : INTEGER;

PROCEDURE TestNewAndDeref() =
VAR
  x : IntRef;
BEGIN
  x := NEW(IntRef);
  x^ := 42;
  n := x^;
  Wr.PutInt(n);
END TestNewAndDeref;

PROCEDURE TestNil() =
VAR
  y : IntRef;
BEGIN
  y := NIL;
  p := NIL;
  r := NIL;
END TestNil;

PROCEDURE TestDispose() =
VAR
  z : IntRef;
BEGIN
  z := NEW(IntRef);
  z^ := 99;
  DISPOSE(z);
END TestDispose;

BEGIN
  TestNewAndDeref();
  TestNil();
  TestDispose();
END TestRefs.
