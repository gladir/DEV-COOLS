-- T06_COND.ADB : IF/ELSIF/ELSE et CASE/WHEN/OTHERS
WITH Ada.Text_IO;
USE Ada.Text_IO;

PROCEDURE T06_Cond IS
   N : Integer;
BEGIN
   -- IF / ELSIF / ELSE
   N := 75;
   IF N >= 90 THEN
      Put_Line ("Tres bien");
   ELSIF N >= 70 THEN
      Put_Line ("Bien");
   ELSIF N >= 50 THEN
      Put_Line ("Passable");
   ELSE
      Put_Line ("Insuffisant");
   END IF;

   -- CASE / WHEN / OTHERS
   N := 3;
   CASE N IS
      WHEN 1 => Put_Line ("Un");
      WHEN 2 => Put_Line ("Deux");
      WHEN 3 => Put_Line ("Trois");
      WHEN 4 => Put_Line ("Quatre");
      WHEN 5 => Put_Line ("Cinq");
      WHEN OTHERS => Put_Line ("Autre");
   END CASE;

   -- CASE avec plage (valeur dans OTHERS)
   N := 99;
   CASE N IS
      WHEN 1 => Put_Line ("Un");
      WHEN 2 => Put_Line ("Deux");
      WHEN OTHERS => Put_Line ("hors 1..2");
   END CASE;
END T06_Cond;
