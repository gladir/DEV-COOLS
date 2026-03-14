(* test_generics.m3 - Test des modules generiques (TODO 23)             *)
(* Verifie le code genere pour :                                        *)
(*   - GENERIC INTERFACE : declarations parametrees par interfaces      *)
(*   - GENERIC MODULE : implementation parametree                       *)
(*   - Instanciation INTERFACE Inst = Gen(Params) END Inst.             *)
(*   - Instanciation MODULE Inst = Gen(Params) END Inst.                *)
(*   - Parametres formels multiples                                     *)
(*   - Prefixe _M3G_ pour les labels des instances generiques          *)
(*   - Limitation : un seul niveau de genericite                        *)

(* ---- Definition generique d un conteneur simple ---- *)
GENERIC INTERFACE GenContainer(ElemIntf);
  TYPE T <: REFANY;
  PROCEDURE Create(): T;
  PROCEDURE Store(c: T; val: INTEGER);
  PROCEDURE Fetch(c: T): INTEGER;
END GenContainer.

GENERIC MODULE GenContainer(ElemIntf);
  TYPE T = REF RECORD val: INTEGER; END;
  PROCEDURE Create(): T =
  BEGIN
    RETURN NEW(T);
  END Create;
  PROCEDURE Store(c: T; val: INTEGER) =
  BEGIN
    c.val := val;
  END Store;
  PROCEDURE Fetch(c: T): INTEGER =
  BEGIN
    RETURN c.val;
  END Fetch;
END GenContainer.

(* ---- Instanciation du generique ---- *)
INTERFACE IntContainer = GenContainer(IntElem) END IntContainer.
MODULE IntContainer = GenContainer(IntElem) END IntContainer.

