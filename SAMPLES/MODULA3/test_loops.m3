(* test_loops.m3 - Test des boucles (TODO 14)                          *)
(* Verifie le code genere pour :                                       *)
(*   - WHILE cond DO stmts END                                         *)
(*   - FOR ident := lo TO hi [BY step] DO stmts END                    *)
(*   - LOOP stmts EXIT END (boucle infinie avec sortie)                *)
(*   - REPEAT stmts UNTIL cond                                         *)
(*   - EXIT dans boucle LOOP imbriquee                                 *)

MODULE TestLoops;

IMPORT Wr;

VAR
  i     : INTEGER;
  sum   : INTEGER;
  count : INTEGER;
  done  : BOOLEAN;

(* ---- Test 1 : WHILE simple ---- *)
PROCEDURE TestWhile();
BEGIN
  i := 1;
  Wr.PutText("WHILE 1..5: ");
  WHILE i <= 5 DO
    Wr.PutInt(i);
    Wr.PutChar(' ');
    i := i + 1;
  END;
  Wr.Nl();
END TestWhile;

(* ---- Test 2 : WHILE avec condition fausse d entree ---- *)
PROCEDURE TestWhileFalse();
BEGIN
  i := 10;
  Wr.PutText("WHILE false: ");
  WHILE i < 5 DO
    Wr.PutText("ERREUR");
    i := i + 1;
  END;
  Wr.PutText("ok");
  Wr.Nl();
END TestWhileFalse;

(* ---- Test 3 : FOR simple croissant ---- *)
PROCEDURE TestFor();
BEGIN
  Wr.PutText("FOR 1..5: ");
  FOR i := 1 TO 5 DO
    Wr.PutInt(i);
    Wr.PutChar(' ');
  END;
  Wr.Nl();
END TestFor;

(* ---- Test 4 : FOR avec BY 2 ---- *)
PROCEDURE TestForBy2();
BEGIN
  Wr.PutText("FOR 0..10 BY 2: ");
  FOR i := 0 TO 10 BY 2 DO
    Wr.PutInt(i);
    Wr.PutChar(' ');
  END;
  Wr.Nl();
END TestForBy2;

(* ---- Test 5 : FOR avec BY -1 (decroissant) ---- *)
PROCEDURE TestForByNeg();
BEGIN
  Wr.PutText("FOR 5..1 BY -1: ");
  FOR i := 5 TO 1 BY -1 DO
    Wr.PutInt(i);
    Wr.PutChar(' ');
  END;
  Wr.Nl();
END TestForByNeg;

(* ---- Test 6 : LOOP avec EXIT ---- *)
PROCEDURE TestLoop();
BEGIN
  i := 0;
  Wr.PutText("LOOP/EXIT: ");
  LOOP
    i := i + 1;
    IF i > 5 THEN
      EXIT;
    END;
    Wr.PutInt(i);
    Wr.PutChar(' ');
  END;
  Wr.Nl();
END TestLoop;

(* ---- Test 7 : REPEAT UNTIL ---- *)
PROCEDURE TestRepeat();
BEGIN
  i := 1;
  Wr.PutText("REPEAT 1..5: ");
  REPEAT
    Wr.PutInt(i);
    Wr.PutChar(' ');
    i := i + 1;
  UNTIL i > 5;
  Wr.Nl();
END TestRepeat;

(* ---- Test 8 : WHILE avec somme cumulative ---- *)
PROCEDURE TestWhileSum();
BEGIN
  sum := 0;
  i := 1;
  WHILE i <= 10 DO
    sum := sum + i;
    i := i + 1;
  END;
  Wr.PutText("Sum 1..10 = ");
  Wr.PutInt(sum);
  Wr.Nl();
END TestWhileSum;

(* ---- Test 9 : FOR avec BY 3 ---- *)
PROCEDURE TestForBy3();
BEGIN
  Wr.PutText("FOR 1..15 BY 3: ");
  FOR i := 1 TO 15 BY 3 DO
    Wr.PutInt(i);
    Wr.PutChar(' ');
  END;
  Wr.Nl();
END TestForBy3;

(* ---- Test 10 : LOOP imbrique avec EXIT ---- *)
PROCEDURE TestNestedLoop();
BEGIN
  Wr.PutText("Nested LOOP: ");
  i := 0;
  LOOP
    i := i + 1;
    count := 0;
    LOOP
      count := count + 1;
      IF count >= 3 THEN
        EXIT;
      END;
    END;
    Wr.PutInt(i);
    Wr.PutChar(' ');
    IF i >= 4 THEN
      EXIT;
    END;
  END;
  Wr.Nl();
END TestNestedLoop;

(* ---- Programme principal ---- *)
BEGIN
  Wr.PutText("=== Test WHILE ==="); Wr.Nl();
  TestWhile();

  Wr.PutText("=== Test WHILE false ==="); Wr.Nl();
  TestWhileFalse();

  Wr.PutText("=== Test FOR ==="); Wr.Nl();
  TestFor();

  Wr.PutText("=== Test FOR BY 2 ==="); Wr.Nl();
  TestForBy2();

  Wr.PutText("=== Test FOR BY -1 ==="); Wr.Nl();
  TestForByNeg();

  Wr.PutText("=== Test LOOP/EXIT ==="); Wr.Nl();
  TestLoop();

  Wr.PutText("=== Test REPEAT ==="); Wr.Nl();
  TestRepeat();

  Wr.PutText("=== Test WHILE sum ==="); Wr.Nl();
  TestWhileSum();

  Wr.PutText("=== Test FOR BY 3 ==="); Wr.Nl();
  TestForBy3();

  Wr.PutText("=== Test nested LOOP ==="); Wr.Nl();
  TestNestedLoop();

  Wr.PutText("=== All loop tests done ==="); Wr.Nl();
END TestLoops.
