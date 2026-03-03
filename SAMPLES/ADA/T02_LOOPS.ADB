-- T02_LOOPS.ADB : test boucles FOR / WHILE / LOOP EXIT WHEN
WITH Ada.Text_IO;
USE Ada.Text_IO;

PROCEDURE T02_Loops IS
   I      : Integer;
   Somme  : Integer;
   N      : Integer;
BEGIN
   -- Boucle FOR
   Put_Line ("FOR 1..5 :");
   Somme := 0;
   FOR I IN 1 .. 5 LOOP
      Somme := Somme + I;
   END LOOP;
   Put (Somme);
   New_Line;

   -- Boucle WHILE
   Put_Line ("WHILE decrement :");
   N := 10;
   Somme := 0;
   WHILE N > 0 LOOP
      Somme := Somme + N;
      N := N - 1;
   END LOOP;
   Put (Somme);
   New_Line;

   -- Boucle LOOP / EXIT WHEN
   Put_Line ("LOOP EXIT WHEN :");
   I := 0;
   LOOP
      I := I + 1;
      EXIT WHEN I >= 5;
   END LOOP;
   Put (I);
   New_Line;
END T02_Loops;
