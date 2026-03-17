-- test_io_vars.ada : tests d'ecriture de variables de differents types
-- Verifie que les variables sont correctement lues/ecrites en memoire
-- et affichees via Put/Put_Line

with Ada.Text_IO; use Ada.Text_IO;

procedure Test_IO_Vars is
   -- Variables locales
   X : Integer;
   Y : Integer;
   Z : Integer;
   Max_Val : constant Integer := 999;
   C : Character;
   B : Boolean;
begin
   -- Test 1 : affectation et affichage simple
   X := 10;
   Put("X=");
   Put(X);
   New_Line;

   -- Test 2 : affectation depuis expression
   Y := X + 5;
   Put("Y=");
   Put(Y);
   New_Line;

   -- Test 3 : affectation depuis autre variable
   Z := Y;
   Put("Z=");
   Put(Z);
   New_Line;

   -- Test 4 : constante
   Put("Max=");
   Put(Max_Val);
   New_Line;

   -- Test 5 : modification et relecture
   X := 100;
   X := X + 1;
   Put("X+1=");
   Put(X);
   New_Line;

   -- Test 6 : operation arithmetique complexe
   Z := (X + Y) * 2;
   Put("(X+Y)*2=");
   Put(Z);
   New_Line;

   -- Test 7 : caractere
   C := 'Z';
   Put("Char=");
   Put(C);
   New_Line;

   -- Test 8 : boolean True
   B := True;
   Put("Bool=");
   Put(B);
   New_Line;

   -- Test 9 : boolean False
   B := False;
   Put("Bool=");
   Put(B);
   New_Line;

   -- Test 10 : echange de valeurs
   X := 11;
   Y := 22;
   Z := X;
   X := Y;
   Y := Z;
   Put("X apres swap=");
   Put(X);
   New_Line;
   Put("Y apres swap=");
   Put(Y);
   New_Line;

   Put_Line("Fin test_io_vars");
end Test_IO_Vars;
