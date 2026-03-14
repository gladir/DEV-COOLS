(* test_dataseg.m3 - Test du segment de donnees (TODO 08)           *)
(* Verifie ParseDataDecls, DataAddGlobalVar, DataAddGlobalConst.    *)
(* Le compilateur doit generer des entrees DATA pour les variables  *)
(* globales (VAR) et les constantes (CONST) au niveau MODULE.       *)

MODULE TestDataSeg;

CONST
  MaxItems = 100;
  AppName  = "Modula-3 Test";
  Version  = "2.0";
  PiTrunc  = 3;
  Debug    = TRUE;
  NegVal   = -42;

VAR
  count   : INTEGER;
  total   : CARDINAL;
  flag    : BOOLEAN;
  initial : CHAR;
  name    : TEXT;
  score   : REAL;

BEGIN
  count := MaxItems;
  total := 0;
END TestDataSeg.
