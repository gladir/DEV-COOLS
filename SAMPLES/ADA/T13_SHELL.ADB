-- T13_SHELL.ADB : tri Shell-Metzner (Shell sort avec sequence N/2)
WITH Ada.Text_IO;
WITH Ada.Integer_Text_IO;
USE Ada.Text_IO;
USE Ada.Integer_Text_IO;

PROCEDURE T13_Shell IS

   TYPE Int_Array IS ARRAY (Positive RANGE <>) OF Integer;

   PROCEDURE Tri_Shell_Metzner (T : IN OUT Int_Array) IS
      N      : CONSTANT Integer := T'Length;
      Base   : CONSTANT Integer := T'First;
      Ecart  : Integer;
      I, J   : Integer;
      Temp   : Integer;
   BEGIN
      Ecart := N / 2;
      WHILE Ecart > 0 LOOP
         I := Base + Ecart;
         WHILE I <= T'Last LOOP
            Temp := T (I);
            J := I;
            WHILE J >= Base + Ecart AND THEN T (J - Ecart) > Temp LOOP
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
      FOR I IN T'Range LOOP
         Put (T (I), 5);
      END LOOP;
      New_Line;
   END Afficher;

   Donnees : Int_Array (1 .. 12) :=
     (23, 1, 45, 12, 78, 3, 9, 67, 34, 56, 8, 21);
BEGIN
   Afficher ("Avant : ", Donnees);
   Tri_Shell_Metzner (Donnees);
   Afficher ("Apres : ", Donnees);
END T13_Shell;
