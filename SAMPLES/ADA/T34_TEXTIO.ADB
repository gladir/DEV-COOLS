-- T34_TEXTIO.ADB : Ada.Text_IO -- primitives de base
-- Teste Put, Put_Line, New_Line, Set_Col sur differents types.

WITH Ada.Text_IO;  USE Ada.Text_IO;

PROCEDURE T34_TEXTIO IS
   N : Integer := 42;
   B : Boolean := True;
   C : Character := 'Q';
BEGIN
   Put_Line("=== Ada.Text_IO ===");

   -- Put sur differents types
   Put_Line("Put(String)  :");
   Put("Bonjour"); New_Line;
   Put_Line("Put(Integer) :");
   Put(N); New_Line;
   Put(-1234); New_Line;
   Put_Line("Put(Boolean) :");
   Put(B); New_Line;
   Put(False); New_Line;
   Put_Line("Put(Character) :");
   Put(C); New_Line;
   Put('$'); New_Line;

   -- New_Line avec compteur
   Put_Line("-- New_Line --");
   Put("avant"); New_Line;
   Put("apres"); New_Line;

   -- Set_Col : positionnement en colonne
   Put_Line("-- Set_Col --");
   Put("Col1"); Set_Col(10); Put_Line("Col10");
   Put("X"); Set_Col(5); Put("Y"); Set_Col(15); Put_Line("Z");

   -- Put_Line combine
   Put_Line("Une ligne.");
   Put_Line("Une autre.");

   Put_Line("=== FIN ===");
END T34_TEXTIO;
