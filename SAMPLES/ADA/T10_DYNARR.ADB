-- T10_DYNARR.ADB : manipulations sur un tableau Integer de taille fixe.
-- Demontre le remplissage, la somme et le maximum d'un tableau statique
-- de 10 entiers (carres successifs). Les operations sont effectuees en
-- ligne (le passage de tableau en parametre par valeur n'est pas encore
-- supporte par le compilateur ADACW32).
WITH Ada.Text_IO;
USE Ada.Text_IO;

PROCEDURE T10_DynArr IS
   N : CONSTANT Integer := 10;

   TYPE Int_Array IS ARRAY (1 .. 10) OF Integer;

   Tab : Int_Array;
   Somme   : Integer := 0;
   Maximum : Integer;
BEGIN
   -- Remplissage : suite des carres (1, 4, 9, 16, ..., 100)
   FOR I IN 1 .. N LOOP
      Tab (I) := I * I;
   END LOOP;

   -- Affichage des elements
   Put_Line ("Tableau de taille 10 (carres successifs) :");
   FOR I IN 1 .. N LOOP
      Put_Line ("  T(" & Integer'Image (I) & " ) =" &
                Integer'Image (Tab (I)));
   END LOOP;

   -- Somme des elements
   FOR I IN 1 .. N LOOP
      Somme := Somme + Tab (I);
   END LOOP;

   -- Maximum
   Maximum := Tab (1);
   FOR I IN 2 .. N LOOP
      IF Tab (I) > Maximum THEN
         Maximum := Tab (I);
      END IF;
   END LOOP;

   Put_Line ("Somme   =" & Integer'Image (Somme));
   Put_Line ("Maximum =" & Integer'Image (Maximum));
END T10_DynArr;
