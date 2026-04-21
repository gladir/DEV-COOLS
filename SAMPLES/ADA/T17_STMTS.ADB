-- T17_STMTS.ADB : dispatcher des instructions (TODO 17 / TODO 18)
-- Exerce toutes les formes d instructions prises en charge :
--   * NULL
--   * RETURN, IF / ELSIF / ELSE / END IF
--   * CASE / WHEN valeur | valeurs alternatives | ranges | OTHERS
--   * LOOP + EXIT WHEN
--   * WHILE ... LOOP
--   * FOR I IN bornes LOOP, y compris REVERSE
--   * BEGIN ... END bloc anonyme
--   * DECLARE ... BEGIN ... END bloc avec declaration locale
--   * GOTO / <<label>>
--   * PRAGMA (ignore)

WITH Ada.Text_IO;
WITH Ada.Integer_Text_IO;
USE Ada.Text_IO;
USE Ada.Integer_Text_IO;

PROCEDURE T17_Stmts IS

   X   : Integer;
   I   : Integer;
   Sum : Integer;

BEGIN
   -- 1. IF / ELSIF / ELSE --------------------------------------
   X := 5;
   IF X < 0 THEN
      Put_Line("neg");
   ELSIF X = 0 THEN
      Put_Line("zero");
   ELSIF X < 10 THEN
      Put_Line("small");
   ELSE
      Put_Line("big");
   END IF;

   -- 2. CASE avec valeurs, ranges et OTHERS --------------------
   FOR V IN 0 .. 10 LOOP
      Put("case "); Put(V, 0); Put(" -> ");
      CASE V IS
         WHEN 0         => Put_Line("zero");
         WHEN 1 .. 4    => Put_Line("1..4");
         WHEN 5 | 6 | 7 => Put_Line("5|6|7");
         WHEN 8 .. 9    => Put_Line("8..9");
         WHEN OTHERS    => Put_Line("autre");
      END CASE;
   END LOOP;

   -- 3. LOOP + EXIT WHEN ---------------------------------------
   I := 0;
   LOOP
      EXIT WHEN I >= 3;
      Put("loop "); Put(I, 0); New_Line;
      I := I + 1;
   END LOOP;

   -- 4. WHILE --------------------------------------------------
   I := 3;
   WHILE I > 0 LOOP
      Put("while "); Put(I, 0); New_Line;
      I := I - 1;
   END LOOP;

   -- 5. FOR et FOR REVERSE -------------------------------------
   Sum := 0;
   FOR K IN 1 .. 5 LOOP
      Sum := Sum + K;
   END LOOP;
   Put("sum1..5="); Put(Sum, 0); New_Line;

   FOR K IN REVERSE 1 .. 3 LOOP
      Put("rev "); Put(K, 0); New_Line;
   END LOOP;

   -- 6. NULL ---------------------------------------------------
   NULL;

   -- 7. BEGIN anonyme ------------------------------------------
   BEGIN
      Put_Line("bloc anonyme");
   END;

   -- 8. DECLARE avec variable locale ---------------------------
   DECLARE
      Y : Integer := 100;
   BEGIN
      Put("declare Y="); Put(Y, 0); New_Line;
   END;

   -- 9. GOTO / <<label>> ---------------------------------------
   I := 0;
   <<Retry>>
   I := I + 1;
   Put("goto pass "); Put(I, 0); New_Line;
   IF I < 2 THEN
      GOTO Retry;
   END IF;

   GOTO Suite;
   Put_Line("skipped");
   <<Suite>>
   Put_Line("apres goto");

   -- 10. PRAGMA (ignore) --------------------------------------
   PRAGMA Unreferenced(X);

   Put_Line("fin");
END T17_Stmts;
