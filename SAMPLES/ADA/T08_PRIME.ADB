-- T08_PRIME.ADB : nombres premiers et factorielle (iterative / recursive)
WITH Ada.Text_IO;
WITH Ada.Integer_Text_IO;
USE Ada.Text_IO;
USE Ada.Integer_Text_IO;

PROCEDURE T08_Prime IS

   FUNCTION Est_Premier (N : Integer) RETURN Boolean IS
      I : Integer;
   BEGIN
      IF N < 2 THEN
         RETURN False;
      END IF;
      IF N = 2 THEN
         RETURN True;
      END IF;
      IF N MOD 2 = 0 THEN
         RETURN False;
      END IF;
      I := 3;
      WHILE I * I <= N LOOP
         IF N MOD I = 0 THEN
            RETURN False;
         END IF;
         I := I + 2;
      END LOOP;
      RETURN True;
   END Est_Premier;

   FUNCTION Factorielle_Iter (N : Natural) RETURN Long_Long_Integer IS
      R : Long_Long_Integer := 1;
      I : Natural := 2;
   BEGIN
      WHILE I <= N LOOP
         R := R * Long_Long_Integer (I);
         I := I + 1;
      END LOOP;
      RETURN R;
   END Factorielle_Iter;

   FUNCTION Factorielle_Rec (N : Natural) RETURN Long_Long_Integer IS
   BEGIN
      IF N <= 1 THEN
         RETURN 1;
      END IF;
      RETURN Long_Long_Integer (N) * Factorielle_Rec (N - 1);
   END Factorielle_Rec;

   Compte : Integer := 0;
BEGIN
   Put_Line ("Nombres premiers inferieurs a 50 :");
   FOR K IN 2 .. 49 LOOP
      IF Est_Premier (K) THEN
         Put (K, 4);
         Compte := Compte + 1;
      END IF;
   END LOOP;
   New_Line;
   Put ("Total : "); Put (Compte, 0); New_Line;

   Put_Line ("Factorielles (iteratif / recursif) :");
   FOR K IN 0 .. 12 LOOP
      Put (K, 3); Put (" -> ");
      Put (Long_Long_Integer'Image (Factorielle_Iter (K)));
      Put (" / ");
      Put (Long_Long_Integer'Image (Factorielle_Rec (K)));
      New_Line;
   END LOOP;
END T08_Prime;
