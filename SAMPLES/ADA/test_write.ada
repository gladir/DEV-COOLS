-- test_write.ada : tests d'ecriture (Put, Put_Line, New_Line)
-- Verifie que toutes les formes d'ecriture console fonctionnent
-- Sortie attendue exacte pour verification automatisee

with Ada.Text_IO; use Ada.Text_IO;

procedure Test_Write is
   I : Integer;
   C : Character;
   B : Boolean;
begin
   -- Test 1 : Put_Line chaine litterale
   Put_Line("Test 1 : Hello");

   -- Test 2 : Put chaine + New_Line
   Put("Test 2 : ");
   Put("Bonjour");
   New_Line;

   -- Test 3 : Put entier
   I := 42;
   Put("Test 3 : ");
   Put(I);
   New_Line;

   -- Test 4 : Put_Line entier litteral
   Put("Test 4 : ");
   Put_Line(100);

   -- Test 5 : Put caractere
   C := 'X';
   Put("Test 5 : ");
   Put(C);
   New_Line;

   -- Test 6 : Put boolean
   B := True;
   Put("Test 6 : ");
   Put(B);
   New_Line;

   -- Test 7 : Plusieurs Put_Line enchaines
   Put_Line("Test 7a : ligne A");
   Put_Line("Test 7b : ligne B");
   Put_Line("Test 7c : ligne C");

   -- Test 8 : Ecriture d'expression
   I := 10 + 25;
   Put("Test 8 : ");
   Put(I);
   New_Line;

   -- Test 9 : Ecriture de zero
   I := 0;
   Put("Test 9 : ");
   Put(I);
   New_Line;

   -- Test 10 : Ecriture negative
   I := 0 - 1;
   Put("Test 10 : ");
   Put(I);
   New_Line;

   Put_Line("Fin test_write");
end Test_Write;
