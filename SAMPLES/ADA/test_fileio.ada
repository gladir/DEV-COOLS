-- test_fileio.ada : Exemple de lecture et ecriture de fichiers
-- Teste Ada.Text_IO : Create, Open, Close, Put_Line, Get_Line
with Ada.Text_IO; use Ada.Text_IO;

procedure Test_FileIO is
   type Buffer is array (1 .. 256) of Character;
   F      : Integer;
   Buf    : Buffer;
   Last   : Integer;
begin
   -- Test 1 : Ecriture dans un fichier
   Put_Line ("Test 1 : Ecriture fichier");
   Create (F, Out_File, "test_output.txt");
   Put_Line (F, "Ligne 1 : Bonjour le monde !");
   Put_Line (F, "Ligne 2 : ADACW32 File IO");
   Put_Line (F, "Ligne 3 : Fin du fichier");
   Close (F);
   Put_Line ("Fichier test_output.txt cree avec succes");

   -- Test 2 : Relecture du fichier
   Put_Line ("Test 2 : Lecture fichier");
   Open (F, In_File, "test_output.txt");
   Get_Line (F, Buf, Last);
   Put_Line (Buf);
   Get_Line (F, Buf, Last);
   Put_Line (Buf);
   Get_Line (F, Buf, Last);
   Put_Line (Buf);
   Close (F);

   Put_Line ("Test termine avec succes !");
end Test_FileIO;
