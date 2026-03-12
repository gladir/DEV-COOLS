(* test_interface.i3 - Test d une interface Modula-3 (TODO 18) *)
(* Un fichier INTERFACE ne contient que des declarations,     *)
(* pas de corps BEGIN...END. Toutes les declarations sont     *)
(* automatiquement exportees.                                  *)

INTERFACE TestInterface;

CONST
  MaxSize = 100;
  Label   = "TestInterface";

TYPE
  Index = INTEGER;

VAR
  count : INTEGER;

PROCEDURE Init();
PROCEDURE GetCount(): INTEGER;
PROCEDURE SetCount(n: INTEGER);

END TestInterface.
