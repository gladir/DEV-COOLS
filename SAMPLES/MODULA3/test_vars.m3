(* test_vars.m3 - Test des variables et affectations (TODO 09)      *)
(* Verifie ParseProcDecls, GenVarRef, GenVarAddr, EmitProcedures.  *)
(* Le compilateur doit trouver les PROCEDURE, leurs parametres     *)
(* (VALUE, VAR, READONLY), leurs variables locales, et generer     *)
(* le prologue et epilogue ASM pour chaque procedure.              *)

MODULE TestVars;

CONST
  MaxSize = 256;

VAR
  globalCount : INTEGER;
  globalFlag  : BOOLEAN;
  globalName  : TEXT;

PROCEDURE Init();
VAR
  temp : INTEGER;
  ok   : BOOLEAN;
BEGIN
  temp := 0;
  ok   := TRUE;
END Init;

PROCEDURE Add(a : INTEGER; b : INTEGER) : INTEGER;
VAR
  result : INTEGER;
BEGIN
  result := 0;
END Add;

PROCEDURE Swap(VAR x : INTEGER; VAR y : INTEGER);
VAR
  tmp : INTEGER;
BEGIN
  tmp := 0;
END Swap;

PROCEDURE PrintValue(READONLY val : INTEGER);
BEGIN
END PrintValue;

PROCEDURE Complex(a : INTEGER; VAR b : CARDINAL; READONLY c : TEXT);
VAR
  local1 : INTEGER;
  local2 : BOOLEAN;
  local3 : CHAR;
BEGIN
END Complex;

BEGIN
  globalCount := 0;
END TestVars.
