-- test_stmts.ada : Test du dispatcher principal des instructions (TODO 15)
--
-- Ce fichier teste :
--   1. NULL ; instruction
--   2. RETURN simple
--   3. RETURN avec expression
--   4. EXIT simple
--   5. EXIT WHEN condition
--   6. RAISE simple
--   7. RAISE nom d exception
--   8. GOTO label
--   9. PRAGMA instruction
--  10. Assignation simple (ident := expr ;)
--  11. Appel de procedure simple
--  12. Appel qualifie (pkg.proc)
--  13. IF / ELSIF / ELSE / END IF imbrique
--  14. CASE / WHEN / END CASE
--  15. LOOP / END LOOP (boucle infinie)
--  16. WHILE / LOOP / END LOOP
--  17. FOR / IN / LOOP / END LOOP
--  18. BEGIN / END bloc anonyme
--  19. DECLARE bloc avec declarations locales
--  20. Melange : sequence avec plusieurs types d instructions

WITH Ada.Text_IO;
USE Ada.Text_IO;

-- 1. NULL dans une procedure
PROCEDURE Test_Null IS
BEGIN
   NULL;
END Test_Null;

-- 2. RETURN simple dans une procedure
PROCEDURE Test_Return IS
BEGIN
   RETURN;
END Test_Return;

-- 3. RETURN avec expression dans une function
FUNCTION Test_Return_Expr RETURN Integer IS
BEGIN
   RETURN 42;
END Test_Return_Expr;

-- 4. EXIT simple dans une boucle
PROCEDURE Test_Exit IS
BEGIN
   LOOP
      EXIT;
   END LOOP;
END Test_Exit;

-- 5. EXIT WHEN dans une boucle
PROCEDURE Test_Exit_When IS
   I : Integer;
BEGIN
   LOOP
      EXIT WHEN I > 10;
   END LOOP;
END Test_Exit_When;

-- 6. RAISE simple
PROCEDURE Test_Raise IS
BEGIN
   NULL;
EXCEPTION
   WHEN OTHERS =>
      RAISE;
END Test_Raise;

-- 7. RAISE avec nom d exception
PROCEDURE Test_Raise_Name IS
BEGIN
   RAISE Constraint_Error;
END Test_Raise_Name;

-- 8. GOTO et label
PROCEDURE Test_Goto IS
BEGIN
   GOTO Done;
   NULL;
END Test_Goto;

-- 9. PRAGMA dans un corps (pas dans la partie declarative)
PROCEDURE Test_Pragma IS
BEGIN
   PRAGMA Inline;
   NULL;
END Test_Pragma;

-- 10. Assignation simple
PROCEDURE Test_Assign IS
   X : Integer;
BEGIN
   X := 42;
END Test_Assign;

-- 11. Appel de procedure simple
PROCEDURE Test_Call IS
BEGIN
   Test_Null;
END Test_Call;

-- 12. Appel qualifie
PROCEDURE Test_Qual_Call IS
BEGIN
   Ada.Text_IO.Put_Line ("Hello");
END Test_Qual_Call;

-- 13. IF / ELSIF / ELSE / END IF imbrique
PROCEDURE Test_If IS
   X : Integer;
BEGIN
   IF X > 0 THEN
      NULL;
   ELSIF X = 0 THEN
      NULL;
   ELSE
      NULL;
   END IF;
END Test_If;

-- 14. CASE / WHEN / END CASE
PROCEDURE Test_Case IS
   X : Integer;
BEGIN
   CASE X IS
      WHEN 1 =>
         NULL;
      WHEN 2 | 3 =>
         NULL;
      WHEN OTHERS =>
         NULL;
   END CASE;
END Test_Case;

-- 15. LOOP / END LOOP (boucle infinie)
PROCEDURE Test_Loop IS
BEGIN
   LOOP
      EXIT;
   END LOOP;
END Test_Loop;

-- 16. WHILE / LOOP / END LOOP
PROCEDURE Test_While IS
   I : Integer;
BEGIN
   WHILE I < 10 LOOP
      NULL;
   END LOOP;
END Test_While;

-- 17. FOR / IN / LOOP / END LOOP
PROCEDURE Test_For IS
BEGIN
   FOR I IN 1 .. 10 LOOP
      NULL;
   END LOOP;
END Test_For;

-- 18. BEGIN / END bloc anonyme
PROCEDURE Test_Begin_Block IS
BEGIN
   BEGIN
      NULL;
   END;
END Test_Begin_Block;

-- 19. DECLARE bloc
PROCEDURE Test_Declare IS
BEGIN
   DECLARE
      Temp : Integer;
   BEGIN
      NULL;
   END;
END Test_Declare;

-- 20. Melange : sequence avec plusieurs types d instructions
PROCEDURE Test_Mixed IS
   X : Integer;
   Y : Integer;
BEGIN
   X := 0;
   Y := 1;
   IF X > 0 THEN
      Y := X;
   ELSE
      NULL;
   END IF;
   FOR I IN 1 .. 5 LOOP
      NULL;
   END LOOP;
   WHILE Y < 100 LOOP
      Y := Y + 1;
   END LOOP;
   CASE X IS
      WHEN 0 =>
         NULL;
      WHEN OTHERS =>
         NULL;
   END CASE;
   RETURN;
END Test_Mixed;
