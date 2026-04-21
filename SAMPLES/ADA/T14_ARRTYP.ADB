-- T14_ARRTYP.ADB : tableaux non-contraints
-- Declare un type ARRAY (Integer RANGE <>) OF Integer et instancie
-- des variables contraintes avec des bornes differentes. Utilise
-- les attributs 'First, 'Last et 'Length, puis affiche la somme
-- des elements de chaque tableau.
WITH Ada.Text_IO;
WITH Ada.Integer_Text_IO;
USE Ada.Text_IO;
USE Ada.Integer_Text_IO;

PROCEDURE T14_ArrTyp IS

   TYPE Int_Array IS ARRAY (Integer RANGE <>) OF Integer;

   A : Int_Array(1..5);
   B : Int_Array(10..14);

   Somme : Integer;

BEGIN
   -- Remplir A : carres de 1..5
   FOR I IN 1 .. 5 LOOP
      A(I) := I * I;
   END LOOP;

   -- Remplir B : cubes de 1..5
   FOR I IN 1 .. 5 LOOP
      B(I + 9) := I * I * I;
   END LOOP;

   -- Afficher A
   Put("A'First  = "); Put(A'First,  0); New_Line;
   Put("A'Last   = "); Put(A'Last,   0); New_Line;
   Put("A'Length = "); Put(A'Length, 0); New_Line;

   Somme := 0;
   FOR I IN 1 .. 5 LOOP
      Somme := Somme + A(I);
   END LOOP;
   Put("Somme A  = "); Put(Somme, 0); New_Line;

   -- Afficher B
   Put("B'First  = "); Put(B'First,  0); New_Line;
   Put("B'Last   = "); Put(B'Last,   0); New_Line;
   Put("B'Length = "); Put(B'Length, 0); New_Line;

   Somme := 0;
   FOR I IN 10 .. 14 LOOP
      Somme := Somme + B(I);
   END LOOP;
   Put("Somme B  = "); Put(Somme, 0); New_Line;
END T14_ArrTyp;
