-- T11_TRIPLE.ADB : triples boucles imbriquees.
-- Remplit un "cube" 3x3x3 (represente par un tableau 1D de 27 entiers
-- indexe manuellement) avec i*j*k, calcule la somme totale, puis
-- enumere les triplets pythagoriciens (a,b,c) avec c <= 20.
WITH Ada.Text_IO;
USE Ada.Text_IO;

PROCEDURE T11_Triple IS

   -- Cube 3x3x3 aplati : Cube(i,j,k) <=> Plat((i-1)*9 + (j-1)*3 + k)
   TYPE Flat_Cube IS ARRAY (1 .. 27) OF Integer;
   Cube  : Flat_Cube;
   Total : Integer := 0;
   Idx   : Integer;
BEGIN
   -- Remplissage du cube 3x3x3 avec i*j*k
   FOR I IN 1 .. 3 LOOP
      FOR J IN 1 .. 3 LOOP
         FOR K IN 1 .. 3 LOOP
            Idx := (I - 1) * 9 + (J - 1) * 3 + K;
            Cube (Idx) := I * J * K;
            Total := Total + Cube (Idx);
         END LOOP;
      END LOOP;
   END LOOP;

   -- Affichage du cube
   Put_Line ("Cube 3x3x3 (i*j*k) :");
   FOR I IN 1 .. 3 LOOP
      Put_Line ("Plan i=" & Integer'Image (I));
      FOR J IN 1 .. 3 LOOP
         FOR K IN 1 .. 3 LOOP
            Idx := (I - 1) * 9 + (J - 1) * 3 + K;
            Put (Integer'Image (Cube (Idx)) & " ");
         END LOOP;
         New_Line;
      END LOOP;
   END LOOP;
   Put_Line ("Somme totale =" & Integer'Image (Total));

   -- Recherche des triplets pythagoriciens a <= b <= c <= 20
   Put_Line ("Triplets pythagoriciens (a,b,c) avec c <= 20 :");
   FOR A IN 1 .. 20 LOOP
      FOR B IN A .. 20 LOOP
         FOR C IN B .. 20 LOOP
            IF A * A + B * B = C * C THEN
               Put ("(" & Integer'Image (A) & "," &
                    Integer'Image (B) & "," &
                    Integer'Image (C) & " ) ");
            END IF;
         END LOOP;
      END LOOP;
   END LOOP;
   New_Line;
END T11_Triple;
