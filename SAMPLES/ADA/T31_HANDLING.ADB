-- T31_HANDLING.ADB : Ada.Characters.Handling -- Is_xxx et To_xxx
-- Teste les 14 fonctions de classification/conversion Character.

WITH Ada.Text_IO;                  USE Ada.Text_IO;
WITH Ada.Characters.Handling;      USE Ada.Characters.Handling;

PROCEDURE T31_HANDLING IS
BEGIN
   Put_Line("=== Ada.Characters.Handling ===");

   -- Classification Is_xxx
   Put("Is_Letter('a')        = "); Put(Is_Letter('a'));        New_Line;
   Put("Is_Letter('5')        = "); Put(Is_Letter('5'));        New_Line;
   Put("Is_Digit('7')         = "); Put(Is_Digit('7'));         New_Line;
   Put("Is_Digit('Z')         = "); Put(Is_Digit('Z'));         New_Line;
   Put("Is_Alphanumeric('A')  = "); Put(Is_Alphanumeric('A'));  New_Line;
   Put("Is_Alphanumeric('#')  = "); Put(Is_Alphanumeric('#'));  New_Line;
   Put("Is_Upper('A')         = "); Put(Is_Upper('A'));         New_Line;
   Put("Is_Upper('a')         = "); Put(Is_Upper('a'));         New_Line;
   Put("Is_Lower('x')         = "); Put(Is_Lower('x'));         New_Line;
   Put("Is_Lower('X')         = "); Put(Is_Lower('X'));         New_Line;
   Put("Is_Control(ASCII.NUL) = "); Put(Is_Control(Character'Val(0))); New_Line;
   Put("Is_Control('A')       = "); Put(Is_Control('A'));       New_Line;
   Put("Is_Graphic(' ')       = "); Put(Is_Graphic(' '));       New_Line;
   Put("Is_Graphic('A')       = "); Put(Is_Graphic('A'));       New_Line;
   Put("Is_Hexadecimal_Digit('F') = "); Put(Is_Hexadecimal_Digit('F')); New_Line;
   Put("Is_Hexadecimal_Digit('G') = "); Put(Is_Hexadecimal_Digit('G')); New_Line;

   -- Conversion To_xxx
   Put("To_Upper('a') = '"); Put(To_Upper('a')); Put_Line("'");
   Put("To_Upper('z') = '"); Put(To_Upper('z')); Put_Line("'");
   Put("To_Upper('5') = '"); Put(To_Upper('5')); Put_Line("'");
   Put("To_Lower('A') = '"); Put(To_Lower('A')); Put_Line("'");
   Put("To_Lower('Z') = '"); Put(To_Lower('Z')); Put_Line("'");
   Put("To_Lower('_') = '"); Put(To_Lower('_')); Put_Line("'");

   Put_Line("=== FIN ===");
END T31_HANDLING;
