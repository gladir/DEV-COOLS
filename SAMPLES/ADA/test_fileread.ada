-- test_fileread.ada : Exemple de lecture de fichier ligne par ligne
-- Teste Ada.Text_IO : Create, Open, Get_Line avec handle fichier, Close
with Ada.Text_IO; use Ada.Text_IO;

procedure Test_FileRead is
   type Buffer is array (1 .. 256) of Character;
   FOut : Integer;
   FIn  : Integer;
   Buf  : Buffer;
   Last : Integer;
begin
   -- Etape 1 : Creer un fichier de test
   Put_Line ("Etape 1 : Creation du fichier de test");
   Create (FOut, Out_File, "donnees.txt");
   Put_Line (FOut, "Pomme");
   Put_Line (FOut, "Banane");
   Put_Line (FOut, "Cerise");
   Put_Line (FOut, "Datte");
   Put_Line (FOut, "Figue");
   Close (FOut);
   Put_Line ("Fichier donnees.txt cree (5 lignes)");

   -- Etape 2 : Relire le fichier
   Put_Line ("Etape 2 : Lecture du fichier");
   Open (FIn, In_File, "donnees.txt");

   Get_Line (FIn, Buf, Last);
   Put ("Lu : ");
   Put_Line (Buf);

   Get_Line (FIn, Buf, Last);
   Put ("Lu : ");
   Put_Line (Buf);

   Get_Line (FIn, Buf, Last);
   Put ("Lu : ");
   Put_Line (Buf);

   Get_Line (FIn, Buf, Last);
   Put ("Lu : ");
   Put_Line (Buf);

   Get_Line (FIn, Buf, Last);
   Put ("Lu : ");
   Put_Line (Buf);

   Close (FIn);
   Put_Line ("Lecture terminee avec succes !");
end Test_FileRead;
