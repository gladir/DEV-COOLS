-- T32_NUMERICS.ADB : Ada.Numerics.Elementary_Functions -- 12 fonctions FPU
-- Teste les fonctions mathematiques standard sur Float.

WITH Ada.Text_IO;                           USE Ada.Text_IO;
WITH Ada.Numerics.Elementary_Functions;     USE Ada.Numerics.Elementary_Functions;

PROCEDURE T32_NUMERICS IS
   X : Float;
BEGIN
   Put_Line("=== Ada.Numerics.Elementary_Functions ===");

   Put("Sqrt(16.0)  = "); X := Sqrt(16.0);  Put(X); New_Line;
   Put("Sqrt(2.0)   = "); X := Sqrt(2.0);   Put(X); New_Line;
   Put("Sqrt(100.0) = "); X := Sqrt(100.0); Put(X); New_Line;

   Put("Sin(0.0)      = "); X := Sin(0.0);      Put(X); New_Line;
   Put("Cos(0.0)      = "); X := Cos(0.0);      Put(X); New_Line;
   Put("Tan(0.0)      = "); X := Tan(0.0);      Put(X); New_Line;

   Put("Exp(0.0)   = "); X := Exp(0.0);   Put(X); New_Line;
   Put("Exp(1.0)   = "); X := Exp(1.0);   Put(X); New_Line;
   Put("Log(1.0)   = "); X := Log(1.0);   Put(X); New_Line;

   Put("Arcsin(0.0) = "); X := Arcsin(0.0); Put(X); New_Line;
   Put("Arccos(1.0) = "); X := Arccos(1.0); Put(X); New_Line;
   Put("Arctan(0.0) = "); X := Arctan(0.0); Put(X); New_Line;

   Put("Sinh(0.0) = "); X := Sinh(0.0); Put(X); New_Line;
   Put("Cosh(0.0) = "); X := Cosh(0.0); Put(X); New_Line;
   Put("Tanh(0.0) = "); X := Tanh(0.0); Put(X); New_Line;

   Put_Line("=== FIN ===");
END T32_NUMERICS;
