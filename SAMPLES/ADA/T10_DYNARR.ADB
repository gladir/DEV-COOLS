-- T10_DYNARR.ADB : tableau dynamique via type access et Unchecked_Deallocation
WITH Ada.Text_IO;
WITH Ada.Integer_Text_IO;
WITH Ada.Unchecked_Deallocation;
USE Ada.Text_IO;
USE Ada.Integer_Text_IO;

PROCEDURE T10_DynArr IS

   TYPE Int_Array IS ARRAY (Positive RANGE <>) OF Integer;
   TYPE Int_Array_Ptr IS ACCESS Int_Array;

   PROCEDURE Liberer IS NEW Ada.Unchecked_Deallocation
     (Object => Int_Array, Name => Int_Array_Ptr);

   FUNCTION Somme (T : Int_Array) RETURN Integer IS
      S : Integer := 0;
   BEGIN
      FOR I IN T'Range LOOP
         S := S + T (I);
      END LOOP;
      RETURN S;
   END Somme;

   FUNCTION Maximum (T : Int_Array) RETURN Integer IS
      M : Integer := T (T'First);
   BEGIN
      FOR I IN T'Range LOOP
         IF T (I) > M THEN
            M := T (I);
         END IF;
      END LOOP;
      RETURN M;
   END Maximum;

   Tab : Int_Array_Ptr;
   N   : CONSTANT Positive := 10;
BEGIN
   -- Allocation dynamique du tableau
   Tab := NEW Int_Array (1 .. N);

   -- Remplissage : suite des carres
   FOR I IN 1 .. N LOOP
      Tab (I) := I * I;
   END LOOP;

   -- Affichage
   Put ("Tableau dynamique de taille "); Put (N, 0); Put_Line (" :");
   FOR I IN 1 .. N LOOP
      Put (Tab (I), 5);
   END LOOP;
   New_Line;

   Put ("Somme   = "); Put (Somme (Tab.ALL), 0); New_Line;
   Put ("Maximum = "); Put (Maximum (Tab.ALL), 0); New_Line;

   -- Liberation
   Liberer (Tab);
   IF Tab = NULL THEN
      Put_Line ("Memoire liberee.");
   END IF;
END T10_DynArr;
