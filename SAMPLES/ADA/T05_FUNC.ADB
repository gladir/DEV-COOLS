-- T05_FUNC.ADB : procedures et fonctions avec parametres / RETURN
WITH Ada.Text_IO;
USE Ada.Text_IO;

PROCEDURE T05_Func IS

   FUNCTION Max2 (A : Integer; B : Integer) RETURN Integer IS
   BEGIN
      IF A > B THEN
         RETURN A;
      ELSE
         RETURN B;
      END IF;
   END Max2;

   FUNCTION Factorielle (N : Integer) RETURN Integer IS
      R : Integer;
      I : Integer;
   BEGIN
      R := 1;
      I := 2;
      WHILE I <= N LOOP
         R := R * I;
         I := I + 1;
      END LOOP;
      RETURN R;
   END Factorielle;

   PROCEDURE Affiche2 (A : Integer; B : Integer) IS
   BEGIN
      Put (A);   New_Line;
      Put (B);   New_Line;
   END Affiche2;

   M : Integer;
   F : Integer;
BEGIN
   M := Max2 (17, 42);
   Put (M);   New_Line;

   M := Max2 (99, 3);
   Put (M);   New_Line;

   F := Factorielle (5);
   Put (F);   New_Line;

   Affiche2 (10, 20);
END T05_Func;
