-- T03_VARS.ADB : variables, constantes, affectations, arithmetique
WITH Ada.Text_IO;
USE Ada.Text_IO;

PROCEDURE T03_Vars IS
   Max   : CONSTANT Integer := 100;
   A     : Integer;
   B     : Integer;
   C     : Integer;
BEGIN
   A := 42;
   B := Max - A;
   C := A + B;
   Put (A);   New_Line;
   Put (B);   New_Line;
   Put (C);   New_Line;

   -- Expressions complexes
   A := (10 + 3) * 2;
   Put (A);   New_Line;

   -- Operateurs relationnels via IF
   IF A > 20 THEN
      Put_Line ("A > 20 OK");
   END IF;

   IF A = 26 THEN
      Put_Line ("A = 26 OK");
   END IF;
END T03_Vars;
