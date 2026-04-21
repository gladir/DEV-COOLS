-- T07_MATH.ADB : fonctions mathematiques (racine, puissance, PGCD, PPCM...)
WITH Ada.Text_IO;
WITH Ada.Integer_Text_IO;
WITH Ada.Numerics.Elementary_Functions;
WITH Ada.Float_Text_IO;
USE Ada.Text_IO;
USE Ada.Integer_Text_IO;
USE Ada.Numerics.Elementary_Functions;
USE Ada.Float_Text_IO;

PROCEDURE T07_Math IS

   FUNCTION Abs_Int (A : Integer) RETURN Integer IS
   BEGIN
      IF A < 0 THEN
         RETURN -A;
      ELSE
         RETURN A;
      END IF;
   END Abs_Int;

   FUNCTION Min_Int (A, B : Integer) RETURN Integer IS
   BEGIN
      IF A < B THEN RETURN A; ELSE RETURN B; END IF;
   END Min_Int;

   FUNCTION Max_Int (A, B : Integer) RETURN Integer IS
   BEGIN
      IF A > B THEN RETURN A; ELSE RETURN B; END IF;
   END Max_Int;

   FUNCTION PGCD (A, B : Integer) RETURN Integer IS
      X : Integer := Abs_Int (A);
      Y : Integer := Abs_Int (B);
      T : Integer;
   BEGIN
      WHILE Y /= 0 LOOP
         T := Y;
         Y := X MOD Y;
         X := T;
      END LOOP;
      RETURN X;
   END PGCD;

   FUNCTION PPCM (A, B : Integer) RETURN Integer IS
   BEGIN
      IF A = 0 OR B = 0 THEN
         RETURN 0;
      END IF;
      RETURN Abs_Int (A * B) / PGCD (A, B);
   END PPCM;

   FUNCTION Puissance (Base : Integer; Exp : Natural) RETURN Integer IS
      R : Integer := 1;
      I : Natural := 0;
   BEGIN
      WHILE I < Exp LOOP
         R := R * Base;
         I := I + 1;
      END LOOP;
      RETURN R;
   END Puissance;

   X : Float;
BEGIN
   Put ("Abs(-17)   = "); Put (Abs_Int (-17), 0); New_Line;
   Put ("Min(8,3)   = "); Put (Min_Int (8, 3), 0); New_Line;
   Put ("Max(8,3)   = "); Put (Max_Int (8, 3), 0); New_Line;
   Put ("PGCD(48,18)= "); Put (PGCD (48, 18), 0); New_Line;
   Put ("PPCM(6,4)  = "); Put (PPCM (6, 4), 0); New_Line;
   Put ("2^10       = "); Put (Puissance (2, 10), 0); New_Line;

   X := Sqrt (2.0);
   Put ("Sqrt(2)    = ");
   Put (X, Fore => 1, Aft => 6, Exp => 0);
   New_Line;

   X := Sin (0.5);
   Put ("Sin(0.5)   = ");
   Put (X, Fore => 1, Aft => 6, Exp => 0);
   New_Line;
END T07_Math;
