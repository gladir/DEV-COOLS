-- test_io_formats.ada : tests de formatage d'entrees/sorties
-- Verifie les differentes combinaisons de Put et Put_Line
-- avec differents types de donnees

with Ada.Text_IO; use Ada.Text_IO;

procedure Test_IO_Formats is
   N : Integer;
   A : Integer;
   B : Integer;
   C : Character;
begin
   -- Test 1 : Entier positif simple
   N := 1;
   Put(N);
   New_Line;

   -- Test 2 : Entier plus grand
   N := 12345;
   Put(N);
   New_Line;

   -- Test 3 : Concatenation de chaines via Put
   Put("abc");
   Put("def");
   Put("ghi");
   New_Line;

   -- Test 4 : Alternance texte/nombre
   Put("valeur=");
   N := 77;
   Put(N);
   New_Line;

   -- Test 5 : Deux nombres sur la meme ligne
   A := 3;
   B := 7;
   Put(A);
   Put(" ");
   Put(B);
   New_Line;

   -- Test 6 : Caracteres individuels
   C := 'H';
   Put(C);
   C := 'i';
   Put(C);
   New_Line;

   -- Test 7 : Put_Line avec chaine vide (juste newline)
   Put("avant");
   New_Line;
   Put("apres");
   New_Line;

   -- Test 8 : Calcul et affichage
   A := 6;
   B := 7;
   N := A * B;
   Put("6*7=");
   Put(N);
   New_Line;

   -- Test 9 : Chaine longue
   Put_Line("ABCDEFGHIJKLMNOPQRSTUVWXYZ");

   -- Test 10 : Put_Line entier resultat de calcul
   N := 2 + 3 + 5 + 7 + 11;
   Put("somme premiers=");
   Put(N);
   New_Line;

   Put_Line("Fin test_io_formats");
end Test_IO_Formats;
