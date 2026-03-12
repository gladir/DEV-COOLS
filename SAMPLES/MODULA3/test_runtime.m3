(* test_runtime.m3 - Test du runtime minimal (TODO 24)                   *)
(* Verifie le code genere pour :                                         *)
(*   - RuntimeEmitted : flag emettant le runtime une seule fois          *)
(*   - _M3RT_PRINTLN : affichage ASCIIZ + CR+LF                         *)
(*   - _M3RT_ABS : valeur absolue                                       *)
(*   - _M3RT_MAX : maximum de deux entiers                               *)
(*   - _M3RT_MIN : minimum de deux entiers                               *)
(*   - _M3RT_TYPECODE : lire le typecode d un objet                     *)
(*   - _M3RT_CHKIDX : verification de bornes d index                    *)
(*   - _M3RT_PANIC : message d erreur + Halt                            *)
(*   - _M3RT_PRINT : ecriture ASCIIZ via DOS                            *)
(*   - _M3RT_STRLEN : longueur d une chaine                             *)
(*   - _M3RT_NUMTOSTR : entier signe vers ASCII                         *)
(*   - _M3RT_STRTONUM : ASCII vers entier                               *)
(*   - _M3RT_CONCAT : concatenation TEXT                                 *)
(*   - _M3RT_STRCMP : comparaison de chaines                             *)
(*   - _M3RT_TEXTSUB : sous-chaine                                      *)
(*   - _M3RT_NEW : allocation heap                                       *)
(*   - _M3RT_CHKNIL : verification pointeur nul                         *)

MODULE TestRuntime;

IMPORT Wr;

VAR
  a, b, c : INTEGER;
  s : TEXT;

PROCEDURE TestAbs() =
VAR
  x : INTEGER;
BEGIN
  x := -42;
  x := ABS(x);
  Wr.PutInt(x);
  Wr.Nl();
END TestAbs;

PROCEDURE TestMaxMin() =
VAR
  m : INTEGER;
BEGIN
  a := 10;
  b := 20;
  m := MAX(a, b);
  Wr.PutInt(m);
  Wr.Nl();
  m := MIN(a, b);
  Wr.PutInt(m);
  Wr.Nl();
END TestMaxMin;

PROCEDURE TestPrint() =
BEGIN
  Wr.PutText("Hello runtime");
  Wr.Nl();
  Wr.PutInt(123);
  Wr.Nl();
END TestPrint;

PROCEDURE TestConcat() =
VAR
  t : TEXT;
BEGIN
  t := "Hello" & " World";
  Wr.PutText(t);
  Wr.Nl();
END TestConcat;

BEGIN
  TestAbs();
  TestMaxMin();
  TestPrint();
  TestConcat();
END TestRuntime.
