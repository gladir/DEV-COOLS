(* generic.m3 - Exemple de modules generiques (TODO 25)                 *)
(* Demontre : GENERIC INTERFACE, GENERIC MODULE, instanciation,        *)
(* parametres de genericite, PROCEDURE dans generiques,                 *)
(* prefixe _M3G_ pour les instances.                                    *)

(* ---- Definition generique d une pile simple ---- *)
GENERIC INTERFACE GenStack(ElemIntf);
  TYPE T <: REFANY;
  PROCEDURE Create(): T;
  PROCEDURE Push(s: T; val: INTEGER);
  PROCEDURE Pop(s: T): INTEGER;
  PROCEDURE IsEmpty(s: T): BOOLEAN;
END GenStack.

GENERIC MODULE GenStack(ElemIntf);
  TYPE T = REF RECORD
    top : INTEGER;
  END;
  PROCEDURE Create(): T =
  BEGIN
    RETURN NEW(T);
  END Create;
  PROCEDURE Push(s: T; val: INTEGER) =
  BEGIN
    s.top := val;
  END Push;
  PROCEDURE Pop(s: T): INTEGER =
  BEGIN
    RETURN s.top;
  END Pop;
  PROCEDURE IsEmpty(s: T): BOOLEAN =
  BEGIN
    RETURN s.top = 0;
  END IsEmpty;
END GenStack.

(* ---- Instanciation ---- *)
INTERFACE IntStack = GenStack(IntElem) END IntStack.
MODULE IntStack = GenStack(IntElem) END IntStack.

