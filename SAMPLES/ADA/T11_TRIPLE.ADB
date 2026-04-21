-- T11_TRIPLE.ADB : triples boucles imbriquees (cube 3D, triplets pythagoriciens)
WITH Ada.Text_IO;
WITH Ada.Integer_Text_IO;
USE Ada.Text_IO;
USE Ada.Integer_Text_IO;

PROCEDURE T11_Triple IS
   Cube  : ARRAY (1 .. 3, 1 .. 3, 1 .. 3) OF Integer;
   Total : Integer := 0;
BEGIN
   -- Remplissage d'un cube 3x3x3 avec i*j*k
   FOR I IN 1 .. 3 LOOP
      FOR J IN 1 .. 3 LOOP
         FOR K IN 1 .. 3 LOOP
            Cube (I, J, K) := I * J * K;
            Total := Total + Cube (I, J, K);
         END LOOP;
      END LOOP;
   END LOOP;

   -- Affichage du cube
   Put_Line ("Cube 3x3x3 (i*j*k) :");
   FOR I IN 1 .. 3 LOOP
      Put ("Plan i="); Put (I, 0); New_Line;
      FOR J IN 1 .. 3 LOOP
         FOR K IN 1 .. 3 LOOP
            Put (Cube (I, J, K), 4);
         END LOOP;
         New_Line;
      END LOOP;
   END LOOP;
   Put ("Somme totale = "); Put (Total, 0); New_Line;

   -- Recherche des triplets pythagoriciens a <= b <= c <= 20
   Put_Line ("Triplets pythagoriciens (a,b,c) avec c <= 20 :");
   FOR A IN 1 .. 20 LOOP
      FOR B IN A .. 20 LOOP
         FOR C IN B .. 20 LOOP
            IF A * A + B * B = C * C THEN
               Put ("("); Put (A, 0); Put (",");
               Put (B, 0); Put (",");
               Put (C, 0); Put (") ");
            END IF;
         END LOOP;
      END LOOP;
   END LOOP;
   New_Line;
END T11_Triple;
