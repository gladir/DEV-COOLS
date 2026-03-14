(* test_control.m3 - Test des instructions de controle (TODO 13)       *)
(* Verifie le code genere pour :                                       *)
(*   - IF / ELSIF / ELSE / END (deja implemente depuis TODO 12)        *)
(*   - CASE expr OF | val => stmts | val,val => | lo..hi => ELSE END   *)
(*   - TYPECASE expr OF | Type(v) => stmts ELSE stmts END              *)

MODULE TestControl;

IMPORT Wr;

VAR
  x     : INTEGER;
  code  : INTEGER;
  ch    : CHAR;
  grade : INTEGER;

(* ---- Test 1 : IF / ELSIF / ELSE simple ---- *)
PROCEDURE TestIf();
BEGIN
  x := 10;
  IF x = 10 THEN
    Wr.PutText("x is 10");
    Wr.Nl();
  ELSIF x = 20 THEN
    Wr.PutText("x is 20");
    Wr.Nl();
  ELSE
    Wr.PutText("x is other");
    Wr.Nl();
  END;
END TestIf;

(* ---- Test 2 : CASE avec valeurs simples ---- *)
PROCEDURE TestCaseSimple();
BEGIN
  code := 2;
  CASE code OF
  | 1 => Wr.PutText("one"); Wr.Nl();
  | 2 => Wr.PutText("two"); Wr.Nl();
  | 3 => Wr.PutText("three"); Wr.Nl();
  ELSE
    Wr.PutText("other"); Wr.Nl();
  END;
END TestCaseSimple;

(* ---- Test 3 : CASE avec valeurs multiples ---- *)
PROCEDURE TestCaseMulti();
BEGIN
  code := 5;
  CASE code OF
  | 1, 2, 3 => Wr.PutText("low"); Wr.Nl();
  | 4, 5, 6 => Wr.PutText("mid"); Wr.Nl();
  | 7, 8, 9 => Wr.PutText("high"); Wr.Nl();
  ELSE
    Wr.PutText("out of range"); Wr.Nl();
  END;
END TestCaseMulti;

(* ---- Test 4 : CASE avec intervalles lo..hi ---- *)
PROCEDURE TestCaseRange();
BEGIN
  grade := 75;
  CASE grade OF
  | 0..59   => Wr.PutText("F"); Wr.Nl();
  | 60..69  => Wr.PutText("D"); Wr.Nl();
  | 70..79  => Wr.PutText("C"); Wr.Nl();
  | 80..89  => Wr.PutText("B"); Wr.Nl();
  | 90..100 => Wr.PutText("A"); Wr.Nl();
  ELSE
    Wr.PutText("invalid"); Wr.Nl();
  END;
END TestCaseRange;

(* ---- Test 5 : CASE avec caracteres ---- *)
PROCEDURE TestCaseChar();
BEGIN
  ch := 'B';
  CASE ch OF
  | 'A' => Wr.PutText("Alpha"); Wr.Nl();
  | 'B' => Wr.PutText("Bravo"); Wr.Nl();
  | 'C' => Wr.PutText("Charlie"); Wr.Nl();
  ELSE
    Wr.PutText("Unknown"); Wr.Nl();
  END;
END TestCaseChar;

(* ---- Test 6 : CASE sans ELSE ---- *)
PROCEDURE TestCaseNoElse();
BEGIN
  code := 1;
  CASE code OF
  | 1 => Wr.PutText("found 1"); Wr.Nl();
  | 2 => Wr.PutText("found 2"); Wr.Nl();
  END;
END TestCaseNoElse;

(* ---- Test 7 : CASE avec mix valeurs et intervalles ---- *)
PROCEDURE TestCaseMixed();
BEGIN
  code := 50;
  CASE code OF
  | 0       => Wr.PutText("zero"); Wr.Nl();
  | 1..10   => Wr.PutText("1 to 10"); Wr.Nl();
  | 42      => Wr.PutText("answer"); Wr.Nl();
  | 50..100 => Wr.PutText("50 to 100"); Wr.Nl();
  ELSE
    Wr.PutText("else"); Wr.Nl();
  END;
END TestCaseMixed;

(* ---- Test 8 : TYPECASE basique (stub OOP) ---- *)
PROCEDURE TestTypecase();
BEGIN
  x := 42;
  TYPECASE x OF
  | INTEGER => Wr.PutText("is integer"); Wr.Nl();
  ELSE
    Wr.PutText("unknown type"); Wr.Nl();
  END;
END TestTypecase;

(* ---- Programme principal ---- *)
BEGIN
  Wr.PutText("=== Test IF ==="); Wr.Nl();
  TestIf();

  Wr.PutText("=== Test CASE simple ==="); Wr.Nl();
  TestCaseSimple();

  Wr.PutText("=== Test CASE multi ==="); Wr.Nl();
  TestCaseMulti();

  Wr.PutText("=== Test CASE range ==="); Wr.Nl();
  TestCaseRange();

  Wr.PutText("=== Test CASE char ==="); Wr.Nl();
  TestCaseChar();

  Wr.PutText("=== Test CASE no else ==="); Wr.Nl();
  TestCaseNoElse();

  Wr.PutText("=== Test CASE mixed ==="); Wr.Nl();
  TestCaseMixed();

  Wr.PutText("=== Test TYPECASE ==="); Wr.Nl();
  TestTypecase();

  Wr.PutText("=== All control tests done ==="); Wr.Nl();
END TestControl.
