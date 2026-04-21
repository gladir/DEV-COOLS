-- T13_SHELL.ADB : tri Shell-Metzner (Shell sort avec sequence N/2).
-- Le tri est effectue en ligne sur un tableau global (le passage de
-- tableaux en parametre n'est pas encore supporte par ADACW32).
WITH Ada.Text_IO;
USE Ada.Text_IO;

PROCEDURE T13_Shell IS

   N : CONSTANT Integer := 12;

   TYPE Int_Array IS ARRAY (1 .. 12) OF Integer;

   Donnees : Int_Array;
   Ecart   : Integer;
   I, J    : Integer;
   Temp    : Integer;
BEGIN
   -- Initialisation : 23, 1, 45, 12, 78, 3, 9, 67, 34, 56, 8, 21
   Donnees (1)  := 23;
   Donnees (2)  := 1;
   Donnees (3)  := 45;
   Donnees (4)  := 12;
   Donnees (5)  := 78;
   Donnees (6)  := 3;
   Donnees (7)  := 9;
   Donnees (8)  := 67;
   Donnees (9)  := 34;
   Donnees (10) := 56;
   Donnees (11) := 8;
   Donnees (12) := 21;

   -- Affichage avant tri
   Put ("Avant :");
   FOR K IN 1 .. N LOOP
      Put (Integer'Image (Donnees (K)));
   END LOOP;
   New_Line;

   -- Tri Shell-Metzner
   Ecart := N / 2;
   WHILE Ecart > 0 LOOP
      I := 1 + Ecart;
      WHILE I <= N LOOP
         Temp := Donnees (I);
         J := I;
         WHILE J >= 1 + Ecart AND THEN Donnees (J - Ecart) > Temp LOOP
            Donnees (J) := Donnees (J - Ecart);
            J := J - Ecart;
         END LOOP;
         Donnees (J) := Temp;
         I := I + 1;
      END LOOP;
      Ecart := Ecart / 2;
   END LOOP;

   -- Affichage apres tri
   Put ("Apres :");
   FOR K IN 1 .. N LOOP
      Put (Integer'Image (Donnees (K)));
   END LOOP;
   New_Line;
END T13_Shell;
