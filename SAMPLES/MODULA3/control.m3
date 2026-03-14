(* control.m3 - Exemple de structures de controle (TODO 25)             *)
(* Demontre : IF/ELSIF/ELSE, CASE (valeurs, multi, ranges, chars),     *)
(* WHILE, FOR, FOR BY, LOOP/EXIT, REPEAT/UNTIL.                        *)

MODULE ControlExample;

IMPORT Wr;

VAR
  i     : INTEGER;
  sum   : INTEGER;
  grade : INTEGER;

(* ---- IF / ELSIF / ELSE ---- *)
PROCEDURE TestIf() =
VAR
  x : INTEGER;
BEGIN
  x := 15;
  IF x < 10 THEN
    Wr.PutText("petit");
  ELSIF x < 20 THEN
    Wr.PutText("moyen");
  ELSE
    Wr.PutText("grand");
  END;
  Wr.Nl();
END TestIf;

(* ---- CASE avec valeurs simples ---- *)
PROCEDURE TestCase() =
VAR
  day : INTEGER;
BEGIN
  day := 3;
  CASE day OF
  | 1 => Wr.PutText("Lundi");
  | 2 => Wr.PutText("Mardi");
  | 3 => Wr.PutText("Mercredi");
  | 4 => Wr.PutText("Jeudi");
  | 5 => Wr.PutText("Vendredi");
  ELSE
    Wr.PutText("Weekend");
  END;
  Wr.Nl();
END TestCase;

(* ---- CASE avec intervalles ---- *)
PROCEDURE TestCaseRange() =
BEGIN
  grade := 82;
  CASE grade OF
  | 0..59   => Wr.PutText("Echec");
  | 60..69  => Wr.PutText("D");
  | 70..79  => Wr.PutText("C");
  | 80..89  => Wr.PutText("B");
  | 90..100 => Wr.PutText("A");
  ELSE
    Wr.PutText("Invalide");
  END;
  Wr.Nl();
END TestCaseRange;

(* ---- WHILE ---- *)
PROCEDURE TestWhile() =
BEGIN
  i := 1;
  sum := 0;
  WHILE i <= 10 DO
    sum := sum + i;
    i := i + 1;
  END;
  Wr.PutText("Somme 1..10 = ");
  Wr.PutInt(sum);
  Wr.Nl();
END TestWhile;

(* ---- FOR simple ---- *)
PROCEDURE TestFor() =
BEGIN
  Wr.PutText("Compteur : ");
  FOR i := 1 TO 5 DO
    Wr.PutInt(i);
    Wr.PutChar(' ');
  END;
  Wr.Nl();
END TestFor;

(* ---- FOR avec BY ---- *)
PROCEDURE TestForBy() =
BEGIN
  Wr.PutText("Pairs : ");
  FOR i := 0 TO 10 BY 2 DO
    Wr.PutInt(i);
    Wr.PutChar(' ');
  END;
  Wr.Nl();
END TestForBy;

(* ---- LOOP / EXIT ---- *)
PROCEDURE TestLoop() =
VAR
  count : INTEGER;
BEGIN
  count := 0;
  LOOP
    count := count + 1;
    IF count > 5 THEN
      EXIT;
    END;
  END;
  Wr.PutText("LOOP compte = ");
  Wr.PutInt(count);
  Wr.Nl();
END TestLoop;

(* ---- REPEAT / UNTIL ---- *)
PROCEDURE TestRepeat() =
VAR
  n : INTEGER;
BEGIN
  n := 1;
  Wr.PutText("Repeat : ");
  REPEAT
    Wr.PutInt(n);
    Wr.PutChar(' ');
    n := n + 1;
  UNTIL n > 5;
  Wr.Nl();
END TestRepeat;

(* ---- Programme principal ---- *)
BEGIN
  Wr.PutText("=== IF/ELSIF/ELSE ==="); Wr.Nl();
  TestIf();

  Wr.PutText("=== CASE ==="); Wr.Nl();
  TestCase();

  Wr.PutText("=== CASE range ==="); Wr.Nl();
  TestCaseRange();

  Wr.PutText("=== WHILE ==="); Wr.Nl();
  TestWhile();

  Wr.PutText("=== FOR ==="); Wr.Nl();
  TestFor();

  Wr.PutText("=== FOR BY ==="); Wr.Nl();
  TestForBy();

  Wr.PutText("=== LOOP/EXIT ==="); Wr.Nl();
  TestLoop();

  Wr.PutText("=== REPEAT/UNTIL ==="); Wr.Nl();
  TestRepeat();

  Wr.PutText("Termine.");
  Wr.Nl();
END ControlExample.
