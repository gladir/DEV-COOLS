-- T10_DYNARR.ADB : manipulations sur un tableau Integer de taille fixe.
-- Demontre le remplissage, la somme et le maximum d'un tableau statique
-- de 10 entiers (carres successifs), avec des sous-programmes qui prennent
-- le tableau par copie.
WITH Ada.Text_IO;
USE Ada.Text_IO;

PROCEDURE T10_DynArr IS

   N : CONSTANT Integer := 10;

   TYPE Int_Array IS ARRAY (1 .. 10) OF Integer;

   FUNCTION Somme (T : Int_Array) RETURN Integer IS
      S : Integer := 0;
   BEGIN
      FOR I IN 1 .. N LOOP
         S := S + T (I);
      END LOOP;
      RETURN S;
   END Somme;

   FUNCTION Maximum (T : Int_Array) RETURN Integer IS
      M : Integer := T (1);
   BEGIN
      FOR I IN 2 .. N LOOP
         IF T (I) > M THEN
            M := T (I);
         END IF;
      END LOOP;
      RETURN M;
   END Maximum;

   Tab : Int_Array;
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

   Put_Line ("Somme   =" & Integer'Image (Somme (Tab)));
   Put_Line ("Maximum =" & Integer'Image (Maximum (Tab)));
END T10_DynArr;
