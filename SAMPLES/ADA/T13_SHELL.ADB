-- T13_SHELL.ADB : tri Shell-Metzner (Shell sort avec sequence N/2).
-- Le tableau est initialise par assignation directe de chaque element
-- (le sous-ensemble d'Ada supporte par ADACW32 n'inclut pas les
-- aggregats de tableau).
WITH Ada.Text_IO;
USE Ada.Text_IO;

PROCEDURE T13_Shell IS

   N : CONSTANT Integer := 12;

   TYPE Int_Array IS ARRAY (1 .. 12) OF Integer;

   PROCEDURE Tri_Shell_Metzner (T : IN OUT Int_Array) IS
      Ecart : Integer;
      I, J  : Integer;
      Temp  : Integer;
   BEGIN
      Ecart := N / 2;
      WHILE Ecart > 0 LOOP
         I := 1 + Ecart;
         WHILE I <= N LOOP
            Temp := T (I);
            J := I;
            WHILE J >= 1 + Ecart AND THEN T (J - Ecart) > Temp LOOP
               T (J) := T (J - Ecart);
               J := J - Ecart;
            END LOOP;
            T (J) := Temp;
            I := I + 1;
         END LOOP;
         Ecart := Ecart / 2;
      END LOOP;
   END Tri_Shell_Metzner;

   PROCEDURE Afficher (Titre : String; T : Int_Array) IS
   BEGIN
      Put (Titre);
      FOR I IN 1 .. N LOOP
         Put (Integer'Image (T (I)));
      END LOOP;
      New_Line;
   END Afficher;

   Donnees : Int_Array;
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

   Afficher ("Avant :", Donnees);
   Tri_Shell_Metzner (Donnees);
   Afficher ("Apres :", Donnees);
END T13_Shell;
